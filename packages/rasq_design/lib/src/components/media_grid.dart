import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:rasq_models/rasq_models.dart';

import '../theme/rasq_tokens_extension.dart';
import '../tokens/colors.dart';
import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../platform/media_policy.dart';
import '../platform/media_image.dart';
import '../l10n/design_l10n.dart';

/// MediaGrid — layout auto-adjusts by count (1枚フル幅 / 2枚横並び / 3枚以上グリッド、
/// [maxVisible] を超える分は最後のタイルに「+N」。スレッド展開など全部見せたい所は
/// [maxVisible] を枚数以上にすると 2 列の行が続く、D-177),
/// media types may be mixed, and sensitive state is independent per tile.
///
/// Reveal state is ephemeral UI state, so it lives inside the widget
/// (emit/on scope); it is **not** business state and never reaches the store.
/// 全画面表示と揃えたいとき (D-510) は [revealed] / [onReveal] でホストが持つ(1 枚ずつ。1 枚を開いても他は開かない)。
class RasqMediaGrid extends StatefulWidget {
  const RasqMediaGrid({
    super.key,
    required this.items,
    this.onTapTile,
    this.onPlayTile,
    this.revealed,
    this.onReveal,
    this.maxVisible = 4,
    this.borderRadius = RasqSizes.radiusMd,
    this.singleAspectRatio = 16 / 9,
    this.gridAspectRatio = 1,
  });

  final List<MediaItem> items;

  /// Tap on a revealed tile (index into [items]).
  final ValueChanged<int>? onTapTile;

  /// 動画タイルの再生バッジ(インライン再生、D-201)。null ならバッジは飾り(タイルのタップと同じ)。
  final ValueChanged<int>? onPlayTile;

  /// 開いた(クッションを外した)タイルの [MediaItem.id]。null ならウィジェットの中で持つ。
  final Set<String>? revealed;

  /// タイルのクッションを外したとき([MediaItem.id])。[revealed] を渡すならこれも渡す。
  final ValueChanged<String>? onReveal;
  final int maxVisible;
  final double borderRadius;
  final double singleAspectRatio;
  final double gridAspectRatio;

  @override
  State<RasqMediaGrid> createState() => _RasqMediaGridState();
}

class _RasqMediaGridState extends State<RasqMediaGrid> {
  final Set<String> _revealed = {};

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final radius = BorderRadius.circular(widget.borderRadius);

    final visible = items.length > widget.maxVisible ? widget.maxVisible : items.length;
    Widget tile(int i) => _MediaTile(
          item: items[i],
          revealed: (widget.revealed ?? _revealed).contains(items[i].id),
          overflow: i == widget.maxVisible - 1 && items.length > widget.maxVisible ? items.length - widget.maxVisible : 0,
          onReveal: () {
            final id = items[i].id;
            if (widget.revealed == null) setState(() => _revealed.add(id));
            widget.onReveal?.call(id);
          },
          onTap: widget.onTapTile == null ? null : () => widget.onTapTile!(i),
          onPlay: widget.onPlayTile == null ? null : () => widget.onPlayTile!(i),
        );

