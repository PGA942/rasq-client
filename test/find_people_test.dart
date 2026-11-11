import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/backend/link_match_api.dart';
import 'package:rasq_client/backend/onboarding_discover_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart' show RasqAccountPost, RasqPostAuthor;
import 'package:rasq_client/features/onboarding/export_archive.dart';
import 'package:rasq_client/features/onboarding/export_discover_screen.dart';
import 'package:rasq_client/features/onboarding/page_search.dart';
import 'package:rasq_client/features/onboarding/page_search_screen.dart';
import 'package:rasq_client/features/onboarding/web_snapshot.dart';
import 'package:rasq_models/rasq_models.dart' show ErrorCode;
import 'package:rasq_overlay/rasq_overlay.dart';

// 人を探す 2 つの機能 (D-551 エクスポートデータから探す / D-552 この画面を探す)。

Uint8List _u(String s) => Uint8List.fromList(utf8.encode(s));

/// X の書き出しの zip(フォロー 2 人・フォロワー 1 人・メンション 2 人。フォローの 1 人はメンションでハンドルが分かる)。
Uint8List _xZip() {
  final a = Archive();
  void add(String name, String text) => a.addFile(ArchiveFile.bytes(name, _u(text)));
  add('data/account.js', 'window.YTD.account.part0 = [ {"account":{"username":"Me_Taro","accountId":"100","accountDisplayName":"太郎"}} ]');
  add('data/following.js', 'window.YTD.following.part0 = [ {"following":{"accountId":"201","userLink":"https://twitter.com/intent/user?user_id=201"}}, {"following":{"accountId":"202","userLink":"x"}} ]');
  add('data/follower.js', 'window.YTD.follower.part0 = [ {"follower":{"accountId":"301","userLink":"x"}} ]');
  add(
      'data/tweets.js',
      'window.YTD.tweets.part0 = [ {"tweet":{"entities":{"user_mentions":[ {"name":"はな","screen_name":"Hana_K","indices":["0","7"],"id_str":"201","id":"201"}, '
          '{"name":"じろう","screen_name":"jiro","indices":["8","13"],"id_str":"999","id":"999"}, {"name":"消えた","screen_name":"gone","indices":["1","2"],"id_str":"-1","id":"-1"} ]},"full_text":"@Hana_K @jiro やあ"}} ]');
  add('data/tweets_media/1.jpg', 'x' * 64);
  return Uint8List.fromList(ZipEncoder().encode(a));
}

/// Bluesky の repo.car のかけら: フォローの記録 2 つと、フォローではない記録(いいね)1 つ。
Uint8List _car() {
  final b = BytesBuilder();
  void text(String s) {
    final bytes = ascii.encode(s);
    if (bytes.length < 24) {
      b.addByte(0x60 + bytes.length);
    } else {
      b.add([0x78, bytes.length]);
    }
    b.add(bytes);
  }

  void follow(String did) {
    b.addByte(0xa3);
    text(r'$type');
    text('app.bsky.graph.follow');
    text('subject');
    text(did);
    text('createdAt');
    text('2026-01-01T00:00:00.000Z');
  }

  b.add([1, 2, 3]);
  follow('did:plc:aaaaaaaaaaaaaaaaaaaaaaaa');
  b.addByte(0xa2);
  text(r'$type');
  text('app.bsky.feed.like');
  text('subject');
  text('did:plc:zzzzzzzzzzzzzzzzzzzzzzzz');
  follow('did:web:example.com');
  return b.toBytes();
}

/// 照合の口だけの Central。[known] = (サービス, 名前) → ハンドル。
class _Central {
  _Central(this.known, {this.salt = 'rasq-link-match-v1', this.maxItems = 200, this.busyOnce = false});
  final Map<(String, String), ({String handle, bool verified})> known;
  final String salt;
  final int maxItems;
  bool busyOnce;
  final batches = <int>[];
  final bodies = <String>[];
  Map<String, Object?>? xIdentity;

