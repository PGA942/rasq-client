import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import 'orgate_client.dart';
import 'rasq_collections_api.dart';

/// 初回オンボーディング v2 (D-414) の Central の口(`/api/v1/onboarding/...`、匿名で呼べる)。
/// 形は `CONTRACT.md`(2026-10-03 の取り決め)のとおり。Central の外部サービスが未設定なら `mode: "dummy"` の見本が返る。

String? _s(Object? v) => v == null ? null : '$v';
List<Map<String, Object?>> _maps(Object? v) => [for (final e in v as List? ?? const []) if (e is Map) e.cast<String, Object?>()];

/// 左カラムの投稿 1 件(公開 RASQ リストの有力な投稿、§1)。
@immutable
class OnboardingFeedItem {
  const OnboardingFeedItem({required this.post, required this.listId, required this.listName, this.ownerHandle, this.score = 0});
  final Post post;
  final String listId;
  final String listName;
  final String? ownerHandle;
  final double score;

  factory OnboardingFeedItem.fromJson(Map<String, Object?> j) {
    final wire = (j['post'] as Map? ?? const {}).cast<String, Object?>();
    final author = (wire['author'] as Map?)?.cast<String, Object?>() ?? const {};
    final list = (j['list'] as Map? ?? const {}).cast<String, Object?>();
    // 見本はどのアカウントのものでもない: 投稿の SNS / サーバーを仮の「見ているアカウント」にする(サーバーのタイルの見本と同じ)。
    final viewer = AccountId(kind: SnsKind.values.asNameMap()['${author['kind']}'] ?? SnsKind.other, instance: _s(author['instance']) ?? '-', handle: '-');
    return OnboardingFeedItem(
      post: SnsWire.postFrom(wire, account: viewer),
      listId: _s(list['id']) ?? '',
      listName: _s(list['name']) ?? '',
      ownerHandle: _s(list['ownerHandle']),
      score: (j['score'] as num?)?.toDouble() ?? 0,
    );
  }
}

@immutable
class OnboardingFeed {
  const OnboardingFeed({this.items = const [], this.stale = false});
  final List<OnboardingFeedItem> items;
  final bool stale;

  factory OnboardingFeed.fromJson(Map<String, Object?> j) => OnboardingFeed(
        items: [
          for (final p in _maps(j['posts']))
            if (p['post'] is Map) OnboardingFeedItem.fromJson(p),
        ],
        stale: j['stale'] == true,
      );
}

/// 公開 RASQ リストの検索結果 (§4 `ListHit`)。
@immutable
class ListHit {
  const ListHit({required this.id, required this.name, this.description = '', this.ownerHandle = '', this.memberCount = 0, this.sampleHosts = const [], this.score = 0, this.reason = ''});
  final String id;
  final String name;
  final String description;
  final String ownerHandle;
  final int memberCount;
  final List<String> sampleHosts;
  final double score;
  final String reason;

  factory ListHit.fromJson(Map<String, Object?> j) => ListHit(
        id: _s(j['id']) ?? '',
        name: _s(j['name']) ?? '',
        description: _s(j['description']) ?? '',
        ownerHandle: _s(j['ownerHandle']) ?? '',
        memberCount: (j['memberCount'] as num?)?.toInt() ?? 0,
        sampleHosts: [for (final h in j['sampleHosts'] as List? ?? const []) '$h'],
        score: (j['score'] as num?)?.toDouble() ?? 0,
        reason: _s(j['reason']) ?? '',
      );

  /// リストの画面 / 取り込み (D-347) に渡す形(公開のリスト。中身は開いたときに Central から読む)。
  RasqCollection toCollection() => RasqCollection(
        id: id,
        kind: RasqCollectionKind.list,
        name: name,
        description: description.isEmpty ? null : description,
        isPublic: true,
        owner: RasqCollectionOwner(id: '', handle: ownerHandle, displayName: ownerHandle),
        itemCount: memberCount,
        instances: sampleHosts,
        canFetchChecked: false,
      );
}

/// サーバーの候補 (§4 `ServerHit`)。
@immutable
class ServerHit {
  const ServerHit({required this.host, this.kind = '', this.name = '', this.reason = ''});
  final String host;

