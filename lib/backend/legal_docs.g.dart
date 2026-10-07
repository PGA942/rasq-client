// 生成: tool/legal/build_legal.py(手で直さない)。規約・ポリシーの文書 ID・版・本文の SHA-256 (D-372 / CONS-01)。

/// 草案の版(全文書で同じ)。利用規約 / プライバシーポリシーの承諾の版にもなる。
const rasqLegalVersion = '1.0.0-draft.20261007';

/// 文書 ID → (設定ページ, 題, 版, 本文の SHA-256)。
const rasqLegalDocs = <String, ({String area, String title, String version, String sha256})>{
  'rasq.terms': (area: 'about.terms', title: '利用規約', version: rasqLegalVersion, sha256: '0158d647e2a07904d2a3506da2012616a7ee5a60f68c5309b141491415f46d58'),
  'rasq.privacy': (area: 'about.privacy', title: 'プライバシーポリシー', version: rasqLegalVersion, sha256: '746824911fca56d4fa0667ae5b429917a9200fb1712032c6b70a61065ed0da6a'),
  'rasq.learning': (area: 'about.learning', title: 'アルゴリズムとコミュニティへの貢献について', version: rasqLegalVersion, sha256: '528897f3018cd2f75cbfe483b62ff4279daefef563b7387a008b95ddf828c42f'),
  'rasq.astell': (area: 'about.astell', title: 'AsTell の利用条件', version: rasqLegalVersion, sha256: 'aa2c45e503aea41696c9db33b0219869c58c024ab986cf6edba19dc0527d5f03'),
  'rasq.rai': (area: 'about.rai', title: 'RAi の利用条件', version: rasqLegalVersion, sha256: '7ebe73313485a9c6d74aa7e66dd85238a9d9d5a686a800aaf9333150cfd70a4b'),
  'rasq.store': (area: 'about.store', title: 'プラグインストアの利用条件', version: rasqLegalVersion, sha256: 'd1c05e4e39630ddc983f2a5da50f1bcefd3139529de686c19ff5e92942a39940'),
  'rasq.developer': (area: 'about.devterms', title: 'プラグイン開発者の掲載・審査条件', version: rasqLegalVersion, sha256: 'da0e24257c5b22abdf93ac4350cae9bafae81e46f126e73271097a32b1ba75e5'),
  'rasq.billing': (area: 'about.billing', title: '料金・ポイントの条件', version: rasqLegalVersion, sha256: '97b63db997b737d911ea6dea1d05edc9e0f8b579877029422dbedf404fc65b4b'),
  'rasq.commerce': (area: 'about.commerce', title: '特定商取引法に基づく表記', version: rasqLegalVersion, sha256: '2378016eb2eeb06a84d1c0740710509438c65c624823e3d9643252ba292e5c7f'),
};
