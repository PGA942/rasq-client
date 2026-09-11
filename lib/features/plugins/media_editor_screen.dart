import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rrl_renderer/rrl_renderer.dart' show rrlIconFor;

import '../../app/providers.dart';
import 'slot_plugins.dart';

/// メディアエディター (D-169、契約 v0.2 §2.2): 添付をプラグインで加工する専用の全画面。
///
/// 中央に画像(画面の 70%。プラグインの下付き FOW が開くと 45% に縮む)、
/// 左に第 1 階層の丸ボタン列(選んだジャンルのアクション)、右に縦のフローティング列
/// (上端の ↓ でプラグイン / 編集ジャンルを選ぶ。選ぶと左の列が入れ替わる)、
/// ヘッダーに キャンセル / 適用。プレビューはプラグインの `composer.media.preview` で
/// ほぼリアルタイムに差し替わる。結果は [MediaEditResult] で呼び出し元へ。
class MediaEditorArgs {
  const MediaEditorArgs({required this.plugin, required this.bytes, required this.name, required this.mimeType});
  final SlotPlugin plugin;
  final Uint8List bytes;
  final String name;
  final String mimeType;
}

class MediaEditResult {
  const MediaEditResult({required this.bytes, required this.mimeType, this.name});
  final Uint8List bytes;
  final String mimeType;
  final String? name;
}

const mediaEditorPreviewKey = Key('media.editor.preview');

class MediaEditorScreen extends ConsumerStatefulWidget {
  const MediaEditorScreen({super.key, required this.args});
  final MediaEditorArgs args;
  @override
  ConsumerState<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends ConsumerState<MediaEditorScreen> {
  late SlotPlugin _plugin = widget.args.plugin;
  MediaEditSession? _session;
  late Uint8List _preview = widget.args.bytes;
  int _genre = 0;
  bool _closing = false;
  String? _note;
  late final SlotPluginsNotifier _slots = ref.read(slotPluginsProvider.notifier);

  late final OverlayManager _overlay = ref.read(overlayManagerProvider);

  @override
  void initState() {
    super.initState();
    _slots.openFows.addListener(_onFows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 下の FOW(コンポーザー等)は退避、自分の下付き FOW(プラグイン)だけ出す (D-169)。
      // ビルド中に OverlayManager を通知できないのでフレーム後に。
      _suspendOthers();
      _open(_plugin);
    });
  }

  void _onFows() {
    if (mounted) setState(() {});
  }

  /// 自分(いま編集に使っているプラグイン)の下付き FOW だけ出し、他は退避。
  void _suspendOthers() => _overlay.setFowSuspend((e) => !e.id.startsWith('fow.slot.${_plugin.id}.'));

  bool get _fowOpen => _slots.openFows.value.any((id) => id.startsWith('fow.slot.${_plugin.id}.'));

  Future<void> _open(SlotPlugin plugin) async {
    final s = await _slots.mediaEditorOpen(
      plugin,
      name: widget.args.name,
      mimeType: widget.args.mimeType,
      bytes: widget.args.bytes,
      onPreview: (bytes, mime) {
        if (mounted) setState(() => _preview = bytes);
      },
      // 旧形(プラグイン自身の FOW → replace)や即差し替え形: そのまま結果にする。
      onReplace: (bytes, mime, name) => _finish(MediaEditResult(bytes: bytes, mimeType: mime, name: name)),
    );
    if (!mounted) return;
    setState(() {
      _plugin = plugin;
      _session = s;
      _genre = 0;
      _note = s == null ? '${plugin.manifest.name} はエディター形ではありません(プラグインのパネルで操作してください)' : null;
    });
    _suspendOthers();
  }

  void _finish(MediaEditResult? result) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _commit() async {
    final s = _session;
    if (s == null) return;
    final r = await _slots.mediaCommit(s);
    if (!mounted) return;
    if (r == null) {
      setState(() => _note = '適用できませんでした(プラグインが結果を返しませんでした)');
      return;
    }
    _finish(MediaEditResult(bytes: r.$1, mimeType: r.$2, name: r.$3));
  }

  Future<void> _cancel() async {
    final s = _session;
    if (s != null) await _slots.mediaCancel(s);
    _finish(null);
  }

