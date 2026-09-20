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
import 'package:rasq_client/features/profile/rasq_profile_edit_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
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

  testWidgets('ページ: プロフィール / SNS タイル / タブ。自分のページでは投稿の上限の案内と削除、編集画面でタイルの出し分けを変える', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const author = {'id': 'acc-1', 'handle': 'taro', 'displayName': 'タロ'};
    final posts = <Map<String, Object?>>[
      {'id': 'p1', 'author': author, 'body': 'はじめての投稿', 'images': <Object>[], 'createdAt': '2026-09-20T00:00:00Z', 'replyCount': 0, 'rebroadCount': 0, 'rebroaded': false, 'queues': <Object>[]},
      {
        'id': 'p2', 'author': author, 'body': 'ふたつめ', 'images': <Object>[], 'createdAt': '2026-09-19T00:00:00Z', 'replyCount': 2, 'rebroadCount': 1, 'rebroaded': false,
        'queues': [{'packId': 'dev.pack', 'stickerId': 'star', 'url': 'https://central.test/api/v1/plugins/dev.pack/stickers/star', 'count': 3, 'mine': false}],
      },
      // ほかの人の投稿のリブロー(上限には数えない)。
      {'id': 'p9', 'author': {'id': 'acc-2', 'handle': 'hanako', 'displayName': 'ハナコ'}, 'body': 'ハナコの投稿', 'images': <Object>[], 'createdAt': '2026-09-18T00:00:00Z', 'rebroadedBy': author, 'rebroaded': true, 'rebroadCount': 1},
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
        case 'DELETE /posts/p9/rebroad':
          return http.Response('', 204);
        case 'GET /posts/p9':
          return json({'post': posts.firstWhere((p) => p['id'] == 'p9'), 'replies': <Object>[]});
        case 'PUT /posts/p2/rebroad':
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
    // リブローは上限に数えない(通常の投稿 2 件 + リブロー 1 件 = 2 / 3)。リブローの帯が出る。
    final pageScroll = find.descendant(of: find.byType(RasqAccountPageScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('タロ がリブロー'), 200, scrollable: pageScroll);
    expect(find.text('タロ がリブロー'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('rasqPost.p2')), -200, scrollable: pageScroll);
    // アクションバー: リブロー → 件数と印が変わる。キューのチップ → 同じ絵を自分も付ける。返信 → replyTo つきで送る。
    // タイルは SNS の投稿と同じ部品(RasqPostTile / RasqReactionChips / RasqActionBar。D-273)。
    final p2 = find.byKey(const ValueKey('rasqPost.p2'));
    expect(find.descendant(of: p2, matching: find.byType(RasqPostTile)), findsOneWidget);
    await tester.tap(find.descendant(of: p2, matching: find.byTooltip('リブロー')));
    await tester.pumpAndSettle();
    expect(calls, contains('PUT /posts/p2/rebroad'));
    // ボタンは入り切りにしない (D-274): リブロー済みでも、ボタンは「リブロー」のまま(取り消しは … から)。
    expect(find.descendant(of: p2, matching: find.byTooltip('リブロー')), findsOneWidget);
    expect(find.descendant(of: p2, matching: find.byTooltip('リブローをやめる')), findsNothing);
    // 付いているキュー = リアクションのチップ。押すと、同じ絵を自分も付ける。
    await tester.tap(find.descendant(of: p2, matching: find.byType(RasqReactionChips)));
    await tester.pumpAndSettle();
    expect(calls, contains('PUT /posts/p2/queue'));
    await tester.tap(find.descendant(of: p2, matching: find.byTooltip('返信')));
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('rasqReply.body')), matching: find.byType(TextField)), 'いいですね');
    await tester.tap(find.text('返信').last);
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
    // 自分のリブローの帯(「タロ がリブロー」)の横の … → リブローを取り消す (D-274)。
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('rasqPost.p9')), matching: find.byTooltip('リノートの操作')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('リブローを取り消す'));
    await tester.pumpAndSettle();
    expect(calls, contains('DELETE /posts/p9/rebroad'));
    // … = ほかの SNS と同じドロップダウン。削除はこの中(自分の投稿だけ)。
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('rasqPost.p9')), matching: find.byTooltip('メニュー')));
    await tester.pumpAndSettle();
    expect(find.text('リンクをコピー'), findsOneWidget);
    expect(find.text('削除'), findsNothing);
    c.read(overlayManagerProvider).close('rasq.post.more');
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
    await tester.tap(find.text('プラグイン'));
    await tester.pumpAndSettle();
    expect(find.text('タロの道具'), findsOneWidget);
    expect(find.textContaining('★★★★'), findsOneWidget);
    await tester.tap(find.text('リスト'));
    await tester.pumpAndSettle();
    expect(find.textContaining('今後ここに出ます'), findsOneWidget);

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
  });
}
