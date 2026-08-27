import 'package:meta/meta.dart';

/// Error code families.
///
/// 原典: ワイヤーフレーム「検索エラー系」注釈 —
/// 000-999 は HTTP 系リクエストエラー、A00-FFF がアプリ固有エラー
/// (A: 設定 / B: 影響設定(認証設定) / C: プラグイン間データ受け渡し /
/// D: データ破損 / E: Ban・規制モード / F: 予約領域)。
enum ErrorFamily {
  http('', 'HTTP'),
  settings('A', '設定'),
  affectedSettings('B', '影響設定'),
  pluginTransfer('C', 'プラグイン間受け渡し'),
  dataCorruption('D', 'データ破損'),
  regulation('E', '規制'),
  reserved('F', '予約');

  const ErrorFamily(this.prefix, this.label);

  final String prefix;
  final String label;
}

/// A RASQ error code such as `404`, `A25`, `D2F`.
@immutable
class ErrorCode {
  const ErrorCode._(this.family, this.code, {this.title, this.message});

  /// Parses `"404"`, `"A25"`, `"D2F"` (case-insensitive). Returns `null` for
  /// anything that does not match the code grammar.
  static ErrorCode? tryParse(String raw, {String? title, String? message}) {
    final s = raw.trim().toUpperCase();
    final http = RegExp(r'^\d{3}$');
    final app = RegExp(r'^([A-F])([0-9A-F]{2})$');
    if (http.hasMatch(s)) {
      return ErrorCode._(ErrorFamily.http, s, title: title, message: message);
    }
    final m = app.firstMatch(s);
    if (m == null) return null;
    final family = ErrorFamily.values.firstWhere((f) => f.prefix == m.group(1));
    return ErrorCode._(family, s, title: title, message: message);
  }

  factory ErrorCode.http(int status, {String? title, String? message}) => ErrorCode._(
        ErrorFamily.http,
        status.toString().padLeft(3, '0'),
        title: title,
        message: message,
      );

  factory ErrorCode.app(ErrorFamily family, String hex2, {String? title, String? message}) {
    assert(family != ErrorFamily.http);
    assert(RegExp(r'^[0-9A-Fa-f]{2}$').hasMatch(hex2));
    return ErrorCode._(family, '${family.prefix}${hex2.toUpperCase()}', title: title, message: message);
  }

  final ErrorFamily family;

  /// Full code string, e.g. `404` / `A25`.
  final String code;

  /// Short English title as shown in wireframes ("Not Found", "No Trend Requirement").
  final String? title;

  /// Localised hint for the user ("好きなジャンル/方向性の設定を変更してください").
  final String? message;

  /// Whether the wireframes call for the compact rendering (404 / 408 only).
  bool get isCompact => family == ErrorFamily.http && (code == '404' || code == '408');

  /// Display string: `Error:A25 No Trend Requirement`.
  String get display => title == null ? 'Error:$code' : 'Error:$code $title';

  ErrorCode copyWith({String? title, String? message}) =>
      ErrorCode._(family, code, title: title ?? this.title, message: message ?? this.message);

  @override
  bool operator ==(Object other) => other is ErrorCode && other.code == code;

  @override
  int get hashCode => code.hashCode;

  @override
  String toString() => display;

  // Well-known codes used across wireframes.
  static final notFound = ErrorCode.http(404, title: 'Not Found');
  static final timeout = ErrorCode.http(408, title: 'Request Timeout', message: 'インターネット接続を確認してください');
  static final methodNotAcceptable = ErrorCode.http(405, title: 'Method not Acceptable', message: 'プラグインの障害情報をチェックしてください');
  static final internalServerError = ErrorCode.http(500, title: 'Internal Server Error', message: 'サーバーでエラーが発生しました');
  static final unauthorized = ErrorCode.http(401, title: 'Unauthorized');
  static final noTrendRequirement = ErrorCode.app(ErrorFamily.settings, '25', title: 'No Trend Requirement', message: '好きなジャンル/方向性の設定を変更してください');
  static final relationalTimelineBroken = ErrorCode.app(ErrorFamily.dataCorruption, '2F', title: 'Relational Timeline Broken', message: 'リロードすると解決することがあります');
}
