import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import 'orgate_client.dart';

/// RASQ リスト / RASQ クリップ (D-343/D-344、Central S-042)。SNS を跨いだ人のリスト(`list`)と投稿の束(`clip`)。
/// 中身は Central が、資格のある人(作った人 / 条件に合うフォロワー)が見たときに、その人の AsTell のトークン
/// (S-027 で預けた SNS のトークン)で取り直す。アプリはスナップショットを読むだけ。
enum RasqCollectionKind {
  list('list', 'リスト'),
  clip('clip', 'クリップ');

  const RasqCollectionKind(this.wire, this.label);
  final String wire;
  final String label;
  static RasqCollectionKind fromWire(Object? w) => values.where((k) => k.wire == w).firstOrNull ?? list;
}

@immutable
class RasqCollectionOwner {
  const RasqCollectionOwner({required this.id, required this.handle, required this.displayName, this.avatarUrl});
  final String id;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;

  factory RasqCollectionOwner.fromJson(Map<String, Object?> j) => RasqCollectionOwner(
        id: '${j['id'] ?? ''}',
        handle: '${j['handle'] ?? ''}',
        displayName: '${j['displayName'] ?? j['handle'] ?? ''}',
        avatarUrl: _httpUri(j['avatarUrl']),
      );
}

/// 概要(`CollectionSummary`)。
@immutable
class RasqCollection {
  const RasqCollection({
    required this.id,
    required this.kind,
    required this.name,
    required this.owner,
    this.code,
    this.description,
    this.isPublic = false,
    this.itemCount = 0,
    this.followerCount = 0,
    this.instances = const [],
    this.refreshedAt,
    this.updatedAt,
    this.url,
    this.canFetch,
    this.canFetchChecked = true,
    this.following = false,
    this.isOwner = false,
  });

  final String id;
  final String? code;
  final RasqCollectionKind kind;
  final String name;
  final String? description;
  final bool isPublic;
  final RasqCollectionOwner owner;
  final int itemCount;
  final int followerCount;

  /// 項目が属するサーバー(サーバー情報タイル D-345 に使う)。
  final List<String> instances;
  final DateTime? refreshedAt;
  final DateTime? updatedAt;

  /// 共有 URL(`…/@handle/lists/<code>`)。投稿に貼るとタイルになる。
  final String? url;

  /// 見ている人が、リスト内の人の情報を取れるか (S-044)。null = 分からない(未ログイン / 古いサーバー)。
  /// タイムラインの取り込み元に選べるのは true のときだけ (D-346)。
  final bool? canFetch;

  /// 一覧では「入っている人をフォローしている」をネットワークで確かめない (S-044)。false = まだ確かめていない(詳細を開くと分かる)。
  final bool canFetchChecked;
  final bool following;
  final bool isOwner;

  /// 詳細で分かった、見ている人との関係を載せる。
  RasqCollection withViewer({required bool canFetch, required bool following, required bool isOwner}) => RasqCollection(
        id: id,
        code: code,
        kind: kind,
        name: name,
        description: description,
        isPublic: isPublic,
        owner: owner,
        itemCount: itemCount,
        followerCount: followerCount,
        instances: instances,
        refreshedAt: refreshedAt,
        updatedAt: updatedAt,
        url: url,
        canFetch: canFetch,
        following: following,
        isOwner: isOwner,
      );

  factory RasqCollection.fromJson(Map<String, Object?> j) => RasqCollection(
        id: '${j['id']}',
        code: j['code'] as String?,
        kind: RasqCollectionKind.fromWire(j['kind']),
        name: '${j['name'] ?? ''}',
        description: (j['description'] as String?)?.trim().isEmpty ?? true ? null : j['description'] as String,
        isPublic: j['visibility'] == 'public',
        owner: RasqCollectionOwner.fromJson((j['owner'] as Map? ?? const {}).cast<String, Object?>()),
        itemCount: (j['itemCount'] as num?)?.toInt() ?? 0,
        followerCount: (j['followerCount'] as num?)?.toInt() ?? 0,
        instances: [for (final h in j['instances'] as List? ?? const []) '$h'],
        refreshedAt: DateTime.tryParse('${j['refreshedAt']}'),
        updatedAt: DateTime.tryParse('${j['updatedAt']}'),
        url: _httpUri(j['url'])?.toString(),
        canFetch: (j['viewer'] as Map?)?['canFetch'] as bool?,
        canFetchChecked: (j['viewer'] as Map?)?['canFetchChecked'] != false,
        following: (j['viewer'] as Map?)?['following'] == true,
        isOwner: (j['viewer'] as Map?)?['isOwner'] == true,
      );
}

