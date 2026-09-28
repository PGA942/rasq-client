import 'package:flutter/foundation.dart';

import 'astell_web_audio.dart' show astellBrowserSecureContext;

/// AsTell の通話の音声 (D-317) の境界。
///
/// 通話はピア同士の WebRTC(音声だけのメッシュ)。シグナリングは Central の WS の
/// `offer` / `answer` / `ice` を使い、手順(誰が offer を出すか、ICE の控え、ぶつかったときの譲り方)は
/// [AstellCallMesh](`astell_call.dart`)が持つ。ここはその下の**薄い口**だけ — 実物は flutter_webrtc
/// (`astell_media_webrtc.dart`)、テストは偽物、モックのルームは [NullAstellMedia](何もしない)。
///
/// 送る音は 1 本のマイクを全員に。相手ごとの接続は、はじめから送受信の音声 1 本を持ち、マイクを
/// 開く / 閉じるは中身の差し替え(`replaceTrack`)だけなので、繋ぎ直し(再ネゴシエーション)は起きない。
abstract class AstellMedia {
  /// 通話を扱えるか。偽の / 何もしない口は false(セッションはメッシュを作らない)。
  bool get available;

  /// マイクを開けない理由(Web の http など)。開けるなら null。
  AstellMediaIssue? get micBlocked;

  /// マイクを開いたか([openMic] のあと)。
  bool get micOpen;

  /// マイクを開く(OS の許可を求める)。開けなければ [AstellMediaException]。開いた直後は送らない
  /// ([setMicEnabled] で送り始める)。
  Future<void> openMic();

  /// マイクの音を送る / 止める(開いていなければ何もしない)。
  void setMicEnabled(bool enabled);

  /// 相手 1 人との接続を作る。[offerer] = こちらが offer を出す側(送受信の音声 1 本を先に足す)。
  Future<AstellPeerLink> createLink(String peerId, {required bool offerer, required List<Map<String, Object?>> iceServers, required AstellLinkHandlers handlers});

  /// マイクを閉じて、残っている接続も閉じる(退出)。
  Future<void> dispose();
}

/// 相手 1 人との接続(RTCPeerConnection 1 本)。
abstract class AstellPeerLink {
  String get peerId;

  /// `stable` / `have-local-offer` / `have-remote-offer` / `closed` など(W3C の綴り)。
  String get signalingState;

  /// 相手の記述を入れたか(ICE の候補を入れてよいか)。
  bool get hasRemoteDescription;

  /// offer を作って自分の記述に入れ、`{sdp, type}` を返す。
  Future<Map<String, Object?>> createOffer({bool iceRestart = false});

  /// answer を作って自分の記述に入れ、`{sdp, type}` を返す。
  Future<Map<String, Object?>> createAnswer();

  /// 相手の `{sdp, type}` を入れる。
  Future<void> setRemoteDescription(Map<String, Object?> description);

  /// 出しかけの offer を取り下げる(offer がぶつかって譲る側)。
  Future<void> rollback();

  /// 相手の ICE の候補 `{candidate, sdpMid, sdpMLineIndex}` を入れる。
  Future<void> addIceCandidate(Map<String, Object?> candidate);

  /// 相手の声を鳴らすか(スピーカーミュート / 手元のミュート)。
  void setPlayback(bool on);

  /// 相手の声の大きさ(0〜1、受けている音声の audioLevel)。話している印に使う。
  Future<double> remoteAudioLevel();

  /// 接続の様子(開発者向けの表示、D-323)。
  Future<AstellLinkDiagnostics> diagnostics();

  Future<void> close();
}

/// 相手の声を鳴らす口 (D-318)。Web は受けた音声を `<audio>` に繋がないと鳴らない(ネイティブは受けたトラックが
/// そのまま鳴るので要らない)。実物は `astell_web_audio_web.dart`、テストは偽物。
abstract class AstellRemoteAudio {
  /// 鳴らす / 止める(スピーカーミュート / 手元のミュート)。
  void setMuted(bool muted);

