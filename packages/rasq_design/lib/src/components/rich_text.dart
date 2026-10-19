import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/rasq_tokens_extension.dart';
import 'custom_emoji.dart';
import 'mfm.dart';
import '../platform/media_policy.dart';
import '../platform/media_image.dart';

/// Inline span model for RSL (RASQ Subassembly Language) output.
///
/// The renderer parses body text (plain / MFM / HTML) into a list of
/// [RasqSpan]s; this widget only draws them. Interactive spans are allowed for
/// store-reviewed plugins (旧D2 A案); sideloaded content must be non-interactive
/// — enforcement happens in the renderer's validation gate, not here.
sealed class RasqSpan {
  const RasqSpan();
}

class RasqTextSpan extends RasqSpan {
  const RasqTextSpan(this.text, {this.bold = false, this.italic = false, this.strike = false, this.small = false, this.code = false});
  final String text;
  final bool bold;
  final bool italic;
  final bool strike;
  final bool small;

  /// `` `inline code` `` — monospace + 薄い背景。
  final bool code;

  RasqTextSpan copyWith({bool? bold, bool? italic, bool? strike, bool? small, bool? code}) =>
      RasqTextSpan(text, bold: bold ?? this.bold, italic: italic ?? this.italic, strike: strike ?? this.strike, small: small ?? this.small, code: code ?? this.code);
}

/// Custom emoji rendered inline at text height.
class RasqEmojiSpan extends RasqSpan {
  const RasqEmojiSpan({required this.shortcode, this.url});
  final String shortcode;
  final Uri? url;
}

/// Arbitrary inline image (e.g. badge images inside display names).
class RasqInlineImageSpan extends RasqSpan {
  const RasqInlineImageSpan(this.url, {this.height = 18, this.alt});
  final Uri url;
  final double height;
  final String? alt;
}

class RasqLinkSpan extends RasqSpan {
  const RasqLinkSpan(this.text, {required this.url, this.onTap});
  final String text;
  final Uri url;
  final VoidCallback? onTap;
}

class RasqMentionSpan extends RasqSpan {
  const RasqMentionSpan(this.handle, {this.onTap});
  final String handle;
  final VoidCallback? onTap;
}

class RasqHashtagSpan extends RasqSpan {
  const RasqHashtagSpan(this.tag, {this.onTap});
  final String tag;
  final VoidCallback? onTap;
}

/// MFM 装飾関数 (`$[fn.args …]` / RSL wire `{s:"transform", fn, args, c}`).
///
/// Rendering is delegated to `RasqMfmTransform` (mfm.dart). Unknown [fn]s
/// render [children] unchanged — the schema's forward-compat rule.
class RasqTransformSpan extends RasqSpan {
  const RasqTransformSpan(this.fn, {this.args = const {}, required this.children});
  final String fn;
  final Map<String, Object?> args;
  final List<RasqSpan> children;
}

/// Draws a list of [RasqSpan]s. Stateless; gesture recognizers are owned by
/// the widget and disposed with it.
///
/// MFM の関数 ([RasqTransformSpan]) は Misskey の描画に合わせる (D-509、[RasqMfmTransform]):
/// `x2..x4` / `small` / `plain` / `clickable` は行に流れる文字の様式、ほかの関数は 1 つずつ箱(inline-block = 中の
/// [RasqRichText] を基準線で行に置く [WidgetSpan])、`center` / 引用 / コード / 検索は行の幅いっぱいのブロック。
/// 本文に MFM の関数があれば、カスタム絵文字は Misskey のノートと同じ 2em(MFM アートの位置がずれないように)。
class RasqRichText extends StatefulWidget {
  const RasqRichText(this.spans, {super.key, this.style, this.maxLines, this.overflow = TextOverflow.clip, this.textAlign = TextAlign.start, this.mfm});

  /// Convenience for plain text.
  RasqRichText.plain(String text, {Key? key, TextStyle? style, int? maxLines, TextOverflow overflow = TextOverflow.clip})
      : this([RasqTextSpan(text)], key: key, style: style, maxLines: maxLines, overflow: overflow);

  final List<RasqSpan> spans;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

  /// 入れ子の段(MFM の箱の中)の文脈。null = いちばん外(ここから決める)。
  final RasqMfmContext? mfm;

  @override
  State<RasqRichText> createState() => _RasqRichTextState();
}

class _RasqRichTextState extends State<RasqRichText> {
  final List<GestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  GestureRecognizer? _tap(VoidCallback? cb) {
    if (cb == null) return null;
    final r = TapGestureRecognizer()..onTap = cb;
    _recognizers.add(r);
    return r;
  }

  /// MFM の関数(Misskey の装飾)を含むか。
  static bool _hasMfmFn(List<RasqSpan> spans) => spans.any((s) => s is RasqTransformSpan && (RasqMfmTransform.misskeyFns.contains(s.fn) || _hasMfmFn(s.children)));

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final base = DefaultTextStyle.of(context).style.merge(widget.style);
    final nested = widget.mfm != null;
    final RasqMfmContext ctx;
    if (widget.mfm != null) {
      ctx = widget.mfm!;
    } else {
      // デカ絵文字: 本文が絵文字(と空白)だけなら 2.5em(RASQ)。MFM の関数があれば Misskey のノートと同じ 2em。
      final emojiOnly = widget.spans.isNotEmpty &&
          widget.spans.every((s) => switch (s) {
                RasqEmojiSpan() => true,
                RasqTextSpan() => s.text.trim().isEmpty,
                _ => false,
              });
      ctx = RasqMfmContext(emojiEm: _hasMfmFn(widget.spans) ? 2.0 : (emojiOnly ? 2.5 : 1.25), textAlign: widget.textAlign);
    }

