import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../l10n/l10n.dart';
import 'audio_visualizer_video.dart';

/// Visualizer の設定 FOW (D-251): 加工画面の下段バーの「Visualizer」から。値を変えると**今の再生位置のフレーム**を
/// その場で描き直す(書き出しと同じ [paintAudioFrame])。「決定」で設定を返す(呼び出し元が動画を書き出し直す)。
const audioVisualizerFowId = 'media.pro.visualizer';
const audioVisualizerPreviewKey = Key('media.pro.visualizer.preview');

/// 保存先(端末ごと、全アカウント共通)。
const audioVisualizerStorageKey = 'editor.audioVisualizer.v1';

// 色の見本(名前は表示の言語、D-484)。
List<(String, Color)> _backgroundsOf(AppLocalizations l) => [(l.mediaColorBlack, const Color(0xFF000000)), (l.mediaColorNavy, const Color(0xFF0B1020)), (l.mediaColorInk, const Color(0xFF16181C)), (l.mediaColorDeepGreen, const Color(0xFF06231B)), (l.mediaColorCrimson, const Color(0xFF2A0A12)), (l.mediaColorWhite, const Color(0xFFFFFFFF))];
List<(String, Color)> _textColorsOf(AppLocalizations l) => [(l.mediaColorWhite, const Color(0xFFFFFFFF)), (l.mediaColorLightGray, const Color(0xFFCBD5E1)), (l.mediaColorYellow, const Color(0xFFFFD54F)), (l.mediaColorSkyBlue, const Color(0xFF35C9E8)), (l.mediaColorPink, const Color(0xFFFF5C8A)), (l.mediaColorBlack, const Color(0xFF000000))];
List<(String, Color)> _barColorsOf(AppLocalizations l) => [(l.mediaColorBlue, const Color(0xFF4F8DFD)), (l.mediaColorSkyBlue, const Color(0xFF35C9E8)), (l.mediaColorGreen, const Color(0xFF3DDC84)), (l.mediaColorYellow, const Color(0xFFFFD54F)), (l.mediaColorOrange, const Color(0xFFFF8A3D)), (l.mediaColorPink, const Color(0xFFFF5C8A)), (l.mediaColorPurple, const Color(0xFFA27BFF)), (l.mediaColorWhite, const Color(0xFFFFFFFF))];

/// FOW が外から借りるもの (D-253): 絵の読み込みとファイル選び(選んだファイルは呼び出し側がアプリの保存領域へ写して、
/// そのパスを返す = 設定として持ち続けられる)。どれも無ければその項目は出るが、選べない / プレビューに出ないだけ。
class AudioVisualizerFowHost {
  const AudioVisualizerFowHost({this.avatar, this.loadImage, this.loadVideoFrame, this.pickImage, this.pickVideo, this.lastTimings});

  /// 前回の書き出しの内訳(あれば「書き出し」の節に出す)。
  final AudioBuildTimings? lastTimings;

  /// アカウントのアイコン(読み込み済み)。
  final ui.Image? avatar;
  final Future<ui.Image?> Function(String path)? loadImage;

  /// 背景の動画の、その時刻の 1 枚(ループ込みの時刻で呼ぶ)。
  final Future<ui.Image?> Function(String path, Duration at)? loadVideoFrame;
  final Future<String?> Function()? pickImage;
  final Future<String?> Function()? pickVideo;
}

Future<AudioVisualizerConfig?> showAudioVisualizerFow(OverlayManager manager, {required AudioVisualizerConfig initial, required AudioPcm? pcm, required Duration position, String? title, AudioVisualizerFowHost host = const AudioVisualizerFowHost()}) async {
  if (manager.contains(audioVisualizerFowId)) return null;
  var config = initial;
  final l10n = appL10n;
  final ok = await manager.showFow<bool>(
    id: audioVisualizerFowId,
    spec: FowSpec(title: 'Visualizer', cancelText: l10n.mediaVizCancel, confirmText: l10n.mediaVizConfirm, initialHeightFactor: 0.8, maxHeightFactor: 0.92, maxWidth: 640),
    semanticsLabel: l10n.mediaVizSemantics,
    builder: (_, _) => _Body(initial: initial, pcm: pcm, position: position, title: title, host: host, onChanged: (c) => config = c),
  );
  return ok == true ? config : null;
}

