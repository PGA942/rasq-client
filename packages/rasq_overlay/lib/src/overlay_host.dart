import 'package:flutter/material.dart';

import 'fow.dart';
import 'overlay_entry.dart';
import 'overlay_layer.dart';
import 'overlay_manager.dart';

/// Renders the content plus every open overlay, honouring layer z-order,
/// scrims and barrier behaviour. Place it once at the root of the app shell.
class OverlayHost extends StatelessWidget {
  const OverlayHost({super.key, required this.manager, required this.child, this.scrimColor, this.fowDockInset});

  final OverlayManager manager;
  final Widget child;
  final Color? scrimColor;

  /// [FowSpec.dockAboveFooter] な FOW の根本を持ち上げる量(= アプリの
  /// フッターメニュー高さ)。レイアウトを知るアプリ側が供給する (D-047)。
  final double Function(BuildContext context)? fowDockInset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final entries = manager.entries;
        return PopScope(
          canPop: !entries.any((e) => e.effectiveBarrierBehavior != OverlayBarrierBehavior.none),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) manager.handleBack();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              for (final e in entries)
                if (e.layer == OverlayLayer.fow) ...[
                  // FOW group is rendered once, at the position of the first FOW entry.
                  if (entries.firstWhere((x) => x.layer == OverlayLayer.fow) == e) ..._buildFowGroup(context, entries.where((x) => x.layer == OverlayLayer.fow).toList()),
                ] else
                  ..._buildEntry(context, e),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildEntry(BuildContext context, RasqOverlayEntry e) {
    final widgets = <Widget>[];
    final behavior = e.effectiveBarrierBehavior;
    if (behavior != OverlayBarrierBehavior.none) {
      widgets.add(Positioned.fill(
        child: Semantics(
          label: behavior == OverlayBarrierBehavior.ignore ? null : '閉じる',
          button: behavior != OverlayBarrierBehavior.ignore,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => manager.barrierTapped(e.id),
            child: e.layer.hasScrim
                ? ColoredBox(color: scrimColor ?? Colors.black.withValues(alpha: 0.35))
                : const SizedBox.expand(),
          ),
        ),
      ));
    }

    final handle = manager.handleFor(e);
    Widget content = Builder(builder: (ctx) => e.builder(ctx, handle));
    if (e.semanticsLabel != null) {
      content = Semantics(label: e.semanticsLabel, container: true, child: content);
    }

    if (e.layer == OverlayLayer.dropdown && e.anchor != null) {
      widgets.add(_AnchoredDropdown(anchor: e.anchor!, child: content));
    } else {
      widgets.add(Positioned.fill(child: Align(alignment: e.alignment, child: content)));
    }
    return widgets;
  }

  /// FOWs dock to the bottom as a bottom-up column: newest at the bottom.
  /// A scrim is painted once, behind the topmost interstitial (if any).
  List<Widget> _buildFowGroup(BuildContext context, List<RasqOverlayEntry> fows) {
    final widgets = <Widget>[];
    final blocking = fows.lastWhere((e) => e.effectiveBarrierBehavior != OverlayBarrierBehavior.none, orElse: () => fows.first);
    if (blocking.effectiveBarrierBehavior != OverlayBarrierBehavior.none) {
      // グレーアウト(スクリム)はインタースティシャル(+ボタンの投稿
      // コンポーザー等)のときだけ (D-052)。ピッカー類の「余白クリックで
      // 消失」は**透明バリア**で受ける(背面を暗くしない)。
      final dim = blocking.fow?.blocksContent ?? false;
      widgets.add(Positioned.fill(
        child: Semantics(
          label: '閉じる',
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => manager.barrierTapped(blocking.id),
            child: dim ? ColoredBox(color: scrimColor ?? Colors.black.withValues(alpha: 0.35)) : const SizedBox.expand(),
          ),
        ),
      ));
    }
    widgets.add(Positioned.fill(
      child: _FowColumn(
        dockInset: fowDockInset,
        entries: fows,
        buildContent: (e) {
          final handle = manager.handleFor(e);
          Widget content = Builder(builder: (ctx) => e.builder(ctx, handle));
          if (e.semanticsLabel != null) content = Semantics(label: e.semanticsLabel, container: true, child: content);
          return content;
        },
        onCancel: (e) => manager.close(e.id, reason: OverlayCloseReason.discard),
        onConfirm: (e) => manager.close(e.id, result: true),
      ),
    ));
    return widgets;
  }
}

