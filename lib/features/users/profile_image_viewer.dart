import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../home/plugin_actions.dart';
import '../media/viewer_plugin_overlay.dart';

/// プロフィールのアイコン / バナーの全画面表示 (D-177)。黒背景 + ピンチズーム、
/// タップでヘッダーの表示切り替え。投稿のビューワー(`MediaViewerScreen`)と違い本文や投稿のアクションは無いが、
/// 全画面表示プラグイン(`viewer.overlay`)は同じく重なり (D-178)、**全画面アクションバー**(プラグインのトグル)も
/// ヘッダーの右に出る (D-246。投稿が無いので SNS のアクションボタンは並ばない)。
class ProfileImageViewerScreen extends ConsumerStatefulWidget {
  const ProfileImageViewerScreen({super.key, required this.url, this.title});
  final Uri url;
  final String? title;

  @override
  ConsumerState<ProfileImageViewerScreen> createState() => _ProfileImageViewerScreenState();
}

class _ProfileImageViewerScreenState extends ConsumerState<ProfileImageViewerScreen> {
  bool _chrome = true;
  late final ViewerPluginOverlays _overlays = ViewerPluginOverlays(ref, onChanged: () {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _overlays.ask(0, widget.url));
  }

  @override
  void dispose() {
    _overlays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _chrome = !_chrome),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: _overlays.wrap(0, Image.network(webHtmlElementStrategy: rasqWebImageStrategy, widget.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48))),
            ),
          ),
        ),
        if (_chrome)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(RasqSpacing.sm),
              child: Row(children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                  child: RasqIconButton(icon: Icons.arrow_back_ios_new, size: 18, color: Colors.white, onPressed: () => Navigator.of(context).maybePop(), tooltip: '戻る'),
                ),
                const SizedBox(width: RasqSpacing.sm),
                Expanded(child: Text(widget.title ?? '', style: RasqTypography.title.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis)),
                // 全画面アクションバー (D-246): 全画面表示プラグインのトグル。狭ければ横スクロール(右寄せ)。
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final a in ref.watch(viewerPluginActionsProvider)) ...[
                        const SizedBox(width: 2),
                        ViewerPluginToggle(
                          pluginId: a.plugin.id,
                          label: a.decl.label,
                          iconName: a.decl.icon,
                          enabled: ref.watch(viewerOverlayPluginsProvider).any((p) => p.id == a.plugin.id),
                          status: _overlays.statusOf(0, a.plugin.id),
                          onPressed: () => _overlays.toggle(a.plugin.id, 0, widget.url),
                        ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