  late final client = MockClient((req) async {
    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});
    final path = req.url.path.replaceFirst('/api/v1', '');
    if (path == '/accounts/match-links' && req.method == 'GET') return json({'salt': salt, 'maxItems': maxItems});
    if (path == '/accounts/match-links' && req.method == 'POST') {
      if (busyOnce) {
        busyOnce = false;
        return json({'error': {'code': '429', 'message': 'busy'}}, 429);
      }
      bodies.add(req.body);
      final items = (jsonDecode(req.body) as Map)['items'] as List;
      batches.add(items.length);
      final table = {for (final e in known.entries) '${e.key.$1}\n${linkMatchHash(salt, e.key.$1, e.key.$2)}': e.value};
      return json({
        'matches': [
          for (final i in items)
            if (table['${i['service']}\n${i['hash']}'] != null)
              {
                'service': i['service'],
                'hash': i['hash'],
                'accounts': [
                  {'id': 'id-${table['${i['service']}\n${i['hash']}']!.handle}', 'handle': table['${i['service']}\n${i['hash']}']!.handle, 'displayName': '', 'bio': '', 'verified': table['${i['service']}\n${i['hash']}']!.verified},
                ],
              },
        ],
      });
    }
    if (path == '/me/x-identity' && req.method == 'PUT') {
      xIdentity = (jsonDecode(req.body) as Map).cast<String, Object?>();
      return json({'identity': {...xIdentity!, 'method': 'dummy'}});
    }
    return json({'error': {'code': '404', 'message': 'no'}}, 404);
  });

  OrgateClient get orgate => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: client);
}

