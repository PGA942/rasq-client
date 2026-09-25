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

  /// 切る。
  Future<void> disconnect();
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
