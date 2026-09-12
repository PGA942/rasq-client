import 'dart:io';

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
    expect(sit.first.item.id, anyOf('dm', 'dm-new'));
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

  test('評価セット (assets/rai/eval.jsonl): 先頭 25 問(語の一致)は n-gram 代替でも top-1 85% 以上、全体(言い換え 234 問)は top-3 を報告', () async {
    final index = await load();
    final evals = parseJsonl(await rootBundle.loadString(raiEvalAsset));
    expect(evals.length, greaterThanOrEqualTo(200));
    final keyword = await evaluate(index, evals.take(25).toList());
    expect(keyword.top1, greaterThanOrEqualTo(0.85), reason: keyword.misses.map((m) => '${m.query} → ${m.got}').join('; '));
    final all = await evaluate(index, evals);
    // ignore: avoid_print
    print('ngram all: top1=${(all.top1 * 100).toStringAsFixed(1)}% top3=${(all.topK * 100).toStringAsFixed(1)}%');
    expect(all.topK, greaterThanOrEqualTo(0.5)); // 言い換えは埋め込みモデルの仕事(D-192 の計測を参照)
  });

  test('分岐 (D-192): base の先頭 branchAt 手順を共有して枝の手順が続く、循環 / 不明な base は自分の手順だけ', () async {
    final index = await load();
    final ops = [
      ...index.operations,
      const RaiOperation(id: 'test-poll', index: '投票を付けて投稿', base: 'post', branchAt: 1, steps: [RaiOperationStep(say: '投票を足します')]),
      const RaiOperation(id: 'test-poll-multi', index: '複数選択の投票', base: 'test-poll', branchAt: 2, steps: [RaiOperationStep(say: '複数選択にします')]),
      const RaiOperation(id: 'loop-a', index: 'a', base: 'loop-b', branchAt: 1, steps: [RaiOperationStep(say: 'a')]),
      const RaiOperation(id: 'loop-b', index: 'b', base: 'loop-a', branchAt: 1, steps: [RaiOperationStep(say: 'b')]),
      const RaiOperation(id: 'orphan', index: 'o', base: 'nope', branchAt: 3, steps: [RaiOperationStep(say: 'o')]),
    ];
    final idx = await RaiReferenceIndex.build(functions: index.functions, operations: ops, embedder: const NgramRaiEmbedder());
    final poll = idx.expand(idx.operation('test-poll')!);
    expect([for (final s in poll) s.text], ['右下の「投稿」でコンポーザーが開きます', '投票を足します']);
    expect(poll.first.tooltip, '投稿'); // 共有した手順は関数の部品も引き継ぐ
    final multi = idx.expand(idx.operation('test-poll-multi')!);
    expect([for (final s in multi) s.text], ['右下の「投稿」でコンポーザーが開きます', '投票を足します', '複数選択にします']);
    expect([for (final s in idx.expand(idx.operation('loop-a')!)) s.text], ['b', 'a']); // 循環は 1 周で切れる
    expect([for (final s in idx.expand(idx.operation('orphan')!)) s.text], ['o']);
  });

  test('整合性: 分岐先が存在し、target のツールチップ / 表示テキストと route が実際のコードにある', () async {
    final index = await load();
    // lib/ と packages/*/lib の Dart、assets の yaml / json の中身をそのまま持ち、部品の文字列が含まれるかを見る。
    final texts = <String>[];
    final sources = [
      ...Directory('lib').listSync(recursive: true),
      for (final d in Directory('packages').listSync().whereType<Directory>())
        if (Directory('${d.path}/lib').existsSync()) ...Directory('${d.path}/lib').listSync(recursive: true),
      ...Directory('assets').listSync(recursive: true).where((f) => !f.path.contains('/rai/')),
    ];
    for (final f in sources.whereType<File>()) {
      if (f.path.endsWith('.dart') || f.path.endsWith('.yaml') || f.path.endsWith('.yml') || f.path.endsWith('.json')) texts.add(f.readAsStringSync());
    }
    final routes = <String>{};
    for (final m in RegExp(r"'(/[a-z0-9/_-]*)'").allMatches(File('lib/app/router.dart').readAsStringSync())) {
      routes.add(m.group(1)!);
    }
    final literals = _Contains(texts);
    final problems = <String>[];
    void checkTarget(String where, RaiTarget? t, String? route) {
      final s = t?.tooltip ?? t?.label;
      if (s != null && !literals.has("'$s'") && !literals.has('"$s"')) problems.add('$where: 部品 "$s" がコードに無い');
      if (route != null && !routes.contains(route)) problems.add('$where: route $route がコードに無い');
    }
    for (final op in index.operations) {
      if (op.base != null) {
        expect(index.operation(op.base!), isNotNull, reason: '${op.id}: base ${op.base}');
        expect(op.branchAt, lessThanOrEqualTo(index.resolvedSteps(index.operation(op.base!)!).length), reason: '${op.id}: branchAt');
      }
      expect(index.expand(op), isNotEmpty, reason: op.id);
      for (final s in op.steps) {
        checkTarget(op.id, s.target, s.route);
        if (s.fn != null) expect(index.function(s.fn!), isNotNull, reason: '${op.id}: fn ${s.fn}');
      }
    }
    for (final f in index.functions) {
      checkTarget(f.id, f.target, f.route);
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
    expect(index.operations.map((o) => o.id).toSet().length, index.operations.length);
  });
}

class _Contains {
  _Contains(this.texts);
  final List<String> texts;
  bool has(String s) => texts.any((t) => t.contains(s));
}
