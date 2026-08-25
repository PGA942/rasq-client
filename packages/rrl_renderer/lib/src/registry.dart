import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_core/rrl_core.dart';

import 'host.dart';

/// Builds one L2 Standard Component from resolved props.
///
/// [props] are the node's `p` with every Bind already resolved; [children]
/// are the node's rendered children (may be empty — most L2 nodes are
/// Props-only per D-002).
typedef RrlComponentBuilder = Widget Function(RrlL2Context ctx);

/// What an L2 builder gets to work with.
class RrlL2Context {
  RrlL2Context({
    required this.node,
    required this.props,
    required this.children,
    required this.host,
    required this.scope,
    required this.renderChild,
  });

  final RrlNode node;
  final Map<String, Object?> props;
  final List<Widget> children;
  final RrlHost host;
  final RrlScope scope;

  /// Renders an arbitrary child node in this scope (used by composite
  /// builders that pick specific children for their slots).
  final Widget Function(RrlNode) renderChild;

  void emit(String kind, [Map<String, Object?> payload = const {}]) => host.emit(node, scope, kind, payload);

  VoidCallback? tapHandler(String kind) => node.on.containsKey(kind) ? () => emit(kind) : null;
}

/// Host icon registry (plugin icon names → Material glyphs, D-017: bundled
/// defaults; the RASQ icon font replaces this later).
IconData rrlIconFor(String? name, [IconData fallback = Icons.circle_outlined]) => _icons[name] ?? fallback;

const _icons = <String, IconData>{
  'subdirectory_arrow_left': Icons.subdirectory_arrow_left,
  'repeat': Icons.repeat,
  'repeat_on': Icons.repeat_on,
  'add_reaction_outlined': Icons.add_reaction_outlined,
  'add_reaction': Icons.add_reaction,
  'star_border': Icons.star_border,
  'star': Icons.star,
  'favorite_border': Icons.favorite_border,
  'favorite': Icons.favorite,
  'ios_share': Icons.ios_share,
  'bookmark_border': Icons.bookmark_border,
  'bookmark': Icons.bookmark,
  'link': Icons.link,
  'search': Icons.search,
  'settings': Icons.settings_outlined,
};

// ---- prop coercion helpers (wire JSON → typed props) -----------------------

String rrlString(Object? v, [String fallback = '']) => v?.toString() ?? fallback;

Uri? rrlUri(Object? v) => v == null ? null : Uri.tryParse(v.toString());

DateTime rrlTime(Object? v) => switch (v) {
      DateTime d => d,
      int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      String s => DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0),
      _ => DateTime.fromMillisecondsSinceEpoch(0),
    };

bool rrlTruthy(Object? v) => switch (v) {
      null => false,
      bool b => b,
      num n => n != 0,
      String s => s.isNotEmpty,
      List l => l.isNotEmpty,
      Map m => m.isNotEmpty,
      _ => true,
    };

