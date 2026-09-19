import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// 音声だけのファイルを動画にする (D-250 → D-251)。
///
/// 加工画面は動画のエディターなので、音声(`audio/*`)は開くときに **2560×1440 の動画**へ変換する。
/// 絵は **その瞬間のスペクトル**(左から右に 低音 → 高音)を 1 フレームごとに描く(既定 25fps)。バーの列の
/// 中央(高さ方向)に**シークバー**(再生位置までバーの色、つまみ付き)。左に絵(既定はアカウントのアイコン / 選んだ画像 /
/// 音符 / なし)+ タイトル・説明(絵の上か下、色と大きさ)。背景は単色か**動画**(その瞬間のコマを取り出して描く。短ければ
/// ループ、上に暗さを掛ける)。先頭 / 末尾にフェード (D-253)。
///
/// 流れ(端末ネイティブ = Android / iOS / macOS だけ。pro_video_editor の 音声の取り出し / StopMotion が要る):
/// 1. `extractAudioToFile` で WAV に → [AudioPcm.parseWav](モノラル、≤ 24kHz に間引き)
/// 2. フレームごとに [spectrumAt](Hann 窓 + FFT → 対数間隔の帯域、前のフレームからの減衰つき)
/// 3. `dart:ui` で描いて PNG に → `renderStopMotionToFile`(無音の動画)
/// 4. `renderVideoToFile` で元の音声を重ねて mp4 に
///
/// 設定([AudioVisualizerConfig]: 背景色 / バーの色 / 形 / 帯域の数 / fps / アイコン・ファイル名 / 描画の細かさ)は
/// 加工画面の下段バーの「Visualizer」から変える(その場のフレームをプレビュー、決定で書き出し直す)。
const audioVideoSize = ui.Size(2560, 1440);

/// フレームの上限(これを超える長さは fps を下げて収める)。25fps で 5 分。
const audioMaxFrames = 7500;

/// 波形の形。
enum AudioVisualizerStyle {
  mirror('上下対称のバー'),
  bars('下から伸びるバー'),
  line('折れ線');

  const AudioVisualizerStyle(this.label);
  final String label;
}

/// 左の絵 (D-253)。
enum AudioVisualizerLeft {
  avatar('アカウントのアイコン'),
  file('選んだ画像'),
  glyph('音符のアイコン'),
  none('なし(波形を横いっぱいに)');

  const AudioVisualizerLeft(this.label);
  final String label;
}

/// タイトル / 説明を左の絵のどちらに付けるか。
enum AudioVisualizerTextPosition {
  below('絵の下'),
  above('絵の上');

  const AudioVisualizerTextPosition(this.label);
  final String label;
}

@immutable
class AudioVisualizerConfig {
  const AudioVisualizerConfig({
    this.fps = 25,
    this.bands = 64,
    this.style = AudioVisualizerStyle.mirror,
    this.background = const Color(0xFF000000),
    this.barColor = const Color(0xFF4F8DFD),
    this.left = AudioVisualizerLeft.avatar,
    this.leftImagePath,
    this.showTitle = true,
    this.textPosition = AudioVisualizerTextPosition.below,
    this.textColor,
    this.textScale = 1.0,
    this.backgroundVideoPath,
    this.backgroundDim = 0.35,
    this.fadeIn = 0,
    this.fadeOut = 0,
    this.fine = false,
    this.title,
    this.description = '',
  });

  /// 10〜60。既定 25(30 だと 2 分の音声の書き出しに 3 分ほどかかった、D-253)。
  final int fps;

  /// 帯域(バー)の数。16〜128。
  final int bands;
  final AudioVisualizerStyle style;
  final Color background;
  final Color barColor;

  /// 左の絵。[AudioVisualizerLeft.file] は [leftImagePath](アプリの保存領域に写したもの)。
  final AudioVisualizerLeft left;
  final String? leftImagePath;

