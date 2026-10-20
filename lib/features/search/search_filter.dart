import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import 'search_ranker.dart';
import '../../l10n/l10n.dart';

/// 検索の並び替えキー (D-021)。昇順/降順ではなく**キー名に方向を内包**する。
enum SearchSort {
  relevance,
  newest,
  oldest,
  reactions;

  /// 表示の名前(表示の言語、D-528)。
  String get label => switch (this) {
        relevance => appL10n.searchSortRelevance,
        newest => appL10n.searchSortNewest,
        oldest => appL10n.searchSortOldest,
        reactions => appL10n.searchSortReactions,
      };
}

enum SearchPeriod {
  all(null),
  day(Duration(days: 1)),
  week(Duration(days: 7)),
  month(Duration(days: 30));

  const SearchPeriod(this.window);
  final Duration? window;

  /// 表示の名前(表示の言語、D-528)。
  String get label => switch (this) {
        all => appL10n.searchPeriodAll,
        day => appL10n.searchPeriodDay,
        week => appL10n.searchPeriodWeek,
        month => appL10n.searchPeriodMonth,
      };
}

/// 検索フィルタ状態。検索ホームで設定 → トレンドTL(結果)に引き継ぐ。
@immutable
class SearchFilterState {
  const SearchFilterState({this.sort = SearchSort.relevance, this.period = SearchPeriod.all, this.genres = const {}});

  final SearchSort sort;
  final SearchPeriod period;

  /// 選択中ジャンル(トレンドタグ)。
  final Set<String> genres;

  /// 既定から変更されている = チップ行を常時表示する条件。
  bool get dirty => sort != SearchSort.relevance || period != SearchPeriod.all || genres.isNotEmpty;

  SearchFilterState copyWith({SearchSort? sort, SearchPeriod? period, Set<String>? genres}) =>
      SearchFilterState(sort: sort ?? this.sort, period: period ?? this.period, genres: genres ?? this.genres);

  SearchFilterState toggleGenre(String tag) {
    final next = {...genres};
    next.contains(tag) ? next.remove(tag) : next.add(tag);
    return copyWith(genres: next);
  }

  static const initial = SearchFilterState();
}

/// 画面をまたいで共有(検索ホーム → トレンドTL)。
class SearchFilterStore extends Notifier<SearchFilterState> {
  @override
  SearchFilterState build() => SearchFilterState.initial;

  void set(SearchFilterState next) => state = next;
}

final searchFilterProvider = NotifierProvider<SearchFilterStore, SearchFilterState>(SearchFilterStore.new);

/// 並び替えチップの小型ドロップダウン(D-015 と同じ部品)。
Future<SearchSort?> showSearchSortMenu(OverlayManager manager, Rect anchor, SearchSort current) => manager.showDropdown<SearchSort>(
      id: 'search.sort',
      anchor: anchor,
      dense: true,
      items: [for (final s in SearchSort.values) RasqDropdownItem(s.label, s, checked: s == current)],
    );

Future<SearchPeriod?> showSearchPeriodMenu(OverlayManager manager, Rect anchor, SearchPeriod current) => manager.showDropdown<SearchPeriod>(
      id: 'search.period',
      anchor: anchor,
      dense: true,
      items: [for (final p in SearchPeriod.values) RasqDropdownItem(p.label, p, checked: p == current)],
    );

/// フィルタ(期間・ジャンル)→ 並び替えを適用する。関連順は [SearchRanker]。
List<Post> applySearchFilter(List<Post> posts, SearchFilterState filter, {required String query, SearchRanker? ranker, DateTime? now}) {
  final clock = now ?? DateTime.now();
  var list = posts;
  final window = filter.period.window;
  if (window != null) {
    final cutoff = clock.subtract(window);
    list = [for (final p in list) if (p.createdAt.isAfter(cutoff)) p];
  }
  if (filter.genres.isNotEmpty) {
    final r = ranker ?? const SearchRanker();
    list = [for (final p in list) if (r.matchesAnyGenre(p, filter.genres)) p];
  }
  switch (filter.sort) {
    case SearchSort.relevance:
      return (ranker ?? const SearchRanker()).rank(list, query: query, genres: filter.genres, now: clock);
    case SearchSort.newest:
      return [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    case SearchSort.oldest:
      return [...list]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    case SearchSort.reactions:
      return [...list]..sort((a, b) => b.reactionTotal.compareTo(a.reactionTotal));
  }
}

/// 展開タイル内に入れ子で置くジャンルボタンの上限(選択済みは常に出す)。
const int maxGenreChips = 6;

/// 並び替え/期間のドロップダウンチップ(検索ホーム / トレンドTL 共用)。
List<RasqFilterChipItem> buildSortPeriodChips({
  required SearchFilterState filter,
  required void Function(Rect) onSortTap,
  required void Function(Rect) onPeriodTap,
}) =>
    [
      RasqFilterChipItem(label: filter.sort.label, selected: filter.sort != SearchSort.relevance, dropdown: true, onAnchorTap: onSortTap),
      RasqFilterChipItem(label: filter.period == SearchPeriod.all ? appL10n.searchPeriodChip : filter.period.label, selected: filter.period != SearchPeriod.all, dropdown: true, onAnchorTap: onPeriodTap),
    ];

/// ジャンルのトグルチップ(スタジアム形・入れ子)。選択済みを優先。
List<RasqFilterChipItem> buildGenreChips({
  required SearchFilterState filter,
  required List<String> genreCandidates,
  required void Function(String) onGenreToggle,
}) {
  final inline = <String>[
    ...filter.genres,
    for (final g in genreCandidates)
      if (!filter.genres.contains(g)) g,
  ].take(maxGenreChips).toList();
  return [for (final g in inline) RasqFilterChipItem(label: '#$g', selected: filter.genres.contains(g), onTap: () => onGenreToggle(g))];
}
