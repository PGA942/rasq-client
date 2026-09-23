import 'dart:convert';

import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

/// チャイルドセーフ v2 の制限(ポリシー)と、その署名 (D-307)。
///
/// 親(保護者)の RASQ アカウントが決め、Central が署名して子の端末へ渡す。**当てはめるのは子の端末**
/// (Central は投稿の中身を見ない)。このファイルは flutter の画面に依存しない(型 / 解釈 / 署名の検証だけ)。
///
/// - 形は `rasq.child-safe/2`。v1(`schema` が無い)もそのまま読める。`allow` が無ければ v1 と同じ
///   (タイムライン / コンポーザー / 時間 / 1 日の投稿数だけ。ほかは止めない)。
/// - 署名: `base64(ed25519(sha512(canonical_json({childAccountId, revision, settings, issuedAt}))))`。鍵は
///   **ストアの鍵**(`.rasqpkg` のストア署名と同じ)。canonical JSON = キーを再帰的に並べ替え、空白なし、UTF-8。

/// 判定の強さ。タイムラインは [stimulusThreshold] 以上の刺激性(強い言葉)を落とし、コンポーザーは送らない。
enum ChildSafeLevel {
  strict('strict', 'きびしめ', 0.3),
  standard('standard', 'ふつう', 0.5),
  mild('mild', 'ゆるめ', 0.8);

  const ChildSafeLevel(this.wire, this.label, this.stimulusThreshold);
  final String wire;
  final String label;

  /// [TendencyScorer.stimulusPenaltyOf] と比べる閾値(以上なら止める)。
  final double stimulusThreshold;
  static ChildSafeLevel fromWire(Object? w) => values.where((l) => l.wire == w).firstOrNull ?? strict;
}

/// 年齢の帯 (13-15 / 16-17 / 18+)。カタログの `presets` のキー。
const childSafeAgeBands = ['13-15', '16-17', '18+'];

/// RAi の関数のまとまり。第二期のもの([childSafeRaiPhase2Groups])は、いまは選べるだけ。
const childSafeRaiGroups = ['rai.guide', 'rai.read', 'rai.compose', 'rai.act', 'rai.settings', 'rai.astell', 'rai.web'];
const childSafeRaiPhase2Groups = ['rai.assistant', 'rai.macro', 'rai.automation'];

List<String> _strings(Object? v) => [for (final e in v is List ? v : const []) if (e is String && e.trim().isNotEmpty) e.trim()];
Map<String, bool> _bools(Object? v) => {for (final e in (v is Map ? v : const {}).entries) if (e.value is bool) '${e.key}': e.value as bool};
Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

@immutable
class ChildSafeTimeline {
  const ChildSafeTimeline({this.enabled = false, this.level = ChildSafeLevel.strict, this.blockedTopics = const []});
  final bool enabled;
  final ChildSafeLevel level;
  final List<String> blockedTopics;
  factory ChildSafeTimeline.fromJson(Map<String, Object?> j) => ChildSafeTimeline(enabled: j['enabled'] == true, level: ChildSafeLevel.fromWire(j['level']), blockedTopics: _strings(j['blockedTopics']));
  Map<String, Object?> toJson() => {'enabled': enabled, 'level': level.wire, 'blockedTopics': blockedTopics};
  ChildSafeTimeline copyWith({bool? enabled, ChildSafeLevel? level, List<String>? blockedTopics}) =>
      ChildSafeTimeline(enabled: enabled ?? this.enabled, level: level ?? this.level, blockedTopics: blockedTopics ?? this.blockedTopics);
}

