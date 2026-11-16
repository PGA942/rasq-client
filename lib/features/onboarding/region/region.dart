import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart' show RasqUiLocale;

import '../../../backend/orgate_client.dart';
import '../../../l10n/l10n.dart';
import '../../compose/kana_romaji.dart' show kanaSearchKey, romajiSearchKey;
import 'region_aliases_ja.dart';
import 'region_names_en.dart';
import 'region_names_ja.dart';
import 'region_names_ko.dart';
import 'region_names_zh.dart';
import 'region_names_zh_hant.dart';

/// 住んでいる地域の申告 (D-542 / ORGATE O-018、ユーザー決定 2026-10-20)。
///
/// - RASQ アカウントを**新しく作る**ときだけ、住んでいる国・地域を選んでもらう(自己申告。IP などでは確かめない)。
///   アメリカだけは州まで(`US-CA`、ISO 3166-2)。ほかは ISO 3166-1 alpha-2(`JP`)。ログイン中 / 前からあるアカウントには聞かない。
/// - 選べる地域と、いま提供していない地域は ORGATE の `GET /api/v1/regions` が決める(アプリは一覧を持たない)。
///   読めないときは、名前の表にあるコードを全部選べるようにして、作るときのサーバーの答え(`403 region_not_served`)に従う。
/// - 提供していない地域を選んだら、作成へは進ませない([RegionUnavailableScreen])。

/// 州まで選ぶ国。
const regionSubdivided = 'US';

/// 選べる地域の 1 つ。
@immutable
class RasqRegionEntry {
  const RasqRegionEntry(this.code, {this.available = true});
  final String code;
  final bool available;
}

/// 国(州まで選ぶ国は [subdivisions] がある)。
@immutable
class RasqCountry {
  const RasqCountry(this.code, {this.available = true, this.subdivisions = const []});
  final String code;
  final bool available;
  final List<RasqRegionEntry> subdivisions;
}

/// 選べる地域の一覧(`GET /api/v1/regions`)。
@immutable
class RasqRegions {
  const RasqRegions({required this.countries, this.unavailable = const {}, this.fromServer = true});
  final List<RasqCountry> countries;

  /// 提供していない地域のコード(国ごと / 州)。
  final Set<String> unavailable;

  /// サーバーから読めたか(false = 読めずに、全部を選べるようにした一覧。提供の可否はサーバーが作るときに決める)。
  final bool fromServer;

  factory RasqRegions.fromJson(Map<String, Object?> j) {
    final countries = <RasqCountry>[];
    for (final c in (j['countries'] as List? ?? const [])) {
      if (c is! Map) continue;
      final code = c['code'];
      if (code is! String || code.isEmpty) continue;
      countries.add(RasqCountry(
        code,
        available: c['available'] != false,
        subdivisions: [
          for (final s in (c['subdivisions'] as List? ?? const []))
            if (s is Map && s['code'] is String) RasqRegionEntry(s['code'] as String, available: s['available'] != false),
        ],
      ));
    }
    return RasqRegions(
      countries: countries,
      unavailable: {for (final u in (j['unavailable'] as List? ?? const [])) if (u is String) u},
    );
  }

  /// サーバーから読めないときの一覧: 名前の表のコード全部(提供の可否はわからないので、全部選べる)。
  factory RasqRegions.fallback() => RasqRegions(
        fromServer: false,
        countries: [
          for (final c in regionNamesJa.keys)
            RasqCountry(c, subdivisions: c == regionSubdivided ? [for (final s in usStateNamesJa.keys) RasqRegionEntry(s)] : const []),
        ],
      );

