import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../backend/orgate_client.dart' show OrgateException, centralBaseUrlProvider;
import '../../backend/rasq_account_page_api.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart' show EmbeddedComposer;
import '../media/video_player.dart' show VideoSession, fmtDuration;
import '../profile/rasq_post_tile.dart' show RasqPostTileView, pickRasqQueue;
import 'swing_models.dart';
import '../../l10n/l10n.dart';

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
///
/// D-424: **返信への返信**もこの FOW の中で。スレッドの返信のタイルの「返信 N 件を見る」/ タイルを押すと、その返信のスレッド
/// (上に返信そのもの、下にその返信への返信)へ**入り**、ヘッダーの ← で 1 つ戻る(何段でも)。タイルの「返信」ボタン / 下の返信の欄は、
/// いま開いている返信への返信のコンポーザー(返信先のタイル = その返信)。返信への返信も Swing のスレッドの中なので、添付 / 投票 / 注釈を
/// 付けられる(Central S-076 / S-079)。スレッドから書き始めたら、送る / やめるでスレッドへ戻る。
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

  /// 開いている返信のスレッド(根 → 深い順、D-424)。空 = Swing のスレッド。
  final List<RasqAccountPost> _trail = [];

  /// コンポーザーの返信先(null = Swing の根の投稿、D-424)。
  RasqAccountPost? _replyTo;

  /// コンポーザーを閉じたら戻る形(スレッドから書き始めたらスレッド、D-424)。
  SwingBarMode _composeReturn = SwingBarMode.compact;

  /// 開いている返信(null = Swing のスレッド)。
  RasqAccountPost? get openReply => _trail.isEmpty ? null : _trail.last;

  /// 入った深さ(0 = Swing のスレッド)。
  int get depth => _trail.length;

  /// コンポーザーの返信先(null = Swing の根の投稿)。
  RasqAccountPost? get replyTo => _replyTo;

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
    if (changed) {
      _composeHeight = null;
      _trail.clear();
      _replyTo = null;
      _composeReturn = SwingBarMode.compact;
    }
    _notify();
  }

  void setMode(SwingBarMode m) {
    if (m == _mode) return;
    if (m != SwingBarMode.compact && !_reply) return;
    _mode = m;
    // 畳んだら、入っていた返信のスレッドからも出る(次に広げると Swing のスレッド)。
    if (m == SwingBarMode.compact) {
      _trail.clear();
      _replyTo = null;
    }
    if (m != SwingBarMode.compose) _replyTo = null;
    _notify();
  }

  /// 返信のスレッドへ入る (D-424)。スレッドの形にする。
  void openReplies(RasqAccountPost post) {
    if (!_reply) return;
    if (openReply?.id == post.id) return;
    _trail.add(post);
    if (_mode != SwingBarMode.thread) _mode = SwingBarMode.thread;
    _notify();
  }

  /// 1 つ戻る (D-424)。
  void back() {
    if (_trail.isEmpty) return;
    _trail.removeLast();
    _notify();
  }

  /// コンポーザーにする。[to] = 返信先の返信(null = Swing の根の投稿、D-424)。閉じたら、いまの形(スレッド / 畳んだ形)へ戻る。
  void compose({RasqAccountPost? to}) {
    if (!_reply) return;
    if (_mode != SwingBarMode.compose) _composeReturn = _mode;
    final changed = _replyTo?.id != to?.id;
    _replyTo = to;
    if (changed) _composeHeight = null;
    if (_mode == SwingBarMode.compose) {
      if (changed) _notify();
      return;
    }
    _mode = SwingBarMode.compose;
    _notify();
  }

  /// コンポーザーを閉じる(送った / やめた)。書き始めた形へ戻る。
  void endCompose() {
    final back = _composeReturn;
    _composeReturn = SwingBarMode.compact;
    setMode(back);
    _replyTo = null;
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

  /// Swing のスレッドと、開いている / 返信先の返信のスレッドを取り直す。
  void _refresh() {
    for (final id in {_postId, _c.openReply?.id, _c.replyTo?.id, for (final r in _c._trail) r.id}) {
      if (id != null) ref.invalidate(rasqThreadProvider(id));
    }
  }

  Future<void> _run(Future<RasqAccountPost> Function(RasqAccountPageApi api) f) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null) return;
    try {
      await f(api);
    } catch (e) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(context.l10n.swingActionFailed('$e'))));
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

  /// コンポーザーの形へ(入力欄はコンポーザーが自分でフォーカスする)。スレッドで返信に入っていれば、その返信への返信。
  void _compose() => _c.compose(to: _c.mode == SwingBarMode.thread ? _c.openReply : null);

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
    // 返信のスレッドに入っていれば、その返信への返信 (D-424)。
    final open = showCount ? null : _c.openReply;
    final hint = open == null ? context.l10n.swingReplyHint : context.l10n.swingReplyToHint(open.author?.handle ?? '');
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
              child: Text(hint, key: const ValueKey('swing.reply.hint'), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
        ),
      ),
      if (showCount)
        TextButton.icon(
          key: const ValueKey('swing.reply.count'),
          onPressed: () => _c.setMode(SwingBarMode.thread),
          icon: const Icon(Icons.forum_outlined, size: 18),
          label: Text(context.l10n.swingReplyCount(replies)),
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
                  message: context.l10n.swingQueueTooltip,
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

  /// 投稿の返信のコンポーザーと同じ中身 (D-421)。返信先 = この Swing のスレッドの根の投稿、または返信 (D-424)。
  /// 添付 / 投票も付けられる(Central S-076: 返信先が Swing のスレッドの投稿なら、返信への返信も)。
  Widget _composer(Swing s) {
    final to = _c.replyTo;
    final composer = EmbeddedComposer(
      key: ValueKey('swing.bar.composer.${s.id}.${to?.id ?? 'root'}'),
      target: ComposeReply(to == null ? swingRootPost(s) : to.toPost(central: ref.read(centralBaseUrlProvider))),
      targetPreview: to == null ? SwingReplyTargetTile(key: const ValueKey('swing.bar.replyTile'), swing: s) : SwingReplyTargetPostTile(key: const ValueKey('swing.bar.replyTile'), post: to),
      rasqReplyAttachments: true,
      ownerId: SwingBar.fowId,
      hostSpec: widget.spec,
      onFitHeight: _c.setComposeContentHeight,
      onClose: _c.endCompose,
      onSent: (_) {
        _refresh();
        // 送ったら書き始めた形へ戻る(畳んだ形からなら Swing の大きさも戻る。スレッドからならスレッドで自分の返信が見える)。
        _c.endCompose();
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
    // 返信のスレッドに入っていればその返信 (D-424)、いなければ Swing の根の投稿。
    final id = _c.openReply?.id ?? s.postId!;
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
    final open = _c.openReply;
    final count = thread.value?.replies.length ?? open?.replyCount ?? s.replyCount;
    // 入っている返信(取り直したものがあればそれ)。
    final focus = open == null ? null : (thread.value?.post ?? open);
    // チャイルドセーフ (D-454、セキュリティ確認 2026-10-09 の [9]): 投稿の詳細と同じく、見守りの時間に詳細を開かせない設定 /
    // 見せない投稿(入っている返信、根なら Swing の投稿)なら、スレッドの中身を出さない。返信は rasqThreadProvider で外してある。
    final childBlocked = rasqPostDetailBlockReason(ref.watch(childGateProvider), focus ?? thread.value?.post);
    return Column(key: const ValueKey('swing.thread'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(open == null ? RasqSpacing.page : RasqSpacing.xs, 0, RasqSpacing.sm, 0),
        child: Row(children: [
          if (open == null)
            Icon(Icons.forum_outlined, size: 18, color: scheme.onSurfaceVariant)
          else
            RasqIconButton(key: const ValueKey('swing.thread.back'), icon: Icons.arrow_back, tooltip: _c.depth > 1 ? context.l10n.swingThreadBackReply : context.l10n.swingThreadBackSwing, onPressed: _c.back),
          const SizedBox(width: RasqSpacing.xs),
          Flexible(
            child: Text(
              open == null ? context.l10n.swingReplyCount(count) : context.l10n.swingRepliesTo(open.author?.handle ?? '', count),
              key: const ValueKey('swing.thread.count'),
              style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          RasqIconButton(key: const ValueKey('swing.thread.close'), icon: Icons.expand_more, tooltip: context.l10n.swingThreadClose, onPressed: () => _c.setMode(SwingBarMode.compact)),
        ]),
      ),
      Divider(height: 1, color: scheme.outlineVariant),
      Expanded(
        child: ListView(
          key: const ValueKey('swing.thread.list'),
          padding: EdgeInsets.zero,
          children: childBlocked != null
              ? [Padding(key: const ValueKey('childSafe.postHidden'), padding: const EdgeInsets.all(RasqSpacing.page), child: Text(childBlocked, style: muted))]
              : thread.when(
            loading: () => const [Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading())],
            error: (e, _) => [Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(context.l10n.swingLoadFailed(e is OrgateException ? e.message : '$e'), style: muted))],
            data: (_) => [
              // 入っている返信そのもの(主役)。その下に、その返信への返信 (D-424)。
              if (focus != null) ...[
                RasqPostTileView(key: ValueKey('swing.thread.focus.${focus.id}'), post: focus, focused: true, onChanged: _refresh, onReply: () => _c.compose(to: focus)),
                Divider(height: 1, color: scheme.outlineVariant),
              ],
              if (replies.isEmpty) Padding(key: const ValueKey('swing.thread.empty'), padding: const EdgeInsets.all(RasqSpacing.page), child: Text(context.l10n.swingNoReplies, style: muted)),
              for (final r in replies) ...[
                // タイルを押す / 「返信 N 件を見る」= その返信のスレッドへ。「返信」ボタン = その返信への返信(この FOW のコンポーザー)。
                RasqPostTileView(key: ValueKey('swing.thread.reply.${r.id}'), post: r, onChanged: _refresh, onOpen: () => _c.openReplies(r), onReply: () => _c.compose(to: r)),
                if (r.replyCount > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: RasqSpacing.page + 36, bottom: RasqSpacing.xs),
                      child: TextButton.icon(
                        key: ValueKey('swing.thread.open.${r.id}'),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => _c.openReplies(r),
                        icon: const Icon(Icons.subdirectory_arrow_right, size: 16),
                        label: Text(context.l10n.swingViewReplies(r.replyCount)),
                      ),
                    ),
                  ),
                Divider(height: 1, color: scheme.outlineVariant),
              ],
            ],
          ),
        ),
      ),
      if (childBlocked == null) ...[
        Divider(height: 1, color: scheme.outlineVariant),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.xs),
          child: SizedBox(height: 48, child: _replyRow(s, showCount: false)),
        ),
      ],
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

/// 返信先のタイル (D-424): Swing のスレッドの返信へ返信するとき。返信した人と本文(添付 / 投票があればそのしるし)。
class SwingReplyTargetPostTile extends StatelessWidget {
  const SwingReplyTargetPostTile({super.key, required this.post});
  final RasqAccountPost post;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = post;
    final who = p.author?.label ?? '';
    final summary = p.body.trim().isNotEmpty ? p.body.trim() : (p.images.isNotEmpty ? context.l10n.swingAttachments(p.images.length) : (p.poll != null ? context.l10n.swingPoll : ''));
    return Container(
      height: 64,
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
        border: Border(left: BorderSide(color: RasqColors.link, width: 3)),
      ),
      child: Row(children: [
        RasqAvatar(imageUrl: p.author?.avatarUrl, size: 32, fallbackLabel: who),
        const SizedBox(width: RasqSpacing.sm),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(context.l10n.swingReplyOf(who), style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
            Row(children: [
              Icon(Icons.reply, size: 14, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Expanded(child: Text(summary, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

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
      SwingKind.image => s.text.isEmpty ? context.l10n.swingImageSwing : s.text,
      SwingKind.video => s.text.isEmpty ? context.l10n.swingVideoSwing : s.text,
      SwingKind.plugin => context.l10n.swingPluginSwing,
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
            Text(context.l10n.swingOf(s.author.displayName), style: RasqTypography.caption.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
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
