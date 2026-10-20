import 'emoji_regex.dart';
import 'mfm_node.dart';

/// mfm.js(misskey-dev/mfm.js 0.27.0 の src/internal/parser.ts / core)の Dart への移植 (D-509)。
///
/// 規則・順番・失敗の扱い(`seqOrText` で閉じなかったら開きの記号を文字に戻す、入れ子の上限 `nestLimit` を超えたら
/// 1 文字ずつ文字にする、リンクのラベルの失敗の境目を覚えて同じ所を何度も試さない…)を mfm.js のまま写した。
/// 出力は mfm.js の `parse()` / `parseSimple()` と同じ木(test/mfm_parser_test.dart が mfm.js 自身のテストの入出力と
/// mfm.js の実物の出力で突き合わせる)。
///
/// RASQ の拡張(既定では無効。mfm.js と同じ木にしたいときは付けない):
/// - [Mfm.parse] の `htmlFns`: RASQ の Markdown ページ (D-446) の HTML 風の MFM(`<spin speed="1s" left>…</spin>` /
///   `<ruby>本<rt>ほん</rt></ruby>`)を `fn` ノードにする。
/// - [Mfm.parse] の `emojiHost`: `:name@host:` / `:name@.:` も `emojiCode` にする(リアクションなどで来るホスト付きの名前)。
///
/// mfm.js: MIT License, Copyright (c) 2020-2022 Marihachi and other contributors.
abstract final class Mfm {
  /// mfm.js の `parse(input, {nestLimit})`(フルパーサー)。
  static List<MfmNode> parse(String input, {int nestLimit = 20, bool htmlFns = false, bool emojiHost = false}) {
    final state = _State(nestLimit: nestLimit, htmlFns: htmlFns, emojiHost: emojiHost);
    final result = _lang.fullParser.handler(input, 0, state);
    if (result == null) throw StateError('Unexpected parse error');
    return _mergeText(result.value as List);
  }

  /// mfm.js の `parseSimple(input)`(名前などに使う、絵文字と `<plain>` だけ)。
  static List<MfmNode> parseSimple(String input) {
    final state = _State(nestLimit: 1 << 30);
    final result = _lang.simpleParser.handler(input, 0, state);
    if (result == null) throw StateError('Unexpected parse error');
    return _mergeText(result.value as List);
  }

  static final _lang = _Language();
}

// ── core(Parsimmon 風の状態つきパーサー結合子) ─────────────────────────────

class _State {
  _State({required this.nestLimit, this.htmlFns = false, this.emojiHost = false});
  final int nestLimit;
  final bool htmlFns;
  final bool emojiHost;
  int depth = 0;
  bool linkLabel = false;
  Map<String, Map<int, Set<int>>>? linkLabelFailures;
}

class _Ok {
  const _Ok(this.index, this.value);
  final int index;
  final Object? value;
}

typedef _Handler = _Ok? Function(String input, int index, _State state);

class _P {
  _P(this.handler);
  _Handler handler;

  _P map(Object? Function(Object? value) fn) => _P((input, index, state) {
        final r = handler(input, index, state);
        return r == null ? null : _Ok(r.index, fn(r.value));
      });

  _P text() => _P((input, index, state) {
        final r = handler(input, index, state);
        return r == null ? null : _Ok(r.index, input.substring(index, r.index));
      });

  _P many(int min) => _P((input, index, state) {
        var latest = index;
        final accum = <Object?>[];
        while (latest < input.length) {
          final r = handler(input, latest, state);
          if (r == null) break;
          latest = r.index;
          accum.add(r.value);
        }
        if (accum.length < min) return null;
        return _Ok(latest, accum);
      });

  _P sep(_P separator, int min) {
    assert(min >= 1);
    return _seq([this, _seq([separator, this]).select(1).many(min - 1)]).map((v) {
      final l = v as List;
      return [l[0], ...(l[1] as List)];
    });
  }

