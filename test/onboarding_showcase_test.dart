import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart' show orgateTokenHolderProvider;
import 'package:rasq_client/backend/server_info_api.dart';
import 'package:rasq_client/features/collections/rasq_collection_screen.dart';
import 'package:rasq_client/features/login/sns_login_screen.dart';
import 'package:rasq_client/features/onboarding/onboarding_previews.dart';
import 'package:rasq_client/features/onboarding/onboarding_screen.dart';
import 'package:rasq_client/features/onboarding/rasq_account_nudge.dart';
import 'package:rasq_client/features/onboarding/rasq_register_screen.dart' show RasqRegisterScreen;
import 'package:rasq_client/features/onboarding/server_signup.dart';
import 'package:rasq_client/features/onboarding/showcase_genres.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_client/features/rai/rai_reference.dart' show RaiEmbedder;
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart' show MisskeyPlugin;

import 'support/fakes.dart';

/// オンボーディングのサーバー / RASQ リストのタイルと、タップから始める登録 (D-412)。
void main() {
  const host = 'misskey.io';
  const viewer = AccountId(kind: SnsKind.misskey, instance: host, handle: '-');

  Post post(String id, String body, {String? cw, String? replyToId, String visibility = 'public', bool sensitive = false, String handle = 'taro', String instance = host}) => Post(
        id: id,
        account: viewer,
        author: UserSummary(id: 'u-$handle', account: AccountId(kind: SnsKind.misskey, instance: instance, handle: handle), displayName: handle),
        createdAt: DateTime(2026, 10, 1),
        body: body,
        contentWarning: cw,
        replyToId: replyToId,
        visibility: visibility,
        media: [if (sensitive) MediaItem(id: 'm', type: MediaType.image, url: Uri.parse('https://$instance/m.png'), sensitive: true)],
        counts: const {'reactions': 12, 'renotes': 3},
      );

  group('ジャンルの判定と見本の選び方', () {
    test('語の辞書: ジャンルの分かる投稿だけに付く(挨拶・雑談には付かない、英字は語の境目で)', () {
      expect(ShowcaseGenreClassifier.byWords('スプラの新シーズン始まったのでガチマッチ回してる')?.genre.id, 'game');
      expect(ShowcaseGenreClassifier.byWords('駅前の新しいラーメン屋、スープが濃厚でおいしかった')?.genre.id, 'food');
      expect(ShowcaseGenreClassifier.byWords('Rustで書いたCLIツールをようやく公開できた')?.genre.id, 'tech');
      expect(ShowcaseGenreClassifier.byWords('おはようございます、今日も一日がんばろう'), isNull);
      expect(ShowcaseGenreClassifier.byWords('she said hello'), isNull, reason: '「ai」は語の境目でだけ当たる');
    });

    test('出してはいけない投稿(CW / 返信 / 公開以外 / センシティブな添付 / 短い)は落とし、ジャンルの違う強い投稿を選ぶ', () async {
      final cands = [
        ShowcaseCandidate(post: post('cw', 'スプラの新シーズン始まったのでガチマッチ回してる', cw: 'ネタバレ'), score: 9),
        ShowcaseCandidate(post: post('reply', 'スプラの新シーズン始まったのでガチマッチ回してる', replyToId: 'x'), score: 9),
        ShowcaseCandidate(post: post('home', 'スプラの新シーズン始まったのでガチマッチ回してる', visibility: 'home'), score: 9),
        ShowcaseCandidate(post: post('nsfw', 'スプラの新シーズン始まったのでガチマッチ回してる', sensitive: true), score: 9),
        ShowcaseCandidate(post: post('short', 'ポケモン'), score: 9),
        ShowcaseCandidate(post: post('marked', 'スプラの新シーズン始まったのでガチマッチ回してる', handle: 'たろう🔞'), score: 9),
        ShowcaseCandidate(post: post('chat', 'おはようございます、今日も一日がんばりましょう'), score: 8),
        ShowcaseCandidate(post: post('game1', 'スプラの新シーズン始まったのでガチマッチ回してる'), score: 5),
        ShowcaseCandidate(post: post('game2', 'ポケモンの色違いやっと出た、3時間粘った甲斐があった'), score: 4),
        ShowcaseCandidate(post: post('food', '駅前の新しいラーメン屋、スープが濃厚でおいしかった'), score: 1),
        ShowcaseCandidate(post: post('cat', 'うちの猫が箱から出てこない、ずっと寝てる'), score: 0.5),
      ];
      final picks = await selectShowcasePosts(cands, ShowcaseGenreClassifier(), max: 3);
      expect([for (final p in picks) p.post.id], ['game1', 'food', 'cat'], reason: '同じジャンルは後回し(game2 は 4 件目以降)');
      expect([for (final p in picks) p.genre.genre.label], ['ゲーム', '食べ物', '動物・ペット']);
    });

    test('RASQ MiniLM があれば、辞書に無い言い回しもモデルで拾う(しきい値: 近さ・差・ジャンルの無い文より近い)', () async {
      final picks = await selectShowcasePosts(
        [ShowcaseCandidate(post: post('fluffy', 'ふわふわの毛玉がひざの上で丸くなっている'), score: 1), ShowcaseCandidate(post: post('hi', 'ふつうの一日でした、とくに何もなかったです'), score: 1)],
        ShowcaseGenreClassifier(embedder: _FakeMiniLm()),
      );
      expect(picks.single.post.id, 'fluffy');
      expect(picks.single.genre.genre.id, 'animal');
      expect(picks.single.genre.byModel, isTrue);
      expect(ShowcaseGenreClassifier.isRasqMiniLm(_FakeMiniLm()), isTrue);
    });

    test('本文は文字だけに(MFM の関数・絵文字の名前・タグを外す)', () {
      expect(showcasePlainText(r'今日は $[tada すごい] 日 :blobcat: <small>小</small> 10:30:00'), '今日は すごい 日 小 10:30:00');
    });
  });

  group('タイル', () {
    testWidgets('サーバーのタイル: サーバー情報の下に、ジャンルの分かる見本だけ(CW / 返信 / 雑談は出さない)', (tester) async {
      await _pumpWide(tester, _central());
      expect(find.byKey(const ValueKey('onboarding.previews.sns')), findsNothing, reason: '「おすすめの SNS」は外した');
      expect(find.text('おすすめの SNS'), findsNothing);
      final tile = find.byKey(const ValueKey('onboarding.server.$host'));
      expect(tile, findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byKey(const ValueKey('server.tile.$host'))), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('このサーバーに登録')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byType(ShowcasePostCard)), findsNWidgets(2));
      expect(find.descendant(of: tile, matching: find.text('ゲーム')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('食べ物')), findsOneWidget);
      expect(find.textContaining('ネタバレ注意の'), findsNothing, reason: 'CW つきは出さない');
      expect(find.textContaining('それな'), findsNothing, reason: '返信は出さない');
      expect(find.textContaining('今日もいちにち'), findsNothing, reason: 'ジャンルの分からない雑談は出さない');
    });

    testWidgets('RASQ リストのタイル: リストの情報の下に、公開のスナップショットからの見本', (tester) async {
      await _pumpWide(tester, _central());
      final tile = find.byKey(const ValueKey('onboarding.list.list-1'));
      await tester.scrollUntilVisible(tile, 200, scrollable: find.descendant(of: find.byKey(const ValueKey('onboarding.previews')), matching: find.byType(Scrollable)).first);
      expect(find.descendant(of: tile, matching: find.text('ねこ好きの集まり')), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byType(ShowcasePostCard)), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text('動物・ペット')), findsOneWidget);
      expect(find.textContaining('フォロワー限定の'), findsNothing, reason: '公開の投稿だけ');
    });

    testWidgets('狭い画面: 入口から見本のページを開ける(2 カラムにはしない)', (tester) async {
      await _pumpWide(tester, _central(), size: const Size(360, 640));
      expect(find.byType(OnboardingPreviewColumn), findsNothing);
      await tester.tap(find.byKey(const ValueKey('onboarding.showcase')));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingShowcaseScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('onboarding.server.$host')), findsOneWidget);
    });
  });

  group('タップから登録', () {
    testWidgets('投稿をタップ → 登録ページ(WebView)+ RAi の案内 →「登録できた」→ ログイン → その投稿を開く', (tester) async {
      final plugin = _SignupPlugin();
      // ブラウザを開く口(MiAuth の URL)は開けたことにする。
      final launched = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
        launched.add('${(call.arguments as Map?)?['url']}');
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), null));
      final container = await _pumpWide(tester, _central(), plugin: plugin);
      await tester.tap(find.byKey(ValueKey('onboarding.post.${post('g1', '').key}')));
      await tester.pumpAndSettle();
      // 登録ページ: WebView(テストでは差し替え)にサーバーのトップ、横に RAi の案内。
      expect(find.byType(ServerSignupScreen), findsOneWidget);
      expect(find.text('fake web: https://misskey.io/'), findsOneWidget);
      expect(container.read(serverSignupTargetProvider)?.post?.id, 'g1');
      expect(find.byKey(const ValueKey('signup.guide.count')), findsOneWidget);
      expect(tester.widget<Text>(find.byKey(const ValueKey('signup.guide.count'))).data, '1/5');
      expect(find.textContaining('「新規登録」を押してください'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('signup.guide.next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ユーザー名とパスワード'), findsOneWidget);
      // 「登録できた」→ いつものログイン(サーバーは入れてあり、すぐ確かめる)。
      await tester.tap(find.byKey(const ValueKey('signup.done')));
      await tester.pumpAndSettle();
      expect(find.byType(SnsLoginScreen), findsOneWidget);
      await tester.tap(find.text('ブラウザで認証する (MiAuth)'));
      await tester.pumpAndSettle();
      expect(launched, ['https://misskey.io/miauth/x']);
      await tester.tap(find.text('認証を確認'));
      // ホームは読み込みの印が回り続けるので、時間で進める。
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // ログインできた → 新しいアカウントで引き直した投稿を開く。
      expect(container.read(sessionsProvider).value!.isLoggedIn, isTrue);
      expect(find.byType(PostDetailScreen), findsOneWidget);
      expect(tester.widget<PostDetailScreen>(find.byType(PostDetailScreen)).postId, 'g1');
      expect(tester.widget<PostDetailScreen>(find.byType(PostDetailScreen)).initial?.account, _SignupPlugin.me, reason: '新しいアカウントの投稿として');
      expect(container.read(serverSignupTargetProvider), isNull, reason: '使ったら消す');
    });

    testWidgets('RASQ リストの「登録する」→ リストの人のサーバーへ登録 → ログインしたらリストを開く', (tester) async {
      final container = await _pumpWide(tester, _central(), plugin: _SignupPlugin());
      final tile = find.byKey(const ValueKey('onboarding.list.list-1'));
      await tester.scrollUntilVisible(tile, 200, scrollable: find.descendant(of: find.byKey(const ValueKey('onboarding.previews')), matching: find.byType(Scrollable)).first);
      await tester.tap(find.descendant(of: tile, matching: find.text('登録する')));
      await tester.pumpAndSettle();
      expect(find.byType(ServerSignupScreen), findsOneWidget);
      final target = container.read(serverSignupTargetProvider)!;
      expect((target.host, target.list?.id, target.post), ('misskey.io', 'list-1', null));
      expect(signupGuideSteps(target).last, contains('RASQ リスト「ねこ好きの集まり」を開きます'));
      await container.read(sessionsProvider.notifier).add(await _Flow().complete());
      await followSignupTarget(container, _SignupPlugin.me);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RasqCollectionScreen), findsOneWidget);
      expect(container.read(serverSignupTargetProvider), isNull);
    });

    testWidgets('RASQ アカウントのポップアップ (D-413): タイルから登録した最初のオンボーディングが終わったら 1 回だけ(作る / ログイン / あとで)。もう出さない', (tester) async {
      final storage = MemorySessionStorage({});
      final container = await _pumpWide(tester, _central(), plugin: _SignupPlugin(), storage: storage);
      final tile = find.byKey(const ValueKey('onboarding.list.list-1'));
      await tester.scrollUntilVisible(tile, 200, scrollable: find.descendant(of: find.byKey(const ValueKey('onboarding.previews')), matching: find.byType(Scrollable)).first);
      await tester.tap(find.descendant(of: tile, matching: find.text('登録する')));
      await tester.pumpAndSettle();
      expect(find.text('RASQ アカウントを作りますか?'), findsNothing, reason: '登録の途中では聞かない');
      // ログインできた → ホーム(SNS のログインと同じ流れ)→ タップしたものを開く → ポップアップ。
      await container.read(sessionsProvider.notifier).add(await _Flow().complete());
      container.read(routerProvider).go(Routes.home);
      await followSignupTarget(container, _SignupPlugin.me);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RasqCollectionScreen), findsOneWidget, reason: 'タップしたリストは開く');
      expect(find.text('RASQ アカウントを作りますか?'), findsOneWidget);
      expect(find.byKey(const ValueKey('rasqNudge.create')), findsOneWidget);
      expect(find.byKey(const ValueKey('rasqNudge.login')), findsOneWidget);
      expect(await storage.read(rasqAccountNudgeKey), isNotNull, reason: '出したことを残す');
      await tester.tap(find.byKey(const ValueKey('rasqNudge.later')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('RASQ アカウントを作りますか?'), findsNothing);
      // 2 回目(もう一度タイルから登録した)は出さない。
      await requestRasqAccountNudge(container);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('RASQ アカウントを作りますか?'), findsNothing);
      expect(container.read(rasqAccountNudgeProvider), isFalse);
    });

    testWidgets('RASQ アカウントのポップアップ (D-413): 「作る」は登録のページ (/rasq-register) へ', (tester) async {
      final container = await _pumpWide(tester, _central(), plugin: _SignupPlugin());
      await container.read(sessionsProvider.notifier).add(await _Flow().complete());
      container.read(routerProvider).go(Routes.home);
      await requestRasqAccountNudge(container);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.byKey(const ValueKey('rasqNudge.create')));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(RasqRegisterScreen), findsOneWidget);
    });

    testWidgets('RASQ アカウントのポップアップ (D-413): Central の RASQ アカウントをもう持っている人には出さない', (tester) async {
      final storage = MemorySessionStorage({
        RasqAccountsNotifier.storageKey: jsonEncode({
          'accounts': [
            {'id': 'central-c1', 'kind': 'central', 'handle': 'me', 'displayName': 'me', 'centralAccountId': 'c1', 'sessionKeys': <String>[], 'createdAt': '2026-10-01T00:00:00Z'},
          ],
          'current': 'central-c1',
          'onboardingDone': true,
        }),
      });
      final container = await _pumpWide(tester, _central(), plugin: _SignupPlugin(), storage: storage);
      await tester.runAsync(() => container.read(rasqAccountsProvider.future));
      container.read(serverSignupTargetProvider.notifier).set(const ServerSignupTarget(host: 'misskey.io', kind: SnsKind.misskey));
      await container.read(sessionsProvider.notifier).add(await _Flow().complete());
      container.read(routerProvider).go(Routes.home);
      await followSignupTarget(container, _SignupPlugin.me);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('RASQ アカウントを作りますか?'), findsNothing);
      expect(await storage.read(rasqAccountNudgeKey), isNull);
    });

    testWidgets('Mastodon: 登録ページは /auth/sign_up、メールの確認のページへ移ると案内も進む', (tester) async {
      Uri? changed;
      await _pumpWide(tester, _central(), onWeb: (u, cb) => changed = u);
      final c = ProviderScope.containerOf(tester.element(find.byType(OnboardingScreen)));
      const target = ServerSignupTarget(host: 'mastodon.social', kind: SnsKind.mastodon, software: 'mastodon', name: 'Mastodon');
      c.read(serverSignupTargetProvider.notifier).set(target);
      c.read(routerProvider).push(Routes.serverSignup);
      await tester.pumpAndSettle();
      expect(changed.toString(), 'https://mastodon.social/auth/sign_up');
      expect(find.textContaining('「同意する」'), findsOneWidget);
      _FakeWeb.last!(Uri.parse('https://mastodon.social/auth/setup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('確認のメール'), findsOneWidget);
      expect(target.loginLocation, '/login/mastodon?host=mastodon.social');
    });

    test('ログインに使う SNS と登録の入口(Misskey 系 / Mastodon 系だけ)', () {
      expect(signupKindOf('sharkey'), SnsKind.misskey);
      expect(signupKindOf('mastodon'), SnsKind.mastodon);
      expect(signupKindOf('pleroma'), isNull, reason: 'ログインの口が無いので出さない');
      expect(signupTargetFor(const RasqServerInfo(host: 'x.example', software: 'gotosocial')), isNull);
      final closed = signupGuideSteps(const ServerSignupTarget(host: 'x.example', kind: SnsKind.misskey, registrationOpen: false), hasRasqAccount: false);
      expect(closed.first, contains('招待制'));
      expect(closed.last, contains('あとからサイドバー'));
    });
  });
}

