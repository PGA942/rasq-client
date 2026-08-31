import 'package:meta/meta.dart';

import 'node.dart';

/// `baseRev` didn't match the document's current rev — the host must reply
/// with `resync` (PROTOCOL §3.1 / validation gate V10).
class RrlRevMismatchException implements Exception {
  RrlRevMismatchException(this.expected, this.baseRev);
  final int expected;
  final int baseRev;
  @override
  String toString() => 'RrlRevMismatchException: baseRev $baseRev != current rev $expected → resync';
}

/// A patch op referenced a key that isn't in the tree (or an op was
/// malformed). The batch is atomic, so the document is left untouched.
class RrlPatchException implements Exception {
  RrlPatchException(this.message);
  final String message;
  @override
  String toString() => 'RrlPatchException: $message';
}

/// The live tree of one plugin instance: `snapshot` seeds it, `patch`
/// advances it atomically (Command + rev, D-001).
@immutable
class RrlDocument {
  const RrlDocument({required this.scope, required this.rev, required this.root});

  /// `instanceScope` — `pluginId:accountKey:pluginVersion:instanceId`.
  final String scope;
  final int rev;
  final RrlNode root;

  /// Builds a document from a `snapshot` boundary message.
  factory RrlDocument.fromSnapshot(Map<String, Object?> message) {
    if (message['schema'] != 'rasq.boundary/1') {
      throw RrlPatchException('unknown schema: ${message['schema']}');
    }
    if (message['type'] != 'snapshot') {
      throw RrlPatchException('not a snapshot: ${message['type']}');
    }
    return RrlDocument(
      scope: message['scope'] as String,
      rev: message['rev'] as int,
      // V11 検証ゲート (D-086): 付与先違反のタグは取り込み時に剥がす
      // (装飾/構造ノードのタグが意味タグの読取りを汚さないように)。
      root: RrlNode.fromJson((message['root'] as Map).cast<String, Object?>()).sanitizeTags(),
    );
  }

  /// Applies a `patch` boundary message as one atomic batch and returns the
  /// new document. Throws [RrlRevMismatchException] on rev mismatch and
  /// [RrlPatchException] on a bad op — in both cases `this` is unchanged.
  RrlDocument applyPatch(Map<String, Object?> message) {
    if (message['type'] != 'patch') throw RrlPatchException('not a patch: ${message['type']}');
    final baseRev = message['baseRev'] as int;
    if (baseRev != rev) throw RrlRevMismatchException(rev, baseRev);

    var newRoot = root;
    for (final rawOp in (message['ops'] as List)) {
      final op = (rawOp as Map).cast<String, Object?>();
      final key = RrlNodeId.parse(op['target'] as String).key;
      newRoot = switch (op['op'] as String) {
        'setProp' => _mustRewrite(newRoot, key, (n) => n.copyWith(p: {...n.p, op['prop'] as String: op['value']})),
        'replaceSubtree' => _mustRewrite(newRoot, key, (n) => RrlNode.fromJson((op['node'] as Map).cast<String, Object?>())),
        'insert' => _mustRewrite(newRoot, key, (parent) {
            final node = RrlNode.fromJson((op['node'] as Map).cast<String, Object?>());
            final children = [...parent.c];
            final index = (op['index'] as int?)?.clamp(0, children.length) ?? children.length;
            children.insert(index, node);
            return parent.copyWith(c: children);
          }),
        'remove' => _removeByKey(newRoot, key),
        'move' => _moveByKey(newRoot, key, op['index'] as int? ?? 0),
        final other => throw RrlPatchException('unknown op: $other'),
      };
    }
    return RrlDocument(scope: scope, rev: message['rev'] as int, root: newRoot);
  }

  static RrlNode _mustRewrite(RrlNode root, String key, RrlNode Function(RrlNode) transform) {
    final (rewritten, hit) = _rewrite(root, key, transform);
    if (!hit) throw RrlPatchException('target not found: $key');
    return rewritten;
  }

  static (RrlNode, bool) _rewrite(RrlNode node, String key, RrlNode Function(RrlNode) transform) {
    if (node.k == key) return (transform(node), true);
    for (var i = 0; i < node.c.length; i++) {
      final (child, hit) = _rewrite(node.c[i], key, transform);
      if (hit) {
        final children = [...node.c]..[i] = child;
        return (node.copyWith(c: children), true);
      }
    }
    return (node, false);
  }

  static RrlNode _removeByKey(RrlNode root, String key) {
    if (root.k == key) throw RrlPatchException('cannot remove the root node');
    final (rewritten, hit) = _removeIn(root, key);
    if (!hit) throw RrlPatchException('target not found: $key');
    return rewritten;
  }

  static (RrlNode, bool) _removeIn(RrlNode node, String key) {
    final index = node.c.indexWhere((child) => child.k == key);
    if (index >= 0) return (node.copyWith(c: [...node.c]..removeAt(index)), true);
    for (var i = 0; i < node.c.length; i++) {
      final (child, hit) = _removeIn(node.c[i], key);
      if (hit) return (node.copyWith(c: [...node.c]..[i] = child), true);
    }
    return (node, false);
  }

  static RrlNode _moveByKey(RrlNode root, String key, int toIndex) {
    final (rewritten, hit) = _moveIn(root, key, toIndex);
    if (!hit) throw RrlPatchException('target not found: $key');
    return rewritten;
  }

  static (RrlNode, bool) _moveIn(RrlNode node, String key, int toIndex) {
    final from = node.c.indexWhere((child) => child.k == key);
    if (from >= 0) {
      final children = [...node.c];
      final moved = children.removeAt(from);
      children.insert(toIndex.clamp(0, children.length), moved);
      return (node.copyWith(c: children), true);
    }
    for (var i = 0; i < node.c.length; i++) {
      final (child, hit) = _moveIn(node.c[i], key, toIndex);
      if (hit) return (node.copyWith(c: [...node.c]..[i] = child), true);
    }
    return (node, false);
  }
}
