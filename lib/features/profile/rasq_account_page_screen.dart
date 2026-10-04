import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../backend/rasq_collections_api.dart';
import '../../shell/headers.dart';
import '../../shell/third_column.dart' show fowColumnOf;
import '../../session/session_providers.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../home/post_row.dart';
import '../post/post_menu.dart' show PostMenuPin;
import '../home/timeline_providers.dart';
import '../collections/rasq_collection_tile.dart';
import '../collections/rasq_collections.dart';
import '../custom/custom_profile.dart';
import 'rasq_post_tile.dart';

/// RASQ アカウントページ (D-270 / S-021)。
///
/// 上から: バナー / アイコン / 表示名・ハンドル / 自己紹介 / 場所・誕生日・登録した年月・リンク →
/// **SNS アカウントのタイル**(横に流れる。アカウント名 → サーバーのアイコン → サーバー名。タップで、ログイン中の SNS なら
/// アプリ内のユーザーページ、そうでなければブラウザ)→ タブ **投稿 / メディア / リスト / クリップ(どちらも第二期)/ プラグイン / レビュー** (D-277)。
/// 自分のページでは「編集」と、RASQ アカウントとしての投稿(第一期は 3 件まで)の作成 / 削除ができる。
class RasqAccountPageScreen extends ConsumerStatefulWidget {
  const RasqAccountPageScreen({super.key, required this.handle});
  final String handle;
  @override
  ConsumerState<RasqAccountPageScreen> createState() => _RasqAccountPageScreenState();
}

class _RasqAccountPageScreenState extends ConsumerState<RasqAccountPageScreen> {

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _openTile(RasqSnsTile t) => openRasqSnsTile(context, ref, t);

  /// 「RASQ に投稿」= いつものコンポーザーを RASQ 指定で開く (D-275。SNS の投稿と同じ作り方: 注釈 / 公開範囲 / 投票 / 画像)。
  Future<void> _compose(RasqPostList posts) async {
    if (posts.posts.where((p) => p.rebroadedBy == null).length >= posts.limit) return _toast('投稿は ${posts.limit} 件までです。古い投稿を消してから投稿してください');
    await showComposer(ref, const ComposeNormal(), rasqTarget: true, column: fowColumnOf(context));
    if (mounted) ref.invalidate(rasqAccountPageProvider(widget.handle));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final page = ref.watch(rasqAccountPageProvider(widget.handle));
    final me = ref.watch(orgateAccountProvider).value;
    final isMine = me != null && me.handle.toLowerCase() == widget.handle.toLowerCase();
    return Scaffold(
      appBar: RasqPageHeader(
        title: '@${widget.handle}',
        actions: [if (isMine) TextButton(key: const ValueKey('rasqPage.edit'), onPressed: () async {
          await context.push('${Routes.settings}/rasq-profile');
          ref.invalidate(rasqAccountPageProvider(widget.handle));
        }, child: const Text('編集'))],
      ),
      floatingActionButton: isMine && page.hasValue
          ? FloatingActionButton.extended(key: const ValueKey('rasqPage.compose'), heroTag: 'fab.rasqPage', onPressed: () => _compose(page.value!.posts), icon: const Icon(Icons.edit_outlined), label: const Text('RASQ に投稿'))
          : null,
      body: page.when(
        loading: () => const RasqLoading(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Text(e is OrgateException && e.code.code == '404' ? '@${widget.handle} という RASQ アカウントはありません' : '読み込めませんでした: ${e is OrgateException ? e.message : e}', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        ),
        data: (d) => DefaultTabController(
          length: 7,
          child: NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(child: _Header(profile: d.profile, onTile: _openTile)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: const [Tab(text: '投稿'), Tab(text: 'メディア'), Tab(text: 'ページ'), Tab(text: 'リスト'), Tab(text: 'クリップ'), Tab(text: 'プラグイン'), Tab(text: 'レビュー')]),
                  scheme.surface,
                ),
              ),
            ],
            body: TabBarView(children: [
              _PostsTab(
                posts: d.posts,
                isMine: isMine,
                snsLinked: d.profile.snsAccounts.isNotEmpty,
                onChanged: () => ref.invalidate(rasqAccountPageProvider(widget.handle)),
                onOpenSnsPostsSettings: () async {
                  await context.push('${Routes.settings}/rasq-profile');
                  ref.invalidate(rasqAccountPageProvider(widget.handle));
                },
              ),
              _MediaTab(posts: d.posts),
              // カスタムプラグイン (D-357): 置いたページ。
              CustomProfilePagesTab(handle: widget.handle, accountId: d.profile.id, isMine: isMine),
              _CollectionsTab(handle: widget.handle, kind: RasqCollectionKind.list, isMine: isMine),
              _CollectionsTab(handle: widget.handle, kind: RasqCollectionKind.clip, isMine: isMine),
              _PluginsTab(profile: d.profile, reviews: false),
              _PluginsTab(profile: d.profile, reviews: true),
            ]),
          ),
        ),
      ),
    );
  }
}

