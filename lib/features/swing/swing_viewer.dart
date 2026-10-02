import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/router.dart';
import '../../shell/third_column.dart' show openPageInPanes, paneBack;
import '../ads/ad_placement.dart';
import '../ads/export_ad.dart';
import '../vc/astell_models.dart' show astellReportReasons;
import '../custom/custom_page.dart';
import '../media/video_player.dart';
import '../plugins/slot_plugins.dart';
import 'swing_models.dart';
import 'swing_providers.dart';
import 'swing_reply.dart';
import '../../backend/rasq_account_page_api.dart' show rasqAccountPageApiProvider;

/// Swing のビューワー (D-377 / D-379)。全画面、**左右のスワイプ**で次 / 前の Swing(と広告)へ。マウス / トラックパッドの
/// ドラッグでも動く(Mac 版で縦のスワイプが効かなかった)。
///
/// - 並びは [swingViewerQueue](押した人の Swing → ほかの人の見ていないもの)。開いた時点のフィードで並べる。
/// - **時間で次へ**: テキスト / 画像は [displayDuration]、動画は終わったら。プラグインと広告は自分では進まない。
///   **中央をタップで一時停止 / 再開**、左端 / 右端のタップで前 / 次。
/// - **見終えた** = その Swing を離れた / 閉じた / プラグインが `page.end` を呼んだ。Central へ送る(ヘッダーのリングが白になる)。
/// - **広告**: Swing [adEvery] 個ごとに 1 枚(広告を出せる端末とアカウントだけ。出せなければ挟まない)。広告は見終えの記録なし。
///   D-395: **`adSafe` でない Swing(通報された / CW / センシティブ / 未審査のプラグイン / 運営が止めた)の前後には置かない**
///   ([adGaps]。予定の所が危なければ次の安全な所へずらす)。
/// - **CW / センシティブ** (D-395): ぼかして覆い、「表示する」を押すまで中身を出さない。覆っている間は時計を回さず、
///   動画 / プラグインも動かさない。
/// - **通報** (D-395): ヘッダーの旗から理由を選んで `POST /reports {swingId}`。通報した Swing はこの回の間、広告の隣に置かない
///   扱いにする(並びは開いた時点で決めているので、記録するだけ)。
/// - **プラグイン**(ページ型、surface `swing`、契約 v0.19): 全画面で動かし、その間は**スワイプで移れない**。
///   「全画面から縮小」を押すと、ぼかして止め(`page.event paused`)、スワイプで移れるようにする。縮小したものを押すと
///   全画面に戻る(`resumed`)。
///
/// D-413: **幅の広い画面では第3カラム**に開く([openSwingViewer]。狭い画面は前のとおり全画面)。**Swing の下に返信が続く**
/// (D-389 のスレッド = 返信の一覧と返信の欄。下へスクロールすると出る。左下の欄のハンドル / 入力欄もそこへ送る)。
///
/// D-410: [mine] = **自分の Swing**(ヘッダーの自分の顔から)。`GET /me/swings` の並び(古い順)で、広告・見終えの記録・
/// 通報は無し、作った人だけが見られる**見た人の数**(`viewCount`)を出す。
class SwingViewerScreen extends ConsumerStatefulWidget {
  const SwingViewerScreen({super.key, this.startAuthor, this.mine = false});

  /// 作った人の accountId。
  final String? startAuthor;

  /// 自分の Swing を見る (D-410)。
  final bool mine;

  static const adEvery = 5;

  /// テキスト / 画像を出しておく時間(テストで null = 時間では進まない)。
  static Duration? displayDuration = const Duration(seconds: 6);

  @override
  ConsumerState<SwingViewerScreen> createState() => _SwingViewerScreenState();
}

/// 第3カラムに開いた回数(同じ人を開き直したら、並びを作り直す)。
int _paneSerial = 0;