/// Lays FOW panels out bottom-up. Heights come from each spec's heightFactor
/// and are scaled down proportionally when they would not fit.
class _FowColumn extends StatelessWidget {
  const _FowColumn({required this.entries, required this.buildContent, required this.onCancel, required this.onConfirm, this.dockInset});
  final List<RasqOverlayEntry> entries;
  final Widget Function(RasqOverlayEntry) buildContent;
  final void Function(RasqOverlayEntry) onCancel;
  final void Function(RasqOverlayEntry) onConfirm;
  final double Function(BuildContext context)? dockInset;

  @override
  Widget build(BuildContext context) {
    final ordered = entries.reversed.toList(); // newest first → placed at bottom
    return LayoutBuilder(builder: (context, constraints) {
      var insets = MediaQuery.viewInsetsOf(context).bottom;
      // stick FOW (D-047): キーボードが閉じている間はフッターメニューの上に
      // ドックする(キーボードが出たらその上 = 従来どおり)。
      if (insets == 0 && ordered.any((e) => e.fow?.dockAboveFooter == true)) {
        insets = dockInset?.call(context) ?? 0;
      }
      final avail = constraints.maxHeight - insets;
      return AnimatedBuilder(
        animation: Listenable.merge([for (final e in ordered) e.fow?.heightFactor].whereType<Listenable>().toList()),
        builder: (context, _) {
          final factors = [for (final e in ordered) (e.fow?.heightFactor.value ?? 0.45)];
          final total = factors.fold(0.0, (a, b) => a + b);
          final scale = total > 1 ? 1 / total : 1.0;
          final heights = [for (final f in factors) f * scale * avail];
          // Older entries are above; the newest sits at the very bottom.
          // OverflowBox: 高さアニメーション(D-049)の過渡期は合計が avail を
          // 一時的に超えることがある(古いパネルが縮む前に新しいパネルが
          // 目標高さで現れる)。上方向へ逃がして RenderFlex overflow にしない。
          // 幅 (D-057): FOW はページ幅または 1200px に合わせる — 広い画面では
          // 1200px を上限に中央寄せ(カラム別の幅追従は M5c のカラム間移行で)。
          return Padding(
            padding: EdgeInsets.only(bottom: insets),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: OverflowBox(
                  alignment: Alignment.bottomCenter,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = ordered.length - 1; i >= 0; i--)
                      // 最前面(最新)のパネルだけ影付き (D-052: 複数 FOW の判別)。
                      _FowPanel(entry: ordered[i], height: heights[i], frontmost: i == 0, child: buildContent(ordered[i]), onCancel: () => onCancel(ordered[i]), onConfirm: () => onConfirm(ordered[i])),
                  ]),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _FowPanel extends StatefulWidget {
  const _FowPanel({required this.entry, required this.height, required this.child, required this.onCancel, required this.onConfirm, this.frontmost = true});
  final RasqOverlayEntry entry;
  final double height;
  final Widget child;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  /// 最前面(操作対象)のパネルか。FOW の枠はグレーの線で描き、**影の有無で
  /// 最前面かどうかを判別**する (D-052: 複数 FOW を開いたときの識別)。
  final bool frontmost;

  @override
  State<_FowPanel> createState() => _FowPanelState();
}

class _FowPanelState extends State<_FowPanel> {
  /// ドラッグ中は高さを即時反映(追従遅延を出さない)。離したら
  /// [FowSpec.snapToStops] で最寄りの高さ段階へアニメーションで着地 (D-049)。
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final height = widget.height;
    final child = widget.child;
    final onCancel = widget.onCancel;
    final onConfirm = widget.onConfirm;
    final spec = entry.fow ?? FowSpec();
    final scheme = Theme.of(context).colorScheme;
    final hostHeight = MediaQuery.sizeOf(context).height;
    // 非リサイズパネル(stick コンポーザー等)は heightFactor 変更を
    // なめらかに(展開時にヘッダー/返信先タイルが「割り込んでくる」動き)。
    // ドラッグリサイズ可能なパネルは追従遅延を避けて即時反映。
    final panel = Material(
        color: scheme.surface,
        // 最前面のパネルだけ影付き(枠線は全パネル共通のグレー、D-052)。
        elevation: widget.frontmost ? 8 : 0,
        // FOW = ドラッグハンドル + **角丸四角形枠**の集合 (D-048)。フッターの
        // 上にドックする stick は内部フッター(アクションバー)が枠の下辺に
        // なるため下側も丸める。画面最下端まで覆う通常 FOW は上側のみ。
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: spec.dockAboveFooter ? BorderRadius.circular(16) : const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          if (spec.showHandle)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: spec.resizable ? (_) => setState(() => _dragging = true) : null,
              onVerticalDragUpdate: spec.resizable ? (d) => spec.resizeBy(d.delta.dy / hostHeight) : null,
              onVerticalDragEnd: spec.resizable
                  ? (_) {
                      setState(() => _dragging = false);
                      spec.snapToStops();
                    }
                  : null,
              onVerticalDragCancel: spec.resizable ? () => setState(() => _dragging = false) : null,
              child: Semantics(
                label: 'サイズ変更ハンドル',
                child: SizedBox(
                  height: 18,
                  width: double.infinity,
                  child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(2)))),
                ),
              ),
            ),
          if (spec.hasHeader)
            SizedBox(
              height: 40,
              child: Row(children: [
                if (spec.cancelText != null) TextButton(onPressed: onCancel, child: Text(spec.cancelText!, style: TextStyle(color: scheme.onSurfaceVariant))) else const SizedBox(width: 80),
                Expanded(child: Center(child: Text(spec.title ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis))),
                // 右側: headerTrailing(D-045: コンポーザーの公開設定など)>
                // 決定ボタン > 空きスペース。
                if (spec.headerTrailing != null)
                  spec.headerTrailing!
                else if (spec.confirmText != null)
                  TextButton(onPressed: onConfirm, child: Text(spec.confirmText!, style: TextStyle(color: scheme.primary)))
                else
                  const SizedBox(width: 80),
              ]),
            ),
          Expanded(child: child),
        ]),
      );
    // ドラッグ中は即時反映(duration 0)、それ以外(スナップ着地・stick の
    // 展開/折りたたみ・外部からの heightFactor 変更)はアニメーションで動かす。
    // ⚠ ウィジェット型は常に AnimatedContainer 1 種に固定する: SizedBox と
    // 切り替えると Element が作り直され、**入力中のテキストごと State が
    // 消える**(ハンドル操作で本文消失、D-050 で実測)。
    return ValueListenableBuilder<bool>(
      valueListenable: spec.dragging,
      builder: (context, innerDragging, child) => AnimatedContainer(
        duration: _dragging || innerDragging ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: height,
        child: child,
      ),
      child: panel,
    );
  }
}

