import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 本文なしの投稿 (D-494): コンポーザーはメディア / 投票 / 引用だけなら本文 `''` のまま `createPost` を呼ぶ。
/// 同梱の SNS プラグイン(assets/plugins の wasm を実物で)が、空の本文をそのまま API に載せないこと。
/// 偽サーバーは各 SNS と同じ検査をする(Misskey: `text` / `cw` は minLength 1・`fileIds` は minItems 1 → 400。
/// Mastodon: 本文も添付も無い、または投票に本文が無い → 422)。
void main() {
  const permissions = {RasqPermissions.network, RasqPermissions.storageSafe};

  ({WasmSnsSession session, List<Map<String, Object?>> sent}) sessionOf(String asset, String host, SyncFetchResponse Function(SyncFetchRequest req, Map<String, Object?> body) server) {
    final sent = <Map<String, Object?>>[];
    final env = RasqHostEnvironment(permissions: permissions, fetchHosts: {host}, fetch: (req) {
      final body = req.body == null || req.body!.isEmpty ? <String, Object?>{} : (jsonDecode(req.body!) as Map).cast<String, Object?>();
      if (req.method == 'POST') sent.add(body);
      return server(req, body);
    });
    final controller = WasmPluginController(wasmBytes: File('../../assets/plugins/$asset').readAsBytesSync(), env: env);
    addTearDown(controller.dispose);
    controller.load();
    final account = AccountId(kind: asset.startsWith('misskey') ? SnsKind.misskey : SnsKind.mastodon, instance: host, handle: 'me');
    return (
      session: WasmSnsSession(account: account, pluginId: 'p', extraArgs: {'host': host, 'token': 'tok'}, invoke: (fn, args) async => controller.invoke(fn, args)),
      sent: sent,
    );
  }

  group('Misskey (misskey_wasm_sample)', () {
    SyncFetchResponse misskey(SyncFetchRequest req, Map<String, Object?> b) {
      final invalid = b['text'] == '' || b['cw'] == '' || (b['fileIds'] is List && (b['fileIds'] as List).isEmpty);
      final content = b['text'] is String || b['fileIds'] is List || b['poll'] != null || b['renoteId'] != null;
      if (invalid || !content) return SyncFetchResponse(status: 400, bodyText: jsonEncode({'error': {'code': 'INVALID_PARAM'}}));
      final note = {'id': 'n1', 'createdAt': '2026-10-20T00:00:00Z', 'text': b['text'], 'user': {'id': 'me', 'username': 'me'}};
      return SyncFetchResponse(status: 200, bodyText: jsonEncode({'createdNote': note}));
    }

    test('メディアだけ / 引用 + メディアだけ / 投票だけ: text を送らない', () async {
      final s = sessionOf('misskey_wasm_sample.wasm', 'misskey.example', misskey);
      await s.session.createPost(const NewPost(text: '', mediaIds: ['f1']));
      expect(s.sent.last.containsKey('text'), isFalse);
      expect(s.sent.last['fileIds'], ['f1']);
      await s.session.createPost(const NewPost(text: '', quoteOfId: 'q1', mediaIds: ['f1']));
      expect(s.sent.last['renoteId'], 'q1');
      expect(s.sent.last.containsKey('text'), isFalse);
      await s.session.createPost(const NewPost(text: '', poll: NewPoll(choices: ['a', 'b'])));
      expect(s.sent.last.containsKey('text'), isFalse);
    });
  });

  group('Mastodon (mastodon_wasm)', () {
    SyncFetchResponse mastodon(SyncFetchRequest req, Map<String, Object?> b) {
      final blank = (b['status'] as String? ?? '').trim().isEmpty;
      final media = b['media_ids'] is List && (b['media_ids'] as List).isNotEmpty;
      if ((blank && !media) || (blank && b['poll'] != null)) return SyncFetchResponse(status: 422, bodyText: jsonEncode({'error': "Validation failed: Text can't be blank"}));
      return SyncFetchResponse(status: 200, bodyText: jsonEncode({'id': 's1', 'created_at': '2026-10-20T00:00:00Z', 'content': '', 'account': {'id': 'me', 'acct': 'me', 'username': 'me'}, 'media_attachments': []}));
    }

    test('メディアだけ: status を省いて media_ids だけ。投票だけは送る前に理由の文で断る', () async {
      final s = sessionOf('mastodon_wasm.wasm', 'mastodon.example', mastodon);
      await s.session.createPost(const NewPost(text: '', mediaIds: ['m1']));
      expect(s.sent.single.containsKey('status'), isFalse);
      expect(s.sent.single['media_ids'], ['m1']);
      await expectLater(
        s.session.createPost(const NewPost(text: '', poll: NewPoll(choices: ['a', 'b']))),
        throwsA(isA<SnsApiException>().having((e) => '${e.code.message} $e', 'message', contains('Mastodon の投票には本文が要ります'))),
      );
      expect(s.sent, hasLength(1));
    });
  });
}