class _Body extends StatefulWidget {
  const _Body({required this.initial, required this.pcm, required this.position, required this.title, required this.host, required this.onChanged});
  final AudioVisualizerFowHost host;
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
  late final _title = TextEditingController(text: widget.initial.title ?? widget.title ?? '');
  late final _description = TextEditingController(text: widget.initial.description);

  /// プレビュー用に読み込んだ絵(選んだ画像 / 背景の動画の今のコマ)。
  ui.Image? _fileImage;
  String? _fileImagePath;
  ui.Image? _bgFrame;
  String? _bgFramePath;

  @override
  void initState() {
    super.initState();
    _loadPreviewImages();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _fileImage?.dispose();
    _bgFrame?.dispose();
    super.dispose();
  }

  void _set(AudioVisualizerConfig next) {
    setState(() => _c = next);
    widget.onChanged(next);
    _loadPreviewImages();
  }

  Future<void> _loadPreviewImages() async {
    final img = _c.leftImagePath;
    if (img != _fileImagePath) {
      _fileImagePath = img;
      final loaded = img == null ? null : await widget.host.loadImage?.call(img);
      if (!mounted) return loaded?.dispose();
      setState(() {
        _fileImage?.dispose();
        _fileImage = loaded;
      });
    }
    final bg = _c.backgroundVideoPath;
    if (bg != _bgFramePath) {
      _bgFramePath = bg;
      final loaded = bg == null ? null : await widget.host.loadVideoFrame?.call(bg, widget.position);
      if (!mounted) return loaded?.dispose();
      setState(() {
        _bgFrame?.dispose();
        _bgFrame = loaded;
      });
    }
  }

  ui.Image? get _leftImage => switch (_c.left) {
        AudioVisualizerLeft.avatar => widget.host.avatar,
        AudioVisualizerLeft.file => _fileImage,
        _ => null,
      };