/// Positions a dropdown next to its anchor, flipping horizontally/vertically
/// when it would overflow (「スクリーン端で位置反転」).
///
/// `LayoutBuilder → Positioned` の形は ParentDataWidget 違反(Positioned は
/// Stack の直下限定)で、開くたびに debug 例外が出ていた —
/// [CustomSingleChildLayout] のデリゲートで座標計算する形に修正 (D-039)。
class _AnchoredDropdown extends StatelessWidget {
  const _AnchoredDropdown({required this.anchor, required this.child});
  final Rect anchor;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
        child: CustomSingleChildLayout(delegate: _DropdownLayout(anchor), child: child),
      );
}

class _DropdownLayout extends SingleChildLayoutDelegate {
  const _DropdownLayout(this.anchor);
  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
        maxWidth: constraints.maxWidth * 0.8,
        maxHeight: constraints.maxHeight * 0.6,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final openDown = anchor.bottom + 200 <= size.height || anchor.top < size.height / 2;
    final openRight = anchor.left + 220 <= size.width;
    final top = openDown ? anchor.bottom : anchor.top - childSize.height;
    final left = openRight ? anchor.left : anchor.right - childSize.width;
    return Offset(
      left.clamp(0.0, (size.width - childSize.width).clamp(0.0, double.infinity)),
      top.clamp(0.0, (size.height - childSize.height).clamp(0.0, double.infinity)),
    );
  }

  @override
  bool shouldRelayout(_DropdownLayout oldDelegate) => oldDelegate.anchor != anchor;
}
