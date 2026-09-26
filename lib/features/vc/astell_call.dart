import 'dart:async';

import 'package:flutter/foundation.dart';

import 'astell_media.dart';

/// 通話に入れる人数(自分を含む)。音声だけのメッシュは人数の 2 乗で接続が増えるので、ここで止める。
/// それより後に入った人は通話に入らず、配信があれば LiveKit で聞く (D-317)。
const astellMeshCap = 8;

/// 話している印の閾値(受けている音声の audioLevel、0〜1)。
const astellSpeakingLevel = 0.02;

/// 通話の手順 (D-317): 音声だけのメッシュを、Central の WS の中継で組む。
///
/// - **offer を出すのは後から入った側**: `welcome` の `peers` の全員へ([start])。いた側は offer に
///   answer で応える。1 組につき offer を出すのは片方だけなので、ふつうはぶつからない。
/// - ICE は届いた順に(trickle)。相手の記述より先に届いた候補は控えて、記述を入れたあとに入れる。
/// - offer がぶつかったとき(繋ぎ直しなど)は perfect negotiation: peerId の大きいほうが**譲る側**
///   (出しかけの offer を取り下げて相手の offer を受ける)、小さいほうは相手の offer を捨てる。
/// - 接続が `failed` になったら、offer を出した側が ICE をやり直す offer を出す。
/// - `peer-left` / 退出 / キックでその接続を閉じる。
///
/// 受け取ったメッセージは 1 本の列で順に処理する(offer の処理の途中で届いた ice が先に走らないように)。
class AstellCallMesh {
  AstellCallMesh({
    required this.media,
    required this.send,
    required this.iceServers,
    this.onChanged,
    this.onError,
    this.levelInterval = const Duration(milliseconds: 400),
    this.cap = astellMeshCap,
  });

  final AstellMedia media;

  /// シグナリングの送り口(`{"type": "offer"|"answer"|"ice", "to", "payload"}`)。
  final void Function(Map<String, Object?> message) send;

  /// ICE サーバー(`GET /astell/ice`)。最初の接続のときに 1 度だけ読む。
  final Future<List<Map<String, Object?>>> Function() iceServers;

  /// 接続 / 話している人が変わった。
  final VoidCallback? onChanged;

  /// 画面に出す失敗。
  final void Function(String message)? onError;

  /// 話している印のために声の大きさを見る間隔。null なら見ない(テストは [pollLevels] を直接呼ぶ)。
  final Duration? levelInterval;
  final int cap;

  String? _me;
  final Map<String, _Link> _links = {};
  List<Map<String, Object?>>? _ice;
  Future<void> _queue = Future.value();
  Timer? _levelTimer;
  bool _closed = false;
  bool _speakerMuted = false;
  Set<String> _muted = const {};

  /// 満員で通話に入らなかった。
  bool full = false;

  /// いま話している相手の peerId。
  Set<String> speaking = const {};

  /// 接続(作りかけも含む)がある相手。
  Set<String> get peerIds => _links.keys.toSet();

  /// その相手との接続の状態(無ければ null)。
  AstellLinkState? stateOf(String peerId) => _links[peerId]?.state;

  /// その相手の声が繋がっているか。
  bool connectedTo(String peerId) => _links[peerId]?.state == AstellLinkState.connected;

  /// 使っている ICE サーバーの URL(資格情報は出さない)。まだ読んでいなければ null (D-323)。
  List<String>? get iceServerUrls => _ice == null
      ? null
      : [
          for (final e in _ice!)
            ...switch (e['urls']) {
              final String u => [u],
              final List<Object?> us => us.whereType<String>(),
              _ => const <String>[],
            },
        ];

  /// 相手ごとの接続の様子(開発者向けの表示、D-323)。
  Future<List<AstellLinkDiagnostics>> diagnostics() async => [for (final l in [..._links.values]) await l.link.diagnostics()];

  /// 1 本の列に積む(前の処理が終わってから)。戻り値はその処理の終わり(テスト用)。
  Future<void> _enqueue(Future<void> Function() run) {
    final next = _queue.then((_) async {
      if (_closed) return;
      try {
        await run();
      } catch (e, st) {
        debugPrint('astell call: $e\n$st');
        onError?.call('通話の接続に失敗しました: ${AstellMediaException.from(e).message}');
      }
    });
    _queue = next;
    return next;
  }

  /// `welcome`: 自分の peerId と、先にいた人。後から入った側(自分)が全員へ offer を出す。
  /// 満員なら何もしない([full])。
  Future<void> start(String me, List<String> others) => _enqueue(() async {
        _me = me;
        final targets = [for (final id in others) if (id != me) id];
        if (targets.length + 1 > cap) {
          full = true;
          onChanged?.call();
          return;
        }
        for (final id in targets) {
          await _offer(id);
        }
      });

  /// Central からの `offer` / `answer` / `ice`(`from` と `payload`)。
  Future<void> handle(Map<String, Object?> message) => _enqueue(() async {
        final from = message['from'];
        final payload = message['payload'];
        if (from is! String || payload is! Map || _me == null) return;
        final p = payload.cast<String, Object?>();
        switch (message['type']) {
          case 'offer':
            await _onOffer(from, p);
          case 'answer':
            await _onAnswer(from, p);
          case 'ice':
            await _onIce(from, p);
        }
      });

  /// `peer-left`(キック / BAN も): その相手との接続を閉じる。
  Future<void> peerLeft(String peerId) => _enqueue(() async {
        final l = _links.remove(peerId);
        if (l == null) return;
        await l.link.close();
        if (speaking.contains(peerId)) speaking = {...speaking}..remove(peerId);
        if (_links.isEmpty) _stopLevels();
        onChanged?.call();
      });