/// 埋め込みのフェイク(名前は RASQ MiniLM): 「ふわふわ」と動物の見本の文だけが同じ向き、ジャンルの無い見本の文は別の向き。
class _FakeMiniLm implements RaiEmbedder {
  @override
  String get name => 'rasq-minilm-fake';
  @override
  Future<List<List<double>>> embed(List<String> texts) async => [
        for (final t in texts)
          if (t.contains('ふわふわ') || t.contains('ペット'))
            [1.0, 0.0, 0.0]
          else if (t.contains('ふつう') || t.contains('おはよう') || t.contains('疲れ'))
            [0.0, 1.0, 0.0]
          else
            [0.0, 0.0, 1.0],
      ];
}

/// 登録の WebView の代わり(URL を出し、ページの移動を外から起こせる)。
class _FakeWeb extends StatelessWidget {
  const _FakeWeb(this.url);
  final Uri url;
  static ValueChanged<Uri>? last;
  @override
  Widget build(BuildContext context) => Center(child: Text('fake web: $url'));
}

/// 登録したサーバーのログイン(MiAuth のフェイク): ログインすると misskey.io の新しいアカウント。投稿 g1 は同じ id で読める。
class _SignupPlugin extends FakeSnsPlugin {
  _SignupPlugin() : super(id: MisskeyPlugin.pluginId, posts: (a) => [Post(id: 'g1', account: a, author: UserSummary(id: 'u-taro', account: const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'taro'), displayName: 'taro'), createdAt: DateTime(2026, 10, 1), body: 'スプラの新シーズン始まったのでガチマッチ回してる')]);
  static const me = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'newbie');
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) async => _Flow();
}

