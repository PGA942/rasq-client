import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
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
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart' show childGateProvider;
import 'package:rasq_client/features/login/sns_login_screen.dart';
import 'package:rasq_client/features/login/sns_signup.dart';
import 'package:rasq_client/features/onboarding/feature_tour.dart';
import 'package:rasq_client/features/onboarding/feature_tour_screen.dart';
import 'package:rasq_client/features/onboarding/server_signup.dart';
import 'package:rasq_client/features/settings/settings_section_screen.dart';
import 'package:rasq_client/features/trend/tendency_profile.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart' show RasqRadarChart;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart' show MisskeyPlugin;

import 'support/child_safe_fakes.dart';
import 'support/fakes.dart';

/// RASQ の機能の紹介 (D-471): 入れてから最初のログインのあとだけ / 初めては「スキップ」なし / 見たことがあれば「スキップ」/
/// 「いま設定を見る」/ 見守り中のページ / 「{SNS}でログイン」の「新規登録」/ 設定からもう一度。
void main() {
  const me = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'newbie');
  AuthResult result([AccountId a = me, String pluginId = MisskeyPlugin.pluginId]) => AuthResult(
        session: AccountSession(account: a, pluginId: pluginId, token: 't', createdAt: DateTime(2026, 10, 13), displayName: a.handle),
        me: UserSummary(id: 'u-${a.handle}', account: a, displayName: a.handle),
      );
  String sessionsJson(AccountSession s) => jsonEncode({'sessions': [s.toJson()], 'current': s.account.key});

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required MemorySessionStorage storage,
    bool? fresh = true,
    Size size = const Size(420, 900),
    List<Override> overrides = const [],
    List<SnsPlugin>? plugins,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final registry = PluginRegistry();
    for (final p in plugins ?? [FakeSnsPlugin(id: MisskeyPlugin.pluginId, posts: (_) => const [])]) {
      registry.register(p);
    }
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        featureTourInstallMarkerProvider.overrideWithValue(_Marker(fresh)),
        signupWebAreaProvider.overrideWithValue((context, url, hooks) => Center(child: Text('fake web: $url'))),
        ...overrides,
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<void> login(WidgetTester tester, ProviderContainer c, [AuthResult? r]) async {
    await c.read(sessionsProvider.notifier).add(r ?? result());
    c.read(routerProvider).go(Routes.home);
    await tester.pumpAndSettle();
  }

  Future<FeatureTourDevice> device(MemorySessionStorage s) async => FeatureTourDevice.parse(await s.read(featureTourDeviceKey));

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('tour.next')));
    await tester.pumpAndSettle();
  }

  group('いつ出すか', () {
    testWidgets('入れて最初のログインのあと: 「スキップ」なしで出る。次へ / 戻る、端末の戻るでは閉じない、最後の「はじめる」で閉じて印を残す', (tester) async {
      final storage = MemorySessionStorage();
      final c = await pump(tester, storage: storage);
      expect((await device(storage)).pending, isTrue, reason: '入れて最初の起動(まだログインしていない)で立てる');
      expect(find.byType(FeatureTourScreen), findsNothing, reason: 'ログインの前には出さない');
      await login(tester, c);
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('tour.skip')), findsNothing, reason: '初めて見る人にはスキップを出さない');
      expect(find.byKey(const ValueKey('tour.title.sns')), findsOneWidget);
      expect(find.byKey(const ValueKey('tour.back')), findsNothing);
      // 端末の戻る: 最初のページでは閉じない。
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      await next(tester);
      expect(find.byKey(const ValueKey('tour.title.timeline')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour.back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tour.title.sns')), findsOneWidget);
      final titles = <String>[];
      for (var i = 0; i < 7; i++) {
        titles.add(tester.widget<Text>(find.descendant(of: find.byType(PageView), matching: find.byWidgetPredicate((w) => w is Text && (w.key as ValueKey?)?.value.toString().startsWith('tour.title.') == true))).data!);
        if (i < 6) await next(tester);
      }
      expect(titles, ['いくつもの SNS を、ひとつの場所で', 'タイムラインは、ノードで組み立てる', 'トレンドと Today', 'ASTell で、声でつながる', 'Swing で、気軽に流す', '迷ったら RAi に', 'プラグインで、広げる']);
      expect(find.text('はじめる'), findsOneWidget);
      await next(tester);
      expect(find.byType(FeatureTourScreen), findsNothing);
      final d = await device(storage);
      expect((d.pending, d.seen), (false, featureTourVersion));
    });

    testWidgets('同じ端末の 2 回目以降のログインでは出さない(起動し直しても)', (tester) async {
      final storage = MemorySessionStorage({featureTourDeviceKey: const FeatureTourDevice(seen: 1).encode()});
      var c = await pump(tester, storage: storage, fresh: false);
      await login(tester, c);
      expect(find.byType(FeatureTourScreen), findsNothing);
      // 起動し直し(ログインしたまま)。
      await tester.pumpWidget(const SizedBox());
      c = await pump(tester, storage: storage, fresh: false);
      expect(find.byType(FeatureTourScreen), findsNothing);
      expect((await device(storage)).pending, isFalse);
    });

    testWidgets('前の版から上げた(入れて最初の起動だが、もうログインしている)ときは立てない', (tester) async {
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: sessionsJson(result().session)});
      await pump(tester, storage: storage);
      expect(find.byType(FeatureTourScreen), findsNothing);
      expect((await device(storage)).pending, isFalse);
    });

    testWidgets('入れ直し(端末の印が残っていて、前に見た): 最初のログインのあとに「スキップ」つきで出る → スキップで閉じる', (tester) async {
      final storage = MemorySessionStorage({featureTourDeviceKey: const FeatureTourDevice(seen: 1).encode()});
      final c = await pump(tester, storage: storage);
      expect((await device(storage)).pending, isTrue);
      await login(tester, c);
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour.skip')));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourScreen), findsNothing);
      expect((await device(storage)).pending, isFalse);
    });

    testWidgets('SNS の新規登録のオンボーディング(登録ページ → ログイン → RASQ アカウントのポップアップ)が済んでから出る', (tester) async {
      // ブラウザを開く口(MiAuth の URL)は開けたことにする。
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async => true);
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null));
      final storage = MemorySessionStorage();
      final c = await pump(tester, storage: storage, plugins: [_SignupPlugin()]);
      c.read(routerProvider).go(Routes.login);
      await tester.pumpAndSettle();
      c.read(routerProvider).push(Routes.loginMisskey);
      await tester.pumpAndSettle();
      // 「Misskeyでログイン」の画面の「新規登録」→ D-412 の登録ページ(RAi の案内つき)。
      await tester.ensureVisible(find.byKey(const ValueKey('login.signup')));
      await tester.tap(find.byKey(const ValueKey('login.signup')));
      await tester.pumpAndSettle();
      expect(find.byType(ServerSignupScreen), findsOneWidget);
      final t = c.read(serverSignupTargetProvider)!;
      expect((t.host, t.kind, t.signupUrl.toString()), ('misskey.io', SnsKind.misskey, 'https://misskey.io/'));
      // 「登録できた」→ このサーバーのログイン(サーバーは確かめ済み)→ 認証。
      await tester.tap(find.byKey(const ValueKey('signup.done')));
      await tester.pumpAndSettle();
      expect(find.byType(SnsLoginScreen), findsOneWidget);
      await tester.tap(find.text('ブラウザで認証する (MiAuth)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('認証を確認'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // ポップアップ (D-413) が先。閉じるまでツアーは待つ。
      final manager = c.read(overlayManagerProvider);
      expect(manager.contains('onboarding.rasqAccount'), isTrue);
      expect(find.byType(FeatureTourScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('rasqNudge.later')));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('tour.skip')), findsNothing);
    });

    testWidgets('待たせている間(登録のあとの流れ)は出さず、終わったら出す', (tester) async {
      final storage = MemorySessionStorage();
      final c = await pump(tester, storage: storage);
      c.read(featureTourHoldsProvider.notifier).hold(featureTourHoldSignup);
      await login(tester, c);
      expect(find.byType(FeatureTourScreen), findsNothing);
      c.read(featureTourHoldsProvider.notifier).release(featureTourHoldSignup);
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourScreen), findsOneWidget);
    });
  });

  group('中身', () {
    MemorySessionStorage pendingWithSession() => MemorySessionStorage({
          SessionsNotifier.storageKey: sessionsJson(result().session),
          featureTourDeviceKey: const FeatureTourDevice(pending: true).encode(),
        });

    testWidgets('「トレンドと Today」: 既定の刺激性(恐れ / 嫌悪 / 怒り 45%)のレーダー、「いま設定を見る」で設定を開き、閉じると同じページに戻る', (tester) async {
      final c = await pump(tester, storage: pendingWithSession(), fresh: false);
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      await next(tester);
      await next(tester);
      expect(find.byKey(const ValueKey('tour.title.trend')), findsOneWidget);
      expect(find.textContaining('恐れ・嫌悪・怒りを 45% までに抑えている'), findsOneWidget);
      final radar = tester.widget<RasqRadarChart>(find.byKey(const ValueKey('tour.radar')));
      expect((radar.values['fear'], radar.values['disgust'], radar.values['anger'], radar.values['joy']), (0.45, 0.45, 0.45, 1.0));
      expect(radar.onChanged, isNull, reason: '絵なので触れない');
      await tester.tap(find.byKey(const ValueKey('tour.openTendency')));
      await tester.pumpAndSettle();
      final manager = c.read(overlayManagerProvider);
      expect(manager.contains('trend.tendency'), isTrue);
      expect(find.byKey(const Key('trend.tendency.stimulus')), findsOneWidget);
      manager.close('trend.tendency');
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('tour.title.trend')), findsOneWidget);
      expect(TendencyProfile.defaultStimulus['anger'], 0.45);
    });

    testWidgets('見守り中: ASTell(止めている)/ Swing / ストア(止めている)のページを外し、刺激性のページに一言足す', (tester) async {
      final gate = ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy.fromJson(v2())), now: DateTime(2026, 9, 24, 12));
      expect([for (final p in featureTourPages(gate)) p.id], ['sns', 'timeline', 'trend', 'rai']);
      expect([for (final p in featureTourPages(ChildGate.off)) p.id], ['sns', 'timeline', 'trend', 'astell', 'swing', 'rai', 'plugins']);
      final noRai = ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy.fromJson({...v2(), 'allow': {...(v2()['allow']! as Map), 'rai': {'enabled': false}}})), now: DateTime(2026, 9, 24, 12));
      expect([for (final p in featureTourPages(noRai)) p.id], isNot(contains('rai')));
      await pump(tester, storage: pendingWithSession(), fresh: false, overrides: [childGateProvider.overrideWithValue(gate)]);
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      await next(tester);
      await next(tester);
      expect(find.textContaining('見守り中は、保護者の設定でさらに抑えます'), findsOneWidget);
      await next(tester);
      expect(find.byKey(const ValueKey('tour.title.rai')), findsOneWidget);
      expect(find.text('はじめる'), findsOneWidget);
    });

    testWidgets('タブレット(幅 840 以上)は絵と文を横に並べる / 大きな文字でもはみ出さない', (tester) async {
      await pump(tester, storage: pendingWithSession(), fresh: false, size: const Size(1280, 800));
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      final pic = tester.getCenter(find.byKey(const ValueKey('tour.title.sns')));
      final logo = tester.getCenter(find.bySemanticsLabel(RegExp('RASQ にまとまる絵')));
      expect(logo.dx, lessThan(pic.dx), reason: '絵が左、文が右');
      await tester.pumpWidget(const SizedBox());
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pump(tester, storage: pendingWithSession(), fresh: false, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      expect(find.byType(FeatureTourScreen), findsOneWidget);
    });

    testWidgets('読み上げ: ページの番号・見出し・絵の説明・ボタン', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, storage: pendingWithSession(), fresh: false);
      expect(find.bySemanticsLabel('1 / 7 ページ'), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('RASQ にまとまる絵')), findsOneWidget);
      expect(tester.getSemantics(find.text('いくつもの SNS を、ひとつの場所で')), matchesSemantics(label: 'いくつもの SNS を、ひとつの場所で', isHeader: true));
      expect(find.bySemanticsLabel('次へ'), findsOneWidget);
      handle.dispose();
    });
  });

  group('「{SNS}でログイン」の「新規登録」', () {
    testWidgets('Mastodon: そのサーバーの /auth/sign_up(D-412 の登録ページ)', (tester) async {
      final c = await pump(tester, storage: MemorySessionStorage(), plugins: [FakeSnsPlugin(id: mastodonPluginId, kind: SnsKind.mastodon, posts: (_) => const [])]);
      c.read(routerProvider).go('${Routes.loginMastodon}?host=mstdn.jp');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('login.signup')));
      await tester.tap(find.byKey(const ValueKey('login.signup')));
      await tester.pumpAndSettle();
      expect(find.byType(ServerSignupScreen), findsOneWidget);
      final t = c.read(serverSignupTargetProvider)!;
      expect((t.host, t.kind, t.signupUrl.toString()), ('mstdn.jp', SnsKind.mastodon, 'https://mstdn.jp/auth/sign_up'));
      expect(find.text('fake web: https://mstdn.jp/auth/sign_up'), findsOneWidget);
    });

    for (final (route, url, hint) in [
      (Routes.loginBluesky, 'https://bsky.app/', 'アプリパスワード'),
      (Routes.loginMixi2, 'https://mixi.social/', 'ブラウザで認証'),
    ]) {
      testWidgets('$route: 外部のブラウザで登録ページ($url)→ 戻ったらログインの手順', (tester) async {
        final opened = <Uri>[];
        final c = await pump(tester, storage: MemorySessionStorage(), overrides: [
          snsSignupLauncherProvider.overrideWithValue((u) async {
            opened.add(u);
            return true;
          }),
        ]);
        c.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('login.signup.hint')), findsNothing);
        await tester.ensureVisible(find.byKey(const ValueKey('login.signup')));
        await tester.tap(find.byKey(const ValueKey('login.signup')));
        await tester.pumpAndSettle();
        expect(opened.map((u) => '$u'), [url]);
        expect(find.byKey(const ValueKey('login.signup.hint')), findsOneWidget);
        expect(find.descendant(of: find.byKey(const ValueKey('login.signup.hint')), matching: find.textContaining(hint)), findsOneWidget);
      });
    }

    test('登録ページの URL', () {
      expect(snsSignupPageUrl(SnsKind.mastodon, 'https://Mastodon.Social/about').toString(), 'https://mastodon.social/auth/sign_up');
      expect(snsSignupPageUrl(SnsKind.misskey, 'misskey.io').toString(), 'https://misskey.io/');
      expect(snsSignupPageUrl(SnsKind.bluesky, 'bsky.social').toString(), 'https://bsky.app/');
    });
  });

  group('もう一度見る / 印', () {
    testWidgets('設定 → RASQ について「RASQ の使い方をもう一度見る」: スキップつきで開き、閉じると設定に戻る', (tester) async {
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: sessionsJson(result().session), featureTourDeviceKey: const FeatureTourDevice(seen: 1).encode()});
      final c = await pump(tester, storage: storage, fresh: false);
      expect(find.byType(FeatureTourScreen), findsNothing);
      c.read(routerProvider).push('/settings/section/about');
      await tester.pumpAndSettle();
      await tester.tap(find.text('RASQ の使い方をもう一度見る'));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tour.skip')));
      await tester.pumpAndSettle();
      expect(find.byType(FeatureTourScreen), findsNothing);
      expect(find.byType(SettingsSectionScreen), findsOneWidget);
    });

    test('出すか / スキップを出すか(版)', () {
      expect(featureTourShouldShow(const FeatureTourDevice(pending: true)), isTrue);
      expect(featureTourShouldShow(const FeatureTourDevice()), isFalse);
      expect(featureTourShouldShow(const FeatureTourDevice(seen: featureTourVersion)), isFalse);
      expect(featureTourShouldShow(const FeatureTourDevice(seen: featureTourVersion), accountSeen: featureTourVersion + 1), isFalse);
      expect(featureTourCanSkip(const FeatureTourDevice(pending: true)), isFalse);
      expect(featureTourCanSkip(const FeatureTourDevice(pending: true), accountSeen: 1), isTrue, reason: 'ほかの端末で見た');
      expect(featureTourCanSkip(const FeatureTourDevice(pending: true, seen: 1)), isTrue);
      expect(featureTourLocation(), Routes.featureTour);
      expect(featureTourLocation(skip: true), '${Routes.featureTour}?skip=1');
      expect(featureTourLocation(again: true), '${Routes.featureTour}?again=1');
    });

    test('RASQ アカウントの印(ユーザーデータ同期 /me/data/onboarding.tour.v1): 読む / 見終えたら書く(下げない)', () async {
      final puts = <String>[];
      var stored = <String, Object?>{};
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/me/data/$featureTourDataArea')) {
          if (req.method == 'PUT') {
            puts.add(req.body);
            stored = (jsonDecode(req.body) as Map).cast<String, Object?>();
            return http.Response('', 204, headers: {'etag': '"2"'});
          }
          return stored.isEmpty ? http.Response('', 404) : http.Response(jsonEncode(stored), 200, headers: {'etag': '"1"'});
        }
        return http.Response('[]', 200);
      });
      final storage = MemorySessionStorage();
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        featureTourInstallMarkerProvider.overrideWithValue(const _Marker(false)),
        orgateClientProvider.overrideWithValue(OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client, tokenProvider: () => 'tok')),
        orgateAccountProvider.overrideWith(_SignedIn.new),
      ]);
      addTearDown(c.dispose);
      await c.read(featureTourProvider.future);
      final n = c.read(featureTourProvider.notifier);
      expect(await n.accountSeen(), 0);
      await n.markSeen();
      expect(puts, hasLength(1));
      expect((jsonDecode(puts.single) as Map)['seenVersion'], featureTourVersion);
      expect(await n.accountSeen(), featureTourVersion);
      await n.markSeen();
      expect(puts, hasLength(1), reason: '同じ版ならもう書かない');
      expect((await device(storage)).seen, featureTourVersion);
    });

    test('RASQ アカウントが無ければ読まない(null)', () async {
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        featureTourInstallMarkerProvider.overrideWithValue(const _Marker(null)),
        orgateClientProvider.overrideWithValue(null),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(featureTourProvider.future), isA<FeatureTourDevice>().having((d) => d.pending, 'pending', isFalse));
      expect(await c.read(featureTourProvider.notifier).accountSeen(), isNull);
    });
  });
}

class _Marker implements FeatureTourInstallMarker {
  const _Marker(this.fresh);
  final bool? fresh;
  @override
  Future<bool?> checkAndMark(SessionStorage storage) async => fresh;
}

class _SignedIn extends OrgateAccountNotifier {
  @override
  Future<RasqAccount?> build() async => RasqAccount.fromJson(const {'id': 'acc-1', 'handle': 'neko', 'displayName': 'ねこ'});
}

/// 新規登録 → ログインの流れの SNS(Misskey の役)。
class _SignupPlugin extends FakeSnsPlugin {
  _SignupPlugin() : super(id: MisskeyPlugin.pluginId, posts: (_) => const []);
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) async => _Flow();
}

class _Flow extends BrowserAuthFlow {
  @override
  Uri get url => Uri.parse('https://misskey.io/miauth/x');
  @override
  String get hint => '';
  @override
  Future<AuthResult> complete() async => AuthResult(
        session: AccountSession(account: const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'newbie'), pluginId: MisskeyPlugin.pluginId, token: 't', createdAt: DateTime(2026, 10, 13), displayName: 'newbie'),
        me: const UserSummary(id: 'u-newbie', account: AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'newbie'), displayName: 'newbie'),
      );
}
