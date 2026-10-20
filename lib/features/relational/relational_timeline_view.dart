import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';


import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../../text/inline_spans.dart';
import '../clips/virtual_index.dart';
import '../home/own_posts.dart';
import '../home/timeline_providers.dart';
import 'relational_engine.dart';
import 'relational_providers.dart';
import '../ads/timeline_ads.dart';
import '../../shell/scroll_memory.dart';
import '../../l10n/l10n.dart';

/// 「関連」タブ = リレーショナルTL v1 (D-027、会話イベント方式)。
/// フォロイーの投稿を「どの直前投稿への暗黙応答か」で会話イベントに束ね、
/// **イベントカード**を活動が新しい順に並べる。カードをタップすると中の投稿
/// (PostRow)を展開する。
///
/// - リスト末尾(または空の状態)でさらに引っ張ると **30 分ずつ遡って**
///   TTL で沈んだ過去の空リプ会話を表示に含める(D-028)
/// - 右上 ⚙ は **FOW チューニングパネル**: 背面のタイムラインを見ながら
///   重み・τ・ウィンドウ・TTL をライブ調整できる
class RelationalTimelineView extends ConsumerStatefulWidget {
  const RelationalTimelineView({super.key});

  @override
  ConsumerState<RelationalTimelineView> createState() => _RelationalTimelineViewState();
}

class _RelationalTimelineViewState extends ConsumerState<RelationalTimelineView> {
  double _dragOverscroll = 0;
  bool _firedThisDrag = false;

  /// 位置を覚える (D-504): 関連 TL は重いので隠れたら捨てる(タブの外では生かしておかない、D-508)。戻ったら前の位置から。
  late final RememberedScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = RememberedScrollController(memory: ref.read(scrollMemoryProvider), id: () => scrollMemoryKey(ref, 'tl.relational'));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// 末尾方向のオーバースクロール(クランプ物理は Overscroll 通知、バウンス
  /// 物理は maxScrollExtent 超過)を 1 ドラッグ 1 回だけ拾う。
  bool _onScroll(ScrollNotification n) {
    if (n is OverscrollNotification && n.overscroll > 0) {
      _dragOverscroll += n.overscroll;
    } else if (n is ScrollUpdateNotification && n.metrics.pixels > n.metrics.maxScrollExtent) {
      _dragOverscroll = n.metrics.pixels - n.metrics.maxScrollExtent;
    } else if (n is ScrollEndNotification) {
      _dragOverscroll = 0;
      _firedThisDrag = false;
      return false;
    }
    if (!_firedThisDrag && _dragOverscroll > 48) {
      _firedThisDrag = true;
      _loadOlder();
    }
    return false;
  }

  /// 遡り: 表示窓を 30 分広げ、home TL の過去ページも取りに行く。
  void _loadOlder() {
    ref.read(relationalLookbackProvider.notifier).extend();
    ref.read(timelineProvider(TimelineKind.home).notifier).loadMore();
  }

  Future<void> _refresh() {
    ref.read(relationalLookbackProvider.notifier).reset();
    return ref.read(timelineProvider(TimelineKind.home).notifier).refresh();
  }

  String _lookbackLabel(int minutes) {
    final l = context.l10n;
    return minutes >= 60 ? (minutes % 60 == 0 ? l.relationalDurationHours(minutes ~/ 60) : l.relationalDurationHoursMinutes(minutes ~/ 60, minutes % 60)) : l.relationalDurationMinutes(minutes);
  }

  /// 読み直しを済ませた自分の投稿 (D-507)。
  late int _ownSeq = ref.read(ownPostsProvider)?.seq ?? 0;

