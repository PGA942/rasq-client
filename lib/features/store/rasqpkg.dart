import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show rasqZstdDecompress;
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show ManifestLocales;

import '../../l10n/l10n.dart';

/// `.rasqpkg`(D-034 / D-244d): zstd 圧縮 tar。先頭が `bundle.json`(`rasq.bundle/1`、rasq-sdk-sample
/// `schema/bundle.schema.json`)、最後が `SHA512SUMS`。ここは **展開と中身の検証**(`rasq inspect` と同じ手順):
///
/// 1. zstd を展開(出力上限つき = 展開爆弾の対策)→ tar を読む(件数上限、パスの文法、通常ファイルだけ)
/// 2. 先頭が `bundle.json`、`schema == rasq.bundle/1`、root / children / libs / assets / models の形
/// 3. 目次のファイルごとに実在 / `sizeBytes` / `sha512`、wasm は `\0asm` で始まること
/// 4. マニフェストの `id` / `version` が目次と同じ、子の id は `<root.id>.` で始まる、sns 以外の root は子を持てない
/// 5. `SHA512SUMS` の全行が中身と一致、目次に無いファイルは `models/` の下(モデル本体)だけ
///
/// 配布物**そのもの**の真正性(ストア署名 / 開発者鍵)は呼び出し側で先に確かめる([verifyDevSignature] と
/// `store_providers.dart` の `verifyArtifact`)。ここが見るのは「署名された入れ物の中身が目次どおりか」。

/// zstd の復号(既定はネイティブランタイム内蔵の ruzstd)。テストは差し替えて、作った tar をそのまま返す。
typedef ZstdDecompress = Uint8List Function(Uint8List input, {int maxOutput});

final rasqpkgZstdProvider = Provider<ZstdDecompress>((ref) => rasqZstdDecompress);

/// 展開後の合計の上限(wasm + アセット + 同梱モデル)。遅延取得のモデルは別 artifact なのでここには入らない。
const rasqpkgMaxUnpackedBytes = 256 * 1024 * 1024;

/// tar のエントリ数の上限。
const rasqpkgMaxEntries = 512;

const _bundleName = 'bundle.json';
const _sumsName = 'SHA512SUMS';

/// zstd フレームか(マジック `28 B5 2F FD`)。ストアの配布物が `.rasqpkg` かの判定。
bool isRasqPackage(Uint8List b) => b.length > 4 && b[0] == 0x28 && b[1] == 0xB5 && b[2] == 0x2F && b[3] == 0xFD;

/// wasm バイナリか(`\0asm`)。
bool isWasmModule(Uint8List b) => b.length > 4 && b[0] == 0 && b[1] == 0x61 && b[2] == 0x73 && b[3] == 0x6d;

class RasqPackageException implements Exception {
  const RasqPackageException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 配布物の中のプラグイン 1 つ(root か child)。
@immutable
class RasqPackagePlugin {
  const RasqPackagePlugin({required this.id, required this.version, required this.kind, required this.manifest, required this.wasm, this.template});
  final String id;
  final String version;
  final String kind;
  final Map<String, Object?> manifest;
  final Uint8List wasm;

  /// 雛形の名前(= スロット。記録用、無いこともある)。
  final String? template;

  bool get isSns => kind == 'sns';

  /// アセットパック(契約 v0.11 §2.10): wasm を持たない。[wasm] は空。
  bool get isAssets => kind == 'assets';

  /// 着せ替えパック(契約 v0.16 §2.12、D-335): アセットパックと同じく wasm を持たない。宣言はマニフェストの `theme`。
  bool get isTheme => kind == 'theme';

