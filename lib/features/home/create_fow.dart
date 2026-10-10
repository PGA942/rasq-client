import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../settings/settings_dsl.dart';
import '../swing/swing_composer.dart' show openSwingComposer;
import '../swing/swing_providers.dart';
import '../vc/astell_fows.dart' show openAstellCreateFow;

/// 作るボタン (D-378 → D-381 → D-382 → D-383 → D-385)。
///
/// - **＋**([RadialCreateFab]、ホーム / トレンド / AsTell): **タップ**で決まったもの(ホーム / トレンド = 投稿、AsTell = AsTell を作る)。
/// - **展開**(ホバー / 長押し): 後ろを暗くし、**丸いアクションボタン**(下に名前、[RasqActionCircle])を ＋ の左上の扇に出す。
///   押すとそれを始める。展開している間、＋ は**歯車**に変わり、押すとボタンの並べ替えの FOW([_FabEditor])。
/// - **枠は最大 7 つ** (D-385): 内側の輪に 3 つ(上 / 左 / 左上)、4 つ目からは外側の輪に 4 つまで。**置いた数で並びが変わる**
///   ([fabSlotPositions]: 内側 1 つなら上、2 つなら上と左 …、外側は数に合わせて扇に均等)。
/// - **スライド**: その方向へ動かすとボタンを薄く出し、向かっている方を強く出す。近くで離すと内側、遠くまで動かすと外側の輪
///   ([fabSlotFor])。十分動かして離すと、それを始める(作成ページへ)。
///   押す / 動かす / 長押しは自分で見分ける(素早く払って離しても長押しにならない)。
/// - **並べ替えの FOW**: 上に ×、真ん中に ＋ と枠のプレビュー(置いてあるもの + 次に足す空き枠)、下にアクションボタンの列
///   (AsTell / Swing / RASQ に投稿 / 投稿 / アカウントごとの SNS の投稿)。ドラッグで枠に入れる / 枠どうしで入れ替える / 列へ戻して外す。
///   設定領域 [fabSettingsArea] の `<scope>Slots`(置いた順のアクション id、最大 [fabMaxSlots])。
/// - アクション: `post`(いまのアカウント)/ `post:<accountKey>`(そのアカウントで)/ `rasq` / `swing` / `astell` / `none`。
/// - トレンドの投稿は、そのワードのハッシュタグ入り([RadialCreateFab.postText])。

/// 割り当ての設定。
const fabSettingsArea = 'appearance.fab';

/// 並べ替えの FOW。
const fabEditorFowId = 'fow.fab.editor';

/// 枠の数の上限(内側 [fabInnerSlots] + 外側 4)。
const fabMaxSlots = 7;

/// 内側の輪の枠の数。
const fabInnerSlots = 3;

/// 内側 / 外側の輪の、＋ からの距離。
const fabInnerRadius = 92.0;
const fabOuterRadius = 168.0;

/// 左 = 0°、上 = 90° の向き(度)。内側は置いた順に 上 → 左 → 左上。外側は数に合わせて扇に均等(上から)。
List<double> _innerAngles(int k) => const [90.0, 0.0, 45.0].sublist(0, k.clamp(0, fabInnerSlots));
List<double> _outerAngles(int k) => switch (k) {
      <= 0 => const [],
      1 => const [45],
      2 => const [70, 20],
      3 => const [80, 45, 10],
      _ => const [90, 60, 30, 0],
    };

Offset _dir(double deg) => Offset(-math.cos(deg * math.pi / 180), -math.sin(deg * math.pi / 180));

/// [n] 個置いたときの、それぞれの位置(＋ の中心から。y は下が +)。n = 0..[fabMaxSlots]。
List<Offset> fabSlotPositions(int n) {
  final c = n.clamp(0, fabMaxSlots);
  return [
    for (final a in _innerAngles(c)) _dir(a) * fabInnerRadius,
    for (final a in _outerAngles(c - fabInnerSlots)) _dir(a) * fabOuterRadius,
  ];
}