  @override
  Widget build(BuildContext context) {
    // 自分が投稿した (D-507): 関連 TL の元(フォロー中の TL)に足す。隠れている間は次に見えたときに。
    final own = ref.watch(ownPostsProvider)?.seq ?? 0;
    if (own != _ownSeq && TickerMode.valuesOf(context).enabled) {
      _ownSeq = own;
      Future.microtask(() {
        if (mounted) ref.read(timelineProvider(TimelineKind.home).notifier).prependNewer();
      });
    }
    final events = ref.watch(conversationEventsProvider);
    final settings = ref.watch(relationalSettingsProvider);
    final lookback = ref.watch(relationalLookbackProvider);
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: RasqSpacing.sm),
              child: Text(rasqDetail(context, context.l10n.relationalHeader, context.l10n.relationalHeaderDetail(settings.linkBias, settings.maxTtlMinutes)), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ),
          RasqIconButton(icon: Icons.tune, size: 20, tooltip: context.l10n.relationalTuningTitle, onPressed: _openTuning),
        ]),
      ),
      if (lookback > 0)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Row(children: [
            Icon(Icons.history, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(child: Text(context.l10n.relationalLookback(_lookbackLabel(lookback)), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
            TextButton(onPressed: () => ref.read(relationalLookbackProvider.notifier).reset(), child: Text(context.l10n.relationalLookbackReset)),
          ]),
        ),
      Expanded(
        child: events.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.relationalTimelineBroken, onRetry: () => ref.invalidate(timelineProvider(TimelineKind.home)), retryLabel: context.l10n.relationalRetry),
          data: (list) => NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: list.isEmpty
                ? RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                      const SizedBox(height: 120),
                      RasqEmptyView(title: context.l10n.relationalEmptyTitle, hint: context.l10n.relationalEmptyHint),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: Builder(builder: (context) {
                      // 会話の間の広告 (D-438): 会話の最初の投稿が危なくないところにだけ。
                      final ads = timelineAdGaps(ref, [for (final e in list) e.root]);
                      final adOrdinal = {for (final (n, g) in (ads.toList()..sort()).indexed) g: n};
                      return ListView.separated(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const Divider(),
                        itemBuilder: (_, i) => ads.contains(i)
                            ? Column(mainAxisSize: MainAxisSize.min, children: [TimelineAdSlot(key: ValueKey('relational.ad.$i'), ordinal: adOrdinal[i]!), const Divider(), RelationalEventCard(event: list[i])])
                            : RelationalEventCard(event: list[i]),
                      );
                    }),
                  ),
          ),
        ),
      ),
    ]);
  }

  /// FOW(widget タイプ)= 背面のタイムラインが動いたまま調整できる。
  /// 絵文字ピッカー FOW と同じ作法: キャンセル(空白クリック・esc 含む)で
  /// 開いたときの設定に巻き戻し、決定で確定。
  Future<void> _openTuning() => openRelationalTuning(ref);
}

/// リレーショナル TL 調整の FOW (D-028)。関連タブの調整ボタンと、設定「投稿クラスター」(D-238) から開く。
/// FOW(widget タイプ)= 背面のタイムラインが動いたまま調整できる。キャンセルで開いたときの設定に巻き戻し、決定で確定。
Future<void> openRelationalTuning(WidgetRef ref) async {
  {
    final manager = ref.read(overlayManagerProvider);
    final store = ref.read(relationalSettingsProvider.notifier);
    final snapshot = ref.read(relationalSettingsProvider);
    final result = await manager.showFow<bool>(
      id: 'relational.tuning',
      spec: FowSpec(
        type: FowPanelType.widget,
        initialHeightFactor: 0.5,
        minHeightFactor: 0.25,
        maxHeightFactor: 0.9,
        title: appL10n.relationalTuningTitle,
        cancelText: appL10n.relationalTuningCancel,
        confirmText: appL10n.relationalTuningConfirm,
      ),
      builder: (_, _) => const _TuningPanel(),
    );
    if (result != true) store.set(snapshot);
  }
}

/// FOW チューニングパネル (D-028)。変更は即時反映+永続化
/// (`relational.settings.v1`)、キャンセル時は呼び出し側が巻き戻す。
///
/// 通常表示は要点 6 つ+TTL(RangeSlider)に絞り、全パラメーターは
/// 「詳細設定」タイルからの遷移で表示する。
class _TuningPanel extends ConsumerStatefulWidget {
  const _TuningPanel();

  @override
  ConsumerState<_TuningPanel> createState() => _TuningPanelState();
}

class _TuningPanelState extends ConsumerState<_TuningPanel> {
  bool _advanced = false;

  static const _defaults = LinkWeights();

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
        child: Text(title, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
      );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(relationalSettingsProvider);
    final store = ref.read(relationalSettingsProvider.notifier);
    final w = s.weights;

