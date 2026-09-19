import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'orgate_client.dart';
import 'rasq_account.dart';

/// メール認証とアカウントの強化 (S-019) の口。メールで届くのはどれも 6 桁コード(15 分、5 回まで)。
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
  emailRemove('email.remove');

  const ConfirmAction(this.id);
  final String id;
}

class AccountSecurityApi {
  AccountSecurityApi(this._client);
  final OrgateClient _client;

  /// メールを登録(または変更)して、確認のコードを送る。
  Future<void> setEmail(String email) => _client.putJson('/me/email', {'email': email});
  Future<void> verifyEmail(String code) => _client.postJson('/me/email/verify', {'code': code});
  Future<void> removeEmail({String? code}) => _client.delete('/me/email', {'code': ?code});

  /// 確認コードを、確認済みのメールへ送る。戻り = 送り先の目安(`t***@example.com`)。
  Future<String> requestConfirmation(ConfirmAction action) async => (await _client.postJson('/me/confirm', {'action': action.id}))['email'] as String? ?? '';

  /// パスワードを付ける / 変える。変えるときは [currentPassword] か [code] が要る。
  Future<void> setPassword(String password, {String? currentPassword, String? code}) =>
      _client.postJson('/auth/password', {'password': password, 'currentPassword': ?currentPassword, 'code': ?code});

  Future<void> requestPasswordReset(String email) => _client.postJson('/auth/password/reset/request', {'email': email});
  Future<void> confirmPasswordReset({required String email, required String code, required String password}) =>
      _client.postJson('/auth/password/reset/confirm', {'email': email, 'code': code, 'password': password});

  /// ハンドル(かメール)+ パスワード。戻りは [OrgateAccountNotifier.adoptLogin] へ。
  Future<Map<String, Object?>> login({required String identifier, required String password, required String deviceId, String? label}) =>
      _client.postJson('/auth/login', {'handle': identifier, 'password': password, 'deviceId': deviceId, 'label': ?label});

  Future<void> requestLoginCode(String email) => _client.postJson('/auth/login/email/request', {'email': email});
  Future<Map<String, Object?>> loginWithCode({required String email, required String code, required String deviceId, String? label}) =>
      _client.postJson('/auth/login/email/confirm', {'email': email, 'code': code, 'deviceId': deviceId, 'label': ?label});

  Future<List<RasqLoginSession>> sessions() async => [for (final s in await _client.getList('/me/sessions')) RasqLoginSession.fromJson((s as Map).cast<String, Object?>())];
  Future<void> revokeSession(String sessionId) => _client.delete('/me/sessions/$sessionId');
  Future<int> revokeOtherSessions() async => ((await _client.postJson('/me/sessions/revoke-others', const {}))['revoked'] as num?)?.toInt() ?? 0;
}

final accountSecurityApiProvider = Provider<AccountSecurityApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  return client == null ? null : AccountSecurityApi(client);
});

/// サーバーのエラーを、画面に出す 1 行へ。
String accountSecurityMessage(OrgateException e) => switch (e.code.code) {
      '429' => '試行が多すぎます。しばらく待ってから、やり直してください',
      '501' => 'このサーバーは、メールを送れる設定になっていません',
      '409' when e.message.contains('already used') => 'このメールアドレスは、ほかのアカウントで使われています',
      '401' => 'ハンドル(メール)かパスワードが違います',
      '400' when e.message.contains('code') => 'コードが違うか、期限が切れています',
      '400' when e.message.contains('too weak') => 'このパスワードは弱すぎます(よく使われるもの / 同じ字の繰り返し / ハンドルやメールと同じもの は使えません)',
      '400' when e.message.contains('8-256') => 'パスワードは 8 文字以上にしてください',
      '400' when e.message.contains('email') => 'メールアドレスの形が正しくありません',
      '403' when e.message.contains('current password') => 'いまのパスワードが違います',
      _ => e.message,
    };
