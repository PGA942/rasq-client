import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../../shell/third_column.dart';
import '../../text/inline_spans.dart';
import '../home/post_row.dart';
import '../plugins/sideload_trust.dart';
import '../plugins/slot_plugins.dart';
import '../store/rasqpkg.dart';

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
class WasmPluginScreen extends ConsumerStatefulWidget {
  const WasmPluginScreen({super.key, this.wasmBytesOverride, this.envOverride});

  /// Tests inject the bytes / a hermetic environment (同期実行になる).
  final Uint8List? wasmBytesOverride;
  final RasqHostEnvironment? envOverride;

  @override
  ConsumerState<WasmPluginScreen> createState() => _WasmPluginScreenState();
}

class _WasmPluginScreenState extends ConsumerState<WasmPluginScreen> {
  WasmPluginViewModel? _controller;
  String? _loadError;

  /// .rasqpkg を読み込んだときの説明(中身 / 開発者鍵の署名の有無)。
  String? _pkgNote;
  final _hostField = TextEditingController(text: 'misskey.io');
  final _pathField = TextEditingController();
  bool _busy = false;

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
      if (mounted) setState(() => _loadError = '境界TL: $e');
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
      await _start(bytes);
    } catch (e) {
      setState(() => _loadError = 'アセットの読み込みに失敗: $e');
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
      // サイドロード (WF P-23): .rasqpkg は展開・検証して、root(SNS プラグインなら最初の子)を読み込む。
      // 隣に `<pkg>.sig.json`(`rasq build` の開発者鍵の署名)があれば確かめて、鍵の指紋を出す。
      if (isRasqPackage(bytes)) {
        final pkg = RasqPackage.open(bytes, decompress: ref.read(rasqpkgZstdProvider));
        final target = pkg.slotPlugins.firstOrNull ?? pkg.root;
        if (target.id != pkg.root.id) _lastSource = '${file.path}#${target.id}';
        final sigFile = File('${file.path}.sig.json');
        final signed = sigFile.existsSync() ? await verifyDevSignature(bytes, (jsonDecode(sigFile.readAsStringSync()) as Map).cast<String, Object?>()) : null;
        // スロットに登録したときの段 (D-306): 自分の開発者鍵の署名ならフル機能、ほかは制限モード(GPU は閉)。
        final own = signed != null && ref.read(ownDevKeyFingerprintsProvider).contains(signed);
        note = '.rasqpkg: ${pkg.root.id} ${pkg.root.version}(子 ${pkg.children.length})→ ${target.id} を読み込み。'
            '${signed != null ? '開発者鍵の署名 OK(指紋 $signed)。ストアの審査は通っていません' : '署名なし(.sig.json がありません)。出どころを確かめられません'}。'
            'スロットに登録すると${own ? 'フル機能(自分の鍵の署名)' : '制限モード(自分の鍵の署名ではないため GPU は閉)'}';
        bytes = target.wasm;
      }
      await _start(bytes);
      if (mounted) setState(() => _pkgNote = note);
    } catch (e) {
      setState(() => _loadError = '$raw の読み込みに失敗(絶対パスか ~/ 始まりで指定してください): $e');
    }
  }

  Future<void> _start(Uint8List bytes) async {
    _disposeController();
    if (widget.envOverride != null) {
      final controller = WasmPluginController(wasmBytes: bytes, env: widget.envOverride)..load();
      _wireFowSurface(controller);
      setState(() {
        _controller = controller;
        _loadError = null;
      });
      return;
    }
    // 手元の .wasm を直接読む開発用サーフェス: マニフェストが無いので
    // 宣言を引けない。ストア経由の導入 (slot_plugins / WasmSnsPlugin) は
    // 宣言どおりに絞られる。gpu.compute (D-081) も、`network` と同じくこの画面では開ける
    // (手元で読み込んだこと自体が付与。RasqPermissions.all に gpu_ml が入っている)。
    // 注意: この画面は debug ビルド限定ではない(サイドメニューの「WASMプラグイン試験 (dev)」、未ログインでも開ける)。
    // 「スロットに登録」したもの (slot_plugins) は D-306 の SideloadTrust に従い、自分の署名が無ければ制限モード(GPU 閉)。
    // TODO(制限モード): この試験画面そのものの門(debug 限定にする / 同じ SideloadTrust に揃える)は制限モードの残りと一緒に決める。
    final controller = AsyncWasmPluginController(wasmBytes: bytes, permissions: RasqPermissions.all, gpuCompute: true);
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
      cancelText: spec['cancelText'] as String? ?? (req.onCancel != null ? '閉じる' : null),
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
      semanticsLabel: spec['title'] as String? ?? 'プラグインFOW',
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
      setState(() => _loadError = '実登録には Misskey アカウントでのログインが必要です');
      return;
    }
    final acc = AccountId(kind: cur.account.kind, instance: cur.account.instance, handle: '${cur.account.handle}~wasm');
    final me = UserSummary(id: '-', account: acc, displayName: '${cur.displayName ?? cur.account.handle} (wasm境界)', avatarUrl: cur.avatarUrl);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controller = _controller;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'WASMプラグイン試験 (dev)'),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: RasqInput(controller: _hostField, hintText: 'インスタンス (例: misskey.io)')),
              const SizedBox(width: RasqSpacing.sm),
              FilledButton.icon(
                onPressed: controller == null || _busy ? null : () => _invoke('timeline', {'host': _hostField.text.trim(), 'limit': 10}),
                icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download, size: 18),
                label: const Text('TL取得'),
              ),
              const SizedBox(width: RasqSpacing.sm),
              // 境界セッション (D-074): sns.timeline 抽象関数 → Post ワイヤ。
              OutlinedButton(
                onPressed: controller == null || _busy ? null : _boundaryTimeline,
                child: const Text('境界TL'),
              ),
            ]),
            const SizedBox(height: RasqSpacing.xs),
            Row(children: [
              Expanded(child: RasqInput(controller: _pathField, hintText: '.wasm のパスからインポート (空欄=同梱アセット)')),
              const SizedBox(width: RasqSpacing.sm),
              OutlinedButton(
                onPressed: _busy ? null : () => _pathField.text.trim().isEmpty ? _loadFromAsset() : _loadFromPath(_pathField.text.trim()),
                child: const Text('読み込み'),
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
                child: const Text('実登録'),
              ),
            ]),
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
                label: const Text('スロットに登録'),
              ),
              const SizedBox(width: RasqSpacing.sm),
              Expanded(child: Text(ref.watch(slotPluginsNoticeProvider) ?? '登録済み: ${ref.watch(slotPluginsProvider).length}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
            for (final p in ref.watch(slotPluginsProvider))
              Row(children: [
                Expanded(child: Text('${p.manifest.name} ${p.manifest.version} — ${p.manifest.slots.join(', ')}', style: RasqTypography.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                TextButton(onPressed: () => ref.read(slotPluginsProvider.notifier).unregister(p.id), child: const Text('解除')),
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
                      Expanded(child: Text('境界セッション: sns.timeline → Post ワイヤ → PostRow', style: RasqTypography.caption)),
                      TextButton(onPressed: () => setState(() => _boundaryPosts = null), child: const Text('閉じる')),
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
                          if (mounted) setState(() => _boundaryNote = 'performAction(${a.id}) 失敗: $e');
                        }
                      },
                    ),
                    const Divider(),
                  ],
                ])
              : controller == null
                  ? const RasqLoading()
                  : SingleChildScrollView(
                      child: WasmPluginView(controller: controller, rslParser: InlineSpans.parse),
                    ),
        ),
      ]),
    );
  }
}
