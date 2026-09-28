import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/redact.dart';
import '../child_safe/child_gate.dart';
import '../child_safe/child_safe_policy.dart';
import '../settings/settings_dsl.dart';
import '../../session/session_providers.dart';
import 'astell_call.dart';
import 'astell_client.dart';
import 'astell_media.dart';
import 'astell_media_webrtc.dart';
import 'astell_models.dart';
import 'astell_stream.dart';
import 'astell_stream_livekit.dart';
import 'astell_web_audio.dart' show astellAudioAwaitingGesture, astellPrimeAudioOnGesture;
import 'hold_music.dart';

/// AsTell クライアント (D-139)。Central に繋がっていれば HTTP、無ければモック。
final astellClientProvider = Provider<AstellClient>((ref) {
  final client = ref.watch(centralClientProvider);
  final base = ref.watch(centralBaseUrlProvider);
  // RASQ アカウントを切り替えたら作り直す(D-316: フォロー / ブロック / ホームは、アカウントごと)。
  ref.watch(currentCentralAccountIdProvider);
  if (client == null || base == null) return MockAstellClient();
  final holder = ref.read(orgateTokenHolderProvider);
  return HttpAstellClient(client, baseUrl: base, token: () => holder.token);
});

/// 通話の音声の口 (D-317)。ルームに入るたびに 1 つ作る。Central に繋がっていれば flutter_webrtc、
/// モックのルームは何もしない口(通話は作らない)。テストは偽物に差し替える。
final astellMediaFactoryProvider = Provider<AstellMedia Function()>((ref) {
  if (ref.watch(astellClientProvider) is MockAstellClient) return NullAstellMedia.new;
  return WebRtcAstellMedia.new;
});

/// 配信の口 (D-317)。LiveKit、モックのルームは何も映さない口。
final astellStreamerFactoryProvider = Provider<AstellStreamer Function()>((ref) {
  if (ref.watch(astellClientProvider) is MockAstellClient) return NullAstellStreamer.new;
  return LiveKitAstellStreamer.new;
});

/// 話している印のために声の大きさを見る間隔 (D-317)。null なら見ない(テスト)。
final astellLevelIntervalProvider = Provider<Duration?>((ref) => const Duration(milliseconds: 400));

/// Web: ブラウザが声の自動再生を止めているときの案内 (D-323)。次にページを触ると鳴らし直す。
const astellAudioBlockedNotice = 'ブラウザが音声の再生を止めています。画面のどこかをクリック / タップすると鳴ります';

/// 満員で通話に入れなかったときの案内 (D-317)。
const astellCallFullNotice = '通話は満員です($astellMeshCap 人まで)。声は届きません — ホストが配信していれば、配信で聞けます';

/// 保留音 (D-327) の案内: 開催予約の開始待ち / 全員が静か。開始 (D-331) はチャイムと一緒に。
const astellHoldWaitingNotice = '開催までお待ちください。保留音を鳴らしています';
const astellStartedNotice = '開催が始まりました';
const astellHoldIdleNotice = '全員がマイクを下ろして静かなので、保留音を鳴らしています(話し始めるかチャットが流れると止まります)';

/// これだけチャット(共有 / 文字起こし)が流れず、全員がマイクを下ろしていれば「静か」(D-327)。
const astellHoldIdleAfter = Duration(minutes: 1);

/// 保留音の見直しの間隔 (D-327): 開催時刻を過ぎた / 静かな時間が満ちた を拾う。null なら見直さない(テスト)。
final astellHoldMusicTickProvider = Provider<Duration?>((ref) => const Duration(seconds: 15));

/// 保留音を鳴らすか(自分の端末、D-327)。KV `holdMusic`、既定オン。ルーム側(オーナー)の `room.holdMusic` と AND。
final astellHoldMusicProvider = Provider<bool>((ref) {
  final area = ref.watch(settingsAreaProvider(astellSettingsArea)).value ?? const <String, Object?>{};
  return (area['holdMusic'] as bool?) ?? true;
});

