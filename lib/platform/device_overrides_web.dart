import 'package:flutter_riverpod/misc.dart' show Override;

/// Web 版 (D-295): 端末内のモデル(RAi の LLM / 埋め込み / 絵文字の画像検索)は載らない。既定の「使えない」のまま。
List<Override> deviceOverrides() => const [];
