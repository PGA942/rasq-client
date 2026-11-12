import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:path_provider/path_provider.dart';

import '../../../backend/orgate_client.dart';
import '../../../backend/rasq_account.dart' show orgateAccountProvider;
import '../../../session/session_providers.dart' show sessionStorageProvider;
import '../swing_client.dart';
import '../swing_models.dart';
import '../swing_providers.dart';
import 'swing_copy_store.dart';
import 'swing_manifest.dart';
import 'swing_signer.dart';

/// P2P の Swing の受け渡し (D-549 / Central S-128、仕様 `swing-p2p-spec.md`)。
///
/// - **取りに行く** [SwingP2p.fetch]: 目録の署名を確かめ、手元に無ければ `GET /swings/{id}/sources` の相手(作者が先)から
///   WebRTC の DataChannel で受け取る。シグナリングは `POST /swings/{id}/signal`(送る)と `/me/events` の `swing.signal`
///   (受ける、[SwingP2p.onLiveEvent])。受け取った実体は [SwingAssembler] が大きさと SHA-256 を目録と照合し、合わなければ捨てて
///   その相手を `POST /swings/{id}/integrity` で知らせ、次の相手へ。合えば [SwingCopyStore] に期限まで置く(配る側に回る)。
/// - **配る**: 相手から `offer` が来て、その Swing の実体を持っていて、**アプリが前面にあり**、同時に配る数が
///   [maxServing] 未満のときだけ応える。
/// - **写しを送る** [SwingP2p.answerEvidenceRequest]: 通報の写しの求め(`/me/events` の `swing.evidence_request`、FCM のデータ、
///   アプリを開いたときの `GET /me/swing-evidence-requests`)に、持っていれば実体を送る。
/// - TURN は `GET /me/swing-turn` の資格情報を有効時間まで使い回す。出してもらえなければ STUN だけ。
class SwingP2p {
  SwingP2p({
    required this.api,
    required this.store,
    this.peerConnection = createPeerConnection,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SwingApi api;
  final SwingCopyStore store;

  /// 相手との接続を作る口(テストは偽物)。
  final Future<RTCPeerConnection> Function(
    Map<String, dynamic> configuration, [
    Map<String, dynamic> constraints,
  ])
  peerConnection;
  final DateTime Function() _now;

  /// 同時に配る数の上限(仕様 §2)。
  static const maxServing = 3;

  /// 1 人の相手から受け取るのを待つ時間。
  static Duration fetchTimeout = const Duration(seconds: 30);

  /// 試す相手の数。
  static const maxSourcesTried = 3;

  /// TURN を出してもらえないときの ICE サーバー(Central の既定と同じ公開の STUN)。
  static const fallbackIce = [
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  final _signals = StreamController<Map<String, Object?>>.broadcast();
  final _inflight = <String, Future<Uint8List>>{};
  final _serving = <String, _Serve>{};

  /// 取りに行っている受け渡し(期限 / 破棄で止める。セキュリティ確認 2026-11-11 の #16)。
  final _fetching = <Completer<Uint8List>>{};

  /// 配るときの実体の読み込み(同じ Swing を同時に求められても 1 回だけ読む。#20)。
  final _entryLoads = <String, Future<({Uint8List bytes, String sha256, String? contentType})?>>{};
  bool _foreground = true;
  bool _disposed = false;
  ({List<Map<String, Object?>> ice, DateTime until})? _turn;

  /// アプリが前面にあるか(裏では配らない)。
  set foreground(bool v) {
    _foreground = v;
    if (!v) {
      for (final s in [..._serving.values]) {
        unawaited(s.close());
      }
    }
  }

  /// `/me/events` から届いたもの(`swing.signal` / `swing.evidence_request`)。
  void onLiveEvent(Map<String, Object?> m) {
    if (_disposed) return;
    switch (m['type']) {
      case 'swing.signal':
        _signals.add(m);
        if (m['kind'] == 'offer') unawaited(_serve(m));
        _serving['${m['session']}']?.onSignal(m);
      case 'swing.evidence_request':
        final id = m['swingId'], hash = m['manifestSha256'];
        if (id is String && hash is String) {
          unawaited(answerEvidenceRequest(id, manifestSha256: hash));
        }
    }
  }

  Future<List<Map<String, Object?>>> _ice() async {
    final t = _turn;
    if (t != null && t.until.isAfter(_now())) return t.ice;
    try {
      final r = await api.turn();
      final ice = r.iceServers.isEmpty
          ? [for (final s in fallbackIce) Map<String, Object?>.of(s)]
          : r.iceServers;
      _turn = (
        ice: ice,
        until: _now().add(Duration(seconds: (r.ttlSecs - 60).clamp(30, 86400))),
      );
      return ice;
    } catch (_) {
      return [for (final s in fallbackIce) Map<String, Object?>.of(s)];
    }
  }

  // ── 取りに行く ──────────────────────────────────────────────

  /// P2P の Swing の実体(確かめ済み)。同じ Swing を同時に呼んでも 1 回だけ取りに行く。
  Future<Uint8List> fetch(Swing swing) =>
      // 後始末は値を返さない(`remove` はこの Future 自身を返すので、`=>` だと自分の完了を待って止まる)。
      _inflight[swing.id] ??= _fetch(swing).whenComplete(() {
        _inflight.remove(swing.id);
      });

  Future<Uint8List> _fetch(Swing swing) async {
    final media = swing.p2pMedia;
    if (media == null) throw const SwingP2pException(SwingP2pFailure.noMedia);
    if (!await SwingSigner.verify(
      manifest: swing.manifest!,
      signature: swing.signature!,
      publicKey: swing.signingKey!,
    )) {
      throw const SwingP2pException(SwingP2pFailure.unverified);
    }
    final local = await store.get(swing.id);
    if (local != null && sha256Hex(local) == media.sha256) return local;
    final sources = await api.sources(swing.id);
    if (sources.isEmpty) {
      throw const SwingP2pException(SwingP2pFailure.noSource);
    }
    for (final s in sources.take(maxSourcesTried)) {
      try {
        final bytes = await _fetchFrom(
          swing,
          s.source,
          media.sha256,
          media.size,
        // 期限は [_fetchFrom] の中で掛けて接続も閉じる (#16)。ここは接続を作る前で止まったときの予備。
        ).timeout(fetchTimeout + const Duration(seconds: 5));
        await store.put(
          swing.id,
          bytes,
          sha256: media.sha256,
          expiresAt: swing.expiresAt,
          contentType: media.contentType,
        );
        return bytes;
      } on FormatException catch (e) {
        debugPrint(
          'swing p2p: ${swing.id}: bad body from a source: ${e.message}',
        );
        unawaited(api.integrity(swing.id, s.source).catchError((Object _) {}));
      } catch (e) {
        debugPrint('swing p2p: ${swing.id}: source failed: $e');
      }
    }
    throw const SwingP2pException(SwingP2pFailure.noSource);
  }

  Future<Uint8List> _fetchFrom(
    Swing swing,
    String source,
    String sha256,
    int size,
  ) async {
    final session = newSwingId();
    // 期限は接続を持つここで掛ける (#16): 外の Future だけを期限切れにすると、相手が終わりの知らせを送らないあいだ
    // 接続と受け取った塊が残る。期限 / 破棄で [done] を失敗にし、下の finally で接続と購読を必ず閉じる。
    final done = Completer<Uint8List>();
    void fail(Object e) {
      if (!done.isCompleted) done.completeError(e);
    }

    final deadline = Timer(fetchTimeout, () => fail(TimeoutException('swing p2p fetch', fetchTimeout)));
    _fetching.add(done);
    RTCPeerConnection? pc;
    StreamSubscription<Map<String, Object?>>? sub;
    try {
      pc = await peerConnection({
        'iceServers': await _ice(),
        'sdpSemantics': 'unified-plan',
      });
      if (done.isCompleted) return await done.future;
      final conn = pc;
      final asm = SwingAssembler(expectSha256: sha256, maxBytes: size);
      final pendingIce = <RTCIceCandidate>[];
      var remoteSet = false;
      conn.onConnectionState = (st) {
        if (st == RTCPeerConnectionState.RTCPeerConnectionStateFailed || st == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          fail(StateError('the connection closed'));
        }
      };
      final dc = await conn.createDataChannel(
        'swing',
        RTCDataChannelInit()..ordered = true,
      );
      // 相手がチャネルを閉じたら、終わりの知らせを待たない (#16)。
      dc.onDataChannelState = (st) {
        if (st == RTCDataChannelState.RTCDataChannelClosed) fail(StateError('the channel closed'));
      };
      dc.onMessage = (m) {
        if (done.isCompleted) return;
        try {
          if (m.isBinary) {
            asm.binary(m.binary);
          } else {
            final body = asm.text(m.text);
            if (body != null) done.complete(body);
          }
        } on FormatException catch (e) {
          done.completeError(e);
        }
      };
      conn.onIceCandidate = (c) {
        if (c.candidate == null) return;
        unawaited(
          api
              .signal(
                swing.id,
                to: source,
                session: session,
                kind: 'ice',
                data: {
                  'candidate': c.candidate,
                  'sdpMid': c.sdpMid,
                  'sdpMLineIndex': c.sdpMLineIndex,
                },
              )
              .catchError((Object _) {}),
        );
      };
      sub = _signals.stream
          .where(
            (m) =>
                m['swingId'] == swing.id &&
                m['session'] == session &&
                m['from'] == source,
          )
          .listen((m) async {
            final data = m['data'];
            try {
              switch (m['kind']) {
                case 'answer' when data is Map:
                  await conn.setRemoteDescription(
                    RTCSessionDescription(
                      data['sdp'] as String?,
                      data['type'] as String? ?? 'answer',
                    ),
                  );
                  remoteSet = true;
                  for (final c in pendingIce) {
                    await conn.addCandidate(c);
                  }
                  pendingIce.clear();
                case 'ice' when data is Map:
                  final c = RTCIceCandidate(
                    data['candidate'] as String?,
                    data['sdpMid'] as String?,
                    (data['sdpMLineIndex'] as num?)?.toInt(),
                  );
                  remoteSet ? await conn.addCandidate(c) : pendingIce.add(c);
                case 'bye':
                  if (!done.isCompleted) {
                    done.completeError(StateError('the source declined'));
                  }
              }
            } catch (e) {
              if (!done.isCompleted) done.completeError(e);
            }
          });
      final offer = await conn.createOffer();
      await conn.setLocalDescription(offer);
      if (done.isCompleted) return await done.future;
      await api.signal(
        swing.id,
        to: source,
        session: session,
        kind: 'offer',
        data: {'sdp': offer.sdp, 'type': offer.type},
      );
      return await done.future;
    } catch (e) {
      fail(e);
      rethrow;
    } finally {
      deadline.cancel();
      _fetching.remove(done);
      if (!done.isCompleted) done.completeError(StateError('fetch ended'));
      done.future.ignore();
      unawaited(sub?.cancel());
      unawaited(
        api
            .signal(swing.id, to: source, session: session, kind: 'bye')
            .catchError((Object _) {}),
      );
      try {
        await pc?.close();
      } catch (_) {}
    }
  }

  // ── 配る ─────────────────────────────────────────────────────

  Future<void> _serve(Map<String, Object?> offer) async {
    final swingId = offer['swingId'],
        from = offer['from'],
        session = offer['session'],
        data = offer['data'];
    if (swingId is! String ||
        from is! String ||
        session is! String ||
        data is! Map) {
      return;
    }
    if (!_foreground ||
        _serving.length >= maxServing ||
        _serving.containsKey(session)) {
      unawaited(
        api
            .signal(swingId, to: from, session: session, kind: 'bye')
            .catchError((Object _) {}),
      );
      return;
    }
    // 枠は最初の await より前に取る (セキュリティ確認 2026-11-11 の #20): 読み込みの待ちのあいだに届いたほかの offer も、
    // この保留の枠を数える([maxServing] を超えて読み込み・接続を始めない)。同じ session の重ねは上で断る。
    // 終わったときは、台帳の持ち主がこの受け渡しのときだけ外す(ほかの受け渡しの登録を消さない)。
    late final _Serve serve;
    serve = _Serve(
      swingId: swingId,
      to: from,
      session: session,
      api: api,
      onClosed: () {
        if (identical(_serving[session], serve)) _serving.remove(session);
      },
    );
    _serving[session] = serve;
    // 期限は読み込みの前から (#20)。相手が受け取らないまま止まっても、ずっと抱えない。
    final expire = Timer(fetchTimeout * 2, () => unawaited(serve.close()));
    serve.onDone = expire.cancel;
    try {
      final entry = await (_entryLoads[swingId] ??= store.entry(swingId).whenComplete(() {
        _entryLoads.remove(swingId);
      }));
      if (entry == null || serve.closed || _disposed || !_foreground) {
        unawaited(
          api
              .signal(swingId, to: from, session: session, kind: 'bye')
              .catchError((Object _) {}),
        );
        await serve.close();
        return;
      }
      final pc = await peerConnection({
        'iceServers': await _ice(),
        'sdpSemantics': 'unified-plan',
      });
      serve.pc = pc;
      if (serve.closed) {
        try {
          await pc.close();
        } catch (_) {}
        return;
      }
      pc.onIceCandidate = (c) {
        if (c.candidate == null) return;
        unawaited(
          api
              .signal(
                swingId,
                to: from,
                session: session,
                kind: 'ice',
                data: {
                  'candidate': c.candidate,
                  'sdpMid': c.sdpMid,
                  'sdpMLineIndex': c.sdpMLineIndex,
                },
              )
              .catchError((Object _) {}),
        );
      };
      pc.onDataChannel = (dc) {
        dc.onDataChannelState = (s) {
          if (s == RTCDataChannelState.RTCDataChannelOpen) {
            unawaited(serve.send(dc, entry.bytes, entry.sha256));
          }
        };
      };
      await pc.setRemoteDescription(
        RTCSessionDescription(
          data['sdp'] as String?,
          data['type'] as String? ?? 'offer',
        ),
      );
      await serve.remoteSet();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      await api.signal(
        swingId,
        to: from,
        session: session,
        kind: 'answer',
        data: {'sdp': answer.sdp, 'type': answer.type},
      );
    } catch (e) {
      debugPrint('swing p2p: serving $swingId failed: $e');
      await serve.close();
    }
  }

  // ── 通報の写し ───────────────────────────────────────────────

  /// 写しの求めに応える(持っていなければ何もしない。断られても静かに終わる)。
  Future<void> answerEvidenceRequest(
    String swingId, {
    required String manifestSha256,
  }) async {
    final e = await store.entry(swingId);
    if (e == null) return;
    try {
      await api.uploadEvidence(
        swingId,
        e.bytes,
        manifestSha256: manifestSha256,
        contentType: e.contentType ?? 'application/octet-stream',
      );
    } on OrgateException catch (x) {
      debugPrint(
        'swing p2p: evidence for $swingId not taken: ${x.code.code} ${x.serverCode}',
      );
    } catch (x) {
      debugPrint('swing p2p: evidence for $swingId failed: $x');
    }
  }

  /// アプリを開いたとき: まだ送っていない写しの求めに応える。
  Future<void> answerPendingEvidence() async {
    try {
      for (final r in await api.evidenceRequests()) {
        await answerEvidenceRequest(
          r.swingId,
          manifestSha256: r.manifestSha256,
        );
      }
    } catch (e) {
      debugPrint('swing p2p: evidence requests: $e');
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    // 取りに行っている受け渡しも止める (#16): 接続と受け取った塊は、それぞれの finally で手放す。
    for (final d in [..._fetching]) {
      if (!d.isCompleted) d.completeError(StateError('disposed'));
    }
    for (final s in [..._serving.values]) {
      await s.close();
    }
    await _signals.close();
  }
}

/// 1 人の相手へ配っている受け渡し。
class _Serve {
  _Serve({
    required this.swingId,
    required this.to,
    required this.session,
    required this.api,
    required this.onClosed,
  });
  final String swingId, to, session;
  final SwingApi api;
  final VoidCallback onClosed;
  RTCPeerConnection? pc;
  bool _remote = false, _closed = false, _sending = false;
  bool get closed => _closed;

  /// 閉じたときに呼ぶ(期限のタイマーを止める)。
  VoidCallback? onDone;
  final _pendingIce = <RTCIceCandidate>[];

  Future<void> remoteSet() async {
    _remote = true;
    for (final c in _pendingIce) {
      await pc?.addCandidate(c);
    }
    _pendingIce.clear();
  }

  void onSignal(Map<String, Object?> m) {
    if (m['from'] != to) return;
    final data = m['data'];
    switch (m['kind']) {
      case 'ice' when data is Map:
        final c = RTCIceCandidate(
          data['candidate'] as String?,
          data['sdpMid'] as String?,
          (data['sdpMLineIndex'] as num?)?.toInt(),
        );
        _remote ? unawaited(pc?.addCandidate(c)) : _pendingIce.add(c);
      case 'bye':
        unawaited(close());
    }
  }

  /// 最初の知らせ → 塊(送る待ちが溜まりすぎないよう待ちながら)→ 終わりの知らせ。
  Future<void> send(RTCDataChannel dc, Uint8List bytes, String sha256) async {
    if (_sending || _closed) return;
    _sending = true;
    try {
      await dc.send(
        RTCDataChannelMessage(
          swingTransferHeader(
            swingId: swingId,
            size: bytes.length,
            sha256: sha256,
          ),
        ),
      );
      for (final chunk in swingChunks(bytes)) {
        if (_closed) return;
        while ((dc.bufferedAmount ?? 0) > 1024 * 1024 && !_closed) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await dc.send(RTCDataChannelMessage.fromBinary(chunk));
      }
      await dc.send(RTCDataChannelMessage(swingTransferDone));
    } catch (e) {
      debugPrint('swing p2p: sending $swingId failed: $e');
      await close();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    onClosed();
    onDone?.call();
    try {
      await pc?.close();
    } catch (_) {}
  }
}

enum SwingP2pFailure { noMedia, unverified, noSource }

class SwingP2pException implements Exception {
  const SwingP2pException(this.failure);
  final SwingP2pFailure failure;
  @override
  String toString() => 'SwingP2pException(${failure.name})';
}

// ── 状態 ─────────────────────────────────────────────────────

/// 実体の置き場(テストで一時のフォルダへ差し替える)。
final swingCopyStoreProvider = Provider<SwingCopyStore>(
  (ref) => SwingCopyStore(getApplicationCacheDirectory),
);

final swingSignerProvider = Provider<SwingSigner>(
  (ref) => SwingSigner(ref.watch(sessionStorageProvider)),
);

/// P2P の受け渡し。RASQ アカウントに繋がっていなければ null。
final swingP2pProvider = Provider<SwingP2p?>((ref) {
  final api = ref.watch(swingApiProvider);
  if (api == null) return null;
  final p2p = SwingP2p(api: api, store: ref.watch(swingCopyStoreProvider));
  final store = ref.read(swingCopyStoreProvider);
  unawaited(store.sweep());
  // 期限の来た実体を消す / アプリへ戻ったら写しの求めを確かめる / 裏では配らない。
  final sweeper = Timer.periodic(
    const Duration(minutes: 5),
    (_) => unawaited(store.sweep()),
  );
  AppLifecycleListener? life;
  if (!kIsWeb) {
    life = AppLifecycleListener(
      onStateChange: (s) {
        p2p.foreground = s == AppLifecycleState.resumed;
        if (s == AppLifecycleState.resumed) {
          unawaited(p2p.answerPendingEvidence());
          unawaited(store.sweep());
        }
      },
    );
  }
  unawaited(p2p.answerPendingEvidence());
  ref.onDispose(() {
    sweeper.cancel();
    life?.dispose();
    unawaited(p2p.dispose());
  });
  return p2p;
});

/// P2P で Swing を作る(D-549)。サーバーが P2P を受けない(`404 swing_p2p_disabled`)なら null を返す(呼び元は今までの形で作る)。
/// 実体があれば手元に置き、作った人として配る側に回る。署名鍵が知られていなければ登録し直して 1 回だけ作り直す。
Future<Swing?> createP2pSwing(
  WidgetRef ref, {
  required NewSwing draft,
  Uint8List? bytes,
  String? contentType,
  Map<String, Object?>? plugin,
}) async {
  final api = ref.read(swingApiProvider);
  final account = ref.read(orgateAccountProvider).value;
  final deviceId = ref.read(orgateAccountProvider.notifier).deviceId;
  if (api == null || account == null || deviceId == null) return null;
  final signer = ref.read(swingSignerProvider);
  final swingId = newSwingId();
  final media = bytes == null || contentType == null
      ? null
      : (
          sha256: sha256Hex(bytes),
          size: bytes.length,
          contentType: contentType,
        );
  Map<String, Object?> manifest() => buildSwingManifest(
    swingId: swingId,
    authorAccountId: account.id,
    deviceId: deviceId,
    kind: draft.kind.wire,
    text: draft.text,
    cw: draft.cw,
    sensitive: draft.sensitive,
    media: media,
    plugin: plugin,
    audience: draft.audience.toJson(),
    notify: draft.notify == null || draft.notify!.isEmpty
        ? null
        : draft.notify!.toJson(),
    ttlHours: draft.ttlHours,
    createdAt: DateTime.now(),
  );
  /// 鍵を登録する。登録できない(古い Central に口が無い / 端末の保管庫が使えない)なら false(今までの形で作る)。
  Future<bool> register() async {
    try {
      await signer.ensureRegistered(
        account.id,
        deviceId,
        (pk) => api.registerKey(deviceId, pk),
      );
      return true;
    } catch (e) {
      debugPrint('swing p2p: key registration unavailable: $e');
      return false;
    }
  }

  Future<Swing> attempt() async {
    final m = manifest();
    return api.createP2p(m, await signer.sign(account.id, m));
  }

  /// P2P を受けない Central(設定で止めている / 口が無い古い版)。
  bool unsupported(OrgateException e) =>
      e.serverCode == SwingApi.p2pDisabled || e.code.code == '404';

  Swing swing;
  try {
    if (!await register()) return null;
    swing = await attempt();
  } on OrgateException catch (e) {
    if (unsupported(e)) return null;
    if (e.serverCode != SwingApi.keyUnknown) rethrow;
    await signer.forgetRegistration(account.id, deviceId);
    if (!await register()) return null;
    swing = await attempt();
  } on FormatException {
    // 目録にできない(プラグインのデータに小数がある)→ 今までの形で作る。
    return null;
  }
  if (bytes != null && media != null) {
    await ref
        .read(swingCopyStoreProvider)
        .put(
          swing.id,
          bytes,
          sha256: media.sha256,
          expiresAt: swing.expiresAt,
          contentType: media.contentType,
        );
  }
  return swing;
}
