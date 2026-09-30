import 'dart:async';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../settings/settings_dsl.dart';
import '../swing/swing_providers.dart';
import '../vc/astell_fows.dart' show openAstellCreateFow;

/// 作るボタン (D-378 → D-381 → D-382)。
///
/// - **ホーム / トレンドの ＋**([CreateGestureFab]): タップ = 投稿、**上へスライド = Swing**、**下へスライド = AsTell**。
///   D-382: FOW は使わない。
///   - **ホバー(マウス)/ 長押し**で、＋ の**横にチップ**(置けるなら右、狭ければ左)。押すとそれを始める。
///   - **スライドを始めると縦長の角丸のレール**がフェードインし、＋ が指に付いて動く。**端まで動かして離す**と、そのまま作成ページへ。
///     途中で離せば何もしない。
///   - 押す / 動かす / 長押しは自分で見分ける(素早く上へ払って離しても長押しにならない)。
///   - トレンドの投稿は、そのワードのハッシュタグ入り。
/// - **AsTell の ＋**([AstellCreateFab]): 押すと横にチップ(Swing / AsTell / RASQ に投稿)。
/// - 割り当ては設定 → アプリの外観 → 「＋ ボタンの割り当て」(領域 [fabSettingsArea])。
/// - Swing は作成ページ(始め方: 画像 / 動画 / プラグイン / 背景とテキスト、D-380)へ。

enum CreateChoice {
  post('post'),
  rasq('rasq'),
  astell('astell'),
  swing('swing'),
  none('none');

  const CreateChoice(this.wire);
  final String wire;

  static CreateChoice parse(Object? v, CreateChoice fallback) => CreateChoice.values.where((c) => c.wire == v).firstOrNull ?? fallback;
}


/// 割り当ての設定 (D-381)。
const fabSettingsArea = 'appearance.fab';

/// この端末で使えるか。
bool createChoiceAvailable(WidgetRef ref, CreateChoice c) => switch (c) {
      CreateChoice.post => true,
      CreateChoice.rasq => ref.read(orgateAccountProvider).value != null,
      CreateChoice.astell => ref.read(childGateProvider).featureAllowed('astell.join'),
      CreateChoice.swing => ref.read(swingApiProvider) != null,
      CreateChoice.none => false,
    };

/// 今この端末で選べるもの(並び順どおり)。
List<CreateChoice> availableCreateChoices(WidgetRef ref) => [for (final c in const [CreateChoice.post, CreateChoice.rasq, CreateChoice.astell, CreateChoice.swing]) if (createChoiceAvailable(ref, c)) c];

({IconData icon, String title, String subtitle}) createChoiceLabel(CreateChoice c) => switch (c) {
      CreateChoice.post => (icon: Icons.edit_outlined, title: '投稿', subtitle: 'いまのアカウントの SNS に投稿します'),
      CreateChoice.rasq => (icon: Icons.person_pin_outlined, title: 'RASQ に投稿', subtitle: 'RASQ アカウントのページに投稿します'),
      CreateChoice.astell => (icon: Icons.graphic_eq, title: 'AsTell を作る', subtitle: '声で話せる部屋を開きます'),
      CreateChoice.swing => (icon: Icons.bolt_outlined, title: 'Swing を作る', subtitle: 'フォロワーや RASQ リストの人に届き、時間がたつと消えます'),
      CreateChoice.none => (icon: Icons.block, title: 'なし', subtitle: ''),
    };

/// 1 つを実行する。使えなければ理由を出す。[postText] = 投稿の書き出し(トレンドのハッシュタグ)。
Future<void> runCreateChoice(BuildContext context, WidgetRef ref, CreateChoice c, {String? postText, VoidCallback? onPosted}) async {
  if (c == CreateChoice.none) return;
  if (!createChoiceAvailable(ref, c)) {
    final why = switch (c) {
      CreateChoice.rasq || CreateChoice.swing => '${createChoiceLabel(c).title}には RASQ アカウントが要ります',
      CreateChoice.astell => '見守りの設定で AsTell が止められています',
      _ => '使えません',
    };
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(why)));
    return;
  }
  switch (c) {
    case CreateChoice.post:
      final created = await showComposer(ref, const ComposeNormal(), initialText: postText);
      if (created != null) onPosted?.call();
    case CreateChoice.rasq:
      await showComposer(ref, const ComposeNormal(), rasqTarget: true, initialText: postText);
    case CreateChoice.astell:
      await openAstellCreateFow(context, ref);
    case CreateChoice.swing:
      // 作成ページ(始め方の一覧、D-380)へ。
      await context.push(Routes.swingNew);
    case CreateChoice.none:
      break;
  }
}

