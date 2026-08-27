import 'package:rasq_design/rasq_design.dart';

/// Inline parser for MFM / plain text → RSL spans.
///
/// - リーフ: URL / @mention(@user@host) / #hashtag / :custom_emoji:(`:name@host:`
///   はローカルキャッシュの `name` にフォールバック)
/// - マークダウン: `**太字**` `*斜体*` `~~打ち消し~~` `` `コード` `` ```コードブロック```
///   `[テキスト](URL)` 行頭の `> 引用`
/// - タグ: `<b> <i> <s> <small> <center> <plain>`(plain は中身を解析しない)
/// - MFM 関数: `$[fn.args …]`(入れ子可)→ [RasqTransformSpan]
///
/// 引用・コードブロックも transform スパン(`quote` / `code_block`)として
/// 持ち、`RasqMfmTransform` が描画する。
abstract final class InlineSpans {
  static final _token = RegExp(
    r'(https?://[^\s<>"　]+)|(?<![\w@.])@([A-Za-z0-9_.-]+)(@[A-Za-z0-9.-]+)?|(?<![\w#])#([^\s#＃]+)|:([A-Za-z0-9_+-]+(?:@[A-Za-z0-9.-]+)?):',
    unicode: true,
  );
  static final _emojiToken = RegExp(r':([A-Za-z0-9_+-]+)(@[A-Za-z0-9.-]+)?:');
  static final _mfmOpen = RegExp(r'\$\[([a-zA-Z][a-zA-Z0-9_]*)((?:\.[a-zA-Z0-9_.,=\-]+)?)\s');
  static final _mdLink = RegExp(r'^\[([^\[\]]+)\]\((https?://[^\s)]+)\)');
  static final _htmlTag = RegExp(r'^<(b|i|s|small|center|plain)>');

  /// Shortcodes found in [text], host suffix stripped (絵文字URLのプリフェッチ用。
  /// リモート絵文字の URL は本来ノートの emojis フィールド由来)。
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
      _Parser(emojis: emojis, onLink: onLink, onMention: onMention, onHashtag: onHashtag).parse(text, atLineStart: true);

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

  List<RasqSpan> parse(String text, {bool atLineStart = false}) {
    final out = <RasqSpan>[];
    var rest = text;
    var lineStart = atLineStart;
    while (rest.isNotEmpty) {
      final marker = _firstMarker(rest, lineStart);
      if (marker == null) {
        out.addAll(_leaf(rest));
        break;
      }
      if (marker.index > 0) out.addAll(_leaf(rest.substring(0, marker.index)));
      final consumed = marker.handle(this, rest, out);
      if (consumed <= 0) {
        // Unbalanced → treat the marker char literally and move on.
        out.addAll(_leaf(rest.substring(marker.index, marker.index + 1)));
        rest = rest.substring(marker.index + 1);
      } else {
        rest = rest.substring(consumed);
      }
      lineStart = rest.isNotEmpty && (marker is _QuoteMarker || rest.startsWith('\n'));
      if (out.isNotEmpty && out.last is RasqTextSpan) {
        lineStart = (out.last as RasqTextSpan).text.endsWith('\n') || lineStart;
      }
    }
    return out;
  }

  // ---- marker scan ----------------------------------------------------------

  _Marker? _firstMarker(String s, bool lineStart) {
    _Marker? best;
    void consider(_Marker? m) {
      if (m != null && (best == null || m.index < best!.index)) best = m;
    }

    consider(_index(s, r'```', (i) => _FenceMarker(i)));
    consider(_index(s, '`', (i) => s.startsWith('```', i) ? null : _InlineCodeMarker(i)));
    consider(_index(s, '**', (i) => _StyleMarker(i, '**', bold: true)));
    consider(_index(s, '~~', (i) => _StyleMarker(i, '~~', strike: true)));
    final mfm = InlineSpans._mfmOpen.firstMatch(s);
    if (mfm != null) consider(_MfmMarker(mfm.start, mfm));
    consider(_index(s, '*', (i) => s.startsWith('**', i) ? null : _StyleMarker(i, '*', italic: true)));
    consider(_index(s, '[', (i) => InlineSpans._mdLink.firstMatch(s.substring(i)) == null ? null : _LinkMarker(i)));
    consider(_index(s, '<', (i) => InlineSpans._htmlTag.firstMatch(s.substring(i)) == null ? null : _TagMarker(i, InlineSpans._htmlTag.firstMatch(s.substring(i))!.group(1)!)));
    // 行頭の "> " 引用(先頭 or 改行直後)。
    final quote = RegExp(r'(^|\n)> ').firstMatch(s);
    if (quote != null) {
      final at = quote.group(1)!.isEmpty ? 0 : quote.start + 1;
      if (at > 0 || lineStart) consider(_QuoteMarker(at));
    }
    return best;
  }

  static _Marker? _index(String s, String pattern, _Marker? Function(int) build) {
    final i = s.indexOf(pattern);
    return i < 0 ? null : build(i);
  }