  /// wasm を持たない配布物(アセットパック / 着せ替え)。
  bool get isPack => isAssets || isTheme;
}

/// アセットパックの 1 枚(`manifest.assets[]` + 中身)。
@immutable
class RasqPackSticker {
  const RasqPackSticker({required this.id, required this.path, required this.bytes, this.label, this.tags = const []});
  final String id;
  final String path;
  final Uint8List bytes;
  final String? label;
  final List<String> tags;
}

/// 画像のマジックナンバー(PNG / JPEG / WebP / GIF)。アセットパックの中身はこれだけ。
bool isPackImage(Uint8List b) =>
    (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) ||
    (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) ||
    (b.length > 12 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46 && b[8] == 0x57 && b[9] == 0x45 && b[10] == 0x42 && b[11] == 0x50) ||
    (b.length > 6 && b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38);

/// アセットパックの上限(契約 v0.11): 1 枚 2 MiB、256 枚。
const rasqPackMaxImageBytes = 2 * 1024 * 1024;
const rasqPackMaxImages = 256;

@immutable
class RasqPackageLib {
  const RasqPackageLib({required this.name, required this.wasm, required this.exports});
  final String name;
  final Uint8List wasm;
  final List<String> exports;
}

@immutable
class RasqPackageRequirement {
  const RasqPackageRequirement({required this.id, required this.version});
  final String id;

  /// SemVer の範囲(Cargo と同じ書き方)。第一期は id の有無だけを見る。
  final String version;
}

@immutable
class RasqPackage {
  const RasqPackage({required this.bundle, required this.root, required this.children, required this.libs, required this.assets, required this.files, required this.requires});

  final Map<String, Object?> bundle;
  final RasqPackagePlugin root;
  final List<RasqPackagePlugin> children;
  final List<RasqPackageLib> libs;

  /// 添付ファイル(`path` → 中身)。
  final Map<String, Uint8List> assets;

  /// 全エントリ(`bundle.json` / `SHA512SUMS` も含む)。
  final Map<String, Uint8List> files;
  final List<RasqPackageRequirement> requires;

  /// スロットに登録できるもの: root(sns 以外)と children。
  List<RasqPackagePlugin> get slotPlugins => [if (!root.isSns && !root.isPack) root, ...children];

  /// 着せ替えパックの画像(`use: "theme"`、id → 中身)。着せ替えでなければ空。
  Map<String, ({String path, Uint8List bytes})> get themeImages => {
        if (root.isTheme)
          for (final a in (root.manifest['assets'] as List? ?? const []))
            if (a is Map && a['use'] == 'theme' && a['id'] is String && assets[a['path']] != null) a['id'] as String: (path: a['path'] as String, bytes: assets[a['path']]!),
      };

  /// アセットパックのステッカー(`use: "sticker"`)。アセットパックでなければ空。ラベルは表示の言語(`locales.<tag>.assets.<id>.label`、D-484)。
  List<RasqPackSticker> get stickers => [
        if (root.isAssets)
          for (final a in (root.manifest['assets'] as List? ?? const []))
            if (a is Map && a['use'] == 'sticker' && a['id'] is String && assets[a['path']] != null)
              RasqPackSticker(id: a['id'] as String, path: a['path'] as String, bytes: assets[a['path']]!, label: ManifestLocales.fromManifest(root.manifest).assetLabel(a['id'] as String) ?? a['label'] as String?, tags: [for (final t in (a['tags'] as List? ?? const [])) if (t is String) t]),
      ];

  /// id で引く(null / 空 = root)。無ければ例外。
  RasqPackagePlugin plugin(String? id) {
    if (id == null || id.isEmpty || id == root.id) return root;
    return children.firstWhere((c) => c.id == id, orElse: () => throw RasqPackageException(appL10n.storePkgMissingPlugin(id)));
  }

