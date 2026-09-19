import 'dart:ui' as ui;

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
const _textColors = <(String, Color)>[('白', Color(0xFFFFFFFF)), ('薄い灰', Color(0xFFCBD5E1)), ('黄', Color(0xFFFFD54F)), ('水色', Color(0xFF35C9E8)), ('桃', Color(0xFFFF5C8A)), ('黒', Color(0xFF000000))];
const _barColors = <(String, Color)>[('青', Color(0xFF4F8DFD)), ('水色', Color(0xFF35C9E8)), ('緑', Color(0xFF3DDC84)), ('黄', Color(0xFFFFD54F)), ('橙', Color(0xFFFF8A3D)), ('桃', Color(0xFFFF5C8A)), ('紫', Color(0xFFA27BFF)), ('白', Color(0xFFFFFFFF))];

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
  final ok = await manager.showFow<bool>(
    id: audioVisualizerFowId,
    spec: FowSpec(title: 'Visualizer', cancelText: 'キャンセル', confirmText: '決定', initialHeightFactor: 0.8, maxHeightFactor: 0.92, maxWidth: 640),
    semanticsLabel: 'Visualizer の設定',
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
            child: CustomPaint(key: audioVisualizerPreviewKey, painter: _FramePainter(spectrum: spectrum, progress: progress, config: _c, title: widget.title, background: _bgFrame, leftImage: _leftImage, fade: 1)),
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
      const RasqSectionHeader(title: '左の絵'),
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
          title: _c.leftImagePath == null ? '画像を選ぶ' : '画像を選び直す',
          subtitle: _c.leftImagePath == null ? '選ぶまでは音符のアイコン' : _fileName(_c.leftImagePath!),
          onTap: widget.host.pickImage == null
              ? null
              : () async {
                  final path = await widget.host.pickImage!();
                  if (path != null && mounted) _set(_c.copyWith(leftImagePath: path));
                },
        ),
      const RasqSectionHeader(title: 'タイトル / 説明'),
      RasqSwitchListTile(key: const ValueKey('viz.title'), title: 'タイトル / 説明を出す', value: _c.showTitle, enabled: _c.showLeft, onChanged: (v) => _set(_c.copyWith(showTitle: v))),
      if (_c.showLeft && _c.showTitle) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.xs),
          child: RasqInput(key: const ValueKey('viz.title.text'), controller: _title, hintText: 'タイトル(空ならファイル名)', onChanged: (v) => _set(_c.copyWith(title: v.trim().isEmpty ? (widget.title ?? '') : v.trim()))),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.xs),
          child: RasqInput(key: const ValueKey('viz.description.text'), controller: _description, hintText: '説明(無くてもよい)', onChanged: (v) => _set(_c.copyWith(description: v.trim()))),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, children: [
            for (final t in AudioVisualizerTextPosition.values) ChoiceChip(key: ValueKey('viz.text.${t.name}'), label: Text(t.label, style: RasqTypography.caption), selected: _c.textPosition == t, onSelected: (_) => _set(_c.copyWith(textPosition: t))),
          ]),
        ),
        RasqSliderListTile(key: const ValueKey('viz.text.scale'), title: '文字の大きさ', value: _c.textScale, min: 0.6, max: 2.0, divisions: 14, valueLabel: '${(_c.textScale * 100).round()}%', onChanged: (v) => _set(_c.copyWith(textScale: v))),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, 0),
          child: Row(children: [
            ChoiceChip(key: const ValueKey('viz.text.color.auto'), label: Text('文字の色: 自動', style: RasqTypography.caption), selected: _c.textColor == null, onSelected: (_) => _set(_c.copyWith(clearTextColor: true))),
          ]),
        ),
        _swatches('viz.text.color', _textColors, _c.textColor ?? const Color(0x00000000), (c) => _set(_c.copyWith(textColor: c))),
      ],
      const RasqSectionHeader(title: '背景の動画'),
      RasqListTile(
        key: const ValueKey('viz.bgvideo.pick'),
        leading: const Icon(Icons.movie_outlined),
        title: _c.backgroundVideoPath == null ? '動画を選ぶ' : '動画を選び直す',
        subtitle: _c.backgroundVideoPath == null ? '背景色の代わりに動画を流します(音は使いません)' : '${_fileName(_c.backgroundVideoPath!)} — 音声より短ければループします',
        onTap: widget.host.pickVideo == null
            ? null
            : () async {
                final path = await widget.host.pickVideo!();
                if (path != null && mounted) _set(_c.copyWith(backgroundVideoPath: path));
              },
      ),
      if (_c.backgroundVideoPath != null) ...[
        RasqListTile(key: const ValueKey('viz.bgvideo.clear'), leading: const Icon(Icons.close), title: '背景の動画を外す', chevron: false, onTap: () => _set(_c.copyWith(clearBackgroundVideo: true))),
        RasqSliderListTile(key: const ValueKey('viz.bgvideo.dim'), title: '動画の上に掛ける暗さ', subtitle: '波形と文字を読みやすくします', value: _c.backgroundDim, min: 0, max: 0.8, divisions: 16, valueLabel: '${(_c.backgroundDim * 100).round()}%', onChanged: (v) => _set(_c.copyWith(backgroundDim: v))),
      ],
      const RasqSectionHeader(title: 'フェード(絵)'),
      RasqSliderListTile(key: const ValueKey('viz.fadein'), title: 'フェードイン', value: _c.fadeIn, min: 0, max: 5, divisions: 10, valueLabel: _c.fadeIn == 0 ? 'なし' : '${_c.fadeIn.toStringAsFixed(1)} 秒', onChanged: (v) => _set(_c.copyWith(fadeIn: v))),
      RasqSliderListTile(key: const ValueKey('viz.fadeout'), title: 'フェードアウト', value: _c.fadeOut, min: 0, max: 5, divisions: 10, valueLabel: _c.fadeOut == 0 ? 'なし' : '${_c.fadeOut.toStringAsFixed(1)} 秒', onChanged: (v) => _set(_c.copyWith(fadeOut: v))),
      const RasqSectionHeader(title: '書き出し'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
          for (final q in AudioVisualizerQuality.values) ChoiceChip(key: ValueKey('viz.quality.${q.name}'), label: Text(q.label, style: RasqTypography.caption), selected: _c.quality == q, onSelected: (_) => _set(_c.copyWith(quality: q))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
        child: Text('${widget.host.lastTimings == null ? '' : '前回の書き出し: ${widget.host.lastTimings}。\n'}波形を描く大きさ(出力はいつも 2560×1440)。左の絵と文字は別の 1 枚で、いつも細かく描きます。書き出しの時間はほぼ フレーム数 × 描く大きさ で決まります(fps を下げるのも効きます)。背景の動画を使うと遅くなります。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
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
