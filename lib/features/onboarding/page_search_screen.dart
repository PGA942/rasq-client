import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/link_match_api.dart' show LinkMatchAccount;
import '../../backend/onboarding_discover_api.dart';
import '../../backend/rasq_account_page_api.dart' show RasqAccountPost, rasqAccountPageApiProvider;
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../plugins/media_plugin_panel.dart' show MediaEditResult;
import '../plugins/pro_media_editor_screen.dart' show ProMediaEditorArgs, ProMediaEditorScreen;
import 'discover_history.dart';
import 'export_discover_screen.dart' show LinkMatchAccountCard;
import 'page_search.dart';
import 'sns_discover_screen.dart' show DiscoverResultsView;
import 'web_snapshot.dart';

/// アプリの中のブラウザの「この画面を探す」(D-552)。
///
/// ページの写しのプレビュー(**長さのスライダー**つき)→ 探したい部分を**いくつでも囲む** → 囲みをタップすると FOW
/// (検索文字列を直す / 文字か画像か / 画像エディターで開く / 消す。キャンセル = 巻き戻し、決定 = 確定)→「探す」。
/// 探す中身は `page_search.dart`。

/// 画像エディターを開く口(テストで差し替える)。直した画像を返す(閉じたら null)。
typedef PageRegionImageEditor = Future<Uint8List?> Function(BuildContext context, Uint8List png);

final pageRegionImageEditorProvider = Provider<PageRegionImageEditor>((ref) => (context, png) async {
      final r = await Navigator.of(context).push<MediaEditResult>(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ProMediaEditorScreen(args: ProMediaEditorArgs(bytes: png, name: 'region.png', mimeType: 'image/png')),
      ));
      return r?.bytes;
    });

/// 「この画面を探す」を開く。
Future<void> openDiscoverPageSearch(BuildContext context, PageSnapshot snapshot) =>
    Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => DiscoverPageSelectScreen(snapshot: snapshot)));

enum _Mode { draw, scroll }

class DiscoverPageSelectScreen extends ConsumerStatefulWidget {
  const DiscoverPageSelectScreen({super.key, required this.snapshot});
  final PageSnapshot snapshot;
  @override
  ConsumerState<DiscoverPageSelectScreen> createState() => _DiscoverPageSelectScreenState();
}

class _DiscoverPageSelectScreenState extends ConsumerState<DiscoverPageSelectScreen> {
  final _scroll = ScrollController();
  final _regions = <PageRegion>[];
  int _seq = 0;
  _Mode _mode = _Mode.draw;

  /// 見せる長さ(ページの座標)。
  late double _length = math.min(widget.snapshot.height, widget.snapshot.viewportHeight * 2);

  /// いま引いている囲み(ページの座標)。
  Offset? _dragFrom;
  Rect? _dragging;
  bool _busy = false;
  String? _notice;

  PageSnapshot get _snap => widget.snapshot;
  int get _imageCount => _regions.where((r) => r.byImage).length;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _endDrag() {
    final r = _dragging;
    setState(() {
      _dragFrom = null;
      _dragging = null;
      if (r == null || r.width < 16 || r.height < 16) return;
      if (_regions.length >= pageSearchMaxRegions) {
        _notice = context.l10n.onboardingPageSearchRegionsFull(pageSearchMaxRegions);
        return;
      }
      final text = pageRegionText(_snap.texts, r);
      // 文字が無い囲みは画像で(画像が撮れていて、枠が残っていれば)。
      _regions.add(PageRegion(id: _seq++, rect: r, query: text, byImage: text.isEmpty && _snap.hasImage && _imageCount < pageSearchMaxImages));
      _notice = null;
    });
  }

  void _setLength(double v) => setState(() {
        _length = v;
        // 短くして外に出た囲みは消す。
        _regions.removeWhere((r) => r.rect.top >= v);
      });

