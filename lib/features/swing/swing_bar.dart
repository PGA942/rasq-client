import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../backend/orgate_client.dart' show OrgateException;
import '../../backend/rasq_account_page_api.dart';
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart' show EmbeddedComposer;
import '../media/video_player.dart' show VideoSession, fmtDuration;
import '../profile/rasq_post_tile.dart' show RasqPostTileView, pickRasqQueue;
import 'swing_models.dart';

/// Swing のビューワーの下の **stick FOW** (D-420)。D-389 / D-413 の左下の欄(ハンドル + 「返信を送る…」+ Que)と
/// Swing の下に続くスレッドを、ビューワーのカラムの下端に付く 1 つの FOW にまとめた。
///
/// - **畳んだ形(stick)**: 上に**シークバー**(動画は再生位置で、引くと移る。テキスト / 画像は出しておく時間の進み。
///   プラグインは出さない)、下に**返信の欄**「返信を送る…」・**返信 N**・**キュー**。
/// - **返信の欄を押す** → FOW が**返信のコンポーザー**に変わる。中身は投稿の返信のコンポーザーと同じもの (D-421、
///   [EmbeddedComposer]: アクションバー・画像 / 動画(ピッカーとメディアエディター)・投票・注釈・絵文字・下書き)で、
///   返信先のタイルだけ、この Swing のタイル。送る / キャンセルで畳んだ形へ戻る。高さは中身に合わせる。
/// - **返信 N を押す / ハンドルを上へ引く / 空いたところを押す** → FOW が**スレッド**(返信の一覧 + 返信の欄)に広がる。
///   ハンドルを下へ引くと畳む。
/// - 広げている間(コンポーザー / スレッド)は Swing を止める。Swing の面は FOW の残りへ縮む(`FowAvoidingBox`)。
///   畳んだ形の間は、カラムに付いていれば D-397 の `FowStickPadding` がカラムごと縮め、全画面ならビューワーの面が寄る。
///
/// スレッド = Central S-058 の Swing の根の投稿(`visibility = swing`、Swing を見られる人だけが読める / 返信 / キューできる)。
class SwingBar {
  SwingBar._();

  /// FOW の id(ビューワーは同時に 1 つ)。
  static const fowId = 'swing.viewer.bar';

  /// 返信の上限(RASQ の投稿と同じ)。
  static const maxChars = 500;

  /// 畳んだ形の高さ(px): ハンドル + シークバーの段 + 返信の段 + 余白。
  static double compactHeight({required bool seek, required bool reply}) => kFowHandleHeight + (seek ? 30 : 0) + (reply ? 52 : 0) + 10;

  /// コンポーザーの高さ(px)の初めの見込み: ハンドル + コンポーザー(見出し + 返信先のタイル + 投稿先 + 入力欄 + アクションバー)。
  /// 開いたあとはコンポーザーが測った高さ([SwingBarController.composeHeight])にする (D-421)。
  static const composeHeight = kFowHandleHeight + 300.0;

  /// スレッドの高さ(カラムの高さに対して)。
  static const threadFactor = 0.62;
}

/// シークバーが読む再生の位置(テストで差し替える)。動画のセッションは [VideoSessionSeekable] で包む。
abstract interface class SwingSeekable implements Listenable {
  Duration get position;
  Duration get duration;

  /// 引いて移れる(読み込めた)か。
  bool get seekable;
  Future<void> seekTo(Duration d);
}

/// [VideoSession] をシークバーにつなぐ。
class VideoSessionSeekable implements SwingSeekable {
  VideoSessionSeekable(this.session);
  final VideoSession session;

  @override
  void addListener(VoidCallback l) => session.addListener(l);
  @override
  void removeListener(VoidCallback l) => session.removeListener(l);
  @override
  Duration get position => session.position;
  @override
  Duration get duration => session.duration;
  @override
  bool get seekable => session.ready && session.error == null && session.duration > Duration.zero;
  @override
  Future<void> seekTo(Duration d) => session.seekTo(d);
}

