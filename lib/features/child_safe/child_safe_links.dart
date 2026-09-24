import 'package:flutter/foundation.dart';

/// チャイルドセーフのリンク (D-309): 保護者の画面の QR の中身と、端末のカメラで読んだときに開くアプリの中の画面。
///
/// - つなぐ: `rasq://child-safe/pair?code=<8 字>`(`POST /me/child-safe/pairings` の `link`)。
/// - ログイン: `rasq://child-safe/login?code=<12 字>`(`POST /me/child-safe/children` の `link`)。
///
/// アプリの中の QR の読み取り(カメラのパッケージ)は入れていない: 対応していない面(Linux / Windows)があり、
/// カメラの権限(AndroidManifest / Info.plist)をここで確かめられないため。代わりに `rasq://child-safe/…` を
/// Android(intent-filter)と iOS(CFBundleURLTypes)に登録し、**端末のカメラアプリで QR を読むと、この画面が
/// コード入りで開く**。つなぐ / ログインは**自動では送らない**(知らない人のリンクで見守られないように、
/// 子が画面で確かめて押す)。

const childSafeLinkScheme = 'rasq';
const childSafeLinkHost = 'child-safe';

/// コードの形に寄せる(大文字、`ABCD-EFGH` の `-` はそのまま送ってよい)。リンク(`…?code=…`)を貼っても、コードだけを取る。
String childSafeCodeFromInput(String input) {
  final link = RegExp(r'[?&]code=([A-Za-z0-9-]+)').firstMatch(input);
  final raw = link?.group(1) ?? input;
  return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9-]'), '');
}

String _linkOf(String action, String code) => Uri(scheme: childSafeLinkScheme, host: childSafeLinkHost, path: '/$action', queryParameters: {'code': code}).toString();

/// つなぐコードのリンク(Central の `link` が無いときの控え。形は Central と同じ)。
String childSafePairLink(String code) => _linkOf('pair', code);

/// 保護者が作った子のログインのコードのリンク(同上)。
String childSafeLoginLink(String code) => _linkOf('login', code);

/// 外から来たリンク(`rasq://child-safe/pair?code=…` / `…/login?code=…`)→ アプリの中の場所
/// (`/child-safe/pair?code=…`)。チャイルドセーフのリンクでなければ null。コードは [childSafeCodeFromInput] で
/// 形をそろえ、長すぎるもの(32 字より長い)は捨てる(画面に入れるだけで送らない)。
String? childSafeDeepLinkLocation(Uri uri) {
  if (uri.scheme != childSafeLinkScheme || uri.host != childSafeLinkHost) return null;
  final action = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  if (action != 'pair' && action != 'login') return '/child-safe';
  final code = childSafeCodeFromInput(uri.queryParameters['code'] ?? '');
  return Uri(path: '/child-safe/$action', queryParameters: code.isEmpty || code.length > 32 ? null : {'code': code}).toString();
}

/// 端末のカメラアプリで読んだ QR がアプリを開けるか(`rasq://` を登録している面)。
bool get childSafeLinksOpenApp => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