  RasqCountry? country(String code) {
    for (final c in countries) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// その地域で作れるか(国ごと提供していなければ、その国の州も作れない)。読めなかった一覧では、いつも true(サーバーが決める)。
  bool isAvailable(String code) {
    if (unavailable.contains(code)) return false;
    final dash = code.indexOf('-');
    if (dash > 0 && unavailable.contains(code.substring(0, dash))) return false;
    final country = this.country(dash > 0 ? code.substring(0, dash) : code);
    if (country != null && !country.available) return false;
    if (dash > 0 && country != null) {
      for (final s in country.subdivisions) {
        if (s.code == code) return s.available;
      }
    }
    return true;
  }
}

/// ORGATE から選べる地域を読む。読めなければ [RasqRegions.fallback](作るときにサーバーが決める)。
final rasqRegionsProvider = FutureProvider.autoDispose<RasqRegions>((ref) async {
  final client = ref.watch(orgateClientProvider);
  if (client == null) return RasqRegions.fallback();
  try {
    final regions = RasqRegions.fromJson(await client.withToken(() => null).getJson('/regions'));
    return regions.countries.isEmpty ? RasqRegions.fallback() : regions;
  } catch (e) {
    debugPrint('regions: GET /regions unavailable, letting the server decide: $e');
    return RasqRegions.fallback();
  }
});

/// 言語ごとの名前の表(国, 州, 読み)。無い言語は日本語。
const _regionNameTables = <String, (Map<String, String>, Map<String, String>, Map<String, String>)>{
  'ja': (regionNamesJa, usStateNamesJa, regionReadingsJa),
  'en': (regionNamesEn, usStateNamesEn, <String, String>{}),
  'zh': (regionNamesZh, usStateNamesZh, <String, String>{}),
  'zh-Hant': (regionNamesZhHant, usStateNamesZhHant, <String, String>{}),
  'ko': (regionNamesKo, usStateNamesKo, <String, String>{}),
};

(Map<String, String>, Map<String, String>, Map<String, String>) get _tables {
  final tag = RasqUiLocale.tag;
  final lang = tag.split('-').first;
  return _regionNameTables[tag] ?? _regionNameTables[lang] ?? _regionNameTables['ja']!;
}

/// 国・地域 / 州の名前(いまの表示の言語。表に無ければコード)。`US-CA` は「アメリカ合衆国・カリフォルニア州」。
String regionName(String code) {
  final (countries, states, _) = _tables;
  final dash = code.indexOf('-');
  if (dash < 0) return countries[code] ?? code;
  final country = countries[code.substring(0, dash)] ?? code.substring(0, dash);
  return appL10n.regionCountryAndState(country, states[code] ?? code);
}

/// 州だけの名前(州の一覧に出す)。
String regionStateName(String code) => _tables.$2[code] ?? code;

/// 並べる順の鍵(読み → 名前。ひらがなはカタカナにそろえる)。
String regionSortKey(String code) {
  final (countries, states, readings) = _tables;
  return _katakana(readings[code] ?? countries[code] ?? states[code] ?? code);
}

/// 探す語に合うか(名前・読み・コード。大文字小文字とひらがな / カタカナは区別しない)。[regionMatch] の結果があるか。
bool regionMatches(String code, String query) => regionMatch(code, query) != null;

/// 探す語に合ったときの結果。[via] = 名前ではなく、その中の地名(日本の都道府県・市・区 / アメリカの州)に当たったときの地名。
@immutable
class RegionMatch {
  const RegionMatch({this.via});
  final String? via;
}

/// 探す語 [query] が地域 [code] に合うか (D-542 → D-573)。合わなければ null。比べるもの:
/// - いまの表示の言語の名前・読み・コード(大文字小文字、ひらがな / カタカナ、記号は見ない)
/// - 英語の名前(どの表示の言語でも `japan` / `france` で引ける。アクセントは見ない)
/// - **ローマ字**: 日本語の名前の読みをローマ字にしたもの([romajiSearchKey]。ヘボン式 / 訓令式・長音の有無を問わない。
///   `nihon` / `furansu` / `amerika`)
/// - 国の中の地名: 日本は都道府県・政令指定都市・東京 23 区([jpPlaceAliasesJa]。`tokyo` / `shibuya` / `sapporo` / `東京`)、
///   国の一覧のアメリカは州の名前(`california` / `カリフォルニア`)。当たった地名は [RegionMatch.via]。
RegionMatch? regionMatch(String code, String query) {
  final q = _plainKey(query);
  if (q.isEmpty) return const RegionMatch();
  final qr = RegExp(r'[a-zA-Z]').hasMatch(query) ? romajiSearchKey(query) : '';
  final index = _regionIndex();
  final keys = index.keys[code] ?? _RegionKeys.of(code);
  if (keys.matches(q, qr)) return const RegionMatch();
  for (final a in index.aliases[code] ?? const <_RegionAlias>[]) {
    if (a.matches(q, qr)) return RegionMatch(via: a.label);
  }
  return null;
}

/// 比べる形: ひらがな → カタカナ、小文字、アクセントを外し、文字と数字だけ(空白・記号・「・」は落とす)。
String _plainKey(String s) {
  const accents = {'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ç': 'c', 'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ñ': 'n', 'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ý': 'y', 'ÿ': 'y', 'ō': 'o', 'ū': 'u', 'ā': 'a'};
  final lower = _katakana(s.trim()).toLowerCase();
  final folded = lower.split('').map((c) => accents[c] ?? c).join();
  return folded.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
}

/// ローマ字の鍵で比べる語の短さの下限(2 文字の `ka` / `to` などは、ほとんどの名前に当たる)。
const _romajiMinChars = 3;

/// 英語の名前の語(語の頭から比べる。`us` が Australia / Russia の途中に当たらないように)。
List<String> _englishWords(String? name) {
  if (name == null || name.isEmpty) return const [];
  final whole = _plainKey(name);
  return [whole, for (final w in name.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))) if (w.isNotEmpty) _plainKey(w)];
}

