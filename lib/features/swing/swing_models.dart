import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';
import '../../l10n/l10n.dart';

/// Swing (D-377 / Central S-056): RASQ の短命の配信。正本は `rasq-central/docs/API.md` §4i。

enum SwingKind {
  text('text'),
  image('image'),
  video('video'),
  plugin('plugin');

  const SwingKind(this.wire);
  final String wire;

  /// 表示の名前(表示の言語)。
  String get label => switch (this) {
        text => appL10n.swingKindText,
        image => appL10n.swingKindImage,
        video => appL10n.swingKindVideo,
        plugin => appL10n.swingKindPlugin,
      };

  static SwingKind? parse(Object? v) => SwingKind.values.where((k) => k.wire == v).firstOrNull;
}

@immutable
class SwingPlugin {
  const SwingPlugin({required this.id, this.version, this.data, this.packageId, this.packageUrl, this.unreviewed = false, this.session, this.sessionId});
  final String id;
  final String? version;
  final Object? data;

  /// 作るとき (D-424 / Central S-079): shared のカスタムプラグインのセッション。[newSession] = この Swing のセッションを作る、
  /// ほか = いま入っている `link:` / `profile:` のセッションの id(カスタムプラグインのページの「招待」)。
  final String? session;

  /// 見る側: 入る shared のセッション(Central S-079)。無ければ 1 人で開く。
  final String? sessionId;

  /// [session] の「この Swing のセッションを作る」。
  static const newSession = 'new';

  /// 未審査 (D-379 / S-057): 作るときに上げた入れ物の id。
  final String? packageId;

  /// 未審査: 見る側が取る入れ物の URL(署名つき)。
  final Uri? packageUrl;
  final bool unreviewed;

  Map<String, Object?> toJson() => {'id': id, 'version': ?version, 'data': ?data, 'packageId': ?packageId, 'session': ?session};

  /// 版を付けない(Central の現在の版、D-424: 端末の版がそのサーバーで配られていないとき)。
  SwingPlugin withoutVersion() => SwingPlugin(id: id, data: data, packageId: packageId, packageUrl: packageUrl, unreviewed: unreviewed, session: session, sessionId: sessionId);
}

@immutable
class SwingAudience {
  const SwingAudience({this.followers = true, this.lists = const []});
  final bool followers;
  final List<String> lists;

  bool get isEmpty => !followers && lists.isEmpty;

  Map<String, Object?> toJson() => {'followers': followers, 'lists': lists};
}

@immutable
class Swing {
  const Swing({
    required this.id,
    required this.author,
    required this.kind,
    this.text = '',
    this.mediaUrl,
    this.mediaType,
    this.plugin,
    required this.createdAt,
    required this.expiresAt,
    this.seen = false,
    this.audience,
    this.viewCount,
    this.postId,
    this.replyCount = 0,
    this.cw,
    this.sensitive = false,
    this._adSafe,
    this.notified,
  });

  final String id;

  /// 作った人(RASQ アカウント。`id` = `rasq:<accountId>`)。
  final UserSummary author;
  final SwingKind kind;
  final String text;
  final Uri? mediaUrl;
  final String? mediaType;
  final SwingPlugin? plugin;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool seen;

  /// 作った人にだけ載る。
  final SwingAudience? audience;
  final int? viewCount;

  /// 返信とキューの根の RASQ 投稿 (D-389 / Central S-058)。見られる人にだけ見える。古い Central では null。
  final String? postId;
  final int replyCount;

  /// CW(注意書き、D-395 / Central S-060)。あればビューワーで覆ってから出す。
  final String? cw;

  /// センシティブな内容 (D-395)。
  final bool sensitive;

  final bool? _adSafe;

  /// 作ったときの応答にだけ: RASQ の通知を積んだ人数(Central S-079)。
  final int? notified;

  /// 広告の隣に置いてよいか (D-395)。Central の `adSafe`(通報 / 運営の止め / 作った人の処置も入る)。
  /// 古い Central で無ければ手元で: センシティブでなく、CW が無く、未審査のプラグインでない。
  bool get adSafe => _adSafe ?? (!sensitive && cw == null && !(plugin?.unreviewed ?? false));

  /// 覆ってから出すか(CW かセンシティブ)。
  bool get covered => cw != null || sensitive;

  String get authorAccountId => author.id.replaceFirst('rasq:', '');

  Swing copyWith({bool? seen, bool? adSafe}) => Swing(id: id, author: author, kind: kind, text: text, mediaUrl: mediaUrl, mediaType: mediaType, plugin: plugin, createdAt: createdAt, expiresAt: expiresAt, seen: seen ?? this.seen, audience: audience, viewCount: viewCount, postId: postId, replyCount: replyCount, cw: cw, sensitive: sensitive, adSafe: adSafe ?? _adSafe);

