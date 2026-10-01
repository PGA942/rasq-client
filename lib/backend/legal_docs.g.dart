// 生成: tool/legal/build_legal.py(手で直さない)。規約・ポリシーの文書 ID・版・本文の SHA-256 (D-372 / CONS-01)。

/// 草案の版(全文書で同じ)。利用規約 / プライバシーポリシーの承諾の版にもなる。
const rasqLegalVersion = '1.0.0-draft.20260929';

/// 文書 ID → (設定ページ, 題, 版, 本文の SHA-256)。
const rasqLegalDocs = <String, ({String area, String title, String version, String sha256})>{
  'rasq.terms': (area: 'about.terms', title: '利用規約', version: rasqLegalVersion, sha256: '3639d01b3e8b2fee0c336a30b82547f6419f18247761e61f55fc44ad7ccc867a'),
  'rasq.privacy': (area: 'about.privacy', title: 'プライバシーポリシー', version: rasqLegalVersion, sha256: 'ecdd83ef1a94db7aa47a335394027209527b28316f8f1dbf75d6bd3af1fa7bd7'),
  'rasq.learning': (area: 'about.learning', title: 'アルゴリズムとコミュニティへの貢献について', version: rasqLegalVersion, sha256: '4a45111b47438067f731e717a447e8ad3cb918cfdc2941bd4745bfbd17d28014'),
  'rasq.astell': (area: 'about.astell', title: 'AsTell の利用条件', version: rasqLegalVersion, sha256: '9670d0527effe5b8ace0ec487756eb3ee11fe217aee8127833b81416066b4e55'),
  'rasq.rai': (area: 'about.rai', title: 'RAi の利用条件', version: rasqLegalVersion, sha256: 'c95668ba4837bd511d0438b78742301ccded8c74c07a8100aa7c0f5238d04e3c'),
  'rasq.store': (area: 'about.store', title: 'プラグインストアの利用条件', version: rasqLegalVersion, sha256: '5cab6346d0f2037710fa2d960639c2bec2c285c6af90be0fd61f3cd86fe6e94d'),
  'rasq.developer': (area: 'about.devterms', title: 'プラグイン開発者の掲載・審査条件', version: rasqLegalVersion, sha256: '0c54c37c63c47ad5386652846cd0a253e54137d22ed3dc7b2852aebbec179c58'),
  'rasq.billing': (area: 'about.billing', title: '料金・ポイントの条件', version: rasqLegalVersion, sha256: 'db26dcfa23ac8ee527d13bf11cc4e2fdc7f88608fce8b16e26db035f5fa4695f'),
  'rasq.commerce': (area: 'about.commerce', title: '特定商取引法に基づく表記', version: rasqLegalVersion, sha256: '5a8c3ac14ba1e441b2322d3b6bd37b22f31cb8999a00b8297fe72a85b5df46e9'),
};
