
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import 'viewer_plugin_overlay.dart';

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

  /// 全画面表示プラグイン (D-167 / D-178 で共通化): 画像ごとの重ねとトークン。
  late final ViewerPluginOverlays _overlays = ViewerPluginOverlays(ref, onChanged: () {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askOverlay(_index));
  }

  @override
  void dispose() {
    _overlays.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _askOverlay(int i) {
    if (i >= widget.post.media.length) return;
    final m = widget.post.media[i];
    if (m.type != MediaType.image && m.type != MediaType.gif) return;
    _overlays.ask(i, m.url);
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
                      : _overlays.wrap(i, Image.network(m.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48))),
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

