import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/nodeprog/node_tabs.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/vc/astell_actions.dart' show AstellRoomTile;
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_providers.dart' show astellHomeProvider;
import 'package:rasq_client/features/vc/vc_screen.dart' show searchAstellRooms;
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-439: セクション(ほかの TL を包む枠)と表示モード(通常 TL / 関連 TL / ユーザー)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(int i, {String author = 'u1'}) => Post(
        id: 'p$i',
        account: acc,
        author: UserSummary(id: author, account: acc, displayName: '人$author'),
        createdAt: DateTime(2026, 10, 5, 12).subtract(Duration(minutes: i)),
        body: '投稿 $i',
      );

  test('構成の JSON: 既定(通常 TL・枠なし)は書かない。読めない値は既定に', () {
    const plain = TlConfig(sources: [TlSourceComponent()]);
    expect(plain.toJson().containsKey('display'), isFalse);
    expect(plain.toJson().containsKey('sections'), isFalse);
    const cfg = TlConfig(display: TlDisplayMode.users, sections: [TlSection(id: 's1', title: 'おすすめ', tl: 'social', display: TlDisplayMode.relational, limit: 3, enabled: false)]);
    final back = TlConfig.fromJson(jsonDecode(jsonEncode(cfg.toJson())) as Map<String, Object?>);
    expect(back.display, TlDisplayMode.users);
    expect(back.sections.single.toJson(), cfg.sections.single.toJson());
    expect(TlConfig.fromJson({'display': 'nope', 'sections': ['x']}).display, TlDisplayMode.timeline);
  });

  late List<Post> posts;
  late FakeSnsPlugin plugin;

  /// 開いたときに見えるタブ(テストの SNS はソーシャル)の構成を [cfg] にする。
  Future<ProviderContainer> pump(WidgetTester tester, TlConfig cfg, {String scope = 'tl.social', List<Override> extra = const []}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final key = fakeSession().account.key;
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': key}),
    });
    posts = [for (var i = 0; i < 12; i++) post(i, author: i < 8 ? 'a' : 'b')];
    plugin = FakeSnsPlugin(posts: (_) => posts);
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)), ...extra],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await c.read(settingsAreaProvider(nodeprogAreaFor(key, scope)).notifier).set('tlcfg', jsonEncode(cfg.toJson()));
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('TL の上に、包んだ TL の枠(件数まで)。包んだ TL は新しい投稿を読み込まず、引き下げで読み直す', (tester) async {
    final c = await pump(tester, const TlConfig(sources: [TlSourceComponent()], sections: [TlSection(id: 's1', title: 'フォロー中から', tl: 'home', limit: 3)]));
    final section = find.byKey(const ValueKey('tl.section.s1'));
    expect(section, findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('フォロー中から')), findsOneWidget);
    expect(find.descendant(of: section, matching: find.textContaining('投稿 ')), findsNWidgets(3));
    // 包んだ TL に新しい投稿が来ても、枠は開いたときのまま。
    plugin.opened.last.prepend(post(99));
    await c.read(timelineProvider(TimelineKind.home).notifier).prependNewer();
    await tester.pumpAndSettle();
    expect(find.descendant(of: section, matching: find.text('投稿 99')), findsNothing);
    // 枠の ↻ で読み直す。
    await tester.tap(find.byKey(const ValueKey('tl.section.s1.reload')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: section, matching: find.text('投稿 99')), findsOneWidget);
  });

  testWidgets('表示モード: ユーザー(投稿の多い順)/ 関連 TL', (tester) async {
    await pump(tester, const TlConfig(sources: [TlSourceComponent()], display: TlDisplayMode.users));
    expect(find.byKey(const ValueKey('tl.display.users')), findsOneWidget);
    expect(find.text('8 件の投稿'), findsOneWidget);
    expect(find.text('4 件の投稿'), findsOneWidget);
    expect(tester.getTopLeft(find.text('人a')).dy, lessThan(tester.getTopLeft(find.text('人b')).dy));
  });

  testWidgets('カスタマイズ画面: ホームの TL には表示モードとセクション、DM には出さない。セクションを足せる', (tester) async {
    final c = await pump(tester, const TlConfig(sources: [TlSourceComponent()]), scope: 'tl.home');
    c.read(routerProvider).push(Routes.tlConfig('tl.home'));
    await tester.pumpAndSettle();
    final display = find.byKey(const ValueKey('tlconfig.display'));
    await tester.scrollUntilVisible(display, 200, scrollable: find.byType(Scrollable).last);
    expect(display, findsOneWidget);
    await tester.tap(display);
    await tester.pumpAndSettle();
    await tester.tap(find.text('関連 TL').last);
    await tester.pumpAndSettle();
    final area = await c.read(settingsAreaProvider(nodeprogAreaFor(fakeSession().account.key, 'tl.home')).future);
    expect(TlConfig.fromJson((jsonDecode(area['tlcfg']! as String) as Map).cast<String, Object?>()).display, TlDisplayMode.relational);

    final add = find.text('セクションを追加');
    await tester.scrollUntilVisible(add, 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ソーシャル').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    final saved = TlConfig.fromJson((jsonDecode((await c.read(settingsAreaProvider(nodeprogAreaFor(fakeSession().account.key, 'tl.home')).future))['tlcfg']! as String) as Map).cast<String, Object?>());
    expect(saved.sections.single.tl, 'social');
    expect(saved.sections.single.title, 'ソーシャル');

    c.read(routerProvider).pushReplacement(Routes.tlConfig('tl.dm'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tlconfig.display')), findsNothing);
  });

  testWidgets('D-441: AsTell のタイル / Swing の枠。AsTell はいま開いているルーム(件数まで)、Swing が無ければ案内', (tester) async {
    AstellRoom room(String id, String title) => AstellRoom(id: id, ownerId: 'o', ownerHandle: 'o', ownerDisplayName: 'オーナー', title: title, createdAt: DateTime(2026, 10, 5));
    final home = AstellHome(trending: [room('r1', '花火の話'), room('r2', '月見の話'), room('r3', '花火大会')]);
    await pump(
      tester,
      const TlConfig(sources: [TlSourceComponent()], sections: [
        TlSection(id: 'a', title: 'いまの AsTell', tl: astellSectionKind, limit: 2),
        TlSection(id: 'w', title: 'Swing', tl: swingSectionKind),
      ]),
      extra: [astellHomeProvider.overrideWith((ref) async => home)],
    );
    final astell = find.byKey(const ValueKey('tl.section.a'));
    expect(find.descendant(of: astell, matching: find.text('いまの AsTell')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('tl.section.a.rooms')), matching: find.byType(AstellRoomTile)), findsNWidgets(2), reason: '件数まで');
    expect(find.descendant(of: find.byKey(const ValueKey('tl.section.w')), matching: find.text('いま Swing はありません')), findsOneWidget);
  });

  test('D-441: AsTell の枠は、ページのワードに当たるルームだけ(トレンド TL)', () {
    AstellRoom room(String id, String title) => AstellRoom(id: id, ownerId: 'o', ownerHandle: 'o', ownerDisplayName: 'オーナー', title: title, createdAt: DateTime(2026, 10, 5));
    final home = AstellHome(trending: [room('r1', '花火の話'), room('r2', '月見の話')]);
    expect(searchAstellRooms(home, '花火').map((r) => r.id), ['r1']);
  });
}
