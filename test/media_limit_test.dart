import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/home/media_limit.dart';
import 'package:rasq_client/features/home/plugin_actions.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/action_bar_plugins_screen.dart';
import 'package:rasq_client/features/store/plugin_page_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// D-589: 添付の並びの既定は横(5 枚以上は横に送る)、横に送る並びでは既定で 4 枚までにしない、
/// 投稿のバーの「4 枚まで」の切り替え → 長押しでアクションバーの編集(設定 → プラグインボタン)→ プラグインのページ。
void main() {
  List<MediaItem> media(int n) => [for (var i = 0; i < n; i++) MediaItem(id: 'm$i', type: MediaType.image, url: Uri.parse('https://e.test/m$i.png'), width: 300, height: 200)];

  group('見せる枚数', () {
    test('横に送る並び(既定 / 横 / 横・詰める)は既定で全部、制限をオンにすると 4 枚。縦はいつも 4 枚、全部を見せる面はいつも全部', () {
      for (final a in [RasqMediaArrangement.auto, RasqMediaArrangement.horizontal, RasqMediaArrangement.horizontalPacked]) {
        expect(a.horizontalAxis, isTrue, reason: a.name);
        expect(mediaMaxVisible(count: 7, arrangement: a, showAll: false, limitFour: false), 7, reason: a.name);
        expect(mediaMaxVisible(count: 7, arrangement: a, showAll: false, limitFour: true), 4, reason: a.name);
        expect(mediaLimitApplies(count: 7, arrangement: a, showAll: false), isTrue, reason: a.name);
      }
      for (final a in [RasqMediaArrangement.vertical, RasqMediaArrangement.verticalPacked]) {
        expect(a.horizontalAxis, isFalse, reason: a.name);
        expect(mediaMaxVisible(count: 7, arrangement: a, showAll: false, limitFour: false), 4, reason: a.name);
        expect(mediaLimitApplies(count: 7, arrangement: a, showAll: false), isFalse, reason: a.name);
      }
      expect(mediaMaxVisible(count: 7, arrangement: RasqMediaArrangement.vertical, showAll: true, limitFour: true), 7);
      expect(mediaLimitApplies(count: 7, arrangement: RasqMediaArrangement.auto, showAll: true), isFalse);
      expect(mediaLimitApplies(count: 4, arrangement: RasqMediaArrangement.auto, showAll: false), isFalse);
    });
  });

  group('RasqMediaGrid', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 400, child: child))));

    testWidgets('既定(auto)の 5 枚以上は横に送る(「+N」なし)。縦を選ぶと D-177 の 2 列の行、4 枚までなら「+N」', (tester) async {
      await tester.pumpWidget(wrap(RasqMediaGrid(items: media(6), maxVisible: 6)));
      expect(find.byKey(const ValueKey('media.auto.horizontal')), findsOneWidget);
      final list = tester.widget<ListView>(find.descendant(of: find.byKey(const ValueKey('media.auto.horizontal')), matching: find.byType(ListView)));
      expect(list.scrollDirection, Axis.horizontal);
      expect(find.textContaining('+'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(wrap(RasqMediaGrid(items: media(6), maxVisible: 6, overflowAxis: Axis.vertical)));
      expect(find.byKey(const ValueKey('media.auto.horizontal')), findsNothing);
      expect(find.byType(ListView), findsNothing);

      await tester.pumpWidget(wrap(RasqMediaGrid(items: media(6))));
      expect(find.byKey(const ValueKey('media.auto.horizontal')), findsNothing);
      expect(find.text('+2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('横・詰めるの 2 枚は 1 枚ずつの 2 列(列の半分が空かない)。3 列以上は次の列が覗く', (tester) async {
      await tester.pumpWidget(wrap(RasqMediaGrid(items: media(2), arrangement: RasqMediaArrangement.horizontalPacked)));
      final packed = find.byKey(const ValueKey('media.arranged.horizontalPacked'));
      expect(packed, findsOneWidget);
      final cols = find.descendant(of: packed, matching: find.byWidgetPredicate((w) => w is SizedBox && w.width != null && w.width! > 100));
      expect(cols, findsNWidgets(2));
      expect(tester.getTopLeft(cols.at(1)).dx, greaterThan(tester.getTopLeft(cols.at(0)).dx));

      await tester.pumpWidget(wrap(RasqMediaGrid(items: media(6), maxVisible: 6, arrangement: RasqMediaArrangement.horizontalPacked)));
      final w = tester.widget<SizedBox>(find.descendant(of: find.byKey(const ValueKey('media.arranged.horizontalPacked')), matching: find.byWidgetPredicate((w) => w is SizedBox && w.width != null && w.width! > 100)).first).width!;
      expect(w, lessThan((400 - RasqSpacing.mediaGap) / 2));
      expect(tester.takeException(), isNull);
    });
  });

  group('投稿のバーの切り替え → アクションバーの編集 → プラグインのページ', () {
    const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    late Map<String, FakeSlotRuntime Function()> fakes;
    setUp(() => fakes = {});

    Future<ProviderContainer> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      final post = Post(id: 'p1', account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 11, 17), body: '写真 6 枚', media: media(6), url: Uri.parse('https://example.test/notes/p1'));
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post]));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(registry),
          slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    testWidgets('既定は 6 枚を横に送る → 押すと 4 枚まで(+2)→ 長押しの「アクションバーを編集」→ ボタンの行からプラグインのページ', (tester) async {
      fakes['act'] = () => FakeSlotRuntime(
            manifest: {'id': 't.act', 'name': '投稿ボタン', 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget'], 'actions': [{'id': 'copy', 'label': '本文をコピー', 'icon': 'content_copy', 'tags': ['Copy']}]},
            handler: (self, fn, args) => {'result': {'done': true}},
          );
      // グリッドの「+N」(24px)。TL のほかの所にも「+2」の小さい文字が出る。
      final plusTwo = find.byWidgetPredicate((w) => w is Text && w.data == '+2' && w.style?.fontSize == 24);
      final c = await pump(tester);
      await c.read(slotPluginsProvider.notifier).register('fake:act', bytes: Uint8List.fromList('act'.codeUnits));
      await tester.pumpAndSettle();

      // 既定: 横に送る(全部)、「+N」なし、切り替えはオフ。
      expect(find.byKey(const ValueKey('media.auto.horizontal')), findsOneWidget);
      expect(plusTwo, findsNothing);
      final toggle = find.byKey(const ValueKey('post.mediaLimit'));
      expect(toggle, findsOneWidget);
      expect(tester.widget<RasqActionButton>(toggle).done, isFalse);

      // 押す → 4 枚まで(端末の設定)。
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(c.read(mediaLimitFourProvider), isTrue);
      expect(plusTwo, findsOneWidget);
      expect(tester.widget<RasqActionButton>(toggle).done, isTrue);

      // 長押し → メニュー →「全部横に送る」で戻る。
      await tester.longPress(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('添付を全部横に送る'));
      await tester.pumpAndSettle();
      expect(c.read(mediaLimitFourProvider), isFalse);
      expect(plusTwo, findsNothing);

      // 長押し →「アクションバーを編集」→ 設定 → プラグインボタン(アプリのボタンの節)。
      await tester.longPress(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('アクションバーを編集'));
      await tester.pumpAndSettle();
      expect(find.byType(ActionBarPluginsScreen), findsOneWidget);
      expect(find.text('アプリのボタン'), findsOneWidget);
      // ボタンを出さない → TL の投稿から消える。
      await tester.tap(find.byKey(const ValueKey('actionbar.app.mediaLimitButton')));
      await tester.pumpAndSettle();
      expect(c.read(mediaLimitButtonProvider), isFalse);

      // ボタンの行の左のアイコン → そのボタンを出しているプラグインのページ(同梱 / サイドロードはストアのページ)。
      final copyId = pluginActionId('t.act', 'copy');
      final link = find.byKey(ValueKey('actionbar.pluginPage.$copyId'));
      await tester.scrollUntilVisible(link, 120, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('投稿ボタン のページを開く'), findsWidgets);
      await tester.tap(link);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.widget<PluginPageScreen>(find.byType(PluginPageScreen)).pluginId, 't.act');
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(PluginPageScreen))).pop();
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(ActionBarPluginsScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('post.mediaLimit')), findsNothing);
    });

    test('プラグインのページの行き先: ストアから入れたものはインストール済みのページ、ほかはストアのページ', () {
      SlotPlugin plugin(String source) => SlotPlugin(manifest: const SlotManifest(id: 'x.child', name: 'X'), source: source, runtime: FakeSlotRuntime(manifest: const {}, handler: (_, _, _) => null));
      expect(pluginPageRouteOf(plugin('store:x.pkg@1.0.0')), '/store/installed/x.pkg');
      expect(pluginPageRouteOf(plugin('fake:act')), '/store/plugin/x.child');
    });
  });
}
