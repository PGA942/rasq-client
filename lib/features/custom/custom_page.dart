import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/rasq_account.dart';
import '../../backend/redact.dart';
import '../../shell/headers.dart';
import '../plugins/slot_plugins.dart';
import '../store/rasqpkg.dart';
import '../store/store_models.dart';
import '../store/store_providers.dart';
import 'custom_client.dart';
import 'custom_models.dart';

/// カスタムプラグイン(ページ型、契約 v0.18 §2.13、D-357)を開く引数。ルート `/custom/<pluginId>?surface=&session=&room=&profile=`。
@immutable
class CustomPageArgs {
  const CustomPageArgs({required this.pluginId, this.version, this.surface = PluginPageDecl.surfacePage, this.sessionId, this.roomId, this.profileHandle, this.profileAccountId});
  final String pluginId;
  final String? version;
  final String surface;
  final String? sessionId;
  final String? roomId;
  final String? profileHandle;
  final String? profileAccountId;

  Map<String, String> get query => {
        'version': ?version,
        if (surface != PluginPageDecl.surfacePage) 'surface': surface,
        'session': ?sessionId,
        'room': ?roomId,
        'profile': ?profileHandle,
        'profileId': ?profileAccountId,
      };

  factory CustomPageArgs.fromState(String pluginId, Map<String, String> q) => CustomPageArgs(
        pluginId: pluginId,
        version: q['version'],
        surface: q['surface'] ?? PluginPageDecl.surfacePage,
        sessionId: q['session'],
        roomId: q['room'],
        profileHandle: q['profile'],
        profileAccountId: q['profileId'],
      );

  CustomPageArgs withSession(String id) => CustomPageArgs(pluginId: pluginId, version: version, surface: surface, sessionId: id, roomId: roomId, profileHandle: profileHandle, profileAccountId: profileAccountId);
}

enum CustomPagePhase { resolving, needsConsent, needsInstall, loading, ready, failed }

/// 端末に登録済みのページ型プラグイン(ストアから入れた / サイドロード)。[version] があればその版を優先。
SlotPlugin? registeredPagePlugin(List<SlotPlugin> all, String pluginId, {String? version}) {
  final mine = [for (final p in all) if (p.has(SlotIds.page) && (p.id == pluginId || p.storePluginId == pluginId)) p];
  if (mine.isEmpty) return null;
  return mine.where((p) => version != null && p.storeVersion == version).firstOrNull ?? mine.last;
}

/// 開いているページ 1 つ: プラグインを用意し(登録済み、なければ同意のうえ一時的に)、共有セッションがあれば WS に入り、
/// `page.open` → 描画。`page.render` / `shared.*` を受け、サーバーの変化を `page.event` で渡す。
class CustomPageController extends ChangeNotifier implements PluginPageSink {
  CustomPageController(this.container, this.args, {this.size = const Size(400, 700)});
  final ProviderContainer container;
  final CustomPageArgs args;
  Size size;

  CustomPagePhase phase = CustomPagePhase.resolving;
  String? error;
  RrlNode? root;
  String? title;
  SlotPlugin? plugin;
  bool temporary = false;
  StorePluginDetail? detail;

  CustomSession? session;
  final vars = <String, CustomVar>{};
  final participants = <CustomParticipant>[];
  CustomParticipant? me;

  /// サーバーが決めた役割(welcome の `me.role`。ルームのオーナー / モデレーターも owner、S-048)。
  String? role;

  /// セッションが閉じられた(ページは最後の表示のまま)。
  String? closedReason;

  /// サーバーの断り(一時的な案内)。
  String? notice;

  CustomConnection? _conn;
  StreamSubscription<Map<String, Object?>>? _sub;
  late final String token = 'page-${args.pluginId}-${DateTime.now().microsecondsSinceEpoch}';
  bool _disposed = false;

  SlotPluginsNotifier get _slots => container.read(slotPluginsProvider.notifier);
  PluginPageDecl? get decl => plugin?.manifest.page;

  @override
  bool get hasSession => session != null && closedReason == null && _conn != null;

  void _set(void Function() f) {
    if (_disposed) return;
    f();
    notifyListeners();
  }

