import 'package:flutter/material.dart';

import 'fow.dart';
import 'overlay_entry.dart';
import 'overlay_layer.dart';
import 'overlay_manager.dart';

/// Convenience presets on top of [OverlayManager]. These are host-owned L4
/// surfaces; plugins reach them only through host functions (fow.open / alert).
extension OverlayPresets on OverlayManager {
  /// Bottom sheet with grab handle, optional title row (キャンセル / タイトル / 決定).
  Future<T?> showBottomSheet<T>({
    required String id,
    required WidgetBuilder builder,
    String? title,
    String? cancelText = 'キャンセル',
    String? confirmText,
    VoidCallback? onConfirm,
    String? ownerId,
    double? maxHeightFactor = 0.9,
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
                      TextButton(onPressed: handle.cancel, child: Text(cancelText, style: TextStyle(color: scheme.onSurfaceVariant)))
                    else
                      const SizedBox(width: 80),
                    Expanded(child: Center(child: Text(title ?? '', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)))),
                    if (confirmText != null)
                      TextButton(
                        onPressed: () {
                          onConfirm?.call();
                          handle.close(result: true);
                        },
                        child: Text(confirmText, style: TextStyle(color: scheme.primary)),
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
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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

  /// Function Override Widget: docked, resizable bottom panel.
  /// `builder` receives the handle so the content can close itself with a result.
  Future<T?> showFow<T>({
    required String id,
    required OverlayWidgetBuilder builder,
    FowSpec? spec,
    String? ownerId,
    String? semanticsLabel,
  }) async {
    final result = await show(RasqOverlayEntry(
      id: id,
      layer: OverlayLayer.fow,
      alignment: Alignment.bottomCenter,
      ownerId: ownerId,
      semanticsLabel: semanticsLabel ?? spec?.title,
      fow: spec ?? FowSpec(),
      builder: builder,
    ));
    return result as T?;
  }

  /// Dropdown menu anchored to a widget (長押しメニュー / ソート選択 / アカウント切替).
  /// [dense] = compact variant for small sort menus.
  Future<T?> showDropdown<T>({
    required String id,
    required Rect anchor,
    required List<RasqDropdownItem<T>> items,
    String? ownerId,
    bool dense = false,
  }) async {
    final result = await show(RasqOverlayEntry(
      id: id,
      layer: OverlayLayer.dropdown,
      anchor: anchor,
      ownerId: ownerId,
      builder: (context, handle) {
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          elevation: 6,
          child: IntrinsicWidth(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < items.length; i++) ...[
                InkWell(
                  onTap: items[i].enabled ? () => handle.close(result: items[i].value) : null,
                  child: Container(
                    constraints: BoxConstraints(minHeight: dense ? 34 : 44, minWidth: dense ? 120 : 160),
                    padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16),
                    alignment: Alignment.centerLeft,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (items[i].checked) Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.check, size: dense ? 14 : 18)),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: dense ? 12.5 : 14,
                          fontWeight: FontWeight.w600,
                          color: items[i].destructive ? scheme.error : (items[i].accent ? scheme.primary : scheme.onSurface),
                        ),
                      ),
                    ]),
                  ),
                ),
                if (i != items.length - 1) Divider(height: 1, color: scheme.outlineVariant),
              ],
            ]),
          ),
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
