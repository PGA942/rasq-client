import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../settings/settings_dsl.dart';
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

/// アップロード前の圧縮 (D-145): Central は `zstd` を期待する。Dart 側の zstd
/// コーデック(`zstd_dart` / `dart_zstd`、いずれも FFI)は実機ビルドで検証してから
/// 差し込む — それまでは無圧縮(`identity`)で送る。サーバーは両方受ける。
class AstellAssetCodec {
  const AstellAssetCodec({required this.encoding, required this.encode});
  final String encoding;
  final List<int> Function(List<int> bytes) encode;
  static const identity = AstellAssetCodec(encoding: 'identity', encode: _same);
  static List<int> _same(List<int> b) => b;
}

final astellAssetCodecProvider = Provider<AstellAssetCodec>((ref) => AstellAssetCodec.identity);

/// 「共有する」のファイル選択 (D-142)。テストは差し替える。
final astellMediaPickerProvider = Provider<Future<XFile?> Function()>((ref) => () => ImagePicker().pickMedia());

/// 共有欄の自動表示設定 (D-146): チャットに流れたものをメディアタイプごとに
/// 自動で「共有」欄へ出すか。KV `astell.v1` の `auto.<class>`。既定は画像・動画のみ。
const astellSettingsArea = 'astell';
const astellShareClasses = <({String id, String label})>[
  (id: 'image', label: '画像'),
  (id: 'video', label: '動画'),
  (id: 'file', label: 'ファイル'),
  (id: 'link', label: 'リンク'),
  (id: 'post', label: '投稿'),
  (id: 'text', label: 'テキスト'),
  (id: 'transcript', label: '文字起こし'),
];
const _astellAutoDefaults = {'image': true, 'video': true};

final astellAutoShareProvider = Provider<Map<String, bool>>((ref) {
  final area = ref.watch(settingsAreaProvider(astellSettingsArea)).value ?? const <String, Object?>{};
  return {for (final c in astellShareClasses) c.id: (area['auto.${c.id}'] as bool?) ?? (_astellAutoDefaults[c.id] ?? false)};
});

/// 自動再生 (D-147): ピアの画面共有が始まったら(参加時に既にあるものも)共有枠に自動で出す。
/// KV `autoplay.screen`、既定オン。
final astellAutoPlayProvider = Provider<bool>((ref) {
  final area = ref.watch(settingsAreaProvider(astellSettingsArea)).value ?? const <String, Object?>{};
  return (area['autoplay.screen'] as bool?) ?? true;
});

