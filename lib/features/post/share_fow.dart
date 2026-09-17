import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import 'post_menu.dart';
import '../compose/account_select.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../plugins/slot_plugins.dart';
import '../vc/astell_post_share.dart';
import '../vc/astell_providers.dart';

/// 投稿の共有 FOW (D-170): アクションバー右端の共有ボタンで開く。
///
/// - ヘッダー左: アカウント選択(200〜300px のピル、[AccountSelectPill])。非公開投稿
///   (ダイレクト / フォロワー限定 / ローカルのみ)は**受け取ったアカウントだけ**。
/// - 本体: 内容をコピー / リンクをコピー / 他のアカウントで共有(選んだアカウントの
///   コンポーザーにリンクを初期入力)、**プラグイン**節(`post.share` を宣言した
///   プラグインが自動で並ぶ。タップで `post.share` → プラグインの FOW がこの FOW の子に
///   インラインで開き、`composer.open` で編集した文面をコンポーザーへ)、DM へ共有、
///   ブラウザで開く。
const postShareFowId = 'fow.post.share';
const postShareDmFowId = 'fow.post.share.dm';
const postShareAccountKey = Key('post.share.account');

/// 共有できる範囲が限られる投稿か(受け取ったアカウントに閉じる)。
bool isPrivatePost(Post p) => p.isDirect || p.visibility == 'followers' || p.localOnly;

/// コピーする「内容」= CW + 本文。
String postShareContent(Post p) => (p.contentWarning != null && p.contentWarning!.isNotEmpty) ? '[${p.contentWarning}] ${p.body}' : p.body;

Future<void> showPostShareFow(WidgetRef ref, Post post, {int column = 0, MediaItem? media}) async {
  final manager = ref.read(overlayManagerProvider);
  final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  final candidates = isPrivatePost(post) ? [for (final s in sessions) if (s.account == post.account) s] : sessions;
  final current = ref.read(currentAccountSessionProvider);
  final selected = ValueNotifier<AccountSession?>(
    candidates.where((s) => s.account == post.account).firstOrNull ?? candidates.where((s) => s.account.key == current?.account.key).firstOrNull ?? candidates.firstOrNull,
  );
  // 全画面表示から (D-213): リンクは画像のリンク。
  final link = media?.url.toString() ?? postWebUrl(post).toString();

  Future<void> openComposer(String text, {Uint8List? media, String? mime, String? name}) async {
    final s = selected.value;
    manager.close(postShareFowId);
    await showComposer(ref, const ComposeNormal(), initialText: text, postAs: s, column: column, initialFiles: media == null ? null : [ComposerInitialFile(bytes: media, name: name ?? 'share.png', mimeType: mime)]);
  }

  Future<void> openDm(DmRoom room) async {
    final s = selected.value;
    manager.close(postShareFowId);
    await showComposer(ref, ComposeDm(room), initialText: link, postAs: s, column: column);
  }

  final spec = FowSpec(
    type: FowPanelType.widget,
    initialHeightFactor: 0.6,
    minHeightFactor: 0.3,
    maxHeightFactor: 0.92,
    dockAboveFooter: true,
    columnIndex: column,
    headerLeading: Padding(
      padding: const EdgeInsets.only(left: RasqSpacing.sm),
      child: ValueListenableBuilder<AccountSession?>(
        valueListenable: selected,
        builder: (context, s, _) {
          if (s == null) return const SizedBox(width: 200);
          return Builder(
            builder: (ctx) => AccountSelectPill(
              key: postShareAccountKey,
              account: s.account,
              displayName: s.displayName,
              avatarUrl: s.avatarUrl,
              tooltip: candidates.length > 1 ? '共有に使うアカウント' : '受け取ったアカウントだけで共有できます',
              onTap: candidates.length <= 1
                  ? null
                  : () async {
                      final box = ctx.findRenderObject() as RenderBox;
                      final pick = await pickAccountSession(manager, id: 'post.share.account', anchor: box.localToGlobal(Offset.zero) & box.size, sessions: candidates, selected: s);
                      if (pick != null) selected.value = pick;
                    },
            ),
          );
        },
      ),
    ),
    headerTrailing: RasqIconButton(icon: Icons.close, tooltip: '閉じる', onPressed: () => manager.close(postShareFowId)),
  );
  try {
    await manager.showFow<void>(
      id: postShareFowId,
      spec: spec,
      semanticsLabel: '共有',
      builder: (ctx, handle) => _ShareBody(post: post, link: link, selected: selected, column: column, onComposer: openComposer, onDm: openDm, media: media),
    );
  } finally {
    manager.closeOwnedBy(postShareFowId);
    selected.dispose();
  }
}

