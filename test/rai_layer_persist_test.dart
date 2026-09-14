import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/rai/rai_overlay.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// RAi の層は FOW / ドロップダウンが出入りしても作り直されない (D-205 のキー付け。実機で three_js が
/// 手順ごとに作り直されていた)。State が同じインスタンスのまま残ることで確かめる。
void main() {
  testWidgets('FOW とドロップダウンの出入りで RaiMascotLayer の State は変わらない', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
    });
    final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
    await tester.pumpWidget(ProviderScope(overrides: [sessionStorageProvider.overrideWithValue(storage), pluginRegistryProvider.overrideWithValue(registry)], child: const RasqApp()));
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final manager = c.read(overlayManagerProvider);
    // RAi を出す(バー + マスコット層)。
    c.read(raiProvider.notifier).open(mode: RaiMode.instruction);
    manager.show(RasqOverlayEntry(id: raiBarOverlayId, layer: OverlayLayer.rai, alignment: Alignment.bottomCenter, builder: (_, _) => const SizedBox.shrink()));
    manager.show(RasqOverlayEntry(id: raiMascotOverlayId, layer: OverlayLayer.rai, alignment: Alignment.topLeft, builder: (_, _) => const RaiMascotLayer()));
    await tester.pumpAndSettle();
    final before = tester.state(find.byType(RaiMascotLayer));
    // FOW を出して閉じる、ドロップダウンを出して閉じる。
    manager.showFow<void>(id: 'x.fow', spec: FowSpec(title: 'x'), builder: (_, _) => const Text('fow'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(RaiMascotLayer)), same(before));
    manager.close('x.fow');
    await tester.pumpAndSettle();
    manager.showDropdown<String>(id: 'x.dd', anchor: const Rect.fromLTWH(10, 10, 40, 40), items: const [RasqDropdownItem('a', 'a')]);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(RaiMascotLayer)), same(before));
    manager.close('x.dd');
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(RaiMascotLayer)), same(before));
    // 画面遷移(push / pop / go)でも残る。
    final router = c.read(routerProvider);
    router.push(Routes.settings);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(RaiMascotLayer)), same(before));
    router.pop();
    await tester.pumpAndSettle();
    router.go(Routes.notifications);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(RaiMascotLayer)), same(before));
    // ボトムシートの出入りでも残る。
    manager.showBottomSheet<void>(id: 'x.sheet', title: 'x', builder: (_) => const Text('sheet'));
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(RaiMascotLayer)), same(before));
    manager.close('x.sheet');
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(RaiMascotLayer)), same(before));
  });
}