  _P select(int key) => map((v) => (v as List)[key]);

  _P option() => _alt([this, _succeeded(null)]);
}

_P _str(String value) => _P((input, index, _) => input.startsWith(value, index) ? _Ok(index + value.length, value) : null);

/// JS の `regexp()`(`^(?:pattern)` を index から)。
_P _regexp(String pattern, {bool caseInsensitive = false}) {
  final re = RegExp(pattern, caseSensitive: !caseInsensitive);
  return _P((input, index, _) {
    final m = re.matchAsPrefix(input, index);
    return m == null ? null : _Ok(m.end, m[0]);
  });
}

_P _seq(List<_P> parsers) => _P((input, index, state) {
      var latest = index;
      final accum = <Object?>[];
      for (final p in parsers) {
        final r = p.handler(input, latest, state);
        if (r == null) return null;
        latest = r.index;
        accum.add(r.value);
      }
      return _Ok(latest, accum);
    });

_P _alt(List<_P> parsers) => _P((input, index, state) {
      for (final p in parsers) {
        final r = p.handler(input, index, state);
        if (r != null) return r;
      }
      return null;
    });

_P _succeeded(Object? value) => _P((_, index, _) => _Ok(index, value));

_P _notMatch(_P parser) => _P((input, index, state) => parser.handler(input, index, state) == null ? _Ok(index, null) : null);

final _cr = _str('\r');
final _lf = _str('\n');
final _crlf = _str('\r\n');

final _char = _P((input, index, _) => input.length - index < 1 ? null : _Ok(index + 1, input[index]));

final _lineBegin = _P((input, index, state) {
  if (index == 0) return _Ok(index, null);
  if (_cr.handler(input, index - 1, state) != null) return _Ok(index, null);
  if (_lf.handler(input, index - 1, state) != null) return _Ok(index, null);
  return null;
});

final _lineEnd = _P((input, index, state) {
  if (index == input.length) return _Ok(index, null);
  if (_cr.handler(input, index, state) != null) return _Ok(index, null);
  if (_lf.handler(input, index, state) != null) return _Ok(index, null);
  return null;
});

_P _lazy(_P Function() fn) {
  late final _P parser;
  parser = _P((input, index, state) {
    parser.handler = fn().handler;
    return parser.handler(input, index, state);
  });
  return parser;
}

// ── util ────────────────────────────────────────────────────────────────

/// mfm.js の `mergeText`: 1 段だけ平らにし、続く文字列 / text ノードを 1 つの text にまとめる。
List<MfmNode> _mergeText(List nodes) {
  final dest = <MfmNode>[];
  final stored = StringBuffer();
  void generateText() {
    if (stored.isNotEmpty) {
      dest.add(MfmNode.ofText(stored.toString()));
      stored.clear();
    }
  }

  for (final node in nodes.expand((e) => e is List ? e : [e])) {
    if (node is String) {
      stored.write(node);
    } else if (node is MfmNode && node.type == 'text') {
      stored.write(node.text);
    } else if (node is MfmNode) {
      generateText();
      dest.add(node);
    }
  }
  generateText();
  return dest;
}

// ── language(parser.ts) ─────────────────────────────────────────────────

final _space = _regexp(r'[ 　\t]'); // l10n-ignore
final _alphaAndNum = _regexp(r'[a-z0-9]', caseInsensitive: true);
final _newLine = _alt([_crlf, _cr, _lf]);
final _alnumEnd = RegExp(r'[a-z0-9]$', caseSensitive: false);

/// 直前の 1 文字が英数字か(mfm.js の `/[a-z0-9]$/i.test(input.slice(0, index))`)。
bool _afterAlnum(String input, int index) => index > 0 && _alnumEnd.hasMatch(input.substring(index - 1, index));

