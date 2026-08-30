import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// The real Misskey sample plugin, built from rasq-sdk-sample:
/// `cargo build --release --target wasm32-unknown-unknown -p misskey-wasm-sample`.
File get wasmFile => File('../../../rasq-sdk-sample/rust/target/wasm32-unknown-unknown/release/misskey_wasm_sample.wasm');

/// Canned Misskey `notes/local-timeline` response (2 notes, one with MFM).
final cannedNotes = jsonEncode([
  {
    'id': 'n1',
    'text': r'打ち上げ成功！ $[tada 🎉] #打上会',
    'cw': null,
    'createdAt': '2026-08-23T12:00:00.000Z',
    'user': {'username': 'douglas', 'name': 'ダグラス', 'host': null, 'avatarUrl': 'https://example.invalid/a.png'},
    'files': [
      {'id': 'f1', 'type': 'image/png', 'url': 'https://example.invalid/1.png', 'thumbnailUrl': null, 'isSensitive': false},
    ],
    'repliesCount': 2,
    'renoteCount': 5,
    'reactions': {'👍': 3, '🎉': 4},
  },
  {
    'id': 'n2',
    'text': '2件目',
    'cw': null,
    'createdAt': '2026-08-23T11:00:00.000Z',
    'user': {'username': 'tivard', 'name': null, 'host': 'other.example', 'avatarUrl': null},
    'files': [],
    'repliesCount': 0,
    'renoteCount': 0,
    'reactions': {},
  },
]);

Widget wrap(Widget child) => MaterialApp(
      theme: RasqTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 420, child: child))),
      ),
    );