/// 地域 1 つの比べる鍵。
class _RegionKeys {
  _RegionKeys(this.plain, this.english, this.romaji);

  /// 表示の言語の名前・読み・コード(部分一致)。
  final List<String> plain;

  /// 英語の名前の語(語の頭から)。
  final List<String> english;

  /// 日本語の読みのローマ字の鍵(部分一致、[_romajiMinChars] 文字から)。
  final List<String> romaji;

  bool matches(String q, String qr) =>
      plain.any((k) => k.contains(q)) || english.any((w) => w.startsWith(q)) || (qr.length >= _romajiMinChars && romaji.any((k) => k.contains(qr)));

  factory _RegionKeys.of(String code) {
    final (countries, states, readings) = _tables;
    final plain = <String>{
      for (final s in [countries[code], states[code], readings[code], code])
        if (s != null && s.isNotEmpty) _plainKey(s),
    };
    final english = {..._englishWords(regionNamesEn[code]), ..._englishWords(usStateNamesEn[code])};
    // ローマ字は日本語の名前から(読み → 名前のカタカナ)。表示の言語が日本語でなくても引ける。
    final ja = regionReadingsJa[code] ?? regionNamesJa[code] ?? usStateNamesJa[code];
    final romaji = <String>{if (ja != null) kanaSearchKey(ja)}..remove('');
    return _RegionKeys(plain.toList(), english.toList(), romaji.toList());
  }
}

/// 国の中の地名 1 つ。
class _RegionAlias {
  _RegionAlias(this.label, this.plain, this.english, this.romaji);
  final String label;
  final List<String> plain;
  final List<String> english;
  final String romaji;

  bool matches(String q, String qr) =>
      plain.any((k) => k.contains(q)) || english.any((w) => w.startsWith(q)) || (qr.length >= _romajiMinChars && romaji.contains(qr));
}

/// 表示の言語ごとの鍵の表(地域の数 × 数語なので、言語が変わったときだけ作り直す)。
({String tag, Map<String, _RegionKeys> keys, Map<String, List<_RegionAlias>> aliases})? _index;

({String tag, Map<String, _RegionKeys> keys, Map<String, List<_RegionAlias>> aliases}) _regionIndex() {
  final tag = RasqUiLocale.tag;
  final cached = _index;
  if (cached != null && cached.tag == tag) return cached;
  final (_, states, _) = _tables;
  final keys = <String, _RegionKeys>{for (final c in {...regionNamesJa.keys, ...usStateNamesJa.keys}) c: _RegionKeys.of(c)};
  final aliases = <String, List<_RegionAlias>>{
    'JP': [for (final (name, reading) in jpPlaceAliasesJa) _RegionAlias(name, [_plainKey(name), _plainKey(reading)], const [], kanaSearchKey(reading))],
    regionSubdivided: [
      for (final s in usStateNamesJa.keys)
        _RegionAlias(
          states[s] ?? usStateNamesJa[s]!,
          {_plainKey(states[s] ?? ''), _plainKey(usStateNamesJa[s]!)}.where((k) => k.isNotEmpty).toList(),
          _englishWords(usStateNamesEn[s]),
          kanaSearchKey(usStateNamesJa[s]!),
        ),
    ],
  };
  return _index = (tag: tag, keys: keys, aliases: aliases);
}

String _katakana(String s) => String.fromCharCodes(s.runes.map((r) => r >= 0x3041 && r <= 0x3096 ? r + 0x60 : r));
