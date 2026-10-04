import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:rasq_design/rasq_design.dart';

import '../ads/export_ad.dart';

import 'rai_mascot_3d.dart';
import 'rai_providers.dart';

/// RAi のマスコット (D-179): ワイヤーフレーム p.4 の RAi ホーム(頭 = 耳付きの板 + 目、
/// 体 = コーン)を 2D で。gltf / three.js 相当のモーションは第一期では簡易(位置の
/// スプライン移動 + 指差し方向で少し傾く)。
class RaiMascot extends ConsumerWidget {
  const RaiMascot({super.key, this.size = 96, this.tilt = 0, this.pointing, this.controller3d, this.opacity = 1, this.flat = false});
  final double size;

  /// 常に 2D で描く (D-202): 小さいアイコン用。three_js のインスタンスを増やすと空間モードの描画が壊れる。
  final bool flat;

  /// 薄く表示(アシスタントのスタンバイ)。
  final double opacity;

  /// 傾き(ラジアン)。移動中に進行方向へ少し傾ける(2D のとき)。
  final double tilt;

  /// 指差す方向(単位ベクトル)。null なら正面(2D のとき)。
  final Offset? pointing;

  /// 3D (D-191) のクリップ制御。null なら静止(idle)。
  final RaiMascot3dController? controller3d;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final three = !flat && ref.watch(raiMascot3dProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'RAi',
      child: three
          ? RaiMascot3d(size: size, controller: controller3d, opacity: opacity, outline: dark ? Colors.white.withValues(alpha: 0.85) : null)
          : Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: tilt,
                child: CustomPaint(size: Size(size, size * 1.25), painter: _RaiMascotPainter(pointing: pointing, scheme: Theme.of(context).colorScheme, outline: dark)),
              ),
            ),
    );
  }
}

class _RaiMascotPainter extends CustomPainter {
  _RaiMascotPainter({required this.pointing, required this.scheme, this.outline = false});
  final Offset? pointing;
  final ColorScheme scheme;

  /// ダークモードの縁取り (D-192)。
  final bool outline;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    // 体: コーン + 台座(サーモン)。
    final cone = Paint()..color = RasqColors.salmon.withValues(alpha: 0.8);
    final base = Path()..addOval(Rect.fromCenter(center: Offset(cx, h * 0.93), width: w * 0.62, height: h * 0.11));
    canvas.drawPath(base, cone);
    final body = Path()
      ..moveTo(cx - w * 0.07, h * 0.52)
      ..lineTo(cx + w * 0.07, h * 0.52)
      ..lineTo(cx + w * 0.16, h * 0.92)
      ..lineTo(cx - w * 0.16, h * 0.92)
      ..close();
    if (outline) {
      // ダークモード: 外形(台座 / 体 / 耳 / 頭)を白で縁取る。
      final rim = Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.05
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(base, rim);
      canvas.drawPath(body, rim);
      canvas.drawCircle(Offset(cx - w * 0.36, h * 0.12), w * 0.11, rim);
      canvas.drawCircle(Offset(cx + w * 0.36, h * 0.12), w * 0.11, rim);
      final dx0 = (pointing?.dx ?? 0) * w * 0.04;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.44 + dx0, h * 0.1, w * 0.88, h * 0.4), Radius.circular(w * 0.07)), rim);
    }
    canvas.drawPath(body, cone);
    // 耳。
    final ear = Paint()..color = const Color(0xFFEDEDED);
    canvas.drawCircle(Offset(cx - w * 0.36, h * 0.12), w * 0.11, ear);
    canvas.drawCircle(Offset(cx + w * 0.36, h * 0.12), w * 0.11, ear);
    // 頭: 白い板 + グレーの画面。指差し方向へ少し寄せる。
    final dx = (pointing?.dx ?? 0) * w * 0.04;
    final head = RRect.fromRectAndRadius(Rect.fromLTWH(cx - w * 0.44 + dx, h * 0.1, w * 0.88, h * 0.4), Radius.circular(w * 0.07));
    canvas.drawRRect(head, Paint()..color = Colors.white);
    canvas.drawRRect(head, Paint()..color = const Color(0xFFBDBDBD)..style = PaintingStyle.stroke..strokeWidth = 1.2);
    final screen = RRect.fromRectAndRadius(head.outerRect.deflate(w * 0.05), Radius.circular(w * 0.04));
    canvas.drawRRect(screen, Paint()..color = const Color(0xFFCFCFCF));
    // 目(白い楕円、指差し方向へ寄る)。
    final ex = (pointing?.dx ?? 0) * w * 0.03;
    final ey = (pointing?.dy ?? 0) * h * 0.02;
    final eye = Paint()..color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx - w * 0.17 + ex + dx, h * 0.3 + ey), width: w * 0.1, height: h * 0.11), eye);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + w * 0.17 + ex + dx, h * 0.3 + ey), width: w * 0.1, height: h * 0.11), eye);
  }

  @override
  bool shouldRepaint(_RaiMascotPainter old) => old.pointing != pointing || old.outline != outline;
}

