import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'mappers.dart';
import 'misskey_api.dart';

/// MiAuth flow: open `https://{host}/miauth/{session}?…` in a browser, then
/// `POST /api/miauth/{session}/check` to exchange for a token.
class MiAuthFlow extends BrowserAuthFlow {
  MiAuthFlow({
    required this.host,
    required this.pluginId,
    required this.permissions,
    this.appName = 'RASQ',
    this.iconUrl,
    this.callback,
    String? sessionId,
    this.client,
  }) : sessionId = sessionId ?? _uuidV4();

  final String host;
  final String pluginId;
  final List<String> permissions;
  final String appName;
  final Uri? iconUrl;
  final Uri? callback;
  final String sessionId;
  final http.Client? client;

  /// Misskey permission scopes requested for phase 1.
  ///
  /// 注意: スコープを増やすと**既存トークンには反映されない**(再ログインが
  /// 必要)。後から足すと全ユーザーに再ログインを強いるので、使う見込みの
  /// あるものは最初から並べておく (D-045)。
  static const defaultPermissions = [
    'read:account',
    // i/update(アカウント設定 D-044: Bot/Cat/承認制…)、クリップ・リストの
    // 作成/削除など「アカウント」括りの書き込み系はこれが無いと 403 になる。
    'write:account',
    'write:notes',
    // 投票 (RasqPollWidget) 用。
    'write:votes',
    'read:notifications',
    'write:notifications',
    'read:reactions',
    'write:reactions',
    'read:following',
    'write:following',
    'read:blocks',
    'write:blocks',
    'read:mutes',
    'write:mutes',
    'read:favorites',
    'write:favorites',
    'read:drive',
    'write:drive',
    'read:messaging',
    'write:messaging',
    'read:chat',
    'write:chat',
  ];

  @override
  Uri get url => snsUri(host, '/miauth/$sessionId', {
        'name': appName,
        if (iconUrl != null) 'icon': iconUrl.toString(),
        if (callback != null) 'callback': callback.toString(),
        'permission': permissions.join(','),
      });

  @override
  String get hint => 'ブラウザで「許可する」を押したら、このアプリに戻って「認証を確認」を押してください。';

  @override
  Future<AuthResult> complete() async {
    final api = MisskeyApi(host, client: client);
    final res = await api.callMap('miauth/$sessionId/check');
    if (res['ok'] != true || res['token'] == null) {
      throw SnsApiException(ErrorCode.unauthorized.copyWith(message: 'まだ許可されていません。ブラウザで許可してから再度お試しください。'));
    }
    final token = res['token'] as String;
    final user = (res['user'] as Map).cast<String, Object?>();
    final account = AccountId(kind: SnsKind.misskey, instance: host, handle: user['username'] as String);
    final me = MisskeyMappers.user(user, account: account, host: host);
    final session = AccountSession(
      account: account,
      pluginId: pluginId,
      token: token,
      createdAt: DateTime.now(),
      displayName: me.displayName,
      avatarUrl: me.avatarUrl,
    );
    return AuthResult(session: session, me: me);
  }

  static String _uuidV4([Random? rng]) {
    final r = rng ?? Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }
}
