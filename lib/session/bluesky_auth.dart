import 'dart:convert';

import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// Bluesky (AT Protocol) のログイン (D-175): ハンドル(またはメール)+ **アプリパスワード**で
/// PDS の `com.atproto.server.createSession` を叩く。実処理は wasm プラグイン側の `sns.login`
/// (匿名ワーカー)で、ホストは入力フォームと結果の保存だけを持つ。
///
/// トークンは `{did, handle, accessJwt, refreshJwt}` の JSON 文字列を [AccountSession.token] に
/// 入れる(プラグインは期限切れ時に refreshSession して `storage.safe` に新しい組を残す)。
const blueskyPluginId = 'rasq.official.bluesky';
const blueskyDefaultHost = 'bsky.social';

class BlueskyCredentialFlow extends CredentialAuthFlow {
  const BlueskyCredentialFlow({required this.plugin, required this.host});
  final WasmSnsPlugin plugin;
  final String host;

  @override
  Future<AuthResult> login({required String identifier, required String secret}) async {
    final result = await plugin.callAnonymous('sns.login', {'host': host, 'identifier': identifier.trim(), 'password': secret});
    if (result['ok'] != true) {
      final error = (result['error'] as Map?)?.cast<String, Object?>() ?? const {};
      final message = '${error['message'] ?? 'ログインに失敗しました'}';
      throw SnsApiException(ErrorCode.tryParse('${error['code'] ?? ''}', message: message) ?? ErrorCode.internalServerError.copyWith(message: message));
    }
    final value = (result['value'] as Map? ?? const {}).cast<String, Object?>();
    final session = (value['session'] as Map? ?? const {}).cast<String, Object?>();
    final handle = '${session['handle'] ?? identifier}';
    final account = AccountId(kind: SnsKind.bluesky, instance: host, handle: handle);
    final meWire = (value['me'] as Map?)?.cast<String, Object?>();
    final me = meWire == null
        ? UserSummary(id: '${session['did'] ?? handle}', account: account, displayName: handle)
        : SnsWire.userFrom({...meWire, 'kind': 'bluesky', 'instance': host, 'handle': meWire['handle'] ?? handle});
    return AuthResult(
      session: AccountSession(
        account: account,
        pluginId: plugin.manifest.id,
        token: jsonEncode({'did': session['did'], 'handle': handle, 'accessJwt': session['accessJwt'], 'refreshJwt': session['refreshJwt']}),
        createdAt: DateTime.now(),
        displayName: me.displayName,
        avatarUrl: me.avatarUrl,
      ),
      me: me,
    );
  }
}

/// Bluesky のセッションの DID (D-423)。トークン([AccountSession.token] の `{did, handle, …}` の JSON)から読む。Bluesky でない / 読めなければ null。
String? blueskyDidOf(AccountSession s) {
  if (s.account.kind != SnsKind.bluesky) return null;
  try {
    final j = jsonDecode(s.token);
    final did = j is Map ? j['did'] : null;
    return did is String && did.startsWith('did:') ? did : null;
  } catch (_) {
    return null;
  }
}
