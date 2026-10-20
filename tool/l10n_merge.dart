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
//
// Flutter に依らない部品(packages/rasq_models・rasq_plugin_api・sns_misskey。D-533)は `flutter gen-l10n` を使えない
// (生成物が Flutter を要る)ので、設定を `l10n_dart.yaml` に書き、このツールが ARB から素の Dart の文言のクラスを作る
// (`output-dir/output-localization-file`。キーごとの getter / メソッド、言語ごとのクラス、`lookup<クラス>(タグ)`)。
// ICU は gen-l10n と同じ書き方の範囲(`{名前}`、`{n, plural, =0{…} one{…} other{…}}`、`{x, select, a{…} other{…}}`)。
// plural / select を使う部品は `package:intl` に依る。--check はこの生成物も見る。
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final check = args.contains('--check');
  final configs = <File>[
    File('l10n.yaml'),
    if (Directory('packages').existsSync())
      for (final d in Directory('packages').listSync()..sort((a, b) => a.path.compareTo(b.path)))
        if (d is Directory)
          for (final name in const ['l10n.yaml', 'l10n_dart.yaml'])
            if (File('${d.path}/$name').existsSync()) File('${d.path}/$name'),
  ];
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
  // 設定の静的なページ (D-535): assets/settings/*.rrl.json の `@l10n:<キー>` を引く表を、部品 settings_pages* から作る。
  if (cfg.uri.pathSegments.last == 'l10n.yaml' && cfg.parent.path == '.') {
    final assetParts = {for (final e in templateParts.entries) if (e.key.startsWith('settings_pages')) e.key: e.value};
    final out = File('$arbDir/asset_strings.g.dart');
    final text = generateAssetLookup(assetParts);
    if (!out.existsSync() || out.readAsStringSync() != text) {
      changed.add(out.path);
      if (!check) out.writeAsStringSync(text);
    }
  }
  // Flutter に依らない部品 (D-533): 素の Dart の文言のクラスを作る。
  if (cfg.uri.pathSegments.last == 'l10n_dart.yaml') {
    final outDir = '$root/${yaml['output-dir'] ?? 'lib/l10n/gen'}';
    final outFile = File('$outDir/${yaml['output-localization-file'] ?? '${prefix}_localizations.dart'}');
    final className = yaml['output-class'] ?? 'Localizations';
    final merged = <String, Map<String, Object?>>{
      for (final locale in byLocale.keys)
        locale: {for (final part in byLocale[locale]!.values) ...part}..removeWhere((k, _) => k.startsWith('@@')),
    };
    final text = generatePureDart(className, templateLocale, merged);
    if (!outFile.existsSync() || outFile.readAsStringSync() != text) {
      changed.add(outFile.path);
      if (!check) {
        outFile.parent.createSync(recursive: true);
        outFile.writeAsStringSync(text);
      }
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


// ── Flutter に依らない部品の文言のクラス (D-533) ─────────────────────────────

/// ICU の部品: 文字 / 差し込み / plural / select。
sealed class _Icu {}

class _IcuText extends _Icu {
  _IcuText(this.text);
  final String text;
}

class _IcuArg extends _Icu {
  _IcuArg(this.name);
  final String name;
}

class _IcuChoice extends _Icu {
  _IcuChoice(this.name, this.kind, this.options);
  final String name;
  final String kind; // plural / select
  final Map<String, List<_Icu>> options;
}

/// gen-l10n と同じ範囲の ICU を読む(引用符の逃がしは使わない)。
List<_Icu> _parseIcu(String s, String key) {
  var i = 0;
  List<_Icu> message({required bool nested}) {
    final out = <_Icu>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) out.add(_IcuText(buf.toString()));
      buf.clear();
    }

    while (i < s.length) {
      final c = s[i];
      if (c == '}') {
        if (!nested) throw FormatException('"$key": 対応しない } があります');
        break;
      }
      if (c != '{') {
        buf.write(c);
        i++;
        continue;
      }
      // {名前} / {名前, plural|select, …}
      final m = RegExp(r'\{\s*(\w+)\s*(?:,\s*(plural|select)\s*,\s*)?').matchAsPrefix(s, i);
      if (m == null) {
        // 名前でない { はそのまま文字(gen-l10n も同じ)。
        buf.write(c);
        i++;
        continue;
      }
      flush();
      i = m.end;
      if (m.group(2) == null) {
        if (i >= s.length || s[i] != '}') throw FormatException('"$key": {${m.group(1)} が閉じていません');
        i++;
        out.add(_IcuArg(m.group(1)!));
        continue;
      }
      final options = <String, List<_Icu>>{};
      while (true) {
        while (i < s.length && s[i].trim().isEmpty) {
          i++;
        }
        if (i < s.length && s[i] == '}') {
          i++;
          break;
        }
        final om = RegExp(r'(=?\w+)\s*\{').matchAsPrefix(s, i);
        if (om == null) throw FormatException('"$key": ${m.group(2)} の選択肢が読めません(位置 $i)');
        i = om.end;
        options[om.group(1)!] = message(nested: true);
        if (i >= s.length || s[i] != '}') throw FormatException('"$key": 選択肢 ${om.group(1)} が閉じていません');
        i++;
      }
      if (!options.containsKey('other')) throw FormatException('"$key": ${m.group(2)} に other がありません');
      out.add(_IcuChoice(m.group(1)!, m.group(2)!, options));
    }
    flush();
    return out;
  }

  final r = message(nested: false);
  if (i != s.length) throw FormatException('"$key": 余分な } があります');
  return r;
}