Map<String, Object?> rrlMap(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

List<Object?> rrlList(Object? v) => v is List ? v : const [];

/// `{displayName, handle, avatarUrl, kind?, instance?, id?, verification?}` →
/// [UserSummary]. SNS adapters ship real models; over the wire we get maps.
UserSummary rrlUser(Object? v) {
  final m = rrlMap(v);
  final kind = SnsKind.values.asNameMap()[rrlString(m['kind'])] ?? SnsKind.other;
  return UserSummary(
    id: rrlString(m['id'], rrlString(m['handle'], '?')),
    account: AccountId(kind: kind, instance: rrlString(m['instance'], '-'), handle: rrlString(m['handle'], '?')),
    displayName: rrlString(m['displayName'], rrlString(m['handle'], '?')),
    avatarUrl: rrlUri(m['avatarUrl']),
    verification: UserVerification.values.asNameMap()[rrlString(m['verification'])] ?? UserVerification.none,
  );
}

MediaItem rrlMediaItem(Object? v) {
  final m = rrlMap(v);
  return MediaItem(
    id: rrlString(m['id'], rrlString(m['url'])),
    type: MediaType.values.asNameMap()[rrlString(m['type'])] ?? MediaType.image,
    url: rrlUri(m['url']) ?? Uri.parse('about:blank'),
    thumbnailUrl: rrlUri(m['thumbnailUrl']),
    alt: m['alt'] as String?,
    sensitive: rrlTruthy(m['sensitive']),
    fileName: m['fileName'] as String?,
  );
}

Poll rrlPoll(Object? v) {
  final m = rrlMap(v);
  return Poll(
    options: [
      for (final o in rrlList(m['options']))
        PollOption(text: rrlString(rrlMap(o)['text']), votes: (rrlMap(o)['votes'] as num?)?.toInt() ?? 0),
    ],
    multiple: rrlTruthy(m['multiple']),
    expiresAt: m['expiresAt'] == null ? null : rrlTime(m['expiresAt']),
    votedIndices: {for (final i in rrlList(m['votedIndices'])) (i as num).toInt()},
  );
}

/// The default L2 registry: type name → host implementation in `rasq_design`.
/// Hosts can override / extend via `RrlHost.components`. Types without an
/// entry render as an inline "unsupported" box (never a crash).
abstract final class RrlComponentRegistry {
  static final Map<String, RrlComponentBuilder> standard = {
    'Avatar': (ctx) {
      final user = rrlUser(ctx.props['user']);
      return RasqAvatar(imageUrl: user.avatarUrl, fallbackLabel: user.displayName, onTap: ctx.tapHandler('tap'));
    },
    'Badge': (ctx) => RasqBadge(count: (ctx.props['count'] as num?)?.toInt(), dot: rrlTruthy(ctx.props['dot'])),
    'RichText': (ctx) => RasqRichText(ctx.host.parseRsl(rrlString(ctx.props['source'])), style: RasqTypography.body),
    'Timestamp': (ctx) => RasqTimestamp(rrlTime(ctx.props['time'])),
    'Button': (ctx) => FilledButton(onPressed: ctx.tapHandler('tap'), child: Text(rrlString(ctx.props['label']))),
    'ActionButton': (ctx) => RasqActionButton.iconCount(
          icon: rrlIconFor(rrlString(ctx.props['icon'])),
          doneIcon: ctx.props['doneIcon'] == null ? null : rrlIconFor(rrlString(ctx.props['doneIcon'])),
          done: rrlTruthy(ctx.props['done']),
          count: (ctx.props['count'] as num?)?.toInt() ?? 0,
          tooltip: ctx.props['label'] as String?,
          onTap: ctx.tapHandler('tap'),
          onLongPress: ctx.node.on.containsKey('longPress') ? () => ctx.emit('longPress') : null,
        ),
    'MediaGrid': (ctx) => RasqMediaGrid(
          items: [for (final m in rrlList(ctx.props['items'])) rrlMediaItem(m)],
          onTapTile: ctx.node.on.containsKey('tap') ? (i) => ctx.emit('tap', {'index': i}) : null,
        ),
    'PollWidget': (ctx) => RasqPollWidget(
          poll: rrlPoll(ctx.props['poll']),
          onVote: ctx.node.on.containsKey('confirm') ? (choices) => ctx.emit('confirm', {'choices': choices.toList()}) : null,
        ),
    'CollapsedPost': (ctx) => RasqCollapsedPost(
          spans: ctx.host.parseRsl(rrlString(ctx.props['source'])),
          onExpand: ctx.tapHandler('tap'),
        ),
    'SectionHeader': (ctx) => RasqSectionHeader(title: rrlString(ctx.props['title'])),
    'ListTile': (ctx) => RasqListTile(
          title: rrlString(ctx.props['title']),
          subtitle: ctx.props['subtitle'] as String?,
          onTap: ctx.tapHandler('tap'),
        ),
    'UserRow': (ctx) => RasqUserRow(user: rrlUser(ctx.props['user']), onTap: ctx.tapHandler('tap')),
    'ActionBar': _actionBar,
    'PostTile': _postTile,
  };

  /// `p.actions` = list of descriptor maps, `p.states` = `{actionId: {done,
  /// count, enabled, iconUrl}}` (both usually Binds into host data).
  static Widget _actionBar(RrlL2Context ctx) {
    final states = rrlMap(ctx.props['states']);
    final items = <RasqActionBarItem>[];
    for (final raw in rrlList(ctx.props['actions'])) {
      final a = rrlMap(raw);
      final id = rrlString(a['id']);
      final st = rrlMap(states[id]);
      items.add(RasqActionBarItem(
        id: id,
        label: rrlString(a['label'], id),
        icon: rrlIconFor(a['icon'] as String?),
        doneIcon: a['doneIcon'] == null ? null : rrlIconFor(a['doneIcon'] as String?),
        done: rrlTruthy(st['done']),
        count: (st['count'] as num?)?.toInt() ?? (a['count'] as num?)?.toInt(),
        showCount: rrlString(a['countSource'], 'self') != 'none',
        enabled: st['enabled'] == null || rrlTruthy(st['enabled']),
        iconUrl: rrlUri(st['iconUrl']),
        onTap: () => ctx.emit('tap', {'actionId': id}),
        onLongPress: () => ctx.emit('longPress', {'actionId': id}),
      ));
    }
    return RasqActionBar(items: items, trailing: [for (final w in ctx.children) w]);
  }

  /// Composite realize step: maps the PostTile node's children onto
  /// [RasqPostTile]'s slots (D-004/D-005). The tile owns geometry + header,
  /// so header rows / avatars in the RRL tree are absorbed:
  ///
  /// - child with `role: actionBar` → action slot
  /// - `MediaGrid` (or `tag: pic` container) → media slot
  /// - `Avatar` → avatar slot override
  /// - header `Row` (contains `user_name`/`user_handle`/`time` tags) → dropped
  /// - everything else, in order → content slot
  static Widget _postTile(RrlL2Context ctx) {
    final post = rrlMap(ctx.props['post']);
    final author = rrlUser(post['author']);
    Widget? avatar, media, actionBar;
    final content = <Widget>[];
    for (final child in ctx.node.c) {
      if (child.role == 'actionBar' || child.t == 'ActionBar') {
        actionBar = ctx.renderChild(child);
      } else if (child.t == 'MediaGrid' || child.tag == 'pic') {
        media = ctx.renderChild(child);
      } else if (child.t == 'Avatar') {
        avatar = ctx.renderChild(child);
      } else if (child.t == 'Row' && (child.containsTag('user_name') || child.containsTag('user_handle') || child.containsTag('time'))) {
        // Header row — RasqPostTile renders its own header from props.
      } else {
        content.add(ctx.renderChild(child));
      }
    }
    final variant = switch (rrlString(ctx.props['variant'], 'normal')) {
      'embedded' => RasqPostTileVariant.embedded,
      'threadSummary' => RasqPostTileVariant.threadSummary,
      _ => RasqPostTileVariant.normal,
    };
    return RasqPostTile(
      variant: variant,
      author: author,
      createdAt: rrlTime(post['createdAt']),
      avatar: avatar,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: content),
      media: media,
      actionBar: actionBar,
      onTap: ctx.tapHandler('tap'),
    );
  }
}