/// 自分がフォローしている RASQ アカウント (D-149)。
final astellFollowingProvider = FutureProvider<Set<String>>((ref) => ref.watch(astellClientProvider).following());

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
    this.myAccountId,
    this.peers = const [],
    this.shares = const [],
    this.transcripts = const [],
    this.connected = false,
    this.micOn = false,
    this.captionsOn = true,
    this.screenShareOn = false,
    this.viewingPeerId,
    this.mutedPeerIds = const {},
    this.speakerMuted = false,
    this.forceMuted = false,
    this.error,
  });
  final AstellRoom room;
  final String? myPeerId;

  /// 自分の RASQ アカウント id(welcome の `accountId`)。役割の判定に使う。
  final String? myAccountId;
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

  /// 共有枠に表示している(ピン留め/クリックした)ピアの画面共有 (D-146)。
  final String? viewingPeerId;

  /// 手元でミュートしたピア (D-147)。音声は M5 後段なので今は表示と台帳だけ。
  final Set<String> mutedPeerIds;

  /// スピーカーミュート (D-148): 受け取る音声を全部止める(音声は M5 後段)。
  final bool speakerMuted;

  /// モデレーターに全員向けミュートされている (D-149)。マイクは立てられない。
  final bool forceMuted;
  final String? error;

  bool isMuted(String peerId) => mutedPeerIds.contains(peerId);

  /// 役割 (D-149): オーナー / モデレーター(オーナー含む)。
  bool get isOwner => myAccountId != null && room.ownerId == myAccountId;
  bool get isModerator => room.isModerator(myAccountId);

  AstellPeer? get viewingPeer => viewingPeerId == null ? null : peers.where((p) => p.peerId == viewingPeerId && p.screenShare != null).firstOrNull;

  AstellSessionState copyWith({
    AstellRoom? room,
    String? myPeerId,
    String? myAccountId,
    List<AstellPeer>? peers,
    List<AstellShare>? shares,
    List<AstellTranscript>? transcripts,
    bool? connected,
    bool? micOn,
    bool? captionsOn,
    bool? screenShareOn,
    String? viewingPeerId,
    bool clearViewing = false,
    Set<String>? mutedPeerIds,
    bool? speakerMuted,
    bool? forceMuted,
    String? error,
    bool clearError = false,
  }) =>
      AstellSessionState(
        room: room ?? this.room,
        myPeerId: myPeerId ?? this.myPeerId,
        myAccountId: myAccountId ?? this.myAccountId,
        peers: peers ?? this.peers,
        shares: shares ?? this.shares,
        transcripts: transcripts ?? this.transcripts,
        connected: connected ?? this.connected,
        micOn: micOn ?? this.micOn,
        captionsOn: captionsOn ?? this.captionsOn,
        screenShareOn: screenShareOn ?? this.screenShareOn,
        viewingPeerId: clearViewing ? null : (viewingPeerId ?? this.viewingPeerId),
        mutedPeerIds: mutedPeerIds ?? this.mutedPeerIds,
        speakerMuted: speakerMuted ?? this.speakerMuted,
        forceMuted: forceMuted ?? this.forceMuted,
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
          myAccountId: m['accountId'] as String?,
          // S-006: welcome にルーム(モデレーター / ポリシー)が載る。
          room: m['room'] is Map ? AstellRoom.fromJson((m['room'] as Map).cast<String, Object?>()) : null,
          peers: peersOf(m['peers']),
          shares: [for (final x in (m['shares'] as List? ?? const [])) if (x is Map) AstellShare.fromJson(x.cast<String, Object?>())],
          transcripts: [for (final x in (m['transcripts'] as List? ?? const [])) if (x is Map) AstellTranscript.fromJson(x.cast<String, Object?>())],
        );
        _autoPlay(state!.peers.where((p) => p.peerId != state!.myPeerId && p.screenShare != null).firstOrNull);
      case 'peer-joined':
        final p = m['peer'];
        if (p is Map) state = s.copyWith(peers: [...s.peers, AstellPeer.fromJson(p.cast<String, Object?>())]);
      case 'peer-left':
        state = s.copyWith(peers: [for (final p in s.peers) if (p.peerId != m['peerId']) p]);
      case 'share':
        final x = m['share'];
        if (x is Map) {
          final sh = AstellShare.fromJson(x.cast<String, Object?>());
          // 同じ id はピン留め等の更新 (D-146)。
          state = s.copyWith(shares: s.shares.any((e) => e.id == sh.id) ? [for (final e in s.shares) e.id == sh.id ? sh : e] : [...s.shares, sh]);
        }
      case 'peer-state':
        final p = m['peer'];
        if (p is Map) {
          final peer = AstellPeer.fromJson(p.cast<String, Object?>());
          if (peer.peerId == s.myPeerId) {
            // 自分の状態の折り返しは参加者に入れない。強制ミュート (D-149) だけ拾う。
            if (peer.mutedByMod != s.forceMuted) state = s.copyWith(forceMuted: peer.mutedByMod, micOn: peer.mutedByMod ? false : null);
            break;
          }
          final before = s.peers.where((e) => e.peerId == peer.peerId).firstOrNull;
          state = s.copyWith(
            peers: before != null ? [for (final e in s.peers) e.peerId == peer.peerId ? peer : e] : [...s.peers, peer],
            // 表示中のピアが共有をやめたら共有枠を閉じる。
            clearViewing: s.viewingPeerId == peer.peerId && peer.screenShare == null,
          );
          // 画面共有が**始まった**ら自動再生 (D-147)。
          if (peer.screenShare != null && before?.screenShare == null) _autoPlay(peer);
        }
      case 'share-removed':
        state = s.copyWith(shares: [for (final x in s.shares) if (x.id != m['shareId']) x]);
      case 'transcript':
        final x = m['transcript'];
        if (x is Map) {
          final t = AstellTranscript.fromJson(x.cast<String, Object?>());
          state = s.copyWith(transcripts: s.transcripts.any((e) => e.id == t.id) ? [for (final e in s.transcripts) e.id == t.id ? t : e] : [...s.transcripts, t]);
        }
      case 'room':
        final x = m['room'];
        if (x is Map) state = s.copyWith(room: AstellRoom.fromJson(x.cast<String, Object?>()));
      case 'closed':
        state = s.copyWith(connected: false, error: 'ホストがルームを終了しました');
      case 'kicked':
        // モデレーションで追い出された (D-149)。接続は切る(状態は残して案内を出す)。
        state = s.copyWith(connected: false, error: m['reason'] == 'banned' ? 'このルームから BAN されました' : 'モデレーターにルームから退出させられました');
        unawaited(_teardown());
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

  /// 自分の状態(マイク / 画面共有)を全員へ (D-146: `state` メッセージ)。
  void _sendState() {
    final s = state;
    if (s == null) return;
    _conn?.send({
      'type': 'state',
      'state': {
        'micOn': s.micOn,
        'screenShare': s.screenShareOn ? const AstellScreenShare(title: '自分の画面').toJson() : null,
      },
    });
  }

  void toggleMic() {
    if (state == null || state!.forceMuted) return; // 強制ミュート中は立てられない
    state = state!.copyWith(micOn: !state!.micOn);
    _sendState();
  }

  // ── モデレーション (D-149) ──
  Future<void> setModerator(String accountId, bool moderator) async {
    final s = state;
    if (s == null) return;
    final room = await ref.read(astellClientProvider).setModerator(s.room.id, accountId, moderator);
    if (state != null) state = state!.copyWith(room: room);
  }

  Future<void> kick(String peerId) async {
    final s = state;
    if (s == null) return;
    await ref.read(astellClientProvider).kickPeer(s.room.id, peerId);
    if (state != null) state = state!.copyWith(peers: [for (final p in state!.peers) if (p.peerId != peerId) p], clearViewing: state!.viewingPeerId == peerId);
  }

  Future<void> mutePeer(String peerId, bool muted) async {
    final s = state;
    if (s == null) return;
    final p = await ref.read(astellClientProvider).mutePeer(s.room.id, peerId, muted);
    if (state != null) state = state!.copyWith(peers: [for (final e in state!.peers) e.peerId == peerId ? p : e]);
  }

  Future<List<AstellBan>> ban(String accountId, {String? reason}) async {
    final s = state;
    if (s == null) return const [];
    final bans = await ref.read(astellClientProvider).ban(s.room.id, accountId, reason: reason);
    if (state != null) state = state!.copyWith(peers: [for (final p in state!.peers) if (p.accountId != accountId) p]);
    return bans;
  }

  Future<void> follow(String accountId, bool follow) async {
    await ref.read(astellClientProvider).follow(accountId, follow);
    ref.invalidate(astellFollowingProvider);
    ref.invalidate(astellHomeProvider);
  }

  /// 自動再生 (D-147): 設定がオンで、共有枠が空いていれば [peer] の画面を出す。
  void _autoPlay(AstellPeer? peer) {
    final s = state;
    if (s == null || peer == null || s.viewingPeerId != null) return;
    if (!ref.read(astellAutoPlayProvider)) return;
    state = s.copyWith(viewingPeerId: peer.peerId);
  }

  /// スピーカーミュート切替 (D-148)。
  void toggleSpeaker() {
    if (state != null) state = state!.copyWith(speakerMuted: !state!.speakerMuted);
  }

  /// ピアを手元でミュート/解除 (D-147)。
  void toggleMute(String peerId) {
    final s = state;
    if (s == null) return;
    final next = {...s.mutedPeerIds};
    if (!next.remove(peerId)) next.add(peerId);
    state = s.copyWith(mutedPeerIds: next);
  }

  /// ピアの画面共有を共有枠に表示する/やめる (D-146)。
  void viewScreen(String? peerId) {
    if (state == null) return;
    state = peerId == null ? state!.copyWith(clearViewing: true) : state!.copyWith(viewingPeerId: peerId);
  }

  Future<void> pinShare(String shareId, bool pinned) async {
    final s = state;
    if (s == null) return;
    final updated = await ref.read(astellClientProvider).pinShare(s.room.id, shareId, pinned);
    if (state != null) state = state!.copyWith(shares: [for (final e in state!.shares) e.id == shareId ? updated : e]);
  }

  Future<void> pinTranscript(String transcriptId, bool pinned) async {
    final s = state;
    if (s == null) return;
    final updated = await ref.read(astellClientProvider).pinTranscript(s.room.id, transcriptId, pinned);
    if (state != null) state = state!.copyWith(transcripts: [for (final e in state!.transcripts) e.id == transcriptId ? updated : e]);
  }

  void toggleCaptions() {
    if (state != null) state = state!.copyWith(captionsOn: !state!.captionsOn);
  }

  void toggleScreenShare() {
    if (state == null) return;
    state = state!.copyWith(screenShareOn: !state!.screenShareOn);
    _sendState();
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
