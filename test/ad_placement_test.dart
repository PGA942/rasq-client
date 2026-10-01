import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/ads/ad_placement.dart';
import 'package:rasq_models/rasq_models.dart';

/// 広告の置き場所 (D-395 / Central S-060): 危ない中身の隣に広告を置かない。
void main() {
  /// [unsafe] の位置だけ危ない並びの、広告のすき間。
  List<int> gaps(int n, {Set<int> unsafe = const {}, int every = 5}) => adGaps(n, (i) => !unsafe.contains(i), every: every);

  /// すき間を入れた並び(テストの読みやすさのため)。
  String laid(int n, List<int> g, {Set<int> unsafe = const {}}) => [
        for (var i = 0; i < n; i++) ...[
          if (g.contains(i)) 'ad',
          unsafe.contains(i) ? 'x$i' : '$i',
        ],
      ].join(' ');

  test('すべて安全なら every 個ごと。最後のあとには置かない', () {
    expect(gaps(6), [5]);
    expect(gaps(5), isEmpty, reason: '最後の項目のあと');
    expect(gaps(11), [5, 10]);
    expect(gaps(10), [5]);
    expect(gaps(0), isEmpty);
    expect(gaps(1), isEmpty);
    expect(gaps(4, every: 1), [1, 2, 3]);
  });

  test('予定の所が危なければ次の安全な所へずらし、置いた所から数え直す', () {
    // 項目 4 が危ない → 4|5 も 5 の前も置けない(4 の直後)。5|6 へ。
    expect(laid(12, gaps(12, unsafe: {4}), unsafe: {4}), '0 1 2 3 x4 5 ad 6 7 8 9 10 ad 11');
    // 項目 5 が危ない → 4|5 も 5|6 も置けない → 6|7。
    expect(laid(13, gaps(13, unsafe: {5}), unsafe: {5}), '0 1 2 3 4 x5 6 ad 7 8 9 10 11 ad 12');
    // 続けて危ない所はまとめて飛ばす。
    expect(laid(10, gaps(10, unsafe: {4, 5, 6}), unsafe: {4, 5, 6}), '0 1 2 3 x4 x5 x6 7 ad 8 9');
  });

  test('広告の両隣は必ず安全', () {
    for (final unsafe in [
      {0},
      {4},
      {5},
      {1, 3, 5, 7, 9, 11},
      {4, 9, 14},
      {5, 6, 7, 8},
    ]) {
      for (final n in [6, 10, 16, 23]) {
        for (final g in gaps(n, unsafe: unsafe)) {
          expect(unsafe.contains(g - 1) || unsafe.contains(g), isFalse, reason: 'n=$n unsafe=$unsafe gap=$g');
          expect(g, lessThan(n), reason: '最後のあとには置かない');
        }
      }
    }
  });

  test('危ない所でずれて最後まで来たら置かない', () {
    expect(gaps(7, unsafe: {4, 5, 6}), isEmpty);
    expect(gaps(6, unsafe: {5}), isEmpty);
  });

  test('投稿 (postAdSafe): CW / センシティブな画像があれば置かない。引用も見る', () {
    final account = const AccountId(kind: SnsKind.misskey, instance: 'misskey.test', handle: 'me');
    final author = UserSummary(id: 'u1', account: account, displayName: 'u1');
    Post post({String? cw, bool sensitive = false, Post? quote}) => Post(
          id: 'p',
          account: account,
          author: author,
          createdAt: DateTime(2026, 10, 1),
          body: 'こんにちは',
          contentWarning: cw,
          media: [MediaItem(id: 'm', type: MediaType.image, url: Uri.parse('https://x.test/a.png'), sensitive: sensitive)],
          quote: quote,
        );
    expect(postAdSafe(post()), isTrue);
    expect(postAdSafe(post(cw: 'ネタバレ')), isFalse);
    expect(postAdSafe(post(cw: '  ')), isTrue, reason: '空の CW は無いのと同じ');
    expect(postAdSafe(post(sensitive: true)), isFalse);
    expect(postAdSafe(post(quote: post(sensitive: true))), isFalse);
    expect(postAdSafe(post(quote: post())), isTrue);
  });
}
