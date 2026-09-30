import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart' show centralBaseUrlProvider;
import '../../backend/rasq_account_page_api.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../profile/rasq_post_screen.dart';
import '../profile/rasq_post_tile.dart' show pickRasqQueue;
import 'swing_models.dart';

/// Swing の返信とキュー (D-389 / Central S-058)。ビューワーの**左下**に置く。
///
/// - **stick の入力欄**「返信を送る…」: 押すと返信のコンポーザーに変わる(RASQ アカウントとして、その Swing のスレッドへ返信)。
/// - **Que ボタン**: 押すと、いいね(付けていれば外す)。長押しでキューのピッカー(アセットパックの絵)。
/// - **ハンドル**(入力欄の上): 上に引く(か押す)と、Swing のスレッド = RASQ の投稿の詳細が **FOW** で開く。
/// - どれかを開いている間は、Swing を止める([onHold])。スレッドは Swing を見られる人だけに見える(Central が絞る)。
class SwingReplyBar extends ConsumerStatefulWidget {
  const SwingReplyBar({super.key, required this.swing, required this.onHold});
  final Swing swing;

  /// true = 止める(コンポーザー / ピッカー / FOW を開いた)、false = 戻す。
  final ValueChanged<bool> onHold;

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

  Future<void> _openThread() => _hold(() async {
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
            onTap: post == null ? null : () => _reply(post),
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
