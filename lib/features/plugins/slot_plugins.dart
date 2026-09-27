import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../text/inline_spans.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/plugin_actions.dart' show actionButtonPrefsProvider, migrateViewerPluginSettings, postTransformActionId;
import '../media/image_scale.dart';
import '../settings/settings_dsl.dart';
import '../store/rasqpkg.dart';
import '../store/store_models.dart' show InstalledPlugin;
import '../store/store_providers.dart';
import '../trend/example_match.dart' show pluginExamplePieces;
import '../vc/astell_models.dart';
import '../vc/astell_providers.dart';
import 'fetch_shape_telemetry.dart';
import 'sideload_trust.dart';

/// スロットプラグイン (D-167、契約 = `plugin-sample/CONTRACT.md`)。
///
/// 「WASMプラグイン試験 (dev)」で読み込んだ wasm を**スロットに登録**すると、
/// マニフェスト(`call("plugin.manifest")`)の `slots` に応じてアプリの各所
/// (AsTell 下段のプラグインアクション / コンポーザーの添付・本文 / メディア
/// 全画面 / TL / トレンド)から `call` される。プラグイン → アプリの働きかけは
/// ホスト関数(`toast` / `sound.play` / `clipboard.set` / `url.open` / `mute.add` /
/// `astell.share` / `composer.*.replace` / `viewer.overlay.set`)で、ワーカー
/// isolate から fire-and-forget で中継される。登録したパスは端末に残り、
/// 次回起動時に読み直す。

/// `plugin.manifest` の答え。
@immutable
class SlotManifest {
  const SlotManifest({required this.id, required this.name, this.version = '0.0.0', this.kind = 'action', this.description = '', this.slots = const [], this.permissions = const [], this.actions = const [], this.network});
  final String id;
  final String name;
  final String version;
  final String kind;
  final String description;
  final List<String> slots;
  final List<String> permissions;

  /// 投稿のアクションボタン (契約 v0.7 §2.9、D-176): `post.action` の宣言。
  final List<SlotActionDecl> actions;

  /// `net.fetch` の接続先 (schema v0.12)。null = 宣言なし = どこにも繋げない。
  /// スロットプラグインにはセッションが無いので `instance` は効かず、`hosts` だけ。
  final PluginNetwork? network;

  /// ランタイムに渡す接続先の宣言。
  Set<String> get fetchHosts => (network ?? PluginNetwork.none).hosts.toSet();

  factory SlotManifest.fromJson(Map<String, Object?> j) => SlotManifest(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? j['id'] as String? ?? '',
        version: j['version'] as String? ?? '0.0.0',
        kind: j['kind'] as String? ?? 'action',
        description: j['description'] as String? ?? '',
        slots: [for (final s in (j['slots'] as List? ?? const [])) if (s is String) s],
        permissions: [for (final s in (j['permissions'] as List? ?? const [])) if (s is String) s],
        network: j['network'] is Map ? PluginNetwork.fromJson((j['network'] as Map).cast<String, Object?>()) : null,
        actions: [
          for (final a in (j['actions'] as List? ?? const []))
            if (a is Map && a['id'] is String)
              SlotActionDecl(
                id: a['id'] as String,
                label: a['label'] as String? ?? a['id'] as String,
                icon: a['icon'] as String?,
                tags: [for (final t in (a['tags'] as List? ?? const [])) if (t is String) t],
                slot: a['slot'] as String?,
                accepts: [for (final t in (a['accepts'] as List? ?? const [])) if (t is String) t],
                output: a['output'] as String?,
                auto: a['auto'] is bool ? a['auto'] as bool : null,
                placement: a['placement'] == SlotActionDecl.placementManual ? SlotActionDecl.placementManual : SlotActionDecl.placementAuto,
                destructive: a['destructive'] == true,
                autoHookForbidden: a['autoHookForbidden'] == true,
              ),
        ],
      );

  /// スロットと権限から、許可するアプリ向けホスト関数を決める。
  Set<String> get appFns => {
        RasqHostFns.toast,
        RasqHostFns.soundPlay,
        RasqHostFns.clipboardSet,
        RasqHostFns.urlOpen,
        if (permissions.contains('mute.words')) RasqHostFns.muteAdd,
        if (slots.contains(SlotIds.astellAction)) RasqHostFns.astellShare,
        if (slots.contains(SlotIds.composerMedia)) RasqHostFns.composerMediaReplace,
        if (slots.contains(SlotIds.composerMedia)) RasqHostFns.composerMediaPreview,
        if (slots.contains(SlotIds.composerMedia)) RasqHostFns.composerMediaOverlay,
        if (slots.contains(SlotIds.composerText)) RasqHostFns.composerTextReplace,
        if (slots.contains(SlotIds.viewerOverlay)) RasqHostFns.viewerOverlaySet,
        // 投稿共有 (§2.8) / 投稿のアクションボタン (§2.9): コンポーザーを開く + 参加中の AsTell へ。
        if (slots.contains(SlotIds.postShare) || slots.contains(SlotIds.postAction)) RasqHostFns.composerOpen,
        if (slots.contains(SlotIds.postShare) || slots.contains(SlotIds.postAction)) RasqHostFns.astellShare,
      };

  Set<String> get fowPermissions => {
        'widget',
        if (permissions.contains('fow.interstitial')) 'interstitial',
        if (permissions.contains('fow.system')) 'system',
      };
}

/// `post.action` のボタン宣言 (§2.9): タグ = 希望スロット(既存ボタンのタグと比べて束ねる)。
/// ボタン共通の属性 (契約 v0.14 §2.11、D-305): [auto](temp = 面が作られた瞬間の初期状態)と [placement](自動配置か手動か)。
class SlotActionDecl {
  const SlotActionDecl({required this.id, required this.label, this.icon, this.tags = const [], this.slot, this.accepts = const [], this.output, this.auto, this.placement = placementAuto, this.destructive = false, this.autoHookForbidden = false});
  static const placementAuto = 'auto';
  static const placementManual = 'manual';
  final String id;
  final String label;
  final String? icon;
  final List<String> tags;

  /// このボタンが属するスロット(契約 v0.9)。null = `post.action`。`viewer.overlay` = 全画面アクションバーの
  /// ON / OFF ボタンの見た目の宣言(押したときの call は無い)。
  final String? slot;

  /// 出現する添付の種類(契約 v0.10、`composer.media` の宣言だけ): MIME の型(`image/*` / `video/mp4` / `audio/*`)か
  /// 拡張子(`.gif`)。空 = `image/*`(従来どおり画像だけ)。
  final List<String> accepts;

  /// `media.commit` の結果の置き方(契約 v0.11、`composer.media` の宣言だけ): null / `replace` = 背景を差し替える、
  /// `sticker` = ステッカーのレイヤーとして置く(ジェネレーター)。
  final String? output;
  bool get isStickerOutput => output == 'sticker';

  /// カスタムフィルター(契約 v0.12): ON / OFF のボタン。`filter.preview` の描画リストを重ね、完了のとき焼き込むか `filter.apply`。
  bool get isFilterOutput => output == 'filter';

  bool get isPostAction => slot == null || slot == SlotIds.postAction;

  /// temp の宣言(契約 v0.14): 面が作られた瞬間にオンで始めるか。null = 面ごとのホスト既定
  /// (viewer.overlay: true、composer.media の filter: false、composer.text: true、post.action: false)。
  /// 審査済み(ストアから入れた)プラグインの宣言だけ読む。
  final bool? auto;

  /// placement の宣言(契約 v0.14): `auto` = 宣言だけで自動配置、`manual` = 利用者が (+) で足すまで出ない。
  final String placement;

  /// `destructive` / `autoHookForbidden`(契約 v0.14): どちらかが立っていれば post.action の自動実行(temp)はしない。
  final bool destructive;
  final bool autoHookForbidden;

  /// 手動配置か: `placement: "manual"`、または tags を省いた post.action のボタン(契約 v0.14 §2.9)。
  bool get isManual => placement == placementManual || (isPostAction && tags.isEmpty);
}

/// 添付(MIME + ファイル名)が宣言の `accepts` に当てはまるか(契約 v0.10)。空の宣言は `image/*`。
bool mediaAccepts(List<String> accepts, {required String mimeType, String name = ''}) {
  final mime = mimeType.toLowerCase();
  final file = name.toLowerCase();
  for (final raw in accepts.isEmpty ? const ['image/*'] : accepts) {
    final a = raw.trim().toLowerCase();
    if (a == '*' || a == '*/*') return true;
    if (a.startsWith('.')) {
      if (file.endsWith(a)) return true;
    } else if (a.endsWith('/*')) {
      if (mime.startsWith(a.substring(0, a.length - 1))) return true;
    } else if (a == mime) {
      return true;
    }
  }
  return false;
}

