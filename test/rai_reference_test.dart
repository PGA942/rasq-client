import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_reference_providers.dart';

import '../tool/rai_reference_eval.dart';

/// RAi のリファレンス関数 (D-189): 関数 / 操作リファレンス(jsonl)、引数の preset / input の分離、
/// preset マクロの解決、ハイブリッド検索(ベクトル + キーワード)と評価セット。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<RaiReferenceIndex> load() async => RaiReferenceIndex.fromJsonl(
        functionsJsonl: await rootBundle.loadString(raiFunctionsAsset),
        operationsJsonl: await rootBundle.loadString(raiOperationsAsset),
        embedder: const NgramRaiEmbedder(),
      );

  test('関数リファレンス: できること + 引数は preset(事前に決まる)と input(必ず入力)に分かれる', () async {
    final index = await load();
    final post = index.function('post.create')!;
    expect(post.does, contains('投稿'));
    expect([for (final p in post.inputs) p.name], ['main']);
    expect([for (final p in post.presets) p.name], ['visibility', 'hide', 'replyLimit', 'createdAt']);
    final search = index.function('search.posts')!;
    expect([for (final p in search.inputs) p.name], ['searchIndex']);
    // 全関数: id が一意で、操作リファレンスの fn は全て関数リファレンスに存在する。
    expect(index.functions.map((f) => f.id).toSet().length, index.functions.length);
    for (final op in index.operations) {
      for (final s in op.steps) {
        if (s.fn != null) expect(index.function(s.fn!), isNotNull, reason: '${op.id}: ${s.fn}');
      }
    }
  });

  test('preset のマクロ: \$unixTime / \$unixTime-7d / \$today、それ以外はそのまま', () {
    final presets = RaiPresets(now: DateTime.utc(2026, 9, 12, 0, 0, 0));
    expect(presets.resolve(r'$unixTime'), 1789171200);
    expect(presets.resolve(r'$unixTime-7d'), 1789171200 - 7 * 86400);
    expect(presets.resolve(r'$unixTime+1h'), 1789171200 + 3600);
    expect(presets.resolve(r'$today'), '2026-09-12');
    expect(presets.resolve('public'), 'public');
    expect(presets.resolve(false), false);
    expect(presets.resolve(0), 0);
  });

  test('操作の展開: 関数の部品 / 画面を引き継ぎ、input の表示名と解決済み preset が付く', () async {
    final index = await load();
    final steps = index.expand(index.operation('login-bluesky')!, presets: RaiPresets(now: DateTime.utc(2026, 9, 12)));
    expect(steps.length, 2);
    expect(steps.first.fn, 'login.bluesky');
    expect(steps.first.label, 'Blueskyでログイン'); // 関数の target
    expect(steps.first.route, '/login');
    expect(steps.first.inputs, ['ハンドル', 'アプリパスワード']);
    expect(steps.first.presets, {'PDS': 'bsky.social'});
    expect(steps.last.label, 'ログイン'); // 手順側の target
    final post = index.expand(index.operation('post')!, presets: RaiPresets(now: DateTime.utc(2026, 9, 12)));
    expect(post.first.tooltip, '投稿'); // composer.open の target
    expect(post.first.route, '/home');
    expect(post.last.presets['作成時刻'], 1789171200);
    // 提案文: 1 行目が見出し、以降は 関数〔id〕入力 / 固定。
    final lines = proposalLines(index.operation('login-bluesky')!, steps);
    expect(lines.first, contains('Bluesky でログイン'));
    expect(lines[1], contains('〔login.bluesky〕'));
    expect(lines[1], contains('入力: ハンドル、アプリパスワード'));
    expect(lines[1], contains('固定: PDS=bsky.social'));
  });

  test('語尾 / 終止形の語幹化 (stemJa)', () {
    expect(stemJa('投稿したい'), '投稿');
    expect(stemJa('リノートするには'), 'リノート');
    expect(stemJa('下書きはどこ'), '下書き');
    expect(stemJa('つぶやくには？'), 'つぶやく');
    expect(stemJa('ログイン'), 'ログイン');
  });

  test('ハイブリッド検索: 入力そのまま / シチュエーション付き、閾値未満は空、記録が残る', () async {
    final index = await load();
    final raw = await index.searchOperations('Blueskyでログインしたい');
    expect(raw.first.item.id, 'login-bluesky');
    expect(raw.first.vector, greaterThan(0));
    expect(raw.first.keyword, greaterThanOrEqualTo(0.9));
    expect(await index.searchOperations('zzzz qqqq'), isEmpty);
    expect(await index.searchOperations('   '), isEmpty);
    // シチュエーション(LLM の一文)が付くと、それでも引ける。
    final sit = await index.searchOperations('あの人にこっそり伝えたい', situation: 'DM でメッセージを送りたい');
    expect(sit.first.item.id, 'dm');
    expect(index.traces.first.mode, RaiSearchMode.situation);
    expect(index.traces.first.situation, 'DM でメッセージを送りたい');
    expect(index.traces.first.toString(), contains('dm:'));
    // 関数リファレンスも引ける。
    final fns = await index.searchFunctions('画像を添付');
    expect(fns.first.item.id, 'post.attach');
    // 旧契約 (matchInstruction) も同じ操作を返す。
    expect(index.matchInstruction('つぶやくには？')?.instruction.id, 'post');
    expect(index.matchInstruction('zzzz qqqq'), isNull);
  });

  test('評価セット (assets/rai/eval.jsonl): n-gram 埋め込みでも top-1 が 9 割以上', () async {
    final index = await load();
    final evals = parseJsonl(await rootBundle.loadString(raiEvalAsset));
    expect(evals.length, greaterThanOrEqualTo(20));
    final r = await evaluate(index, evals);
    expect(r.top1, greaterThanOrEqualTo(0.9), reason: r.misses.map((m) => '${m.query} → ${m.got}').join('; '));
    expect(r.topK, greaterThanOrEqualTo(0.95));
  });
}
