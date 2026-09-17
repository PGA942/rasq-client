import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../clips/virtual_index.dart';
import '../home/timeline_providers.dart';
import 'relational_engine.dart';
import 'relational_providers.dart';

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

  String _lookbackLabel(int minutes) => minutes >= 60 ? (minutes % 60 == 0 ? '${minutes ~/ 60}時間' : '${minutes ~/ 60}時間${minutes % 60}分') : '$minutes分';

  @override
  Widget build(BuildContext context) {
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
              child: Text('束ねやすさ ${settings.linkBias} / 会話のテンポに応じて最長${settings.maxTtlMinutes}分で沈む', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
          ),
          RasqIconButton(icon: Icons.tune, size: 20, tooltip: 'リレーショナルTL調整', onPressed: _openTuning),
        ]),
      ),
      if (lookback > 0)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Row(children: [
            Icon(Icons.history, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(child: Text('${_lookbackLabel(lookback)}前の会話まで表示中(引っ張るとさらに遡る)', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
            TextButton(onPressed: () => ref.read(relationalLookbackProvider.notifier).reset(), child: const Text('戻す')),
          ]),
        ),
      Expanded(
        child: events.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.relationalTimelineBroken, onRetry: () => ref.invalidate(timelineProvider(TimelineKind.home)), retryLabel: '再読み込み'),
          data: (list) => NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: list.isEmpty
                ? RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [
                      SizedBox(height: 120),
                      RasqEmptyView(title: 'いま進行中の会話はありません', hint: 'フォロイーの空リプや会話が始まると、ここに束ねて表示します。上方向へ引っ張ると過去の会話を遡ります'),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (_, i) => _EventCard(event: list[i]),
                    ),
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
        title: 'リレーショナルTL調整',
        cancelText: 'キャンセル',
        confirmText: '決定',
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

    if (_advanced) {
      return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
        ListTile(
          dense: true,
          leading: const Icon(Icons.arrow_back, size: 20),
          title: const Text('詳細設定'),
          onTap: () => setState(() => _advanced = false),
        ),
        _section(context, '束ね判定'),
        RasqSliderListTile(
          title: '候補ウィンドウ',
          subtitle: '親候補を探す直近の範囲',
          value: s.candidateWindowMinutes.toDouble(),
          min: 5,
          max: 120,
          divisions: 23,
          valueLabel: '${s.candidateWindowMinutes}分',
          onChanged: (v) => store.set(s.copyWith(candidateWindowMinutes: v.round())),
        ),
        _section(context, '重み(通常投稿)'),
        weight('内容類似', w.content, 0.8, (v) => w.copyWith(content: v)),
        weight('エンティティ一致', w.entity, 0.5, (v) => w.copyWith(entity: v)),
        weight('時間減衰', w.time, 0.5, (v) => w.copyWith(time: v)),
        weight('ペア親密度', w.affinity, 0.3, (v) => w.copyWith(affinity: v)),
        weight('発話交替', w.turn, 0.2, (v) => w.copyWith(turn: v)),
        weight('アンカー', w.anchor, 0.3, (v) => w.copyWith(anchor: v)),
        _section(context, 'フラット加点'),
        weight('コミュニティ事前分布 ±', w.communityPrior, 0.15, (v) => w.copyWith(communityPrior: v)),
        _section(context, 'ライフサイクル'),
        RasqSliderListTile(
          title: '仮 ROOT 保留',
          subtitle: '新話題として確定するまでの保留時間',
          value: s.tentativeHoldSeconds.toDouble(),
          min: 30,
          max: 300,
          divisions: 27,
          valueLabel: '${s.tentativeHoldSeconds}秒',
          onChanged: (v) => store.set(s.copyWith(tentativeHoldSeconds: v.round())),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
          child: OutlinedButton.icon(icon: const Icon(Icons.restart_alt, size: 18), label: const Text('既定に戻す'), onPressed: store.reset),
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
      _section(context, '束ね判定'),
      RasqSliderListTile(
        title: '束ねやすさ',
        subtitle: '低いほど広く束ねる(しきい値はコミュニティ別に自動調整)',
        value: s.linkBias.toDouble(),
        min: 50,
        max: 100,
        divisions: 50,
        onChanged: (v) => store.set(s.copyWith(linkBias: v.round())),
      ),
      RasqSliderListTile(
        title: '時間減衰',
        subtitle: '大きいほど時間が離れた投稿もリンクしやすい(τ)',
        value: s.tauSeconds.toDouble(),
        min: 60,
        max: 1800,
        divisions: 29,
        valueLabel: '${s.tauSeconds}秒',
        onChanged: (v) => store.set(s.copyWith(tauSeconds: v.round())),
      ),
      _section(context, '重み'),
      RasqSliderListTile(
        title: '類似性',
        subtitle: '内容類似+エンティティ一致(内訳は詳細設定)',
        value: similarity,
        min: 0,
        max: 1.0,
        divisions: 100,
        valueLabel: similarity.toStringAsFixed(2),
        onChanged: (v) => store.set(s.copyWith(weights: w.copyWith(content: v * _defaults.content / simBase, entity: v * _defaults.entity / simBase))),
      ),
      RasqSliderListTile(
        title: '親密度',
        subtitle: 'ペア親密度+発話交替(内訳は詳細設定)',
        value: closeness,
        min: 0,
        max: 0.45,
        divisions: 45,
        valueLabel: closeness.toStringAsFixed(2),
        onChanged: (v) => store.set(s.copyWith(weights: w.copyWith(affinity: v * _defaults.affinity / closeBase, turn: v * _defaults.turn / closeBase))),
      ),
      _section(context, '追加判定'),
      weight('ハードアンカー(URL/引用先)', w.hardAnchorBonus, 0.4, (v) => w.copyWith(hardAnchorBonus: v)),
      weight('反応表現(それな・わかる等)', w.reactiveBonus, 0.3, (v) => w.copyWith(reactiveBonus: v)),
      _section(context, 'ライフサイクル'),
      RasqRangeSliderListTile(
        title: 'TTL',
        subtitle: '会話が沈むまでの時間。投稿間隔からこの範囲内で自動調整',
        values: RangeValues(s.minTtlMinutes.toDouble(), s.maxTtlMinutes.toDouble()),
        min: 1,
        max: 60,
        divisions: 59,
        valueLabel: '${s.minTtlMinutes}〜${s.maxTtlMinutes}分',
        onChanged: (v) {
          final lo = v.start.round().clamp(1, 60);
          final hi = v.end.round().clamp(lo, 60);
          store.set(s.copyWith(minTtlMinutes: lo, maxTtlMinutes: hi));
        },
      ),
      ListTile(
        dense: true,
        leading: const Icon(Icons.tune, size: 20),
        title: const Text('詳細設定'),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: () => setState(() => _advanced = true),
      ),
    ]);
  }
}

