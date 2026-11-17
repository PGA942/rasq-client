import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../backend/rasq_account_page_api.dart';
import '../../l10n/l10n.dart';
import '../../session/session_providers.dart';
import '../../shell/scroll_memory.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../nodeprog/tl_components.dart';
import '../nodeprog/tl_config_store.dart';
import '../users/user_list.dart';
import 'notification_nodes.dart';
import 'notification_prefs.dart';
import 'notifications_screen.dart';

/// 通知のノードの実行 (D-590)。ノードの構成は**画面の表示だけ**に使う(push の受け取り・出す / 出さないには関わらない)。

/// いまのアカウント以外のアカウントの通知(`AccountId.key`)。いまのアカウントの分は [notificationsProvider](未読のバッジ・既読と同じもの)。
/// 使えないアカウント(見守りで止めた SNS / ほかの RASQ アカウントのもの)は空。
final accountNotificationsProvider = FutureProvider.family<Page<NotificationItem>, String>((ref, key) async {
  final usable = ref.watch(usableSessionsProvider).where((s) => s.account.key == key).firstOrNull;
  if (usable == null) return Page.empty();
  final s = ref.watch(pluginRegistryProvider).session(usable);
  // チャイルドセーフ (D-454): いまのアカウントの通知と同じ制限。
  final gate = ref.watch(childGateProvider);
  final page = await s.notifications(limit: 40);
  await ref.read(userListHelperProvider).primeRelationships(page.items.expand((n) => n.actors.map((a) => a.id)), account: key);
  return gate.supervised ? Page(items: gate.filterNotifications(page.items), nextCursor: page.nextCursor) : page;
});

/// 読み込みの口: '' = いまのアカウント([notificationsProvider])、それ以外 = そのアカウント。
FutureProvider<Page<NotificationItem>> notifSourceProvider(String key) => key.isEmpty ? notificationsProvider : accountNotificationsProvider(key);

/// ノードのアカウントの表記 → 読み込みの口の並び。いまのアカウントは ''(同じ読み込みを使う)。見つからないアカウントは無し。
List<String> notifSourceKeysOf(List<AccountSession> usable, String? currentKey, String account) {
  String norm(String key) => key == currentKey ? '' : key;
  if (account.isEmpty) return const [''];
  if (account == notifAllAccounts) {
    final keys = {for (final s in usable) norm(s.account.key)}.toList();
    return keys.isEmpty ? const [''] : keys;
  }
  final s = usable.where((x) => '${x.account}' == account || x.account.key == account).firstOrNull;
  return s == null ? const [] : [norm(s.account.key)];
}

List<String> notifNodeKeys(WidgetRef ref, TlSourceComponent node) => notifSourceKeysOf(ref.watch(usableSessionsProvider), ref.watch(currentAccountProvider)?.key, node.account);

