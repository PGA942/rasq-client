import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../app/router.dart' show Routes;
import '../../shell/headers.dart';
import '../../shell/third_column.dart';
import '../../text/inline_spans.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../home/post_row.dart';
import '../plugins/sideload_trust.dart';
import '../plugins/slot_plugins.dart';
import '../store/rasqpkg.dart';
import '../store/store_providers.dart' show bundledSnsPluginIds, installedPluginsProvider;
import '../trend/example_match.dart' show pluginExamplePieces;
import 'review_import.dart';
import '../../l10n/l10n.dart';

/// WASM プラグイン試験画面 (dev)。misskey-wasm-sample(rasq-sdk-sample で
/// ビルドした .wasm)をインポートし、plugin_runtime 経由で描画する:
///
/// 1. 同梱アセット(assets/plugins/misskey_wasm_sample.wasm)または任意の
///    .wasm ファイルパスからロード → 初期 snapshot を表示
/// 2. 「TL取得」→ プラグインが `net.fetch`(ランタイム内蔵 rustls, D-023)で
///    Misskey の `notes/local-timeline` を叩き、RRL ツリーを再構築 → 再描画
/// 3. タイル上のタップは `call(fn)` としてプラグインへ戻る(結果を下部に表示)
///
/// 通常はワーカー isolate(AsyncWasmPluginController)で実行し UI を
/// ブロックしない。テストは envOverride で同期コントローラに差し替える。
///
/// 読み込んだものに与える権限は [devScreenGrantFor] (D-308): debug ビルドだけ全権限、release では
/// スロット登録と同じ [SideloadTrust](自分の鍵で署名した `.rasqpkg` = フル、ほか = 制限モード)。
///
/// 見守り中は、動かす前に保護者のプラグインの制限([ChildGate.devPreviewBlockReason])を確かめ、
/// 動かしている間に止められたら閉じる(セキュリティ確認 2026-10-09 の [12])。
class WasmPluginScreen extends ConsumerStatefulWidget {
  const WasmPluginScreen({super.key, this.wasmBytesOverride, this.envOverride, this.initialUrl});

  /// 審査中の版の仮インポート (D-436): judge の QR(`rasq://dev-import?url=…`)から開いたときの URL。入れるだけで、読み込みは押してから。
  final String? initialUrl;

  /// Tests inject the bytes / a hermetic environment (同期実行になる).
  final Uint8List? wasmBytesOverride;
  final RasqHostEnvironment? envOverride;

  @override
  ConsumerState<WasmPluginScreen> createState() => _WasmPluginScreenState();
}

/// dev 試験画面が読み込んだものに与える権限 (D-308)。マニフェストを読まずに動かす面なので、権限は語彙の全部
/// ([RasqPermissions.all])から段の表で絞る。
@immutable
class DevScreenGrant {
  const DevScreenGrant({required this.label, required this.permissions, required this.fowPermissions, required this.gpuCompute, required this.fuelPerCall, this.trust});

  /// 画面に出す段の名前(「デバッグビルド: 全権限」/「フル」/「制限」)。
  final String label;
  final Set<String> permissions;
  final Set<String> fowPermissions;
  final bool gpuCompute;

  /// null = ランタイム既定。
  final int? fuelPerCall;

  /// release で使った段(debug の全権限では null)。
  final SideloadTrust? trust;

  bool get isDebugAll => trust == null;
}

/// dev 試験画面の門 (D-308) — [debug] は `kDebugMode`(試験では両方を渡す)。
/// - debug ビルド: 明示の開発用サンドボックスとして全権限(`RasqPermissions.all`、FOW は全種類、`gpu.compute` を開ける)。
/// - release ビルド: スロット登録と同じ [trust](自分の鍵の署名 = フル / ほか = 制限モード)の表
///   ([SideloadTrust.capabilities]) で絞る。制限モードでは `network` / `storage.unsafe` / `gpu_ml` /
///   `fow.interstitial` / `fow.system` を外し、fuel は倍率を掛ける。
DevScreenGrant devScreenGrantFor({required bool debug, required SideloadTrust trust}) {
  if (debug) {
    return DevScreenGrant(label: appL10n.devGrantDebugAll, permissions: RasqPermissions.all, fowPermissions: sideloadFowKinds, gpuCompute: true, fuelPerCall: null);
  }
  final caps = trust.capabilities;
  return DevScreenGrant(
    label: trust.label,
    permissions: caps.permissions(RasqPermissions.all),
    fowPermissions: caps.fowKinds(sideloadFowKinds),
    gpuCompute: caps.gpuEnabled,
    fuelPerCall: caps.fuelPerCall(null),
    trust: trust,
  );
}

