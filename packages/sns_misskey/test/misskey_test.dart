import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:sns_misskey/sns_misskey.dart';
import 'package:test/test.dart';

const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.test', handle: 'me');

Map<String, Object?> user(String id, {String? host}) => {'id': id, 'username': id, 'name': '名前$id', 'host': host, 'avatarUrl': 'https://a/$id.png'};

Map<String, Object?> note(String id, {String? text = 'hello :blobcat:', Map<String, Object?>? renote, List<Map<String, Object?>> files = const [], Object? poll, String? myReaction}) => {
      'id': id,
      'createdAt': '2026-08-22T00:00:00.000Z',
      'text': text,
      'user': user('u$id'),
      'renote': renote,
      'files': files,
      'fileIds': [for (final f in files) f['id']],
      'poll': poll,
      'reactions': {'👍': 2, ':blobcat:': 1},
      'myReaction': myReaction,
      'renoteCount': 3,
      'repliesCount': 1,
    };

void main() {
  group('mappers', () {
    test('note → Post with media, poll, counts', () {
      final p = MisskeyMappers.note(
        note('n1', files: [
          {'id': 'f1', 'type': 'image/png', 'url': 'https://f/1.png', 'isSensitive': true, 'properties': {'width': 16, 'height': 9}},
          {'id': 'f2', 'type': 'video/mp4', 'url': 'https://f/2.mp4'},
        ], poll: {
          'choices': [
            {'text': 'a', 'votes': 1, 'isVoted': true},
            {'text': 'b', 'votes': 0, 'isVoted': false},
          ],
          'multiple': false,
        }),
        viewer: viewer,
        host: 'misskey.test',
      );
      expect(p.author.account.instance, 'misskey.test'); // local user → viewer host
      expect(p.media.length, 2);
      expect(p.media.first.sensitive, isTrue);
      expect(p.media.first.aspectRatio, closeTo(16 / 9, 0.001));
      expect(p.media[1].type, MediaType.video);
      expect(p.poll!.votedIndices, {0});
      expect(p.counts['reaction'], 3);
      expect(p.counts['renote'], 3);
      expect(p.bodyFormat, 'mfm');
      expect(p.key, '${viewer.key}:n1');
    });

    test('pure renote → inner note with repostedBy; quote keeps outer text', () {
      final pure = MisskeyMappers.note(note('r1', text: null, renote: note('n2')), viewer: viewer, host: 'misskey.test');
      expect(pure.id, 'r1');
      expect(pure.body, 'hello :blobcat:');
      expect(pure.repostedBy!.displayName, '名前ur1');
      expect(pure.author.id, 'un2');

      final quote = MisskeyMappers.note(note('q1', text: 'QT!', renote: note('n3')), viewer: viewer, host: 'misskey.test');
      expect(quote.body, 'QT!');
      expect(quote.quote!.id, 'n3');
      expect(quote.repostedBy, isNull);
    });

    test('remote user keeps its own host', () {
      final u = MisskeyMappers.user(user('bob', host: 'other.example'), account: viewer, host: 'misskey.test');
      expect(u.account.instance, 'other.example');
      expect(u.handle, 'bob');
    });

    test('notification kinds', () {
      final n = MisskeyMappers.notification({'id': 'x', 'type': 'reaction', 'createdAt': '2026-08-22T00:00:00Z', 'user': user('a'), 'note': note('n9'), 'reaction': '👍'}, viewer: viewer, host: 'misskey.test');
      expect(n.kind, NotificationKind.reaction);
      expect(n.kind.tile, NotificationTileType.action);
      expect(n.actors.single.id, 'a');
      expect(n.post!.id, 'n9');
    });
  });

  group('MiAuth + session (mock http)', () {
    MockClient client(Map<String, Object? Function(Map<String, Object?> body)> routes) => MockClient((req) async {
          final path = req.url.path.replaceFirst('/api/', '');
          final body = req.body.isEmpty ? <String, Object?>{} : (jsonDecode(req.body) as Map).cast<String, Object?>();
          final h = routes[path];
          if (h == null) return http.Response(jsonEncode({'error': {'message': 'no route $path', 'code': 'NOT_FOUND'}}), 404);
          final r = h(body);
          return http.Response(jsonEncode(r), 200, headers: {'content-type': 'application/json'});
        });

    test('MiAuth url and check → AuthResult', () async {
      final c = client({
        'miauth/abc/check': (_) => {'ok': true, 'token': 'TOKEN', 'user': user('me')},
      });
      final plugin = MisskeyPlugin(client: c);
      final flow = await plugin.beginAuth('https://misskey.test/') as MiAuthFlow;
      expect(flow.host, 'misskey.test');
      expect(flow.url.host, 'misskey.test');
      expect(flow.url.queryParameters['permission'], contains('write:notes'));

      final flow2 = MiAuthFlow(host: 'misskey.test', pluginId: MisskeyPlugin.pluginId, permissions: const ['read:account'], sessionId: 'abc', client: c);
      final result = await flow2.complete();
      expect(result.session.token, 'TOKEN');
      expect(result.session.account.handle, 'me');
      expect(result.me.displayName, '名前me');
    });

    test('MiAuth not yet approved → 401 SnsApiException', () async {
      final c = client({'miauth/abc/check': (_) => {'ok': false}});
      final flow = MiAuthFlow(host: 'misskey.test', pluginId: 'p', permissions: const [], sessionId: 'abc', client: c);
      await expectLater(flow.complete(), throwsA(isA<SnsApiException>().having((e) => e.code.code, 'code', '401')));
    });

    test('timelineWithStates sends token & untilId, maps done flags', () async {
      late Map<String, Object?> seen;
      final c = client({
        'notes/timeline': (b) {
          seen = b;
          return [note('n1', myReaction: '👍'), note('n2')];
        },
        'notes/reactions/create': (_) => {},
        'notes/show': (_) => note('n2', myReaction: '👍'),
      });
      final s = MisskeySession(AccountSession(account: viewer, pluginId: MisskeyPlugin.pluginId, token: 'T', createdAt: DateTime(2026)), client: c);
      final (page, states) = await s.timelineWithStates(TimelineKind.home, cursor: 'c0', limit: 2);
      expect(seen['i'], 'T');
      expect(seen['untilId'], 'c0');
      expect(page.items.length, 2);
      expect(page.nextCursor, 'n2');
      expect(states['n1']!['reaction']!.done, isTrue);
      expect(states['n2']!['reaction']!.done, isFalse);

      final r = await s.performAction('reaction', 'n2');
      expect(r.done, isTrue);
      expect(r.count, 3);
    });

    test('http error → SnsApiException with HTTP code', () async {
      final c = MockClient((_) async => http.Response(jsonEncode({'error': {'message': 'Unauthorized', 'code': 'CREDENTIAL_REQUIRED'}}), 401));
      final api = MisskeyApi('misskey.test', client: c);
      await expectLater(api.call('i'), throwsA(isA<SnsApiException>().having((e) => e.code.display, 'display', 'Error:401 Unauthorized')));
    });
  });
}