/// 画面ごとの既定。
({String tap, List<String> slots}) _defaults(String scope) => switch (scope) {
      'astell' => (tap: 'astell', slots: const ['swing', 'rasq', 'post']),
      _ => (tap: 'post', slots: const ['swing', 'astell', 'rasq']),
    };

/// ＋ の割り当て(タップ / 置いた順の枠)。
({String tap, List<String> slots}) fabAssignment(WidgetRef ref, String scope) {
  final m = ref.watch(settingsAreaProvider(fabSettingsArea)).value ?? const <String, Object?>{};
  final d = _defaults(scope);
  final raw = m['${scope}Slots'];
  return (tap: m['${scope}Tap'] is String ? m['${scope}Tap'] as String : d.tap, slots: raw is List ? normalizeFabSlots([for (final v in raw) '$v']) : d.slots);
}

/// 空き('none')を詰め、同じものは 1 つにし、[fabMaxSlots] までにする(D-383 の「上 / 左 / 左上」の保存もこれで読める)。
List<String> normalizeFabSlots(List<String> ids) {
  final out = <String>[];
  for (final id in ids) {
    if (id == 'none' || id.isEmpty || out.contains(id)) continue;
    out.add(id);
    if (out.length == fabMaxSlots) break;
  }
  return out;
}

Future<void> setFabSlots(WidgetRef ref, String scope, List<String> slots) => ref.read(settingsAreaProvider(fabSettingsArea).notifier).set('${scope}Slots', normalizeFabSlots(slots));

AccountSession? _sessionOf(WidgetRef ref, String key) => ref.read(sessionsProvider).value?.sessions.where((s) => s.account.key == key).firstOrNull;

/// アクションの見た目と、使えるか。
({IconData icon, String label, AccountSession? account, bool available}) createActionInfo(WidgetRef ref, String id) {
  if (id.startsWith('post:')) {
    final s = _sessionOf(ref, id.substring(5));
    return (icon: Icons.edit_outlined, label: s == null ? '(いないアカウント)' : (s.displayName?.isNotEmpty == true ? s.displayName! : '@${s.account.handle}'), account: s, available: s != null);
  }
  return switch (id) {
    'post' => (icon: Icons.edit_outlined, label: '投稿', account: null, available: true),
    'rasq' => (icon: Icons.person_pin_outlined, label: 'RASQ', account: null, available: ref.read(orgateAccountProvider).value != null),
    'astell' => (icon: Icons.graphic_eq, label: 'ASTell', account: null, available: ref.read(childGateProvider).featureAllowed('astell.join')),
    'swing' => (icon: Icons.bolt_outlined, label: 'Swing', account: null, available: ref.read(swingApiProvider) != null),
    _ => (icon: Icons.block, label: 'なし', account: null, available: false),
  };
}

/// 並べられるアクション(並べ替えの FOW の下の列)。
List<String> createActionPalette(WidgetRef ref) => [
      'astell',
      'swing',
      'rasq',
      'post',
      for (final s in ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[]) 'post:${s.account.key}',
    ];

/// アクションの丸ボタン(アカウントはアバター + SNS の印)。
Widget createActionCircle(WidgetRef ref, String id, {VoidCallback? onTap, bool faded = false, bool selected = false, Color? labelColor, double size = 52, Key? key}) {
  final info = createActionInfo(ref, id);
  final acc = info.account;
  return RasqActionCircle(
    key: key,
    icon: info.icon,
    label: info.label,
    onTap: onTap,
    faded: faded || !info.available,
    selected: selected,
    labelColor: labelColor,
    size: size,
    badge: acc == null ? null : RasqSnsPill(account: acc.account, showLabel: false, dotSize: 16),
    child: acc == null ? null : RasqAvatar(imageUrl: acc.avatarUrl, size: size - 6, fallbackLabel: info.label),
  );
}

