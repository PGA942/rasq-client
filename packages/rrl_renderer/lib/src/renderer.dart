import 'dart:typed_data';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';

import 'budget.dart';
import 'geometry.dart';
import 'host.dart';
import 'registry.dart';
import 'svg_lite.dart';

/// Renders one RRL tree. Give it the document root (or any subtree) and a
/// [RrlHost]; rebuild with a new node after a `patch` (the tree is immutable,
/// Flutter diffs the widgets).
class RrlRenderer extends StatelessWidget {
  const RrlRenderer({super.key, required this.node, required this.host});

  final RrlNode node;
  final RrlHost host;

  @override
  // 木の下の画像 / メディアの読み込みは、すべて host.mediaPolicy に従う (D-407)。
  Widget build(BuildContext context) {
    // 展開の予算 (セキュリティ確認 2026-10-09 の [4]): ウィジェットを作る前に木全体で数え、超えれば描かない。
    // 根の Bind の中身は描くたびに変わりうるので、毎回数える(手間は予算の分まで)。
    if (rrlExpansionOverBudget(node, host.scope, host.budget) case final over?) return _ErrorBox('${node.t}(${node.k ?? '-'}) not rendered: $over');
    return RasqMediaPolicyScope(policy: host.mediaPolicy, child: _NodeWidget(node: node, host: host, scope: host.scope));
  }
}