enum RasqItemState { ok, pending, gone }

/// 項目(`CollectionItem`)。リスト = 人、クリップ = 投稿。
@immutable
class RasqCollectionItem {
  const RasqCollectionItem({required this.key, required this.kind, required this.instance, required this.refId, this.handle, this.url, this.state = RasqItemState.ok, this.snapshot});
  final String key;
  final String kind;
  final String instance;
  final String refId;
  final String? handle;
  final String? url;
  final RasqItemState state;
  final Map<String, Object?>? snapshot;

  AccountId get account => AccountId(kind: SnsKind.values.asNameMap()[kind] ?? SnsKind.other, instance: instance, handle: handle ?? refId);

  /// リストのメンバー(スナップショットが無ければ最小限)。
  UserSummary get user {
    final s = snapshot;
    if (s == null) return UserSummary(id: refId, account: account, displayName: handle ?? refId);
    return SnsWire.userFrom({...s, 'kind': s['kind'] ?? kind, 'instance': s['instance'] ?? instance});
  }

  /// クリップの投稿(`gone` / 本文を見せない `pending` は null)。[viewer] = 見ている人の同じサーバーのアカウント(あれば操作できる)。
  Post? post({AccountId? viewer}) {
    final s = snapshot;
    if (s == null || state != RasqItemState.ok) return null;
    return SnsWire.postFrom(s, account: viewer ?? account);
  }

  factory RasqCollectionItem.fromJson(Map<String, Object?> j) => RasqCollectionItem(
        key: '${j['key']}',
        kind: '${j['kind'] ?? ''}',
        instance: '${j['instance'] ?? ''}',
        refId: '${j['refId'] ?? ''}',
        handle: j['handle'] as String?,
        url: j['url'] as String?,
        state: RasqItemState.values.asNameMap()['${j['state']}'] ?? RasqItemState.ok,
        snapshot: (j['snapshot'] as Map?)?.cast<String, Object?>(),
      );

  /// 送る形(`PUT …/items`)。
  Map<String, Object?> toJson() => {'kind': kind, 'instance': instance, 'refId': refId, 'handle': ?handle, 'url': ?url, 'snapshot': ?snapshot};

  /// リストに人を足すときの項目。[user] は**足したアカウントから見た**ユーザー(id はそのサーバーのもの)。
  factory RasqCollectionItem.member(UserSummary user, {required AccountId via}) {
    final remote = user.account.instance.isNotEmpty && user.account.instance != via.instance;
    return RasqCollectionItem(
      key: '${via.kind.name}:${via.instance}:${user.id}',
      kind: via.kind.name,
      instance: via.instance,
      refId: user.id,
      handle: remote ? '${user.account.handle}@${user.account.instance}' : user.account.handle,
      snapshot: SnsWire.user(user),
    );
  }
}

/// リストの投稿(Central のスナップショット)。
@immutable
class RasqCollectionPost {
  const RasqCollectionPost({required this.key, required this.memberKey, required this.wire, this.createdAt});
  final String key;
  final String memberKey;
  final Map<String, Object?> wire;
  final DateTime? createdAt;

  Post toPost(RasqCollectionItem? member, {AccountId? viewer}) {
    final parts = memberKey.split(':');
    final fallback = AccountId(kind: SnsKind.values.asNameMap()[parts.first] ?? SnsKind.other, instance: parts.length > 1 ? parts[1] : '-', handle: member?.handle ?? '-');
    return SnsWire.postFrom(wire, account: viewer ?? member?.account ?? fallback);
  }