    return Text.rich(
      TextSpan(children: _spans(widget.spans, base, ctx)),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: nested ? ctx.textAlign : widget.textAlign,
      // 箱の中は中身の幅(inline-block の shrink-to-fit)。
      textWidthBasis: nested ? TextWidthBasis.longestLine : TextWidthBasis.parent,
      style: base,
    );
  }

  List<InlineSpan> _spans(List<RasqSpan> spans, TextStyle st, RasqMfmContext ctx) {
    final out = <InlineSpan>[];
    for (var i = 0; i < spans.length; i++) {
      final s = spans[i];
      out.add(_span(s, st, ctx));
      // ブロックの直後の改行は、HTML ではブロックの後ろに空の行を作る(Flutter ではブロックが行を終えるので 1 つ足す)。
      final next = i + 1 < spans.length ? spans[i + 1] : null;
      if (s is RasqTransformSpan && RasqMfmTransform.blockFns.contains(s.fn) && next is RasqTextSpan && next.text.startsWith('\n')) {
        out.add(TextSpan(text: '\n', style: st));
      }
    }
    return out;
  }

  TextStyle _tint(TextStyle t, RasqMfmContext ctx) {
    if (ctx.transparentText) return t.copyWith(color: const Color(0x00000000));
    if (ctx.opacity >= 1) return t;
    final c = t.color ?? const Color(0xFF000000);
    return t.copyWith(color: c.withValues(alpha: c.a * ctx.opacity));
  }

  InlineSpan _span(RasqSpan s, TextStyle st, RasqMfmContext ctx) {
    final tokens = RasqTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final size = st.fontSize ?? 15;
    final linkStyle = _tint(st.copyWith(color: tokens.link), ctx);
    switch (s) {
      case RasqTextSpan():
        return TextSpan(
          text: s.text,
          style: _tint(
            st.copyWith(
              fontWeight: s.bold ? FontWeight.w700 : null,
              fontStyle: s.italic ? FontStyle.italic : null,
              decoration: s.strike ? TextDecoration.lineThrough : null,
              fontSize: s.small ? size * 0.85 : null,
              fontFamily: s.code ? 'monospace' : null,
              fontFamilyFallback: s.code ? const ['Menlo', 'Courier New'] : null,
              backgroundColor: s.code ? scheme.surfaceContainerHighest : null,
            ),
            ctx,
          ),
        );
      case RasqEmojiSpan():
        if (s.url == null) return TextSpan(text: ':${s.shortcode}:', style: _tint(st, ctx));
        Widget emoji = RasqCustomEmoji(url: s.url, fallbackText: ':${s.shortcode}:', height: size * ctx.emojiEm, name: s.shortcode, semanticLabel: s.shortcode);
        if (ctx.hideEmoji || ctx.opacity < 1) emoji = Opacity(opacity: ctx.hideEmoji ? 0 : ctx.opacity, child: emoji);
        // 可変幅ルール + ホバー/長押しチップ (D-040)。Misskey の `vertical-align: middle`。
        return WidgetSpan(alignment: PlaceholderAlignment.middle, child: emoji);
      case RasqInlineImageSpan():
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          // プラグインの面では、その権限で読めない URL は読まない (D-407)。
          child: Builder(
            builder: (context) => rasqMediaAllowed(context, s.url)
                ? Image(image: rasqMediaImage(context, s.url), height: s.height, semanticLabel: s.alt, errorBuilder: (_, _, _) => const SizedBox.shrink())
                : const SizedBox.shrink(),
          ),
        );
      case RasqLinkSpan():
        return TextSpan(text: s.text, style: linkStyle, recognizer: _tap(s.onTap));
      case RasqMentionSpan():
        return TextSpan(text: '@${s.handle}', style: linkStyle, recognizer: _tap(s.onTap));
      case RasqHashtagSpan():
        return TextSpan(text: '#${s.tag}', style: linkStyle, recognizer: _tap(s.onTap));
      case RasqTransformSpan():
        return _transform(s, st, ctx);
    }
  }

  InlineSpan _transform(RasqTransformSpan s, TextStyle st, RasqMfmContext ctx) {
    final fn = s.fn;
    // 箱を作らない: 文字の様式だけ(`x2` の入れ子は半分だけ効く)。
    if (RasqMfmTransform.inlineFns.contains(fn)) {
      final childStyle = RasqMfmTransform.childStyle(fn, s.args, st, zoomDepth: ctx.zoomDepth);
      final childCtx = switch (fn) {
        'x2' || 'x3' || 'x4' => ctx.copyWith(zoomDepth: ctx.zoomDepth + 1),
        'small' => ctx.copyWith(opacity: ctx.opacity * 0.7),
        _ => ctx,
      };
      return TextSpan(children: _spans(s.children, childStyle, childCtx), style: childStyle);
    }
    final block = RasqMfmTransform.blockFns.contains(fn);
    if (!block && !RasqMfmTransform.boxFns.contains(fn)) {
      // 知らない関数は中身をそのまま(RSL の前方互換)。
      return TextSpan(children: _spans(s.children, st, ctx), style: st);
    }
    final childStyle = RasqMfmTransform.childStyle(fn, s.args, st, zoomDepth: ctx.zoomDepth);
    final childCtx = fn == 'center' ? ctx.copyWith(textAlign: TextAlign.center) : ctx;
    Widget layer(RasqMfmContext Function(RasqMfmContext) adjust) => RasqRichText(s.children, style: childStyle, mfm: adjust(childCtx));
    final box = RasqMfmTransform(fn: fn, args: s.args, style: childStyle, layer: layer, child: layer((c) => c));
    if (block) return WidgetSpan(child: box);
    // inline-block: 中の最初の行の基準線を行の基準線に揃える。
    return WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: box);
  }
}
