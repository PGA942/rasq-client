import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../plugins/slot_plugins.dart';
import '../settings/settings_dsl.dart';
import '../vc/astell_bar.dart';
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
/// - ボタン共通の 3 属性 (契約 v0.14 §2.11、D-305)。どれも ActionKey 単位で直交する:
///   - **switch** = 端末全体の主電源([ActionButtonPrefs.switchOn]、設定エリア `slots.global` の `switch`)。オフなら
///     全アカウント・全面で出ず、自動でも動かない(temp も評価しない)。アカウントごとの有効 / 無効とは AND。
///   - **temp** = 面が作られた瞬間の初期状態([PluginAction.effectiveAuto])。宣言 `actions[].auto` → 利用者の上書き
///     (`slots.global` の `auto`)。面の中で切り替えた値はその面限りで永続しない。
///   - **placement** = 宣言だけで自動配置されるか([SlotActionDecl.isManual])。manual は利用者が (+) で足すまで出ない。

/// ホスト側の id: `slot:<pluginId>:<actionId>`。
String pluginActionId(String pluginId, String actionId) => 'slot:$pluginId:$actionId';

bool isPluginActionId(String id) => id.startsWith('slot:');

/// `slot:<pluginId>:<actionId>` → pluginId(プラグインボタンでなければ null)。
String? pluginIdOfActionId(String id) {
  if (!isPluginActionId(id)) return null;
  final rest = id.substring('slot:'.length);
  final i = rest.indexOf(':');
  return i < 0 ? rest : rest.substring(0, i);
}

// ── ボタン共通の設定 (契約 v0.14 §2.11、D-305) ─────────────────────────

/// 端末全体のボタン設定の置き場(設定エリア、保存キー `slots.global.v1`): `{"switch": {ActionKey: bool}, "auto": {ActionKey: bool}}`。
const actionButtonPrefsArea = 'slots.global';

/// switch / temp の上書き。未指定 = switch オン、temp は宣言 → ホスト既定。
@immutable
class ActionButtonPrefs {
  const ActionButtonPrefs({this.switches = const {}, this.auto = const {}});
  static const switchKey = 'switch';
  static const autoKey = 'auto';

  /// ActionKey → 主電源。未指定はオン。
  final Map<String, bool> switches;

  /// ActionKey → 利用者が決めた初期状態(宣言とホスト既定に勝つ)。未指定は無し。
  final Map<String, bool> auto;

  bool switchOn(String id) => switches[id] ?? true;
  bool? autoOverride(String id) => auto[id];

  Map<String, bool> switchesWith(String id, bool on) => {...switches, id: on};

  /// null = 上書きを外す(宣言 / ホスト既定に戻す)。
  Map<String, bool> autoWith(String id, bool? on) => on == null ? ({...auto}..remove(id)) : {...auto, id: on};

  static Map<String, bool> _bools(Object? v) => {for (final e in ((v as Map?) ?? const {}).entries) '${e.key}': e.value == true};

  factory ActionButtonPrefs.fromJson(Map<String, Object?> j) => ActionButtonPrefs(switches: _bools(j[switchKey]), auto: _bools(j[autoKey]));
}

final actionButtonPrefsProvider = Provider<ActionButtonPrefs>((ref) {
  final v = ref.watch(settingsAreaProvider(actionButtonPrefsArea)).value;
  return v == null ? const ActionButtonPrefs() : ActionButtonPrefs.fromJson(v);
});

/// temp の上書きを書く(設定画面と、面の中の長押し「次からも自動でオン / オフ」から)。null = 宣言 / ホスト既定に戻す。
Future<void> setActionAuto(SettingsAreaStore store, ActionButtonPrefs prefs, String id, bool? on) => store.set(ActionButtonPrefs.autoKey, prefs.autoWith(id, on));

/// switch を書く(設定画面から)。
Future<void> setActionSwitch(SettingsAreaStore store, ActionButtonPrefs prefs, String id, bool on) => store.set(ActionButtonPrefs.switchKey, prefs.switchesWith(id, on));

