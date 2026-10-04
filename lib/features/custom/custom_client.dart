import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../backend/orgate_client.dart';
import '../../backend/redact.dart';
import '../../backend/rasq_account.dart';
import 'custom_models.dart';

/// カスタムプラグインの共有セッションの口(rasq-central S-048、D-357)。
abstract class CustomSessionClient {
  /// [scope] = `room:<roomId>` / `profile` / `link`。room はホスト(オーナー / モデレーター)だけ = デプロイの承認。
  Future<CustomSession> create({required String pluginId, String? version, required String scope});

  /// 有効なもの(新しい順)。[scope] = `room:<roomId>` / `profile:<accountId>`。
  Future<List<CustomSession>> list(String scope);

  Future<({CustomSession session, Map<String, CustomVar> vars, List<CustomParticipant> participants})> get(String id);

  /// 招待コードから(閉じていれば null)。
  Future<CustomSession?> invite(String code);
  Future<void> close(String id);

  /// RASQ アカウントのページに置いたもの。
  Future<List<CustomProfilePage>> profilePages(String handle);
  Future<void> setMyPages(List<({String pluginId, String? version})> items);

  /// セッションの WS(welcome / var / call / joined / left / conflict / error / closed)。
  Future<CustomConnection> connect(String sessionId);
}

abstract class CustomConnection {
  Stream<Map<String, Object?>> get messages;
  void send(Map<String, Object?> message);
  Future<void> close();
}

final customSessionClientProvider = Provider<CustomSessionClient>((ref) {
  final client = ref.watch(centralClientProvider);
  final base = ref.watch(centralBaseUrlProvider);
  ref.watch(currentCentralAccountIdProvider);
  if (client == null || base == null) return MockCustomSessionClient();
  final holder = ref.read(orgateTokenHolderProvider);
  return HttpCustomSessionClient(client, baseUrl: base, token: () => holder.token, ensureFresh: holder.ensureFresh);
});

// ── 規則(Central と同じ。モックと、送る前の手元の確かめに使う)──────────────

/// キーの形(`me.` は送った人の `@<accountId>.` に書き換わる)。
final customVarKeyPattern = RegExp(r'^[A-Za-z0-9_.:@-]{1,64}$');
const customVarMaxBytes = 16 * 1024;
const customVarMaxKeys = 256;
const customAppendMax = 500;

/// `me.` → `@<accountId>.`。本人以外の `@<id>.` は書けない(null)。形が違うキーも null。
String? resolveCustomKey(String key, String accountId) {
  if (!customVarKeyPattern.hasMatch(key)) return null;
  if (key.startsWith('me.')) return '@$accountId.${key.substring(3)}';
  if (key.startsWith('@')) {
    final dot = key.indexOf('.');
    if (dot < 0 || key.substring(1, dot) != accountId) return null;
  }
  return key;
}

/// `shared.op` をサーバーと同じ規則で当てる(モック用)。形が合わなければ例外。
Object? applyCustomOp(Object? current, String op, Object? value) {
  switch (op) {
    case 'incr':
      final base = current is num ? current : (current == null ? 0 : throw const FormatException('incr: not a number'));
      if (value is! num) throw const FormatException('incr: value must be a number');
      final sum = base + value;
      return sum is double && sum == sum.roundToDouble() && base is int && value is int ? sum.toInt() : sum;
    case 'append':
      final list = current is List ? [...current] : (current == null ? <Object?>[] : throw const FormatException('append: not an array'));
      list.add(value);
      return list.length > customAppendMax ? list.sublist(list.length - customAppendMax) : list;
    case 'remove':
      if (current == null) return null;
      if (current is! List) throw const FormatException('remove: not an array');
      final list = [...current];
      final i = list.indexWhere((e) => jsonEncode(e) == jsonEncode(value));
      if (i >= 0) list.removeAt(i);
      return list;
    case 'merge':
      final map = current is Map ? {...current.cast<String, Object?>()} : (current == null ? <String, Object?>{} : throw const FormatException('merge: not an object'));
      if (value is! Map) throw const FormatException('merge: value must be an object');
      map.addAll(value.cast<String, Object?>());
      return map;
    default:
      throw FormatException('unknown op: $op');
  }
}

