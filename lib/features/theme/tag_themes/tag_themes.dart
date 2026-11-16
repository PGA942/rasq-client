import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show ActionDescriptor;

import '../../../app/feature_flags.dart';
import '../../../backend/orgate_client.dart';
import '../../../text/mfm/mfm_node.dart';
import '../../../text/mfm/mfm_parser.dart';
import '../icon_theme/rasq_theme_spec.dart';
import '../icon_theme/theme_frames.dart';

/// ハッシュタグに付くテーマ (D-566): **コミュハッシュタグのテーマ**(D-567)と **RASQ Atmos**(D-568)が同じ形を使う。
///
/// - 1 件 = [TagThemeEntry](ハッシュタグ → [RasqThemeSpec])。見た目の中身は第3回のテーマのデータ(D-562)そのもの。
///   テーマフレームの SVG は ID で置き場から引き、どこから来ても [sanitizeThemeSvg](`SvgLite.parseStrict` と上限)を通す。
/// - 一覧は Central が配る(`GET /api/v1/tag-themes`、docs/TAG_THEMES.md)。**アプリはどのタグを見たかを送らない**:
///   有効な一覧をまるごと取り、手元で投稿のハッシュタグと突き合わせる。Atmos のインプレッションは、この一覧を
///   RASQ アプリへ配った回数としてサーバーが数える(端末の閲覧や操作は送らない)。
/// - 機能が無効([RasqFeatureFlags])なら取りに行かない(一覧は空)。

/// タグの比べ方: 先頭の `#` を除き、小文字にする(Misskey / Mastodon のハッシュタグは大文字小文字を区別しない)。
String normalizeHashtag(String tag) => tag.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase();

/// タグに使える形(空白・記号の無い 1〜64 字)。
bool isValidHashtag(String tag) {
  final t = normalizeHashtag(tag);
  return t.isNotEmpty && t.length <= 64 && !RegExp(r'''[\s#.,!?'"(){}\[\]<>:;/\\@]''').hasMatch(t);
}

enum TagThemeKind {
  /// コミュハッシュタグのテーマ(そのタグのページに効く)。
  community,

  /// RASQ Atmos(タグの付いた投稿の SVG アイコン・アクションのアニメーション・スレッドだけのテーマ)。
  atmos;

  RasqThemeSource get source => this == community ? RasqThemeSource.communityTag : RasqThemeSource.atmos;
}

/// 配られたテーマ 1 件。
@immutable
class TagThemeEntry {
  const TagThemeEntry({required this.id, required this.kind, required this.tag, required this.spec, this.thread = false, this.until});

  final String id;
  final TagThemeKind kind;

  /// [normalizeHashtag] した形。
  final String tag;

  /// `source` は [kind] のもの、`scope` は `hashtag(tag)` に揃えてある(サーバーの値は使わない)。
  final RasqThemeSpec spec;

  /// Atmos: そのタグの投稿のスレッドを開いたとき、そのスレッドの表示だけにテーマを付けるか。
  final bool thread;

  /// 配信の終わり(過ぎたものは使わない)。null = 決まっていない。
  final DateTime? until;

  static final idPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');

  bool activeAt(DateTime now) => until == null || now.isBefore(until!);

  /// SVG アイコン(`hashtagBadge`)のきっかけ。
  RasqThemeTrigger? get badge => spec.triggers.where((t) => t.kind == 'hashtagBadge').firstOrNull;

  /// アクション [action](ID か種類)で再生するアニメーション。
  RasqThemeTrigger? animationFor(ActionDescriptor action) {
    final id = action.id.toLowerCase(), genre = action.genreTag.toLowerCase();
    return spec.triggers.where((t) => t.kind == 'actionAnimation' && (t.actionId!.toLowerCase() == id || t.actionId!.toLowerCase() == genre)).firstOrNull;
  }

  Map<String, Object?> toJson() => {'id': id, 'kind': kind.name, 'tag': tag, 'theme': spec.toJson(), if (thread) 'thread': true, if (until != null) 'until': until!.toUtc().toIso8601String()};

  /// 読めないもの(形が違う / 知らない種類 / タグが不正 / テーマが読めない)は null。
  static TagThemeEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], tag = j['tag'];
    final kind = TagThemeKind.values.where((k) => k.name == j['kind']).firstOrNull;
    if (id is! String || !idPattern.hasMatch(id) || kind == null || tag is! String || !isValidHashtag(tag)) return null;
    final raw = RasqThemeSpec.fromJson(j['theme']);
    if (raw == null) return null;
    final t = normalizeHashtag(tag);
    final spec = raw.copyWith(
      source: kind.source,
      scope: RasqThemeScope.hashtag(t),
      frames: raw.frames.take(themeFramesMax).toList(),
      // コミュハッシュタグはきっかけを持たない。Atmos の SVG アイコンは、そのエントリのタグのものだけ。
      triggers: kind == TagThemeKind.community ? const [] : [for (final x in raw.triggers) if (x.kind != 'hashtagBadge' || normalizeHashtag(x.hashtag!) == t) x].take(8).toList(),
    );
    final until = j['until'] is String ? DateTime.tryParse(j['until'] as String) : null;
    return TagThemeEntry(id: id, kind: kind, tag: t, spec: spec, thread: kind == TagThemeKind.atmos && j['thread'] == true, until: until);
  }

  @override
  bool operator ==(Object other) => other is TagThemeEntry && other.id == id && other.kind == kind && other.tag == tag && other.spec == spec && other.thread == thread && other.until == until;
  @override
  int get hashCode => Object.hash(id, kind, tag, spec, thread, until);
}

