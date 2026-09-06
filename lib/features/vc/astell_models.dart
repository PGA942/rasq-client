import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';

/// AsTell (VC) のワイヤ型 (D-139)。正本は `rasq-central/docs/API.md` §3。
/// クライアント側 `lib/features/vc/*` とサーバー `src/astell/mod.rs` で同じ形。

UserSummary _rasqUser({required String id, required String handle, required String displayName, Uri? avatarUrl, UserPresence presence = UserPresence.none}) => UserSummary(
      id: 'rasq:$id',
      account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: handle),
      displayName: displayName.isEmpty ? handle : displayName,
      avatarUrl: avatarUrl,
      presence: presence,
    );

Uri? _uri(Object? v) => v is String && v.isNotEmpty ? Uri.tryParse(v) : null;
DateTime _date(Object? v) => DateTime.tryParse(v as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

/// ルーム(= VC タイル 1 枚)。
@immutable
class AstellRoom {
  const AstellRoom({
    required this.id,
    required this.ownerId,
    required this.ownerHandle,
    required this.ownerDisplayName,
    this.ownerAvatarUrl,
    required this.title,
    this.description = '',
    this.genres = const [],
    this.visibility = 'public',
    this.welcomeMessage,
    this.showSummary = true,
    this.autoGenre = true,
    required this.createdAt,
    this.closedAt,
    this.peerCount = 0,
    this.live = false,
    this.thumbnailUrl,
    this.hostStream,
  });

  final String id;
  final String ownerId;
  final String ownerHandle;
  final String ownerDisplayName;
  final Uri? ownerAvatarUrl;
  final String title;

  /// ざっくり要約(端末側の mT5 が生成してホストが `PATCH` で書く)。
  final String description;

  /// ジャンル(最大 10。ホスト端末の自動選択 or 手動)。
  final List<String> genres;
  final String visibility;
  final String? welcomeMessage;

  /// プレビューにざっくり要約を表示する(偽なら文字起こしも行われない)。
  final bool showSummary;
  final bool autoGenre;
  final DateTime createdAt;
  final DateTime? closedAt;

  /// 接続中のピア数。
  final int peerCount;

  /// 直近にメディア共有あり(タイルの LIVE バッジ)。
  final bool live;

  /// LIVE タイルのサムネイル(共有メディア。モック/将来のサーバー拡張)。
  final Uri? thumbnailUrl;

  /// ホストの配信(動画 / 画面)。null = 配信なし。
  final AstellHostStream? hostStream;

  bool get isOpen => closedAt == null;

  UserSummary get owner => _rasqUser(id: ownerId, handle: ownerHandle, displayName: ownerDisplayName, avatarUrl: ownerAvatarUrl);

  /// タイル/プレビューに出す要約文(ワイヤーフレームの空表示つき)。
  String get summaryText => description.isEmpty ? 'デスクリプションが提供されていません。' : description;

  factory AstellRoom.fromJson(Map<String, Object?> j) => AstellRoom(
        id: j['id'] as String? ?? '',
        ownerId: j['ownerId'] as String? ?? '',
        ownerHandle: j['ownerHandle'] as String? ?? '',
        ownerDisplayName: j['ownerDisplayName'] as String? ?? '',
        ownerAvatarUrl: _uri(j['ownerAvatarUrl']),
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        genres: [for (final g in (j['genres'] as List? ?? const [])) if (g is String) g],
        visibility: j['visibility'] as String? ?? 'public',
        welcomeMessage: j['welcomeMessage'] as String?,
        showSummary: j['showSummary'] != false,
        autoGenre: j['autoGenre'] != false,
        createdAt: _date(j['createdAt']),
        closedAt: j['closedAt'] is String ? DateTime.tryParse(j['closedAt'] as String) : null,
        peerCount: (j['peerCount'] as num?)?.toInt() ?? 0,
        live: j['live'] == true,
        thumbnailUrl: _uri(j['thumbnailUrl']) ?? (j['hostStream'] is Map ? _uri((j['hostStream'] as Map)['thumbnailUrl']) : null),
        hostStream: j['hostStream'] is Map ? AstellHostStream.fromJson((j['hostStream'] as Map).cast<String, Object?>()) : null,
      );

  AstellRoom copyWith({String? title, String? description, List<String>? genres, bool? showSummary, bool? autoGenre, int? peerCount, bool? live, AstellHostStream? hostStream, bool clearHostStream = false}) => AstellRoom(
        id: id,
        ownerId: ownerId,
        ownerHandle: ownerHandle,
        ownerDisplayName: ownerDisplayName,
        ownerAvatarUrl: ownerAvatarUrl,
        title: title ?? this.title,
        description: description ?? this.description,
        genres: genres ?? this.genres,
        visibility: visibility,
        welcomeMessage: welcomeMessage,
        showSummary: showSummary ?? this.showSummary,
        autoGenre: autoGenre ?? this.autoGenre,
        createdAt: createdAt,
        closedAt: closedAt,
        peerCount: peerCount ?? this.peerCount,
        live: live ?? this.live,
        thumbnailUrl: thumbnailUrl,
        hostStream: clearHostStream ? null : (hostStream ?? this.hostStream),
      );
}

/// ホストの配信状態 (D-145): `{kind: video|screen, title, thumbnailUrl, startedAt}`。
@immutable
class AstellHostStream {
  const AstellHostStream({required this.kind, this.title = '', this.thumbnailUrl, this.startedAt});
  final String kind;
  final String title;
  final Uri? thumbnailUrl;
  final DateTime? startedAt;
  bool get isScreen => kind == 'screen';

  factory AstellHostStream.fromJson(Map<String, Object?> j) => AstellHostStream(
        kind: j['kind'] as String? ?? 'video',
        title: j['title'] as String? ?? '',
        thumbnailUrl: _uri(j['thumbnailUrl']),
        startedAt: j['startedAt'] is String ? DateTime.tryParse(j['startedAt'] as String) : null,
      );

  Map<String, Object?> toJson() => {'kind': kind, 'title': title, 'thumbnailUrl': thumbnailUrl?.toString(), 'startedAt': startedAt?.toIso8601String()};
}

/// アップロード済みの共有コンテンツ(`POST /astell/rooms/{id}/assets` の応答)。
@immutable
class AstellAsset {
  const AstellAsset({required this.id, required this.url, required this.name, required this.contentType, required this.sizeBytes});
  final String id;
  final Uri url;
  final String name;
  final String contentType;
  final int sizeBytes;

  factory AstellAsset.fromJson(Map<String, Object?> j) => AstellAsset(
        id: j['id'] as String? ?? '',
        url: Uri.parse(j['url'] as String? ?? ''),
        name: j['name'] as String? ?? '',
        contentType: j['contentType'] as String? ?? 'application/octet-stream',
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

/// VC ホームの 3 節(ワイヤーフレーム p.3)。
@immutable
class AstellHome {
  const AstellHome({this.recommended = const [], this.trending = const [], this.following = const []});
  final List<AstellRoom> recommended;
  final List<AstellRoom> trending;
  final List<AstellRoom> following;

  factory AstellHome.fromJson(Map<String, Object?> j) {
    List<AstellRoom> rooms(Object? v) => [for (final r in (v as List? ?? const [])) if (r is Map) AstellRoom.fromJson(r.cast<String, Object?>())];
    return AstellHome(recommended: rooms(j['recommended']), trending: rooms(j['trending']), following: rooms(j['following']));
  }
}

/// 作成 FOW の入力。
@immutable
class NewAstellRoom {
  const NewAstellRoom({required this.title, this.description = '', this.genres = const [], this.welcomeMessage, this.showSummary = true, this.autoGenre = true, this.visibility = 'public'});
  final String title;
  final String description;
  final List<String> genres;
  final String? welcomeMessage;
  final bool showSummary;
  final bool autoGenre;
  final String visibility;

  Map<String, Object?> toJson() => {
        'title': title,
        'description': description,
        'genres': genres,
        'visibility': visibility,
        'welcomeMessage': ?welcomeMessage,
        'showSummary': showSummary,
        'autoGenre': autoGenre,
      };
}

/// 接続中のピア(参加メンバー)。
@immutable
class AstellPeer {
  const AstellPeer({required this.peerId, required this.accountId, required this.handle, required this.displayName, this.avatarUrl, this.micOn = false, this.speaking = false});
  final String peerId;
  final String accountId;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;

  /// マイク状態(シグナリングの拡張で流す予定。今は端末側の表示用)。
  final bool micOn;
  final bool speaking;

  UserSummary get user => _rasqUser(id: accountId, handle: handle, displayName: displayName, avatarUrl: avatarUrl, presence: UserPresence.inVc);

  factory AstellPeer.fromJson(Map<String, Object?> j) => AstellPeer(
        peerId: j['peerId'] as String? ?? '',
        accountId: j['accountId'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        avatarUrl: _uri(j['avatarUrl']),
        micOn: j['micOn'] == true,
      );
}

/// 共有(プラグイン以外: post / media / link / text)。
@immutable
class AstellShare {
  const AstellShare({required this.id, required this.accountId, required this.handle, required this.displayName, required this.kind, this.payload = const {}, required this.createdAt});
  final String id;
  final String accountId;
  final String handle;
  final String displayName;
  final String kind;
  final Map<String, Object?> payload;
  final DateTime createdAt;

  /// 1 行表示(共有欄のカード見出し)。
  String get headline => switch (kind) {
        'text' => payload['text'] as String? ?? '',
        'link' => payload['title'] as String? ?? payload['url'] as String? ?? '',
        'post' => payload['body'] as String? ?? payload['text'] as String? ?? '投稿',
        'media' => payload['title'] as String? ?? 'メディア',
        _ => kind,
      };

  /// 種別の日本語ラベル(stick のタイルのピル)。
  String get kindLabel => switch (kind) {
        'post' => '投稿',
        'media' => (payload['mimeType'] as String? ?? '').startsWith('video/') ? '動画' : 'メディア',
        'link' => 'リンク',
        'text' => 'テキスト',
        _ => kind,
      };

  /// 投稿/メディアの作者名(payload の `author`、無ければ共有した人)。
  String get authorName => payload['author'] as String? ?? displayName;
  Uri? get authorAvatarUrl => _uri(payload['avatarUrl']);

  /// 投稿の所属 SNS(`sns` / `instance` / `postId`)。対応プラグインがあればアプリ内で開く。
  String? get snsKind => payload['sns'] as String?;
  String? get instance => payload['instance'] as String?;
  String? get postId => payload['postId'] as String?;
  Uri? get url => _uri(payload['url']);
  bool get isImage => (payload['mimeType'] as String? ?? '').startsWith('image/');

  /// サムネイル(メディア / 投稿の添付 / リンクの OGP)。
  Uri? get thumbnailUrl => _uri(payload['thumbnailUrl']) ?? (kind == 'media' ? _uri(payload['url']) : null);
  bool get isVideo => (payload['mimeType'] as String? ?? '').startsWith('video/');

  factory AstellShare.fromJson(Map<String, Object?> j) => AstellShare(
        id: j['id'] as String? ?? '',
        accountId: j['accountId'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        kind: j['kind'] as String? ?? 'text',
        payload: (j['payload'] as Map?)?.cast<String, Object?>() ?? const {},
        createdAt: _date(j['createdAt']),
      );
}

/// 文字起こし 1 件(distil-whisper/distil-large-v3、サーバー側)。
@immutable
class AstellTranscript {
  const AstellTranscript({required this.id, required this.accountId, required this.handle, required this.displayName, required this.text, this.lang, required this.createdAt});
  final String id;
  final String accountId;
  final String handle;
  final String displayName;
  final String text;
  final String? lang;
  final DateTime createdAt;

  factory AstellTranscript.fromJson(Map<String, Object?> j) => AstellTranscript(
        id: j['id'] as String? ?? '',
        accountId: j['accountId'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        text: j['text'] as String? ?? '',
        lang: j['lang'] as String?,
        createdAt: _date(j['createdAt']),
      );
}
