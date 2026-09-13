import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../plugins/slot_plugins.dart';
import 'viewer_plugins_screen.dart';

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

class ViewerPluginOverlays {
  ViewerPluginOverlays(this.ref, {required this.onChanged});
  final WidgetRef ref;

  /// 重ねが増えた / 差し替わった(setState を呼ぶ)。
  final VoidCallback onChanged;

  final Map<int, ViewerOverlay> _overlays = {};
  final Map<int, String> _tokens = {};

  ViewerOverlay? operator [](int i) => _overlays[i];

  /// [i] 番目の画像 [url] をプラグインへ渡す(登録が無い / 済みなら何もしない)。
  /// dispose では ref を使えない(Riverpod 3)ので、使った登録簿と対象プラグインを覚えておく。
  SlotPluginsNotifier? _notifier;
  final Map<String, SlotPlugin> _used = {};

  Future<void> ask(int i, Uri url) async {
    final plugins = ref.read(viewerOverlayPluginsProvider); // 有効なものだけ (D-205)
    if (plugins.isEmpty || _tokens.containsKey(i)) return;
    _notifier ??= ref.read(slotPluginsProvider.notifier);
    for (final p in plugins) {
      _used[p.id] = p;
    }
    final token = 'viewer-${identityHashCode(this)}-$i';
    _tokens[i] = token;
    Uint8List? bytes;
    var width = 0;
    var height = 0;
    try {
      final src = await ref.read(viewerImageFetcherProvider)(url);
      if (src != null) {
        final scaled = await downscalePng(src, 1024);
        bytes = scaled.$1;
        width = scaled.$2;
        height = scaled.$3;
      }
    } catch (e) {
      debugPrint('viewer overlay: fetch failed: $e');
    }
    if (_disposed || width == 0 || height == 0) return;
    for (final p in plugins) {
      final root = await _notifier!.viewerOpen(
        p,
        token: token,
        url: url.toString(),
        mimeType: 'image/png',
        width: width,
        height: height,
        bytes: bytes,
        onOverlay: (root) => _set(i, ViewerOverlay(root: root, width: width, height: height, plugin: p)),
      );
      if (root != null) _set(i, ViewerOverlay(root: root, width: width, height: height, plugin: p));
    }
  }

  void _set(int i, ViewerOverlay ov) {
    if (_disposed) return;
    _overlays[i] = ov;
    onChanged();
  }

  bool _disposed = false;

  /// 開いたトークンを全部閉じる(`viewer.close`)。
  void dispose() {
    _disposed = true;
    final notifier = _notifier;
    if (notifier == null) return;
    for (final e in _tokens.entries) {
      for (final p in _used.values) {
        notifier.viewerClose(p, e.value);
      }
    }
  }

  /// 画像の上に重ねる(画素座標 → 表示倍率はホストが合わせる)。重ねが無ければ [image] のまま。
  Widget wrap(int i, Widget image) {
    final ov = _overlays[i];
    if (ov == null) return image;
    final controller = ov.plugin.runtime.view;
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: ov.width.toDouble(),
        height: ov.height.toDouble(),
        child: Stack(fit: StackFit.expand, children: [
          image,
          RrlRenderer(
            node: ov.root,
            host: RrlHost(
              instanceScope: controller.document?.scope ?? ov.plugin.id,
              scope: RrlScope({}),
              geometry: controller.geometry,
              onEvent: (nodeId, kind, {fn, payload = const {}}) => controller.handleEvent(nodeId, kind, fn: fn, payload: payload),
            ),
          ),
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
