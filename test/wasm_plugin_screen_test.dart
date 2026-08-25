import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/features/dev/wasm_plugin_screen.dart';
import 'package:rasq_design/rasq_design.dart';

/// End-to-end: the dev screen imports the real misskey-wasm-sample binary,
/// fetches a (canned) timeline through the host boundary and renders it.
void main() {
  final wasmFile = File('../rasq-sdk-sample/rust/target/wasm32-unknown-unknown/release/misskey_wasm_sample.wasm');

  testWidgets('import → TL取得 → RRL tree rendered as RasqPostTiles', (tester) async {
    if (!wasmFile.existsSync()) {
      markTestSkipped('misskey-wasm-sample not built');
      return;
    }
    final canned = jsonEncode([
      {
        'id': 'n1',
        'text': 'ローカルTLの投稿',
        'cw': null,
        'createdAt': '2026-08-23T12:00:00.000Z',
        'user': {'username': 'douglas', 'name': 'ダグラス', 'host': null, 'avatarUrl': null},
        'files': [],
        'repliesCount': 1,
        'renoteCount': 2,
        'reactions': {'👍': 3},
      },
    ]);
    final env = RasqHostEnvironment(fetch: (req) => SyncFetchResponse(status: 200, bodyText: canned));

    await tester.pumpWidget(MaterialApp(
      theme: RasqTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: WasmPluginScreen(wasmBytesOverride: wasmFile.readAsBytesSync(), envOverride: env),
      ),
    ));
    await tester.pump();

    // Initial snapshot (sample tile placeholder) is on screen.
    expect(find.byType(WasmPluginView), findsOneWidget);

    await tester.tap(find.text('TL取得'));
    await tester.pump();

    expect(find.byType(RasqPostTile), findsOneWidget);
    expect(find.text('ローカルTLの投稿'), findsOneWidget);
    expect(find.text('ダグラス'), findsOneWidget);
    expect(find.byType(RasqActionBar), findsOneWidget);
  });
}
