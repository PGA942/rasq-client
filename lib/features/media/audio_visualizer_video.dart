import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// 音声だけのファイルを動画にする (D-250)。
///
/// 加工画面は動画のエディターなので、音声(`audio/*`)は開くときに **2560×1440 の動画**へ変換する:
/// 左に黒地 + アイコン、右に Wave Visualizer(再生位置までアクセント色、その先は灰色のバー + 再生位置の線)。
///
/// 流れ(端末ネイティブ = Android / iOS / macOS だけ。pro_video_editor の Waveform / StopMotion が要る):
/// 1. `getWaveform` で音量の包絡を取る
/// 2. フレームを `dart:ui` で描いて PNG に(枚数は [audioFramePlan] で抑える)
/// 3. `renderStopMotionToFile` で無音の動画に
/// 4. `renderVideoToFile` で元の音声を重ねて mp4 に
///
/// フレームの絵([paintAudioFrame])と枚数の計画([audioFramePlan])は純 Dart(テストできる)。
const audioVideoSize = ui.Size(2560, 1440);

/// Visualizer のバーの本数(右半分に並ぶ)。
const audioVisualizerBars = 96;

/// フレームの上限(2560×1440 の PNG を描いて渡すので、長い音声ほど間引く)。
const audioMaxFrames = 360;

/// フレームの割り当て: 短い音声は 8fps、長い音声は [audioMaxFrames] 枚に収まるまで 1 枚を長く持たせる。
({int frames, Duration each}) audioFramePlan(Duration total) {
  final ms = math.max(total.inMilliseconds, 1000);
  final frames = (ms / 125).ceil().clamp(1, audioMaxFrames);
  return (frames: frames, each: Duration(microseconds: (ms * 1000 / frames).round()));
}

/// 波形(0..1 の包絡)を [bars] 本のバーの高さ(0..1)へ。区間ごとの最大値、全体の最大で正規化。
List<double> audioBars(List<double> envelope, {int bars = audioVisualizerBars}) {
  if (envelope.isEmpty) return List.filled(bars, 0);
  final out = List<double>.filled(bars, 0);
  for (var i = 0; i < bars; i++) {
    final a = (i * envelope.length / bars).floor();
    final b = math.max(a + 1, ((i + 1) * envelope.length / bars).floor());
    var peak = 0.0;
    for (var k = a; k < b && k < envelope.length; k++) {
      peak = math.max(peak, envelope[k].abs());
    }
    out[i] = peak;
  }
  final top = out.reduce(math.max);
  return top <= 0 ? out : [for (final v in out) v / top];
}

/// 1 フレームを描く。[progress] = 再生位置(0..1)。
void paintAudioFrame(Canvas canvas, ui.Size size, {required List<double> bars, required double progress, Color accent = const Color(0xFF4F8DFD), IconData icon = Icons.music_note_rounded, String? title}) {
  final w = size.width, h = size.height;
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF000000));
  // 左: 黒地にアイコン(角丸の枠の中)。
  final left = Rect.fromLTWH(0, 0, w / 2, h);
  final badge = Rect.fromCenter(center: left.center, width: h * 0.42, height: h * 0.42);
  canvas.drawRRect(RRect.fromRectAndRadius(badge, Radius.circular(h * 0.06)), Paint()..color = const Color(0xFF16181C));
  final glyph = TextPainter(
    text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: h * 0.26, color: accent)),
    textDirection: TextDirection.ltr,
  )..layout();
  glyph.paint(canvas, badge.center - Offset(glyph.width / 2, glyph.height / 2));
  if (title != null && title.isNotEmpty) {
    final t = TextPainter(
      text: TextSpan(text: title, style: TextStyle(fontSize: h * 0.034, color: const Color(0xB3FFFFFF))),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: w / 2 - h * 0.16);
    t.paint(canvas, Offset(left.center.dx - t.width / 2, badge.bottom + h * 0.05));
  }
  // 右: Wave Visualizer(中央線から上下に伸びるバー)。
  final area = Rect.fromLTWH(w / 2 + h * 0.04, h * 0.18, w / 2 - h * 0.12, h * 0.64);
  final n = bars.length;
  if (n == 0) return;
  final step = area.width / n;
  final bw = step * 0.62;
  final p = progress.clamp(0.0, 1.0);
  final played = Paint()..color = accent;
  final rest = Paint()..color = const Color(0xFF3A3F47);
  for (var i = 0; i < n; i++) {
    final x = area.left + i * step + (step - bw) / 2;
    // 再生位置のまわりのバーは少し持ち上げる(動いて見えるように)。
    final near = 1 - ((i + 0.5) / n - p).abs() * 14;
    final boost = near > 0 ? 1 + 0.22 * near : 1.0;
    final half = math.max(area.height * 0.012, area.height / 2 * (bars[i] * boost).clamp(0.0, 1.0));
    final r = RRect.fromRectAndRadius(Rect.fromLTRB(x, area.center.dy - half, x + bw, area.center.dy + half), Radius.circular(bw / 2));
    canvas.drawRRect(r, (i + 0.5) / n <= p ? played : rest);
  }
  final px = area.left + area.width * p;
  canvas.drawRect(Rect.fromLTWH(px - h * 0.002, area.top - h * 0.03, h * 0.004, area.height + h * 0.06), Paint()..color = const Color(0xFFFFFFFF));
}

