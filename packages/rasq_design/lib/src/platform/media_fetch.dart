import 'dart:typed_data';

import 'media_fetch_io.dart' if (dart.library.js_interop) 'media_fetch_web.dart' as impl;

/// 制限のある面の画像を、ホストの通信で取る (セキュリティ確認 2026-10-09 の [11])。
///
/// ふつうの画像の読み込み (`NetworkImage`) はリダイレクトを黙って追うので、宣言した接続先がほかへ転送すると、
/// プラグインの宣言に無い接続先にもホストが GET を送ってしまう。ここでは:
/// - 端末: リダイレクトを自分で追い、**各ホップ**で [allowHop] に聞く(だめなら転送先へは送らない)。最大 [maxRedirects] 回。
/// - Web: ブラウザの読み込みでは転送先を確かめられないので、`fetch` の `redirect: 'error'` で**リダイレクトを追わない**
///   (`<img>` にも回さない。CORS ヘッダの無い接続先の画像は出ない)。
/// 本文は [maxBytes] まで(超えたら捨てる)。
Future<Uint8List> rasqFetchMedia(Uri url, bool Function(Uri url) allowHop, {int maxRedirects = rasqMediaMaxRedirects, int maxBytes = rasqMediaMaxBytes}) =>
    impl.fetchMedia(url, allowHop, maxRedirects: maxRedirects, maxBytes: maxBytes);

/// 追ってよいリダイレクトの数(各ホップは方針で確かめる)。
const rasqMediaMaxRedirects = 5;

/// 画像 1 枚の本文の上限。
const rasqMediaMaxBytes = 32 * 1024 * 1024;

/// 方針で止めた(その URL へは送っていない)。
class RasqMediaBlocked implements Exception {
  const RasqMediaBlocked(this.url, this.reason);
  final Uri url;
  final String reason;
  @override
  String toString() => 'RasqMediaBlocked($reason: $url)';
}
