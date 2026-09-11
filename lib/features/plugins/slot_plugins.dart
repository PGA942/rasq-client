import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
import '../settings/settings_dsl.dart';
import '../store/store_providers.dart';
import '../vc/astell_models.dart';
import '../vc/astell_providers.dart';

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
  const SlotManifest({required this.id, required this.name, this.version = '0.0.0', this.kind = 'action', this.description = '', this.slots = const [], this.permissions = const []});
  final String id;
  final String name;
  final String version;
  final String kind;
  final String description;
  final List<String> slots;
  final List<String> permissions;

  factory SlotManifest.fromJson(Map<String, Object?> j) => SlotManifest(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? j['id'] as String? ?? '',
        version: j['version'] as String? ?? '0.0.0',
        kind: j['kind'] as String? ?? 'action',
        description: j['description'] as String? ?? '',
        slots: [for (final s in (j['slots'] as List? ?? const [])) if (s is String) s],
        permissions: [for (final s in (j['permissions'] as List? ?? const [])) if (s is String) s],
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
        if (slots.contains(SlotIds.composerText)) RasqHostFns.composerTextReplace,
        if (slots.contains(SlotIds.viewerOverlay)) RasqHostFns.viewerOverlaySet,
      };

  Set<String> get fowPermissions => {
        'widget',
        if (permissions.contains('fow.interstitial')) 'interstitial',
        if (permissions.contains('fow.system')) 'system',
      };
}

abstract final class SlotIds {
  static const astellAction = 'astell.action';
  static const composerMedia = 'composer.media';
  static const composerText = 'composer.text';
  static const viewerOverlay = 'viewer.overlay';
  static const postTransform = 'post.transform';
  static const tl = 'tl';
  static const trendSuggest = 'trend.suggest';
}

/// 実行中のプラグイン 1 つ(ワーカー isolate 上の wasm、テストでは偽物)。
abstract class SlotRuntime {
  /// 描画/FOW 用のビュー(`WasmFowSurfaceHost` を実装していること)。
  WasmPluginViewModel get view;
  Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> args);
  set onAppFn(AppFnRelay? relay);
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
  void dispose() => controller.dispose();
}

/// wasm バイト列 → 実行中のプラグイン。テストは偽物に差し替える。
typedef SlotRuntimeLoader = Future<SlotRuntime> Function(Uint8List bytes, {required String source, required Set<String> fowPermissions, required Set<String> appFns});

final slotRuntimeLoaderProvider = Provider<SlotRuntimeLoader>((ref) => (bytes, {required source, required fowPermissions, required appFns}) async {
      final c = AsyncWasmPluginController(wasmBytes: bytes, fowPermissions: fowPermissions, appFns: appFns);
      await c.load();
      if (c.lastError != null && c.document == null) {
        c.dispose();
        throw StateError(c.lastError!);
      }
      return _AsyncSlotRuntime(c);
    });

@immutable
class SlotPlugin {
  const SlotPlugin({required this.manifest, required this.source, required this.runtime});
  final SlotManifest manifest;

  /// 読み込み元(ファイルパス、または `asset:<name>`)。
  final String source;
  final SlotRuntime runtime;