    Widget weight(String title, double value, double max, LinkWeights Function(double) apply, {String? subtitle}) => RasqSliderListTile(
          title: title,
          subtitle: subtitle,
          value: value,
          min: 0,
          max: max,
          divisions: (max * 100).round(),
          valueLabel: value.toStringAsFixed(2),
          onChanged: (v) => store.set(s.copyWith(weights: apply(v))),
        );

    final l = context.l10n;
    if (_advanced) {
      return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.arrow_back, size: 20),
          title: Text(context.l10n.relationalAdvanced),
          onTap: () => setState(() => _advanced = false),
        ),
        _section(context, l.relationalSectionLinking),
        RasqSliderListTile(
          title: l.relationalCandidateWindow,
          subtitle: l.relationalCandidateWindowSubtitle,
          value: s.candidateWindowMinutes.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          valueLabel: l.relationalMinutesValue(s.candidateWindowMinutes),
          onChanged: (v) => store.set(s.copyWith(candidateWindowMinutes: v.round())),
        ),
        _section(context, l.relationalSectionWeightsPlain),
        weight(l.relationalWeightContent, w.content, 0.8, (v) => w.copyWith(content: v)),
        weight(l.relationalWeightEntity, w.entity, 0.5, (v) => w.copyWith(entity: v)),
        weight(l.relationalWeightTime, w.time, 0.5, (v) => w.copyWith(time: v)),
        weight(l.relationalWeightAffinity, w.affinity, 0.3, (v) => w.copyWith(affinity: v)),
        weight(l.relationalWeightTurn, w.turn, 0.2, (v) => w.copyWith(turn: v)),
        weight(l.relationalWeightAnchor, w.anchor, 0.3, (v) => w.copyWith(anchor: v)),
        _section(context, l.relationalSectionFlatBonus),
        weight(l.relationalWeightCommunityPrior, w.communityPrior, 0.15, (v) => w.copyWith(communityPrior: v)),
        _section(context, l.relationalSectionLifecycle),
        RasqSliderListTile(
          title: l.relationalTentativeHold,
          subtitle: l.relationalTentativeHoldSubtitle,
          value: s.tentativeHoldSeconds.toDouble(),
          min: 30,
          max: 300,
          divisions: 27,
          valueLabel: l.relationalSecondsValue(s.tentativeHoldSeconds),
          onChanged: (v) => store.set(s.copyWith(tentativeHoldSeconds: v.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
          child: OutlinedButton.icon(icon: const Icon(Icons.restart_alt, size: 18), label: Text(l.relationalResetDefaults), onPressed: store.reset),
        ),
      ]);
    }

    // 類似性 = 内容類似 + エンティティ、親密度 = ペア親密度 + 発話交替。
    // まとめスライダーは既定の内訳比率を保ったまま両方をスケールする。
    final similarity = w.content + w.entity;
    final closeness = w.affinity + w.turn;
    const simBase = 0.45 + 0.20;
    const closeBase = 0.10 + 0.05;

    return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
      _section(context, l.relationalSectionLinking),
      RasqSliderListTile(
        title: l.relationalLinkBias,
        subtitle: l.relationalLinkBiasSubtitle,
        value: s.linkBias.toDouble(),
        min: 50,
        max: 100,
        divisions: 50,
        onChanged: (v) => store.set(s.copyWith(linkBias: v.round())),
      ),
      RasqSliderListTile(
        title: l.relationalWeightTime,
        subtitle: l.relationalTauSubtitle,
        value: s.tauSeconds.toDouble(),
        min: 60,
        max: 1800,
        divisions: 29,
        valueLabel: l.relationalSecondsValue(s.tauSeconds),
        onChanged: (v) => store.set(s.copyWith(tauSeconds: v.round())),
      ),
      _section(context, l.relationalSectionWeights),
      RasqSliderListTile(
        title: l.relationalSimilarity,
        subtitle: l.relationalSimilaritySubtitle,
        value: similarity,
        min: 0,
        max: 1.0,
        divisions: 100,
        valueLabel: similarity.toStringAsFixed(2),
        onChanged: (v) => store.set(s.copyWith(weights: w.copyWith(content: v * _defaults.content / simBase, entity: v * _defaults.entity / simBase))),
      ),
      RasqSliderListTile(
        title: l.relationalCloseness,
        subtitle: l.relationalClosenessSubtitle,
        value: closeness,
        min: 0,
        max: 0.45,
        divisions: 45,
        valueLabel: closeness.toStringAsFixed(2),
        onChanged: (v) => store.set(s.copyWith(weights: w.copyWith(affinity: v * _defaults.affinity / closeBase, turn: v * _defaults.turn / closeBase))),
      ),
      _section(context, l.relationalSectionExtra),
      weight(l.relationalHardAnchor, w.hardAnchorBonus, 0.4, (v) => w.copyWith(hardAnchorBonus: v)),
      weight(l.relationalReactive, w.reactiveBonus, 0.3, (v) => w.copyWith(reactiveBonus: v)),
      _section(context, l.relationalSectionLifecycle),
      RasqRangeSliderListTile(
        title: 'TTL',
        subtitle: l.relationalTtlSubtitle,
        values: RangeValues(s.minTtlMinutes.toDouble(), s.maxTtlMinutes.toDouble()),
        min: 1,
        max: 60,
        divisions: 59,
        valueLabel: l.relationalTtlValue(s.minTtlMinutes, s.maxTtlMinutes),
        onChanged: (v) {
          final lo = v.start.round().clamp(1, 60);
          final hi = v.end.round().clamp(lo, 60);
          store.set(s.copyWith(minTtlMinutes: lo, maxTtlMinutes: hi));
        },
      ),
      ListTile(
        dense: true,
        leading: const Icon(Icons.tune, size: 20),
        title: Text(l.relationalAdvanced),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => setState(() => _advanced = true),
      ),
    ]);
  }
}

