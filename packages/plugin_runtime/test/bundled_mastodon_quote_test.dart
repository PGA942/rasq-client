import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// Mastodon の引用 (D-495): 同梱の mastodon_wasm(assets/plugins の wasm を実物で)が、
/// 引用を `quoted_status_id` で送り(4.5+)、持たないサーバーでは引用元の URL を本文に足し、
/// 読むときは承認済みの `quote` を [Post.quote] に写す(タイルの引用表示は SNS を問わない)。
void main() {
  const host = 'mastodon.example';
  const quotedUrl = 'https://remote.example/@author/1';
  final author = {'id': 'u1', 'acct': 'author@remote.example', 'username': 'author', 'display_name': '書いた人'};
  final quoted = {'id': 'q1', 'url': quotedUrl, 'created_at': '2026-10-19T00:00:00Z', 'content': '<p>元の投稿</p>', 'account': author, 'media_attachments': []};

  ({WasmSnsSession session, List<Map<String, Object?>> sent}) sessionOf({required int? apiVersion}) {
    final sent = <Map<String, Object?>>[];
    SyncFetchResponse ok(Object body) => SyncFetchResponse(status: 200, bodyText: jsonEncode(body));
    final env = RasqHostEnvironment(permissions: const {RasqPermissions.network, RasqPermissions.storageSafe}, fetchHosts: {host}, fetch: (req) {
      final path = req.url.path;
      if (req.method == 'GET') {
        if (path == '/api/v2/instance') {
          return ok({'domain': host, 'version': apiVersion == null ? '4.4.3' : '4.5.0', 'api_versions': ?(apiVersion == null ? null : {'mastodon': apiVersion})});
        }
        if (path == '/api/v1/statuses/q1') return ok(quoted);
        if (path == '/api/v1/timelines/home') {
          return ok([
            {
              'id': 's9', 'created_at': '2026-10-20T00:00:00Z', 'account': {'id': 'u2', 'acct': 'friend', 'username': 'friend'}, 'media_attachments': [],
              'content': '<p class="quote-inline">RE: <a href="$quotedUrl">remote.example/@author/1</a></p><p>これ見て</p>',
              'quote': {'state': 'accepted', 'quoted_status': quoted},
            },
          ]);
        }
        return SyncFetchResponse(status: 404, bodyText: '{"error":"Record not found"}');
      }
      final b = (jsonDecode(req.body!) as Map).cast<String, Object?>();
      sent.add(b);
      return ok({
        'id': 's1', 'created_at': '2026-10-20T00:00:00Z', 'content': '<p>${b['status'] ?? ''}</p>', 'account': {'id': 'me', 'acct': 'me', 'username': 'me'}, 'media_attachments': [],
        if (b['quoted_status_id'] != null) 'quote': {'state': 'accepted', 'quoted_status': quoted},
      });
    });
    final controller = WasmPluginController(wasmBytes: File('../../assets/plugins/mastodon_wasm.wasm').readAsBytesSync(), env: env);
    addTearDown(controller.dispose);
    controller.load();
    return (
      session: WasmSnsSession(account: const AccountId(kind: SnsKind.mastodon, instance: host, handle: 'me'), pluginId: 'p', extraArgs: {'host': host, 'token': 'tok'}, invoke: (fn, args) async => controller.invoke(fn, args)),
      sent: sent,
    );
  }

  test('4.5+: quoted_status_id で引用し、戻りの投稿も引用を持つ', () async {
    final s = sessionOf(apiVersion: 7);
    final post = await s.session.createPost(const NewPost(text: 'これ見て', quoteOfId: 'q1'));
    expect(s.sent.single['quoted_status_id'], 'q1');
    expect(s.sent.single['status'], 'これ見て');
    expect(post.quote?.id, 'q1');
    // 引用できたときは知らせ無し(契約 v0.25 の notice、D-500)。
    expect((await s.session.createPostWithNotice(const NewPost(text: 'もう一回', quoteOfId: 'q1'))).notice, isNull);
  });

  test('引用を持たないサーバー: 引用元の URL を本文の末尾の行に足す', () async {
    final s = sessionOf(apiVersion: null);
    final sent = await s.session.createPostWithNotice(const NewPost(text: 'これ見て', quoteOfId: 'q1'));
    expect(s.sent.single.containsKey('quoted_status_id'), isFalse);
    expect(s.sent.single['status'], 'これ見て\n$quotedUrl');
    // URL で送ったことを、答えの notice で知らせる(契約 v0.25、D-500)。コンポーザーがスナックバーで出す。
    expect(sent.post.id, 's1');
    expect(sent.notice?.code, 'quote.fallbackUrl');
    expect(sent.notice?.message, '引用に対応していないサーバーなので、引用元の URL を付けて投稿しました');
  });

  test('タイムラインの引用は Post.quote に入り、本文の RE: は外れる', () async {
    final s = sessionOf(apiVersion: 7);
    final page = await s.session.timeline(TimelineKind.home);
    final p = page.items.single;
    expect(p.body, 'これ見て');
    expect(p.quote?.id, 'q1');
    expect(p.quote?.body, '元の投稿');
    expect(p.quote?.author.displayName, '書いた人');
  });
}
