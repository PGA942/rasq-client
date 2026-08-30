import 'account.dart';
import 'media.dart';
import 'page.dart';
import 'post.dart';
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
        votedIndices: {for (final i in (j['voted'] as List? ?? const [])) (i as num).toInt()},
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
}