_P _seqOrText(List<_P> parsers) => _P((input, index, state) {
      final accum = <Object?>[];
      var latest = index;
      for (final p in parsers) {
        final r = p.handler(input, latest, state);
        if (r == null) {
          if (latest == index) return null;
          return _Ok(latest, input.substring(index, latest));
        }
        accum.add(r.value);
        latest = r.index;
      }
      return _Ok(latest, accum);
    });

final _notLinkLabel = _P((_, index, state) => !state.linkLabel ? _Ok(index, null) : null);

final _nestable = _P((_, index, state) => state.depth < state.nestLimit ? _Ok(index, null) : null);

_P _nest(_P parser, [_P? fallback]) {
  final inner = _alt([_seq([_nestable, parser]).select(1), fallback ?? _char]);
  return _P((input, index, state) {
    state.depth++;
    final r = inner.handler(input, index, state);
    state.depth--;
    return r;
  });
}

Set<int> _linkLabelFailures(String input, _State state) {
  final all = state.linkLabelFailures ??= {};
  final byDepth = all.putIfAbsent(input, () => {});
  return byDepth.putIfAbsent(state.depth, () => <int>{});
}

/// HTML 風の MFM のタグ(RASQ の拡張、D-446)。`<b>` などの mfm.js のタグは除く。
const mfmHtmlFnTags = {'x2', 'x3', 'x4', 'blur', 'rotate', 'flip', 'fg', 'bg', 'shake', 'spin', 'jump', 'bounce', 'rainbow', 'twitch', 'jelly', 'tada', 'ruby', 'font', 'position', 'scale', 'border', 'sparkle'};

class _Language {
  late final _P fullParser = _lazy(() => full.many(0));
  late final _P simpleParser = _lazy(() => simple.many(0));

  late final _P full = _lazy(() => _alt([
        unicodeEmoji, htmlFn, centerTag, smallTag, plainTag, boldTag, italicTag, strikeTag, urlAlt, big, boldAsta, //
        italicAsta, boldUnder, italicUnder, codeBlock, inlineCode, quote, mathBlock, mathInline, strikeWave, fn,
        mention, hashtag, emojiCode, link, url, search, textP,
      ]));

  late final _P simple = _lazy(() => _alt([unicodeEmoji, emojiCode, plainTag, textP]));

  late final _P inline = _lazy(() => _alt([
        unicodeEmoji, htmlFn, smallTag, plainTag, boldTag, italicTag, strikeTag, urlAlt, big, boldAsta, italicAsta, //
        boldUnder, italicUnder, inlineCode, mathInline, strikeWave, fn, mention, hashtag, emojiCode, link, url, textP,
      ]));

  late final _P quote = _lazy(() {
    final lines = _seq([
      _str('>'),
      _space.option(),
      _seq([_notMatch(_newLine), _char]).select(1).many(0).text(),
    ]).select(2).sep(_newLine, 1);
    final parser = _seq([_newLine.option(), _newLine.option(), _lineBegin, lines, _newLine.option(), _newLine.option()]).select(3);
    return _P((input, index, state) {
      final r = parser.handler(input, index, state);
      if (r == null) return null;
      final contents = (r.value as List).cast<String>();
      final quoteIndex = r.index;
      // 1 行だけで空なら引用にしない
      if (contents.length == 1 && contents[0].isEmpty) return null;
      final contentParser = _nest(fullParser).many(0);
      final inner = contentParser.handler(contents.join('\n'), 0, state);
      if (inner == null) return null;
      return _Ok(quoteIndex, MfmNode.quote(_mergeText(inner.value as List)));
    });
  });

  late final _P codeBlock = _lazy(() {
    final mark = _str('```');
    return _seq([
      _newLine.option(),
      _lineBegin,
      mark,
      _seq([_notMatch(_newLine), _char]).select(1).many(0),
      _newLine,
      _seq([_notMatch(_seq([_newLine, mark, _lineEnd])), _char]).select(1).many(1),
      _newLine,
      mark,
      _lineEnd,
      _newLine.option(),
    ]).map((v) {
      final r = v as List;
      final lang = (r[3] as List).join().trim();
      final code = (r[5] as List).join();
      return MfmNode.codeBlock(code, lang.isNotEmpty ? lang : null);
    });
  });

