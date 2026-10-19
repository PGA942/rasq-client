/// 送る前の判定 (D-462) の、端末の測り方: 語彙ルール(`lexicon`)と形のルール(`pattern`)。
///
/// **すべて端末の中で決まる純関数**。本文はどこにも送らない(Central S-102 には、止めた種類だけが届く)。
/// - `lexicon`: 種類ごとの語の当たり数 n を `1 - 0.5^n`(1 回 0.5、2 回 0.75、3 回 0.875 …)にする。トレンドの感情の語彙
///   ([emotionLexiconOf]) と同じ飽和の形。英字だけの語は、前後が英字でないときだけ当てる(`sussex` に `sex` を当てない)。
/// - `pattern`: 電話番号 / メールアドレス / 郵便番号 / 住所 / LINE の ID、URL。当たれば 1。
/// - 画像(`image`)の判定は、ここには無い(端末に画像の判定のモデルが無い。判定できないときの倒し方は [evaluateCompose] が決める)。
library;

import 'dart:math' as math;

/// 当たった範囲(本文の中の添字)。
typedef ComposeHit = ({int start, int end});

/// 種類ごとの語。誤判定の多い短い語(「ばか」→「ばかり」、「カス」→「カスタム」、「ゴミ」→「ゴミ出し」など)は入れない。
const composeLexicon = <String, List<String>>{
  'sexual': [
    'セックス', 'せっくす', 'エッチしよ', 'えっちしよ', 'エッチな写真', 'えっちな写真', '裸の写真', '裸の画像', 'ヌード', 'おっぱい', 'ちんこ', 'ちんぽ', // l10n-ignore
    'まんこ', 'オナニー', 'おなにー', 'パパ活', 'ママ活', '援交', '援助交際', 'エロ画像', 'エロ動画', 'ムラムラ', 'sex', 'nude', 'nudes', 'porn', // l10n-ignore
    'horny', 'send pics', 'boobs', 'dick pic',
  ],
  'violence': [
    '殺す', 'ころす', '殺してやる', 'ぶっ殺', 'ぶっころ', '殴る', 'なぐる', 'ぶん殴', '刺してやる', '燃やしてやる', '爆破', '襲ってやる', '痛めつけ', // l10n-ignore
    'ボコボコにし', 'kill you', 'i will kill', 'beat you up', 'stab you', 'shoot you', 'bomb threat', // l10n-ignore
  ],
  'self-harm': [
    '死にたい', 'しにたい', '消えたい', 'きえたい', '自殺', 'リスカ', 'リストカット', '首吊', '首つり', '飛び降り', 'オーバードーズ', '自傷', // l10n-ignore
    'kill myself', 'suicide', 'self harm', 'self-harm', 'want to die', 'cut myself',
  ],
  'harassment': [
    '死ね', '氏ね', 'タヒね', 'きもい', 'キモい', 'うざい', 'ウザい', 'ブス', 'クズ', '馬鹿', 'バカじゃ', 'バカやろ', 'ばかやろ', 'バーカ', 'アホ', // l10n-ignore
    '消えろ', '黙れ', 'ガイジ', 'idiot', 'stupid', 'loser', 'shut up', 'kys', 'fuck you', 'retard', // l10n-ignore
  ],
};

bool _ascii(String s) => s.codeUnits.every((c) => c < 0x80);
bool _letter(int c) => (c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a);

/// [text] の中の [words] の当たり(先頭から順)。
List<ComposeHit> lexiconHits(String text, List<String> words) {
  final lower = text.toLowerCase();
  // 小文字にして長さが変わる字があると添字がずれるので、そのときは範囲を返さない(当たりの数だけ数える)。
  final aligned = lower.length == text.length;
  final out = <ComposeHit>[];
  for (final w in words) {
    final key = w.toLowerCase();
    final word = _ascii(key);
    var i = lower.indexOf(key);
    while (i >= 0) {
      final end = i + key.length;
      final ok = !word || ((i == 0 || !_letter(lower.codeUnitAt(i - 1))) && (end >= lower.length || !_letter(lower.codeUnitAt(end))));
      if (ok) out.add(aligned ? (start: i, end: end) : (start: -1, end: -1));
      i = lower.indexOf(key, end);
    }
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// 当たり数 → 点数(1 回 0.5、2 回 0.75 …、6 回で打ち止め)。
double lexiconScore(int hits) => hits <= 0 ? 0 : 1 - math.pow(0.5, math.min(hits, 6)).toDouble();

// ── 形のルール ──

final _phone = RegExp(r'(?<![\d０-９])(?:\+81[-\s]?|0)\d{1,4}[-‐－ー−\s]?\d{1,4}[-‐－ー−\s]?\d{3,4}(?![\d０-９])'); // l10n-ignore
final _email = RegExp(r'(?<![@\w.+-])[\w.+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+');
final _postal = RegExp(r'(?:〒|郵便番号\s*[:：]?)\s*\d{3}[-－ー]?\d{4}'); // l10n-ignore
final _address = RegExp(r'[一-龥]{1,4}[市区町村][一-龥ぁ-んァ-ヶ]{0,12}\d{1,4}\s*(?:丁目|番地|[-－ー]\s*\d{1,4})'); // l10n-ignore
final _lineId = RegExp(r'(?:LINE|ＬＩＮＥ|ライン)\s*(?:ID|ＩＤ|id)\s*[:：は]?\s*[A-Za-z0-9._-]{3,}', caseSensitive: false); // l10n-ignore
final _url = RegExp(r'(?:https?://|www\.)[^\s]+', caseSensitive: false);

/// 電話番号らしい数字の並び(数字が 10〜11 桁、`+81` は 9〜10 桁)。
bool _phoneLike(String m) {
  final digits = m.replaceAll(RegExp(r'[^0-9]'), '');
  if (m.startsWith('+81')) return digits.length >= 11 && digits.length <= 12;
  return digits.length >= 10 && digits.length <= 11;
}

/// 種類 [type] の形のルールの当たり(先頭から順)。種類に形のルールが無ければ空。
List<ComposeHit> patternHits(String type, String text) {
  final out = <ComposeHit>[];
  void add(RegExp re, [bool Function(String m)? keep]) {
    for (final m in re.allMatches(text)) {
      if (keep == null || keep(m[0]!)) out.add((start: m.start, end: m.end));
    }
  }

  switch (type) {
    case 'personal-info':
      add(_phone, _phoneLike);
      add(_email);
      add(_postal);
      add(_address);
      add(_lineId);
    case 'link':
      add(_url);
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

/// 文の測り方([signal])で、種類 [type] の点数と最初に当たった範囲。測れない(知らない測り方)なら null。
({double score, ComposeHit? hit})? measureText(String signal, String type, String text) {
  switch (signal) {
    case 'lexicon':
      final words = composeLexicon[type];
      if (words == null) return null;
      final hits = lexiconHits(text, words);
      return (score: lexiconScore(hits.length), hit: hits.where((h) => h.start >= 0).firstOrNull);
    case 'pattern':
      if (type != 'personal-info' && type != 'link') return null;
      final hits = patternHits(type, text);
      return (score: hits.isEmpty ? 0 : 1, hit: hits.firstOrNull);
  }
  return null;
}
