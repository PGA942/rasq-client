import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../plugins/slot_plugins.dart';
import 'plugin_actions.dart';

/// `post.action` の temp = タイルごとに 1 回の自動実行 (契約 v0.14 §2.9、D-305)。v0.13 までの `auto_hook`(フック)の置き換えで、
/// 権限 `auto_hook` は「`auto: true` を書ける」の意味。審査済み(ストアから)で `auto_hook` を持ち、`destructive` /
/// `autoHookForbidden` でないボタン([PluginAction.canAutoRun])が、switch オン・このアカウントで有効・temp オンのとき、
/// タイルが作られた直後に `post.action {…, "auto": true}` を 1 回呼ばれる。FOW は開かず(契約でプラグインに求める)、
/// `message` もトーストに出さない。
///
/// 「1 回」の単位は 投稿(key)× ボタン(ActionKey)で、アプリを起動している間(= TL のセッション)覚える。
final postActionAutoRunsProvider = NotifierProvider<PostActionAutoRuns, Set<String>>(PostActionAutoRuns.new);

class PostActionAutoRuns extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// まだ走らせていなければ記録して true。
  bool claim(String postKey, String actionId) {
    final key = '$postKey|$actionId';
    if (state.contains(key)) return false;
    state = {...state, key};
    return true;
  }
}

/// 自動実行の候補があるか(タイルの build ごとの早い判定)。
bool hasAutoPostActions(List<PluginAction> plugins) => plugins.any((a) => a.canAutoRun);

/// [postKey] のタイルが作られた: 自動実行するボタンを 1 回ずつ呼ぶ。[settingsKey] = アカウントごとのスロット設定のキー。
Future<void> runAutoPostActions(
  WidgetRef ref, {
  required String postKey,
  required String settingsKey,
  required List<PluginAction> plugins,
  required Map<String, Object?> payload,
  required Map<String, Object?> account,
  required void Function(String text, Uint8List? media, String? mime, String? name) onComposerOpen,
  int column = 0,
}) async {
  final prefs = ref.read(actionButtonPrefsProvider);
  final settings = ref.read(slotActionSettingsProvider(settingsKey));
  final runs = ref.read(postActionAutoRunsProvider.notifier);
  final slots = ref.read(slotPluginsProvider.notifier);
  final targets = [for (final a in plugins) if (a.canAutoRun && settings.isEnabled(a.id) && a.effectiveAuto(prefs) && runs.claim(postKey, a.id)) a];
  for (final a in targets) {
    await slots.postAction(a.plugin, actionId: a.decl.id, post: payload, account: account, onComposerOpen: onComposerOpen, column: column, auto: true);
  }
}
