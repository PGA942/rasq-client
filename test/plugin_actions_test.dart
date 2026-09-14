import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
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

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => [post('p1', 'こんにちは')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry), slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes))],
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

  testWidgets('アクションバーの編集 (D-208): 大きいタイル + (…) メニュー(詳細 / アクションリスト化 / 削除)、隙間に落として並び替え、タイルの上に落としてバンドル、バンドル FOW', (tester) async {
    fakes['act'] = () => FakeSlotRuntime(
          manifest: {
            'id': 't.act', 'name': '投稿ボタン', 'version': '0.1.0', 'kind': 'action', 'slots': ['post.action'], 'permissions': ['fow.widget'],
            'actions': [{'id': 'copy', 'label': '本文をコピー', 'icon': 'content_copy', 'tags': ['Copy']}],
          },
          handler: (self, fn, args) => {'result': {'done': true}},
        );
    final c = await pump(tester);
    await c.read(slotPluginsProvider.notifier).register('fake:act', bytes: Uint8List.fromList('act'.codeUnits));
    await tester.pumpAndSettle();
    final copyId = pluginActionId('t.act', 'copy');
    final accountKey = fakeSession().account.key;
    // 投稿の … → アクションバーを編集。
    await tester.tap(find.byTooltip('メニュー').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('アクションバーを編集'));
    await tester.pumpAndSettle();
    expect(find.text('アクションバーの編集'), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.tile.reply')), findsOneWidget);
    expect(find.byKey(ValueKey('actionbar.slot.$copyId')), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.slot.threshold')), findsOneWidget);
    expect(find.text('非表示'), findsNothing);
    // (+) → 検索 FOW: 名前で絞って選ぶ → 有効。
    await tester.tap(find.byKey(const ValueKey('actionbar.plugins.open')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(actionBarPluginSearchKey), 'コピー');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('actionbar.plugin.$copyId')));
    await tester.pumpAndSettle();
    expect(find.byKey(actionBarPluginSearchKey), findsNothing);
    // 返信の (…) → 詳細 / アクションリスト化(削除は SNS のボタンには無い)。
    await tester.tap(find.byKey(const ValueKey('actionbar.tile.menu.reply')));
    await tester.pumpAndSettle();
    expect(find.text('アクションの詳細'), findsOneWidget);
    expect(find.text('削除'), findsNothing);
    await tester.tap(find.text('アクションリスト化'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('actionbar.bundle.name')), '返信まわり');
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();
    var cfg = c.read(actionBarConfigProvider(accountKey));
    expect(cfg.lists.length, 1);
    expect(cfg.lists.single.memberIds, ['reply']);
    expect(cfg.order.first, ActionBarConfig.listKey(cfg.lists.single.id));
    final listKey = ActionBarConfig.listKey(cfg.lists.single.id);
    // リノートのタイルをバンドルの上に落とす → バンドルに入り、編集 FOW が開く。
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
    expect(find.text('バンドルを編集'), findsOneWidget);
    expect(find.byKey(const ValueKey('actionbar.bundle.member.renote')), findsOneWidget);
    // メンバーを外す → バーに戻る。
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('actionbar.bundle.member.renote')), matching: find.byTooltip('バンドルから外す')));
    await tester.pumpAndSettle();
    cfg = c.read(actionBarConfigProvider(accountKey));
    expect(cfg.lists.single.memberIds, ['reply']);
    expect(cfg.order, contains('renote'));
    await tester.tap(find.text('閉じる').last);
    await tester.pumpAndSettle();
    // 隙間に落として並び替え: 末尾の隙間へリノート。
    await tester.ensureVisible(find.byKey(const ValueKey('actionbar.tile.renote')));
    await tester.pumpAndSettle();
    final entriesBefore = c.read(actionBarConfigProvider(accountKey)).order;
    g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('actionbar.tile.renote'))));
    await tester.pump(const Duration(milliseconds: 400));
    final lastGap = find.byKey(ValueKey('actionbar.gap.${entriesBefore.length}'));
    await g.moveTo(tester.getCenter(lastGap));
    await tester.pump(const Duration(milliseconds: 50));
    await g.up();
    await tester.pumpAndSettle();
    expect(c.read(actionBarConfigProvider(accountKey)).order.last, 'renote');
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
}
