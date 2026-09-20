import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rasq_models/rasq_models.dart';

import 'orgate_client.dart';

/// RASQ アカウントページ (S-021) の口とモデル。

/// SNS アカウントのタイルを出すか。`auto` は、本人のアプリの判定([snsAutoVisible])に従う。
enum SnsTileVisibility {
  auto('auto', '自動'),
  show('show', '表示'),
  hide('hide', '非表示');

  const SnsTileVisibility(this.id, this.label);
  final String id;
  final String label;
  static SnsTileVisibility of(String? id) => values.firstWhere((v) => v.id == id, orElse: () => auto);
}

/// 自動の判定: **鍵アカウント**、または**直近の投稿の公開範囲がフォロワーのみに寄っている**(半分を超える)なら出さない。
/// 投稿が 1 つも無い / 公開範囲を持たない SNS は、出す。
bool snsAutoVisible({required bool isLocked, required Iterable<String?> recentVisibilities}) {
  if (isLocked) return false;
  const limited = {'followers', 'private', 'specified', 'direct', 'limited', 'mutuals_only', 'self'};
  final known = recentVisibilities.whereType<String>().toList();
  if (known.isEmpty) return true;
  return known.where(limited.contains).length * 2 <= known.length;
}

/// ページに出る SNS アカウントのタイル。
@immutable
class RasqSnsTile {
  const RasqSnsTile({required this.kind, required this.instance, required this.handle, this.displayName, this.avatarUrl, this.serverName, this.serverIconUrl, this.profileUrl});
  final String kind;
  final String instance;
  final String handle;
  final String? displayName;
  final Uri? avatarUrl;
  final String? serverName;
  final Uri? serverIconUrl;

  /// その SNS 上のプロフィール(タップの行き先)。
  final Uri? profileUrl;

  /// タイルの左に出す名前。
  String get label => (displayName ?? '').isEmpty ? handle : displayName!;

  /// サーバーの呼び名(無ければホスト)。
  String get serverLabel => (serverName ?? '').isEmpty ? instance : serverName!;

  factory RasqSnsTile.fromJson(Map<String, Object?> j) => RasqSnsTile(
        kind: j['kind'] as String? ?? '',
        instance: j['instance'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String?,
        avatarUrl: _http(j['avatarUrl']),
        serverName: j['serverName'] as String?,
        serverIconUrl: _http(j['serverIconUrl']),
        profileUrl: _http(j['profileUrl']),
      );
}

/// 自分のバンドルの 1 行(編集画面で、出す / 出さないを決める)。
@immutable
class RasqSnsLink {
  const RasqSnsLink({required this.accountKey, required this.tile, required this.visibility, required this.autoVisible, required this.visible});
  final String accountKey;
  final RasqSnsTile tile;
  final SnsTileVisibility visibility;
  final bool autoVisible;

  /// いま実際にページに出ているか。
  final bool visible;

  factory RasqSnsLink.fromJson(Map<String, Object?> j) => RasqSnsLink(
        accountKey: j['accountKey'] as String? ?? '',
        tile: RasqSnsTile.fromJson(j),
        visibility: SnsTileVisibility.of(j['visibility'] as String?),
        autoVisible: j['autoVisible'] != false,
        visible: j['visible'] != false,
      );
}

@immutable
class RasqPostImage {
  const RasqPostImage({required this.id, required this.url, this.width = 0, this.height = 0, this.sensitive = false, this.type = 'image'});
  final String id;

  /// image / video / audio (S-024)。
  final String type;

  /// ほかの SNS の投稿と同じ部品(メディアグリッド / 全画面表示)に渡す形。音声は「ファイル」として出る。
  MediaItem toMediaItem() => MediaItem(
        id: id,
        type: switch (type) { 'video' => MediaType.video, 'audio' => MediaType.file, _ => MediaType.image },
        url: url,
        sensitive: sensitive,
        fileName: type == 'audio' ? '音声' : null,
        width: width == 0 ? null : width,
        height: height == 0 ? null : height,
      );
  final Uri url;
  final int width;
  final int height;
  final bool sensitive;
}

/// 投票 (S-023)。
@immutable
class RasqPoll {
  const RasqPoll({required this.choices, this.multiple = false, this.expiresAt, this.expired = false});
  final List<({String text, int votes, bool voted})> choices;
  final bool multiple;
  final DateTime? expiresAt;
  final bool expired;

