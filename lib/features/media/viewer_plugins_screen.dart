import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../plugins/slot_plugins.dart';
import '../settings/settings_dsl.dart';

/// 全画面表示プラグインの編集 (D-205): 全画面の「…」→「全画面表示プラグイン」。
/// スロット `viewer.overlay` のプラグインを一覧し、有効 / 無効を切り替える(設定エリア `slots.viewer`)。
/// ストア由来のものはストアのページへ。無ければストアで探す。
const viewerPluginsSettingsArea = 'slots.viewer';

String viewerPluginEnabledKey(String id) => 'enabled.$id';

/// 有効な全画面表示プラグイン(ビューワーが画像を渡す相手)。
final viewerOverlayPluginsProvider = Provider<List<SlotPlugin>>((ref) {
  final all = ref.watch(slotPluginsForProvider(SlotIds.viewerOverlay));
  final v = ref.watch(settingsAreaProvider(viewerPluginsSettingsArea)).value ?? const <String, Object?>{};
  return [for (final p in all) if (v[viewerPluginEnabledKey(p.id)] != false) p];
});

class ViewerPluginsScreen extends ConsumerWidget {
  const ViewerPluginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final all = ref.watch(slotPluginsForProvider(SlotIds.viewerOverlay));
    final v = ref.watch(settingsAreaProvider(viewerPluginsSettingsArea)).value ?? const <String, Object?>{};
    return Scaffold(
      appBar: AppBar(title: const Text('全画面表示プラグイン'), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: '戻る', onPressed: () => context.pop())),
      body: ListView(padding: const EdgeInsets.symmetric(vertical: RasqSpacing.sm), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
          child: Text('全画面表示の画像をプラグインに渡し、検出した枠などを重ねます。無効にしたプラグインには渡しません。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Column(children: [
              Text('全画面表示プラグインはまだありません', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
              const SizedBox(height: RasqSpacing.md),
              FilledButton.icon(key: const ValueKey('viewer.plugins.store'), onPressed: () => context.push(Routes.store), icon: const Icon(Icons.storefront_outlined), label: const Text('ストアで探す')),
            ]),
          ),
        for (final p in all)
          SwitchListTile(
            key: ValueKey('viewer.plugins.${p.id}'),
            title: Text(p.manifest.name, style: RasqTypography.body),
            subtitle: p.manifest.description.isEmpty ? null : Text(p.manifest.description, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
            secondary: p.source.startsWith('store:')
                ? RasqIconButton(icon: Icons.storefront_outlined, tooltip: 'ストアのページ', onPressed: () => context.push(Routes.storePlugin(p.source.substring('store:'.length))))
                : null,
            value: v[viewerPluginEnabledKey(p.id)] != false,
            onChanged: (on) => ref.read(settingsAreaProvider(viewerPluginsSettingsArea).notifier).set(viewerPluginEnabledKey(p.id), on),
          ),
        if (all.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: OutlinedButton.icon(key: const ValueKey('viewer.plugins.store'), onPressed: () => context.push(Routes.store), icon: const Icon(Icons.storefront_outlined), label: const Text('ストアで探す')),
          ),
      ]),
    );
  }
}
