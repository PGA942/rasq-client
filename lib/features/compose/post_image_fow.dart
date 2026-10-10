import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide Page;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../ads/export_ad.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/post_row.dart';
import '../search/search_history.dart';
import '../vc/astell_post_share.dart';
import '../media/audio_visualizer_video.dart' show audioVideoSupported;
import '../vc/astell_providers.dart';
import 'post_video.dart';

/// 「ノート画像の追加」FOW (D-258 → D-259): **投稿そのものを画像にして**、コンポーザーの添付にする。
///
/// 画像にするのは、タイムラインに出るのと同じ投稿タイル([PostRow])。投稿に付いている画像を抜き出すのではない。
///
/// 構成(上から、ワイヤー 2026-09-19):
/// - ヘッダー: キャンセル / ノート画像の追加 / **決定**(投稿を 1 つ選ぶと押せる)
/// - アカウントのアイコン + **絞り込みの欄**(いま出ている一覧を言葉で絞る。∨ は最近の検索から言葉を入れる)
/// - **タブ**: その SNS のタイムライン(ローカル / フォロー中 / グローバル …)/ 自分の投稿 / リアクション / ブックマーク /
///   AsTell(ルームで共有された投稿)/ **最近の検索**。選んでいるタブには ∨ が付き、もう一度押すと全部のタブのドロップダウン。
/// - 一覧: 投稿タイル(押して選ぶ)。「最近の検索」は履歴のタイル → 押すとその言葉で検索した結果になり、ほかのタブと同じく
///   上の欄で絞り込める。
///
/// **公開範囲が フォロワーのみ / 指名 / ダイレクト の投稿は出さない**([isPickablePost]): 限定公開の投稿を画像にして広めないため。
const postImageFowId = 'fow.composer.postImage';
const postImageFilterKey = Key('postImage.filter');
const postImageConfirmKey = Key('postImage.confirm');

/// 画像(PNG)か動画(mp4、D-260)にした投稿 1 つ。
/// [still] = 動画にしたとき (`video/mp4`) の、同じタイルの静止画(PNG)。加工画面が、置き場所を決めるオブジェクトに使う。
typedef PostImageResult = ({Uint8List bytes, String name, String mimeType, Post post, Uint8List? still});

/// 添付に使ってよい投稿か: 公開範囲が フォロワーのみ / 指名 / ダイレクト(プラグインごとの言い方を含む)でないこと。
/// 公開範囲を持たない SNS(null)は公開として扱う。
bool isPickablePost(Post p) {
  if (p.isDirect) return false;
  const limited = {'followers', 'private', 'specified', 'direct', 'limited', 'mutuals_only', 'self'};
  return !limited.contains(p.visibility);
}

/// 絞り込み: 本文 / 注釈 / 作者の名前・ハンドルに言葉が含まれるか(空白区切りは全部を含むこと。大文字小文字は見ない)。
bool postMatchesFilter(Post p, String filter) {
  final words = filter.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  if (words.isEmpty) return true;
  final hay = '${p.body}\n${p.contentWarning ?? ''}\n${p.author.displayName}\n${p.author.handle}'.toLowerCase();
  return words.every(hay.contains);
}

/// タブ 1 つ。
@immutable
class PostImageTab {
  const PostImageTab(this.id, this.label);
  final String id;
  final String label;

  static const mine = PostImageTab('mine', '自分の投稿');
  static const reacted = PostImageTab('reacted', 'リアクション');
  static const favorites = PostImageTab('favorites', 'ブックマーク');
  static const astell = PostImageTab('astell', 'AsTell');
  static const searches = PostImageTab('searches', '最近の検索');

  static List<PostImageTab> of(SnsSession session) => [for (final t in session.timelines) PostImageTab('tl:${t.id}', t.label), mine, reacted, favorites, astell, searches];
}

/// 貼る投稿の見た目 (D-262)。一覧もこの見た目で並ぶ(見えているものが、そのまま画像になる)。
enum PostTileStyle {
  /// スレッド展開時の本文(全文 + メディアを全部)。
  thread('thread', 'スレッド'),