/// RAi の小さいアイコン(黄色い丸に RAi の頭、吹き出しの左)。
class RaiIcon extends StatelessWidget {
  const RaiIcon({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: RasqColors.yellow, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: RaiMascot(size: size * 0.55, flat: true),
      );
}

/// モード切替トグル (D-179): 緑 = インストラクション(ノブは指差しのピン)、
/// 紺 = アシスタント(ノブは吹き出し)。ノブ内のアイコンはフェードで入れ替わる。
class RaiModeToggle extends StatelessWidget {
  const RaiModeToggle({super.key, required this.mode, required this.onChanged});
  final RaiMode mode;
  final ValueChanged<RaiMode> onChanged;

  static const _w = 58.0;
  static const _h = 30.0;

  @override
  Widget build(BuildContext context) {
    final instruction = mode == RaiMode.instruction;
    return Semantics(
      label: 'RAi モード',
      value: mode.label,
      toggled: instruction,
      button: true,
      child: GestureDetector(
        key: const ValueKey('rai.toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(instruction ? RaiMode.assistant : RaiMode.instruction),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: _w,
          height: _h,
          decoration: BoxDecoration(color: instruction ? RasqColors.inVc : RasqColors.navy, borderRadius: BorderRadius.circular(_h / 2)),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: instruction ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: _h - 4,
              height: _h - 4,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: SizedBox.expand(
                  key: ValueKey(mode),
                  child: CustomPaint(painter: instruction ? const RaiPointerIconPainter(color: RasqColors.navy) : const RaiBubbleIconPainter(color: RasqColors.navy)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// トグルの「指差し」アイコン(丸 + 斜めの棒。添付画像の形)。
class RaiPointerIconPainter extends CustomPainter {
  const RaiPointerIconPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.11
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width * 0.62, size.height * 0.36);
    canvas.drawCircle(c, s * 0.14, p);
    canvas.drawLine(c + Offset(-s * 0.1, s * 0.1), Offset(size.width * 0.28, size.height * 0.74), p);
  }

  @override
  bool shouldRepaint(RaiPointerIconPainter old) => old.color != color;
}

/// トグルの「吹き出し」アイコン(角丸の四角 + 右下のしっぽ。添付画像の形)。
class RaiBubbleIconPainter extends CustomPainter {
  const RaiBubbleIconPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final r = Rect.fromLTWH(size.width * 0.22, size.height * 0.26, size.width * 0.56, size.height * 0.4);
    final body = Path()..addRRect(RRect.fromRectAndRadius(r, Radius.circular(s * 0.1)));
    final tail = Path()
      ..moveTo(r.right - s * 0.16, r.bottom - 1)
      ..lineTo(r.right - s * 0.06, r.bottom + s * 0.12)
      ..lineTo(r.right - s * 0.04, r.bottom - 1)
      ..close();
    final fill = Paint()..color = color..style = PaintingStyle.fill;
    canvas.drawPath(Path.combine(PathOperation.union, body, tail), fill);
    // 中を抜いて枠だけに(添付の白抜き)。
    canvas.drawRRect(RRect.fromRectAndRadius(r.deflate(s * 0.09), Radius.circular(s * 0.05)), Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(RaiBubbleIconPainter old) => old.color != color;
}

/// 状態リング: 待機は青い輪、処理中は回る。
class RaiStatusRing extends StatelessWidget {
  const RaiStatusRing({super.key, required this.busy, this.error = false});
  final bool busy;

  /// 直近が失敗表示(赤い輪)。
  final bool error;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 24,
        height: 24,
        child: busy
            ? const CircularProgressIndicator(strokeWidth: 3, color: RasqColors.link)
            : Container(key: ValueKey(error ? 'rai.ring.error' : 'rai.ring.idle'), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: error ? RasqColors.danger : RasqColors.link, width: 3))),
      );
}

/// RAi バーのモデルのチップ(アイコン + モデル名 + 注記)。[onTap] が null なら押せない(クラウド版の表示だけ)。
class RaiModelChip extends StatelessWidget {
  const RaiModelChip({super.key, required this.icon, required this.label, this.note, this.onTap});
  final IconData icon;
  final String label;
  final String? note;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RasqSizes.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 6),
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusPill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
          if (note != null) Padding(padding: const EdgeInsets.only(left: 4), child: Text(note!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
        ]),
      ),
    );
  }
}