/// 1 つを実行する。使えなければ理由を出す。[postText] = 投稿の書き出し(トレンドのハッシュタグ)。
Future<void> runCreateAction(BuildContext context, WidgetRef ref, String id, {String? postText, VoidCallback? onPosted}) async {
  if (id == 'none') return;
  final info = createActionInfo(ref, id);
  if (!info.available) {
    final why = switch (id) {
      'rasq' || 'swing' => '${info.label}には RASQ アカウントが要ります',
      'astell' => '見守りの設定で ASTell が止められています',
      _ => 'このアカウントはもうありません',
    };
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(why)));
    return;
  }
  if (id == 'post' || id.startsWith('post:')) {
    final created = await showComposer(ref, const ComposeNormal(), initialText: postText, postAs: info.account);
    if (created != null) onPosted?.call();
    return;
  }
  switch (id) {
    case 'rasq':
      await showComposer(ref, const ComposeNormal(), rasqTarget: true, initialText: postText);
    case 'astell':
      await openAstellCreateFow(context, ref);
    case 'swing':
      // 作る画面 (D-410)。幅の広い画面では、押したカラム(ホーム / 第3カラム)を置き換えて開く (D-413)。
      await openSwingComposer(context);
  }
}

/// 動かした量 → 枠の番号([n] 個置いているとき)。十分動いていない / 右や下へ動かしたら null。
/// 内側と外側の間より遠ければ外側の輪(外側に置いていれば)、そのうえで向きのいちばん近い枠。
int? fabSlotFor(Offset delta, int n, {double arm = 56}) {
  if (n <= 0 || delta.distance < arm || delta.dx > 12 || delta.dy > 12) return null;
  final pos = fabSlotPositions(n);
  final outer = n > fabInnerSlots && delta.distance > (fabInnerRadius + fabOuterRadius) / 2;
  final range = outer ? [for (var i = fabInnerSlots; i < pos.length; i++) i] : [for (var i = 0; i < math.min(n, fabInnerSlots); i++) i];
  final a = math.atan2(-delta.dy, -delta.dx);
  int? best;
  var bestDiff = double.infinity;
  for (final i in range) {
    final diff = (math.atan2(-pos[i].dy, -pos[i].dx) - a).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = i;
    }
  }
  return best;
}

/// ＋ (D-383 / D-385)。[scope] = `home` / `trend` / `astell`(設定のキーの頭)。
class RadialCreateFab extends ConsumerStatefulWidget {
  const RadialCreateFab({super.key, required this.scope, required this.heroTag, this.postText, this.onPosted, this.tooltip = '作成'});

  final String scope;
  final Object heroTag;
  final String? postText;
  final VoidCallback? onPosted;

  /// RAi の案内が指す名前 (D-378)。長押しは展開に使うので、ツールチップは長押しでは出さない。
  final String tooltip;

  /// 押したまま動かさずにこれだけたつと長押し。
  static const longPress = Duration(milliseconds: 450);

  /// これだけ動かしたらスライド(それまでは押しただけ)。
  static const slop = 10.0;

  @override
  ConsumerState<RadialCreateFab> createState() => _RadialCreateFabState();
}

enum _Mode { idle, sliding, open }

