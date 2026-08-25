import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import 'wasm_plugin_controller.dart';

/// Renders a [WasmPluginController]'s document through [RrlRenderer] and
/// routes events back into the plugin. This is the "画面コンストラクタは隔離
/// WASM、描画は Dart レンダラー" seam of D-001 made concrete.
class WasmPluginView extends StatelessWidget {
  const WasmPluginView({super.key, required this.controller, this.rslParser, this.slots = const {}});

  final WasmPluginController controller;

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
            onEvent: (nodeId, kind, {fn, payload = const {}}) => controller.handleEvent(nodeId, kind, fn: fn, payload: payload),
          ),
        );
      },
    );
  }
}