class _ShareBody extends ConsumerStatefulWidget {
  const _ShareBody({required this.post, required this.link, required this.selected, required this.column, required this.onComposer, required this.onDm, this.media});

  /// 全画面表示から (D-213): 「内容をコピー」の代わりに「画像を保存」。
  final MediaItem? media;
  final Post post;
  final String link;
  final ValueNotifier<AccountSession?> selected;
  final int column;
  final Future<void> Function(String text, {Uint8List? media, String? mime, String? name}) onComposer;
  final Future<void> Function(DmRoom room) onDm;
  @override
  ConsumerState<_ShareBody> createState() => _ShareBodyState();
}

class _ShareBodyState extends ConsumerState<_ShareBody> {
  late final SlotPluginsNotifier _slots = ref.read(slotPluginsProvider.notifier);
  late final OverlayManager _manager = ref.read(overlayManagerProvider);

  /// 呼び出したプラグイン → token(閉じるときに `post.share.close`)。
  final Map<SlotPlugin, String> _tokens = {};
  String? _note;

  @override
  void dispose() {
    for (final e in _tokens.entries) {
      _slots.postShareClose(e.key, e.value);
    }
    super.dispose();
  }

  void _snack(String message) {
    final m = ref.read(rootMessengerKeyProvider).currentState;
    m?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snack('$labelをコピーしました');
  }

  Future<void> _plugin(SlotPlugin p) async {
    final s = widget.selected.value;
    final acc = s?.account ?? widget.post.account;
    final existing = _tokens[p];
    if (existing != null) await _slots.postShareClose(p, existing);
    final token = await _slots.postShare(
      p,
      post: astellPostPayloadOf(widget.post),
      account: {'sns': acc.kind.name, 'instance': acc.instance, 'handle': acc.handle},
      link: widget.link,
      fowOwner: postShareFowId,
      column: widget.column,
      onComposerOpen: (text, media, mime, name) => widget.onComposer(text, media: media, mime: mime, name: name),
    );
    if (mounted) setState(() => _tokens[p] = token);
  }

