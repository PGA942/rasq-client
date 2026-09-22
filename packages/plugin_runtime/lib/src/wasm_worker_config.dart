import 'package:flutter/foundation.dart';

/// ワーカー isolate に渡す構成(isolate 間で送れる値だけ)。
///
/// ホスト関数のクロージャは isolate を跨げないため、ワーカー側の
/// [RasqHostEnvironment] は「storage の初期値 + nativeFetch フラグ」から
/// その場で組み立てる。alert は自動確認、ログはメッセージでメインへ流す。
@immutable
class WasmWorkerConfig {
  const WasmWorkerConfig({required this.wasmBytes, this.nativeFetch = true, this.seedStorage = const {}, this.fowPermissions = const {'widget'}, this.appFns = const {}, this.permissions = const {}, this.fuelPerCall, this.fetchHosts = const {}, this.instanceAllowed = false});

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

  /// マニフェスト `network.hosts` (schema v0.12)。空 = どこにも繋げない。
  final Set<String> fetchHosts;

  /// マニフェスト `network.instance`: セッションのインスタンスを後から
  /// 許可してよいか(`grantHost`)。偽なら grant は無視される。
  final bool instanceAllowed;
}