/// イベントタイル (D-037): GroupAvatar + 「◯◯+N人」+ **実在語の見出し** +
/// 1 行要約(要約が無ければ ROOT 本文)。タップで**リレーショナルページ**へ
/// 遷移する(以前のドロップダウン展開は廃止 — 1行/3行要約を分けるため)。
/// 会話イベントの 1 カード(関連タブ、トレンドの「フォロー中の反応」D-364)。
class RelationalEventCard extends ConsumerWidget {
  const RelationalEventCard({super.key, required this.event});
  final ConversationEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final e = event;
    // チャイルドセーフ (D-407、指摘 #26 / #27): 見せない投稿は見出し / チップ / メンバー / 要約にも使わない。
    final shown = childSafeEventPosts(ref.watch(childGateProvider), e);
    if (shown == null) return const SizedBox.shrink();
    final filtered = shown.length != e.posts.length;
    final members = eventMembersOf(shown);
    final emojis = ref.watch(emojiCacheProvider);
    // 自分も会話に含まれるが、アイコンはタイルに出さない(全員自分なら残す)。
    final selfKey = ref.watch(currentUserProvider).key;
    final avatarUsers = [for (final u in members) if (u.key != selfKey) u];
    final shownUsers = avatarUsers.isEmpty ? members : avatarUsers;
    final others = members.length - 1;
    final headline = sharedHeadline(shown);
    final tags = topSharedLabels(shown);
    // ASTell 要約(1 行。実行手段が無ければ ROOT 本文)。見せない投稿を含むイベントの要約は出さない。
    final summary = filtered ? null : ref.watch(eventSummaryProvider(e.id)).value;

    return InkWell(
      onTap: () => context.pushRelationalEvent(e),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RasqGroupAvatar(users: shownUsers, size: RasqSizes.avatarMd, overflowCount: shownUsers.length > 3 ? shownUsers.length - 3 : null),
          const SizedBox(width: RasqSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(others > 0 ? context.l10n.relationalEventTitle(e.root.author.displayName, others) : e.root.author.displayName, style: RasqTypography.displayName),
              if (headline != null) Text(headline, style: RasqTypography.displayName.copyWith(fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (summary != null)
                Text(summary, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)
              else
                RasqRichText(InlineSpans.parse(e.root.body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 6, children: [for (final t in tags) Text(t, style: RasqTypography.caption.copyWith(color: RasqTokens.of(context).link))]),
                ),
            ]),
          ),
          Column(children: [
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            Text(context.l10n.relationalEventPostCount(shown.length), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }
}
