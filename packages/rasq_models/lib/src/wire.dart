import 'account.dart';
import 'dm.dart';
import 'media.dart';
import 'notification.dart';
import 'page.dart';
import 'post.dart';
import 'profile.dart';
import 'reaction.dart';
import 'thread.dart';
import 'user.dart';

/// SNS 境界のワイヤ形 (`rasq.post/1`、D-074 / M5d)。
///
/// wasm SNS プラグインの**イベントハンドラー抽象関数**(SnsSession 契約の
/// boundary 写像、例 `sns.timeline`)がホストと交換する投稿/ユーザーの
/// JSON。RRL snapshot(画面コンストラクタ側)とは別のデータワイヤ。
///
/// 閲覧アカウントのキー付け([Post.account])はワイヤに含めない —
/// 取り込み時にホスト(セッションアダプター)が与える。
abstract final class SnsWire {
  static Map<String, Object?> user(UserSummary u) => {
        'id': u.id,
        'kind': u.account.kind.name,
        'instance': u.account.instance,
        'handle': u.account.handle,
        'displayName': u.displayName,
        'avatarUrl': ?u.avatarUrl?.toString(),
        'bio': ?u.bio,
      };

  static UserSummary userFrom(Map<String, Object?> j) => UserSummary(
        id: '${j['id']}',
        account: AccountId(
          kind: SnsKind.values.asNameMap()['${j['kind']}'] ?? SnsKind.misskey,
          instance: '${j['instance'] ?? ''}',
          handle: '${j['handle'] ?? ''}',
        ),
        displayName: '${j['displayName'] ?? j['handle'] ?? '?'}',
        avatarUrl: j['avatarUrl'] is String ? Uri.tryParse(j['avatarUrl'] as String) : null,
        bio: j['bio'] as String?,
      );

  static Map<String, Object?> media(MediaItem m) => {
        'id': m.id,
        'type': m.type.name,
        'url': m.url.toString(),
        'thumbnailUrl': ?m.thumbnailUrl?.toString(),
        'alt': ?m.alt,
        if (m.sensitive) 'sensitive': true,
        'fileName': ?m.fileName,
        'width': ?m.width,
        'height': ?m.height,
      };

  static MediaItem mediaFrom(Map<String, Object?> j) => MediaItem(
        id: '${j['id']}',
        type: MediaType.values.asNameMap()['${j['type']}'] ?? MediaType.file,
        url: Uri.parse('${j['url']}'),
        thumbnailUrl: j['thumbnailUrl'] is String ? Uri.tryParse(j['thumbnailUrl'] as String) : null,
        alt: j['alt'] as String?,
        sensitive: j['sensitive'] == true,
        fileName: j['fileName'] as String?,
        width: (j['width'] as num?)?.toInt(),
        height: (j['height'] as num?)?.toInt(),
      );

  static Map<String, Object?> poll(Poll p) => {
        'options': [
          for (final o in p.options) {'text': o.text, 'votes': o.votes, 'imageUrl': ?o.imageUrl?.toString()},
        ],
        if (p.multiple) 'multiple': true,
        'expiresAt': ?p.expiresAt?.toIso8601String(),
        if (p.votedIndices.isNotEmpty) 'voted': p.votedIndices.toList(),
      };

  static Poll pollFrom(Map<String, Object?> j) => Poll(
        options: [
          for (final o in (j['options'] as List? ?? const []))
            PollOption(
              text: '${(o as Map)['text'] ?? ''}',
              votes: (o['votes'] as num?)?.toInt() ?? 0,
              imageUrl: o['imageUrl'] is String ? Uri.tryParse(o['imageUrl'] as String) : null,
            ),
        ],
        multiple: j['multiple'] == true,
        expiresAt: j['expiresAt'] is String ? DateTime.tryParse(j['expiresAt'] as String) : null,
        // `voted` は投票した選択肢の番号の並び。真偽値で送ってくるプラグイン(Mastodon の `voted: false`)があるので、並びでなければ「なし」として読む(投稿ごと落とさない)。
        votedIndices: {if (j['voted'] case final List v) for (final i in v) if (i is num) i.toInt()},
      );

