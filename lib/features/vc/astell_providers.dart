import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import 'astell_client.dart';
import 'astell_models.dart';

/// AsTell クライアント (D-139)。Central に繋がっていれば HTTP、無ければモック。
final astellClientProvider = Provider<AstellClient>((ref) {
  final client = ref.watch(centralClientProvider);
  final base = ref.watch(centralBaseUrlProvider);
  if (client == null || base == null) return MockAstellClient();
  final holder = ref.read(orgateTokenHolderProvider);
  return HttpAstellClient(client, baseUrl: base, token: () => holder.token);
});

/// 「共有する」のファイル選択 (D-142)。テストは差し替える。
final astellMediaPickerProvider = Provider<Future<XFile?> Function()>((ref) => () => ImagePicker().pickMedia());

/// VC ホームの 3 節。
final astellHomeProvider = FutureProvider<AstellHome>((ref) => ref.watch(astellClientProvider).home());

/// 参加 FOW の「参加メンバー」(接続前のプレビュー)。
final astellPeersProvider = FutureProvider.family<List<AstellPeer>, String>((ref, id) => ref.watch(astellClientProvider).peers(id));

/// 接続中のルームの状態。
@immutable
class AstellSessionState {
  const AstellSessionState({
    required this.room,
    this.myPeerId,
    this.peers = const [],
    this.shares = const [],
    this.transcripts = const [],
    this.connected = false,
    this.micOn = false,
    this.captionsOn = true,
    this.screenShareOn = false,
    this.error,
  });
  final AstellRoom room;
  final String? myPeerId;
  final List<AstellPeer> peers;
  final List<AstellShare> shares;
  final List<AstellTranscript> transcripts;
  final bool connected;

  /// マイク(音声は M5 後段 — 今は表示状態だけ)。
  final bool micOn;

  /// 字幕(文字起こしの表示)。
  final bool captionsOn;

  /// 画面共有モード(映像は M5 後段 — 今は表示状態だけ)。
  final bool screenShareOn;
  final String? error;

  AstellSessionState copyWith({
    AstellRoom? room,
    String? myPeerId,
    List<AstellPeer>? peers,
    List<AstellShare>? shares,
    List<AstellTranscript>? transcripts,
    bool? connected,
    bool? micOn,
    bool? captionsOn,
    bool? screenShareOn,
    String? error,
    bool clearError = false,
  }) =>
      AstellSessionState(
        room: room ?? this.room,
        myPeerId: myPeerId ?? this.myPeerId,
        peers: peers ?? this.peers,
        shares: shares ?? this.shares,
        transcripts: transcripts ?? this.transcripts,
        connected: connected ?? this.connected,
        micOn: micOn ?? this.micOn,
        captionsOn: captionsOn ?? this.captionsOn,
        screenShareOn: screenShareOn ?? this.screenShareOn,
        error: clearError ? null : (error ?? this.error),
      );
}

/// ルーム接続の状態機械 (D-139): join → welcome で確定 → peer-joined/left /
/// share / transcript / room / closed を反映 → leave で切る。同時に 1 ルーム。
/// WebRTC のメディアはまだ繋がない(offer/answer は受け流す。M5 後段)。
class AstellSession extends Notifier<AstellSessionState?> {
  AstellConnection? _conn;
  StreamSubscription<Map<String, Object?>>? _sub;

  @override
  AstellSessionState? build() {
    ref.onDispose(() => _teardown());
    return null;
  }

  Future<void> join(AstellRoom room) async {
    await leave();
    state = AstellSessionState(room: room);
    try {
      final conn = await ref.read(astellClientProvider).connect(room.id);
      _conn = conn;
      _sub = conn.messages.listen(_onMessage, onError: (Object e) => _fail('$e'), onDone: () {
        if (state != null) state = state!.copyWith(connected: false);
      });
    } catch (e) {
      _fail('接続に失敗しました: $e');
    }
  }