  Future<void> start() async {
    var p = registeredPagePlugin(container.read(slotPluginsProvider), args.pluginId, version: args.version);
    // インストール済みなのに起動直後でまだ登録が済んでいない。少し待つ。
    if (p == null && container.read(installedPluginsProvider).any((x) => x.id == args.pluginId)) {
      for (var i = 0; i < 30 && p == null && !_disposed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        p = registeredPagePlugin(container.read(slotPluginsProvider), args.pluginId, version: args.version);
      }
    }
    if (_disposed) return;
    if (p != null) {
      plugin = p;
      return _open();
    }
    try {
      detail = await container.read(storeClientProvider).plugin(args.pluginId);
    } catch (_) {}
    // 共有セッションの参加者はインストールせずに使える(同意のうえ一時的に)。それ以外はインストールしてから。
    _set(() => phase = args.sessionId != null ? CustomPagePhase.needsConsent : CustomPagePhase.needsInstall);
  }

  /// 同意 → ストアから(セッション経由で)取り、登録簿に入れずに動かす。
  Future<void> acceptTemporary() async {
    final sessionId = args.sessionId;
    if (sessionId == null) return;
    _set(() => phase = CustomPagePhase.loading);
    try {
      final bytes = await container.read(storeClientProvider).sessionPackage(args.pluginId, sessionId, version: args.version);
      final p = await _slots.register(storeSlotSource(args.pluginId, args.version ?? detail?.version ?? '0.0.0'), bytes: bytes, persist: false, temporary: true);
      if (p == null) throw StateError(container.read(slotPluginsNoticeProvider) ?? '読み込めませんでした');
      if (!p.has(SlotIds.page)) {
        _slots.disposeTemporary(p);
        throw StateError('${p.manifest.name} はページ型のプラグインではありません');
      }
      plugin = p;
      temporary = true;
      await _open();
    } catch (e) {
      _set(() {
        phase = CustomPagePhase.failed;
        error = '$e';
      });
    }
  }

  Future<void> _open() async {
    final p = plugin!;
    _set(() => phase = CustomPagePhase.loading);
    final account = container.read(orgateAccountProvider).value;
    me = account == null ? const CustomParticipant(accountId: 'me', handle: 'me', displayName: 'あなた') : CustomParticipant(accountId: account.id, handle: account.handle, displayName: account.displayName);
    final sessionId = args.sessionId;
    if (sessionId != null) {
      if (p.manifest.page?.isShared != true) {
        _set(() {
          phase = CustomPagePhase.failed;
          error = '${p.manifest.name} は 1 人で使うプラグインです(共有セッションには入れません)';
        });
        return;
      }
      try {
        await _join(sessionId);
      } catch (e) {
        _set(() {
          phase = CustomPagePhase.failed;
          error = 'セッションに入れませんでした: ${redactSecrets('$e')}';
        });
        return;
      }
    }
    final r = await _slots.pageOpen(p, token: token, sink: this, args: {
      'surface': args.surface,
      'context': {'roomId': ?args.roomId, 'profileHandle': ?args.profileHandle, 'profileAccountId': ?args.profileAccountId},
      'me': me!.toJson(),
      if (session != null) 'session': _sessionJson(),
      'size': {'width': size.width.round(), 'height': size.height.round()},
    });
    _set(() {
      if (r.error != null || r.root == null) {
        phase = CustomPagePhase.failed;
        error = r.error ?? 'ページが返ってきませんでした(page.open の root)';
      } else {
        phase = CustomPagePhase.ready;
        root = r.root;
        title = r.title;
      }
    });
  }

  Map<String, Object?> _sessionJson() => {
        'id': session!.id,
        'scope': session!.scope,
        'role': role ?? (session!.ownerAccountId != null && session!.ownerAccountId == me?.accountId ? 'owner' : 'member'),
        'participants': [for (final x in participants) x.toJson()],
        'vars': {for (final e in vars.entries) e.key: e.value.toJson()},
      };

