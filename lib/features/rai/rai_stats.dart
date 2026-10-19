import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import 'rai_providers.dart';
import '../../l10n/l10n.dart';

/// RAi の実績と会話の履歴 (D-214、RAi サイドバー)。
///
/// - [RaiStats]: 聞いたインストラクションの数 / アシスタントにアプリの話をした数 / 順調に進んだ数 /
///   何度も聞いた数。端末内に保存(`rai.stats.v1`)。
/// - [raiAchievements]: 実績の定義(閾値)。[RaiAchievementProgress] で達成 / 進み具合を出す。
/// - [RaiConversation]: 発言の履歴(RAi の発言 + 質問)のまとまり。「新しい会話」で区切って保存(`rai.conversations.v1`)。

@immutable
class RaiStats {
  const RaiStats({this.instructionsAsked = 0, this.assistantAsked = 0, this.assistantAppAsked = 0, this.instructionsCompleted = 0, this.repeatedAsks = 0, this.automations = 0});

  /// 「スキップ」→ 承認して RAi に任せた回数 (D-226)。
  final int automations;

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

  RaiStats copyWith({int? instructionsAsked, int? assistantAsked, int? assistantAppAsked, int? instructionsCompleted, int? repeatedAsks, int? automations}) => RaiStats(
        instructionsAsked: instructionsAsked ?? this.instructionsAsked,
        assistantAsked: assistantAsked ?? this.assistantAsked,
        assistantAppAsked: assistantAppAsked ?? this.assistantAppAsked,
        instructionsCompleted: instructionsCompleted ?? this.instructionsCompleted,
        repeatedAsks: repeatedAsks ?? this.repeatedAsks,
        automations: automations ?? this.automations,
      );

  Map<String, Object?> toJson() => {
        'instructionsAsked': instructionsAsked,
        'assistantAsked': assistantAsked,
        'assistantAppAsked': assistantAppAsked,
        'instructionsCompleted': instructionsCompleted,
        'repeatedAsks': repeatedAsks,
        'automations': automations,
      };

  factory RaiStats.fromJson(Map<String, Object?> j) => RaiStats(
        instructionsAsked: (j['instructionsAsked'] as num?)?.toInt() ?? 0,
        assistantAsked: (j['assistantAsked'] as num?)?.toInt() ?? 0,
        assistantAppAsked: (j['assistantAppAsked'] as num?)?.toInt() ?? 0,
        instructionsCompleted: (j['instructionsCompleted'] as num?)?.toInt() ?? 0,
        repeatedAsks: (j['repeatedAsks'] as num?)?.toInt() ?? 0,
        automations: (j['automations'] as num?)?.toInt() ?? 0,
      );

