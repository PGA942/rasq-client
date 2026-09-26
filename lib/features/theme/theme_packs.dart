import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../session/session_providers.dart';
import '../home/post_row.dart' show PostRow;
import '../settings/settings_dsl.dart';
import '../store/rasqpkg.dart';

/// 着せ替えパック (D-335、契約 v0.16 §2.12 `kind: "theme"`)。
///
/// インストールした着せ替えパック(wasm 無しの `.rasqpkg`)の画像を端末に保存し(`theme_packs/<packId>/<path>`)、宣言(マニフェストの
/// `theme`)と一緒に目次(ホストのストレージ `themePacks.v1`)に残す。**同時に効くのは 1 つ**: 設定 → アプリの外観 →
/// 「フォントやカラースキーム」で選ぶ(設定領域 `appearance.theme` の `id`)。コードは動かないので、ストアを通さない読み込み
/// (サイドロード)もそのまま入れられる(未審査の印だけ付ける)。
@immutable
class InstalledThemePack {
  const InstalledThemePack({required this.id, required this.name, required this.version, this.description = '', required this.theme, required this.images, this.sideloaded = false});
  final String id;
  final String name;
  final String version;
  final String description;

  /// マニフェストの `theme`(そのまま)。
  final Map<String, Object?> theme;

  /// 画像の id → 端末上の絶対パス。
  final Map<String, String> images;

  /// ストアを通さずに入れた(未審査)。
  final bool sideloaded;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'version': version, 'description': description, 'theme': theme, 'images': images, if (sideloaded) 'sideloaded': true};
  factory InstalledThemePack.fromJson(Map<String, Object?> j) => InstalledThemePack(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
        version: j['version'] as String? ?? '0.0.0',
        description: j['description'] as String? ?? '',
        theme: (j['theme'] as Map?)?.cast<String, Object?>() ?? const {},
        images: {for (final e in ((j['images'] as Map?) ?? const {}).entries) if (e.key is String && e.value is String) e.key as String: e.value as String},
        sideloaded: j['sideloaded'] == true,
      );

  /// 一覧の見本に出す色(明 / 暗の primary と surface、面の色)。
  List<Color> get swatches => [
        for (final b in const ['dark', 'light'])
          for (final k in const ['primary', 'surface'])
            ?RasqSkin.parseColor(((theme['colors'] as Map?)?[b] as Map?)?[k]),
        for (final s in ((theme['surfaces'] as Map?) ?? const {}).values)
          if (s is Map) ?RasqSkin.parseColor(s['color']),
      ];
}

/// 置き場(テストで差し替える)。
final themePackDirProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}/theme_packs');
    });

class ThemePacks extends Notifier<List<InstalledThemePack>> {
  static const storageKey = 'themePacks.v1';
  Future<void>? _restored;

  @override
  List<InstalledThemePack> build() {
    _restored = _restore();
    return const [];
  }

  Future<void> get ready => _restored ?? Future.value();

  Future<void> _restore() async {
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw == null) return;
      state = [for (final p in jsonDecode(raw) as List) if (p is Map) InstalledThemePack.fromJson(p.cast<String, Object?>())];
    } catch (_) {
      // 壊れた目次は空に(入れ直せば戻る)。
    }
  }

  Future<void> _persist(List<InstalledThemePack> next) async {
    state = next;
    await ref.read(sessionStorageProvider).write(storageKey, jsonEncode([for (final p in next) p.toJson()]));
  }

  static String _dirName(String packId) => packId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// 検証済みの着せ替えパックを保存する(同じ id は入れ替え)。[sideloaded] = ストアを通していない。
  Future<InstalledThemePack> install(RasqPackage package, {bool sideloaded = false}) async {
    if (!package.root.isTheme) throw ArgumentError('着せ替えパックではありません: ${package.root.id}');
    await ready;
    final base = await ref.read(themePackDirProvider)();
    final dir = Directory('${base.path}/${_dirName(package.root.id)}');
    if (dir.existsSync()) await dir.delete(recursive: true);
    final images = <String, String>{};
    for (final e in package.themeImages.entries) {
      // 配布物の中のパスは検証済み(`..` / 先頭 `/` 無し)。
      final f = File('${dir.path}/${e.value.path}');
      await f.parent.create(recursive: true);
      await f.writeAsBytes(e.value.bytes, flush: true);
      images[e.key] = f.path;
    }
    final m = package.root.manifest;
    final pack = InstalledThemePack(
      id: package.root.id,
      name: m['name'] as String? ?? package.root.id,
      version: package.root.version,
      description: m['description'] as String? ?? '',
      theme: (m['theme'] as Map).cast<String, Object?>(),
      images: images,
      sideloaded: sideloaded,
    );
    await _persist([...state.where((p) => p.id != pack.id), pack]);
    return pack;
  }

  Future<void> uninstall(String packId) async {
    await ready;
    if (!state.any((p) => p.id == packId)) return;
    try {
      final base = await ref.read(themePackDirProvider)();
      final dir = Directory('${base.path}/${_dirName(packId)}');
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
    await _persist([...state.where((p) => p.id != packId)]);
    // 使っていた着せ替えを消したら既定に戻す。
    if (ref.read(activeThemeIdProvider) == packId) await ref.read(settingsAreaProvider(themeSettingsArea).notifier).set('id', null);
  }
}

final themePacksProvider = NotifierProvider<ThemePacks, List<InstalledThemePack>>(ThemePacks.new);

/// 今の着せ替えの id(設定領域 `appearance.theme` の `id`)。null = 着せ替えなし。
const themeSettingsArea = 'appearance.theme';
final activeThemeIdProvider = Provider<String?>((ref) => ref.watch(settingsAreaProvider(themeSettingsArea)).value?['id'] as String?);

/// Material のアイコン名 → IconData(アクションの名前表と同じ。知らない名前は null)。
IconData? themeIconByName(String name) {
  const miss = IconData(0xFFFFF);
  final ic = PostRow.iconFor(name, miss);
  return ic == miss ? null : ic;
}

/// 今の着せ替え(読んだもの)。入っていない / 選んでいない / 読めないときは null。
final activeSkinProvider = Provider<RasqSkin?>((ref) {
  final id = ref.watch(activeThemeIdProvider);
  if (id == null || kIsWeb) return null;
  final pack = ref.watch(themePacksProvider).where((p) => p.id == id).firstOrNull;
  if (pack == null) return null;
  try {
    return RasqSkin.parse(
      id: pack.id,
      name: pack.name,
      theme: pack.theme,
      image: (assetId) => pack.images[assetId] == null ? null : FileImage(File(pack.images[assetId]!)),
      materialIcon: themeIconByName,
    );
  } catch (e) {
    debugPrint('theme: ${pack.id}: $e');
    return null;
  }
});
