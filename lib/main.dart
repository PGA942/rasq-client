import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sns_misskey/sns_misskey.dart';

import 'app/app.dart';
import 'session/session_storage.dart';

/// Dev-only connectivity probe: `flutter run --dart-define=RASQ_PROBE=misskey.io`
/// prints the result of `/api/meta` from inside the real app sandbox and exits.
const _probeHost = String.fromEnvironment('RASQ_PROBE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode && _probeHost.isNotEmpty) await _probe(_probeHost);
  runApp(const ProviderScope(child: RasqApp()));
}

Future<void> _probe(String host) async {
  final sw = Stopwatch()..start();
  try {
    final info = await MisskeyPlugin().inspectServer(host);
    debugPrint('RASQ_PROBE OK ${sw.elapsedMilliseconds}ms: ${info.name} v${info.version}');
  } catch (e) {
    debugPrint('RASQ_PROBE FAIL ${sw.elapsedMilliseconds}ms: $e');
  }
  try {
    final storage = SecureSessionStorage();
    await storage.write('rasq.probe', 'ok');
    final v = await storage.read('rasq.probe');
    await storage.delete('rasq.probe');
    debugPrint('RASQ_PROBE secure storage: ${v == 'ok' ? 'OK' : 'MISMATCH($v)'}');
  } catch (e) {
    debugPrint('RASQ_PROBE secure storage FAIL: $e');
  }
}
