import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../settings/settings_dsl.dart';
import '../theme_packs.dart' show themeSettingsArea;
import 'icon_theme_codec.dart';
import 'icon_theme_library.dart' show iconThemeFramesFor;
import 'rasq_theme_spec.dart';

/// アイコンに埋め込まれたテーマを読む (D-564)。
///
/// - タイムラインのアイコン(予約 3 ビット = フレームと添付の並び)と、プロフィールのアイコンの拡大(背景・文字色・強調色・
///   パーティクル・枠)で使う。**読めない画像では何もしない**(null)。
/// - 表示の邪魔をしない: 画像の取得と復号は表示と別に、同時に 2 つまで([_maxConcurrent])。復号(JPEG / PNG を画素にして
///   四隅を読む)は別の isolate([compute]、Web は同じスレッド)。結果は URL ごとに覚える(読めなかったことも、[_cacheSize] 件)。
/// - 画像は表示に使う URL を取り直す(Flutter の画像の置き場は元のバイト列を持たないため)。2 MiB を超えるもの・正方形で
///   ないもの・32px 未満は読まない。
/// - 設定 → アプリの外観 →「フォントやカラースキーム」の「アイコンのテーマを読む」で止められる(既定オン)。

/// 設定の項目(`appearance.theme` の `iconThemes`、既定 true)。
const iconThemesSettingKey = 'iconThemes';

final iconThemesEnabledProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(themeSettingsArea)).value?[iconThemesSettingKey] != false);

/// 画像のバイト列を取る口(テストで差し替える)。null = 取れない。
final iconThemeFetcherProvider = Provider<Future<Uint8List?> Function(Uri)>((ref) => _fetch);

const _maxBytes = 2 * 1024 * 1024;

/// `flutter test` の中か(既定の口は通信しない。ウィジェットのテストに、取り待ちのタイマーを残さないため。読むテストは
/// [iconThemeFetcherProvider] を差し替える)。
final bool _underFlutterTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

Future<Uint8List?> _fetch(Uri url) async {
  if (_underFlutterTest) return null;
  if (url.scheme != 'https' && url.scheme != 'http') return null;
  final res = await http.get(url).timeout(const Duration(seconds: 15));
  if (res.statusCode != 200 || res.bodyBytes.length > _maxBytes) return null;
  return res.bodyBytes;
}

/// 画像のバイト列 → テーマ(別の isolate で動く。読めなければ null)。
IconThemeDecoded? decodeIconThemeBytes(Uint8List bytes) {
  if (bytes.length > _maxBytes) return null;
  img.Image? im;
  try {
    im = img.decodeImage(bytes);
  } catch (_) {
    return null; // 壊れた / 知らない形式
  }
  if (im == null || im.width < 32 || im.height < 32) return null;
  // 正方形のアイコンだけ(SNS は正方形に切って配る。横長の画像の四隅は別物)。
  if ((im.width - im.height).abs() > im.width * 0.02) return null;
  final rgba = im.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba);
  final d = iconThemeDecode(rgba, im.width, im.height);
  return d.ok ? d : null;
}

const _cacheSize = 256;
const _maxConcurrent = 2;

/// URL ごとの結果と、取り / 復号の順番待ち。
class IconThemeCache {
  IconThemeCache(this._fetcher);
  final Future<Uint8List?> Function(Uri) _fetcher;
  final _done = <String, RasqThemeSpec?>{}; // 挿入順 = 古い順
  final _pending = <String, Future<RasqThemeSpec?>>{};
  final _queue = Queue<Completer<void>>();
  var _running = 0;

  /// 覚えている結果(まだ読んでいなければ、読み終わるまで待たない)。
  ({bool known, RasqThemeSpec? spec}) peek(String url) => _done.containsKey(url) ? (known: true, spec: _done[url]) : (known: false, spec: null);

  Future<RasqThemeSpec?> read(String url) {
    if (_done.containsKey(url)) {
      final v = _done.remove(url);
      _done[url] = v; // 使った順に
      return SynchronousFuture(v);
    }
    return _pending[url] ??= _run(url);
  }

  Future<RasqThemeSpec?> _run(String url) async {
    if (_running >= _maxConcurrent) {
      final c = Completer<void>();
      _queue.add(c);
      await c.future;
    }
    _running++;
    RasqThemeSpec? spec;
    try {
      final uri = Uri.tryParse(url);
      final bytes = uri == null ? null : await _fetcher(uri);
      if (bytes != null) {
        final d = kIsWeb ? decodeIconThemeBytes(bytes) : await compute(decodeIconThemeBytes, bytes);
        if (d != null) spec = RasqThemeSpec.fromIcon(d, frames: iconThemeFramesFor(d.theme!));
      }
    } catch (e) {
      debugPrint('icon theme: $url unreadable: $e');
    } finally {
      _running--;
      if (_queue.isNotEmpty) _queue.removeFirst().complete();
    }
    _pending.remove(url);
    _done[url] = spec;
    while (_done.length > _cacheSize) {
      _done.remove(_done.keys.first);
    }
    return spec;
  }
}

final iconThemeCacheProvider = Provider<IconThemeCache>((ref) => IconThemeCache(ref.watch(iconThemeFetcherProvider)));

/// アイコン [url] に埋め込まれたテーマ(無い / 読めない / 設定で止めている → null)。
final iconThemeProvider = FutureProvider.family<RasqThemeSpec?, String>((ref, url) {
  if (!ref.watch(iconThemesEnabledProvider)) return null;
  return ref.watch(iconThemeCacheProvider).read(url);
});
