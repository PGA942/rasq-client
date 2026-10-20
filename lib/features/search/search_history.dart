import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart' show RasqDateFormat;

import '../../session/session_providers.dart';
import '../../l10n/l10n.dart';

/// 最近の検索 (D-259): 検索ホームで決定した検索を端末に控える(新しい順、30 件まで、同じ言葉は 1 つ)。
/// 「ノート画像の追加」FOW の「最近の検索」タブが、ここから探し直す。
@immutable
class SearchHistoryEntry {
  const SearchHistoryEntry({required this.query, required this.at, this.chips = const []});

  /// 検索した言葉(タイルの見出し)。
  final String query;
  final DateTime at;

  /// 一緒に掛けていた絞り込み(ジャンルなど。タイルの下に並ぶ)。
  final List<String> chips;

  Map<String, Object?> toJson() => {'query': query, 'at': at.toIso8601String(), if (chips.isNotEmpty) 'chips': chips};
  static SearchHistoryEntry? fromJson(Object? j) {
    if (j is! Map || j['query'] is! String || (j['query'] as String).isEmpty) return null;
    return SearchHistoryEntry(query: j['query'] as String, at: DateTime.tryParse('${j['at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0), chips: [for (final c in (j['chips'] as List? ?? const [])) if (c is String) c]);
  }
}

class SearchHistory extends Notifier<List<SearchHistoryEntry>> {
  static const storageKey = 'search.history.v1';
  static const max = 30;
  Future<void>? _restored;

  @override
  List<SearchHistoryEntry> build() {
    _restored = _restore();
    return const [];
  }

  Future<void> get ready => _restored ?? Future.value();

  Future<void> _restore() async {
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw == null) return;
      state = [for (final e in jsonDecode(raw) as List) SearchHistoryEntry.fromJson(e)].whereType<SearchHistoryEntry>().toList();
    } catch (_) {}
  }

  Future<void> _persist(List<SearchHistoryEntry> next) async {
    state = next;
    await ref.read(sessionStorageProvider).write(storageKey, jsonEncode([for (final e in next) e.toJson()]));
  }

  Future<void> record(String query, {Iterable<String> chips = const [], DateTime? at}) async {
    final q = query.trim();
    if (q.isEmpty) return;
    await ready;
    await _persist([SearchHistoryEntry(query: q, at: at ?? DateTime.now(), chips: chips.toList()), for (final e in state) if (e.query != q) e].take(max).toList());
  }

  Future<void> remove(String query) async {
    await ready;
    await _persist([for (final e in state) if (e.query != query) e]);
  }
}

final searchHistoryProvider = NotifierProvider<SearchHistory, List<SearchHistoryEntry>>(SearchHistory.new);

/// 「1 時間前」「1 日前」。
String searchHistoryAgo(DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(at);
  final l = appL10n;
  if (d.inMinutes < 1) return l.searchAgoJustNow;
  if (d.inHours < 1) return l.searchAgoMinutes(d.inMinutes);
  if (d.inDays < 1) return l.searchAgoHours(d.inHours);
  if (d.inDays < 30) return l.searchAgoDays(d.inDays);
  return RasqDateFormat.numericDate(at);
}
