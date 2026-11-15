import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show HitTestResult;
import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';
import 'media_file_pick.dart';

/// 他のアプリからコンポーザーへメディアを落とす (D-555)。
///
/// - 受け口は desktop_drop の [DropTarget](macOS / Web / Windows / Linux / Android)。iPadOS は ios/Runner/MediaDropBridge.swift が
///   同じ口で話す(desktop_drop 0.8 には iOS が無い)。
/// - 重なっているコンポーザー(ページ常駐の stick の上に開いた FOW のコンポーザーなど)は、**落とした位置でいちばん上に
///   描かれているもの**だけが受ける(desktop_drop は重なりを見ないので、位置で当たり判定をする)。
/// - 添付の上限・種類は、ボタンから選ぶときと同じ([planMediaDrop])。

/// 落としたファイル 1 つ。
@immutable
class DroppedMediaFile {
  const DroppedMediaFile({required this.name, required this.read, this.mimeType});
  final String name;

  /// 渡してきた側の MIME(無いことが多い)。
  final String? mimeType;
  final Future<Uint8List> Function() read;
}

/// 画像の拡張子 → MIME(ドロップは MIME が付かないことが多い。デスクトップの Finder など)。
const _imageMime = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'avif': 'image/avif',
  'bmp': 'image/bmp',
};

/// 添付にできるメディアの MIME(画像 / 動画 / 音声)。メディアでなければ null。
String? droppedMediaMime(String name, {String? reported}) {
  if (reported != null && reported.startsWith('image/')) return reported;
  final av = mediaMimeFor(name, reported: reported);
  if (av != null) return av;
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  return _imageMime[name.substring(dot + 1).toLowerCase()];
}

/// 落としたものの振り分け。
@immutable
class MediaDropPlan {
  const MediaDropPlan({required this.accepted, required this.notMedia, required this.overLimit});

  /// 添付に入れるもの(落とした順)と、その MIME。
  final List<(DroppedMediaFile, String)> accepted;

  /// メディアではないので入れないもの(名前)。
  final List<String> notMedia;

  /// 上限を超えたので入れなかった数(メディアのうち)。
  final int overLimit;
}

/// [current] 件付いているコンポーザーに、上限 [max] 件で落としたときの振り分け。先に落としたものから入る。
MediaDropPlan planMediaDrop(List<DroppedMediaFile> files, {required int current, required int max}) {
  final accepted = <(DroppedMediaFile, String)>[];
  final notMedia = <String>[];
  var over = 0;
  for (final f in files) {
    final mime = droppedMediaMime(f.name, reported: f.mimeType);
    if (mime == null) {
      notMedia.add(f.name);
    } else if (current + accepted.length >= max) {
      over++;
    } else {
      accepted.add((f, mime));
    }
  }
  return MediaDropPlan(accepted: accepted, notMedia: notMedia, overLimit: over);
}

/// コンポーザーの上に落とせるようにする枠。ホバー中は枠と案内を重ねる。
class ComposerMediaDropTarget extends StatefulWidget {
  const ComposerMediaDropTarget({super.key, required this.child, required this.onDrop, required this.remaining, required this.max, this.blockedReason, this.enabled = true});
  final Widget child;
  final ValueChanged<List<DroppedMediaFile>> onDrop;

  /// あと何件付けられるか。
  final int remaining;
  final int max;

  /// 付けられない理由(RASQ の文字だけの返信など)。あれば、ホバー中にこれを出し、落としても受けない。
  final String? blockedReason;

  /// false = 受けない(送っている間 / 前に別の画面が重なっている間)。
  final bool enabled;

  @override
  State<ComposerMediaDropTarget> createState() => _ComposerMediaDropTargetState();
}

class _ComposerMediaDropTargetState extends State<ComposerMediaDropTarget> {
  final _marker = GlobalKey();
  bool _hover = false;

  /// 位置 [global] で、いちばん上に描かれているのがこの枠の中か(上に FOW などが重なっていれば false)。
  bool _onTop(Offset global) {
    final box = _marker.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return false;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, global, View.of(context).viewId);
    for (final e in result.path) {
      // いちばん上(先頭)から見て、この枠より先に「指を止めるもの」(FOW のバリアなど、別の部品の根)があっても、
      // 経路にこの枠が入っていれば、その部品はこの枠の中にある。
      if (identical(e.target, box)) return true;
    }
    return false;
  }

  void _setHover(bool v) {
    if (_hover != v && mounted) setState(() => _hover = v);
  }

  Future<void> _done(DropDoneDetails d) async {
    _setHover(false);
    if (!_onTop(d.globalPosition)) return;
    final files = <DroppedMediaFile>[];
    for (final item in d.files) {
      if (item is DropItemDirectory) {
        files.add(DroppedMediaFile(name: item.name, read: () async => Uint8List(0)));
        continue;
      }
      final bookmark = item.extraAppleBookmark;
      files.add(DroppedMediaFile(
        name: item.name,
        mimeType: item.mimeType,
        read: () async {
          // macOS の砂場 (D-555): アプリの外から落としたファイルは、ブックマークで読む許しを取ってから読む。
          final scoped = !kIsWeb && bookmark != null && bookmark.isNotEmpty && await DesktopDrop.instance.startAccessingSecurityScopedResource(bookmark: bookmark);
          try {
            return await item.readAsBytes();
          } finally {
            if (scoped) await DesktopDrop.instance.stopAccessingSecurityScopedResource(bookmark: bookmark);
          }
        },
      ));
    }
    if (files.isNotEmpty && widget.blockedReason == null) widget.onDrop(files);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = context.l10n;
    final blocked = widget.blockedReason;
    final full = widget.remaining <= 0;
    final ok = blocked == null && !full;
    final message = blocked ?? (full ? l.composeDropFull(widget.max) : l.composeDropHint(widget.remaining));
    final color = ok ? scheme.primary : scheme.error;
    return DropTarget(
      enable: widget.enabled,
      onDragEntered: (d) => _setHover(_onTop(d.globalPosition)),
      onDragUpdated: (d) => _setHover(_onTop(d.globalPosition)),
      onDragExited: (_) => _setHover(false),
      onDragDone: _done,
      child: Stack(children: [
        // 当たり判定の印(この中に当たれば、このコンポーザーが前にある)。
        Listener(key: _marker, behavior: HitTestBehavior.translucent, child: widget.child),
        if (_hover)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                key: const ValueKey('composer.drop.hover'),
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  border: Border.all(color: color, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
                  decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: color)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(ok ? Icons.add_photo_alternate_outlined : Icons.block, size: 18, color: color),
                    const SizedBox(width: 6),
                    Flexible(child: Text(message, key: const ValueKey('composer.drop.message'), style: RasqTypography.bodySmall.copyWith(color: color))),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}
