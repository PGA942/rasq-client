import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router.dart' show Routes;
import '../rai/rai_reference.dart' show keywordScore;
import 'settings_dsl.dart' show loadSettingsPageJson;
import 'settings_sections.dart';
import '../../l10n/asset_strings.dart';
import '../../l10n/l10n.dart';
import '../../l10n/ui_locale.dart' show uiLocaleProvider, uiLocaleTagProvider;

/// 設定の検索 (D-385)。「全ての設定」の検索欄から、設定の行と、設定ページ(DSL)の中の項目を探す。
///
/// - 索引 = 第一階層の節([settingsSections])+ その行 + 行が開く設定ページ(`/settings/dsl/<area>`)の見出しと項目の名前。
///   項目に当たったら、その項目があるページを開く(パンくずで「節 › 行」を出す)。
/// - 当て方は RAi の操作リファレンスと同じキーワードのスコア([keywordScore]、語尾の揺れ / 2-gram)。
/// - 操作(「〜するには」)は RAi の操作リファレンスからも引き、押すと RAi が手順を案内する(画面側)。

/// 索引の 1 件。
class SettingsSearchEntry {
  const SettingsSearchEntry({required this.title, required this.sectionId, this.path = const [], this.row, this.keys = const []});
  final String title;

  /// 節の id([settingsSections] のキー)。絞り込みのチップに使う。
  final String sectionId;

  /// パンくず(節 › 行)。
  final List<String> path;

  /// 押したときに開く行(null = 節のページ)。
  final SettingsRow? row;

  /// 当てるのに使う語(名前のほか、説明)。
  final List<String> keys;

  String get route => row?.route ?? '/settings/section/$sectionId';
}

class SettingsSearchHit {
  const SettingsSearchHit(this.entry, this.score);
  final SettingsSearchEntry entry;
  final double score;
}

/// 設定ページ(DSL)の中から、名前(`p.title`)のある部品を拾う。お知らせ(Notice)の本文は長いので拾わない。
List<String> settingsPageLabels(Object? node) {
  final out = <String>[];
  void walk(Object? n) {
    if (n is Map) {
      final p = n['p'];
      if (n['t'] != 'Notice' && p is Map && p['title'] is String && (p['title'] as String).trim().isNotEmpty) out.add((p['title'] as String).trim());
      final c = n['c'];
      if (c is List) c.forEach(walk);
      if (n['child'] != null) walk(n['child']);
    } else if (n is List) {
      n.forEach(walk);
    }
  }

  walk(node);
  return out;
}

/// 索引を組む。[loadPage] = 設定ページの JSON を読む(テストで差し替える。読めなければ null)。
/// [l10n] = 名前の言語(省略するといまの表示の言語)。
Future<List<SettingsSearchEntry>> buildSettingsSearchIndex(Future<String?> Function(String area) loadPage, {AppLocalizations? l10n}) async {
  final l = l10n ?? appL10n;
  final out = <SettingsSearchEntry>[];
  final pages = <String, Future<String?>>{};
  for (final MapEntry(key: id, value: section) in settingsSectionsOf(l).entries) {
    out.add(SettingsSearchEntry(title: section.title, sectionId: id));
    for (final r in section.rows) {
      out.add(SettingsSearchEntry(title: r.title, sectionId: id, path: [section.title], row: r, keys: [?r.subtitle, ?r.detail]));
      final route = r.route;
      if (route == null || !route.startsWith('/settings/dsl/')) continue;
      final area = route.substring('/settings/dsl/'.length);
      final raw = await (pages[area] ??= loadPage(area));
      if (raw == null) continue;
      Object? page;
      try {
        // 文言の参照(`@l10n:`)を表示の言語の文言に (D-535)。
        page = resolveAssetStrings(jsonDecode(raw), l);
      } catch (_) {
        continue;
      }
      final seen = <String>{r.title};
      for (final label in settingsPageLabels(page is Map ? page['root'] : null)) {
        if (!seen.add(label)) continue;
        out.add(SettingsSearchEntry(title: label, sectionId: id, path: [section.title, r.title], row: r));
      }
    }
  }
  // 「全ての設定」の下の段(節に入っていないもの)。
  List<String> words(String s) => [for (final w in s.split(',')) if (w.trim().isNotEmpty) w.trim()];
  out.addAll([
    SettingsSearchEntry(
      title: l.settingsHomeComposer,
      sectionId: 'other',
      path: [l.settingsHomeOtherHeader],
      row: SettingsRow(l.settingsHomeComposer, route: '/settings/composer'),
      keys: words(l.settingsHomeComposerKeywords),
    ),
    SettingsSearchEntry(
      title: l.settingsSectionsAppearanceThemeTitle,
      sectionId: 'appearance',
      path: [l.settingsSectionsAppearanceTitle],
      row: SettingsRow(l.settingsSectionsAppearanceThemeTitle, route: Routes.settingsTheme),
      keys: words(l.settingsHomeThemeKeywords),
    ),
  ]);
  return out;
}

final settingsSearchIndexProvider = FutureProvider<List<SettingsSearchEntry>>((ref) {
  // 表示の言語が変わったら組み直す (D-484)。
  final l = appL10nFor(ref.watch(uiLocaleProvider));
  final tag = ref.watch(uiLocaleTagProvider);
  return buildSettingsSearchIndex(l10n: l, (area) async {
    try {
      // 長い文書ページも同じ道で読む。表示の言語の文書があればそれ (D-535)。
      return await loadSettingsPageJson(area, localeTag: tag);
    } catch (_) {
      return null;
    }
  });
});

/// 当たったものを良い順に。[sections] を渡すとその節だけ。同じページへ行く同じ名前は 1 つに。
List<SettingsSearchHit> searchSettings(List<SettingsSearchEntry> index, String query, {Set<String> sections = const {}, int limit = 30, double threshold = 0.55}) {
  final q = query.trim();
  final pool = sections.isEmpty
      ? index
      : [
          for (final e in index)
            if (sections.contains(e.sectionId)) e,
        ];
  if (q.isEmpty) {
    // 語が無くて節だけ選んでいれば、その節の行を並べる。
    return sections.isEmpty
        ? const []
        : [
            for (final e in pool)
              if (e.row != null && e.path.length == 1) SettingsSearchHit(e, 0),
          ];
  }
  final hits = <SettingsSearchHit>[];
  for (final e in pool) {
    var s = keywordScore(q, [e.title, ...e.keys]);
    // 名前にそのまま含まれていれば上へ(説明だけに含まれるものより前)。
    if (e.title.toLowerCase().contains(q.toLowerCase())) s += 0.3;
    if (s >= threshold) hits.add(SettingsSearchHit(e, s));
  }
  // 同じ点なら浅いもの(行)が先。
  hits.sort((a, b) {
    final d = b.score.compareTo(a.score);
    return d != 0 ? d : a.entry.path.length.compareTo(b.entry.path.length);
  });
  final seen = <String>{};
  return [
    for (final h in hits)
      if (seen.add('${h.entry.title}|${h.entry.route}')) h,
  ].take(limit).toList();
}