  /// 囲みをタップ: FOW で直す。**キャンセル(余白 / esc も)= 開いたときの状態へ巻き戻し、決定 = 確定**(絵文字ピッカーの作法)。
  Future<void> _editRegion(int id) async {
    final i = _regions.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final before = _regions[i];
    final l10n = context.l10n;
    void apply(PageRegion next) {
      final k = _regions.indexWhere((r) => r.id == id);
      if (k >= 0 && mounted) setState(() => _regions[k] = next);
    }

    final result = await ref.read(overlayManagerProvider).showFow<Object>(
          id: 'discover.page.region',
          spec: FowSpec(initialHeightFactor: 0.42, minHeightFactor: 0.25, maxHeightFactor: 0.8, title: l10n.onboardingPageSearchRegionTitle(i + 1), cancelText: l10n.onboardingPageSearchRegionCancel, confirmText: l10n.onboardingPageSearchRegionConfirm),
          semanticsLabel: l10n.onboardingPageSearchRegionTitle(i + 1),
          barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
          builder: (ctx, handle) => _RegionPanel(
            region: before,
            canImage: _snap.hasImage,
            imageRoom: before.byImage || _imageCount < pageSearchMaxImages,
            onChanged: apply,
            onOpenEditor: () => handle.close(result: 'edit'),
            onDelete: () => handle.close(result: 'delete'),
          ),
        );
    if (!mounted) return;
    switch (result) {
      case true:
        break; // そのまま確定。
      case 'delete':
        setState(() => _regions.removeWhere((r) => r.id == id));
      case 'edit':
        await _openEditor(id);
      default:
        apply(before); // 巻き戻し。
    }
  }

  /// 囲みを切り抜いて画像エディターで開く。保存したら、その画像で探す。
  Future<void> _openEditor(int id) async {
    final i = _regions.indexWhere((r) => r.id == id);
    if (i < 0) return;
    final region = _regions[i];
    final png = region.edited ?? await cropPageSnapshot(_snap, region.rect);
    if (png == null || !mounted) return;
    final edited = await ref.read(pageRegionImageEditorProvider)(context, png);
    if (edited == null || !mounted) return;
    final k = _regions.indexWhere((r) => r.id == id);
    if (k >= 0) setState(() => _regions[k] = _regions[k].copyWith(edited: edited, byImage: true));
  }

