import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';

/// 本物の Bluesky wasm (D-175) を同期コントローラ + net.fetch のモックで通す:
/// sns.login(createSession + getProfile)→ トークン JSON、sns.timeline(getTimeline)→ Post ワイヤ、期限切れ → refreshSession。
/// サンプルプラグインが function.json で宣言する権限 (D-004)。
const _samplePermissions = {'network', 'storage.safe'};

void main() {
  final f = File('assets/plugins/bluesky_wasm.wasm');
  if (!f.existsSync() || f.lengthSync() == 0) {
    test('bluesky wasm needs to be built', () {}, skip: 'assets/plugins/bluesky_wasm.wasm が無い');
    return;
  }
  final requests = <SyncFetchRequest>[];
  SyncFetchResponse json(Object body, {int status = 200}) => SyncFetchResponse(status: status, headers: const {'content-type': 'application/json'}, bodyText: jsonEncode(body));
  const post = {
    'uri': 'at://did:plc:alice/app.bsky.feed.post/3k2a', 'cid': 'bafy1',
    'author': {'did': 'did:plc:alice', 'handle': 'alice.bsky.social', 'displayName': 'Alice', 'avatar': 'https://cdn/a.jpg'},
    'record': {r'$type': 'app.bsky.feed.post', 'text': 'こんにちは #rasq', 'createdAt': '2026-09-11T00:00:00.000Z'},
    'replyCount': 1, 'repostCount': 2, 'likeCount': 3, 'quoteCount': 0, 'indexedAt': '2026-09-11T00:00:00.000Z',
    'viewer': {'like': 'at://did:plc:me/app.bsky.feed.like/xyz'},
  };
  var expired = false;
  SyncFetchResponse handler(SyncFetchRequest r) {
    requests.add(r);
    final p = r.url.path;
    if (p.endsWith('com.atproto.server.createSession')) {
      final body = jsonDecode(r.body!) as Map;
      if (body['password'] != 'app-pass') return json({'error': 'AuthenticationRequired', 'message': 'Invalid identifier or password'}, status: 401);
      return json({'did': 'did:plc:me', 'handle': 'me.bsky.social', 'accessJwt': 'access-1', 'refreshJwt': 'refresh-1'});
    }
    if (p.endsWith('app.bsky.actor.getProfile')) return json({'did': 'did:plc:me', 'handle': 'me.bsky.social', 'displayName': 'わたし', 'avatar': 'https://cdn/me.jpg'});
    if (p.endsWith('com.atproto.server.refreshSession')) return json({'did': 'did:plc:me', 'handle': 'me.bsky.social', 'accessJwt': 'access-2', 'refreshJwt': 'refresh-2'});
    if (p.endsWith('app.bsky.feed.getTimeline')) {
      if (expired && r.headers['Authorization'] == 'Bearer access-1') return json({'error': 'ExpiredToken', 'message': 'Token has expired'}, status: 400);
      return json({'feed': [{'post': post}, {'post': post, 'reason': {r'$type': 'app.bsky.feed.defs#reasonRepost', 'by': {'did': 'did:plc:bob', 'handle': 'bob.bsky.social', 'displayName': 'Bob'}, 'indexedAt': '2026-09-11T01:00:00.000Z'}}], 'cursor': 'next'});
    }
    return json({'error': 'NotFound', 'message': p}, status: 404);
  }

  Map<String, dynamic> value(Map<String, dynamic> r) {
    expect(r['ok'], isTrue, reason: '$r');
    return (r['value'] as Map).cast<String, dynamic>();
  }

  test('sns.login → session/me、sns.timeline → Post ワイヤ(リポスト展開、⭐、url)、ExpiredToken → refreshSession + storage.set', () {
    final storage = <String, Object?>{};
    final env = RasqHostEnvironment(
      permissions: _samplePermissions,
      fetch: handler,
      storage: storage,
    );
    final c = WasmPluginController(wasmBytes: f.readAsBytesSync(), env: env)..load();
    // ログイン失敗 → 401。
    expect(c.invoke('sns.login', {'host': 'bsky.social', 'identifier': 'me.bsky.social', 'password': 'wrong'})['ok'], isFalse);
    final login = value(c.invoke('sns.login', {'host': 'bsky.social', 'identifier': 'me.bsky.social', 'password': 'app-pass'}));
    expect((login['session'] as Map)['did'], 'did:plc:me');
    expect((login['session'] as Map)['accessJwt'], 'access-1');
    expect((login['me'] as Map)['displayName'], 'わたし');
    expect(requests.last.url.toString(), startsWith('https://bsky.social/xrpc/'));
    final token = jsonEncode({'did': 'did:plc:me', 'handle': 'me.bsky.social', 'accessJwt': 'access-1', 'refreshJwt': 'refresh-1'});
    // タイムライン。
    final tl = value(c.invoke('sns.timeline', {'host': 'bsky.social', 'token': token, 'kind': 'home', 'limit': 20, 'now': '2026-09-11T02:00:00.000Z'}));
    final items = ((tl['page'] as Map)['items'] as List).cast<Map>();
    expect(items.length, 2);
    expect(items[0]['id'], 'at://did:plc:alice/app.bsky.feed.post/3k2a');
    expect(items[0]['url'], 'https://bsky.app/profile/alice.bsky.social/post/3k2a');
    expect((items[0]['author'] as Map)['kind'], 'bluesky');
    expect(items[0]['myReaction'], '⭐');
    expect((items[1]['repostedBy'] as Map)['handle'], 'bob.bsky.social');
    expect(items[1]['repostTargetId'], 'at://did:plc:alice/app.bsky.feed.post/3k2a');
    expect((tl['page'] as Map)['nextCursor'], 'next');
    // 期限切れ → refreshSession → 再試行 → storage.safe に新しい組。
    expired = true;
    value(c.invoke('sns.timeline', {'host': 'bsky.social', 'token': token, 'kind': 'home', 'limit': 20}));
    expect(requests.any((r) => r.url.path.endsWith('com.atproto.server.refreshSession')), isTrue);
    expect(requests.last.headers['Authorization'], 'Bearer access-2');
    expect(storage.values.any((v) => '$v'.contains('access-2')), isTrue, reason: '$storage');
    c.dispose();
  });
}
