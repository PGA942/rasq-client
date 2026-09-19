import 'dart:convert';

import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';

/// 投稿から画像を探す FOW (D-258): コンポーザーの添付に、SNS の投稿の画像を選ぶ。
///
/// 構成(上から): 検索欄 / 探す場所(ドロップダウンで種別を選ぶ)/ 投稿の一覧(画像のある投稿だけ。サムネイルを押して選ぶ)。
/// - 探す場所: その SNS のタイムライン(フォロー中 など)/ 自分の投稿 / リアクションした投稿 / ブックマーク / **最近選んだ画像**
///   (端末に控える履歴)。検索欄に入れて決定すると、その SNS の投稿検索の結果になる(消すと元の場所に戻る)。
/// - **公開範囲が フォロワーのみ / 指名(自分のみ・ダイレクト)の投稿は出さない**([isPickablePost])。元の投稿が限定公開なのに、
///   その画像を別の投稿に付けて広めてしまわないため。除いた件数は一覧の上に出す。
/// - SNS プラグインが持たない機能(検索 / 履歴など)は `UnsupportedError` → 「この SNS では使えません」。
const postImagePickerFowId = 'fow.composer.postImages';
const postImagePickerSearchKey = Key('postPicker.search');
const postImagePickerSourceKey = Key('postPicker.source');

/// 選ばれた 1 枚(元の投稿つき)。
typedef PickedPostImage = ({MediaItem item, Post post});

/// 添付に使ってよい投稿か: 公開範囲が フォロワーのみ / 指名 / ダイレクト(プラグインごとの言い方を含む)でないこと。
/// 公開範囲を持たない SNS(null)は公開として扱う。
bool isPickablePost(Post p) {
  if (p.isDirect) return false;
  const limited = {'followers', 'private', 'specified', 'direct', 'limited', 'mutuals_only', 'self'};
  return !limited.contains(p.visibility);
}

/// 選べる画像(静止画 / GIF)。
List<MediaItem> pickableImagesOf(Post p) => [for (final m in p.media) if (m.type == MediaType.image || m.type == MediaType.gif) m];

/// 探す場所 1 つ。
@immutable
class PostPickerSource {
  const PostPickerSource(this.id, this.label);
  final String id;
  final String label;

  static const mine = PostPickerSource('mine', '自分の投稿');
  static const reacted = PostPickerSource('reacted', 'リアクションした投稿');
  static const favorites = PostPickerSource('favorites', 'ブックマーク');
  static const recent = PostPickerSource('recent', '最近選んだ画像');

  static List<PostPickerSource> of(SnsSession session) => [
        for (final t in session.timelines) PostPickerSource('tl:${t.id}', t.label),
        mine,
        reacted,
        favorites,
        recent,
      ];
}

/// 最近選んだ画像(端末に控える。新しい順、24 件まで)。投稿の最小限(作者の表示名 / 本文の頭 / その 1 枚)だけ持つ。
class PostPickerRecent extends Notifier<List<PickedPostImage>> {
  static const storageKey = 'postPicker.recent.v1';
  static const max = 24;
  Future<void>? _restored;

  @override
  List<PickedPostImage> build() {
    _restored = _restore();
    return const [];
  }

  Future<void> get ready => _restored ?? Future.value();

  Future<void> _restore() async {
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw == null) return;
      state = [for (final e in jsonDecode(raw) as List) if (e is Map) _decode(e.cast<String, Object?>())].whereType<PickedPostImage>().toList();
    } catch (_) {}
  }

  static PickedPostImage? _decode(Map<String, Object?> j) {
    final url = Uri.tryParse('${j['url'] ?? ''}');
    final account = j['account'];
    if (url == null || !url.hasScheme || account is! Map) return null;
    final kind = SnsKind.values.where((k) => k.name == account['kind']).firstOrNull;
    if (kind == null) return null;
    final acc = AccountId(kind: kind, instance: '${account['instance'] ?? ''}', handle: '${account['handle'] ?? ''}');
    final item = MediaItem(id: '${j['mediaId'] ?? url}', type: j['gif'] == true ? MediaType.gif : MediaType.image, url: url, thumbnailUrl: j['thumb'] is String ? Uri.tryParse(j['thumb'] as String) : null, sensitive: j['sensitive'] == true);
    final post = Post(id: '${j['postId'] ?? ''}', account: acc, author: UserSummary(id: '${j['authorId'] ?? ''}', account: acc, displayName: '${j['author'] ?? ''}'), createdAt: DateTime.tryParse('${j['at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0), body: '${j['body'] ?? ''}', media: [item], visibility: j['visibility'] as String?);
    return (item: item, post: post);
  }

  static Map<String, Object?> _encode(PickedPostImage p) => {
        'url': '${p.item.url}',
        if (p.item.thumbnailUrl != null) 'thumb': '${p.item.thumbnailUrl}',
        'mediaId': p.item.id,
        'gif': p.item.type == MediaType.gif,
        'sensitive': p.item.sensitive,
        'postId': p.post.id,
        'account': {'kind': p.post.account.kind.name, 'instance': p.post.account.instance, 'handle': p.post.account.handle},
        'authorId': p.post.author.id,
        'author': p.post.author.displayName,
        'body': p.post.body.length > 80 ? p.post.body.substring(0, 80) : p.post.body,
        'at': p.post.createdAt.toIso8601String(),
        if (p.post.visibility != null) 'visibility': p.post.visibility,
      };

  Future<void> add(PickedPostImage picked) async {
    await ready;
    state = [picked, for (final p in state) if (p.item.url != picked.item.url) p].take(max).toList();
    await ref.read(sessionStorageProvider).write(storageKey, jsonEncode([for (final p in state) _encode(p)]));
  }
}

