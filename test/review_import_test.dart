import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/dev/review_import.dart';
import 'package:rasq_client/features/dev/wasm_plugin_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';

/// D-436: 審査中の版の仮インポート(rasq-judge J-017 の 4 段目と対)。
void main() {
  group('リンク', () {
    test('rasq://dev-import?url=… はインポートの画面へ(URL を入れるだけ)。http(s) でない / ほかのリンクは入れない', () {
      const judge = 'https://rasqjp.example.ts.net:6443/review-dl/abc_DEF-123';
      expect(reviewImportDeepLinkLocation(Uri.parse('rasq://dev-import?url=${Uri.encodeComponent(judge)}')), '/dev/wasm?url=${Uri.encodeQueryComponent(judge)}');
      expect(reviewImportDeepLinkLocation(Uri.parse('rasq://dev-import?url=javascript:alert(1)')), '/dev/wasm');
      expect(reviewImportDeepLinkLocation(Uri.parse('rasq://dev-import')), '/dev/wasm');
      expect(reviewImportDeepLinkLocation(Uri.parse('rasq://child-safe/pair?code=X')), isNull);
    });

    test('置くファイルの名前は content-disposition から、英数字と ._- だけ', () {
      expect(reviewImportFileName('attachment; filename="sample.board-0.1.0.rasqpkg"', 'https://j/review-dl/t'), 'sample.board-0.1.0.rasqpkg');
      expect(reviewImportFileName('attachment; filename="../../etc/x"', 'https://j/x'), 'review-import.rasqpkg', reason: '. で始まる名前(上の階層)は使わない');
      expect(reviewImportFileName(null, 'https://j/review-dl/t'), 'review-import.rasqpkg');
    });
  });

  testWidgets('QR から開く → URL 入り(押すまで読まない)→「URL から読む」で落として読み込み、入っていない親(土台)は「ストアで開く」', (tester) async {
    final pkg = File('test/fixtures/rasqpkg/net.example.later-0.1.0.rasqpkg').readAsBytesSync();
    final dir = Directory.systemTemp.createTempSync('review-import');
    addTearDown(() => dir.deleteSync(recursive: true));
    final requests = <Uri>[];
    final client = MockClient((req) async {
      requests.add(req.url);
      if (req.url.path.endsWith('/gone')) return http.Response('', 404);
      return http.Response.bytes(pkg, 200, headers: {'content-disposition': 'attachment; filename="net.example.later-0.1.0.rasqpkg"'});
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        reviewImportHttpProvider.overrideWithValue(client),
        reviewImportDirProvider.overrideWithValue(() async => dir),
      ],
      child: MaterialApp(
        theme: RasqTheme.light(),
        home: WasmPluginScreen(
          wasmBytesOverride: pkg,
          envOverride: RasqHostEnvironment(permissions: const {}),
          initialUrl: 'https://judge.test/review-dl/gone',
        ),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const ValueKey('wasm.url.fromLink')), findsOneWidget);
    expect(requests, isEmpty, reason: '開いただけでは落とさない');

    // 期限切れのリンク。
    await tester.tap(find.byKey(const ValueKey('wasm.url.load')));
    for (var i = 0; i < 40 && find.textContaining('リンクの期限が切れた').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(find.textContaining('リンクの期限が切れた'), findsOneWidget);

    await tester.enterText(find.descendant(of: find.byKey(const ValueKey('wasm.url.field')), matching: find.byType(EditableText)), 'https://judge.test/review-dl/ok');
    await tester.tap(find.byKey(const ValueKey('wasm.url.load')));
    for (var i = 0; i < 80 && find.byKey(const ValueKey('wasm.parent.dev.test.mysns')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(File('${dir.path}/net.example.later-0.1.0.rasqpkg').existsSync(), isTrue);
    expect(find.textContaining('net.example.later 0.1.0'), findsWidgets, reason: '.rasqpkg として読み込んだ');
    expect(find.byKey(const ValueKey('wasm.parent.dev.test.mysns')), findsOneWidget);
    expect(find.byKey(const ValueKey('wasm.parent.store.dev.test.mysns')), findsOneWidget);
  });
}
