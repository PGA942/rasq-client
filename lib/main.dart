import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:sns_misskey/sns_misskey.dart';

import 'app/app.dart';
import 'features/plugins/svgz.dart' show installSvgzDecoder;
import 'platform/device_overrides.dart';
import 'session/session_storage.dart';

/// Dev-only connectivity probe: `flutter run --dart-define=RASQ_PROBE=misskey.io`
/// prints the result of `/api/meta` from inside the real app sandbox and exits.
const _probeHost = String.fromEnvironment('RASQ_PROBE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Web 版 (D-456): `#/…` でなく path の URL(Central が `/app/` の下を index.html に落とす、rasq-central S-092)。
  // Central のページのチップ(`/app/astell/<code>` / `/app/rasq/<handle>` / `/app/custom/invite/<code>`)がそのまま場所になる。
  // 端末では何もしない。
  usePathUrlStrategy();
  if (kDebugMode && _probeHost.isNotEmpty) await _probe(_probeHost);
  await prepareDeviceRuntime();
  // 落書きの zstd の SVG(契約 v0.23、D-472)を RRL の Image / 編集画面で読めるように。
  installSvgzDecoder();
  runApp(ProviderScope(
    // 端末だけの実装(端末内モデルなど)。Web 版では空 (D-295)。
    overrides: deviceOverrides(),
    child: const RasqApp(),
  ));
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