  /// タイトル / 説明を出すか、絵の上下どちらか、色(null = 背景に合わせて白 / 黒)、大きさ(0.6〜2.0 倍)。
  final bool showTitle;
  final AudioVisualizerTextPosition textPosition;
  final Color? textColor;
  final double textScale;

  /// 背景の動画(アプリの保存領域に写したもの。音声より短ければループ)と、その上に掛ける暗さ(0〜0.8)。
  final String? backgroundVideoPath;
  final double backgroundDim;

  /// 絵のフェードイン / フェードアウト(秒、0〜5。黒から / 黒へ)。
  final double fadeIn;
  final double fadeOut;

  /// 描画の細かさ: false = 1280×720 で描いて 2560×1440 へ拡大(速い)、true = 2560×1440 で描く(約 4 倍かかる)。
  final bool fine;

  /// タイトル(null = ファイル名)と説明。**保存しない**(その音声ごとの中身)。
  final String? title;
  final String description;

  bool get showLeft => left != AudioVisualizerLeft.none;
  ui.Size get paintSize => fine ? audioVideoSize : audioVideoSize / 2;

  AudioVisualizerConfig copyWith({
    int? fps,
    int? bands,
    AudioVisualizerStyle? style,
    Color? background,
    Color? barColor,
    AudioVisualizerLeft? left,
    String? leftImagePath,
    bool? showTitle,
    AudioVisualizerTextPosition? textPosition,
    Color? textColor,
    bool clearTextColor = false,
    double? textScale,
    String? backgroundVideoPath,
    bool clearBackgroundVideo = false,
    double? backgroundDim,
    double? fadeIn,
    double? fadeOut,
    bool? fine,
    String? title,
    String? description,
  }) =>
      AudioVisualizerConfig(
        fps: (fps ?? this.fps).clamp(10, 60),
        bands: (bands ?? this.bands).clamp(16, 128),
        style: style ?? this.style,
        background: background ?? this.background,
        barColor: barColor ?? this.barColor,
        left: left ?? this.left,
        leftImagePath: leftImagePath ?? this.leftImagePath,
        showTitle: showTitle ?? this.showTitle,
        textPosition: textPosition ?? this.textPosition,
        textColor: clearTextColor ? null : (textColor ?? this.textColor),
        textScale: (textScale ?? this.textScale).clamp(0.6, 2.0),
        backgroundVideoPath: clearBackgroundVideo ? null : (backgroundVideoPath ?? this.backgroundVideoPath),
        backgroundDim: (backgroundDim ?? this.backgroundDim).clamp(0.0, 0.8),
        fadeIn: (fadeIn ?? this.fadeIn).clamp(0.0, 5.0),
        fadeOut: (fadeOut ?? this.fadeOut).clamp(0.0, 5.0),
        fine: fine ?? this.fine,
        title: title ?? this.title,
        description: description ?? this.description,
      );

  /// 保存する形(タイトル / 説明は入れない)。
  Map<String, Object?> toJson() => {
        'fps': fps,
        'bands': bands,
        'style': style.name,
        'background': background.toARGB32(),
        'barColor': barColor.toARGB32(),
        'left': left.name,
        if (leftImagePath != null) 'leftImagePath': leftImagePath,
        'showTitle': showTitle,
        'textPosition': textPosition.name,
        if (textColor != null) 'textColor': textColor!.toARGB32(),
        'textScale': textScale,
        if (backgroundVideoPath != null) 'backgroundVideoPath': backgroundVideoPath,
        'backgroundDim': backgroundDim,
        'fadeIn': fadeIn,
        'fadeOut': fadeOut,
        'fine': fine,
      };

