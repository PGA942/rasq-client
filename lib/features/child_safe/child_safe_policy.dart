import 'dart:convert';

import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

import '../trend/example_match.dart';

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

/// 保護者が作れる子のアカウントの帯(Central の `POST /me/child-safe/children` は 13-15 / 16-17 だけ)。
const childSafeChildBands = ['13-15', '16-17'];

/// RAi の関数のまとまり。第二期のもの([childSafeRaiPhase2Groups])は、いまは選べるだけ。
const childSafeRaiGroups = ['rai.guide', 'rai.read', 'rai.compose', 'rai.act', 'rai.settings', 'rai.astell', 'rai.web'];
const childSafeRaiPhase2Groups = ['rai.assistant', 'rai.macro', 'rai.automation'];

List<String> _strings(Object? v) => [for (final e in v is List ? v : const []) if (e is String && e.trim().isNotEmpty) e.trim()];
Map<String, bool> _bools(Object? v) => {for (final e in (v is Map ? v : const {}).entries) if (e.value is bool) '${e.key}': e.value as bool};
Map<String, Object?> _map(Object? v) => v is Map ? v.cast<String, Object?>() : const {};

/// 話題の一覧の見方 (D-315): ホワイトリスト(どれかの話題に当たるものだけ)/ ブラックリスト(当たるものを止める)。
enum ChildSafeTopicMode {
  allow('allow', 'ホワイトリスト'),
  deny('deny', 'ブラックリスト');

  const ChildSafeTopicMode(this.wire, this.label);
  final String wire;
  final String label;
  static ChildSafeTopicMode? fromWire(Object? w) => values.where((m) => m.wire == w).firstOrNull;
}

/// 面(タイムライン / 投稿 / 見守りの時間)ごとの話題の一覧 (D-315)。Central `docs/API.md` の「話題の一覧」。
///
/// - 新しい形: `topicMode`(`allow` / `deny`)+ `topics`。アプリはいつもこの形で書く([toJson])。
/// - もとの形: `timeline.blockedTopics`(= ブラックリスト)/ `time.allowedTopics`(= ホワイトリスト)。子の端末は両方を読む
///   (新しい形があればそれ)。**もとの形の空のホワイトリスト**(時間)は、いままでどおり「何も流さない」。新しい形の
///   空のホワイトリストは、面が有効なら Central が受け付けない([childSafeTopicErrors])。
@immutable
class ChildSafeTopics {
  const ChildSafeTopics({this.mode = ChildSafeTopicMode.deny, this.topics = const [], this.legacy = false});
  final ChildSafeTopicMode mode;
  final List<String> topics;

  /// もとの形(`blockedTopics` / `allowedTopics`、どちらも無い面を含む)から読んだ。
  final bool legacy;

  bool get allow => mode == ChildSafeTopicMode.allow;

  /// 空のホワイトリスト(面が有効なら、新しい形では保存できない)。
  bool get isEmptyWhitelist => allow && topics.isEmpty;

  /// 目印(TL を作り直す判断に使う)。
  String get signature => '${mode.wire}:${topics.join(',')}';

  /// [j] の面から読む。[legacyKey] = もとの欄(無ければ null)、[legacyMode] = もとの欄の見方。
  factory ChildSafeTopics.read(Map<String, Object?> j, {String? legacyKey, ChildSafeTopicMode legacyMode = ChildSafeTopicMode.deny}) {
    if (j.containsKey('topicMode') || j.containsKey('topics')) {
      return ChildSafeTopics(mode: ChildSafeTopicMode.fromWire(j['topicMode']) ?? legacyMode, topics: _strings(j['topics']));
    }
    return ChildSafeTopics(mode: legacyMode, topics: legacyKey == null ? const [] : _strings(j[legacyKey]), legacy: true);
  }

  Map<String, Object?> toJson() => {'topicMode': mode.wire, 'topics': topics};
  ChildSafeTopics copyWith({ChildSafeTopicMode? mode, List<String>? topics}) => ChildSafeTopics(mode: mode ?? this.mode, topics: topics ?? this.topics);