/// Swing のビューワーを開く (D-413): 幅の広い画面では**第3カラム**(第3カラムのページは第2カラムへ移る、D-057)、
/// 狭い画面は前のとおり全画面のルート。[mine] = 自分の Swing (D-410)。
void openSwingViewer(BuildContext context, {String? author, bool mine = false}) {
  final id = 'swing:${mine ? 'me' : author ?? ''}#${++_paneSerial}';
  if (openPageInPanes(
    context,
    id: id,
    title: 'Swing',
    location: Routes.swingInHome(author: author, mine: mine),
    builder: (_) => SwingViewerScreen(key: ValueKey(id), startAuthor: author, mine: mine),
  )) {
    return;
  }
  context.push(mine ? Routes.mySwings : Routes.swing(author));
}

/// 1 ページ = Swing か広告。
@immutable
class SwingViewerItem {
  const SwingViewerItem.swing(Swing this.swing) : ad = false;
  const SwingViewerItem.ad()
      : swing = null,
        ad = true;
  final Swing? swing;
  final bool ad;
}

/// Swing の並びに広告を挟む([every] 個ごと、最後には付けない)。`adSafe` でない Swing の前後には置かない ([adGaps]、D-395)。
List<SwingViewerItem> interleaveAds(List<Swing> swings, {required bool ads, int every = SwingViewerScreen.adEvery}) {
  final gaps = ads ? adGaps(swings.length, (i) => swings[i].adSafe, every: every).toSet() : const <int>{};
  return [
    for (var i = 0; i < swings.length; i++) ...[
      if (gaps.contains(i)) const SwingViewerItem.ad(),
      SwingViewerItem.swing(swings[i]),
    ],
  ];
}

class _SwingViewerScreenState extends ConsumerState<SwingViewerScreen> with SingleTickerProviderStateMixin {
  late final List<SwingViewerItem> _items;
  late final PageController _pages;
  late final AnimationController _clock = AnimationController(vsync: this)..addStatusListener(_onClock);
  int _index = 0;

  /// いまのプラグインが全画面で動いている(スワイプで移れない)。
  bool _locked = false;

  /// 中央のタップで止めている。
  bool _paused = false;

  /// 止めている理由 (D-389 / D-413): 返信のコンポーザー / キューのピッカー(`reply`)、下の返信を読んでいる(`thread`)、通報の理由を
  /// 選んでいる(`report`)。どれかがあれば止める。
  final _holds = <String>{};
  bool get _held => _holds.isNotEmpty;

  /// 閉じる / 移るで見終えを送ったか(カラムから外されたときに送る、D-413)。
  bool _closed = false;
  late final SwingFeed _feed;

  /// 「表示する」を押した CW / センシティブの Swing (D-395)。
  final _revealed = <String>{};

  /// この回で通報した Swing (D-395)。広告の隣に置かない扱い(並びは開いた時点のままなので、記録だけ)。
  final _reported = <String>{};

  bool _coveredNow(Swing s) => s.covered && !_revealed.contains(s.id);

  void _reveal(Swing s) {
    setState(() => _revealed.add(s.id));
    if (_current?.id == s.id) _startClock();
  }

