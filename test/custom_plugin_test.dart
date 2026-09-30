import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/custom/custom_astell.dart';
import 'package:rasq_client/features/custom/custom_client.dart';
import 'package:rasq_client/features/custom/custom_models.dart';
import 'package:rasq_client/features/custom/custom_page.dart';
import 'package:rasq_client/features/custom/custom_profile.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/store/store_client.dart';
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/store/store_providers.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_core/rrl_core.dart';

import 'support/fake_store_client.dart';
import 'support/fake_slot_runtime.dart';
import 'support/fakes.dart';

/// カスタムプラグイン(ページ型、契約 v0.18 §2.13、D-357 / S-048)。

const _boardId = 'sample.board';

Map<String, Object?> _manifest({String mode = 'shared', List<String> permissions = const ['render', 'shared.session']}) => {
      'id': _boardId,
      'name': 'みんなのボード',
      'version': '1.0.0',
      'kind': 'view',
      'slots': ['page'],
      'permissions': permissions,
      'page': {'title': 'ボード', 'icon': 'dashboard', 'mode': mode, 'surfaces': ['page', 'astell', 'profile']},
    };

/// 偽のページ型: カウンター(`count`)を表示。ボタン = `shared.op incr`、「🎉」= `shared.call`。値が変わるたびに `page.render`。
FakeSlotRuntime _board({String mode = 'shared', List<(String, Map<String, Object?>)>? events}) {
  var count = 0;
  Map<String, Object?> root(int n) => {
        't': 'Column',
        'k': 'root',
        'c': [
          {'t': 'Text', 'k': 'count', 'p': {'text': 'カウント $n'}},
          {'t': 'Button', 'k': 'inc', 'p': {'label': '+1'}, 'on': {'tap': 'inc'}},
        ],
      };
  return FakeSlotRuntime(
    manifest: _manifest(mode: mode),
    handler: (rt, fn, args) {
      switch (fn) {
        case 'page.open':
          final vars = ((args['session'] as Map?)?['vars'] as Map?) ?? const {};
          count = ((vars['count'] as Map?)?['value'] as num?)?.toInt() ?? 0;
          return {'root': root(count), 'title': 'ボード'};
        case 'inc':
          rt.hostFn('shared.op', {'token': args['token'], 'key': 'count', 'op': 'incr', 'value': 1});
          return {};
        case 'page.event':
          events?.add(('${args['type']}', args));
          if (args['type'] == 'var' && args['key'] == 'count') {
            count = (args['value'] as num).toInt();
            rt.hostFn('page.render', {'token': args['token'], 'root': root(count)});
          }
          return {};
        case 'page.close':
          return {};
      }
      return null;
    },
  );
}

class _Store extends FakeStoreClient {
  @override
  Future<StorePluginDetail?> plugin(String id) async => id == _boardId
      ? const StorePluginDetail(id: _boardId, name: 'みんなのボード', version: '1.0.0', pluginType: StorePluginType.custom, safety: SafetyBlock(permissions: [PermissionEntry('shared.session', 'みんなの値')]))
      : super.plugin(id);
  final sessionDownloads = <String>[];
  @override
  Future<Uint8List> sessionPackage(String pluginId, String sessionId, {String? version}) async {
    sessionDownloads.add('$pluginId/$sessionId');
    return Uint8List.fromList(utf8.encode('board'));
  }
}

String _text(RrlNode n) => [if (n.p['text'] != null) '${n.p['text']}', for (final c in n.c) _text(c)].join('|');