  @override
  bool operator ==(Object other) => other is ChildSafeTopics && other.mode == mode && other.legacy == legacy && listEquals(other.topics, topics);
  @override
  int get hashCode => Object.hash(mode, legacy, Object.hashAll(topics));
}

@immutable
class ChildSafeTimeline {
  const ChildSafeTimeline({this.enabled = false, this.level = ChildSafeLevel.strict, this.topics = const ChildSafeTopics()});
  final bool enabled;
  final ChildSafeLevel level;

  /// 流す / 見せない話題(もとの形 `blockedTopics` = ブラックリスト)。
  final ChildSafeTopics topics;
  factory ChildSafeTimeline.fromJson(Map<String, Object?> j) =>
      ChildSafeTimeline(enabled: j['enabled'] == true, level: ChildSafeLevel.fromWire(j['level']), topics: ChildSafeTopics.read(j, legacyKey: 'blockedTopics'));
  Map<String, Object?> toJson() => {'enabled': enabled, 'level': level.wire, ...topics.toJson()};
  ChildSafeTimeline copyWith({bool? enabled, ChildSafeLevel? level, ChildSafeTopics? topics}) =>
      ChildSafeTimeline(enabled: enabled ?? this.enabled, level: level ?? this.level, topics: topics ?? this.topics);
}

@immutable
class ChildSafeComposer {
  const ChildSafeComposer({this.enabled = false, this.level = ChildSafeLevel.strict, this.topics = const ChildSafeTopics()});
  final bool enabled;
  final ChildSafeLevel level;

  /// 送れる / 送れない話題 (D-315。もとの形は無い: 無い = 話題では止めない)。
  final ChildSafeTopics topics;
  factory ChildSafeComposer.fromJson(Map<String, Object?> j) => ChildSafeComposer(enabled: j['enabled'] == true, level: ChildSafeLevel.fromWire(j['level']), topics: ChildSafeTopics.read(j));
  Map<String, Object?> toJson() => {'enabled': enabled, 'level': level.wire, ...topics.toJson()};
  ChildSafeComposer copyWith({bool? enabled, ChildSafeLevel? level, ChildSafeTopics? topics}) =>
      ChildSafeComposer(enabled: enabled ?? this.enabled, level: level ?? this.level, topics: topics ?? this.topics);
}

/// 見守りの時間。`start` / `end` = `HH:MM`(**子の端末の時計**)。`end` が早ければ次の日まで。
@immutable
class ChildSafeTime {
  const ChildSafeTime({this.enabled = false, this.start = '21:00', this.end = '06:00', this.topics = const ChildSafeTopics(), this.hideNotifications = true, this.hidePostDetail = false, this.hideDirectMessages = true});
  final bool enabled;
  final String start;
  final String end;

  /// その間に流す / 流さない話題(もとの形 `allowedTopics` = ホワイトリスト。もとの形だけ、空 = 何も流さない)。
  final ChildSafeTopics topics;
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
        topics: ChildSafeTopics.read(j, legacyKey: 'allowedTopics', legacyMode: ChildSafeTopicMode.allow),
        hideNotifications: j['hideNotifications'] != false,
        hidePostDetail: j['hidePostDetail'] == true,
        hideDirectMessages: j['hideDirectMessages'] != false,
      );
  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'start': start,
        'end': end,
        ...topics.toJson(),
        'hideNotifications': hideNotifications,
        'hidePostDetail': hidePostDetail,
        'hideDirectMessages': hideDirectMessages,
      };
  ChildSafeTime copyWith({bool? enabled, String? start, String? end, ChildSafeTopics? topics, bool? hideNotifications, bool? hidePostDetail, bool? hideDirectMessages}) => ChildSafeTime(
        enabled: enabled ?? this.enabled,
        start: start ?? this.start,
        end: end ?? this.end,
        topics: topics ?? this.topics,
        hideNotifications: hideNotifications ?? this.hideNotifications,
        hidePostDetail: hidePostDetail ?? this.hidePostDetail,
        hideDirectMessages: hideDirectMessages ?? this.hideDirectMessages,
      );
}

