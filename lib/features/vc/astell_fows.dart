import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'astell_models.dart';
import 'astell_providers.dart';

/// AsTell の 3 つの FOW (D-139、ワイヤーフレーム p.3):
///
/// - [openAstellPreviewFow] 参加 FOW — タイトル / 共有・ブックマーク / 参加メンバー /
///   ざっくり要約 / ジャンル / 下段(マイク・字幕・**参加**・歯車)
/// - [openAstellRoomFow] ルーム FOW(参加後)— 共有欄 / 参加メンバー / 設定トグル /
///   ジャンル編集 / 文字起こしのティッカー + 入力 / 下段(マイク・画面・字幕・共有・歯車)、
///   ヘッダー右は **退出**
/// - [openAstellCreateFow] 作成 FOW — タイトル / フォロワーを招待 / ウェルカム
///   メッセージ / トグル 2 つ / 下段(**作成**)
///
/// 音声・映像(WebRTC)はまだ繋がない — マイク/画面のボタンは状態表示だけ。
const astellPreviewFowId = 'fow.astell.preview';
const astellRoomFowId = 'fow.astell.room';
const astellCreateFowId = 'fow.astell.create';

FowSpec _spec({required String title, String? cancelText, Widget? trailing, double height = 0.6}) => FowSpec(
      type: FowPanelType.widget,
      initialHeightFactor: height,
      minHeightFactor: 0.35,
      maxHeightFactor: 0.92,
      title: title,
      cancelText: cancelText,
      headerTrailing: trailing,
      dockAboveFooter: true,
    );

Widget _label(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 2),
      child: Text(text, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );

/// 参加メンバー行: アバター(マイク/スピーカーのバッジ)+ 名前、3 人まで + 「他N人」。
class AstellMembersRow extends StatelessWidget {
  const AstellMembersRow({super.key, required this.peers, this.totalCount});
  final List<AstellPeer> peers;
  final int? totalCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = peers.take(3).toList();
    final total = totalCount ?? peers.length;
    final rest = total - shown.length;
    if (peers.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('まだ誰もいません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
      child: Row(children: [
        for (final p in shown) ...[
          Column(mainAxisSize: MainAxisSize.min, children: [
            RasqAvatar(
              imageUrl: p.avatarUrl,
              size: RasqSizes.avatarXl,
              fallbackLabel: p.displayName,
              badge: Icon(p.micOn ? Icons.mic : Icons.volume_up, size: 14, color: p.micOn ? RasqColors.accent : RasqColors.sub),
            ),
            const SizedBox(height: 2),
            SizedBox(width: RasqSizes.avatarXl + 8, child: Text(p.displayName, style: RasqTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center)),
          ]),
          const SizedBox(width: RasqSpacing.md),
        ],
        if (rest > 0) Text('他$rest人', style: RasqTypography.body),
      ]),
    );
  }
}

/// ジャンルのチップ列(先頭が選択色、横スクロール)。
class AstellGenreChips extends StatelessWidget {
  const AstellGenreChips({super.key, required this.genres});
  final List<String> genres;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (genres.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), children: [
        for (final (i, g) in genres.indexed)
          Padding(
            padding: const EdgeInsets.only(right: RasqSpacing.xs),
            child: RasqPill(label: g, dense: false, color: i == 0 ? RasqColors.lightBlue : scheme.surfaceContainerHighest, textColor: i == 0 ? RasqColors.navy : scheme.onSurface),
          ),
      ]),
    );
  }
}

/// 下段の丸ボタン(マイク / 字幕 / 画面 / 歯車)。
class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, this.onPressed, this.filled, this.active = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? filled;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ?? Colors.transparent,
        shape: CircleBorder(side: filled == null ? BorderSide(color: scheme.onSurface, width: 1.5) : BorderSide.none),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: filled != null ? Colors.white : (onPressed == null ? scheme.onSurfaceVariant : scheme.onSurface))),
        ),
      ),
    );
  }
}

Future<void> _notYet(BuildContext context, String what) async {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what は M5 後段(WebRTC 接続)で入ります')));
}

// ── 参加 FOW ──────────────────────────────────────────────────────

