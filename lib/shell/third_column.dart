import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import '../features/search/search_screen.dart';
import '../features/settings/settings_dsl.dart';

/// 第3カラム (M5b/D-056): タブレット幅(≥840dp)の右カラム。
///
/// - **何も開いていないとき**は検索(既定)。KV `thirdColumn.v1` の
///   `empty` キーで変更できる(`search` / `none` — カラムヘッダーの歯車から)。
/// - features は [ThirdColumnStore.open] で補助面を開ける。M5c 以降、FOW の
///   「掴んで第3カラムへ移動」の移動先・RRL surface のホストになる。
class ThirdColumnEntry {
  const ThirdColumnEntry({required this.id, required this.title, required this.builder});
  final String id;
  final String title;
  final WidgetBuilder builder;
}

class ThirdColumnStore extends Notifier<ThirdColumnEntry?> {
  @override
  ThirdColumnEntry? build() => null;

  void open(ThirdColumnEntry entry) => state = entry;

  void close([String? id]) {
    if (id == null || state?.id == id) state = null;
  }
}

final thirdColumnProvider = NotifierProvider<ThirdColumnStore, ThirdColumnEntry?>(ThirdColumnStore.new);

/// 第3カラムの中身。empty 設定は設定 DSL と同じ KV 規約(`thirdColumn.v1`)。
class ThirdColumnView extends ConsumerWidget {
  const ThirdColumnView({super.key});

  static const _emptyChoices = <(String, String)>[('search', '検索'), ('none', '表示しない')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final entry = ref.watch(thirdColumnProvider);
    if (entry != null) {
      return Column(children: [
        SizedBox(
          height: 40,
          child: Row(children: [
            const SizedBox(width: RasqSpacing.md),
            Expanded(child: Text(entry.title, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
            RasqIconButton(icon: Icons.close, size: 20, tooltip: '閉じる', onPressed: () => ref.read(thirdColumnProvider.notifier).close()),
            const SizedBox(width: 4),
          ]),
        ),
        Divider(height: 1, color: scheme.outlineVariant),
        Expanded(child: Builder(builder: entry.builder)),
      ]);
    }

    final empty = settingValue(ref, 'thirdColumn', 'empty', 'search') as String? ?? 'search';
    return Column(children: [
      SizedBox(
        height: 32,
        child: Row(children: [
          const Spacer(),
          Builder(builder: (ctx) {
            return RasqIconButton(
              icon: Icons.settings,
              size: 18,
              tooltip: '第3カラムの設定',
              onPressed: () async {
                final box = ctx.findRenderObject() as RenderBox;
                final anchor = box.localToGlobal(Offset.zero) & box.size;
                final manager = ref.read(overlayManagerProvider);
                final picked = await manager.showDropdown<String>(id: 'thirdColumn.empty', anchor: anchor, dense: true, items: [
                  for (final (v, label) in _emptyChoices) RasqDropdownItem(label, v, checked: v == empty),
                ]);
                if (picked != null) await ref.read(settingsAreaProvider('thirdColumn').notifier).set('empty', picked);
              },
            );
          }),
          const SizedBox(width: 4),
        ]),
      ),
      Expanded(
        child: switch (empty) {
          'none' => const RasqEmptyView(title: '第3カラム', hint: 'FOW をここへ移動できます(M5c)'),
          _ => const SearchScreen(),
        },
      ),
    ]);
  }
}
