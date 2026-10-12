import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'astell_models.dart';
import 'astell_providers.dart';

/// AsTell の配信 (D-317) の境界: LiveKit(自前の SFU)。
///
/// - **ホストの配信**(オーナー): カメラ / 画面 + マイクを上げ、`hostStream` を立てる(今までどおり `PATCH`)。
/// - **参加者の画面共有**: 画面を上げ、`state.screenShare` を立てる(メッシュで映像は重いので)。
/// - **見る / 聞く**: 配信や画面共有があるルームに入ったら、見るだけのトークンで繋いで映像を受ける。
///   声は通話(P2P)で聞こえるので、LiveKit の声は**通話に入っていない人**(満員で入れなかった人)だけ鳴らす。
///
/// 実物は `astell_stream_livekit.dart`、モックのルームは [NullAstellStreamer]、テストは偽物。
/// LiveKit の参加者 id(identity)= RASQ アカウントの id。
abstract class AstellStreamer extends ChangeNotifier {
  /// 繋がっているか。
  bool get connected;

  /// 上げてよいトークンで繋いでいるか。
  bool get canPublish;

  /// 自分が上げているもの: `camera` / `screen` / null。
  String? get publishing;

  /// トークンで繋ぐ(繋いでいれば切ってから)。
  Future<void> connect(AstellStreamToken token);

  /// 上げる。[kind] は `camera` / `screen`、[mic] でマイクも。[screenSourceId] はデスクトップで選んだ画面 / ウィンドウ。
  /// 失敗は `AstellMediaException`(許可が無い等)。
  Future<void> publish(String kind, {required bool mic, String? screenSourceId});

  /// 上げているマイクを入れる / 切る(上げていなければ何もしない)。
  Future<void> setMic(bool on);

  /// 上げているものを全部下ろす(繋いだまま)。
  Future<void> unpublish();

  /// その人(identity)の映像があるか。[screen] = 画面共有(なければカメラも見る)。
  bool hasVideo(String identity, {bool screen = false});

  /// その人の映像の描画。無ければ null。
  Widget? video(String identity, {bool screen = false, BoxFit fit = BoxFit.contain});

  /// LiveKit の声を鳴らす相手を決める(identity → 鳴らすか)。
  void setAudioPolicy(bool Function(String identity) play);

  /// いま話しているほかの参加者(identity = アカウント、D-467)。LiveKit のサーバーが決める話している人
  /// (`ActiveSpeakersChanged`)。通話に入っていない人(満員 / 配信だけで聞いている)の話している印に使う。
  /// 変わったら [notifyListeners]。
  Set<String> get speakingIdentities => const {};

  /// 自分が配信で話している(LiveKit のサーバーの印、D-467)。
  bool get localSpeaking => false;

  /// 切る。
  Future<void> disconnect();

  /// 繋がり方の様子(開発者向けの表示、D-323)。実物は上げている / 受けているトラックまで出す。
  AstellStreamDiagnostics diagnostics() => AstellStreamDiagnostics(connection: connected ? 'connected' : 'disconnected', canPublish: canPublish, publishing: publishing);
}

/// 配信(LiveKit)の様子 (D-323)。
@immutable
class AstellStreamDiagnostics {
  const AstellStreamDiagnostics({required this.connection, this.canPublish = false, this.publishing, this.local = const [], this.remote = const {}, this.canPlaybackAudio});

  /// `disconnected` / `connecting` / `reconnecting` / `connected`。
  final String connection;
  final bool canPublish;
  final String? publishing;

  /// 自分が上げているトラック(`screenShareVideo video` の形)。
  final List<String> local;

  /// ほかの参加者(identity)ごとの、相手が上げているトラックと受けているか。
  final Map<String, List<String>> remote;

  /// Web: ブラウザが声を鳴らせているか(自動再生の制限)。ネイティブは null。
  final bool? canPlaybackAudio;

  /// 受けている(購読した)トラックの数。
  int get subscribed => remote.values.expand((t) => t).where((t) => t.contains('受信中')).length;

  List<String> lines() => [
        '配信: $connection${canPublish ? '(上げられる)' : ''}${publishing != null ? ' / 上げているもの: $publishing' : ''}${canPlaybackAudio == false ? ' / 声: ブラウザが止めている(操作待ち)' : ''}',
        '自分のトラック: ${local.isEmpty ? 'なし' : local.join(', ')}',
        if (remote.isEmpty) 'ほかの参加者: なし' else ...[for (final e in remote.entries) '${e.key.length > 8 ? e.key.substring(0, 8) : e.key}: ${e.value.isEmpty ? 'トラック無し' : e.value.join(', ')}'],
        '受けているトラック: $subscribed',
      ];
}

/// 何も映さない口(モックのルーム)。繋いだ / 上げたことだけ覚える。
class NullAstellStreamer extends AstellStreamer {
  bool _connected = false;
  bool _canPublish = false;
  String? _publishing;

  @override
  bool get connected => _connected;
  @override
  bool get canPublish => _canPublish;
  @override
  String? get publishing => _publishing;

  @override
  Future<void> connect(AstellStreamToken token) async {
    _connected = true;
    _canPublish = token.canPublish;
    notifyListeners();
  }

  @override
  Future<void> publish(String kind, {required bool mic, String? screenSourceId}) async {
    _publishing = kind;
    notifyListeners();
  }

  @override
  Future<void> setMic(bool on) async {}

  @override
  Future<void> unpublish() async {
    _publishing = null;
    notifyListeners();
  }

  @override
  bool hasVideo(String identity, {bool screen = false}) => false;

  @override
  Widget? video(String identity, {bool screen = false, BoxFit fit = BoxFit.contain}) => null;

  @override
  void setAudioPolicy(bool Function(String identity) play) {}

  @override
  Future<void> disconnect() async {
    _connected = false;
    _publishing = null;
    notifyListeners();
  }
}

/// LiveKit の映像(その人の画面 / カメラ)。まだ無ければ [fallback](サムネイル等)。
class AstellLiveVideo extends ConsumerWidget {
  const AstellLiveVideo({super.key, required this.identity, this.screen = false, this.fit = BoxFit.contain, required this.fallback});
  final String identity;
  final bool screen;
  final BoxFit fit;
  final Widget fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(astellSessionProvider.select((s) => s?.streamConnected ?? false));
    final st = ref.read(astellSessionProvider.notifier).streamer;
    if (!connected || st == null) return fallback;
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => st.video(identity, screen: screen, fit: fit) ?? fallback,
    );
  }
}
