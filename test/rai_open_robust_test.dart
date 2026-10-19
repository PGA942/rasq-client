import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/rai/rai_diagnostics.dart';
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_home_screen.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_mascot_3d.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_widgets.dart';
import 'package:rasq_client/features/settings/developer_mode.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:three_js/three_js.dart' as three;

import 'support/fake_rai_embedding_model.dart';
import 'support/fake_rai_llm.dart';
import 'support/fakes.dart';

/// 準備の確かめで投げる LLM (D-516): Android の端末内モデル(ネイティブのライブラリ / モデルの確かめ)の失敗の代わり。
class _ThrowingRaiLlm extends FakeRaiLlm {
  @override
  Future<void> refresh() async => throw StateError('libllama.so not found (fake)');
}

class _ThrowingRaiEmbeddingModel extends FakeRaiEmbeddingModel {
  @override
  Future<void> refresh() async => throw StateError('onnxruntime init failed (fake)');
}

/// 準備が終わらない three_js の土台 (D-516): GL の初期化が失敗 / 止まった Android の代わり(onSetupComplete を呼ばない)。
/// 読み込み中の表示は three_js と同じく [loadingWidget](無ければ画面いっぱいの面 + くるくる)。
class _StuckThree extends three.ThreeJS {
  _StuckThree(Widget? loading) : super(onSetupComplete: () {}, setup: null, loadingWidget: loading);
  @override
  Widget build() => KeyedSubtree(key: const ValueKey('test.stuckThree'), child: loadingWidget ?? const ColoredBox(color: Colors.white, child: Center(child: CircularProgressIndicator())));
  @override
  void dispose() {}
}

