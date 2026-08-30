import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

const instanceScope = 'rasq.official.misskey:misskey:misskey.io:yamada:0.1.0:tl-home';

/// Host data the sample snapshot binds into ($.post / $.actions / $.actionStates).
Map<String, Object?> hostData({bool withCw = false, bool withMedia = true}) => {
      'post': {
        'id': 'p1',
        'key': 'misskey:misskey.io:yamada:p1',
        'author': {'displayName': 'タロ・ヤマダ', 'handle': 'yamada', 'kind': 'misskey', 'instance': 'misskey.io'},
        'createdAt': '2026-08-22T12:00:00Z',
        'bodyRSL': '本文テキスト',
        'contentWarning': withCw ? '注釈あり' : null,
        'media': withMedia
            ? [
                {'id': 'm1', 'type': 'image', 'url': 'https://example.invalid/1.png'},
                {'id': 'm2', 'type': 'image', 'url': 'https://example.invalid/2.png'},
              ]
            : [],
        'poll': null,
        'quote': null,
      },
      'actions': [
        {'id': 'reply', 'label': '返信', 'icon': 'subdirectory_arrow_left'},
        {'id': 'renote', 'label': 'リノート', 'icon': 'repeat', 'doneIcon': 'repeat_on'},
      ],
      'actionStates': {
        'misskey:misskey.io:yamada:p1': {
          'renote': {'done': true, 'count': 12},
          'reply': {'count': 2},
        },
      },
    };

RrlNode sampleRoot() {
  final file = File('../rrl_core/test/fixtures/post_tile.rrl.json');
  final message = (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
  return RrlDocument.fromSnapshot(message).root;
}

Widget wrap(Widget child) => MaterialApp(
      theme: RasqTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 400, child: child))),
    );

