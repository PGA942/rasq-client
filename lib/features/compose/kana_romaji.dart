/// かな → ローマ字(ヘボン式寄り)。メンションの候補を引くとき、表示名を日本語で打ってもハンドル(英数字)に届くようにする (D-289)。
///
/// 「AnyAscii で ASCII に寄せてから引く」方針の、かなの部分。漢字は読みが決まらないので、そのまま(変換しない)。
/// 変換できるかなが 1 つも無ければ null。
String? kanaToRomaji(String input) {
  final s = _toHiragana(input);
  final out = StringBuffer();
  var converted = false;
  var i = 0;
  while (i < s.length) {
    // 促音: 次の子音を重ねる。
    if (s[i] == 'っ' && i + 1 < s.length) {
      final next = _lookup(s, i + 1);
      if (next != null && next.$1.isNotEmpty && !'aiueon'.contains(next.$1[0])) {
        out.write(next.$1[0]);
        converted = true;
        i++;
        continue;
      }
    }
    if (s[i] == 'ー') {
      // 長音は、直前の母音を伸ばさずに落とす(ハンドルでは書かないことが多い)。
      converted = true;
      i++;
      continue;
    }
    final hit = _lookup(s, i);
    if (hit != null) {
      out.write(hit.$1);
      converted = true;
      i += hit.$2;
    } else {
      out.write(s[i]);
      i++;
    }
  }
  return converted ? out.toString().toLowerCase() : null;
}

/// 位置 [i] から、拗音(2 文字)→ 1 文字の順に引く。戻り = (ローマ字, 使った文字数)。
(String, int)? _lookup(String s, int i) {
  if (i + 1 < s.length) {
    final two = _digraphs[s.substring(i, i + 2)];
    if (two != null) return (two, 2);
  }
  final one = _kana[s[i]];
  return one == null ? null : (one, 1);
}

String _toHiragana(String s) => String.fromCharCodes([
      for (final c in s.runes) (c >= 0x30A1 && c <= 0x30F6) ? c - 0x60 : c,
    ]);

const _kana = {
  'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o',
  'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko',
  'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so',
  'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to',
  'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no',
  'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho',
  'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo',
  'や': 'ya', 'ゆ': 'yu', 'よ': 'yo',
  'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro',
  'わ': 'wa', 'ゐ': 'i', 'ゑ': 'e', 'を': 'o', 'ん': 'n',
  'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go',
  'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo',
  'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do',
  'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo',
  'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po',
  'ゔ': 'vu',
  'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o', 'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'っ': '',
};

const _digraphs = {
  'きゃ': 'kya', 'きゅ': 'kyu', 'きょ': 'kyo',
  'しゃ': 'sha', 'しゅ': 'shu', 'しょ': 'sho', 'しぇ': 'she',
  'ちゃ': 'cha', 'ちゅ': 'chu', 'ちょ': 'cho', 'ちぇ': 'che',
  'にゃ': 'nya', 'にゅ': 'nyu', 'にょ': 'nyo',
  'ひゃ': 'hya', 'ひゅ': 'hyu', 'ひょ': 'hyo',
  'みゃ': 'mya', 'みゅ': 'myu', 'みょ': 'myo',
  'りゃ': 'rya', 'りゅ': 'ryu', 'りょ': 'ryo',
  'ぎゃ': 'gya', 'ぎゅ': 'gyu', 'ぎょ': 'gyo',
  'じゃ': 'ja', 'じゅ': 'ju', 'じょ': 'jo', 'じぇ': 'je',
  'びゃ': 'bya', 'びゅ': 'byu', 'びょ': 'byo',
  'ぴゃ': 'pya', 'ぴゅ': 'pyu', 'ぴょ': 'pyo',
  'ふぁ': 'fa', 'ふぃ': 'fi', 'ふぇ': 'fe', 'ふぉ': 'fo',
  'てぃ': 'ti', 'でぃ': 'di', 'とぅ': 'tu', 'どぅ': 'du',
  'うぃ': 'wi', 'うぇ': 'we', 'うぉ': 'wo',
  'ゔぁ': 'va', 'ゔぃ': 'vi', 'ゔぇ': 've', 'ゔぉ': 'vo',
};
