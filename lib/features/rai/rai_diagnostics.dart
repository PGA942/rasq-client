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
