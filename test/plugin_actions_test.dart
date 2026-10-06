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
import 'package:rasq_design/rasq_design.dart';
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

  test('構成キー → どのアカウントのバーか (D-284)', () {
    expect(accountKeyOfConfigKey('misskey:mk.example:me'), 'misskey:mk.example:me');
    expect(accountKeyOfConfigKey('viewer:misskey:mk.example:me'), 'misskey:mk.example:me');
    // 内蔵のバー(加工画面 / RASQ の投稿)と、旧来の共通構成は、アカウントに属さない。
    expect(accountKeyOfConfigKey(editorImageConfigKey), isNull);
    expect(accountKeyOfConfigKey(rasqPostConfigKey), isNull);
    expect(accountKeyOfConfigKey(''), isNull);
  });

  group('ボタン共通の属性 (契約 v0.14 §2.11、D-305)', () {
    PluginAction action(Map<String, Object?> decl, {String source = 'store:t.p', List<String> permissions = const ['fow.widget']}) {
      final m = SlotManifest.fromJson({'id': 't.p', 'name': 'P', 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action', 'viewer.overlay', 'composer.media', 'composer.text'], 'permissions': permissions, 'actions': [decl]});
      return PluginAction(plugin: SlotPlugin(manifest: m, source: source, runtime: FakeSlotRuntime(manifest: const {}, handler: (self, fn, args) => null)), decl: m.actions.single);
    }

    const reaction = ActionDescriptor(id: 'reaction', genreTag: 'Reaction', label: 'リアクション');
    const reply = ActionDescriptor(id: 'reply', genreTag: 'Reply', label: '返信');

    test('placement: auto は宣言だけで置かれる、manual(tags 無しも)は構成に入っているときだけ', () {
      final auto = action({'id': 'later', 'label': '後で', 'tags': ['Favorite']});
      final manual = action({'id': 'pin', 'label': '留める', 'tags': ['Pin'], 'placement': 'manual'});
      final noTags = action({'id': 'bare', 'label': '素', 'placement': 'manual'});
      expect((auto.isManual, manual.isManual, noTags.isManual), (false, true, true));
      final plugins = [auto, manual, noTags];
      var m = mergePluginActions(config: const ActionBarConfig(), snsActions: [reaction, reply], plugins: plugins, settings: const SlotActionSettings());
      expect(m.actions.map((a) => a.id), [reaction.id, reply.id, auto.id]); // manual は出ない
      expect(m.config.lists.single.memberIds, [reaction.id, auto.id]); // Favorite → リアクションのバンドル
      // (+) で足した(並びに入った)manual は出る。バンドルに入れたものも同じ。
      m = mergePluginActions(config: ActionBarConfig(order: [reaction.id, manual.id], lists: [ActionListDef(id: 'l', name: 'L', memberIds: [reply.id, noTags.id])]), snsActions: [reaction, reply], plugins: plugins, settings: const SlotActionSettings());
      expect(m.actions.map((a) => a.id), containsAll([manual.id, noTags.id]));
      expect(m.config.order, contains(manual.id));
    });

    test('switch: オフのボタンは合成にも候補にも出ず、temp は評価しない。アカウントごとの有効 / 無効とは AND', () {
      final a = action({'id': 'later', 'label': '後で', 'tags': ['Favorite'], 'auto': true}, permissions: ['fow.widget', 'auto_hook']);
      final prefs = ActionButtonPrefs(switches: {a.id: false});
      expect(prefs.switchOn(a.id), isFalse);
      expect(a.effectiveAuto(const ActionButtonPrefs()), isTrue);
      expect(a.effectiveAuto(prefs), isFalse);
      expect(mergePluginActions(config: const ActionBarConfig(), snsActions: [reaction], plugins: [a], settings: const SlotActionSettings(), prefs: prefs).actions.map((x) => x.id), [reaction.id]);
      expect(mergePluginActions(config: const ActionBarConfig(), snsActions: [reaction], plugins: [a], settings: SlotActionSettings(enabled: {a.id: false})).actions.map((x) => x.id), [reaction.id]);
      // 保存の形: {"switch": {ActionKey: bool}, "auto": {ActionKey: bool}}。上書きの外し方(null)。
      final j = ActionButtonPrefs.fromJson({'switch': {a.id: false}, 'auto': {a.id: false, 'junk': 'x'}});
      expect((j.switchOn(a.id), j.autoOverride(a.id), j.autoOverride('junk')), (false, false, false));
      expect(j.autoWith(a.id, null).containsKey(a.id), isFalse);
    });

    test('temp の既定: 面ごとのホスト既定 → 審査済みの宣言 → 利用者の上書き。post.action は auto_hook が要り、サイドロードは宣言を読まない', () {
      final viewer = action({'id': 'toggle', 'slot': 'viewer.overlay', 'label': 'QR', 'tags': ['QR']});
      final text = action({'id': 't', 'slot': 'composer.text', 'label': '校正', 'tags': ['Text']});
      final filter = action({'id': 'glaze', 'slot': 'composer.media', 'label': 'Glaze', 'tags': ['Glaze'], 'output': 'filter'});
      final edit = action({'id': 'edit', 'slot': 'composer.media', 'label': '編集', 'tags': ['Edit'], 'auto': true});
      final post = action({'id': 'later', 'label': '後で', 'tags': ['Favorite']});
      const none = ActionButtonPrefs();
      expect([viewer, text, filter, post].map((a) => a.effectiveAuto(none)), [true, true, false, false]);
      expect([viewer, text, filter, post].map((a) => a.hasTemp), [true, true, true, false]);
      expect((edit.hasTemp, edit.effectiveAuto(none)), (false, false)); // replace / sticker は状態を持たない
      // 宣言 auto(審査済み)→ 利用者の上書きが勝つ。
      final declaredOff = action({'id': 'toggle', 'slot': 'viewer.overlay', 'label': 'QR', 'tags': ['QR'], 'auto': false});
      expect(declaredOff.effectiveAuto(none), isFalse);
      expect(declaredOff.effectiveAuto(ActionButtonPrefs(auto: {declaredOff.id: true})), isTrue);
      // サイドロード(未審査)の宣言は読まない → ホスト既定。
      expect(action({'id': 'toggle', 'slot': 'viewer.overlay', 'label': 'QR', 'tags': ['QR'], 'auto': false}, source: 'file:/x.wasm').effectiveAuto(none), isTrue);
      // post.action の auto: true は auto_hook のある審査済みだけ。destructive / autoHookForbidden は不可。
      final hook = action({'id': 'mark', 'label': '既読', 'tags': ['Read'], 'auto': true}, permissions: ['fow.widget', 'auto_hook']);
      expect((hook.canAutoRun, hook.hasTemp, hook.effectiveAuto(none)), (true, true, true));
      expect(action({'id': 'mark', 'label': '既読', 'tags': ['Read'], 'auto': true}).canAutoRun, isFalse);
      expect(action({'id': 'mark', 'label': '既読', 'tags': ['Read'], 'auto': true}, source: 'file:/x.wasm', permissions: ['fow.widget', 'auto_hook']).canAutoRun, isFalse);
      expect(action({'id': 'del', 'label': '消す', 'tags': ['Delete'], 'auto': true, 'destructive': true}, permissions: ['fow.widget', 'auto_hook']).canAutoRun, isFalse);
      expect(action({'id': 'x', 'label': 'x', 'tags': ['X'], 'auto': true, 'autoHookForbidden': true}, permissions: ['fow.widget', 'auto_hook']).canAutoRun, isFalse);
      // 利用者の上書きがあっても、自動実行できないボタンは false のまま。
      expect(action({'id': 'later', 'label': '後で', 'tags': ['Favorite']}).effectiveAuto(ActionButtonPrefs(auto: {'slot:t.p:later': true})), isFalse);
      expect(postTransformActionId('t.p'), 'slot:t.p:post.transform');
    });
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
    // composer.open / astell.share / mute.add / url.open はサイドロードの制限モード (D-308) で閉じるので、審査済み(ストア)として登録する。
    final p = await c.read(slotPluginsProvider.notifier).register('store:t.act', bytes: Uint8List.fromList('act'.codeUnits));
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
    expect(find.text('削除'), findsOneWidget); // SNS のボタンも外せる (D-215)
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
    // ファイル I/O は本物の非同期(FakeAsync では進まない)。固定待ちだと遅い CI で落ちるので、書き終わるまで待つ。
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('actionbar.bundle.icon.photo')));
      for (var i = 0; i < 200; i++) {
        if (c.read(actionBarConfigProvider(accountKey)).lists.single.icon?.startsWith('file:') ?? false) break;
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
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
    // SNS のボタンの削除 (D-215): リノートの (…) → 削除 → バーから消え(hidden)、(+) の検索に出て戻せる。
    await tester.ensureVisible(find.byKey(const ValueKey('actionbar.tile.menu.renote')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('actionbar.tile.menu.renote')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(accountKey)).hidden, {'favorite', 'renote'}); // お気に入りは既定で外している (D-447)
    expect(find.byKey(const ValueKey('actionbar.tile.renote')), findsNothing);
    expect(find.byKey(const ValueKey('actionbar.tile.renote.viewer')), findsOneWidget); // 全画面バーは別構成
    await tester.ensureVisible(find.byKey(const ValueKey('actionbar.plugins.open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('actionbar.plugins.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('actionbar.plugin.renote')), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.plugin.reply')), findsNothing); // 出ているボタンは候補に無い
    await tester.tap(find.byKey(const ValueKey('actionbar.plugin.renote')));
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(accountKey)).hidden, {'favorite'});
    expect(find.byKey(const ValueKey('actionbar.tile.renote')), findsOneWidget);
    // 隙間に落として並び替え: 末尾の隙間へリノート(投稿バー)。
    // 落とす先の隙間(1 段上の行)が FOW のヘッダーに隠れない位置まで戻す(編集 FOW は面が増えて長い、D-251)。
    final n = c.read(actionBarConfigProvider(accountKey)).order.length;
    final sheet = find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.byKey(const ValueKey('actionbar.surface.viewer')), -60, scrollable: sheet);
    await tester.pumpAndSettle();
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

  testWidgets('post.action の temp (契約 v0.14 §2.9): auto_hook のある審査済みの auto: true は、タイルごとに 1 回 auto: true で呼ばれる(トースト無し)。権限が無い / サイドロード / switch オフは動かない', (tester) async {
    late FakeSlotRuntime hook;
    late FakeSlotRuntime noHook;
    late FakeSlotRuntime side;
    // バーが溢れないよう、t.hook の「既読」以外は Favorite → リアクションのバンドルに入れる。
    Map<String, Object?> manifest(String id, {required List<String> permissions, bool bundled = true}) => {
          'id': id, 'name': id, 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': permissions,
          'actions': [
            {'id': 'mark', 'label': '既読', 'icon': 'done', 'tags': [bundled ? 'Favorite' : 'Read'], 'auto': true},
            if (!bundled) {'id': 'copy', 'label': 'コピー', 'icon': 'content_copy', 'tags': ['Favorite']},
          ],
        };
    Map<String, Object?> handler(String fn, Map<String, Object?> args) => {'result': {'done': true, 'message': '${args['actionId']} を実行しました'}};
    fakes['store:t.hook'] = () => hook = FakeSlotRuntime(manifest: manifest('t.hook', permissions: ['fow.widget', 'auto_hook'], bundled: false), handler: (self, fn, args) => handler(fn, args));
    fakes['store:t.nohook'] = () => noHook = FakeSlotRuntime(manifest: manifest('t.nohook', permissions: ['fow.widget']), handler: (self, fn, args) => handler(fn, args));
    fakes['side'] = () => side = FakeSlotRuntime(manifest: manifest('t.side', permissions: ['fow.widget', 'auto_hook']), handler: (self, fn, args) => handler(fn, args));
    final c = await pump(tester);
    final slots = c.read(slotPluginsProvider.notifier);
    await slots.register('store:t.hook', bytes: Uint8List.fromList('hook'.codeUnits));
    await slots.register('store:t.nohook', bytes: Uint8List.fromList('nohook'.codeUnits));
    await slots.register('fake:side', bytes: Uint8List.fromList('side'.codeUnits));
    await tester.pumpAndSettle();
    final markId = pluginActionId('t.hook', 'mark');
    final prefs = c.read(actionButtonPrefsProvider);
    final byId = {for (final a in c.read(pluginActionsProvider)) a.id: a};
    expect((byId[markId]!.canAutoRun, byId[markId]!.hasTemp, byId[markId]!.effectiveAuto(prefs)), (true, true, true));
    expect(byId[pluginActionId('t.hook', 'copy')]!.effectiveAuto(prefs), isFalse); // 既定 OFF
    expect((byId[pluginActionId('t.nohook', 'mark')]!.canAutoRun, byId[pluginActionId('t.nohook', 'mark')]!.hasTemp), (false, false)); // auto_hook が無い
    expect(byId[pluginActionId('t.side', 'mark')]!.canAutoRun, isFalse); // サイドロード
    // TL の投稿 p1 のタイルが作られた → t.hook の mark だけが auto: true で 1 回。message はトーストに出ない。
    Iterable<Map<String, Object?>> autoCalls(FakeSlotRuntime rt) => rt.calls.where((x) => x.$1 == 'post.action').map((x) => x.$2);
    expect(autoCalls(hook).map((a) => (a['actionId'], a['auto'])), [('mark', true)]);
    expect((autoCalls(hook).single['post'] as Map)['url'], 'https://example.test/notes/p1');
    expect(autoCalls(noHook), isEmpty);
    expect(autoCalls(side), isEmpty);
    expect(find.text('mark を実行しました'), findsNothing);
    // 描き直しても同じ投稿にはもう呼ばない。
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(autoCalls(hook).length, 1);
    // 手で押したときは auto が付かず、message がトーストに出る(ボタン自体は今までどおり)。
    await tester.tap(find.byTooltip('既読'));
    await tester.pumpAndSettle();
    expect(autoCalls(hook).last.containsKey('auto'), isFalse);
    expect(find.text('mark を実行しました'), findsOneWidget);
    // switch オフ(端末全体): ボタンが消え、temp も評価しない(false)。
    await setActionSwitch(c.read(settingsAreaProvider(actionButtonPrefsArea).notifier), c.read(actionButtonPrefsProvider), markId, false);
    await tester.pumpAndSettle();
    expect(find.byTooltip('既読'), findsNothing);
    expect(byId[markId]!.effectiveAuto(c.read(actionButtonPrefsProvider)), isFalse);
  });

  testWidgets('設定 → SNSプラグイン → プラグインボタン (D-210 → D-305): 面ごとの節に switch と「面を開いたとき自動でオン」、このアカウントの有効 / 無効と束ねる閾値', (tester) async {
    fakes['act'] = () => FakeSlotRuntime(
          manifest: {'id': 't.act', 'name': '投稿ボタン', 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget'], 'actions': [{'id': 'copy', 'label': '本文をコピー', 'icon': 'content_copy', 'tags': ['Copy']}]},
          handler: (self, fn, args) => {'result': {'done': true}},
        );
    fakes['qr'] = () => FakeSlotRuntime(manifest: {'id': 't.qr', 'name': 'QR 検出', 'version': '0.1.0', 'kind': 'mediaViewer', 'slots': ['viewer.overlay'], 'permissions': ['fow.widget']}, handler: (self, fn, args) => null);
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:act', bytes: Uint8List.fromList('act'.codeUnits));
    await c.read(slotPluginsProvider.notifier).register('fake:qr', bytes: Uint8List.fromList('qr'.codeUnits));
    await tester.pumpAndSettle();
    final copyId = pluginActionId('t.act', 'copy');
    final qrId = pluginActionId('t.qr', viewerToggleActionId);
    c.read(routerProvider).push('/settings/actionbar-plugins');
    await tester.pumpAndSettle();
    expect(find.text('プラグインボタン'), findsWidgets);
    final list = find.byType(Scrollable).first;
    // 一覧は長いので、先頭に戻してから目当ての行までスクロールする(下へしか進まないので)。
    Future<void> show(Finder f) async {
      tester.state<ScrollableState>(list).position.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(f, 120, scrollable: list);
      await tester.pumpAndSettle();
    }

    // 面ごとの節。投稿タイルの「本文をコピー」は switch だけ(auto_hook が無いので temp の行は出ない)、全画面の QR は switch + temp。
    for (final title in ['投稿タイル', '全画面', '加工画面', 'コンポーザー本文', '投稿加工(自動)']) {
      await show(find.text(title));
      expect(find.text(title), findsOneWidget);
    }
    await show(find.byKey(ValueKey('actionbar.switch.$copyId')));
    expect(find.byKey(ValueKey('actionbar.auto.$copyId')), findsNothing);
    expect(find.textContaining('単体で末尾'), findsOneWidget); // 配置の説明
    await show(find.byKey(ValueKey('actionbar.auto.$qrId')));
    expect(find.text('既定(オン)'), findsOneWidget); // ホスト既定
    await tester.tap(find.byKey(ValueKey('actionbar.auto.$qrId')));
    await tester.pumpAndSettle();
    expect(c.read(actionButtonPrefsProvider).autoOverride(qrId), isFalse);
    expect(find.textContaining('設定で上書き中'), findsOneWidget);
    // このアカウント: 有効 / 無効(従来)と閾値。
    await show(find.byKey(ValueKey('actionbar.slot.$copyId')));
    await tester.tap(find.byKey(ValueKey('actionbar.slot.$copyId')));
    await tester.pumpAndSettle();
    expect(c.read(slotActionSettingsProvider(fakeSession().account.key)).isEnabled(copyId), isFalse);
    await show(find.byKey(const ValueKey('actionbar.slot.threshold')));
    expect(find.byKey(const ValueKey('actionbar.slot.threshold')), findsOneWidget);
    // switch(端末全体)を切る → prefs に書かれ、このアカウントの行は触れなくなる。
    await show(find.byKey(ValueKey('actionbar.switch.$copyId')));
    await tester.tap(find.byKey(ValueKey('actionbar.switch.$copyId')));
    await tester.pumpAndSettle();
    expect(c.read(actionButtonPrefsProvider).switchOn(copyId), isFalse);
    await show(find.byKey(ValueKey('actionbar.slot.$copyId')));
    expect(tester.widget<RasqSwitchListTile>(find.byKey(ValueKey('actionbar.slot.$copyId'))).enabled, isFalse);
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

  test('既定の構成 (D-447): RASQ の全画面アクションバー(Swing)は空、SNS のバーは Misskey の「お気に入り」を初めは外す', () {
    expect(ActionBarConfigStore.defaultFor(rasqViewerConfigKey).hidden, containsAll(['rasq.reply', 'rasq.rebroad', 'rasq.queue']));
    expect(ActionBarConfigStore.defaultFor(ActionBarConfigStore.viewerKey('@a@m.example')).hidden, {'favorite'});
    expect(ActionBarConfigStore.defaultFor('@a@m.example').hidden, {'favorite'});
    expect(ActionBarConfigStore.defaultFor(rasqPostConfigKey).hidden, isEmpty);
    expect(ActionBarConfigStore.defaultFor('editor:image').hidden, isEmpty);
  });
}