abstract final class SlotIds {
  static const astellAction = 'astell.action';
  static const composerMedia = 'composer.media';
  static const composerText = 'composer.text';
  static const viewerOverlay = 'viewer.overlay';
  static const postTransform = 'post.transform';
  static const tl = 'tl';
  static const trendSuggest = 'trend.suggest';
  static const postShare = 'post.share';
  static const postAction = 'post.action';
}

/// 実行中のプラグイン 1 つ(ワーカー isolate 上の wasm、テストでは偽物)。
abstract class SlotRuntime {
  /// 描画/FOW 用のビュー(`WasmFowSurfaceHost` を実装していること)。
  WasmPluginViewModel get view;
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> args);
  set onAppFn(AppFnRelay? relay);

  /// 初めて見た `net.fetch` の形(値は無い)。同意があればストアへ報告する。
  Stream<Map<String, Object?>> get fetchShapes;
  void dispose();
}

class _AsyncSlotRuntime implements SlotRuntime {
  _AsyncSlotRuntime(this.controller);
  final AsyncWasmPluginController controller;
  @override
  WasmPluginViewModel get view => controller;
  @override
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> args) => controller.invoke(fn, args);
  @override
  set onAppFn(AppFnRelay? relay) => controller.onAppFn = relay;
  @override
  Stream<Map<String, Object?>> get fetchShapes => controller.fetchShapes;
  @override
  void dispose() => controller.dispose();
}

/// wasm バイト列 → 実行中のプラグイン。テストは偽物に差し替える。
/// [gpuCompute] = `gpu.compute` (D-081) を開けるか([slotGpuComputeAllowed] の答え)。
typedef SlotRuntimeLoader = Future<SlotRuntime> Function(Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns, required Set<String> permissions, required int? fuelPerCall, required Set<String> fetchHosts, required bool gpuCompute});

final slotRuntimeLoaderProvider = Provider<SlotRuntimeLoader>((ref) => (bytes, {required source, required fowPermissions, required appFns, required permissions, required fuelPerCall, required fetchHosts, required gpuCompute}) async {
      // 権限はマニフェスト宣言がそのまま実行時のゲートになる (D-004)。
      // gpu.compute はさらに gpuCompute(審査済み / 自分の署名のサイドロード、D-306)が要る。`gpu_ml` の宣言はワーカーの env が重ねて見る。
      final c = AsyncWasmPluginController(wasmBytes: bytes, fowPermissions: fowPermissions, appFns: appFns, permissions: permissions, fuelPerCall: fuelPerCall, fetchHosts: fetchHosts, gpuCompute: gpuCompute);
      await c.load();
      if (c.lastError != null && c.document == null) {
        c.dispose();
        throw StateError(c.lastError!);
      }
      return _AsyncSlotRuntime(c);
    });

/// 登録元がストア(審査済み、D-168)か。`store:<id>` / `store:<id>#<childId>`。それ以外(ファイルのパス /
/// `asset:<name>`)は dev 画面からのサイドロード。
bool isReviewedSlotSource(String source) => source.startsWith('store:');

/// `gpu.compute` (D-081) の門をランタイムで開けるか。`gpu.compute` はランタイム内(wgpu)で短絡され、
/// Dart の host_fn の権限検査を通らないので、既定は閉で、埋込側がインスタンスごとに開ける(rasq-sdk-sample
/// docs/host-functions.md「gpu.compute の権限と上限」)。どちらもマニフェストの `gpu_ml` の宣言が要る:
/// - ストア (`store:`): 審査を通った配布物のマニフェストが `gpu_ml` を宣言していれば開ける。
/// - サイドロード(ファイル / `asset:`): **自分の開発者鍵の署名がある場合 ([SideloadTrust.full])** とアプリ同梱のアセット
///   ([SideloadTrust.bundled]) だけ宣言どおりに開ける。それ以外(署名なし / 他人の鍵 / 素の `.wasm`)は制限モードで閉
///   (D-306 / D-308、ユーザー決定 2026-09-24)。
///   [sideloadTrust] は register が [sideloadTrustOf] で決めた段。ストアの登録では見ない。
/// 表の値は [slotCapabilitiesFor] → [SideloadCapabilities.gpuEnabled](D-308 の表と同じ 1 か所)。
bool slotGpuComputeAllowed(SlotManifest manifest, {required String source, required SideloadTrust sideloadTrust}) =>
    manifest.permissions.contains(RasqPermissions.gpuMl) && slotCapabilitiesFor(source, sideloadTrust).gpuEnabled;

/// スロットプラグインに開けてよい能力 (D-308): ストア (`store:`、審査済み) は宣言どおり ([SideloadCapabilities.full])、
/// サイドロードは段 ([SideloadTrust.capabilities]、自分の署名 = フル / ほか = 制限モード)。
SideloadCapabilities slotCapabilitiesFor(String source, SideloadTrust sideloadTrust) =>
    isReviewedSlotSource(source) ? SideloadCapabilities.full : sideloadTrust.capabilities;

@immutable
class SlotPlugin {
  const SlotPlugin({required this.manifest, required this.source, required this.runtime, this.sideloadTrust = SideloadTrust.restricted});
  final SlotManifest manifest;

  /// サイドロードの信頼の段(D-306: 自分の署名 = full、ほかは制限モード)。ストア (`store:`) のものは審査で決まるので見ない。
  final SideloadTrust sideloadTrust;

  /// 読み込み元(ファイルパス、または `asset:<name>`)。
  final String source;
  final SlotRuntime runtime;

  String get id => manifest.id;
  bool has(String slot) => manifest.slots.contains(slot);

  /// ストアから入れた版 (D-355、登録元 `store:<id>@<version>`)。サイドロード / 古い形は null。
  String? get storeVersion => parseStoreSlotSource(source)?.version;

  /// ストアのプラグイン id(子なら入れ物の id)。サイドロードは null。
  String? get storePluginId => parseStoreSlotSource(source)?.pluginId;

  /// 例との近さを測る中身(名前 + 説明 + スロット。チャイルドセーフの `allow.examples`、D-314)。
  List<String> get examplePieces => pluginExamplePieces(name: manifest.name, description: manifest.description, slots: manifest.slots);

  /// 審査済みか(ストアからインストールしたもの、D-168)。サイドロード(ファイル / 同梱アセット)は未審査として扱い、
  /// 宣言の `auto`(temp)を読まない(契約 v0.14 §2.11)。
  bool get isReviewed => isReviewedSlotSource(source);

  /// 開けてよい能力 (D-308)。ストアは宣言どおり、サイドロードは [sideloadTrust] の表の行。
  SideloadCapabilities get capabilities => slotCapabilitiesFor(source, sideloadTrust);
  Future<Map<String, dynamic>> call(String fn, Map<String, Object?> args) => runtime.invoke(fn, args);

  /// `call` の `value`(失敗は null)。
  Future<Map<String, dynamic>?> value(String fn, Map<String, Object?> args) async {
    try {
      final r = await call(fn, args);
      return r['ok'] == true ? (r['value'] as Map?)?.cast<String, dynamic>() : null;
    } catch (e) {
      debugPrint('slot plugin ${manifest.id}.$fn: $e');
      return null;
    }
  }
}

/// 登録の永続化キー(パスの JSON 配列)。
const slotPluginsStorageKey = 'plugins.slots.v1';

/// ミュート語の設定領域/キー (D-167: `mute.add`)。
const muteWordsArea = 'mute';
const muteWordsKey = 'words';

/// 登録済みプラグイン一覧。
final slotPluginsProvider = NotifierProvider<SlotPluginsNotifier, List<SlotPlugin>>(SlotPluginsNotifier.new);

/// スロットの有効 / 無効 (D-238「プラグインの構成」): 設定エリア → スロット。キー `enabled`(既定 on)。
const slotSettingsAreas = <String, String>{
  SlotIds.trendSuggest: 'plugins.trend',
  SlotIds.composerText: 'plugins.composer',
  SlotIds.composerMedia: 'plugins.composer',
  SlotIds.tl: 'plugins.timeline',
};