String _dartLiteral(List<_Icu> nodes, Set<String> args, String key) {
  final b = StringBuffer("'");
  for (final n in nodes) {
    switch (n) {
      case _IcuText(:final text):
        b.write(text.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$').replaceAll('\n', r'\n'));
      case _IcuArg(:final name):
        if (!args.contains(name)) throw FormatException('"$key": プレースホルダ $name が @$key.placeholders にありません');
        b.write('\${$name}');
      case _IcuChoice(:final name, :final kind, :final options):
        if (!args.contains(name)) throw FormatException('"$key": プレースホルダ $name が @$key.placeholders にありません');
        if (kind == 'plural') {
          const named = {'=0': 'zero', 'zero': 'zero', '=1': 'one', 'one': 'one', '=2': 'two', 'two': 'two', 'few': 'few', 'many': 'many', 'other': 'other'};
          final parts = [
            for (final e in options.entries)
              if (named[e.key] case final p?) '$p: ${_dartLiteral(e.value, args, key)}' else throw FormatException('"$key": plural の ${e.key} は使えません'),
          ];
          b.write('\${intl.Intl.pluralLogic($name, locale: localeName, ${parts.join(', ')})}');
        } else {
          final parts = [for (final e in options.entries) "'${e.key}': ${_dartLiteral(e.value, args, key)}"];
          b.write('\${intl.Intl.selectLogic($name, {${parts.join(', ')}})}');
        }
    }
  }
  b.write("'");
  return b.toString();
}

bool _usesChoice(List<_Icu> nodes) => nodes.any((n) => n is _IcuChoice);

String _localeSuffix(String locale) => locale.split(RegExp('[_-]')).map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1).toLowerCase()).join();

