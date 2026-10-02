import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// FOW のぶんメディアを寄せる余白 (D-207 → D-215 → D-326 → D-332、D-413 で共通化)。
///
/// [area](メディアを出す場所、ホストの座標)に重なる FOW ごとに、メディアを FOW の**逆サイド**へ寄せる余白を出す。
/// 上下に寄せるか左右に寄せるかは**空きが広くなるほう**(壁付けは左右固定): 幅の広い画面でカラムに置かれた FOW
/// (縦に長い)は左右へ、下側中央の FOW は上へ。[area] に重ならない FOW は見ない。逆サイドに [minFree] は必ず残す
/// (足りないぶんは FOW と重なる)。
EdgeInsets fowAvoidInset(Rect area, Iterable<({Rect rect, bool wall})> fows, {double minFree = 0}) {
  var top = 0.0, bottom = 0.0, left = 0.0, right = 0.0;
  final w = area.width, h = area.height;
  if (w <= 0 || h <= 0) return EdgeInsets.zero;
  for (final f in fows) {
    if (!f.rect.overlaps(area)) continue;
    // [area] の中の座標へ。
    final r = f.rect.intersect(area).shift(-area.topLeft);
    final vertical = r.top >= h - r.bottom ? (top: 0.0, bottom: h - r.top) : (top: r.bottom, bottom: 0.0);
    final horizontal = r.left >= w - r.right ? (left: 0.0, right: w - r.left) : (left: r.right, right: 0.0);
    final freeV = (h - vertical.top - vertical.bottom) * w;
    final freeH = (w - horizontal.left - horizontal.right) * h;
    if (f.wall || freeH > freeV) {
      left = math.max(left, horizontal.left);
      right = math.max(right, horizontal.right);
    } else {
      top = math.max(top, vertical.top);
      bottom = math.max(bottom, vertical.bottom);
    }
  }
  (top, bottom) = _keepFree(top, bottom, h, minFree);
  (left, right) = _keepFree(left, right, w, minFree);
  return EdgeInsets.fromLTRB(left, top, right, bottom);
}

/// [total] のうち [a] / [b] を空けた残りが [min] を切らないように、大きいほうから削る。
(double, double) _keepFree(double a, double b, double total, double min) {
  var over = a + b - (total - min);
  if (over <= 0) return (a, b);
  if (a >= b) {
    final d = math.min(over, a);
    a -= d;
    over -= d;
    b = math.max(0, b - over);
  } else {
    final d = math.min(over, b);
    b -= d;
    over -= d;
    a = math.max(0, a - over);
  }
  return (a, b);
}

/// いま置かれている FOW の矩形(退避中・未配置は除く)。[exclude] の id は見ない。
Iterable<({Rect rect, bool wall})> laidOutFows(OverlayManager manager, {Set<String> exclude = const {}}) sync* {
  for (final e in manager.entries) {
    final f = e.fow;
    final r = f?.laidOut;
    if (f == null || r == null || exclude.contains(e.id) || manager.isFowSuspended(e)) continue;
    yield (rect: r, wall: f.pinnedWall != 0);
  }
}

/// 全画面のメディア表示と同じ作り (D-413): [child](メディアの面)を、重なる FOW の**逆サイド**へ寄せて縮める。
/// FOW が出る / 消える / 伸び縮みする / 動くたびに、次のフレームで測り直す(1 フレームに 1 回)。
/// 置き場所はこのウィジェットの矩形(カラムの中に置けば、そのカラムに重なる FOW だけを見る)。
class FowAvoidingBox extends StatefulWidget {
  const FowAvoidingBox({super.key, required this.manager, required this.child, this.minFree = 160, this.duration = const Duration(milliseconds: 150), this.areaKey});
  final OverlayManager manager;
  final Widget child;

  /// 逆サイドに必ず残す幅 / 高さ。
  final double minFree;
  final Duration duration;

  /// 余白を掛けた面(テストで矩形を測る)に付けるキー。
  final Key? areaKey;

  @override
  State<FowAvoidingBox> createState() => _FowAvoidingBoxState();
}

class _FowAvoidingBoxState extends State<FowAvoidingBox> {
  EdgeInsets _inset = EdgeInsets.zero;
  bool _pending = false;
  final _listened = <Listenable>{};

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onOverlays);
    _onOverlays();
  }

  @override
  void didUpdateWidget(FowAvoidingBox old) {
    super.didUpdateWidget(old);
    if (old.manager != widget.manager) {
      old.manager.removeListener(_onOverlays);
      _unlistenAll();
      widget.manager.addListener(_onOverlays);
      _onOverlays();
    }
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onOverlays);
    _unlistenAll();
    super.dispose();
  }

  void _unlistenAll() {
    for (final l in _listened) {
      l.removeListener(_schedule);
    }
    _listened.clear();
  }

  /// FOW の出入り: 幾何(高さ / 横縦の移動 / カラムなど)を聞き直してから測る。
  void _onOverlays() {
    if (widget.manager.disposed) return;
    final next = <Listenable>{
      for (final e in widget.manager.entries)
        if (e.fow case final f?) ...[f.heightFactor, f.moveDx, f.moveDy, f.geometryRev],
    };
    for (final l in _listened.difference(next)) {
      l.removeListener(_schedule);
    }
    for (final l in next.difference(_listened)) {
      l.addListener(_schedule);
    }
    _listened
      ..clear()
      ..addAll(next);
    _schedule();
  }

  void _schedule() {
    if (_pending || !mounted) return;
    _pending = true;
    // 矩形はホストの build で決まるので 1 フレーム後に読む。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pending = false;
      _measure();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// 置き場所がまだ決まっていない FOW(出たばかり)を待って測り直した回数。
  int _retries = 0;

  void _measure() {
    if (!mounted || widget.manager.disposed) return;
    // 出たばかりの FOW は、ホストが置くまで矩形が無い。置かれるまで(数フレーム)測り直す。
    final unplaced = widget.manager.entries.any((e) => e.fow != null && e.fow!.laidOut == null && !widget.manager.isFowSuspended(e));
    if (unplaced && _retries < 30) {
      _retries++;
      _schedule();
    } else if (!unplaced) {
      _retries = 0;
    }
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize || !box.attached) return;
    final area = box.localToGlobal(Offset.zero) & box.size;
    final inset = fowAvoidInset(area, laidOutFows(widget.manager), minFree: widget.minFree);
    if (inset != _inset) setState(() => _inset = inset);
  }

  @override
  Widget build(BuildContext context) {
    // 大きさが変わったとき(カラムの幅が変わった / 回転)も測り直す。
    return NotificationListener<SizeChangedLayoutNotification>(
      onNotification: (_) {
        _schedule();
        return false;
      },
      child: SizeChangedLayoutNotifier(
        child: AnimatedPadding(key: widget.areaKey, duration: widget.duration, curve: Curves.easeOutCubic, padding: _inset, child: widget.child),
      ),
    );
  }
}