/// 同じプラグインのいくつかの版が登録されているとき (D-355)、[versionOf] が返す版(そのアカウントで使う版)を 1 つ選ぶ。
/// 版を持たない登録(サイドロード / 古い形)はそのまま。選ぶ版が無ければ、最後に登録したもの。
List<SlotPlugin> resolveSlotVersions(List<SlotPlugin> all, String? Function(String storePluginId) versionOf) {
  final byKey = <String, List<SlotPlugin>>{};
  for (final p in all) {
    byKey.putIfAbsent(p.id, () => []).add(p);
  }
  final out = <SlotPlugin>[];
  for (final p in all) {
    final group = byKey[p.id]!;
    if (group.length == 1) {
      out.add(p);
      continue;
    }
    if (!identical(group.first, p)) continue; // グループの先頭で 1 回だけ決める
    final storeId = group.map((x) => x.storePluginId).whereType<String>().firstOrNull;
    final want = storeId == null ? null : versionOf(storeId);
    out.add(group.where((x) => want != null && x.storeVersion == want).firstOrNull ?? group.last);
  }
  return out;
}

/// そのアカウントで使う版を選ぶ関数 (D-355)。[accountKey] null = 既定の版。
typedef SlotVersionPicker = String? Function(String storePluginId);
SlotVersionPicker slotVersionPickerFor(List<InstalledPlugin> installed, String? accountKey) =>
    (id) => installed.where((p) => p.id == id).firstOrNull?.versionFor(accountKey);

/// **いまのアカウントで動く**スロットプラグイン (D-355): 同じプラグインの版が並んでいれば、そのアカウントの版だけ。
final activeSlotPluginsProvider = Provider<List<SlotPlugin>>((ref) {
  final all = ref.watch(slotPluginsProvider);
  final installed = ref.watch(installedPluginsProvider);
  return resolveSlotVersions(all, slotVersionPickerFor(installed, ref.watch(currentAccountProvider)?.key));
});

/// スロット別。設定で切ったスロットは空(プラグインは呼ばれない)。いまのアカウントの版だけ (D-355)。
final slotPluginsForProvider = Provider.family<List<SlotPlugin>, String>((ref, slot) {
  final area = slotSettingsAreas[slot];
  if (area != null && ref.watch(settingsAreaProvider(area)).value?['enabled'] == false) return const [];
  // チャイルドセーフ (D-307): 保護者が許したプラグイン / スロットだけ。
  final gate = ref.watch(childGateProvider);
  return [for (final p in ref.watch(activeSlotPluginsProvider)) if (p.has(slot) && gate.pluginAllowed(p.id, slot, text: p.examplePieces)) p];
});

/// 登録の失敗などの直近メッセージ(dev 画面が表示)。
final slotPluginsNoticeProvider = NotifierProvider<SlotPluginsNotice, String?>(SlotPluginsNotice.new);

class SlotPluginsNotice extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? v) => state = v;
}

class SlotPluginsNotifier extends Notifier<List<SlotPlugin>> {
  static const _fowOwner = 'slot-plugins';
  static const _fowPrefix = 'fow.slot.';

  /// トークン → 反映先(コンポーザーの添付/本文、ビューワーの重ね)。
  final Map<String, void Function(Uint8List bytes, String mime, String? name)> _mediaReplace = {};
  final Map<String, void Function(int start, int end, String text)> _textReplace = {};
  final Map<String, void Function(RrlNode root)> _overlaySet = {};
  final Map<String, void Function(Uint8List bytes, String mime, int? width, int? height)> _mediaPreview = {};
  final Map<String, void Function(RrlNode? root)> _mediaOverlay = {};
  final Map<String, void Function(String text, Uint8List? media, String? mime, String? name)> _composerOpen = {};

  /// FOW の着き方 (D-169、契約 v0.2): プラグインの `fow.open` は呼び出し元の面の子として
  /// 開く。呼び出し元(コンポーザー / ルーム FOW / メディアエディター)が入口で指定する。
  final Map<String, ({String? ownerId, int column, bool barrierless})> _fowContext = {};

  /// 開いているプラグイン FOW の entry id(エディターがプレビューを縮める判定に使う)。
  final ValueNotifier<Set<String>> openFows = ValueNotifier(const {});

  /// [barrierless] = 余白タップで閉じないし、外のボタン(エディターの丸ボタン列)にタップが通る。
  void _setFowContext(SlotPlugin plugin, String? ownerId, int column, {bool barrierless = false}) => _fowContext[plugin.id] = (ownerId: ownerId, column: column, barrierless: barrierless);

  /// AsTell: プラグインごとの現在のトークン(FOW を開いている間の通知先)。
  final Map<String, String> _astellTokens = {};
  Set<String> _seenShares = {};
  Set<String> _seenPeers = {};
  bool _restored = false;

  /// `state` の写し(dispose 用)。
  final List<SlotPlugin> _live = [];
  bool _disposed = false;

  void _set(List<SlotPlugin> next) {
    _live
      ..clear()
      ..addAll(next);
    state = next;
  }

  @override
  List<SlotPlugin> build() {
    // dispose 時は `state` を触れない(ライフサイクル内の Ref 使用になる)ので写しを持つ。
    ref.onDispose(() {
      _disposed = true;
      for (final p in _live) {
        p.runtime.dispose();
      }
    });
    // AsTell の出来事をプラグインへ (CONTRACT §2.1 `astell.event`)。
    ref.listen<AstellSessionState?>(astellSessionProvider, _onAstellChanged);
    // 自分の開発者鍵の一覧 (D-306) が届いた / 変わった: 登録済みのサイドロードの段を確かめ直す(起動直後の読み直しは
    // 一覧が届く前に走るので、ここで full へ上がる。鍵を失効すれば restricted へ下がる)。
    ref.listen<Set<String>>(ownDevKeyFingerprintsProvider, (prev, next) {
      if (!setEquals(prev, next)) Future.microtask(_reevaluateSideloadTrust);
    });
    if (!_restored) {
      _restored = true;
      Future.microtask(_restore);
    }
    return const [];
  }

  Future<void> _restore() async {
    // 全画面トグルの保存の移行 (契約 v0.14 §2.4、D-305): プラグインを読み直す前に 1 回。
    await migrateViewerPluginSettings(ref);
    if (_disposed) return;
    try {
      final raw = await ref.read(sessionStorageProvider).read(slotPluginsStorageKey);
      if (raw == null) return;
      // 同じ .rasqpkg から複数(root と子)を読むので、取り直しはプラグイン id ごとに 1 回。
      final artifacts = <String, Uint8List>{}; // `<id>@<版>` → 配布物
      for (final p in (jsonDecode(raw) as List)) {
        if (p is! String) continue;
        // ストアからのインストール (D-168): 配布物を取り直す(モックは同梱アセット)。`store:<id>#<childId>` は
        // .rasqpkg の中の子。取り直したものは**インストール時に検証した SHA-512 と同じ**でなければ読み込まない
        // (ストア署名を確かめたのはインストール時だけなので、ここで別物にすり替わっていないことを見る)。
        if (p.startsWith('store:')) {
          // 版つきの登録元 (D-355) はその版の配布物を取り直す(古い形 `store:<id>` は既定の版 = 現在版)。
          final (:pluginId, :version, child: _) = parseStoreSlotSource(p)!;
          try {
            final bytes = artifacts['$pluginId@${version ?? ''}'] ??= await ref.read(storeClientProvider).downloadArtifact(pluginId, 'bundle', version: version);
            final record = ref.read(installedPluginsProvider).where((x) => x.id == pluginId).firstOrNull;
            final expected = version == null ? record?.sha512 : record?.versionInfo(version)?.sha512;
            if (expected != null && expected.isNotEmpty && expected != '-' && sha512.convert(bytes).toString() != expected) {
              ref.read(slotPluginsNoticeProvider.notifier).set('$pluginId: 取り直した配布物がインストール時と違うため読み込みません(ストアで入れ直してください)');
              continue;
            }
            await register(p, bytes: bytes, persist: false);
          } catch (e) {
            debugPrint('slot plugin restore $p: $e');
          }
          continue;
        }
        await register(p, persist: false);
      }
    } catch (e) {
      debugPrint('slot plugins restore: $e');
    }
  }

  Future<void> _persist() async {
    await ref.read(sessionStorageProvider).write(slotPluginsStorageKey, jsonEncode([for (final p in state) p.source]));
  }

