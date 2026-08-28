import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import 'compose_providers.dart';
import 'compose_target.dart';
import 'emoji_picker_fow.dart';
import 'mfm_picker_fow.dart';
import 'poll_editor.dart';

/// Opens the composer as an interstitial FOW (docked, resizable). Child FOWs
/// (絵文字ピッカー) are owned by it and closed with it.
/// Resolves with the created post, or null on cancel.
const composerFowId = 'fow.composer';

Future<Post?> showComposer(WidgetRef ref, ComposeTarget target) async {
  final manager = ref.read(overlayManagerProvider);
  final res = await manager.showFow<Post>(
    id: composerFowId,
    spec: FowSpec(
      type: FowPanelType.interstitial,
      confirmMode: FowConfirmMode.saveDiscard,
      initialHeightFactor: 0.72,
      minHeightFactor: 0.35,
      title: target.title,
      cancelText: 'キャンセル',
      // ヘッダー右側の空きスペース (D-045): 公開設定 / 連合 / リアクション
      // 受け入れ / MFM ピッカー。
      headerTrailing: ComposerHeaderControls(isDm: target is ComposeDm),
    ),
    builder: (ctx, handle) => _ComposerBody(target: target, onSent: (p) => handle.close(result: p)),
  );
  manager.closeOwnedBy(composerFowId);
  return res;
}

/// FOW ヘッダー右側のコントロール群 (D-045)。状態は [composeOptionsProvider]
/// (本文側と共有、アプリ起動中は前回値を記憶)。DM では公開範囲が specified
/// 固定のため MFM ピッカーだけを出す。
class ComposerHeaderControls extends ConsumerWidget {
  const ComposerHeaderControls({super.key, this.isDm = false});
  final bool isDm;

  Rect _anchorOf(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final opts = ref.watch(composeOptionsProvider);
    final store = ref.read(composeOptionsProvider.notifier);
    final manager = ref.read(overlayManagerProvider);
    final mfm = ref.watch(currentAccountProvider)?.kind == SnsKind.misskey;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (!isDm) ...[
        Builder(builder: (ctx) {
          final (icon, label) = switch (opts.visibility) {
            'home' => (Icons.home_outlined, 'ホーム'),
            'followers' => (Icons.lock_outline, 'フォロワー'),
            _ => (Icons.public, 'パブリック'),
          };
          return RasqActionButton.icon(
            icon: icon,
            tooltip: '公開範囲: $label',
            onTap: () async {
              final picked = await manager.showDropdown<String>(id: 'composer.visibility', ownerId: composerFowId, anchor: _anchorOf(ctx), dense: true, items: const [
                RasqDropdownItem('パブリック', 'public'),
                RasqDropdownItem('ホーム', 'home'),
                RasqDropdownItem('フォロワー', 'followers'),
              ]);
              if (picked != null) store.setVisibility(picked);
            },
          );
        }),
        RasqActionButton.icon(
          icon: Icons.rocket_launch_outlined,
          doneIcon: Icons.public_off,
          done: opts.localOnly,
          tooltip: opts.localOnly ? '連合なし(このサーバーのみ)' : '連合あり(タップで連合なしに)',
          onTap: () => store.setLocalOnly(!opts.localOnly),
        ),
        Builder(builder: (ctx) {
          return RasqActionButton.icon(
            icon: Icons.add_reaction_outlined,
            doneIcon: Icons.add_reaction,
            done: opts.reactionAcceptance != null,
            tooltip: 'リアクションの受け入れ: ${reactionAcceptanceLabels[opts.reactionAcceptance]}',
            onTap: () async {
              final picked = await manager.showDropdown<(String?,)>(id: 'composer.reaction', ownerId: composerFowId, anchor: _anchorOf(ctx), dense: true, items: [
                for (final e in reactionAcceptanceLabels.entries) RasqDropdownItem(e.value, (e.key,)),
              ]);
              if (picked != null) store.setReactionAcceptance(picked.$1);
            },
          );
        }),
      ],
      RasqActionButton.icon(
        icon: Icons.code,
        tooltip: mfm ? 'MFM' : 'Markdown',
        onTap: () => openMfmPicker(ref, ownerId: composerFowId, mfm: mfm, onApply: (p, s) => ref.read(composerInsertBridgeProvider).value = ComposerInsert(p, s)),
      ),
      const SizedBox(width: 4),
    ]);
  }
}

class _Attachment {
  _Attachment({required this.bytes, required this.name, this.mimeType});
  final Uint8List bytes;
  final String name;
  final String? mimeType;
  bool sensitive = false;
  MediaItem? uploaded;
}

class _ComposerBody extends ConsumerStatefulWidget {
  const _ComposerBody({required this.target, required this.onSent});
  final ComposeTarget target;
  final ValueChanged<Post> onSent;
  @override
  ConsumerState<_ComposerBody> createState() => _ComposerBodyState();
}

