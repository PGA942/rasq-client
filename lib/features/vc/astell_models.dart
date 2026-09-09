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
    this.ttsVoice,
    this.joinPolicy = 'anyone',
    this.sharePolicy = 'everyone',
    this.moderators = const [],
    this.tendencyFilter = false,
    this.locked = false,
    this.scheduledAt,
    this.shareUrl,
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

  /// 読み上げのプリセット音声(CosyVoice2-0.5B)。null = 読み上げなし。
  final String? ttsVoice;

  /// 参加できる人 (D-149): anyone | followers | following | mutual。
  final String joinPolicy;

  /// 共有できる人 (D-149): everyone | moderators。
  final String sharePolicy;

  /// モデレーターのアカウント id(オーナーは含まない)。
  final List<String> moderators;

  /// 発信傾向(GoEmotion、今はダミー判定)で入室を絞る (D-150)。
  final bool tendencyFilter;

  /// 運営(rasq-judge)による新規入室停止 (D-151)。
  final bool locked;

  /// 開催予約 (D-159/S-011)。null = 開催中。未来ならオーナー/モデレーター以外は入れず、
  /// オーナーが接続した時点で開催中になる(サーバーが null にする)。
  final DateTime? scheduledAt;

  /// 共有 URL (D-165/S-012): `https://astell.rasq.jp/@handle/<Base58 id>`。サーバーが
  /// 付ける。無ければ(モック)`rasq://astell/<id>`。
  final String? shareUrl;

  bool get isOpen => closedAt == null;

  /// 予約中(まだ開催時刻が来ていない)か。
  bool get isScheduled => scheduledAt != null && scheduledAt!.isAfter(DateTime.now());

  /// オーナーかモデレーターか。
  bool isModerator(String? accountId) => accountId != null && (accountId == ownerId || moderators.contains(accountId));

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
        ttsVoice: j['ttsVoice'] as String?,
        joinPolicy: j['joinPolicy'] as String? ?? 'anyone',
        sharePolicy: j['sharePolicy'] as String? ?? 'everyone',
        moderators: [for (final m in (j['moderators'] as List? ?? const [])) if (m is String) m],
        tendencyFilter: j['tendencyFilter'] == true,
        locked: j['locked'] == true,
        scheduledAt: j['scheduledAt'] is String ? DateTime.tryParse(j['scheduledAt'] as String)?.toLocal() : null,
        shareUrl: (j['shareUrl'] as String?)?.isNotEmpty == true ? j['shareUrl'] as String : null,
      );

  /// ワイヤ形(サーバーの `Room` と同じ)。ブックマークのスナップショット (D-160) と
  /// モックの `room` メッセージに使う。
  Map<String, Object?> toJson() => {
        'id': id, 'ownerId': ownerId, 'ownerHandle': ownerHandle, 'ownerDisplayName': ownerDisplayName, 'ownerAvatarUrl': ownerAvatarUrl?.toString(),
        'title': title, 'description': description, 'genres': genres, 'visibility': visibility, 'welcomeMessage': welcomeMessage,
        'showSummary': showSummary, 'autoGenre': autoGenre, 'createdAt': createdAt.toIso8601String(), 'closedAt': closedAt?.toIso8601String(), 'peerCount': peerCount, 'live': live,
        'thumbnailUrl': thumbnailUrl?.toString(), 'hostStream': hostStream?.toJson(), 'ttsVoice': ttsVoice,
        'joinPolicy': joinPolicy, 'sharePolicy': sharePolicy, 'moderators': moderators, 'tendencyFilter': tendencyFilter, 'locked': locked,
        'scheduledAt': scheduledAt?.toUtc().toIso8601String(),
        'shareUrl': shareUrl,
      };

  AstellRoom copyWith({String? title, String? description, List<String>? genres, bool? showSummary, bool? autoGenre, int? peerCount, bool? live, AstellHostStream? hostStream, bool clearHostStream = false, String? ttsVoice, bool clearTtsVoice = false, String? joinPolicy, String? sharePolicy, List<String>? moderators, bool? tendencyFilter, DateTime? scheduledAt, bool clearSchedule = false}) => AstellRoom(
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
        ttsVoice: clearTtsVoice ? null : (ttsVoice ?? this.ttsVoice),
        joinPolicy: joinPolicy ?? this.joinPolicy,
        sharePolicy: sharePolicy ?? this.sharePolicy,
        moderators: moderators ?? this.moderators,
        tendencyFilter: tendencyFilter ?? this.tendencyFilter,
        locked: locked,
        scheduledAt: clearSchedule ? null : (scheduledAt ?? this.scheduledAt),
        shareUrl: shareUrl,
      );
}