/// RAi バーの「質問する」。
class RaiAskButton extends StatelessWidget {
  const RaiAskButton({super.key, required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(backgroundColor: RasqColors.link, foregroundColor: Colors.white, minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: const Text('質問する'),
      );
}

/// RAi バーの枠(角丸 + 線 + 影)。
ShapeBorder raiBarShape(ColorScheme scheme) => RoundedRectangleBorder(side: BorderSide(color: scheme.onSurface, width: 1.2), borderRadius: BorderRadius.circular(RasqSizes.radiusLg));

/// 会話だけの RAi の入力 (D-427): RAi バーと同じ見た目(上段 = 入力欄、下段 = モデルのチップ / 状態リング / 「質問する」)で、
/// 案内 / モードの切り替え / 履歴は持たない。オンボーディングの「RAi に聞く」(クラウドの RAi)で使う。
class RaiPromptBar extends StatelessWidget {
  const RaiPromptBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.modelLabel,
    this.busy = false,
    this.error = false,
    this.hint = '困ったとき、お手伝いします！',
    this.maxLength,
    this.inputKey,
    this.sendKey,
    this.onChanged,
  });
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final String modelLabel;
  final bool busy;
  final bool error;
  final String hint;
  final int? maxLength;
  final Key? inputKey;
  final Key? sendKey;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canSend = !busy && controller.text.trim().isNotEmpty;
    return Material(
      color: scheme.surface,
      elevation: 6,
      shape: raiBarShape(scheme),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextField(
            key: inputKey,
            controller: controller,
            style: RasqTypography.bodySmall,
            minLines: 1,
            maxLines: 4,
            maxLength: maxLength,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: RasqTypography.bodySmall.copyWith(color: scheme.onSurface),
              hintMaxLines: 1,
              isDense: true,
              // テーマの下線は出さない(RAi バーと同じく、枠はバーそのもの)。
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xs, vertical: 10),
            ),
            textInputAction: TextInputAction.send,
            onChanged: onChanged,
            onSubmitted: (_) => canSend ? onSubmit() : null,
          ),
          const SizedBox(height: RasqSpacing.xs),
          Row(children: [
            Expanded(child: Align(alignment: Alignment.centerLeft, child: RaiModelChip(icon: Icons.cloud_outlined, label: modelLabel))),
            const SizedBox(width: RasqSpacing.sm),
            RaiStatusRing(busy: busy, error: error),
            const SizedBox(width: RasqSpacing.sm),
            RaiAskButton(key: sendKey, onPressed: canSend ? onSubmit : null),
          ]),
        ]),
      ),
    );
  }
}

