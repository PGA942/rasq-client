import 'package:web/web.dart' as web;

/// Safari(と iOS の全ブラウザ = WebKit)か。Chrome / Edge / Android の UA にも "Safari" が入るので、それらを除く。
bool isSafariBrowser() {
  final ua = web.window.navigator.userAgent;
  return ua.contains('Safari') && !RegExp(r'Chrome|Chromium|Edg/|Android').hasMatch(ua);
}
