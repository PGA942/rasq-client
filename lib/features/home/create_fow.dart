import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../compose/compose_target.dart';
import '../compose/composer_sheet.dart';
import '../settings/settings_dsl.dart';
import '../swing/swing_composer.dart';
import '../swing/swing_providers.dart';
import '../vc/astell_fows.dart' show openAstellCreateFow;

/// 作るボタン (D-378 → D-381)。
///
/// - **ホームの ＋**([CreateGestureFab] scope `home`): タップ = 投稿、**上へスワイプ = Swing**、**下へスワイプ = AsTell**。
///   長押し(マウスで押し続ける)で、割り当ての 3 つを並べた小さい FOW。
/// - **トレンドの ＋**(scope `trend`): 同じ動き。投稿はそのワードのハッシュタグを入れて開く。
/// - **AsTell の ＋**([AstellCreateFab]): タップで Swing / AsTell / RASQ に投稿 の小さい FOW(1 つだけなら、それをそのまま)。
/// - どれも割り当てを変えられる(設定 → アプリの外観 → 「＋ ボタンの割り当て」、領域 [fabSettingsArea])。
/// - FOW は ＋ の**上に付く**小さいパネル(幅 [createFowWidth]、見出しと説明は無し、D-379)。
/// - Swing は、同じ所に 2 段目(画像 / 動画 / プラグイン / 背景とテキスト、D-380)。

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

const createFowId = 'fow.create';

/// ＋ の FOW の幅と 1 行の高さ。
const createFowWidth = 300.0;
const _rowHeight = 60.0;

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
Future<void> runCreateChoice(BuildContext context, WidgetRef ref, CreateChoice c, {Rect? anchor, String? postText, VoidCallback? onPosted}) async {
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
      // 同じ所に 2 段目(画像 / 動画 / プラグイン / 背景とテキスト、D-380)。
      final start = await _showFow<SwingStart>(ref, context, anchor: anchor, rows: SwingStart.values.length, builder: (close) => SwingStartList(onPick: close));
      if (start != null && context.mounted) await startSwing(context, ref, start);
    case CreateChoice.none:
      break;
  }
}

/// 選ぶ FOW([choices] のうち使えるもの)。1 つだけなら、それをそのまま。
Future<void> openCreateMenu(BuildContext context, WidgetRef ref, {required List<CreateChoice> choices, Rect? anchor, String? postText, VoidCallback? onPosted}) async {
  final usable = [for (final c in choices.toSet()) if (createChoiceAvailable(ref, c)) c];
  if (usable.isEmpty) return;
  final pick = usable.length == 1
      ? usable.single
      : await _showFow<CreateChoice>(ref, context, anchor: anchor, rows: usable.length, builder: (close) => Column(mainAxisSize: MainAxisSize.min, children: [
            for (final c in usable)
              RasqListTile(key: ValueKey('create.${c.name}'), leading: Icon(createChoiceLabel(c).icon), title: createChoiceLabel(c).title, chevron: false, onTap: () => close(c)),
          ]));
  if (pick == null || !context.mounted) return;
  await runCreateChoice(context, ref, pick, anchor: anchor, postText: postText, onPosted: onPosted);
}

/// ホームの ＋ の旧入口(全部を並べる)。
Future<void> openCreateFow(BuildContext context, WidgetRef ref, {Rect? anchor, VoidCallback? onPosted}) =>
    openCreateMenu(context, ref, choices: availableCreateChoices(ref), anchor: anchor, onPosted: onPosted);

/// ホーム / トレンドの ＋ の割り当て。
({CreateChoice tap, CreateChoice up, CreateChoice down}) gestureFabChoices(WidgetRef ref, String scope) {
  final m = ref.watch(settingsAreaProvider(fabSettingsArea)).value ?? const <String, Object?>{};
  return (
    tap: CreateChoice.parse(m['${scope}Tap'], CreateChoice.post),
    up: CreateChoice.parse(m['${scope}Up'], CreateChoice.swing),
    down: CreateChoice.parse(m['${scope}Down'], CreateChoice.astell),
  );
}

/// タップ / 上下のスワイプで作るものが変わる ＋ (D-381)。動かしている間は、離すと何が始まるかを上 / 下に出す。
class CreateGestureFab extends ConsumerStatefulWidget {
  const CreateGestureFab({super.key, required this.scope, required this.heroTag, this.postText, this.onPosted});

  /// `home` / `trend`(設定のキーの頭)。
  final String scope;
  final Object heroTag;
  final String? postText;
  final VoidCallback? onPosted;

  /// これだけ動かしたらスワイプ。
  static const threshold = 36.0;

  @override
  ConsumerState<CreateGestureFab> createState() => _CreateGestureFabState();
}

class _CreateGestureFabState extends ConsumerState<CreateGestureFab> {
  double _dy = 0;
  bool _dragging = false;

  Rect? get _anchor {
    final box = context.findRenderObject() as RenderBox?;
    return box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
  }

