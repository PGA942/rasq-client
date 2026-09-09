// 描画確認ハーネス (D-140): 実フォントで VC ホーム / FOW を PNG に出す。
// `flutter test` の既定対象(test/)には入れない。実行:
//   RASQ_PREVIEW_FONT=/path/to/NotoSansJP.ttf flutter test tool/preview/vc_preview_test.dart --update-goldens
// → tool/preview/*.png(git には入れない)。フォント未指定ならスキップ。
// テストの既定フォント(Ahem)では日本語が □ になり、実機の崩れが見えないため。
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/vc/astell_fows.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/features/vc/astell_client.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_tile.dart';
import 'package:rasq_client/notify/local_notifier.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../test/support/fakes.dart';

void main() {
  final fontPath = Platform.environment['RASQ_PREVIEW_FONT'];
  if (fontPath == null || !File(fontPath).existsSync()) {
    test('preview harness needs RASQ_PREVIEW_FONT', () {}, skip: 'RASQ_PREVIEW_FONT を日本語フォント(.ttf)へ向けると PNG を出す');
    return;
  }

  setUpAll(() async {
    final bytes = File(fontPath).readAsBytesSync();
    // テストの既定ファミリー(Roboto)へ実フォントを差し込む → 全テキストに効く。
    for (final family in ['Roboto', 'NotoSansJP', '.SF UI Text', '.SF UI Display']) {
      final loader = FontLoader(family)..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  });

  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  Future<void> pump(WidgetTester tester, {List<Post>? posts, bool vc = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => posts ?? [post('p1', 'ふつうの投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        localNotifierProvider.overrideWithValue(MemoryLocalNotifier()), // 端末通知は台帳だけ
        astellMediaPickerProvider.overrideWithValue(() async => XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'launch_photo.png', path: '/tmp/launch_photo.png', mimeType: 'image/png')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    if (!vc) return;
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
  }

  testWidgets('create fow schedule + genres (D-159), tl astell tile + bookmarks (D-160)', (tester) async {
    await pump(tester, posts: [post('p1', '今夜やります!\nrasq://astell/r-launch'), post('p2', '来週の反省会、集まれる人は通知登録しておいて\nrasq://astell/r-planned')], vc: false);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('tl_astell_tile.png'));
    // 予約ルームのタイルの通知を登録 + 開催中のタイルをブックマーク。
    await tester.tap(find.byKey(const ValueKey('astell.tile.bookmark')).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('astell.post.tile.r-planned')), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('astell.tile.remind')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('tl_astell_tile_scheduled.png'));
    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ブックマーク'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('bookmarks_astell.png'));
    await tester.tap(find.byTooltip('戻る'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('notifications_astell_reminder.png'));
    // 作成 FOW: ジャンル選定 + 開催予約。
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_home_upcoming.png'));
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars(); // スナックバーが FAB に被る
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('VC を作成'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'タイトル'), '打ち上げ反省会 その2');
    final form = find.descendant(of: find.byKey(astellCreateFormKey), matching: find.byType(Scrollable)).first; // 外側(縦)。内側に招待の横 ListView がある
    await tester.scrollUntilVisible(find.text('ジャンルを自動選択する'), 200, scrollable: form);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ジャンルを自動選択する'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('astell.create.genre.input')), 200, scrollable: form);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('astell.create.genre.input')), '写真');
    await tester.tap(find.byTooltip('ジャンルを追加'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('開催を予約する'), 200, scrollable: form);
    await tester.pumpAndSettle();
    await tester.tap(find.text('開催を予約する'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('astell.create.date')), 200, scrollable: form);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_create_schedule.png'));
  });

  testWidgets('post share in room chat (D-166)', (tester) async {
    await pump(tester, posts: [post('p1', '打ち上げ成功おめでとう! 次は反省会で写真を見ましょう #打上会')], vc: false);
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await container.read(astellSessionProvider.notifier).join((await container.read(astellClientProvider).room('r-launch'))!);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('メニュー').first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('post_menu_astell.png'));
    await tester.tap(find.text('AsTell で共有'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('参加中: '));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AstellRoomBody), matching: find.text('チャット')));
    await tester.pumpAndSettle();
    final chat = find.ancestor(of: find.textContaining('ダグラス> いい感じに行ったねー'), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.textContaining('あなた> 打ち上げ成功'), 80, scrollable: chat);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_post_share.png'));
  });

  testWidgets('vc home', (tester) async {
    await pump(tester);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_home.png'));
  });

  testWidgets('owner tile menu (D-164) + home header strip (D-163)', (tester) async {
    await pump(tester, posts: [post('p1', '今夜やります!\nrasq://astell/r-launch')], vc: false);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('home_header_astell.png'));
    final container = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    await container.read(astellClientProvider).createRoom(const NewAstellRoom(title: '自分の部屋', description: '自分がホストのルーム。… から終了できる。', genres: ['雑談']));
    container.invalidate(astellHomeProvider);
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
    final tile = find.ancestor(of: find.text('自分の部屋').first, matching: find.byType(AstellTile)).first;
    await tester.tap(find.descendant(of: tile, matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_tile_owner_menu.png'));
  });

  testWidgets('preview + room fow', (tester) async {
    await pump(tester);
    await tester.tap(find.text('見てみる').first);
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_preview.png'));
    await tester.tap(find.text('参加'));
    await tester.pumpAndSettle();
    // 自動再生 (D-147): TiVard の画面共有が参加時点で共有枠に出る(下段がピン解除 / 全画面 / ミュートに)。
    // 「…」→ ミュート で「ミュート中」。
    await tester.tap(find.byTooltip('共有枠の操作'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_viewing_menu.png'));
    await tester.tap(find.text('ミュート'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_viewing.png'));
    // stick + 共有枠にピアの画面 (D-148): 左端が映像に。
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_stick_viewing.png'));
    await tester.tap(find.byKey(astellRoomCompactKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('共有枠の操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ピン留めを外す'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'input..'), 'こんばんは');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('送信完了する'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('共有する'));
    await tester.pumpAndSettle();
    // ルームタブ (D-147): メンバー行(画面共有枠 + スピーカー + …)。
    await tester.tap(find.descendant(of: find.byType(AstellRoomBody), matching: find.text('ルーム')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_members.png'));
    // モデレーターのメニュー (D-149): TiVard の「…」。
    final tivardRow = find.ancestor(of: find.text('@tivard'), matching: find.byType(Row)).last;
    await tester.tap(find.descendant(of: tivardRow, matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_members_menu.png'));
    await tester.tap(find.text('全員向けにミュート'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_members_muted.png'));
    // 通報シート (D-150)。
    await tester.tap(find.descendant(of: tivardRow, matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通報'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_report.png'));
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AstellRoomBody), matching: find.text('チャット')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('共有欄にピン留め').first);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AstellRoomBody), matching: find.text('ホーム')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room.png'));
    await tester.tap(find.descendant(of: find.byType(AstellRoomBody), matching: find.text('チャット')));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_chat.png'));
    // stick(共有枠なし、字幕オン): 左端 2 つ + 文字起こし。字幕オフ: ピン留めのタイル(上下スワイプ)。
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_stick.png'));
    await tester.tap(find.byKey(astellRoomCompactKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('字幕オフ'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_captions_off.png'));
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_stick_share.png'));
  });

  testWidgets('video room fow (D-144)', (tester) async {
    await pump(tester);
    // トレンド先頭 = Launch LIVE(投稿 + 動画の共有入り)。
    await tester.tap(find.text('見てみる').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('参加'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_video.png'));
    await tester.tap(find.byTooltip('字幕オフ'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(astellStickPagerKey), const Offset(0, -80));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_video_stick.png'));
  });

  testWidgets('avatar bundle gallery', (tester) async {
    tester.view.physicalSize = const Size(900, 600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const user = UserSummary(id: 'u', account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: 'douglas'), displayName: 'ダグラス');
    await tester.pumpWidget(MaterialApp(
      theme: RasqTheme.light(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 16, runSpacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final (n, live) in [(4, false), (2560, true), (99999, false), (123456, true), (2500000, false), (123000000, true)])
              RasqAvatarBundle(user: user, count: n, live: live, size: 40),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await expectLater(find.byType(Scaffold), matchesGoldenFile('bundle_gallery.png'));
  });

  testWidgets('host stream room (D-145)', (tester) async {
    await pump(tester);
    // Create Game(ホストが動画配信中)へ直接参加 → ホーム先頭の「参加中」からルーム FOW を開く。
    final room = (await MockAstellClient().room('r-sublrony'))!;
    await ProviderScope.containerOf(tester.element(find.byType(RasqApp))).read(astellSessionProvider.notifier).join(room);
    await tester.pumpAndSettle();
    await tester.tap(find.text('参加中: Create Game'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_hoststream.png'));
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_hoststream_stick.png'));
  });

  testWidgets('create fow', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('VC を作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ダグラス を招待'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_create.png'));
    // 作成 → オーナーの設定シート(モデレーション、D-149)。
    await tester.enterText(find.widgetWithText(TextField, 'タイトル'), '夜の雑談');
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('モデレーション(オーナー)'), 80, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_settings_owner.png'));
  });
}
