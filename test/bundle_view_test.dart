import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/home/post_duplicates.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-087/D-088: サイドバーのアカウントバンドルタイル(RASQ アカウント)と
/// 総合表示 — バンドルタイル短押しで全アカウント合流の「総合」TL、個別
/// アカウント押下で現状どおりの単独表示に戻る。
void main() {
  const acc1 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  const acc2 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second');
  AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: a.handle);

  Post postOf(AccountId v) => Post(
      id: 'p-${v.handle}',
      account: v,
      author: UserSummary(id: 'u-${v.handle}', account: v, displayName: v.handle),
      createdAt: DateTime(2026, 8, 31, 10),
      body: '${v.handle} の投稿');

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [session(acc1).toJson(), session(acc2).toJson()],
        'current': acc1.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  testWidgets('バンドルタイル短押し → 総合表示(両アカウントの投稿が合流)、個別選択で戻る', (tester) async {
    final container = await pump(tester);

    // 通常表示: 現在アカウントの投稿だけ。
    expect(find.text('tester の投稿'), findsOneWidget);
    expect(find.text('second の投稿'), findsNothing);

    // サイドバー: RASQ アカウント(素の @handle)+ アカウント行(handle@instance)。
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    Finder inSidebar(Finder f) => find.descendant(of: find.byType(RasqSidebar), matching: f);
    expect(inSidebar(find.text('@tester')), findsOneWidget); // バンドルタイル(インスタンスなし)
    expect(inSidebar(find.text('@tester@example.test')), findsOneWidget);
    expect(inSidebar(find.text('@second@example.test')), findsOneWidget);

    // ^ でアカウントリストを閉じる/開く (D-087)。
    await tester.tap(find.byTooltip('アカウントリストを隠す'));
    await tester.pumpAndSettle();
    expect(inSidebar(find.text('@second@example.test')), findsNothing);
    await tester.tap(find.byTooltip('アカウントリストを表示'));
    await tester.pumpAndSettle();

    // バンドルタイル短押し → 総合表示。タブは「総合」になり両方の投稿が流れる。
    await tester.tap(inSidebar(find.text('@tester')));
    await tester.pumpAndSettle();
    expect(container.read(bundleViewProvider), isTrue);
    expect(find.text('総合'), findsOneWidget);
    expect(find.text('tester の投稿'), findsOneWidget);
    expect(find.text('second の投稿'), findsOneWidget);

    // 個別アカウントを選ぶと総合表示を抜けてそのアカウント単独に戻る。
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();
    expect(container.read(bundleViewProvider), isFalse);
    expect(container.read(currentAccountProvider), acc2);
    expect(find.text('second の投稿'), findsOneWidget);
    expect(find.text('tester の投稿'), findsNothing);
  });

  testWidgets('D-089: コンポーザーのバンドルタイルで投稿先を選ぶと、そのアカウントで送信される', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = await pump(tester);
    final registry = container.read(pluginRegistryProvider);

    await openHomeComposer(tester);
    await tester.pumpAndSettle();

    // アバターをタップするとバンドルタイル(投稿先リスト)が出てくる (D-091)。
    expect(find.text('投稿先のカスタマイズ'), findsNothing);
    await tester.tap(find.byTooltip('投稿先を選ぶ'));
    await tester.pumpAndSettle();
    expect(find.text('投稿先のカスタマイズ'), findsOneWidget);
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();
    expect(find.text('投稿先のカスタマイズ'), findsNothing); // 選択でタイルは閉じる

    await tester.enterText(find.byType(TextField).last, 'バンドルからの投稿');
    await tester.pumpAndSettle();
    await tester.tap(find.text('送信'));
    await tester.pumpAndSettle();

    // second のセッションに届いている(現在アカウント tester ではなく)。
    final s2 = registry.session(session(acc2)) as FakeSnsSession;
    expect(s2.lastDraft?.text, 'バンドルからの投稿');
    final s1 = registry.session(session(acc1)) as FakeSnsSession;
    expect(s1.lastDraft, isNull);
  });

  testWidgets('D-110: 複数アカウントに流れてきた同一投稿は 1 枚に畳み、↓ でアカウント選択', (tester) async {
    // 同じ著者(id+ドメイン)+ 同じ本文 — インスタンスの違いで投稿 id は別。
    Post buzz(AccountId viewer, String id) => Post(
        id: id,
        account: viewer,
        author: const UserSummary(id: 'u-pop', account: AccountId(kind: SnsKind.misskey, instance: 'home.test', handle: 'popular'), displayName: 'ポピュラー'),
        createdAt: DateTime(2026, 9, 1, 12),
        body: 'バズった投稿');
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [session(acc1).toJson(), session(acc2).toJson()],
        'current': acc1.key,
        'bundle': true,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [buzz(v, 'b-${v.handle}'), postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    // 総合 TL: 同一投稿は 1 枚だけ(表示崩れ対策)。
    expect(find.text('バズった投稿'), findsOneWidget);
    expect(find.text('tester の投稿'), findsOneWidget); // 別内容はそのまま
    expect(find.text('second の投稿'), findsOneWidget);

    // ↓(アカウント選択)は畳んだタイルにだけ出る。
    expect(find.byTooltip('アカウント選択'), findsOneWidget);
    await tester.tap(find.byTooltip('アカウント選択'));
    await tester.pumpAndSettle();
    expect(find.text('@tester@example.test'), findsOneWidget);
    expect(find.text('@second@example.test'), findsOneWidget);
    await tester.tap(find.text('@second@example.test'));
    await tester.pumpAndSettle();

    // 選択は保持される(開き直すと second 側にチェック)。表示は 1 枚のまま。
    expect(find.text('バズった投稿'), findsOneWidget);
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    expect(container.read(postAlternatesProvider), isNotEmpty);

    // ↓ で second を選んだままタイルを開く → second のコピー(b-second)のスレッドが
    // second のセッションで展開される (D-155)。返信の投稿先も second。
    await tester.tap(find.text('バズった投稿'));
    await tester.pumpAndSettle();
    expect(find.text('投稿'), findsWidgets); // スレッド展開画面
    final s1 = registry.session(session(acc1)) as FakeSnsSession;
    final s2 = registry.session(session(acc2)) as FakeSnsSession;
    expect(s2.threadRequests, ['b-second']);
    expect(s1.threadRequests, isEmpty);
    await tester.enterText(find.byType(TextField).last, '@popular second から返信');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '返信').last);
    await tester.pumpAndSettle();
    expect(s2.lastDraft?.text, contains('second から返信'));
    expect(s1.lastDraft, isNull);
  });

  testWidgets('D-108: バンドルでノードTLを集合表示 — 他アカウントのタブが並び、中身は持ち主のセッションで動く', (tester) async {
    // acc2 のノード TL タブ + グラフ(取得 home → タイムライン)をアカウント
    // 領域にシードし、総合表示で開く。
    final src = builtinNodeCatalog.firstWhere((e) => e.type == 'tl.source').instantiate('n1', Offset.zero);
    final tl = builtinNodeCatalog.firstWhere((e) => e.type == 'timeline').instantiate('n3', Offset.zero);
    final graph = NodeGraph(nodes: [src.copyWith(inputs: [src.inputs[0].copyWith(value: 'home')]), tl], edges: const [GraphEdge(from: 'n1', fromPort: 0, to: 'n3', toPort: 0)]);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [session(acc1).toJson(), session(acc2).toJson()],
        'current': acc1.key,
        'bundle': true, // 総合表示で起動
      }),
      'nodeprog.${acc2.key}.tabs.v1': jsonEncode({'list': jsonEncode([{'id': 'node:9', 'label': 'セカンドTL'}])}),
      'nodeprog.${acc2.key}.tl.node:9.v1': jsonEncode({'graph': jsonEncode(graph.toJson())}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));

    // 集合表示: acc2 のタブが総合のタブ列に出る。
    expect(find.text('セカンドTL'), findsOneWidget);
    await tester.tap(find.text('セカンドTL'));
    await tester.pumpAndSettle();
    // 中身は持ち主(acc2)のセッションで実行されている。
    expect(find.text('second の投稿'), findsOneWidget);
    expect(find.text('tester の投稿'), findsNothing);

    // 設定でオフにすると隠れる (D-108)。
    await container.read(settingsAreaProvider('nodeprog.prefs').notifier).set('bundleTabs', false);
    await tester.pumpAndSettle();
    expect(find.text('セカンドTL'), findsNothing);
  });

  testWidgets('総合グラフはリフレッシュしても効き続ける (D-117: 以前は旧合流に戻っていた)', (tester) async {
    GraphNode inst(String type, String id, {Map<String, String> values = const {}}) {
      final e = builtinNodeCatalog.firstWhere((x) => x.type == type);
      final n = e.instantiate(id, Offset.zero);
      return n.copyWith(inputs: [for (final p in n.inputs) values.containsKey(p.label) ? p.copyWith(value: values[p.label]) : p]);
    }

    // ユーザー編集済み(auto なし)の総合グラフ: 取得×2 → マージ → 消去
    // (本文に second)→ タイムライン。
    const l1 = '@tester@example.test';
    const l2 = '@second@example.test';
    final graph = NodeGraph(nodes: [
      inst('tl.source', 's0', values: {'TL': 'home', 'アカウント': l1}),
      inst('tl.source', 's1', values: {'TL': 'home', 'アカウント': l2}),
      inst('merge', 'm0'),
      inst('remove', 'r0'),
      inst('cond', 'c0', values: {'値': 'second'}),
      inst('timeline', 't0'),
    ], edges: const [
      GraphEdge(from: 's0', fromPort: 0, to: 'm0', toPort: 0),
      GraphEdge(from: 's1', fromPort: 0, to: 'm0', toPort: 1),
      GraphEdge(from: 'm0', fromPort: 0, to: 'r0', toPort: 0),
      GraphEdge(from: 'r0', fromPort: 0, to: 't0', toPort: 0),
      GraphEdge(from: 'r0', fromPort: 0, to: 'c0', toPort: 0, cond: true),
    ]);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [session(acc1).toJson(), session(acc2).toJson()],
        'current': acc1.key,
      }),
      'nodeprog.tl.bundle.v1': jsonEncode({'graph': jsonEncode(graph.toJson()), 'accounts': '$l1|$l2', 'auto': false}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [postOf(v)]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));

    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RasqSidebar), matching: find.text('@tester')));
    await tester.pumpAndSettle();

    // グラフの消去が効いている(second の投稿は消える)。
    expect(find.text('tester の投稿'), findsOneWidget);
    expect(find.text('second の投稿'), findsNothing);

    // リフレッシュ(プル更新/クロックと同じ経路)後もグラフのまま。
    await container.read(timelineProvider(TimelineKind.bundle).notifier).refresh();
    await tester.pumpAndSettle();
    expect(find.text('tester の投稿'), findsOneWidget);
    expect(find.text('second の投稿'), findsNothing);
  });

  testWidgets('アカウント行の … → ログアウトでそのアカウントが外れる', (tester) async {
    final container = await pump(tester);
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('アカウントの操作').last);
    await tester.pumpAndSettle();
    expect(find.text('このアカウントを表示'), findsOneWidget);
    await tester.tap(find.text('ログアウト'));
    await tester.pumpAndSettle();
    final sessions = container.read(sessionsProvider).value!;
    expect([for (final s in sessions.sessions) s.account], [acc1]);
  });
}
