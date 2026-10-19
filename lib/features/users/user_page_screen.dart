import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../app/navigation.dart';
import '../../app/router.dart';
import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../settings/settings_dsl.dart' show settingsAreaProvider;
import '../../shell/headers.dart';
import '../../text/inline_spans.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../clips/clip_providers.dart';
import '../collections/rasq_collections.dart';
import '../servers/server_info_tile.dart';
import '../profile/rasq_links_on_sns_profile.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../trend/tendency_profile.dart';
import 'user_list.dart';
import 'user_providers.dart';
import 'user_tab_view.dart';
import '../ads/timeline_ads.dart';

/// ユーザーページ(通常 / 自分 / 制限 / ノーヒット). タブ: ノート / 返信 / 引用 / メディア / クリップ.
/// 選んでいるタブをもう一度押すと、いちばん上へ / 並べ替え・絞り込みのパネル (D-514、[showUserTabViewPanel])。
class UserPageScreen extends ConsumerStatefulWidget {
  const UserPageScreen({super.key, required this.userId, this.initial, this.account});
  final String userId;
  final UserSummary? initial;

  /// この人を引いたアカウント(`AccountId.key`、D-469)。ページはこのアカウントのセッションで引く。
  /// null = [initial] の人自身のアカウント(D-155。自分のページならそのアカウント、ほかの人なら現在のアカウントへ縮退)。
  final String? account;

  /// ページを引くアカウント (D-469)。投稿の作者(`initial`)の `AccountId` は**その人の**サーバーとハンドルで、
  /// ログイン中のアカウントではない(自分のときだけ一致する)ので、それで選ぶと、総合表示で現在のアカウントが別のサーバー /
  /// 別の SNS のとき、ほかの人の id を別のサーバーで引いて「このユーザーは存在しないようです」になっていた。
  String? get accountKey => account ?? initial?.account.key;
  @override
  ConsumerState<UserPageScreen> createState() => _UserPageScreenState();
}

class _UserPageScreenState extends ConsumerState<UserPageScreen> {
  bool _showRestricted = false;

  /// 投稿のタブ(並び = タブの順。クリップ/Play はこの後ろ)。
  static const _postTabs = [UserPostsFilter.posts, UserPostsFilter.replies, UserPostsFilter.quotes, UserPostsFilter.media];

  /// タブの一覧の位置(選んでいるタブをもう一度押したとき、いちばん上か、D-514)。
  final _nested = GlobalKey<NestedScrollViewState>();

  /// 並べ替え・絞り込みのパネルの指向性 / 刺激性の欄に指が触れている (D-514)。その間はタブの横のスワイプと戻るジェスチャーを止める。
  final _chartHeld = ValueNotifier(false);

  /// タブごとの検索の語 (D-514)。保存しない(このページを開いている間だけ)。
  final _queries = {for (final f in _postTabs) f: ValueNotifier('')};

  @override
  void dispose() {
    _chartHeld.dispose();
    for (final q in _queries.values) {
      q.dispose();
    }
    super.dispose();
  }