Future<void> openAstellPreviewFow(BuildContext context, WidgetRef ref, AstellRoom room) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showFow<void>(
    id: astellPreviewFowId,
    spec: _spec(
      title: room.title,
      cancelText: '閉じる',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        RasqIconButton(icon: Icons.ios_share, size: 20, tooltip: '共有', onPressed: () {}),
        RasqIconButton(icon: Icons.bookmark, size: 20, tooltip: 'ブックマーク', onPressed: () {}),
      ]),
    ),
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => _PreviewBody(room: room, onJoin: () async {
      handle.close();
      await ref.read(astellSessionProvider.notifier).join(room);
      if (context.mounted) await openAstellRoomFow(context, ref);
    }),
  );
}

class _PreviewBody extends ConsumerWidget {
  const _PreviewBody({required this.room, required this.onJoin});
  final AstellRoom room;
  final Future<void> Function() onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final peers = ref.watch(astellPeersProvider(room.id)).value ?? const <AstellPeer>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          _label(context, '参加メンバー'),
          AstellMembersRow(peers: peers, totalCount: room.peerCount > peers.length ? room.peerCount : null),
          const Divider(height: RasqSpacing.md),
          _label(context, 'ざっくり要約'),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
            child: Text(room.showSummary ? room.summaryText : 'このルームはざっくり要約を公開していません。', style: RasqTypography.body.copyWith(color: room.description.isEmpty ? scheme.onSurfaceVariant : null)),
          ),
          AstellGenreChips(genres: room.genres),
          if (room.welcomeMessage != null && room.welcomeMessage!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
              child: Text('ようこそ: ${room.welcomeMessage}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ),
        ]),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm),
        child: Row(children: [
          _RoundButton(icon: Icons.mic_off, tooltip: 'マイク(参加後に切替)', onPressed: null),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.subtitles_outlined, tooltip: '字幕', filled: room.showSummary ? const Color(0xFF2EBF8F) : scheme.outline, onPressed: () {}),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: RasqGradientButton(label: '参加', onPressed: onJoin)),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.settings, tooltip: '設定', onPressed: () => _notYet(context, 'VC の設定')),
        ]),
      ),
    ]);
  }
}

// ── ルーム FOW(参加後) ────────────────────────────────────────────