// ── モック(Central に繋がっていないとき / テスト)──────────────────────

class MockCustomSessionClient implements CustomSessionClient {
  MockCustomSessionClient({this.me = const CustomParticipant(accountId: 'me', handle: 'me', displayName: 'あなた')});
  final CustomParticipant me;

  final sessions = <String, CustomSession>{};
  final vars = <String, Map<String, CustomVar>>{};
  final pages = <String, List<CustomProfilePage>>{};
  final _conns = <String, List<_MockCustomConnection>>{};

  /// ほかの参加者(テストで足す)。
  final others = <String, List<CustomParticipant>>{};
  var _n = 0;

  /// ルームのホストか(テストで変える)。room の作成はホストだけ。
  bool isRoomHost = true;

  @override
  Future<CustomSession> create({required String pluginId, String? version, required String scope}) async {
    final resolved = switch (scope) {
      'profile' => 'profile:${me.accountId}',
      'link' => 'link:',
      _ => scope,
    };
    if (resolved.startsWith('room:') && !isRoomHost) throw StateError('ホストだけがデプロイできます');
    if (!resolved.startsWith('link:')) {
      final existing = sessions.values.where((s) => s.scope == resolved && s.pluginId == pluginId).firstOrNull;
      if (existing != null) return existing;
    }
    final id = 'cs-${_n++}';
    final s = CustomSession(
      id: id,
      pluginId: pluginId,
      version: version ?? '1.0.0',
      scope: resolved == 'link:' ? 'link:$id' : resolved,
      title: pluginId,
      ownerAccountId: me.accountId,
      ownerHandle: me.handle,
      inviteCode: resolved == 'link:' ? 'INV$id' : null,
      createdAt: DateTime.now(),
    );
    sessions[id] = s;
    vars[id] = {};
    return s;
  }

  @override
  Future<List<CustomSession>> list(String scope) async => [for (final s in sessions.values.toList().reversed) if (s.scope == scope) s.copyWith(participantCount: _participants(s.id).length)];

  List<CustomParticipant> _participants(String id) => [if ((_conns[id] ?? const []).isNotEmpty) me, ...?others[id]];

  @override
  Future<({CustomSession session, Map<String, CustomVar> vars, List<CustomParticipant> participants})> get(String id) async {
    final s = sessions[id];
    if (s == null) throw StateError('not found');
    return (session: s, vars: {...?vars[id]}, participants: _participants(id));
  }

  @override
  Future<CustomSession?> invite(String code) async => sessions.values.where((s) => s.inviteCode == code).firstOrNull;

  @override
  Future<void> close(String id) async {
    sessions.remove(id);
    for (final c in [...?_conns[id]]) {
      c._push({'type': 'closed', 'reason': 'closed'});
    }
  }

  @override
  Future<List<CustomProfilePage>> profilePages(String handle) async {
    final list = pages[handle] ?? const [];
    return [
      for (final p in list)
        CustomProfilePage(
          pluginId: p.pluginId,
          version: p.version,
          name: p.name,
          icon: p.icon,
          mode: p.mode,
          sessionId: p.isShared ? sessions.values.where((s) => s.scope == 'profile:${me.accountId}' && s.pluginId == p.pluginId).firstOrNull?.id : null,
        ),
    ];
  }

  @override
  Future<void> setMyPages(List<({String pluginId, String? version})> items) async {
    final before = {for (final p in pages[me.handle] ?? const <CustomProfilePage>[]) p.pluginId: p};
    pages[me.handle] = [for (final i in items) before[i.pluginId] ?? CustomProfilePage(pluginId: i.pluginId, version: i.version, name: i.pluginId)];
  }

  /// 名前 / モードを付けて置く(テスト用。本物は Central がマニフェストから埋める)。
  void seedPage(String handle, CustomProfilePage page) => pages[handle] = [...?pages[handle], page];

  @override
  Future<CustomConnection> connect(String sessionId) async {
    if (!sessions.containsKey(sessionId)) throw StateError('セッションが閉じています');
    final c = _MockCustomConnection(this, sessionId);
    (_conns[sessionId] ??= []).add(c);
    return c;
  }

