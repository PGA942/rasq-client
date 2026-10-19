import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';
import 'tendency_profile.dart';

/// 指向性 / 刺激性の欄 (D-518)。トレンドの傾向 FOW([openTendencyFow]、D-153 / D-470)とユーザーページのタブの「ノートの表示」
/// (D-514)で**同じ部品**を使う。左(上)= 指向性(スライダーの行 + [directivityExtra])、右(下)= 刺激性(レーダー + 感情ごとの
/// 上限のチップ + 「刺激性をリセット」)。
///
/// **幅で並べ方を変える**: 幅が [tendencyStackBreakpoint] 未満なら縦に積む(指向性の下に刺激性。レーダーは横いっぱいに近い
/// 大きさ)、以上なら横に 2 カラム(D-470 の比: [tendencyWideBreakpoint] 以上は [tendencyWideSplit]、それ未満は
/// [tendencyNarrowSplit])。
///
/// レーダーは触れた時点でドラッグを取る(`claimDrag`。スクロールする FOW / シートの中で縦に動かした指を取られないように)。
/// 指が触れている間を知りたいとき(ページの横のスワイプを止める、D-514)は [onHold]。
class TendencyControls extends StatelessWidget {
  const TendencyControls({
    super.key,
    required this.directionality,
    required this.onDirectionality,
    required this.stimulusCap,
    required this.onStimulus,
    required this.directivityTitle,
    required this.stimulusTitle,
    this.directivitySubtitle,
    this.directivityDetail,
    this.directivityExtra = const [],
    this.onStimulusReset,
    this.onHold,
    this.radarKey = const Key('trend.stimulus.radar'),
    this.keyPrefix = 'trend.tendency',
  });

  /// 0(狭い)〜1(広い)。
  final double directionality;
  final ValueChanged<double> onDirectionality;

  /// 感情 → 上限 0〜1。
  final double Function(String emotion) stimulusCap;
  final void Function(String emotion, double cap) onStimulus;

  final String directivityTitle;
  final String? directivitySubtitle;
  final String? directivityDetail;

  /// 指向性の下に足す行(トレンドの「設定を共有」など)。
  final List<Widget> directivityExtra;
  final String stimulusTitle;

  /// 「刺激性をリセット」(null なら出さない)。戻す先は呼ぶ側が決める(トレンド = 既定の 45%、ノートの表示 = 制限なし)。
  final VoidCallback? onStimulusReset;

  /// 指が欄に触れた(true)/ 離れた(false)。
  final ValueChanged<bool>? onHold;
  final Key radarKey;

  /// 欄のキーの頭(`$keyPrefix.columns` / `.directivity` / `.stimulus` / `.slider`)。
  final String keyPrefix;

  static String directionLabel(double v) => v <= 0.25 ? appL10n.trendProfileDirNarrow : v >= 0.75 ? appL10n.trendProfileDirWide : appL10n.trendProfileDirNormal;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final directivity = Column(key: Key('$keyPrefix.directivity'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KeyedSubtree(
        key: Key('$keyPrefix.slider'),
        child: RasqSliderListTile(
          title: directivityTitle,
          subtitle: directivitySubtitle,
          detail: directivityDetail,
          value: directionality,
          min: 0,
          max: 1,
          divisions: 10,
          valueLabel: directionLabel(directionality),
          onChanged: onDirectionality,
        ),
      ),
      ...directivityExtra,
    ]);
    Widget stimulus({required double width, required bool stacked}) => Container(
          key: Key('$keyPrefix.stimulus'),
          // 横並びは左に縦の線、縦積みは上に横の線(指向性との区切り)。
          // 縦積みで指向性の最後の行が線を持つ(「設定を共有」の行)なら、線を重ねない。
          decoration: BoxDecoration(border: stacked ? (directivityExtra.isEmpty ? Border(top: BorderSide(color: scheme.outlineVariant)) : null) : Border(left: BorderSide(color: scheme.outlineVariant))),
          padding: stacked ? const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0) : const EdgeInsets.symmetric(horizontal: RasqSpacing.xs),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(stimulusTitle, style: RasqTypography.listTile)),
            Text(l.trendProfileStimulusCaption, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: RasqSpacing.xs),
            Center(
              child: RasqRadarChart(
                key: radarKey,
                size: math.max(96, math.min(width - (stacked ? RasqSpacing.page * 2 : RasqSpacing.xs * 2), stacked ? 200 : 240)),
                claimDrag: true,
                axes: TendencyProfile.emotions,
                values: {for (final e in TendencyProfile.emotions) e: stimulusCap(e)},
                labels: TendencyProfile.emotionLabels,
                onChanged: onStimulus,
              ),
            ),
            const SizedBox(height: RasqSpacing.xs),
            Wrap(alignment: stacked ? WrapAlignment.center : WrapAlignment.start, spacing: 4, runSpacing: 4, children: [
              for (final e in TendencyProfile.emotions) TendencyStimulusChip(label: TendencyProfile.emotionLabels[e]!, cap: stimulusCap(e)),
            ]),
            if (onStimulusReset != null)
              Align(
                alignment: Alignment.centerRight,
                // 細いカラムでは折り返さずに縮める。
                child: TextButton(key: Key('$keyPrefix.stimulusReset'), onPressed: onStimulusReset, child: FittedBox(fit: BoxFit.scaleDown, child: Text(l.trendProfileStimulusReset, maxLines: 1))),
              ),
          ]),
        );
    final body = LayoutBuilder(builder: (context, c) {
      if (c.maxWidth < tendencyStackBreakpoint) {
        return Column(key: Key('$keyPrefix.stacked'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          directivity,
          const SizedBox(height: RasqSpacing.xs),
          stimulus(width: c.maxWidth, stacked: true),
        ]);
      }
      final split = c.maxWidth >= tendencyWideBreakpoint ? tendencyWideSplit : tendencyNarrowSplit;
      return Row(key: Key('$keyPrefix.columns'), crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: split.$1, child: directivity),
        Expanded(flex: split.$2, child: stimulus(width: c.maxWidth * split.$2 / (split.$1 + split.$2), stacked: false)),
      ]);
    });
    final hold = onHold;
    if (hold == null) return body;
    return Listener(
      key: Key('$keyPrefix.hold'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => hold(true),
      onPointerUp: (_) => hold(false),
      onPointerCancel: (_) => hold(false),
      child: body,
    );
  }
}

/// 指向性 / 刺激性の欄を縦に積む幅 (D-518)。これ未満(スマホの幅のシート・ボタンにつながったパネル)は、刺激性を指向性の下に。
const tendencyStackBreakpoint = 480.0;

/// 横並びのときの指向性 / 刺激性のカラムの幅の比 (D-470)。
const tendencyNarrowSplit = (62, 38);
const tendencyWideSplit = (60, 40);

/// これ以上の幅なら、刺激性のカラムを広げてレーダーを大きく。
const tendencyWideBreakpoint = 600.0;

/// 刺激性の 1 感情の上限(小さく。抑えているものは赤)。
class TendencyStimulusChip extends StatelessWidget {
  const TendencyStimulusChip({super.key, required this.label, required this.cap});
  final String label;
  final double cap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final limited = cap < 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: limited ? RasqColors.danger : scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)),
      child: Text('$label ${(cap * 100).round()}%', style: RasqTypography.caption.copyWith(fontSize: 11, color: limited ? Colors.white : scheme.onSurface)),
    );
  }
}