/// RAi バー (D-179 / D-180、ワイヤーフレーム p.4): 上段は**そのまま入力欄**(ヒント = 「困ったとき、
/// お手伝いします！」、質問後はその文がヒントに)。左の ^ で下段(モデルチップ / 状態リング /
/// トグル / 質問する)を畳む。「質問する」= 送信。
/// RAi バーの BuildContext(モデル FOW をこの上に付ける、D-192)。GlobalKey は使わない(D-199: 再親付けで
/// `_elements.contains(element)` の assert を踏むため)。バーの build のたびに差し替わる。
BuildContext? raiBarContext;

class RaiBar extends StatefulWidget {
  const RaiBar({super.key, required this.state, required this.onToggleExpanded, required this.onMode, required this.onSubmit, required this.onClose, this.llmNote, this.onModelTap, this.onHistoryToggle, this.historyMaxHeight = 320, this.onSuggest, this.onPredict, this.modelLabel, this.onAskMore, this.onDragUpdate, this.onDragEnd});
  final RaiState state;

  /// 掴んで移動 (D-233): 左上の掴み手をドラッグ。大きさは変えない。null なら掴み手を出さない。
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  /// チップの表記(選択中モデルのコードネーム、D-198)。null なら既定。
  final String? modelLabel;

  /// 薄い補完 (D-194): 入力から候補の見出しを返す(null = 無し)。半角 / 全角スペースで確定。
  final String? Function(String typed)? onSuggest;

  /// 空の入力欄に薄く出す予測 (D-376): 履歴 / 直前の操作から。スペースで入る。null なら既定のヒント。
  final String? Function()? onPredict;

  /// 履歴ボタン (D-187): ウィジェットが上に広がって発言の履歴(コピー付き)が出る。
  final VoidCallback? onHistoryToggle;

  /// 「さらに尋ねる」(D-219): 進行中の案内を打ち切って入力に戻る。案内中だけ出す。
  final VoidCallback? onAskMore;
  final double historyMaxHeight;

  /// モデルチップのタップ → モデル FOW (D-183)。
  final VoidCallback? onModelTap;

  /// 端末内モデルの状態の短い注記(「未DL」「読み込み中」「45%」など。準備できていれば null)。
  final String? llmNote;
  final VoidCallback onToggleExpanded;
  final ValueChanged<RaiMode> onMode;
  final ValueChanged<String> onSubmit;
  final VoidCallback onClose;

  @override
  State<RaiBar> createState() => _RaiBarState();
}