  Duration remaining(DateTime now) {
    final d = expiresAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  static Swing? tryParse(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, Object?>();
    final kind = SwingKind.parse(j['kind']);
    final a = j['author'];
    if (kind == null || a is! Map || j['id'] is! String) return null;
    final media = j['media'];
    final plugin = j['plugin'];
    final audience = j['audience'];
    return Swing(
      id: j['id'] as String,
      author: UserSummary(
        id: 'rasq:${a['accountId']}',
        account: AccountId(kind: SnsKind.other, instance: 'rasq', handle: '${a['handle'] ?? ''}'),
        displayName: '${a['displayName'] ?? a['handle'] ?? ''}',
        avatarUrl: a['avatarUrl'] is String && (a['avatarUrl'] as String).isNotEmpty ? Uri.tryParse(a['avatarUrl'] as String) : null,
      ),
      kind: kind,
      text: j['text'] as String? ?? '',
      mediaUrl: media is Map && media['url'] is String ? Uri.tryParse(media['url'] as String) : null,
      mediaType: media is Map ? media['contentType'] as String? : null,
      plugin: plugin is Map && plugin['id'] is String
          ? SwingPlugin(
              id: plugin['id'] as String,
              version: plugin['version'] as String?,
              data: plugin['data'],
              packageUrl: plugin['packageUrl'] is String ? Uri.tryParse(plugin['packageUrl'] as String) : null,
              unreviewed: plugin['unreviewed'] == true,
              sessionId: plugin['sessionId'] is String && (plugin['sessionId'] as String).isNotEmpty ? plugin['sessionId'] as String : null,
            )
          : null,
      createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: DateTime.tryParse('${j['expiresAt']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
      seen: j['seen'] == true,
      audience: audience is Map
          ? SwingAudience(followers: audience['followers'] == true, lists: [for (final l in (audience['lists'] as List? ?? const [])) '$l'])
          : null,
      viewCount: (j['viewCount'] as num?)?.toInt(),
      postId: j['postId'] is String ? j['postId'] as String : null,
      replyCount: (j['replyCount'] as num?)?.toInt() ?? 0,
      cw: j['cw'] is String && (j['cw'] as String).trim().isNotEmpty ? (j['cw'] as String).trim() : null,
      sensitive: j['sensitive'] == true,
      adSafe: j['adSafe'] is bool ? j['adSafe'] as bool : null,
      notified: (j['notified'] as num?)?.toInt(),
    );
  }
}

/// 作るときの中身。
@immutable
class NewSwing {
  const NewSwing({required this.kind, this.text = '', this.mediaId, this.plugin, this.audience = const SwingAudience(), this.ttlHours = 24, this.cw, this.sensitive = false, this.notify});
  final SwingKind kind;
  final String text;
  final String? mediaId;
  final SwingPlugin? plugin;
  final SwingAudience audience;
  final int ttlHours;

  /// 届け先のうち、RASQ の通知でも知らせる先(D-424 / Central S-079)。[audience] の中だけ。null / 空 = 送らない。
  final SwingAudience? notify;

  NewSwing withPlugin(SwingPlugin? p) => NewSwing(kind: kind, text: text, mediaId: mediaId, plugin: p, audience: audience, ttlHours: ttlHours, cw: cw, sensitive: sensitive, notify: notify);

  /// CW (D-395)。空なら送らない。
  final String? cw;
  final bool sensitive;

  Map<String, Object?> toJson() => {
        'kind': kind.wire,
        if (text.trim().isNotEmpty) 'text': text.trim(),
        'mediaId': ?mediaId,
        if (plugin != null) 'plugin': plugin!.toJson(),
        'audience': audience.toJson(),
        'ttlHours': ttlHours,
        if (cw != null && cw!.trim().isNotEmpty) 'cw': cw!.trim(),
        if (sensitive) 'sensitive': true,
        if (notify != null && !notify!.isEmpty) 'notify': notify!.toJson(),
      };
}

/// ビューワーに並べる順: 作った人ごとにまとめ(その人のいちばん新しい Swing が新しい順)、人の中は古い順。
List<Swing> orderForViewer(List<Swing> feed) {
  final byAuthor = <String, List<Swing>>{};
  for (final s in feed) {
    byAuthor.putIfAbsent(s.authorAccountId, () => []).add(s);
  }
  final groups = byAuthor.values.toList()
    ..sort((a, b) => b.map((s) => s.createdAt).reduce((x, y) => x.isAfter(y) ? x : y).compareTo(a.map((s) => s.createdAt).reduce((x, y) => x.isAfter(y) ? x : y)));
  return [
    for (final g in groups) ...(g..sort((a, b) => a.createdAt.compareTo(b.createdAt))),
  ];
}