/// SNS アカウントのタイルのタップ: その SNS にログイン中ならアプリ内のユーザーページ、そうでなければブラウザ。
/// アカウントページと、SNS のプロフィールの「RASQ アカウント」欄 (D-312) で使う。
Future<void> openRasqSnsTile(BuildContext context, WidgetRef ref, RasqSnsTile t) async {
  void toast(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  final sessions = ref.read(sessionsProvider).value?.allSessions ?? const [];
  // Bluesky はサーバー(PDS)に関係なく、どの Bluesky のアカウントからでも引ける (D-423)。
  final mine = sessionServing(sessions, t.kind, t.instance, preferKey: t.key);
  if (mine != null) {
    try {
      final session = ref.read(pluginRegistryProvider).session(mine);
      final user = await session.userByHandle(t.handle, host: t.instance);
      if (user != null && context.mounted) return context.pushUser(user.summary);
    } catch (_) {
      // 取れなければブラウザへ。
    }
  }
  final url = t.profileUrl;
  if (url == null) return toast('このアカウントの行き先が分かりません');
  if (!await launchUrl(url, mode: LaunchMode.externalApplication)) toast('開けませんでした: $url');
}

/// 公開した RASQ リスト / RASQ クリップ (D-343/D-344、S-042)。タイルを縦に並べて、「見てみる」でそのページへ。
class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab({required this.handle, required this.kind, required this.isMine});
  final String handle;
  final RasqCollectionKind kind;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(accountRasqCollectionsProvider((handle: handle, kind: kind)));
    final isList = kind == RasqCollectionKind.list;
    return list.when(
      loading: () => const RasqLoading(),
      error: (_, _) => _message(context, '読み込めませんでした。'),
      data: (items) {
        if (items.isEmpty) {
          return _message(
            context,
            isMine
                ? (isList ? '公開した RASQ リストがここに出ます(リストの画面から作れます)。' : '公開した RASQ クリップがここに出ます(クリップのページの「公開する」)。')
                : (isList ? '公開しているリストはありません。' : '公開しているクリップはありません。'),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(RasqSpacing.page),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: RasqSpacing.sm),
          itemBuilder: (_, i) => RasqCollectionTile(collection: items[i], onOpen: () => context.push(Routes.rasqCollection(items[i].code ?? items[i].id))),
        );
      },
    );
  }
}

