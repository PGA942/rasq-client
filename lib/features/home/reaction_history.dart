import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../session/session_providers.dart';

/// リアクション履歴 (D-039)。短押しリアクションの**予測**に使う、
/// 事前学習なしのヒューリスティック:
///
/// 1. その投稿に既に付いているリアクションのうち、自分がよく使うもの
///    (文脈 × 自分の癖の交差 — サーバーの絵文字事情にも自然に合う)
/// 2. 無ければ自分が最もよく使う絵文字
/// 3. 履歴が無ければ null(アダプタの既定リアクションに任せる)
///
/// reaction-predictor モデル(examples/reaction-predictor.model.json)の
/// 配線後は、この predictFor を ml.infer に置き換える(D-017)。
/// 保存は KV `reaction.history.v1`(D-035 規約)。
const reactionHistoryStorageKey = 'reaction.history.v1';

class ReactionHistoryStore extends AsyncNotifier<Map<String, int>> {
  @override
  Future<Map<String, int>> build() async {
    try {
      final raw = await ref.watch(sessionStorageProvider).read(reactionHistoryStorageKey);
      if (raw != null) return (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {}
    return const {};
  }

  Future<void> record(String emoji) async {
    final next = {...state.value ?? const <String, int>{}};
    next[emoji] = (next[emoji] ?? 0) + 1;
    // 上位 64 種だけ持ち回る(肥大防止)。
    final entries = next.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final trimmed = {for (final e in entries.take(64)) e.key: e.value};
    state = AsyncData(trimmed);
    await ref.read(sessionStorageProvider).write(reactionHistoryStorageKey, jsonEncode(trimmed));
  }

  /// 投稿 [post] への短押しリアクションの予測。
  String? predictFor(Post post) {
    final counts = state.value ?? const <String, int>{};
    if (counts.isEmpty) return null;
    // 1. 投稿に付いているリアクション × 自分の履歴。
    String? best;
    var bestScore = 0;
    for (final r in post.reactions.keys) {
      final mine = counts[r] ?? 0;
      if (mine > bestScore) {
        best = r;
        bestScore = mine;
      }
    }
    if (best != null) return best;
    // 2. 自分の最頻絵文字。
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }
}

final reactionHistoryProvider = AsyncNotifierProvider<ReactionHistoryStore, Map<String, int>>(ReactionHistoryStore.new);