  /// 展開して検証する。失敗は [RasqPackageException](メッセージはそのままユーザーに見せられる形)。
  static RasqPackage open(Uint8List bytes, {ZstdDecompress decompress = rasqZstdDecompress, int maxUnpackedBytes = rasqpkgMaxUnpackedBytes}) {
    if (!isRasqPackage(bytes)) throw RasqPackageException(appL10n.storePkgNotPackage);
    final Uint8List tar;
    try {
      tar = decompress(bytes, maxOutput: maxUnpackedBytes);
    } catch (e) {
      throw RasqPackageException(appL10n.storePkgUnpack('$e'));
    }

    // 1. tar
    final files = <String, Uint8List>{};
    final order = <String>[];
    final Archive archive;
    try {
      archive = TarDecoder().decodeBytes(tar);
    } catch (e) {
      throw RasqPackageException(appL10n.storePkgTar('$e'));
    }
    for (final f in archive) {
      if (order.length >= rasqpkgMaxEntries) throw RasqPackageException(appL10n.storePkgTooManyFiles);
      if (!f.isFile || f.isSymbolicLink) throw RasqPackageException(appL10n.storePkgNotRegularFile(f.name));
      _checkPath(f.name);
      if (files.containsKey(f.name)) throw RasqPackageException(appL10n.storePkgDuplicatePath(f.name));
      files[f.name] = Uint8List.fromList(f.content as List<int>);
      order.add(f.name);
    }
    if (order.isEmpty || order.first != _bundleName) throw RasqPackageException(appL10n.storePkgBundleFirst);

    // 2. 目次
    final Map<String, Object?> bundle;
    try {
      bundle = (jsonDecode(utf8.decode(files[_bundleName]!)) as Map).cast<String, Object?>();
    } catch (e) {
      throw RasqPackageException(appL10n.storePkgBundleRead('$e'));
    }
    if (bundle['schema'] != 'rasq.bundle/1') throw RasqPackageException(appL10n.storePkgBundleSchema('${bundle['schema']}'));
    final listed = <String>{_bundleName, _sumsName};

    Uint8List fileOf(Object? spec, String what, {bool wasm = false}) {
      if (spec is! Map) throw RasqPackageException(appL10n.storePkgFileShape(what));
      final path = spec['path'];
      if (path is! String) throw RasqPackageException(appL10n.storePkgNoPath(what));
      _checkPath(path);
      final data = files[path];
      if (data == null) throw RasqPackageException(appL10n.storePkgFileMissing(path));
      final size = spec['sizeBytes'];
      if (size is int && size != data.length) throw RasqPackageException(appL10n.storePkgSizeMismatch(path));
      final hash = spec['sha512'];
      if (hash is String) {
        if (sha512.convert(data).toString() != hash) throw RasqPackageException(appL10n.storePkgHashMismatch(path));
      } else if (wasm) {
        throw RasqPackageException(appL10n.storePkgNoSha512(what));
      }
      if (wasm && !isWasmModule(data)) throw RasqPackageException(appL10n.storePkgNotWasm(path));
      if (!listed.add(path)) throw RasqPackageException(appL10n.storePkgTwice(path));
      return data;
    }

    RasqPackagePlugin pluginOf(Object? spec, String what) {
      if (spec is! Map) throw RasqPackageException(appL10n.storePkgPluginShape(what));
      final id = spec['id'], version = spec['version'], kind = spec['kind'], manifestPath = spec['manifest'];
      if (id is! String || !_pluginId.hasMatch(id)) throw RasqPackageException(appL10n.storePkgBadId(what, '$id'));
      if (version is! String || !_semver.hasMatch(version)) throw RasqPackageException(appL10n.storePkgBadVersion(id, '$version'));
      if (kind is! String || !_kinds.contains(kind)) throw RasqPackageException(appL10n.storePkgBadKind(id, '$kind'));
      if (manifestPath is! String) throw RasqPackageException(appL10n.storePkgNoManifest(id));
      _checkPath(manifestPath);
      final raw = files[manifestPath];
      if (raw == null) throw RasqPackageException(appL10n.storePkgFileMissing(manifestPath));
      if (!listed.add(manifestPath)) throw RasqPackageException(appL10n.storePkgTwice(manifestPath));
      final Map<String, Object?> manifest;
      try {
        manifest = (jsonDecode(utf8.decode(raw)) as Map).cast<String, Object?>();
      } catch (e) {
        throw RasqPackageException(appL10n.storePkgManifestRead(manifestPath, '$e'));
      }
      if (manifest['id'] != id || manifest['version'] != version || manifest['kind'] != kind) {
        throw RasqPackageException(appL10n.storePkgManifestMismatch(manifestPath, id, version, kind));
      }
      // アセットパック(v0.11)/ 着せ替え(v0.16)は wasm を持たない(持っていたら入れ物として不正)。root だけがなれる。
      if (kind == 'assets' || kind == 'theme') {
        if (what != 'root') throw RasqPackageException(appL10n.storePkgChildPackKind(id, kind));
        if (spec['wasm'] != null) throw RasqPackageException(appL10n.storePkgPackHasWasm(kind == 'theme' ? appL10n.storePkgKindTheme : appL10n.storePkgKindAssets, id));
        return RasqPackagePlugin(id: id, version: version, kind: kind, manifest: manifest, wasm: Uint8List(0), template: null);
      }
      return RasqPackagePlugin(id: id, version: version, kind: kind, manifest: manifest, wasm: fileOf(spec['wasm'], id, wasm: true), template: spec['template'] as String?);
    }

    List<Object?> listOf(String key) {
      final v = bundle[key];
      if (v is! List) throw RasqPackageException(appL10n.storePkgMissingKey(key));
      return v;
    }

    final rootSpec = bundle['root'];
    final root = pluginOf(rootSpec, 'root');
    final children = [for (final c in listOf('children')) pluginOf(c, 'children')];
    if (!root.isSns && children.isNotEmpty) throw RasqPackageException(appL10n.storePkgChildrenNotSns);
    for (final c in children) {
      if (!c.id.startsWith('${root.id}.')) throw RasqPackageException(appL10n.storePkgChildPrefix(c.id, root.id));
      if (c.isSns) throw RasqPackageException(appL10n.storePkgChildSns(c.id));
    }
    if ({root.id, for (final c in children) c.id}.length != children.length + 1) throw RasqPackageException(appL10n.storePkgDuplicateId);

    final libs = <RasqPackageLib>[];
    for (final l in listOf('libs')) {
      if (l is! Map || l['name'] is! String) throw RasqPackageException(appL10n.storePkgLibsShape);
      libs.add(RasqPackageLib(name: l['name'] as String, wasm: fileOf(l['wasm'], 'lib ${l['name']}', wasm: true), exports: [for (final e in (l['exports'] as List? ?? const [])) if (e is String) e]));
    }
    final assets = <String, Uint8List>{};
    for (final a in listOf('assets')) {
      if (a is! Map || a['path'] is! String) throw RasqPackageException(appL10n.storePkgAssetsShape);
      assets[a['path'] as String] = fileOf(a, 'asset ${a['path']}');
    }
    if (root.isPack) {
      // アセットパック / 着せ替え: コードを一切含まない(wasm を入れ物に紛れ込ませない)、中身は画像だけ、上限つき。
      // 着せ替えは画像 0 枚(色だけ)でもよい。
      if (children.isNotEmpty || libs.isNotEmpty || listOf('models').isNotEmpty) throw RasqPackageException(appL10n.storePkgPackExtras);
      if (files.values.any(isWasmModule)) throw RasqPackageException(appL10n.storePkgPackWasm);
      if ((root.isAssets && assets.isEmpty) || assets.length > rasqPackMaxImages) throw RasqPackageException(appL10n.storePkgPackImageCount(rasqPackMaxImages, assets.length));
      for (final e in assets.entries) {
        if (!isPackImage(e.value)) throw RasqPackageException(appL10n.storePkgNotImage(e.key));
        if (e.value.length > rasqPackMaxImageBytes) throw RasqPackageException(appL10n.storePkgImageTooLarge(e.key, rasqPackMaxImageBytes ~/ 1024 ~/ 1024));
      }
      for (final a in (root.manifest['assets'] as List? ?? const [])) {
        if (a is! Map || a['path'] is! String || !assets.containsKey(a['path'])) throw RasqPackageException(appL10n.storePkgAssetNotListed('${a is Map ? a['path'] : a}'));
      }
      if (root.isTheme) checkThemeManifest(root.manifest);
    }
    for (final m in listOf('models')) {
      if (m is! Map || m['manifest'] is! String) throw RasqPackageException(appL10n.storePkgModelsShape);
      final path = m['manifest'] as String;
      _checkPath(path);
      if (!files.containsKey(path)) throw RasqPackageException(appL10n.storePkgFileMissing(path));
      listed.add(path);
    }
    final requires = <RasqPackageRequirement>[];
    final req = rootSpec is Map ? rootSpec['requires'] : null;
    if (req is List) {
      for (final r in req) {
        if (r is! Map || r['id'] is! String || !_pluginId.hasMatch(r['id'] as String)) throw RasqPackageException(appL10n.storePkgRequiresShape);
        requires.add(RasqPackageRequirement(id: r['id'] as String, version: r['version'] as String? ?? '*'));
      }
    }

    // 5. SHA512SUMS と、目次に無いファイル
    final sums = files[_sumsName];
    if (sums == null) throw RasqPackageException(appL10n.storePkgNoSums);
    for (final line in const LineSplitter().convert(utf8.decode(sums))) {
      final i = line.indexOf('  ');
      if (i <= 0) continue;
      final path = line.substring(i + 2);
      final data = files[path];
      if (data == null) throw RasqPackageException(appL10n.storePkgSumsMissingFile(path));
      if (sha512.convert(data).toString() != line.substring(0, i)) throw RasqPackageException(appL10n.storePkgSumsMismatch(path));
    }
    for (final path in order) {
      if (!listed.contains(path) && !path.startsWith('models/')) throw RasqPackageException(appL10n.storePkgUnlisted(path));
    }

    return RasqPackage(bundle: bundle, root: root, children: children, libs: libs, assets: assets, files: files, requires: requires);
  }
}

final _pluginId = RegExp(r'^[a-z0-9]+(\.[a-z0-9_-]+)+$');
final _semver = RegExp(r'^\d+\.\d+\.\d+([-+][0-9A-Za-z.-]+)?$');
const _kinds = {'sns', 'action', 'view', 'trend', 'mediaViewer', 'postProcessor', 'assets', 'theme'};

/// 着せ替えの宣言の整合 (契約 v0.16 §2.12): `theme` があり、レイヤーとアイコンの `asset:<id>` が `use: "theme"` の画像を指す。
void checkThemeManifest(Map<String, Object?> manifest) {
  final theme = manifest['theme'];
  if (theme is! Map) throw RasqPackageException(appL10n.storePkgThemeMissing);
  final ids = {for (final a in (manifest['assets'] as List? ?? const [])) if (a is Map && a['use'] == 'theme' && a['id'] is String) a['id'] as String};
  void need(Object? id, String where) {
    if (id is! String || !ids.contains(id)) throw RasqPackageException(appL10n.storePkgThemeAsset(where, '$id'));
  }

  if (theme['icons'] case final Map<Object?, Object?> icons) {
    for (final e in icons.entries) {
      if (e.value case final String v when v.startsWith('asset:')) need(v.substring(6), 'icons.${e.key}');
    }
  }
  if (theme['surfaces'] case final Map<Object?, Object?> surfaces) {
    for (final e in surfaces.entries) {
      if (!const {'app', 'postTile', 'fow', 'actionButton'}.contains(e.key)) throw RasqPackageException(appL10n.storePkgThemeSurface('${e.key}'));
      for (final l in ((e.value as Map?)?['layers'] as List? ?? const [])) {
        // レイヤーは画像(asset)かグラデーション(gradient、v0.17)のどちらか 1 つ。
        final hasAsset = l is Map && l['asset'] != null;
        final hasGradient = l is Map && l['gradient'] != null;
        if (hasAsset == hasGradient) throw RasqPackageException(appL10n.storePkgThemeLayer('${e.key}'));
        if (hasAsset) need(l['asset'], 'surfaces.${e.key}.layers');
        if (hasGradient) {
          final g = l['gradient'];
          final colors = g is Map ? g['colors'] : null;
          final stops = g is Map ? g['stops'] : null;
          if (colors is! List || colors.length < 2 || colors.length > 8) throw RasqPackageException(appL10n.storePkgThemeColors('${e.key}'));
          if (stops is List && stops.length != colors.length) throw RasqPackageException(appL10n.storePkgThemeStops('${e.key}'));
        }
      }
    }
  }
}
final _pathChars = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_./-]*$');

