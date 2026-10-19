import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/plugin_actions.dart';
import '../plugins/slot_plugins.dart';
import 'settings_dsl.dart';

/// 設定 → SNSプラグイン →「プラグインボタン」(D-210 → D-305、契約 v0.14 §2.11)。
///
/// 面ごとの節(投稿タイル / 全画面 / 加工画面 / コンポーザー本文 / 投稿加工(自動))に、宣言されたボタンを並べる。
/// 行 = ボタン名 + 提供元 + 配置の説明 + **switch**(端末全体の主電源。オフなら全アカウント・全面で出ず、自動でも動かない)、
/// その下に **temp**「面を開いたとき自動でオン」(面が作られた瞬間の初期状態の上書き。状態を持たない post.action は
/// `auto_hook` 権限のある審査済みプラグインだけ)。
/// 末尾の「このアカウント」に、従来のアカウントごとの有効 / 無効と束ねる閾値(設定エリア `slots.<accountKey>`、D-176)。
class ActionBarPluginsScreen extends ConsumerWidget {
  const ActionBarPluginsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(currentAccountProvider);
    final accountKey = account?.key ?? '';
    final session = ref.watch(currentSnsSessionProvider);
    final snsActions = session?.actions ?? const <ActionDescriptor>[];
    final settings = ref.watch(slotActionSettingsProvider(accountKey));
    final settingsStore = ref.read(settingsAreaProvider(slotSettingsArea(accountKey)).notifier);
    final editorSettings = ref.watch(slotActionSettingsProvider('editor'));
    final prefs = ref.watch(actionButtonPrefsProvider);
    final prefsStore = ref.read(settingsAreaProvider(actionButtonPrefsArea).notifier);
    final postActions = ref.watch(pluginActionsProvider);
    Future<void> setEnabled(String id, bool on) => settingsStore.set('enabled', {...settings.enabled, id: on});

    /// バンドル先の説明(投稿タイル / 加工画面)。
    String bundleOf(PluginAction p, List<ActionDescriptor> existing, double threshold) {
      if (p.isManual) return '手動配置(バーの (+) から足すまで出ない)';
      final m = bestMatch(p.decl.tags, existing);
      return m == null || m.score < threshold ? '単体で末尾' : '「${m.action.label}」のバンドル(${(m.score * 100).round()}%)';
    }

    Widget hint(String text, [String? detail]) =>
        RasqCaption(text, detail: detail, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm));

    /// ボタン 1 つ: switch の行と、temp を持つものは「面を開いたとき自動でオン」の行。
    List<Widget> rows(PluginAction p, String placement) {
      final on = prefs.switchOn(p.id);
      final override = prefs.autoOverride(p.id);
      return [
        RasqSwitchListTile(
          key: ValueKey('actionbar.switch.${p.id}'),
          title: p.decl.label,
          subtitle: '${p.plugin.manifest.name} · $placement',
          value: on,
          onChanged: (v) => setActionSwitch(prefsStore, prefs, p.id, v),
        ),
        if (p.hasTemp)
          RasqSwitchListTile(
            key: ValueKey('actionbar.auto.${p.id}'),
            leading: Icon(Icons.subdirectory_arrow_right, size: 18, color: scheme.onSurfaceVariant),
            title: '面を開いたとき自動でオン',
            subtitle: override == null ? '既定(${p.declaredAuto ? 'オン' : 'オフ'}${p.plugin.isReviewed && p.decl.auto != null ? '、プラグインの宣言' : ''})' : '設定で上書き中(既定は ${p.declaredAuto ? 'オン' : 'オフ'})',
            value: override ?? p.declaredAuto,
            enabled: on,
            onChanged: (v) => setActionAuto(prefsStore, prefs, p.id, v),
          ),
      ];
    }

    List<Widget> section(String title, String emptyDetail, List<PluginAction> actions, String Function(PluginAction) placement) => [
          RasqSectionHeader(title: title),
          if (actions.isEmpty) hint('ストアで追加したプラグインがここに並びます', emptyDetail),
          for (final p in actions) ...rows(p, placement(p)),
        ];

    // 投稿加工(自動、ボタン無し): switch だけ(ActionKey `slot:<pluginId>:post.transform`)。
    final transforms = [
      for (final p in ref.watch(slotPluginsForProvider(SlotIds.postTransform)))
        PluginAction(plugin: p, decl: SlotActionDecl(id: SlotIds.postTransform, label: p.manifest.name, slot: SlotIds.postTransform)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('プラグインボタン'), centerTitle: false, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: '戻る', onPressed: () => context.pop())),
      body: ListView(children: [
        hint('スイッチを切ると、すべてのアカウントで出なくなります。', 'スイッチは端末全体の主電源(オフなら全アカウント・全面で出ず、自動でも動きません)。「面を開いたとき自動でオン」は、その面を開いた瞬間の初期状態です(面の中で切り替えた値は次に持ち越しません)。'),
        ...section('投稿タイル', 'post.action を宣言したプラグインがここに並びます(ストアから追加)', postActions, (p) => bundleOf(p, snsActions, settings.threshold)),
        ...section('全画面', 'viewer.overlay を宣言したプラグイン(QR コード検出など)がここに並びます', ref.watch(viewerPluginActionsProvider), (_) => '全画面アクションバーの ON / OFF ボタン'),
        ...section('加工画面', 'composer.media を宣言したプラグインがここに並びます', ref.watch(mediaPluginActionsProvider), (p) => '${p.decl.isFilterOutput ? 'フィルター · ' : ''}${bundleOf(p, editorBuiltinActions, editorSettings.threshold)}'),
        ...section('コンポーザー本文', 'composer.text を宣言したプラグインがここに並びます', ref.watch(composerTextPluginActionsProvider), (_) => 'コンポーザーのアクションバーの ON / OFF ボタン(長押しで設定)'),
        ...section('投稿加工(自動)', 'post.transform を宣言したプラグインがここに並びます', transforms, (_) => '表示前に本文を加工(ボタン無し)'),
        RasqSectionHeader(title: 'このアカウント(${account == null ? '未選択' : '$account'})'),
        if (postActions.isEmpty) hint('このアカウントで出すかどうか', '投稿タイルのボタンを、このアカウントで出すかどうか'),
        for (final p in postActions)
          RasqSwitchListTile(
            key: ValueKey('actionbar.slot.${p.id}'),
            title: p.decl.label,
            subtitle: '${p.plugin.manifest.name} · タグ: ${p.decl.tags.join(' / ')}',
            value: settings.isEnabled(p.id),
            enabled: prefs.switchOn(p.id),
            onChanged: (v) => setEnabled(p.id, v),
          ),
        RasqSliderListTile(
          key: const ValueKey('actionbar.slot.threshold'),
          title: '束ねる閾値',
          subtitle: '似たボタンをまとめる度合い',
          detail: 'タグの類似度がこれ以上なら既存ボタンのバンドルに入る',
          value: settings.threshold * 100,
          min: 50,
          max: 100,
          divisions: 10,
          valueLabel: '${(settings.threshold * 100).round()}%',
          onChanged: (v) => settingsStore.set('threshold', v / 100),
        ),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.md),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(key: const ValueKey('actionbar.plugins.edit'), onPressed: () => showActionBarEditSheet(ref), icon: const Icon(Icons.tune, size: 18), label: const Text('アクションバーを編集')),
          ),
        ),
      ]),
    );
  }
}
