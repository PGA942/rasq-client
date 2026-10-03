import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:rasq_client/features/plugins/pro_video_export.dart';

/// D-420: Swing に貼った動画が 180° 回って届く。
///
/// 1. 何も変えていない動画は書き出し直さない(コンテナの向きの印 = `tkhd` の行列を残す)。
/// 2. 回したときの `rotateTurns` を二重に反転しない(pro_video_editor のネイティブが `4 - n` するので、こちらはそのまま)。

/// 縦に撮った iPhone の動画と同じ向きの印を持つ、最小の mp4(ftyp + moov/trak/tkhd)。画素は横、行列で 90° 回して見せる。
Uint8List rotatedMp4Fixture({int degrees = 90}) {
  final b = BytesBuilder();
  void u32(int v) => b.add([(v >> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff]);
  void s32(int v) => u32(v & 0xffffffff);
  void tag(String t) => b.add(t.codeUnits);
  // ftyp
  u32(20);
  tag('ftyp');
  tag('isom');
  u32(0x200);
  tag('mp41');
  // moov > trak > tkhd(version 0 = 92 バイト)
  const tkhd = 92;
  u32(8 + 8 + tkhd);
  tag('moov');
  u32(8 + tkhd);
  tag('trak');
  u32(tkhd);
  tag('tkhd');
  u32(0x00000003); // version 0, flags enabled|in_movie
  u32(0); // creation
  u32(0); // modification
  u32(1); // track id
  u32(0); // reserved
  u32(1000); // duration
  u32(0);
  u32(0); // reserved[2]
  b.add([0, 0, 0, 0]); // layer, alternate group
  b.add([0, 0, 0, 0]); // volume, reserved
  final r = degrees * math.pi / 180;
  int fx(double v) => (v * 65536).round();
  // a b u / c d v / x y w(a..d は 16.16、u v w は 2.30)
  s32(fx(math.cos(r)));
  s32(fx(math.sin(r)));
  u32(0);
  s32(fx(-math.sin(r)));
  s32(fx(math.cos(r)));
  u32(0);
  s32(degrees == 90 || degrees == 180 ? fx(1920) : 0);
  s32(degrees == 180 || degrees == 270 ? fx(1080) : 0);
  u32(0x40000000);
  u32(fx(1920)); // width
  u32(fx(1080)); // height
  return b.toBytes();
}

/// `tkhd` の行列から、見せるときの回転(度、時計回り)を読む。
int? mp4DisplayRotation(Uint8List bytes) {
  final d = ByteData.sublistView(bytes);
  for (var i = 4; i + 4 <= bytes.length; i++) {
    if (String.fromCharCodes(bytes.sublist(i, i + 4)) != 'tkhd') continue;
    final version = bytes[i + 4];
    final matrix = i + 4 + 4 + (version == 1 ? 32 : 20) + 8 + 8;
    final a = d.getInt32(matrix) / 65536;
    final bb = d.getInt32(matrix + 4) / 65536;
    return ((math.atan2(bb, a) * 180 / math.pi).round() + 360) % 360;
  }
  return null;
}

CompleteParameters params({
  bool transformed = false,
  int turns = 0,
  List<Layer> layers = const [],
  double blur = 0,
  Duration? start,
  Duration? end,
  List<List<double>> filters = const [],
}) =>
    CompleteParameters(
      blur: blur,
      matrixFilterList: filters,
      matrixTuneAdjustmentsList: const [],
      startTime: start,
      endTime: end,
      cropWidth: transformed ? 1080 : null,
      cropHeight: transformed ? 1920 : null,
      rotateTurns: turns,
      cropX: transformed ? 0 : null,
      cropY: transformed ? 0 : null,
      flipX: false,
      flipY: false,
      image: Uint8List(0),
      isTransformed: transformed,
      layers: layers,
      originalImageSize: const Size(1080, 1920),
      temporaryDecodedImageSize: const Size(1080, 1920),
      bodySize: const Size(360, 780),
      editorSize: const Size(360, 640),
    );

void main() {
  test('fixture: 縦の動画(画素は横 + tkhd の行列で 90°)を読める', () {
    expect(mp4DisplayRotation(rotatedMp4Fixture()), 90);
    expect(mp4DisplayRotation(rotatedMp4Fixture(degrees: 180)), 180);
    expect(mp4DisplayRotation(rotatedMp4Fixture(degrees: 0)), 0);
  });

  test('D-420 ①: 何も変えていない動画は書き出し直さない(元のファイル = 向きの印がそのまま残る)', () {
    final video = rotatedMp4Fixture();
    const len = Duration(seconds: 12);
    // 貼っただけ(トリムの枠が末尾まで、色は恒等)。
    expect(proVideoNeedsRender(params(start: Duration.zero, end: len), mimeType: 'video/mp4', duration: len), isFalse);
    expect(proVideoNeedsRender(params(), mimeType: 'video/quicktime', duration: len), isFalse, reason: 'iPhone の .mov');
    // 書き出さない = 編集画面は元のバイト列を返す → 再生器が行列で 1 回だけ回す。
    expect(mp4DisplayRotation(video), 90, reason: '向きの印は元のまま');
    // 手を入れたら書き出す。
    expect(proVideoNeedsRender(params(transformed: true, turns: 1), mimeType: 'video/mp4', duration: len), isTrue, reason: '回した');
    expect(proVideoNeedsRender(params(layers: [TextLayer(text: 'やっほー')]), mimeType: 'video/mp4', duration: len), isTrue, reason: '文字を置いた');
    expect(proVideoNeedsRender(params(blur: 2), mimeType: 'video/mp4', duration: len), isTrue, reason: 'ぼかし');
    expect(proVideoNeedsRender(params(start: const Duration(seconds: 2)), mimeType: 'video/mp4', duration: len), isTrue, reason: '頭を切った');
    expect(proVideoNeedsRender(params(end: const Duration(seconds: 8)), mimeType: 'video/mp4', duration: len), isTrue, reason: '尻を切った');
    final sepia = [0.39, 0.77, 0.19, 0, 0, 0.35, 0.69, 0.17, 0, 0, 0.27, 0.53, 0.13, 0, 0, 0, 0, 0, 1, 0].map((e) => e.toDouble()).toList();
    expect(proVideoNeedsRender(params(filters: [sepia]), mimeType: 'video/mp4', duration: len), isTrue, reason: '色フィルター');
    expect(proVideoNeedsRender(params(), mimeType: 'video/mp4', duration: len, audioEnabled: false), isTrue, reason: '音を消した');
    expect(proVideoNeedsRender(params(), mimeType: 'video/webm', duration: len), isTrue, reason: 'Apple で読めない入れ物は mp4 に');
    // 恒等の色は合成の経路を通さない。
    expect(proVideoColorFilters(params()), isEmpty);
    expect(proVideoColorFilters(params(filters: [sepia])), hasLength(1));
  });

  test('D-420 ②: 回転は時計回りの回数をそのまま渡す(ネイティブが反転する。こちらで 4 - n すると 90° / 270° が 180° ずれる)', () {
    expect(proVideoExportTransform(params()), isNull, reason: '回していなければ変形なし');
    expect(proVideoExportTransform(params(transformed: true, turns: 1))!.rotateTurns, 1, reason: '右に 1 回 = 1(以前は 3 = 逆向き)');
    expect(proVideoExportTransform(params(transformed: true, turns: -1))!.rotateTurns, 3, reason: '左に 1 回 = 右に 3 回');
    expect(proVideoExportTransform(params(transformed: true, turns: 2))!.rotateTurns, 2);
    expect(proVideoExportTransform(params(transformed: true))!.rotateTurns, 0, reason: 'クロップだけなら回さない(以前は 4)');
    // ネイティブ(ApplyRotation.swift / EffectsProcessor.kt)の反転と組み合わせた向き: 右に 1 回は、反時計回り 270° = 時計回り 90°。
    int nativeCcwDegrees(int turns) => ((4 - ((turns % 4) + 4) % 4) % 4) * 90;
    for (final t in [0, 1, 2, 3, -1]) {
      final sent = proVideoExportTransform(params(transformed: true, turns: t))!.rotateTurns;
      expect((360 - nativeCcwDegrees(sent)) % 360, ((t % 4 + 4) % 4) * 90, reason: '$t 回 → 書き出しも同じ向き');
    }
  });
}
