import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/router.dart';
import '../ads/export_ad.dart';
import '../custom/custom_page.dart';
import '../media/video_player.dart';
import '../plugins/slot_plugins.dart';
import 'swing_models.dart';
import 'swing_providers.dart';

/// Swing のビューワー (D-377)。全画面、縦のスワイプで次の Swing(と広告)へ。
///
/// - 並びは作った人ごと([orderForViewer])。[startAuthor] があればその人の最初の Swing から。開いた時点のフィードで並べる
///   (見終えて手元から消えても、並びは変えない)。
/// - **見終えた** = スワイプでその Swing を離れた / 閉じた / プラグインが `page.end` を呼んだ。Central へ送り、その人には
///   二度と出ない。
/// - **広告**: Swing [adEvery] 個ごとに 1 枚(広告を出せる端末とアカウントだけ。出せなければ挟まない)。広告は見終えの記録なし。
/// - **プラグイン**(ページ型、surface `swing`、契約 v0.19): 全画面で動かし、その間は**スワイプで移れない**。
///   「全画面から縮小」を押すと、ぼかして止め(`page.event paused`)、スワイプで移れるようにする。縮小したものを押すと
///   全画面に戻る(`resumed`)。
class SwingViewerScreen extends ConsumerStatefulWidget {
  const SwingViewerScreen({super.key, this.startAuthor});

  /// 作った人の accountId。
  final String? startAuthor;

  static const adEvery = 5;

  @override
  ConsumerState<SwingViewerScreen> createState() => _SwingViewerScreenState();
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

/// Swing の並びに広告を挟む([every] 個ごと、最後には付けない)。
List<SwingViewerItem> interleaveAds(List<Swing> swings, {required bool ads, int every = SwingViewerScreen.adEvery}) => [
      for (var i = 0; i < swings.length; i++) ...[
        SwingViewerItem.swing(swings[i]),
        if (ads && (i + 1) % every == 0 && i + 1 < swings.length) const SwingViewerItem.ad(),
      ],
    ];

class _SwingViewerScreenState extends ConsumerState<SwingViewerScreen> {
  late final List<SwingViewerItem> _items;
  late final PageController _pages;
  int _index = 0;

  /// いまのプラグインが全画面で動いている(スワイプで移れない)。
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    final feed = orderForViewer(ref.read(swingFeedProvider).value ?? const []);
    final ads = ref.read(exportAdNetworkProvider) != null && ref.read(exportAdAllowedProvider);
    _items = interleaveAds(feed, ads: ads);
    final start = widget.startAuthor == null ? 0 : _items.indexWhere((x) => x.swing?.authorAccountId == widget.startAuthor);
    _index = start < 0 ? 0 : start;
    _pages = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
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
    if (s != null) unawaited(ref.read(swingFeedProvider.notifier).markSeen(s.id));
  }

  void _onPage(int i) {
    _seen(_index);
    setState(() {
      _index = i;
      _locked = false;
    });
  }

  /// 見終えて次へ(最後なら閉じる)。
  void _next() {
    if (_index + 1 < _items.length) {
      _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    } else {
      _close();
    }
  }

  void _close() {
    _seen(_index);
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
                const RasqEmptyView(key: ValueKey('swing.viewer.empty'), title: 'Swing はありません', hint: 'フォローしている人や、RASQ リストに入れてくれた人の Swing がここに流れます'),
                Positioned(top: 8, right: 8, child: SafeArea(child: RasqIconButton(icon: Icons.close, tooltip: '閉じる', color: Colors.white, onPressed: _close))),
              ])
            : PageView.builder(
                key: const ValueKey('swing.viewer.pages'),
                controller: _pages,
                scrollDirection: Axis.vertical,
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
                    position: '${i + 1} / ${_items.length}',
                    onClose: _close,
                    onLockChanged: (locked) {
                      if (i == _index) _setLocked(locked);
                    },
                    onEnd: () {
                      if (i == _index) _next();
                    },
                  );
                },
              ),
      ),
    );
  }
}

String swingRemainingLabel(Duration d) {
  if (d.inHours >= 1) return 'あと ${d.inHours} 時間';
  if (d.inMinutes >= 1) return 'あと ${d.inMinutes} 分';
  return 'まもなく消えます';
}

class _SwingPage extends StatelessWidget {
  const _SwingPage({super.key, required this.swing, required this.active, required this.position, required this.onClose, required this.onLockChanged, required this.onEnd});
  final Swing swing;
  final bool active;
  final String position;
  final VoidCallback onClose;
  final ValueChanged<bool> onLockChanged;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final body = switch (swing.kind) {
      SwingKind.text => _TextBody(text: swing.text),
      SwingKind.image => _ImageBody(swing: swing),
      SwingKind.video => _VideoBody(swing: swing, active: active),
      SwingKind.plugin => _PluginBody(swing: swing, active: active, onLockChanged: onLockChanged, onEnd: onEnd),
    };
    return Stack(fit: StackFit.expand, children: [
      body,
      // 上: 作った人と残り時間、閉じる。
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
                child: Row(children: [
                  RasqAvatar(imageUrl: swing.author.avatarUrl, size: 32, fallbackLabel: swing.author.displayName),
                  const SizedBox(width: RasqSpacing.sm),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(swing.author.displayName, key: const ValueKey('swing.author'), style: RasqTypography.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${swingRemainingLabel(swing.remaining(DateTime.now()))} ・ $position', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                    ]),
                  ),
                  RasqIconButton(key: const ValueKey('swing.close'), icon: Icons.close, tooltip: '閉じる', color: Colors.white, onPressed: onClose),
                ]),
              ),
            ),
          ),
      ),
      // 画像 / 動画に添えた文。
      if (swing.kind != SwingKind.text && swing.kind != SwingKind.plugin && swing.text.isNotEmpty)
        Positioned(
          left: RasqSpacing.page,
          right: RasqSpacing.page,
          bottom: RasqSpacing.xxl,
          child: Text(swing.text, key: const ValueKey('swing.caption'), style: RasqTypography.body.copyWith(color: Colors.white, shadows: const [Shadow(blurRadius: 6)])),
        ),
    ]);
  }
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
  const _VideoBody({required this.swing, required this.active});
  final Swing swing;
  final bool active;

  @override
  State<_VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<_VideoBody> {
  VideoSession? _session;

  @override
  void initState() {
    super.initState();
    final url = widget.swing.mediaUrl;
    if (url != null) _session = VideoSession(MediaItem(id: widget.swing.id, type: MediaType.video, url: url), autoplay: widget.active);
  }

  @override
  void didUpdateWidget(_VideoBody old) {
    super.didUpdateWidget(old);
    // 別のページへ移ったら止める。
    final c = _session?.controller;
    if (c != null && old.active && !widget.active) c.pause();
    if (c != null && !old.active && widget.active) c.play();
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
        context: {
          'swingId': widget.swing.id,
          'data': ?p.data,
          'author': {'accountId': widget.swing.authorAccountId, 'handle': widget.swing.author.account.handle, 'displayName': widget.swing.author.displayName},
        },
      ),
      size: MediaQuery.sizeOf(context),
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
      case CustomPagePhase.needsInstall || CustomPagePhase.needsConsent:
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
      host: RrlHost(instanceScope: controller.document?.scope ?? p.id, scope: RrlScope({}), geometry: controller.geometry, onEvent: c.onRrlEvent),
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
