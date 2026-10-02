import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/providers.dart';
import 'slot_plugins.dart';

/// プラグインの編集パネル (D-249、契約 v0.10 §2.2): 加工画面([ProMediaEditorScreen])の**上に重ねて**出す、
/// プラグイン 1 つぶんの編集セッション。以前の専用画面(MediaEditorScreen、D-169〜D-172)を加工画面に統合したもの。
///
/// - 入口は加工画面の下段バーのボタン(マニフェストの `actions` の `slot: "composer.media"`。並べ替え / バンドルは
///   アクションバーの編集と同じ仕組み)。プラグイン / ジャンルの切り替え列はもう無い(バーとバンドルがその役)。
/// - 中央にプレビュー(`composer.media.preview` でほぼリアルタイムに差し替わる)+ 重ね(`composer.media.overlay`)。
/// - 下に横方向リスト = このプラグインの全編集ボタン(`media.edit` の `genres`)。パラメーターはプラグインの下付き FOW。
/// - 押されたボタンの宣言 id が `genres` のアクション id と同じなら、開いた直後にその `media.action` を呼ぶ。
/// - ヘッダーに キャンセル / 適用。結果は [onDone] へ(null = キャンセル)。
class MediaEditResult {
  const MediaEditResult({required this.bytes, required this.mimeType, this.name});
  final Uint8List bytes;
  final String mimeType;
  final String? name;
}

const mediaEditorPreviewKey = Key('media.editor.preview');
const mediaEditorStripKey = Key('media.editor.strip');
const mediaEditorOverlayKey = Key('media.editor.overlay');

class MediaPluginPanel extends ConsumerStatefulWidget {
  const MediaPluginPanel({super.key, required this.plugin, required this.bytes, required this.name, required this.mimeType, this.actionId, required this.onDone});
  final SlotPlugin plugin;
  final Uint8List bytes;
  final String name;
  final String mimeType;

  /// 押されたボタンの宣言 id(`media.edit` に `actionId` で渡る)。
  final String? actionId;
  final void Function(MediaEditResult? result) onDone;
  @override
  ConsumerState<MediaPluginPanel> createState() => _MediaPluginPanelState();
}

/// 下付きリストの 1 ボタン = (プラグイン, ジャンル, アクション)。
typedef _Entry = ({MediaGenre genre, MediaAction action});

class _MediaPluginPanelState extends ConsumerState<MediaPluginPanel> {
  SlotPlugin get _plugin => widget.plugin;
  MediaEditSession? _session;
  late Uint8List _preview = widget.bytes;
  late String _previewMime = widget.mimeType;

  /// プレビューの画素数(重ねの座標系)。`composer.media.preview` の width/height、無ければ復号して測る。
  (int, int)? _previewSize;
  Uint8List? _measuring;

  /// プレビューの上に重ねる RRL(`composer.media.overlay`、契約 v0.5)。
  RrlNode? _overlayRoot;

  /// 合わせる先 (契約 v0.6、D-174): 重ねの Box の key。ダブルタップ → 「この上にドラッグ」で入る。
  final Set<String> _snapKeys = {};

  /// 下付き横リスト: 中身が変わったら初期位置を中央に(D-172)。
  ScrollController? _strip;
  String _stripKey = '';