  static RasqPoll? fromJson(Object? j) => j is! Map
      ? null
      : RasqPoll(
          choices: [for (final c in j['choices'] as List? ?? const []) if (c is Map) (text: '${c['text'] ?? ''}', votes: (c['votes'] as num?)?.toInt() ?? 0, voted: c['voted'] == true)],
          multiple: j['multiple'] == true,
          expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''),
          expired: j['expired'] == true,
        );
}

/// RASQ に投稿するときの上限 (S-023)。SNS のコンポーザーと共通にしつつ、ここだけ違う。
const rasqPostMaxImages = 6;

/// 動画 / 音声 1 つの大きさ (S-024)。
const rasqPostMaxMediaBytes = 32 * 1024 * 1024;
const rasqPostMaxPollChoices = 6;
const rasqPostMaxChars = 1000;

/// 投稿の作者。
@immutable
class RasqPostAuthor {
  const RasqPostAuthor({required this.id, required this.handle, required this.displayName, this.avatarUrl});
  final String id;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;
  String get label => displayName.isEmpty ? handle : displayName;

  static RasqPostAuthor? fromJson(Object? j) => j is Map
      ? RasqPostAuthor(id: '${j['id'] ?? ''}', handle: '${j['handle'] ?? ''}', displayName: '${j['displayName'] ?? ''}', avatarUrl: _http(j['avatarUrl']))
      : null;
}

/// キュー(アセットパックの絵でのリアクション)を、絵ごとにまとめたもの (S-022)。
@immutable
class RasqQueueCount {
  const RasqQueueCount({required this.packId, required this.stickerId, required this.url, required this.count, this.mine = false, this.like = false});

  /// アセットパックの絵のとき。いいね([like])なら null。
  final String? packId;
  final String stickerId;

  /// いいね(パックを使わないキュー。S-023)。
  final bool like;

  /// 絵(Central がパックから取り出して配る。パックを入れていなくても見える)。いいねは null(❤ を描く)。
  final Uri? url;
  final int count;
  final bool mine;
}

/// [RasqAccountPost.toPost] が付けるインスタンス名。
const rasqPostInstance = 'rasq';

/// RASQ の投稿を SNS の投稿の形にしたものか(SNS のアクションは効かないので、出さない)。
bool isRasqPost(Post post) => post.account.kind == SnsKind.other && post.account.instance == rasqPostInstance;

/// RASQ アカウントとしての投稿。
@immutable
class RasqAccountPost {
  const RasqAccountPost({
    required this.id,
    required this.body,
    this.author,
    this.images = const [],
    this.createdAt,
    this.replyTo,
    this.isReply = false,
    this.replyCount = 0,
    this.rebroadCount = 0,
    this.rebroaded = false,
    this.queues = const [],
    this.rebroadedBy,
    this.rebroadId,
    this.isQuote = false,
    this.quote,
    this.quoteCount = 0,
    this.cw = '',
    this.visibility = 'public',
    this.reactionAcceptance,
    this.poll,
  });
  final String id;
  final String body;
  final RasqPostAuthor? author;
  final List<RasqPostImage> images;
  final DateTime? createdAt;

  /// 返信の元(消えていれば null で [isReply] だけ true)。
  final String? replyTo;
  final bool isReply;
  final int replyCount;
  final int rebroadCount;

  /// 自分がリブロードしているか。
  final bool rebroaded;
  final List<RasqQueueCount> queues;

  /// 一覧で、誰かのリブロードとして出ているとき。
  final RasqPostAuthor? rebroadedBy;

  /// そのリブロード 1 回の id(取り消すときに使う。S-024)。
  final String? rebroadId;

  /// 引用 (S-024): 引用として書かれたか / 元の投稿(消えた・見られないなら null)/ この投稿が引用された数。
  final bool isQuote;
  final RasqAccountPost? quote;
  final int quoteCount;