  late final _P mathBlock = _lazy(() {
    final open = _str(r'\[');
    final close = _str(r'\]');
    return _seq([
      _newLine.option(),
      _lineBegin,
      open,
      _newLine.option(),
      _seq([_notMatch(_seq([_newLine.option(), close])), _char]).select(1).many(1),
      _newLine.option(),
      close,
      _lineEnd,
      _newLine.option(),
    ]).map((v) => MfmNode.mathBlock(((v as List)[4] as List).join()));
  });

  late final _P centerTag = _lazy(() {
    final open = _str('<center>');
    final close = _str('</center>');
    return _seq([
      _newLine.option(),
      _lineBegin,
      open,
      _newLine.option(),
      _seq([_notMatch(_seq([_newLine.option(), close])), _nest(inline)]).select(1).many(1),
      _newLine.option(),
      close,
      _lineEnd,
      _newLine.option(),
    ]).map((v) => MfmNode.center(_mergeText((v as List)[4] as List)));
  });

  /// `<open>…<close>` / `mark…mark` を seqOrText で(閉じなければ開きを文字に戻す)。
  _P _wrapped(_P open, _P close, MfmNode Function(List<MfmNode>) build, {_P? stop}) => _seqOrText([
        open,
        _seq([_notMatch(stop ?? close), _nest(inline)]).select(1).many(1),
        close,
      ]).map((v) => v is String ? v : build(_mergeText((v as List)[1] as List)));

  late final _P big = _lazy(() => _wrapped(_str('***'), _str('***'), (c) => MfmNode.fn('tada', const {}, c)));
  late final _P boldAsta = _lazy(() => _wrapped(_str('**'), _str('**'), MfmNode.bold));
  late final _P boldTag = _lazy(() => _wrapped(_str('<b>'), _str('</b>'), MfmNode.bold));
  late final _P smallTag = _lazy(() => _wrapped(_str('<small>'), _str('</small>'), MfmNode.small));
  late final _P italicTag = _lazy(() => _wrapped(_str('<i>'), _str('</i>'), MfmNode.italic));
  late final _P strikeTag = _lazy(() => _wrapped(_str('<s>'), _str('</s>'), MfmNode.strike));
  late final _P strikeWave = _lazy(() => _wrapped(_str('~~'), _str('~~'), MfmNode.strike, stop: _alt([_str('~~'), _newLine])));

  late final _P boldUnder = _lazy(() {
    final mark = _str('__');
    return _seq([mark, _alt([_alphaAndNum, _space]).many(1), mark]).map((v) => MfmNode.bold(_mergeText((v as List)[1] as List)));
  });

  _P _italicMark(String m) {
    final mark = _str(m);
    final parser = _seq([mark, _alt([_alphaAndNum, _space]).many(1), mark]);
    return _P((input, index, state) {
      final r = parser.handler(input, index, state);
      if (r == null) return null;
      if (_afterAlnum(input, index)) return null;
      return _Ok(r.index, MfmNode.italic(_mergeText((r.value as List)[1] as List)));
    });
  }

  late final _P italicAsta = _lazy(() => _italicMark('*'));
  late final _P italicUnder = _lazy(() => _italicMark('_'));

  late final _P unicodeEmoji = _lazy(() => _regexp(mfmEmojiRegexSource).map((content) => content == '️' ? content : MfmNode.unicodeEmoji(content as String)));

  late final _P plainTag = _lazy(() {
    final open = _str('<plain>');
    final close = _str('</plain>');
    return _seq([
      open,
      _newLine.option(),
      _seq([_notMatch(_seq([_newLine.option(), close])), _char]).select(1).many(1).text(),
      _newLine.option(),
      close,
    ]).select(2).map((t) => MfmNode.plain(t as String));
  });