  factory AudioVisualizerConfig.fromJson(Map<String, Object?> j) => const AudioVisualizerConfig().copyWith(
        fps: (j['fps'] as num?)?.toInt(),
        bands: (j['bands'] as num?)?.toInt(),
        style: AudioVisualizerStyle.values.where((s) => s.name == j['style']).firstOrNull,
        background: j['background'] is int ? Color(j['background'] as int) : null,
        barColor: j['barColor'] is int ? Color(j['barColor'] as int) : null,
        // 旧形 (D-251) の showIcon: false = なし。
        left: AudioVisualizerLeft.values.where((s) => s.name == j['left']).firstOrNull ?? (j['showIcon'] == false ? AudioVisualizerLeft.none : null),
        leftImagePath: j['leftImagePath'] as String?,
        showTitle: j['showTitle'] as bool?,
        textPosition: AudioVisualizerTextPosition.values.where((s) => s.name == j['textPosition']).firstOrNull,
        textColor: j['textColor'] is int ? Color(j['textColor'] as int) : null,
        textScale: (j['textScale'] as num?)?.toDouble(),
        backgroundVideoPath: j['backgroundVideoPath'] as String?,
        backgroundDim: (j['backgroundDim'] as num?)?.toDouble(),
        fadeIn: (j['fadeIn'] as num?)?.toDouble(),
        fadeOut: (j['fadeOut'] as num?)?.toDouble(),
        fine: j['fine'] as bool?,
      );

  static AudioVisualizerConfig decode(String? raw) {
    if (raw == null) return const AudioVisualizerConfig();
    try {
      return AudioVisualizerConfig.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    } catch (_) {
      return const AudioVisualizerConfig();
    }
  }

  @override
  bool operator ==(Object other) => other is AudioVisualizerConfig && jsonEncode(other.toJson()) == jsonEncode(toJson()) && other.title == title && other.description == description;
  @override
  int get hashCode => Object.hash(jsonEncode(toJson()), title, description);
}

/// フェードの明るさ(0 = 真っ黒、1 = そのまま): 先頭 [AudioVisualizerConfig.fadeIn] 秒で上がり、末尾 fadeOut 秒で下がる。
double audioFadeAt(Duration at, Duration total, AudioVisualizerConfig config) {
  final t = at.inMicroseconds / 1e6, end = total.inMicroseconds / 1e6;
  var v = 1.0;
  if (config.fadeIn > 0) v = math.min(v, t / config.fadeIn);
  if (config.fadeOut > 0) v = math.min(v, (end - t) / config.fadeOut);
  return v.clamp(0.0, 1.0);
}

/// 背景の動画のどこを出すか: 音声より短ければループ。
Duration audioBackgroundTimeAt(Duration at, Duration videoDuration) => videoDuration <= Duration.zero ? Duration.zero : Duration(microseconds: at.inMicroseconds % videoDuration.inMicroseconds);

/// フレームの割り当て: 設定の fps、長すぎる音声は [audioMaxFrames] 枚に収まるまで fps を下げる。
({int frames, Duration each, double fps}) audioFramePlan(Duration total, {int fps = 25}) {
  final seconds = math.max(total.inMicroseconds / 1e6, 1.0);
  final want = (seconds * fps).ceil();
  final frames = want.clamp(1, audioMaxFrames);
  return (frames: frames, each: Duration(microseconds: (seconds * 1e6 / frames).round()), fps: frames / seconds);
}

/// 音声の標本(モノラル、16bit)。
class AudioPcm {
  AudioPcm({required this.samples, required this.sampleRate});
  final Int16List samples;
  final int sampleRate;

  Duration get duration => Duration(microseconds: sampleRate == 0 ? 0 : (samples.length * 1e6 / sampleRate).round());