  @override
  bool operator ==(Object other) => other is RaiStats && other.instructionsAsked == instructionsAsked && other.assistantAsked == assistantAsked && other.assistantAppAsked == assistantAppAsked && other.instructionsCompleted == instructionsCompleted && other.repeatedAsks == repeatedAsks && other.automations == automations;
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

/// 実績の一覧(表示順)。名前と説明はいまの表示の言語。
List<RaiAchievement> get raiAchievements => <RaiAchievement>[
  RaiAchievement(id: 'ask1', title: appL10n.raiAchievementAsk1Title, description: appL10n.raiAchievementAsk1Description, threshold: 1, count: (s) => s.instructionsAsked),
  RaiAchievement(id: 'ask10', title: appL10n.raiAchievementAsk10Title, description: appL10n.raiAchievementAsk10Description, threshold: 10, count: (s) => s.instructionsAsked),
  RaiAchievement(id: 'ask50', title: appL10n.raiAchievementAsk50Title, description: appL10n.raiAchievementAsk50Description, threshold: 50, count: (s) => s.instructionsAsked),
  RaiAchievement(id: 'app5', title: appL10n.raiAchievementApp5Title, description: appL10n.raiAchievementApp5Description, threshold: 5, count: (s) => s.assistantAppAsked),
  RaiAchievement(id: 'chat20', title: appL10n.raiAchievementChat20Title, description: appL10n.raiAchievementChat20Description, threshold: 20, count: (s) => s.assistantAsked),
  RaiAchievement(id: 'done1', title: appL10n.raiAchievementDone1Title, description: appL10n.raiAchievementDone1Description, threshold: 1, count: (s) => s.instructionsCompleted),
  RaiAchievement(id: 'done10', title: appL10n.raiAchievementDone10Title, description: appL10n.raiAchievementDone10Description, threshold: 10, count: (s) => s.instructionsCompleted),
  RaiAchievement(id: 'again3', title: appL10n.raiAchievementAgain3Title, description: appL10n.raiAchievementAgain3Description, threshold: 3, count: (s) => s.repeatedAsks),
  RaiAchievement(id: 'auto1', title: appL10n.raiAchievementAuto1Title, description: appL10n.raiAchievementAuto1Description, threshold: 1, count: (s) => s.automations),
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

  void bump({bool instructionAsked = false, bool assistantAsked = false, bool assistantApp = false, bool completed = false, bool repeated = false, bool automated = false}) {
    state = state.copyWith(
      instructionsAsked: state.instructionsAsked + (instructionAsked ? 1 : 0),
      assistantAsked: state.assistantAsked + (assistantAsked ? 1 : 0),
      assistantAppAsked: state.assistantAppAsked + (assistantApp ? 1 : 0),
      instructionsCompleted: state.instructionsCompleted + (completed ? 1 : 0),
      repeatedAsks: state.repeatedAsks + (repeated ? 1 : 0),
      automations: state.automations + (automated ? 1 : 0),
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
        'log': [for (final u in log) {'text': u.text, 'at': u.at.toIso8601String(), if (u.query != null) 'query': u.query, if (u.error) 'error': true, if (u.step != null) 'step': u.step, if (u.opId != null) 'op': u.opId}],
      };

  factory RaiConversation.fromJson(Map<String, Object?> j) => RaiConversation(
        id: '${j['id']}',
        startedAt: DateTime.tryParse('${j['startedAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        title: '${j['title'] ?? ''}',
        log: [
          for (final e in (j['log'] as List? ?? const []).cast<Map>())
            RaiUtterance(text: '${e['text'] ?? ''}', at: DateTime.tryParse('${e['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0), query: e['query'] as String?, error: e['error'] == true, step: (e['step'] as num?)?.toInt(), opId: e['op'] as String?),
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

/// 外れた候補の記録 (D-222): チャットの候補タイルの × で「これじゃない」と言われた質問。次のリファレンス拡充の素材。
@immutable
class RaiMiss {
  const RaiMiss({required this.query, required this.rejected, required this.at, this.situation});
  final String query;
  final String? situation;
  final List<String> rejected;
  final DateTime at;

  Map<String, Object?> toJson() => {'query': query, if (situation != null) 'situation': situation, 'rejected': rejected, 'at': at.toIso8601String()};
  factory RaiMiss.fromJson(Map<String, Object?> j) => RaiMiss(
        query: '${j['query'] ?? ''}',
        situation: j['situation'] as String?,
        rejected: [for (final r in (j['rejected'] as List? ?? const [])) '$r'],
        at: DateTime.tryParse('${j['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class RaiMissLog extends Notifier<List<RaiMiss>> {
  static const storageKey = 'rai.misses.v1';
  static const max = 200;
  bool _loaded = false;

  @override
  List<RaiMiss> build() {
    _restore();
    return const [];
  }

  Future<void> _restore() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw != null && ref.mounted) state = [for (final e in (jsonDecode(raw) as List).cast<Map>()) RaiMiss.fromJson(e.cast<String, Object?>())];
    } catch (_) {}
  }

  void add(RaiMiss m) {
    state = [m, ...state].take(max).toList();
    ref.read(sessionStorageProvider).write(storageKey, jsonEncode([for (final x in state) x.toJson()])).catchError((_) {});
  }
}

final raiMissesProvider = NotifierProvider<RaiMissLog, List<RaiMiss>>(RaiMissLog.new);
