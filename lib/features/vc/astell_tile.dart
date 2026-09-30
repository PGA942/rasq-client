import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import 'astell_models.dart';

/// VC タイル (D-139、ワイヤーフレーム p.3 グローバル VC ホーム)。
///
/// グループアバター(ホスト + `+N`)/ ホスト名 / タイトル / … / ざっくり要約
/// (または「デスクリプションが提供されていません。」)/ ジャンル(青字の行)/
/// LIVE ならバッジ + サムネイル / 「見てみる」。
class AstellTile extends StatelessWidget {
  const AstellTile({super.key, required this.room, this.onOpen, this.onMore, this.openLabel = '見てみる', this.bookmarked = false, this.onBookmark, this.reminded = false, this.onRemind});
  final AstellRoom room;
  final VoidCallback? onOpen;
  final ValueChanged<Rect>? onMore;

  /// 下のボタンの文言 (D-160): 参加中のルームなら「戻る」。
  final String openLabel;

  /// ブックマーク (D-160)。[onBookmark] が null なら出さない。
  final bool bookmarked;
  final VoidCallback? onBookmark;

  /// 開始通知 (D-160)。開催予定のあるルームだけ [onRemind] が入る。
  final bool reminded;
  final VoidCallback? onRemind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    // 高さの決まらない所(縦のリストに直など)に置かれても壊れないように (D-376): 中は Expanded で詰めるので、既定の高さを与える。
    return LayoutBuilder(builder: (context, c) {
      final wide = !c.hasBoundedWidth || c.maxWidth >= roomyWidth;
      return c.hasBoundedHeight ? _tile(scheme, tokens, wide) : SizedBox(height: defaultHeight, child: _tile(scheme, tokens, wide));
    });
  }

  /// 高さが決まらない所での既定(TL の投稿内のタイルと同じ)。
  static const defaultHeight = 216.0;

  /// タイルの最小幅 (D-386)。横並び([AstellTileStrip])はこれより細くしない。
  static const minWidth = 220.0;

  /// この幅から、ブックマークのボタンと 3 人目の顔を出す (D-386)。細いタイルでは見出しが詰まるので出さない。
  static const roomyWidth = 300.0;

  /// アイコン(バンドル)の大きさ (D-386: 30 → 36、2 割大きく)。
  static const bundleSize = 36.0;

  Widget _tile(ColorScheme scheme, RasqTokens tokens, bool wide) {
    final onBookmark = wide ? this.onBookmark : null;
    final faces = wide || room.bundleFaces.length <= 2 ? room.bundleFaces : room.bundleFaces.take(2).toList();
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
        gradient: LinearGradient(
          colors: [RasqColors.lightBlue.withValues(alpha: 0.35), RasqColors.main.withValues(alpha: 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 見出し行: バンドル + ホスト名/タイトル、… は右上に重ねる(行幅を食わない)。
        // タイルは最小 220px (D-386)、バンドルは 36px 基準。
        Stack(clipBehavior: Clip.none, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // アイコン&追加情報バンドル (D-140): 角丸ワイヤー + 円形アイコン + 人数 + LIVE。
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: RasqAvatarBundle(user: room.owner, count: room.peerCount, faces: faces, live: room.live, size: bundleSize),
            ),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: 18.0 * ((onMore != null ? 1 : 0) + (onBookmark != null ? 1 : 0) + (onRemind != null ? 1 : 0))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(room.ownerDisplayName, style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(room.title, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                ]),
              ),
            ),
          ]),
          // 右上: ブックマーク / 開始通知 / … を横並び (D-162: … の横に置く)。
          if (onMore != null || onBookmark != null || onRemind != null)
            Positioned(
              top: -10,
              right: -10,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (onBookmark != null)
                  RasqIconButton(key: const ValueKey('astell.tile.bookmark'), icon: bookmarked ? Icons.bookmark : Icons.bookmark_border, size: 16, color: bookmarked ? RasqColors.accent : null, tooltip: bookmarked ? 'ブックマークから削除' : 'ブックマークに保存', onPressed: onBookmark),
                if (onRemind != null)
                  RasqIconButton(key: const ValueKey('astell.tile.remind'), icon: reminded ? Icons.notifications_active : Icons.notifications_none, size: 16, color: reminded ? RasqColors.accent : null, tooltip: reminded ? '開始通知を解除' : '開始を通知', onPressed: onRemind),
                if (onMore != null)
                  Builder(
                    builder: (ctx) => RasqIconButton(
                      icon: Icons.more_horiz,
                      size: 16,
                      tooltip: 'メニュー',
                      onPressed: () {
                        final box = ctx.findRenderObject() as RenderBox;
                        onMore!(box.localToGlobal(Offset.zero) & box.size);
                      },
                    ),
                  ),
              ]),
            ),
        ]),
        const SizedBox(height: RasqSpacing.xs),
        Expanded(
          child: room.live && room.thumbnailUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(webHtmlElementStrategy: rasqWebImageStrategy, room.thumbnailUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
                    Positioned(left: 4, right: 4, bottom: 4, child: _Genres(genres: room.genres, color: Colors.white)),
                  ]),
                )
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // 開催予定 (D-159): 要約の上に時刻。
                  if (room.isScheduled)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(children: [
                        Icon(Icons.schedule, size: 12, color: tokens.link),
                        const SizedBox(width: 2),
                        Expanded(child: Text('開催予定 ${_schedule(room.scheduledAt!)}', style: RasqTypography.caption.copyWith(color: tokens.link, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  Expanded(
                    child: Text(
                      room.showSummary ? room.summaryText : 'ざっくり要約は非公開です。',
                      style: RasqTypography.caption.copyWith(height: 1.4, color: room.description.isEmpty || !room.showSummary ? scheme.onSurfaceVariant : scheme.onSurface),
                      textAlign: room.description.isEmpty ? TextAlign.center : TextAlign.start,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                  _Genres(genres: room.genres, color: tokens.link),
                ]),
        ),
        const SizedBox(height: RasqSpacing.xs),
        RasqGradientButton(label: openLabel, onPressed: onOpen, height: 36),
      ]),
    );
  }
}

