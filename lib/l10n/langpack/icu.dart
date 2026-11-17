import 'package:intl/intl.dart' show Intl;

/// 言語パック (D-592) の文を実行時に組み立てる、ICU の小さな読み手。
///
/// 読める範囲は gen-l10n(と tool/l10n_merge.dart)と同じ: 文字・`{名前}`・`{n, plural, =0{…} one{…} other{…}}`・
/// `{x, select, a{…} other{…}}`(入れ子も可)。引用符の逃がしは無い。名前でない `{` はそのまま文字。
/// 読めない文は [IcuMessage.parse] が [FormatException] を投げる(読み込むときにそのキーだけ捨てる)。
sealed class _Node {}

class _Text extends _Node {
  _Text(this.text);
  final String text;
}

class _Arg extends _Node {
  _Arg(this.name);
  final String name;
}

class _Choice extends _Node {
  _Choice(this.name, this.plural, this.options);
  final String name;
  final bool plural;
  final Map<String, List<_Node>> options;
}

/// 読んだ ICU の文。
class IcuMessage {
  IcuMessage._(this._nodes, this.names);

  final List<_Node> _nodes;

  /// 文の中で使っている差し込みの名前。
  final Set<String> names;

  static final _argRe = RegExp(r'\{\s*(\w+)\s*(?:,\s*(plural|select)\s*,\s*)?');
  static final _optRe = RegExp(r'(=?\w+)\s*\{');
  static const _pluralKeys = {'=0', 'zero', '=1', 'one', '=2', 'two', 'few', 'many', 'other'};

  /// [source] を読む。読めなければ [FormatException]。
  factory IcuMessage.parse(String source) {
    var i = 0;
    final names = <String>{};
    List<_Node> message({required bool nested}) {
      final out = <_Node>[];
      final buf = StringBuffer();
      void flush() {
        if (buf.isNotEmpty) out.add(_Text(buf.toString()));
        buf.clear();
      }

      while (i < source.length) {
        final c = source[i];
        if (c == '}') {
          if (!nested) throw const FormatException('対応しない } があります');
          break;
        }
        if (c != '{') {
          buf.write(c);
          i++;
          continue;
        }
        final m = _argRe.matchAsPrefix(source, i);
        if (m == null) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        i = m.end;
        final name = m.group(1)!;
        names.add(name);
        if (m.group(2) == null) {
          if (i >= source.length || source[i] != '}') throw FormatException('{$name が閉じていません');
          i++;
          out.add(_Arg(name));
          continue;
        }
        final plural = m.group(2) == 'plural';
        final options = <String, List<_Node>>{};
        while (true) {
          while (i < source.length && source[i].trim().isEmpty) {
            i++;
          }
          if (i < source.length && source[i] == '}') {
            i++;
            break;
          }
          final om = _optRe.matchAsPrefix(source, i);
          if (om == null) throw FormatException('${m.group(2)} の選択肢が読めません(位置 $i)');
          if (plural && !_pluralKeys.contains(om.group(1))) throw FormatException('plural の ${om.group(1)} は使えません');
          i = om.end;
          options[om.group(1)!] = message(nested: true);
          if (i >= source.length || source[i] != '}') throw FormatException('選択肢 ${om.group(1)} が閉じていません');
          i++;
        }
        if (!options.containsKey('other')) throw FormatException('${m.group(2)} に other がありません');
        out.add(_Choice(name, plural, options));
      }
      flush();
      return out;
    }

    final nodes = message(nested: false);
    if (i != source.length) throw const FormatException('余分な } があります');
    return IcuMessage._(nodes, names);
  }

  /// [args] で埋める。[locale] は plural の決まり(`ja` / `en` / `fr` …)。
  String format(Map<String, Object?> args, String locale) {
    final b = StringBuffer();
    void write(List<_Node> nodes) {
      for (final n in nodes) {
        switch (n) {
          case _Text(:final text):
            b.write(text);
          case _Arg(:final name):
            b.write(args[name] ?? '');
          case _Choice(:final name, :final plural, :final options):
            final v = args[name];
            if (plural) {
              final count = v is num ? v : num.tryParse('$v') ?? 0;
              final exact = count == count.roundToDouble() ? options['=${count.toInt()}'] : null;
              List<_Node> pick(String l) => Intl.pluralLogic<List<_Node>>(count,
                  locale: l, zero: options['zero'], one: options['one'], two: options['two'], few: options['few'], many: options['many'], other: options['other']!);
              List<_Node> chosen;
              try {
                chosen = exact ?? pick(locale);
              } catch (_) {
                // intl に plural の決まりが無い言語。
                chosen = exact ?? pick('en');
              }
              write(chosen);
            } else {
              write(options['$v'] ?? options['other']!);
            }
        }
      }
    }

    write(_nodes);
    return b.toString();
  }
}