  bool _closing = false;
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
      _open();
    });
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
  void _suspendOthers() => _overlay.setFowSuspend((e) => !e.id.startsWith('fow.slot.${_plugin.id}.') && !e.id.startsWith('fow.media.'));

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

  Future<void> _open() async {
    final plugin = _plugin;
    final s = await _slots.mediaEditorOpen(
      plugin,
      name: widget.name,
      mimeType: widget.mimeType,
      bytes: widget.bytes,
      actionId: widget.actionId,
      onPreview: (bytes, mime, w, h) {
        if (!mounted) return;
        setState(() {
          _preview = bytes;
          _previewMime = mime;
          _previewSize = (w != null && h != null && w > 0 && h > 0) ? (w, h) : null;
        });
      },
      onOverlay: (root) {
        if (mounted) setState(() => _overlayRoot = root);
      },
      // 旧形(プラグイン自身の FOW → replace)や即差し替え形: そのまま結果にする。
      onReplace: (bytes, mime, name) => _finish(MediaEditResult(bytes: bytes, mimeType: mime, name: name)),
    );
    if (!mounted) return;
    setState(() {
      _overlayRoot = null;
      _snapKeys.clear();
      _session = s;
      _note = s == null && !_closing ? '${plugin.manifest.name} はここでは編集できません(プラグインのパネルで操作してください)' : null;
    });
    _suspendOthers();
    _onFows();
    // 押されたボタンがそのまま編集の 1 つなら、すぐ始める(契約 v0.10)。
    final want = widget.actionId;
    if (s != null && want != null) {
      for (final g in s.genres) {
        for (final a in g.actions) {
          if (a.id == want) {
            await _slots.mediaAction(s, g.id, a.id);
            return;
          }
        }
      }
    }
  }

  /// 幅 / 高さが来なかったプレビューを復号して測る(重ねがあるときだけ)。
  void _measurePreview() {
    if (_previewSize != null || identical(_measuring, _preview) || _overlayRoot == null) return;
    final bytes = _preview;
    _measuring = bytes;
    ui.decodeImageFromList(bytes, (img) {
      if (!mounted || !identical(bytes, _preview)) return;
      setState(() => _previewSize = (img.width, img.height));
      img.dispose();
    });
  }

  /// プレビュー(+ 重ね)。重ねはプレビューの画素数の Stack を表示倍率に合わせて拡縮する(ビューワーの重ねと同じ作法)。
  Widget _previewWidget() {
    // 画像でない添付(動画 / 音声)は、プラグインがプレビューを出すまで印だけ。
    if (!_previewMime.startsWith('image/')) return Icon(_previewMime.startsWith('audio/') ? Icons.graphic_eq : Icons.movie_outlined, color: Colors.white54, size: 64);
    final image = Image.memory(_preview, fit: BoxFit.contain, gaplessPlayback: true, errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48));
    final root = _overlayRoot;
    final size = _previewSize;
    if (root == null) return image;
    if (size == null) {
      _measurePreview();
      return image;
    }
    final controller = _plugin.runtime.view;
    final boxes = _overlayBoxes(root);
    final targets = [for (final b in boxes) if (_snapKeys.contains(b.key)) b];
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        key: mediaEditorOverlayKey,
        width: size.$1.toDouble(),
        height: size.$2.toDouble(),
        child: Stack(fit: StackFit.expand, children: [
          Image.memory(_preview, fit: BoxFit.fill, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          // ダブルタップ (v0.6): 合わせる先の指定。子の tap / drag はそのまま(ダブルタップ判定ぶんだけ tap が遅れる)。
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTapDown: (d) => _onOverlayDoubleTap(boxes, d.localPosition, d.globalPosition),
            child: RrlRenderer(
              node: root,
              host: RrlHost(
                instanceScope: controller.document?.scope ?? _plugin.id,
                scope: RrlScope({}),
                geometry: controller.geometry,
                mediaPolicy: _plugin.mediaPolicy,
                onEvent: (nodeId, kind, {fn, payload = const {}}) => controller.handleEvent(nodeId, kind, fn: fn, payload: _withSnap(boxes, nodeId, kind, payload)),
              ),
            ),
          ),
          // 合わせる先の強調(点線)。
          if (targets.isNotEmpty) IgnorePointer(child: CustomPaint(painter: _SnapPainter(targets))),
        ]),
      ),
    );
  }

  /// 重ねの `Box`(left/top/width/height 付き)を集める。
  static List<_OvBox> _overlayBoxes(RrlNode root) {
    final out = <_OvBox>[];
    for (final c in root.c) {
      if (c.t != 'Box') continue;
      final l = (c.p['left'] as num?)?.toDouble(), t = (c.p['top'] as num?)?.toDouble(), w = (c.p['width'] as num?)?.toDouble(), h = (c.p['height'] as num?)?.toDouble();
      if (l == null || t == null || w == null || h == null) continue;
      out.add(_OvBox(key: c.k ?? '#${out.length}', label: c.p['label'] as String?, rect: Rect.fromLTWH(l, t, w, h), angle: (c.p['angle'] as num?)?.toDouble() ?? 0));
    }
    return out;
  }

  /// `drag` の `end` に `snap` を添える (契約 v0.6): 指を離した位置(ノード左上 + x,y)が合わせる先の中なら。
  Map<String, Object?> _withSnap(List<_OvBox> boxes, String nodeId, String kind, Map<String, Object?> payload) {
    if (kind != 'drag' || payload['phase'] != 'end' || _snapKeys.isEmpty) return payload;
    final key = nodeId.split(':').last;
    final self = boxes.where((b) => b.key == key).firstOrNull;
    final pt = Offset((self?.rect.left ?? 0) + ((payload['x'] as num?)?.toDouble() ?? 0), (self?.rect.top ?? 0) + ((payload['y'] as num?)?.toDouble() ?? 0));
    for (final t in boxes.reversed) {
      if (t.key == key || !_snapKeys.contains(t.key) || !t.contains(pt)) continue;
      return {...payload, 'snap': {'key': t.key, if (t.label != null) 'label': t.label, 'left': t.rect.left, 'top': t.rect.top, 'width': t.rect.width, 'height': t.rect.height, 'angle': t.angle}};
    }
    return payload;
  }

  Future<void> _onOverlayDoubleTap(List<_OvBox> boxes, Offset local, Offset global) async {
    final hit = boxes.reversed.where((b) => b.contains(local)).firstOrNull;
    final isTarget = hit != null && _snapKeys.contains(hit.key);
    final pick = await _overlay.showDropdown<String>(id: 'media.editor.snap', anchor: global & const Size(1, 1), dense: true, items: [
      if (hit != null) RasqDropdownItem(isTarget ? 'この上にドラッグ(解除)' : 'この上にドラッグ(合わせる先にする)', 'toggle', checked: isTarget),
      const RasqDropdownItem('合わせる先を選ぶ…', 'pick'),
      if (_snapKeys.isNotEmpty) const RasqDropdownItem('合わせる先をすべて解除', 'clear'),
    ]);
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'toggle':
        final key = hit?.key;
        if (key != null) setState(() => isTarget ? _snapKeys.remove(key) : _snapKeys.add(key));
      case 'pick':
        _openSnapFow();
      case 'clear':
        setState(_snapKeys.clear);
    }
  }

  /// 合わせる先を選ぶ FOW: label 付きの Box を一覧、複数選択。
  void _openSnapFow() {
    _overlay.showFow<void>(
      id: 'fow.media.snap',
      spec: FowSpec(type: FowPanelType.widget, title: '合わせる先', cancelText: '閉じる', initialHeightFactor: 0.45, dockAboveFooter: true),
      builder: (ctx, handle) => StatefulBuilder(builder: (ctx, setLocal) {
        final root = _overlayRoot;
        final boxes = root == null ? const <_OvBox>[] : _overlayBoxes(root).where((b) => b.label != null).toList();
        if (boxes.isEmpty) return Center(child: Text('名前の付いた枠がありません', style: RasqTypography.bodySmall));
        return ListView(padding: EdgeInsets.zero, children: [
          for (final b in boxes)
            RasqListTile(
              key: ValueKey('media.snap.${b.key}'),
              title: b.label!,
              subtitle: '${b.rect.width.round()} × ${b.rect.height.round()}${b.angle == 0 ? '' : '、${b.angle.round()}°'}',
              chevron: false,
              trailing: Icon(_snapKeys.contains(b.key) ? Icons.check_box : Icons.check_box_outline_blank, color: _snapKeys.contains(b.key) ? RasqColors.accent : null),
              onTap: () {
                setState(() => _snapKeys.contains(b.key) ? _snapKeys.remove(b.key) : _snapKeys.add(b.key));
                setLocal(() {});
              },
            ),
        ]);
      }),
    );
  }

  Future<void> _act(_Entry e) async {
    final s = _session;
    if (s == null) return;
    await _slots.mediaAction(s, e.genre.id, e.action.id);
  }

  void _finish(MediaEditResult? result) {
    if (_closing || !mounted) return;
    _closing = true;
    widget.onDone(result);
  }

  Future<void> _commit() async {
    final s = _session;
    if (s == null) {
      _finish(null);
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

  @override
  void dispose() {
    _overlay.setFowSuspend(null);
    _slots.openFows.removeListener(_onFows);
    for (final (n, l) in _fowHeightListeners) {
      n.removeListener(l);
    }
    _strip?.dispose();
    final s = _session;
    if (s != null && !_closing) _slots.mediaCancel(s);
    super.dispose();
  }

  /// 下付きリストの中身 = このプラグインの全編集ボタン。
  List<_Entry> get _entries => [for (final g in _session?.genres ?? const <MediaGenre>[]) for (final a in g.actions) (genre: g, action: a)];

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final fowH = _fowInset(size);
    // パネルの実測は 1 フレーム遅れるので、変わっていたら次のフレームで追従する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = _fowInset(MediaQuery.sizeOf(context));
      if ((now - _lastInset).abs() > 0.5) setState(() => _lastInset = now);
    });
    _lastInset = fowH;
    final entries = _entries;
    final subtitle = _plugin.manifest.name;
    // 加工画面の上に重ねる(ルートではない)。戻る操作はキャンセル。
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Material(
      color: Colors.black,
      child: Stack(children: [
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
                  width: math.max(48, math.min(size.width * 0.7, c.maxWidth - 16)),
                  height: math.max(48, math.min(size.height * 0.7, c.maxHeight - 8)),
                  alignment: Alignment.center,
                  child: _previewWidget(),
                ),
              ),
            ),
          ),
          // 第 2 階層 = 下付きの横方向リスト(端はフェードアウト)。
          SizedBox(
            key: mediaEditorStripKey,
            height: 84,
            child: entries.isEmpty
                ? Center(child: Text(_session == null ? '' : 'このプラグインに編集はありません', style: RasqTypography.caption.copyWith(color: Colors.white54)))
                : LayoutBuilder(builder: (ctx, c) {
                    // 初期はセンター揃え (D-172): 収まるなら中央に並べ、はみ出すなら中央から始める。
                    const itemW = 68.0;
                    const gap = RasqSpacing.sm;
                    const pad = 24.0;
                    final content = pad * 2 + entries.length * itemW + (entries.length - 1) * gap;
                    final key = '${_plugin.id}:${entries.length}';
                    if (key != _stripKey) {
                      _stripKey = key;
                      _strip?.dispose();
                      _strip = ScrollController(initialScrollOffset: math.max(0, (content - c.maxWidth) / 2));
                    }
                    return ShaderMask(
                      shaderCallback: (r) => const LinearGradient(colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent], stops: [0, 0.08, 0.92, 1]).createShader(r),
                      blendMode: BlendMode.dstIn,
                      child: ListView.separated(
                        controller: _strip,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: content < c.maxWidth ? pad + (c.maxWidth - content) / 2 : pad, vertical: 6),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => const SizedBox(width: gap),
                        itemBuilder: (_, i) {
                          final e = entries[i];
                          return _StripAction(
                            key: ValueKey('media.action.${_plugin.id}.${e.genre.id}.${e.action.id}'),
                            icon: rrlIconFor(e.action.icon, Icons.tune),
                            label: e.action.label,
                            sub: e.genre.label,
                            onTap: () => _act(e),
                          );
                        },
                      ),
                    );
                  }),
          ),
          // 下付き FOW(プラグインのパラメーター)の分だけ空ける。
          AnimatedContainer(duration: const Duration(milliseconds: 180), height: fowH),
        ]),
        if (_note != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 84 + fowH + 8,
            child: Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)), child: Text(_note!, style: RasqTypography.caption.copyWith(color: Colors.white)))),
          ),
      ]),
      ),
    );
  }
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

