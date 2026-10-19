// 文言の抽出の残り (D-484): lib/(と packages/*/lib)に残っている日本語の文字列リテラルを、領域 / ファイルごとに数える。
//
// 使い方:
//   dart run tool/l10n_audit.dart              # 領域ごとの件数と合計
//   dart run tool/l10n_audit.dart --files      # ファイルごとの件数も
//   dart run tool/l10n_audit.dart --list lib/shell   # その下のリテラルを 1 件ずつ(行番号つき)
//   dart run tool/l10n_audit.dart --json       # 機械向け(CI の記録用)
//
// 数えないもの: コメント(// /// /* */)、テスト(test/ は見ない)、生成物(lib/l10n/gen、*.g.dart)、
// ログ(debugPrint / print / log / assert / developer.log の引数)、行末に `// l10n-ignore` を付けた行
// (検索の語彙のような、訳さない日本語)、LLM への指示の文の表(`…/prompts/`、D-492)。日本語 = ひらがな / カタカナ / 漢字 / 全角の記号を 1 文字でも含む。
// 失敗はしない(件数を出すだけ)。抽出の進め方は docs/I18N.md。
import 'dart:convert';
import 'dart:io';

final _japanese = RegExp(r'[　-ヿ㐀-䶿一-鿿＀-￯]');
final _logCall = RegExp(r'\b(debugPrint|print|log|_log|assert|debugLog|developer\.log)\s*\($');

class Literal {
  Literal(this.file, this.line, this.text);
  final String file;
  final int line;
  final String text;
}

void main(List<String> args) {
  final showFiles = args.contains('--files');
  final json = args.contains('--json');
  final listIdx = args.indexOf('--list');
  final listPrefix = listIdx >= 0 && listIdx + 1 < args.length ? args[listIdx + 1] : null;
  final roots = <String>['lib', ...Directory('packages').existsSync() ? [for (final d in Directory('packages').listSync()) if (d is Directory && Directory('${d.path}/lib').existsSync()) '${d.path}/lib'] : const <String>[]];
  final found = <Literal>[];
  for (final root in roots..sort()) {
    for (final f in Directory(root).listSync(recursive: true).whereType<File>()) {
      final path = f.path.replaceAll('\\', '/');
      if (!path.endsWith('.dart') || path.endsWith('.g.dart') || path.contains('/l10n/gen/') || path.contains('/build/')) continue;
      // LLM への指示の文の表(D-492: lib/features/rai/prompts/rai_prompts_<言語>.dart)は、言語ごとの訳そのもの。
      if (path.contains('/prompts/')) continue;
      found.addAll(scanSource(path, f.readAsStringSync()));
    }
  }
  if (listPrefix != null) {
    for (final l in found.where((l) => l.file.startsWith(listPrefix))) {
      stdout.writeln('${l.file}:${l.line}: ${l.text.replaceAll('\n', r'\n')}');
    }
    stdout.writeln('${found.where((l) => l.file.startsWith(listPrefix)).length} literals');
    return;
  }
  final byArea = <String, int>{};
  final byFile = <String, int>{};
  for (final l in found) {
    byArea[areaOf(l.file)] = (byArea[areaOf(l.file)] ?? 0) + 1;
    byFile[l.file] = (byFile[l.file] ?? 0) + 1;
  }
  if (json) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({'total': found.length, 'areas': byArea, if (showFiles) 'files': byFile}));
    return;
  }
  final areas = byArea.keys.toList()..sort((a, b) => byArea[b]!.compareTo(byArea[a]!));
  for (final a in areas) {
    stdout.writeln('${byArea[a].toString().padLeft(6)}  $a');
    if (showFiles) {
      final files = byFile.keys.where((f) => areaOf(f) == a).toList()..sort((x, y) => byFile[y]!.compareTo(byFile[x]!));
      for (final f in files) {
        stdout.writeln('${''.padLeft(8)}${byFile[f].toString().padLeft(5)}  $f');
      }
    }
  }
  stdout.writeln('${found.length.toString().padLeft(6)}  合計(日本語を含む文字列リテラル)');
}

