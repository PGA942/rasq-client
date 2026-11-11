import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// アプリの中のブラウザの「この画面を探す」(D-552) の、ページの写し。
///
/// ページの上から [pageSnapshotMaxScreens] 画面ぶんまでを、スクロールしながら見えている範囲を撮ってつなぐ。
/// 見えている範囲を撮るのはネイティブの口(`rasq/web_snapshot`: Android = WebView を描く、iOS / macOS = `WKWebView.takeSnapshot`)。撮れない端末では、
/// ページの文字の位置だけを読んで**見取り図**(文字を置いた下書き)を出す — 囲んで文字で探すことはできる(画像では探せない)。
/// 写しはメモリに持つだけで、保存しない。

/// 撮る長さの上限(画面の数)と、写しの幅の上限(画素)。
const pageSnapshotMaxScreens = 8;
const pageSnapshotMaxWidth = 720;

/// ページの中の文字 1 つ(位置はページの座標、CSS の画素)。
@immutable
class PageTextItem {
  const PageTextItem(this.rect, this.text);
  final ui.Rect rect;
  final String text;
}

/// ページの写し。位置と大きさは **ページの座標(CSS の画素)**。
@immutable
class PageSnapshot {
  const PageSnapshot({required this.width, required this.height, required this.viewportHeight, this.image, this.texts = const [], this.url, this.title = ''});

  /// ページの幅と、写した高さ。
  final double width;
  final double height;

  /// 1 画面の高さ(長さのスライダーの刻み)。
  final double viewportHeight;

  /// つないだ画像。撮れなかった端末では null(見取り図を出す)。
  final ui.Image? image;
  final List<PageTextItem> texts;
  final Uri? url;
  final String title;

  bool get hasImage => image != null;

  /// 画像の画素 / CSS の画素。
  double get imageScale => image == null || width <= 0 ? 1 : image!.width / width;
}

/// 囲みの中の文字(中心が囲みに入っているものを、上から・左からの順に)。[maxChars] まで。
String pageRegionText(List<PageTextItem> texts, ui.Rect region, {int maxChars = 200}) {
  final hit = [for (final t in texts) if (region.contains(t.rect.center)) t]
    ..sort((a, b) => (a.rect.top - b.rect.top).abs() > 6 ? a.rect.top.compareTo(b.rect.top) : a.rect.left.compareTo(b.rect.left));
  final s = hit.map((t) => t.text).join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.runes.length <= maxChars ? s : String.fromCharCodes(s.runes.take(maxChars));
}

/// 囲みを画像から切り抜く(PNG)。長辺は [maxEdge] まで縮める。画像が無い / 囲みが外なら null。
Future<Uint8List?> cropPageSnapshot(PageSnapshot snapshot, ui.Rect region, {int maxEdge = 1600}) async {
  final image = snapshot.image;
  if (image == null) return null;
  final s = snapshot.imageScale;
  final src = ui.Rect.fromLTRB(region.left * s, region.top * s, region.right * s, region.bottom * s).intersect(ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));
  if (src.width < 2 || src.height < 2) return null;
  final k = math.min(1.0, maxEdge / math.max(src.width, src.height));
  final w = math.max(1, (src.width * k).round());
  final h = math.max(1, (src.height * k).round());
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(image, src, ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.medium);
  final picture = recorder.endRecording();
  final out = await picture.toImage(w, h);
  picture.dispose();
  try {
    return (await out.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
  } finally {
    out.dispose();
  }
}

/// 撮った範囲を、ページの座標の位置に並べて 1 枚にする。[shots] = (画像, ページの上からの位置)。
Future<ui.Image> stitchPageShots(List<({ui.Image image, double top})> shots, {required double width, required double height}) async {
  final scale = shots.first.image.width / width;
  final w = shots.first.image.width;
  final h = math.max(1, (height * scale).round());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  for (final s in shots) {
    canvas.drawImage(s.image, ui.Offset(0, s.top * scale), ui.Paint());
  }
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(w, h);
  } finally {
    picture.dispose();
  }
}

/// ページの大きさとスクロールの位置を読む JavaScript。
const pageMetricsScript = "(function(){var d=document.documentElement,b=document.body||d;return JSON.stringify({w:window.innerWidth,h:window.innerHeight,"
    "docH:Math.max(d.scrollHeight,b.scrollHeight,d.offsetHeight),y:window.scrollY||0,title:document.title||''});})()";

/// ページの文字と位置を読む JavaScript([maxY] より上、3000 個まで)。`[[x, y, w, h, 文字], …]` の JSON。
String pageTextItemsScript(double maxY) => "(function(maxY){var out=[];if(!document.body)return '[]';var w=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);"
    "var n,r=document.createRange(),sy=window.scrollY||0,sx=window.scrollX||0;"
    "while((n=w.nextNode())&&out.length<3000){var t=(n.nodeValue||'').replace(/\\s+/g,' ').trim();if(!t)continue;var p=n.parentElement;if(!p)continue;"
    "var g=p.tagName;if(g==='SCRIPT'||g==='STYLE'||g==='NOSCRIPT')continue;r.selectNodeContents(n);var b=r.getBoundingClientRect();"
    "if(b.width<1||b.height<1)continue;var y=b.top+sy;if(y>maxY)continue;out.push([Math.round(b.left+sx),Math.round(y),Math.round(b.width),Math.round(b.height),t.slice(0,300)]);}"
    "return JSON.stringify(out);})(${maxY.round()})";

