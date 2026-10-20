import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'orgate_client.dart';
import 'rasq_account.dart';
import '../l10n/l10n.dart';

/// メール認証とアカウントの強化 (S-019) の口。メールで届くのはどれも確認コード(Base58 で 10 文字)(1 回きり、5 回まで。
/// 15 分、ログインの 2 段階目とパスワードの再設定は 10 分)。
///
/// D-419 / ORGATE O-010: ほかの端末からのログインは**パスワード必須**。確認済みのメールがあるアカウントは、パスワードのあとに
/// メールのコード(2 段階目、既定 ON)。メールのコードだけのログインは廃止(サーバーは `410 passwordless_login_removed`)。
@immutable
class RasqLoginSession {
  const RasqLoginSession({required this.sessionId, this.deviceId, this.label, this.createdAt, this.lastUsedAt, this.expiresAt, this.lastIp, this.userAgent, this.current = false});
  final String sessionId;
  final String? deviceId;
  final String? label;
  final DateTime? createdAt;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;
  final String? lastIp;
  final String? userAgent;

  /// いま使っている端末。
  final bool current;

  factory RasqLoginSession.fromJson(Map<String, Object?> j) => RasqLoginSession(
        sessionId: j['sessionId'] as String? ?? '',
        deviceId: j['deviceId'] as String?,
        label: j['label'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        lastUsedAt: DateTime.tryParse(j['lastUsedAt'] as String? ?? ''),
        expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''),
        lastIp: j['lastIp'] as String?,
        userAgent: j['userAgent'] as String?,
        current: j['current'] == true,
      );
}

/// 重要な操作(コードで確認する)。
enum ConfirmAction {
  accountDelete('account.delete'),
  passwordChange('password.change'),
  emailRemove('email.remove'),

  /// 確認済みのメールを別のアドレスへ付け替える (ORGATE O-008、D-407): いまのメールへコードを送る。
  emailChange('email.change'),

  /// ログインの 2 段階目を切る (ORGATE O-010、D-419)。
  secondFactorDisable('second_factor.disable');

  const ConfirmAction(this.id);
  final String id;
}

/// パスワードは合っていて、2 段階目のコードを待っている (`401 second_factor_required`、ORGATE O-010)。
@immutable
class RasqLoginChallenge {
  const RasqLoginChallenge({required this.challengeId, this.email = '', this.expiresInSeconds = 600});
  final String challengeId;

  /// 送り先の目安(`t***@example.com`)。
  final String email;
  final int expiresInSeconds;

  /// ログインの失敗がこれなら、その中身。ほかの失敗は null。
  static RasqLoginChallenge? of(OrgateException e) {
    if (e.serverCode != 'second_factor_required') return null;
    final id = e.details['challengeId'];
    if (id is! String || id.isEmpty) return null;
    return RasqLoginChallenge(
      challengeId: id,
      email: e.details['email'] as String? ?? '',
      expiresInSeconds: (e.details['expiresInSeconds'] as num?)?.toInt() ?? 600,
    );
  }
}

/// パスワードの再設定の結果 (ORGATE O-010)。
@immutable
class RasqResetResult {
  const RasqResetResult({this.accountId, this.revokedSessions = 0, this.keptSession = false, this.restoreSecret});
  final String? accountId;
  final int revokedSessions;
  final bool keptSession;

  /// 残したこの端末のセッションの、回った復帰の秘密。
  final String? restoreSecret;

  factory RasqResetResult.fromJson(Map<String, Object?> j) => RasqResetResult(
        accountId: j['accountId'] as String?,
        revokedSessions: (j['revokedSessions'] as num?)?.toInt() ?? 0,
        keptSession: j['keptSession'] == true,
        restoreSecret: j['restoreSecret'] as String?,
      );
}

class AccountSecurityApi {
  AccountSecurityApi(this._client);
  final OrgateClient _client;

  /// メールを登録(または変更)して、確認のコードを送る。**確認済みのメールを付け替える**ときは、いまのパスワード
  /// [currentPassword] か、いまのメールに届いた `email.change` の確認コード [code] が要る(無いと 403、ORGATE O-008)。
  /// 初めて付けるときは、パスワードを設定したアカウントだけ [currentPassword] が要る(ORGATE O-009。無いアカウントは要らない)。
  Future<void> setEmail(String email, {String? currentPassword, String? code}) =>
      _client.putJson('/me/email', {'email': email, 'currentPassword': ?currentPassword, 'code': ?code});
  Future<void> verifyEmail(String code) => _client.postJson('/me/email/verify', {'code': code});
  Future<void> removeEmail({String? code}) => _client.delete('/me/email', {'code': ?code});

  /// 確認コードを、確認済みのメールへ送る。戻り = 送り先の目安(`t***@example.com`)。
  Future<String> requestConfirmation(ConfirmAction action) async => (await _client.postJson('/me/confirm', {'action': action.id}))['email'] as String? ?? '';

