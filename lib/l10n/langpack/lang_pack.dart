import 'dart:convert';

import 'icu.dart';

/// 言語パック (D-592、docs/I18N.md「言語パック」)。
///
/// アプリの文言は同梱している(公式の言語パック = orgate-question/langpack の `packs/official` の写しから生成したクラス)。
/// 利用者は非公式の言語パック(ユーザーが作った訳など)を `.rasqlang` のファイルから読み込める。読み込んだパックの文は、
/// 文言のクラスの上書きの層(`…Overlay`)が先に引き、パックに無いキー・壊れていて捨てたキーは同梱の文言に戻る。
///
/// `.rasqlang` は JSON 1 つ(langpack の `dart run tool/langpack.dart build` が作る。形は langpack の docs/FORMAT.md):
///
/// ```json
/// {"format": "rasq-langpack", "formatVersion": 1,
///  "id": "com.example.kansai", "name": {"ja": "関西弁"}, "version": "1.0.0", "authors": ["…"],
///  "license": "CC-BY-4.0", "description": "…", "official": false, "app": {"min": "0.1.0"},
///  "locales": {"ja": {}, "fr": {"base": "en", "name": "Français"}},
///  "strings": {"ja": {"app": {"<キー>": "<文>"}, "rai": {…}, "plugin:<プラグインの id>": {…}}}}
/// ```
///
/// - 領域: `app` / `rasq_design` / `rasq_models` / `rasq_plugin_api` / `sns_misskey`(ARB と同じ ICU の文)、`rai`(RAi の
///   指示の文。`{名前}` の差し込みだけ)、`plugin:<id>`(プラグインの文。`manifest.name` などはマニフェストの文、ほかはプラグインの
///   kit の表のキーで、`args.localeStrings` で渡す)。
/// - 同梱に無い言語(`fr` など)も足せる。`base` = 足りないキーを引く同梱の言語(Material の訳がある言語だけ)。
/// - `official` は自己申告で、アプリは信用しない(ファイルから読み込んだパックはいつも「未審査」)。

/// `.rasqlang` の `format`。
const langPackFormat = 'rasq-langpack';

/// 読める `formatVersion`。
const langPackFormatVersion = 1;

/// ファイルの大きさの上限。
const langPackMaxBytes = 16 * 1024 * 1024;

/// 1 つの文の長さの上限(文字)。
const langPackMaxValueLength = 20000;

/// 読み込めなかった理由。
enum LangPackError { tooLarge, notPack, unsupportedVersion, badManifest, noLocales }

class LangPackException implements Exception {
  const LangPackException(this.error, [this.detail = '']);
  final LangPackError error;
  final String detail;
  @override
  String toString() => 'LangPackException(${error.name}${detail.isEmpty ? '' : ': $detail'})';
}

/// 捨てたキー(または言語)と理由(パックを作る人向けの、訳さない短い説明)。
class LangPackIssue {
  const LangPackIssue(this.locale, this.domain, this.key, this.reason);
  final String locale;
  final String domain;
  final String key;
  final String reason;
  @override
  String toString() => '$locale ${domain.isEmpty ? '' : '$domain/'}$key: $reason';
}

/// 読み込みの結果。
class LangPackReport {
  const LangPackReport({required this.applied, required this.unknown, required this.rejected, required this.coverage, this.needsNewerApp = false});

  /// 使う文の数(全部の言語・領域)。
  final int applied;

  /// アプリが知らないキー(古いキー・綴りの誤り)。無視した。
  final int unknown;

  /// 捨てたキー・言語。
  final List<LangPackIssue> rejected;

  /// 言語 → アプリの文言(領域 `app`)のうち、パックが持つ割合(0〜1)。
  final Map<String, double> coverage;

  /// パックの `app.min` がこのアプリより新しい(足りないキーは同梱の文言になる)。
  final bool needsNewerApp;
}

/// パックの 1 言語。
class LangPackLocale {
  const LangPackLocale({required this.tag, required this.base, this.name});

  /// パックに書いてあるタグ(`ja` / `zh_Hant` / `fr`)。
  final String tag;

  /// 足りないキーを引く同梱の言語(同梱の言語ならそれ自身)。gen-l10n の形(`ja` / `zh_Hant`)。
  final String base;

  /// その言語の名前(パックが足した言語の、言語の一覧に出す名前)。
  final String? name;

  /// 同梱に無い言語か。
  bool get added => normLangTag(base) != normLangTag(tag);
}

