import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../plugins/slot_plugins.dart';

/// 全画面表示(画像/動画): 黒背景、PageView、戻る/…、下部アクションバー、本文.
/// `…` → 「オーバーレイに移動」(動画のみ、VC・動画オーバーレイへ昇格 = M5 以降).
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({super.key, required this.post, this.initialIndex = 0});
  final Post post;
  final int initialIndex;
  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  late final PageController _ctrl = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  bool _chrome = true;

  /// 全画面表示プラグイン (D-167、スロット `viewer.overlay`): 画像ごとの重ね
  /// (RRL、座標は渡した画素数)とトークン。
  final Map<int, _Overlay> _overlays = {};
  final Map<int, String> _tokens = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askOverlay(_index));
  }

  @override
  void dispose() {
    for (final e in _tokens.entries) {
      for (final p in ref.read(slotPluginsForProvider(SlotIds.viewerOverlay))) {
        ref.read(slotPluginsProvider.notifier).viewerClose(p, e.value);
      }
    }
    _ctrl.dispose();
    super.dispose();
  }

  /// 画像本体を(長辺 1024 に縮めて)プラグインへ渡し、重ねる RRL をもらう。
  Future<void> _askOverlay(int i) async {
    final plugins = ref.read(slotPluginsForProvider(SlotIds.viewerOverlay));
    if (plugins.isEmpty || _tokens.containsKey(i) || i >= widget.post.media.length) return;
    final m = widget.post.media[i];
    if (m.type != MediaType.image && m.type != MediaType.gif) return;
    final token = 'viewer-${identityHashCode(this)}-$i';
    _tokens[i] = token;
    Uint8List? bytes;
    var width = m.width ?? 0;
    var height = m.height ?? 0;
    try {
      final res = await http.get(m.url).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final scaled = await _downscalePng(res.bodyBytes, 1024);
        bytes = scaled.$1;
        width = scaled.$2;
        height = scaled.$3;
      }
    } catch (e) {
      debugPrint('viewer overlay: fetch failed: $e');
    }
    if (!mounted || width == 0 || height == 0) return;
    for (final p in plugins) {
      final root = await ref.read(slotPluginsProvider.notifier).viewerOpen(
        p,
        token: token,
        url: m.url.toString(),
        mimeType: 'image/png',
        width: width,
        height: height,
        bytes: bytes,
        onOverlay: (root) {
          if (mounted) setState(() => _overlays[i] = _Overlay(root: root, width: width, height: height, plugin: p));
        },
      );
      if (root != null && mounted) setState(() => _overlays[i] = _Overlay(root: root, width: width, height: height, plugin: p));
    }
  }

  /// 長辺 [max] に縮めた PNG と画素数。
  static Future<(Uint8List, int, int)> _downscalePng(Uint8List src, int max) async {
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

  /// 画像の上に重ねる(画素座標 → 表示倍率はホストが合わせる)。
  Widget _withOverlay(int i, Widget image) {
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

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    final manager = ref.watch(overlayManagerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        GestureDetector(
          onTap: () => setState(() => _chrome = !_chrome),
          child: PageView.builder(
            controller: _ctrl,
            itemCount: post.media.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _askOverlay(i);
            },
            itemBuilder: (_, i) {
              final m = post.media[i];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: m.type == MediaType.file
                      ? Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 64), Text(m.fileName ?? '', style: const TextStyle(color: Colors.white))])
                      : _withOverlay(i, Image.network(m.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48))),
                ),
              );
            },
          ),
        ),
        if (_chrome) ...[
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(RasqSpacing.sm),
              child: Row(children: [
                _Circle(child: RasqIconButton(icon: Icons.arrow_back_ios_new, size: 18, color: Colors.white, onPressed: () => Navigator.of(context).maybePop(), tooltip: '戻る')),
                const Spacer(),
                if (post.media.length > 1) Text('${_index + 1} / ${post.media.length}', style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                Builder(
                  builder: (ctx) => _Circle(
                    child: RasqIconButton(
                      icon: Icons.more_horiz,
                      color: Colors.white,
                      tooltip: 'メニュー',
                      onPressed: () async {
                        final box = ctx.findRenderObject() as RenderBox;
                        final rect = box.localToGlobal(Offset.zero) & box.size;
                        final m = post.media[_index];
                        await manager.showDropdown<String>(id: 'viewer.menu', anchor: rect, items: [
                          const RasqDropdownItem('リンクをコピー', 'copy'),
                          if (m.type == MediaType.video) const RasqDropdownItem('オーバーレイに移動', 'pip'),
                          if (m.alt != null) const RasqDropdownItem('ALTを表示', 'alt'),
                        ]);
                      },
                    ),
                  ),
                ),
              ]),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
              child: SafeArea(
                top: false,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Theme(
                    data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme.copyWith(onSurface: Colors.white, onSurfaceVariant: Colors.white70)),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      for (final a in actions)
                        RasqActionButton.icon(icon: PostRow.iconFor(a.icon, Icons.circle_outlined), doneIcon: a.doneIcon == null ? null : PostRow.iconFor(a.doneIcon, Icons.circle), tooltip: a.label, onTap: () => notifier.perform(post, a).catchError((_) {})),
                      RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {}),
                    ]),
                  ),
                  if (post.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.md),
                      child: RasqRichText(InlineSpans.parse(post.body), style: RasqTypography.bodySmall.copyWith(color: Colors.white), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle), child: child);
}

class _Overlay {
  const _Overlay({required this.root, required this.width, required this.height, required this.plugin});
  final RrlNode root;
  final int width;
  final int height;
  final SlotPlugin plugin;
}
