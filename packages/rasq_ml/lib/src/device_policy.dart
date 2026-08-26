import 'dart:io';

import 'package:meta/meta.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 端末 CPU 使用率(0..1)の取得。取れない環境では null を返す。
abstract class CpuLoadProbe {
  Future<double?> sample();
}

/// Linux の `/proc/stat` を 2 点サンプリングして全体 CPU 使用率を出す。
/// パーサは [usageBetween] として切り出してあり単体テスト可能。
/// macOS / iOS / Android(/proc/stat 読める端末以外)では null。
class ProcStatCpuProbe implements CpuLoadProbe {
  const ProcStatCpuProbe({this.interval = const Duration(milliseconds: 200)});

  final Duration interval;

  @override
  Future<double?> sample() async {
    final f = File('/proc/stat');
    if (!f.existsSync()) return null;
    try {
      final before = f.readAsStringSync();
      await Future<void>.delayed(interval);
      final after = f.readAsStringSync();
      return usageBetween(before, after);
    } catch (_) {
      return null;
    }
  }

  /// `cpu  user nice system idle iowait irq softirq …` 行 2 点間の busy 率。
  static double? usageBetween(String before, String after) {
    List<int>? parse(String s) {
      final line = s.split('\n').firstWhere((l) => l.startsWith('cpu '), orElse: () => '');
      if (line.isEmpty) return null;
      return [for (final part in line.split(RegExp(r'\s+')).skip(1)) int.tryParse(part) ?? 0];
    }

    final b = parse(before);
    final a = parse(after);
    if (b == null || a == null) return null;
    int total(List<int> v) => v.fold(0, (x, y) => x + y);
    int idle(List<int> v) => (v.length > 3 ? v[3] : 0) + (v.length > 4 ? v[4] : 0); // idle + iowait
    final dTotal = total(a) - total(b);
    final dIdle = idle(a) - idle(b);
    if (dTotal <= 0) return null;
    return (1 - dIdle / dTotal).clamp(0.0, 1.0);
  }
}

/// ローカル(デバイス)推論の許可判定 (D-024 追補)。
///
/// 「HTL アクティブ数が少なければ(CPU 利用率 75% 未満ならば)ローカルで
/// SigLIP する」— どちらの指標も**取れないときは許可**に倒す(サーバーが
/// 無い構成ではローカル駆動しか試験手段が無いため)。
@immutable
class DevicePolicy {
  const DevicePolicy({this.maxCpuUsage = 0.75, this.maxActiveHtlPosts = 30});

  /// これ以上の CPU 使用率(0..1)ならローカル実行を避ける。
  final double maxCpuUsage;

  /// 直近ウィンドウの HTL 流入投稿数がこれを超えたらローカル実行を避ける。
  final int maxActiveHtlPosts;

  bool allowsLocal({double? cpuUsage, int? activeHtlPosts}) {
    if (cpuUsage != null && cpuUsage >= maxCpuUsage) return false;
    if (activeHtlPosts != null && activeHtlPosts > maxActiveHtlPosts) return false;
    return true;
  }
}

/// onnx runtime の実行プロバイダ解決: マニフェストの希望順
/// (`runtimes.onnx.executionProviders`)と端末で使える EP の交差。
/// 交差が空でも `cpu` へフォールバックする。
List<String> resolveExecutionProviders(MlModelManifest manifest, {required List<String> available}) {
  final wanted = manifest.onnx?.executionProviders ?? const ['cpu'];
  final out = [for (final ep in wanted) if (available.contains(ep)) ep];
  if (!out.contains('cpu')) out.add('cpu');
  return out;
}
