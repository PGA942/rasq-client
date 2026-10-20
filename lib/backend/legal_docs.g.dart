// 生成: tool/legal/build_legal.py(手で直さない)。規約・ポリシーの文書 ID・版・本文の SHA-256 (D-372 / CONS-01)。

/// 草案の版(全文書で同じ)。利用規約 / プライバシーポリシーの承諾の版にもなる。
const rasqLegalVersion = '1.0.0-draft.20261007';

/// 文書 ID → (設定ページ, 題, 版, 本文の SHA-256)。
const rasqLegalDocs = <String, ({String area, String title, String version, String sha256})>{
  'rasq.terms': (area: 'about.terms', title: '利用規約', version: rasqLegalVersion, sha256: '0158d647e2a07904d2a3506da2012616a7ee5a60f68c5309b141491415f46d58'),
  'rasq.privacy': (area: 'about.privacy', title: 'プライバシーポリシー', version: rasqLegalVersion, sha256: '746824911fca56d4fa0667ae5b429917a9200fb1712032c6b70a61065ed0da6a'),
  'rasq.learning': (area: 'about.learning', title: 'アルゴリズムとコミュニティへの貢献について', version: rasqLegalVersion, sha256: '528897f3018cd2f75cbfe483b62ff4279daefef563b7387a008b95ddf828c42f'),
  'rasq.astell': (area: 'about.astell', title: 'ASTell の利用条件', version: rasqLegalVersion, sha256: 'aa2c45e503aea41696c9db33b0219869c58c024ab986cf6edba19dc0527d5f03'),
  'rasq.rai': (area: 'about.rai', title: 'RAi の利用条件', version: rasqLegalVersion, sha256: '7ebe73313485a9c6d74aa7e66dd85238a9d9d5a686a800aaf9333150cfd70a4b'),
  'rasq.store': (area: 'about.store', title: 'プラグインストアの利用条件', version: rasqLegalVersion, sha256: 'd1c05e4e39630ddc983f2a5da50f1bcefd3139529de686c19ff5e92942a39940'),
  'rasq.developer': (area: 'about.devterms', title: 'プラグイン開発者の掲載・審査条件', version: rasqLegalVersion, sha256: 'da0e24257c5b22abdf93ac4350cae9bafae81e46f126e73271097a32b1ba75e5'),
  'rasq.billing': (area: 'about.billing', title: '料金・ポイントの条件', version: rasqLegalVersion, sha256: '97b63db997b737d911ea6dea1d05edc9e0f8b579877029422dbedf404fc65b4b'),
  'rasq.commerce': (area: 'about.commerce', title: '特定商取引法に基づく表記', version: rasqLegalVersion, sha256: '2378016eb2eeb06a84d1c0740710509438c65c624823e3d9643252ba292e5c7f'),
};

