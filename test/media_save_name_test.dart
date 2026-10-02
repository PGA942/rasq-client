import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/media/image_saver.dart';
import 'package:rasq_models/rasq_models.dart';

/// D-407 (セキュリティ指摘 #25): SNS の添付ファイル名(相手のサーバーが決める)で、保存先のフォルダーの外へ書かせない / 上書きさせない。
void main() {
  MediaItem item(String? fileName, {MediaType type = MediaType.image, String url = 'https://media.example/files/abc.png'}) =>
      MediaItem(id: 'm/1', type: type, url: Uri.parse(url), fileName: fileName);

  test('ファイル名: パス区切りの前と先頭の . を捨て、1 つのファイル名にする', () {
    expect(mediaSaveFileName(item('../existing.png')), 'existing.png');
    expect(mediaSaveFileName(item('../../Library/Preferences/x.plist')), 'x.plist');
    expect(mediaSaveFileName(item(r'..\..\evil.png')), 'evil.png');
    expect(mediaSaveFileName(item('..')), 'rasq_m_1.png');
    expect(mediaSaveFileName(item('.hidden')), 'hidden.png');
    expect(mediaSaveFileName(item('a\u0000b:c?.jpg')), 'a_b_c_.jpg');
    expect(mediaSaveFileName(item('写真 1.JPG')), '写真 1.jpg');
    expect(mediaSaveFileName(item('noext')), 'noext.png');
    expect(mediaSaveFileName(item(null)), 'rasq_m_1.png');
    expect(mediaSaveFileName(item(null, type: MediaType.video, url: 'https://media.example/v')), 'rasq_m_1.mp4');
    for (final n in ['../a.png', '/etc/passwd', r'C:\x\y.png', '....png', 'a/../../b.png']) {
      final s = mediaSaveFileName(item(n));
      expect(s.contains('/') || s.contains(r'\') || s.startsWith('.'), isFalse, reason: n);
    }
  });

  test('保存: フォルダーの直下に、既にあるファイルは上書きせずに別名で書く。区切りの入った名前は断る', () async {
    final root = await Directory.systemTemp.createTemp('rasq_save_');
    addTearDown(() => root.delete(recursive: true));
    final docs = await Directory('${root.path}/保存').create();
    final sibling = File('${root.path}/existing.png')..writeAsStringSync('keep');
    final name = mediaSaveFileName(item('../existing.png'));
    final a = await writeMediaFileExclusive(docs, name, [1, 2, 3]);
    expect(a.parent.absolute.path, docs.absolute.path);
    expect(sibling.readAsStringSync(), 'keep', reason: '兄弟のファイルは変わらない');
    final b = await writeMediaFileExclusive(docs, name, [4]);
    expect(b.path, endsWith('existing (2).png'));
    expect(a.readAsBytesSync(), [1, 2, 3], reason: '上書きしない');
    await expectLater(writeMediaFileExclusive(docs, '../existing.png', [9]), throwsArgumentError);
    await expectLater(writeMediaFileExclusive(docs, '..', [9]), throwsArgumentError);
    expect(sibling.readAsStringSync(), 'keep');
  });
}