  /// WAV(RIFF、PCM 8 / 16 / 24 / 32bit か float32)→ モノラル。[maxRate] を超える標本化周波数は整数分の 1 に間引く。
  static AudioPcm parseWav(Uint8List bytes, {int maxRate = 24000}) {
    final d = ByteData.sublistView(bytes);
    String tag(int o) => String.fromCharCodes(bytes.sublist(o, o + 4));
    if (bytes.length < 12 || tag(0) != 'RIFF' || tag(8) != 'WAVE') throw const FormatException('WAV ではありません');
    int? format, channels, rate, bits;
    var dataAt = -1, dataLen = 0;
    for (var o = 12; o + 8 <= bytes.length;) {
      final id = tag(o);
      final len = d.getUint32(o + 4, Endian.little);
      if (id == 'fmt ' && o + 8 + 16 <= bytes.length) {
        format = d.getUint16(o + 8, Endian.little);
        channels = d.getUint16(o + 10, Endian.little);
        rate = d.getUint32(o + 12, Endian.little);
        bits = d.getUint16(o + 22, Endian.little);
        // WAVE_FORMAT_EXTENSIBLE: 実際の形式はサブフォーマットの先頭 2 バイト。
        if (format == 0xFFFE && len >= 26) format = d.getUint16(o + 8 + 24, Endian.little);
      } else if (id == 'data') {
        dataAt = o + 8;
        dataLen = math.min(len, bytes.length - dataAt);
        break;
      }
      o += 8 + len + (len & 1);
    }
    if (format == null || channels == null || rate == null || bits == null || dataAt < 0 || channels == 0 || rate == 0) throw const FormatException('WAV の fmt / data がありません');
    if (!((format == 1 && const [8, 16, 24, 32].contains(bits)) || (format == 3 && bits == 32))) throw FormatException('未対応の WAV(format $format、$bits bit)');
    final width = bits ~/ 8;
    final step = math.max(1, (rate / maxRate).ceil());
    final frames = dataLen ~/ (width * channels);
    final out = Int16List((frames / step).ceil());
    double read(int o) => switch ((format, bits)) {
          (3, _) => d.getFloat32(o, Endian.little).clamp(-1.0, 1.0).toDouble(),
          (_, 8) => (bytes[o] - 128) / 128,
          (_, 16) => d.getInt16(o, Endian.little) / 32768,
          (_, 24) => ((bytes[o] | (bytes[o + 1] << 8) | (d.getInt8(o + 2) << 16))) / 8388608,
          _ => d.getInt32(o, Endian.little) / 2147483648,
        };
    for (var i = 0, k = 0; i < frames; i += step, k++) {
      var sum = 0.0;
      // 間引く区間の平均(簡単な低域通過)× チャンネルの平均。
      final n = math.min(step, frames - i);
      for (var s = 0; s < n; s++) {
        for (var c = 0; c < channels; c++) {
          sum += read(dataAt + ((i + s) * channels + c) * width);
        }
      }
      out[k] = (sum / (n * channels) * 32767).round().clamp(-32768, 32767);
    }
    return AudioPcm(samples: out, sampleRate: rate ~/ step);
  }
}

/// FFT の窓(標本数、2 のべき)。24kHz で約 85ms。
const audioFftSize = 2048;

final Float64List _hann = Float64List.fromList([for (var i = 0; i < audioFftSize; i++) 0.5 - 0.5 * math.cos(2 * math.pi * i / (audioFftSize - 1))]);

/// 基数 2 の FFT(その場)。
void _fft(Float64List re, Float64List im) {
  final n = re.length;
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    for (; j & bit != 0; bit >>= 1) {
      j ^= bit;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i], ti = im[i];
      re[i] = re[j];
      im[i] = im[j];
      re[j] = tr;
      im[j] = ti;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final ang = -2 * math.pi / len;
    final wr = math.cos(ang), wi = math.sin(ang);
    for (var i = 0; i < n; i += len) {
      var cr = 1.0, ci = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final a = i + k, b = a + len ~/ 2;
        final xr = re[b] * cr - im[b] * ci, xi = re[b] * ci + im[b] * cr;
        re[b] = re[a] - xr;
        im[b] = im[a] - xi;
        re[a] += xr;
        im[a] += xi;
        final nr = cr * wr - ci * wi;
        ci = cr * wi + ci * wr;
        cr = nr;
      }
    }
  }
}