/// `#RRGGBB` / `#RRGGBBAA` / `#AARRGGBB`(8 桁は RRGGBBAA と解釈)を Color に。
Color? _rrlColor(Object? v) {
  if (v is! String || !v.startsWith('#')) return null;
  final hex = v.substring(1);
  final n = int.tryParse(hex, radix: 16);
  if (n == null) return null;
  if (hex.length == 6) return Color(0xFF000000 | n);
  if (hex.length == 8) return Color(((n & 0xFF) << 24) | (n >> 8));
  return null;
}

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({required this.node, required this.host, required this.scope});

  final RrlNode node;
  final RrlHost host;
  final RrlScope scope;

  Widget _render(RrlNode child, RrlScope childScope) => _NodeWidget(node: child, host: host, scope: childScope);

  List<Widget> _children(RrlScope childScope) => [for (final c in node.c) _render(c, childScope)];

  Object? _prop(String name) => scope.resolveProp(node.p[name]);

  /// 開発者モード (D-362): `dev: true` のノードは開発者モードのときだけ出す。`detail` を持つノードは、開発者モードでは
  /// `subtitle`(タイル)か `text`(Text / Notice)をそれで置き換える(Notice は本文の下に足す)。
  static const _detailTarget = {'Text': 'text'};

  @override
  Widget build(BuildContext context) {
    final p = node.p;
    if (p['dev'] == true || p.containsKey('detail')) {
      final dev = RasqDeveloperMode.of(context);
      if (p['dev'] == true && !dev) return const SizedBox.shrink();
      if (p.containsKey('detail') && node.t != 'Notice') {
        final rest = {...p}..remove('detail')..remove('dev');
        if (dev) rest[_detailTarget[node.t] ?? 'subtitle'] = p['detail'];
        return _render(RrlNode(t: node.t, k: node.k, tag: node.tag, role: node.role, p: rest, on: node.on, c: node.c), scope);
      }
    }
    try {
      var built = _build(context);
      // tap / longPress wiring for nodes that declare events and are not L2
      // (L2 builders wire their own handlers with richer payloads).
      final wantsGesture = node.layer != RrlLayer.l2Standard && (node.on.containsKey('tap') || node.on.containsKey('longPress') || node.on.containsKey('drag'));
      if (wantsGesture) {
        // drag (契約 v0.5 §3): {phase, x, y, dx, dy}(ノードの左上原点、親 Stack の単位)。
        final drag = node.on.containsKey('drag');
        // パン認識はタッチスロップ(≈18px)ぶん遅れて始まるので、指を置いた位置を覚えておき、
        // start は置いた位置で出し、遅れぶんは最初の update として渡す(dx の合計が実移動と一致する)。
        Offset? down;
        Offset? last;
        built = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: node.on.containsKey('tap') ? () => host.emit(node, scope, 'tap') : null,
          onLongPress: node.on.containsKey('longPress') ? () => host.emit(node, scope, 'longPress') : null,
          onPanDown: drag ? (d) => down = d.localPosition : null,
          onPanStart: drag
              ? (d) {
                  final from = down ?? d.localPosition;
                  last = d.localPosition;
                  host.emit(node, scope, 'drag', {'phase': 'start', 'x': from.dx, 'y': from.dy, 'dx': 0, 'dy': 0});
                  final delta = d.localPosition - from;
                  if (delta != Offset.zero) host.emit(node, scope, 'drag', {'phase': 'update', 'x': d.localPosition.dx, 'y': d.localPosition.dy, 'dx': delta.dx, 'dy': delta.dy});
                }
              : null,
          onPanUpdate: drag
              ? (d) {
                  last = d.localPosition;
                  host.emit(node, scope, 'drag', {'phase': 'update', 'x': d.localPosition.dx, 'y': d.localPosition.dy, 'dx': d.delta.dx, 'dy': d.delta.dy});
                }
              : null,
          onPanEnd: drag
              ? (d) {
                  // DragEndDetails の localPosition は無いことがある → 最後の位置を使う。
                  final at = last ?? d.localPosition;
                  host.emit(node, scope, 'drag', {'phase': 'end', 'x': at.dx, 'y': at.dy, 'dx': 0, 'dy': 0});
                  down = null;
                  last = null;
                }
              : null,
          onPanCancel: drag
              ? () {
                  down = null;
                  last = null;
                }
              : null,
          child: built,
        );
      }
      // ジオメトリ登録 (D-072): role 付きノードは実物の矩形を引ける。
      final role = node.role;
      final geometry = host.geometry;
      if (role != null && geometry != null) {
        built = RrlGeometryTag(registry: geometry, nodeId: host.nodeId(node, scope), role: role, child: built);
      }
      return built;
    } catch (e) {
      // V12: per-node fault isolation — a bad node degrades to an inline
      // error box, siblings keep rendering.
      return _ErrorBox('${node.t}(${node.k ?? '-'}) failed: $e');
    }
  }

  Widget _build(BuildContext context) {
    switch (node.t) {
      // ---- L1 Primitive ----------------------------------------------------
      case 'Text':
        // ホスト拡張 props (D-167): size / bold / color(#RRGGBB)。
        final size = (_prop('size') as num?)?.toDouble();
        final bold = rrlTruthy(_prop('bold'));
        final color = _rrlColor(_prop('color'));
        final text = Text(rrlString(_prop('text')), style: RasqTypography.body.copyWith(fontSize: size, fontWeight: bold ? FontWeight.w700 : null, color: color));
        // 余白 (D-238): 設定ページの説明文など。`pad` = 左右の余白(上下はその半分)。
        final pad = (_prop('pad') as num?)?.toDouble();
        return pad == null ? text : Padding(padding: EdgeInsets.symmetric(horizontal: pad, vertical: pad / 2), child: text);
      case 'Icon':
        return Icon(rrlIconFor(rrlString(_prop('icon'))), size: (_prop('size') as num?)?.toDouble() ?? 20, color: _rrlColor(_prop('color')));
      case 'Image':
        // `data:` URI(プラグインが生成した画像、D-167)と幅/高さ指定を受ける。
        final raw = rrlString(_prop('src'));
        final width = (_prop('width') as num?)?.toDouble();
        final height = (_prop('height') as num?)?.toDouble();
        // p.fit (契約 v0.22): contain(既定)/ cover / fill。data: の画像(SVG とラスター)に効く。
        final fit = switch (rrlString(_prop('fit'))) { 'cover' => BoxFit.cover, 'fill' => BoxFit.fill, _ => BoxFit.contain };
        // SVG (契約 v0.22、D-465): 許可リストで消毒してから描く(外のものは読まない)。読めなければ箱だけ。
        if (raw.startsWith('data:image/svg+xml')) {
          final doc = SvgLite.fromDataUri(raw);
          if (doc == null) return const _ErrorBox('bad svg');
          return SvgLiteView(doc: doc, width: width, height: height, fit: fit);
        }
        if (raw.startsWith('data:')) {
          final Uint8List bytes;
          try {
            bytes = UriData.parse(raw).contentAsBytes();
          } catch (_) {
            return const _ErrorBox('bad data uri');
          }
          return Image.memory(bytes, width: width, height: height, fit: fit, gaplessPlayback: true, errorBuilder: (_, _, _) => const _ErrorBox('image'));
        }
        final src = rrlUri(raw);
        if (src == null) return const _ErrorBox('Image without src');
        // プラグインの権限で読めない URL は、通信せずに箱だけ (D-407: 制限モードの下書き持ち出しを塞ぐ)。
        if (!rasqMediaAllowed(context, src)) return const _ErrorBox('image blocked');
        // リダイレクトの各ホップも方針に通す(Web 版は追わない。セキュリティ確認 2026-10-09 の [11])。
        return Image(image: rasqMediaImage(context, src), width: width, height: height, fit: width == null && height == null ? BoxFit.cover : BoxFit.contain, errorBuilder: (_, _, _) => const _ErrorBox('image'));
      case 'Row':
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: _children(scope));
      case 'Column':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _children(scope));
      case 'Stack':
        // 子の `left`/`top`(ホスト拡張、D-167)は絶対配置。
        return Stack(children: [
          for (final c in node.c)
            c.p.containsKey('left') || c.p.containsKey('top')
                ? Positioned(
                    left: (scope.resolveProp(c.p['left']) as num?)?.toDouble(),
                    top: (scope.resolveProp(c.p['top']) as num?)?.toDouble(),
                    width: (scope.resolveProp(c.p['width']) as num?)?.toDouble(),
                    height: (scope.resolveProp(c.p['height']) as num?)?.toDouble(),
                    child: _render(c, scope),
                  )
                : _render(c, scope),
        ]);
      case 'Box':
        // 矩形 (D-167): width / height / color / borderColor / borderWidth / radius。
        final bw = (_prop('borderWidth') as num?)?.toDouble() ?? 0;
        final bc = _rrlColor(_prop('borderColor'));
        final box = Container(
          width: (_prop('width') as num?)?.toDouble(),
          height: (_prop('height') as num?)?.toDouble(),
          decoration: BoxDecoration(
            color: _rrlColor(_prop('color')),
            border: bc != null && bw > 0 ? Border.all(color: bc, width: bw) : null,
            borderRadius: BorderRadius.circular((_prop('radius') as num?)?.toDouble() ?? 0),
          ),
          child: node.c.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: _children(scope)),
        );
        // angle (契約 v0.6): 中心で回転して描く(度)。
        final angle = (_prop('angle') as num?)?.toDouble() ?? 0;
        return angle == 0 ? box : Transform.rotate(angle: angle * math.pi / 180, child: box);
      case 'Grid':
        final columns = (_prop('columns') as num?)?.toInt() ?? 2;
        // p.aspectRatio (契約 v0.22): 1 マスの幅 ÷ 高さ。0.1〜10 の外 / 数でない → 1(正方形)。
        final ratio = switch (_prop('aspectRatio')) { final num r when r >= 0.1 && r <= 10 => r.toDouble(), _ => 1.0 };
        return GridView.count(crossAxisCount: columns, childAspectRatio: ratio, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: RasqSpacing.mediaGap, crossAxisSpacing: RasqSpacing.mediaGap, children: _children(scope));
      case 'Scroll':
        final horizontal = rrlString(_prop('direction')) == 'horizontal';
        return SingleChildScrollView(scrollDirection: horizontal ? Axis.horizontal : Axis.vertical, child: horizontal ? Row(children: _children(scope)) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: _children(scope)));
      case 'Spacer':
        final size = (_prop('size') as num?)?.toDouble() ?? RasqSpacing.sm;
        return SizedBox(width: size, height: size);
      case 'Canvas':
        // Raw pointer transfer is mandatory for Canvas (PROTOCOL §3.2).
        final height = (_prop('height') as num?)?.toDouble() ?? 120;
        return Listener(
          onPointerDown: (e) => host.emit(node, scope, 'pointerDown', {'x': e.localPosition.dx, 'y': e.localPosition.dy}),
          onPointerMove: (e) => host.emit(node, scope, 'pointerMove', {'x': e.localPosition.dx, 'y': e.localPosition.dy}),
          onPointerUp: (e) => host.emit(node, scope, 'pointerUp', {'x': e.localPosition.dx, 'y': e.localPosition.dy}),
          child: SizedBox(height: height, width: double.infinity, child: const ColoredBox(color: Color(0x11000000))),
        );

      // ---- L3 Control ------------------------------------------------------
      case 'If':
        if (!rrlTruthy(_prop('cond'))) return const SizedBox.shrink();
        final children = _children(scope);
        return children.length == 1 ? children.single : Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
      case 'ForEach':
        final items = rrlList(scope.resolveProp(node.p['in']));
        final rows = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          final itemScope = scope.push({'item': items[i], 'index': i});
          rows.addAll([for (final c in node.c) _render(c, itemScope)]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
      case 'Bind':
        // Introduces a named value into child scope: p: {name, value}.
        final name = rrlString(_prop('name'), 'value');
        final childScope = scope.push({name: scope.resolveProp(node.p['value'])});
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _children(childScope));
      case 'Call':
        // Invokes an L2/registered component by name with this node's props.
        final component = rrlString(node.p['component']);
        return _delegate(component.isEmpty ? '?' : component);
      case 'Slot':
        final slot = host.slots[rrlString(_prop('name'))];
        return slot ?? const SizedBox.shrink();
      case 'Stream':
        // Placeholder: subscription lifecycle (`lifecycle {streamId}`) is a
        // later M3 step; children render once with current scope.
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _children(scope));

      // ---- L2 Standard Component (delegated) -------------------------------
      default:
        return _delegate(node.t);
    }
  }

  Widget _delegate(String type) {
    final builder = host.components[type] ?? RrlComponentRegistry.standard[type];
    if (builder == null) return _ErrorBox('unsupported component: $type');
    final props = {for (final e in node.p.entries) e.key: scope.resolveProp(e.value)};
    return builder(RrlL2Context(
      node: node,
      props: props,
      children: _children(scope),
      host: host,
      scope: scope,
      renderChild: (child) => _render(child, scope),
    ));
  }
}

/// Inline degradation box (V12): keeps layout, says what broke.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox(this.message);
  final String message;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: scheme.errorContainer.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(4)),
      child: Text('⚠ $message', style: RasqTypography.caption.copyWith(color: scheme.onErrorContainer), overflow: TextOverflow.ellipsis),
    );
  }
}