/// 重ねの Box(合わせる先の候補 / ドラッグ対象)。
class _OvBox {
  const _OvBox({required this.key, this.label, required this.rect, this.angle = 0});
  final String key;
  final String? label;
  final Rect rect;

  /// 度(中心で回転)。
  final double angle;

  /// 回転を戻してから矩形に入っているか。
  bool contains(Offset p) {
    if (angle == 0) return rect.contains(p);
    final c = rect.center;
    final a = -angle * math.pi / 180;
    final d = p - c;
    final r = Offset(d.dx * math.cos(a) - d.dy * math.sin(a), d.dx * math.sin(a) + d.dy * math.cos(a)) + c;
    return rect.contains(r);
  }
}

/// 合わせる先の点線(回転つき)。
class _SnapPainter extends CustomPainter {
  const _SnapPainter(this.targets);
  final List<_OvBox> targets;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = RasqColors.accent;
    for (final t in targets) {
      canvas.save();
      if (t.angle != 0) {
        canvas.translate(t.rect.center.dx, t.rect.center.dy);
        canvas.rotate(t.angle * math.pi / 180);
        canvas.translate(-t.rect.center.dx, -t.rect.center.dy);
      }
      final r = t.rect.inflate(3);
      const dash = 6.0;
      void seg(Offset a, Offset b) {
        final len = (b - a).distance;
        var d = 0.0;
        while (d < len) {
          final e = math.min(d + dash, len);
          canvas.drawLine(Offset.lerp(a, b, d / len)!, Offset.lerp(a, b, e / len)!, paint);
          d += dash * 2;
        }
      }
      seg(r.topLeft, r.topRight);
      seg(r.topRight, r.bottomRight);
      seg(r.bottomRight, r.bottomLeft);
      seg(r.bottomLeft, r.topLeft);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SnapPainter old) => old.targets != targets;
}