/// 面の中の長押し(契約 v0.14 §2.11): 「次からも自動でオン / オフ」のドロップダウン。今の面の状態は変えない(temp は次に面を作るときの初期状態)。
Future<void> showActionTempMenu(WidgetRef ref, {required Rect anchor, required PluginAction action, String? ownerId}) async {
  final prefs = ref.read(actionButtonPrefsProvider);
  final current = action.effectiveAuto(prefs);
  final pick = await ref.read(overlayManagerProvider).showDropdown<String>(
    id: 'actionbar.temp.menu',
    ownerId: ownerId,
    anchor: anchor,
    dense: true,
    items: [
      RasqDropdownItem('次からも自動でオン', 'on', checked: current),
      RasqDropdownItem('次からも自動でオフ', 'off', checked: !current),
      if (prefs.autoOverride(action.id) != null) const RasqDropdownItem('プラグインの既定に戻す', 'reset'),
    ],
  );
  if (pick == null) return;
  await setActionAuto(ref.read(settingsAreaProvider(actionButtonPrefsArea).notifier), prefs, action.id, pick == 'reset' ? null : pick == 'on');
}

/// v0.13 までの全画面トグルの保存(設定エリア `slots.viewer`、`enabled.<pluginId>`)を、1 回だけ `slots.global` の `auto`
/// (ActionKey `slot:<pluginId>:viewer.overlay`)へ写して捨てる(契約 v0.14 §2.4)。次に開いたときの初期状態が今までと同じになる。
/// 既に `auto` に値があるキーは上書きしない。起動時のプラグインの読み直し([SlotPluginsNotifier])から呼ぶ。
const legacyViewerPluginsStorageKey = 'slots.viewer.v1';

Future<void> migrateViewerPluginSettings(Ref ref) async {
  final storage = ref.read(sessionStorageProvider);
  final String? raw;
  try {
    raw = await storage.read(legacyViewerPluginsStorageKey);
  } catch (_) {
    return;
  }
  if (raw == null) return;
  try {
    final legacy = (jsonDecode(raw) as Map).cast<String, Object?>();
    final store = ref.read(settingsAreaProvider(actionButtonPrefsArea).notifier);
    final prefs = ActionButtonPrefs.fromJson(await ref.read(settingsAreaProvider(actionButtonPrefsArea).future));
    final auto = {...prefs.auto};
    const prefix = 'enabled.';
    for (final e in legacy.entries) {
      if (!e.key.startsWith(prefix) || e.value is! bool) continue;
      auto.putIfAbsent(pluginActionId(e.key.substring(prefix.length), viewerToggleActionId), () => e.value == true);
    }
    if (auto.length != prefs.auto.length) await store.set(ActionButtonPrefs.autoKey, auto);
  } catch (e) {
    debugPrint('viewer plugin settings migration: $e');
  }
  try {
    await storage.delete(legacyViewerPluginsStorageKey);
  } catch (_) {}
}

/// 面ごとのホスト既定(宣言も設定も無いときの temp。今までの挙動と同じ)。
bool hostDefaultAuto(SlotActionDecl decl) => switch (decl.slot) {
      SlotIds.viewerOverlay => true,
      SlotIds.composerText => true,
      SlotIds.composerMedia => false,
      _ => false,
    };

/// `post.transform`(自動、ボタン無し)の ActionKey `slot:<pluginId>:post.transform`。switch だけを持つ(オフ = 端末全体で通さない)。
String postTransformActionId(String pluginId) => pluginActionId(pluginId, SlotIds.postTransform);

/// 登録済みプラグインの `post.action` 宣言(全アカウント共通の候補)。
class PluginAction {
  const PluginAction({required this.plugin, required this.decl});
  final SlotPlugin plugin;
  final SlotActionDecl decl;
  String get id => pluginActionId(plugin.id, decl.id);

  /// 手動配置か(契約 v0.14 placement): 構成に入っていなければ自動では置かない。
  bool get isManual => decl.isManual;

  /// この面で temp(初期状態)を持つボタンか。post.action は自動実行できるもの([canAutoRun])だけ、
  /// composer.media はカスタムフィルター(ON / OFF のボタン)だけ、viewer.overlay / composer.text は常に。
  bool get hasTemp => switch (decl.slot) {
        SlotIds.viewerOverlay || SlotIds.composerText => true,
        SlotIds.composerMedia => decl.isFilterOutput,
        _ => decl.isPostAction && canAutoRun,
      };

  /// post.action の temp = タイルごとに 1 回の自動実行(契約 v0.14 §2.9、旧 auto_hook の置き換え)。
  /// 審査済みで `auto_hook` 権限があり、`destructive` / `autoHookForbidden` でないボタンだけ。
  bool get canAutoRun => decl.isPostAction && plugin.isReviewed && plugin.manifest.permissions.contains('auto_hook') && !decl.destructive && !decl.autoHookForbidden;

