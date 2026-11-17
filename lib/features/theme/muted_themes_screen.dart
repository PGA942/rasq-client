import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import 'icon_theme/icon_theme_backdrop.dart' show iconThemeBackground, themeColor;
import 'icon_theme/rasq_theme_spec.dart';
import 'theme_display.dart';

/// 設定 → フォントやカラースキーム →「ミュートしたテーマ」(D-587)。テーマを出しているページの「…」からミュートしたものの一覧と解除。
/// ミュートは値で覚えている(同じ値のテーマは、誰のものでも出ない)。見本は覚えた値から描く。
class MutedThemesScreen extends ConsumerWidget {
  const MutedThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final muted = ref.watch(mutedThemesProvider);
    return Scaffold(
      appBar: RasqPageHeader(title: l.themeMutedTitle),
      body: muted.isEmpty
          ? RasqEmptyView(key: const ValueKey('theme.muted.empty'), title: l.themeMutedEmpty, hint: l.themeMutedEmptyHint)
          : ListView(children: [
              RasqCaption(l.themeMutedCaption, padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, RasqSpacing.xs)),
              for (final m in muted)
                RasqListTile(
                  key: ValueKey('theme.muted.${m.hash}'),
                  leading: _Swatch(spec: m.spec),
                  title: switch (m.origin) {
                    ThemeOrigin.atmos => l.themeOriginAtmos,
                    ThemeOrigin.community => l.themeOriginCommunity,
                    _ => l.themeOriginIcon,
                  },
                  subtitle: m.mutedAt == null ? null : RasqDateFormat.yearMonth(m.mutedAt!.toLocal()),
                  chevron: false,
                  trailing: TextButton(key: ValueKey('theme.muted.${m.hash}.unmute'), onPressed: () => unmuteTheme(ref, m.hash), child: Text(l.themeUnmute)),
                ),
            ]),
    );
  }
}

/// 色の見本(背景の上に強調色の丸と文字色の線)。値が読めなければ灰色。
class _Swatch extends StatelessWidget {
  const _Swatch({required this.spec});
  final RasqThemeSpec? spec;

  @override
  Widget build(BuildContext context) {
    final s = spec;
    return SizedBox.square(
      dimension: 40,
      child: DecoratedBox(
        decoration: s == null ? BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)) : _rounded(iconThemeBackground(s.basic)),
        child: s == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: themeColor(s.basic.accent), shape: BoxShape.circle)),
                  Container(height: 3, decoration: BoxDecoration(color: themeColor(s.basic.text), borderRadius: BorderRadius.circular(2))),
                ]),
              ),
      ),
    );
  }

  static Decoration _rounded(Decoration d) => d is BoxDecoration ? d.copyWith(borderRadius: BorderRadius.circular(8)) : d;
}