void main() {
  if (!wasmFile.existsSync()) {
    test('misskey-wasm-sample built', () {}, skip: 'build misskey-wasm-sample first (rust/README.md)');
    return;
  }
  final bytes = wasmFile.readAsBytesSync();

  group('WasmPluginController', () {
    test('load → initial snapshot document (rev 1, sample tile)', () {
      final controller = WasmPluginController(wasmBytes: bytes);
      addTearDown(controller.dispose);
      controller.load();
      expect(controller.document, isNotNull);
      expect(controller.document!.rev, 1);
      expect(controller.document!.root.findByKey('post-sample-1'), isNotNull);
      expect(controller.document!.scope, startsWith('rasq.official.misskey'));
    });

    test('timeline: net.fetch (fake) → treeUpdated → new snapshot pulled', () {
      final requests = <SyncFetchRequest>[];
      final env = RasqHostEnvironment(fetch: (req) {
        requests.add(req);
        return SyncFetchResponse(status: 200, bodyText: cannedNotes);
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();

      final result = controller.invoke('timeline', {'host': 'misskey.example', 'limit': 5});
      expect(result['ok'], true, reason: '$result');
      expect((result['value'] as Map)['count'], 2);

      expect(requests.single.url.toString(), 'https://misskey.example/api/notes/local-timeline');
      expect(requests.single.method, 'POST');
      expect(jsonDecode(requests.single.body!), {'limit': 5});

      final doc = controller.document!;
      expect(doc.rev, 2);
      expect(doc.root.t, 'Column');
      expect(doc.root.findByKey('post-n1'), isNotNull);
      expect(doc.root.findByKey('post-n2'), isNotNull);
    });

    test('timeline with no network backend → B01 error, tree unchanged', () {
      final controller = WasmPluginController(wasmBytes: bytes); // env without fetch
      addTearDown(controller.dispose);
      controller.load();
      final result = controller.invoke('timeline');
      expect(result['ok'], false);
      expect((result['error'] as Map)['code'], 'B01');
      expect(controller.document!.rev, 1);
    });

    test('applyPatch applies on the initial tree; after timeline it resyncs (V10)', () {
      final env = RasqHostEnvironment(fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      controller.applyPatch(); // baseRev 1 → ok
      expect(controller.document!.rev, 2);
      // D-064 で初期ツリーは Column(PostTile + FOWデモ Button)になった。
      expect(controller.document!.root.findByKey('post-sample-1')!.p['reactionCount'], 1);

      controller.invoke('timeline'); // plugin rev is now 2 (fresh tree)
      controller.applyPatch(); // patch baseRev 1 vs rev 2 → resync
      expect(controller.document!.root.findByKey('post-n1'), isNotNull);
      expect(controller.lastError, isNull);
    });
  });

  group('WasmPluginView (import & render the ported plugin)', () {
    testWidgets('renders the fetched timeline through RrlRenderer/L2', (tester) async {
      final env = RasqHostEnvironment(fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      controller.invoke('timeline', {'host': 'misskey.example'});

      await tester.pumpWidget(wrap(WasmPluginView(controller: controller)));
      expect(find.byType(RasqPostTile), findsNWidgets(2));
      expect(find.textContaining('打ち上げ成功！'), findsOneWidget);
      expect(find.text('ダグラス'), findsOneWidget);
      expect(find.text('@tivard'), findsOneWidget);
      expect(find.byType(RasqMediaGrid), findsOneWidget);
      expect(find.byType(RasqActionBar), findsNWidgets(2));
      expect(find.text('5'), findsOneWidget); // renote count from note
    });

    testWidgets('tapping an action routes the event back into the plugin as a call', (tester) async {
      final env = RasqHostEnvironment(fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      controller.invoke('timeline');

      await tester.pumpWidget(wrap(WasmPluginView(controller: controller)));
      await tester.tap(find.byTooltip('返信').first);
      await tester.pump();

      final result = controller.lastResult!;
      expect(result['ok'], true);
      final echo = ((result['value'] as Map)['echo'] as Map).cast<String, Object?>();
      expect(echo['fn'], 'performAction');
      final args = (echo['args'] as Map).cast<String, Object?>();
      expect(args['kind'], 'tap');
      expect(args['actionId'], 'reply');
      expect('${args['nodeId']}', contains(':actions'));
    });

    testWidgets('MFM in the note body renders as a transform span', (tester) async {
      final env = RasqHostEnvironment(fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      controller.invoke('timeline');

      // The app injects its MFM parser; here a tiny fake proves the seam.
      await tester.pumpWidget(wrap(WasmPluginView(
        controller: controller,
        rslParser: (source) => source.contains(r'$[tada')
            ? [const RasqTextSpan('parsed:'), const RasqTransformSpan('tada', children: [RasqTextSpan('🎉')])]
            : [RasqTextSpan(source)],
      )));
      expect(find.textContaining('parsed:'), findsOneWidget);
      expect(find.byType(RasqMfmTransform), findsOneWidget);
    });
  });

  group('FOW surface (D-064)', () {
    test('fow.open → onFowOpen(RRL ドキュメント)→ タップで fow.close → onClosed 通知が call で戻る', () async {
      final controller = WasmPluginController(wasmBytes: bytes);
      addTearDown(controller.dispose);
      controller.load();
      WasmFowRequest? opened;
      final closes = <(String, Object?)>[];
      controller.onFowOpen = (req) => opened = req;
      controller.onFowClose = (id, {result, reason}) => closes.add((id, result));

      // 実物ノードへのアンカー (D-072): 呼び出し元バーの key が渡る。
      controller.handleEvent('scope:actions-n1', 'longPress', fn: 'pickReaction', payload: {'postId': 'p1'});
      final result = controller.lastResult!;
      expect(result['ok'], true, reason: '$result');
      expect((result['value'] as Map)['opened'], true);
      expect(opened, isNotNull);
      expect(opened!.id, 'reaction-picker');
      expect(opened!.spec['type'], 'widget');
      expect(opened!.spec['title'], 'リアクション (wasm)');
      expect(opened!.onClosed, 'fowClosed');
      expect(opened!.onCancel, 'confirmCloseFow');
      expect(opened!.anchorNode, 'actions-n1');
      expect(opened!.document.root.findByKey('emoji-like'), isNotNull);

      // lifecycle mount (D-072): v1 は call("lifecycle") で届く。
      await Future<void>.delayed(Duration.zero);
      final mounted = controller.invoke('lastLifecycle');
      expect((mounted['value'] as Map)['kind'], 'mount');
      expect((mounted['value'] as Map)['surface'], 'reaction-picker');

      // FOW 内の絵文字 Button のタップ = event → call(reactFromFow)。
      controller.handleEvent('${opened!.document.scope}:emoji-heart', 'tap', fn: 'reactFromFow');
      expect(closes.single.$1, 'reaction-picker');
      expect(closes.single.$2, '❤️');

      // アプリ層が実 FOW を閉じた通知 → プラグインの onClosed 関数へ +
      // lifecycle unmount (D-072)。
      controller.notifyFowClosed('reaction-picker', reason: 'completed', result: '❤️');
      await Future<void>.delayed(Duration.zero); // scheduleMicrotask 分
      final last = controller.invoke('lastFowClosed');
      expect(last['ok'], true, reason: '$last');
      expect((last['value'] as Map)['reason'], 'completed');
      expect((last['value'] as Map)['result'], '❤️');
      final unmounted = controller.invoke('lastLifecycle');
      expect((unmounted['value'] as Map)['kind'], 'unmount');
    });

    test('✕の割り込み (D-066): onCancel → 確認 FOW が開き、破棄で両方閉じる / 続けるで確認だけ閉じる', () {
      final controller = WasmPluginController(wasmBytes: bytes);
      addTearDown(controller.dispose);
      controller.load();
      final openedIds = <String>[];
      WasmFowRequest? lastOpened;
      final closes = <(String, String?)>[];
      controller.onFowOpen = (req) {
        openedIds.add(req.id);
        lastOpened = req;
      };
      controller.onFowClose = (id, {result, reason}) => closes.add((id, reason));

      controller.invoke('pickReaction', {'postId': 'p1'});
      // ✕押下 = ホストは閉じずに onCancel(confirmCloseFow)を call →
      // 画面そのままで確認 FOW が開く。
      controller.handleEvent('scope:reaction-picker', 'cancel', fn: 'confirmCloseFow', payload: {'id': 'reaction-picker'});
      expect(openedIds, ['reaction-picker', 'reaction-picker-confirm']);
      expect(lastOpened!.spec['title'], '閉じますか?');
      expect(lastOpened!.document.root.findByKey('confirm-discard'), isNotNull);

      // 「続ける」→ 確認だけ閉じる。
      controller.handleEvent('scope:confirm-keep', 'tap', fn: 'keepFow');
      expect(closes, [('reaction-picker-confirm', null)]);

      // もう一度 ✕ → 「破棄」→ 確認と本体の両方が閉じる。
      controller.handleEvent('scope:reaction-picker', 'cancel', fn: 'confirmCloseFow', payload: {'id': 'reaction-picker'});
      controller.handleEvent('scope:confirm-discard', 'tap', fn: 'discardFow');
      expect(closes.sublist(1), [('reaction-picker-confirm', null), ('reaction-picker', 'discard')]);
    });

    test('surface patch (D-073): fowPlus → patch:true 引き取り → FOW ドキュメントだけ差分更新', () async {
      final controller = WasmPluginController(wasmBytes: bytes);
      addTearDown(controller.dispose);
      controller.load();
      controller.onFowOpen = (_) {};
      controller.invoke('pickReaction', {'postId': 'p1'});
      expect(controller.fowDocument('reaction-picker')!.root.findByKey('fow-count')!.p['text'], 'タップ 0 回');

      controller.handleEvent('scope:fow-plus', 'tap', fn: 'fowPlus');
      expect(controller.fowDocument('reaction-picker')!.rev, 2);
      expect(controller.fowDocument('reaction-picker')!.root.findByKey('fow-count')!.p['text'], 'タップ 1 回');
      controller.handleEvent('scope:fow-plus', 'tap', fn: 'fowPlus');
      expect(controller.fowDocument('reaction-picker')!.root.findByKey('fow-count')!.p['text'], 'タップ 2 回');
      expect(controller.document!.rev, 1); // 本体ドキュメントは動かない
      expect(controller.lastError, isNull);

      // 閉じたら surface ドキュメントは消える(再 open で rev 1 から)。
      controller.notifyFowClosed('reaction-picker');
      expect(controller.fowDocument('reaction-picker'), isNull);
      await Future<void>.delayed(Duration.zero); // lifecycle microtask 消化
    });

    test('権限ゲート: 許可外 type / 未配線 / id 無しはエラーで返る(トラップしない)', () {
      Map<String, dynamic> call(RasqHostEnvironment env, String fn, Map<String, Object?> args) =>
          (jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': 'f', 'fn': fn, 'args': args}))) as Map).cast<String, dynamic>();
      final root = {'t': 'Text', 'k': 'x'};
      final env = RasqHostEnvironment(onFow: (fn, args) => null); // 既定権限 = widget のみ
      expect(call(env, 'fow.open', {'id': 'x', 'spec': {'type': 'interstitial'}, 'root': root})['error']['code'], 'E01');
      expect(call(env, 'fow.open', {'id': 'x', 'spec': {'type': 'widget'}, 'root': root})['value'], {'opened': true});
      expect(call(env, 'fow.open', {'spec': {'type': 'widget'}, 'root': root})['error']['code'], 'D01');
      expect(call(env, 'fow.close', const {})['error']['code'], 'D01');
      expect(call(RasqHostEnvironment(), 'fow.open', {'id': 'x', 'spec': {'type': 'widget'}, 'root': root})['error']['code'], 'E01'); // 未配線
    });
  });

  group('WasmSnsSession (D-074/M5d: SnsSession 契約の boundary 写像)', () {
    const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.example', handle: 'me');

    test('sns.timeline → Post ワイヤ → Page<Post>(net.fetch はホスト代理)', () async {
      final env = RasqHostEnvironment(fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(
        account: viewer,
        pluginId: 'misskey-wasm-sample',
        extraArgs: const {'host': 'misskey.example'},
        invoke: (fn, args) async => controller.invoke(fn, args),
      );
      final page = await session.timeline(TimelineKind.local, limit: 5);
      expect(page.items, hasLength(2));
      final p = page.items.first;
      expect(p.id, 'n1');
      expect(p.account, viewer); // キー付けはホスト側
      expect(p.author.displayName, 'ダグラス');
      expect(p.author.account.instance, 'misskey.example'); // host フォールバック
      expect(p.body, contains('打ち上げ成功'));
      expect(p.bodyFormat, 'mfm');
      expect(p.media.single.type, MediaType.image);
      expect(p.counts['renote'], 5);
      expect(p.reactions['👍'], 3);
      expect(page.items[1].author.account.instance, 'other.example');
      expect(page.nextCursor, 'n2');
    });

    test('エラーは SnsApiException(コード付き)へ写る', () async {
      final controller = WasmPluginController(wasmBytes: bytes); // fetch なし → B01
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, invoke: (fn, args) async => controller.invoke(fn, args));
      await expectLater(
        session.timeline(TimelineKind.local),
        throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'B01')),
      );
    });
  });

  test('RasqHostEnvironment: storage round trip + unknown fn C01', () {
    final env = RasqHostEnvironment();
    final set = jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '1', 'fn': 'storage.set', 'args': {'ns': 'safe', 'key': 'k', 'value': 42}})));
    expect(set['ok'], true);
    final got = jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '2', 'fn': 'storage.get', 'args': {'ns': 'safe', 'key': 'k'}})));
    expect(got['value']['value'], 42);
    final unknown = jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '3', 'fn': 'nope', 'args': {}})));
    expect(unknown['error']['code'], 'C01');
    final ml = jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '4', 'fn': 'ml.infer', 'args': {'model': 'x'}})));
    expect(ml['error']['code'], 'E01');
  });
}
