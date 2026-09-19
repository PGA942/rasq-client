import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import 'audio_visualizer_video.dart';

/// Visualizer の設定 FOW (D-251): 加工画面の下段バーの「Visualizer」から。値を変えると**今の再生位置のフレーム**を
/// その場で描き直す(書き出しと同じ [paintAudioFrame])。「決定」で設定を返す(呼び出し元が動画を書き出し直す)。
const audioVisualizerFowId = 'media.pro.visualizer';
const audioVisualizerPreviewKey = Key('media.pro.visualizer.preview');

/// 保存先(端末ごと、全アカウント共通)。
const audioVisualizerStorageKey = 'editor.audioVisualizer.v1';

const _backgrounds = <(String, Color)>[('黒', Color(0xFF000000)), ('濃紺', Color(0xFF0B1020)), ('墨', Color(0xFF16181C)), ('深緑', Color(0xFF06231B)), ('えんじ', Color(0xFF2A0A12)), ('白', Color(0xFFFFFFFF))];
const _barColors = <(String, Color)>[('青', Color(0xFF4F8DFD)), ('水色', Color(0xFF35C9E8)), ('緑', Color(0xFF3DDC84)), ('黄', Color(0xFFFFD54F)), ('橙', Color(0xFFFF8A3D)), ('桃', Color(0xFFFF5C8A)), ('紫', Color(0xFFA27BFF)), ('白', Color(0xFFFFFFFF))];

Future<AudioVisualizerConfig?> showAudioVisualizerFow(OverlayManager manager, {required AudioVisualizerConfig initial, required AudioPcm? pcm, required Duration position, String? title}) async {
  if (manager.contains(audioVisualizerFowId)) return null;
  var config = initial;
  final ok = await manager.showFow<bool>(
    id: audioVisualizerFowId,
    spec: FowSpec(title: 'Visualizer', cancelText: 'キャンセル', confirmText: '決定', initialHeightFactor: 0.8, maxHeightFactor: 0.92, maxWidth: 640),
    semanticsLabel: 'Visualizer の設定',
    builder: (_, _) => _Body(initial: initial, pcm: pcm, position: position, title: title, onChanged: (c) => config = c),
  );
  return ok == true ? config : null;
}

class _Body extends StatefulWidget {
  const _Body({required this.initial, required this.pcm, required this.position, required this.title, required this.onChanged});
  final AudioVisualizerConfig initial;
  final AudioPcm? pcm;
  final Duration position;
  final String? title;
  final ValueChanged<AudioVisualizerConfig> onChanged;
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late AudioVisualizerConfig _c = widget.initial;

  void _set(AudioVisualizerConfig next) {
    setState(() => _c = next);
    widget.onChanged(next);
  }

  Widget _swatches(String prefix, List<(String, Color)> colors, Color selected, ValueChanged<Color> onPick) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
        child: Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.sm, children: [
          for (final (name, color) in colors)
            Tooltip(
              message: name,
              child: InkWell(
                key: ValueKey('$prefix.${color.toARGB32().toRadixString(16)}'),
                customBorder: const CircleBorder(),
                onTap: () => onPick(color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: color == selected ? RasqColors.accent : Theme.of(context).colorScheme.outlineVariant, width: color == selected ? 3 : 1)),
                ),
              ),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pcm = widget.pcm;
    final total = pcm?.duration ?? Duration.zero;
    final progress = total == Duration.zero ? 0.0 : (widget.position.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    // 今の再生位置のスペクトル(無音の位置でも形が分かるよう、標本が無ければ山形の見本)。
    final spectrum = pcm == null ? [for (var i = 0; i < _c.bands; i++) 0.25 + 0.6 * (1 - (i / _c.bands - 0.3).abs()).clamp(0.0, 1.0) * (i.isEven ? 1 : 0.7)] : spectrumAt(pcm, widget.position, bands: _c.bands);
    final plan = audioFramePlan(total, fps: _c.fps);
    return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomPaint(key: audioVisualizerPreviewKey, painter: _FramePainter(spectrum: spectrum, progress: progress, config: _c, title: widget.title)),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Text('今の再生位置のフレーム。決定で動画を書き出し直します(${plan.frames} フレーム${plan.fps < _c.fps - 0.5 ? '、長いので ${plan.fps.toStringAsFixed(1)}fps に下げます' : ''})。ペイントやテキストなど、ここまでの編集は消えます。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
      ),
      const RasqSectionHeader(title: '波形'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Wrap(spacing: RasqSpacing.xs, children: [
          for (final s in AudioVisualizerStyle.values) ChoiceChip(key: ValueKey('viz.style.${s.name}'), label: Text(s.label, style: RasqTypography.caption), selected: _c.style == s, onSelected: (_) => _set(_c.copyWith(style: s))),
        ]),
      ),
      RasqSliderListTile(key: const ValueKey('viz.bands'), title: '帯域の数(低音 → 高音)', value: _c.bands.toDouble(), min: 16, max: 128, divisions: 28, valueLabel: '${_c.bands}', onChanged: (v) => _set(_c.copyWith(bands: v.round()))),
      RasqSliderListTile(key: const ValueKey('viz.fps'), title: 'フレームレート', value: _c.fps.toDouble(), min: 10, max: 60, divisions: 10, valueLabel: '${_c.fps}fps', onChanged: (v) => _set(_c.copyWith(fps: v.round()))),
      const RasqSectionHeader(title: 'バーの色'),
      _swatches('viz.bar', _barColors, _c.barColor, (c) => _set(_c.copyWith(barColor: c))),
      const RasqSectionHeader(title: '背景色'),
      _swatches('viz.bg', _backgrounds, _c.background, (c) => _set(_c.copyWith(background: c))),
      const RasqSectionHeader(title: 'デザイン'),
      RasqSwitchListTile(key: const ValueKey('viz.icon'), title: '左にアイコン', subtitle: '消すと波形が横いっぱいに広がります', value: _c.showIcon, onChanged: (v) => _set(_c.copyWith(showIcon: v))),
      RasqSwitchListTile(key: const ValueKey('viz.title'), title: 'ファイル名を出す', value: _c.showTitle, enabled: _c.showIcon, onChanged: (v) => _set(_c.copyWith(showTitle: v))),
      RasqSwitchListTile(key: const ValueKey('viz.fine'), title: '細かく描く(2560×1440)', subtitle: 'オフ = 1280×720 で描いて拡大(書き出しが約 4 倍速い)', value: _c.fine, onChanged: (v) => _set(_c.copyWith(fine: v))),
    ]);
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.spectrum, required this.progress, required this.config, this.title});
  final List<double> spectrum;
  final double progress;
  final AudioVisualizerConfig config;
  final String? title;
  @override
  void paint(Canvas canvas, Size size) => paintAudioFrame(canvas, size, spectrum: spectrum, progress: progress, config: config, title: title);
  @override
  bool shouldRepaint(_FramePainter old) => old.config != config || old.progress != progress || old.spectrum != spectrum;
}
