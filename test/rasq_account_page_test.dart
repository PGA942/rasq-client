import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/navigation.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/home/home_screen.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/features/profile/rasq_account_page_screen.dart';
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/rasq_account_fow.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_client/shell/third_column.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// RASQ アカウントページ (D-270 / S-021)。サーバーは MockClient で Central の口をまねる。
void main() {
  http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

  test('自動の判定: 鍵アカウント / 直近の公開範囲がフォロワーのみ寄りなら出さない', () {
    expect(snsAutoVisible(isLocked: true, recentVisibilities: const ['public']), isFalse);
    expect(snsAutoVisible(isLocked: false, recentVisibilities: const []), isTrue);
    expect(snsAutoVisible(isLocked: false, recentVisibilities: const [null, null]), isTrue); // 公開範囲を持たない SNS
    expect(snsAutoVisible(isLocked: false, recentVisibilities: const ['public', 'home', 'followers']), isTrue);
    expect(snsAutoVisible(isLocked: false, recentVisibilities: const ['followers', 'followers', 'public']), isFalse);
    expect(snsAutoVisible(isLocked: false, recentVisibilities: const ['followers', 'public']), isTrue); // ちょうど半分は出す
    expect(snsAutoVisible(isLocked: false, recentVisibilities: const ['specified', 'private', 'public']), isFalse);
  });

  test('モデル: http(s) でない URL は捨てる', () {
    final p = RasqPublicProfile.fromJson({
      'id': 'a', 'handle': 'taro', 'displayName': 'タロ', 'avatarUrl': 'javascript:alert(1)',
      'links': [{'label': '悪い', 'url': 'javascript:alert(1)'}, {'label': 'サイト', 'url': 'https://example.com/'}],
      'snsAccounts': [{'kind': 'misskey', 'instance': 'mk.example', 'handle': 'taro', 'profileUrl': 'ftp://x', 'serverName': ''}],
    });
    expect(p.avatarUrl, isNull);
    expect(p.links.single.label, 'サイト');
    expect(p.snsAccounts.single.profileUrl, isNull);
    expect((p.snsAccounts.single.label, p.snsAccounts.single.serverLabel), ('taro', 'mk.example'));
  });

  test('フィード: limit / until はパスでなくクエリで送る(パスに ? を入れると %3F になって 404)', () async {
    final urls = <Uri>[];
    final mock = MockClient((req) async {
      urls.add(req.url);
      if (req.url.path != '/api/v1/me/feed') return json({'error': {'code': 'not_found'}}, 404);
      return json({'posts': <Object>[], 'nextUntil': null});
    });
    final api = RasqAccountPageApi(OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock));
    await api.feed();
    await api.feed(until: '2026-09-20T00:00:00+09:00', limit: 10);
    expect(urls.map((u) => u.path), everyElement('/api/v1/me/feed'));
    expect(urls[0].queryParameters, {'limit': '30'});
    expect(urls[1].queryParameters, {'limit': '10', 'until': '2026-09-20T00:00:00+09:00'});
  });

  test('SNS のトークンを預ける口は ORGATE、投稿の一覧は Central (D-399)', () async {
    final hits = <String>[];
    MockClient server(String name) => MockClient((req) async {
          hits.add('$name ${req.method} ${req.url.path}');
          if (req.url.path.startsWith('/api/v1/me/sns-accounts/')) {
            if (req.method == 'DELETE') return http.Response('', 204);
            return json({'accountKey': 'misskey:mk.example:taro', 'hasToken': true, 'postCount': 3, 'lastFetchAt': null, 'lastError': null, 'collectionsAllowed': req.url.path.endsWith('/collections')});
          }
          return json({'posts': <Object>[], 'limit': 3, 'source': 'rasq', 'snsPosts': <Object>[], 'pins': <Object>[]});
        });
    final api = RasqAccountPageApi(
      OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: server('central')),
      edge: OrgateClient(baseUrl: Uri.parse('https://orgate.test'), httpClient: server('orgate')),
    );
    const key = 'misskey:mk.example:taro';
    expect((await api.depositToken(key, 'secret')).postCount, 3);
    expect((await api.vaultStatus(key))?.hasToken, isTrue);
    expect((await api.setCollectionsAllowed(key, true)).collectionsAllowed, isTrue);
    await api.withdrawToken(key);
    await api.posts('taro');
    expect(hits, [
      'orgate PUT /api/v1/me/sns-accounts/misskey%3Amk.example%3Ataro/token',
      'orgate GET /api/v1/me/sns-accounts/misskey%3Amk.example%3Ataro/token',
      'orgate PUT /api/v1/me/sns-accounts/misskey%3Amk.example%3Ataro/token/collections',
      'orgate DELETE /api/v1/me/sns-accounts/misskey%3Amk.example%3Ataro/token',
      'central GET /api/v1/accounts/taro/posts',
    ]);
  });

  testWidgets('ページ: プロフィール / SNS タイル / タブ。自分のページでは投稿の上限の案内と削除、編集画面でタイルの出し分けを変える', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const author = {'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'};
    final posts = <Map<String, Object?>>[
      {'id': 'p1', 'author': author, 'body': 'はじめての投稿', 'images': <Object>[], 'createdAt': '2026-09-20T00:00:00Z', 'replyCount': 0, 'rebroadCount': 0, 'rebroaded': false, 'queues': <Object>[]},
      {
        'id': 'p2', 'author': author, 'body': 'ふたつめ', 'images': [{'id': 'v2', 'url': 'https://central.test/api/v1/post-images/v2', 'type': 'video'}], 'createdAt': '2026-09-19T00:00:00Z', 'replyCount': 2, 'rebroadCount': 1, 'rebroaded': false,
        'queues': [{'packId': 'dev.pack', 'stickerId': 'star', 'url': 'https://central.test/api/v1/plugins/dev.pack/stickers/star', 'count': 3, 'mine': false}],
      },
      // ほかの人の投稿のリブロード(上限には数えない)。
      {'id': 'p9', 'author': {'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'}, 'body': 'ハナコの投稿', 'images': [{'id': 'v9', 'url': 'https://central.test/api/v1/post-images/v9', 'type': 'video'}], 'createdAt': '2026-09-18T00:00:00Z', 'rebroadedBy': author, 'rebroadId': 'rb9', 'rebroaded': true, 'rebroadCount': 1},
    ];
    final links = [
      {'accountKey': 'misskey:mk.example:taro', 'kind': 'misskey', 'instance': 'mk.example', 'handle': 'taro', 'displayName': 'タロ@みすきー', 'serverName': 'Mk Example', 'profileUrl': 'https://mk.example/@taro', 'visibility': 'auto', 'autoVisible': true, 'visible': true},
      {'accountKey': 'misskey:mk.example:kagi', 'kind': 'misskey', 'instance': 'mk.example', 'handle': 'kagi', 'displayName': 'かぎ', 'visibility': 'auto', 'autoVisible': false, 'visible': false},
    ];
    final calls = <String>[];
    final replies = <Map<String, Object?>>[];
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      calls.add('${req.method} $path');
      switch ('${req.method} $path') {
        case 'GET /me':
          return json({'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'});
        case 'GET /accounts/taro':
          return json({
            'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ', 'bio': 'こんにちは', 'location': '東京', 'birthday': '04-01', 'createdAt': '2026-09-01T00:00:00Z',
            'links': [{'label': 'サイト', 'url': 'https://example.com/'}],
            'snsAccounts': [for (final l in links) if (l['visible'] == true) l],
            'plugins': [{'id': 'dev.taro.tool', 'name': 'タロの道具', 'summary': '便利'}],
            'reviews': [{'pluginId': 'jp.rasq.sample', 'pluginName': 'サンプル', 'rating': 4, 'title': 'よい', 'body': 'よかった', 'createdAt': '2026-09-10T00:00:00Z'}],
          });
        case 'GET /accounts/taro/posts':
          return json({'source': 'rasq', 'limit': 3, 'posts': posts});
        case 'DELETE /me/posts/p1':
          posts.removeWhere((p) => p['id'] == 'p1');
          return http.Response('', 204);
        case 'DELETE /rebroads/rb9':
          return http.Response('', 204);
        case 'GET /posts/p9':
          return json({'post': posts.firstWhere((p) => p['id'] == 'p9'), 'replies': <Object>[]});
        case 'POST /posts/p2/rebroad':
          posts[posts.indexWhere((p) => p['id'] == 'p2')]
            ..['rebroaded'] = true
            ..['rebroadCount'] = 2;
          return json(posts.firstWhere((p) => p['id'] == 'p2'));
        case 'PUT /posts/p2/queue':
          final q = (posts.firstWhere((p) => p['id'] == 'p2')['queues'] as List).first as Map;
          q
            ..['mine'] = true
            ..['count'] = 4;
          return json(posts.firstWhere((p) => p['id'] == 'p2'));
        case 'POST /me/posts':
          replies.add((jsonDecode(req.body) as Map).cast<String, Object?>());
          return json({'id': 'r1', 'author': author, 'body': 'x', 'isReply': true}, 201);
        case 'GET /me/sns-accounts':
          return json(links);
        case 'GET /accounts/taro/rasq-collections':
          // 公開した RASQ リスト / クリップ (D-343/D-344)。リストだけ 1 つ。
          return json([
            if (req.url.queryParameters['kind'] == 'list')
              {'id': 'rl1', 'code': 'ListCode111111111111', 'kind': 'list', 'name': 'タロのリスト', 'visibility': 'public', 'owner': author, 'itemCount': 3, 'instances': ['mk.example']},
          ]);
        case 'PATCH /me/sns-accounts/misskey%3Amk.example%3Akagi':
        case 'PATCH /me/sns-accounts/misskey:mk.example:kagi':
          final v = (jsonDecode(req.body) as Map)['visibility'] as String;
          links[1]
            ..['visibility'] = v
            ..['visible'] = v == 'show' || (v == 'auto' && links[1]['autoVisible'] == true);
          return json(links[1]);
      }
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-1'}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push(Routes.rasqAccount('taro'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqAccountPageScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.name')), findsOneWidget);
    expect(find.text('こんにちは'), findsOneWidget);
    expect(find.text('東京'), findsOneWidget);
    expect(find.text('サイト'), findsOneWidget);
    // SNS タイル: 見えるものだけ。アカウント名 → サーバー名。
    expect(find.byKey(const ValueKey('rasqPage.tile.misskey:mk.example:taro')), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.tile.misskey:mk.example:kagi')), findsNothing);
    expect(find.text('タロ@みすきー'), findsOneWidget);
    expect(find.text('Mk Example'), findsOneWidget);
    // 自分のページ: 上限の案内、投稿、削除。
    expect(find.byKey(const ValueKey('rasqPage.compose')), findsOneWidget);
    expect(find.textContaining('(2 / 3)'), findsOneWidget);
    expect(find.text('はじめての投稿'), findsOneWidget);
    // リブロードは上限に数えない(通常の投稿 2 件 + リブロード 1 件 = 2 / 3)。リブロードの帯が出る。
    final pageScroll = find.descendant(of: find.byType(RasqAccountPageScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('タロ がリブロード'), 200, scrollable: pageScroll);
    expect(find.text('タロ がリブロード'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rasqPost.p2')), -200, scrollable: pageScroll);
    // アクションバー: リブロード → 件数と印が変わる。キューのチップ → 同じ絵を自分も付ける。返信 → replyTo つきで送る。
    // タイルは SNS の投稿と同じ部品(RasqPostTile / RasqReactionChips / RasqActionBar。D-273)。
    final p2 = find.byKey(const ValueKey('rasqPost.p2'));
    expect(find.descendant(of: p2, matching: find.byType(RasqPostTile)), findsOneWidget);
    // リブロードのボタン = バンドル(リブロード / 引用。D-276)。ふつうのタイルでは、何度でもリブロードできる。
    // (固定のボタンの行が無くなったぶん詰まるので、右下の「RASQ に投稿」に隠れない位置へ。D-423)
    await Scrollable.ensureVisible(tester.element(find.descendant(of: p2, matching: find.byTooltip('リブロード'))), alignment: 0.5);
    await tester.pumpAndSettle();
    for (var n = 1; n <= 2; n++) {
      await tester.tap(find.descendant(of: p2, matching: find.byTooltip('リブロード')));
      await tester.pumpAndSettle();
      expect(find.text('引用'), findsOneWidget);
      expect(find.text('リブロードを取り消す'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('actionbar.bundle.pick.rebroad')));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c == 'POST /posts/p2/rebroad').length, n);
    }
    // 付いているキュー = リアクションのチップ。押すと、同じ絵を自分も付ける。
    await tester.tap(find.descendant(of: p2, matching: find.byType(RasqReactionChips)));
    await tester.pumpAndSettle();
    expect(calls, contains('PUT /posts/p2/queue'));
    await tester.tap(find.descendant(of: p2, matching: find.byTooltip('返信')));
    await tester.pumpAndSettle();
    // 返信は、SNS の返信と同じコンポーザーで(投稿先は RASQ に固定。D-292)。
    expect(find.byKey(const ValueKey('composer.pill.rasq')), findsOneWidget);
    // RASQ の返信は文字だけ: 添付 / 投票は押せず、理由を出す (D-421。Swing のスレッドへの返信だけは付けられる)。
    for (final k in ['composer.tool.image', 'composer.tool.video', 'composer.tool.poll']) {
      final b = tester.widget<RasqActionButton>(find.byKey(ValueKey(k)));
      expect(b.onTap, isNull, reason: k);
      expect(b.tooltip, 'RASQ の返信は文字だけです');
    }
    expect(tester.widget<RasqActionButton>(find.byKey(const ValueKey('composer.tool.cw'))).onTap, isNotNull, reason: '注釈は付けられる');
    await tester.enterText(find.byType(TextField).last, 'いいですね');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '返信'));
    await tester.pumpAndSettle();
    expect(replies.single, {'body': 'いいですね', 'replyTo': 'p2'});
    // キューのボタン: 付けていれば、押すと外す(Misskey のリアクションと同じ)。アセットパックが無ければ、長押しでストアへの案内。
    // 右下の「RASQ に投稿」に隠れない位置まで送る。
    await tester.drag(find.byKey(const ValueKey('rasqPost.p2')), const Offset(0, -250));
    await tester.pumpAndSettle();
    await tester.longPress(find.descendant(of: p2, matching: find.byTooltip('キュー')));
    await tester.pumpAndSettle();
    expect(find.text('アセットパックがありません'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    // 自分のリブロードとして出ているタイルでは、ボタンが「リブロードを取り消す」になり、その 1 回だけを取り消す (D-276)。帯の … は無い。
    expect(find.byTooltip('リノートの操作'), findsNothing);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('rasqPost.p9')), matching: find.byTooltip('リブロードを取り消す')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('actionbar.bundle.pick.rebroad')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('actionbar.bundle.pick.undo')));
    await tester.pumpAndSettle();
    expect(calls, contains('DELETE /rebroads/rb9'));
    // … = ほかの SNS と同じドロップダウン。削除はこの中(自分の投稿だけ)。
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('rasqPost.p9')), matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
    expect(find.text('リンクをコピー'), findsOneWidget);
    expect(find.text('アクションバーを編集'), findsOneWidget);
    expect(find.text('削除'), findsNothing);
    c.read(overlayManagerProvider).close('rasq.post.more');
    await tester.pumpAndSettle();
    // いちばん上の投稿まで戻す(下へ送ってあるので)。
    await tester.drag(find.byType(NestedScrollView), const Offset(0, 1500));
    await tester.pumpAndSettle();
    // SNS をつないでいて、SNS の投稿がまだ無い → 預ける画面への案内 (D-316)。そのぶん、投稿は少し下にある。
    expect(find.byKey(const ValueKey('rasqPage.posts.snsHint')), findsOneWidget);
    await Scrollable.ensureVisible(tester.element(find.descendant(of: find.byKey(const ValueKey('rasqPost.p1')), matching: find.byTooltip('メニュー'))), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('rasqPost.p1')), matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除する'));
    await tester.pumpAndSettle();
    expect(find.text('はじめての投稿'), findsNothing);
    expect(find.textContaining('(1 / 3)'), findsOneWidget);
    // プラグインのタブ: 公開したもの / レビューしたもの。
    // タブは 6 つ (D-277)。狭い画面では横に送って出す。
    await tester.ensureVisible(find.text('プラグイン'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プラグイン'));
    await tester.pumpAndSettle();
    expect(find.text('タロの道具'), findsOneWidget);
    // レビューは別のタブ (D-277)。
    expect(find.textContaining('★★★★'), findsNothing);
    await tester.ensureVisible(find.text('レビュー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('レビュー'));
    await tester.pumpAndSettle();
    expect(find.textContaining('★★★★'), findsOneWidget);
    expect(find.text('タロの道具'), findsNothing);
    for (final tab in ['リスト', 'クリップ']) {
      await tester.ensureVisible(find.text(tab));
      await tester.pumpAndSettle();
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      if (tab == 'リスト') {
        expect(find.byKey(const ValueKey('rasqCollection.tile.rl1')), findsOneWidget);
        expect(find.text('タロのリスト'), findsOneWidget);
      } else {
        expect(find.textContaining('公開した RASQ クリップがここに出ます'), findsOneWidget);
      }
    }

    // 編集 → タイルの出し分け: 鍵アカウントは「自動(非表示)」→「表示」にすると出る。
    await tester.tap(find.byKey(const ValueKey('rasqPage.edit')));
    await tester.pumpAndSettle();
    expect(find.byType(RasqProfileEditScreen), findsOneWidget);
    final seg = find.byKey(const ValueKey('rasqProfile.sns.misskey:mk.example:kagi'));
    await tester.scrollUntilVisible(find.descendant(of: seg, matching: find.text('非表示')), 200, scrollable: find.descendant(of: find.byType(RasqProfileEditScreen), matching: find.byType(Scrollable)).first);
    expect(find.descendant(of: seg, matching: find.text('自動(非表示)')), findsOneWidget);
    await tester.ensureVisible(seg);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: seg, matching: find.text('表示')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.startsWith('PATCH')), isNotEmpty, reason: '$calls');
    expect(links[1]['visibility'], 'show');
    expect(tester.widget<SegmentedButton<SnsTileVisibility>>(seg).selected, {SnsTileVisibility.show});
    // 戻ると、ページにも出る。
    c.read(routerProvider).pop();
    await tester.pumpAndSettle();
    // (一覧を送ってあるので、上へ戻してから見る。)
    await tester.drag(find.byType(NestedScrollView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasqPage.tile.misskey:mk.example:kagi')), findsOneWidget);
    // メディアのタブ: グリッドのタイルを押すと、その投稿の全画面表示が開く (D-277)。リブロードした他人の投稿のメディアは並べない。
    await tester.ensureVisible(find.text('メディア'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('メディア'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasqPage.media.v9')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('rasqPage.media.v2')));
    await tester.pumpAndSettle();
    expect(find.byType(MediaViewerScreen), findsOneWidget);
  });

  /// カラム表示 (D-425): ユーザーページと同じく、幅の広い画面では第3カラムに開く。狭い画面とディープリンクは全画面のルート。
  group('カラム表示 (D-425)', () {
    Map<String, Object?> profile(String handle, String name) => {'id': 'acc-$handle', 'handle': handle, 'displayName': name, 'snsAccounts': <Object>[], 'links': <Object>[]};
    final mock = MockClient((req) async {
      final path = req.url.path.replaceFirst('/api/v1', '');
      if (req.method == 'GET' && path == '/me') return json({'id': 'acc-taro', 'handle': 'taro', 'displayName': 'タロ'});
      final m = RegExp(r'^/accounts/(\w+)(/posts)?$').firstMatch(path);
      if (m != null && m.group(2) == null) return json(profile(m.group(1)!, m.group(1) == 'taro' ? 'タロ' : 'ハナコ'));
      if (m != null) return json({'source': 'rasq', 'limit': 3, 'posts': <Object>[]});
      if (path.endsWith('/rasq-collections')) return json(<Object>[]);
      return json({'error': {'code': '404', 'message': 'not found'}}, 404);
    });

    Future<ProviderContainer> pumpAt(WidgetTester tester, Size logical) async {
      tester.view.physicalSize = logical * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({
            SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
            OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-abc', 'token': 'device-token', 'accountId': 'acc-taro'}),
          })),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
          orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
          centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
          orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        ],
        child: const RasqApp(),
      ));
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    }

    Finder inCol3(Finder f) => find.descendant(of: find.byType(ThirdColumnView), matching: f);
    Finder pageOf(String handle) => find.byWidgetPredicate((w) => w is RasqAccountPageScreen && w.handle == handle);

    testWidgets('広い画面: 第2カラムから開くと第3カラムへ。第3カラムから開くと居たページが第2カラム(タブの中)へ移り、< で取り戻せる', (tester) async {
      final c = await pumpAt(tester, const Size(1200, 800));
      tester.element(find.byType(HomeScreen)).pushRasqAccount('taro');
      await tester.pumpAndSettle();
      expect(inCol3(pageOf('taro')), findsOneWidget);
      expect(pageOf('taro'), findsOneWidget, reason: '全画面のルートには積まない');
      expect(find.byType(HomeScreen), findsOneWidget, reason: '第2カラムはホームのまま');
      expect(c.read(thirdColumnProvider)!.location, '/home/rasq/taro');
      expect(inCol3(find.text('@taro')), findsWidgets);

      // 第3カラムのページから別のアカウントページを開く → taro は第2カラム(/home/rasq/taro)へ、hanako が第3カラムに。
      tester.element(inCol3(pageOf('taro'))).pushRasqAccount('hanako');
      await tester.pumpAndSettle();
      expect(inCol3(pageOf('hanako')), findsOneWidget);
      expect(inCol3(pageOf('taro')), findsNothing);
      expect(pageOf('taro'), findsOneWidget, reason: '第2カラム(タブの中のルート)へ移った');
      expect(visibleLocationOf(c.read(routerProvider).routerDelegate.currentConfiguration), '/home/rasq/taro');

      // < で taro を第3カラムへ取り戻す(第2カラムの複製は消える)→ もう一度 < で閉じる。
      await tester.tap(inCol3(find.byTooltip('戻る')).first);
      await tester.pumpAndSettle();
      expect(inCol3(pageOf('taro')), findsOneWidget);
      expect(pageOf('taro'), findsOneWidget);
      expect(pageOf('hanako'), findsNothing);
      await tester.tap(inCol3(find.byTooltip('戻る')).first);
      await tester.pumpAndSettle();
      expect(find.byType(RasqAccountPageScreen), findsNothing);
      expect(c.read(thirdColumnProvider), isNull);
    });

    testWidgets('広い画面: RASQ アカウントの FOW の「アカウントページ」も第3カラムへ(FOW とサイドバーは閉じる)', (tester) async {
      final c = await pumpAt(tester, const Size(1200, 800));
      await c.read(rasqAccountsProvider.notifier).attachCentral(centralAccountId: 'acc-taro', handle: 'taro', displayName: 'タロ');
      await tester.pumpAndSettle();
      RasqSidebar.open(c.read(overlayManagerProvider));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('RASQ アカウント'));
      await tester.pumpAndSettle();
      final row = find.ancestor(of: find.textContaining('taro'), matching: find.byType(RasqUserRow)).first;
      await tester.tap(find.descendant(of: row, matching: find.byTooltip('アカウントの操作')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('アカウントページ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('アカウントページ'));
      await tester.pumpAndSettle();
      expect(inCol3(pageOf('taro')), findsOneWidget);
      expect(c.read(overlayManagerProvider).contains(rasqAccountFowId), isFalse);
      expect(c.read(overlayManagerProvider).contains(RasqSidebar.overlayId), isFalse);
    });

    testWidgets('狭い画面: これまでどおり全画面のルート(タブの中)。戻るで元へ', (tester) async {
      final c = await pumpAt(tester, const Size(400, 800));
      tester.element(find.byType(HomeScreen)).pushRasqAccount('taro');
      await tester.pumpAndSettle();
      expect(c.read(thirdColumnProvider), isNull);
      expect(find.byType(ThirdColumnView), findsNothing);
      expect(pageOf('taro'), findsOneWidget);
      expect(visibleLocationOf(c.read(routerProvider).routerDelegate.currentConfiguration), '/home/rasq/taro');
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(pageOf('taro'), findsNothing);
    });

    testWidgets('ディープリンク: /rasq/<handle>(アプリ直下)も /home/rasq/<handle>(タブの中)も開ける', (tester) async {
      final c = await pumpAt(tester, const Size(1200, 800));
      c.read(routerProvider).push(Routes.rasqAccount('taro'));
      await tester.pumpAndSettle();
      expect(pageOf('taro'), findsOneWidget);
      expect(inCol3(pageOf('taro')), findsNothing, reason: 'ルートで開いたものは全画面');
      c.read(routerProvider).pop();
      await tester.pumpAndSettle();
      c.read(routerProvider).go(Routes.rasqAccountIn(Routes.home, 'hanako'));
      await tester.pumpAndSettle();
      expect(pageOf('hanako'), findsOneWidget);
      expect(find.text('@hanako'), findsWidgets);
    });
  });
}
