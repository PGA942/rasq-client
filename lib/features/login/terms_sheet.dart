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
            if (manifest.official)
              const Padding(padding: EdgeInsets.only(left: 4), child: RasqBrandIcon(size: 18, semanticsLabel: 'RASQ Official'))
            else if (manifest.verified)
              const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.verified, color: Color(0xFF1E88E5), size: 18)),
            const Spacer(),
            if (manifest.author != null) Text(manifest.author!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: RasqSpacing.md),
          ...termsBlocks(text),
        ]),
      );
    },
  );
  return res == true;
}

/// 規約の Markdown を段落に分けて描く(見出し `##` / `###`、箇条書き `-` / `1.`、字下げの続きの行、`**太字**` の印を外す)。
/// 表やリンクは使わない前提(公式プラグインの規約、assets/legal/plugins)。
List<Widget> termsBlocks(String text) {
  final out = <Widget>[];
  String plain(String s) => s.replaceAll('**', '');
  for (final raw in text.trim().split('\n')) {
    final line = raw.trimRight();
    final s = line.trim();
    if (s.isEmpty) continue;
    if (s.startsWith('## ')) {
      // 題はシートの上に名前があるので、少しだけ大きく。
      out.add(Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.sm), child: Text(plain(s.substring(3)), style: RasqTypography.title)));
    } else if (s.startsWith('### ')) {
      out.add(Padding(
        padding: const EdgeInsets.only(top: RasqSpacing.md, bottom: RasqSpacing.xs),
        child: Text(plain(s.substring(4)), style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700)),
      ));
    } else {
      final bullet = s.startsWith('- ');
      final indent = line.startsWith('   ') ? RasqSpacing.lg : 0.0;
      out.add(Padding(
        padding: EdgeInsets.only(left: indent, bottom: RasqSpacing.xs),
        child: Text(plain(bullet ? '・${s.substring(2)}' : s), style: RasqTypography.body),
      ));
    }
  }
  return out;
}