/// 自分の RASQ アカウント id (D-164): 参加中なら welcome の値、無ければクライアント
/// (モックは 'me')か RASQ アカウントの id(`rasq:` 接頭辞を外す)。
final astellMyAccountIdProvider = Provider<String?>((ref) {
  final fromSession = ref.watch(astellSessionProvider.select((s) => s?.myAccountId));
  if (fromSession != null) return fromSession;
  final fromClient = ref.watch(astellClientProvider).selfAccountId;
  if (fromClient != null) return fromClient;
  final id = ref.watch(rasqAccountProvider).id;
  return id.startsWith('rasq:') ? id.substring(5) : id;
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

/// 共有欄の表示 (D-333): カード型横スライド(既定)か、レガシー(共有枠 + 縦の一覧、D-146)。KV `shares.style`。
enum AstellShareStyle {
  cards('カード(横スライド)'),
  list('一覧(レガシー)');

  const AstellShareStyle(this.label);
  final String label;
}

final astellShareStyleProvider = Provider<AstellShareStyle>((ref) {
  final area = ref.watch(settingsAreaProvider(astellSettingsArea)).value ?? const <String, Object?>{};
  return area['shares.style'] == AstellShareStyle.list.name ? AstellShareStyle.list : AstellShareStyle.cards;
});

/// 自動再生 (D-147): ピアの画面共有が始まったら(参加時に既にあるものも)共有枠に自動で出す。
/// KV `autoplay.screen`、既定オン。
final astellAutoPlayProvider = Provider<bool>((ref) {
  final area = ref.watch(settingsAreaProvider(astellSettingsArea)).value ?? const <String, Object?>{};
  return (area['autoplay.screen'] as bool?) ?? true;
});

/// 自分がフォローしている RASQ アカウント (D-149)。
final astellFollowingProvider = FutureProvider<Set<String>>((ref) => ref.watch(astellClientProvider).following());

/// ブロックしている RASQ アカウント (D-150)。発言を隠す / ホストならそのルームに入れない。
final astellBlocksProvider = FutureProvider<Set<String>>((ref) => ref.watch(astellClientProvider).blocks());

/// フォロワー(作成 FOW の「フォロワーを招待」)。
final astellFollowersProvider = FutureProvider<List<AstellFollowEntry>>((ref) => ref.watch(astellClientProvider).followers());

/// VC ホームの 3 節。
final astellHomeProvider = FutureProvider<AstellHome>((ref) => ref.watch(astellClientProvider).home());

/// 参加 FOW の「参加メンバー」(接続前のプレビュー)。
// 参加前の一覧は開くたびに取り直す(REC-04: 最初に見たときの結果が残り、カードの人数と食い違っていた)。
final astellPeersProvider = FutureProvider.autoDispose.family<List<AstellPeer>, String>((ref, id) => ref.watch(astellClientProvider).peers(id));

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
    this.drafts = const {},
    this.connected = false,
    this.micOn = false,
    this.captionsOn = true,
    this.screenShareOn = false,
    this.viewingPeerId,
    this.mutedPeerIds = const {},
    this.speakerMuted = false,
    this.forceMuted = false,
    this.callFull = false,
    this.streamConnected = false,
    this.streaming,
    this.error,
    this.notice,
  });
  final AstellRoom room;
  final String? myPeerId;

  /// 自分の RASQ アカウント id(welcome の `accountId`)。役割の判定に使う。
  final String? myAccountId;
  final List<AstellPeer> peers;
  final List<AstellShare> shares;
  final List<AstellTranscript> transcripts;

  /// ほかの参加者の入力中の下書き (D-311)。peerId ごと。
  final Map<String, AstellDraft> drafts;
  final bool connected;

  /// マイク (D-317): 立っている間だけ通話(P2P)と、配信中なら LiveKit へ声を送る。
  final bool micOn;

  /// 字幕(文字起こしの表示)。
  final bool captionsOn;

  /// 画面共有 (D-317): 画面を LiveKit に上げ、`state.screenShare` を立てている。
  final bool screenShareOn;

  /// 共有枠に表示している(ピン留め/クリックした)ピアの画面共有 (D-146)。
  final String? viewingPeerId;

  /// 手元でミュートしたピア (D-147)。その人の声を鳴らさない(通話も配信も、D-317)。
  final Set<String> mutedPeerIds;

  /// スピーカーミュート (D-148): 受け取る音声を全部止める(D-317)。
  final bool speakerMuted;

  /// モデレーターに全員向けミュートされている (D-149)。マイクは立てられない。
  final bool forceMuted;

  /// 満員で通話に入れなかった (D-317)。声は送れず、配信があれば LiveKit で聞く。
  final bool callFull;

  /// 配信(LiveKit)に繋がっている (D-317)。映像は [AstellLiveVideo] が出す。
  final bool streamConnected;

  /// 自分が LiveKit に上げているもの (D-317): `camera` / `screen` / null。
  final String? streaming;
  final String? error;

  /// 情報の案内(検閲の保留など、D-151)。エラーではない。
  final String? notice;

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
    Map<String, AstellDraft>? drafts,
    bool? connected,
    bool? micOn,
    bool? captionsOn,
    bool? screenShareOn,
    String? viewingPeerId,
    bool clearViewing = false,
    Set<String>? mutedPeerIds,
    bool? speakerMuted,
    bool? forceMuted,
    bool? callFull,
    bool? streamConnected,
    String? streaming,
    bool clearStreaming = false,
    String? error,
    bool clearError = false,
    String? notice,
    bool clearNotice = false,
  }) =>
      AstellSessionState(
        room: room ?? this.room,
        myPeerId: myPeerId ?? this.myPeerId,
        myAccountId: myAccountId ?? this.myAccountId,
        peers: peers ?? this.peers,
        shares: shares ?? this.shares,
        transcripts: transcripts ?? this.transcripts,
        drafts: drafts ?? this.drafts,
        connected: connected ?? this.connected,
        micOn: micOn ?? this.micOn,
        captionsOn: captionsOn ?? this.captionsOn,
        screenShareOn: screenShareOn ?? this.screenShareOn,
        viewingPeerId: clearViewing ? null : (viewingPeerId ?? this.viewingPeerId),
        mutedPeerIds: mutedPeerIds ?? this.mutedPeerIds,
        speakerMuted: speakerMuted ?? this.speakerMuted,
        forceMuted: forceMuted ?? this.forceMuted,
        callFull: callFull ?? this.callFull,
        streamConnected: streamConnected ?? this.streamConnected,
        streaming: clearStreaming ? null : (streaming ?? this.streaming),
        error: clearError ? null : (error ?? this.error),
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

/// ルーム接続の状態機械 (D-139): join → welcome で確定 → peer-joined/left /
/// share / transcript / room / closed を反映 → leave で切る。同時に 1 ルーム。
///
/// 通話 (D-317): welcome で [AstellCallMesh] を作り、offer / answer / ice / peer-left を渡す(音声だけの
/// P2P メッシュ)。配信 (D-317): ホストの配信や画面共有があれば LiveKit に繋いで映像を受け、自分の配信 /
/// 画面共有は LiveKit に上げる([AstellStreamer])。
class AstellSession extends Notifier<AstellSessionState?> {
  AstellConnection? _conn;
  StreamSubscription<Map<String, Object?>>? _sub;
  AstellMedia? _media;
  AstellCallMesh? _mesh;
  AstellStreamer? _streamer;
  bool _streamBusy = false;

  /// 自動で見に行くのを止めた(未設定 / 断られた)。同じルームでは繰り返さない。
  bool _streamGaveUp = false;

  /// 配信の口(繋いでいなければ null)。[AstellLiveVideo] が映像を読む。
  AstellStreamer? get streamer => _streamer;

  /// 通話の手順(テスト用)。
  @visibleForTesting
  AstellCallMesh? get mesh => _mesh;

  @override
  AstellSessionState? build() {
    ref.onDispose(() => _teardown());
    // 端末の保留音の設定が変わったら見直す (D-327)。派生の Provider ではなく元の設定領域を聞く(誰も watch していなくても届く)。
    ref.listen(settingsAreaProvider(astellSettingsArea), (_, _) => _syncHoldMusic());
    return null;
  }

  Future<void> join(AstellRoom room) async {
    await leave();
    state = AstellSessionState(room: room);
    _lastChatAt = DateTime.now();
    _waitingForStart = false;
    if (ref.read(astellHoldMusicTickProvider) case final tick?) _holdTick = Timer.periodic(tick, (_) => _syncHoldMusic());
    _media = ref.read(astellMediaFactoryProvider)();
    _streamGaveUp = false;
    astellAudioAwaitingGesture.addListener(_onAudioAwaitingGesture);
    // Web (Safari): 次の操作のときに、声を鳴らす <audio> を操作の中で鳴らしておく(D-323)。ネイティブは何もしない。
    astellPrimeAudioOnGesture();
    try {
      final conn = await ref.read(astellClientProvider).connect(room.id);
      _conn = conn;
      _sub = conn.messages.listen(_onMessage, onError: (Object e) => _fail(redactSecrets('$e')), onDone: () {
        if (state != null) state = state!.copyWith(connected: false);
      });
    } catch (e) {
      // REC-03: 接続エラーは接続先の URL(`?token=`)を含むので、そのまま出さない。
      _fail(wsConnectErrorMessage(e));
    }
  }

  void _fail(String message) {
    message = redactSecrets(message);
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
        _startCall();
        _syncWatching();
        _syncHoldMusic(); // 開催予約の待ち (D-327) は接続した時点から
      case 'peer-joined':
        final p = m['peer'];
        if (p is Map) state = s.copyWith(peers: [...s.peers, AstellPeer.fromJson(p.cast<String, Object?>())]);
        _applyPlayback();
      case 'peer-left':
        state = s.copyWith(peers: [for (final p in s.peers) if (p.peerId != m['peerId']) p], drafts: {...s.drafts}..remove(m['peerId']));
        if (m['peerId'] case final String id) unawaited(_mesh?.peerLeft(id));
        _applyPlayback();
        _syncWatching();
      // 通話のシグナリング (D-317): 手順は AstellCallMesh。
      case 'offer' || 'answer' || 'ice':
        unawaited(_mesh?.handle(m));
      // ほかの参加者の入力中の下書き (D-311)。null / 空で取り消し。
      case 'draft':
        final peerId = m['peerId'] as String?;
        if (peerId == null || peerId == s.myPeerId) break;
        final d = AstellDraft.fromJson(m);
        final next = {...s.drafts}..remove(peerId);
        if (d != null) next[peerId] = d;
        state = s.copyWith(drafts: next);
      case 'peer-state':
        final p = m['peer'];
        if (p is Map) {
          final peer = AstellPeer.fromJson(p.cast<String, Object?>());
          if (peer.peerId == s.myPeerId) {
            // 自分の状態の折り返しは参加者に入れない。強制ミュート (D-149) だけ拾う。
            if (peer.mutedByMod != s.forceMuted) {
              state = s.copyWith(forceMuted: peer.mutedByMod, micOn: peer.mutedByMod ? false : null);
              // 強制ミュート: 声を止める(通話も配信も)。
              if (peer.mutedByMod) {
                _media?.setMicEnabled(false);
                unawaited(_streamer?.setMic(false));
              }
            }
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
          _syncWatching();
          _syncHoldMusic(); // 誰かが話し始めた / 静かになった (D-327)
        }
      case 'share-removed':
        state = s.copyWith(shares: [for (final x in s.shares) if (x.id != m['shareId']) x]);
      case 'transcript':
        final x = m['transcript'];
        if (x is Map) {
          final t = AstellTranscript.fromJson(x.cast<String, Object?>());
          state = s.copyWith(transcripts: s.transcripts.any((e) => e.id == t.id) ? [for (final e in s.transcripts) e.id == t.id ? t : e] : [...s.transcripts, t]);
          _chatFlowed();
        }
      case 'room':
        final x = m['room'];
        if (x is Map) state = s.copyWith(room: AstellRoom.fromJson(x.cast<String, Object?>()));
        _syncWatching();
        _syncHoldMusic(); // 開催が始まった / 保留音の可否が変わった (D-327)
      case 'closed':
        state = s.copyWith(connected: false, streamConnected: false, clearStreaming: true, screenShareOn: false, error: m['reason'] == 'moderation' ? '運営によりルームが閉鎖されました' : 'ホストがルームを終了しました');
        unawaited(_stopMedia());
      case 'kicked':
        // モデレーションで追い出された (D-149)。接続は切る(状態は残して案内を出す)。
        state = s.copyWith(
          connected: false,
          streamConnected: false,
          clearStreaming: true,
          screenShareOn: false,
          error: switch (m['reason']) {
            'banned' => 'このルームから BAN されました',
            'sanctioned' => 'アカウントの処置により退出させられました',
            _ => 'モデレーターにルームから退出させられました',
          },
        );
        unawaited(_teardown());
      // アカウント処置(中レベル、D-151): 共有は保留 → 判定 → 配信 or 却下。
      case 'held':
        state = s.copyWith(notice: '検閲中: ${m['delaySeconds'] ?? '?'} 秒後に判定して配信されます(アカウントの処置)', clearError: true);
      case 'rejected':
        state = s.copyWith(error: '検閲で却下されました(${m['source'] ?? 'review'})。この発言は配信されていません', clearNotice: true);
      case 'share':
        final x = m['share'];
        if (x is Map) {
          final sh = AstellShare.fromJson(x.cast<String, Object?>());
          // 同じ id はピン留め等の更新 (D-146)。発言が届いたら、その人の下書きは消す(取り消しより先に届くことがある)。
          state = s.copyWith(
            drafts: s.drafts.values.any((d) => d.accountId == sh.accountId) ? {for (final e in s.drafts.entries) if (e.value.accountId != sh.accountId) e.key: e.value} : null,
            shares: s.shares.any((e) => e.id == sh.id) ? [for (final e in s.shares) e.id == sh.id ? sh : e] : [...s.shares, sh],
            clearNotice: sh.accountId == s.myAccountId, // 保留が明けた
          );
          _chatFlowed();
        }
      case 'error':
        state = s.copyWith(error: m['message'] as String?);
      // カスタムプラグイン (S-048、D-357): ルームにデプロイされた / 閉じられた。一覧を取り直す。
      case 'custom':
        ref.read(astellCustomRevProvider.notifier).bump();
      default:
        break;
    }
  }

  void share(String kind, Map<String, Object?> payload) => _conn?.send({'type': 'share', 'kind': kind, 'payload': payload});

  // ── 入力中の下書き (D-311) ──
  // 入力欄の文字を [astellDraftInterval] ごとに送る。送る前に刺激性を見て、強い言葉が入っていれば
  // その回は送らない(打ちかけの一瞬でも相手に見えないように。制限モードに関係なく常に)。
  // 相手側では、書き始めた時刻の位置に差し込まれる。
  String _draftText = '';
  String? _draftSent;
  Timer? _draftTimer;

  /// 入力欄の文字が変わった。
  void setDraft(String text) {
    _draftText = text;
    if (text.trim().isEmpty) {
      _flushDraft();
      return;
    }
    _draftTimer ??= Timer.periodic(astellDraftInterval, (_) => _flushDraft());
  }

  /// 送った / 消したとき: すぐ取り消す。
  void clearDraft() {
    _draftText = '';
    _flushDraft();
  }

  void _flushDraft() {
    final text = _draftText.trim().isEmpty ? '' : _draftText;
    if (text.isEmpty) {
      _draftTimer?.cancel();
      _draftTimer = null;
      if (_draftSent != null) _conn?.send({'type': 'draft', 'text': null});
      _draftSent = null;
      return;
    }
    if (text == _draftSent || !astellDraftAllowed(text)) return;
    _conn?.send({'type': 'draft', 'text': text});
    _draftSent = text;
  }

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

  /// マイク (D-317): 立てるときに初めてマイクを開く(OS の許可)。開けなければ理由を出して立てない。
  Future<void> toggleMic() async {
    final s = state;
    if (s == null || s.forceMuted) return; // 強制ミュート中は立てられない
    final on = !s.micOn;
    final media = _media;
    if (on && media != null && media.available) {
      final blocked = media.micBlocked;
      if (blocked != null) {
        state = s.copyWith(error: AstellMediaException(blocked).message);
        return;
      }
      try {
        if (!media.micOpen) await media.openMic();
      } catch (e) {
        if (state != null) state = state!.copyWith(error: AstellMediaException.from(e).message);
        return;
      }
    }
    final now = state;
    if (now == null || now.forceMuted) return;
    _media?.setMicEnabled(on);
    state = now.copyWith(micOn: on, clearError: on && now.error != null);
    _sendState();
    unawaited(_streamer?.setMic(on));
    if (on && now.callFull && now.streaming == null) state = state!.copyWith(notice: astellCallFullNotice);
    _syncHoldMusic(); // 話し始めたら保留音は止まる (D-327)
  }

  // ── 通話 (D-317) ──

  void _startCall() {
    final s = state;
    final media = _media;
    final me = s?.myPeerId;
    if (s == null || media == null || !media.available || me == null) return;
    unawaited(_mesh?.close());
    final mesh = _mesh = AstellCallMesh(
      media: media,
      send: (m) => _conn?.send(m),
      iceServers: ref.read(astellClientProvider).iceServers,
      onChanged: _onCallChanged,
      onError: (message) {
        if (state != null) state = state!.copyWith(error: message);
      },
      levelInterval: ref.read(astellLevelIntervalProvider),
    );
    mesh.setPlayback(speakerMuted: s.speakerMuted, mutedPeerIds: s.mutedPeerIds);
    unawaited(mesh.start(me, [for (final p in s.peers) p.peerId]));
  }

  /// 通話の接続 / 話している人が変わった: 参加者の `speaking` と、満員の案内。
  void _onCallChanged() {
    final s = state;
    final mesh = _mesh;
    if (s == null || mesh == null) return;
    final speaking = mesh.speaking;
    final becameFull = mesh.full && !s.callFull;
    state = s.copyWith(
      peers: [for (final p in s.peers) p.speaking == speaking.contains(p.peerId) ? p : p.copyWith(speaking: speaking.contains(p.peerId))],
      callFull: mesh.full,
      notice: becameFull ? astellCallFullNotice : null,
    );
    _applyPlayback();
  }

  /// 鳴らす声: 通話はスピーカーミュート / 保留 / 手元のミュートで止める。配信(LiveKit)の声は、通話で繋がっている人
  /// なら鳴らさない(二重にしない)— 満員で通話に入れなかった人は、ホストの声を配信で聞く。
  void _applyPlayback() {
    final s = state;
    if (s == null) return;
    _mesh?.setPlayback(speakerMuted: s.speakerMuted, mutedPeerIds: s.mutedPeerIds);
    _streamer?.setAudioPolicy(_playsOnStream);
    _syncHoldMusic();
  }

  bool _playsOnStream(String identity) {
    final s = state;
    if (s == null || s.speakerMuted || identity == s.myAccountId) return false;
    final peers = [for (final p in s.peers) if (p.accountId == identity) p];
    if (peers.any((p) => s.mutedPeerIds.contains(p.peerId))) return false;
    final linked = _mesh?.peerIds ?? const <String>{};
    return !peers.any((p) => linked.contains(p.peerId));
  }

  // ── 保留音 (D-325 → D-327) ──

  /// チャット(共有 / 文字起こし)が最後に流れた時刻(参加した時刻から)。静かな時間の起点。
  DateTime _lastChatAt = DateTime.now();

  /// 保留音の見直し(時間で変わる条件 = 開催時刻 / 静かな時間 を拾う)。
  Timer? _holdTick;

  /// 開催予約の開始を保留音で待っている (D-331: 待ちが明けた瞬間にチャイム)。
  bool _waitingForStart = false;

  /// テスト用: 最後にチャットが流れた時刻を差し替える。
  @visibleForTesting
  void debugSetLastChatAt(DateTime at) {
    _lastChatAt = at;
    _syncHoldMusic();
  }

  /// チャットが流れた(共有 / 文字起こし)。静かな時間を仕切り直す。
  void _chatFlowed() {
    _lastChatAt = DateTime.now();
    _syncHoldMusic();
  }

  /// 全員が静かか (D-327): 自分もほかの参加者もマイクを下ろし、画面共有 / 配信も無く、チャットが [astellHoldIdleAfter] 以上流れていない。
  bool _roomIdle(AstellSessionState s) {
    if (s.micOn || s.screenShareOn || s.streaming != null || s.room.hostStream != null) return false;
    if (s.peers.any((p) => p.peerId != s.myPeerId && (p.micOn || p.screenShare != null))) return false;
    return DateTime.now().difference(_lastChatAt) >= astellHoldIdleAfter;
  }

  /// 保留音 (D-327): **開催予約の開始を待っている間**と、**全員が静かなとき**([_roomIdle])に手元で鳴らす。
  /// 自分の端末の設定([astellHoldMusicProvider])とルームの設定(`room.holdMusic`、オーナー)の両方がオンで、
  /// スピーカーミュートでないとき。鳴っている間は理由を案内に出し、止まれば消す。
  void _syncHoldMusic() {
    final s = state;
    final HoldMusic music;
    try {
      music = ref.read(holdMusicProvider);
    } catch (_) {
      return; // ref はもう使えない(アプリごと破棄)
    }
    // 端末の設定は元の領域から読む(派生の Provider は設定の変化の直後にはまだ古い値のことがある)。
    final area = ref.read(settingsAreaProvider(astellSettingsArea)).value ?? const <String, Object?>{};
    final mine = (area['holdMusic'] as bool?) ?? true;
    String? reason;
    if (s != null && s.connected && !s.speakerMuted && s.room.holdMusic && mine) {
      if (s.room.isScheduled) {
        reason = astellHoldWaitingNotice;
      } else if (_roomIdle(s)) {
        reason = astellHoldIdleNotice;
      }
    }
    final play = reason != null;
    // 開催の待ちが明けた (D-331): 保留音を止めてチャイムを 1 回。
    final started = _waitingForStart && s != null && s.connected && !s.room.isScheduled;
    _waitingForStart = reason == astellHoldWaitingNotice;
    if (started) {
      unawaited(music.alarm());
    } else if (play != music.playing) {
      unawaited(play ? music.start() : music.stop());
    }
    final now = state;
    if (now == null) return;
    if (started) {
      state = now.copyWith(notice: astellStartedNotice);
    } else if (play) {
      if (now.notice != reason) state = now.copyWith(notice: reason);
    } else if (now.notice == astellHoldWaitingNotice || now.notice == astellHoldIdleNotice || now.notice == astellStartedNotice) {
      state = now.copyWith(clearNotice: true);
    }
  }

  /// Web の自動再生の制限 (D-323): 止められている間は「触ると鳴ります」を出し、鳴ったら消す。
  void _onAudioAwaitingGesture() {
    final s = state;
    if (s == null) return;
    if (astellAudioAwaitingGesture.value) {
      if (s.notice == null) state = s.copyWith(notice: astellAudioBlockedNotice);
    } else if (s.notice == astellAudioBlockedNotice) {
      state = s.copyWith(clearNotice: true);
    }
  }

  /// 通話 / 配信の接続の様子(開発者向け、D-323)。設定の「接続の状態」が 1 秒ごとに読む。実機でしか起きない
  /// 「繋がったのに聞こえない / 映らない」を、ICE の状態・候補・送受信のバイト数・受けたトラックで切り分ける。
  Future<List<String>> diagnostics() async {
    final s = state;
    if (s == null) return const ['ルームに入っていません'];
    String short(String? id) => id == null ? '-' : (id.length > 8 ? id.substring(0, 8) : id);
    final media = _media;
    final mesh = _mesh;
    final blocked = media?.micBlocked;
    final lines = <String>[
      '自分: peer ${short(s.myPeerId)} / ${kIsWeb ? 'Web' : defaultTargetPlatform.name}${kIsWeb ? (astellInsecureWebContext() ? '(安全でない場所 — マイク不可)' : '(https)') : ''}',
      'マイク: ${s.micOn ? '立てている' : '下ろしている'} / ${media == null || !media.available ? '通話なし' : (media.micOpen ? '開いた' : 'まだ開いていない')}${blocked != null ? ' / ${AstellMediaException(blocked).message}' : ''}',
      if (astellAudioAwaitingGesture.value) '声: ブラウザが自動再生を止めている(画面を触ると鳴らし直す)',
      '通話: ${mesh == null ? 'なし' : (mesh.full ? '満員で入っていない' : '接続 ${mesh.peerIds.length} 本')} / ICE サーバー: ${mesh?.iceServerUrls?.join(', ') ?? '-'}',
    ];
    if (mesh != null) {
      for (final d in await mesh.diagnostics()) {
        final who = s.peers.where((p) => p.peerId == d.peerId).firstOrNull;
        lines
          ..add('— ${who?.displayName ?? '?'}(peer ${short(d.peerId)})')
          ..addAll([for (final l in d.lines()) '  $l']);
      }
    }
    final st = _streamer;
    lines.addAll(st == null ? const ['配信: 繋いでいない'] : st.diagnostics().lines());
    return lines;
  }

  // ── 配信 (D-317) ──

  /// LiveKit に繋ぐ(繋いでいればそのまま。上げるのに見るだけのトークンなら取り直す)。
  Future<AstellStreamer> _ensureStream({required bool publish}) async {
    final s = state;
    if (s == null) throw StateError('ルームに入っていません');
    final have = _streamer;
    if (have != null && have.connected && (!publish || have.canPublish)) return have;
    final token = await ref.read(astellClientProvider).streamToken(s.room.id, publish: publish);
    final st = _streamer ??= ref.read(astellStreamerFactoryProvider)();
    await st.connect(token);
    if (state != null) state = state!.copyWith(streamConnected: true);
    _applyPlayback();
    return st;
  }

  /// 見る側: ホストの配信か、ほかの人の画面共有があれば LiveKit に繋ぐ。どちらも無く、自分も上げていなければ切る。
  void _syncWatching() {
    final s = state;
    if (s == null || !s.connected || _streamBusy) return;
    final want = s.room.hostStream != null || s.peers.any((p) => p.peerId != s.myPeerId && p.screenShare != null);
    final st = _streamer;
    if (want && (st == null || !st.connected) && !_streamGaveUp) {
      _streamBusy = true;
      unawaited(_ensureStream(publish: false).then((_) {}, onError: (Object e) {
        _streamGaveUp = true;
        if (state != null) state = state!.copyWith(notice: '映像を受けられません: ${astellStreamErrorText(e)}');
      }).whenComplete(() => _streamBusy = false));
    } else if (!want && st != null && st.connected && st.publishing == null) {
      unawaited(st.disconnect());
      state = s.copyWith(streamConnected: false);
    }
  }

  /// ホストの配信を始める(オーナー、D-317): カメラ / 画面 + マイクを LiveKit に上げ、`hostStream` を立てる。
  Future<void> startHostStream(String kind, {String? screenSourceId}) async {
    final s = state;
    if (s == null || !s.isOwner || s.streaming != null) {
      if (s != null && s.screenShareOn) state = s.copyWith(error: '画面共有中は配信を始められません(共有をやめてから)');
      return;
    }
    try {
      final st = await _ensureStream(publish: true);
      await st.publish(kind, mic: s.micOn && !s.forceMuted, screenSourceId: screenSourceId);
      final room = await ref.read(astellClientProvider).updateRoom(s.room.id, {
        'hostStream': {'kind': kind == 'screen' ? 'screen' : 'video', 'title': s.room.title, 'startedAt': DateTime.now().toUtc().toIso8601String()},
      });
      if (state != null) state = state!.copyWith(room: room, streaming: kind, clearError: true);
      _syncHoldMusic();
    } catch (e) {
      await _streamer?.unpublish();
      if (state != null) state = state!.copyWith(error: '配信を始められません: ${astellStreamErrorText(e)}');
    }
  }

  /// ホストの配信を止める(`hostStream` を null に)。
  Future<void> stopHostStream() async {
    final s = state;
    if (s == null) return;
    await _streamer?.unpublish();
    if (state != null) state = state!.copyWith(clearStreaming: true);
    _syncHoldMusic();
    try {
      final room = await ref.read(astellClientProvider).updateRoom(s.room.id, {'hostStream': null});
      if (state != null) state = state!.copyWith(room: room);
    } catch (e) {
      if (state != null) state = state!.copyWith(error: '配信の印を消せませんでした: $e');
    }
    _syncWatching();
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

  /// ブロック (D-150): Central に残し、フォローも切れる。発言の非表示は表示側で `astellBlocksProvider`。
  Future<void> block(String accountId, bool block) async {
    await ref.read(astellClientProvider).block(accountId, block);
    ref.invalidate(astellBlocksProvider);
    ref.invalidate(astellFollowingProvider);
  }

  /// 自動再生 (D-147): 設定がオンで、共有枠が空いていれば [peer] の画面を出す。
  void _autoPlay(AstellPeer? peer) {
    final s = state;
    if (s == null || peer == null || s.viewingPeerId != null) return;
    if (!ref.read(astellAutoPlayProvider)) return;
    state = s.copyWith(viewingPeerId: peer.peerId);
  }

  /// スピーカーミュート切替 (D-148)。受ける声を全部止める(D-317)。
  void toggleSpeaker() {
    if (state == null) return;
    state = state!.copyWith(speakerMuted: !state!.speakerMuted);
    _applyPlayback();
  }

  /// ピアを手元でミュート/解除 (D-147)。その人の声を鳴らさない(D-317)。
  void toggleMute(String peerId) {
    final s = state;
    if (s == null) return;
    final next = {...s.mutedPeerIds};
    if (!next.remove(peerId)) next.add(peerId);
    state = s.copyWith(mutedPeerIds: next);
    _applyPlayback();
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

  /// 画面共有 (D-317): 画面を LiveKit に上げてから `state.screenShare` を立てる(上げられなければ立てない)。
  /// [screenSourceId] はデスクトップで選んだ画面 / ウィンドウ。
  Future<void> toggleScreenShare({String? screenSourceId}) async {
    final s = state;
    if (s == null) return;
    if (s.screenShareOn) {
      if (s.streaming == 'screen') await _streamer?.unpublish();
      if (state == null) return;
      state = state!.copyWith(screenShareOn: false, clearStreaming: s.streaming == 'screen');
      _syncHoldMusic();
      _sendState();
      _syncWatching();
      return;
    }
    if (s.streaming != null) {
      state = s.copyWith(error: '配信中は画面共有を始められません(配信を止めてから)');
      return;
    }
    try {
      final st = await _ensureStream(publish: true);
      await st.publish('screen', mic: s.micOn && !s.forceMuted, screenSourceId: screenSourceId);
    } catch (e) {
      if (state != null) state = state!.copyWith(error: '画面共有を始められません: ${astellStreamErrorText(e)}');
      return;
    }
    if (state == null) return;
    state = state!.copyWith(screenShareOn: true, streaming: 'screen', clearError: true);
    _syncHoldMusic();
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
    final s = state;
    // ホストが配信したまま出る: 印を消す(待たない)。
    if (s != null && s.isOwner && s.streaming != null && !s.screenShareOn && s.room.hostStream != null) {
      unawaited(ref.read(astellClientProvider).updateRoom(s.room.id, {'hostStream': null}).then((_) {}, onError: (Object e) => debugPrint('astell: hostStream: $e')));
    }
    await _teardown();
    state = null;
  }

  /// 通話と配信を閉じる(退出 / 閉鎖 / キック)。
  Future<void> _stopMedia() async {
    final mesh = _mesh;
    final media = _media;
    final st = _streamer;
    _mesh = null;
    _media = null;
    _streamer = null;
    await mesh?.close();
    await media?.dispose();
    await st?.disconnect();
  }

  /// 切断は待たない — ソケットの close 完了(相手側の done 配送)に UI を
  /// 引きずられないため。購読は先に外すので、以後のメッセージは無視される。
  Future<void> _teardown() async {
    astellAudioAwaitingGesture.removeListener(_onAudioAwaitingGesture);
    _holdTick?.cancel();
    _holdTick = null;
    _draftTimer?.cancel();
    _draftTimer = null;
    _draftText = '';
    _draftSent = null;
    final sub = _sub;
    final conn = _conn;
    _sub = null;
    _conn = null;
    unawaited(sub?.cancel());
    unawaited(conn?.close().catchError((Object e) => debugPrint('astell: close: $e')));
    unawaited(_stopMedia().catchError((Object e) => debugPrint('astell: media: $e')));
    // 保留音 (D-327) は退出で止める(コンテナごと破棄されている途中なら何もしない)。
    try {
      unawaited(ref.read(holdMusicProvider).stop());
    } catch (_) {
      // ref はもう使えない(アプリごと破棄)。
    }
  }
}

/// 配信の失敗を 1 行に (D-317)。
String astellStreamErrorText(Object e) {
  if (e is AstellMediaException) return e.message;
  if (e is OrgateException) {
    return switch (e.code.code) {
      '501' => '配信サーバー(LiveKit)が設定されていません',
      '403' => '許可されていません(${e.message})',
      _ => e.message,
    };
  }
  return '$e';
}

final astellSessionProvider = NotifierProvider<AstellSession, AstellSessionState?>(AstellSession.new);

/// ルームのカスタムプラグインの版(WS の `custom` と、手元でデプロイ / 閉じたときに進める、D-357)。
final astellCustomRevProvider = NotifierProvider<AstellCustomRev, int>(AstellCustomRev.new);

class AstellCustomRev extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

/// 下書きを送る間隔 (D-311)。
const astellDraftInterval = Duration(seconds: 1);

/// この下書きを相手に見せてよいか (D-311): 刺激性(語彙の判定、emotion8 と同じ軸)が
/// チャイルドセーフの「きびしめ」の閾値に届いたら見せない。止めるのは下書きの表示だけで、
/// 送った発言はふだんどおり(処置があれば検閲)。
bool astellDraftAllowed(String text) => ChildGate.stimulusOfText(text) < ChildSafeLevel.strict.stimulusThreshold;
