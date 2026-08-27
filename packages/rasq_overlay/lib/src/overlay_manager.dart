import 'dart:async';

import 'package:flutter/foundation.dart';

import 'overlay_entry.dart';
import 'overlay_layer.dart';

/// Single entry point for every overlay in the app.
///
/// Rules implemented (原典: UI_Elements「Overlay Manager」):
/// * 同時表示: modal/bottomSheet stack, dropdown exclusive, rai coexists.
/// * クローズ挙動: per layer (see [OverlayLayer.barrierBehavior]).
/// * 競合:
///   - ボトムシート中にモーダル → modal interrupts, sheet stays (natural: both layers remain).
///   - VC中に別VC参加 → auto leave & join (exclusive replace, reason=replaced).
///   - VC中にボトムシート / モーダル → coexist.
///   - ドロップダウン中に新規ドロップダウン → previous auto-closes.
class OverlayManager extends ChangeNotifier {
  final List<RasqOverlayEntry> _entries = [];
  final Map<String, Completer<Object?>> _completers = {};

  /// All open entries, back → front (sorted by layer z, then insertion order).
  List<RasqOverlayEntry> get entries => List.unmodifiable(_entries);

  bool get isEmpty => _entries.isEmpty;
  bool contains(String id) => _entries.any((e) => e.id == id);
  RasqOverlayEntry? byId(String id) => _entries.where((e) => e.id == id).firstOrNull;
  Iterable<RasqOverlayEntry> inLayer(OverlayLayer layer) => _entries.where((e) => e.layer == layer);

  /// Topmost entry that blocks input (ignores `rai`/`fow`/`vcVideo`).
  RasqOverlayEntry? get topBlocking {
    for (final e in _entries.reversed) {
      if (e.effectiveBarrierBehavior != OverlayBarrierBehavior.none) return e;
    }
    return null;
  }

  /// Shows [entry]. Returns a future that completes with the result passed to
  /// [close] (or `null` on discard / replace / host close).
  Future<Object?> show(RasqOverlayEntry entry) {
    if (contains(entry.id)) {
      close(entry.id, reason: OverlayCloseReason.replaced);
    }
    switch (entry.layer.stacking) {
      case OverlayStacking.exclusive:
        for (final e in inLayer(entry.layer).toList()) {
          close(e.id, reason: OverlayCloseReason.replaced);
        }
      case OverlayStacking.stack:
      case OverlayStacking.coexist:
        break;
    }
    _entries.add(entry);
    _entries.sort((a, b) => a.layer.z.compareTo(b.layer.z)); // stable sort keeps insertion order within a layer
    final c = Completer<Object?>();
    _completers[entry.id] = c;
    notifyListeners();
    return c.future;
  }

  /// Closes the entry with [id].
  void close(String id, {Object? result, OverlayCloseReason reason = OverlayCloseReason.completed}) {
    final i = _entries.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _entries.removeAt(i);
    e.onClosed?.call(reason, result);
    _completers.remove(id)?.complete(reason == OverlayCloseReason.completed ? result : null);
    notifyListeners();
  }

  /// Barrier tap on [id]: applies the layer rule.
  void barrierTapped(String id) {
    final e = byId(id);
    if (e == null) return;
    switch (e.effectiveBarrierBehavior) {
      case OverlayBarrierBehavior.ignore:
      case OverlayBarrierBehavior.none:
        return;
      case OverlayBarrierBehavior.dismiss:
        close(id, reason: OverlayCloseReason.completed);
      case OverlayBarrierBehavior.dismissDiscard:
        close(id, reason: OverlayCloseReason.discard);
    }
  }

  /// Back gesture / Escape: closes the topmost blocking entry if its rule allows.
  /// Returns `true` when the event was consumed.
  bool handleBack() {
    final top = topBlocking;
    if (top == null) return false;
    switch (top.effectiveBarrierBehavior) {
      case OverlayBarrierBehavior.ignore:
        return true; // modal swallows back; explicit action required
      case OverlayBarrierBehavior.dismiss:
        close(top.id);
        return true;
      case OverlayBarrierBehavior.dismissDiscard:
        close(top.id, reason: OverlayCloseReason.discard);
        return true;
      case OverlayBarrierBehavior.none:
        return false;
    }
  }

  /// Closes every entry in [layer].
  void closeLayer(OverlayLayer layer, {OverlayCloseReason reason = OverlayCloseReason.host}) {
    for (final e in inLayer(layer).toList()) {
      close(e.id, reason: reason);
    }
  }

  /// Closes every entry owned by [ownerId] (plugin crash isolation).
  void closeOwnedBy(String ownerId, {OverlayCloseReason reason = OverlayCloseReason.host}) {
    for (final e in _entries.where((e) => e.ownerId == ownerId).toList()) {
      close(e.id, reason: reason);
    }
  }

  void closeAll({OverlayCloseReason reason = OverlayCloseReason.host}) {
    for (final e in _entries.toList()) {
      close(e.id, reason: reason);
    }
  }

  OverlayHandle handleFor(RasqOverlayEntry e) => e.handleWith(close);
}