/// 使ってよい SNS。`kinds` / `instances` が空 = その軸では絞らない(Central `docs/API.md`)。
@immutable
class ChildSafeSnsAllow {
  const ChildSafeSnsAllow({this.kinds = const [], this.instances = const [], this.addAccounts = false});
  final List<String> kinds;
  final List<String> instances;
  final bool addAccounts;
  bool permits(String kind, String instance) => (kinds.isEmpty || kinds.contains(kind.toLowerCase())) && (instances.isEmpty || instances.contains(instance.toLowerCase()));
  factory ChildSafeSnsAllow.fromJson(Map<String, Object?> j) =>
      ChildSafeSnsAllow(kinds: _strings(j['kinds']), instances: [for (final i in _strings(j['instances'])) i.toLowerCase()], addAccounts: j['addAccounts'] == true);
  Map<String, Object?> toJson() => {'kinds': kinds, 'instances': instances, 'addAccounts': addAccounts};
  ChildSafeSnsAllow copyWith({List<String>? kinds, List<String>? instances, bool? addAccounts}) =>
      ChildSafeSnsAllow(kinds: kinds ?? this.kinds, instances: instances ?? this.instances, addAccounts: addAccounts ?? this.addAccounts);
}

/// プラグインのインストール: `none`(入れられない)/ `listed`(`ids` のものだけ)/ `any` /
/// `examples`(`ids` のものと、許す例に近く止める例に近くないもの。D-314)。
enum ChildSafeInstall {
  none('none', '入れられない'),
  listed('listed', '選んだものだけ'),
  any('any', '自由'),
  examples('examples', '例に近いもの');

  const ChildSafeInstall(this.wire, this.label);
  final String wire;
  final String label;
  static ChildSafeInstall fromWire(Object? w) => values.where((v) => v.wire == w).firstOrNull ?? none;
}

/// 使ってよいプラグイン(Central `docs/API.md` の `allow.plugins`)。`install` が `any` なら入っているものはどれでも、
/// `none` / `listed` なら `ids` のものだけ(入っていても、ここに無ければ呼ばない)、`examples` なら `ids` のものと
/// 許す例に近いもの。**`ids` がいちばん強い**(名指しで許したものは、止める例に近くても使える)。`ids` に無いものは、
/// 止める例に近ければ `any` でも使えない([scores] = マニフェストの中身と `allow.examples` の近さ。D-314)。
/// `slots` = スロットごとの可否(書いていないスロットは可)。
@immutable
class ChildSafePluginsAllow {
  const ChildSafePluginsAllow({this.ids = const [], this.slots = const {}, this.install = ChildSafeInstall.none});
  final List<String> ids;
  final Map<String, bool> slots;
  final ChildSafeInstall install;
  bool permits(String pluginId, String slot, {ExampleScores? scores}) => slots[slot] != false && permitsPlugin(pluginId, scores: scores);

  /// スロットを見ない可否。[scores] が null(中身が分からない)なら、例では許さない / 止めない。
  bool permitsPlugin(String pluginId, {ExampleScores? scores}) {
    if (ids.contains(pluginId)) return true;
    return switch (install) {
      ChildSafeInstall.any => !(scores?.nearDeny ?? false),
      ChildSafeInstall.examples => scores != null && scores.nearAllow && !scores.nearDeny,
      ChildSafeInstall.none || ChildSafeInstall.listed => false,
    };
  }

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
  const ChildSafeAllow({this.sns, this.plugins, this.features, this.search, this.rai, this.examples});
  final ChildSafeSnsAllow? sns;
  final ChildSafePluginsAllow? plugins;

  /// 機能 id → 可否(`dm` / `astell.join` …)。書いていない機能は可。
  final Map<String, bool>? features;

