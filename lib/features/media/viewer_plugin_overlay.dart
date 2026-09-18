import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../plugins/slot_plugins.dart';
import '../settings/settings_dsl.dart';

/// 全画面表示プラグイン (D-167、スロット `viewer.overlay`) の共通部 (D-178)。
///
/// 投稿のビューワー(`MediaViewerScreen`)とプロフィールのアイコン / バナーのビューワー
/// (`ProfileImageViewerScreen`)で同じ流れ: 画像本体を(長辺 1024 に縮めて)プラグインへ渡し、
/// 重ねる RRL(座標は渡した画素数)をもらって [wrap] で画像の上に描く。
/// 所有する State の `ref` を借り、State の dispose で [dispose] を呼ぶ。
/// 画像本体の取得(テストで差し替える)。200 以外 / 失敗は null。
final viewerImageFetcherProvider = Provider<Future<Uint8List?> Function(Uri url)>((ref) => (url) async {
      final res = await http.get(url).timeout(const Duration(seconds: 15));
      return res.statusCode == 200 ? res.bodyBytes : null;
    });

/// 全画面表示プラグインの有効 / 無効 (D-205 → D-207): 全画面の右上のアイコンで切り替え、設定エリア `slots.viewer` に保存。
/// 無効なプラグインには画像を渡さず、重ねも出さない(停止時に RRL の重ねが複数出るかどうかをここで決める)。
const viewerPluginsSettingsArea = 'slots.viewer';

String viewerPluginEnabledKey(String id) => 'enabled.$id';

/// 有効な全画面表示プラグイン(ビューワーが画像を渡す相手)。
final viewerOverlayPluginsProvider = Provider<List<SlotPlugin>>((ref) {
  final all = ref.watch(slotPluginsForProvider(SlotIds.viewerOverlay));
  final v = ref.watch(settingsAreaProvider(viewerPluginsSettingsArea)).value ?? const <String, Object?>{};
  return [for (final p in all) if (v[viewerPluginEnabledKey(p.id)] != false) p];
});

/// その画像について、プラグイン 1 つがいまどうなっているか (D-246)。黙って失敗しない: トグルに出す。
enum ViewerPluginPhase {
  /// まだ渡していない(無効 / これから)。
  idle,

  /// 画像を取得中 / プラグインが見ている最中(wasm はインタープリタで動くので、大きい画像は数秒かかる)。
  asking,

  /// 重ねを出している。
  shown,

  /// 見たが、重ねるものは無かった。
  none,

  /// 画像を取れなかった / プラグインがエラーを返した。オフ → オンで渡し直す。
  failed,
}

@immutable
class ViewerPluginStatus {
  const ViewerPluginStatus(this.phase, [this.message]);
  final ViewerPluginPhase phase;
  final String? message;
  static const idle = ViewerPluginStatus(ViewerPluginPhase.idle);

  String get label => switch (phase) {
        ViewerPluginPhase.idle => '',
        ViewerPluginPhase.asking => '画像を見ています…',
        ViewerPluginPhase.shown => '検出あり',
        ViewerPluginPhase.none => '検出なし',
        ViewerPluginPhase.failed => '失敗: ${message ?? ''}(オフ → オンでやり直す)',
      };
}

class ViewerPluginOverlays {
  ViewerPluginOverlays(this.ref, {required this.onChanged});
  final WidgetRef ref;

  /// 重ねが増えた / 差し替わった(setState を呼ぶ)。
  final VoidCallback onChanged;

  /// 画像 index → プラグイン id → 重ね (D-207: 複数プラグインの重ねを同時に出せる)。
  final Map<int, Map<String, ViewerOverlay>> _overlays = {};

  /// 画像 index → 渡したプラグイン id → トークン。
  final Map<int, Map<String, String>> _tokens = {};

  /// 画像 index → プラグイン id → 状態。
  final Map<int, Map<String, ViewerPluginStatus>> _status = {};

  ViewerPluginStatus statusOf(int i, String pluginId) => _status[i]?[pluginId] ?? ViewerPluginStatus.idle;