  /// `misskey` / `mastodon` / … (Central の系統の見分け)。
  final String kind;
  final String name;
  final String reason;

  factory ServerHit.fromJson(Map<String, Object?> j) => ServerHit(host: _s(j['host']) ?? '', kind: _s(j['kind']) ?? '', name: _s(j['name']) ?? '', reason: _s(j['reason']) ?? '');
}

/// 画像の中の切り抜くべき部分。値は Central が返したまま(0〜1 の割合なら割合、それより大きければ画素)。
@immutable
class DiscoverCrop {
  const DiscoverCrop({required this.x, required this.y, required this.w, required this.h, this.label = '', this.frame});
  final double x, y, w, h;
  final String label;

  /// どのコマの切り抜きか(`frames` で送ったときの 0 始まりの番号、CONTRACT §2 の追記)。単一の `image` なら 0 か null。
  final int? frame;

  /// 割合で表しているか(すべて 0〜1)。
  bool get fractional => x <= 1 && y <= 1 && w <= 1 && h <= 1;

  factory DiscoverCrop.fromJson(Map<String, Object?> j) => DiscoverCrop(
        x: (j['x'] as num?)?.toDouble() ?? 0,
        y: (j['y'] as num?)?.toDouble() ?? 0,
        w: (j['w'] as num?)?.toDouble() ?? 0,
        h: (j['h'] as num?)?.toDouble() ?? 0,
        label: _s(j['label']) ?? '',
        frame: (j['frame'] as num?)?.toInt(),
      );
}

/// 探す言葉(§2 `query`)。
@immutable
class DiscoverQuery {
  const DiscoverQuery({this.text = '', this.keywords = const [], this.crops = const []});
  final String text;
  final List<String> keywords;
  final List<DiscoverCrop> crops;

  factory DiscoverQuery.fromJson(Map<String, Object?> j) => DiscoverQuery(
        text: _s(j['text']) ?? '',
        keywords: [for (final k in j['keywords'] as List? ?? const []) '$k'],
        crops: [for (final c in _maps(j['crops'])) DiscoverCrop.fromJson(c)],
      );
}

/// 探した結果の共通の部分(リスト / サーバー / mode)。
@immutable
class DiscoverResult {
  const DiscoverResult({this.lists = const [], this.servers = const [], this.mode = ''});
  final List<ListHit> lists;
  final List<ServerHit> servers;
  final String mode;

  static List<ListHit> listsOf(Object? v) => [for (final m in _maps(v)) ListHit.fromJson(m)];
  static List<ServerHit> serversOf(Object? v) => [for (final m in _maps(v)) ServerHit.fromJson(m)];

  /// 見つかった人(人から探す、RAi に聞くでリストに当たらなかったときの Brave、Central S-082)。
  List<PersonHit> get people => const [];

  bool get isEmpty => lists.isEmpty && servers.isEmpty && people.isEmpty;
}

/// §2 の結果。
@immutable
class ContentDiscoverResult extends DiscoverResult {
  const ContentDiscoverResult({required this.query, super.lists, super.servers, super.mode});
  final DiscoverQuery query;

  factory ContentDiscoverResult.fromJson(Map<String, Object?> j) => ContentDiscoverResult(
        query: DiscoverQuery.fromJson((j['query'] as Map? ?? const {}).cast<String, Object?>()),
        lists: DiscoverResult.listsOf(j['lists']),
        servers: DiscoverResult.serversOf(j['servers']),
        mode: _s(j['mode']) ?? '',
      );
}

/// §3 の人 1 人。
@immutable
class PersonHit {
  const PersonHit({required this.name, this.kind = 'unknown', this.handle = '', this.host = '', this.profileUrl, this.snippet = '', this.lists = const []});
  final String name;

  /// `mastodon` / `misskey` / `bluesky` / `unknown`。
  final String kind;
  final String handle;
  final String host;
  final Uri? profileUrl;
  final String snippet;
  final List<ListHit> lists;

  /// `handle@host`(どちらかが無ければある方)。
  String get address {
    final h = handle.startsWith('@') ? handle.substring(1) : handle;
    if (h.isEmpty) return host;
    return host.isEmpty || h.contains('@') ? '@$h' : '@$h@$host';
  }

