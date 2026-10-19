import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_models/rasq_models.dart';

/// ホストの予約の引数 (D-484 / 契約 v0.24 §4.6): 毎回の call に表示の言語 `locale` を載せる(args の値はホストの値で上書き)。
void main() {
  tearDown(() => RasqUiLocale.tag = RasqUiLocale.defaultTag);

  test('既定は ja、表示の言語が変われば変わる', () {
    expect(withHostCallArgs({'a': 1}), {'a': 1, 'locale': 'ja'});
    RasqUiLocale.tag = 'en-US';
    expect(withHostCallArgs(const {})[hostLocaleArgKey], 'en-US');
  });

  test('args の locale(RRL のイベントの payload など)はホストの値で上書き', () {
    RasqUiLocale.tag = 'en-US';
    expect(withHostCallArgs({'locale': 'fr'})['locale'], 'en-US');
  });
}
