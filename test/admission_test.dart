import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:rasq_client/features/settings/rasq_invites_screen.dart';
import 'package:rasq_client/features/vc/astell_providers.dart' show astellStreamErrorText;
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/sanctions.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/rasq_admission.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-548 (Central S-120 / ORGATE O-022 / Judge J-024): 入場の審査。審査待ちでも自分の SNS は使え、帯で案内する。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const pendingText = '審査中です。公開機能のみ制限中です。';

  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  /// 偽の Central(`/me/admission*` は admission-spec.md の「追記2」の形)。
  ({MockClient mock, _Admission a}) fake() {
    final a = _Admission();
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      final key = '${req.method} $path';
      a.calls.add(key);
      if (req.headers['authorization'] != 'Bearer device-token') return json({'error': {'code': '401', 'message': 'no token'}}, 401);
      switch (key) {
        case 'GET /me':
          return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'termsAccepted': true});
        case 'GET /me/admission':
          if (a.missing) return json({'error': {'code': '404', 'message': 'not found'}}, 404);
          return json(a.status());
        case 'POST /me/admission/code':
          final code = (jsonDecode(req.body) as Map)['code'] as String?;
          a.lastCode = code;
          // 追記2: 本人が waitlisted でなければ 409。
          if (a.state != 'waitlisted') return json({'error': {'code': 'admission_not_waitlisted', 'message': 'not waitlisted'}}, 409);
          final reason = a.badCodes[code];
          if (reason != null) return json({'error': {'code': 'admission_invite_invalid', 'message': 'invite code is not valid', 'reason': reason}}, 400);
          a.state = 'pending';
          a.waitReason = null;
          return json(a.status());
        case 'GET /me/admission/invites':
          return json({'items': a.invites, 'remaining': a.remaining});
        case 'POST /me/admission/invites':
          a.remaining--;
          a.invites.add({'id': 'inv-${a.invites.length + 1}', 'hint': 'K7', 'uses': 3, 'used': 0, 'expiresAt': '2026-11-05T00:00:00Z', 'revokedAt': null, 'createdAt': '2026-10-22T00:00:00Z'});
          return json({'id': 'inv-${a.invites.length}', 'code': 'K7PQ2MXR9A', 'uses': 3, 'expiresAt': '2026-11-05T00:00:00Z'});
        case 'POST /swings':
          // 止める口(公開の機能)。
          if (a.state != 'approved') return json({'error': {'code': 'admission_pending', 'message': 'the account is not admitted yet', 'admission': a.state}}, 403);
          return json({'id': 'sw-1'});
      }
      return json(<Object>[]);
    });
    return (mock: mock, a: a);
  }

  List<Override> overrides(MockClient mock, MemorySessionStorage storage) => [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ];

  MemorySessionStorage storage() => MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
      });

  Future<ProviderContainer> pump(WidgetTester tester, MockClient mock) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: overrides(mock, storage()), child: const RasqApp()));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  group('形', () {
    test('GET /me/admission の形を読む(追記2)', () {
      final a = RasqAdmission.fromJson({'admission': 'waitlisted', 'waitReason': 'capacity', 'position': 12, 'invites': {'canIssue': false, 'remaining': null}});
      expect(a.state, RasqAdmissionState.waitlisted);
      expect(a.waitReason, RasqWaitReason.capacity);
      expect(a.position, 12);
      expect(a.limited, isTrue);
      expect(a.canInvite, isFalse);
      final ok = RasqAdmission.fromJson({'admission': 'approved', 'waitReason': null, 'position': null, 'invites': {'canIssue': true, 'remaining': 2}});
      expect(ok.limited, isFalse);
      expect(ok.canInvite, isTrue);
      expect(ok.remaining, 2);
      expect(RasqAdmission.fromJson({'admission': 'rejected', 'invites': {'canIssue': true}}).limited, isFalse, reason: '断られたときは今の恒久の凍結の画面が扱う');
      expect(RasqAdmission.fromJson({'admission': 'rejected', 'invites': {'canIssue': true}}).canInvite, isFalse);
    });

    test('403 admission_pending は案内の文の例外になり、状態を知らせる', () async {
      final f = fake()..a.state = 'waitlisted';
      final client = OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: f.mock, tokenProvider: () => 'device-token');
      final seen = <String>[];
      final sub = OrgateClient.admissionBlocked.listen(seen.add);
      addTearDown(sub.cancel);
      try {
        await client.postJson('/swings', const {});
        fail('止められるはず');
      } on AdmissionPendingException catch (e) {
        expect(e.admission, 'waitlisted');
        expect(e.message, pendingText);
        expect('$e', pendingText, reason: '「403: …」のエラーの形にしない');
        expect(e.isReason('admission_pending'), isTrue);
        expect(astellStreamErrorText(e), pendingText, reason: 'AsTell の失敗の文にも案内のまま出す');
      }
      expect(seen, ['waitlisted']);
      f.a.state = 'rejected';
      await expectLater(client.postJson('/swings', const {}), throwsA(isA<AdmissionPendingException>().having((e) => e.message, 'message', contains('承認されませんでした'))));
    });

    test('止められたら、審査の状態を読み直す', () async {
      final f = fake();
      final c = ProviderContainer(overrides: overrides(f.mock, storage()));
      addTearDown(c.dispose);
      c.listen(rasqAdmissionProvider, (_, _) {});
      await c.read(orgateAccountProvider.future);
      expect((await c.read(rasqAdmissionProvider.future))!.state, RasqAdmissionState.approved);
      // 運営が審査を入れて、待ちに戻った(枠いっぱい など)。
      f.a.state = 'waitlisted';
      f.a.waitReason = 'capacity';
      await expectLater(c.read(centralClientProvider)!.postJson('/swings', const {}), throwsA(isA<AdmissionPendingException>()));
      for (var i = 0; i < 20 && c.read(rasqAdmissionProvider).value?.state != RasqAdmissionState.waitlisted; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(c.read(rasqAdmissionProvider).value!.state, RasqAdmissionState.waitlisted);
    });

    test('処置の分類 admission(断られた、追記3)は名前で出す。ほかの分類はサーバーの語のまま', () {
      expect(RasqSanctions.categoryLabel('admission'), '登録の審査');
      expect(RasqSanctionEntry.fromJson({'id': 's1', 'category': 'admission', 'level': 'permanent'}).categoryLabel, '登録の審査');
      expect(RasqSanctions.categoryLabel('spam'), 'spam');
    });

    test('審査の無い(古い)サーバー: 状態が読めなければ何も出さない', () async {
      final f = fake()..a.missing = true;
      final c = ProviderContainer(overrides: overrides(f.mock, storage()));
      addTearDown(c.dispose);
      c.listen(rasqAdmissionProvider, (_, _) {});
      await c.read(orgateAccountProvider.future);
      expect(await c.read(rasqAdmissionProvider.future), isNull);
      expect(f.a.calls, contains('GET /me/admission'));
    });
  });

  group('帯', () {
    testWidgets('pending: ホームに帯。自分の SNS の TL はそのまま見える。閉じられる', (tester) async {
      final f = fake()..a.state = 'pending';
      await pump(tester, f.mock);
      expect(find.byKey(const ValueKey('admission.banner')), findsOneWidget);
      expect(find.text(pendingText), findsOneWidget);
      expect(find.byKey(const ValueKey('admission.code')), findsNothing, reason: '審査待ちには招待コードの欄は出さない');
      expect(find.text(MockData.timeline(fakeSession().account).first.body), findsWidgets, reason: '自分の SNS の TL は止めない');
      await tester.tap(find.byKey(const ValueKey('admission.banner.close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('admission.banner')), findsNothing);
    });

    testWidgets('approved: 帯は出ない', (tester) async {
      final f = fake();
      await pump(tester, f.mock);
      expect(f.a.calls, contains('GET /me/admission'));
      expect(find.byKey(const ValueKey('admission.banner')), findsNothing);
    });

    testWidgets('waitlisted(枠待ち): 理由と順番の目安。招待コードの欄は出さない', (tester) async {
      final f = fake()
        ..a.state = 'waitlisted'
        ..a.waitReason = 'capacity'
        ..a.position = 7;
      await pump(tester, f.mock);
      expect(find.text('登録枠が埋まっているため順番待ちです(目安: 7 番目)'), findsOneWidget);
      expect(find.text(pendingText), findsOneWidget);
      expect(find.byKey(const ValueKey('admission.code')), findsNothing);
    });

    testWidgets('waitlisted(招待コード待ち): 欄に入れる → 効かない理由ごとの文 → 効けば審査待ちへ', (tester) async {
      final f = fake()
        ..a.state = 'waitlisted'
        ..a.waitReason = 'invite'
        ..a.badCodes.addAll({'NOPE000000': 'unknown', 'OLD0000000': 'expired', 'FULL000000': 'used_up', 'STOP000000': 'revoked'});
      final c = await pump(tester, f.mock);
      expect(find.text('招待コードを入れると審査に進みます'), findsOneWidget);
      Future<void> submit(String code) async {
        await tester.enterText(find.byKey(const ValueKey('admission.code')), code);
        await tester.tap(find.byKey(const ValueKey('admission.code.submit')));
        await tester.pumpAndSettle();
      }

      for (final (code, text) in [
        ('NOPE000000', '招待コードが見つかりません。'),
        ('OLD0000000', 'この招待コードは期限が切れています'),
        ('FULL000000', 'この招待コードは利用上限に達しています'),
        ('STOP000000', 'この招待コードは無効です'),
      ]) {
        await submit(code);
        expect(find.text(text), findsOneWidget, reason: code);
      }
      await submit(' K7PQ2MXR9A ');
      expect(f.a.lastCode, 'K7PQ2MXR9A');
      expect(c.read(rasqAdmissionProvider).value!.state, RasqAdmissionState.pending);
      expect(find.byKey(const ValueKey('admission.code')), findsNothing);
      expect(find.text('招待コードを受け付けました。審査が通るまでお待ちください'), findsOneWidget);
      expect(find.text(pendingText), findsOneWidget);
    });

    testWidgets('招待コード待ちでなくなっていたら(409 admission_not_waitlisted)、知らせて状態を読み直す', (tester) async {
      final f = fake()
        ..a.state = 'waitlisted'
        ..a.waitReason = 'invite';
      final c = await pump(tester, f.mock);
      expect(find.byKey(const ValueKey('admission.code')), findsOneWidget);
      // ほかの端末でコードを入れて、もう審査待ち。
      f.a.state = 'pending';
      f.a.waitReason = null;
      await tester.enterText(find.byKey(const ValueKey('admission.code')), 'K7PQ2MXR9A');
      await tester.tap(find.byKey(const ValueKey('admission.code.submit')));
      await tester.pumpAndSettle();
      expect(find.text('いまは招待コードを入れる必要はありません'), findsOneWidget);
      expect(c.read(rasqAdmissionProvider).value!.state, RasqAdmissionState.pending);
      expect(find.byKey(const ValueKey('admission.code')), findsNothing);
      expect(find.text(pendingText), findsOneWidget);
    });
  });

  group('招待コードの画面', () {
    testWidgets('通っていて出せる設定なら、アカウントの設定に入口。出す → 平文はその場だけ・コピー → 一覧は一部だけ', (tester) async {
      final f = fake()
        ..a.canIssue = true
        ..a.remaining = 2;
      final c = await pump(tester, f.mock);
      c.read(routerProvider).push('${Routes.settings}/security');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const ValueKey('security.invites')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('security.invites')));
      await tester.pumpAndSettle();
      expect(find.byType(RasqInvitesScreen), findsOneWidget);
      expect(find.text('あと 2 個出せます'), findsOneWidget);
      expect(find.text('まだ出していません'), findsOneWidget);
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.tap(find.byKey(const ValueKey('invites.issue')));
      await tester.pumpAndSettle();
      expect(find.text('K7PQ2MXR9A'), findsOneWidget);
      expect(find.text('あと 1 個出せます'), findsOneWidget);
      expect(find.text('K7…'), findsOneWidget, reason: '一覧はコードの一部だけ');
      await tester.tap(find.byKey(const ValueKey('invites.issued.copy')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('invites.issued.share')));
      await tester.pump();
      expect(copied, ['K7PQ2MXR9A', 'RASQ に招待します。アカウントを作るときに、招待コード K7PQ2MXR9A を入れてください']);
      // 開き直すと、平文はもう無い。
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('security.invites')));
      await tester.pumpAndSettle();
      expect(find.text('K7PQ2MXR9A'), findsNothing);
      expect(find.text('K7…'), findsOneWidget);
    });

    testWidgets('出せない設定 / 審査待ちなら入口を出さない', (tester) async {
      final f = fake()
        ..a.state = 'pending'
        ..a.canIssue = true;
      final c = await pump(tester, f.mock);
      c.read(routerProvider).push('${Routes.settings}/security');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('security.invites'), skipOffstage: false), findsNothing);
    });
  });
}

class _Admission {
  String state = 'approved';
  String? waitReason;
  int? position;
  bool canIssue = false;
  int remaining = 0;
  bool missing = false;
  final badCodes = <String, String>{};
  final invites = <Map<String, Object?>>[];
  final calls = <String>[];
  String? lastCode;

  Map<String, Object?> status() => {
        'admission': state,
        'waitReason': waitReason,
        'position': position,
        'invites': {'canIssue': canIssue && state == 'approved', 'remaining': canIssue ? remaining : null},
      };
}