  /// 相手の声を鳴らすか: スピーカーミュートなら全員、手元でミュートした相手は鳴らさない。
  void setPlayback({required bool speakerMuted, required Set<String> mutedPeerIds}) {
    _speakerMuted = speakerMuted;
    _muted = mutedPeerIds;
    for (final l in _links.values) {
      l.link.setPlayback(_plays(l.link.peerId));
    }
  }

  bool _plays(String peerId) => !_speakerMuted && !_muted.contains(peerId);

  /// 退出: 全部閉じる。以後のメッセージは捨てる。
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _stopLevels();
    final links = [..._links.values];
    _links.clear();
    speaking = const {};
    for (final l in links) {
      try {
        await l.link.close();
      } catch (e) {
        debugPrint('astell call: close: $e');
      }
    }
  }

  /// peerId の大きいほうが譲る側(polite)。
  bool _polite(String peerId) => _me!.compareTo(peerId) > 0;

  Future<_Link?> _ensure(String peerId, {required bool offerer}) async {
    final have = _links[peerId];
    if (have != null) return have;
    final ice = _ice ??= await iceServers();
    if (_closed) return null;
    _Link? entry;
    final link = await media.createLink(
      peerId,
      offerer: offerer,
      iceServers: ice,
      handlers: AstellLinkHandlers(
        onIceCandidate: (c) {
          final e = entry;
          if (e != null && !_closed && identical(_links[peerId], e)) send({'type': 'ice', 'to': peerId, 'payload': c});
        },
        onState: (s) => _onState(peerId, s),
      ),
    );
    if (_closed) {
      await link.close();
      return null;
    }
    final made = entry = _Link(link, offerer: offerer);
    _links[peerId] = made;
    link.setPlayback(_plays(peerId));
    _startLevels();
    onChanged?.call();
    return made;
  }

  Future<void> _offer(String peerId, {bool iceRestart = false}) async {
    final l = await _ensure(peerId, offerer: true);
    if (l == null) return;
    l.makingOffer = true;
    try {
      final offer = await l.link.createOffer(iceRestart: iceRestart);
      send({'type': 'offer', 'to': peerId, 'payload': offer});
    } finally {
      l.makingOffer = false;
    }
  }

  Future<void> _onOffer(String from, Map<String, Object?> offer) async {
    // 満員(自分 + 接続中が上限)なら、新しい相手の offer は受けない。
    if (full || (!_links.containsKey(from) && _links.length + 1 >= cap)) return;
    final l = await _ensure(from, offerer: false);
    if (l == null) return;
    final collision = l.makingOffer || l.link.signalingState != 'stable';
    l.ignoreOffer = !_polite(from) && collision;
    if (l.ignoreOffer) return;
    if (collision) await l.link.rollback();
    await l.link.setRemoteDescription(offer);
    await _flushIce(l);
    final answer = await l.link.createAnswer();
    send({'type': 'answer', 'to': from, 'payload': answer});
  }

  Future<void> _onAnswer(String from, Map<String, Object?> answer) async {
    final l = _links[from];
    if (l == null || l.link.signalingState != 'have-local-offer') return;
    await l.link.setRemoteDescription(answer);
    await _flushIce(l);
  }

  Future<void> _onIce(String from, Map<String, Object?> candidate) async {
    final l = _links[from];
    if (l == null) return; // 接続の無い相手(offer より先の ice は来ない: WS は順に届く)
    if (!l.link.hasRemoteDescription) {
      l.pendingIce.add(candidate);
      return;
    }
    await _addIce(l, candidate);
  }

  Future<void> _flushIce(_Link l) async {
    final pending = [...l.pendingIce];
    l.pendingIce.clear();
    for (final c in pending) {
      await _addIce(l, c);
    }
  }

  Future<void> _addIce(_Link l, Map<String, Object?> candidate) async {
    try {
      await l.link.addIceCandidate(candidate);
    } catch (e) {
      // 捨てた offer の候補は入らなくてよい。
      if (!l.ignoreOffer) debugPrint('astell call: ice: $e');
    }
  }

  void _onState(String peerId, AstellLinkState s) {
    final l = _links[peerId];
    if (l == null || _closed) return;
    l.state = s;
    // 切れた: offer を出した側が ICE をやり直す。
    if (s == AstellLinkState.failed && l.offerer) {
      unawaited(_enqueue(() => _offer(peerId, iceRestart: true)));
    }
    onChanged?.call();
  }

  void _startLevels() {
    final every = levelInterval;
    if (every == null || _levelTimer != null) return;
    _levelTimer = Timer.periodic(every, (_) => unawaited(pollLevels()));
  }

  void _stopLevels() {
    _levelTimer?.cancel();
    _levelTimer = null;
  }

  bool _polling = false;

  /// 声の大きさを見て、話している人を更新する。変われば [onChanged]。
  Future<void> pollLevels() async {
    if (_polling || _closed) return;
    _polling = true;
    try {
      final next = <String>{};
      for (final l in [..._links.values]) {
        try {
          if (await l.link.remoteAudioLevel() >= astellSpeakingLevel) next.add(l.link.peerId);
        } catch (_) {
          // 統計が取れない(閉じかけ)なら黙っている扱い。
        }
      }
      if (_closed) return;
      if (!setEquals(next, speaking)) {
        speaking = next;
        onChanged?.call();
      }
    } finally {
      _polling = false;
    }
  }
}

class _Link {
  _Link(this.link, {required this.offerer});
  final AstellPeerLink link;

  /// こちらが offer を出した側か(`failed` で ICE をやり直す側)。
  final bool offerer;
  bool makingOffer = false;
  bool ignoreOffer = false;
  AstellLinkState state = AstellLinkState.connecting;

  /// 相手の記述より先に届いた ICE の候補。
  final List<Map<String, Object?>> pendingIce = [];
}
