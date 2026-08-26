import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../home/post_row.dart';
import '../home/timeline_providers.dart';
import 'host_clips.dart';
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
  bool _indexOpen = true;

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
    final scheme = Theme.of(context).colorScheme;
    if (_isHost) ref.watch(hostClipsProvider); // 追加/削除に追従
    final session = ref.watch(currentSnsSessionProvider);
    final actions = session?.actions ?? const <ActionDescriptor>[];
    final posts = _posts ?? const <Post>[];
    final index = buildClipIndex(posts);
    final selected = _selectedEntry == null ? null : _findEntry(index, _selectedEntry!);
    final visible = selected == null ? posts : [for (final p in posts) if (selected.postKeys.contains(p.key)) p];

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
                        if (index.isNotEmpty) _tableOfContents(index, scheme),
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

  IndexEntry? _findEntry(List<IndexEntry> entries, String id) {
    for (final e in entries) {
      if (e.id == id) return e;
      for (final c in e.children) {
        if (c.id == id) return c;
      }
    }
    return null;
  }

  /// 仮想目次: 実在語ラベル + 件数。最大 2 階層。タップで絞り込み(トグル)。
  Widget _tableOfContents(List<IndexEntry> index, ColorScheme scheme) {
    Widget row(IndexEntry e, {bool child = false}) {
      final active = _selectedEntry == e.id;
      return InkWell(
        onTap: () => setState(() => _selectedEntry = active ? null : e.id),
        child: Container(
          padding: EdgeInsets.fromLTRB(RasqSpacing.page + (child ? RasqSpacing.lg : 0), 6, RasqSpacing.page, 6),
          color: active ? scheme.primary.withValues(alpha: 0.08) : null,
          child: Row(children: [
            Icon(child ? Icons.subdirectory_arrow_right : (e.labelSource == 'fallback' ? Icons.more_horiz : Icons.tag), size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(child: Text(e.label, style: RasqTypography.bodySmall.copyWith(fontWeight: active ? FontWeight.w700 : null, color: e.labelSource == 'fallback' ? scheme.onSurfaceVariant : null))),
            Text('${e.count}件', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        onTap: () => setState(() => _indexOpen = !_indexOpen),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 4),
          child: Row(children: [
            Icon(Icons.toc, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: RasqSpacing.sm),
            Text('目次', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
            if (_selectedEntry != null) ...[
              const SizedBox(width: RasqSpacing.sm),
              Text('絞り込み中', style: RasqTypography.caption.copyWith(color: scheme.primary)),
            ],
            const Spacer(),
            AnimatedRotation(turns: _indexOpen ? 0 : -0.25, duration: const Duration(milliseconds: 150), child: Icon(Icons.keyboard_arrow_down, size: 18, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
      if (_indexOpen)
        for (final e in index) ...[
          row(e),
          for (final c in e.children) row(c, child: true),
        ],
      const Divider(),
    ]);
  }
}