  /// 宣言の `auto`(審査済みだけ読む)→ 無ければホスト既定。temp を持たないボタン([hasTemp]: 自動実行できない post.action、
  /// filter でない composer.media)は宣言があっても常に false。
  bool get declaredAuto {
    if (!hasTemp) return false;
    final a = decl.auto;
    return plugin.isReviewed && a != null ? a : hostDefaultAuto(decl);
  }

  /// 面が作られた瞬間の初期状態(temp): switch オフ → false(評価しない)、利用者の上書き → 宣言 → ホスト既定。
  bool effectiveAuto(ActionButtonPrefs prefs) {
    if (!prefs.switchOn(id) || !hasTemp) return false;
    return prefs.autoOverride(id) ?? declaredAuto;
  }

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
        for (final a in p.manifest.actions)
          if (a.isPostAction) PluginAction(plugin: p, decl: a), // ほかのスロット向けの宣言(viewer.overlay など)は投稿のボタンにしない
    ]);

/// 全画面表示プラグインのトグル (D-214): `viewer.overlay` を宣言したプラグイン(QR コード検出など)は
/// **全画面アクションバーのボタン**(ON / OFF)として扱う。id は `slot:<pluginId>:viewer.overlay`。
/// 編集画面の全画面バーの検索に出て、並べ替え / バンドル / 削除(スロット設定で無効)ができる。
const viewerToggleActionId = 'viewer.overlay';

bool isViewerToggleActionId(String id) => isPluginActionId(id) && id.endsWith(':$viewerToggleActionId');

/// `slot:<pluginId>:viewer.overlay` → pluginId。
String viewerTogglePluginId(String id) => id.substring('slot:'.length, id.length - viewerToggleActionId.length - 1);

///
/// 見た目はマニフェストの宣言(契約 v0.9: `actions` の `slot: "viewer.overlay"` の項目の label / icon / tags)。
/// 宣言が無ければプラグイン名と既定のアイコン。ボタンの id は宣言の `id` に依らず `viewer.overlay` 固定(保存した並びが変わらない)。
final viewerPluginActionsProvider = Provider<List<PluginAction>>((ref) => [
      for (final p in ref.watch(slotPluginsForProvider(SlotIds.viewerOverlay)))
        PluginAction(plugin: p, decl: viewerToggleDecl(p.manifest)),
    ]);

/// 既定のアイコン名(宣言が無いとき)。トグルはこの名前なら 塗り / 線 のパズルのアイコンで ON / OFF を出す。
const viewerToggleDefaultIcon = 'extension';

SlotActionDecl viewerToggleDecl(SlotManifest m) {
  final declared = m.actions.where((a) => a.slot == SlotIds.viewerOverlay).firstOrNull;
  return SlotActionDecl(
    id: viewerToggleActionId,
    label: declared?.label ?? m.name,
    icon: declared?.icon ?? viewerToggleDefaultIcon,
    tags: {'全画面表示', ...?declared?.tags}.toList(),
    slot: SlotIds.viewerOverlay,
    auto: declared?.auto,
    placement: declared?.placement ?? SlotActionDecl.placementAuto,
  );
}

// ── コンポーザー本文の ON / OFF ボタン (契約 v0.14 §2.3、D-305 → D-474: アクションバーの行) ──────────

/// `composer.text` のプラグインごとの ON / OFF。ActionKey は `slot:<pluginId>:composer.text`(宣言の `id` に依らない)。
/// 見た目は `actions` の `slot: "composer.text"` の項目(label / icon)、無ければプラグイン名 + 既定のアイコン。
SlotActionDecl composerTextDecl(SlotManifest m) {
  final declared = m.actions.where((a) => a.slot == SlotIds.composerText).firstOrNull;
  return SlotActionDecl(id: SlotIds.composerText, label: declared?.label ?? m.name, icon: declared?.icon ?? viewerToggleDefaultIcon, tags: declared?.tags ?? const [], slot: SlotIds.composerText, auto: declared?.auto);
}

final composerTextPluginActionsProvider = Provider<List<PluginAction>>((ref) => [
      for (final p in ref.watch(slotPluginsForProvider(SlotIds.composerText))) PluginAction(plugin: p, decl: composerTextDecl(p.manifest)),
    ]);

