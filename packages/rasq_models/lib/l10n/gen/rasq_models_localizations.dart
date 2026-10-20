// tool/l10n_merge.dart が lib/l10n/parts/*.arb から作る(手で直さない)。Flutter に依らない部品の文言 (D-533、docs/I18N.md)。
// ignore_for_file: type=lint

/// 文言(言語ごとの実装は [lookupRasqModelsLocalizations])。
abstract class RasqModelsLocalizations {
  const RasqModelsLocalizations(this.localeName);

  /// この文言の言語(`ja` など)。
  final String localeName;

  /// 訳のある言語。
  static const supportedLocales = <String>['ja', 'en', 'ko', 'zh', 'zh_Hant'];

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

/// `en` の文言(訳の無いキーは ja の文言)。
class RasqModelsLocalizationsEn extends RasqModelsLocalizationsJa {
  const RasqModelsLocalizationsEn([super.localeName = 'en']);

  @override
  String get modelsErrorFamilyAffectedSettings => 'Affected settings';

  @override
  String get modelsErrorFamilyDataCorruption => 'Data corruption';

  @override
  String get modelsErrorFamilyHttp => 'HTTP';

  @override
  String get modelsErrorFamilyPluginTransfer => 'Plugin data transfer';

  @override
  String get modelsErrorFamilyRegulation => 'Restriction';

  @override
  String get modelsErrorFamilyReserved => 'Reserved';

  @override
  String get modelsErrorFamilySettings => 'Settings';

  @override
  String get modelsErrorInternalServerErrorHint => 'An error occurred on the server';

  @override
  String get modelsErrorMethodNotAcceptableHint => 'Check the plugin\'s issue reports';

  @override
  String get modelsErrorNoTrendRequirementHint => 'Change your favorite genres/directions setting';

  @override
  String get modelsErrorRelationalTimelineBrokenHint => 'Reloading may fix this';

  @override
  String get modelsErrorTimeoutHint => 'Check your internet connection';
}

/// `ko` の文言(訳の無いキーは ja の文言)。
class RasqModelsLocalizationsKo extends RasqModelsLocalizationsJa {
  const RasqModelsLocalizationsKo([super.localeName = 'ko']);

  @override
  String get modelsErrorFamilyAffectedSettings => '영향 설정';

  @override
  String get modelsErrorFamilyDataCorruption => '데이터 손상';

  @override
  String get modelsErrorFamilyHttp => 'HTTP';

  @override
  String get modelsErrorFamilyPluginTransfer => '플러그인 간 데이터 전달';

  @override
  String get modelsErrorFamilyRegulation => '제한';

  @override
  String get modelsErrorFamilyReserved => '예약';

  @override
  String get modelsErrorFamilySettings => '설정';

  @override
  String get modelsErrorInternalServerErrorHint => '서버에서 오류가 발생했습니다';

  @override
  String get modelsErrorMethodNotAcceptableHint => '플러그인의 장애 정보를 확인해 주세요';

  @override
  String get modelsErrorNoTrendRequirementHint => '좋아하는 장르/방향 설정을 변경해 주세요';

  @override
  String get modelsErrorRelationalTimelineBrokenHint => '새로고침하면 해결될 수 있습니다';

  @override
  String get modelsErrorTimeoutHint => '인터넷 연결을 확인해 주세요';
}

/// `zh` の文言(訳の無いキーは ja の文言)。
class RasqModelsLocalizationsZh extends RasqModelsLocalizationsJa {
  const RasqModelsLocalizationsZh([super.localeName = 'zh']);

  @override
  String get modelsErrorFamilyAffectedSettings => '受影响的设置';

  @override
  String get modelsErrorFamilyDataCorruption => '数据损坏';

  @override
  String get modelsErrorFamilyHttp => 'HTTP';

  @override
  String get modelsErrorFamilyPluginTransfer => '插件间数据传递';

  @override
  String get modelsErrorFamilyRegulation => '限制';

  @override
  String get modelsErrorFamilyReserved => '预留';

  @override
  String get modelsErrorFamilySettings => '设置';

  @override
  String get modelsErrorInternalServerErrorHint => '服务器发生错误';

  @override
  String get modelsErrorMethodNotAcceptableHint => '请查看插件的故障信息';

  @override
  String get modelsErrorNoTrendRequirementHint => '请更改“喜欢的类型/方向”设置';

  @override
  String get modelsErrorRelationalTimelineBrokenHint => '重新加载可能会解决此问题';

  @override
  String get modelsErrorTimeoutHint => '请检查网络连接';
}

/// `zh_Hant` の文言(訳の無いキーは ja の文言)。
class RasqModelsLocalizationsZhHant extends RasqModelsLocalizationsJa {
  const RasqModelsLocalizationsZhHant([super.localeName = 'zh_Hant']);

  @override
  String get modelsErrorFamilyAffectedSettings => '受影響的設定';

  @override
  String get modelsErrorFamilyDataCorruption => '資料損毀';

  @override
  String get modelsErrorFamilyHttp => 'HTTP';

  @override
  String get modelsErrorFamilyPluginTransfer => '外掛間資料傳遞';

  @override
  String get modelsErrorFamilyRegulation => '限制';

  @override
  String get modelsErrorFamilyReserved => '保留';

  @override
  String get modelsErrorFamilySettings => '設定';

  @override
  String get modelsErrorInternalServerErrorHint => '伺服器發生錯誤';

  @override
  String get modelsErrorMethodNotAcceptableHint => '請查看外掛的故障資訊';

  @override
  String get modelsErrorNoTrendRequirementHint => '請變更「喜歡的類型/方向」設定';

  @override
  String get modelsErrorRelationalTimelineBrokenHint => '重新載入可能會解決此問題';

  @override
  String get modelsErrorTimeoutHint => '請檢查網路連線';
}

/// [tag](BCP-47。`ja` / `en-US` / `zh_Hant`)の文言。そのタグ → 言語だけ → `ja` の順に倒す。
RasqModelsLocalizations lookupRasqModelsLocalizations(String tag) {
  final t = tag.replaceAll('_', '-').toLowerCase();
  for (final c in [t, t.split('-').first]) {
    switch (c) {
      case 'ja':
        return const RasqModelsLocalizationsJa();
      case 'en':
        return const RasqModelsLocalizationsEn();
      case 'ko':
        return const RasqModelsLocalizationsKo();
      case 'zh':
        return const RasqModelsLocalizationsZh();
      case 'zh-hant':
        return const RasqModelsLocalizationsZhHant();
    }
  }
  return const RasqModelsLocalizationsJa();
}