class _ComposerBodyState extends ConsumerState<_ComposerBody> {
  final _text = TextEditingController();
  final _cw = TextEditingController();
  final _focus = FocusNode();
  bool _cwOn = false;
  PollDraft? _poll;
  final List<_Attachment> _files = [];
  bool _busy = false;
  String? _error;
  String? _progress;

  late final ValueNotifier<ComposerInsert?> _bridge;

  @override
  void initState() {
    super.initState();
    // ヘッダー/MFM ピッカーからの挿入依頼(カーソル位置はこちらが知っている)。
    _bridge = ref.read(composerInsertBridgeProvider);
    _bridge.addListener(_onBridgeInsert);
    final t = widget.target;
    if (t is ComposeReply) {
      final a = t.to.author;
      final me = ref.read(currentAccountProvider);
      final mention = a.account.instance == me?.instance ? '@${a.handle}' : '@${a.handle}@${a.account.instance}';
      _text.text = '$mention ';
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
      if (t.to.contentWarning != null && t.to.contentWarning!.isNotEmpty) {
        _cwOn = true;
        _cw.text = t.to.contentWarning!;
      }
    }
  }

  @override
  void dispose() {
    _bridge.removeListener(_onBridgeInsert);
    _text.dispose();
    _cw.dispose();
    _focus.dispose();
    _poll?.dispose();
    super.dispose();
  }

  void _onBridgeInsert() {
    final ins = _bridge.value;
    if (ins == null || !mounted) return;
    _bridge.value = null;
    _wrapSelection(ins.prefix, ins.suffix);
    _focus.requestFocus();
  }

