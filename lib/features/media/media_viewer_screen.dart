import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../l10n/l10n.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/rasq_account_page_api.dart';
import '../home/action_bar_config.dart';
import '../home/action_bundle_fow.dart';
import 'fow_avoid.dart';
import 'media_reveal.dart';
import '../settings/safety.dart';
import '../home/plugin_actions.dart';
import '../home/post_row.dart';
import '../post/post_menu.dart';
import '../home/timeline_providers.dart';
import '../compose/post_video.dart' show isAudioMedia;
import 'video_player.dart';
import 'viewer_plugin_overlay.dart';
import 'viewer_sequence.dart';

/// 全画面表示(画像/動画/音声): 黒背景、PageView、戻る/…。
/// 下側はダークモードの FOW (D-202、D-326 で下側**中央**・最大 600px): 動画の操作(左にシークバー、右にボタン類)/
/// アクションバー / 投稿のインライン表示。AsTell のルーム FOW と同じ作法で動く: 折りたたみ(操作 + アクションバー)と
/// 展開(投稿まで)の 2 段、外側タップで折りたたみ(閉じない)、折りたたみ中はバリア無しで背面を触れる。
/// FOW が伸び縮みする / 動くたびに、メディアは FOW の**逆サイド**へ寄る (D-326)。
/// 動画と音声は開くと自動再生(全画面表示プラグインが**オン**のときだけ止める)。**下向きスワイプで閉じる** (D-326)。
/// `…` → 「オーバーレイに移動」(動画のみ、VC・動画オーバーレイへ昇格 = M5 以降).
/// センシティブ / 注釈(CW)のメディアは**1 枚ずつ**クッション (D-510): タイルで開いた 1 枚は開いたまま、スワイプした先の
/// ほかの 1 枚は押すまでクッション(押すまでは自動再生も全画面表示プラグインへの受け渡しもしない)。セーフモード / 見守り中で
/// タイルから取り除いたメディアは、外せないクッション。開いた記録はタイルと共有([mediaRevealProvider])。
/// **投稿をまたいでスワイプ** (D-565): [sequence](開いたタイムラインの並び)があれば、添付の最後(最初)から次(前)の
/// メディア付き投稿へそのまま移る。下の端に近づいたら続きを読み込む。上の端(新しい側)は止まる。
/// **上下に引っ張って閉じる** (D-566): 拡大していなければ上下どちらへ引いても閉じる。拡大中はパンの限界(画像の上端 / 下端)に
/// 達してから、さらに同じ向きへ引いたぶんだけを数える(ピンチ / パンと取り合わない)。
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({super.key, required this.post, this.initialIndex = 0, this.sequence});
  final Post post;
  final int initialIndex;

  /// 投稿をまたいで続ける並び (D-565)。null = この投稿の添付だけ。
  final ViewerSequence? sequence;
  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

const viewerFowId = 'fow.viewer';
const viewerFowCollapsedFactor = 0.2;
const viewerFowExpandedFactor = 0.7;
const viewerPanelKey = ValueKey('viewer.panel');

/// 下側の FOW の最大幅 (D-326): 幅の広い画面では下側**中央**に置く(狭い画面はカラムいっぱい)。
const viewerFowMaxWidth = 600.0;

/// FOW の逆サイドに必ず残すメディアの空き (D-326)。これを切るぶんは FOW と重なる(消えるよりまし)。
const viewerMinFreeSpace = 120.0;

/// メディアを寄せる余白の枠(テストが読む)。
const viewerMediaInsetKey = ValueKey('viewer.media.inset');

