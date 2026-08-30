import 'package:rasq_models/rasq_models.dart';

import 'auth.dart';
import 'manifest.dart';
import 'server_info.dart';
import 'sns_session.dart';

/// An SNS plugin = event-handler part (this contract) + screen-constructor
/// part (RRL, M3). One instance per plugin; sessions are opened per account.
abstract class SnsPlugin {
  PluginManifest get manifest;
  SnsKind get kind;

  /// 設定第二階層ページ (D-044): `rasq.settings-page/1` JSON ドキュメント。
  /// `area` は短名(`account` / `timeline` …)。ホストが `/settings/dsl/
  /// sns.<area>` に割り当て、ローカル保存ページの値はアカウント毎 KV
  /// `sns.<pluginId>.<area>.v1` に置く(`source: "remote"` のページは
  /// [SnsSession.settingsRead]/[SnsSession.settingsWrite] 経由でサーバー保存)。
  List<String> get settingsPages => const [];

  /// Normalises user input ("misskey.io", "https://misskey.io/") to a host.
  String normalizeHost(String input) {
    var s = input.trim();
    s = s.replaceFirst(RegExp(r'^https?://'), '');
    s = s.split('/').first;
    return s.toLowerCase();
  }

  /// Probes [host] (server search / validation before login).
  Future<ServerInfo> inspectServer(String host);

  /// Starts an auth flow for [host]. [callback] is the app's deep link when
  /// the flow supports returning automatically (may be ignored).
  Future<AuthFlow> beginAuth(String host, {Uri? callback});

  /// Opens an authenticated session. Cheap; no network.
  SnsSession open(AccountSession session);
}