  /// タイムラインでの表示(長い本文は畳む)。
  timeline('timeline', 'TL'),

  /// インライン表示(小アバター + 本文 3 行 + サムネイル)。一番小さい。
  inline('inline', 'インライン');

  const PostTileStyle(this.id, this.label);
  final String id;
  final String label;
  static PostTileStyle of(String? id) => values.firstWhere((v) => v.id == id, orElse: () => timeline);
}

/// 選んだ見た目の保存先。
const postTileStyleStorageKey = 'postImage.style.v1';

/// 1 ページぶん取りに行く。[search] があれば投稿検索(「最近の検索」のタイルから)。
Future<Page<Post>> fetchPostImagePage(SnsSession session, PostImageTab tab, {String? search, String? cursor}) async {
  const limit = 30;
  if (search != null) return session.searchPosts(search, cursor: cursor, limit: limit);
  switch (tab.id) {
    case 'mine':
      return session.userPosts((await session.me()).id, cursor: cursor, limit: limit);
    case 'reacted':
      return session.reactedPosts(cursor: cursor, limit: limit);
    case 'favorites':
      return session.favorites(cursor: cursor, limit: limit);
    default:
      final id = tab.id.startsWith('tl:') ? tab.id.substring(3) : tab.id;
      final kind = session.timelines.where((t) => t.id == id).firstOrNull ?? TimelineKind(id, tab.label);
      return session.timeline(kind, cursor: cursor, limit: limit);
  }
}

