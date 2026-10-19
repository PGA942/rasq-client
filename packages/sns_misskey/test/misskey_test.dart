import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart';
import 'package:test/test.dart';

const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.test', handle: 'me');

Map<String, Object?> user(String id, {String? host}) => {'id': id, 'username': id, 'name': '名前$id', 'host': host, 'avatarUrl': 'https://a/$id.png'};

Map<String, Object?> note(String id, {String? text = 'hello :blobcat:', Map<String, Object?>? renote, Map<String, Object?>? reply, List<Map<String, Object?>> files = const [], Object? poll, String? myReaction}) => {
      'id': id,
      'createdAt': '2026-08-22T00:00:00.000Z',
      'text': text,
      'user': user('u$id'),
      'renote': renote,
      'reply': reply,
      'replyId': reply?['id'],
      'files': files,
      'fileIds': [for (final f in files) f['id']],
      'poll': poll,
      'reactions': {'👍': 2, ':blobcat:': 1},
      'myReaction': myReaction,
      'renoteCount': 3,
      'repliesCount': 1,
    };

void main() {
  group('mappers', () {
    test('note → Post with media, poll, counts', () {
      final p = MisskeyMappers.note(
        note('n1', files: [
          {'id': 'f1', 'type': 'image/png', 'url': 'https://f/1.png', 'isSensitive': true, 'properties': {'width': 16, 'height': 9}},
          {'id': 'f2', 'type': 'video/mp4', 'url': 'https://f/2.mp4'},
        ], poll: {
          'choices': [
            {'text': 'a', 'votes': 1, 'isVoted': true},
            {'text': 'b', 'votes': 0, 'isVoted': false},
          ],
          'multiple': false,
        }),
        viewer: viewer,
        host: 'misskey.test',
      );
      expect(p.author.account.instance, 'misskey.test'); // local user → viewer host
      expect(p.media.length, 2);
      expect(p.media.first.sensitive, isTrue);
      expect(p.media.first.aspectRatio, closeTo(16 / 9, 0.001));
      expect(p.media[1].type, MediaType.video);
      expect(p.poll!.votedIndices, {0});
      expect(p.counts['reaction'], 3);
      expect(p.counts['renote'], 3);
      expect(p.bodyFormat, 'mfm');
      expect(p.key, '${viewer.key}:n1');
    });

    test('pure renote → inner note with repostedBy; quote keeps outer text', () {
      final pure = MisskeyMappers.note(note('r1', text: null, renote: note('n2')), viewer: viewer, host: 'misskey.test');
      expect(pure.id, 'r1');
      expect(pure.body, 'hello :blobcat:');
      expect(pure.repostedBy!.displayName, '名前ur1');
      expect(pure.author.id, 'un2');
      // リアクション表示 (D-111): チップ/自分のリアクションは中身のノートから
      // コピーされる(落とすとフォロー外ユーザーの RT で一切出ない)。
      expect(pure.reactions, {'👍': 2, ':blobcat:': 1});
      expect(pure.counts['reaction'], 3);

      final quote = MisskeyMappers.note(note('q1', text: 'QT!', renote: note('n3')), viewer: viewer, host: 'misskey.test');
      expect(quote.body, 'QT!');
      expect(quote.quote!.id, 'n3');
      expect(quote.repostedBy, isNull);
    });

    test('reactionAcceptance (D-321): ノートの「いいねのみ」を載せる。純リノートは中身のノートのもの', () {
      final like = MisskeyMappers.note({...note('n4'), 'reactionAcceptance': 'likeOnly'}, viewer: viewer, host: 'misskey.test');
      expect(like.reactionAcceptance, 'likeOnly');
      final pure = MisskeyMappers.note(note('r2', text: null, renote: {...note('n5'), 'reactionAcceptance': 'likeOnlyForRemote'}), viewer: viewer, host: 'misskey.test');
      expect(pure.reactionAcceptance, 'likeOnlyForRemote');
      expect(MisskeyMappers.note(note('n6'), viewer: viewer, host: 'misskey.test').reactionAcceptance, isNull);
    });

    test('remote user keeps its own host', () {
      final u = MisskeyMappers.user(user('bob', host: 'other.example'), account: viewer, host: 'misskey.test');
      expect(u.account.instance, 'other.example');
      expect(u.handle, 'bob');
    });

    test('notification kinds', () {
      final n = MisskeyMappers.notification({'id': 'x', 'type': 'reaction', 'createdAt': '2026-08-22T00:00:00Z', 'user': user('a'), 'note': note('n9'), 'reaction': '👍'}, viewer: viewer, host: 'misskey.test');
      expect(n.kind, NotificationKind.reaction);
      expect(n.kind.tile, NotificationTileType.action);
      expect(n.actors.single.id, 'a');
      expect(n.post!.id, 'n9');
    });
  });

  group('MiAuth + session (mock http)', () {
    MockClient client(Map<String, Object? Function(Map<String, Object?> body)> routes) => MockClient((req) async {
          final path = req.url.path.replaceFirst('/api/', '');
          final body = req.body.isEmpty ? <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
          final h = routes[path];
          if (h == null) return http.Response(jsonEncode({'error': {'message': 'no route $path', 'code': 'NOT_FOUND'}}), 404);
          final r = h(body);
          return http.Response(jsonEncode(r), 200, headers: {'content-type': 'application/json'});
        });

    test('MiAuth url and check → AuthResult', () async {
      final c = client({
        'miauth/abc/check': (_) => {'ok': true, 'token': 'TOKEN', 'user': user('me')},
      });
      final plugin = MisskeyPlugin(client: c);
      final flow = await plugin.beginAuth('https://misskey.test/') as MiAuthFlow;
      expect(flow.host, 'misskey.test');
      expect(flow.url.host, 'misskey.test');
      expect(flow.url.queryParameters['permission'], contains('write:notes'));

      final flow2 = MiAuthFlow(host: 'misskey.test', pluginId: MisskeyPlugin.pluginId, permissions: const ['read:account'], sessionId: 'abc', client: c);
      final result = await flow2.complete();
      expect(result.session.token, 'TOKEN');
      expect(result.session.account.handle, 'me');
      expect(result.me.displayName, '名前me');
    });

    test('アカウントの設定 (D-482): i から文字・公開範囲を読み、1 キーずつ i/update へ(許可リストと値の形)', () async {
      final sent = <Map<String, Object?>>[];
      final c = client({
        'i': (_) => {'id': 'me', 'name': 'ゼポス', 'description': null, 'isLocked': true, 'isCat': true, 'ffVisibility': 'followers'},
        'i/update': (body) {
          sent.add(body);
          return {'id': 'me', 'name': body['name'], 'location': body['location'], 'followingVisibility': 'private', 'followersVisibility': 'public'};
        },
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final read = await s.settingsRead('account');
      expect(read['name'], 'ゼポス');
      expect(read['description'], '');
      expect(read['isLocked'], isTrue);
      expect(read['isExplorable'], isTrue); // 欠けたら既定
      expect((read['followingVisibility'], read['followersVisibility']), ('followers', 'followers')); // 古いサーバーの ffVisibility
      expect(read.keys.toSet(), MisskeyAccountSettings.defaults.keys.toSet());

      final wrote = await s.settingsWrite('account', 'name', '  新しい名前 ');
      expect(sent.single['name'], '新しい名前');
      expect(wrote['name'], '新しい名前');
      expect(wrote['followingVisibility'], 'private'); // 書いたあとのサーバーの値
      await s.settingsWrite('account', 'location', '');
      expect(sent.last.containsKey('location') && sent.last['location'] == null, isTrue); // 空 = 消す

      expect(() => s.settingsWrite('account', 'isAdmin', true), throwsUnsupportedError);
      expect(() => s.settingsWrite('account', 'birthday', '31/01/2000'), throwsArgumentError);
      expect(() => s.settingsWrite('account', 'followersVisibility', 'everyone'), throwsArgumentError);
      expect(() => s.settingsWrite('account', 'isLocked', 'yes'), throwsArgumentError);
    });

    test('サーバーの広告 (D-438): meta.ads を読み、形の違うもの / https でない画像は捨てる。1 セッション 1 回', () async {
      var calls = 0;
      final c = client({
        'meta': (_) {
          calls++;
          return {
            'ads': [
              {'id': 'a1', 'url': 'https://shop.example/', 'imageUrl': 'https://misskey.test/ad1.png', 'place': 'horizontal', 'ratio': 3, 'dayOfWeek': 0},
              {'id': 'a2', 'url': 'https://x.example/', 'imageUrl': 'http://misskey.test/insecure.png'},
              {'id': 'a3', 'url': 'javascript:alert(1)', 'imageUrl': 'https://misskey.test/ad3.png'},
              'broken',
            ],
          };
        },
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final ads = await s.serverAds();
      expect(ads.map((a) => (a.id, a.ratio, a.place)), [('a1', 3, 'horizontal')]);
      await s.serverAds();
      expect(calls, 1);
      // 曜日のビット(日曜 = 1 … 土曜 = 64)。
      final sunOnly = ServerAd(id: 'x', url: Uri.parse('https://a/'), imageUrl: Uri.parse('https://a/i.png'), dayOfWeek: 1);
      expect(sunOnly.showsOn(DateTime.sunday), isTrue);
      expect(sunOnly.showsOn(DateTime.monday), isFalse);
      // 読めなければ空(TL は止めない)。
      final broken = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: client({}));
      expect(await broken.serverAds(), isEmpty);
    });

    test('MiAuth not yet approved → 401 SnsApiException', () async {
      final c = client({'miauth/abc/check': (_) => {'ok': false}});
      final flow = MiAuthFlow(host: 'misskey.test', pluginId: 'p', permissions: const [], sessionId: 'abc', client: c);
      await expectLater(flow.complete(), throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', '401')));
    });


    test('クリップ (D-032): 一覧/中身/作成/追加/削除', () async {
      late Map<String, Object?> seenAdd;
      final clipJson = {'id': 'cl1', 'name': '旅行の候補', 'isPublic': true, 'notesCount': 2, 'user': user('carol')};
      final c = client({
        'clips/list': (_) => [clipJson],
        'users/clips': (b) => b['userId'] == 'carol' ? [clipJson] : [],
        'clips/show': (b) => clipJson,
        'clips/notes': (b) => [note('n1'), note('n2')],
        'clips/create': (b) => {'id': 'cl2', 'name': b['name'], 'isPublic': b['isPublic'], 'notesCount': 0},
        'clips/add-note': (b) { seenAdd = b; return {}; },
        'clips/remove-note': (b) => {},
        'clips/delete': (b) => {},
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);

      final mine = await s.clips();
      expect(mine.single.name, '旅行の候補');
      expect(mine.single.isPublic, isTrue);
      expect(mine.single.notesCount, 2);
      expect(mine.single.owner?.displayName, '名前carol');
      expect(mine.single.isHost, isFalse);

      expect(await s.clips(userId: 'carol'), hasLength(1));
      expect((await s.clipInfo('cl1')).id, 'cl1');

      final page = await s.clipNotes('cl1', limit: 20);
      expect(page.items.map((p) => p.id), ['n1', 'n2']);
      expect(page.nextCursor, isNull, reason: 'limit 未満なら次ページなし');

      final created = await s.createClip('新規', isPublic: true);
      expect(created.id, 'cl2');
      await s.addToClip('cl1', 'n9');
      expect(seenAdd, {'i': 'T', 'clipId': 'cl1', 'noteId': 'n9'});
      await s.removeFromClip('cl1', 'n9');
      await s.deleteClip('cl1');
    });


    test('Play (D-039): users/flashs → PlayInfo(外部リンク)', () async {
      final c = client({
        'users/flashs': (b) => b['userId'] == 'carol'
            ? [
                {'id': 'fl1', 'title': 'おみくじ', 'summary': '今日の運勢'},
              ]
            : [],
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final plays = await s.userPlays('carol');
      expect(plays.single.title, 'おみくじ');
      expect(plays.single.summary, '今日の運勢');
      expect(plays.single.url.toString(), 'https://misskey.test/play/fl1');
    });


    test('reactionIcon (D-040): Unicode はテキスト、カスタムは /emoji URL', () {
      expect(MisskeySession.reactionIcon(null, 'misskey.test'), isNull);
      final uni = MisskeySession.reactionIcon('❤', 'misskey.test')!;
      expect(uni.text, '❤');
      expect(uni.url, isNull);
      final custom = MisskeySession.reactionIcon(':blobcat@.:', 'misskey.test')!;
      expect(custom.url.toString(), 'https://misskey.test/emoji/blobcat.webp');
      expect(custom.text, isNull);
    });

    test('timelineWithStates sends token & untilId, maps done flags', () async {
      late Map<String, Object?> seen;
      final c = client({
        'notes/timeline': (b) {
          seen = b;
          return [note('n1', myReaction: '👍'), note('n2')];
        },
        'notes/reactions/create': (_) => {},
        'notes/show': (_) => note('n2', myReaction: '👍'),
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: MisskeyPlugin.pluginId, token: 'T', createdAt: DateTime(2026)), client: c);
      final (page, states) = await s.timelineWithStates(TimelineKind.home, cursor: 'c0', limit: 2);
      expect(seen['i'], 'T');
      expect(seen['untilId'], 'c0');
      expect(page.items.length, 2);
      expect(page.nextCursor, 'n2');
      expect(states['n1']!['reaction']!.done, isTrue);
      expect(states['n2']!['reaction']!.done, isFalse);

      final r = await s.performAction('reaction', 'n2');
      expect(r.done, isTrue);
      expect(r.count, 3);
    });

    test('プラグイン設定 (D-044): applySettings→TLパラメーター、account は i/i update', () async {
      late Map<String, Object?> seenTl;
      Map<String, Object?>? seenUpdate;
      final me = {'isLocked': true, 'isExplorable': true, 'hideOnlineStatus': false, 'publicReactions': true, 'isBot': false, 'isCat': false};
      final c = client({
        'notes/timeline': (b) {
          seenTl = b;
          return [];
        },
        'i': (_) => me,
        'i/update': (b) {
          seenUpdate = b;
          return {...me, 'isCat': true};
        },
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: MisskeyPlugin.pluginId, token: 'T', createdAt: DateTime(2026)), client: c);

      // 既定値: withRenotes オン / withReplies オフ。
      await s.timeline(TimelineKind.home);
      expect(seenTl['withRenotes'], isTrue);
      expect(seenTl['withReplies'], isFalse);

      await s.applySettings('timeline', {'withRenotes': false, 'withReplies': true});
      await s.timeline(TimelineKind.home);
      expect(seenTl['withRenotes'], isFalse);
      expect(seenTl['withReplies'], isTrue);

      // account = remote ページ: i から読み、i/update へ 1 キー書き込み。
      final read = await s.settingsRead('account');
      expect(read['isLocked'], isTrue);
      expect(read['isCat'], isFalse);
      final after = await s.settingsWrite('account', 'isCat', true);
      expect(seenUpdate?['isCat'], isTrue);
      expect(after['isCat'], isTrue);
      // 許可リスト外のキーは投げる(パスワード系を DSL から触らせない)。
      await expectLater(s.settingsWrite('account', 'password', 'x'), throwsUnsupportedError);
    });

    test('createPost (D-045): visibility/localOnly/reactionAcceptance を送る', () async {
      late Map<String, Object?> seen;
      final c = client({
        'notes/create': (b) {
          seen = b;
          return {'createdNote': note('n9')};
        },
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: MisskeyPlugin.pluginId, token: 'T', createdAt: DateTime(2026)), client: c);
      await s.createPost(const NewPost(text: 't', visibility: 'home', localOnly: true, reactionAcceptance: 'likeOnly'));
      expect(seen['visibility'], 'home');
      expect(seen['localOnly'], isTrue);
      expect(seen['reactionAcceptance'], 'likeOnly');

      // 既定(未指定)では送らない — サーバー既定に任せる。
      await s.createPost(const NewPost(text: 't2'));
      expect(seen.containsKey('localOnly'), isFalse);
      expect(seen.containsKey('reactionAcceptance'), isFalse);

      // ダイレクト (D-047): specified には宛先 visibleUserIds を添える。
      await s.createPost(const NewPost(text: 't3', visibility: 'specified', directToIds: ['peer1', 'peer2']));
      expect(seen['visibility'], 'specified');
      expect(seen['visibleUserIds'], ['peer1', 'peer2']);
    });

    // 本文なしのメディアだけの投稿 (D-494): Misskey の notes/create は `text` / `cw` が minLength 1、`fileIds` が minItems 1。
    // 空文字 / 空配列を送ると 400 INVALID_PARAM(Bad Request)になる。サーバーと同じ検査をするフェイクで確かめる。
    group('本文なしの投稿 (D-494)', () {
      late List<Map<String, Object?>> sent;
      http.Response strict(Map<String, Object?> b, Map<String, Object?> created) {
        sent.add(b);
        String? invalid;
        for (final k in ['text', 'cw']) {
          if (b.containsKey(k) && b[k] is String && (b[k] as String).isEmpty) invalid = k;
        }
        if (b['fileIds'] is List && (b['fileIds'] as List).isEmpty) invalid = 'fileIds';
        final hasContent = (b['text'] is String) || b['fileIds'] is List || b['poll'] != null || b['renoteId'] != null;
        if (invalid != null) return http.Response(jsonEncode({'error': {'message': 'Invalid param.', 'code': 'INVALID_PARAM', 'info': {'param': invalid}}}), 400);
        if (!hasContent) return http.Response(jsonEncode({'error': {'message': 'No content.', 'code': 'INVALID_PARAM'}}), 400);
        return http.Response(jsonEncode(created), 200, headers: {'content-type': 'application/json'});
      }

      MisskeySession session(String endpoint, Map<String, Object?> created) {
        sent = [];
        final c = MockClient((req) async {
          final path = req.url.path.replaceFirst('/api/', '');
          final body = req.body.isEmpty ? <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
          if (path != endpoint) return http.Response(jsonEncode({'error': {'message': 'no route $path', 'code': 'NOT_FOUND'}}), 404);
          return strict(body, created);
        });
        return MisskeySession(AccountSession(account: viewer, pluginId: MisskeyPlugin.pluginId, token: 'T', createdAt: DateTime(2026)), client: c);
      }

      test('メディアだけ: text を送らず fileIds だけ', () async {
        final s = session('notes/create', {'createdNote': note('m1', text: null)});
        final p = await s.createPost(const NewPost(text: '', mediaIds: ['f1', 'f2']));
        expect(p.id, 'm1');
        expect(sent.single.containsKey('text'), isFalse);
        expect(sent.single['fileIds'], ['f1', 'f2']);
      });

      test('空白だけの本文も送らない / 空の注釈も送らない', () async {
        final s = session('notes/create', {'createdNote': note('m2', text: null)});
        await s.createPost(const NewPost(text: '  \n', contentWarning: '', mediaIds: ['f1']));
        expect(sent.single.containsKey('text'), isFalse);
        expect(sent.single.containsKey('cw'), isFalse);
      });

      test('返信 / 引用 + メディアだけ、投票だけ', () async {
        final s = session('notes/create', {'createdNote': note('m3', text: null)});
        await s.createPost(const NewPost(text: '', replyToId: 'p1', mediaIds: ['f1']));
        expect(sent.last['replyId'], 'p1');
        expect(sent.last.containsKey('text'), isFalse);
        await s.createPost(const NewPost(text: '', quoteOfId: 'q1', mediaIds: ['f1']));
        expect(sent.last['renoteId'], 'q1');
        expect(sent.last.containsKey('text'), isFalse);
        await s.createPost(const NewPost(text: '', poll: NewPoll(choices: ['a', 'b'])));
        expect(sent.last.containsKey('text'), isFalse);
        expect((sent.last['poll'] as Map)['choices'], ['a', 'b']);
        // 注釈だけ付けた(本文なし)メディア投稿でも、注釈は送る。
        await s.createPost(const NewPost(text: '', contentWarning: '注意', mediaIds: ['f1']));
        expect(sent.last['cw'], '注意');
        expect(sent.last.containsKey('text'), isFalse);
      });

      test('本文は空白を含めてそのまま送る(前後の改行を削らない)', () async {
        final s = session('notes/create', {'createdNote': note('m4')});
        await s.createPost(const NewPost(text: 'a\n', mediaIds: ['f1']));
        expect(sent.single['text'], 'a\n');
      });

      test('ダイレクト(限定公開ノート)の DM もメディアだけで送れる', () async {
        final s = session('notes/create', {'createdNote': {...note('d2', text: null), 'visibility': 'specified', 'visibleUserIds': ['alice']}});
        final room = DmRoom(id: 'alice', peer: MisskeyMappers.user(user('alice'), account: viewer, host: 'misskey.test'));
        await s.sendDm(room, const NewPost(text: '', contentWarning: '', mediaIds: ['f1']));
        expect(sent.single.containsKey('text'), isFalse);
        expect(sent.single.containsKey('cw'), isFalse);
        expect(sent.single['fileIds'], ['f1']);
      });
    });

    test('mapper (D-047): localOnly / visibleUserIds を Post に写す', () {
      final p = MisskeyMappers.note({...note('n1'), 'visibility': 'specified', 'localOnly': true, 'visibleUserIds': ['peer1']}, viewer: viewer, host: 'misskey.test');
      expect(p.isDirect, isTrue);
      expect(p.localOnly, isTrue);
      expect(p.directToIds, ['peer1']);
    });

    test('システム通知 (D-045): app/roleAssigned/未知タイプ → system + title/body', () {
      NotificationItem map(Map<String, Object?> j) => MisskeyMappers.notification({'id': 'x', 'createdAt': '2026-08-28T00:00:00.000Z', ...j}, viewer: viewer, host: 'misskey.test');

      final app = map({'type': 'app', 'header': 'メンテナンスのお知らせ', 'body': '本日 2 時から'});
      expect(app.kind, NotificationKind.system);
      expect(app.title, 'メンテナンスのお知らせ');
      expect(app.body, '本日 2 時から');

      final role = map({'type': 'roleAssigned', 'role': {'name': 'モデレーター'}});
      expect(role.kind, NotificationKind.system);
      expect(role.title, 'ロールが付与されました');
      expect(role.body, 'モデレーター');

      // 未知タイプも落とさずシステム通知として縮退表示する。
      final unknown = map({'type': 'somethingNew2027'});
      expect(unknown.kind, NotificationKind.system);
      expect(unknown.title, '通知 (somethingNew2027)');

      // 既存タイプは従来どおり(title/body なし)。
      final follow = map({'type': 'follow', 'user': user('alice')});
      expect(follow.kind, NotificationKind.follow);
      expect(follow.title, isNull);
    });

    test('MiAuth スコープ (D-045): write:account / write:votes を要求する', () {
      expect(MiAuthFlow.defaultPermissions, containsAll(['write:account', 'write:votes']));
    });

    test('設定ページ (D-044): 4 ページとも rasq.settings-page/1 として解釈できる', () {
      final pages = MisskeyPlugin().settingsPages;
      final areas = <String>[];
      for (final raw in pages) {
        final j = (jsonDecode(raw) as Map).cast<String, Object?>();
        expect(j['schema'], 'rasq.settings-page/1');
        expect(j['root'], isA<Map<String, Object?>>());
        areas.add(j['area'] as String);
      }
      expect(areas, ['account', 'timeline', 'safety', 'security']);
      // account はサーバー保存 (source: remote)。書くタイル(設定タイルの change / 文字の欄の submit)のキーはすべて許可リストにある (D-482)。
      final account = (jsonDecode(pages.first) as Map).cast<String, Object?>();
      expect(account['source'], 'remote');
      final keys = {
        for (final n in ((account['root'] as Map)['c'] as List).cast<Map<String, Object?>>())
          if ((n['on'] as Map?)?.values.contains('settings.set') ?? false) n['k'],
      };
      expect(keys, containsAll(['name', 'description', 'birthday', 'followersVisibility', 'isCat']));
      expect(MisskeyAccountSettings.defaults.keys.toSet().containsAll(keys), isTrue);
    });

    test('transport errors are not reported as 408', () async {
      final cors = MisskeyApi('misskey.test', client: MockClient((_) async => throw http.ClientException('Failed to fetch')));
      await expectLater(cors.call('meta'), throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'B03')));
      final denied = MisskeyApi('misskey.test', client: MockClient((_) async => throw const _Socket('Operation not permitted')));
      await expectLater(denied.call('meta'), throwsA(isA<SnsApiException>().having((e) => e.code.message, 'message', contains('サンドボックス'))));
    });

    test('tag / featured timelines and trending tags', () async {
      late String seenTag;
      final c = client({
        'notes/search-by-tag': (b) {
          seenTag = b['tag'] as String;
          return [note('t1')];
        },
        'notes/featured': (_) => [note('f1'), note('f2')],
        'hashtags/trend': (_) => [
              {'tag': '打上会', 'usersCount': 117, 'chart': [1, 2, 3]},
            ],
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final tag = await s.timeline(DynamicTimelines.tag('打上会'));
      expect(seenTag, '打上会');
      expect(tag.items.single.id, 't1');
      final featured = await s.timeline(DynamicTimelines.featured);
      expect(featured.items.length, 2);
      expect(featured.nextCursor, isNull);
      final trends = await s.trendingTags();
      expect(trends.single.tag, '打上会');
      expect(trends.single.usersCount, 117);
    });

    test('DM rooms group direct notes per peer (received + sent)', () async {
      Map<String, Object?> direct(String id, String authorId, List<String> to, String at) => {
            ...note(id),
            'userId': authorId,
            'user': user(authorId),
            'visibility': 'specified',
            'visibleUserIds': to,
            'createdAt': at,
          };
      final c = client({
        'i': (_) => {'id': 'me', 'username': 'me'},
        'notes/mentions': (_) => [direct('r1', 'alice', ['me'], '2026-08-22T10:00:00Z'), direct('r2', 'bob', ['me'], '2026-08-22T09:00:00Z')],
        'users/notes': (_) => [direct('s1', 'me', ['alice'], '2026-08-22T11:00:00Z'), {...note('pub'), 'userId': 'me', 'visibility': 'public'}],
        'users/show': (b) => [for (final id in (b['userIds'] as List)) user(id as String)],
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final rooms = await s.dmRooms();
      expect(rooms.map((r) => r.peer.id).toSet(), {'alice', 'bob'});
      expect(rooms.firstWhere((r) => r.peer.id == 'alice').lastPost!.id, 's1'); // newest (sent) wins
      final room = await s.timeline(DynamicTimelines.dm('alice'));
      expect(room.items.map((p) => p.id).toList(), ['s1', 'r1']);
      expect(room.items.first.isDirect, isTrue);
    });

    test('reactions / reposters / users / relationships', () async {
      final c = client({
        'notes/reactions': (b) => [
              {'id': 'x1', 'createdAt': '2026-08-22T00:00:00Z', 'type': '👍', 'user': user('a')},
              {'id': 'x2', 'createdAt': '2026-08-22T00:00:00Z', 'type': ':blobcat:', 'user': user('b')},
            ],
        'emojis': (_) => {'emojis': [{'name': 'blobcat', 'url': 'https://e/blobcat.png', 'category': 'cats'}]},
        'notes/renotes': (_) => [{'id': 'rn1', 'user': user('c')}],
        'users/show': (b) => [for (final id in (b['userIds'] as List)) {...user(id as String), 'followersCount': 3}],
        'users/relation': (b) => [for (final id in (b['userId'] as List)) {'id': id, 'isFollowing': id == 'a', 'isFollowed': false}],
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final r = await s.reactions('n1');
      expect(r.items.length, 2);
      expect(r.items[1].emojiUrl.toString(), 'https://e/blobcat.png');
      expect((await s.reposters('n1')).items.single.id, 'c');
      expect((await s.users(['a', 'b'])).map((u) => u.followersCount).toList(), [3, 3]);
      final rel = await s.relationships(['a', 'b']);
      expect(rel['a']!.following, isTrue);
      expect(rel['b']!.following, isFalse);
      expect((await s.customEmojis()).single.category, 'cats');
    });

    test('chat: rooms + timeline when available; silently empty on 404', () async {
      Map<String, Object?> msg(String id, String from, String to, String text) => {'id': id, 'createdAt': '2026-08-22T00:00:00Z', 'fromUserId': from, 'toUserId': to, 'text': text, 'fromUser': user(from), 'toUser': user(to), 'isRead': false};
      final c = client({
        'i': (_) => user('me'),
        'notes/mentions': (_) => [],
        'users/notes': (_) => [],
        'chat/history': (_) => [msg('c1', 'alice', 'me', 'hi')],
        'chat/messages/user-timeline': (_) => [msg('c1', 'alice', 'me', 'hi'), msg('c0', 'me', 'alice', 'yo')],
        'chat/messages/create-to-user': (b) => msg('c2', 'me', b['toUserId'] as String, b['text'] as String),
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final rooms = await s.dmRooms();
      expect(rooms.single.kind, DmRoomKind.chat);
      expect(rooms.single.peer.id, 'alice');
      expect(rooms.single.unreadCount, 1);
      final tl = await s.timeline(DynamicTimelines.forRoom(rooms.single));
      expect(tl.items.map((p) => p.author.id).toList(), ['alice', 'me']);
      expect(tl.items.first.source, PostSource.chatMessage);
      final sent = await s.sendDm(rooms.single, const NewPost(text: 'hello'));
      expect(sent.body, 'hello');

      final noChat = client({'i': (_) => user('me'), 'notes/mentions': (_) => [], 'users/notes': (_) => []});
      final s2 = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: noChat);
      expect(await s2.dmRooms(), isEmpty);
    });

    test('direct-note DM send uses specified visibility', () async {
      late Map<String, Object?> seen;
      final c = client({'notes/create': (b) {
            seen = b;
            return {'createdNote': {...note('d1'), 'visibility': 'specified', 'visibleUserIds': ['alice']}};
          }});
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final room = DmRoom(id: 'alice', peer: MisskeyMappers.user(user('alice'), account: viewer, host: 'misskey.test'));
      final p = await s.sendDm(room, const NewPost(text: 'secret'));
      expect(seen['visibility'], 'specified');
      expect(seen['visibleUserIds'], ['alice']);
      expect(p.isDirect, isTrue);
    });

    test('grouped notifications, user posts filters, follow requests, mute/block lists', () async {
      late Map<String, Object?> seenNotes;
      final c = client({
        'i/notifications-grouped': (_) => [
              {'id': 'g1', 'type': 'reaction:grouped', 'createdAt': '2026-08-22T00:00:00Z', 'note': note('n1'), 'reactions': [
                    {'user': user('a'), 'reaction': '👍'},
                    {'user': user('b'), 'reaction': '🎉'},
                  ]},
              {'id': 'g2', 'type': 'renote:grouped', 'createdAt': '2026-08-22T00:00:00Z', 'note': note('n2'), 'users': [user('c'), user('d')]},
            ],
        'users/notes': (b) {
          seenNotes = b;
          return [note('q1', renote: note('x')), note('p1'), note('r1', reply: note('parent1', files: [{'id': 'f', 'type': 'image/png', 'url': 'https://f/p.png'}]))];
        },
        'notes/renotes': (_) => [note('q1', renote: note('x')), note('pure', text: null, renote: note('x')), note('r2', renote: note('x'))],
        'following/requests/list': (_) => [{'id': 'fr1', 'follower': user('e'), 'followee': user('me')}],
        'mute/list': (_) => [{'id': 'm1', 'mutee': user('f')}],
        'blocking/list': (_) => [{'id': 'b1', 'blockee': user('g')}],
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final n = await s.notifications();
      expect(n.items[0].kind, NotificationKind.reaction);
      expect(n.items[0].actors.length, 2);
      expect(n.items[0].reactionsByActor['b'], '🎉');
      expect(n.items[1].actors.length, 2);
      final media = await s.userPosts('u', filter: UserPostsFilter.media);
      expect(seenNotes['withFiles'], isTrue);
      expect(media.items.length, 3);
      // 返信TL / 引用TL への振り分け (D-069): 返信は返信のみ・引用は引用のみ・
      // ノートは両方を除く。返信には replyTo(リプライ元)が載る。
      final quotes = await s.userPosts('u', filter: UserPostsFilter.quotes);
      expect(quotes.items.single.id, 'q1');
      final replies = await s.userPosts('u', filter: UserPostsFilter.replies);
      expect(seenNotes['withReplies'], isTrue);
      expect(replies.items.single.id, 'r1');
      expect(replies.items.single.replyTo?.id, 'parent1');
      expect(replies.items.single.replyTo?.media, hasLength(1));
      final posts = await s.userPosts('u', filter: UserPostsFilter.posts);
      expect([for (final p in posts.items) p.id], ['p1']);
      // 引用ノート一覧 (D-070): notes/renotes から引用のみ(純リノート除外)。
      final quoteNotes = await s.quotes('x');
      expect([for (final q in quoteNotes.items) q.id], ['q1', 'r2']);
      expect((await s.followRequests()).single.user.id, 'e');
      expect((await s.mutedUsers()).items.single.id, 'f');
      expect((await s.blockedUsers()).items.single.id, 'g');
    });

    test('profile update, lists, favorites', () async {
      late Map<String, Object?> seenUpdate;
      final c = client({
        'i/update': (b) {
          seenUpdate = b;
          return {...user('me'), 'name': b['name'], 'fields': b['fields']};
        },
        'users/lists/list': (_) => [{'id': 'l1', 'name': 'Fediverse Banner', 'userIds': ['a', 'b']}],
        'users/lists/show': (_) => {'id': 'l1', 'name': 'Fediverse Banner', 'userIds': ['a', 'b']},
        'users/show': (b) => [for (final id in (b['userIds'] as List)) user(id as String)],
        'users/lists/create': (b) => {'id': 'l2', 'name': b['name'], 'userIds': []},
        'i/favorites': (_) => [{'id': 'f1', 'note': note('n1')}],
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: 'p', token: 'T', createdAt: DateTime(2026)), client: c);
      final p = await s.updateProfile(const ProfileUpdate(displayName: 'タロ', fields: [(name: 'web', value: 'https://x')]));
      expect(seenUpdate['name'], 'タロ');
      expect((seenUpdate['fields'] as List).single, {'name': 'web', 'value': 'https://x'});
      expect(p.summary.displayName, 'タロ');
      expect((await s.lists()).single.memberIds, ['a', 'b']);
      expect((await s.listMembers('l1')).map((u) => u.id).toList(), ['a', 'b']);
      expect((await s.createList('new')).id, 'l2');
      expect((await s.favorites()).items.single.id, 'n1');
    });

    test('http error → SnsApiException with HTTP code', () async {
      final c = MockClient((_) async => http.Response(jsonEncode({'error': {'message': 'Unauthorized', 'code': 'CREDENTIAL_REQUIRED'}}), 401));
      final api = MisskeyApi('misskey.test', client: c);
      await expectLater(api.call('i'), throwsA(isA<SnsApiException>().having((e) => e.code.display, 'display', 'Error:401 Unauthorized')));
    });
  });
}

class _Socket implements Exception {
  const _Socket(this.m);
  final String m;
  @override
  String toString() => 'SocketException: $m';
}
