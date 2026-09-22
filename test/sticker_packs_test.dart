import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/store/rasqpkg.dart';
import 'package:rasq_client/features/store/sticker_packs.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/session/session_storage.dart';

import 'support/fakes.dart';

/// アセットパック (D-252、契約 v0.11 §2.10): wasm 無しの `.rasqpkg`。検証 → 画像を端末に保存 → ステッカーに出る → アンインストールで消える。
class _Store extends MockStoreClient {
  _Store(this.id, this.version, this.bytes);
  final String id;
  final String version;
  final Uint8List bytes;

  @override
  Future<InstallManifest?> manifest(String pluginId, {String? version}) async => pluginId != id
      ? super.manifest(pluginId, version: version)
      : InstallManifest(pluginId: id, version: this.version, manifest: {'id': id, 'name': 'テストのステッカー', 'kind': 'assets'}, artifacts: [StoreArtifact(id: 'bundle', sizeBytes: bytes.length, sha512: sha512.convert(bytes).toString())]);

  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) async => pluginId == id ? bytes : super.downloadArtifact(pluginId, artifactId, version: version);
}

void main() {
  final pack = File('test/fixtures/rasqpkg/dev.test.stickers-0.1.0.rasqpkg').readAsBytesSync();
  final code = File('test/fixtures/rasqpkg/net.example.later-0.1.0.rasqpkg').readAsBytesSync();

  test('検証: アセットパックは wasm を持たず、ステッカー(id / label / 中身)が取れる。スロットには何も出さない', () {
    final p = RasqPackage.open(pack);
    expect((p.root.id, p.root.kind, p.root.isAssets), ('dev.test.stickers', 'assets', true));
    expect(p.root.wasm, isEmpty);
    expect(p.slotPlugins, isEmpty);
    expect(p.stickers.map((s) => (s.id, s.label, s.path)), [('second', 'ふたつめ', 'stickers/second.png'), ('sample', 'サンプル', 'stickers/sample.png')]);
    expect(p.stickers.every((s) => isPackImage(s.bytes)), isTrue);
    // コードの配布物はステッカーを持たない。
    expect(RasqPackage.open(code).stickers, isEmpty);
  });

  test('画像の判定: PNG / JPEG / WebP / GIF だけ', () {
    expect(isPackImage(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0])), isTrue);
    expect(isPackImage(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0])), isTrue);
    expect(isPackImage(Uint8List.fromList([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits, 0])), isTrue);
    expect(isPackImage(Uint8List.fromList([...'GIF89a'.codeUnits, 0])), isTrue);
    expect(isPackImage(Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0, 0])), isFalse); // wasm
    expect(isPackImage(Uint8List.fromList(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>'))), isFalse);
  });

  test('ストアからインストール: 画像が端末に保存され、目次は再起動後も残る。アンインストールで画像ごと消える', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('rasq-d252');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    ProviderContainer make() {
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        storeClientProvider.overrideWithValue(_Store('dev.test.stickers', '0.1.0', pack)),
        assetPackDirProvider.overrideWithValue(() async => dir),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    final c = make();
    final outcome = await c.read(installedPluginsProvider.notifier).install('dev.test.stickers');
    expect(outcome.error, isNull);
    expect(c.read(installedPluginsProvider).single.id, 'dev.test.stickers');
    expect(c.read(slotPluginsProvider), isEmpty);
    final installed = c.read(stickerPacksProvider).single;
    expect((installed.id, installed.name, installed.stickers.length), ('dev.test.stickers', 'テストのステッカー', 2));
    for (final s in installed.stickers) {
      expect(File(s.file).existsSync(), isTrue);
      expect(s.file, startsWith(dir.path));
    }

    // 再起動(同じストレージ)。
    final c2 = make();
    c2.read(stickerPacksProvider);
    await c2.read(stickerPacksProvider.notifier).ready;
    expect(c2.read(stickerPacksProvider).single.stickers.map((s) => s.id), ['second', 'sample']);

    await c2.read(installedPluginsProvider.notifier).uninstall('dev.test.stickers');
    expect(c2.read(stickerPacksProvider), isEmpty);
    expect(Directory('${dir.path}/dev.test.stickers').existsSync(), isFalse);
  });

  test('掲載と中身が食い違うパック / 壊れたパックは入れない', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final dir = Directory.systemTemp.createTempSync('rasq-d252');
    addTearDown(() => dir.deleteSync(recursive: true));
    ProviderContainer make(_Store store) {
      final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({})), storeClientProvider.overrideWithValue(store), assetPackDirProvider.overrideWithValue(() async => dir)]);
      addTearDown(c.dispose);
      return c;
    }

    final wrongVersion = make(_Store('dev.test.stickers', '9.9.9', pack));
    expect((await wrongVersion.read(installedPluginsProvider.notifier).install('dev.test.stickers')).error, contains('掲載'));
    final broken = Uint8List.fromList(pack)..[pack.length ~/ 2] ^= 0x55;
    final c = make(_Store('dev.test.stickers', '0.1.0', broken));
    expect((await c.read(installedPluginsProvider.notifier).install('dev.test.stickers')).error, contains('検証できませんでした'));
    expect(c.read(stickerPacksProvider), isEmpty);
    expect(dir.listSync(), isEmpty);
  });
}
