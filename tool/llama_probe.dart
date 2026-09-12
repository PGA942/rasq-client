// dart run tool/llama_probe.dart <libdir> <model.gguf>  — RAi の端末内 LLM と同じパラメーターで llama_cpp_dart を回し、
// トークンと RSS を出す(メモリ暴走の切り分け用、D-188)。
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart' as lc;

String rss() {
  final m = RegExp(r'VmRSS:\s+(\d+) kB').firstMatch(File('/proc/self/status').readAsStringSync());
  return m == null ? '?' : '${(int.parse(m.group(1)!) / 1024).toStringAsFixed(0)} MB';
}

Future<void> main(List<String> args) async {
  final libDir = args[0];
  final model = args[1];
  final nCtx = args.length > 2 ? int.parse(args[2]) : 1024;
  final mtmd = File('$libDir/libmtmd.so');
  lc.Llama.libraryPath = mtmd.existsSync() ? mtmd.path : '$libDir/libllama.so';
  stdout.writeln('lib=${lc.Llama.libraryPath} model=$model nCtx=$nCtx rss(start)=${rss()}');
  // 動的バックエンド (D-188): ggml_backend_load_all は実行ファイルの隣しか探さないので、明示的に読み込む。
  final lib = lc.Llama.lib;
  for (final f in Directory(libDir).listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (!name.startsWith('libggml-cpu') && !name.startsWith('libggml-metal') && !name.startsWith('libggml-blas')) continue;
    if (!name.endsWith('.so') && !name.endsWith('.dylib')) continue;
    final ptr = name.toNativeUtf8();
    final r = lib.ggml_backend_load(f.path.toNativeUtf8().cast());
    calloc.free(ptr);
    stdout.writeln('backend $name -> ${r.address != 0}');
    if (r.address != 0 && name.startsWith('libggml-cpu')) break; // CPU は 1 つで足りる
  }
  stdout.writeln('backends registered=${lib.ggml_backend_reg_count()}');
  final load = lc.LlamaLoad(
    path: model,
    modelParams: lc.ModelParams()
      ..nGpuLayers = (args.length > 3 ? int.parse(args[3]) : 99)
      ..mainGpu = (args.length > 3 && args[3] == '0' ? -1 : 0),
    contextParams: lc.ContextParams()
      ..nCtx = nCtx
      ..nBatch = 256
      ..nPredict = 256
      ..nThreads = 4
      ..nThreadsBatch = 4,
    samplingParams: lc.SamplerParams()
      ..temp = 0.4
      ..topP = 0.95
      ..penaltyRepeat = 1.1,
    verbose: true,
  );
  final parent = lc.LlamaParent(load);
  final t0 = DateTime.now();
  await parent.init();
  stdout.writeln('loaded in ${DateTime.now().difference(t0).inMilliseconds} ms rss=${rss()}');
  final history = lc.ChatHistory()
    ..addMessage(role: lc.Role.system, content: 'あなたは SNS ブラウザ RASQ のアシスタント「RAi」です。日本語で、短く(3 文以内)答えてください。')
    ..addMessage(role: lc.Role.user, content: 'こんにちは、何ができますか？')
    ..addMessage(role: lc.Role.assistant, content: '');
  final prompt = history.exportFormat(lc.ChatFormat.chatml, leaveLastAssistantOpen: true);
  var text = '';
  var n = 0;
  final sub = parent.stream.listen((t) {
    text += t;
    n++;
    if (n % 20 == 0) stdout.writeln('tokens=$n rss=${rss()}');
  });
  final done = parent.completions.first;
  final id = await parent.sendPrompt(prompt);
  stdout.writeln('prompt id=$id');
  final ev = await done.timeout(const Duration(minutes: 3));
  await sub.cancel();
  stdout.writeln('done success=${ev.success} tokens=$n rss=${rss()}\n---\n$text\n---');
  await parent.dispose();
  stdout.writeln('disposed rss=${rss()}');
  exit(0);
}