/// フォロー / フォロワー / ブロックの 1 件 (`GET /me/following|followers|blocks`)。
@immutable
class AstellFollowEntry {
  const AstellFollowEntry({required this.id, required this.handle, required this.displayName, this.avatarUrl});
  final String id;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;
  factory AstellFollowEntry.fromJson(Map<String, Object?> j) => AstellFollowEntry(id: j['id'] as String? ?? '', handle: j['handle'] as String? ?? '', displayName: j['displayName'] as String? ?? '', avatarUrl: _uri(j['avatarUrl']));
}

/// 発信傾向 (D-150、`GET /judge/tendency/{id}`)。今はサーバーのダミー判定。
@immutable
class AstellTendency {
  const AstellTendency({required this.accountId, required this.labels, required this.hostile, required this.source});
  final String accountId;
  final List<({String label, double score})> labels;
  final bool hostile;
  final String source;
  factory AstellTendency.fromJson(Map<String, Object?> j) => AstellTendency(
        accountId: j['accountId'] as String? ?? '',
        labels: [for (final l in (j['labels'] as List? ?? const [])) if (l is Map) (label: l['label'] as String? ?? '', score: (l['score'] as num?)?.toDouble() ?? 0)],
        hostile: j['hostile'] == true,
        source: j['source'] as String? ?? '',
      );
  String get summary => labels.map((l) => '${l.label} ${(l.score * 100).round()}%').join(' / ');
}

/// 通報の理由 (D-150、`POST /reports`)。
const astellReportReasons = <({String id, String label})>[
  (id: 'spam', label: 'スパム'),
  (id: 'harassment', label: '嫌がらせ・暴言'),
  (id: 'illegal', label: '違法・危険な内容'),
  (id: 'other', label: 'その他'),
];

/// 参加ポリシーの表示 (D-149)。
const astellJoinPolicies = <({String id, String label, String hint})>[
  (id: 'anyone', label: '誰でも', hint: '公開ルームは誰でも参加できます'),
  (id: 'followers', label: 'フォロワーだけ', hint: 'あなた(ホスト)を RASQ アカウントでフォローしている人'),
  (id: 'following', label: 'フォロー中の人だけ', hint: 'あなたがフォローしている人'),
  (id: 'mutual', label: '相互フォローだけ', hint: 'お互いにフォローしている人'),
];
const astellSharePolicies = <({String id, String label})>[
  (id: 'everyone', label: '全員'),
  (id: 'moderators', label: 'モデレーターだけ'),
];

