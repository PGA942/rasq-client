import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plugin_runtime/plugin_runtime.dart' show rasqZstdCompress, rasqZstdDecompress;
import 'package:rrl_renderer/rrl_renderer.dart' show SvgLite;

/// 落書きの圧縮 (D-472、SDK 契約 v0.23 の `svgz`)。
///
/// `media.editor.open` の編集画面で保存した SVG を zstd で縮め(ランタイム内蔵の ruzstd の `Fastest`。Web 版は
/// `assets/web/zstd.wasm`)、標準の base64 にして `page.event {type: "edited", svg, svgz, svgzEncoding: "zstd"}` で渡す。
/// プラグインはそれをサーバー変数に置き(Central は値の中身を見ないので変更なし)、描くときは
/// `Image.p.src` = `data:image/svg+xml;zstd;base64,<svgz>` にする。ホストは展開して(64 KiB まで)許可リストで消毒してから描く
/// ([SvgLite.zstdDecompress])。古いプラグインは `svg` だけを使い続けられる。

/// このホストが話す契約の版(`page.open` の `contract`)。v0.24 (D-484): 毎回の call の `args.locale`(表示の言語)。
const rasqHostContract = '0.24';

/// `svgzEncoding` の値。
const svgzEncoding = 'zstd';

/// zstd で縮めた SVG の data URI の頭。
const svgzDataUriPrefix = 'data:image/svg+xml;zstd;base64,';

/// zstd の圧縮(テストで差し替える)。
typedef SvgzCompress = Uint8List Function(Uint8List input);

final svgzCompressProvider = Provider<SvgzCompress>((ref) => rasqZstdCompress);

/// [svg] を zstd で縮めて標準の base64 にする。縮められなければ null(`svg` だけを渡す)。
String? encodeSvgz(String svg, SvgzCompress compress) {
  try {
    return base64.encode(compress(Uint8List.fromList(utf8.encode(svg))));
  } catch (_) {
    return null;
  }
}

/// RRL の `Image` と編集画面が `data:image/svg+xml;zstd;base64,…` を読めるようにする(起動時に 1 回。テストも呼ぶ)。
void installSvgzDecoder() {
  SvgLite.zstdDecompress ??= (input, maxOutput) => rasqZstdDecompress(input, maxOutput: maxOutput);
}