/// 参考訳 (D-535): 文書 ID → 言語 → (題, 訳の本文の SHA-256)。正本は日本語で、承諾は [rasqLegalDocs] の版 / sha256 に対して記録する。
const rasqLegalTranslations = <String, Map<String, ({String title, String sha256})>>{
  'rasq.terms': {
    'en': (title: 'Terms of Service', sha256: 'b64b22ffe587287a2088d6d5823d7a77cc61360672251b7cdda81c5ef9f191b3'),
    'zh': (title: '使用条款', sha256: 'c4709b5c2994e0d9d12767dd9840dcc3d662f8123b2d128bb8ffa957cb273954'),
    'zh-Hant': (title: '使用條款', sha256: '20c044a377bf28a09541ebb3427a0145325d619690df06f14f20076b8e01a29f'),
    'ko': (title: '이용약관', sha256: '316f2436739c65787ec43815fc11782a7f48789af71678da5802db83bc8326c4'),
  },
  'rasq.privacy': {
    'en': (title: 'Privacy Policy', sha256: '80bc24a42368d12562ef332b6d194b5261d9860e8aa6f37061d183da401a7679'),
    'zh': (title: '隐私政策', sha256: '30be397a56321e50f3ed42317e2e9ab8e5ed80876af4001adb0453a90cc426de'),
    'zh-Hant': (title: '隱私權政策', sha256: '47054c98ed399592b3fdfa49e9947cadd93875cecb715e7ddfee560b593ae38f'),
    'ko': (title: '개인정보 처리방침', sha256: 'c01568327c388d03d2d848aa9b10204b06d688fc5a083f929c36f441c970d22f'),
  },
  'rasq.learning': {
    'en': (title: 'About Contributing to Algorithms and the Community', sha256: '1e67239b012b36623ff29e66b21da2d88b011bda3cf75bb14e026c86ad2c8cf0'),
    'zh': (title: '关于对算法与社区的贡献', sha256: '345ac3333a2a32dd8c6fd9c94370327367af3afccedd4fe0e617bcc614450717'),
    'zh-Hant': (title: '關於對演算法與社群的貢獻', sha256: '67073d92bfeef156e360155d2216bc1c03f28784223b0466ea30d499f01662d4'),
    'ko': (title: '알고리즘과 커뮤니티에 대한 기여에 관하여', sha256: '8e9764104168f67de12b896a22d78b14c48f70d6d64e2b9f3649ddb2bd9ae977'),
  },
  'rasq.astell': {
    'en': (title: 'ASTell Terms of Use', sha256: '26a64a490d9538f78c17248d6354f9d428ea0da5245b31a950b92a45e0a34ac5'),
    'zh': (title: 'ASTell 使用条件', sha256: '00b89174511f6a2a86717365bfecdaaa3335e18bd01d9ecfccc86b1370fd53b7'),
    'zh-Hant': (title: 'ASTell 使用條件', sha256: '5934df2c0605f94a50dcc3c70096a4e24c1a91d618b76579714eb920158edcbb'),
    'ko': (title: 'ASTell 이용 조건', sha256: 'fb442401337f3ec7743a747e88039997b5070ea31739572c1c592afd397b6ecc'),
  },
  'rasq.rai': {
    'en': (title: 'RAi Terms of Use', sha256: 'dff1b2d6025705a727bf17231824feafbc940d791be3ec23222d5cd02961e724'),
    'zh': (title: 'RAi 使用条件', sha256: '909ec97579e573b07514d5d22d2b8dd18c5e037958ab2233eb7a5b7ce72de563'),
    'zh-Hant': (title: 'RAi 使用條件', sha256: '60ecbd70346478ed571ed9db6c1594156dddb3c7b968e3a10c5ffdaaebbcfa05'),
    'ko': (title: 'RAi 이용 조건', sha256: '8f524556275611e3cea6102912333eb20602bebdec4145d4d6ad86fa00843846'),
  },
  'rasq.store': {
    'en': (title: 'Plugin Store Terms of Use', sha256: 'c5ccb3ced169cfefc93f8e1e8aa041112820291f6956c9c064b702dc3cb4aa64'),
    'zh': (title: '插件商店使用条件', sha256: 'e40ec19b49072b7f9cb6bd5a0c63b7ca2069c880bfa211bd413adc696d04d88a'),
    'zh-Hant': (title: '外掛商店使用條件', sha256: 'e9a5ba8b388f34ef0a87bb734f1e871fe113437648c9f85aaffdfa9a4d5942a9'),
    'ko': (title: '플러그인 스토어 이용 조건', sha256: '7de79587383e347e2caa0885b3d3141aa6a638552bd104957f537e241bca6e43'),
  },
  'rasq.developer': {
    'en': (title: 'Plugin Developer Listing and Review Terms', sha256: '02906e02c98517b388d53fb2179694957903aca76e4accda75f7a9fbf418f46a'),
    'zh': (title: '插件开发者上架与审核条件', sha256: 'b5f2413f2113cd74c57fcb63eca5ef17880520729fd30929a67d1b13433969f7'),
    'zh-Hant': (title: '外掛開發者上架與審查條件', sha256: '8a99521e441e201de910d8c5f21027e79ddfd1b92d411f13622c8f90cd8a52b3'),
    'ko': (title: '플러그인 개발자 게재·심사 조건', sha256: 'a1f8f103bd630054e331c8df8181acabd3a764303d2694cbfef333e466ec3cb3'),
  },
  'rasq.billing': {
    'en': (title: 'Pricing and Points Terms', sha256: 'edc6458d78d4c3730f4244a2fe8993d0d155a303623686967a985c7057a2adb2'),
    'zh': (title: '费用与积分条件', sha256: 'f2c519857d29c7ebd0903486566c53916b0eb428e5c29cd0825e3870a0370b50'),
    'zh-Hant': (title: '費用與點數條件', sha256: 'c60f0c1bd615be4714d5b4a1c35237204c206abc2c82d5102947c9f40ce7a2b4'),
    'ko': (title: '요금·포인트 조건', sha256: 'e116fd286903ec90ae339b94ed3cd97be988e2c6a6b87c4cd66452ae06a56df6'),
  },
  'rasq.commerce': {
    'en': (title: 'Notation Based on the Act on Specified Commercial Transactions', sha256: '6dfb1ca79c1c3d59cc3b894968de7460f32bf4ba19e84705c09aee4cdd0aae3e'),
    'zh': (title: '基于《特定商业交易法》的标示', sha256: '7040f5fa6673e1b6e576e24373e31b618779d9b8657a4979955093d6cbb7583a'),
    'zh-Hant': (title: '依《特定商業交易法》之標示', sha256: 'a44db46a714551a4fb3d2389c0a881c2d8b827a91bf012bf7e6e7b2217c861bf'),
    'ko': (title: '특정상거래법에 따른 표기', sha256: '09adaece5f1812d956d8ccd582a3107e804b283fd892f3ab5ec55fbbae38f49c'),
  },
};
