// 文言の部品(parts)を 1 つの ARB にまとめる (D-484)。`flutter gen-l10n` の前に回す。
//
// 文言は領域ごとの部品ファイル `<arb-dir>/parts/<領域>.<言語>.arb` に書く(抽出を何本も並べて進めても、
// 1 つの大きな ARB で衝突しないように)。このツールが言語ごとに `<arb-dir>/<接頭辞>_<言語>.arb` へまとめる
// (gen-l10n が読むのはこちら。手で直さない)。対象 = このリポジトリの l10n.yaml と packages/*/l10n.yaml。
//
//   dart run tool/l10n_merge.dart          # まとめて書く
//   dart run tool/l10n_merge.dart --check  # 書かずに、まとめた結果がコミット済みと同じかだけ見る(CI)
//
// 約束(破っていたら失敗する):
// - 部品のキーは部品の名前の lowerCamelCase で始める(`settings_language.ja.arb` → `settingsLanguage…`)。
//   領域の違う 2 本の抽出が同じキーを作らないため。
// - 同じキーは 1 つの部品にだけ。`@キー`(説明・placeholders)は同じ部品に置く。
// - テンプレートの言語(l10n.yaml の template-arb-file の言語。今は ja)に無いキーを、ほかの言語の部品に書かない。
// ほかの言語の部品はキーが欠けていてよい(gen-l10n がテンプレートの文言に倒す)。
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final check = args.contains('--check');
  final configs = <File>[File('l10n.yaml'), if (Directory('packages').existsSync()) ...[for (final d in Directory('packages').listSync()..sort((a, b) => a.path.compareTo(b.path))) if (d is Directory && File('${d.path}/l10n.yaml').existsSync()) File('${d.path}/l10n.yaml')]];
  var failed = false;
  for (final cfg in configs.where((f) => f.existsSync())) {
    try {
      final stale = mergeProject(cfg, check: check);
      if (check && stale.isNotEmpty) {
        failed = true;
        stderr.writeln('l10n: 部品とまとめた ARB が食い違っています: ${stale.join(', ')}\n  `dart run tool/l10n_merge.dart && flutter gen-l10n` を回してコミットしてください。');
      }
    } on FormatException catch (e) {
      failed = true;
      stderr.writeln('l10n: ${cfg.path}: ${e.message}');
    }
  }
  if (failed) exit(1);
}

/// [cfg] の l10n.yaml のプロジェクトをまとめる。戻り = 中身が変わる(--check なら、食い違っている)ファイル。
List<String> mergeProject(File cfg, {required bool check}) {
  final root = cfg.parent.path;
  final yaml = _readYaml(cfg.readAsStringSync());
  final arbDir = '$root/${yaml['arb-dir'] ?? 'lib/l10n'}';
  final template = yaml['template-arb-file'] ?? 'app_en.arb';
  final m = RegExp(r'^(\w+?)_([a-zA-Z]{2,3}(?:_\w+)?)\.arb$').firstMatch(template);
  if (m == null) throw FormatException('template-arb-file の名前が <接頭辞>_<言語>.arb ではありません: $template');
  final prefix = m.group(1)!;
  final templateLocale = m.group(2)!;
  final partsDir = Directory('$arbDir/parts');
  if (!partsDir.existsSync()) throw FormatException('部品のディレクトリがありません: ${partsDir.path}');

  // 言語 → (部品の名前 → 中身)
  final byLocale = <String, Map<String, Map<String, Object?>>>{};
  final partRe = RegExp(r'^([a-z][a-z0-9_]*)\.([a-zA-Z]{2,3}(?:_\w+)?)\.arb$');
  final files = partsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.arb')).toList()..sort((a, b) => a.path.compareTo(b.path));
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    final pm = partRe.firstMatch(name);
    if (pm == null) throw FormatException('部品の名前は <領域>.<言語>.arb(領域は小文字と _): $name');
    final Object? decoded;
    try {
      decoded = jsonDecode(f.readAsStringSync());
    } on FormatException catch (e) {
      throw FormatException('$name: JSON として読めません: ${e.message}');
    }
    if (decoded is! Map) throw FormatException('$name: 中身が JSON のオブジェクトではありません');
    byLocale.putIfAbsent(pm.group(2)!, () => {})[pm.group(1)!] = decoded.cast<String, Object?>();
  }
  final templateParts = byLocale[templateLocale] ?? const {};
  final templateKeys = <String>{};
  final changed = <String>[];
  for (final locale in [templateLocale, ...byLocale.keys.where((l) => l != templateLocale).toList()..sort()]) {
    final parts = byLocale[locale] ?? const {};
    final merged = <String, Object?>{'@@locale': locale};
    final owner = <String, String>{};
    for (final part in parts.keys.toList()..sort()) {
      final keyPrefix = _camel(part);
      final content = parts[part]!;
      for (final e in content.entries) {
        if (e.key.startsWith('@@')) continue; // 部品の @@locale などは、まとめた側で付け直す
        final key = e.key.startsWith('@') ? e.key.substring(1) : e.key;
        if (!key.startsWith(keyPrefix)) throw FormatException('$part.$locale.arb: キー "$key" は "$keyPrefix" で始めてください');
        if (e.key.startsWith('@')) {
          if (!content.containsKey(key)) throw FormatException('$part.$locale.arb: "@$key" に対応する "$key" がありません');
        } else {
          if (e.value is! String) throw FormatException('$part.$locale.arb: "$key" の値が文字列ではありません');
          final prev = owner[key];
          if (prev != null) throw FormatException('キー "$key" が 2 つの部品にあります: $prev / $part');
          owner[key] = part;
          if (locale == templateLocale) {
            templateKeys.add(key);
          } else if (!templateKeys.contains(key)) {
            throw FormatException('$part.$locale.arb: "$key" はテンプレート($templateLocale)の部品にありません');
          }
        }
        merged[e.key] = e.value;
      }
    }
    if (locale != templateLocale && templateParts.isEmpty) continue;
    final out = File('$arbDir/${prefix}_$locale.arb');
    final text = '${const JsonEncoder.withIndent('  ').convert(merged)}\n';
    if (!out.existsSync() || out.readAsStringSync() != text) {
      changed.add(out.path);
      if (!check) out.writeAsStringSync(text);
    }
  }
  // 部品が無くなった言語のまとめを残さない。
  for (final f in Directory(arbDir).listSync().whereType<File>()) {
    final mm = RegExp('^${prefix}_(.+)\\.arb\$').firstMatch(f.uri.pathSegments.last);
    if (mm != null && !byLocale.containsKey(mm.group(1))) {
      changed.add(f.path);
      if (!check) f.deleteSync();
    }
  }
  if (!check) {
    stdout.writeln('l10n: $arbDir — ${templateKeys.length} keys, ${byLocale.length} locale(s)${changed.isEmpty ? '' : ', updated ${changed.length} file(s)'}');
  }
  return changed;
}

String _camel(String snake) {
  final p = snake.split('_');
  return p.first + [for (final s in p.skip(1)) if (s.isNotEmpty) s[0].toUpperCase() + s.substring(1)].join();
}

/// l10n.yaml の `key: value` の行だけ読む(ここで使うのは arb-dir と template-arb-file だけ)。
Map<String, String> _readYaml(String text) => {
      for (final line in const LineSplitter().convert(text))
        if (RegExp(r'^([\w-]+):\s*(\S.*?)\s*$').firstMatch(line.split(' #').first) case final m?) m.group(1)!: m.group(2)!.replaceAll(RegExp(r'''^["']|["']$'''), ''),
    };
