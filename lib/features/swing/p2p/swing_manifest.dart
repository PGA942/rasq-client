import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

/// P2P の Swing の目録と署名 (D-549 / Central S-128、仕様 `swing-p2p-spec.md` §1)。
///
/// - 目録 `rasq.swing-manifest/1` は Central の `src/swing/p2p.rs` と同じ形。知らない項目を入れると Central が断る。
/// - 署名 = Ed25519(`"rasq-swing-v1\n"` ‖ SHA-256(JCS(目録)))。JCS は RFC 8785 の正規化。**目録の数は整数だけ**
///   (Central と同じ。小数の書き方の違いで正規化がずれないように)。
/// - 見る側は、署名と、受け取った実体の SHA-256 が `media.sha256` に合うことを確かめてから表示する。

/// 署名の前置き(Central の `SIGNING_CONTEXT`)。
const swingSigningContext = 'rasq-swing-v1\n';

/// JCS で正規化した JSON の文字列。整数でない数があれば [FormatException]。
String canonicalJson(Object? v) {
  final out = StringBuffer();
  _write(v, out);
  return out.toString();
}

void _write(Object? v, StringBuffer out) {
  switch (v) {
    case null:
      out.write('null');
    case bool b:
      out.write(b ? 'true' : 'false');
    case int i:
      out.write(i);
    case num _:
      throw const FormatException(
        'numbers in a Swing manifest must be integers',
      );
    case String s:
      _writeString(s, out);
    case List<Object?> l:
      out.write('[');
      for (var i = 0; i < l.length; i++) {
        if (i > 0) out.write(',');
        _write(l[i], out);
      }
      out.write(']');
    case Map<Object?, Object?> m:
      // キーは UTF-16 の並び(Dart の文字列の比較そのもの)。
      final keys = [for (final k in m.keys) '$k']..sort();
      out.write('{');
      for (var i = 0; i < keys.length; i++) {
        if (i > 0) out.write(',');
        _writeString(keys[i], out);
        out.write(':');
        _write(m[keys[i]], out);
      }
      out.write('}');
    default:
      throw FormatException(
        'unsupported value in a Swing manifest: ${v.runtimeType}',
      );
  }
}

/// JSON の文字列(RFC 8785 §3.2.2.2: `"` `\` と制御文字だけを逃がす。制御文字は短い形か小文字の \u00xx)。
void _writeString(String s, StringBuffer out) {
  out.write('"');
  for (final c in s.codeUnits) {
    switch (c) {
      case 0x22:
        out.write(r'\"');
      case 0x5c:
        out.write(r'\\');
      case 0x08:
        out.write(r'\b');
      case 0x0c:
        out.write(r'\f');
      case 0x0a:
        out.write(r'\n');
      case 0x0d:
        out.write(r'\r');
      case 0x09:
        out.write(r'\t');
      default:
        if (c < 0x20) {
          out.write(r'\u');
          out.write(c.toRadixString(16).padLeft(4, '0'));
        } else {
          out.writeCharCode(c);
        }
    }
  }
  out.write('"');
}

/// SHA-256(JCS(目録))。
Uint8List manifestDigest(Map<String, Object?> manifest) => Uint8List.fromList(
  crypto.sha256.convert(utf8.encode(canonicalJson(manifest))).bytes,
);

/// 署名する(される)バイト列: 前置き ‖ SHA-256(JCS(目録))。
Uint8List signingInput(List<int> digest) =>
    Uint8List.fromList([...utf8.encode(swingSigningContext), ...digest]);