  late final _P fn = _lazy(() {
    final fnName = _regexp(r'[a-z0-9_]+', caseInsensitive: true);
    final arg = _seq([
      _regexp(r'[a-z0-9_]+', caseInsensitive: true),
      _seq([_str('='), _regexp(r'[a-z0-9_.-]+', caseInsensitive: true)]).select(1).option(),
    ]).map((v) => (k: (v as List)[0] as String, v: (v[1] as String?) ?? true));
    final args = _seq([_str('.'), arg.sep(_str(','), 1)]).select(1).map((pairs) {
      final result = <String, Object>{};
      for (final p in (pairs as List).cast<({String k, Object v})>()) {
        result[p.k] = p.v;
      }
      return result;
    });
    final fnClose = _str(']');
    return _seqOrText([
      _str(r'$['),
      fnName,
      args.option(),
      _str(' '),
      _seq([_notMatch(fnClose), _nest(inline)]).select(1).many(1),
      fnClose,
    ]).map((v) {
      if (v is String) return v;
      final r = v as List;
      return MfmNode.fn(r[1] as String, (r[2] as Map<String, Object>?) ?? <String, Object>{}, _mergeText(r[4] as List));
    });
  });

  late final _P inlineCode = _lazy(() {
    final mark = _str('`');
    return _seq([
      mark,
      _seq([_notMatch(_alt([mark, _str('´'), _newLine])), _char]).select(1).many(1),
      mark,
    ]).map((v) => MfmNode.inlineCode(((v as List)[1] as List).join()));
  });

  late final _P mathInline = _lazy(() {
    final open = _str(r'\(');
    final close = _str(r'\)');
    return _seq([
      open,
      _seq([_notMatch(_alt([close, _newLine])), _char]).select(1).many(1),
      close,
    ]).map((v) => MfmNode.mathInline(((v as List)[1] as List).join()));
  });

  late final _P mention = _lazy(() {
    final parser = _seq([
      _notLinkLabel,
      _str('@'),
      _regexp(r'[a-z0-9_.-]+', caseInsensitive: true),
      _seq([_str('@'), _regexp(r'[a-z0-9_.-]+', caseInsensitive: true)]).select(1).option(),
    ]);
    final tail = RegExp(r'[.-]+$');
    final head = RegExp(r'^[.-]');
    return _P((input, index, state) {
      final r = parser.handler(input, index, state);
      if (r == null) return null;
      if (_afterAlnum(input, index)) return null;
      var invalid = false;
      final resultIndex = r.index;
      final username = (r.value as List)[2] as String;
      final hostname = (r.value as List)[3] as String?;
      // ホスト名の末尾の [.-] を落とす
      var host = hostname;
      if (hostname != null) {
        final ht = tail.firstMatch(hostname);
        if (ht != null) {
          host = hostname.substring(0, hostname.length - ht[0]!.length);
          if (host.isEmpty) {
            invalid = true;
            host = null;
          }
        }
      }
      // ユーザー名の末尾の [.-] を落とす(ホストがあるときは落とせない)
      var name = username;
      final ut = tail.firstMatch(username);
      if (ut != null) {
        if (host == null) {
          name = username.substring(0, username.length - ut[0]!.length);
        } else {
          invalid = true;
        }
      }
      if (name.isEmpty || head.hasMatch(name)) invalid = true;
      if (host != null && head.hasMatch(host)) invalid = true;
      if (invalid) return _Ok(resultIndex, input.substring(index, resultIndex));
      final acct = host != null ? '@$name@$host' : '@$name';
      return _Ok(index + acct.length, MfmNode.mention(name, host, acct));
    });
  });