Widget _message(BuildContext context, String text) => ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [Text(text, style: RasqTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))]);

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.bar, this.color);
  final TabBar bar;
  final Color color;
  @override
  double get minExtent => bar.preferredSize.height;
  @override
  double get maxExtent => bar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => ColoredBox(color: color, child: bar);
  @override
  bool shouldRebuild(_TabBarDelegate old) => old.color != color;
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.onTile});
  final RasqPublicProfile profile;
  final ValueChanged<RasqSnsTile> onTile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = profile;
    final muted = RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(clipBehavior: Clip.none, children: [
        SizedBox(
          height: 120,
          width: double.infinity,
          child: p.bannerUrl == null ? ColoredBox(color: scheme.surfaceContainerHighest) : Image.network(webHtmlElementStrategy: rasqWebImageStrategy, p.bannerUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
        ),
        Positioned(
          left: RasqSpacing.page,
          bottom: -32,
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 3)),
            child: RasqAvatar(imageUrl: p.avatarUrl, size: 72, fallbackLabel: p.displayName.isEmpty ? p.handle : p.displayName),
          ),
        ),
      ]),
      const SizedBox(height: 40),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.displayName.isEmpty ? p.handle : p.displayName, key: const ValueKey('rasqPage.name'), style: RasqTypography.title),
          Row(children: [Text('@${p.handle}', style: muted), const SizedBox(width: 6), const RasqBrandIcon(size: 14)]),
          if (p.bio.isNotEmpty) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(p.bio, key: const ValueKey('rasqPage.bio'))),
          const SizedBox(height: RasqSpacing.sm),
          Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (p.location.isNotEmpty) _Meta(Icons.place_outlined, p.location),
            if (p.birthday.isNotEmpty) _Meta(Icons.cake_outlined, p.birthday),
            if (p.createdAt != null) _Meta(Icons.calendar_today_outlined, '${p.createdAt!.year}年${p.createdAt!.month}月から'),
            for (final l in p.links)
              InkWell(
                onTap: () => launchUrl(l.url, mode: LaunchMode.externalApplication),
                child: _Meta(Icons.link, l.label.isEmpty ? l.url.host : l.label, color: scheme.primary),
              ),
            // 確かめた Keybase (D-313)。タップで Keybase のプロフィール。
            if (p.keybase != null)
              InkWell(
                key: const ValueKey('rasqPage.keybase'),
                onTap: () => launchUrl(p.keybase!.profileUrl, mode: LaunchMode.externalApplication),
                child: _Meta(Icons.key_outlined, 'Keybase: @${p.keybase!.username}', color: scheme.primary),
              ),
          ]),
        ]),
      ),
      // ── SNS アカウントのタイル(横に流れる)──
      if (p.snsAccounts.isNotEmpty)
        SizedBox(
          height: 56,
          child: ListView.separated(
            key: const ValueKey('rasqPage.tiles'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
            itemCount: p.snsAccounts.length,
            separatorBuilder: (_, _) => const SizedBox(width: RasqSpacing.sm),
            itemBuilder: (_, i) => RasqSnsTileChip(tile: p.snsAccounts[i], onTap: () => onTile(p.snsAccounts[i])),
          ),
        )
      else
        const SizedBox(height: RasqSpacing.sm),
    ]);
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text, {this.color});
  final IconData icon;
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: c), const SizedBox(width: 3), Text(text, style: RasqTypography.bodySmall.copyWith(color: c))]);
  }
}

/// SNS アカウントのタイル: 角丸の中に アカウント名 → サーバーのアイコン → サーバー名。
class RasqSnsTileChip extends StatelessWidget {
  const RasqSnsTileChip({super.key, required this.tile, this.onTap, this.dimmed = false});
  final RasqSnsTile tile;
  final VoidCallback? onTap;