/// その瞬間のスペクトル: [at] を中心にした窓 → 対数間隔の [bands] 帯域(40Hz〜ナイキスト、左 = 低音)の高さ 0..1。
/// dB(-60〜0)で目盛る。[previous](前のフレーム)があれば、下がるときだけゆっくり(× [decay])。
List<double> spectrumAt(AudioPcm pcm, Duration at, {int bands = 64, List<double>? previous, double decay = 0.82}) {
  final re = Float64List(audioFftSize), im = Float64List(audioFftSize);
  final center = (at.inMicroseconds * pcm.sampleRate / 1e6).round();
  final start = center - audioFftSize ~/ 2;
  for (var i = 0; i < audioFftSize; i++) {
    final k = start + i;
    re[i] = k < 0 || k >= pcm.samples.length ? 0 : pcm.samples[k] / 32768 * _hann[i];
  }
  _fft(re, im);
  final nyquist = pcm.sampleRate / 2;
  final lo = math.min(40.0, nyquist / 4);
  final out = List<double>.filled(bands, 0);
  for (var b = 0; b < bands; b++) {
    final f0 = lo * math.pow(nyquist / lo, b / bands), f1 = lo * math.pow(nyquist / lo, (b + 1) / bands);
    final k0 = (f0 / nyquist * (audioFftSize / 2)).floor().clamp(1, audioFftSize ~/ 2 - 1);
    final k1 = math.max(k0 + 1, (f1 / nyquist * (audioFftSize / 2)).ceil().clamp(1, audioFftSize ~/ 2));
    var peak = 0.0;
    for (var k = k0; k < k1; k++) {
      peak = math.max(peak, re[k] * re[k] + im[k] * im[k]);
    }
    // 窓の利得(Hann の和 = N/2)で正規化した振幅 → dB。
    final amp = math.sqrt(peak) / (audioFftSize / 4);
    final db = 20 * math.log(math.max(amp, 1e-9)) / math.ln10;
    var v = ((db + 60) / 60).clamp(0.0, 1.0);
    final p = previous != null && b < previous.length ? previous[b] * decay : 0.0;
    if (p > v) v = p;
    out[b] = v;
  }
  return out;
}

/// 画像を枠いっぱいに(cover)描く。
void _drawCover(Canvas canvas, ui.Image image, Rect dst, {Paint? paint}) {
  final iw = image.width.toDouble(), ih = image.height.toDouble();
  final scale = math.max(dst.width / iw, dst.height / ih);
  final sw = dst.width / scale, sh = dst.height / scale;
  canvas.drawImageRect(image, Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh), dst, paint ?? (Paint()..filterQuality = FilterQuality.medium));
}