class _RaiBarState extends State<RaiBar> {
  final _input = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.state.asking) WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void didUpdateWidget(RaiBar old) {
    super.didUpdateWidget(old);
    if (widget.state.asking && !old.state.asking) _focus.requestFocus();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  String? _ghost;

  /// 空の入力欄の予測(build で引く)。
  String? _predicted;

  /// 入力のたびに候補を引く。末尾に半角 / 全角スペースが入ったら候補で確定する。
  /// 空の入力欄でスペースを打つと、予測([RaiBar.onPredict])で埋める (D-376)。
  void _onChanged(String text) {
    if ((text == ' ' || text == '　') && _predicted != null) {
      final p = _predicted!;
      _input.value = TextEditingValue(text: p, selection: TextSelection.collapsed(offset: p.length));
      setState(() => _ghost = null);
      return;
    }
    if (_ghost != null && (text.endsWith(' ') || text.endsWith('　')) && _ghost!.startsWith(text.substring(0, text.length - 1))) {
      final g = _ghost!;
      _input.value = TextEditingValue(text: g, selection: TextSelection.collapsed(offset: g.length));
      setState(() => _ghost = null);
      return;
    }
    final next = text.trim().isEmpty ? null : widget.onSuggest?.call(text);
    if (next != _ghost) setState(() => _ghost = next);
  }

  void _submit() {
    final t = _input.text.trim();
    if (t.isEmpty) {
      _focus.requestFocus();
      return;
    }
    widget.onSubmit(t);
    _input.clear();
    _ghost = null;
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    raiBarContext = context;
    final scheme = Theme.of(context).colorScheme;
    final s = widget.state;
    // 入力欄は前の質問で埋めない (D-376): 空のときは予測を薄く出し、スペースで入れる。予測が無ければ既定のヒント。
    _predicted = _input.text.isEmpty ? widget.onPredict?.call() : null;
    final hint = _predicted != null ? '$_predicted(スペースで入力)' : '困ったとき、お手伝いします！';
    // 掴んで移動 (D-233 → D-236): FOW と同じく**タイル全体**が移動判定(掴み手は無し)。入力欄やボタンは
    // 自分のジェスチャを優先する。
    return GestureDetector(
      key: const ValueKey('rai.bar'),
      behavior: HitTestBehavior.translucent,
      onPanUpdate: widget.onDragUpdate == null ? null : (d) => widget.onDragUpdate!(d.delta),
      onPanEnd: widget.onDragEnd == null ? null : (_) => widget.onDragEnd!(),
      onPanCancel: widget.onDragEnd,
      child: Material(
      color: scheme.surface,
      elevation: 6,
      shape: raiBarShape(scheme),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 履歴 (D-187): 入力欄の上に広がる。
          if (s.historyOpen)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.historyMaxHeight),
              child: RaiHistoryList(log: s.log),
            ),
          if (s.historyOpen) Divider(height: 1, color: scheme.outlineVariant),
          // 上段: ^(畳む)+ 入力欄 + 履歴 + ✕。
          SizedBox(
            height: 40,
            child: Row(children: [
              RasqIconButton(key: const ValueKey('rai.headline'), icon: s.expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 22, tooltip: s.expanded ? '畳む' : '広げる', onPressed: widget.onToggleExpanded),
              Expanded(
                child: Stack(children: [
                  // 薄い補完 (D-194): 入力の後ろに候補の見出しを薄く敷く。
                  if (_ghost != null)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xs, vertical: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(_ghost!, key: const ValueKey('rai.ghost'), maxLines: 1, overflow: TextOverflow.clip, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.55))),
                        ),
                      ),
                    ),
                  TextField(
                    key: const ValueKey('rai.input'),
                    controller: _input,
                    focusNode: _focus,
                    style: RasqTypography.bodySmall,
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: RasqTypography.bodySmall.copyWith(color: _predicted != null ? scheme.onSurfaceVariant.withValues(alpha: 0.55) : scheme.onSurface),
                      hintMaxLines: 1,
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xs, vertical: 10),
                    ),
                    textInputAction: TextInputAction.send,
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                  ),
                ]),
              ),
              // 案内の途中 (D-219): 上段に「さらに尋ねる」= 案内を打ち切って入力へ(入力欄は Expanded なので詰まる)。
              if (widget.onAskMore != null && s.mode == RaiMode.instruction && (s.steps.isNotEmpty || s.target != null))
                TextButton(
                  key: const ValueKey('rai.askMore'),
                  onPressed: widget.onAskMore,
                  style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: VisualDensity.compact),
                  child: Text('さらに尋ねる', style: RasqTypography.bodySmall.copyWith(color: RasqColors.link, fontWeight: FontWeight.w600)),
                ),
              RasqIconButton(key: const ValueKey('rai.history'), icon: s.historyOpen ? Icons.expand_more : Icons.history, size: 20, tooltip: s.historyOpen ? '履歴を閉じる' : '発言の履歴', onPressed: widget.onHistoryToggle),
              RasqIconButton(icon: Icons.close, size: 18, tooltip: 'RAi を閉じる', onPressed: widget.onClose),
            ]),
          ),
          if (s.expanded)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.xs),
              child: Row(children: [
                // モデルチップは左寄せの自然幅、状態リング / モードトグル / 質問する は常に右付き (D-237)。
                Expanded(
                  child: Align(
                  alignment: Alignment.centerLeft,
                  child: RaiModelChip(key: const ValueKey('rai.model'), icon: s.mode.modelIcon, label: widget.modelLabel ?? s.mode.modelName, note: widget.llmNote, onTap: widget.onModelTap),
                  ),
                ),
                const SizedBox(width: RasqSpacing.sm),
                RaiStatusRing(busy: s.busy, error: s.error),
                const SizedBox(width: RasqSpacing.sm),
                RaiModeToggle(mode: s.mode, onChanged: widget.onMode),
                const SizedBox(width: RasqSpacing.sm),
                RaiAskButton(key: const ValueKey('rai.ask'), onPressed: _submit),
              ]),
            ),
          // クラウドで推論している間だけ、広告の枠 (D-377)。出せない端末 / 見守りのアカウント / 狭いバーでは何も出さない。
          if (s.cloudBusy) const Center(key: ValueKey('rai.ad'), child: ExportAdSlot()),
        ]),
      ),
      ),
    );
  }
}

