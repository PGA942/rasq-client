import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../home/action_bar_config.dart';
import '../home/plugin_actions.dart';
import '../plugins/slot_plugins.dart';

/// AsTell のルームの下段、入力欄の左の丸いボタンの並び (D-324)。
///
/// 構成は投稿のアクションバーと同じ仕組み([ActionBarConfig]、構成キー [astellBarConfigKey] = 端末ごと。アカウントに依らない)で、
/// 編集も「アクションバーの編集」FOW の 1 面(`ActionBarSurface.astell`)。並べ替え / 非表示(`hidden`)/ (+) で追加 / バンドルができる。
/// 選べるのは [astellBarBuiltinActions](今のボタン)と、スロット `astell.action` のプラグインのボタン([astellPluginActionsProvider])。
///
/// **ボタンの種類を足すとき**(挙手など): [AstellBarIds] に id、[astellBarBuiltinActions] の既定の位置に記述子を 1 行足し、
/// ルームの画面(`astell_fows.dart` の `_barButtons`)で今の状態の見た目と動きを返す。保存済みの並びにも、既定の並びの位置に入る
/// ([astellBarWithNewDefaults])。
const astellBarConfigKey = 'astell:room';

/// 今のボタンの id。
abstract final class AstellBarIds {
  static const speaker = 'astell.speaker';
  static const mic = 'astell.mic';
  static const screen = 'astell.screen';

  /// 共有枠にピアの画面があるときだけ出る。
  static const fullscreen = 'astell.fullscreen';

  /// スロット `astell.action` のプラグインを選んで開く(1 つなら即開く)。
  static const plugins = 'astell.plugins';
  static const captions = 'astell.captions';
}

/// 既定の並び = これまでの下段の並び(スピーカー / マイク / 画面共有 / 全画面 / プラグイン / 字幕)。
/// アイコン名は編集画面のタイルと (+) の検索に出るもの(下段では状態に応じたアイコンを出す)。
const astellBarBuiltinActions = <ActionDescriptor>[
  ActionDescriptor(id: AstellBarIds.speaker, genreTag: 'Speaker', label: 'スピーカー', icon: 'volume_up', doneIcon: 'volume_up', countSource: CountSource.none),
  ActionDescriptor(id: AstellBarIds.mic, genreTag: 'Mic', label: 'マイク', icon: 'mic', doneIcon: 'mic', countSource: CountSource.none),
  ActionDescriptor(id: AstellBarIds.screen, genreTag: 'Screen', label: '画面共有', icon: 'desktop_windows', doneIcon: 'desktop_windows', countSource: CountSource.none),
  ActionDescriptor(id: AstellBarIds.fullscreen, genreTag: 'Fullscreen', label: '全画面(共有枠に画面があるとき)', icon: 'fullscreen', doneIcon: 'fullscreen', countSource: CountSource.none),
  ActionDescriptor(id: AstellBarIds.plugins, genreTag: 'PluginPicker', label: 'プラグインアクション', icon: 'extension', doneIcon: 'extension', countSource: CountSource.none),
  ActionDescriptor(id: AstellBarIds.captions, genreTag: 'Captions', label: '字幕(文字起こし)', icon: 'subtitles', doneIcon: 'subtitles', countSource: CountSource.none),
];

// ── プラグインのボタン ──────────────────────────────────────────────

/// `astell.action` のプラグインのボタンの id は `slot:<pluginId>:astell.action`(宣言の `id` に依らない)。
const astellPluginActionId = SlotIds.astellAction;

bool isAstellPluginActionId(String id) => isPluginActionId(id) && id.endsWith(':$astellPluginActionId');

/// 見た目はマニフェストの `actions` の `slot: "astell.action"` の項目(label / icon / tags)、無ければプラグイン名 + パズルのアイコン。
/// **宣言が無ければ手動配置**((+) で足すまで出ない。既定の並び = これまでの並びを変えない)。宣言があればその placement。
SlotActionDecl astellActionDecl(SlotManifest m) {
  final declared = m.actions.where((a) => a.slot == SlotIds.astellAction).firstOrNull;
  return SlotActionDecl(
    id: astellPluginActionId,
    label: declared?.label ?? m.name,
    icon: declared?.icon ?? 'extension',
    tags: declared?.tags ?? const [],
    slot: SlotIds.astellAction,
    placement: declared?.placement ?? SlotActionDecl.placementManual,
  );
}

/// スロット `astell.action` のプラグインのボタン(1 プラグイン = 1 ボタン。押すとそのプラグインの `astell.open`)。
final astellPluginActionsProvider = Provider<List<PluginAction>>((ref) => [
      for (final p in ref.watch(slotPluginsForProvider(SlotIds.astellAction))) PluginAction(plugin: p, decl: astellActionDecl(p.manifest)),
    ]);

// ── 下段の組み立て ──────────────────────────────────────────────────

/// 下段の 1 つのボタンの、今の状態での見た目と動き(ルームの画面が組み立てる)。
@immutable
class AstellBarButton {
  const AstellBarButton({required this.icon, required this.tooltip, this.onPressed, this.filled});
  final IconData icon;