/// 上下に引っ張って閉じる (D-326 → D-566): この距離を超えて離すか、この速さ以上で同じ向きへ払うと閉じる。
/// 拡大中は、パンの限界を越えて引いたぶん(払う速さは見ない)がこの距離を超えたら閉じる。
const viewerSwipeCloseDistance = 120.0;
const viewerSwipeCloseVelocity = 700.0;

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  /// 全画面の並び (D-565): (投稿, 添付の番号)。開いた投稿のぶん + 並びのほかのメディア付き投稿。足すのは末尾だけ
  /// (番号 = ページ = 下の表の鍵がずれない)。
  late List<ViewerSlide> _slides = _initialSlides();
  late final int _startPage = _slides.indexWhere((x) => x.post.key == widget.post.key && x.media == widget.initialIndex).clamp(0, math.max(0, _slides.length - 1));
  late final PageController _ctrl = PageController(initialPage: _startPage);
  late final ValueNotifier<int> _page = ValueNotifier(_startPage);

  List<ViewerSlide> _initialSlides() {
    final seq = widget.sequence;
    final slides = seq == null ? null : buildViewerSlides(seq.posts(), widget.post, visibleMedia: _visibleMedia);
    // 並びが無い / 開いた 1 枚が並びに無い: これまでどおり、この投稿の添付だけ。
    if (slides == null || !slides.any((x) => x.post.key == widget.post.key && x.media == widget.initialIndex)) {
      return [for (var m = 0; m < widget.post.media.length; m++) (post: widget.post, media: m)];
    }
    return slides;
  }

  /// ほかの投稿はタイルに出ている添付だけ(セーフモード / 見守りで取り除いたものは飛ばす)。
  List<int> _visibleMedia(Post p) => ref.read(safetySettingsProvider).applyToPost(p).$2;

  ViewerSlide _slide(int i) => _slides[i.clamp(0, _slides.length - 1)];
  MediaItem _mediaAt(int i) => _slide(i).post.media[_slide(i).media];

  /// いま見ている 1 枚の投稿。
  Post get _post => _slide(_page.value).post;

  // ── 続きの読み込み (D-565) ──
  bool _extending = false;

  /// 読み込み済みの最後から [viewerLoadMoreAhead] 枚以内に来たら、並びの続きを足す。TL がもう読んでいればそれを、無ければ
  /// TL の「続きを読む」を呼ぶ(メディアの無いページだけが返ってきたら、もう少し読む。3 回まで)。上の端では何もしない。
  Future<void> _maybeExtend(int i) async {
    final seq = widget.sequence;
    if (seq == null || _extending || i < _slides.length - 1 - viewerLoadMoreAhead) return;
    if (!_slides.any((x) => x.post.key != widget.post.key) && !seq.posts().any((p) => p.key == widget.post.key)) return; // 並びに無い投稿で開いた
    if (_appendFrom(seq.posts())) return;
    final load = seq.loadMore;
    if (load == null) return;
    _extending = true;
    try {
      for (var tries = 0; tries < 3 && mounted && (seq.canLoadMore?.call() ?? false); tries++) {
        await load();
        if (!mounted || _appendFrom(seq.posts())) break;
      }
    } catch (e) {
      debugPrint('viewer: load more failed: $e');
    } finally {
      _extending = false;
    }
  }

  bool _appendFrom(List<Post> posts) {
    final more = appendViewerSlides(_slides, posts, visibleMedia: _visibleMedia);
    if (more.isEmpty || !mounted) return false;
    setState(() => _slides = [..._slides, ...more]);
    return true;
  }

  /// 動画のセッション(ページごと、D-201)。ページを離れると一時停止、開くと自動再生 (D-202)。
  final _sessions = <int, VideoSession>{};
  VideoSession _session(int i) => _sessions.putIfAbsent(i, () {
        final s = VideoSession(_mediaAt(i), autoplay: true);
        // クッションの下では再生しない(開いたら [_reveal] が外す)。
        if (_gate(i) != _ViewerGate.open) s.hold = true;
        return s;
      });

  /// その 1 枚をいま見せてよいか (D-510)。タイルと同じ答え([SafetySettings.applyToPost] + 開いた記録)。
  _ViewerGate _gate(int i) {
    if (i < 0 || i >= _slides.length) return _ViewerGate.locked;
    final (:post, :media) = _slides[i];
    final (items, map) = ref.read(safetySettingsProvider).applyToPost(post);
    final j = map.indexOf(media);
    if (j < 0) return _ViewerGate.locked; // セーフモード / 見守り中: タイルから取り除いたもの
    if (!items[j].sensitive) return _ViewerGate.open;
    return (ref.read(mediaRevealProvider)[post.key]?.contains(post.media[media].id) ?? false) ? _ViewerGate.open : _ViewerGate.cushion;
  }

  /// クッションを外す(その 1 枚だけ)。外してから全画面表示プラグインへ渡し、動画 / 音声は自動再生 (D-326)。
  void _reveal(int i) {
    final post = _slide(i).post;
    final m = _mediaAt(i);
    ref.read(mediaRevealProvider.notifier).reveal(post, m.id);
    _sessions[i]?.hold = false;
    _askOverlay(i);
    if (i == _page.value && (m.type == MediaType.video || isAudioMedia(m))) _session(i).play();
    _manager?.requestRebuild();
    if (mounted) setState(() {});
  }
  bool _chrome = true;

  /// 下側の FOW (D-202)。最初に開くときに作る(上側のボタン群に**被さらない**最大の高さを画面から決める、D-329)。
  FowSpec? _specOrNull;
  FowSpec get _spec => _specOrNull!;

  /// 上側のボタン群(戻る / 枚数 / アクションバー / PiP / …)の下辺(SafeArea + 余白 + 40px の丸ボタン + 余白)。
  /// FOW はこれより上に伸びない(D-329: 投稿アクションバー付き FOW が上側のボタン群に被さらないように)。
  static double viewerHeaderBottom(BuildContext context) => MediaQuery.paddingOf(context).top + RasqSpacing.sm * 2 + 40;

  FowSpec _createSpec() {
    final screenH = MediaQuery.sizeOf(context).height;
    final max = screenH > 0 ? ((screenH - viewerHeaderBottom(context) - RasqSpacing.sm) / screenH).clamp(0.3, 0.92) : 0.92;
    final expanded = math.min(viewerFowExpandedFactor, max);
    final spec = FowSpec(
      initialHeightFactor: viewerFowCollapsedFactor,
      minHeightFactor: 0.08,
      maxHeightFactor: max,
      heightStops: [viewerFowCollapsedFactor, expanded],
      freeAboveStops: true,
      theme: (_) => RasqTheme.dark(),
      maxWidth: viewerFowMaxWidth, // 下側中央 (D-326)
    );
    spec.heightFactor.addListener(_syncBarrier);
    // FOW の伸び縮み / 移動に追従 (D-326)。
    for (final l in _geometryOf(spec)) {
      l.addListener(_scheduleRelayout);
    }
    return spec;
  }
  final _barrier = ValueNotifier<bool>(false);
  OverlayManager? _manager;

  /// 全画面表示プラグイン (D-167 / D-178 で共通化): 画像ごとの重ねとトークン。
  late final ViewerPluginOverlays _overlays = ViewerPluginOverlays(ref, onChanged: () {
    if (mounted) setState(() {});
  });

  /// FOW のぶんメディアを寄せる余白 (D-207 → D-215 → D-326 → D-332): FOW が出る / 消える / **伸び縮みする / 動く**たびに、
  /// メディアを FOW の**逆サイド**へ寄せる。ホストが置いた矩形(`FowSpec.laidOut`)を次のフレームで読み、上下に寄せるか
  /// 左右に寄せるかは**空きが広くなるほう**(壁付けは左右固定): 幅の広い画面でカラムに置かれた FOW(縦に長い)は左右へ、
  /// 下側中央の FOW は上へ。逆サイドに [viewerMinFreeSpace] は必ず残す(足りないぶんは FOW と重なる)。
  EdgeInsets _fowInset = EdgeInsets.zero;
  bool _relayoutPending = false;

  /// 自分の FOW の高さ / 移動 / 幾何が変わったら次のフレームで測り直す(1 フレームに 1 回にまとめる)。
  void _scheduleRelayout() {
    if (_relayoutPending || !mounted) return;
    _relayoutPending = true;
    // 矩形はホストの build で決まるので 1 フレーム後に読む。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _relayoutPending = false;
      _relayoutForFows();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// ほかの FOW(バンドルのメニューなど)の出入りも同じ扱い。
  void _onOverlays() => _scheduleRelayout();

  void _relayoutForFows() {
    final manager = _manager;
    if (!mounted || manager == null) return;
    // 計算は Swing を作る画面 (D-413) と共通 ([fowAvoidInset])。全画面なので、場所は画面ぜんぶ。
    final inset = fowAvoidInset(Offset.zero & MediaQuery.sizeOf(context), laidOutFows(manager), minFree: viewerMinFreeSpace);
    if (inset != _fowInset) setState(() => _fowInset = inset);
  }

  // ── 上下に引っ張って閉じる (D-326 → D-566) ──

  /// 面を指に付けて動かし、離したときの距離 / 速さで閉じるか戻すか。拡大中は縦ドラッグのジェスチャーを登録せず
  /// InteractiveViewer のパンに譲り、パンの限界を越えたぶんだけを [_onZoomedPointerMove] が数える。
  double _swipeDy = 0;
  bool _swiping = false;
  bool _zoomed = false;
  final _zoom = <int, TransformationController>{};

  TransformationController _zoomOf(int i) => _zoom.putIfAbsent(i, () {
        final c = TransformationController();
        c.addListener(() => _syncZoomed(i));
        return c;
      });

  void _syncZoomed(int i) {
    if (i != _page.value || !mounted) return;
    final z = _zoomOf(i).value.getMaxScaleOnAxis() > 1.01;
    if (z != _zoomed) setState(() => _zoomed = z);
  }

  void _onSwipeUpdate(DragUpdateDetails d) => setState(() {
        _swiping = true;
        _swipeDy += d.delta.dy;
      });

  void _onSwipeEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? d.velocity.pixelsPerSecond.dy;
    // 上でも下でも: 離した位置が遠いか、引いている向きへ速く払った。
    if (_swipeDy.abs() >= viewerSwipeCloseDistance || (_swipeDy != 0 && v.sign == _swipeDy.sign && v.abs() >= viewerSwipeCloseVelocity)) {
      _close();
      return;
    }
    _resetSwipe();
  }

  bool _closing = false;
  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  // 拡大中 (D-566): 指 1 本で動かしている間、パンが限界(画像の上端 / 下端)で止まっているのに同じ向きへ引いたぶんを数える。
  // 2 本目の指(ピンチ)が来たら数えない。押してからタッチの遊び(kTouchSlop)ぶん動くまでは数えない(パンが始まる前)。
  final Set<int> _pointers = {};
  double _pointerTravel = 0;
  double? _lastTy;
  double _viewportH = 0;

  void _onZoomedPointerDown(PointerDownEvent e) {
    _pointers.add(e.pointer);
    _pointerTravel = 0;
    _lastTy = _zoomOf(_page.value).value.getTranslation().y;
    if (_pointers.length > 1) _resetSwipe();
  }

  void _onZoomedPointerMove(PointerMoveEvent e) {
    if (!_zoomed || _pointers.length != 1 || _viewportH <= 0) return;
    _pointerTravel += e.delta.distance;
    final m = _zoomOf(_page.value).value;
    final ty = m.getTranslation().y;
    final panned = _lastTy != null && (ty - _lastTy!).abs() > 0.01;
    _lastTy = ty;
    if (_pointerTravel < kTouchSlop) return;
    final dy = e.delta.dy;
    if (_swipeDy != 0) {
      // 引いている途中: 戻す向きならそのぶん減らす(0 を越えたら引くのをやめる)。
      final next = _swipeDy + dy;
      setState(() => _swipeDy = next.sign == _swipeDy.sign ? next : 0);
      return;
    }
    if (panned) return; // まだパンしている(限界に達していない)
    final scale = m.getMaxScaleOnAxis();
    final atTop = ty >= -0.5;
    final atBottom = ty <= _viewportH - scale * _viewportH + 0.5;
    if ((dy > 0 && atTop) || (dy < 0 && atBottom)) {
      setState(() {
        _swiping = true;
        _swipeDy = dy;
      });
    }
  }

  void _onZoomedPointerUp(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (!_zoomed || _swipeDy == 0) return;
    if (e is PointerUpEvent && _pointers.isEmpty && _swipeDy.abs() >= viewerSwipeCloseDistance) {
      _close();
      return;
    }
    _resetSwipe();
  }

  void _resetSwipe() {
    if (!mounted || (!_swiping && _swipeDy == 0)) return;
    setState(() {
      _swiping = false;
      _swipeDy = 0;
    });
  }

  /// 上に画面が積まれたら FOW を閉じ、戻ってきたら開き直す (D-205)。
  GoRouter? _router;
  bool _closedByNav = false;

  void _onRoute() {
    final router = _router;
    final manager = _manager;
    if (!mounted || router == null || manager == null) return;
    final onTop = sameRoute(visibleLocationOf(router.routerDelegate.currentConfiguration), Routes.viewer);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!onTop && manager.contains(viewerFowId)) {
        _closedByNav = true;
        manager.close(viewerFowId);
      } else if (onTop && _closedByNav && !manager.contains(viewerFowId)) {
        _closedByNav = false;
        _openPanel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    _router!.routerDelegate.addListener(_onRoute);
    _manager = ref.read(overlayManagerProvider);
    _manager!.addListener(_onOverlays);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _askOverlay(_page.value);
      _openPanel();
      unawaited(_maybeExtend(_page.value)); // 開いたのが読み込み済みの端の近く
    });
  }

  /// 自分の FOW の幾何(高さ / 横縦の追従量 / カラムなど)。
  static List<Listenable> _geometryOf(FowSpec spec) => [spec.heightFactor, spec.moveDx, spec.moveDy, spec.geometryRev];

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    _manager?.removeListener(_onOverlays);
    if (_specOrNull case final spec?) {
      for (final l in _geometryOf(spec)) {
        l.removeListener(_scheduleRelayout);
      }
      spec.heightFactor.removeListener(_syncBarrier);
    }
    for (final c in _zoom.values) {
      c.dispose();
    }
    final manager = _manager;
    // 破棄中に他のウィジェットを更新しない: 次のフレームで FOW を閉じる(アプリごと破棄された後なら何もしない)。
    if (manager != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          manager.close(viewerFowId);
        } catch (_) {
          // マネージャーが先に破棄されている(テストの終了時など)。
        }
      });
    }
    for (final v in _sessions.values) {
      v.dispose();
    }
    _overlays.dispose();
    _ctrl.dispose();
    _page.dispose();
    _barrier.dispose();
    super.dispose();
  }

  void _openPanel() {
    final manager = ref.read(overlayManagerProvider);
    _manager = manager;
    _specOrNull ??= _createSpec();
    manager.showFow<void>(
      id: viewerFowId,
      spec: _spec,
      semanticsLabel: context.l10n.mediaViewerSemantics,
      barrierBehavior: OverlayBarrierBehavior.dismiss,
      onBarrierTap: _collapse,
      barrierEnabled: _barrier,
      builder: (_, _) => _ViewerPanel(slideAt: _slide, page: _page, sessionOf: _session, isOpen: (i) => _gate(i) == _ViewerGate.open, spec: _spec),
    );
  }

  /// 展開中だけバリア(外側タップで折りたたみ)。折りたたみ中は背面(ページ送り / 動画のタップ)を触れる。
  void _syncBarrier() {
    final stops = _spec.heightStops;
    final mid = stops.length >= 2 ? (stops.first + stops.last) / 2 : (viewerFowCollapsedFactor + viewerFowExpandedFactor) / 2;
    final expanded = _spec.heightFactor.value >= mid;
    if (_barrier.value != expanded) {
      _barrier.value = expanded;
      _manager?.requestRebuild();
    }
  }

  /// 全画面アクションバー (D-212 → D-214): ヘッダーの「…」の左に、`viewer:<accountKey>` の構成で詰めて並べる。
  /// バンドルはアイコンから出る FOW。全画面表示プラグインのトグル(`slot:<id>:viewer.overlay`)もこのバーの
  /// ボタン(ON = 塗り / アクセント。動画の再生中は出さない)。
  List<Widget> _viewerActionBar() {
    final post = _post;
    // RASQ の投稿 (D-276) には、SNS のアクションは効かないので出さない。
    final session = isRasqPost(post) ? null : ref.watch(sessionForAccountProvider(post.account.key)) ?? ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final viewerPlugins = ref.watch(viewerPluginActionsProvider);
    if (actions.isEmpty && viewerPlugins.isEmpty) return const [];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    final i = _page.value;
    final m = _mediaAt(i);
    final playing = m.type == MediaType.video && (_sessions[i]?.playing ?? false);
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(ActionBarConfigStore.viewerKey(post.account.key))),
      snsActions: actions,
      plugins: [...ref.watch(pluginActionsProvider), ...viewerPlugins],
      settings: ref.watch(slotActionSettingsProvider(post.account.key)),
      prefs: ref.watch(actionButtonPrefsProvider),
    );
    final entries = merged.config.apply(merged.actions);
    Future<void> perform(ActionDescriptor a) => isViewerToggleActionId(a.id) ? _toggleViewerPlugin(viewerTogglePluginId(a.id)) : notifier.perform(post, a).catchError((_) {});
    Widget toggle(ActionDescriptor a) {
      final id = viewerTogglePluginId(a.id);
      final action = viewerPlugins.where((p) => p.id == a.id).firstOrNull;
      return ViewerPluginToggle(
        pluginId: id,
        label: a.label,
        iconName: a.icon,
        // ON / OFF はこの全画面限り(契約 v0.14 temp)。長押しで「次からも自動でオン / オフ」。
        enabled: _overlays.isOn(id),
        status: _overlays.statusOf(i, id),
        onPressed: () => perform(a),
        onLongPress: action == null ? null : (anchor) => showActionTempMenu(ref, anchor: anchor, action: action),
      );
    }
    return [
      for (final e in entries)
        if (!(playing && e is SingleActionEntry && isViewerToggleActionId(e.action.id))) ...[
          const SizedBox(width: 2),
          switch (e) {
            SingleActionEntry() when isViewerToggleActionId(e.action.id) => toggle(e.action),
            SingleActionEntry() => _Circle(child: RasqIconButton(key: ValueKey('viewer.action.${e.action.id}'), icon: PostRow.iconFor(e.action.icon, Icons.circle_outlined), color: Colors.white, tooltip: e.action.label, onPressed: () => perform(e.action))),
            ActionListEntry() => Builder(
                builder: (bctx) => _Circle(
                  child: Tooltip(
                    message: e.list.name,
                    child: InkResponse(
                      key: ValueKey('viewer.action.list:${e.list.id}'),
                      radius: 22,
                      onTap: () {
                        final box = bctx.findRenderObject() as RenderBox;
                        showActionBundleMenuFow(ref, anchor: box.localToGlobal(Offset.zero) & box.size, entry: e, onPick: perform);
                      },
                      child: SizedBox(width: 40, height: 40, child: Center(child: bundleIconWidget(e.list, e.members, size: 22, color: Colors.white))),
                    ),
                  ),
                ),
              ),
          },
        ],
      const SizedBox(width: RasqSpacing.xs),
    ];
  }

  /// 全画面表示プラグインの ON / OFF (D-207 → D-214 → D-246 → D-305): この全画面限り(保存しない)。失敗中はやり直し。
  Future<void> _toggleViewerPlugin(String pluginId) async {
    final i = _page.value;
    final m = _mediaAt(i);
    // クッションの下の 1 枚は渡さない(開いたときに [_reveal] が渡す、D-510)。
    final url = _gate(i) != _ViewerGate.open ? null : m.type == MediaType.video ? m.thumbnailUrl : (m.type == MediaType.image || m.type == MediaType.gif ? m.url : null);
    await _overlays.toggle(pluginId, i, url);
    if (mounted) setState(() {});
  }

  /// PiP (D-204): ビューワーを閉じてインライン再生 FOW を同じ位置から開く。
  void _toPip() {
    final i = _page.value;
    final m = _mediaAt(i);
    if (m.type != MediaType.video || _gate(i) != _ViewerGate.open) return;
    final manager = ref.read(overlayManagerProvider);
    final at = VideoPrefs.pipKeepPosition ? _sessions[i]?.position : null; // 再生位置の引き継ぎ (D-238 の設定)
    final post = _post;
    Navigator.of(context).maybePop();
    WidgetsBinding.instance.addPostFrameCallback((_) => showVideoFowWith(manager, m, post: post, startAt: at));
  }

  /// クッションの面 (D-510): サムネイル(動画はサムネイル、画像は本体)をぼかした上に、文言と「表示する」。
  /// 外せない面は何も読まない(黒地に文言だけ)。
  Widget _cushionPage(int i, MediaItem m, {required bool locked}) {
    final thumb = m.thumbnailUrl ?? (m.type == MediaType.image || m.type == MediaType.gif ? m.url : null);
    return Stack(key: ValueKey('viewer.cushion.${m.id}'), fit: StackFit.expand, children: [
      if (!locked && thumb != null) Image.network(webHtmlElementStrategy: rasqWebImageStrategy, thumb.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
      Positioned.fill(child: RasqSensitiveCushion(large: true, onReveal: locked ? null : () => _reveal(i))),
    ]);
  }

  void _collapse() {
    _spec.userResized = false;
    _spec.heightFactor.value = _spec.heightStops.isEmpty ? viewerFowCollapsedFactor : _spec.heightStops.first;
  }

  void _askOverlay(int i) {
    if (i < 0 || i >= _slides.length) return;
    // クッションの下の 1 枚はプラグインへ渡さない(開いたら渡す、D-510)。
    if (_gate(i) != _ViewerGate.open) return;
    final m = _mediaAt(i);
    if (m.type == MediaType.video) {
      // 全画面表示プラグインが**オン**なら再生を止め(D-202 → D-326: 登録があるだけでは止めない = 自動再生)、
      // サムネイルを渡す(再生中のフレームの取り出しは後段)。
      if (!ref.read(viewerOverlayPluginsProvider).any((p) => _overlays.isOn(p.id))) return;
      _session(i).hold = true;
      final thumb = m.thumbnailUrl;
      if (thumb != null) _overlays.ask(i, thumb);
      return;
    }
    if (m.type != MediaType.image && m.type != MediaType.gif) return;
    _overlays.ask(i, m.url);
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;
    final slide = _slide(_page.value);
    final manager = ref.watch(overlayManagerProvider);
    // 閲覧注意の設定 / 開いた記録が変わったら描き直す (D-510)。
    ref.watch(safetySettingsProvider);
    ref.watch(mediaRevealProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // FOW の逆サイドへ寄せる余白 (D-326): 伸び縮みに追従するので短めのアニメ。
        AnimatedPadding(
          key: viewerMediaInsetKey,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: _fowInset,
          // 上下に引っ張って閉じる (D-566): 面を指に付けて動かし、離すと閉じる / 戻る。
          child: AnimatedContainer(
            duration: _swiping ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _swipeDy, 0),
            transformAlignment: Alignment.center,
            child: Listener(
              // 拡大中にパンの限界を越えて引いたぶん (D-566)。拡大していないときは下の縦ドラッグが受ける。
              onPointerDown: _onZoomedPointerDown,
              onPointerMove: _onZoomedPointerMove,
              onPointerUp: _onZoomedPointerUp,
              onPointerCancel: _onZoomedPointerUp,
              child: GestureDetector(
                // タップ (D-203): 下側の FOW が消えていれば開き直す(開く手段が無くならないように)。出ていれば上のクロームの表示切替。
                // 動画の面のタップでは再生を止めない。
                onTap: () {
                  if (!manager.contains(viewerFowId)) {
                    _openPanel();
                    return;
                  }
                  setState(() => _chrome = !_chrome);
                },
                // 拡大中は InteractiveViewer のパンに譲る(登録しない)。
                onVerticalDragUpdate: _zoomed ? null : _onSwipeUpdate,
                onVerticalDragEnd: _zoomed ? null : _onSwipeEnd,
                onVerticalDragCancel: _zoomed ? null : _resetSwipe,
                child: LayoutBuilder(builder: (context, c) {
                  _viewportH = c.maxHeight;
                  return PageView.builder(
                    controller: _ctrl,
                    itemCount: _slides.length,
                    onPageChanged: (i) {
                      for (final e in _sessions.entries) {
                        if (e.key != i) e.value.pause();
                      }
                      _page.value = i;
                      setState(() {});
                      _syncZoomed(i);
                      _askOverlay(i);
                      final m = _mediaAt(i);
                      // 動画と音声は開くと自動再生 (D-326)。クッションの下では押すまで再生しない (D-510)。
                      if ((m.type == MediaType.video || isAudioMedia(m)) && _gate(i) == _ViewerGate.open) _session(i).play();
                      // 読み込み済みの端に近づいたら続きを (D-565)。
                      unawaited(_maybeExtend(i));
                    },
                    itemBuilder: (_, i) {
                      final m = _mediaAt(i);
                      final gate = _gate(i);
                      if (gate != _ViewerGate.open) return _cushionPage(i, m, locked: gate == _ViewerGate.locked);
                      return InteractiveViewer(
                        key: ValueKey('viewer.page.${_slide(i).post.key}.${_slide(i).media}'),
                        transformationController: _zoomOf(i),
                        minScale: 1,
                        maxScale: 5,
                        child: Center(
                          child: isAudioMedia(m)
                              // 音声 (D-326): 音符の面。再生は動画と同じセッション、操作は下側の FOW。
                              ? _AudioFace(key: ValueKey('viewer.audio.${m.id}'), item: m, session: _session(i))
                              : m.type == MediaType.file
                                  ? Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 64), Text(m.fileName ?? '', style: const TextStyle(color: Colors.white))])
                                  : m.type == MediaType.video
                                      // 動画 (D-200 → D-201): 面はタップで再生 / 一時停止。操作は下側の FOW。
                                      ? RasqVideoView(key: ValueKey('viewer.video.${m.id}'), session: _session(i), tapToggles: false)
                                      : _overlays.wrap(i, Image.network(webHtmlElementStrategy: rasqWebImageStrategy, m.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48))),
                        ),
                      );
                    },
                  );
                }),
              ),
            ),
          ),
        ),
        if (_chrome)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(RasqSpacing.sm),
              // ヘッダー (D-213 → D-214): 上付き、全部同じ 40px の丸ボタン。左から 戻る / 枚数 / 全画面
              // アクションバー(プラグインのトグル込み) / PiP / 「…」。右側のボタンは右端に寄せる: バーを
              // Flexible にすると使い切らない余白が末尾に残って右端から離れるので、幅の上限を LayoutBuilder で
              // 計算して枚数の Expanded に残りを渡す。
              child: LayoutBuilder(builder: (context, c) {
                final video = _mediaAt(_page.value).type == MediaType.video && _gate(_page.value) == _ViewerGate.open;
                final fixed = 40.0 + 2 + 40 + (video ? 42 : 0) + 56; // 戻る / … / PiP / 枚数の最低幅
                final barMax = math.max(0.0, c.maxWidth - fixed);
                return Row(children: [
                  _Circle(child: RasqIconButton(icon: Icons.arrow_back_ios_new, size: 18, color: Colors.white, onPressed: () => Navigator.of(context).maybePop(), tooltip: context.l10n.mediaViewerBack)),
                  // 枚数はいま見ている投稿の中で (D-565: 投稿をまたいでも、その投稿の何枚目か)。
                  Expanded(child: post.media.length > 1 ? Text('${slide.media + 1} / ${post.media.length}', key: const ValueKey('viewer.count'), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center) : const SizedBox.shrink()),
                  // 全画面アクションバー (D-212 → D-214): `viewer:<accountKey>` の構成。全画面表示プラグインの
                  // トグルもこのバーのボタン(編集画面で並べ替え / 削除 / 検索)。狭ければ横スクロール。
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: barMax),
                    child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: Row(mainAxisSize: MainAxisSize.min, children: _viewerActionBar())),
                  ),
                  // PiP (D-204): 動画のとき。
                  if (video) ...[
                    const SizedBox(width: 2),
                    _Circle(child: RasqIconButton(key: const ValueKey('viewer.pip'), icon: Icons.picture_in_picture_alt_outlined, color: Colors.white, tooltip: context.l10n.mediaViewerPip, onPressed: _toPip)),
                  ],
                  const SizedBox(width: 2),
                  // 「…」(D-213): 投稿のメニューに準拠(詳細の代わりに「画像を保存」)。
                  Builder(
                    builder: (ctx) => _Circle(
                      child: RasqIconButton(
                        icon: Icons.more_horiz,
                        color: Colors.white,
                        tooltip: context.l10n.mediaViewerMenu,
                        onPressed: () {
                          final box = ctx.findRenderObject() as RenderBox;
                          final rect = box.localToGlobal(Offset.zero) & box.size;
                          // クッションの下の 1 枚は保存させない (D-510)。
                          showPostMenu(ctx, ref, post, rect, media: _gate(_page.value) == _ViewerGate.open ? _mediaAt(_page.value) : null);
                        },
                      ),
                    ),
                  ),
                ]);
              }),
            ),
          ),
      ]),
    );
  }
}

