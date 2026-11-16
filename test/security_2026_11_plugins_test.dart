import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_core/rrl_core.dart';

import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// セキュリティ確認 2026-11-11(rasq-client)の #5 / #4。
class _GateBox extends Notifier<ChildGate> {
  @override
  ChildGate build() => ChildGate.off;
  void set(ChildGate g) => state = g;
}

final _gateBox = NotifierProvider<_GateBox, ChildGate>(_GateBox.new);

ChildGate kid(ChildSafePluginsAllow plugins) => ChildGate(
      state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy(allow: ChildSafeAllow(plugins: plugins))),
      now: DateTime(2026, 11, 11, 12),
    );

void main() {
  Map<String, Object?> manifest(String id, List<String> slots) => {'id': id, 'name': 'テスト $id', 'version': '0.1.0', 'kind': 'action', 'slots': slots, 'permissions': ['fow.widget']};

  late Map<String, FakeSlotRuntime Function()> fakes;
  setUp(() => fakes = {});

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({
          SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
        })),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []))),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(fakes)),
        childGateProvider.overrideWith((ref) => ref.watch(_gateBox)),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
  }

  Future<SlotPlugin> register(ProviderContainer c, String name) async {
    final p = await c.read(slotPluginsProvider.notifier).register('store:t.$name', bytes: Uint8List.fromList(name.codeUnits));
    expect(p, isNotNull, reason: c.read(slotPluginsNoticeProvider));
    return p!;
  }

  group('#5 AsTell プラグインのトークン', () {
    for (final (label, banned) in [
      ('プラグインの id を外す', const ChildSafePluginsAllow(ids: [], install: ChildSafeInstall.none)),
      ('astell.action のスロットを止める', const ChildSafePluginsAllow(ids: ['t.astell'], slots: {'astell.action': false})),
    ]) {
      testWidgets('開いたあとに$label と、以後の共有は届かない。許し直しても、開き直すまでは届かない', (tester) async {
        late FakeSlotRuntime rt;
        fakes['astell'] = () => rt = FakeSlotRuntime(manifest: manifest('t.astell', ['astell.action']), handler: (self, fn, args) => {});
        final c = await pump(tester);
        c.read(_gateBox.notifier).set(kid(const ChildSafePluginsAllow(ids: ['t.astell'])));
        final plugin = await register(c, 'astell');
        final session = c.read(astellSessionProvider.notifier);
        await session.join((await c.read(astellClientProvider).room('r-launch'))!);
        await tester.pumpAndSettle();
        await c.read(slotPluginsProvider.notifier).astellOpen(plugin, c.read(astellSessionProvider)!);
        int shares() => rt.calls.where((x) => x.$1 == 'astell.event' && x.$2['type'] == 'share').length;

        session.share('text', {'text': 'ひとつめ'});
        await tester.pumpAndSettle();
        expect(shares(), 1);

        c.read(_gateBox.notifier).set(kid(banned));
        await tester.pumpAndSettle();
        session.share('text', {'text': 'ふたつめ'});
        await tester.pumpAndSettle();
        expect(shares(), 1, reason: '止めたプラグインへは送らない');

        c.read(_gateBox.notifier).set(kid(const ChildSafePluginsAllow(ids: ['t.astell'])));
        await tester.pumpAndSettle();
        session.share('text', {'text': 'みっつめ'});
        await tester.pumpAndSettle();
        expect(shares(), 1, reason: '古いトークンは戻さない');

        await c.read(slotPluginsProvider.notifier).astellOpen(plugin, c.read(astellSessionProvider)!);
        session.share('text', {'text': 'よっつめ'});
        await tester.pumpAndSettle();
        expect(shares(), 2, reason: '開き直せば届く');
        await session.leave();
        await tester.pumpAndSettle();
      });
    }
  });

  group('#4 ビューワーの重ね', () {
    testWidgets('A がほかのプラグインのトークンで重ねを送っても B の重ねにならない。同じトークンでも自分の分だけ', (tester) async {
      late FakeSlotRuntime a;
      late FakeSlotRuntime b;
      fakes['a'] = () => a = FakeSlotRuntime(manifest: manifest('t.a', ['viewer.overlay']), handler: (self, fn, args) => {});
      fakes['b'] = () => b = FakeSlotRuntime(manifest: manifest('t.b', ['viewer.overlay']), handler: (self, fn, args) => {});
      final c = await pump(tester);
      final pa = await register(c, 'a');
      final pb = await register(c, 'b');
      final n = c.read(slotPluginsProvider.notifier);
      final gotA = <String>[];
      final gotB = <String>[];
      Future<void> open(SlotPlugin p, String token, List<String> into) => n.viewerOpen(p, token: token, url: 'https://example.test/a.png', mimeType: 'image/png', width: 10, height: 10, onOverlay: (root) => into.add(root.k ?? ''));
      await open(pa, 'shared', gotA);
      await open(pb, 'shared', gotB);
      await open(pb, 'only-b', gotB);
      Map<String, Object?> root(String k) => {'t': 'Column', 'k': k};

      a.hostFn('viewer.overlay.set', {'token': 'shared', 'root': root('from-a')});
      a.hostFn('viewer.overlay.set', {'token': 'only-b', 'root': root('from-a-to-b')});
      b.hostFn('viewer.overlay.set', {'token': 'only-b', 'root': root('from-b')});
      await tester.pumpAndSettle();
      expect(gotA, ['from-a']);
      expect(gotB, ['from-b']);

      n.viewerClose(pb, 'shared');
      b.hostFn('viewer.overlay.set', {'token': 'shared', 'root': root('late-b')});
      a.hostFn('viewer.overlay.set', {'token': 'shared', 'root': root('still-a')});
      await tester.pumpAndSettle();
      expect(gotB, ['from-b'], reason: '閉じたトークンの更新は受けない');
      expect(gotA, ['from-a', 'still-a'], reason: 'B を閉じても A のトークンは残る');
    });
  });

  test('RrlNode の key を読める(テストの前提)', () {
    expect(RrlNode.fromJson({'t': 'Column', 'k': 'x'}).k, 'x');
  });
}
