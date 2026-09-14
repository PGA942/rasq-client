import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/action_bar_config.dart';
import 'package:rasq_client/features/home/action_bar_edit_sheet.dart';
import 'package:rasq_client/features/home/plugin_actions.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// 投稿のアクションボタン (D-176、契約 v0.7 §2.9): タグで既存ボタンのバンドルへ、アカウントごとのスロット設定、
/// 「アクションバーの編集」(D-208): タイル + (…) メニュー、ドラッグでバンドル / 並び替え。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body, url: Uri.parse('https://example.test/notes/$id'));
  late Map<String, FakeSlotRuntime Function()> fakes;
  setUp(() => fakes = {});

  late Directory iconDir;
  setUp(() => iconDir = Directory.systemTemp.createTempSync('rasq_icons'));
  tearDown(() => iconDir.deleteSync(recursive: true));

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'こんにちは')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
        // 写真アイコン (D-212): 置き場は一時ディレクトリ、選択は 2×1 の PNG。
        bundleIconDirProvider.overrideWithValue(() async => iconDir),
        bundlePhotoPickerProvider.overrideWithValue(() async {
          final f = File('${iconDir.path}/picked.png');
          f.writeAsBytesSync(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAYAAAD0In+KAAAADklEQVR4nGP4z8AAQv8BD/kD/YURmXYAAAAASUVORK5CYII='));
          return XFile(f.path);
        }),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  test('タグの類似度: 完全一致 = 1、別名(Favorite ↔ Star)も届く、遠いものは閾値未満', () {
    expect(tagSimilarity('Favorite', 'favorite'), 1);
    expect(tagSimilarity('Bookmark', 'Book'), greaterThan(0.5));
    expect(tagSimilarity('Copy', 'Reply'), lessThan(0.85));
    const reaction = ActionDescriptor(id: 'reaction', genreTag: 'Reaction', label: 'リアクション');
    const renote = ActionDescriptor(id: 'renote', genreTag: 'Repost', label: 'リノート');
    final m = bestMatch(['Favorite', 'Bookmark', 'Star'], [reaction, renote])!;
    expect(m.action.id, 'reaction'); // 別名 Favorite / Star が Reaction に付いている
    expect(m.score, 1);
    final q = bestMatch(['Quote', 'Repost'], [reaction, renote])!;
    expect(q.action.id, 'renote');
    expect(bestMatch(['Copy'], [reaction, renote])!.score, lessThan(0.85));
  });

  testWidgets('宣言だけでバンドルに入る → タップで post.action(post / account)→ message がトースト、composer.open でコンポーザー、スロット設定で無効化', (tester) async {
    late FakeSlotRuntime rt;
    fakes['act'] = () => rt = FakeSlotRuntime(
          manifest: {
            'id': 't.act', 'name': '投稿ボタン', 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget'],
            'actions': [
              {'id': 'later', 'label': '後で読む', 'icon': 'bookmark', 'tags': ['Favorite', 'Bookmark', 'Star']},
              {'id': 'copy', 'label': '本文をコピー', 'icon': 'content_copy', 'tags': ['Copy']},
              {'id': 'quoteDraft', 'label': '引用の下書き', 'icon': 'format_quote', 'tags': ['Quote', 'Repost']},
            ],
          },
          handler: (self, fn, args) {
            if (fn == 'post.action') {
              if (args['actionId'] == 'quoteDraft') {
                self.hostFn('composer.open', {'token': args['token'], 'text': '「こんにちは」\nhttps://example.test/notes/p1'});
                return {'result': {'done': true}};
              }
              return {'result': {'done': true, 'message': '${args['actionId']} を実行しました'}};
            }
            return null;
          },
        );
    final c = await pump(tester);
    final p = await c.read(slotPluginsProvider.notifier).register('fake:act', bytes: Uint8List.fromList('act'.codeUnits));
    expect(p!.manifest.actions.length, 3);
    expect(p.manifest.appFns, contains('composer.open'));
    await tester.pumpAndSettle();
    // 「後で読む」は Favorite/Star → リアクションの自動バンドル、「引用の下書き」は リノートの自動バンドル、
    // 「本文をコピー」は届かないので単体で末尾。
    expect(find.byTooltip('リアクション'), findsOneWidget); // バンドル名 = 既存ボタンのラベル
    expect(find.byTooltip('本文をコピー'), findsOneWidget);
    await tester.tap(find.byTooltip('リアクション'));
    await tester.pumpAndSettle();
    expect(find.text('後で読む'), findsOneWidget); // ドロップダウン(最下層)
    await tester.tap(find.text('後で読む'));
    await tester.pumpAndSettle();
    final call = rt.calls.where((x) => x.$1 == 'post.action').single.$2;
    expect(call['actionId'], 'later');
    expect((call['post'] as Map)['url'], 'https://example.test/notes/p1');
    expect(call['account'], {'sns': 'misskey', 'instance': 'example.test', 'handle': 'tester'});
    expect(find.text('later を実行しました'), findsOneWidget);
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    await tester.pumpAndSettle();
    // 引用の下書き → composer.open → コンポーザーに文面。
    await tester.tap(find.byTooltip('リノート'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('引用の下書き'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, '「こんにちは」\nhttps://example.test/notes/p1');
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    // スロット設定: このアカウントで「本文をコピー」を無効に → バーから消える(設定エリア slots.<account>)。
    await c.read(settingsAreaProvider(slotSettingsArea(acc.key)).notifier).set('enabled', {pluginActionId('t.act', 'copy'): false});
    await tester.pumpAndSettle();
    expect(find.byTooltip('本文をコピー'), findsNothing);
    expect(c.read(slotActionSettingsProvider(acc.key)).isEnabled(pluginActionId('t.act', 'copy')), isFalse);
  });

  testWidgets('アクションバーの編集 FOW (D-208 → D-210): アカウントタイル / 全画面バー / 投稿バー、(…) メニュー、隙間で並び替え、タイルの上に落としてバンドル → 設定 FOW(名前 / アイコン / メンバー / 検索 / 解除)、詳細は RRL の FOW', (tester) async {
    fakes['act'] = () => FakeSlotRuntime(
          manifest: {
            'id': 't.act', 'name': '投稿ボタン', 'version': '0.1.0', 'kind': 'action', 'description': '後で読む・本文をコピーを足すテスト', 'slots': ['post.action'], 'permissions': ['fow.widget'],
            'actions': [{'id': 'copy', 'label': '本文をコピー', 'icon': 'content_copy', 'tags': ['Copy']}],
          },
          handler: (self, fn, args) => {'result': {'done': true}},
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:act', bytes: Uint8List.fromList('act'.codeUnits));
    await tester.pumpAndSettle();
    final copyId = pluginActionId('t.act', 'copy');
    final accountKey = fakeSession().account.key;
    // 投稿の … → アクションバーを編集(FOW)。
    await tester.tap(find.byTooltip('メニュー').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('アクションバーを編集'));
    await tester.pumpAndSettle();
    expect(find.text('アクションバーの編集'), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.account')), findsOneWidget);
    expect(find.text('全画面アクションバー'), findsOneWidget);
    expect(find.text('投稿アクションバー'), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.tile.reply.viewer')), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.tile.reply')), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.slot.threshold')), findsNothing); // 設定へ移動 (D-210)
    // 返信の (…) → 詳細 = RRL で描く FOW(プラグインの見出し + アクションの詳細)。
    await tester.ensureVisible(find.byKey(const ValueKey('actionbar.tile.menu.reply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('actionbar.tile.menu.reply')));
    await tester.pumpAndSettle();
    expect(find.text('削除'), findsNothing); // SNS のボタンには無い
    await tester.tap(find.text('詳細'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('actionbar.detail.rrl')), findsOneWidget);
    expect(find.text('スロット(ジャンル)'), findsOneWidget);
    await tester.tap(find.text('閉じる').last);
    await tester.pumpAndSettle();
    // アクションリスト化 → バンドルができて設定 FOW が開く。名前を変え、アイコンはメンバーの使い回しに。
    await tester.tap(find.byKey(const ValueKey('actionbar.tile.menu.reply')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('アクションリスト化'));
    await tester.pumpAndSettle();
    expect(find.text('バンドルの設定'), findsOneWidget);
    var cfg = c.read(actionBarConfigProvider(accountKey));
    expect(cfg.lists.single.memberIds, ['reply']);
    final listId = cfg.lists.single.id;
    await tester.enterText(find.byKey(const ValueKey('actionbar.bundle.name')), '返信まわり');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('actionbar.bundle.icon.member.reply')));
    await tester.pumpAndSettle();
    cfg = c.read(actionBarConfigProvider(accountKey));
    expect(cfg.lists.single.name, '返信まわり');
    expect(cfg.lists.single.icon, 'member:reply');
    // Material Icon のピッカー (D-212): 検索して選ぶ。
    await tester.tap(find.byKey(const ValueKey('actionbar.bundle.icon.material')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('actionbar.icon.search')), 'star_border');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('actionbar.icon.star_border')));
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(accountKey)).lists.single.icon, 'material:star_border');
    // 写真 (D-212): アプリの保存領域へコピーされ、file: で持つ。
    // ファイル I/O は本物の非同期(FakeAsync では進まない)。
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('actionbar.bundle.icon.photo')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    final photoIcon = c.read(actionBarConfigProvider(accountKey)).lists.single.icon!;
    expect(photoIcon, startsWith('file:${iconDir.path}'));
    expect(File(photoIcon.substring('file:'.length)).existsSync(), isTrue);
    await tester.tap(find.byKey(const ValueKey('actionbar.bundle.icon.member.reply')));
    await tester.pumpAndSettle();
    // 「プラグインを検索」→ 本文をコピー をバンドルに足す(スロット設定も有効に)。
    await tester.tap(find.byKey(const ValueKey('actionbar.bundle.search')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(actionBarPluginSearchKey), 'コピー');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('actionbar.plugin.$copyId')));
    await tester.pumpAndSettle();
    cfg = c.read(actionBarConfigProvider(accountKey));
    expect(cfg.lists.single.memberIds, ['reply', copyId]);
    expect(find.byKey(ValueKey('actionbar.bundle.member.$copyId')), findsOneWidget);
    expect(find.text('後で読む・本文をコピーを足すテスト'), findsOneWidget); // プラグインタイルの説明
    // メンバーの … → バンドルから外す → バーに戻る。
    await tester.tap(find.descendant(of: find.byKey(ValueKey('actionbar.bundle.member.$copyId')), matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('バンドルから外す'));
    await tester.pumpAndSettle();
    cfg = c.read(actionBarConfigProvider(accountKey));
    expect(cfg.lists.single.memberIds, ['reply']);
    expect(cfg.order, contains(copyId));
    await tester.tap(find.text('閉じる').last);
    await tester.pumpAndSettle();
    expect(find.text('バンドルの設定'), findsNothing);
    // リノートのタイルをバンドルの上に落とす → バンドルに入り、設定 FOW が開く。
    final listKey = ActionBarConfig.listKey(listId);
    final renote = find.byKey(const ValueKey('actionbar.tile.renote'));
    await tester.ensureVisible(renote);
    await tester.pumpAndSettle();
    var g = await tester.startGesture(tester.getCenter(renote));
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveTo(tester.getCenter(find.byKey(ValueKey('actionbar.tile.$listKey'))));
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pumpAndSettle();
    cfg = c.read(actionBarConfigProvider(accountKey));
    expect(cfg.lists.single.memberIds, ['reply', 'renote']);
    expect(find.text('バンドルの設定'), findsOneWidget);
    // リストの解除 → 中身がバーに戻る。
    await tester.tap(find.byKey(const ValueKey('actionbar.bundle.dissolve')));
    await tester.pumpAndSettle();
    cfg = c.read(actionBarConfigProvider(accountKey));
    expect(cfg.lists, isEmpty);
    expect(cfg.order.take(2), ['reply', 'renote']);
    // 隙間に落として並び替え: 末尾の隙間へリノート(投稿バー)。
    await tester.ensureVisible(find.byKey(const ValueKey('actionbar.tile.renote')));
    await tester.pumpAndSettle();
    final n = c.read(actionBarConfigProvider(accountKey)).order.length;
    g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('actionbar.tile.renote'))));
    await tester.pump(const Duration(milliseconds: 400));
    await g.moveTo(tester.getCenter(find.byKey(ValueKey('actionbar.gap.$n'))));
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(accountKey)).order.last, 'renote');
    // 全画面バーは別の構成: こちらは動いていない。
    expect(c.read(actionBarConfigProvider(ActionBarConfigStore.viewerKey(accountKey))).order, isEmpty);
    // プラグインボタンの (…) → 削除 = スロット設定で無効。
    await tester.ensureVisible(find.byKey(ValueKey('actionbar.tile.menu.$copyId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('actionbar.tile.menu.$copyId')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(c.read(slotActionSettingsProvider(accountKey)).isEnabled(copyId), isFalse);
    expect(find.byKey(ValueKey('actionbar.tile.$copyId')), findsNothing);
  });

  testWidgets('設定 → SNSプラグイン → プラグインボタン (D-210): 宣言されたボタンのスイッチと束ねる閾値', (tester) async {
    fakes['act'] = () => FakeSlotRuntime(
          manifest: {'id': 't.act', 'name': '投稿ボタン', 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget'], 'actions': [{'id': 'copy', 'label': '本文をコピー', 'icon': 'content_copy', 'tags': ['Copy']}]},
          handler: (self, fn, args) => {'result': {'done': true}},
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:act', bytes: Uint8List.fromList('act'.codeUnits));
    await tester.pumpAndSettle();
    final copyId = pluginActionId('t.act', 'copy');
    c.read(routerProvider).push('/settings/actionbar-plugins');
    await tester.pumpAndSettle();
    expect(find.text('プラグインボタン'), findsWidgets);
    expect(find.byKey(const ValueKey('actionbar.slot.threshold')), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('actionbar.slot.$copyId')));
    await tester.pumpAndSettle();
    expect(c.read(slotActionSettingsProvider(fakeSession().account.key)).isEnabled(copyId), isFalse);
  });

  testWidgets('バンドルのボタン (D-210): アイコンから出る FOW(バンドル名 + ボタン + 名称のタイル)→ タイル全体で実行', (tester) async {
    fakes['act'] = () => FakeSlotRuntime(
          manifest: {'id': 't.act', 'name': '投稿ボタン', 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget'], 'actions': [{'id': 'later', 'label': '後で読む', 'icon': 'bookmark_add', 'tags': ['Favorite']}]},
          handler: (self, fn, args) => {'result': {'done': true, 'message': '後で読むに入れました'}},
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:act', bytes: Uint8List.fromList('act'.codeUnits));
    await tester.pumpAndSettle();
    final laterId = pluginActionId('t.act', 'later');
    // 「リアクション」のバンドル(自動)→ タップで FOW。
    await tester.tap(find.byTooltip('リアクション').first);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('actionbar.bundle.pick.$laterId')), findsOneWidget);
    expect(find.text('リアクション'), findsWidgets); // FOW のヘッダー
    await tester.tap(find.byKey(ValueKey('actionbar.bundle.pick.$laterId')));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('actionbar.bundle.pick.$laterId')), findsNothing);
    expect(find.text('後で読むに入れました'), findsOneWidget);
  });
}
