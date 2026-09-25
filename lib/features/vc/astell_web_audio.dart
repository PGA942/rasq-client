/// Web 版の通話 / 配信の音 (D-318)。ネイティブでは何もしない(受けた声はそのまま鳴り、マイクは OS が許可を決める)。
library;

export 'astell_web_audio_io.dart' if (dart.library.js_interop) 'astell_web_audio_web.dart';