class _RadialCreateFabState extends ConsumerState<RadialCreateFab> with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _overlay = OverlayPortalController();
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));

  _Mode _mode = _Mode.idle;

  /// 展開がマウス(ホバー)からか(暗い背景は押せない = マウスが離れれば閉じる)。
  bool _byHover = false;
  Offset? _down;
  Offset _delta = Offset.zero;
  bool _consumed = false;
  bool _hoverFab = false;
  bool _hoverOverlay = false;
  Timer? _longTimer;
  Timer? _hideTimer;

  @override
  void dispose() {
    _longTimer?.cancel();
    _hideTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  void _show(_Mode m, {bool byHover = false}) {
    _hideTimer?.cancel();
    setState(() {
      _mode = m;
      _byHover = byHover;
    });
    if (!_overlay.isShowing) _overlay.show();
    _fade.forward();
  }

  void _close() {
    _hideTimer?.cancel();
    if (_mode == _Mode.idle) return;
    setState(() {
      _mode = _Mode.idle;
      _delta = Offset.zero;
    });
    _fade.reverse().whenComplete(() {
      if (_mode == _Mode.idle && _overlay.isShowing) _overlay.hide();
    });
  }

  void _run(String id) {
    _close();
    runCreateAction(context, ref, id, postText: widget.postText, onPosted: widget.onPosted);
  }

  void _maybeHideHover() {
    _hideTimer?.cancel();
    if (!_byHover || _mode != _Mode.open) return;
    _hideTimer = Timer(const Duration(milliseconds: 250), () {
      if (!_hoverFab && !_hoverOverlay) _close();
    });
  }

  void _onDown(PointerDownEvent e) {
    if (_mode == _Mode.open) return; // 開いている間は歯車(押すと並べ替え)
    _down = e.position;
    _delta = Offset.zero;
    _consumed = false;
    _longTimer?.cancel();
    _longTimer = Timer(RadialCreateFab.longPress, () {
      if (_down == null || _mode != _Mode.idle) return;
      _consumed = true;
      _down = null;
      _show(_Mode.open);
    });
  }

  void _onMove(PointerMoveEvent e) {
    final d = _down;
    if (d == null) return;
    final delta = e.position - d;
    if (_mode == _Mode.idle && delta.distance > RadialCreateFab.slop) {
      _consumed = true;
      _longTimer?.cancel();
      _show(_Mode.sliding);
    }
    if (_mode == _Mode.sliding) setState(() => _delta = delta);
  }

  void _onUp(PointerEvent e) {
    _longTimer?.cancel();
    final wasDown = _down != null;
    _down = null;
    if (_mode != _Mode.sliding || !wasDown) return;
    final slots = fabAssignment(ref, widget.scope).slots;
    final slot = e is PointerUpEvent ? fabSlotFor(_delta, slots.length) : null;
    final id = slot == null ? null : slots[slot];
    _close();
    if (id != null && id != 'none') runCreateAction(context, ref, id, postText: widget.postText, onPosted: widget.onPosted);
  }

  Future<void> _openEditor() async {
    _close();
    final manager = ref.read(overlayManagerProvider);
    await manager.showFow<void>(
      id: fabEditorFowId,
      spec: FowSpec(
        type: FowPanelType.widget,
        initialHeightFactor: 0.62,
        minHeightFactor: 0.4,
        maxHeightFactor: 0.9,
        // 上に ×。
        headerLeading: RasqIconButton(key: const ValueKey('fab.editor.close'), icon: Icons.close, tooltip: '閉じる', onPressed: () => manager.close(fabEditorFowId)),
        title: '＋ のボタン',
      ),
      semanticsLabel: '＋ のボタン',
      builder: (ctx, handle) => _FabEditor(scope: widget.scope),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = fabAssignment(ref, widget.scope);
    final scheme = Theme.of(context).colorScheme;
    final target = _mode == _Mode.sliding ? fabSlotFor(_delta, a.slots.length) : null;
    final pos = fabSlotPositions(a.slots.length);
    const box = fabOuterRadius * 2 + 140;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlay,
        overlayChildBuilder: (_) => Stack(children: [
          // 後ろを暗くする。長押しで開いたときは、押すと閉じる。
          Positioned.fill(
            child: IgnorePointer(
              ignoring: _mode != _Mode.open || _byHover,
              child: GestureDetector(
                key: ValueKey('fab.${widget.scope}.scrim'),
                onTap: _close,
                child: FadeTransition(opacity: _fade, child: const ColoredBox(color: Colors.black54)),
              ),
            ),
          ),
          // 外側の輪まで入れると画面より大きくなるので、画面の幅に縛らない(位置は ＋ に付いていく)。
          Positioned(
            left: 0,
            top: 0,
            child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.center,
            followerAnchor: Alignment.center,
            child: MouseRegion(
              onEnter: (_) => _hoverOverlay = true,
              onExit: (_) {
                _hoverOverlay = false;
                _maybeHideHover();
              },
              child: FadeTransition(
                opacity: _fade,
                child: SizedBox(
                  width: box,
                  height: box,
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (var i = 0; i < a.slots.length; i++)
                      Positioned(
                        left: box / 2 + pos[i].dx - 40,
                        top: box / 2 + pos[i].dy - 30,
                        child: IgnorePointer(
                          ignoring: _mode != _Mode.open,
                          child: createActionCircle(
                            ref,
                            a.slots[i],
                            key: ValueKey('fab.${widget.scope}.action.$i'),
                            onTap: () => _run(a.slots[i]),
                            faded: _mode == _Mode.sliding && target != i,
                            selected: target == i,
                            labelColor: Colors.white,
                          ),
                        ),
                      ),
                    // 展開している間の ＋ = 歯車(押すと並べ替え)。スライドの間は ＋ のまま。
                    Positioned(
                      left: box / 2 - 28,
                      top: box / 2 - 28,
                      child: IgnorePointer(
                        ignoring: _mode != _Mode.open,
                        child: Material(
                          color: scheme.primaryContainer,
                          shape: const CircleBorder(),
                          elevation: 6,
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            key: ValueKey('fab.${widget.scope}.settings'),
                            onTap: _openEditor,
                            child: SizedBox(width: 56, height: 56, child: Icon(_mode == _Mode.open ? Icons.settings : Icons.add, color: scheme.onPrimaryContainer)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
          ),
        ]),
        child: MouseRegion(
          onEnter: (e) {
            _hoverFab = true;
            if (e.kind == PointerDeviceKind.mouse && _mode == _Mode.idle) _show(_Mode.open, byHover: true);
          },
          onExit: (_) {
            _hoverFab = false;
            _maybeHideHover();
          },
          child: Listener(
            key: ValueKey('fab.${widget.scope}.gesture'),
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onUp,
            child: Tooltip(
              message: widget.tooltip,
              triggerMode: TooltipTriggerMode.manual,
              child: FloatingActionButton(
                heroTag: widget.heroTag,
                onPressed: () {
                  // スライド / 長押しのあとの「離した」は押したことにしない。
                  if (_consumed) return;
                  _run(a.tap);
                },
                shape: const CircleBorder(),
                child: const Icon(Icons.add),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 並べ替えの FOW (D-383 / D-385): 真ん中に ＋ と枠(置いてあるもの + 次に足す空き枠)、下にアクションボタンの列。
/// 列から枠へドラッグで入れる(置いてある枠なら入れ替え、空き枠なら足す)/ 枠どうしで入れ替える / 列へ戻して外す。
class _FabEditor extends ConsumerWidget {
  const _FabEditor({required this.scope});
  final String scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = fabAssignment(ref, scope);
    final scheme = Theme.of(context).colorScheme;
    final n = a.slots.length;
    // 空き枠を足した数で並べる(足したときの位置がそのまま見える)。
    final shown = math.min(n + 1, fabMaxSlots);
    final pos = fabSlotPositions(shown);
    const fab = 56.0;
    const margin = 52.0;
    const box = fabOuterRadius + fab / 2 + margin + 28;
    // ＋ の中心(プレビューの右下)。
    const center = Offset(box - fab / 2 - 8, box - fab / 2 - 8);

    // [data] = 列のアクション id(String)か、枠の番号(int)。
    void drop(int slot, Object data) {
      final next = [...a.slots];
      if (data is int) {
        if (data == slot || slot >= next.length) return;
        final t = next[slot];
        next[slot] = next[data];
        next[data] = t;
      } else if (data is String) {
        final at = next.indexOf(data);
        if (slot < next.length) {
          // 置いてあったものは、動かしてきたものの元の枠へ(列からなら外れる)。
          if (at >= 0) next[at] = next[slot];
          next[slot] = data;
        } else if (at < 0) {
          next.add(data);
        }
      }
      setFabSlots(ref, scope, next);
    }

    void remove(int slot) => setFabSlots(ref, scope, [...a.slots]..removeAt(slot));

    Widget slotView(int i) {
      final id = i < n ? a.slots[i] : null;
      return DragTarget<Object>(
        onWillAcceptWithDetails: (d) => d.data != i,
        onAcceptWithDetails: (d) => drop(i, d.data),
        builder: (ctx, cand, _) {
          final hover = cand.isNotEmpty;
          if (id == null) {
            return Container(
              key: const ValueKey('fab.editor.slot.add'),
              width: 80,
              height: 76,
              alignment: Alignment.topCenter,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle, color: hover ? scheme.primaryContainer : null, border: Border.all(color: hover ? scheme.primary : scheme.outline, width: 1.5)),
                child: Icon(Icons.add, color: scheme.outline),
              ),
            );
          }
          final circle = createActionCircle(ref, id, key: ValueKey('fab.editor.slot.$i'), selected: hover);
          return Draggable<Object>(
            data: i,
            feedback: Material(color: Colors.transparent, child: createActionCircle(ref, id)),
            childWhenDragging: Opacity(opacity: 0.3, child: circle),
            child: circle,
          );
        },
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqCaption(
        '下のボタンを枠へドラッグすると入ります(枠どうしは入れ替え、下の列へ戻すと外れます)。内側に 3 つ、外側に 4 つまで ・ $n / $fabMaxSlots',
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
      ),
      // プレビュー: 右下に ＋、左上の扇に枠。
      Expanded(
        child: Center(
          child: FittedBox(
            child: SizedBox(
              key: const ValueKey('fab.editor.preview'),
              width: box,
              height: box,
              child: Stack(children: [
                // 輪の目安。
                for (final r in [fabInnerRadius, if (shown > fabInnerSlots) fabOuterRadius])
                  Positioned(
                    left: center.dx - r,
                    top: center.dy - r,
                    child: IgnorePointer(
                      child: Container(width: r * 2, height: r * 2, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)))),
                    ),
                  ),
                for (var i = 0; i < shown; i++) Positioned(left: center.dx + pos[i].dx - 40, top: center.dy + pos[i].dy - 26, child: slotView(i)),
                Positioned(
                  left: center.dx - fab / 2,
                  top: center.dy - fab / 2,
                  child: Material(color: scheme.primaryContainer, shape: const CircleBorder(), elevation: 4, child: SizedBox(width: fab, height: fab, child: Icon(Icons.add, color: scheme.onPrimaryContainer))),
                ),
              ]),
            ),
          ),
        ),
      ),
      // 下の列: 並べられるアクション。ここへ枠のボタンを落とすと外れる。
      DragTarget<Object>(
        onWillAcceptWithDetails: (d) => d.data is int,
        onAcceptWithDetails: (d) => remove(d.data as int),
        builder: (ctx, cand, _) => Container(
          key: const ValueKey('fab.editor.palette'),
          height: 104,
          decoration: BoxDecoration(color: cand.isNotEmpty ? scheme.errorContainer : scheme.surfaceContainerHighest, border: Border(top: BorderSide(color: scheme.outlineVariant))),
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.sm), children: [
            for (final id in createActionPalette(ref))
              Draggable<Object>(
                data: id,
                feedback: Material(color: Colors.transparent, child: createActionCircle(ref, id)),
                childWhenDragging: Opacity(opacity: 0.3, child: createActionCircle(ref, id)),
                child: createActionCircle(ref, id, key: ValueKey('fab.editor.palette.$id'), faded: a.slots.contains(id)),
              ),
          ]),
        ),
      ),
    ]);
  }
}
