// 文言の正本(言語パックのリポジトリ orgate-question/langpack の公式パック packs/official)と、このリポジトリの写しを
// そろえる (D-592、docs/I18N.md「言語パック」)。
//
//   dart run tool/langpack_sync.dart pull  [--langpack ../langpack]  # langpack → このリポジトリ(写しを正本と同じにする)
//   dart run tool/langpack_sync.dart push  [--langpack ../langpack]  # このリポジトリで足した / 消したキーを langpack へ
//   dart run tool/langpack_sync.dart check [--langpack ../langpack]  # 食い違いを見る(あれば 1 で終わる)
//
// langpack の場所は `--langpack` か環境変数 `RASQ_LANGPACK`(どちらも無ければ ../langpack)。
//
// - **正本は langpack**。文言の言い回しを直す・訳すのは langpack で行い、pull で取り込む(pull はファイルを丸ごと写し、
//   正本に無いファイルは消す)。取り込んだ langpack のコミットは lib/l10n/langpack.lock.json に残す。
// - 機能を足して新しいキー(ja)をこのリポジトリで書いたときは push で langpack に足す(ファイルが無ければ丸ごと)。push は
//   langpack に既にあるキーの値を書き換えない(違えば知らせるだけ)。ただし ja のプレースホルダが変わったキーは、コードが
//   それに合わせて変わっているので、ja の値と `@キー` をこちらの値にする。ja から消したキーは langpack の全部の言語から消す。
//   push のあとは langpack でコミット → MR、入ったら pull。
// - 写しの置き場(領域 → このリポジトリのフォルダ)は [domains]。プラグインの文(packs/official/plugins)は rasq-sdk-sample が
//   元なので、ここでは扱わない(langpack の `tool/langpack.dart import-plugins`)。
import 'dart:convert';
import 'dart:io';

/// langpack の packs/official の下のフォルダ → このリポジトリのフォルダ。
const domains = {
  'app': 'lib/l10n/parts',
  'rasq_design': 'packages/rasq_design/lib/l10n/parts',
  'rasq_models': 'packages/rasq_models/lib/l10n/parts',
  'rasq_plugin_api': 'packages/rasq_plugin_api/lib/l10n/parts',
  'sns_misskey': 'packages/sns_misskey/lib/l10n/parts',
  'rai': 'lib/features/rai/prompts/parts',
};

const lockFile = 'lib/l10n/langpack.lock.json';
const packDir = 'packs/official';
const repoUrl = 'http://tui.tail346b42.ts.net:8929/orgate-question/langpack.git';

void main(List<String> args) {
  if (args.isEmpty || !const {'pull', 'push', 'check'}.contains(args.first)) {
    stderr.writeln('使い方: dart run tool/langpack_sync.dart pull|push|check [--langpack <langpack のフォルダ>]');
    exit(64);
  }
  final i = args.indexOf('--langpack');
  final root = i >= 0 && i + 1 < args.length ? args[i + 1] : (Platform.environment['RASQ_LANGPACK'] ?? '../langpack');
  final official = Directory('$root/$packDir');
  if (!official.existsSync()) {
    stderr.writeln('langpack: $root/$packDir がありません(--langpack で langpack の clone を指してください)');
    exit(1);
  }
  switch (args.first) {
    case 'pull':
      pull(root);
    case 'push':
      push(root);
    case 'check':
      final diffs = differences(root);
      for (final d in diffs) {
        stdout.writeln(d);
      }
      if (diffs.isNotEmpty) {
        stderr.writeln('langpack: 写しが正本と ${diffs.length} か所違います(正本を取り込むなら pull、こちらのキーを足すなら push)');
        exit(1);
      }
      stdout.writeln('langpack: 写しは正本と同じです');
  }
}

bool _isPart(File f) => RegExp(r'^[a-z][a-z0-9_]*\.[a-zA-Z]{2,3}(?:_\w+)?\.(arb|json)$').hasMatch(f.uri.pathSegments.last);

Map<String, File> _files(String dir) => {
      if (Directory(dir).existsSync())
        for (final f in Directory(dir).listSync().whereType<File>())
          if (_isPart(f)) f.uri.pathSegments.last: f,
    };

/// 食い違い(`+ ファイル` = 正本にだけ、`- ファイル` = 写しにだけ、`~ ファイル` = 中身が違う)。
List<String> differences(String root) {
  final out = <String>[];
  for (final e in domains.entries) {
    final src = _files('$root/$packDir/${e.key}');
    final dst = _files(e.value);
    for (final n in ({...src.keys, ...dst.keys}.toList()..sort())) {
      final s = src[n], d = dst[n];
      if (d == null) {
        out.add('+ ${e.value}/$n');
      } else if (s == null) {
        out.add('- ${e.value}/$n');
      } else if (s.readAsStringSync() != d.readAsStringSync()) {
        out.add('~ ${e.value}/$n');
      }
    }
  }
  return out;
}

