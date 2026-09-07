import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/vc/astell_client.dart';
import 'package:rasq_client/features/vc/astell_fows.dart';
import 'package:rasq_client/features/vc/astell_media_viewer.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/features/vc/astell_tile.dart';
import 'package:rasq_client/features/vc/vc_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-139: AsTell タイル周辺 — VC ホームの 3 節 × タイル、参加 FOW、ルーム FOW
/// (共有 / 退出)、作成 FOW。データは Central 未接続時のモック。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  /// 下段の左端ボタン群(横 ListView、狭幅は 2 つまで)を [tooltip] のボタンまでスクロール (D-148)。
  Future<void> scrollActions(WidgetTester tester, String tooltip, {bool back = false}) => tester.scrollUntilVisible(
        find.byTooltip(tooltip),
        back ? -48 : 48,
        scrollable: find.descendant(of: find.byKey(astellFooterActionsKey), matching: find.byType(Scrollable)),
      );

  Future<ProviderContainer> pump(WidgetTester tester) async {
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
        // 「共有する」のファイル選択はダミー画像を返す。
        astellMediaPickerProvider.overrideWithValue(() async => XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'photo.png', path: '/tmp/photo.png', mimeType: 'image/png')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<void> openVc(WidgetTester tester) async {
    await tester.tap(find.byTooltip('AsTell'));
    await tester.pumpAndSettle();
  }

  group('アイコン&追加情報バンドル (D-140)', () {
    test('人数: 1000 未満は素の数、以上は k で小数点以下切り捨て、100k 以上は + なし・3 文字/行・2 行まで', () {
      expect(RasqAvatarBundle.formatCount(4), '+4');
      expect(RasqAvatarBundle.formatCount(999), '+999');
      expect(RasqAvatarBundle.formatCount(1000), '+1k');
      expect(RasqAvatarBundle.formatCount(2560), '+2k');
      expect(RasqAvatarBundle.formatCount(99_999), '+99k');
      expect(RasqAvatarBundle.formatCount(100_000), '100\nk');
      expect(RasqAvatarBundle.formatCount(123_456), '123\nk');
      expect(RasqAvatarBundle.formatCount(2_500_000), '2M');
      expect(RasqAvatarBundle.formatCount(12_000_000), '12M');
      expect(RasqAvatarBundle.formatCount(123_000_000), '123\nM');
    });

    testWidgets('層: 角丸ワイヤー(背面)→ 円形アイコン → LIVE(下辺中央)、人数は右端', (tester) async {
      const user = UserSummary(id: 'u', account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: 'h'), displayName: 'ダグラス');
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Center(child: RasqAvatarBundle(user: user, count: 2560, live: true, size: 40)))));
      expect(find.text('+2k'), findsOneWidget);
      expect(find.text('LIVE'), findsOneWidget);
      final bundle = tester.getRect(find.byType(RasqAvatarBundle));
      final avatar = tester.getRect(find.byType(RasqAvatar));
      final count = tester.getRect(find.text('+2k'));
      final live = tester.getRect(find.text('LIVE'));
      // アイコンは左端、人数はその右、LIVE はワイヤー(アイコン中心から右)の中央下。
      expect(avatar.left, closeTo(bundle.left, 3)); // 円形縁取り(size*0.06)の内側
      expect(count.left, greaterThan(avatar.right - 1));
      expect(count.center.dy, closeTo(avatar.center.dy, 1));
      expect(live.center.dy, greaterThan(count.bottom));
      // LIVE はアイコンを除いた右側(アイコン中心〜右端)の中央。
      expect(live.center.dx, closeTo((bundle.left + 20 + bundle.right) / 2, 4));
    });
  });

  group('モデル', () {
    test('Room / Peer / Share / Transcript の JSON(rasq-central API.md §3)を読める', () {
      final r = AstellRoom.fromJson({
        'id': 'x', 'ownerId': 'o', 'ownerHandle': 'douglas', 'ownerDisplayName': 'ダグラス', 'title': '打ち上げの打ち上げ',
        'description': '', 'genres': ['#打上会', '宇宙'], 'visibility': 'public', 'showSummary': true, 'autoGenre': false,
        'createdAt': '2026-09-06T10:00:00Z', 'closedAt': null, 'peerCount': 5, 'live': true,
      });
      expect(r.owner.account.handle, 'douglas');
      expect(r.owner.presence, UserPresence.none, reason: 'LIVE はバンドル側が描く(アバターの LIVE 帯と二重にしない)');
      expect(r.summaryText, 'デスクリプションが提供されていません。');
      expect(r.autoGenre, isFalse);
      expect(r.isOpen, isTrue);
      final p = AstellPeer.fromJson({'peerId': 'p', 'accountId': 'a', 'handle': 'h', 'displayName': 'H'});
      expect(p.user.account.instance, 'rasq');
      final s = AstellShare.fromJson({'id': 's', 'accountId': 'a', 'handle': 'h', 'displayName': 'H', 'kind': 'link', 'payload': {'url': 'https://x.test'}, 'createdAt': '2026-09-06T10:00:00Z'});
      expect(s.headline, 'https://x.test');
      final t = AstellTranscript.fromJson({'id': 't', 'accountId': 'a', 'handle': 'h', 'displayName': 'H', 'text': 'こんにちは', 'lang': 'ja', 'createdAt': '2026-09-06T10:00:00Z'});
      expect(t.text, 'こんにちは');
      expect(const NewAstellRoom(title: 'T', welcomeMessage: 'ようこそ').toJson()['welcomeMessage'], 'ようこそ');
      expect(const NewAstellRoom(title: 'T').toJson().containsKey('welcomeMessage'), isFalse);
    });

    test('ホストが動画配信中のダミー (D-145): Create Game に hostStream が入っている', () async {
      final client = MockAstellClient();
      final room = (await client.room('r-sublrony'))!;
      expect(room.hostStream, isNotNull);
      expect(room.hostStream!.kind, 'video');
      expect(room.hostStream!.title, contains('エディタ'));
      expect(room.live, isTrue);
      // JSON からも読める(サーバーの Room.hostStream)。
      final parsed = AstellRoom.fromJson({'id': 'x', 'ownerId': 'o', 'ownerHandle': 'h', 'ownerDisplayName': 'H', 'title': 't', 'createdAt': '2026-09-06T00:00:00Z',
        'hostStream': {'kind': 'screen', 'title': '画面', 'thumbnailUrl': 'https://x.test/t.png'}});
      expect(parsed.hostStream!.isScreen, isTrue);
      expect(parsed.thumbnailUrl.toString(), 'https://x.test/t.png');
    });

    test('動画つき FOW のダミー (D-144): Launch LIVE に投稿 + 動画の共有が入っている', () async {
      final client = MockAstellClient();
      final shares = await client.shares('r-spacequant');
      expect(shares.map((s) => s.kind), ['post', 'media']);
      expect(shares.last.isVideo, isTrue);
      expect(shares.last.kindLabel, '動画');
      expect(shares.last.thumbnailUrl, isNotNull);
      expect(shares.first.authorName, 'SpaceQuant Barbados');
      expect(shares.first.kindLabel, '投稿');
      final room = (await client.room('r-spacequant'))!;
      expect(room.thumbnailUrl, isNotNull);
    });

    test('セッション: welcome → peer-joined/left → share → transcript → closed', () async {
      final client = MockAstellClient();
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        astellClientProvider.overrideWithValue(client),
      ]);
      addTearDown(container.dispose);
      final room = MockAstellClient.seededRooms().first;
      final session = container.read(astellSessionProvider.notifier);
      // モックの接続で join。
      await session.join(room);
      await Future<void>.delayed(Duration.zero);
      var s = container.read(astellSessionProvider)!;
      expect(s.connected, isTrue);
      expect(s.myPeerId, 'me');
      expect(s.peers.length, 5);

      session.share('text', {'text': 'やあ'});
      await Future<void>.delayed(Duration.zero);
      s = container.read(astellSessionProvider)!;
      expect(s.shares.single.headline, 'やあ');
      expect((await client.shares(room.id)).length, 1, reason: 'モックもログに残す');

      await session.leave();
      expect(container.read(astellSessionProvider), isNull);
    });
  });

  testWidgets('VC ホーム: おすすめ / トレンド / フォロー中 にタイル(ホスト / タイトル / 要約 / ジャンル / LIVE / 見てみる)', (tester) async {
    await pump(tester);
    await openVc(tester);

    // 招待 (D-150): 招待されているルームの行 → 辞退で消える。
    expect(find.text('招待'), findsOneWidget);
    expect(find.text('サプライズ'), findsWidgets);
    expect(find.textContaining('よもぎもち から招待'), findsOneWidget);
    expect(find.text('おすすめ'), findsOneWidget);
    expect(find.text('トレンド'), findsOneWidget);
    expect(find.byType(AstellTile), findsWidgets);
    await tester.scrollUntilVisible(find.text('フォロー中'), 200, scrollable: find.descendant(of: find.byType(VcScreen), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('フォロー中'), findsOneWidget);
    await tester.drag(find.text('トレンド'), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('辞退'));
    await tester.pumpAndSettle();
    expect(find.text('招待'), findsNothing);
    // おすすめの先頭 = ダグラス「打ち上げの打ち上げ」(要約 + ジャンル)。
    expect(find.text('ダグラス'), findsWidgets);
    expect(find.text('打ち上げの打ち上げ'), findsWidgets);
    expect(find.textContaining('打ち上げ成功、おめでとう'), findsWidgets);
    expect(find.textContaining('#打上会'), findsWidgets);
    expect(find.text('見てみる'), findsWidgets);
    // 要約なしのタイルは空表示、LIVE のタイルにはバッジ。
    expect(find.text('デスクリプションが提供されていません。'), findsWidgets);
    expect(find.text('LIVE'), findsWidgets);
    await tester.scrollUntilVisible(find.text('フォロー中のユーザーの VC はありません'), 200, scrollable: find.descendant(of: find.byType(VcScreen), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.text('フォロー中のユーザーの VC はありません'), findsOneWidget);
    // タイルの「…」→ 報告 → 通報シート → 送信 (D-150)。
    await tester.drag(find.text('フォロー中'), const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('メニュー').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('報告'));
    await tester.pumpAndSettle();
    expect(find.text('通報'), findsOneWidget);
    await tester.tap(find.text('嫌がらせ・暴言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('通報する'));
    await tester.pumpAndSettle();
    expect(find.textContaining('通報しました'), findsOneWidget);
    final mock = ProviderScope.containerOf(tester.element(find.byType(VcScreen))).read(astellClientProvider) as MockAstellClient;
    expect(mock.reports.single['reason'], 'harassment');
  });

  testWidgets('見てみる → 参加 FOW(参加メンバー / ざっくり要約 / ジャンル / 参加)→ 参加 → ルーム FOW(共有 / 退出)', (tester) async {
    final container = await pump(tester);
    await openVc(tester);

    await tester.tap(find.text('見てみる').first);
    await tester.pumpAndSettle();
    expect(find.text('参加メンバー'), findsOneWidget);
    expect(find.text('ざっくり要約'), findsOneWidget);
    expect(find.byType(AstellMembersRow), findsOneWidget);
    expect(find.text('TiVard'), findsOneWidget);
    expect(find.text('他2人'), findsOneWidget); // 5 人中 3 人表示
    expect(find.byType(AstellGenreChips), findsOneWidget);
    expect(find.text('参加'), findsOneWidget);

    await tester.tap(find.text('参加'));
    await tester.pumpAndSettle();
    expect(find.byType(AstellRoomBody), findsOneWidget);
    expect(container.read(astellSessionProvider)?.connected, isTrue);
    expect(find.text('退出'), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
    expect(find.text('プレビューにざっくり要約を表示する'), findsOneWidget);

    // 自動再生 (D-147): TiVard が画面共有中なので、参加した時点で共有枠に出ている。
    // 下段 (D-148): 左端 = スピーカー / マイク / 画面共有 / 全画面(共有枠にある間) / プラグイン、
    // 右端 = 共有する + 設定。「…」→ ミュート → 「ミュート中」。
    expect(container.read(astellSessionProvider)!.viewingPeer?.displayName, 'TiVard');
    expect(find.textContaining('TiVard の画面'), findsOneWidget);
    expect(find.byKey(astellFooterActionsKey), findsOneWidget);
    expect(find.byTooltip('スピーカーミュート'), findsOneWidget);
    expect(find.byTooltip('マイクオン(音声は M5 後段)'), findsOneWidget);
    expect(find.byTooltip('画面共有'), findsNothing); // 狭幅(360px)は 2 つまで → 横スクロールの先
    await scrollActions(tester, '画面共有');
    await tester.pumpAndSettle();
    expect(find.byTooltip('画面共有'), findsOneWidget);
    await scrollActions(tester, 'プラグインアクション(未対応)');
    await tester.pumpAndSettle();
    expect(find.byTooltip('全画面'), findsWidgets); // 左端 + パネル右上
    expect(find.byTooltip('プラグインアクション(未対応)'), findsOneWidget);
    await scrollActions(tester, 'スピーカーミュート', back: true);
    await tester.pumpAndSettle();
    expect(find.byTooltip('設定'), findsOneWidget);
    await tester.tap(find.byTooltip('スピーカーミュート'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.speakerMuted, isTrue);
    await tester.tap(find.byTooltip('スピーカーミュート解除'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('共有枠の操作'));
    await tester.pumpAndSettle();
    expect(find.text('ピン留めを外す'), findsOneWidget);
    expect(find.text('通報'), findsOneWidget);
    await tester.tap(find.text('ミュート'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.isMuted('p2'), isTrue);
    expect(find.text('ミュート中'), findsOneWidget);
    await tester.tap(find.byTooltip('共有枠の操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ミュート解除'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.isMuted('p2'), isFalse);
    // stick + 共有枠にピアの画面: 左端が映像に置き換わり、タップで全画面。
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    expect(find.byKey(astellStickScreenKey), findsOneWidget);
    expect(find.byKey(astellFooterActionsKey), findsNothing);
    expect(find.byTooltip('マイクオン(音声は M5 後段)'), findsNothing);
    expect(find.byTooltip('字幕オフ'), findsOneWidget);
    expect(find.byTooltip('退出'), findsOneWidget);
    expect(find.byTooltip('設定'), findsNothing);
    await tester.tap(find.byKey(astellStickScreenKey));
    await tester.pumpAndSettle();
    expect(find.byType(AstellMediaViewer), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(astellRoomCompactKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('共有枠の操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ピン留めを外す'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.viewingPeer, isNull);
    expect(find.byTooltip('全画面'), findsNothing);

    // タブ (D-141): ホーム / チャット / 目次 / ルーム。ヘッダーは本体側 (D-143)。
    Finder inRoom(String t) => find.descendant(of: find.byType(AstellRoomBody), matching: find.text(t));
    for (final t in ['ホーム', 'チャット', '目次', 'ルーム']) {
      expect(inRoom(t), findsOneWidget);
    }
    expect(find.byKey(astellRoomHeaderKey), findsOneWidget);

    // チャット入力(字幕オン時): 入力開始で下書き枠 + 「送信完了する」、全消去で消える、送信で共有。
    await tester.tap(inRoom('チャット'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('共有する'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'input..'), 'こん');
    await tester.pumpAndSettle();
    expect(find.text('下書き'), findsOneWidget);
    expect(find.byTooltip('送信完了する'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'input..'), '');
    await tester.pumpAndSettle();
    expect(find.text('下書き'), findsNothing);
    await tester.enterText(find.widgetWithText(TextField, 'input..'), 'こんばんは');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('送信完了する'));
    await tester.pumpAndSettle();
    expect(find.textContaining('こんばんは'), findsNWidgets(2)); // チャット + 下段のティッカー(共有欄には出ない)
    expect(find.text('共有'), findsOneWidget); // 共有欄は空
    // チャットの 📌 で共有欄へ (D-146)。「こんばんは」の行のピンを押す(先頭行は文字起こし)。
    final row = find.ancestor(of: find.textContaining('あなた> こんばんは'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('共有欄にピン留め')));
    await tester.pumpAndSettle();
    expect(find.text('共有 (1)'), findsOneWidget);
    expect(find.descendant(of: find.byType(AstellRoomBody), matching: find.text('こんばんは')), findsOneWidget); // 共有欄のカード(素の Text)
    expect(find.textContaining('📌'), findsOneWidget);

    // 字幕オフ → 入力欄が「共有する」(ファイル選択)に差し替わる → media 共有。
    await tester.tap(find.byTooltip('字幕オフ'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'input..'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, '共有する'));
    await tester.pumpAndSettle();
    expect(find.text('photo.png'), findsWidgets);
    expect(find.text('共有 (2)'), findsOneWidget); // 画像は自動表示(既定オン)
    expect(find.textContaining('自動表示'), findsWidgets);
    // アップロード (D-145): 共有の payload に Central の URL と assetId が載る。
    final media = container.read(astellSessionProvider)!.shares.lastWhere((x) => x.kind == 'media');
    expect(media.payload['assetId'], startsWith('mock-asset-'));
    expect(media.url, isNotNull);
    expect(media.thumbnailUrl, isNotNull); // image/png
    // メディアのタップ → 全画面ビューワー。
    await tester.tap(find.text('photo.png').first);
    await tester.pumpAndSettle();
    expect(find.byType(AstellMediaViewer), findsOneWidget);
    expect(find.byTooltip('保存'), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.byType(AstellMediaViewer), findsNothing);
    // ↓ で全件、… → 削除。
    await tester.tap(find.byTooltip('共有をすべて表示'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('共有の操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(find.text('共有 (1)'), findsOneWidget);
    await tester.tap(find.byTooltip('字幕オン'));
    await tester.pumpAndSettle();

    // FOW の外側をタップ → stick(共有枠なし): ヘッダーと入力欄が消え、左端は 2 つまで(横 ListView)。
    // 字幕オン: 中央は文字起こし。字幕オフ: 画面共有以外のピン留めのタイル(上下スワイプ) (D-148)。
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    expect(find.byKey(astellRoomCompactKey), findsOneWidget);
    expect(find.byKey(astellRoomHeaderKey), findsNothing);
    expect(find.widgetWithText(TextField, 'input..'), findsNothing);
    expect(find.byTooltip('スピーカーミュート'), findsOneWidget);
    expect(find.byTooltip('マイクオン(音声は M5 後段)'), findsOneWidget);
    expect(find.byTooltip('画面共有'), findsNothing); // 3 つ目は横スクロールの先
    expect(find.byTooltip('退出'), findsOneWidget);
    expect(find.byTooltip('共有する'), findsNothing);
    expect(find.byKey(astellStickPagerKey), findsNothing); // 字幕オン = 文字起こし
    await tester.tap(find.byKey(astellRoomCompactKey));
    await tester.pumpAndSettle();
    expect(find.byKey(astellRoomHeaderKey), findsOneWidget);
    await tester.tap(find.byTooltip('字幕オフ'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    expect(find.byKey(astellStickPagerKey), findsOneWidget);
    await tester.drag(find.byKey(astellStickPagerKey), const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(find.text('こんばんは'), findsOneWidget); // ピン留めしたテキストのタイル
    expect(find.text('テキスト'), findsOneWidget); // 種別ピル
    // タップで展開、字幕を戻す。
    await tester.tap(find.byKey(astellRoomCompactKey));
    await tester.pumpAndSettle();
    expect(find.byKey(astellRoomHeaderKey), findsOneWidget);
    await tester.tap(find.byTooltip('字幕オン'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'input..'), findsOneWidget);

    // 画面共有のデモ (D-146): TiVard のタイルにマイク表示の左の画面共有枠 → タップで共有枠に表示、
    // 左端に 全画面 が増える (D-148)。もう一度タップで外す。
    await tester.tap(inRoom('ホーム'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('画面共有を表示'), findsOneWidget);
    await tester.tap(find.byTooltip('画面共有を表示'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.viewingPeer?.displayName, 'TiVard');
    expect(find.textContaining('TiVard の画面'), findsOneWidget);
    expect(find.byTooltip('マイクオン(音声は M5 後段)'), findsOneWidget);
    expect(find.byTooltip('全画面'), findsWidgets);
    await tester.tap(find.byTooltip('共有枠に表示中'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.viewingPeer, isNull);
    expect(find.byTooltip('全画面'), findsNothing);

    // 歯車 → 設定: 自動表示の種類と読み上げ音声(CosyVoice2-0.5B)。
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    expect(find.text('VC の設定'), findsOneWidget);
    // 自動再生の設定 (D-147)。
    expect(find.widgetWithText(RasqSwitchListTile, '画面共有が始まったら共有枠に出す'), findsOneWidget);
    await tester.tap(find.widgetWithText(RasqSwitchListTile, '画面共有が始まったら共有枠に出す'));
    await tester.pumpAndSettle();
    expect(container.read(astellAutoPlayProvider), isFalse);
    // 読み上げの段はシートの下(遅延 ListView)なのでスクロールして見る。
    await tester.scrollUntilVisible(find.text('女性 1(日本語)'), 80, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    expect(find.textContaining('CosyVoice2-0.5B'), findsOneWidget);
    expect(find.text('女性 1(日本語)'), findsOneWidget);
    await tester.tap(find.widgetWithText(RasqSwitchListTile, 'テキスト'));
    await tester.pumpAndSettle();
    expect(container.read(astellAutoShareProvider)['text'], isTrue);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    // 自分の画面共有モード: 左端の 画面共有 が塗りつぶしに、展開の上部に印。
    await scrollActions(tester, '画面共有');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('画面共有'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.screenShareOn, isTrue);
    expect(find.textContaining('画面共有モード'), findsOneWidget);
    await tester.tap(find.byTooltip('画面共有オフ'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.screenShareOn, isFalse);

    // ルーム: 参加メンバー全員。
    await tester.tap(inRoom('ルーム'));
    await tester.pumpAndSettle();
    expect(find.text('参加メンバー(5)'), findsOneWidget);
    // メンバー行 (D-147): @handle + 画面共有枠 + スピーカー + 「…」。
    expect(find.text('@tivard'), findsOneWidget);
    expect(find.byTooltip('画面共有を表示'), findsOneWidget); // TiVard の枠
    expect(find.byTooltip('ミュート'), findsWidgets);
    final tivardRow = find.ancestor(of: find.text('@tivard'), matching: find.byType(Row)).last;
    await tester.tap(find.descendant(of: tivardRow, matching: find.byTooltip('ミュート')));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.isMuted('p2'), isTrue);
    expect(find.descendant(of: tivardRow, matching: find.byTooltip('ミュート解除')), findsOneWidget);
    await tester.tap(find.descendant(of: tivardRow, matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    expect(find.text('共有枠に表示'), findsOneWidget);
    expect(find.text('ミュート解除'), findsOneWidget);
    expect(find.text('ブロック'), findsOneWidget);
    // モデレーション (D-149): あなたはこのルームのモデレーター → 全員向けミュート / キック はある、
    // 付与 / BAN(オーナーだけ)はない。
    expect(container.read(astellSessionProvider)!.isModerator, isTrue);
    expect(container.read(astellSessionProvider)!.isOwner, isFalse);
    expect(find.text('全員向けにミュート'), findsOneWidget);
    expect(find.text('キック'), findsOneWidget);
    expect(find.text('モデレーターにする'), findsNothing);
    expect(find.text('BAN'), findsNothing);
    await tester.tap(find.text('共有枠に表示'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.viewingPeer?.displayName, 'TiVard');
    // 共有枠パネルが上に出て行が下へ押されるので、見える所まで寄せてから外す。
    await tester.ensureVisible(find.descendant(of: tivardRow, matching: find.byTooltip('共有枠に表示中')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: tivardRow, matching: find.byTooltip('共有枠に表示中')));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.viewingPeer, isNull);
    // 全員向けミュート → peer-state(mutedByMod)で行に赤いピル。キック → 参加者から消える。
    await tester.tap(find.descendant(of: tivardRow, matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('全員向けにミュート'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.peers.firstWhere((p) => p.peerId == 'p2').mutedByMod, isTrue);
    expect(find.text('強制ミュート'), findsOneWidget);
    await tester.drag(find.text('@tivard'), const Offset(0, 300)); // 先頭(ダグラス)まで戻す(遅延 ListView)
    await tester.pumpAndSettle();
    expect(find.text('ホスト'), findsOneWidget); // ダグラスの役割ピル
    await tester.scrollUntilVisible(find.text('@a4'), 80, scrollable: find.ancestor(of: find.text('@tivard'), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    final guestRow = find.ancestor(of: find.text('@a4'), matching: find.byType(Row)).last;
    await tester.tap(find.descendant(of: guestRow, matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キック'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.peers.map((p) => p.peerId), isNot(contains('p4')));
    expect(container.read(astellSessionProvider)!.peers, hasLength(4));

    // チャット行の「…」(D-147): ピン留め / フォロー / ミュート / ブロック / 通報。
    await tester.tap(inRoom('チャット'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('チャットの操作').first); // 先頭 = ダグラスの文字起こし
    await tester.pumpAndSettle();
    expect(find.text('共有欄にピン留め'), findsWidgets);
    expect(find.text('フォロー'), findsOneWidget);
    await tester.tap(find.text('ミュート'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.isMuted('p1'), isTrue);
    // ブロック (D-150): ダグラスの発言が隠れ、解除で戻る。
    await tester.tap(find.byTooltip('チャットの操作').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ブロック'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ブロック中のユーザーの発言'), findsOneWidget);
    expect(find.textContaining('いい感じに行ったねー'), findsNothing);
    await tester.tap(find.byTooltip('チャットの操作').first); // 先頭は山ハヤ(ダグラスは隠れている)
    await tester.pumpAndSettle();
    expect(find.text('ブロック'), findsOneWidget); // 山ハヤは未ブロック
    await tester.tap(find.text('通報'));
    await tester.pumpAndSettle();
    expect(find.text('通報する'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    await tester.tap(inRoom('ルーム'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('@tivard'), const Offset(0, 300));
    await tester.pumpAndSettle();
    final douglasRow = find.ancestor(of: find.text('@douglas'), matching: find.byType(Row)).last;
    await tester.tap(find.descendant(of: douglasRow, matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    expect(find.text('ブロック解除'), findsOneWidget);
    expect(find.text('発信傾向を見る(ダミー判定)'), findsOneWidget);
    await tester.tap(find.text('ブロック解除'));
    await tester.pumpAndSettle();
    expect(container.read(astellBlocksProvider).value, isEmpty);

    // 退出でセッションが消える。
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider), isNull);
    expect(find.byType(AstellRoomBody), findsNothing);
  });

  testWidgets('ホスト配信中のルーム: 展開に配信パネル、stick の先頭に配信の印、タップで全画面', (tester) async {
    await pump(tester);
    await openVc(tester);
    // Create Game(ホストが動画配信中)へ直接参加 → ホーム先頭の「参加中」からルーム FOW を開く。
    final room = (await MockAstellClient().room('r-sublrony'))!;
    await ProviderScope.containerOf(tester.element(find.byType(RasqApp))).read(astellSessionProvider.notifier).join(room);
    await tester.pumpAndSettle();
    await tester.tap(find.text('参加中: Create Game'));
    await tester.pumpAndSettle();
    expect(find.textContaining('配信: エディタ作業'), findsOneWidget);
    await tester.tap(find.textContaining('配信: エディタ作業'));
    await tester.pumpAndSettle();
    expect(find.byType(AstellMediaViewer), findsOneWidget);
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    // stick の中央は字幕オフの時にピン留め/配信のタイル (D-148)。
    await tester.tap(find.byTooltip('字幕オフ'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(180, 60));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sublrony が配信中'), findsOneWidget);
    await tester.tap(find.byKey(astellRoomCompactKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
  });

  testWidgets('+ → 作成 FOW(タイトル / ウェルカム / トグル)→ 作成 → ルーム FOW、ホームに載る', (tester) async {
    final container = await pump(tester);
    await openVc(tester);

    await tester.tap(find.byTooltip('VC を作成'));
    await tester.pumpAndSettle();
    expect(find.text('フォロワーを招待'), findsOneWidget);
    expect(find.text('参加時にウェルカムメッセージを表示する'), findsOneWidget);
    // タイトル空 → 弾く。
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();
    expect(find.text('タイトルを入力してください'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'タイトル'), '夜の雑談');
    // フォロワーを招待 (D-150): チップで選ぶ + 検索して追加。
    await tester.tap(find.byTooltip('ダグラス を招待'));
    await tester.pumpAndSettle();
    expect(find.text('フォロワーを招待(1)'), findsOneWidget);
    // 「検索して追加」は横並びの右端(横スクロールの先)。
    await tester.scrollUntilVisible(find.byTooltip('検索して追加'), 80, scrollable: find.ancestor(of: find.byTooltip('ダグラス の招待をやめる'), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('検索して追加'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '@handle(RASQ アカウント)'), '@nobody');
    await tester.tap(find.text('招待に追加'));
    await tester.pumpAndSettle();
    expect(find.textContaining('見つかりませんでした'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '@handle(RASQ アカウント)'), '@spacequant');
    await tester.tap(find.text('招待に追加'));
    await tester.pumpAndSettle();
    expect(find.text('フォロワーを招待(2)'), findsOneWidget);
    await tester.tap(find.text('参加時にウェルカムメッセージを表示する'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'ウェルカムメッセージを設定..'), 'ようこそ');
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();

    final s = container.read(astellSessionProvider)!;
    expect(s.room.title, '夜の雑談');
    expect(s.room.welcomeMessage, 'ようこそ');
    expect(find.byType(AstellRoomBody), findsOneWidget);
    expect(s.isOwner, isTrue);
    expect((container.read(astellClientProvider) as MockAstellClient).invitesOf(s.room.id), {'douglas', 'spacequant'});

    // オーナーのモデレーション (D-149): ダグラスをモデレーターに → 役割ピル / 設定の一覧に載る。
    Finder inRoom(String t) => find.descendant(of: find.byType(AstellRoomBody), matching: find.text(t));
    await tester.tap(inRoom('ルーム'));
    await tester.pumpAndSettle();
    final row = find.ancestor(of: find.text('@douglas'), matching: find.byType(Row)).last;
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    expect(find.text('モデレーターにする'), findsOneWidget);
    expect(find.text('BAN'), findsOneWidget);
    await tester.tap(find.text('モデレーターにする'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.room.moderators, ['douglas']);
    expect(find.text('モデレーター'), findsOneWidget);
    // 設定: 参加できる人 / 共有できる人 / モデレーター / BAN。
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    expect(find.text('モデレーション(オーナー)'), findsOneWidget);
    await tester.tap(find.text('フォロワーだけ'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.room.joinPolicy, 'followers');
    Finder sheet() => find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('モデレーターだけ'), 80, scrollable: sheet());
    await tester.pumpAndSettle();
    await tester.tap(find.text('モデレーターだけ'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.room.sharePolicy, 'moderators');
    await tester.scrollUntilVisible(find.text('モデレーター(1)— 付与はメンバー行の「…」から'), 80, scrollable: sheet());
    await tester.pumpAndSettle();
    expect(find.text('モデレーター(1)— 付与はメンバー行の「…」から'), findsOneWidget);
    await tester.scrollUntilVisible(find.byTooltip('モデレーターを外す'), 80, scrollable: sheet());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('モデレーターを外す'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.room.moderators, isEmpty);
    // 発信傾向フィルター(ダミー判定)。
    await tester.scrollUntilVisible(find.widgetWithText(RasqSwitchListTile, '発信傾向で入室を絞る(ダミー判定)'), 80, scrollable: sheet());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RasqSwitchListTile, '発信傾向で入室を絞る(ダミー判定)'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.room.tendencyFilter, isTrue);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    // BAN → 参加者から消え、設定の BAN 一覧に載る → 解除。
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('メンバーの操作')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BAN'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.peers, isEmpty);
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('BAN(1)— メンバー行の「…」から'), 80, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    expect(find.text('@douglas'), findsOneWidget);
    await tester.tap(find.byTooltip('BAN を解除'));
    await tester.pumpAndSettle();
    expect(find.text('BAN(0)— メンバー行の「…」から'), findsOneWidget);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    // ホームのおすすめ先頭に自分のルーム。
    expect(find.text('夜の雑談'), findsWidgets);
  });
}
