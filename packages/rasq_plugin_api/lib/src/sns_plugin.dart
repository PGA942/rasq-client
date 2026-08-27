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
