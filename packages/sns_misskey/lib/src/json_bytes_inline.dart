import 'dart:convert';

/// Web: isolate が無いので、その場でデコードする。
Future<Object?> decodeLarge(List<int> bytes) async => jsonDecode(utf8.decode(bytes));
