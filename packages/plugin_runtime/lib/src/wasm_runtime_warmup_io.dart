import 'dart:typed_data';

/// 端末では、zstd はネイティブのランタイムが持っている。支度は要らない。
Future<void> rasqZstdWarmUp(Uint8List wasmBytes) async {}