String _schedule(DateTime at) {
  final l = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.month}/${l.day} ${two(l.hour)}:${two(l.minute)}';
}

class _Genres extends StatelessWidget {
  const _Genres({required this.genres, required this.color});
  final List<String> genres;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) return const SizedBox.shrink();
    return Text(genres.take(4).join('   '), style: RasqTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// タイルの横並び(2 枚 + 右端に次が覗く)。
class AstellTileStrip extends StatefulWidget {
  const AstellTileStrip({super.key, required this.rooms, this.onOpen, this.onMore, this.tileBuilder, this.height = 236, this.emptyHint});
  final List<AstellRoom> rooms;
  final void Function(AstellRoom room)? onOpen;
  final void Function(AstellRoom room, Rect anchor)? onMore;

  /// タイルを差し替える(ブックマーク/通知を配線した `AstellRoomTile` など、D-160)。
  final Widget Function(AstellRoom room)? tileBuilder;
  final double height;
  final String? emptyHint;

  @override
  State<AstellTileStrip> createState() => _AstellTileStripState();
}

class _AstellTileStripState extends State<AstellTileStrip> {
  /// タイル 1 枚の最大幅 (D-142)。タブレットで横に伸びすぎないように。
  static const maxTileWidth = 600.0;
  PageController? _controller;
  double _fraction = 0.54;

  PageController _controllerFor(double width) {
    // 1 枚 = 幅の 54%(次が覗く)。ただし最小 [AstellTile.minWidth](D-386)/ 最大 [maxTileWidth]。狭い画面でも右端に次が少し覗くように 0.92 まで。
    final tile = (width * 0.54).clamp(AstellTile.minWidth, maxTileWidth);
    final fraction = width <= 0 ? 0.54 : (tile / width).clamp(0.2, 0.92);
    if (_controller == null || (fraction - _fraction).abs() > 0.001) {
      _controller?.dispose();
      _fraction = fraction;
      _controller = PageController(viewportFraction: fraction);
    }
    return _controller!;
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.rooms.isEmpty) {
      return SizedBox(
        height: 72,
        child: Center(child: Text(widget.emptyHint ?? 'VC はまだありません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
      );
    }
    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) => PageView.builder(
        controller: _controllerFor(constraints.maxWidth),
        padEnds: false,
        itemCount: widget.rooms.length,
        itemBuilder: (_, i) {
          final room = widget.rooms[i];
          return Padding(
            padding: const EdgeInsets.only(left: RasqSpacing.sm, right: RasqSpacing.xs, top: RasqSpacing.xs, bottom: RasqSpacing.xs),
            child: widget.tileBuilder?.call(room) ?? AstellTile(room: room, onOpen: widget.onOpen == null ? null : () => widget.onOpen!(room), onMore: widget.onMore == null ? null : (rect) => widget.onMore!(room, rect)),
          );
        },
        ),
      ),
    );
  }
}
