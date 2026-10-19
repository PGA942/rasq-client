import 'package:rasq_design/rasq_design.dart';

import '../l10n/l10n.dart';
import 'mfm/mfm_node.dart';
import 'mfm/mfm_parser.dart';

/// MFM / プレーンテキスト → RSL スパン。
///
/// 解析は mfm.js の移植([Mfm.parse]、D-509)。木は mfm.js と同じで、ここでは Misskey の描画(MkMfm /
/// frontend-shared の mfm-renderer)と同じ意味のスパンに置き換える:
/// - リーフ: URL(`<https://…>` も)/ @mention / #hashtag / :custom_emoji:(`:name@host:` はローカルキャッシュの
///   `name` にフォールバック)/ Unicode の絵文字(文字のまま)
/// - 装飾: `**太字**` `<b>` / `<i>` `*abc*` `_abc_` / `~~打ち消し~~` `<s>` / `` `コード` `` / `\(数式\)`(コード)/
///   `<small>`(`small`)/ `<plain>`(解析しない)/ `[ラベル](URL)` `?[ラベル](URL)`
/// - ブロック(行頭): `<center>`(`center`)/ `> 引用`(`quote`)/ ```` ``` ````(`code_block`)/ `\[数式\]`(コード)/
///   `… 検索`(`search`)
/// - MFM 関数 `$[fn.args …]`(入れ子可)→ [RasqTransformSpan]。Misskey が知らない関数は Misskey と同じく
///   `$[name 中身]` を文字のまま出す。`***大きく***` は `tada`。`ruby` / `unixtime` は Misskey と同じ読み方で引数にする。
/// - HTML 風の MFM(`htmlFns: true` のときだけ、D-446 の RASQ の Markdown ページ): `<spin speed="1s">…</spin>` / `<x2>` /
///   `<fg color="f00">` / `<flip h v>` / `<rotate deg="30">` …(MFM の関数名をタグに、引数を属性に)、`<ruby>本<rt>ほん</rt></ruby>`。
abstract final class InlineSpans {
  static final _emojiToken = RegExp(r':([A-Za-z0-9_+-]+)(@[A-Za-z0-9.-]+)?:');

  /// HTML 風に書ける MFM の関数(`<b>` などの mfm.js のタグは除く)。
  static const htmlFnTags = mfmHtmlFnTags;

  /// Misskey の描画が知っている MFM 関数(これ以外は `$[name 中身]` を文字のまま)。
  static const misskeyFns = {
    'tada', 'jelly', 'twitch', 'shake', 'spin', 'jump', 'bounce', 'flip', 'x2', 'x3', 'x4', 'font', 'blur', 'rainbow', //
    'sparkle', 'rotate', 'position', 'scale', 'fg', 'bg', 'border', 'ruby', 'unixtime', 'clickable',
  };

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
    bool htmlFns = false,
  }) =>
      _Converter(emojis: emojis, onLink: onLink, onMention: onMention, onHashtag: onHashtag).spans(Mfm.parse(text, htmlFns: htmlFns, emojiHost: true));

  /// Misskey の名前などの簡易な解析(`parseSimple`: 絵文字と `<plain>` だけ)。
  static List<RasqSpan> parseSimple(String text, {Map<String, Uri?> emojis = const {}}) => _Converter(emojis: emojis).spans(Mfm.parseSimple(text));

  static String shortUrl(String raw) {
    var s = raw.replaceFirst(RegExp(r'^https?://'), '');
    if (s.endsWith('/')) s = s.substring(0, s.length - 1);
    return s.length > 40 ? '${s.substring(0, 37)}…' : s;
  }
}

class _Converter {
  _Converter({required this.emojis, this.onLink, this.onMention, this.onHashtag});

  final Map<String, Uri?> emojis;
  final void Function(Uri url)? onLink;
  final void Function(String handle, String? host)? onMention;
  final void Function(String tag)? onHashtag;

  List<RasqSpan> spans(List<MfmNode> nodes, {bool bold = false, bool italic = false, bool strike = false}) => [
        for (final n in nodes) ..._node(n, bold: bold, italic: italic, strike: strike),
      ];

  RasqLinkSpan _link(String text, Uri url) => RasqLinkSpan(text, url: url, onTap: onLink == null ? null : () => onLink!(url));

