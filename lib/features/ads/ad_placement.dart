import 'package:rasq_models/rasq_models.dart';

/// 広告の置き場所 (D-395 / Central S-060)。AdMob は広告の隣に出す中身もポリシーに沿っていることを求めるので、
/// **広告は危ない中身の隣(直前 / 直後)に置かない**。危ない = 通報された / CW 付き / センシティブ / 未審査のプラグイン /
/// 運営が止めた(Central の `adSafe` が false)など。Swing のビューワーと、のちに TL の投稿の下の広告で使う。
///
/// [count] 個の並びの、広告を挟む**すき間**を返す。すき間 `g` = 項目 `g - 1` と `g` の間(1 ≦ g < count)。
/// - [every] 個ごとに 1 枚。数えるのは前の広告(か先頭)からの項目の数。
/// - 両隣が [isSafe] のすき間にだけ置く。予定のすき間が危なければ、次の安全なすき間まで後ろへずらす
///   (置いたらそこから数え直す)。
/// - 最後の項目のあとには置かない。
List<int> adGaps(int count, bool Function(int i) isSafe, {required int every}) {
  assert(every > 0);
  final gaps = <int>[];
  var since = 0;
  for (var i = 0; i + 1 < count; i++) {
    since++;
    if (since >= every && isSafe(i) && isSafe(i + 1)) {
      gaps.add(i + 1);
      since = 0;
    }
  }
  return gaps;
}

/// 投稿を広告の隣に置いてよいか(TL の投稿の下の広告で使う)。CW が無く、センシティブな画像 / 動画が無い。
/// 引用している投稿も同じに見る。通報したかどうかは呼ぶ側が別に見る。
bool postAdSafe(Post p) {
  bool clean(Post q) => (q.contentWarning?.trim().isEmpty ?? true) && !q.media.any((m) => m.sensitive);
  return clean(p) && (p.quote == null || clean(p.quote!));
}
