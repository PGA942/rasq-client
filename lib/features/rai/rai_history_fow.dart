import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import 'rai_layout.dart';
import 'rai_providers.dart';
import 'rai_widgets.dart';

/// RAi の発言履歴 FOW (D-185): 発言ポップアップの ↑ から。タイル = 発言(全文、可変高)、
/// ▶ の代わりにコピー。幅は入力ウィジェットに揃える。
const raiHistoryFowId = 'fow.rai.history';

Future<void> showRaiHistoryFow(WidgetRef ref, BuildContext context) async {
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains(raiHistoryFowId)) return;
  await manager.showFow<void>(
    id: raiHistoryFowId,
    spec: FowSpec(title: 'RAi の発言', cancelText: '閉じる', initialHeightFactor: 0.6, maxHeightFactor: 0.92, maxWidth: raiPanelWidth(context)),
    builder: (_, _) => const RaiHistoryBody(),
  );
}

class RaiHistoryBody extends ConsumerWidget {
  const RaiHistoryBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final log = ref.watch(raiProvider.select((s) => s.log));
    if (log.isEmpty) return const RasqEmptyView(title: 'まだ発言はありません');
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xl),
      itemCount: log.length,
      itemBuilder: (context, i) {
        final u = log[i];
        return Container(
          key: ValueKey('rai.history.$i'),
          margin: const EdgeInsets.only(bottom: RasqSpacing.sm),
          padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm),
          decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(RasqSizes.radiusLg), border: Border.all(color: u.error ? RasqColors.danger : scheme.outlineVariant)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const RaiIcon(size: 32),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (u.query != null) Text('Q: ${u.query}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                SelectableText(u.text, style: RasqTypography.bodySmall),
                Text(RasqTimestamp.format(u.at), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
            RasqIconButton(
              key: ValueKey('rai.history.copy.$i'),
              icon: Icons.copy,
              size: 18,
              tooltip: 'コピー',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: u.text));
                if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('コピーしました')));
              },
            ),
          ]),
        );
      },
    );
  }
}