/// switch がオンの `composer.text` プラグイン(コンポーザーが `text.changed` を送りうる相手。面の中の ON / OFF は別)。
final composerTextPluginsProvider = Provider<List<PluginAction>>((ref) {
  final prefs = ref.watch(actionButtonPrefsProvider);
  return [for (final a in ref.watch(composerTextPluginActionsProvider)) if (prefs.switchOn(a.id)) a];
});

// ── 加工画面の下段バー (D-249、契約 v0.10) ─────────────────────────────

/// 加工画面の下段バーの構成キー: `editor:image` / `editor:video` / `editor:svg`(D-472、アカウントに依らない)。
const editorImageConfigKey = 'editor:image';
const editorVideoConfigKey = 'editor:video';
const editorSvgConfigKey = 'editor:svg';

/// SVG の MIME。
const svgMimeType = 'image/svg+xml';

/// 加工画面のモード (D-472): 添付の種類(MIME / 拡張子)で道具と下段バーを変える。
/// - [image]: pro_image_editor(クロップ / ペイント / テキスト / フィルター …)。構成 `editor:image`
/// - [video] / [audio]: pro_image_editor の動画モード(音声は Visualizer の動画にしてから)。構成 `editor:video`
/// - [svg]: SVG の道具(ペン / 消しゴム / 色 / 太さ / 取り消し = `SvgPaintEditor`)。ラスターの編集と動画 / 音声の編集は出ない。構成 `editor:svg`
enum MediaEditorMode { image, video, audio, svg }

MediaEditorMode mediaEditorModeOf({required String mimeType, String name = ''}) {
  final mime = mimeType.toLowerCase();
  if (mime == svgMimeType || name.toLowerCase().endsWith('.svg')) return MediaEditorMode.svg;
  if (mime.startsWith('audio/')) return MediaEditorMode.audio;
  if (mime.startsWith('video/')) return MediaEditorMode.video;
  return MediaEditorMode.image;
}

/// SVG モードのバーに出す宣言か (D-472、契約 v0.23 §2.2): `accepts` に `image/svg+xml` か `.svg` を**書いた**もの
/// (`image/*` / `*` / `*/*` では出さない。ラスターの画像を前提にしたプラグインへ SVG の文字列を渡さない)。
/// ステッカー / カスタムフィルターは SVG モードには出さない(焼き込む先の絵が無い)。
bool svgEditorAccepts(SlotActionDecl decl) =>
    !decl.isStickerOutput && !decl.isFilterOutput && decl.accepts.any((a) => const {svgMimeType, '.svg'}.contains(a.trim().toLowerCase()));

bool isEditorConfigKey(String configKey) => configKey.startsWith('editor:');

/// RASQ の投稿のバー (D-279): SNS の投稿バーと同じく、並び替え / バンドル / プラグインのボタンを持てる。土台は RASQ の内蔵のアクション。
const rasqPostConfigKey = 'rasq:post';
const rasqReplyActionId = 'rasq.reply';
const rasqRebroadActionId = 'rasq.rebroad';
const rasqQueueActionId = 'rasq.queue';
const rasqPostBuiltinActions = [
  ActionDescriptor(id: rasqReplyActionId, genreTag: 'Reply', label: '返信', icon: 'chat_bubble_outline'),
  ActionDescriptor(id: rasqRebroadActionId, genreTag: 'Repost', label: 'リブロード', icon: 'repeat', doneIcon: 'repeat'),
  ActionDescriptor(id: rasqQueueActionId, genreTag: 'Reaction', label: 'キュー', icon: 'add_reaction_outlined', doneIcon: 'add_reaction', iconPerPost: true, countSource: CountSource.none),
];

/// 構成キー → どのアカウントのバーか (D-284)。投稿バー = アカウントの key、全画面バー = `viewer:<key>`。内蔵のバー / 旧来の共通構成は null。
String? accountKeyOfConfigKey(String configKey) {
  if (configKey.isEmpty || isBuiltinConfigKey(configKey)) return null;
  return configKey.startsWith('viewer:') ? configKey.substring('viewer:'.length) : configKey;
}

