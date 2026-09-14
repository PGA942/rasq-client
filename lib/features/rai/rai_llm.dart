import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../settings/settings_dsl.dart';

/// 端末内 LLM(ワイヤーフレームの「Agents-A1-4B」)の配線 (D-181)。
///
/// - 実体は [raiLlmProvider] で差し替える([FlutterGemmaRaiLlm] = LiteRT-LM、テストは偽物)。
/// - モデルは [raiModelSpecs] から選ぶ(D-216 → D-219: Qwen3.5 2B(既定)/ Agents-A1 4B / Qwen3.5 0.8B の GGUF だけ。同梱して展開は選択制)。
/// - フォールアップ(セルフホストのクラウド)は [RaiFallUp] — サーバー側が無いので必ず失敗を返す。
enum RaiLlmPhase { notInstalled, downloading, ready, loading, generating, unavailable }

@immutable
class RaiLlmStatus {
  const RaiLlmStatus(this.phase, {this.progress, this.message, this.modelId, this.bundled = false});
  final RaiLlmPhase phase;

  /// 未インストールだがアプリに同梱されている (D-216): 「ダウンロード」ではなく「展開」で使える。
  final bool bundled;

  /// ダウンロード中の % (0..100)。
  final int? progress;
  final String? message;
  final String? modelId;

  bool get ready => phase == RaiLlmPhase.ready || phase == RaiLlmPhase.generating;
  static const initial = RaiLlmStatus(RaiLlmPhase.notInstalled);
}

/// 推論エンジン (D-182): GGUF は llama.cpp(fllama)、.litertlm は LiteRT-LM(flutter_gemma)。
enum RaiEngine {
  gguf,
  litertlm;

  String get label => this == RaiEngine.gguf ? 'llama.cpp / GGUF' : 'LiteRT-LM';
}

/// 端末に入れるモデルの候補(クラウドのフォールアップ先も同じ形で並べる、D-183)。
@immutable
class RaiModelSpec {
  const RaiModelSpec({required this.id, required this.label, required this.fileName, required this.url, required this.sizeMb, required this.family, this.engine = RaiEngine.gguf, this.cloud = false, this.params = 4, this.completionRate});
  final String id;
  final String label;
  final String fileName;
  final String url;
  final int sizeMb;

  /// flutter_gemma の ModelType 名(general / qwen3 …)。GGUF はチャットテンプレート(ChatML)を使う。
  final String family;
  final RaiEngine engine;

  /// クラウド(フォールアップ先)のモデル。端末には入れない。
  final bool cloud;

  /// パラメーター数(B)。完遂率の集計対象は 35B 未満。
  final double params;

  /// 2 単語のコードネーム (D-198)。
  String get codename => raiCodename(this);

  /// 集計された完遂率(0..1)。未集計は null → 「-%」。
  final double? completionRate;

  bool get local => !cloud;
}

/// 既定 = Qwen3 1.7B Q4_K_M (D-188: llama_cpp_dart 0.2.2 の llama.cpp は b7564(2025-12)で **Qwen3.5 は未対応**。
/// Qwen3 系 / Agents-A1(Qwen3-4B 系)は読める)。
const raiModelSpecs = <RaiModelSpec>[
  // D-216: ローカルはこの 3 つだけ(アプリに圧縮して同梱、展開は選択制。無ければ HF からダウンロード)。
  // D-219: Qwen3 → Qwen3.5 系(Agents-A1 と同じ qwen3_5 アーキテクチャ。llama.cpp b10182 で読める)。
  RaiModelSpec(
    id: 'qwen3.5-2b-q4km',
    label: 'Qwen3.5 2B (Q4_K_M)',
    fileName: 'Qwen3.5-2B-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf',
    sizeMb: 1281,
    family: 'qwen3',
    params: 2,
  ),
  RaiModelSpec(
    id: 'agents-a1-4b-q4km',
    label: 'Agents-A1 4B (Q4_K_M)',
    fileName: 'InternScience_Agents-A1-4B-Q4_K_M.gguf',
    url: 'https://huggingface.co/bartowski/InternScience_Agents-A1-4B-GGUF/resolve/main/InternScience_Agents-A1-4B-Q4_K_M.gguf',
    sizeMb: 2885,
    family: 'qwen3',
    params: 4,
  ),
  RaiModelSpec(
    id: 'qwen3.5-0.8b-q4km',
    label: 'Qwen3.5 0.8B (Q4_K_M)',
    fileName: 'Qwen3.5-0.8B-Q4_K_M.gguf',
    url: 'https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf',
    sizeMb: 533,
    family: 'qwen3',
    params: 0.8,
  ),
];

