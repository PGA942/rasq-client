import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_design/rasq_design.dart' show RasqTogglePillButton;
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/post_row.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart' show FollowState;

import 'support/fakes.dart';

/// D-421: RASQ アカウント(総合表示)で、ほかのアカウントの自分の投稿の … が他人のメニューになり、フォロー中の一覧が
/// 「フォロー」(未フォロー)と出ていた。自分かどうか・関係・操作を、現在のアカウントではなく、投稿 / 一覧が属するアカウントで決める。
const acc1 = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
const acc2 = AccountId(kind: SnsKind.misskey, instance: 'other.test', handle: 'second');
const friendAccount = AccountId(kind: SnsKind.misskey, instance: 'other.test', handle: 'friend');
const friend = UserSummary(id: 'u-friend', account: friendAccount, displayName: 'フレンド');

/// アカウントごとに、そのサーバーでのフォローの関係を返すセッション。
class _RelSession extends FakeSnsSession {
  _RelSession(super.session, super.posts, {required this.followingIds});
  final Set<String> followingIds;
  final deleted = <String>[];
  final followed = <String>[];

  @override
  Future<Map<String, FollowState>> relationships(List<String> userIds) async => {for (final id in userIds) id: FollowState(following: followingIds.contains(id))};
  @override
  Future<Page<UserSummary>> following(String id, {String? cursor, int limit = 20}) async => Page(items: account == acc2 ? const [friend] : const []);
  @override
  Future<void> deletePost(String id) async => deleted.add(id);
  @override
  Future<FollowState> setFollowing(String userId, bool following) async {
    followed.add('$userId:$following');
    return FollowState(following: following);
  }
}

class _RelPlugin extends FakeSnsPlugin {
  _RelPlugin({required super.posts, required this.following});
  final Map<String, Set<String>> following;
  final sessions = <String, _RelSession>{};
  @override
  SnsSession open(AccountSession session) => sessions[session.account.key] = _RelSession(session, posts(session.account), followingIds: following[session.account.key] ?? const {});
}

