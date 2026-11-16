#!/usr/bin/env python3
"""システム絵文字の名前の索引 (D-574) を作る。

元: npm の @misskey-dev/emoji-data 17.0.3(MFM の絵文字の正規表現 lib/text/mfm/emoji_regex.dart と同じ版)。
    built/emojilist.json(字・ショートコード・分類)と built/indexes/{ja-JP,ja-JP_hira,en-US}.json(名前と語)。
    ライセンス: コード MIT(Misskey Project)、Unicode 11 以前の語 MIT(emojilib, Mu-An Chiou)、
    Unicode 12 以降の注釈 Unicode License v3(CLDR)。assets/emoji/LICENSES.txt に写す。

使い方:
    npm pack @misskey-dev/emoji-data@17.0.3 && tar xzf misskey-dev-emoji-data-17.0.3.tgz
    python3 -I tool/build_unicode_emoji_names.py package

出力: assets/emoji/unicode_emoji_names.tsv.gz。1 行 = 1 絵文字(並びは emojilist の順 = ピッカーの並び):
    字 \t ショートコード \t 分類(0〜8) \t 日本語の語(| 区切り、先頭が CLDR の名前) \t ひらがなの語 \t 英語の語
ひらがなの語は、日本語の語をひらがなにしたものと同じなら省く(大きさを抑える)。
"""
import gzip
import json
import os
import sys


def hira(s):
    return ''.join(chr(ord(c) - 0x60) if 0x30A1 <= ord(c) <= 0x30F6 else c for c in s)


def main(pkg):
    built = os.path.join(pkg, 'built')
    emojis = json.load(open(os.path.join(built, 'emojilist.json'), encoding='utf-8'))
    idx = {lang: json.load(open(os.path.join(built, 'indexes', f'{lang}.json'), encoding='utf-8')) for lang in ['ja-JP', 'ja-JP_hira', 'en-US']}
    lines = []
    for char, name, cat in emojis:
        ja = [w for w in dict.fromkeys(idx['ja-JP'].get(char, [])) if w]
        ja_h = {hira(w) for w in ja}
        hi = [w for w in dict.fromkeys(idx['ja-JP_hira'].get(char, [])) if w and w not in ja_h]
        en = [w for w in dict.fromkeys(idx['en-US'].get(char, [])) if w and w != name]
        # 区切りの字を含む語(`:|` などの顔文字)は落とす。
        ok = lambda w: not any(c in w for c in '\t|\n')
        ja, hi, en = [w for w in ja if ok(w)], [w for w in hi if ok(w)], [w for w in en if ok(w)]
        assert ok(char) and ok(name), char
        lines.append('\t'.join([char, name, str(cat), '|'.join(ja), '|'.join(hi), '|'.join(en)]))
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'emoji')
    os.makedirs(root, exist_ok=True)
    data = ('\n'.join(lines) + '\n').encode('utf-8')
    with open(os.path.join(root, 'unicode_emoji_names.tsv.gz'), 'wb') as f:
        f.write(gzip.compress(data, compresslevel=9, mtime=0))
    with open(os.path.join(root, 'LICENSES.txt'), 'w', encoding='utf-8') as out:
        out.write('unicode_emoji_names.tsv.gz は npm の @misskey-dev/emoji-data 17.0.3 から作った(tool/build_unicode_emoji_names.py)。\n')
        out.write('This file is derived from @misskey-dev/emoji-data 17.0.3 and carries the licenses below.\n\n')
        for name in ['LICENSE', 'LICENSE-CODE', 'LICENSE-EMOJILIB', 'LICENSE-CLDR']:
            out.write(f'===== {name} =====\n')
            out.write(open(os.path.join(pkg, name), encoding='utf-8').read().strip() + '\n\n')
    print(f'{len(lines)} emojis, {len(data)} bytes raw')


if __name__ == '__main__':
    main(sys.argv[1])