/// 素の Dart の文言のクラス(Flutter に依らない部品)。[byLocale] = 言語 → まとめた ARB(`@キー` を含む)。
String generatePureDart(String className, String templateLocale, Map<String, Map<String, Object?>> byLocale) {
  final template = byLocale[templateLocale] ?? const {};
  final keys = [for (final k in template.keys) if (!k.startsWith('@')) k]..sort();
  final params = <String, List<(String, String)>>{};
  final descriptions = <String, String>{};
  var intlNeeded = false;
  final parsed = <String, Map<String, List<_Icu>>>{};
  for (final k in keys) {
    final meta = (template['@$k'] as Map?)?.cast<String, Object?>() ?? const {};
    descriptions[k] = '${meta['description'] ?? ''}';
    final ph = (meta['placeholders'] as Map?)?.cast<String, Object?>() ?? const {};
    params[k] = [
      for (final e in ph.entries)
        (e.key, switch ('${(e.value as Map?)?['type'] ?? 'Object'}') { 'String' => 'String', 'int' => 'int', 'num' => 'num', 'double' => 'double', _ => 'Object' }),
    ];
  }
  final locales = [templateLocale, ...byLocale.keys.where((l) => l != templateLocale).toList()..sort()];
  for (final locale in locales) {
    final m = byLocale[locale]!;
    for (final k in keys) {
      final v = m[k];
      if (v is! String) continue;
      final nodes = _parseIcu(v, k);
      if (_usesChoice(nodes)) intlNeeded = true;
      (parsed[locale] ??= {})[k] = nodes;
    }
  }
  String sig(String k) {
    final p = params[k]!;
    return p.isEmpty ? 'String get $k' : 'String $k(${[for (final (n, t) in p) '$t $n'].join(', ')})';
  }

  String body(String locale, String k) => _dartLiteral(parsed[locale]![k]!, {for (final (n, _) in params[k]!) n}, k);

  final b = StringBuffer()
    ..writeln('// tool/l10n_merge.dart が lib/l10n/parts/*.arb から作る(手で直さない)。Flutter に依らない部品の文言 (D-533、docs/I18N.md)。')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln();
  if (intlNeeded) b.writeln("import 'package:intl/intl.dart' as intl;\n");
  b
    ..writeln('/// 文言(言語ごとの実装は [lookup$className])。')
    ..writeln('abstract class $className {')
    ..writeln('  const $className(this.localeName);')
    ..writeln()
    ..writeln('  /// この文言の言語(`$templateLocale` など)。')
    ..writeln('  final String localeName;')
    ..writeln()
    ..writeln('  /// 訳のある言語。')
    ..writeln("  static const supportedLocales = <String>[${locales.map((l) => "'$l'").join(', ')}];");
  for (final k in keys) {
    b.writeln();
    for (final line in const LineSplitter().convert(descriptions[k]!.isEmpty ? k : descriptions[k]!)) {
      b.writeln('  /// $line');
    }
    b.writeln('  ///');
    b.writeln("  /// $templateLocale: **${jsonEncode(template[k])}**");
    b.writeln('  ${sig(k)};');
  }
  b.writeln('}');
  for (final locale in locales) {
    final cls = '$className${_localeSuffix(locale)}';
    final base = locale == templateLocale ? className : '$className${_localeSuffix(templateLocale)}';
    b
      ..writeln()
      ..writeln('/// `$locale` の文言${locale == templateLocale ? '(テンプレート)' : '(訳の無いキーは $templateLocale の文言)'}。')
      ..writeln('class $cls extends $base {')
      ..writeln("  const $cls([super.localeName = '$locale']);");
    for (final k in keys) {
      if (parsed[locale]?[k] == null) continue;
      b
        ..writeln()
        ..writeln('  @override')
        ..writeln('  ${sig(k)} => ${body(locale, k)};');
    }
    b.writeln('}');
  }
  b
    ..writeln()
    ..writeln('/// [tag](BCP-47。`ja` / `en-US` / `zh_Hant`)の文言。そのタグ → 言語だけ → `$templateLocale` の順に倒す。')
    ..writeln('$className lookup$className(String tag) {')
    ..writeln("  final t = tag.replaceAll('_', '-').toLowerCase();")
    ..writeln('  for (final c in [t, t.split(\'-\').first]) {')
    ..writeln('    switch (c) {');
  for (final locale in locales) {
    b.writeln("      case '${locale.replaceAll('_', '-').toLowerCase()}':");
    b.writeln('        return const $className${_localeSuffix(locale)}();');
  }
  b
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('  return const $className${_localeSuffix(templateLocale)}();')
    ..writeln('}');
  return b.toString();
}


// ── 設定の静的なページの文言の参照 (D-535) ─────────────────────────────

/// `appAssetString(l, key, args)`: アセットのキー → `AppLocalizations` の文言。プレースホルダは [args] から(String / 数)。
String generateAssetLookup(Map<String, Map<String, Object?>> parts) {
  final keys = <String>[
    for (final part in parts.values)
      for (final k in part.keys)
        if (!k.startsWith('@')) k,
  ]..sort();
  final all = {for (final part in parts.values) ...part};
  final b = StringBuffer()
    ..writeln('// tool/l10n_merge.dart が lib/l10n/parts/settings_pages*.ja.arb から作る(手で直さない)。')
    ..writeln('// 設定の静的なページ(assets/settings/*.rrl.json)の文言の参照 `@l10n:<キー>` を引く表 (D-535、docs/I18N.md)。')
    ..writeln('// ignore_for_file: type=lint')
    ..writeln()
    ..writeln("import 'gen/app_localizations.dart';")
    ..writeln()
    ..writeln('/// アセットの文言のキー → 表示の言語の文言。知らないキーは null。プレースホルダは [args](`{"\$l10n": キー, "args": {…}}`)から。')
    ..writeln('String? appAssetString(AppLocalizations l, String key, [Map<String, Object?> args = const {}]) => switch (key) {');
  for (final k in keys) {
    final ph = ((all['@$k'] as Map?)?['placeholders'] as Map?)?.cast<String, Object?>() ?? const {};
    final argList = [
      for (final e in ph.entries)
        switch ('${(e.value as Map?)?['type'] ?? 'String'}') {
          'int' => "(args['${e.key}'] as num?)?.toInt() ?? 0",
          'num' || 'double' => "(args['${e.key}'] as num?) ?? 0",
          _ => "'\${args['${e.key}'] ?? ''}'",
        },
    ];
    b.writeln(ph.isEmpty ? "      '$k' => l.$k," : "      '$k' => l.$k(${argList.join(', ')}),");
  }
  b
    ..writeln('      _ => null,')
    ..writeln('    };');
  return b.toString();
}
