import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/store/release_fow.dart';
import 'package:rasq_client/features/store/review_timeline_screen.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/features/store/store_widgets.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// D-137: ストアページ「全体像」— レビュー TL(↪️/👍/👎)と上位 10 件の
/// フレーム、リリースノート FOW からの版指定インストール、権限タイプの
/// グループ分け。
void main() {
  const acc = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
  Post post(String id, String body) => Post(id: id, account: acc, author: const UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 8, 31), body: body);

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (v) => [post('p1', 'ふつうの投稿')]));
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<void> openSamplePage(WidgetTester tester, ProviderContainer container) async {
    RasqSidebar.open(container.read(overlayManagerProvider));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(RasqSidebar), matching: find.text('プラグイン')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Misskey コネクタ').first);
    await tester.pumpAndSettle();
  }

  /// プラグインページ本体の Scrollable(PageView の Scrollable より木の順で先)。
  Finder page() => find.descendant(of: find.byType(ListView).first, matching: find.byType(Scrollable)).first;

  /// 遅延 ListView の要素を**画面内**まで出す(scrollUntilVisible はキャッシュ
  /// 範囲で止まるので ensureVisible まで行う)。
  Future<void> reveal(WidgetTester tester, Finder f, {bool up = false}) async {
    await tester.scrollUntilVisible(f, up ? -200 : 200, scrollable: page());
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
  }

  group('モデル', () {
    test('権限タイプのグループ分け: 領域語で分類し、未知は「その他」に落とす', () {
      final groups = PermissionKind.group(const [
        PermissionEntry('net.fetch', 'API'),
        PermissionEntry('storage.safe', '保存'),
        PermissionEntry('gpu_ml', 'GPU'),
        PermissionEntry('fs.read', '辞書'),
        PermissionEntry('net.stream', '常時接続'),
        PermissionEntry('mystery', '?'),
      ]);
      expect([for (final g in groups) g.kind], [PermissionKind.network, PermissionKind.storage, PermissionKind.files, PermissionKind.gpuMl, PermissionKind.other]);
      expect(groups.first.entries.map((e) => e.permission), ['net.fetch', 'net.stream']);
    });

    test('関連性の並び = 参考になった数(差分)→ 実利用済み → 新しさ', () {
      final a = StoreReview(id: 'a', rating: 3, helpfulCount: 5, notHelpfulCount: 4, verifiedUse: false, createdAt: DateTime(2026, 1, 1));
      final b = StoreReview(id: 'b', rating: 3, helpfulCount: 1, verifiedUse: true, createdAt: DateTime(2026, 1, 1));
      final c = StoreReview(id: 'c', rating: 3, helpfulCount: 1, verifiedUse: true, createdAt: DateTime(2026, 2, 1));
      expect(StoreReview.sorted([a, b, c], ReviewSort.helpful).map((r) => r.id), ['c', 'b', 'a']);
      expect(StoreReview.sorted([a, b, c], ReviewSort.recent).first.id, 'c');
      expect(StoreReview.histogram([a, b, c]), [0, 0, 3, 0, 0]);
    });

    test('ストアページのレビューフレーム = ダミー TL の関連性上位 10 件', () async {
      final container = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({})),
        storeClientProvider.overrideWithValue(MockStoreClient()),
      ]);
      addTearDown(container.dispose);
      final all = await container.read(storeReviewsProvider(storeSamplePluginId).future);
      final top = await container.read(storeTopReviewsProvider(storeSamplePluginId).future);
      expect(all.length, greaterThan(storeTopReviewCount));
      expect(top.length, storeTopReviewCount);
      expect(top.first.id, 'r1'); // 👍12 が先頭
      expect(top.map((r) => r.id), isNot(contains('r10'))); // 👍0/👎4 は圏外
    });

    test('版指定の manifest: リリースノートに載る版だけ受け、その版の権限増分を返す', () async {
      final client = MockStoreClient();
      final m = await client.manifest(storeSamplePluginId, version: '0.6.0-pre.1');
      expect(m!.version, '0.6.0-pre.1');
      expect(m.channel, 'beta');
      expect(m.permissionsAdded.map((p) => p.permission), ['net.stream']);
      expect(await client.manifest(storeSamplePluginId, version: '9.9.9'), isNull);
    });
  });

  testWidgets('全体像: 先月の DL / 評価 / レビュー› / アップデートとバージョン› / プライバシーと必要な権限›(権限タイプごと)', (tester) async {
    final container = await pump(tester);
    await openSamplePage(tester, container);

    await reveal(tester, find.text('先月のダウンロード数'));
    expect(find.text('先月のダウンロード数'), findsOneWidget);
    expect(find.text('1900'), findsOneWidget);
    expect(find.byType(DownloadsSparkline), findsOneWidget);
    await reveal(tester, find.text('評価'));
    expect(find.text('評価'), findsOneWidget);
    expect(find.byType(RatingHistogram), findsOneWidget);

    await reveal(tester, find.text('レビュー'));
    expect(find.text('12件'), findsOneWidget);
    expect(find.byType(StoreReviewFrame), findsWidgets);
    expect(find.text('wasm でここまで動く'), findsOneWidget); // 関連性 1 位が先頭フレーム

    await reveal(tester, find.text('プライバシーと必要な権限'));
    expect(find.text('ネットワーク'), findsOneWidget);
    expect(find.text('ストレージ'), findsOneWidget);
    // › で全文シート: 権限グループ + 外部通信とデータ + 実行環境(3 枚目以降の
    // フレームは PageView が遅延構築するのでシート側で確認する)。
    await tester.tap(find.text('プライバシーと必要な権限'));
    await tester.pumpAndSettle();
    expect(find.text('外部通信とデータ'), findsOneWidget);
    expect(find.text('実行環境'), findsOneWidget);
    expect(find.textContaining('ネットワーク — 外部への通信'), findsOneWidget);
  });

  testWidgets('レビュー› → レビュー TL: 関連性/最新タブ、👍 で人数が増え KV に残る、もう一度で取り消し', (tester) async {
    final container = await pump(tester);
    await openSamplePage(tester, container);

    await reveal(tester, find.text('レビュー'));
    await tester.tap(find.text('レビュー'));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewTimelineScreen), findsOneWidget);
    expect(find.text('関連性'), findsOneWidget);
    expect(find.text('最新'), findsOneWidget);
    expect(find.byType(StoreReviewTile), findsWidgets);
    // 先頭タイル = 関連性 1 位(👍12)。↪️ / 👍 / 👎 のアクションバー。
    expect(find.text('wasm でここまで動く'), findsOneWidget);
    expect(find.text('タロ・ヤマダ'), findsOneWidget);
    expect(find.text('12人が役に立ったと考えました。'), findsOneWidget);
    expect(find.byIcon(Icons.shortcut), findsWidgets);

    final firstTile = find.byType(StoreReviewTile).first;
    await tester.tap(find.descendant(of: firstTile, matching: find.byIcon(Icons.thumb_up_outlined)));
    await tester.pumpAndSettle();
    expect(find.text('13人が役に立ったと考えました。'), findsOneWidget);
    expect(container.read(reviewVotesProvider)['$storeSamplePluginId/r1'], ReviewVote.up);

    // 👎 に切り替えると 👍 は外れる。
    await tester.tap(find.descendant(of: firstTile, matching: find.byIcon(Icons.thumb_down_outlined)));
    await tester.pumpAndSettle();
    expect(find.text('12人が役に立ったと考えました。'), findsOneWidget);
    expect(container.read(reviewVotesProvider)['$storeSamplePluginId/r1'], ReviewVote.down);

    // 最新タブ: 一番新しい 0.6 系のレビュー(9/4 以前で最新 = 9/3)が先頭。
    await tester.tap(find.text('最新'));
    await tester.pumpAndSettle();
    expect(find.text('リノートの展開が惜しい'), findsOneWidget);
  });

  testWidgets('アップデートとバージョン: フレームをタップ → FOW(リリースノート + 増えた権限 + Ver.〇〇をインストール)→ 版指定インストール', (tester) async {
    final container = await pump(tester);
    await openSamplePage(tester, container);

    await reveal(tester, find.text('アップデートとバージョン'));
    // 先頭フレーム = 最新のプレビュー版(net.stream が増えている)。
    await tester.tap(find.text('Misskey コネクタ 0.6.0-pre.1 Pre'));
    await tester.pumpAndSettle();

    expect(find.byType(ReleaseNoteBody), findsOneWidget);
    expect(find.text('この版で増えた権限'), findsOneWidget);
    expect(find.textContaining('ネットワーク: net.stream'), findsOneWidget);
    await tester.tap(find.text('Ver.0.6.0-pre.1 をインストール'));
    await tester.pumpAndSettle();

    // 確認シート(版名つき)→ 確定 → その版で登録される。
    expect(find.text('Misskey コネクタ 0.6.0-pre.1 をインストール'), findsOneWidget);
    expect(find.text('前のバージョンから増えた権限'), findsOneWidget);
    await tester.tap(find.text('インストールする'));
    await tester.pumpAndSettle();
    final installed = container.read(installedPluginsProvider).where((p) => p.id == storeSamplePluginId).single;
    expect(installed.version, '0.6.0-pre.1');
    await reveal(tester, find.textContaining('インストール済み v0.6.0-pre.1'), up: true);
    expect(find.textContaining('インストール済み v0.6.0-pre.1'), findsOneWidget);

    // 同じ版の FOW を開くとボタンは「インストール済み」で無効。
    await reveal(tester, find.text('アップデートとバージョン'));
    await tester.tap(find.text('Misskey コネクタ 0.6.0-pre.1 Pre'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(find.ancestor(of: find.text('Ver.0.6.0-pre.1 はインストール済み'), matching: find.byType(FilledButton)));
    expect(button.onPressed, isNull);
  });
}