  /// 編集画面で「いまは出ていない」ことを示す。
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('rasqPage.tile.${tile.kind}:${tile.instance}:${tile.handle}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(tile.label, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              if (tile.serverIconUrl != null)
                ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(webHtmlElementStrategy: rasqWebImageStrategy, tile.serverIconUrl.toString(), width: 18, height: 18, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.dns_outlined, size: 16, color: scheme.onSurfaceVariant)))
              else
                Icon(Icons.dns_outlined, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(tile.serverLabel, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              // 持ち主の確認が済んだアカウント (D-313)。
              if (tile.verified) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: tile.verifiedLabel,
                  child: Icon(Icons.verified, key: ValueKey('rasqPage.tile.verified.${tile.key}'), size: 14, color: scheme.primary, semanticLabel: tile.verifiedLabel),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.posts, required this.isMine, required this.onChanged, this.snsLinked = false, this.onOpenSnsPostsSettings});
  final RasqPostList posts;
  final bool isMine;

  /// ページに SNS アカウントのタイルが出ているか。
  final bool snsLinked;

  /// SNS の投稿を出す設定(アクセストークンを預けるスイッチ、S-027)の画面を開く。
  final VoidCallback? onOpenSnsPostsSettings;

  /// 投稿が変わった / 消えた(ページを取り直す)。
  final VoidCallback onChanged;

  /// 固定の入り切り (S-027)。5 件まで。投稿の … のメニューから (D-423)。
  Future<void> _togglePin(BuildContext context, WidgetRef ref, RasqPin pin) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null) return;
    final has = posts.pins.contains(pin);
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (!has && posts.pins.length >= rasqMaxPins) {
      messenger.showSnackBar(const SnackBar(content: Text('固定できるのは $rasqMaxPins 件までです')));
      return;
    }
    try {
      await api.setPins(has ? [for (final p in posts.pins) if (p != pin) p] : [pin, ...posts.pins]);
      onChanged();
    } on OrgateException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('固定できませんでした: ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final items = orderAccountPosts(posts);
    // 見ている人が、同じサーバーにアカウントを持っていれば、そのアカウントで SNS の投稿にリアクションなどができる (S-027)。
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    // 固定された投稿の印。固定する / 外すは、投稿の … のメニュー (D-423。前は投稿の上の行のボタンだった)。
    Widget pinnedMark(RasqPin pin) => Padding(
          key: ValueKey('rasqPage.pinned.${pin.source}.${pin.ref}'),
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 6, RasqSpacing.page, 0),
          child: Row(children: [Icon(Icons.push_pin, size: 14, color: scheme.onSurfaceVariant), const SizedBox(width: 4), Text('固定された投稿', style: caption)]),
        );
    Future<void> Function() toggle(RasqPin pin) => () => _togglePin(context, ref, pin);
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      if (isMine)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Text(rasqDetail(context, 'RASQ の投稿は ${posts.limit} 件までです(${posts.posts.where((p) => p.rebroadedBy == null).length} / ${posts.limit})。SNS の投稿は、ログインの鍵を預けると一緒に出ます。', 'RASQ アカウントとしての投稿は、いまは ${posts.limit} 件までです(${posts.posts.where((p) => p.rebroadedBy == null).length} / ${posts.limit})。SNS アカウントの投稿は、そのアカウントのアクセストークンを RASQ に預けると、ここに一緒に出ます。'), key: const ValueKey('rasqPage.posts.note'), style: caption),
        ),
      // 自分のページで、SNS アカウントはつないであるのに、その投稿が 1 件も出ていない (D-316): トークンを預けていない
      // (か、取れていない)。「投稿が出ない」と見えるので、預ける画面への入口を出す。ほかの人が見るときは出さない。
      if (isMine && snsLinked && posts.snsPosts.isEmpty)
        Container(
          key: const ValueKey('rasqPage.posts.snsHint'),
          margin: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          padding: const EdgeInsets.all(RasqSpacing.sm),
          decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(RasqSizes.radiusSm), border: Border.all(color: scheme.outlineVariant)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('つないだ SNS アカウントの投稿は、まだここに出ていません。', style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(rasqDetail(context, 'プロフィール編集で「投稿もアカウントページに出す」を入れると、ここに出ます。', 'プロフィール編集の「アカウントページに出す SNS アカウント」で、アカウントごとに「投稿もアカウントページに出す」を入れると(その SNS のアクセストークンを RASQ に預けます)、公開 / ホームの投稿がここに出ます。'), style: caption),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('rasqPage.posts.snsHint.open'),
                onPressed: onOpenSnsPostsSettings,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('SNS の投稿を出す設定へ'),
              ),
            ),
          ]),
        ),
      if (items.isEmpty) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('投稿はまだありません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
      for (final e in items)
        if (e.rasq != null) ...[
          if (e.pinned) pinnedMark((source: 'rasq', ref: e.rasq!.id)),
          RasqPostTileView(
            post: e.rasq!,
            onChanged: onChanged,
            onOpen: () => context.push(Routes.rasqPost(e.rasq!.id)),
            pinned: e.pinned,
            // 固定できるのは、自分の投稿そのもの(リブロードとして出ている行は固定しない)。
            onTogglePin: isMine && (e.pinned || (e.rasq!.rebroadedBy == null && !e.rasq!.isReply)) ? toggle((source: 'rasq', ref: e.rasq!.id)) : null,
          ),
        ] else ...[
          if (e.pinned) pinnedMark(e.sns!.pin),
          _SnsPostRow(key: ValueKey('rasqPage.sns.${e.sns!.pin.ref}'), post: e.sns!, sessions: sessions, menuPin: isMine ? (pinned: e.pinned, toggle: toggle(e.sns!.pin)) : null),
          const Divider(),
        ],
    ]);
  }
}

/// アカウントページに出る SNS の投稿 (S-027)。SNS の投稿と同じ行 ([PostRow]) で描く。
/// **見ている人が、同じ種類・同じサーバーのアカウントを持っていれば**、そのアカウントのセッションでリアクション / リノートなどができる
/// (投稿の id が、そのサーバーの中でそのまま通じるため)。持っていなければ、読むだけ(タップで、その SNS のページを開く)。
class _SnsPostRow extends ConsumerWidget {
  const _SnsPostRow({super.key, required this.post, required this.sessions, this.menuPin});
  final RasqSnsPost post;
  final List<AccountSession> sessions;

