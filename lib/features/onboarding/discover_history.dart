import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/session_providers.dart';

/// 「SNS サービスを探す」で探した言葉の控え (D-553)。**端末の中だけ**に持つ(サーバーへは送らない)。
/// 新しい順、[DiscoverHistory.max] 件まで、同じ言葉(大小文字は区別しない)は 1 つ。
/// 「検索履歴を統合して探す」(`history_discover_screen.dart`)が、ここから言葉を選んで探し直す。

/// どこで探した言葉か。
enum DiscoverHistorySource { people, content, page }

@immutable
class DiscoverHistoryEntry {
  const DiscoverHistoryEntry({required this.term, required this.source, required this.at});
  final String term;
  final DiscoverHistorySource source;
  final DateTime at;

  Map<String, Object?> toJson() => {'term': term, 'source': source.name, 'at': at.toIso8601String()};
  static DiscoverHistoryEntry? fromJson(Object? j) {
    if (j is! Map || j['term'] is! String || (j['term'] as String).trim().isEmpty) return null;
    return DiscoverHistoryEntry(
      term: (j['term'] as String).trim(),
      source: DiscoverHistorySource.values.asNameMap()['${j['source']}'] ?? DiscoverHistorySource.people,
      at: DateTime.tryParse('${j['at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// 控える言葉の長さの上限(長い文は控えない: 探し直す言葉にならない)。
const discoverHistoryMaxTermChars = 40;

class DiscoverHistory extends Notifier<List<DiscoverHistoryEntry>> {
  static const storageKey = 'discover.history.v1';
  static const max = 40;
  Future<void>? _restored;

  @override
  List<DiscoverHistoryEntry> build() {
    _restored = _restore();
    return const [];
  }

  Future<void> get ready => _restored ?? Future.value();

  Future<void> _restore() async {
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw == null) return;
      state = [for (final e in jsonDecode(raw) as List) DiscoverHistoryEntry.fromJson(e)].whereType<DiscoverHistoryEntry>().toList();
    } catch (_) {}
  }

  Future<void> _persist(List<DiscoverHistoryEntry> next) async {
    state = next;
    try {
      await ref.read(sessionStorageProvider).write(storageKey, jsonEncode([for (final e in next) e.toJson()]));
    } catch (e) {
      debugPrint('discover history: $e');
    }
  }

  /// 探した言葉を控える(先に渡した言葉が新しい扱い)。空 / 長すぎる言葉は控えない。
  Future<void> record(Iterable<String> terms, DiscoverHistorySource source, {DateTime? at}) async {
    final fresh = <DiscoverHistoryEntry>[];
    for (final t in terms) {
      final term = t.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (term.isEmpty || term.runes.length > discoverHistoryMaxTermChars) continue;
      if (fresh.any((e) => e.term.toLowerCase() == term.toLowerCase())) continue;
      fresh.add(DiscoverHistoryEntry(term: term, source: source, at: at ?? DateTime.now()));
    }
    if (fresh.isEmpty) return;
    await ready;
    final seen = {for (final e in fresh) e.term.toLowerCase()};
    await _persist([...fresh, for (final e in state) if (!seen.contains(e.term.toLowerCase())) e].take(max).toList());
  }

  Future<void> remove(String term) async {
    await ready;
    await _persist([for (final e in state) if (e.term != term) e]);
  }

  Future<void> clear() async {
    await ready;
    await _persist(const []);
  }
}

final discoverHistoryProvider = NotifierProvider<DiscoverHistory, List<DiscoverHistoryEntry>>(DiscoverHistory.new);
