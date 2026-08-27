import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_design/rasq_design.dart';

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
      expect(controller.document!.root.p['reactionCount'], 1);

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