  /// 読み込んで登録。`bytes` を渡せばファイルを読まない(同梱アセット等)。
  ///
  /// 中身が `.rasqpkg`(zstd)なら展開・検証して、その中の 1 つを登録する: `source` の `#<pluginId>` が指す子、
  /// 無ければ root。登録するのは sns 以外(SNS プラグイン本体の差し替えはここではしない)。
  Future<SlotPlugin?> register(String source, {Uint8List? bytes, bool persist = true}) async {
    try {
      final (:container, :pluginId) = splitPackageSource(source);
      // `asset:` はアプリ同梱のアセット(次回起動の読み直しは bytes 無しで来る)。
      var data = bytes ?? await readSideloadContainer(container);
      // サイドロードの信頼の段 (D-306 / D-308): 展開する前の配布物そのものと、隣の `.sig.json` で決める(同梱のアセットはフル)。
      // 次回起動の読み直しでも毎回ここを通る(登録時の結果を覚えておかない)。
      // 一覧が届く前 / 変わる途中に読んだ段は、登録のあとで [_reevaluateSideloadTrust] が確かめ直す。
      final ownFingerprints = ref.read(ownDevKeyFingerprintsProvider);
      final sideloadTrust = isReviewedSlotSource(source)
          ? SideloadTrust.restricted
          : await sideloadTrustOfContainer(container, data, ownFingerprints: ownFingerprints);
      String? expectedId;
      if (isRasqPackage(data)) {
        final entry = RasqPackage.open(data, decompress: ref.read(rasqpkgZstdProvider)).plugin(pluginId);
        if (entry.isSns) throw StateError('${entry.id} は SNS プラグインです(スロットには登録できません)');
        data = entry.wasm;
        expectedId = entry.id;
      }
      final loader = ref.read(slotRuntimeLoaderProvider);
      // 制限モード (D-308): 宣言をさらに絞る表の行。ストアは宣言どおり。
      final caps = slotCapabilitiesFor(source, sideloadTrust);
      // マニフェストを読むために一度素の権限で起動し、宣言に合わせて起動し直す。
      // 1 段目はマニフェストを読むだけ。予算はランタイム既定(重いほう)に任せる(制限モードはその倍率)。
      var runtime = await loader(data, source: source, fowPermissions: const {'widget'}, appFns: const {}, permissions: const {}, fuelPerCall: caps.fuelPerCall(null), fetchHosts: const {}, gpuCompute: false);
      final m = (await runtime.invoke('plugin.manifest', const {}))['value'];
      if (m is! Map) {
        runtime.dispose();
        throw StateError('plugin.manifest がありません(スロット契約 §1)');
      }
      final manifest = SlotManifest.fromJson(m.cast<String, Object?>());
      if (manifest.id.isEmpty) {
        runtime.dispose();
        throw StateError('plugin.manifest.id が空です');
      }
      // 配布物の目次が言う id と、wasm 自身が名乗る id が同じこと(別のプラグインを入れ物に紛れ込ませない)。
      if (expectedId != null && manifest.id != expectedId) {
        runtime.dispose();
        throw StateError('配布物の目次は $expectedId なのに、wasm は ${manifest.id} を名乗っています');
      }
      runtime.dispose();
      // 2 段目は宣言どおり、ただし制限モード (D-308) の表で絞る: `network` / `storage.unsafe` / `gpu_ml` /
      // `fow.interstitial` / `fow.system` を権限から外し、接続先を空に、閉じるアプリ向けホスト関数を外し、fuel は倍率を掛ける。
      // 外したものはワーカーの環境(端末: RasqHostEnvironment、Web: Worker の JS)が `E01` で断る(どちらも同じ config を受ける)。
      runtime = await loader(data, source: source, fowPermissions: caps.fowKinds(manifest.fowPermissions), appFns: caps.appFns(manifest.appFns), permissions: caps.permissions(manifest.permissions),
          fuelPerCall: caps.fuelPerCall(fuelBudgetFor(permissions: manifest.permissions.toSet(), slots: manifest.slots.toSet())), fetchHosts: caps.fetchHosts(manifest.fetchHosts),
          gpuCompute: slotGpuComputeAllowed(manifest, source: source, sideloadTrust: sideloadTrust));
      if (_disposed) {
        runtime.dispose(); // 読み込み中にプロバイダーが捨てられた(テストの再構築など)
        return null;
      }
      final plugin = SlotPlugin(manifest: manifest, source: source, runtime: runtime, sideloadTrust: sideloadTrust);
      runtime.onAppFn = (fn, args) => _onAppFn(plugin, fn, args);
      _wireFow(plugin);
      // 通信の形(同意した端末だけ、初めて見たものだけ)。版はプラグインの自己申告。
      final telemetry = ref.read(fetchShapeTelemetryProvider);
      runtime.fetchShapes.listen((s) => telemetry.report(manifest.id, manifest.version, s));
      // 同じ id は差し替え。ただしストアの**別の版**(D-355: `store:<id>@<版>`)は並べて持つ(アカウントごとに使う版を選ぶ)。
      final version = plugin.storeVersion;
      bool replaces(SlotPlugin p) => p.id == manifest.id && (version == null || p.storeVersion == null || p.storeVersion == version);
      for (final old in state.where(replaces)) {
        old.runtime.dispose();
      }
      _set([for (final p in state) if (!replaces(p)) p, plugin]);
      if (persist) await _persist();
      ref.read(slotPluginsNoticeProvider.notifier).set('${manifest.name} を登録しました(${manifest.slots.join(', ')})');
      // 登録している間に鍵の一覧が変わった(listen は、まだ state に無いこのプラグインを見られなかった)。
      if (!plugin.isReviewed && !setEquals(ownFingerprints, ref.read(ownDevKeyFingerprintsProvider))) Future.microtask(_reevaluateSideloadTrust);
      return plugin;
    } catch (e) {
      if (!_disposed) ref.read(slotPluginsNoticeProvider.notifier).set('登録できませんでした: $e');
      return null;
    }
  }

  bool _reevaluating = false;
  bool _reevaluateAgain = false;

  /// 登録済みのサイドロード(ストア以外)の [SideloadTrust] を、いまの [ownDevKeyFingerprintsProvider] で確かめ直す (D-306)。
  /// **段が変わったものだけ**読み直す(`register` で起動し直す = `gpu.compute` の門を開け直す / 閉じ直す。プラグインの実行中の
  /// 状態はそこで捨てる)。変わらないものは触らない。配布物が読めなくなったもの(ファイルが消えた)はそのまま。
  /// **いつ**: 鍵の一覧が変わったとき(listen)と、登録の途中で一覧が変わったとき。次回起動の読み直しでも `register` が毎回確かめる。
  Future<void> _reevaluateSideloadTrust() async {
    if (_disposed) return;
    if (_reevaluating) {
      _reevaluateAgain = true;
      return;
    }
    _reevaluating = true;
    try {
      do {
        _reevaluateAgain = false;
        final own = ref.read(ownDevKeyFingerprintsProvider);
        for (final p in [...state]) {
          if (_disposed) return;
          if (p.isReviewed) continue;
          final container = splitPackageSource(p.source).container;
          final Uint8List bytes;
          try {
            bytes = await readSideloadContainer(container);
          } catch (e) {
            debugPrint('slot plugin ${p.id}: sideload trust not re-evaluated (unreadable): $e');
            continue;
          }
          final trust = await sideloadTrustOfContainer(container, bytes, ownFingerprints: own);
          if (_disposed) return;
          // 読み直しのあいだに外された / 差し替えられたものは見ない。
          if (trust != p.sideloadTrust && state.any((x) => identical(x, p))) await register(p.source, bytes: bytes, persist: false);
        }
      } while (_reevaluateAgain && !_disposed);
    } finally {
      _reevaluating = false;
    }
  }

  Future<void> unregister(String id) async {
    for (final p in state.where((p) => p.id == id)) {
      ref.read(overlayManagerProvider).closeOwnedBy('$_fowOwner.$id');
      p.runtime.dispose();
    }
    _astellTokens.remove(id);
    _set([for (final p in state) if (p.id != id) p]);
    await _persist();
  }