  /// 通報 (D-395): 理由を選んで `POST /reports {swingId}`。選んでいる間は止める。
  Future<void> _report(Swing s) async {
    final api = ref.read(swingApiProvider);
    if (api == null) return;
    _hold('report', true);
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text('${s.author.displayName} の Swing を通報します。RASQ の審査で確認します。', style: RasqTypography.bodySmall)),
          for (final r in astellReportReasons)
            ListTile(key: ValueKey('swing.report.${r.id}'), title: Text(r.label), onTap: () => Navigator.of(ctx).pop(r.id)),
        ]),
      ),
    );
    if (!mounted) return;
    _hold('report', false);
    if (reason == null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await api.report(s.id, reason: reason);
      _reported.add(s.id);
      messenger?.showSnackBar(const SnackBar(content: Text('通報しました。審査で確認します')));
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('通報できませんでした: $e')));
    }
  }

  void _hold(String reason, bool v) {
    if (!mounted || _holds.contains(reason) == v) return;
    final was = _held;
    setState(() => v ? _holds.add(reason) : _holds.remove(reason));
    if (was == _held) return;
    if (_held) {
      _clock.stop();
    } else if (!_paused && _clock.duration != null && _clock.value > 0 && _clock.value < 1) {
      _clock.forward();
    }
  }

  @override
  void initState() {
    super.initState();
    _feed = ref.read(swingFeedProvider.notifier);
    final feed = widget.mine
        ? ([...?ref.read(mySwingsProvider).value]..sort((a, b) => a.createdAt.compareTo(b.createdAt)))
        : swingViewerQueue(ref.read(swingFeedProvider).value ?? const [], startAuthor: widget.startAuthor);
    final ads = !widget.mine && ref.read(exportAdNetworkProvider) != null && ref.read(exportAdAllowedProvider);
    _items = interleaveAds(feed, ads: ads);
    _pages = PageController(initialPage: _index);
    _startClock();
  }

  @override
  void dispose() {
    // カラムから外された(第3カラムに別のページを開いた など)ときも、見ていたものは見終えにする (D-413)。
    final s = _closed || _index >= _items.length ? null : _items[_index].swing;
    if (s != null && !widget.mine) unawaited(_feed.markSeen(s.id));
    _clock.dispose();
    _pages.dispose();
    super.dispose();
  }

  /// 時間で進むもの(テキスト / 画像)だけ、時計を回す。
  void _startClock() {
    _clock.stop();
    _clock.value = 0;
    final s = _index < _items.length ? _items[_index].swing : null;
    final d = SwingViewerScreen.displayDuration;
    if (s == null || d == null || !(s.kind == SwingKind.text || s.kind == SwingKind.image) || _coveredNow(s)) return;
    _clock.duration = d;
    if (!_paused && !_held) _clock.forward();
  }

  void _onClock(AnimationStatus st) {
    if (st == AnimationStatus.completed && mounted) _next();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _clock.stop();
    } else if (_clock.duration != null && _clock.value > 0 && _clock.value < 1) {
      _clock.forward();
    } else {
      _startClock();
    }
  }

  /// スワイプを止める / 戻す。ページが止まりきる前に物理を変えると、ページの途中で止まるので、止まってから。
  void _setLocked(bool v) {
    if (v == _locked) return;
    final pos = _pages.hasClients ? _pages.position : null;
    if (v && pos != null && pos.isScrollingNotifier.value) {
      void once() {
        if (pos.isScrollingNotifier.value) return;
        pos.isScrollingNotifier.removeListener(once);
        if (mounted) _setLocked(true);
      }

      pos.isScrollingNotifier.addListener(once);
      return;
    }
    setState(() => _locked = v);
  }

  void _seen(int i) {
    final s = (i >= 0 && i < _items.length) ? _items[i].swing : null;
    if (s != null && !widget.mine) unawaited(_feed.markSeen(s.id));
  }

  void _onPage(int i) {
    _seen(_index);
    setState(() {
      _index = i;
      _locked = false;
      _paused = false;
      // 下の返信を読んでいた / 書いていたのは前の Swing。
      _holds
        ..remove('thread')
        ..remove('replyInput');
    });
    _startClock();
  }

  /// 次へ(最後なら閉じる)。
  void _next() {
    if (_index + 1 < _items.length) {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _close();
    }
  }

  void _prev() {
    if (_index > 0) _pages.previousPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  void _close() {
    _seen(_index);
    _closed = true;
    // 第3カラム (D-413): < と同じ戻り(1 つ前のページへ / 無ければ閉じる)。
    if (paneBack(context)) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: RasqTheme.dark(),
      child: Scaffold(
        key: const ValueKey('swing.viewer'),
        backgroundColor: Colors.black,
        body: _items.isEmpty
            ? Stack(children: [
                widget.mine
                    ? const RasqEmptyView(key: ValueKey('swing.viewer.empty'), title: '出している Swing はありません', hint: '＋ を上へスワイプすると Swing を作れます')
                    : const RasqEmptyView(key: ValueKey('swing.viewer.empty'), title: 'Swing はありません', hint: 'フォローしている人や、RASQ リストに入れてくれた人の Swing がここに流れます'),
                Positioned(top: 8, right: 8, child: SafeArea(child: RasqIconButton(icon: Icons.close, tooltip: '閉じる', color: Colors.white, onPressed: _close))),
              ])
            : Stack(children: [
                Positioned.fill(child: ScrollConfiguration(
                // マウス / トラックパッドのドラッグでもめくれる(既定はタッチだけ)。
                behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus}),
                child: PageView.builder(
                key: const ValueKey('swing.viewer.pages'),
                controller: _pages,
                physics: _locked ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                onPageChanged: _onPage,
                itemCount: _items.length,
                itemBuilder: (_, i) {
                  final item = _items[i];
                  final s = item.swing;
                  if (s == null) return _AdPage(key: ValueKey('swing.ad.$i'), onClose: _close);
                  return _SwingPage(
                    key: ValueKey('swing.page.${s.id}'),
                    swing: s,
                    active: i == _index,
                    paused: i == _index && (_paused || _held),
                    replyBar: i == _index && _replyBarShown(s),
                    onHold: _hold,
                    covered: _coveredNow(s),
                    onReveal: () => _reveal(s),
                    onReport: widget.mine || ref.watch(swingApiProvider) == null ? null : () => _report(s),
                    viewCount: widget.mine ? s.viewCount : null,
                    clock: _clock,
                    position: '${i + 1} / ${_items.length}',
                    onClose: _close,
                    onTapZone: (zone) => switch (zone) { -1 => _prev(), 1 => _next(), _ => _togglePause() },
                    onLockChanged: (locked) {
                      if (i == _index) _setLocked(locked);
                    },
                    onEnd: () {
                      if (i == _index) _next();
                    },
                  );
                },
              ),
              )),
              ]),
      ),
    );
  }

  Swing? get _current => _index < _items.length ? _items[_index].swing : null;

  /// 返信(左下の欄と、下に続くスレッド)を出すか。全画面で動いているプラグイン・覆っている Swing・根の無い Swing には出さない。
  bool _replyBarShown(Swing s) => s.postId != null && !_locked && !_coveredNow(s) && ref.watch(rasqAccountPageApiProvider) != null;
}