Future<void> openAstellRoomFow(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  final room = ref.read(astellSessionProvider)?.room;
  if (room == null) return;
  await manager.showFow<void>(
    id: astellRoomFowId,
    spec: _spec(
      title: room.title,
      height: 0.75,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        RasqIconButton(icon: Icons.ios_share, size: 20, tooltip: '共有', onPressed: () {}),
        RasqIconButton(icon: Icons.bookmark, size: 20, tooltip: 'ブックマーク', onPressed: () {}),
        Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              await ref.read(astellSessionProvider.notifier).leave();
              manager.close(astellRoomFowId);
            },
            child: Text('退出', style: TextStyle(color: RasqTokens.of(ctx).danger, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    ),
    // 余白タップでは閉じない(閉じる = 退出のみ。ミニ化は FOW のドラッグで)。
    barrierBehavior: OverlayBarrierBehavior.none,
    builder: (ctx, handle) => const AstellRoomBody(),
  );
}

class AstellRoomBody extends ConsumerStatefulWidget {
  const AstellRoomBody({super.key});
  @override
  ConsumerState<AstellRoomBody> createState() => _AstellRoomBodyState();
}

class _AstellRoomBodyState extends ConsumerState<AstellRoomBody> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final s = ref.watch(astellSessionProvider);
    if (s == null) return const RasqEmptyView(title: '退出しました');
    final session = ref.read(astellSessionProvider.notifier);
    final room = s.room;
    final isOwner = ref.watch(rasqAccountProvider).account.handle == room.ownerHandle;
    final lastLines = s.transcripts.reversed.take(3).toList().reversed;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (s.error != null)
        Container(
          color: tokens.danger.withValues(alpha: 0.08),
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
          child: Text(s.error!, style: RasqTypography.caption.copyWith(color: tokens.danger)),
        )
      else if (!s.connected)
        Container(
          color: scheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
          child: Text('接続しています…', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          _label(context, '共有'),
          if (s.shares.isEmpty)
            Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('まだ共有はありません。下の入力からテキストやリンクを共有できます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)))
          else
            for (final sh in s.shares.reversed.take(5))
              Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 2, RasqSpacing.page, 2),
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: scheme.outline), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: RasqSpacing.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      RasqPill(label: sh.kind),
                      const SizedBox(width: RasqSpacing.xs),
                      Expanded(child: Text(sh.headline, style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    ]),
                    Text('${sh.accountId == 'me' || sh.handle == ref.watch(rasqAccountProvider).account.handle ? 'あなた' : sh.displayName} が共有', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                ),
              ),
          const Divider(height: RasqSpacing.md),
          _label(context, '参加メンバー'),
          AstellMembersRow(peers: s.peers),
          const Divider(height: RasqSpacing.md),
          RasqSwitchListTile(
            title: 'プレビューにざっくり要約を表示する',
            value: room.showSummary,
            enabled: isOwner,
            onChanged: isOwner ? (v) => _patch({'showSummary': v}) : null,
          ),
          RasqSwitchListTile(
            title: 'ジャンルを自動選択する',
            value: room.autoGenre,
            enabled: isOwner,
            onChanged: isOwner ? (v) => _patch({'autoGenre': v}) : null,
          ),
          _label(context, isOwner ? '自動選択されたジャンルを編集' : 'ジャンル'),
          AstellGenreChips(genres: room.genres),
          const SizedBox(height: RasqSpacing.sm),
        ]),
      ),
      const Divider(height: 1),
      // 下段: マイク / 画面 / 字幕 / 文字起こしティッカー + 入力 / 共有 / 歯車。
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _RoundButton(icon: s.micOn ? Icons.mic : Icons.mic_off, tooltip: s.micOn ? 'マイクオフ' : 'マイクオン(音声は M5 後段)', active: s.micOn, onPressed: session.toggleMic),
          const SizedBox(width: RasqSpacing.xs),
          _RoundButton(icon: Icons.desktop_access_disabled_outlined, tooltip: '画面配信', onPressed: () => _notYet(context, '画面配信')),
          const SizedBox(width: RasqSpacing.xs),
          _RoundButton(icon: Icons.subtitles_outlined, tooltip: s.captionsOn ? '字幕オフ' : '字幕オン', filled: s.captionsOn ? const Color(0xFF2EBF8F) : null, onPressed: session.toggleCaptions),
          const SizedBox(width: RasqSpacing.xs),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              if (s.captionsOn)
                for (final t in lastLines) Text('${t.displayName}>${t.text}', style: RasqTypography.caption.copyWith(fontSize: 9, color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (s.captionsOn && s.transcripts.isEmpty && room.showSummary)
                Text('文字起こしはまだありません', style: RasqTypography.caption.copyWith(fontSize: 9, color: scheme.onSurfaceVariant)),
              RasqInput(
                controller: _input,
                hintText: 'input..',
                onSubmitted: (_) => _sendShare(),
              ),
            ]),
          ),
          const SizedBox(width: RasqSpacing.xs),
          _RoundButton(icon: Icons.upload, tooltip: '共有する', filled: scheme.onSurface, onPressed: _sendShare),
          const SizedBox(width: RasqSpacing.xs),
          _RoundButton(icon: Icons.settings, tooltip: '設定', onPressed: () => _notYet(context, 'VC の設定')),
        ]),
      ),
    ]);
  }

  void _sendShare() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final isLink = text.startsWith('http://') || text.startsWith('https://');
    ref.read(astellSessionProvider.notifier).share(isLink ? 'link' : 'text', isLink ? {'url': text} : {'text': text});
    _input.clear();
  }

  Future<void> _patch(Map<String, Object?> patch) async {
    final s = ref.read(astellSessionProvider);
    if (s == null) return;
    try {
      final updated = await ref.read(astellClientProvider).updateRoom(s.room.id, patch);
      ref.read(astellSessionProvider.notifier).applyRoom(updated);
      ref.invalidate(astellHomeProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('設定を更新できませんでした: $e')));
    }
  }
}

// ── 作成 FOW ──────────────────────────────────────────────────────

