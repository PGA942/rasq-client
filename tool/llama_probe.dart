// dart run tool/llama_probe.dart <libdir> <model.gguf> [nCtx] [nGpuLayers] — RAi の端末内 LLM と同じパラメーターで
// llama_cpp_dart(0.9 系 = LlamaEngine)を回し、トークンと RSS を出す(メモリ暴走 / 無応答の切り分け用、D-188 → D-217)。
import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart' as lc;

String rss() {
  final f = File('/proc/self/status');
  if (!f.existsSync()) return '?';
  final m = RegExp(r'VmRSS:\s+(\d+) kB').firstMatch(f.readAsStringSync());
  return m == null ? '?' : '${(int.parse(m.group(1)!) / 1024).toStringAsFixed(0)} MB';
}

/// RAi と同じ ChatML(空の think ブロックで思考を封じる)。
String chatMl(String system, String user) => '<|im_start|>system\n$system<|im_end|>\n<|im_start|>user\n$user<|im_end|>\n<|im_start|>assistant\n<think>\n\n</think>\n\n';

Future<void> main(List<String> args) async {
  final libDir = args[0];
  final model = args[1];
  final nCtx = args.length > 2 ? int.parse(args[2]) : 2048;
  final gpuLayers = args.length > 3 ? int.parse(args[3]) : 99;
  final lib = [File('$libDir/libllama.dylib'), File('$libDir/libllama.so')].firstWhere((f) => f.existsSync(), orElse: () => File('$libDir/libllama.so'));
  stdout.writeln('lib=${lib.path} model=$model nCtx=$nCtx rss(start)=${rss()}');
  final t0 = DateTime.now();
  final engine = await lc.LlamaEngine.spawn(
    libraryPath: lib.path,
    modelParams: lc.ModelParams(path: model, gpuLayers: gpuLayers, mainGpu: gpuLayers == 0 ? -1 : 0),
    contextParams: lc.ContextParams(nCtx: nCtx, nBatch: 256, nUbatch: 256, nThreads: 4, nThreadsBatch: 4),
  );
  stdout.writeln('loaded in ${DateTime.now().difference(t0).inMilliseconds} ms rss=${rss()} devices=${engine.devices.map((d) => d.name).join(',')}');
  final session = await engine.createSession();
  var text = '';
  var n = 0;
  await for (final e in session.generate(
    prompt: chatMl('あなたは SNS ブラウザ RASQ のアシスタント「RAi」です。日本語で、短く(3 文以内)答えてください。', 'こんにちは、何ができますか？'),
    addSpecial: true,
    sampler: const lc.SamplerParams(temperature: 0.4, topP: 0.95, repeatPenalty: 1.1),
    maxTokens: 512,
  ).timeout(const Duration(minutes: 3))) {
    switch (e) {
      case lc.TokenEvent():
        text += e.text;
        n++;
        if (n % 20 == 0) stdout.writeln('tokens=$n rss=${rss()}');
      case lc.DoneEvent():
        stdout.writeln('done reason=${e.reason} tokens=${e.generatedCount} rss=${rss()}\n---\n$text\n---');
      case lc.ShiftEvent():
        break;
    }
  }
  await session.dispose();
  await engine.dispose();
  stdout.writeln('disposed rss=${rss()}');
  exit(0);
}