void main() {
  group('リンクの照合の鍵 (Central S-129 と同じ揃え方)', () {
    test('サービスと名前の揃え方、ハッシュ', () {
      expect(linkMatchService('WWW.Twitter.com'), 'x.com');
      expect(linkMatchService('mobile.twitter.com'), 'x.com');
      expect(linkMatchService('www.threads.com'), 'threads.net');
      expect(linkMatchService('Mastodon.Social.'), 'mastodon.social');
      expect(linkMatchName(' @Taro_1 '), 'taro_1');
      expect(linkMatchName('@'), isNull);
      expect(linkMatchXId('12345'), 'id:12345');
      expect(linkMatchXId('12a'), isNull);
      // Central の `hash_is_stable` と同じベクタ。
      expect(linkMatchHash('rasq-link-match-v1', 'x.com', 'taro'), sha256.convert(utf8.encode('rasq-link-match-v1\nx.com\ntaro')).toString());
      expect(linkMatchHash('a', 'x.com', 'taro'), isNot(linkMatchHash('b', 'x.com', 'taro')));
      expect(validXHandle('@Taro_1'), 'Taro_1');
      expect(validXHandle('taro!'), isNull);
    });
  });

  group('書き出しを端末で読む', () {
    test('X の zip: フォロー / フォロワーは内部 ID、メンションで分かった人はハンドルも', () {
      final a = parseExportBytes([(name: 'twitter-2026.zip', bytes: _xZip())]);
      expect(a.xSelf, (handle: 'Me_Taro', userId: '100'));
      expect(a.count(ExportKind.x, ExportRelation.following), 2);
      expect(a.count(ExportKind.x, ExportRelation.follower), 1);
      expect(a.count(ExportKind.x, ExportRelation.mention), 1, reason: 'フォローしていない jiro だけ(消えたアカウントは外す)');
      expect(a.xWithHandle, 2);
      final hana = a.people.firstWhere((p) => p.label == '@Hana_K');
      expect(hana.keys, [(service: 'x.com', name: 'id:201'), (service: 'x.com', name: 'hana_k')]);
      expect(a.people.firstWhere((p) => p.label == 'ID 202').keys, [(service: 'x.com', name: 'id:202')]);
      expect(a.recognized, isNot(contains('data/tweets_media/1.jpg')), reason: 'メディアは読まない');
    });

    test('Mastodon / Misskey の CSV: 1 列目の user@host。ブロック / ミュートの書き出しは読まない', () {
      final a = parseExportBytes([
        (name: 'following_accounts.csv', bytes: _u('Account address,Show boosts,Notify on new posts,Languages\nTaro@Example.Social,true,false,\nhana@misskey.io,true,false,\n')),
        (name: 'blocked_accounts.csv', bytes: _u('bad@example.social\n')),
        (name: 'lists.csv', bytes: _u('friends,jiro@example.social\n')),
      ]);
      expect(a.people.map((p) => p.label), ['@Taro@Example.Social', '@hana@misskey.io']);
      expect(a.people.first.keys.single, (service: 'example.social', name: 'taro'));
      expect(a.people.every((p) => p.relations.contains(ExportRelation.following)), isTrue);
    });

    test('Instagram / Threads: フォローのファイルの URL からユーザー名', () {
      final a = parseExportBytes([
        (name: 'connections/followers_and_following/followers_1.json', bytes: _u(r'[{"string_list_data":[{"href":"https:\/\/www.instagram.com\/hana.ko","value":"hana.ko","timestamp":1}]}]')),
        (name: 'connections/followers_and_following/following.json', bytes: _u('{"relationships_following":[{"title":"jiro","string_list_data":[{"href":"https://www.instagram.com/_u/jiro","timestamp":1}]}]}')),
        (name: 'your_instagram_activity/threads/following.json', bytes: _u('{"x":[{"string_list_data":[{"href":"https://www.threads.net/@saburo","timestamp":1}]}]}')),
        (name: 'connections/followers_and_following/blocked_profiles.json', bytes: _u('{"x":[{"href":"https://www.instagram.com/blocked"}]}')),
      ]);
      expect(a.count(ExportKind.instagram, ExportRelation.follower), 1);
      expect(a.count(ExportKind.instagram, ExportRelation.following), 1);
      expect(a.count(ExportKind.threads), 1);
      expect(a.people.firstWhere((p) => p.kind == ExportKind.threads).keys.single, (service: 'threads.net', name: 'saburo'));
      expect(a.people.any((p) => p.label == '@blocked'), isFalse);
    });

    test('Bluesky の repo.car: フォローの記録の DID だけ。ハンドルを引けたら鍵を足す', () {
      expect(blueskyFollowDidsOf(_car()), ['did:plc:aaaaaaaaaaaaaaaaaaaaaaaa', 'did:web:example.com']);
      final a = parseExportBytes([(name: 'repo.car', bytes: _car())]);
      expect(a.count(ExportKind.bluesky, ExportRelation.following), 2);
      final b = withBlueskyHandles(a, {'did:plc:aaaaaaaaaaaaaaaaaaaaaaaa': 'Taro.bsky.social'});
      final taro = b.people.firstWhere((p) => p.label == '@Taro.bsky.social');
      expect(taro.keys, [(service: 'bsky.app', name: 'did:plc:aaaaaaaaaaaaaaaaaaaaaaaa'), (service: 'bsky.app', name: 'taro.bsky.social')]);
      expect(b.people.where((p) => p.keys.length == 1).single.label, 'did:web:example.com');
    });
  });

  group('照合', () {
    test('ハッシュだけを 200 件ずつ送り、当たった人をまとめる。429 は待って送り直す', () async {
      final central = _Central({
        ('x.com', 'id:201'): (handle: 'hana', verified: false),
        ('x.com', 'hana_k'): (handle: 'hana', verified: false),
        ('example.social', 'taro'): (handle: 'taro_rasq', verified: true),
      }, maxItems: 3, busyOnce: true);
      final archive = parseExportBytes([
        (name: 'x.zip', bytes: _xZip()),
        (name: 'following_accounts.csv', bytes: _u('taro@example.social\n')),
      ]);
      final progress = <(int, int)>[];
      final matches = await matchExportPeople(LinkMatchApi(central.orgate), archive.people, onProgress: (d, t) => progress.add((d, t)), retryWait: Duration.zero);
      // 鍵は 201(ID とハンドル)・202・301・jiro(ID とハンドル)・taro = 7 つ → 3 件ずつ。
      expect(central.batches, [3, 3, 1]);
      expect(progress.last, (7, 7));
      expect(matches.map((m) => m.account.handle), ['hana', 'taro_rasq'], reason: 'フォロー中の人を先に、同じなら名前の順');
      expect(matches.first.people.single.label, '@Hana_K', reason: '同じ人が 2 つの鍵で当たっても 1 人');
      expect(matches.last.account.verified, isTrue);
      // 平文のハンドルや ID は送らない。
      for (final body in central.bodies) {
        expect(body, isNot(contains('hana_k')));
        expect(body, isNot(contains('id:201')));
        expect(body, isNot(contains('taro')));
      }
    });
  });

  group('エクスポートデータから探す画面', () {
    Future<void> pump(WidgetTester tester, _Central central, ExportArchive archive, {Map<String, String> bluesky = const {}}) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          centralClientProvider.overrideWithValue(central.orgate),
          exportFilePickerProvider.overrideWithValue(() async => [XFile.fromData(Uint8List(0), name: 'x.zip')]),
          exportArchiveReaderProvider.overrideWithValue((files) async => archive),
          blueskyHandleResolverProvider.overrideWithValue((dids) async => bluesky),
        ],
        child: const MaterialApp(home: DiscoverExportScreen()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('X の書き出し: ダミーの X 認証を通してから探せる。見つかった人が並ぶ', (tester) async {
      final central = _Central({('x.com', 'hana_k'): (handle: 'hana', verified: false)});
      await pump(tester, central, parseExportBytes([(name: 'x.zip', bytes: _xZip())]));
      await tester.tap(find.byKey(const ValueKey('discover.export.pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.export.found.x')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.export.xNote')), findsOneWidget);
      // X 認証(ダミー)の前は探せない。試作だと画面に出す。
      expect(find.byKey(const ValueKey('discover.export.xAuth.dummy')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('discover.export.search'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('discover.export.xAuth.button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.export.xAuth.button')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('discover.export.search')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.account.hana')), findsOneWidget);
      expect(find.textContaining('@Hana_K'), findsOneWidget);
      expect(find.textContaining('本人の確認はまだ'), findsOneWidget);
    });

    testWidgets('Fediverse だけなら X 認証は出ない。Bluesky は引き直したハンドルでも照合する。誰もいなければそう出す', (tester) async {
      final central = _Central({('bsky.app', 'taro.bsky.social'): (handle: 'taro', verified: true)});
      await pump(tester, central, parseExportBytes([(name: 'repo.car', bytes: _car()), (name: 'following.csv', bytes: _u('hana@misskey.io\n'))]), bluesky: {'did:plc:aaaaaaaaaaaaaaaaaaaaaaaa': 'taro.bsky.social'});
      await tester.tap(find.byKey(const ValueKey('discover.export.pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.export.xAuth')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('discover.export.search')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.account.taro')), findsOneWidget);
      expect(find.textContaining('本人の確認はまだ'), findsNothing, reason: '確認済みの連携で当たった');
    });

    testWidgets('読めないファイルは、そう出す', (tester) async {
      await pump(tester, _Central({}), const ExportArchive());
      await tester.tap(find.byKey(const ValueKey('discover.export.pick')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.export.error')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.export.search')), findsNothing);
    });
  });

  group('この画面を探す', () {
    const texts = [
      PageTextItem(ui.Rect.fromLTWH(20, 20, 200, 20), 'ねこ写真まとめ'),
      PageTextItem(ui.Rect.fromLTWH(20, 60, 120, 16), '撮影: @hana_k'),
      PageTextItem(ui.Rect.fromLTWH(20, 700, 120, 16), '下の方の文字'),
    ];

    test('囲みの中の文字は、上から・左からの順', () {
      expect(pageRegionText(texts, const ui.Rect.fromLTWH(0, 0, 400, 100)), 'ねこ写真まとめ 撮影: @hana_k');
      expect(pageRegionText(texts, const ui.Rect.fromLTWH(0, 50, 400, 40)), '撮影: @hana_k');
      expect(pageRegionText(texts, const ui.Rect.fromLTWH(300, 300, 50, 50)), '');
      expect(parsePageTextItems('[[1,2,3,4,"あ"],[1,2,3],"x"]').single.text, 'あ');
      expect(parsePageTextItems('こわれた'), isEmpty);
    });

    testWidgets('撮った範囲をつないで 1 枚にし、囲みを切り抜く', (tester) async {
      await tester.runAsync(() async {
        Future<ui.Image> solid(int w, int h, ui.Color c) async {
          final r = ui.PictureRecorder();
          ui.Canvas(r).drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = c);
          return r.endRecording().toImage(w, h);
        }

        // ページの幅 100(CSS)を 50 画素で撮った 2 枚(上 = 赤、下 = 青)。
        final image = await stitchPageShots([
          (image: await solid(50, 40, const ui.Color(0xFFFF0000)), top: 0),
          (image: await solid(50, 40, const ui.Color(0xFF0000FF)), top: 80),
        ], width: 100, height: 160);
        expect((image.width, image.height), (50, 80));
        final snap = PageSnapshot(width: 100, height: 160, viewportHeight: 80, image: image);
        expect(snap.imageScale, 0.5);
        // 下半分(CSS で y = 100〜140)を切り抜くと、青。
        final png = await cropPageSnapshot(snap, const ui.Rect.fromLTWH(10, 100, 40, 40));
        final codec = await ui.instantiateImageCodec(png!);
        final cut = (await codec.getNextFrame()).image;
        expect((cut.width, cut.height), (20, 20));
        final px = (await cut.toByteData(format: ui.ImageByteFormat.rawRgba))!;
        expect([px.getUint8(0), px.getUint8(1), px.getUint8(2)], [0, 0, 255]);
        expect(await cropPageSnapshot(snap, const ui.Rect.fromLTWH(500, 500, 10, 10)), isNull, reason: 'ページの外');
        expect(await cropPageSnapshot(const PageSnapshot(width: 100, height: 160, viewportHeight: 80), const ui.Rect.fromLTWH(0, 0, 50, 50)), isNull, reason: '写しが無い');
      });
    });

    test('探す言葉: 文字はそのものと @ハンドル、画像は RAi のキーワード', () {
      expect(pageSearchTermsOfText(' 撮影:  @hana_k '), ['撮影: @hana_k', 'hana_k']);
      expect(pageSearchTermsOfQuery(const DiscoverQuery(text: '茶トラの子猫', keywords: ['猫', '子猫', '茶トラ', '写真'])), ['猫', '子猫', '茶トラ', '茶トラの子猫']);
    });

    test('同時に走らせる数を守る', () async {
      var running = 0, peak = 0;
      final r = await runLimited([
        for (var i = 0; i < 7; i++)
          () async {
            running++;
            peak = running > peak ? running : peak;
            await Future<void>.delayed(const Duration(milliseconds: 5));
            running--;
            return i;
          },
      ], 3);
      expect(r, [0, 1, 2, 3, 4, 5, 6]);
      expect(peak, 3);
    });

    test('画像は 3 枚まで・同時に 3 枚まで。429 は待って送り直す。結果は重ねずにまとめる', () async {
      var running = 0, peak = 0, imageCalls = 0, textCalls = 0;
      var busy = true;
      final accountTerms = <String>[];
      final outcome = await runPageSearch(
        inputs: [
          const PageSearchInput.text('撮影: @hana_k'),
          for (var i = 0; i < 5; i++) PageSearchInput.image(Uint8List.fromList([i])),
        ],
        url: Uri.parse('https://example.com/cats'),
        retryWait: Duration.zero,
        content: ({frames = const [], text, url}) async {
          if (frames.isEmpty) {
            textCalls++;
            return ContentDiscoverResult.fromJson({'query': {'text': text, 'keywords': <String>[]}, 'lists': [{'id': 'l1', 'name': 'ねこ好き'}], 'servers': [{'host': 'misskey.io', 'kind': 'misskey'}], 'mode': 'rai'});
          }
          if (busy) {
            busy = false;
            throw OrgateException(ErrorCode.http(429), 'busy');
          }
          imageCalls++;
          running++;
          peak = running > peak ? running : peak;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          return ContentDiscoverResult.fromJson({'query': {'text': '茶トラの子猫', 'keywords': ['猫']}, 'lists': [{'id': 'l1', 'name': 'ねこ好き'}], 'servers': <Object>[], 'mode': 'dummy'});
        },
        searchAccounts: (t) async {
          accountTerms.add(t);
          return [RasqPostAuthor(id: 'a1', handle: 'hana', displayName: 'はな')];
        },
        searchPosts: (t) async => [RasqAccountPost(id: 'p-$t', body: t)],
      );
      expect(imageCalls, 3, reason: '画像は 3 枚まで');
      expect(peak, lessThanOrEqualTo(3));
      expect(textCalls, 1);
      expect(outcome.terms, ['撮影: @hana_k', 'hana_k', '猫', '茶トラの子猫']);
      expect(accountTerms.toSet(), outcome.terms.toSet());
      expect(outcome.accounts.single.handle, 'hana', reason: '同じ人は 1 度');
      expect(outcome.posts.length, 4);
      expect(outcome.lists.single.id, 'l1');
      expect(outcome.servers.single.host, 'misskey.io');
      expect(outcome.dummy, isTrue);
      expect(outcome.failedImages, 0);
    });

    Future<void> pumpSelect(WidgetTester tester, PageSnapshot snap) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: Consumer(
          // アプリと同じく、FOW のホストはナビゲーターの中(AppOverlayRoot)。
          builder: (context, ref, _) => MaterialApp(
            home: OverlayScope(
              manager: ref.watch(overlayManagerProvider),
              child: OverlayHost(manager: ref.watch(overlayManagerProvider), child: DiscoverPageSelectScreen(snapshot: snap)),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('囲むと検索文字列にページの文字が入る。タップで FOW: キャンセルは巻き戻し、決定は確定、消せる', (tester) async {
      // 写しの画像が無い端末(見取り図): 文字で探す。
      await pumpSelect(tester, const PageSnapshot(width: 400, height: 1600, viewportHeight: 800, texts: texts));
      expect(find.byKey(const ValueKey('discover.page.hint')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('discover.page.search'))).onPressed, isNull);
      final canvas = tester.getTopLeft(find.byKey(const ValueKey('discover.page.canvas')));
      await tester.dragFrom(canvas + const Offset(10, 10), const Offset(300, 80));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.page.region.0')), findsOneWidget);
      expect(find.text('1 か所を探す'), findsOneWidget);
      // 2 つ目(文字の無いところ): 画像が無いので探せない囲み。
      await tester.dragFrom(canvas + const Offset(250, 300), const Offset(100, 100));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.page.region.1')), findsOneWidget);
      expect(find.text('1 か所を探す'), findsOneWidget);

      // FOW で直して、キャンセル → 巻き戻る。
      await tester.tap(find.byKey(const ValueKey('discover.page.region.1')));
      await tester.pumpAndSettle();
      final query = find.byKey(const ValueKey('discover.page.region.query'));
      expect(query, findsOneWidget);
      await tester.enterText(query, 'ねこ');
      await tester.pumpAndSettle();
      expect(find.text('2 か所を探す'), findsOneWidget, reason: '直している間は画面に反映する');
      await tester.tap(find.text('キャンセル'));
      await tester.pumpAndSettle();
      expect(find.text('1 か所を探す'), findsOneWidget);

      // もう一度直して、決定 → 残る。
      await tester.tap(find.byKey(const ValueKey('discover.page.region.1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('discover.page.region.query')), 'ねこ');
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();
      expect(find.text('2 か所を探す'), findsOneWidget);

      // 1 つ目の検索文字列は、囲んだところのページの文字。消すと無くなる。
      await tester.tap(find.byKey(const ValueKey('discover.page.region.0')));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byKey(const ValueKey('discover.page.region.query'))).controller!.text, 'ねこ写真まとめ 撮影: @hana_k');
      // 画像が無いので、画像で探す / 画像エディターは選べない。
      expect(tester.widget<OutlinedButton>(find.byKey(const ValueKey('discover.page.region.editor'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('discover.page.region.delete')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.page.region.0')), findsNothing);
      expect(find.text('1 か所を探す'), findsOneWidget);
    });

    testWidgets('結果の画面: 探した言葉・RASQ のユーザー・投稿・リスト / サーバー', (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: DiscoverPageResultsScreen(
            outcome: PageSearchOutcome(
              terms: const ['ねこ'],
              accounts: [RasqPostAuthor(id: 'a1', handle: 'hana', displayName: 'はな')],
              posts: [RasqAccountPost(id: 'p1', body: 'ねこの写真です', author: RasqPostAuthor(id: 'a1', handle: 'hana', displayName: 'はな'))],
              lists: const [ListHit(id: 'l1', name: 'ねこ好き')],
              failedImages: 1,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('discover.page.term.ねこ')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.account.hana')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.page.post.p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.listHit.l1')), findsOneWidget);
      expect(find.byKey(const ValueKey('discover.page.imagesFailed')), findsOneWidget);
    });
  });
}
