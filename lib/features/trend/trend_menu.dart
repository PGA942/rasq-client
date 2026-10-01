import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../vc/astell_models.dart' show astellReportReasons;
import 'trend_reports.dart';

export 'trend_reports.dart' show trendReportsArea;

/// トレンドの行を開くアカウント (D-397): そのトレンドを出したアカウント([sources])。いまのアカウントも出していれば
/// いまのアカウントを先に(切り替えずに済む)。出どころが分からなければ null(= いまのアカウント)。
AccountId? trendOpenAccount(List<AccountId> sources, AccountId? current) {
  if (sources.isEmpty) return null;
  if (current != null && sources.contains(current)) return current;
  return sources.first;
}

/// トレンドを開く (D-397)。いまのアカウントなら指定しない(アカウントを切り替えるとついてくる)。
void openTrendAs(BuildContext context, WidgetRef ref, String tag, AccountId? account) {
  final current = ref.read(currentAccountProvider);
  context.pushTrend(tag, account: account == null || account == current ? null : account.key);
}

/// トレンドの行の「…」(D-397): 別のアカウントで開く / 通報。
Future<void> showTrendMenu(BuildContext context, WidgetRef ref, {required TrendTag trend, required List<AccountId> sources, required Rect anchor}) async {
  final manager = ref.read(overlayManagerProvider);
  final accounts = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
  // 前に送れなかったトレンドの通報があれば、ここで送り直す (D-402)。
  unawaited(flushPendingTrendReports(ProviderScope.containerOf(context, listen: false)));
  final pick = await manager.showDropdown<String>(id: 'trend.menu', anchor: anchor, dense: true, items: [
    RasqDropdownItem('別のアカウントで開く', 'openAs', enabled: accounts.isNotEmpty),
    const RasqDropdownItem('通報', 'report', destructive: true),
  ]);
  if (!context.mounted) return;
  switch (pick) {
    case 'openAs':
      // アカウントを選ぶ: いまの RASQ アカウントに入っている SNS アカウント。このトレンドを出したアカウントに印。
      final current = ref.read(currentAccountProvider);
      final chosen = await manager.showDropdown<String>(id: 'trend.openAs', anchor: anchor, dense: true, items: [
        for (final s in accounts)
          RasqDropdownItem('${s.account}${sources.contains(s.account) ? '(トレンドに出したアカウント)' : ''}', s.account.key, checked: s.account == current),
      ]);
      if (chosen == null || !context.mounted) return;
      final account = accounts.where((s) => s.account.key == chosen).firstOrNull?.account;
      openTrendAs(context, ref, trend.tag, account);
    case 'report':
      await showTrendReportSheet(context, ref, trend: trend, account: trendOpenAccount(sources, ref.read(currentAccountProvider)));
  }
}

/// トレンドの通報シート (D-397 → D-402): 理由(AsTell の通報と同じ 4 つ)+ 補足。Central の `POST /reports {trend}` へ送る
/// ([reportTrend])。繋がっていなければ端末に控えて、あとで送る。通報したトレンドは一覧から隠す(スナックバーで戻せる)。
Future<void> showTrendReportSheet(BuildContext context, WidgetRef ref, {required TrendTag trend, AccountId? account}) async {
  final manager = ref.read(overlayManagerProvider);
  // 通報するとこの行は一覧から消える(隠す)ので、送るのはコンテナから(行の ref は使えなくなる)。
  final container = ProviderScope.containerOf(context, listen: false);
  final note = TextEditingController();
  var reason = astellReportReasons.first.id;
  var picked = false;
  await manager.showBottomSheet<void>(
    id: 'trend.report',
    title: '通報',
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final scheme = Theme.of(ctx).colorScheme;
      return ListView(shrinkWrap: true, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Text('トレンド「${trend.tag}」${account == null ? '' : '(${account.instance})'}を通報します。RASQ の審査で確認します。通報したトレンドは、トレンドの一覧に出なくなります。', style: RasqTypography.bodySmall),
        ),
        for (final r in astellReportReasons) RasqRadioListTile<String>(title: r.label, value: r.id, groupValue: reason, onChanged: (v) => setSheet(() => reason = v)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: RasqInput(controller: note, hintText: '補足(任意)', maxLines: 3)),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: FilledButton(
            key: const ValueKey('trend.report.send'),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () {
              picked = true;
              manager.close('trend.report');
            },
            child: const Text('通報する'),
          ),
        ),
      ]);
    }),
  );
  final text = note.text;
  note.dispose();
  if (!picked) return;
  final messenger = context.mounted ? ScaffoldMessenger.maybeOf(context) : null;
  final outcome = await reportTrend(container, trend: trend, reason: reason, note: text, account: account);
  messenger?.showSnackBar(SnackBar(
    content: Text(switch (outcome) {
      TrendReportOutcome.sent => '通報しました。RASQ の審査で確認します',
      TrendReportOutcome.stored => 'この端末に控えました。RASQ アカウントに繋がったら送ります',
      TrendReportOutcome.failed => '送れなかったので、この端末に控えました(あとで送り直します)',
    }),
    action: SnackBarAction(key: const ValueKey('trend.report.unhide'), label: '表示に戻す', onPressed: () => unhideTrend(container, trend.tag)),
  ));
}
