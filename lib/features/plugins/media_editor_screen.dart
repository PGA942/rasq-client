import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rrl_renderer/rrl_renderer.dart' show rrlIconFor;

import '../../app/providers.dart';
import 'slot_plugins.dart';

/// メディアエディター (D-169 → D-171、契約 v0.4 §2.2): 添付をプラグインで加工する専用の全画面。
///
/// - 中央に画像(画面の 70%。下付き FOW が開くとその分だけ小さくなる)。
/// - 右に反転色の角丸枠: 上端の ↓ で **「プラグイン」/「ジャンル」** の見方を切り替え、その下に
///   プラグイン一覧 または ジャンル一覧(既定 5 種 + プラグインが宣言したカスタム)。
/// - 下付きの横方向リスト(端はフェードアウト)= 第 2 階層: 「プラグイン」なら選んだプラグインの全編集ボタン、
///   「ジャンル」なら全プラグインの中からそのジャンルに該当する編集ボタン。
/// - パラメーターが要る編集は第 3 階層 = プラグインの下付き FOW(スライダー等)。
/// - ヘッダーに キャンセル / 適用。プレビューは `composer.media.preview` でほぼリアルタイムに差し替わる。
///
/// プラグインをまたぐ編集は直列合成: 別プラグインの編集を押すと、今のプラグインを `media.commit` して
/// その結果を次のプラグインの `media.edit` に渡す。結果は [MediaEditResult] で呼び出し元へ。
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
const mediaEditorStripKey = Key('media.editor.strip');

/// 見方(↓ で切り替え)。
enum MediaEditorMode { plugin, genre }

class MediaEditorScreen extends ConsumerStatefulWidget {
  const MediaEditorScreen({super.key, required this.args});
  final MediaEditorArgs args;
  @override
  ConsumerState<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

/// 下付きリストの 1 ボタン = (プラグイン, ジャンル, アクション)。
typedef _Entry = ({SlotPlugin plugin, MediaGenre genre, MediaAction action});

class _MediaEditorScreenState extends ConsumerState<MediaEditorScreen> {
  late SlotPlugin _plugin = widget.args.plugin;
  MediaEditSession? _session;

  /// 今のセッションへの入力(前のプラグインの適用結果、最初は元の添付)。
  late Uint8List _base = widget.args.bytes;
  late String _baseMime = widget.args.mimeType;
  late String _baseName = widget.args.name;
  bool _baseChanged = false;
  late Uint8List _preview = widget.args.bytes;

  MediaEditorMode _mode = MediaEditorMode.plugin;
  String _genreId = 'tone';

  /// プラグインごとのジャンル一覧(`media.catalog`、無ければセッションの `genres` で補う)。
  final Map<String, List<MediaGenre>> _catalog = {};
  bool _closing = false;
  bool _busy = false;
  String? _note;
  late final SlotPluginsNotifier _slots = ref.read(slotPluginsProvider.notifier);
  late final OverlayManager _overlay = ref.read(overlayManagerProvider);
  final List<(ValueNotifier<double>, VoidCallback)> _fowHeightListeners = [];

