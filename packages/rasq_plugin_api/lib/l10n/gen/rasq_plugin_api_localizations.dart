// tool/l10n_merge.dart が lib/l10n/parts/*.arb から作る(手で直さない)。Flutter に依らない部品の文言 (D-533、docs/I18N.md)。
// ignore_for_file: type=lint

/// 文言(言語ごとの実装は [lookupRasqPluginApiLocalizations])。
abstract class RasqPluginApiLocalizations {
  const RasqPluginApiLocalizations(this.localeName);

  /// この文言の言語(`ja` など)。
  final String localeName;

  /// 訳のある言語。
  static const supportedLocales = <String>['ja', 'en', 'ko', 'zh', 'zh_Hant'];

  /// ホームのタブの名前: ログインしている全部のアカウントのホームの TL を合わせたもの
  ///
  /// ja: **"総合"**
  String get pluginApiTimelineBundle;

  /// ホームのタブの名前: つながっているサーバー全体の TL
  ///
  /// ja: **"グローバル"**
  String get pluginApiTimelineGlobal;

  /// ホームのタブの名前: フォローしている人の TL
  ///
  /// ja: **"フォロー中"**
  String get pluginApiTimelineHome;

  /// ホームのタブの名前: そのサーバーの人の TL
  ///
  /// ja: **"ローカル"**
  String get pluginApiTimelineLocal;

  /// ホームのタブの名前: おすすめの投稿の TL
  ///
  /// ja: **"おすすめ"**
  String get pluginApiTimelineRecommended;

  /// ホームのタブの名前: 会話ごとにまとめた RASQ の TL(関連 TL)
  ///
  /// ja: **"関連"**
  String get pluginApiTimelineRelational;

  /// ホームのタブの名前: フォロー中とローカルを合わせた TL(Misskey の呼び名)
  ///
  /// ja: **"ソーシャル"**
  String get pluginApiTimelineSocial;
}

/// `ja` の文言(テンプレート)。
class RasqPluginApiLocalizationsJa extends RasqPluginApiLocalizations {
  const RasqPluginApiLocalizationsJa([super.localeName = 'ja']);

  @override
  String get pluginApiTimelineBundle => '総合';

  @override
  String get pluginApiTimelineGlobal => 'グローバル';

  @override
  String get pluginApiTimelineHome => 'フォロー中';

  @override
  String get pluginApiTimelineLocal => 'ローカル';

  @override
  String get pluginApiTimelineRecommended => 'おすすめ';

  @override
  String get pluginApiTimelineRelational => '関連';

  @override
  String get pluginApiTimelineSocial => 'ソーシャル';
}

/// `en` の文言(訳の無いキーは ja の文言)。
class RasqPluginApiLocalizationsEn extends RasqPluginApiLocalizationsJa {
  const RasqPluginApiLocalizationsEn([super.localeName = 'en']);

  @override
  String get pluginApiTimelineBundle => 'All accounts';

  @override
  String get pluginApiTimelineGlobal => 'Global';

  @override
  String get pluginApiTimelineHome => 'Following';

  @override
  String get pluginApiTimelineLocal => 'Local';

  @override
  String get pluginApiTimelineRecommended => 'Recommended';

  @override
  String get pluginApiTimelineRelational => 'Related';

  @override
  String get pluginApiTimelineSocial => 'Social';
}

/// `ko` の文言(訳の無いキーは ja の文言)。
class RasqPluginApiLocalizationsKo extends RasqPluginApiLocalizationsJa {
  const RasqPluginApiLocalizationsKo([super.localeName = 'ko']);

  @override
  String get pluginApiTimelineBundle => '종합';

  @override
  String get pluginApiTimelineGlobal => '글로벌';

  @override
  String get pluginApiTimelineHome => '팔로잉';

  @override
  String get pluginApiTimelineLocal => '로컬';

  @override
  String get pluginApiTimelineRecommended => '추천';

  @override
  String get pluginApiTimelineRelational => '관련';

  @override
  String get pluginApiTimelineSocial => '소셜';
}

/// `zh` の文言(訳の無いキーは ja の文言)。
class RasqPluginApiLocalizationsZh extends RasqPluginApiLocalizationsJa {
  const RasqPluginApiLocalizationsZh([super.localeName = 'zh']);

  @override
  String get pluginApiTimelineBundle => '综合';

  @override
  String get pluginApiTimelineGlobal => '全局';

  @override
  String get pluginApiTimelineHome => '关注中';

  @override
  String get pluginApiTimelineLocal => '本地';

  @override
  String get pluginApiTimelineRecommended => '推荐';

  @override
  String get pluginApiTimelineRelational => '关联';

  @override
  String get pluginApiTimelineSocial => '社交';
}

/// `zh_Hant` の文言(訳の無いキーは ja の文言)。
class RasqPluginApiLocalizationsZhHant extends RasqPluginApiLocalizationsJa {
  const RasqPluginApiLocalizationsZhHant([super.localeName = 'zh_Hant']);

  @override
  String get pluginApiTimelineBundle => '綜合';

  @override
  String get pluginApiTimelineGlobal => '全域';

  @override
  String get pluginApiTimelineHome => '追蹤中';

  @override
  String get pluginApiTimelineLocal => '本站';

  @override
  String get pluginApiTimelineRecommended => '推薦';

  @override
  String get pluginApiTimelineRelational => '關聯';

  @override
  String get pluginApiTimelineSocial => '社群';
}

/// [tag](BCP-47。`ja` / `en-US` / `zh_Hant`)の文言。そのタグ → 言語だけ → `ja` の順に倒す。
RasqPluginApiLocalizations lookupRasqPluginApiLocalizations(String tag) {
  final t = tag.replaceAll('_', '-').toLowerCase();
  for (final c in [t, t.split('-').first]) {
    switch (c) {
      case 'ja':
        return const RasqPluginApiLocalizationsJa();
      case 'en':
        return const RasqPluginApiLocalizationsEn();
      case 'ko':
        return const RasqPluginApiLocalizationsKo();
      case 'zh':
        return const RasqPluginApiLocalizationsZh();
      case 'zh-hant':
        return const RasqPluginApiLocalizationsZhHant();
    }
  }
  return const RasqPluginApiLocalizationsJa();
}