  /// 登録元 1 つだけ外す (D-355: 使わなくなった版)。
  Future<void> unregisterSource(String source) async {
    final gone = [for (final p in state) if (p.source == source) p];
    if (gone.isEmpty) return;
    for (final p in gone) {
      p.runtime.dispose();
    }
    _set([for (final p in state) if (p.source != source) p]);
    // 同じ id の版がもう無ければ、FOW と AsTell の口も閉じる。
    for (final p in gone) {
      if (!state.any((x) => x.id == p.id)) {
        ref.read(overlayManagerProvider).closeOwnedBy('$_fowOwner.${p.id}');
        _astellTokens.remove(p.id);
      }
    }
    await _persist();
  }

  /// そのアカウント([accountKey]、省略 = いまのアカウント)で動く版だけ (D-355)。
  List<SlotPlugin> active({String? accountKey}) =>
      resolveSlotVersions(state, slotVersionPickerFor(ref.read(installedPluginsProvider), accountKey ?? ref.read(currentAccountProvider)?.key));

  List<SlotPlugin> forSlot(String slot, {String? accountKey}) {
    // チャイルドセーフ (D-307): 保護者が許したプラグイン(`allow.plugins.ids`)とスロット(`allow.plugins.slots`)だけ。
    final gate = ref.read(childGateProvider);
    return [for (final p in active(accountKey: accountKey)) if (p.has(slot) && gate.pluginAllowed(p.id, slot, text: p.examplePieces)) p];
  }

  // ── FOW(プラグインの拡張面)────────────────────────────────────────

  void _wireFow(SlotPlugin plugin) {
    final view = plugin.runtime.view;
    if (view is! WasmFowSurfaceHost) return;
    final host = view as WasmFowSurfaceHost;
    host.onFowOpen = (req) => _openFow(plugin, req);
    host.onFowClose = (id, {result, reason}) => ref.read(overlayManagerProvider).close('$_fowPrefix${plugin.id}.$id', result: result);
  }

  void _openFow(SlotPlugin plugin, WasmFowRequest req) {
    final manager = ref.read(overlayManagerProvider);
    final controller = plugin.runtime.view;
    final spec = req.spec;
    final type = switch ('${spec['type']}') {
      'interstitial' => FowPanelType.interstitial,
      'system' => FowPanelType.system,
      _ => FowPanelType.widget,
    };
    final ctx = _fowContext[plugin.id];
    final fowSpec = FowSpec(
      type: type,
      initialHeightFactor: (spec['initialHeightFactor'] as num?)?.toDouble() ?? 0.45,
      title: spec['title'] as String?,
      cancelText: spec['cancelText'] as String? ?? (req.onCancel != null ? '閉じる' : null),
      confirmText: spec['confirmText'] as String?,
      dockAboveFooter: true,
      // 呼び出し元の面と同じカラム(インライン FOW、D-169)。
      columnIndex: ctx?.column ?? 0,
    );
    fowSpec.attachTop = spec['attachTop'] == true;
    if (req.anchorNode != null || req.anchorRole != null) {
      final scope = req.document.scope;
      fowSpec.anchor = controller.geometry.lookup(nodeId: req.anchorNode == null ? null : '$scope:${req.anchorNode}', role: req.anchorRole);
    }
    final onCancelFn = req.onCancel;
    if (onCancelFn != null) {
      fowSpec.interceptCancel = () => controller.handleEvent('${req.document.scope}:${req.id}', 'cancel', fn: onCancelFn, payload: {'id': req.id});
    }
    final owner = '$_fowOwner.${plugin.id}';
    final entryId = '$_fowPrefix${plugin.id}.${req.id}';
    openFows.value = {...openFows.value, entryId};
    manager.show(RasqOverlayEntry(
      id: entryId,
      layer: OverlayLayer.fow,
      alignment: Alignment.bottomCenter,
      // 親: プラグイン内の親 FOW > 呼び出し元の面(コンポーザー / ルーム FOW / エディター、D-169)> プラグイン自身。
      // 親が閉じれば連動して閉じる。
      ownerId: req.parentId != null ? '$_fowPrefix${plugin.id}.${req.parentId}' : (ctx?.ownerId ?? owner),
      semanticsLabel: spec['title'] as String? ?? plugin.manifest.name,
      // エディターの下付き FOW (D-169) はバリア無し: 開いたまま左右の列を押せる。
      barrierBehavior: ctx?.barrierless == true ? OverlayBarrierBehavior.none : OverlayBarrierBehavior.dismissDiscard,
      fow: fowSpec,
      onClosed: (reason, result) {
        if (reason == OverlayCloseReason.replaced) return;
        openFows.value = {...openFows.value}..remove(entryId);
        (controller as WasmFowSurfaceHost).notifyFowClosed(req.id, reason: reason.name, result: result);
      },
      builder: (ctx, handle) => WasmFowView(controller: controller, request: req, rslParser: InlineSpans.parse),
    ));
  }

  // ── アプリ向けホスト関数(fire-and-forget)────────────────────────

  void _onAppFn(SlotPlugin plugin, String fn, Map<String, Object?> args) {
    if (_disposed) return;
    // 制限モード (D-308) で閉じた関数は、ワーカーの環境が `E01` で断っていてここへは来ない。念のためここでも落とす
    // (トーストは出さない: プラグインは `E01` を受け取っている。チャイルドセーフの関所とも重ねて知らせない)。
    if (plugin.capabilities.blockedHostFns.contains(fn)) {
      debugPrint('slot plugin ${plugin.id}: $fn is closed in restricted mode (D-308)');
      return;
    }
    switch (fn) {
      case RasqHostFns.toast:
        _toast('${plugin.manifest.name}: ${args['message'] ?? ''}');
      case RasqHostFns.soundPlay:
        SystemSound.play(args['kind'] == 'alert' ? SystemSoundType.alert : SystemSoundType.click);
      case RasqHostFns.clipboardSet:
        Clipboard.setData(ClipboardData(text: '${args['text'] ?? ''}'));
      case RasqHostFns.urlOpen:
        // scheme はランタイム側 (host_environment / Worker) で http(s) に絞っているが、ここでも確かめる。
        final u = Uri.tryParse('${args['url']}');
        if (u != null && (u.isScheme('https') || u.isScheme('http'))) launchUrl(u, mode: LaunchMode.externalApplication);
      case RasqHostFns.muteAdd:
        _muteAdd(plugin, '${args['text'] ?? ''}');
      case RasqHostFns.astellShare:
        _astellShare(plugin, '${args['kind'] ?? 'text'}', (args['payload'] as Map?)?.cast<String, Object?>() ?? const {});
      case RasqHostFns.composerMediaReplace:
        final cb = _mediaReplace['${args['token']}'];
        final b64 = args['bytesB64'];
        if (cb != null && b64 is String) {
          try {
            cb(base64Decode(b64), '${args['mimeType'] ?? 'image/png'}', args['name'] as String?);
          } catch (e) {
            _toast('${plugin.manifest.name}: 画像を受け取れませんでした($e)');
          }
        }
      case RasqHostFns.composerMediaPreview:
        final cb = _mediaPreview['${args['token']}'];
        final b64 = args['bytesB64'];
        if (cb != null && b64 is String) {
          try {
            cb(base64Decode(b64), '${args['mimeType'] ?? 'image/png'}', (args['width'] as num?)?.toInt(), (args['height'] as num?)?.toInt());
          } catch (e) {
            debugPrint('media preview: $e');
          }
        }
      case RasqHostFns.composerMediaOverlay:
        // プレビューの上に重ねる RRL (契約 v0.5 §2.2)。root: null で消す。
        final cb = _mediaOverlay['${args['token']}'];
        final root = args['root'];
        if (cb != null) cb(root is Map ? RrlNode.fromJson(root.cast<String, Object?>()) : null);
      case RasqHostFns.composerTextReplace:
        final cb = _textReplace['${args['token']}'];
        if (cb != null) cb((args['start'] as num?)?.toInt() ?? 0, (args['end'] as num?)?.toInt() ?? 0, '${args['text'] ?? ''}');
      case RasqHostFns.viewerOverlaySet:
        final cb = _overlaySet['${args['token']}'];
        final root = args['root'];
        if (cb != null && root is Map) cb(RrlNode.fromJson(root.cast<String, Object?>()));
      case RasqHostFns.composerOpen:
        final cb = _composerOpen['${args['token']}'];
        if (cb == null) return;
        final b64 = args['mediaB64'];
        Uint8List? media;
        try {
          if (b64 is String) media = base64Decode(b64);
        } catch (_) {
          media = null;
        }
        cb('${args['text'] ?? ''}', media, args['mimeType'] as String?, args['name'] as String?);
    }
  }

