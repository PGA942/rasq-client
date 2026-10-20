import '../l10n/l10n.dart';
/// エラー文から秘密を外す (REC-03、2026-09-28 録画): WebSocket の接続エラーは接続先の URL を丸ごと含み、
/// その `?token=` に RASQ アカウントのトークンが載る。画面やログに出す前に通す。
/// - URL のクエリ(`?…`)とフラグメントは丸ごと `?…` に置き換える(トークン以外の値も出さない)
/// - `token=` / `access_token=` / `i=` / `Bearer …` の値も念のため伏せる(URL の外に出ている場合)
String redactSecrets(String text) {
  var s = text.replaceAllMapped(RegExp(r'((?:https?|wss?)://[^\s?#\x27"]+)[?#][^\s\x27"]*'), (m) => '${m.group(1)}?…');
  s = s.replaceAllMapped(RegExp(r'\b(token|access_token|refresh_token|accessJwt|refreshJwt|i)=([^&\s\x27"]+)', caseSensitive: false), (m) => '${m.group(1)}=…');
  s = s.replaceAllMapped(RegExp(r'(Bearer\s+)[A-Za-z0-9._~+/=-]+', caseSensitive: false), (m) => '${m.group(1)}…');
  return s;
}

/// WebSocket の接続に失敗したときの、利用者向けの短い説明(秘密は含まない)。
String wsConnectErrorMessage(Object e) {
  final raw = '$e';
  if (raw.contains('was not upgraded to websocket') || raw.contains('404') || raw.contains('410')) {
    return appL10n.backendRoomClosed;
  }
  if (raw.contains('401') || raw.contains('403')) return appL10n.backendRoomForbidden;
  return appL10n.backendRoomConnectFailed(redactSecrets(raw));
}
