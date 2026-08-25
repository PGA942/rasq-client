import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';

import 'host.dart';
import 'registry.dart';

/// Renders one RRL tree. Give it the document root (or any subtree) and a
/// [RrlHost]; rebuild with a new node after a `patch` (the tree is immutable,
/// Flutter diffs the widgets).
class RrlRenderer extends StatelessWidget {
  const RrlRenderer({super.key, required this.node, required this.host});

  final RrlNode node;
  final RrlHost host;

  @override
  Widget build(BuildContext context) => _NodeWidget(node: node, host: host, scope: host.scope);
}

class _NodeWidget extends StatelessWidget {
  const _NodeWidget({required this.node, required this.host, required this.scope});

  final RrlNode node;
  final RrlHost host;
  final RrlScope scope;

  Widget _render(RrlNode child, RrlScope childScope) => _NodeWidget(node: child, host: host, scope: childScope);

  List<Widget> _children(RrlScope childScope) => [for (final c in node.c) _render(c, childScope)];

  Object? _prop(String name) => scope.resolveProp(node.p[name]);

  @override
  Widget build(BuildContext context) {
    try {
      final built = _build(context);
      // tap / longPress wiring for nodes that declare events and are not L2
      // (L2 builders wire their own handlers with richer payloads).
      final wantsGesture = node.layer != RrlLayer.l2Standard && (node.on.containsKey('tap') || node.on.containsKey('longPress'));
      if (!wantsGesture) return built;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: node.on.containsKey('tap') ? () => host.emit(node, scope, 'tap') : null,
        onLongPress: node.on.containsKey('longPress') ? () => host.emit(node, scope, 'longPress') : null,
        child: built,
      );
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
        return Text(rrlString(_prop('text')), style: RasqTypography.body);
      case 'Icon':
        return Icon(rrlIconFor(rrlString(_prop('icon'))), size: (_prop('size') as num?)?.toDouble() ?? 20);
      case 'Image':
        final src = rrlUri(_prop('src'));
        if (src == null) return const _ErrorBox('Image without src');
        return Image.network(src.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => const _ErrorBox('image'));
      case 'Row':
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: _children(scope));
      case 'Column':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _children(scope));
      case 'Stack':
        return Stack(children: _children(scope));
      case 'Grid':
        final columns = (_prop('columns') as num?)?.toInt() ?? 2;
        return GridView.count(crossAxisCount: columns, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: RasqSpacing.mediaGap, crossAxisSpacing: RasqSpacing.mediaGap, children: _children(scope));
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