  /// RASQ の投稿を、SNS の投稿の形に(全画面表示 / 引用のコンポーザーなど、共通の部品に渡すため)。
  /// アカウントは `other / rasq`([isRasqPost] で見分ける)。
  Post toPost({Uri? central}) => Post(
        id: id,
        url: central == null ? null : permalink(central),
        account: AccountId(kind: SnsKind.other, instance: rasqPostInstance, handle: author?.handle ?? ''),
        author: UserSummary(id: 'rasq:${author?.id ?? ''}', account: AccountId(kind: SnsKind.other, instance: rasqPostInstance, handle: author?.handle ?? ''), displayName: author?.label ?? '', avatarUrl: author?.avatarUrl),
        createdAt: createdAt ?? DateTime.now(),
        body: body,
        contentWarning: cw.isEmpty ? null : cw,
        // 共有 FOW が「フォロワー限定は広げない」の判断に使う。
        visibility: visibility,
        media: [for (final i in images) i.toMediaItem()],
      );

  /// 注釈 (CW)。空 = なし。
  final String cw;

  /// public / home / followers。
  final String visibility;

  /// `likeOnly` = いいねのみ(キューの絵は受けない)。
  final String? reactionAcceptance;
  bool get likeOnly => reactionAcceptance == 'likeOnly';
  final RasqPoll? poll;

  /// 共有の行き先(Web の個別ページ)。
  Uri permalink(Uri central) => central.replace(path: '/p/$id', query: null);

  factory RasqAccountPost.fromJson(Map<String, Object?> j) => RasqAccountPost(
        id: j['id'] as String? ?? '',
        body: j['body'] as String? ?? '',
        author: RasqPostAuthor.fromJson(j['author']),
        images: [
          for (final i in j['images'] as List? ?? const [])
            if (i is Map && _http(i['url']) != null) RasqPostImage(id: '${i['id']}', url: _http(i['url'])!, width: (i['width'] as num?)?.toInt() ?? 0, height: (i['height'] as num?)?.toInt() ?? 0, sensitive: i['sensitive'] == true, type: i['type'] as String? ?? 'image'),
        ],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        cw: j['cw'] as String? ?? '',
        visibility: j['visibility'] as String? ?? 'public',
        reactionAcceptance: j['reactionAcceptance'] as String?,
        poll: RasqPoll.fromJson(j['poll']),
        replyTo: j['replyTo'] as String?,
        isReply: j['isReply'] == true,
        replyCount: (j['replyCount'] as num?)?.toInt() ?? 0,
        rebroadCount: (j['rebroadCount'] as num?)?.toInt() ?? 0,
        rebroaded: j['rebroaded'] == true,
        queues: [
          for (final q in j['queues'] as List? ?? const [])
            if (q is Map && (q['like'] == true || _http(q['url']) != null))
              RasqQueueCount(packId: q['packId'] as String?, stickerId: '${q['stickerId']}', url: _http(q['url']), like: q['like'] == true, count: (q['count'] as num?)?.toInt() ?? 0, mine: q['mine'] == true),
        ],
        rebroadedBy: RasqPostAuthor.fromJson(j['rebroadedBy']),
        rebroadId: j['rebroadId'] as String?,
        isQuote: j['isQuote'] == true,
        quote: j['quote'] is Map ? RasqAccountPost.fromJson((j['quote'] as Map).cast<String, Object?>()) : null,
        quoteCount: (j['quoteCount'] as num?)?.toInt() ?? 0,
      );
}

/// 投稿 1 つと、その前後(`GET /posts/{id}`)。
@immutable
class RasqThread {
  const RasqThread({required this.post, this.parent, this.replies = const []});
  final RasqAccountPost post;
  final RasqAccountPost? parent;
  final List<RasqAccountPost> replies;
}

@immutable
class RasqPostList {
  const RasqPostList({required this.posts, required this.limit, required this.source});
  final List<RasqAccountPost> posts;

  /// 持てる件数(第一期は 3)。
  final int limit;

  /// `rasq` = RASQ アカウントとしての投稿(SNS の投稿をまとめて出すのは後段)。
  final String source;
}

@immutable
class RasqPagePlugin {
  const RasqPagePlugin({required this.id, required this.name, this.summary = '', this.iconUrl, this.rating, this.reviewTitle = '', this.reviewBody = ''});
  final String id;
  final String name;
  final String summary;
  final Uri? iconUrl;

  /// レビューしたプラグインのとき、その評価(1〜5)と中身。
  final int? rating;
  final String reviewTitle;
  final String reviewBody;
}

