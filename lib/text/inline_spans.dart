import 'package:rasq_design/rasq_design.dart';

/// Minimal inline parser for MFM / plain text → RSL spans.
///
/// Handles URLs, @mentions (incl. @user@host), #hashtags and :custom_emoji:.
/// Block MFM (`$[spin ...]`, quotes, code) is M2 renderer work — here the
/// decorations are stripped to their inner text so nothing is lost.
abstract final class InlineSpans {
  static final _token = RegExp(
    r'(https?://[^\s<>"　]+)|(?<![\w@.])@([A-Za-z0-9_.-]+)(@[A-Za-z0-9.-]+)?|(?<![\w#])#([^\s#＃]+)|:([A-Za-z0-9_+-]+(?:@[A-Za-z0-9.-]+)?):',
    unicode: true,
  );
  static final _mfmFn = RegExp(r'\$\[[a-zA-Z0-9_.,=\-]+\s');

  /// Shortcodes found in [text] (for prefetching emoji URLs).
  static Set<String> emojiShortcodes(String text) => {
        for (final m in _token.allMatches(text))
          if (m.group(5) != null) m.group(5)!,
      };

  static List<RasqSpan> parse(
    String text, {
    Map<String, Uri?> emojis = const {},
    void Function(Uri url)? onLink,
    void Function(String handle, String? host)? onMention,
    void Function(String tag)? onHashtag,
  }) {
    // Strip MFM function wrappers: `$[spin text]` → `text`.
    var t = text.replaceAll(_mfmFn, '');
    if (t != text) t = t.replaceAll(']', '');
    final out = <RasqSpan>[];
    var last = 0;
    for (final m in _token.allMatches(t)) {
      if (m.start > last) out.add(RasqTextSpan(t.substring(last, m.start)));
      if (m.group(1) != null) {
        final raw = m.group(1)!;
        final uri = Uri.tryParse(raw);
        out.add(uri == null ? RasqTextSpan(raw) : RasqLinkSpan(_shortUrl(raw), url: uri, onTap: onLink == null ? null : () => onLink(uri)));
      } else if (m.group(2) != null) {
        final handle = m.group(2)!;
        final host = m.group(3)?.substring(1);
        out.add(RasqMentionSpan(host == null ? handle : '$handle@$host', onTap: onMention == null ? null : () => onMention(handle, host)));
      } else if (m.group(4) != null) {
        final tag = m.group(4)!;
        out.add(RasqHashtagSpan(tag, onTap: onHashtag == null ? null : () => onHashtag(tag)));
      } else if (m.group(5) != null) {
        final code = m.group(5)!;
        out.add(RasqEmojiSpan(shortcode: code, url: emojis[code]));
      }
      last = m.end;
    }
    if (last < t.length) out.add(RasqTextSpan(t.substring(last)));
    return out;
  }

  static String _shortUrl(String raw) {
    var s = raw.replaceFirst(RegExp(r'^https?://'), '');
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.length > 40 ? '${s.substring(0, 37)}…' : s;
  }
}
