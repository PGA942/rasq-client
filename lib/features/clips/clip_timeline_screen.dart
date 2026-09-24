import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../session/session_providers.dart';
import '../../shell/headers.dart';
import '../child_safe/child_safe_collections.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../child_safe/child_safe_screens.dart' show ChildSafeBlockedView;
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import '../relational/relational_event_screen.dart';
import 'host_clips.dart';
import 'index_toc.dart';
import 'virtual_index.dart';

/// クリップTL (D-032/D-036)。ネイティブクリップとホスト横断クリップの
/// 詳細画面 — 中身の投稿列の**最上位に仮想目次**を重ねる。目次の項目を
/// タップするとその章の投稿だけに絞り込み、もう一度タップで解除する
/// (投稿そのものの順番・所属は変えない)。
class ClipTimelineScreen extends ConsumerStatefulWidget {
  const ClipTimelineScreen({super.key, required this.clip});
  final ClipInfo clip;

  @override
  ConsumerState<ClipTimelineScreen> createState() => _ClipTimelineScreenState();
}

class _ClipTimelineScreenState extends ConsumerState<ClipTimelineScreen> {
  List<Post>? _posts;
  String? _cursor;
  bool _loading = false;
  Object? _error;
  String? _selectedEntry;

  bool get _isHost => widget.clip.isHost;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isHost) {
        final id = widget.clip.id.substring(hostClipIdPrefix.length);
        final all = await ref.read(hostClipsProvider.future);
        final clip = all.where((c) => c.id == id).firstOrNull;
        final entries = [...?clip?.entries]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
        _posts = [for (final e in entries) postFromSnapshot(e.snapshot)];
      } else {
        final s = ref.read(currentSnsSessionProvider);
        if (s == null) throw StateError('セッションがありません');
        final page = await s.clipNotes(widget.clip.id, cursor: more ? _cursor : null);
        _posts = more ? [...?_posts, ...page.items] : page.items;
        _cursor = page.nextCursor;
      }
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isHost) ref.watch(hostClipsProvider); // 追加/削除に追従
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final posts = _posts ?? const <Post>[];
    final index = buildClipIndex(posts);
    final selected = findIndexEntry(index, _selectedEntry);
    final visible = selected == null ? posts : [for (final p in posts) if (selected.postKeys.contains(p.key)) p];

    // ヘッダーはリレーショナルページと同じブロック(D-037):
    // 参加メンバー + 実在語見出し + 説明 + キーワードチップ。
    // チャイルドセーフ (D-314): 止める例に近い中身のクリップは開かない(自分のものは一覧からも外している。他人のクリップは
    // 読んだ中身で決める)。確かめ終わるまでは中身を出さない。
    final gate = ref.watch(childGateProvider);
    if (gate.hasDenyExamples) {
      final hidden = ref.watch(childSafeHiddenCollectionsProvider).value;
      if (hidden == null || (_posts == null && _error == null)) return Scaffold(appBar: RasqPageHeader(title: widget.clip.name), body: const RasqLoading());
      if (childSafeCollectionHidden(gate, hidden, kind: 'clip', id: widget.clip.id, name: widget.clip.name, description: widget.clip.description) ||
          gate.collectionHidden(childSafeCollectionMeta(widget.clip.name, widget.clip.description), [for (final p in posts) '${p.body} ${p.quote?.body ?? ''}'])) {
        return Scaffold(appBar: RasqPageHeader(title: widget.clip.name), body: const ChildSafeBlockedView(message: '保護者がこのクリップを止めています'));
      }
    }
    final selfKey = ref.watch(currentUserProvider).key;
    final memberSeen = <String>{};
    final members = [for (final p in posts) if (memberSeen.add(p.author.key)) p.author];
    final avatars = [for (final u in members) if (u.key != selfKey) u];

    return Scaffold(
      appBar: RasqPageHeader(title: widget.clip.name),
      body: _error != null
          ? RasqErrorView(code: _error is SnsApiException ? (_error as SnsApiException).code : ErrorCode.internalServerError.copyWith(message: '$_error'), onRetry: _load, retryLabel: '再読み込み')
          : posts.isEmpty && _loading
              ? const RasqLoading()
              : posts.isEmpty
                  ? const RasqEmptyView(title: 'クリップは空です', hint: '投稿メニューの「クリップに追加」からここへ集められます')
                  : RefreshIndicator(
                      onRefresh: () => _load(),
                      child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                        EventStyleHeader(
                          members: avatars.isEmpty ? members : avatars,
                          title: widget.clip.name,
                          caption: [
                            '${widget.clip.notesCount ?? posts.length}件',
                            if (_isHost) 'RASQ クリップ(SNS 横断)' else if (!widget.clip.isPublic) '非公開クリップ' else if (widget.clip.owner != null) widget.clip.owner!.displayName,
                          ].join(' ・ '),
                          headline: sharedHeadline(posts),
                          description: widget.clip.description,
                          chips: topSharedLabels(posts),
                        ),
                        VirtualIndexToc(entries: index, selectedId: _selectedEntry, onSelect: (id) => setState(() => _selectedEntry = id)),
                        for (final p in visible) ...[
                          PostRow(
                            post: p,
                            actions: _isHost ? const [] : actions,
                            onAction: (a, {args = const {}}) => ref.read(timelineProvider(TimelineKind.home).notifier).perform(p, a, args: args),
                            onTap: _isHost ? null : () => context.pushPost(p),
                          ),
                          const Divider(),
                        ],
                        if (!_isHost && _cursor != null)
                          Center(
                            child: TextButton(onPressed: _loading ? null : () => _load(more: true), child: Text(_loading ? '読み込み中…' : 'さらに読み込む')),
                          ),
                      ]),
                    ),
    );
  }
}