Future<void> openAstellCreateFow(BuildContext context, WidgetRef ref) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showFow<void>(
    id: astellCreateFowId,
    spec: _spec(title: 'VC を作成', cancelText: 'キャンセル', height: 0.7),
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (ctx, handle) => _CreateBody(onCreated: (room) async {
      handle.close();
      ref.invalidate(astellHomeProvider);
      await ref.read(astellSessionProvider.notifier).join(room);
      if (context.mounted) await openAstellRoomFow(context, ref);
    }),
  );
}

class _CreateBody extends ConsumerStatefulWidget {
  const _CreateBody({required this.onCreated});
  final Future<void> Function(AstellRoom room) onCreated;
  @override
  ConsumerState<_CreateBody> createState() => _CreateBodyState();
}

class _CreateBodyState extends ConsumerState<_CreateBody> {
  final _title = TextEditingController();
  final _welcome = TextEditingController();
  final _description = TextEditingController();
  bool _welcomeOn = false;
  bool _showSummary = true;
  bool _autoGenre = true;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _welcome.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('タイトルを入力してください')));
      return;
    }
    setState(() => _busy = true);
    try {
      final room = await ref.read(astellClientProvider).createRoom(NewAstellRoom(
            title: title,
            description: _description.text.trim(),
            welcomeMessage: _welcomeOn && _welcome.text.trim().isNotEmpty ? _welcome.text.trim() : null,
            showSummary: _showSummary,
            autoGenre: _autoGenre,
          ));
      await widget.onCreated(room);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('作成できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final me = ref.watch(rasqAccountProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        child: ListView(padding: EdgeInsets.zero, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: RasqInput(controller: _title, hintText: 'タイトル', autofocus: true),
          ),
          _label(context, 'フォロワーを招待'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
            child: Row(children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarXl, fallbackLabel: me.displayName),
                const SizedBox(height: 2),
                Text('あなた', style: RasqTypography.caption),
              ]),
              const SizedBox(width: RasqSpacing.md),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Material(
                  shape: CircleBorder(side: BorderSide(color: scheme.onSurface, width: 1.5)),
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _notYet(context, 'フォロワーの招待'),
                    child: SizedBox(width: RasqSizes.avatarXl, height: RasqSizes.avatarXl, child: Icon(Icons.add, size: 28, color: scheme.onSurface)),
                  ),
                ),
                const SizedBox(height: 2),
                Text('検索して追加', style: RasqTypography.caption),
              ]),
            ]),
          ),
          const Divider(height: RasqSpacing.md),
          RasqSwitchListTile(title: '参加時にウェルカムメッセージを表示する', value: _welcomeOn, onChanged: (v) => setState(() => _welcomeOn = v)),
          if (_welcomeOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
              child: RasqInput(controller: _welcome, hintText: 'ウェルカムメッセージを設定..'),
            ),
          const Divider(height: 1),
          RasqSwitchListTile(title: 'プレビューにざっくり要約を表示する', value: _showSummary, onChanged: (v) => setState(() => _showSummary = v)),
          const Divider(height: 1),
          RasqSwitchListTile(title: 'ジャンルを自動選択する', value: _autoGenre, onChanged: (v) => setState(() => _autoGenre = v)),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
            child: RasqInput(controller: _description, hintText: 'ざっくり要約(任意。空なら端末側で自動生成)', maxLines: 2),
          ),
        ]),
      ),
      const Divider(height: 1),
      Padding(
        padding: const EdgeInsets.all(RasqSpacing.sm),
        child: Row(children: [
          _RoundButton(icon: Icons.mic_off, tooltip: 'マイク(作成後に切替)', onPressed: null),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.subtitles_outlined, tooltip: '字幕', filled: _showSummary ? const Color(0xFF2EBF8F) : scheme.outline, onPressed: () => setState(() => _showSummary = !_showSummary)),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(child: RasqGradientButton(label: '作成', onPressed: _busy ? null : _create, enabled: !_busy)),
          const SizedBox(width: RasqSpacing.sm),
          _RoundButton(icon: Icons.settings, tooltip: '設定', onPressed: () => _notYet(context, 'VC の設定')),
        ]),
      ),
    ]);
  }
}
