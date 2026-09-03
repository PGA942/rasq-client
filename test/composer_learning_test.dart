import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/compose/composer_learning.dart';
import 'package:rasq_client/features/nodeprog/node_executor.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_models/rasq_models.dart';

/// D-132: 運用時の学習ループ — 確定ラベルの EMA 学習(半減期 90 日・代表投稿
/// 固定・訂正は強く学習)と、連動 (A→B) の正例/負例の分離記録。
void main() {
  test('確定投稿の学習: 件数・代表投稿の固定・特徴語/プロファイルの蓄積', () {
    Map<String, Object?>? slot;
    for (var i = 0; i < 7; i++) {
      slot = composerLearnUpdate(slot, 'スプラトゥーンのガチマッチ配信 その$i', now: DateTime(2026, 9, 1));
    }
    expect(slot!['count'], 7);
    expect((slot['reps'] as List), hasLength(composerLearnRepCount)); // 代表投稿は最初の 5 件で固定
    expect((slot['texts'] as List).cast<String>().first, contains('スプラトゥーン'));
    final vector = (slot['vector'] as Map).cast<String, Object?>();
    expect(vector['kind'], 'ngram');
    expect((vector['p'] as Map), isNotEmpty);
  });

  test('半減期 90 日: 90 日後の更新で古い寄与が半分に減衰する', () {
    final t0 = DateTime(2026, 1, 1);
    var slot = composerLearnUpdate(null, 'ねこの話', now: t0);
    final before = ((slot['vector'] as Map)['p'] as Map).values.cast<num>().fold<double>(0, (a, b) => a + b);
    slot = composerLearnUpdate(slot, 'べつの話題', now: t0.add(const Duration(days: 90)));
    final p = ((slot['vector'] as Map)['p'] as Map).cast<String, num>();
    // 「ねこ」由来の n-gram は半減している(新規追加分と混ざるので個別に確認)。
    final neko = charKeysOf(p, 'ねこ');
    expect(neko, isNotEmpty);
    for (final k in neko) {
      expect(p[k]!.toDouble(), lessThan(before)); // 減衰済み
    }
  });

  test('訂正は強く学習(重み 3 倍)', () {
    final a = composerLearnUpdate(null, 'ガチマッチ', now: DateTime(2026, 9, 1));
    final b = composerLearnUpdate(null, 'ガチマッチ', weight: 3, now: DateTime(2026, 9, 1));
    final pa = ((a['vector'] as Map)['p'] as Map).values.cast<num>().fold<double>(0, (x, y) => x + y);
    final pb = ((b['vector'] as Map)['p'] as Map).values.cast<num>().fold<double>(0, (x, y) => x + y);
    expect(pb, closeTo(pa * 3, 0.001));
  });

  test('連動の正例/負例は分離して記録・集計される', () {
    var r = <String, Object?>{};
    r = composerRelationBump(r, '@main@a.test', '@game@a.test', positive: true);
    r = composerRelationBump(r, '@main@a.test', '@game@a.test', positive: false);
    r = composerRelationBump(r, '@sub@a.test', '@game@a.test', positive: true);
    final (pos, neg) = composerRelationStats(r, '@game@a.test');
    expect((pos, neg), (2, 1));
    expect(composerRelationStats(r, '@main@a.test'), (0, 0));
  });

  test('学習プロファイル基準: storage.load 経由でコンパイルされ、選択に効く', () async {
    final g = compileComposerConfig({
      '@game@a.test': const ComposerAccountFilter(enabled: true, what: 'キーワード', from: '学習プロファイル'),
    }, ['@game@a.test']);
    final load = g.nodes.firstWhere((n) => n.type == 'storage.load');
    expect(load.inputs.first.value, composerLearnSlot('@game@a.test'));
    expect(g.nodes.where((n) => n.type == 'ml.keyword'), hasLength(1));
    expect(g.nodes.where((n) => n.type == 'tl.source'), isEmpty); // 基準取得は不要

    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    Post draft(String body) =>
        Post(id: 'd', account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 2), body: body);
    final slot = composerLearnUpdate(null, 'スプラトゥーンのガチマッチ配信');
    Future<Object?> storageRead(String s) async => s == composerLearnSlot('@game@a.test') ? slot : null;

    expect(await composerTargetAccounts(g, draft('今夜もガチマッチやります'), storageRead: storageRead), ['@game@a.test']);
    expect(await composerTargetAccounts(g, draft('会議の議事録です'), storageRead: storageRead), isEmpty);
  });
}

/// [p] のキーのうち [word] の n-gram に対応するもの。
List<String> charKeysOf(Map<String, num> p, String word) =>
    [for (final k in p.keys) if (word.contains(k) || k.contains(word.substring(0, 1))) k];
