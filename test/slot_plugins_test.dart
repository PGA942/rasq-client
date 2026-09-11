import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/plugins/media_editor_screen.dart';
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
    await c.read(slotPluginsProvider.notifier).mediaEdit(c.read(slotPluginsForProvider(SlotIds.composerMedia)).single, index: 0, name: 'a.png', mimeType: 'image/png', bytes: Uint8List.fromList([9, 9]), onReplace: (b, m, n) => replaced = [b, m, n]);
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

  testWidgets('メディアエディター (D-171 §2.2): プラグイン / ジャンルの見方、下付き横リスト → media.action、下付き FOW でプレビューが縮む、別プラグインは直列合成、適用 → media.commit', (tester) async {
    late FakeSlotRuntime rt;
    late FakeSlotRuntime rt2;
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
    // 2 つめ: 加工(process)だけを持つプラグイン(media.catalog あり)。
    fakes['media2'] = () => rt2 = FakeSlotRuntime(
          manifest: manifest('t.media2', ['composer.media']),
          handler: (self, fn, args) {
            switch (fn) {
              case 'media.catalog' || 'media.edit':
                return {'genres': [{'id': 'process', 'actions': [{'id': 'blur', 'label': 'ぼかし'}]}]};
              case 'media.action':
                return {};
              case 'media.commit':
                return {'bytesB64': base64Encode([9, 9]), 'mimeType': 'image/jpeg', 'name': 'blurred.jpg'};
              case 'media.cancel':
                return {};
            }
            return null;
          },
        );
    final c = await pump(tester);
    final plugin = await register(c, 'media');
    await register(c, 'media2');
    final future = c.read(routerProvider).push<MediaEditResult>(Routes.mediaEditor, extra: MediaEditorArgs(plugin: plugin, bytes: png, name: 'a.png', mimeType: 'image/png'));
    await tester.pumpAndSettle();
    expect(find.byType(MediaEditorScreen), findsOneWidget);
    expect(rt.calls.where((x) => x.$1 == 'media.edit').length, 1);
    expect(rt.calls.where((x) => x.$1 == 'media.catalog').length, 1);
    expect(rt2.calls.where((x) => x.$1 == 'media.catalog').length, 1);
    // 見方「プラグイン」: 右の列 = プラグイン、下の横リスト = 選んだプラグインの全編集ボタン。
    expect(find.byKey(const ValueKey('media.plugin.t.media')), findsOneWidget);
    expect(find.byKey(const ValueKey('media.plugin.t.media2')), findsOneWidget);
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
    // ↓ で見方を「ジャンル」に: 右の列 = 既定 5 種 + カスタム(スタンプ)、下 = そのジャンルの編集(全プラグイン)。
    await tester.tap(find.byKey(const ValueKey('media.editor.pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ジャンル'));
    await tester.pumpAndSettle();
    final genreList = find.descendant(of: find.byType(MediaEditorScreen), matching: find.byType(Scrollable)).last;
    for (final g in ['tone', 'process', 'transform', 'add', 'draw', 'sticker']) {
      await tester.scrollUntilVisible(find.byKey(ValueKey('media.genre.$g')), 60, scrollable: genreList);
      expect(find.byKey(ValueKey('media.genre.$g')), findsOneWidget, reason: g);
    }
    await tester.scrollUntilVisible(find.byKey(const ValueKey('media.genre.tone')), -60, scrollable: genreList);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('media.action.t.media.tone.gamma')), findsOneWidget);
    expect(find.byKey(const ValueKey('media.action.t.media.transform.rotl')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('media.genre.process')));
    await tester.pumpAndSettle();
    // 別プラグインの編集 → 今のプラグインを commit(直列合成)→ 次の media.edit に結果を渡す。
    await tester.tap(find.byKey(const ValueKey('media.action.t.media2.process.blur')));
    await tester.pumpAndSettle();
    expect(rt.calls.where((x) => x.$1 == 'media.commit').length, 1);
    final edit2 = rt2.calls.where((x) => x.$1 == 'media.edit').single.$2;
    expect(edit2['bytesB64'], base64Encode([1, 2, 3]));
    expect(edit2['name'], 'edited.png');
    expect(rt2.calls.where((x) => x.$1 == 'media.action').single.$2['action'], 'blur');
    expect(find.byType(Slider), findsNothing); // 前のプラグインの下付き FOW は閉じる
    // 適用 → 今のプラグイン(media2)の media.commit の結果が呼び出し元へ。
    await tester.tap(find.byKey(const ValueKey('media.editor.apply')));
    await tester.pumpAndSettle();
    final result = await future;
    expect(result!.bytes, [9, 9]);
    expect(result.name, 'blurred.jpg');
    expect(find.byType(MediaEditorScreen), findsNothing);
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
}