  /// … のメニューの「固定する / 固定を外す」(D-423。自分のページだけ)。
  final PostMenuPin? menuPin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 投稿した本人のアカウントがこの端末にあればそれ(自分の投稿 = 自分のメニュー)。Bluesky はサーバーを問わない (D-423)。
    final mine = sessionServing(sessions, post.kind, post.instance, preferKey: post.accountKey);
    final p = post.toPost(viewer: mine?.account);
    final session = mine == null ? null : ref.watch(sessionForAccountProvider(mine.account.key));
    return PostRow(
      post: p,
      menuPin: menuPin,
      actions: session?.actions ?? const [],
      onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, a, args: args),
      onTap: mine != null
          ? () => context.pushPost(p)
          : () {
              final url = p.url;
              if (url != null) launchUrl(url, mode: LaunchMode.externalApplication);
            },
    );
  }
}

class _MediaTab extends ConsumerWidget {
  const _MediaTab({required this.posts});
  final RasqPostList posts;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final central = ref.watch(centralBaseUrlProvider);
    // 注釈つきの投稿のメディアは、ここには並べない(Web のページと同じ)。センシティブなものは伏せて出す。
    final cells = [
      for (final p in posts.posts)
        if (p.cw.isEmpty && p.rebroadedBy == null)
          for (var i = 0; i < p.images.length; i++) (post: p, index: i),
    ];
    if (cells.isEmpty) return _message(context, 'メディアはまだありません。');
    return GridView.builder(
      padding: const EdgeInsets.all(RasqSpacing.sm),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, mainAxisSpacing: 4, crossAxisSpacing: 4),
      itemCount: cells.length,
      itemBuilder: (_, n) {
        final cell = cells[n];
        final m = cell.post.images[cell.index];
        final Widget face = switch (m.type) {
          _ when m.sensitive => Container(color: scheme.surfaceContainerHighest, child: Icon(Icons.visibility_off_outlined, color: scheme.onSurfaceVariant)),
          'image' => Image.network(webHtmlElementStrategy: rasqWebImageStrategy, m.url.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          'video' => Container(color: Colors.black, child: const Icon(Icons.play_circle_outline, color: Colors.white, size: 36)),
          _ => Container(color: scheme.surfaceContainerHighest, child: Icon(Icons.audiotrack, color: scheme.onSurfaceVariant)),
        };
        // タップ = その投稿の全画面表示を、このメディアの位置で開く (D-277)。
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('rasqPage.media.${m.id}'),
              onTap: () => context.openViewer(cell.post.toPost(central: central), cell.index),
              child: face,
            ),
          ),
        );
      },
    );
  }
}

class _PluginsTab extends StatelessWidget {
  const _PluginsTab({required this.profile, required this.reviews});
  final RasqPublicProfile profile;

  /// false = 「プラグイン」タブ(公開したもの)/ true = 「レビュー」タブ(レビューしたもの)。D-277 で 2 つに分けた。
  final bool reviews;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(RasqPagePlugin g) => RasqListTile(
          key: ValueKey('rasqPage.plugin.${g.id}.${g.rating == null ? 'pub' : 'rev'}'),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: g.iconUrl == null
                ? Container(width: 40, height: 40, color: scheme.surfaceContainerHighest, child: const Icon(Icons.extension_outlined, size: 20))
                : Image.network(webHtmlElementStrategy: rasqWebImageStrategy, g.iconUrl.toString(), width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 40, height: 40, color: scheme.surfaceContainerHighest)),
          ),
          title: g.name,
          subtitle: g.rating == null ? g.summary : '${'★' * g.rating!.clamp(0, 5)} ${g.reviewTitle.isEmpty ? g.reviewBody : g.reviewTitle}',
          onTap: () => context.push('/store/plugin/${Uri.encodeComponent(g.id)}'),
        );
    final items = reviews ? profile.reviewed : profile.published;
    if (items.isEmpty) return _message(context, reviews ? 'レビューはまだありません。' : '公開したプラグインはありません。');
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      for (final g in items) tile(g),
    ]);
  }
}
