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

  /// チャットの 1 件を「共有」欄へ出す/外す (D-146)。
  Future<AstellShare> pinShare(String roomId, String shareId, bool pinned);
  Future<AstellTranscript> pinTranscript(String roomId, String transcriptId, bool pinned);

  /// モデレーション (D-149 / S-006)。付与・BAN はオーナー、キック・強制ミュートはモデレーター。
  Future<AstellRoom> setModerator(String roomId, String accountId, bool moderator);
  Future<void> kickPeer(String roomId, String peerId);
  Future<AstellPeer> mutePeer(String roomId, String peerId, bool muted);
  Future<List<AstellBan>> bans(String roomId);
  Future<List<AstellBan>> ban(String roomId, String accountId, {String? reason});
  Future<void> unban(String roomId, String accountId);

  /// RASQ アカウントのフォロー (S-006、参加ポリシーの判定に使う)。
  Future<Set<String>> following();
  Future<void> follow(String accountId, bool follow);

  /// 読み上げ (D-146): プリセット音声の一覧と、音声の合成(未設定なら例外)。
  Future<AstellTtsVoices> ttsVoices();
  Future<List<int>> speak(String roomId, String text, {String? voice});

  /// 共有コンテンツのアップロード (D-145)。[bytes] は [encoding] で圧縮済み
  /// (`zstd` or `identity`)。応答の `url` を共有の payload に載せる。
  Future<AstellAsset> uploadAsset(String roomId, List<int> bytes, {required String name, required String contentType, String encoding = 'identity'});
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

