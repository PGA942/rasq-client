import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

/// 別の isolate でデコードする(戻りの Map / List は isolate の間でそのまま渡る)。
Future<Object?> decodeLarge(List<int> bytes) {
  final copy = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  return Isolate.run(() => jsonDecode(utf8.decode(copy)));
}
