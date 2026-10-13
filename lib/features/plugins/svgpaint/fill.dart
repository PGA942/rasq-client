import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'geometry.dart';
import 'model.dart';
import 'spline.dart';

/// オート塗りつぶし (D-473)。
///
/// 1. 線の層を [cell] 単位の格子に描く(線の太さの半分 + すき間の許し [gap] まで = 小さな切れ目は閉じたものとみなす)。
///    読み込んだ形は輪郭を壁にする。塗りは壁にしない。
/// 2. タップした升から 4 近傍で塗り広げる。紙の縁に届いたら閉じていない(何もしない)。
/// 3. 塗った領域を [gap] + 0.75 だけ太らせる(すき間の許しで痩せた分を戻し、線の下へ潜らせる = 線との間に白い筋を残さない)。
///    中に残った穴のうち、線の下だけの穴(開いた升を含まない)は埋める(線の下は見えないので、穴を作らない方が小さい)。
/// 4. marching squares で境界を輪にし(外の輪と穴は向きが逆)、閉じた RDP(0.75)で減らし、なめらかな閉じた曲線で結ぶ。
///    面積 3 未満の輪は捨てる。

enum FillFailure {
  /// 線の上をタップした。
  onLine,

  /// 閉じていない(紙の縁へ漏れる)。
  leak,

  /// 塗る形が残らなかった。
  empty,
}

/// 結果(塗りか、できなかった理由)。
class FillOutcome {
  const FillOutcome.ok(PaintFill this.fill) : failure = null;
  const FillOutcome.fail(FillFailure this.failure) : fill = null;
  final PaintFill? fill;
  final FillFailure? failure;
}

FillOutcome autoFill(List<PaintItem> items, Size vb, Offset tap, Color color, {double cell = 1, double gap = 1.5}) {
  final w = math.max(1, (vb.width / cell).ceil()), h = math.max(1, (vb.height / cell).ceil());
  final blocked = Uint8List(w * h);

  void mark(Offset a, Offset b, double r) {
    final x0 = ((math.min(a.dx, b.dx) - r) / cell).floor().clamp(0, w - 1);
    final x1 = ((math.max(a.dx, b.dx) + r) / cell).ceil().clamp(0, w - 1);
    final y0 = ((math.min(a.dy, b.dy) - r) / cell).floor().clamp(0, h - 1);
    final y1 = ((math.max(a.dy, b.dy) + r) / cell).ceil().clamp(0, h - 1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final i = y * w + x;
        if (blocked[i] == 1) continue;
        if (segmentDistance(Offset((x + 0.5) * cell, (y + 0.5) * cell), a, b) <= r) blocked[i] = 1;
      }
    }
  }

  for (final item in items) {
    switch (item) {
      case PaintStroke():
        final (p, ws) = item.dense;
        if (p.length == 1) mark(p.first, p.first, ws.first / 2 + gap);
        for (var i = 1; i < p.length; i++) {
          mark(p[i - 1], p[i], math.max(ws[i - 1], ws[i]) / 2 + gap);
        }
      case PaintFill():
        break;
      case PaintShape() || PaintPath():
        final g = item is PaintShape ? item.generic : item as PaintPath;
        final half = (g.style.stroke != null ? g.style.strokeWidth / 2 : 0.5) + gap;
        for (final line in flattenSegments(g.segments)) {
          for (var i = 1; i < line.length; i++) {
            mark(line[i - 1], line[i], half);
          }
        }
    }
  }

  final tx = (tap.dx / cell).floor(), ty = (tap.dy / cell).floor();
  if (tx < 0 || ty < 0 || tx >= w || ty >= h) return const FillOutcome.fail(FillFailure.leak);
  if (blocked[ty * w + tx] == 1) return const FillOutcome.fail(FillFailure.onLine);

  // 2. 塗り広げる。
  final region = Uint8List(w * h);
  final queue = Queue<int>()..add(ty * w + tx);
  region[ty * w + tx] = 1;
  while (queue.isNotEmpty) {
    final i = queue.removeFirst();
    final x = i % w, y = i ~/ w;
    if (x == 0 || y == 0 || x == w - 1 || y == h - 1) return const FillOutcome.fail(FillFailure.leak);
    for (final j in [i - 1, i + 1, i - w, i + w]) {
      if (region[j] == 0 && blocked[j] == 0) {
        region[j] = 1;
        queue.add(j);
      }
    }
  }

  // 3. 太らせる。
  final mask = Uint8List.fromList(region);
  final rc = (gap + 0.75) / cell;
  final reach = rc.ceil();
  final disk = <(int, int)>[
    for (var dy = -reach; dy <= reach; dy++)
      for (var dx = -reach; dx <= reach; dx++)
        if (dx * dx + dy * dy <= rc * rc) (dx, dy),
  ];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (region[i] == 0) continue;
      final edge = (x > 0 && region[i - 1] == 0) || (x < w - 1 && region[i + 1] == 0) || (y > 0 && region[i - w] == 0) || (y < h - 1 && region[i + w] == 0);
      if (!edge) continue;
      for (final (dx, dy) in disk) {
        final nx = x + dx, ny = y + dy;
        if (nx >= 0 && ny >= 0 && nx < w && ny < h) mask[ny * w + nx] = 1;
      }
    }
  }
  _fillLineOnlyHoles(mask, blocked, w, h);

  // 4. 境界 → 輪。
  final rings = marchingSquares(mask, w, h);
  final contours = <List<Offset>>[];
  for (final ring in rings) {
    final pts = [for (final p in ring) Offset((p.dx - 0.5) * cell, (p.dy - 0.5) * cell)];
    final simple = rdpClosed(pts, 0.75 * cell);
    final q = <Offset>[];
    for (final p in simple) {
      final v = qp(p);
      if (q.isEmpty || q.last != v) q.add(v);
    }
    if (q.length > 1 && q.first == q.last) q.removeLast();
    if (q.length < 3 || signedArea(q).abs() < 3) continue;
    contours.add(q);
  }
  if (contours.isEmpty) return const FillOutcome.fail(FillFailure.empty);
  return FillOutcome.ok(PaintFill(color: color, contours: contours));
}

