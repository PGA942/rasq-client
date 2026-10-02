import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/rasq_tokens_extension.dart';
import 'custom_emoji.dart';
import 'mfm.dart';
import '../platform/media_policy.dart';
import '../platform/web_image.dart';

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
class RasqRichText extends StatefulWidget {
  const RasqRichText(this.spans, {super.key, this.style, this.maxLines, this.overflow = TextOverflow.clip, this.textAlign = TextAlign.start});

  /// Convenience for plain text.
  RasqRichText.plain(String text, {Key? key, TextStyle? style, int? maxLines, TextOverflow overflow = TextOverflow.clip})
      : this([RasqTextSpan(text)], key: key, style: style, maxLines: maxLines, overflow: overflow);

  final List<RasqSpan> spans;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;
  final TextAlign textAlign;

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

  @override
  Widget build(BuildContext context) {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();

    final base = widget.style ?? DefaultTextStyle.of(context).style;
    final tokens = RasqTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    final linkStyle = base.copyWith(color: tokens.link);
    // デカ絵文字: 本文が絵文字(と空白)だけなら 2 倍で描く(Misskey 準拠)。
    final emojiOnly = widget.spans.isNotEmpty &&
        widget.spans.every((s) => switch (s) {
              RasqEmojiSpan() => true,
              RasqTextSpan() => s.text.trim().isEmpty,
              _ => false,
            });
    final emojiHeight = (base.fontSize ?? 15) * (emojiOnly ? 2.5 : 1.25);

    InlineSpan toSpan(RasqSpan s) => switch (s) {
          RasqTextSpan() => TextSpan(
              text: s.text,
              style: base.copyWith(
                fontWeight: s.bold ? FontWeight.w700 : null,
                fontStyle: s.italic ? FontStyle.italic : null,
                decoration: s.strike ? TextDecoration.lineThrough : null,
                fontSize: s.small ? (base.fontSize ?? 15) * 0.85 : null,
                fontFamily: s.code ? 'monospace' : null,
                fontFamilyFallback: s.code ? const ['Menlo', 'Courier New'] : null,
                backgroundColor: s.code ? scheme.surfaceContainerHighest : null,
              ),
            ),
          RasqEmojiSpan() => s.url == null
              ? TextSpan(text: ':${s.shortcode}:', style: base)
              : WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  // 可変幅ルール + ホバー/長押しチップ (D-040)。
                  child: RasqCustomEmoji(url: s.url, fallbackText: ':${s.shortcode}:', height: emojiHeight, name: s.shortcode, semanticLabel: s.shortcode),
                ),
          RasqInlineImageSpan() => WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              // プラグインの面では、その権限で読めない URL は読まない (D-407)。
              child: Builder(
                builder: (context) => rasqMediaAllowed(context, s.url)
                    ? Image.network(webHtmlElementStrategy: rasqWebImageStrategy, s.url.toString(), height: s.height, semanticLabel: s.alt, errorBuilder: (_, _, _) => const SizedBox.shrink())
                    : const SizedBox.shrink(),
              ),
            ),
          RasqLinkSpan() => TextSpan(text: s.text, style: linkStyle, recognizer: _tap(s.onTap)),
          RasqMentionSpan() => TextSpan(text: '@${s.handle}', style: linkStyle, recognizer: _tap(s.onTap)),
          RasqHashtagSpan() => TextSpan(text: '#${s.tag}', style: linkStyle, recognizer: _tap(s.onTap)),
          RasqTransformSpan() => WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: RasqMfmTransform(
                fn: s.fn,
                args: s.args,
                child: RasqRichText(s.children, style: RasqMfmTransform.childStyle(s.fn, s.args, base)),
              ),
            ),
        };

    return Text.rich(
      TextSpan(children: widget.spans.map(toSpan).toList()),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      textAlign: widget.textAlign,
      style: base,
    );
  }
}