@immutable
class ChildSafeComposer {
  const ChildSafeComposer({this.enabled = false, this.level = ChildSafeLevel.strict});
  final bool enabled;
  final ChildSafeLevel level;
  factory ChildSafeComposer.fromJson(Map<String, Object?> j) => ChildSafeComposer(enabled: j['enabled'] == true, level: ChildSafeLevel.fromWire(j['level']));
  Map<String, Object?> toJson() => {'enabled': enabled, 'level': level.wire};
  ChildSafeComposer copyWith({bool? enabled, ChildSafeLevel? level}) => ChildSafeComposer(enabled: enabled ?? this.enabled, level: level ?? this.level);
}

/// 見守りの時間。`start` / `end` = `HH:MM`(**子の端末の時計**)。`end` が早ければ次の日まで。
@immutable
class ChildSafeTime {
  const ChildSafeTime({this.enabled = false, this.start = '21:00', this.end = '06:00', this.allowedTopics = const [], this.hideNotifications = true, this.hidePostDetail = false, this.hideDirectMessages = true});
  final bool enabled;
  final String start;
  final String end;
  final List<String> allowedTopics;
  final bool hideNotifications;
  final bool hidePostDetail;
  final bool hideDirectMessages;

  static int? minutesOf(String hhmm) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(hhmm.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!), min = int.parse(m.group(2)!);
    if (h > 23 || min > 59) return null;
    return h * 60 + min;
  }

  /// [now] が見守りの時間の中か。`start == end` / 読めない時刻は「無し」。
  bool contains(DateTime now) {
    if (!enabled) return false;
    final s = minutesOf(start), e = minutesOf(end);
    if (s == null || e == null || s == e) return false;
    final m = now.hour * 60 + now.minute;
    return s < e ? (m >= s && m < e) : (m >= s || m < e);
  }

  /// 次に「中 / 外」が切り替わる時刻(時計を進めて画面を作り直すため)。無ければ null。
  DateTime? nextBoundary(DateTime now) {
    if (!enabled) return null;
    final s = minutesOf(start), e = minutesOf(end);
    if (s == null || e == null || s == e) return null;
    DateTime at(int minutes, int dayOffset) => DateTime(now.year, now.month, now.day + dayOffset, minutes ~/ 60, minutes % 60);
    final candidates = [for (final d in const [0, 1]) for (final x in [s, e]) at(x, d)]..sort();
    return candidates.firstWhere((t) => t.isAfter(now), orElse: () => at(s, 1));
  }

  factory ChildSafeTime.fromJson(Map<String, Object?> j) => ChildSafeTime(
        enabled: j['enabled'] == true,
        start: j['start'] as String? ?? '21:00',
        end: j['end'] as String? ?? '06:00',
        allowedTopics: _strings(j['allowedTopics']),
        hideNotifications: j['hideNotifications'] != false,
        hidePostDetail: j['hidePostDetail'] == true,
        hideDirectMessages: j['hideDirectMessages'] != false,
      );
  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'start': start,
        'end': end,
        'allowedTopics': allowedTopics,
        'hideNotifications': hideNotifications,
        'hidePostDetail': hidePostDetail,
        'hideDirectMessages': hideDirectMessages,
      };
  ChildSafeTime copyWith({bool? enabled, String? start, String? end, List<String>? allowedTopics, bool? hideNotifications, bool? hidePostDetail, bool? hideDirectMessages}) => ChildSafeTime(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        end: end ?? this.end,
        allowedTopics: allowedTopics ?? this.allowedTopics,
        hideNotifications: hideNotifications ?? this.hideNotifications,
        hidePostDetail: hidePostDetail ?? this.hidePostDetail,
        hideDirectMessages: hideDirectMessages ?? this.hideDirectMessages,
      );
}

