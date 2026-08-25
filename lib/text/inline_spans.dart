import 'package:rasq_design/rasq_design.dart';

/// Inline parser for MFM / plain text → RSL spans.
///
/// Handles URLs, @mentions (incl. @user@host), #hashtags, :custom_emoji:,
/// `**bold**` and **structural MFM functions** `$[fn.args content]` (nested)
/// which become [RasqTransformSpan]s rendered by `RasqMfmTransform`.
/// Block-level MFM (quotes, code fences, search) is still out of scope.
abstract final class InlineSpans {
  static final _token = RegExp(
    r'(https?://[^\s<>"　]+)|(?<![\w@.])@([A-Za-z0-9_.-]+)(@[A-Za-z0-9.-]+)?|(?<![\w#])#([^\s#＃]+)|:([A-Za-z0-9_+-]+(?:@[A-Za-z0-9.-]+)?):',
    unicode: true,
  );
  static final _emojiToken = RegExp(r':([A-Za-z0-9_+-]+(?:@[A-Za-z0-9.-]+)?):');
  static final _mfmOpen = RegExp(r'\$\[([a-zA-Z][a-zA-Z0-9_]*)((?:\.[a-zA-Z0-9_.,=\-]+)?)\s');

  /// Shortcodes found in [text] (for prefetching emoji URLs).
  static Set<String> emojiShortcodes(String text) => {
        for (final m in _emojiToken.allMatches(text)) m.group(1)!,
      };

  static List<RasqSpan> parse(
    String text, {
    Map<String, Uri?> emojis = const {},
    void Function(Uri url)? onLink,
    void Function(String handle, String? host)? onMention,
    void Function(String tag)? onHashtag,
  }) =>
      _Parser(emojis: emojis, onLink: onLink, onMention: onMention, onHashtag: onHashtag).parse(text);

  static String shortUrl(String raw) {
    var s = raw.replaceFirst(RegExp(r'^https?://'), '');
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.length > 40 ? '${s.substring(0, 37)}…' : s;
  }
}

class _Parser {
  _Parser({required this.emojis, this.onLink, this.onMention, this.onHashtag});

  final Map<String, Uri?> emojis;
  final void Function(Uri url)? onLink;
  final void Function(String handle, String? host)? onMention;
  final void Function(String tag)? onHashtag;

  List<RasqSpan> parse(String text) {
    final out = <RasqSpan>[];
    var rest = text;
    while (rest.isNotEmpty) {
      final mfm = InlineSpans._mfmOpen.firstMatch(rest);
      final bold = rest.indexOf('**');
      // Take whichever structural marker comes first.
      if (mfm != null && (bold < 0 || mfm.start <= bold)) {
        if (mfm.start > 0) out.addAll(_leaf(rest.substring(0, mfm.start)));
        final contentStart = mfm.end;
        final close = _matchingBracket(rest, contentStart);
        if (close < 0) {
          // Unbalanced → treat literally.
          out.addAll(_leaf(rest.substring(mfm.start, contentStart)));
          rest = rest.substring(contentStart);
          continue;
        }
        out.add(RasqTransformSpan(
          mfm.group(1)!,
          args: _args(mfm.group(2) ?? ''),
          children: parse(rest.substring(contentStart, close)),
        ));
        rest = rest.substring(close + 1);
      } else if (bold >= 0) {
        final end = rest.indexOf('**', bold + 2);
        if (end < 0) {
          out.addAll(_leaf(rest));
          break;
        }
        if (bold > 0) out.addAll(_leaf(rest.substring(0, bold)));
        for (final s in parse(rest.substring(bold + 2, end))) {
          out.add(s is RasqTextSpan ? RasqTextSpan(s.text, bold: true, italic: s.italic, strike: s.strike, small: s.small) : s);
        }
        rest = rest.substring(end + 2);
      } else {
        out.addAll(_leaf(rest));
        break;
      }
    }
    return out;
  }

  /// Index of the `]` closing an MFM function whose content starts at
  /// [from], skipping nested `$[…]`. -1 when unbalanced.
  static int _matchingBracket(String s, int from) {
    var depth = 0;
    for (var i = from; i < s.length; i++) {
      if (s[i] == ']') {
        if (depth == 0) return i;
        depth--;
      } else if (s.startsWith(r'$[', i)) {
        depth++;
        i++;
      }
    }
    return -1;
  }

  /// `.left,speed=0.5,deg=30` → {left: true, speed: '0.5', deg: 30}.
  static Map<String, Object?> _args(String raw) {
    if (raw.isEmpty) return const {};
    final out = <String, Object?>{};
    for (final part in raw.substring(1).split(',')) {
      if (part.isEmpty) continue;
      final eq = part.indexOf('=');
      if (eq < 0) {
        out[part] = true;
      } else {
        final v = part.substring(eq + 1);
        out[part.substring(0, eq)] = num.tryParse(v) ?? v;
      }
    }
    return out;
  }

  /// Leaf tokens: URLs / mentions / hashtags / custom emoji / plain text.
  List<RasqSpan> _leaf(String t) {
    final out = <RasqSpan>[];
    var last = 0;
    for (final m in InlineSpans._token.allMatches(t)) {
      if (m.start > last) out.add(RasqTextSpan(t.substring(last, m.start)));
      if (m.group(1) != null) {
        final raw = m.group(1)!;
        final uri = Uri.tryParse(raw);
        out.add(uri == null ? RasqTextSpan(raw) : RasqLinkSpan(InlineSpans.shortUrl(raw), url: uri, onTap: onLink == null ? null : () => onLink!(uri)));
      } else if (m.group(2) != null) {
        final handle = m.group(2)!;
        final host = m.group(3)?.substring(1);
        out.add(RasqMentionSpan(host == null ? handle : '$handle@$host', onTap: onMention == null ? null : () => onMention!(handle, host)));
      } else if (m.group(4) != null) {
        final tag = m.group(4)!;
        out.add(RasqHashtagSpan(tag, onTap: onHashtag == null ? null : () => onHashtag!(tag)));
      } else if (m.group(5) != null) {
        final code = m.group(5)!;
        out.add(RasqEmojiSpan(shortcode: code, url: emojis[code]));
      }
      last = m.end;
    }
    if (last < t.length) out.add(RasqTextSpan(t.substring(last)));
    return out;
  }
}