  Future<void> _dm() async {
    final s = widget.selected.value;
    final session = s == null ? ref.read(currentSnsSessionProvider) : ref.read(pluginRegistryProvider).session(s);
    if (session == null) return;
    final room = await _manager.showFow<DmRoom>(
      id: postShareDmFowId,
      ownerId: postShareFowId,
      spec: FowSpec(type: FowPanelType.widget, title: 'DM へ共有', cancelText: '閉じる', initialHeightFactor: 0.5, dockAboveFooter: true, columnIndex: widget.column),
      builder: (ctx, handle) => FutureBuilder<List<DmRoom>>(
        future: session.dmRooms(),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final rooms = snap.data ?? const <DmRoom>[];
          if (rooms.isEmpty) return Center(child: Text('DM の相手がいません', style: RasqTypography.bodySmall));
          return ListView(padding: EdgeInsets.zero, children: [
            for (final r in rooms)
              RasqListTile(
                key: ValueKey('post.share.dm.${r.id}'),
                leading: RasqAvatar(imageUrl: r.peer.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: r.peer.displayName),
                title: r.displayTitle,
                subtitle: '@${r.peer.handle}',
                onTap: () => handle.close(result: r),
              ),
          ]);
        },
      ),
    );
    if (room != null) await widget.onDm(room);
  }

  /// AsTell へのインライン共有 (D-166 → D-178 で共有 FOW へ)。
  void _astell() {
    final room = ref.read(astellSessionProvider)?.room;
    if (room == null) return;
    // 限定公開の投稿の本文をルーム全員へ配らない (D-242)。
    final blocked = astellShareBlockReason(widget.post);
    if (blocked != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(blocked)));
      return;
    }
    ref.read(astellSessionProvider.notifier).share('post', astellPostPayloadOf(widget.post));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('「${room.title}」に共有しました')));
    ref.read(overlayManagerProvider).close(postShareFowId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plugins = ref.watch(slotPluginsForProvider(SlotIds.postShare));
    final astell = ref.watch(astellSessionProvider);
    final post = widget.post;
    return ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.page), children: [
      Row(children: [
        if (widget.media == null)
          _ShareChip(key: const ValueKey('post.share.copyContent'), icon: Icons.notes, label: '内容をコピー', onTap: () => _copy(postShareContent(post), '内容'))
        else
          _ShareChip(key: const ValueKey('post.share.saveImage'), icon: Icons.download_outlined, label: '画像を保存', onTap: () => saveMediaImage(ref, widget.media!)),
        const SizedBox(width: RasqSpacing.sm),
        _ShareChip(key: const ValueKey('post.share.copyLink'), icon: Icons.link, label: 'リンクをコピー', onTap: () => _copy(widget.link, 'リンク')),
        const SizedBox(width: RasqSpacing.sm),
        _ShareChip(key: const ValueKey('post.share.otherAccount'), icon: Icons.switch_account_outlined, label: '他のアカウントで共有', onTap: () => widget.onComposer(widget.link)),
      ]),
      // 「プラグインに共有」(D-178): 参加中の AsTell(ホスト内蔵)+ post.share を宣言したプラグイン。
      // 投稿メニューの「AsTell で共有」はここへ統合。
      const RasqSectionHeader(title: 'プラグインに共有', topMargin: RasqSpacing.md),
      if (astell != null)
        RasqListTile(
          key: const ValueKey('post.share.astell'),
          leading: Icon(Icons.record_voice_over_outlined, size: 20, color: scheme.onSurfaceVariant),
          title: 'AsTell に共有',
          subtitle: '参加中のルーム「${astell.room.title}」へ投稿を流す',
          onTap: _astell,
        ),
      if (plugins.isEmpty && astell == null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: RasqSpacing.sm),
          child: Text('post.share を宣言したプラグイン(と参加中の AsTell)がここに並びます', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
      for (final p in plugins)
        RasqListTile(
          key: ValueKey('post.share.plugin.${p.id}'),
          leading: Icon(Icons.extension_outlined, size: 20, color: scheme.onSurfaceVariant),
          title: p.manifest.name,
          subtitle: p.manifest.description.isEmpty ? null : p.manifest.description,
          onTap: () => _plugin(p),
        ),
      const RasqSectionHeader(title: 'その他', topMargin: RasqSpacing.md),
      RasqListTile(key: const ValueKey('post.share.dm'), leading: Icon(Icons.mail_outline, size: 20, color: scheme.onSurfaceVariant), title: 'DM へ共有', subtitle: '選んだアカウントの DM にリンクを送る', onTap: _dm),
      RasqListTile(
        key: const ValueKey('post.share.browser'),
        leading: Icon(Icons.open_in_browser, size: 20, color: scheme.onSurfaceVariant),
        title: 'ブラウザで開く',
        subtitle: widget.link,
        onTap: () => launchUrl(Uri.parse(widget.link), mode: LaunchMode.externalApplication),
      ),
      if (_note != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_note!, style: RasqTypography.caption.copyWith(color: scheme.error))),
    ]);
  }
}

/// 上段の 3 つ(内容 / リンク / 他のアカウント): アイコン + 短いラベルの角丸チップ。
class _ShareChip extends StatelessWidget {
  const _ShareChip({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 22, color: scheme.onSurface),
              const SizedBox(height: 4),
              Text(label, style: RasqTypography.caption, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }
}
