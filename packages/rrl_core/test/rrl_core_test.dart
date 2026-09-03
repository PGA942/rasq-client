import 'dart:convert';
import 'dart:io';

import 'package:rrl_core/rrl_core.dart';
import 'package:test/test.dart';

const scope = 'rasq.official.misskey:misskey:misskey.io:yamada:0.1.0:tl-home';

void main() {
  group('RrlNode', () {
    test('parses the post-tile snapshot example (rasq-sdk-sample)', () {
      final message = jsonDecode(File('test/fixtures/post_tile.rrl.json').readAsStringSync()) as Map<String, dynamic>;
      final doc = RrlDocument.fromSnapshot(message.cast<String, Object?>());
      expect(doc.rev, 1);
      expect(doc.root.t, 'PostTile');
      expect(doc.root.role, 'contentBody');
      expect(doc.root.layer, RrlLayer.l2Standard);
      final body = doc.root.findByKey('body')!;
      expect(body.tag, 'main_text');
      expect(body.p['source'], r'$.post.bodyRSL');
      expect(doc.root.findByKey('actions')!.role, 'actionBar');
      expect(doc.root.containsTag('vote'), isTrue);
      // Round-trips through JSON.
      expect(RrlNode.fromJson(doc.root.toJson()).toJson(), doc.root.toJson());
    });

    test('layers', () {
      expect(const RrlNode(t: 'Row').layer, RrlLayer.l1Primitive);
      expect(const RrlNode(t: 'ForEach').layer, RrlLayer.l3Control);
      expect(const RrlNode(t: 'PostTile').layer, RrlLayer.l2Standard);
      expect(const RrlNode(t: 'Nope').layer, RrlLayer.unknown);
    });

    test('V11 タグ検証 (D-086): 装飾/構造ノードのタグは取り込み時に剥がれる', () {
      final doc = RrlDocument.fromSnapshot({
        'schema': 'rasq.boundary/1',
        'scope': 's',
        'type': 'snapshot',
        'rev': 1,
        'root': {
          't': 'Column', 'k': 'root', 'tag': 'main_text', // 構造ノード → 剥がす
          'c': [
            {'t': 'RichText', 'k': 'body', 'tag': 'main_text', 'p': {'source': 'x'}}, // 内容ノード → 残す
            {'t': 'Icon', 'k': 'deco', 'tag': 'pic', 'p': {'icon': 'star'}}, // 装飾 → 剥がす
            {'t': 'Image', 'k': 'img', 'tag': 'pic', 'p': {'src': 'https://x/1.png'}}, // メディア → 残す
            {'t': 'ActionBar', 'k': 'bar', 'tag': 'reaction', 'role': 'actionBar', 'p': {}},
          ],
        },
      });
      expect(doc.root.tag, isNull);
      expect(doc.root.findByKey('body')!.tag, 'main_text');
      expect(doc.root.findByKey('deco')!.tag, isNull);
      expect(doc.root.findByKey('img')!.tag, 'pic');
      expect(doc.root.findByKey('bar')!.tag, isNull);
      expect(doc.root.findByKey('bar')!.role, 'actionBar'); // role は対象外
    });

    test('RrlNodeId splits instanceScope and key at the last colon', () {
      final id = RrlNodeId.parse('$scope:post-sample-1');
      expect(id.instanceScope, scope);
      expect(id.key, 'post-sample-1');
      expect(() => RrlNodeId.parse('nocolon'), throwsFormatException);
    });
  });

  group('RrlScope', () {
    final root = RrlScope({
      'post': {
        'id': 'p1',
        'key': 'misskey:misskey.io:yamada:p1',
        'author': {'displayName': 'タロ', 'handle': 'yamada'},
        'media': [
          {'id': 'm1', 'url': 'https://example.invalid/1.png'},
        ],
      },
      'actionStates': {
        'misskey:misskey.io:yamada:p1': {'renote': true},
      },
    });

    test('dot paths, indexes, dynamic keys', () {
      expect(root.resolve(r'$.post.author.displayName'), 'タロ');
      expect(root.resolve(r'$.post.media[0].id'), 'm1');
      expect(root.resolve(r'$.actionStates[post.key]'), {'renote': true});
      expect(root.resolve(r'$.post.nothing'), isNull);
      expect(root.resolve(r'$.post.media[9]'), isNull);
    });

    test('scope chaining (ForEach item) and templates', () {
      final item = root.push({'item': {'id': 'm1'}, 'index': 0});
      expect(item.resolve(r'$.item.id'), 'm1');
      expect(item.resolve(r'$.post.id'), 'p1'); // falls through to parent
      expect(item.resolveTemplate('tile-{{item.id}}-{{index}}'), 'tile-m1-0');
      expect(root.resolveTemplate('post-{{post.id}}'), 'post-p1');
    });

    test('resolveProp passes literals through', () {
      expect(root.resolveProp('hello'), 'hello');
      expect(root.resolveProp(42), 42);
      expect(root.resolveProp(r'$.post.id'), 'p1');
    });
  });

  group('RrlDocument.applyPatch', () {
    RrlDocument doc() => RrlDocument(
          scope: scope,
          rev: 1,
          root: const RrlNode(t: 'Column', k: 'root', c: [
            RrlNode(t: 'Text', k: 'a', p: {'text': 'A'}),
            RrlNode(t: 'Text', k: 'b', p: {'text': 'B'}),
          ]),
        );

    Map<String, Object?> patch(List<Map<String, Object?>> ops, {int rev = 2, int baseRev = 1}) =>
        {'schema': 'rasq.boundary/1', 'scope': scope, 'type': 'patch', 'rev': rev, 'baseRev': baseRev, 'ops': ops};

    test('setProp / insert / remove / move / replaceSubtree', () {
      var d = doc().applyPatch(patch([
        {'op': 'setProp', 'target': '$scope:a', 'prop': 'text', 'value': 'A2'},
        {'op': 'insert', 'target': '$scope:root', 'index': 0, 'node': {'t': 'Text', 'k': 'c', 'p': {'text': 'C'}}},
      ]));
      expect(d.rev, 2);
      expect(d.root.findByKey('a')!.p['text'], 'A2');
      expect(d.root.c.first.k, 'c');

      d = d.applyPatch(patch([
        {'op': 'move', 'target': '$scope:c', 'index': 2},
        {'op': 'remove', 'target': '$scope:b'},
        {'op': 'replaceSubtree', 'target': '$scope:a', 'node': {'t': 'Icon', 'k': 'a', 'p': {'icon': 'star'}}},
      ], rev: 3, baseRev: 2));
      expect([for (final n in d.root.c) n.k], ['a', 'c']);
      expect(d.root.findByKey('a')!.t, 'Icon');
    });

    test('rev mismatch throws and leaves the document untouched (V10 → resync)', () {
      final d = doc();
      expect(() => d.applyPatch(patch([], baseRev: 7)), throwsA(isA<RrlRevMismatchException>()));
      expect(d.rev, 1);
    });

    test('bad target throws RrlPatchException atomically', () {
      final d = doc();
      expect(
        () => d.applyPatch(patch([
          {'op': 'setProp', 'target': '$scope:a', 'prop': 'text', 'value': 'A2'},
          {'op': 'remove', 'target': '$scope:missing'},
        ])),
        throwsA(isA<RrlPatchException>()),
      );
      expect(d.root.findByKey('a')!.p['text'], 'A'); // first op not committed
    });

    test('original snapshot patch example applies (reactionCount)', () {
      final message = jsonDecode(File('test/fixtures/post_tile.rrl.json').readAsStringSync()) as Map<String, dynamic>;
      final d = RrlDocument.fromSnapshot(message.cast<String, Object?>());
      final rootKey = d.root.k!; // "post-{{id}}" — the wire form keeps the template as the key
      final patched = d.applyPatch({
        'schema': 'rasq.boundary/1',
        'scope': d.scope,
        'type': 'patch',
        'rev': 2,
        'baseRev': 1,
        'ops': [
          {'op': 'setProp', 'target': '${d.scope}:$rootKey', 'prop': 'reactionCount', 'value': 1},
        ],
      });
      expect(patched.root.p['reactionCount'], 1);
    });
  });
}
