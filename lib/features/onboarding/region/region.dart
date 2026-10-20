import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart' show RasqUiLocale;

import '../../../backend/orgate_client.dart';
import '../../../l10n/l10n.dart';
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

/// 探す語に合うか(名前・読み・コード。大文字小文字とひらがな / カタカナは区別しない)。
bool regionMatches(String code, String query) {
  final q = _katakana(query.trim()).toLowerCase();
  if (q.isEmpty) return true;
  final (countries, states, readings) = _tables;
  for (final s in [countries[code], states[code], readings[code], code]) {
    if (s != null && _katakana(s).toLowerCase().contains(q)) return true;
  }
  return false;
}

String _katakana(String s) => String.fromCharCodes(s.runes.map((r) => r >= 0x3041 && r <= 0x3096 ? r + 0x60 : r));
