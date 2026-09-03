import 'package:meta/meta.dart';

/// Node layers of D-002. The renderer decides what each layer means; the
/// model only records which layer a type name belongs to.
enum RrlLayer { l1Primitive, l2Standard, l3Control, unknown }

/// One RRL node (rrl-node.schema.json).
///
/// Immutable — patches produce new trees (see `RrlDocument.applyPatch`).
@immutable
class RrlNode {
  const RrlNode({
    required this.t,
    this.k,
    this.tag,
    this.role,
    this.p = const {},
    this.on = const {},
    this.c = const [],
  });

  /// Node type (L1 primitive / L2 standard component / L3 control).
  final String t;

  /// Explicit key, unique among siblings (ForEach items use the item id).
  /// Nodes without a key cannot be patch targets (PROTOCOL §2).
  final String? k;

  /// Semantic tag (D-019) — only on nodes forming the post content.
  final String? tag;

  /// Structural role for validation gates (`threadNav` / `contentBody` /
  /// `mediaItem` / `actionBar`).
  final String? role;

  /// Props. String values starting with `$.` are Bind references.
  final Map<String, Object?> p;

  /// Event name → plugin function name (function.json).
  final Map<String, String> on;

  /// Children.
  final List<RrlNode> c;

  static const _l1 = {'Text', 'Icon', 'Image', 'Row', 'Column', 'Stack', 'Grid', 'Scroll', 'Canvas', 'Spacer'};
  static const _l3 = {'If', 'ForEach', 'Call', 'Bind', 'Slot', 'Stream'};
  static const _l2 = {
    'Input', 'Avatar', 'Badge', 'RichText', 'MediaGrid', 'ActionButton', 'Timestamp', 'Button', //
    'ListTile', 'SwitchListTile', 'RadioListTile', 'ValueListTile', 'WarningListTile', 'DestructiveListTile', 'SectionHeader', //
    'PostTile', 'ActionBar', 'TrendHeader', 'UserRow', 'UserTileLarge', 'PollWidget', 'NotificationTile', 'PluginTile', 'VCCard', //
    'CollapsedPost', 'HeaderedListView', 'SortableList', 'SegmentedControl', 'Tabs',
  };

  RrlLayer get layer => _l1.contains(t)
      ? RrlLayer.l1Primitive
      : _l3.contains(t)
          ? RrlLayer.l3Control
          : _l2.contains(t)
              ? RrlLayer.l2Standard
              : RrlLayer.unknown;

  factory RrlNode.fromJson(Map<String, Object?> json) => RrlNode(
        t: json['t'] as String,
        k: json['k'] as String?,
        tag: json['tag'] as String?,
        role: json['role'] as String?,
        p: (json['p'] as Map?)?.cast<String, Object?>() ?? const {},
        on: (json['on'] as Map?)?.cast<String, String>() ?? const {},
        c: [for (final child in (json['c'] as List? ?? const [])) RrlNode.fromJson((child as Map).cast<String, Object?>())],
      );

  Map<String, Object?> toJson() => {
        't': t,
        if (k != null) 'k': k,
        if (tag != null) 'tag': tag,
        if (role != null) 'role': role,
        if (p.isNotEmpty) 'p': p,
        if (on.isNotEmpty) 'on': on,
        if (c.isNotEmpty) 'c': [for (final child in c) child.toJson()],
      };

  RrlNode copyWith({Map<String, Object?>? p, List<RrlNode>? c}) =>
      RrlNode(t: t, k: k, tag: tag, role: role, p: p ?? this.p, on: on, c: c ?? this.c);

  /// タグを付けてはいけないノード型 (PROTOCOL §2.2「付けないもの」):
  /// 装飾/構造ノードのタグは意味タグの読取り(RAi・関連TL・TL ソート)を
  /// 汚すので、取り込み時に剥がす。
  static const Set<String> _noTagTypes = {'Icon', 'Avatar', 'ActionBar', 'ActionButton', 'Spacer', 'Row', 'Column', 'Stack', 'Grid', 'Scroll'};

  /// V11 検証ゲート (D-086): 付与先違反のタグを再帰的に剥がした木を返す。
  /// 違反が無ければ自身をそのまま返す(再構築しない)。
  RrlNode sanitizeTags() {
    final children = [for (final child in c) child.sanitizeTags()];
    final childChanged = !identical(children.length, c.length) || Iterable<int>.generate(children.length).any((i) => !identical(children[i], c[i]));
    final badTag = tag != null && _noTagTypes.contains(t);
    if (!badTag && !childChanged) return this;
    return RrlNode(t: t, k: k, tag: badTag ? null : tag, role: role, p: p, on: on, c: childChanged ? children : c);
  }

  /// Depth-first search by explicit key. Keys are expected to be tree-unique
  /// for patch targets (plugin's responsibility, PROTOCOL §2).
  RrlNode? findByKey(String key) {
    if (k == key) return this;
    for (final child in c) {
      final hit = child.findByKey(key);
      if (hit != null) return hit;
    }
    return null;
  }

  /// True if this node or any descendant carries [wantedTag].
  bool containsTag(String wantedTag) => tag == wantedTag || c.any((child) => child.containsTag(wantedTag));

  /// V5 検証(完全置き換えタイルの必須ロール)などで使う (D-082)。
  bool containsRole(String wantedRole) => role == wantedRole || c.any((child) => child.containsRole(wantedRole));
}

/// `nodeId = "{instanceScope}:{key}"` where
/// `instanceScope = pluginId:accountKey:pluginVersion:instanceId` and
/// `accountKey = kind:instance:handle` (PROTOCOL §1) — so the key is always
/// the last `:`-separated segment.
@immutable
class RrlNodeId {
  const RrlNodeId({required this.instanceScope, required this.key});

  final String instanceScope;
  final String key;

  static RrlNodeId parse(String nodeId) {
    final cut = nodeId.lastIndexOf(':');
    if (cut <= 0 || cut == nodeId.length - 1) {
      throw FormatException('not a nodeId (instanceScope:key): $nodeId');
    }
    return RrlNodeId(instanceScope: nodeId.substring(0, cut), key: nodeId.substring(cut + 1));
  }

  @override
  String toString() => '$instanceScope:$key';

  @override
  bool operator ==(Object other) => other is RrlNodeId && other.instanceScope == instanceScope && other.key == key;

  @override
  int get hashCode => Object.hash(instanceScope, key);
}