/// RAi が開かない(Android、D-516)の再発防止: 3D のマスコット / 端末内モデルの準備が失敗しても RAi ホームとバーは出る。
void main() {
  group('3D を使うか (raiMascot3dAllowed)', () {
    test('テストでは使わない', () {
      expect(raiMascot3dAllowed(test: true, android: false, androidOptIn: true), isFalse);
    });
    test('Android は既定で 2D、開発者モードで試すときだけ 3D', () {
      expect(raiMascot3dAllowed(test: false, android: true, androidOptIn: false), isFalse);
      expect(raiMascot3dAllowed(test: false, android: true, androidOptIn: true), isTrue);
    });
    test('iOS / iPadOS / macOS など(Android 以外の端末)は 3D', () {
      expect(raiMascot3dAllowed(test: false, android: false, androidOptIn: false), isTrue);
    });
  });

  test('3D が失敗したら 2D に切り替わり、理由が診断に残る。試し直しで戻る', () {
    final c = ProviderContainer(overrides: [raiMascot3dSupportedProvider.overrideWithValue(true)]);
    addTearDown(c.dispose);
    expect(c.read(raiMascot3dProvider), isTrue);
    c.read(raiMascot3dFallbackProvider.notifier).fail('GL init failed');
    expect(c.read(raiMascot3dProvider), isFalse);
    expect(c.read(raiDiagnosticsProvider).single.area, '3d');
    // 2 回目の失敗は上書きしない(最初の理由を残す)。
    c.read(raiMascot3dFallbackProvider.notifier).fail('again');
    expect(c.read(raiMascot3dFallbackProvider), 'GL init failed');
    c.read(raiMascot3dFallbackProvider.notifier).reset();
    expect(c.read(raiMascot3dProvider), isTrue);
  });

  test('診断は新しい 30 件だけ残す', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    for (var i = 0; i < 40; i++) {
      c.read(raiDiagnosticsProvider.notifier).add('llm', 'e$i');
    }
    final log = c.read(raiDiagnosticsProvider);
    expect(log, hasLength(RaiDiagnostics.max));
    expect(log.first.message, 'e10');
    expect(log.last.message, 'e39');
  });

  Future<ProviderContainer> pump(WidgetTester tester, {RaiLlm? llm, RaiEmbeddingModel? embedding, List<Override> extra = const [], String location = Routes.rai}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    rootBundle.clear();
    final session = fakeSession();
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [session.toJson()], 'current': session.account.key}),
    });
    final acc = session.account;
    final registry = PluginRegistry()
      ..register(FakeSnsPlugin(
        posts: (_) => [Post(id: 'p1', account: acc, author: UserSummary(id: 'u1', account: acc, displayName: 'テスター'), createdAt: DateTime(2026, 10, 20), body: 'こんにちは')],
      ));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        raiLlmProvider.overrideWithValue(llm ?? FakeRaiLlm(phase: RaiLlmPhase.ready)),
        raiEmbeddingModelProvider.overrideWithValue(embedding ?? FakeRaiEmbeddingModel()),
        deviceRamReaderProvider.overrideWithValue(() async => (totalMb: 8192, availableMb: 4096)),
        ...extra,
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).go(location);
    await tester.pumpAndSettle();
    return c;
  }

  void expectRaiOpen() {
    expect(find.byType(RaiHomeScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('rai.chat.empty')), findsOneWidget);
  }

  testWidgets('端末内 LLM / 埋め込みモデルの確かめが投げても RAi は開き、失敗は診断に残る', (tester) async {
    final c = await pump(tester, llm: _ThrowingRaiLlm(), embedding: _ThrowingRaiEmbeddingModel(), extra: [developerModeProvider.overrideWithValue(true)]);
    expectRaiOpen();
    expect(tester.takeException(), isNull);
    // バーとサイドバーの診断が状態を読む(確かめが走る)。
    c.read(raiProvider.notifier).toggleSidebar(open: true);
    await tester.pumpAndSettle();
    final areas = c.read(raiDiagnosticsProvider).map((d) => d.area).toSet();
    expect(areas, contains('llm'));
    expect(areas, contains('embedding'));
  });

  testWidgets('3D の土台を作るときに投げたら、2D の RAi に切り替えて開く', (tester) async {
    final c = await pump(tester, extra: [
      raiMascot3dSupportedProvider.overrideWithValue(true),
      raiThreeFactoryProvider.overrideWithValue(({required onSetupComplete, required setup, loadingWidget, size, settings}) => throw StateError('initOpenGLAngle: eglInitialize failed (fake)')),
    ]);
    expectRaiOpen();
    expect(tester.takeException(), isNull);
    expect(c.read(raiMascot3dFallbackProvider), contains('eglInitialize failed'));
    expect(c.read(raiMascot3dProvider), isFalse);
    // 3D の層は外れ、背景の RAi は 2D で出る。
    expect(find.byType(RaiMascot3d), findsNothing);
    expect(find.descendant(of: find.byType(RaiMascotLayer), matching: find.byType(RaiMascot)), findsOneWidget);
    expect(c.read(raiDiagnosticsProvider).map((d) => d.area), contains('3d'));
  });

  testWidgets('3D の準備が終わらない(GL の初期化が止まる)ときは、待ち時間を過ぎたら 2D に切り替える。待つ間も画面を覆わない', (tester) async {
    final c = await pump(tester, location: Routes.raiAsk, extra: [
      raiMascot3dSupportedProvider.overrideWithValue(true),
      raiThreeFactoryProvider.overrideWithValue(({required onSetupComplete, required setup, loadingWidget, size, settings}) => _StuckThree(loadingWidget)),
    ]);
    // 待っている間: RAi ホームとバーは出ている。3D の層は何も描かない(読み込み中の面で覆わない)。
    expectRaiOpen();
    expect(find.byType(RaiMascot3d), findsOneWidget);
    expect(find.byKey(const ValueKey('test.stuckThree')), findsOneWidget);
    expect(find.descendant(of: find.byType(RaiMascot3d), matching: find.byType(CircularProgressIndicator)), findsNothing);
    expect(c.read(raiMascot3dFallbackProvider), isNull);
    await tester.pump(raiMascot3dTimeout + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(c.read(raiMascot3dFallbackProvider), contains('not ready'));
    expect(find.byType(RaiMascot3d), findsNothing);
    expect(find.descendant(of: find.byType(RaiMascotLayer), matching: find.byType(RaiMascot)), findsOneWidget);
    expectRaiOpen();
    expect(tester.takeException(), isNull);
  });

  testWidgets('開発者モードのサイドバーに診断が出る', (tester) async {
    final c = await pump(tester, extra: [developerModeProvider.overrideWithValue(true)]);
    c.read(raiMascot3dFallbackProvider.notifier).fail('GL init failed');
    c.read(raiProvider.notifier).toggleSidebar(open: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rai.sidebar.diagnostics')), findsOneWidget);
    expect(find.textContaining('失敗したので 2D に切り替えました'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rai.sidebar.diagnostics.retry3d')));
    await tester.pumpAndSettle();
    expect(c.read(raiMascot3dFallbackProvider), isNull);
  });
}
