import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:rasq_models/rasq_models.dart';

/// 「画像を保存」(D-213): 全画面表示の「…」/ 共有 FOW から。デスクトップはダウンロード、それ以外はアプリの
/// 書類フォルダへ。戻りは保存先のパス。テストでは差し替える。
final imageSaverProvider = Provider<Future<String> Function(MediaItem item)>((ref) => (item) async {
      final res = await http.get(item.url).timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) throw StateError('HTTP ${res.statusCode}');
      Directory? dir;
      if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) dir = await getDownloadsDirectory();
      dir ??= await getApplicationDocumentsDirectory();
      final ext = item.url.pathSegments.isNotEmpty && item.url.pathSegments.last.contains('.') ? item.url.pathSegments.last.split('.').last : 'jpg';
      final f = File('${dir.path}/rasq_${item.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}.$ext');
      await f.writeAsBytes(res.bodyBytes, flush: true);
      return f.path;
    });
