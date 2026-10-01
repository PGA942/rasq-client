import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../settings/settings_dsl.dart';
import '../vc/astell_models.dart' show astellReportReasons;
import 'trend_providers.dart';

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

/// トレンドの通報を控える場所 (D-397)。KV `trend.reports.v1`、キー = [trendKey]。
/// ⚠ 仮置き: Central の通報(`POST /reports`)は対象(アカウント / ルーム / 共有 / Swing)が要り、トレンドのワードは
/// 送れない。SNS の通報(`reportUser`)も人が対象。受け口ができるまでは端末に控えるだけで、どこにも送らない。
const trendReportsArea = 'trend.reports';

/// トレンドの行の「…」(D-397): 別のアカウントで開く / 通報。
Future<void> showTrendMenu(BuildContext context, WidgetRef ref, {required TrendTag trend, required List<AccountId> sources, required Rect anchor}) async {
  final manager = ref.read(overlayManagerProvider);
  final accounts = ref.read(sessionsProvider).value?.sessions ?? const <AccountSession>[];
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

/// トレンドの通報シート (D-397): 理由(AsTell の通報と同じ 4 つ)+ 補足。⚠ いまは端末に控えるだけ([trendReportsArea])。
Future<void> showTrendReportSheet(BuildContext context, WidgetRef ref, {required TrendTag trend, AccountId? account}) async {
  final manager = ref.read(overlayManagerProvider);
  final note = TextEditingController();
  var reason = astellReportReasons.first.id;
  var sent = false;
  await manager.showBottomSheet<void>(
    id: 'trend.report',
    title: '通報',
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
      final scheme = Theme.of(ctx).colorScheme;
      return ListView(shrinkWrap: true, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Text('トレンド「${trend.tag}」を通報します。いまは通報の受け口が無いため、この端末に控えるだけです(送信はされません)。', style: RasqTypography.bodySmall),
        ),
        for (final r in astellReportReasons) RasqRadioListTile<String>(title: r.label, value: r.id, groupValue: reason, onChanged: (v) => setSheet(() => reason = v)),
        Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: RasqInput(controller: note, hintText: '補足(任意)', maxLines: 3)),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: FilledButton(
            key: const ValueKey('trend.report.send'),
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () async {
              await ref.read(settingsAreaProvider(trendReportsArea).notifier).set(trendKey(trend.tag), {
                'tag': trend.tag,
                'reason': reason,
                if (note.text.trim().isNotEmpty) 'note': note.text.trim(),
                if (account != null) 'account': account.key,
                'at': DateTime.now().toUtc().toIso8601String(),
              });
              sent = true;
              manager.close('trend.report');
            },
            child: const Text('通報する'),
          ),
        ),
      ]);
    }),
  );
  note.dispose();
  if (sent && context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('通報をこの端末に控えました(送信は受け口ができてから)')));
}
