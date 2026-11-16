import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/onboarding/server_signup.dart';
import 'package:rasq_client/features/onboarding/sns_discover_screen.dart';
import 'package:rasq_client/features/rai/rai_chat.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';

// オンボーディングの RAi (D-558): 登録ページの「RAi の案内」はタブレットで右の枠に RAi、
// 「RAi に聞く」は RAi ホームと同じページの組み([RaiChatFrame])。

Future<ProviderContainer> _pump(WidgetTester tester, Widget home, {required Size size, List<Override> overrides = const []}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  late ProviderContainer c;
  await tester.pumpWidget(ProviderScope(
    overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), ...overrides],
    child: Consumer(builder: (context, ref, _) {
      c = ProviderScope.containerOf(context);
      return MaterialApp(home: home);
    }),
  ));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  const target = ServerSignupTarget(host: 'misskey.io', kind: SnsKind.misskey, software: 'misskey', name: 'Misskey.io');
  final web = signupWebAreaProvider.overrideWithValue((context, url, hooks) => Center(child: Text('fake web: $url')));

  testWidgets('登録ページ: タブレットでは右の枠に RAi が立ち、その下に案内', (tester) async {
    final c = await _pump(tester, const ServerSignupScreen(), size: const Size(1280, 900), overrides: [web]);
    c.read(serverSignupTargetProvider.notifier).set(target);
    await tester.pumpAndSettle();
    final rai = find.byKey(const ValueKey('signup.rai'));
    expect(rai, findsOneWidget);
    expect(tester.widget(rai), isA<RaiMascot>());
    final raiRect = tester.getRect(rai);
    final guide = tester.getRect(find.byKey(const ValueKey('signup.guide')));
    final webRect = tester.getRect(find.textContaining('fake web'));
    expect(raiRect.left, greaterThan(webRect.right), reason: '右の枠');
    expect(guide.top, greaterThan(raiRect.bottom - 1), reason: '案内は RAi の下');
    expect(raiRect.width, greaterThanOrEqualTo(96));
  });

  testWidgets('登録ページ: 電話の幅では RAi を立たせない(案内だけ、上に)', (tester) async {
    final c = await _pump(tester, const ServerSignupScreen(), size: const Size(400, 860), overrides: [web]);
    c.read(serverSignupTargetProvider.notifier).set(target);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('signup.rai')), findsNothing);
    expect(find.byKey(const ValueKey('signup.guide')), findsOneWidget);
  });

  testWidgets('「RAi に聞く」は RAi ホームと同じページの組み: 列の奥に薄い RAi、空のときは共通の見出し', (tester) async {
    await _pump(tester, const DiscoverAskScreen(), size: const Size(1280, 900));
    expect(find.byType(RaiChatFrame), findsOneWidget);
    expect(find.byType(RaiChatEmptyView), findsOneWidget);
    final mascot = find.byKey(const ValueKey('discover.ask.mascot'));
    expect(mascot, findsOneWidget);
    expect(tester.widget<RaiMascot>(mascot).opacity, 0.35);
    // 列の幅は RAi ホームと同じ(1280 幅なら 600 + 680 / 2 = 940)、RAi はその真ん中。
    final frame = tester.getRect(find.byType(RaiChatFrame).first);
    final input = tester.getRect(find.byKey(const ValueKey('discover.ask.input')));
    expect(input.width, lessThanOrEqualTo(940));
    expect(tester.getCenter(mascot).dx, closeTo(frame.center.dx, 1));
    // 大きさも RAi ホームと同じ決め方。
    expect(tester.getSize(mascot).width, closeTo(RaiChatFrame.standbySizeOf(940, const Size(1280, 900)), 1));
  });
}