  static Map<String, Object?> post(Post p) => {
        'id': p.id,
        'author': user(p.author),
        'createdAt': p.createdAt.toIso8601String(),
        'body': p.body,
        'bodyFormat': p.bodyFormat,
        'cw': ?p.contentWarning,
        if (p.media.isNotEmpty) 'media': [for (final m in p.media) media(m)],
        'poll': ?(p.poll == null ? null : poll(p.poll!)),
        'quote': ?(p.quote == null ? null : post(p.quote!)),
        'replyTo': ?(p.replyTo == null ? null : post(p.replyTo!)),
        'replyToId': ?p.replyToId,
        'repostedBy': ?(p.repostedBy == null ? null : user(p.repostedBy!)),
        'linkUrl': ?p.linkUrl?.toString(),
        if (p.counts.isNotEmpty) 'counts': p.counts,
        'visibility': ?p.visibility,
        if (p.localOnly) 'localOnly': true,
        if (p.directToIds.isNotEmpty) 'directToIds': p.directToIds,
        if (p.reactions.isNotEmpty) 'reactions': p.reactions,
        if (p.reactionEmojis.isNotEmpty) 'reactionEmojis': {for (final e in p.reactionEmojis.entries) e.key: e.value.toString()},
        'myReaction': ?p.myReaction,
        if (p.source != PostSource.note) 'source': p.source.name,
        'url': ?p.url?.toString(),
      };