  /// いまの様子 (D-323): `playing` / `blocked`(自動再生の制限で止められ、次の操作を待っている)/ `muted` / `paused` / `closed`。
  String get state;

  /// `<audio>` を外す。
  Future<void> dispose();
}

/// 接続の出来事の受け口。
@immutable
class AstellLinkHandlers {
  const AstellLinkHandlers({required this.onIceCandidate, required this.onState});

  /// 自分の ICE の候補ができた(`{candidate, sdpMid, sdpMLineIndex}`)。相手へ `ice` で送る。
  final void Function(Map<String, Object?> candidate) onIceCandidate;

  /// 接続の状態が変わった。
  final void Function(AstellLinkState state) onState;
}

enum AstellLinkState { connecting, connected, disconnected, failed, closed }

/// マイクや相手の音を扱えない理由。
enum AstellMediaIssue {
  /// Web 版を http(localhost 以外)で開いている。getUserMedia は安全な場所 (https) でしか使えない。
  insecureContext,

  /// OS / ブラウザでマイクが許可されていない。
  permissionDenied,

  /// マイクが無い。
  noDevice,

  /// そのほか(この端末では使えない等)。
  unsupported,
}

class AstellMediaException implements Exception {
  const AstellMediaException(this.issue, [this.detail]);
  final AstellMediaIssue issue;
  final String? detail;

  /// 画面に出す 1 行。
  String get message => switch (issue) {
        AstellMediaIssue.insecureContext => 'Web 版の通話は https で開いたときだけ使えます',
        AstellMediaIssue.permissionDenied => 'マイク(カメラ)の許可がありません。端末の設定で許可してください',
        AstellMediaIssue.noDevice => 'マイク(カメラ)が見つかりません',
        AstellMediaIssue.unsupported => 'この端末では使えません${detail == null ? '' : '($detail)'}',
      };

  @override
  String toString() => message;

  /// プラットフォームの例外を言い換える(`NotAllowedError` / `Permission denied` など)。
  static AstellMediaException from(Object error) {
    if (error is AstellMediaException) return error;
    final s = '$error';
    final l = s.toLowerCase();
    if (l.contains('notallowed') || l.contains('permission') || l.contains('denied') || l.contains('securityerror')) {
      return const AstellMediaException(AstellMediaIssue.permissionDenied);
    }
    if (l.contains('notfound') || l.contains('no audio') || l.contains('no device') || l.contains('requested device not found')) {
      return const AstellMediaException(AstellMediaIssue.noDevice);
    }
    return AstellMediaException(AstellMediaIssue.unsupported, s.length > 120 ? '${s.substring(0, 120)}…' : s);
  }
}

/// Web 版が安全でない場所(http で、localhost 以外)で開かれているか。getUserMedia / 画面の取り込みは
/// https か localhost でしか使えない。ブラウザが答えられれば `window.isSecureContext` をそのまま使い(https なら
/// マイクを使える)、答えられないときだけページの URL で決める。[page] / [secureContext] はテスト用。
bool astellInsecureWebContext({bool web = kIsWeb, Uri? page, bool? secureContext}) {
  if (!web) return false;
  final secure = secureContext ?? (page == null ? astellBrowserSecureContext() : null);
  if (secure != null) return !secure;
  final u = page ?? Uri.base;
  if (u.scheme != 'http') return false;
  return !const {'localhost', '127.0.0.1', '::1', '[::1]'}.contains(u.host);
}

/// 何もしない口(Central に繋がっていないモックのルーム)。通話は作らない。
class NullAstellMedia implements AstellMedia {
  @override
  bool get available => false;
  @override
  AstellMediaIssue? get micBlocked => null;
  @override
  bool get micOpen => false;
  @override
  Future<void> openMic() async {}
  @override
  void setMicEnabled(bool enabled) {}
  @override
  Future<AstellPeerLink> createLink(String peerId, {required bool offerer, required List<Map<String, Object?>> iceServers, required AstellLinkHandlers handlers}) =>
      throw StateError('NullAstellMedia does not make calls');
  @override
  Future<void> dispose() async {}
}

