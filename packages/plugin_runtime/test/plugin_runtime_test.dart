// host-fn の応答 JSON(dynamic)をそのまま辿るテストなので、このファイルだけ dynamic 呼び出しを許す。
// ignore_for_file: avoid_dynamic_calls
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_wasm_runtime/rasq_wasm_runtime.dart';

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

/// サンプルプラグインが function.json で宣言する権限 (D-004)。ランタイムの
/// ゲートはこの宣言に載っている host-fn しか通さないので、テストでも実物と
/// 同じ宣言を通す。
const _samplePermissions = {RasqPermissions.network, RasqPermissions.storageSafe};

/// テストの偽サーバー。宣言に無いホストは E01 になる (schema v0.12)。
const _sampleHosts = {'misskey.io', 'misskey.example', 'x.test', 'x.example', 'example.com', 'example.invalid'}; // misskey.io = サンプルの既定 host

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
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
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
      final controller = WasmPluginController(wasmBytes: bytes, env: RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts)); // 権限はあるが fetch 未注入
      addTearDown(controller.dispose);
      controller.load();
      final result = controller.invoke('timeline');
      expect(result['ok'], false);
      expect((result['error'] as Map)['code'], 'B01');
      expect(controller.document!.rev, 1);
    });

    test('applyPatch applies on the initial tree; after timeline it resyncs (V10)', () {
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
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
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
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
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
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
      // ホストの予約の引数 (D-484): 表示の言語が毎回の call に載る(既定は ja)。
      expect(args['locale'], 'ja');

      // 表示の言語が変われば、次の call から変わった値が載る。args の locale(イベントの payload)はホストの値で上書き。
      addTearDown(() => RasqUiLocale.tag = RasqUiLocale.defaultTag);
      RasqUiLocale.tag = 'en-US';
      controller.invoke('performAction', {'nodeId': 'x:actions', 'kind': 'tap', 'actionId': 'reply'});
      final echoed = ((controller.lastResult!['value'] as Map)['echo'] as Map)['args'] as Map;
      expect(echoed['locale'], 'en-US');
      controller.invoke('performAction', {'nodeId': 'x:actions', 'kind': 'tap', 'actionId': 'reply', 'locale': 'fr'});
      expect((((controller.lastResult!['value'] as Map)['echo'] as Map)['args'] as Map)['locale'], 'en-US');
    });

    testWidgets('MFM in the note body renders as a transform span', (tester) async {
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
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

  group('メディア / リスト / クリップ (D-136)', () {
    const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.example', handle: 'me');

    test('sns.uploadMedia: multipart 本体がバイナリのまま境界を渡る', () async {
      // PNG のマジックナンバー + UTF-8 にならないバイト。文字列経路だと壊れる。
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0xFF, 0xFE]);
      SyncFetchRequest? seen;
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        seen = req;
        return const SyncFetchResponse(
          status: 200,
          bodyText: '{"id":"f1","type":"image/png","url":"https://x.test/f1.png","thumbnailUrl":"https://x.test/f1s.png","isSensitive":true,"comment":"ロケット","name":"rocket.png"}',
        );
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(
        account: viewer,
        extraArgs: const {'host': 'misskey.example', 'token': 'tok'},
        invoke: (fn, a) async => controller.invoke(fn, a),
      );

      final media = await session.uploadMedia(png, 'rocket.png', mimeType: 'image/png', sensitive: true, alt: 'ロケット');

      expect(media.id, 'f1');
      expect(media.type, MediaType.image);
      expect(media.sensitive, isTrue);
      expect(media.alt, 'ロケット');

      // multipart として組み立てられ、**生バイトがそのまま**入っている。
      expect(seen!.headers['Content-Type'], startsWith('multipart/form-data; boundary='));
      expect(seen!.bodyBytes, isNotNull, reason: 'バイナリ経路 ({b64}) を通ること');
      expect(seen!.body, isNull);
      final body = seen!.bodyBytes!;
      expect(_indexOfBytes(body, png), greaterThan(0), reason: '画像のバイト列が壊れずに載っている');
      final asText = latin1.decode(body);
      expect(asText, contains('name="file"; filename="rocket.png"'));
      expect(asText, contains('Content-Type: image/png'));
      expect(asText, contains('name="i"'), reason: 'Misskey はトークンをフィールドで渡す');
      expect(asText, contains('name="comment"'));
    });

    test('applySettings (D-044): TL 設定が毎呼び出しの settings に載り、取得パラメーターに効く', () async {
      final bodies = <String>[];
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        bodies.add(req.body ?? '');
        return SyncFetchResponse(status: 200, bodyText: cannedNotes);
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, extraArgs: const {'host': 'misskey.example', 'token': 't'}, invoke: (fn, a) async => controller.invoke(fn, a));

      // 設定前: プラグインは既定のまま(パラメーターを付けない)。
      await session.timeline(TimelineKind.home, limit: 5);
      expect(bodies.last, isNot(contains('withRenotes')));

      // ホストは値の変更毎(+ 最初の TL 取得前)に applySettings を呼ぶ。
      await session.applySettings('timeline', {'withRenotes': false, 'withReplies': true});
      await session.timeline(TimelineKind.home, limit: 5);
      expect(bodies.last, contains('"withRenotes":false'));
      expect(bodies.last, contains('"withReplies":true'));
    });

    test('settingsRead / settingsWrite (D-044): remote ページはサーバーが真実', () async {
      final writes = <String>[];
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        final endpoint = req.url.path.replaceFirst('/api/', '');
        if (endpoint == 'i/update') {
          writes.add(req.body ?? '');
          return const SyncFetchResponse(status: 200, bodyText: '{}');
        }
        return const SyncFetchResponse(status: 200, bodyText: '{"id":"me","username":"me","isLocked":true,"noCrawle":false}');
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, extraArgs: const {'host': 'misskey.example', 'token': 't'}, invoke: (fn, a) async => controller.invoke(fn, a));

      expect((await session.settingsRead('account'))['isLocked'], isTrue);
      // 書き込み後は読み直した値が返る(サーバーが弾いた変更も見える)。
      final after = await session.settingsWrite('account', 'noCrawle', true);
      expect(writes.single, contains('"noCrawle":true'));
      expect(after.containsKey('isLocked'), isTrue);

      // 知らない area は C01 → ホストがページを出さない。
      await expectLater(
        session.settingsRead('nope'),
        throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'C01')),
      );
    });

    test('sns.lists / listMembers / createList / add / remove', () async {
      final calls = <String>[];
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        final endpoint = req.url.path.replaceFirst('/api/', '');
        calls.add(endpoint);
        return switch (endpoint) {
          'users/lists/list' => const SyncFetchResponse(status: 200, bodyText: '[{"id":"L1","name":"友だち","userIds":["u1","u2"],"isPublic":false}]'),
          'users/lists/show' => const SyncFetchResponse(status: 200, bodyText: '{"id":"L1","name":"友だち","userIds":["u1"],"isPublic":false}'),
          'users/show' => const SyncFetchResponse(status: 200, bodyText: '[{"id":"u1","username":"alice","name":"アリス"}]'),
          'users/lists/create' => const SyncFetchResponse(status: 200, bodyText: '{"id":"L2","name":"新しいリスト","userIds":[]}'),
          'users/lists/push' || 'users/lists/pull' => const SyncFetchResponse(status: 204),
          _ => const SyncFetchResponse(status: 404, bodyText: '{}'),
        };
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, extraArgs: const {'host': 'misskey.example', 'token': 't'}, invoke: (fn, a) async => controller.invoke(fn, a));

      final lists = await session.lists();
      expect(lists.single.name, '友だち');
      expect(lists.single.memberIds, ['u1', 'u2']);

      expect((await session.listInfo('L1')).id, 'L1');
      // メンバーは id しか返らないので、ユーザーを引き直す。
      expect((await session.listMembers('L1')).single.displayName, 'アリス');
      expect(calls, contains('users/show'));

      expect((await session.createList('新しいリスト')).id, 'L2');
      await session.addToList('L1', 'u3');
      expect(calls, contains('users/lists/push'));
      await session.removeFromList('L1', 'u3');
      expect(calls, contains('users/lists/pull'));
    });

    test('sns.clips / clipNotes / userPlays', () async {
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        final endpoint = req.url.path.replaceFirst('/api/', '');
        return switch (endpoint) {
          'clips/list' => const SyncFetchResponse(status: 200, bodyText: '[{"id":"c1","name":"あとで読む","description":"メモ","isPublic":false,"notesCount":3}]'),
          'clips/notes' => SyncFetchResponse(status: 200, bodyText: cannedNotes),
          'users/flashs' => const SyncFetchResponse(status: 200, bodyText: '[{"id":"p1","title":"占い","summary":"あそび"}]'),
          _ => const SyncFetchResponse(status: 404, bodyText: '{}'),
        };
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, extraArgs: const {'host': 'misskey.example', 'token': 't'}, invoke: (fn, a) async => controller.invoke(fn, a));

      final clips = await session.clips();
      expect(clips.single.name, 'あとで読む');
      expect(clips.single.notesCount, 3);
      expect((await session.clipNotes('c1')).items, hasLength(2));

      final plays = await session.userPlays('u1');
      // Play は RASQ 内で実行せず外部リンクとして出す (D-039)。
      expect(plays.single.url.toString(), 'https://misskey.example/play/p1');
      expect(plays.single.title, '占い');
    });

  });

  group('WasmSnsSession — 通知 / 関係 / DM / 検索 (D-134)', () {
    const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.example', handle: 'me');

    /// エンドポイントごとに応答を返す偽 Misskey。呼ばれた順に記録する。
    ({WasmSnsSession session, List<String> calls, List<String> bodies}) sessionWith(Map<String, Object?> routes) {
      final calls = <String>[];
      final bodies = <String>[];
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        final endpoint = req.url.path.replaceFirst('/api/', '');
        calls.add(endpoint);
        bodies.add(req.body ?? '');
        final canned = routes[endpoint];
        if (canned == null) return const SyncFetchResponse(status: 404, bodyText: '{"error":"no route"}');
        return SyncFetchResponse(status: 200, bodyText: jsonEncode(canned));
      });
      final controller = WasmPluginController(wasmBytes: wasmFile.readAsBytesSync(), env: env);
      addTearDown(controller.dispose);
      controller.load();
      return (
        session: WasmSnsSession(
          account: viewer,
          pluginId: 'misskey-wasm-sample',
          extraArgs: const {'host': 'misskey.example', 'token': 'tok'},
          invoke: (fn, args) async => controller.invoke(fn, args),
        ),
        calls: calls,
        bodies: bodies,
      );
    }

    test('sns.capabilities: 文字数上限はインスタンスごとにプラグインが答える', () async {
      final s = sessionWith({
        'meta': {'maxNoteTextLength': 5000},
      });
      // 宣言前はホスト既定 (500)。
      expect(s.session.maxPostLength, 500);
      await s.session.loadCapabilities();
      expect(s.session.maxPostLength, 5000, reason: 'インスタンス設定を反映する');
    });

    test('sns.capabilities: meta が取れなくても Misskey の既定値で答える', () async {
      final s = sessionWith(const {}); // meta は 404
      await s.session.loadCapabilities();
      expect(s.session.maxPostLength, 3000);
    });

    test('sns.timelines: TL タブの並びをプラグインが宣言する', () async {
      final s = sessionWith(const {});
      await s.session.loadTimelines();
      expect(s.session.timelines.map((t) => t.id), ['home', 'social', 'local', 'global', 'featured']);
      expect(s.session.timelines.first.label, 'ホーム');
      // 宣言はネットワークを使わない(純粋な宣言関数)。
      expect(s.calls, isEmpty);
    });

    test('timeline(kind) が TL 種別ごとのエンドポイントへ届く (CONTRACT §6)', () async {
      final s = sessionWith({
        'notes/timeline': jsonDecode(cannedNotes),
        'notes/global-timeline': jsonDecode(cannedNotes),
        'notes/user-list-timeline': jsonDecode(cannedNotes),
      });
      await s.session.timeline(TimelineKind.home, limit: 5);
      expect(s.calls, contains('notes/timeline'));

      await s.session.timeline(TimelineKind.global, limit: 5);
      expect(s.calls, contains('notes/global-timeline'));

      await s.session.timeline(TimelineKind.list('L1', 'リスト'), limit: 5);
      expect(s.calls, contains('notes/user-list-timeline'));
      // 接頭辞は剥がして listId として送る。
      expect(s.bodies.last, contains('"listId":"L1"'));
    });

    test('sns.notifications: グループ通知が actors + reactionsByActor に畳まれる', () async {
      final s = sessionWith({
        'i/notifications-grouped': [
          {
            'id': 'nt1',
            'type': 'reaction',
            'createdAt': '2026-09-01T00:00:00.000Z',
            'isRead': false,
            'users': [
              {'id': 'u1', 'username': 'alice', 'name': 'アリス'},
              {'id': 'u2', 'username': 'bob', 'name': null},
            ],
            'reactions': [
              {'type': '🎉', 'user': {'id': 'u1', 'username': 'alice'}},
              {'type': '👍', 'user': {'id': 'u2', 'username': 'bob'}},
            ],
            'note': {'id': 'p1', 'text': '祝われた投稿', 'user': {'id': 'me', 'username': 'me'}, 'files': []},
          },
          {
            'id': 'nt2',
            'type': 'follow',
            'createdAt': '2026-08-31T00:00:00.000Z',
            'isRead': true,
            'user': {'id': 'u9', 'username': 'newbie', 'name': '新入り'},
          },
        ],
      });
      final page = await s.session.notifications(limit: 20);
      expect(page.items, hasLength(2));

      final grouped = page.items.first;
      expect(grouped.kind, NotificationKind.reaction);
      expect(grouped.read, isFalse);
      expect(grouped.actors.map((a) => a.displayName), ['アリス', 'bob']);
      expect(grouped.reactionsByActor, {'u1': '🎉', 'u2': '👍'});
      expect(grouped.post!.body, '祝われた投稿');
      expect(grouped.account, viewer); // キー付けはホスト側

      final follow = page.items[1];
      expect(follow.kind, NotificationKind.follow);
      expect(follow.kind.tile, NotificationTileType.follow);
      expect(follow.post, isNull);
      expect(page.nextCursor, 'nt2');
    });

    test('sns.notifications: グループ版が無いインスタンスは素の一覧へ落ちる', () async {
      // `i/notifications-grouped` は 404(ルート未登録)。
      final s = sessionWith({
        'i/notifications': [
          {'id': 'nt1', 'type': 'mention', 'createdAt': '2026-09-01T00:00:00.000Z', 'user': {'id': 'u1', 'username': 'alice'}},
        ],
      });
      final page = await s.session.notifications();
      expect(page.items.single.kind, NotificationKind.mention);
      expect(s.calls, containsAllInOrder(['i/notifications-grouped', 'i/notifications']));
    });

    test('sns.relationships / setFollowing: 鍵アカウントは requested で返る', () async {
      var created = false;
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        final endpoint = req.url.path.replaceFirst('/api/', '');
        if (endpoint == 'following/create') {
          created = true;
          return const SyncFetchResponse(status: 204);
        }
        if (endpoint == 'users/relation') {
          // 書き込み後は「申請中」— サーバーの状態がそのまま返るべき。
          return SyncFetchResponse(
            status: 200,
            bodyText: jsonEncode([
              {'id': 'u1', 'isFollowing': false, 'hasPendingFollowRequestFromYou': created, 'isMuted': false},
            ]),
          );
        }
        return const SyncFetchResponse(status: 404, bodyText: '{}');
      });
      final controller = WasmPluginController(wasmBytes: wasmFile.readAsBytesSync(), env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(
        account: viewer,
        extraArgs: const {'host': 'misskey.example', 'token': 'tok'},
        invoke: (fn, args) async => controller.invoke(fn, args),
      );

      final before = await session.relationship('u1');
      expect(before.following, isFalse);
      expect(before.requested, isFalse);

      final after = await session.setFollowing('u1', true);
      expect(created, isTrue);
      expect(after.following, isFalse, reason: '鍵アカウントは即フォローにならない');
      expect(after.requested, isTrue);
    });

    test('sns.userList: ミュート/ブロック/フォロー申請が同じ形で返る', () async {
      final s = sessionWith({
        'mute/list': [
          {'id': 'm1', 'mutee': {'id': 'u1', 'username': 'noisy', 'name': 'うるさい人'}},
        ],
        'blocking/list': [
          {'id': 'b1', 'blockee': {'id': 'u2', 'username': 'blocked'}},
        ],
        'following/requests/list': [
          {'id': 'r1', 'follower': {'id': 'u3', 'username': 'asker'}},
        ],
      });
      expect((await s.session.mutedUsers()).items.single.displayName, 'うるさい人');
      expect((await s.session.blockedUsers()).items.single.id, 'u2');
      final requests = await s.session.followRequests();
      expect(requests.single.user.account.handle, 'asker');
      expect(requests.single.id, 'u3', reason: 'accept/reject は userId で解決する');
    });

    test('sns.dmRooms: 限定公開投稿が相手ごとに 1 ルームへ束ねられる (CONTRACT §7)', () async {
      final s = sessionWith({
        'i': {'id': 'me', 'username': 'me', 'name': '自分'},
        'notes/mentions': [
          {
            'id': 'd1',
            'text': 'ないしょの話',
            'visibility': 'specified',
            'createdAt': '2026-09-01T10:00:00.000Z',
            'user': {'id': 'u1', 'username': 'peer', 'name': '相手'},
            'files': [],
          },
          {
            // 同じ相手の古い方は落ちる(新しい方だけがルームの lastPost)。
            'id': 'd0',
            'text': '前のやりとり',
            'visibility': 'specified',
            'createdAt': '2026-08-01T10:00:00.000Z',
            'user': {'id': 'u1', 'username': 'peer', 'name': '相手'},
            'files': [],
          },
          {
            // 限定公開でない投稿は DM にしない。
            'id': 'pub1',
            'text': '公開メンション',
            'visibility': 'public',
            'createdAt': '2026-09-01T11:00:00.000Z',
            'user': {'id': 'u2', 'username': 'other'},
            'files': [],
          },
        ],
      });
      final rooms = await s.session.dmRooms();
      expect(rooms, hasLength(1));
      expect(rooms.single.kind, DmRoomKind.direct);
      expect(rooms.single.peer.id, 'u1');
      expect(rooms.single.lastPost!.body, 'ないしょの話');
    });

    test('sns.sendDm: direct は限定公開ノートとして送る', () async {
      final s = sessionWith({
        'notes/create': {
          'createdNote': {
            'id': 'sent1',
            'text': '送ったよ',
            'visibility': 'specified',
            'createdAt': '2026-09-01T12:00:00.000Z',
            'user': {'id': 'me', 'username': 'me'},
            'files': [],
          },
        },
      });
      const room = DmRoom(id: 'dm:u1', peer: UserSummary(id: 'u1', account: viewer, displayName: '相手'));
      final sent = await s.session.sendDm(room, const NewPost(text: '送ったよ'));
      expect(sent.body, '送ったよ');
      expect(s.bodies.last, contains('"visibility":"specified"'));
      expect(s.bodies.last, contains('"visibleUserIds":["u1"]'));
    });

    test('sns.search / trendingTags', () async {
      final s = sessionWith({
        'notes/search': jsonDecode(cannedNotes),
        'users/search': [
          {'id': 'u1', 'username': 'found', 'name': '見つかった人'},
        ],
        'hashtags/trend': [
          {'tag': '打上会', 'usersCount': 42},
        ],
      });
      expect((await s.session.searchPosts('打ち上げ')).items, hasLength(2));
      expect((await s.session.searchUsers('found')).items.single.displayName, '見つかった人');
      final tags = await s.session.trendingTags();
      expect(tags.single.tag, '打上会');
      expect(tags.single.usersCount, 42);
    });
  });

  group('WasmSnsSession (D-074/M5d: SnsSession 契約の boundary 写像)', () {
    const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.example', handle: 'me');

    test('sns.timeline → Post ワイヤ → Page<Post>(net.fetch はホスト代理)', () async {
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
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

    test('sns.timeline: 純リノートは中身へ展開して repostedBy を載せる (D-100)', () async {
      final pureRenote = jsonEncode([
        {
          'id': 'outer1',
          'text': null,
          'fileIds': <Object?>[],
          'poll': null,
          'createdAt': '2026-08-31T12:00:00.000Z',
          'user': {'id': 'u2', 'username': 'renoter', 'name': 'リノートする人'},
          'renote': {
            'id': 'inner1',
            'text': '中身の本文',
            'createdAt': '2026-08-30T12:00:00.000Z',
            'user': {'id': 'u1', 'username': 'author', 'name': '元の人'},
          },
        },
      ]);
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (_) => SyncFetchResponse(status: 200, bodyText: pureRenote));
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(
        account: viewer,
        extraArgs: const {'host': 'misskey.example'},
        invoke: (fn, args) async => controller.invoke(fn, args),
      );
      final page = await session.timeline(TimelineKind.local, limit: 5);
      final p = page.items.single;
      expect(p.id, 'outer1'); // アクションは外側の id へ
      expect(p.body, '中身の本文'); // 「内容のない投稿」にならない
      expect(p.author.handle, 'author');
      expect(p.repostedBy?.handle, 'renoter');
    });

    test('純リノートの読み替え (D-112): repostTargetId を採取して各欄を中身のノートへ', () async {
      final pureRenote = jsonEncode([
        {
          'id': 'outer1',
          'text': null,
          'fileIds': <Object?>[],
          'poll': null,
          'createdAt': '2026-09-01T12:00:00.000Z',
          'user': {'id': 'u2', 'username': 'renoter'},
          'renote': {
            'id': 'inner1',
            'text': '中身の本文',
            'reactions': {':abunaiyo_i@.:': 2},
            'user': {'id': 'u1', 'username': 'author'},
          },
        },
      ]);
      final asked = <String>[];
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        asked.add('${req.url.path}:${jsonDecode(req.body ?? '{}')['noteId'] ?? ''}');
        if (req.url.path.endsWith('notes/timeline') || req.url.path.endsWith('notes/local-timeline')) {
          return SyncFetchResponse(status: 200, bodyText: pureRenote);
        }
        return const SyncFetchResponse(status: 200, bodyText: '[]');
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(
        account: viewer,
        extraArgs: const {'host': 'misskey.example'},
        invoke: (fn, args) async => controller.invoke(fn, args),
      );
      final page = await session.timeline(TimelineKind.local, limit: 5);
      final p = page.items.single;
      expect(p.id, 'outer1');
      // リアクション絵文字の URL 補完 (D-112): ローカルカスタムは /emoji/。
      expect(p.reactionEmojis[':abunaiyo_i@.:']?.toString(), 'https://misskey.example/emoji/abunaiyo_i.webp');
      // 各欄は中身のノート(inner1)に向く。
      asked.clear();
      await session.reactions(p.id, limit: 10);
      await session.reposters(p.id, limit: 10);
      expect(asked.where((a) => a.contains('inner1')), hasLength(2));
      expect(asked.where((a) => a.contains('outer1')), isEmpty);
    });

    test('sns.emojis (D-111): カスタム絵文字の取得と emojiUrl(未掲載は /emoji/ 縮退)', () async {
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        if (req.url.path.endsWith('emojis')) {
          return SyncFetchResponse(status: 200, bodyText: jsonEncode({
            'emojis': [
              {'name': 'blobcat', 'url': 'https://misskey.example/files/blobcat.webp', 'category': 'ねこ'},
            ],
          }));
        }
        return const SyncFetchResponse(status: 404);
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(
        account: viewer,
        extraArgs: const {'host': 'misskey.example'},
        invoke: (fn, args) async => controller.invoke(fn, args),
      );
      final emojis = await session.customEmojis();
      expect(emojis.single.name, 'blobcat');
      expect(emojis.single.url.toString(), 'https://misskey.example/files/blobcat.webp');
      expect((await session.emojiUrl('blobcat'))?.toString(), 'https://misskey.example/files/blobcat.webp');
      // 一覧に無いローカルカスタム(:name@.:)は /emoji/<name>.webp に縮退。
      expect((await session.emojiUrl('unknown@.'))?.toString(), 'https://misskey.example/emoji/unknown.webp');
    });

    test('sns.actions / sns.thread / sns.performAction (D-075)', () async {
      final requests = <String>[];
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        requests.add(req.url.path);
        if (req.url.path.endsWith('notes/show')) return SyncFetchResponse(status: 200, bodyText: jsonEncode(jsonDecode(cannedNotes)[0]));
        if (req.url.path.endsWith('notes/conversation')) return SyncFetchResponse(status: 200, bodyText: jsonEncode([jsonDecode(cannedNotes)[1]]));
        if (req.url.path.endsWith('notes/children')) return SyncFetchResponse(status: 200, bodyText: cannedNotes);
        if (req.url.path.endsWith('notes/reactions/create')) return const SyncFetchResponse(status: 204);
        return SyncFetchResponse(status: 200, bodyText: cannedNotes);
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(
        account: viewer,
        extraArgs: const {'host': 'misskey.example'},
        invoke: (fn, args) async => controller.invoke(fn, args),
      );

      // アクション宣言(register_action と同形)。
      await session.loadActions();
      expect([for (final a in session.actions) a.id], ['reply', 'renote', 'reaction']);
      expect(session.actions.last.genreTag, 'Reaction');
      expect(session.actions.last.doneIcon, 'add_reaction');

      // スレッド: show + conversation(古い順へ反転)+ children。
      final t = await session.thread('n1');
      expect(t.post.id, 'n1');
      expect(t.ancestors.single.id, 'n2');
      expect(t.descendants, hasLength(2));
      expect(requests.where((p) => p.endsWith('notes/show')), hasLength(1));

      // performAction: 短押しの中身はプラグイン(reaction → 204 → done)。
      final r = await session.performAction('reaction', 'n1', args: {'reaction': '🎉'});
      expect(r.done, isTrue);
      // 未対応アクションは C01 の SnsApiException。
      await expectLater(
        session.performAction('bookmark', 'n1'),
        throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'C01')),
      );
    });

    test('D-076 増線: createPost/deletePost/me/user/userPosts/reactions/reposters/quotes', () async {
      final douglas = {'id': 'u1', 'username': 'douglas', 'name': 'ダグラス', 'host': null, 'avatarUrl': null};
      final plain = {'id': 'n1', 'text': 'ふつうの投稿', 'user': douglas, 'files': [], 'reactions': {}, 'repliesCount': 0, 'renoteCount': 0};
      final replyNote = {'id': 'r1', 'text': '返信です', 'user': douglas, 'files': [], 'reactions': {}, 'replyId': 'n1', 'reply': plain};
      final quoteNote = {'id': 'q1', 'text': '引用です', 'user': douglas, 'files': [], 'reactions': {}, 'renote': plain};
      final seen = <String, Map<String, Object?>>{};
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts, fetch: (req) {
        final ep = req.url.path.split('/api/').last;
        seen[ep] = (jsonDecode(req.body ?? '{}') as Map).cast<String, Object?>();
        final Object? out = switch (ep) {
          'notes/create' => {'createdNote': quoteNote},
          'notes/delete' => null,
          'i' => {'id': 'me1', 'username': 'me', 'name': 'わたし', 'host': null},
          'users/show' => {...douglas, 'description': 'bio です', 'followersCount': 12, 'followingCount': 34, 'notesCount': 56, 'isBot': true, 'fields': [{'name': 'web', 'value': 'https://x.example'}], 'pinnedNotes': []},
          'users/notes' => [plain, replyNote, quoteNote],
          'notes/reactions' => [{'id': 're1', 'user': douglas, 'type': '🎉', 'createdAt': '2026-08-30T00:00:00Z'}],
          'notes/renotes' => [{'id': 'rn1', 'text': null, 'user': douglas, 'files': [], 'reactions': {}, 'renote': plain}, quoteNote],
          _ => [],
        };
        return out == null ? const SyncFetchResponse(status: 204) : SyncFetchResponse(status: 200, bodyText: jsonEncode(out));
      });
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(
        account: viewer,
        extraArgs: const {'host': 'misskey.example', 'token': 'T'},
        invoke: (fn, args) async => controller.invoke(fn, args),
      );

      // createPost: NewPost ワイヤ → notes/create への写像 → 作成 Post が返る。
      final created = await session.createPost(const NewPost(
          text: 'こんにちは', contentWarning: '注', replyToId: 'n1', visibility: 'home', localOnly: true,
          poll: NewPoll(choices: ['犬', '猫'], multiple: true, expiresAfter: Duration(hours: 1))));
      expect(created.id, 'q1');
      final body = seen['notes/create']!;
      expect(body['text'], 'こんにちは');
      expect(body['cw'], '注');
      expect(body['replyId'], 'n1');
      expect(body['visibility'], 'home');
      expect(body['localOnly'], true);
      expect((body['poll'] as Map)['choices'], ['犬', '猫']);
      expect((body['poll'] as Map)['expiredAfter'], 3600000);
      expect(body['i'], 'T'); // token は共通口で積まれる

      await session.deletePost('n1');
      expect(seen['notes/delete']!['noteId'], 'n1');

      expect((await session.me()).displayName, 'わたし');

      final profile = await session.user('u1');
      expect(profile.summary.displayName, 'ダグラス');
      expect(profile.followersCount, 12);
      expect(profile.isBot, isTrue);
      expect(profile.fields.single.name, 'web');
      expect(profile.profileUrl.toString(), contains('@douglas'));
      expect((await session.userByHandle('douglas', host: 'other.example'))!.summary.id, 'u1');
      expect(seen['users/show']!['username'], 'douglas');

      // userPosts: 返信/引用の振り分け (D-069 と同じ規約) がワイヤ越しでも効く。
      expect([for (final p in (await session.userPosts('u1', filter: UserPostsFilter.replies)).items) p.id], ['r1']);
      expect((await session.userPosts('u1', filter: UserPostsFilter.replies)).items.single.replyTo?.id, 'n1');
      expect([for (final p in (await session.userPosts('u1', filter: UserPostsFilter.quotes)).items) p.id], ['q1']);
      expect((await session.userPosts('u1', filter: UserPostsFilter.quotes)).items.single.quote?.body, 'ふつうの投稿');
      expect([for (final p in (await session.userPosts('u1', filter: UserPostsFilter.posts)).items) p.id], ['n1']);

      final reactions = await session.reactions('n1');
      expect(reactions.items.single.reaction, '🎉');
      expect(reactions.items.single.user.displayName, 'ダグラス');

      expect((await session.reposters('n1')).items, hasLength(2)); // リノートした人
      expect([for (final q in (await session.quotes('n1')).items) q.id], ['q1']);
    });

    test('実登録の口 (D-079): WasmSnsPlugin → PluginRegistry 解決、TL 前にアクション自動取り込み、close で破棄', () async {
      final plugin = WasmSnsPlugin(
        manifest: const PluginManifest(id: 'misskey-wasm-sample', name: 'Misskey (wasm sample)', version: '0.1.0', kind: PluginKind.sns, supportedSns: [SnsKind.misskey], permissions: [RasqPermissions.network, RasqPermissions.storageSafe]),
        kind: SnsKind.misskey,
        nativeFetch: false, // ワーカーはネットワーク無し(net.fetch → B01)
        loadBytes: () async => bytes,
      );
      final registry = PluginRegistry()..register(plugin);
      final account = AccountSession(account: viewer, pluginId: 'misskey-wasm-sample', token: 'TOKEN', createdAt: DateTime(2026));
      final session = registry.session(account);
      expect(session, isA<WasmSnsSession>());
      expect(session.pluginId, 'misskey-wasm-sample');
      expect(session.account, viewer);

      // TL は fetch 不能で B01 だが、**アクション宣言(静的)は先に取り込まれる**。
      await expectLater(
        session.timeline(TimelineKind.local),
        throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'B01')),
      );
      expect([for (final a in session.actions) a.id], ['reply', 'renote', 'reaction']);

      await registry.closeSession(account.account); // ワーカー破棄(例外なし)
    });

    test('TL レンダラー契約 v1 (D-080): tl.timelines 宣言 + tl.sort(リアクション順)', () async {
      final controller = WasmPluginController(wasmBytes: bytes);
      addTearDown(controller.dispose);
      controller.load();
      final tl = WasmTimelinePlugin(invoke: (fn, args) async => controller.invoke(fn, args));

      final specs = await tl.timelines();
      expect(specs, hasLength(1));
      expect(specs.single.id, 'reaction-rank');
      expect(specs.single.label, 'リアクション順');
      expect(specs.single.base, 'local');

      Post p(String id, int reactions) => Post(id: id, account: viewer, author: const UserSummary(id: 'u', account: AccountId(kind: SnsKind.misskey, instance: 'x', handle: 'u'), displayName: 'う'), createdAt: DateTime(2026), body: id, counts: {'reaction': reactions});
      final sorted = await tl.compose('reaction-rank', [p('a', 1), p('b', 5), p('c', 3)]);
      expect([for (final x in sorted) x.id], ['b', 'c', 'a']); // リアクション降順・同数は元順

      // 未知の TL id は C01 → StateError(呼び出し側で縮退)。
      await expectLater(tl.compose('nope', [p('a', 1)]), throwsA(isA<StateError>()));

      // 投稿カスタマイザ (D-082): 1 位に置き換えタイル(contentBody 込み)。
      final deco = await tl.customize('reaction-rank', await tl.compose('reaction-rank', [p('a', 1), p('b', 5)]));
      expect(deco.tiles.keys, ['b']);
      expect(deco.tiles['b']!.containsRole('contentBody'), isTrue);
      // 上付きバナー行 (D-085): 2 位はバッジ(RT 行スタイル)。
      expect(deco.badges.keys, ['a']);
      expect(deco.badges['a']!.icon, 'star');
      expect(deco.badges['a']!.text, contains('リアクション2位'));
      expect((await tl.customize('nope', [p('a', 1)])).tiles, isEmpty); // 失敗は空に縮退

      // 投稿加工 (D-083 transform_content): 表示前の本文加工(該当のみ)。
      Post body(String id, String text) => Post(id: id, account: viewer, author: const UserSummary(id: 'u', account: AccountId(kind: SnsKind.misskey, instance: 'x', handle: 'u'), displayName: 'う'), createdAt: DateTime(2026), body: text);
      final transformed = await tl.transform([body('t1', '打ち上げ成功！'), body('t2', 'ただの投稿')]);
      expect(transformed[0].body, '🚀 打ち上げ成功！');
      expect(transformed[1].body, 'ただの投稿');
    });

    test('V5 検証 (D-082): contentBody の無い置き換えタイルは破棄される', () async {
      final tl = WasmTimelinePlugin(invoke: (fn, args) async => {
            'ok': true,
            'value': {
              'tiles': {
                'good': {'t': 'Column', 'k': 'g', 'c': [{'t': 'PostTile', 'k': 'gp', 'role': 'contentBody', 'p': {'post': {'id': 'good'}}}]},
                'bad': {'t': 'Text', 'k': 'b', 'p': {'text': 'contentBody 無し'}},
              },
            },
          });
      Post p(String id) => Post(id: id, account: viewer, author: const UserSummary(id: 'u', account: AccountId(kind: SnsKind.misskey, instance: 'x', handle: 'u'), displayName: 'う'), createdAt: DateTime(2026), body: id);
      final deco = await tl.customize('x', [p('good'), p('bad')]);
      expect(deco.tiles.keys, ['good']); // V5 違反は破棄 → 通常タイルに縮退
    });

    test('エラーは SnsApiException(コード付き)へ写る', () async {
      final controller = WasmPluginController(wasmBytes: bytes, env: RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts)); // 権限はあるが fetch 未注入 → B01
      addTearDown(controller.dispose);
      controller.load();
      final session = WasmSnsSession(account: viewer, invoke: (fn, args) async => controller.invoke(fn, args));
      await expectLater(
        session.timeline(TimelineKind.local),
        throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', 'B01')),
      );
    });
  });

  test('gpu.compute (D-081): WGSL compute で f32 配列を 2 倍(GPU 無しは E01 でクラウドへ縮退)', () {
    // 門を開ける: 審査済み(gpuCompute)かつ gpu_ml の宣言。
    final controller = WasmPluginController(wasmBytes: bytes, env: RasqHostEnvironment(permissions: {RasqPermissions.gpuMl}, gpuCompute: true));
    addTearDown(controller.dispose);
    controller.load();
    final result = controller.invoke('gpuDouble', {'values': [1, 2.5, 3]});
    if (result['ok'] != true) {
      // GPU アダプターの無い環境: E01 = クラウドカルクレーターへの
      // フォールバック規約どおり。門は開いているので「permission denied」ではない。
      expect((result['error'] as Map)['code'], 'E01', reason: '$result');
      expect('${(result['error'] as Map)['message']}', isNot(contains('permission denied')), reason: '$result');
      markTestSkipped('no gpu adapter: $result');
      return;
    }
    final value = (result['value'] as Map).cast<String, Object?>();
    expect(value['placement'], 'device');
    expect((value['values'] as List).map((v) => (v as num).toDouble()).toList(), [2.0, 5.0, 6.0]);
  });

  group('gpu.compute の門 (D-081): 既定は閉、審査済み + gpu_ml のときだけ開ける', () {
    test('gpuComputeEnabled = gpuCompute かつ gpu_ml の宣言', () {
      expect(RasqHostEnvironment().gpuComputeEnabled, isFalse); // 既定は閉
      expect(RasqHostEnvironment(permissions: {RasqPermissions.gpuMl}).gpuComputeEnabled, isFalse); // 宣言だけ(未審査)
      expect(RasqHostEnvironment(permissions: RasqPermissions.all.difference({RasqPermissions.gpuMl}), gpuCompute: true).gpuComputeEnabled, isFalse); // 審査済みでも宣言が無い
      expect(RasqHostEnvironment(permissions: {RasqPermissions.gpuMl}, gpuCompute: true).gpuComputeEnabled, isTrue);
      expect(WasmWorkerConfig(wasmBytes: Uint8List(0)).gpuCompute, isFalse); // ワーカーの構成も既定は閉
    });

    // ランタイムが門を閉じたまま答えること(GPU の有無に関係なく決まる)。
    for (final (label, env) in [
      ('既定の env', RasqHostEnvironment()),
      ('gpu_ml の宣言だけ(gpuCompute 偽)', RasqHostEnvironment(permissions: {RasqPermissions.gpuMl})),
      ('gpuCompute 真でも gpu_ml の宣言が無い', RasqHostEnvironment(permissions: _samplePermissions, gpuCompute: true)),
    ]) {
      test('閉: $label → E01 permission denied', () {
        final controller = WasmPluginController(wasmBytes: bytes, env: env);
        addTearDown(controller.dispose);
        controller.load();
        final result = controller.invoke('gpuDouble', {'values': [1, 2]});
        expect(result['ok'], isFalse, reason: '$result');
        expect((result['error'] as Map)['code'], 'E01');
        expect('${(result['error'] as Map)['message']}', contains('permission denied'));
      });
    }
  });

  test('RasqHostEnvironment: storage round trip + unknown fn C01', () {
    final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: _sampleHosts);
    final set = jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '1', 'fn': 'storage.set', 'args': {'ns': 'safe', 'key': 'k', 'value': 42}})));
    expect(set['ok'], true);
    final got = jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '2', 'fn': 'storage.get', 'args': {'ns': 'safe', 'key': 'k'}})));
    expect(got['value']['value'], 42);
    final unknown = jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '3', 'fn': 'nope', 'args': {}})));
    expect(unknown['error']['code'], 'C01');
    final ml = jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '4', 'fn': 'ml.infer', 'args': {'model': 'x'}})));
    expect(ml['error']['code'], 'E01');
  });

  _fuelBudgetTests();

  group('権限ゲート (D-004): 宣言に無い権限を要する host-fn は E01', () {
    Map<String, dynamic> call(RasqHostEnvironment env, String fn, Map<String, Object?> args) =>
        (jsonDecode(env.dispatch(jsonEncode({'schema': 'rasq.hostfn/1', 'callId': '1', 'fn': fn, 'args': args}))) as Map).cast<String, dynamic>();

    test('net.fetch: network 未宣言なら、fetch バックエンドがあっても拒否', () {
      var reached = false;
      final env = RasqHostEnvironment(fetch: (_) {
        reached = true;
        return const SyncFetchResponse(status: 200, bodyText: '{}');
      });
      final res = call(env, 'net.fetch', {'url': 'https://example.com/'});
      expect(res['ok'], false);
      expect(res['error']['code'], 'E01');
      // バックエンドへ到達していない = 権限判定が実行より前にある。
      expect(reached, isFalse);
    });

    test('net.fetch: network を宣言すれば通る', () {
      final env = RasqHostEnvironment(
        permissions: const {RasqPermissions.network},
        fetchHosts: const {'example.com'},
        fetch: (_) => const SyncFetchResponse(status: 200, bodyText: '{}'),
      );
      expect(call(env, 'net.fetch', {'url': 'https://example.com/'})['ok'], true);
    });

    test('storage.*: storage.safe 未宣言なら読み書き削除とも拒否', () {
      final env = RasqHostEnvironment();
      expect(call(env, 'storage.set', {'ns': 'safe', 'key': 'k', 'value': 1})['error']['code'], 'E01');
      expect(call(env, 'storage.get', {'ns': 'safe', 'key': 'k'})['error']['code'], 'E01');
      expect(call(env, 'storage.delete', {'ns': 'safe', 'key': 'k'})['error']['code'], 'E01');
      expect(env.storage, isEmpty);
    });

    test('storage.*: ns ごとに別権限 — safe の宣言で unsafe は開かない', () {
      final env = RasqHostEnvironment(permissions: const {RasqPermissions.storageSafe});
      expect(call(env, 'storage.set', {'ns': 'safe', 'key': 'k', 'value': 1})['ok'], true);
      expect(call(env, 'storage.set', {'ns': 'unsafe', 'key': 'k', 'value': 1})['error']['code'], 'E01');
    });

    test('storage.*: 未知の ns は fail-closed(両方宣言していても通さない)', () {
      final env = RasqHostEnvironment(permissions: const {RasqPermissions.storageSafe, RasqPermissions.storageUnsafe});
      expect(call(env, 'storage.set', {'ns': 'nope', 'key': 'k', 'value': 1})['error']['code'], 'E01');
    });

    test('net.fetch: network 権限があっても、接続先の宣言が無ければどこにも繋げない (schema v0.12)', () {
      var reached = false;
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetch: (_) {
        reached = true;
        return SyncFetchResponse(status: 200, bodyText: '{}');
      });
      final r = call(env, 'net.fetch', {'method': 'GET', 'url': 'https://misskey.example/api/meta'});
      expect(r['error']['code'], 'E01');
      expect('${r['error']['message']}', contains('host not permitted'));
      expect(reached, isFalse, reason: '弾くのは fetch を呼ぶ前');
    });

    test('net.fetch: 宣言したホストだけ通る(完全一致、大文字小文字は区別しない、ポートは見ない)', () {
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: const {'misskey.example'}, fetch: (_) => SyncFetchResponse(status: 200, bodyText: '{}'));
      expect(call(env, 'net.fetch', {'url': 'https://Misskey.Example:8443/api/meta'})['ok'], true);
      expect(call(env, 'net.fetch', {'url': 'https://misskey.example.evil.test/'})['error']['code'], 'E01');
      expect(call(env, 'net.fetch', {'url': 'https://evilmisskey.example/'})['error']['code'], 'E01');
      // userinfo で host を偽装しても Uri.host は本当のホスト。
      expect(call(env, 'net.fetch', {'url': 'https://misskey.example@evil.test/'})['error']['code'], 'E01');
    });

    test('net.fetch: *.example.com はサブドメインだけ(apex は別に書く)、* はどこでも', () {
      expect(fetchHostPermitted('a.example.com', {'*.example.com'}), isTrue);
      expect(fetchHostPermitted('a.b.example.com', {'*.example.com'}), isTrue);
      expect(fetchHostPermitted('example.com', {'*.example.com'}), isFalse);
      expect(fetchHostPermitted('notexample.com', {'*.example.com'}), isFalse);
      expect(fetchHostPermitted('anything.test', {'*'}), isTrue);
      expect(fetchHostPermitted('anything.test', const {}), isFalse);
      expect(fetchHostPermitted('', {'*'}), isFalse);
    });

    test('net.fetch: network.instance はセッションのホストを後から許可する。宣言が無ければ grant は無視', () {
      final allowed = RasqHostEnvironment(permissions: _samplePermissions, instanceAllowed: true, fetch: (_) => SyncFetchResponse(status: 200, bodyText: '{}'));
      expect(call(allowed, 'net.fetch', {'url': 'https://misskey.example/api/meta'})['error']['code'], 'E01');
      expect(allowed.grantInstance('Misskey.Example'), isTrue);
      expect(allowed.effectiveFetchHosts, {'misskey.example'});
      expect(call(allowed, 'net.fetch', {'url': 'https://misskey.example/api/meta'})['ok'], true);
      expect(call(allowed, 'net.fetch', {'url': 'https://other.example/'})['error']['code'], 'E01');
      // 別のセッションのホストへ切り替えたら前のは消える。
      allowed.grantInstance('other.example');
      expect(call(allowed, 'net.fetch', {'url': 'https://misskey.example/'})['error']['code'], 'E01');

      final notDeclared = RasqHostEnvironment(permissions: _samplePermissions, fetch: (_) => SyncFetchResponse(status: 200, bodyText: '{}'));
      expect(notDeclared.grantInstance('misskey.example'), isFalse, reason: 'network.instance を宣言していないプラグインに、呼び出し側が後から権限を足せない');
      expect(call(notDeclared, 'net.fetch', {'url': 'https://misskey.example/'})['error']['code'], 'E01');
    });

    test('通信の形: 同期コントローラでも invoke のあとに流れる。B01 でも E01 でも控えられる', () {
      final env = RasqHostEnvironment(permissions: _samplePermissions, fetchHosts: const {'misskey.example'}, fetch: (_) => SyncFetchResponse(status: 200, bodyText: cannedNotes));
      final controller = WasmPluginController(wasmBytes: bytes, env: env);
      addTearDown(controller.dispose);
      final shapes = <Map<String, Object?>>[];
      controller.fetchShapes.listen(shapes.add);
      controller.load();
      controller.invoke('timeline', {'host': 'misskey.example', 'limit': 10});
      controller.invoke('timeline', {'host': 'other.example', 'limit': 10}); // 宣言外 → E01。それでも形は控える(ホストが違うので別の形)
      return Future<void>.delayed(Duration.zero).then((_) {
        expect(shapes.map((s) => (s['shape'] as Map)['host']), ['misskey.example', 'other.example']);
        expect(shapes.map((s) => s['hash']).toSet(), hasLength(2));
      });
    });

    test('ネイティブ net.fetch は network 未宣言なら短絡させない (迂回防止, D-023)', () {
      // ランタイム内で短絡された net.fetch は Dart のディスパッチャを通らない。
      // フラグ自体を落とさないと、上の E01 ゲートごと迂回される。
      expect(RasqHostEnvironment(nativeFetch: true).nativeFetchEnabled, isFalse);
      expect(RasqHostEnvironment(nativeFetch: true, permissions: const {RasqPermissions.network}).nativeFetchEnabled, isTrue);
      expect(RasqHostEnvironment(nativeFetch: false, permissions: const {RasqPermissions.network}).nativeFetchEnabled, isFalse);
    });
  });
}

