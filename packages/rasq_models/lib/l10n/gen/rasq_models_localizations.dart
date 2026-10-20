// tool/l10n_merge.dart が lib/l10n/parts/*.arb から作る(手で直さない)。Flutter に依らない部品の文言 (D-533、docs/I18N.md)。
// ignore_for_file: type=lint

/// 文言(言語ごとの実装は [lookupRasqModelsLocalizations])。
abstract class RasqModelsLocalizations {
  const RasqModelsLocalizations(this.localeName);

  /// この文言の言語(`ja` など)。
  final String localeName;

  /// 訳のある言語。
  static const supportedLocales = <String>['ja'];

  /// 誤りのコードの系統の名前: B(認証など、ほかに影響する設定の誤り)
  ///
  /// ja: **"影響設定"**
  String get modelsErrorFamilyAffectedSettings;

  /// 誤りのコードの系統の名前: D(データが壊れている)
  ///
  /// ja: **"データ破損"**
  String get modelsErrorFamilyDataCorruption;

  /// 誤りのコードの系統の名前: HTTP の誤り(000〜999)。HTTP は訳さない
  ///
  /// ja: **"HTTP"**
  String get modelsErrorFamilyHttp;

  /// 誤りのコードの系統の名前: C(プラグインのあいだのデータの受け渡しの誤り)
  ///
  /// ja: **"プラグイン間受け渡し"**
  String get modelsErrorFamilyPluginTransfer;

  /// 誤りのコードの系統の名前: E(Ban・規制モード)
  ///
  /// ja: **"規制"**
  String get modelsErrorFamilyRegulation;

  /// 誤りのコードの系統の名前: F(予約。まだ使っていない)
  ///
  /// ja: **"予約"**
  String get modelsErrorFamilyReserved;

  /// 誤りのコードの系統の名前: A(設定の誤り)
  ///
  /// ja: **"設定"**
  String get modelsErrorFamilySettings;

  /// 誤り 500 の、利用者への手がかり
  ///
  /// ja: **"サーバーでエラーが発生しました"**
  String get modelsErrorInternalServerErrorHint;

  /// 誤り 405 の、利用者への手がかり(プラグインの不具合のことが多い)
  ///
  /// ja: **"プラグインの障害情報をチェックしてください"**
  String get modelsErrorMethodNotAcceptableHint;

  /// 誤り A25(トレンドの条件に合うものが無い)の、利用者への手がかり。「好きなジャンル/方向性」はトレンドの設定の名前
  ///
  /// ja: **"好きなジャンル/方向性の設定を変更してください"**
  String get modelsErrorNoTrendRequirementHint;

  /// 誤り D2F(関連 TL が壊れた)の、利用者への手がかり
  ///
  /// ja: **"リロードすると解決することがあります"**
  String get modelsErrorRelationalTimelineBrokenHint;

  /// 誤り 408(応答が無い)の、利用者への手がかり
  ///
  /// ja: **"インターネット接続を確認してください"**
  String get modelsErrorTimeoutHint;
}

/// `ja` の文言(テンプレート)。
class RasqModelsLocalizationsJa extends RasqModelsLocalizations {
  const RasqModelsLocalizationsJa([super.localeName = 'ja']);

  @override
  String get modelsErrorFamilyAffectedSettings => '影響設定';

  @override
  String get modelsErrorFamilyDataCorruption => 'データ破損';

  @override
  String get modelsErrorFamilyHttp => 'HTTP';

  @override
  String get modelsErrorFamilyPluginTransfer => 'プラグイン間受け渡し';

  @override
  String get modelsErrorFamilyRegulation => '規制';

  @override
  String get modelsErrorFamilyReserved => '予約';

  @override
  String get modelsErrorFamilySettings => '設定';

  @override
  String get modelsErrorInternalServerErrorHint => 'サーバーでエラーが発生しました';

  @override
  String get modelsErrorMethodNotAcceptableHint => 'プラグインの障害情報をチェックしてください';

  @override
  String get modelsErrorNoTrendRequirementHint => '好きなジャンル/方向性の設定を変更してください';

  @override
  String get modelsErrorRelationalTimelineBrokenHint => 'リロードすると解決することがあります';

  @override
  String get modelsErrorTimeoutHint => 'インターネット接続を確認してください';
}

/// [tag](BCP-47。`ja` / `en-US` / `zh_Hant`)の文言。そのタグ → 言語だけ → `ja` の順に倒す。
RasqModelsLocalizations lookupRasqModelsLocalizations(String tag) {
  final t = tag.replaceAll('_', '-').toLowerCase();
  for (final c in [t, t.split('-').first]) {
    switch (c) {
      case 'ja':
        return const RasqModelsLocalizationsJa();
    }
  }
  return const RasqModelsLocalizationsJa();
}