// ── 接続の様子(開発者向け、D-323) ──
// 実機でしか起きない「繋がったのに聞こえない」を切り分けるため、ICE の状態・出した / 受けた候補の種類・選ばれた
// 候補の組・送受信のバイト数・Web の `<audio>` の様子を 1 か所に集める。設定の「接続の状態(開発者向け)」とログに出す。

/// ICE の候補 1 行(`candidate:… <address> <port> typ <type> …`)の種類。`host` / `host(mDNS)` / `srflx` / `prflx` /
/// `relay`、TCP なら `/tcp` を付ける。空(候補の終わり)や読めない行は null。
/// ブラウザは自分の host 候補の IP を `<uuid>.local`(mDNS)で隠す — 相手がそれを引けなければ、その候補には繋がらない。
String? astellCandidateKind(String? candidate) {
  if (candidate == null) return null;
  final f = candidate.trim().split(RegExp(r'\s+'));
  final typ = f.indexOf('typ');
  if (typ < 0 || typ + 1 >= f.length || f.length < 6) return null;
  final type = f[typ + 1];
  final mdns = type == 'host' && f[4].toLowerCase().endsWith('.local');
  final tcp = f[2].toLowerCase() == 'tcp';
  return '$type${mdns ? '(mDNS)' : ''}${tcp ? '/tcp' : ''}';
}

/// `getStats()` の報告 1 つ(W3C の名前: `transport` / `candidate-pair` / `local-candidate` / `remote-candidate` /
/// `inbound-rtp` / `outbound-rtp` …)。
typedef AstellStatsReport = ({String id, String type, Map<Object?, Object?> values});

/// 接続の統計のまとめ (D-323)。取れなかったものは null。
@immutable
class AstellRtcStats {
  const AstellRtcStats({this.pairState, this.localCandidate, this.remoteCandidate, this.bytesSent, this.bytesReceived, this.packetsReceived, this.packetsLost, this.audioLevel});

  /// 選ばれた候補の組の状態(`succeeded` など)。
  final String? pairState;

  /// 選ばれた組の自分 / 相手の候補(`prflx udp 100.64.0.1:50000` の形)。
  final String? localCandidate;
  final String? remoteCandidate;

  /// 音声の送った / 受けたバイト数(`outbound-rtp` / `inbound-rtp`)。
  final int? bytesSent;
  final int? bytesReceived;
  final int? packetsReceived;
  final int? packetsLost;

  /// 受けている声の大きさ(0〜1)。
  final double? audioLevel;