  List<RasqSpan> _node(MfmNode n, {required bool bold, required bool italic, required bool strike}) {
    RasqTextSpan text(String t, {bool code = false}) => RasqTextSpan(t, bold: bold, italic: italic, strike: strike, code: code);
    List<RasqSpan> kids({bool? b, bool? i, bool? s}) => spans(n.children ?? const [], bold: b ?? bold, italic: i ?? italic, strike: s ?? strike);
    final p = n.props ?? const {};
    switch (n.type) {
      case 'text':
        return [text(n.text)];
      case 'bold':
        return kids(b: true);
      case 'italic':
        return kids(i: true);
      case 'strike':
        return kids(s: true);
      case 'small':
        return [RasqTransformSpan('small', children: kids())];
      case 'center':
        return [RasqTransformSpan('center', children: kids())];
      case 'quote':
        return [RasqTransformSpan('quote', children: kids())];
      case 'blockCode':
        return [
          RasqTransformSpan('code_block', args: {if (p['lang'] != null) 'lang': p['lang']}, children: [RasqTextSpan(p['code'] as String, code: true)]),
        ];
      // Misskey は数式を `<code>` のまま出す(ブロックも)。
      case 'inlineCode':
        return [text(p['code'] as String, code: true)];
      case 'mathInline' || 'mathBlock':
        return [text(p['formula'] as String, code: true)];
      case 'search':
        final q = p['query'] as String;
        final url = Uri.https('www.google.com', '/search', {'q': q});
        return [
          RasqTransformSpan('search', args: {'query': q}, children: [_link(appL10n.composeMfmSearchButton, url)]),
        ];
      case 'mention':
        final user = p['username'] as String;
        final host = p['host'] as String?;
        return [RasqMentionSpan(host == null ? user : '$user@$host', onTap: onMention == null ? null : () => onMention!(user, host))];
      case 'hashtag':
        final tag = p['hashtag'] as String;
        return [RasqHashtagSpan(tag, onTap: onHashtag == null ? null : () => onHashtag!(tag))];
      case 'url':
        final raw = p['url'] as String;
        final uri = Uri.tryParse(raw);
        return [if (uri == null) text(raw) else _link(InlineSpans.shortUrl(raw), uri)];
      case 'link':
        final uri = Uri.tryParse(p['url'] as String);
        final label = kids();
        if (uri == null) return label;
        return [for (final s in label) s is RasqTextSpan ? _link(s.text, uri) : s];
      case 'emojiCode':
        final code = p['name'] as String;
        // `:name@host:` / `:name@.:` はローカルキャッシュの `name` にフォールバック。
        final bare = code.split('@').first;
        return [RasqEmojiSpan(shortcode: code, url: emojis[code] ?? emojis[bare])];
      case 'unicodeEmoji':
        return [text(p['emoji'] as String)];
      case 'plain':
        return [text(n.children?.map((c) => c.text).join() ?? '')];
      case 'fn':
        return _fn(n, kids, text);
    }
    return kids();
  }

  List<RasqSpan> _fn(MfmNode n, List<RasqSpan> Function() kids, RasqTextSpan Function(String) text) {
    final name = n.fnName;
    final args = n.fnArgs;
    final children = n.children ?? const <MfmNode>[];
    // Misskey: 知らない関数・書体の無い font は `$[name 中身]` を文字のまま(引数は出さない)。
    final fontless = name == 'font' && !const ['serif', 'monospace', 'cursive', 'fantasy', 'emoji', 'math'].any(args.containsKey);
    if (!InlineSpans.misskeyFns.contains(name) || fontless) {
      return [text('\$[$name '), ...kids(), text(']')];
    }
    switch (name) {
      case 'ruby':
        // HTML 風 (D-446) は `<rt>` を引数で持つ。
        if (args['rt'] != null) return [RasqTransformSpan('ruby', args: args, children: kids())];
        // Misskey: 子が 1 つなら「本文 読み」を空白で分ける。2 つ以上なら最後の text が読み。
        if (children.length == 1) {
          final t = children.single.type == 'text' ? children.single.text : '';
          final parts = t.split(' ');
          return [
            RasqTransformSpan('ruby', args: {'rt': parts.length > 1 ? parts[1] : ''}, children: [text(parts[0])]),
          ];
        }
        final rt = children.isEmpty || children.last.type != 'text' ? '' : children.last.text.trim();
        return [
          RasqTransformSpan('ruby', args: {'rt': rt}, children: spans(children.sublist(0, children.isEmpty ? 0 : children.length - 1))),
        ];
      case 'unixtime':
        final t = children.isNotEmpty && children.first.type == 'text' ? children.first.text : '';
        return [RasqTransformSpan('unixtime', args: {'time': _parseInt(t)}, children: [text(t)])];
    }
    return [RasqTransformSpan(name, args: args, children: kids())];
  }

  /// JS の `parseInt`(先頭の空白を飛ばし、先頭の整数だけ。読めなければ null)。
  static int? _parseInt(String s) {
    final m = RegExp(r'^\s*([+-]?\d+)').firstMatch(s);
    return m == null ? null : int.tryParse(m[1]!);
  }
}
