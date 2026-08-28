import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// カスタム絵文字の共通表示 (D-040)。
///
/// **可変幅ルール**(絵文字ピッカー、本文インライン、リアクションタイル共通):
/// - 画像の幅が高さの 3 倍まで → **高さ固定・幅は画像なり**(可変)
/// - それ以上に横長 → **幅を高さの 2 倍に固定**(contain で縮む)
///
/// ホバー(デスクトップ)/ 長押し(モバイル)で**チップ**を出す:
/// 名前の左横に絵文字、横長の絵文字なら名前の上に表示する。
class RasqCustomEmoji extends StatefulWidget {
  const RasqCustomEmoji({super.key, this.url, required this.fallbackText, required this.height, this.name, this.semanticLabel, this.chipDetail});

  /// 画像 URL(null = [fallbackText] をテキスト表示)。
  final Uri? url;

  /// 画像が無い/壊れているときのテキスト(Unicode 絵文字 or `:name:`)。
  final String fallbackText;
  final double height;

  /// チップに出す名前(null = チップなし)。
  final String? name;
  final String? semanticLabel;

  /// チップの追加行(リアクションしたユーザーの名前とアイコン等、D-042)。
  /// チップ表示中だけ build される。
  final WidgetBuilder? chipDetail;

  /// 可変幅ルール: アスペクト比 3 まで幅可変、超えたら幅 2×高さで固定。
  static double displayWidth(double aspect, double height) => aspect <= 3 ? height * aspect : height * 2;

  @override
  State<RasqCustomEmoji> createState() => _RasqCustomEmojiState();
}

class _RasqCustomEmojiState extends State<RasqCustomEmoji> {
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;
  final _chip = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(RasqCustomEmoji old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _aspect = null;
      _unlisten();
      _resolve();
    }
  }

  void _resolve() {
    final url = widget.url;
    if (url == null) return;
    final stream = NetworkImage(url.toString()).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      if (mounted) setState(() => _aspect = info.image.width / info.image.height);
    }, onError: (_, _) {});
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _unlisten() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _unlisten();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url;
    final Widget emoji;
    if (url == null) {
      emoji = Text(widget.fallbackText, style: TextStyle(fontSize: widget.height * 0.85), semanticsLabel: widget.semanticLabel);
    } else if (_aspect == null) {
      // 実寸解決前: 高さ固定・幅は画像なり(fitHeight)で即表示し、上限 3×h
      // だけ constraints で掛ける。以前の「正方形 + contain」はロング絵文字が
      // 数 px にレタボ化されて見えなくなっていた (D-041)。
      emoji = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.height * 3, maxHeight: widget.height),
        child: Image.network(
          url.toString(),
          height: widget.height,
          fit: BoxFit.fitHeight,
          semanticLabel: widget.semanticLabel ?? widget.name,
          errorBuilder: (_, _, _) => Text(widget.fallbackText, style: TextStyle(fontSize: widget.height * 0.6)),
        ),
      );
    } else {
      emoji = SizedBox(
        width: RasqCustomEmoji.displayWidth(_aspect!, widget.height),
        height: widget.height,
        child: Image.network(
          url.toString(),
          fit: BoxFit.contain,
          semanticLabel: widget.semanticLabel ?? widget.name,
          errorBuilder: (_, _, _) => FittedBox(child: Text(widget.fallbackText)),
        ),
      );
    }
    if (widget.name == null) return emoji;
    return OverlayPortal(
      controller: _chip,
      overlayChildBuilder: (context) => _EmojiChip(anchorContext: context, target: this),
      child: MouseRegion(
        onEnter: (_) => _chip.show(),
        onExit: (_) => _chip.hide(),
        child: GestureDetector(
          onLongPress: () {
            _chip.show();
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted && _chip.isShowing) _chip.hide();
            });
          },
          child: emoji,
        ),
      ),
    );
  }
}

/// ホバー/長押しチップ: 名前の左横に絵文字(横長なら名前の上)。
class _EmojiChip extends StatelessWidget {
  const _EmojiChip({required this.anchorContext, required this.target});
  final BuildContext anchorContext;
  final _RasqTargetState target;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = target.widget;
    final box = target.context.findRenderObject() as RenderBox?;
    final origin = box == null ? Offset.zero : box.localToGlobal(Offset.zero);
    final wide = (target._aspect ?? 1.0) > 1.5;
    const chipEmojiHeight = 28.0;
    final emoji = w.url == null
        ? Text(w.fallbackText, style: const TextStyle(fontSize: 24))
        : SizedBox(
            width: RasqCustomEmoji.displayWidth(target._aspect ?? 1.0, chipEmojiHeight),
            height: chipEmojiHeight,
            child: Image.network(w.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => Text(w.fallbackText)),
          );
    final name = Text(w.name!, style: RasqTypography.caption.copyWith(color: scheme.onInverseSurface));
    final detail = w.chipDetail?.call(context);
    return Positioned(
      left: origin.dx,
      top: origin.dy - (wide ? 64 : 40) - (detail == null ? 0 : 24),
      child: Material(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 4),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (wide) ...[emoji, const SizedBox(height: 2), name] else Row(mainAxisSize: MainAxisSize.min, children: [emoji, const SizedBox(width: RasqSpacing.sm), name]),
            // リアクションしたユーザー等の追加行 (D-042)。
            ?detail,
          ]),
        ),
      ),
    );
  }
}

typedef _RasqTargetState = _RasqCustomEmojiState;