  /// 選んでいるタブをもう一度押した (D-514)。一覧が下へ進んでいれば、まずいちばん上へ(下のナビの D-505 と同じ「押し直すと上へ」)。
  /// いちばん上なら、そのタブにつながった並べ替え・絞り込みのパネルを開く(開いていれば閉じる)。ヘッダーが出ていれば先に畳む。
  Future<void> _onSelectedTabTap(int i, Rect anchor, UserProfile p, String label) async {
    if (i >= _postTabs.length) return;
    final inner = _nested.currentState?.innerController;
    if (inner != null && inner.hasClients && inner.positions.any((x) => x.pixels > 0.5)) {
      await inner.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      return;
    }
    // ヘッダーが出ていれば畳んで、タブを上に留めてから開く(パネルの入る高さを取る)。タブの矩形はその分だけ上へ。
    final outer = _nested.currentState?.outerController;
    if (outer != null && outer.hasClients) {
      final rest = outer.position.maxScrollExtent - outer.position.pixels;
      if (rest > 0.5) {
        await outer.animateTo(outer.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOutCubic);
        if (!mounted) return;
        anchor = anchor.shift(Offset(0, -rest));
      }
    }
    final f = _postTabs[i];
    if (!mounted) return;
    await showUserTabViewPanel(
      context,
      ref,
      anchor: anchor,
      tab: f,
      tabLabel: label,
      query: _queries[f]!,
      chartHeld: _chartHeld,
      postsKey: (id: p.summary.id, filter: f, account: widget.accountKey),
      hasPinned: f == UserPostsFilter.posts && p.pinnedPosts.isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final acct = widget.accountKey; // 引いたアカウントで展開 (D-155 / D-469)
    final profile = ref.watch(userProfileProvider((id: widget.userId, account: acct)));
    final me = ref.watch(currentUserProvider);
    // 見ているアカウント = このページを引いたセッションのアカウント (D-421。総合表示でも、そのアカウントの自分のページは「自分」)。
    final viewer = ref.watch(viewerForAccountProvider(acct));
    final manager = ref.watch(overlayManagerProvider);
    final title = profile.value?.summary.displayName ?? widget.initial?.displayName ?? (profile.hasError ? '@${widget.initial?.handle ?? ''}' : '');

    return Scaffold(
      appBar: RasqPageHeader(
        title: title,
        onMore: () => _userMenu(context, manager, profile.value?.summary ?? widget.initial, profile.value),
      ),
      body: profile.when(
        loading: () => const RasqLoading(),
        error: (e, _) {
          final code = e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e');
          if (code.code == '404' || code.code == '400') return const _NoHit();
          return RasqErrorView(code: code, onRetry: () => ref.invalidate(userProfileProvider((id: widget.userId, account: acct))), retryLabel: '再読み込み');
        },
        data: (p) {
          final isSelf = isViewerSelf(p.summary, viewer, me: me, viewerId: ref.watch(viewerUserIdProvider(acct)));
          final keyUser = viewer == null ? p.summary.key : followUserKey(viewer, p.summary.id);
          final st = viewer == null ? const FollowState() : ref.watch(followStateOfProvider((viewer: viewer.key, user: keyUser)));
          final restricted = (p.isSuspended || st.blocked || st.blockedBy) && !_showRestricted;
          // 返信TL / 引用TL (D-069): 返信と引用はそれぞれのタブに振り分ける
          // (ノートには両方とも流さない。純リノートはノートに残る)。
          final labels = ['ノート', '返信', '引用', 'メディア', 'クリップ/Play'];
          final views = ref.watch(settingsAreaProvider(userPageTabsKvArea)).value ?? const <String, Object?>{};
          // 選んでいるタブの ∨ = 並べ替え・絞り込み (D-514)。クリップ/Play には無い。変えているタブは名前の右肩に点。
          return ListenableBuilder(
            listenable: Listenable.merge([_chartHeld, ..._queries.values]),
            builder: (context, _) {
              final tabs = [
                for (final (i, f) in _postTabs.indexed) RasqTabItem(labels[i], dot: !restricted && (!UserTabView.fromJson(views[f.name]).isDefault || _queries[f]!.value.trim().isNotEmpty)),
                RasqTabItem(labels[4], chevron: false),
              ];
              final held = _chartHeld.value;
              return PopScope(
                // 指をチャートに置いている間は、端からの戻るジェスチャーで閉じない (D-514)。
                canPop: !held,
                child: RasqCollapsibleTabScaffold(
            nestedScrollKey: _nested,
            tabViewPhysics: held ? const NeverScrollableScrollPhysics() : null,
            header: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RasqUserTileLarge(
                profile: p,
                isSelf: isSelf,
                following: isSelf ? null : st.following,
                followedBy: st.followedBy,
                requested: st.requested,
                restricted: restricted,
                onShowRestricted: () => setState(() => _showRestricted = true),
                // アイコン / バナーのタップで全画面表示 (D-177)。
                onAvatarTap: p.summary.avatarUrl == null ? null : () => context.openImage(p.summary.avatarUrl!, title: p.summary.displayName),
                onBannerTap: p.bannerUrl == null ? null : () => context.openImage(p.bannerUrl!, title: p.summary.displayName),
                bio: p.description == null ? null : RasqRichText(InlineSpans.parse(p.description!, emojis: ref.watch(emojiCacheProvider), onLink: (u) => launchUrl(u, mode: LaunchMode.externalApplication), onHashtag: (t) => context.pushTrend(t)), style: RasqTypography.body),
                onFollowTap: () => ref.read(userListHelperProvider).toggleFollow(p.summary, account: acct),
                onEditTap: () => context.push(Routes.profileEdit),
                onNotifyTap: () {},
                onFollowingTap: () => context.pushFollows(p.summary, followers: false, account: acct),
                onFollowersTap: () => context.pushFollows(p.summary, followers: true, account: acct),
                onLinkTap: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
              ),
              // この人の RASQ アカウントと、ほかにつないでいるアカウント (D-312)。制限中 / 凍結中は出さない。
              if (!restricted && !p.isSuspended) RasqLinksOnSnsProfile(profile: p),
            ]),
            tabs: RasqTabs(items: tabs, onSelectedTabTap: restricted ? null : (i, anchor) => _onSelectedTabTap(i, anchor, p, labels[i])),
            tabViews: restricted
                ? [for (final _ in tabs) const RasqEmptyView(title: '制限されたユーザーです', hint: '「表示」を押すと内容を表示します')]
                : [
                    _UserPosts(userId: p.summary.id, account: acct, filter: UserPostsFilter.posts, pinned: p.pinnedPosts, query: _queries[UserPostsFilter.posts]!),
                    _UserPosts(userId: p.summary.id, account: acct, filter: UserPostsFilter.replies, query: _queries[UserPostsFilter.replies]!),
                    _UserPosts(userId: p.summary.id, account: acct, filter: UserPostsFilter.quotes, query: _queries[UserPostsFilter.quotes]!),
                    _UserPosts(userId: p.summary.id, account: acct, filter: UserPostsFilter.media, query: _queries[UserPostsFilter.media]!),
                    _UserClips(userId: p.summary.id),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _userMenu(BuildContext context, OverlayManager manager, UserSummary? u, UserProfile? p) async {
    if (u == null) return;
    final box = context.findRenderObject() as RenderBox?;
    final anchor = box == null ? const Rect.fromLTWH(0, 80, 1, 1) : Rect.fromLTWH(box.size.width - 48, 56, 40, 40);
    final acct = widget.accountKey;
    // このページを開いているアカウント (D-155 / D-421)。RASQ リストの項目の id も、ミュート / ブロック / 報告も、このサーバーのもの。
    final viewer = ref.read(viewerForAccountProvider(acct));
    final st = viewer == null ? const FollowState() : ref.read(followStateProvider.notifier).of(viewer.key, followUserKey(viewer, u.id));
    final via = viewer;
    final pick = await manager.showDropdown<String>(id: 'user.menu', anchor: anchor, items: [
      const RasqDropdownItem('リンクをコピー', 'copy'),
      if (via != null && ref.read(hasRasqAccountProvider)) const RasqDropdownItem('RASQ リストに追加', 'rasqList'),
      if (u.account.kind != SnsKind.bluesky) const RasqDropdownItem('サーバー情報', 'server'),
      RasqDropdownItem(st.muted ? 'ミュート解除' : 'ミュート', 'mute', accent: true),
      RasqDropdownItem(st.blocked ? 'ブロック解除' : 'ブロック', 'block', destructive: true),
      const RasqDropdownItem('報告', 'report', destructive: true),
    ]);
    // SNS の操作ではないもの (D-343 / D-345)。
    if (pick == 'rasqList' && via != null) return showAddToRasqListSheet(ref, u, via: via);
    if (pick == 'server') return showServerInfoFow(ref, u.account.instance);
    final s = ref.read(sessionForAccountProvider(acct));
    if (pick == null || s == null || viewer == null) return;
    final store = ref.read(followStateProvider.notifier);
    final key = followUserKey(viewer, u.id);
    switch (pick) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: (p?.profileUrl ?? Uri.https(u.account.instance, '/@${u.handle}')).toString()));
      case 'mute':
        store.apply(viewer.key, key, await s.setMuted(u.id, !st.muted));
      case 'block':
        final ok = st.blocked || await manager.showAlert(id: 'user.block', title: '${u.displayName} をブロックしますか？', message: '相手からのフォロー・リアクション・返信が届かなくなります。', confirmText: 'ブロック', cancelText: 'キャンセル', destructive: true);
        if (ok) store.apply(viewer.key, key, await s.setBlocked(u.id, !st.blocked));
      case 'report':
        final ok = await manager.showAlert(id: 'user.report', title: '${u.displayName} を報告しますか？', message: 'サーバー管理者に報告します(コメントは次バッチで入力可能)。', confirmText: '報告', cancelText: 'キャンセル', destructive: true);
        if (ok) await s.reportUser(u.id, 'Reported from RASQ');
    }
  }
}

class _UserPosts extends ConsumerWidget {
  const _UserPosts({required this.userId, required this.filter, required this.query, this.pinned = const [], this.account});
  final String userId;
  final UserPostsFilter filter;
  final List<Post> pinned;
  final String? account;

  /// このタブの検索の語 (D-514)。
  final ValueListenable<String> query;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(userPostsProvider((id: userId, filter: filter, account: account)));
    // チャイルドセーフ (D-454、セキュリティ確認 2026-10-09 の [9]): ピン留め(プロフィールに付いてくる投稿)にも、投稿一覧
    // (userPostsProvider)と同じ保護者の表示制限を掛けてから混ぜる。
    final pinned = ref.watch(childGateProvider).filterPosts(this.pinned);
    final actions = ref.watch(sessionForAccountProvider(account))?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    final scheme = Theme.of(context).colorScheme;
    final view = watchUserTabView(ref, filter);
    // 指向性 / 傾向に合う順は、トレンドの設定の好きなジャンル / 例を使う(使うときだけ読む)。
    final base = view.limitsDirection || view.limitsStimulus || view.sort == UserTabSort.tendency ? ref.watch(tendencyProfileProvider).value : null;
    return page.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(userPostsProvider((id: userId, filter: filter, account: account))), retryLabel: '再読み込み'),
      data: (p) => ValueListenableBuilder<String>(valueListenable: query, builder: (context, q, _) {
        // 並べ替え・絞り込み (D-514): ピン留めは絞るだけで上に(並べ替えない)、残りに並べ替えも掛ける。
        final rest = p.items.where((x) => !pinned.any((pin) => pin.id == x.id)).toList();
        if (pinned.isEmpty && rest.isEmpty) return const RasqEmptyView(title: '投稿はありません');
        final shownPinned = view.pinned ? applyUserTabView(pinned, view, query: q, base: base, sorted: false) : const <Post>[];
        final items = [...shownPinned, ...applyUserTabView(rest, view, query: q, base: base)];
        if (items.isEmpty) return RasqEmptyView(key: const ValueKey('user.tabView.empty'), title: context.l10n.userPageViewEmptyTitle, hint: context.l10n.userPageViewEmptyHint);
        final pinnedCount = shownPinned.length;
        // 投稿の間の広告 (D-438)。ピン留めの間には置かない。
        final ads = {for (final g in timelineAdGaps(ref, items)) if (g > pinnedCount) g};
        final adOrdinal = {for (final (n, g) in (ads.toList()..sort()).indexed) g: n};
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: items.length,
          separatorBuilder: (_, _) => const Divider(),
          itemBuilder: (_, i) {
            final post = items[i];
            final isPinned = i < pinnedCount;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (ads.contains(i)) ...[TimelineAdSlot(key: ValueKey('user.ad.$i'), ordinal: adOrdinal[i]!), const Divider()],
              if (isPinned) Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page + RasqSizes.avatarLg + RasqSpacing.md, 6, 0, 0), child: Row(children: [Icon(Icons.push_pin, size: 14, color: scheme.onSurfaceVariant), const SizedBox(width: 4), Text('ピン留め', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))])),
              // ダイジェスト (D-514) = 小表示(D-156 のインラインフレーム)。
              if (view.digest)
                Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs), child: InlinePostFrame(key: ValueKey('user.digest.${post.id}'), post: post, onTap: () => context.pushPost(post)))
              else
                PostRow(post: post, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(post, a, args: args), onTap: () => context.pushPost(post)),
            ]);
          },
        );
      }),
    );
  }
}