  /// パスワードを付ける / 変える。変えるときは [currentPassword] か [code] が要る。
  Future<void> setPassword(String password, {String? currentPassword, String? code}) =>
      _client.postJson('/auth/password', {'password': password, 'currentPassword': ?currentPassword, 'code': ?code});

  /// パスワードの再設定のコードを送る(10 分)。アカウントがあっても無くても同じ応答(サーバーは常に 204)。
  Future<void> requestPasswordReset(String email) => _anonymous.postJson('/auth/password/reset/request', {'email': email});

  /// コード + 新しいパスワード。ほかのセッションはすべてログアウト。[keepCurrentSession] = この端末のログインは残す
  /// (いまの RASQ アカウントのトークンを添える。同じアカウントのときだけサーバーが残し、復帰の秘密を回して返す)。
  Future<RasqResetResult> confirmPasswordReset({required String email, required String code, required String password, bool keepCurrentSession = false}) async =>
      RasqResetResult.fromJson(await (keepCurrentSession ? _client : _anonymous)
          .postJson('/auth/password/reset/confirm', {'email': email, 'code': code, 'password': password, if (keepCurrentSession) 'keepCurrentSession': true}));

  /// ハンドル(かメール)+ パスワード。戻りは [OrgateAccountNotifier.adoptLogin] へ。2 段階目が効いているアカウントは
  /// [OrgateException](`401 second_factor_required`)→ [RasqLoginChallenge.of] → [confirmLogin]。
  /// トークンは添えない(添えると、401 でトークンの取り直しと送り直しが起き、コードが 2 通届く)。
  Future<Map<String, Object?>> login({required String identifier, required String password, required String deviceId, String? label}) =>
      _anonymous.postJson('/auth/login', {'handle': identifier, 'password': password, 'deviceId': deviceId, 'label': ?label});

  /// 2 段階目: メールに届いたコード(短いコードでも、リンクの長いトークンでも)。戻りはログインの応答。
  Future<Map<String, Object?>> confirmLogin({required String challengeId, required String code}) =>
      _anonymous.postJson('/auth/login/confirm', {'challengeId': challengeId, 'code': code});

  /// ログインの 2 段階目を入れる / 切る。切るときは [currentPassword] か `second_factor.disable` の [code] が要る。
  Future<({bool enabled, bool active})> setSecondFactor({required bool enabled, String? currentPassword, String? code}) async {
    final r = await _client.putJson('/me/second-factor', {'enabled': enabled, 'currentPassword': ?currentPassword, 'code': ?code});
    return (enabled: r['enabled'] != false, active: r['active'] == true);
  }

  OrgateClient get _anonymous => _client.withToken(() => null);

  Future<List<RasqLoginSession>> sessions() async => [for (final s in await _client.getList('/me/sessions')) RasqLoginSession.fromJson((s as Map).cast<String, Object?>())];
  Future<void> revokeSession(String sessionId) => _client.delete('/me/sessions/$sessionId');
  Future<int> revokeOtherSessions() async => ((await _client.postJson('/me/sessions/revoke-others', const {}))['revoked'] as num?)?.toInt() ?? 0;
}

/// ログイン / パスワード / メール / セッションは ORGATE-Server (D-398)。
final accountSecurityApiProvider = Provider<AccountSecurityApi?>((ref) {
  final client = ref.watch(orgateClientProvider);
  return client == null ? null : AccountSecurityApi(client);
});

/// サーバーのエラーを、画面に出す 1 行へ。
String accountSecurityMessage(OrgateException e) {
  final l = appL10n;
  return switch (e.code.code) {
    _ when e.serverCode == 'passwordless_login_removed' => l.backendSecurityPasswordlessRemoved,
    _ when e.serverCode == 'second_factor_required' => l.backendSecuritySecondFactor,
    '429' => l.backendSecurityTooMany,
    '501' => l.backendSecurityNoMail,
    '409' when e.message.contains('already used') => l.backendSecurityEmailUsed,
    '401' => l.backendSecurityBadCredentials,
    '400' when e.message.contains('code') => l.backendSecurityBadCode,
    '400' when e.message.contains('too weak') => l.backendSecurityWeakPassword,
    '400' when e.message.contains('8-256') => l.backendSecurityShortPassword,
    '400' when e.message.contains('email') => l.backendSecurityBadEmail,
    '403' when e.message.contains('current password') => l.backendSecurityWrongPassword,
    // ORGATE O-009 から 403 の文面は日本語(そのまま出す)。上は前の版の英語の文面。
    '403' when e.message.contains('has no password') => l.backendSecurityNoPassword,
    '403' when e.message.contains('confirmation required') => l.backendSecurityConfirmRequired,
    _ => e.message,
  };
}