  void _setStatus(int i, String pluginId, ViewerPluginStatus st) {
    if (_disposed) return;
    _status.putIfAbsent(i, () => {})[pluginId] = st;
    onChanged();
  }

  /// 有効 / 無効を切り替える(`slots.viewer` に保存)。有効にしたら、この画像をまだ渡せていなければ渡す
  /// (前に失敗したものはここでやり直しになる)。無効は重ねを出さないだけ(トークンは残す)。
  Future<void> toggle(String pluginId, int i, Uri? url) async {
    final enabled = ref.read(viewerOverlayPluginsProvider).any((p) => p.id == pluginId);
    await ref.read(settingsAreaProvider(viewerPluginsSettingsArea).notifier).set(viewerPluginEnabledKey(pluginId), !enabled);
    if (_disposed) return;
    if (!enabled && url != null) await ask(i, url);
    onChanged();
  }

  /// その画像の重ね(有効なプラグインのぶんだけ)。
  List<ViewerOverlay> overlaysOf(int i) {
    final enabled = {for (final p in ref.read(viewerOverlayPluginsProvider)) p.id};
    return [for (final e in (_overlays[i] ?? const <String, ViewerOverlay>{}).entries) if (enabled.contains(e.key)) e.value];
  }

  /// [i] 番目の画像 [url] をプラグインへ渡す(登録が無い / 済みなら何もしない)。
  /// dispose では ref を使えない(Riverpod 3)ので、使った登録簿と対象プラグインを覚えておく。
  SlotPluginsNotifier? _notifier;
  final Map<String, SlotPlugin> _used = {};

  Future<void> ask(int i, Uri url) async {
    // 有効で、まだ渡していないプラグインだけ (D-205 / D-207: 後から有効にしたものにも渡す)。
    // 渡せなかったもの(画像の取得失敗 / プラグインのエラー)は記録を外して、次の ask でやり直せるようにする。
    final asked = _tokens.putIfAbsent(i, () => {});
    final plugins = [for (final p in ref.read(viewerOverlayPluginsProvider)) if (!asked.containsKey(p.id)) p];
    if (plugins.isEmpty) return;
    _notifier ??= ref.read(slotPluginsProvider.notifier);
    final token = 'viewer-${identityHashCode(this)}-$i';
    for (final p in plugins) {
      _used[p.id] = p;
      asked[p.id] = token;
      _setStatus(i, p.id, const ViewerPluginStatus(ViewerPluginPhase.asking));
    }
    void failAll(String why) {
      for (final p in plugins) {
        asked.remove(p.id);
        _setStatus(i, p.id, ViewerPluginStatus(ViewerPluginPhase.failed, why));
      }
    }

    Uint8List? bytes;
    var width = 0;
    var height = 0;
    try {
      final src = await ref.read(viewerImageFetcherProvider)(url);
      if (src == null) return failAll('画像を取得できませんでした');
      final scaled = await downscalePng(src, 1024);
      bytes = scaled.$1;
      width = scaled.$2;
      height = scaled.$3;
    } catch (e) {
      debugPrint('viewer overlay: fetch failed: $e');
      return failAll('画像を取得できませんでした($e)');
    }
    if (_disposed) return;
    if (width == 0 || height == 0) return failAll('画像を読めませんでした');
    for (final p in plugins) {
      final (:root, :error) = await _notifier!.viewerOpen(
        p,
        token: token,
        url: url.toString(),
        mimeType: 'image/png',
        width: width,
        height: height,
        bytes: bytes,
        onOverlay: (root) => _set(i, ViewerOverlay(root: root, width: width, height: height, plugin: p)),
      );
      if (error != null) {
        asked.remove(p.id);
        _setStatus(i, p.id, ViewerPluginStatus(ViewerPluginPhase.failed, error));
      } else if (root != null) {
        _set(i, ViewerOverlay(root: root, width: width, height: height, plugin: p));
      } else {
        _setStatus(i, p.id, const ViewerPluginStatus(ViewerPluginPhase.none));
      }
    }
  }

