import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/plugins/pro_media_editor_screen.dart';

/// 動画編集の一時ファイル (D-248): 置き場が無くても書ける / 元のファイル名(空白・日本語)をパスに持ち込まない。
void main() {
  test('置き場が無ければ作り、ファイル名は ASCII + 元の拡張子', () async {
    final root = Directory.systemTemp.createTempSync('rasq-d248');
    addTearDown(() => root.deleteSync(recursive: true));
    final dir = Directory('${root.path}/Caches/com.example.rasqClient');
    expect(dir.existsSync(), isFalse);

    final f = await videoEditTempFile(dir, '画面収録 2026-09-14 21.56.49.mov');
    await f.writeAsBytes([1, 2, 3], flush: true);
    expect(f.existsSync(), isTrue);
    final base = f.uri.pathSegments.last;
    expect(base, matches(RegExp(r'^rasq_edit_\d+\.mov$')));
  });

  test('拡張子が無い / 変な名前は mp4 扱い', () async {
    final root = Directory.systemTemp.createTempSync('rasq-d248');
    addTearDown(() => root.deleteSync(recursive: true));
    expect((await videoEditTempFile(root, 'video')).path, endsWith('.mp4'));
    expect((await videoEditTempFile(root, 'a/b.MOV')).path, matches(RegExp(r'rasq_edit_\d+\.mov$')));
    expect((await videoEditTempFile(root, 'x.日本語')).path, endsWith('.mp4'));
  });
}
