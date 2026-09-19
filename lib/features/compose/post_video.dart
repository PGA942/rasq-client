import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

/// 投稿タイルの動画化 (D-260): 「ノート画像の追加」で選んだ投稿が**動く / 鳴る**なら、静止画ではなく動画(mp4)にできる。
///
/// | 種類 | 中身 | 作り方 |
/// |---|---|---|
/// | [PostMotion.video] | 動画が 1 本付いた投稿 | タイルの静止画を土台に、**メディアの枠の位置へ元の動画を重ねる**(音も入る) |
/// | [PostMotion.audio] | 音声ファイルが付いた投稿 | タイルの静止画を音声の長さぶん出して、音声を重ねる |
/// | [PostMotion.animated] | GIF / 動く MFM(spin / jump / rainbow …) | 画面で動いているタイルを**コマ撮り**(12fps、4 秒)。音は無い |
///
/// 端末ネイティブ(Android / iOS / macOS、pro_video_editor)だけ。判定と寸法の計算は純 Dart(テストできる)。
enum PostMotion { none, video, audio, animated }

const _animatedMfm = {'shake', 'spin', 'jump', 'bounce', 'rainbow', 'twitch', 'jelly', 'tada'};
const _audioExt = {'mp3', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'opus', 'flac'};

/// 動画の長さの上限(元の動画 / 音声が長くても、ここまで)。
const postVideoMaxDuration = Duration(seconds: 60);

/// コマ撮りの長さと速さ。
const postAnimatedDuration = Duration(seconds: 4);
const postAnimatedFps = 12;

bool isAudioMedia(MediaItem m) {
  if (m.type != MediaType.file) return false;
  final name = (m.fileName ?? (m.url.pathSegments.isEmpty ? '' : m.url.pathSegments.last)).toLowerCase();
  final dot = name.lastIndexOf('.');
  return dot >= 0 && _audioExt.contains(name.substring(dot + 1));
}

/// 本文に動く MFM(`$[spin …]` など)があるか。
bool hasAnimatedMfm(String body) {
  for (final m in RegExp(r'\$\[([a-z0-9]+)').allMatches(body)) {
    if (_animatedMfm.contains(m.group(1))) return true;
  }
  return false;
}

/// その投稿をどう動画にするか。動画は「1 本だけ付いている」ときだけ重ねる(複数のメディアの枠の位置は、外からは分からない)。
PostMotion postMotionOf(Post p) {
  final videos = [for (final m in p.media) if (m.type == MediaType.video) m];
  if (videos.length == 1 && p.media.length == 1) return PostMotion.video;
  if (p.media.any(isAudioMedia)) return PostMotion.audio;
  if (p.media.any((m) => m.type == MediaType.gif) || hasAnimatedMfm(p.body)) return PostMotion.animated;
  return PostMotion.none;
}

String postMotionLabel(PostMotion m) => switch (m) {
      PostMotion.video => '動画にする(付いている動画を、タイルの中で再生。音つき)',
      PostMotion.audio => '動画にする(タイルの静止画 + 付いている音声)',
      PostMotion.animated => '動画にする(動いている様子を $postAnimatedFps コマ/秒で ${postAnimatedDuration.inSeconds} 秒)',
      PostMotion.none => '',
    };

/// 動画の大きさは偶数の画素(コーデックの都合)。
ui.Size evenPixelSize(ui.Size logical, double pixelRatio) {
  int even(double v) => (v * pixelRatio).round() & ~1;
  return ui.Size(even(logical.width).clamp(2, 8192).toDouble(), even(logical.height).clamp(2, 8192).toDouble());
}

/// タイルの中のメディアの枠(画素、タイルの左上が原点)。見つからなければ null。
ui.Rect? mediaRectInTile(GlobalKey boundaryKey, double pixelRatio) {
  final root = boundaryKey.currentContext;
  final rootBox = root?.findRenderObject();
  if (root == null || rootBox is! RenderBox) return null;
  RenderBox? found;
  void visit(Element e) {
    if (found != null) return;
    if (e.widget is RasqMediaGrid) {
      final box = e.findRenderObject();
      if (box is RenderBox && box.hasSize) found = box;
      return;
    }
    e.visitChildren(visit);
  }

  (root as Element).visitChildren(visit);
  final box = found;
  if (box == null) return null;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: rootBox);
  return ui.Rect.fromLTWH(topLeft.dx * pixelRatio, topLeft.dy * pixelRatio, box.size.width * pixelRatio, box.size.height * pixelRatio);
}

Future<ui.Image?> _capture(GlobalKey boundaryKey, double pixelRatio) async {
  final box = boundaryKey.currentContext?.findRenderObject();
  return box is RenderRepaintBoundary ? box.toImage(pixelRatio: pixelRatio) : null;
}

Future<File?> _capturePng(GlobalKey boundaryKey, double pixelRatio, File out) async {
  final image = await _capture(boundaryKey, pixelRatio);
  if (image == null) return null;
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    await out.writeAsBytes(data.buffer.asUint8List());
    return out;
  } finally {
    image.dispose();
  }
}

Future<File> _download(Uri url, File out) async {
  final res = await http.get(url).timeout(const Duration(seconds: 60));
  if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: url);
  await out.writeAsBytes(res.bodyBytes, flush: true);
  return out;
}

