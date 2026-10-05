import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../session/session_providers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../relational/relational_engine.dart';
import '../swing/swing_banner.dart';
import '../swing/swing_models.dart';
import '../swing/swing_providers.dart';
import '../vc/astell_actions.dart' show AstellRoomTile;
import '../vc/astell_providers.dart' show astellHomeProvider;
import '../vc/astell_tile.dart' show AstellTileStrip;
import '../vc/vc_screen.dart' show searchAstellRooms;
import '../relational/relational_providers.dart' show relationalSettingsProvider;
import '../relational/relational_timeline_view.dart' show RelationalEventCard;
import '../users/user_list.dart';
import 'node_tabs.dart';
import 'tl_components.dart';
import 'tl_config_store.dart';

/// セクション(包むノード)と表示モード (D-439) の画面側。
///
/// - [TlSectionsBlock]: TL の上に、構成の [TlConfig.sections] を枠ごとに並べる。
/// - [TlSectionView]: 1 つの枠。包んだ TL の投稿を**開いたときの分だけ**写して([limit] 件まで)出し、新しい投稿は読み込まない。
///   引き下げ([tlSectionsRefreshProvider] を進める)/ 枠の ↻ で読み直す。
/// - [TlPostsDisplay]: 投稿の並びを表示モード(通常 TL / 関連 TL / ユーザー)で描く。TL 本体の表示モードにも使う。

/// セクションを読み直す合図(引き下げで進める)。
class TlSectionsRefresh extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final tlSectionsRefreshProvider = NotifierProvider<TlSectionsRefresh, int>(TlSectionsRefresh.new);

/// 包める TL の名前([TlSection.tl] → 見出しに出す名前)。
String tlSectionSourceLabel(WidgetRef ref, String tl) {
  if (tl == astellSectionKind) return 'AsTell のタイル';
  if (tl == swingSectionKind) return 'Swing';
  if (tl.startsWith('node:')) return ref.watch(nodeTabsProvider).where((t) => t.id == tl).firstOrNull?.label ?? 'ノード TL';
  final kinds = ref.watch(currentSnsSessionProvider)?.timelines ?? const <TimelineKind>[];
  return kinds.where((k) => k.id == tl).firstOrNull?.label ?? switch (tl) {
        'home' => TimelineKind.home.label,
        'local' => TimelineKind.local.label,
        'social' => TimelineKind.social.label,
        'global' => TimelineKind.global.label,
        _ => tl,
      };
}

/// [scope] の構成のセクション。無ければ何も出さない。
class TlSectionsBlock extends ConsumerWidget {
  const TlSectionsBlock({super.key, required this.scope, this.query});
  final String scope;

  /// このページの検索ワード / タグ (D-441: トレンド TL)。AsTell / Swing の枠はこれに当たるものだけ出す。
  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = [for (final s in ref.watch(tlViewConfigProvider(scope))?.sections ?? const <TlSection>[]) if (s.enabled) s];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(key: ValueKey('tl.sections.$scope'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final s in sections)
        if (s.isAstell || s.isSwing) _LiveSectionView(key: ValueKey('tl.section.${s.id}'), section: s, query: query) else TlSectionView(key: ValueKey('tl.section.${s.id}'), section: s),
    ]);
  }
}

class TlSectionView extends ConsumerStatefulWidget {
  const TlSectionView({super.key, required this.section});
  final TlSection section;

  @override
  ConsumerState<TlSectionView> createState() => _TlSectionViewState();
}

class _TlSectionViewState extends ConsumerState<TlSectionView> {
  /// 開いたときに写した投稿(包んだ TL が新しい投稿を読んでも、ここは変えない)。
  List<Post>? _snapshot;
  int _tick = 0;

  TimelineKind get _kind => TimelineKind(widget.section.tl, widget.section.title);

  @override
  void didUpdateWidget(TlSectionView old) {
    super.didUpdateWidget(old);
    if (old.section.tl != widget.section.tl) _snapshot = null;
  }

  Future<void> _reload() async {
    setState(() => _snapshot = null);
    await ref.read(timelineProvider(_kind).notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final tick = ref.watch(tlSectionsRefreshProvider);
    if (tick != _tick) {
      _tick = tick;
      _snapshot = null;
      Future.microtask(() {
        if (mounted) ref.read(timelineProvider(_kind).notifier).refresh();
      });
    }
    final tl = ref.watch(timelineProvider(_kind));
    if (_snapshot == null && tl.hasValue && !tl.isLoading) _snapshot = tl.requireValue.posts;
    final posts = _snapshot;
    final s = widget.section;
    final scheme = Theme.of(context).colorScheme;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(
        title: s.title.isEmpty ? tlSectionSourceLabel(ref, s.tl) : s.title,
        topMargin: 0,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Tooltip(message: s.display.label, child: Icon(s.display.icon, size: 16, color: scheme.onSurfaceVariant)),
          RasqIconButton(key: ValueKey('tl.section.${s.id}.reload'), icon: Icons.refresh, size: 18, tooltip: '読み直す', onPressed: _reload),
        ]),
      ),
      if (posts == null)
        tl.hasError ? const RasqCaption('読み込めませんでした') : const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
      else if (posts.isEmpty)
        const RasqCaption('まだありません')
      else
        TlPostsDisplay(posts: posts, mode: s.display, limit: s.limit, scrollable: false, kind: _kind),
      const Divider(height: 1),
    ]);
  }
}

