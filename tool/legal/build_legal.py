#!/usr/bin/env python3
"""規約・ポリシーの草案(Markdown)→ アプリの文書 (D-372、規約案 06 CONS-01 の第一歩)。

  python3 tool/legal/build_legal.py [--src <規約案のフォルダ>]

- 草案(Obsidian「RASQ/規約設計/<日付>/01〜05」、最新は 2026-10-07)から**利用者向けの本文だけ**を切り出し、`assets/legal/<doc>.md` に置く(アプリの正本)。
  内部設計メモ・実装根拠・決裁表・コードの参照は入れない(切り出す節を下の DOCS で決める)。
- その Markdown から設定の文書ページ `assets/settings/about.<name>.rrl.json` を作る。見出し → SectionHeader、段落・箇条書き
  → RichText(太字・リンク・［要確定］の強調)、表 → 行ごとの段落、引用 → Notice。
- 文書 ID・版・本文の SHA-256 をページの `doc` と `lib/backend/legal_docs.g.dart` に書く。`test/legal_docs_test.dart` が
  「本文と表示が同じ版・同じハッシュか」「内部メモが混ざっていないか」を確かめる。
- `--src` を省くと `assets/legal/*.md` から作り直すだけ(草案を読まない)。
- 参考訳 (D-535): `assets/legal/<言語>/<doc>.md`(`en` / `zh` / `zh-Hant` / `ko`)があれば、設定の文書ページ
  `assets/settings/<言語>/about.<name>.rrl.json` も作る。**正本は日本語**: 訳の先頭には「参考訳であり日本語版が優先する」旨の
  引用(> …)を必ず置く(無ければ止める)。ページの `doc`(文書 ID・版・`bodySha256`)は日本語の正本のまま(承諾は日本語の文書に
  対して記録する)。訳の本文の SHA-256 は `translation.bodySha256` に別に書く。
- 公式の SNS プラグインの規約の参考訳 `assets/legal/<言語>/plugins/<pluginId>.md` は、rasq_plugin_api の定数
  `<名前>TermsLocales`(マニフェストの `locales.<言語>.termsOfService`)にする。
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
VERSION = '1.0.0-draft.20261007'

# 公式の SNS プラグインの規約: assets/legal/plugins/<pluginId>.md → rasq_plugin_api の定数(マニフェストの termsOfService)。
PLUGIN_LEGAL = os.path.join(LEGAL, 'plugins')
PLUGIN_DART = os.path.join(ROOT, 'packages', 'rasq_plugin_api', 'lib', 'src', 'official_plugin_terms.g.dart')

# (文書 ID, 設定ページ, 題, 草案のファイル, 切り出す節の始まり, 終わり(その見出しの手前まで), 見出しの深さの繰り上げ)
DOCS = [
    ('rasq.terms', 'about.terms', '利用規約', '01 利用規約案.md', '## 利用者向け本文', '## 内部設計メモ'),
    ('rasq.privacy', 'about.privacy', 'プライバシーポリシー', '02 プライバシーポリシー案.md', '## A. 利用者向け本文案', '## B.'),
    # 学習の説明は独立した全文(2026-10-07〜。プライバシーポリシー第10項は案内だけ)。02 の末尾の節 D。
    ('rasq.learning', 'about.learning', 'アルゴリズムとコミュニティへの貢献について', '02 プライバシーポリシー案.md', '## D. 利用者向け本文案: アルゴリズムとコミュニティへの貢献について', '## E.'),
    ('rasq.astell', 'about.astell', 'ASTell の利用条件', '03 AsTell・RAi利用条件案.md', '## 2. 利用者向け本文案: ASTell', '## 3.'),
    ('rasq.rai', 'about.rai', 'RAi の利用条件', '03 AsTell・RAi利用条件案.md', '## 3. 利用者向け本文案: RAi', '## 4.'),
    ('rasq.store', 'about.store', 'プラグインストアの利用条件', '04 プラグインストア・開発者条件案.md', '## A. 利用者向け「プラグインストア利用条件」本文案', '## C.'),
    ('rasq.developer', 'about.devterms', 'プラグイン開発者の掲載・審査条件', '04 プラグインストア・開発者条件案.md', '## C. 開発者向け「掲載・配信・販売条件」本文案', '## D.'),
    ('rasq.billing', 'about.billing', '料金・ポイントの条件', '05 料金・ポイント・特商法表示案.md', '## 2. 利用者向け料金・ポイント条件の本文案', '## 3.'),
    ('rasq.commerce', 'about.commerce', '特定商取引法に基づく表記', '05 料金・ポイント・特商法表示案.md', '## 3. 特定商取引法に基づく表記の公開用テンプレート', '## 4.'),
]

# 利用者向けの本文に混ざってはいけないもの(test でも見る)。
FORBIDDEN = ['/Users/', 'src/', '.rs:', '.dart:', '内部設計', '根拠コード', 'nosemgrep']

# 参考訳の言語(assets/legal/<言語>/ と assets/settings/<言語>/ のフォルダ名。アプリの表示の言語のタグ)。
TRANSLATIONS = ['en', 'zh', 'zh-Hant', 'ko']

# 参考訳の先頭に置く注記(Markdown の引用。文書ページでは Notice になる)。訳の Markdown はこの行で始まること。
TRANSLATION_NOTICE = {
    'en': '> **Reference translation.** This is a reference translation provided for convenience. The Japanese version is the official text, and if there is any difference between them, the Japanese version governs.',
    'zh': '> **参考译文。** 本文是为方便阅读而提供的参考译文。正式文本为日文版，如两者内容有任何出入，以日文版为准。',
    'zh-Hant': '> **參考譯文。** 本文是為方便閱讀而提供的參考譯文。正式文本為日文版，如兩者內容有任何出入，以日文版為準。',
    'ko': '> **참고 번역.** 이 문서는 편의를 위해 제공하는 참고 번역입니다. 정식 문서는 일본어판이며, 내용에 차이가 있는 경우 일본어판이 우선합니다.',
}

# 参考訳のページの題(文書 ID → 言語 → 題)。
TRANSLATED_TITLES = {
    'rasq.terms': {'en': 'Terms of Service', 'zh': '使用条款', 'zh-Hant': '使用條款', 'ko': '이용약관'},
    'rasq.privacy': {'en': 'Privacy Policy', 'zh': '隐私政策', 'zh-Hant': '隱私權政策', 'ko': '개인정보 처리방침'},
    'rasq.learning': {'en': 'About Contributing to Algorithms and the Community', 'zh': '关于对算法与社区的贡献', 'zh-Hant': '關於對演算法與社群的貢獻', 'ko': '알고리즘과 커뮤니티에 대한 기여에 관하여'},
    'rasq.astell': {'en': 'ASTell Terms of Use', 'zh': 'ASTell 使用条件', 'zh-Hant': 'ASTell 使用條件', 'ko': 'ASTell 이용 조건'},
    'rasq.rai': {'en': 'RAi Terms of Use', 'zh': 'RAi 使用条件', 'zh-Hant': 'RAi 使用條件', 'ko': 'RAi 이용 조건'},
    'rasq.store': {'en': 'Plugin Store Terms of Use', 'zh': '插件商店使用条件', 'zh-Hant': '外掛商店使用條件', 'ko': '플러그인 스토어 이용 조건'},
    'rasq.developer': {'en': 'Plugin Developer Listing and Review Terms', 'zh': '插件开发者上架与审核条件', 'zh-Hant': '外掛開發者上架與審查條件', 'ko': '플러그인 개발자 게재·심사 조건'},
    'rasq.billing': {'en': 'Pricing and Points Terms', 'zh': '费用与积分条件', 'zh-Hant': '費用與點數條件', 'ko': '요금·포인트 조건'},
    'rasq.commerce': {'en': 'Notation Based on the Act on Specified Commercial Transactions', 'zh': '基于《特定商业交易法》的标示', 'zh-Hant': '依《特定商業交易法》之標示', 'ko': '특정상거래법에 따른 표기'},
}

# 参考訳のページの決まった文。{doc_id} / {version} / {sha} / {ja_sha} を差し込む。
PAGE_TEXT = {
    'ja': {
        'draft': '公開前の草案です。【要確定】や［　］の箇所は、正式版の公開までに決まります。',
        'draftDetail': '{doc_id} / 版 {version}。草案の利用者向け本文だけを切り出したもの(tool/legal/build_legal.py)。',
        'footer': '文書 ID: {doc_id} ・ 版: {version}',
        'sha': '本文の SHA-256: {sha}',
    },
    'en': {
        'draft': 'This is a pre-release draft. Items marked 【TBD】 or ［　］ will be decided before the official version is published.',
        'draftDetail': '{doc_id} / version {version}. Reference translation of the user-facing text of the Japanese draft (tool/legal/build_legal.py).',
        'footer': 'Document ID: {doc_id} · Version: {version} (the Japanese version governs)',
        'sha': 'SHA-256 of the Japanese original: {ja_sha} · SHA-256 of this translation: {sha}',
    },
    'zh': {
        'draft': '这是公开前的草案。标有【待定】或［　］的部分将在正式版公开前确定。',
        'draftDetail': '{doc_id} / 版本 {version}。日文草案中面向用户的正文的参考译文(tool/legal/build_legal.py)。',
        'footer': '文档 ID: {doc_id} · 版本: {version}(以日文版为准)',
        'sha': '日文原文的 SHA-256: {ja_sha} · 本译文的 SHA-256: {sha}',
    },
    'zh-Hant': {
        'draft': '這是公開前的草案。標有【待定】或［　］的部分將在正式版公開前確定。',
        'draftDetail': '{doc_id} / 版本 {version}。日文草案中面向使用者的內文的參考譯文(tool/legal/build_legal.py)。',
        'footer': '文件 ID: {doc_id} · 版本: {version}(以日文版為準)',
        'sha': '日文原文的 SHA-256: {ja_sha} · 本譯文的 SHA-256: {sha}',
    },
    'ko': {
        'draft': '공개 전 초안입니다. 【미정】이나 ［　］로 표시된 부분은 정식판 공개 전까지 정해집니다.',
        'draftDetail': '{doc_id} / 버전 {version}. 일본어 초안 중 이용자용 본문의 참고 번역(tool/legal/build_legal.py).',
        'footer': '문서 ID: {doc_id} · 버전: {version} (일본어판이 우선)',
        'sha': '일본어 원문의 SHA-256: {ja_sha} · 이 번역의 SHA-256: {sha}',
    },
}


def check_translation(path: str, lang: str, md: str):
    if not md.startswith(TRANSLATION_NOTICE[lang] + '\n'):
        raise SystemExit(f'{path}: 参考訳の先頭に注記がありません(TRANSLATION_NOTICE[{lang!r}])')
    for f in FORBIDDEN + ["'''"]:
        if f in md:
            raise SystemExit(f'{path}: 使えない文字列が混ざっています: {f!r}')


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


def page(doc_id: str, area: str, title: str, md: str, sha: str, lang: str = 'ja', ja_sha: str | None = None) -> dict:
    """文書ページ。[lang] が ja 以外なら参考訳のページ: `doc` は日本語の正本(承諾の記録はこちら)、訳は `translation`。"""
    content = to_nodes(md)
    t = {k: v.format(doc_id=doc_id, version=VERSION, sha=sha, ja_sha=ja_sha or sha) for k, v in PAGE_TEXT[lang].items()}
    out = {
        'schema': 'rasq.settings-page/1',
        'area': area,
        'title': title,
        # 文書 ID・版・本文の SHA-256 (CONS-01)。test が assets/legal/*.md と照らす。参考訳でも日本語の正本の値。
        'doc': {'id': doc_id, 'version': VERSION, 'bodySha256': ja_sha or sha},
    }
    if lang != 'ja':
        out['translation'] = {'locale': lang, 'bodySha256': sha, 'governing': 'ja'}
    out.update({
        'defaults': {},
        'root': {
            't': 'Column',
            'c': [
                {'t': 'Notice', 'p': {'kind': 'warning', 'text': t['draft'], 'detail': t['draftDetail']}},
                *content,
                {'t': 'Text', 'p': {'text': t['footer'], 'pad': 16, 'size': 11}},
                {'t': 'Text', 'p': {'text': t['sha'], 'pad': 16, 'size': 11, 'dev': True}},
            ],
        },
    })
    return out


def write_json(path: str, obj: dict):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write('\n')


def build_translations(entries) -> dict:
    """参考訳の文書ページ(assets/settings/<言語>/<area>.rrl.json)。戻り値は 文書 ID → 言語 → 訳の SHA-256。"""
    done: dict[str, dict[str, str]] = {}
    for lang in TRANSLATIONS:
        for doc_id, area, _title, ja_sha in entries:
            md_path = os.path.join(LEGAL, lang, f'{doc_id}.md')
            out_path = os.path.join(SETTINGS, lang, f'{area}.rrl.json')
            if not os.path.exists(md_path):
                # 訳が無くなったら古いページも消す(日本語に倒れる)。
                if os.path.exists(out_path):
                    os.remove(out_path)
                continue
            md = open(md_path, encoding='utf-8').read()
            check_translation(md_path, lang, md)
            sha = hashlib.sha256(md.encode('utf-8')).hexdigest()
            write_json(out_path, page(doc_id, area, TRANSLATED_TITLES[doc_id][lang], md, sha, lang=lang, ja_sha=ja_sha))
            done.setdefault(doc_id, {})[lang] = sha
    return done


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
        write_json(os.path.join(SETTINGS, f'{area}.rrl.json'), page(doc_id, area, title, md, sha))
        entries.append((doc_id, area, title, sha))
    translated = build_translations([(d, a, t, s) for d, a, t, s in entries])
    with open(DART, 'w', encoding='utf-8') as f:
        f.write('// 生成: tool/legal/build_legal.py(手で直さない)。規約・ポリシーの文書 ID・版・本文の SHA-256 (D-372 / CONS-01)。\n\n')
        f.write('/// 草案の版(全文書で同じ)。利用規約 / プライバシーポリシーの承諾の版にもなる。\n')
        f.write(f"const rasqLegalVersion = '{VERSION}';\n\n")
        f.write('/// 文書 ID → (設定ページ, 題, 版, 本文の SHA-256)。\n')
        f.write('const rasqLegalDocs = <String, ({String area, String title, String version, String sha256})>{\n')
        for doc_id, area, title, sha in entries:
            f.write(f"  '{doc_id}': (area: '{area}', title: '{title}', version: rasqLegalVersion, sha256: '{sha}'),\n")
        f.write('};\n\n')
        f.write('/// 参考訳 (D-535): 文書 ID → 言語 → (題, 訳の本文の SHA-256)。正本は日本語で、承諾は [rasqLegalDocs] の版 / sha256 に対して記録する。\n')
        f.write('const rasqLegalTranslations = <String, Map<String, ({String title, String sha256})>>{\n')
        for doc_id, _area, _title, _sha in entries:
            if doc_id in translated:
                f.write(f"  '{doc_id}': {{\n")
                for lang, tsha in translated[doc_id].items():
                    f.write(f"    '{lang}': (title: '{TRANSLATED_TITLES[doc_id][lang]}', sha256: '{tsha}'),\n")
                f.write('  },\n')
        f.write('};\n')
    print('\n'.join(f'{d} → {a} ({s[:12]})' for d, a, _, s in entries))
    print('\n'.join(f'{lang}/{d} ({s[:12]})' for d, m in translated.items() for lang, s in m.items()))
    build_plugin_terms()


def plugin_const(plugin_id: str) -> str:
    # rasq.official.misskey → officialMisskeyTerms
    parts = plugin_id.split('.')[1:]
    return parts[0] + ''.join(p[:1].upper() + p[1:] for p in parts[1:]) + 'Terms'


def plugin_locales_const(plugin_id: str) -> str:
    # rasq.official.misskey → officialMisskeyTermsLocales
    return plugin_const(plugin_id) + 'Locales'


def build_plugin_terms():
    files = sorted(f for f in os.listdir(PLUGIN_LEGAL) if f.endswith('.md'))
    with open(PLUGIN_DART, 'w', encoding='utf-8') as f:
        f.write('// 生成: tool/legal/build_legal.py(手で直さない)。正本は assets/legal/plugins/<pluginId>.md。\n')
        f.write('// 公式の SNS プラグインの規約(マニフェストの termsOfService、初回ログインの前に出す)。\n')
        f.write('// 参考訳は assets/legal/<言語>/plugins/<pluginId>.md → `<名前>TermsLocales`(マニフェストの locales、日本語が正本)。\n')
        f.write("\nimport 'manifest_locales.dart';\n")
        for name in files:
            plugin_id = name[:-3]
            md = open(os.path.join(PLUGIN_LEGAL, name), encoding='utf-8').read()
            for bad in FORBIDDEN + ["'''"]:
                if bad in md:
                    raise SystemExit(f'{name}: 使えない文字列が混ざっています: {bad!r}')
            f.write(f"\n/// `{plugin_id}` の規約。\nconst {plugin_const(plugin_id)} = r'''\n{md}''';\n")
            translated = []
            for lang in TRANSLATIONS:
                path = os.path.join(LEGAL, lang, 'plugins', name)
                if os.path.exists(path):
                    tmd = open(path, encoding='utf-8').read()
                    check_translation(path, lang, tmd)
                    translated.append((lang, tmd))
            f.write(f"\n/// `{plugin_id}` の規約の参考訳(マニフェストの `locales.<言語>.termsOfService`)。\n")
            f.write(f"const {plugin_locales_const(plugin_id)} = ManifestLocales(byTag: {{\n")
            for lang, tmd in translated:
                # ManifestLocales の byTag のキーは正規化したタグ(小文字)。
                f.write(f"  '{lang.lower()}': {{'termsOfService': r'''\n{tmd}'''}},\n")
            f.write('});\n')
    print('\n'.join(f'plugins/{n} → {plugin_const(n[:-3])}' for n in files))

if __name__ == '__main__':
    main()