/// ホーム / トレンドの ＋ の割り当て。
({CreateChoice tap, CreateChoice up, CreateChoice down}) gestureFabChoices(WidgetRef ref, String scope) {
  final m = ref.watch(settingsAreaProvider(fabSettingsArea)).value ?? const <String, Object?>{};
  return (
    tap: CreateChoice.parse(m['${scope}Tap'], CreateChoice.post),
    up: CreateChoice.parse(m['${scope}Up'], CreateChoice.swing),
    down: CreateChoice.parse(m['${scope}Down'], CreateChoice.astell),
  );
}

/// ＋ の横のチップと、スライドのレール (D-382)。
class CreateGestureFab extends ConsumerStatefulWidget {
  const CreateGestureFab({super.key, required this.scope, required this.heroTag, this.postText, this.onPosted});

  /// `home` / `trend`(設定のキーの頭)。
  final String scope;
  final Object heroTag;
  final String? postText;
  final VoidCallback? onPosted;

  /// 押したまま動かさずにこれだけたつと長押し。
  static const longPress = Duration(milliseconds: 450);

  /// これだけ動かしたらスライド(それまでは押しただけ)。
  static const slop = 10.0;

  /// レールの片側の長さ。端(この 75% 以上)で離すと始める。
  static const travel = 104.0;

  @override
  ConsumerState<CreateGestureFab> createState() => _CreateGestureFabState();
}