String _git(String root, List<String> args) {
  try {
    // nosemgrep: rasq-client-subprocess — 開発用の道具(アプリには入らない)。langpack の clone のコミットを lock に書くための git だけ。引数は配列で渡し、シェルは通さない。
    final r = Process.runSync('git', ['-C', root, ...args]);
    return r.exitCode == 0 ? '${r.stdout}'.trim() : '';
  } catch (_) {
    return '';
  }
}

void pull(String root) {
  var n = 0;
  for (final e in domains.entries) {
    final src = _files('$root/$packDir/${e.key}');
    final dst = _files(e.value);
    Directory(e.value).createSync(recursive: true);
    for (final s in src.entries) {
      final text = s.value.readAsStringSync();
      final d = dst[s.key];
      if (d != null && d.readAsStringSync() == text) continue;
      File('${e.value}/${s.key}').writeAsStringSync(text);
      n++;
    }
    for (final d in dst.entries) {
      if (!src.containsKey(d.key)) {
        d.value.deleteSync();
        n++;
      }
    }
  }
  final manifest = jsonDecode(File('$root/$packDir/pack.json').readAsStringSync()) as Map;
  final lock = {
    'repo': repoUrl,
    'pack': packDir,
    'version': manifest['version'],
    'commit': _git(root, ['rev-parse', 'HEAD']),
    if (_git(root, ['status', '--porcelain', '--', packDir]).isNotEmpty) 'dirty': true,
  };
  File(lockFile).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(lock)}\n');
  stdout.writeln('langpack: $n ファイルを取り込みました(${lock['commit']}${lock['dirty'] == true ? '、コミットしていない変更を含む' : ''})。'
      '続けて `dart run tool/l10n_merge.dart && flutter gen-l10n && (cd packages/rasq_design && flutter gen-l10n)` を回してください');
}

Map<String, Object?> _json(File f) => (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
String _encode(Map<String, Object?> m) => '${const JsonEncoder.withIndent('  ').convert(m)}\n';
String _locale(String name) => name.split('.')[1];
String _part(String name) => name.split('.').first;
Set<String> _keys(Map<String, Object?> m) => {for (final k in m.keys) if (!k.startsWith('@')) k};
Object? _placeholders(Map<String, Object?> m, String key) => jsonEncode(((m['@$key'] as Map?)?['placeholders']) ?? const {});

void push(String root) {
  final notes = <String>[];
  var written = 0;
  for (final e in domains.entries) {
    final dstDir = '$root/$packDir/${e.key}';
    Directory(dstDir).createSync(recursive: true);
    final mine = _files(e.value);
    final theirs = _files(dstDir);
    // こちらの ja の部品 → キー(消したキーを知るため)。
    final jaKeys = <String, Set<String>>{
      for (final f in mine.entries)
        if (_locale(f.key) == 'ja') _part(f.key): _keys(_json(f.value)),
    };
    for (final f in mine.entries) {
      final t = theirs[f.key];
      if (t == null) {
        File('$dstDir/${f.key}').writeAsStringSync(f.value.readAsStringSync());
        notes.add('+ ${e.key}/${f.key}');
        written++;
        continue;
      }
      final a = _json(f.value);
      final b = _json(t);
      final next = <String, Object?>{...b};
      final isJa = _locale(f.key) == 'ja';
      for (final k in _keys(a)) {
        if (!b.containsKey(k)) {
          next[k] = a[k];
          if (a.containsKey('@$k')) next['@$k'] = a['@$k'];
          notes.add('+ ${e.key}/${f.key}: $k');
        } else if (isJa && _placeholders(a, k) != _placeholders(b, k)) {
          next[k] = a[k];
          if (a.containsKey('@$k')) next['@$k'] = a['@$k'];
          notes.add('! ${e.key}/${f.key}: $k のプレースホルダが変わったので、こちらの値にしました');
        } else if (a[k] != b[k]) {
          notes.add('= ${e.key}/${f.key}: $k は langpack の値のまま(こちらと違う。取り込むなら pull)');
        }
      }
      // ja から消したキーは、どの言語からも消す。
      final keep = jaKeys[_part(f.key)];
      if (keep != null) {
        for (final k in _keys(b)) {
          if (!keep.contains(k)) {
            next.remove(k);
            next.remove('@$k');
            notes.add('- ${e.key}/${f.key}: $k');
          }
        }
      }
      if (_encode(next) != _encode(b)) {
        File('$dstDir/${f.key}').writeAsStringSync(_encode(next));
        written++;
      }
    }
    // こちらの ja に無くなった部品は、langpack から部品ごと消す。
    for (final t in theirs.entries) {
      if (!jaKeys.containsKey(_part(t.key))) {
        t.value.deleteSync();
        notes.add('- ${e.key}/${t.key}');
        written++;
      }
    }
  }
  for (final n in notes) {
    stdout.writeln(n);
  }
  stdout.writeln('langpack: $written ファイルを書きました。$root で `dart run tool/langpack.dart check` → コミット → MR、入ったら pull してください');
}
