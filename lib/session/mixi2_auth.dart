import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../backend/sns_oauth.dart';

/// mixi2 (D-206、サンプル): 公式 API は申請制で、認証は OAuth(RASQ サーバーのブローカー経由)。
/// どちらも揃うまでは **ダミーモード**(ホスト `dummy`)で流れを確かめる。プラグイン
/// (`rasq-sdk-sample/rust/mixi2-wasm`)がメモリ上の投稿でログイン → TL → アクション → 投稿 → 通知をこなす。
const mixi2PluginId = 'rasq.official.mixi2';
const mixi2DefaultHost = 'mixi.social';
const mixi2DummyHost = 'dummy';

/// ダミーのログイン: プラグインの `sns.login`(匿名ワーカー)。資格情報は要らない。
class Mixi2DummyFlow extends CredentialAuthFlow {
  const Mixi2DummyFlow({required this.plugin});
  final WasmSnsPlugin plugin;

  @override
  Future<AuthResult> login({required String identifier, required String secret}) async {
    final result = await plugin.callAnonymous('sns.login', {'host': mixi2DummyHost, 'identifier': identifier.trim().isEmpty ? 'me' : identifier.trim()});
    if (result['ok'] != true) {
      final error = (result['error'] as Map?)?.cast<String, Object?>() ?? const {};
      final message = '${error['message'] ?? 'ログインに失敗しました'}';
      throw SnsApiException(ErrorCode.tryParse('${error['code'] ?? ''}', message: message) ?? ErrorCode.internalServerError.copyWith(message: message));
    }
    final value = (result['value'] as Map? ?? const {}).cast<String, Object?>();
    final session = (value['session'] as Map? ?? const {}).cast<String, Object?>();
    final handle = '${session['handle'] ?? 'me'}';
    const kind = SnsKind.mixi2;
    final account = AccountId(kind: kind, instance: mixi2DummyHost, handle: handle);
    final meWire = (value['me'] as Map?)?.cast<String, Object?>();
    final me = meWire == null ? UserSummary(id: handle, account: account, displayName: handle) : SnsWire.userFrom({...meWire, 'kind': 'mixi2', 'instance': mixi2DummyHost, 'handle': meWire['handle'] ?? handle});
    return AuthResult(
      session: AccountSession(account: account, pluginId: plugin.manifest.id, token: '${session['token'] ?? 'dummy:$handle'}', createdAt: DateTime.now(), displayName: me.displayName, avatarUrl: me.avatarUrl),
      me: me,
    );
  }
}

/// ホスト `dummy` はダミー、それ以外はブローカー経由の OAuth(サーバー未設定なら理由を返す)。
Future<AuthFlow> Function(String host, {Uri? callback}) mixi2AuthFactory(Ref ref, WasmSnsPlugin Function() plugin) {
  final brokered = brokeredAuthFactory(ref, provider: 'mixi2', pluginId: mixi2PluginId, kind: SnsKind.mixi2);
  return (String host, {Uri? callback}) async {
    if (host == mixi2DummyHost) return Mixi2DummyFlow(plugin: plugin());
    return brokered(host, callback: callback);
  };
}

/// トークンがダミーか(セッション一覧の表示などで区別したいとき)。
bool isMixi2DummyToken(String token) => token.startsWith('dummy:');

/// ダミーのセッション(テスト / プレビュー用)。
AccountSession mixi2DummySession({String handle = 'me'}) => AccountSession(
      account: AccountId(kind: SnsKind.mixi2, instance: mixi2DummyHost, handle: handle),
      pluginId: mixi2PluginId,
      token: 'dummy:$handle',
      createdAt: DateTime(2026, 9, 13),
      displayName: 'わたし(ダミー)',
    );