  void _set(int i, ViewerOverlay ov) {
    if (_disposed) return;
    _overlays.putIfAbsent(i, () => {})[ov.plugin.id] = ov;
    _status.putIfAbsent(i, () => {})[ov.plugin.id] = const ViewerPluginStatus(ViewerPluginPhase.shown);
    onChanged();
  }

  bool _disposed = false;

  /// 開いたトークンを全部閉じる(`viewer.close`)。
  void dispose() {
    _disposed = true;
    final notifier = _notifier;
    if (notifier == null) return;
    for (final byPlugin in _tokens.values) {
      for (final e in byPlugin.entries) {
        final p = _used[e.key];
        if (p != null) notifier.viewerClose(p, e.value);
      }
    }
  }

  /// 画像の上に重ねる(画素座標 → 表示倍率はホストが合わせる)。重ねが無ければ [image] のまま。
  Widget wrap(int i, Widget image) {
    final list = overlaysOf(i);
    if (list.isEmpty) return image;
    final first = list.first;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: first.width.toDouble(),
        height: first.height.toDouble(),
        child: Stack(fit: StackFit.expand, children: [
          image,
          // 有効なプラグインの重ねを全部(同じ画素数で渡しているので座標は共通)。
          for (final ov in list)
            Builder(builder: (_) {
              final controller = ov.plugin.runtime.view;
              return RrlRenderer(
                key: ValueKey('viewer.overlay.${ov.plugin.id}'),
                node: ov.root,
                host: RrlHost(
                  instanceScope: controller.document?.scope ?? ov.plugin.id,
                  scope: RrlScope({}),
                  geometry: controller.geometry,
                  onEvent: (nodeId, kind, {fn, payload = const {}}) => controller.handleEvent(nodeId, kind, fn: fn, payload: payload),
                ),
              );
            }),
        ]),
      ),
    );
  }

  /// 長辺 [max] に縮めた PNG と画素数。
  static Future<(Uint8List, int, int)> downscalePng(Uint8List src, int max) async {
    final probe = await ui.instantiateImageCodec(src);
    final frame = await probe.getNextFrame();
    var image = frame.image;
    if (image.width > max || image.height > max) {
      final wide = image.width >= image.height;
      final codec = await ui.instantiateImageCodec(src, targetWidth: wide ? max : null, targetHeight: wide ? null : max);
      image = (await codec.getNextFrame()).image;
    }
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return (data!.buffer.asUint8List(), image.width, image.height);
  }
}

class ViewerOverlay {
  const ViewerOverlay({required this.root, required this.width, required this.height, required this.plugin});
  final RrlNode root;
  final int width;
  final int height;
  final SlotPlugin plugin;
}

/// 全画面表示プラグインのトグル (D-214 → D-246): ON = 塗り / アクセント。処理中は砂時計の印、検出なしは薄く、失敗は
/// 警告色。投稿のビューワーとプロフィール画像のビューワーで同じもの。(印は静止画: 回る輪だと終わらない処理の間
/// 画面が落ち着かず、テストの pumpAndSettle も終わらない。)
class ViewerPluginToggle extends StatelessWidget {
  const ViewerPluginToggle({super.key, required this.pluginId, required this.label, required this.enabled, required this.status, required this.onPressed});
  final String pluginId;
  final String label;
  final bool enabled;
  final ViewerPluginStatus status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final failed = enabled && status.phase == ViewerPluginPhase.failed;
    final asking = enabled && status.phase == ViewerPluginPhase.asking;
    final color = !enabled
        ? Colors.white
        : failed
            ? RasqTokens.of(context).danger
            : status.phase == ViewerPluginPhase.none
                ? Colors.white70
                : RasqColors.accent;
    final tip = enabled && status.label.isNotEmpty ? '$label — ${status.label}' : label;
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
      child: Stack(alignment: Alignment.center, children: [
        RasqIconButton(key: ValueKey('viewer.plugin.$pluginId'), icon: failed ? Icons.error_outline : (enabled ? Icons.extension : Icons.extension_outlined), color: color, tooltip: tip, onPressed: onPressed),
        if (asking) const Positioned(right: 4, bottom: 4, child: IgnorePointer(child: Icon(Icons.hourglass_top, size: 12, color: Colors.white))),
      ]),
    );
  }
}