/// 配られた一覧。
@immutable
class TagThemeCatalog {
  const TagThemeCatalog({this.entries = const [], this.refresh = const Duration(hours: 6)});
  static const empty = TagThemeCatalog();

  final List<TagThemeEntry> entries;

  /// 次に取り直すまで(サーバーが `refreshSeconds` で決める。15 分〜1 日)。
  final Duration refresh;

  /// 1 つの一覧に載せる上限(多すぎる分は捨てる)。
  static const maxEntries = 500;

  factory TagThemeCatalog.fromJson(Map<String, Object?> j) {
    final list = j['entries'];
    final secs = j['refreshSeconds'];
    final seen = <(TagThemeKind, String)>{};
    return TagThemeCatalog(
      entries: [
        for (final e in (list is List ? list : const []).take(maxEntries))
          // 同じ種類・同じタグは先のものだけ。
          if (TagThemeEntry.fromJson(e) case final x? when seen.add((x.kind, x.tag))) x,
      ],
      refresh: Duration(seconds: secs is int ? secs.clamp(15 * 60, 24 * 3600) : 6 * 3600),
    );
  }

  TagThemeEntry? find(TagThemeKind kind, String tag, {DateTime? now}) {
    final t = normalizeHashtag(tag), at = now ?? DateTime.now();
    return entries.where((e) => e.kind == kind && e.tag == t && e.activeAt(at)).firstOrNull;
  }

  /// [tags] のどれかに付いた Atmos(投稿のハッシュタグの順で最初のもの)。
  TagThemeEntry? atmosFor(Iterable<String> tags, {DateTime? now}) {
    for (final t in tags) {
      if (find(TagThemeKind.atmos, t, now: now) case final e?) return e;
    }
    return null;
  }

  bool get hasAtmos => entries.any((e) => e.kind == TagThemeKind.atmos);
}

/// 投稿の本文のハッシュタグ([normalizeHashtag] した形、出てきた順、重複なし)。表示と同じ MFM の読み方で拾う。
List<String> postHashtags(Post post) {
  final body = post.body;
  if (!body.contains('#') && !body.contains('＃')) return const [];
  final out = <String>[];
  void walk(List<MfmNode> nodes) {
    for (final n in nodes) {
      if (n.type == 'hashtag' && n.props?['hashtag'] is String) {
        final t = n.props!['hashtag'] as String;
        final x = normalizeHashtag(t);
        if (x.isNotEmpty && !out.contains(x)) out.add(x);
      }
      if (n.children case final c?) walk(c);
    }
  }

  try {
    walk(Mfm.parse(body));
  } catch (e) {
    debugPrint('postHashtags: $e');
  }
  return out;
}

// ── Central の口 (docs/TAG_THEMES.md) ──

/// 申請の状態。
enum CommunityTagState {
  /// 審査を待っている。
  pending,

  /// 通った(配信中)。
  approved,

  /// 断られた([CommunityTagApplication.reason])。
  rejected,

  /// サブスクが切れた / 宣伝の投稿が消えたなどで止まっている。
  suspended,

  /// 自分で取り下げた。
  withdrawn;

  static CommunityTagState fromWire(Object? w) => values.where((s) => s.name == w).firstOrNull ?? pending;
}

/// 申請 1 件。
@immutable
class CommunityTagApplication {
  const CommunityTagApplication({required this.id, required this.tag, required this.state, this.spec, this.promoUrl, this.reason, this.createdAt, this.decidedAt});
  final String id;
  final String tag;
  final CommunityTagState state;
  final RasqThemeSpec? spec;
  final Uri? promoUrl;

  /// 断られた / 止まった理由の名前(`promo_missing` / `tag_taken` / `subscription_inactive` / `theme_rejected` / `policy` …)。
  final String? reason;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  bool get open => state == CommunityTagState.pending || state == CommunityTagState.approved || state == CommunityTagState.suspended;

  factory CommunityTagApplication.fromJson(Map<String, Object?> j) => CommunityTagApplication(
        id: '${j['id'] ?? ''}',
        tag: normalizeHashtag('${j['tag'] ?? ''}'),
        state: CommunityTagState.fromWire(j['state']),
        spec: RasqThemeSpec.fromJson(j['theme']),
        promoUrl: j['promoUrl'] is String ? Uri.tryParse(j['promoUrl'] as String) : null,
        reason: j['reason'] is String ? j['reason'] as String : null,
        createdAt: j['createdAt'] is String ? DateTime.tryParse(j['createdAt'] as String) : null,
        decidedAt: j['decidedAt'] is String ? DateTime.tryParse(j['decidedAt'] as String) : null,
      );
}

