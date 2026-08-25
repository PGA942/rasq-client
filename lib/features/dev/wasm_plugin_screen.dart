import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../shell/headers.dart';
import '../../text/inline_spans.dart';

/// WASM プラグイン試験画面 (dev)。misskey-wasm-sample(rasq-sdk-sample で
/// ビルドした .wasm)をインポートし、plugin_runtime 経由で描画する:
///
/// 1. 同梱アセット(assets/plugins/misskey_wasm_sample.wasm)または任意の
///    .wasm ファイルパスからロード → 初期 snapshot を表示
/// 2. 「TL取得」→ プラグインが host の `net.fetch`(curl 同期)で Misskey の
///    `notes/local-timeline` を叩き、RRL ツリーを再構築 → 再描画
/// 3. タイル上のタップは `call(fn)` としてプラグインへ戻る(結果を下部に表示)
class WasmPluginScreen extends StatefulWidget {
  const WasmPluginScreen({super.key, this.wasmBytesOverride, this.envOverride});

  /// Tests inject the bytes / a hermetic environment.
  final Uint8List? wasmBytesOverride;
  final RasqHostEnvironment? envOverride;

  @override
  State<WasmPluginScreen> createState() => _WasmPluginScreenState();
}

class _WasmPluginScreenState extends State<WasmPluginScreen> {
  WasmPluginController? _controller;
  String? _loadError;
  final _hostField = TextEditingController(text: 'misskey.io');
  final _pathField = TextEditingController();
  bool _busy = false;

  RasqHostEnvironment get _env =>
      widget.envOverride ?? RasqHostEnvironment(fetch: curlSyncFetch, onLog: (m) => debugPrint('[wasm host] $m'));

  @override
  void initState() {
    super.initState();
    _loadFromAsset();
  }

  Future<void> _loadFromAsset() async {
    try {
      final bytes = widget.wasmBytesOverride ?? (await rootBundle.load('assets/plugins/misskey_wasm_sample.wasm')).buffer.asUint8List();
      _start(bytes);
    } catch (e) {
      setState(() => _loadError = 'アセットの読み込みに失敗: $e');
    }
  }

  void _loadFromPath(String path) {
    try {
      _start(File(path).readAsBytesSync());
    } catch (e) {
      setState(() => _loadError = '$path の読み込みに失敗: $e');
    }
  }

  void _start(Uint8List bytes) {
    _controller?.dispose();
    final controller = WasmPluginController(wasmBytes: bytes, env: _env)..load();
    setState(() {
      _controller = controller;
      _loadError = null;
    });
  }

  Future<void> _run(void Function() op) async {
    setState(() => _busy = true);
    try {
      op(); // v1 host fns are synchronous — this blocks (dev screen; v2 = worker isolate)
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _hostField.dispose();
    _pathField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'WASMプラグイン試験 (dev)'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: RasqInput(controller: _hostField, hintText: 'インスタンス (例: misskey.io)')),
              const SizedBox(width: RasqSpacing.sm),
              FilledButton.icon(
                onPressed: controller == null || _busy ? null : () => _run(() => controller.invoke('timeline', {'host': _hostField.text.trim(), 'limit': 10})),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('TL取得'),
              ),
            ]),
            const SizedBox(height: RasqSpacing.xs),
            Row(children: [
              Expanded(child: RasqInput(controller: _pathField, hintText: '.wasm のパスからインポート (空欄=同梱アセット)')),
              const SizedBox(width: RasqSpacing.sm),
              OutlinedButton(
                onPressed: _busy ? null : () => _pathField.text.trim().isEmpty ? _loadFromAsset() : _loadFromPath(_pathField.text.trim()),
                child: const Text('読み込み'),
              ),
            ]),
            if (_loadError != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_loadError!, style: RasqTypography.caption.copyWith(color: RasqTokens.of(context).danger))),
            if (controller?.lastResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('result: ${controller!.lastResult}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
        const Divider(),
        Expanded(
          child: controller == null
              ? const RasqLoading()
              : SingleChildScrollView(
                  child: WasmPluginView(controller: controller, rslParser: InlineSpans.parse),
                ),
        ),
      ]),
    );
  }
}
