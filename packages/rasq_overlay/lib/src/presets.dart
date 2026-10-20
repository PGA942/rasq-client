import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'fow.dart';
import 'overlay_entry.dart';
import 'overlay_layer.dart';
import 'overlay_l10n.dart';
import 'overlay_manager.dart';
import 'tethered_panel.dart';

/// Convenience presets on top of [OverlayManager]. These are host-owned L4
/// surfaces; plugins reach them only through host functions (fow.open / alert).
extension OverlayPresets on OverlayManager {
  /// Bottom sheet with grab handle, optional title row (キャンセル / タイトル / 決定).
  Future<T?> showBottomSheet<T>({
    required String id,
    required WidgetBuilder builder,
    String? title,
    String? cancelText = kOverlayDefaultCancel,
    String? confirmText,
    VoidCallback? onConfirm,
    String? ownerId,
    double? maxHeightFactor = 0.9,
    // false の間は確定ボタンを押せない(同意のチェックなど、中身がそろうまで進ませない)。
    ValueListenable<bool>? confirmEnabled,
  }) async {
    final result = await show(RasqOverlayEntry(
      id: id,
      layer: OverlayLayer.bottomSheet,
      alignment: Alignment.bottomCenter,
      ownerId: ownerId,
      semanticsLabel: title,
      builder: (context, handle) {
        final scheme = Theme.of(context).colorScheme;
        final media = MediaQuery.of(context);
        return Material(
          color: scheme.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: media.size.height * (maxHeightFactor ?? 0.9)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: scheme.onSurface, borderRadius: BorderRadius.circular(2))),
              if (title != null || cancelText != null || confirmText != null)
                SizedBox(
                  height: 44,
                  child: Row(children: [
                    if (cancelText != null)
                      TextButton(onPressed: handle.cancel, child: Text(overlayCancelLabel(context, cancelText), style: TextStyle(color: scheme.onSurfaceVariant)))
                    else
                      const SizedBox(width: 80),
                    Expanded(child: Center(child: Text(title ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)))),
                    if (confirmText != null)
                      ValueListenableBuilder<bool>(
                        valueListenable: confirmEnabled ?? const AlwaysStoppedAnimation(true),
                        builder: (context, enabled, _) => TextButton(
                          onPressed: enabled
                              ? () {
                                  onConfirm?.call();
                                  handle.close(result: true);
                                }
                              : null,
                          child: Text(confirmText, style: TextStyle(color: enabled ? scheme.primary : scheme.onSurfaceVariant)),
                        ),
                      )
                    else
                      const SizedBox(width: 80),
                  ]),
                ),
              Flexible(child: SafeArea(top: false, child: builder(context))),
            ]),
          ),
        );
      },
    ));
    return result as T?;
  }

  /// Alert / confirm dialog. Modal: barrier taps are ignored (明示的操作必須).
  Future<bool> showAlert({
    required String id,
    required String title,
    String? message,
    String confirmText = 'OK',
    String? cancelText,
    bool destructive = false,
    String? ownerId,
  }) async {
    final result = await show(RasqOverlayEntry(
      id: id,
      layer: OverlayLayer.modal,
      alignment: Alignment.center,
      ownerId: ownerId,
      semanticsLabel: title,
      builder: (context, handle) {
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                if (message != null) ...[const SizedBox(height: 8), Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center)],
                const SizedBox(height: 12),
                // 入りきらない長さの文言は縦に積む(横に並べると、はみ出す)。
                OverflowBar(alignment: MainAxisAlignment.end, overflowAlignment: OverflowBarAlignment.end, children: [
                  if (cancelText != null) TextButton(onPressed: () => handle.close(result: false), child: Text(cancelText)),
                  TextButton(
                    onPressed: () => handle.close(result: true),
                    child: Text(confirmText, style: TextStyle(color: destructive ? scheme.error : scheme.primary, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            ),
          ),
        );
      },
    ));
    return result == true;
  }

  /// 選択式のポップアップ (D-177): タイトル + 縦に並ぶ選択肢(下書きの「上書き / 新規保存 /
  /// 変更を破棄 / キャンセル」など)。選ばれた値を返す。[cancelText] の行と barrier 外は null。
  Future<T?> showChoiceAlert<T>({
    required String id,
    required String title,
    required List<RasqAlertChoice<T>> choices,
    String? message,
    String? cancelText = kOverlayDefaultCancel,
    String? ownerId,
  }) async {
    final result = await show(RasqOverlayEntry(
      id: id,
      layer: OverlayLayer.modal,
      alignment: Alignment.center,
      ownerId: ownerId,
      semanticsLabel: title,
      builder: (context, handle) {
        final scheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                if (message != null) ...[const SizedBox(height: 8), Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center)],
                const SizedBox(height: 12),
                for (final c in choices)
                  TextButton(
                    key: c.key,
                    onPressed: () => handle.close(result: c.value),
                    child: Text(c.label, style: TextStyle(color: c.destructive ? scheme.error : scheme.primary, fontWeight: c.primary ? FontWeight.w700 : FontWeight.w400)),
                  ),
                if (cancelText != null) TextButton(onPressed: handle.cancel, child: Text(overlayCancelLabel(context, cancelText), style: TextStyle(color: scheme.onSurfaceVariant))),
              ]),
            ),
          ),
        );
      },
    ));
    return result is T ? result : null;
  }

  /// Function Override Widget: docked, resizable bottom panel.
  /// `builder` receives the handle so the content can close itself with a result.
  Future<T?> showFow<T>({
    required String id,
    required OverlayWidgetBuilder builder,
    FowSpec? spec,
    String? ownerId,
    String? semanticsLabel,
    OverlayBarrierBehavior? barrierBehavior,
    VoidCallback? onBarrierTap,
    ValueListenable<bool>? barrierEnabled,
  }) async {
    final result = await show(RasqOverlayEntry(
      id: id,
      layer: OverlayLayer.fow,
      alignment: Alignment.bottomCenter,
      ownerId: ownerId,
      semanticsLabel: semanticsLabel ?? spec?.title,
      fow: spec ?? FowSpec(),
      barrierBehavior: barrierBehavior,
      onBarrierTap: onBarrierTap,
      barrierEnabled: barrierEnabled,
      builder: builder,
    ));
    return result as T?;
  }

  /// Dropdown menu anchored to a widget (長押しメニュー / ソート選択 / アカウント切替).
  /// [dense] = compact variant for small sort menus.
  ///
  /// [tetherAnchorChild] を渡すと、**ボタンにつながった形**([TetheredPanel]、D-513)で出す: 「…」などのボタンから開くメニュー。
  /// 渡すのは元のボタンのアイコン(パネルがボタンを覆うので、首の中に同じものを描く)。[tetherSide] = 開く側(入らなければ反対)。
  Future<T?> showDropdown<T>({
    required String id,
    required Rect anchor,
    required List<RasqDropdownItem<T>> items,
    String? ownerId,
    bool dense = false,
    Widget? tetherAnchorChild,
    TetherSide tetherSide = TetherSide.below,
  }) async {
    final tethered = tetherAnchorChild != null;
    final result = await show(RasqOverlayEntry(
      id: id,
      layer: OverlayLayer.dropdown,
      anchor: tethered ? null : anchor,
      ownerId: ownerId,
      builder: (context, handle) {
        final scheme = Theme.of(context).colorScheme;
        final list = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < items.length; i++) ...[
            InkWell(
              onTap: items[i].enabled ? () => handle.close(result: items[i].value) : null,
              child: Container(
                constraints: BoxConstraints(minHeight: dense ? 34 : 44, minWidth: dense ? 120 : 160),
                padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16),
                alignment: Alignment.centerLeft,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (items[i].checked) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check, size: dense ? 14 : 18)),
                  // 長いラベルは折り返す(はみ出しで overflow にしない)。
                  Flexible(
                    child: Text(
                      items[i].label,
                      style: TextStyle(
                        fontSize: dense ? 12.5 : 14,
                        fontWeight: FontWeight.w600,
                        color: items[i].destructive ? scheme.error : (items[i].accent ? scheme.primary : scheme.onSurface),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            if (i != items.length - 1) Divider(height: 1, color: scheme.outlineVariant),
          ],
        ]);
        if (tethered) {
          // ボタンにつながったメニュー (D-513): 首の下に項目を並べる。外 / 首のタップで閉じる。
          final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
          Widget panel(double t) => TetheredPanel(
                key: ValueKey('$id.tether'),
                anchor: anchor,
                width: dense ? 220 : 260,
                preferredSide: tetherSide,
                progress: t,
                anchorChild: tetherAnchorChild,
                onAnchorTap: handle.cancel,
                child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: SingleChildScrollView(child: list)),
              );
          return SizedBox.expand(
            child: still
                ? panel(1)
                : TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 140), curve: Curves.easeOutCubic, builder: (context, t, _) => panel(t)),
          );
        }
        return Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          elevation: 6,
          // 項目が多くて高さ上限を超えたらスクロール(はみ出しにしない、D-205)。
          child: IntrinsicWidth(child: SingleChildScrollView(child: list)),
        );
      },
    ));
    return result as T?;
  }
}

class RasqDropdownItem<T> {
  const RasqDropdownItem(this.label, this.value, {this.checked = false, this.destructive = false, this.accent = false, this.enabled = true});
  final String label;
  final T value;
  final bool checked;
  final bool destructive;
  final bool accent;
  final bool enabled;
}

/// [OverlayPresets.showChoiceAlert] の 1 行。
class RasqAlertChoice<T> {
  const RasqAlertChoice(this.label, this.value, {this.primary = false, this.destructive = false, this.key});
  final String label;
  final T value;

  /// 太字(既定の操作)。
  final bool primary;
  final bool destructive;
  final Key? key;
}