/// 使ってよい SNS。`kinds` が空 = どれも使えない。`instances` が空 = その種類ならどのサーバーでも。
@immutable
class ChildSafeSnsAllow {
  const ChildSafeSnsAllow({this.kinds = const [], this.instances = const [], this.addAccounts = false});
  final List<String> kinds;
  final List<String> instances;
  final bool addAccounts;
  bool permits(String kind, String instance) => kinds.contains(kind) && (instances.isEmpty || instances.contains(instance.toLowerCase()));
  factory ChildSafeSnsAllow.fromJson(Map<String, Object?> j) =>
      ChildSafeSnsAllow(kinds: _strings(j['kinds']), instances: [for (final i in _strings(j['instances'])) i.toLowerCase()], addAccounts: j['addAccounts'] == true);
  Map<String, Object?> toJson() => {'kinds': kinds, 'instances': instances, 'addAccounts': addAccounts};
  ChildSafeSnsAllow copyWith({List<String>? kinds, List<String>? instances, bool? addAccounts}) =>
      ChildSafeSnsAllow(kinds: kinds ?? this.kinds, instances: instances ?? this.instances, addAccounts: addAccounts ?? this.addAccounts);
}

/// プラグインのインストール: `none`(入れられない)/ `listed`(`ids` のものだけ)/ `any`。
enum ChildSafeInstall {
  none('none', '入れられない'),
  listed('listed', '選んだものだけ'),
  any('any', '自由');

  const ChildSafeInstall(this.wire, this.label);
  final String wire;
  final String label;
  static ChildSafeInstall fromWire(Object? w) => values.where((v) => v.wire == w).firstOrNull ?? none;
}

/// 使ってよいプラグイン。`ids` = 使ってよいプラグイン(入っていても、ここに無ければ呼ばない)。
/// `slots` = スロットごとの可否(書いていないスロットは可)。
@immutable
class ChildSafePluginsAllow {
  const ChildSafePluginsAllow({this.ids = const [], this.slots = const {}, this.install = ChildSafeInstall.none});
  final List<String> ids;
  final Map<String, bool> slots;
  final ChildSafeInstall install;
  bool permits(String pluginId, String slot) => ids.contains(pluginId) && slots[slot] != false;
  factory ChildSafePluginsAllow.fromJson(Map<String, Object?> j) => ChildSafePluginsAllow(ids: _strings(j['ids']), slots: _bools(j['slots']), install: ChildSafeInstall.fromWire(j['install']));
  Map<String, Object?> toJson() => {'ids': ids, 'slots': slots, 'install': install.wire};
  ChildSafePluginsAllow copyWith({List<String>? ids, Map<String, bool>? slots, ChildSafeInstall? install}) =>
      ChildSafePluginsAllow(ids: ids ?? this.ids, slots: slots ?? this.slots, install: install ?? this.install);
}

/// RAi。`groups` = 使ってよいまとまり、`deny` = まとまりの中でも止める関数(またはまとまり)。
@immutable
class ChildSafeRaiAllow {
  const ChildSafeRaiAllow({this.enabled = true, this.groups = const [], this.deny = const [], this.automation = false});
  final bool enabled;
  final List<String> groups;
  final List<String> deny;
  final bool automation;
  factory ChildSafeRaiAllow.fromJson(Map<String, Object?> j) => ChildSafeRaiAllow(enabled: j['enabled'] != false, groups: _strings(j['groups']), deny: _strings(j['deny']), automation: j['automation'] == true);
  Map<String, Object?> toJson() => {'enabled': enabled, 'groups': groups, 'deny': deny, 'automation': automation};
  ChildSafeRaiAllow copyWith({bool? enabled, List<String>? groups, List<String>? deny, bool? automation}) =>
      ChildSafeRaiAllow(enabled: enabled ?? this.enabled, groups: groups ?? this.groups, deny: deny ?? this.deny, automation: automation ?? this.automation);
}

/// `allow`: 書いてある面だけを絞る(書いていない面 = 止めない)。
@immutable
class ChildSafeAllow {
  const ChildSafeAllow({this.sns, this.plugins, this.features, this.search, this.rai});
  final ChildSafeSnsAllow? sns;
  final ChildSafePluginsAllow? plugins;

  /// 機能 id → 可否(`dm` / `astell.join` …)。書いていない機能は可。
  final Map<String, bool>? features;

