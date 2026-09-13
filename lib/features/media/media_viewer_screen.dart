import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../home/post_row.dart';
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

  @override
  void initState() {
    super.initState();
    _spec.heightFactor.addListener(_syncBarrier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _askOverlay(_page.value);
      _openPanel();
    });
  }

  @override
  void dispose() {
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
        GestureDetector(
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
        if (_chrome)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(RasqSpacing.sm),
              child: Row(children: [
                _Circle(child: RasqIconButton(icon: Icons.arrow_back_ios_new, size: 18, color: Colors.white, onPressed: () => Navigator.of(context).maybePop(), tooltip: '戻る')),
                const Spacer(),
                if (post.media.length > 1) Text('${_page.value + 1} / ${post.media.length}', style: const TextStyle(color: Colors.white70)),
                const Spacer(),
                Builder(
                  builder: (ctx) => _Circle(
                    child: RasqIconButton(
                      icon: Icons.more_horiz,
                      color: Colors.white,
                      tooltip: 'メニュー',
                      onPressed: () async {
                        final box = ctx.findRenderObject() as RenderBox;
                        final rect = box.localToGlobal(Offset.zero) & box.size;
                        final m = post.media[_page.value];
                        await manager.showDropdown<String>(id: 'viewer.menu', anchor: rect, items: [
                          const RasqDropdownItem('リンクをコピー', 'copy'),
                          if (m.type == MediaType.video) const RasqDropdownItem('オーバーレイに移動', 'pip'),
                          if (m.alt != null) const RasqDropdownItem('ALTを表示', 'alt'),
                        ]);
                      },
                    ),
                  ),
                ),
              ]),
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
              for (final a in actions)
                RasqActionButton.icon(icon: PostRow.iconFor(a.icon, Icons.circle_outlined), doneIcon: a.doneIcon == null ? null : PostRow.iconFor(a.doneIcon, Icons.circle), tooltip: a.label, onTap: () => notifier.perform(post, a).catchError((_) {})),
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
