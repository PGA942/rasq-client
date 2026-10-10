import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/clips/clip_timeline_screen.dart';
import 'package:rasq_client/features/clips/host_clips.dart';
import 'package:rasq_client/features/compose/post_image_fow.dart';
import 'package:rasq_client/features/trend/example_sources.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart' show childGateProvider;
import 'package:rasq_client/features/notifications/notifications_screen.dart' show notificationsProvider;
import 'package:rasq_client/features/rai/rai_functions.dart';
import 'package:rasq_client/features/users/user_providers.dart' show userProfileProvider;
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/child_safe_fakes.dart';
import 'support/fakes.dart';

/// D-454(セキュリティ確認 2026-10-09 の [9]): 別の投稿表示経路(プロフィールの固定投稿、通知、RASQ の詳細 / 反応 / アカウント
/// ページ、Swing の返信、RAi の読み取り)にも、ホームと同じ保護者の表示制限を掛ける。RASQ の詳細では見守りの時間の
/// 「詳細を開かせない」も。方針は v2(止める話題「ホラー」、12 時 = 見守りの時間の外)。
const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');

Post post(String id, String body, {String author = 'alice'}) => Post(
      id: id,
      account: acc,
      author: UserSummary(id: author, account: acc, displayName: author),
      createdAt: DateTime(2026, 9, 24, 12),
      body: body,
    );

RasqAccountPost rasq(String id, String body, {RasqAccountPost? quote}) => RasqAccountPost(id: id, body: body, quote: quote, isQuote: quote != null);

/// [settings] の方針で見守る。`allow` は外す(テストのセッション / 機能を止めない)。
ChildGate gateOf(Map<String, Object?> settings, {DateTime? now}) =>
    ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy.fromJson({...settings}..remove('allow'))), now: now ?? DateTime(2026, 9, 24, 12));

/// 見守りの時間(21:00〜06:00)の中で、詳細を開かせない設定。
ChildGate windowGate() {
  final s = v2();
  s['time'] = {...(s['time'] as Map).cast<String, Object?>(), 'hidePostDetail': true};
  return gateOf(s, now: DateTime(2026, 9, 24, 22));
}