Duration _cap(Duration d) => d > postVideoMaxDuration ? postVideoMaxDuration : (d < const Duration(seconds: 1) ? const Duration(seconds: 1) : d);

/// 投稿タイル → mp4。[boundaryKey] = 画面に出ているタイル。[onProgress] = 0..1。
Future<File> buildPostVideo({required Post post, required PostMotion motion, required GlobalKey boundaryKey, required Directory workDir, double pixelRatio = 2, void Function(double progress)? onProgress, bool Function()? cancelled}) async {
  final id = DateTime.now().microsecondsSinceEpoch;
  final dir = Directory('${workDir.path}/rasq_post_$id');
  await dir.create(recursive: true);
  final out = '${workDir.path}/rasq_post_$id.mp4';
  try {
    final box = boundaryKey.currentContext?.findRenderObject();
    if (box is! RenderBox) throw StateError('投稿が画面に出ていません');
    final canvas = evenPixelSize(box.size, pixelRatio);
    final editor = pve.ProVideoEditor.instance;

    if (motion == PostMotion.animated) {
      // 画面で動いているタイルをコマ撮り(アニメーションは実時間で進むので、コマの間は待つ)。
      final count = postAnimatedDuration.inSeconds * postAnimatedFps;
      final each = Duration(microseconds: 1000000 ~/ postAnimatedFps);
      final frames = <pve.StopMotionFrame>[];
      final clock = Stopwatch()..start();
      for (var i = 0; i < count; i++) {
        if (cancelled?.call() ?? false) throw StateError('cancelled');
        final f = await _capturePng(boundaryKey, pixelRatio, File('${dir.path}/f_${i.toString().padLeft(4, '0')}.png'));
        if (f == null) throw StateError('投稿が画面に出ていません');
        frames.add(pve.StopMotionFrame(image: pve.EditorLayerImage.file(f), duration: each));
        onProgress?.call(0.7 * (i + 1) / count);
        final wait = each * (i + 1) - clock.elapsed;
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      await editor.renderStopMotionToFile(out, pve.StopMotionRenderData(id: 'rasq-post-$id', frames: frames, frameRate: postAnimatedFps.toDouble(), resolution: canvas, fit: pve.StopMotionFit.stretch, outputFormat: pve.VideoOutputFormat.mp4));
      onProgress?.call(1);
      return File(out);
    }

    // 動画 / 音声: タイルの静止画 1 枚を、元の長さぶんの動画にして土台にする。
    final item = motion == PostMotion.video ? post.media.firstWhere((m) => m.type == MediaType.video) : post.media.firstWhere(isAudioMedia);
    final rect = motion == PostMotion.video ? mediaRectInTile(boundaryKey, pixelRatio) : null;
    final still = await _capturePng(boundaryKey, pixelRatio, File('${dir.path}/tile.png'));
    if (still == null) throw StateError('投稿が画面に出ていません');
    onProgress?.call(0.1);
    final ext = (item.fileName ?? item.url.path).split('.').last.toLowerCase();
    final source = await _download(item.url, File('${dir.path}/source.${RegExp(r'^[a-z0-9]{1,5}$').hasMatch(ext) ? ext : (motion == PostMotion.video ? 'mp4' : 'm4a')}'));
    onProgress?.call(0.35);
    final length = _cap((await editor.getMetadata(pve.EditorVideo.file(source.path))).duration);
    final base = '${dir.path}/base.mp4';
    await editor.renderStopMotionToFile(base, pve.StopMotionRenderData(id: 'rasq-post-base-$id', frames: [pve.StopMotionFrame(image: pve.EditorLayerImage.file(still), duration: length)], frameRate: 10, resolution: canvas, fit: pve.StopMotionFit.stretch, outputFormat: pve.VideoOutputFormat.mp4));
    onProgress?.call(0.6);
    if (motion == PostMotion.audio || rect == null) {
      // 音声(か、メディアの枠が見つからなかった動画): 土台に音だけ重ねる。
      await editor.renderVideoToFile(out, pve.VideoRenderData(id: 'rasq-post-mux-$id', videoSegments: [pve.VideoSegment(video: pve.EditorVideo.file(base))], audioTracks: [pve.VideoAudioTrack(path: source.path, audioEndTime: length)], enableAudio: true, outputFormat: pve.VideoOutputFormat.mp4));
    } else {
      // 動画: メディアの枠の位置へ、元の動画を重ねる(枠いっぱいに cover。音は元の動画のもの)。
      await editor.renderVideoToFile(
        out,
        pve.VideoRenderData(
          id: 'rasq-post-comp-$id',
          composition: pve.VideoComposition(canvasSize: canvas, layers: [
            pve.VideoLayer(clips: [pve.VideoSegment(video: pve.EditorVideo.file(base))]),
            pve.VideoLayer(clips: [pve.VideoSegment(video: pve.EditorVideo.file(source.path), endTime: length, transform: pve.SegmentTransform(offset: rect.topLeft, size: rect.size, fit: pve.SegmentFit.cover))]),
          ]),
          enableAudio: true,
          outputFormat: pve.VideoOutputFormat.mp4,
        ),
      );
    }
    onProgress?.call(1);
    return File(out);
  } finally {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}
