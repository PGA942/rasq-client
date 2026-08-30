import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

void main() {
  group('FowSpec 高さ段階 (D-049)', () {
    FowSpec spec({bool freeAbove = false, bool freeBelow = false}) => FowSpec(
          initialHeightFactor: 0.3,
          minHeightFactor: 0.1,
          maxHeightFactor: 0.9,
          heightStops: const [0.5, 0.2], // 昇順に整列される
          freeAboveStops: freeAbove,
          freeBelowStops: freeBelow,
        );

    test('段階は昇順に整列され、free 指定なしでは端の段階で止まる', () {
      final s = spec();
      expect(s.heightStops, [0.2, 0.5]);
      s.resizeBy(0.5); // 下方向へ大きくドラッグ(縮小)
      expect(s.heightFactor.value, 0.2); // 最下段で停止
      s.resizeBy(-1.0); // 上方向へ大きくドラッグ(拡大)
      expect(s.heightFactor.value, 0.5); // 最上段で停止
      expect(s.userResized, isTrue);
    });

    test('freeAboveStops: 最上段より上はシームレス(min/max まで)', () {
      final s = spec(freeAbove: true);
      s.resizeBy(-1.0);
      expect(s.heightFactor.value, 0.9); // maxHeightFactor まで動く
      s.snapToStops();
      expect(s.heightFactor.value, 0.9); // 段階の外側はスナップしない
    });

    test('段階の間で離すと最も近い段階へスナップする', () {
      final s = spec();
      s.heightFactor.value = 0.26;
      s.snapToStops();
      expect(s.heightFactor.value, 0.2);
      s.heightFactor.value = 0.42;
      s.snapToStops();
      expect(s.heightFactor.value, 0.5);
    });

    test('freeBelowStops: 最下段より下はシームレスでスナップもしない', () {
      final s = spec(freeBelow: true);
      s.resizeBy(0.5);
      expect(s.heightFactor.value, 0.1); // minHeightFactor まで
      s.snapToStops();
      expect(s.heightFactor.value, 0.1);
    });

    test('段階なし(空配列)は従来どおり min〜max のシームレス', () {
      final s = FowSpec(initialHeightFactor: 0.4, minHeightFactor: 0.2, maxHeightFactor: 0.8);
      s.resizeBy(-1.0);
      expect(s.heightFactor.value, 0.8);
      s.snapToStops(); // no-op
      expect(s.heightFactor.value, 0.8);
    });
  });
}
