import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'store_models.dart';
import 'store_providers.dart';

/// ストアページ共用の部品 (D-137: ワイヤーフレーム「全体像」)。
///
/// - [StoreFrameStrip] / [StoreFrameCard]: 左右スライドできる**インライン
///   フレーム**(レビュー / アップデートとバージョン / プライバシーと必要な権限
///   の 3 節が同じ形)。次のフレームが右端に少し見える。
/// - [StoreReviewTile]: レビュー TL のタイル(↪️ / 👍 / 👎 のアクションバー)。
/// - [StoreReviewFrame]: 同じレビューをフレーム形に畳んだもの。
/// - [RatingHistogram] / [DownloadsSparkline]: 評価分布と DL 推移。

// ---------------------------------------------------------------------------
// インラインフレーム
// ---------------------------------------------------------------------------

/// 横スライドのフレーム列。[PageView] なので 1 枚ずつスナップし、右端に
/// 次のフレームが覗く(viewportFraction < 1)。
class StoreFrameStrip extends StatefulWidget {
  const StoreFrameStrip({super.key, required this.height, required this.children, this.viewportFraction = 0.86});
  final double height;
  final List<Widget> children;
  final double viewportFraction;

  @override
  State<StoreFrameStrip> createState() => _StoreFrameStripState();
}

class _StoreFrameStripState extends State<StoreFrameStrip> {
  late final PageController _controller = PageController(viewportFraction: widget.viewportFraction);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: PageView.builder(
          controller: _controller,
          padEnds: false,
          itemCount: widget.children.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(left: RasqSpacing.page, right: RasqSpacing.xs),
            child: widget.children[i],
          ),
        ),
      );
}

/// プラグインページの「プレビュー」(D-374): 横スライドで、**帯の高さを見ている画像の縦横比に合わせる**(切り抜かない)。
/// 画像の大きさが分かるまでは [initialHeight]。高さは [minHeight]〜[maxHeight] に収め、ページを変えると滑らかに変わる。
class StorePreviewStrip extends StatefulWidget {
  const StorePreviewStrip({
    super.key,
    required this.images,
    this.placeholder,
    this.initialHeight = 200,
    this.minHeight = 140,
    this.maxHeight = 480,
    this.viewportFraction = 0.86,
    this.imageProvider,
  });
  final List<Uri> images;
  final Widget? placeholder;
  final double initialHeight;
  final double minHeight;
  final double maxHeight;
  final double viewportFraction;

  /// 画像の読み込み(テストで差し替える)。既定は [NetworkImage]。
  final ImageProvider Function(Uri url)? imageProvider;

  /// 1 枚の幅 → その画像の縦横比での高さ(範囲に収める)。
  static double heightFor(double itemWidth, double? aspect, {double initial = 200, double min = 140, double max = 480}) =>
      aspect == null || aspect <= 0 ? initial : (itemWidth / aspect).clamp(min, max);

  @override
  State<StorePreviewStrip> createState() => _StorePreviewStripState();
}

class _StorePreviewStripState extends State<StorePreviewStrip> {
  late final PageController _controller = PageController(viewportFraction: widget.viewportFraction);
  final _aspects = <int, double>{};
  final _streams = <(ImageStream, ImageStreamListener)>[];
  int _page = 0;

