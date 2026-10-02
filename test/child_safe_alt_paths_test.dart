import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/rasq_collections_api.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart' show childGateProvider;
import 'package:rasq_client/features/collections/rasq_collection_screen.dart';
import 'package:rasq_client/features/post/thread_section.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/relational/relational_event_screen.dart';
import 'package:rasq_client/features/relational/relational_providers.dart';
import 'package:rasq_client/features/relational/relational_timeline_view.dart';
import 'package:rasq_client/features/trend/example_match.dart';
import 'package:rasq_client/features/users/user_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/child_safe_fakes.dart';
import 'support/fakes.dart';

/// D-407 (セキュリティ指摘 #26 / #27): ホーム以外の表示経路(関連 TL のゲスト / ほかのアカウントのホーム、会話イベントの
/// カード / ページ、RASQ リスト / クリップ、引用 / 返信、プロフィール)にも、保護者の表示制限を同じに掛ける。
/// 方針は v2(止める話題「ホラー」、12 時 = 見守りの時間の外)。
const acc = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'kid');

Post post(String id, String body, {String author = 'alice', int minute = 0, Post? quote}) => Post(
      id: id,
      account: acc,
      author: UserSummary(id: author, account: acc, displayName: author),
      createdAt: DateTime(2026, 9, 24, 12, minute),
      body: body,
      quote: quote,
    );

ChildGate gateOf(Map<String, Object?> settings) => ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy.fromJson(settings)), now: DateTime(2026, 9, 24, 12));

/// テストの中で保護者の方針を変えられるように。
class _Gate extends Notifier<ChildGate> {
  _Gate(this.initial);
  final ChildGate initial;
  @override
  ChildGate build() => initial;
  void set(ChildGate g) => state = g;
}