  /// ほかの参加者として送る(テスト用)。WS と同じ規則で当て、全員へ配る。
  void actAs(String sessionId, CustomParticipant who, Map<String, Object?> message) => _handle(sessionId, who, message, null);

  /// ほかの参加者が入った / 出た(テスト用)。
  void join(String sessionId, CustomParticipant who) {
    (others[sessionId] ??= []).add(who);
    _broadcast(sessionId, {'type': 'joined', 'participant': who.toJson()});
  }

  void leave(String sessionId, String accountId) {
    others[sessionId]?.removeWhere((p) => p.accountId == accountId);
    _broadcast(sessionId, {'type': 'left', 'accountId': accountId});
  }

  void _broadcast(String sessionId, Map<String, Object?> m) {
    for (final c in [...?_conns[sessionId]]) {
      c._push(m);
    }
  }

  void _handle(String sessionId, CustomParticipant who, Map<String, Object?> m, _MockCustomConnection? from) {
    void error(String message) => from?._push({'type': 'error', 'message': message});
    final store = vars[sessionId];
    if (store == null) return error('closed');
    switch (m['type']) {
      case 'ping':
        from?._push({'type': 'pong'});
      case 'set' || 'op':
        final key = resolveCustomKey('${m['key']}', who.accountId);
        if (key == null) return error('forbidden key: ${m['key']}');
        final cur = store[key];
        Object? next;
        if (m['type'] == 'set') {
          final ifRev = (m['ifRev'] as num?)?.toInt();
          if (ifRev != null && ifRev != (cur?.rev ?? 0)) {
            from?._push({'type': 'conflict', 'key': key, 'value': cur?.value, 'rev': cur?.rev ?? 0});
            return;
          }
          next = m['value'];
        } else {
          try {
            next = applyCustomOp(cur?.value, '${m['op']}', m['value']);
          } on FormatException catch (e) {
            return error(e.message);
          }
        }
        if (utf8.encode(jsonEncode(next)).length > customVarMaxBytes) return error('value too large');
        if (cur == null && next != null && store.length >= customVarMaxKeys) return error('too many keys');
        final rev = (cur?.rev ?? 0) + 1;
        if (next == null) {
          store.remove(key);
        } else {
          store[key] = CustomVar(value: next, rev: rev, by: who.accountId);
        }
        _broadcast(sessionId, {'type': 'var', 'key': key, 'value': next, 'rev': rev, 'by': who.accountId});
      case 'call':
        _broadcast(sessionId, {'type': 'call', 'fn': m['fn'], 'args': m['args'], 'from': who.toJson()});
      default:
        error('unknown type');
    }
  }
}

class _MockCustomConnection implements CustomConnection {
  _MockCustomConnection(this.client, this.sessionId) {
    _controller = StreamController<Map<String, Object?>>.broadcast(onListen: () {
      final s = client.sessions[sessionId]!;
      _controller.add({
        'type': 'welcome',
        'me': client.me.toJson(),
        'session': s.toJson(),
        'participants': [for (final p in client._participants(sessionId)) p.toJson()],
        'vars': {for (final e in (client.vars[sessionId] ?? const <String, CustomVar>{}).entries) e.key: e.value.toJson()},
      });
    });
  }
  final MockCustomSessionClient client;
  final String sessionId;
  late final StreamController<Map<String, Object?>> _controller;

  /// 送ったもの(テスト用)。
  final sent = <Map<String, Object?>>[];

  void _push(Map<String, Object?> m) {
    if (!_controller.isClosed) _controller.add(m);
  }

  @override
  Stream<Map<String, Object?>> get messages => _controller.stream;

  @override
  void send(Map<String, Object?> message) {
    sent.add(message);
    client._handle(sessionId, client.me, message, this);
  }

  @override
  Future<void> close() async {
    client._conns[sessionId]?.remove(this);
    await _controller.close();
  }
}

// ── RASQ Central ──────────────────────────────────────────────────

class HttpCustomSessionClient implements CustomSessionClient {
  HttpCustomSessionClient(this._client, {required this.baseUrl, required this.token, this.ensureFresh});

