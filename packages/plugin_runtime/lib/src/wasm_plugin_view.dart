import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import 'wasm_fow.dart';
import 'wasm_plugin_controller.dart';

/// Renders a [WasmPluginController]'s document through [RrlRenderer] and
/// routes events back into the plugin. This is the "画面コンストラクタは隔離
/// WASM、描画は Dart レンダラー" seam of D-001 made concrete.
class WasmPluginView extends StatelessWidget {
  const WasmPluginView({super.key, required this.controller, this.rslParser, this.slots = const {}});

  /// 同期([WasmPluginController])/非同期(AsyncWasmPluginController)どちらでも。
  final WasmPluginViewModel controller;

  /// RSL/MFM parser for RichText sources (the app passes `InlineSpans.parse`).
  final List<RasqSpan> Function(String source)? rslParser;
  final Map<String, Widget> slots;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final error = controller.lastError;
        final doc = controller.document;
        if (doc == null) {
          if (error != null) {
            return RasqInlineErrorTile(code: ErrorCode.internalServerError.copyWith(message: error));
          }
          return const RasqLoading();
        }
        return RrlRenderer(
          node: doc.root,
          host: RrlHost(
            instanceScope: doc.scope,
            scope: RrlScope({}),
            rslParser: rslParser,
            slots: slots,
            // 実物ジオメトリ (D-072): role 付きノードの矩形を登録 → FOW の
            // 実物アンカー(fow.open anchor)が引く。
            geometry: controller.geometry,
            onEvent: (nodeId, kind, {fn, payload = const {}}) => controller.handleEvent(nodeId, kind, fn: fn, payload: payload),
          ),
        );
      },
    );
  }
}

/// プラグインが `fow.open` で渡した RRL ツリーを FOW の中身として描画する
/// (D-064: FOW の RRL surface 化)。イベントは通常ページと同じ経路で
/// プラグインの関数 `call` に戻る。中身の更新は同一 id での `fow.open`
/// 再要求 = リクエスト差し替え(このウィジェットごと作り直される)。
class WasmFowView extends StatelessWidget {
  const WasmFowView({super.key, required this.controller, required this.request, this.rslParser});

  final WasmPluginViewModel controller;
  final WasmFowRequest request;
  final List<RasqSpan> Function(String source)? rslParser;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: RrlRenderer(
          node: request.document.root,
          host: RrlHost(
            instanceScope: request.document.scope,
            scope: RrlScope({}),
            rslParser: rslParser,
            onEvent: (nodeId, kind, {fn, payload = const {}}) => controller.handleEvent(nodeId, kind, fn: fn, payload: payload),
          ),
        ),
      );
}
