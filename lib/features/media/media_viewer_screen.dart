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
import '../home/action_bar_config.dart';
import '../home/action_bundle_fow.dart';
import '../home/plugin_actions.dart';
import '../home/post_row.dart';
import '../post/post_menu.dart';
import '../home/timeline_providers.dart';
import '../plugins/slot_plugins.dart';
import 'video_player.dart';
import 'viewer_plugin_overlay.dart';

/// 全画面表示(画像/動画): 黒背景、PageView、戻る/…。
/// 下側はダークモードの FOW (D-202): 動画の操作(左にシークバー、右にボタン類)/ アクションバー /
/// 投稿のインライン表示。AsTell のルーム FOW と同じ作法で動く: 折りたたみ(操作 + アクションバー)と
/// 展開(投稿まで)の 2 段、外側タップで折りたたみ(閉じない)、折りたたみ中はバリア無しで背面を触れる。
/// 動画は開くと自動再生、全画面表示プラグインが起動するときは止める。
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

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  late final PageController _ctrl = PageController(initialPage: widget.initialIndex);
  late final ValueNotifier<int> _page = ValueNotifier(widget.initialIndex);

  /// 動画のセッション(ページごと、D-201)。ページを離れると一時停止、開くと自動再生 (D-202)。
  final _sessions = <int, VideoSession>{};
  VideoSession _session(int i) => _sessions.putIfAbsent(i, () => VideoSession(widget.post.media[i], autoplay: true));
  bool _chrome = true;

  /// 下側の FOW (D-202)。
  late final FowSpec _spec = FowSpec(
    initialHeightFactor: viewerFowCollapsedFactor,
    minHeightFactor: 0.08,
    maxHeightFactor: 0.92,
    heightStops: const [viewerFowCollapsedFactor, viewerFowExpandedFactor],
    freeAboveStops: true,
    theme: (_) => RasqTheme.dark(),
  );
  final _barrier = ValueNotifier<bool>(false);
  OverlayManager? _manager;

  /// 全画面表示プラグイン (D-167 / D-178 で共通化): 画像ごとの重ねとトークン。
  late final ViewerPluginOverlays _overlays = ViewerPluginOverlays(ref, onChanged: () {
    if (mounted) setState(() {});
  });

  /// FOW のぶんメディアを寄せる余白(FOW が出現 / 消失したときだけ測る。途中のサイズ変更は追わない)。
  EdgeInsets _fowInset = EdgeInsets.zero;
  Set<String> _fowIds = const {};

  /// FOW が出る / 消えるたびにメディアを**空いているスペース**へ寄せる (D-207 → D-215)。ホストが置いた矩形
  /// (`FowSpec.laidOut`)を次のフレームで読み、幅の広い FOW は上下、狭い FOW(壁付け / カラム)は左右の余白に
  /// する。残りが小さすぎる側は寄せない(被さるほうがまし)。
  void _onOverlays() {
    final manager = _manager;
    if (!mounted || manager == null) return;
    final ids = {for (final e in manager.entries) if (e.fow != null) e.id};
    if (ids.length == _fowIds.length && ids.containsAll(_fowIds)) return;
    _fowIds = ids;
    // 矩形はホストの build で決まるので 1 フレーム後に読む。
    WidgetsBinding.instance.addPostFrameCallback((_) => _relayoutForFows());
  }

  void _relayoutForFows() {
    final manager = _manager;
    if (!mounted || manager == null) return;
    final screen = MediaQuery.sizeOf(context);
    var top = 0.0, bottom = 0.0, left = 0.0, right = 0.0;
    for (final e in manager.entries) {
      final r = e.fow?.laidOut;
      if (e.fow == null || r == null) continue;
      if (r.width >= screen.width * 0.6) {
        if (r.center.dy < screen.height / 2) {
          top = math.max(top, r.bottom);
        } else {
          bottom = math.max(bottom, screen.height - r.top);
        }
      } else if (r.center.dx < screen.width / 2) {
        left = math.max(left, r.right);
      } else {
        right = math.max(right, screen.width - r.left);
      }
    }
    // 残りが 160px を切る軸は寄せない。
    if (screen.height - top - bottom < 160) {
      top = 0;
      bottom = 0;
    }
    if (screen.width - left - right < 160) {
      left = 0;
      right = 0;
    }
    final inset = EdgeInsets.fromLTRB(left, top, right, bottom);
    if (inset != _fowInset) setState(() => _fowInset = inset);
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
    _spec.heightFactor.addListener(_syncBarrier);
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

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRoute);
    _manager?.removeListener(_onOverlays);
    _spec.heightFactor.removeListener(_syncBarrier);
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
    final session = ref.watch(sessionForAccountProvider(post.account.key)) ?? ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final viewerPlugins = ref.watch(viewerPluginActionsProvider);
    if (actions.isEmpty && viewerPlugins.isEmpty) return const [];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    final i = _page.value;
    final m = post.media[i];
    final playing = m.type == MediaType.video && (_sessions[i]?.playing ?? false);
    final enabled = {for (final p in ref.watch(viewerOverlayPluginsProvider)) p.id};
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(ActionBarConfigStore.viewerKey(post.account.key))),
      snsActions: actions,
      plugins: [...ref.watch(pluginActionsProvider), ...viewerPlugins],
      settings: ref.watch(slotActionSettingsProvider(post.account.key)),
    );
    final entries = merged.config.apply(merged.actions);
    Future<void> perform(ActionDescriptor a) => isViewerToggleActionId(a.id) ? _toggleViewerPlugin(viewerTogglePluginId(a.id)) : notifier.perform(post, a).catchError((_) {});
    Widget toggle(ActionDescriptor a) {
      final id = viewerTogglePluginId(a.id);
      return ViewerPluginToggle(pluginId: id, label: a.label, enabled: enabled.contains(id), status: _overlays.statusOf(i, id), onPressed: () => perform(a));
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

  /// 全画面表示プラグインの ON / OFF (D-207 → D-214 → D-246): 状態は `slots.viewer` に保存。失敗中はやり直し。
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
      // 全画面表示プラグインが登録されていれば再生を止め(D-202)、サムネイルを渡す
      // (再生中のフレームの取り出しは後段)。
      if (ref.read(slotPluginsForProvider(SlotIds.viewerOverlay)).isEmpty) return;
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
        AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: _fowInset,
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
          child: PageView.builder(
            controller: _ctrl,
            itemCount: post.media.length,
            onPageChanged: (i) {
              for (final e in _sessions.entries) {
                if (e.key != i) e.value.pause();
              }
              _page.value = i;
              setState(() {});
              _askOverlay(i);
              if (post.media[i].type == MediaType.video) _session(i).play();
            },
            itemBuilder: (_, i) {
              final m = post.media[i];
              return InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: m.type == MediaType.file
                      ? Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 64), Text(m.fileName ?? '', style: const TextStyle(color: Colors.white))])
                      : m.type == MediaType.video
                          // 動画 (D-200 → D-201): 面はタップで再生 / 一時停止。操作は下側の FOW。
                          ? RasqVideoView(key: ValueKey('viewer.video.${m.id}'), session: _session(i), tapToggles: false)
                          : _overlays.wrap(i, Image.network(m.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48))),
                ),
              );
            },
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
      final fit = ((box.size.height + _chromeHeight) / host).clamp(spec.minHeightFactor, viewerFowExpandedFactor - 0.05);
      final current = spec.heightStops.isEmpty ? viewerFowCollapsedFactor : spec.heightStops.first;
      if ((fit - current).abs() < 0.003) return;
      spec.heightStops = [fit, viewerFowExpandedFactor];
      if ((spec.heightFactor.value - current).abs() < 0.01) spec.heightFactor.value = fit;
    });
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    // アクションは投稿が流れてきたアカウントのもの (D-200)。無ければ現在のアカウント。
    final session = ref.watch(sessionForAccountProvider(post.account.key)) ?? ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(TimelineKind.home).notifier);
    // 下側の FOW のバーは投稿アクションバーそのまま (D-212: 全画面アクションバーはヘッダーの「…」の左)。
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(post.account.key)),
      snsActions: actions,
      plugins: ref.watch(pluginActionsProvider),
      settings: ref.watch(slotActionSettingsProvider(post.account.key)),
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
            // 動画の操作 (D-201 → D-202): 左にシークバー、右にボタン類(小画面では下の行)。
            if (m != null && m.type == MediaType.video) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm), child: VideoControls(session: widget.sessionOf(i))),
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
