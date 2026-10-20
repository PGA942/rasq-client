import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../backend/legal_docs.g.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../login/terms_sheet.dart';
import '../onboarding/feature_tour.dart' show featureTourLocation;

/// アプリのバージョン(pubspec の version と揃える。package_info は入れていない)。
const rasqAppVersion = '0.1.0+1';

/// ヘルプ、法的表示 (D-238): バージョン、文書(ヘルプ / 規約 / ポリシー / クッキー)、入っている SNS プラグインの規約、
/// オープンソースライセンス。
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugins = ref.watch(pluginRegistryProvider).plugins;
    final manager = ref.read(overlayManagerProvider);
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.settingsLegalTitle),
      body: ListView(children: [
        const RasqSectionHeader(title: 'RASQ'),
        RasqValueListTile(title: l.settingsLegalVersionTitle, value: rasqAppVersion),
        RasqListTile(title: l.settingsLegalHelpTitle, onTap: () => context.push('/settings/dsl/about.help')),
        // RASQ の機能の紹介 (D-471) をもう一度。
        RasqListTile(key: const ValueKey('legal.tour'), title: l.settingsLegalTourTitle, onTap: () => context.push(featureTourLocation(again: true))),
        // 規約・ポリシー (D-372): 草案の利用者向け本文から作った文書ページ(tool/legal/build_legal.py)。
        for (final MapEntry(key: id, value: d) in rasqLegalDocs.entries)
          RasqListTile(key: ValueKey('legal.doc.${d.area}'), title: legalDocTitle(id, d.title, l.localeName), onTap: () => context.push('/settings/dsl/${d.area}')),
        RasqListTile(title: l.settingsLegalCookiesTitle, onTap: () => context.push('/settings/dsl/about.cookies')),
        RasqSectionHeader(title: l.settingsLegalPluginTermsHeader),
        for (final p in plugins)
          RasqListTile(
            key: ValueKey('legal.plugin.${p.manifest.id}'),
            title: p.manifest.name,
            subtitle: (p.manifest.termsOfService ?? '').trim().isEmpty ? l.settingsLegalPluginNoTerms : 'v${p.manifest.version}',
            chevron: (p.manifest.termsOfService ?? '').trim().isNotEmpty,
            onTap: (p.manifest.termsOfService ?? '').trim().isEmpty ? null : () => showTermsSheet(manager, p.manifest),
          ),
        RasqSectionHeader(title: l.settingsLegalLicensesHeader),
        RasqListTile(
          key: const ValueKey('legal.licenses'),
          title: l.settingsLegalLicensesTitle,
          subtitle: l.settingsLegalLicensesSubtitle,
          onTap: () => showLicensePage(context: context, applicationName: 'RASQ', applicationVersion: rasqAppVersion),
        ),
      ]),
    );
  }
}

/// 文書の題を表示の言語で。参考訳([rasqLegalTranslations])が無い言語は日本語の題 [fallback]。
/// [localeName] は gen-l10n の `zh_Hant` の形。
String legalDocTitle(String docId, String fallback, String localeName) {
  final tr = rasqLegalTranslations[docId];
  if (tr == null) return fallback;
  final tag = localeName.replaceAll('_', '-');
  return (tr[tag] ?? tr[tag.split('-').first])?.title ?? fallback;
}
