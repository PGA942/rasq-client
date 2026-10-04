import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/onboarding_discover_api.dart' show discoverFramesMax, discoverFramesMaxTotalBytes;
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart' show orgateTokenHolderProvider;
import 'package:rasq_client/features/child_safe/child_safe_screens.dart' show ChildLoginScreen;
import 'package:rasq_client/features/collections/rasq_collection_screen.dart';
import 'package:rasq_client/features/login/sns_login_screen.dart';
import 'package:rasq_client/features/settings/developer_mode.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart' show settingsAreaProvider;
import 'package:rasq_client/features/onboarding/discover_image_crop.dart';
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
      // 「SNS サービスを探す」→ 探す画面 → 戻る(D-422)→ ③。
      await tester.tap(find.byKey(const ValueKey('onb.discover')));
      await tester.pumpAndSettle();
      expect(find.byType(SnsDiscoverScreen), findsOneWidget);
      await tester.tap(find.byTooltip('戻る').first);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingSnsScreen), findsOneWidget);
      // SNS のログイン(Misskey)→ 戻る → ③。
      await tester.tap(find.text('Misskeyでログイン'));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingSnsScreen), findsNothing);
      await tester.tap(find.byTooltip('戻る').first);
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingSnsScreen), findsOneWidget);
      // ③ にも戻るがある(D-422)。戻る先が無い(② の登録のあと `go` で来た)ので、RASQ アカウントの入口へ。作ったアカウントは残る。
      await tester.tap(find.byKey(const ValueKey('onb.back')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingSnsScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(c.read(rasqAccountsProvider).value!.current?.handle, 'neko_taro');
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

    testWidgets('画像から探す: 選んだ画像を(囲まずに決定 = 全体)multipart の frames で送り、探す言葉・切り抜き・リスト・サーバーを出す', (tester) async {
      final central = _FakeCentral();
      await openDiscover(tester, central, sub: Routes.snsDiscoverContent, overrides: [
        discoverImagePickerProvider.overrideWithValue(({required bool camera, required int limit}) async => [_png]),
        discoverImageToolsProvider.overrideWithValue(const DiscoverImageTools.inline()),
      ]);
      await tester.tap(find.byKey(const ValueKey('discover.content.pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.editor')), findsOneWidget, reason: '追加した画像は「囲って検索」を開く');
      await tester.tap(find.byKey(const ValueKey('discover.editor.done')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.content.search')));
      await tester.pumpAndSettle();
      final sent = central.lastContent!;
      expect(sent.contentType, startsWith('multipart/form-data'));
      expect(sent.body, isNot(contains('name="image"')));
      expect('name="frames"'.allMatches(sent.body).length, 1);
      expect(sent.body, contains('content-type: image/jpeg'), reason: '端末で JPEG にしてから送る');
      expect(sent.body, contains('picker'));
      await tester.scrollUntilVisible(find.byKey(const ValueKey('discover.serverHit.misskey.io')), 200, scrollable: find.descendant(of: find.byKey(const ValueKey('discover.content.list')), matching: find.byType(Scrollable)).first);
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
      // 写し(コマ)を content の口へ `frames` で送り(CONTRACT §2 の追記、D-416)、結果を出す。通知は消す。
      final sent = central.lastContent!;
      expect('name="frames"'.allMatches(sent.body).length, 3);
      expect(sent.body, isNot(contains('name="image"')));
      expect(sent.body, contains('name="source"\r\n\r\nscreen'));
      expect(sent.body, contains('name="capturedat"'));
      expect(sent.body, contains('content-type: image/png'));
      expect(find.byKey(const ValueKey('discover.content.glimpse.capturing')), findsNothing);
      expect(find.byKey(const ValueKey('discover.content.glimpse.done')), findsOneWidget);
      expect(find.textContaining('(3 コマ)'), findsOneWidget);
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
      expect(central.lastContent!.body, contains('name="frames"'));
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
      expect('name="frames"'.allMatches(sent.body).length, 2);
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

  group('囲って検索 (D-418)', () {
    Future<_PickHarness> openPicker(WidgetTester tester, List<Uint8List> images, {List<Override> overrides = const []}) async {
      final h = _PickHarness(images);
      final central = _FakeCentral();
      final c = await _pump(tester, central, overrides: [
        discoverImagePickerProvider.overrideWithValue(({required bool camera, required int limit}) async {
          h.limits.add(limit);
          return images;
        }),
        discoverImageToolsProvider.overrideWithValue(h),
        ...overrides,
      ]);
      c.read(routerProvider).push(Routes.snsDiscoverContent);
      await tester.pumpAndSettle();
      h.central = central;
      return h;
    }

    Future<void> done(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('discover.editor.done')));
      await tester.pumpAndSettle();
    }

    /// 画像の画素の座標 → 編集画面の上の座標(拡大していないとき)。
    Offset onCanvas(WidgetTester tester, Size image, Offset p) {
      final box = tester.getRect(find.byKey(const ValueKey('discover.editor.canvas')));
      final fitted = applyBoxFit(BoxFit.contain, image, box.size).destination;
      final fit = Alignment.center.inscribe(fitted, Offset.zero & box.size);
      return box.topLeft + fit.topLeft + p * (fit.width / image.width);
    }

    List<String> order(String body) {
      final found = [for (final m in RegExp(r'pick-(\w)').allMatches(body)) m.group(1)!];
      return found;
    }

    testWidgets('複数の画像を追加 → 順に囲って検索(決定で全体)→ 外す・並べ替え → その順で frames(source: picker)を送り、1 枚ずつ切り抜きのチップで見られる', (tester) async {
      final imgs = [_synth(40, 30), _synth(50, 30), _synth(60, 30)];
      final h = await openPicker(tester, imgs);
      await tester.tap(find.byKey(const ValueKey('discover.content.pick')));
      await tester.pumpAndSettle();
      expect(h.limits, [6], reason: '残りの枚数まで選べる');
      expect(find.text('囲って検索(1 / 3)'), findsOneWidget);
      await done(tester);
      expect(find.text('囲って検索(2 / 3)'), findsOneWidget);
      await done(tester);
      await done(tester);
      expect(find.byKey(const ValueKey('discover.editor')), findsNothing);
      for (final id in [0, 1, 2]) {
        expect(find.byKey(ValueKey('discover.pick.$id')), findsOneWidget);
        expect(tester.widget<Text>(find.byKey(ValueKey('discover.pick.$id.badge'))).data, '全体');
      }
      expect(find.text('この 3 枚で探す'), findsOneWidget);
      expect(h.selections, [null, null, null], reason: '囲まずに決定 = 画像全体');

      // 外す
      await tester.tap(find.byKey(const ValueKey('discover.pick.1.remove')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.pick.1')), findsNothing);
      expect(find.text('この 2 枚で探す'), findsOneWidget);

      // 並べ替え(長押しして右へ)
      final g = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('discover.pick.0'))));
      await tester.pump(const Duration(milliseconds: 600));
      for (var i = 0; i < 6; i++) {
        await g.moveBy(const Offset(30, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await g.up();
      await tester.pumpAndSettle();
      expect(tester.getCenter(find.byKey(const ValueKey('discover.pick.2'))).dx, lessThan(tester.getCenter(find.byKey(const ValueKey('discover.pick.0'))).dx));

      await tester.tap(find.byKey(const ValueKey('discover.content.search')));
      await tester.pumpAndSettle();
      final body = h.central.lastContent!.body;
      expect('name="frames"'.allMatches(body).length, 2);
      expect(body, contains('name="source"'));
      expect(body, contains('\r\n\r\npicker\r\n'));
      expect(order(body), ['c', 'a'], reason: '並べた順に送る');
      expect(find.byKey(const ValueKey('discover.content.frame.0')), findsOneWidget);
      expect(find.text('2 枚目'), findsOneWidget);
    });

    testWidgets('四角で囲む → その外接の四角で切り抜く(長辺 1600 以内の JPEG)。タップで囲み直し、なぞった輪にも替えられる', (tester) async {
      const size = Size(400, 200);
      final h = await openPicker(tester, [_synth(400, 200)], overrides: []);
      h.real = true;
      await tester.tap(find.byKey(const ValueKey('discover.content.pick')));
      await tester.pumpAndSettle();
      expect(find.text('決定(画像全体)'), findsOneWidget);
      final g = await tester.startGesture(onCanvas(tester, size, const Offset(100, 50)));
      await g.moveTo(onCanvas(tester, size, const Offset(200, 100)));
      await tester.pump();
      await g.moveTo(onCanvas(tester, size, const Offset(300, 150)));
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text('決定'), findsOneWidget);
      await done(tester);
      final sel = h.selections.single!;
      expect(sel.kind, DiscoverSelectionKind.rect);
      final b = discoverSelectionBounds(sel, size)!;
      expect(b.left, closeTo(100, 1));
      expect(b.top, closeTo(50, 1));
      expect(b.right, closeTo(300, 1));
      expect(b.bottom, closeTo(150, 1));
      final out = img.decodeJpg(h.prepared.last!)!;
      expect(out.width, closeTo(200, 2));
      expect(out.height, closeTo(100, 2));
      expect(tester.widget<Text>(find.byKey(const ValueKey('discover.pick.0.badge'))).data, '四角');

      // タップで開き直して、なぞった輪に替える(ひし形)。
      await tester.tap(find.byKey(const ValueKey('discover.pick.0.edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.editor.tool.lasso')));
      await tester.pumpAndSettle();
      final lasso = [const Offset(200, 20), const Offset(260, 60), const Offset(300, 100), const Offset(250, 140), const Offset(200, 180), const Offset(150, 140), const Offset(100, 100), const Offset(150, 60)];
      final g2 = await tester.startGesture(onCanvas(tester, size, lasso.first));
      for (final p in lasso.skip(1)) {
        await g2.moveTo(onCanvas(tester, size, p));
        await tester.pump();
      }
      await g2.up();
      await tester.pumpAndSettle();
      await done(tester);
      final sel2 = h.selections.last!;
      expect(sel2.kind, DiscoverSelectionKind.lasso);
      final b2 = discoverSelectionBounds(sel2, size)!;
      expect(b2.left, closeTo(100, 1));
      expect(b2.top, closeTo(20, 1));
      expect(b2.right, closeTo(300, 1));
      expect(b2.bottom, closeTo(180, 1));
      final out2 = img.decodeJpg(h.prepared.last!)!;
      expect(out2.width, closeTo(200, 2));
      expect(out2.height, closeTo(160, 2));
      final corner = out2.getPixel(2, 2);
      expect(corner.r, closeTo(discoverMaskGray, 12), reason: '輪の外は灰色');
      expect(tester.widget<Text>(find.byKey(const ValueKey('discover.pick.0.badge'))).data, 'なぞり');

      // 消して決定 → 画像全体に戻る。
      await tester.tap(find.byKey(const ValueKey('discover.pick.0.edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.editor.clear')));
      await tester.pumpAndSettle();
      await done(tester);
      expect(h.selections.last, isNull);
      final whole = img.decodeJpg(h.prepared.last!)!;
      expect((whole.width, whole.height), (400, 200), reason: '囲まなければ画像全体');
    });

    testWidgets('6 枚まで: 多く返ったら 6 枚だけ追加してそう出す。編集を閉じたら残りは全体のまま。送るのは 6 コマ', (tester) async {
      final h = await openPicker(tester, [for (var i = 0; i < 8; i++) _synth(20 + i, 20)]);
      await tester.tap(find.byKey(const ValueKey('discover.content.pick')));
      await tester.pumpAndSettle();
      expect(find.text('囲って検索(1 / 6)'), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const ValueKey('discover.editor')))).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.editor')), findsNothing, reason: '閉じたら残りは開かない');
      expect(find.byKey(const ValueKey('discover.content.picks.notice')), findsOneWidget);
      expect(find.textContaining('2 枚は追加しませんでした'), findsOneWidget);
      expect(find.text('この 6 枚で探す'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('discover.content.pick'))).onPressed, isNull, reason: '6 枚で満杯');
      await tester.tap(find.byKey(const ValueKey('discover.content.search')));
      await tester.pumpAndSettle();
      final body = h.central.lastContent!.body;
      expect('name="frames"'.allMatches(body).length, 6);
      expect(body, contains('\r\n\r\npicker\r\n'));
      expect(h.selections, everyElement(isNull));
    });

    test('合計 24 MiB・1 枚 10 MiB・6 枚を超える分は後ろから外す(順番は保つ)', () {
      Uint8List jpeg(int mib) => Uint8List(mib * 1024 * 1024)..setAll(0, [0xFF, 0xD8, 0xFF]);
      final r = fitDiscoverPickerFrames([jpeg(6), jpeg(11), jpeg(6), jpeg(6), jpeg(6), jpeg(6)]);
      expect(r.frames.length, 4);
      expect(r.dropped, 2);
      expect(r.frames.fold<int>(0, (n, f) => n + f.length), lessThanOrEqualTo(discoverFramesMaxTotalBytes));
      final many = fitDiscoverPickerFrames([for (var i = 0; i < 8; i++) Uint8List.fromList([0xFF, 0xD8, 0xFF, i])]);
      expect(many.frames.length, discoverFramesMax);
      expect([for (final f in many.frames) f[3]], [0, 1, 2, 3, 4, 5]);
      expect(fitDiscoverPickerFrames([Uint8List.fromList([1, 2, 3])]).frames, isEmpty, reason: '形式の分からないものは送らない');
    });

    testWidgets('いつものブラウザで見て探す: iOS は既定で出さず、開発者モードの「画面の読み取りを試す(iOS)」で出す。Android は出す。画像の追加が主', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        final c = await _pump(tester, _FakeCentral());
        c.read(routerProvider).push(Routes.snsDiscoverContent);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('discover.content.glimpse')), findsNothing);
        expect(find.byKey(const ValueKey('discover.content.browse')), findsOneWidget);
        expect(find.widgetWithText(FilledButton, '画像を選ぶ'), findsOneWidget, reason: '主の操作は画像');
        await c.read(settingsAreaProvider(developerModeArea).notifier).set('iosScreenGlimpse', true);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('discover.content.glimpse')), findsNothing, reason: '開発者モードがオフ');
        await c.read(settingsAreaProvider(developerModeArea).notifier).set('enabled', true);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('discover.content.glimpse')), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('Android はいつものブラウザで見て探すを出す', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        final c = await _pump(tester, _FakeCentral());
        c.read(routerProvider).push(Routes.snsDiscoverContent);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('discover.content.glimpse')), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('Android の画面の読み取り (D-416、ネイティブの口は偽物)', () {
    late Directory root;
    setUp(() => root = Directory.systemTemp.createTempSync('rasq_glimpse_test'));
    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    /// ネイティブが書くのと同じ形で、読み取ったコマを置く。
    Directory writeCapture(String id, {int frames = 3}) {
      final dir = Directory('${root.path}/$id')..createSync(recursive: true);
      final names = <String>[];
      for (var i = 0; i < frames; i++) {
        File('${dir.path}/frame_$i.jpg').writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0, i, 1, 2, 3]);
        names.add('frame_$i.jpg');
      }
      File('${dir.path}/meta.json').writeAsStringSync(jsonEncode({'id': id, 'capturedAt': '2026-10-03T08:00:00.400Z', 'width': 498, 'height': 1080, 'frames': names}));
      return dir;
    }

    Future<void> nativeEvent(WidgetTester tester, Map<String, Object?> event) async {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(screenGlimpseChannelName, const StandardMethodCodec().encodeMethodCall(MethodCall('event', event)), (_) {});
      await tester.pumpAndSettle();
    }

    Future<({ProviderContainer c, _FakeCentral central, List<String> calls, List<Uri> opened, MemoryLocalNotifier notifier})> open(
      WidgetTester tester, {
      String startStatus = 'started',
      String? launchId,
      String? sub = Routes.snsDiscoverContent,
      DateTime Function()? clock,
    }) async {
      final calls = <String>[];
      const channel = MethodChannel(screenGlimpseChannelName);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'start' => {'status': startStatus},
          'dir' => root.path,
          'takeLaunchOpen' => launchId,
          _ => null,
        };
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      final glimpse = NativeScreenGlimpse(channel: channel, clock: clock);
      addTearDown(glimpse.dispose);
      final central = _FakeCentral();
      final notifier = MemoryLocalNotifier();
      final opened = <Uri>[];
      final c = await _pump(tester, central, overrides: [
        screenGlimpseProvider.overrideWithValue(glimpse),
        localNotifierProvider.overrideWithValue(notifier),
        discoverExternalBrowserProvider.overrideWithValue((u) async {
          opened.add(u);
          return true;
        }),
      ]);
      if (sub != null) {
        c.read(routerProvider).push(sub);
        await tester.pumpAndSettle();
      }
      return (c: c, central: central, calls: calls, opened: opened, notifier: notifier);
    }

    testWidgets('押す → 同意 → 端末の通知(RASQ の通知は出さない)とブラウザ → 読み取り終えたら全部のコマを frames で送り、コマを消す。切り抜きは合うコマに重ねる', (tester) async {
      final t = await open(tester);
      t.central.contentCrops = [
        {'x': 0.1, 'y': 0.1, 'w': 0.3, 'h': 0.3, 'label': '最初', 'frame': 0},
        {'x': 0.2, 'y': 0.2, 'w': 0.3, 'h': 0.3, 'label': '最後', 'frame': 2},
        {'x': 0.3, 'y': 0.3, 'w': 0.3, 'h': 0.3, 'label': '範囲の外', 'frame': 99},
      ];
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      expect(t.calls, contains('start'));
      expect(t.opened, [discoverBrowserHome]);
      expect(t.notifier.shown, isEmpty, reason: '読み取りのボタンつきの通知は端末(前面サービス)が出す');
      expect(find.byKey(const ValueKey('discover.content.glimpse.armed')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.content.glimpse.dummy')), findsNothing, reason: '本物');

      const id = 'g1759478400000-0a1b2c3d4e5f';
      final dir = writeCapture(id);
      await nativeEvent(tester, {'type': 'capturing', 'id': id});
      await nativeEvent(tester, {'type': 'done', 'id': id, 'frames': 3});
      final sent = t.central.lastContent!;
      expect('name="frames"'.allMatches(sent.body).length, 3);
      expect(sent.body, isNot(contains('name="image"')));
      expect(sent.body, contains('content-type: image/jpeg'));
      expect(sent.body, contains('name="source"\r\n\r\nscreen'));
      expect(sent.body, contains('name="capturedat"\r\n\r\n2026-10-03t08:00:00.400z'));
      expect(dir.existsSync(), isFalse, reason: '送ったらコマを消す');
      expect(t.calls, contains('dismissDone'));
      expect(find.byKey(const ValueKey('discover.content.glimpse.armed')), findsNothing);
      expect(find.textContaining('(3 コマ)'), findsOneWidget);
      // 切り抜きのいちばん多いコマ(最後 + 範囲の外 = 3 コマ目)を出し、そのコマの分だけ重ねる。
      expect(tester.widget<ChoiceChip>(find.byKey(const ValueKey('discover.content.frame.2'))).selected, isTrue);
      expect(find.byKey(const ValueKey('discover.crop.0')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.crop.1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover.content.frame.0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.crop.0')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.crop.1')), findsNothing);

      // あとから「読み取りました」の通知をタップしても、2 度は送らない。
      t.central.lastContent = null;
      await nativeEvent(tester, {'type': 'open', 'id': id});
      expect(t.central.lastContent, isNull);
      expect(find.byKey(const ValueKey('discover.content.error')), findsNothing);
    });

    testWidgets('探す画面を閉じていても「読み取りました」のタップで結果の画面を開いて送る / 通知から起動したときも', (tester) async {
      const id = 'g1759478400001-aaaaaaaaaaaa';
      final t = await open(tester, sub: null);
      expect(find.byType(DiscoverContentScreen), findsNothing);
      writeCapture(id, frames: 2);
      await nativeEvent(tester, {'type': 'open', 'id': id});
      expect(find.byType(DiscoverContentScreen), findsOneWidget);
      expect('name="frames"'.allMatches(t.central.lastContent!.body).length, 2);
      expect(Directory('${root.path}/$id').existsSync(), isFalse);
    });

    testWidgets('通知から起動: 起動時に 10 分より古いコマを先に消すので、古い結果は送らず「見つかりませんでした」', (tester) async {
      const id = 'g1759478400002-bbbbbbbbbbbb';
      final stale = writeCapture('g1759478000000-cccccccccccc');
      writeCapture(id);
      // 時計を 11 分進める → 置いたままのコマは全部古い。結果の id は消す前に開くので、起動時の掃除の対象から外れるよう、先に読む。
      final t = await open(tester, sub: null, launchId: id, clock: () => DateTime.now().add(const Duration(minutes: 11)));
      await tester.pumpAndSettle();
      expect(t.calls, containsAllInOrder(['dir', 'takeLaunchOpen']));
      expect(stale.existsSync(), isFalse, reason: '置いたままのコマは起動時に消す');
      // 起動時の掃除が先に走るので、10 分より古い結果は「見つかりませんでした」になる(古いコマは送らない)。
      expect(find.byType(DiscoverContentScreen), findsOneWidget);
      expect(t.central.lastContent, isNull);
      expect(find.textContaining('読み取った画面が見つかりませんでした'), findsOneWidget);
    });

    testWidgets('起動時の掃除は新しいコマを残し、通知から起動したらそのコマを送る', (tester) async {
      const id = 'g1759478400003-dddddddddddd';
      writeCapture(id);
      final t = await open(tester, sub: null, launchId: id);
      await tester.pumpAndSettle();
      expect(find.byType(DiscoverContentScreen), findsOneWidget);
      expect('name="frames"'.allMatches(t.central.lastContent!.body).length, 3);
    });

    testWidgets('同意しなかった / 通知を許可しなかった: そう出し、ブラウザは開かない', (tester) async {
      var t = await open(tester, startStatus: 'denied');
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      expect(find.textContaining('画面の読み取りが許可されませんでした'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.content.glimpse.armed')), findsNothing);
      expect(t.opened, isEmpty);

      await tester.pumpWidget(const SizedBox());
      t = await open(tester, startStatus: 'notifications_denied');
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      expect(find.textContaining('端末の設定で RASQ の通知を許可してください'), findsOneWidget);
      expect(t.opened, isEmpty);
    });

    testWidgets('やめる → ネイティブの cancel。端末が止めた(onStop)ら待ちを外してそう出す', (tester) async {
      final t = await open(tester);
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse.cancel')));
      await tester.pumpAndSettle();
      expect(t.calls, contains('cancel'));
      expect(find.byKey(const ValueKey('discover.content.glimpse.armed')), findsNothing);
      await nativeEvent(tester, {'type': 'stopped', 'reason': 'cancel'});
      expect(find.byKey(const ValueKey('discover.content.error')), findsNothing, reason: '自分でやめたときは何も出さない');

      await tester.tap(find.byKey(const ValueKey('discover.content.glimpse')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.content.glimpse.armed')), findsOneWidget);
      await nativeEvent(tester, {'type': 'stopped', 'reason': 'system'});
      expect(find.byKey(const ValueKey('discover.content.glimpse.armed')), findsNothing);
      expect(find.textContaining('画面の読み取りが止められました'), findsOneWidget);
      expect(t.central.lastContent, isNull);
    });

    test('NativeScreenGlimpse: 変な id は読まない・消さない、古いコマだけ消す', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      const channel = MethodChannel('rasq/screen_glimpse_unit');
      final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => call.method == 'dir' ? root.path : null);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var now = DateTime.now();
      final g = NativeScreenGlimpse(channel: channel, clock: () => now);
      addTearDown(g.dispose);
      final outside = Directory('${root.path}/../rasq_glimpse_outside_${root.path.hashCode}')..createSync();
      addTearDown(() => outside.existsSync() ? outside.deleteSync(recursive: true) : null);
      expect(await g.takeResult('../${outside.path.split('/').last}'), isNull);
      await g.discard('../${outside.path.split('/').last}');
      expect(outside.existsSync(), isTrue);
      writeCapture('g1759478400004-eeeeeeeeeeee', frames: 2);
      final r = await g.takeResult('g1759478400004-eeeeeeeeeeee');
      expect(r!.frames, hasLength(2));
      expect(r.capturedAt, DateTime.utc(2026, 10, 3, 8, 0, 0, 400));
      expect(await g.cleanupStale(), 0, reason: '新しいコマは残す');
      now = now.add(const Duration(minutes: 11));
      expect(await g.cleanupStale(), 1);
      expect(root.listSync(), isEmpty);
    });

    test('iOS (D-417): 配信を止めたら読み取る案内。拡張機能の id(小文字の UUID)を受け付ける', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      final ios = NativeScreenGlimpse(channel: const MethodChannel('rasq/screen_glimpse_ios'), broadcast: true);
      final android = NativeScreenGlimpse(channel: const MethodChannel('rasq/screen_glimpse_android'));
      addTearDown(ios.dispose);
      addTearDown(android.dispose);
      expect(isBroadcastGlimpse(ios), isTrue);
      expect(isBroadcastGlimpse(android), isFalse);
      expect(isBroadcastGlimpse(const DummyScreenGlimpse()), isFalse);
      expect(glimpseArmedHint(ios), contains('配信を止めて'));
      expect(glimpseArmedHint(android), contains('通知をタップ'));
      expect(isValidGlimpseId('3f2a9c1e-7b4d-4e8a-9f00-1a2b3c4d5e6f'), isTrue);
    });
  });
}