  Future<void> _search() async {
    final discover = ref.read(onboardingDiscoverApiProvider);
    final page = ref.read(rasqAccountPageApiProvider);
    if (discover == null || page == null) {
      setState(() => _notice = context.l10n.onboardingDiscoverNoCentral);
      return;
    }
    final regions = [for (final r in _regions) if (r.searchable) r];
    if (regions.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final inputs = <PageSearchInput>[];
      for (final r in regions) {
        if (!r.byImage) {
          inputs.add(PageSearchInput.text(r.query));
          continue;
        }
        final png = r.edited ?? await cropPageSnapshot(_snap, r.rect);
        if (png != null) inputs.add(PageSearchInput.image(png));
      }
      final outcome = await runPageSearch(
        inputs: inputs,
        url: _snap.url,
        content: ({frames = const [], text, url}) => discover.content(frames: frames, source: frames.isEmpty ? null : 'browser', text: text, url: url),
        searchAccounts: (t) => page.searchAccounts(t, limit: 5),
        searchPosts: (t) async => (await page.searchPosts(t, limit: 5)).posts,
      );
      // 探した言葉を控える (D-553)。
      unawaited(ref.read(discoverHistoryProvider.notifier).record(outcome.terms, DiscoverHistorySource.page));
      if (!mounted) return;
      await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => DiscoverPageResultsScreen(outcome: outcome)));
    } catch (e) {
      debugPrint('page search: $e');
      if (mounted) setState(() => _notice = context.l10n.onboardingDiscoverSearchFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final snap = _snap;
    final minLength = math.min(snap.height, snap.viewportHeight / 2);
    final searchable = _regions.where((r) => r.searchable).length;
    return Scaffold(
      appBar: RasqPageHeader(title: l10n.onboardingPageSearchTitle, showMore: false, onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        top: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm, 0),
            child: Row(children: [
              Text(l10n.onboardingPageSearchLengthLabel, style: caption),
              Expanded(
                child: Slider(
                  key: const ValueKey('discover.page.length'),
                  value: _length.clamp(minLength, snap.height),
                  min: minLength,
                  max: math.max(snap.height, minLength + 1),
                  onChanged: snap.height > minLength && !_busy ? _setLength : null,
                ),
              ),
              SegmentedButton<_Mode>(
                key: const ValueKey('discover.page.mode'),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: _Mode.draw, icon: const Icon(Icons.crop_free, size: 16), label: Text(l10n.onboardingPageSearchModeDraw)),
                  ButtonSegment(value: _Mode.scroll, icon: const Icon(Icons.swipe_vertical, size: 16), label: Text(l10n.onboardingPageSearchModeScroll)),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
            child: Text(snap.hasImage ? l10n.onboardingPageSearchHint : l10n.onboardingPageSearchSketchNote, key: const ValueKey('discover.page.hint'), style: caption),
          ),
          const SizedBox(height: RasqSpacing.xs),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final shown = math.min(box.maxWidth, 640.0);
              final k = shown / snap.width;
              Offset toPage(Offset local) => Offset((local.dx / k).clamp(0.0, snap.width), (local.dy / k).clamp(0.0, _length));
              return Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                  key: const ValueKey('discover.page.scroll'),
                  controller: _scroll,
                  physics: _mode == _Mode.scroll ? null : const NeverScrollableScrollPhysics(),
                  child: Center(
                    child: SizedBox(
                      width: shown,
                      height: _length * k,
                      child: GestureDetector(
                        key: const ValueKey('discover.page.canvas'),
                        behavior: HitTestBehavior.opaque,
                        onPanStart: _mode == _Mode.draw && !_busy ? (d) => setState(() => _dragFrom = toPage(d.localPosition)) : null,
                        onPanUpdate: _mode == _Mode.draw && !_busy
                            ? (d) {
                                final from = _dragFrom;
                                if (from != null) setState(() => _dragging = Rect.fromPoints(from, toPage(d.localPosition)));
                              }
                            : null,
                        onPanEnd: _mode == _Mode.draw && !_busy ? (_) => _endDrag() : null,
                        child: Stack(clipBehavior: Clip.hardEdge, children: [
                          Positioned.fill(child: RepaintBoundary(child: ClipRect(child: CustomPaint(painter: _PagePainter(snap, k, scheme))))),
                          for (final (i, r) in _regions.indexed)
                            Positioned(
                              left: r.rect.left * k,
                              top: r.rect.top * k,
                              width: r.rect.width * k,
                              height: r.rect.height * k,
                              child: GestureDetector(
                                key: ValueKey('discover.page.region.${r.id}'),
                                onTap: _busy ? null : () => _editRegion(r.id),
                                child: _RegionBox(index: i + 1, region: r),
                              ),
                            ),
                          if (_dragging != null)
                            Positioned(
                              left: _dragging!.left * k,
                              top: _dragging!.top * k,
                              width: _dragging!.width * k,
                              height: _dragging!.height * k,
                              child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(color: RasqColors.sub.withValues(alpha: 0.12), border: Border.all(color: RasqColors.sub, width: 2)))),
                            ),
                        ]),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.sm),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              if (_notice != null) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.xs), child: Text(_notice!, key: const ValueKey('discover.page.notice'), style: caption)),
              FilledButton.icon(
                key: const ValueKey('discover.page.search'),
                onPressed: searchable == 0 || _busy ? null : _search,
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search, size: 18),
                label: Text(l10n.onboardingPageSearchButton(searchable)),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// ページの絵: 写しがあればそれを、無ければ文字の位置だけの見取り図。
class _PagePainter extends CustomPainter {
  _PagePainter(this.snapshot, this.k, this.scheme);
  final PageSnapshot snapshot;
  final double k;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final image = snapshot.image;
    if (image != null) {
      canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), Rect.fromLTWH(0, 0, snapshot.width * k, snapshot.height * k), Paint()..filterQuality = FilterQuality.medium);
      return;
    }
    canvas.drawRect(Offset.zero & size, Paint()..color = scheme.surface);
    final box = Paint()..color = scheme.onSurface.withValues(alpha: 0.06);
    var drawn = 0;
    for (final t in snapshot.texts) {
      if (t.rect.top * k > size.height || drawn >= 600) break;
      final r = Rect.fromLTWH(t.rect.left * k, t.rect.top * k, t.rect.width * k, t.rect.height * k);
      canvas.drawRect(r, box);
      final tp = TextPainter(
        text: TextSpan(text: t.text, style: TextStyle(color: scheme.onSurface, fontSize: (r.height * 0.7).clamp(7.0, 16.0))),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: math.max(8, r.width));
      tp.paint(canvas, r.topLeft);
      tp.dispose();
      drawn++;
    }
  }

  @override
  bool shouldRepaint(_PagePainter old) => old.snapshot != snapshot || old.k != k || old.scheme != scheme;
}