/// RAi の発言を行に割る (D-182): 改行と文末(。！？!?)で切り、空行は捨てる。
List<String> splitSpeechLines(String text) {
  final out = <String>[];
  for (final para in text.split('\n')) {
    final buf = StringBuffer();
    for (final ch in para.split('')) {
      buf.write(ch);
      if ('。！？!?'.contains(ch)) {
        final t = buf.toString().trim();
        if (t.isNotEmpty) out.add(t);
        buf.clear();
      }
    }
    final rest = buf.toString().trim();
    if (rest.isNotEmpty) out.add(rest);
  }
  return out;
}

/// RAi の発言 (D-182、ワイヤーフレーム p.4): 入力ウィジェット(バー)の上に**1 行ずつ**。
/// 左に RAi アイコン、右に n/m と ▶(次の行 / 次の手順)、✕。
class RaiSpeech extends StatelessWidget {
  const RaiSpeech({super.key, required this.line, required this.index, required this.count, required this.hasMore, required this.streaming, required this.onNext, required this.onClose, this.error = false, this.onHistory});
  final String line;
  final int index;
  final int count;

  /// ▶ で先がある(次の行 / 次の手順)。
  final bool hasMore;

  /// まだ生成中(行が増える)。
  final bool streaming;
  final bool error;
  final VoidCallback onNext;
  final VoidCallback onClose;

  /// ↑: 発言の履歴 FOW (D-185)。
  final VoidCallback? onHistory;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      elevation: 4,
      shape: RoundedRectangleBorder(side: BorderSide(color: error ? RasqColors.danger : scheme.onSurface, width: 1.2), borderRadius: BorderRadius.circular(RasqSizes.radiusLg)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.xs, RasqSpacing.xs),
        child: Row(children: [
          const RaiIcon(size: 36),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: hasMore ? onNext : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                // 高さは可変 (D-185): 長いエラー文も全部見える。
                child: Text(line, key: const ValueKey('rai.bubble'), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          if (count > 1 || streaming) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(streaming ? '${index + 1}/$count…' : '${index + 1}/$count', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
          RasqIconButton(key: const ValueKey('rai.speech.history'), icon: Icons.arrow_upward, size: 20, tooltip: '発言の履歴', onPressed: onHistory),
          RasqIconButton(key: const ValueKey('rai.next'), icon: hasMore ? Icons.play_arrow : Icons.check, size: 22, tooltip: hasMore ? '次へ' : '了解(閉じる)', onPressed: onNext),
          RasqIconButton(key: const ValueKey('rai.speech.close'), icon: Icons.close, size: 18, tooltip: '閉じる', onPressed: onClose),
        ]),
      ),
    );
  }
}

/// 指差しの方向: RAi から見た目標の向き(単位ベクトル)。
Offset pointingDirection(Offset from, Offset to) {
  final d = to - from;
  final len = d.distance;
  return len < 1 ? Offset.zero : d / len;
}

/// 目標の矩形に対して RAi を置く位置(上下左右の空いている側)。画面下の [reservedBottom]
/// (RAi バー + フッター)には置かない — 下の方の部品は上側から指差す。
/// RAi の箱(mascot × 1.25)のうち、左右の透明な余白の割合 (D-196: 体が部品の端に付くように、この分だけ寄せる)。
const raiBodyInset = 0.22;