  ImageProvider _provider(Uri u) => widget.imageProvider?.call(u) ?? NetworkImage(u.toString(), webHtmlElementStrategy: rasqWebImageStrategy);

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final p = (_controller.page ?? 0).round();
      if (p != _page) setState(() => _page = p);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_streams.isNotEmpty) return;
    // 画像の縦横比を先に知る(表示と同じ provider なので、読み込みは 1 回で済む)。
    for (final (i, u) in widget.images.indexed) {
      final stream = _provider(u).resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener((info, _) {
        try {
          final w = info.image.width;
          final h = info.image.height;
          if (mounted && h > 0) setState(() => _aspects[i] = w / h);
        } catch (_) {
          // Web の <img> で描いたときは大きさを取れないことがある → 既定の高さのまま。
        }
      }, onError: (_, _) {});
      stream.addListener(listener);
      _streams.add((stream, listener));
    }
  }

  @override
  void dispose() {
    for (final (s, l) in _streams) {
      s.removeListener(l);
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (widget.images.isEmpty) {
      return SizedBox(
        height: widget.initialHeight,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: widget.placeholder ?? const SizedBox.shrink()),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      // 1 枚の幅 = 見える幅 × viewportFraction − 左右の余白。
      final itemWidth = c.maxWidth * widget.viewportFraction - RasqSpacing.page - RasqSpacing.xs;
      final height = StorePreviewStrip.heightFor(itemWidth, _aspects[_page], initial: widget.initialHeight, min: widget.minHeight, max: widget.maxHeight);
      return AnimatedContainer(
        key: const ValueKey('store.preview.strip'),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        height: height,
        child: PageView.builder(
          controller: _controller,
          padEnds: false,
          itemCount: widget.images.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(left: RasqSpacing.page, right: RasqSpacing.xs),
            child: Container(
              key: ValueKey('store.preview.$i'),
              decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(RasqSizes.radiusMd), color: scheme.surfaceContainerHighest),
              clipBehavior: Clip.antiAlias,
              // 切り抜かない: 帯の高さは見ている画像に合わせてあり、ほかの画像は収まる大きさで出す。
              child: Image(
                image: _provider(widget.images[i]),
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined)),
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// 角丸枠のフレーム: ヘッダー行(見出し + 右端の …)/ 区切り / 本文 / 任意の
/// フッター。右側の `>` はタップで詳細へ(ワイヤーフレームの各フレーム)。
class StoreFrameCard extends StatelessWidget {
  const StoreFrameCard({
    super.key,
    required this.header,
    this.headerTrailing,
    required this.body,
    this.footer,
    this.onTap,
    this.onMore,
    this.showChevron = true,
  });

  final Widget header;
  final Widget? headerTrailing;
  final Widget body;
  final Widget? footer;
  final VoidCallback? onTap;

  /// … メニュー(ボタンの矩形付き。ドロップダウンのアンカー)。
  final ValueChanged<Rect>? onMore;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd), side: BorderSide(color: scheme.outline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            // 右端は … ボタンがあればその余白に任せ、無ければ左と同じ間隔を空ける
            // (相対時刻などの trailing が枠に張り付かないように)。
            padding: EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.xs, onMore == null ? RasqSpacing.md : RasqSpacing.xs, RasqSpacing.xs),
            child: Row(children: [
              Expanded(child: header),
              ?headerTrailing,
              if (onMore != null)
                Builder(
                  builder: (ctx) => RasqIconButton(
                    icon: Icons.more_horiz,
                    size: 18,
                    tooltip: 'メニュー',
                    onPressed: () {
                      final box = ctx.findRenderObject() as RenderBox;
                      onMore!(box.localToGlobal(Offset.zero) & box.size);
                    },
                  ),
                ),
            ]),
          ),
          Divider(height: 1, color: scheme.outline),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.xs),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: body),
                if (showChevron) Center(child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant)),
              ]),
            ),
          ),
          if (footer != null)
            Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.md, 0, RasqSpacing.md, RasqSpacing.xs), child: footer),
        ]),
      ),
    );
  }
}