  static Post postFrom(Map<String, Object?> j, {required AccountId account}) => Post(
        id: '${j['id']}',
        account: account,
        author: userFrom((j['author'] as Map? ?? const {}).cast<String, Object?>()),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        body: '${j['body'] ?? ''}',
        bodyFormat: '${j['bodyFormat'] ?? 'plain'}',
        contentWarning: j['cw'] as String?,
        media: [for (final m in (j['media'] as List? ?? const [])) mediaFrom((m as Map).cast<String, Object?>())],
        poll: j['poll'] is Map ? pollFrom((j['poll'] as Map).cast<String, Object?>()) : null,
        quote: j['quote'] is Map ? postFrom((j['quote'] as Map).cast<String, Object?>(), account: account) : null,
        replyTo: j['replyTo'] is Map ? postFrom((j['replyTo'] as Map).cast<String, Object?>(), account: account) : null,
        replyToId: j['replyToId'] as String?,
        repostedBy: j['repostedBy'] is Map ? userFrom((j['repostedBy'] as Map).cast<String, Object?>()) : null,
        linkUrl: j['linkUrl'] is String ? Uri.tryParse(j['linkUrl'] as String) : null,
        counts: {for (final e in ((j['counts'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num?)?.toInt() ?? 0},
        visibility: j['visibility'] as String?,
        localOnly: j['localOnly'] == true,
        directToIds: [for (final id in (j['directToIds'] as List? ?? const [])) '$id'],
        reactions: {for (final e in ((j['reactions'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num?)?.toInt() ?? 0},
        reactionEmojis: {
          for (final e in ((j['reactionEmojis'] as Map?) ?? const {}).entries)
            if (e.value is String && Uri.tryParse(e.value as String) != null) '${e.key}': Uri.parse(e.value as String),
        },
        myReaction: j['myReaction'] as String?,
        source: PostSource.values.asNameMap()['${j['source']}'] ?? PostSource.note,
        url: j['url'] is String ? Uri.tryParse(j['url'] as String) : null,
      );

  static Map<String, Object?> page(Page<Post> p) => {
        'items': [for (final x in p.items) post(x)],
        'nextCursor': ?p.nextCursor,
      };

  static Page<Post> pageFrom(Map<String, Object?> j, {required AccountId account}) => Page(
        items: [for (final x in (j['items'] as List? ?? const [])) postFrom((x as Map).cast<String, Object?>(), account: account)],
        nextCursor: j['nextCursor'] as String?,
      );

  static Page<UserSummary> userPageFrom(Map<String, Object?> j) => Page(
        items: [for (final x in (j['items'] as List? ?? const [])) userFrom((x as Map).cast<String, Object?>())],
        nextCursor: j['nextCursor'] as String?,
      );

  /// `createPost` の下書き (D-076: `sns.createPost` の引数)。
  static Map<String, Object?> newPost(NewPost d) => {
        'text': d.text,
        'cw': ?d.contentWarning,
        'replyToId': ?d.replyToId,
        'quoteOfId': ?d.quoteOfId,
        'repostOfId': ?d.repostOfId,
        'visibility': ?d.visibility,
        if (d.localOnly) 'localOnly': true,
        'reactionAcceptance': ?d.reactionAcceptance,
        if (d.directToIds.isNotEmpty) 'directToIds': d.directToIds,
        if (d.mediaIds.isNotEmpty) 'mediaIds': d.mediaIds,
        'poll': ?(d.poll == null
            ? null
            : {
                'choices': d.poll!.choices,
                if (d.poll!.multiple) 'multiple': true,
                'expiresAfterSec': ?d.poll!.expiresAfter?.inSeconds,
              }),
      };

  static UserProfile profileFrom(Map<String, Object?> j, {required AccountId account}) => UserProfile(
        summary: userFrom((j['user'] as Map? ?? const {}).cast<String, Object?>()),
        bannerUrl: j['bannerUrl'] is String ? Uri.tryParse(j['bannerUrl'] as String) : null,
        description: j['description'] as String?,
        followersCount: (j['followersCount'] as num?)?.toInt(),
        followingCount: (j['followingCount'] as num?)?.toInt(),
        postsCount: (j['postsCount'] as num?)?.toInt(),
        fields: [
          for (final f in (j['fields'] as List? ?? const []))
            ProfileField(name: '${(f as Map)['name'] ?? ''}', value: '${f['value'] ?? ''}', verified: f['verified'] == true),
        ],
        createdAt: j['createdAt'] is String ? DateTime.tryParse(j['createdAt'] as String) : null,
        birthday: j['birthday'] as String?,
        location: j['location'] as String?,
        url: j['url'] is String ? Uri.tryParse(j['url'] as String) : null,
        isLocked: j['isLocked'] == true,
        isBot: j['isBot'] == true,
        isSuspended: j['isSuspended'] == true,
        pinnedPosts: [for (final p in (j['pinnedPosts'] as List? ?? const [])) postFrom((p as Map).cast<String, Object?>(), account: account)],
        profileUrl: j['profileUrl'] is String ? Uri.tryParse(j['profileUrl'] as String) : null,
      );

  static ReactionEntry reactionEntryFrom(Map<String, Object?> j) => ReactionEntry(
        id: '${j['id']}',
        user: userFrom((j['user'] as Map? ?? const {}).cast<String, Object?>()),
        reaction: '${j['reaction'] ?? ''}',
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        emojiUrl: j['emojiUrl'] is String ? Uri.tryParse(j['emojiUrl'] as String) : null,
      );

  static Thread threadFrom(Map<String, Object?> j, {required AccountId account}) => Thread(
        post: postFrom((j['post'] as Map? ?? const {}).cast<String, Object?>(), account: account),
        ancestors: [for (final a in (j['ancestors'] as List? ?? const [])) postFrom((a as Map).cast<String, Object?>(), account: account)],
        descendants: [for (final d in (j['descendants'] as List? ?? const [])) postFrom((d as Map).cast<String, Object?>(), account: account)],
      );

  // ── 通知 / DM (D-134) ────────────────────────────────────────────

  /// 通知ワイヤ → [NotificationItem]。
  ///
  /// `actors` はグループ通知を畳んだ配列(単体通知は 1 件)、
  /// `reactionsByActor` は actor id → リアクション文字列。未知の `kind` は
  /// [NotificationKind.other] に倒す — プラグインが新しい種別を返しても
  /// ホストは落ちず、アクションタイルとして描く。
  static NotificationItem notificationFrom(Map<String, Object?> j, {required AccountId account}) => NotificationItem(
        id: '${j['id']}',
        account: account,
        kind: NotificationKind.values.asNameMap()['${j['kind']}'] ?? NotificationKind.other,
        createdAt: DateTime.tryParse('${j['createdAt']}')?.toLocal() ?? DateTime.now(),
        actors: [
          for (final a in (j['actors'] as List? ?? const []))
            if (a is Map) userFrom(a.cast<String, Object?>()),
        ],
        post: j['post'] is Map ? postFrom((j['post'] as Map).cast<String, Object?>(), account: account) : null,
        reaction: j['reaction'] as String?,
        read: j['read'] == true,
        reactionsByActor: {
          for (final e in ((j['reactionsByActor'] as Map?) ?? const {}).entries)
            if (e.value is String) '${e.key}': e.value as String,
        },
        title: j['title'] as String?,
        body: j['body'] as String?,
      );

  static Page<NotificationItem> notificationPageFrom(Map<String, Object?> j, {required AccountId account}) => Page(
        items: [
          for (final n in (j['items'] as List? ?? const []))
            if (n is Map) notificationFrom(n.cast<String, Object?>(), account: account),
        ],
        nextCursor: j['nextCursor'] as String?,
      );

  /// DM ルームワイヤ → [DmRoom] (CONTRACT §7)。`kind` は `direct`
  /// (限定公開投稿を束ねたもの)か `chat`(ネイティブ Chat)。
  static DmRoom dmRoomFrom(Map<String, Object?> j, {required AccountId account}) => DmRoom(
        id: '${j['id']}',
        kind: DmRoomKind.values.asNameMap()['${j['kind']}'] ?? DmRoomKind.direct,
        peer: userFrom(((j['peer'] as Map?) ?? const {}).cast<String, Object?>()),
        lastPost: j['lastPost'] is Map ? postFrom((j['lastPost'] as Map).cast<String, Object?>(), account: account) : null,
        unreadCount: (j['unreadCount'] as num?)?.toInt() ?? 0,
        title: j['title'] as String?,
      );
}
