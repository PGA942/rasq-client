// rasq-client.yml の規則の例 (`semgrep --test .semgrep`)。コンパイルはしない(analyzer からは除外)。
// 注釈 `ruleid` の次の行は拾われるべき、注釈 `ok` の次の行は拾われてはいけない。
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class Session {
  final String token = '';
  final List<String> tokens = const [];
}

// ── rasq-client-secret-in-log ────────────────────────────────────────────────
void logs(Session session, String token, String apiKey, String hfToken) {
  // ruleid: rasq-client-secret-in-log
  debugPrint('token: $token');
  // ruleid: rasq-client-secret-in-log
  debugPrint('session ${session.token} rejected');
  // ruleid: rasq-client-secret-in-log
  print('key=${apiKey.trim()}');
  // ruleid: rasq-client-secret-in-log
  stdout.writeln('hf: $hfToken');
  // ok: rasq-client-secret-in-log
  debugPrint('rasq account: token rejected, restoring the device');
  // ok: rasq-client-secret-in-log
  debugPrint('tokens: ${session.tokens.length}');
  // ok: rasq-client-secret-in-log
  debugPrint('has token: ${token.isNotEmpty}');
}

// ── rasq-client-http-timeout ─────────────────────────────────────────────────
Future<void> requests(Uri url, http.Client? injected, http.Request req) async {
  // ruleid: rasq-client-http-timeout
  final a = await http.get(url);
  // ok: rasq-client-http-timeout
  final b = await http.get(url).timeout(const Duration(seconds: 30));
  final c = injected ?? http.Client();
  try {
    // ruleid: rasq-client-http-timeout
    await c.post(url, body: 'x');
    // ok: rasq-client-http-timeout
    await c.post(url, body: 'x').timeout(const Duration(seconds: 30));
  } finally {
    c.close();
  }
  final d = http.Client();
  // ruleid: rasq-client-http-timeout
  final res = await d.send(req);
  // ok: rasq-client-http-timeout
  final res2 = await d.send(req).timeout(const Duration(seconds: 60));
  debugPrint('$a $b $res $res2');
}

// ── rasq-client-runtime-fetch-gate ───────────────────────────────────────────
class RasqWasmPlugin {
  factory RasqWasmPlugin.fromBytes(Uint8List bytes, {Object? hostFn, bool nativeFetch = false, int? fuelPerCall, Set<String> fetchHosts = const {}, bool gpuCompute = false}) => throw UnimplementedError();
}

class Env {
  bool get nativeFetch => true;
  bool get nativeFetchEnabled => true;
  Set<String> get effectiveFetchHosts => const {};
  Set<String> get fetchHosts => const {};
  bool get gpuCompute => true;
  bool get gpuComputeEnabled => true;
}

void runtimes(Uint8List bytes, Env env, Env? maybeEnv) {
  // ok: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes, hostFn: null, nativeFetch: env.nativeFetchEnabled, fuelPerCall: null, fetchHosts: env.effectiveFetchHosts, gpuCompute: env.gpuComputeEnabled);
  // ok: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes, hostFn: null, nativeFetch: maybeEnv!.nativeFetchEnabled, fetchHosts: maybeEnv!.effectiveFetchHosts, gpuCompute: maybeEnv!.gpuComputeEnabled);
  // ruleid: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes, hostFn: null, nativeFetch: env.nativeFetch, fetchHosts: env.effectiveFetchHosts, gpuCompute: env.gpuComputeEnabled);
  // ruleid: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes, hostFn: null, nativeFetch: env.nativeFetchEnabled, fetchHosts: env.fetchHosts, gpuCompute: env.gpuComputeEnabled);
  // gpuCompute を省く / env の判定以外(宣言だけ・定数)を渡す。
  // ruleid: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes, hostFn: null, nativeFetch: env.nativeFetchEnabled, fetchHosts: env.effectiveFetchHosts);
  // ruleid: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes, hostFn: null, nativeFetch: env.nativeFetchEnabled, fetchHosts: env.effectiveFetchHosts, gpuCompute: env.gpuCompute);
  // ruleid: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes, hostFn: null, nativeFetch: env.nativeFetchEnabled, fetchHosts: env.effectiveFetchHosts, gpuCompute: true);
  // ruleid: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes, hostFn: null, nativeFetch: true);
  // ruleid: rasq-client-runtime-fetch-gate
  RasqWasmPlugin.fromBytes(bytes);
}

// ── rasq-client-host-match-shared ────────────────────────────────────────────
bool hosts(String h, String suffix, String file, String ext) {
  // ruleid: rasq-client-host-match-shared
  if (h.endsWith('.$suffix')) return true;
  // ruleid: rasq-client-host-match-shared
  if (h.endsWith('.' + suffix)) return true;
  // ok: rasq-client-host-match-shared
  if (file.endsWith(ext)) return true;
  // ok: rasq-client-host-match-shared
  if (file.endsWith('.gif')) return true;
  return false;
}

// ── rasq-client-launch-url-external ──────────────────────────────────────────
Future<void> links(Uri u) async {
  // ok: rasq-client-launch-url-external
  await launchUrl(u, mode: LaunchMode.externalApplication);
  // ruleid: rasq-client-launch-url-external
  await launchUrl(u);
  // ruleid: rasq-client-launch-url-external
  await launchUrl(u, mode: LaunchMode.inAppWebView);
  // ruleid: rasq-client-launch-url-external
  await launchUrl(u, mode: LaunchMode.platformDefault);
}

// ── rasq-client-subprocess ───────────────────────────────────────────────────
Future<void> commands(String path) async {
  // ruleid: rasq-client-subprocess
  await Process.run('/usr/bin/xattr', ['-dr', 'com.apple.quarantine', path]);
  // ruleid: rasq-client-subprocess
  Process.runSync('curl', ['-sS', path]);
  // ok: rasq-client-subprocess
  await File(path).readAsBytes();
}