  /// 右上の ↓: プラグイン / 編集ジャンルの切り替え。
  Future<void> _pick(Rect anchor) async {
    final manager = ref.read(overlayManagerProvider);
    final plugins = ref.read(slotPluginsForProvider(SlotIds.composerMedia));
    final genres = _session?.genres ?? const <MediaGenre>[];
    final pick = await manager.showDropdown<String>(id: 'media.editor.pick', anchor: anchor, dense: true, items: [
      for (final (i, g) in genres.indexed) RasqDropdownItem('${_plugin.manifest.name} ▸ ${g.label}', 'g:$i', accent: i == _genre),
      for (final p in plugins)
        if (p.id != _plugin.id) RasqDropdownItem('プラグイン: ${p.manifest.name}', 'p:${p.id}'),
    ]);
    if (pick == null || !mounted) return;
    if (pick.startsWith('g:')) {
      setState(() => _genre = int.parse(pick.substring(2)));
    } else {
      final next = plugins.where((p) => p.id == pick.substring(2)).firstOrNull;
      if (next == null) return;
      final s = _session;
      if (s != null) await _slots.mediaCancel(s);
      if (mounted) setState(() => _preview = widget.args.bytes);
      await _open(next);
    }
  }

  @override
  void dispose() {
    _overlay.setFowSuspend(null);
    _slots.openFows.removeListener(_onFows);
    final s = _session;
    if (s != null && !_closing) _slots.mediaCancel(s);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final genres = _session?.genres ?? const <MediaGenre>[];
    final genre = _genre < genres.length ? genres[_genre] : null;
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final factor = _fowOpen ? 0.45 : 0.7;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // 中央のプレビュー(下付き FOW が開くと上寄せで小さく)。
        AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: _fowOpen ? const Alignment(0, -0.6) : Alignment.center,
          child: AnimatedContainer(
            key: mediaEditorPreviewKey,
            duration: const Duration(milliseconds: 180),
            width: size.width * factor,
            height: size.height * factor,
            alignment: Alignment.center,
            child: Image.memory(_preview, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48)),
          ),
        ),
        // ヘッダー: キャンセル / タイトル / 適用。
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(RasqSpacing.sm),
            child: Row(children: [
              _Circle(child: RasqIconButton(icon: Icons.close, size: 18, color: Colors.white, tooltip: 'キャンセル', onPressed: _cancel)),
              const Spacer(),
              Text(genre == null ? _plugin.manifest.name : '${_plugin.manifest.name} ▸ ${genre.label}', style: RasqTypography.bodySmall.copyWith(color: Colors.white70)),
              const Spacer(),
              FilledButton(key: const ValueKey('media.editor.apply'), onPressed: _session == null ? null : _commit, child: const Text('適用')),
            ]),
          ),
        ),
        // 左: 第 1 階層(選んだジャンルのアクション)の丸ボタン列(AsTell 下段と同じ作法)。
        if (genre != null)
          Positioned(
            left: RasqSpacing.sm,
            top: 96,
            bottom: 24,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                for (final a in genre.actions) ...[
                  _RoundAction(key: ValueKey('media.action.${a.id}'), icon: rrlIconFor(a.icon, Icons.tune), label: a.label, onTap: () => _slots.mediaAction(_session!, genre.id, a.id)),
                  const SizedBox(height: RasqSpacing.sm),
                ],
              ]),
            ),
          ),
        // 右: カラーモード反転色の角丸枠(D-170)。上端に ↓(丸に包まない、上に詰める)、
        // その下にジャンルの縦列(スクロール)。
        Positioned(
          right: RasqSpacing.sm,
          top: 96,
          bottom: 24,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: scheme.inverseSurface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.onInverseSurface.withValues(alpha: 0.35)),
              ),
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Builder(
                  builder: (ctx) => RasqIconButton(
                    key: const ValueKey('media.editor.pick'),
                    icon: Icons.keyboard_arrow_down,
                    size: 22,
                    color: scheme.onInverseSurface,
                    tooltip: 'プラグイン / ジャンル',
                    onPressed: () {
                      final box = ctx.findRenderObject() as RenderBox;
                      _pick(box.localToGlobal(Offset.zero) & box.size);
                    },
                  ),
                ),
                Flexible(
                  child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(top: 2), children: [
                    for (final (i, g) in genres.indexed) ...[
                      _RoundAction(key: ValueKey('media.genre.${g.id}'), icon: rrlIconFor(g.icon, Icons.category_outlined), label: g.label, filled: i == _genre, onTap: () => setState(() => _genre = i)),
                      const SizedBox(height: RasqSpacing.sm),
                    ],
                  ]),
                ),
              ]),
            ),
          ),
        ),
        if (_note != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)), child: Text(_note!, style: RasqTypography.caption.copyWith(color: Colors.white)))),
          ),
      ]),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({super.key, required this.icon, required this.label, this.onTap, this.filled = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool filled;
  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: Material(
          color: filled ? RasqColors.accent : Colors.black.withValues(alpha: 0.45),
          shape: const CircleBorder(side: BorderSide(color: Colors.white70, width: 1.2)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: Colors.white)),
          ),
        ),
      );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle), child: child);
}
