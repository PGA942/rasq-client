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

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p1', 'ふつうの投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        astellMediaPickerProvider.overrideWithValue(() async => XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'launch_photo.png', path: '/tmp/launch_photo.png', mimeType: 'image/png')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
  }

  testWidgets('vc home', (tester) async {
    await pump(tester);
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_home.png'));
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
    await tester.tap(find.byTooltip('共有枠から外す'));
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
    // stick(画面共有なし): 文字起こし → 上下スワイプで共有タイル。
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_stick.png'));
    await tester.drag(find.byKey(astellStickPagerKey), const Offset(0, -80));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_stick_share.png'));
    // メディアのタイルはタップで全画面になるので、文字起こしのページへ戻してから展開。
    await tester.drag(find.byKey(astellStickPagerKey), const Offset(0, 80));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(astellRoomCompactKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('画面共有'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_stick_screen.png'));
  });

  testWidgets('video room fow (D-144)', (tester) async {
    await pump(tester);
    // トレンド先頭 = Launch LIVE(投稿 + 動画の共有入り)。
    await tester.tap(find.text('見てみる').at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('参加'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_room_video.png'));
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    await tester.drag(find.byKey(astellStickPagerKey), const Offset(0, -80));
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
    await expectLater(find.byType(RasqApp), matchesGoldenFile('vc_create.png'));
  });
}