  /// 検索の種類 id → 可否(`posts` / `users` / `trend` / `store` / `web`)。書いていない種類は可。
  final Map<String, bool>? search;
  final ChildSafeRaiAllow? rai;

  /// 例で決める (D-314): 許す例 / 止める例。null = 例では絞らない。
  final ContentExamples? examples;

  factory ChildSafeAllow.fromJson(Map<String, Object?> j) => ChildSafeAllow(
        sns: j['sns'] is Map ? ChildSafeSnsAllow.fromJson(_map(j['sns'])) : null,
        plugins: j['plugins'] is Map ? ChildSafePluginsAllow.fromJson(_map(j['plugins'])) : null,
        features: j['features'] is Map ? _bools(j['features']) : null,
        search: j['search'] is Map ? _bools(j['search']) : null,
        rai: j['rai'] is Map ? ChildSafeRaiAllow.fromJson(_map(j['rai'])) : null,
        examples: j['examples'] is Map ? ContentExamples.fromJson(j['examples']) : null,
      );
  Map<String, Object?> toJson() => {
        if (sns != null) 'sns': sns!.toJson(),
        if (plugins != null) 'plugins': plugins!.toJson(),
        if (features != null) 'features': features,
        if (search != null) 'search': search,
        if (rai != null) 'rai': rai!.toJson(),
        if (examples != null && examples!.isNotEmpty) 'examples': examples!.toJson(),
      };
  ChildSafeAllow copyWith({ChildSafeSnsAllow? sns, ChildSafePluginsAllow? plugins, Map<String, bool>? features, Map<String, bool>? search, ChildSafeRaiAllow? rai, ContentExamples? examples}) => ChildSafeAllow(
      sns: sns ?? this.sns, plugins: plugins ?? this.plugins, features: features ?? this.features, search: search ?? this.search, rai: rai ?? this.rai, examples: examples ?? this.examples);
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

  /// サーバーから取れないとき(オフライン / 古い Central)の控え。**Central の `policy::catalog()` と同じ値**
  /// (`test/fixtures/child_safe_catalog.json` と突き合わせている。Central を変えたら、ここと fixture も)。
  static final fallback = ChildSafeCatalog(
    version: 1,
    features: const [
      ChildSafeCatalogItem('astell.join', 'AsTell への参加'),
      ChildSafeCatalogItem('astell.create', 'AsTell ルームの作成'),
      ChildSafeCatalogItem('astell.share', 'AsTell での共有・チャット'),
      ChildSafeCatalogItem('astell.stream', 'AsTell の画面共有・配信'),
      ChildSafeCatalogItem('store.review', 'ストアのレビュー投稿'),
      ChildSafeCatalogItem('account.follow', 'RASQ アカウントのフォロー'),
      ChildSafeCatalogItem('post', '投稿'),
      ChildSafeCatalogItem('post.media', '画像・動画つきの投稿'),
      ChildSafeCatalogItem('dm', 'ダイレクトメッセージ'),
      ChildSafeCatalogItem('reaction', 'リアクション'),
      ChildSafeCatalogItem('relational', 'つながりの表示(フォロー / フォロワー)'),
      ChildSafeCatalogItem('trend', 'トレンド'),
      ChildSafeCatalogItem('lists', 'リスト'),
      ChildSafeCatalogItem('notifications', '通知'),
      ChildSafeCatalogItem('store.install', 'プラグインのインストール'),
      ChildSafeCatalogItem('sns.addAccount', 'SNS アカウントの追加'),
    ],
    search: const [
      ChildSafeCatalogItem('posts', '投稿の検索'),
      ChildSafeCatalogItem('users', 'ユーザーの検索'),
      ChildSafeCatalogItem('trend', 'トレンドの検索'),
      ChildSafeCatalogItem('store', 'ストアの検索'),
      ChildSafeCatalogItem('web', 'Web の検索'),
    ],
    raiGroups: const [
      ChildSafeCatalogItem('rai.guide', '使い方の案内'),
      ChildSafeCatalogItem('rai.read', '読む(要約・翻訳)'),
      ChildSafeCatalogItem('rai.compose', '書く手伝い'),
      ChildSafeCatalogItem('rai.act', '操作の代行'),
      ChildSafeCatalogItem('rai.settings', '設定の変更'),
      ChildSafeCatalogItem('rai.astell', 'AsTell の手伝い'),
      ChildSafeCatalogItem('rai.web', 'Web の調べもの'),
      ChildSafeCatalogItem('rai.assistant', 'アシスタント', phase: 2),
      ChildSafeCatalogItem('rai.macro', 'マクロ', phase: 2),
      ChildSafeCatalogItem('rai.automation', '自動化', phase: 2),
    ],
    presets: {'13-15': childSafePresets['strict']!, '16-17': childSafePresets['standard']!, '18+': childSafePresets['mild']!},
  );
}