  factory RasqCollectionPost.fromJson(Map<String, Object?> j) => RasqCollectionPost(
        key: '${j['key']}',
        memberKey: '${j['memberKey'] ?? ''}',
        wire: (j['post'] as Map? ?? const {}).cast<String, Object?>(),
        createdAt: DateTime.tryParse('${j['createdAt']}'),
      );
}

/// 詳細(`GET /rasq-collections/{idOrCode}`)。
@immutable
class RasqCollectionDetail {
  const RasqCollectionDetail({required this.collection, this.items = const [], this.posts = const [], this.isOwner = false, this.following = false, this.eligible = false, this.canFetch = false, this.refresh});
  final RasqCollection collection;
  final List<RasqCollectionItem> items;
  final List<RasqCollectionPost> posts;
  final bool isOwner;
  final bool following;

  /// 見たときに取り直せる人か(作った人 / 条件に合うフォロワー)。
  final bool eligible;

  /// リスト内の人の情報を取れるか (S-044)。タイムラインに取り込めるのは true のときだけ。
  final bool canFetch;

  /// `done` / `fresh` / `not_eligible` / `failed`。
  final String? refresh;

  RasqCollectionItem? memberOf(String key) => items.where((i) => i.key == key).firstOrNull;

  /// 概要 + 見ている人との関係。
  RasqCollection get summary => collection.withViewer(canFetch: canFetch, following: following, isOwner: isOwner);

  factory RasqCollectionDetail.fromJson(Map<String, Object?> j) {
    final viewer = (j['viewer'] as Map? ?? const {}).cast<String, Object?>();
    return RasqCollectionDetail(
      collection: RasqCollection.fromJson((j['collection'] as Map? ?? const {}).cast<String, Object?>()),
      items: [for (final i in j['items'] as List? ?? const []) if (i is Map) RasqCollectionItem.fromJson(i.cast<String, Object?>())],
      posts: [for (final p in j['posts'] as List? ?? const []) if (p is Map && p['post'] is Map) RasqCollectionPost.fromJson(p.cast<String, Object?>())],
      isOwner: viewer['isOwner'] == true,
      following: viewer['following'] == true,
      eligible: viewer['eligible'] == true,
      canFetch: viewer['canFetch'] == true || viewer['isOwner'] == true,
      refresh: j['refresh'] as String?,
    );
  }
}

class RasqCollectionsApi {
  RasqCollectionsApi(this.client);
  final OrgateClient client;

  Future<List<RasqCollection>> mine(RasqCollectionKind kind) async =>
      [for (final e in await client.getList('/me/rasq-collections', {'kind': kind.wire})) RasqCollection.fromJson((e as Map).cast<String, Object?>())];

  Future<List<RasqCollection>> following() async =>
      [for (final e in await client.getList('/me/rasq-collections/following')) RasqCollection.fromJson((e as Map).cast<String, Object?>())];

  Future<List<RasqCollection>> ofAccount(String handle, RasqCollectionKind kind) async => [
        for (final e in await client.getList('/accounts/${Uri.encodeComponent(handle)}/rasq-collections', {'kind': kind.wire}))
          RasqCollection.fromJson((e as Map).cast<String, Object?>()),
      ];

  Future<RasqCollection> create(RasqCollectionKind kind, String name, {String? description, bool? isPublic}) async => RasqCollection.fromJson(await client.postJson('/me/rasq-collections', {
        'kind': kind.wire,
        'name': name,
        'description': ?description,
        'visibility': ?(isPublic == null ? null : (isPublic ? 'public' : 'private')),
      }));

  Future<RasqCollection> update(String id, {String? name, String? description, bool? isPublic}) async => RasqCollection.fromJson(await client.patchJson('/me/rasq-collections/$id', {
        'name': ?name,
        'description': ?description,
        'visibility': ?(isPublic == null ? null : (isPublic ? 'public' : 'private')),
      }));

  Future<void> delete(String id) => client.delete('/me/rasq-collections/$id');