/// 領域: `lib/features/<x>` → `features/<x>`、`lib/<dir>` → `<dir>`、`packages/<p>/lib` → `packages/<p>`。
String areaOf(String path) {
  final p = path.split('/');
  if (p.first == 'packages') return 'packages/${p[1]}';
  if (p.length > 2 && p[1] == 'features') return p.length > 3 ? 'features/${p[2]}' : 'features';
  return p.length > 2 ? p[1] : 'lib';
}

/// Dart のソースから、日本語を含む文字列リテラルを拾う(コメントは飛ばす。補間 `${...}` の中も字句として辿る)。
List<Literal> scanSource(String path, String src) {
  final out = <Literal>[];
  final lines = src.split('\n');
  final lineStarts = <int>[0];
  for (var i = 0; i < src.length; i++) {
    if (src.codeUnitAt(i) == 0x0a) lineStarts.add(i + 1);
  }
  int lineOf(int offset) {
    var lo = 0, hi = lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo + 1;
  }

  // 文の頭(直前の ; { } )から、リテラルの前までにログの呼び出しがあるか。
  bool inLogCall(int start) {
    var depth = 0;
    for (var i = start - 1; i >= 0 && i > start - 400; i--) {
      final c = src[i];
      if (c == ')') depth++;
      if (c == '(') {
        if (depth == 0) {
          if (_logCall.hasMatch(src.substring((i - 30).clamp(0, i), i + 1))) return true;
        } else {
          depth--;
        }
      }
      if (c == ';' || c == '{' || c == '}') return false;
    }
    return false;
  }

  var i = 0;
  // 字句を辿る。[untilBrace] = 補間の中(対応する `}` で戻る)。
  void scan({bool untilBrace = false}) {
    var braces = 0;
    while (i < src.length) {
      final c = src[i];
      if (c == '/' && i + 1 < src.length && src[i + 1] == '/') {
        while (i < src.length && src[i] != '\n') {
          i++;
        }
        continue;
      }
      if (c == '/' && i + 1 < src.length && src[i + 1] == '*') {
        var depth = 0;
        while (i < src.length) {
          if (src.startsWith('/*', i)) {
            depth++;
            i += 2;
          } else if (src.startsWith('*/', i)) {
            depth--;
            i += 2;
            if (depth == 0) break;
          } else {
            i++;
          }
        }
        continue;
      }
      if (untilBrace) {
        if (c == '{') braces++;
        if (c == '}') {
          if (braces == 0) {
            i++;
            return;
          }
          braces--;
        }
      }
      if (c == '"' || c == "'") {
        final raw = i > 0 && src[i - 1] == 'r' && (i < 2 || !RegExp(r'[A-Za-z0-9_$]').hasMatch(src[i - 2]));
        final start = raw ? i - 1 : i;
        final triple = src.startsWith(c * 3, i);
        final q = triple ? c * 3 : c;
        i += q.length;
        final buf = StringBuffer();
        while (i < src.length && !src.startsWith(q, i)) {
          if (!raw && src[i] == '\\') {
            buf.write(src.substring(i, (i + 2).clamp(0, src.length)));
            i += 2;
            continue;
          }
          if (!raw && src.startsWith(r'${', i)) {
            buf.write(r'${…}');
            i += 2;
            scan(untilBrace: true);
            continue;
          }
          if (!triple && src[i] == '\n') break; // 壊れたリテラルは打ち切る
          buf.write(src[i]);
          i++;
        }
        i += q.length;
        final text = buf.toString();
        if (_japanese.hasMatch(text)) {
          final line = lineOf(start);
          final lineText = lines[line - 1];
          if (!lineText.contains('l10n-ignore') && !inLogCall(start)) out.add(Literal(path, line, text));
        }
        continue;
      }
      i++;
    }
  }

  scan();
  return out;
}
