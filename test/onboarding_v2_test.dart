import 'dart:convert';
import 'dart:typed_data';

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
import 'package:rasq_client/backend/rasq_account.dart' show orgateTokenHolderProvider;
import 'package:rasq_client/features/child_safe/child_safe_screens.dart' show ChildLoginScreen;
import 'package:rasq_client/features/collections/rasq_collection_screen.dart';
import 'package:rasq_client/features/login/sns_login_screen.dart';
import 'package:rasq_client/features/onboarding/onboarding_feed.dart';
import 'package:rasq_client/features/onboarding/onboarding_screen.dart';
import 'package:rasq_client/features/onboarding/onboarding_steps.dart';
import 'package:rasq_client/features/onboarding/screen_glimpse.dart';
import 'package:rasq_client/features/onboarding/rasq_account_nudge.dart';
import 'package:rasq_client/features/onboarding/server_signup.dart';
import 'package:rasq_client/features/onboarding/signup_pointer.dart';
import 'package:rasq_client/features/onboarding/sns_discover_screen.dart';
import 'package:rasq_client/notify/local_notifier.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 初回オンボーディング v2 (D-414): ①②③ のページ、左カラムの公開 RASQ リストの投稿、探す画面(画像 / 人 / RAi)、結果からの登録、WebView の指差し。
void main() {
  group('① ② ③ のページ', () {
    Future<void> fillStep1(WidgetTester tester, {String handle = 'neko_taro', String age = '18+'}) async {
      await tester.enterText(find.byKey(const ValueKey('onb.handle')), handle);
      await tester.enterText(find.byKey(const ValueKey('onb.password')), 'correct horse');
      await tester.enterText(find.byKey(const ValueKey('onb.passwordConfirm')), 'correct horse');
      await tester.ensureVisible(find.byKey(ValueKey('onb.age.$age')));
      await tester.tap(find.byKey(ValueKey('onb.age.$age')));
      await tester.pumpAndSettle();
    }

    FilledButton next(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const ValueKey('onb.next')));
    FilledButton register(WidgetTester tester) => tester.widget<FilledButton>(find.byKey(const ValueKey('onb.register')));

    testWidgets('① ユーザー名・パスワード・年齢がそろうまで「次へ」は押せない', (tester) async {
      final central = _FakeCentral();
      await _pump(tester, central);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(next(tester).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('onb.handle')), 'ab');
      await tester.pumpAndSettle();
      expect(find.text('3 文字以上にしてください'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('onb.handle')), 'Neko-Taro');
      await tester.pumpAndSettle();
      expect(find.text('半角の英小文字・数字・_ だけ使えます'), findsOneWidget, reason: '大文字は小文字にそろえ、- は使えない');
      await fillStep1(tester);
      expect(next(tester).onPressed, isNotNull);
      await tester.enterText(find.byKey(const ValueKey('onb.passwordConfirm')), 'correct hors');
      await tester.pumpAndSettle();
      expect(find.text('一致しません'), findsOneWidget);
      expect(next(tester).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('onb.password')), 'aaaaaaaaaa');
      await tester.enterText(find.byKey(const ValueKey('onb.passwordConfirm')), 'aaaaaaaaaa');
      await tester.pumpAndSettle();
      expect(find.text('同じ字の繰り返しは使えません'), findsOneWidget);
      expect(next(tester).onPressed, isNull);
      expect(central.calls, isNot(contains('POST /auth/device')));
    });

    testWidgets('② 規約に同意するまで登録できない → 登録(承諾は一緒に)→ ユーザー名 → パスワード → ③ へ。ポップアップ (D-413) は頼まない', (tester) async {
      final central = _FakeCentral();
      final c = await _pump(tester, central);
      await fillStep1(tester);
      await tester.tap(find.byKey(const ValueKey('onb.next')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingTermsScreen), findsOneWidget);
      expect(find.text('2 / 3'), findsOneWidget);
      expect(register(tester).onPressed, isNull);
      expect(find.byKey(const ValueKey('onb.guardian')), findsNothing, reason: '18 歳以上は保護者の同意を聞かない');
      await tester.tap(find.byKey(const ValueKey('onb.agree')));
      await tester.pumpAndSettle();
      expect(register(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('onb.register')));
      await tester.pumpAndSettle();
      expect(central.calls.where((x) => x == 'POST /auth/device').length, 1);
      expect(central.consents?['age'], '18+');
      expect(central.consents?['guardian'], false);
      expect(central.calls.indexOf('PATCH /me'), lessThan(central.calls.indexOf('POST /auth/password')), reason: 'ユーザー名を先に確かめる');
      expect(central.handle, 'neko_taro');
      expect(find.byType(OnboardingSnsScreen), findsOneWidget);
      expect(find.text('3 / 3'), findsOneWidget);
      expect(find.text('Misskeyでログイン'), findsOneWidget);
      expect(find.byKey(const ValueKey('onb.discover')), findsOneWidget);
      final ledger = c.read(rasqAccountsProvider).value!;
      expect(ledger.onboardingDone, isTrue);
      expect(ledger.current?.isCentral, isTrue);
      expect(ledger.current?.handle, 'neko_taro');
      expect(c.read(rasqAccountNudgeProvider), isFalse);
      // 「SNS サービスを探す」→ 探す画面。
      await tester.tap(find.byKey(const ValueKey('onb.discover')));
      await tester.pumpAndSettle();
      expect(find.byType(SnsDiscoverScreen), findsOneWidget);
    });

    testWidgets('② ユーザー名が使われていたら ① に戻って直す → もう一度で登録(アカウントは作り直さない)', (tester) async {
      final central = _FakeCentral(takenHandles: {'taken_name'});
      await _pump(tester, central);
      await fillStep1(tester, handle: 'taken_name');
      await tester.tap(find.byKey(const ValueKey('onb.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onb.agree')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onb.register')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingTermsScreen), findsNothing);
      expect(find.text('このユーザー名はもう使われています'), findsOneWidget);
      expect(central.calls, isNot(contains('POST /auth/password')), reason: '名前が決まるまでパスワードは送らない');
      expect(next(tester).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('onb.handle')), 'free_name');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onb.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onb.agree')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onb.register')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingSnsScreen), findsOneWidget);
      expect(central.calls.where((x) => x == 'POST /auth/device').length, 1);
      expect(central.handle, 'free_name');
    });

    testWidgets('② 18 歳未満: チャイルドセーフの案内と保護者の同意(無いと登録できない)、保護者からのコードでログインもできる', (tester) async {
      final central = _FakeCentral();
      await _pump(tester, central);
      await fillStep1(tester, age: '13-15');
      await tester.tap(find.byKey(const ValueKey('onb.next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('onb.childSafe.note')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onb.agree')));
      await tester.pumpAndSettle();
      expect(register(tester).onPressed, isNull, reason: '保護者の同意がまだ');
      await tester.ensureVisible(find.byKey(const ValueKey('onb.guardian')));
      await tester.tap(find.byKey(const ValueKey('onb.guardian')));
      await tester.pumpAndSettle();
      expect(register(tester).onPressed, isNotNull);
      await tester.ensureVisible(find.byKey(const ValueKey('onb.childLogin')));
      await tester.tap(find.byKey(const ValueKey('onb.childLogin')));
      await tester.pumpAndSettle();
      expect(find.byType(ChildLoginScreen), findsOneWidget);
      expect(central.calls, isNot(contains('POST /auth/device')));
    });

    testWidgets('② 18 歳未満で登録すると、保護者の承諾も送る', (tester) async {
      final central = _FakeCentral();
      await _pump(tester, central);
      await fillStep1(tester, age: '16-17');
      await tester.tap(find.byKey(const ValueKey('onb.next')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onb.agree')));
      await tester.ensureVisible(find.byKey(const ValueKey('onb.guardian')));
      await tester.tap(find.byKey(const ValueKey('onb.guardian')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onb.register')));
      await tester.pumpAndSettle();
      expect(central.consents?['age'], '16-17');
      expect(central.consents?['guardian'], true);
      expect(find.byType(OnboardingSnsScreen), findsOneWidget);
    });
  });

  group('左カラム', () {
    testWidgets('公開 RASQ リストの投稿だけを、リストの名前つきで流す(CW / 返信は端末でも落とす)', (tester) async {
      final central = _FakeCentral();
      await _pump(tester, central, size: const Size(1280, 900));
      expect(find.byType(OnboardingFeedColumn), findsOneWidget);
      expect(central.calls, contains('GET /onboarding/feed?limit=30'));
      expect(find.textContaining('うちの猫が箱から出てこない'), findsOneWidget);
      expect(find.text('リスト「ねこ好きの集まり」'), findsOneWidget);
      expect(find.textContaining('ネタバレ'), findsNothing);
      expect(find.textContaining('それな'), findsNothing);
      expect(find.byKey(const ValueKey('onboarding.previews.servers')), findsNothing, reason: 'サーバーのタイルは出さない');
    });
  });

  group('探す画面', () {
    Future<ProviderContainer> openDiscover(WidgetTester tester, _FakeCentral central, {List<Override> overrides = const [], String? sub}) async {
      final c = await _pump(tester, central, overrides: overrides);
      c.read(routerProvider).push(sub ?? Routes.snsDiscover);
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('入口は 4 つ。外部 SNS のエクスポートは準備中で押せない', (tester) async {
      await openDiscover(tester, _FakeCentral());
      for (final k in ['discover.content', 'discover.people', 'discover.export', 'discover.ask']) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
      expect(find.text('外部 SNS のエクスポートデータから探す'), findsOneWidget);
      expect(find.text('準備中'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover.export')));
      await tester.pumpAndSettle();
      expect(find.byType(SnsDiscoverScreen), findsOneWidget, reason: '押しても進まない');
      await tester.tap(find.byKey(const ValueKey('discover.content')));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverContentScreen), findsOneWidget);
    });

    testWidgets('画像から探す: 選んだ画像を multipart で送り、探す言葉・切り抜き・リスト・サーバーを出す', (tester) async {
      final central = _FakeCentral();
      await openDiscover(tester, central, sub: Routes.snsDiscoverContent, overrides: [
        discoverImagePickerProvider.overrideWithValue(({required bool camera}) async => _png),
      ]);
      await tester.tap(find.byKey(const ValueKey('discover.content.pick')));
      await tester.pumpAndSettle();
      final sent = central.lastContent!;
      expect(sent.contentType, startsWith('multipart/form-data'));
      expect(sent.body, contains('name="image"'));
      expect(sent.body, contains('content-type: image/png'));
      expect(find.byKey(const ValueKey('discover.content.image')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.content.query')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.keyword.猫')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.crop.0')), findsOneWidget, reason: '割合の切り抜きは画像の上に枠');
      expect(find.text('ねこ'), findsWidgets);
      expect(find.byKey(const ValueKey('discover.listHit.list-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.serverHit.misskey.io')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.dummy')), findsOneWidget);
    });

    testWidgets('アプリの中のブラウザで「この画面から探す」: 読み取った本文と URL だけを送る(画面の写しは送らない)', (tester) async {
      final central = _FakeCentral();
      final capturer = _FakeCapturer();
      await openDiscover(tester, central, sub: Routes.snsDiscoverContent, overrides: [
        discoverBrowserProvider.overrideWithValue((context, initial, attach) {
          attach(capturer);
          return Center(child: Text('fake browser: $initial'));
        }),
      ]);
      await tester.tap(find.byKey(const ValueKey('discover.content.browse')));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverBrowseScreen), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('discover.browse.address')), '猫 写真');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pumpAndSettle();
      expect(capturer.loaded.single.queryParameters['q'], '猫 写真');
      await tester.tap(find.byKey(const ValueKey('discover.browse.capture')));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverContentScreen), findsOneWidget);
      final sent = central.lastContent!;
      expect(sent.body, contains('name="text"'));
      expect(sent.body, contains('name="url"'));
      expect(sent.body, contains('https://example.com/cats'));
      expect(sent.body, isNot(contains('name="image"')), reason: '画像は端末の画像の選択だけ (D-415)');
      expect(find.byKey(const ValueKey('discover.content.url')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.listHit.list-1')), findsOneWidget);
    });

    testWidgets('いつものブラウザで見て探す: 通知を出してブラウザを開く → 通知をタップ → 3 秒読み取って(ダミー)送り、結果を出す', (tester) async {
      final central = _FakeCentral();
      final notifier = MemoryLocalNotifier();
      final opened = <Uri>[];
      await openDiscover(tester, central, sub: Routes.snsDiscoverContent, overrides: [
        localNotifierProvider.overrideWithValue(notifier),
        discoverExternalBrowserProvider.overrideWithValue((u) async {
          opened.add(u);
          return true;
        }),
      ]);
      expect(find.byKey(const ValueKey('discover.content.glimpse')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      // 端末の通知(タップで探す画面へ戻る payload)を出し、端末のブラウザを開く。
      final shown = notifier.shown[discoverGlimpseNotificationId]!;
      expect(shown.body, 'タップすると、いま見ている画面を 3 秒だけ読み取ります');
      expect(shown.payload, discoverGlimpsePayload);
      expect(opened, [discoverBrowserHome]);
      expect(find.byKey(const ValueKey('discover.content.glimpse.armed')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.content.glimpse.dummy')), findsOneWidget, reason: '既定の読み取りはダミー');
      expect(central.lastContent, isNull);

      // 通知をタップ → 3 秒だけ読み取る(1 秒ごとに 1 コマ)。
      notifier.tap(discoverGlimpseNotificationId);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('discover.content.glimpse.capturing')), findsOneWidget);
      expect(find.text('画面を読み取っています(0 / 3 秒)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('画面を読み取っています(1 / 3 秒)'), findsOneWidget);
      expect(central.lastContent, isNull, reason: '3 秒たつまで送らない');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      // 写し(画像)を content の口へ送り、結果を出す。通知は消す。
      final sent = central.lastContent!;
      expect(sent.body, contains('name="image"'));
      expect(sent.body, contains('content-type: image/png'));
      expect(find.byKey(const ValueKey('discover.content.glimpse.capturing')), findsNothing);
      expect(find.byKey(const ValueKey('discover.content.glimpse.done')), findsOneWidget);
      expect(find.textContaining('3 コマ'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.listHit.list-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.serverHit.misskey.io')), findsOneWidget);
      expect(notifier.shown, isEmpty);
    });

    testWidgets('画面の読み取りの通知: 探す画面を閉じていても、タップで探す画面を開いて読み取る。やめると通知を消す', (tester) async {
      final central = _FakeCentral();
      final notifier = MemoryLocalNotifier();
      final c = await openDiscover(tester, central, sub: Routes.snsDiscoverContent, overrides: [
        localNotifierProvider.overrideWithValue(notifier),
        discoverExternalBrowserProvider.overrideWithValue((u) async => true),
      ]);
      // やめる → 通知を消す。
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      expect(notifier.shown, isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse.cancel')));
      await tester.pumpAndSettle();
      expect(notifier.shown, isEmpty);
      expect(find.byKey(const ValueKey('discover.content.glimpse.armed')), findsNothing);

      // 通知を出したまま探す画面を閉じて、ほかの画面にいるときにタップ。
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverContentScreen), findsNothing);
      expect(c.read(discoverGlimpseRequestsProvider).listening, isFalse);
      notifier.tap(discoverGlimpseNotificationId);
      // 開く画面の切り替え(読み取りは 1 秒ごとのタイマーなので、ここではまだ終わらない)。
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverContentScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.content.glimpse.capturing')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(central.lastContent!.body, contains('name="image"'));
      expect(find.byKey(const ValueKey('discover.listHit.list-1')), findsOneWidget);
    });

    testWidgets('画面の読み取りの口は差し替えられる(読めた文字と URL も送る)', (tester) async {
      final central = _FakeCentral();
      final notifier = MemoryLocalNotifier();
      final glimpse = _FakeGlimpse();
      await openDiscover(tester, central, sub: Routes.snsDiscoverContent, overrides: [
        localNotifierProvider.overrideWithValue(notifier),
        discoverExternalBrowserProvider.overrideWithValue((u) async => true),
        screenGlimpseProvider.overrideWithValue(glimpse),
      ]);
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.content.glimpse.dummy')), findsNothing);
      notifier.tap(discoverGlimpseNotificationId);
      await tester.pumpAndSettle();
      expect(glimpse.durations, [discoverGlimpseDuration]);
      final sent = central.lastContent!;
      expect(sent.body, contains('name="image"'));
      expect(sent.body, contains('name="text"'));
      expect(sent.body, contains('https://example.com/cats'));
    });

    testWidgets('通知を出せなければ、そう出す(ブラウザは開かない)', (tester) async {
      final opened = <Uri>[];
      await openDiscover(tester, _FakeCentral(), sub: Routes.snsDiscoverContent, overrides: [
        localNotifierProvider.overrideWithValue(_DeniedNotifier()),
        discoverExternalBrowserProvider.overrideWithValue((u) async {
          opened.add(u);
          return true;
        }),
      ]);
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      expect(find.text('通知を出せませんでした。端末の設定で RASQ の通知を許可してください'), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('人から探す: 人のカード(名前・handle@host・説明・入っているリスト)とサーバー', (tester) async {
      final central = _FakeCentral();
      await openDiscover(tester, central, sub: Routes.snsDiscoverPeople);
      await tester.enterText(find.byKey(const ValueKey('discover.people.query')), '猫の写真家');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.people.search')));
      await tester.pumpAndSettle();
      expect(central.peopleQueries, ['猫の写真家']);
      expect(find.byKey(const ValueKey('discover.person.0')), findsOneWidget);
      expect(find.text('はな'), findsOneWidget);
      expect(find.text('@hana@misskey.io'), findsOneWidget);
      expect(find.textContaining('猫の写真を毎日'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.listHit.list-1')), findsWidgets);
      expect(find.byKey(const ValueKey('discover.serverHit.misskey.io')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.people.notFound')), findsNothing);
    });

    testWidgets('人から探す: RASQ リストに無い(source = none)なら、そう出して画像 / RAi の入口を勧める', (tester) async {
      final central = _FakeCentral();
      await openDiscover(tester, central, sub: Routes.snsDiscoverPeople);
      await tester.enterText(find.byKey(const ValueKey('discover.people.query')), 'だれもいない');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.people.search')));
      await tester.pumpAndSettle();
      expect(find.text('RASQ リストでは見つかりませんでした'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.person.0')), findsNothing);
      expect(find.byKey(const ValueKey('discover.people.tryContent')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.people.tryAsk')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover.people.tryAsk')));
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverAskScreen), findsOneWidget);
    });

    testWidgets('RAi に聞く: 会話をクラウドの RAi に送り、答えと候補のタイルを出す(続けて聞くと前の会話も送る)', (tester) async {
      final central = _FakeCentral();
      await openDiscover(tester, central, sub: Routes.snsDiscoverAsk);
      await tester.enterText(find.byKey(const ValueKey('discover.ask.input')), '猫の写真が好き');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.ask.send')));
      await tester.pumpAndSettle();
      expect(find.text('猫の写真が好き'), findsOneWidget);
      expect(find.textContaining('猫の写真なら'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.listHit.list-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.serverHit.misskey.io')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('discover.ask.input')), 'ほかには?');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.ask.send')));
      await tester.pumpAndSettle();
      expect([for (final m in central.askMessages.last) m['role']], ['user', 'assistant', 'user']);
      expect(central.askMessages.last.first['text'], '猫の写真が好き');
    });
  });

  group('結果から', () {
    Future<ProviderContainer> askAndGetResults(WidgetTester tester, _FakeCentral central, {SnsPlugin? plugin}) async {
      final c = await _pump(tester, central, plugin: plugin);
      c.read(routerProvider).push(Routes.snsDiscoverAsk);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('discover.ask.input')), '猫');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.ask.send')));
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('サーバーの「登録する」→ D-412 の登録ページ(RASQ アカウントのポップアップは頼まない)/「ログイン」→ そのサーバーのログイン', (tester) async {
      final c = await askAndGetResults(tester, _FakeCentral());
      await tester.tap(find.byKey(const ValueKey('discover.serverHit.misskey.io.signup')));
      await tester.pumpAndSettle();
      expect(find.byType(ServerSignupScreen), findsOneWidget);
      final t = c.read(serverSignupTargetProvider)!;
      expect((t.host, t.kind, t.nudgeRasqAccount), ('misskey.io', SnsKind.misskey, false));
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.serverHit.misskey.io.login')));
      await tester.pumpAndSettle();
      expect(find.byType(SnsLoginScreen), findsOneWidget);
    });

    testWidgets('リスト: SNS アカウントが無ければ、リストの人のサーバー(sampleHosts)へ登録 → ログインしたらリストを開く', (tester) async {
      final c = await askAndGetResults(tester, _FakeCentral(), plugin: _SignupPlugin());
      expect(find.text('リストの人のサーバーに登録'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover.listHit.list-1.open')));
      await tester.pumpAndSettle();
      expect(find.byType(ServerSignupScreen), findsOneWidget);
      final t = c.read(serverSignupTargetProvider)!;
      expect((t.host, t.list?.id, t.nudgeRasqAccount), ('misskey.io', 'list-1', false));
      await c.read(sessionsProvider.notifier).add(await _Flow().complete());
      c.read(routerProvider).go(Routes.home);
      await followSignupTarget(c, _SignupPlugin.me);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RasqCollectionScreen), findsOneWidget);
      expect(c.read(rasqAccountNudgeProvider), isFalse, reason: 'D-414 の流れでは頼まない');
    });

    testWidgets('リスト: SNS アカウントがあれば、そのままリストを開く', (tester) async {
      final c = await _pump(tester, _FakeCentral(), plugin: _SignupPlugin());
      await c.read(sessionsProvider.notifier).add(await _Flow().complete());
      c.read(routerProvider).push(Routes.snsDiscoverAsk);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('discover.ask.input')), '猫');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.ask.send')));
      await tester.pumpAndSettle();
      expect(find.text('リストを開いて取り込む'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover.listHit.list-1.open')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RasqCollectionScreen), findsOneWidget);
    });
  });

  group('WebView の指差し', () {
    const misskey = ServerSignupTarget(host: 'misskey.io', kind: SnsKind.misskey, software: 'misskey', name: 'Misskey.io');
    const mastodon = ServerSignupTarget(host: 'mastodon.social', kind: SnsKind.mastodon, software: 'mastodon', name: 'Mastodon');

    test('手順 / URL ごとに指すもの(SNS ごとの見つけ方)', () {
      expect(signupPointIntent(misskey, 0, 5), SignupPointIntent.openSignup);
      expect(signupPointIntent(misskey, 1, 5), SignupPointIntent.accountFields);
      expect(signupPointIntent(misskey, 2, 5), SignupPointIntent.extraFields);
      expect(signupPointIntent(misskey, 3, 5), SignupPointIntent.agreement);
      expect(signupPointIntent(misskey, 4, 5), SignupPointIntent.none, reason: '最後(登録できた)は指さない');
      expect(signupPointIntent(mastodon, 0, 4), SignupPointIntent.rules);
      expect(signupPointIntent(mastodon, 1, 4), SignupPointIntent.accountFields);
      expect(signupPointIntent(mastodon, 2, 4), SignupPointIntent.none, reason: 'メールの確認');
      expect(signupPointIntent(mastodon, 0, 4, url: Uri.parse('https://mastodon.social/auth/sign_in')), SignupPointIntent.login);
      expect(signupPointIntent(mastodon, 1, 4, url: Uri.parse('https://mastodon.social/oauth/authorize?x=1')), SignupPointIntent.authorize);
      const closed = ServerSignupTarget(host: 'x.example', kind: SnsKind.misskey, software: 'misskey', registrationOpen: false);
      expect(signupPointIntent(closed, 0, 6), SignupPointIntent.none, reason: '招待制の注意');
      expect(signupPointIntent(closed, 1, 6), SignupPointIntent.openSignup);
      expect(signupPointSpec(mastodon, SignupPointIntent.accountFields)!.selectors, contains('input[name="user[account_attributes][username]"]'));
      expect(signupPointSpec(mastodon, SignupPointIntent.accountFields)!.selectors, contains('input[name="user[agreement]"]'));
      expect(signupPointSpec(misskey, SignupPointIntent.accountFields)!.selectors, contains('[data-cy-signup-username] input'));
      expect(signupPointSpec(misskey, SignupPointIntent.none), isNull);
      final js = signupPointScript(signupPointSpec(misskey, SignupPointIntent.openSignup));
      expect(js, contains('scrollIntoView'));
      expect(js, contains('__rasq_point'));
      expect(js, contains('[data-cy-signup]'));
      expect(signupPointScript(null), contains('(null)'), reason: '指さないときは前の枠を消すだけ');
    });

    testWidgets('登録ページ: 手順を進めるたびに、その手順の JS をページに流す(URL が変わればそちらを優先)', (tester) async {
      final runner = _FakeJs();
      SignupWebHooks? hooks;
      final c = await _pump(tester, _FakeCentral(), signupWeb: (context, url, h) {
        hooks = h;
        h.attach(runner);
        return Center(child: Text('fake web: $url'));
      });
      c.read(serverSignupTargetProvider.notifier).set(mastodon);
      c.read(routerProvider).push(Routes.serverSignup);
      await tester.pumpAndSettle();
      expect(runner.scripts, isNotEmpty);
      expect(runner.scripts.last, contains('accept='), reason: '1 つめ = ルールの「同意する」');
      await tester.tap(find.byKey(const ValueKey('signup.guide.next')));
      await tester.pumpAndSettle();
      expect(runner.scripts.last, contains('user[account_attributes][username]'));
      expect(runner.scripts.last, contains('user[email]'));
      await tester.tap(find.byKey(const ValueKey('signup.guide.next')));
      await tester.pumpAndSettle();
      expect(runner.scripts.last, contains('(null)'), reason: 'メールの確認は指さない(前の枠を消す)');
      hooks!.onPageLoaded(Uri.parse('https://mastodon.social/auth/sign_in'));
      await tester.pumpAndSettle();
      expect(runner.scripts.last, contains('/auth/sign_in'));
      expect(runner.scripts.last, contains('user[password]'));
    });
  });
}

// ---------------------------------------------------------------------------

/// 1×1 の PNG。
final _png = Uint8List.fromList(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));

class _FakeGlimpse implements ScreenGlimpse {
  final durations = <Duration>[];
  @override
  bool get isDummy => false;
  @override
  Future<GlimpseFrames> capture({required Duration duration, ValueChanged<Duration>? onProgress}) async {
    durations.add(duration);
    return GlimpseFrames(frames: [_png, _png], text: '茶トラの子猫', url: Uri.parse('https://example.com/cats'));
  }
}

class _DeniedNotifier extends MemoryLocalNotifier {
  @override
  Future<bool> show({required int id, required String title, required String body, String? payload}) async => false;
}

class _FakeCapturer implements DiscoverPageCapturer {
  final loaded = <Uri>[];
  @override
  void load(Uri url) => loaded.add(url);
  @override
  Future<DiscoverCapture> capture() async => DiscoverCapture(text: 'ねこ写真まとめ\n茶トラの子猫', url: Uri.parse('https://example.com/cats'));
}

class _FakeJs implements WebJsRunner {
  final scripts = <String>[];
  @override
  Future<void> runJavaScript(String javaScript) async => scripts.add(javaScript);
  @override
  Future<Object> runJavaScriptReturningResult(String javaScript) async {
    scripts.add(javaScript);
    return 0;
  }
}

class _SignupPlugin extends FakeSnsPlugin {
  _SignupPlugin() : super(id: 'rasq.official.misskey', posts: (_) => const []);
  static const me = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'newbie');
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
        session: AccountSession(account: _SignupPlugin.me, pluginId: 'rasq.official.misskey', token: 't', createdAt: DateTime(2026, 10, 3), displayName: 'newbie'),
        me: const UserSummary(id: 'u-newbie', account: _SignupPlugin.me, displayName: 'newbie'),
      );
}

Map<String, Object?> _wire(String id, String body, {String? cw, String? replyToId, String handle = 'hana'}) => {
      'id': id,
      'author': {'id': 'u-$handle', 'kind': 'misskey', 'instance': 'misskey.io', 'handle': handle, 'displayName': handle},
      'createdAt': '2026-10-01T00:00:00Z',
      'body': body,
      'cw': ?cw,
      'replyToId': ?replyToId,
      'visibility': 'public',
      'counts': {'reactions': 5},
    };

const _listHit = {
  'id': 'list-1',
  'name': 'ねこ好きの集まり',
  'description': '猫の写真を投稿する人たち',
  'ownerHandle': 'neko',
  'memberCount': 12,
  'sampleHosts': ['misskey.io'],
  'score': 0.9,
  'reason': '猫の写真',
};
const _serverHit = {'host': 'misskey.io', 'kind': 'misskey', 'name': 'Misskey.io', 'reason': 'リストの人が多いサーバー'};

/// Central / ORGATE のフェイク(契約 CONTRACT.md の形)。
class _FakeCentral {
  _FakeCentral({this.takenHandles = const {}});
  final Set<String> takenHandles;
  final calls = <String>[];
  Map<String, Object?>? consents;
  String handle = 'rasq_new';
  bool hasPassword = false;
  ({String contentType, String body})? lastContent;
  final peopleQueries = <String>[];
  final askMessages = <List<Map<String, Object?>>>[];

  Map<String, Object?> get me => {'id': 'acc-1', 'handle': handle, 'displayName': 'テスター', 'createdAt': '2026-10-03T00:00:00Z', 'hasPassword': hasPassword};

  late final MockClient client = MockClient((req) async {
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    final path = req.url.path.replaceFirst('/api/v1', '');
    calls.add('${req.method} $path${req.url.hasQuery ? '?${req.url.query}' : ''}');
    // オンボーディングの口は匿名。
    if (path == '/onboarding/feed') {
      return json({
        'posts': [
          {'post': _wire('cw1', 'ネタバレ注意の新作ゲームの感想、ボスが強すぎる', cw: 'ネタバレ'), 'list': {'id': 'list-1', 'name': 'ねこ好きの集まり', 'ownerHandle': 'neko'}, 'score': 9},
          {'post': _wire('r1', 'それなー、うちの猫も同じことしてる本当に', replyToId: 'x'), 'list': {'id': 'list-1', 'name': 'ねこ好きの集まり', 'ownerHandle': 'neko'}, 'score': 8},
          {'post': _wire('p1', 'うちの猫が箱から出てこない、ずっと寝てる'), 'list': {'id': 'list-1', 'name': 'ねこ好きの集まり', 'ownerHandle': 'neko'}, 'score': 5},
        ],
        'stale': false,
      });
    }
    if (path == '/onboarding/discover/content') {
      lastContent = (contentType: req.headers['content-type'] ?? '', body: latin1.decode(req.bodyBytes).toLowerCase());
      return json({
        'query': {
          'text': '茶トラの子猫の写真',
          'keywords': ['猫', '写真'],
          'crops': [
            {'x': 0.1, 'y': 0.1, 'w': 0.5, 'h': 0.5, 'label': 'ねこ'},
          ],
        },
        'lists': [_listHit],
        'servers': [_serverHit],
        'mode': 'dummy',
      });
    }
    if (path == '/onboarding/discover/people') {
      final q = (jsonDecode(req.body) as Map)['query'] as String;
      peopleQueries.add(q);
      if (q == 'だれもいない') return json({'people': [], 'lists': [], 'servers': [], 'source': 'none', 'mode': 'lexical'});
      return json({
        'people': [
          {'name': 'はな', 'kind': 'misskey', 'handle': 'hana', 'host': 'misskey.io', 'profileUrl': 'https://misskey.io/@hana', 'snippet': '猫の写真を毎日あげています', 'lists': [_listHit]},
        ],
        'lists': [_listHit],
        'servers': [_serverHit],
        'source': 'lists',
        'mode': 'lexical',
      });
    }
    if (path == '/onboarding/discover/ask') {
      askMessages.add([for (final m in (jsonDecode(req.body) as Map)['messages'] as List) (m as Map).cast<String, Object?>()]);
      return json({'answer': '猫の写真なら、このリストとサーバーが合いそうです。', 'lists': [_listHit], 'servers': [_serverHit], 'mode': 'dummy'});
    }
    final info = RegExp(r'^/servers/([^/]+)/info$').firstMatch(path);
    if (info != null) {
      if (info.group(1) == 'misskey.io') return json({'host': 'misskey.io', 'software': 'misskey', 'name': 'Misskey.io', 'users': 1200, 'registrationOpen': true});
      return json({'error': {'code': '404', 'message': 'not an instance'}}, 404);
    }
    if (path.startsWith('/rasq-collections/list-1')) {
      return json({
        'collection': {'id': 'list-1', 'kind': 'list', 'name': 'ねこ好きの集まり', 'visibility': 'public', 'owner': {'id': 'o1', 'handle': 'neko'}, 'itemCount': 1, 'instances': ['misskey.io']},
        'items': [],
        'posts': [],
        'viewer': {'isOwner': false, 'following': false, 'eligible': false, 'canFetch': false},
      });
    }
    // 登録(ORGATE)。
    if (req.method == 'POST' && path == '/auth/device') {
      consents = ((jsonDecode(req.body) as Map)['consents'] as Map?)?.cast<String, Object?>();
      return json({'accountId': 'acc-1', 'handle': handle, 'displayName': 'テスター', 'accessToken': 'device-token', 'refreshToken': 'refresh'});
    }
    if (req.headers['authorization'] != 'Bearer device-token') return json({'error': {'code': '401', 'message': 'valid bearer token required'}}, 401);
    if (req.method == 'GET' && path == '/me') return json(me);
    if (req.method == 'PATCH' && path == '/me') {
      final h = (jsonDecode(req.body) as Map)['handle'] as String?;
      if (h != null && takenHandles.contains(h)) return json({'error': {'code': '409', 'message': 'handle taken'}}, 409);
      if (h != null) handle = h;
      return json(me);
    }
    if (req.method == 'POST' && path == '/auth/password') {
      hasPassword = true;
      return http.Response('', 204);
    }
    return json([]);
  });
}

/// 新規の端末(台帳が空)。既定は狭い画面。
Future<ProviderContainer> _pump(WidgetTester tester, _FakeCentral central, {Size size = const Size(420, 900), List<Override> overrides = const [], SnsPlugin? plugin, SignupWebAreaBuilder? signupWeb}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin ?? FakeSnsPlugin(posts: (_) => const []))),
      orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: central.client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      signupWebAreaProvider.overrideWithValue(signupWeb ?? (context, url, hooks) => Center(child: Text('fake web: $url'))),
      ...overrides,
    ],
    child: const RasqApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
}