  /// 繋ぐ前に、アクセストークンの期限が近ければ取り直す (D-398。WebSocket の `?token=` は 401 で取り直せない)。
  final Future<void> Function()? ensureFresh;
  final OrgateClient _client;
  final Uri baseUrl;
  final String? Function() token;

  /// 端末の版がそのサーバーで配られていなければ(`404 version_not_available`: アプリ同梱のサンプルの版を持っている / 審査待ち、
  /// D-424 / Central S-079)、版を付けずに作り直す(サーバーの現在の版。現在の版も無ければそのまま失敗)。
  @override
  Future<CustomSession> create({required String pluginId, String? version, required String scope}) async {
    Future<CustomSession> post(String? v) async => CustomSession.fromJson(await _client.postJson('/custom/sessions', {'pluginId': pluginId, 'version': ?v, 'scope': scope}));
    try {
      return await post(version);
    } on OrgateException catch (e) {
      if (version == null || e.serverCode != 'version_not_available') rethrow;
      return post(null);
    }
  }

  @override
  Future<List<CustomSession>> list(String scope) async => [for (final e in await _client.getList('/custom/sessions', {'scope': scope})) if (e is Map) CustomSession.fromJson(e.cast<String, Object?>())];

  @override
  Future<({CustomSession session, Map<String, CustomVar> vars, List<CustomParticipant> participants})> get(String id) async {
    final j = await _client.getJson('/custom/sessions/${Uri.encodeComponent(id)}');
    return (
      session: CustomSession.fromJson((j['session'] as Map).cast<String, Object?>()),
      vars: {for (final e in ((j['vars'] as Map?) ?? const {}).entries) '${e.key}': CustomVar.fromJson((e.value as Map).cast<String, Object?>())},
      participants: [for (final p in (j['participants'] as List? ?? const [])) if (p is Map) CustomParticipant.fromJson(p.cast<String, Object?>())],
    );
  }

  @override
  Future<CustomSession?> invite(String code) async {
    try {
      return CustomSession.fromJson(await _client.getJson('/custom/invites/${Uri.encodeComponent(code)}'));
    } on OrgateException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  @override
  Future<void> close(String id) => _client.delete('/custom/sessions/${Uri.encodeComponent(id)}');

  @override
  Future<List<CustomProfilePage>> profilePages(String handle) async =>
      [for (final e in await _client.getList('/accounts/${Uri.encodeComponent(handle)}/pages')) if (e is Map) CustomProfilePage.fromJson(e.cast<String, Object?>())];

  @override
  Future<void> setMyPages(List<({String pluginId, String? version})> items) => _client.putJson('/me/pages', {
        'items': [for (final i in items) {'pluginId': i.pluginId, 'version': ?i.version}],
      });

  @override
  Future<CustomConnection> connect(String sessionId) async {
    await ensureFresh?.call();
    final t = token();
    if (t == null) throw StateError('RASQ アカウントのトークンがありません');
    // AsTell の WS と同じく Bearer はクエリで(Web 版でも繋がる web_socket_channel)。
    final url = baseUrl.replace(
      scheme: baseUrl.scheme == 'https' ? 'wss' : 'ws',
      path: '${baseUrl.path}/api/v1/custom/sessions/${Uri.encodeComponent(sessionId)}/ws',
      queryParameters: {'token': t},
    );
    final ws = WebSocketChannel.connect(url);
    try {
      await ws.ready;
    } catch (e) {
      throw StateError(wsConnectErrorMessage(e)); // REC-03: URL の token を出さない
    }
    return _WsCustomConnection(ws);
  }
}

class _WsCustomConnection implements CustomConnection {
  _WsCustomConnection(this._ws);
  final WebSocketChannel _ws;

  @override
  Stream<Map<String, Object?>> get messages => _ws.stream.map((e) {
        try {
          return (jsonDecode(e as String) as Map).cast<String, Object?>();
        } catch (_) {
          return <String, Object?>{'type': 'error', 'message': 'unreadable frame'};
        }
      });

  @override
  void send(Map<String, Object?> message) => _ws.sink.add(jsonEncode(message));

  @override
  Future<void> close() => _ws.sink.close();
}
