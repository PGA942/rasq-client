import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart';
import '../../shell/headers.dart';
import 'rasq_profile_edit_screen.dart' show profileImageContentType;

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
  bool _busy = false;

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

  Future<void> _compose(RasqPostList posts) async {
    if (posts.posts.length >= posts.limit) return _toast('投稿は ${posts.limit} 件までです。古い投稿を消してから投稿してください');
    final draft = await showRasqPostSheet(ref);
    if (draft == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(rasqAccountPageApiProvider)!.createPost(draft.body, images: draft.images);
      ref.invalidate(rasqAccountPageProvider(widget.handle));
      _toast('投稿しました');
    } on OrgateException catch (e) {
      _toast(e.code.code == '409' ? '投稿は ${posts.limit} 件までです' : '投稿できませんでした: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(RasqAccountPost p) async {
    final ok = await ref.read(overlayManagerProvider).showAlert(id: 'rasq.post.delete', title: '投稿を削除', message: 'この投稿と、付いている画像を削除します。元に戻せません。', confirmText: '削除する', cancelText: 'キャンセル', destructive: true);
    if (!ok || !mounted) return;
    try {
      await ref.read(rasqAccountPageApiProvider)!.deletePost(p.id);
      ref.invalidate(rasqAccountPageProvider(widget.handle));
    } on OrgateException catch (e) {
      _toast('削除できませんでした: ${e.message}');
    }
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
          ? FloatingActionButton.extended(key: const ValueKey('rasqPage.compose'), onPressed: _busy ? null : () => _compose(page.value!.posts), icon: const Icon(Icons.edit_outlined), label: const Text('RASQ に投稿'))
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
              _PostsTab(posts: d.posts, profile: d.profile, isMine: isMine, onDelete: _delete),
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
  const _PostsTab({required this.posts, required this.profile, required this.isMine, required this.onDelete});
  final RasqPostList posts;
  final RasqPublicProfile profile;
  final bool isMine;
  final ValueChanged<RasqAccountPost> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return ListView(padding: const EdgeInsets.only(bottom: 96), children: [
      if (isMine)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Text('RASQ アカウントとしての投稿は、いまは ${posts.limit} 件までです(${posts.posts.length} / ${posts.limit})。SNS アカウントの投稿をまとめて出す機能は、今後の対応です。', key: const ValueKey('rasqPage.posts.note'), style: caption),
        ),
      if (posts.posts.isEmpty) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('投稿はまだありません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))),
      for (final p in posts.posts)
        Container(
          key: ValueKey('rasqPage.post.${p.id}'),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RasqAvatar(imageUrl: profile.avatarUrl, size: 36, fallbackLabel: profile.displayName.isEmpty ? profile.handle : profile.displayName),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(profile.displayName.isEmpty ? profile.handle : profile.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                  if (p.createdAt != null) Text('${p.createdAt!.toLocal().month}/${p.createdAt!.toLocal().day}', style: caption),
                  if (isMine) RasqIconButton(icon: Icons.delete_outline, size: 18, tooltip: '投稿を削除', onPressed: () => onDelete(p)),
                ]),
                if (p.body.isNotEmpty) Text(p.body),
                if (p.images.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: RasqSpacing.sm),
                    child: Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final i in p.images) ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(i.url.toString(), width: p.images.length == 1 ? 260 : 126, height: p.images.length == 1 ? 180 : 126, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 126, height: 126))),
                    ]),
                  ),
              ]),
            ),
          ]),
        ),
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

/// RASQ アカウントとしての投稿を書くシート: 本文(1000 文字まで)+ 画像 4 枚まで。
Future<({String body, List<({List<int> bytes, String contentType})> images})?> showRasqPostSheet(WidgetRef ref) async {
  final body = TextEditingController();
  final images = <({Uint8List bytes, String contentType})>[];
  final ok = await ref.read(overlayManagerProvider).showBottomSheet<bool>(
        id: 'rasq.post.compose',
        title: 'RASQ に投稿',
        confirmText: '投稿',
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              RasqInput(key: const ValueKey('rasqPost.body'), controller: body, hintText: 'いまどうしてる?(1000 文字まで)', maxLines: 5, autofocus: true),
              const SizedBox(height: RasqSpacing.sm),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (var i = 0; i < images.length; i++)
                  Stack(children: [
                    ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(images[i].bytes, width: 64, height: 64, fit: BoxFit.cover)),
                    Positioned(right: 0, top: 0, child: RasqIconButton(icon: Icons.cancel, size: 16, tooltip: '外す', onPressed: () => setState(() => images.removeAt(i)))),
                  ]),
                if (images.length < 4)
                  OutlinedButton.icon(
                    key: const ValueKey('rasqPost.addImage'),
                    onPressed: () async {
                      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (x == null) return;
                      final v = (bytes: await x.readAsBytes(), contentType: profileImageContentType(x.name, x.mimeType));
                      setState(() => images.add(v));
                    },
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('画像'),
                  ),
              ]),
              const SizedBox(height: RasqSpacing.xs),
              Text('RASQ の公開ページに出ます。画像はサーバーで縮めて保存し直します(位置情報などは残りません)。', style: RasqTypography.caption.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
            ]),
          ),
        ),
      );
  final text = body.text.trim();
  if (ok != true || (text.isEmpty && images.isEmpty)) return null;
  return (body: text, images: [for (final i in images) (bytes: i.bytes as List<int>, contentType: i.contentType)]);
}