/// 検証の基準(アプリが同梱している文言の形)。
class LangPackSchema {
  const LangPackSchema({required this.icuDomains, required this.raiParams, required this.raiFunctionNames, required this.bundledLocales, required this.canAddLanguage});

  /// ICU の領域 → キー → 使えるプレースホルダ。
  final Map<String, Map<String, List<String>>> icuDomains;

  /// RAi の指示の文のキー → 差し込める名前。
  final Map<String, List<String>> raiParams;

  /// RAi の関数の一覧(`functionUsage`)の行ごとの関数名(同梱の日本語の表)。パックの行も同じでなければ捨てる。
  final List<List<String>> raiFunctionNames;

  /// 同梱の言語(gen-l10n の形: `ja` / `en` / `zh` / `zh_Hant` / `ko`)。
  final List<String> bundledLocales;

  /// 同梱に無い言語を足してよいか(Material の訳がある言語)。
  final bool Function(String languageCode) canAddLanguage;
}

/// タグを比べる形(小文字、`-` 区切り)。
String normLangTag(String tag) => tag.trim().replaceAll('_', '-').toLowerCase();

/// RAi の関数の一覧の行の関数名(`raiFunctionUsageFor` と同じ読み方)。
List<String> raiUsageNames(String line) => [for (final m in RegExp(r'(?:^|・)([a-z][\w.]*)\(').allMatches(line.split(': ').first)) m.group(1)!];

final _slot = RegExp(r'\{(\w+)\}');
final _pluginKey = RegExp(r'^[A-Za-z0-9_.\-]+$');
final _manifestKey = RegExp(r'^manifest\.(?:name|description|pageTitle|(?:actions|assets)\.[A-Za-z0-9_.\-]+\.label)$');
final _id = RegExp(r'^[a-z0-9][a-z0-9._-]{2,63}$');
final _semver = RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.\-+]*)?$');

/// 読み込んだ言語パック。
class LangPack {
  LangPack._(
    this._entries, {
    required this.id,
    required this.names,
    required this.version,
    required this.authors,
    required this.license,
    required this.description,
    required this.claimsOfficial,
    required this.appMin,
    required this.homepage,
    required this.locales,
    required this.report,
  });

  final String id;

  /// 言語 → 名前(`""` = どの言語でもない名前)。
  final Map<String, String> names;
  final String version;
  final List<String> authors;
  final String license;
  final String description;

  /// パックが自分で「公式」と書いているか(信用しない。表示もしない)。
  final bool claimsOfficial;
  final String? appMin;
  final String? homepage;

  /// 正規化したタグ → 言語。
  final Map<String, LangPackLocale> locales;
  final LangPackReport report;

  /// 正規化したタグ → 領域 → キー → [IcuMessage](ICU の領域)/ String(`rai` / `plugin:`)。
  final Map<String, Map<String, Map<String, Object>>> _entries;

  /// [tag] の言語での名前(無ければ言語の無い名前 → 最初の名前 → id)。
  String nameFor(String tag) {
    for (final c in _candidates(tag)) {
      for (final e in names.entries) {
        if (normLangTag(e.key) == c) return e.value;
      }
    }
    return names[''] ?? (names.values.isEmpty ? id : names.values.first);
  }

  /// パックが足した言語(同梱に無い言語)。
  Iterable<LangPackLocale> get addedLocales => locales.values.where((l) => l.added);

  /// [locale] から引く順の、パックが持つ言語のタグ。繁体字(`zh-Hant` / 台湾・香港・マカオ)は簡体字の `zh` に倒さない。
  List<String> _candidates(String locale) {
    final parts = normLangTag(locale).split('-').where((p) => p.isNotEmpty).toList();
    final hant = parts.contains('hant') || (parts.isNotEmpty && parts.first == 'zh' && parts.any((p) => const {'tw', 'hk', 'mo'}.contains(p)));
    return [
      for (var n = parts.length; n > 0; n--)
        if (!(hant && n == 1 && parts.first == 'zh')) parts.take(n).join('-'),
      if (hant && parts.length > 1 && parts[1] != 'hant') 'zh-hant',
    ];
  }

  Map<String, Object>? _domain(String locale, String domain) {
    for (final c in _candidates(locale)) {
      final d = _entries[c]?[domain];
      if (d != null) return d;
    }
    return null;
  }