  @override
  void initState() {
    super.initState();
    _slots.openFows.addListener(_onFows);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 下の FOW(コンポーザー等)は退避、自分の下付き FOW(プラグイン)だけ出す (D-169)。
      _suspendOthers();
      _loadCatalogs();
      _open(_plugin);
    });
  }

  Future<void> _loadCatalogs() async {
    for (final p in ref.read(slotPluginsForProvider(SlotIds.composerMedia))) {
      final g = await _slots.mediaCatalog(p);
      if (!mounted) return;
      if (g != null) setState(() => _catalog[p.id] = g);
    }
  }

  void _onFows() {
    if (!mounted) return;
    // 下付き FOW の高さに追従してプレビューを縮める。
    for (final (n, l) in _fowHeightListeners) {
      n.removeListener(l);
    }
    _fowHeightListeners.clear();
    for (final e in _overlay.entries) {
      final fow = e.fow;
      if (fow == null || !e.id.startsWith('fow.slot.${_plugin.id}.')) continue;
      void l() {
        if (mounted) setState(() {});
      }
      fow.heightFactor.addListener(l);
      _fowHeightListeners.add((fow.heightFactor, l));
    }
    setState(() {});
  }

  /// 自分(いま編集に使っているプラグイン)の下付き FOW だけ出し、他は退避。
  void _suspendOthers() => _overlay.setFowSuspend((e) => !e.id.startsWith('fow.slot.${_plugin.id}.'));

  /// 開いている下付き FOW が画面下端から占める高さ(px)。無ければ 0。
  /// パネルの実測(前フレームの位置)を優先し、まだ描かれていなければ heightFactor から見積もる。
  double _fowInset(Size size) {
    var inset = 0.0;
    for (final e in _overlay.entries) {
      final fow = e.fow;
      if (fow == null || !e.id.startsWith('fow.slot.${_plugin.id}.')) continue;
      final box = fow.previewBoundaryKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize && box.attached) {
        inset = math.max(inset, size.height - box.localToGlobal(Offset.zero).dy);
      } else {
        inset = math.max(inset, size.height * fow.heightFactor.value);
      }
    }
    return inset.clamp(0, size.height * 0.8);
  }

  double _lastInset = 0;

  Future<void> _open(SlotPlugin plugin) async {
    final s = await _slots.mediaEditorOpen(
      plugin,
      name: _baseName,
      mimeType: _baseMime,
      bytes: _base,
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
      if (s != null && !_catalog.containsKey(plugin.id)) _catalog[plugin.id] = s.genres;
      _note = s == null ? '${plugin.manifest.name} はエディター形ではありません(プラグインのパネルで操作してください)' : null;
    });
    _suspendOthers();
    _onFows();
  }

  /// 別プラグインへ(直列合成): 今のプラグインを適用して、その結果を次の入力にする。
  Future<void> _switchTo(SlotPlugin plugin) async {
    final s = _session;
    if (s != null && s.plugin.id == plugin.id) return;
    if (_busy) return;
    _busy = true;
    try {
      if (s != null) {
        final r = await _slots.mediaCommit(s);
        if (r != null) {
          _base = r.$1;
          _baseMime = r.$2;
          _baseName = r.$3 ?? _baseName;
          _baseChanged = true;
          _preview = r.$1;
        }
        _session = null;
      }
      if (!mounted) return;
      await _open(plugin);
    } finally {
      _busy = false;
    }
  }

  Future<void> _act(_Entry e) async {
    await _switchTo(e.plugin);
    final s = _session;
    if (s == null || s.plugin.id != e.plugin.id) return;
    await _slots.mediaAction(s, e.genre.id, e.action.id);
  }

  void _finish(MediaEditResult? result) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  Future<void> _commit() async {
    final s = _session;
    if (s == null) {
      _finish(_baseChanged ? MediaEditResult(bytes: _base, mimeType: _baseMime, name: _baseName) : null);
      return;
    }
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

  /// 右上の ↓: 見方(プラグイン / ジャンル)の切り替え。
  Future<void> _pick(Rect anchor) async {
    final pick = await _overlay.showDropdown<String>(id: 'media.editor.pick', anchor: anchor, dense: true, items: [
      RasqDropdownItem('プラグイン', 'plugin', checked: _mode == MediaEditorMode.plugin),
      RasqDropdownItem('ジャンル', 'genre', checked: _mode == MediaEditorMode.genre),
    ]);
    if (pick == null || !mounted) return;
    setState(() => _mode = pick == 'genre' ? MediaEditorMode.genre : MediaEditorMode.plugin);
  }

  @override
  void dispose() {
    _overlay.setFowSuspend(null);
    _slots.openFows.removeListener(_onFows);
    for (final (n, l) in _fowHeightListeners) {
      n.removeListener(l);
    }
    final s = _session;
    if (s != null && !_closing) _slots.mediaCancel(s);
    super.dispose();
  }

  /// ジャンル一覧 = 既定 5 種 + 全プラグインのカスタム(宣言順)。
  List<MediaGenre> get _allGenres {
    final out = <String, MediaGenre>{
      for (final e in mediaGenreDefaults.entries) e.key: MediaGenre(id: e.key, label: e.value.label),
    };
    for (final gs in _catalog.values) {
      for (final g in gs) {
        out.putIfAbsent(g.id, () => g);
      }
    }
    return out.values.toList();
  }

  /// 下付きリストの中身。
  List<_Entry> get _entries {
    final plugins = ref.read(slotPluginsForProvider(SlotIds.composerMedia));
    if (_mode == MediaEditorMode.plugin) {
      final gs = _catalog[_plugin.id] ?? _session?.genres ?? const <MediaGenre>[];
      return [for (final g in gs) for (final a in g.actions) (plugin: _plugin, genre: g, action: a)];
    }
    return [
      for (final p in plugins)
        for (final g in (_catalog[p.id] ?? const <MediaGenre>[]))
          if (g.id == _genreId)
            for (final a in g.actions) (plugin: p, genre: g, action: a),
    ];
  }

  IconData _genreIcon(MediaGenre g) => mediaGenreDefaults[g.id]?.icon ?? rrlIconFor(g.icon, Icons.category_outlined);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scheme = Theme.of(context).colorScheme;
    final plugins = ref.watch(slotPluginsForProvider(SlotIds.composerMedia));
    final fowH = _fowInset(size);
    // パネルの実測は 1 フレーム遅れるので、変わっていたら次のフレームで追従する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = _fowInset(MediaQuery.sizeOf(context));
      if ((now - _lastInset).abs() > 0.5) setState(() => _lastInset = now);
    });
    _lastInset = fowH;
    final entries = _entries;
    final subtitle = _mode == MediaEditorMode.plugin ? _plugin.manifest.name : (_allGenres.where((g) => g.id == _genreId).firstOrNull?.label ?? _genreId);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Column(children: [
          // ヘッダー: キャンセル / タイトル / 適用。
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(RasqSpacing.sm),
              child: Row(children: [
                _Circle(child: RasqIconButton(icon: Icons.close, size: 18, color: Colors.white, tooltip: 'キャンセル', onPressed: _cancel)),
                const Spacer(),
                Text(subtitle, style: RasqTypography.bodySmall.copyWith(color: Colors.white70), overflow: TextOverflow.ellipsis),
                const Spacer(),
                FilledButton(key: const ValueKey('media.editor.apply'), onPressed: _commit, child: const Text('適用')),
              ]),
            ),
          ),
          // 中央のプレビュー(画面の 70%。残りの高さに収まる範囲で)。
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) => Center(
                child: AnimatedContainer(
                  key: mediaEditorPreviewKey,
                  duration: const Duration(milliseconds: 180),
                  width: math.max(48, math.min(size.width * 0.7, c.maxWidth - 144)),
                  height: math.max(48, math.min(size.height * 0.7, c.maxHeight - 8)),
                  alignment: Alignment.center,
                  child: Image.memory(_preview, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48)),
                ),
              ),
            ),
          ),
          // 第 2 階層 = 下付きの横方向リスト(端はフェードアウト)。
          SizedBox(
            key: mediaEditorStripKey,
            height: 84,
            child: entries.isEmpty
                ? Center(child: Text(_mode == MediaEditorMode.plugin ? 'このプラグインに編集はありません' : '「$subtitle」の編集を持つプラグインがありません', style: RasqTypography.caption.copyWith(color: Colors.white54)))
                : ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent], stops: [0, 0.08, 0.92, 1]).createShader(r),
                    blendMode: BlendMode.dstIn,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(width: RasqSpacing.sm),
                      itemBuilder: (_, i) {
                        final e = entries[i];
                        return _StripAction(
                          key: ValueKey('media.action.${e.plugin.id}.${e.genre.id}.${e.action.id}'),
                          icon: rrlIconFor(e.action.icon, Icons.tune),
                          label: e.action.label,
                          // 「ジャンル」の見方では、どのプラグインの編集か分かるように小さく添える。
                          sub: _mode == MediaEditorMode.genre ? e.plugin.manifest.name : null,
                          onTap: () => _act(e),
                        );
                      },
                    ),
                  ),
          ),
          // 下付き FOW(プラグインのパラメーター)の分だけ空ける。
          AnimatedContainer(duration: const Duration(milliseconds: 180), height: fowH),
        ]),
        // 右: カラーモード反転色の角丸枠(D-170)。上端に ↓(見方の切り替え)、その下に
        // プラグイン一覧 / ジャンル一覧(スクロール)。
        Positioned(
          right: RasqSpacing.sm,
          top: 96,
          bottom: 84 + fowH + 8,
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
                    tooltip: _mode == MediaEditorMode.plugin ? '見方: プラグイン' : '見方: ジャンル',
                    onPressed: () {
                      final box = ctx.findRenderObject() as RenderBox;
                      _pick(box.localToGlobal(Offset.zero) & box.size);
                    },
                  ),
                ),
                Flexible(
                  child: ListView(shrinkWrap: true, padding: const EdgeInsets.only(top: 2), children: [
                    if (_mode == MediaEditorMode.plugin)
                      for (final p in plugins) ...[
                        _RoundAction(key: ValueKey('media.plugin.${p.id}'), icon: Icons.extension_outlined, label: p.manifest.name, filled: p.id == _plugin.id, onTap: () => _switchTo(p)),
                        const SizedBox(height: RasqSpacing.sm),
                      ]
                    else
                      for (final g in _allGenres) ...[
                        _RoundAction(key: ValueKey('media.genre.${g.id}'), icon: _genreIcon(g), label: g.label, filled: g.id == _genreId, onTap: () => setState(() => _genreId = g.id)),
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
            bottom: 84 + fowH + 8,
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

/// 下付き横リストの 1 ボタン: 丸アイコン + 短いラベル(+ プラグイン名)。
class _StripAction extends StatelessWidget {
  const _StripAction({super.key, required this.icon, required this.label, this.sub, this.onTap});
  final IconData icon;
  final String label;
  final String? sub;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 68,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(side: BorderSide(color: Colors.white70, width: 1.2)),
              child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: Colors.white)),
            ),
            const SizedBox(height: 2),
            Text(label, style: RasqTypography.caption.copyWith(color: Colors.white, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (sub != null) Text(sub!, style: RasqTypography.caption.copyWith(color: Colors.white54, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
      );
}

class _Circle extends StatelessWidget {
  const _Circle({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => DecoratedBox(decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle), child: child);
}
