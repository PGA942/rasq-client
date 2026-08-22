import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 利用規約画面 (プラグインごと): キャンセル / プラグインの規約 / 同意.
/// Returns true when the user agreed. No terms → implicit agreement.
Future<bool> showTermsSheet(OverlayManager manager, PluginManifest manifest) async {
  final text = manifest.termsOfService;
  if (text == null || text.trim().isEmpty) return true;
  final res = await manager.showBottomSheet<bool>(
    id: 'terms.${manifest.id}',
    title: 'プラグインの規約',
    confirmText: '同意',
    builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xl),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(manifest.name, style: RasqTypography.title),
            if (manifest.verified) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: Color(0xFF34C759), size: 18)),
            const Spacer(),
            if (manifest.author != null) Text(manifest.author!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: RasqSpacing.md),
          Text(text.trim(), style: RasqTypography.body),
        ]),
      );
    },
  );
  return res == true;
}