  /// [locale] の言語・領域 [domain]・キー [key] の文([args] で埋めたもの)。無ければ null。
  String? lookup(String locale, String domain, String key, Map<String, Object?> args) {
    final v = _domain(locale, domain)?[key];
    switch (v) {
      case IcuMessage():
        return v.format(args, locale.replaceAll('-', '_'));
      case String():
        return args.isEmpty ? v : v.replaceAllMapped(_slot, (m) => args.containsKey(m[1]) ? '${args[m[1]]}' : m[0]!);
      default:
        return null;
    }
  }

  /// プラグイン [pluginId] に渡す [locale] の文の表(マニフェストのキーを除く)。無ければ null。
  Map<String, String>? pluginStrings(String pluginId, String locale) {
    final d = _domain(locale, 'plugin:$pluginId');
    if (d == null) return null;
    final out = {for (final e in d.entries) if (!e.key.startsWith('manifest.') && e.value is String) e.key: e.value as String};
    return out.isEmpty ? null : out;
  }

  /// [locale](パックが足した言語なら)の、足りないキーを引く同梱の言語。それ以外は [locale] のまま。
  String baseTagOf(String locale) {
    final l = locales[normLangTag(locale)] ?? locales[normLangTag(locale).split('-').first];
    return l != null && l.added ? l.base.replaceAll('_', '-') : locale;
  }