/// 配布物内のパスの文法(`bundle.schema.json` の `path`): 相対、`..` なし、英数字と `_ . / -` だけ。
void _checkPath(String p) {
  final ok = _pathChars.hasMatch(p) && !p.startsWith('/') && !p.split('/').any((s) => s.isEmpty || s == '..' || s == '.');
  if (!ok) throw RasqPackageException(appL10n.storePkgBadPath(p));
}

/// 登録元の文字列から「入れ物」と「中のプラグイン id」を分ける: `store:<id>#<childId>` / `/path/x.rasqpkg#<childId>`。
({String container, String? pluginId}) splitPackageSource(String source) {
  final i = source.indexOf('#');
  return i < 0 ? (container: source, pluginId: null) : (container: source.substring(0, i), pluginId: source.substring(i + 1));
}

/// ストアから入れたプラグインの登録元 (D-168 → D-355): `store:<id>@<version>`(子は `#<childId>`)。版を持たない古い形 `store:<id>` も読む。
String storeSlotSource(String pluginId, String version, {String? child}) => 'store:$pluginId@$version${child == null ? '' : '#$child'}';

/// 登録元が `store:` なら (プラグイン id, 版(古い形は null), 子 id)。ほかは null。
({String pluginId, String? version, String? child})? parseStoreSlotSource(String source) {
  if (!source.startsWith('store:')) return null;
  final (:container, pluginId: child) = splitPackageSource(source);
  final body = container.substring(6);
  final at = body.indexOf('@');
  return at < 0 ? (pluginId: body, version: null, child: child) : (pluginId: body.substring(0, at), version: body.substring(at + 1), child: child);
}

