import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../l10n/l10n.dart';
import '../clips/virtual_index.dart';

/// リスト系(SNS のリスト / フィード / RASQ リスト)の「話題の目次」タブ (D-368)。AsTell のルームの「目次」と同じ形:
/// 話題(会話のまとまり、[indexForListTimeline])を時刻順に並べ、タップで「投稿」タブのその話題へ(絞り込み)。
/// 選んだ話題は [listTopicSelectionProvider](画面ごとの scope)に置き、投稿タブは [ListTopicFilterBar] で解除できる。

class _TopicSelection extends Notifier<String?> {
  _TopicSelection(this.scope);
  final String scope;

  @override
  String? build() => null;

  void select(String? id) => state = id;
}

/// scope(`list:<id>` / `feed:<uri>` / `rasq:<id>`)→ 選んでいる話題の id。
final listTopicSelectionProvider = NotifierProvider.autoDispose.family<_TopicSelection, String?, String>(_TopicSelection.new);

String _hhmm(DateTime t, DateTime now) {
  final l = t.toLocal();
  final hm = '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  final n = now.toLocal();
  return l.year == n.year && l.month == n.month && l.day == n.day ? hm : '${l.month}/${l.day} $hm';
}

IconData _iconOf(IndexEntry e) {
  if (e.labelSource == 'fallback') return Icons.more_horiz;
  return switch (e.state) {
    IndexEntryState.active => Icons.forum_outlined,
    IndexEntryState.dormant => Icons.history,
    IndexEntryState.tentative => Icons.pending_outlined,
  };
}

/// 話題の目次のタブの中身。[postsTabIndex] = 「投稿」タブの位置(タップでそこへ移る)。
class ListTopicsTab extends ConsumerWidget {
  const ListTopicsTab({super.key, required this.scope, required this.entries, required this.posts, required this.postsTabIndex, this.now});

  final String scope;
  final List<IndexEntry> entries;

  /// 見出しの下に出す代表の投稿を引く(key → 投稿)。
  final Map<String, Post> posts;
  final int postsTabIndex;
  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(listTopicSelectionProvider(scope));
    final clock = now ?? DateTime.now();
    final l10n = context.l10n;
    if (entries.isEmpty) return RasqEmptyView(title: l10n.listsTopicsEmpty, hint: l10n.listsTopicsEmptyHint);
    // 時刻順(AsTell の目次と同じ)。単発投稿のまとまりは最後。
    final sorted = [...entries]..sort((a, b) {
        final fa = a.labelSource == 'fallback' ? 1 : 0;
        final fb = b.labelSource == 'fallback' ? 1 : 0;
        return fa != fb ? fa - fb : a.startedAt.compareTo(b.startedAt);
      });
    return ListView(key: ValueKey('topics.$scope'), padding: EdgeInsets.zero, children: [
      RasqCaption(l10n.listsTopicsCaption, detail: l10n.listsTopicsCaptionDetail),
      for (final e in sorted)
        RasqListTile(
          key: ValueKey('topics.entry.${e.id}'),
          title: e.label,
          subtitle: [
            _subtitle(l10n, e, clock),
            ?_snippet(l10n, e),
          ].join('\n'),
          leading: Icon(_iconOf(e), size: 18),
          trailing: selected == e.id ? const Icon(Icons.check, size: 18, color: RasqColors.link) : null,
          chevron: false,
          onTap: () {
            ref.read(listTopicSelectionProvider(scope).notifier).select(e.id);
            DefaultTabController.maybeOf(context)?.animateTo(postsTabIndex);
          },
        ),
      const SizedBox(height: RasqSpacing.xxl),
    ]);
  }

  static String _subtitle(AppLocalizations l10n, IndexEntry e, DateTime clock) {
    final start = _hhmm(e.startedAt, clock);
    final time = e.lastActiveAt.difference(e.startedAt).inMinutes >= 1 ? l10n.listsTopicTimeRange(start, _hhmm(e.lastActiveAt, clock)) : start;
    final people = e.participantKeys.length;
    return people > 1 ? l10n.listsTopicSubtitleWithPeople(time, e.count, people) : l10n.listsTopicSubtitle(time, e.count);
  }

  String? _snippet(AppLocalizations l10n, IndexEntry e) {
    final key = e.representativeKeys.firstOrNull ?? e.postKeys.firstOrNull;
    final p = key == null ? null : posts[key];
    if (p == null) return null;
    final body = p.body.replaceAll('\n', ' ').trim();
    if (body.isEmpty) return null;
    return l10n.listsTopicSnippet(p.author.displayName, body.length > 40 ? '${body.substring(0, 40)}…' : body);
  }
}

/// 投稿タブの上: 話題で絞っているときだけ「話題: ○○ ✕」。
class ListTopicFilterBar extends ConsumerWidget {
  const ListTopicFilterBar({super.key, required this.scope, required this.entry});
  final String scope;
  final IndexEntry? entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = entry;
    if (e == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InputChip(
          key: const ValueKey('topics.filter'),
          avatar: const Icon(Icons.forum_outlined, size: 16),
          label: Text(context.l10n.listsTopicFilterChip(e.label, e.count)),
          onDeleted: () => ref.read(listTopicSelectionProvider(scope).notifier).select(null),
          deleteButtonTooltipMessage: context.l10n.listsTopicFilterClear,
        ),
      ),
    );
  }
}
