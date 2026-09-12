import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import 'rai_providers.dart';

/// RAi のマスコット (D-179): ワイヤーフレーム p.4 の RAi ホーム(頭 = 耳付きの板 + 目、
/// 体 = コーン)を 2D で。gltf / three.js 相当のモーションは第一期では簡易(位置の
/// スプライン移動 + 指差し方向で少し傾く)。
class RaiMascot extends StatelessWidget {
  const RaiMascot({super.key, this.size = 96, this.tilt = 0, this.pointing});
  final double size;

  /// 傾き(ラジアン)。移動中に進行方向へ少し傾ける。
  final double tilt;

  /// 指差す方向(単位ベクトル)。null なら正面。
  final Offset? pointing;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'RAi',
        child: Transform.rotate(
          angle: tilt,
          child: CustomPaint(size: Size(size, size * 1.25), painter: _RaiMascotPainter(pointing: pointing, scheme: Theme.of(context).colorScheme)),
        ),
      );
}

class _RaiMascotPainter extends CustomPainter {
  _RaiMascotPainter({required this.pointing, required this.scheme});
  final Offset? pointing;
  final ColorScheme scheme;

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
  bool shouldRepaint(_RaiMascotPainter old) => old.pointing != pointing;
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
        child: RaiMascot(size: size * 0.55),
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

/// RAi バー (D-179 / D-180、ワイヤーフレーム p.4): 上段は**そのまま入力欄**(ヒント = 「困ったとき、
/// お手伝いします！」、質問後はその文がヒントに)。左の ^ で下段(モデルチップ / 状態リング /
/// トグル / 質問する)を畳む。「質問する」= 送信。
class RaiBar extends StatefulWidget {
  const RaiBar({super.key, required this.state, required this.onToggleExpanded, required this.onMode, required this.onSubmit, required this.onClose, this.llmNote, this.onModelTap});
  final RaiState state;

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

  void _submit() {
    final t = _input.text.trim();
    if (t.isEmpty) {
      _focus.requestFocus();
      return;
    }
    widget.onSubmit(t);
    _input.clear();
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = widget.state;
    final hint = s.query ?? '困ったとき、お手伝いします！';
    return Material(
      color: scheme.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(side: BorderSide(color: scheme.onSurface, width: 1.2), borderRadius: BorderRadius.circular(RasqSizes.radiusLg)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.sm),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // 上段: ^(畳む)+ 入力欄 + ✕。
          SizedBox(
            height: 40,
            child: Row(children: [
              RasqIconButton(key: const ValueKey('rai.headline'), icon: s.expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 22, tooltip: s.expanded ? '畳む' : '広げる', onPressed: widget.onToggleExpanded),
              Expanded(
                child: TextField(
                  key: const ValueKey('rai.input'),
                  controller: _input,
                  focusNode: _focus,
                  style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: RasqSpacing.xs, vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              RasqIconButton(icon: Icons.close, size: 18, tooltip: 'RAi を閉じる', onPressed: widget.onClose),
            ]),
          ),
          if (s.expanded)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.xs),
              child: Row(children: [
                // モデルチップ。
                Flexible(
                  child: InkWell(
                    key: const ValueKey('rai.model'),
                    onTap: widget.onModelTap,
                    borderRadius: BorderRadius.circular(RasqSizes.radiusPill),
                    child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: 6),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusPill)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(s.mode.modelIcon, size: 16),
                      const SizedBox(width: 4),
                      Flexible(child: Text(s.mode.modelName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      if (widget.llmNote != null) Padding(padding: const EdgeInsets.only(left: 4), child: Text(widget.llmNote!, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
                    ]),
                    ),
                  ),
                ),
                const SizedBox(width: RasqSpacing.sm),
                RaiStatusRing(busy: s.busy, error: s.error),
                const SizedBox(width: RasqSpacing.sm),
                RaiModeToggle(mode: s.mode, onChanged: widget.onMode),
                const SizedBox(width: RasqSpacing.sm),
                FilledButton(
                  key: const ValueKey('rai.ask'),
                  onPressed: _submit,
                  style: FilledButton.styleFrom(backgroundColor: RasqColors.link, foregroundColor: Colors.white, minimumSize: const Size(0, 34), padding: const EdgeInsets.symmetric(horizontal: 14), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('質問する'),
                ),
              ]),
            ),
        ]),
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
  const RaiSpeech({super.key, required this.line, required this.index, required this.count, required this.hasMore, required this.streaming, required this.onNext, required this.onClose, this.error = false});
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
                child: Text(line, key: const ValueKey('rai.bubble'), style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
          if (count > 1 || streaming) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text(streaming ? '${index + 1}/$count…' : '${index + 1}/$count', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))),
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
Offset raiAnchorFor(Rect target, Size screen, {double mascot = 72, double reservedBottom = 180}) {
  final gap = 12.0;
  final left = Offset(target.left - gap - mascot / 2, target.center.dy);
  final right = Offset(target.right + gap + mascot / 2, target.center.dy);
  final top = Offset(target.center.dx, target.top - gap - mascot * 0.7);
  final bottom = Offset(target.center.dx, target.bottom + gap + mascot * 0.7);
  final lowOnScreen = target.center.dy > screen.height - reservedBottom - mascot;
  final candidates = lowOnScreen ? [top, left, right, bottom] : [left, right, top, bottom];
  for (final c in candidates) {
    if (c.dx - mascot / 2 >= 0 && c.dx + mascot / 2 <= screen.width && c.dy - mascot * 0.7 >= 0 && c.dy + mascot * 0.7 <= screen.height - reservedBottom) return c;
  }
  return Offset(screen.width / 2, math.max(mascot, target.top - gap - mascot * 0.7));
}