/// 1 フレームを描く。[spectrum] = 帯域の高さ(0..1、左 = 低音)、[progress] = 再生位置(0..1)。
/// [background] = 背景の動画のその瞬間の 1 枚、[leftImage] = 左の絵(アイコン / 選んだ画像)、[fade] = 明るさ(0..1)。
void paintAudioFrame(Canvas canvas, ui.Size size, {required List<double> spectrum, required double progress, AudioVisualizerConfig config = const AudioVisualizerConfig(), IconData icon = Icons.music_note_rounded, String? title, ui.Image? background, ui.Image? leftImage, double fade = 1}) {
  final w = size.width, h = size.height;
  final bg = config.background;
  final full = Offset.zero & size;
  canvas.drawRect(full, Paint()..color = bg);
  var onBg = bg.computeLuminance() > 0.5 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  if (background != null) {
    _drawCover(canvas, background, full);
    if (config.backgroundDim > 0) canvas.drawRect(full, Paint()..color = const Color(0xFF000000).withValues(alpha: config.backgroundDim));
    onBg = const Color(0xFFFFFFFF);
  }
  final textColor = config.textColor ?? onBg;
  var areaLeft = h * 0.08;
  if (config.showLeft) {
    // 左: 絵(角丸)+ タイトル / 説明(絵の上か下)。
    final left = Rect.fromLTWH(0, 0, w * 0.34, h);
    final heading = config.title ?? title ?? '';
    final lines = <TextPainter>[
      if (config.showTitle && heading.isNotEmpty)
        TextPainter(text: TextSpan(text: heading, style: TextStyle(fontSize: h * 0.036 * config.textScale, fontWeight: FontWeight.w700, color: textColor)), textDirection: TextDirection.ltr, textAlign: TextAlign.center, maxLines: 2, ellipsis: '…')..layout(maxWidth: left.width - h * 0.08),
      if (config.showTitle && config.description.isNotEmpty)
        TextPainter(text: TextSpan(text: config.description, style: TextStyle(fontSize: h * 0.026 * config.textScale, color: textColor.withValues(alpha: 0.78))), textDirection: TextDirection.ltr, textAlign: TextAlign.center, maxLines: 3, ellipsis: '…')..layout(maxWidth: left.width - h * 0.08),
    ];
    final gap = h * 0.018;
    final textH = lines.fold(0.0, (s, t) => s + t.height) + (lines.isEmpty ? 0 : gap * lines.length);
    final side = math.min(h * 0.36, h * 0.8 - textH);
    final blockH = side + textH;
    final top = (h - blockH) / 2;
    final above = config.textPosition == AudioVisualizerTextPosition.above;
    final badge = Rect.fromLTWH(left.center.dx - side / 2, above ? top + textH : top, side, side);
    final rr = RRect.fromRectAndRadius(badge, Radius.circular(side * 0.14));
    if (leftImage != null && config.left != AudioVisualizerLeft.glyph) {
      canvas.save();
      canvas.clipRRect(rr);
      _drawCover(canvas, leftImage, badge);
      canvas.restore();
    } else {
      canvas.drawRRect(rr, Paint()..color = onBg.withValues(alpha: 0.09));
      final glyph = TextPainter(
        text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: side * 0.6, color: config.barColor)),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(canvas, badge.center - Offset(glyph.width / 2, glyph.height / 2));
    }
    var y = above ? top : badge.bottom + gap;
    for (final t in lines) {
      t.paint(canvas, Offset(left.center.dx - t.width / 2, y));
      y += t.height + gap;
    }
    areaLeft = left.right;
  }
  final area = Rect.fromLTRB(areaLeft, h * 0.16, w - h * 0.08, h * 0.84);
  final n = spectrum.length;
  final p = progress.clamp(0.0, 1.0);
  final mirror = config.style == AudioVisualizerStyle.mirror;
  // シークバーの高さ: 対称なら列の中央、ほかは列の下。
  final seekY = mirror ? area.center.dy : area.bottom;
  final reach = mirror ? area.height / 2 - h * 0.02 : area.height - h * 0.03;
  final bar = Paint()..color = config.barColor;
  if (n > 0) {
    final step = area.width / n;
    if (config.style == AudioVisualizerStyle.line) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final x = area.left + (i + 0.5) * step, y = seekY - h * 0.02 - reach * spectrum[i].clamp(0.0, 1.0);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
          path,
          Paint()
            ..color = config.barColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = h * 0.008
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round);
    } else {
      final bw = step * 0.64;
      for (var i = 0; i < n; i++) {
        final x = area.left + i * step + (step - bw) / 2;
        final len = math.max(h * 0.006, reach * spectrum[i].clamp(0.0, 1.0));
        final r = mirror ? Rect.fromLTRB(x, seekY - h * 0.02 - len, x + bw, seekY + h * 0.02 + len) : Rect.fromLTRB(x, seekY - h * 0.02 - len, x + bw, seekY - h * 0.02);
        canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(bw / 2)), bar);
      }
    }
  }
  // シークバー: 溝 + 再生済み + つまみ(背景が動画のときは溝を背景色で抜かない)。
  final track = Rect.fromLTRB(area.left, seekY - h * 0.006, area.right, seekY + h * 0.006);
  if (background == null) canvas.drawRect(track.inflate(h * 0.012), Paint()..color = bg);
  canvas.drawRRect(RRect.fromRectAndRadius(track, Radius.circular(h * 0.006)), Paint()..color = onBg.withValues(alpha: background == null ? 0.22 : 0.4));
  canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(track.left, track.top, track.left + track.width * p, track.bottom), Radius.circular(h * 0.006)), bar);
  canvas.drawCircle(Offset(track.left + track.width * p, seekY), h * 0.016, Paint()..color = onBg);
  // フェード(黒から / 黒へ)。
  if (fade < 1) canvas.drawRect(full, Paint()..color = const Color(0xFF000000).withValues(alpha: (1 - fade).clamp(0.0, 1.0)));
}

