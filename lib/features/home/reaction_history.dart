import 'dart:convert';
import 'dart:math' as math;

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

  /// 投稿 [post] への短押しリアクションの予測 (D-041 改)。
  ///
  /// 1. **既に複数回リアクションされている投稿** → その投稿のリアクションの
  ///    中から選出。順位が上のものほど**指数関数的に**選ばれやすい
  ///    (重み 2^-rank、post.key シードの決定的乱択 — 表示が投稿ごとに
  ///    安定しつつ、毎回 1 位ばかりにはならない)
  /// 2. それ以外 → 自分の履歴 × 投稿の既存リアクションの交差 → 自分の最頻
  ///
  /// 計算は純ローカル(ネットワーク・ML なし)なので、**表示されたタイミングの
  /// パッシブ駆動**で全投稿に対して走らせてよい。
  String? predictFor(Post post) {
    final total = post.reactions.values.fold<int>(0, (a, b) => a + b);
    if (total >= 2) {
      final ranked = post.reactions.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final weights = [for (var i = 0; i < ranked.length; i++) math.pow(2.0, -i).toDouble()];
      final sum = weights.fold<double>(0, (a, b) => a + b);
      var roll = math.Random(post.key.hashCode).nextDouble() * sum;
      for (var i = 0; i < ranked.length; i++) {
        roll -= weights[i];
        if (roll <= 0) return ranked[i].key;
      }
      return ranked.first.key;
    }
    final counts = state.value ?? const <String, int>{};
    if (counts.isEmpty) return null;
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
    return (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
  }
}

final reactionHistoryProvider = AsyncNotifierProvider<ReactionHistoryStore, Map<String, int>>(ReactionHistoryStore.new);

/// 他サーバーのカスタム絵文字(`:name@host:`)なら、その名前。Unicode / 自サーバーの絵文字(`:name:` / `:name@.:`)は null。
/// 他サーバーの絵文字はそのままでは付けられない(サーバーが別の絵文字にすり替える)ので、同じ名前の自サーバーの絵文字に読み替えるか、
/// 無ければピッカーを開く (D-278)。
String? remoteReactionName(String reaction) {
  if (!reaction.startsWith(':') || !reaction.endsWith(':') || reaction.length < 3) return null;
  final inner = reaction.substring(1, reaction.length - 1);
  final at = inner.indexOf('@');
  if (at <= 0) return null;
  final host = inner.substring(at + 1);
  return host.isEmpty || host == '.' ? null : inner.substring(0, at);
}

