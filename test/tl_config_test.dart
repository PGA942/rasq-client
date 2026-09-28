import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/nodeprog/node_editor_screen.dart';
import 'package:rasq_client/features/nodeprog/node_executor.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-121: TL カスタマイズの簡略化 — SNSタイムライン + アルゴリズムの
/// コンポーネント積みを正準形ノードグラフへコンパイルする。
void main() {
  test('コンパイル: 取得×1 + 時系列順 + クロック → 正準形フルチェーン', () {
    final g = compileTlConfig(const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'chrono')]), scope: 'tl.home');
    expect({for (final n in g.nodes) n.type}, {'tl.source', 'timeline', 'clock'});
    expect(g.edges.where((e) => e.toIcon).length, 1); // クロック → 取得ノードのアイコン (D-095)
    expect(nodeGraphClockInterval(g), const Duration(seconds: 15));
  });

  test('コンパイル: 取得×2 はマージ、サジェスト/TLプラグインは鎖の段に', () {
    final g = compileTlConfig(
      const TlConfig(
        sources: [TlSourceComponent(tl: 'home'), TlSourceComponent(tl: 'local', account: '@sub@other.test')],
        algorithms: [
          TlAlgorithmComponent(type: 'suggest', what: 'キーワード', from: 'リアクション'),
          TlAlgorithmComponent(type: 'plugin:dict', pluginLabel: '辞書でソート'),
        ],
        clock: '',
      ),
      scope: 'tl.home',
    );
    final types = {for (final n in g.nodes) n.type};
    expect(types, containsAll(['merge', 'sort', 'ml.gliner', 'ml.keyword', 'compare', 'plugin:dict', 'timeline']));
    expect(types, isNot(contains('clock')));
    // サジェストの基準 = リアクション済み (myreactions を TL 値に持つ取得ノード)。
    expect(g.nodes.where((n) => n.type == 'tl.source' && n.inputs.first.value == 'myreactions'), hasLength(1));
    // 鎖: merge → sort → plugin → timeline(データエッジを辿って確認)。
    String? upstreamOf(String id) => g.edges.where((e) => !e.cond && !e.toIcon && e.to == id && e.toPort == 0).firstOrNull?.from;
    final t = g.nodes.firstWhere((n) => n.type == 'timeline');
    final plugin = upstreamOf(t.id)!;
    expect(g.nodes.firstWhere((n) => n.id == plugin).type, 'plugin:dict');
    final sort = upstreamOf(plugin)!;
    expect(g.nodes.firstWhere((n) => n.id == sort).type, 'sort');
    expect(g.nodes.firstWhere((n) => n.id == upstreamOf(sort)!).type, 'merge');
  });

  test('コンパイル: 関連スコープの終端は関連タイムライン (D-102)', () {
    final g = compileTlConfig(defaultTlConfig('tl.relational'), scope: 'tl.relational');
    expect(g.nodes.where((n) => n.type == 'timeline.relational'), hasLength(1));
  });

  test('D-124: self/リスト/トレンドの既定構成とコンパイル(トレンド枠チェーン付き)', () {
    expect(defaultTlConfig('trend').sources.single.tl, 'self');
    expect(defaultTlConfig('trend.users').sources.single.tl, 'self');
    expect(defaultTlConfig('trend.following').sources.single.tl, 'home');
    expect(defaultTlConfig('tl.list:abc123').sources.single.tl, 'list:abc123');

    final g = compileTlConfig(defaultTlConfig('trend'), scope: 'trend');
    final src = g.nodes.firstWhere((n) => n.type == 'tl.source');
    expect(src.inputs.first.value, 'self'); // 基礎TLの自己参照
    expect({for (final n in g.nodes) n.type}, containsAll(['trend.tags', 'trend.frame'])); // トレンド枠の既定チェーンも添える
  });

  test('コンパイル: リスト系 → tl.list、現在のトレンドTL → trend.posts (D-122)', () {
    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'list:推しの人たち'), TlSourceComponent(tl: 'trend')], algorithms: [], clock: ''),
      scope: 'tl.home',
    );
    final list = g.nodes.firstWhere((n) => n.type == 'tl.list');
    expect(list.inputs.firstWhere((p) => p.label == 'リスト').value, '推しの人たち');
    expect(g.nodes.where((n) => n.type == 'trend.posts'), hasLength(1));
    expect(g.nodes.where((n) => n.type == 'merge'), hasLength(1));
  });

  test('実行: 類似性×投稿内容のサジェストが基準に近い投稿を先頭へ', () async {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    Post post(String id, String body) =>
        Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 1), body: body);

    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'suggest', what: '類似性', from: '投稿内容')], clock: ''),
      scope: 'tl.home',
    );
    final out = await runNodeGraph(
      g,
      fetch: (kid) async => switch (kid) {
        'myposts' => [post('ref', '猫がかわいい。猫の写真を撮った')],
        _ => [post('p1', '為替と株価の話題です'), post('p2', '猫がかわいいですね猫')],
      },
    );
    expect([for (final p in out!) p.id], ['p2', 'p1']); // 猫の投稿が先頭
  });


  test('D-125: 検索絞り込みノード — selfQuery/指定ワードで絞る', () async {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    Post post(String id, String body) =>
        Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 1), body: body);
    final posts = [post('p1', '#りんご の話'), post('p2', 'みかんの話')];

    // queryfilter コンポーネント(ワード空)→ selfQuery で絞る。
    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'queryfilter')], clock: ''),
      scope: 'tl.home',
    );
    var out = await runNodeGraph(g, fetch: (_) async => posts, selfQuery: 'りんご');
    expect([for (final p in out!) p.id], ['p1']);

    // 指定ワードは selfQuery より優先。
    final g2 = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'queryfilter', query: 'みかん')], clock: ''),
      scope: 'tl.home',
    );
    out = await runNodeGraph(g2, fetch: (_) async => posts, selfQuery: 'りんご');
    expect([for (final p in out!) p.id], ['p2']);

    // 除外 (D-227): ワードを含む投稿を落とす(ワードミュート)。JSON 往復でも残る。
    const ex = TlAlgorithmComponent(type: 'queryfilter', query: 'みかん', exclude: true);
    expect(TlAlgorithmComponent.fromJson(ex.toJson()).exclude, isTrue);
    expect(ex.title, '検索絞り込み(除外)');
    final g3 = compileTlConfig(const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [ex], clock: ''), scope: 'tl.home');
    expect(g3.nodes.firstWhere((n) => n.type == 'filter.query').inputs.firstWhere((i) => i.label == '除外').value, 'true');
    out = await runNodeGraph(g3, fetch: (_) async => posts, selfQuery: 'りんご');
    expect([for (final p in out!) p.id], ['p1']);

    // trend.following の既定構成に検索絞り込みが入っている。
    expect(defaultTlConfig('trend.following').algorithms.first.type, 'queryfilter');
  });

  test('D-125: 絞り込みコンポーネント — remove + Not + 比較にコンパイルされ、合わない投稿を除外', () async {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    Post post(String id, String body) =>
        Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 1), body: body);

    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'home')], algorithms: [TlAlgorithmComponent(type: 'filter', what: '類似性', from: '投稿内容')], clock: ''),
      scope: 'tl.home',
    );
    expect({for (final n in g.nodes) n.type}, containsAll(['remove', 'not', 'compare', 'ml.siglip', 'ml.similar']));
    final out = await runNodeGraph(
      g,
      fetch: (kid) async => switch (kid) {
        'myposts' => [post('ref', '猫がかわいい。猫の写真を撮った')],
        _ => [post('p1', '為替と株価の話題です'), post('p2', '猫がかわいいですね猫')],
      },
    );
    expect([for (final p in out!) p.id], ['p2']); // 合わない p1 は除外
  });

  test('D-125: コンポーザーの絞り込み — 有効アカウントだけポスト先になり、下書きの一致で選ばれる', () async {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    Post post(String id, String body) =>
        Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 1), body: body);

    final g = compileComposerConfig({
      '@game@a.test': const ComposerAccountFilter(enabled: true, what: 'キーワード', from: '投稿内容'),
      '@work@b.test': const ComposerAccountFilter(enabled: false),
    }, ['@game@a.test', '@work@b.test']);
    // 無効アカウントはポスト先ノード自体が無い。
    expect(g.nodes.where((n) => n.type == 'composer.target'), hasLength(1));

    Future<List<Post>> fetch(String kid) async =>
        kid == 'acct:@game@a.test|myposts' ? [post('ref', 'スプラトゥーンのガチマッチ配信')] : const [];
    final hit = await composerTargetAccounts(g, post('d1', '今夜もガチマッチやります'), fetch: fetch);
    expect(hit, ['@game@a.test']);
    final miss = await composerTargetAccounts(g, post('d2', '会議の議事録を共有します'), fetch: fetch);
    expect(miss, isEmpty);
  });


  test('D-126: 代わりのフォーマットで投稿 — 絞り込みに合わないとフォールバック候補になる', () async {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    Post post(String id, String body) =>
        Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 2), body: body);

    final g = compileComposerConfig({
      '@game@a.test': const ComposerAccountFilter(enabled: true, what: 'キーワード', from: '投稿内容', fallbackEnabled: true, fallbackFormat: 'フォロワー限定'),
    }, ['@game@a.test']);
    // フォールバックは比較の Not からバイパス (無くなる直前のノードから)。
    expect({for (final n in g.nodes) n.type}, containsAll(['composer.target', 'composer.fallback', 'not', 'compare']));

    Future<List<Post>> fetch(String kid) async =>
        kid == 'acct:@game@a.test|myposts' ? [post('ref', 'スプラトゥーンのガチマッチ配信')] : const [];
    // 合う → 通常候補(フォールバックなし)。
    final hit = await composerTargetChoices(g, post('d1', '今夜もガチマッチやります'), fetch: fetch);
    expect(hit.single.$1, '@game@a.test');
    expect(hit.single.$2, isNull);
    // 合わない → 代わりのフォーマット(フォロワー限定)で候補に残る。
    final fb = await composerTargetChoices(g, post('d2', '会議の議事録を共有します'), fetch: fetch);
    expect(fb.single.$1, '@game@a.test');
    expect(fb.single.$2, {'format': 'followers', 'cw': ''});
  });

  test('D-127: DM の既定構成と DM 取得ソースのコンパイル', () {
    expect(defaultTlConfig('tl.dm').sources.single.tl, 'self');
    expect(defaultTlConfig('tl.dm:abc').sources.single.tl, 'self');
    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'dm:alice')], algorithms: [], clock: ''),
      scope: 'tl.dm',
    );
    final dm = g.nodes.firstWhere((n) => n.type == 'tl.dm');
    expect(dm.inputs.firstWhere((p) => p.label == '相手').value, 'alice');
  });


  test('D-130: 正規表現加工 — ルール抽出と適用(アカウント限定/不正パターンはスキップ)', () {
    final g = compileComposerConfig({
      '@a@x.test': const ComposerAccountFilter(regexEnabled: true, regexPattern: 'ねこ', regexReplace: '🐱'),
      '@b@y.test': const ComposerAccountFilter(regexEnabled: true, regexPattern: '[', regexReplace: 'x'), // 不正
    }, ['@a@x.test', '@b@y.test']);
    final rules = composerRegexRules(g);
    expect(rules, hasLength(2));
    // a 限定ルールは a にだけ効く。不正パターンは落とさず無視。
    expect(applyComposerRegex('ねこの話', '@a@x.test', rules), '🐱の話');
    expect(applyComposerRegex('ねこの話', '@b@y.test', rules), 'ねこの話');
    // アカウント空 = すべてに適用。
    expect(applyComposerRegex('ねこ', '@b@y.test', [('', 'ねこ', '🐱')]), '🐱');
  });

  test('D-129: 届け方のラベルと既定', () {
    expect(const ComposerAccountFilter().delivery, 'auto');
    expect(composerDeliveryLabel('confirm'), contains('確認'));
    expect(composerDeliveryLabel('draft'), contains('下書き'));
  });


  test('D-131: 追加ノードは「かつ」連結、連動の絞り込みは linkgate、連動元は linkSources', () async {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    Post post(String id, String body) =>
        Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 9, 2), body: body);

    final g = compileComposerConfig({
      '@game@a.test': const ComposerAccountFilter(
        enabled: true,
        what: 'キーワード',
        from: '投稿内容',
        extraFilters: [ComposerFilterSpec(what: 'キーワード', from: 'リアクション')],
        linkFilters: [ComposerFilterSpec(what: 'キーワード', from: '投稿内容')],
      ),
    }, ['@game@a.test']);
    // 追加ノード: 比較が 2 つ + 連動関門(linkgate)にも比較。
    expect(g.nodes.where((n) => n.type == 'compare').length, 3);
    expect(g.nodes.where((n) => n.type == 'composer.linkgate'), hasLength(1));

    // 連動の絞り込み: 基準に合う下書きだけ関門を通る。
    Future<List<Post>> fetch(String kid) async => switch (kid) {
          'acct:@game@a.test|myposts' => [post('ref', 'スプラトゥーンのガチマッチ配信')],
          'acct:@game@a.test|myreactions' => [post('ref2', 'スプラトゥーンのガチマッチ配信')],
          _ => const <Post>[],
        };
    final pass = await composerLinkGates(g, post('d1', '今夜もガチマッチやります'), fetch: fetch);
    expect(pass['@game@a.test'], isTrue);
    final fail = await composerLinkGates(g, post('d2', '会議の議事録です'), fetch: fetch);
    expect(fail['@game@a.test'], isFalse);

    // 連動元のアカウント選択: ['*'] = すべて許可(既定)、リスト指定は限定。
    expect(const ComposerAccountFilter().linkAllowedFrom('@x@y.test'), isTrue);
    const limited = ComposerAccountFilter(linkSources: ['@main@a.test']);
    expect(limited.linkAllowedFrom('@main@a.test'), isTrue);
    expect(limited.linkAllowedFrom('@sub@a.test'), isFalse);
    expect(const ComposerAccountFilter(linkSources: []).linkAllowedFrom('@main@a.test'), isFalse); // 空 = どこからも連動しない

    // 追加の正規表現ノードもルールに載る。
    final g2 = compileComposerConfig({
      '@a@x.test': const ComposerAccountFilter(regexEnabled: true, regexPattern: 'ねこ', regexReplace: '🐱', extraRegexes: [ComposerRegexSpec(pattern: 'いぬ', replace: '🐶')]),
    }, ['@a@x.test']);
    final rules = composerRegexRules(g2);
    expect(rules, hasLength(2));
    expect(applyComposerRegex('ねこといぬ', '@a@x.test', rules), '🐱と🐶');
  });

  Future<ProviderContainer> pumpConfig(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('歯車 → 簡略版カスタマイズ画面: コンポーネント追加でグラフが KV へコンパイルされる', (tester) async {
    final container = await pumpConfig(tester);

    // TL の歯車は簡略版カスタマイズ画面へ (D-121: キャンバスは一旦無効化)。
    expect(find.byType(TimelineConfigScreen), findsOneWidget);
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    expect(inScreen(find.text('アルゴリズム')), findsOneWidget);
    expect(inScreen(find.text('SNSタイムライン')), findsOneWidget);

    // フォロー中タブへ(スコープ = tl.home)。既定は取得×1 + 時系列順。
    await tester.tap(inScreen(find.text('フォロー中')));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('タイムラインを取得')), findsOneWidget);
    expect(inScreen(find.text('時系列順')), findsOneWidget);

    // アルゴリズムを追加 → ノード検索 FOW (D-122): プラグインタイルで
    // 入出力ではなくネイティブ対応の SNS プラグインを表示。
    await tester.tap(inScreen(find.text('アルゴリズムを追加')));
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsOneWidget);
    expect(find.textContaining('対応: Fake'), findsWidgets);
    // パレットの ∨ (D-227): 押すとチップの列が出て、「並び替え」「ジャンル」のドロップダウンが開く
    // (以前はフォーカスの変化で組み直しておらず、∨ にもハンドラが無かった)。
    expect(find.text('並び替え: 関連順'), findsNothing);
    await tester.tap(find.descendant(of: find.byType(RasqExpandableSearchBox), matching: find.byIcon(Icons.keyboard_arrow_down)));
    await tester.pumpAndSettle();
    expect(find.text('並び替え: 関連順'), findsOneWidget);
    await tester.tap(find.text('ジャンル: すべて'));
    await tester.pumpAndSettle();
    expect(container.read(overlayManagerProvider).contains('tlconfig.palette.genre'), isTrue); // ドロップダウンが開いた
    container.read(overlayManagerProvider).close('tlconfig.palette.genre');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RasqExpandableSearchBox), matching: find.byIcon(Icons.keyboard_arrow_down)).first);
    await tester.pumpAndSettle();
    expect(find.text('並び替え: 関連順'), findsNothing); // ∨ でまた畳める
    await tester.tap(find.text('サジェスト'));
    await tester.pumpAndSettle();
    expect(find.text('プラグインノードを検索'), findsNothing); // 追加で閉じる
    expect(inScreen(find.text('キーワードを投稿内容からサジェスト')), findsOneWidget);

    // タイムラインを追加 → FOW の選択肢は [タイムライン, リスト系,
    // 現在のトレンドTL] に絞られている (D-122)。
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    expect(find.text('タイムライン'), findsOneWidget);
    expect(find.text('リストTL'), findsOneWidget); // D-194: リストは追加後にアカウント → リストで選ぶ
    expect(find.text('カスタムフィード(Bluesky)'), findsNothing); // Bluesky アカウントが無い
    expect(find.text('現在のトレンドTL'), findsOneWidget);
    await tester.tap(find.text('現在のトレンドTL'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('現在のトレンドTLを取得')), findsOneWidget);

    // KV: tlcfg(コンポーネント)+ graph(正準形コンパイル、トレンドは
    // trend.posts、2 本目でマージ段)。
    final area = await container.read(settingsAreaProvider('nodeprog.${fakeSession().account.key}.tl.home').future);
    expect(area['tlcfg'], isA<String>());
    final graph = NodeGraph.fromJson((jsonDecode(area['graph']! as String) as Map).cast<String, Object?>());
    final types = {for (final n in graph.nodes) n.type};
    expect(types, containsAll(['merge', 'trend.posts', 'sort', 'ml.gliner', 'ml.keyword', 'compare', 'timeline', 'clock']));

    // アルゴリズムの … → 削除でサジェストが外れる。
    await tester.tap(inScreen(find.byTooltip('アルゴリズムの操作')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('キーワードを投稿内容からサジェスト')), findsNothing);
  });

  testWidgets('D-123: パラメーターFOW(RRL)/一時的な無効化/並べ替えシート/ジャンルチップ', (tester) async {
    final container = await pumpConfig(tester);
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    final manager = container.read(overlayManagerProvider);
    final acc = fakeSession().account.key;

    await tester.tap(inScreen(find.text('フォロー中')));
    await tester.pumpAndSettle();

    // サジェストを追加してからタイルをタップ → パラメーター FOW(RRL の
    // ラジオ)。「類似性」を選ぶとタイトルが追従する。
    await tester.tap(inScreen(find.text('アルゴリズムを追加')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('サジェスト'));
    await tester.pumpAndSettle();
    await tester.tap(inScreen(find.text('キーワードを投稿内容からサジェスト')));
    await tester.pumpAndSettle();
    expect(find.text('なにをサジェストする?'), findsOneWidget); // RRL SectionHeader
    expect(find.text('ノードを設定'), findsOneWidget); // 決定/キャンセルヘッダー (D-124)
    await tester.tap(find.text('類似性'));
    await tester.pumpAndSettle();
    expect(find.text('類似性を投稿内容からサジェスト'), findsWidgets); // タイル + FOW ヘッダー
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    expect(find.text('ノードを設定'), findsNothing); // 決定で閉じて確定
    expect(inScreen(find.text('類似性を投稿内容からサジェスト')), findsOneWidget);

    // キャンセル = 巻き戻し (D-124: 絵文字ピッカーの作法)。
    await tester.tap(inScreen(find.text('類似性を投稿内容からサジェスト')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キーワード'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('類似性を投稿内容からサジェスト')), findsOneWidget); // 巻き戻った
    expect(inScreen(find.text('キーワードを投稿内容からサジェスト')), findsNothing);

    // … → 一時的な無効化: タイルがグレー表記になり、コンパイルから外れる。
    await tester.tap(inScreen(find.byTooltip('アルゴリズムの操作')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('一時的な無効化'));
    await tester.pumpAndSettle();
    expect(find.textContaining('無効化中'), findsOneWidget);
    var area = await container.read(settingsAreaProvider('nodeprog.$acc.tl.home').future);
    var types = {for (final n in NodeGraph.fromJson((jsonDecode(area['graph']! as String) as Map).cast<String, Object?>()).nodes) n.type};
    expect(types, isNot(contains('sort'))); // 無効化された段は消える

    // 並べ替えシート(アクションバー編集と同じ UI): 目のトグルで解除。
    await tester.tap(inScreen(find.byTooltip('アルゴリズムの並べ替え')));
    await tester.pumpAndSettle();
    expect(find.text('アルゴリズムの並べ替え'), findsWidgets); // シートタイトル
    expect(find.byIcon(Icons.drag_handle), findsWidgets);
    await tester.tap(find.byTooltip('無効化の解除'));
    await tester.pumpAndSettle();
    area = await container.read(settingsAreaProvider('nodeprog.$acc.tl.home').future);
    types = {for (final n in NodeGraph.fromJson((jsonDecode(area['graph']! as String) as Map).cast<String, Object?>()).nodes) n.type};
    expect(types, contains('sort')); // 解除で戻る
    manager.close('tlconfig.reorder');
    await tester.pumpAndSettle();

    // ジャンルチップ (D-123): タイムライン側パレットを「リスト系」に絞る。
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    expect(find.text('タイムライン'), findsOneWidget);
    await tester.tap(find.text('プラグインノードを検索')); // 検索欄フォーカスでチップ表示
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('ジャンル: すべて'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リスト系').last); // ドロップダウン項目
    await tester.pumpAndSettle();
    expect(find.text('タイムライン'), findsNothing);
    expect(find.text('リストTL'), findsOneWidget);
  });

  testWidgets('D-124: 「グラフで編集」→ ノードエディタ。グラフ編集で tlcfg は破棄され手組み扱いに', (tester) async {
    final container = await pumpConfig(tester);
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    final acc = fakeSession().account.key;

    await tester.tap(inScreen(find.text('フォロー中')));
    await tester.pumpAndSettle();
    // 何か編集して tlcfg を作る(自動更新: 15秒 → 1分)。
    await tester.tap(inScreen(find.textContaining('間隔:')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1分'));
    await tester.pumpAndSettle();
    var area = await container.read(settingsAreaProvider('nodeprog.$acc.tl.home').future);
    expect(area['tlcfg'], isA<String>());

    // … → グラフで編集 (D-124: ノードの調節はグラフ形式で編集)。
    await tester.tap(find.byTooltip('その他'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('グラフで編集'));
    await tester.pumpAndSettle();
    expect(find.byType(NodeEditorScreen), findsOneWidget);

    // キャンバスで編集(コピー → ペースト)するとグラフが正になり tlcfg 破棄。
    final onCanvas = find.descendant(of: find.byType(NodeEditorScreen), matching: find.text('タイムライン取得'));
    await tester.tap(onCanvas.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('コピー'));
    await tester.pumpAndSettle();
    await tester.tap(onCanvas.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ペースト'));
    await tester.pumpAndSettle();
    area = await container.read(settingsAreaProvider('nodeprog.$acc.tl.home').future);
    expect(area['tlcfg'], isNull);

    // 戻ると簡易側は「ノードで編集済み」の置き換え警告。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ノードエディタで編集されています'), findsOneWidget);
  });

  testWidgets('D-127: DM 設定画面 — 共通タブ + DM 取得タイルだけのパレット', (tester) async {
    final container = await pumpConfig(tester); // TL 設定を開いた状態から DM 設定へ遷移
    container.read(routerProvider).push(Routes.tlConfig('tl.dm'));
    await tester.pumpAndSettle();

    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    expect(find.text('DM(共通)'), findsOneWidget);
    expect(find.textContaining('すべての DM ページに使う設定'), findsOneWidget);
    expect(inScreen(find.text('このタイムラインを取得')), findsOneWidget); // 既定 = self

    // 取得元パレットは DM 取得用のタイルだけ (D-127)。
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    expect(find.text('このDM'), findsOneWidget);
    expect(find.textContaining('DM: @'), findsWidgets);
    expect(find.text('タイムライン'), findsNothing);
    expect(find.text('現在のトレンドTL'), findsNothing);
  });

  testWidgets('D-127: DM ルームに共通設定(tl.dm)のグラフが適用される', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const acc2 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'peer');
    Post dmPost(String id, String body) =>
        Post(id: id, account: acc2, author: const UserSummary(id: 'peer1', account: acc2, displayName: '相手'), createdAt: DateTime(2026, 9, 2), body: body);

    // 共通設定: self → 消去(本文に「消して」)→ タイムライン。
    final cfg = TlConfig(sources: const [TlSourceComponent(tl: 'self')], algorithms: const [TlAlgorithmComponent(type: 'filter')], clock: '');
    // filter は ML 依存なので、確実な cond 消去のグラフを直接コンパイルする
    // 代わりに queryfilter(ワード指定)で組む。
    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'self')], algorithms: [TlAlgorithmComponent(type: 'queryfilter', query: '残る')], clock: ''),
      scope: 'tl.dm',
    );
    expect(cfg, isNotNull);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
      'nodeprog.${fakeSession().account.key}.tl.dm.v1': jsonEncode({'graph': jsonEncode(g.toJson())}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [dmPost('a', '残るメッセージ'), dmPost('b', '関係ない話')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));

    // DM ルームを直接開く(ページ個別設定なし → tl.dm の共通設定が効く)。
    // fakes の dm: 取得は最後の 1 件(関係ない話)だけを返す — 共通設定の
    // 検索絞り込み(残る)がそれを落とすので、空になれば適用の証拠。
    container.read(routerProvider).push('/dm/room/peer1');
    await tester.pumpAndSettle();
    expect(find.text('関係ない話'), findsNothing);
    expect(find.text('まだメッセージはありません'), findsOneWidget);
  });

  test('D-194: カスタムフィード(feed:<uri>)は tl.feed ノードにコンパイルされ、表示名を持つ', () {
    final g = compileTlConfig(
      const TlConfig(sources: [TlSourceComponent(tl: 'feed:at://did:plc:x/app.bsky.feed.generator/cats', account: '@alice.bsky.social@bsky.social', label: 'Cats')], algorithms: [TlAlgorithmComponent(type: 'chrono')], clock: ''),
      scope: 'tl.home',
    );
    final feed = g.nodes.singleWhere((n) => n.type == 'tl.feed');
    expect(feed.inputs.firstWhere((i) => i.label == 'フィード').value, 'at://did:plc:x/app.bsky.feed.generator/cats');
    expect(feed.inputs.firstWhere((i) => i.label == 'アカウント').value, '@alice.bsky.social@bsky.social');
    final round = TlSourceComponent.fromJson(const TlSourceComponent(tl: 'feed:at://x', label: 'Cats').toJson());
    expect(round.isFeed, isTrue);
    expect(round.feedUri, 'at://x');
    expect(round.label, 'Cats');
  });

  testWidgets('D-194: TL 種別はアカウントの SNS が出せるもの(「現在のアカウント」は無し)、リストTL はアカウント → リスト、Bluesky はカスタムフィードを検索して選ぶ', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final bsky = AccountSession(account: const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'alice.bsky.social'), pluginId: 'test.bsky', token: 't', createdAt: DateTime(2026, 9, 1), displayName: 'アリス');
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson(), bsky.toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(posts: MockData.timeline))
      ..register(FakeSnsPlugin(posts: MockData.timeline, kind: SnsKind.bluesky, id: 'test.bsky', feeds: const [FeedInfo(uri: 'at://did:plc:x/app.bsky.feed.generator/cats', name: 'Cats', description: 'ねこのフィード'), FeedInfo(uri: 'at://did:plc:x/app.bsky.feed.generator/dogs', name: 'Dogs')]));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    await tester.tap(inScreen(find.text('フォロー中')));
    await tester.pumpAndSettle();
    // タイムラインを追加 → アカウントは現在のもの、TL 種別はその SNS の宣言(フェイク: フォロー中 / ソーシャル)。
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('タイムライン'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('@tester@example.test')), findsWidgets);
    await tester.tap(inScreen(find.text('タイムラインを取得')).last);
    await tester.pumpAndSettle();
    expect(find.text('ノードを設定'), findsOneWidget);
    expect(find.text('現在のアカウント'), findsNothing);
    expect(find.text('TL 種別(この SNS が出せるもの)'), findsOneWidget);
    expect(find.text('ソーシャル'), findsOneWidget);
    expect(find.text('ローカル (local)'), findsNothing); // 決め打ちの 4 種は出ない
    await tester.tap(find.text('ソーシャル'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('TL: ソーシャル')), findsOneWidget);
    // リストTL → アカウントのリスト(フェイク: Fediverse Banner)を選ぶ。
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リストTL'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('TL: リスト: 未選択')), findsOneWidget);
    await tester.tap(inScreen(find.text('リストTLを取得')));
    await tester.pumpAndSettle();
    expect(find.text('リスト(このアカウントのもの)'), findsOneWidget);
    await tester.tap(find.text('Fediverse Banner'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('TL: リスト: Fediverse Banner')), findsOneWidget);
    // カスタムフィード(Bluesky): 検索して選ぶ。
    await tester.tap(inScreen(find.text('タイムラインを追加')));
    await tester.pumpAndSettle();
    expect(find.text('カスタムフィード(Bluesky)'), findsOneWidget);
    await tester.tap(find.text('カスタムフィード(Bluesky)'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('@alice.bsky.social@bsky.social')), findsWidgets);
    await tester.tap(inScreen(find.text('カスタムフィードを取得')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tlcfg.feed.search')), findsOneWidget);
    expect(find.text('Cats'), findsOneWidget); // 検索前は人気順(全部)
    expect(find.text('Dogs'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('tlcfg.feed.search')), 'cat');
    await tester.pumpAndSettle();
    expect(find.text('Dogs'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tlcfg.feed.at://did:plc:x/app.bsky.feed.generator/cats')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    expect(inScreen(find.text('TL: フィード: Cats')), findsOneWidget);
    final area = await container.read(settingsAreaProvider('nodeprog.${fakeSession().account.key}.tl.home').future);
    final graph = NodeGraph.fromJson((jsonDecode(area['graph']! as String) as Map).cast<String, Object?>());
    final feed = graph.nodes.singleWhere((n) => n.type == 'tl.feed');
    expect(feed.inputs.firstWhere((i) => i.label == 'フィード').value, 'at://did:plc:x/app.bsky.feed.generator/cats');
    expect(feed.inputs.firstWhere((i) => i.label == 'アカウント').value, '@alice.bsky.social@bsky.social');
    expect(graph.nodes.where((n) => n.type == 'tl.list').single.inputs.firstWhere((i) => i.label == 'リスト').value, 'Fediverse Banner');
  });
}