/// 1 つの通知ノードの並び(種類 / フォロー中 / 通知プロファイルの種類の ON/OFF を掛けたもの、新しい順)。
/// [onPage] = 読み込めた口ごとに呼ぶ(見たところ・青いハイライト、D-557)。
AsyncValue<List<NotificationItem>> watchNotifNode(WidgetRef ref, TlSourceComponent node, {void Function(Page<NotificationItem>)? onPage}) {
  final keys = notifNodeKeys(ref, node);
  final spec = node.notifSpec;
  final prefs = ref.watch(notificationPrefsProvider);
  final follows = spec.followingOnly ? ref.watch(followStateProvider) : const <String, FollowState>{};
  final current = ref.watch(currentAccountProvider);
  // 関係は受け取ったアカウントのサーバーの id で引いてある (D-421): いまのアカウントの口は見ているアカウント、ほかはそのアカウントで。
  // 見ているアカウントが無ければ、前の「フォロー中」と同じく出さない。
  final usable = ref.watch(usableSessionsProvider);
  AccountId? viewerOf(String k) => k.isEmpty ? current : usable.where((s) => s.account.key == k).firstOrNull?.account;
  bool followed(AccountId? viewer, UserSummary u) => viewer != null && (follows[followKey(viewer.key, followUserKey(viewer, u.id))]?.following ?? false);

  final lists = <List<NotificationItem>>[];
  Object? error;
  StackTrace? stack;
  var loading = false;
  for (final k in keys) {
    final v = ref.watch(notifSourceProvider(k));
    final page = v.value;
    if (page != null) {
      onPage?.call(page);
      final viewer = viewerOf(k);
      lists.add([
        for (final n in page.items)
          if (prefs.isOn(n.kind) && spec.acceptsKind(n.kind) && (!spec.followingOnly || n.actors.any((u) => followed(viewer, u)))) n,
      ]);
    } else if (v.hasError) {
      error ??= v.error;
      stack ??= v.stackTrace;
    } else {
      loading = true;
    }
  }
  if (lists.isEmpty && error != null) return AsyncError(error, stack ?? StackTrace.current);
  if (lists.isEmpty && loading) return const AsyncLoading();
  return AsyncData(mergeNotifications(lists));
}

/// 通知のタブの中身: 構成の並びの順に、枠(セクション / RASQ の通知 / 開始通知の予定)と、本体の並び(通知ノードを 1 本に
/// まとめたもの。最初の通知ノードの位置)。構成が保存されていなければ既定([defaultNotifConfig] = 前の画面と同じ中身)。
class NotificationNodeView extends ConsumerWidget {
  const NotificationNodeView({super.key, required this.scope, this.highlight, this.onPage, this.emptyTitle});
  final String scope;

  /// 青く出す通知 (D-557)。
  final bool Function(NotificationItem)? highlight;
  final void Function(Page<NotificationItem>)? onPage;
  final String? emptyTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final cfg = ref.watch(tlViewConfigProvider(scope)) ?? defaultNotifConfig(scope);
    final layout = notifPageLayout(cfg);
    final mainParts = [for (final n in layout.main) watchNotifNode(ref, n, onPage: onPage)];
    final mainKeys = {for (final n in layout.main) ...notifNodeKeys(ref, n)};
    final mainData = [for (final p in mainParts) ?p.value];
    final main = applyNotifAlgorithms(mergeNotifications(mainData), cfg.algorithms);
    final usesRasq = cfg.sources.any((s) => s.isRasqNotices || s.children.any((c) => c.isRasqNotices));
    Future<void> refresh() async {
      if (usesRasq) ref.invalidate(rasqNoticesProvider);
      for (final s in [...layout.before, ...layout.after]) {
        for (final c in s.children.where((c) => c.isNotif)) {
          for (final k in notifNodeKeys(ref, c)) {
            ref.invalidate(notifSourceProvider(k));
          }
        }
      }
      await Future.wait([for (final k in mainKeys) ref.refresh(notifSourceProvider(k).future).then((_) {}, onError: (_) {})]);
    }

