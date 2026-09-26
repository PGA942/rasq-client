import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart';
import 'package:rasq_client/features/vc/astell_bookmarks.dart';
import 'package:rasq_client/features/vc/astell_client.dart';
import 'package:rasq_client/features/vc/astell_links.dart';
import 'package:rasq_client/notify/local_notifier.dart';
import 'package:rasq_client/features/vc/astell_fows.dart';
import 'package:rasq_client/features/vc/astell_media_viewer.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_post_share.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/features/vc/hold_music.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/features/vc/astell_tile.dart';
import 'package:rasq_client/features/vc/vc_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-139: AsTell タイル周辺 — VC ホームの 3 節 × タイル、参加 FOW、ルーム FOW
/// (共有 / 退出)、作成 FOW。データは Central 未接続時のモック。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body, {String visibility = 'public'}) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body, visibility: visibility);

  /// 下段に入りきらないボタン(歯車のメニューの先頭、D-324)の [tooltip] を押す。押すとメニューは閉じる。
  Future<void> tapOverflow(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(astellOverflowKey), matching: find.byTooltip(tooltip)));
    await tester.pumpAndSettle();
  }

  final notifier = MemoryLocalNotifier();

  Future<ProviderContainer> pump(WidgetTester tester, {List<Post>? posts}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    notifier.scheduled.clear();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => posts ?? [post('p1', 'ふつうの投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        localNotifierProvider.overrideWithValue(notifier),
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

    test('保留音 (D-327): 開催予約の開始待ち / 全員が静か(マイク・画面共有・配信なし、チャット 1 分以上なし)で鳴る、話す・チャット・設定オフで止まる、退出で止まる', () async {
      final client = MockAstellClient();
      final storage = MemorySessionStorage({});
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        astellClientProvider.overrideWithValue(client),
        astellHoldMusicTickProvider.overrideWithValue(null),
      ]);
      addTearDown(container.dispose);
      final music = container.read(holdMusicProvider) as MemoryHoldMusic;
      final session = container.read(astellSessionProvider.notifier);
      final room = MockAstellClient.seededRooms().first;
      final soon = DateTime.now().add(const Duration(hours: 1));

      // 開催予約の待ち: 接続した時点で鳴る(参加者は誰もマイクを立てていなくても関係なく)。開催が始まる(scheduledAt が消える)と止まる。
      await session.join(room.copyWith(scheduledAt: soon));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(astellSessionProvider)!.connected, isTrue);
      expect(music.playing, isTrue);
      expect(container.read(astellSessionProvider)!.notice, astellHoldWaitingNotice);
      client.emit(room.id, {'type': 'room', 'room': room.toJson()});
      await Future<void>.delayed(Duration.zero);
      expect(music.playing, isFalse, reason: '開催が始まった(ほかの人がマイクを立てている)');
      // 待ちが明けた瞬間にチャイム (D-331)。案内は「開催が始まりました」(次の見直しで消える)。
      expect(music.alarms, 1);
      expect(container.read(astellSessionProvider)!.notice, astellStartedNotice);
      await session.toggleMic();
      await session.toggleMic();
      expect(container.read(astellSessionProvider)!.notice, isNull);
      expect(music.alarms, 1, reason: 'チャイムは 1 回だけ');

      // 全員が静か: 1 対 1 にして、相手がマイクを下ろし、チャットが 1 分以上流れていない。
      for (final id in ['p1', 'p3', 'p4', 'p5']) {
        client.emit(room.id, {'type': 'peer-left', 'peerId': id});
      }
      client.emit(room.id, {'type': 'peer-state', 'peer': {'peerId': 'p2', 'accountId': 'tivard', 'handle': 'tivard', 'displayName': 'TiVard', 'state': {'micOn': false, 'screenShare': null}}});
      await Future<void>.delayed(Duration.zero);
      expect(music.playing, isFalse, reason: 'まだ 1 分経っていない');
      session.debugSetLastChatAt(DateTime.now().subtract(const Duration(seconds: 61)));
      expect(music.playing, isTrue);
      expect(container.read(astellSessionProvider)!.notice, astellHoldIdleNotice);
      // 自分が話し始める → 止まる。下ろす → 鳴る。
      await session.toggleMic();
      expect(music.playing, isFalse);
      await session.toggleMic();
      expect(music.playing, isTrue);
      // 相手が話し始める → 止まる。
      client.emit(room.id, {'type': 'peer-state', 'peer': {'peerId': 'p2', 'accountId': 'tivard', 'handle': 'tivard', 'displayName': 'TiVard', 'state': {'micOn': true}}});
      await Future<void>.delayed(Duration.zero);
      expect(music.playing, isFalse);
      client.emit(room.id, {'type': 'peer-state', 'peer': {'peerId': 'p2', 'accountId': 'tivard', 'handle': 'tivard', 'displayName': 'TiVard', 'state': {'micOn': false}}});
      await Future<void>.delayed(Duration.zero);
      expect(music.playing, isTrue);
      // チャットが流れる → 止まる(静かな時間を仕切り直す)。
      client.emit(room.id, {'type': 'share', 'share': {'id': 'x1', 'accountId': 'tivard', 'handle': 'tivard', 'displayName': 'TiVard', 'kind': 'text', 'payload': {'text': 'いる?'}, 'createdAt': DateTime.now().toIso8601String()}});
      await Future<void>.delayed(Duration.zero);
      expect(music.playing, isFalse);
      session.debugSetLastChatAt(DateTime.now().subtract(const Duration(seconds: 90)));
      expect(music.playing, isTrue);
      // スピーカーミュート中は鳴らさない。
      session.toggleSpeaker();
      expect(music.playing, isFalse);
      session.toggleSpeaker();
      expect(music.playing, isTrue);
      // ルームの設定(オーナー)でオフ → 止まる。オンで鳴る。
      client.emit(room.id, {'type': 'room', 'room': room.copyWith(holdMusic: false).toJson()});
      await Future<void>.delayed(Duration.zero);
      expect(music.playing, isFalse);
      client.emit(room.id, {'type': 'room', 'room': room.toJson()});
      await Future<void>.delayed(Duration.zero);
      expect(music.playing, isTrue);
      // 自分の端末の設定でオフ → 止まる。
      await container.read(settingsAreaProvider(astellSettingsArea).notifier).set('holdMusic', false);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(astellHoldMusicProvider), isFalse);
      expect(music.playing, isFalse);
      await container.read(settingsAreaProvider(astellSettingsArea).notifier).set('holdMusic', true);
      await Future<void>.delayed(Duration.zero);
      expect(music.playing, isTrue);
      // 退出で止まる。
      await session.leave();
      expect(music.playing, isFalse);
    });

    test('入力中の下書き (D-311): 1 秒ごとに送る / 強い言葉の回は送らない / 送ったら取り消す / 相手の下書きを受ける', () async {
      final client = MockAstellClient();
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        astellClientProvider.overrideWithValue(client),
      ]);
      addTearDown(container.dispose);
      final session = container.read(astellSessionProvider.notifier);
      await session.join(MockAstellClient.seededRooms().first);
      await Future<void>.delayed(Duration.zero);
      List<Object?> drafts() => [for (final m in client.sent) if (m['type'] == 'draft') m['text']];
      const tick = Duration(milliseconds: 1100);

      expect(astellDraftAllowed('あしたは晴れ'), isTrue);
      expect(astellDraftAllowed('ふざけるな'), isFalse);

      session.setDraft('あー');
      expect(drafts(), isEmpty, reason: 'すぐには送らない(間隔ごと)');
      await Future<void>.delayed(tick);
      expect(drafts(), ['あー']);
      await Future<void>.delayed(tick);
      expect(drafts(), ['あー'], reason: '変わっていなければ送らない');
      session.setDraft('あーふざけるな');
      await Future<void>.delayed(tick);
      expect(drafts(), ['あー'], reason: '強い言葉が入った回は送らない(相手には直前のまま)');
      session.setDraft('あーふざけ…いや、明日は晴れ');
      await Future<void>.delayed(tick);
      expect(drafts().length, 1, reason: 'まだ強い言葉が残っている');
      session.setDraft('明日は晴れ');
      await Future<void>.delayed(tick);
      expect(drafts(), ['あー', '明日は晴れ']);
      session.clearDraft();
      expect(drafts(), ['あー', '明日は晴れ', null], reason: '送った / 消したら、すぐ取り消す');
      session.clearDraft();
      expect(drafts().length, 3, reason: '取り消すものが無ければ送らない');

      // 相手の下書き: 受ける → その人の発言が届いたら消える / 取り消し / 退出で消える。自分の折り返しは無視。
      client.emit('r-launch', {'type': 'draft', 'peerId': 'p2', 'accountId': 'tivard', 'handle': 'tivard', 'displayName': 'TiVard', 'text': 'いま打ってる', 'startedAt': '2026-09-24T01:00:00Z'});
      client.emit('r-launch', {'type': 'draft', 'peerId': 'me', 'accountId': 'me', 'handle': 'me', 'displayName': 'あなた', 'text': 'x', 'startedAt': '2026-09-24T01:00:00Z'});
      await Future<void>.delayed(Duration.zero);
      var s = container.read(astellSessionProvider)!;
      expect(s.drafts.keys, ['p2']);
      expect(s.drafts['p2']!.startedAt, DateTime.utc(2026, 9, 24, 1));
      client.emit('r-launch', {'type': 'share', 'share': {'id': 'x1', 'accountId': 'tivard', 'handle': 'tivard', 'displayName': 'TiVard', 'kind': 'text', 'payload': {'text': 'いま打ってる'}, 'createdAt': '2026-09-24T01:00:05Z'}});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(astellSessionProvider)!.drafts, isEmpty);
      client.emit('r-launch', {'type': 'draft', 'peerId': 'p3', 'accountId': 'yamahaya', 'handle': 'yamahaya', 'displayName': '山ハヤ', 'text': 'えっと', 'startedAt': '2026-09-24T01:01:00Z'});
      client.emit('r-launch', {'type': 'draft', 'peerId': 'p2', 'accountId': 'tivard', 'handle': 'tivard', 'displayName': 'TiVard', 'text': 'つぎ', 'startedAt': '2026-09-24T01:02:00Z'});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(astellSessionProvider)!.drafts.length, 2);
      client.emit('r-launch', {'type': 'draft', 'peerId': 'p3', 'text': null});
      client.emit('r-launch', {'type': 'peer-left', 'peerId': 'p2'});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(astellSessionProvider)!.drafts, isEmpty);
      await session.leave();
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
    expect(find.byType(AstellTile), findsWidgets);
    final vcList = find.descendant(of: find.byType(VcScreen), matching: find.byType(Scrollable)).first;
    // 近日開催 (D-159): 予約中のルームの節がおすすめの次に入る。
    await tester.scrollUntilVisible(find.text('近日開催'), 200, scrollable: vcList);
    await tester.pumpAndSettle();
    expect(find.text('近日開催'), findsOneWidget);
    expect(find.textContaining('開催予定 '), findsWidgets);
    await tester.scrollUntilVisible(find.text('トレンド'), 200, scrollable: vcList);
    await tester.pumpAndSettle();
    expect(find.text('トレンド'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('フォロー中'), 200, scrollable: vcList);
    await tester.pumpAndSettle();
    expect(find.text('フォロー中'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('辞退'), -200, scrollable: vcList);
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
    // ホスト(ダグラス、接続中)は参加メンバーの行から外れて、上の「ホスト」の枠に出る。
    expect(find.text('ホスト'), findsOneWidget);
    expect(find.byType(AstellHostRow), findsOneWidget);
    expect(find.descendant(of: find.byType(AstellHostRow), matching: find.text('ダグラス')), findsOneWidget);
    expect(find.descendant(of: find.byType(AstellHostRow), matching: find.text('参加中')), findsOneWidget);
    expect(find.descendant(of: find.byType(AstellMembersRow), matching: find.text('ダグラス')), findsNothing);
    expect(find.text('他1人'), findsOneWidget); // ホストを除く 4 人中 3 人表示
    expect(find.byType(AstellGenreChips), findsOneWidget);
    expect(find.text('参加'), findsOneWidget);

    await tester.tap(find.text('参加'));
    await tester.pumpAndSettle();
    expect(find.byType(AstellRoomBody), findsOneWidget);
    expect(container.read(astellSessionProvider)?.connected, isTrue);
    expect(find.text('退出'), findsOneWidget);
    expect(find.text('共有'), findsOneWidget);
    // ホームの下の方(ハンドルが 26px になって画面外、D-178)。リストをずらしてから見る。
    await tester.drag(find.text('参加メンバー'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(find.text('プレビューにざっくり要約を表示する'), findsOneWidget);
    await tester.drag(find.text('プレビューにざっくり要約を表示する'), const Offset(0, 150)); // 戻す
    await tester.pumpAndSettle();

    // 自動再生 (D-147): TiVard が画面共有中なので、参加した時点で共有枠に出ている。
    // 下段 (D-148 → D-324): 左端 = スピーカー / マイク / 画面共有 / 全画面(共有枠にある間) / プラグイン / 字幕、
    // 右端 = 共有する + 設定。「…」→ ミュート → 「ミュート中」。
    expect(container.read(astellSessionProvider)!.viewingPeer?.displayName, 'TiVard');
    expect(find.textContaining('TiVard の画面'), findsOneWidget);
    expect(find.byKey(astellFooterActionsKey), findsOneWidget);
    expect(find.byTooltip('スピーカーミュート'), findsOneWidget);
    expect(find.byTooltip('マイクオン'), findsOneWidget);
    expect(find.byTooltip('字幕オフ'), findsOneWidget); // 並びの最後(入力欄の隣)は幅が足りなくても出す
    // 狭幅(360px)は 3 つ: 先頭の 2 つ + 最後の字幕。残りは歯車のメニューの先頭へ(歯車に点、D-324)。
    expect(find.byTooltip('画面共有'), findsNothing);
    expect(find.byKey(astellOverflowDotKey), findsOneWidget);
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    final overflow = find.byKey(astellOverflowKey);
    expect(find.descendant(of: overflow, matching: find.byTooltip('画面共有')), findsOneWidget);
    expect(find.descendant(of: overflow, matching: find.byTooltip('全画面')), findsOneWidget);
    expect(find.descendant(of: overflow, matching: find.byTooltip('プラグインアクション(未登録)')), findsNothing); // D-328: 選ぶシートは廃止
    expect(find.text('下段のボタンの並びを編集'), findsOneWidget);
    // 保留音の設定 (D-327): 自分の端末のスイッチ(ルームのスイッチはオーナーだけ)。シートの下の方(スクロールして見る)。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('astell.holdMusic.mine')), 200, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('astell.holdMusic.mine')), findsOneWidget);
    expect(find.byKey(const ValueKey('astell.holdMusic.room')), findsNothing);
    container.read(overlayManagerProvider).close('astell.room.settings');
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
    expect(find.byTooltip('マイクオン'), findsNothing);
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
    // ほかの人の下書き (D-311): 書き始めの時刻の位置に「入力中」で差し込まれ、取り消しで消える。
    (container.read(astellClientProvider) as MockAstellClient).emit('r-launch', {'type': 'draft', 'peerId': 'p3', 'accountId': 'yamahaya', 'handle': 'yamahaya', 'displayName': '山ハヤ', 'text': 'スタビライザーの件だけど', 'startedAt': DateTime.now().toUtc().toIso8601String()});
    await tester.pumpAndSettle();
    expect(find.text('入力中'), findsOneWidget);
    expect(find.textContaining('スタビライザーの件だけど'), findsOneWidget);
    (container.read(astellClientProvider) as MockAstellClient).emit('r-launch', {'type': 'draft', 'peerId': 'p3', 'text': null});
    await tester.pumpAndSettle();
    expect(find.text('入力中'), findsNothing);
    expect(find.byTooltip('共有する'), findsOneWidget);
    // キーボードが出て FOW が縮んでも(閉じて伸び戻る間も)compact に切り替わらず、入力欄と
    // 選んでいたタブが残る (D-178: 以前は TextField ごと消えてキーボードが一瞬で閉じていた)。
    await tester.tap(find.widgetWithText(TextField, 'input..'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 1800);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'input..'), findsOneWidget);
    expect(tester.widget<TextField>(find.widgetWithText(TextField, 'input..')).focusNode?.hasFocus ?? FocusManager.instance.primaryFocus != null, isTrue);
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pumpAndSettle();
    expect(DefaultTabController.of(tester.element(find.byType(TabBarView))).index, 1); // チャットのまま
    await tester.enterText(find.widgetWithText(TextField, 'input..'), 'こん');
    await tester.pumpAndSettle();
    // 下書き枠は末尾(時刻順)。リストを末尾まで送ってから見る(ハンドル 26px で 1 行ぶん外、D-178)。
    final chatList = find.descendant(of: find.byType(TabBarView), matching: find.byWidgetPredicate((w) => w is Scrollable)).last;
    await tester.scrollUntilVisible(find.text('下書き'), 100, scrollable: chatList);
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
    expect(find.byTooltip('マイクオン'), findsOneWidget);
    expect(find.byTooltip('画面共有'), findsNothing); // stick は 3 つまで(先頭の 2 つ + 最後の字幕、D-324)
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
    await tester.ensureVisible(find.byTooltip('画面共有を表示')); // タブ欄が狭いとメンバー行の下端が外 (D-178)
    await tester.tap(find.byTooltip('画面共有を表示'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.viewingPeer?.displayName, 'TiVard');
    expect(find.textContaining('TiVard の画面'), findsOneWidget);
    expect(find.byTooltip('マイクオン'), findsOneWidget);
    expect(find.byTooltip('全画面'), findsWidgets);
    await tester.ensureVisible(find.byTooltip('共有枠に表示中'));
    await tester.tap(find.byTooltip('共有枠に表示中'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.viewingPeer, isNull);
    expect(find.byTooltip('全画面'), findsNothing);

    // 歯車 → 設定: 自動表示の種類と読み上げ音声(CosyVoice2-0.5B)。
    await tester.tap(find.byTooltip('設定'));
    await tester.pumpAndSettle();
    expect(find.text('VC の設定'), findsOneWidget);
    // 先頭は下段に入りきらないボタンと「下段のボタンの並びを編集」(D-324)。自動再生の設定 (D-147) はその下。
    expect(find.byKey(astellOverflowKey), findsOneWidget);
    await tester.scrollUntilVisible(find.widgetWithText(RasqSwitchListTile, '画面共有が始まったら共有枠に出す'), 80, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(RasqSwitchListTile, '画面共有が始まったら共有枠に出す'), findsOneWidget);
    await tester.tap(find.widgetWithText(RasqSwitchListTile, '画面共有が始まったら共有枠に出す'));
    await tester.pumpAndSettle();
    expect(container.read(astellAutoPlayProvider), isFalse);
    // 読み上げの段はシートの下(遅延 ListView)なのでスクロールして見る。
    await tester.scrollUntilVisible(find.text('女性 1(日本語)'), 80, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    expect(find.textContaining('CosyVoice2-0.5B'), findsOneWidget);
    expect(find.text('女性 1(日本語)'), findsOneWidget);
    // 自動表示の段は上(保留音の段 D-327 のぶん遠くなったので、戻ってから)。
    await tester.scrollUntilVisible(find.widgetWithText(RasqSwitchListTile, 'テキスト'), -80, scrollable: find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(RasqSwitchListTile, 'テキスト'));
    await tester.pumpAndSettle();
    expect(container.read(astellAutoShareProvider)['text'], isTrue);
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();

    // 自分の画面共有モード: 画面共有(狭幅では歯車のメニューの先頭、D-324)が塗りつぶしに、展開の上部に印。
    await tapOverflow(tester, '画面共有');
    expect(container.read(astellSessionProvider)!.screenShareOn, isTrue);
    expect(find.text('画面を共有しています'), findsOneWidget);
    await tapOverflow(tester, '画面共有オフ');
    expect(container.read(astellSessionProvider)!.screenShareOn, isFalse);

    // ルーム: 参加メンバー全員。
    await tester.tap(inRoom('ルーム'));
    await tester.pumpAndSettle();
    expect(find.text('参加メンバー(5)'), findsOneWidget);
    // ルームタブはホストが先頭(役割のピル付き)。
    final firstName = tester.widgetList<Text>(find.descendant(of: find.byType(AstellRoomBody), matching: find.textContaining('@'))).first.data;
    expect(firstName, '@douglas');
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
    // 共有枠パネルが上に出て行が下へ押される(遅延リストの外に出る)ので、見える所まで送ってから外す。
    await tester.scrollUntilVisible(find.text('@tivard'), 60, scrollable: find.descendant(of: find.byType(TabBarView), matching: find.byWidgetPredicate((w) => w is Scrollable)).last);
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

    // アカウント処置 (D-151): 共有の保留(held)→ 案内、却下(rejected)→ エラー、運営の閉鎖。
    final mockClient = container.read(astellClientProvider) as MockAstellClient;
    mockClient.emit('r-launch', {'type': 'held', 'reason': 'review', 'delaySeconds': 30, 'kind': 'text'});
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.notice, contains('検閲中'));
    expect(find.textContaining('検閲中: 30 秒後'), findsOneWidget);
    mockClient.emit('r-launch', {'type': 'rejected', 'reason': 'review', 'kind': 'text', 'source': 'dummy'});
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.notice, isNull);
    expect(find.textContaining('検閲で却下されました'), findsOneWidget);
    mockClient.emit('r-launch', {'type': 'closed', 'reason': 'moderation'});
    await tester.pumpAndSettle();
    expect(find.textContaining('運営によりルームが閉鎖されました'), findsWidgets); // FOW + ホームの「参加中」行
    expect(container.read(astellSessionProvider)!.connected, isFalse);

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
    Finder sheet() => find.descendant(of: find.byType(ListView).last, matching: find.byType(Scrollable));
    // 先頭の下段のボタン(D-324)の下。
    await tester.scrollUntilVisible(find.text('モデレーション(オーナー)'), 40, scrollable: sheet());
    await tester.pumpAndSettle();
    expect(find.text('モデレーション(オーナー)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('フォロワーだけ'), 40, scrollable: sheet());
    await tester.pumpAndSettle();
    await tester.tap(find.text('フォロワーだけ'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.room.joinPolicy, 'followers');
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
    // ホストの配信 (D-317): カメラで配信 → hostStream が立ち「配信を止める」に → 止めると消える。
    await tester.scrollUntilVisible(find.text('カメラで配信する'), 80, scrollable: sheet());
    await tester.pumpAndSettle();
    await tester.tap(find.text('カメラで配信する'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.room.hostStream?.kind, 'video');
    expect(container.read(astellSessionProvider)!.streaming, 'camera');
    expect(find.text('配信を止める'), findsWidgets);
    await tester.tap(find.widgetWithText(RasqListTile, '配信を止める'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider)!.room.hostStream, isNull);
    expect(find.text('カメラで配信する'), findsOneWidget);
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

  test('AsTell リンクの検出と共有文 (D-159/D-160)', () {
    expect(astellRoomIdIn('今夜やります rasq://astell/r-launch よろしく'), 'r-launch');
    expect(astellRoomIdIn('https://central.example/astell/9f1c-uuid まで'), '9f1c-uuid');
    expect(astellRoomIdIn('リンクなし https://example.com/astellx/1'), isNull);
    // 共有 URL (D-165): `@handle/<Base58>` からはコードを id として拾う(Central はコードでも引ける)。
    expect(astellRoomIdIn('来てね https://astell.rasq.jp/@douglas/A7XeQCmhp4JYSaDQeZEyJG'), 'A7XeQCmhp4JYSaDQeZEyJG');
    expect(astellRoomIdIn('https://astell.rasq.jp/@douglas/A7XeQCmhp4JYSaDQeZEyJG/banner.png'), isNull);
    expect(astellRoomIdIn('https://example.com/@douglas'), isNull);
    final room = AstellRoom(id: 'x', ownerId: 'o', ownerHandle: 'o', ownerDisplayName: 'ホスト', title: '反省会', genres: const ['打上会'], createdAt: DateTime(2026), scheduledAt: DateTime.now().add(const Duration(days: 1)));
    expect(astellRoomLink(room), 'rasq://astell/x');
    expect(astellRoomLink(AstellRoom.fromJson({...room.toJson(), 'shareUrl': 'https://astell.rasq.jp/@o/abc'})), 'https://astell.rasq.jp/@o/abc');
    expect(astellShareText(room, 'rasq://astell/x'), allOf(contains('「反省会」を'), contains('に開催します'), contains('#打上会'), endsWith('rasq://astell/x')));
    expect(astellShareText(room.copyWith(clearSchedule: true), 'L'), startsWith('「反省会」を開催中です'));
  });

  testWidgets('作成 FOW (D-159): 開催を予約 + ジャンルを選定 + 共有 → 予約(参加しない)→ 近日開催に載り、コンポーザーへリンク転送', (tester) async {
    final container = await pump(tester);
    await openVc(tester);
    await tester.tap(find.byTooltip('VC を作成'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'タイトル'), '反省会');
    // ジャンル選定: 自動選択をオフ → 入力欄とチップ。
    final form = find.descendant(of: find.byKey(astellCreateFormKey), matching: find.byType(Scrollable)).first; // 外側(縦)。内側に招待の横 ListView がある
    await tester.scrollUntilVisible(find.text('ジャンルを自動選択する'), 200, scrollable: form);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ジャンルを自動選択する'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('astell.create.genre.input')), 200, scrollable: form);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('astell.create.genre.input')), '#写真');
    await tester.tap(find.byTooltip('ジャンルを追加'));
    await tester.pumpAndSettle();
    expect(find.text('#写真 ✕'), findsOneWidget);
    // 開催予約: オンで日付/時刻ボタン、作成ボタンは「予約」。
    await tester.scrollUntilVisible(find.text('開催を予約する'), 200, scrollable: form);
    await tester.pumpAndSettle();
    await tester.tap(find.text('開催を予約する'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('astell.create.date')), findsOneWidget);
    expect(find.byKey(const ValueKey('astell.create.time')), findsOneWidget);
    expect(find.text('予約'), findsOneWidget);
    // ヘッダーの共有をオン → 作成後にコンポーザーへ転送。
    await tester.tap(find.byKey(const ValueKey('astell.create.share')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('予約'));
    await tester.pumpAndSettle();
    // コンポーザーに共有文(リンク付き)。閉じる。
    final field = find.byType(TextField).evaluate().map((e) => e.widget as TextField).where((t) => (t.controller?.text ?? '').contains('rasq://astell/')).toList();
    expect(field, isNotEmpty, reason: 'コンポーザーに共有リンクが入る');
    expect(field.first.controller!.text, contains('「反省会」を'));
    expect(field.first.controller!.text, contains('#写真'));
    final roomId = astellRoomIdIn(field.first.controller!.text)!;
    container.read(overlayManagerProvider).close(composerFowId, reason: OverlayCloseReason.discard);
    await tester.pumpAndSettle();
    // 予約なので参加していない。ホームの近日開催に載り、タイルに開催予定。
    expect(container.read(astellSessionProvider), isNull);
    expect(find.textContaining('に予約しました'), findsOneWidget);
    final created = await container.read(astellClientProvider).room(roomId);
    expect(created!.isScheduled, isTrue);
    expect(created.genres, ['写真']);
    expect(created.autoGenre, isFalse);
    await tester.pumpAndSettle();
    expect(find.text('近日開催'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('近日開催'), 200, scrollable: find.descendant(of: find.byType(VcScreen), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('開催予定 '), findsWidgets);
  });

  testWidgets('TL の AsTell タイル (D-160): リンク付き投稿 → タイル、ブックマーク保存/削除、開始通知、参加中は「戻る」', (tester) async {
    final container = await pump(tester, posts: [post('p1', '今夜やります rasq://astell/r-launch'), post('p2', '来週の反省会 rasq://astell/r-planned')]);
    // 開催中のルーム(打ち上げの打ち上げ)のタイルが本文の下に出る。
    expect(find.byKey(const ValueKey('astell.post.tile.r-launch')), findsOneWidget);
    expect(find.text('打ち上げの打ち上げ'), findsOneWidget);
    final live = find.descendant(of: find.byKey(const ValueKey('astell.post.tile.r-launch')), matching: find.byKey(const ValueKey('astell.tile.bookmark')));
    expect(live, findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('astell.post.tile.r-launch')), matching: find.byKey(const ValueKey('astell.tile.remind'))), findsNothing, reason: '開催中には通知ボタンなし');
    // ブックマーク保存 → ブックマーク画面に AsTell の帯。
    await tester.tap(live);
    await tester.pumpAndSettle();
    expect(find.text('ブックマークに保存しました'), findsOneWidget);
    expect(container.read(astellBookmarkedProvider('r-launch')), isTrue);
    // 予約ルーム(反省会)のタイル: 開催予定 + 通知ボタン → 登録 → 端末通知に入る。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('astell.post.tile.r-planned')), 200, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('開催予定 '), findsOneWidget);
    final bell = find.descendant(of: find.byKey(const ValueKey('astell.post.tile.r-planned')), matching: find.byKey(const ValueKey('astell.tile.remind')));
    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(notifier.scheduled.length, 1);
    await tester.pump(const Duration(seconds: 5)); // 前のスナックバーが消えてから次
    await tester.pumpAndSettle();
    expect(find.textContaining('に通知します'), findsOneWidget);
    expect(notifier.scheduled.values.single.title, 'ブックマークしたVCが始まります！');
    expect(container.read(astellRemindedProvider('r-planned')), isTrue);
    // 通知画面に「開始通知を登録した VC」→ 解除で消える。
    await tester.tap(find.byTooltip('通知'));
    await tester.pumpAndSettle();
    expect(find.text('開始通知を登録した VC'), findsOneWidget);
    expect(find.text('打ち上げ反省会'), findsOneWidget);
    await tester.tap(find.text('解除'));
    await tester.pumpAndSettle();
    expect(notifier.scheduled, isEmpty);
    expect(find.text('開始通知を登録した VC'), findsNothing);
    // ブックマーク画面: AsTell の帯にタイル → 削除で消える。
    await tester.tap(find.byTooltip('ホーム'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('サイドバーを開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ブックマーク'));
    await tester.pumpAndSettle();
    expect(find.text('AsTell'), findsOneWidget);
    expect(find.text('打ち上げの打ち上げ'), findsWidgets); // 帯のタイル + お気に入りの投稿内タイル
    // 前のスナックバー(通知登録 / 解除)を流してから。
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('astell.tile.bookmark')).first);
    await tester.pumpAndSettle();
    expect(find.text('ブックマークから削除しました'), findsOneWidget);
    expect(container.read(astellBookmarkedProvider('r-launch')), isFalse);
    // 参加中のルームのタイルは「戻る」→ ルーム FOW。
    await container.read(astellSessionProvider.notifier).join((await container.read(astellClientProvider).room('r-launch'))!);
    await tester.tap(find.byTooltip('戻る')); // ブックマーク画面を閉じる
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('ホーム'));
    await tester.pumpAndSettle();
    final tile = find.byKey(const ValueKey('astell.post.tile.r-launch'));
    expect(find.descendant(of: tile, matching: find.text('戻る')), findsOneWidget);
    expect(find.descendant(of: tile, matching: find.text('見てみる')), findsNothing);
    await tester.tap(find.descendant(of: tile, matching: find.text('戻る')));
    await tester.pumpAndSettle();
    expect(find.byType(AstellRoomBody), findsOneWidget);
    await container.read(astellSessionProvider.notifier).leave();
  });

  testWidgets('ホームヘッダーの AsTell 帯 (D-163): 招待/フォロー中のルームのバンドル → タップで参加 FOW', (tester) async {
    await pump(tester);
    // ホーム TL のヘッダー: 招待されている「サプライズ」(よもぎもち)のバンドル。
    expect(find.byKey(const ValueKey('astell.header.strip')), findsOneWidget);
    final bundle = find.descendant(of: find.byKey(const ValueKey('astell.header.strip')), matching: find.byType(RasqAvatarBundle));
    expect(bundle, findsOneWidget);
    expect(find.byTooltip('よもぎもち: サプライズ'), findsOneWidget);
    await tester.tap(bundle);
    await tester.pumpAndSettle();
    expect(find.text('参加'), findsOneWidget); // 参加 FOW
    expect(find.text('サプライズ'), findsWidgets);
  });

  testWidgets('自分がホストのタイルの … (D-164): 参加する / 終了する(報告は無い)→ 確認シート → 終了', (tester) async {
    final container = await pump(tester);
    await container.read(astellClientProvider).createRoom(const NewAstellRoom(title: '自分の部屋'));
    container.invalidate(astellHomeProvider);
    await openVc(tester);
    expect(find.text('自分の部屋'), findsWidgets);
    final tile = find.ancestor(of: find.text('自分の部屋').first, matching: find.byType(AstellTile)).first;
    await tester.tap(find.descendant(of: tile, matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
    expect(find.text('終了する'), findsOneWidget);
    expect(find.text('参加する'), findsOneWidget);
    expect(find.text('報告'), findsNothing);
    expect(find.text('ホストをフォロー'), findsNothing);
    await tester.tap(find.text('終了する'));
    await tester.pumpAndSettle();
    expect(find.text('ルームを終了'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '終了する'));
    await tester.pumpAndSettle();
    expect(find.text('「自分の部屋」を終了しました'), findsOneWidget);
    expect(find.text('自分の部屋'), findsNothing);
  });

  testWidgets('FOW 本体を掴んで移動 (D-161): ルーム FOW の本体側ヘッダー(ListView でない所)を上へ → アプリヘッダー下付き、下へ → 戻る', (tester) async {
    await pump(tester);
    await openVc(tester);
    await tester.tap(find.text('見てみる').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('参加'));
    await tester.pumpAndSettle();
    expect(find.byType(AstellRoomBody), findsOneWidget);
    Finder panel() => find.byWidgetPredicate((w) => w is Material && w.elevation == 8);
    final before = tester.getTopLeft(panel()).dy;
    expect(before, greaterThan(100));
    // 本体側ヘッダーのタイトル文字を掴んで上へ(ウィンドウ高さの 1 割以上)。
    await tester.drag(find.descendant(of: find.byKey(astellRoomHeaderKey), matching: find.text('打ち上げの打ち上げ')), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(panel()).dy, lessThan(120)); // アプリヘッダーの直下
    await tester.drag(find.descendant(of: find.byKey(astellRoomHeaderKey), matching: find.text('打ち上げの打ち上げ')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(panel()).dy, closeTo(before, 1));
  });

  test('投稿のインライン共有 (D-166): URL 判定 / payload / 開くアカウントの一致', () {
    expect(parseSnsPostUrl('https://misskey.io/notes/9abc123XYZ'), (sns: 'misskey', instance: 'misskey.io', id: '9abc123XYZ'));
    expect(parseSnsPostUrl('https://mastodon.social/@Gargron/1'), (sns: 'mastodon', instance: 'mastodon.social', id: '1'));
    expect(parseSnsPostUrl('https://bsky.app/profile/bsky.app/post/3k4')?.sns, 'bluesky');
    expect(parseSnsPostUrl('https://astell.rasq.jp/@rasq_1/A7XeQCmhp4JYSaDQeZEyJG'), isNull);
    expect(parseSnsPostUrl('https://example.com/'), isNull);
    final p = Post(id: 'n1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター', avatarUrl: Uri.parse('https://example.test/a.png')), createdAt: DateTime.utc(2026, 9, 1), body: 'こんにちは', media: [MediaItem(id: 'm1', type: MediaType.image, url: Uri.parse('https://example.test/m.png'))]);
    final payload = astellPostPayloadOf(p);
    expect(payload['url'], 'https://example.test/notes/n1');
    expect(payload['sns'], 'misskey');
    expect(payload['instance'], 'example.test');
    expect(payload['thumbnailUrl'], 'https://example.test/m.png');
    expect((payload['media'] as List).length, 1);
    final back = postFromSharePayload(payload, acc)!;
    expect(back.id, 'n1');
    expect(back.body, 'こんにちは');
    expect(back.media.single.type, MediaType.image);
    expect(back.author.displayName, 'テスター');
    // 一致するアカウント: 同じ SNS + インスタンス。違うインスタンスは null(= ブラウザ)。
    expect(astellAccountForPost(payload, [fakeSession()]), acc);
    expect(astellAccountForPost({'sns': 'misskey', 'instance': 'other.example'}, [fakeSession()]), isNull);
    expect(astellAccountForPost({'sns': 'mastodon', 'instance': 'example.test'}, [fakeSession()]), isNull);
  });

  test('AsTell の投稿共有は公開範囲を見る (D-242): public / home / unlisted だけ本文ごと共有できる', () {
    Post post({String? visibility, bool localOnly = false, PostSource source = PostSource.note, String? cw}) => Post(
        id: 'n1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime.utc(2026, 9, 1), body: '本文', visibility: visibility, localOnly: localOnly, source: source, contentWarning: cw);
    for (final v in ['public', 'home', 'unlisted']) {
      expect(astellShareBlockReason(post(visibility: v)), isNull, reason: v);
    }
    for (final v in ['followers', 'private', 'specified', 'direct']) {
      expect(astellShareBlockReason(post(visibility: v)), isNotNull, reason: v);
    }
    expect(astellShareBlockReason(post()), contains('公開範囲が分からない'));
    expect(astellShareBlockReason(post(visibility: 'public', localOnly: true)), contains('ローカル限定'));
    expect(astellShareBlockReason(post(visibility: 'public', source: PostSource.chatMessage)), isNotNull);
    // 公開範囲と閲覧注意は payload に独立して載る(サーバーが visibility を検査する)。
    final payload = astellPostPayloadOf(post(visibility: 'home', cw: 'ネタバレ'));
    expect(payload['visibility'], 'home');
    expect(payload['localOnly'], false);
    expect(payload['cw'], 'ネタバレ');
  });

  testWidgets('フォロワー限定の投稿は AsTell に共有しない (D-242): 共有 FOW の「AsTell に共有」は理由を出して止まる', (tester) async {
    final container = await pump(tester, posts: [post('p1', 'フォロワー向けの投稿', visibility: 'followers')]);
    await container.read(astellSessionProvider.notifier).join((await container.read(astellClientProvider).room('r-launch'))!);
    await tester.pumpAndSettle();
    final before = container.read(astellSessionProvider)!.shares.length;
    await tester.tap(find.byTooltip('メニュー').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('共有'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('post.share.astell')));
    await tester.pumpAndSettle();
    expect(find.text('公開範囲が限定された投稿は AsTell に共有できません'), findsOneWidget);
    expect(container.read(astellSessionProvider)!.shares.length, before);
  });

  testWidgets('AsTell で投稿を共有 (D-166): 投稿メニュー → 参加中のルームへ post 共有、チャット行のタップで一致するアカウントならアプリ内展開、URL 入力は解決して post', (tester) async {
    final container = await pump(tester);
    // 参加してから TL へ戻り、投稿の … → 共有 FOW の「プラグインに共有」に「AsTell に共有」(D-178:
    // 投稿メニューの「AsTell で共有」は共有 FOW へ統合)。
    await container.read(astellSessionProvider.notifier).join((await container.read(astellClientProvider).room('r-launch'))!);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('メニュー').first);
    await tester.pumpAndSettle();
    expect(find.text('AsTell で共有'), findsNothing);
    await tester.tap(find.text('共有'));
    await tester.pumpAndSettle();
    expect(find.text('プラグインに共有'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('post.share.astell')));
    await tester.pumpAndSettle();
    expect(find.textContaining('に共有しました'), findsOneWidget);
    final shares = container.read(astellSessionProvider)!.shares;
    expect(shares.last.kind, 'post');
    expect(shares.last.payload['instance'], 'example.test');
    expect(shares.last.payload['body'], 'ふつうの投稿');
    // ルーム FOW のチャット: 入力欄に投稿 URL → 一致するアカウントが無い(misskey.example)ので
    // Central(モック)で解決 → post として共有。
    await openVc(tester);
    await tester.tap(find.textContaining('参加中: '));
    await tester.pumpAndSettle();
    Finder inRoom(String t) => find.descendant(of: find.byType(AstellRoomBody), matching: find.text(t));
    await tester.tap(inRoom('チャット'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'input..'), 'https://misskey.example/notes/abc123');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('送信完了する'));
    await tester.pumpAndSettle();
    final last = container.read(astellSessionProvider)!.shares.last;
    expect(last.kind, 'post');
    expect(last.payload['author'], 'モックの投稿者');
    expect(last.payload['instance'], 'misskey.example');
    // チャット行(遅延 ListView の末尾)をタップ → インスタンスが一致する投稿はアプリ内でスレッド展開。
    final chat = find.ancestor(of: find.textContaining('ダグラス> いい感じに行ったねー'), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.textContaining('あなた> ふつうの投稿'), 80, scrollable: chat);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('あなた> ふつうの投稿'));
    await tester.pumpAndSettle();
    expect(find.text('投稿'), findsWidgets); // スレッド展開画面のヘッダー
    expect(find.text('@tester'), findsWidgets); // 共有した投稿(自分のアカウントで開いた)
    await container.read(astellSessionProvider.notifier).leave();
  });
}