/// 公開プロフィール(`GET /accounts/{handle}`)。
@immutable
class RasqPublicProfile {
  const RasqPublicProfile({
    required this.id,
    required this.handle,
    required this.displayName,
    this.avatarUrl,
    this.bannerUrl,
    this.bio = '',
    this.location = '',
    this.birthday = '',
    this.links = const [],
    this.createdAt,
    this.snsAccounts = const [],
    this.published = const [],
    this.reviewed = const [],
  });
  final String id;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;
  final Uri? bannerUrl;
  final String bio;
  final String location;
  final String birthday;
  final List<({String label, Uri url})> links;
  final DateTime? createdAt;
  final List<RasqSnsTile> snsAccounts;

  /// 開発者として公開しているプラグイン / レビューしたプラグイン。
  final List<RasqPagePlugin> published;
  final List<RasqPagePlugin> reviewed;

  factory RasqPublicProfile.fromJson(Map<String, Object?> j) => RasqPublicProfile(
        id: j['id'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        avatarUrl: _http(j['avatarUrl']),
        bannerUrl: _http(j['bannerUrl']),
        bio: j['bio'] as String? ?? '',
        location: j['location'] as String? ?? '',
        birthday: j['birthday'] as String? ?? '',
        links: [
          for (final l in j['links'] as List? ?? const [])
            if (l is Map && _http(l['url']) != null) (label: '${l['label'] ?? ''}', url: _http(l['url'])!),
        ],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        snsAccounts: [for (final s in j['snsAccounts'] as List? ?? const []) if (s is Map) RasqSnsTile.fromJson(s.cast<String, Object?>())],
        published: [
          for (final p in j['plugins'] as List? ?? const [])
            if (p is Map) RasqPagePlugin(id: '${p['id']}', name: '${p['name'] ?? p['id']}', summary: '${p['summary'] ?? ''}', iconUrl: _http(p['iconUrl'])),
        ],
        reviewed: [
          for (final r in j['reviews'] as List? ?? const [])
            if (r is Map) RasqPagePlugin(id: '${r['pluginId']}', name: '${r['pluginName'] ?? r['pluginId']}', iconUrl: _http(r['pluginIconUrl']), rating: (r['rating'] as num?)?.toInt(), reviewTitle: '${r['title'] ?? ''}', reviewBody: '${r['body'] ?? ''}'),
        ],
      );
}

/// http(s) の URL だけ受ける(サーバーから来た値でも、リンク / 画像に使う前に確かめる)。
Uri? _http(Object? v) {
  if (v is! String || v.isEmpty) return null;
  final u = Uri.tryParse(v);
  return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty ? u : null;
}

class RasqAccountPageApi {
  RasqAccountPageApi(this._client);
  final OrgateClient _client;

  Future<RasqPublicProfile> profile(String handle) async => RasqPublicProfile.fromJson(await _client.getJson('/accounts/${Uri.encodeComponent(handle)}'));

  Future<RasqPostList> posts(String handle) async {
    final j = await _client.getJson('/accounts/${Uri.encodeComponent(handle)}/posts');
    return RasqPostList(
      posts: [for (final p in j['posts'] as List? ?? const []) if (p is Map) RasqAccountPost.fromJson(p.cast<String, Object?>())],
      limit: (j['limit'] as num?)?.toInt() ?? 3,
      source: j['source'] as String? ?? 'rasq',
    );
  }

  /// 画像を先に上げて、id を付けて投稿する。
  /// SNS の投稿と同じ項目 (S-023): 注釈 / 公開範囲 / いいねのみ / センシティブな画像 / 投票。連合に関わるものは無い。
  Future<RasqAccountPost> createPost(
    String body, {
    List<({List<int> bytes, String contentType, bool sensitive})> images = const [],
    String cw = '',
    String visibility = 'public',
    bool likeOnly = false,
    ({List<String> choices, bool multiple, Duration? expiresAfter})? poll,
    String? quoteOf,
  }) async {
    final ids = <String>[];
    final sensitive = <String>[];
    for (final i in images) {
      // 画像も動画 / 音声も同じ口(サーバーが中身で見分ける。S-024)。
      final id = '${(await _client.postBytes('/me/posts/media', i.bytes, contentType: i.contentType))['id']}';
      ids.add(id);
      if (i.sensitive) sensitive.add(id);
    }
    return RasqAccountPost.fromJson(await _client.postJson('/me/posts', {
      'body': body,
      if (ids.isNotEmpty) 'imageIds': ids,
      if (sensitive.isNotEmpty) 'sensitiveImageIds': sensitive,
      if (cw.isNotEmpty) 'cw': cw,
      if (visibility != 'public') 'visibility': visibility,
      if (likeOnly) 'reactionAcceptance': 'likeOnly',
      'quoteOf': ?quoteOf,
      if (poll != null) 'poll': {'choices': poll.choices, 'multiple': poll.multiple, if (poll.expiresAfter != null) 'expiresInSeconds': poll.expiresAfter!.inSeconds},
    }));
  }

