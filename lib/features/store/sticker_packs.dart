import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../l10n/l10n.dart';
import '../../session/session_providers.dart';
import 'rasqpkg.dart';

/// アセットパックのステッカー (D-252、契約 v0.11 §2.10)。
///
/// ストアからインストールしたアセットパック(wasm 無しの `.rasqpkg`)の画像を**端末に保存**して、加工画面のステッカーに出す
/// (スロットプラグインと違い、起動のたびにストアから取り直さない)。置き場 = アプリの保存領域 `asset_packs/<packId>/<path>`、
/// 目次はホストのストレージ(`assetPacks.v1`)。
@immutable
class InstalledSticker {
  const InstalledSticker({required this.id, required this.file, this.label, this.tags = const []});
  final String id;

  /// 端末上の絶対パス。
  final String file;
  final String? label;
  final List<String> tags;

  Map<String, Object?> toJson() => {'id': id, 'file': file, if (label != null) 'label': label, if (tags.isNotEmpty) 'tags': tags};
  factory InstalledSticker.fromJson(Map<String, Object?> j) => InstalledSticker(id: j['id'] as String, file: j['file'] as String, label: j['label'] as String?, tags: [for (final t in (j['tags'] as List? ?? const [])) if (t is String) t]);
}

@immutable
class InstalledStickerPack {
  const InstalledStickerPack({required this.id, required this.name, required this.version, required this.stickers});
  final String id;
  final String name;
  final String version;
  final List<InstalledSticker> stickers;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'version': version, 'stickers': [for (final s in stickers) s.toJson()]};
  factory InstalledStickerPack.fromJson(Map<String, Object?> j) => InstalledStickerPack(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
        version: j['version'] as String? ?? '0.0.0',
        stickers: [for (final s in (j['stickers'] as List? ?? const [])) if (s is Map) InstalledSticker.fromJson(s.cast<String, Object?>())],
      );
}

/// 置き場(テストで差し替える)。
final assetPackDirProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}/asset_packs');
    });

class StickerPacks extends Notifier<List<InstalledStickerPack>> {
  static const storageKey = 'assetPacks.v1';
  Future<void>? _restored;

  @override
  List<InstalledStickerPack> build() {
    _restored = _restore();
    return const [];
  }

  /// 復元が済むまで待つ(加工画面を開いた直後など)。
  Future<void> get ready => _restored ?? Future.value();

  Future<void> _restore() async {
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw == null) return;
      state = [for (final p in jsonDecode(raw) as List) if (p is Map) InstalledStickerPack.fromJson(p.cast<String, Object?>())];
    } catch (_) {
      // 壊れた目次は空に(入れ直せば戻る)。
    }
  }

  Future<void> _persist(List<InstalledStickerPack> next) async {
    state = next;
    await ref.read(sessionStorageProvider).write(storageKey, jsonEncode([for (final p in next) p.toJson()]));
  }

  static String _dirName(String packId) => packId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// 検証済みのアセットパックを保存する(同じ id は入れ替え)。
  Future<InstalledStickerPack> install(RasqPackage package) async {
    if (!package.root.isAssets) throw ArgumentError(appL10n.storeNotAssetPack(package.root.id));
    await ready;
    final base = await ref.read(assetPackDirProvider)();
    final dir = Directory('${base.path}/${_dirName(package.root.id)}');
    if (dir.existsSync()) await dir.delete(recursive: true);
    final stickers = <InstalledSticker>[];
    for (final s in package.stickers) {
      // 配布物の中のパスは検証済み(`..` / 先頭 `/` 無し)。
      final f = File('${dir.path}/${s.path}');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(s.bytes, flush: true);
      stickers.add(InstalledSticker(id: s.id, file: f.path, label: s.label, tags: s.tags));
    }
    final pack = InstalledStickerPack(id: package.root.id, name: package.root.manifest['name'] as String? ?? package.root.id, version: package.root.version, stickers: stickers);
    await _persist([...state.where((p) => p.id != pack.id), pack]);
    return pack;
  }

  Future<void> uninstall(String packId) async {
    await ready;
    if (!state.any((p) => p.id == packId)) return;
    try {
      final base = await ref.read(assetPackDirProvider)();
      final dir = Directory('${base.path}/${_dirName(packId)}');
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
    await _persist([...state.where((p) => p.id != packId)]);
  }
}

final stickerPacksProvider = NotifierProvider<StickerPacks, List<InstalledStickerPack>>(StickerPacks.new);
