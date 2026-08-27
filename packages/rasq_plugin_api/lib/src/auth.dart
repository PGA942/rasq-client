import 'package:meta/meta.dart';
import 'package:rasq_models/rasq_models.dart';

/// A persisted login. Tokens are stored by the host in secure storage;
/// plugins receive them only through [SnsPlugin.open].
@immutable
class AccountSession {
  const AccountSession({required this.account, required this.pluginId, required this.token, required this.createdAt, this.displayName, this.avatarUrl});

  final AccountId account;
  final String pluginId;
  final String token;
  final DateTime createdAt;

  /// Cached profile bits so the UI can render before the first `me()` call.
  final String? displayName;
  final Uri? avatarUrl;

  Map<String, Object?> toJson() => {
        'kind': account.kind.name,
        'instance': account.instance,
        'handle': account.handle,
        'pluginId': pluginId,
        'token': token,
        'createdAt': createdAt.toIso8601String(),
        if (displayName != null) 'displayName': displayName,
        if (avatarUrl != null) 'avatarUrl': avatarUrl.toString(),
      };

  factory AccountSession.fromJson(Map<String, Object?> j) => AccountSession(
        account: AccountId(kind: SnsKind.values.byName(j['kind'] as String), instance: j['instance'] as String, handle: j['handle'] as String),
        pluginId: j['pluginId'] as String,
        token: j['token'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        displayName: j['displayName'] as String?,
        avatarUrl: j['avatarUrl'] == null ? null : Uri.tryParse(j['avatarUrl'] as String),
      );

  AccountSession copyWith({String? token, String? displayName, Uri? avatarUrl}) => AccountSession(
        account: account,
        pluginId: pluginId,
        token: token ?? this.token,
        createdAt: createdAt,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}

/// Outcome of a successful auth flow.
@immutable
class AuthResult {
  const AuthResult({required this.session, required this.me});
  final AccountSession session;
  final UserSummary me;
}

/// Auth flows a plugin can offer. The host renders the matching screen
/// (ログイン画面: マルチPDS / PDS変更 / ユーザー名+パスワード).
sealed class AuthFlow {
  const AuthFlow();
}

/// Open [url] in a browser (MiAuth / OAuth), then call [complete] once the
/// user returns. [complete] polls/exchanges and returns the session.
abstract class BrowserAuthFlow extends AuthFlow {
  const BrowserAuthFlow();
  Uri get url;

  /// Human hint shown under the button (e.g. "ブラウザで許可したら戻ってきてください").
  String get hint;
  Future<AuthResult> complete();
}

/// Username + password (or app password) exchange.
abstract class CredentialAuthFlow extends AuthFlow {
  const CredentialAuthFlow();
  Future<AuthResult> login({required String identifier, required String secret});
}

/// Raised by auth flows / sessions with a RASQ error code attached.
class SnsApiException implements Exception {
  SnsApiException(this.code, {this.cause});
  final ErrorCode code;
  final Object? cause;
  @override
  String toString() => 'SnsApiException(${code.display})${cause == null ? '' : ': $cause'}';
}
