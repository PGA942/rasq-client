import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/clips/clip_timeline_screen.dart';
import 'package:rasq_client/features/clips/host_clips.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');

Post post(String id, String body) => Post(
      id: id,
      account: account,
      author: UserSummary(id: 'a$id', account: account, displayName: '作者$id'),
      createdAt: DateTime(2026, 8, 27, 12).add(Duration(minutes: int.parse(id))),
      body: body,
    );

void main() {
  testWidgets('クリップTL: 仮想目次が出て、章タップで絞り込み/解除できる (D-032/D-036)', (tester) async {
    final clip = HostClip(id: 'c1', name: '旅行の候補', createdAt: DateTime(2026, 8, 27), entries: [
      for (final p in [post('1', '#京都旅行 の宿を探す'), post('2', '#京都旅行 町家もいい'), post('3', '猫カフェのラテアート')])
        HostClipEntry(postKey: p.key, addedAt: p.createdAt, snapshot: postSnapshot(p)),
    ]);
    final storage = MemorySessionStorage({hostClipsStorageKey: jsonEncode([clip.toJson()])});

    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage)],
      child: MaterialApp(theme: RasqTheme.light(), home: ClipTimelineScreen(clip: clip.info)),
    ));
    await tester.pumpAndSettle();

    // ヘッダー + 目次 + 全 3 投稿。
    expect(find.text('旅行の候補'), findsOneWidget);
    expect(find.text('目次'), findsOneWidget);
    expect(find.text('#京都旅行'), findsOneWidget);
    expect(find.text('2件'), findsOneWidget);
    expect(find.textContaining('宿を探す'), findsOneWidget);
    expect(find.textContaining('ラテアート'), findsOneWidget);

    // 章をタップ → その章だけに絞り込み(元の所属は変えない、表示だけ)。
    await tester.tap(find.text('#京都旅行'));
    await tester.pumpAndSettle();
    expect(find.textContaining('宿を探す'), findsOneWidget);
    expect(find.textContaining('ラテアート'), findsNothing);
    expect(find.text('絞り込み中'), findsOneWidget);

    // もう一度タップで解除。
    await tester.tap(find.text('#京都旅行'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ラテアート'), findsOneWidget);
    expect(find.text('絞り込み中'), findsNothing);
  });
}
