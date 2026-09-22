import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// The Mastodon plugin, built from rasq-sdk-sample:
/// `cargo build --release --target wasm32-unknown-unknown -p mastodon-wasm`.
File get wasmFile => File('../../../rasq-sdk-sample/rust/target/wasm32-unknown-unknown/release/mastodon_wasm.wasm');

/// D-135: Mastodon プラグイン。Misskey サンプルと**同じ `sns.*` 契約**を
/// 満たすことを、偽 Mastodon インスタンス相手に end-to-end で確かめる。
/// ここが通れば、ホスト側は SNS の違いを知らないまま動く。
/// サンプルプラグインが function.json で宣言する権限 (D-004)。ランタイムの
/// ゲートはこの宣言に載っている host-fn しか通さないので、テストでも実物と
/// 同じ宣言を通す。
const _samplePermissions = {RasqPermissions.network, RasqPermissions.storageSafe};

/// テストの偽サーバー。宣言に無いホストは E01 になる (schema v0.12)。
const _sampleHosts = {'mastodon.example', 'x.test', 'example.com'};

void main() {
  if (!wasmFile.existsSync()) {
    test('mastodon-wasm built', () {}, skip: 'build mastodon-wasm first (rust/README.md)');
    return;
  }
  final bytes = wasmFile.readAsBytesSync();
  const viewer = AccountId(kind: SnsKind.mastodon, instance: 'mastodon.example', handle: 'me');

  /// 典型的な Mastodon Status(本文は HTML、ブースト、CW、投票つき)。
  final cannedStatuses = jsonEncode([
    {
      'id': 's1',
      'content': '<p>打ち上げ成功！<br />次は <a href="https://mastodon.example/tags/rocket">#<span>rocket</span></a> です</p>',
      'spoiler_text': '',
      'sensitive': false,
      'created_at': '2026-09-01T12:00:00.000Z',
      'account': {'id': 'u1', 'acct': 'douglas', 'display_name': 'ダグラス', 'avatar': 'https://x.test/a.png'},
      'media_attachments': [
        {'id': 'm1', 'type': 'image', 'url': 'https://x.test/1.png', 'preview_url': 'https://x.test/1s.png', 'description': 'ロケット'},
      ],
      'replies_count': 2,
      'reblogs_count': 5,
      'favourites_count': 9,
      'favourited': true,
      'visibility': 'public',
      'url': 'https://mastodon.example/@douglas/s1',
    },
    {
      // ブースト: content が空で reblog に中身。展開されないと「内容のない投稿」。
      'id': 's2',
      'content': '',
      'created_at': '2026-09-01T11:00:00.000Z',
      'account': {'id': 'u2', 'acct': 'booster@other.example', 'display_name': 'ブースト元'},
      'media_attachments': [],
      'reblog': {
        'id': 'inner1',
        'content': '<p>中身の本文</p>',
        'created_at': '2026-09-01T10:00:00.000Z',
        'account': {'id': 'u3', 'acct': 'author', 'display_name': '書いた人'},
        'media_attachments': [],
        'favourites_count': 1,
      },
    },
  ]);

  /// エンドポイントごとに応答を返す偽 Mastodon。呼ばれたパスを記録する。
  ({WasmSnsSession session, List<String> paths, List<String> auth}) sessionWith(Map<String, Object?> routes) {
    final paths = <String>[];
    final auth = <String>[];
    final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
      paths.add(req.url.path);
      auth.add(req.headers['Authorization'] ?? '');
      final canned = routes[req.url.path];
      if (canned == null) return const SyncFetchResponse(status: 404, bodyText: '{"error":"Record not found"}');
      return SyncFetchResponse(status: 200, bodyText: canned is String ? canned : jsonEncode(canned));
    });
    final controller = WasmPluginController(wasmBytes: bytes, env: env);
    addTearDown(controller.dispose);
    controller.load();
    return (
      session: WasmSnsSession(
        account: viewer,
        pluginId: 'rasq.official.mastodon',
        extraArgs: const {'host': 'mastodon.example', 'token': 'tok-abc'},
        invoke: (fn, args) async => controller.invoke(fn, args),
      ),
      paths: paths,
      auth: auth,
    );
  }

  group('Mastodon プラグイン (D-135)', () {
    test('sns.timeline: HTML 本文が平文になり、ブーストは中身へ展開される', () async {
      final s = sessionWith({'/api/v1/timelines/home': cannedStatuses});
      final page = await s.session.timeline(TimelineKind.home, limit: 20);

      expect(page.items, hasLength(2));
      final post = page.items.first;
      expect(post.account, viewer, reason: 'キー付けはホスト側');
      expect(post.author.displayName, 'ダグラス');
      // HTML はプラグインが潰す — ホストはタグを見ない。
      expect(post.body, '打ち上げ成功！\n次は #rocket です');
      expect(post.bodyFormat, 'plain');
      expect(post.media.single.type, MediaType.image);
      expect(post.media.single.alt, 'ロケット');
      expect(post.counts['repost'], 5);
      // お気に入りをリアクション欄に写す(Mastodon にリアクションは無い)。
      expect(post.counts['reaction'], 9);

      final boost = page.items[1];
      expect(boost.id, 's2', reason: 'アクションは外側の id へ');
      expect(boost.body, '中身の本文', reason: '展開しないと本文の無い投稿になる');
      expect(boost.author.displayName, '書いた人');
      expect(boost.repostedBy?.displayName, 'ブースト元');
      // リモートユーザーは acct から instance を割り出す。
      expect(boost.repostedBy?.account.instance, 'other.example');

      expect(page.nextCursor, 's2', reason: 'max_id ページング');
      expect(s.auth.first, 'Bearer tok-abc');
    });

    test('sns.timelines / timeline(kind): Mastodon の TL 構成に合う', () async {
      final s = sessionWith({
        '/api/v1/timelines/home': cannedStatuses,
        '/api/v1/timelines/public': cannedStatuses,
        '/api/v1/trends/statuses': cannedStatuses,
      });
      await s.session.loadTimelines();
      expect(s.session.timelines.map((t) => t.id), ['home', 'local', 'global', 'featured']);

      // ローカルと連合はどちらも /timelines/public(local フラグ違い)。
      await s.session.timeline(TimelineKind.local);
      await s.session.timeline(TimelineKind.global);
      expect(s.paths.where((p) => p == '/api/v1/timelines/public'), hasLength(2));

      await s.session.timeline(const TimelineKind('featured', 'トレンド'));
      expect(s.paths, contains('/api/v1/trends/statuses'));
    });

    test('sns.inspectServer: サーバー情報の取り方はプラグインが知っている', () async {
      final plugin = WasmSnsPlugin(
        manifest: const PluginManifest(id: 'rasq.official.mastodon', name: 'Mastodon', version: '0.1.0', kind: PluginKind.sns, supportedSns: [SnsKind.mastodon]),
        kind: SnsKind.mastodon,
        loadBytes: () async => bytes,
        // ワーカーはネットワークを持たない → net.fetch が B01 で返り、
        // ホスト名だけの ServerInfo に縮退することを確かめる。
        nativeFetch: false,
      );
      addTearDown(plugin.dispose);
      final info = await plugin.inspectServer('https://Mastodon.Example/@someone');
      expect(info.host, 'mastodon.example', reason: 'normalizeHost (CONTRACT §2)');
      expect(info.name, 'mastodon.example', reason: '取れなければホスト名で縮退する');
    });

    test('sns.performAction: お気に入りはトグルで、件数が返る', () async {
      var favourited = false;
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        if (req.url.path == '/api/v1/statuses/s1') {
          return SyncFetchResponse(status: 200, bodyText: jsonEncode({'id': 's1', 'favourited': favourited, 'favourites_count': favourited ? 10 : 9}));
        }
        if (req.url.path == '/api/v1/statuses/s1/favourite') {
          favourited = true;
          return SyncFetchResponse(status: 200, bodyText: jsonEncode({'id': 's1', 'favourited': true, 'favourites_count': 10}));
        }
        if (req.url.path == '/api/v1/statuses/s1/unfavourite') {
          favourited = false;
          return SyncFetchResponse(status: 200, bodyText: jsonEncode({'id': 's1', 'favourited': false, 'favourites_count': 9}));
        }
        return const SyncFetchResponse(status: 404, bodyText: '{}');
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, extraArgs: const {'host': 'mastodon.example', 'token': 't'}, invoke: (fn, a) async => controller.invoke(fn, a));

      final on = await session.performAction('favourite', 's1');
      expect(on.done, isTrue);
      expect(on.count, 10);

      final off = await session.performAction('favourite', 's1');
      expect(off.done, isFalse, reason: '2 回目は解除');
      expect(off.count, 9);
    });

    test('sns.actions: お気に入りが Reaction ジャンルとして宣言される', () async {
      final s = sessionWith(const {});
      await s.session.loadActions();
      final ids = s.session.actions.map((a) => a.id).toList();
      expect(ids, containsAll(['reply', 'reblog', 'favourite', 'bookmark']));
      final fav = s.session.actions.firstWhere((a) => a.id == 'favourite');
      // 他 SNS のリアクションと同じスロットに並ぶ(同ジャンル = 同スロット)。
      expect(fav.genreTag, 'Reaction');
    });

    test('sns.notifications: お気に入り通知が ⭐ リアクションとして届く', () async {
      final s = sessionWith({
        '/api/v1/notifications': [
          {
            'id': 'n1',
            'type': 'favourite',
            'created_at': '2026-09-01T00:00:00.000Z',
            'account': {'id': 'u1', 'acct': 'fan', 'display_name': 'ファン'},
            'status': {'id': 's1', 'content': '<p>本文</p>', 'account': {'id': 'me', 'acct': 'me'}, 'media_attachments': []},
          },
          {
            'id': 'n2',
            'type': 'follow_request',
            'created_at': '2026-08-31T00:00:00.000Z',
            'account': {'id': 'u2', 'acct': 'asker'},
          },
        ],
      });
      final page = await s.session.notifications();
      expect(page.items.first.kind, NotificationKind.reaction);
      expect(page.items.first.reaction, '⭐');
      expect(page.items.first.reactionsByActor, {'u1': '⭐'});
      expect(page.items.first.post!.body, '本文');
      expect(page.items[1].kind, NotificationKind.followRequest);
    });

    test('sns.setRelation: 鍵アカウントは requested で返る', () async {
      final s = sessionWith({
        '/api/v1/accounts/u1/follow': {'id': 'u1', 'following': false, 'requested': true},
      });
      final state = await s.session.setFollowing('u1', true);
      expect(state.following, isFalse);
      expect(state.requested, isTrue);
    });

    test('sns.dmRooms: 会話 API がそのまま DM ルームになる (CONTRACT §7)', () async {
      final s = sessionWith({
        '/api/v1/conversations': [
          {
            'id': 'c1',
            'unread': true,
            'accounts': [
              {'id': 'u1', 'acct': 'peer', 'display_name': '相手'},
            ],
            'last_status': {
              'id': 'd1',
              'content': '<p>ないしょの話</p>',
              'visibility': 'direct',
              'created_at': '2026-09-01T00:00:00.000Z',
              'account': {'id': 'u1', 'acct': 'peer'},
              'media_attachments': [],
            },
          },
        ],
      });
      final rooms = await s.session.dmRooms();
      expect(rooms.single.kind, DmRoomKind.direct);
      expect(rooms.single.peer.displayName, '相手');
      expect(rooms.single.lastPost!.body, 'ないしょの話');
      expect(rooms.single.unreadCount, 1);
    });

    test('sns.sendDm: 本文に相手のメンションが前置される', () async {
      String? sentBody;
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        if (req.url.path == '/api/v1/accounts/u1') {
          return const SyncFetchResponse(status: 200, bodyText: '{"id":"u1","acct":"peer@remote.test"}');
        }
        sentBody = req.body;
        return const SyncFetchResponse(
          status: 200,
          bodyText: '{"id":"d1","content":"<p>@peer@remote.test やあ</p>","created_at":"2026-09-01T00:00:00.000Z","account":{"id":"me","acct":"me"},"media_attachments":[],"visibility":"direct"}',
        );
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, extraArgs: const {'host': 'mastodon.example', 'token': 't'}, invoke: (fn, a) async => controller.invoke(fn, a));

      const room = DmRoom(id: 'c1', peer: UserSummary(id: 'u1', account: viewer, displayName: '相手'));
      final sent = await session.sendDm(room, const NewPost(text: 'やあ'));
      expect(sent.body, '@peer@remote.test やあ');
      // direct 投稿はメンションが無いと誰にも届かない。
      expect(sentBody, contains('@peer@remote.test やあ'));
      expect(sentBody, contains('"visibility":"direct"'));
    });

    test('引用はネイティブに無いので C01 → ホストが欄を隠す', () async {
      final s = sessionWith(const {});
      await expectLater(
        s.session.quotes('s1'),
        throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'C01')),
      );
    });

    test('クリップ / Play は Mastodon に無いので C01 → ホストがタブを隠す', () async {
      final s = sessionWith(const {});
      await expectLater(s.session.clips(), throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'C01')));
      await expectLater(s.session.userPlays('u1'), throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'C01')));
    });

    test('sns.uploadMedia: multipart がバイナリのまま渡り、v2 の media を返す', () async {
      final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0xFF, 0xFE]);
      SyncFetchRequest? seen;
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        seen = req;
        return const SyncFetchResponse(
          status: 200,
          bodyText: '{"id":"m9","type":"image","url":"https://x.test/m9.jpg","preview_url":"https://x.test/m9s.jpg","description":"写真"}',
        );
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, extraArgs: const {'host': 'mastodon.example', 'token': 'tok'}, invoke: (fn, a) async => controller.invoke(fn, a));

      final media = await session.uploadMedia(jpeg, 'photo.jpg', mimeType: 'image/jpeg', alt: '写真');
      expect(media.id, 'm9');
      expect(media.type, MediaType.image);
      expect(media.alt, '写真');
      expect(seen!.url.path, '/api/v2/media');
      expect(seen!.bodyBytes, isNotNull);
      // Mastodon はトークンをヘッダーで渡す(Misskey はフィールド)。
      expect(seen!.headers['Authorization'], 'Bearer tok');
      final asText = latin1.decode(seen!.bodyBytes!);
      expect(asText, contains('name="file"; filename="photo.jpg"'));
      expect(asText, contains('name="description"'));
    });

    test('HTTP エラーはコード付きの SnsApiException になる', () async {
      final s = sessionWith(const {}); // 全部 404
      await expectLater(
        s.session.thread('missing'),
        throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', '404')),
      );
    });
  });
}