/// 小文字の 16 進。
String hexOf(List<int> bytes) =>
    [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

/// 実体の SHA-256(小文字の 16 進)。
String sha256Hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// UUID v4(端末が Swing の id を決める)。
String newSwingId([Random? random]) {
  final r = random ?? Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = hexOf(b);
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// 目録の実体の部分。
typedef SwingManifestMedia = ({String sha256, int size, String contentType});

/// 目録を作る。本文と CW は Central と同じく前後の空白を落としておく(Central は直さずに断るので、署名の前にそろえる)。
/// [plugin] は `{id, version?, data?, session?}`(未審査の入れ物は P2P で出さない)。
Map<String, Object?> buildSwingManifest({
  required String swingId,
  required String authorAccountId,
  required String deviceId,
  required String kind,
  String text = '',
  String? cw,
  bool sensitive = false,
  SwingManifestMedia? media,
  Map<String, Object?>? plugin,
  required Map<String, Object?> audience,
  Map<String, Object?>? notify,
  required int ttlHours,
  required DateTime createdAt,
}) {
  final c = cw?.trim();
  return {
    'v': 1,
    'swingId': swingId,
    'author': authorAccountId,
    'deviceId': deviceId,
    'kind': kind,
    'text': text.trim(),
    'cw': (c == null || c.isEmpty) ? null : c,
    'sensitive': sensitive,
    if (media != null)
      'media': {
        'sha256': media.sha256,
        'size': media.size,
        'contentType': media.contentType,
      },
    'plugin': ?plugin,
    'audience': audience,
    'notify': ?notify,
    'ttlHours': ttlHours,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

// ── 転送の区切り ────────────────────────────────────────────────

/// DataChannel で送る 1 つの塊の大きさ(どの実装でも分けずに届く大きさ)。
const swingChunkBytes = 16 * 1024;

/// 送る側の最初の知らせ(テキストのフレーム)。
String swingTransferHeader({
  required String swingId,
  required int size,
  required String sha256,
}) => jsonEncode({
  't': 'head',
  'swingId': swingId,
  'size': size,
  'sha256': sha256,
});

/// 送り終えた知らせ(テキストのフレーム)。
const swingTransferDone = '{"t":"done"}';

/// [bytes] を [swingChunkBytes] ずつに分ける。
Iterable<Uint8List> swingChunks(Uint8List bytes) sync* {
  for (var i = 0; i < bytes.length; i += swingChunkBytes) {
    yield Uint8List.sublistView(
      bytes,
      i,
      min(i + swingChunkBytes, bytes.length),
    );
  }
}

/// 受ける側: 最初の知らせ → 塊 → 終わりの知らせを組み立て、大きさとハッシュを確かめる。
class SwingAssembler {
  SwingAssembler({required this.expectSha256, required this.maxBytes});

  /// 目録の `media.sha256`(見る側が Central から受け取ったもの。送る側の言い分は信じない)。
  final String expectSha256;
  final int maxBytes;

  int? _size;
  final _buf = BytesBuilder(copy: false);

  /// テキストのフレーム。終わったら確かめた実体を返す。形が違う / 大きさやハッシュが合わなければ [FormatException]。
  Uint8List? text(String frame) {
    final j = jsonDecode(frame);
    if (j is! Map) throw const FormatException('bad frame');
    switch (j['t']) {
      case 'head':
        final size = j['size'];
        if (size is! int || size <= 0 || size > maxBytes) {
          throw const FormatException('bad size');
        }
        if (j['sha256'] != expectSha256) {
          throw const FormatException('the source offers another body');
        }
        _size = size;
        return null;
      case 'done':
        final size = _size;
        if (size == null || _buf.length != size) {
          throw const FormatException('incomplete body');
        }
        final bytes = _buf.takeBytes();
        if (sha256Hex(bytes) != expectSha256) {
          throw const FormatException('the body does not match the manifest');
        }
        return bytes;
      default:
        throw const FormatException('bad frame');
    }
  }

  /// バイナリのフレーム。
  void binary(Uint8List chunk) {
    final size = _size;
    if (size == null) throw const FormatException('body before head');
    if (_buf.length + chunk.length > size) {
      throw const FormatException('body is longer than announced');
    }
    _buf.add(chunk);
  }
}