  Future<void> _join(String sessionId) async {
    final client = container.read(customSessionClientProvider);
    final conn = await client.connect(sessionId);
    _conn = conn;
    final welcome = Completer<void>();
    _sub = conn.messages.listen((m) {
      if (m['type'] == 'welcome') {
        final s = m['session'];
        if (s is Map) session = CustomSession.fromJson(s.cast<String, Object?>());
        if (m['me'] is Map) {
          me = CustomParticipant.fromJson((m['me'] as Map).cast<String, Object?>());
          role = (m['me'] as Map)['role'] as String?;
        }
        participants
          ..clear()
          ..addAll([for (final x in (m['participants'] as List? ?? const [])) if (x is Map) CustomParticipant.fromJson(x.cast<String, Object?>())]);
        vars
          ..clear()
          ..addAll({for (final e in ((m['vars'] as Map?) ?? const {}).entries) '${e.key}': CustomVar.fromJson((e.value as Map).cast<String, Object?>())});
        if (!welcome.isCompleted) welcome.complete();
        notifyListeners();
        return;
      }
      _onMessage(m);
    }, onError: (Object e) {
      if (!welcome.isCompleted) welcome.completeError(e);
      _set(() => notice = '接続が切れました: ${redactSecrets('$e')}');
    }, onDone: () {
      if (!welcome.isCompleted) welcome.completeError(StateError('接続が切れました'));
      if (closedReason == null) _set(() => notice = '接続が切れました');
    });
    await welcome.future.timeout(const Duration(seconds: 10));
  }

  void _event(Map<String, Object?> e) {
    final p = plugin;
    if (p != null && phase == CustomPagePhase.ready) _slots.pageEvent(p, token, e);
  }

  void _onMessage(Map<String, Object?> m) {
    switch (m['type']) {
      case 'var':
        final key = '${m['key']}';
        final rev = (m['rev'] as num?)?.toInt() ?? 0;
        if (m['value'] == null) {
          vars.remove(key);
        } else {
          vars[key] = CustomVar(value: m['value'], rev: rev, by: m['by'] as String?);
        }
        _event({'type': 'var', 'key': key, 'value': m['value'], 'rev': rev, 'by': m['by']});
      case 'call':
        _event({'type': 'call', 'fn': m['fn'], 'args': m['args'], 'from': m['from']});
      case 'joined':
        final x = m['participant'];
        if (x is Map) {
          final who = CustomParticipant.fromJson(x.cast<String, Object?>());
          participants
            ..removeWhere((e) => e.accountId == who.accountId)
            ..add(who);
          _event({'type': 'joined', 'participant': who.toJson()});
        }
      case 'left':
        participants.removeWhere((e) => e.accountId == m['accountId']);
        _event({'type': 'left', 'accountId': m['accountId']});
      case 'conflict':
        final key = '${m['key']}';
        final rev = (m['rev'] as num?)?.toInt() ?? 0;
        if (m['value'] != null) vars[key] = CustomVar(value: m['value'], rev: rev);
        _event({'type': 'conflict', 'key': key, 'value': m['value'], 'rev': rev});
      case 'closed':
        closedReason = '${m['reason'] ?? 'closed'}';
        _event({'type': 'closed', 'reason': closedReason});
      case 'error':
        notice = '${m['message'] ?? 'エラー'}';
      default:
        return;
    }
    notifyListeners();
  }

  // ── PluginPageSink ──

  @override
  void render(RrlNode root, String? title) => _set(() {
        this.root = root;
        if (title != null) this.title = title;
      });

  @override
  void shared(String fn, Map<String, Object?> a) {
    final conn = _conn;
    if (conn == null) return;
    switch (fn) {
      case 'shared.set':
        conn.send({'type': 'set', 'key': a['key'], 'value': a['value'], if (a['ifRev'] is num) 'ifRev': a['ifRev']});
      case 'shared.op':
        conn.send({'type': 'op', 'key': a['key'], 'op': a['op'], 'value': a['value']});
      case 'shared.call':
        conn.send({'type': 'call', 'fn': a['fn'], 'args': a['args']});
    }
  }

  /// RRL のイベント → プラグインの関数(`{token, nodeId, kind, ...payload}`)。
  void onRrlEvent(String nodeId, String kind, {String? fn, Map<String, Object?> payload = const {}}) {
    final p = plugin;
    if (p == null || fn == null) return;
    p.value(fn, {'token': token, 'nodeId': nodeId, 'kind': kind, ...payload});
  }