/// 土台が SNS のアクションではなく、アプリ内蔵のもののバー(加工画面 / RASQ の投稿 / AsTell のルームの下段 D-324)。
/// RASQ の全画面アクションバー (D-446): Swing のビューワーの上のボタン。SNS の全画面アクションバーと同じ扱いで、土台は RASQ の投稿と同じ
/// 内蔵のアクション(並び / バンドル / プラグインのボタンは投稿のバーと別に持つ)。
const rasqViewerConfigKey = 'rasq:viewer';

/// RASQ のバーか(投稿 / 全画面)。
bool isRasqConfigKey(String configKey) => configKey == rasqPostConfigKey || configKey == rasqViewerConfigKey;

bool isBuiltinConfigKey(String configKey) => isEditorConfigKey(configKey) || isRasqConfigKey(configKey) || configKey == astellBarConfigKey;
List<ActionDescriptor> builtinActionsFor(String configKey) => switch (configKey) {
      // SVG の道具は落書きの面(SvgPaintEditor)が持つので、バーは SVG を受けるプラグインのボタンだけ (D-472)。
      editorSvgConfigKey => const <ActionDescriptor>[],
      rasqPostConfigKey || rasqViewerConfigKey => rasqPostBuiltinActions,
      astellBarConfigKey => astellBarBuiltinActions,
      _ => editorBuiltinActionsFor(configKey),
    };

String editorConfigKeyFor(String mimeType, {String name = ''}) => switch (mediaEditorModeOf(mimeType: mimeType, name: name)) {
      MediaEditorMode.svg => editorSvgConfigKey,
      MediaEditorMode.image => editorImageConfigKey,
      MediaEditorMode.video || MediaEditorMode.audio => editorVideoConfigKey,
    };

/// プラグインボタンの有効 / 無効と閾値の置き場: 加工画面は `slots.editor`、AsTell の下段は `slots.astell`、ほかはアカウントごと。
String slotSettingsKeyFor(String configKey, String accountKey) => isEditorConfigKey(configKey) ? 'editor' : (isRasqConfigKey(configKey) ? 'rasq' : (configKey == astellBarConfigKey ? 'astell' : accountKey));

/// 宣言が無い `composer.media` プラグインのボタン(プラグイン名 + パズルのアイコン、画像だけ)。
const mediaEditDefaultActionId = 'composer.media';

/// 内蔵の編集(pro_image_editor)。id は `editor:<tool>`。動画にも同じものが出る。
const editorBuiltinActions = <ActionDescriptor>[
  ActionDescriptor(id: 'editor:cropRotate', genreTag: 'Transform', label: 'クロップ / 回転', icon: 'crop_rotate', doneIcon: 'crop_rotate', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:paint', genreTag: 'Draw', label: 'ペイント', icon: 'edit', doneIcon: 'edit', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:text', genreTag: 'Text', label: 'テキスト', icon: 'text_fields', doneIcon: 'text_fields', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:post', genreTag: 'Post', label: 'ノート', icon: 'article', doneIcon: 'article', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:media', genreTag: 'Media', label: 'メディア', icon: 'add_photo_alternate', doneIcon: 'add_photo_alternate', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:sticker', genreTag: 'Sticker', label: 'ステッカー', icon: 'auto_awesome_mosaic', doneIcon: 'auto_awesome_mosaic', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:emoji', genreTag: 'Emoji', label: '絵文字', icon: 'sentiment_satisfied_alt', doneIcon: 'sentiment_satisfied_alt', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:filter', genreTag: 'Filter', label: 'フィルター', icon: 'filter', doneIcon: 'filter', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:blur', genreTag: 'Blur', label: 'ぼかし', icon: 'blur_on', doneIcon: 'blur_on', countSource: CountSource.none),
  ActionDescriptor(id: 'editor:tune', genreTag: 'Tune', label: '調整', icon: 'tune', doneIcon: 'tune', countSource: CountSource.none),
];

/// 音声の Visualizer の設定 (D-251)。動画のバーの先頭。音声を開いているときだけ出る。
const editorVisualizerActionId = 'editor:visualizer';
const editorVisualizerAction = ActionDescriptor(id: editorVisualizerActionId, genreTag: 'Audio', label: 'Visualizer', icon: 'graphic_eq', doneIcon: 'graphic_eq', countSource: CountSource.none);

