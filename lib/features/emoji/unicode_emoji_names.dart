import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// システム(Unicode)の絵文字を名前で探す (D-574)。
///
/// 名前のデータは `assets/emoji/unicode_emoji_names.tsv.gz`(@misskey-dev/emoji-data 17.0.3 の日本語 / ひらがな / 英語の索引から
/// `tool/build_unicode_emoji_names.py` で作る。ライセンスは同じフォルダの LICENSES.txt)。1915 個、gzip で 87KB。
/// 絵文字ピッカーを開いて検索欄に打ったときに初めて読む。
const unicodeEmojiNamesAsset = 'assets/emoji/unicode_emoji_names.tsv.gz';

/// 絵文字 1 つ。
@immutable
class UnicodeEmojiEntry {
  const UnicodeEmojiEntry({required this.char, required this.name, required this.category, this.ja = const [], this.hira = const [], this.en = const []});

  /// 絵文字そのもの(`🐱`)。
  final String char;

  /// ショートコード(`cat`)。
  final String name;

  /// 分類(emojilist の 0〜8: 顔 / 人 / 動物 / 食べ物 / 活動 / 旅行 / 物 / 記号 / 旗)。
  final int category;

  /// 日本語の語(先頭が CLDR の名前「ネコの顔」)。
  final List<String> ja;

  /// ひらがなの語(日本語の語をひらがなにしたものと違うものだけ)。
  final List<String> hira;

  /// 英語の語。
  final List<String> en;
}

/// 比べる形: 小文字、カタカナ → ひらがな、`_` / `-` → 空白。
String _norm(String s) {
  final lower = s.trim().toLowerCase().replaceAll(RegExp('[_-]'), ' ');
  return String.fromCharCodes(lower.runes.map((r) => r >= 0x30A1 && r <= 0x30F6 ? r - 0x60 : r));
}

/// 名前の索引。
class UnicodeEmojiNames {
  UnicodeEmojiNames(this.entries) : _keys = [for (final e in entries) _keysOf(e)];

  final List<UnicodeEmojiEntry> entries;

  /// 絵文字ごとの比べる語(先頭の 2 つ = ショートコードと CLDR の名前は「名前」として強く扱う)。
  final List<List<String>> _keys;

  static List<String> _keysOf(UnicodeEmojiEntry e) => {
        _norm(e.name),
        if (e.ja.isNotEmpty) _norm(e.ja.first),
        for (final w in e.ja) _norm(w),
        for (final w in e.hira) _norm(w),
        for (final w in e.en) _norm(w),
      }.toList();

  /// 作り直しの形(1 行 = 字 \t ショートコード \t 分類 \t 日本語 \t ひらがな \t 英語、語は `|` 区切り)を読む。
  factory UnicodeEmojiNames.parse(String tsv) {
    List<String> words(String s) => s.isEmpty ? const [] : s.split('|');
    return UnicodeEmojiNames([
      for (final line in const LineSplitter().convert(tsv))
        if (line.split('\t') case [final char, final name, final cat, final ja, final hira, final en])
          UnicodeEmojiEntry(char: char, name: name, category: int.tryParse(cat) ?? 0, ja: words(ja), hira: words(hira), en: words(en)),
    ]);
  }

  /// gzip のまま読む。
  factory UnicodeEmojiNames.fromGzip(List<int> bytes) => UnicodeEmojiNames.parse(utf8.decode(const GZipDecoder().decodeBytes(bytes)));

  /// [query] に合う絵文字(良く合う順、同じなら並びの順)。合い方: 名前(ショートコード / CLDR の名前)と同じ → 語と同じ →
  /// 語の頭から → 語の途中。英字 1 字だけの語は頭からだけ(`c` で cat は出るが、ac の途中は出ない)。
  /// 日本語は漢字・カタカナ・ひらがなのどれでも(「猫」「ネコ」「ねこ」)。
  List<String> search(String query, {int limit = 200}) {
    final q = _norm(query);
    if (q.isEmpty) return const [];
    final shortAscii = q.length == 1 && RegExp('[a-z0-9]').hasMatch(q);
    final scored = <(int, int)>[];
    for (var i = 0; i < entries.length; i++) {
      final keys = _keys[i];
      var best = 99;
      for (var k = 0; k < keys.length && best > 0; k++) {
        final w = keys[k];
        final named = k < 2;
        int? s;
        if (w == q) {
          s = named ? 0 : 1;
        } else if (w.startsWith(q) || w.contains(' $q')) {
          s = named ? 2 : 3;
        } else if (!shortAscii && w.contains(q)) {
          s = named ? 4 : 5;
        }
        if (s != null && s < best) best = s;
      }
      if (best < 99) scored.add((best, i));
    }
    scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return [for (final (_, i) in scored.take(limit)) entries[i].char];
  }
}

/// 名前の索引(初めて使うときに読む。読めなければエラー = 検索に Unicode の絵文字を出さないだけ)。
final unicodeEmojiNamesProvider = FutureProvider<UnicodeEmojiNames>((ref) async {
  final data = await rootBundle.load(unicodeEmojiNamesAsset);
  return UnicodeEmojiNames.fromGzip(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
});