Future<void> _settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('宣言 / 許すホスト関数 / キーと op の規則(Central と同じ)', () {
    final m = SlotManifest.fromJson(_manifest());
    expect(m.page!.isShared, isTrue);
    expect(m.page!.allows('astell'), isTrue);
    expect(m.appFns, containsAll([RasqHostFns.pageRender, RasqHostFns.sharedSet, RasqHostFns.sharedOp, RasqHostFns.sharedCall]));
    // 権限が無ければ shared.* は開けない。solo は astell に出せない。
    expect(SlotManifest.fromJson(_manifest(permissions: ['render'])).appFns.contains(RasqHostFns.sharedSet), isFalse);
    final solo = SlotManifest.fromJson(_manifest(mode: 'solo'));
    expect((solo.page!.allows('astell'), solo.page!.allows('profile'), solo.appFns.contains(RasqHostFns.sharedOp)), (false, true, false));
    // page スロットが無ければ宣言も無い。
    expect(SlotManifest.fromJson({'id': 'x', 'slots': ['tl'], 'page': {'mode': 'shared'}}).page, isNull);

    expect(resolveCustomKey('me.vote', 'a1'), '@a1.vote');
    expect(resolveCustomKey('@a1.vote', 'a1'), '@a1.vote');
    expect(resolveCustomKey('@a2.vote', 'a1'), isNull);
    expect(resolveCustomKey('bad key', 'a1'), isNull);
    expect(applyCustomOp(null, 'incr', 2), 2);
    expect(applyCustomOp(1.5, 'incr', 1), 2.5);
    expect(applyCustomOp([1], 'append', 2), [1, 2]);
    expect((applyCustomOp([for (var i = 0; i < 500; i++) i], 'append', 500)! as List).first, 1); // 500 まで
    expect(applyCustomOp([1, 2, 1], 'remove', 1), [2, 1]);
    expect(applyCustomOp({'a': 1}, 'merge', {'b': 2}), {'a': 1, 'b': 2});
    expect(() => applyCustomOp('x', 'incr', 1), throwsFormatException);
  });

  test('モックのサーバー: ifRev の不一致 / 他人のキー / 呼び出しは全員へ', () async {
    final client = MockCustomSessionClient();
    final s = await client.create(pluginId: _boardId, scope: 'link');
    expect(s.inviteCode, isNotNull);
    expect((await client.invite(s.inviteCode!))!.id, s.id);
    final conn = await client.connect(s.id);
    final got = <Map<String, Object?>>[];
    conn.messages.listen(got.add);
    await _settle();
    expect(got.first['type'], 'welcome');
    conn.send({'type': 'set', 'key': 'me.vote', 'value': 'a'});
    conn.send({'type': 'set', 'key': 'title', 'value': 'x', 'ifRev': 5});
    conn.send({'type': 'set', 'key': '@other.vote', 'value': 'b'});
    client.actAs(s.id, const CustomParticipant(accountId: 'u2', handle: 'u2'), {'type': 'call', 'fn': 'celebrate', 'args': {'n': 1}});
    await _settle();
    expect([for (final m in got.skip(1)) m['type']], ['var', 'conflict', 'error', 'call']);
    expect(got[1]['key'], '@me.vote');
    expect((got[4]['from'] as Map)['accountId'], 'u2');
  });

  ProviderContainer container({StoreClient? store, MockCustomSessionClient? custom, required Map<String, FakeSlotRuntime Function()> plugins}) {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})})),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(store ?? _Store()),
      customSessionClientProvider.overrideWithValue(custom ?? MockCustomSessionClient()),
      slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(plugins)),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('共有セッション: 入る → page.open に値 → ボタンで incr → 全員の値が変わり描き直す / 他の人の書き込み・参加・閉じる', () async {
    final custom = MockCustomSessionClient();
    final events = <(String, Map<String, Object?>)>[];
    late FakeSlotRuntime rt;
    final c = container(custom: custom, plugins: {'store:$_boardId@1.0.0': () => rt = _board(events: events)});
    await c.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false);
    final s = await custom.create(pluginId: _boardId, version: '1.0.0', scope: 'room:r1');
    custom.vars[s.id]!['count'] = const CustomVar(value: 4, rev: 4, by: 'u2');

    final page = CustomPageController(c, CustomPageArgs(pluginId: _boardId, surface: 'astell', sessionId: s.id, roomId: 'r1'));
    addTearDown(page.dispose);
    await page.start();
    await _settle();
    expect(page.phase, CustomPagePhase.ready);
    expect(page.temporary, isFalse);
    expect(_text(page.root!), contains('カウント 4'));
    final open = rt.calls.firstWhere((x) => x.$1 == 'page.open').$2;
    expect((open['surface'], (open['context'] as Map)['roomId'], (open['session'] as Map)['role']), ('astell', 'r1', 'owner'));

    page.onRrlEvent('inc', 'tap', fn: 'inc');
    await _settle();
    expect(_text(page.root!), contains('カウント 5'));
    expect(custom.vars[s.id]!['count']!.value, 5);

    // ほかの参加者が足す / 入る / 呼ぶ。
    const u2 = CustomParticipant(accountId: 'u2', handle: 'hanako', displayName: 'ハナコ');
    custom.join(s.id, u2);
    custom.actAs(s.id, u2, {'type': 'op', 'key': 'count', 'op': 'incr', 'value': 10});
    custom.actAs(s.id, u2, {'type': 'call', 'fn': 'celebrate', 'args': {}});
    await _settle();
    expect(_text(page.root!), contains('カウント 15'));
    expect(page.participants.map((p) => p.handle), contains('hanako'));
    expect([for (final e in events) e.$1], containsAllInOrder(['var', 'joined', 'var', 'call']));
    expect((events.last.$2['from'] as Map)['handle'], 'hanako');

    await custom.close(s.id);
    await _settle();
    expect(page.closedReason, 'closed');
    expect(page.hasSession, isFalse);
    expect(events.last.$1, 'closed');
  });

  test('インストールしていない参加者: 同意 → セッション経由で取り、一時的に動かす(登録簿には入れない)→ 閉じたら捨てる', () async {
    final custom = MockCustomSessionClient();
    final store = _Store();
    late FakeSlotRuntime rt;
    final c = container(store: store, custom: custom, plugins: {'store:$_boardId@1.0.0': () => rt = _board()});
    final s = await custom.create(pluginId: _boardId, version: '1.0.0', scope: 'room:r1');
    final page = CustomPageController(c, CustomPageArgs(pluginId: _boardId, version: '1.0.0', surface: 'astell', sessionId: s.id, roomId: 'r1'));
    await page.start();
    expect(page.phase, CustomPagePhase.needsConsent);
    expect(page.detail!.safety.permissions.single.permission, 'shared.session');
    await page.acceptTemporary();
    await _settle();
    expect(page.phase, CustomPagePhase.ready);
    expect(page.temporary, isTrue);
    expect(store.sessionDownloads, ['$_boardId/${s.id}']);
    expect(c.read(slotPluginsProvider), isEmpty);
    page.dispose();
    expect(rt.disposed, isTrue);
    expect(rt.calls.map((x) => x.$1), contains('page.close'));

    // セッションが無くインストールもしていない → インストールの案内。
    final lone = CustomPageController(c, const CustomPageArgs(pluginId: _boardId));
    addTearDown(lone.dispose);
    await lone.start();
    expect(lone.phase, CustomPagePhase.needsInstall);
  });

  test('1 人で使うプラグインは共有セッションに入れない / セッション無しで shared.* は通さない', () async {
    final custom = MockCustomSessionClient();
    late FakeSlotRuntime rt;
    final c = container(custom: custom, plugins: {'store:$_boardId@1.0.0': () => rt = _board(mode: 'solo')});
    await c.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false);
    final s = await custom.create(pluginId: _boardId, scope: 'link');
    final joined = CustomPageController(c, CustomPageArgs(pluginId: _boardId, sessionId: s.id));
    addTearDown(joined.dispose);
    await joined.start();
    expect(joined.phase, CustomPagePhase.failed);
    expect(joined.error, contains('1 人で使う'));

    final alone = CustomPageController(c, const CustomPageArgs(pluginId: _boardId));
    addTearDown(alone.dispose);
    await alone.start();
    expect(alone.phase, CustomPagePhase.ready);
    alone.onRrlEvent('inc', 'tap', fn: 'inc');
    await _settle();
    expect(_text(alone.root!), contains('カウント 0'));
    expect(c.read(slotPluginsNoticeProvider), isNot(contains('shared')));
    expect(rt.calls.where((x) => x.$1 == 'page.event'), isEmpty);
  });

  testWidgets('ページの画面: RRL を描き、ボタン / 入力欄のイベントでみんなの値が変わる', (tester) async {
    final custom = MockCustomSessionClient();
    final s = await custom.create(pluginId: _boardId, version: '1.0.0', scope: 'link');
    FakeSlotRuntime? rt;
    FakeSlotRuntime make() {
      var count = 0;
      var notes = <Object?>[];
      Map<String, Object?> root() => {
            't': 'Column',
            'k': 'root',
            'c': [
              {'t': 'Text', 'k': 'count', 'p': {'text': 'カウント $count'}},
              {'t': 'Button', 'k': 'inc', 'p': {'label': '+1'}, 'on': {'tap': 'inc'}},
              {'t': 'Input', 'k': 'note', 'p': {'hint': 'ひとこと'}, 'on': {'submit': 'note'}},
              for (final n in notes) {'t': 'Text', 'p': {'text': '📝 $n'}},
            ],
          };
      return rt = FakeSlotRuntime(
        manifest: _manifest(),
        handler: (rt, fn, args) {
          switch (fn) {
            case 'page.open':
              return {'root': root()};
            case 'inc':
              rt.hostFn('shared.op', {'token': args['token'], 'key': 'count', 'op': 'incr', 'value': 1});
              return {};
            case 'note':
              rt.hostFn('shared.op', {'token': args['token'], 'key': 'notes', 'op': 'append', 'value': args['text']});
              return {};
            case 'page.event':
              if (args['type'] == 'var') {
                if (args['key'] == 'count') count = (args['value'] as num).toInt();
                if (args['key'] == 'notes') notes = [...(args['value'] as List)];
                rt.hostFn('page.render', {'token': args['token'], 'root': root()});
              }
              return {};
          }
          return {};
        },
      );
    }

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})})),
        pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
        storeClientProvider.overrideWithValue(_Store()),
        customSessionClientProvider.overrideWithValue(custom),
        slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader({'store:$_boardId@1.0.0': make})),
      ],
      child: Consumer(builder: (context, ref, _) {
        return MaterialApp(home: FutureBuilder(
          future: ref.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false),
          builder: (_, snap) => snap.connectionState != ConnectionState.done ? const SizedBox() : CustomPageScreen(args: CustomPageArgs(pluginId: _boardId, sessionId: s.id)),
        ));
      }),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(rt, isNotNull);
    expect(find.text('カウント 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('custom.page.participants')), findsOneWidget);
    await tester.tap(find.text('+1'));
    await tester.pump();
    await tester.pump();
    expect(find.text('カウント 1'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'おつかれ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    await tester.pump();
    expect(find.text('📝 おつかれ'), findsOneWidget);
    expect(custom.vars[s.id]!['notes']!.value, ['おつかれ']);
  });

  testWidgets('ルームの節: デプロイされたものを並べる / 共有の提案カードの見出し', (tester) async {
    final custom = MockCustomSessionClient();
    await custom.create(pluginId: _boardId, version: '1.0.0', scope: 'room:r1');
    final room = AstellRoom(id: 'r1', ownerId: 'me', ownerHandle: 'me', ownerDisplayName: 'あなた', title: '打ち上げ', createdAt: DateTime(2026, 9, 27));
    await tester.pumpWidget(ProviderScope(
      overrides: [customSessionClientProvider.overrideWithValue(custom)],
      child: MaterialApp(home: Scaffold(body: AstellCustomPluginsSection(session: AstellSessionState(room: room, myAccountId: 'me')))),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('astell.custom.$_boardId')), findsOneWidget);
    expect(find.text('プラグインを追加'), findsOneWidget); // ホスト
    await tester.pumpWidget(ProviderScope(
      overrides: [customSessionClientProvider.overrideWithValue(custom)],
      child: MaterialApp(home: Scaffold(body: AstellCustomPluginsSection(session: AstellSessionState(room: room, myAccountId: 'guest')))),
    ));
    await tester.pump();
    expect(find.text('プラグインを提案'), findsOneWidget);
    final share = AstellShare(id: 's1', accountId: 'g', handle: 'g', displayName: 'ゲスト', kind: 'plugin', payload: const CustomPluginProposal(pluginId: _boardId, name: 'ボード').toPayload(), createdAt: DateTime(2026, 9, 27));
    expect((share.headline, share.kindLabel), ('「ボード」を使いたい', 'プラグイン'));
  });

  testWidgets('プロフィールの「ページ」タブ: 置いたものを並べる(shared はセッションの有無)', (tester) async {
    final custom = MockCustomSessionClient();
    custom.seedPage('tester', const CustomProfilePage(pluginId: _boardId, name: 'ボード', mode: 'shared'));
    custom.seedPage('tester', const CustomProfilePage(pluginId: 'sample.memo', name: 'メモ'));
    await custom.create(pluginId: _boardId, scope: 'profile');
    await tester.pumpWidget(ProviderScope(
      overrides: [customSessionClientProvider.overrideWithValue(custom)],
      child: const MaterialApp(home: Scaffold(body: CustomProfilePagesTab(handle: 'tester', isMine: false))),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('ボード'), findsOneWidget);
    expect(find.text('みんなで使う'), findsOneWidget);
    expect(find.text('1 人で使う'), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.custom.edit')), findsNothing);
  });
}
