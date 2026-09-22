import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:rasq_wasm_runtime/rasq_wasm_runtime.dart';

import 'host_environment.dart';

/// ワーカー isolate に渡す構成(isolate 間で送れる値だけ)。
///
/// ホスト関数のクロージャは isolate を跨げないため、ワーカー側の
/// [RasqHostEnvironment] は「storage の初期値 + nativeFetch フラグ」から
/// その場で組み立てる。alert は自動確認、ログはメッセージでメインへ流す。
@immutable
class WasmWorkerConfig {
  const WasmWorkerConfig({required this.wasmBytes, this.nativeFetch = true, this.seedStorage = const {}, this.fowPermissions = const {'widget'}, this.appFns = const {}, this.permissions = const {}, this.fuelPerCall});

  final Uint8List wasmBytes;
  final bool nativeFetch;
  final Map<String, Object?> seedStorage;

  /// 許可された FOW type (D-064)。ワーカー側の環境にそのまま渡る。
  final Set<String> fowPermissions;

  /// 許可されたアプリ向けホスト関数 (D-167)。
  final Set<String> appFns;

  /// マニフェストが宣言した権限 (D-004)。`network` / `storage.*` のゲートに使う。
  final Set<String> permissions;

  /// 1 呼び出しあたりの fuel 予算。null ならランタイム既定(重いほう)。
  final int? fuelPerCall;
}

/// WASM プラグインを専用 isolate で動かすワーカー (D-023 の後段)。
///
/// v1 の host_fn は同期でワーカースレッドをブロックするが、UI isolate は
/// ブロックされない — `net.fetch`(ランタイム内蔵 rustls)の間も UI が動く。
class WasmPluginWorker {
  WasmPluginWorker._(this._isolate, this._commands, this._responses);

  final Isolate _isolate;
  final SendPort _commands;
  final ReceivePort _responses;

  final Map<int, Completer<String>> _pending = {};
  int _seq = 0;
  final _logs = StreamController<String>.broadcast();
  final _fows = StreamController<Map<String, Object?>>.broadcast();
  final _apps = StreamController<Map<String, Object?>>.broadcast();

  /// ホスト関数のログ(hostFn 呼び出し名など)。
  Stream<String> get logs => _logs.stream;

  /// ワーカー内のアプリ向けホスト関数の中継 (D-167)。要素は `{fn, args}`。
  Stream<Map<String, Object?>> get appRequests => _apps.stream;

  /// ワーカー内の `fow.open` / `fow.close` の中継 (D-064)。要素は
  /// `{fn, args}` — wasm 側は即 `{opened:true}` を受け取り(受理)、実際の
  /// 表示はこのストリームを購読する UI isolate 側が行う。
  Stream<Map<String, Object?>> get fowRequests => _fows.stream;

  static Future<WasmPluginWorker> spawn(WasmWorkerConfig config) async {
    final handshake = ReceivePort();
    final isolate = await Isolate.spawn(_workerMain, [handshake.sendPort, config], debugName: 'rasq-wasm-worker');
    final responses = ReceivePort();
    final first = await handshake.first;
    handshake.close();
    if (first is! SendPort) {
      isolate.kill(priority: Isolate.immediate);
      throw StateError('wasm worker failed to start: $first');
    }
    first.send(responses.sendPort);
    final worker = WasmPluginWorker._(isolate, first, responses);
    responses.listen(worker._onMessage);
    // 起動確認(instantiate 失敗はここで例外になる)。
    await worker._request('ping');
    return worker;
  }

  void _onMessage(dynamic message) {
    final map = (message as Map).cast<String, Object?>();
    if (map['log'] != null) {
      _logs.add('${map['log']}');
      return;
    }
    if (map['fow'] != null) {
      _fows.add((map['fow'] as Map).cast<String, Object?>());
      return;
    }
    if (map['app'] != null) {
      _apps.add((map['app'] as Map).cast<String, Object?>());
      return;
    }
    final completer = _pending.remove(map['id']);
    if (completer == null) return;
    if (map['ok'] == true) {
      completer.complete('${map['result']}');
    } else {
      completer.completeError(StateError('${map['error']}'));
    }
  }

  Future<String> _request(String op, [Map<String, Object?> args = const {}]) {
    final id = _seq++;
    final completer = Completer<String>();
    _pending[id] = completer;
    _commands.send({'id': id, 'op': op, ...args});
    return completer.future;
  }

  Future<String> snapshot() => _request('snapshot');
  Future<String> patch() => _request('patch');
  Future<String> call({required String fn, required String argsJson, required String callId}) =>
      _request('call', {'fn': fn, 'args': argsJson, 'callId': callId});

  Future<void> dispose() async {
    try {
      await _request('dispose').timeout(const Duration(seconds: 2));
    } catch (_) {}
    _responses.close();
    _logs.close();
    _fows.close();
    _apps.close();
    _isolate.kill(priority: Isolate.beforeNextEvent);
  }
}

Future<void> _workerMain(List<Object?> init) async {
  final handshake = init[0] as SendPort;
  final config = init[1] as WasmWorkerConfig;

  final commands = ReceivePort();
  handshake.send(commands.sendPort);
  // メイン側の応答ポートを受け取ってから開始。
  final firstCommand = Completer<SendPort>();
  late final SendPort respond;

  RasqWasmPlugin? plugin;
  RasqHostEnvironment? env;

  commands.listen((message) {
    if (message is SendPort) {
      firstCommand.complete(message);
      return;
    }
    final map = (message as Map).cast<String, Object?>();
    final id = map['id'];
    try {
      switch (map['op']) {
        case 'ping':
          env ??= RasqHostEnvironment(
            storage: {...config.seedStorage},
            nativeFetch: config.nativeFetch,
            onLog: (m) => respond.send({'log': m}),
            fowPermissions: config.fowPermissions,
            // fow.* はメイン isolate へ fire-and-forget で中継 (D-064)。
            // 戻り null → 環境の既定値(open は {opened:true} = 受理)。
            onFow: (fn, args) {
              respond.send({'fow': {'fn': fn, 'args': args}});
              return null;
            },
            // アプリ向けホスト関数 (D-167) も同じく fire-and-forget で中継。
            appFns: config.appFns,
            onAppFn: (fn, args) => respond.send({'app': {'fn': fn, 'args': args}}),
            permissions: config.permissions,
          );
          // nativeFetchEnabled: `network` 未宣言なら短絡させない (D-023)。
          plugin ??= RasqWasmPlugin.fromBytes(config.wasmBytes, hostFn: env!.dispatch, nativeFetch: env!.nativeFetchEnabled, fuelPerCall: config.fuelPerCall);
          respond.send({'id': id, 'ok': true, 'result': 'pong'});
        case 'snapshot':
          respond.send({'id': id, 'ok': true, 'result': plugin!.snapshot()});
        case 'patch':
          respond.send({'id': id, 'ok': true, 'result': plugin!.patch()});
        case 'call':
          respond.send({'id': id, 'ok': true, 'result': plugin!.call(fn: '${map['fn']}', argsJson: '${map['args']}', callId: '${map['callId']}')});
        case 'dispose':
          plugin?.dispose();
          plugin = null;
          respond.send({'id': id, 'ok': true, 'result': 'disposed'});
          commands.close();
        default:
          respond.send({'id': id, 'ok': false, 'error': 'unknown op: ${map['op']}'});
      }
    } catch (e) {
      respond.send({'id': id, 'ok': false, 'error': '$e'});
    }
  });

  respond = await firstCommand.future;
}