  factory PersonHit.fromJson(Map<String, Object?> j) {
    final url = Uri.tryParse(_s(j['profileUrl']) ?? '');
    return PersonHit(
      name: _s(j['name']) ?? '',
      kind: _s(j['kind']) ?? 'unknown',
      handle: _s(j['handle']) ?? '',
      host: _s(j['host']) ?? '',
      profileUrl: url != null && (url.scheme == 'https' || url.scheme == 'http') ? url : null,
      snippet: _s(j['snippet']) ?? '',
      lists: DiscoverResult.listsOf(j['lists']),
    );
  }
}

/// §3 の結果。[source] = どこで見つけたか(`lists` / `brave` / `none`、3 の追記)。
@immutable
class PeopleDiscoverResult extends DiscoverResult {
  const PeopleDiscoverResult({this.people = const [], this.source = 'lists', super.lists, super.servers, super.mode});
  @override
  final List<PersonHit> people;
  final String source;

  /// RASQ リストに無く(Brave も使わず)、何も見つからなかった。
  bool get notFound => source == 'none' || (people.isEmpty && lists.isEmpty);

  factory PeopleDiscoverResult.fromJson(Map<String, Object?> j) => PeopleDiscoverResult(
        people: [for (final m in _maps(j['people'])) PersonHit.fromJson(m)],
        source: _s(j['source']) ?? 'lists',
        lists: DiscoverResult.listsOf(j['lists']),
        servers: DiscoverResult.serversOf(j['servers']),
        mode: _s(j['mode']) ?? '',
      );
}

/// §5 の結果。
@immutable
class AskDiscoverResult extends DiscoverResult {
  const AskDiscoverResult({required this.answer, this.people = const [], super.lists, super.servers, super.mode});
  final String answer;

  /// リストに当たらなかったとき、Brave で見つけた SNS の人 (D-432、Central S-082)。
  @override
  final List<PersonHit> people;

  factory AskDiscoverResult.fromJson(Map<String, Object?> j) => AskDiscoverResult(
        answer: _s(j['answer']) ?? '',
        people: [for (final m in _maps(j['people'])) PersonHit.fromJson(m)],
        lists: DiscoverResult.listsOf(j['lists']),
        servers: DiscoverResult.serversOf(j['servers']),
        mode: _s(j['mode']) ?? '',
      );
}

/// RAi との会話の 1 行(§5 `messages`)。
@immutable
class DiscoverChatMessage {
  const DiscoverChatMessage({required this.fromUser, required this.text});
  final bool fromUser;
  final String text;
  Map<String, Object?> toJson() => {'role': fromUser ? 'user' : 'assistant', 'text': text};
}

/// 画像の上限 (§2: 10 MiB)・本文の上限 (4000 字)・人の検索の上限 (200 字)・会話 (最新 10 件、各 2000 字)。
const discoverImageMaxBytes = 10 * 1024 * 1024;

/// 画面の読み取りのコマ (§2 の追記、D-416): 6 枚まで、合計 24 MiB まで。
const discoverFramesMax = 6;
const discoverFramesMaxTotalBytes = 24 * 1024 * 1024;
const discoverTextMaxChars = 4000;
const discoverPeopleMaxChars = 200;
const discoverAskMaxMessages = 10;
const discoverAskMaxChars = 2000;

String _clip(String s, int max) => s.characters.length <= max ? s : s.characters.take(max).toString();

/// 画像の先頭のバイトから MIME(jpeg / png / webp だけ。ほかは null = 送らない)。
String? discoverImageMime(List<int> b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length >= 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) return 'image/webp';
  return null;
}

class OnboardingDiscoverApi {
  OnboardingDiscoverApi(this.client);
  final OrgateClient client;

  /// §1 `GET /onboarding/feed`。
  Future<OnboardingFeed> feed({int limit = 30}) async => OnboardingFeed.fromJson(await client.getJson('/onboarding/feed', {'limit': '$limit'}));