  static String _fileName(String path) => path.split(RegExp(r'[/\\]')).last;

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
    final pcm = widget.pcm;
    final total = pcm?.duration ?? Duration.zero;
    final progress = total == Duration.zero ? 0.0 : (widget.position.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    // 今の再生位置のスペクトル(無音の位置でも形が分かるよう、標本が無ければ山形の見本)。
    final spectrum = pcm == null ? [for (var i = 0; i < _c.bands; i++) 0.25 + 0.6 * (1 - (i / _c.bands - 0.3).abs()).clamp(0.0, 1.0) * (i.isEven ? 1 : 0.7)] : spectrumAt(pcm, widget.position, bands: _c.bands);
    final plan = audioFramePlan(total, fps: _c.fps);
    final l10n = context.l10n;
    String seconds(double v) => l10n.mediaSeconds(v.toStringAsFixed(1));
    return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: CustomPaint(key: audioVisualizerPreviewKey, painter: _FramePainter(spectrum: spectrum, progress: progress, config: _c, title: widget.title, background: _bgFrame, leftImage: _leftImage, fade: 1)),
          ),
        ),
      ),
      RasqNotice.warning(
        text: l10n.mediaVizRebuildWarning,
        detail: plan.fps < _c.fps - 0.5 ? l10n.mediaVizRebuildDetailReducedFps(plan.frames, plan.fps.toStringAsFixed(1)) : l10n.mediaVizRebuildDetail(plan.frames),
      ),
      RasqSectionHeader(title: l10n.mediaVizWaveform),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Wrap(spacing: RasqSpacing.xs, children: [
          for (final s in AudioVisualizerStyle.values) ChoiceChip(key: ValueKey('viz.style.${s.name}'), label: Text(s.label, style: RasqTypography.caption), selected: _c.style == s, onSelected: (_) => _set(_c.copyWith(style: s))),
        ]),
      ),
      RasqSliderListTile(key: const ValueKey('viz.bands'), title: l10n.mediaVizBands, value: _c.bands.toDouble(), min: 16, max: 128, divisions: 28, valueLabel: '${_c.bands}', onChanged: (v) => _set(_c.copyWith(bands: v.round()))),
      RasqSliderListTile(key: const ValueKey('viz.fps'), title: l10n.mediaVizFrameRate, value: _c.fps.toDouble(), min: 10, max: 60, divisions: 10, valueLabel: '${_c.fps}fps', onChanged: (v) => _set(_c.copyWith(fps: v.round()))),
      RasqSectionHeader(title: l10n.mediaVizBarColor),
      _swatches('viz.bar', _barColorsOf(l10n), _c.barColor, (c) => _set(_c.copyWith(barColor: c))),
      RasqSectionHeader(title: l10n.mediaVizBackgroundColor),
      _swatches('viz.bg', _backgroundsOf(l10n), _c.background, (c) => _set(_c.copyWith(background: c))),
      RasqSectionHeader(title: l10n.mediaVizLeftImage),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
          for (final l in AudioVisualizerLeft.values) ChoiceChip(key: ValueKey('viz.left.${l.name}'), label: Text(l.label, style: RasqTypography.caption), selected: _c.left == l, onSelected: (_) => _set(_c.copyWith(left: l))),
        ]),
      ),
      if (_c.left == AudioVisualizerLeft.file)
        RasqListTile(
          key: const ValueKey('viz.left.pick'),
          leading: const Icon(Icons.image_outlined),
          title: _c.leftImagePath == null ? l10n.mediaVizPickImage : l10n.mediaVizRepickImage,
          subtitle: _c.leftImagePath == null ? l10n.mediaVizPickImageHint : _fileName(_c.leftImagePath!),
          onTap: widget.host.pickImage == null
              ? null
              : () async {
                  final path = await widget.host.pickImage!();
                  if (path != null && mounted) _set(_c.copyWith(leftImagePath: path));
                },
        ),
      RasqSectionHeader(title: l10n.mediaVizTitleSection),
      RasqSwitchListTile(key: const ValueKey('viz.title'), title: l10n.mediaVizShowTitle, value: _c.showTitle, enabled: _c.showLeft, onChanged: (v) => _set(_c.copyWith(showTitle: v))),
      if (_c.showLeft && _c.showTitle) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
          child: RasqInput(key: const ValueKey('viz.title.text'), controller: _title, hintText: l10n.mediaVizTitleHint, onChanged: (v) => _set(_c.copyWith(title: v.trim().isEmpty ? (widget.title ?? '') : v.trim()))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
          child: RasqInput(key: const ValueKey('viz.description.text'), controller: _description, hintText: l10n.mediaVizDescriptionHint, onChanged: (v) => _set(_c.copyWith(description: v.trim()))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, children: [
            for (final t in AudioVisualizerTextPosition.values) ChoiceChip(key: ValueKey('viz.text.${t.name}'), label: Text(t.label, style: RasqTypography.caption), selected: _c.textPosition == t, onSelected: (_) => _set(_c.copyWith(textPosition: t))),
          ]),
        ),
        RasqSliderListTile(key: const ValueKey('viz.text.scale'), title: l10n.mediaVizTextScale, value: _c.textScale, min: 0.6, max: 2.0, divisions: 14, valueLabel: '${(_c.textScale * 100).round()}%', onChanged: (v) => _set(_c.copyWith(textScale: v))),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, 0),
          child: Row(children: [
            ChoiceChip(key: const ValueKey('viz.text.color.auto'), label: Text(l10n.mediaVizTextColorAuto, style: RasqTypography.caption), selected: _c.textColor == null, onSelected: (_) => _set(_c.copyWith(clearTextColor: true))),
          ]),
        ),
        _swatches('viz.text.color', _textColorsOf(l10n), _c.textColor ?? const Color(0x00000000), (c) => _set(_c.copyWith(textColor: c))),
      ],
      RasqSectionHeader(title: l10n.mediaVizBackgroundVideo),
      RasqListTile(
        key: const ValueKey('viz.bgvideo.pick'),
        leading: const Icon(Icons.movie_outlined),
        title: _c.backgroundVideoPath == null ? l10n.mediaVizPickVideo : l10n.mediaVizRepickVideo,
        subtitle: _c.backgroundVideoPath == null ? l10n.mediaVizPickVideoHint : l10n.mediaVizVideoSelected(_fileName(_c.backgroundVideoPath!)),
        onTap: widget.host.pickVideo == null
            ? null
            : () async {
                final path = await widget.host.pickVideo!();
                if (path != null && mounted) _set(_c.copyWith(backgroundVideoPath: path));
              },
      ),
      if (_c.backgroundVideoPath != null) ...[
        RasqListTile(key: const ValueKey('viz.bgvideo.clear'), leading: const Icon(Icons.close), title: l10n.mediaVizRemoveVideo, chevron: false, onTap: () => _set(_c.copyWith(clearBackgroundVideo: true))),
        RasqSliderListTile(key: const ValueKey('viz.bgvideo.dim'), title: l10n.mediaVizDim, subtitle: l10n.mediaVizDimHint, value: _c.backgroundDim, min: 0, max: 0.8, divisions: 16, valueLabel: '${(_c.backgroundDim * 100).round()}%', onChanged: (v) => _set(_c.copyWith(backgroundDim: v))),
      ],
      RasqSectionHeader(title: l10n.mediaVizFade),
      RasqSliderListTile(key: const ValueKey('viz.fadein'), title: l10n.mediaVizFadeIn, value: _c.fadeIn, min: 0, max: 5, divisions: 10, valueLabel: _c.fadeIn == 0 ? l10n.mediaVizFadeNone : seconds(_c.fadeIn), onChanged: (v) => _set(_c.copyWith(fadeIn: v))),
      RasqSliderListTile(key: const ValueKey('viz.fadeout'), title: l10n.mediaVizFadeOut, value: _c.fadeOut, min: 0, max: 5, divisions: 10, valueLabel: _c.fadeOut == 0 ? l10n.mediaVizFadeNone : seconds(_c.fadeOut), onChanged: (v) => _set(_c.copyWith(fadeOut: v))),
      RasqSectionHeader(title: l10n.mediaVizExport),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
          for (final q in AudioVisualizerQuality.values) ChoiceChip(key: ValueKey('viz.quality.${q.name}'), label: Text(q.label, style: RasqTypography.caption), selected: _c.quality == q, onSelected: (_) => _set(_c.copyWith(quality: q))),
        ]),
      ),
      RasqCaption(
        l10n.mediaVizExportCaption,
        detail: widget.host.lastTimings == null ? l10n.mediaVizExportDetail : l10n.mediaVizExportDetailWithLast('${widget.host.lastTimings}'),
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
      ),
    ]);
  }
}

class _FramePainter extends CustomPainter {
  const _FramePainter({required this.spectrum, required this.progress, required this.config, this.title, this.background, this.leftImage, this.fade = 1});
  final ui.Image? background;
  final ui.Image? leftImage;
  final double fade;
  final List<double> spectrum;
  final double progress;
  final AudioVisualizerConfig config;
  final String? title;
  @override
  void paint(Canvas canvas, Size size) => paintAudioFrame(canvas, size, spectrum: spectrum, progress: progress, config: config, title: title, background: background, leftImage: leftImage, fade: fade);
  @override
  bool shouldRepaint(_FramePainter old) => old.config != config || old.progress != progress || old.spectrum != spectrum || old.background != background || old.leftImage != leftImage;
}
