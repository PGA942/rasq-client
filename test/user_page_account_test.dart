import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/features/trend/trend_screen.dart';
import 'package:rasq_client/features/users/user_list.dart';
import 'package:rasq_client/features/users/follows_screen.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-469: 投稿タイルのアイコン / 名前から、**ログイン中のアカウントと同じサーバーのほかの人**のページを開くと
/// 「このユーザーは存在しないようです」になっていた。
///
/// 原因: ユーザーページは作者の `AccountId.key`(その人のサーバーとハンドル)でセッションを選んでいた。ログイン中の
/// アカウントと一致するのは自分だけなので、ほかの人は**現在のアカウント**へ縮退し、総合表示で現在のアカウントが
/// 別のサーバーのとき、そのサーバーの id(Misskey / Mastodon の id はサーバーの中でだけ通じる)を別のサーバーで引いて
/// 404 / 400 になっていた。→ 投稿を引いたアカウント(`post.account`)で開く。
const serverA = AccountId(kind: SnsKind.misskey, instance: 'a.test', handle: 'alice');
const serverB = AccountId(kind: SnsKind.misskey, instance: 'b.test', handle: 'tester');

/// b.test のローカルの人(Misskey の `user.host == null` → プラグインは見ているサーバーを入れる)。
const bob = UserSummary(id: 'b-bob', account: AccountId(kind: SnsKind.misskey, instance: 'b.test', handle: 'bob'), displayName: 'ボブ');

/// b.test から見たリモートの人(id は b.test の中の id)。
const dave = UserSummary(id: 'b-dave', account: AccountId(kind: SnsKind.misskey, instance: 'remote.test', handle: 'dave'), displayName: 'デイブ');

/// b.test の自分。
const meOnB = UserSummary(id: 'b-me', account: serverB, displayName: 'テスターB');

/// a.test のローカルの人。
const carol = UserSummary(id: 'a-carol', account: AccountId(kind: SnsKind.misskey, instance: 'a.test', handle: 'carol'), displayName: 'キャロル');

class _RecSession extends FakeSnsSession {
  _RecSession(super.session, super.posts);
  final userRequests = <String>[];
  final followerRequests = <String>[];

  @override
  Future<UserProfile> user(String id) {
    userRequests.add(id);
    return super.user(id);
  }

  @override
  Future<Page<UserSummary>> followers(String id, {String? cursor, int limit = 20}) {
    followerRequests.add(id);
    return super.followers(id, cursor: cursor, limit: limit);
  }
}

class _RecPlugin extends FakeSnsPlugin {
  _RecPlugin({required super.posts});
  final sessions = <String, _RecSession>{};
  @override
  SnsSession open(AccountSession session) => sessions[session.account.key] = _RecSession(session, posts(session.account));
}

