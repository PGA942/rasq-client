import 'dart:convert';

import 'json_bytes_inline.dart' if (dart.library.io) 'json_bytes_isolate.dart' as impl;

/// 大きい応答(絵文字の一覧・タイムラインのページ)を、UI のスレッドを止めずにデコードする目安(バイト)。
const largeJsonBytes = 64 * 1024;

/// UTF-8 の JSON をデコードする。[largeJsonBytes] を超えるものは、Web 以外では別の isolate で(画面のカクつきを避ける)。
Future<Object?> decodeJsonBytes(List<int> bytes) async {
  if (bytes.length < largeJsonBytes) return jsonDecode(utf8.decode(bytes));
  return impl.decodeLarge(bytes);
}
