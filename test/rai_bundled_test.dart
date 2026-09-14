import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_bundled.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';

/// 同梱モデル (D-216): アセットの名前、flutter_assets の場所、gzip の伸長。
void main() {
  test('ローカルモデルは 3 つ(Qwen3.5 2B / Agents-A1 4B / Qwen3.5 0.8B)で、同梱アセット名は <fileName>.gz', () {
    expect(raiModelSpecs.map((m) => m.id), ['qwen3.5-2b-q4km', 'agents-a1-4b-q4km', 'qwen3.5-0.8b-q4km']);
    expect(raiModelSpecs.every((m) => m.engine == RaiEngine.gguf), isTrue);
    expect(raiBundledAsset(raiModelSpecs.first), 'assets/rai_models/Qwen3.5-2B-Q4_K_M.gguf.gz');
  });

  test('flutter_assets の場所: macOS は App.framework の中、Linux / Windows は data/、モバイルは null', () {
    expect(flutterAssetsDirOf('/Applications/rasq.app/Contents/MacOS/rasq_client', os: 'macos'), '/Applications/rasq.app/Contents/Frameworks/App.framework/Resources/flutter_assets');
    expect(flutterAssetsDirOf('/opt/rasq/rasq_client', os: 'linux'), '/opt/rasq/data/flutter_assets');
    expect(flutterAssetsDirOf('C:/rasq/rasq_client.exe', os: 'windows'), 'C:/rasq/data/flutter_assets');
    expect(flutterAssetsDirOf('/x/app', os: 'ios'), isNull);
    expect(flutterAssetsDirOf('/x/app', os: 'android'), isNull);
  });

  test('gunzipToFile: 流しながら伸長し、進捗は圧縮側のバイト数。壊れた入力は .part を残さない', () async {
    final dir = await Directory.systemTemp.createTemp('rai_bundled');
    try {
      final payload = List<int>.generate(200000, (i) => (i * 7) % 251);
      final src = File('${dir.path}/m.gguf.gz')..writeAsBytesSync(gzip.encode(payload));
      final dst = File('${dir.path}/out/m.gguf');
      final progress = <(int, int)>[];
      await gunzipToFile(src, dst, onProgress: (d, t) => progress.add((d, t)));
      expect(dst.readAsBytesSync(), payload);
      expect(progress.last.$1, progress.last.$2);
      expect(File('${dst.path}.part').existsSync(), isFalse);
      // 壊れた gzip → 例外、.part は消える。
      final bad = File('${dir.path}/bad.gz')..writeAsBytesSync([1, 2, 3, 4, 5]);
      final badDst = File('${dir.path}/out/bad.gguf');
      await expectLater(gunzipToFile(bad, badDst), throwsA(anything));
      expect(badDst.existsSync(), isFalse);
      expect(File('${badDst.path}.part').existsSync(), isFalse);
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