  /// 検索の種類 id → 可否(`posts` / `users` / `trend` / `store` / `web`)。書いていない種類は可。
  final Map<String, bool>? search;
  final ChildSafeRaiAllow? rai;

  factory ChildSafeAllow.fromJson(Map<String, Object?> j) => ChildSafeAllow(
        sns: j['sns'] is Map ? ChildSafeSnsAllow.fromJson(_map(j['sns'])) : null,
        plugins: j['plugins'] is Map ? ChildSafePluginsAllow.fromJson(_map(j['plugins'])) : null,
        features: j['features'] is Map ? _bools(j['features']) : null,
        search: j['search'] is Map ? _bools(j['search']) : null,
        rai: j['rai'] is Map ? ChildSafeRaiAllow.fromJson(_map(j['rai'])) : null,
      );
  Map<String, Object?> toJson() => {
        if (sns != null) 'sns': sns!.toJson(),
        if (plugins != null) 'plugins': plugins!.toJson(),
        if (features != null) 'features': features,
        if (search != null) 'search': search,
        if (rai != null) 'rai': rai!.toJson(),
      };
  ChildSafeAllow copyWith({ChildSafeSnsAllow? sns, ChildSafePluginsAllow? plugins, Map<String, bool>? features, Map<String, bool>? search, ChildSafeRaiAllow? rai}) =>
      ChildSafeAllow(sns: sns ?? this.sns, plugins: plugins ?? this.plugins, features: features ?? this.features, search: search ?? this.search, rai: rai ?? this.rai);
}

/// 制限の全体(`rasq.child-safe/2`)。
@immutable
class ChildSafePolicy {
  const ChildSafePolicy({
    this.schema = schemaV2,
    this.preset,
    this.timeline = const ChildSafeTimeline(),
    this.composer = const ChildSafeComposer(),
    this.time = const ChildSafeTime(),
    this.postsPerDay,
    this.allow,
    this.catalogVersion,
  });

  static const schemaV2 = 'rasq.child-safe/2';
  final String schema;

  /// 元にした強さ(`strict` / `standard` / `mild`)。表示と編集の目安だけ。
  final String? preset;
  final ChildSafeTimeline timeline;
  final ChildSafeComposer composer;
  final ChildSafeTime time;

  /// 1 日に送れる投稿の数。null = 決めない。
  final int? postsPerDay;

  /// null = v1 と同じ(ほかの面は止めない)。
  final ChildSafeAllow? allow;
  final int? catalogVersion;

