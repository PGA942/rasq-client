// RAi リファレンス検索の評価 (D-189)。
//
//   dart run tool/rai_reference_eval.dart [--k 3] [--threshold 0.42] [--verbose]
//
// assets/rai/eval.jsonl の {q, op} を n-gram 埋め込み(SigLIP の代替、同じ契約)で引き、
// top-1 / top-3 の的中率と、外した問い合わせを出す。SigLIP 実配線時は同じ eval で比べる。
import 'dart:io';

import 'package:rasq_client/features/rai/rai_reference.dart';

Future<void> main(List<String> args) async {
  var k = 3;
  double? threshold;
  var verbose = false;
  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--k':
        k = int.parse(args[++i]);
      case '--threshold':
        threshold = double.parse(args[++i]);
      case '--verbose':
        verbose = true;
    }
  }
  final root = File(Platform.script.toFilePath()).parent.parent.path;
  final index = await RaiReferenceIndex.fromJsonl(
    functionsJsonl: await File('$root/assets/rai/functions.jsonl').readAsString(),
    operationsJsonl: await File('$root/assets/rai/operations.jsonl').readAsString(),
    embedder: const NgramRaiEmbedder(),
  );
  final evals = parseJsonl(await File('$root/assets/rai/eval.jsonl').readAsString());
  final result = await evaluate(index, evals, k: k, threshold: threshold);
  stdout.writeln('embedder=${index.embedder.name} functions=${index.functions.length} operations=${index.operations.length} queries=${evals.length}');
  stdout.writeln('top1=${(result.top1 * 100).toStringAsFixed(1)}% top$k=${(result.topK * 100).toStringAsFixed(1)}% miss=${result.misses.length}');
  for (final m in result.misses) {
    stdout.writeln('  MISS "${m.query}" expected=${m.expected} got=${m.got.join(', ')}');
  }
  if (verbose) {
    for (final t in index.traces.reversed) {
      stdout.writeln('  $t');
    }
  }
  exitCode = result.top1 >= 0.9 ? 0 : 1;
}

class RaiEvalResult {
  const RaiEvalResult({required this.top1, required this.topK, required this.misses});
  final double top1;
  final double topK;
  final List<({String query, String expected, List<String> got})> misses;
}

/// eval.jsonl を回す(テストからも呼ぶ)。
Future<RaiEvalResult> evaluate(RaiReferenceIndex index, List<Map<String, Object?>> evals, {int k = 3, double? threshold}) async {
  var top1 = 0, topK = 0;
  final misses = <({String query, String expected, List<String> got})>[];
  for (final e in evals) {
    final q = '${e['q']}';
    final expected = '${e['op']}';
    final hits = await index.searchOperations(q, k: k, threshold: threshold);
    final ids = [for (final h in hits) h.item.id];
    if (ids.isNotEmpty && ids.first == expected) top1++;
    if (ids.contains(expected)) topK++;
    if (ids.isEmpty || ids.first != expected) misses.add((query: q, expected: expected, got: ids));
  }
  final n = evals.isEmpty ? 1 : evals.length;
  return RaiEvalResult(top1: top1 / n, topK: topK / n, misses: misses);
}
