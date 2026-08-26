import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../home/post_row.dart';
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
  void _openTuning() {
    final manager = ref.read(overlayManagerProvider);
    manager.showFow(
      id: 'relational.tuning',
      spec: FowSpec(title: 'リレーショナルTL調整', initialHeightFactor: 0.5),
      builder: (_, _) => const _TuningPanel(),
    );
  }
}

/// FOW チューニングパネル (D-028): エンジンの全パラメーターをライブ調整。
/// 変更は即時反映+永続化(`relational.settings.v1`)。
class _TuningPanel extends ConsumerWidget {
  const _TuningPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(relationalSettingsProvider);
    final store = ref.read(relationalSettingsProvider.notifier);
    final w = s.weights;
    final scheme = Theme.of(context).colorScheme;

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
          child: Text(title, style: RasqTypography.caption.copyWith(color: scheme.primary, fontWeight: FontWeight.w700)),
        );

    Widget weight(String title, double value, double max, LinkWeights Function(double) apply) => RasqSliderListTile(
          title: title,
          value: value,
          min: 0,
          max: max,
          divisions: (max * 100).round(),
          valueLabel: value.toStringAsFixed(2),
          onChanged: (v) => store.set(s.copyWith(weights: apply(v))),
        );

    return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
      section('束ね判定'),
      RasqSliderListTile(
        title: '束ねやすさ',
        subtitle: 'リンクしきい値バイアス。低いほど広く束ねる(しきい値自体はコミュニティ別に自動調整)',
        value: s.linkBias.toDouble(),
        min: 50,
        max: 100,
        divisions: 50,
        onChanged: (v) => store.set(s.copyWith(linkBias: v.round())),
      ),
      RasqSliderListTile(
        title: '時間減衰 τ',
        subtitle: 'e^(-Δt/τ)。大きいほど時間が離れた投稿もリンクしやすい',
        value: s.tauSeconds.toDouble(),
        min: 60,
        max: 1800,
        divisions: 29,
        valueLabel: '${s.tauSeconds}秒',
        onChanged: (v) => store.set(s.copyWith(tauSeconds: v.round())),
      ),
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
      section('重み(通常投稿)'),
      weight('内容類似', w.content, 0.8, (v) => w.copyWith(content: v)),
      weight('エンティティ一致', w.entity, 0.5, (v) => w.copyWith(entity: v)),
      weight('時間減衰', w.time, 0.5, (v) => w.copyWith(time: v)),
      weight('ペア親密度', w.affinity, 0.3, (v) => w.copyWith(affinity: v)),
      weight('発話交替', w.turn, 0.2, (v) => w.copyWith(turn: v)),
      weight('アンカー', w.anchor, 0.3, (v) => w.copyWith(anchor: v)),
      section('フラット加点'),
      weight('ハードアンカー(URL/引用先)', w.hardAnchorBonus, 0.4, (v) => w.copyWith(hardAnchorBonus: v)),
      weight('反応表現(それな・わかる等)', w.reactiveBonus, 0.3, (v) => w.copyWith(reactiveBonus: v)),
      weight('コミュニティ事前分布 ±', w.communityPrior, 0.15, (v) => w.copyWith(communityPrior: v)),
      section('ライフサイクル'),
      RasqSliderListTile(
        title: 'TTL 下限',
        value: s.minTtlMinutes.toDouble(),
        min: 1,
        max: 15,
        divisions: 14,
        valueLabel: '${s.minTtlMinutes}分',
        onChanged: (v) => store.set(s.copyWith(minTtlMinutes: v.round())),
      ),
      RasqSliderListTile(
        title: 'TTL 上限',
        value: s.maxTtlMinutes.toDouble(),
        min: 5,
        max: 60,
        divisions: 55,
        valueLabel: '${s.maxTtlMinutes}分',
        onChanged: (v) => store.set(s.copyWith(maxTtlMinutes: v.round())),
      ),
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
}

/// イベントカード: GroupAvatar + 「◯◯+N人」 + ROOT本文 + 共通エンティティ
/// → タップで会話(投稿列)を展開。
class _EventCard extends ConsumerStatefulWidget {
  const _EventCard({required this.event});
  final ConversationEvent event;

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = widget.event;
    final members = e.members;
    final emojis = ref.watch(emojiCacheProvider);
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final others = members.length - 1;
    final tags = [for (final t in e.entities) if (t.length >= 2) t].take(4).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RasqGroupAvatar(users: members, size: RasqSizes.avatarMd, overflowCount: others > 2 ? others - 2 : null),
            const SizedBox(width: RasqSpacing.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(others > 0 ? '${e.root.author.displayName}+$others人' : e.root.author.displayName, style: RasqTypography.displayName),
                RasqRichText(InlineSpans.parse(e.root.body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(spacing: 6, children: [for (final t in tags) Text('#$t', style: RasqTypography.caption.copyWith(color: RasqTokens.of(context).link))]),
                  ),
              ]),
            ),
            Column(children: [
              Icon(_expanded ? Icons.keyboard_arrow_down : Icons.chevron_right, color: scheme.onSurfaceVariant),
              Text('${e.posts.length}件', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ]),
        ),
      ),
      if (_expanded)
        for (final p in e.posts) ...[
          const Divider(indent: RasqSpacing.page * 2),
          Padding(
            padding: const EdgeInsets.only(left: RasqSpacing.page),
            child: PostRow(
              post: p,
              actions: actions,
              onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, a, args: args),
              onTap: () => context.pushPost(p),
              dense: true,
            ),
          ),
        ],
    ]);
  }
}
