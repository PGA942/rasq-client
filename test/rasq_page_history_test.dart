import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/profile/rasq_page_history.dart';
import 'package:rasq_client/session/session_storage.dart';

/// 開いた RASQ アカウントページの履歴 (D-272): 新しい順、同じアカウントは 1 つ、8 件まで、保存される。
void main() {
  test('record: 先頭へ、重複なし(大文字小文字を見ない)、上限、保存と復元', () async {
    final storage = MemorySessionStorage({});
    final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(c.dispose);
    final h = c.read(rasqPageHistoryProvider.notifier);
    await h.record(const RasqVisited(handle: 'taro', displayName: 'タロ'));
    await h.record(const RasqVisited(handle: 'hanako'));
    await h.record(const RasqVisited(handle: 'Taro', displayName: 'タロ 2'));
    expect([for (final v in c.read(rasqPageHistoryProvider)) v.handle], ['Taro', 'hanako']);
    for (var i = 0; i < 10; i++) {
      await h.record(RasqVisited(handle: 'u$i'));
    }
    expect(c.read(rasqPageHistoryProvider), hasLength(RasqPageHistory.max));
    expect(c.read(rasqPageHistoryProvider).first.handle, 'u9');
    expect((jsonDecode((await storage.read(RasqPageHistory.storageKey))!) as List), hasLength(RasqPageHistory.max));

    // 別の起動: 保存したものが戻る。http(s) でないアイコンの URL は捨てる。
    await storage.write(RasqPageHistory.storageKey, jsonEncode([{'handle': 'mio', 'avatarUrl': 'javascript:alert(1)'}, {'handle': 'rin', 'avatarUrl': 'https://c.test/a.png'}]));
    final c2 = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(c2.dispose);
    c2.read(rasqPageHistoryProvider);
    await Future<void>.delayed(Duration.zero);
    final restored = c2.read(rasqPageHistoryProvider);
    expect([for (final v in restored) v.handle], ['mio', 'rin']);
    expect(restored.first.avatarUrl, isNull);
    expect(restored.last.avatarUrl.toString(), 'https://c.test/a.png');
  });
}