  /// 並びごと置き換える。
  Future<RasqCollectionDetail> putItems(String id, List<Map<String, Object?>> items) async =>
      RasqCollectionDetail.fromJson(await client.putJson('/me/rasq-collections/$id/items', {'items': items}));

  /// [refresh] = false: 取り直さずにスナップショットだけ(TL のタイル / 読んで書き換えるとき)。
  Future<RasqCollectionDetail> get(String idOrCode, {bool refresh = true}) async =>
      RasqCollectionDetail.fromJson(await client.getJson('/rasq-collections/${Uri.encodeComponent(idOrCode)}', {'refresh': refresh ? null : 'false'}));

  /// 公開コレクションを探す (S-044)。`q` は名前 / 説明 / `@handle` / 共有 URL・コード。空 = 人気。
  Future<List<RasqCollection>> search(String q, {RasqCollectionKind kind = RasqCollectionKind.list, int limit = 20}) async => [
        for (final e in await client.getList('/rasq-collections/search', {'q': q.trim(), 'kind': kind.wire, 'limit': '$limit'}))
          RasqCollection.fromJson((e as Map).cast<String, Object?>()),
      ];

  /// タイムライン用の投稿の列 (S-044)。`until` = 前のページの `next`。
  Future<RasqListTimelinePage> timeline(String idOrCode, {String? until, int limit = 40}) async =>
      RasqListTimelinePage.fromJson(await client.getJson('/rasq-collections/${Uri.encodeComponent(idOrCode)}/timeline', {'until': until, 'limit': '$limit'}));

  Future<RasqCollectionDetail> refresh(String idOrCode) async => RasqCollectionDetail.fromJson(await client.postJson('/rasq-collections/${Uri.encodeComponent(idOrCode)}/refresh', const {}));

  Future<void> follow(String id, {required bool on}) async {
    if (on) {
      await client.putJson('/rasq-collections/$id/follow', const {});
    } else {
      await client.delete('/rasq-collections/$id/follow');
    }
  }
}

/// リストのタイムラインの 1 ページ (S-044)。
@immutable
class RasqListTimelinePage {
  const RasqListTimelinePage({this.posts = const [], this.members = const [], this.next});
  final List<RasqCollectionPost> posts;
  final List<RasqCollectionItem> members;
  final String? next;

  RasqCollectionItem? memberOf(String key) => members.where((i) => i.key == key).firstOrNull;

  factory RasqListTimelinePage.fromJson(Map<String, Object?> j) => RasqListTimelinePage(
        posts: [for (final p in j['posts'] as List? ?? const []) if (p is Map && p['post'] is Map) RasqCollectionPost.fromJson(p.cast<String, Object?>())],
        members: [for (final i in j['members'] as List? ?? const []) if (i is Map) RasqCollectionItem.fromJson(i.cast<String, Object?>())],
        next: j['next'] as String?,
      );
}

final rasqCollectionsApiProvider = Provider<RasqCollectionsApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  return client == null ? null : RasqCollectionsApi(client);
});

/// 共有 URL(`https://…/@handle/lists/<code>` / `/clips/<code>`)。投稿の本文から拾う(タイル D-345)。
final _collectionLink = RegExp(r'https?://[^\s/]+/@[A-Za-z0-9_.-]{1,64}/(lists|clips)/([1-9A-HJ-NP-Za-km-z]{16,22}|[0-9a-fA-F-]{36})(?![/A-Za-z0-9])');

/// 本文に含まれる最初のコレクション(種類, id かコード)。
({RasqCollectionKind kind, String ref})? rasqCollectionLinkIn(String text) {
  final m = _collectionLink.firstMatch(text);
  if (m == null) return null;
  return (kind: m.group(1) == 'clips' ? RasqCollectionKind.clip : RasqCollectionKind.list, ref: m.group(2)!);
}

Uri? _httpUri(Object? v) {
  if (v is! String) return null;
  final u = Uri.tryParse(v);
  return u != null && (u.scheme == 'http' || u.scheme == 'https') ? u : null;
}