String swingRemainingLabel(Duration d) {
  if (d.inHours >= 1) return 'あと ${d.inHours} 時間';
  if (d.inMinutes >= 1) return 'あと ${d.inMinutes} 分';
  return 'まもなく消えます';
}

class _SwingPage extends StatefulWidget {
  const _SwingPage({super.key, required this.swing, required this.active, required this.paused, required this.clock, required this.position, required this.onClose, required this.onTapZone, required this.onLockChanged, required this.onEnd, required this.onHold, this.replyBar = false, this.covered = false, this.onReveal, this.onReport, this.viewCount});

  /// 自分の Swing の見た人の数 (D-410)。null = 出さない(ほかの人の Swing / 古い Central)。
  final int? viewCount;

  /// CW / センシティブで覆っている (D-395)。
  final bool covered;
  final VoidCallback? onReveal;

  /// 通報 (D-395)。null = 出さない(RASQ アカウントが無い)。
  final VoidCallback? onReport;

  /// 返信を出す: 左下の欄と、**下に続くスレッド** (D-389 / D-413)。
  final bool replyBar;
  final Swing swing;
  final bool active;
  final bool paused;
  final Animation<double> clock;
  final String position;

  /// -1 = 左端(前へ)、0 = 中央(一時停止)、1 = 右端(次へ)。
  final ValueChanged<int> onTapZone;
  final VoidCallback onClose;
  final ValueChanged<bool> onLockChanged;
  final VoidCallback onEnd;

  /// 止める / 戻す(理由ごと)。
  final void Function(String reason, bool hold) onHold;

  @override
  State<_SwingPage> createState() => _SwingPageState();
}

/// 1 つの Swing のページ (D-413): 縦にスクロールでき、Swing(ページの高さいっぱい)の下に返信のスレッドが続く。
/// 返信を出さないとき(プラグインが全画面 / 覆っている / 根が無い)はスクロールしない。木の形は変えない(プラグインを作り直さない)。
class _SwingPageState extends State<_SwingPage> {
  final _scroll = ScrollController();
  final _threadKey = GlobalKey();
  final _reply = FocusNode();
  bool _reading = false;

