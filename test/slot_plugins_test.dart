import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/plugins/media_plugin_panel.dart';
import 'package:rasq_client/features/nodeprog/node_editor_screen.dart';
import 'package:rasq_client/features/nodeprog/node_executor.dart' show pluginParamsOf;
import 'package:rasq_client/features/nodeprog/node_graph.dart';
import 'package:rasq_client/features/nodeprog/timeline_config_screen.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart' show settingsAreaProvider;
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/vc/astell_fows.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// スロットプラグイン (D-167): 偽のランタイムで契約(plugin-sample/CONTRACT.md)の
/// ホスト側を通す — 登録 / AsTell / コンポーザー(添付・本文)/ 投稿加工 / カスタム TL / トレンド / mute.add。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  Map<String, Object?> manifest(String id, List<String> slots, {List<String> permissions = const ['fow.widget']}) =>
      {'id': id, 'name': 'テスト $id', 'version': '0.1.0', 'kind': 'action', 'slots': slots, 'permissions': permissions};

  late Map<String, FakeSlotRuntime Function()> fakes;
  late MemorySessionStorage storage;

  Future<ProviderContainer> pump(WidgetTester tester, {List<Post>? posts}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts ?? [post('p1', '今日は打ち上げ'), post('p2', 'あいう')]));
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

  Future<SlotPlugin> register(ProviderContainer c, String name) async {
    final p = await c.read(slotPluginsProvider.notifier).register('fake:$name', bytes: Uint8List.fromList(name.codeUnits));
    expect(p, isNotNull, reason: c.read(slotPluginsNoticeProvider));
    return p!;
  }

  /// 編集パネル (D-249) を単体で開く(本番では加工画面の上に重なる)。結果は onDone で返り、パネルは閉じる。
  Future<MediaEditResult?> openPanel(WidgetTester tester, SlotPlugin plugin, Uint8List bytes) {
    // 加工画面と同じ「app」ナビゲーター(FOW / ドロップダウンの層より下)に積む。
    final nav = tester.stateList<NavigatorState>(find.byType(Navigator)).firstWhere((n) => '${n.widget.key}'.contains('app'));
    return nav.push<MediaEditResult>(PageRouteBuilder(
      pageBuilder: (ctx, _, _) => MediaPluginPanel(plugin: plugin, bytes: bytes, name: 'a.png', mimeType: 'image/png', onDone: (r) => Navigator.of(ctx).pop(r)),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    ));
  }

  setUp(() => fakes = {});

  testWidgets('登録と永続化: マニフェストの slots で振り分け、パスは端末に残り、解除で消える', (tester) async {
    fakes['a'] = () => FakeSlotRuntime(manifest: manifest('t.a', ['post.transform', 'trend.suggest']), handler: (_, fn, args) => null);
    final c = await pump(tester);
    final p = await register(c, 'a');
    expect(p.manifest.name, 'テスト t.a');
    expect(c.read(slotPluginsForProvider(SlotIds.postTransform)).length, 1);
    expect(c.read(slotPluginsForProvider(SlotIds.trendSuggest)).length, 1);
    expect(c.read(slotPluginsForProvider(SlotIds.astellAction)), isEmpty);
    expect(await storage.read(slotPluginsStorageKey), '["fake:a"]');
    expect(p.manifest.appFns, isNot(contains('mute.add')));
    await c.read(slotPluginsProvider.notifier).unregister('t.a');
    expect(c.read(slotPluginsProvider), isEmpty);
    expect(await storage.read(slotPluginsStorageKey), '[]');
    // マニフェストが無い wasm は登録できない。
    fakes['bad'] = () => FakeSlotRuntime(manifest: const {}, handler: (_, fn, args) => null);
    expect(await c.read(slotPluginsProvider.notifier).register('fake:bad', bytes: Uint8List.fromList('bad'.codeUnits)), isNull);
    expect(c.read(slotPluginsNoticeProvider), contains('登録できませんでした'));
  });

  testWidgets('AsTell (§2.1): プラグインアクション → astell.open(room/peers/shares)→ FOW、astell.share/sound.play、共有の出来事は astell.event', (tester) async {
    late FakeSlotRuntime rt;
    fakes['astell'] = () => rt = FakeSlotRuntime(
          manifest: manifest('t.astell', ['astell.action']),
          handler: (self, fn, args) {
            if (fn == 'astell.open') {
              self.openFow('panel', {'t': 'Column', 'k': 'root', 'c': [{'t': 'Text', 'k': 'hello', 'p': {'text': 'プラグインのパネル ${(args['peers'] as List).length} 人'}}, {'t': 'Button', 'k': 'b', 'p': {'label': '効果音'}, 'on': {'tap': 'fx'}}]}, title: 'AsTell プラグイン');
              return {};
            }
            if (fn == 'fx') {
              self.hostFn('sound.play', {'kind': 'alert'});
              self.hostFn('astell.share', {'kind': 'text', 'payload': {'text': '🔔 ピンポン!'}});
              return {};
            }
            if (fn == 'astell.event') return {};
            return null;
          },
        );
    final c = await pump(tester);
    await register(c, 'astell');
    // 参加してルーム FOW を開く。
    await c.read(astellSessionProvider.notifier).join((await c.read(astellClientProvider).room('r-launch'))!);
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('参加中: '));
    await tester.pumpAndSettle();
    expect(find.byType(AstellRoomBody), findsOneWidget);
    // 下段のプラグインアクション(横 ListView の末尾)へスクロールして押す。
    await tester.scrollUntilVisible(find.byTooltip('プラグインアクション'), 48, scrollable: find.descendant(of: find.byKey(astellFooterActionsKey), matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('プラグインアクション'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('プラグインアクション'), warnIfMissed: false);
    await tester.pumpAndSettle();
    final open = rt.calls.where((x) => x.$1 == 'astell.open').single;
    expect(open.$2['room'], isA<Map>());
    expect((open.$2['peers'] as List).length, 5);
    expect((open.$2['shares'] as List), isA<List>());
    expect(find.text('AsTell プラグイン'), findsOneWidget); // FOW が開いた
    expect(find.textContaining('プラグインのパネル 5 人'), findsOneWidget);
    // FOW のボタン → プラグイン fn → astell.share がルームの共有になる。
    await tester.tap(find.text('効果音'));
    await tester.pumpAndSettle();
    expect(c.read(astellSessionProvider)!.shares.last.payload['text'], '🔔 ピンポン!');
    // 共有の出来事がプラグインへ届く(自分の共有も share イベント)。
    expect(rt.calls.where((x) => x.$1 == 'astell.event' && x.$2['type'] == 'share'), isNotEmpty);
    await c.read(astellSessionProvider.notifier).leave();
    await tester.pumpAndSettle();
    expect(rt.calls.where((x) => x.$1 == 'astell.event' && x.$2['type'] == 'closed'), isNotEmpty);
  });

  testWidgets('コンポーザー (§2.2/§2.3): 添付の「プラグインで加工」→ media.edit → composer.media.replace、本文の # → text.changed(trigger)→ composer.text.replace', (tester) async {
    late FakeSlotRuntime media;
    late FakeSlotRuntime text;
    fakes['media'] = () => media = FakeSlotRuntime(
          manifest: manifest('t.media', ['composer.media']),
          handler: (self, fn, args) {
            if (fn == 'media.edit') {
              // UI 無しで即差し替え(§2.2 の「すぐ返す形」)。
              return {'bytesB64': base64Encode([1, 2, 3, 4]), 'mimeType': 'image/png', 'name': 'edited.png'};
            }
            return null;
          },
        );
    fakes['text'] = () => text = FakeSlotRuntime(
          manifest: manifest('t.text', ['composer.text']),
          handler: (self, fn, args) {
            if (fn == 'text.changed' && (args['trigger'] as String?)?.startsWith('#') == true) {
              final cursor = args['selectionStart'] as int;
              final trig = args['trigger'] as String;
              self.hostFn('composer.text.replace', {'token': args['token'], 'start': cursor - trig.length, 'end': cursor, 'text': '#打上会 '});
              return {};
            }
            return fn == 'text.changed' ? {} : null;
          },
        );
    final c = await pump(tester);
    await register(c, 'media');
    await register(c, 'text');
    // コンポーザーを開く(ホーム右下の +)。
    await tester.tap(find.byTooltip('投稿'));
    await tester.pumpAndSettle();
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'こんにちは #uch');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final changed = text.calls.where((x) => x.$1 == 'text.changed').last;
    expect(changed.$2['trigger'], '#uch');
    expect(changed.$2['text'], 'こんにちは #uch');
    expect(tester.widget<TextField>(field).controller!.text, 'こんにちは #打上会 ');
    // 添付: 画像を足すのはピッカー経由なので、ここでは加工の口(media.edit → 即差し替え)を直接通す。
    var replaced = <Object?>[];
    final session = await c.read(slotPluginsProvider.notifier).mediaEditorOpen(c.read(slotPluginsForProvider(SlotIds.composerMedia)).single, name: 'a.png', mimeType: 'image/png', bytes: Uint8List.fromList([9, 9]), onPreview: (_, _, _, _) {}, onReplace: (b, m, n) => replaced = [b, m, n]);
    expect(session, isNull); // 即差し替え形はセッションにならない
    expect(media.calls.single.$1, 'media.edit');
    expect((media.calls.single.$2['bytesB64'] as String), base64Encode([9, 9]));
    expect(replaced, [Uint8List.fromList([1, 2, 3, 4]), 'image/png', 'edited.png']);
    // 遅延返答(§2.2 の UI を出す形): composer.media.replace のホスト関数で差し替わる。
    media.hostFn('composer.media.replace', {'token': media.calls.single.$2['token'], 'bytesB64': base64Encode([7]), 'mimeType': 'image/jpeg'});
    expect(replaced, [Uint8List.fromList([7]), 'image/jpeg', null]);
  });

  testWidgets('投稿加工 (§2.5) とトレンド (§2.7)', (tester) async {
    fakes['tl'] = () => FakeSlotRuntime(
          manifest: manifest('t.tl', ['post.transform', 'tl', 'trend.suggest']),
          handler: (self, fn, args) {
            switch (fn) {
              case 'post.transform':
                return {'posts': {for (final p in (args['posts'] as List)) if ((p as Map)['body'].toString().contains('今日')) p['id']: {'body': p['body'].toString().replaceAll('今日', '8/31(今日)')}}};
              case 'tl.timelines':
                return {'timelines': [{'id': 'asc', 'label': 'Unicode 昇順', 'base': 'home'}]};
              case 'tl.sort':
                final posts = [for (final p in (args['posts'] as List)) p as Map];
                posts.sort((a, b) => '${a['body']}'.compareTo('${b['body']}'));
                return {'order': [for (final p in posts) p['id']]};
              case 'trend.suggest':
                return {'suggestions': [{'text': '反省会', 'reason': '打上会 と共起'}]};
            }
            return null;
          },
        );
    final c = await pump(tester);
    await register(c, 'tl');
    // ホーム TL: 本文が加工される。
    c.invalidate(timelineProvider);
    await tester.pumpAndSettle();
    expect(find.textContaining('8/31(今日)は打ち上げ'), findsOneWidget);
    // TL プラグインはタブにならない (D-169: アルゴリズム部品)。
    expect(find.text('Unicode 昇順'), findsNothing);
    // 検索ホームのトレンド節にサジェスト。
    await tester.tap(find.byTooltip('検索'));
    await tester.pumpAndSettle();
    expect(find.text('#反省会'), findsOneWidget);
  });

  testWidgets('mute.add (§2.4): 権限 mute.words があるプラグインだけ、確認してからミュート語に入る', (tester) async {
    late FakeSlotRuntime rt;
    fakes['qr'] = () => rt = FakeSlotRuntime(manifest: manifest('t.qr', ['viewer.overlay'], permissions: ['fow.widget', 'mute.words']), handler: (_, fn, args) => null);
    final c = await pump(tester);
    final p = await register(c, 'qr');
    expect(p.manifest.appFns, containsAll(['mute.add', 'viewer.overlay.set', 'clipboard.set', 'url.open']));
    rt.hostFn('mute.add', {'text': 'https://spam.example/'});
    await tester.pumpAndSettle();
    expect(find.text('ミュート語に追加'), findsOneWidget);
    await tester.tap(find.text('追加'));
    await tester.pumpAndSettle();
    final words = (await c.read(settingsAreaProvider(muteWordsArea).future))[muteWordsKey];
    expect(words, ['https://spam.example/']);
    expect(find.textContaining('ミュート語に追加しました'), findsOneWidget);
  });

  testWidgets('プラグインの編集パネル (D-249 §2.2): 下付き横リスト → media.action、下付き FOW でプレビューが縮む、適用 → media.commit', (tester) async {
    late FakeSlotRuntime rt;
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
    final catalog = {'genres': [
      {'id': 'tone', 'actions': [{'id': 'gamma', 'label': 'ガンマ', 'icon': 'brightness_6'}, {'id': 'reset', 'label': 'リセット'}]},
      {'id': 'transform', 'actions': [{'id': 'rotl', 'label': '左回転'}]},
      {'id': 'sticker', 'label': 'スタンプ', 'icon': 'star', 'actions': [{'id': 'cat', 'label': 'ねこ'}]},
    ]};
    fakes['media'] = () => rt = FakeSlotRuntime(
          manifest: manifest('t.media', ['composer.media']),
          handler: (self, fn, args) {
            switch (fn) {
              case 'media.catalog':
                return catalog;
              case 'media.edit':
                self.hostFn('composer.media.preview', {'token': args['token'], 'bytesB64': base64Encode(png), 'mimeType': 'image/png'});
                return catalog;
              case 'media.action':
                if (args['action'] == 'gamma') {
                  self.openFow('media-param', {'t': 'Column', 'k': 'root', 'c': [{'t': 'SliderListTile', 'k': 'gamma', 'p': {'title': 'ガンマ', 'value': 1.0, 'min': 0.3, 'max': 3.0}, 'on': {'change': 'gammaChanged'}}]}, title: 'ガンマ');
                }
                self.hostFn('composer.media.preview', {'token': args['token'], 'bytesB64': base64Encode(png), 'mimeType': 'image/png'});
                return {};
              case 'media.commit':
                return {'bytesB64': base64Encode([1, 2, 3]), 'mimeType': 'image/png', 'name': 'edited.png'};
              case 'media.cancel':
                return {};
            }
            return null;
          },
        );
    final c = await pump(tester);
    final plugin = await register(c, 'media');
    final future = openPanel(tester, plugin, png);
    await tester.pumpAndSettle();
    expect(find.byType(MediaPluginPanel), findsOneWidget);
    expect(rt.calls.where((x) => x.$1 == 'media.edit').length, 1);
    // 下の横リスト = このプラグインの全編集ボタン(プラグイン / ジャンルの切り替え列はもう無い)。
    expect(find.byKey(const ValueKey('media.editor.pick')), findsNothing);
    expect(find.byKey(const ValueKey('media.action.t.media.tone.gamma')), findsOneWidget);
    expect(find.byKey(const ValueKey('media.action.t.media.transform.rotl')), findsOneWidget);
    expect(find.byKey(const ValueKey('media.action.t.media.sticker.cat')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('media.action.t.media.transform.rotl')));
    await tester.pumpAndSettle();
    final act = rt.calls.where((x) => x.$1 == 'media.action').last;
    expect(act.$2['genre'], 'transform');
    expect(act.$2['action'], 'rotl');
    // 第 3 階層 = 下付き FOW(ガンマのスライダー)。開くとプレビューが縮む。スライダーは楽観更新で動く。
    final before = tester.getSize(find.byKey(mediaEditorPreviewKey));
    await tester.tap(find.byKey(const ValueKey('media.action.t.media.tone.gamma')));
    await tester.pumpAndSettle();
    expect(find.text('ガンマ'), findsWidgets);
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.getSize(find.byKey(mediaEditorPreviewKey)).height, lessThan(before.height));
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, greaterThan(1.0));
    expect(rt.calls.where((x) => x.$1 == 'gammaChanged'), isNotEmpty);
    // 適用 → media.commit の結果が呼び出し元へ。
    await tester.tap(find.byKey(const ValueKey('media.editor.apply')));
    await tester.pumpAndSettle();
    final result = await future;
    expect(result!.bytes, [1, 2, 3]);
    expect(result.name, 'edited.png');
    expect(find.byType(MediaPluginPanel), findsNothing);
  });

  testWidgets('TL プラグイン = アルゴリズム部品 (D-169 §2.6): タブにはならず、ノードを設定 FOW にプラグインの RRL、tl.sort に params', (tester) async {
    late FakeSlotRuntime rt;
    fakes['tl'] = () => rt = FakeSlotRuntime(
          manifest: {'id': 'sample.timeline', 'name': 'Unicode 順ソート', 'version': '0.2.0', 'kind': 'view', 'slots': ['tl']},
          handler: (self, fn, args) {
            switch (fn) {
              case 'tl.timelines':
                return {'timelines': [{'id': 'unicode', 'label': 'Unicode 順', 'base': 'home'}]};
              case 'tl.params':
                return {'root': {'t': 'Column', 'c': [
                  {'t': 'SectionHeader', 'p': {'title': '並び順'}},
                  {'t': 'RadioListTile', 'k': 'order', 'p': {'title': '昇順', 'value': 'asc', 'group': r'$.settings.order'}, 'on': {'change': 'settings.set'}},
                  {'t': 'RadioListTile', 'k': 'order', 'p': {'title': '降順', 'value': 'desc', 'group': r'$.settings.order'}, 'on': {'change': 'settings.set'}},
                ]}, 'defaults': {'order': 'asc'}};
              case 'tl.sort':
                final posts = [for (final p in (args['posts'] as List)) p as Map];
                posts.sort((a, b) => '${a['body']}'.compareTo('${b['body']}'));
                final desc = (args['params'] as Map?)?['order'] == 'desc';
                return {'order': [for (final p in (desc ? posts.reversed : posts)) p['id']]};
            }
            return null;
          },
        );
    final c = await pump(tester);
    await register(c, 'tl');
    await tester.pumpAndSettle();
    expect(find.text('Unicode 順'), findsNothing); // タブにはならない
    // フォロー中(home)のタイムライン設定 → アルゴリズムを追加 → 「Unicode 順でソート」。
    await tester.tap(find.text('フォロー中'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('タイムライン設定'));
    await tester.pumpAndSettle();
    Finder inScreen(Finder f) => find.descendant(of: find.byType(TimelineConfigScreen), matching: f);
    await tester.tap(inScreen(find.text('アルゴリズムを追加')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Unicode 順でソート'), 120, scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unicode 順でソート'));
    await tester.pumpAndSettle();
    // 部品タイル → ノードを設定 FOW にプラグインの RRL(ラジオ)。
    await tester.tap(inScreen(find.text('Unicode 順でソート')));
    await tester.pumpAndSettle();
    expect(find.text('ノードを設定'), findsOneWidget);
    expect(find.text('並び順'), findsOneWidget);
    await tester.tap(find.text('降順'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    // 保存された部品に params、コンパイルされたグラフのノードに「パラメーター」ポート。
    final acc = fakeSession().account.key;
    final area = await c.read(settingsAreaProvider('nodeprog.$acc.tl.home').future);
    final cfg = TlConfig.fromJson((jsonDecode(area['tlcfg']! as String) as Map).cast<String, Object?>());
    final comp = cfg.algorithms.firstWhere((a) => a.isPlugin);
    expect(comp.type, 'plugin:slot:sample.timeline:unicode');
    expect(comp.params, {'order': 'desc'});
    // ホーム TL を読み直すと tl.sort に params が渡り、降順になる。
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    c.invalidate(timelineProvider);
    await tester.pumpAndSettle();
    final sortCall = rt.calls.where((x) => x.$1 == 'tl.sort').last;
    expect((sortCall.$2['params'] as Map)['order'], 'desc');
  });

  testWidgets('ノードエディター(自由キャンバス)の「ノードを設定」(D-171): ソートノードにプラグインの tl.params の RRL、決定で「パラメーター」ポートに JSON', (tester) async {
    fakes['tl'] = () => FakeSlotRuntime(
          manifest: {'id': 'sample.timeline', 'name': 'Unicode 順ソート', 'version': '0.2.0', 'kind': 'view', 'slots': ['tl']},
          handler: (self, fn, args) {
            switch (fn) {
              case 'tl.timelines':
                return {'timelines': [{'id': 'unicode', 'label': 'Unicode 順', 'base': 'home'}]};
              case 'tl.params':
                return {'root': {'t': 'Column', 'c': [
                  {'t': 'SectionHeader', 'p': {'title': '並び順'}},
                  {'t': 'RadioListTile', 'k': 'order', 'p': {'title': '昇順', 'value': 'asc', 'group': r'$.settings.order'}, 'on': {'change': 'settings.set'}},
                  {'t': 'RadioListTile', 'k': 'order', 'p': {'title': '降順', 'value': 'desc', 'group': r'$.settings.order'}, 'on': {'change': 'settings.set'}},
                ]}, 'defaults': {'order': 'asc'}};
              case 'tl.sort':
                return {'order': [for (final p in (args['posts'] as List)) (p as Map)['id']]};
            }
            return null;
          },
        );
    final c = await pump(tester);
    await register(c, 'tl');
    await tester.pumpAndSettle();
    c.read(routerProvider).push(Routes.nodes('tl.home'));
    await tester.pumpAndSettle();
    Finder onCanvas(Finder f) => find.descendant(of: find.byType(NodeEditorScreen), matching: f);
    // パレットから「Unicode 順でソート」を追加(パラメーターのポート付き)。
    await tester.tap(find.text('プラグインノードを検索'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Unicode');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unicode 順でソート').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンバスに追加'));
    await tester.pumpAndSettle();
    expect(onCanvas(find.text('Unicode 順でソート')), findsOneWidget);
    expect(onCanvas(find.text('パラメーター')), findsOneWidget);
    // ノード → 「ノードを設定」→ プラグインの RRL(並び順)→ 降順 → 決定。
    await tester.tap(onCanvas(find.text('Unicode 順でソート')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ノードを設定'));
    await tester.pumpAndSettle();
    expect(find.text('並び順'), findsOneWidget);
    await tester.tap(find.text('降順'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('決定'));
    await tester.pumpAndSettle();
    final saved = (await c.read(settingsAreaProvider('nodeprog.${fakeSession().account.key}.tl.home').future))['graph'] as String;
    final graph = NodeGraph.fromJson((jsonDecode(saved) as Map).cast<String, Object?>());
    final node = graph.nodes.where((n) => n.type == 'plugin:slot:sample.timeline:unicode').single;
    expect(pluginParamsOf(node), {'order': 'desc'});
    // 開き直すと今の値(降順)が選ばれている。キャンセルは何も変えない。
    await tester.tap(onCanvas(find.text('Unicode 順でソート')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ノードを設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('昇順'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    final saved2 = (await c.read(settingsAreaProvider('nodeprog.${fakeSession().account.key}.tl.home').future))['graph'] as String;
    expect(pluginParamsOf(NodeGraph.fromJson((jsonDecode(saved2) as Map).cast<String, Object?>()).nodes.where((n) => n.type.startsWith('plugin:slot:')).single), {'order': 'desc'});
  });

  testWidgets('メディアエディターの重ね (D-172 §2.2 v0.5): composer.media.overlay の Stack をプレビューの画素数で拡縮、Box の drag はプレビュー画素の座標で届く、横リストは中央揃え', (tester) async {
    late FakeSlotRuntime rt;
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
    fakes['ov'] = () => rt = FakeSlotRuntime(
          manifest: manifest('t.ov', ['composer.media']),
          handler: (self, fn, args) {
            switch (fn) {
              case 'media.catalog' || 'media.edit':
                if (fn == 'media.edit') {
                  // プレビュー 200×100 画素(実体は 1×1 PNG でも座標系は width/height で決まる)。
                  self.hostFn('composer.media.preview', {'token': args['token'], 'bytesB64': base64Encode(png), 'mimeType': 'image/png', 'width': 200, 'height': 100});
                }
                return {'genres': [{'id': 'transform', 'actions': [{'id': 'rotate', 'label': '回転'}, {'id': 'crop', 'label': 'クロップ'}]}]};
              case 'media.action':
                self.hostFn('composer.media.overlay', {'token': args['token'], 'root': {'t': 'Stack', 'k': 'ov', 'p': {'width': 200, 'height': 100}, 'c': [
                  {'t': 'Box', 'k': 'handle', 'p': {'left': 80, 'top': 30, 'width': 40, 'height': 40, 'color': '#ffffff88', 'radius': 20}, 'on': {'drag': 'rotate.drag'}},
                ]}});
                return {};
              case 'media.commit' || 'media.cancel':
                return {};
            }
            return null;
          },
        );
    final c = await pump(tester);
    final plugin = await register(c, 'ov');
    openPanel(tester, plugin, png);
    await tester.pumpAndSettle();
    // 横リスト: 2 つしか無いので中央に並ぶ(左右の余白が等しい)。
    final strip = tester.getRect(find.byKey(mediaEditorStripKey));
    final a = tester.getRect(find.byKey(const ValueKey('media.action.t.ov.transform.rotate')));
    final b = tester.getRect(find.byKey(const ValueKey('media.action.t.ov.transform.crop')));
    expect((a.left - strip.left) - (strip.right - b.right), closeTo(0, 1));
    // 重ね: Stack(200×100) がプレビュー枠に contain で入る。
    await tester.tap(find.byKey(const ValueKey('media.action.t.ov.transform.rotate')));
    await tester.pumpAndSettle();
    final ov = tester.getRect(find.byKey(mediaEditorOverlayKey));
    expect(ov.width / ov.height, closeTo(2.0, 0.01));
    final scale = ov.width / 200;
    // ハンドル(Box、drag 付き)を 20 論理 px 右へなぞる → プレビュー画素で 20/scale。
    final handle = find.descendant(of: find.byKey(mediaEditorOverlayKey), matching: find.byType(GestureDetector)).first;
    await tester.drag(handle, const Offset(20, 0));
    await tester.pumpAndSettle();
    final drags = rt.calls.where((x) => x.$1 == 'rotate.drag').toList();
    expect(drags.first.$2['phase'], 'start');
    expect(drags.last.$2['phase'], 'end');
    final dx = drags.where((x) => x.$2['phase'] == 'update').fold<double>(0, (acc, x) => acc + (x.$2['dx'] as num).toDouble());
    expect(dx, closeTo(20 / scale, 0.5));
    // root: null で消える。
    rt.hostFn('composer.media.overlay', {'token': rt.calls.firstWhere((x) => x.$1 == 'media.edit').$2['token'], 'root': null});
    await tester.pumpAndSettle();
    expect(find.byKey(mediaEditorOverlayKey), findsNothing);
  });

  testWidgets('合わせる先 (D-174 §2.2 v0.6): 重ねの Box をダブルタップ → 「この上にドラッグ」→ その上で指を離した drag の end に snap が付く、FOW で選び直せる', (tester) async {
    late FakeSlotRuntime rt;
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');
    fakes['snap'] = () => rt = FakeSlotRuntime(
          manifest: manifest('t.snap', ['composer.media']),
          handler: (self, fn, args) {
            switch (fn) {
              case 'media.catalog' || 'media.edit':
                if (fn == 'media.edit') self.hostFn('composer.media.preview', {'token': args['token'], 'bytesB64': base64Encode(png), 'mimeType': 'image/png', 'width': 200, 'height': 100});
                return {'genres': [{'id': 'process', 'actions': [{'id': 'sticker', 'label': 'スタンプ'}]}]};
              case 'media.action':
                self.hostFn('composer.media.overlay', {'token': args['token'], 'root': {'t': 'Stack', 'k': 'ov', 'p': {'width': 200, 'height': 100}, 'c': [
                  {'t': 'Box', 'k': 'face.0', 'p': {'left': 120, 'top': 10, 'width': 60, 'height': 60, 'label': '顔 1', 'color': '#00000000', 'borderColor': '#ffffff', 'borderWidth': 1}, 'on': {'tap': 'face.0'}},
                  {'t': 'Box', 'k': 'obj.0', 'p': {'left': 10, 'top': 10, 'width': 40, 'height': 40, 'label': 'スタンプ 1', 'color': '#ffffff88'}, 'on': {'drag': 'obj.0.move'}},
                ]}});
                return {};
              case 'media.commit' || 'media.cancel':
                return {};
            }
            return null;
          },
        );
    final c = await pump(tester);
    final plugin = await register(c, 'snap');
    openPanel(tester, plugin, png);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('media.action.t.snap.process.sticker')));
    await tester.pumpAndSettle();
    final ov = tester.getRect(find.byKey(mediaEditorOverlayKey));
    final scale = ov.width / 200;
    Offset g(double x, double y) => ov.topLeft + Offset(x * scale, y * scale);
    // 顔の枠をダブルタップ → ドロップダウン → 合わせる先にする。
    await tester.tapAt(g(150, 40));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(g(150, 40));
    await tester.pumpAndSettle();
    expect(find.text('この上にドラッグ(合わせる先にする)'), findsOneWidget);
    await tester.tap(find.text('この上にドラッグ(合わせる先にする)'));
    await tester.pumpAndSettle();
    // スタンプの枠(drag)を顔の上まで運んで離す → end に snap {key: face.0 …}。
    await tester.dragFrom(g(30, 30), Offset(120 * scale, 0));
    await tester.pumpAndSettle();
    final end = rt.calls.where((x) => x.$1 == 'obj.0.move' && x.$2['phase'] == 'end').last.$2;
    final snap = end['snap'] as Map;
    expect(snap['key'], 'face.0');
    expect(snap['label'], '顔 1');
    expect(snap['left'], 120);
    expect(snap['width'], 60);
    expect(snap['angle'], 0);
    // 外で離すと snap は付かない(タッチスロップを超える距離で)。
    await tester.dragFrom(g(30, 30), Offset(40 * scale, 0));
    await tester.pumpAndSettle();
    expect(rt.calls.where((x) => x.$1 == 'obj.0.move' && x.$2['phase'] == 'end').last.$2.containsKey('snap'), isFalse);
    // FOW「合わせる先を選ぶ…」: label 付きの枠が並び、チェックで切り替わる。
    await tester.tapAt(g(30, 30));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(g(30, 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('合わせる先を選ぶ…'));
    await tester.pumpAndSettle();
    expect(find.text('顔 1'), findsOneWidget);
    expect(find.text('スタンプ 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('media.snap.face.0'))); // 解除
    await tester.pumpAndSettle();
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    await tester.dragFrom(g(30, 30), Offset(120 * scale, 0));
    await tester.pumpAndSettle();
    expect(rt.calls.where((x) => x.$1 == 'obj.0.move' && x.$2['phase'] == 'end').last.$2.containsKey('snap'), isFalse);
  });
}