  void _fail(String message) {
    debugPrint('astell: $message');
    if (state != null) state = state!.copyWith(connected: false, error: message);
  }

  void _onMessage(Map<String, Object?> m) {
    final s = state;
    if (s == null) return;
    List<AstellPeer> peersOf(Object? v) => [for (final p in (v as List? ?? const [])) if (p is Map) AstellPeer.fromJson(p.cast<String, Object?>())];
    switch (m['type']) {
      case 'welcome':
        state = s.copyWith(
          connected: true,
          clearError: true,
          myPeerId: m['peerId'] as String?,
          peers: peersOf(m['peers']),
          shares: [for (final x in (m['shares'] as List? ?? const [])) if (x is Map) AstellShare.fromJson(x.cast<String, Object?>())],
          transcripts: [for (final x in (m['transcripts'] as List? ?? const [])) if (x is Map) AstellTranscript.fromJson(x.cast<String, Object?>())],
        );
      case 'peer-joined':
        final p = m['peer'];
        if (p is Map) state = s.copyWith(peers: [...s.peers, AstellPeer.fromJson(p.cast<String, Object?>())]);
      case 'peer-left':
        state = s.copyWith(peers: [for (final p in s.peers) if (p.peerId != m['peerId']) p]);
      case 'share':
        final x = m['share'];
        if (x is Map) state = s.copyWith(shares: [...s.shares, AstellShare.fromJson(x.cast<String, Object?>())]);
      case 'share-removed':
        state = s.copyWith(shares: [for (final x in s.shares) if (x.id != m['shareId']) x]);
      case 'transcript':
        final x = m['transcript'];
        if (x is Map) state = s.copyWith(transcripts: [...s.transcripts, AstellTranscript.fromJson(x.cast<String, Object?>())]);
      case 'room':
        final x = m['room'];
        if (x is Map) state = s.copyWith(room: AstellRoom.fromJson(x.cast<String, Object?>()));
      case 'closed':
        state = s.copyWith(connected: false, error: 'ホストがルームを終了しました');
      case 'error':
        state = s.copyWith(error: m['message'] as String?);
      default:
        // offer / answer / ice はメディア接続(M5 後段)で扱う。
        break;
    }
  }

  void share(String kind, Map<String, Object?> payload) => _conn?.send({'type': 'share', 'kind': kind, 'payload': payload});

  /// ルーム設定の更新結果(PATCH の応答)を反映する。
  void applyRoom(AstellRoom room) {
    if (state != null) state = state!.copyWith(room: room);
  }

  void toggleMic() {
    if (state != null) state = state!.copyWith(micOn: !state!.micOn);
  }

  void toggleCaptions() {
    if (state != null) state = state!.copyWith(captionsOn: !state!.captionsOn);
  }

  void toggleScreenShare() {
    if (state != null) state = state!.copyWith(screenShareOn: !state!.screenShareOn);
  }

  /// 共有の削除(自分の共有 or ルームオーナー)。サーバーの `share-removed` で
  /// 全員に反映されるが、モック/遅延に備えて手元も先に消す。
  Future<void> removeShare(String shareId) async {
    final s = state;
    if (s == null) return;
    await ref.read(astellClientProvider).deleteShare(s.room.id, shareId);
    if (state != null) state = state!.copyWith(shares: [for (final x in state!.shares) if (x.id != shareId) x]);
  }

  Future<void> leave() async {
    await _teardown();
    state = null;
  }

  /// 切断は待たない — ソケットの close 完了(相手側の done 配送)に UI を
  /// 引きずられないため。購読は先に外すので、以後のメッセージは無視される。
  Future<void> _teardown() async {
    final sub = _sub;
    final conn = _conn;
    _sub = null;
    _conn = null;
    unawaited(sub?.cancel());
    unawaited(conn?.close().catchError((Object e) => debugPrint('astell: close: $e')));
  }
}

final astellSessionProvider = NotifierProvider<AstellSession, AstellSessionState?>(AstellSession.new);
