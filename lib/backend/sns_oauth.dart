import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'orgate_client.dart';

/// サーバーの OAuth ブローカー経由の認証フロー (CONTRACT §3)。
///
/// Misskey は MiAuth でクライアント単体で完結するのでこれを通らない。
/// Mastodon は**インスタンスごとのアプリ登録に `client_secret` が要る**ため、
/// 登録を `orgate-server` が代行して保持する。第一期の計画で Bluesky /
/// Mastodon が出せていなかった理由(「アクセストークン発行にサーバー側が
/// 必要」)がここで解ける。
///
/// ```text
///   begin  → {state, authorizeUrl, hint}   ブラウザで authorizeUrl を開く
///   (ユーザーが許可 → サーバーの callback がディープリンクでアプリへ戻す)
///   complete {state} → {token, me}         ← トークンはここで初めて端末へ
/// ```
///
/// **サーバーはトークンを保存しない。** 受け取ったトークンはそのまま
/// [AccountSession] に載り、ホストのセキュアストレージにのみ残る。
class BrokeredOAuthFlow extends BrowserAuthFlow {
  BrokeredOAuthFlow({
    required this.client,
    required this.provider,
    required this.pluginId,
    required this.kind,
    required this.host,
    required this.state,
    required this.url,
    required this.hint,
  });

  final OrgateClient client;

  /// ブローカー側のプロバイダー名(`mastodon` など)。
  final String provider;
  final String pluginId;
  final SnsKind kind;
  final String host;

  /// ワンタイムの state。`complete` の引き当てキー。
  final String state;

  @override
  final Uri url;

  @override
  final String hint;

  @override
  Future<AuthResult> complete() async {
    final Map<String, Object?> res;
    try {
      res = await client.postJson('/auth/sns/$provider/complete', {'state': state});
    } on OrgateException catch (e) {
      // ブローカーのエラーコードは CONTRACT §9 の体系なので、そのまま
      // ホストの認証画面が読めるかたちに載せ替える。
      throw SnsApiException(e.code.copyWith(message: e.message));
    }

    final token = res['token'] as String? ?? '';
    if (token.isEmpty) {
      throw SnsApiException(ErrorCode.unauthorized.copyWith(message: 'アクセストークンを取得できませんでした'));
    }
    final me = (res['me'] as Map?)?.cast<String, Object?>() ?? const {};
    final account = AccountId(
      kind: kind,
      instance: res['host'] as String? ?? host,
      handle: me['handle'] as String? ?? '',
    );
    final avatarUrl = switch (me['avatarUrl']) { final String u when u.isNotEmpty => Uri.tryParse(u), _ => null };
    final displayName = me['displayName'] as String? ?? account.handle;

    return AuthResult(
      session: AccountSession(
        account: account,
        pluginId: pluginId,
        token: token,
        createdAt: DateTime.now(),
        displayName: displayName,
        avatarUrl: avatarUrl,
      ),
      me: UserSummary(
        id: me['id'] as String? ?? '',
        account: account,
        displayName: displayName,
        avatarUrl: avatarUrl,
      ),
    );
  }
}

/// [WasmSnsPlugin.authFlowFactory] に渡す口。サーバー未設定なら
/// [SnsApiException] で断る — ログイン画面がその場で理由を出せる。
Future<AuthFlow> Function(String host, {Uri? callback}) brokeredAuthFactory(
  Ref ref, {
  required String provider,
  required String pluginId,
  required SnsKind kind,
}) {
  return (String host, {Uri? callback}) async {
    // 接続先は認証を始める時点のものを読む(構成変更に追随させるため、
    // プラグイン登録時には束縛しない)。
    // 開発 / デモ用の差し替え (D-359): そのインスタンスが差し替えられていれば、ブローカーもダミーのサーバーに聞く。
    final devBase = devSnsBaseFor(host);
    final client = devBase != null ? OrgateClient(baseUrl: devBase) : ref.read(orgateClientProvider);
    if (client == null) {
      throw SnsApiException(ErrorCode.app(ErrorFamily.affectedSettings, '10',
          title: 'Server Not Configured',
          message: '${kind.label} のログインには RASQ サーバーが必要です。設定 →「RASQ サーバー」で接続先を設定してください。'));
    }
    final Map<String, Object?> res;
    try {
      res = await client.postJson('/auth/sns/$provider/begin', {
        'host': host,
        // Web 版 (D-296): 戻すアプリのリンクが無い。着地ページは「このタブを閉じて、認証を確認」と案内する (S-032)。
        'appCallback': ?(kIsWeb ? 'web' : callback?.toString()),
      });
    } on OrgateException catch (e) {
      throw SnsApiException(e.code.copyWith(message: e.message));
    }
    final url = Uri.tryParse(res['authorizeUrl'] as String? ?? '');
    if (url == null) {
      throw SnsApiException(ErrorCode.internalServerError.copyWith(message: '認証 URL を取得できませんでした'));
    }
    debugPrint('oauth: $provider@$host → $url');
    return BrokeredOAuthFlow(
      client: client,
      provider: provider,
      pluginId: pluginId,
      kind: kind,
      host: res['host'] as String? ?? host,
      state: res['state'] as String? ?? '',
      url: url,
      hint: res['hint'] as String? ?? 'ブラウザで許可したら、アプリに戻って「認証を確認」を押してください。',
    );
  };
}
