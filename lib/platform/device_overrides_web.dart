import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:web/web.dart' as web;

import '../session/session_providers.dart';
import '../session/session_storage.dart';

/// Web 版 (D-295): 端末内のモデル(RAi の LLM / 埋め込み / 絵文字の画像検索)は載らない。既定の「使えない」のまま。
///
/// 保存先: flutter_secure_storage の Web 実装は WebCrypto を使うので、**安全なコンテキスト(https / localhost)でしか動かない**。
/// 開発用に http で開いたとき(tailnet のアドレスなど)だけ、localStorage にそのまま置く代わりを使う。本番は https で配ること。
List<Override> deviceOverrides() => [
      if (!web.window.isSecureContext) sessionStorageProvider.overrideWithValue(_InsecureWebSessionStorage()),
    ];

class _InsecureWebSessionStorage implements SessionStorage {
  _InsecureWebSessionStorage() {
    debugPrint('RASQ: 安全でないコンテキスト (http) で開いています。ログイン情報は暗号化せずに localStorage へ置きます(開発用)。本番は https で配ってください。');
  }
  static const _prefix = 'rasq.insecure.';

  @override
  Future<String?> read(String key) async => web.window.localStorage.getItem('$_prefix$key');
  @override
  Future<void> write(String key, String value) async => web.window.localStorage.setItem('$_prefix$key', value);
  @override
  Future<void> delete(String key) async => web.window.localStorage.removeItem('$_prefix$key');
}