/// 動画の Swing の再生を差し替える(テスト: 本物の再生器を作らない)。null = 本物。
final swingVideoSeekOverrideProvider = Provider<SwingSeekable Function(Swing swing)?>((ref) => null);

/// FOW の形。
enum SwingBarMode { compact, compose, thread }

/// FOW の中身の状態。ビューワーが書き、FOW の本体([SwingViewerBar])が読む。
class SwingBarController extends ChangeNotifier {
  Swing? _swing;
  bool _reply = false;
  SwingSeekable? _video;
  Animation<double>? _clock;
  SwingBarMode _mode = SwingBarMode.compact;
  bool _disposed = false;
  double? _composeHeight;

  /// コンポーザーの形の高さ(px、ハンドル込み)。コンポーザーが測るまでは [SwingBar.composeHeight] (D-421)。
  double get composeHeight => _composeHeight ?? SwingBar.composeHeight;

  /// コンポーザーが測った中身の高さ(px、ハンドルは含まない)。
  void setComposeContentHeight(double px) {
    final h = kFowHandleHeight + px;
    if (_composeHeight != null && (h - _composeHeight!).abs() < 0.5) return;
    _composeHeight = h;
    if (_mode == SwingBarMode.compose) _notify();
  }

  /// 止める / 戻す(理由ごと。ビューワーの `_hold`)。
  void Function(String reason, bool hold)? onHold;

  Swing? get swing => _swing;

  /// 返信の欄・返信 N・キューを出す(根の投稿があり、覆っておらず、RASQ アカウントで読める)。
  bool get reply => _reply;

  /// 動画の再生(動画の Swing で、再生器ができていれば)。
  SwingSeekable? get video => _video;

  /// 出しておく時間の進み(テキスト / 画像)。
  Animation<double>? get clock => _clock;
  SwingBarMode get mode => _mode;

  /// シークバーを出すか(プラグインは出さない)。
  bool get hasSeek => _swing != null && _swing!.kind != SwingKind.plugin;

  /// 何か出すものがあるか(無ければ FOW を出さない)。
  bool get hasContent => _swing != null && (hasSeek || _reply);

  /// いまの Swing を書く。Swing が替わったら畳む。
  void show({required Swing? swing, required bool reply, SwingSeekable? video, Animation<double>? clock}) {
    final changed = swing?.id != _swing?.id;
    if (!changed && reply == _reply && identical(video, _video) && identical(clock, _clock)) return;
    _swing = swing;
    _reply = reply;
    _video = video;
    _clock = clock;
    if (changed || !reply) _mode = SwingBarMode.compact;
    if (changed) _composeHeight = null;
    _notify();
  }

  void setMode(SwingBarMode m) {
    if (m == _mode) return;
    if (m != SwingBarMode.compact && !_reply) return;
    _mode = m;
    _notify();
  }

  void hold(String reason, bool v) => onHold?.call(reason, v);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// FOW の本体。
class SwingViewerBar extends ConsumerStatefulWidget {
  const SwingViewerBar({super.key, required this.controller, this.spec});
  final SwingBarController controller;

  /// この FOW の形(コンポーザーの子 FOW = 絵文字 / MFM ピッカーを避ける余白とカラムに使う)。
  final FowSpec? spec;

