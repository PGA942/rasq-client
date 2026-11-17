import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../l10n/l10n.dart';
import '../nodeprog/node_tabs.dart' show nodeprogAreaFor;
import '../nodeprog/tl_components.dart';
import '../settings/settings_dsl.dart';

/// 通知のノード (D-590): 通知の画面の**表示だけ**を、TL と同じノード(`TlConfig` の並び + アルゴリズム)で組む。
///
/// - 構成の置き場は TL と同じ(`nodeprog.<アカウント>.notif.<タブ>` の `tlcfg`)。編集は「タイムラインをカスタマイズ」と同じ画面を、
///   通知用のパレット(下のノードと、時系列順 / 検索絞り込み)で開く。ノードグラフ(`graph`)にはコンパイルしない。
/// - **push 通知はノードの外**: 端末の通知(FCM の前面の知らせ)・ORGATE の受信箱の見回り(`CentralInbox`)・push の登録
///   (通知トークン)は、この構成を読まない(`lib/notify/` はここを import しない)。ノードの組み方で push は変わらない。

/// 「通知」ノードの kind id。`notif` = すべての種類、`notif:<グループ>,…[,following]` = 種類を絞る / フォロー中の人だけ。
/// [TlSourceComponent.account] = 受け取ったアカウント(空 = いまのアカウント、[notifAllAccounts] = つないでいる全部のアカウント、
/// それ以外はアカウント表記 `@handle@instance` か `AccountId.key`)。
const notifNodeKind = 'notif';

/// 「RASQ の通知」ノード (D-285 の一覧)。
const rasqNoticesNodeKind = 'notif.rasq';

/// 「開始通知の予定」ノード (D-160 の AsTell の予定)。
const astellRemindersNodeKind = 'notif.reminders';

/// 通知ノードのアカウント: つないでいる全部のアカウント。
const notifAllAccounts = '*';

/// 通知のタブのスコープの頭(`notif.<タブ id>`)。
const notifScopePrefix = 'notif.';
bool isNotifScope(String scope) => scope.startsWith(notifScopePrefix);
String notifScopeOf(String tabId) => '$notifScopePrefix$tabId';
String notifTabIdOf(String scope) => isNotifScope(scope) ? scope.substring(notifScopePrefix.length) : scope;

/// 通知の種類のまとまり(ノードのパラメーター)。
enum NotifKindGroup {
  mentions([NotificationKind.reply, NotificationKind.mention, NotificationKind.quote]),
  reactions([NotificationKind.reaction]),
  reposts([NotificationKind.repost]),
  follows([NotificationKind.follow, NotificationKind.followRequest, NotificationKind.followAccepted, NotificationKind.listAdded]),
  events([NotificationKind.pollEnded, NotificationKind.timer, NotificationKind.vc]),
  system([NotificationKind.system, NotificationKind.other]);

  const NotifKindGroup(this.kinds);
  final List<NotificationKind> kinds;

  String label(AppLocalizations l) => switch (this) {
        mentions => l.notificationsGroupMentions,
        reactions => l.notificationsGroupReactions,
        reposts => l.notificationsGroupReposts,
        follows => l.notificationsGroupFollows,
        events => l.notificationsGroupEvents,
        system => l.notificationsGroupSystem,
      };

  static NotifKindGroup? byName(String name) => values.where((g) => g.name == name).firstOrNull;
}

/// 「通知」ノードのパラメーター(kind id に書く)。
@immutable
class NotifNodeSpec {
  const NotifNodeSpec({this.groups = const {}, this.followingOnly = false});

  /// 出す種類(空 = すべて)。
  final Set<NotifKindGroup> groups;

  /// フォロー中の人からの通知だけ。
  final bool followingOnly;

  static const _following = 'following';

  /// [tl] が通知ノードでなければ null。
  static NotifNodeSpec? parse(String tl) {
    if (tl == notifNodeKind) return const NotifNodeSpec();
    if (!tl.startsWith('$notifNodeKind:')) return null;
    final parts = tl.substring(notifNodeKind.length + 1).split(',');
    return NotifNodeSpec(groups: {for (final p in parts) ?NotifKindGroup.byName(p)}, followingOnly: parts.contains(_following));
  }

  String get tl {
    final parts = [for (final g in NotifKindGroup.values) if (groups.contains(g)) g.name, if (followingOnly) _following];
    return parts.isEmpty ? notifNodeKind : '$notifNodeKind:${parts.join(',')}';
  }

  bool acceptsKind(NotificationKind k) => groups.isEmpty || groups.any((g) => g.kinds.contains(k));

  NotifNodeSpec copyWith({Set<NotifKindGroup>? groups, bool? followingOnly}) => NotifNodeSpec(groups: groups ?? this.groups, followingOnly: followingOnly ?? this.followingOnly);
}