  void resized(Size next) {
    if ((next.width - size.width).abs() < 1 && (next.height - size.height).abs() < 1) return;
    size = next;
    _event({'type': 'resized', 'size': {'width': next.width.round(), 'height': next.height.round()}});
  }

  void dismissNotice() => _set(() => notice = null);

  @override
  void dispose() {
    _disposed = true;
    final p = plugin;
    if (p != null) {
      _slots.pageClose(p, token);
      if (temporary) _slots.disposeTemporary(p);
    }
    _sub?.cancel();
    _conn?.close();
    super.dispose();
  }
}

/// カスタムプラグインのページ (D-357)。ヘッダー(名前・参加者・…)と戻るはホスト、中身はプラグインの RRL。
class CustomPageScreen extends ConsumerStatefulWidget {
  const CustomPageScreen({super.key, required this.args});
  final CustomPageArgs args;

  @override
  ConsumerState<CustomPageScreen> createState() => _CustomPageScreenState();
}

class _CustomPageScreenState extends ConsumerState<CustomPageScreen> {
  CustomPageController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final size = MediaQuery.sizeOf(context);
    _c = CustomPageController(ProviderScope.containerOf(context), widget.args, size: size)..addListener(_changed);
    unawaited(_c!.start());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_changed);
    _c?.dispose();
    super.dispose();
  }

  Future<void> _menu(BuildContext anchorCtx) async {
    final c = _c!;
    final s = c.session;
    final d = c.decl;
    final box = anchorCtx.findRenderObject() as RenderBox?;
    final anchor = box == null ? const Rect.fromLTWH(0, 0, 1, 1) : box.localToGlobal(Offset.zero) & box.size;
    final isOwner = s != null && (c.role == 'owner' || (s.ownerAccountId != null && s.ownerAccountId == c.me?.accountId));
    final pick = await ref.read(overlayManagerProvider).showDropdown<String>(id: 'custom.page.menu', anchor: anchor, items: [
      if (s == null && d != null && d.isShared && d.allows(PluginPageDecl.surfacePage) && !c.temporary) const RasqDropdownItem('みんなで使う(招待コードを作る)', 'invite'),
      if (s?.inviteCode != null) const RasqDropdownItem('招待コードをコピー', 'copy'),
      if (s != null) RasqDropdownItem('参加者(${c.participants.length})', 'people'),
      if (isOwner) const RasqDropdownItem('セッションを閉じる', 'close', destructive: true),
      const RasqDropdownItem('ストアで見る', 'store'),
    ]);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (pick) {
      case 'invite':
        try {
          final created = await ref.read(customSessionClientProvider).create(pluginId: widget.args.pluginId, version: c.plugin?.storeVersion, scope: 'link');
          if (!mounted) return;
          context.pushReplacement(Routes.customPage(widget.args.pluginId, widget.args.withSession(created.id).query));
        } catch (e) {
          messenger?.showSnackBar(SnackBar(content: Text('招待を作れませんでした: $e')));
        }
      case 'copy':
        await Clipboard.setData(ClipboardData(text: s!.inviteCode!));
        messenger?.showSnackBar(SnackBar(content: Text('招待コード ${s.inviteCode} をコピーしました')));
      case 'people':
        await ref.read(overlayManagerProvider).showAlert(
              id: 'custom.page.people',
              title: '参加者',
              message: [for (final p in c.participants) '${p.displayName ?? p.handle} (@${p.handle})'].join('\n'),
              confirmText: '閉じる',
            );
      case 'close':
        final ok = await ref.read(overlayManagerProvider).showAlert(id: 'custom.page.closeConfirm', title: 'セッションを閉じますか?', message: '参加している全員のページで、共有の値が止まります。', confirmText: '閉じる', cancelText: 'キャンセル', destructive: true);
        if (ok) {
          try {
            await ref.read(customSessionClientProvider).close(s!.id);
          } catch (e) {
            messenger?.showSnackBar(SnackBar(content: Text('閉じられませんでした: $e')));
          }
        }
      case 'store':
        if (mounted) context.push(Routes.storePlugin(widget.args.pluginId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c!;
    final scheme = Theme.of(context).colorScheme;
    final name = c.title ?? c.decl?.title ?? c.plugin?.manifest.name ?? c.detail?.name ?? widget.args.pluginId;
    return Scaffold(
      appBar: RasqPageHeader(
        title: name,
        showMore: false,
        actions: [
          if (c.session != null)
            Padding(
              padding: const EdgeInsets.only(right: RasqSpacing.xs),
              child: Chip(
                key: const ValueKey('custom.page.participants'),
                avatar: const Icon(Icons.people_outline, size: 16),
                label: Text('${c.participants.length}'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          Builder(builder: (bctx) => RasqIconButton(key: const ValueKey('custom.page.more'), icon: Icons.more_horiz, tooltip: 'メニュー', onPressed: () => _menu(bctx))),
        ],
      ),
      body: LayoutBuilder(builder: (ctx, box) {
        WidgetsBinding.instance.addPostFrameCallback((_) => c.resized(Size(box.maxWidth, box.maxHeight)));
        return Column(children: [
          if (c.closedReason != null)
            _Banner(key: const ValueKey('custom.page.closed'), icon: Icons.stop_circle_outlined, text: 'このセッションは閉じられました(共有の値はもう変わりません)', color: scheme.errorContainer),
          if (c.notice != null) _Banner(icon: Icons.info_outline, text: c.notice!, color: scheme.secondaryContainer, onClose: c.dismissNotice),
          Expanded(child: _body(c, scheme)),
        ]);
      }),
    );
  }

  Widget _body(CustomPageController c, ColorScheme scheme) {
    switch (c.phase) {
      case CustomPagePhase.resolving || CustomPagePhase.loading:
        return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)));
      case CustomPagePhase.needsConsent:
        final d = c.detail;
        return ListView(padding: const EdgeInsets.all(RasqSpacing.page), children: [
          Text(d?.name ?? widget.args.pluginId, style: RasqTypography.title),
          const SizedBox(height: RasqSpacing.xs),
          Text('このページを開いている間だけ、インストールせずに動かします(閉じると消えます)。', style: RasqTypography.body.copyWith(color: scheme.onSurfaceVariant)),
          if (d != null && d.safety.permissions.isNotEmpty) ...[
            const SizedBox(height: RasqSpacing.md),
            Text('使う権限', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            for (final p in d.safety.permissions) ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: const Icon(Icons.shield_outlined, size: 18), title: Text(p.permission), subtitle: p.reason.isEmpty ? null : Text(p.reason)),
          ],
          const SizedBox(height: RasqSpacing.lg),
          FilledButton(key: const ValueKey('custom.consent.accept'), onPressed: c.acceptTemporary, child: const Text('使う')),
          TextButton(onPressed: () => context.pop(), child: const Text('やめる')),
        ]);
      case CustomPagePhase.needsInstall:
        return RasqEmptyView(
          key: const ValueKey('custom.page.needsInstall'),
          title: 'インストールされていません',
          hint: 'ストアからインストールすると開けます',
          action: FilledButton(onPressed: () => context.push(Routes.storePlugin(widget.args.pluginId)), child: const Text('ストアで見る')),
        );
      case CustomPagePhase.failed:
        return RasqEmptyView(key: const ValueKey('custom.page.failed'), title: '開けませんでした', hint: c.error);
      case CustomPagePhase.ready:
        final p = c.plugin!;
        final controller = p.runtime.view;
        return SingleChildScrollView(
          key: const ValueKey('custom.page.body'),
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: RrlRenderer(
            node: c.root!,
            host: RrlHost(
              instanceScope: controller.document?.scope ?? p.id,
              scope: RrlScope({}),
              geometry: controller.geometry,
              onEvent: c.onRrlEvent,
            ),
          ),
        );
    }
  }
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.text, required this.color, this.onClose});
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
          child: Row(children: [
            Icon(icon, size: 18),
            const SizedBox(width: RasqSpacing.xs),
            Expanded(child: Text(text, style: RasqTypography.caption)),
            if (onClose != null) IconButton(icon: const Icon(Icons.close, size: 16), onPressed: onClose, visualDensity: VisualDensity.compact),
          ]),
        ),
      );
}
