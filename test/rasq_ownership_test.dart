import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/profile/rasq_account_page_screen.dart';
import 'package:rasq_client/features/profile/rasq_ownership_screens.dart';
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// 持ち主の確認と Keybase (D-313)。サーバーは MockClient で Central の口をまねる。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
  http.Response err(String code, String message, int status) => json({'error': {'code': code, 'message': message}}, status);
  OrgateException ex(String code, String message) => OrgateException(ErrorCode.tryParse(code)!, message);

  Future<ProviderContainer> pump(WidgetTester tester, MockClient mock, {bool loggedIn = true, List<Post> Function(AccountId)? posts}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      if (loggedIn) OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: posts ?? MockData.timeline))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  /// 画面の中を、見えるまでスクロールしてから押す(ListView は見えていない行を作らない)。
  Future<void> tapIn(WidgetTester tester, Type screen, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.scrollUntilVisible(f, 150, scrollable: find.descendant(of: find.byType(screen), matching: find.byType(Scrollable)).first);
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
  }

  Map<String, Object?> link(String kind, String instance, String handle, {bool verified = false, String? method, String visibility = 'show'}) => {
        'accountKey': '$kind:$instance:$handle',
        'kind': kind,
        'instance': instance,
        'handle': handle,
        'pluginId': 'p',
        'displayName': handle,
        'visibility': visibility,
        'autoVisible': true,
        'visible': true,
        'verified': verified,
        'verifiedMethod': method,
      };

  group('モデルと言葉', () {
    test('タイル / 行 / 公開ページ / me が確認と Keybase を読む', () {
      final t = RasqSnsTile.fromJson({'kind': 'misskey', 'instance': 'm.example', 'handle': 'taro', 'verified': true, 'verifiedMethod': 'keybase'});
      expect((t.verified, t.verifiedLabel, t.key), (true, 'Keybase の証明で確認済み', 'misskey:m.example:taro'));
      expect(RasqSnsTile.fromJson(const {'kind': 'misskey', 'instance': 'm', 'handle': 'x'}).verified, isFalse);
      expect(RasqSnsTile.fromJson(const {'kind': 'misskey', 'instance': 'm', 'handle': 'x', 'verified': true, 'verifiedMethod': 'profile'}).verifiedLabel, 'プロフィールで確認済み');
      final p = RasqPublicProfile.fromJson({'id': 'a', 'handle': 'taro', 'displayName': '', 'keybase': {'username': 'taro_kb', 'verifiedAt': '2026-09-24T00:00:00Z'}});
      expect((p.keybase!.username, p.keybase!.profileUrl.toString()), ('taro_kb', 'https://keybase.io/taro_kb'));
      expect(RasqPublicProfile.fromJson(const {'id': 'a', 'handle': 'taro', 'displayName': '', 'keybase': null}).keybase, isNull);
      expect(RasqAccount.fromJson(const {'id': 'a', 'handle': 'x', 'displayName': '', 'keybase': {'username': 'kb'}}).keybase!.username, 'kb');
      expect(RasqAccount.fromJson(const {'id': 'a', 'handle': 'x', 'displayName': ''}).keybase, isNull);
      final s = RasqSnsVerifyStart.fromJson(const {'code': 'rasq-verify-abc', 'text': 'RASQ: @taro rasq-verify-abc', 'expiresAt': '2026-09-25T00:00:00Z', 'where': ['bio', 'fields']});
      expect((s.text, s.expiresAt != null), ('RASQ: @taro rasq-verify-abc', true));
      expect(s.where, ['bio', 'fields']);
      final st = RasqKeybaseStatus.fromJson(const {'keybase': {'username': 'kb', 'verifiedAt': '2026-09-24T00:00:00Z'}, 'verifiedLinks': ['mastodon:m.example:taro']});
      expect(st.keybase!.username, 'kb');
      expect(st.verifiedLinks, ['mastodon:m.example:taro']);
    });

    test('どこに貼るか / エラーの言い換え', () {
      expect(rasqVerifyWhere('misskey', ['bio', 'fields']), contains('追加情報'));
      expect(rasqVerifyWhere('mastodon', ['bio', 'fields']), contains('補足情報'));
      expect(rasqVerifyWhere('bluesky', ['bio']), contains('自己紹介'));
      expect(rasqVerifyWhere('bluesky', ['bio']), isNot(contains('項目')));
      expect(rasqVerifyMessage(ex('409', 'the code was not found in the public profile (bio or profile fields)')), contains('見つかりませんでした'));
      expect(rasqVerifyMessage(ex('409', 'no verification in progress; call verify/start first')), contains('確認の文を作る'));
      expect(rasqVerifyMessage(ex('409', 'the public profile of that sns account was not found')), contains('公開のプロフィールが見つかりません'));
      expect(rasqVerifyMessage(ex('409', 'could not read the public profile: timed out')), contains('読めませんでした'));
      expect(rasqVerifyMessage(ex('429', 'too many attempts; retry in 60 seconds')), contains('回数が多すぎます'));
      expect(rasqVerifyMessage(ex('400', 'verifying this kind of sns account is not supported yet')), contains('対応していません'));
      expect(rasqKeybaseMessage(ex('400', 'signature: signature does not verify')), contains('BEGIN KEYBASE'));
      expect(rasqKeybaseMessage(ex('400', 'the signed text is not the statement; sign exactly the statement')), contains('文が違います'));
      expect(rasqKeybaseMessage(ex('400', 'the signature was not made with a current key of keybase user x')), contains('鍵で署名されていません'));
      expect(rasqKeybaseMessage(ex('409', 'that keybase account is linked to another rasq account')), contains('別の RASQ アカウント'));
      expect(rasqKeybaseMessage(ex('B03', 'keybase: HTTP 500')), contains('Keybase に繋がりませんでした'));
    });
  });

  testWidgets('持ち主の確認: 編集画面の「持ち主を確認」→ 文を作る(コピー / 貼る場所)→ 見つからない 409 → 貼って確認 → 確認済み。戻ると編集画面にも印', (tester) async {
    final links = [link('misskey', 'm.example', 'taro'), link('mixi2', 'mixi.social', 'taro')];
    final calls = <String>[];
    var pasted = false;
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
      if (req.method == 'GET' && path == '/me/sns-accounts') return json(links);
      if (req.method == 'POST' && path.endsWith('/verify/start')) {
        calls.add('start ${Uri.decodeComponent(path.split('/')[3])}');
        return json({'code': 'rasq-verify-q1w2e3r4t5y6', 'text': 'RASQ: @taro rasq-verify-q1w2e3r4t5y6', 'expiresAt': '2026-09-25T00:00:00Z', 'where': ['bio', 'fields']});
      }
      if (req.method == 'POST' && path.endsWith('/verify/check')) {
        calls.add('check');
        if (!pasted) return err('409', 'the code was not found in the public profile (bio or profile fields)', 409);
        links[0] = link('misskey', 'm.example', 'taro', verified: true, method: 'profile');
        return json({'link': links[0], 'notice': 'verified; you may now remove the text from your profile'});
      }
      return err('404', 'not found', 404);
    });
    final c = await pump(tester, mock);
    c.read(routerProvider).push('${Routes.settings}/rasq-profile');
    await tester.pumpAndSettle();
    expect(find.byType(RasqProfileEditScreen), findsOneWidget);
    final scrollable = find.descendant(of: find.byType(RasqProfileEditScreen), matching: find.byType(Scrollable)).first;
    final open = find.byKey(const ValueKey('rasqProfile.verify.misskey:m.example:taro'));
    await tester.scrollUntilVisible(open, 200, scrollable: scrollable);
    // 公開のプロフィールを読めない種類には、ボタンを出さない。
    expect(find.byKey(const ValueKey('rasqProfile.verify.mixi2:mixi.social:taro')), findsNothing);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.byType(RasqSnsVerifyScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('snsVerify.text')), findsNothing);

    // 文を作る → 貼る文と、Misskey での貼る場所。アプリからは書き換えない。
    await tapIn(tester, RasqSnsVerifyScreen, 'snsVerify.start');
    await tester.pumpAndSettle();
    expect(calls, ['start misskey:m.example:taro']);
    expect(find.text('RASQ: @taro rasq-verify-q1w2e3r4t5y6'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('snsVerify.where'))).data, contains('追加情報'));
    expect(find.textContaining('書き換えることはしません'), findsOneWidget);
    await tapIn(tester, RasqSnsVerifyScreen, 'snsVerify.copy');
    await tester.pump();
    expect(find.text('確認の文をコピーしました'), findsOneWidget);
    // スナックバーを片付ける(下のボタンに重なるので)。
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    // まだ貼っていない → 言い換えたエラー。
    await tapIn(tester, RasqSnsVerifyScreen, 'snsVerify.check');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('snsVerify.error')), findsOneWidget);
    expect(find.textContaining('確認の文が見つかりませんでした'), findsOneWidget);

    // 貼った → 確認済み。文は消してよい、と出す。
    pasted = true;
    await tapIn(tester, RasqSnsVerifyScreen, 'snsVerify.check');
    await tester.pumpAndSettle();
    expect(calls, ['start misskey:m.example:taro', 'check', 'check']);
    expect(find.byKey(const ValueKey('snsVerify.done')), findsOneWidget);
    expect(find.byKey(const ValueKey('snsVerify.removeHint')), findsOneWidget);
    expect(find.byKey(const ValueKey('snsVerify.check')), findsNothing);
    expect(find.byKey(const ValueKey('rasqPage.tile.verified.misskey:m.example:taro')), findsOneWidget);

    // 戻る → 編集画面の行も「確認済み」。
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    expect(find.byType(RasqProfileEditScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqProfile.verified.misskey:m.example:taro')), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqProfile.verify.misskey:m.example:taro')), findsNothing);
  });

  testWidgets('Keybase: ユーザー名 → 文とコマンド(コピー)→ 署名を貼る → 違う署名は言い換えて出す → 正しい署名でつながる → 証明を読み直す → 外す', (tester) async {
    Map<String, Object?>? keybase;
    final verifyBodies = <Map<String, Object?>>[];
    const statement = 'RASQ: I am @taro on RASQ and taro_kb on Keybase. nonce 00112233445566778899aabbccddeeff';
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'keybase': keybase});
      if (req.method == 'POST' && path == '/me/keybase/start') {
        final body = (jsonDecode(req.body) as Map).cast<String, Object?>();
        if (body['username'] != 'taro_kb') return err('400', 'username must be a keybase username (2-16 characters: a-z, 0-9, _)', 400);
        return json({'username': 'taro_kb', 'statement': statement, 'command': "keybase sign -m '$statement'", 'expiresAt': '2026-09-25T00:00:00Z'});
      }
      if (req.method == 'POST' && path == '/me/keybase/verify') {
        final body = (jsonDecode(req.body) as Map).cast<String, Object?>();
        verifyBodies.add(body);
        if (body['signature'] == null) return json({'keybase': keybase, 'verifiedLinks': ['mastodon:m.example:taro']});
        if (!'${body['signature']}'.startsWith('BEGIN KEYBASE SALTPACK SIGNED MESSAGE.')) return err('400', 'signature: not an armored saltpack signed message: no body', 400);
        keybase = {'username': 'taro_kb', 'verifiedAt': '2026-09-24T01:02:00Z'};
        return json({'keybase': keybase, 'verifiedLinks': []});
      }
      if (req.method == 'DELETE' && path == '/me/keybase') {
        keybase = null;
        return http.Response('', 204);
      }
      return err('404', 'not found', 404);
    });
    final c = await pump(tester, mock);
    c.read(routerProvider).push(Routes.rasqKeybase);
    await tester.pumpAndSettle();
    expect(find.byType(RasqKeybaseScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('keybase.command')), findsNothing);

    // おかしなユーザー名 → サーバーの 400 を言い換える。
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('keybase.username')), matching: find.byType(TextField)), 'Not-OK');
    await tapIn(tester, RasqKeybaseScreen, 'keybase.start');
    await tester.pumpAndSettle();
    expect(find.textContaining('Keybase のユーザー名(英小文字'), findsOneWidget);

    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('keybase.username')), matching: find.byType(TextField)), '@taro_kb');
    await tapIn(tester, RasqKeybaseScreen, 'keybase.start');
    await tester.pumpAndSettle();
    expect(find.text("keybase sign -m '$statement'"), findsOneWidget);
    expect(find.textContaining(statement), findsWidgets);
    await tapIn(tester, RasqKeybaseScreen, 'keybase.copy');
    await tester.pump();
    expect(find.text('コマンドをコピーしました'), findsOneWidget);
    // スナックバーを片付ける(下のボタンに重なるので)。
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).last)).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    // 署名でないもの → 400 を言い換える。
    await tester.scrollUntilVisible(find.byKey(const ValueKey('keybase.signature')), 150, scrollable: find.descendant(of: find.byType(RasqKeybaseScreen), matching: find.byType(Scrollable)).first);
    final sig = find.descendant(of: find.byKey(const ValueKey('keybase.signature')), matching: find.byType(TextField));
    await tester.enterText(sig, 'hello');
    await tapIn(tester, RasqKeybaseScreen, 'keybase.verify');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('keybase.error')), findsOneWidget);
    expect(find.textContaining('署名を読めませんでした'), findsOneWidget);

    // 正しい署名 → つながり、/me を読み直して「Keybase: @taro_kb」。
    await tester.enterText(sig, 'BEGIN KEYBASE SALTPACK SIGNED MESSAGE. abc. END KEYBASE SALTPACK SIGNED MESSAGE.');
    await tapIn(tester, RasqKeybaseScreen, 'keybase.verify');
    await tester.pumpAndSettle();
    expect(verifyBodies.last, {'signature': 'BEGIN KEYBASE SALTPACK SIGNED MESSAGE. abc. END KEYBASE SALTPACK SIGNED MESSAGE.'});
    expect(find.text('Keybase: @taro_kb'), findsOneWidget);
    expect(c.read(orgateAccountProvider).value!.keybase!.username, 'taro_kb');
    expect(find.byKey(const ValueKey('keybase.signature')), findsNothing);

    // 証明を読み直す(署名なし)。
    await tapIn(tester, RasqKeybaseScreen, 'keybase.refresh');
    await tester.pumpAndSettle();
    expect(verifyBodies.last, isEmpty);
    expect(find.textContaining('1 件も確認済み'), findsOneWidget);

    // 外す。
    await tapIn(tester, RasqKeybaseScreen, 'keybase.unlink');
    await tester.pumpAndSettle();
    expect(c.read(orgateAccountProvider).value!.keybase, isNull);
    expect(find.byKey(const ValueKey('keybase.username')), findsOneWidget);
    expect(find.textContaining('Keybase を外しました'), findsOneWidget);
  });

  testWidgets('印: アカウントページのタイル(確認済みだけ)と「Keybase: @user」、編集画面の Keybase の行', (tester) async {
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'keybase': {'username': 'taro_kb', 'verifiedAt': '2026-09-24T00:00:00Z'}});
      if (req.method == 'GET' && path == '/accounts/taro') {
        return json({
          'id': 'acc-1',
          'handle': 'taro',
          'displayName': 'タロ',
          'keybase': {'username': 'taro_kb', 'verifiedAt': '2026-09-24T00:00:00Z'},
          'snsAccounts': [
            {'kind': 'misskey', 'instance': 'm.example', 'handle': 'taro', 'verified': true, 'verifiedMethod': 'profile'},
            {'kind': 'mastodon', 'instance': 'masto.example', 'handle': 'taro', 'verified': false},
          ],
        });
      }
      if (req.method == 'GET' && path == '/accounts/taro/posts') return json({'source': 'rasq', 'limit': 3, 'posts': []});
      if (req.method == 'GET' && path == '/me/sns-accounts') return json([]);
      return err('404', 'not found', 404);
    });
    final c = await pump(tester, mock);
    c.read(routerProvider).push(Routes.rasqAccount('taro'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqAccountPageScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.tile.verified.misskey:m.example:taro')), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.tile.verified.mastodon:masto.example:taro')), findsNothing);
    expect(find.byKey(const ValueKey('rasqPage.tile.mastodon:masto.example:taro')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('rasqPage.keybase')), matching: find.text('Keybase: @taro_kb')), findsOneWidget);

    c.read(routerProvider).push('${Routes.settings}/rasq-profile');
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('rasqProfile.keybase'));
    await tester.scrollUntilVisible(row, 200, scrollable: find.descendant(of: find.byType(RasqProfileEditScreen), matching: find.byType(Scrollable)).first);
    expect(find.descendant(of: row, matching: find.text('Keybase: @taro_kb')), findsOneWidget);
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(RasqKeybaseScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('keybase.linked')), findsOneWidget);
  });

  testWidgets('SNS のプロフィールの「RASQ アカウント」欄: 見ているアカウントが確認済みなら印、ほかのタイルにも印', (tester) async {
    const bob = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'bob');
    final bobUser = UserSummary(id: 'bob', account: bob, displayName: 'ボブ');
    final posts = [Post(id: 'p1', account: fakeSession().account, author: bobUser, createdAt: DateTime(2026, 9, 1), body: 'こんにちは')];
    for (final verified in [true, false]) {
      final mock = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        if (req.method == 'GET' && path == '/accounts/by-sns') {
          return json({
            'account': {'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'},
            'snsAccounts': [
              {'kind': 'misskey', 'instance': 'example.test', 'handle': 'bob', 'verified': verified, 'verifiedMethod': verified ? 'profile' : null},
              {'kind': 'mastodon', 'instance': 'masto.example', 'handle': 'bob', 'verified': true, 'verifiedMethod': 'keybase'},
            ],
          });
        }
        return err('404', 'not found', 404);
      });
      final c = await pump(tester, mock, loggedIn: false, posts: (_) => posts);
      c.read(routerProvider).push('/user/bob', extra: bobUser);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('snsProfile.rasq')), findsOneWidget);
      expect(find.byKey(const ValueKey('snsProfile.rasq.verified')), verified ? findsOneWidget : findsNothing);
      expect(find.byKey(const ValueKey('rasqPage.tile.verified.mastodon:masto.example:bob')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
