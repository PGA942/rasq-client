import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../shell/headers.dart';
import '../../shell/third_column.dart';
import '../../text/inline_spans.dart';

/// WASM プラグイン試験画面 (dev)。misskey-wasm-sample(rasq-sdk-sample で
/// ビルドした .wasm)をインポートし、plugin_runtime 経由で描画する:
///
/// 1. 同梱アセット(assets/plugins/misskey_wasm_sample.wasm)または任意の
///    .wasm ファイルパスからロード → 初期 snapshot を表示
/// 2. 「TL取得」→ プラグインが `net.fetch`(ランタイム内蔵 rustls, D-023)で
///    Misskey の `notes/local-timeline` を叩き、RRL ツリーを再構築 → 再描画
/// 3. タイル上のタップは `call(fn)` としてプラグインへ戻る(結果を下部に表示)
///
/// 通常はワーカー isolate(AsyncWasmPluginController)で実行し UI を
/// ブロックしない。テストは envOverride で同期コントローラに差し替える。
class WasmPluginScreen extends StatefulWidget {
  const WasmPluginScreen({super.key, this.wasmBytesOverride, this.envOverride});

  /// Tests inject the bytes / a hermetic environment (同期実行になる).
  final Uint8List? wasmBytesOverride;
  final RasqHostEnvironment? envOverride;

  @override
  State<WasmPluginScreen> createState() => _WasmPluginScreenState();
}

class _WasmPluginScreenState extends State<WasmPluginScreen> {
  WasmPluginViewModel? _controller;
  String? _loadError;
  final _hostField = TextEditingController(text: 'misskey.io');
  final _pathField = TextEditingController();
  bool _busy = false;

  /// FOW surface (D-064) 用に捕まえた OverlayManager(dispose 時の
  /// closeOwnedBy にも使うので context 経由にしない)。
  OverlayManager? _overlay;

  /// この画面のプラグインが開く FOW の id 前置(衝突回避 + 一括クローズ)。
  static const _fowOwner = 'wasm-sample';
  static const _fowPrefix = 'fow.wasm-sample.';

  @override
  void initState() {
    super.initState();
    _loadFromAsset();
  }

  Future<void> _loadFromAsset() async {
    try {
      final bytes = widget.wasmBytesOverride ?? (await rootBundle.load('assets/plugins/misskey_wasm_sample.wasm')).buffer.asUint8List();
      await _start(bytes);
    } catch (e) {
      setState(() => _loadError = 'アセットの読み込みに失敗: $e');
    }
  }

  Future<void> _loadFromPath(String path) async {
    try {
      await _start(File(path).readAsBytesSync());
    } catch (e) {
      setState(() => _loadError = '$path の読み込みに失敗: $e');
    }
  }

  Future<void> _start(Uint8List bytes) async {
    _disposeController();
    if (widget.envOverride != null) {
      final controller = WasmPluginController(wasmBytes: bytes, env: widget.envOverride)..load();
      _wireFowSurface(controller);
      setState(() {
        _controller = controller;
        _loadError = null;
      });
      return;
    }
    final controller = AsyncWasmPluginController(wasmBytes: bytes);
    _wireFowSurface(controller);
    setState(() {
      _controller = controller;
      _loadError = null;
    });
    await controller.load();
  }

  /// プラグインの fow.open/close (D-064) を OverlayManager の実 FOW へ写す。
  void _wireFowSurface(WasmPluginViewModel controller) {
    if (controller is! WasmFowSurfaceHost) return;
    final host = controller as WasmFowSurfaceHost;
    host.onFowOpen = (req) => _openPluginFow(controller, req);
    host.onFowClose = (id, {result, reason}) => _overlay?.close('$_fowPrefix$id', result: result);
  }

  void _openPluginFow(WasmPluginViewModel controller, WasmFowRequest req) {
    if (!mounted) return;
    final manager = _overlay ??= OverlayScope.read(context);
    final spec = req.spec;
    final type = switch ('${spec['type']}') {
      'interstitial' => FowPanelType.interstitial,
      'system' => FowPanelType.system,
      _ => FowPanelType.widget,
    };
    final fowSpec = FowSpec(
      type: type,
      initialHeightFactor: (spec['initialHeightFactor'] as num?)?.toDouble() ?? 0.45,
      title: spec['title'] as String?,
      cancelText: spec['cancelText'] as String? ?? (req.onCancel != null ? '閉じる' : null),
      confirmText: spec['confirmText'] as String?,
      dockAboveFooter: true,
      // 横ドッキング (D-062): 開いた画面のカラムに揃える。
      columnIndex: fowColumnOf(context),
    );
    // ✕の割り込み (D-066): onCancel 指定時、キャンセルボタンは閉じずに
    // プラグインの関数を呼ぶ(プラグインが確認 FOW を出して自分で閉じる)。
    final onCancelFn = req.onCancel;
    if (onCancelFn != null) {
      fowSpec.interceptCancel = () => controller.handleEvent('${req.document.scope}:${req.id}', 'cancel', fn: onCancelFn, payload: {'id': req.id});
    }
    manager.show(RasqOverlayEntry(
      id: '$_fowPrefix${req.id}',
      layer: OverlayLayer.fow,
      alignment: Alignment.bottomCenter,
      ownerId: _fowOwner,
      semanticsLabel: spec['title'] as String? ?? 'プラグインFOW',
      // ピッカー同手法 (D-051): 透明バリア、余白クリックで破棄。
      barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
      fow: fowSpec,
      onClosed: (reason, result) {
        // 同一 id の再 open(中身の差し替え)はクローズ通知にしない。
        if (reason == OverlayCloseReason.replaced) return;
        (controller as WasmFowSurfaceHost).notifyFowClosed(req.id, reason: reason.name, result: result);
      },
      builder: (ctx, handle) => WasmFowView(controller: controller, request: req, rslParser: InlineSpans.parse),
    ));
  }

  void _disposeController() {
    _overlay?.closeOwnedBy(_fowOwner);
    final c = _controller;
    if (c is WasmPluginController) c.dispose();
    if (c is AsyncWasmPluginController) c.dispose();
    _controller = null;
  }

  Future<void> _invoke(String fn, Map<String, Object?> args) async {
    final c = _controller;
    setState(() => _busy = true);
    try {
      if (c is AsyncWasmPluginController) {
        await c.invoke(fn, args);
      } else if (c is WasmPluginController) {
        c.invoke(fn, args);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _disposeController();
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
                onPressed: controller == null || _busy ? null : () => _invoke('timeline', {'host': _hostField.text.trim(), 'limit': 10}),
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download, size: 18),
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