/// 塗りの中の穴のうち、開いた升を含まない(線の下だけの)ものを埋める。
void _fillLineOnlyHoles(Uint8List mask, Uint8List blocked, int w, int h) {
  final seen = Uint8List(w * h);
  final queue = Queue<int>();
  // 縁から届く外側。
  for (var x = 0; x < w; x++) {
    for (final i in [x, (h - 1) * w + x]) {
      if (mask[i] == 0 && seen[i] == 0) {
        seen[i] = 1;
        queue.add(i);
      }
    }
  }
  for (var y = 0; y < h; y++) {
    for (final i in [y * w, y * w + w - 1]) {
      if (mask[i] == 0 && seen[i] == 0) {
        seen[i] = 1;
        queue.add(i);
      }
    }
  }
  void spread(List<int>? into) {
    while (queue.isNotEmpty) {
      final i = queue.removeFirst();
      into?.add(i);
      final x = i % w, y = i ~/ w;
      if (x > 0) _push(i - 1, mask, seen, queue);
      if (x < w - 1) _push(i + 1, mask, seen, queue);
      if (y > 0) _push(i - w, mask, seen, queue);
      if (y < h - 1) _push(i + w, mask, seen, queue);
    }
  }

  spread(null);
  for (var i = 0; i < w * h; i++) {
    if (mask[i] != 0 || seen[i] != 0) continue;
    seen[i] = 1;
    queue.add(i);
    final comp = <int>[];
    spread(comp);
    if (comp.every((j) => blocked[j] == 1)) {
      for (final j in comp) {
        mask[j] = 1;
      }
    }
  }
}

void _push(int j, Uint8List mask, Uint8List seen, Queue<int> q) {
  if (mask[j] == 0 && seen[j] == 0) {
    seen[j] = 1;
    q.add(j);
  }
}

/// 2 値の格子([mask]、w×h)の境界の輪(格子の座標: 升 (x, y) の中心が (x + 1, y + 1)。外に 1 升の余白を足して閉じる)。
/// 輪の向きは、中を右手に見る向き(y 下向きで)。外の輪と穴は逆向きになる。斜めにだけ接する升は別々(4 近傍)。
List<List<Offset>> marchingSquares(Uint8List mask, int w, int h) {
  int at(int gx, int gy) {
    final x = gx - 1, y = gy - 1;
    return x < 0 || y < 0 || x >= w || y >= h ? 0 : mask[y * w + x];
  }

  // 点は 2 倍した整数の組(辺の中点が .5 になるため)を 1 つの int にする。
  final stride = 2 * (w + 2) + 1;
  int key(int x2, int y2) => y2 * stride + x2;
  final next = <int, int>{};
  // 角 0..3 = 左上・右上・右下・左下(時計回り)。辺 k は角 k と角 k+1 の間。
  const cx = [0, 1, 1, 0], cy = [0, 0, 1, 1];
  for (var sy = 0; sy <= h; sy++) {
    for (var sx = 0; sx <= w; sx++) {
      final v = [for (var k = 0; k < 4; k++) at(sx + cx[k], sy + cy[k])];
      final sum = v[0] + v[1] + v[2] + v[3];
      if (sum == 0 || sum == 4) continue;
      int mid(int k) {
        final k2 = (k + 1) % 4;
        return key(2 * sx + cx[k] + cx[k2], 2 * sy + cy[k] + cy[k2]);
      }

      // 中の角が続く並びごとに、出る辺の中点 → 入る辺の中点。
      for (var k = 0; k < 4; k++) {
        final prev = (k + 3) % 4;
        if (v[k] == 1 && v[prev] == 0) {
          // 角 k から中の並びが始まる(入る辺 = prev)。並びの終わりを探す。
          var e = k;
          while (v[(e + 1) % 4] == 1) {
            e = (e + 1) % 4;
          }
          next[mid(e)] = mid(prev);
        }
      }
    }
  }
  final rings = <List<Offset>>[];
  final used = <int>{};
  for (final start in next.keys) {
    if (used.contains(start)) continue;
    final ring = <Offset>[];
    var k = start;
    while (!used.contains(k)) {
      used.add(k);
      ring.add(Offset((k % stride) / 2, (k ~/ stride) / 2));
      final n = next[k];
      if (n == null) break;
      k = n;
    }
    if (ring.length >= 3) rings.add(ring);
  }
  return rings;
}
