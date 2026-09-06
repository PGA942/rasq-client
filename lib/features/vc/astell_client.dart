import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;

import 'package:rasq_models/rasq_models.dart';

import '../../backend/orgate_client.dart';
import 'astell_models.dart';

/// AsTell の境界 (D-139)。RASQ Central の `/astell/*`(`rasq-central/docs/API.md`
/// §3)と同形。Central 未接続ならモックへ縮退する(ストアと同じ作法)。
abstract class AstellClient {
  Future<AstellHome> home();
  Future<AstellRoom?> room(String id);
  Future<List<AstellPeer>> peers(String id);
  Future<AstellRoom> createRoom(NewAstellRoom req);
  Future<AstellRoom> updateRoom(String id, Map<String, Object?> patch);
  Future<void> closeRoom(String id);
  Future<List<AstellShare>> shares(String id);
  Future<void> deleteShare(String roomId, String shareId);
  Future<List<AstellTranscript>> transcripts(String id);

  /// シグナリング WebSocket。welcome / peer-joined / share / transcript … を
  /// そのまま JSON で流す。
  Future<AstellConnection> connect(String roomId);
}

/// ルームへの接続 1 本。
abstract class AstellConnection {
  Stream<Map<String, Object?>> get messages;
  void send(Map<String, Object?> message);
  Future<void> close();
}

// ── モック ────────────────────────────────────────────────────────

/// ワイヤーフレーム p.3 のダミー(ダグラス「打ち上げの打ち上げ」ほか)。
class MockAstellClient implements AstellClient {
  MockAstellClient() {
    _rooms.addAll(seededRooms());
    _shares['r-spacequant'] = seededShares('r-spacequant');
  }

  /// 動画つき FOW のダミー (D-144): 画像はコンポーネントカタログと同じ picsum を流用。
  static List<AstellShare> seededShares(String roomId) => switch (roomId) {
        'r-spacequant' => [
            AstellShare(
              id: 'sq-post',
              accountId: 'spacequant',
              handle: 'spacequant',
              displayName: 'SpaceQuant',
              kind: 'post',
              payload: const {
                'author': 'SpaceQuant Barbados',
                'avatarUrl': 'https://picsum.photos/seed/spacequant/200',
                'body': 'Barbados III has been successfully placed into Earth orbit. Good job @Stratolaunch',
              },
              createdAt: DateTime(2026, 9, 6, 18, 5),
            ),
            AstellShare(
              id: 'sq-video',
              accountId: 'spacequant',
              handle: 'spacequant',
              displayName: 'SpaceQuant',
              kind: 'media',
              payload: const {
                'title': 'Barbados III 打ち上げ映像',
                'mimeType': 'video/mp4',
                'url': 'https://picsum.photos/seed/rrl1/600/400',
                'thumbnailUrl': 'https://picsum.photos/seed/rrl1/600/400',
                'durationMs': 95000,
              },
              createdAt: DateTime(2026, 9, 6, 18, 12),
            ),
          ],
        _ => const [],
      };

  final List<AstellRoom> _rooms = [];
  final Map<String, List<AstellShare>> _shares = {};

  static const _me = AstellPeer(peerId: 'me', accountId: 'me', handle: 'me', displayName: 'あなた', micOn: false);

  static List<AstellRoom> seededRooms() => [
        AstellRoom(
          id: 'r-launch',
          ownerId: 'douglas',
          ownerHandle: 'douglas',
          ownerDisplayName: 'ダグラス',
          title: '打ち上げの打ち上げ',
          description: '打ち上げ成功、おめでとう!後援会(?)のみんなでお酒スクエアしています。山ハヤくんはダグラスのおごり!(?)',
          genres: const ['#打上会', 'スペースライフ', '宇宙', 'ロケット発射', '発射', 'バルバトスIII', '周回軌道'],
          createdAt: DateTime(2026, 9, 6, 20),
          peerCount: 5,
        ),
        AstellRoom(
          id: 'r-surprise',
          ownerId: 'yomogi',
          ownerHandle: 'yomogimochi',
          ownerDisplayName: 'よもぎもち',
          title: 'サプライズ',
          createdAt: DateTime(2026, 9, 6, 19, 30),
          peerCount: 2,
        ),
        AstellRoom(
          id: 'r-spacequant',
          ownerId: 'spacequant',
          ownerHandle: 'spacequant',
          ownerDisplayName: 'SpaceQuant',
          title: 'Launch LIVE',
          description: 'バルバトスIIIロケット、発進!技術者たちがロケットの状態を議論しています。',
          genres: const ['発射', 'バルバトスIII', '周回軌道'],
          createdAt: DateTime(2026, 9, 6, 18),
          peerCount: 2500,
          live: true,
          thumbnailUrl: Uri.parse('https://picsum.photos/seed/rrl1/600/400'),
        ),
        AstellRoom(
          id: 'r-sublrony',
          ownerId: 'sublrony',
          ownerHandle: 'sublrony',
          ownerDisplayName: 'Sublrony',
          title: 'Create Game',
          createdAt: DateTime(2026, 9, 6, 17),
          peerCount: 2,
          live: true,
          thumbnailUrl: Uri.parse('https://picsum.photos/seed/rrl2/600/400'),
        ),
      ];