/// 囲みの枠(番号と、文字 / 画像の印)。
class _RegionBox extends StatelessWidget {
  const _RegionBox({required this.index, required this.region});
  final int index;
  final PageRegion region;

  @override
  Widget build(BuildContext context) {
    final ok = region.searchable;
    final color = ok ? RasqColors.sub : Theme.of(context).colorScheme.error;
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), border: Border.all(color: color, width: 2), borderRadius: BorderRadius.circular(4)),
      child: Align(
        alignment: Alignment.topLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          color: color,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('$index', style: RasqTypography.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            const SizedBox(width: 2),
            Icon(region.byImage ? Icons.image_outlined : Icons.text_fields, size: 12, color: Colors.white),
          ]),
        ),
      ),
    );
  }
}

/// 囲みの FOW の中身。直すたびに [onChanged] で画面へ反映する(キャンセルなら呼んだ側が巻き戻す)。
class _RegionPanel extends StatefulWidget {
  const _RegionPanel({required this.region, required this.canImage, required this.imageRoom, required this.onChanged, required this.onOpenEditor, required this.onDelete});
  final PageRegion region;

  /// ページの写しがある(画像で探せる / 画像エディターを開ける)。
  final bool canImage;

  /// 画像で探す枠が残っている。
  final bool imageRoom;
  final ValueChanged<PageRegion> onChanged;
  final VoidCallback onOpenEditor;
  final VoidCallback onDelete;
  @override
  State<_RegionPanel> createState() => _RegionPanelState();
}

class _RegionPanelState extends State<_RegionPanel> {
  late PageRegion _region = widget.region;
  late final _query = TextEditingController(text: widget.region.query);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _set(PageRegion next) {
    setState(() => _region = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
      SegmentedButton<bool>(
        key: const ValueKey('discover.page.region.kind'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(value: false, icon: const Icon(Icons.text_fields, size: 16), label: Text(l10n.onboardingPageSearchByText)),
          ButtonSegment(value: true, icon: const Icon(Icons.image_outlined, size: 16), label: Text(l10n.onboardingPageSearchByImage), enabled: widget.canImage && widget.imageRoom),
        ],
        selected: {_region.byImage},
        onSelectionChanged: (s) => _set(_region.copyWith(byImage: s.first)),
      ),
      if (widget.canImage && !widget.imageRoom) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(l10n.onboardingPageSearchTooManyImages(pageSearchMaxImages), style: caption)),
      const SizedBox(height: RasqSpacing.sm),
      TextField(
        key: const ValueKey('discover.page.region.query'),
        controller: _query,
        enabled: !_region.byImage,
        minLines: 1,
        maxLines: 3,
        maxLength: 200,
        decoration: InputDecoration(isDense: true, labelText: l10n.onboardingPageSearchQueryLabel, hintText: l10n.onboardingPageSearchQueryHint),
        onChanged: (v) => _set(_region.copyWith(query: v)),
      ),
      if (_region.edited != null) Text(l10n.onboardingPageSearchEdited, key: const ValueKey('discover.page.region.edited'), style: caption),
      const SizedBox(height: RasqSpacing.xs),
      Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
        OutlinedButton.icon(
          key: const ValueKey('discover.page.region.editor'),
          onPressed: widget.canImage && (widget.imageRoom || _region.byImage) ? widget.onOpenEditor : null,
          icon: const Icon(Icons.brush_outlined, size: 18),
          label: Text(l10n.onboardingPageSearchOpenEditor),
        ),
        TextButton.icon(
          key: const ValueKey('discover.page.region.delete'),
          onPressed: widget.onDelete,
          icon: Icon(Icons.delete_outline, size: 18, color: scheme.error),
          label: Text(l10n.onboardingPageSearchDelete, style: TextStyle(color: scheme.error)),
        ),
      ]),
    ]);
  }
}