/// クリップ/Play タブ (D-032/D-039): 対象ユーザーの公開クリップ一覧
/// (タップでクリップTL)+ **Play の外部リンク**(RASQ 内では実行しない)。
/// SNS がどちらも非対応なら従来どおりのプレースホルダー。
class _UserClips extends ConsumerWidget {
  const _UserClips({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clips = ref.watch(userClipsProvider(userId));
    final plays = ref.watch(userPlaysProvider(userId)).value;
    final scheme = Theme.of(context).colorScheme;
    return clips.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(userClipsProvider(userId)), retryLabel: '再読み込み'),
      data: (list) {
        if (list == null && plays == null) return const RasqEmptyView(title: 'クリップ / Play', hint: 'この SNS はクリップ・Play に対応していません(プラグインタイルは M4)');
        if ((list ?? const []).isEmpty && (plays ?? const []).isEmpty) return const RasqEmptyView(title: '公開クリップ・Play はありません');
        return ListView(children: [
          if ((list ?? const []).isNotEmpty) ...[
            const RasqSectionHeader(title: 'クリップ', topMargin: 0),
            for (final c in list!) ...[
              RasqListTile(
                title: c.name,
                subtitle: [if (c.notesCount != null) '${c.notesCount}件', if (c.description?.isNotEmpty == true) c.description!].join(' ・ '),
                leading: Icon(Icons.collections_bookmark_outlined, color: scheme.onSurfaceVariant),
                onTap: () => context.pushClip(c),
              ),
              const Divider(height: 1),
            ],
          ],
          if ((plays ?? const []).isNotEmpty) ...[
            const RasqSectionHeader(title: 'Play'),
            for (final p in plays!) ...[
              RasqListTile(
                title: p.title,
                subtitle: p.summary,
                leading: Icon(Icons.play_circle_outline, color: scheme.onSurfaceVariant),
                trailing: const Icon(Icons.north_east, size: 18),
                onTap: () => launchUrl(p.url, mode: LaunchMode.externalApplication),
              ),
              const Divider(height: 1),
            ],
          ],
        ]);
      },
    );
  }
}

/// ユーザーページ(ノーヒット): グレーの空タイル + 「このユーザーは存在しないようです。」
class _NoHit extends StatelessWidget {
  const _NoHit();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      Container(height: 120, color: scheme.surfaceContainerLow),
      Padding(
        padding: const EdgeInsets.all(RasqSpacing.page),
        child: Row(children: [
          Container(width: 56, height: 56, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, shape: BoxShape.circle)),
          const Spacer(),
          Container(width: 96, height: 32, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16))),
        ]),
      ),
      const SizedBox(height: 24),
      const Text('このユーザーは存在しないようです。', style: RasqTypography.bodySmall),
    ]);
  }
}