/// 描かれている投稿タイルを PNG に(`RepaintBoundary` をそのまま写す)。
Future<Uint8List?> capturePostTile(GlobalKey boundaryKey, {double pixelRatio = 3}) async {
  final box = boundaryKey.currentContext?.findRenderObject();
  if (box is! RenderRepaintBoundary) return null;
  final image = await box.toImage(pixelRatio: pixelRatio);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

/// [id] = FOW の id(加工画面から開くときは、加工画面が退避させない id を渡す)。[allowVideo] = 動く / 鳴る投稿を動画にできるか
/// (加工画面のオブジェクトは静止画だけ)。
/// [confirmVideo] = 動く / 鳴る投稿で「決定」を押したときに、動画にするかを呼び出し側で尋ねる(渡すと、FOW の中の切り替えは出ない)。
Future<PostImageResult?> showPostImageFow(WidgetRef ref, {String? ownerId, int column = 0, String id = postImageFowId, bool allowVideo = true, Future<bool> Function(PostMotion motion)? confirmVideo}) {
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains(id)) return Future.value();
  final canConfirm = ValueNotifier(false);
  final confirm = ValueNotifier<VoidCallback?>(null);
  return manager
      .showFow<PostImageResult>(
        id: id,
        ownerId: ownerId,
        spec: FowSpec(
          type: FowPanelType.widget,
          title: 'ノート画像の追加',
          cancelText: 'キャンセル',
          // 下書きの FOW と同じ高さ(コンポーザーは子の FOW の高さぶん避けるので、高すぎると閉じる瞬間にコンポーザーがはみ出す)。
          initialHeightFactor: 0.6,
          minHeightFactor: 0.3,
          maxHeightFactor: 0.92,
          maxWidth: 640,
          dockAboveFooter: true,
          columnIndex: column,
          // 決定は投稿を選ぶまで押せない。
          headerTrailing: ValueListenableBuilder<bool>(
            valueListenable: canConfirm,
            builder: (ctx, ok, _) => TextButton(key: postImageConfirmKey, onPressed: ok ? () => confirm.value?.call() : null, child: const Text('決定')),
          ),
        ),
        semanticsLabel: 'ノート画像の追加',
        builder: (_, _) => _Body(fowId: id, allowVideo: allowVideo && audioVideoSupported, confirmVideo: confirmVideo, canConfirm: canConfirm, confirm: confirm, onDone: (r) => manager.close(id, result: r)),
      )
      .whenComplete(() {
        canConfirm.dispose();
        confirm.dispose();
      });
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.fowId, required this.allowVideo, this.confirmVideo, required this.canConfirm, required this.confirm, required this.onDone});
  final String fowId;
  final bool allowVideo;
  final Future<bool> Function(PostMotion motion)? confirmVideo;
  final ValueNotifier<bool> canConfirm;
  final ValueNotifier<VoidCallback?> confirm;
  final ValueChanged<PostImageResult> onDone;
  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  final _filter = TextEditingController();
  final _tabScroll = ScrollController();
  PostImageTab? _tab;

  /// 「最近の検索」で選んだ言葉(null = 履歴の一覧を出している)。
  String? _search;

  List<Post> _posts = const [];
  int _excluded = 0;
  String? _cursor;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  Post? _selected;
  final Map<String, GlobalKey> _tileKeys = {};
  bool _capturing = false;
  String? _notice;

  /// 動く / 鳴る投稿を動画にするか (D-260)。選んだ投稿が対象のときだけ出るスイッチ。
  bool _asVideo = true;

  /// 投稿の見た目 (D-262、前回の選択を覚える)。
  PostTileStyle _style = PostTileStyle.timeline;
  double? _videoProgress;

  @override
  void initState() {
    super.initState();
    widget.confirm.value = _confirm;
    _loadStyle();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  @override
  void dispose() {
    _filter.dispose();
    _tabScroll.dispose();
    super.dispose();
  }

  Future<void> _loadStyle() async {
    try {
      final v = await ref.read(sessionStorageProvider).read(postTileStyleStorageKey);
      if (mounted && v != null) setState(() => _style = PostTileStyle.of(v));
    } catch (_) {}
  }

  Future<void> _setStyle(PostTileStyle v) async {
    setState(() => _style = v);
    try {
      await ref.read(sessionStorageProvider).write(postTileStyleStorageKey, v.id);
    } catch (_) {}
  }

  SnsSession? get _session => ref.read(currentSnsSessionProvider);
  bool get _showingHistory => _tab?.id == PostImageTab.searches.id && _search == null;

  void _select(Post? p) {
    setState(() {
      _selected = p;
      _notice = null;
    });
    widget.canConfirm.value = p != null;
  }

  Future<void> _reload() => _load(reset: true);

  Future<void> _load({required bool reset}) async {
    final session = _session;
    if (session == null) return setState(() => _error = 'アカウントがありません');
    final tab = _tab ??= PostImageTab.of(session).first;
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _posts = const [];
        _excluded = 0;
        _cursor = null;
        _tileKeys.clear();
      }
    });
    if (reset) _select(null);
    if (_showingHistory) {
      await ref.read(searchHistoryProvider.notifier).ready;
      if (mounted && gen == _generation) setState(() => _loading = false);
      return;
    }
    try {
      final page = tab.id == PostImageTab.astell.id ? await _astellPosts() : await fetchPostImagePage(session, tab, search: _search, cursor: reset ? null : _cursor);
      if (!mounted || gen != _generation) return;
      final ok = [for (final p in page.items) if (isPickablePost(p)) p];
      // チャイルドセーフ (D-454、セキュリティ確認 2026-10-09 の [9]): ホームと同じ保護者の表示制限を掛ける(見せない投稿は
      // 選べない・描かない。公開範囲で外した数には数えない)。
      final shown = ref.read(childGateProvider).filterPosts(ok);
      setState(() {
        final seen = {for (final p in _posts) p.key};
        _posts = [..._posts, for (final p in shown) if (seen.add(p.key)) p];
        _excluded += page.items.length - ok.length;
        _cursor = page.hasMore ? page.nextCursor : null;
        _loading = false;
      });
    } on UnsupportedError {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = _search != null ? 'この SNS では投稿の検索が使えません' : 'この SNS では「${tab.label}」が使えません';
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = '取得できませんでした: $e';
      });
    }
  }

  /// AsTell: 参加 / フォロー中のルームで共有された投稿(自分のアカウントで開けるものだけ)。
  Future<Page<Post>> _astellPosts() async {
    final client = ref.read(astellClientProvider);
    final sessions = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    final home = await client.home();
    final rooms = {for (final r in [...home.following, ...home.invited, ...home.recommended]) r.id: r}.values.take(8);
    final out = <Post>[];
    for (final room in rooms) {
      try {
        for (final s in await client.shares(room.id)) {
          if (s.kind != 'post') continue;
          final acct = astellAccountForPost(s.payload, sessions, prefer: ref.read(currentAccountProvider));
          final post = acct == null ? null : postFromSharePayload(s.payload, acct);
          if (post != null) out.add(post);
        }
      } catch (_) {}
    }
    return Page(items: out);
  }

  Future<void> _switchTab(PostImageTab tab) async {
    _tab = tab;
    _search = null;
    await _reload();
  }

  /// 選んでいるタブをもう一度押す: 全部のタブのドロップダウン(横に流れて見えないタブへも行ける)。
  Future<void> _tabMenu(BuildContext ctx) async {
    final session = _session;
    if (session == null) return;
    final box = ctx.findRenderObject() as RenderBox;
    final picked = await ref.read(overlayManagerProvider).showDropdown<PostImageTab>(
          id: 'postImage.tab.menu',
          ownerId: widget.fowId,
          anchor: box.localToGlobal(Offset.zero) & box.size,
          dense: true,
          items: [for (final t in PostImageTab.of(session)) RasqDropdownItem(t.label, t, checked: t.id == _tab?.id)],
        );
    if (picked != null && mounted) await _switchTab(picked);
  }

  /// 絞り込みの欄の ∨: 最近の検索の言葉を入れる。
  Future<void> _filterMenu(BuildContext ctx) async {
    await ref.read(searchHistoryProvider.notifier).ready;
    final history = ref.read(searchHistoryProvider);
    if (history.isEmpty || !ctx.mounted) return;
    final box = ctx.findRenderObject() as RenderBox;
    final picked = await ref.read(overlayManagerProvider).showDropdown<String>(
          id: 'postImage.filter.menu',
          ownerId: widget.fowId,
          anchor: box.localToGlobal(Offset.zero) & box.size,
          dense: true,
          items: [for (final e in history.take(8)) RasqDropdownItem(e.query, e.query)],
        );
    if (picked == null || !mounted) return;
    _filter.text = picked;
    setState(() {});
  }

  Future<void> _confirm() async {
    final post = _selected;
    final key = post == null ? null : _tileKeys[post.key];
    if (post == null || key == null || _capturing) return;
    setState(() => _capturing = true);
    final name = 'post-${post.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}';
    try {
      var motion = widget.allowVideo ? postMotionOf(post) : PostMotion.none;
      if (motion != PostMotion.none) {
        final ask = widget.confirmVideo;
        final yes = ask == null ? _asVideo : await ask(motion);
        if (!mounted) return;
        if (!yes) motion = PostMotion.none;
      }
      if (motion != PostMotion.none) {
        final still = await capturePostTile(key);
        if (!mounted) return;
        setState(() => _videoProgress = 0);
        final video = await buildPostVideo(
          post: post,
          motion: motion,
          boundaryKey: key,
          workDir: Directory.systemTemp,
          cancelled: () => !mounted,
          onProgress: (p) {
            if (mounted) setState(() => _videoProgress = p);
          },
        );
        final bytes = await video.readAsBytes();
        try {
          await video.delete();
        } catch (_) {}
        if (mounted) widget.onDone((bytes: bytes, name: '$name.mp4', mimeType: 'video/mp4', post: post, still: still));
        return;
      }
      final bytes = await capturePostTile(key);
      if (!mounted) return;
      // 選んだあとで遠くまでスクロールすると、タイルが画面に無くて写せない(一覧は見えるところだけ作る)。
      if (bytes == null) return setState(() => _notice = '選んだ投稿が画面に出ている状態で、もう一度「決定」を押してください');
      widget.onDone((bytes: bytes, name: '$name.png', mimeType: 'image/png', post: post, still: null));
    } catch (e) {
      if (mounted) setState(() => _notice = '動画にできませんでした: $e');
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
          _videoProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(currentSnsSessionProvider);
    final me = ref.watch(currentUserProvider);
    final tabs = session == null ? const <PostImageTab>[] : PostImageTab.of(session);
    final shown = [for (final p in _posts) if (postMatchesFilter(p, _filter.text)) p];
    // 絞り込みで見えなくなった投稿は選択から外す。
    if (_selected != null && !shown.any((p) => p.key == _selected!.key)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _select(null);
      });
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // 上の欄は、FOW を低くしたときにはみ出さないよう、入りきらなければ中で送れる。
      Flexible(flex: 0, fit: FlexFit.loose, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      // ── アカウント + 絞り込みの欄 ──
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
        child: Row(children: [
          RasqAvatar(imageUrl: me.avatarUrl, fallbackLabel: me.displayName, size: 36),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(
            child: RasqInput(
              key: postImageFilterKey,
              controller: _filter,
              hintText: _showingHistory ? '検索の履歴を絞り込む' : '一覧を絞り込む',
              prefix: Builder(builder: (ctx) => RasqIconButton(key: const ValueKey('postImage.filter.menu'), icon: Icons.keyboard_arrow_down, size: 20, tooltip: '最近の検索から入れる', onPressed: () => _filterMenu(ctx))),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ]),
      ),
      // ── タブ ──
      // タブは数が少ないので全部作る(見えていないタブも、テストやアクセシビリティから辿れる)。
      SizedBox(
        height: 40,
        child: SingleChildScrollView(controller: _tabScroll, scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm), child: Row(children: [
          for (final t in tabs)
            Builder(builder: (ctx) {
              final on = t.id == _tab?.id;
              return InkWell(
                key: ValueKey('postImage.tab.${t.id}'),
                borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
                onTap: () => on ? _tabMenu(ctx) : _switchTab(t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (on) Icon(Icons.keyboard_arrow_down, size: 18, color: scheme.onSurface),
                    Text(t.label, style: RasqTypography.body.copyWith(fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: on ? scheme.onSurface : scheme.onSurfaceVariant)),
                  ]),
                ),
              );
            }),
        ])),
      ),
      const Divider(height: 1),
      // ── 見た目 (D-262) ──
      if (!_showingHistory)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            Text('見た目', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(width: RasqSpacing.sm),
            for (final v in PostTileStyle.values)
              Padding(
                padding: const EdgeInsets.only(right: RasqSpacing.xs),
                child: ChoiceChip(
                  key: ValueKey('postImage.style.${v.id}'),
                  label: Text(v.label),
                  selected: _style == v,
                  visualDensity: VisualDensity.compact,
                  onSelected: _capturing
                      ? null
                      : (_) {
                          _setStyle(v);
                        },
                ),
              ),
          ])),
        ),
      if (_search != null)
        RasqListTile(key: const ValueKey('postImage.search.back'), leading: const Icon(Icons.arrow_back), title: '「$_search」の検索結果', subtitle: '最近の検索に戻る', chevron: false, onTap: () => _switchTab(PostImageTab.searches)),
      if (_excluded > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
          child: Text('公開範囲を限った投稿 $_excluded 件は出していません。', key: const ValueKey('postImage.excluded'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
      // 動く / 鳴る投稿を選んだとき (D-260): 動画にするか、その瞬間の静止画にするか。
      if (widget.allowVideo && widget.confirmVideo == null && _selected != null && postMotionOf(_selected!) != PostMotion.none)
        RasqSwitchListTile(key: const ValueKey('postImage.asVideo'), title: postMotionLabel(postMotionOf(_selected!)), subtitle: 'オフ = その瞬間の静止画', value: _asVideo, enabled: !_capturing, onChanged: (v) => setState(() => _asVideo = v)),
      // 書き出しの進み具合と、その間だけの広告の枠 (D-327)。
      if (_videoProgress != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
          child: MediaExportProgress(progress: _videoProgress, label: '動画にしています…'),
        ),
      if (_notice != null) Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs), child: Text(_notice!, style: RasqTypography.caption.copyWith(color: scheme.error))),
      ]))),
      // ── 一覧 ──
      Expanded(child: _showingHistory ? _history(scheme) : _list(scheme, shown)),
    ]);
  }

  Widget _message(ColorScheme scheme, String text) => Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(text, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)));

  /// 「最近の検索」: 履歴のタイル(見出し = 言葉、右に いつ、下に 掛けていた絞り込み)。押すとその言葉の検索結果へ。
  Widget _history(ColorScheme scheme) {
    final words = _filter.text.trim().toLowerCase();
    final entries = [for (final e in ref.watch(searchHistoryProvider)) if (words.isEmpty || e.query.toLowerCase().contains(words) || e.chips.any((c) => c.toLowerCase().contains(words))) e];
    if (entries.isEmpty) return _message(scheme, words.isEmpty ? '最近の検索はありません(検索ホームで検索すると、ここに並びます)' : '当てはまる検索はありません');
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final e = entries[i];
        return InkWell(
          key: ValueKey('postImage.history.${e.query}'),
          onTap: () {
            _search = e.query;
            _filter.clear();
            _reload();
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.sm, RasqSpacing.md),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.query, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text(searchHistoryAgo(e.at), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                  ]),
                  if (e.chips.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(e.chips.join('  '), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ]),
          ),
        );
      },
    );
  }

  Widget _list(ColorScheme scheme, List<Post> shown) {
    if (_error != null) return _message(scheme, _error!);
    if (shown.isEmpty) return _loading ? const RasqLoading() : _message(scheme, _posts.isEmpty ? '投稿はありません' : '当てはまる投稿はありません(「もっと読む」で続きも探せます)');
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: RasqSpacing.lg),
      itemCount: shown.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        if (i == shown.length) {
          if (_cursor == null) return const SizedBox(height: RasqSpacing.md);
          return Padding(padding: const EdgeInsets.all(RasqSpacing.sm), child: Center(child: _loading ? const RasqLoading() : TextButton(key: const ValueKey('postImage.more'), onPressed: () => _load(reset: false), child: const Text('もっと読む'))));
        }
        final p = shown[i];
        final on = _selected?.key == p.key;
        return _PostTile(key: ValueKey('postImage.post.${p.id}'), post: p, style: _style, boundaryKey: _tileKeys.putIfAbsent(p.key, GlobalKey.new), selected: on, onTap: () => _select(on ? null : p));
      },
    );
  }
}

