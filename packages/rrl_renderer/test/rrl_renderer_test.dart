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

  // 展開の予算 (セキュリティ確認 2026-10-09 の [4])。
  group('expansion budget', () {
    final items = [for (var i = 0; i < 100; i++) i];
    // 100 項目の ForEach を 5 段(JSON は小さいが 100^5 の葉)。
    RrlNode nested(int levels) => levels == 0
        ? const RrlNode(t: 'Text', k: 'leaf', p: {'text': '葉'})
        : RrlNode(t: 'ForEach', p: {'in': items}, c: [nested(levels - 1)]);

    test('counts the whole tree under one shared budget', () {
      final scope = RrlScope({});
      expect(rrlExpansionOverBudget(nested(5), scope), contains('too many'));
      expect(rrlExpansionOverBudget(nested(1), scope), isNull);
      // 1 段なら収まる大きさでも、入れ子にすると積で超える。
      expect(rrlExpansionOverBudget(nested(2), scope, const RrlBudget(maxNodes: 5000)), contains('too many nodes'));
      // 子の無い ForEach も繰り返しを数える。
      expect(rrlExpansionOverBudget(RrlNode(t: 'ForEach', p: {'in': List.filled(20000, 0)}), scope), contains('too many iterations'));
      // Bind 越しのリストも同じ規則で数える。偽の If の中は数えない。
      final bound = RrlNode(t: 'Bind', p: {'name': 'xs', 'value': items}, c: [RrlNode(t: 'ForEach', p: {'in': r'$.xs'}, c: [nested(1)])]);
      expect(rrlExpansionOverBudget(bound, scope, const RrlBudget(maxNodes: 5000)), contains('too many nodes'));
      expect(rrlExpansionOverBudget(RrlNode(t: 'If', p: {'cond': false}, c: [nested(5)]), scope), isNull);
      // 深すぎる木。
      var deep = const RrlNode(t: 'Text', p: {'text': 'x'});
      for (var i = 0; i < 100; i++) {
        deep = RrlNode(t: 'Column', c: [deep]);
      }
      expect(rrlExpansionOverBudget(deep, scope), contains('too deep'));
    });

    testWidgets('over-budget trees are not built; normal iteration still renders', (tester) async {
      final host = RrlHost(instanceScope: instanceScope, scope: RrlScope({'rows': items}));
      await tester.pumpWidget(wrap(RrlRenderer(node: nested(5), host: host)));
      expect(find.text('葉'), findsNothing);
      expect(find.textContaining('not rendered'), findsOneWidget);

      await tester.pumpWidget(wrap(SingleChildScrollView(
        child: RrlRenderer(
          node: const RrlNode(t: 'ForEach', p: {'in': r'$.rows'}, c: [RrlNode(t: 'Text', k: 'row', p: {'text': r'$.item'})]),
          host: host,
        ),
      )));
      expect(find.textContaining('not rendered'), findsNothing);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('SVG / Grid の縦横比 (契約 v0.22、D-465)', () {
    String svgUri(String svg) => 'data:image/svg+xml;base64,${base64.encode(utf8.encode(svg))}';
    RrlHost host() => RrlHost(instanceScope: instanceScope, scope: RrlScope(const {}));

    testWidgets('Grid.p.aspectRatio: 3:4 の縦長のマス、外れた値は正方形', (tester) async {
      final cell = svgUri('<svg viewBox="0 0 300 400"><path d="M0 0L300 400" stroke="#000"/></svg>');
      RrlNode grid(Object? ratio) => RrlNode(t: 'Grid', p: {'columns': 2, 'aspectRatio': ratio}, c: [
            for (var i = 0; i < 4; i++) RrlNode(t: 'Image', k: 'c$i', p: {'src': cell}),
          ]);
      await tester.pumpWidget(wrap(RrlRenderer(node: grid(0.75), host: host())));
      final w = (400 - RasqSpacing.mediaGap) / 2;
      expect(find.byType(SvgLiteView), findsNWidgets(4));
      expect(tester.getSize(find.byType(SvgLiteView).first), Size(w, w / 0.75));
      for (final bad in [0.05, 11, 'x', null]) {
        await tester.pumpWidget(wrap(RrlRenderer(node: grid(bad), host: host())));
        expect(tester.getSize(find.byType(SvgLiteView).first), Size(w, w), reason: '$bad');
      }
    });

    testWidgets('Image の data:image/svg+xml は SvgLiteView で描く(fit / 大きさ)、読めなければ ⚠', (tester) async {
      final svg = '<svg viewBox="0 0 300 400"><circle cx="150" cy="200" r="100" fill="red"/></svg>';
      await tester.pumpWidget(wrap(RrlRenderer(node: RrlNode(t: 'Column', c: [
        RrlNode(t: 'Image', k: 'a', p: {'src': svgUri(svg)}),
        RrlNode(t: 'Image', k: 'b', p: {'src': 'data:image/svg+xml,${Uri.encodeComponent(svg)}', 'width': 60, 'height': 60, 'fit': 'cover'}),
        const RrlNode(t: 'Image', k: 'c', p: {'src': 'data:image/svg+xml;base64,PGh0bWw+'}),
      ]), host: host())));
      final views = tester.widgetList<SvgLiteView>(find.byType(SvgLiteView)).toList();
      expect(views, hasLength(2));
      // 大きさの指定が無ければ親の幅に合わせ、viewBox の縦横比で高さ。
      expect(tester.getSize(find.byWidget(views[0])), const Size(400, 400 * 4 / 3));
      expect(views[0].fit, BoxFit.contain);
      expect(views[1].fit, BoxFit.cover);
      expect(tester.getSize(find.byWidget(views[1])), const Size(60, 60));
      expect(find.text('⚠ bad svg'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('悪意のある SVG: 捨てた部分は描かず、残りだけ描く', (tester) async {
      const svg = '<svg viewBox="0 0 10 10" onload="alert(1)">'
          '<script>alert(1)</script>'
          '<foreignObject><path d="M0 0L5 5"/></foreignObject>'
          '<image href="https://evil.invalid/a.png"/>'
          '<use href="#p"/>'
          '<path id="p" d="M0 0L10 10" stroke="#ff0000" onclick="x()" style="fill:url(https://evil.invalid/)"/>'
          '</svg>';
      await tester.pumpWidget(wrap(RrlRenderer(node: RrlNode(t: 'Image', p: {'src': svgUri(svg), 'width': 50, 'height': 50}), host: host())));
      final view = tester.widget<SvgLiteView>(find.byType(SvgLiteView));
      expect(view.doc.shapes, hasLength(1));
      expect(view.doc.shapes.single.stroke, const Color(0xFFFF0000));
      final out = view.doc.toSvg();
      for (final bad in ['script', 'onload', 'onclick', 'href', 'style', 'evil', 'foreignObject']) {
        expect(out, isNot(contains(bad)), reason: bad);
      }
      expect(find.byType(Image), findsNothing); // 外の画像は読まない
    });
  });
}