/// 申請の画面に出す自分の状態。
@immutable
class CommunityTagStatus {
  const CommunityTagStatus({required this.subscribed, this.plan, this.applications = const [], this.limit = 1});

  /// サブスクに入っているか(サーバーが ORGATE の支払いで確かめた結果)。
  final bool subscribed;
  final String? plan;
  final List<CommunityTagApplication> applications;

  /// 同時に持てるタグの数。
  final int limit;

  int get openCount => applications.where((a) => a.open).length;
  bool get canApply => subscribed && openCount < limit;

  factory CommunityTagStatus.fromJson(Map<String, Object?> j) {
    final sub = j['subscription'];
    final apps = j['applications'];
    return CommunityTagStatus(
      subscribed: sub is Map && sub['active'] == true,
      plan: sub is Map && sub['plan'] is String ? sub['plan'] as String : null,
      applications: [for (final a in (apps is List ? apps : const [])) if (a is Map) CommunityTagApplication.fromJson(a.cast<String, Object?>())],
      limit: j['limit'] is int ? (j['limit'] as int).clamp(0, 20) : 1,
    );
  }
}

/// 申請に添える宣伝の投稿(自分の公開の投稿で、そのタグを含むもの)。
@immutable
class CommunityTagPromo {
  const CommunityTagPromo({required this.sns, required this.instance, required this.postId, this.url});
  final String sns;
  final String instance;
  final String postId;
  final Uri? url;

  factory CommunityTagPromo.of(Post p) => CommunityTagPromo(sns: p.account.kind.name, instance: p.account.instance, postId: p.id, url: p.url);
  Map<String, Object?> toJson() => {'sns': sns, 'instance': instance, 'postId': postId, if (url != null) 'url': '$url'};
}

class TagThemesApi {
  const TagThemesApi(this._client);
  final OrgateClient _client;

  /// 配信中の一覧。**トークンを付けずに**取る(誰に配ったかをサーバーに残さない)。どのタグを見たかも送らない。
  /// `via=app` = RASQ アプリへの配信(サーバーは、この回数を Atmos のインプレッションとして数える)。
  Future<TagThemeCatalog> catalog() async => TagThemeCatalog.fromJson(await _client.withToken(() => null).getJson('/tag-themes', const {'via': 'app'}));

  Future<CommunityTagStatus> mine() async => CommunityTagStatus.fromJson(await _client.getJson('/me/community-tags'));

  Future<CommunityTagApplication> apply({required String tag, required RasqThemeSpec spec, required CommunityTagPromo promo}) async {
    final res = await _client.postJson('/me/community-tags', {'tag': normalizeHashtag(tag), 'theme': spec.toJson(), 'promo': promo.toJson()});
    final app = res['application'];
    return CommunityTagApplication.fromJson(app is Map ? app.cast<String, Object?>() : res);
  }

  Future<void> withdraw(String id) => _client.delete('/me/community-tags/${Uri.encodeComponent(id)}');
}

/// 口(機能が無効 / Central が無ければ null)。
final tagThemesApiProvider = Provider<TagThemesApi?>((ref) {
  if (!ref.watch(featureFlagsProvider).anyTagThemes) return null;
  final c = ref.watch(centralClientProvider);
  return c == null ? null : TagThemesApi(c);
});

/// 配信中の一覧。無効なら空のまま(通信しない)。取れなければ空(飾りが出ないだけ)。サーバーの `refreshSeconds` ごとに取り直す。
final tagThemeCatalogProvider = FutureProvider<TagThemeCatalog>((ref) async {
  final api = ref.watch(tagThemesApiProvider);
  if (api == null) return TagThemeCatalog.empty;
  TagThemeCatalog catalog;
  try {
    catalog = await api.catalog();
  } catch (e) {
    debugPrint('tag themes: $e');
    catalog = TagThemeCatalog.empty;
  }
  final timer = Timer(catalog.refresh, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return catalog;
});

/// タグのコミュハッシュタグのテーマ(無効 / 無ければ null)。
final communityTagThemeProvider = Provider.family<TagThemeEntry?, String>((ref, tag) {
  if (!ref.watch(featureFlagsProvider).communityTagThemes) return null;
  return ref.watch(tagThemeCatalogProvider).value?.find(TagThemeKind.community, tag);
});

extension AtmosWidgetRef on WidgetRef {
  /// この投稿に付く Atmos(無効 / 無ければ null)。無効なら一覧も読まない(本文も読み直さない)。
  TagThemeEntry? watchAtmos(Post post) {
    if (!watch(featureFlagsProvider).atmos) return null;
    final catalog = watch(tagThemeCatalogProvider).value;
    if (catalog == null || !catalog.hasAtmos) return null;
    return catalog.atmosFor(_hashtagsOf(post));
  }
}

/// 投稿ごとのハッシュタグの控え(同じ投稿の組み立て直しで本文を読み直さない)。
final _hashtagCache = Expando<List<String>>('postHashtags');
List<String> _hashtagsOf(Post post) => _hashtagCache[post] ??= postHashtags(post);
