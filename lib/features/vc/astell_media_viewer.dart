import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import 'astell_models.dart';

/// 共有メディアの全画面表示 (D-145)。黒背景 + 画像(動画は ▶ の静止画。
/// 再生は M5 後段)。下段は**画像加工プラグインと同じ口**の並び — 保存 / 共有 /
/// プラグイン(メディアビューワープラグイン D-004 ③ はストア統合後)。
class AstellMediaViewer extends StatelessWidget {
  const AstellMediaViewer({super.key, required this.share});
  final AstellShare share;

  static Future<void> open(BuildContext context, AstellShare share) =>
      Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(fullscreenDialog: true, builder: (_) => AstellMediaViewer(share: share)));

  @override
  Widget build(BuildContext context) {
    final url = share.thumbnailUrl ?? share.url;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(share.headline, style: RasqTypography.title.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [RasqIconButton(icon: Icons.more_horiz, color: Colors.white, tooltip: 'メニュー', onPressed: () {})],
      ),
      body: Column(children: [
        Expanded(
          child: Center(
            child: Stack(alignment: Alignment.center, children: [
              if (url != null)
                InteractiveViewer(
                  child: Image.network(url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, size: 64, color: Colors.white54)),
                )
              else
                const Icon(Icons.insert_drive_file_outlined, size: 64, color: Colors.white54),
              if (share.isVideo) const Icon(Icons.play_circle_fill, size: 72, color: Colors.white70),
            ]),
          ),
        ),
        // 下段: 画像加工プラグインと同じ並び(左 = 編集系スロット、右 = 保存 / 共有)。
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.xs),
            child: Row(children: [
              RasqIconButton(icon: Icons.extension_outlined, color: Colors.white54, tooltip: 'メディアビューワープラグイン(ストア統合後)', onPressed: null),
              RasqIconButton(icon: Icons.crop_outlined, color: Colors.white54, tooltip: '加工(画像加工プラグイン)', onPressed: null),
              const Spacer(),
              Text('${share.authorName} が共有', style: RasqTypography.caption.copyWith(color: Colors.white70)),
              const Spacer(),
              RasqIconButton(icon: Icons.download_outlined, color: Colors.white, tooltip: '保存', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存は M5 後段で入ります')))),
              RasqIconButton(icon: Icons.ios_share, color: Colors.white, tooltip: '共有', onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('共有は M5 後段で入ります')))),
            ]),
          ),
        ),
      ]),
    );
  }
}