/// プリセットの中身(Central `Settings::preset`。カタログの `presets` と同じ)。控え([ChildSafeCatalog.fallback])と、
/// `allow.features` / `allow.search` に書いていない id の既定([childSafePresetDefault])に使う。
final childSafePresets = <String, Map<String, Object?>>{
  'strict': _preset(
    'strict',
    time: {'enabled': true, 'start': '21:00', 'hideNotifications': true, 'hideDirectMessages': true},
    postsPerDay: 10,
    sns: false,
    plugins: {'slots': {'post.action': false}, 'install': 'none'},
    features: {'astell.create': false, 'astell.join': false, 'astell.share': false, 'astell.stream': false, 'dm': false, 'sns.addAccount': false, 'store.install': false, 'store.review': false},
    search: {'posts': true, 'store': false, 'trend': true, 'users': false, 'web': false},
    rai: ['rai.guide', 'rai.read', 'rai.compose'],
    automation: false,
  ),
  'standard': _preset(
    'standard',
    time: {'enabled': true, 'start': '23:00', 'hideNotifications': true, 'hideDirectMessages': false},
    postsPerDay: 30,
    sns: false,
    plugins: {'slots': <String, bool>{}, 'install': 'listed'},
    features: {'astell.create': false, 'astell.stream': false, 'sns.addAccount': false},
    search: {'posts': true, 'store': true, 'trend': true, 'users': true, 'web': false},
    rai: ['rai.guide', 'rai.read', 'rai.compose', 'rai.settings', 'rai.astell'],
    automation: false,
  ),
  'mild': _preset(
    'mild',
    time: {'enabled': false, 'start': '21:00', 'hideNotifications': false, 'hideDirectMessages': false},
    postsPerDay: null,
    sns: true,
    plugins: {'slots': <String, bool>{}, 'install': 'any'},
    features: <String, bool>{},
    search: {'posts': true, 'store': true, 'trend': true, 'users': true, 'web': true},
    rai: childSafeRaiGroups,
    automation: true,
  ),
};

Map<String, Object?> _preset(String level,
        {required Map<String, Object?> time,
        required int? postsPerDay,
        required bool sns,
        required Map<String, Object?> plugins,
        required Map<String, bool> features,
        required Map<String, bool> search,
        required List<String> rai,
        required bool automation}) =>
    {
      'schema': ChildSafePolicy.schemaV2,
      'preset': level,
      // 話題 (D-315): TL / 投稿 = ホワイトリストの空(保護者が話題を足すまで保存できない)、時間 = ブラックリストの空。
      'timeline': {'enabled': true, 'level': level, 'topicMode': 'allow', 'topics': <String>[]},
      'composer': {'enabled': true, 'level': level, 'topicMode': 'allow', 'topics': <String>[]},
      'time': {'end': '06:00', 'topicMode': 'deny', 'topics': <String>[], 'hidePostDetail': false, ...time},
      'postsPerDay': postsPerDay,
      'allow': {
        'sns': {'kinds': <String>[], 'instances': <String>[], 'addAccounts': sns},
        'plugins': {'ids': <String>[], ...plugins},
        'features': features,
        'search': search,
        'rai': {'enabled': true, 'groups': rai, 'deny': <String>[], 'automation': automation},
      },
      'source': {'catalogVersion': 1},
    };

