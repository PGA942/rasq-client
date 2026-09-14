import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../plugins/slot_plugins.dart';
import '../settings/settings_dsl.dart';
import 'action_bar_config.dart';

/// 投稿のアクションボタンをプラグインが足す (D-176、契約 v0.7 §2.9)。
///
/// - プラグインはマニフェストの `actions` で **希望スロット = タグ** を宣言する。
/// - ホストは SNS アカウントごとに、既存のアクションボタンのタグ(`genreTag` + 別名)と比べ、
///   類似度が閾値(既定 0.85)以上なら **その既存ボタンのバンドルの最下層**に足す
///   (ユーザーのアクションリストに入っていればその末尾、無ければ 既存 + プラグイン の
///   バンドルを自動生成)。届かなければ単体で末尾。
/// - アカウントごとのスロット設定([SlotActionSettings]): ボタンごとの有効 / 無効と閾値。
///   「アクションリストの編集」の「プラグインボタン」節から。

/// ホスト側の id: `slot:<pluginId>:<actionId>`。
String pluginActionId(String pluginId, String actionId) => 'slot:$pluginId:$actionId';

bool isPluginActionId(String id) => id.startsWith('slot:');

/// 登録済みプラグインの `post.action` 宣言(全アカウント共通の候補)。
class PluginAction {
  const PluginAction({required this.plugin, required this.decl});
  final SlotPlugin plugin;
  final SlotActionDecl decl;
  String get id => pluginActionId(plugin.id, decl.id);

  /// アクションバー用の記述子(genreTag = 先頭のタグ)。
  ActionDescriptor get descriptor => ActionDescriptor(
        id: id,
        genreTag: decl.tags.isEmpty ? 'Plugin' : decl.tags.first,
        label: decl.label,
        icon: decl.icon,
        // 押すたびに動く(done で無効化しない)。
        doneIcon: decl.icon,
        countSource: CountSource.none,
      );
}

final pluginActionsProvider = Provider<List<PluginAction>>((ref) => [
      for (final p in ref.watch(slotPluginsForProvider(SlotIds.postAction)))
        for (final a in p.manifest.actions) PluginAction(plugin: p, decl: a),
    ]);

/// 全画面表示プラグインのトグル (D-214): `viewer.overlay` を宣言したプラグイン(QR コード検出など)は
/// **全画面アクションバーのボタン**(ON / OFF)として扱う。id は `slot:<pluginId>:viewer.overlay`。
/// 編集画面の全画面バーの検索に出て、並べ替え / バンドル / 削除(スロット設定で無効)ができる。
const viewerToggleActionId = 'viewer.overlay';

bool isViewerToggleActionId(String id) => isPluginActionId(id) && id.endsWith(':$viewerToggleActionId');

/// `slot:<pluginId>:viewer.overlay` → pluginId。
String viewerTogglePluginId(String id) => id.substring('slot:'.length, id.length - viewerToggleActionId.length - 1);

final viewerPluginActionsProvider = Provider<List<PluginAction>>((ref) => [
      for (final p in ref.watch(slotPluginsForProvider(SlotIds.viewerOverlay)))
        PluginAction(plugin: p, decl: SlotActionDecl(id: viewerToggleActionId, label: p.manifest.name, icon: 'extension', tags: const ['全画面表示'])),
    ]);

/// 構成キーに応じたプラグインボタン: 全画面バー(`viewer:` の構成)には全画面表示プラグインのトグルも含む。
final pluginActionsForProvider = Provider.family<List<PluginAction>, String>((ref, configKey) => [
      ...ref.watch(pluginActionsProvider),
      if (configKey.startsWith('viewer:')) ...ref.watch(viewerPluginActionsProvider),
    ]);

/// アカウントごとのスロット設定(設定エリア `slots.<accountKey>`)。
@immutable
class SlotActionSettings {
  const SlotActionSettings({this.enabled = const {}, this.threshold = defaultThreshold});
  static const defaultThreshold = 0.85;

  /// プラグインボタン id → 有効か。未指定は有効。
  final Map<String, bool> enabled;
  final double threshold;

  bool isEnabled(String id) => enabled[id] ?? true;

  factory SlotActionSettings.fromJson(Map<String, Object?> j) => SlotActionSettings(
        enabled: {for (final e in ((j['enabled'] as Map?) ?? const {}).entries) '${e.key}': e.value == true},
        threshold: (j['threshold'] as num?)?.toDouble() ?? defaultThreshold,
      );
}

String slotSettingsArea(String accountKey) => 'slots.$accountKey';