    final blocks = [...layout.before, ...layout.after];
    if (layout.main.isEmpty && blocks.isEmpty) {
      return ListView(physics: const AlwaysScrollableScrollPhysics(), children: [const SizedBox(height: 120), RasqEmptyView(title: l10n.notificationsTabNoNodes, hint: l10n.notificationsTabNoNodesHint)]);
    }
    if (layout.main.isNotEmpty && mainData.isEmpty) {
      if (mainParts.any((p) => p.isLoading)) return const RasqLoading();
      final e = mainParts.firstWhere((p) => p.hasError).error;
      return RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: refresh, retryLabel: l10n.notificationsRetry);
    }
    // 受け取ったアカウントが混ざるときだけ、タイルにアカウントの印を出す。
    final mixed = {for (final n in main) n.account.key}.length > 1;
    final alone = layout.main.isEmpty && blocks.length == 1;
    Widget block(TlSourceComponent b) => _NotifBlock(node: b, algorithms: cfg.algorithms, highlight: highlight, onPage: onPage, alone: alone);
    final entries = <Widget Function(BuildContext)>[
      for (final b in layout.before) (_) => block(b),
      if (layout.main.isNotEmpty && main.isEmpty) (_) => Padding(padding: const EdgeInsets.only(top: 120), child: RasqEmptyView(title: emptyTitle ?? l10n.notificationsEmpty)),
      for (final n in main) (_) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [NotificationTile(item: n, unread: highlight?.call(n), showAccount: mixed), const Divider()]),
      for (final b in layout.after) (_) => block(b),
    ];
    return RefreshIndicator(
      onRefresh: refresh,
      child: RememberScroll(
        // 位置を覚える一覧の名前 (D-504)。前の画面の名前(notifications.all / .following / .rasq)をそのまま使う。
        id: 'notifications.${notifTabIdOf(scope)}',
        builder: (context, controller) => ListView.builder(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, i) => entries[i](context),
        ),
      ),
    );
  }
}

/// 枠: セクション(見出し + 中のノードを件数まで)/ RASQ の通知 / 開始通知の予定。
class _NotifBlock extends ConsumerWidget {
  const _NotifBlock({required this.node, required this.algorithms, this.highlight, this.onPage, this.alone = false});
  final TlSourceComponent node;
  final List<TlAlgorithmComponent> algorithms;
  final bool Function(NotificationItem)? highlight;
  final void Function(Page<NotificationItem>)? onPage;

  /// タブにこの枠しか無い(読み込み中 / 空を、前の画面のように真ん中に出す)。
  final bool alone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (node.isRasqNotices) return _RasqNoticesBlock(limit: null, alone: alone);
    if (node.isAstellReminders) return const AstellRemindersBlock();
    if (!node.isSection) return const SizedBox.shrink();
    final children = [for (final c in node.children) if (c.enabled) c];
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(title: node.label.isEmpty ? context.l10n.nodeprogTimelineSectionTitle : node.label, topMargin: RasqSpacing.sm),
      for (final c in children)
        if (c.isRasqNotices)
          _RasqNoticesBlock(limit: c.limit)
        else if (c.isAstellReminders)
          const AstellRemindersBlock()
        else if (c.isNotif)
          ...switch (watchNotifNode(ref, c, onPage: onPage)) {
            AsyncValue(:final value?) => [
                for (final n in applyNotifAlgorithms(value, algorithms).take(c.limit)) ...[NotificationTile(item: n, unread: highlight?.call(n), showAccount: c.account == notifAllAccounts), const Divider()],
              ],
            AsyncValue(isLoading: true) => [const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: RasqLoading())],
            _ => const <Widget>[],
          },
      const Divider(height: 1),
    ]);
  }
}

/// RASQ の通知 (D-285) の枠。[limit] = セクションの中の件数(null = 全部)。
class _RasqNoticesBlock extends ConsumerWidget {
  const _RasqNoticesBlock({this.limit, this.alone = false});
  final int? limit;
  final bool alone;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(rasqNoticesProvider);
    final pad = alone ? 120.0 : RasqSpacing.md;
    return notices.when(
      loading: () => alone ? const Padding(padding: EdgeInsets.only(top: 120), child: RasqLoading()) : const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: RasqLoading()),
      error: (e, _) => Padding(padding: EdgeInsets.only(top: pad), child: RasqEmptyView(title: context.l10n.notificationsRasqLoadError, hint: e is StateError ? e.message : '$e')),
      data: (list) => list.isEmpty
          ? Padding(padding: EdgeInsets.only(top: pad), child: RasqEmptyView(title: context.l10n.notificationsRasqEmpty, hint: context.l10n.notificationsRasqEmptyHint))
          : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final n in limit == null ? list : list.take(limit!)) ...[RasqNoticeTile(notice: n), const Divider()],
            ]),
    );
  }
}
