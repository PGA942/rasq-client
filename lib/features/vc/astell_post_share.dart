import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// SNS 投稿の AsTell へのインライン共有 (D-166/S-013)。
///
/// 共有 `kind: "post"` の payload はサーバーの `PostPayload` と同じ形:
/// `{url, sns, instance, postId, author, handle, avatarUrl?, body, thumbnailUrl?, media:[{url, thumbnailUrl?, type}], createdAt?}`。
/// 手元にある [Post](自分の TL の投稿)からはそのまま組み、URL だけのときは
/// **自分のアカウントのインスタンスと一致すればプラグインのトークン**で取り、
/// そうでなければ Central の `POST /astell/posts/resolve`(公開 API)で取る。
/// タップ時は payload の `instance` がログイン中のアカウントと一致すれば
/// アプリ内でスレッド展開、そうでなければブラウザ。

/// 投稿 URL の判定(Central の `parse_post_url` と同じ規則)。
({String sns, String instance, String id})? parseSnsPostUrl(String url) {
  final u = Uri.tryParse(url.trim());
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return null;
  final segs = u.pathSegments.where((s) => s.isNotEmpty).toList();
  if (u.host == 'bsky.app' || u.host == 'staging.bsky.app') {
    if (segs.length == 4 && segs[0] == 'profile' && segs[2] == 'post') return (sns: 'bluesky', instance: 'bsky.social', id: 'at://${segs[1]}/app.bsky.feed.post/${segs[3]}');
    return null;
  }
  final alnum = RegExp(r'^[A-Za-z0-9]+$');
  final digits = RegExp(r'^[0-9]+$');
  if (segs.length == 2 && segs[0] == 'notes' && alnum.hasMatch(segs[1])) return (sns: 'misskey', instance: u.host, id: segs[1]);
  if (segs.length == 2 && segs[0].startsWith('@') && digits.hasMatch(segs[1])) return (sns: 'mastodon', instance: u.host, id: segs[1]);
  if (segs.length == 4 && segs[0] == 'users' && segs[2] == 'statuses' && digits.hasMatch(segs[3])) return (sns: 'mastodon', instance: u.host, id: segs[3]);
  return null;
}

/// 投稿の Web URL(`Post.url` が無ければ SNS ごとの定番パス)。
Uri postWebUrl(Post p) =>
    p.url ??
    switch (p.account.kind) {
      SnsKind.misskey => Uri.https(p.account.instance, '/notes/${p.id}'),
      SnsKind.mastodon => Uri.https(p.account.instance, '/@${p.author.handle}/${p.id}'),
      SnsKind.bluesky => Uri.https('bsky.app', '/profile/${p.author.handle}/post/${p.id.split('/').last}'),
      _ => Uri.https(p.account.instance, '/${p.id}'),
    };

String _mediaType(MediaType t) => switch (t) { MediaType.image => 'image', MediaType.video => 'video', MediaType.gif => 'gif', MediaType.file => 'file' };
MediaType _mediaTypeOf(String? t) => switch (t) { 'image' => MediaType.image, 'video' => MediaType.video, 'gif' => MediaType.gif, _ => MediaType.file };

/// ルーム全員に本文ごと見せてよい公開範囲(Central の `SHAREABLE_VISIBILITY` と同じ)。
const astellShareableVisibility = {'public', 'home', 'unlisted'};

/// AsTell へ**本文ごと**共有できない理由 (D-242 / S-016)。共有してよければ null。
///
/// 限定公開 / DM / ローカル限定 / 公開範囲が不明な投稿は、共有する人にしか読めないかもしれない。
/// その本文をルーム全員へ配らない。リンクだけの共有は別(見る側の権限で開く)。サーバーも同じ検査をする。
String? astellShareBlockReason(Post p) {
  if (p.source != PostSource.note || p.isDirect) return 'ダイレクトの投稿は AsTell に共有できません';
  if (p.localOnly) return 'ローカル限定の投稿は AsTell に共有できません';
  final v = p.visibility;
  if (v == null || v.isEmpty) return '公開範囲が分からない投稿は AsTell に共有できません';
  if (!astellShareableVisibility.contains(v)) return '公開範囲が限定された投稿は AsTell に共有できません';
  return null;
}

