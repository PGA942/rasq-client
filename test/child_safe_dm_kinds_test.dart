import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/rai/rai_functions.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 見守り (セキュリティ確認 2026-10-09 の [21]): DM を止めていれば、DM / チャットの TL はどの口からも取らない。
void main() {
  final me = fakeSession();
  const alice = UserSummary(id: 'alice', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  final posts = [Post(id: 'd1', account: me.account, author: alice, createdAt: DateTime(2026, 10, 9, 10), body: 'ないしょの話', visibility: 'specified')];

  ChildGate kid({bool dm = false}) => ChildGate(
        state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy(allow: ChildSafeAllow(features: {'dm': dm}))),
        now: DateTime(2026, 10, 9, 12),
      );

  test('関所: dm: / chat:(acct: で包んでも)は DM を止めていれば取らない。ほかの TL は通す', () {
    for (final k in ['dm:alice', 'chat:alice', ' dm:alice', 'acct:@tester@example.test|dm:alice', 'acct:@a@x|acct:@b@y|chat:z']) {
      expect(ChildGate.isDirectTimelineKind(k), isTrue, reason: k);
      expect(kid().timelineKindBlockReason(k), isNotNull, reason: k);
      expect(kid(dm: true).timelineKindBlockReason(k), isNull, reason: k);
      expect(ChildGate.off.timelineKindBlockReason(k), isNull, reason: k);
    }
    for (final k in ['home', 'list:dm', 'search:dm:alice', 'tag:chat', 'acct:@tester@example.test|home']) {
      expect(kid().timelineKindBlockReason(k), isNull, reason: k);
    }
  });

  test('取得ノード (tl.dm など): resolveNodeFetch は止めた kind を取りに行かない(acct: で包んでも)', () async {
    final session = FakeSnsSession(me, posts);
    expect(await resolveNodeFetch(session, 'dm:alice'), isNotEmpty, reason: '止めていなければ今までどおり');
    for (final k in ['dm:alice', 'chat:alice', 'acct:@tester@example.test|dm:alice']) {
      final before = session.timelineFetches;
      expect(await resolveNodeFetch(session, k, sessionFor: (_) => session, kindBlocked: childKindBlocked(kid())), isEmpty, reason: k);
      expect(session.timelineFetches, before, reason: '$k: 取りに行かない');
    }
    expect(await resolveNodeFetch(session, 'home', kindBlocked: childKindBlocked(kid())), isNotEmpty, reason: 'ほかの TL は通す');
  });

  test('RAi の timeline.list: kind=dm: / chat: は DM を止めていれば取らない', () async {
    final runner = Provider((ref) => RaiFunctionRunner(ref));
    final c = ProviderContainer(overrides: [childGateProvider.overrideWithValue(kid())]);
    addTearDown(c.dispose);
    for (final k in ['dm:alice', 'chat:alice', 'acct:@tester@example.test|dm:alice']) {
      final r = await c.read(runner).run(RaiFunctionCall(name: 'timeline.list', args: {'kind': k}));
      expect(r.ok, isFalse, reason: k);
      expect(r.text, contains(childSafeBlockedText), reason: k);
    }
  });

  test('TL の口 (timelineProvider): DM / チャットの TL は、DM を止めていれば取りに行かず空', () async {
    for (final (allowed, expected) in [(false, isEmpty), (true, isNotEmpty)]) {
      final plugin = FakeSnsPlugin(posts: (_) => posts);
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({
          SessionsNotifier.storageKey: jsonEncode({'sessions': [me.toJson()], 'current': me.account.key}),
        })),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)),
        childGateProvider.overrideWithValue(kid(dm: allowed)),
      ]);
      addTearDown(c.dispose);
      await c.read(sessionsProvider.future);
      final s = await c.read(timelineProvider(DynamicTimelines.dm('alice')).future);
      expect(s.posts, expected, reason: 'dm allowed=$allowed');
    }
  });
}
