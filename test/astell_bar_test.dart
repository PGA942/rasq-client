import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/action_bar_config.dart';
import 'package:rasq_client/features/home/plugin_actions.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/vc/astell_bar.dart';
import 'package:rasq_client/features/vc/astell_fows.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// D-324: AsTell のルームの下段、入力欄の左の丸いボタンの並び(並べ替え / 表示 / 非表示 / 追加、はみ出しは歯車のメニューへ)。
void main() {
  /// 今押せるボタン(見た目は id そのもの)。
  Map<String, AstellBarButton> buttons(Iterable<String> ids) => {for (final id in ids) id: AstellBarButton(icon: Icons.circle, tooltip: id, onPressed: () {})};
  final allBuiltin = [for (final a in astellBarBuiltinActions) a.id];
  List<String> keys(List<AstellBarItem> items) => [for (final i in items) i.key];

  List<AstellBarItem> resolve(ActionBarConfig config, {List<PluginAction> plugins = const [], SlotActionSettings settings = const SlotActionSettings(), Iterable<String>? available}) =>
      resolveAstellBar(config: config, plugins: plugins, settings: settings, buttons: buttons([...available ?? allBuiltin, for (final p in plugins) p.id]));

  group('並び (D-324)', () {
    test('既定の並び = これまでの下段(スピーカー / マイク / 画面共有 / 全画面 / 字幕。「プラグインアクション」は D-328 で廃止)。全画面は共有枠に画面があるときだけ', () {
      expect(keys(resolve(const ActionBarConfig())), [AstellBarIds.speaker, AstellBarIds.mic, AstellBarIds.screen, AstellBarIds.fullscreen, AstellBarIds.captions]);
      expect(keys(resolve(const ActionBarConfig(), available: allBuiltin.where((id) => id != AstellBarIds.fullscreen))), [AstellBarIds.speaker, AstellBarIds.mic, AstellBarIds.screen, AstellBarIds.captions]);
    });

    test('並べ替え: 保存した順に。並びに無いボタンは後ろ', () {
      final config = ActionBarConfig(order: [AstellBarIds.captions, AstellBarIds.mic, AstellBarIds.speaker, AstellBarIds.screen, AstellBarIds.fullscreen]);
      expect(keys(resolve(config)), [AstellBarIds.captions, AstellBarIds.mic, AstellBarIds.speaker, AstellBarIds.screen, AstellBarIds.fullscreen]);
    });

    test('非表示: hidden のボタンは出さない。外すと元の位置に戻る', () {
      final hidden = resolve(const ActionBarConfig(hidden: {AstellBarIds.speaker}));
      expect(keys(hidden), [AstellBarIds.mic, AstellBarIds.screen, AstellBarIds.fullscreen, AstellBarIds.captions]);
      expect(keys(resolve(const ActionBarConfig(hidden: {AstellBarIds.captions}))).first, AstellBarIds.speaker);
    });

    test('あとから増えたボタン(挙手など)は、保存済みの並びでも既定の位置(直前の既定のボタンの後ろ)に入る', () {
      // 「画面共有」を知らない保存値(= あとから増えた種類の代わり)。マイクの後ろに入る。
      final saved = ActionBarConfig(order: [AstellBarIds.captions, AstellBarIds.speaker, AstellBarIds.mic, AstellBarIds.fullscreen]);
      expect(astellBarWithNewDefaults(saved).order, [AstellBarIds.captions, AstellBarIds.speaker, AstellBarIds.mic, AstellBarIds.screen, AstellBarIds.fullscreen]);
      // 非表示にしてあるものは足さない。一度も編集していなければそのまま(記述子の順)。
      expect(astellBarWithNewDefaults(saved.copyWith(hidden: {AstellBarIds.screen})).order, isNot(contains(AstellBarIds.screen)));
      expect(astellBarWithNewDefaults(const ActionBarConfig()).order, isEmpty);
    });

    test('バンドル: メンバーのうち今押せるものだけ。1 つも無ければ出さない', () {
      final config = ActionBarConfig(
        order: [AstellBarIds.mic, ActionBarConfig.listKey('b'), AstellBarIds.captions],
        lists: const [ActionListDef(id: 'b', name: '画面', memberIds: [AstellBarIds.screen, AstellBarIds.fullscreen])],
      );
      final items = resolve(config, available: allBuiltin.where((id) => id != AstellBarIds.fullscreen));
      final bundle = items.whereType<AstellBarBundle>().single;
      expect([for (final m in bundle.members) m.action.id], [AstellBarIds.screen]);
      expect(keys(resolve(config, available: allBuiltin.where((id) => id != AstellBarIds.fullscreen && id != AstellBarIds.screen))), isNot(contains(ActionBarConfig.listKey('b'))));
    });
  });

  group('幅に収まらないとき (D-324 → D-428)', () {
    test('入る数: 360px は 3 つ(これまでの「2 つ + 字幕」)、広い画面は全部、stick は 3 つまで', () {
      const reserved = 8 * 2 + 8 * 2 + 44 * 2 + 4.0;
      expect(astellBarSlots(360, reserved: reserved, compact: false), 3);
      expect(astellBarSlots(900, reserved: reserved, compact: false), greaterThanOrEqualTo(6));
      expect(astellBarSlots(900, reserved: 8 * 4 + 44, compact: true), 3);
      expect(astellBarSlots(120, reserved: reserved, compact: false), 1);
    });

    test('入りきらなければ並びの最後の 1 つ(入力欄の隣)を固定し、残りは横にスライドする列へ (D-428)', () {
      final items = resolve(const ActionBarConfig());
      final three = layoutAstellBar(items, 3);
      expect(keys(three.scroll), [AstellBarIds.speaker, AstellBarIds.mic, AstellBarIds.screen, AstellBarIds.fullscreen]);
      expect(keys(three.fixed), [AstellBarIds.captions]);
      expect(three.scrollWidth, 44 * 2 + 4, reason: '列の幅は 2 個分(残りはスライド)');
      final all = layoutAstellBar(items, 5);
      expect(all.fixed.length, 5);
      expect(all.scroll, isEmpty);
      expect(layoutAstellBar(items, 1).scrollWidth, 44, reason: '入る数が 1 つでも、列は 1 個分');
    });
  });

  group('プラグインのボタン (D-324)', () {
    SlotPlugin plugin(Map<String, Object?> manifest) => SlotPlugin(source: 'store:${manifest['id']}', manifest: SlotManifest.fromJson(manifest), runtime: FakeSlotRuntime(manifest: manifest, handler: (_, _, _) => null));
    Map<String, Object?> manifest(String id, {List<Map<String, Object?>> actions = const []}) => {'id': id, 'name': 'テスト $id', 'version': '0.1.0', 'kind': 'action', 'slots': ['astell.action'], 'permissions': ['fow.widget'], 'actions': actions};

    test('宣言が無ければ手動配置(既定の並びは変えない)。並びに入れると出る。宣言(D-328)は 1 つ = 1 ボタンで、placement: auto なら最後の 1 つ(字幕)の手前に入る', () {
      final bare = PluginAction(plugin: plugin(manifest('t.fx')), decl: astellActionDecls(SlotManifest.fromJson(manifest('t.fx'))).single);
      expect(bare.id, 'slot:t.fx:astell.action');
      expect(isAstellPluginAction(bare), isTrue);
      expect(bare.decl.label, 'テスト t.fx');
      expect(keys(resolve(const ActionBarConfig(), plugins: [bare])), isNot(contains(bare.id)));
      final placed = ActionBarConfig(order: [AstellBarIds.speaker, bare.id, for (final id in allBuiltin.skip(1)) id]);
      expect(keys(resolve(placed, plugins: [bare])).sublist(0, 2), [AstellBarIds.speaker, bare.id]);
      // スロット設定で無効 = 非表示。
      expect(keys(resolve(placed, plugins: [bare], settings: SlotActionSettings(enabled: {bare.id: false}))), isNot(contains(bare.id)));

      final m = manifest('t.auto', actions: [
        {'id': 'x', 'slot': 'astell.action', 'label': '拍手', 'icon': 'celebration', 'placement': 'auto'},
        {'id': 'y', 'slot': 'astell.action', 'label': '花火', 'icon': 'celebration'},
        {'id': 'z', 'slot': 'astell.action', 'label': '手動', 'placement': 'manual'},
        {'id': 'p', 'slot': 'post.action', 'label': '投稿のボタン', 'tags': ['Share']},
      ]);
      final decls = astellActionDecls(SlotManifest.fromJson(m));
      expect([for (final d in decls) d.id], ['x', 'y', 'z'], reason: 'astell.action の宣言だけ、宣言ごとに 1 つ');
      final autos = [for (final d in decls) PluginAction(plugin: plugin(m), decl: d)];
      expect(autos.first.id, 'slot:t.auto:x');
      expect(autos.first.decl.label, '拍手');
      // auto の 2 つは字幕の手前に(宣言の順)、manual は出ない。
      final autoKeys = keys(resolve(const ActionBarConfig(), plugins: autos));
      expect(autoKeys.sublist(autoKeys.length - 3), ['slot:t.auto:x', 'slot:t.auto:y', AstellBarIds.captions]);
      expect(autoKeys, isNot(contains('slot:t.auto:z')));
      // 並びを編集済みでも、構成にまだ無い auto のボタンは最後の 1 つの手前。構成に入れたものはその位置
      // (並びに無い内蔵のボタンは既定の位置に入る: スピーカーが先頭に)。
      final edited = ActionBarConfig(order: [AstellBarIds.captions, 'slot:t.auto:y', AstellBarIds.mic]);
      final editedKeys = keys(resolve(edited, plugins: autos));
      expect(editedKeys.sublist(0, 4), [AstellBarIds.speaker, AstellBarIds.captions, 'slot:t.auto:y', AstellBarIds.mic]);
      expect(editedKeys[editedKeys.length - 2], 'slot:t.auto:x');
    });
  });

  // ── 画面 ──────────────────────────────────────────────────────────

  late Map<String, FakeSlotRuntime Function()> fakes;
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const <Post>[]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<void> openRoom(WidgetTester tester, ProviderContainer c) async {
    await c.read(astellSessionProvider.notifier).join((await c.read(astellClientProvider).room('r-launch'))!);
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('参加中: '));
    await tester.pumpAndSettle();
    expect(find.byType(AstellRoomBody), findsOneWidget);
  }

  setUp(() => fakes = {});

  testWidgets('設定 → ASTell →「ルームのボタン」: 非表示にする / 非表示から戻す / (+) でプラグインのボタンを足す / 既定の並びに戻す', (tester) async {
    late FakeSlotRuntime rt;
    fakes['fx'] = () => rt = FakeSlotRuntime(
          manifest: {'id': 't.fx', 'name': '効果音', 'version': '0.1.0', 'kind': 'action', 'slots': ['astell.action'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) => fn == 'astell.open' ? {} : null,
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('store:t.fx', bytes: Uint8List.fromList('fx'.codeUnits));
    await tester.pumpAndSettle();
    final pluginId = pluginActionId('t.fx', astellPluginActionId);

    c.read(routerProvider).push('/settings/section/astell');
    await tester.pumpAndSettle();
    await tester.tap(find.text('ルームのボタン'));
    await tester.pumpAndSettle();
    expect(find.text('ルームのボタンの編集'), findsWidgets);
    expect(find.byKey(const ValueKey('actionbar.account')), findsNothing); // 端末ごとの構成なのでアカウントのタイルは出さない
    for (final id in allBuiltin) {
      expect(find.byKey(ValueKey('actionbar.tile.$id.astell')), findsOneWidget, reason: id);
    }
    expect(find.byKey(ValueKey('actionbar.tile.$pluginId.astell')), findsNothing); // プラグインは手動配置
    expect(find.text('非表示のボタンはありません'), findsOneWidget);

    // (…) → 非表示にする。
    await tester.tap(find.byKey(const ValueKey('actionbar.tile.menu.astell.speaker.astell')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('非表示にする'));
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(astellBarConfigKey)).hidden, contains(AstellBarIds.speaker));
    expect(find.byKey(const ValueKey('actionbar.tile.astell.speaker.astell')), findsNothing);
    // 非表示のチップを押すと戻る。
    await tester.tap(find.byKey(const ValueKey('actionbar.hidden.astell.speaker.astell')));
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(astellBarConfigKey)).hidden, isNot(contains(AstellBarIds.speaker)));
    expect(find.byKey(const ValueKey('actionbar.tile.astell.speaker.astell')), findsOneWidget);

    // (+) → AsTell のプラグイン → 最後の 1 つ(字幕)の手前に入る。
    await tester.tap(find.byKey(const ValueKey('actionbar.plugins.open.astell')));
    await tester.pumpAndSettle();
    expect(find.textContaining('AsTell プラグイン(押すとそのプラグインを開く)'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('actionbar.plugin.$pluginId')));
    await tester.pumpAndSettle();
    final order = c.read(actionBarConfigProvider(astellBarConfigKey)).order;
    expect(order.sublist(order.length - 2), [pluginId, AstellBarIds.captions]);
    expect(find.byKey(ValueKey('actionbar.tile.$pluginId.astell')), findsOneWidget);

    // 既定の並びに戻す。
    await tester.ensureVisible(find.byKey(const ValueKey('actionbar.reset.astell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('actionbar.reset.astell')));
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(astellBarConfigKey)).order, isEmpty);
    expect(find.byKey(ValueKey('actionbar.tile.$pluginId.astell')), findsNothing);
    expect(rt.calls, isEmpty);
  });

  testWidgets('ルームの下段は設定の並びで出る: 非表示は出さない、はみ出しは歯車のメニュー(点)、プラグインのボタンは押すとそのプラグインを開く、歯車から編集へ', (tester) async {
    late FakeSlotRuntime rt;
    fakes['fx'] = () => rt = FakeSlotRuntime(
          manifest: {'id': 't.fx', 'name': '効果音', 'version': '0.1.0', 'kind': 'action', 'slots': ['astell.action'], 'permissions': ['fow.widget']},
          handler: (self, fn, args) {
            if (fn == 'astell.open') {
              self.openFow('panel', {'t': 'Text', 'k': 'root', 'p': {'text': '効果音のパネル'}}, title: '効果音');
              return {};
            }
            return fn == 'astell.event' ? {} : null;
          },
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('store:t.fx', bytes: Uint8List.fromList('fx'.codeUnits));
    final pluginId = pluginActionId('t.fx', astellPluginActionId);
    // 字幕 / プラグインのボタン / マイク の順、スピーカーは非表示。
    c.read(actionBarConfigProvider(astellBarConfigKey).notifier).set(ActionBarConfig(order: [AstellBarIds.captions, pluginId, AstellBarIds.mic, AstellBarIds.screen], hidden: const {AstellBarIds.speaker}));
    await tester.pumpAndSettle();
    await openRoom(tester, c);

    final bar = find.byKey(astellFooterActionsKey);
    // 360px は 3 つ分の幅: 並びの最後(並びに無い全画面が後ろに足されるので、共有枠に画面がある今は全画面)は入力欄の隣に固定、
    // 残り(字幕 / 効果音 / マイク / 画面共有)は横にスライドする列 (D-428)。
    final scroll = find.byKey(astellFooterScrollKey);
    expect(find.descendant(of: bar, matching: find.byTooltip('全画面')), findsOneWidget);
    expect(find.descendant(of: scroll, matching: find.byTooltip('全画面')), findsNothing, reason: '最後の 1 つは固定');
    expect(find.descendant(of: scroll, matching: find.byTooltip('字幕オフ')), findsOneWidget);
    expect(find.descendant(of: scroll, matching: find.byTooltip('効果音')), findsOneWidget);
    expect(find.byTooltip('スピーカーミュート'), findsNothing);
    final xs = [for (final t in ['字幕オフ', '効果音']) tester.getCenter(find.descendant(of: scroll, matching: find.byTooltip(t))).dx];
    expect(xs, orderedEquals([...xs]..sort()));
    expect(tester.getCenter(find.descendant(of: bar, matching: find.byTooltip('全画面'))).dx, greaterThan(xs.last));
    // 列の外のボタン(マイク / 画面共有)は、スライドすると出てきて押せる。
    await tester.scrollUntilVisible(find.byTooltip('マイクオン'), 48, scrollable: find.descendant(of: scroll, matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: scroll, matching: find.byTooltip('マイクオン')));
    await tester.pumpAndSettle();
    expect(c.read(astellSessionProvider)!.micOn, isTrue);
    await tester.drag(find.descendant(of: scroll, matching: find.byType(Scrollable)), const Offset(400, 0));
    await tester.pumpAndSettle();

    // プラグインのボタン → 選ぶシートを挟まずにそのプラグインの astell.open。
    await tester.tap(find.descendant(of: bar, matching: find.byTooltip('効果音')));
    await tester.pumpAndSettle();
    expect(rt.calls.where((x) => x.$1 == 'astell.open'), hasLength(1));
    expect(find.text('効果音のパネル'), findsOneWidget);
    rt.closeFow('panel');
    await tester.pumpAndSettle();

    // 歯車 →「下段のボタンの並びを編集」→ AsTell の面だけの編集 FOW。
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('astell.bar.edit')));
    await tester.pumpAndSettle();
    expect(find.text('ルームのボタンの編集'), findsWidgets);
    expect(find.byKey(ValueKey('actionbar.tile.$pluginId.astell')), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.hidden.astell.speaker.astell')), findsOneWidget);
    await c.read(astellSessionProvider.notifier).leave();
    await tester.pumpAndSettle();
  });
}