  Swing get swing => widget.swing;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reply.addListener(() => widget.onHold('replyInput', _reply.hasFocus));
  }

  @override
  void didUpdateWidget(_SwingPage old) {
    super.didUpdateWidget(old);
    // 返信を出さなくなった(プラグインが全画面に戻った など)ら、Swing の位置へ戻す。
    if (old.replyBar && !widget.replyBar && _scroll.hasClients && _scroll.offset > 0) _scroll.jumpTo(0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _reply.dispose();
    super.dispose();
  }

  /// 下の返信を読んでいる間は、Swing を止める。
  void _onScroll() {
    final reading = _scroll.offset > 24;
    if (reading == _reading) return;
    _reading = reading;
    if (widget.active) widget.onHold('thread', reading);
  }

  /// 下のスレッドへ送る([focus] = 返信の欄に入る)。
  Future<void> _toThread({bool focus = false}) async {
    final ctx = _threadKey.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    if (focus && mounted) _reply.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final thread = widget.replyBar;
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        key: const ValueKey('swing.page.scroll'),
        controller: _scroll,
        physics: thread ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: box.maxHeight, child: _body(context)),
          if (thread)
            SwingThreadSection(
              key: _threadKey,
              swing: swing,
              focusNode: _reply,
              minHeight: box.maxHeight * 0.6,
              onHold: (v) => widget.onHold('reply', v),
            ),
        ]),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final active = widget.active;
    final paused = widget.paused;
    final covered = widget.covered;
    final replyBar = widget.replyBar;
    final clock = widget.clock;
    final onEnd = widget.onEnd;
    final onTapZone = widget.onTapZone;
    final onReport = widget.onReport;
    final onClose = widget.onClose;
    final viewCount = widget.viewCount;
    final position = widget.position;
    // 覆っている間は動画 / プラグインを動かさない。
    final live = active && !covered;
    final body = switch (swing.kind) {
      SwingKind.text => _TextBody(text: swing.text),
      SwingKind.image => _ImageBody(swing: swing),
      SwingKind.video => _VideoBody(swing: swing, active: live, paused: paused, onDone: onEnd),
      SwingKind.plugin => _PluginBody(swing: swing, active: live, onLockChanged: widget.onLockChanged, onEnd: onEnd),
    };
    final timed = swing.kind != SwingKind.plugin;
    return Stack(fit: StackFit.expand, children: [
      body,
      // タップ: 左端 / 中央 / 右端(プラグインはページ自身がタップを使う)。
      if (timed)
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, box) => GestureDetector(
              key: const ValueKey('swing.tap'),
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) {
                final x = d.localPosition.dx / box.maxWidth;
                onTapZone(x < 0.25 ? -1 : (x > 0.75 ? 1 : 0));
              },
            ),
          ),
        ),
      if (timed && paused && !covered)
        const Center(child: IgnorePointer(child: Icon(Icons.pause_circle_outline, key: ValueKey('swing.paused'), color: Colors.white70, size: 64))),
      if (covered) Positioned.fill(child: _Cover(swing: swing, onReveal: widget.onReveal)),
      // 上: 時間の進み、作った人と残り時間、閉じる。
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: DecoratedBox(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent])),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.lg),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (swing.kind == SwingKind.text || swing.kind == SwingKind.image)
                    Padding(
                      padding: const EdgeInsets.only(bottom: RasqSpacing.xs, right: RasqSpacing.sm),
                      child: AnimatedBuilder(
                        animation: clock,
                        builder: (_, _) => LinearProgressIndicator(key: const ValueKey('swing.progress'), value: active ? clock.value : 0, minHeight: 2, color: Colors.white, backgroundColor: Colors.white24),
                      ),
                    ),
                  Row(children: [
                  RasqAvatar(imageUrl: swing.author.avatarUrl, size: 32, fallbackLabel: swing.author.displayName),
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(swing.author.displayName, key: const ValueKey('swing.author'), style: RasqTypography.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${swingRemainingLabel(swing.remaining(DateTime.now()))} ・ $position', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                      if (viewCount != null)
                        Row(key: const ValueKey('swing.viewCount'), mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.visibility_outlined, size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Text('見た人 $viewCount 人', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                        ]),
                    ]),
                  ),
                  if (onReport != null) RasqIconButton(key: const ValueKey('swing.report'), icon: Icons.flag_outlined, tooltip: '通報', color: Colors.white, onPressed: onReport),
                  RasqIconButton(key: const ValueKey('swing.close'), icon: Icons.close, tooltip: '閉じる', color: Colors.white, onPressed: onClose),
                ]),
                ]),
              ),
            ),
          ),
      ),
      // 画像 / 動画に添えた文。
      if (swing.kind != SwingKind.text && swing.kind != SwingKind.plugin && swing.text.isNotEmpty && !covered)
        Positioned(
          left: RasqSpacing.page,
          right: RasqSpacing.page,
          bottom: RasqSpacing.xxl + (replyBar ? 88 : 0),
          child: Text(swing.text, key: const ValueKey('swing.caption'), style: RasqTypography.body.copyWith(color: Colors.white, shadows: const [Shadow(blurRadius: 6)])),
        ),
      // 左下: 返信とキュー (D-389)。ハンドル / 入力欄は、下に続くスレッドへ送る (D-413)。
      if (replyBar)
        Positioned(
          left: RasqSpacing.page,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: swing.kind == SwingKind.video ? 64 : RasqSpacing.md),
              child: SwingReplyBar(
                key: ValueKey('swing.reply.${swing.id}'),
                swing: swing,
                onHold: (v) => widget.onHold('reply', v),
                onOpenThread: _toThread,
                onReply: () => _toThread(focus: true),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// CW / センシティブの覆い (D-395): ぼかして暗くし、CW の文か「センシティブな内容」と「表示する」。スワイプでは移れる。
class _Cover extends StatelessWidget {
  const _Cover({required this.swing, this.onReveal});
  final Swing swing;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) => ClipRect(
        key: const ValueKey('swing.cover'),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.7),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(RasqSpacing.xxl),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.visibility_off_outlined, color: Colors.white70, size: 40),
                  const SizedBox(height: RasqSpacing.sm),
                  Text(swing.cw ?? 'センシティブな内容', key: const ValueKey('swing.cover.text'), textAlign: TextAlign.center, style: RasqTypography.title.copyWith(color: Colors.white)),
                  if (swing.cw != null && swing.sensitive) Text('センシティブな内容', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                  const SizedBox(height: RasqSpacing.md),
                  FilledButton.tonal(key: const ValueKey('swing.cover.reveal'), onPressed: onReveal, child: const Text('表示する')),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _TextBody extends StatelessWidget {
  const _TextBody({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [RasqColors.main, RasqColors.link])),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(RasqSpacing.xxl),
            child: Text(text, key: const ValueKey('swing.text'), textAlign: TextAlign.center, style: RasqTypography.title.copyWith(color: Colors.white, fontSize: 26, height: 1.4)),
          ),
        ),
      );
}