  late final _P hashtag = _lazy(() {
    final mark = _str('#');
    final hashTagChar = _seq([
      _notMatch(_alt([_regexp(r'''[ 　\t.,!?'"#:/\[\]【】()「」（）<>]'''), _space, _newLine])), // l10n-ignore
      _char,
    ]).select(1);
    late final _P innerItem;
    innerItem = _lazy(() => _alt([
          _seq([_str('('), _nest(innerItem, hashTagChar).many(0), _str(')')]),
          _seq([_str('['), _nest(innerItem, hashTagChar).many(0), _str(']')]),
          _seq([_str('「'), _nest(innerItem, hashTagChar).many(0), _str('」')]), // l10n-ignore
          _seq([_str('（'), _nest(innerItem, hashTagChar).many(0), _str('）')]), // l10n-ignore
          hashTagChar,
        ]));
    final parser = _seq([_notLinkLabel, mark, innerItem.many(1).text()]).select(2);
    final digits = RegExp(r'^[0-9]+$');
    return _P((input, index, state) {
      final r = parser.handler(input, index, state);
      if (r == null) return null;
      if (_afterAlnum(input, index)) return null;
      final value = r.value as String;
      if (digits.hasMatch(value)) return null; // 数字だけは不可
      return _Ok(r.index, MfmNode.hashtag(value));
    });
  });

  late final _P emojiCode = _lazy(() {
    final side = _notMatch(_regexp(r'[a-z0-9]', caseInsensitive: true));
    final mark = _str(':');
    final plainName = _regexp(r'[a-z0-9_+-]+', caseInsensitive: true);
    // RASQ の拡張: `:name@host:` / `:name@.:`(state.emojiHost のときだけ)。
    final hostName = _regexp(r'[a-z0-9_+-]+(?:@[a-z0-9_.-]+)?', caseInsensitive: true);
    final name = _P((input, index, state) => (state.emojiHost ? hostName : plainName).handler(input, index, state));
    return _seq([_alt([_lineBegin, side]), mark, name, mark, _alt([_lineEnd, side])]).select(2).map((n) => MfmNode.emojiCode(n as String));
  });

  late final _P link = _lazy(() {
    final labelInline = _P((input, index, state) {
      state.linkLabel = true;
      final r = inline.handler(input, index, state);
      state.linkLabel = false;
      return r;
    });
    final closeLabel = _str(']');
    final openLabel = _seq([_notLinkLabel, _alt([_str('?['), _str('[')])]).select(1);
    final labelItem = _seq([_notMatch(_alt([closeLabel, _newLine])), _nest(labelInline)]).select(1);
    final afterLabel = _seq([closeLabel, _str('('), _alt([urlAlt, url]), _str(')')]).select(2);
    return _P((input, index, state) {
      final openResult = openLabel.handler(input, index, state);
      if (openResult == null) return null;
      final failed = _linkLabelFailures(input, state);
      final boundaries = <int>[];
      final label = <Object?>[];
      var latest = openResult.index;
      while (!failed.contains(latest)) {
        boundaries.add(latest);
        if (latest >= input.length) break;
        final item = labelItem.handler(input, latest, state);
        if (item == null) break;
        label.add(item.value);
        latest = item.index;
      }
      if (label.isEmpty) return null;
      final knownFailure = failed.contains(latest);
      final after = knownFailure ? null : afterLabel.handler(input, latest, state);
      if (after == null || after.value is String) {
        failed.addAll(boundaries);
        return null;
      }
      final silent = openResult.value == '?[';
      final urlNode = after.value as MfmNode;
      return _Ok(after.index, MfmNode.link(silent, urlNode.props!['url'] as String, _mergeText(label)));
    });
  });