  /// 報告からまとめる。選ばれた組は `transport.selectedCandidatePairId`、無ければ `selected` / `nominated` で
  /// `succeeded` の組(ブラウザとネイティブで持ち方が違う)。
  static AstellRtcStats from(Iterable<AstellStatsReport> reports) {
    final byId = {for (final r in reports) r.id: r};
    int? asInt(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
    double? asDouble(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
    bool isAudio(Map<Object?, Object?> v) => v['kind'] == 'audio' || v['mediaType'] == 'audio';

    AstellStatsReport? pair;
    for (final r in reports) {
      final id = r.values['selectedCandidatePairId'];
      if (r.type == 'transport' && id is String && byId[id] != null) pair = byId[id];
    }
    final pairs = [for (final r in reports) if (r.type == 'candidate-pair') r];
    pair ??= pairs.where((r) => r.values['selected'] == true).firstOrNull;
    pair ??= pairs.where((r) => r.values['nominated'] == true && r.values['state'] == 'succeeded').firstOrNull;
    pair ??= pairs.where((r) => r.values['state'] == 'succeeded').firstOrNull;

    String? candidate(Object? id) {
      final c = id is String ? byId[id] : null;
      if (c == null) return null;
      final v = c.values;
      final address = v['address'] ?? v['ip'];
      final port = v['port'];
      return [v['candidateType'], v['protocol'], if (address != null) '$address${port != null ? ':$port' : ''}'].whereType<Object>().join(' ');
    }

    int? bytesSent, bytesReceived, packetsReceived, packetsLost;
    double? level;
    for (final r in reports) {
      final v = r.values;
      if (!isAudio(v)) continue;
      if (r.type == 'inbound-rtp') {
        bytesReceived = (bytesReceived ?? 0) + (asInt(v['bytesReceived']) ?? 0);
        packetsReceived = (packetsReceived ?? 0) + (asInt(v['packetsReceived']) ?? 0);
        packetsLost = (packetsLost ?? 0) + (asInt(v['packetsLost']) ?? 0);
        final l = asDouble(v['audioLevel']);
        if (l != null && l > (level ?? -1)) level = l;
      } else if (r.type == 'outbound-rtp') {
        bytesSent = (bytesSent ?? 0) + (asInt(v['bytesSent']) ?? 0);
      }
    }
    return AstellRtcStats(
      pairState: pair?.values['state'] as String?,
      localCandidate: candidate(pair?.values['localCandidateId']),
      remoteCandidate: candidate(pair?.values['remoteCandidateId']),
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
      packetsReceived: packetsReceived,
      packetsLost: packetsLost,
      audioLevel: level,
    );
  }
}

/// 相手 1 人との接続の様子 (D-323)。
@immutable
class AstellLinkDiagnostics {
  const AstellLinkDiagnostics({
    required this.peerId,
    this.connectionState,
    this.iceConnectionState,
    this.iceGatheringState,
    this.signalingState,
    this.localCandidates = const {},
    this.remoteCandidates = const {},
    this.stats = const AstellRtcStats(),
    this.remoteAudio = false,
    this.playout,
    this.micAttached = false,
  });

  final String peerId;

  /// W3C の綴り(`new` / `connecting` / `connected` / `disconnected` / `failed` / `closed` など)。
  final String? connectionState;
  final String? iceConnectionState;
  final String? iceGatheringState;
  final String? signalingState;

  /// 出した / 受けた ICE の候補の種類ごとの数([astellCandidateKind])。
  final Map<String, int> localCandidates;
  final Map<String, int> remoteCandidates;
  final AstellRtcStats stats;

  /// 相手の声のトラックを受けたか(`ontrack`)。
  final bool remoteAudio;

  /// Web の `<audio>` の様子([AstellRemoteAudio.state])。ネイティブは null(繋がなくても鳴る)。
  final String? playout;

  /// 送る側にマイクを差し込んだか。
  final bool micAttached;

  /// 表示とログの行。
  List<String> lines() {
    String tally(Map<String, int> m) => m.isEmpty ? 'なし' : [for (final e in m.entries) '${e.key}×${e.value}'].join(' ');
    String num(int? v) => v == null ? '-' : '$v';
    final s = stats;
    return [
      '接続 ${connectionState ?? '-'} / ICE ${iceConnectionState ?? '-'}(収集 ${iceGatheringState ?? '-'})/ SDP ${signalingState ?? '-'}',
      '候補: 自分 ${tally(localCandidates)} / 相手 ${tally(remoteCandidates)}',
      '選ばれた組: ${s.pairState ?? 'なし'}${s.localCandidate != null || s.remoteCandidate != null ? '(自分 ${s.localCandidate ?? '?'} ⇄ 相手 ${s.remoteCandidate ?? '?'})' : ''}',
      '音声: 送 ${num(s.bytesSent)} B / 受 ${num(s.bytesReceived)} B(${num(s.packetsReceived)} パケット、欠 ${num(s.packetsLost)})/ 声の大きさ ${s.audioLevel?.toStringAsFixed(3) ?? '-'}',
      '相手の声: ${remoteAudio ? '受けた' : 'まだ'}${playout != null ? ' / <audio> $playout' : ''} / マイク: ${micAttached ? '差し込み済み' : 'まだ'}',
    ];
  }
}
