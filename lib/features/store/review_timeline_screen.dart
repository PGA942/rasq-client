import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import 'store_models.dart';
import 'store_providers.dart';
import 'store_widgets.dart';

/// レビュー TL (D-137: ワイヤーフレーム「レビューを表示」)。
///
/// **スレッド展開画面と同じスタイル**(D-137 追補): ヘッダーは `<` + 自分の
/// RASQ アカウント + タイトル、タイルは L2 の投稿タイル([StoreReviewTile] =
/// RasqPostTile に ★ + 見出し / 本文 / ↪️ 👍 👎)。著者タップは将来 RASQ
/// アカウントページへ(今は準備中の案内)。
/// タブ = 「∨関連性 | 最新」(固定 2 タブ。選択中タブの ∨ から 関連性 /
/// 評価が高い / 評価が低い を選べる)。右下の + でレビュー作成。ストアページの
/// 「レビュー」フレームはこの TL の関連性上位 10 件。
class ReviewTimelineScreen extends ConsumerStatefulWidget {
  const ReviewTimelineScreen({super.key, required this.pluginId});
  final String pluginId;

  @override
  ConsumerState<ReviewTimelineScreen> createState() => _ReviewTimelineScreenState();
}

class _ReviewTimelineScreenState extends ConsumerState<ReviewTimelineScreen> {
  /// 左タブの並び(関連性 / 評価が高い / 評価が低い)。右タブは常に最新。
  ReviewSort _leftSort = ReviewSort.helpful;

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(overlayManagerProvider);
    final detail = ref.watch(storePluginProvider(widget.pluginId)).value;
    final reviews = ref.watch(storeReviewsProvider(widget.pluginId));
    final me = ref.watch(rasqAccountProvider);
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: RasqPageHeader(
          title: 'レビュー',
          leadingAvatar: me,
          onMore: () {},
          bottom: RasqTabs(
            items: [RasqTabItem(_leftSort.label), const RasqTabItem('最新')],
            mode: RasqTabsMode.fixed,
            onSelectedTabTap: (i, rect) async {
              if (i != 0) return;
              final pick = await manager.showDropdown<ReviewSort>(id: 'store.reviews.sort', anchor: rect, dense: true, items: [
                for (final s in [ReviewSort.helpful, ReviewSort.ratingHigh, ReviewSort.ratingLow]) RasqDropdownItem(s.label, s, checked: _leftSort == s),
              ]);
              if (pick != null && mounted) setState(() => _leftSort = pick);
            },
          ),
        ),
        body: reviews.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqEmptyView(title: 'レビューを取得できませんでした', hint: '$e'),
          data: (all) => TabBarView(children: [
            _ReviewList(pluginId: widget.pluginId, reviews: StoreReview.sorted(all, _leftSort)),
            _ReviewList(pluginId: widget.pluginId, reviews: StoreReview.sorted(all, ReviewSort.recent)),
          ]),
        ),
        floatingActionButton: detail == null
            ? null
            : FloatingActionButton(
                tooltip: 'レビューを書く',
                onPressed: () => openReviewComposer(context, ref, detail: detail),
                child: const Icon(Icons.add),
              ),
      ),
    );
  }
}

class _ReviewList extends ConsumerWidget {
  const _ReviewList({required this.pluginId, required this.reviews});
  final String pluginId;
  final List<StoreReview> reviews;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reviews.isEmpty) return const RasqEmptyView(title: 'まだレビューがありません', hint: '右下の + から最初のレビューを書けます');
    final manager = ref.read(overlayManagerProvider);
    return ListView.separated(
      itemCount: reviews.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final r = reviews[i];
        return StoreReviewTile(
          pluginId: pluginId,
          review: r,
          // 著者 → RASQ アカウントページ (D-270)。ハンドルの無いレビュー(匿名 / 同梱のサンプル)は行き先が無い。
          onAuthorTap: r.authorHandle.isEmpty ? null : () => context.push(Routes.rasqAccount(r.authorHandle)),
          onMore: (rect) async {
            final pick = await manager.showDropdown<String>(id: 'store.review.more', anchor: rect, items: const [
              RasqDropdownItem('リンクをコピー', 'copy'),
              RasqDropdownItem('レビューを報告', 'report', destructive: true),
            ]);
            if (!context.mounted) return;
            switch (pick) {
              case 'copy':
                await Clipboard.setData(ClipboardData(text: reviewShareLink(pluginId, r.id)));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('レビューのリンクをコピーしました')));
              case 'report':
                // 通報 API は store.yaml 未定義(レビュー信頼性「通報」は M4 後段)。
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('レビューの報告はまだ受け付けていません(ストア側の実装待ち)')));
              default:
                break;
            }
          },
        );
      },
    );
  }
}