  /// ツールチップ = バンドル / 歯車のメニューでの名前(今の状態で押すと何が起きるか)。
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? filled;
}

/// 下段の 1 枠: 単体のボタン or バンドル(押すとバンドル FOW)。
sealed class AstellBarItem {
  const AstellBarItem();
  String get key;
}

class AstellBarSingle extends AstellBarItem {
  const AstellBarSingle(this.id, this.button);
  final String id;
  final AstellBarButton button;
  @override
  String get key => id;
}

class AstellBarBundle extends AstellBarItem {
  const AstellBarBundle(this.list, this.members);
  final ActionListDef list;

  /// 今押せるメンバー(記述子 + 今のボタン)。
  final List<({ActionDescriptor action, AstellBarButton button})> members;
  @override
  String get key => ActionBarConfig.listKey(list.id);
}

/// 保存済みの並びに無い内蔵のボタン(あとから増えた種類)を、既定の並びの位置(直前の既定のボタンの後ろ)に入れる。
/// 並びを一度も編集していなければ([ActionBarConfig.order] が空)そのまま(記述子の順 = 既定の並び)。
ActionBarConfig astellBarWithNewDefaults(ActionBarConfig config) {
  if (config.order.isEmpty) return config;
  final order = [...config.order];
  final known = {...order, ...config.listedIds, ...config.hidden};
  var changed = false;
  for (var i = 0; i < astellBarBuiltinActions.length; i++) {
    final id = astellBarBuiltinActions[i].id;
    if (known.contains(id)) continue;
    // 直前の既定のボタンのうち、並びにあるものの後ろ(無ければ先頭)。バンドルに入っていればバンドルの後ろ。
    var at = 0;
    for (var j = i - 1; j >= 0; j--) {
      final prev = astellBarBuiltinActions[j].id;
      final list = config.lists.where((l) => l.memberIds.contains(prev)).firstOrNull;
      final k = order.indexOf(list == null ? prev : ActionBarConfig.listKey(list.id));
      if (k >= 0) {
        at = k + 1;
        break;
      }
    }
    order.insert(at, id);
    known.add(id);
    changed = true;
  }
  return changed ? config.copyWith(order: order) : config;
}

/// 構成 + プラグインのボタン + 今押せるボタン([buttons]、id → 今の見た目。無い id = 今は出さない)→ 下段の並び。
List<AstellBarItem> resolveAstellBar({
  required ActionBarConfig config,
  required List<PluginAction> plugins,
  required SlotActionSettings settings,
  ActionButtonPrefs prefs = const ActionButtonPrefs(),
  required Map<String, AstellBarButton> buttons,
}) {
  final merged = mergePluginActions(config: astellBarWithNewDefaults(config), snsActions: astellBarBuiltinActions, plugins: plugins, settings: settings, prefs: prefs);
  final out = <AstellBarItem>[];
  for (final e in merged.config.apply(merged.actions)) {
    switch (e) {
      case SingleActionEntry(:final action):
        final b = buttons[action.id];
        if (b != null) out.add(AstellBarSingle(action.id, b));
      case ActionListEntry(:final list, :final members):
        // 今押せるメンバーが無いバンドル(全画面だけ、など)は出さない。
        final ms = [for (final a in members) if (buttons[a.id] case final b?) (action: a, button: b)];
        if (ms.isNotEmpty) out.add(AstellBarBundle(list, ms));
    }
  }
  return out;
}

/// 丸いボタンの幅と間隔(下段の `_RoundButton` と同じ)。
const astellBarButtonSize = 44.0;
const astellBarGap = 4.0;

/// 入力欄(字幕オン)/「共有する」/ stick の文字起こしに残す最小の幅。これまでの狭幅(360px)の下段と同じ。
const astellBarMiddleMinWidth = 96.0;

/// 下段の幅 [width] に並べられるボタンの数。[reserved] = 左右の余白と右端のボタン(共有する / 設定、stick は退出)の幅。
/// stick は 3 つまで(これまでの「2 つ + 字幕」と同じ)。
int astellBarSlots(double width, {required double reserved, required bool compact}) {
  final free = width - reserved - astellBarMiddleMinWidth;
  final n = ((free + astellBarGap) / (astellBarButtonSize + astellBarGap)).floor();
  return n.clamp(1, compact ? 3 : 99);
}

/// 幅に収まらないときの扱い: 先頭から [slots] - 1 個と、**並びの最後の 1 つ**(入力欄の隣。既定では字幕)を出し、
/// 残り(はみ出した分)は歯車のメニュー(VC の設定の先頭)へ。収まれば全部出す。
({List<AstellBarItem> shown, List<AstellBarItem> overflow}) splitAstellBar(List<AstellBarItem> items, int slots) {
  if (items.length <= slots) return (shown: items, overflow: const []);
  if (slots <= 1) return (shown: [items.last], overflow: items.sublist(0, items.length - 1));
  return (shown: [...items.take(slots - 1), items.last], overflow: items.sublist(slots - 1, items.length - 1));
}