/// `allow.features` / `allow.search` に書いていない id の値: `preset` のプリセットの値、無ければ「許す」(Central と同じ規則。
/// Central は保存のときに埋めて署名するので、ふつうは届いた値に全部ある)。[kind] = `features` / `search`。
bool childSafePresetDefault(String? preset, String kind, String id) {
  final allow = childSafePresets[preset]?['allow'];
  final m = allow is Map ? allow[kind] : null;
  return m is Map ? m[id] != false : true;
}

/// 保存の前の確かめ (D-315): 有効な面(`timeline` / `composer` / `time`)の空のホワイトリスト → 面 → 文。
/// Central も同じものを `400`(`timeline.topics: …`)で断る。ブラックリストは空でよい(= 話題では絞らない)。
Map<String, String> childSafeTopicErrors(ChildSafePolicy p) => {
      if (p.timeline.enabled && p.timeline.topics.isEmptyWhitelist) 'timeline': childSafeEmptyWhitelistText,
      if (p.composer.enabled && p.composer.topics.isEmptyWhitelist) 'composer': childSafeEmptyWhitelistText,
      if (p.time.enabled && p.time.topics.isEmptyWhitelist) 'time': childSafeEmptyWhitelistText,
    };

const childSafeEmptyWhitelistText = 'ホワイトリストが空です。話題を 1 つ以上入れるか、ブラックリストにしてください';

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
  'rasqLists.search': 'rai.read',
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
  'timeline.addRasqList': 'rai.settings',
  'timeline.excludeWord': 'rai.settings',
  'timeline.filterWord': 'rai.settings',
  'tendency.seed': 'rai.settings',
  'astell.rooms': 'rai.astell',
  'astell.create': 'rai.astell',
  'web.search': 'rai.web',
};

/// RAi の案内 (D-309): リファレンス(`assets/rai/functions.jsonl`)の関数 id → 止まっていたら案内しない機能 / 検索。
/// 値は `features:<id>`(`allow.features`)か `search:<id>`(`allow.search`)。まとまり(`group`)と画面(`route`)は
/// [ChildGate.raiGuideAllowed] がこれとは別に見る。完全一致が先、無ければ [raiGuideRequirementPrefixes] の頭の一致。
const raiGuideRequirements = <String, String>{
  'post.shareDm': 'features:dm',
  'post.attach': 'features:post.media',
  'media.edit': 'features:post.media',
  'media.editPlugin': 'features:post.media',
  'post.react': 'features:reaction',
  'react.pick': 'features:reaction',
  'plugins.install': 'features:store.install',
  'plugins.review': 'features:store.review',
  'relational.tune': 'features:relational',
  'astell.create': 'features:astell.create',
  'astell.schedule': 'features:astell.create',
  'astell.share': 'features:astell.share',
  'account.add': 'features:sns.addAccount',
  'search.posts': 'search:posts',
  'search.hashtag': 'search:posts',
  'search.users': 'search:users',
  'plugins.search': 'search:store',
  'plugins.store': 'search:store',
};

/// [raiGuideRequirements] の頭の一致(長いほうが先に当たるよう、使う側で長い順に見る)。
const raiGuideRequirementPrefixes = <String, String>{
  'dm.': 'features:dm',
  'login.': 'features:sns.addAccount',
  'lists.': 'features:lists',
  'list.': 'features:lists',
  'notifications.': 'features:notifications',
  'trend.': 'features:trend',
  'plugin.sample.': 'features:store.install',
};