  static List<AstellPeer> seededPeers(String roomId) => switch (roomId) {
        'r-launch' => const [
            AstellPeer(peerId: 'p1', accountId: 'douglas', handle: 'douglas', displayName: 'ダグラス', micOn: true),
            AstellPeer(peerId: 'p2', accountId: 'tivard', handle: 'tivard', displayName: 'TiVard', micOn: true),
            AstellPeer(peerId: 'p3', accountId: 'yamahaya', handle: 'yamahaya', displayName: '山ハヤ'),
            AstellPeer(peerId: 'p4', accountId: 'a4', handle: 'a4', displayName: 'ゲスト A'),
            AstellPeer(peerId: 'p5', accountId: 'a5', handle: 'a5', displayName: 'ゲスト B'),
          ],
        _ => const [AstellPeer(peerId: 'p1', accountId: 'host', handle: 'host', displayName: 'ホスト', micOn: true)],
      };

  @override
  Future<AstellHome> home() async {
    final open = [for (final r in _rooms) if (r.isOpen && r.visibility == 'public') r];
    final trending = [...open]..sort((a, b) => b.peerCount.compareTo(a.peerCount));
    return AstellHome(recommended: open.take(10).toList(), trending: trending.take(10).toList(), following: const []);
  }

  @override
  Future<AstellRoom?> room(String id) async => _rooms.where((r) => r.id == id).firstOrNull;

  @override
  Future<List<AstellPeer>> peers(String id) async => seededPeers(id);

  @override
  Future<AstellRoom> createRoom(NewAstellRoom req) async {
    final room = AstellRoom(
      id: 'mock-${DateTime.now().microsecondsSinceEpoch}',
      ownerId: 'me',
      ownerHandle: 'me',
      ownerDisplayName: 'あなた',
      title: req.title,
      description: req.description,
      genres: req.genres,
      visibility: req.visibility,
      welcomeMessage: req.welcomeMessage,
      showSummary: req.showSummary,
      autoGenre: req.autoGenre,
      createdAt: DateTime.now(),
    );
    _rooms.insert(0, room);
    return room;
  }

  @override
  Future<AstellRoom> updateRoom(String id, Map<String, Object?> patch) async {
    final i = _rooms.indexWhere((r) => r.id == id);
    if (i < 0) throw StateError('no such room');
    final r = _rooms[i].copyWith(
      title: patch['title'] as String?,
      description: patch['description'] as String?,
      genres: (patch['genres'] as List?)?.cast<String>(),
      showSummary: patch['showSummary'] as bool?,
      autoGenre: patch['autoGenre'] as bool?,
    );
    _rooms[i] = r;
    return r;
  }

  @override
  Future<void> closeRoom(String id) async => _rooms.removeWhere((r) => r.id == id);

  @override
  Future<List<AstellShare>> shares(String id) async => _shares[id] ?? const [];

  @override
  Future<void> deleteShare(String roomId, String shareId) async {
    _shares[roomId]?.removeWhere((s) => s.id == shareId);
    for (final c in _connections.where((c) => c.roomId == roomId)) {
      c._controller.add({'type': 'share-removed', 'shareId': shareId});
    }
  }

  final List<_MockConnection> _connections = [];

  @override
  Future<List<AstellTranscript>> transcripts(String id) async => const [];

  @override
  Future<AstellConnection> connect(String roomId) async {
    final c = _MockConnection(this, roomId);
    _connections.add(c);
    return c;
  }
}

class _MockConnection implements AstellConnection {
  _MockConnection(this.client, this.roomId) {
    // welcome は購読が始まってから流す(broadcast は購読前のイベントを捨てる)。
    _controller = StreamController<Map<String, Object?>>.broadcast(onListen: () {
      final peers = MockAstellClient.seededPeers(roomId);
      _controller.add({
        'type': 'welcome',
        'peerId': MockAstellClient._me.peerId,
        'peers': [for (final p in peers) _peerJson(p)],
        'shares': [for (final s in client._shares[roomId] ?? const <AstellShare>[]) _shareJson(s)],
        'transcripts': const [],
      });
    });
  }
  final MockAstellClient client;
  final String roomId;
  late final StreamController<Map<String, Object?>> _controller;
  var _n = 0;

