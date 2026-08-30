import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// プラグインへの `call` の実行口(同期/非同期コントローラの `invoke` を
/// そのまま渡す)。戻りは boundary の `result` メッセージ。
typedef WasmSnsInvoke = Future<Map<String, dynamic>> Function(String fn, Map<String, Object?> args);

/// SnsSession 契約の wasm 境界写像 v1 (D-074 / M5d)。
///
/// 基本思想の「SNS プラグインのイベントハンドラー関数は一定程度は抽象的な
/// 関数で共通化 → 既存 SnsSession 契約の boundary 写像として wasm 化」の
/// 実装形: 抽象関数を `call("sns.<fn>")` に写し、戻りの Post ワイヤ
/// (`rasq.post/1`、[SnsWire])をホストモデルへ取り込む。
///
/// v1 は `timeline` のみ — 以降の関数(thread / createPost / performAction
/// …)は同じ形で 1 本ずつ増やす。未実装は [UnsupportedError] のまま
/// (ホストが UI を隠す既定動作)。
class WasmSnsSession extends SnsSessionBase {
  WasmSnsSession({required this.account, required WasmSnsInvoke invoke, this.pluginId = 'wasm', this.extraArgs = const {}}) : _invoke = invoke; // ignore: prefer_initializing_formals

  @override
  final AccountId account;

  @override
  final String pluginId;

  final WasmSnsInvoke _invoke;

  /// 毎呼び出しに足す引数(dev 試験での baseUrl/host 上書き等)。
  final Map<String, Object?> extraArgs;

  @override
  List<TimelineKind> get timelines => const [TimelineKind.local];

  @override
  List<ActionDescriptor> get actions => const [];

  /// `call("sns.<fn>")` → ok チェック → value。エラーは [SnsApiException]
  /// に写す(ホストのエラービュー/リトライがそのまま効く)。
  Future<Map<String, Object?>> _call(String fn, Map<String, Object?> args) async {
    final result = await _invoke(fn, {...args, ...extraArgs});
    if (result['ok'] == true) return (result['value'] as Map? ?? const {}).cast<String, Object?>();
    final error = (result['error'] as Map?)?.cast<String, Object?>() ?? const {};
    final message = '${error['message'] ?? 'wasm sns call failed: $fn'}';
    throw SnsApiException(ErrorCode.tryParse('${error['code'] ?? ''}', message: message) ?? ErrorCode.internalServerError.copyWith(message: message));
  }

  @override
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20}) async {
    final value = await _call('sns.timeline', {'kind': kind.id, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }
}