/// 節の見出し「レビュー ›」: タップで一覧/詳細へ(ワイヤーフレームの
/// 「レビュー >」「アップデートとバージョン >」)。
class StoreFrameSectionHeader extends StatelessWidget {
  const StoreFrameSectionHeader({super.key, required this.title, this.onTap, this.trailing});
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.lg, RasqSpacing.page, RasqSpacing.sm),
        child: Row(children: [
          Text(title, style: RasqTypography.sectionHeader.copyWith(color: scheme.onSurface)),
          if (onTap != null) ...[const SizedBox(width: 2), Icon(Icons.chevron_right, size: 20, color: scheme.onSurface)],
          const Spacer(),
          ?trailing,
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// レビュー
// ---------------------------------------------------------------------------

/// ★ の並び(ワイヤーフレームは塗り星だけを評価数ぶん)。
String starsText(int rating) => '★' * rating.clamp(0, 5);

/// 「3人が役に立ったと考えました。」(自分の 👍 は足して見せる)。
String helpfulSummary(StoreReview r, ReviewVote mine) {
  final n = r.helpfulCount + (mine == ReviewVote.up ? 1 : 0);
  return n == 0 ? 'まだ評価がありません' : '$n人が役に立ったと考えました。';
}

/// レビュー共有用のリンク(アプリ内ディープリンク。Web 版は M4 後段)。
String reviewShareLink(String pluginId, String reviewId) => 'rasq://store/plugin/${Uri.encodeComponent(pluginId)}/reviews#${Uri.encodeComponent(reviewId)}';

/// 「N人が役に立ったと考えました。」だけを出す(ストアページのフレーム用。
/// アクションバーは置かず、投票はレビュー TL 側で行う)。
class ReviewHelpfulSummary extends ConsumerWidget {
  const ReviewHelpfulSummary({super.key, required this.pluginId, required this.review, this.textAlign = TextAlign.center});
  final String pluginId;
  final StoreReview review;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mine = ref.watch(reviewVotesProvider.select((m) => m['$pluginId/${review.id}'] ?? ReviewVote.none));
    return Text(helpfulSummary(review, mine), textAlign: textAlign, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis);
  }
}

/// レビュー TL のアクションバー (D-137): ↪️ 共有 / 👍 参考になった / 👎 参考に
/// ならなかった。状態は [reviewVotesProvider](端末側)から props で流す
/// (投稿タイルのアクションバーと同じ「状態は DSL の外」)。
class ReviewActionBar extends ConsumerWidget {
  const ReviewActionBar({super.key, required this.pluginId, required this.review, this.showSummary = true});
  final String pluginId;
  final StoreReview review;
  final bool showSummary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final mine = ref.watch(reviewVotesProvider.select((m) => m['$pluginId/${review.id}'] ?? ReviewVote.none));
    final votes = ref.read(reviewVotesProvider.notifier);
    void toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    return Row(children: [
      RasqActionBar(
        layout: RasqActionBarLayout.leading,
        items: [
          RasqActionBarItem(
            id: 'share',
            label: '共有',
            icon: Icons.shortcut,
            showCount: false,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: reviewShareLink(pluginId, review.id)));
              if (context.mounted) toast('レビューのリンクをコピーしました');
            },
          ),
          RasqActionBarItem(
            id: 'helpful',
            label: '参考になった',
            icon: Icons.thumb_up_outlined,
            doneIcon: Icons.thumb_up,
            done: mine == ReviewVote.up,
            showCount: false,
            onTap: () => votes.toggle(pluginId, review.id, ReviewVote.up),
          ),
          RasqActionBarItem(
            id: 'not_helpful',
            label: '参考にならなかった',
            icon: Icons.thumb_down_outlined,
            doneIcon: Icons.thumb_down,
            done: mine == ReviewVote.down,
            showCount: false,
            onTap: () => votes.toggle(pluginId, review.id, ReviewVote.down),
          ),
        ],
      ),
      if (showSummary)
        Expanded(
          child: Text(helpfulSummary(review, mine), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
        ),
    ]);
  }
}

/// レビューの投稿者を投稿タイルの著者として表す (D-137 追補)。RASQ アカウント
/// (`rasqAccountProvider` と同じ `kind: other / instance: rasq` の形)。
/// 将来はここからアカウントページへ飛ぶ。
UserSummary reviewAuthorOf(StoreReview r) {
  final handle = r.authorHandle.isNotEmpty ? r.authorHandle : (r.authorName.isNotEmpty ? r.authorName : 'anonymous');
  return UserSummary(
    id: 'rasq:$handle',
    account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: handle),
    displayName: r.authorName.isEmpty ? '匿名' : r.authorName,
    avatarUrl: r.authorAvatarUrl,
  );
}

/// レビュー TL の 1 タイル (D-137 追補): **スレッド展開画面と同じスタイル** —
/// L2 の [RasqPostTile](通常バリアント)に載せる。アバター / 表示名 +
/// `@handle ● rasq` / 相対時刻 / … のヘッダーは投稿タイルそのまま、本文
/// スロットに ★ + 見出し / 本文 / 実利用済み・版 / 開発者返信、アクション
/// スロットに ↪️ 👍 👎。著者タップは将来 RASQ アカウントページへ
/// ([onAuthorTap])。
class StoreReviewTile extends StatelessWidget {
  const StoreReviewTile({super.key, required this.pluginId, required this.review, this.onMore, this.onAuthorTap});
  final String pluginId;
  final StoreReview review;
  final ValueChanged<Rect>? onMore;
  final VoidCallback? onAuthorTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final r = review;
    final meta = [
      if (r.verifiedUse) '実利用済み',
      if (r.usedVersion.isNotEmpty) 'v${r.usedVersion}',
    ].join(' ・ ');
    return RasqPostTile(
      author: reviewAuthorOf(r),
      createdAt: r.createdAt,
      onAuthorTap: onAuthorTap,
      onMore: onMore,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(starsText(r.rating), style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700, color: RasqTokens.of(context).warning)),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: Text(r.headline, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700))),
        ]),
        if (r.body.isNotEmpty && r.title.isNotEmpty) ...[
          const SizedBox(height: RasqSpacing.xs),
          Text(r.body, style: RasqTypography.body),
        ],
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: RasqSpacing.xs),
            child: Text(meta, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ),
        if (r.developerReply != null)
          Container(
            margin: const EdgeInsets.only(top: RasqSpacing.sm),
            padding: const EdgeInsets.all(RasqSpacing.sm),
            decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
            child: Text('開発者の返信: ${r.developerReply}', style: RasqTypography.caption),
          ),
      ]),
      actionBar: ReviewActionBar(pluginId: pluginId, review: r),
    );
  }
}