  void _run(CreateChoice c) => runCreateChoice(context, ref, c, anchor: _anchor, postText: widget.postText, onPosted: widget.onPosted);

  @override
  Widget build(BuildContext context) {
    final a = gestureFabChoices(ref, widget.scope);
    final pending = !_dragging ? null : (_dy <= -CreateGestureFab.threshold ? a.up : (_dy >= CreateGestureFab.threshold ? a.down : null));
    Widget hint(CreateChoice c, {required bool above}) => Positioned(
          right: 0,
          top: above ? -44 : null,
          bottom: above ? null : -44,
          child: IgnorePointer(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: _dragging && c != CreateChoice.none ? (pending == c ? 1 : 0.55) : 0,
              child: Material(
                key: ValueKey('fab.${widget.scope}.hint.${above ? 'up' : 'down'}'),
                elevation: 2,
                borderRadius: BorderRadius.circular(16),
                color: pending == c ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(above ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
                    const SizedBox(width: 4),
                    Text(createChoiceLabel(c).title, style: RasqTypography.caption),
                  ]),
                ),
              ),
            ),
          ),
        );
    return GestureDetector(
      key: ValueKey('fab.${widget.scope}.gesture'),
      onVerticalDragStart: (_) => setState(() {
        _dragging = true;
        _dy = 0;
      }),
      onVerticalDragUpdate: (d) => setState(() => _dy += d.delta.dy),
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        final c = (_dy <= -CreateGestureFab.threshold || v < -600) ? a.up : ((_dy >= CreateGestureFab.threshold || v > 600) ? a.down : null);
        setState(() => _dragging = false);
        if (c != null) _run(c);
      },
      onVerticalDragCancel: () => setState(() => _dragging = false),
      onLongPress: () => openCreateMenu(context, ref, choices: [a.tap, a.up, a.down], anchor: _anchor, postText: widget.postText, onPosted: widget.onPosted),
      child: Stack(clipBehavior: Clip.none, children: [
        Transform.translate(
          offset: Offset(0, _dragging ? _dy.clamp(-24.0, 24.0) : 0),
          // RAi の案内が指す名前 (D-378)。長押しは ＋ の FOW に使うので、ツールチップは長押しでは出さない。
          child: Tooltip(
            message: '作成',
            triggerMode: TooltipTriggerMode.manual,
            child: FloatingActionButton(
              heroTag: widget.heroTag,
              onPressed: () => _run(a.tap),
              shape: const CircleBorder(),
              child: const Icon(Icons.add),
            ),
          ),
        ),
        hint(a.up, above: true),
        hint(a.down, above: false),
      ]),
    );
  }
}

/// AsTell の ＋ (D-381): Swing / AsTell / RASQ に投稿(設定で出すものを選べる)。
class AstellCreateFab extends ConsumerWidget {
  const AstellCreateFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(settingsAreaProvider(fabSettingsArea)).value ?? const <String, Object?>{};
    final choices = [
      if (m['astellSwing'] != false) CreateChoice.swing,
      if (m['astellAstell'] != false) CreateChoice.astell,
      if (m['astellRasq'] != false) CreateChoice.rasq,
    ];
    return Builder(
      builder: (fabContext) => FloatingActionButton(
        // 全画面ビューワー(ルートナビゲータへ push)の Hero と衝突しないよう固有タグ (D-145)。
        heroTag: 'astell.create',
        tooltip: 'VC を作成',
        onPressed: () {
          final box = fabContext.findRenderObject() as RenderBox?;
          final anchor = box == null || !box.hasSize ? null : box.localToGlobal(Offset.zero) & box.size;
          openCreateMenu(context, ref, choices: choices.isEmpty ? const [CreateChoice.astell] : choices, anchor: anchor);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// ＋ の上に付く小さい FOW(見出しなし、幅 [createFowWidth]、高さは行の数から)。
Future<T?> _showFow<T>(WidgetRef ref, BuildContext context, {required Rect? anchor, required int rows, required Widget Function(void Function(T value) close) builder}) {
  final screen = MediaQuery.sizeOf(context).height;
  final f = ((rows * _rowHeight + RasqSpacing.md) / screen).clamp(0.1, 0.9);
  return ref.read(overlayManagerProvider).showFow<T>(
        id: createFowId,
        spec: FowSpec(
          type: FowPanelType.widget,
          initialHeightFactor: f,
          minHeightFactor: f,
          maxHeightFactor: f,
          resizable: false,
          showHandle: false,
          maxWidth: createFowWidth,
          hAlign: FowHAlign.end,
          anchor: anchor,
          anchorBelow: anchor == null ? null : false,
        ),
        semanticsLabel: '作成',
        barrierBehavior: OverlayBarrierBehavior.dismissDiscard,
        builder: (ctx, handle) => SingleChildScrollView(child: builder((v) => handle.close(result: v))),
      );
}