final postPickerRecentProvider = NotifierProvider<PostPickerRecent, List<PickedPostImage>>(PostPickerRecent.new);

/// 1 ページぶん取りに行く。`query` があれば投稿検索、無ければ [source]。
Future<Page<Post>> fetchPickerPage(SnsSession session, PostPickerSource source, {String query = '', String? cursor}) async {
  const limit = 30;
  if (query.isNotEmpty) return session.searchPosts(query, cursor: cursor, limit: limit);
  switch (source.id) {
    case 'mine':
      return session.userPosts((await session.me()).id, cursor: cursor, limit: limit, filter: UserPostsFilter.media);
    case 'reacted':
      return session.reactedPosts(cursor: cursor, limit: limit);
    case 'favorites':
      return session.favorites(cursor: cursor, limit: limit);
    default:
      final id = source.id.startsWith('tl:') ? source.id.substring(3) : source.id;
      final kind = session.timelines.where((t) => t.id == id).firstOrNull ?? TimelineKind(id, source.label);
      return session.timeline(kind, cursor: cursor, limit: limit);
  }
}

Future<PickedPostImage?> showPostImagePickerFow(WidgetRef ref, {String? ownerId, int column = 0}) async {
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains(postImagePickerFowId)) return null;
  final picked = await manager.showFow<PickedPostImage>(
    id: postImagePickerFowId,
    ownerId: ownerId,
    spec: FowSpec(type: FowPanelType.widget, title: '投稿から画像を探す', cancelText: 'キャンセル', initialHeightFactor: 0.75, minHeightFactor: 0.3, maxHeightFactor: 0.92, maxWidth: 640, dockAboveFooter: true, columnIndex: column),
    semanticsLabel: '投稿から画像を探す',
    builder: (_, _) => _PickerBody(onPick: (p) => manager.close(postImagePickerFowId, result: p)),
  );
  if (picked != null) await ref.read(postPickerRecentProvider.notifier).add(picked);
  return picked;
}