/// `GET /astell/tts/voices`。
class AstellTtsVoices {
  const AstellTtsVoices({required this.enabled, required this.model, required this.voices});
  final bool enabled;
  final String model;
  final List<({String id, String label})> voices;
  factory AstellTtsVoices.fromJson(Map<String, Object?> j) => AstellTtsVoices(
        enabled: j['enabled'] == true,
        model: j['model'] as String? ?? 'CosyVoice2-0.5B',
        voices: [for (final v in (j['voices'] as List? ?? const [])) if (v is Map) (id: v['id'] as String? ?? '', label: v['label'] as String? ?? v['id'] as String? ?? '')],
      );
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
          // あなたはこのルームのモデレーター (D-149 のデモ)。
          moderators: const ['me'],
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
          description: 'ゲーム制作の作業配信。エディタの画面を流しながら雑談中。',
          genres: const ['ゲーム制作', '作業配信'],
          createdAt: DateTime(2026, 9, 6, 17),
          peerCount: 2,
          live: true,
          thumbnailUrl: Uri.parse('https://picsum.photos/seed/rrl2/600/400'),
          // ホストが動画(作業画面の録画)を配信中のダミー (D-145)。
          hostStream: AstellHostStream(kind: 'video', title: 'エディタ作業 — 敵キャラのAI', thumbnailUrl: Uri.parse('https://picsum.photos/seed/rrl2/600/400'), startedAt: DateTime(2026, 9, 6, 17, 5)),
        ),
      ];

  /// ダミーの文字起こし(打ち上げの打ち上げ)。ワイヤーフレームの 3 行。
  static List<AstellTranscript> seededTranscripts(String roomId) => switch (roomId) {
        'r-launch' => [
            AstellTranscript(id: 't1', accountId: 'douglas', handle: 'douglas', displayName: 'ダグラス', text: 'いい感じに行ったねー', lang: 'ja', createdAt: DateTime(2026, 9, 6, 20, 3)),
            AstellTranscript(id: 't2', accountId: 'yamahaya', handle: 'yamahaya', displayName: '山ハヤ', text: '振動まわりだけちょい気がかり', lang: 'ja', createdAt: DateTime(2026, 9, 6, 20, 4)),
            AstellTranscript(id: 't3', accountId: 'douglas', handle: 'douglas', displayName: 'ダグラス', text: 'そうやねー分離の後エンジンのスタビライザー周りが', lang: 'ja', createdAt: DateTime(2026, 9, 6, 20, 5)),
          ],
        _ => const [],
      };

  static List<AstellPeer> seededPeers(String roomId) => switch (roomId) {
        'r-launch' => [
            const AstellPeer(peerId: 'p1', accountId: 'douglas', handle: 'douglas', displayName: 'ダグラス', micOn: true),
            // TiVard は画面共有中 (D-146 のデモ)。サムネイルはカタログの picsum。
            AstellPeer(peerId: 'p2', accountId: 'tivard', handle: 'tivard', displayName: 'TiVard', micOn: true, screenShare: AstellScreenShare(title: '打ち上げ映像(エディタ)', thumbnailUrl: Uri.parse('https://picsum.photos/seed/rrl1/600/400'))),
            const AstellPeer(peerId: 'p3', accountId: 'yamahaya', handle: 'yamahaya', displayName: '山ハヤ'),
            const AstellPeer(peerId: 'p4', accountId: 'a4', handle: 'a4', displayName: 'ゲスト A'),
            const AstellPeer(peerId: 'p5', accountId: 'a5', handle: 'a5', displayName: 'ゲスト B'),
          ],
        _ => const [AstellPeer(peerId: 'p1', accountId: 'douglas', handle: 'douglas', displayName: 'ダグラス', micOn: true)],
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
      joinPolicy: patch['joinPolicy'] as String?,
      sharePolicy: patch['sharePolicy'] as String?,
      ttsVoice: patch['ttsVoice'] as String?,
      clearTtsVoice: patch.containsKey('ttsVoice') && patch['ttsVoice'] == null,
    );
    _rooms[i] = r;
    _broadcast(id, {'type': 'room', 'room': _roomJson(r)});
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
  Future<AstellShare> pinShare(String roomId, String shareId, bool pinned) async {
    final list = _shares[roomId] ??= [];
    final i = list.indexWhere((s) => s.id == shareId);
    if (i < 0) throw StateError('no such share');
    final updated = list[i].copyWith(pinned: pinned);
    list[i] = updated;
    for (final c in _connections.where((c) => c.roomId == roomId)) {
      c._controller.add({'type': 'share', 'share': _MockConnection._shareJson(updated)});
    }
    return updated;
  }

  final Map<String, List<AstellTranscript>> _transcripts = {};

  @override
  Future<AstellTranscript> pinTranscript(String roomId, String transcriptId, bool pinned) async {
    final list = _transcripts[roomId] ??= [];
    final i = list.indexWhere((t) => t.id == transcriptId);
    if (i < 0) throw StateError('no such transcript');
    final updated = list[i].copyWith(pinned: pinned);
    list[i] = updated;
    for (final c in _connections.where((c) => c.roomId == roomId)) {
      c._controller.add({'type': 'transcript', 'transcript': _MockConnection._transcriptJson(updated)});
    }
    return updated;
  }

  // ── モデレーション (D-149) ──
  final Map<String, List<AstellBan>> _bans = {};
  final Map<String, Set<String>> _mutedByMod = {};
  final Map<String, Set<String>> _kicked = {};
  final Set<String> _following = {};

  void _broadcast(String roomId, Map<String, Object?> m) {
    for (final c in _connections.where((c) => c.roomId == roomId)) {
      c._controller.add(m);
    }
  }

  /// 接続中のピア(seed からキック済みを除く)。
  List<AstellPeer> _livePeers(String roomId) => [for (final p in seededPeers(roomId)) if (!(_kicked[roomId]?.contains(p.peerId) ?? false)) p];

  Map<String, Object?> _roomJson(AstellRoom r) => {
        'id': r.id, 'ownerId': r.ownerId, 'ownerHandle': r.ownerHandle, 'ownerDisplayName': r.ownerDisplayName, 'ownerAvatarUrl': r.ownerAvatarUrl?.toString(),
        'title': r.title, 'description': r.description, 'genres': r.genres, 'visibility': r.visibility, 'welcomeMessage': r.welcomeMessage,
        'showSummary': r.showSummary, 'autoGenre': r.autoGenre, 'createdAt': r.createdAt.toIso8601String(), 'peerCount': r.peerCount, 'live': r.live,
        'thumbnailUrl': r.thumbnailUrl?.toString(), 'hostStream': r.hostStream?.toJson(), 'ttsVoice': r.ttsVoice,
        'joinPolicy': r.joinPolicy, 'sharePolicy': r.sharePolicy, 'moderators': r.moderators,
      };

  @override
  Future<AstellRoom> setModerator(String roomId, String accountId, bool moderator) async {
    final i = _rooms.indexWhere((r) => r.id == roomId);
    if (i < 0) throw StateError('no such room');
    final mods = {..._rooms[i].moderators};
    if (moderator) {
      mods.add(accountId);
    } else {
      mods.remove(accountId);
    }
    _rooms[i] = _rooms[i].copyWith(moderators: mods.toList());
    _broadcast(roomId, {'type': 'room', 'room': _roomJson(_rooms[i])});
    return _rooms[i];
  }

  @override
  Future<void> kickPeer(String roomId, String peerId) async {
    (_kicked[roomId] ??= {}).add(peerId);
    _broadcast(roomId, {'type': 'peer-left', 'peerId': peerId});
  }

  @override
  Future<AstellPeer> mutePeer(String roomId, String peerId, bool muted) async {
    final p = _livePeers(roomId).where((p) => p.peerId == peerId).firstOrNull;
    if (p == null) throw StateError('no such peer');
    final set = _mutedByMod[roomId] ??= {};
    if (muted) {
      set.add(peerId);
    } else {
      set.remove(peerId);
    }
    final updated = p.copyWith(mutedByMod: muted, micOn: muted ? false : null);
    _broadcast(roomId, {'type': 'peer-state', 'peer': _MockConnection._peerJson(updated)});
    return updated;
  }

  @override
  Future<List<AstellBan>> bans(String roomId) async => List.unmodifiable(_bans[roomId] ?? const []);

  @override
  Future<List<AstellBan>> ban(String roomId, String accountId, {String? reason}) async {
    final list = _bans[roomId] ??= [];
    final p = seededPeers(roomId).where((p) => p.accountId == accountId).firstOrNull;
    if (!list.any((b) => b.accountId == accountId)) {
      list.insert(0, AstellBan(accountId: accountId, handle: p?.handle ?? accountId, displayName: p?.displayName ?? accountId, reason: reason, createdAt: DateTime.now()));
    }
    // モデレーターなら外し、接続中なら追い出す。
    final i = _rooms.indexWhere((r) => r.id == roomId);
    if (i >= 0 && _rooms[i].moderators.contains(accountId)) {
      _rooms[i] = _rooms[i].copyWith(moderators: [for (final m in _rooms[i].moderators) if (m != accountId) m]);
      _broadcast(roomId, {'type': 'room', 'room': _roomJson(_rooms[i])});
    }
    for (final peer in _livePeers(roomId).where((p) => p.accountId == accountId)) {
      await kickPeer(roomId, peer.peerId);
    }
    return List.unmodifiable(list);
  }

  @override
  Future<void> unban(String roomId, String accountId) async => _bans[roomId]?.removeWhere((b) => b.accountId == accountId);

  @override
  Future<Set<String>> following() async => {..._following};

  @override
  Future<void> follow(String accountId, bool follow) async {
    if (follow) {
      _following.add(accountId);
    } else {
      _following.remove(accountId);
    }
  }

  @override
  Future<AstellTtsVoices> ttsVoices() async => const AstellTtsVoices(enabled: false, model: 'CosyVoice2-0.5B', voices: [
        (id: 'ja_female_1', label: '女性 1(日本語)'),
        (id: 'ja_male_1', label: '男性 1(日本語)'),
        (id: 'en_female_1', label: 'Female 1 (English)'),
      ]);

  @override
  Future<List<int>> speak(String roomId, String text, {String? voice}) async => throw StateError('読み上げバックエンドが未設定です(CENTRAL_TTS_URL)');

  @override
  Future<AstellAsset> uploadAsset(String roomId, List<int> bytes, {required String name, required String contentType, String encoding = 'identity'}) async {
    // モックは実体を持たない — 名前と大きさだけ返す(URL は picsum のダミー)。
    return AstellAsset(id: 'mock-asset-${DateTime.now().microsecondsSinceEpoch}', url: Uri.parse('https://picsum.photos/seed/${Uri.encodeComponent(name)}/600/400'), name: name, contentType: contentType, sizeBytes: bytes.length);
  }

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
      final muted = client._mutedByMod[roomId] ?? const <String>{};
      final peers = [for (final p in client._livePeers(roomId)) muted.contains(p.peerId) ? p.copyWith(mutedByMod: true, micOn: false) : p];
      client._transcripts[roomId] ??= MockAstellClient.seededTranscripts(roomId);
      _controller.add({
        'type': 'welcome',
        'peerId': MockAstellClient._me.peerId,
        'accountId': MockAstellClient._me.accountId,
        'peers': [for (final p in peers) _peerJson(p)],
        'shares': [for (final s in client._shares[roomId] ?? const <AstellShare>[]) _shareJson(s)],
        'transcripts': [for (final t in client._transcripts[roomId] ?? const <AstellTranscript>[]) _transcriptJson(t)],
      });
    });
  }
  final MockAstellClient client;
  final String roomId;
  late final StreamController<Map<String, Object?>> _controller;
  var _n = 0;

  static Map<String, Object?> _peerJson(AstellPeer p) => {'peerId': p.peerId, 'accountId': p.accountId, 'handle': p.handle, 'displayName': p.displayName, 'state': {'micOn': p.micOn, 'screenShare': p.screenShare?.toJson(), 'mutedByMod': p.mutedByMod}};
  static Map<String, Object?> _shareJson(AstellShare s) => {'id': s.id, 'accountId': s.accountId, 'handle': s.handle, 'displayName': s.displayName, 'kind': s.kind, 'payload': s.payload, 'pinned': s.pinned, 'createdAt': s.createdAt.toIso8601String()};
  static Map<String, Object?> _transcriptJson(AstellTranscript t) => {'id': t.id, 'accountId': t.accountId, 'handle': t.handle, 'displayName': t.displayName, 'text': t.text, 'lang': t.lang, 'pinned': t.pinned, 'createdAt': t.createdAt.toIso8601String()};

  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;

  @override
  void send(Map<String, Object?> message) {
    switch (message['type']) {
      case 'ping':
        _controller.add({'type': 'pong'});
      case 'state':
        // 自分の状態をそのまま peer-state で返す(他のピアにも配った体)。
        final st = (message['state'] as Map?)?.cast<String, Object?>() ?? const {};
        _controller.add({'type': 'peer-state', 'peer': {'peerId': MockAstellClient._me.peerId, 'accountId': 'me', 'handle': 'me', 'displayName': 'あなた', 'state': st}});
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
  Future<AstellShare> pinShare(String roomId, String shareId, bool pinned) async =>
      AstellShare.fromJson(await _client.putJson('/astell/rooms/${Uri.encodeComponent(roomId)}/shares/${Uri.encodeComponent(shareId)}/pin', {'pinned': pinned}));

  @override
  Future<AstellTranscript> pinTranscript(String roomId, String transcriptId, bool pinned) async =>
      AstellTranscript.fromJson(await _client.putJson('/astell/rooms/${Uri.encodeComponent(roomId)}/transcripts/${Uri.encodeComponent(transcriptId)}/pin', {'pinned': pinned}));

  String _room(String id) => '/astell/rooms/${Uri.encodeComponent(id)}';

  @override
  Future<AstellRoom> setModerator(String roomId, String accountId, bool moderator) async {
    final path = '${_room(roomId)}/moderators/${Uri.encodeComponent(accountId)}';
    if (moderator) return AstellRoom.fromJson(await _client.putJson(path, const {}));
    await _client.delete(path);
    return AstellRoom.fromJson(await _client.getJson(_room(roomId)));
  }

  @override
  Future<void> kickPeer(String roomId, String peerId) => _client.postJson('${_room(roomId)}/peers/${Uri.encodeComponent(peerId)}/kick', const {});

  @override
  Future<AstellPeer> mutePeer(String roomId, String peerId, bool muted) async =>
      AstellPeer.fromJson(await _client.putJson('${_room(roomId)}/peers/${Uri.encodeComponent(peerId)}/mute', {'muted': muted}));

  @override
  Future<List<AstellBan>> bans(String roomId) async => _list(await _client.getList('${_room(roomId)}/bans'), AstellBan.fromJson);

  @override
  Future<List<AstellBan>> ban(String roomId, String accountId, {String? reason}) async =>
      _list(await _client.putList('${_room(roomId)}/bans/${Uri.encodeComponent(accountId)}', {'reason': ?reason}), AstellBan.fromJson);

  @override
  Future<void> unban(String roomId, String accountId) => _client.delete('${_room(roomId)}/bans/${Uri.encodeComponent(accountId)}');

  @override
  Future<Set<String>> following() async => {for (final e in await _client.getList('/me/following')) if (e is Map && e['id'] is String) e['id'] as String};

  @override
  Future<void> follow(String accountId, bool follow) =>
      follow ? _client.putJson('/me/following/${Uri.encodeComponent(accountId)}', const {}) : _client.delete('/me/following/${Uri.encodeComponent(accountId)}');

  @override
  Future<AstellTtsVoices> ttsVoices() async => AstellTtsVoices.fromJson(await _client.getJson('/astell/tts/voices'));

  @override
  Future<List<int>> speak(String roomId, String text, {String? voice}) => _client.postForBytes('/astell/rooms/${Uri.encodeComponent(roomId)}/tts', {'text': text, 'voice': ?voice});

  @override
  Future<AstellAsset> uploadAsset(String roomId, List<int> bytes, {required String name, required String contentType, String encoding = 'identity'}) async =>
      AstellAsset.fromJson(await _client.postBytes(
        '/astell/rooms/${Uri.encodeComponent(roomId)}/assets',
        bytes,
        contentType: contentType,
        headers: {'content-encoding': encoding, 'x-rasq-file-name': Uri.encodeComponent(name)},
      ));

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