  void _toast(String message) {
    if (_disposed) return;
    final ctx = ref.read(rootMessengerKeyProvider).currentState;
    ctx?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _muteAdd(SlotPlugin plugin, String text) async {
    if (text.trim().isEmpty) return;
    final ok = await ref.read(overlayManagerProvider).showAlert(id: 'slot.mute.${plugin.id}', title: 'ミュート語に追加', message: '${plugin.manifest.name} が「$text」をミュート語に追加しようとしています。', confirmText: '追加', cancelText: 'キャンセル');
    if (!ok) return;
    final store = ref.read(settingsAreaProvider(muteWordsArea).notifier);
    final current = [for (final w in ((await ref.read(settingsAreaProvider(muteWordsArea).future))[muteWordsKey] as List? ?? const [])) if (w is String) w];
    if (!current.contains(text)) await store.set(muteWordsKey, [...current, text]);
    _toast('「$text」をミュート語に追加しました');
  }

  Future<void> _astellShare(SlotPlugin plugin, String kind, Map<String, Object?> payload) async {
    final session = ref.read(astellSessionProvider.notifier);
    final s = ref.read(astellSessionProvider);
    if (s == null) return;
    var p = payload;
    if (kind == 'media' && payload['bytesB64'] is String) {
      // 生成画像 (CONTRACT §2.1): アセットにアップロードして URL にする。
      try {
        final bytes = base64Decode(payload['bytesB64'] as String);
        final mime = '${payload['mimeType'] ?? 'image/png'}';
        final name = '${payload['name'] ?? 'effect.png'}';
        final asset = await ref.read(astellClientProvider).uploadAsset(s.room.id, bytes, name: name, contentType: mime);
        p = {
          'name': name,
          'title': payload['title'] ?? name,
          'mimeType': mime,
          'sizeBytes': bytes.length,
          'assetId': asset.id,
          'url': asset.url.toString(),
          if (mime.startsWith('image/')) 'thumbnailUrl': asset.url.toString(),
        };
      } catch (e) {
        _toast('${plugin.manifest.name}: 効果映像を送れませんでした($e)');
        return;
      }
    }
    session.share(kind, p);
  }

  // ── スロット別の入口(アプリの各所から呼ぶ)──────────────────────

  /// AsTell (CONTRACT §2.1): プラグインアクションから選ばれた。
  /// [action] = 押されたボタンの宣言 id(契約 v0.15: マニフェストの `actions` に `slot: "astell.action"` を書いたもの)。
  /// 宣言の無いプラグインの既定ボタンなら null(payload に `action` を載せない)。
  Future<void> astellOpen(SlotPlugin plugin, AstellSessionState s, {String? action, String? fowOwner, int column = 0}) async {
    _setFowContext(plugin, fowOwner, column);
    final token = 'astell-${DateTime.now().microsecondsSinceEpoch}';
    _astellTokens[plugin.id] = token;
    _seenShares = {for (final x in s.shares) x.id};
    _seenPeers = {for (final x in s.peers) x.peerId};
    await plugin.value('astell.open', {
      'token': token,
      'action': ?action,
      'room': s.room.toJson(),
      'me': {'accountId': s.myAccountId, 'peerId': s.myPeerId, 'handle': 'me', 'displayName': 'あなた'},
      'peers': [for (final p in s.peers) _peerJson(p)],
      // 古い → 新しい(ルームのログ順)。直近 10 件。
      'shares': [for (final x in (s.shares.length > 10 ? s.shares.sublist(s.shares.length - 10) : s.shares)) _shareJson(x)],
    });
  }

  static Map<String, Object?> _peerJson(AstellPeer p) => {'peerId': p.peerId, 'accountId': p.accountId, 'handle': p.handle, 'displayName': p.displayName, 'micOn': p.micOn};
  static Map<String, Object?> _shareJson(AstellShare x) => {'id': x.id, 'kind': x.kind, 'payload': x.payload, 'displayName': x.displayName, 'handle': x.handle, 'createdAt': x.createdAt.toIso8601String()};

  void _onAstellChanged(AstellSessionState? prev, AstellSessionState? next) {
    if (_astellTokens.isEmpty) return;
    void send(Map<String, Object?> ev) {
      for (final p in active()) {
        final token = _astellTokens[p.id];
        if (token != null) p.value('astell.event', {'token': token, ...ev});
      }
    }
    if (next == null || (prev != null && next.room.id != prev.room.id)) {
      send({'type': 'closed'});
      _astellTokens.clear();
      return;
    }
    for (final x in next.shares) {
      if (_seenShares.add(x.id)) send({'type': 'share', 'share': _shareJson(x)});
    }
    final peers = {for (final p in next.peers) p.peerId: p};
    for (final p in peers.values) {
      if (_seenPeers.add(p.peerId)) send({'type': 'peer-joined', 'peer': _peerJson(p)});
    }
    for (final id in _seenPeers.toList()) {
      if (!peers.containsKey(id)) {
        _seenPeers.remove(id);
        send({'type': 'peer-left', 'peer': {'peerId': id}});
      }
    }
    if (next.transcripts.isNotEmpty && (prev == null || next.transcripts.length != prev.transcripts.length)) {
      final t = next.transcripts.last;
      send({'type': 'transcript', 'transcript': {'id': t.id, 'displayName': t.displayName, 'text': t.text}});
    }
  }

  /// メディアプラグインへ渡す前に縮める長辺の上限 (CONTRACT §2.2)。
  ///
  /// ランタイムの fuel 予算は 1 呼び出し 60 億。実測では `media.edit` が
  /// 2048x1536 で 21.5 億に対し、12MP (4032x3024) では 84.6 億で予算を超え、
  /// E02 で落ちる。インタプリタを 12 秒ブロックするのは上限を上げる理由には
  /// ならないので、渡す前にホストが縮める。
  ///
  /// 縮めると `media.commit` が返す「本サイズ」もこの寸法になる。解像度は
  /// 落ちるが、落とさなければ編集自体ができない。
  static const mediaEditMaxSide = 2048;

  /// 編集へ渡す前に、大きすぎる画像だけを縮める。
  ///
  /// 画素数はヘッダーから読む(復号しない)。**復号まで進むのは上限を
  /// 超えていると分かったときだけ**で、それ以外はバイト列に触らない。
  /// 復号は背景スレッドへ出るため、毎回待つ作りにすると UI の経路が
  /// 実非同期に引きずられる。
  ///
  /// 画像以外・読めない形式・縮小に失敗したものはそのまま通す。ここで
  /// 落としても添付が編集できなくなるだけで、歯止めはランタイム側の
  /// fuel 上限(超過は E02)が担う。
  Future<ScaledImage> _fitForEdit(SlotPlugin plugin, Uint8List bytes, String mimeType) async {
    final passthrough = ScaledImage(bytes: bytes, mimeType: mimeType, width: 0, height: 0, scaled: false);
    if (!mimeType.startsWith('image/')) return passthrough;
    final size = imageSizeFromHeader(bytes);
    if (size == null) return passthrough;
    final (width, height) = size;
    if (width <= mediaEditMaxSide && height <= mediaEditMaxSide) {
      return ScaledImage(bytes: bytes, mimeType: mimeType, width: width, height: height, scaled: false);
    }
    try {
      final fitted = await fitWithin(bytes, mediaEditMaxSide, mimeType: mimeType);
      if (fitted.scaled) {
        _toast('${plugin.manifest.name}: 編集のため長辺 $mediaEditMaxSide px に縮小しました');
      }
      return fitted;
    } catch (e) {
      debugPrint('media.edit: 縮小できませんでした($e)');
      return passthrough;
    }
  }

  /// コンポーザーの添付 (CONTRACT §2.2)。戻りは即時差し替え(あれば)。
  Future<void> mediaEdit(SlotPlugin plugin, {required int index, required String name, required String mimeType, required Uint8List bytes, required void Function(Uint8List bytes, String mime, String? name) onReplace, String? fowOwner, int column = 0}) async {
    _setFowContext(plugin, fowOwner, column);
    final token = 'media-${DateTime.now().microsecondsSinceEpoch}';
    _mediaReplace[token] = onReplace;
    final fitted = await _fitForEdit(plugin, bytes, mimeType);
    final v = await plugin.value('media.edit', {'token': token, 'index': index, 'name': name, 'mimeType': fitted.mimeType, if (fitted.width > 0) 'width': fitted.width, if (fitted.height > 0) 'height': fitted.height, 'bytesB64': base64Encode(fitted.bytes)});
    if (v != null && v['bytesB64'] is String) {
      try {
        onReplace(base64Decode(v['bytesB64'] as String), '${v['mimeType'] ?? mimeType}', v['name'] as String?);
      } catch (e) {
        _toast('${plugin.manifest.name}: 画像を受け取れませんでした($e)');
      }
    }
  }

  /// メディアエディター (D-169、契約 v0.2 §2.2): `media.edit` を開いて genres を受ける。
  /// 戻り null = エディター形ではない(旧形 / 即差し替え形)。
  Future<MediaEditSession?> mediaEditorOpen(SlotPlugin plugin, {required String name, required String mimeType, required Uint8List bytes, required void Function(Uint8List bytes, String mime, int? width, int? height) onPreview, required void Function(Uint8List bytes, String mime, String? name) onReplace, void Function(RrlNode? root)? onOverlay, String? actionId, String? fowOwner, int column = 0}) async {
    _setFowContext(plugin, fowOwner, column, barrierless: true);
    final token = 'media-${DateTime.now().microsecondsSinceEpoch}';
    _mediaPreview[token] = onPreview;
    _mediaReplace[token] = onReplace;
    if (onOverlay != null) _mediaOverlay[token] = onOverlay;
    final fitted = await _fitForEdit(plugin, bytes, mimeType);
    final v = await plugin.value('media.edit', {'token': token, 'index': 0, 'name': name, 'mimeType': fitted.mimeType, 'actionId': ?actionId, if (fitted.width > 0) 'width': fitted.width, if (fitted.height > 0) 'height': fitted.height, 'bytesB64': base64Encode(fitted.bytes)});
    if (v == null) {
      _mediaPreview.remove(token);
      _mediaReplace.remove(token);
      _mediaOverlay.remove(token);
      return null;
    }
    if (v['bytesB64'] is String) {
      try {
        onReplace(base64Decode(v['bytesB64'] as String), '${v['mimeType'] ?? mimeType}', v['name'] as String?);
      } catch (_) {}
      return null;
    }
    return MediaEditSession(plugin: plugin, token: token, genres: parseMediaGenres(v['genres']));
  }

  /// `media.catalog` (契約 v0.4 §2.2): セッション無しの静的なジャンル / アクション一覧。無ければ null。
  Future<List<MediaGenre>?> mediaCatalog(SlotPlugin plugin) async {
    final v = await plugin.value('media.catalog', const {});
    if (v == null) return null;
    return parseMediaGenres(v['genres']);
  }

  /// `{genres: [{id, label?, icon?, actions: [{id, label, icon?}]}]}` の genres 部分。
  static List<MediaGenre> parseMediaGenres(Object? raw) {
    final genres = <MediaGenre>[];
    for (final g in (raw as List? ?? const [])) {
      if (g is! Map || g['id'] is! String) continue;
      genres.add(MediaGenre(
        id: g['id'] as String,
        label: g['label'] as String? ?? mediaGenreDefaults[g['id']]?.label ?? g['id'] as String,
        icon: g['icon'] as String?,
        actions: [
          for (final a in (g['actions'] as List? ?? const []))
            if (a is Map && a['id'] is String) MediaAction(id: a['id'] as String, label: a['label'] as String? ?? a['id'] as String, icon: a['icon'] as String?),
        ],
      ));
    }
    return genres;
  }

  /// カスタムフィルター (契約 v0.12): 描画リスト。戻りは `filter.preview` の value(無ければ null)。
  Future<Map<String, dynamic>?> filterPreview(SlotPlugin plugin, {required String actionId, required int width, required int height, required int seed, Map<String, double>? params}) =>
      plugin.value('filter.preview', {'actionId': actionId, 'width': width, 'height': height, 'seed': seed, 'params': ?params});

  /// カスタムフィルターの `mode: "pixels"`: 焼き込んだ 1 枚を渡して、書き換えた結果を受け取る。失敗は null。
  Future<(Uint8List, String)?> filterApply(SlotPlugin plugin, {required String actionId, required int seed, required int width, required int height, required Uint8List bytes, String mimeType = 'image/png', Map<String, double>? params}) async {
    final v = await plugin.value('filter.apply', {'actionId': actionId, 'seed': seed, 'width': width, 'height': height, 'params': ?params, 'mimeType': mimeType, 'bytesB64': base64Encode(bytes)});
    if (v == null || v['bytesB64'] is! String) return null;
    try {
      return (base64Decode(v['bytesB64'] as String), '${v['mimeType'] ?? mimeType}');
    } catch (_) {
      return null;
    }
  }

  Future<void> mediaAction(MediaEditSession s, String genre, String action) => s.plugin.value('media.action', {'token': s.token, 'genre': genre, 'action': action});

  /// 適用: 本サイズの結果(戻り)か、`composer.media.replace` 経由。
  Future<(Uint8List, String, String?)?> mediaCommit(MediaEditSession s) async {
    final overlay = ref.read(overlayManagerProvider);
    final v = await s.plugin.value('media.commit', {'token': s.token});
    _mediaPreview.remove(s.token);
    _mediaReplace.remove(s.token);
    _mediaOverlay.remove(s.token);
    if (!_disposed) overlay.closeOwnedBy('$_fowOwner.${s.plugin.id}');
    if (v != null && v['bytesB64'] is String) {
      try {
        return (base64Decode(v['bytesB64'] as String), '${v['mimeType'] ?? 'image/png'}', v['name'] as String?);
      } catch (_) {}
    }
    return null;
  }

  Future<void> mediaCancel(MediaEditSession s) async {
    _mediaPreview.remove(s.token);
    _mediaReplace.remove(s.token);
    _mediaOverlay.remove(s.token);
    if (_disposed) return;
    final overlay = ref.read(overlayManagerProvider);
    await s.plugin.value('media.cancel', {'token': s.token});
    if (!_disposed) overlay.closeOwnedBy('$_fowOwner.${s.plugin.id}');
  }

  /// コンポーザー本文 (CONTRACT §2.3)。`token` は入力欄ごとに 1 つ。
  void textChanged(SlotPlugin plugin, {required String token, required String text, required int selectionStart, required int selectionEnd, required void Function(int start, int end, String text) onReplace, String? fowOwner, int column = 0}) {
    _setFowContext(plugin, fowOwner, column);
    _textReplace[token] = onReplace;
    plugin.value('text.changed', {'token': token, 'text': text, 'selectionStart': selectionStart, 'selectionEnd': selectionEnd, 'trigger': ?triggerBeforeCursor(text, selectionStart)});
  }

  /// カーソル直前のトークン(`#タグ` / `@handle` / `:emoji`)。無ければ null。
  static String? triggerBeforeCursor(String text, int cursor) {
    if (cursor < 0 || cursor > text.length) return null;
    var i = cursor;
    while (i > 0) {
      final c = text[i - 1];
      if (c == ' ' || c == '\n' || c == '\t' || c == '　') break;
      i--;
    }
    final tok = text.substring(i, cursor);
    if (tok.isEmpty) return null;
    return (tok.startsWith('#') || tok.startsWith('@') || tok.startsWith(':')) ? tok : null;
  }

  void textDone(String token) => _textReplace.remove(token);

  /// メディア全画面 (CONTRACT §2.4)。戻りは重ねる RRL(無ければ null)と、失敗の説明(成功なら null)。
  /// 契約では壊れた入力(`D01`)は「黙って重ねない」だが、ユーザーには理由を見せる (D-246: トグルに出す)。
  Future<({RrlNode? root, String? error})> viewerOpen(SlotPlugin plugin, {required String token, required String url, required String mimeType, required int width, required int height, Uint8List? bytes, required void Function(RrlNode root) onOverlay}) async {
    _overlaySet[token] = onOverlay;
    try {
      final r = await plugin.call('viewer.open', {'token': token, 'url': url, 'mimeType': mimeType, 'width': width, 'height': height, if (bytes != null) 'bytesB64': base64Encode(bytes)});
      if (r['ok'] != true) {
        final e = r['error'];
        return (root: null, error: e is Map ? '${e['code'] ?? ''} ${e['message'] ?? ''}'.trim() : 'プラグインがエラーを返しました');
      }
      final root = (r['value'] as Map?)?['root'];
      return (root: root is Map ? RrlNode.fromJson(root.cast<String, Object?>()) : null, error: null);
    } catch (e) {
      debugPrint('slot plugin ${plugin.manifest.id}.viewer.open: $e');
      return (root: null, error: '$e');
    }
  }

  void viewerClose(SlotPlugin plugin, String token) {
    _overlaySet.remove(token);
    plugin.value('viewer.close', {'token': token});
  }

  /// 投稿加工 (CONTRACT §2.5): 登録済みプラグインを順に通す。
  /// switch(契約 v0.14 §2.11、D-305)で切ったもの(ActionKey `slot:<pluginId>:post.transform`)は通さない。
  Future<List<Post>> transform(List<Post> posts) async {
    var out = posts;
    final prefs = ref.read(actionButtonPrefsProvider);
    for (final p in forSlot(SlotIds.postTransform)) {
      if (!prefs.switchOn(postTransformActionId(p.id))) continue;
      final v = await p.value('post.transform', {'posts': [for (final x in out) SnsWire.post(x)]});
      final m = v?['posts'];
      if (m is! Map) continue;
      out = [
        for (final x in out)
          if (m[x.id] is Map) x.copyWith(body: (m[x.id] as Map)['body'] as String? ?? x.body, contentWarning: (m[x.id] as Map)['cw'] as String? ?? x.contentWarning) else x,
      ];
    }
    return out;
  }

  /// カスタム TL (CONTRACT §2.6): 全プラグインの宣言。id は `slot:<pluginId>:<id>`。
  Future<List<(SlotPlugin, CustomTimelineSpec)>> timelines() async {
    final out = <(SlotPlugin, CustomTimelineSpec)>[];
    for (final p in forSlot(SlotIds.tl)) {
      final v = await p.value('tl.timelines', const {});
      for (final t in (v?['timelines'] as List? ?? const [])) {
        if (t is Map && t['id'] is String) out.add((p, CustomTimelineSpec(id: t['id'] as String, label: t['label'] as String? ?? t['id'] as String, base: t['base'] as String? ?? 'home')));
      }
    }
    return out;
  }

  /// `tl.params` (契約 v0.2 §2.6): ノードを設定 FOW に差し込む RRL と既定値。無ければ null。
  Future<({RrlNode root, Map<String, Object?> defaults})?> tlParams(SlotPlugin plugin, String id) async {
    final v = await plugin.value('tl.params', {'id': id});
    final root = v?['root'];
    if (root is! Map) return null;
    return (root: RrlNode.fromJson(root.cast<String, Object?>()), defaults: (v!['defaults'] as Map?)?.cast<String, Object?>() ?? const {});
  }

  /// `slot:<pluginId>:<tlId>` で引く(ノードグラフの `plugin:` ステップから)。
  /// [accountKey] = このグラフの持ち主のアカウント(その版で並べる、D-355)。省略 = いまのアカウント。
  Future<List<Post>> sortById(String slotTlId, List<Post> posts, {Map<String, Object?> params = const {}, String? accountKey}) async {
    final parts = slotTlId.startsWith('slot:') ? slotTlId.substring(5).split(':') : const <String>[];
    if (parts.length < 2) return posts;
    final plugin = active(accountKey: accountKey).where((p) => p.id == parts.first).firstOrNull;
    // チャイルドセーフ (D-307): 許していないプラグインの並べ替えは素通し。
    if (plugin == null || !ref.read(childGateProvider).pluginAllowed(plugin.id, SlotIds.tl, text: plugin.examplePieces)) return posts;
    return sort(plugin, parts.sublist(1).join(':'), posts, params: params);
  }

  Future<List<Post>> sort(SlotPlugin plugin, String id, List<Post> posts, {Map<String, Object?> params = const {}}) async {
    final v = await plugin.value('tl.sort', {'id': id, 'posts': [for (final x in posts) SnsWire.post(x)], 'params': params});
    final order = v?['order'];
    if (order is! List) return posts;
    final byId = {for (final x in posts) x.id: x};
    return [for (final i in order) if (i is String && byId.containsKey(i)) byId[i]!];
  }

  /// トレンドのサジェスト (CONTRACT §2.7)。
  /// 投稿共有 (CONTRACT §2.8、D-170): 共有 FOW のプラグイン行から選ばれた。
  /// プラグインの FOW は共有 FOW の子(インライン)。`composer.open` は [onComposerOpen] へ。
  Future<String> postShare(SlotPlugin plugin, {required Map<String, Object?> post, required Map<String, Object?> account, required String link, required void Function(String text, Uint8List? media, String? mime, String? name) onComposerOpen, String? fowOwner, int column = 0}) async {
    _setFowContext(plugin, fowOwner, column);
    final token = 'share-${DateTime.now().microsecondsSinceEpoch}';
    _composerOpen[token] = onComposerOpen;
    await plugin.value('post.share', {'token': token, 'post': post, 'account': account, 'link': link});
    return token;
  }

  /// 共有 FOW が閉じた: プラグインへ知らせ、受け口を捨てる。
  Future<void> postShareClose(SlotPlugin plugin, String token) async {
    _composerOpen.remove(token);
    await plugin.value('post.share.close', {'token': token});
  }

  /// 投稿のアクションボタン (CONTRACT §2.9、D-176): ユーザーが押した。戻りは `result.message`(トースト用)。
  /// `composer.open` は [onComposerOpen] へ(呼び出し元の投稿の面から開く)。
  /// [auto] = temp の自動実行(契約 v0.14 §2.9): タイルが作られたときに 1 回、`auto: true` を添えて呼ぶ。`message` は返さない(トーストに出さない)。
  Future<String?> postAction(SlotPlugin plugin, {required String actionId, required Map<String, Object?> post, required Map<String, Object?> account, required void Function(String text, Uint8List? media, String? mime, String? name) onComposerOpen, String? fowOwner, int column = 0, bool auto = false}) async {
    _setFowContext(plugin, fowOwner, column);
    final token = 'action-${DateTime.now().microsecondsSinceEpoch}';
    _composerOpen[token] = onComposerOpen;
    try {
      final v = await plugin.value('post.action', {'token': token, 'actionId': actionId, 'post': post, 'account': account, if (auto) 'auto': true});
      if (auto) return null;
      final r = (v?['result'] as Map?)?.cast<String, Object?>();
      return r?['message'] as String?;
    } finally {
      // composer.open は少し遅れて来ることがある(FOW のボタン経由)ので受け口は残す。上限で古いものから捨てる。
      if (_composerOpen.length > 32) _composerOpen.remove(_composerOpen.keys.first);
    }
  }

  Future<List<({String text, String? reason, SlotPlugin plugin})>> trendSuggest(List<String> recent, {String? query, int limit = 6}) async {
    final out = <({String text, String? reason, SlotPlugin plugin})>[];
    for (final p in forSlot(SlotIds.trendSuggest)) {
      final v = await p.value('trend.suggest', {'recent': recent, 'query': ?query, 'limit': limit});
      for (final s in (v?['suggestions'] as List? ?? const [])) {
        if (s is Map && s['text'] is String) out.add((text: s['text'] as String, reason: s['reason'] as String?, plugin: p));
      }
    }
    return out;
  }
}

/// アプリ直下の ScaffoldMessenger(トーストの出口)。`RasqApp` が付ける。
final rootMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>((ref) => GlobalKey<ScaffoldMessengerState>());

/// メディアエディターの 1 セッション (D-169)。
class MediaEditSession {
  const MediaEditSession({required this.plugin, required this.token, required this.genres});
  final SlotPlugin plugin;
  final String token;
  final List<MediaGenre> genres;
}

class MediaGenre {
  const MediaGenre({required this.id, required this.label, this.icon, this.actions = const []});
  final String id;
  final String label;
  final String? icon;
  final List<MediaAction> actions;
}

/// 既定のジャンル 5 種 (契約 v0.4 §2.2): id は固定、ラベル / アイコンはホストが持つ。
/// カスタムジャンルはプラグインが `label` / `icon` を付けて宣言する。
const mediaGenreDefaults = <String, ({String label, IconData icon})>{
  'tone': (label: '色調', icon: Icons.tune),
  'process': (label: '加工', icon: Icons.auto_fix_high),
  'transform': (label: '変形', icon: Icons.crop_rotate),
  'add': (label: '追加', icon: Icons.add_circle_outline),
  'draw': (label: '描画', icon: Icons.brush),
};

class MediaAction {
  const MediaAction({required this.id, required this.label, this.icon});
  final String id;
  final String label;
  final String? icon;
}