/// 関数 id の案内に要る機能 / 検索([raiGuideRequirements] → [raiGuideRequirementPrefixes])。書く手伝い(`rai.compose`)の
/// DM 以外は「投稿」。無ければ null。
String? raiGuideRequirementOf(String id, String? group) {
  final exact = raiGuideRequirements[id];
  if (exact != null) return exact;
  final prefixes = raiGuideRequirementPrefixes.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final p in prefixes) {
    if (id.startsWith(p)) return raiGuideRequirementPrefixes[p];
  }
  if (group == 'rai.compose') return 'features:post';
  return null;
}

// ── 署名 ───────────────────────────────────────────────────────────────

/// canonical JSON(Central `docs/API.md` の「署名」。参照のベクトルも同じ節)。**手で書く**(`jsonEncode` には頼らない):
/// - オブジェクトのキーは **UTF-8 のバイト順**(Dart の `String.compareTo` は UTF-16 の順で、U+E000〜U+FFFF と
///   U+10000 以上の並びが逆になる)。入れ子も同じ。配列の順はそのまま。空白は入れない。
/// - 文字列は `"` `\` と U+0000〜U+001F だけをエスケープ(`\b` `\t` `\n` `\f` `\r` はその形、ほかは `\u00xx` の小文字)。
///   それ以外(日本語 / `/` / U+007F / U+2028 など)は UTF-8 のまま。
/// - 数は整数だけ。`null` / `true` / `false` はそのまま。
///
/// 決めていない値(小数 / 対になっていないサロゲート / Map・List 以外のオブジェクト)は [ArgumentError](署名の検証は false)。
String canonicalJson(Object? v) {
  final out = StringBuffer();
  _writeCanonical(v, out);
  return out.toString();
}

int _compareUtf8(String a, String b) {
  final x = utf8.encode(a), y = utf8.encode(b);
  final n = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    if (x[i] != y[i]) return x[i] - y[i];
  }
  return x.length - y.length;
}

void _writeCanonical(Object? v, StringBuffer out) {
  switch (v) {
    case null:
      out.write('null');
    case bool b:
      out.write(b ? 'true' : 'false');
    case int i:
      out.write(i);
    case double d when d.isFinite && d == d.truncateToDouble() && d.abs() <= 9007199254740991:
      out.write(d.toInt()); // Web では整数も double で届く
    case String str:
      _writeCanonicalString(str, out);
    case Map m:
      final keys = [
        for (final k in m.keys)
          if (k is String) k else throw ArgumentError.value(k, 'key', 'canonical JSON のキーは文字列だけです'),
      ]..sort(_compareUtf8);
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        _writeCanonicalString(keys[i], out);
        out.write(':');
        _writeCanonical(m[keys[i]], out);
      }
      out.write('}');
    case List l:
      out.write('[');
      for (var i = 0; i < l.length; i++) {
        if (i > 0) out.write(',');
        _writeCanonical(l[i], out);
      }
      out.write(']');
    default:
      throw ArgumentError.value(v, 'value', 'canonical JSON にできない値です');
  }
}

const _shortEscapes = {0x08: r'\b', 0x09: r'\t', 0x0a: r'\n', 0x0c: r'\f', 0x0d: r'\r', 0x22: r'\"', 0x5c: r'\\'};

void _writeCanonicalString(String s, StringBuffer out) {
  out.write('"');
  final units = s.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    final short = _shortEscapes[c];
    if (short != null) {
      out.write(short);
    } else if (c < 0x20) {
      out.write(r'\u00');
      out.write(c.toRadixString(16).padLeft(2, '0'));
    } else if (c >= 0xd800 && c <= 0xdbff && i + 1 < units.length && units[i + 1] >= 0xdc00 && units[i + 1] <= 0xdfff) {
      out.writeCharCode(c);
      out.writeCharCode(units[++i]);
    } else if (c >= 0xd800 && c <= 0xdfff) {
      throw ArgumentError.value(s, 'string', '対になっていないサロゲートがあります');
    } else {
      out.writeCharCode(c);
    }
  }
  out.write('"');
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