void main() {
  final denied = gateOf(v2());

  test('会話イベント: ROOT が見せないものならイベントごと、ほかの見せない投稿は外す', () {
    final e = ConversationEvent.root(post('1', '打ち上げの話 #打上げ'));
    e.add(post('2', 'ホラー映画を見た #打上げ', author: 'guest', minute: 1));
    e.add(post('3', '打ち上げ楽しかった #打上げ', author: 'bob', minute: 2));
    expect([for (final p in childSafeEventPosts(denied, e)!) p.id], ['1', '3']);
    expect(eventMembersOf(childSafeEventPosts(denied, e)!).map((u) => u.id), ['alice', 'bob']);
    expect(childSafeEventPosts(ChildGate.off, e), hasLength(3));
    final horrorRoot = ConversationEvent.root(post('9', 'ホラー映画まとめ'));
    horrorRoot.add(post('10', 'いいね', minute: 1));
    expect(childSafeEventPosts(denied, horrorRoot), isNull);
  });

  testWidgets('会話イベントのページ / カード: 見せない投稿・ヘッダー・メンバーを出さず、開いている間に方針が変わっても掛け直す', (tester) async {
    final gate = NotifierProvider<_Gate, ChildGate>(() => _Gate(ChildGate.off));
    final e = ConversationEvent.root(post('1', '打ち上げの話 #打上げ'));
    e.add(post('2', 'ホラー映画を見た #打上げ', author: 'guest', minute: 1));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage()), childGateProvider.overrideWith((ref) => ref.watch(gate))],
      child: MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: ListView(children: [RelationalEventCard(event: e), SizedBox(height: 600, child: RelationalEventScreen(event: e))]))),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('ホラー映画を見た'), findsOneWidget);
    expect(find.text('alice+1人'), findsWidgets);
    // 開いたまま見守りが始まる → ホラーの投稿・ゲスト(メンバー)が消える。
    ProviderScope.containerOf(tester.element(find.byType(RelationalEventScreen))).read(gate.notifier).set(denied);
    await tester.pumpAndSettle();
    expect(find.textContaining('ホラー'), findsNothing);
    expect(find.text('alice+1人'), findsNothing);
    expect(find.text('1件 ・ 1人'), findsOneWidget);
    // ROOT が止める話題 → ページごと出さない。カードも出さない。
    final h = ConversationEvent.root(post('9', 'ホラー映画まとめ'));
    h.add(post('10', '打ち上げ', minute: 1));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage()), childGateProvider.overrideWithValue(denied)],
      child: MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: ListView(children: [RelationalEventCard(event: h), SizedBox(height: 600, child: RelationalEventScreen(event: h))]))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('childSafe.eventHidden')), findsOneWidget);
    expect(find.textContaining('ホラー'), findsNothing);
  });

  group('供給源', () {
    Future<ProviderContainer> pump(WidgetTester tester, List<Post> Function(AccountId viewer) posts, {List<AccountId> accounts = const [acc]}) async {
      AccountSession session(AccountId a) => AccountSession(account: a, pluginId: 'test.fake', token: 't', createdAt: DateTime(2026), displayName: a.handle);
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [for (final a in accounts) session(a).toJson()], 'current': accounts.first.key}),
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(storage),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: posts))),
          childGateProvider.overrideWithValue(denied),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    testWidgets('ほかのアカウントのホーム(関連 TL のバンドル供給)に入った見せない投稿は外す', (tester) async {
      const second = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'second');
      final c = await pump(tester, (v) => v.handle == 'second' ? [post('s1', 'ホラー映画を見た', author: 'x'), post('s2', '晴れ', author: 'y')] : [post('h1', '打ち上げ')], accounts: const [acc, second]);
      final bundle = await c.read(bundleFolloweePostsProvider.future);
      expect(bundle.map((p) => p.id), isNot(contains('s1')));
      expect(bundle.map((p) => p.id), contains('s2'));
    });

    testWidgets('引用ノート(共有の口)/ プロフィールの投稿一覧も同じ制限', (tester) async {
      final root = post('r', '打ち上げ');
      final c = await pump(tester, (_) => [root, post('q1', 'ホラー映画で引用', author: 'x', quote: root), post('q2', 'いいね', author: 'y', quote: root)]);
      final quotes = await c.read(threadQuotesProvider((id: 'r', account: null)).future);
      expect(quotes.map((p) => p.id), ['q2']);
      final page = await c.read(userPostsProvider((id: 'x', filter: UserPostsFilter.posts, account: null)).future);
      expect(page.items, isEmpty);
    });
  });

  group('RASQ リスト / クリップ', () {
    RasqCollectionDetail detail(String name, List<String> bodies) => RasqCollectionDetail(
          collection: RasqCollection.fromJson({'id': 'c1', 'kind': 'list', 'name': name, 'isPublic': true}),
          posts: [
            for (final (i, b) in bodies.indexed)
              RasqCollectionPost(key: 'k$i', memberKey: 'misskey:misskey.io:u$i', wire: SnsWire.post(post('p$i', b, author: 'u$i'))),
          ],
        );

    test('見せない投稿は外す。見守り中でなければそのまま', () {
      final d = detail('夏の思い出', ['海に行った', 'ホラー映画を見た']);
      expect(childSafeRasqCollection(ChildGate.off, d)!.posts.length, 2);
      expect([for (final p in childSafeRasqCollection(denied, d)!.posts) p.key], ['k0']);
    });

    test('止める例に近い中身(名前 / 投稿)なら開かない(見出し / 話題の目次も出さない)', () {
      const horror = ContentExample(kind: ExampleKind.clip, ref: 'c-h', text: 'ホラー映画のまとめ 心霊 怖い話 呪い');
      final policy = ChildSafePolicy.fromJson({'schema': ChildSafePolicy.schemaV2, 'preset': 'custom', 'allow': {'examples': const ContentExamples(deny: [horror]).toJson()}});
      final g = ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: policy));
      expect(childSafeRasqCollection(g, detail('ホラー映画 心霊まとめ', ['海に行った'])), isNull);
      expect(childSafeRasqCollection(g, detail('夏の思い出', ['ホラー映画 心霊まとめを見た', '呪いのホラー映画を見た', '海に行った'])), isNull);
      expect(childSafeRasqCollection(g, detail('夏の思い出', ['海に行った', 'スイカ割り', '花火大会'])), isNotNull);
    });
  });
}