/// `needle` が `haystack` に現れる位置(無ければ -1)。
int _indexOfBytes(List<int> haystack, List<int> needle) {
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

void _fuelBudgetTests() {
  group('fuel 予算: 分ける軸はビットマップを触るかどうか', () {
    test('composer.media スロット / replace_media / tag_media は重いほう', () {
      expect(fuelBudgetFor(permissions: const {}, slots: const {kComposerMediaSlot}), RasqWasmPlugin.mediaFuelBudget);
      expect(fuelBudgetFor(permissions: const {RasqPermissions.replaceMedia}), RasqWasmPlugin.mediaFuelBudget);
      expect(fuelBudgetFor(permissions: const {RasqPermissions.tagMedia}), RasqWasmPlugin.mediaFuelBudget);
    });

    test('viewer.overlay(全画面表示プラグイン)も画像を受け取って復号するので重いほう (D-519)', () {
      // QR コード検出のサンプルの宣言そのまま(fow.widget / mute.words だけでも、スロットで重いほう)。
      expect(fuelBudgetFor(permissions: const {RasqPermissions.fowWidget, 'mute.words'}, slots: const {kViewerOverlaySlot}), RasqWasmPlugin.mediaFuelBudget);
    });

    test('それ以外は絞られる', () {
      expect(fuelBudgetFor(permissions: const {RasqPermissions.network}), RasqWasmPlugin.standardFuelBudget);
      expect(fuelBudgetFor(permissions: const {RasqPermissions.storageSafe}, slots: const {'tl'}), RasqWasmPlugin.standardFuelBudget);
      expect(fuelBudgetFor(permissions: const {}), RasqWasmPlugin.standardFuelBudget);
    });

    test('絞ったほうが実際に小さくないと、配線しても意味が無い', () {
      expect(RasqWasmPlugin.standardFuelBudget, lessThan(RasqWasmPlugin.mediaFuelBudget));
      expect(RasqWasmPlugin.standardFuelBudget, greaterThan(0));
    });

    test('scaleFuelBudget: 倍率を掛ける(制限モード 0.5、D-308)。null = ランタイム既定(重いほう)に掛ける', () {
      expect(scaleFuelBudget(RasqWasmPlugin.standardFuelBudget, 0.5), RasqWasmPlugin.standardFuelBudget ~/ 2);
      expect(scaleFuelBudget(RasqWasmPlugin.mediaFuelBudget, 0.5), RasqWasmPlugin.mediaFuelBudget ~/ 2);
      expect(scaleFuelBudget(null, 0.5), RasqWasmPlugin.mediaFuelBudget ~/ 2);
      expect(scaleFuelBudget(RasqWasmPlugin.standardFuelBudget, 1), RasqWasmPlugin.standardFuelBudget);
      expect(scaleFuelBudget(null, 1), isNull);
      expect(scaleFuelBudget(100, 0), 1); // 0 には落とさない
    });
  });
}