/// 全画面表示の 1 枚の見せ方 (D-510)。
enum _ViewerGate {
  /// そのまま見せる。
  open,

  /// センシティブ / 注釈(CW): 押すまでクッション。
  cushion,

  /// セーフモード / 見守り中でタイルから取り除いたもの: 外せないクッション。
  locked,
}

/// 下側の FOW の中身 (D-202 → D-569): **投稿アクションバー付き FOW**。上辺に**その投稿の実物のアクションバー**
/// (タイムラインの投稿と同じ [PostRow] のバー。リアクションのピッカー / リノートのバンドルは押したボタンにつながって出る。
/// 以前はバーの複製(押すと実行するだけのボタン列)を置いていた)/ [動画の操作] / [投稿のインライン表示(添付は無し)]。
/// 折りたたみの段は上 2 つの実測高さに合わせる(AsTell のルーム FOW と同じ作法)。
/// 投稿をまたいでスワイプしたら (D-565)、いま見ている 1 枚の投稿に替わる。
class _ViewerPanel extends ConsumerStatefulWidget {
  const _ViewerPanel({required this.slideAt, required this.page, required this.sessionOf, required this.isOpen, required this.spec});
  final ViewerSlide Function(int) slideAt;
  final ValueListenable<int> page;
  final VideoSession Function(int) sessionOf;

