import 'package:flutter/widgets.dart';

import 'web_image_io.dart' if (dart.library.js_interop) 'web_image_web.dart';

/// Web 版での画像の出し方 (D-298)。端末では無視される。
///
/// SNS のメディア / 絵文字のサーバーは CORS ヘッダを付けないものが多く、Flutter Web の通常の読み方 (XHR → デコード) では読めない。
/// - 通常: まず XHR、だめなら `<img>`([WebHtmlElementStrategy.fallback])。
/// - **Safari**: 実機で、XHR が CORS で落ちたあと画像が出ないままになった(Chrome は出る)。原因は未特定なので、最初から `<img>`([WebHtmlElementStrategy.prefer])で出す。
final WebHtmlElementStrategy rasqWebImageStrategy = isSafariBrowser() ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.fallback;