    const gap = SizedBox.square(dimension: RasqSpacing.mediaGap);
    final Widget body = switch (visible) {
      1 => AspectRatio(aspectRatio: items.first.aspectRatio?.clamp(0.6, 2.2) ?? widget.singleAspectRatio, child: tile(0)),
      2 => AspectRatio(
          aspectRatio: widget.singleAspectRatio,
          child: Row(children: [Expanded(child: tile(0)), gap, Expanded(child: tile(1))]),
        ),
      3 => AspectRatio(
          aspectRatio: widget.singleAspectRatio,
          child: Row(children: [
            Expanded(child: tile(0)),
            gap,
            Expanded(child: Column(children: [Expanded(child: tile(1)), gap, Expanded(child: tile(2))])),
          ]),
        ),
      4 => AspectRatio(
          aspectRatio: widget.gridAspectRatio,
          child: Column(children: [
            Expanded(child: Row(children: [Expanded(child: tile(0)), gap, Expanded(child: tile(1))])),
            gap,
            Expanded(child: Row(children: [Expanded(child: tile(2)), gap, Expanded(child: tile(3))])),
          ]),
        ),
      // 5 枚以上を全部見せる (D-177): 2 列の行を枚数分(奇数なら最後は 1 枚で全幅)。
      _ => Column(children: [
          for (var r = 0; r * 2 < visible; r++) ...[
            if (r > 0) gap,
            AspectRatio(
              aspectRatio: widget.gridAspectRatio * 2,
              child: r * 2 + 1 < visible ? Row(children: [Expanded(child: tile(r * 2)), gap, Expanded(child: tile(r * 2 + 1))]) : tile(r * 2),
            ),
          ],
        ]),
    };
    return ClipRRect(borderRadius: radius, child: body);
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.item, required this.revealed, required this.overflow, required this.onReveal, this.onTap, this.onPlay});
  final VoidCallback? onPlay;

  final MediaItem item;
  final bool revealed;
  final int overflow;
  final VoidCallback onReveal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hidden = item.sensitive && !revealed;

    // プラグインの面では、その権限で読めない URL は読まない (D-407)。
    final thumb = item.thumbnailUrl ?? item.url;
    Widget content = switch (item.type) {
      MediaType.image || MediaType.gif || MediaType.video when !rasqMediaAllowed(context, thumb) =>
        ColoredBox(color: scheme.surfaceContainerHighest, child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant)),
      MediaType.image || MediaType.gif || MediaType.video => Image(
          image: rasqMediaImage(context, thumb),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest, child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant)),
        ),
      MediaType.file => ColoredBox(
          color: scheme.surfaceContainer,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.insert_drive_file_outlined, color: scheme.onSurfaceVariant, size: 32),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(item.fileName ?? item.url.pathSegments.lastOrNull ?? 'file', maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ),
            ]),
          ),
        ),
    };

    final overlays = <Widget>[Positioned.fill(child: content)];

    if (item.type == MediaType.video) {
      overlays.add(Center(
        child: onPlay == null
            ? const Icon(Icons.play_circle_fill, color: RasqColors.white, size: 48)
            : Semantics(button: true, label: context.designL10n.designMediaPlay, child: GestureDetector(key: ValueKey('media.play.${item.id}'), onTap: onPlay, child: const Icon(Icons.play_circle_fill, color: RasqColors.white, size: 48))),
      ));
      if (item.duration != null) {
        overlays.add(Positioned(right: 6, bottom: 6, child: _Chip(_fmt(item.duration!))));
      }
    }
    if (item.type == MediaType.gif) {
      overlays.add(const Positioned(left: 6, bottom: 6, child: _Chip('GIF')));
    }
    if (item.alt != null && item.alt!.isNotEmpty) {
      overlays.add(const Positioned(left: 6, top: 6, child: _Chip('ALT')));
    }
    if (overflow > 0) {
      overlays.add(Positioned.fill(
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.45),
          child: Center(child: Text('+$overflow', style: const TextStyle(color: RasqColors.white, fontSize: 24, fontWeight: FontWeight.w700))),
        ),
      ));
    }

    if (hidden) overlays.add(Positioned.fill(child: RasqSensitiveCushion(key: ValueKey('media.cushion.${item.id}'), onReveal: onReveal)));

    return Semantics(
      label: item.alt ?? (item.type == MediaType.file ? item.fileName : null),
      image: item.type != MediaType.file,
      button: onTap != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: hidden ? onReveal : onTap,
        child: Stack(fit: StackFit.expand, children: overlays),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(d.inHours > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }
}

/// センシティブ / CW のメディアに被せるクッション (D-510): ぼかし + 「センシティブな可能性のあるメディアです」+ 表示するボタン。
/// タイル(RasqMediaGrid)と全画面表示で同じもの。メディアの上に `Positioned.fill` で重ねる(背面をぼかす)。
/// [onReveal] が null なら外せない面(セーフモード / 見守り中で出さないメディア): 文言だけで、ボタンは無い。
class RasqSensitiveCushion extends StatelessWidget {
  const RasqSensitiveCushion({super.key, this.onReveal, this.large = false});
  final VoidCallback? onReveal;

  /// 全画面表示向け(文字とボタンを大きく)。
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = RasqTokens.of(context);
    final l = context.designL10n;
    final locked = onReveal == null;
    final cushion = ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: large ? 32 : 16, sigmaY: large ? 32 : 16),
        child: ColoredBox(
          color: tokens.sensitiveOverlay,
          child: Stack(children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (large) Icon(locked ? Icons.visibility_off_outlined : Icons.warning_amber_rounded, color: RasqColors.white, size: 40),
                  if (large) const SizedBox(height: 8),
                  Text(locked ? l.designMediaHidden : l.designMediaSensitive, textAlign: TextAlign.center, style: TextStyle(color: RasqColors.white, fontSize: large ? 15 : 12, fontWeight: FontWeight.w600)),
                  if (large && !locked) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onReveal,
                      icon: const Icon(Icons.visibility, color: RasqColors.white),
                      label: Text(l.designMediaReveal, style: const TextStyle(color: RasqColors.white)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: RasqColors.white), minimumSize: const Size(RasqSizes.minTap, RasqSizes.minTap)),
                    ),
                  ],
                ]),
              ),
            ),
            if (!large && !locked)
              Positioned(
                right: 4,
                bottom: 4,
                child: IconButton(
                  onPressed: onReveal,
                  icon: const Icon(Icons.visibility, color: RasqColors.white),
                  tooltip: l.designMediaReveal,
                  constraints: const BoxConstraints(minWidth: RasqSizes.minTap, minHeight: RasqSizes.minTap),
                ),
              ),
          ]),
        ),
      ),
    );
    // 全画面表示では面のどこを押しても開く(タイルはタイルの GestureDetector が開く)。
    return large && !locked ? GestureDetector(behavior: HitTestBehavior.opaque, onTap: onReveal, child: cushion) : cushion;
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
        child: Text(label, style: const TextStyle(color: RasqColors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
