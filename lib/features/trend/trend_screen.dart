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

/// トレンドTL(検索結果): ∨ノート / フォロー中 / ユーザー tabs.
/// ノート = 「フォロー中の反応」(空欄, D-011) + 「トレンド」(tag timeline).
class TrendScreen extends ConsumerStatefulWidget {
  const TrendScreen({super.key, required this.tag});
  final String tag;
  @override
  ConsumerState<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends ConsumerState<TrendScreen> {
  final _scroll = ScrollController();
  TimelineKind get _kind => DynamicTimelines.tag(widget.tag);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) ref.read(timelineProvider(_kind).notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const [];
    final tl = ref.watch(timelineProvider(_kind));
    final notifier = ref.read(timelineProvider(_kind).notifier);
    final tabs = [const RasqTabItem('ノート'), const RasqTabItem('フォロー中'), const RasqTabItem('ユーザー')];
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqSearchHeader(
          me: me,
          onAvatarTap: () => RasqShell.openSidebar(context, ref),
          controller: TextEditingController(text: widget.tag),
          readOnly: true,
          onSearchTap: () => Navigator.of(context).maybePop(),
        ),
        body: Column(children: [
          RasqTabs(items: tabs),
          Expanded(
            child: TabBarView(children: [
              RefreshIndicator(
                onRefresh: notifier.refresh,
                child: ListView(controller: _scroll, physics: const AlwaysScrollableScrollPhysics(), children: [
                  const RasqSectionHeader(title: 'フォロー中の反応', topMargin: 0),
                  const SizedBox(height: 48), // 空欄 (D-011)
                  const RasqSectionHeader(title: 'トレンド', topMargin: 0),
                  ...tl.when(
                    loading: () => const [RasqLoading()],
                    error: (e, _) => [RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: notifier.refresh, retryLabel: '再読み込み')],
                    data: (s) => s.posts.isEmpty
                        ? const [RasqEmptyView(title: 'なんにもないようです', hint: 'ワードを変えると見つかるかもしれません')]
                        : [
                            for (final p in s.posts) ...[PostRow(post: p, actions: actions, onAction: (a) => notifier.perform(p, a), onTap: () => context.pushPost(p)), const Divider()],
                            if (s.loadingMore) const RasqLoading(),
                          ],
                  ),
                ]),
              ),
              const RasqEmptyView(title: 'フォロー中', hint: 'フォロイーの反応 (リレーショナルTL) は保留'),
              const RasqEmptyView(title: 'ユーザー', hint: 'ユーザー検索は M2'),
            ]),
          ),
        ]),
      ),
    );
  }
}