/// [pageTextItemsScript] の結果を読む。
List<PageTextItem> parsePageTextItems(String json) {
  try {
    final j = jsonDecode(json);
    return [
      for (final e in j is List ? j : const [])
        if (e is List && e.length >= 5 && e[4] is String)
          PageTextItem(ui.Rect.fromLTWH((e[0] as num).toDouble(), (e[1] as num).toDouble(), (e[2] as num).toDouble(), (e[3] as num).toDouble()), e[4] as String),
    ];
  } catch (_) {
    return const [];
  }
}

/// WebView のいま見えている範囲を撮る口(JPEG / PNG。撮れない端末は null)。テストで差し替える。
typedef WebViewShot = Future<Uint8List?> Function(WebViewController controller);

final webViewShotProvider = Provider<WebViewShot>((ref) => captureVisibleWebView);

const _snapshotChannel = MethodChannel('rasq/web_snapshot');

Future<Uint8List?> captureVisibleWebView(WebViewController controller) async {
  if (kIsWeb) return null;
  final platform = controller.platform;
  // WebView の番号(ネイティブの側で、その番号から WebView を取り出す)。
  final id = switch (platform) {
    AndroidWebViewController() when defaultTargetPlatform == TargetPlatform.android => platform.webViewIdentifier,
    WebKitWebViewController() when defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS => platform.webViewIdentifier,
    _ => null,
  };
  if (id == null) return null;
  try {
    return await _snapshotChannel.invokeMethod<Uint8List>('captureVisible', {'id': id, 'maxWidth': pageSnapshotMaxWidth});
  } on MissingPluginException {
    return null;
  } catch (e) {
    debugPrint('web snapshot: $e');
    return null;
  }
}

String _jsString(Object? r) {
  if (r is! String) return r?.toString() ?? '';
  if (r.length >= 2 && r.startsWith('"') && r.endsWith('"')) {
    try {
      return jsonDecode(r) as String;
    } catch (_) {}
  }
  return r;
}

Future<ui.Image?> _decode(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } catch (_) {
    return null;
  }
}

/// ページの上から [maxScreens] 画面ぶんまでを写す。スクロールは終わったら元へ戻す。
/// 画像が撮れない端末では、文字の位置だけを持った写し([PageSnapshot.image] が null)を返す。
Future<PageSnapshot> capturePageSnapshot(WebViewController controller, WebViewShot shot, {int maxScreens = pageSnapshotMaxScreens, Duration settle = const Duration(milliseconds: 220)}) async {
  final m = (jsonDecode(_jsString(await controller.runJavaScriptReturningResult(pageMetricsScript))) as Map).cast<String, Object?>();
  final width = (m['w'] as num?)?.toDouble() ?? 0;
  final viewport = (m['h'] as num?)?.toDouble() ?? 0;
  final docH = math.max((m['docH'] as num?)?.toDouble() ?? viewport, viewport);
  final startY = (m['y'] as num?)?.toDouble() ?? 0;
  if (width <= 0 || viewport <= 0) throw StateError('page has no size');
  final height = math.min(docH, viewport * maxScreens);
  final url = Uri.tryParse(await controller.currentUrl() ?? '');
  var texts = const <PageTextItem>[];
  try {
    texts = parsePageTextItems(_jsString(await controller.runJavaScriptReturningResult(pageTextItemsScript(height))));
  } catch (e) {
    debugPrint('page text items: $e');
  }
  final shots = <({ui.Image image, double top})>[];
  try {
    for (var top = 0.0; top < height - 1; top += viewport) {
      // 最後の 1 枚は、ページの末尾に合わせて上へずらす(重なるぶんは上書きになる)。
      final y = math.max(0.0, math.min(top, height - viewport));
      await controller.runJavaScript('window.scrollTo(0,${y.round()})');
      await Future<void>.delayed(settle);
      final bytes = await shot(controller);
      if (bytes == null) break;
      final image = await _decode(bytes);
      if (image == null) break;
      shots.add((image: image, top: y));
    }
  } finally {
    try {
      await controller.runJavaScript('window.scrollTo(0,${startY.round()})');
    } catch (_) {}
  }
  ui.Image? stitched;
  if (shots.isNotEmpty) {
    try {
      stitched = await stitchPageShots(shots, width: width, height: height);
    } finally {
      for (final s in shots) {
        s.image.dispose();
      }
    }
  }
  return PageSnapshot(width: width, height: height, viewportHeight: viewport, image: stitched, texts: texts, url: url, title: '${m['title'] ?? ''}');
}
