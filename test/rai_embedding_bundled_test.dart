import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_embedding_model_device.dart';

/// 同梱の RASQ MiniLM (D-522): アセットがあればネットワークを使わずに置き場へ写して使い、
/// 壊れていれば(長さ / sha256)写しを捨ててダウンロードへ戻る。アセットが無ければ従来どおりダウンロード。
class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, List<int>> files;
  @override
  Future<ByteData> load(String key) async {
    final b = files[key];
    if (b == null) throw StateError('no asset $key');
    return ByteData.sublistView(Uint8List.fromList(b));
  }
}

const _asset = '$raiBundledEmbeddingDir/m.onnx';
final _good = List<int>.generate(4096, (i) => i * 7 % 256);
final _bad = List<int>.generate(4096, (i) => i * 3 % 256);
final _goodSha = crypto.sha256.convert(_good).toString();

RaiEmbeddingSpec _spec({String? sha}) => RaiEmbeddingSpec(
      id: 'bundled-test',
      label: 'test',
      fileName: 'm.onnx',
      url: '',
      centralPath: 'x/m.onnx',
      bundledAsset: _asset,
      sha256: sha,
      sizeMb: 1,
      tokenizerAsset: '',
      dims: 384,
      // 画像側の形 = 埋め込み器を作らない(onnxruntime を読まずに、ファイルの解決だけを見る)。
      kind: RaiEmbeddingKind.rasqVision,
      maxLen: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory base;
  late int requests;
  late List<int> served;

  setUp(() {
    base = Directory.systemTemp.createTempSync('rai_emb_bundled');
    requests = 0;
    served = _good;
  });
  tearDown(() => base.deleteSync(recursive: true));

  DeviceRaiEmbeddingModel model({String? sha, Map<String, List<int>>? bundle}) {
    final files = bundle ?? {_asset: _good};
    return DeviceRaiEmbeddingModel(
      spec: _spec(sha: sha),
      central: () => Uri.parse('https://central.test'),
      bundle: _Bundle(files),
      baseDir: () async => base,
      assets: () async => files.keys.toSet(),
      flutterAssetsDir: () => null,
      httpClient: () => MockClient((req) async {
        requests++;
        return http.Response.bytes(served, 200);
      }),
    );
  }

  test('同梱があれば、ネットワークなしで準備完了(同梱)→ 初めて使うときに置き場へ写す', () async {
    final m = model(sha: _goodSha);
    await m.refresh();
    expect(m.current.phase, RaiEmbeddingPhase.ready);
    expect(m.current.bundled, isTrue);
    expect(m.current.label, '準備完了(同梱)');
    final f = await m.installedFile();
    expect(f, isNotNull);
    expect(f!.path, '${base.path}/rai_models/bundled-test/m.onnx');
    expect(await f.readAsBytes(), _good);
    expect(File('${f.path}.part').existsSync(), isFalse);
    // install も写すだけ。
    await m.install();
    expect(m.current.bundled, isTrue);
    expect(requests, 0, reason: 'ネットワークを使わない');
  });

  test('sha256 が未記入でも、長さを見て写す', () async {
    final m = model();
    expect(await (await m.installedFile())!.readAsBytes(), _good);
    expect(requests, 0);
  });

  test('同梱のモデルは消せない(メモリを解放するだけ)', () async {
    final m = model(sha: _goodSha);
    final f = (await m.installedFile())!;
    await m.uninstall();
    expect(f.existsSync(), isTrue);
    expect(m.current.phase, RaiEmbeddingPhase.ready);
    expect(m.current.bundled, isTrue);
  });

  test('同梱のものの sha256 が違う → 写しを捨て、ダウンロードできる状態に戻る → ダウンロードして確かめる', () async {
    final m = model(sha: _goodSha, bundle: {_asset: _bad});
    expect(await m.installedFile(), isNull);
    expect(m.current.phase, RaiEmbeddingPhase.notInstalled);
    expect(m.current.message, contains('sha256'));
    expect(Directory('${base.path}/rai_models/bundled-test').listSync(), isEmpty, reason: '壊れた写しを残さない');
    await m.refresh();
    expect(m.current.phase, RaiEmbeddingPhase.notInstalled, reason: '壊れた同梱を「準備完了」と言わない');
    await m.install();
    expect(requests, 1);
    expect(m.current.phase, RaiEmbeddingPhase.ready);
    expect(m.current.bundled, isFalse);
    expect(await (await m.installedFile())!.readAsBytes(), _good);
  });

  test('同梱が無いビルドは従来どおりダウンロード(削除もできる)', () async {
    final m = model(sha: _goodSha, bundle: const {});
    await m.refresh();
    expect(m.current.phase, RaiEmbeddingPhase.notInstalled);
    expect(await m.installedFile(), isNull);
    await m.install();
    expect(requests, 1);
    expect(m.current.phase, RaiEmbeddingPhase.ready);
    expect(m.current.bundled, isFalse);
    await m.uninstall();
    expect(m.current.phase, RaiEmbeddingPhase.notInstalled);
    expect(await m.installedFile(), isNull);
  });

  test('ダウンロードしたものの sha256 が違えば置かない', () async {
    served = _bad;
    final m = model(sha: _goodSha, bundle: const {});
    await expectLater(m.install(), throwsA(isA<RaiEmbeddingException>()));
    expect(m.current.phase, RaiEmbeddingPhase.notInstalled);
    expect(await m.installedFile(), isNull);
    expect(Directory('${base.path}/rai_models/bundled-test').listSync(), isEmpty);
  });

  test('既定の RASQ MiniLM は同梱を指し、pubspec はその置き場を Web 以外にだけ入れる', () {
    expect(raiEmbeddingSpec.bundledAsset, '$raiBundledEmbeddingDir/${raiEmbeddingSpec.fileName}');
    expect(postVisionEmbeddingSpec.bundledAsset, isNull, reason: '画像の塔は従来どおりダウンロード');
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final entry = RegExp(r'- path: assets/rai_embedding/\n\s+platforms: \[([^\]]*)\]').firstMatch(pubspec);
    expect(entry, isNotNull);
    final platforms = entry!.group(1)!.split(',').map((s) => s.trim()).toSet();
    expect(platforms, containsAll(['android', 'ios']));
    expect(platforms, isNot(contains('web')));
  });
}