  static Map<String, Object?> _peerJson(AstellPeer p) => {'peerId': p.peerId, 'accountId': p.accountId, 'handle': p.handle, 'displayName': p.displayName, 'micOn': p.micOn};
  static Map<String, Object?> _shareJson(AstellShare s) => {'id': s.id, 'accountId': s.accountId, 'handle': s.handle, 'displayName': s.displayName, 'kind': s.kind, 'payload': s.payload, 'createdAt': s.createdAt.toIso8601String()};

  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;

  @override
  void send(Map<String, Object?> message) {
    switch (message['type']) {
      case 'ping':
        _controller.add({'type': 'pong'});
      case 'share':
        final share = AstellShare(
          id: 'ms-${_n++}',
          accountId: 'me',
          handle: 'me',
          displayName: 'あなた',
          kind: message['kind'] as String? ?? 'text',
          payload: (message['payload'] as Map?)?.cast<String, Object?>() ?? const {},
          createdAt: DateTime.now(),
        );
        (client._shares[roomId] ??= []).add(share);
        _controller.add({'type': 'share', 'share': _shareJson(share)});
      default:
        break;
    }
  }

  @override
  Future<void> close() {
    client._connections.remove(this);
    return _controller.close();
  }
}

// ── RASQ Central ──────────────────────────────────────────────────

class HttpAstellClient implements AstellClient {
  HttpAstellClient(this._client, {required this.baseUrl, required this.token});
  final OrgateClient _client;
  final Uri baseUrl;
  final String? Function() token;

  List<T> _list<T>(Object? v, T Function(Map<String, Object?>) f) => [for (final e in (v as List? ?? const [])) if (e is Map) f(e.cast<String, Object?>())];

  @override
  Future<AstellHome> home() async => AstellHome.fromJson(await _client.getJson('/astell/home'));

  @override
  Future<AstellRoom?> room(String id) async {
    try {
      return AstellRoom.fromJson(await _client.getJson('/astell/rooms/${Uri.encodeComponent(id)}'));
    } on OrgateException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  @override
  Future<List<AstellPeer>> peers(String id) async => _list(await _client.getList('/astell/rooms/${Uri.encodeComponent(id)}/peers'), AstellPeer.fromJson);

  @override
  Future<AstellRoom> createRoom(NewAstellRoom req) async => AstellRoom.fromJson(await _client.postJson('/astell/rooms', req.toJson()));

  @override
  Future<AstellRoom> updateRoom(String id, Map<String, Object?> patch) async => AstellRoom.fromJson(await _client.patchJson('/astell/rooms/${Uri.encodeComponent(id)}', patch));

  @override
  Future<void> closeRoom(String id) => _client.postJson('/astell/rooms/${Uri.encodeComponent(id)}/close', const {});

  @override
  Future<List<AstellShare>> shares(String id) async => _list(await _client.getList('/astell/rooms/${Uri.encodeComponent(id)}/shares'), AstellShare.fromJson);

  @override
  Future<void> deleteShare(String roomId, String shareId) => _client.delete('/astell/rooms/${Uri.encodeComponent(roomId)}/shares/${Uri.encodeComponent(shareId)}');

  @override
  Future<List<AstellTranscript>> transcripts(String id) async => _list(await _client.getList('/astell/rooms/${Uri.encodeComponent(id)}/transcripts'), AstellTranscript.fromJson);

  @override
  Future<AstellConnection> connect(String roomId) async {
    final t = token();
    if (t == null) throw StateError('RASQ アカウントのトークンがありません');
    // Bearer はクエリで渡す(API.md §3)。http → ws。
    final url = baseUrl.replace(
      scheme: baseUrl.scheme == 'https' ? 'wss' : 'ws',
      path: '${baseUrl.path}/api/v1/astell/rooms/${Uri.encodeComponent(roomId)}/ws',
      queryParameters: {'token': t},
    );
    final ws = await WebSocket.connect(url.toString());
    return _WsConnection(ws);
  }
}

class _WsConnection implements AstellConnection {
  _WsConnection(this._ws);
  final WebSocket _ws;

  @override
  Stream<Map<String, Object?>> get messages => _ws.map((e) {
        try {
          return (jsonDecode(e as String) as Map).cast<String, Object?>();
        } catch (_) {
          return <String, Object?>{'type': 'error', 'message': 'unreadable frame'};
        }
      });

  @override
  void send(Map<String, Object?> message) => _ws.add(jsonEncode(message));

  @override
  Future<void> close() => _ws.close();
}

/// 端末ローカル用: モックのピアと同じ [UserSummary] を作る補助(テスト/表示)。
UserSummary astellUser(AstellPeer p) => p.user;