  @override
  ConsumerState<SwingViewerBar> createState() => _SwingViewerBarState();
}

class _SwingViewerBarState extends ConsumerState<SwingViewerBar> {
  SwingBarController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_changed);
  }

  @override
  void didUpdateWidget(SwingViewerBar old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    _c.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    // 別の Swing へ移ったら、コンポーザーは作り直す(鍵が Swing ごと。書きかけは投稿のコンポーザーと同じく下書きに残る)。
    setState(() {});
  }

  String? get _postId => _c.swing?.postId;

  void _refresh() {
    final id = _postId;
    if (id != null) ref.invalidate(rasqThreadProvider(id));
  }

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

  /// キュー: 押すと いいね(付けていれば外す)。
  Future<void> _que(RasqAccountPost post) async {
    final mine = post.queues.where((q) => q.mine).firstOrNull;
    if (mine != null) {
      await _run((api) => api.setQueue(post.id, null).then((_) => post));
    } else {
      await _run((api) => api.like(post.id));
    }
  }

  /// 長押し: キューのピッカー(投稿のタイルと共通)。選んでいる間は止める。
  Future<void> _pickQue(RasqAccountPost post, Rect anchor) async {
    _c.hold('queue', true);
    try {
      await pickRasqQueue(context, ref, post, anchor: anchor, onRun: _run);
    } finally {
      _c.hold('queue', false);
    }
  }

  /// コンポーザーの形へ(入力欄はコンポーザーが自分でフォーカスする)。
  void _compose() => _c.setMode(SwingBarMode.compose);

  @override
  Widget build(BuildContext context) {
    final s = _c.swing;
    if (s == null) return const SizedBox.shrink();
    return switch (_c.mode) {
      SwingBarMode.compact => _compact(s),
      SwingBarMode.compose => _composer(s),
      SwingBarMode.thread => _thread(s),
    };
  }

  // ── 畳んだ形 ──

  Widget _compact(Swing s) {
    final reply = _c.reply;
    return ClipRect(
      key: const ValueKey('swing.bar.compact'),
      child: SingleChildScrollView(
        // 形が替わる途中(高さのアニメーション)ではみ出しても崩さない。
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.sm, RasqSpacing.xs),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_c.hasSeek) SizedBox(height: 30, child: _seekBar(s)),
          if (reply) SizedBox(height: 52, child: _replyRow(s, showCount: true)),
        ]),
      ),
    );
  }

  /// シークバー: 動画は再生位置(引くと移る)、テキスト / 画像は出しておく時間の進み。
  Widget _seekBar(Swing s) {
    final scheme = Theme.of(context).colorScheme;
    final video = _c.video;
    if (s.kind == SwingKind.video) {
      if (video == null) {
        return Center(child: LinearProgressIndicator(key: const ValueKey('swing.seek.loading'), minHeight: 2, value: 0, backgroundColor: scheme.outlineVariant));
      }
      return ListenableBuilder(
        listenable: video,
        builder: (context, _) {
          final total = video.duration;
          final pos = video.position;
          final v = total.inMilliseconds <= 0 ? 0.0 : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);
          return Row(children: [
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: RasqColors.link,
                  inactiveTrackColor: scheme.outlineVariant,
                  thumbColor: RasqColors.link,
                ),
                child: Slider(
                  key: const ValueKey('swing.seek'),
                  value: v,
                  semanticFormatterCallback: (_) => '${fmtDuration(pos)} / ${fmtDuration(total)}',
                  onChangeStart: video.seekable ? (_) => _c.hold('seek', true) : null,
                  onChangeEnd: video.seekable ? (_) => _c.hold('seek', false) : null,
                  onChanged: video.seekable ? (x) => video.seekTo(Duration(milliseconds: (total.inMilliseconds * x).round())) : null,
                ),
              ),
            ),
            Text('${fmtDuration(pos)} / ${fmtDuration(total)}', key: const ValueKey('swing.seek.time'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]);
        },
      );
    }
    final clock = _c.clock;
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: RasqSpacing.sm),
        child: clock == null
            ? LinearProgressIndicator(key: const ValueKey('swing.progress'), value: 0, minHeight: 3, color: RasqColors.link, backgroundColor: scheme.outlineVariant)
            : AnimatedBuilder(
                animation: clock,
                builder: (_, _) => LinearProgressIndicator(key: const ValueKey('swing.progress'), value: clock.value, minHeight: 3, color: RasqColors.link, backgroundColor: scheme.outlineVariant),
              ),
      ),
    );
  }

  /// 返信の欄(押すとコンポーザー)+ 返信 N + キュー。
  Widget _replyRow(Swing s, {required bool showCount}) {
    final scheme = Theme.of(context).colorScheme;
    final id = s.postId!;
    final thread = ref.watch(rasqThreadProvider(id)).value;
    final post = thread?.post;
    final mine = post?.queues.where((q) => q.mine).firstOrNull;
    final replies = thread?.replies.length ?? s.replyCount;
    return Row(children: [
      Expanded(
        child: Material(
          color: scheme.surfaceContainerHighest,
          shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
          child: InkWell(
            key: const ValueKey('swing.reply.stick'),
            customBorder: const StadiumBorder(),
            onTap: _compose,
            child: Container(
              height: 40,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md),
              child: Text('返信を送る…', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
      if (showCount)
        TextButton.icon(
          key: const ValueKey('swing.reply.count'),
          onPressed: () => _c.setMode(SwingBarMode.thread),
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: Text('返信 $replies'),
        )
      else
        const SizedBox(width: RasqSpacing.sm),
      // キュー: 押すと いいね(付けていれば外す)、長押しでキューのピッカー。
      Builder(
        builder: (ctx) => GestureDetector(
          onLongPress: post == null
              ? null
              : () {
                  final box = ctx.findRenderObject() as RenderBox;
                  _pickQue(post, box.localToGlobal(Offset.zero) & box.size);
                },
          child: Material(
            color: mine != null ? RasqColors.accent : scheme.surfaceContainerHighest,
            shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
            child: InkWell(
              key: const ValueKey('swing.reply.que'),
              customBorder: const CircleBorder(),
              onTap: post == null ? null : () => _que(post),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Tooltip(
                  message: 'キュー(長押しで絵を選ぶ)',
                  triggerMode: TooltipTriggerMode.manual,
                  child: Icon(mine != null ? Icons.favorite : Icons.add_reaction_outlined, size: 20, color: mine != null ? Colors.white : scheme.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── 返信のコンポーザー ──

  /// 投稿の返信のコンポーザーと同じ中身 (D-421)。返信先 = この Swing のスレッドの根の投稿。添付 / 投票も付けられる(Central S-076)。
  Widget _composer(Swing s) {
    final composer = EmbeddedComposer(
      key: ValueKey('swing.bar.composer.${s.id}'),
      target: ComposeReply(swingRootPost(s)),
      targetPreview: SwingReplyTargetTile(key: const ValueKey('swing.bar.replyTile'), swing: s),
      rasqReplyAttachments: true,
      ownerId: SwingBar.fowId,
      hostSpec: widget.spec,
      onFitHeight: _c.setComposeContentHeight,
      onClose: () => _c.setMode(SwingBarMode.compact),
      onSent: (_) {
        _refresh();
        // 送ったら畳んだ形へ戻る(Swing の大きさも戻る)。
        _c.setMode(SwingBarMode.compact);
      },
    );
    // 高さのアニメーション(畳んだ形 → コンポーザー)の途中で低くても崩さない。木の形は変えない(コンポーザーを作り直さない)。
    return LayoutBuilder(
      key: const ValueKey('swing.bar.composer'),
      builder: (context, box) {
        final h = box.maxHeight.isFinite ? (box.maxHeight < 160 ? 160.0 : box.maxHeight) : 400.0;
        return ClipRect(child: OverflowBox(alignment: Alignment.topCenter, minHeight: h, maxHeight: h, child: composer));
      },
    );
  }

  // ── スレッド ──

  Widget _thread(Swing s) {
    final scheme = Theme.of(context).colorScheme;
    final id = s.postId!;
    final thread = ref.watch(rasqThreadProvider(id));
    final replies = thread.value?.replies ?? const <RasqAccountPost>[];
    final muted = RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant);
    // 高さのアニメーション(畳んだ形 → スレッド)の途中では、低いぶんを切って崩さない。
    return LayoutBuilder(
      builder: (context, box) => box.maxHeight >= 200
          ? _threadColumn(s, thread, replies, muted)
          : ClipRect(child: OverflowBox(alignment: Alignment.topCenter, minHeight: 200, maxHeight: 200, child: _threadColumn(s, thread, replies, muted))),
    );
  }

  Widget _threadColumn(Swing s, AsyncValue<RasqThread> thread, List<RasqAccountPost> replies, TextStyle muted) {
    final scheme = Theme.of(context).colorScheme;
    return Column(key: const ValueKey('swing.thread'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.sm, 0),
        child: Row(children: [
          Icon(Icons.forum_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: RasqSpacing.xs),
          Text('返信 ${thread.value?.replies.length ?? s.replyCount}', key: const ValueKey('swing.thread.count'), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          RasqIconButton(key: const ValueKey('swing.thread.close'), icon: Icons.expand_more, tooltip: '返信をしまう', onPressed: () => _c.setMode(SwingBarMode.compact)),
        ]),
      ),
      Divider(height: 1, color: scheme.outlineVariant),
      Expanded(
        child: ListView(
          key: const ValueKey('swing.thread.list'),
          padding: EdgeInsets.zero,
          children: thread.when(
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
        ),
      ),
      Divider(height: 1, color: scheme.outlineVariant),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.xs),
        child: SizedBox(height: 48, child: _replyRow(s, showCount: false)),
      ),
    ]);
  }
}

/// Swing のスレッドの根の投稿を、返信のコンポーザーの返信先 ([ComposeReply]) にする形 (D-421)。RASQ の投稿として扱われる
/// (`isRasqPost`: 投稿先は RASQ に固定)。注釈は Swing の注釈(投稿の返信と同じく、返信にも引き継ぐ)。
Post swingRootPost(Swing s) => Post(
      id: s.postId ?? '',
      account: AccountId(kind: SnsKind.other, instance: rasqPostInstance, handle: s.author.account.handle),
      author: s.author,
      createdAt: s.createdAt,
      body: s.text,
      contentWarning: s.cw,
      visibility: 'swing',
    );

/// 返信先のタイル: 返信する Swing(作った人・中身の種類・添えた文 / 画像)。投稿の返信の「返信先」と同じ位置づけ。
class SwingReplyTargetTile extends StatelessWidget {
  const SwingReplyTargetTile({super.key, required this.swing});
  final Swing swing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = swing;
    final summary = switch (s.kind) {
      SwingKind.text => s.text,
      SwingKind.image => s.text.isEmpty ? '画像の Swing' : s.text,
      SwingKind.video => s.text.isEmpty ? '動画の Swing' : s.text,
      SwingKind.plugin => 'プラグインの Swing',
    };
    final icon = switch (s.kind) {
      SwingKind.text => Icons.notes,
      SwingKind.image => Icons.image_outlined,
      SwingKind.video => Icons.movie_outlined,
      SwingKind.plugin => Icons.extension_outlined,
    };
    final url = s.mediaUrl;
    return Container(
      height: 64,
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
        border: Border(left: BorderSide(color: RasqColors.link, width: 3)),
      ),
      child: Row(children: [
        RasqAvatar(imageUrl: s.author.avatarUrl, size: 32, fallbackLabel: s.author.displayName),
        const SizedBox(width: RasqSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('${s.author.displayName} の Swing', style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(children: [
              Icon(icon, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(child: Text(summary, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        ),
        if (s.kind == SwingKind.image && url != null) ...[
          const SizedBox(width: RasqSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
            child: Image.network(url.toString(), width: 44, height: 44, fit: BoxFit.cover, webHtmlElementStrategy: rasqWebImageStrategy, errorBuilder: (_, _, _) => const SizedBox(width: 44, height: 44)),
          ),
        ],
      ]),
    );
  }
}
