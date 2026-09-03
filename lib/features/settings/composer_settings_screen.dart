import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

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
    return Scaffold(
      appBar: const RasqPageHeader(title: '投稿コンポーザー'),
      body: ListView(children: [
        RasqSwitchListTile(
          title: '投稿アカウントの自動選択',
          subtitle: '下書きの内容がポスト先の絞り込みに合うアカウントへ、投稿先を自動で切り替えます(手動選択が常に優先)',
          value: autoAccount,
          onChanged: (v) => ref.read(settingsAreaProvider('composer.prefs').notifier).set('autoAccount', v),
        ),
      ]),
    );
  }
}