/// イベントタイル (D-037): GroupAvatar + 「◯◯+N人」+ **実在語の見出し** +
/// 1 行要約(要約が無ければ ROOT 本文)。タップで**リレーショナルページ**へ
/// 遷移する(以前のドロップダウン展開は廃止 — 1行/3行要約を分けるため)。
class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event});
  final ConversationEvent event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final e = event;
    final members = e.members;
    final emojis = ref.watch(emojiCacheProvider);
    // 自分も会話に含まれるが、アイコンはタイルに出さない(全員自分なら残す)。
    final selfKey = ref.watch(currentUserProvider).key;
    final avatarUsers = [for (final u in members) if (u.key != selfKey) u];
    final shownUsers = avatarUsers.isEmpty ? members : avatarUsers;
    final others = members.length - 1;
    final headline = sharedHeadline(e.posts);
    final tags = topSharedLabels(e.posts);
    // ASTell 要約(1 行。実行手段が無ければ ROOT 本文)。
    final summary = ref.watch(eventSummaryProvider(e.id)).value;

    return InkWell(
      onTap: () => context.push('/relational/event', extra: e),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RasqGroupAvatar(users: shownUsers, size: RasqSizes.avatarMd, overflowCount: shownUsers.length > 3 ? shownUsers.length - 3 : null),
          const SizedBox(width: RasqSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(others > 0 ? '${e.root.author.displayName}+$others人' : e.root.author.displayName, style: RasqTypography.displayName),
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
            Text('${e.posts.length}件', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }
}