class _WasmPluginScreenState extends ConsumerState<WasmPluginScreen> {
  /// いま読み込んでいるものに与えた権限 (D-308)。
  DevScreenGrant? _grant;

  WasmPluginViewModel? _controller;
  String? _loadError;

  /// .rasqpkg を読み込んだときの説明(中身 / 開発者鍵の署名の有無)。
  String? _pkgNote;
  final _hostField = TextEditingController(text: 'misskey.io');
  final _pathField = TextEditingController();
  late final _urlField = TextEditingController(text: widget.initialUrl ?? '');
  bool _busy = false;

  /// 読み込んだ .rasqpkg の親(土台)のプラグイン (D-436)。入っていないものは「ストアで開く」。
  List<({String id, String version, bool installed})> _parents = const [];

  /// URL(judge の仮インポート用のリンク)から落として、ファイルから読むのと同じ道で読み込む (D-436)。
  Future<void> _loadFromUrl() async {
    final url = _urlField.text.trim();
    if (!isReviewImportUrl(url)) {
      setState(() => _loadError = context.l10n.devUrlInvalid);
      return;
    }
    setState(() => _busy = true);
    try {
      final path = await downloadReviewImport(url, client: ref.read(reviewImportHttpProvider), dir: ref.read(reviewImportDirProvider));
      await _loadFromPath(path);
    } catch (e) {
      if (mounted) setState(() => _loadError = context.l10n.devUrlLoadFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// FOW surface (D-064) 用に捕まえた OverlayManager(dispose 時の
  /// closeOwnedBy にも使うので context 経由にしない)。
  OverlayManager? _overlay;

  /// この画面のプラグインが開く FOW の id 前置(衝突回避 + 一括クローズ)。
  static const _fowOwner = 'wasm-sample';
  static const _fowPrefix = 'fow.wasm-sample.';

  /// 境界セッション試験 (D-074/M5d): `WasmSnsSession.timeline` の結果
  /// (Post ワイヤ → ホストモデル)。非 null の間はこれを表示する。
  List<Post>? _boundaryPosts;
  WasmSnsSession? _boundarySession;
  String? _boundaryNote; // performAction の結果表示

  /// SnsSession 契約の boundary 写像を実際に叩く: 抽象関数 `sns.timeline`
  /// → Post ワイヤ → ホストの PostRow パイプラインで描画。
  Future<void> _boundaryTimeline() async {
    final c = _controller;
    if (c == null) return;
    final host = _hostField.text.trim();
    setState(() => _busy = true);
    try {
      final session = WasmSnsSession(
        account: AccountId(kind: SnsKind.misskey, instance: host, handle: 'wasm-boundary'),
        pluginId: 'misskey-wasm-sample',
        extraArgs: {'host': host},
        invoke: (fn, args) async => switch (c) {
          AsyncWasmPluginController() => await c.invoke(fn, args),
          WasmPluginController() => c.invoke(fn, args),
          _ => <String, dynamic>{'ok': false},
        },
      );
      await session.loadActions(); // sns.actions (D-075: アクションバー宣言)
      final page = await session.timeline(TimelineKind.local);
      if (mounted) {
        setState(() {
          _boundarySession = session;
          _boundaryPosts = page.items;
          _boundaryNote = null;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = context.l10n.devBoundaryTimelineFailed('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFromAsset();
  }

  /// 直近に読み込んだ wasm(スロット登録に使う、D-167)。
  Uint8List? _lastBytes;
  String? _lastSource;

  Future<void> _loadFromAsset([String asset = 'assets/plugins/misskey_wasm_sample.wasm']) async {
    try {
      final bytes = widget.wasmBytesOverride ?? (await rootBundle.load(asset)).buffer.asUint8List();
      _lastBytes = bytes;
      _lastSource = 'asset:$asset';
      // アプリ同梱のアセットはアプリと同じ信頼 = フル (D-308)。rootBundle から読んだものだけ(試験の差し替えのバイト列は制限モード)。
      final trust = widget.wasmBytesOverride == null ? SideloadTrust.bundled : SideloadTrust.restricted;
      await _start(bytes, trust: trust, pluginId: null);
    } catch (e) {
      setState(() => _loadError = context.l10n.devAssetLoadFailed('$e'));
    }
  }

  Future<void> _loadFromPath(String raw) async {
    try {
      // 相対パスはアプリの作業ディレクトリ基準になって役に立たない (D-078):
      // `~` を展開し、相対ならホーム配下(と SDK リポジトリの定位置)も探す。
      var path = raw.trim();
      final home = Platform.environment['HOME'];
      if (home != null && (path == '~' || path.startsWith('~/'))) path = home + path.substring(1);
      var file = File(path);
      if (!file.existsSync() && !path.startsWith('/') && home != null) {
        for (final base in [home, '$home/Documents', '$home/Documents/rasq-sdk-sample']) {
          final cand = File('$base/$path');
          if (cand.existsSync()) {
            file = cand;
            break;
          }
        }
      }
      var bytes = file.readAsBytesSync();
      _lastBytes = bytes;
      _lastSource = file.path;
      String? note;
      // 見守りの関所 ([12]) に渡す中身: .rasqpkg は目次の id とマニフェスト、素の .wasm は分からない(null)。
      String? pluginId;
      List<String>? text;
      // 段 (D-306 / D-308) は展開する前の配布物と隣の .sig.json で決める(スロット登録と同じ sideloadTrustOfContainer)。
      final trust = await sideloadTrustOfContainer(file.path, bytes, ownFingerprints: ref.read(ownDevKeyFingerprintsProvider));
      // サイドロード (WF P-23): .rasqpkg は展開・検証して、root(SNS プラグインなら最初の子)を読み込む。
      // 隣に `<pkg>.sig.json`(`rasq build` の開発者鍵の署名)があれば確かめて、鍵の指紋を出す。
      if (isRasqPackage(bytes)) {
        final pkg = RasqPackage.open(bytes, decompress: ref.read(rasqpkgZstdProvider));
        final target = pkg.slotPlugins.firstOrNull ?? pkg.root;
        if (target.id != pkg.root.id) _lastSource = '${file.path}#${target.id}';
        final sigFile = File('${file.path}.sig.json');
        final signed = sigFile.existsSync() ? await verifyDevSignature(bytes, (jsonDecode(sigFile.readAsStringSync()) as Map).cast<String, Object?>()) : null;
        final l = appL10n;
        note = l.devPkgLoaded(pkg.root.id, pkg.root.version, pkg.children.length, target.id) +
            (signed != null ? l.devPkgSigned(signed) : l.devPkgUnsigned) +
            (trust.isFull ? l.devPkgSlotFull : l.devPkgSlotRestricted);
        bytes = target.wasm;
        pluginId = target.id;
        final m = target.manifest;
        text = pluginExamplePieces(name: '${m['name'] ?? target.id}', description: '${m['description'] ?? ''}', slots: [for (final x in (m['slots'] as List? ?? const [])) '$x']);
        final have = {...bundledSnsPluginIds, for (final p in ref.read(installedPluginsProvider)) p.id};
        _parents = [for (final r in pkg.requires) (id: r.id, version: r.version, installed: have.contains(r.id))];
      } else {
        _parents = const [];
      }
      await _start(bytes, trust: trust, pluginId: pluginId, text: text);
      if (mounted) setState(() => _pkgNote = note);
    } catch (e) {
      setState(() => _loadError = appL10n.devPathLoadFailed(raw, '$e'));
    }
  }

  /// いま動かしているものの中身(見守りの関所 [12] の判定に使う。止められたら閉じる)。
  ({String? id, List<String>? text})? _previewIdentity;

  Future<void> _start(Uint8List bytes, {required SideloadTrust trust, required String? pluginId, List<String>? text}) async {
    _disposeController();
    // 見守り ([12]): 保護者のプラグインの制限を、ゲストのコードを動かす前に(スロット登録を押さなくても)。
    if (ref.read(childGateProvider).devPreviewBlockReason(pluginId, text: text) case final blocked?) {
      _grant = null;
      if (mounted) setState(() => _loadError = blocked);
      return;
    }
    _previewIdentity = (id: pluginId, text: text);
    final grant = devScreenGrantFor(debug: kDebugMode, trust: trust);
    _grant = grant;
    if (widget.envOverride != null) {
      final controller = WasmPluginController(wasmBytes: bytes, env: widget.envOverride)..load();
      _wireFowSurface(controller);
      setState(() {
        _controller = controller;
        _loadError = null;
      });
      return;
    }
    // 手元の .wasm を直接読む開発用サーフェス: マニフェストが無いので宣言を引けない。ストア経由の導入
    // (slot_plugins / WasmSnsPlugin) は宣言どおりに絞られる。この画面は debug ビルド限定ではない
    // (サイドメニューの「WASMプラグイン試験 (dev)」、未ログインでも開ける)ので、門は [devScreenGrantFor] (D-308):
    // 全権限は debug ビルドだけ、release はスロット登録と同じ SideloadTrust の表で絞る(素の .wasm は制限モード)。
    final controller = AsyncWasmPluginController(wasmBytes: bytes, permissions: grant.permissions, fowPermissions: grant.fowPermissions, fuelPerCall: grant.fuelPerCall, gpuCompute: grant.gpuCompute);
    _wireFowSurface(controller);
    setState(() {
      _controller = controller;
      _loadError = null;
    });
    await controller.load();
  }

  /// プラグインの fow.open/close (D-064) を OverlayManager の実 FOW へ写す。
  void _wireFowSurface(WasmPluginViewModel controller) {
    if (controller is! WasmFowSurfaceHost) return;
    final host = controller as WasmFowSurfaceHost;
    host.onFowOpen = (req) => _openPluginFow(controller, req);
    host.onFowClose = (id, {result, reason}) => _overlay?.close('$_fowPrefix$id', result: result);
  }

  void _openPluginFow(WasmPluginViewModel controller, WasmFowRequest req) {
    if (!mounted) return;
    final manager = _overlay ??= OverlayScope.read(context);
    final spec = req.spec;
    final type = switch ('${spec['type']}') {
      'interstitial' => FowPanelType.interstitial,
      'system' => FowPanelType.system,
      _ => FowPanelType.widget,
    };
    final fowSpec = FowSpec(
      type: type,
      initialHeightFactor: (spec['initialHeightFactor'] as num?)?.toDouble() ?? 0.45,
      title: spec['title'] as String?,
      cancelText: spec['cancelText'] as String? ?? (req.onCancel != null ? appL10n.devFowClose : null),
      confirmText: spec['confirmText'] as String?,
      dockAboveFooter: true,
      // 横ドッキング (D-062): 開いた画面のカラムに揃える。
      columnIndex: fowColumnOf(context),
    );
    // placement (D-072): アプリヘッダー下付き / 実物ノードへのアンカー。
    // anchor はプラグイン自ドキュメントのノード(key または role)を
    // ジオメトリ登録簿から解決 — 見つからなければ通常ドックに縮退。
    fowSpec.attachTop = spec['attachTop'] == true;
    if (req.anchorNode != null || req.anchorRole != null) {
      final scope = req.document.scope;
      fowSpec.anchor = controller.geometry.lookup(
        nodeId: req.anchorNode == null ? null : '$scope:${req.anchorNode}',
        role: req.anchorRole,
      );
    }
    // ✕の割り込み (D-066): onCancel 指定時、キャンセルボタンは閉じずに
    // プラグインの関数を呼ぶ(プラグインが確認 FOW を出して自分で閉じる)。
    final onCancelFn = req.onCancel;
    if (onCancelFn != null) {
      fowSpec.interceptCancel = () => controller.handleEvent('${req.document.scope}:${req.id}', 'cancel', fn: onCancelFn, payload: {'id': req.id});
    }
    manager.show(RasqOverlayEntry(
      id: '$_fowPrefix${req.id}',
      layer: OverlayLayer.fow,
      alignment: Alignment.bottomCenter,
      // 親子 FOW (D-067): parentId 指定時は親 FOW entry を owner にする
      // (付く方向の追従・親の伸縮・連動クローズ)。親が閉じれば子も
      // 連動して閉じるので、プラグイン一括クローズにも連なる。
      ownerId: req.parentId != null ? '$_fowPrefix${req.parentId}' : _fowOwner,
      semanticsLabel: spec['title'] as String? ?? appL10n.devFowSemantics,
      // ピッカー同手法 (D-051): 透明バリア、余白クリックで破棄。
      barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
      fow: fowSpec,
      onClosed: (reason, result) {
        // 同一 id の再 open(中身の差し替え)はクローズ通知にしない。
        if (reason == OverlayCloseReason.replaced) return;
        (controller as WasmFowSurfaceHost).notifyFowClosed(req.id, reason: reason.name, result: result);
      },
      builder: (ctx, handle) => WasmFowView(controller: controller, request: req, rslParser: InlineSpans.parse),
    ));
  }

  /// 実登録 (D-079): 現在の Misskey アカウントのトークンで、wasm SNS
  /// プラグイン(misskey-wasm-sample)のセッションを**本物のアカウント**と
  /// して登録し、そのまま切り替える。以降アプリの TL/スレッド/アクションが
  /// sns.* 境界の上で動く(認証はホスト所有 — トークンは呼び出し毎に
  /// args.token で渡る)。アカウントキー衝突を避けるため handle に ~wasm を
  /// 付ける。戻るときはサイドバーのアカウント切り替えで元のアカウントへ。
  Future<void> _registerRealSession() async {
    final cur = (await ref.read(sessionsProvider.future)).current;
    if (!mounted) return;
    if (cur == null || cur.account.kind != SnsKind.misskey || cur.pluginId == wasmSamplePluginId) {
      setState(() => _loadError = context.l10n.devRegisterNeedsMisskey);
      return;
    }
    final acc = AccountId(kind: cur.account.kind, instance: cur.account.instance, handle: '${cur.account.handle}~wasm');
    final me = UserSummary(id: '-', account: acc, displayName: '${cur.displayName ?? cur.account.handle} (wasm境界)', avatarUrl: cur.avatarUrl); // l10n-ignore
    await ref.read(sessionsProvider.notifier).add(AuthResult(
          session: AccountSession(
            account: acc,
            pluginId: wasmSamplePluginId,
            token: cur.token,
            createdAt: DateTime.now(),
            displayName: me.displayName,
            avatarUrl: cur.avatarUrl,
          ),
          me: me,
        ));
    if (mounted) setState(() => _loadError = null);
  }

  void _disposeController() {
    _overlay?.closeOwnedBy(_fowOwner);
    final c = _controller;
    if (c is WasmPluginController) c.dispose();
    if (c is AsyncWasmPluginController) c.dispose();
    _controller = null;
    _previewIdentity = null;
    _boundaryPosts = null;
    _boundarySession = null;
    _boundaryNote = null;
  }

  /// 動かしている間に保護者が止めたら閉じる ([12])。
  void _onChildGateChanged() {
    final id = _previewIdentity;
    if (_controller == null || id == null) return;
    final blocked = ref.read(childGateProvider).devPreviewBlockReason(id.id, text: id.text);
    if (blocked == null) return;
    setState(() {
      _disposeController();
      _grant = null;
      _loadError = blocked;
    });
  }

  Future<void> _invoke(String fn, Map<String, Object?> args) async {
    final c = _controller;
    setState(() => _busy = true);
    try {
      if (c is AsyncWasmPluginController) {
        await c.invoke(fn, args);
      } else if (c is WasmPluginController) {
        c.invoke(fn, args);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _disposeController();
    _hostField.dispose();
    _pathField.dispose();
    _urlField.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ref.listen(childGateProvider, (_, _) => _onChildGateChanged());
    final controller = _controller;
    return Scaffold(
      appBar: RasqPageHeader(title: context.l10n.devTitle),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: RasqInput(controller: _hostField, hintText: context.l10n.devHostHint)),
              const SizedBox(width: RasqSpacing.sm),
              FilledButton.icon(
                onPressed: controller == null || _busy ? null : () => _invoke('timeline', {'host': _hostField.text.trim(), 'limit': 10}),
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download, size: 18),
                label: Text(context.l10n.devFetchTimeline),
              ),
              const SizedBox(width: RasqSpacing.sm),
              // 境界セッション (D-074): sns.timeline 抽象関数 → Post ワイヤ。
              OutlinedButton(
                onPressed: controller == null || _busy ? null : _boundaryTimeline,
                child: Text(context.l10n.devBoundaryTimeline),
              ),
            ]),
            const SizedBox(height: RasqSpacing.xs),
            Row(children: [
              Expanded(child: RasqInput(controller: _pathField, hintText: context.l10n.devPathHint)),
              const SizedBox(width: RasqSpacing.sm),
              OutlinedButton(
                onPressed: _busy ? null : () => _pathField.text.trim().isEmpty ? _loadFromAsset() : _loadFromPath(_pathField.text.trim()),
                child: Text(context.l10n.devLoad),
              ),
              const SizedBox(width: RasqSpacing.sm),
              // SDK の最小サンプル (D-077) も同梱 — ボタン一発で試せる。
              OutlinedButton(
                onPressed: _busy ? null : () => _loadFromAsset('assets/plugins/hello_rasq_plugin.wasm'),
                child: const Text('hello'),
              ),
              const SizedBox(width: RasqSpacing.sm),
              // 実登録 (D-079): 現在のトークンで wasm セッションを本登録。
              OutlinedButton(
                onPressed: _busy ? null : _registerRealSession,
                child: Text(context.l10n.devRegisterReal),
              ),
            ]),
            const SizedBox(height: RasqSpacing.xs),
            // 審査中の版の仮インポート (D-436): judge の期限つきのリンク(QR から開けば入っている)。
            Row(children: [
              Expanded(child: RasqInput(key: const ValueKey('wasm.url.field'), controller: _urlField, hintText: context.l10n.devUrlHint)),
              const SizedBox(width: RasqSpacing.sm),
              OutlinedButton(key: const ValueKey('wasm.url.load'), onPressed: _busy ? null : _loadFromUrl, child: Text(context.l10n.devUrlLoad)),
            ]),
            if (widget.initialUrl != null)
              Text(context.l10n.devOpenedFromLink,
                  key: const ValueKey('wasm.url.fromLink'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            for (final p in _parents)
              Row(key: ValueKey('wasm.parent.${p.id}'), children: [
                Expanded(
                  child: Text(p.installed ? context.l10n.devParentInstalled(p.id, p.version) : context.l10n.devParentMissing(p.id, p.version),
                      style: RasqTypography.caption.copyWith(color: p.installed ? scheme.onSurfaceVariant : RasqTokens.of(context).danger)),
                ),
                if (!p.installed) TextButton(key: ValueKey('wasm.parent.store.${p.id}'), onPressed: () => context.push(Routes.storePlugin(p.id)), child: Text(context.l10n.devOpenInStore)),
              ]),
            const SizedBox(height: RasqSpacing.xs),
            // 段 (D-308): この画面で読み込んだものの権限と、スロットに登録したときの段の説明。
            if (_grant != null)
              Text(
                _grant!.isDebugAll
                    ? context.l10n.devGrantDebugNote(_grant!.label, sideloadTrustHint)
                    : context.l10n.devGrantMode(switch (_grant!.trust!) { SideloadTrust.full => context.l10n.devModeFull, SideloadTrust.bundled => context.l10n.devModeBundled, SideloadTrust.restricted => context.l10n.devModeRestricted, SideloadTrust.swing => context.l10n.devModeSwing }, sideloadTrustHint),
                key: const ValueKey('wasm.dev.mode'),
                style: RasqTypography.caption.copyWith(color: _grant!.isDebugAll || _grant!.trust!.isFull ? scheme.onSurfaceVariant : RasqTokens.of(context).danger),
              ),
            const SizedBox(height: RasqSpacing.xs),
            // スロット登録 (D-167): 読み込んだ wasm をアプリの各所(AsTell / コンポーザー /
            // ビューワー / TL / トレンド)から呼べるように常駐させる。パスは端末に残る。
            Row(children: [
              OutlinedButton.icon(
                key: const ValueKey('wasm.slot.register'),
                onPressed: _busy || _lastBytes == null
                    ? null
                    : () async {
                        setState(() => _busy = true);
                        try {
                          await ref.read(slotPluginsProvider.notifier).register(_lastSource!, bytes: _lastSource!.startsWith('asset:') ? _lastBytes : null);
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                icon: const Icon(Icons.extension, size: 18),
                label: Text(context.l10n.devSlotRegister),
              ),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(child: Text(ref.watch(slotPluginsNoticeProvider) ?? context.l10n.devSlotRegistered(ref.watch(slotPluginsProvider).length), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            Text(context.l10n.devSlotModeHint(sideloadTrustHint), key: const ValueKey('wasm.slot.modeHint'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            for (final p in ref.watch(slotPluginsProvider))
              Row(children: [
                // 段 (D-308): ストアは審査済み、サイドロードは フル / 制限。
                Expanded(child: Text('${p.manifest.name} ${p.manifest.version} [${p.isReviewed ? context.l10n.devSlotReviewed : p.sideloadTrust.label}] — ${p.manifest.slots.join(', ')}', style: RasqTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                TextButton(onPressed: () => ref.read(slotPluginsProvider.notifier).unregister(p.id), child: Text(context.l10n.devSlotUnregister)),
              ]),
            if (_loadError != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_loadError!, style: RasqTypography.caption.copyWith(color: RasqTokens.of(context).danger))),
            if (_pkgNote != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_pkgNote!, style: RasqTypography.caption)),
            if (controller?.lastResult != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('result: ${controller!.lastResult}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ]),
        ),
        const Divider(),
        Expanded(
          child: _boundaryPosts != null
              // 境界セッション試験 (D-074): Post ワイヤをホストの通常
              // パイプライン(PostRow)で描画 = 契約写像の実証。
              ? ListView(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: 4),
                    color: scheme.surfaceContainerHighest,
                    child: Row(children: [
                      Expanded(child: Text(context.l10n.devBoundaryHeader, style: RasqTypography.caption)),
                      TextButton(onPressed: () => setState(() => _boundaryPosts = null), child: Text(context.l10n.devBoundaryClose)),
                    ]),
                  ),
                  if (_boundaryNote != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: 4),
                      child: Text(_boundaryNote!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                    ),
                  for (final p in _boundaryPosts!) ...[
                    // アクションは sns.performAction へ (D-075: 短押しの中身は
                    // プラグインが決める。トークン無しの実サーバーではエラー表示)。
                    PostRow(
                      post: p,
                      actions: _boundarySession?.actions ?? const [],
                      onAction: (a, {args = const {}}) async {
                        try {
                          final r = await _boundarySession!.performAction(a.id, p.id, args: args);
                          if (mounted) setState(() => _boundaryNote = 'performAction(${a.id}, ${p.id}) → done=${r.done}');
                        } catch (e) {
                          if (mounted) setState(() => _boundaryNote = context.l10n.devActionFailed(a.id, '$e'));
                        }
                      },
                    ),
                    const Divider(),
                  ],
                ])
              : controller == null
                  ? (_loadError != null && _grant == null ? const SizedBox.shrink() : const RasqLoading())
                  : SingleChildScrollView(
                      child: WasmPluginView(controller: controller, rslParser: InlineSpans.parse),
                    ),
        ),
      ]),
    );
  }
}
