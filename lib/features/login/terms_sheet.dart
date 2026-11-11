import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import '../../l10n/l10n.dart';

/// 規約の FOW で、何のために同意するか (D-557)。下のボタンの文言が変わる。
enum TermsPurpose {
  /// 「同意してログイン」。
  login,

  /// 「同意して新規登録」。
  signup,

  /// 読むだけ(設定 → 法務)。「閉じる」だけ。
  view,
}

/// 規約の FOW のボタンのキー(テスト用)。
const termsAgreeKey = ValueKey('plugin.terms.agree');
const termsCancelKey = ValueKey('plugin.terms.cancel');

/// 利用規約画面 (プラグインごと、ワイヤーフレーム p.4)。見出しは題だけ、**ボタンは FOW の下**(D-557):
/// 「同意してログイン」/「同意して新規登録」と「キャンセル」。余白を押す / 戻る も キャンセル。
/// 同意したら true。規約の無いプラグインは、出さずに同意したことにする。
Future<bool> showTermsSheet(OverlayManager manager, PluginManifest manifest, {TermsPurpose purpose = TermsPurpose.login}) async {
  final text = manifest.termsOfService;
  if (text == null || text.trim().isEmpty) return purpose != TermsPurpose.view;
  final res = await manager.showFow<bool>(
    id: 'terms.${manifest.id}',
    spec: FowSpec(title: appL10n.loginTermsTitle, initialHeightFactor: 0.8, minHeightFactor: 0.4, maxHeightFactor: 0.92),
    semanticsLabel: appL10n.loginTermsTitle,
    barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
    builder: (context, handle) {
      final scheme = Theme.of(context).colorScheme;
      final l10n = context.l10n;
      final agreeLabel = switch (purpose) { TermsPurpose.login => l10n.loginTermsAgreeLogin, TermsPurpose.signup => l10n.loginTermsAgreeSignup, TermsPurpose.view => null };
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.lg),
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
          ),
        ),
        // 下のボタン(上に細い線)。
        Container(
          key: const ValueKey('plugin.terms.footer'),
          padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(border: Border(top: fowRimSide(scheme))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            if (agreeLabel != null)
              FilledButton(key: termsAgreeKey, onPressed: () => handle.close(result: true), style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)), child: Text(agreeLabel)),
            if (agreeLabel != null) const SizedBox(height: RasqSpacing.xs),
            OutlinedButton(
              key: termsCancelKey,
              onPressed: handle.cancel,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: Text(agreeLabel == null ? l10n.loginTermsClose : l10n.loginTermsCancel),
            ),
          ]),
        ),
      ]);
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
        child: Text(plain(bullet ? appL10n.loginTermsBullet(s.substring(2)) : s), style: RasqTypography.body),
      ));
    }
  }
  return out;
}
