import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/vc/astell_client.dart';
import 'package:rasq_client/features/vc/astell_fows.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/features/vc/astell_tile.dart';
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

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p1', 'ふつうの投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
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
      final wireLeft = avatar.left + 20;
      expect(live.center.dx, closeTo((wireLeft + bundle.right) / 2, 4));
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

    expect(find.text('おすすめ'), findsOneWidget);
    expect(find.text('トレンド'), findsOneWidget);
    expect(find.text('フォロー中'), findsOneWidget);
    expect(find.byType(AstellTile), findsWidgets);
    // おすすめの先頭 = ダグラス「打ち上げの打ち上げ」(要約 + ジャンル)。
    expect(find.text('ダグラス'), findsWidgets);
    expect(find.text('打ち上げの打ち上げ'), findsWidgets);
    expect(find.textContaining('打ち上げ成功、おめでとう'), findsWidgets);
    expect(find.textContaining('#打上会'), findsWidgets);
    expect(find.text('見てみる'), findsWidgets);
    // 要約なしのタイルは空表示、LIVE のタイルにはバッジ。
    expect(find.text('デスクリプションが提供されていません。'), findsWidgets);
    expect(find.text('LIVE'), findsWidgets);
    expect(find.text('フォロー中のユーザーの VC はありません'), findsOneWidget);
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

    // タブ (D-141): ホーム / チャット / 目次 / ルーム。
    Finder inRoom(String t) => find.descendant(of: find.byType(AstellRoomBody), matching: find.text(t));
    for (final t in ['ホーム', 'チャット', '目次', 'ルーム']) {
      expect(inRoom(t), findsOneWidget);
    }

    // チャット: 入力を始めると下書き枠が入り、ボタンが「送信完了する」に。全部消すと枠が消える。
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
    expect(find.byTooltip('共有する'), findsOneWidget);

    // 送信 → 共有欄とチャットに載る(モックはエコー)。
    await tester.enterText(find.widgetWithText(TextField, 'input..'), 'こんばんは');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('送信完了する'));
    await tester.pumpAndSettle();
    expect(find.text('下書き'), findsNothing);
    expect(find.text('こんばんは'), findsOneWidget); // 共有欄(常設)
    expect(find.text('あなた が共有'), findsOneWidget);
    expect(find.textContaining('あなた> '), findsOneWidget); // チャット欄

    // ルーム: 参加メンバー全員。
    await tester.tap(inRoom('ルーム'));
    await tester.pumpAndSettle();
    expect(find.text('参加メンバー(5)'), findsOneWidget);
    expect(find.byType(RasqUserRow), findsWidgets); // 全員を行で(遅延 ListView なので見えている分)
    expect(find.text('ダグラス'), findsWidgets);

    // 退出でセッションが消える。
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    expect(container.read(astellSessionProvider), isNull);
    expect(find.byType(AstellRoomBody), findsNothing);
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
    await tester.tap(find.text('参加時にウェルカムメッセージを表示する'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'ウェルカムメッセージを設定..'), 'ようこそ');
    await tester.tap(find.text('作成'));
    await tester.pumpAndSettle();

    final s = container.read(astellSessionProvider)!;
    expect(s.room.title, '夜の雑談');
    expect(s.room.welcomeMessage, 'ようこそ');
    expect(find.byType(AstellRoomBody), findsOneWidget);
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();
    // ホームのおすすめ先頭に自分のルーム。
    expect(find.text('夜の雑談'), findsWidgets);
  });
}