/// 投稿の並びを表示モードで描く。[limit] = 出す数(投稿 / 会話 / 人)。[scrollable] = false なら外のリストに埋め込む。
class TlPostsDisplay extends ConsumerWidget {
  const TlPostsDisplay({super.key, required this.posts, required this.mode, this.limit, this.scrollable = true, required this.kind});
  final List<Post> posts;
  final TlDisplayMode mode;
  final int? limit;
  final bool scrollable;

  /// 投稿へのアクション(リアクションなど)を送る TL。
  final TimelineKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = ref.watch(childGateProvider).filterPosts(posts);
    final children = switch (mode) {
      TlDisplayMode.timeline => _posts(context, ref, shown),
      TlDisplayMode.relational => _events(ref, shown),
      TlDisplayMode.users => _users(shown),
    };
    if (scrollable) return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.only(bottom: 80), children: children);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  List<Widget> _posts(BuildContext context, WidgetRef ref, List<Post> shown) {
    final actions = ref.watch(currentSnsSessionProvider)?.actions ?? const <ActionDescriptor>[];
    final notifier = ref.read(timelineProvider(kind).notifier);
    return [
      for (final p in limit == null ? shown : shown.take(limit!)) ...[
        PostRow(post: p, actions: actions, onAction: (a, {args = const {}}) => notifier.perform(p, a, args: args), onTap: () => context.pushPost(p)),
        const Divider(),
      ],
    ];
  }

  /// 関連 TL の形: 並びの投稿から会話のまとまりを組む(関連 TL と同じエンジン、ゲストなし)。
  List<Widget> _events(WidgetRef ref, List<Post> shown) {
    final events = ConversationEngine(settings: ref.watch(relationalSettingsProvider)).build(followeePosts: shown, guestPosts: const []);
    if (events.isEmpty) return const [RasqCaption('会話のまとまりはまだありません')];
    return [
      for (final e in limit == null ? events : events.take(limit!)) ...[RelationalEventCard(key: ValueKey('tl.display.event.${e.id}'), event: e), const Divider()],
    ];
  }

  /// 投稿した人の並び(投稿の多い順、同じなら新しい順)。
  List<Widget> _users(List<Post> shown) {
    final count = <String, int>{};
    final users = <String, UserSummary>{};
    for (final p in shown) {
      count[p.author.key] = (count[p.author.key] ?? 0) + 1;
      users.putIfAbsent(p.author.key, () => p.author);
    }
    final order = users.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    final picked = [for (final k in limit == null ? order : order.take(limit!)) users[k]!];
    if (picked.isEmpty) return const [RasqCaption('まだいません')];
    return [UserList(key: const ValueKey('tl.display.users.list'), users: picked, shrinkWrap: true, subtitles: {for (final u in picked) u.id: '${count[u.key]} 件の投稿'})];
  }
}

/// AsTell のタイル / Swing の並びの枠 (D-441)。どちらも「いま」のものなので、写しは持たずにいまの状態を出す。[query] があれば当たるものだけ。
class _LiveSectionView extends ConsumerWidget {
  const _LiveSectionView({super.key, required this.section, this.query});
  final TlSection section;
  final String? query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = section;
    final q = (query ?? '').replaceFirst(RegExp(r'^#'), '');
    final Widget body;
    if (s.isAstell) {
      // チャイルドセーフ: AsTell に入れないアカウントには出さない。
      if (!ref.watch(childGateProvider).featureAllowed('astell.join')) return const SizedBox.shrink();
      final home = ref.watch(astellHomeProvider);
      final rooms = home.value == null ? null : searchAstellRooms(home.value!, q).take(s.limit).toList();
      body = rooms == null
          ? (home.hasError ? const RasqCaption('読み込めませんでした') : const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))))
          : rooms.isEmpty
              ? RasqCaption(q.isEmpty ? 'いま開いている AsTell はありません' : '「$q」の AsTell はありません')
              : AstellTileStrip(key: ValueKey('tl.section.${s.id}.rooms'), rooms: rooms, tileBuilder: (r) => AstellRoomTile(room: r));
    } else {
      final feed = ref.watch(swingFeedProvider).value ?? const <Swing>[];
      final entries = (q.isEmpty ? swingAuthorsOf(feed) : searchSwingAuthors(feed, q)).take(s.limit).toList();
      body = entries.isEmpty
          ? RasqCaption(q.isEmpty ? 'いま Swing はありません' : '「$q」の Swing はありません')
          : Column(key: ValueKey('tl.section.${s.id}.swings'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final e in entries) Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, 0, RasqSpacing.sm, RasqSpacing.xs), child: SwingBanner(entry: e)),
            ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(title: s.title.isEmpty ? tlSectionSourceLabel(ref, s.tl) : s.title, topMargin: 0),
      body,
      const Divider(height: 1),
    ]);
  }
}