/// バー(構成キー)ごとの内蔵の編集。
List<ActionDescriptor> editorBuiltinActionsFor(String configKey) => switch (configKey) {
      editorVideoConfigKey => const [editorVisualizerAction, ...editorBuiltinActions],
      editorSvgConfigKey => const <ActionDescriptor>[],
      _ => editorBuiltinActions,
    };

/// `composer.media` プラグインの下段バーのボタン(契約 v0.10): マニフェストの `actions` の
/// `slot: "composer.media"` の項目。1 つも宣言していないプラグインは、従来どおり画像にだけ出る既定のボタン 1 つ。
List<SlotActionDecl> mediaEditDecls(SlotManifest m) {
  final declared = [for (final a in m.actions) if (a.slot == SlotIds.composerMedia) a];
  if (declared.isNotEmpty) return declared;
  return [SlotActionDecl(id: mediaEditDefaultActionId, label: m.name, icon: 'extension', tags: const ['Plugin'], slot: SlotIds.composerMedia)];
}

final mediaPluginActionsProvider = Provider<List<PluginAction>>((ref) => [
      for (final p in ref.watch(slotPluginsForProvider(SlotIds.composerMedia)))
        for (final a in mediaEditDecls(p.manifest)) PluginAction(plugin: p, decl: a),
    ]);

/// 構成キーに応じたプラグインボタン: 全画面バー(`viewer:` の構成)には全画面表示プラグインのトグルも含む。
/// 加工画面(`editor:` の構成)は `composer.media` の宣言だけ(その種類の添付に出るもの)。AsTell の下段は `astell.action` だけ。
/// switch(契約 v0.14)を切ったボタンは含めない(バーにも (+) の検索にも出ない。戻すのは設定画面)。
final pluginActionsForProvider = Provider.family<List<PluginAction>, String>((ref, configKey) {
  final prefs = ref.watch(actionButtonPrefsProvider);
  final List<PluginAction> all;
  if (configKey == editorSvgConfigKey) {
    all = [for (final a in ref.watch(mediaPluginActionsProvider)) if (svgEditorAccepts(a.decl)) a];
  } else if (isEditorConfigKey(configKey)) {
    final mime = configKey == editorImageConfigKey ? 'image/*' : 'video/*';
    all = [for (final a in ref.watch(mediaPluginActionsProvider)) if (mediaAcceptsKind(a.decl.accepts, mime)) a];
  } else if (configKey == astellBarConfigKey) {
    // AsTell のルームの下段 (D-324): `astell.action` のプラグイン(投稿のボタンは出さない)。
    all = ref.watch(astellPluginActionsProvider);
  } else {
    all = [
      ...ref.watch(pluginActionsProvider),
      if (configKey.startsWith('viewer:')) ...ref.watch(viewerPluginActionsProvider),
    ];
  }
  return [for (final a in all) if (prefs.switchOn(a.id)) a];
});

/// バーの種類(`image/*` / `video/*`)に出うる宣言か: 拡張子だけの宣言はどちらにも出うる(実際の添付で絞る)。
/// 音声(`audio/*`)は動画のバーで扱う(音声だけのファイルは動画として編集する)。
bool mediaAcceptsKind(List<String> accepts, String kind) {
  if (accepts.isEmpty) return kind == 'image/*';
  final major = kind.substring(0, kind.indexOf('/'));
  return accepts.any((a) {
    final t = a.trim().toLowerCase();
    return t.startsWith('.') || t == '*' || t == '*/*' || t.startsWith('$major/') || (major == 'video' && t.startsWith('audio/'));
  });
}

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
/// 契約 v0.14 (D-305): switch を切ったボタンは出さない(アカウントごとの有効 / 無効と AND)。
/// `placement: "manual"`(tags 無しの post.action を含む)のボタンは、構成(並び / リスト)に入っているときだけ出す
/// = 利用者が (+) の検索で足すまで自動では置かない。
({List<ActionDescriptor> actions, ActionBarConfig config}) mergePluginActions({
  required ActionBarConfig config,
  required List<ActionDescriptor> snsActions,
  required List<PluginAction> plugins,
  required SlotActionSettings settings,
  ActionButtonPrefs prefs = const ActionButtonPrefs(),
}) {
  bool placed(PluginAction p) => config.order.contains(p.id) || config.lists.any((l) => l.memberIds.contains(p.id));
  final enabled = [for (final p in plugins) if (settings.isEnabled(p.id) && prefs.switchOn(p.id) && (!p.isManual || placed(p))) p];
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
