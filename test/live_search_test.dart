import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/home/timeline_providers.dart' show resolveNodeFetch;
import 'package:rasq_client/features/nodeprog/node_executor.dart' show withPageQuery;
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_client/features/users/user_page_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/notify/push_fcm.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

class _FakePush implements PushMessaging {
  @override
  Future<String?> token() async => 'fcm-token-1';
  @override
  Stream<String> get tokenRefresh => const Stream.empty();
  @override
  Stream<({String title, String body, Map<String, String> data})> get foreground => const Stream.empty();
  @override
  Stream<Map<String, String>> get opened => const Stream.empty();
}

/// D-449: RASQ 検索のノード / 通知のアイコンからその人のページ / プッシュの端末トークン。
void main() {
  group('RASQ 検索のノード', () {
    test('ワードが空ならこのページのワード。取得は Central の検索(フォローしていない人も)。アカウントで包まない', () async {
      expect(withPageQuery(rasqSearchKindPrefix, '花火'), '$rasqSearchKindPrefix花火');
      expect(withPageQuery('$rasqSearchKindPrefix月見', '花火'), '$rasqSearchKindPrefix月見');
      const s = TlSourceComponent(tl: '$rasqSearchKindPrefix花火');
      expect((s.isRasqSearch, s.rasqSearchWord), (true, '花火'));
      final g = compileTlConfig(const TlConfig(sources: [s]), scope: 'tl.home');
      expect(g.nodes.where((n) => n.type == 'tl.source').single.inputs.firstWhere((i) => i.label == 'TL').value, '$rasqSearchKindPrefix花火');
      final session = (PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))).session(fakeSession());
      final asked = <String>[];
      final author = UserSummary(id: 'rasq:x', account: const AccountId(kind: SnsKind.other, instance: 'rasq', handle: 'x'), displayName: 'x');
      final got = await resolveNodeFetch(session, '$rasqSearchKindPrefix花火', rasqSearch: (q, until) async {
        asked.add(q);
        return ([Post(id: 'r1', account: author.account, author: author, createdAt: DateTime(2026, 10, 6), body: '花火を見た')], null);
      });
      expect(asked, ['花火']);
      expect(got.single.id, 'r1');
      expect(await resolveNodeFetch(session, rasqSearchKindPrefix, rasqSearch: (q, u) async => throw StateError('呼ばない')), isEmpty, reason: 'ワードが無ければ取らない');
    });
  });

  test('プッシュの端末トークン: FCM が使えればその登録トークン、無ければダミー', () async {
    expect(await pushTokenFor(_FakePush()), 'fcm-token-1');
    expect(await pushTokenFor(null), startsWith('dummy:'));
    expect(fcmOptionsFromEnvironment(), isNull, reason: 'dart-define が無ければ使わない');
  });

  testWidgets('通知のアイコンを押すと、その人のページへ', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline)))],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).go(Routes.notifications);
    await tester.pumpAndSettle();
    final avatar = find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('notif.avatar.'));
    expect(avatar, findsWidgets);
    await tester.tap(avatar.first);
    await tester.pumpAndSettle();
    expect(find.byType(UserPageScreen), findsOneWidget);
  });
}
