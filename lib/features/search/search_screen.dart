import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../settings/settings_dsl.dart';
import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../plugins/slot_plugins.dart';
import '../../shell/rasq_shell.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../child_safe/child_safe_screens.dart' show ChildSafeBlockedView, ChildSafeGreyed;
import '../trend/tendency_fows.dart';
import '../trend/trend_providers.dart';
import 'search_filter.dart';
import 'search_history.dart';
import 'search_filter_bar_view.dart';

/// 検索ホーム / トレンドホーム: 広告枠(AdSlot) → トレンド(ワード一覧) → Today.
/// Phase-1 sample sources trends from the SNS (`hashtags/trend`) and Today
/// from `notes/featured` until the trend provider / server exists.
///
/// 検索欄にフォーカスが当たると下方向に拡幅して検索フィルタ行が現れる
/// (D-021。設定後は常時表示、結果画面のトレンドTLへ引き継がれる)。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;
    final trends = ref.watch(trendFrameTagsProvider); // トレンド枠ノード対応 (D-113)
    final today = ref.watch(timelineProvider(DynamicTimelines.featured));
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const [];
    final genreCandidates = trends.value?.map((t) => t.tag).take(maxGenreChips).toList() ?? const <String>[];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // 検索ボックス一体型(D-021 改): フォーカスで下方向に拡幅する角丸タイル。
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: me.displayName, onTap: () => RasqShell.openSidebar(context, ref)),
              ),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(
                // チャイルドセーフ (D-307): 保護者が投稿の検索を止めていれば、入力欄を薄くして理由を出す。
                child: ChildSafeGreyed(
                  reason: ref.watch(childGateProvider).searchAllowed('posts') ? null : '保護者が投稿の検索を止めています',
                  child: SearchFilterBox(
                  controller: _controller,
                  focusNode: _focus,
                  genreCandidates: genreCandidates,
                  onSubmitted: (q) {
                    final tag = q.trim().replaceFirst(RegExp(r'^#'), '');
                    if (tag.isEmpty) return;
                    // 最近の検索 (D-259): 掛けていたジャンルの絞り込みも一緒に控える。
                    ref.read(searchHistoryProvider.notifier).record(tag, chips: ref.read(searchFilterProvider).genres);
                    context.pushTrend(tag);
                  },
                ),
                ),
              ),
            ]),
          ),
          Expanded(child: _home(context, scheme, trends, today, actions)),
        ]),
      ),
    );
  }

  Widget _home(BuildContext context, ColorScheme scheme, AsyncValue<List<TrendTag>> trends, AsyncValue<TimelineState> today, List<ActionDescriptor> actions) {
    // チャイルドセーフ (D-307): トレンドを止めていれば、トレンドと Today を出さない。
    if (!ref.watch(childGateProvider).searchAllowed('trend')) return const ChildSafeBlockedView(message: '保護者がトレンドを止めています');
    return RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(trendingTagsProvider);
          ref.invalidate(trendFrameTagsProvider);
          await ref.read(timelineProvider(DynamicTimelines.featured).notifier).refresh();
        },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          // AdSlot — renderer-owned insertion point (検索ホーム固定位置). 設定「リソースと広告」(D-238) で隠せる。
          if (settingValue(ref, 'resources', 'showAds', true) != false)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), color: scheme.surfaceContainerHighest, child: Text('広告', style: TextStyle(fontSize: 28, color: scheme.onSurfaceVariant))),
          ),
          // TL 系は全部同 UI (D-124): トレンドのカスタマイズ画面へ。
          // トレンドプロファイル設定 (D-153): ジャンル / 指向性・刺激性 / プラグイン / キャッシュ / ノード編集。
          RasqSectionHeader(title: 'トレンド', trailing: RasqIconButton(icon: Icons.settings, size: 20, onPressed: () => showTrendProfileSheet(context, ref), tooltip: 'トレンド設定')),
          ...trends.when(
            loading: () => const [RasqLoading()],
            error: (e, _) => [RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), compact: true, onRetry: () => ref.invalidate(trendFrameTagsProvider), retryLabel: '再読み込み')],
            data: (list) => list.isEmpty
                ? const [RasqEmptyView(title: 'トレンドはありません', hint: 'トレンドの取得は準備中です')]
                : [for (final t in list.take(8)) _TrendTile(trend: t, onTap: () => context.pushTrend(t.tag))],
          ),
          // トレンドプラグインのサジェスト (D-167、スロット `trend.suggest`)。
          _TrendSuggestions(recent: [for (final t in trends.value ?? const <TrendTag>[]) t.tag]),
          const RasqSectionHeader(title: 'Today'),
          ...today.when(
            loading: () => const [RasqLoading()],
            error: (e, _) => [RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), compact: true)],
            data: (s) => s.posts.isEmpty
                ? const [RasqEmptyView(title: 'Today', hint: 'ハイライトはまだありません')]
                : [
                    for (final p in s.posts.take(10)) ...[
                      PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => ref.read(timelineProvider(DynamicTimelines.featured).notifier).perform(p, a, args: args), onTap: () => context.pushPost(p)),
                      const Divider(),
                    ],
                  ],
          ),
          const SizedBox(height: 80),
        ]),
      );
  }
}

class _TrendTile extends StatelessWidget {
  const _TrendTile({required this.trend, required this.onTap});
  final TrendTag trend;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final count = trend.postsCount ?? trend.usersCount;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trend.tag, style: RasqTypography.title.copyWith(fontSize: 16)),
              const SizedBox(height: 2),
              Row(children: [
                if (count != null) Text('$count ${trend.postsCount != null ? 'Post' : 'Users'}', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(width: 12),
                for (final r in trend.related.take(3)) Padding(padding: const EdgeInsets.only(right: 8), child: Text(r, style: RasqTypography.bodySmall.copyWith(color: tokens.link))),
              ]),
            ]),
          ),
          if (trend.chart.isNotEmpty) SizedBox(width: 56, height: 20, child: CustomPaint(painter: _Sparkline(trend.chart, tokens.link))),
          RasqIconButton(icon: Icons.more_horiz, size: 18, onPressed: () {}, tooltip: 'メニュー'),
        ]),
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  _Sparkline(this.values, this.color);
  final List<int> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - size.height * values[i] / maxV;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(covariant _Sparkline old) => old.values != values || old.color != color;
}

/// トレンドプラグイン (D-167): `trend.suggest` のチップ。登録が無ければ何も出さない。
class _TrendSuggestions extends ConsumerWidget {
  const _TrendSuggestions({required this.recent});
  final List<String> recent;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(slotPluginsForProvider(SlotIds.trendSuggest));
    if (plugins.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: ref.read(slotPluginsProvider.notifier).trendSuggest(recent),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('検索の候補(${items.first.plugin.manifest.name})', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: RasqSpacing.xs),
            Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
              for (final it in items) ActionChip(label: Text('#${it.text}'), tooltip: it.reason, onPressed: () => context.pushTrend(it.text)),
            ]),
          ]),
        );
      },
    );
  }
}