class _ImageBody extends StatelessWidget {
  const _ImageBody({required this.swing});
  final Swing swing;

  @override
  Widget build(BuildContext context) {
    final url = swing.mediaUrl;
    if (url == null) return const _Missing();
    return Image.network(
      url.toString(),
      key: const ValueKey('swing.image'),
      webHtmlElementStrategy: rasqWebImageStrategy,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const _Missing(),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();
  @override
  Widget build(BuildContext context) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 48));
}

class _VideoBody extends StatefulWidget {
  const _VideoBody({required this.swing, required this.active, this.paused = false, this.onDone});
  final Swing swing;
  final bool active;
  final bool paused;

  /// 終わりまで再生した(次へ)。
  final VoidCallback? onDone;

  @override
  State<_VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<_VideoBody> {
  VideoSession? _session;

  @override
  void initState() {
    super.initState();
    final url = widget.swing.mediaUrl;
    if (url != null) {
      _session = VideoSession(MediaItem(id: widget.swing.id, type: MediaType.video, url: url), autoplay: widget.active)
        ..addListener(_hook);
    }
  }

  @override
  void didUpdateWidget(_VideoBody old) {
    super.didUpdateWidget(old);
    // 別のページへ移ったら止める。
    final c = _session?.controller;
    if (c != null && (old.active && !widget.active || !old.paused && widget.paused)) c.pause();
    if (c != null && widget.active && !widget.paused && (!old.active || old.paused)) c.play();
  }

  bool _done = false;
  bool _hooked = false;

  /// 再生器ができたら、終わりを見張る(1 回だけ)。
  void _hook() {
    final c = _session?.controller;
    if (c == null || _hooked) return;
    _hooked = true;
    c.addListener(_watchEnd);
  }

  void _watchEnd() {
    final c = _session?.controller;
    if (c == null || _done || !widget.active) return;
    final v = c.value;
    if (v.isInitialized && v.duration > Duration.zero && v.position >= v.duration && !v.isPlaying) {
      _done = true;
      widget.onDone?.call();
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (s == null) return const _Missing();
    return Stack(fit: StackFit.expand, children: [
      RasqVideoView(key: const ValueKey('swing.video'), session: s),
      Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false, child: VideoControls(session: s, light: true))),
    ]);
  }
}

