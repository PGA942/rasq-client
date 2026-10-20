// tool/l10n_merge.dart が lib/l10n/parts/*.arb から作る(手で直さない)。Flutter に依らない部品の文言 (D-533、docs/I18N.md)。
// ignore_for_file: type=lint

/// 文言(言語ごとの実装は [lookupRasqPluginApiLocalizations])。
abstract class RasqPluginApiLocalizations {
  const RasqPluginApiLocalizations(this.localeName);

  /// この文言の言語(`ja` など)。
  final String localeName;

  /// 訳のある言語。
  static const supportedLocales = <String>['ja'];

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

/// [tag](BCP-47。`ja` / `en-US` / `zh_Hant`)の文言。そのタグ → 言語だけ → `ja` の順に倒す。
RasqPluginApiLocalizations lookupRasqPluginApiLocalizations(String tag) {
  final t = tag.replaceAll('_', '-').toLowerCase();
  for (final c in [t, t.split('-').first]) {
    switch (c) {
      case 'ja':
        return const RasqPluginApiLocalizationsJa();
    }
  }
  return const RasqPluginApiLocalizationsJa();
}