/// 開発者鍵の署名(`<pkg>.sig.json`、`rasq build` が出す)を確かめる。署名対象は配布物バイト列の SHA-512 ダイジェスト
/// (生 64 バイト)= ストア署名と同じ。戻りは公開鍵の指紋(SHA-512 の先頭 8 バイト、`rasq key show` と同じ)。
/// サイドロード用: 鍵そのものの信頼はユーザーが指紋で判断する(常に警告つき)。
Future<String> verifyDevSignature(Uint8List packageBytes, Map<String, Object?> sig) async {
  if (sig['alg'] != 'ed25519') throw RasqPackageException(appL10n.storePkgSigAlg('${sig['alg']}'));
  final digest = sha512.convert(packageBytes);
  if (sig['digest'] != 'sha512:$digest') throw RasqPackageException(appL10n.storePkgSigDigest);
  final Uint8List publicKey, signature;
  try {
    publicKey = base64Decode(sig['publicKey'] as String);
    signature = base64Decode(sig['signature'] as String);
  } catch (_) {
    throw RasqPackageException(appL10n.storePkgSigRead);
  }
  if (publicKey.length != 32 || signature.length != 64) throw RasqPackageException(appL10n.storePkgSigLength);
  final ok = await Ed25519().verify(Uint8List.fromList(digest.bytes), signature: Signature(signature, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)));
  if (!ok) throw RasqPackageException(appL10n.storePkgSigInvalid);
  return sha512.convert(publicKey).bytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
