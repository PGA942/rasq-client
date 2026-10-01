#!/usr/bin/env python3
"""規約・ポリシーの草案(Markdown)→ アプリの文書 (D-372、規約案 06 CONS-01 の第一歩)。

  python3 tool/legal/build_legal.py [--src <規約案のフォルダ>]

- 草案(Obsidian「利用規約案/01〜05」)から**利用者向けの本文だけ**を切り出し、`assets/legal/<doc>.md` に置く(アプリの正本)。
  内部設計メモ・実装根拠・決裁表・コードの参照は入れない(切り出す節を下の DOCS で決める)。
- その Markdown から設定の文書ページ `assets/settings/about.<name>.rrl.json` を作る。見出し → SectionHeader、段落・箇条書き
  → RichText(太字・リンク・［要確定］の強調)、表 → 行ごとの段落、引用 → Notice。
- 文書 ID・版・本文の SHA-256 をページの `doc` と `lib/backend/legal_docs.g.dart` に書く。`test/legal_docs_test.dart` が
  「本文と表示が同じ版・同じハッシュか」「内部メモが混ざっていないか」を確かめる。
- `--src` を省くと `assets/legal/*.md` から作り直すだけ(草案を読まない)。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
LEGAL = os.path.join(ROOT, 'assets', 'legal')
SETTINGS = os.path.join(ROOT, 'assets', 'settings')
DART = os.path.join(ROOT, 'lib', 'backend', 'legal_docs.g.dart')

# 版はそろえる(草案の 01 / 05 の版)。公開の版は運営の決裁で決める。
VERSION = '1.0.0-draft.20260929'

# (文書 ID, 設定ページ, 題, 草案のファイル, 切り出す節の始まり, 終わり(その見出しの手前まで), 見出しの深さの繰り上げ)
DOCS = [
    ('rasq.terms', 'about.terms', '利用規約', '01 利用規約案.md', '## 利用者向け本文', '## 内部設計メモ'),
    ('rasq.privacy', 'about.privacy', 'プライバシーポリシー', '02 プライバシーポリシー案.md', '## A. 利用者向け本文案', '## B.'),
    ('rasq.learning', 'about.learning', 'アルゴリズムとコミュニティへの貢献について', '02 プライバシーポリシー案.md', '### 10. 学習へのデータ提供', '### 11.'),
    ('rasq.astell', 'about.astell', 'AsTell の利用条件', '03 AsTell・RAi利用条件案.md', '## 2. 利用者向け本文案: ASTell', '## 3.'),
    ('rasq.rai', 'about.rai', 'RAi の利用条件', '03 AsTell・RAi利用条件案.md', '## 3. 利用者向け本文案: RAi', '## 4.'),
    ('rasq.store', 'about.store', 'プラグインストアの利用条件', '04 プラグインストア・開発者条件案.md', '## A. 利用者向け「プラグインストア利用条件」本文案', '## C.'),
    ('rasq.developer', 'about.devterms', 'プラグイン開発者の掲載・審査条件', '04 プラグインストア・開発者条件案.md', '## C. 開発者向け「掲載・配信・販売条件」本文案', '## D.'),
    ('rasq.billing', 'about.billing', '料金・ポイントの条件', '05 料金・ポイント・特商法表示案.md', '## 2. 利用者向け料金・ポイント条件の本文案', '## 3.'),
    ('rasq.commerce', 'about.commerce', '特定商取引法に基づく表記', '05 料金・ポイント・特商法表示案.md', '## 3. 特定商取引法に基づく表記の公開用テンプレート', '## 4.'),
]

# 利用者向けの本文に混ざってはいけないもの(test でも見る)。
FORBIDDEN = ['/Users/', 'src/', '.rs:', '.dart:', '内部設計', '根拠コード', 'nosemgrep']


def extract(src_dir: str, file: str, start: str, end: str) -> str:
    text = open(os.path.join(src_dir, file), encoding='utf-8').read()
    i = text.index(start)
    j = text.find(end, i + len(start))
    body = text[i + len(start): j if j >= 0 else len(text)]
    # 節の見出しの行は捨て、残りの見出しを 1 段繰り上げる必要はない(### を見出しとして使う)。
    body = re.sub(r'<!--.*?-->', '', body, flags=re.S)
    # Obsidian のローカルリンク(</Users/...>)は文字だけにする。
    body = re.sub(r'\[([^\]]+)\]\(<[^>]*>\)', r'\1', body)
    body = re.sub(r'\[([^\]]+)\]\((?!https?://)[^)]*\)', r'\1', body)
    lines = [l.rstrip() for l in body.strip('\n').split('\n')]
    out = '\n'.join(lines).strip() + '\n'
    for f in FORBIDDEN:
        if f in out:
            raise SystemExit(f'{file}: 利用者向けの本文に内部の参照が混ざっています: {f!r}')
    return out


# ── Markdown → RSL スパン ──

PLACEHOLDER = re.compile(r'(【[^】]*】|［[^］]*］)')
INLINE = re.compile(r'(\*\*[^*]+\*\*|\[[^\]]+\]\(https?://[^)]+\)|`[^`]+`)')


def spans(text: str) -> list[dict]:
    out: list[dict] = []

    def plain(t: str, bold: bool = False):
        for part in PLACEHOLDER.split(t):
            if not part:
                continue
            if PLACEHOLDER.fullmatch(part):
                # 未確定の欄は目立たせる(公開前に埋める)。
                out.append({'s': 'text', 'text': part, 'bold': True, 'code': True})
            else:
                span = {'s': 'text', 'text': part}
                if bold:
                    span['bold'] = True
                out.append(span)

    for tok in INLINE.split(text):
        if not tok:
            continue
        if tok.startswith('**') and tok.endswith('**'):
            plain(tok[2:-2], bold=True)
        elif tok.startswith('[') and '](' in tok:
            m = re.match(r'\[([^\]]+)\]\((https?://[^)]+)\)', tok)
            out.append({'s': 'link', 'text': m.group(1), 'url': m.group(2)})
        elif tok.startswith('`') and tok.endswith('`'):
            out.append({'s': 'text', 'text': tok[1:-1], 'code': True})
        else:
            plain(tok)
    return out


def rich(text: str, pad: int = 16) -> dict:
    return {'t': 'RichText', 'p': {'source': spans(text), 'pad': pad}}


def cells(row: str) -> list[str]:
    return [c.strip() for c in row.strip().strip('|').split('|')]


def to_nodes(md: str) -> list[dict]:
    nodes: list[dict] = []
    lines = md.split('\n')
    i = 0
    para: list[str] = []

    def flush():
        if para:
            nodes.append(rich(' '.join(s.strip() for s in para)))
            para.clear()

    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if not s:
            flush()
            i += 1
            continue
        if s.startswith('```'):
            # 図(mermaid)やコードは文書ページに出さない。
            flush()
            i += 1
            while i < len(lines) and not lines[i].strip().startswith('```'):
                i += 1
            i += 1
            continue
        m = re.match(r'^(#{2,6})\s+(.*)$', s)
        if m:
            flush()
            title = re.sub(r'\*\*', '', m.group(2)).strip()
            if len(m.group(1)) <= 3:
                nodes.append({'t': 'SectionHeader', 'p': {'title': title}})
            else:
                nodes.append({'t': 'RichText', 'p': {'source': [{'s': 'text', 'text': title, 'bold': True}], 'pad': 16}})
            i += 1
            continue
        if s.startswith('|'):
            flush()
            rows = []
            while i < len(lines) and lines[i].strip().startswith('|'):
                rows.append(cells(lines[i]))
                i += 1
            header, body = rows[0], [r for r in rows[1:] if not all(re.fullmatch(r':?-{2,}:?', c) for c in r)]
            # 表は行ごとの段落に(狭い画面で読めるように)。先頭の列を太字、残りは「列名: 値」。
            for r in body:
                src = [{'s': 'text', 'text': '・', 'bold': True}] + [dict(x, bold=True) for x in spans(r[0])]
                for h, c in zip(header[1:], r[1:]):
                    if c:
                        src.append({'s': 'text', 'text': f'\n{h}: '})
                        src.extend(spans(c))
                nodes.append({'t': 'RichText', 'p': {'source': src, 'pad': 16}})
            continue
        if s.startswith('>'):
            flush()
            quote = []
            while i < len(lines) and lines[i].strip().startswith('>'):
                quote.append(lines[i].strip().lstrip('>').strip())
                i += 1
            nodes.append({'t': 'Notice', 'p': {'kind': 'info', 'text': re.sub(r'\*\*', '', ' '.join(quote))}})
            continue
        lm = re.match(r'^(\d+)\.\s+(.*)$', s) or re.match(r'^[-*]\s+(.*)$', s)
        if lm:
            flush()
            if s[0].isdigit():
                n, t = lm.group(1), lm.group(2)
                prefix = f'{n}. '
            else:
                t = lm.group(1)
                prefix = '・'
            # 続きの行(字下げ)をつなぐ。
            i += 1
            while i < len(lines) and lines[i].startswith('   ') and lines[i].strip():
                t += ' ' + lines[i].strip()
                i += 1
            nodes.append(rich(prefix + t))
            continue
        para.append(s)
        i += 1
    flush()
    return nodes


def page(doc_id: str, area: str, title: str, md: str, sha: str) -> dict:
    content = to_nodes(md)
    return {
        'schema': 'rasq.settings-page/1',
        'area': area,
        'title': title,
        # 文書 ID・版・本文の SHA-256 (CONS-01)。test が assets/legal/*.md と照らす。
        'doc': {'id': doc_id, 'version': VERSION, 'bodySha256': sha},
        'defaults': {},
        'root': {
            't': 'Column',
            'c': [
                {'t': 'Notice', 'p': {'kind': 'warning', 'text': '公開前の草案です。【要確定】や［　］の箇所は、正式版の公開までに決まります。',
                                      'detail': f'{doc_id} / 版 {VERSION}。草案の利用者向け本文だけを切り出したもの(tool/legal/build_legal.py)。'}},
                *content,
                {'t': 'Text', 'p': {'text': f'文書 ID: {doc_id} ・ 版: {VERSION}', 'pad': 16, 'size': 11}},
                {'t': 'Text', 'p': {'text': f'本文の SHA-256: {sha}', 'pad': 16, 'size': 11, 'dev': True}},
            ],
        },
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--src', help='規約案のフォルダ(Obsidian の「利用規約案」)。省くと assets/legal/*.md から作り直す')
    args = ap.parse_args()
    os.makedirs(LEGAL, exist_ok=True)
    entries = []
    for doc_id, area, title, file, start, end in DOCS:
        md_path = os.path.join(LEGAL, f'{doc_id}.md')
        if args.src:
            md = extract(args.src, file, start, end)
            open(md_path, 'w', encoding='utf-8').write(md)
        md = open(md_path, encoding='utf-8').read()
        sha = hashlib.sha256(md.encode('utf-8')).hexdigest()
        json.dump(page(doc_id, area, title, md, sha), open(os.path.join(SETTINGS, f'{area}.rrl.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
        open(os.path.join(SETTINGS, f'{area}.rrl.json'), 'a', encoding='utf-8').write('\n')
        entries.append((doc_id, area, title, sha))
    with open(DART, 'w', encoding='utf-8') as f:
        f.write('// 生成: tool/legal/build_legal.py(手で直さない)。規約・ポリシーの文書 ID・版・本文の SHA-256 (D-372 / CONS-01)。\n\n')
        f.write('/// 草案の版(全文書で同じ)。利用規約 / プライバシーポリシーの承諾の版にもなる。\n')
        f.write(f"const rasqLegalVersion = '{VERSION}';\n\n")
        f.write('/// 文書 ID → (設定ページ, 題, 版, 本文の SHA-256)。\n')
        f.write('const rasqLegalDocs = <String, ({String area, String title, String version, String sha256})>{\n')
        for doc_id, area, title, sha in entries:
            f.write(f"  '{doc_id}': (area: '{area}', title: '{title}', version: rasqLegalVersion, sha256: '{sha}'),\n")
        f.write('};\n')
    print('\n'.join(f'{d} → {a} ({s[:12]})' for d, a, _, s in entries))


if __name__ == '__main__':
    main()
