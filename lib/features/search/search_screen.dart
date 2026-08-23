import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_shell.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../trend/trend_providers.dart';

/// 検索ホーム / トレンドホーム: 広告枠(AdSlot) → トレンド(ワード一覧) → Today.
/// Phase-1 sample sources trends from the SNS (`hashtags/trend`) and Today
/// from `notes/featured` until the trend provider / server exists.
class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider);
    final scheme = Theme.of(context).colorScheme;
    final trends = ref.watch(trendingTagsProvider);
    final today = ref.watch(timelineProvider(DynamicTimelines.featured));
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const [];
    final controller = TextEditingController();
    return Scaffold(
      appBar: RasqSearchHeader(me: me, onAvatarTap: () => RasqShell.openSidebar(context, ref), controller: controller, onSubmitted: (q) {
        final tag = q.trim().replaceFirst(RegExp(r'^#'), '');
        if (tag.isNotEmpty) context.pushTrend(tag);
      }),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(trendingTagsProvider);
          await ref.read(timelineProvider(DynamicTimelines.featured).notifier).refresh();
        },
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
          // AdSlot — renderer-owned insertion point (検索ホーム固定位置).
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), color: scheme.surfaceContainerHighest, child: Text('広告', style: TextStyle(fontSize: 28, color: scheme.onSurfaceVariant))),
          ),
          RasqSectionHeader(title: 'トレンド', trailing: RasqIconButton(icon: Icons.settings, size: 20, onPressed: () {}, tooltip: 'トレンド設定')),
          ...trends.when(
            loading: () => const [RasqLoading()],
            error: (e, _) => [RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), compact: true, onRetry: () => ref.invalidate(trendingTagsProvider), retryLabel: '再読み込み')],
            data: (list) => list.isEmpty
                ? const [RasqEmptyView(title: 'トレンドはありません', hint: 'サーバーサイドのトレンドプロバイダーは準備中')]
                : [for (final t in list.take(8)) _TrendTile(trend: t, onTap: () => context.pushTrend(t.tag))],
          ),
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
      ),
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