/// 目標の矩形に対して RAi を置く位置(上下左右の空いている側)。体が部品の端に**付く**ように、箱の余白ぶん寄せる (D-196)。
/// 画面下の [reservedBottom](RAi バー + フッター)には置かない — 下の方の部品は上側から指差す。
Offset raiAnchorFor(Rect target, Size screen, {double mascot = 72, double reservedBottom = 180}) => raiPlaceFor(target, screen, mascot: mascot, reservedBottom: reservedBottom).pos;

/// 置き場所 (D-203): 上下左右に空きが無ければ [cramped](半透明で出す)。そのときは優先順の先頭の側へ、
/// **胴体(頭 + コーン)が画面に完全に入る**ところまで寄せる(手とアンテナははみ出してよい)。
/// 目標の下側に空きが無いときは [armsDown](手を下ろした静止)。
typedef RaiPlacement = ({Offset pos, bool cramped, bool armsDown});

RaiPlacement raiPlaceFor(Rect target, Size screen, {double mascot = 72, double reservedBottom = 180}) {
  final inset = mascot * raiBodyInset;
  final left = Offset(target.left - mascot / 2 + inset, target.center.dy);
  final right = Offset(target.right + mascot / 2 - inset, target.center.dy);
  final top = Offset(target.center.dx, target.top - mascot * 0.7 + inset * 0.5);
  final bottom = Offset(target.center.dx, target.bottom + mascot * 0.7 - inset * 0.5);
  final lowOnScreen = target.center.dy > screen.height - reservedBottom - mascot;
  final candidates = lowOnScreen ? [top, left, right, bottom] : [left, right, top, bottom];
  for (final c in candidates) {
    if (c.dx - mascot / 2 + inset >= 0 && c.dx + mascot / 2 - inset <= screen.width && c.dy - mascot * 0.7 >= 0 && c.dy + mascot * 0.7 <= screen.height - reservedBottom) {
      return (pos: c, cramped: false, armsDown: false);
    }
  }
  // 空きが無い: 胴体(腕を除く半幅 0.28、アンテナを除く上 0.5、下 0.625)が入るところまで寄せる。
  final c = candidates.first;
  final halfW = mascot * 0.28;
  final up = mascot * 0.5;
  final down = mascot * 0.625;
  final x = c.dx.clamp(halfW, math.max(halfW, screen.width - halfW)).toDouble();
  final y = c.dy.clamp(up, math.max(up, screen.height - reservedBottom - down)).toDouble();
  final roomBelow = target.bottom + mascot * 1.4 <= screen.height - reservedBottom;
  return (pos: Offset(x, y), cramped: true, armsDown: !roomBelow);
}

/// 発言の履歴 (D-187): タイル = 全文(選択可)+ Q + 時刻、コピー。失敗は赤枠。新しい順。
class RaiHistoryList extends StatelessWidget {
  const RaiHistoryList({super.key, required this.log});
  final List<RaiUtterance> log;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (log.isEmpty) {
      return Padding(padding: const EdgeInsets.all(RasqSpacing.md), child: Text('まだ発言はありません', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)));
    }
    return ListView.builder(
      key: const ValueKey('rai.history.list'),
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(0, RasqSpacing.xs, 0, RasqSpacing.xs),
      itemCount: log.length,
      itemBuilder: (context, i) {
        final u = log[i];
        return Container(
          key: ValueKey('rai.history.$i'),
          margin: const EdgeInsets.only(bottom: RasqSpacing.xs),
          padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, 0, RasqSpacing.xs),
          decoration: BoxDecoration(color: scheme.surfaceContainerLow, borderRadius: BorderRadius.circular(RasqSizes.radiusMd), border: Border.all(color: u.error ? RasqColors.danger : scheme.outlineVariant)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const RaiIcon(size: 28),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (u.query != null) Text('Q: ${u.query}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                SelectableText(u.text, style: RasqTypography.bodySmall),
                Text(RasqTimestamp.format(u.at), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ]),
            ),
            RasqIconButton(
              key: ValueKey('rai.history.copy.$i'),
              icon: Icons.copy,
              size: 18,
              tooltip: 'コピー',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: u.text));
                if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('コピーしました')));
              },
            ),
          ]),
        );
      },
    );
  }
}
