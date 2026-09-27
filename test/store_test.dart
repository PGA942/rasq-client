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

  /// プラグインページ本体の Scrollable(PageView の Scrollable より木の順で先)。
  Finder page() => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;
  Future<void> reveal(WidgetTester tester, Finder f, {bool up = false}) async {
    await tester.scrollUntilVisible(f, up ? -200 : 200, scrollable: page());
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> openStore(WidgetTester tester, ProviderContainer container) async {
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RasqSidebar), matching: find.text('プラグイン')));
    await tester.pumpAndSettle();
  }

  testWidgets('ストアホーム (D-353): サイドバーの「プラグイン」から開き、今週のトレンド / 新着のタイルの横の列。検索欄 → 検索画面(グリッド + 絞り込み)', (tester) async {
    final container = await pump(tester);
    await openStore(tester, container);

    expect(find.text('プラグインストア'), findsOneWidget);
    expect(find.text('今週のトレンド'), findsOneWidget);
    expect(find.text('新着'), findsOneWidget);
    // タイル: 明るい色の角丸の中に名前 / 開発者 / 説明 / DL 数。
    final misskey = find.byKey(const ValueKey('store.tile.$storeSamplePluginId'));
    expect(misskey, findsOneWidget);
    expect(find.descendant(of: misskey, matching: find.text('Misskey コネクタ')), findsOneWidget);
    expect(find.descendant(of: misskey, matching: find.textContaining('RASQ Project')), findsOneWidget);
    expect(find.descendant(of: misskey, matching: find.textContaining('1.3万 DL')), findsOneWidget);
    // 新着は 7 個まで(モックの新着は 16 件)。
    final recentList = tester.widget<ListView>(find.descendant(of: find.byKey(const ValueKey('store.home.recent')), matching: find.byType(ListView)));
    expect(recentList.childrenDelegate.estimatedChildCount, 7 * 2 - 1); // タイル 7 + 間 6

    // 検索欄 → 検索画面。SigLIP → レコメンダーだけ。
    await tester.tap(find.byKey(const ValueKey('store.home.search')));
    await tester.pumpAndSettle();
    expect(find.text('プラグインを検索'), findsWidgets);
    expect(find.byKey(const ValueKey('store.search.grid')), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'SigLIP');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.tile.net.example.siglip-reco')), findsOneWidget);
    expect(find.byKey(const ValueKey('store.tile.$storeSamplePluginId')), findsNothing);
    // 絞り込み: 語を消して「広告なし」+「軽量」→ SigLIP(96MB)は外れる。
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const ValueKey('store.search.box')), matching: find.byIcon(Icons.keyboard_arrow_down)).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('軽量(5MB 未満)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('store.tile.net.example.siglip-reco')), findsNothing);
    expect(find.byKey(const ValueKey('store.tile.$storeSamplePluginId')), findsOneWidget);
  });

  testWidgets('プラグインページ: 安全性ブロック → インストール確認シート → SHA-512 検証 → 削除', (tester) async {
    final container = await pump(tester);
    await openStore(tester, container);

    await tester.tap(find.text('SigLIP レコメンダー').first);
    await tester.pumpAndSettle();

    // 「全体像」(D-137): 依存の注意(Misskey コネクタが必要)+ インストールのピル。
    expect(find.textContaining('のインストールが必要です'), findsOneWidget);
    expect(find.text(storeSamplePluginId), findsOneWidget);

    // 常設安全性ブロック (D-033) は「プライバシーと必要な権限」の節に権限タイプ
    // ごとのフレームで残る(GPU / 機械学習 グループに gpu_ml)。
    await reveal(tester, find.text('プライバシーと必要な権限'));
    expect(find.text('GPU / 機械学習'), findsOneWidget);
    expect(find.textContaining('gpu_ml — 埋め込み計算を GPU で実行するため'), findsOneWidget);
    expect(find.text('互換性'), findsOneWidget);

    // インストール → 確認シート(権限が根拠、グループ見出しつき)→ 確定。
    await reveal(tester, find.text('インストール'), up: true);
    await tester.tap(find.text('インストール'));
    await tester.pumpAndSettle();
    expect(find.text('このプラグインが使う権限'), findsOneWidget);
    expect(find.text('SigLIP レコメンダー 1.2.1 をインストール'), findsOneWidget);
    await tester.tap(find.text('インストールする'));
    await tester.pumpAndSettle();

    // SHA-512 検証を通ってインストール済みに(KV 永続)。
    await reveal(tester, find.textContaining('インストール済み v1.2.1'), up: true);
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
  Future<Uint8List> downloadArtifact(String pluginId, String artifactId, {String? version}) async => Uint8List.fromList(utf8.encode('tampered!'));
}
