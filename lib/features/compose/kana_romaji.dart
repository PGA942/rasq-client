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
    if (s[i] == 'っ' && i + 1 < s.length) { // l10n-ignore
      final next = _lookup(s, i + 1);
      if (next != null && next.$1.isNotEmpty && !'aiueon'.contains(next.$1[0])) {
        out.write(next.$1[0]);
        converted = true;
        i++;
        continue;
      }
    }
    if (s[i] == 'ー') { // l10n-ignore
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
  'あ': 'a', 'い': 'i', 'う': 'u', 'え': 'e', 'お': 'o', // l10n-ignore
  'か': 'ka', 'き': 'ki', 'く': 'ku', 'け': 'ke', 'こ': 'ko', // l10n-ignore
  'さ': 'sa', 'し': 'shi', 'す': 'su', 'せ': 'se', 'そ': 'so', // l10n-ignore
  'た': 'ta', 'ち': 'chi', 'つ': 'tsu', 'て': 'te', 'と': 'to', // l10n-ignore
  'な': 'na', 'に': 'ni', 'ぬ': 'nu', 'ね': 'ne', 'の': 'no', // l10n-ignore
  'は': 'ha', 'ひ': 'hi', 'ふ': 'fu', 'へ': 'he', 'ほ': 'ho', // l10n-ignore
  'ま': 'ma', 'み': 'mi', 'む': 'mu', 'め': 'me', 'も': 'mo', // l10n-ignore
  'や': 'ya', 'ゆ': 'yu', 'よ': 'yo', // l10n-ignore
  'ら': 'ra', 'り': 'ri', 'る': 'ru', 'れ': 're', 'ろ': 'ro', // l10n-ignore
  'わ': 'wa', 'ゐ': 'i', 'ゑ': 'e', 'を': 'o', 'ん': 'n', // l10n-ignore
  'が': 'ga', 'ぎ': 'gi', 'ぐ': 'gu', 'げ': 'ge', 'ご': 'go', // l10n-ignore
  'ざ': 'za', 'じ': 'ji', 'ず': 'zu', 'ぜ': 'ze', 'ぞ': 'zo', // l10n-ignore
  'だ': 'da', 'ぢ': 'ji', 'づ': 'zu', 'で': 'de', 'ど': 'do', // l10n-ignore
  'ば': 'ba', 'び': 'bi', 'ぶ': 'bu', 'べ': 'be', 'ぼ': 'bo', // l10n-ignore
  'ぱ': 'pa', 'ぴ': 'pi', 'ぷ': 'pu', 'ぺ': 'pe', 'ぽ': 'po', // l10n-ignore
  'ゔ': 'vu', // l10n-ignore
  'ぁ': 'a', 'ぃ': 'i', 'ぅ': 'u', 'ぇ': 'e', 'ぉ': 'o', 'ゃ': 'ya', 'ゅ': 'yu', 'ょ': 'yo', 'っ': '', // l10n-ignore
};

const _digraphs = {
  'きゃ': 'kya', 'きゅ': 'kyu', 'きょ': 'kyo', // l10n-ignore
  'しゃ': 'sha', 'しゅ': 'shu', 'しょ': 'sho', 'しぇ': 'she', // l10n-ignore
  'ちゃ': 'cha', 'ちゅ': 'chu', 'ちょ': 'cho', 'ちぇ': 'che', // l10n-ignore
  'にゃ': 'nya', 'にゅ': 'nyu', 'にょ': 'nyo', // l10n-ignore
  'ひゃ': 'hya', 'ひゅ': 'hyu', 'ひょ': 'hyo', // l10n-ignore
  'みゃ': 'mya', 'みゅ': 'myu', 'みょ': 'myo', // l10n-ignore
  'りゃ': 'rya', 'りゅ': 'ryu', 'りょ': 'ryo', // l10n-ignore
  'ぎゃ': 'gya', 'ぎゅ': 'gyu', 'ぎょ': 'gyo', // l10n-ignore
  'じゃ': 'ja', 'じゅ': 'ju', 'じょ': 'jo', 'じぇ': 'je', // l10n-ignore
  'びゃ': 'bya', 'びゅ': 'byu', 'びょ': 'byo', // l10n-ignore
  'ぴゃ': 'pya', 'ぴゅ': 'pyu', 'ぴょ': 'pyo', // l10n-ignore
  'ふぁ': 'fa', 'ふぃ': 'fi', 'ふぇ': 'fe', 'ふぉ': 'fo', // l10n-ignore
  'てぃ': 'ti', 'でぃ': 'di', 'とぅ': 'tu', 'どぅ': 'du', // l10n-ignore
  'うぃ': 'wi', 'うぇ': 'we', 'うぉ': 'wo', // l10n-ignore
  'ゔぁ': 'va', 'ゔぃ': 'vi', 'ゔぇ': 've', 'ゔぉ': 'vo', // l10n-ignore
};