  String get id => manifest.id;
  bool has(String slot) => manifest.slots.contains(slot);
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

/// スロット別。
final slotPluginsForProvider = Provider.family<List<SlotPlugin>, String>((ref, slot) => [for (final p in ref.watch(slotPluginsProvider)) if (p.has(slot)) p]);

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
  final Map<String, void Function(Uint8List bytes, String mime)> _mediaPreview = {};

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
    if (!_restored) {
      _restored = true;
      Future.microtask(_restore);
    }
    return const [];
  }

  Future<void> _restore() async {
    try {
      final raw = await ref.read(sessionStorageProvider).read(slotPluginsStorageKey);
      if (raw == null) return;
      for (final p in (jsonDecode(raw) as List)) {
        if (p is! String) continue;
        // ストアからのインストール (D-168): 配布物を取り直す(モックは同梱アセット)。
        if (p.startsWith('store:')) {
          try {
            final bytes = await ref.read(storeClientProvider).downloadArtifact(p.substring(6), 'bundle');
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
  Future<SlotPlugin?> register(String source, {Uint8List? bytes, bool persist = true}) async {
    try {
      final data = bytes ?? File(source).readAsBytesSync();
      final loader = ref.read(slotRuntimeLoaderProvider);
      // マニフェストを読むために一度素の権限で起動し、宣言に合わせて起動し直す。
      var runtime = await loader(data, source: source, fowPermissions: const {'widget'}, appFns: const {});
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
      runtime.dispose();
      runtime = await loader(data, source: source, fowPermissions: manifest.fowPermissions, appFns: manifest.appFns);
      if (_disposed) {
        runtime.dispose(); // 読み込み中にプロバイダーが捨てられた(テストの再構築など)
        return null;
      }
      final plugin = SlotPlugin(manifest: manifest, source: source, runtime: runtime);
      runtime.onAppFn = (fn, args) => _onAppFn(plugin, fn, args);
      _wireFow(plugin);
      // 同じ id は差し替え。
      for (final old in state.where((p) => p.id == manifest.id)) {
        old.runtime.dispose();
      }
      _set([for (final p in state) if (p.id != manifest.id) p, plugin]);
      if (persist) await _persist();
      ref.read(slotPluginsNoticeProvider.notifier).set('${manifest.name} を登録しました(${manifest.slots.join(', ')})');
      return plugin;
    } catch (e) {
      if (!_disposed) ref.read(slotPluginsNoticeProvider.notifier).set('登録できませんでした: $e');
      return null;
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

  List<SlotPlugin> forSlot(String slot) => [for (final p in state) if (p.has(slot)) p];

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
    switch (fn) {
      case RasqHostFns.toast:
        _toast('${plugin.manifest.name}: ${args['message'] ?? ''}');
      case RasqHostFns.soundPlay:
        SystemSound.play(args['kind'] == 'alert' ? SystemSoundType.alert : SystemSoundType.click);
      case RasqHostFns.clipboardSet:
        Clipboard.setData(ClipboardData(text: '${args['text'] ?? ''}'));
      case RasqHostFns.urlOpen:
        final u = Uri.tryParse('${args['url']}');
        if (u != null) launchUrl(u, mode: LaunchMode.externalApplication);
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
            cb(base64Decode(b64), '${args['mimeType'] ?? 'image/png'}');
          } catch (e) {
            debugPrint('media preview: $e');
          }
        }
      case RasqHostFns.composerTextReplace:
        final cb = _textReplace['${args['token']}'];
        if (cb != null) cb((args['start'] as num?)?.toInt() ?? 0, (args['end'] as num?)?.toInt() ?? 0, '${args['text'] ?? ''}');
      case RasqHostFns.viewerOverlaySet:
        final cb = _overlaySet['${args['token']}'];
        final root = args['root'];
        if (cb != null && root is Map) cb(RrlNode.fromJson(root.cast<String, Object?>()));
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
  Future<void> astellOpen(SlotPlugin plugin, AstellSessionState s, {String? fowOwner, int column = 0}) async {
    _setFowContext(plugin, fowOwner, column);
    final token = 'astell-${DateTime.now().microsecondsSinceEpoch}';
    _astellTokens[plugin.id] = token;
    _seenShares = {for (final x in s.shares) x.id};
    _seenPeers = {for (final x in s.peers) x.peerId};
    await plugin.value('astell.open', {
      'token': token,
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
      for (final p in state) {
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

  /// コンポーザーの添付 (CONTRACT §2.2)。戻りは即時差し替え(あれば)。
  Future<void> mediaEdit(SlotPlugin plugin, {required int index, required String name, required String mimeType, required Uint8List bytes, required void Function(Uint8List bytes, String mime, String? name) onReplace, String? fowOwner, int column = 0}) async {
    _setFowContext(plugin, fowOwner, column);
    final token = 'media-${DateTime.now().microsecondsSinceEpoch}';
    _mediaReplace[token] = onReplace;
    final v = await plugin.value('media.edit', {'token': token, 'index': index, 'name': name, 'mimeType': mimeType, 'bytesB64': base64Encode(bytes)});
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
  Future<MediaEditSession?> mediaEditorOpen(SlotPlugin plugin, {required String name, required String mimeType, required Uint8List bytes, required void Function(Uint8List bytes, String mime) onPreview, required void Function(Uint8List bytes, String mime, String? name) onReplace, String? fowOwner, int column = 0}) async {
    _setFowContext(plugin, fowOwner, column, barrierless: true);
    final token = 'media-${DateTime.now().microsecondsSinceEpoch}';
    _mediaPreview[token] = onPreview;
    _mediaReplace[token] = onReplace;
    final v = await plugin.value('media.edit', {'token': token, 'index': 0, 'name': name, 'mimeType': mimeType, 'bytesB64': base64Encode(bytes)});
    if (v == null) {
      _mediaPreview.remove(token);
      _mediaReplace.remove(token);
      return null;
    }
    if (v['bytesB64'] is String) {
      try {
        onReplace(base64Decode(v['bytesB64'] as String), '${v['mimeType'] ?? mimeType}', v['name'] as String?);
      } catch (_) {}
      return null;
    }
    final genres = <MediaGenre>[];
    for (final g in (v['genres'] as List? ?? const [])) {
      if (g is! Map || g['id'] is! String) continue;
      genres.add(MediaGenre(
        id: g['id'] as String,
        label: g['label'] as String? ?? g['id'] as String,
        icon: g['icon'] as String?,
        actions: [
          for (final a in (g['actions'] as List? ?? const []))
            if (a is Map && a['id'] is String) MediaAction(id: a['id'] as String, label: a['label'] as String? ?? a['id'] as String, icon: a['icon'] as String?),
        ],
      ));
    }
    return MediaEditSession(plugin: plugin, token: token, genres: genres);
  }

  Future<void> mediaAction(MediaEditSession s, String genre, String action) => s.plugin.value('media.action', {'token': s.token, 'genre': genre, 'action': action});

  /// 適用: 本サイズの結果(戻り)か、`composer.media.replace` 経由。
  Future<(Uint8List, String, String?)?> mediaCommit(MediaEditSession s) async {
    final overlay = ref.read(overlayManagerProvider);
    final v = await s.plugin.value('media.commit', {'token': s.token});
    _mediaPreview.remove(s.token);
    _mediaReplace.remove(s.token);
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

  /// メディア全画面 (CONTRACT §2.4)。戻りは重ねる RRL(無ければ null)。
  Future<RrlNode?> viewerOpen(SlotPlugin plugin, {required String token, required String url, required String mimeType, required int width, required int height, Uint8List? bytes, required void Function(RrlNode root) onOverlay}) async {
    _overlaySet[token] = onOverlay;
    final v = await plugin.value('viewer.open', {'token': token, 'url': url, 'mimeType': mimeType, 'width': width, 'height': height, if (bytes != null) 'bytesB64': base64Encode(bytes)});
    final root = v?['root'];
    return root is Map ? RrlNode.fromJson(root.cast<String, Object?>()) : null;
  }

  void viewerClose(SlotPlugin plugin, String token) {
    _overlaySet.remove(token);
    plugin.value('viewer.close', {'token': token});
  }

  /// 投稿加工 (CONTRACT §2.5): 登録済みプラグインを順に通す。
  Future<List<Post>> transform(List<Post> posts) async {
    var out = posts;
    for (final p in forSlot(SlotIds.postTransform)) {
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
  Future<List<Post>> sortById(String slotTlId, List<Post> posts, {Map<String, Object?> params = const {}}) async {
    final parts = slotTlId.startsWith('slot:') ? slotTlId.substring(5).split(':') : const <String>[];
    if (parts.length < 2) return posts;
    final plugin = state.where((p) => p.id == parts.first).firstOrNull;
    if (plugin == null) return posts;
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
  Future<List<({String text, String? reason, SlotPlugin plugin})>> trendSuggest(List<String> recent, {String? query, int limit = 6}) async {
    final out = <({String text, String? reason, SlotPlugin plugin})>[];
    for (final p in forSlot(SlotIds.trendSuggest)) {
      final v = await p.value('trend.suggest', {'recent': recent, if (query != null) 'query': query, 'limit': limit});
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

class MediaAction {
  const MediaAction({required this.id, required this.label, this.icon});
  final String id;
  final String label;
  final String? icon;
}
