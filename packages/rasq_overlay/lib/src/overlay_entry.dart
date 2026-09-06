import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'fow.dart';
import 'overlay_layer.dart';

/// Why an entry was closed.
enum OverlayCloseReason {
  /// Closed programmatically with a result (confirm / save).
  completed,

  /// Cancel button / barrier tap on a discard-layer → changes discarded.
  discard,

  /// Replaced by another exclusive entry in the same layer
  /// (dropdown→dropdown, VC→別VC参加).
  replaced,

  /// Host removed it (route change, plugin crash, logout).
  host,
}

/// Callback that builds the overlay content. [close] dismisses this entry.
typedef OverlayWidgetBuilder = Widget Function(BuildContext context, OverlayHandle handle);

/// Handle passed to builders so the overlay can close itself.
class OverlayHandle {
  OverlayHandle._(this.id, this._close);
  final String id;
  final void Function(String id, {Object? result, OverlayCloseReason reason}) _close;

  void close({Object? result, OverlayCloseReason reason = OverlayCloseReason.completed}) => _close(id, result: result, reason: reason);
  void cancel() => _close(id, reason: OverlayCloseReason.discard);
}

/// A request to show something above the content.
class RasqOverlayEntry {
  RasqOverlayEntry({
    required this.id,
    required this.layer,
    required this.builder,
    this.alignment = Alignment.center,
    this.anchor,
    this.barrierBehavior,
    this.onBarrierTap,
    this.barrierEnabled,
    this.onClosed,
    this.ownerId,
    this.semanticsLabel,
    this.fow,
  });

  /// Stable id (plugin-scoped ids should be prefixed by pluginId).
  final String id;
  final OverlayLayer layer;
  final OverlayWidgetBuilder builder;

  /// Where the entry is placed inside the host (bottom sheet → bottomCenter,
  /// sidebar → centerLeft, FOW/VC pip → bottomRight, modal → center).
  final Alignment alignment;

  /// For dropdowns: the anchor rect in global coordinates. The host flips the
  /// menu to the other side when it would overflow the screen
  /// (「スクリーン端で位置反転」).
  final Rect? anchor;

  /// Per-entry override of the layer default.
  final OverlayBarrierBehavior? barrierBehavior;

  /// バリア(FOW 以外の部分)のタップを**閉じずに**横取りする (D-143: AsTell の
  /// ルーム FOW は外側タップで stick に変形する)。設定時は [barrierBehavior]
  /// の閉じる動作を行わない。
  final VoidCallback? onBarrierTap;

  /// バリアの動的な有効/無効 (D-143)。false の間は [OverlayBarrierBehavior.none]
  /// と同じ(背面を触れる)。切り替えたら [OverlayManager.requestRebuild] を呼ぶ。
  final ValueListenable<bool>? barrierEnabled;
  final void Function(OverlayCloseReason reason, Object? result)? onClosed;

  /// Owner (plugin id / feature id) — lets the host close everything owned by
  /// a crashed plugin in one go.
  final String? ownerId;
  final String? semanticsLabel;

  /// Presentation for `fow` layer entries (docked, resizable panel).
  final FowSpec? fow;

  OverlayBarrierBehavior get effectiveBarrierBehavior =>
      barrierEnabled?.value == false
          ? OverlayBarrierBehavior.none
          : barrierBehavior ?? (layer == OverlayLayer.fow && (fow?.blocksContent ?? false) ? OverlayBarrierBehavior.dismissDiscard : layer.barrierBehavior);

  OverlayHandle handleWith(void Function(String id, {Object? result, OverlayCloseReason reason}) close) => OverlayHandle._(id, close);
}
