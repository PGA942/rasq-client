import 'package:flutter/material.dart';

import '../tokens/spacing.dart';
import '../tokens/typography.dart';
import '../platform/media_policy.dart';
import '../platform/web_image.dart';

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

  /// この面で [RasqCustomEmoji.url] を読んでよいか (D-407、[RasqMediaPolicyScope])。だめなら通信せず [fallbackText]。
  bool _allowed = false;
  Uri? _syncedUrl;
  bool _synced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(RasqCustomEmoji old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _sync();
  }

  void _sync() {
    final allowed = rasqMediaAllowed(context, widget.url);
    if (_synced && allowed == _allowed && _syncedUrl == widget.url) return;
    _synced = true;
    _allowed = allowed;
    _syncedUrl = widget.url;
    _aspect = null;
    _unlisten();
    if (allowed) _resolve();
  }

  void _resolve() {
    final url = widget.url;
    if (url == null) return;
    final stream = NetworkImage(url.toString(), webHtmlElementStrategy: rasqWebImageStrategy).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      // Web 版で `<img>` として読めた絵 (D-298) は、`image` を持たない(触ると例外)。そのときは実寸なしのまま(高さ固定で出る)。
      try {
        final aspect = info.image.width / info.image.height;
        if (mounted) setState(() => _aspect = aspect);
      } catch (_) {}
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
    final url = _allowed ? widget.url : null;
    final Widget emoji;
    if (url == null) {
      emoji = Text(widget.fallbackText, style: TextStyle(fontSize: widget.height * 0.85), semanticsLabel: widget.semanticLabel);
    } else if (_aspect == null) {
      // 実寸解決前: 高さ固定・幅は画像なり(fitHeight)で即表示し、上限 3×h
      // だけ constraints で掛ける。以前の「正方形 + contain」はロング絵文字が
      // 数 px にレタボ化されて見えなくなっていた (D-041)。
      emoji = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.height * 3, maxHeight: widget.height),
        child: Image.network(webHtmlElementStrategy: rasqWebImageStrategy, 
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
        child: Image.network(webHtmlElementStrategy: rasqWebImageStrategy, 
          url.toString(),
          fit: BoxFit.contain,
          semanticLabel: widget.semanticLabel ?? widget.name,
          errorBuilder: (_, _, _) => FittedBox(child: Text(widget.fallbackText)),
        ),
      );
    }
    if (widget.name == null) return emoji;
    // ホバー / 長押しチップ (D-211): OverlayPortal は、出したまま画面が下(オフステージ)に回ると
    // レイアウト前の箱がヒットテストされて落ち、以後マウスが効かなくなった(実機)。Tooltip は
    // Overlay の通常の子として毎フレーム配置されるので安全。
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      richMessage: WidgetSpan(child: _EmojiChip(target: this)),
      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 4),
      preferBelow: false,
      triggerMode: TooltipTriggerMode.longPress,
      showDuration: const Duration(seconds: 2),
      waitDuration: Duration.zero,
      child: emoji,
    );
  }
}

/// ホバー/長押しチップの中身: 名前の左横に絵文字(横長なら名前の上)。
class _EmojiChip extends StatelessWidget {
  const _EmojiChip({required this.target});
  final _RasqTargetState target;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = target.widget;
    final wide = (target._aspect ?? 1.0) > 1.5;
    const chipEmojiHeight = 28.0;
    final emoji = w.url == null || !target._allowed
        ? Text(w.fallbackText, style: const TextStyle(fontSize: 24))
        : SizedBox(
            width: RasqCustomEmoji.displayWidth(target._aspect ?? 1.0, chipEmojiHeight),
            height: chipEmojiHeight,
            child: Image.network(webHtmlElementStrategy: rasqWebImageStrategy, w.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => Text(w.fallbackText)),
          );
    final name = Text(w.name!, style: RasqTypography.caption.copyWith(color: scheme.onInverseSurface));
    final detail = w.chipDetail?.call(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (wide) ...[emoji, const SizedBox(height: 2), name] else Row(mainAxisSize: MainAxisSize.min, children: [emoji, const SizedBox(width: RasqSpacing.sm), name]),
      // リアクションしたユーザー等の追加行 (D-042)。
      ?detail,
    ]);
  }
}

typedef _RasqTargetState = _RasqCustomEmojiState;