/// ストアページのレビューフレーム: ★ + 見出し / 相対時刻 | 本文(3 行)|
/// 「N人が役に立ったと考えました。」(中央揃え、アクションバーなし — 投票は
/// レビュー TL で)。タップでレビュー TL へ。
class StoreReviewFrame extends StatelessWidget {
  const StoreReviewFrame({super.key, required this.pluginId, required this.review, this.onTap, this.onMore});
  final String pluginId;
  final StoreReview review;
  final VoidCallback? onTap;
  final ValueChanged<Rect>? onMore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StoreFrameCard(
      onTap: onTap,
      onMore: onMore,
      header: Row(children: [
        Text(starsText(review.rating), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: RasqSpacing.sm),
        Expanded(child: Text(review.headline, style: RasqTypography.listTile, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
      headerTrailing: RasqTimestamp(review.createdAt, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      body: Text(review.body.isEmpty ? '(本文なし)' : review.body, style: RasqTypography.caption.copyWith(height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
      footer: Padding(padding: const EdgeInsets.symmetric(vertical: RasqSpacing.xs), child: ReviewHelpfulSummary(pluginId: pluginId, review: review)),
    );
  }
}

/// レビュー作成シート(ワイヤーフレーム「レビューの作成」): ★ を選んで
/// 見出し + 本文。利用バージョンはインストール中の版を自動で付ける。
/// 送信後は一覧を再取得する。
Future<void> openReviewComposer(BuildContext context, WidgetRef ref, {required StorePluginDetail detail}) async {
  final manager = ref.read(overlayManagerProvider);
  final installed = ref.read(installedPluginsProvider).where((p) => p.id == detail.id).firstOrNull;
  final title = TextEditingController();
  final body = TextEditingController();
  var rating = 0;
  final ok = await manager.showBottomSheet<bool>(
    id: 'store.review.create',
    title: 'レビューの作成',
    confirmText: '送信',
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Text('評価', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(width: RasqSpacing.sm),
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(i <= rating ? Icons.star : Icons.star_border, color: i <= rating ? RasqTokens.of(ctx).warning : scheme.onSurfaceVariant),
                  onPressed: () => setSheet(() => rating = i),
                ),
            ]),
            RasqInput(controller: title, hintText: '見出し(任意)'),
            const SizedBox(height: RasqSpacing.sm),
            RasqInput(controller: body, hintText: '使用感や気になった点を入力してください', maxLines: 5, autofocus: true),
            if (installed != null)
              Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.xs),
                child: Text('利用バージョン: v${installed.version}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ),
          ]),
        );
      },
    ),
  );
  if (ok != true || !context.mounted) return;
  if (rating == 0) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('★ を選んでください')));
    return;
  }
  try {
    await ref.read(storeClientProvider).createReview(detail.id, rating: rating, title: title.text.trim(), body: body.text.trim(), usedVersion: installed?.version);
    ref.invalidate(storeReviewsProvider(detail.id));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('レビューを送信しました')));
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('レビューを送信できませんでした: $e')));
  }
}

// ---------------------------------------------------------------------------
// 評価分布 / DL 推移
// ---------------------------------------------------------------------------