class _PickerBody extends ConsumerStatefulWidget {
  const _PickerBody({required this.onPick});
  final ValueChanged<PickedPostImage> onPick;
  @override
  ConsumerState<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends ConsumerState<_PickerBody> {
  final _search = TextEditingController();
  String _query = '';
  PostPickerSource? _source;

  List<Post> _posts = const [];
  int _excluded = 0;
  String? _cursor;
  bool _loading = false;
  String? _error;

  /// 取りに行くたびに増やす(古い返事を捨てる)。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  SnsSession? get _session => ref.read(currentSnsSessionProvider);

  Future<void> _reload() => _load(reset: true);

  Future<void> _load({required bool reset}) async {
    final session = _session;
    if (session == null) return setState(() => _error = 'アカウントがありません');
    final source = _source ??= PostPickerSource.of(session).first;
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _posts = const [];
        _excluded = 0;
        _cursor = null;
      }
    });
    // 最近選んだ画像は端末の履歴から(検索中は SNS の検索が優先)。
    if (_query.isEmpty && source.id == PostPickerSource.recent.id) {
      await ref.read(postPickerRecentProvider.notifier).ready;
      if (!mounted || gen != _generation) return;
      return setState(() {
        _posts = [for (final p in ref.read(postPickerRecentProvider)) p.post];
        _loading = false;
      });
    }
    try {
      final page = await fetchPickerPage(session, source, query: _query, cursor: reset ? null : _cursor);
      if (!mounted || gen != _generation) return;
      final withImages = [for (final p in page.items) if (pickableImagesOf(p).isNotEmpty) p];
      final ok = [for (final p in withImages) if (isPickablePost(p)) p];
      setState(() {
        final seen = {for (final p in _posts) p.key};
        _posts = [..._posts, for (final p in ok) if (seen.add(p.key)) p];
        _excluded += withImages.length - ok.length;
        _cursor = page.hasMore ? page.nextCursor : null;
        _loading = false;
      });
    } on UnsupportedError {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = _query.isNotEmpty ? 'この SNS では投稿の検索が使えません' : 'この SNS では「${source.label}」が使えません';
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = '取得できませんでした: $e';
      });
    }
  }

  Future<void> _pickSource(BuildContext ctx) async {
    final session = _session;
    if (session == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    final picked = await ref.read(overlayManagerProvider).showDropdown<PostPickerSource>(
          id: 'postPicker.source.menu',
          ownerId: postImagePickerFowId,
          anchor: box.localToGlobal(Offset.zero) & box.size,
          dense: true,
          items: [for (final s in PostPickerSource.of(session)) RasqDropdownItem(s.label, s, checked: s.id == _source?.id)],
        );
    if (picked == null || !mounted) return;
    // 場所を選び直したら検索はやめる(検索結果のままだと、選んだ場所が出ないため)。
    _search.clear();
    _query = '';
    _source = picked;
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final searching = _query.isNotEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // ── 検索欄 ──
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
        child: RasqInput(
          key: postImagePickerSearchKey,
          controller: _search,
          hintText: '投稿を検索(決定で探す、空にすると下の場所に戻る)',
          prefix: const Icon(Icons.search, size: 18),
          onSubmitted: (v) {
            _query = v.trim();
            _reload();
          },
        ),
      ),
      // ── 探す場所(ドロップダウン)──
      Builder(
        builder: (ctx) => RasqListTile(
          key: postImagePickerSourceKey,
          leading: Icon(searching ? Icons.manage_search : Icons.view_stream_outlined),
          title: searching ? '検索結果: 「$_query」' : (_source?.label ?? '…'),
          subtitle: searching ? '場所を選ぶと検索をやめます' : '探す場所',
          trailing: const Icon(Icons.arrow_drop_down),
          chevron: false,
          onTap: () => _pickSource(ctx),
        ),
      ),
      if (_excluded > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
          child: Text('公開範囲が フォロワーのみ / 指名 の投稿 $_excluded 件は出していません。', key: const ValueKey('postPicker.excluded'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
      const Divider(height: 1),
      // ── 投稿の一覧 ──
      Expanded(
        child: _error != null
            ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(_error!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)))
            : _posts.isEmpty
                ? (_loading ? const RasqLoading() : Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(searching ? '画像のある投稿は見つかりませんでした' : '画像のある投稿はありません', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant))))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: RasqSpacing.lg),
                    itemCount: _posts.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (i == _posts.length) {
                        if (_cursor == null) return const SizedBox(height: RasqSpacing.md);
                        return Padding(
                          padding: const EdgeInsets.all(RasqSpacing.sm),
                          child: Center(child: _loading ? const RasqLoading() : TextButton(key: const ValueKey('postPicker.more'), onPressed: () => _load(reset: false), child: const Text('もっと読む'))),
                        );
                      }
                      return _PostImagesRow(post: _posts[i], onPick: (m) => widget.onPick((item: m, post: _posts[i])));
                    },
                  ),
      ),
    ]);
  }
}

/// 投稿 1 件: 作者 + 本文の頭 + 画像のサムネイル(押して選ぶ)。
class _PostImagesRow extends StatelessWidget {
  const _PostImagesRow({required this.post, required this.onPick});
  final Post post;
  final ValueChanged<MediaItem> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final images = pickableImagesOf(post);
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          RasqAvatar(imageUrl: post.author.avatarUrl, fallbackLabel: post.author.displayName, size: 24),
          const SizedBox(width: RasqSpacing.xs),
          Expanded(child: Text(post.author.displayName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
          RasqSnsPill(account: post.account),
        ]),
        if (post.body.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(post.contentWarning ?? post.body.trim(), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        const SizedBox(height: RasqSpacing.xs),
        Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
          for (final m in images)
            Tooltip(
              message: m.alt?.isNotEmpty == true ? m.alt! : (m.sensitive ? 'センシティブな画像(添付にも引き継ぎます)' : 'この画像を添付する'),
              child: InkWell(
                key: ValueKey('postPicker.image.${post.id}.${m.id}'),
                borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
                onTap: () => onPick(m),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: m.sensitive
                        // センシティブは中身を出さない(選べはする)。
                        ? Container(color: scheme.surfaceContainerHighest, alignment: Alignment.center, child: Icon(Icons.visibility_off_outlined, color: scheme.onSurfaceVariant))
                        : Image.network('${m.thumbnailUrl ?? m.url}', fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, _, _) => Container(color: scheme.surfaceContainerHighest, alignment: Alignment.center, child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant))),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}
