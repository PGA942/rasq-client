import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';

/// テストの端末の言語は日本語にそろえる (D-484)。
///
/// テストの既定の端末の言語は `en_US`。英語の訳を足したので、何もしなければ画面が英語で出て、日本語の文字で探す
/// テストが通らなくなる。言語ごとの表示を確かめるテストは、そのテストの中で端末の言語や設定を変える。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => binding.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')]);
  tearDown(binding.platformDispatcher.clearLocalesTestValue);
  await testMain();
}
