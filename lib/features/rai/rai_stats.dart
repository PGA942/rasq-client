import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'rai_providers.dart';

/// RAi の実績と会話の履歴 (D-214、RAi サイドバー)。
///
/// - [RaiStats]: 聞いたインストラクションの数 / アシスタントにアプリの話をした数 / 順調に進んだ数 /
///   何度も聞いた数。端末内に保存(`rai.stats.v1`)。
/// - [raiAchievements]: 実績の定義(閾値)。[RaiAchievementProgress] で達成 / 進み具合を出す。
/// - [RaiConversation]: 発言の履歴(RAi の発言 + 質問)のまとまり。「新しい会話」で区切って保存(`rai.conversations.v1`)。

@immutable
class RaiStats {
  const RaiStats({this.instructionsAsked = 0, this.assistantAsked = 0, this.assistantAppAsked = 0, this.instructionsCompleted = 0, this.repeatedAsks = 0});

  /// インストラクション(操作の案内)を聞いた回数。
  final int instructionsAsked;

  /// アシスタントに質問した回数。
  final int assistantAsked;

  /// そのうちアプリについての会話(操作リファレンスに当たった)の回数。
  final int assistantAppAsked;

  /// 案内を最後の手順まで進めた回数(順調に進んだ)。
  final int instructionsCompleted;

  /// 同じ質問をもう一度聞いた回数(何度も聞いた)。
  final int repeatedAsks;

  RaiStats copyWith({int? instructionsAsked, int? assistantAsked, int? assistantAppAsked, int? instructionsCompleted, int? repeatedAsks}) => RaiStats(
        instructionsAsked: instructionsAsked ?? this.instructionsAsked,
        assistantAsked: assistantAsked ?? this.assistantAsked,
        assistantAppAsked: assistantAppAsked ?? this.assistantAppAsked,
        instructionsCompleted: instructionsCompleted ?? this.instructionsCompleted,
        repeatedAsks: repeatedAsks ?? this.repeatedAsks,
      );

  Map<String, Object?> toJson() => {
        'instructionsAsked': instructionsAsked,
        'assistantAsked': assistantAsked,
        'assistantAppAsked': assistantAppAsked,
        'instructionsCompleted': instructionsCompleted,
        'repeatedAsks': repeatedAsks,
      };