  late final _P url = _lazy(() {
    final urlChar = _regexp(r'[.,a-z0-9_/:%#@$&?!~=+-]', caseInsensitive: true);
    late final _P innerItem;
    innerItem = _lazy(() => _alt([
          _seq([_str('('), _nest(innerItem, urlChar).many(0), _str(')')]),
          _seq([_str('['), _nest(innerItem, urlChar).many(0), _str(']')]),
          urlChar,
        ]));
    final parser = _seq([_notLinkLabel, _regexp(r'https?://'), innerItem.many(1).text()]);
    final trailing = RegExp(r'[.,]+$');
    return _P((input, index, state) {
      final r = parser.handler(input, index, state);
      if (r == null) return null;
      final resultIndex = r.index;
      var modifiedIndex = resultIndex;
      final schema = (r.value as List)[1] as String;
      var content = (r.value as List)[2] as String;
      // 右端の ".," を落とす
      final t = trailing.firstMatch(content);
      if (t != null) {
        modifiedIndex -= t[0]!.length;
        content = content.substring(0, content.length - t[0]!.length);
        if (content.isEmpty) return _Ok(resultIndex, input.substring(index, resultIndex));
      }
      return _Ok(modifiedIndex, MfmNode.url(schema + content));
    });
  });

  late final _P urlAlt = _lazy(() {
    final open = _str('<');
    final close = _str('>');
    final parser = _seq([
      _notLinkLabel,
      open,
      _regexp(r'https?://'),
      _seq([_notMatch(_alt([close, _space])), _char]).select(1).many(1),
      close,
    ]).text();
    return _P((input, index, state) {
      final r = parser.handler(input, index, state);
      if (r == null) return null;
      final text = r.value as String;
      return _Ok(r.index, MfmNode.url(text.substring(1, text.length - 1), brackets: true));
    });
  });

  late final _P search = _lazy(() {
    final button = _alt([
      _regexp(r'\[(検索|search)\]', caseInsensitive: true), // l10n-ignore
      _regexp(r'(検索|search)', caseInsensitive: true), // l10n-ignore
    ]);
    return _seq([
      _newLine.option(),
      _lineBegin,
      _seq([
        _notMatch(_alt([_newLine, _seq([_space, button, _lineEnd])])),
        _char,
      ]).select(1).many(1),
      _space,
      button,
      _lineEnd,
      _newLine.option(),
    ]).map((v) {
      final r = v as List;
      final query = (r[2] as List).join();
      return MfmNode.search(query, '$query${r[3]}${r[4]}');
    });
  });

  late final _P textP = _char;

  /// RASQ の拡張 (D-446): `<fn attr="v" flag>…</fn>` → `fn`。`<ruby>本<rt>ほん</rt></ruby>` は引数 `rt` に読み。
  late final _P htmlFn = _lazy(() {
    final openTag = RegExp(r'<([a-z][a-z0-9]*)((?:\s+[a-z][a-z0-9]*(?:="[^"<>]*")?)*)\s*>');
    final attr = RegExp(r'([a-z][a-z0-9]*)(?:="([^"<>]*)")?');
    final rtOpen = _str('<rt>');
    final rtText = _seq([_notMatch(_str('</rt>')), _char]).select(1).many(0).text();
    return _P((input, index, state) {
      if (!state.htmlFns) return null;
      final m = openTag.matchAsPrefix(input, index);
      if (m == null) return null;
      final tag = m[1]!;
      if (!mfmHtmlFnTags.contains(tag)) return null;
      final close = _str('</$tag>');
      final args = <String, Object>{for (final a in attr.allMatches(m[2] ?? '')) a[1]!: a[2] ?? true};
      final stop = tag == 'ruby' ? _alt([close, rtOpen]) : close;
      final body = _seq([_notMatch(stop), _nest(inline)]).select(1).many(1).handler(input, m.end, state);
      if (body == null) return null;
      var at = body.index;
      if (tag == 'ruby') {
        final rt = _seq([rtOpen, rtText, _str('</rt>')]).handler(input, at, state);
        if (rt != null) {
          args['rt'] = (rt.value as List)[1] as String;
          at = rt.index;
        }
      }
      final end = close.handler(input, at, state);
      if (end == null) return null;
      return _Ok(end.index, MfmNode.fn(tag, args, _mergeText(body.value as List)));
    });
  });
}
