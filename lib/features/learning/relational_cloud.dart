import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/learning_api.dart';
import '../../backend/orgate_client.dart';
import '../child_safe/child_safe_providers.dart';
import '../relational/relational_engine.dart';
import '../settings/settings_dsl.dart';
import 'contribution.dart';

/// クラウド版のリレーショナルタイムライン (D-367 / Central S-050)。**アルゴリズムとコミュニティへの貢献に同意した人だけ**。
///
/// 端末のエンジンは、しきい値の近く(± [ConversationEngine.borderlineMargin])で決めた結び付き(投稿 → 会話)を
/// [ConversationEngine.borderline] に控える。ここで集めて Central の `POST /me/relational/judge` に送り、クラウドの RAi(LLM)が
/// 「同じ会話か」を決める。返ってきた判定は [ConversationEngine.decisions] としてエンジンに戻し、TL を組み直す。
/// Central は判定の例を残す(**怪しいけど違う** = 端末は結び付けた / 結び付けかけた → クラウドは別の会話、など)。
///
/// - 投稿の書き手は、貢献の判定([ContributionController.ensureVerdicts])で許可の人と自分だけ。許可でない人を含む組は送らない。
/// - 設定 `learning.contrib.v1` の `cloudRelational`(既定オン)で止められる。見守り中の端末は使わない。
/// - 判定は起動のあいだ覚えておく(同じ組は 2 度送らない)。

@immutable
class RelationalCloudState {
  const RelationalCloudState({
    this.active = false,
    this.decisions = const {},
    this.reasons = const {},
    this.pending = 0,
    this.hardNegative = 0,
    this.hardPositive = 0,
    this.agree = 0,
    this.skipped = 0,
    this.busy = false,
  });

  /// 同意済み・受付中・設定オン・見守りでない。
  final bool active;

  /// [relationalPairKey] → 同じ会話か(クラウドの判定)。
  final Map<String, bool> decisions;
  final Map<String, String> reasons;
  final int pending;

  /// この起動での判定の内訳(怪しいけど違う / 分けたけど同じ / 一致)。
  final int hardNegative;
  final int hardPositive;
  final int agree;

  /// 書き手の許可が無くて送らなかった組。
  final int skipped;
  final bool busy;

  RelationalCloudState copyWith({bool? active, Map<String, bool>? decisions, Map<String, String>? reasons, int? pending, int? hardNegative, int? hardPositive, int? agree, int? skipped, bool? busy}) => RelationalCloudState(
        active: active ?? this.active,
        decisions: decisions ?? this.decisions,
        reasons: reasons ?? this.reasons,
        pending: pending ?? this.pending,
        hardNegative: hardNegative ?? this.hardNegative,
        hardPositive: hardPositive ?? this.hardPositive,
        agree: agree ?? this.agree,
        skipped: skipped ?? this.skipped,
        busy: busy ?? this.busy,
      );
}

/// 組 → 送る形。書き手の番号は [authors] に足しながら振る(自分は -1)。
Map<String, Object?> relationalPairJson(BorderlinePair p, List<ContributionAuthor> authors) {
  int indexOf(Post x) {
    if (isOwnPost(x)) return -1;
    final a = contributionAuthorOf(x);
    final i = authors.indexWhere((y) => y.key == a.key);
    if (i >= 0) return i;
    authors.add(a);
    return authors.length - 1;
  }

  Map<String, Object?> post(Post x) => {'a': indexOf(x), 't': redactContributionText(x.body.length > 280 ? x.body.substring(0, 280) : x.body), 'at': x.createdAt.toUtc().toIso8601String()};
  return {
    'key': p.key,
    'post': post(p.post),
    'event': [for (final x in p.event) post(x)],
    'entities': {for (final x in p.event) ...extractFeatures(x)}.take(12).toList(),
    'score': double.parse(p.score.toStringAsFixed(3)),
    'threshold': double.parse(p.threshold.toStringAsFixed(3)),
    'joined': p.joined,
  };
}

class RelationalCloudController extends Notifier<RelationalCloudState> {
  static Duration debounce = const Duration(seconds: 15);
  static const maxPairsPerRun = 12;

  final _pending = <String, BorderlinePair>{};
  final _skipped = <String>{};
  Timer? _timer;
  RelationalCloudState? _last;

  @override
  set state(RelationalCloudState value) {
    _last = value;
    super.state = value;
  }

