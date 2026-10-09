import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/compose/compose_target.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 見守り中のコンポーザーの送る前の判定(セキュリティ確認 2026-10-09)。
void main() {
  final me = fakeSession();
  const alice = UserSummary(id: 'alice', account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'alice'), displayName: 'アリス');
  Post post(String id, {String? visibility}) => Post(id: id, account: me.account, author: alice, createdAt: DateTime(2026, 10, 9, 10), body: 'もとの投稿', visibility: visibility);

  ChildGate kid({Map<String, bool>? features, ChildSafeComposer composer = const ChildSafeComposer()}) => ChildGate(
        state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy(composer: composer, allow: ChildSafeAllow(features: features))),
        now: DateTime(2026, 10, 9, 12),
      );

  Future<(ProviderContainer, FakeSnsSession)> pumpApp(WidgetTester tester, ChildGate gate, {Map<String, String> storage = const {}}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p1')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({
          SessionsNotifier.storageKey: jsonEncode({'sessions': [me.toJson()], 'current': me.account.key}),
          ...storage,
        })),
        pluginRegistryProvider.overrideWithValue(registry),
        childGateProvider.overrideWithValue(gate),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqApp))), registry.session(me) as FakeSnsSession);
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const ValueKey('composer.input')), text);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('composer.send')));
    await tester.pumpAndSettle();
  }

  group('[19] ダイレクト投稿への返信', () {
    testWidgets('DM を止めていれば、ダイレクト投稿への返信(specified + 宛先継承)は送らない。ふつうの返信は送れる', (tester) async {
      final (c, session) = await pumpApp(tester, kid(features: {'dm': false}));
      unawaited(showComposerWith(ComposeReply(post('d1', visibility: 'specified')), manager: c.read(overlayManagerProvider), router: c.read(routerProvider)));
      await tester.pumpAndSettle();
      await send(tester, 'へんじ');
      expect(session.lastDraft, isNull);
      expect(find.textContaining(childSafeBlockedText), findsWidgets);
      c.read(overlayManagerProvider).close(composerFowId);
      await tester.pumpAndSettle();

      unawaited(showComposerWith(ComposeReply(post('p1', visibility: 'public')), manager: c.read(overlayManagerProvider), router: c.read(routerProvider)));
      await tester.pumpAndSettle();
      await send(tester, 'へんじ');
      expect(session.lastDraft?.text, 'へんじ');
      expect(session.lastDraft?.replyToId, 'p1');
    });

    test('判定: direct は DM の機能も要る(本文は投稿として判定)', () async {
      final daily = ChildSafeDaily(MemorySessionStorage({}));
      final now = DateTime(2026, 10, 9, 12);
      final g = kid(features: {'dm': false});
      expect(await childComposeVerdictFor(g, daily, now, text: 'へんじ'), isNull);
      expect((await childComposeVerdictFor(g, daily, now, text: 'へんじ', direct: true))?.message, contains(childSafeBlockedText));
      expect(await childComposeVerdictFor(kid(), daily, now, text: 'へんじ', direct: true), isNull);
    });
  });
}
