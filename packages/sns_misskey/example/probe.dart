import 'package:sns_misskey/sns_misskey.dart';

Future<void> main(List<String> args) async {
  final host = args.isEmpty ? 'misskey.io' : args.first;
  final plugin = MisskeyPlugin();
  final sw = Stopwatch()..start();
  try {
    final info = await plugin.inspectServer(host);
    print('OK ${sw.elapsedMilliseconds}ms: ${info.name} (${info.host}) v${info.version} registration=${info.registrationOpen}');
    final flow = await plugin.beginAuth(host);
    print('MiAuth URL: ${(flow as MiAuthFlow).url}');
  } catch (e) {
    print('FAIL ${sw.elapsedMilliseconds}ms: $e');
  }
}