/// 手元の投稿 → 共有 payload。
Map<String, Object?> astellPostPayloadOf(Post p) {
  final media = [
    for (final m in p.media)
      {'url': m.url.toString(), if (m.thumbnailUrl != null) 'thumbnailUrl': m.thumbnailUrl.toString(), 'type': _mediaType(m.type), if (m.sensitive) 'sensitive': true},
  ];
  final thumb = p.media.where((m) => m.type != MediaType.file).firstOrNull;
  return {
    'url': postWebUrl(p).toString(),
    'sns': p.account.kind.name,
    'instance': p.account.instance,
    'postId': p.id,
    'author': p.author.displayName,
    'handle': p.author.handle,
    if (p.author.avatarUrl != null) 'avatarUrl': p.author.avatarUrl.toString(),
    'body': p.contentWarning != null && p.contentWarning!.isNotEmpty ? '[${p.contentWarning}] ${p.body}' : p.body,
    if (thumb != null) 'thumbnailUrl': (thumb.thumbnailUrl ?? thumb.url).toString(),
    'media': media,
    'createdAt': p.createdAt.toUtc().toIso8601String(),
    // 公開範囲と閲覧注意は本文とは別の情報として持つ (D-242)。サーバーは visibility を検査する。
    if (p.visibility != null) 'visibility': p.visibility,
    'localOnly': p.localOnly,
    if (p.contentWarning != null && p.contentWarning!.isNotEmpty) 'cw': p.contentWarning,
    // 閲覧注意 (TERMS-10): メディアごとの印に加えて、投稿としての印も持つ(カードはこれを見て画像をぼかす)。
    if (p.media.any((m) => m.sensitive)) 'sensitive': true,
  };
}

/// payload の投稿を、[account] で開く [Post] に戻す(スレッド展開の初期表示用)。
Post? postFromSharePayload(Map<String, Object?> payload, AccountId account) {
  final id = payload['postId'] as String?;
  if (id == null || id.isEmpty) return null;
  final handle = payload['handle'] as String? ?? '';
  final authorAccount = AccountId(kind: account.kind, instance: payload['instance'] as String? ?? account.instance, handle: handle);
  var n = 0;
  final cw = payload['cw'] is String && (payload['cw'] as String).isNotEmpty ? payload['cw'] as String : null;
  var body = payload['body'] as String? ?? payload['text'] as String? ?? '';
  // 本文の先頭の「[CW] 」は、CW を別に持っているので外す (TERMS-10)。
  if (cw != null && body.startsWith('[$cw] ')) body = body.substring(cw.length + 3);
  final allSensitive = payload['sensitive'] == true;
  return Post(
    id: id,
    account: account,
    author: UserSummary(id: 'share:$handle', account: authorAccount, displayName: payload['author'] as String? ?? handle, avatarUrl: Uri.tryParse(payload['avatarUrl'] as String? ?? '')),
    createdAt: DateTime.tryParse(payload['createdAt'] as String? ?? '') ?? DateTime.now(),
    body: body,
    contentWarning: cw,
    media: [
      for (final m in (payload['media'] as List? ?? const []))
        if (m is Map && m['url'] is String && Uri.tryParse(m['url'] as String) != null)
          MediaItem(
            id: 'm${n++}',
            type: _mediaTypeOf(m['type'] as String?),
            url: Uri.parse(m['url'] as String),
            thumbnailUrl: m['thumbnailUrl'] is String ? Uri.tryParse(m['thumbnailUrl'] as String) : null,
            sensitive: m['sensitive'] == true || allSensitive,
          ),
    ],
    url: Uri.tryParse(payload['url'] as String? ?? ''),
  );
}

/// payload の投稿を開けるログイン中アカウント: 同じ SNS 種別で、インスタンスが
/// 一致するもの(Bluesky は種別だけ)。無ければ null(= ブラウザで開く)。
AccountId? astellAccountForPost(Map<String, Object?> payload, Iterable<AccountSession> sessions, {AccountId? prefer}) {
  final sns = payload['sns'] as String?;
  final instance = payload['instance'] as String?;
  bool ok(AccountId a) => sns != null && a.kind.name == sns && (a.kind == SnsKind.bluesky || instance == null || a.instance == instance);
  if (prefer != null && ok(prefer)) return prefer;
  for (final s in sessions) {
    if (ok(s.account)) return s.account;
  }
  return null;
}

/// 本文ごとの共有を止めた(呼び元はリンクの共有へ切り替える)。
class AstellShareBlocked implements Exception {
  const AstellShareBlocked();
}