  /// §2 `POST /onboarding/discover/content`(multipart)。画像 / コマ / 本文 / URL の少なくとも 1 つ。
  /// [frames] は画面の読み取りのコマ(時刻順、§2 の追記: 6 枚・合計 24 MiB まで。[image] とは併用しない)。
  /// [source] は `screen` / `picker` / `browser`、[capturedAt] は読み取った時刻。
  Future<ContentDiscoverResult> content({List<int>? image, List<List<int>> frames = const [], String? source, DateTime? capturedAt, String? text, Uri? url}) async {
    final mime = image == null ? null : discoverImageMime(image);
    if (image != null && mime == null) throw ArgumentError('jpeg / png / webp の画像だけ送れます');
    if (image != null && image.length > discoverImageMaxBytes) throw ArgumentError('画像は 10 MiB までです');
    if (image != null && frames.isNotEmpty) throw ArgumentError('画像とコマは一緒に送れません');
    if (frames.length > discoverFramesMax) throw ArgumentError('コマは $discoverFramesMax 枚までです');
    final frameMimes = [for (final f in frames) discoverImageMime(f)];
    if (frameMimes.any((m) => m == null)) throw ArgumentError('jpeg / png / webp のコマだけ送れます');
    if (frames.any((f) => f.length > discoverImageMaxBytes)) throw ArgumentError('コマは 1 枚 10 MiB までです');
    if (frames.fold<int>(0, (n, f) => n + f.length) > discoverFramesMaxTotalBytes) throw ArgumentError('コマは合計 24 MiB までです');
    final t = text?.trim() ?? '';
    if (image == null && frames.isEmpty && t.isEmpty && url == null) throw ArgumentError('画像・本文・URL のどれかが要ります');
    return ContentDiscoverResult.fromJson(await client.postMultipart(
      '/onboarding/discover/content',
      fields: {
        if (t.isNotEmpty) 'text': _clip(t, discoverTextMaxChars),
        if (url != null) 'url': url.toString(),
        'source': ?source,
        if (capturedAt != null) 'capturedAt': capturedAt.toUtc().toIso8601String(),
      },
      files: {
        if (image != null) 'image': (bytes: image, contentType: mime!, filename: 'image.${mime.split('/').last}'),
      },
      repeated: [
        for (var i = 0; i < frames.length; i++) (field: 'frames', bytes: frames[i], contentType: frameMimes[i]!, filename: 'frame_$i.${frameMimes[i]!.split('/').last}'),
      ],
    ));
  }

  /// §3 `POST /onboarding/discover/people`。
  Future<PeopleDiscoverResult> people(String query) async =>
      PeopleDiscoverResult.fromJson(await client.postJson('/onboarding/discover/people', {'query': _clip(query.trim(), discoverPeopleMaxChars)}));

  /// §4 `GET /onboarding/discover/lists`。
  Future<List<ListHit>> lists(String q, {int limit = 20}) async => DiscoverResult.listsOf((await client.getJson('/onboarding/discover/lists', {'q': q, 'limit': '$limit'}))['lists']);

  /// §5 `POST /onboarding/discover/ask`(最新 10 件、各 2000 字まで)。
  Future<AskDiscoverResult> ask(List<DiscoverChatMessage> messages) async {
    final recent = messages.length <= discoverAskMaxMessages ? messages : messages.sublist(messages.length - discoverAskMaxMessages);
    return AskDiscoverResult.fromJson(await client.postJson('/onboarding/discover/ask', {
      'messages': [for (final m in recent) {'role': m.fromUser ? 'user' : 'assistant', 'text': _clip(m.text, discoverAskMaxChars)}],
    }));
  }
}

/// Central の接続先が無ければ null。
final onboardingDiscoverApiProvider = Provider<OnboardingDiscoverApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  return client == null ? null : OnboardingDiscoverApi(client);
});

/// 左カラムの流れ(取れなければ空)。
final onboardingFeedProvider = FutureProvider<OnboardingFeed>((ref) async {
  final api = ref.watch(onboardingDiscoverApiProvider);
  if (api == null) return const OnboardingFeed();
  try {
    return await api.feed();
  } catch (e) {
    debugPrint('onboarding feed: $e');
    return const OnboardingFeed();
  }
});
