import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart' show Routes;
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart' show childGateProvider;
import 'package:rasq_client/features/custom/custom_astell.dart';
import 'package:rasq_client/features/custom/custom_client.dart';
import 'package:rasq_client/features/custom/custom_models.dart';
import 'package:rasq_client/features/custom/custom_page.dart';
import 'package:rasq_client/features/custom/custom_profile.dart';
import 'package:rasq_client/features/plugins/slot_plugins.dart';
import 'package:rasq_client/features/plugins/svg_paint_editor.dart' show SvgPaintResult;
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

/// 見守りの関所 (D-451): `allow.plugins` だけ決めた制限。
ChildGate _kidGate({List<String> ids = const [], ChildSafeInstall install = ChildSafeInstall.listed, Map<String, bool> slots = const {}}) => ChildGate(
      state: ChildSafeState(managed: true, state: 'active', policy: ChildSafePolicy(allow: ChildSafeAllow(plugins: ChildSafePluginsAllow(ids: ids, install: install, slots: slots)))),
      now: DateTime(2026, 10, 7, 12),
    );

/// テストの中で保護者の制限を変えられるように。
class _Gate extends Notifier<ChildGate> {
  _Gate(this.initial);
  final ChildGate initial;
  @override
  ChildGate build() => initial;
  void set(ChildGate g) => state = g;
}

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
    expect(m.appFns, containsAll([RasqHostFns.pageRender, RasqHostFns.sharedSet, RasqHostFns.sharedOp, RasqHostFns.sharedCall, RasqHostFns.mediaEditorOpen]));
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

  ProviderContainer container({StoreClient? store, MockCustomSessionClient? custom, required Map<String, FakeSlotRuntime Function()> plugins, NotifierProvider<_Gate, ChildGate>? gate}) {
    TestWidgetsFlutterBinding.ensureInitialized();
    final c = ProviderContainer(overrides: [
      sessionStorageProvider.overrideWithValue(MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})})),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
      storeClientProvider.overrideWithValue(store ?? _Store()),
      customSessionClientProvider.overrideWithValue(custom ?? MockCustomSessionClient()),
      slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader(plugins)),
      if (gate != null) childGateProvider.overrideWith((ref) => ref.watch(gate)),
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

  test('別のプラグインのセッション: 入れたプラグインに page.open もみんなの値も渡さない / 同じプラグインはこれまでどおり (セキュリティ確認 2026-10-09 の [2])', () async {
    final custom = MockCustomSessionClient();
    late FakeSlotRuntime rt;
    final c = container(custom: custom, plugins: {'store:$_boardId@1.0.0': () => rt = _board()});
    await c.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false);
    // 利用者が入れる、別のプラグイン A のセッション(秘密の値と参加者)。
    final other = await custom.create(pluginId: 'other.secret', version: '1.0.0', scope: 'link');
    custom.vars[other.id]!['secret'] = const CustomVar(value: 'A の秘密', rev: 1, by: 'u2');
    custom.join(other.id, const CustomParticipant(accountId: 'u2', handle: 'hanako'));

    final page = CustomPageController(c, CustomPageArgs(pluginId: _boardId, sessionId: other.id));
    addTearDown(page.dispose);
    await page.start();
    await _settle();
    expect(page.phase, CustomPagePhase.failed);
    expect(page.error, contains('セッションではありません'));
    expect(rt.calls.where((x) => x.$1 == 'page.open' || x.$1 == 'page.event'), isEmpty);
    expect(page.session, isNull);
    expect(page.vars, isEmpty);
    expect(page.participants, isEmpty);
    expect(page.hasSession, isFalse);
    // 共有の口も A へは送らない。
    page.shared('shared.set', {'key': 'secret', 'value': 'x'});
    custom.actAs(other.id, const CustomParticipant(accountId: 'u2', handle: 'hanako'), {'type': 'set', 'key': 'title', 'value': 'y'});
    await _settle();
    expect(custom.vars[other.id]!['secret']!.value, 'A の秘密');
    expect(rt.calls.where((x) => x.$1 == 'page.event'), isEmpty);
    final board = c.read(slotPluginsProvider).single;
    expect(CustomPageController.sessionBelongsTo(other, board), isFalse);
    expect(CustomPageController.sessionBelongsTo(CustomSession.fromJson({'id': 'x', 'scope': 'link'}), board), isFalse); // 名乗りが無い

    // 同じプラグインのセッションは入れて、自分のキーだけ書ける。
    final mine = await custom.create(pluginId: _boardId, version: '1.0.0', scope: 'link');
    final ok = CustomPageController(c, CustomPageArgs(pluginId: _boardId, sessionId: mine.id));
    addTearDown(ok.dispose);
    await ok.start();
    await _settle();
    expect(ok.phase, CustomPagePhase.ready);
    ok.shared('shared.set', {'key': 'me.vote', 'value': 'a'});
    ok.shared('shared.set', {'key': '@u2.vote', 'value': 'b'});
    await _settle();
    expect(custom.vars[mine.id]!.keys, ['@me.vote']);
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

  group('チャイルドセーフ (D-451): 保護者が止めたカスタムプラグインのページは開かない', () {
    test('関所: ページのスロット / 名指し / ルート', () {
      expect(ChildGate.off.pluginPageBlockReason(_boardId), isNull);
      expect(_kidGate().pluginPageBlockReason(_boardId), '保護者がこのプラグインを止めています');
      expect(_kidGate(ids: [_boardId]).pluginPageBlockReason(_boardId), isNull);
      expect(_kidGate(ids: [_boardId], slots: {'page': false}).pluginPageBlockReason(_boardId), isNotNull);
      // `any` は止める例に近くなければ通す。`examples` は中身が分からないうちは通さない。
      expect(_kidGate(install: ChildSafeInstall.any).pluginPageBlockReason(_boardId), isNull);
      expect(_kidGate(install: ChildSafeInstall.examples).pluginPageBlockReason(_boardId), isNotNull);
      // ルート: ページ型をどれも使えないときだけ画面ごと止める(1 つずつは開く側)。
      final route = Routes.customPage(_boardId);
      expect(ChildGate.off.routeBlockReason(route), isNull);
      expect(_kidGate().routeBlockReason(route), '保護者がカスタムプラグインを止めています');
      expect(_kidGate(ids: [_boardId], slots: {'page': false}).routeBlockReason(route), isNotNull);
      expect(_kidGate(ids: ['other.plugin']).routeBlockReason(route), isNull);
      expect(_kidGate(install: ChildSafeInstall.any).routeBlockReason(route), isNull);
      expect(_kidGate().routeBlockReason('/custom'), isNull);
    });

    test('入れているもの: 止めていれば page.open を呼ばず理由を出す / 開いたあとに止めたら閉じて、出来事も描画も通さない', () async {
      final custom = MockCustomSessionClient();
      final gate = NotifierProvider<_Gate, ChildGate>(() => _Gate(_kidGate()));
      final events = <(String, Map<String, Object?>)>[];
      final runtimes = <FakeSlotRuntime>[];
      final c = container(custom: custom, gate: gate, plugins: {'store:$_boardId@1.0.0': () => (runtimes..add(_board(events: events))).last});
      await c.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false);
      final rt = runtimes.last;

      final denied = CustomPageController(c, const CustomPageArgs(pluginId: _boardId, surface: 'profile', profileHandle: 'kid'));
      addTearDown(denied.dispose);
      await denied.start();
      expect(denied.phase, CustomPagePhase.blocked);
      expect(denied.error, '保護者がこのプラグインを止めています');
      expect(denied.plugin, isNull);
      expect(rt.calls.map((x) => x.$1), isNot(contains('page.open')));
      // 口そのものも断る(ほかの入口から呼ばれても)。
      final direct = await c.read(slotPluginsProvider.notifier).pageOpen(c.read(slotPluginsProvider).single, token: 't', args: const {}, sink: denied);
      expect(direct.error, contains('保護者'));
      expect(rt.calls.map((x) => x.$1), isNot(contains('page.open')));

      // 許す → 開ける(共有セッションにも入る)。
      c.read(gate.notifier).set(_kidGate(ids: [_boardId]));
      final s = await custom.create(pluginId: _boardId, version: '1.0.0', scope: 'link');
      final page = CustomPageController(c, CustomPageArgs(pluginId: _boardId, sessionId: s.id));
      addTearDown(page.dispose);
      await page.start();
      await _settle();
      expect(page.phase, CustomPagePhase.ready);
      expect(page.hasSession, isTrue);

      // 開いたまま保護者が止める → page.close、セッションから抜ける。ほかの人の書き込みもボタンも、もう渡さない。
      c.read(gate.notifier).set(_kidGate());
      await _settle();
      expect(page.phase, CustomPagePhase.blocked);
      expect(page.root, isNull);
      expect(page.hasSession, isFalse);
      expect(rt.calls.where((x) => x.$1 == 'page.close').single.$2['reason'], 'childSafe');
      final before = rt.calls.length;
      custom.actAs(s.id, const CustomParticipant(accountId: 'u2', handle: 'u2'), {'type': 'op', 'key': 'count', 'op': 'incr', 'value': 1});
      page.onRrlEvent('inc', 'tap', fn: 'inc');
      rt.hostFn('page.render', {'token': page.token, 'root': {'t': 'Column'}});
      await _settle();
      expect(rt.calls.length, before);
      expect(page.root, isNull);
      expect(events, isEmpty);
    });

    test('共有セッションの参加者(入れていない): 止めていれば同意も聞かず、取りにも行かない / 同意のあいだに止めても取らない', () async {
      final custom = MockCustomSessionClient();
      final store = _Store();
      final gate = NotifierProvider<_Gate, ChildGate>(() => _Gate(_kidGate()));
      var loads = 0;
      final c = container(store: store, custom: custom, gate: gate, plugins: {'store:$_boardId@1.0.0': () {
        loads++;
        return _board();
      }});
      final s = await custom.create(pluginId: _boardId, version: '1.0.0', scope: 'room:r1');
      final page = CustomPageController(c, CustomPageArgs(pluginId: _boardId, version: '1.0.0', surface: 'astell', sessionId: s.id, roomId: 'r1'));
      addTearDown(page.dispose);
      await page.start();
      expect(page.phase, CustomPagePhase.blocked);
      await page.acceptTemporary();
      expect(page.phase, CustomPagePhase.blocked);
      expect(store.sessionDownloads, isEmpty);
      expect(loads, 0);

      // 同意の画面のあいだに止めた。
      c.read(gate.notifier).set(_kidGate(ids: [_boardId]));
      final later = CustomPageController(c, CustomPageArgs(pluginId: _boardId, version: '1.0.0', surface: 'astell', sessionId: s.id, roomId: 'r1'));
      addTearDown(later.dispose);
      await later.start();
      expect(later.phase, CustomPagePhase.needsConsent);
      c.read(gate.notifier).set(_kidGate());
      await _settle();
      expect(later.phase, CustomPagePhase.blocked);
      await later.acceptTemporary();
      expect(store.sessionDownloads, isEmpty);
      expect(loads, 0);
    });

    test('一時的に動かすもの: 名乗った id / 中身で止めたら、宣言どおりに起動し直さず捨てる(登録の関所)', () async {
      var loads = 0;
      final runtimes = <FakeSlotRuntime>[];
      final c = container(plugins: {'store:$_boardId@1.0.0': () {
        loads++;
        return (runtimes..add(_board())).last;
      }});
      final seen = <(String, List<String>?)>[];
      final p = await c.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false, temporary: true, admit: (id, text) {
        seen.add((id, text));
        return '保護者がこのプラグインを止めています';
      });
      expect(p, isNull);
      expect(loads, 1); // マニフェストを読む 1 段目だけ
      expect(runtimes.single.disposed, isTrue);
      expect(runtimes.single.calls.map((x) => x.$1), ['plugin.manifest']);
      expect(seen.single.$1, _boardId);
      expect(seen.single.$2, contains('みんなのボード'));
      expect(c.read(slotPluginsNoticeProvider), contains('保護者'));
    });

    testWidgets('ページの画面: 止めているときは見守りの案内を出す', (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sessionStorageProvider.overrideWithValue(MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})})),
          pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
          storeClientProvider.overrideWithValue(_Store()),
          customSessionClientProvider.overrideWithValue(MockCustomSessionClient()),
          slotRuntimeLoaderProvider.overrideWithValue(fakeSlotLoader({'store:$_boardId@1.0.0': _board})),
          childGateProvider.overrideWithValue(_kidGate()),
        ],
        child: Consumer(builder: (context, ref, _) {
          return MaterialApp(home: FutureBuilder(
            future: ref.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false),
            builder: (_, snap) => snap.connectionState != ConnectionState.done ? const SizedBox() : const CustomPageScreen(args: CustomPageArgs(pluginId: _boardId)),
          ));
        }),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byKey(const ValueKey('childSafe.blocked')), findsOneWidget);
      expect(find.text('保護者がこのプラグインを止めています'), findsOneWidget);
      expect(find.byKey(const ValueKey('custom.page.body')), findsNothing);
    });
  });

  group('契約 v0.22 (D-465 / Central S-106): 時刻・期限・owner の削除・落書きの編集画面', () {
    /// 偽のページ型: `paint` = `shared.set me.paint`(ttl 60)、`zap` = 他人の `@u2.paint` を消す、`draw` = `media.editor.open`。
    FakeSlotRuntime painter({required List<(String, Map<String, Object?>)> events, Map<String, Object?> editorArgs = const {'format': 'svg', 'aspect': '3:4', 'svg': '<svg/>', 'title': '落書き'}}) => FakeSlotRuntime(
          manifest: _manifest(),
          handler: (rt, fn, args) {
            final token = args['token'];
            switch (fn) {
              case 'page.open':
                return {'root': {'t': 'Text', 'k': 'root', 'p': {'text': '落書き'}}};
              case 'paint':
                rt.hostFn('shared.set', {'token': token, 'key': 'me.paint', 'value': {'svg': '<svg/>'}, 'ttl': 60});
                return {};
              case 'bump':
                rt.hostFn('shared.op', {'token': token, 'key': 'count', 'op': 'incr', 'value': 1, 'ttl': 30});
                return {};
              case 'zap':
                rt.hostFn('shared.set', {'token': token, 'key': '@u2.paint', 'value': null});
                return {};
              case 'draw':
                rt.hostFn('media.editor.open', {'token': token, ...editorArgs});
                return {};
              case 'page.event':
                events.add(('${args['type']}', args));
                return {};
              case 'page.close':
                return {};
            }
            return null;
          },
        );

    test('page.open / page.event / RRL のイベントに now(Central の時計に合わせる)、session に ownerAccountId、var の expiresAt / reason、shared.* の ttl', () async {
      var serverNow = DateTime(2030, 1, 2, 3, 4, 5);
      final custom = MockCustomSessionClient(clock: () => serverNow);
      final events = <(String, Map<String, Object?>)>[];
      late FakeSlotRuntime rt;
      final c = container(custom: custom, plugins: {'store:$_boardId@1.0.0': () => rt = painter(events: events)});
      await c.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false);
      final s = await custom.create(pluginId: _boardId, version: '1.0.0', scope: 'link');
      final page = CustomPageController(c, CustomPageArgs(pluginId: _boardId, sessionId: s.id));
      addTearDown(page.dispose);
      await page.start();
      await _settle();
      expect(page.phase, CustomPagePhase.ready);
      bool nearServer(Object? v) => v is int && (v - serverNow.millisecondsSinceEpoch).abs() < 5000;
      final open = rt.calls.firstWhere((x) => x.$1 == 'page.open').$2;
      expect(nearServer(open['now']), isTrue, reason: '${open['now']}');
      expect(((open['session'] as Map)['ownerAccountId'], (open['session'] as Map)['role']), ('me', 'owner'));

      // 期限つきで書く → var に expiresAt。RRL のイベントにも now。
      page.onRrlEvent('paint', 'tap', fn: 'paint');
      await _settle();
      expect(nearServer(rt.calls.lastWhere((x) => x.$1 == 'paint').$2['now']), isTrue);
      final at = serverNow.millisecondsSinceEpoch + 60000;
      expect(custom.vars[s.id]!['@me.paint']!.expiresAt, at);
      expect(page.vars['@me.paint']!.expiresAt, at);
      var e = events.lastWhere((x) => x.$1 == 'var').$2;
      expect((e['key'], e['expiresAt'], e.containsKey('reason'), nearServer(e['now'])), ('@me.paint', at, false, true));
      // op の ttl も Central へ渡る。
      page.onRrlEvent('bump', 'tap', fn: 'bump');
      await _settle();
      expect(custom.vars[s.id]!['count']!.expiresAt, serverNow.millisecondsSinceEpoch + 30000);

      // owner は他人の @<accountId>. を消せる(reason: removedByOwner)。
      const u2 = CustomParticipant(accountId: 'u2', handle: 'hanako', displayName: 'ハナコ');
      custom.join(s.id, u2);
      custom.actAs(s.id, u2, {'type': 'set', 'key': 'me.paint', 'value': {'svg': '<svg/>'}});
      page.onRrlEvent('zap', 'tap', fn: 'zap');
      await _settle();
      e = events.lastWhere((x) => x.$1 == 'var').$2;
      expect((e['key'], e['value'], e['by'], e['reason']), ('@u2.paint', null, 'me', 'removedByOwner'));
      expect(custom.vars[s.id]!.containsKey('@u2.paint'), isFalse);

      // 期限が来たら Central が消す(by: null、reason: expired)。
      serverNow = serverNow.add(const Duration(minutes: 2));
      custom.expire(s.id);
      await _settle();
      e = events.lastWhere((x) => x.$1 == 'var' && x.$2['key'] == '@me.paint').$2;
      expect((e['value'], e['by'], e['reason']), (null, null, 'expired'));
      expect(page.vars.containsKey('@me.paint'), isFalse);
      expect(events.every((x) => x.$2['now'] is int), isTrue);
    });

    test('media.editor.open: 開き方へ渡し、保存で edited / やめたら editCancelled / 開き直すと前は editCancelled / ページを閉じたら編集画面も閉じる', () async {
      final events = <(String, Map<String, Object?>)>[];
      late FakeSlotRuntime rt;
      final c = container(plugins: {'store:$_boardId@1.0.0': () => rt = painter(events: events)});
      await c.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false);
      final page = CustomPageController(c, const CustomPageArgs(pluginId: _boardId));
      final opened = <({String aspect, String? svg, String? title, Completer<SvgPaintResult?> done})>[];
      var closes = 0;
      page.editorOpener = ({required aspect, svg, title}) {
        final done = Completer<SvgPaintResult?>();
        opened.add((aspect: aspect, svg: svg, title: title, done: done));
        return (
          result: done.future,
          close: () {
            closes++;
            if (!done.isCompleted) done.complete(null);
          },
        );
      };
      await page.start();
      await _settle();
      expect(page.phase, CustomPagePhase.ready);

      page.onRrlEvent('draw', 'tap', fn: 'draw');
      await _settle();
      expect((opened.single.aspect, opened.single.svg, opened.single.title), ('3:4', '<svg/>', '落書き'));
      opened.single.done.complete(const SvgPaintResult(svg: '<svg viewBox="0 0 300 400"/>', width: 300, height: 400));
      await _settle();
      final edited = events.lastWhere((x) => x.$1 == 'edited').$2;
      expect((edited['svg'], edited['width'], edited['height'], edited['now'] is int), ('<svg viewBox="0 0 300 400"/>', 300, 400, true));

      // 開いている間にもう一度 → 前のものは閉じて editCancelled、新しいのは開いたまま。
      page.onRrlEvent('draw', 'tap', fn: 'draw');
      page.onRrlEvent('draw', 'tap', fn: 'draw');
      await _settle();
      expect((opened.length, closes, events.where((x) => x.$1 == 'editCancelled').length), (3, 1, 1));
      // ページを閉じたら編集画面も閉じる(結果はもう渡さない)。
      final before = rt.calls.length;
      page.dispose();
      await _settle();
      expect(closes, 2);
      expect(rt.calls.skip(before).where((x) => x.$1 == 'page.event'), isEmpty);
    });

    test('media.editor.open の引数: 縦横比は 1〜16 の整数(外れたら 3:4)、svg は 64 KiB まで、svg 以外の形式は editCancelled', () async {
      expect([for (final a in ['1:1', '16:9', '3:4', '99:1', '0:3', 'x', null, 3]) normalizeEditorAspect(a)], ['1:1', '16:9', '3:4', '3:4', '3:4', '3:4', '3:4', '3:4']);
      final events = <(String, Map<String, Object?>)>[];
      final big = '<svg>${'x' * (64 * 1024)}</svg>';
      final c = container(plugins: {
        'store:$_boardId@1.0.0': () => painter(events: events, editorArgs: {'format': 'svg', 'aspect': '9:16', 'svg': big}),
      });
      await c.read(slotPluginsProvider.notifier).register('store:$_boardId@1.0.0', bytes: Uint8List.fromList(utf8.encode('board')), persist: false);
      final page = CustomPageController(c, const CustomPageArgs(pluginId: _boardId));
      addTearDown(page.dispose);
      String? gotSvg = 'unset';
      String? gotAspect;
      page.editorOpener = ({required aspect, svg, title}) {
        gotSvg = svg;
        gotAspect = aspect;
        return (result: Completer<SvgPaintResult?>().future, close: () {});
      };
      await page.start();
      await _settle();
      page.onRrlEvent('draw', 'tap', fn: 'draw');
      await _settle();
      expect((gotAspect, gotSvg), ('9:16', null));
      // 開き方が無い(画面の外)/ svg 以外の形式 → すぐ editCancelled。
      page.editorOpener = null;
      page.onRrlEvent('draw', 'tap', fn: 'draw');
      await _settle();
      expect(events.where((x) => x.$1 == 'editCancelled'), hasLength(1));
    });
  });
}
