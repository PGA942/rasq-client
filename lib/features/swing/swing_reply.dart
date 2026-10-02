import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart' show OrgateException, centralBaseUrlProvider;
import '../../backend/rasq_account_page_api.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../profile/rasq_post_screen.dart';
import '../profile/rasq_post_tile.dart' show RasqPostTileView, pickRasqQueue;
import 'swing_models.dart';

/// Swing の返信とキュー (D-389 / Central S-058)。ビューワーの**左下**に置く。
///
/// - **stick の入力欄**「返信を送る…」: 押すと返信のコンポーザーに変わる(RASQ アカウントとして、その Swing のスレッドへ返信)。
/// - **Que ボタン**: 押すと、いいね(付けていれば外す)。長押しでキューのピッカー(アセットパックの絵)。
/// - **ハンドル**(入力欄の上): 上に引く(か押す)と、Swing のスレッド = RASQ の投稿の詳細が **FOW** で開く。
/// - どれかを開いている間は、Swing を止める([onHold])。スレッドは Swing を見られる人だけに見える(Central が絞る)。
///
/// D-413: ビューワーでは返信が **Swing の下に続く**([SwingThreadSection])。ハンドル([onOpenThread])と入力欄([onReply])は
/// そこへ送る(渡されなければ前のとおり、スレッドの FOW / 返信のコンポーザー)。
class SwingReplyBar extends ConsumerStatefulWidget {
  const SwingReplyBar({super.key, required this.swing, required this.onHold, this.onOpenThread, this.onReply});
  final Swing swing;

  /// true = 止める(コンポーザー / ピッカー / FOW を開いた)、false = 戻す。
  final ValueChanged<bool> onHold;

  /// ハンドルを上に引いた / 押した(下に続くスレッドへ)。null = スレッドの FOW。
  final VoidCallback? onOpenThread;

  /// 入力欄を押した(下に続くスレッドの返信の欄へ)。null = 返信のコンポーザー。
  final VoidCallback? onReply;

  /// スレッドの FOW の id。
  static const threadFowId = 'fow.swing.thread';

  @override
  ConsumerState<SwingReplyBar> createState() => _SwingReplyBarState();
}

class _SwingReplyBarState extends ConsumerState<SwingReplyBar> {
  double _drag = 0;

  String get _postId => widget.swing.postId!;

  void _refresh() => ref.invalidate(rasqThreadProvider(_postId));

  Future<void> _hold(Future<void> Function() f) async {
    widget.onHold(true);
    try {
      await f();
    } finally {
      if (mounted) widget.onHold(false);
    }
  }

  Future<void> _reply(RasqAccountPost post) => _hold(() async {
        await showComposer(ref, ComposeReply(post.toPost(central: ref.read(centralBaseUrlProvider))), onPosted: (_) => _refresh());
      });

