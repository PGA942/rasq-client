import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/rasq_account_page_api.dart';
import '../home/action_bar_config.dart';
import '../home/action_bundle_fow.dart';
import 'fow_avoid.dart';
import '../home/plugin_actions.dart';
import '../home/post_row.dart';
import '../post/post_menu.dart';
import '../home/timeline_providers.dart';
import '../compose/post_video.dart' show isAudioMedia;
import 'video_player.dart';
import 'viewer_plugin_overlay.dart';

/// 全画面表示(画像/動画/音声): 黒背景、PageView、戻る/…。
/// 下側はダークモードの FOW (D-202、D-326 で下側**中央**・最大 600px): 動画の操作(左にシークバー、右にボタン類)/
/// アクションバー / 投稿のインライン表示。AsTell のルーム FOW と同じ作法で動く: 折りたたみ(操作 + アクションバー)と
/// 展開(投稿まで)の 2 段、外側タップで折りたたみ(閉じない)、折りたたみ中はバリア無しで背面を触れる。
/// FOW が伸び縮みする / 動くたびに、メディアは FOW の**逆サイド**へ寄る (D-326)。
/// 動画と音声は開くと自動再生(全画面表示プラグインが**オン**のときだけ止める)。**下向きスワイプで閉じる** (D-326)。
/// `…` → 「オーバーレイに移動」(動画のみ、VC・動画オーバーレイへ昇格 = M5 以降).
class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({super.key, required this.post, this.initialIndex = 0});
  final Post post;
  final int initialIndex;
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