void main() {
  group('自分かどうか (D-421)', () {
    test('ハンドルの大文字小文字・先頭の @・handle@host・https:// と末尾の / を同じに見る', () {
      expect(sameAccountIdentity(const AccountId(kind: SnsKind.misskey, instance: 'Example.test', handle: '@Tester'), acc1), isTrue);
      expect(sameAccountIdentity(const AccountId(kind: SnsKind.other, instance: '', handle: 'tester@example.test'), acc1), isTrue);
      expect(sameAccountIdentity(const AccountId(kind: SnsKind.misskey, instance: 'https://example.test/', handle: 'tester'), acc1), isTrue);
      expect(sameAccountIdentity(const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'second'), acc1), isFalse);
      expect(sameAccountIdentity(const AccountId(kind: SnsKind.misskey, instance: 'other.test', handle: 'tester'), acc1), isFalse, reason: '同じ名前でもサーバーが違えば別の人');
      expect(sameAccountIdentity(const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: ''), const AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: '')), isFalse);
    });

    test('見ているアカウントと同じ人なら自分。id は同じアカウントのプロフィールのときだけ比べる', () {
      const mine = UserSummary(id: 'u2', account: acc2, displayName: 'second');
      expect(isViewerSelf(mine, acc2), isTrue);
      expect(isViewerSelf(mine, acc1), isFalse, reason: '現在のアカウントから見れば別の人');
      const me1 = UserSummary(id: 'u2', account: acc1, displayName: 'tester');
      expect(isViewerSelf(mine, acc2, me: me1), isTrue);
      expect(isViewerSelf(const UserSummary(id: 'u2', account: friendAccount, displayName: 'x'), acc2, me: me1), isFalse, reason: '別のサーバーの id は比べない');
      expect(isViewerSelf(const UserSummary(id: 'me-id', account: friendAccount, displayName: 'x'), acc1, me: const UserSummary(id: 'me-id', account: acc1, displayName: 't')), isTrue, reason: 'me() の id');
      expect(isViewerSelf(const UserSummary(id: '-', account: friendAccount, displayName: 'x'), acc1, me: const UserSummary(id: '-', account: acc1, displayName: 't')), isFalse, reason: 'me() を取れていない id は使わない');
    });
  });

  Post postOf(AccountId v) => Post(
      id: 'p-${v.handle}',
      account: v,
      author: UserSummary(id: 'u-${v.handle}', account: v, displayName: v.handle),
      createdAt: DateTime(2026, 10, 3, 10),
      body: '${v.handle} の投稿');

  Future<(ProviderContainer, _RelPlugin)> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: a.handle);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [session(acc1).toJson(), session(acc2).toJson()],
        'current': acc1.key,
        // RASQ アカウント(バンドルタイル)を選んでいる = 総合表示。
        'bundle': true,
      }),
    });
    final plugin = _RelPlugin(posts: (v) => [postOf(v)], following: {acc2.key: {friend.id}});
    final registry = PluginRegistry()..register(plugin);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqApp))), plugin);
  }

  Future<void> openMenu(WidgetTester tester, String body) async {
    final row = find.ancestor(of: find.text(body), matching: find.byType(PostRow)).first;
    await tester.tap(find.descendant(of: row, matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
  }

  testWidgets('総合表示: ほかのアカウントの自分の投稿の … は自分のメニュー(削除)。削除はそのアカウントのセッションへ', (tester) async {
    final (c, plugin) = await pump(tester);
    expect(c.read(bundleViewProvider), isTrue);
    expect(c.read(currentAccountProvider), acc1);
    expect(find.text('second の投稿'), findsOneWidget);
    expect(find.text('tester の投稿'), findsOneWidget);

    // 現在でないアカウント(second)の自分の投稿。
    await openMenu(tester, 'second の投稿');
    expect(find.text('削除'), findsOneWidget);
    expect(find.text('フォロー'), findsNothing);
    expect(find.text('ブロック'), findsNothing);
    expect(find.text('報告'), findsNothing);
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除').last);
    await tester.pumpAndSettle();
    expect(plugin.sessions[acc2.key]!.deleted, ['p-second'], reason: '投稿が属するアカウントで消す');
    expect(plugin.sessions[acc1.key]!.deleted, isEmpty);

    // 現在のアカウント(tester)の自分の投稿も自分のメニュー。
    await openMenu(tester, 'tester の投稿');
    expect(find.text('削除'), findsOneWidget);
    expect(find.text('フォロー'), findsNothing);
  });

  testWidgets('総合表示: ほかのアカウントのフォロー中の一覧は、そのアカウントの関係(フォロー中)。押すとそのアカウントで外す', (tester) async {
    final (c, plugin) = await pump(tester);
    c.read(routerProvider).push('/user/u-second/follows', extra: const UserSummary(id: 'u-second', account: acc2, displayName: 'second'));
    await tester.pumpAndSettle();
    expect(find.text('フレンド'), findsOneWidget);
    expect(find.text('フォロー中'), findsWidgets, reason: 'second のサーバーではフォローしている');
    final pill = find.widgetWithText(RasqTogglePillButton, 'フォロー中').last;
    await tester.tap(pill);
    await tester.pumpAndSettle();
    expect(plugin.sessions[acc2.key]!.followed, ['u-friend:false'], reason: 'そのアカウントで外す');
    expect(plugin.sessions[acc1.key]!.followed, isEmpty);
  });

  testWidgets('総合表示: ほかのアカウントの自分のページは「自分」(フォローのボタンが無い)', (tester) async {
    final (c, _) = await pump(tester);
    c.read(routerProvider).push('/user/u-second', extra: const UserSummary(id: 'u-second', account: acc2, displayName: 'second'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(RasqTogglePillButton, 'フォロー'), findsNothing);
  });
}
