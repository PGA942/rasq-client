import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import 'orgate_client.dart';

/// サーバー情報 (D-345、Central S-043)。インスタンスのあるサービス(Misskey / Mastodon など nodeinfo を出すサーバー)だけ。
/// Central が nodeinfo + 各ソフトのメタ情報をまとめて 6 時間おぼえる。
@immutable
class RasqServerInfo {
  const RasqServerInfo({
    required this.host,
    this.software,
    this.version,
    this.name,
    this.description,
    this.iconUrl,
    this.bannerUrl,
    this.themeColor,
    this.users,
    this.posts,
    this.activeMonth,
    this.registrationOpen,
    this.languages = const [],
    this.maintainerName,
    this.tosUrl,
    this.stale = false,
  });

  final String host;
  final String? software;
  final String? version;
  final String? name;
  final String? description;
  final Uri? iconUrl;
  final Uri? bannerUrl;

  /// `#RRGGBB`(Misskey の themeColor など)。
  final String? themeColor;
  final int? users;
  final int? posts;
  final int? activeMonth;
  final bool? registrationOpen;
  final List<String> languages;
  final String? maintainerName;
  final Uri? tosUrl;

  /// 取り直せず、古い値を返したとき。
  final bool stale;

  String get displayName => (name?.trim().isNotEmpty ?? false) ? name!.trim() : host;

  factory RasqServerInfo.fromJson(Map<String, Object?> j) => RasqServerInfo(
        host: '${j['host']}',
        software: j['software'] as String?,
        version: j['version'] as String?,
        name: j['name'] as String?,
        description: j['description'] as String?,
        iconUrl: _httpUri(j['iconUrl']),
        bannerUrl: _httpUri(j['bannerUrl']),
        themeColor: j['themeColor'] as String?,
        users: (j['users'] as num?)?.toInt(),
        posts: (j['posts'] as num?)?.toInt(),
        activeMonth: (j['activeMonth'] as num?)?.toInt(),
        registrationOpen: j['registrationOpen'] as bool?,
        languages: [for (final l in j['languages'] as List? ?? const []) '$l'],
        maintainerName: ((j['maintainer'] as Map?)?['name'] as String?)?.trim().isEmpty ?? true ? null : (j['maintainer'] as Map)['name'] as String,
        tosUrl: _httpUri(j['tosUrl']),
        stale: j['stale'] == true,
      );
}

/// クラウド版 RAi によるユーザーの特性の解説 (S-043)。コミュニティの話が出てこないサーバーは [community] = false(欄を出さない)。
@immutable
class RaiServerProfile {
  const RaiServerProfile({required this.host, required this.community, this.summary, this.traits = const [], this.topics = const [], this.sampleCount = 0, this.model});
  final String host;
  final bool community;
  final String? summary;
  final List<String> traits;
  final List<String> topics;
  final int sampleCount;
  final String? model;

  /// タイルに出すか: コミュニティの話が出てきていて、解説があるときだけ。
  bool get showable => community && (summary?.trim().isNotEmpty ?? false);

  factory RaiServerProfile.fromJson(Map<String, Object?> j) => RaiServerProfile(
        host: '${j['host']}',
        community: j['community'] == true,
        summary: j['summary'] as String?,
        traits: [for (final t in j['traits'] as List? ?? const []) '$t'],
        topics: [for (final t in j['topics'] as List? ?? const []) '$t'],
        sampleCount: (j['sampleCount'] as num?)?.toInt() ?? 0,
        model: j['model'] as String?,
      );
}

/// サーバーの見本の投稿 (D-412、Central S-072): オンボーディングのサーバータイルの下に出す候補。Central がトークン無しで取れる
/// 公開の投稿(Misskey の注目 / ローカル TL、Mastodon のトレンド / ローカル TL)から、返信 / CW / センシティブ / ボットなどを落とし、
/// 強い順に 12 件まで。ジャンルの判定は端末 ([selectShowcasePosts])。
@immutable
class ServerShowcase {
  const ServerShowcase({required this.host, this.software, this.posts = const [], this.stale = false});
  final String host;
  final String? software;
  final List<ShowcaseCandidate> posts;
  final bool stale;