/// 探した結果: RASQ のユーザー → RASQ の投稿 → RASQ リスト / サーバー。
class DiscoverPageResultsScreen extends ConsumerWidget {
  const DiscoverPageResultsScreen({super.key, required this.outcome});
  final PageSearchOutcome outcome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final bold = RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700);
    final o = outcome;
    return Scaffold(
      appBar: RasqPageHeader(title: l10n.onboardingPageSearchResultsTitle, showMore: false, onBack: () => Navigator.of(context).pop()),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(key: const ValueKey('discover.page.results'), padding: const EdgeInsets.all(RasqSpacing.page), children: [
              if (o.terms.isNotEmpty) ...[
                Text(l10n.onboardingPageSearchTermsHeading, style: bold),
                const SizedBox(height: RasqSpacing.xs),
                Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [for (final t in o.terms) Chip(key: ValueKey('discover.page.term.$t'), label: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis), visualDensity: VisualDensity.compact)]),
                const SizedBox(height: RasqSpacing.sm),
              ],
              if (o.failedImages > 0) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), child: Text(l10n.onboardingPageSearchImagesFailed(o.failedImages), key: const ValueKey('discover.page.imagesFailed'), style: caption)),
              if (o.isEmpty) Text(l10n.onboardingDiscoverNoResults, key: const ValueKey('discover.page.empty'), style: caption),
              if (o.accounts.isNotEmpty) ...[
                Text(l10n.onboardingPageSearchUsersHeading, style: bold),
                const SizedBox(height: RasqSpacing.xs),
                for (final a in o.accounts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RasqSpacing.xs),
                    child: LinkMatchAccountCard(account: LinkMatchAccount(id: a.id, handle: a.handle, displayName: a.displayName, avatarUrl: a.avatarUrl)),
                  ),
                const SizedBox(height: RasqSpacing.sm),
              ],
              if (o.posts.isNotEmpty) ...[
                Text(l10n.onboardingPageSearchPostsHeading, style: bold),
                const SizedBox(height: RasqSpacing.xs),
                for (final p in o.posts) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.xs), child: _PostCard(post: p)),
                const SizedBox(height: RasqSpacing.sm),
              ],
              if (o.lists.isNotEmpty || o.servers.isNotEmpty) DiscoverResultsView(result: DiscoverResult(lists: o.lists, servers: o.servers, mode: o.dummy ? 'dummy' : '')),
            ]),
          ),
        ),
      ),
    );
  }
}

/// RASQ の投稿のカード。タップで、ログインしていれば投稿、まだなら書いた人のページ。
class _PostCard extends ConsumerWidget {
  const _PostCard({required this.post});
  final RasqAccountPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final author = post.author;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd), side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('discover.page.post.${post.id}'),
        onTap: () {
          final loggedIn = ref.read(sessionsProvider).value?.isLoggedIn ?? false;
          if (loggedIn) {
            context.push(Routes.rasqPost(post.id));
          } else if (author != null) {
            context.push(Routes.snsDiscoverAccount(author.handle));
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(RasqSpacing.sm),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (author != null) Text('${author.label}  @${author.handle}', style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(post.cw.isNotEmpty ? post.cw : post.body, style: RasqTypography.bodySmall, maxLines: 4, overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}
