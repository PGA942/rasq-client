import 'package:rasq_models/rasq_models.dart';

import 'auth.dart';
import 'sns_plugin.dart';
import 'sns_session.dart';

/// Host registry of installed SNS plugins and open sessions.
/// Sessions are keyed by account so per-account plugin versions stay isolated.
class PluginRegistry {
  final Map<String, SnsPlugin> _plugins = {};
  final Map<String, SnsSession> _sessions = {};

  void register(SnsPlugin plugin) => _plugins[plugin.manifest.id] = plugin;
  SnsPlugin? plugin(String id) => _plugins[id];
  Iterable<SnsPlugin> get plugins => _plugins.values;

  /// First plugin that supports [kind] (multiple may exist; store config decides later).
  SnsPlugin? pluginFor(SnsKind kind) => _plugins.values.where((p) => p.kind == kind).firstOrNull;

  SnsSession session(AccountSession s) {
    final key = s.account.key;
    return _sessions.putIfAbsent(key, () {
      final p = _plugins[s.pluginId];
      if (p == null) throw StateError('plugin ${s.pluginId} not installed');
      return p.open(s);
    });
  }

  Future<void> closeSession(AccountId account) async {
    final s = _sessions.remove(account.key);
    await s?.close();
  }

  Future<void> closeAll() async {
    for (final s in _sessions.values) {
      await s.close();
    }
    _sessions.clear();
  }
}
