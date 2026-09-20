import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../shell/headers.dart';
import '../../shell/third_column.dart' show fowColumnOf;
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import 'rasq_page_history.dart';
import 'rasq_post_tile.dart';

/// RASQ アカウントページ (D-270 / S-021)。
///
/// 上から: バナー / アイコン / 表示名・ハンドル / 自己紹介 / 場所・誕生日・登録した年月・リンク →
/// **SNS アカウントのタイル**(横に流れる。アカウント名 → サーバーのアイコン → サーバー名。タップで、ログイン中の SNS なら
/// アプリ内のユーザーページ、そうでなければブラウザ)→ タブ **投稿 / メディア / リスト(第二期)/ プラグイン**。
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

  /// タイルのタップ: その SNS にログイン中ならアプリ内のユーザーページ、そうでなければブラウザ。
  Future<void> _openTile(RasqSnsTile t) async {
    final sessions = ref.read(sessionsProvider).value?.allSessions ?? const [];
    final mine = sessions.where((s) => s.account.instance == t.instance && s.account.kind.name == t.kind).firstOrNull;
    if (mine != null) {
      try {
        final session = ref.read(pluginRegistryProvider).session(mine);
        final user = await session.userByHandle(t.handle, host: t.instance);
        if (user != null && mounted) return context.pushUser(user.summary);
      } catch (_) {
        // 取れなければブラウザへ。
      }
    }
    final url = t.profileUrl;
    if (url == null) return _toast('このアカウントの行き先が分かりません');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) _toast('開けませんでした: $url');
  }

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
    // 開いたページを履歴に (D-272。サイドバーの … の横に出る)。読み込めたときに 1 回。
    ref.listen(rasqAccountPageProvider(widget.handle), (_, next) {
      final p = next.value?.profile;
      if (p != null) ref.read(rasqPageHistoryProvider.notifier).record(RasqVisited(handle: p.handle, displayName: p.displayName, avatarUrl: p.avatarUrl));
    });
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
          ? FloatingActionButton.extended(key: const ValueKey('rasqPage.compose'), onPressed: () => _compose(page.value!.posts), icon: const Icon(Icons.edit_outlined), label: const Text('RASQ に投稿'))
          : null,
      body: page.when(
        loading: () => const RasqLoading(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Text(e is OrgateException && e.code.code == '404' ? '@${widget.handle} という RASQ アカウントはありません' : '読み込めませんでした: ${e is OrgateException ? e.message : e}', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        ),
        data: (d) => DefaultTabController(
          length: 4,
          child: NestedScrollView(
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(child: _Header(profile: d.profile, onTile: _openTile)),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(isScrollable: true, tabAlignment: TabAlignment.start, tabs: const [Tab(text: '投稿'), Tab(text: 'メディア'), Tab(text: 'リスト'), Tab(text: 'プラグイン')]),
                  scheme.surface,
                ),
              ),
            ],
            body: TabBarView(children: [
              _PostsTab(posts: d.posts, isMine: isMine, onChanged: () => ref.invalidate(rasqAccountPageProvider(widget.handle))),
              _MediaTab(posts: d.posts),
              _message(context, '作成したリストは、今後ここに出ます。'),
              _PluginsTab(profile: d.profile),
            ]),
          ),
        ),
      ),
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
          child: p.bannerUrl == null ? ColoredBox(color: scheme.surfaceContainerHighest) : Image.network(p.bannerUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest)),
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
                ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(tile.serverIconUrl.toString(), width: 18, height: 18, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.dns_outlined, size: 16, color: scheme.onSurfaceVariant)))
              else
                Icon(Icons.dns_outlined, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(tile.serverLabel, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PostsTab extends StatelessWidget {
  const _PostsTab({required this.posts, required this.isMine, required this.onChanged});
  final RasqPostList posts;
  final bool isMine;

  /// 投稿が変わった / 消えた(ページを取り直す)。
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      if (isMine)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Text('RASQ アカウントとしての投稿は、いまは ${posts.limit} 件までです(${posts.posts.where((p) => p.rebroadedBy == null).length} / ${posts.limit})。SNS アカウントの投稿をまとめて出す機能は、今後の対応です。', key: const ValueKey('rasqPage.posts.note'), style: caption),
        ),
      if (posts.posts.isEmpty) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('投稿はまだありません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
      for (final p in posts.posts) RasqPostTileView(post: p, onChanged: onChanged, onOpen: () => context.push(Routes.rasqPost(p.id))),
    ]);
  }
}

class _MediaTab extends StatelessWidget {
  const _MediaTab({required this.posts});
  final RasqPostList posts;
  @override
  Widget build(BuildContext context) {
    final images = [for (final p in posts.posts) ...p.images];
    if (images.isEmpty) return _message(context, 'メディアはまだありません。');
    return GridView.builder(
      padding: const EdgeInsets.all(RasqSpacing.sm),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 160, mainAxisSpacing: 4, crossAxisSpacing: 4),
      itemCount: images.length,
      itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(images[i].url.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())),
    );
  }
}

class _PluginsTab extends StatelessWidget {
  const _PluginsTab({required this.profile});
  final RasqPublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(RasqPagePlugin g) => RasqListTile(
          key: ValueKey('rasqPage.plugin.${g.id}.${g.rating == null ? 'pub' : 'rev'}'),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: g.iconUrl == null
                ? Container(width: 40, height: 40, color: scheme.surfaceContainerHighest, child: const Icon(Icons.extension_outlined, size: 20))
                : Image.network(g.iconUrl.toString(), width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(width: 40, height: 40, color: scheme.surfaceContainerHighest)),
          ),
          title: g.name,
          subtitle: g.rating == null ? g.summary : '${'★' * g.rating!.clamp(0, 5)} ${g.reviewTitle.isEmpty ? g.reviewBody : g.reviewTitle}',
          onTap: () => context.push('/store/plugin/${Uri.encodeComponent(g.id)}'),
        );
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      const RasqSectionHeader(title: '公開したプラグイン'),
      if (profile.published.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('公開したプラグインはありません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
      for (final g in profile.published) tile(g),
      const RasqSectionHeader(title: 'レビューしたプラグイン'),
      if (profile.reviewed.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('レビューはまだありません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
      for (final g in profile.reviewed) tile(g),
    ]);
  }
}
