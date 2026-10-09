import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../backend/limited_http.dart';

/// 審査中の版の仮インポート (D-436、rasq-judge J-017 の 4 段目 = 人の確認と対)。
///
/// 審査中の版はストアから落とせないので、judge の審査の画面が**期限つき(30 分)・ログインの要らないリンク**
/// (`https://…/review-dl/<token>`)と、そのリンクを入れた QR(`rasq://dev-import?url=<リンク>`)を出す。
/// 管理者のクライアントは:
/// - 端末のカメラアプリで QR を読む → この画面(`/dev/wasm`)が URL 入りで開く(**読み込みは押すまでしない**。
///   知らない人のリンクで勝手にコードを入れないように。チャイルドセーフのリンク D-309 と同じ考え)。
/// - またはリンクを「URL から読む」に貼る。
/// 落としたものはアプリの保存領域(`review-imports/`)に置き、ファイルから読むのと同じ道(署名の段 = 制限モード、
/// スロットに登録できる)を通る。

const reviewImportLinkScheme = 'rasq';
const reviewImportLinkHost = 'dev-import';

/// 落とす配布物の上限。
const reviewImportMaxBytes = 64 * 1024 * 1024;

/// URL として受けるか(http / https だけ)。
bool isReviewImportUrl(String raw) {
  final u = Uri.tryParse(raw.trim());
  return u != null && (u.scheme == 'https' || u.scheme == 'http') && u.host.isNotEmpty;
}

/// `rasq://dev-import?url=…` → アプリの中の場所(`/dev/wasm?url=…`)。このリンクでなければ null。
String? reviewImportDeepLinkLocation(Uri uri) {
  if (uri.scheme != reviewImportLinkScheme || uri.host != reviewImportLinkHost) return null;
  final url = uri.queryParameters['url'] ?? '';
  return Uri(path: '/dev/wasm', queryParameters: isReviewImportUrl(url) && url.length <= 2048 ? {'url': url} : null).toString();
}

/// 落とした配布物の置き場(テストで差し替える)。
final reviewImportDirProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}/review-imports');
    });

/// 落とす口(テストで差し替える)。
final reviewImportHttpProvider = Provider<http.Client>((ref) {
  final c = http.Client();
  ref.onDispose(c.close);
  return c;
});

/// [url] の配布物を落として、保存領域のファイルにする。戻りはそのパス。
/// 本文は [reviewImportMaxBytes] までしか読まない(超えたら読むのをやめて通信を切る。全部貯めてから大きさを見ない、
/// セキュリティ確認 2026-10-09 の [18])。
Future<String> downloadReviewImport(String url, {required http.Client client, required Future<Directory> Function() dir}) async {
  final LimitedResponse res;
  try {
    res = await getLimited(Uri.parse(url.trim()), maxBytes: reviewImportMaxBytes, timeout: const Duration(seconds: 60), client: client);
  } on ResponseTooLargeException catch (e) {
    throw ReviewImportException('大きさが不正です(${e.maxBytes} bytes を超えています)');
  }
  if (res.statusCode == 404) throw const ReviewImportException('リンクの期限が切れたか、違うリンクです。審査の画面で作り直してください');
  if (res.statusCode != 200) throw ReviewImportException('取得に失敗しました(HTTP ${res.statusCode})');
  final bytes = res.bodyBytes;
  if (bytes.isEmpty) throw ReviewImportException('大きさが不正です(${bytes.length} bytes)');
  final d = await dir();
  await d.create(recursive: true);
  final file = File('${d.path}/${reviewImportFileName(res.headers['content-disposition'], url)}');
  await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  return file.path;
}

/// 置くファイルの名前: `content-disposition` の filename → URL の最後 → 既定。英数字と `._-` だけ。
String reviewImportFileName(String? disposition, String url) {
  final fromHeader = disposition == null ? null : RegExp(r'filename="?([^";]+)"?').firstMatch(disposition)?.group(1);
  final raw = fromHeader ?? 'review-import.rasqpkg';
  final safe = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  return safe.isEmpty || safe.startsWith('.') ? 'review-import.rasqpkg' : safe;
}

class ReviewImportException implements Exception {
  const ReviewImportException(this.message);
  final String message;
  @override
  String toString() => message;
}
