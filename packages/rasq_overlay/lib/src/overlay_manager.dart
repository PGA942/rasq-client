import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart' show RepaintBoundary, BuildContext;

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
    // サイドバーの前に持ち上げた FOW (D-274) は、サイドバーより先に戻る / Escape を受ける。
    if (_entries.any((e) => e.layer == OverlayLayer.sidebar)) {
      for (final e in _entries.reversed) {
        if (e.layer == OverlayLayer.fow && (e.fow?.aboveSidebar ?? false) && !isFowSuspended(e) && e.effectiveBarrierBehavior != OverlayBarrierBehavior.none) return e;
      }
    }
    for (final e in _entries.reversed) {
      // 退避中の FOW(全画面の加工画面の下に隠れているコンポーザー等)は、戻る / Escape の相手にしない。
      if (e.layer == OverlayLayer.fow && isFowSuspended(e)) continue;
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
    // 同じ id で開き直す: 閉じかけ (D-476) の古い方は動きを待たずに消す(同じ id の FOW が 2 つ描かれないように)。
    for (final x in _leavingFows.where((x) => x.entry.id == entry.id).toList()) {
      _dropLeaving(x);
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
    final e = _entries[i];
    // 閉じる動き (D-476): FOW は閉じたあとも、ホストが動かし終えるまで重ね順の位置ごと覚えておく(entries からは外す =
    // 戻る / バリア / 前面の判定には入らない)。描くのは閉じる直前のパネルの**写し**(RepaintBoundary の画像)で、中身の
    // ウィジェットはすぐ捨てる(GlobalKey の重複 / フォーカス / 閉じたビルダーの呼び直しを起こさない)。
    // 退避中 (D-169) の FOW は見えていないので動かさない。写せなければ(まだ描かれていない等)動かさずに消す。
    if (e.layer == OverlayLayer.fow && fowExitMotion && (e.fow?.motion ?? true) && !isFowSuspended(e)) {
      final shot = _snapshot(e);
      if (shot != null) {
        final index = _entries.where((x) => x.layer == OverlayLayer.fow).toList().indexOf(e);
        _leavingFows.add((entry: e, index: index, image: shot.image, size: shot.size));
        // ホストが描かなくなっても溜まり続けないように。
        if (_leavingFows.length > 16) _dropLeaving(_leavingFows.first);
      }
    }
    _entries.removeAt(i);
    e.onClosed?.call(reason, result);
    _completers.remove(id)?.complete(reason == OverlayCloseReason.completed ? result : null);
    // 子 FOW は ownerId で連動クローズ(CONTRACT/D-067: 親が閉じたら
    // 子ピッカー等も閉じる)。ownerId がプラグイン id 等で FOW entry id と
    // 一致しない場合は何も起きない。
    if (e.layer == OverlayLayer.fow) {
      for (final child in _entries.where((x) => x.layer == OverlayLayer.fow && x.ownerId == id).toList()) {
        close(child.id, reason: OverlayCloseReason.host);
      }
    }
    if (_fowSwitcherOpen && !_entries.any((x) => x.layer == OverlayLayer.fow)) {
      _fowSwitcherOpen = false; // 最後の FOW が消えたらスイッチャーも閉じる
    }
    notifyListeners();
  }

  // ---- 閉じかけの FOW (D-476) ------------------------------------------

  final List<FowLeaving> _leavingFows = [];

  /// 閉じたあと、ホストが閉じる動きを描いている FOW(index = 閉じたときの FOW の中の重ね順、image = 閉じる直前のパネルの写し)。
  List<FowLeaving> get leavingFows => List.unmodifiable(_leavingFows);

  /// 閉じる動きを付けるか(ホストが毎ビルド書く: モーションの抑制中は false = 写しを撮らずにすぐ消す)。
  bool fowExitMotion = true;

  /// 閉じる動きが終わった(ホストが呼ぶ)。
  void fowLeft(RasqOverlayEntry entry) {
    final hit = _leavingFows.where((x) => identical(x.entry, entry)).toList();
    if (hit.isEmpty) return;
    hit.forEach(_dropLeaving);
    if (!_disposed) notifyListeners();
  }

  void _dropLeaving(FowLeaving x) {
    _leavingFows.remove(x);
    x.image.dispose();
  }

  ({ui.Image image, Size size})? _snapshot(RasqOverlayEntry e) {
    try {
      final obj = e.fow?.previewBoundaryKey.currentContext?.findRenderObject();
      if (obj is! RenderRepaintBoundary || !obj.hasSize || !obj.attached || obj.size.isEmpty) return null;
      // 直前に描いたレイヤーから写す(押したボタンのインク等で描き直し待ちでも、最後に描いた見た目でよい)。
      // まだ一度も描かれていない(開いたのと同じフレームで閉じた)ならレイヤーが無いので写さない。
      if (obj is! RenderFowSnapshotBoundary) return null;
      final dpr = SchedulerBinding.instance.platformDispatcher.implicitView?.devicePixelRatio ?? 1.0;
      final image = obj.lastPainted(dpr);
      return image == null ? null : (image: image, size: obj.size);
    } catch (_) {
      return null;
    }
  }

  // ---- FOW スイッチャー (D-065) ----------------------------------------
  // ドラッグハンドルの**クリック**で開く「開いている FOW の選択画面」。
  // 背景をブラックアウトし、FOW をリスト形式で表示(APP スイッチャー風)。

  bool _fowSwitcherOpen = false;
  bool get fowSwitcherOpen => _fowSwitcherOpen;

  /// FOW の一時退避 (D-169): true を返した FOW は Offstage(State は生きたまま)で、
  /// バリアも張らない。全画面の画面(メディアエディター)が下の FOW(コンポーザー等)を
  /// 隠しつつ、自分の子 FOW だけ出すために使う。null = 退避なし。
  bool Function(RasqOverlayEntry entry)? _fowSuspend;
  bool isFowSuspended(RasqOverlayEntry e) => _fowSuspend?.call(e) ?? false;

  void setFowSuspend(bool Function(RasqOverlayEntry entry)? filter) {
    _fowSuspend = filter;
    // 画面の dispose 中/ビルド中からも呼べるよう、通知はマイクロタスクで。
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
  }

  bool _disposed = false;

  /// 捨てたあとか(画面の dispose のあとで閉じる呼び出しが、アプリごと捨てたあとに来ることがある)。
  bool get disposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    for (final x in _leavingFows.toList()) {
      _dropLeaving(x);
    }
    fowStickReserve.dispose();
    super.dispose();
  }

  // ---- stick FOW のぶんカラムを縮める (D-397) ---------------------------

  /// stick(畳まれている)FOW がカラムの下端に占めている高さ。キー = 列スロットの index(単一スロットは 0)。
  /// ホストのレイアウトが書き、アプリのカラムは中身をこのぶん縮めて残りに並べる([FowStickPadding])。
  final ValueNotifier<Map<int, double>> fowStickReserve = ValueNotifier(const {});

  /// [fowStickReserve] を書き換える(変わったときだけ)。ホストはレイアウト中に呼ぶので、書くのはフレームの後。
  void setFowStickReserve(Map<int, double> next) {
    if (_disposed || mapEquals(fowStickReserve.value, next)) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_disposed || mapEquals(fowStickReserve.value, next)) return;
      fowStickReserve.value = next;
    });
  }

  void setFowSwitcher(bool open) {
    if (_fowSwitcherOpen == open) return;
    if (open && !_entries.any((e) => e.layer == OverlayLayer.fow)) return;
    _fowSwitcherOpen = open;
    notifyListeners();
  }

  /// スイッチャーを開く (D-066): まだ画面に出ているうちに各パネルを
  /// RepaintBoundary からキャプチャしてプレビューにする(名前だけでは
  /// 判別しづらい、の対応。失敗しても名前で選べるので握りつぶす)。
  Future<void> openFowSwitcher() async {
    for (final e in inLayer(OverlayLayer.fow)) {
      final s = e.fow;
      if (s == null) continue;
      try {
        final obj = s.previewBoundaryKey.currentContext?.findRenderObject();
        if (obj is RenderRepaintBoundary && obj.hasSize) {
          final image = await obj.toImage(pixelRatio: 0.6);
          s.switcherPreview?.dispose();
          s.switcherPreview = image;
        }
      } catch (_) {}
    }
    setFowSwitcher(true);
  }

  /// スイッチャーからの選択: 選んだ FOW を前面化し、**その FOW を親
  /// (ownerId)とする子 FOW は自動で閉じる**(例: コンポーザーを選ぶと
  /// 子の絵文字/MFM ピッカーが閉じる)。
  void promoteFow(String id) {
    _fowSwitcherOpen = false;
    final e = byId(id);
    if (e == null || e.layer != OverlayLayer.fow) {
      notifyListeners();
      return;
    }
    for (final child in _entries.where((x) => x.layer == OverlayLayer.fow && x.ownerId == id).toList()) {
      close(child.id, reason: OverlayCloseReason.host);
    }
    _entries.remove(e);
    _entries.add(e); // 同一レイヤー内の挿入順 = 前面度
    _entries.sort((a, b) => a.layer.z.compareTo(b.layer.z));
    notifyListeners();
  }

  /// Barrier tap on [id]: applies the layer rule.
  void barrierTapped(String id) {
    final e = byId(id);
    if (e == null) return;
    if (e.onBarrierTap != null) {
      e.onBarrierTap!();
      return;
    }
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

  /// エントリ側の動的な状態(バリアの有効/無効など)が変わったときにホストを
  /// 描き直させる。
  void requestRebuild() => notifyListeners();

  /// Back gesture / Escape: closes the topmost blocking entry if its rule allows.
  /// Returns `true` when the event was consumed.
  bool handleBack() {
    if (_fowSwitcherOpen) {
      setFowSwitcher(false);
      return true;
    }
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

/// 閉じる動きの途中の FOW (D-476)。
typedef FowLeaving = ({RasqOverlayEntry entry, int index, ui.Image image, Size size});

/// FOW のパネルの RepaintBoundary (D-066 のスイッチャーのプレビュー / D-476 の閉じる動きの写し)。
class FowSnapshotBoundary extends RepaintBoundary {
  const FowSnapshotBoundary({super.key, super.child});

  @override
  RenderFowSnapshotBoundary createRenderObject(BuildContext context) => RenderFowSnapshotBoundary();
}

class RenderFowSnapshotBoundary extends RenderRepaintBoundary {
  /// 直前に描いたレイヤーの写し。描き直し待ち(押したボタンのインク等)でも最後に描いた見た目を返す
  /// ([toImageSync] は描き直し待ちだと debug で assert する)。まだ一度も描いていなければ null。
  ui.Image? lastPainted(double pixelRatio) {
    final l = layer;
    if (l is! OffsetLayer || !hasSize || size.isEmpty) return null;
    return l.toImageSync(Offset.zero & size, pixelRatio: pixelRatio);
  }
}