  /// いいね(パックを使わないキュー)。
  Future<RasqAccountPost> like(String postId) async => RasqAccountPost.fromJson(await _client.putJson('/posts/$postId/queue', const {'like': true}));

  Future<RasqAccountPost> vote(String postId, int choice) async => RasqAccountPost.fromJson(await _client.postJson('/posts/$postId/poll/vote', {'choice': choice}));

  Future<void> deletePost(String id) => _client.delete('/me/posts/$id');

  // ── アクション (S-022) ──
  Future<RasqThread> thread(String id) async {
    final j = await _client.getJson('/posts/$id');
    RasqAccountPost? one(Object? v) => v is Map ? RasqAccountPost.fromJson(v.cast<String, Object?>()) : null;
    return RasqThread(post: one(j['post'])!, parent: one(j['parent']), replies: [for (final r in j['replies'] as List? ?? const []) if (one(r) != null) one(r)!]);
  }

  /// 返信(文字だけ、500 文字まで)。
  Future<RasqAccountPost> reply(String postId, String body) async => RasqAccountPost.fromJson(await _client.postJson('/me/posts', {'body': body, 'replyTo': postId}));

  /// リブロード (S-024): 押すたびに 1 回増える(同じ投稿を何度でも)。戻り = 更新後の投稿。
  Future<RasqAccountPost> rebroad(String postId) async => RasqAccountPost.fromJson(await _client.postJson('/posts/$postId/rebroad', const {}));

  /// リブロード 1 回を取り消す([RasqAccountPost.rebroadId])。
  Future<void> deleteRebroad(String rebroadId) => _client.delete('/rebroads/$rebroadId');

  /// キュー: アセットパックの絵でリアクション(そのパックをインストールしていること)。null で外す。
  Future<RasqAccountPost> setQueue(String postId, ({String packId, String stickerId})? sticker) async {
    if (sticker != null) return RasqAccountPost.fromJson(await _client.putJson('/posts/$postId/queue', {'packId': sticker.packId, 'stickerId': sticker.stickerId}));
    await _client.delete('/posts/$postId/queue');
    return (await thread(postId)).post;
  }

  Future<List<RasqSnsLink>> mySnsLinks() async => [for (final l in await _client.getList('/me/sns-accounts')) if (l is Map) RasqSnsLink.fromJson(l.cast<String, Object?>())];

  Future<RasqSnsLink> setSnsVisibility(String accountKey, SnsTileVisibility v) async =>
      RasqSnsLink.fromJson(await _client.patchJson('/me/sns-accounts/${Uri.encodeComponent(accountKey)}', {'visibility': v.id}));
}

final rasqAccountPageApiProvider = Provider<RasqAccountPageApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  return client == null ? null : RasqAccountPageApi(client);
});

/// ページ 1 枚ぶん(プロフィール + 投稿)。
final rasqAccountPageProvider = FutureProvider.autoDispose.family<({RasqPublicProfile profile, RasqPostList posts}), String>((ref, handle) async {
  final api = ref.watch(rasqAccountPageApiProvider);
  if (api == null) throw StateError('RASQ Central の接続先が未設定です');
  final (profile, posts) = await (api.profile(handle), api.posts(handle)).wait;
  return (profile: profile, posts: posts);
});

/// 投稿 1 つのスレッド。
final rasqThreadProvider = FutureProvider.autoDispose.family<RasqThread, String>((ref, id) async {
  final api = ref.watch(rasqAccountPageApiProvider);
  if (api == null) throw StateError('RASQ Central の接続先が未設定です');
  return api.thread(id);
});
