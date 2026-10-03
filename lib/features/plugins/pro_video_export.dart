import 'package:pro_image_editor/pro_image_editor.dart' show CompleteParameters;
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// 動画の書き出し (D-174 → D-420) の決めごと。pro_image_editor の「完了」から pro_video_editor へ渡す値を作る。
///
/// D-420: **Swing に貼った動画が 180° 回って届く**のを直した。原因は 2 つ。
/// 1. **手を入れていない動画まで書き出し直していた**。iPhone などの縦の動画は、画素は横のまま、コンテナ (`tkhd` の行列 /
///    `preferredTransform`) に「90° 回して見せる」と書いてある。書き出し直すと、この向きをネイティブの書き出し(HDR → SDR の
///    前変換・合成)が解いて焼き直すので、端末 / 形式によっては向きが二重に掛かる。→ 何も変えていなければ**元のファイルを
///    そのまま返す**([proVideoNeedsRender])。向きの印はそのまま残り、再生する側(video_player)が 1 回だけ回す。
/// 2. **回転の向きを二重に反転していた**: `ExportTransform.rotateTurns` は時計回りの回数で、反転(`4 - n`)は
///    pro_video_editor のネイティブの側が自分でする(`ApplyRotation.swift` / `EffectsProcessor.kt`)。こちらでも
///    `4 - n` していたので、90° / 270° 回すと逆向き = **180° ずれて**書き出されていた。→ そのまま渡す([proVideoExportTransform])。

/// そのまま返してよい入れ物(Apple / Android の再生器がそのまま読める)。それ以外(webm など)は従来どおり mp4 に書き出す。
const _passthroughMimes = {'video/mp4', 'video/quicktime', 'video/x-m4v'};

/// 色の行列が何もしない(恒等)か。
bool _identityMatrix(List<double> m) {
  const id = [1.0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  if (m.length != id.length) return false;
  for (var i = 0; i < id.length; i++) {
    if ((m[i] - id[i]).abs() > 1e-6) return false;
  }
  return true;
}

/// 色フィルター / 調整を掛けたか。
bool proVideoHasColor(CompleteParameters p) => !_identityMatrix(p.colorFiltersCombined);

/// 書き出し直す必要があるか (D-420)。false = 元のファイルのまま使える(トリム・レイヤー・ぼかし・色・変形・音を消す・
/// 差し替えた音、のどれも無い)。[duration] = 元の長さ(トリムの終わりが末尾かどうか)。
bool proVideoNeedsRender(CompleteParameters p, {required String mimeType, required Duration? duration, bool audioEnabled = true}) {
  if (!_passthroughMimes.contains(mimeType.toLowerCase())) return true;
  if (p.isTransformed || p.layers.isNotEmpty || p.blur > 0 || proVideoHasColor(p)) return true;
  if (!audioEnabled || p.audioTracks.isNotEmpty) return true;
  final start = p.startTime;
  if (start != null && start > const Duration(milliseconds: 50)) return true;
  final end = p.endTime;
  if (end != null && (duration == null || end < duration - const Duration(milliseconds: 50))) return true;
  return false;
}

/// クロップ / 回転 / 反転 (D-174)。手を入れていなければ null。
/// `rotateTurns` は**そのまま**渡す(時計回りの回数。ネイティブの側が座標系に合わせて反転する。D-420 の 2)。
pve.ExportTransform? proVideoExportTransform(CompleteParameters p) => p.isTransformed
    ? pve.ExportTransform(width: p.cropWidth, height: p.cropHeight, rotateTurns: ((p.rotateTurns % 4) + 4) % 4, x: p.cropX, y: p.cropY, flipX: p.flipX, flipY: p.flipY)
    : null;

/// 色フィルター(恒等なら無し: 合成の経路を通さない)。
List<pve.ColorFilter> proVideoColorFilters(CompleteParameters p) => proVideoHasColor(p) ? [pve.ColorFilter(matrix: p.colorFiltersCombined)] : const [];