/// 下向きスワイプで閉じる (D-326): この距離を超えて離すか、この速さ以上で下へ払うと閉じる。
const viewerSwipeCloseDistance = 120.0;
const viewerSwipeCloseVelocity = 700.0;

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  late final PageController _ctrl = PageController(initialPage: widget.initialIndex);
  late final ValueNotifier<int> _page = ValueNotifier(widget.initialIndex);

  /// 動画のセッション(ページごと、D-201)。ページを離れると一時停止、開くと自動再生 (D-202)。
  final _sessions = <int, VideoSession>{};
  VideoSession _session(int i) => _sessions.putIfAbsent(i, () => VideoSession(widget.post.media[i], autoplay: true));
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

  // ── 下向きスワイプで閉じる (D-326) ──

  /// 面を指に付けて下げ、離したときの距離 / 速さで閉じるか戻すか。拡大中は InteractiveViewer のパンに譲る
  /// (縦ドラッグのジェスチャーを登録しない)。
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
        _swipeDy = math.max(0, _swipeDy + d.delta.dy);
      });

  void _onSwipeEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? d.velocity.pixelsPerSecond.dy;
    if (_swipeDy >= viewerSwipeCloseDistance || (_swipeDy > 0 && v >= viewerSwipeCloseVelocity)) {
      Navigator.of(context).maybePop();
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
      semanticsLabel: '投稿',
      barrierBehavior: OverlayBarrierBehavior.dismiss,
      onBarrierTap: _collapse,
      barrierEnabled: _barrier,
      builder: (_, _) => _ViewerPanel(post: widget.post, page: _page, sessionOf: _session, spec: _spec),
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
    final post = widget.post;
    // RASQ の投稿 (D-276) には、SNS のアクションは効かないので出さない。
    final session = isRasqPost(post) ? null : ref.watch(sessionForAccountProvider(post.account.key)) ?? ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final viewerPlugins = ref.watch(viewerPluginActionsProvider);
    if (actions.isEmpty && viewerPlugins.isEmpty) return const [];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    final i = _page.value;
    final m = post.media[i];
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
    final m = widget.post.media[i];
    final url = m.type == MediaType.video ? m.thumbnailUrl : (m.type == MediaType.image || m.type == MediaType.gif ? m.url : null);
    await _overlays.toggle(pluginId, i, url);
    if (mounted) setState(() {});
  }

  /// PiP (D-204): ビューワーを閉じてインライン再生 FOW を同じ位置から開く。
  void _toPip() {
    final i = _page.value;
    final m = widget.post.media[i];
    if (m.type != MediaType.video) return;
    final manager = ref.read(overlayManagerProvider);
    final at = VideoPrefs.pipKeepPosition ? _sessions[i]?.position : null; // 再生位置の引き継ぎ (D-238 の設定)
    Navigator.of(context).maybePop();
    WidgetsBinding.instance.addPostFrameCallback((_) => showVideoFowWith(manager, m, post: widget.post, startAt: at));
  }

  void _collapse() {
    _spec.userResized = false;
    _spec.heightFactor.value = _spec.heightStops.isEmpty ? viewerFowCollapsedFactor : _spec.heightStops.first;
  }

  void _askOverlay(int i) {
    if (i >= widget.post.media.length) return;
    final m = widget.post.media[i];
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
    final post = widget.post;
    final manager = ref.watch(overlayManagerProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // FOW の逆サイドへ寄せる余白 (D-326): 伸び縮みに追従するので短めのアニメ。
        AnimatedPadding(
          key: viewerMediaInsetKey,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          padding: _fowInset,
          // 下向きスワイプ (D-326): 面を指に付けて下げ、離すと閉じる / 戻る。
          child: AnimatedContainer(
            duration: _swiping ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(0, _swipeDy, 0),
            transformAlignment: Alignment.center,
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
              child: PageView.builder(
                controller: _ctrl,
                itemCount: post.media.length,
                onPageChanged: (i) {
                  for (final e in _sessions.entries) {
                    if (e.key != i) e.value.pause();
                  }
                  _page.value = i;
                  setState(() {});
                  _syncZoomed(i);
                  _askOverlay(i);
                  final m = post.media[i];
                  // 動画と音声は開くと自動再生 (D-326)。
                  if (m.type == MediaType.video || isAudioMedia(m)) _session(i).play();
                },
                itemBuilder: (_, i) {
                  final m = post.media[i];
                  return InteractiveViewer(
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
                final video = post.media[_page.value].type == MediaType.video;
                final fixed = 40.0 + 2 + 40 + (video ? 42 : 0) + 56; // 戻る / … / PiP / 枚数の最低幅
                final barMax = math.max(0.0, c.maxWidth - fixed);
                return Row(children: [
                  _Circle(child: RasqIconButton(icon: Icons.arrow_back_ios_new, size: 18, color: Colors.white, onPressed: () => Navigator.of(context).maybePop(), tooltip: '戻る')),
                  Expanded(child: post.media.length > 1 ? Text('${_page.value + 1} / ${post.media.length}', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center) : const SizedBox.shrink()),
                  // 全画面アクションバー (D-212 → D-214): `viewer:<accountKey>` の構成。全画面表示プラグインの
                  // トグルもこのバーのボタン(編集画面で並べ替え / 削除 / 検索)。狭ければ横スクロール。
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: barMax),
                    child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true, child: Row(mainAxisSize: MainAxisSize.min, children: _viewerActionBar())),
                  ),
                  // PiP (D-204): 動画のとき。
                  if (video) ...[
                    const SizedBox(width: 2),
                    _Circle(child: RasqIconButton(key: const ValueKey('viewer.pip'), icon: Icons.picture_in_picture_alt_outlined, color: Colors.white, tooltip: 'PiP で再生', onPressed: _toPip)),
                  ],
                  const SizedBox(width: 2),
                  // 「…」(D-213): 投稿のメニューに準拠(詳細の代わりに「画像を保存」)。
                  Builder(
                    builder: (ctx) => _Circle(
                      child: RasqIconButton(
                        icon: Icons.more_horiz,
                        color: Colors.white,
                        tooltip: 'メニュー',
                        onPressed: () {
                          final box = ctx.findRenderObject() as RenderBox;
                          final rect = box.localToGlobal(Offset.zero) & box.size;
                          final m = post.media[_page.value];
                          showPostMenu(ctx, ref, post, rect, media: m);
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

/// 下側の FOW の中身 (D-202): [動画の操作] / [アクションバー] / [投稿のインライン表示(添付は無し)]。
/// 折りたたみの段は上 2 つの実測高さに合わせる(AsTell のルーム FOW と同じ作法)。
class _ViewerPanel extends ConsumerStatefulWidget {
  const _ViewerPanel({required this.post, required this.page, required this.sessionOf, required this.spec});
  final Post post;
  final ValueListenable<int> page;
  final VideoSession Function(int) sessionOf;
  final FowSpec spec;
  @override
  ConsumerState<_ViewerPanel> createState() => _ViewerPanelState();
}

class _ViewerPanelState extends ConsumerState<_ViewerPanel> {
  final _topKey = GlobalKey();

  /// FOW のクローム(ハンドル + 余白)ぶん。
  static const _chromeHeight = kFowHandleHeight + 12;

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
    final post = widget.post;
    // アクションは投稿が流れてきたアカウントのもの (D-200)。無ければ現在のアカウント。
    // RASQ の投稿 (D-276) には、SNS のアクションは効かないので出さない。
    final session = isRasqPost(post) ? null : ref.watch(sessionForAccountProvider(post.account.key)) ?? ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    // 下側の FOW のバーは投稿アクションバーそのまま (D-212: 全画面アクションバーはヘッダーの「…」の左)。
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(post.account.key)),
      snsActions: actions,
      plugins: ref.watch(pluginActionsProvider),
      settings: ref.watch(slotActionSettingsProvider(post.account.key)),
      prefs: ref.watch(actionButtonPrefsProvider),
    );
    final entries = merged.config.apply(merged.actions);
    return ValueListenableBuilder<int>(
      key: viewerPanelKey,
      valueListenable: widget.page,
      builder: (context, i, _) {
        final m = i < post.media.length ? post.media[i] : null;
        _syncCollapsedStop(context);
        // 折りたたみの段の実測前 / 過渡期に上のブロックが枠より高くてもはみ出さない(スクロールに逃がす)。
        return ListView(padding: EdgeInsets.zero, children: [
          Column(key: _topKey, mainAxisSize: MainAxisSize.min, children: [
            // 動画 / 音声の操作 (D-201 → D-202、音声は D-326): 左にシークバー、右にボタン類(小画面では下の行)。
            if (m != null && (m.type == MediaType.video || isAudioMedia(m))) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm), child: VideoControls(session: widget.sessionOf(i))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final e in entries)
                switch (e) {
                  SingleActionEntry() => RasqActionButton.icon(icon: PostRow.iconFor(e.action.icon, Icons.circle_outlined), doneIcon: e.action.doneIcon == null ? null : PostRow.iconFor(e.action.doneIcon, Icons.circle), tooltip: e.action.label, onTap: () => notifier.perform(post, e.action).catchError((_) {})),
                  // バンドル: アイコンから出る FOW (D-210)。
                  ActionListEntry() => Builder(
                      key: ValueKey('viewer.bundle.${e.list.id}'),
                      builder: (bctx) => RasqActionButton.icon(
                        icon: bundleIconOf(e.list, e.members),
                        tooltip: e.list.name,
                        onTap: () {
                          final box = bctx.findRenderObject() as RenderBox;
                          showActionBundleMenuFow(ref, anchor: box.localToGlobal(Offset.zero) & box.size, entry: e, onPick: (a) => notifier.perform(post, a).catchError((_) {}));
                        },
                      ),
                    ),
                },
              RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {}),
            ]),
            Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          ]),
          // 投稿のインライン表示(添付はビューワー本体にあるので出さない)。
          PostRow(
            key: const ValueKey('viewer.post'),
            post: post,
            actions: const [],
            onAction: (a, {args = const {}}) => notifier.perform(post, a, args: args),
            onTap: () => context.pushPost(post),
            hideMedia: true,
          ),
        ]);
      },
    );
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
