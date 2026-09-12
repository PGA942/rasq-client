import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 端末内 LLM(ワイヤーフレームの「Agents-A1-4B」)の配線 (D-181)。
///
/// - 実体は [raiLlmProvider] で差し替える([FlutterGemmaRaiLlm] = LiteRT-LM、テストは偽物)。
/// - モデルは [raiModelSpecs] から選ぶ(既定 = 仕様の LFM2.5 2.6B。4B 級は Qwen3.5 4B)。
/// - フォールアップ(セルフホストのクラウド)は [RaiFallUp] — サーバー側が無いので必ず失敗を返す。
enum RaiLlmPhase { notInstalled, downloading, ready, loading, generating, unavailable }

@immutable
class RaiLlmStatus {
  const RaiLlmStatus(this.phase, {this.progress, this.message, this.modelId});
  final RaiLlmPhase phase;

  /// ダウンロード中の % (0..100)。
  final int? progress;
  final String? message;
  final String? modelId;

  bool get ready => phase == RaiLlmPhase.ready || phase == RaiLlmPhase.generating;
  static const initial = RaiLlmStatus(RaiLlmPhase.notInstalled);
}

/// 端末に入れるモデルの候補。
@immutable
class RaiModelSpec {
  const RaiModelSpec({required this.id, required this.label, required this.fileName, required this.url, required this.sizeMb, required this.family});
  final String id;
  final String label;
  final String fileName;
  final String url;
  final int sizeMb;

  /// flutter_gemma の ModelType 名(general / qwen3 …)。
  final String family;
}

const raiModelSpecs = <RaiModelSpec>[
  RaiModelSpec(
    id: 'lfm2.5-2.6b',
    label: 'LFM2.5 2.6B (int4)',
    fileName: 'LFM2.5-2.6B_int4.litertlm',
    url: 'https://huggingface.co/litert-community/LFM2.5-2.6B/resolve/main/LFM2.5-2.6B_int4.litertlm',
    sizeMb: 1668,
    family: 'general',
  ),
  RaiModelSpec(
    id: 'qwen3.5-4b',
    label: 'Qwen3.5 4B (mixed int4)',
    fileName: 'Qwen3.5-4B_mixed_int4.litertlm',
    url: 'https://huggingface.co/litert-community/Qwen3.5-4B/resolve/main/Qwen3.5-4B_mixed_int4.litertlm',
    sizeMb: 2754,
    family: 'qwen3',
  ),
];

/// バーのチップに出す端末内モデルの呼び名(ワイヤーフレーム)。
const raiLocalModelLabel = 'Agents-A1-4B';

abstract class RaiLlm {
  RaiLlmStatus get current;
  Stream<RaiLlmStatus> get statuses;

  /// 選んでいるモデル。
  RaiModelSpec get spec;

  /// 状態の確認(インストール済みか)。
  Future<void> refresh();
  Future<void> select(RaiModelSpec spec);
  Future<void> install({String? hfToken});
  Future<void> uninstall();

  /// 読み込んだモデルを解放する(フォールアップ時に呼ぶ想定)。
  Future<void> release();

  /// 1 問 1 答(トークンのストリーム)。
  Stream<String> chat(String prompt, {String? system});
}

class RaiLlmException implements Exception {
  const RaiLlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// フォールアップ先(セルフホストのクラウド)。サーバー側が無いので失敗する。
class RaiFallUp {
  const RaiFallUp();
  Future<String> chat(String prompt) async {
    throw const RaiLlmException('フォールアップ先(サーバー側)が未接続です');
  }
}

final raiFallUpProvider = Provider<RaiFallUp>((_) => const RaiFallUp());

/// 実体はアプリ側で登録する(`rai_llm_gemma.dart`、main.dart の override)。未登録なら「使えない」状態の骨格。
final raiLlmProvider = Provider<RaiLlm>((ref) => UnavailableRaiLlm());

/// 状態の購読(バーのチップ / RAi ホーム)。初回に [RaiLlm.refresh] を呼ぶ。
final raiLlmStatusProvider = StreamProvider<RaiLlmStatus>((ref) async* {
  final llm = ref.watch(raiLlmProvider);
  yield llm.current;
  unawaited(llm.refresh());
  yield* llm.statuses;
});

/// 端末内 LLM が無い環境(テスト / 未配線)の骨格。
class UnavailableRaiLlm implements RaiLlm {
  UnavailableRaiLlm({this.reason = 'この環境では端末内モデルを使えません'});
  final String reason;
  final _ctrl = StreamController<RaiLlmStatus>.broadcast();
  RaiModelSpec _spec = raiModelSpecs.first;
  late RaiLlmStatus _current = RaiLlmStatus(RaiLlmPhase.unavailable, message: reason, modelId: _spec.id);

  @override
  RaiLlmStatus get current => _current;
  @override
  Stream<RaiLlmStatus> get statuses => _ctrl.stream;
  @override
  RaiModelSpec get spec => _spec;
  void _set(RaiLlmStatus s) {
    _current = s;
    _ctrl.add(s);
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> select(RaiModelSpec spec) async {
    _spec = spec;
    _set(RaiLlmStatus(RaiLlmPhase.unavailable, message: reason, modelId: spec.id));
  }

  @override
  Future<void> install({String? hfToken}) async => throw RaiLlmException(reason);
  @override
  Future<void> uninstall() async {}
  @override
  Future<void> release() async {}
  @override
  Stream<String> chat(String prompt, {String? system}) => Stream.error(RaiLlmException(reason));
}