  Future<void> _run(Future<RasqAccountPost> Function(RasqAccountPageApi api) f) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null) return;
    try {
      await f(api);
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('できませんでした: $e')));
    }
    _refresh();
  }

  Future<void> _que(RasqAccountPost post) async {
    final mine = post.queues.where((q) => q.mine).firstOrNull;
    if (mine != null) {
      await _run((api) => api.setQueue(post.id, null).then((_) => post));
    } else {
      await _run((api) => api.like(post.id));
    }
  }

  Future<void> _pickQue(RasqAccountPost post, Rect anchor) => _hold(() => pickRasqQueue(context, ref, post, anchor: anchor, onRun: (f) => _run(f)));

  Future<void> _openThread() async {
    if (widget.onOpenThread case final open?) return open();
    return _openThreadFow();
  }

  Future<void> _openThreadFow() => _hold(() async {
        final manager = ref.read(overlayManagerProvider);
        if (manager.contains(SwingReplyBar.threadFowId)) return;
        await manager.showFow<void>(
          id: SwingReplyBar.threadFowId,
          semanticsLabel: 'Swing の返信',
          spec: FowSpec(type: FowPanelType.widget, initialHeightFactor: 0.72, minHeightFactor: 0.4, maxHeightFactor: 0.95),
          builder: (ctx, handle) => RasqPostScreen(key: ValueKey('swing.thread.$_postId'), postId: _postId, residentComposer: false, onClose: handle.close),
        );
        _refresh();
      });

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(rasqThreadProvider(_postId)).value;
    final post = thread?.post;
    final mine = post?.queues.where((q) => q.mine).firstOrNull;
    final replies = thread?.replies.length ?? widget.swing.replyCount;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ハンドル: 上に引くとスレッド(RASQ の投稿の詳細)の FOW。
      GestureDetector(
        key: const ValueKey('swing.reply.handle'),
        behavior: HitTestBehavior.opaque,
        onTap: _openThread,
        onVerticalDragUpdate: (d) => _drag += d.delta.dy,
        onVerticalDragEnd: (d) {
          final up = _drag < -24 || (d.primaryVelocity ?? 0) < -300;
          _drag = 0;
          if (up) _openThread();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.lg, RasqSpacing.xs, RasqSpacing.lg, RasqSpacing.sm),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(2))),
            if (replies > 0) ...[
              const SizedBox(width: RasqSpacing.sm),
              Text('返信 $replies', key: const ValueKey('swing.reply.count'), style: RasqTypography.caption.copyWith(color: Colors.white70)),
            ],
          ]),
        ),
      ),
      Row(mainAxisSize: MainAxisSize.min, children: [
        // stick の入力欄: 押すと返信のコンポーザーに。
        Material(
          color: Colors.black38,
          shape: const StadiumBorder(side: BorderSide(color: Colors.white38)),
          child: InkWell(
            key: const ValueKey('swing.reply.stick'),
            customBorder: const StadiumBorder(),
            onTap: post == null ? null : () => widget.onReply != null ? widget.onReply!() : _reply(post),
            child: Container(
              width: 200,
              height: 40,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md),
              child: Text('返信を送る…', style: RasqTypography.bodySmall.copyWith(color: Colors.white70)),
            ),
          ),
        ),
        const SizedBox(width: RasqSpacing.sm),
        // Que: 押すといいね(付けていれば外す)、長押しでキューのピッカー。
        Builder(
          builder: (ctx) => GestureDetector(
            onLongPress: post == null
                ? null
                : () {
                    final box = ctx.findRenderObject() as RenderBox;
                    _pickQue(post, box.localToGlobal(Offset.zero) & box.size);
                  },
            child: Material(
              color: mine != null ? RasqColors.accent : Colors.black38,
              shape: const CircleBorder(side: BorderSide(color: Colors.white38)),
              child: InkWell(
                key: const ValueKey('swing.reply.que'),
                customBorder: const CircleBorder(),
                onTap: post == null ? null : () => _que(post),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Tooltip(
                    message: 'Que(長押しで絵を選ぶ)',
                    triggerMode: TooltipTriggerMode.manual,
                    child: Icon(mine != null ? Icons.favorite : Icons.add_reaction_outlined, size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    ]);
  }
}

/// Swing の下に続くスレッド (D-413): 返信の数の帯 → 返信の一覧 → 返信の欄(RASQ アカウントとして、その Swing のスレッドへ。
/// 文字だけ、500 文字まで)。スレッドは Swing を見られる人だけに見える(Central S-058 が絞る)。書いている間は Swing を止める。
class SwingThreadSection extends ConsumerStatefulWidget {
  const SwingThreadSection({super.key, required this.swing, required this.onHold, this.focusNode, this.minHeight = 0});
  final Swing swing;
  final ValueChanged<bool> onHold;

  /// 返信の欄(左下の入力欄から入る)。
  final FocusNode? focusNode;

  /// 返信が少なくても、この高さまでは広げる(スクロールしきったときに Swing の下端が半端に残らないように)。
  final double minHeight;

  /// 返信の上限(RASQ の投稿と同じ)。
  static const maxChars = 500;

  @override
  ConsumerState<SwingThreadSection> createState() => _SwingThreadSectionState();
}

class _SwingThreadSectionState extends ConsumerState<SwingThreadSection> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  String get _postId => widget.swing.postId!;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _refresh() => ref.invalidate(rasqThreadProvider(_postId));

  Future<void> _send() async {
    final api = ref.read(rasqAccountPageApiProvider);
    final body = _text.text.trim();
    if (api == null || body.isEmpty || body.characters.length > SwingThreadSection.maxChars) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await api.reply(_postId, body);
      _text.clear();
      _refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '送れませんでした: ${e is OrgateException ? e.message : e}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final thread = ref.watch(rasqThreadProvider(_postId));
    final replies = thread.value?.replies ?? const <RasqAccountPost>[];
    final tooLong = _text.text.trim().characters.length > SwingThreadSection.maxChars;
    final muted = RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      key: const ValueKey('swing.thread'),
      constraints: BoxConstraints(minHeight: widget.minHeight),
      color: scheme.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 帯: 返信の数。
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, RasqSpacing.sm),
          child: Row(children: [
            Icon(Icons.forum_outlined, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.xs),
            Text('返信 ${thread.value?.replies.length ?? widget.swing.replyCount}', key: const ValueKey('swing.thread.count'), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        ...thread.when(
          loading: () => const [Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading())],
          error: (e, _) => [Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('読み込めませんでした: ${e is OrgateException ? e.message : e}', style: muted))],
          data: (_) => [
            if (replies.isEmpty) Padding(key: const ValueKey('swing.thread.empty'), padding: const EdgeInsets.all(RasqSpacing.page), child: Text('返信はまだありません。', style: muted)),
            for (final r in replies) ...[
              RasqPostTileView(key: ValueKey('swing.thread.reply.${r.id}'), post: r, onChanged: _refresh),
              Divider(height: 1, color: scheme.outlineVariant),
            ],
          ],
        ),
        // 返信の欄(Swing のスレッドへ)。
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.md),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                key: const ValueKey('swing.thread.input'),
                controller: _text,
                focusNode: widget.focusNode,
                enabled: !_busy,
                minLines: 1,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '返信を送る…',
                  errorText: tooLong ? '${SwingThreadSection.maxChars} 文字までです' : _error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
                ),
              ),
            ),
            const SizedBox(width: RasqSpacing.xs),
            RasqIconButton(
              key: const ValueKey('swing.thread.send'),
              icon: Icons.send,
              tooltip: '返信を送る',
              onPressed: _busy || tooLong || _text.text.trim().isEmpty ? null : _send,
            ),
          ]),
        ),
        SizedBox(height: MediaQuery.paddingOf(context).bottom),
      ]),
    );
  }
}
