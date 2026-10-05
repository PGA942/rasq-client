import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/trend/trend_screen.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_providers.dart' show astellHomeProvider;
import 'package:rasq_client/features/vc/astell_tile.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// トレンドの「フォロー中の反応」(D-364) の AsTell タイル (D-376): 縦のリストに直に置いて高さが決まらず、下へスクロールして
/// 戻ると `RenderFlex children have non-zero flex but incoming height constraints are unbounded` → 戻るが効かなくなっていた。
void main() {
  testWidgets('フォロー中の反応の AsTell タイルは高さの決まった帯。下へスクロール → 戻っても壊れず、戻るも効く', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    AstellRoom room(String id, int peers) => AstellRoom.fromJson({
          'id': id, 'ownerId': 'o$id', 'ownerHandle': 'douglas', 'ownerDisplayName': 'ダグラス', 'title': '打上会の反省会 $id', 'genres': ['#打上会'],
          'createdAt': '2026-09-29T10:00:00Z', 'peerCount': peers,
          'peerFaces': [for (var i = 0; i < peers; i++) {'accountId': 'p$id$i', 'handle': 'p$i', 'displayName': '参加者$i'}],
        });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        // フォロー中の反応のセクションの AsTell のタイル (D-442): いま開いているルームから、このページのワードに当たるもの。
        astellHomeProvider.overrideWith((ref) async => AstellHome(trending: [room('r1', 2), room('r2', 3)])),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    c.read(routerProvider).push('/trend/${Uri.encodeComponent('打上会')}');
    await tester.pumpAndSettle();
    expect(find.byType(TrendScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('tl.node.astell')), findsOneWidget);
    expect(find.byType(AstellTile), findsWidgets);
    expect(tester.takeException(), isNull);

    // 下へ → 少し戻る(タイルが作り直される)。
    final list = find.descendant(of: find.byType(TrendScreen), matching: find.byType(Scrollable)).last;
    for (var i = 0; i < 4; i++) {
      await tester.drag(list, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 4; i++) {
      await tester.drag(list, const Offset(0, 300));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
    expect(find.byType(AstellTile), findsWidgets);

    // 戻る。
    await tester.tap(find.byTooltip('トレンドホームへ戻る'));
    await tester.pumpAndSettle();
    expect(find.byType(TrendScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