extension NotifNodes on TlSourceComponent {
  /// 「通知」ノード。
  bool get isNotif => NotifNodeSpec.parse(tl) != null;
  NotifNodeSpec get notifSpec => NotifNodeSpec.parse(tl) ?? const NotifNodeSpec();
  bool get isRasqNotices => tl == rasqNoticesNodeKind;
  bool get isAstellReminders => tl == astellRemindersNodeKind;

  /// 通知の画面で、本体の並び(通知ノードを 1 本にまとめたもの)ではなく、枠で出すノード。
  bool get isNotifBlock => isSection || isRasqNotices || isAstellReminders;
}

/// 通知のタブ。[builtin] は最初からあるタブ(消せない。名前は表示の言語)。
@immutable
class NotifTab {
  const NotifTab({required this.id, this.label = ''});
  final String id;

  /// ユーザーが付けた名前(空 = 既定の名前)。
  final String label;

  bool get builtin => notifBuiltinTabs.contains(id);
  String get scope => notifScopeOf(id);

  String title(AppLocalizations l) => label.isNotEmpty
      ? label
      : switch (id) {
          'all' => l.notificationsTabAll,
          'following' => l.notificationsTabFollowing,
          'mentions' => l.notificationsTabMentions,
          'rasq' => 'RASQ',
          _ => l.notificationsTabCustomFallback,
        };

  NotifTab copyWith({String? label}) => NotifTab(id: id, label: label ?? this.label);
  Map<String, Object?> toJson() => {'id': id, if (label.isNotEmpty) 'label': label};
  @override
  bool operator ==(Object other) => other is NotifTab && other.id == id && other.label == label;
  @override
  int get hashCode => Object.hash(id, label);
}

/// 最初からあるタブ(この順)。`rasq` は RASQ アカウントにログインしているときだけ出す。
const notifBuiltinTabs = ['all', 'following', 'mentions', 'rasq'];

/// タブの並びの置き場(設定エリア)。
const notifTabsArea = 'notifications.tabs';

List<NotifTab> parseNotifTabs(Object? raw) {
  final out = <NotifTab>[];
  if (raw is String) {
    try {
      for (final t in jsonDecode(raw) as List) {
        if (t is Map && t['id'] is String && (t['id'] as String).isNotEmpty && !out.any((x) => x.id == t['id'])) out.add(NotifTab(id: t['id'] as String, label: t['label'] as String? ?? ''));
      }
    } catch (_) {}
  }
  // 最初からあるタブは必ずある(保存した並びに無ければ末尾へ)。
  for (final id in notifBuiltinTabs) {
    if (!out.any((t) => t.id == id)) out.add(NotifTab(id: id));
  }
  return out;
}

/// 通知のタブの並び(保存した順。RASQ のタブも含む)。
final notifTabsProvider = Provider<List<NotifTab>>((ref) => parseNotifTabs((ref.watch(settingsAreaProvider(notifTabsArea)).value ?? const {})['tabs']));

Future<void> saveNotifTabs(ProviderContainer c, List<NotifTab> tabs) async {
  await c.read(settingsAreaProvider(notifTabsArea).future);
  await c.read(settingsAreaProvider(notifTabsArea).notifier).set('tabs', jsonEncode([for (final t in tabs) t.toJson()]));
}

/// 通知のタブの構成を書く(TL と同じ置き場の `tlcfg`。ノードグラフにはコンパイルしない)。
Future<void> writeNotifConfig(ProviderContainer c, String? accountKey, String scope, TlConfig cfg) async {
  final area = nodeprogAreaFor(accountKey, scope);
  await c.read(settingsAreaProvider(area).future);
  await c.read(settingsAreaProvider(area).notifier).set('tlcfg', jsonEncode(cfg.toJson()));
}

/// タブの構成を消す(タブを消したとき)。
Future<void> clearNotifConfig(ProviderContainer c, String? accountKey, String scope) async {
  final area = nodeprogAreaFor(accountKey, scope);
  await c.read(settingsAreaProvider(area).future);
  await c.read(settingsAreaProvider(area).notifier).set('tlcfg', null);
}

/// 新しいタブの id(`u<連番>`)。
String nextNotifTabId(List<NotifTab> tabs) {
  var n = 1;
  while (tabs.any((t) => t.id == 'u$n')) {
    n++;
  }
  return 'u$n';
}

