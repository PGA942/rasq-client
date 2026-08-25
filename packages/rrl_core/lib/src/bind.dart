/// `$.path` Bind resolution (PROTOCOL §2: 「`$.path` は Bind — ホスト Store /
/// 投稿オブジェクトへの参照」).
///
/// Supported grammar (draft, mirrors what the samples use):
///
/// - `$.post.author.displayName` — dot segments into nested maps
/// - `$.items[2].url`            — integer index into lists
/// - `$.actionStates[post.key]`  — dynamic key: the bracket content is itself
///   resolved in the same scope and used as a map key
/// - `{{id}}` / `post-{{item.id}}` — key templates ([resolveTemplate])
///
/// Scopes chain: `ForEach` pushes `{item, index}`, `Bind` pushes a named
/// value, lookups walk outward until a root value matches.
class RrlScope {
  RrlScope(this.values, {this.parent});

  final Map<String, Object?> values;
  final RrlScope? parent;

  RrlScope push(Map<String, Object?> child) => RrlScope(child, parent: this);

  /// True when [value] is a Bind reference rather than a literal.
  static bool isBind(Object? value) => value is String && value.startsWith(r'$.');

  /// Resolves a prop value: Bind strings are looked up, everything else is
  /// returned as-is.
  Object? resolveProp(Object? value) => isBind(value) ? resolve(value! as String) : value;

  /// Resolves `$.a.b[0][c.d]` against this scope chain. Unknown segments
  /// resolve to `null` (the renderer treats that as "absent", like `If`
  /// with a missing cond).
  Object? resolve(String bind) {
    if (!isBind(bind)) throw ArgumentError('not a bind: $bind');
    return _walk(_segments(bind.substring(2)));
  }

  Object? _walk(List<_Seg> segs) {
    if (segs.isEmpty) return null;
    // First segment: search up the scope chain.
    Object? current;
    RrlScope? scope = this;
    final head = segs.first;
    while (scope != null) {
      if (head is _Key && scope.values.containsKey(head.name)) {
        current = scope.values[head.name];
        break;
      }
      scope = scope.parent;
    }
    if (scope == null) return null;
    for (final seg in segs.skip(1)) {
      current = _step(current, seg);
      if (current == null) return null;
    }
    return current;
  }

  Object? _step(Object? current, _Seg seg) {
    switch (seg) {
      case _Key(:final name):
        if (current is Map) return current[name];
        return null;
      case _Index(:final index):
        if (current is List && index >= 0 && index < current.length) return current[index];
        return null;
      case _Dynamic(:final path):
        final key = _walk(_segments(path));
        if (current is Map && key != null) return current['$key'];
        return null;
    }
  }

  /// Replaces every `{{expr}}` with the resolved value of `$.expr`
  /// (used for explicit keys like `post-{{id}}` / `{{item.id}}`).
  String resolveTemplate(String template) => template.replaceAllMapped(
        RegExp(r'\{\{([^}]+)\}\}'),
        (m) => '${_walk(_segments(m.group(1)!.trim())) ?? ''}',
      );

  static List<_Seg> _segments(String path) {
    final segs = <_Seg>[];
    final re = RegExp(r'([^.\[\]]+)|\[([^\[\]]+)\]');
    for (final m in re.allMatches(path)) {
      final plain = m.group(1);
      if (plain != null) {
        segs.add(_Key(plain));
      } else {
        final inner = m.group(2)!;
        final asInt = int.tryParse(inner);
        segs.add(asInt != null ? _Index(asInt) : _Dynamic(inner));
      }
    }
    return segs;
  }
}

sealed class _Seg {}

class _Key extends _Seg {
  _Key(this.name);
  final String name;
}

class _Index extends _Seg {
  _Index(this.index);
  final int index;
}

class _Dynamic extends _Seg {
  _Dynamic(this.path);
  final String path;
}
