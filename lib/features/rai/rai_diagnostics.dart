import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// RAi を開くまわりで起きた失敗の記録 (D-516)。3D のマスコット / 端末内モデルの準備が失敗しても RAi は開き、
/// ここに残す。`debugPrint`(Android は `adb logcat -s flutter` で読める)と、開発者モードの RAi サイドバーの「診断」に出す。
@immutable
class RaiDiagnostic {
  const RaiDiagnostic({required this.at, required this.area, required this.message});
  final DateTime at;

  /// どこで(`3d` / `llm` / `embedding` / `open`)。
  final String area;
  final String message;
}

class RaiDiagnostics extends Notifier<List<RaiDiagnostic>> {
  /// 残す件数(古いものから捨てる)。
  static const max = 30;

  @override
  List<RaiDiagnostic> build() => const [];

  void add(String area, String message) {
    // ログの目印 (D-516): 実機の確認は `adb logcat -s flutter | grep 'RAi diag'`。
    debugPrint('RAi diag [$area]: $message');
    if (!ref.mounted) return;
    final next = [...state, RaiDiagnostic(at: DateTime.now(), area: area, message: message)];
    state = next.length > max ? next.sublist(next.length - max) : next;
  }
}

final raiDiagnosticsProvider = NotifierProvider<RaiDiagnostics, List<RaiDiagnostic>>(RaiDiagnostics.new);

/// 3D の RAi の準備の段階の記録 (D-520)。Android の実機で「20 秒たっても準備が終わらない」だけが残り、どこで止まったか
/// 分からなかった。段階ごとに `RAi diag [3d]: stage <名前> +<開始からのミリ秒>ms` を残し、見張りの理由には最後に着いた段階を付ける。
class Rai3dStages {
  Rai3dStages(this._report, {Stopwatch? clock}) : _clock = (clock ?? Stopwatch())..start();
  final void Function(String message) _report;
  final Stopwatch _clock;
  String _current = 'created';
  int _at = 0;

  /// 最後に着いた段階。
  String get current => _current;
  int get elapsedMs => _clock.elapsedMilliseconds;

  void mark(String stage, [String? detail]) {
    _current = stage;
    _at = elapsedMs;
    _report('stage $stage +${_at}ms${detail == null ? '' : ': $detail'}');
  }

  /// 見張り / 失敗の理由に付ける: 最後に着いた段階と、そこからの経過。
  String get summary => 'last stage: $_current at +${_at}ms, now +${elapsedMs}ms';
}

/// 段階 [stage] を記録しながら [body] を待つ (D-520)。`<stage> start` / `<stage> done` を残す。[timeout] を過ぎたら
/// [TimeoutException](段階の名前入り)で失敗させ、止まったまま見張りの 20 秒を待たない。
Future<T> raiStage<T>(Rai3dStages stages, String stage, Future<T> Function() body, {Duration? timeout, String? Function(T value)? detail}) async {
  stages.mark('$stage start');
  var f = body();
  if (timeout != null) {
    f = f.timeout(timeout, onTimeout: () => throw TimeoutException('$stage did not finish in ${timeout.inSeconds}s', timeout));
  }
  final v = await f;
  stages.mark('$stage done', detail?.call(v));
  return v;
}