/// 評価の分布(★5 → ★1 の横棒)。[histogram] は `[★1 … ★5]` の件数。
class RatingHistogram extends StatelessWidget {
  const RatingHistogram({super.key, required this.histogram});
  final List<int> histogram;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = List<int>.generate(5, (i) => i < histogram.length ? histogram[i] : 0);
    final max = h.fold<int>(0, (m, v) => v > m ? v : m);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var star = 5; star >= 1; star--)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(children: [
            SizedBox(width: 62, child: Text(starsText(star), textAlign: TextAlign.right, style: RasqTypography.caption.copyWith(fontSize: 10, height: 1.2, fontWeight: FontWeight.w700))),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: max == 0 ? 0 : (h[star - 1] / max).clamp(0.0, 1.0),
                  child: Container(height: 6, decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(3))),
                ),
              ),
            ),
          ]),
        ),
    ]);
  }
}

/// 累積ダウンロードの折れ線(点 + 横罫線)。値が 2 点未満なら描かない。
class DownloadsSparkline extends StatelessWidget {
  const DownloadsSparkline({super.key, required this.values});
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (values.length < 2) return const SizedBox.shrink();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('$max', style: RasqTypography.caption.copyWith(fontSize: 9, color: scheme.onSurfaceVariant)),
        Text('$min', style: RasqTypography.caption.copyWith(fontSize: 9, color: scheme.onSurfaceVariant)),
      ]),
      const SizedBox(width: RasqSpacing.xs),
      Expanded(child: CustomPaint(painter: _SparklinePainter(values, line: RasqTokens.of(context).link, grid: scheme.outlineVariant))),
    ]);
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.values, {required this.line, required this.grid});
  final List<int> values;
  final Color line;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b).toDouble();
    final max = values.reduce((a, b) => a > b ? a : b).toDouble();
    final span = (max - min) == 0 ? 1.0 : (max - min);
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - min) / span * size.height;
      points.add(Offset(x, y));
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
    final dot = Paint()..color = line;
    for (final p in points) {
      canvas.drawCircle(p, 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values || old.line != line || old.grid != grid;
}

/// 「プライバシーと必要な権限」の全文(権限の種別ごと → 外部通信とデータ → 実行環境)。ストアのページの下付きシートと、
/// インストール済みのページ (D-256) で使う。
class SafetyDetail extends StatelessWidget {
  const SafetyDetail({super.key, required this.safety});
  final SafetyBlock safety;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (safety.permissions.isEmpty) Padding(padding: const EdgeInsets.only(top: RasqSpacing.md), child: Text('必要な権限: なし', style: RasqTypography.bodySmall)),
      for (final g in PermissionKind.group(safety.permissions)) ...[
        Padding(
          padding: const EdgeInsets.only(top: RasqSpacing.md, bottom: RasqSpacing.xs),
          child: Text('${g.kind.label}${g.kind.description.isEmpty ? '' : ' — ${g.kind.description}'}', style: RasqTypography.listTile),
        ),
        for (final p in g.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.key_outlined, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(p.reason.isEmpty ? p.permission : '${p.permission} — ${p.reason}', style: RasqTypography.bodySmall)),
            ]),
          ),
      ],
      Padding(padding: const EdgeInsets.only(top: RasqSpacing.md, bottom: RasqSpacing.xs), child: Text('外部通信とデータ', style: RasqTypography.listTile)),
      Text(safety.externalHosts.isEmpty ? '外部通信先: なし' : '外部通信先: ${safety.externalHosts.join('、')}', style: RasqTypography.bodySmall),
      if (safety.dataHandling.isNotEmpty) Text('データの扱い: ${safety.dataHandling}', style: RasqTypography.bodySmall),
      if (safety.externalSdks.isNotEmpty) Text('外部 SDK: ${safety.externalSdks.join('、')}', style: RasqTypography.bodySmall),
      Padding(padding: const EdgeInsets.only(top: RasqSpacing.md, bottom: RasqSpacing.xs), child: Text('実行環境', style: RasqTypography.listTile)),
      Text(
        [
          if (safety.crashFreeRate != null) '正常起動率 ${(safety.crashFreeRate! * 100).toStringAsFixed(1)}%',
          safety.backgroundExecution ? 'バックグラウンド実行あり' : 'バックグラウンド実行なし',
          safety.usesGpu ? 'GPU 使用' : 'GPU 不使用',
          safety.adPlacements.isEmpty ? '広告なし' : '広告あり(${safety.adPlacements.join('、')})',
        ].join(' ・ '),
        style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant),
      ),
    ]);
  }
}