/// クラウド(フォールアップ先)。サーバー側が無いので「未接続」。
const raiCloudModelSpecs = <RaiModelSpec>[
  RaiModelSpec(id: 'cloud-qwen3.9-33b-a3b', label: 'Qwen3.9 33B A3B', fileName: '', url: '', sizeMb: 0, family: 'qwen3', cloud: true, params: 33),
  RaiModelSpec(id: 'cloud-cyllm-jp-150b', label: 'CyLLM-JP-150B', fileName: '', url: '', sizeMb: 0, family: 'general', cloud: true, params: 150),
];

RaiModelSpec raiModelSpecById(String? id) => raiModelSpecs.where((m) => m.id == id).firstOrNull ?? raiModelSpecs.first;

/// メモリの判定 (D-183): モデルの重み × 1.15 + コンテキスト分(600 MB)が、端末 RAM の 6 割までなら
/// 余裕、8.5 割までなら ぎりぎり、それ以上は 不可。RAM が分からなければ 不明。
enum RaiRamVerdict {
  ok,
  tight,
  no,
  unknown;

  String get label => switch (this) { RaiRamVerdict.ok => '動作可', RaiRamVerdict.tight => 'ぎりぎり', RaiRamVerdict.no => 'メモリ不足', RaiRamVerdict.unknown => '不明' };
}

RaiRamVerdict raiMemoryVerdict({required int modelMb, required int? totalRamMb}) {
  if (totalRamMb == null || totalRamMb <= 0) return RaiRamVerdict.unknown;
  final need = modelMb * 1.15 + 600;
  if (need <= totalRamMb * 0.6) return RaiRamVerdict.ok;
  if (need <= totalRamMb * 0.85) return RaiRamVerdict.tight;
  return RaiRamVerdict.no;
}

/// 端末の RAM(MB、合計 / 空き)。取れなければ null。実体は `rai_llm_device.dart` の
/// [deviceRamReader] を main.dart で差す(テストは override)。
final deviceRamProvider = FutureProvider<({int? totalMb, int? availableMb})>((ref) => ref.watch(deviceRamReaderProvider)());
final deviceRamReaderProvider = Provider<Future<({int? totalMb, int? availableMb})> Function()>((_) => () async => (totalMb: null, availableMb: null));

/// バーのチップに出す端末内モデルの呼び名(ワイヤーフレーム)。
/// モデルのコードネーム (D-198): 2 単語(モデルコード + サイズ)。
/// コード: QA = Qwen3 系、Agent = Agents-A1、Liquid = LFM2.5。それ以外は家系名。
/// サイズ: Nano < 1.2B、Mini < 2.5B、Lite < 4B、Lite+ < 8B、Core < 14B、Core+ < 27B、Max < 48B、Max+ < 120B、それ以上 Extreme。
String raiModelCode(RaiModelSpec m) {
  final id = m.id.toLowerCase();
  if (id.contains('agents')) return 'Agent';
  if (id.contains('lfm')) return 'Liquid';
  if (id.contains('qwen')) return 'QA';
  final head = m.label.split(RegExp(r'[\s\-]')).first;
  return head.isEmpty ? m.family : head;
}

