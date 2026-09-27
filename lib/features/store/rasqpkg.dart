import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart' show sha512;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show rasqZstdDecompress;

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

  /// アセットパックのステッカー(`use: "sticker"`)。アセットパックでなければ空。
  List<RasqPackSticker> get stickers => [
        if (root.isAssets)
          for (final a in (root.manifest['assets'] as List? ?? const []))
            if (a is Map && a['use'] == 'sticker' && a['id'] is String && assets[a['path']] != null)
              RasqPackSticker(id: a['id'] as String, path: a['path'] as String, bytes: assets[a['path']]!, label: a['label'] as String?, tags: [for (final t in (a['tags'] as List? ?? const [])) if (t is String) t]),
      ];

  /// id で引く(null / 空 = root)。無ければ例外。
  RasqPackagePlugin plugin(String? id) {
    if (id == null || id.isEmpty || id == root.id) return root;
    return children.firstWhere((c) => c.id == id, orElse: () => throw RasqPackageException('配布物に $id がありません'));
  }

  /// 展開して検証する。失敗は [RasqPackageException](メッセージはそのままユーザーに見せられる形)。
  static RasqPackage open(Uint8List bytes, {ZstdDecompress decompress = rasqZstdDecompress, int maxUnpackedBytes = rasqpkgMaxUnpackedBytes}) {
    if (!isRasqPackage(bytes)) throw const RasqPackageException('配布物が .rasqpkg(zstd)ではありません');
    final Uint8List tar;
    try {
      tar = decompress(bytes, maxOutput: maxUnpackedBytes);
    } catch (e) {
      throw RasqPackageException('配布物を展開できません(壊れているか、大きすぎます): $e');
    }

    // 1. tar
    final files = <String, Uint8List>{};
    final order = <String>[];
    final Archive archive;
    try {
      archive = TarDecoder().decodeBytes(tar);
    } catch (e) {
      throw RasqPackageException('配布物の tar を読めません: $e');
    }
    for (final f in archive) {
      if (order.length >= rasqpkgMaxEntries) throw const RasqPackageException('配布物のファイル数が多すぎます');
      if (!f.isFile || f.isSymbolicLink) throw RasqPackageException('配布物に通常ファイルでないものがあります: ${f.name}');
      _checkPath(f.name);
      if (files.containsKey(f.name)) throw RasqPackageException('配布物内のパスが重複しています: ${f.name}');
      files[f.name] = Uint8List.fromList(f.content as List<int>);
      order.add(f.name);
    }
    if (order.isEmpty || order.first != _bundleName) throw const RasqPackageException('配布物の先頭が bundle.json ではありません');

    // 2. 目次
    final Map<String, Object?> bundle;
    try {
      bundle = (jsonDecode(utf8.decode(files[_bundleName]!)) as Map).cast<String, Object?>();
    } catch (e) {
      throw RasqPackageException('bundle.json を読めません: $e');
    }
    if (bundle['schema'] != 'rasq.bundle/1') throw RasqPackageException('bundle.json の schema が rasq.bundle/1 ではありません: ${bundle['schema']}');
    final listed = <String>{_bundleName, _sumsName};

    Uint8List fileOf(Object? spec, String what, {bool wasm = false}) {
      if (spec is! Map) throw RasqPackageException('bundle.json: $what の wasm / file の形が違います');
      final path = spec['path'];
      if (path is! String) throw RasqPackageException('bundle.json: $what に path がありません');
      _checkPath(path);
      final data = files[path];
      if (data == null) throw RasqPackageException('$path: 目次にあるのに中にありません');
      final size = spec['sizeBytes'];
      if (size is int && size != data.length) throw RasqPackageException('$path: 大きさが目次と違います');
      final hash = spec['sha512'];
      if (hash is String) {
        if (sha512.convert(data).toString() != hash) throw RasqPackageException('$path: SHA-512 が目次と違います');
      } else if (wasm) {
        throw RasqPackageException('bundle.json: $what に sha512 がありません');
      }
      if (wasm && !isWasmModule(data)) throw RasqPackageException('$path: wasm ではありません');
      if (!listed.add(path)) throw RasqPackageException('bundle.json: $path が 2 回出てきます');
      return data;
    }

    RasqPackagePlugin pluginOf(Object? spec, String what) {
      if (spec is! Map) throw RasqPackageException('bundle.json: $what の形が違います');
      final id = spec['id'], version = spec['version'], kind = spec['kind'], manifestPath = spec['manifest'];
      if (id is! String || !_pluginId.hasMatch(id)) throw RasqPackageException('bundle.json: $what の id が不正です: $id');
      if (version is! String || !_semver.hasMatch(version)) throw RasqPackageException('bundle.json: $id の version が不正です: $version');
      if (kind is! String || !_kinds.contains(kind)) throw RasqPackageException('bundle.json: $id の kind が不正です: $kind');
      if (manifestPath is! String) throw RasqPackageException('bundle.json: $id に manifest がありません');
      _checkPath(manifestPath);
      final raw = files[manifestPath];
      if (raw == null) throw RasqPackageException('$manifestPath: 目次にあるのに中にありません');
      if (!listed.add(manifestPath)) throw RasqPackageException('bundle.json: $manifestPath が 2 回出てきます');
      final Map<String, Object?> manifest;
      try {
        manifest = (jsonDecode(utf8.decode(raw)) as Map).cast<String, Object?>();
      } catch (e) {
        throw RasqPackageException('$manifestPath を読めません: $e');
      }
      if (manifest['id'] != id || manifest['version'] != version || manifest['kind'] != kind) {
        throw RasqPackageException('$manifestPath: id / version / kind が目次($id $version $kind)と違います');
      }
      // アセットパック(v0.11)/ 着せ替え(v0.16)は wasm を持たない(持っていたら入れ物として不正)。root だけがなれる。
      if (kind == 'assets' || kind == 'theme') {
        if (what != 'root') throw RasqPackageException('bundle.json: 子 $id は kind = $kind にできません');
        if (spec['wasm'] != null) throw RasqPackageException('bundle.json: ${kind == 'theme' ? '着せ替え' : 'アセットパック'} $id が wasm を持っています');
        return RasqPackagePlugin(id: id, version: version, kind: kind, manifest: manifest, wasm: Uint8List(0), template: null);
      }
      return RasqPackagePlugin(id: id, version: version, kind: kind, manifest: manifest, wasm: fileOf(spec['wasm'], id, wasm: true), template: spec['template'] as String?);
    }

    List<Object?> listOf(String key) {
      final v = bundle[key];
      if (v is! List) throw RasqPackageException('bundle.json: $key がありません');
      return v;
    }

    final rootSpec = bundle['root'];
    final root = pluginOf(rootSpec, 'root');
    final children = [for (final c in listOf('children')) pluginOf(c, 'children')];
    if (!root.isSns && children.isNotEmpty) throw const RasqPackageException('bundle.json: sns 以外の root は children を持てません');
    for (final c in children) {
      if (!c.id.startsWith('${root.id}.')) throw RasqPackageException('bundle.json: 子 ${c.id} の id が ${root.id}. で始まっていません');
      if (c.isSns) throw RasqPackageException('bundle.json: 子 ${c.id} は kind = sns にできません');
    }
    if ({root.id, for (final c in children) c.id}.length != children.length + 1) throw const RasqPackageException('bundle.json: プラグインの id が重複しています');

    final libs = <RasqPackageLib>[];
    for (final l in listOf('libs')) {
      if (l is! Map || l['name'] is! String) throw const RasqPackageException('bundle.json: libs の形が違います');
      libs.add(RasqPackageLib(name: l['name'] as String, wasm: fileOf(l['wasm'], 'lib ${l['name']}', wasm: true), exports: [for (final e in (l['exports'] as List? ?? const [])) if (e is String) e]));
    }
    final assets = <String, Uint8List>{};
    for (final a in listOf('assets')) {
      if (a is! Map || a['path'] is! String) throw const RasqPackageException('bundle.json: assets の形が違います');
      assets[a['path'] as String] = fileOf(a, 'asset ${a['path']}');
    }
    if (root.isPack) {
      // アセットパック / 着せ替え: コードを一切含まない(wasm を入れ物に紛れ込ませない)、中身は画像だけ、上限つき。
      // 着せ替えは画像 0 枚(色だけ)でもよい。
      if (children.isNotEmpty || libs.isNotEmpty || listOf('models').isNotEmpty) throw const RasqPackageException('bundle.json: アセットパック / 着せ替えは children / libs / models を持てません');
      if (files.values.any(isWasmModule)) throw const RasqPackageException('アセットパック / 着せ替えに wasm が入っています');
      if ((root.isAssets && assets.isEmpty) || assets.length > rasqPackMaxImages) throw RasqPackageException('アセットパックの画像は 1〜$rasqPackMaxImages 枚です: ${assets.length}');
      for (final e in assets.entries) {
        if (!isPackImage(e.value)) throw RasqPackageException('${e.key}: 画像(PNG / JPEG / WebP / GIF)ではありません');
        if (e.value.length > rasqPackMaxImageBytes) throw RasqPackageException('${e.key}: 大きすぎます(1 枚 ${rasqPackMaxImageBytes ~/ 1024 ~/ 1024} MiB まで)');
      }
      for (final a in (root.manifest['assets'] as List? ?? const [])) {
        if (a is! Map || a['path'] is! String || !assets.containsKey(a['path'])) throw RasqPackageException('manifest.assets の ${a is Map ? a['path'] : a} が配布物の目次にありません');
      }
      if (root.isTheme) checkThemeManifest(root.manifest);
    }
    for (final m in listOf('models')) {
      if (m is! Map || m['manifest'] is! String) throw const RasqPackageException('bundle.json: models の形が違います');
      final path = m['manifest'] as String;
      _checkPath(path);
      if (!files.containsKey(path)) throw RasqPackageException('$path: 目次にあるのに中にありません');
      listed.add(path);
    }
    final requires = <RasqPackageRequirement>[];
    final req = rootSpec is Map ? rootSpec['requires'] : null;
    if (req is List) {
      for (final r in req) {
        if (r is! Map || r['id'] is! String || !_pluginId.hasMatch(r['id'] as String)) throw const RasqPackageException('bundle.json: requires の形が違います');
        requires.add(RasqPackageRequirement(id: r['id'] as String, version: r['version'] as String? ?? '*'));
      }
    }

    // 5. SHA512SUMS と、目次に無いファイル
    final sums = files[_sumsName];
    if (sums == null) throw const RasqPackageException('SHA512SUMS がありません');
    for (final line in const LineSplitter().convert(utf8.decode(sums))) {
      final i = line.indexOf('  ');
      if (i <= 0) continue;
      final path = line.substring(i + 2);
      final data = files[path];
      if (data == null) throw RasqPackageException('$path: SHA512SUMS にあるのに中にありません');
      if (sha512.convert(data).toString() != line.substring(0, i)) throw RasqPackageException('$path: SHA512SUMS と違います');
    }
    for (final path in order) {
      if (!listed.contains(path) && !path.startsWith('models/')) throw RasqPackageException('$path: 目次に載っていないファイルがあります');
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
  if (theme is! Map) throw const RasqPackageException('着せ替えのマニフェストに theme がありません');
  final ids = {for (final a in (manifest['assets'] as List? ?? const [])) if (a is Map && a['use'] == 'theme' && a['id'] is String) a['id'] as String};
  void need(Object? id, String where) {
    if (id is! String || !ids.contains(id)) throw RasqPackageException('theme.$where の画像 $id が assets(use: theme)にありません');
  }

  if (theme['icons'] case final Map<Object?, Object?> icons) {
    for (final e in icons.entries) {
      if (e.value case final String v when v.startsWith('asset:')) need(v.substring(6), 'icons.${e.key}');
    }
  }
  if (theme['surfaces'] case final Map<Object?, Object?> surfaces) {
    for (final e in surfaces.entries) {
      if (!const {'app', 'postTile', 'fow', 'actionButton'}.contains(e.key)) throw RasqPackageException('theme.surfaces の ${e.key} は使えません(app / postTile / fow / actionButton)');
      for (final l in ((e.value as Map?)?['layers'] as List? ?? const [])) {
        // レイヤーは画像(asset)かグラデーション(gradient、v0.17)のどちらか 1 つ。
        final hasAsset = l is Map && l['asset'] != null;
        final hasGradient = l is Map && l['gradient'] != null;
        if (hasAsset == hasGradient) throw RasqPackageException('theme.surfaces.${e.key}.layers: asset か gradient のどちらか 1 つを書いてください');
        if (hasAsset) need(l['asset'], 'surfaces.${e.key}.layers');
        if (hasGradient) {
          final g = l['gradient'];
          final colors = g is Map ? g['colors'] : null;
          final stops = g is Map ? g['stops'] : null;
          if (colors is! List || colors.length < 2 || colors.length > 8) throw RasqPackageException('theme.surfaces.${e.key}.layers: gradient.colors は 2〜8 色です');
          if (stops is List && stops.length != colors.length) throw RasqPackageException('theme.surfaces.${e.key}.layers: gradient.stops は colors と同じ数です');
        }
      }
    }
  }
}
final _pathChars = RegExp(r'^[A-Za-z0-9_][A-Za-z0-9_./-]*$');

/// 配布物内のパスの文法(`bundle.schema.json` の `path`): 相対、`..` なし、英数字と `_ . / -` だけ。
void _checkPath(String p) {
  final ok = _pathChars.hasMatch(p) && !p.startsWith('/') && !p.split('/').any((s) => s.isEmpty || s == '..' || s == '.');
  if (!ok) throw RasqPackageException('配布物内のパスとして使えません: $p');
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
  if (sig['alg'] != 'ed25519') throw RasqPackageException('署名の alg が ed25519 ではありません: ${sig['alg']}');
  final digest = sha512.convert(packageBytes);
  if (sig['digest'] != 'sha512:$digest') throw const RasqPackageException('sig.json の digest が配布物と違います(配布物が差し替わっています)');
  final Uint8List publicKey, signature;
  try {
    publicKey = base64Decode(sig['publicKey'] as String);
    signature = base64Decode(sig['signature'] as String);
  } catch (_) {
    throw const RasqPackageException('sig.json の publicKey / signature を読めません');
  }
  if (publicKey.length != 32 || signature.length != 64) throw const RasqPackageException('sig.json の鍵 / 署名の長さが違います');
  final ok = await Ed25519().verify(Uint8List.fromList(digest.bytes), signature: Signature(signature, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)));
  if (!ok) throw const RasqPackageException('開発者鍵の署名が合いません');
  return sha512.convert(publicKey).bytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