/// 1 フレームを PNG に(本番は設定の [AudioVisualizerConfig.paintSize]。テストは小さく描ける)。
Future<Uint8List> renderAudioFramePng({required List<double> spectrum, required double progress, AudioVisualizerConfig config = const AudioVisualizerConfig(), ui.Size? size, String? title, ui.Image? background, ui.Image? leftImage, double fade = 1}) async {
  final s = size ?? config.paintSize;
  final rec = ui.PictureRecorder();
  paintAudioFrame(Canvas(rec), s, spectrum: spectrum, progress: progress, config: config, title: title, background: background, leftImage: leftImage, fade: fade);
  final pic = rec.endRecording();
  final img = await pic.toImage(s.width.round(), s.height.round());
  pic.dispose();
  try {
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    img.dispose();
  }
}

/// この端末で変換できるか(pro_video_editor の 音声の取り出し / StopMotion は Android / iOS / macOS)。
bool get audioVideoSupported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

/// 音声ファイル → 標本(WAV ならそのまま読む。ほかは端末ネイティブで WAV に取り出す)。
Future<AudioPcm> loadAudioPcm(File audio, Directory workDir) async {
  if (audio.path.toLowerCase().endsWith('.wav')) {
    try {
      return AudioPcm.parseWav(await audio.readAsBytes());
    } on FormatException {
      // 圧縮入りの WAV など: 取り出しへ。
    }
  }
  await workDir.create(recursive: true);
  final wav = '${workDir.path}/rasq_audio_${DateTime.now().microsecondsSinceEpoch}.wav';
  try {
    await pve.ProVideoEditor.instance.extractAudioToFile(wav, pve.AudioExtractConfigs(video: pve.EditorVideo.file(audio.path), format: pve.AudioFormat.wav));
    return AudioPcm.parseWav(await File(wav).readAsBytes());
  } finally {
    try {
      await File(wav).delete();
    } catch (_) {}
  }
}

/// 画像のバイト列 → [ui.Image](失敗は null)。
Future<ui.Image?> decodeUiImage(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } catch (_) {
    return null;
  }
}

/// 背景の動画のコマを、まとめて取り出す単位と、取り出す間隔(背景は毎フレームでなくてよい: 最大 15fps)。
const _bgBatch = 48;
const audioBackgroundMaxFps = 15.0;

