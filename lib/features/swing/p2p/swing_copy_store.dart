import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// P2P の Swing の実体の置き場 (D-549 / Central S-128 §2)。
///
/// - 作った人は自分の実体を、見た人は受け取って確かめた実体を、**Swing の期限まで**置く(ほかの見る人へ配る / 通報の写しを送るため)。
/// - 期限が来たらすぐ消す(ユーザー決定: 期限後の猶予は持たない)。読むときも期限を見て、過ぎていれば消して無いことにする。
/// - 置き場は OS が掃除してよいキャッシュの場所(バックアップに載せない)。無くなっても、ほかの人からまた受け取れる。
/// - 端末の中だけ。暗号化はしない(OS のアプリごとの領域。中身は届け先の人に配られるもの)。
class SwingCopyStore {
  SwingCopyStore(this._root, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Future<Directory> Function() _root;
  final DateTime Function() _now;
  Directory? _dir;

  Future<Directory> _folder() async {
    final d = _dir;
    if (d != null) return d;
    final root = await _root();
    final dir = Directory('${root.path}${Platform.pathSeparator}swing_p2p');
    await dir.create(recursive: true);
    return _dir = dir;
  }

  static bool _safeId(String id) =>
      RegExp(r'^[0-9a-fA-F-]{1,64}$').hasMatch(id);

  Future<(File, File)?> _files(String swingId) async {
    if (!_safeId(swingId)) return null;
    final dir = await _folder();
    final sep = Platform.pathSeparator;
    return (
      File('${dir.path}$sep$swingId.bin'),
      File('${dir.path}$sep$swingId.json'),
    );
  }

  /// 置く(同じ Swing はそのまま上書き)。期限が過ぎていれば置かない。
  Future<void> put(
    String swingId,
    Uint8List bytes, {
    required String sha256,
    required DateTime expiresAt,
    String? contentType,
  }) async {
    if (!expiresAt.isAfter(_now())) return;
    final f = await _files(swingId);
    if (f == null) return;
    await f.$1.writeAsBytes(bytes, flush: true);
    await f.$2.writeAsString(
      jsonEncode({
        'sha256': sha256,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'contentType': contentType,
        'size': bytes.length,
      }),
    );
  }

  /// 期限内の実体(無い / 過ぎた / 壊れていれば null。過ぎたものは消す)。
  Future<Uint8List?> get(String swingId) async {
    final f = await _files(swingId);
    if (f == null) return null;
    final meta = await _meta(f.$2);
    if (meta == null) return null;
    if (!meta.expiresAt.isAfter(_now())) {
      await _delete(f);
      return null;
    }
    try {
      return await f.$1.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  /// 期限内の実体と、その SHA-256・型(配る側の最初の知らせと、通報の写しに使う)。
  Future<({Uint8List bytes, String sha256, String? contentType})?> entry(
    String swingId,
  ) async {
    final f = await _files(swingId);
    if (f == null) return null;
    final meta = await _meta(f.$2);
    final bytes = await get(swingId);
    if (meta == null || bytes == null) return null;
    String? type;
    try {
      final j = jsonDecode(await f.$2.readAsString());
      if (j is Map && j['contentType'] is String) {
        type = j['contentType'] as String;
      }
    } catch (_) {}
    return (bytes: bytes, sha256: meta.sha256, contentType: type);
  }

  /// 置いてある実体のファイル(画像 / 動画をファイルから出す)。無ければ [bytes] を一時の場所に書く。
  /// [extension] があれば(動画: iOS の再生器は拡張子で形式を見る)、OS の一時の場所にその拡張子で書く。
  Future<File> fileFor(String swingId, Uint8List bytes, {String? extension}) async {
    if (extension != null && _safeId(swingId)) {
      final dir = Directory('${Directory.systemTemp.path}${Platform.pathSeparator}rasq_swing');
      await dir.create(recursive: true);
      final out = File('${dir.path}${Platform.pathSeparator}$swingId.$extension');
      if (!await out.exists()) await out.writeAsBytes(bytes, flush: true);
      return out;
    }
    final f = await _files(swingId);
    if (f != null && await f.$1.exists()) return f.$1;
    final tmp = File('${(await _folder()).path}${Platform.pathSeparator}tmp-${bytes.hashCode}.bin');
    await tmp.writeAsBytes(bytes, flush: true);
    return tmp;
  }

  /// 期限内の実体があるか(読まずに)。
  Future<bool> has(String swingId) async {
    final f = await _files(swingId);
    if (f == null) return false;
    final meta = await _meta(f.$2);
    return meta != null &&
        meta.expiresAt.isAfter(_now()) &&
        await f.$1.exists();
  }

  Future<({DateTime expiresAt, String sha256})?> _meta(File f) async {
    try {
      if (!await f.exists()) return null;
      final j = jsonDecode(await f.readAsString());
      if (j is! Map) return null;
      final exp = DateTime.tryParse('${j['expiresAt']}');
      final sha = j['sha256'];
      if (exp == null || sha is! String) return null;
      return (expiresAt: exp, sha256: sha);
    } catch (_) {
      return null;
    }
  }

  Future<void> _delete((File, File) f) async {
    for (final x in [f.$1, f.$2]) {
      try {
        if (await x.exists()) await x.delete();
      } catch (_) {}
    }
  }

  /// 消す(消した Swing)。
  Future<void> delete(String swingId) async {
    final f = await _files(swingId);
    if (f != null) await _delete(f);
  }

  /// 期限の過ぎたものを全部消す。戻り = 消した数。
  Future<int> sweep() async {
    var n = 0;
    try {
      final dir = await _folder();
      await for (final e in dir.list()) {
        if (e is! File || !e.path.endsWith('.json')) continue;
        final meta = await _meta(e);
        final id = e.uri.pathSegments.last.replaceAll('.json', '');
        if (meta == null || !meta.expiresAt.isAfter(_now())) {
          final f = await _files(id);
          if (f != null) {
            await _delete(f);
            n++;
          } else {
            await e.delete();
          }
        }
      }
      // 目録の無い実体(書きかけで落ちた)も消す。
      await for (final e in dir.list()) {
        if (e is File &&
            e.path.endsWith('.bin') &&
            !await File(e.path.replaceAll(RegExp(r'\.bin$'), '.json'))
                .exists()) {
          await e.delete();
        }
      }
    } catch (e) {
      debugPrint('swing copies: sweep: $e');
    }
    return n;
  }
}