  @override
  RelationalCloudState build() {
    ref.onDispose(() => _timer?.cancel());
    // 貢献の provider は関連 TL を listen しているので、ここでは watch しない(循環になる)。同じ条件を直接見る。
    final learning = ref.watch(learningProvider).value;
    final settings = ref.watch(settingsAreaProvider(contributionArea)).value ?? const {};
    final supervised = ref.watch(childGateProvider).supervised;
    // 他人の投稿をクラウドで処理し例として残すので、検証用の範囲 (extended) だけ (D-370 / S-051)。
    final active = learning != null && learning.granted && learning.open && learning.extended && !supervised && settings['cloudRelational'] != false;
    if (!active) _pending.clear();
    final prev = _last ?? const RelationalCloudState();
    // 止めたら判定も使わない(端末のエンジンだけに戻る)。
    return _last = prev.copyWith(active: active, decisions: active ? prev.decisions : const {}, pending: _pending.length, busy: false);
  }

  /// 関連 TL を組んだあとに、しきい値の近くの組を渡す(`conversationEventsProvider` から)。
  void offer(List<BorderlinePair> pairs) {
    if (!state.active) return;
    var added = 0;
    for (final p in pairs) {
      if (state.decisions.containsKey(p.key) || _skipped.contains(p.key) || _pending.containsKey(p.key)) continue;
      if (!isPublicPost(p.post) || p.event.any((x) => !isPublicPost(x))) continue;
      _pending[p.key] = p;
      added++;
    }
    if (added == 0) return;
    state = state.copyWith(pending: _pending.length);
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    final client = ref.read(centralClientProvider);
    if (client == null || !state.active || state.busy || _pending.isEmpty) return;
    state = state.copyWith(busy: true);
    try {
      final batch = _pending.values.take(maxPairsPerRun).toList();
      // 書き手の判定を揃え、許可の人と自分だけの組にする。
      final contribution = ref.read(contributionProvider.notifier);
      final verdicts = await contribution.ensureVerdicts([
        for (final p in batch)
          for (final x in [p.post, ...p.event])
            if (!isOwnPost(x)) contributionAuthorOf(x),
      ]);
      final send = <BorderlinePair>[];
      var skipped = 0;
      for (final p in batch) {
        final keys = [for (final x in [p.post, ...p.event]) if (!isOwnPost(x)) contributionAuthorOf(x).key];
        if (keys.any((k) => verdicts[k] == null || verdicts[k]!.verdict == 'unknown')) continue; // 判定待ち → 次へ
        _pending.remove(p.key);
        if (keys.every((k) => verdicts[k]!.allowed)) {
          send.add(p);
        } else {
          _skipped.add(p.key);
          skipped++;
        }
      }
      if (send.isNotEmpty) {
        final authors = <ContributionAuthor>[];
        final pairs = [for (final p in send) relationalPairJson(p, authors)];
        final res = await LearningApi(client).relationalJudge({
          'authors': [for (final a in authors) {'host': a.host, 'id': a.id}],
          'pairs': pairs,
        });
        final decisions = {...state.decisions};
        final reasons = {...state.reasons};
        var hn = 0, hp = 0, ag = 0;
        for (final d in res.decisions) {
          final key = '${d['key']}';
          decisions[key] = d['same'] == true;
          reasons[key] = '${d['reason'] ?? ''}';
          switch (d['kind']) {
            case 'hard_negative':
              hn++;
            case 'hard_positive':
              hp++;
            default:
              ag++;
          }
        }
        _skipped.addAll(res.skipped);
        state = state.copyWith(decisions: decisions, reasons: reasons, hardNegative: state.hardNegative + hn, hardPositive: state.hardPositive + hp, agree: state.agree + ag, skipped: state.skipped + skipped + res.skipped.length);
      } else if (skipped > 0) {
        state = state.copyWith(skipped: state.skipped + skipped);
      }
    } catch (e) {
      debugPrint('relational cloud: $e');
    } finally {
      state = state.copyWith(busy: false, pending: _pending.length);
    }
  }
}

final relationalCloudProvider = NotifierProvider<RelationalCloudController, RelationalCloudState>(RelationalCloudController.new);

/// エンジンに渡す判定(クラウド版が止まっていれば空)。
final relationalCloudDecisionsProvider = Provider<Map<String, bool>>((ref) => ref.watch(relationalCloudProvider.select((s) => s.decisions)));