  // ---- leaf tokens ----------------------------------------------------------

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
        // `:name@host:` / `:name@.:` はローカルキャッシュの `name` にフォールバック。
        final bare = code.split('@').first;
        out.add(RasqEmojiSpan(shortcode: code, url: emojis[code] ?? emojis[bare]));
      }
      last = m.end;
    }
    if (last < t.length) out.add(RasqTextSpan(t.substring(last)));
    return out;
  }

  /// スタイルを子スパンのテキストへ畳み込む(**bold** / *italic* / ~~strike~~)。
  List<RasqSpan> styled(String inner, {bool bold = false, bool italic = false, bool strike = false}) => [
        for (final s in parse(inner))
          s is RasqTextSpan ? s.copyWith(bold: bold || s.bold, italic: italic || s.italic, strike: strike || s.strike) : s,
      ];
}

sealed class _Marker {
  _Marker(this.index);
  final int index;

  /// Handles the marker at [index]; returns total consumed length from the
  /// start of [s] (0 = unbalanced, treat literally).
  int handle(_Parser p, String s, List<RasqSpan> out);
}

class _StyleMarker extends _Marker {
  _StyleMarker(super.index, this.token, {this.bold = false, this.italic = false, this.strike = false});
  final String token;
  final bool bold;
  final bool italic;
  final bool strike;

  @override
  int handle(_Parser p, String s, List<RasqSpan> out) {
    final start = index + token.length;
    final end = s.indexOf(token, start);
    if (end < 0 || end == start) return 0;
    out.addAll(p.styled(s.substring(start, end), bold: bold, italic: italic, strike: strike));
    return end + token.length;
  }
}

class _InlineCodeMarker extends _Marker {
  _InlineCodeMarker(super.index);

  @override
  int handle(_Parser p, String s, List<RasqSpan> out) {
    final start = index + 1;
    final end = s.indexOf('`', start);
    if (end < 0 || end == start) return 0;
    out.add(RasqTextSpan(s.substring(start, end), code: true));
    return end + 1;
  }
}

class _FenceMarker extends _Marker {
  _FenceMarker(super.index);

  @override
  int handle(_Parser p, String s, List<RasqSpan> out) {
    final start = index + 3;
    final end = s.indexOf('```', start);
    if (end < 0) return 0;
    var content = s.substring(start, end);
    // ```lang\n … ``` の言語行と前後の改行を落とす。
    content = content.replaceFirst(RegExp(r'^[^\n]*\n'), '').replaceFirst(RegExp(r'\n$'), '');
    out.add(RasqTransformSpan('code_block', children: [RasqTextSpan(content, code: true)]));
    return end + 3;
  }
}

class _LinkMarker extends _Marker {
  _LinkMarker(super.index);

  @override
  int handle(_Parser p, String s, List<RasqSpan> out) {
    final m = InlineSpans._mdLink.firstMatch(s.substring(index))!;
    final url = Uri.tryParse(m.group(2)!);
    if (url == null) return 0;
    out.add(RasqLinkSpan(m.group(1)!, url: url, onTap: p.onLink == null ? null : () => p.onLink!(url)));
    return index + m.end;
  }
}

class _TagMarker extends _Marker {
  _TagMarker(super.index, this.tag);
  final String tag;

  @override
  int handle(_Parser p, String s, List<RasqSpan> out) {
    final open = '<$tag>';
    final close = '</$tag>';
    final start = index + open.length;
    final end = s.indexOf(close, start);
    if (end < 0) return 0;
    final inner = s.substring(start, end);
    switch (tag) {
      case 'b':
        out.addAll(p.styled(inner, bold: true));
      case 'i':
        out.addAll(p.styled(inner, italic: true));
      case 's':
        out.addAll(p.styled(inner, strike: true));
      case 'small':
        out.addAll([for (final sp in p.parse(inner)) sp is RasqTextSpan ? RasqTextSpan(sp.text, bold: sp.bold, italic: sp.italic, strike: sp.strike, small: true, code: sp.code) : sp]);
      case 'center':
        out.add(RasqTransformSpan('center', children: p.parse(inner)));
      case 'plain':
        out.add(RasqTextSpan(inner)); // 中身は解析しない
    }
    return end + close.length;
  }
}

class _MfmMarker extends _Marker {
  _MfmMarker(super.index, this.match);
  final RegExpMatch match;

  @override
  int handle(_Parser p, String s, List<RasqSpan> out) {
    final contentStart = match.end;
    final close = _matchingBracket(s, contentStart);
    if (close < 0) return 0;
    out.add(RasqTransformSpan(match.group(1)!, args: _args(match.group(2) ?? ''), children: p.parse(s.substring(contentStart, close))));
    return close + 1;
  }

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
}

class _QuoteMarker extends _Marker {
  _QuoteMarker(super.index);

  @override
  int handle(_Parser p, String s, List<RasqSpan> out) {
    // 連続する "> " 行をひとつの引用ブロックに。
    var end = index;
    final lines = <String>[];
    while (end < s.length && s.startsWith('> ', end)) {
      final lineEnd = s.indexOf('\n', end);
      if (lineEnd < 0) {
        lines.add(s.substring(end + 2));
        end = s.length;
        break;
      }
      lines.add(s.substring(end + 2, lineEnd));
      end = lineEnd + 1;
    }
    if (lines.isEmpty) return 0;
    out.add(RasqTransformSpan('quote', children: p.parse(lines.join('\n'))));
    return end;
  }
}