  /// その 1 枚がクッションの下でないか (D-510)。クッションの下の動画 / 音声には操作を出さない(押すまで再生させない)。
  final bool Function(int) isOpen;
  final FowSpec spec;
  @override
  ConsumerState<_ViewerPanel> createState() => _ViewerPanelState();
}

/// 下側の FOW の上辺のアクションバー(テストが読む)。
const viewerPanelBarKey = ValueKey('viewer.panel.bar');

class _ViewerPanelState extends ConsumerState<_ViewerPanel> {
  final _topKey = GlobalKey();

  /// FOW のクローム(ハンドル + 余白)ぶん。
  static const _chromeHeight = kFowHandleHeight + 12;

  @override
  void initState() {
    super.initState();
    widget.page.addListener(_onPage);
  }

  @override
  void didUpdateWidget(covariant _ViewerPanel old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) {
      old.page.removeListener(_onPage);
      widget.page.addListener(_onPage);
    }
  }

  @override
  void dispose() {
    widget.page.removeListener(_onPage);
    super.dispose();
  }

  void _onPage() {
    if (mounted) setState(() {});
  }

  void _syncCollapsedStop(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final spec = widget.spec;
      final box = _topKey.currentContext?.findRenderObject() as RenderBox?;
      final host = MediaQuery.sizeOf(context).height;
      if (box == null || !box.hasSize || host <= 0) return;
      // 展開の段は作ったときの値(上側のボタン群に被さらない範囲、D-329)。
      final expanded = spec.heightStops.length >= 2 ? spec.heightStops.last : math.min(viewerFowExpandedFactor, spec.maxHeightFactor);
      final fit = ((box.size.height + _chromeHeight) / host).clamp(spec.minHeightFactor, expanded - 0.05);
      final current = spec.heightStops.isEmpty ? viewerFowCollapsedFactor : spec.heightStops.first;
      if ((fit - current).abs() < 0.003) return;
      spec.heightStops = [fit, expanded];
      if ((spec.heightFactor.value - current).abs() < 0.01) spec.heightFactor.value = fit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.page.value;
    final slide = widget.slideAt(i);
    final post = slide.post;
    final m = slide.media < post.media.length ? post.media[slide.media] : null;
    // アクションは投稿が流れてきたアカウントのもの (D-200)。無ければ現在のアカウント。
    // RASQ の投稿 (D-276) には、SNS のアクションは効かないので出さない。
    final session = isRasqPost(post) ? null : ref.watch(sessionForAccountProvider(post.account.key)) ?? ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    // クッションを外したら操作を出し直す (D-510)。
    ref.watch(mediaRevealProvider.select((s) => s[post.key]));
    _syncCollapsedStop(context);
    final controls = m != null && (m.type == MediaType.video || isAudioMedia(m)) && widget.isOpen(i);
    // 折りたたみの段の実測前 / 過渡期に上のブロックが枠より高くてもはみ出さない(スクロールに逃がす)。
    return ListView(key: viewerPanelKey, padding: EdgeInsets.zero, children: [
      // 投稿のインライン表示(添付はビューワー本体にあるので出さない)。バーは投稿の上 = FOW の上辺 (D-569)。
      PostRow(
        key: ValueKey('viewer.post.${post.key}'),
        post: post,
        actions: actions,
        onAction: (a, {args = const {}}) => notifier.perform(post, a, args: args),
        onTap: () => context.pushPost(post),
        hideMedia: true,
        actionBarAbove: (bar) => Column(key: _topKey, mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (bar != null) KeyedSubtree(key: viewerPanelBarKey, child: bar),
          // 動画 / 音声の操作 (D-201 → D-202、音声は D-326): 左にシークバー、右にボタン類(小画面では下の行)。
          if (controls) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm), child: VideoControls(session: widget.sessionOf(i))),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        ]),
      ),
    ]);
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle), child: child);
}

/// 音声の面 (D-326): 音符(再生中は波形)+ ファイル名。再生は動画と同じ [VideoSession](開くと自動再生)、操作は
/// 下側の FOW の [VideoControls]。再生できない環境(テスト / 未対応形式)は案内。
class _AudioFace extends StatelessWidget {
  const _AudioFace({super.key, required this.item, required this.session});
  final MediaItem item;
  final VideoSession session;

  @override
  Widget build(BuildContext context) {
    final name = item.fileName ?? (item.url.pathSegments.isEmpty ? '' : item.url.pathSegments.last);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.all(RasqSpacing.page),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(session.playing ? Icons.graphic_eq : Icons.music_note, color: Colors.white70, size: 96),
          const SizedBox(height: RasqSpacing.sm),
          Text(name, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          if (session.error != null)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.sm),
              child: Text(session.error!, key: const ValueKey('viewer.audio.error'), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
            ),
        ]),
      ),
    );
  }
}