class _Flow extends BrowserAuthFlow {
  @override
  Uri get url => Uri.parse('https://misskey.io/miauth/x');
  @override
  String get hint => 'ブラウザで許可したら戻ってきてください';
  @override
  Future<AuthResult> complete() async => AuthResult(
        session: AccountSession(account: _SignupPlugin.me, pluginId: MisskeyPlugin.pluginId, token: 't', createdAt: DateTime(2026, 10, 2), displayName: 'newbie'),
        me: const UserSummary(id: 'u-newbie', account: _SignupPlugin.me, displayName: 'newbie'),
      );
}

Map<String, Object?> _wire(String id, String body, {String? cw, String? replyToId, String visibility = 'public', String handle = 'taro', String instance = 'misskey.io', String kind = 'misskey'}) => {
      'id': id,
      'author': {'id': 'u-$handle', 'kind': kind, 'instance': instance, 'handle': handle, 'displayName': handle},
      'createdAt': '2026-10-01T00:00:00Z',
      'body': body,
      'cw': ?cw,
      'replyToId': ?replyToId,
      'visibility': visibility,
      'counts': {'reactions': 5, 'renotes': 1},
      'url': 'https://$instance/notes/$id',
    };

/// Central のフェイク: misskey.io / mastodon.social のサーバー情報と見本、公開の RASQ リスト 1 つ。
MockClient _central() => MockClient((req) async {
      http.Response json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});
      final p = req.url.path;
      final info = RegExp(r'/api/v1/servers/([^/]+)/info$').firstMatch(p);
      if (info != null) {
        final h = info.group(1)!;
        if (h == 'misskey.io') return json({'host': h, 'software': 'misskey', 'name': 'Misskey.io', 'users': 1200, 'registrationOpen': true});
        if (h == 'mastodon.social') return json({'host': h, 'software': 'mastodon', 'name': 'Mastodon', 'users': 3000, 'registrationOpen': true});
      }
      if (p.endsWith('/servers/misskey.io/showcase')) {
        return json({
          'host': 'misskey.io',
          'software': 'misskey',
          'posts': [
            {'post': _wire('cw1', 'ネタバレ注意の新作ゲームの感想、ボスが強すぎる', cw: 'ネタバレ'), 'score': 9, 'source': 'featured'},
            {'post': _wire('r1', 'それなー、スプラの新シーズン楽しいよね本当に', replyToId: 'x'), 'score': 8, 'source': 'local'},
            {'post': _wire('chat', '今日もいちにちおつかれさまでした、また明日'), 'score': 7, 'source': 'local'},
            {'post': _wire('g1', 'スプラの新シーズン始まったのでガチマッチ回してる'), 'score': 5, 'source': 'featured'},
            {'post': _wire('f1', '駅前の新しいラーメン屋、スープが濃厚でおいしかった'), 'score': 2, 'source': 'local'},
          ],
          'fetchedAt': '2026-10-02T00:00:00Z',
        });
      }
      if (p.endsWith('/servers/mastodon.social/showcase')) return json({'host': 'mastodon.social', 'software': 'mastodon', 'posts': [], 'fetchedAt': '2026-10-02T00:00:00Z'});
      final owner = {'id': 'o1', 'handle': 'neko', 'displayName': 'ねこ'};
      final list = {'id': 'list-1', 'code': 'L1', 'kind': 'list', 'name': 'ねこ好きの集まり', 'description': '猫の写真を投稿する人たち', 'visibility': 'public', 'owner': owner, 'itemCount': 2, 'followerCount': 4, 'instances': ['misskey.io'], 'url': 'https://central.test/@neko/lists/L1'};
      if (p.endsWith('/rasq-collections/search')) return json([list]);
      if (p.endsWith('/rasq-collections/list-1')) {
        return json({
          'collection': list,
          'items': [
            {'key': 'misskey:misskey.io:u-hana', 'kind': 'misskey', 'instance': 'misskey.io', 'refId': 'u-hana', 'handle': 'hana', 'state': 'ok'},
          ],
          'posts': [
            {'key': 'k1', 'memberKey': 'misskey:misskey.io:u-hana', 'createdAt': '2026-10-01T00:00:00Z', 'post': _wire('lp1', 'うちの猫が箱から出てこない、ずっと寝てる', handle: 'hana')},
            {'key': 'k2', 'memberKey': 'misskey:misskey.io:u-hana', 'createdAt': '2026-10-01T00:00:00Z', 'post': _wire('lp2', 'フォロワー限定の猫の写真、かわいいので見てほしい', handle: 'hana', visibility: 'followers')},
          ],
          'viewer': {'isOwner': false, 'following': false, 'eligible': false, 'canFetch': false},
          'refresh': 'skipped',
        });
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });

/// 新規の端末(台帳が空)のオンボーディング。既定は幅の広い画面(2 カラム)。
Future<ProviderContainer> _pumpWide(WidgetTester tester, MockClient client, {Size size = const Size(1280, 900), SnsPlugin? plugin, void Function(Uri url, ValueChanged<Uri> cb)? onWeb, MemorySessionStorage? storage}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(storage ?? MemorySessionStorage({})),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin ?? FakeSnsPlugin(posts: (_) => const []))),
      orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
      centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      signupWebAreaProvider.overrideWithValue((context, url, onUrlChanged) {
        _FakeWeb.last = onUrlChanged;
        onWeb?.call(url, onUrlChanged);
        return _FakeWeb(url);
      }),
    ],
    child: const RasqApp(),
  ));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
}
