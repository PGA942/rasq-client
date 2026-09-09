import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-156: インラインフレームモードの小表示 — TL の引用は通常の埋め込みタイル、
/// スレッド展開の引用とリアクション表示の対象投稿は小表示(サムネイル最大 4 枚)。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  MediaItem img(int i) => MediaItem(id: 'm$i', type: MediaType.image, url: Uri.parse('https://x.invalid/$i.png'), thumbnailUrl: Uri.parse('https://x.invalid/t$i.png'));
  const quotedAcc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'quoted');
  const posterAcc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'poster');
  final quoted = Post(id: 'q1', account: acc, author: const UserSummary(id: 'u-q', account: quotedAcc, displayName: '引用元'), createdAt: DateTime(2026, 9, 8), body: '引用された投稿の本文', media: [for (var i = 0; i < 5; i++) img(i)]);
  final posts = [
    Post(id: 'p1', account: acc, author: const UserSummary(id: 'u1', account: posterAcc, displayName: '投稿者'), createdAt: DateTime(2026, 9, 9), body: '引用つきの投稿', quote: quoted),
    quoted,
  ];

  testWidgets('TL では埋め込みタイル、スレッド展開では小表示(2×2 のサムネイル + "+1")、リアクション表示の対象も小表示', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => posts));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    // TL: 引用は通常の埋め込みタイル(小表示カードは出ない)。
    expect(find.text('引用つきの投稿'), findsOneWidget);
    expect(find.byType(RasqInlinePostCard), findsNothing);
    expect(find.byType(RasqMediaGrid), findsWidgets);

    // スレッド展開: 引用が小表示 — 小アバター + 名前 + @handle、左に 2×2 サムネイル、5 枚目以降は +1。
    await tester.tap(find.text('引用つきの投稿'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqInlinePostCard), findsWidgets);
    expect(find.byKey(const Key('inline.thumbs.4')), findsOneWidget);
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('@quoted'), findsWidgets);
    expect(find.textContaining('引用された投稿の本文'), findsWidgets);

    // リアクション表示: 対象投稿が小表示(引用ではなく投稿そのもの)。
    await tester.tap(find.text('リアクションを表示'));
    await tester.pumpAndSettle();
    expect(find.byType(RasqInlinePostCard), findsWidgets);
    expect(find.text('@poster'), findsWidgets);
    // 小表示のタップでそのスレッドへ。
    await tester.tap(find.byType(RasqInlinePostCard).first);
    await tester.pumpAndSettle();
    expect(find.text('投稿'), findsWidgets);
  });
}