String raiSizeClass(double params) {
  if (params < 1.2) return 'Nano';
  if (params < 2.5) return 'Mini';
  if (params < 4) return 'Lite';
  if (params < 8) return 'Lite+';
  if (params < 14) return 'Core';
  if (params < 27) return 'Core+';
  if (params < 48) return 'Max';
  if (params < 120) return 'Max+';
  return 'Extreme';
}

String raiCodename(RaiModelSpec m) => '${raiModelCode(m)} ${raiSizeClass(m.params)}';

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

  /// 1 問 1 答(トークンのストリーム)。[maxTokens] は生成の上限(D-220: 箇条書きの計画は短く)。
  Stream<String> chat(String prompt, {String? system, int? maxTokens});
}

class RaiLlmException implements Exception {
  const RaiLlmException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// フォールアップ先 (D-216): OpenAI 互換のチャット API(ローカル推論サーバー = llama-server / vLLM など)。
/// 端末内モデルが失敗 / 無応答のとき、質問と **MiniLM で近かったリファレンス**(操作の手順)を添えて渡す。
/// URL が未設定なら従来どおり失敗する。
class RaiFallUp {
  const RaiFallUp({this.baseUrl = '', this.model = '', this.token = '', this.client});
  final String baseUrl;
  final String model;
  final String token;
  final http.Client? client;

  bool get configured => baseUrl.trim().isNotEmpty;

  Uri get endpoint => Uri.parse('${baseUrl.trim().replaceAll(RegExp(r'/+$'), '')}/chat/completions');

  /// 送るメッセージ(system にリファレンスを添える)。
  List<Map<String, String>> messages(String prompt, {String? system, List<String> context = const []}) => [
        if ((system ?? '').isNotEmpty || context.isNotEmpty)
          {'role': 'system', 'content': [if ((system ?? '').isNotEmpty) system!, if (context.isNotEmpty) '参考(操作リファレンス、近い順):', ...context].join('\n')},
        {'role': 'user', 'content': prompt},
      ];

  Future<String> chat(String prompt, {String? system, List<String> context = const []}) async {
    if (!configured) throw const RaiLlmException('フォールアップ先(サーバー側)が未接続です');
    final c = client ?? http.Client();
    try {
      final res = await c
          .post(
            endpoint,
            headers: {'content-type': 'application/json', if (token.trim().isNotEmpty) 'authorization': 'Bearer ${token.trim()}'},
            body: jsonEncode({
              if (model.trim().isNotEmpty) 'model': model.trim(),
              'messages': messages(prompt, system: system, context: context),
              'max_tokens': 512,
              'temperature': 0.4,
              'stream': false,
              'chat_template_kwargs': {'enable_thinking': false},
            }),
          )
          .timeout(const Duration(seconds: 90));
      if (res.statusCode != 200) throw RaiLlmException('推論サーバー HTTP ${res.statusCode}');
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
      final choices = j['choices'] as List? ?? const [];
      final content = choices.isEmpty ? null : ((choices.first as Map)['message'] as Map?)?['content'];
      final text = '${content ?? ''}'.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trim();
      if (text.isEmpty) throw const RaiLlmException('推論サーバーから返事がありませんでした');
      return text;
    } on RaiLlmException {
      rethrow;
    } catch (e) {
      throw RaiLlmException('推論サーバーに届きません: $e');
    } finally {
      if (client == null) c.close();
    }
  }
}

/// 推論サーバーの設定エリア (D-216): `serverUrl`(…/v1)/ `serverModel` / `serverToken`。
const raiSettingsArea = 'rai';

final raiFallUpProvider = Provider<RaiFallUp>((ref) {
  final v = ref.watch(settingsAreaProvider(raiSettingsArea)).value ?? const <String, Object?>{};
  return RaiFallUp(baseUrl: '${v['serverUrl'] ?? ''}', model: '${v['serverModel'] ?? ''}', token: '${v['serverToken'] ?? ''}');
});

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
  Stream<String> chat(String prompt, {String? system, int? maxTokens}) => Stream.error(RaiLlmException(reason));
}