  factory ServerShowcase.fromJson(Map<String, Object?> j) {
    final host = '${j['host']}';
    final kind = SnsKind.values.asNameMap()['${j['software']}'] ?? SnsKind.other;
    return ServerShowcase(
      host: host,
      software: j['software'] as String?,
      stale: j['stale'] == true,
      posts: [
        for (final p in j['posts'] as List? ?? const [])
          if (p is Map && p['post'] is Map)
            ShowcaseCandidate(
              // 見本はどのアカウントのものでもない: 投稿の SNS / サーバーを仮の「見ているアカウント」にする(登録したら [resolvePostOn] で引き直す)。
              post: SnsWire.postFrom((p['post'] as Map).cast<String, Object?>(), account: AccountId(kind: _kindOf(p['post'] as Map, kind), instance: host, handle: '-')),
              score: (p['score'] as num?)?.toDouble() ?? 0,
              source: '${p['source'] ?? 'local'}',
            ),
      ],
    );
  }

  static SnsKind _kindOf(Map post, SnsKind fallback) => SnsKind.values.asNameMap()['${(post['author'] as Map?)?['kind']}'] ?? fallback;
}

/// 見本の投稿の候補 1 件(強さ = Central の [score])。
@immutable
class ShowcaseCandidate {
  const ShowcaseCandidate({required this.post, this.score = 0, this.source = 'local'});
  final Post post;
  final double score;

  /// `featured` / `trend` / `local`(RASQ リストのスナップショットは `list`)。
  final String source;
}

class ServerInfoApi {
  ServerInfoApi(this.client);
  final OrgateClient client;

  /// null = インスタンスではない / 分からない(`404`)。
  Future<RasqServerInfo?> info(String host) async {
    try {
      return RasqServerInfo.fromJson(await client.getJson('/servers/${Uri.encodeComponent(host)}/info'));
    } on OrgateException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  /// 見本の投稿(D-412)。null = インスタンスではない / 分からない(`404`)。
  Future<ServerShowcase?> showcase(String host) async {
    try {
      return ServerShowcase.fromJson(await client.getJson('/servers/${Uri.encodeComponent(host)}/showcase'));
    } on OrgateException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  /// null = クラウド版 RAi が使えない(`501`)/ インスタンスではない。
  Future<RaiServerProfile?> rai(String host) async {
    try {
      return RaiServerProfile.fromJson(await client.getJson('/servers/${Uri.encodeComponent(host)}/rai'));
    } on OrgateException catch (e) {
      if (e.code.code == '404' || e.code.code == '501' || e.code.code == '401') return null;
      rethrow;
    }
  }
}

final serverInfoApiProvider = Provider<ServerInfoApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  return client == null ? null : ServerInfoApi(client);
});

/// サーバー情報(失敗 / インスタンスでない = null。タイルは出さない)。
final serverInfoProvider = FutureProvider.family<RasqServerInfo?, String>((ref, host) async {
  final api = ref.watch(serverInfoApiProvider);
  if (api == null || host.isEmpty) return null;
  try {
    return await api.info(host.toLowerCase());
  } catch (e) {
    debugPrint('server info $host: $e');
    return null;
  }
});

/// 見本の投稿の候補(失敗 / インスタンスでない = null)。
final serverShowcaseProvider = FutureProvider.family<ServerShowcase?, String>((ref, host) async {
  final api = ref.watch(serverInfoApiProvider);
  if (api == null || host.isEmpty) return null;
  try {
    return await api.showcase(host.toLowerCase());
  } catch (e) {
    debugPrint('server showcase $host: $e');
    return null;
  }
});

/// クラウド版 RAi の解説(使えない / 失敗 = null)。
final serverRaiProvider = FutureProvider.family<RaiServerProfile?, String>((ref, host) async {
  final api = ref.watch(serverInfoApiProvider);
  if (api == null || host.isEmpty) return null;
  try {
    return await api.rai(host.toLowerCase());
  } catch (e) {
    debugPrint('server rai $host: $e');
    return null;
  }
});

/// 本文の中の「サーバーそのもの」へのリンク(`https://misskey.io` / `https://misskey.io/` / `/about`)。投稿やユーザーへのリンクは拾わない。
final _serverLink = RegExp(r'https://([A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+)(?:/|/about/?)?(?=$|[\s)\]」』、。,])'); // l10n-ignore

/// 本文に含まれる最初のサーバーのホスト([exclude] に当たるもの = Central 自身など、は飛ばす)。
String? serverHostLinkIn(String text, {Set<String> exclude = const {}}) {
  for (final m in _serverLink.allMatches(text)) {
    final host = m.group(1)!.toLowerCase();
    if (!exclude.contains(host)) return host;
  }
  return null;
}

Uri? _httpUri(Object? v) {
  if (v is! String) return null;
  final u = Uri.tryParse(v);
  return u != null && (u.scheme == 'http' || u.scheme == 'https') ? u : null;
}