/// タブの既定の構成(保存が無いとき)。最初からあるタブは、前の通知の画面と同じ中身。
TlConfig defaultNotifConfig(String scope) {
  const chrono = [TlAlgorithmComponent(type: 'chrono')];
  return switch (notifTabIdOf(scope)) {
    'following' => TlConfig(sources: [TlSourceComponent(tl: const NotifNodeSpec(followingOnly: true).tl)], algorithms: chrono, clock: ''),
    'mentions' => TlConfig(sources: [TlSourceComponent(tl: const NotifNodeSpec(groups: {NotifKindGroup.mentions}).tl)], algorithms: chrono, clock: ''),
    'rasq' => const TlConfig(sources: [TlSourceComponent(tl: rasqNoticesNodeKind)], algorithms: chrono, clock: ''),
    _ => const TlConfig(sources: [TlSourceComponent(tl: notifNodeKind)], algorithms: chrono, clock: ''),
  };
}

/// タブを足すときの雛形。
enum NotifTabTemplate { empty, account, kind }

/// 雛形からの構成。[account] = アカウント表記([NotifTabTemplate.account])、[group] = 種類([NotifTabTemplate.kind]、全部のアカウント)。
TlConfig notifTemplateConfig(NotifTabTemplate t, {String account = '', NotifKindGroup? group}) {
  const chrono = [TlAlgorithmComponent(type: 'chrono')];
  return switch (t) {
    NotifTabTemplate.empty => const TlConfig(algorithms: chrono, clock: ''),
    NotifTabTemplate.account => TlConfig(sources: [TlSourceComponent(account: account, tl: notifNodeKind)], algorithms: chrono, clock: ''),
    NotifTabTemplate.kind => TlConfig(sources: [TlSourceComponent(account: notifAllAccounts, tl: NotifNodeSpec(groups: {?group}).tl)], algorithms: chrono, clock: ''),
  };
}

/// 本体の並び(通知ノードを 1 本にまとめたもの)の前 / 後ろの枠。
typedef NotifPageLayout = ({List<TlSourceComponent> before, List<TlSourceComponent> main, List<TlSourceComponent> after});

NotifPageLayout notifPageLayout(TlConfig cfg) {
  final before = <TlSourceComponent>[], main = <TlSourceComponent>[], after = <TlSourceComponent>[];
  for (final s in cfg.sources) {
    if (!s.enabled) continue;
    if (s.isNotif) {
      main.add(s);
    } else if (s.isNotifBlock) {
      (main.isEmpty ? before : after).add(s);
    }
  }
  return (before: before, main: main, after: after);
}

/// 絞り込みに使う通知の文(人の名前・ハンドル・投稿の本文・見出し・本文・リアクション)。
String notificationSearchText(NotificationItem n) => [
      for (final a in n.actors) ...[a.displayName, a.account.handle],
      n.post?.body ?? '',
      n.title ?? '',
      n.body ?? '',
      n.reaction ?? '',
    ].join('\n').toLowerCase();

/// 構成のアルゴリズムを通知の並びに掛ける(上から順)。時系列順 = 新しい順、検索絞り込み = 語(空白で区切ったどれか)を含むものだけ /
/// 除く(語が空なら何もしない)。ほかのアルゴリズムは通知には掛けない(パレットにも出さない)。
List<NotificationItem> applyNotifAlgorithms(List<NotificationItem> items, List<TlAlgorithmComponent> algorithms) {
  var out = items;
  for (final a in algorithms) {
    if (!a.enabled) continue;
    if (a.type == 'chrono') {
      out = [...out]..sort((x, y) => y.createdAt.compareTo(x.createdAt));
    } else if (a.isQueryFilter) {
      final words = [for (final w in a.query.toLowerCase().split(RegExp(r'\s+'))) if (w.isNotEmpty) w];
      if (words.isEmpty) continue;
      out = [
        for (final n in out)
          if (words.any(notificationSearchText(n).contains) != a.exclude) n,
      ];
    }
  }
  return out;
}

/// 通知の並びを合わせる: 同じ通知(受け取ったアカウント + id)は 1 つに、新しい順。
List<NotificationItem> mergeNotifications(Iterable<List<NotificationItem>> lists) {
  final seen = <String>{};
  final out = <NotificationItem>[
    for (final l in lists)
      for (final n in l)
        if (seen.add('${n.account.key}|${n.id}')) n,
  ];
  out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return out;
}

/// ノードのアカウントの表記(パレット / タイル)。
String notifAccountLabel(AppLocalizations l, String account) => switch (account) {
      '' => l.nodeprogTimelineCurrentAccount,
      notifAllAccounts => l.nodeprogTimelineAllAccounts,
      _ => account,
    };

/// 通知ノードの説明(タイル): 種類とフォロー中の人だけか。
String notifNodeDescription(AppLocalizations l, TlSourceComponent s) {
  final spec = s.notifSpec;
  final kinds = spec.groups.isEmpty ? l.notificationsNodeAllKinds : [for (final g in NotifKindGroup.values) if (spec.groups.contains(g)) g.label(l)].join(l.nodeprogTimelineMetaSeparator);
  return spec.followingOnly ? l.notificationsNodeDescriptionFollowing(kinds) : l.notificationsNodeDescription(kinds);
}