  /// 選択範囲を [prefix]…[suffix] で包む。カーソルは中身部分(サフィックス
  /// 直前)へ — MFM 挿入後にそのまま本文を打てる (D-045)。
  void _wrapSelection(String prefix, String suffix) {
    final v = _text.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final selected = v.text.substring(sel.start, sel.end);
    final next = v.text.replaceRange(sel.start, sel.end, '$prefix$selected$suffix');
    _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: sel.start + prefix.length + selected.length));
    setState(() {});
  }

  SnsSession? get _session => ref.read(currentSnsSessionProvider);
  bool get _isDm => widget.target is ComposeDm;
  int get _max => _session?.maxPostLength ?? 500;

  void _insert(String s) {
    final v = _text.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final next = v.text.replaceRange(sel.start, sel.end, s);
    _text.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: sel.start + s.length));
    setState(() {});
  }

  Future<void> _pick({bool camera = false}) async {
    final picker = ImagePicker();
    try {
      final files = camera ? [await picker.pickImage(source: ImageSource.camera)].whereType<XFile>().toList() : await picker.pickMultiImage();
      for (final f in files.take(4 - _files.length)) {
        _files.add(_Attachment(bytes: await f.readAsBytes(), name: f.name, mimeType: f.mimeType));
      }
      setState(() {});
    } catch (e) {
      if (camera) return _pick();
      setState(() => _error = '画像を選択できませんでした: $e');
    }
  }

  bool get _canSend {
    if (_busy || _session == null) return false;
    final hasText = _text.text.trim().isNotEmpty;
    final hasMedia = _files.isNotEmpty;
    final pollOk = _poll == null || _poll!.isValid;
    if (_poll != null && !_poll!.isValid) return false;
    if (_text.text.length > _max) return false;
    return (hasText || hasMedia || (_poll != null && pollOk)) && !(_isDm && _files.length > 1);
  }

  Future<void> _send() async {
    final session = _session;
    if (session == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ids = <String>[];
      for (var i = 0; i < _files.length; i++) {
        final f = _files[i];
        setState(() => _progress = 'アップロード中 ${i + 1}/${_files.length}');
        f.uploaded ??= await session.uploadMedia(f.bytes, f.name, mimeType: f.mimeType, sensitive: f.sensitive);
        ids.add(f.uploaded!.id);
      }
      setState(() => _progress = '送信中…');
      // 投稿オプション (D-045: FOW ヘッダーの公開設定/連合/リアクション受け入れ)。
      final opts = ref.read(composeOptionsProvider);
      final draft = NewPost(
        text: _text.text.trim(),
        contentWarning: _cwOn && _cw.text.trim().isNotEmpty ? _cw.text.trim() : null,
        replyToId: switch (widget.target) { ComposeReply(to: final p) => p.id, _ => null },
        quoteOfId: switch (widget.target) { ComposeQuote(of: final p) => p.id, _ => null },
        visibility: _isDm ? null : opts.visibility,
        localOnly: !_isDm && opts.localOnly,
        reactionAcceptance: _isDm ? null : opts.reactionAcceptance,
        mediaIds: ids,
        poll: _poll == null ? null : NewPoll(choices: _poll!.texts, multiple: _poll!.multiple, expiresAfter: _poll!.expiresAfter),
      );
      final post = switch (widget.target) {
        ComposeDm(room: final r) => await session.sendDm(r, draft),
        _ => await session.createPost(draft),
      };
      widget.onSent(post);
    } on SnsApiException catch (e) {
      setState(() => _error = '${e.code.display}${e.code.message == null ? '' : '\n${e.code.message}'}');
    } catch (e) {
      setState(() => _error = '送信に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final me = ref.watch(currentUserProvider);
    final emojis = ref.watch(emojiCacheProvider);
    final target = widget.target;
    final count = _text.text.length;
    final over = count > _max;

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (target is ComposeReply || target is ComposeQuote)
              Padding(
                padding: const EdgeInsets.only(bottom: RasqSpacing.sm),
                child: _TargetPreview(post: target is ComposeReply ? target.to : (target as ComposeQuote).of, emojis: emojis),
              ),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RasqAvatar(imageUrl: me.avatarUrl, size: RasqSizes.avatarMd, fallbackLabel: me.displayName),
              const SizedBox(width: RasqSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_cwOn)
                    Row(children: [
                      Icon(Icons.visibility_outlined, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: _cw, decoration: const InputDecoration(hintText: '注釈..', isDense: true), style: RasqTypography.bodySmall)),
                      RasqIconButton(icon: Icons.cancel, size: 20, tooltip: '注釈を外す', onPressed: () => setState(() => _cwOn = false)),
                    ]),
                  TextField(
                    controller: _text,
                    focusNode: _focus,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 10,
                    style: RasqTypography.body,
                    decoration: InputDecoration(hintText: _isDm ? 'メッセージを入力..' : 'いいことがありますように！', border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none),
                    onChanged: (_) => setState(() {}),
                  ),
                ]),
              ),
            ]),
            if (_files.isNotEmpty)
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _files.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _AttachmentTile(a: _files[i], onRemove: () => setState(() => _files.removeAt(i)), onToggleSensitive: () => setState(() => _files[i].sensitive = !_files[i].sensitive)),
                ),
              ),
            if (_poll != null) PollEditor(draft: _poll!, onRemove: () => setState(() => _poll = null)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.sm),
                child: Text(_error!, style: RasqTypography.bodySmall.copyWith(color: tokens.danger)),
              ),
            if (_progress != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_progress!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          ]),
        ),
      ),
      // Toolbar (コンポーザーツールバー = アクションバーの左寄せバリエーション)
      Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 4, RasqSpacing.sm, 4),
        child: Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                RasqActionButton.icon(icon: Icons.photo_camera_outlined, tooltip: 'カメラ', onTap: _busy ? null : () => _pick(camera: true)),
                RasqActionButton.icon(icon: Icons.image_outlined, tooltip: '画像', onTap: _busy || _files.length >= 4 ? null : () => _pick()),
                RasqActionButton.icon(icon: Icons.visibility_outlined, doneIcon: Icons.visibility, done: _cwOn, tooltip: '隠す(注釈)', onTap: () => setState(() => _cwOn = !_cwOn)),
                if (!_isDm) RasqActionButton.icon(icon: Icons.poll_outlined, doneIcon: Icons.poll, done: _poll != null, tooltip: '投票', onTap: () => setState(() => _poll = _poll == null ? PollDraft() : null)),
                RasqActionButton.icon(
                  icon: Icons.emoji_emotions_outlined,
                  tooltip: '絵文字',
                  onTap: () => openEmojiPicker(ref, ownerId: composerFowId, predictionContext: _text.text, onPick: (e) {
                    _insert(e);
                    _focus.requestFocus();
                  }),
                ),
              ]),
            ),
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: over ? tokens.danger : scheme.primary, width: 1.5)),
            child: Text('$count', style: RasqTypography.caption.copyWith(color: over ? tokens.danger : scheme.primary, fontSize: 10)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _canSend ? _send : null,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text(switch (target) { ComposeReply() => '返信', ComposeDm() => '送信', _ => '送信' }),
          ),
        ]),
      ),
    ]);
  }
}

class _TargetPreview extends StatelessWidget {
  const _TargetPreview({required this.post, required this.emojis});
  final Post post;
  final Map<String, Uri?> emojis;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RasqAvatar(imageUrl: post.author.avatarUrl, size: RasqSizes.avatarSm, fallbackLabel: post.author.displayName),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.author.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
            RasqRichText(InlineSpans.parse(post.body, emojis: emojis), style: RasqTypography.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({required this.a, required this.onRemove, required this.onToggleSensitive});
  final _Attachment a;
  final VoidCallback onRemove;
  final VoidCallback onToggleSensitive;
  @override
  Widget build(BuildContext context) => Stack(children: [
        ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(a.bytes, width: 88, height: 88, fit: BoxFit.cover)),
        Positioned(right: 0, top: 0, child: RasqIconButton(icon: Icons.cancel, size: 18, color: Colors.white, onPressed: onRemove, tooltip: '削除')),
        Positioned(
          left: 0,
          bottom: 0,
          child: IconButton(
            onPressed: onToggleSensitive,
            tooltip: a.sensitive ? 'センシティブ解除' : 'センシティブにする',
            icon: Icon(a.sensitive ? Icons.visibility_off : Icons.visibility_outlined, size: 18, color: Colors.white),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ),
      ]);
}
