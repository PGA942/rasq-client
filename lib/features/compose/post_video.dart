import 'dart:io';
import 'dart:typed_data';
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

/// 加工画面の「動画に変換しますか?」に添える説明。
String postMotionNote(PostMotion m) => switch (m) {
      PostMotion.video => 'この投稿には動画が付いています。',
      PostMotion.audio => 'この投稿には音声が付いています。',
      PostMotion.animated => 'この投稿には動く絵(GIF / 動く MFM)があります。',
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

/// 中身の先頭から、入れ物の拡張子を当てる(URL / ファイル名に拡張子が無い・違うことがある。AVFoundation は拡張子も見る)。
/// 分からなければ null。
String? mediaContainerExt(List<int> b) {
  bool at(int i, String s) => b.length >= i + s.length && String.fromCharCodes(b.sublist(i, i + s.length)) == s;
  if (at(4, 'ftyp')) {
    if (at(8, 'qt  ')) return 'mov';
    if (at(8, 'M4A ') || at(8, 'M4B ')) return 'm4a';
    return 'mp4';
  }
  if (b.length >= 4 && b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) return 'webm';
  if (at(0, 'OggS')) return 'ogg';
  if (at(0, 'fLaC')) return 'flac';
  if (at(0, 'RIFF') && at(8, 'WAVE')) return 'wav';
  if (at(0, 'RIFF') && at(8, 'AVI ')) return 'avi';
  if (at(0, 'ID3') || (b.length >= 2 && b[0] == 0xFF && (b[1] & 0xE0) == 0xE0)) return 'mp3';
  return null;
}

/// Apple の端末(AVFoundation)が読めない入れ物。
const _appleUnreadable = {'webm', 'ogg', 'avi', 'flac'};

/// 段ごとに、どこで失敗したかを付ける(端末のエラーは中身が分からないことが多い)。
Future<T> _stage<T>(String what, Future<T> Function() run) async {
  try {
    return await run();
  } catch (e) {
    throw StateError('$what: $e');
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
    final named = (item.fileName ?? item.url.path).split('.').last.toLowerCase();
    var source = await _stage('元のファイルを取得できませんでした', () => _download(item.url, File('${dir.path}/source.bin')));
    // 拡張子は中身から決める(無ければ名前、それも無ければ mp4 / m4a)。
    final head = await source.openRead(0, 16).fold<List<int>>([], (a, c) => a..addAll(c));
    final ext = mediaContainerExt(head) ?? (RegExp(r'^[a-z0-9]{1,5}$').hasMatch(named) ? named : (motion == PostMotion.video ? 'mp4' : 'm4a'));
    if ((Platform.isMacOS || Platform.isIOS) && _appleUnreadable.contains(ext)) throw StateError('この端末は $ext 形式を読めません(静止画なら貼れます)');
    source = await source.rename('${dir.path}/source.$ext');
    onProgress?.call(0.35);
    final length = _cap((await _stage('元のファイル(.$ext、${await source.length()} バイト)を開けませんでした', () => editor.getMetadata(pve.EditorVideo.file(source.path)))).duration);
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

/// 加工画面に置いた投稿オブジェクトの、**絵の画素での枠** (D-261)。pro_image_editor のレイヤーは「表示している絵の中心からの
/// ずれ([offset])× 表示の大きさ」で持つので、元の絵の画素へ直す。[aspect] = 高さ / 幅。回転は見ない(動く投稿は回せない)。
ui.Rect postObjectRectInImage({required ui.Size image, required ui.Size shown, required ui.Offset offset, required double width, required double aspect, required double scale}) {
  final k = shown.width <= 0 ? 1.0 : image.width / shown.width;
  final w = width * scale * k;
  final h = w * aspect;
  final center = ui.Offset(image.width / 2 + offset.dx * k, image.height / 2 + offset.dy * k);
  return ui.Rect.fromCenter(center: center, width: w, height: h);
}

/// 画面で測った枠から、絵の画素での枠へ (D-265): [reference] = 絵 / 動画が画面に出ている枠、[object] = オブジェクトが出ている枠
/// (どちらも画面の座標)。レイヤーの数値から計算するより確実(動画の加工では、表示の大きさの数値が当てにならなかった)。
ui.Rect objectRectFromScreen({required ui.Rect reference, required ui.Rect object, required ui.Size image}) {
  if (reference.width <= 0 || reference.height <= 0) return ui.Rect.zero;
  final kx = image.width / reference.width;
  final ky = image.height / reference.height;
  return ui.Rect.fromLTWH((object.left - reference.left) * kx, (object.top - reference.top) * ky, object.width * kx, object.height * ky);
}

/// 書き出す動画の大きさ: 長辺 [maxSide] まで縮めて偶数に。返り値の factor を枠にも掛ける。
({ui.Size canvas, double factor}) postCanvasFor(ui.Size image, {double maxSide = 1920}) {
  final f = image.longestSide > maxSide ? maxSide / image.longestSide : 1.0;
  return (canvas: evenPixelSize(image, f), factor: f);
}

/// 画像 + 動くオブジェクト → mp4 (D-261): 加工した画像([imagePng]、オブジェクトの静止画も焼き込み済み)を土台に、[posts] の動画をそれぞれの枠へ重ねる。
/// 長さは一番長い動画に合わせる(短いものは止まる)。音は重ねた動画のもの。
Future<File> buildImageWithPostVideos({required Uint8List imagePng, required ui.Size imageSize, required List<OverlayVideo> posts, required Directory workDir}) async {
  final id = DateTime.now().microsecondsSinceEpoch;
  final dir = Directory('${workDir.path}/rasq_postimg_$id');
  await dir.create(recursive: true);
  try {
    final editor = pve.ProVideoEditor.instance;
    final (:canvas, :factor) = postCanvasFor(imageSize);
    final still = File('${dir.path}/image.png');
    await still.writeAsBytes(imagePng);
    var length = const Duration(seconds: 1);
    for (final p in posts) {
      final raw = (await editor.getMetadata(pve.EditorVideo.file(p.video.path))).duration;
      final d = _cap(Duration(microseconds: (raw.inMicroseconds / p.speed.clamp(0.25, 4.0)).round()));
      if (d > length) length = d;
    }
    final base = File('${dir.path}/base.mp4');
    await editor.renderStopMotionToFile(base.path, pve.StopMotionRenderData(id: 'rasq-postimg-base-$id', frames: [pve.StopMotionFrame(image: pve.EditorLayerImage.file(still), duration: length)], frameRate: 10, resolution: canvas, fit: pve.StopMotionFit.stretch, outputFormat: pve.VideoOutputFormat.mp4));
    return await overlayVideosOnVideo(base: base, canvas: canvas, length: length, posts: [for (final p in posts) (video: p.video, rect: ui.Rect.fromLTWH(p.rect.left * factor, p.rect.top * factor, p.rect.width * factor, p.rect.height * factor), loop: p.loop, speed: p.speed, volume: p.volume, opacity: p.opacity)], out: File('${workDir.path}/rasq_postimg_$id.mp4'));
  } finally {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}

/// 重ねる動画 1 本ぶん (D-266): 枠(画素)と、繰り返し / 速さ / 音 / 不透明度。
typedef OverlayVideo = ({File video, ui.Rect rect, bool loop, double speed, double volume, double opacity});

/// 繰り返しの並べ方: 長さ [clip] の動画を [length] ぶん並べたときの、各回の (始まり, その回で使う長さ)。[loop] = false なら 1 回だけ。
List<({Duration start, Duration take})> overlayClipPlan(Duration clip, Duration length, {required bool loop, int maxRepeats = 60}) {
  if (clip <= Duration.zero || length <= Duration.zero) return const [];
  final plan = <({Duration start, Duration take})>[];
  var at = Duration.zero;
  while (at < length && plan.length < maxRepeats) {
    final left = length - at;
    plan.add((start: at, take: clip > left ? left : clip));
    if (!loop) break;
    at += clip;
  }
  return plan;
}

/// 動画 + 動くオブジェクト → mp4 (D-262 → D-266): 書き出し済みの動画 [base]([canvas] = その画素の大きさ、[length] = 長さ)の上へ、
/// [posts] の動画をそれぞれの枠(画素)へ重ねる。重ねる動画は頭から流し、土台より長いぶんは切る。短ければ繰り返す(設定による)。
/// 速さは合成の中では変えられないので、先に速さを変えた動画を作ってから重ねる。
Future<File> overlayVideosOnVideo({required File base, required ui.Size canvas, required Duration length, required List<OverlayVideo> posts, required File out}) async {
  final editor = pve.ProVideoEditor.instance;
  final id = DateTime.now().microsecondsSinceEpoch;
  final temp = <File>[];
  try {
    final layers = <pve.VideoLayer>[pve.VideoLayer(clips: [pve.VideoSegment(video: pve.EditorVideo.file(base.path))])];
    for (var i = 0; i < posts.length; i++) {
      final p = posts[i];
      var source = p.video;
      if ((p.speed - 1).abs() > 0.01) {
        final sped = File('${out.parent.path}/rasq_overlay_${id}_speed_$i.mp4');
        temp.add(sped);
        await editor.renderVideoToFile(sped.path, pve.VideoRenderData(id: 'rasq-overlay-speed-$id-$i', videoSegments: [pve.VideoSegment(video: pve.EditorVideo.file(source.path), playbackSpeed: p.speed)], enableAudio: true, outputFormat: pve.VideoOutputFormat.mp4));
        source = sped;
      }
      final d = (await editor.getMetadata(pve.EditorVideo.file(source.path))).duration;
      final transform = pve.SegmentTransform(offset: p.rect.topLeft, size: p.rect.size, fit: pve.SegmentFit.cover);
      layers.add(pve.VideoLayer(opacity: p.opacity.clamp(0.0, 1.0).toDouble(), clips: [
        for (final c in overlayClipPlan(d, length, loop: p.loop)) pve.VideoSegment(video: pve.EditorVideo.file(source.path), endTime: c.take, timelineStart: c.start, volume: p.volume, transform: transform),
      ]));
    }
    await editor.renderVideoToFile(out.path, pve.VideoRenderData(id: 'rasq-overlay-$id', composition: pve.VideoComposition(canvasSize: canvas, layers: layers), enableAudio: true, outputFormat: pve.VideoOutputFormat.mp4));
    return out;
  } finally {
    for (final f in temp) {
      try {
        await f.delete();
      } catch (_) {}
    }
  }
}