// ---------------------------------------------------------------------------

/// 1×1 の PNG。
final _png = Uint8List.fromList(base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=='));

/// 単色の左右 2 色の PNG(左 = 赤、右 = 青)。
Uint8List _synth(int w, int h) {
  final im = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (x < w ~/ 2) {
        im.setPixelRgb(x, y, 220, 30, 30);
      } else {
        im.setPixelRgb(x, y, 30, 30, 220);
      }
    }
  }
  return img.encodePng(im);
}

/// 画像の道具の記録つき。既定は送る画像を目印(`pick-a` …、選んだ順の画像ごと)の小さな JPEG にする。[real] なら本当に切り抜く。
class _PickHarness extends DiscoverImageTools {
  _PickHarness(this.images);
  final List<Uint8List> images;
  late _FakeCentral central;
  bool real = false;
  final limits = <int>[];
  final selections = <DiscoverSelection?>[];
  final prepared = <Uint8List?>[];

  @override
  Future<Size?> measure(Uint8List bytes) async => discoverImageSizeOf(bytes);

  @override
  Future<Uint8List?> prepare(Uint8List bytes, DiscoverSelection? selection) async {
    selections.add(selection);
    final i = images.indexWhere((b) => identical(b, bytes));
    final out = real ? prepareDiscoverImage(bytes, selection) : Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, ...utf8.encode('pick-${String.fromCharCode(97 + i)}')]);
    prepared.add(out);
    return out;
  }
}

class _FakeGlimpse extends DummyScreenGlimpse {
  _FakeGlimpse();
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

  /// §2 の応答の切り抜き(S-074: コマを送ると `frame` つき)。
  List<Map<String, Object?>> contentCrops = [
    {'x': 0.1, 'y': 0.1, 'w': 0.5, 'h': 0.5, 'label': 'ねこ'},
  ];
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
          'crops': contentCrops,
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