void main() {
  // Image.network in tests: errorBuilder handles the failed fetch, fine.

  group('sample snapshot (post-tile.rrl.json)', () {
    testWidgets('renders body, media grid and store-fed action bar', (tester) async {
      final events = <(String, String)>[];
      final host = RrlHost(
        instanceScope: instanceScope,
        scope: RrlScope(hostData()),
        onEvent: (nodeId, kind, {fn, payload = const {}}) => events.add((nodeId, kind)),
      );
      await tester.pumpWidget(wrap(RrlRenderer(node: sampleRoot(), host: host)));
      expect(find.text('本文テキスト'), findsOneWidget); // RichText via default parser
      expect(find.byType(RasqPostTile), findsOneWidget); // L2 delegation
      expect(find.byType(RasqMediaGrid), findsOneWidget); // ForEach over $.post.media absorbed into media slot
      expect(find.byType(RasqActionBar), findsOneWidget);
      expect(find.text('12'), findsOneWidget); // renote count from $.actionStates[post.key]
      expect(find.text('注釈あり'), findsNothing); // If cw? with null cond
      expect(find.byIcon(Icons.repeat_on), findsOneWidget); // done state icon

      await tester.tap(find.byTooltip('返信'));
      expect(events.single.$2, 'tap');
      expect(events.single.$1, startsWith(instanceScope));
    });

    testWidgets('ジオメトリ登録簿 (D-072): role 付きノードの実物矩形が引ける', (tester) async {
      final geometry = RrlGeometryRegistry();
      final host = RrlHost(instanceScope: instanceScope, scope: RrlScope(hostData()), geometry: geometry);
      await tester.pumpWidget(wrap(RrlRenderer(node: sampleRoot(), host: host)));

      // role 指定でも nodeId 指定でも現在の矩形が取れる(グローバル座標)。
      final byRole = geometry.lookup(role: 'actionBar');
      expect(byRole, isNotNull);
      expect(byRole!.width, greaterThan(0));
      final byId = geometry.lookup(nodeId: '$instanceScope:actions');
      expect(byId, byRole);
      expect(geometry.lookup(role: 'threadNav'), isNull); // 無い role は null

      // アンマウントで登録が消える。
      await tester.pumpWidget(wrap(const SizedBox()));
      expect(geometry.lookup(role: 'actionBar'), isNull);
    });

    testWidgets('If cw? shows the annotation when bound truthy', (tester) async {
      final host = RrlHost(instanceScope: instanceScope, scope: RrlScope(hostData(withCw: true)));
      await tester.pumpWidget(wrap(RrlRenderer(node: sampleRoot(), host: host)));
      expect(find.text('注釈あり'), findsOneWidget);
    });
  });

  group('L1 / L3', () {
    testWidgets('Text, Row/Column, Icon, Spacer, If false, unsupported box', (tester) async {
      const node = RrlNode(t: 'Column', k: 'root', c: [
        RrlNode(t: 'Text', p: {'text': 'こんにちは'}),
        RrlNode(t: 'Row', c: [RrlNode(t: 'Icon', p: {'icon': 'star'}), RrlNode(t: 'Spacer', p: {'size': 4}), RrlNode(t: 'Text', p: {'text': r'$.missing'})]),
        RrlNode(t: 'If', p: {'cond': false}, c: [RrlNode(t: 'Text', p: {'text': '見えない'})]),
        RrlNode(t: 'VCCard', k: 'vc'),
      ]);
      final host = RrlHost(instanceScope: instanceScope, scope: RrlScope({}));
      await tester.pumpWidget(wrap(RrlRenderer(node: node, host: host)));
      expect(find.text('こんにちは'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('見えない'), findsNothing);
      expect(find.textContaining('unsupported component: VCCard'), findsOneWidget);
    });

    testWidgets('ForEach pushes item/index scope and key templates resolve', (tester) async {
      final events = <String>[];
      const node = RrlNode(t: 'ForEach', k: 'list', p: {'in': r'$.users'}, c: [
        RrlNode(t: 'Text', k: 'u-{{item.id}}', p: {'text': r'$.item.name'}, on: {'tap': 'openUser'}),
      ]);
      final host = RrlHost(
        instanceScope: instanceScope,
        scope: RrlScope({
          'users': [
            {'id': '1', 'name': 'ダグラス'},
            {'id': '2', 'name': 'TiVard'},
          ],
        }),
        onEvent: (nodeId, kind, {fn, payload = const {}}) => events.add(nodeId),
      );
      await tester.pumpWidget(wrap(RrlRenderer(node: node, host: host)));
      expect(find.text('ダグラス'), findsOneWidget);
      expect(find.text('TiVard'), findsOneWidget);
      await tester.tap(find.text('TiVard'));
      expect(events.single, '$instanceScope:u-2'); // ForEach はアイテムIDを key にする
    });

    testWidgets('Bind introduces a named value; Slot pulls host widgets', (tester) async {
      const node = RrlNode(t: 'Column', c: [
        RrlNode(t: 'Bind', p: {'name': 'title', 'value': r'$.deep.title'}, c: [
          RrlNode(t: 'Text', p: {'text': r'$.title'}),
        ]),
        RrlNode(t: 'Slot', p: {'name': 'ad'}),
      ]);
      final host = RrlHost(
        instanceScope: instanceScope,
        scope: RrlScope({'deep': {'title': 'バインド済み'}}),
        slots: const {'ad': Text('AdSlot はホスト側')},
      );
      await tester.pumpWidget(wrap(RrlRenderer(node: node, host: host)));
      expect(find.text('バインド済み'), findsOneWidget);
      expect(find.text('AdSlot はホスト側'), findsOneWidget);
    });

    testWidgets('Call invokes a registered component with props', (tester) async {
      const node = RrlNode(t: 'Call', p: {'component': 'SectionHeader', 'title': 'セクション'});
      final host = RrlHost(instanceScope: instanceScope, scope: RrlScope({}));
      await tester.pumpWidget(wrap(RrlRenderer(node: node, host: host)));
      expect(find.text('セクション'), findsOneWidget);
    });

    testWidgets('設定タイル (D-031): Switch/Slider/Radio が Bind 値を描画し change を発火する', (tester) async {
      final events = <(String, Object?)>[];
      const root = RrlNode(t: 'Column', c: [
        RrlNode(t: 'SectionHeader', p: {'title': '表示'}),
        RrlNode(t: 'SwitchListTile', k: 'reduceMotion', p: {'title': 'モーションを抑制する', 'value': r'$.settings.reduceMotion'}, on: {'change': 'settings.set'}),
        RrlNode(t: 'SliderListTile', k: 'textScale', p: {'title': '文字の大きさ', 'value': r'$.settings.textScale', 'min': 85, 'max': 130, 'divisions': 9, 'unit': '%'}, on: {'change': 'settings.set'}),
        RrlNode(t: 'RadioListTile', k: 'themeDark', p: {'title': 'ダーク', 'value': 'dark', 'group': r'$.settings.theme'}, on: {'change': 'settings.set'}),
        RrlNode(t: 'ValueListTile', k: 'lang', p: {'title': '言語', 'value': '日本語'}),
        RrlNode(t: 'DestructiveListTile', k: 'reset', p: {'title': 'リセット'}, on: {'tap': 'settings.reset'}),
      ]);
      final host = RrlHost(
        instanceScope: instanceScope,
        scope: RrlScope({
          'settings': {'reduceMotion': false, 'textScale': 100, 'theme': 'light'},
        }),
        onEvent: (nodeId, kind, {fn, payload = const {}}) => events.add(('${nodeId.split(':').last}/$kind/$fn', payload['value'])),
      );
      await tester.pumpWidget(wrap(RrlRenderer(node: root, host: host)));
      expect(find.text('モーションを抑制する'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      expect(events.single, ('reduceMotion/change/settings.set', true));

      events.clear();
      await tester.tap(find.text('ダーク'));
      expect(events.single, ('themeDark/change/settings.set', 'dark'));

      events.clear();
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(80, 0));
      expect(events, isNotEmpty);
      expect(events.last.$1, 'textScale/change/settings.set');
      expect(events.last.$2, isA<num>());
    });

    testWidgets('patch → re-render updates the tree', (tester) async {
      var doc = const RrlDocument(scope: instanceScope, rev: 1, root: RrlNode(t: 'Text', k: 'msg', p: {'text': '古い'}));
      final host = RrlHost(instanceScope: instanceScope, scope: RrlScope({}));
      await tester.pumpWidget(wrap(StatefulBuilder(builder: (context, setState) => RrlRenderer(node: doc.root, host: host))));
      expect(find.text('古い'), findsOneWidget);
      doc = doc.applyPatch({
        'type': 'patch', 'rev': 2, 'baseRev': 1,
        'ops': [
          {'op': 'setProp', 'target': '$instanceScope:msg', 'prop': 'text', 'value': '新しい'},
        ],
      });
      await tester.pumpWidget(wrap(RrlRenderer(node: doc.root, host: host)));
      expect(find.text('新しい'), findsOneWidget);
      expect(find.text('古い'), findsNothing);
    });
  });
}