/// BAN の 1 件 (D-149)。
@immutable
class AstellBan {
  const AstellBan({required this.accountId, required this.handle, required this.displayName, this.reason, required this.createdAt});
  final String accountId;
  final String handle;
  final String displayName;
  final String? reason;
  final DateTime createdAt;
  factory AstellBan.fromJson(Map<String, Object?> j) => AstellBan(
        accountId: j['accountId'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        reason: j['reason'] as String?,
        createdAt: _date(j['createdAt']),
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
  const AstellHome({this.recommended = const [], this.trending = const [], this.following = const [], this.invited = const [], this.upcoming = const []});
  final List<AstellRoom> recommended;
  final List<AstellRoom> trending;
  final List<AstellRoom> following;

  /// 招待されているルーム (D-150)。
  final List<AstellRoom> invited;

  /// 開催予約中のルーム (D-159): 近い順。
  final List<AstellRoom> upcoming;

  factory AstellHome.fromJson(Map<String, Object?> j) {
    List<AstellRoom> rooms(Object? v) => [for (final r in (v as List? ?? const [])) if (r is Map) AstellRoom.fromJson(r.cast<String, Object?>())];
    return AstellHome(recommended: rooms(j['recommended']), trending: rooms(j['trending']), following: rooms(j['following']), invited: rooms(j['invited']), upcoming: rooms(j['upcoming']));
  }
}

/// 作成 FOW の入力。
@immutable
class NewAstellRoom {
  const NewAstellRoom({required this.title, this.description = '', this.genres = const [], this.welcomeMessage, this.showSummary = true, this.autoGenre = true, this.visibility = 'public', this.scheduledAt});
  final String title;
  final String description;
  final List<String> genres;
  final String? welcomeMessage;
  final bool showSummary;
  final bool autoGenre;
  final String visibility;

  /// 開催予約 (D-159)。null = 作成即開催。
  final DateTime? scheduledAt;

  Map<String, Object?> toJson() => {
        'title': title,
        'description': description,
        'genres': genres,
        'visibility': visibility,
        'welcomeMessage': ?welcomeMessage,
        'showSummary': showSummary,
        'autoGenre': autoGenre,
        if (scheduledAt != null) 'scheduledAt': scheduledAt!.toUtc().toIso8601String(),
      };
}

/// 接続中のピア(参加メンバー)。
/// ピアの画面共有(`state.screenShare`)。
@immutable
class AstellScreenShare {
  const AstellScreenShare({this.title = '', this.thumbnailUrl});
  final String title;
  final Uri? thumbnailUrl;
  factory AstellScreenShare.fromJson(Map<String, Object?> j) => AstellScreenShare(title: j['title'] as String? ?? '', thumbnailUrl: _uri(j['thumbnailUrl']));
  Map<String, Object?> toJson() => {'title': title, 'thumbnailUrl': thumbnailUrl?.toString()};
}

@immutable
class AstellPeer {
  const AstellPeer({required this.peerId, required this.accountId, required this.handle, required this.displayName, this.avatarUrl, this.micOn = false, this.speaking = false, this.screenShare, this.mutedByMod = false});
  final String peerId;
  final String accountId;
  final String handle;
  final String displayName;
  final Uri? avatarUrl;

  /// マイク状態(`state.micOn`、シグナリングの `state` で共有)。
  final bool micOn;
  final bool speaking;

  /// このピアの画面共有。null = していない。
  final AstellScreenShare? screenShare;

  /// モデレーターに全員向けミュートされている (D-149、`state.mutedByMod`)。
  final bool mutedByMod;

  UserSummary get user => _rasqUser(id: accountId, handle: handle, displayName: displayName, avatarUrl: avatarUrl, presence: UserPresence.inVc);

  factory AstellPeer.fromJson(Map<String, Object?> j) {
    final st = (j['state'] as Map?)?.cast<String, Object?>() ?? const {};
    return AstellPeer(
      peerId: j['peerId'] as String? ?? '',
      accountId: j['accountId'] as String? ?? '',
      handle: j['handle'] as String? ?? '',
      displayName: j['displayName'] as String? ?? '',
      avatarUrl: _uri(j['avatarUrl']),
      micOn: j['micOn'] == true || st['micOn'] == true,
      screenShare: st['screenShare'] is Map ? AstellScreenShare.fromJson((st['screenShare'] as Map).cast<String, Object?>()) : null,
      mutedByMod: st['mutedByMod'] == true,
    );
  }

  AstellPeer copyWith({bool? micOn, AstellScreenShare? screenShare, bool clearScreenShare = false, bool? mutedByMod}) => AstellPeer(
        peerId: peerId,
        accountId: accountId,
        handle: handle,
        displayName: displayName,
        avatarUrl: avatarUrl,
        micOn: micOn ?? this.micOn,
        speaking: speaking,
        screenShare: clearScreenShare ? null : (screenShare ?? this.screenShare),
        mutedByMod: mutedByMod ?? this.mutedByMod,
      );
}

/// 共有(プラグイン以外: post / media / link / text)。
@immutable
class AstellShare {
  const AstellShare({required this.id, required this.accountId, required this.handle, required this.displayName, required this.kind, this.payload = const {}, this.pinned = false, required this.createdAt});
  final String id;
  final String accountId;
  final String handle;
  final String displayName;
  final String kind;
  final Map<String, Object?> payload;

  /// チャットからピン留めされて「共有」欄に出ているか (D-146)。
  final bool pinned;
  final DateTime createdAt;

  AstellShare copyWith({bool? pinned}) => AstellShare(id: id, accountId: accountId, handle: handle, displayName: displayName, kind: kind, payload: payload, pinned: pinned ?? this.pinned, createdAt: createdAt);

  /// 自動表示設定のキー(画像 / 動画 / リンク / 投稿 / テキスト)。
  String get mediaClass => switch (kind) {
        'media' => isVideo ? 'video' : (isImage ? 'image' : 'file'),
        _ => kind,
      };

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
        pinned: j['pinned'] == true,
        createdAt: _date(j['createdAt']),
      );
}

/// 文字起こし 1 件(distil-whisper/distil-large-v3、サーバー側)。
@immutable
class AstellTranscript {
  const AstellTranscript({required this.id, required this.accountId, required this.handle, required this.displayName, required this.text, this.lang, this.pinned = false, required this.createdAt});
  final String id;
  final String accountId;
  final String handle;
  final String displayName;
  final String text;
  final String? lang;
  final bool pinned;
  final DateTime createdAt;

  AstellTranscript copyWith({bool? pinned}) => AstellTranscript(id: id, accountId: accountId, handle: handle, displayName: displayName, text: text, lang: lang, pinned: pinned ?? this.pinned, createdAt: createdAt);

  factory AstellTranscript.fromJson(Map<String, Object?> j) => AstellTranscript(
        id: j['id'] as String? ?? '',
        accountId: j['accountId'] as String? ?? '',
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        text: j['text'] as String? ?? '',
        lang: j['lang'] as String?,
        pinned: j['pinned'] == true,
        createdAt: _date(j['createdAt']),
      );
}