/// プラグインの Swing: 全画面で動かす。「全画面から縮小」でぼかして止め、スワイプで移れるように。
class _PluginBody extends ConsumerStatefulWidget {
  const _PluginBody({required this.swing, required this.active, required this.onLockChanged, required this.onEnd});
  final Swing swing;
  final bool active;
  final ValueChanged<bool> onLockChanged;
  final VoidCallback onEnd;

  @override
  ConsumerState<_PluginBody> createState() => _PluginBodyState();
}

class _PluginBodyState extends ConsumerState<_PluginBody> {
  CustomPageController? _c;
  bool _shrunk = false;

  @override
  void initState() {
    super.initState();
    // 画面の大きさ(MediaQuery)を読むので、最初のフレームのあとに起こす。
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active && _c == null) _start();
      });
    }
  }

  @override
  void didUpdateWidget(_PluginBody old) {
    super.didUpdateWidget(old);
    // 見えたときに起こす。離れたら閉じる(page.close)。
    if (widget.active && _c == null) _start();
    if (!widget.active && _c != null) _stop();
  }

  void _start() {
    final p = widget.swing.plugin!;
    final c = CustomPageController(
      ProviderScope.containerOf(context, listen: false),
      CustomPageArgs(
        pluginId: p.id,
        version: p.version,
        surface: PluginPageDecl.surfaceSwing,
        // 未審査 (D-379): 作った人が上げた入れ物を、同意のうえ制限モード(通信なし、GPU だけ可)で一時的に動かす。
        package: p.unreviewed && p.packageUrl != null ? () => ref.read(swingPackageFetcherProvider)(p.packageUrl!) : null,
        packageSource: p.unreviewed ? '$swingSlotSourcePrefix${widget.swing.id}' : null,
        context: {
          'swingId': widget.swing.id,
          'data': ?p.data,
          'author': {'accountId': widget.swing.authorAccountId, 'handle': widget.swing.author.account.handle, 'displayName': widget.swing.author.displayName},
        },
      ),
      // 第3カラムに開いたときは、カラムの大きさ (D-413)。
      size: switch (context.findRenderObject()) { final RenderBox b when b.hasSize => b.size, _ => MediaQuery.sizeOf(context) },
    );
    c.onEnd = widget.onEnd;
    c.addListener(_changed);
    _c = c;
    _shrunk = false;
    unawaited(c.start());
  }

  void _stop() {
    final c = _c;
    _c = null;
    c?.removeListener(_changed);
    c?.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    widget.onLockChanged(_running && !_shrunk);
  }

  bool get _running => _c?.phase == CustomPagePhase.ready;

  void _setShrunk(bool v) {
    final c = _c;
    if (c == null) return;
    setState(() => _shrunk = v);
    v ? c.pause() : c.resume();
    widget.onLockChanged(_running && !v);
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final scheme = Theme.of(context).colorScheme;
    if (c == null || c.phase == CustomPagePhase.resolving || c.phase == CustomPagePhase.loading) {
      return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)));
    }
    switch (c.phase) {
      case CustomPagePhase.needsConsent:
        // 未審査のプラグイン (D-379)。
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.extension_outlined, color: Colors.white70, size: 40),
              const SizedBox(height: RasqSpacing.sm),
              Text(widget.swing.plugin!.id, style: RasqTypography.title.copyWith(color: Colors.white)),
              const SizedBox(height: RasqSpacing.sm),
              const RasqNotice.warning(
                key: ValueKey('swing.plugin.consent'),
                text: '審査されていないプラグインです。通信はできない状態で、この Swing を見ている間だけ動かします。',
                detail: 'D-379 / S-057。制限モード(network / storage.unsafe / interstitial・system の FOW / URL を開くなどは閉、GPU は可)。子プラグインを持たない 1 つだけ。',
              ),
              const SizedBox(height: RasqSpacing.md),
              FilledButton(key: const ValueKey('swing.plugin.run'), onPressed: c.acceptTemporary, child: const Text('動かす')),
            ]),
          ),
        );
      case CustomPagePhase.needsInstall:
        return RasqEmptyView(
          key: const ValueKey('swing.plugin.needsInstall'),
          title: '${c.detail?.name ?? widget.swing.plugin!.id} を入れると見られます',
          hint: 'プラグインの Swing です。ストアからインストールしてください',
          action: FilledButton(onPressed: () => context.push(Routes.storePlugin(widget.swing.plugin!.id)), child: const Text('ストアで見る')),
        );
      case CustomPagePhase.failed:
        return RasqEmptyView(key: const ValueKey('swing.plugin.failed'), title: '開けませんでした', hint: c.error);
      default:
        break;
    }
    final p = c.plugin!;
    final controller = p.runtime.view;
    final page = RrlRenderer(
      node: c.root ?? RrlNode.fromJson(const {'t': 'Column'}),
      host: RrlHost(instanceScope: controller.document?.scope ?? p.id, scope: RrlScope({}), geometry: controller.geometry, mediaPolicy: p.mediaPolicy, onEvent: c.onRrlEvent),
    );
    final full = Container(
      key: const ValueKey('swing.plugin.page'),
      color: scheme.surface,
      child: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 56, RasqSpacing.page, RasqSpacing.page), child: page)),
    );
    if (_shrunk) {
      // 縮小: ぼかして止め、押すと全画面に戻る。
      return GestureDetector(
        key: const ValueKey('swing.plugin.shrunk'),
        onTap: () => _setShrunk(false),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.78,
            heightFactor: 0.7,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
                child: AbsorbPointer(child: ImageFiltered(imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8), child: full)),
              ),
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
                  const SizedBox(height: RasqSpacing.xs),
                  Text('押すと全画面に戻ります', style: RasqTypography.caption.copyWith(color: Colors.white)),
                  Text('上下にスワイプで次の Swing へ', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                ]),
              ),
            ]),
          ),
        ),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      full,
      Positioned(
        right: RasqSpacing.sm,
        bottom: RasqSpacing.lg,
        child: SafeArea(
          child: FilledButton.tonalIcon(
            key: const ValueKey('swing.plugin.shrink'),
            onPressed: () => _setShrunk(true),
            icon: const Icon(Icons.close_fullscreen, size: 18),
            label: const Text('全画面から縮小'),
          ),
        ),
      ),
    ]);
  }
}

/// 広告の 1 枚。出せなかった(読み込めない)ときは案内だけ。
class _AdPage extends StatelessWidget {
  const _AdPage({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ExportAdSlot(onDark: true),
            const SizedBox(height: RasqSpacing.md),
            Text('上にスワイプで次の Swing へ', style: RasqTypography.caption.copyWith(color: Colors.white54)),
          ]),
        ),
        Positioned(top: 8, right: 8, child: SafeArea(child: RasqIconButton(icon: Icons.close, tooltip: '閉じる', color: Colors.white, onPressed: onClose))),
      ]);
}
