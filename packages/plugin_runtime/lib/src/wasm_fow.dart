import 'dart:async';

import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_core/rrl_core.dart';

/// `fow.open` のワイヤ引数を UI 側で扱う形にしたもの (D-064: FOW の
/// RRL surface 化)。`root` は rev 1 の snapshot として [RrlDocument] に
/// 取り込む。以後の更新は同じ id での `fow.open` 再要求 = 差し替え
/// (patch のドキュメント多重化は後続)。
class WasmFowRequest {
  WasmFowRequest({required this.id, required this.spec, required this.document, this.onClosed});

  /// プラグインローカルの FOW id(ホスト側はプラグイン id を前置して
  /// OverlayManager 上の衝突を避ける)。
  final String id;

  /// ワイヤの FowSpec(`type` / `confirmMode` / `initialHeightFactor` /
  /// `title` / `cancelText` / `confirmText`)。実 FowSpec への写像は
  /// OverlayManager を知るアプリ層が行う。
  final Map<String, Object?> spec;

  /// FOW の中身(RRL ツリー)。
  final RrlDocument document;

  /// 閉じたときにホストが call するプラグイン関数名
  /// (args は `{id, reason, result?}`)。
  final String? onClosed;

  factory WasmFowRequest.fromArgs(Map<String, Object?> args, {required String scope}) {
    final root = args['root'];
    if (root is! Map) throw const FormatException('fow.open: root missing');
    return WasmFowRequest(
      id: '${args['id']}',
      spec: (args['spec'] as Map?)?.cast<String, Object?>() ?? const {},
      document: RrlDocument.fromSnapshot({
        'schema': 'rasq.boundary/1',
        'scope': scope,
        'type': 'snapshot',
        'rev': 1,
        'root': root,
      }),
      onClosed: args['onClosed'] as String?,
    );
  }
}

/// プラグインの FOW surface 要求の受け口 (D-064)。OverlayManager を知る
/// アプリ層がコールバックを差し、`fow.open` / `fow.close` を実 FOW へ写す。
abstract class WasmFowSurfaceHost {
  /// `fow.open`: アプリ層が FOW を開く(同一 id は中身の差し替え)。
  abstract void Function(WasmFowRequest request)? onFowOpen;

  /// `fow.close`: アプリ層が該当 FOW を閉じる。
  abstract void Function(String id, {Object? result, String? reason})? onFowClose;

  /// ホスト側で FOW が閉じた通知(→ プラグインの `onClosed` 関数を call)。
  /// アプリ層が FOW クローズ時(reason = dismissed/completed/…)に呼ぶ。
  void notifyFowClosed(String id, {String reason = 'dismissed', Object? result});
}

/// [WasmFowSurfaceHost] の共通実装(同期/非同期コントローラで共用)。
mixin WasmFowSurfaceMixin implements WasmFowSurfaceHost {
  @override
  void Function(WasmFowRequest request)? onFowOpen;

  @override
  void Function(String id, {Object? result, String? reason})? onFowClose;

  /// FOW id → onClosed 関数名(fow.open 時に控え、通知で消費)。
  final Map<String, String?> _fowOnClosed = {};

  /// 環境から中継されてきた `fow.*` host-fn を UI 側コールバックへ写す。
  /// 戻り値は host-fn の value(open は `{opened: true}`)。
  Object? handleFowHostFn(String fn, Map<String, Object?> args, {required String scope}) {
    if (fn == RasqHostFns.fowOpen) {
      final req = WasmFowRequest.fromArgs(args, scope: scope);
      _fowOnClosed[req.id] = req.onClosed;
      onFowOpen?.call(req);
      return const {'opened': true};
    }
    onFowClose?.call('${args['id']}', result: args['result'], reason: args['reason'] as String?);
    return const <String, Object?>{};
  }

  @override
  void notifyFowClosed(String id, {String reason = 'dismissed', Object? result}) {
    final fn = _fowOnClosed.remove(id);
    if (fn == null) return;
    // マイクロタスクへ逃がす: 同期コントローラでは fow.close host-fn の
    // 最中(wasm 実行中)にここへ来ることがあり、その場で call すると
    // wasm へ再入してしまう。呼び出しが解けてから通知する。
    scheduleMicrotask(() => invokeFowClosed(fn, {'id': id, 'reason': reason, 'result': ?result}));
  }

  /// コントローラが提供: プラグインへの `call`(fire-and-forget で良い)。
  void invokeFowClosed(String fn, Map<String, Object?> args);
}