/// 標本 + 設定 → 動画ファイル(mp4)。[workDir] に途中のファイル(フレーム / 無音の動画)を作り、終わったら消す。
/// [leftImage] = 左の絵(呼び出し側が用意。null なら音符)。背景の動画は設定のパスから、その瞬間のコマを取り出して描く
/// (短ければループ)。[onProgress] = 0..1(フレーム作り 0〜0.7、書き出し 0.7〜1)。
Future<File> buildAudioVisualizerVideo({required File audio, required AudioPcm pcm, required Directory workDir, AudioVisualizerConfig config = const AudioVisualizerConfig(), String? title, ui.Image? leftImage, void Function(double progress)? onProgress, bool Function()? cancelled}) async {
  if (!audioVideoSupported) throw UnsupportedError('この端末では音声を動画にできません(Android / iOS / macOS だけ)');
  final id = DateTime.now().microsecondsSinceEpoch;
  final dir = Directory('${workDir.path}/rasq_audio_$id');
  await dir.create(recursive: true);
  ui.Image? bgImage;
  try {
    final total = pcm.duration;
    final plan = audioFramePlan(total, fps: config.fps);
    // 背景の動画: 長さを調べて、取り出す時刻(ループ込み)を決める。読めなければ背景なしで続ける。
    final bgPath = config.backgroundVideoPath;
    pve.EditorVideo? bgVideo;
    var bgDuration = Duration.zero;
    if (bgPath != null && File(bgPath).existsSync()) {
      try {
        bgVideo = pve.EditorVideo.file(bgPath);
        bgDuration = (await pve.ProVideoEditor.instance.getMetadata(bgVideo)).duration;
      } catch (_) {
        bgVideo = null;
      }
    }
    final bgEvery = bgVideo == null ? 1 : math.max(1, (plan.fps / audioBackgroundMaxFps).ceil());
    var bgQueue = <Uint8List>[];
    var bgNext = 0; // 次に取り出す「背景のコマ番号」(= フレーム番号 / bgEvery)

    final frames = <pve.StopMotionFrame>[];
    List<double>? prev;
    for (var i = 0; i < plan.frames; i++) {
      if (cancelled?.call() ?? false) throw StateError('cancelled');
      final at = plan.each * i;
      if (bgVideo != null && i % bgEvery == 0) {
        if (bgQueue.isEmpty) {
          final count = math.min(_bgBatch, ((plan.frames - i) / bgEvery).ceil());
          final stamps = [for (var k = 0; k < count; k++) audioBackgroundTimeAt(plan.each * ((bgNext + k) * bgEvery), bgDuration)];
          try {
            bgQueue = await pve.ProVideoEditor.instance.getThumbnails(pve.ThumbnailConfigs(video: bgVideo, outputSize: config.paintSize, timestamps: stamps, boxFit: pve.ThumbnailBoxFit.cover, outputFormat: pve.ThumbnailFormat.jpeg));
          } catch (_) {
            bgQueue = [];
            bgVideo = null; // 取り出せなければ、以降は背景なし
          }
          bgNext += count;
        }
        if (bgQueue.isNotEmpty) {
          final next = await decodeUiImage(bgQueue.removeAt(0));
          if (next != null) {
            bgImage?.dispose();
            bgImage = next;
          }
        }
      }
      prev = spectrumAt(pcm, at, bands: config.bands, previous: prev);
      final png = await renderAudioFramePng(spectrum: prev, progress: plan.frames == 1 ? 0 : i / (plan.frames - 1), config: config, title: title, background: bgImage, leftImage: leftImage, fade: audioFadeAt(at, total, config));
      final f = File('${dir.path}/f_${i.toString().padLeft(5, '0')}.png');
      await f.writeAsBytes(png);
      frames.add(pve.StopMotionFrame(image: pve.EditorLayerImage.file(f), duration: plan.each));
      if (i % 5 == 0) onProgress?.call(0.7 * (i + 1) / plan.frames);
    }
    final silent = '${dir.path}/silent.mp4';
    await pve.ProVideoEditor.instance.renderStopMotionToFile(silent, pve.StopMotionRenderData(id: 'rasq-audio-$id', frames: frames, frameRate: plan.fps, resolution: audioVideoSize, fit: pve.StopMotionFit.stretch, outputFormat: pve.VideoOutputFormat.mp4));
    onProgress?.call(0.88);
    final out = '${workDir.path}/rasq_audio_$id.mp4';
    await pve.ProVideoEditor.instance.renderVideoToFile(
      out,
      pve.VideoRenderData(
        id: 'rasq-audio-mux-$id',
        videoSegments: [pve.VideoSegment(video: pve.EditorVideo.file(silent))],
        audioTracks: [pve.VideoAudioTrack(path: audio.path)],
        enableAudio: true,
        outputFormat: pve.VideoOutputFormat.mp4,
      ),
    );
    onProgress?.call(1);
    return File(out);
  } finally {
    bgImage?.dispose();
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}