  /// `.rasqlang` の [bytes] を読み、[schema] で確かめる。形の壊れたキーはそのキーだけ捨て(結果の [report])、
  /// パック全体が読めなければ [LangPackException]。[appVersion] はこのアプリの版(`0.1.0`)。
  static LangPack parse(List<int> bytes, LangPackSchema schema, {String? appVersion}) {
    if (bytes.length > langPackMaxBytes) throw LangPackException(LangPackError.tooLarge, '${bytes.length}');
    final Object? root;
    try {
      root = jsonDecode(utf8.decode(bytes));
    } on FormatException catch (e) {
      throw LangPackException(LangPackError.notPack, e.message);
    }
    if (root is! Map || root['format'] != langPackFormat) throw const LangPackException(LangPackError.notPack, 'format');
    final fv = root['formatVersion'];
    if (fv is! int || fv < 1) throw const LangPackException(LangPackError.notPack, 'formatVersion');
    if (fv > langPackFormatVersion) throw LangPackException(LangPackError.unsupportedVersion, '$fv');

    String req(String key, bool Function(String) ok) {
      final v = (root as Map)[key];
      if (v is! String || !ok(v)) throw LangPackException(LangPackError.badManifest, key);
      return v;
    }

    final id = req('id', _id.hasMatch);
    final version = req('version', _semver.hasMatch);
    final rawName = root['name'];
    final names = <String, String>{
      if (rawName is String && rawName.trim().isNotEmpty) '': rawName.trim(),
      if (rawName is Map)
        for (final e in rawName.entries)
          if (e.key is String && e.value is String && (e.value as String).trim().isNotEmpty) e.key as String: (e.value as String).trim(),
    };
    if (names.isEmpty) throw const LangPackException(LangPackError.badManifest, 'name');
    final rawAuthors = root['authors'];
    final authors = [if (rawAuthors is List) for (final a in rawAuthors) if (a is String && a.trim().isNotEmpty) a.trim()];
    if (authors.isEmpty) throw const LangPackException(LangPackError.badManifest, 'authors');
    final app = root['app'];
    final appMin = app is Map && app['min'] is String ? app['min'] as String : null;

    final issues = <LangPackIssue>[];
    final bundledByNorm = {for (final l in schema.bundledLocales) normLangTag(l): l};
    final locales = <String, LangPackLocale>{};
    final rawLocales = root['locales'];
    if (rawLocales is Map) {
      for (final e in rawLocales.entries) {
        if (e.key is! String) continue;
        final tag = e.key as String;
        final norm = normLangTag(tag);
        final meta = e.value is Map ? (e.value as Map) : const {};
        final name = meta['name'] is String ? meta['name'] as String : null;
        if (!RegExp(r'^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$').hasMatch(norm)) {
          issues.add(LangPackIssue(tag, '', '', 'bad-locale-tag'));
          continue;
        }
        final bundled = bundledByNorm[norm];
        if (bundled != null) {
          locales[norm] = LangPackLocale(tag: tag, base: bundled, name: name);
          continue;
        }
        final base = bundledByNorm[normLangTag('${meta['base'] ?? ''}')];
        if (base == null) {
          issues.add(LangPackIssue(tag, '', '', 'added-locale-needs-bundled-base'));
          continue;
        }
        if (!schema.canAddLanguage(norm.split('-').first)) {
          issues.add(LangPackIssue(tag, '', '', 'no-material-localizations'));
          continue;
        }
        locales[norm] = LangPackLocale(tag: tag, base: base, name: name);
      }
    }
    if (locales.isEmpty) throw LangPackException(LangPackError.noLocales, issues.map((i) => i.toString()).join('\n'));

    final entries = <String, Map<String, Map<String, Object>>>{};
    var applied = 0;
    var unknown = 0;
    final rawStrings = root['strings'];
    if (rawStrings is Map) {
      for (final le in rawStrings.entries) {
        final tag = '${le.key}';
        final norm = normLangTag(tag);
        if (!locales.containsKey(norm)) {
          issues.add(LangPackIssue(tag, '', '', 'locale-not-declared'));
          continue;
        }
        if (le.value is! Map) continue;
        for (final de in (le.value as Map).entries) {
          final domain = '${de.key}';
          if (de.value is! Map) continue;
          final out = <String, Object>{};
          for (final ke in (de.value as Map).entries) {
            final key = '${ke.key}';
            final value = ke.value;
            void reject(String reason) => issues.add(LangPackIssue(tag, domain, key, reason));
            if (value is! String) {
              reject('not-a-string');
              continue;
            }
            if (value.length > langPackMaxValueLength) {
              reject('too-long');
              continue;
            }
            final icuKeys = schema.icuDomains[domain];
            if (icuKeys != null) {
              final allowed = icuKeys[key];
              if (allowed == null) {
                unknown++;
                continue;
              }
              try {
                final msg = IcuMessage.parse(value);
                final bad = msg.names.where((n) => !allowed.contains(n)).toList();
                if (bad.isNotEmpty) {
                  reject('unknown-placeholder ${bad.join(', ')}');
                  continue;
                }
                out[key] = msg;
              } on FormatException catch (e) {
                reject('icu: ${e.message}');
                continue;
              }
            } else if (domain == 'rai') {
              final allowed = schema.raiParams[key];
              if (allowed == null) {
                unknown++;
                continue;
              }
              final bad = [for (final m in _slot.allMatches(value)) if (!allowed.contains(m[1])) m[1]!];
              if (bad.isNotEmpty) {
                reject('unknown-placeholder ${bad.join(', ')}');
                continue;
              }
              if (key == 'functionUsage') {
                final lines = value.split('\n');
                final names = [for (final l in lines) raiUsageNames(l)];
                if (names.length != schema.raiFunctionNames.length || [for (var i = 0; i < names.length; i++) names[i].join(',') == schema.raiFunctionNames[i].join(',')].contains(false)) {
                  reject('function-names-differ');
                  continue;
                }
              }
              out[key] = value;
            } else if (domain.startsWith('plugin:') && domain.length > 'plugin:'.length) {
              if (!_pluginKey.hasMatch(key) || (key.startsWith('manifest.') && !_manifestKey.hasMatch(key))) {
                reject('bad-plugin-key');
                continue;
              }
              out[key] = value;
            } else {
              unknown++;
              continue;
            }
          }
          if (out.isNotEmpty) {
            applied += out.length;
            ((entries[norm] ??= {})[domain] ??= {}).addAll(out);
          }
        }
      }
    }
    final appKeys = schema.icuDomains['app']?.length ?? 0;
    return LangPack._(
      entries,
      id: id,
      names: names,
      version: version,
      authors: authors,
      license: root['license'] is String ? root['license'] as String : '',
      description: root['description'] is String ? root['description'] as String : '',
      claimsOfficial: root['official'] == true,
      appMin: appMin,
      homepage: root['homepage'] is String ? root['homepage'] as String : null,
      locales: locales,
      report: LangPackReport(
        applied: applied,
        unknown: unknown,
        rejected: issues,
        coverage: {for (final l in locales.entries) l.value.tag: appKeys == 0 ? 0 : (entries[l.key]?['app']?.length ?? 0) / appKeys},
        needsNewerApp: appMin != null && appVersion != null && compareVersions(appMin, appVersion) > 0,
      ),
    );
  }
}

/// `1.2.3` どうしを比べる(数の部分だけ)。
int compareVersions(String a, String b) {
  List<int> p(String v) => [for (final s in v.split(RegExp(r'[-+]')).first.split('.')) int.tryParse(s) ?? 0];
  final x = p(a), y = p(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}