class _CreateGestureFabState extends ConsumerState<CreateGestureFab> with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _chips = OverlayPortalController();
  final _track = OverlayPortalController();
  late final AnimationController _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));

  Offset? _down;
  double _dy = 0;
  bool _sliding = false;
  bool _consumed = false;
  bool _pinned = false; // 長押しで出したチップ(外を押すまで出したまま)
  bool _hoverFab = false;
  bool _hoverChips = false;
  Timer? _longTimer;
  Timer? _hideTimer;

  @override
  void dispose() {
    _longTimer?.cancel();
    _hideTimer?.cancel();
    _fade.dispose();
    super.dispose();
  }

  ({CreateChoice tap, CreateChoice up, CreateChoice down}) get _a => gestureFabChoices(ref, widget.scope);

  void _run(CreateChoice c) {
    _hideChips();
    runCreateChoice(context, ref, c, postText: widget.postText, onPosted: widget.onPosted);
  }

  void _showChips({bool pinned = false}) {
    _hideTimer?.cancel();
    _pinned = _pinned || pinned;
    if (!_chips.isShowing) _chips.show();
    setState(() {});
  }

  void _hideChips() {
    _hideTimer?.cancel();
    _pinned = false;
    if (_chips.isShowing) _chips.hide();
    if (mounted) setState(() {});
  }

  /// マウスが ＋ からもチップからも離れたら、少し待って隠す。
  void _maybeHide() {
    _hideTimer?.cancel();
    if (_pinned) return;
    _hideTimer = Timer(const Duration(milliseconds: 250), () {
      if (!_hoverFab && !_hoverChips && !_pinned) _hideChips();
    });
  }

  void _onDown(PointerDownEvent e) {
    _down = e.position;
    _dy = 0;
    _sliding = false;
    _consumed = false;
    _longTimer?.cancel();
    _longTimer = Timer(CreateGestureFab.longPress, () {
      if (_down == null || _sliding) return;
      _consumed = true;
      _showChips(pinned: true);
    });
  }

  void _onMove(PointerMoveEvent e) {
    final d = _down;
    if (d == null) return;
    final delta = e.position - d;
    if (!_sliding && delta.dy.abs() > CreateGestureFab.slop && delta.dy.abs() >= delta.dx.abs()) {
      _sliding = true;
      _consumed = true;
      _longTimer?.cancel();
      _hideChips();
      _track.show();
      _fade.forward(from: 0);
    }
    if (_sliding) setState(() => _dy = delta.dy.clamp(-CreateGestureFab.travel, CreateGestureFab.travel));
  }

  CreateChoice? get _target {
    if (!_sliding) return null;
    if (_dy <= -CreateGestureFab.travel * 0.75) return _a.up;
    if (_dy >= CreateGestureFab.travel * 0.75) return _a.down;
    return null;
  }

  void _onUp(PointerEvent e) {
    _longTimer?.cancel();
    final target = e is PointerUpEvent ? _target : null;
    _down = null;
    if (_sliding) {
      _fade.reverse().whenComplete(() {
        if (_track.isShowing) _track.hide();
      });
      setState(() {
        _sliding = false;
        _dy = 0;
      });
    }
    if (target != null && target != CreateChoice.none) _run(target);
  }

  /// チップを右に置けるか(＋ の右に余白がある)。
  bool get _chipsRight {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final right = box.localToGlobal(Offset(box.size.width, 0)).dx;
    return MediaQuery.sizeOf(context).width - right >= _chipWidth + 16;
  }

  static const _chipWidth = 168.0;

  @override
  Widget build(BuildContext context) {
    final a = _a;
    final scheme = Theme.of(context).colorScheme;
    final right = _chipsRight;
    Widget chip(CreateChoice c, IconData dir) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            elevation: 3,
            color: scheme.surface,
            shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
            child: InkWell(
              key: ValueKey('fab.${widget.scope}.chip.${c.name}'),
              customBorder: const StadiumBorder(),
              onTap: () => _run(c),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(dir, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Icon(createChoiceLabel(c).icon, size: 16),
                  const SizedBox(width: 6),
                  Text(createChoiceLabel(c).title, style: RasqTypography.bodySmall),
                ]),
              ),
            ),
          ),
        );
    final chips = [
      if (a.up != CreateChoice.none) chip(a.up, Icons.arrow_upward),
      if (a.tap != CreateChoice.none) chip(a.tap, Icons.touch_app_outlined),
      if (a.down != CreateChoice.none) chip(a.down, Icons.arrow_downward),
    ];
    final fabSize = 56.0;
    final target = _target;
    Widget end(CreateChoice c, {required bool top}) => Opacity(
          opacity: c == CreateChoice.none ? 0.3 : 1,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(createChoiceLabel(c).icon, size: 20, color: target == c ? scheme.onPrimary : scheme.onSurface),
            Text(c == CreateChoice.none ? '' : createChoiceLabel(c).title.replaceAll('を作る', '').trim(), style: RasqTypography.caption.copyWith(fontSize: 10, color: target == c ? scheme.onPrimary : scheme.onSurface)),
          ]),
        );
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _track,
        overlayChildBuilder: (_) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.center,
          followerAnchor: Alignment.center,
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _fade,
              child: SizedBox(
                width: fabSize + 20,
                height: fabSize + CreateGestureFab.travel * 2 + 20,
                child: Stack(alignment: Alignment.center, children: [
                  // レール(縦長の角丸)。端に上 / 下で始まるもの。
                  Container(
                    key: ValueKey('fab.${widget.scope}.track'),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular((fabSize + 20) / 2),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    child: Container(
                      key: ValueKey('fab.${widget.scope}.track.up'),
                      width: fabSize + 12,
                      height: fabSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: target == a.up && a.up != CreateChoice.none ? scheme.primary : Colors.transparent),
                      child: end(a.up, top: true),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    child: Container(
                      key: ValueKey('fab.${widget.scope}.track.down'),
                      width: fabSize + 12,
                      height: fabSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: target == a.down && a.down != CreateChoice.none ? scheme.primary : Colors.transparent),
                      child: end(a.down, top: false),
                    ),
                  ),
                  // 指に付いて動く ＋。
                  Transform.translate(
                    offset: Offset(0, _dy),
                    child: Material(color: scheme.primaryContainer, shape: const CircleBorder(), elevation: 6, child: SizedBox(width: fabSize, height: fabSize, child: Icon(Icons.add, color: scheme.onPrimaryContainer))),
                  ),
                ]),
              ),
            ),
          ),
        ),
        child: OverlayPortal(
          controller: _chips,
          overlayChildBuilder: (_) => Stack(children: [
            // 長押しで出したときは、外を押すと隠す。
            if (_pinned) Positioned.fill(child: GestureDetector(key: ValueKey('fab.${widget.scope}.chips.barrier'), behavior: HitTestBehavior.translucent, onTap: _hideChips)),
            CompositedTransformFollower(
              link: _link,
              targetAnchor: right ? Alignment.centerRight : Alignment.centerLeft,
              followerAnchor: right ? Alignment.centerLeft : Alignment.centerRight,
              offset: Offset(right ? 8 : -8, 0),
              child: MouseRegion(
                onEnter: (_) => _hoverChips = true,
                onExit: (_) {
                  _hoverChips = false;
                  _maybeHide();
                },
                child: Column(
                  key: ValueKey('fab.${widget.scope}.chips'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: right ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: chips,
                ),
              ),
            ),
          ]),
          child: MouseRegion(
            onEnter: (e) {
              _hoverFab = true;
              if (e.kind == PointerDeviceKind.mouse) _showChips();
            },
            onExit: (_) {
              _hoverFab = false;
              _maybeHide();
            },
            child: Listener(
              key: ValueKey('fab.${widget.scope}.gesture'),
              onPointerDown: _onDown,
              onPointerMove: _onMove,
              onPointerUp: _onUp,
              onPointerCancel: _onUp,
              child: Opacity(
                // スライドの間は、レールの上の ＋ を動かす(元の ＋ は隠す)。
                opacity: _sliding ? 0 : 1,
                // RAi の案内が指す名前 (D-378)。長押しはチップに使うので、ツールチップは長押しでは出さない。
                child: Tooltip(
                  message: '作成',
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
        ),
      ),
    );
  }
}

/// AsTell の ＋ (D-381 / D-382): 押すと横にチップ(Swing / AsTell / RASQ に投稿、設定で出すものを選べる)。1 つだけならそのまま。
class AstellCreateFab extends ConsumerStatefulWidget {
  const AstellCreateFab({super.key});

  @override
  ConsumerState<AstellCreateFab> createState() => _AstellCreateFabState();
}

class _AstellCreateFabState extends ConsumerState<AstellCreateFab> {
  final _link = LayerLink();
  final _chips = OverlayPortalController();

  List<CreateChoice> get _choices {
    final m = ref.read(settingsAreaProvider(fabSettingsArea)).value ?? const <String, Object?>{};
    final all = [
      if (m['astellSwing'] != false) CreateChoice.swing,
      if (m['astellAstell'] != false) CreateChoice.astell,
      if (m['astellRasq'] != false) CreateChoice.rasq,
    ];
    return all.isEmpty ? const [CreateChoice.astell] : all;
  }

  void _run(CreateChoice c) {
    if (_chips.isShowing) _chips.hide();
    runCreateChoice(context, ref, c);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(settingsAreaProvider(fabSettingsArea));
    final scheme = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _chips,
        overlayChildBuilder: (_) => Stack(children: [
          Positioned.fill(child: GestureDetector(key: const ValueKey('fab.astell.chips.barrier'), behavior: HitTestBehavior.translucent, onTap: _chips.hide)),
          CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.centerLeft,
            followerAnchor: Alignment.centerRight,
            offset: const Offset(-8, 0),
            child: Column(key: const ValueKey('fab.astell.chips'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final c in _choices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Material(
                    elevation: 3,
                    color: scheme.surface,
                    shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
                    child: InkWell(
                      key: ValueKey('fab.astell.chip.${c.name}'),
                      customBorder: const StadiumBorder(),
                      onTap: () => _run(c),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(createChoiceLabel(c).icon, size: 16),
                          const SizedBox(width: 6),
                          Text(createChoiceLabel(c).title, style: RasqTypography.bodySmall),
                        ]),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ]),
        child: FloatingActionButton(
          // 全画面ビューワー(ルートナビゲータへ push)の Hero と衝突しないよう固有タグ (D-145)。
          heroTag: 'astell.create',
          tooltip: 'VC を作成',
          onPressed: () {
            final choices = [for (final c in _choices) if (createChoiceAvailable(ref, c)) c];
            if (choices.length == 1) return _run(choices.single);
            _chips.isShowing ? _chips.hide() : _chips.show();
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
