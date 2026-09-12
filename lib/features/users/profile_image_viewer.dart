import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../media/viewer_plugin_overlay.dart';

/// プロフィールのアイコン / バナーの全画面表示 (D-177)。黒背景 + ピンチズーム、
/// タップで戻るボタンの表示切り替え。投稿のビューワー(`MediaViewerScreen`)と違い
/// アクションバーや本文は無いが、全画面表示プラグイン(`viewer.overlay`)は同じく重なる (D-178)。
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
              child: _overlays.wrap(0, Image.network(widget.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48))),
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
                if (widget.title != null) ...[
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(child: Text(widget.title!, style: RasqTypography.title.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis)),
                ],
              ]),
            ),
          ),
      ]),
    );
  }
}