/// 1 フレームを PNG に(本番は [audioVideoSize]。テストは小さく描ける)。
Future<Uint8List> renderAudioFramePng({required List<double> bars, required double progress, ui.Size size = audioVideoSize, Color accent = const Color(0xFF4F8DFD), String? title}) async {
  final rec = ui.PictureRecorder();
  paintAudioFrame(Canvas(rec), size, bars: bars, progress: progress, accent: accent, title: title);
  final pic = rec.endRecording();
  final img = await pic.toImage(size.width.round(), size.height.round());
  pic.dispose();
  try {
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    img.dispose();
  }
}

/// この端末で変換できるか(pro_video_editor の Waveform / StopMotion は Android / iOS / macOS)。
bool get audioVideoSupported => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

/// 音声ファイル → 動画ファイル(mp4)。[workDir] に途中のファイル(フレーム / 無音の動画)を作り、終わったら消す。
/// [onProgress] = 0..1(フレーム作り 0〜0.6、書き出し 0.6〜1)。
Future<File> buildAudioVisualizerVideo({required File audio, required Directory workDir, String? title, Color accent = const Color(0xFF4F8DFD), void Function(double progress)? onProgress}) async {
  if (!audioVideoSupported) throw UnsupportedError('この端末では音声を動画にできません(Android / iOS / macOS だけ)');
  final id = DateTime.now().microsecondsSinceEpoch;
  final dir = Directory('${workDir.path}/rasq_audio_$id');
  await dir.create(recursive: true);
  try {
    final source = pve.EditorVideo.file(audio.path);
    final wave = await pve.ProVideoEditor.instance.getWaveform(pve.WaveformConfigs(video: source, resolution: pve.WaveformResolution.low));
    final right = wave.rightChannel;
    final envelope = [
      for (var i = 0; i < wave.leftChannel.length; i++) math.max(wave.leftChannel[i].abs(), right == null || i >= right.length ? 0.0 : right[i].abs()).toDouble(),
    ];
    final bars = audioBars(envelope);
    final plan = audioFramePlan(wave.duration);
    final frames = <pve.StopMotionFrame>[];
    for (var i = 0; i < plan.frames; i++) {
      final png = await renderAudioFramePng(bars: bars, progress: plan.frames == 1 ? 0 : i / (plan.frames - 1), accent: accent, title: title);
      final f = File('${dir.path}/f_${i.toString().padLeft(4, '0')}.png');
      await f.writeAsBytes(png, flush: true);
      frames.add(pve.StopMotionFrame(image: pve.EditorLayerImage.file(f), duration: plan.each));
      onProgress?.call(0.6 * (i + 1) / plan.frames);
    }
    final silent = '${dir.path}/silent.mp4';
    await pve.ProVideoEditor.instance.renderStopMotionToFile(silent, pve.StopMotionRenderData(id: 'rasq-audio-$id', frames: frames, frameRate: 8, resolution: audioVideoSize, fit: pve.StopMotionFit.stretch, outputFormat: pve.VideoOutputFormat.mp4));
    onProgress?.call(0.8);
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
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}
