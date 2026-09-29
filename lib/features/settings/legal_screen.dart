import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../backend/legal_docs.g.dart';
import '../../shell/headers.dart';
import '../login/terms_sheet.dart';

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
    return Scaffold(
      appBar: const RasqPageHeader(title: 'ヘルプ、法的表示'),
      body: ListView(children: [
        const RasqSectionHeader(title: 'RASQ'),
        const RasqValueListTile(title: 'バージョン', value: rasqAppVersion),
        RasqListTile(title: 'ヘルプ', onTap: () => context.push('/settings/dsl/about.help')),
        // 規約・ポリシー (D-372): 草案の利用者向け本文から作った文書ページ(tool/legal/build_legal.py)。
        for (final d in rasqLegalDocs.values)
          RasqListTile(key: ValueKey('legal.doc.${d.area}'), title: d.title, onTap: () => context.push('/settings/dsl/${d.area}')),
        RasqListTile(title: 'クッキーについて', onTap: () => context.push('/settings/dsl/about.cookies')),
        const RasqSectionHeader(title: 'SNS プラグインの規約'),
        for (final p in plugins)
          RasqListTile(
            key: ValueKey('legal.plugin.${p.manifest.id}'),
            title: p.manifest.name,
            subtitle: (p.manifest.termsOfService ?? '').trim().isEmpty ? '規約の記載なし' : 'v${p.manifest.version}',
            chevron: (p.manifest.termsOfService ?? '').trim().isNotEmpty,
            onTap: (p.manifest.termsOfService ?? '').trim().isEmpty ? null : () => showTermsSheet(manager, p.manifest),
          ),
        const RasqSectionHeader(title: 'ライセンス'),
        RasqListTile(
          key: const ValueKey('legal.licenses'),
          title: 'オープンソースライセンス',
          subtitle: 'Flutter と同梱ライブラリ',
          onTap: () => showLicensePage(context: context, applicationName: 'RASQ', applicationVersion: rasqAppVersion),
        ),
      ]),
    );
  }
}