void main() {
  test('アカウントの無い SNS の人のプロフィールの URL (D-469)', () {
    expect(snsProfileUrlOf(bob), Uri.parse('https://b.test/@bob'));
    expect(snsProfileUrlOf(const UserSummary(id: '1', account: AccountId(kind: SnsKind.mastodon, instance: 'mstdn.test', handle: '@m'), displayName: 'm')), Uri.parse('https://mstdn.test/@m'));
    expect(snsProfileUrlOf(const UserSummary(id: 'did:plc:x', account: AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'x.bsky.social'), displayName: 'x')), Uri.parse('https://bsky.app/profile/x.bsky.social'));
    expect(snsProfileUrlOf(const UserSummary(id: '1', account: AccountId(kind: SnsKind.misskey, instance: '', handle: 'x'), displayName: 'x')), isNull);
  });

  Post post(String id, AccountId via, UserSummary author, String body) => Post(id: id, account: via, author: author, createdAt: DateTime(2026, 10, 13, 9), body: body);

  Future<(ProviderContainer, _RecPlugin)> pump(WidgetTester tester, {List<Post> extraB = const []}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [
          AccountSession(account: serverA, pluginId: 'test.fake', token: 'ta', createdAt: DateTime(2026), displayName: 'alice').toJson(),
          AccountSession(account: serverB, pluginId: 'test.fake', token: 'tb', createdAt: DateTime(2026), displayName: 'tester').toJson(),
        ],
        // 現在は a.test、RASQ アカウント(バンドルタイル)を選んでいる = 総合表示。b.test の投稿も TL に流れる。
        'current': serverA.key,
        'bundle': true,
      }),
    });
    final plugin = _RecPlugin(
      posts: (v) => v == serverB
          ? [
              post('b1', v, bob, 'ボブの投稿'),
              post('b2', v, dave, 'デイブの投稿'),
              post('b3', v, meOnB, 'b.test の自分の投稿'),
              ...extraB,
            ]
          : [post('a1', v, carol, 'キャロルの投稿')],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqApp))), plugin);
  }

  Finder rowOf(String body) => find.ancestor(of: find.text(body), matching: find.byType(PostRow)).first;

  Future<void> tapAvatar(WidgetTester tester, String body) async {
    final row = rowOf(body);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: row, matching: find.byType(RasqAvatar)).first);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester, ProviderContainer c) async {
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
  }

  const noHit = 'このユーザーは存在しないようです。';

  testWidgets('総合表示: 同じサーバー(b.test)のほかの人のページは、アイコンからも名前からも b.test のアカウントで開く', (tester) async {
    final (c, plugin) = await pump(tester);
    expect(c.read(currentAccountProvider), serverA);
    final a = plugin.sessions[serverA.key]!;
    final b = plugin.sessions[serverB.key]!;

    await tapAvatar(tester, 'ボブの投稿');
    expect(find.byType(UserPageScreen), findsOneWidget);
    expect(find.text(noHit), findsNothing);
    expect(b.userRequests, ['b-bob']);
    expect(a.userRequests, isEmpty, reason: 'b.test の id を a.test で引かない');
    expect(find.widgetWithText(RasqTogglePillButton, 'フォロー'), findsOneWidget, reason: 'ほかの人');
    await back(tester, c);

    // 名前のタップも同じ口。
    final row = rowOf('ボブの投稿');
    await tester.tap(find.descendant(of: row, matching: find.text('ボブ')).first);
    await tester.pumpAndSettle();
    expect(find.text(noHit), findsNothing);
    expect(b.userRequests, ['b-bob', 'b-bob']);
    expect(a.userRequests, isEmpty);
  });

  testWidgets('総合表示: リモートの人・自分・現在のアカウントのサーバーの人も、投稿を引いたアカウントで開く', (tester) async {
    final (c, plugin) = await pump(tester);
    final a = plugin.sessions[serverA.key]!;
    final b = plugin.sessions[serverB.key]!;

    // b.test から見たリモートの人(id は b.test のもの)。
    await tapAvatar(tester, 'デイブの投稿');
    expect(find.text(noHit), findsNothing);
    expect(b.userRequests, ['b-dave']);
    await back(tester, c);

    // b.test の自分: 自分のページ(フォローのボタンは出ない)。
    await tapAvatar(tester, 'b.test の自分の投稿');
    expect(find.text(noHit), findsNothing);
    expect(b.userRequests, ['b-dave', 'b-me']);
    expect(find.widgetWithText(RasqTogglePillButton, 'フォロー'), findsNothing);
    await back(tester, c);

    // 現在のアカウント(a.test)の人は a.test で(従来どおり)。
    await tapAvatar(tester, 'キャロルの投稿');
    expect(find.text(noHit), findsNothing);
    expect(a.userRequests, ['a-carol']);
    expect(b.userRequests, ['b-dave', 'b-me']);
  });

  testWidgets('ユーザーページから開くフォロワーの一覧と、一覧の行からのページも、同じアカウントで引く', (tester) async {
    final (c, plugin) = await pump(tester);
    final a = plugin.sessions[serverA.key]!;
    final b = plugin.sessions[serverB.key]!;

    await tapAvatar(tester, 'ボブの投稿');
    await tester.tap(find.text('フォロワー'));
    await tester.pumpAndSettle();
    expect(find.byType(FollowsScreen), findsOneWidget);
    expect(b.followerRequests, ['b-bob']);
    expect(a.followerRequests, isEmpty);

    // 一覧(b.test の人たち)の行: デイブのページも b.test で。
    await tester.tap(find.descendant(of: find.byType(FollowsScreen), matching: find.text('デイブ')).first);
    await tester.pumpAndSettle();
    expect(find.text(noHit), findsNothing);
    expect(b.userRequests, ['b-bob', 'b-dave']);
    expect(a.userRequests, isEmpty);
  });

  testWidgets('ルート: `?account=` で引くアカウントを渡せる。無ければ従来どおり(作者自身のアカウント → 現在)', (tester) async {
    final (c, plugin) = await pump(tester);
    final a = plugin.sessions[serverA.key]!;
    final b = plugin.sessions[serverB.key]!;

    c.read(routerProvider).push('/user/${Uri.encodeComponent(bob.id)}?account=${Uri.encodeQueryComponent(serverB.key)}', extra: bob);
    await tester.pumpAndSettle();
    expect(find.text(noHit), findsNothing);
    expect(b.userRequests, ['b-bob']);
    await back(tester, c);

    // 渡さなければ現在(a.test)へ縮退 = 直す前の形(b.test の id は a.test に無い)。
    c.read(routerProvider).push('/user/${Uri.encodeComponent(bob.id)}', extra: bob);
    await tester.pumpAndSettle();
    expect(a.userRequests, isNotEmpty);
    expect(a.userRequests, everyElement('b-bob'), reason: '取り直しはあっても、引くのは a.test');
    expect(find.text(noHit), findsOneWidget);
  });

  testWidgets('トレンドのページのユーザーの一覧 (D-472、D-469 の続き): 行のタップは、そのページのアカウント(b.test)で開く', (tester) async {
    // 偽物のタグの TL は id が p1 の投稿だけを返す(b.test のボブの投稿)。
    final (c, plugin) = await pump(tester, extraB: [post('p1', serverB, bob, '#花火 ボブ')]);
    expect(c.read(currentAccountProvider), serverA);
    c.read(routerProvider).push('/trend/${Uri.encodeComponent('花火')}?account=${Uri.encodeQueryComponent(serverB.key)}');
    await tester.pumpAndSettle();
    expect(find.byType(TrendScreen), findsOneWidget);
    final a = plugin.sessions[serverA.key]!;
    final b = plugin.sessions[serverB.key]!;
    await tester.tap(find.text('ユーザー'));
    await tester.pumpAndSettle();
    final list = find.byType(UserList);
    expect(list, findsOneWidget);
    expect(tester.widget<UserList>(list).account, serverB.key);
    final before = a.userRequests.length;
    await tester.tap(find.descendant(of: list, matching: find.text('ボブ')).first);
    await tester.pumpAndSettle();
    expect(find.byType(UserPageScreen), findsOneWidget);
    expect(find.text(noHit), findsNothing);
    expect(b.userRequests.last, 'b-bob', reason: 'トレンドのページのアカウント(b.test)で引く');
    expect(a.userRequests.length, before, reason: 'b.test の id を現在のアカウント(a.test)で引かない');
  });
}
