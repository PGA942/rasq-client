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

  Future<void> close();
}

/// 相手の声を鳴らす口 (D-318)。Web は受けた音声を `<audio>` に繋がないと鳴らない(ネイティブは受けたトラックが
/// そのまま鳴るので要らない)。実物は `astell_web_audio_web.dart`、テストは偽物。
abstract class AstellRemoteAudio {
  /// 鳴らす / 止める(スピーカーミュート / 手元のミュート)。
  void setMuted(bool muted);

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
        AstellMediaIssue.permissionDenied => 'マイク(カメラ)を使う許可がありません。端末の設定で RASQ に許可してください',
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
