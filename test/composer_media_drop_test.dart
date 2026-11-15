import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/compose/composer_sheet.dart';
import 'package:rasq_client/features/compose/media_drop.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// コンポーザーへのメディアのドロップ (D-555) と添付の並べ替え (D-556)。
void main() {
  // 1×1 の PNG。
  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

  DroppedMediaFile file(String name, {String? mime}) => DroppedMediaFile(name: name, mimeType: mime, read: () async => Uint8List(1));

  group('振り分け', () {
    test('画像 / 動画 / 音声は拡張子でも MIME でも受け、ほかは入れない', () {
      expect(droppedMediaMime('a.JPG'), 'image/jpeg');
      expect(droppedMediaMime('a.webp'), 'image/webp');
      expect(droppedMediaMime('clip.mov'), 'video/quicktime');
      expect(droppedMediaMime('voice.m4a'), 'audio/mp4');
      expect(droppedMediaMime('noext', reported: 'image/png'), 'image/png');
      expect(droppedMediaMime('memo.txt'), isNull);
      expect(droppedMediaMime('folder'), isNull);
    });

    test('上限までを落とした順に入れ、超えた分とメディアでないものを数える', () {
      final plan = planMediaDrop([file('1.png'), file('memo.txt'), file('2.png'), file('3.mp4'), file('4.png')], current: 1, max: 4);
      expect([for (final (f, _) in plan.accepted) f.name], ['1.png', '2.png', '3.mp4']);
      expect(plan.accepted.map((e) => e.$2), ['image/png', 'image/png', 'video/mp4']);
      expect(plan.notMedia, ['memo.txt']);
      expect(plan.overLimit, 1);
      // RASQ(6 件)の上限でも同じ式。
      final rasq = planMediaDrop([for (var i = 0; i < 8; i++) file('$i.png')], current: 0, max: 6);
      expect(rasq.accepted.length, 6);
      expect(rasq.overLimit, 2);
    });

    test('並べ替えは onReorderItem の (元の位置, 動かしたあとの位置)', () {
      final l = ['a', 'b', 'c', 'd'];
      moveAttachment(l, 0, 2);
      expect(l, ['b', 'c', 'a', 'd']);
      moveAttachment(l, 3, 0);
      expect(l, ['d', 'b', 'c', 'a']);
      moveAttachment(l, 1, 1);
      expect(l, ['d', 'b', 'c', 'a']);
      moveAttachment(l, 9, 0);
      expect(l, ['d', 'b', 'c', 'a']);
    });
  });

  Future<void> openComposer(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final plugin = FakeSnsPlugin(posts: MockData.timeline);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(plugin)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    await openHomeComposer(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ComposerMediaDropTarget), findsOneWidget);
  }

  // desktop_drop の口(ios/Runner/MediaDropBridge.swift も同じ口で話す)。
  Future<void> channel(WidgetTester tester, String method, [Object? args]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage('desktop_drop', const StandardMethodCodec().encodeMethodCall(MethodCall(method, args)), (_) {});
    await tester.pump();
  }

  Offset composerCenter(WidgetTester tester) => tester.getCenter(find.byType(ComposerMediaDropTarget));

  Future<void> hover(WidgetTester tester, Offset at) async {
    await channel(tester, 'entered', [at.dx, at.dy]);
    await channel(tester, 'updated', [at.dx, at.dy]);
  }

  // Web の形(中身つき)で落とす。
  Future<void> drop(WidgetTester tester, List<(String, String, Uint8List)> items) async {
    await channel(tester, 'performOperation_web', [
      for (final (name, type, data) in items)
        {'uri': name, 'name': name, 'type': type, 'size': data.length, 'data': data, 'relativePath': null, 'lastModified': 0},
    ]);
    await tester.pumpAndSettle();
  }

  testWidgets('ホバー中は枠と「あと n 件」、離すと上限(SNS は 4 件)まで添付し、メディアでないもの / 超えた分は知らせる', (tester) async {
    await openComposer(tester);
    final at = composerCenter(tester);
    await hover(tester, at);
    expect(find.byKey(const ValueKey('composer.drop.hover')), findsOneWidget);
    expect(find.text('離すと添付します(あと 4 件)'), findsOneWidget);
    // 外へ出ると消える。
    await channel(tester, 'updated', [at.dx, 2000.0]);
    expect(find.byKey(const ValueKey('composer.drop.hover')), findsNothing);
    await hover(tester, at);
    await drop(tester, [
      for (var i = 1; i <= 5; i++) ('photo$i.png', 'image/png', png),
      ('memo.txt', 'text/plain', Uint8List.fromList(utf8.encode('x'))),
    ]);
    expect(find.byKey(const ValueKey('composer.drop.hover')), findsNothing);
    final attachments = find.byKey(const ValueKey('composer.attachments'));
    expect(find.descendant(of: attachments, matching: find.byType(Image)), findsNWidgets(4));
    expect(find.textContaining('memo.txt'), findsOneWidget);
    expect(find.textContaining('1 件は入れませんでした'), findsOneWidget);
    // いっぱいのときにまた持ってくると、受けられないことを出す(落としても増えない)。
    await hover(tester, composerCenter(tester));
    expect(find.text('添付は 4 件までです'), findsOneWidget);
    await drop(tester, [('more.png', 'image/png', png)]);
    expect(find.descendant(of: attachments, matching: find.byType(Image)), findsNWidgets(4));
  });

  testWidgets('コンポーザーの外に落としたものは入れない', (tester) async {
    await openComposer(tester);
    await channel(tester, 'entered', [10.0, 5.0]);
    await channel(tester, 'updated', [10.0, 5.0]);
    expect(find.byKey(const ValueKey('composer.drop.hover')), findsNothing);
    await drop(tester, [('photo.png', 'image/png', png)]);
    expect(find.byKey(const ValueKey('composer.attachments')), findsNothing);
  });

  testWidgets('添付は長押しして横へ動かすと並べ替えられる', (tester) async {
    await openComposer(tester);
    await hover(tester, composerCenter(tester));
    await drop(tester, [
      ('a.mp4', 'video/mp4', Uint8List(4)),
      ('b.mp4', 'video/mp4', Uint8List(4)),
      ('c.mp4', 'video/mp4', Uint8List(4)),
    ]);
    double x(String name) => tester.getCenter(find.text(name)).dx;
    expect(x('a.mp4') < x('b.mp4') && x('b.mp4') < x('c.mp4'), isTrue);
    // タッチの端末(テストは Android)は長押ししてから動かす。
    // タイルの真ん中を押す(角のボタンの当たりの外)。
    Offset tile(String name) => tester.getCenter(find.ancestor(of: find.text(name), matching: find.byType(ReorderableDelayedDragStartListener)));
    final g = await tester.startGesture(tile('a.mp4'));
    await tester.pump(const Duration(milliseconds: 600));
    for (var i = 0; i < 10; i++) {
      await g.moveBy(const Offset(24, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(x('b.mp4') < x('c.mp4') && x('c.mp4') < x('a.mp4'), isTrue, reason: 'b, c, a の順');
    // 長押しせずに払うのは並べ替えにならない(一覧の横スクロール)。
    await tester.dragFrom(tile('b.mp4'), const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(x('b.mp4') < x('c.mp4') && x('c.mp4') < x('a.mp4'), isTrue);
  });
}