void main() {
  final denied = gateOf(v2());

  group('RASQ の投稿', () {
    test('見せない投稿 / 見せない投稿を引用したものは外す。見守り中でなければそのまま', () {
      final t = RasqThread(
        post: rasq('p', '打ち上げ'),
        parent: rasq('pp', 'ホラー映画まとめ'),
        replies: [rasq('r1', 'ホラー映画を見た'), rasq('r2', 'いいね'), rasq('r3', '引用', quote: rasq('q', 'ホラーの話'))],
      );
      final g = childSafeRasqThread(denied, t);
      expect(g.parent, isNull);
      expect(g.parentHidden, isTrue);
      expect([for (final r in g.replies) r.id], ['r2']);
      final off = childSafeRasqThread(ChildGate.off, t);
      expect((off.parent?.id, off.replies.length, off.parentHidden), ('pp', 3, false));

      final rx = childSafeRasqReactions(denied, RasqPostReactions(quotes: [rasq('a', 'ホラーで引用'), rasq('b', '花火')]));
      expect([for (final q in rx.quotes) q.id], ['b']);
    });

    test('アカウントページ: 固定 / 一覧 / メディアの元(RASQ と SNS の投稿)から外す', () {
      final list = RasqPostList(
        posts: [rasq('h', 'ホラー映画'), rasq('ok', '海')],
        snsPosts: [
          RasqSnsPost(accountKey: 'misskey:example.test:alice', kind: 'misskey', instance: 'example.test', wire: SnsWire.post(post('s1', 'ホラー特集'))),
          RasqSnsPost(accountKey: 'misskey:example.test:alice', kind: 'misskey', instance: 'example.test', wire: SnsWire.post(post('s2', '晴れ'))),
        ],
        pins: const [(source: 'rasq', ref: 'h'), (source: 'sns', ref: 'misskey:example.test:alice|s1')],
        limit: 3,
        source: 'rasq',
      );
      final g = childSafeRasqPostList(denied, list);
      final ordered = orderAccountPosts(g);
      expect([for (final e in ordered) e.rasq?.id ?? e.sns!.postId], unorderedEquals(['ok', 's2']));
      expect(ordered.any((e) => e.pinned), isFalse, reason: '見せない固定投稿は、固定の欄にも戻さない');
      expect(orderAccountPosts(childSafeRasqPostList(ChildGate.off, list)).where((e) => e.pinned), hasLength(2));
    });

    test('詳細: 見せない投稿 / 見守りの時間に詳細を開かせない設定なら開かない', () {
      expect(rasqPostDetailBlockReason(denied, rasq('p', 'ホラー映画')), 'この投稿は表示できません');
      expect(rasqPostDetailBlockReason(denied, rasq('p', '引用', quote: rasq('q', 'ホラー'))), 'この投稿は表示できません');
      expect(rasqPostDetailBlockReason(denied, rasq('p', '花火')), isNull);
      expect(rasqPostDetailBlockReason(windowGate(), null), contains('見守りの時間'), reason: '読む前から止める');
      expect(rasqPostDetailBlockReason(ChildGate.off, rasq('p', 'ホラー映画')), isNull);
    });
  });

  test('通知: 見せない投稿は外し、通知そのものは残す。RASQ の通知の抜粋も同じ判定', () {
    final items = [
      NotificationItem(id: 'n1', account: acc, kind: NotificationKind.reply, createdAt: DateTime(2026), actors: [post('x', '').author], post: post('p1', 'ホラー映画を見た'), raw: const {'note': 'ホラー映画を見た'}),
      NotificationItem(id: 'n2', account: acc, kind: NotificationKind.reaction, createdAt: DateTime(2026), post: post('p2', '花火'), reaction: '👍'),
    ];
    final g = denied.filterNotifications(items);
    expect([for (final n in g) n.id], ['n1', 'n2']);
    expect(g[0].post, isNull);
    expect(g[0].raw, isNull);
    expect(g[0].actors, hasLength(1));
    expect(g[1].post?.id, 'p2');
    expect(identical(ChildGate.off.filterNotifications(items), items), isTrue);
    expect(denied.textHidden('ホラー映画を見た'), isTrue);
    expect(denied.textHidden('花火'), isFalse);
    expect(ChildGate.off.textHidden('ホラー映画を見た'), isFalse);
  });

  group('アプリの中', () {
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

    Future<ProviderContainer> pump(WidgetTester tester, ChildGate gate, {List<Post> posts = const [], MockClient? central, List<Override> overrides = const []}) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        if (central != null) OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts))),
          childGateProvider.overrideWithValue(gate),
          if (central != null) ...[
            orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
            centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
            orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          ],
          ...overrides,
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    MockClient centralWith(String body, List<(String, String)> replies) => MockClient((req) async {
          final path = req.url.path.replaceFirst('/api/v1', '');
          const hanako = {'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'};
          if (path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
          if (path == '/posts/p1') {
            return json({
              'post': {'id': 'p1', 'author': hanako, 'body': body, 'createdAt': '2026-09-20T00:00:00Z'},
              'replies': [for (final (id, b) in replies) {'id': id, 'author': hanako, 'body': b, 'isReply': true, 'replyTo': 'p1', 'createdAt': '2026-09-20T00:00:01Z'}],
            });
          }
          if (path == '/posts/p1/reactions') return json({'queues': [], 'rebroads': [], 'quotes': []});
          return json({'error': {'code': '404', 'message': 'not found'}}, 404);
        });

    testWidgets('RASQ の詳細: 見せない返信は出さない', (tester) async {
      final c = await pump(tester, denied, central: centralWith('打ち上げ', [('r1', 'ホラー映画を見た'), ('r2', 'いいね')]));
      c.read(routerProvider).push(Routes.rasqPost('p1'));
      await tester.pumpAndSettle();
      expect(find.text('打ち上げ'), findsWidgets);
      expect(find.text('いいね'), findsOneWidget);
      expect(find.textContaining('ホラー'), findsNothing);
      expect(find.text('返信 1'), findsOneWidget);
    });

    testWidgets('RASQ の詳細 / リアクションを表示: 見せない投稿なら中身も返信欄も出さない', (tester) async {
      final c = await pump(tester, denied, central: centralWith('ホラー映画まとめ', [('r2', 'いいね')]));
      c.read(routerProvider).push(Routes.rasqPost('p1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('childSafe.postHidden')), findsOneWidget);
      expect(find.textContaining('ホラー'), findsNothing);
      expect(find.text('いいね'), findsNothing);
      // リアクションを表示のページも同じ。
      c.read(routerProvider).push(Routes.rasqPostReactions('p1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('childSafe.postHidden')), findsWidgets);
      expect(find.textContaining('ホラー'), findsNothing);
    });

    testWidgets('RASQ の詳細: 見守りの時間に詳細を開かせない設定なら、話題が通っても開かない', (tester) async {
      final c = await pump(tester, windowGate(), central: centralWith('宿題', [('r2', '宿題おわった')]));
      c.read(routerProvider).push(Routes.rasqPost('p1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('childSafe.postHidden')), findsOneWidget);
      expect(find.textContaining('見守りの時間'), findsOneWidget);
      expect(find.text('宿題おわった'), findsNothing);
    });

    testWidgets('SNS のリアクションを表示: 投稿の詳細と同じく、見せない投稿なら対象の投稿も返信 / 引用も出さない', (tester) async {
      final c = await pump(tester, denied, posts: [post('p1', 'ホラー映画を見た'), post('p2', '花火')]);
      c.read(routerProvider).push('/post/p1/reactions');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('childSafe.postHidden')), findsOneWidget);
      expect(find.textContaining('ホラー'), findsNothing);
    });

    testWidgets('通知(共有の口): 見せない投稿は通知から外す', (tester) async {
      final c = await pump(tester, denied, posts: [post('p1', 'ホラー映画を見た'), post('p2', '花火')]);
      final page = await c.read(notificationsProvider.future);
      expect(page.items.map((n) => n.id), ['n1', 'n2']);
      expect(page.items.first.post, isNull, reason: 'FakeSnsSession の通知 n1 はホラーの投稿へのリアクション');
    });

    testWidgets('プロフィールの固定投稿: 一覧と同じ制限を掛けてから混ぜる', (tester) async {
      final alice = post('a', '').author;
      final c = await pump(tester, denied, posts: [post('u1', '海の写真'), post('u2', 'ホラー映画の感想')], overrides: [
        userProfileProvider.overrideWith((ref, k) async => UserProfile(summary: alice, pinnedPosts: [post('pin1', 'ホラー映画の固定'), post('pin2', '花火の固定')])),
      ]);
      c.read(routerProvider).push('/user/alice');
      await tester.pumpAndSettle();
      expect(find.textContaining('花火の固定'), findsOneWidget);
      expect(find.textContaining('海の写真'), findsOneWidget);
      expect(find.textContaining('ホラー'), findsNothing);
      expect(find.text('ピン留め'), findsOneWidget);
    });

    testWidgets('クリップ: 開けるクリップでも見せない投稿は外す(一覧 / 件数 / 見出しにも使わない)', (tester) async {
      final ps = [post('1', 'ホラー映画の話 #京都旅行'), post('2', '#京都旅行 の宿を探す'), post('3', '#京都旅行 町家もいい')];
      final clip = HostClip(id: 'c1', name: '旅行の候補', createdAt: DateTime(2026, 8, 27), entries: [for (final p in ps) HostClipEntry(postKey: p.key, addedAt: p.createdAt, snapshot: postSnapshot(p))]);
      await tester.pumpWidget(ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({hostClipsStorageKey: jsonEncode([clip.toJson()])})), childGateProvider.overrideWithValue(denied)],
        child: MaterialApp(theme: RasqTheme.light(), home: ClipTimelineScreen(clip: clip.info)),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('宿を探す'), findsOneWidget);
      expect(find.textContaining('ホラー'), findsNothing);
      expect(find.text('2件'), findsOneWidget);
    });

    testWidgets('投稿画像の選択 / ジャンル例の候補: 見せない投稿は出さない', (tester) async {
      final c = await pump(tester, denied, posts: [post('p1', 'ホラー映画を見た'), post('p2', '花火を見た'), post('p3', '夏祭りの花火')]);
      final ref = tester.element(find.byType(RasqApp)) as WidgetRef;
      showPostImageFow(ref);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('postImage.post.p2')), findsOneWidget);
      expect(find.byKey(const ValueKey('postImage.post.p1')), findsNothing);
      expect(find.byKey(const ValueKey('postImage.excluded')), findsNothing, reason: '公開範囲で外した数には数えない');
      c.read(overlayManagerProvider).close(postImageFowId);
      await tester.pumpAndSettle();

      final recent = await tester.runAsync(() => recentActionCandidates(ref));
      expect([for (final cand in recent!) ...cand.posts.map((p) => p.id)], isNot(contains('p1')));
      expect([for (final cand in recent) ...cand.posts.map((p) => p.id)], contains('p2'));
      final clips = await tester.runAsync(() => clipCandidates(ref));
      for (final cand in clips!) {
        expect(cand.posts.map((p) => p.id), isNot(contains('p1')));
        expect(cand.example.text, isNot(contains('ホラー')));
      }
    });

    testWidgets('RAi の読み取り: 見せない投稿はモデルへ渡さない。投稿 1 件 / スレッドは詳細と同じく止める', (tester) async {
      final c = await pump(tester, denied, posts: [post('p1', 'ホラー映画を見た'), post('p2', '花火を見た'), post('p3', '宿題')]);
      final runner = RaiFunctionRunner(c.read(_refProvider));
      for (final fn in ['timeline.list', 'favorites.list', 'reacted.list', 'posts.fetch', 'clips.notes']) {
        final r = await runner.run(RaiFunctionCall(name: fn, args: const {'clip': 'c1', 'limit': '10'}));
        expect(r.text, isNot(contains('ホラー')), reason: fn);
      }
      final one = await runner.run(const RaiFunctionCall(name: 'post.get', args: {'id': 'p1'}));
      expect(one.ok, isFalse);
      expect(one.text, isNot(contains('ホラー')));
      final thread = await runner.run(const RaiFunctionCall(name: 'post.thread', args: {'post': 'p2'}));
      expect(thread.text, contains('花火'));
      expect(thread.text, isNot(contains('ホラー')));
      final ok = await runner.run(const RaiFunctionCall(name: 'post.get', args: {'id': 'p2'}));
      expect(ok.text, contains('花火'));
    });
  });
}

final _refProvider = Provider<Ref>((ref) => ref);