  factory ChildSafePolicy.fromJson(Map<String, Object?> j) {
    final ppd = j['postsPerDay'];
    return ChildSafePolicy(
      schema: j['schema'] as String? ?? 'rasq.child-safe/1',
      preset: j['preset'] as String?,
      timeline: ChildSafeTimeline.fromJson(_map(j['timeline'])),
      composer: ChildSafeComposer.fromJson(_map(j['composer'])),
      time: ChildSafeTime.fromJson(_map(j['time'])),
      postsPerDay: ppd is num ? ppd.toInt().clamp(0, 1000) : null,
      allow: j['allow'] is Map ? ChildSafeAllow.fromJson(_map(j['allow'])) : null,
      catalogVersion: (_map(j['source'])['catalogVersion'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toJson() => {
        'schema': schemaV2,
        if (preset != null) 'preset': preset,
        'timeline': timeline.toJson(),
        'composer': composer.toJson(),
        'time': time.toJson(),
        'postsPerDay': postsPerDay,
        if (allow != null) 'allow': allow!.toJson(),
        'source': {'catalogVersion': ?catalogVersion},
      };

  ChildSafePolicy copyWith({String? preset, ChildSafeTimeline? timeline, ChildSafeComposer? composer, ChildSafeTime? time, int? postsPerDay, bool clearPostsPerDay = false, ChildSafeAllow? allow, int? catalogVersion}) => ChildSafePolicy(
        preset: preset ?? this.preset,
        timeline: timeline ?? this.timeline,
        composer: composer ?? this.composer,
        time: time ?? this.time,
        postsPerDay: clearPostsPerDay ? null : (postsPerDay ?? this.postsPerDay),
        allow: allow ?? this.allow,
        catalogVersion: catalogVersion ?? this.catalogVersion,
      );

  /// 強さを選び直す(タイムラインとコンポーザーの判定の強さを揃える)。
  ChildSafePolicy withPreset(ChildSafeLevel level) => copyWith(preset: level.wire, timeline: timeline.copyWith(level: level), composer: composer.copyWith(level: level));
}

// ── カタログ ───────────────────────────────────────────────────────────

@immutable
class ChildSafeCatalogItem {
  const ChildSafeCatalogItem(this.id, this.label, {this.phase = 1});
  final String id;
  final String label;

  /// RAi のまとまりの期(2 = 第二期。いまは選べるだけ)。
  final int phase;
  factory ChildSafeCatalogItem.fromJson(Map<String, Object?> j) => ChildSafeCatalogItem('${j['id'] ?? ''}', '${j['label'] ?? j['id'] ?? ''}', phase: (j['phase'] as num?)?.toInt() ?? 1);
}

/// `GET /me/child-safe/catalog`: 選べる機能 / 検索の種類 / RAi のまとまりと、年齢の帯ごとの既定。
@immutable
class ChildSafeCatalog {
  const ChildSafeCatalog({required this.version, required this.features, required this.search, required this.raiGroups, required this.presets});
  final int version;
  final List<ChildSafeCatalogItem> features;
  final List<ChildSafeCatalogItem> search;
  final List<ChildSafeCatalogItem> raiGroups;

  /// 年齢の帯 → 既定の制限(JSON のまま)。
  final Map<String, Map<String, Object?>> presets;

  ChildSafePolicy presetFor(String band) => ChildSafePolicy.fromJson(presets[band] ?? presets['13-15'] ?? fallback.presets['13-15']!).copyWith(catalogVersion: version);

  factory ChildSafeCatalog.fromJson(Map<String, Object?> j) {
    List<ChildSafeCatalogItem> items(Object? v) => [for (final e in v is List ? v : const []) if (e is Map) ChildSafeCatalogItem.fromJson(e.cast<String, Object?>())];
    final presets = {for (final e in _map(j['presets']).entries) if (e.value is Map) e.key: (e.value as Map).cast<String, Object?>()};
    return ChildSafeCatalog(
      version: (j['version'] as num?)?.toInt() ?? 1,
      features: items(j['features']),
      search: items(j['search']),
      raiGroups: items(j['raiGroups']),
      presets: presets.isEmpty ? fallback.presets : presets,
    );
  }

  /// サーバーから取れないとき(オフライン / 古い Central)の控え。Central の既定と同じ考え方
  /// (13-15 = きびしめ、16-17 = ふつう、18+ = ゆるめ)。
  static final fallback = ChildSafeCatalog(
    version: 1,
    features: const [
      ChildSafeCatalogItem('dm', 'DM'),
      ChildSafeCatalogItem('astell.join', 'AsTell への参加'),
      ChildSafeCatalogItem('astell.create', 'AsTell ルームの作成'),
      ChildSafeCatalogItem('astell.share', 'AsTell での共有・チャット'),
      ChildSafeCatalogItem('astell.stream', 'AsTell の画面共有・配信'),
      ChildSafeCatalogItem('reaction', 'リアクション'),
      ChildSafeCatalogItem('post.media', 'メディア付き投稿'),
      ChildSafeCatalogItem('account.follow', 'RASQ アカウントのフォロー'),
      ChildSafeCatalogItem('store.review', 'ストアのレビュー投稿'),
    ],
    search: const [
      ChildSafeCatalogItem('posts', '投稿'),
      ChildSafeCatalogItem('users', 'ユーザー'),
      ChildSafeCatalogItem('trend', 'トレンド'),
      ChildSafeCatalogItem('store', 'プラグインストア'),
      ChildSafeCatalogItem('web', 'web 検索'),
    ],
    raiGroups: const [
      ChildSafeCatalogItem('rai.guide', '操作の案内'),
      ChildSafeCatalogItem('rai.read', '読む(TL / 投稿 / ユーザー)'),
      ChildSafeCatalogItem('rai.compose', '下書きを書く'),
      ChildSafeCatalogItem('rai.act', 'アクション(フォロー / リスト / クリップ)'),
      ChildSafeCatalogItem('rai.settings', '設定を変える'),
      ChildSafeCatalogItem('rai.astell', 'AsTell'),
      ChildSafeCatalogItem('rai.web', 'web 検索'),
      ChildSafeCatalogItem('rai.assistant', 'アシスタント', phase: 2),
      ChildSafeCatalogItem('rai.macro', 'マクロ', phase: 2),
      ChildSafeCatalogItem('rai.automation', '自動化', phase: 2),
    ],
    presets: {
      '13-15': _preset('strict', time: true, start: '21:00', postsPerDay: 10, addAccounts: false, install: 'none', features: {'dm': false, 'astell.join': false, 'astell.create': false, 'astell.stream': false}, search: {'posts': true, 'users': false, 'trend': true, 'store': false, 'web': false}, rai: ['rai.guide', 'rai.read', 'rai.compose'], automation: false),
      '16-17': _preset('standard', time: true, start: '23:00', postsPerDay: 30, addAccounts: false, install: 'listed', features: {'dm': true, 'astell.join': true, 'astell.create': false, 'astell.stream': false}, search: {'posts': true, 'users': true, 'trend': true, 'store': true, 'web': false}, rai: ['rai.guide', 'rai.read', 'rai.compose', 'rai.act', 'rai.settings'], automation: false),
      '18+': _preset('mild', time: false, start: '23:00', postsPerDay: null, addAccounts: true, install: 'any', features: {'dm': true, 'astell.join': true, 'astell.create': true, 'astell.stream': true}, search: {'posts': true, 'users': true, 'trend': true, 'store': true, 'web': true}, rai: childSafeRaiGroups, automation: true),
    },
  );

  static Map<String, Object?> _preset(String level, {required bool time, required String start, required int? postsPerDay, required bool addAccounts, required String install, required Map<String, bool> features, required Map<String, bool> search, required List<String> rai, required bool automation}) => {
        'schema': ChildSafePolicy.schemaV2,
        'preset': level,
        'timeline': {'enabled': true, 'level': level, 'blockedTopics': <String>[]},
        'composer': {'enabled': true, 'level': level},
        'time': {'enabled': time, 'start': start, 'end': '06:00', 'allowedTopics': <String>[], 'hideNotifications': true, 'hidePostDetail': false, 'hideDirectMessages': true},
        'postsPerDay': postsPerDay,
        'allow': {
          'sns': {'kinds': <String>[], 'instances': <String>[], 'addAccounts': addAccounts},
          'plugins': {'ids': <String>[], 'slots': <String, bool>{}, 'install': install},
          'features': features,
          'search': search,
          'rai': {'enabled': true, 'groups': rai, 'deny': <String>[], 'automation': automation},
        },
        'source': {'catalogVersion': 1},
      };
}

// ── RAi の関数のまとまり ─────────────────────────────────────────────────

/// [RaiFunctionRunner.run] が実行できる関数 → まとまり。**ここに無い関数は、見守り中は呼べない**。
/// 送信の別名(`post.create` など、自動化不可 → 下書きへ置き換える)は、置き換え先と同じまとまり。
const raiFunctionGroups = <String, String>{
  'reference.get': 'rai.guide',
  'app.actions': 'rai.guide',
  'posts.fetch': 'rai.read',
  'page.read': 'rai.read',
  'timeline.list': 'rai.read',
  'post.get': 'rai.read',
  'post.thread': 'rai.read',
  'post.reactions': 'rai.read',
  'post.reposters': 'rai.read',
  'post.quotes': 'rai.read',
  'favorites.list': 'rai.read',
  'reacted.list': 'rai.read',
  'me.get': 'rai.read',
  'user.get': 'rai.read',
  'user.posts': 'rai.read',
  'user.search': 'rai.read',
  'user.follows': 'rai.read',
  'user.relation': 'rai.read',
  'moderation.list': 'rai.read',
  'notifications.list': 'rai.read',
  'trends.tags': 'rai.read',
  'lists.list': 'rai.read',
  'lists.members': 'rai.read',
  'clips.list': 'rai.read',
  'clips.notes': 'rai.read',
  'feeds.list': 'rai.read',
  'dm.rooms': 'rai.read',
  'emoji.find': 'rai.read',
  'post.compose': 'rai.compose',
  'post.reply': 'rai.compose',
  'post.quote': 'rai.compose',
  'dm.compose': 'rai.compose',
  'post.create': 'rai.compose',
  'post.send': 'rai.compose',
  'dm.send': 'rai.compose',
  'post.reply.send': 'rai.compose',
  'post.action': 'rai.act',
  'notifications.read': 'rai.act',
  'follow.set': 'rai.act',
  'list.edit': 'rai.act',
  'list.create': 'rai.act',
  'clip.edit': 'rai.act',
  'clip.create': 'rai.act',
  'feed.save': 'rai.act',
  'settings.get': 'rai.settings',
  'settings.set': 'rai.settings',
  'timeline.addFeed': 'rai.settings',
  'timeline.excludeWord': 'rai.settings',
  'timeline.filterWord': 'rai.settings',
  'tendency.seed': 'rai.settings',
  'astell.rooms': 'rai.astell',
  'astell.create': 'rai.astell',
  'web.search': 'rai.web',
};

// ── 署名 ───────────────────────────────────────────────────────────────

/// canonical JSON: オブジェクトのキーを再帰的に並べ替え、空白を入れない。文字列の書き方は
/// `jsonEncode` と同じ(`"` `\` と制御文字だけをエスケープし、ほかは UTF-8 のまま)。
String canonicalJson(Object? v) {
  if (v is Map) {
    final keys = [for (final k in v.keys) '$k']..sort();
    return '{${[for (final k in keys) '${jsonEncode(k)}:${canonicalJson(v[k])}'].join(',')}}';
  }
  if (v is List) return '[${[for (final e in v) canonicalJson(e)].join(',')}]';
  return jsonEncode(v);
}

/// 署名の対象(SHA-512 の生 64 バイト)。
Uint8List childSafeSigningDigest({required String childAccountId, required int revision, required Object? settings, required String issuedAt}) =>
    Uint8List.fromList(sha512.convert(utf8.encode(canonicalJson({'childAccountId': childAccountId, 'revision': revision, 'settings': settings, 'issuedAt': issuedAt}))).bytes);

/// 署名を確かめる。鍵 / 署名が読めない・長さが違う・合わない、はどれも false。
Future<bool> verifyChildSafeSignature({required String publicKey, required String signature, required String childAccountId, required int revision, required Object? settings, required String issuedAt}) async {
  try {
    final key = base64Decode(publicKey);
    final sig = base64Decode(signature);
    if (key.length != 32 || sig.length != 64) return false;
    final digest = childSafeSigningDigest(childAccountId: childAccountId, revision: revision, settings: settings, issuedAt: issuedAt);
    return await Ed25519().verify(digest, signature: Signature(sig, publicKey: SimplePublicKey(key, type: KeyPairType.ed25519)));
  } catch (_) {
    return false;
  }
}