final slotActionSettingsProvider = Provider.family<SlotActionSettings, String>((ref, accountKey) {
  final v = ref.watch(settingsAreaProvider(slotSettingsArea(accountKey))).value;
  return v == null ? const SlotActionSettings() : SlotActionSettings.fromJson(v);
});

/// 既存ボタンのタグの別名(genreTag / id / label 以外に、よく使われる言い方)。
const _aliases = <String, List<String>>{
  'Reaction': ['Like', 'Favorite', 'Star', 'Heart', 'Emoji'],
  'Repost': ['Boost', 'Renote', 'Reblog', 'Share', 'Retweet'],
  'Reply': ['Comment', 'Respond'],
  'Quote': ['QuoteRepost', 'QuoteNote', 'Repost'],
  'Favorite': ['Bookmark', 'Star', 'Like', 'Clip'],
};

/// 文字 2-gram の Dice 係数(大文字小文字を無視。完全一致 = 1.0)。
double tagSimilarity(String a, String b) {
  final x = a.trim().toLowerCase();
  final y = b.trim().toLowerCase();
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  Map<String, int> grams(String s) {
    final t = ' $s ';
    final out = <String, int>{};
    for (var i = 0; i + 2 <= t.length; i++) {
      final g = t.substring(i, i + 2);
      out[g] = (out[g] ?? 0) + 1;
    }
    return out;
  }
  final ga = grams(x), gb = grams(y);
  var common = 0;
  for (final e in ga.entries) {
    final c = gb[e.key];
    if (c != null) common += e.value < c ? e.value : c;
  }
  final total = ga.values.fold(0, (s, v) => s + v) + gb.values.fold(0, (s, v) => s + v);
  return total == 0 ? 0 : 2 * common / total;
}

/// 既存ボタンのタグ集合(genreTag / id / label + 別名)。
List<String> actionTags(ActionDescriptor a) => [a.genreTag, a.id, a.label, ...(_aliases[a.genreTag] ?? const [])];

/// プラグインボタンの希望スロットに最も近い既存ボタンとその類似度。
({ActionDescriptor action, double score})? bestMatch(List<String> tags, List<ActionDescriptor> existing) {
  ({ActionDescriptor action, double score})? best;
  for (final a in existing) {
    if (isPluginActionId(a.id)) continue;
    var score = 0.0;
    for (final t in tags) {
      for (final u in actionTags(a)) {
        final s = tagSimilarity(t, u);
        if (s > score) score = s;
      }
    }
    if (best == null || score > best.score) best = (action: a, score: score);
  }
  return best;
}

/// SNS のアクション + 有効なプラグインボタン → (全記述子, バンドル込みの構成)。
///
/// プラグインボタンは既存ボタンのバンドルへ: 既存ボタンがユーザーのアクションリストにあれば
/// その末尾に、無ければ `auto:<既存 id>` のリスト(既存 + プラグイン)を作って既存ボタンの位置に置く。
({List<ActionDescriptor> actions, ActionBarConfig config}) mergePluginActions({
  required ActionBarConfig config,
  required List<ActionDescriptor> snsActions,
  required List<PluginAction> plugins,
  required SlotActionSettings settings,
}) {
  final enabled = [for (final p in plugins) if (settings.isEnabled(p.id)) p];
  if (enabled.isEmpty) return (actions: snsActions, config: config);
  final all = [...snsActions, for (final p in enabled) p.descriptor];
  final lists = [for (final l in config.lists) l];
  final order = [...config.order];
  final placedInOrder = order.toSet();
  for (final p in enabled) {
    // 既に構成に入っている(ユーザーが並べ替えた / リストに入れた)ならそのまま。
    if (placedInOrder.contains(p.id) || lists.any((l) => l.memberIds.contains(p.id))) continue;
    final m = bestMatch(p.decl.tags, snsActions);
    if (m == null || m.score < settings.threshold) continue;
    final target = m.action.id;
    final li = lists.indexWhere((l) => l.memberIds.contains(target));
    if (li >= 0) {
      final l = lists[li];
      lists[li] = l.copyWith(memberIds: [...l.memberIds, p.id]);
    } else {
      final id = 'auto:$target';
      final ai = lists.indexWhere((l) => l.id == id);
      if (ai >= 0) {
        final l = lists[ai];
        lists[ai] = l.copyWith(memberIds: [...l.memberIds, p.id]);
      } else {
        lists.add(ActionListDef(id: id, name: m.action.label, memberIds: [target, p.id]));
        // 既存ボタンの位置に自動バンドルを置く(order に無ければ apply が末尾に足す)。
        final key = ActionBarConfig.listKey(id);
        final at = order.indexOf(target);
        if (at >= 0) {
          order[at] = key;
        }
      }
    }
  }
  return (actions: all, config: config.copyWith(order: order, lists: lists));
}