/// 投稿タイル(タイムラインと同じ [PostRow])。押すと選ぶだけ(中のリンクやボタンは効かせない)。
/// 画像にするのは [boundaryKey] の中(選択の枠は外側 = 写らない)。背景は不透明(透けた PNG にしない)。
class _PostTile extends StatelessWidget {
  const _PostTile({super.key, required this.post, required this.style, required this.boundaryKey, required this.selected, required this.onTap});
  final Post post;
  final PostTileStyle style;
  final GlobalKey boundaryKey;
  final bool selected;
  final VoidCallback onTap;

  static Future<void> _noop(ActionDescriptor action, {Map<String, Object?> args = const {}}) async {}

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        foregroundDecoration: BoxDecoration(border: Border.all(color: selected ? RasqColors.accent : Colors.transparent, width: 3)),
        child: AbsorbPointer(
          child: RepaintBoundary(
            key: boundaryKey,
            child: ColoredBox(
              color: scheme.surface,
              child: switch (style) {
                PostTileStyle.thread => PostRow(post: post, actions: const [], onAction: _noop, showReplyParent: false, compactQuote: true, showAllMedia: true),
                PostTileStyle.timeline => PostRow(post: post, actions: const [], onAction: _noop),
                PostTileStyle.inline => Padding(padding: const EdgeInsets.all(RasqSpacing.sm), child: InlinePostFrame(post: post, onTap: () {})),
              },
            ),
          ),
        ),
      ),
    );
  }
}