  factory RaiStats.fromJson(Map<String, Object?> j) => RaiStats(
        instructionsAsked: (j['instructionsAsked'] as num?)?.toInt() ?? 0,
        assistantAsked: (j['assistantAsked'] as num?)?.toInt() ?? 0,
        assistantAppAsked: (j['assistantAppAsked'] as num?)?.toInt() ?? 0,
        instructionsCompleted: (j['instructionsCompleted'] as num?)?.toInt() ?? 0,
        repeatedAsks: (j['repeatedAsks'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is RaiStats && other.instructionsAsked == instructionsAsked && other.assistantAsked == assistantAsked && other.assistantAppAsked == assistantAppAsked && other.instructionsCompleted == instructionsCompleted && other.repeatedAsks == repeatedAsks;
  @override
  int get hashCode => Object.hash(instructionsAsked, assistantAsked, assistantAppAsked, instructionsCompleted, repeatedAsks);
}

/// 実績の定義: どの数字が閾値に届いたら達成か。
@immutable
class RaiAchievement {
  const RaiAchievement({required this.id, required this.title, required this.description, required this.threshold, required this.count});
  final String id;
  final String title;
  final String description;
  final int threshold;
  final int Function(RaiStats s) count;
}

/// 実績の一覧(表示順)。
final raiAchievements = <RaiAchievement>[
  RaiAchievement(id: 'ask1', title: 'はじめての質問', description: 'インストラクションを 1 回聞いた', threshold: 1, count: (s) => s.instructionsAsked),
  RaiAchievement(id: 'ask10', title: '聞き上手', description: 'インストラクションを 10 回聞いた', threshold: 10, count: (s) => s.instructionsAsked),
  RaiAchievement(id: 'ask50', title: 'RAi の常連', description: 'インストラクションを 50 回聞いた', threshold: 50, count: (s) => s.instructionsAsked),
  RaiAchievement(id: 'app5', title: 'アプリ通', description: 'アシスタントとアプリについて 5 回話した', threshold: 5, count: (s) => s.assistantAppAsked),
  RaiAchievement(id: 'chat20', title: 'おしゃべり', description: 'アシスタントに 20 回話しかけた', threshold: 20, count: (s) => s.assistantAsked),
  RaiAchievement(id: 'done1', title: '一発で完走', description: '案内を最後の手順まで進めた', threshold: 1, count: (s) => s.instructionsCompleted),
  RaiAchievement(id: 'done10', title: '完走マスター', description: '案内を 10 回最後まで進めた', threshold: 10, count: (s) => s.instructionsCompleted),
  RaiAchievement(id: 'again3', title: '復習中', description: '同じ操作を 3 回聞き直した', threshold: 3, count: (s) => s.repeatedAsks),
];

@immutable
class RaiAchievementProgress {
  const RaiAchievementProgress({required this.achievement, required this.count});
  final RaiAchievement achievement;
  final int count;
  bool get unlocked => count >= achievement.threshold;
  double get fraction => (count / achievement.threshold).clamp(0, 1).toDouble();
}

List<RaiAchievementProgress> raiAchievementProgress(RaiStats s) => [for (final a in raiAchievements) RaiAchievementProgress(achievement: a, count: a.count(s))];

class RaiStatsStore extends Notifier<RaiStats> {
  static const storageKey = 'rai.stats.v1';
  bool _loaded = false;

  @override
  RaiStats build() {
    _restore();
    return const RaiStats();
  }

  Future<void> _restore() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw != null && ref.mounted) state = RaiStats.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {}
  }

  void _save() => ref.read(sessionStorageProvider).write(storageKey, jsonEncode(state.toJson())).catchError((_) {});

  void bump({bool instructionAsked = false, bool assistantAsked = false, bool assistantApp = false, bool completed = false, bool repeated = false}) {
    state = state.copyWith(
      instructionsAsked: state.instructionsAsked + (instructionAsked ? 1 : 0),
      assistantAsked: state.assistantAsked + (assistantAsked ? 1 : 0),
      assistantAppAsked: state.assistantAppAsked + (assistantApp ? 1 : 0),
      instructionsCompleted: state.instructionsCompleted + (completed ? 1 : 0),
      repeatedAsks: state.repeatedAsks + (repeated ? 1 : 0),
    );
    _save();
  }
}

final raiStatsProvider = NotifierProvider<RaiStatsStore, RaiStats>(RaiStatsStore.new);

/// 保存された会話 1 つ。[title] は最初の質問(無ければ最初の発言)。
@immutable
class RaiConversation {
  const RaiConversation({required this.id, required this.startedAt, required this.title, required this.log});
  final String id;
  final DateTime startedAt;
  final String title;

  /// 新しい順(画面の履歴と同じ向き)。
  final List<RaiUtterance> log;

  Map<String, Object?> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'title': title,
        'log': [for (final u in log) {'text': u.text, 'at': u.at.toIso8601String(), if (u.query != null) 'query': u.query, if (u.error) 'error': true}],
      };

  factory RaiConversation.fromJson(Map<String, Object?> j) => RaiConversation(
        id: '${j['id']}',
        startedAt: DateTime.tryParse('${j['startedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        title: '${j['title'] ?? ''}',
        log: [
          for (final e in (j['log'] as List? ?? const []).cast<Map>())
            RaiUtterance(text: '${e['text'] ?? ''}', at: DateTime.tryParse('${e['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0), query: e['query'] as String?, error: e['error'] == true),
        ],
      );

  /// 画面の発言の履歴から作る(空なら null)。
  static RaiConversation? fromLog(List<RaiUtterance> log, {String? id}) {
    if (log.isEmpty) return null;
    final first = log.last;
    return RaiConversation(id: id ?? first.at.millisecondsSinceEpoch.toRadixString(36), startedAt: first.at, title: first.query ?? first.text, log: List.unmodifiable(log));
  }
}

class RaiConversationsStore extends Notifier<List<RaiConversation>> {
  static const storageKey = 'rai.conversations.v1';
  static const max = 30;
  bool _loaded = false;

  @override
  List<RaiConversation> build() {
    _restore();
    return const [];
  }

  Future<void> _restore() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw != null && ref.mounted) state = [for (final e in (jsonDecode(raw) as List).cast<Map>()) RaiConversation.fromJson(e.cast<String, Object?>())];
    } catch (_) {}
  }

  void _save() => ref.read(sessionStorageProvider).write(storageKey, jsonEncode([for (final c in state) c.toJson()])).catchError((_) {});

  /// 先頭に足す(同じ id は置き換え)。
  void put(RaiConversation c) {
    state = [c, ...state.where((x) => x.id != c.id)].take(max).toList();
    _save();
  }

  void remove(String id) {
    state = [for (final c in state) if (c.id != id) c];
    _save();
  }
}

final raiConversationsProvider = NotifierProvider<RaiConversationsStore, List<RaiConversation>>(RaiConversationsStore.new);
