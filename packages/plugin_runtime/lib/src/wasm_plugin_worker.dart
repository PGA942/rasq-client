import 'dart:async';
import 'dart:isolate';

import 'wasm_runtime.dart';

import 'host_environment.dart';
import 'wasm_worker_config.dart';

export 'wasm_worker_config.dart';

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
  final _shapes = StreamController<Map<String, Object?>>.broadcast();
  final _storage = StreamController<Map<String, Object?>>.broadcast();

  /// ワーカーの中の `storage.set` / `storage.delete` の写し (D-422)。要素は `{ns, key, value}`。
  Stream<Map<String, Object?>> get storageWrites => _storage.stream;

  /// このワーカーが初めて見た `net.fetch` の**形**(値は無い: host / method / パスの
  /// テンプレート / query のキー / ヘッダ名 / 本文のキー構造)。要素は `{hash, shape}`、
  /// 上限を超えたら `{overflow: true}` が 1 度。アプリはユーザーの同意があれば
  /// ストアに報告する(承認後に通信の形が変わった版を審査が読み直すため)。
  Stream<Map<String, Object?>> get fetchShapes => _shapes.stream;

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
    if (map['storage'] != null) {
      _storage.add((map['storage'] as Map).cast<String, Object?>());
      return;
    }
    if (map['shapes'] != null) {
      for (final s in map['shapes'] as List) {
        _shapes.add((s as Map).cast<String, Object?>());
      }
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

  /// セッションのインスタンスのホストを `net.fetch` に許可する(マニフェストが
  /// `network.instance` を宣言している場合だけ効く)。null で取り消し。
  Future<String> grantHost(String? host) => _request('grantHost', {'host': host});

  Future<void> dispose() async {
    try {
      await _request('dispose').timeout(const Duration(seconds: 2));
    } catch (_) {}
    _responses.close();
    _logs.close();
    _fows.close();
    _apps.close();
    _shapes.close();
    _storage.close();
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

  // ランタイムが控えた通信の形(初めて見たものだけ)をメインへ流す。
  void drainShapes() {
    final shapes = plugin?.takeFetchShapes() ?? const [];
    if (shapes.isNotEmpty) respond.send({'shapes': shapes});
  }

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
            onStorageWrite: (ns, key, value) => respond.send({'storage': {'ns': ns, 'key': key, 'value': value}}),
            permissions: config.permissions,
            fetchHosts: config.fetchHosts,
            instanceAllowed: config.instanceAllowed,
            gpuCompute: config.gpuCompute,
          );
          // nativeFetchEnabled: `network` 未宣言なら短絡させない (D-023)。
          // fetchHosts: ネイティブ経路も同じ宣言で縛る(Dart のゲートを通らないため)。
          // gpuComputeEnabled: 審査済み(または dev の付与)かつ `gpu_ml` 宣言のときだけ開ける (D-081)。
          plugin ??= RasqWasmPlugin.fromBytes(config.wasmBytes, hostFn: env!.dispatch, nativeFetch: env!.nativeFetchEnabled, fuelPerCall: config.fuelPerCall, fetchHosts: env!.effectiveFetchHosts, gpuCompute: env!.gpuComputeEnabled);
          respond.send({'id': id, 'ok': true, 'result': 'pong'});
        case 'grantHost':
          // セッションのインスタンス (schema v0.12 `network.instance`)。宣言が
          // 無ければ env が無視するので、ここで判断はしない。
          if (env!.grantInstance(map['host'] as String?)) plugin!.setFetchHosts(env!.effectiveFetchHosts);
          respond.send({'id': id, 'ok': true, 'result': env!.instanceHost ?? ''});
        case 'snapshot':
          respond.send({'id': id, 'ok': true, 'result': plugin!.snapshot()});
          drainShapes();
        case 'patch':
          respond.send({'id': id, 'ok': true, 'result': plugin!.patch()});
          drainShapes();
        case 'call':
          respond.send({'id': id, 'ok': true, 'result': plugin!.call(fn: '${map['fn']}', argsJson: '${map['args']}', callId: '${map['callId']}')});
          drainShapes();
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
