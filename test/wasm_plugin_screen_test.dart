import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/dev/wasm_plugin_screen.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

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

  testWidgets('境界セッション (D-074/M5d): 境界TL → sns.timeline → Post ワイヤ → PostRow で描画', (tester) async {
    if (!wasmFile.existsSync()) {
      markTestSkipped('misskey-wasm-sample not built');
      return;
    }
    final canned = jsonEncode([
      {
        'id': 'n1',
        'text': '境界越えの投稿',
        'cw': null,
        'createdAt': '2026-08-30T12:00:00.000Z',
        'user': {'username': 'douglas', 'name': 'ダグラス', 'host': null, 'avatarUrl': null},
        'files': [],
        'repliesCount': 0,
        'renoteCount': 2,
        'reactions': {'👍': 3},
      },
    ]);
    final env = RasqHostEnvironment(fetch: (req) => SyncFetchResponse(status: 200, bodyText: canned));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage())],
      child: MaterialApp(
        theme: RasqTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: WasmPluginScreen(wasmBytesOverride: wasmFile.readAsBytesSync(), envOverride: env),
        ),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('境界TL'));
    await tester.pumpAndSettle();

    // Post ワイヤがホストの通常パイプライン(PostRow → RasqPostTile)で出る。
    expect(find.textContaining('境界セッション: sns.timeline'), findsOneWidget);
    expect(find.byType(RasqPostTile), findsOneWidget);
    expect(find.text('境界越えの投稿'), findsOneWidget);
    expect(find.text('ダグラス'), findsOneWidget);
  });

  testWidgets('FOW surface (D-064): プラグインの fow.open が実 FOW になり、絵文字タップの fow.close で閉じる', (tester) async {
    if (!wasmFile.existsSync()) {
      markTestSkipped('misskey-wasm-sample not built');
      return;
    }
    final manager = OverlayManager();
    await tester.pumpWidget(MaterialApp(
      theme: RasqTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: OverlayScope(
          manager: manager,
          child: OverlayHost(
            manager: manager,
            child: WasmPluginScreen(wasmBytesOverride: wasmFile.readAsBytesSync(), envOverride: RasqHostEnvironment()),
          ),
        ),
      ),
    ));
    await tester.pump();

    // 初期ツリーの「FOWデモ」Button → プラグインが fow.open を要求。
    await tester.tap(find.text('FOWデモ'));
    await tester.pumpAndSettle();
    expect(find.text('リアクション (wasm)'), findsOneWidget); // ヘッダー行クローム(タイトル)
    expect(find.text('閉じる'), findsOneWidget);
    expect(find.text('👍'), findsOneWidget);
    expect(find.textContaining('postId: p-demo'), findsNothing); // postId 無しの入口

    // surface patch (D-073): +1 → カウンターだけ差分更新(FOW は開いたまま)。
    expect(find.text('タップ 0 回'), findsOneWidget);
    await tester.tap(find.text('+1'));
    await tester.pumpAndSettle();
    expect(find.text('タップ 1 回'), findsOneWidget);
    expect(find.text('リアクション (wasm)'), findsOneWidget);

    // FOW 内の絵文字 Button → event → reactFromFow → プラグイン発 fow.close。
    await tester.tap(find.text('👍'));
    await tester.pumpAndSettle();
    expect(find.text('リアクション (wasm)'), findsNothing);

    // 再度開いて ✕(閉じる)→ ホストは閉じずにプラグインの onCancel が
    // 呼ばれ、**画面そのままで確認ポップアップ**(確認 FOW)が出る (D-066)。
    await tester.tap(find.text('FOWデモ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    expect(find.text('リアクション (wasm)'), findsOneWidget); // 本体は残る
    expect(find.text('閉じますか?'), findsOneWidget);

    // 「続ける」→ 確認だけ閉じて本体は残る。
    await tester.tap(find.text('続ける'));
    await tester.pumpAndSettle();
    expect(find.text('閉じますか?'), findsNothing);
    expect(find.text('リアクション (wasm)'), findsOneWidget);

    // ✕ → 「破棄」→ 両方閉じる。
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('破棄'));
    await tester.pumpAndSettle();
    expect(find.text('閉じますか?'), findsNothing);
    expect(find.text('リアクション (wasm)'), findsNothing);
  });
}
