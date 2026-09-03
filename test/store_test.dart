import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// M4 / D-120: プラグインストア — ホーム(トレンド/最近の更新/検索)、
/// プラグインページ(常設安全性ブロック)、インストール確認シート +
/// SHA-512 検証、アンインストール。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [fakeSession().toJson()],
        'current': fakeSession().account.key,
      }),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p1', 'ふつうの投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<void> openStore(WidgetTester tester, ProviderContainer container) async {
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RasqSidebar), matching: find.text('プラグイン')));
    await tester.pumpAndSettle();
  }

  testWidgets('ストアホーム: サイドバーの「プラグイン」から開き、トレンド/最近の更新 + 検索で絞り込み', (tester) async {
    final container = await pump(tester);
    await openStore(tester, container);

    expect(find.text('プラグインストア'), findsOneWidget);
    expect(find.text('今週のトレンド'), findsOneWidget);
    expect(find.text('最近の更新'), findsOneWidget);
    expect(find.text('Misskey コネクタ'), findsOneWidget);
    expect(find.text('広告フィルター'), findsOneWidget);

    // 検索: SigLIP → レコメンダーだけに絞られる。
    await tester.enterText(find.byType(TextField).first, 'SigLIP');
    await tester.pumpAndSettle();
    expect(find.text('SigLIP レコメンダー'), findsOneWidget);
    expect(find.text('Misskey コネクタ'), findsNothing);
  });

  testWidgets('プラグインページ: 安全性ブロック → インストール確認シート → SHA-512 検証 → 削除', (tester) async {
    final container = await pump(tester);
    await openStore(tester, container);

    await tester.tap(find.text('SigLIP レコメンダー').first);
    await tester.pumpAndSettle();

    // 常設安全性ブロック (D-033): 権限 + 用途理由、互換性。
    expect(find.text('権限と安全性'), findsOneWidget);
    expect(find.textContaining('gpu_ml — 埋め込み計算を GPU で実行するため'), findsOneWidget);
    expect(find.text('互換性'), findsOneWidget);

    // インストール → 確認シート(権限が根拠)→ 確定。
    await tester.tap(find.text('インストール'));
    await tester.pumpAndSettle();
    expect(find.text('このプラグインが使う権限'), findsOneWidget);
    await tester.tap(find.text('インストールする'));
    await tester.pumpAndSettle();

    // SHA-512 検証を通ってインストール済みに(KV 永続)。
    expect(find.textContaining('インストール済み v1.2.1'), findsOneWidget);
    final installed = container.read(installedPluginsProvider);
    expect(installed.map((p) => p.id), contains('net.example.siglip-reco'));
    expect(installed.first.sha512, isNotEmpty);

    // 削除でアンインストール。
    await tester.tap(find.text('削除'));
    await tester.pumpAndSettle();
    expect(container.read(installedPluginsProvider), isEmpty);
    expect(find.text('インストール'), findsOneWidget);
  });

  test('改ざんされた配布物は SHA-512 不一致でインストール失敗', () async {
    final container = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
      storeClientProvider.overrideWithValue(_TamperedStoreClient()),
    ]);
    addTearDown(container.dispose);
    final outcome = await container.read(installedPluginsProvider.notifier).install('net.example.dict-sort');
    expect(outcome.error, contains('SHA-512'));
    expect(container.read(installedPluginsProvider), isEmpty);
  });
}

/// マニフェストは正規、配布物だけ差し替えられた(改ざん)モック。
class _TamperedStoreClient extends MockStoreClient {
  @override
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId) async => Uint8List.fromList(utf8.encode('tampered!'));
}
