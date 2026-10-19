import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import 'settings_dsl.dart';

/// 「その他の設定 → 投稿コンポーザー」 (D-131)。
/// KV `composer.prefs.v1`(アカウント非依存のグローバル設定)。
class ComposerSettingsScreen extends ConsumerWidget {
  const ComposerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final area = ref.watch(settingsAreaProvider('composer.prefs')).value ?? const <String, Object?>{};
    final autoAccount = area['autoAccount'] != false;
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.settingsComposerTitle),
      body: ListView(children: [
        RasqSwitchListTile(
          title: l.settingsComposerAutoAccountTitle,
          subtitle: l.settingsComposerAutoAccountSubtitle,
          detail: l.settingsComposerAutoAccountDetail,
          value: autoAccount,
          onChanged: (v) => ref.read(settingsAreaProvider('composer.prefs').notifier).set('autoAccount', v),
        ),
        // RASQ への連動投稿 (D-286)。
        RasqSwitchListTile(
          key: const ValueKey('composerPrefs.rasqLinked'),
          title: l.settingsComposerRasqLinkedTitle,
          subtitle: l.settingsComposerRasqLinkedSubtitle,
          detail: l.settingsComposerRasqLinkedDetail,
          value: area['rasqLinked'] == true,
          onChanged: (v) => ref.read(settingsAreaProvider('composer.prefs').notifier).set('rasqLinked', v),
        ),
      ]),
    );
  }
}
