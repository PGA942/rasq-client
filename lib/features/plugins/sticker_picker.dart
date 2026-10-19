import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:rasq_design/rasq_design.dart';

import '../home/plugin_actions.dart';
import '../home/post_row.dart';
import '../../l10n/l10n.dart';
import '../store/sticker_packs.dart';

/// 加工画面のステッカー一覧 (D-252): pro_image_editor の `StickerEditorConfigs.builder` の中身。
///
/// - 上に「プラグインで作る」: `output: "sticker"` を宣言した `composer.media` のボタン(ジェネレーター)。
/// - その下にインストール済みのアセットパックごとの節(契約 v0.11 §2.10)。タップでレイヤーとして置く。
class StickerPicker extends ConsumerWidget {
  const StickerPicker({super.key, required this.setLayer, required this.scrollController, required this.generators, required this.onGenerate});
  final void Function(WidgetLayer layer) setLayer;
  final ScrollController scrollController;

  /// `output: "sticker"` のプラグインボタン(この添付に出るもの)。
  final List<PluginAction> generators;
  final void Function(PluginAction action) onGenerate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packs = ref.watch(stickerPacksProvider);
    final scheme = Theme.of(context).colorScheme;
    final empty = packs.every((p) => p.stickers.isEmpty) && generators.isEmpty;
    return Material(
      color: scheme.surface,
      child: empty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(RasqSpacing.page),
                child: Text(rasqDetail(context, context.l10n.pluginsMediaStickerEmpty, context.l10n.pluginsMediaStickerEmptyDetail), style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant), textAlign: TextAlign.center),
              ),
            )
          : ListView(controller: scrollController, padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
              if (generators.isNotEmpty) ...[
                RasqSectionHeader(title: context.l10n.pluginsMediaStickerGenerate),
                for (final g in generators)
                  RasqListTile(
                    key: ValueKey('sticker.generate.${g.id}'),
                    leading: Icon(PostRow.iconFor(g.decl.icon, Icons.extension_outlined), color: RasqColors.accent),
                    title: g.decl.label,
                    subtitle: g.plugin.manifest.name,
                    onTap: () => onGenerate(g),
                  ),
              ],
              for (final p in packs)
                if (p.stickers.isNotEmpty) ...[
                  RasqSectionHeader(title: p.name),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                    child: Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.sm, children: [
                      for (final s in p.stickers)
                        Tooltip(
                          message: s.label ?? s.id,
                          child: InkWell(
                            key: ValueKey('sticker.${p.id}.${s.id}'),
                            borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
                            onTap: () => setLayer(WidgetLayer(widget: Image.file(File(s.file), fit: BoxFit.contain, gaplessPlayback: true))),
                            child: Container(
                              width: 72,
                              height: 72,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
                              child: Image.file(File(s.file), fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ],
            ]),
    );
  }
}
