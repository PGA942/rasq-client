// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get childSafeLevelStrict => 'きびしめ';

  @override
  String get childSafeLevelStandard => 'ふつう';

  @override
  String get childSafeLevelMild => 'ゆるめ';

  @override
  String get childSafeTopicModeAllow => 'ホワイトリスト';

  @override
  String get childSafeTopicModeDeny => 'ブラックリスト';

  @override
  String get childSafeInstallNone => '入れられない';

  @override
  String get childSafeInstallListed => '選んだものだけ';

  @override
  String get childSafeInstallAny => '自由';

  @override
  String get childSafeInstallExamples => '例に近いもの';

  @override
  String get childSafeEmptyWhitelistError =>
      'ホワイトリストが空です。話題を 1 つ以上入れるか、ブラックリストにしてください';

  @override
  String get childSafeMethodJpki => 'マイナンバーカード (JPKI)';

  @override
  String get childSafeMethodSelfDeclared => '自己申告';

  @override
  String get childSafeErrorCodeInvalid => 'コードが違うか、期限が切れています';

  @override
  String get childSafeErrorHandleTaken => 'そのハンドルは使われています';

  @override
  String get childSafeErrorAlreadyLinked => 'もう見守られている(か、だれかを見守っている)アカウントです';

  @override
  String get childSafeErrorCodeGone =>
      'コードの期限が切れたか、もう使われています。保護者に出し直してもらってください';

  @override
  String get childSafeErrorDevice => 'この端末ではログインできません';

  @override
  String get childSafeErrorTooMany => '試行が多すぎます。しばらく待ってから、やり直してください';

  @override
  String get childSafeNoServer => 'RASQ サーバーの接続先が未設定です';

  @override
  String childSafeNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '(ほか $count 件)',
    );
    return '$_temp0';
  }

  @override
  String get childSafeNoticeRefreshed => 'チャイルドセーフ: 保護者の設定を取り直しました';

  @override
  String get childSafeNoticeView => '見る';

  @override
  String get childSafeBlocked => '保護者が止めています';

  @override
  String childSafeBlockedWith(String label) {
    return '保護者が止めています($label)';
  }

  @override
  String childSafeTimeRange(String start, String end) {
    return '$start〜$end';
  }

  @override
  String get childSafeLockedUntilSetup => '保護者が設定を決めるまで使えません';

  @override
  String childSafeWindowNoDm(String window) {
    return '見守りの時間($window)は DM を使えません';
  }

  @override
  String get childSafeBlockedAstell => '保護者が ASTell を止めています';

  @override
  String childSafeWindowNoAstell(String window) {
    return '見守りの時間($window)は ASTell を使えません';
  }

  @override
  String get childSafeBlockedDm => '保護者が DM を止めています';

  @override
  String childSafeWindowNoNotifications(String window) {
    return '見守りの時間($window)は通知を見られません';
  }

  @override
  String get childSafeBlockedRai => '保護者が RAi を止めています';

  @override
  String get childSafeBlockedStore => '保護者がプラグインストアを止めています';

  @override
  String get childSafeBlockedSearch => '保護者が検索を止めています';

  @override
  String get childSafeBlockedAddAccount => '保護者が SNS アカウントの追加を止めています';

  @override
  String get childSafeBlockedCustomPlugins => '保護者がカスタムプラグインを止めています';

  @override
  String get childSafeBlockedPlugins => '保護者がプラグインを止めています';

  @override
  String childSafeWindowNoPostDetail(String window) {
    return '見守りの時間($window)は投稿の詳細を開けません';
  }

  @override
  String get childSafePostHidden => 'この投稿は表示できません';

  @override
  String get childSafeListSeparator => '・';

  @override
  String childSafeBullet(String text) {
    return '・$text';
  }

  @override
  String childSafeTopicsEtc(String topics) {
    return '$topics など';
  }

  @override
  String get childSafeComposeNoTopicsAllowed => '保護者の設定により、いまは投稿を送れません';

  @override
  String childSafeComposeTopicsOnly(String topics) {
    return '保護者の設定により、決められた話題($topics)の投稿だけ送れます。話題に合うように書いてください';
  }

  @override
  String childSafeComposeTopicDenied(String topic) {
    return '保護者の設定により、「$topic」の話題の投稿は送れません。書き換えてください';
  }

  @override
  String childSafeQuoted(String text) {
    return '「$text」';
  }

  @override
  String childSafeComposeStimulus(String level, String word) {
    return '保護者の設定($level)により、この表現$wordは送れません。言い換えてください';
  }

  @override
  String get childSafeBlockedThisPlugin => '保護者がこのプラグインを止めています';

  @override
  String get childSafeDevPreviewUnknown =>
      '保護者が選んだプラグインだけ動かせます(この読み込み方では、どのプラグインか確かめられません)';

  @override
  String get childSafeBlockedInstall => '保護者がプラグインのインストールを止めています';

  @override
  String get childSafeNearDenyPlugin => '保護者が止めている例に近いプラグインです';

  @override
  String get childSafeInstallListedOnly => '保護者が選んだプラグインだけ入れられます';

  @override
  String get childSafeInstallExamplesOnly => '保護者が選んだプラグインと、許す例に近いものだけ入れられます';

  @override
  String get childSafeCacheUnverified => '控えた制限の署名を確かめられません。オンラインで取り直してください';

  @override
  String get childSafeNewSettingsUnverified =>
      '保護者の新しい設定の署名を確かめられませんでした(前の設定のまま)';

  @override
  String get childSafeComposeLocked => '保護者が設定を決めるまで送れません';

  @override
  String childSafeComposeDailyLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '今日はもう $count 件送りました(保護者が決めた 1 日の数)。また明日',
    );
    return '$_temp0';
  }

  @override
  String childSafeComposeAfterTransform(String message) {
    return '$message(送る前の加工のあとの本文)';
  }

  @override
  String get childSafeStatePending => '設定待ち';

  @override
  String get childSafeWatchAsGuardian => '見守る(保護者)';

  @override
  String get childSafeLoginWithCode => '保護者からのコードでログイン';

  @override
  String get childSafeChildMode => 'チャイルドモード';

  @override
  String get childSafeGuardianStateApplied => '見守り中(端末に届いています)';

  @override
  String childSafeGuardianStateNotApplied(int revision) {
    return '見守り中(設定 $revision はまだ端末に届いていません)';
  }

  @override
  String childSafeGuardianPledgeTitle(String version) {
    return '保護者の誓約(版 $version)';
  }

  @override
  String childSafeGuardianPledgeMessage(String pledge) {
    return '$pledge\n\n同意すると、マイナンバーカード(デジタル認証アプリ)での確認に進みます(日本にお住まいの方)。';
  }

  @override
  String get childSafeGuardianPledgeConfirm => '同意して進む';

  @override
  String get childSafeGuardianCancel => 'キャンセル';

  @override
  String get childSafeGuardianLoadError => '読み込めませんでした';

  @override
  String get childSafeGuardianReload => '再読み込み';

  @override
  String get childSafeGuardianVerifySection => '保護者の確認';

  @override
  String get childSafeGuardianVerified => '確認済み';

  @override
  String get childSafeGuardianNotVerified => 'まだ確認していません';

  @override
  String get childSafeGuardianVerifyIntro =>
      '子のアカウントを作る / つなぐ前に、保護者の確認をします(日本はマイナンバーカード)。';

  @override
  String get childSafeGuardianVerifyIntroDetail =>
      '子のアカウントを作る / つなぐ前に、保護者の確認をします(日本はマイナンバーカード (JPKI)、ほかの国は Web コンソールでの自己申告)。';

  @override
  String get childSafeGuardianVerifyJpki => 'マイナンバーカードで確認する';

  @override
  String get childSafeGuardianVerifyJpkiSubtitle =>
      '日本にお住まいの方。誓約に同意してから、外のブラウザで開きます';

  @override
  String get childSafeGuardianVerifyWeb => 'Web コンソールで確認する';

  @override
  String get childSafeGuardianOpensInBrowser => '外のブラウザで開きます';

  @override
  String childSafeGuardianChildrenSection(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '見守っている子($count / $max)',
    );
    return '$_temp0';
  }

  @override
  String get childSafeGuardianNoChildren => 'まだいません。';

  @override
  String get childSafeGuardianCreatedByGuardian => '・保護者が作成';

  @override
  String get childSafeGuardianAddSection => '子を足す';

  @override
  String get childSafeGuardianCreate => '子のアカウントを作る';

  @override
  String get childSafeGuardianCreateSubtitle =>
      'ハンドル / 名前 / 年齢の帯を決めると、子の端末でログインするためのコードが 1 度だけ出ます';

  @override
  String get childSafeGuardianHandleHint => 'ハンドル(英数字)';

  @override
  String get childSafeGuardianNameHint => '表示名';

  @override
  String get childSafeGuardianCreateButton => '作る';

  @override
  String childSafeGuardianNewLoginCodeTitle(String handle) {
    return '@$handle のログインのコード(子の端末の「保護者からのコードでログイン」に入れるか、子の端末のカメラで QR を読む)';
  }

  @override
  String get childSafeGuardianPair => 'コードでつなぐ';

  @override
  String get childSafeGuardianPairSubtitle =>
      '子がもう持っている RASQ アカウントを、子の端末の「チャイルドモード」でつなぎます(10 分・1 回だけ)';

  @override
  String get childSafeGuardianPairCodeTitle =>
      'つなぐコード(子の端末の「チャイルドモード」に入れるか、子の端末のカメラで QR を読む)';

  @override
  String childSafeGuardianCodeExpires(String time) {
    return '$time まで。この画面を閉じると、もう出せません(出し直すと前のコードは使えなくなります)。';
  }

  @override
  String get childSafeGuardianCodeQr => 'コードの QR';

  @override
  String get childSafeGuardianCopy => 'コピー';

  @override
  String get childSafeGuardianCopyLink => 'リンクをコピー';

  @override
  String get childSafeGuardianClose => '閉じる';

  @override
  String get childSafeGuardianPageTimeline => 'TL';

  @override
  String get childSafeGuardianPageComposer => '投稿';

  @override
  String get childSafeGuardianPageAstell => 'ASTell';

  @override
  String get childSafeGuardianPagePlugins => 'プラグイン';

  @override
  String get childSafeGuardianPageSns => 'SNS';

  @override
  String get childSafeGuardianPageScreenTime => 'スクリーンタイム';

  @override
  String get childSafeGuardianPageOther => 'その他';

  @override
  String get childSafeGuardianTimeFormatError => '時刻は HH:MM で入れてください';

  @override
  String get childSafeGuardianConfirmTitle => 'この設定を送る';

  @override
  String get childSafeGuardianConfirmSend => '送る';

  @override
  String childSafeGuardianConfirmIntro(String handle) {
    return '@$handle の端末に、この設定が届きます。';
  }

  @override
  String childSafeGuardianConfirmIntroDetail(String handle) {
    return '@$handle の端末には、Central が署名した設定が届きます(端末で確かめてから当てはめます)。';
  }

  @override
  String childSafeGuardianSaved(int revision) {
    return '保存しました(設定 $revision)。子の端末に届くと「届いています」になります';
  }

  @override
  String childSafeGuardianImportPreset(String band) {
    return '$band の既定を読み込む';
  }

  @override
  String get childSafeGuardianImportCopy => 'ほかの子の設定をコピー';

  @override
  String childSafeGuardianImportedPreset(String band) {
    return '$band の既定を読み込みました';
  }

  @override
  String get childSafeGuardianCopyWhich => 'どの子の設定をコピーしますか';

  @override
  String childSafeGuardianNotSetUp(String handle) {
    return '@$handle は、まだ設定が済んでいません';
  }

  @override
  String childSafeGuardianCopied(String handle) {
    return '@$handle の設定をコピーしました';
  }

  @override
  String childSafeGuardianNotSavedYet(String what) {
    return '$what(まだ保存していません)';
  }

  @override
  String get childSafeGuardianEnd => '見守りを終える';

  @override
  String childSafeGuardianEndMessage(String handle) {
    return '@$handle の制限をすべて外します。子の端末は、次につながったときに外れます。元に戻すには、もう一度つなぎます。';
  }

  @override
  String childSafeGuardianEndMessageDetail(String handle) {
    return '@$handle の制限をすべて外します。子の端末は、次に Central に届いたときに外れます。元に戻すには、もう一度つなぎます。';
  }

  @override
  String get childSafeGuardianEndConfirm => '終える';

  @override
  String get childSafeGuardianEndSubtitle => '制限をすべて外します';

  @override
  String get childSafeGuardianSummarySection => '最近の発信内容の要約(14 日)';

  @override
  String get childSafeGuardianLoginSection => '子の端末のログイン';

  @override
  String get childSafeGuardianReissue => 'コードを出し直す';

  @override
  String get childSafeGuardianReissueSubtitle =>
      '子の端末の「保護者からのコードでログイン」に入れるコード(10 分・1 回だけ。前のコードは使えなくなります)';

  @override
  String childSafeGuardianLoginCodeTitle(String handle) {
    return '@$handle のログインのコード';
  }

  @override
  String get childSafeGuardianSaveButton => '保存して子の端末へ送る';

  @override
  String get childSafeGuardianImportTooltip => '設定をインポート';

  @override
  String childSafeGuardianPresetCaption(String band) {
    return '強さを選ぶと、タイムラインと投稿の判定の強さがそろいます。右の丸いボタンで、$band の既定やほかの子の設定を読み込めます。';
  }

  @override
  String get childSafeGuardianSummaryEmpty =>
      'まだ報告はありません(子の端末は、終わった日の数を 1 日 1 回送ります)。';

  @override
  String get childSafeGuardianSummaryCaption =>
      '送った数 / 止めた数 / 止めた種類だけです(投稿の本文や話題は届きません。送る前の判定はお子さんの端末で行います)。';

  @override
  String childSafeGuardianSummaryDay(int posts, int blocked, String trips) {
    return '送った $posts・止めた $blocked$trips';
  }

  @override
  String childSafeGuardianSummaryTrips(String list) {
    return '($list)';
  }

  @override
  String get childSafeGuardianSummaryTripsSeparator => '、';

  @override
  String get childSafeGuardianTimelineEnabled => 'タイムラインを絞る';

  @override
  String get childSafeGuardianTimelineEnabledSubtitle => '強い言葉の投稿を見せず、話題で絞ります';

  @override
  String get childSafeGuardianTimelineLevel => 'タイムラインの強さ';

  @override
  String get childSafeGuardianTimelineTopics => 'タイムラインの話題';

  @override
  String get childSafeGuardianTimelineAllowHint => '流す話題(語やタグを「,」で区切る)';

  @override
  String get childSafeGuardianTimelineDenyHint => '見せない話題(語やタグを「,」で区切る)';

  @override
  String get childSafeGuardianTimelineAllowNote =>
      'ホワイトリスト: どれかの話題に当たる投稿だけが、タイムラインに流れます。';

  @override
  String get childSafeGuardianTimelineDenyNote =>
      'ブラックリスト: 当たる投稿を見せません(空 = 話題では絞りません)。';

  @override
  String get childSafeGuardianComposerEnabled => '投稿を判定する';

  @override
  String get childSafeGuardianComposerEnabledSubtitle =>
      '強い言葉と話題で、送る前に止めます(当たった語に印を付けて止める)';

  @override
  String get childSafeGuardianComposerLevel => '投稿の強さ';

  @override
  String get childSafeGuardianPostsPerDayHint => '1 日に送れる投稿の数(空 = 決めない、0〜1000)';

  @override
  String get childSafeGuardianComposerTopics => '投稿の話題';

  @override
  String get childSafeGuardianComposerAllowHint => '送れる話題(語やタグを「,」で区切る)';

  @override
  String get childSafeGuardianComposerDenyHint => '送れない話題(語やタグを「,」で区切る)';

  @override
  String get childSafeGuardianComposerAllowNote =>
      'ホワイトリスト: どれかの話題に当たる投稿だけ送れます(DM には当てません)。';

  @override
  String get childSafeGuardianComposerDenyNote =>
      'ブラックリスト: 当たる投稿は送れません(空 = 話題では止めません。DM には当てません)。';

  @override
  String get childSafeGuardianAstellCaption =>
      'ASTell(ルームの通話・チャット・共有)で、子ができること。';

  @override
  String get childSafeGuardianInstallSection => 'インストール';

  @override
  String get childSafeGuardianInstallCaption =>
      '子が自分で入れられる範囲。プラグインは増えていくので、ひとつずつではなく、下の「例」で大まかに決めます。';

  @override
  String get childSafeGuardianNamedSection => '名前で許しているプラグイン';

  @override
  String get childSafeGuardianNamedNone => 'ありません。';

  @override
  String get childSafeGuardianNamedCaption => 'ここにあるものは、止める例に近くても使えます(✕ で外す)。';

  @override
  String get childSafeGuardianRemove => '外す';

  @override
  String get childSafeGuardianAddIdHint => 'id で足す(例: jp.example.quiz)';

  @override
  String get childSafeGuardianAddIdButton => '足す';

  @override
  String get childSafeGuardianIdShapeError =>
      'プラグインの id の形ではありません(英小文字・数字・「.」「_」「-」、例: jp.example.quiz)';

  @override
  String get childSafeGuardianSnsCaption =>
      '子が使ってよい SNS の種類とサーバー(あなたのバンドルから)。サーバーを選ばなければ、その種類ならどこでも。保護者の SNS のログインは貸しません。';

  @override
  String get childSafeGuardianSnsAdd => '子が SNS アカウントを足せる';

  @override
  String get childSafeGuardianTimeEnabled => '見守りの時間';

  @override
  String get childSafeGuardianTimeEnabledSubtitle =>
      'その間は、1 本のタイムラインになります(子の端末の時計)';

  @override
  String get childSafeGuardianTimeStartHint => '始まり 21:00';

  @override
  String get childSafeGuardianTimeEndHint => '終わり 06:00';

  @override
  String get childSafeGuardianTimeRangeSeparator => '〜';

  @override
  String get childSafeGuardianTimeLegacyNote =>
      'いまの設定は、以前の形の「その間は何も流さない」です。この形は新しく保存できないので、流す話題を入れるか、ブラックリストにしてから保存してください。';

  @override
  String get childSafeGuardianTimeTopics => 'その間の話題';

  @override
  String get childSafeGuardianTimeAllowHint => 'その間に流す話題(語やタグを「,」で区切る)';

  @override
  String get childSafeGuardianTimeDenyHint => 'その間に流さない話題(語やタグを「,」で区切る)';

  @override
  String get childSafeGuardianTimeAllowNote =>
      'ホワイトリスト: その間は、どれかの話題に当たる投稿だけが流れます。';

  @override
  String get childSafeGuardianTimeDenyNote =>
      'ブラックリスト: その間は、当たる投稿を流しません(空 = 話題では絞りません)。';

  @override
  String get childSafeGuardianHideNotifications => '通知を隠す';

  @override
  String get childSafeGuardianHidePostDetail => '投稿の詳細を開かせない';

  @override
  String get childSafeGuardianHideDm => 'DM を隠す';

  @override
  String get childSafeGuardianRaiEnabled => 'RAi を使える';

  @override
  String get childSafeGuardianRaiComingSoon => '準備中(いまは効きません)';

  @override
  String get childSafeGuardianRaiAutomation => '関数での自動化';

  @override
  String get childSafeGuardianRaiAutomationSubtitle => 'オフなら、案内(指差し)だけで進めます';

  @override
  String get childSafeGuardianSearchSection => '検索';

  @override
  String get childSafeGuardianFeaturesSection => '機能';

  @override
  String get childSafeGuardianExamplesTitlePlugins => '例で決める(プラグイン)';

  @override
  String get childSafeGuardianExamplesTitleTl => '例で決める(クリップ / リスト)';

  @override
  String get childSafeGuardianExamplesCaptionPlugins =>
      '「こういうプラグインは許す / 止める」を例で選びます。子の端末は、プラグインの名前・説明が例に近いかで決めます。止める例に近いものは「自由」でも使えません。「例に近いもの」にすると、名前で許したものと、許す例に近いものを使えます。';

  @override
  String get childSafeGuardianExamplesCaptionTl =>
      '「こういうものは許す / 止める」を、あなたの最近のアクション / クリップ / リストから選びます。子のクリップ / リストのうち、中身が止める例に近いものは、一覧にもタイムラインにも出ません。';

  @override
  String get childSafeGuardianPickPlugins => '例を選ぶ(プラグイン / ストア)';

  @override
  String get childSafeGuardianPickTl => '例を選ぶ(最近のアクション / クリップ / リスト)';

  @override
  String childSafeGuardianPickCounts(int allow, int deny) {
    return '許す例 $allow / 止める例 $deny';
  }

  @override
  String childSafeGuardianPickTitlePlugins(String handle) {
    return 'プラグインの例(@$handle)';
  }

  @override
  String childSafeGuardianPickTitleTl(String handle) {
    return 'TL の例(@$handle)';
  }

  @override
  String get childSafeGuardianAllowLabel => '許す例';

  @override
  String get childSafeGuardianDenyLabel => '止める例';

  @override
  String get childSafeGuardianPickIntroPlugins =>
      '中身を見て、子に「許す例」/「止める例」を選びます(右 / 左スワイプでも)。子の端末は、新しいプラグインを例との近さで分けます。';

  @override
  String get childSafeGuardianPickIntroTl =>
      '中身を見て、子に「許す例」/「止める例」を選びます(右 / 左スワイプでも)。子の端末は、クリップ / リストを例との近さで分けます。';

  @override
  String get childSafeScreensBadge => '見守り中';

  @override
  String childSafeScreensWindowBanner(String window, String detail) {
    return '見守りの時間($window)です。$detail';
  }

  @override
  String get childSafeScreensWindowNothing => '投稿は流れません';

  @override
  String childSafeScreensWindowAllowOnly(String topics) {
    return '「$topics」の話題だけが流れます';
  }

  @override
  String childSafeScreensWindowDenied(String topics) {
    return '「$topics」の話題は流れません';
  }

  @override
  String get childSafeScreensBlockedHint => '見守りの設定は保護者が決めています';

  @override
  String get childSafeScreensHubTitle => 'チャイルドセーフ';

  @override
  String get childSafeScreensHubIntro =>
      '保護者が、子のアカウントの使い方を決めます。保護者に届くのは数と止めた種類だけで、投稿の本文は送りません。';

  @override
  String get childSafeScreensHubIntroDetail =>
      '保護者の RASQ アカウントが、子の RASQ アカウントの使い方を決めます。投稿の判定はこの端末の中で行い、保護者に届くのは、送った数と止めた数と、送る前に止めた種類だけです(投稿の本文や話題は送りません)。';

  @override
  String get childSafeScreensHubManagedSection => '見守られています';

  @override
  String get childSafeScreensHubParent => '保護者';

  @override
  String get childSafeScreensHubState => '状態';

  @override
  String childSafeScreensHubStateActive(int revision) {
    return '見守り中(設定 $revision)';
  }

  @override
  String get childSafeScreensHubOffline => 'いまはサーバーに届きません。前の設定のまま見守ります。';

  @override
  String get childSafeScreensHubRefresh => '保護者の設定を取り直す';

  @override
  String get childSafeScreensHubAsGuardian => '保護者として';

  @override
  String childSafeScreensHubGuardianVerified(String method) {
    return '確認済み($method)。子のアカウントを作る / つなぐ / 設定';
  }

  @override
  String get childSafeScreensHubGuardianUnverified =>
      '保護者の確認は Web コンソールで(日本はマイナンバーカード、ほかは自己申告)';

  @override
  String get childSafeScreensHubAsChild => '子として';

  @override
  String get childSafeScreensHubChildModeLogin => '保護者からのコードでログインします';

  @override
  String get childSafeScreensHubChildModePair => 'このアカウントを、保護者のコードでつなぎます';

  @override
  String get childSafeScreensHubLoginSubtitle => '保護者が作った子のアカウントに入ります';

  @override
  String get childSafeScreensHubThisDevice => 'この端末';

  @override
  String get childSafeScreensHubSafety => 'プライバシーとセーフモード';

  @override
  String get childSafeScreensHubSafetyManaged =>
      '見守り中は、閲覧注意のメディアを必ず隠します(変えられません)';

  @override
  String get childSafeScreensHubSafetyNormal => '閲覧注意メディアの扱い';

  @override
  String childSafeScreensTopicsNote(String label, String topics) {
    return '($label: $topics)';
  }

  @override
  String get childSafeScreensTopicsNone => 'なし';

  @override
  String get childSafeScreensTopicsShown => '流す話題';

  @override
  String get childSafeScreensTopicsHidden => '見せない話題';

  @override
  String get childSafeScreensTopicsSendable => '送れる話題';

  @override
  String get childSafeScreensTopicsUnsendable => '送れない話題';

  @override
  String get childSafeScreensTopicsNotShown => '流さない話題';

  @override
  String childSafeScreensSummaryTimeline(String level, String note) {
    return 'タイムライン: $level$note';
  }

  @override
  String childSafeScreensSummaryComposer(String level, String note) {
    return '投稿の判定: $level$note';
  }

  @override
  String childSafeScreensSummaryPostsPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '1 日に送れる投稿: $count 件',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryTime(String window, String note) {
    return '見守りの時間: $window$note';
  }

  @override
  String get childSafeScreensSummaryTimeNothing => '(投稿は流れません)';

  @override
  String childSafeScreensSummarySns(
    String kinds,
    String servers,
    String noAdd,
  ) {
    return '使える SNS: $kinds$servers$noAdd';
  }

  @override
  String get childSafeScreensSummaryAny => 'どれでも';

  @override
  String childSafeScreensSummarySnsServers(String servers) {
    return '($servers)';
  }

  @override
  String get childSafeScreensSummarySnsNoAdd => '、追加はできません';

  @override
  String childSafeScreensSummaryFeaturesOff(String list) {
    return '止めている機能: $list';
  }

  @override
  String childSafeScreensSummarySearchOff(String list) {
    return '止めている検索: $list';
  }

  @override
  String childSafeScreensSummaryPlugins(String scope, String install) {
    return 'プラグイン: $scope・インストールは$install';
  }

  @override
  String childSafeScreensSummaryPluginsExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '選んだ $count 個と、許す例に近いもの',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryPluginsListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '選んだ $count 個だけ',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryExamples(int allow, int deny) {
    return '例: 許す例 $allow / 止める例 $deny(止める例に近いプラグイン / クリップ / リストは出ません)';
  }

  @override
  String childSafeScreensSummaryRai(int count, String noAuto) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RAi: $count 種類の関数$noAuto',
    );
    return '$_temp0';
  }

  @override
  String get childSafeScreensSummaryRaiNoAuto => '(自動化なし)';

  @override
  String get childSafeScreensSummaryRaiOff => 'RAi: 使えません';

  @override
  String childSafeScreensFromLink(String action) {
    return 'リンク(QR)からコードを入れました。自分の保護者から受け取ったものか確かめてから「$action」を押してください。知らない人のリンクなら、押さずに閉じてください。';
  }

  @override
  String get childSafeScreensPaired => '保護者とつなぎました。保護者が設定を決めるまで待ってください';

  @override
  String get childSafeScreensPairNotLoggedIn =>
      'RASQ アカウントにログインしていません。保護者が作ったアカウントなら、保護者からのコードでログインします。';

  @override
  String get childSafeScreensPairExistingLogin => '既存の RASQ アカウントにログイン';

  @override
  String childSafeScreensPairIntro(String handle) {
    return '@$handle を保護者の見守りにつなぎます。保護者の画面に出ているコード(8 字)を入れてください。つないだら、保護者が設定を決めるまで使えません。';
  }

  @override
  String childSafeScreensPairIntroDetail(String handle) {
    return '@$handle を、保護者の見守りにつなぎます。保護者の画面(アプリか Web コンソール)に出ているコード(8 字、例 ABCD-EFGH)を入れてください。つないだら、保護者が設定を決めるまでアプリは使えません。';
  }

  @override
  String get childSafeScreensPairButton => 'つなぐ';

  @override
  String get childSafeScreensPairQrHint =>
      '保護者の画面の QR を、この端末のカメラアプリで読んでもつなげます。';

  @override
  String get childSafeScreensPairQrHintDetail =>
      '保護者の画面の QR は、この端末のカメラアプリで読むと、コードが入った状態でこの画面が開きます。リンク(rasq://child-safe/pair?code=…)を貼り付けても、つなげます。';

  @override
  String get childSafeScreensPairNoQr => 'この端末では QR を読めません。コードを入れてください。';

  @override
  String get childSafeScreensPairNoQrDetail =>
      'この端末では QR を読めません。コードを入れるか、リンク(rasq://child-safe/pair?code=…)を貼り付けてください。';

  @override
  String get childSafeScreensLoginFailed => 'ログインできませんでした';

  @override
  String childSafeScreensLoggedIn(String handle, String device) {
    return '@$handle にログインしました($device)';
  }

  @override
  String get childSafeScreensLoginIntro =>
      '保護者がアプリで子のアカウントを作ると、1 度だけ使えるコードが出ます。そのコードを入れると、この端末がそのアカウントになります。この端末の SNS アカウントは引き継ぎません。';

  @override
  String get childSafeScreensLoginCodeHint => 'ログインのコード';

  @override
  String get childSafeScreensLoginButton => 'ログイン';

  @override
  String get childSafeScreensPendingUnverifiedTitle => '保護者の設定を確かめられません';

  @override
  String get childSafeScreensPendingTitle => '保護者が設定を決めるまで待ってください';

  @override
  String get childSafeScreensPendingSignatureMismatch => '設定の署名が合いません。';

  @override
  String childSafeScreensPendingBody(String parent) {
    return '$parent と見守りでつながっています。$parent が使い方を決めると、使えるようになります。';
  }

  @override
  String get childSafeScreensPendingParent => '保護者';

  @override
  String get childSafeScreensPendingOffline => 'いまはサーバーに届きません。';

  @override
  String get childSafeScreensPendingRefresh => '更新';

  @override
  String get childSafeScreensPendingLogout => 'ログアウト';

  @override
  String get childSafeScreensPendingRasqLogin => 'RASQ アカウントにログイン';

  @override
  String get composeTargetNormalTitle => 'ノートの作成';

  @override
  String get composeTargetReplyTitle => '返信';

  @override
  String get composeTargetQuoteTitle => '引用';

  @override
  String get composeEmojiPickerTitle => '絵文字';

  @override
  String get composeEmojiPickerClose => '閉じる';

  @override
  String get composePollRemoveTooltip => '投票を削除';

  @override
  String composePollChoiceHint(int index) {
    return '回答$index';
  }

  @override
  String get composePollChoiceDeleteTooltip => '削除';

  @override
  String get composePollAddChoice => 'その他';

  @override
  String get composePollTimed => '時間指定';

  @override
  String get composePollMultiple => '複数回答';

  @override
  String get composePollUnitDays => '日';

  @override
  String get composePollUnitHours => '時間';

  @override
  String get composePollUnitMinutes => '分';

  @override
  String get composePollUnitSeconds => '秒';

  @override
  String get composeDraftsTitle => '下書き';

  @override
  String get composeDraftsCancel => 'キャンセル';

  @override
  String get composeDraftsDelete => '削除';

  @override
  String get composeDraftsSaveAndClose => '今の内容を保存して閉じる';

  @override
  String get composeDraftsOverwriteAndClose => '今の内容を上書き保存して閉じる';

  @override
  String get composeDraftsSaveNewAndClose => '今の内容を新しい下書きにして閉じる';

  @override
  String get composeDraftsEmpty => '下書きはありません';

  @override
  String composeDraftsAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添付 $count',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftsOpenNow => '開いている';

  @override
  String get composeDraftsSelectOff => '選択解除';

  @override
  String get composeDraftsSelect => '選択';

  @override
  String composeDraftsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '$_temp0';
  }

  @override
  String composeDraftTitleAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '(添付 $count 件)',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftTitleEmpty => '(本文なし)';

  @override
  String get composeDraftTargetReply => '返信';

  @override
  String get composeDraftTargetQuote => '引用';

  @override
  String get composeDraftTargetPost => '投稿';

  @override
  String get composeReactionAcceptanceAll => '全て';

  @override
  String get composeReactionAcceptanceLikeOnly => 'いいねのみ';

  @override
  String get composeReactionAcceptanceLikeOnlyForRemote => '外部からはいいね';

  @override
  String get composeReactionAcceptanceNonSensitiveOnly => '非センシティブのみ';

  @override
  String
  get composeReactionAcceptanceNonSensitiveOnlyForLocalLikeOnlyForRemote =>
      '非センシティブ&外部からはいいねのみ';

  @override
  String get composeEmojiResizeHandleSemantics => 'サイズ変更ハンドル';

  @override
  String get composeEmojiSectionHistory => '履歴';

  @override
  String get composeEmojiSectionPrediction => '予測';

  @override
  String get composeEmojiBundleEditTitle => 'バンドル編集';

  @override
  String get composeEmojiBundleEditMessage => 'バンドルの編集は準備中です。';

  @override
  String get composeEmojiSectionDefault => 'デフォルト';

  @override
  String get composeEmojiCustomEmpty => '独自の絵文字はありません';

  @override
  String get composeEmojiSectionServer => 'サーバー';

  @override
  String get composeEmojiGenreOther => 'その他';

  @override
  String composeEmojiGroupHeading(String name) {
    return '・$name';
  }

  @override
  String get composeEmojiSearchHint => '検索';

  @override
  String get composeEmojiStickersEmpty => '使えるアセットパックがありません(ストアからインストールできます)';

  @override
  String get composeEmojiSectionSearchResults => '検索結果';

  @override
  String get composeEmojiSearchNoHit => '見つかりません';

  @override
  String composeEmojiIndexProgress(int done, int total) {
    return '意味検索を準備中 $done / $total';
  }

  @override
  String get composeVisibilityHome => 'ホーム';

  @override
  String get composeVisibilityFollowers => 'フォロワー';

  @override
  String get composeVisibilityPublic => 'パブリック';

  @override
  String composeVisibilityTooltip(String label) {
    return '公開範囲: $label';
  }

  @override
  String get composeLocalOnlyOnTooltip => '連合なし(このサーバーのみ)';

  @override
  String get composeLocalOnlyOffTooltip => '連合あり(タップで連合なしに)';

  @override
  String composeReactionAcceptanceTooltip(String label) {
    return 'リアクションの受け入れ: $label';
  }

  @override
  String get composeOn => 'オン';

  @override
  String get composeOff => 'オフ';

  @override
  String composeTextPluginTooltip(String label, String state) {
    return '$label($state・長押しで設定)';
  }

  @override
  String get composeTextPluginHereTitle => 'このコンポーザーでオン';

  @override
  String get composeTextPluginHereSubtitle => '本文の変化をこのプラグインに渡します';

  @override
  String get composeTextPluginAutoTitle => '次からも自動でオン';

  @override
  String composeTextPluginAutoDefault(String state) {
    return 'プラグインの既定($state)';
  }

  @override
  String composeTextPluginAutoOverridden(String state) {
    return '設定で上書き中(既定は $state)';
  }

  @override
  String get composeTextPluginResetDefault => 'プラグインの既定に戻す';

  @override
  String composeTextPluginCaption(String name) {
    return '$name · テキスト加工';
  }

  @override
  String get composeHeaderPost => '投稿';

  @override
  String get composeHeaderReply => '返信';

  @override
  String get composeHeaderQuote => '引用';

  @override
  String get composeCloseOverwriteTitle => '下書きを上書きしますか';

  @override
  String get composeCloseSaveTitle => '下書きに保存しますか';

  @override
  String get composeCloseOverwriteMessage => '開いている下書きを今の内容で上書きして閉じます。';

  @override
  String get composeCloseSaveMessage => '今の内容を下書きに残して閉じます。';

  @override
  String get composeCloseOverwrite => '上書き';

  @override
  String get composeCloseSaveNew => '新規保存';

  @override
  String get composeCloseSave => '保存';

  @override
  String get composeCloseDiscard => '変更を破棄';

  @override
  String get composeCancel => 'キャンセル';

  @override
  String get composeMultiNormal => '通常投稿';

  @override
  String get composeMultiLinked => 'ノード連動';

  @override
  String get composeRasqTarget => 'RASQ に投稿';

  @override
  String get composeTargetMatchedTooltip => 'ポスト先ノードの条件に一致';

  @override
  String get composeTargetCustomize => '投稿先のカスタマイズ';

  @override
  String get composeMultiSelectOff => '複数選択を解除';

  @override
  String get composeMultiSelectOn => '複数選択モード';

  @override
  String get composeLinkedConfirmTitle => '連動投稿の確認';

  @override
  String get composeLinkedConfirmSame => '同内容で連動投稿';

  @override
  String get composeLinkedConfirmAlt => '代わりのフォーマットで連動投稿';

  @override
  String get composeLinkedConfirmPost => 'この内容で投稿する';

  @override
  String get composeRasqNoServer => 'RASQ のサーバーが設定されていません';

  @override
  String get composeRasqOverLimit => 'RASQ の上限を超えています';

  @override
  String get composeRasqTextOnlyTip => 'RASQ の返信は文字だけです';

  @override
  String composePickImageFailed(String error) {
    return '画像を選択できませんでした: $error';
  }

  @override
  String get composePickVideoLibrary => 'ライブラリの動画';

  @override
  String get composePickVideoFile => 'ファイルから(動画 / 音声)';

  @override
  String composePickNotMedia(String name) {
    return '動画 / 音声のファイルではありません: $name';
  }

  @override
  String composePickMediaFailed(String error) {
    return '動画 / 音声を選択できませんでした: $error';
  }

  @override
  String get composeRasqNotLoggedIn => 'RASQ アカウントにログインしていません';

  @override
  String composeRasqMediaTooLarge(int mb) {
    return 'RASQ への投稿では、動画 / 音声は 1 つ $mb MB までです';
  }

  @override
  String get composeRasqReplyTextOnly => 'RASQ の返信は、文字だけです(添付 / 投票は付けられません)';

  @override
  String composeRasqReplyMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ の返信は $count 文字までです',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ への投稿は、添付 $count つまでです',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ への投稿は $count 文字までです',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxPollChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ への投稿は、投票の選択肢 $count 個までです',
    );
    return '$_temp0';
  }

  @override
  String get composeRasqPosted => 'RASQ に投稿しました';

  @override
  String get composeRasqReplyQuota => 'RASQ の返信は 100 件までです。古い返信を消してください';

  @override
  String get composeRasqPostQuota => 'RASQ への投稿は 3 件までです。古い投稿を消してください';

  @override
  String composeRasqPostFailed(String error) {
    return 'RASQ に投稿できませんでした: $error';
  }

  @override
  String get composePolicyConfirmTitle => '送る前の確認';

  @override
  String get composePolicyConfirmSend => 'このまま送る';

  @override
  String get composePolicyConfirmEdit => '書き直す';

  @override
  String get composeSending => '送信中…';

  @override
  String composeModerationDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '検閲による遅延: あと $seconds 秒',
    );
    return '$_temp0';
  }

  @override
  String composeUploading(int index, int total) {
    return 'アップロード中 $index/$total';
  }

  @override
  String composeLinkedFailed(String errors) {
    return '連動投稿に失敗しました: $errors(本体は投稿済みです)';
  }

  @override
  String composeSendFailed(String error) {
    return '送信に失敗しました: $error';
  }

  @override
  String composePostNoticeForAccount(String account, String message) {
    return '$account: $message';
  }

  @override
  String get composeDraftsButton => '下書き';

  @override
  String get composeDirectReplyNote => 'ダイレクト投稿への返信(相手にだけ届きます)';

  @override
  String get composeChooseTargetTooltip => '投稿先を選ぶ';

  @override
  String get composeCwHint => '注釈..';

  @override
  String get composeCwRemoveTooltip => '注釈を外す';

  @override
  String get composeDmHint => 'メッセージを入力..';

  @override
  String get composeTextHint => 'いいことがありますように！';

  @override
  String composeHashtagUsers(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag  $count人',
    );
    return '$_temp0';
  }

  @override
  String get composeToolCamera => 'カメラ';

  @override
  String get composeToolImage => '画像';

  @override
  String get composeToolVideo => '動画 / 音声';

  @override
  String get composeToolCw => '隠す(注釈)';

  @override
  String get composeToolPoll => '投票';

  @override
  String get composeToolEmoji => '絵文字';

  @override
  String get composeSendReply => '返信';

  @override
  String get composeSend => '送信';

  @override
  String get composeAttachmentRemove => '削除';

  @override
  String get composeAttachmentEdit => '加工';

  @override
  String get composeAttachmentUnsensitive => 'センシティブ解除';

  @override
  String get composeAttachmentSensitive => 'センシティブにする';

  @override
  String get composeMediaPickTypeLabel => '動画 / 音声';

  @override
  String get composeMediaMotionVideoLabel => '動画にする(付いている動画を、タイルの中で再生。音つき)';

  @override
  String get composeMediaMotionAudioLabel => '動画にする(タイルの静止画 + 付いている音声)';

  @override
  String composeMediaMotionAnimatedLabel(int fps, int seconds) {
    return '動画にする(動いている様子を $fps コマ/秒で $seconds 秒)';
  }

  @override
  String get composeMediaMotionVideoNote => 'この投稿には動画が付いています。';

  @override
  String get composeMediaMotionAudioNote => 'この投稿には音声が付いています。';

  @override
  String get composeMediaMotionAnimatedNote => 'この投稿には動く絵(GIF / 動く MFM)があります。';

  @override
  String get composeMediaPostNotOnScreen => '投稿が画面に出ていません';

  @override
  String get composeMediaSourceFetchFailed => '元のファイルを取得できませんでした';

  @override
  String composeMediaFormatUnreadable(String ext) {
    return 'この端末は $ext 形式を読めません(静止画なら貼れます)';
  }

  @override
  String composeMediaSourceOpenFailed(String ext, int bytes) {
    return '元のファイル(.$ext、$bytes バイト)を開けませんでした';
  }

  @override
  String get composeMediaTabMine => '自分の投稿';

  @override
  String get composeMediaTabReacted => 'リアクション';

  @override
  String get composeMediaTabFavorites => 'ブックマーク';

  @override
  String get composeMediaTabSearches => '最近の検索';

  @override
  String get composeMediaStyleThread => 'スレッド';

  @override
  String get composeMediaStyleInline => 'インライン';

  @override
  String get composeMediaPostImageTitle => 'ノート画像の追加';

  @override
  String get composeMediaCancel => 'キャンセル';

  @override
  String get composeMediaConfirm => '決定';

  @override
  String get composeMediaNoAccount => 'アカウントがありません';

  @override
  String get composeMediaSearchUnsupported => 'この SNS では投稿の検索が使えません';

  @override
  String composeMediaTabUnsupported(String tab) {
    return 'この SNS では「$tab」が使えません';
  }

  @override
  String composeMediaFetchFailed(String error) {
    return '取得できませんでした: $error';
  }

  @override
  String get composeMediaCaptureRetry => '選んだ投稿が画面に出ている状態で、もう一度「決定」を押してください';

  @override
  String composeMediaVideoFailed(String error) {
    return '動画にできませんでした: $error';
  }

  @override
  String get composeMediaFilterHistoryHint => '検索の履歴を絞り込む';

  @override
  String get composeMediaFilterListHint => '一覧を絞り込む';

  @override
  String get composeMediaFilterFromHistoryTooltip => '最近の検索から入れる';

  @override
  String get composeMediaStyleHeading => '見た目';

  @override
  String composeMediaSearchResultsTitle(String query) {
    return '「$query」の検索結果';
  }

  @override
  String get composeMediaSearchBack => '最近の検索に戻る';

  @override
  String composeMediaExcludedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '公開範囲を限った投稿 $count 件は出していません。',
    );
    return '$_temp0';
  }

  @override
  String get composeMediaAsVideoOffNote => 'オフ = その瞬間の静止画';

  @override
  String get composeMediaExporting => '動画にしています…';

  @override
  String get composeMediaHistoryEmpty => '最近の検索はありません(検索ホームで検索すると、ここに並びます)';

  @override
  String get composeMediaHistoryNoMatch => '当てはまる検索はありません';

  @override
  String get composeMediaPostsEmpty => '投稿はありません';

  @override
  String get composeMediaPostsNoMatch => '当てはまる投稿はありません(「もっと読む」で続きも探せます)';

  @override
  String get composeMediaLoadMore => 'もっと読む';

  @override
  String get composeMfmFnX2 => '2倍に拡大';

  @override
  String get composeMfmFnX3 => '3倍に拡大';

  @override
  String get composeMfmFnX4 => '4倍に拡大';

  @override
  String get composeMfmFnSmall => '小さく表示';

  @override
  String get composeMfmFnCenter => '中央寄せ';

  @override
  String get composeMfmFnBlur => 'ぼかし(ホバー/タップで解除)';

  @override
  String get composeMfmFnRotate => '回転';

  @override
  String get composeMfmPropRotateDeg => '角度(既定 90)';

  @override
  String get composeMfmFnFlip => '反転';

  @override
  String get composeMfmPropFlipH => '左右';

  @override
  String get composeMfmPropFlipV => '上下';

  @override
  String get composeMfmFnFg => '文字色';

  @override
  String get composeMfmPropFgColor => '16進(例: ff0000)';

  @override
  String get composeMfmFnBg => '背景色';

  @override
  String get composeMfmPropBgColor => '16進(例: ffff00)';

  @override
  String get composeMfmFnShake => '振動';

  @override
  String get composeMfmPropShakeSpeed => '例: 0.5s';

  @override
  String get composeMfmFnSpin => '回転アニメ';

  @override
  String get composeMfmPropSpinSpeed => '例: 1.5s';

  @override
  String get composeMfmPropSpinLeft => '逆回転';

  @override
  String get composeMfmPropSpinAlternate => '往復';

  @override
  String get composeMfmPropSpinX => '横軸';

  @override
  String get composeMfmPropSpinY => '縦軸';

  @override
  String get composeMfmFnJump => 'ジャンプ';

  @override
  String get composeMfmPropJumpSpeed => '例: 0.75s';

  @override
  String get composeMfmFnBounce => 'バウンド';

  @override
  String get composeMfmPropBounceSpeed => '例: 0.75s';

  @override
  String get composeMfmFnRainbow => '虹色';

  @override
  String get composeMfmPropRainbowSpeed => '例: 1s';

  @override
  String get composeMfmFnTwitch => 'ぴくぴく';

  @override
  String get composeMfmPropTwitchSpeed => '例: 0.5s';

  @override
  String get composeMfmFnJelly => 'ぷるぷる';

  @override
  String get composeMfmPropJellySpeed => '例: 1s';

  @override
  String get composeMfmFnTada => 'じゃーん';

  @override
  String get composeMfmPropTadaSpeed => '例: 1s';

  @override
  String get composeMfmFnPlain => '装飾を無効化';

  @override
  String get composeMfmMarkdownBoldName => '太字';

  @override
  String get composeMfmMarkdownBoldDescription => '**強調** で表示';

  @override
  String get composeMfmMarkdownItalicName => '斜体';

  @override
  String get composeMfmMarkdownItalicDescription => '*斜体* で表示';

  @override
  String get composeMfmMarkdownStrikeName => '取り消し線';

  @override
  String get composeMfmMarkdownStrikeDescription => '~~取り消し~~ で表示';

  @override
  String get composeMfmMarkdownInlineCodeName => 'インラインコード';

  @override
  String get composeMfmMarkdownInlineCodeDescription => '`コード` で表示';

  @override
  String get composeMfmMarkdownCodeBlockName => 'コードブロック';

  @override
  String get composeMfmMarkdownCodeBlockDescription => '複数行のコードを枠で表示';

  @override
  String get composeMfmMarkdownHeadingName => '見出し';

  @override
  String get composeMfmMarkdownHeadingDescription => '行頭に # を付ける';

  @override
  String get composeMfmMarkdownLinkName => 'リンク';

  @override
  String get composeMfmMarkdownLinkDescription => '[表示名](URL) の形';

  @override
  String get composeMfmClose => '閉じる';

  @override
  String get composeMfmSample => 'サンプル';

  @override
  String composeMfmSampleWithEmoji(String emoji) {
    return 'サンプル $emoji';
  }

  @override
  String get composeMfmBackTooltip => '一覧へ戻る';

  @override
  String get composeMfmApply => '決定';

  @override
  String get composeMfmNoProps => 'この関数にプロパティーはありません。';

  @override
  String get composePolicyTypeSexual => '性的な表現';

  @override
  String get composePolicyTypeViolence => '暴力・脅し';

  @override
  String get composePolicyTypeSelfHarm => '自傷・自殺';

  @override
  String get composePolicyTypeHarassment => '暴言・嫌がらせ';

  @override
  String get composePolicyTypePersonalInfo => '個人情報(電話番号・メールアドレス・住所など)';

  @override
  String get composePolicyTypeLink => '外部へのリンク';

  @override
  String get composePolicyTypeMedia => '画像・動画';

  @override
  String get composePolicyTypeStimulus => '強い言葉';

  @override
  String get composePolicyTypeTopic => '決められた話題';

  @override
  String get composePolicyWhoGuardian => '保護者の設定';

  @override
  String get composePolicyWhoSanction => 'アカウントの制限';

  @override
  String composePolicyBlockedMediaUnmeasured(String who) {
    return '$whoにより、画像・動画は送れません(この端末では添付の確認ができません)。添付を外してください';
  }

  @override
  String composePolicyBlockedUnmeasured(String who, String label) {
    return '$whoにより、いまは送れません(この端末では「$label」の確認ができません)';
  }

  @override
  String composePolicyBlocked(String who, String label) {
    return '$whoにより、「$label」に当たる内容は送れません。書き換えてください';
  }

  @override
  String composePolicyWarn(String label, String who) {
    return '「$label」に当たるかもしれません($who)。このまま送りますか?';
  }

  @override
  String customShareAddToRoom(String room) {
    return '「$room」に追加';
  }

  @override
  String customShareProposeToRoom(String room) {
    return '「$room」で提案';
  }

  @override
  String get customSharePlaceOnProfile => 'プロフィールに置く';

  @override
  String get customShareInviteBySwing => 'Swing で招待(みんなで使う)';

  @override
  String get customShareInstallToShare => 'インストールするとプロフィールや招待で共有できます';

  @override
  String customAddedToRoom(String name) {
    return '「$name」をルームに追加しました';
  }

  @override
  String customAddToRoomFailed(String error) {
    return '追加できませんでした: $error';
  }

  @override
  String customShareProposedToRoom(String name) {
    return '「$name」をルームで提案しました';
  }

  @override
  String get customSharePlacedOnProfile => 'プロフィールに置きました';

  @override
  String customPlaceFailed(String error) {
    return '置けませんでした: $error';
  }

  @override
  String customInvitedBySwingNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return 'Swing で招待しました(RASQ の通知 $_temp0)';
  }

  @override
  String get customInvitedBySwing => 'Swing で招待しました';

  @override
  String get customInviteTitle => 'Swing で招待';

  @override
  String customInviteSendFailed(String error) {
    return '送れませんでした: $error';
  }

  @override
  String customInviteHeading(String title) {
    return '「$title」に招待';
  }

  @override
  String get customInviteIntroOwnPage => 'Swing で届けます。見た人は、あなたのページに一緒に入ります。';

  @override
  String get customInviteIntroCurrentPage =>
      'Swing で届けます。見た人は、いま開いているページに一緒に入ります。';

  @override
  String get customInviteHelp =>
      '届け先: 押す = Swing を届ける ・ 2 回続けて押す = RASQ の通知でも知らせる 🔔';

  @override
  String get customInviteFollowers => 'フォロワー';

  @override
  String get customInviteNoLists => 'RASQ リストを作ると、リストに入れた人も招待できます';

  @override
  String get customInviteTextHint => 'ひとこと(なくてもよい)';

  @override
  String get customInviteTtl => '消えるまで';

  @override
  String customInviteTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 時間',
    );
    return '$_temp0';
  }

  @override
  String get customInviteSendWithNotify => 'Swing で招待(通知も送る)';

  @override
  String get customInviteErrorVersionNotAvailable =>
      'このプラグインは、つないでいる RASQ サーバーのストアで配られていません(審査を通った版がありません)。アプリに入っているサンプルのままでは、みんなで使えません';

  @override
  String get customInviteErrorNotShared => 'みんなで使うプラグインではありません';

  @override
  String get customInviteErrorSessionNotShareable =>
      'このページのセッションは Swing では招待できません';

  @override
  String get customInviteErrorSwingLimit => '同時に出しておける Swing は 20 個までです';

  @override
  String customInviteTargetWithNotify(String label) {
    return '$label(通知も送る)';
  }

  @override
  String get customInviteTargetHint => '押すと選ぶ / 外す。2 回続けて押すと、通知も送る';

  @override
  String get customProfileLimit => 'ページに置けるのは 8 個までです';

  @override
  String get customProfileSideloadReplace => '上げ直す(新しい版)';

  @override
  String get customProfileSideloadRemove => 'ページから外す';

  @override
  String customProfileRemoveFailed(String error) {
    return '外せませんでした: $error';
  }

  @override
  String customLoadFailed(String error) {
    return '読み込めませんでした: $error';
  }

  @override
  String get customProfileEmptyMine =>
      '「+ 追加」で Markdown のページや、カスタムプラグインを置けます。訪れた人がここから開けます。';

  @override
  String get customProfileEmpty => 'ページはまだありません。';

  @override
  String get customProfileSharedNotStarted => 'みんなで使う(まだ始まっていません)';

  @override
  String get customProfileShared => 'みんなで使う';

  @override
  String get customSolo => '1 人で使う';

  @override
  String customProfileHostPage(String title) {
    return '$title のホスト用ページ';
  }

  @override
  String get customProfileHostPageSubtitle => 'あなたにだけ出ます';

  @override
  String get customProfileMdPageWithDraft => 'ページ ・ 書きかけの下書きあり';

  @override
  String get customProfileMdPage => 'ページ';

  @override
  String get customProfileUntitled => '(無題)';

  @override
  String get customProfileDraft => '下書き(この端末だけ)';

  @override
  String customProfileSideloadSubtitle(String version) {
    return '自作プラグイン ・ 制限モード ・ v$version';
  }

  @override
  String get customMenu => 'メニュー';

  @override
  String get customProfileAdd => '追加';

  @override
  String get customProfileLoginToPlace => 'RASQ アカウントにログインすると置けます';

  @override
  String customProfileSideloadPlaced(String name) {
    return '「$name」を置きました(訪れた人の端末では制限モードで動きます)';
  }

  @override
  String get customProfileSideloadErrorNotProfilePage =>
      'RASQ のページに置けるのは、プロフィールの面を持つ 1 人で使うページ型だけです';

  @override
  String get customProfileSideloadErrorLimit => '自作プラグインは 4 つまでです';

  @override
  String get customProfileSideloadErrorInvalidPackage =>
      '配布物を読めませんでした(.rspkg / .rasqpkg)';

  @override
  String get customClose => '閉じる';

  @override
  String get customProfileAddTitle => 'ページを追加';

  @override
  String get customProfileAddMd => 'Markdown のページを書く';

  @override
  String get customProfileAddMdSubtitle =>
      '下書きはこの端末に残し、「公開」で出します。MFM は HTML 風のタグで';

  @override
  String get customProfileAddSideload => '自作プラグインを置く(.rspkg / .rasqpkg)';

  @override
  String get customProfileAddSideloadSubtitle =>
      '審査していないプラグイン。訪れた人の端末では制限モード(通信などなし)で動きます';

  @override
  String get customProfileAddStoreSection => 'ストアのカスタムプラグイン';

  @override
  String get customProfileAddStoreEmpty => 'ページに置けるカスタムプラグインを入れていません';

  @override
  String get customProfileAddStorePlaced => '置いています(押すと外す)';

  @override
  String get customProfileAddStoreTapToPlace => '押すと置く';

  @override
  String get customProfileAddStoreHasHostPage => 'ホスト用ページあり';

  @override
  String get customListSeparator => ' ・ ';

  @override
  String customProfileChangeFailed(String error) {
    return '変えられませんでした: $error';
  }

  @override
  String get customSearchStore => 'ストアで探す';

  @override
  String get customPluginsTitle => 'カスタムプラグイン';

  @override
  String get customPluginsJoinByCode => '招待コードで参加';

  @override
  String get customPluginsInviteCode => '招待コード';

  @override
  String get customPluginsJoin => '参加';

  @override
  String get customPluginsInstalled => 'インストール済み';

  @override
  String get customPluginsEmpty => 'まだありません。ストアの「カスタム」から探せます。';

  @override
  String get customPluginsShared => 'みんなで使える';

  @override
  String get customPluginsProfile => 'プロフィール';

  @override
  String get customPluginsSearchStore => 'ストアでカスタムプラグインを探す';

  @override
  String get customPluginsInviteNotFound =>
      'この招待コードのセッションは見つかりません(閉じられたかもしれません)';

  @override
  String get customPluginsInviteTitle => '招待';

  @override
  String get customPluginsJoinFailed => '参加できませんでした';

  @override
  String get customPageLoadFailed => '読み込めませんでした';

  @override
  String customPageNotPagePlugin(String name) {
    return '$name はページ型のプラグインではありません';
  }

  @override
  String customPageSoloPlugin(String name) {
    return '$name は 1 人で使うプラグインです(みんなでは使えません)';
  }

  @override
  String customPageJoinFailed(String error) {
    return 'セッションに入れませんでした: $error';
  }

  @override
  String get customPageNoPage => 'プラグインがページを返しませんでした';

  @override
  String customPageWrongSession(String name) {
    return '$name のセッションではありません';
  }

  @override
  String customPageLeftWrongSession(String name) {
    return '$name のセッションではないため抜けました';
  }

  @override
  String customPageDisconnectedWithError(String error) {
    return '接続が切れました: $error';
  }

  @override
  String get customPageDisconnected => '接続が切れました';

  @override
  String get customPageError => 'エラー';

  @override
  String get customPageMenuInvite => '招待(Swing で送る)';

  @override
  String get customPageMenuCopyCode => '招待コードをコピー';

  @override
  String get customPageMenuCopyLink => '招待リンクをコピー';

  @override
  String customPageMenuParticipants(int count) {
    return '参加者($count)';
  }

  @override
  String get customPageMenuCloseSession => 'セッションを閉じる';

  @override
  String get customPageViewInStore => 'ストアで見る';

  @override
  String customPageCodeCopied(String code) {
    return '招待コード $code をコピーしました';
  }

  @override
  String get customPageLinkCopied => '招待リンクをコピーしました';

  @override
  String get customPageParticipants => '参加者';

  @override
  String get customPageCloseConfirmTitle => 'セッションを閉じますか?';

  @override
  String get customPageCloseConfirmMessage => '参加している全員のページで、共有の値が止まります。';

  @override
  String get customCancel => 'キャンセル';

  @override
  String customPageCloseFailed(String error) {
    return '閉じられませんでした: $error';
  }

  @override
  String get customPageClosedBanner => 'このセッションは閉じられました(共有の値はもう変わりません)';

  @override
  String get customPageConsentBody =>
      'このページを開いている間だけ、インストールせずに動かします(閉じると消えます)。';

  @override
  String get customPageConsentPermissions => '使う権限';

  @override
  String get customPageConsentAccept => '使う';

  @override
  String get customPageConsentDecline => 'やめる';

  @override
  String get customPageNotInstalled => 'インストールされていません';

  @override
  String get customPageNotInstalledHint => 'ストアからインストールすると開けます';

  @override
  String get customPageOpenFailed => '開けませんでした';

  @override
  String get customClientHostOnly => 'ホストだけがデプロイできます';

  @override
  String get customClientSessionClosed => 'セッションが閉じています';

  @override
  String get customClientNoToken => 'RASQ アカウントのトークンがありません';

  @override
  String customAstellWaitingApproval(String name) {
    return '「$name」はホストの承認を待っています';
  }

  @override
  String customAstellApproveTitle(String name) {
    return '「$name」をこのルームで使いますか?';
  }

  @override
  String customAstellApproveMessage(String name) {
    return '$name さんからの提案です。承認すると、参加している全員が開けるようになります(インストールしていない人は、開くときに一時的に読み込みます)。';
  }

  @override
  String get customAstellApprove => '承認する';

  @override
  String customAstellProposed(String name) {
    return '「$name」を提案しました(ホストが承認すると使えます)';
  }

  @override
  String get customAstellEmptyHost =>
      'このルームで動くプラグインはまだありません。下の「プラグインを追加」から足せます。';

  @override
  String get customAstellEmptyMember =>
      'このルームで動くプラグインはまだありません。「プラグインを提案」でホストに頼めます。';

  @override
  String customAstellInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人が使用中',
    );
    return '$_temp0';
  }

  @override
  String customAstellInUseAddedBy(int count, String handle) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人が使用中',
    );
    return '$_temp0 ・ @$handle が追加';
  }

  @override
  String get customAstellOpen => '開く';

  @override
  String get customAstellRemove => 'ルームから外す';

  @override
  String get customAstellAdd => 'プラグインを追加';

  @override
  String get customAstellPropose => 'プラグインを提案';

  @override
  String get homeCreateMissingAccount => '(いないアカウント)';

  @override
  String get homeCreatePost => '投稿';

  @override
  String get homeCreateNone => 'なし';

  @override
  String homeCreateNeedsRasqAccount(String label) {
    return '$labelには RASQ アカウントが要ります';
  }

  @override
  String get homeCreateAstellBlocked => '見守りの設定で ASTell が止められています';

  @override
  String get homeCreateAccountGone => 'このアカウントはもうありません';

  @override
  String get homeCreate => '作成';

  @override
  String get homeClose => '閉じる';

  @override
  String get homeFabEditorTitle => '＋ のボタン';

  @override
  String homeFabEditorHelp(int count, int max) {
    return '下のボタンを枠へドラッグすると入ります(枠どうしは入れ替え、下の列へ戻すと外れます)。内側に 3 つ、外側に 4 つまで ・ $count / $max';
  }

  @override
  String get homeHeaderCollapse => 'ヘッダーをしまう';

  @override
  String get homeTimelineTemp => 'タイムラインを一時変更';

  @override
  String get homeTimelineSettings => 'タイムライン設定';

  @override
  String get homeTabRecommended => 'おすすめ';

  @override
  String get homeEmpty => '投稿はありません';

  @override
  String get homePullToRefresh => '下に引っ張って更新';

  @override
  String get homeLoadNewer => '新しい投稿を読み込む';

  @override
  String get homeLoadingNewer => '更新しています…';

  @override
  String get homeLoadMoreFailed => '読み込みに失敗しました。再試行';

  @override
  String get homeLoadMore => '続きを読み込む';

  @override
  String get homeLoadingMore => '読み込んでいます…';

  @override
  String get homeReload => '再読み込み';

  @override
  String homeSwingOf(String name) {
    return '$name の Swing';
  }

  @override
  String homeSwingOfSeen(String name) {
    return '$name の Swing(見終えました)';
  }

  @override
  String homeMySwingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個',
    );
    return '自分の Swing($_temp0)';
  }

  @override
  String get homeMySwing => '自分の Swing';

  @override
  String get homeLiveNoToken => 'RASQ アカウントのトークンがありません';

  @override
  String homePostAttachmentFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の添付ファイル',
    );
    return '$_temp0';
  }

  @override
  String get homePostAttachmentLink => '1件の添付リンク';

  @override
  String get homePostShare => '共有';

  @override
  String get homePostSelectAccount => 'アカウント選択';

  @override
  String get homePostLike => 'いいね';

  @override
  String get homePostReaction => 'リアクション';

  @override
  String homePostRepostVia(String handle, String instance) {
    return '(@$handle@$instance で)';
  }

  @override
  String get homePostUndoRepost => 'リノートを取り消す';

  @override
  String homePostCw(String cw) {
    return '【CW: $cw】';
  }

  @override
  String homePostAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の添付',
    );
    return '$_temp0';
  }

  @override
  String get homeActionReply => '返信';

  @override
  String get homeActionRebroad => 'リブロード';

  @override
  String get homeActionQueue => 'キュー';

  @override
  String get homeEditorCropRotate => 'クロップ / 回転';

  @override
  String get homeEditorPaint => 'ペイント';

  @override
  String get homeEditorText => 'テキスト';

  @override
  String get homeEditorPost => 'ノート';

  @override
  String get homeEditorMedia => 'メディア';

  @override
  String get homeEditorSticker => 'ステッカー';

  @override
  String get homeEditorEmoji => '絵文字';

  @override
  String get homeEditorFilter => 'フィルター';

  @override
  String get homeEditorBlur => 'ぼかし';

  @override
  String get homeEditorTune => '調整';

  @override
  String get homeActionAutoOn => '次からも自動でオン';

  @override
  String get homeActionAutoOff => '次からも自動でオフ';

  @override
  String get homeActionAutoReset => 'プラグインの既定に戻す';

  @override
  String get homeChildSafeWindowTab => '見守りの時間';

  @override
  String get homeCancel => 'キャンセル';

  @override
  String get homeBarPost => '投稿アクションバー';

  @override
  String get homeBarViewer => '全画面アクションバー';

  @override
  String get homeBarEditorImage => '加工画面のバー(画像)';

  @override
  String get homeBarEditorVideo => '加工画面のバー(動画 / 音声)';

  @override
  String get homeBarEditorSvg => '加工画面のバー(SVG)';

  @override
  String get homeBarRasqViewer => '全画面アクションバー(Swing)';

  @override
  String get homeBarAstell => 'ASTell のルームの下段';

  @override
  String get homeBarEditAstellTitle => 'ルームのボタンの編集';

  @override
  String get homeBarEditTitle => 'アクションバーの編集';

  @override
  String get homeBarSearchPlugins => 'プラグインを検索';

  @override
  String get homeBarSearchPluginButtons => 'プラグインボタンを検索';

  @override
  String homeBarSearchSubtitle(String source, String detail) {
    return '$source · $detail';
  }

  @override
  String get homeBarBuiltinEditor => '内蔵の編集';

  @override
  String get homeBarRasqActions => 'RASQ のアクション';

  @override
  String get homeBarAstellButtons => 'ASTell のボタン';

  @override
  String get homeBarSnsActions => 'SNS のアクション';

  @override
  String get homeBarViewerTogglePlugin => '全画面表示プラグイン(ON / OFF のボタン)';

  @override
  String get homeBarAstellPlugin => 'ASTell プラグイン(押すとそのプラグインを開く)';

  @override
  String homeBarPluginTags(String tags) {
    return 'タグ: $tags';
  }

  @override
  String get homeBarManualPlacement => ' · 手動配置';

  @override
  String get homeBarAllGenres => 'すべて';

  @override
  String get homeBarSearchHint => 'ボタン名 / プラグイン名 / タグ';

  @override
  String get homeBarSearchEmptyAstell => '追加できるボタンがありません。プラグインはストアから追加できます';

  @override
  String get homeBarSearchEmpty => 'ここに置けるプラグインがありません。ストアから追加できます';

  @override
  String get homeBarSearchEmptyEditorDetail =>
      'composer.media を宣言したプラグインがありません(ストアから追加)';

  @override
  String get homeBarSearchEmptyAstellDetail =>
      '非表示にしたボタン / ASTell のプラグイン(astell.action)がありません(プラグインはストアから追加)';

  @override
  String get homeBarSearchEmptyViewerDetail =>
      '全画面表示プラグイン / post.action を宣言したプラグインがありません(ストアから追加)';

  @override
  String get homeBarSearchEmptyPostDetail =>
      'post.action を宣言したプラグインがありません(ストアから追加)';

  @override
  String get homeBarSearchNoHits => '見つかりません';

  @override
  String get homeBarDetailTitle => 'アクションの詳細';

  @override
  String get homeBarDetailUnknownDeveloper => '提供元不明';

  @override
  String homeBarDetailStats(String rating, int downloads) {
    return '★$rating ・ $downloads DL';
  }

  @override
  String get homeBarDetailAction => 'アクション';

  @override
  String get homeBarDetailSlot => 'スロット(ジャンル)';

  @override
  String get homeBarDetailConfirm => '確認';

  @override
  String get homeBarDetailAutomation => '自動化';

  @override
  String get homeBarDetailTags => 'タグ';

  @override
  String get homeBarIconSearchHint => 'アイコン名で検索(例: star, bolt)';

  @override
  String get homeBarBundleTitle => 'バンドルの設定';

  @override
  String get homeBarBundleDissolved => '解除しました';

  @override
  String get homeBarPlugin => 'プラグイン';

  @override
  String homeBarBundleAstellMember(String label) {
    return 'ルームの下段のボタン($label)';
  }

  @override
  String homeBarBundleSnsMember(String genre) {
    return 'SNS プラグインが提供するアクション($genre)';
  }

  @override
  String get homeBarBundleName => 'リスト名';

  @override
  String get homeBarBundleIcon => 'アイコン';

  @override
  String get homeBarBundlePhoto => '写真';

  @override
  String get homeBarBundlePhotoFailed => '写真を使えません';

  @override
  String get homeBarBundleMembers => 'メンバー';

  @override
  String get homeBarMenuDetail => '詳細';

  @override
  String get homeBarBundleRemoveMember => 'バンドルから外す';

  @override
  String get homeBarDissolveList => 'リストの解除';

  @override
  String get homeBarMemberMenu => 'メンバーの操作';

  @override
  String get homeBarRasqAccount => 'RASQ アカウント';

  @override
  String get homeBarHelpAstell =>
      '(…) か右クリックでメニュー。長押しで並び替え、ほかのアイコンに重ねるとまとめます。(+) でボタンを追加。';

  @override
  String get homeBarHelp => '(…) か右クリックでメニュー。長押しで並び替え、ほかのアイコンに重ねるとまとめます。';

  @override
  String get homeBarHelpAstellDetail =>
      '(…) / shift + クリック / 右クリックでメニュー(非表示 / バンドル)。長押しして動かすと並び替え、別のアイコンの上で離すとバンドル。(+) で非表示にしたボタンや ASTell のプラグインを足す。幅に収まらないときは、先頭から入るだけと最後の 1 つ(入力欄の隣)を出し、残りはルームの歯車のメニューへ。';

  @override
  String get homeBarHelpDetail =>
      '(…) / shift + クリック / 右クリックでメニュー。長押しして動かすと並び替え、別のアイコンの上で離すとバンドル。宣言されたプラグインボタンと束ねる閾値は 設定 → SNSプラグイン →「プラグインボタン」。';

  @override
  String get homeBarRasqBuiltinEditor => 'RASQ(内蔵の編集)';

  @override
  String get homeBarNewBundleName => 'マイリスト';

  @override
  String get homeBarMenuMakeList => 'アクションリスト化';

  @override
  String get homeBarMenuHide => '非表示にする';

  @override
  String get homeBarMenuDelete => '削除';

  @override
  String get homeBarMenuListSettings => 'アクションリストの設定';

  @override
  String get homeBarMenuPinList => '固定リストにする';

  @override
  String get homeBarAddButton => 'ボタンを追加';

  @override
  String get homeBarNoHidden => '非表示のボタンはありません';

  @override
  String get homeBarHiddenLabel => '非表示(押すと表示):';

  @override
  String homeBarShowHidden(String label) {
    return '$label を表示';
  }

  @override
  String get homeBarResetOrder => '既定の並びに戻す';

  @override
  String get languageSelfName => '日本語';

  @override
  String get languageSettingsTitle => '言語';

  @override
  String get languageSettingsRowSubtitle => 'アプリの表示の言語';

  @override
  String get languageSettingsCaption =>
      'アプリの文字の言語を選びます。端末の言語に対応していないときは日本語で表示します。';

  @override
  String get languageSettingsCaptionDetail =>
      'アプリの文字の言語を選びます。「システムに合わせる」は端末の言語の設定に従い、対応していない言語なら日本語にします。選んだ言語はこの端末に保存し、RASQ アカウントにログインしていれば ORGATE にも伝えます(メールや通知の言語、D-484)。';

  @override
  String get languageSettingsSystem => 'システムに合わせる';

  @override
  String languageSettingsSystemCurrent(String language) {
    return 'いまは $language';
  }

  @override
  String get languageSettingsListHeader => '表示の言語';

  @override
  String get nodeprogCatalogGenreGenerate => '生成';

  @override
  String get nodeprogCatalogGenreConvert => '変換';

  @override
  String get nodeprogCatalogGenreInput => '入力';

  @override
  String get nodeprogCatalogGenreTimeline => 'タイムライン';

  @override
  String get nodeprogCatalogGenreProcess => '加工';

  @override
  String get nodeprogCatalogGenreCondition => '条件';

  @override
  String get nodeprogCatalogGenreFunction => '関数';

  @override
  String get nodeprogCatalogGenreFetch => '取得';

  @override
  String get nodeprogCatalogGenreComposer => 'コンポーザー';

  @override
  String get nodeprogCatalogGenreStorage => '保存';

  @override
  String get nodeprogCatalogClockTitle => 'クロックメーカー';

  @override
  String get nodeprogCatalogClockDescription =>
      '一定間隔でクロックを出します。TL の自動更新などのトリガーに使います。';

  @override
  String get nodeprogCatalogTextConstTitle => 'テキスト';

  @override
  String get nodeprogCatalogTextConstDescription =>
      '書いた文をテキストとして出します。類似性 / キーワードの基準や、分割の入力に繋げます。';

  @override
  String get nodeprogCatalogConvertSplitTitle => '分割';

  @override
  String get nodeprogCatalogConvertSplitDescription =>
      'テキストを区切り(改行 / カンマ / 空白)でテキスト配列にします。キーワードリストや保存の入力に繋げます。';

  @override
  String get nodeprogCatalogConvertJoinTitle => '結合';

  @override
  String get nodeprogCatalogConvertJoinDescription =>
      'テキスト配列を区切り(改行 / カンマ / 空白)で 1 つのテキストにします。';

  @override
  String get nodeprogCatalogListFirstTitle => '投稿を取り出す';

  @override
  String get nodeprogCatalogListFirstDescription =>
      '投稿リストの何番目かの投稿を 1 件取り出します(1 = 先頭)。本文をテキストにして基準や設定に繋げます。';

  @override
  String get nodeprogCatalogPostTextTitle => '投稿の本文';

  @override
  String get nodeprogCatalogPostTextDescription => '投稿 1 件の本文をテキストにします。';

  @override
  String get nodeprogCatalogRandomTitle => 'ランダム';

  @override
  String get nodeprogCatalogRandomDescription =>
      '投稿ごとに乱数を出します。範囲は「1-7」のように指定し、小数点を入れると小数点以下もカウントします。シードで再現できます。';

  @override
  String get nodeprogCatalogFileTitle => 'ファイルリーダー';

  @override
  String get nodeprogCatalogFileDescription => 'ローカルファイルを読み込んでテキストとして出します。';

  @override
  String get nodeprogCatalogTimelineTitle => 'タイムライン';

  @override
  String get nodeprogCatalogTimelineDescription =>
      '最終出力。投稿リストを繋ぐと、この画面のタイムラインに流れます。';

  @override
  String get nodeprogCatalogTlSourceTitle => 'タイムライン取得';

  @override
  String get nodeprogCatalogTlSourceDescription =>
      '選んだタイムラインを取得して、投稿リストとして渡します。';

  @override
  String get nodeprogCatalogTlSourceDetail =>
      '選んだタイムラインを取得して、投稿リスト(RRLタグ付き)として渡します。';

  @override
  String get nodeprogCatalogSortTitle => '並べ替え';

  @override
  String get nodeprogCatalogSortDescription =>
      '下に繋いだ条件に合う投稿を先頭に並べ替えます(元の順序は保たれます)。';

  @override
  String get nodeprogCatalogRemoveTitle => '消去';

  @override
  String get nodeprogCatalogRemoveDescription => '下に繋いだ条件に合う投稿を取り除きます。';

  @override
  String get nodeprogCatalogCondTitle => '条件';

  @override
  String get nodeprogCatalogCondDescription =>
      '指定したタグの内容を見て True/False を返します。下に数珠繋ぎで「かつ」、同じ接続部から並列で「または」。';

  @override
  String get nodeprogCatalogNotDescription => '下に繋いだ条件の否定を返します。';

  @override
  String get nodeprogCatalogFnInputTitle => '関数入力';

  @override
  String get nodeprogCatalogFnInputDescription =>
      '関数の中身の入口。呼び出し元から渡された投稿リストがここから出ます(関数の中身の編集画面専用)。';

  @override
  String get nodeprogCatalogFnOutputTitle => '関数出力';

  @override
  String get nodeprogCatalogFnOutputDescription =>
      '関数の中身の出口。ここに繋いだ投稿リストが関数ノードの出力になります(未接続なら素通し)。';

  @override
  String get nodeprogCatalogFilterQueryTitle => '検索絞り込み';

  @override
  String get nodeprogCatalogFilterQueryDescription =>
      '検索ワードに合う投稿だけ通します(「除外」で逆に落とします)。';

  @override
  String get nodeprogCatalogFilterQueryDetail =>
      '検索ワードに合う投稿だけ通します。ワードが空のときは、このページの検索ワード/タグを使います。「除外」を true にすると、合う投稿を落とします(ワードミュート)。';

  @override
  String get nodeprogCatalogMergeTitle => 'マージ';

  @override
  String get nodeprogCatalogMergeDescription => '繋いだ投稿リストを時刻順に 1 本にまとめます。';

  @override
  String get nodeprogCatalogMergeDetail =>
      '繋いだ投稿リストを時刻順に 1 本へ合流します。別アカウントに流れてきた同じ投稿は 1 枚に畳み、タイルの ↓ でアカウントを選べます。';

  @override
  String get nodeprogCatalogTimelineRelationalTitle => '関連タイムライン';

  @override
  String get nodeprogCatalogTimelineRelationalDescription =>
      '関連タイムラインの絞り込みの出口です。';

  @override
  String get nodeprogCatalogTimelineRelationalDetail =>
      '関連TLの前段絞り込みの最終出力。繋いだ投稿リストが会話イベント構築の入力になります(処理系は変わりません)。';

  @override
  String get nodeprogCatalogTlListTitle => 'リストTL取得';

  @override
  String get nodeprogCatalogTlListDescription =>
      'Misskey のリストのタイムラインを取得します(リスト名で指定)。';

  @override
  String get nodeprogCatalogTlSearchTitle => '検索TL取得';

  @override
  String get nodeprogCatalogTlSearchDescription => '検索ワードにヒットする投稿を取得します。';

  @override
  String get nodeprogCatalogTlDmTitle => 'DM取得';

  @override
  String get nodeprogCatalogTlDmDescription => '相手(ハンドル)との DM を取得します。';

  @override
  String get nodeprogCatalogTrendTagsTitle => 'トレンド取得';

  @override
  String get nodeprogCatalogTrendTagsDescription =>
      'いまのトレンドタグを文字列の配列として出します(類似度/キーワードの入力に)。';

  @override
  String get nodeprogCatalogTlFeedTitle => 'カスタムフィード取得';

  @override
  String get nodeprogCatalogTlFeedDescription => 'Bluesky のカスタムフィードを取得します。';

  @override
  String get nodeprogCatalogTlFeedDetail =>
      'Bluesky のカスタムフィード(フィードジェネレーター)のタイムラインを取得します(at:// の URI で指定。TL カスタマイズでは検索して選べます)。';

  @override
  String get nodeprogCatalogTlRasqlistTitle => 'RASQ リスト取得';

  @override
  String get nodeprogCatalogTlRasqlistDescription =>
      'いくつもの SNS の人をまとめた RASQ リストの投稿を取得します。';

  @override
  String get nodeprogCatalogTlRasqlistDetail =>
      'RASQ リスト(Misskey / Mastodon / Bluesky の人を 1 つにまとめたリスト)の投稿を取得します。選べるのは、リスト内の人の情報を取れる(同じサーバーのアカウントがある / 入っている人をフォローしている)リストだけです。';

  @override
  String get nodeprogCatalogTrendPostsTitle => 'トレンド検索結果取得';

  @override
  String get nodeprogCatalogTrendPostsDescription =>
      'いまのトレンド上位タグを検索して、その投稿を 1 本に合流して出します。';

  @override
  String get nodeprogCatalogComposerTargetTitle => 'ポスト先';

  @override
  String get nodeprogCatalogComposerTargetDescription =>
      '投稿先アカウントの候補です。下の条件に合うと投稿先になります。';

  @override
  String get nodeprogCatalogComposerTargetDetail =>
      '投稿先アカウントの候補。下に条件をぶら下げると、投稿内容がその条件に合うときこのアカウントが投稿先になります(上に置いたものほど優先。手動で選び直せます)。';

  @override
  String get nodeprogCatalogComposerFallbackTitle => '代わりのフォーマットで投稿';

  @override
  String get nodeprogCatalogComposerFallbackDescription =>
      '絞り込みで外れたとき、別の形でこのアカウントに投稿します。';

  @override
  String get nodeprogCatalogComposerFallbackDetail =>
      '絞り込みで投稿先から外れた場合のバイパス。下の条件(通常は直前の比較の Not)が成立したとき、代わりのフォーマットでこのアカウントに投稿します。';

  @override
  String get nodeprogCatalogComposerLinkgateTitle => '連動の絞り込み';

  @override
  String get nodeprogCatalogComposerLinkgateDescription =>
      '一緒に送る投稿だけに効く絞り込みです。';

  @override
  String get nodeprogCatalogComposerLinkgateDetail =>
      '連動投稿だけに掛かる絞り込みです。下の条件が成立しないと、このアカウントへの連動投稿は送られません(通常のポスト先判定には影響しません)。';

  @override
  String get nodeprogCatalogComposerRegexTitle => '投稿加工(正規表現)';

  @override
  String get nodeprogCatalogComposerRegexDescription => '送信するときに本文の一部を置き換えます。';

  @override
  String get nodeprogCatalogComposerRegexDetail =>
      '送信時に本文へ正規表現の置換をかけます(パターンに一致した部分を置換)。アカウントが空のときは全ての投稿先に適用します。';

  @override
  String get nodeprogCatalogTlMyreactionsTitle => 'リアクション済み取得';

  @override
  String get nodeprogCatalogTlMyreactionsDescription =>
      'TL で自分がリアクションした投稿を取得します(好みのプロファイル作りに)。';

  @override
  String get nodeprogCatalogTrendFrameTitle => 'トレンド枠';

  @override
  String get nodeprogCatalogTrendFrameDescription =>
      'トレンドホームの「トレンド」一覧の最終出力。タグ(テキスト配列)を繋ぐとそのまま一覧に出ます。';

  @override
  String get nodeprogCatalogMlSimilarTitle => '類似度 (SigLIP)';

  @override
  String get nodeprogCatalogMlSimilarDescription =>
      '基準と各投稿の似ている度合いを 0〜1 で出します。';

  @override
  String get nodeprogCatalogMlSimilarDetail =>
      '基準(テキスト/配列/ベクトル)と各投稿の類似度を、この TL 内での相対値 0〜1 で出します(0.8 ≒ 上位 2 割相当)。ML 不達時は n-gram 類似度に縮退します。';

  @override
  String get nodeprogCatalogMlGlinerTitle => 'GLiNER抽出';

  @override
  String get nodeprogCatalogMlGlinerDescription =>
      '投稿リストから特徴語(頻出順)を抽出して文字列の配列で出します。';

  @override
  String get nodeprogCatalogMlSiglipTitle => 'SigLIP埋め込み';

  @override
  String get nodeprogCatalogMlSiglipDescription => '投稿リストの傾向をまとめて出します。';

  @override
  String get nodeprogCatalogMlSiglipDetail =>
      '投稿リストの平均埋め込み(プロファイル)をベクトルで出します。ML 不達時は n-gram プロファイルに縮退します。';

  @override
  String get nodeprogCatalogStorageSaveTitle => '保存 (storage.safe)';

  @override
  String get nodeprogCatalogStorageSaveDescription => '繋いだデータを保存します。';

  @override
  String get nodeprogCatalogStorageSaveDetail =>
      '繋いだデータをスロットに保存します。storage.safe は依存関係の子プラグインにも渡せる安全な置き場(プラグイン側の受け渡しは初回起動時に確認)。';

  @override
  String get nodeprogCatalogStorageLoadTitle => '読み出し (storage.safe)';

  @override
  String get nodeprogCatalogStorageLoadDescription => 'スロットに保存したデータを読み出します。';

  @override
  String get nodeprogCatalogMlKeywordTitle => 'キーワード一致 (GLiNER)';

  @override
  String get nodeprogCatalogMlKeywordDescription =>
      'キーワード(または配列)と各投稿の特徴語の一致数を出します。';

  @override
  String get nodeprogCatalogMlTendencyTitle => '指向性/刺激性 (プロファイル)';

  @override
  String get nodeprogCatalogMlTendencyDescription =>
      '好みの設定への合い具合(0〜1)を各投稿に出します。';

  @override
  String get nodeprogCatalogMlTendencyDetail =>
      'storage.safe のトレンドプロファイル(好きなジャンル/方向性・指向性のしきい値・刺激性の上限)への適合度(0〜1)を各投稿に出します。プロファイルは検索ホームのトレンド ⚙ で編集し、他のノードからも同じスロットを読めます。';

  @override
  String get nodeprogCatalogCompareTitle => '比較';

  @override
  String get nodeprogCatalogCompareDescription =>
      '数値としきい値を比べて True/False を返します。';

  @override
  String get nodeprogCatalogCompareDetail =>
      '数値(類似度・乱数など)としきい値を比べて True/False を返す演算子条件です。値元が未接続・値が取れないとき(スロットが空など)は False になります。';

  @override
  String nodeprogCatalogTypeWithFormat(String type, String format) {
    return '$type($format)';
  }

  @override
  String nodeprogCatalogPortWithType(String label, String type) {
    return '$label($type)';
  }

  @override
  String get nodeprogCatalogIoCond => '条件';

  @override
  String get nodeprogCatalogIoNone => 'なし';

  @override
  String get nodeprogCatalogListSeparator => '・';

  @override
  String nodeprogCatalogIoSummary(String inputs, String outputs) {
    return '入力: $inputs → 出力: $outputs';
  }

  @override
  String get nodeprogCatalogCustomFunctionAuthor => 'カスタム関数';

  @override
  String nodeprogCatalogCustomFunctionCondDescription(String tags) {
    return '条件 $tags を受ける、自分で作った関数です。';
  }

  @override
  String nodeprogCatalogCustomFunctionCondDetail(String tags) {
    return '条件タグ $tags を受けるカスタム関数です(中身の配線はプラグイン/RAi で)。';
  }

  @override
  String get nodeprogCatalogCustomFunctionDataDescription => '自分で作った関数です。';

  @override
  String get nodeprogCatalogCustomFunctionDataDetail =>
      'カスタム関数です(中身の配線はプラグイン/RAi で)。';

  @override
  String get nodeprogCatalogGenreSortDictionary => 'ソート/辞書';

  @override
  String get nodeprogCatalogCustomFunctionDefaultName => '関数';

  @override
  String get nodeprogComponentsTrendFormTilesLabel => 'トレンドを取得';

  @override
  String get nodeprogComponentsTrendFormChipsLabel => 'カスタム(候補のチップ)';

  @override
  String get nodeprogComponentsTrendFormChipsHeading => '検索の候補';

  @override
  String get nodeprogComponentsTrendFormTilesDescription =>
      '候補のワードを、トレンドのタイルの形で出します(タップでそのワードのトレンド)。';

  @override
  String get nodeprogComponentsTrendFormTodayDescription =>
      '候補の上位のワードの投稿を、Today のようにまとめて出します。';

  @override
  String get nodeprogComponentsTrendFormChipsDescription =>
      '候補のワードを、検索の候補のチップで出します。';

  @override
  String nodeprogComponentsSuggestTitle(String what, String from) {
    return '$whatを$fromからサジェスト';
  }

  @override
  String nodeprogComponentsFilterTitle(String what, String from) {
    return '$whatを$fromから絞り込み';
  }

  @override
  String get nodeprogComponentsQueryFilterExcludeTitle => '検索絞り込み(除外)';

  @override
  String get nodeprogComponentsTendencyTitle => '指向性/刺激性(プロファイル)';

  @override
  String get nodeprogComponentsPluginTitle => 'カスタム(TLプラグイン)';

  @override
  String get nodeprogComponentsDisplayTimeline => '通常 TL';

  @override
  String get nodeprogComponentsDisplayRelational => '関連 TL';

  @override
  String get nodeprogComponentsDeliveryConfirm => '確認して投稿 (confirm)';

  @override
  String get nodeprogComponentsDeliveryDraft => '下書きだけ作る (draft)';

  @override
  String get nodeprogComponentsDeliveryAuto => 'そのまま投稿 (auto)';

  @override
  String get nodeprogComponentsSelfDm => 'この DM のメッセージ';

  @override
  String get nodeprogComponentsSelfSearch => 'このワードの検索結果';

  @override
  String get nodeprogComponentsSelfToday => 'Today の投稿';

  @override
  String get nodeprogComponentsSelfTrendWords => 'トレンドのワード';

  @override
  String get nodeprogComponentsSelfList => 'このリストの投稿';

  @override
  String get nodeprogComponentsSelfFeed => 'このフィードの投稿';

  @override
  String get nodeprogComponentsSelfBundle => '総合タブの投稿';

  @override
  String get nodeprogComponentsSelfHome => 'フォロー中タブの投稿';

  @override
  String get nodeprogComponentsSelfSocial => 'おすすめタブの投稿';

  @override
  String get nodeprogComponentsSelfLocal => 'ローカルタブの投稿';

  @override
  String get nodeprogComponentsSelfGlobal => 'グローバルタブの投稿';

  @override
  String get nodeprogComponentsSelfRelational => '関連タブの投稿';

  @override
  String get nodeprogComponentsSelfTab => 'このタブの投稿';

  @override
  String get nodeprogComponentsTrendTilesNoMl => 'ML モデルを使うので、トレンドタイルでは使えません';

  @override
  String get nodeprogComponentsTrendTilesNoPlugin =>
      '投稿の並べ替え(GPU を使うことも)なので、トレンドタイルでは使えません';

  @override
  String get nodeprogComposerResetConfig => 'この構成をリセット';

  @override
  String get nodeprogComposerLearnNone => 'まだ学習していません(投稿すると学習します)';

  @override
  String get nodeprogComposerLearnNoneDetail =>
      '学習プロファイル: まだ確定投稿がありません(投稿すると自動で学習します)';

  @override
  String nodeprogComposerLearnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'これまでの投稿 $count 件から学習しています',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerLearnCountDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '学習プロファイル: 確定投稿 $count 件(手動で切り替えた投稿は強く学習・半減期 90 日)',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerRelationStats(int pos, int neg) {
    return '実績: 連動 $pos 回 / 確認で解除 $neg 回';
  }

  @override
  String get nodeprogComposerNoAccounts => 'アカウントがありません';

  @override
  String get nodeprogComposerNoAccountsHint => 'ログインすると投稿先の条件を組めます';

  @override
  String get nodeprogComposerBanner => '下書きの内容に合うアカウントが、投稿先の候補になります';

  @override
  String get nodeprogComposerBannerDetail =>
      'アカウントごとに絞り込みを組むと、下書きの内容(と内部のフォーマット)が合うアカウントが投稿先の候補になります。';

  @override
  String get nodeprogComposerHandEdited =>
      'ポスト先はノードエディタで編集されています。ここで変えると上書きされます';

  @override
  String get nodeprogComposerHandEditedDetail =>
      'ポスト先はノードエディタで編集されています。ここで変更すると簡易構成で置き換えます。';

  @override
  String get nodeprogComposerFiltersHeader => 'ポスト先の絞り込み';

  @override
  String get nodeprogComposerFormatHeader => 'フォーマット';

  @override
  String get nodeprogComposerFormatCaption => '絞り込みに合わなかったときも、別の形で候補に残せます';

  @override
  String get nodeprogComposerFormatCaptionDetail =>
      '絞り込みに合わなかったとき、代わりのフォーマットで候補に残します(無くなる直前の比較からバイパス)。';

  @override
  String get nodeprogComposerDeliveryHeader => '連動投稿の届け方';

  @override
  String get nodeprogComposerDeliveryCaption => 'ほかのアカウントと一緒に送るときの設定です';

  @override
  String get nodeprogComposerDeliveryCaptionDetail =>
      '複数選択モードの「ノード連動」でこのアカウントへ送るときの届け方と、連動できる連動元です。';

  @override
  String nodeprogComposerDeliveryTitle(String delivery) {
    return '届け方: $delivery';
  }

  @override
  String get nodeprogComposerLinkSourcesLabel => '連動元のアカウント(主投稿先がここにあるときだけ連動)';

  @override
  String get nodeprogComposerLinkFiltersCaption => '連動の絞り込み(一緒に送るときだけ効きます)';

  @override
  String get nodeprogComposerLinkFiltersCaptionDetail =>
      '連動の絞り込み(連動投稿だけに掛かる関門。ポスト先判定には影響しません)';

  @override
  String nodeprogComposerFilterDescription(String basis, String what) {
    return 'このアカウントの$basisを基準に、下書きが$whatで合うとき投稿先候補になります。';
  }

  @override
  String get nodeprogComposerFilterBasisPosts => '投稿';

  @override
  String get nodeprogComposerFilterBasisReplies => '返信';

  @override
  String get nodeprogComposerFilterDisabled => '無効化中: このアカウントはポスト先の候補になりません。';

  @override
  String nodeprogComposerLinkOnlySubtitle(String account) {
    return '$account ・ 連動のみ';
  }

  @override
  String nodeprogComposerAndSubtitle(String account) {
    return '$account ・ かつ';
  }

  @override
  String get nodeprogComposerLinkFilterDescription =>
      '連動投稿がこの条件に合わないとき、このアカウントへは送られません。';

  @override
  String get nodeprogComposerAndDescription => '前の絞り込みと「かつ」で連結されます。';

  @override
  String get nodeprogComposerDeleteNode => 'ノードを削除';

  @override
  String nodeprogComposerRegexDescription(String pattern, String replace) {
    return 'このアカウントへ送る本文の「$pattern」を「$replace」に置換します。';
  }

  @override
  String get nodeprogComposerRegexDescriptionEmpty =>
      '送信時に本文へ正規表現の置換をかけます(例: タグの付け替え・伏せ字)。';

  @override
  String get nodeprogComposerRegexUnset => '投稿加工(未設定)';

  @override
  String nodeprogComposerRegexRule(String pattern, String replace) {
    return '「$pattern」→「$replace」';
  }

  @override
  String nodeprogComposerExtraNodeSubtitle(String account) {
    return '$account ・ 追加ノード';
  }

  @override
  String get nodeprogComposerExtraRegexDescription => '上の加工に続けて適用されます。';

  @override
  String get nodeprogComposerCwLabel => '注釈';

  @override
  String get nodeprogComposerNoOtherAccounts => '他のアカウントがありません';

  @override
  String get nodeprogComposerRegexMenuTooltip => '投稿加工の操作';

  @override
  String get nodeprogComposerFilterMenuTooltip => 'ポスト先の操作';

  @override
  String get nodeprogComposerParamsRegexEnabled => '投稿加工を有効にする';

  @override
  String get nodeprogComposerParamsRegexEnabledSubtitle =>
      'このアカウントへ送る本文にパターン置換をかけます';

  @override
  String get nodeprogComposerParamsExtraRegex => '上の加工に続けて適用される追加ノードです。';

  @override
  String get nodeprogComposerParamsFilterEnabled => '絞り込みを有効にする';

  @override
  String get nodeprogComposerParamsFilterEnabledSubtitle =>
      '無効のときこのアカウントはポスト先の候補になりません';

  @override
  String get nodeprogComposerParamsWhat => 'なにを見る?';

  @override
  String get nodeprogComposerParamsRegexDescription => '送信時に本文へ正規表現の置換をかけます。';

  @override
  String get nodeprogComposerParamsLinkFilterDescription => '一緒に送るときだけ効く条件です。';

  @override
  String get nodeprogComposerParamsLinkFilterDetail =>
      '連動投稿だけに掛かる関門です(ポスト先判定には影響しません)。';

  @override
  String get nodeprogComposerParamsFilterDescription =>
      '下書きがこの条件に合うとき、このアカウントが投稿先候補になります。';

  @override
  String get nodeprogComposerParamsPatternLabel => 'パターン(正規表現)';

  @override
  String get nodeprogComposerParamsPatternHint => '例: #ネタバレ\\s*';

  @override
  String get nodeprogComposerParamsReplaceLabel => '置換(空 = 削除)';

  @override
  String get nodeprogEditorCanvasInputs => '入力';

  @override
  String get nodeprogEditorCanvasOutputs => '出力';

  @override
  String get nodeprogEditorBadgeDefaultOwner => '既定';

  @override
  String get nodeprogEditorBadgeNotRegistered => '未登録';

  @override
  String get nodeprogEditorBadgeSeparator => ' ・ ';

  @override
  String get nodeprogEditorNodeTabDefaultLabel => 'ノードTL';

  @override
  String get nodeprogEditorInlineEmpty => 'ノードがありません';

  @override
  String get nodeprogEditorInlineExpandTooltip => '全画面で編集';

  @override
  String get nodeprogEditorParamsMissing =>
      'このプラグインは登録されていません(ストアから入れ直してください)。';

  @override
  String get nodeprogEditorParamsLoading => 'パラメーターを読み込んでいます…';

  @override
  String get nodeprogEditorParamsNone => 'このプラグインにパラメーターはありません。';

  @override
  String get nodeprogEditorCancelButton => 'キャンセル';

  @override
  String get nodeprogEditorConfirmButton => '決定';

  @override
  String get nodeprogEditorParamsTitle => 'ノードを設定';

  @override
  String get nodeprogEditorPluginSortAuthor => 'TLプラグイン';

  @override
  String get nodeprogEditorPluginSortDescription => 'プラグインの並べ方で投稿を並べ替えます。';

  @override
  String get nodeprogEditorParamsPluginDetail =>
      '投稿リストをプラグインのソート(tl.sort)で並べ替えます。パラメーターはノードの「パラメーター」ポートに入ります。';

  @override
  String nodeprogEditorPluginSortTitle(String name) {
    return '$nameでソート';
  }

  @override
  String get nodeprogEditorPluginSortDetail =>
      '投稿リストをプラグインのソート(tl.sort)で並べ替えます。';

  @override
  String get nodeprogEditorTitleFunctionBody => '関数の中身';

  @override
  String nodeprogEditorTitleFunctionBodyNamed(String name) {
    return '関数の中身 — $name';
  }

  @override
  String get nodeprogEditorTitleComposer => '投稿先のカスタマイズ';

  @override
  String get nodeprogEditorTitleTrend => 'トレンドをカスタマイズ';

  @override
  String get nodeprogEditorTitleTimeline => 'タイムラインをカスタマイズ';

  @override
  String get nodeprogEditorTabTrendNotes => 'ノート';

  @override
  String get nodeprogEditorTabFollowing => 'フォロー中';

  @override
  String get nodeprogEditorTabTrendUsers => 'ユーザー';

  @override
  String get nodeprogEditorTabBundle => '総合';

  @override
  String get nodeprogEditorTabSocial => 'おすすめ';

  @override
  String get nodeprogEditorTabRelational => '関連';

  @override
  String get nodeprogEditorTabLocal => 'ローカル';

  @override
  String get nodeprogEditorTabGlobal => 'グローバル';

  @override
  String get nodeprogEditorAddTabTooltip => 'タブを追加';

  @override
  String get nodeprogEditorNewTabTitle => '新しいタブ';

  @override
  String get nodeprogEditorTabNameHint => 'タブ名';

  @override
  String get nodeprogEditorRenameTab => 'タブ名を変更';

  @override
  String get nodeprogEditorDeleteTab => 'タブを削除';

  @override
  String get nodeprogEditorClearGraph => 'グラフをクリア';

  @override
  String get nodeprogEditorBundleTabsToggle => 'バンドルでノードTLを集合表示';

  @override
  String get nodeprogEditorPaletteSearchHint => 'プラグインノードを検索';

  @override
  String nodeprogEditorConnectTypeMismatch(String from, String to) {
    return '接続できません: $from → $to(形式が合いません)';
  }

  @override
  String get nodeprogEditorCreateFunction => 'カスタム関数を作成';

  @override
  String get nodeprogEditorFunctionNameHint => '関数名';

  @override
  String get nodeprogEditorFunctionSourceLabel => '入力元';

  @override
  String get nodeprogEditorFunctionSourceCond => '条件';

  @override
  String get nodeprogEditorFunctionSourceData => 'データ';

  @override
  String get nodeprogEditorFunctionCondTagsLabel => '条件タグ(複数選ぶと下側の分岐が増えます)';

  @override
  String get nodeprogEditorFunctionInputsLabel => '入力(データ形式)';

  @override
  String get nodeprogEditorFunctionOutputsLabel => '出力(データ形式)';

  @override
  String get nodeprogEditorCreateButton => '作成';

  @override
  String get nodeprogEditorMenuInfo => 'ノード情報';

  @override
  String get nodeprogEditorMenuEditFunctionBody => '関数の中身を編集';

  @override
  String get nodeprogEditorMenuStore => 'プラグインストアに移動';

  @override
  String get nodeprogEditorMenuCopy => 'コピー';

  @override
  String get nodeprogEditorMenuPaste => 'ペースト';

  @override
  String get nodeprogEditorMenuDelete => '削除';

  @override
  String get nodeprogEditorMoreTooltip => 'その他';

  @override
  String get nodeprogEditorSearchNodesTooltip => 'ノードを検索';

  @override
  String get nodeprogEditorEmptyHint => '下の検索から追加(タップで詳細、長押しでドラッグ)';

  @override
  String get nodeprogEditorToolbarSelect => '範囲選択';

  @override
  String get nodeprogEditorToolbarSelectStop => '範囲選択をやめる';

  @override
  String get nodeprogEditorToolbarDeleteSelected => '選んだノードを削除';

  @override
  String get nodeprogEditorToolbarTidy => '整理整頓';

  @override
  String get nodeprogEditorToolbarZoomOut => '縮小';

  @override
  String get nodeprogEditorToolbarZoomIn => '拡大';

  @override
  String get nodeprogEditorToolbarFit => '全体表示';

  @override
  String get nodeprogEditorPaletteSortChip => '並び替え: 関連順';

  @override
  String get nodeprogEditorPaletteSortRelevance => '関連順';

  @override
  String nodeprogEditorPaletteGenreChip(String genre) {
    return 'ジャンル: $genre';
  }

  @override
  String get nodeprogEditorPaletteGenreAll => 'すべて';

  @override
  String get nodeprogEditorPaletteSettingsTooltip => '検索設定(準備中)';

  @override
  String get nodeprogEditorPaletteEmptyTitle => 'ノードが見つかりません';

  @override
  String get nodeprogEditorPaletteEmptyHint => '検索ワードやジャンルを変えてみてください';

  @override
  String get nodeprogEditorCreateFunctionDescription =>
      '条件タグまたは入出力(データ形式)を選んで、自分の関数ノードを作ります。データ関数は中身をノードで組めます。';

  @override
  String nodeprogEditorTileSubtitle(String author, String genre) {
    return '$author · $genre';
  }

  @override
  String get nodeprogEditorBuiltinAuthor => '組み込みノード';

  @override
  String get nodeprogEditorAddToCanvas => 'キャンバスに追加';

  @override
  String get nodeprogEditorEditFunctionBody => '中身を編集';

  @override
  String get nodeprogEditorDeleteFunction => '関数を削除';

  @override
  String nodeprogEditorInfoGenre(String genre) {
    return 'ジャンル: $genre';
  }

  @override
  String get nodeprogEditorInfoCondIn => '条件(上辺)';

  @override
  String get nodeprogEditorInfoCondOut => '条件(下辺)';

  @override
  String get nodeprogTimelineTabDmCommon => 'DM(共通)';

  @override
  String get nodeprogTimelineTabThisDm => 'このDM';

  @override
  String get nodeprogTimelineTabTrendPage => 'トレンドページ';

  @override
  String get nodeprogTimelineTabTrendTl => 'トレンド TL';

  @override
  String get nodeprogTimelineTabThisList => 'このリスト';

  @override
  String get nodeprogTimelineReorderTabs => 'タブの並べ替え';

  @override
  String get nodeprogTimelineShareTab => 'すべてのアカウントで共有';

  @override
  String get nodeprogTimelineResetConfig => 'このTLの構成をリセット';

  @override
  String get nodeprogTimelineEditAsGraph => 'グラフで編集';

  @override
  String nodeprogTimelinePluginWithVersion(String version) {
    return 'TLプラグイン ・ v$version';
  }

  @override
  String get nodeprogTimelineAlgoChronoDescription => '取得したままの時刻順に整えます。';

  @override
  String get nodeprogTimelineAlgoTendencyDescription =>
      '好みの設定に合わない投稿を除き、合う順に並べます。';

  @override
  String get nodeprogTimelineAlgoTendencyDetail =>
      'トレンドプロファイル(指向性/刺激性・好きなジャンル)に合わない投稿を除外し、適合度順に並べます。';

  @override
  String nodeprogTimelineAlgoSuggestDescription(
    String from,
    String kind,
    String what,
  ) {
    return '$from($kind)を基準に、$whatで合う投稿を先頭へ並べ替えます。';
  }

  @override
  String get nodeprogTimelineSuggestFromMyPosts => '自分の投稿';

  @override
  String get nodeprogTimelineSuggestFromMyReplies => '自分の返信';

  @override
  String get nodeprogTimelineSuggestFromReacted => 'リアクションした投稿';

  @override
  String get nodeprogTimelineSourceHomeLabel => 'フォロー中 (home)';

  @override
  String get nodeprogTimelineSourceRasqTitle => 'RASQ の投稿を取得';

  @override
  String get nodeprogTimelineSourceRasqDescription =>
      'TL: 自分とフォロー中の RASQ アカウントの投稿';

  @override
  String get nodeprogTimelineSourceRasqSearchTitle => 'RASQ 検索';

  @override
  String get nodeprogTimelineSourceRasqSearchPageQuery =>
      '検索: このページの検索ワード / タグ(フォローしていない人の投稿も)';

  @override
  String nodeprogTimelineSourceRasqSearchWord(String word) {
    return '検索: $word(フォローしていない人の投稿も)';
  }

  @override
  String get nodeprogTimelineSourceRasqListTitle => 'RASQ リストを取得';

  @override
  String nodeprogTimelineSourceRasqListDescription(String name) {
    return 'RASQ リスト: $name';
  }

  @override
  String get nodeprogTimelineNotSelected => '未選択';

  @override
  String get nodeprogTimelineSectionTitle => 'セクション';

  @override
  String nodeprogTimelineSectionDescription(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'ノードを $max つまで包む枠(画面では入れた順に角丸の枠で出す)',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceAstellTitle => 'ASTell のタイル';

  @override
  String nodeprogTimelineSourceAstellDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'いま開いている ASTell のルーム($count 件まで)',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineSourceSwingDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Swing を出している人($count 件まで)',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceTrendFollowingTitle => 'フォロー中の反応';

  @override
  String get nodeprogTimelineSourceTrendFollowingDescription =>
      'フォロー中の人の、このページのワード / タグの投稿';

  @override
  String get nodeprogTimelineTrendPluginAll => '入れているトレンドプラグイン全部';

  @override
  String nodeprogTimelineTrendPluginMissing(String id) {
    return '$id(入っていません)';
  }

  @override
  String get nodeprogTimelineTrendPluginAuthor => 'トレンドプラグイン';

  @override
  String nodeprogTimelineTrendPluginDescription(String name, String form) {
    return '$name ・ $form';
  }

  @override
  String get nodeprogTimelineCurrentAccount => '(現在のアカウント)';

  @override
  String get nodeprogTimelineAllAccounts => '全部のアカウント';

  @override
  String get nodeprogTimelineSourceTrendTitle => 'トレンドを取得';

  @override
  String get nodeprogTimelineSourceTrendTagsAllDescription =>
      '種別: トレンドタイル(RASQ アカウントの SNS アカウント全部のトレンドのワード)';

  @override
  String get nodeprogTimelineSourceTrendTagsDescription =>
      '種別: トレンドタイル(このアカウントのサーバーのトレンドのワード)';

  @override
  String get nodeprogTimelineSourceSearchTitle => '検索結果を取得';

  @override
  String get nodeprogTimelineSourceSearchPageQuery => '検索: このページの検索ワード / タグ';

  @override
  String nodeprogTimelineSourceSearchWord(String word) {
    return '検索: $word';
  }

  @override
  String get nodeprogTimelineSourceTodayTitle => 'Today を取得';

  @override
  String get nodeprogTimelineSourceTodayDescription => 'TL: Today(注目の投稿)';

  @override
  String nodeprogTimelineSourceSelfTitle(String name) {
    return '$nameを取得';
  }

  @override
  String get nodeprogTimelineSourceDmTitle => 'DM取得';

  @override
  String get nodeprogTimelineSourceFeedTitle => 'カスタムフィードを取得';

  @override
  String get nodeprogTimelineSourceListTitle => 'リストTLを取得';

  @override
  String get nodeprogTimelineSourceTimelineTitle => 'タイムラインを取得';

  @override
  String nodeprogTimelineSourceTlDescription(String tl) {
    return 'TL: $tl';
  }

  @override
  String nodeprogTimelineSourceDmPeer(String peer) {
    return 'DM: @$peer';
  }

  @override
  String get nodeprogTimelineSourceTrendTlKind => '種別: トレンド TL(トレンド上位タグの検索結果)';

  @override
  String nodeprogTimelineSourceFeedName(String name) {
    return 'フィード: $name';
  }

  @override
  String nodeprogTimelineSourceListName(String name) {
    return 'リスト: $name';
  }

  @override
  String get nodeprogTimelineMenuInfo => '詳細';

  @override
  String get nodeprogTimelineMenuEditParams => 'パラメーターを編集';

  @override
  String get nodeprogTimelineMenuDisable => '一時的な無効化';

  @override
  String get nodeprogTimelineMenuEnable => '無効化の解除';

  @override
  String get nodeprogTimelineMenuStore => 'プラグインのストアページへ移動';

  @override
  String get nodeprogTimelineMenuKindToTiles => '種別をトレンドタイルに';

  @override
  String get nodeprogTimelineMenuKindToTl => '種別をトレンド TL に';

  @override
  String nodeprogTimelineMenuLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '件数: $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineMenuForm(String form) {
    return '形式: $form';
  }

  @override
  String nodeprogTimelineMenuDisplay(String mode) {
    return '表示モード: $mode';
  }

  @override
  String nodeprogTimelineLimitItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineInfoProvider(String provider) {
    return '提供: $provider';
  }

  @override
  String nodeprogTimelineInfoSupported(String sns) {
    return '対応: $sns';
  }

  @override
  String get nodeprogTimelineReorderAlgorithms => 'アルゴリズムの並べ替え';

  @override
  String get nodeprogTimelineReorderSources => 'タイムラインの並べ替え';

  @override
  String get nodeprogTimelineBannerDmCommon => 'すべての DM ページに使う設定です';

  @override
  String get nodeprogTimelineBannerDmPage => 'この DM ページだけの設定です';

  @override
  String get nodeprogTimelineBanner => 'タイムラインの中身と並び方を決められます';

  @override
  String get nodeprogTimelineBannerDmCommonDetail =>
      'DM のメイン設定です。個別設定のない全ての DM ページに適用されます。アルゴリズムは上から順に適用されます。';

  @override
  String get nodeprogTimelineBannerDmPageDetail =>
      'この DM ページだけの設定です(保存すると DM 共通設定より優先されます)。アルゴリズムは上から順に適用されます。';

  @override
  String get nodeprogTimelineBannerDetail =>
      'タイムラインのアルゴリズムや取り込み、表示するタイムラインなどを指定できます。アルゴリズムは上から順に適用されます。';

  @override
  String get nodeprogTimelineCreateNameLabel => 'タイムラインの名前';

  @override
  String get nodeprogTimelineCreateNameHint => '例: 友だち / 写真';

  @override
  String get nodeprogTimelineTempSearchOnly => 'プラグインが並べるタイムラインです。ここでは探すだけできます';

  @override
  String get nodeprogTimelineTempChanged => 'このタイムラインを一時的に変えています(保存していません)。';

  @override
  String get nodeprogTimelineTempRevert => '元に戻す';

  @override
  String get nodeprogTimelineTempSave => 'この内容で保存';

  @override
  String get nodeprogTimelineTempNotice => 'ここでの変更は一時的です。保存するまで元の設定は変わりません';

  @override
  String get nodeprogTimelineTempNoticeDetail =>
      'ここでの変更はこのタイムラインに一時的に効きます。保存するまで、元の設定は変わりません。';

  @override
  String get nodeprogTimelineCreateCaption => '取り込むタイムラインとアルゴリズムを選んで「決定」';

  @override
  String get nodeprogTimelineHandEdited =>
      'この TL はノードエディタで編集されています。ここで変えると上書きされます';

  @override
  String get nodeprogTimelineHandEditedDetail =>
      'この TL はノードエディタで編集されています。ここで変更すると簡易構成で置き換えます。';

  @override
  String get nodeprogTimelineAlgorithmsHeader => 'アルゴリズム';

  @override
  String get nodeprogTimelineAddAlgorithm => 'アルゴリズムを追加';

  @override
  String nodeprogTimelineSectionSubtitle(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'セクション ・ $count / $max',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineDisabledSuffix => ' ・ 無効化中';

  @override
  String get nodeprogTimelineDisabled => '無効化中';

  @override
  String get nodeprogTimelineMetaSeparator => ' ・ ';

  @override
  String get nodeprogTimelineSectionMenuTooltip => 'セクションの操作';

  @override
  String get nodeprogTimelineAddNode => 'ノードを追加';

  @override
  String get nodeprogTimelineNodeMenuTooltip => 'ノードの操作';

  @override
  String get nodeprogTimelineSectionRename => '見出しを変更';

  @override
  String get nodeprogTimelineSectionRenameTitle => 'セクションの見出し';

  @override
  String get nodeprogTimelineMenuTakeOut => 'セクションから出す';

  @override
  String get nodeprogTimelineDisplayHeader => '表示モード';

  @override
  String nodeprogTimelineDisplayTitle(String mode) {
    return '表示: $mode';
  }

  @override
  String get nodeprogTimelineDisplaySubtitle =>
      '同じ投稿を、通常の TL / 会話のまとまり(関連 TL)/ 投稿した人の並びで見せます';

  @override
  String get nodeprogTimelineSourcesHeader => 'SNSタイムライン';

  @override
  String get nodeprogTimelineReorderDone => '並べ替えを終える';

  @override
  String get nodeprogTimelineTrendPageCaption =>
      '検索ホームに上から順に出します。セクションでトレンドと Today の区間を分けます';

  @override
  String get nodeprogTimelineTrendPageCaptionDetail =>
      '検索ホームに上から順に出します。既定は「トレンド」(全部のアカウントのトレンドのタイル)と「Today」のセクションです。アルゴリズムはトレンドのタイルに掛かります(重いものは使えません)。';

  @override
  String get nodeprogTimelineSourcesCaption =>
      '複数を重ねると 1 本にまとまり、同じ投稿は 1 つになります';

  @override
  String get nodeprogTimelineSourcesCaptionDetail =>
      '複数を重ねると 1 本に合流し、同じ投稿は 1 枚に畳まれます(タイルの ↓ でアカウント切替)。投稿加工プラグインは各タイムライン提供元(SNSプラグイン)側で適用されます。';

  @override
  String get nodeprogTimelineReorderHint =>
      '長押しでつかんで動かします。セクションの中(3 つまで)へも出し入れできます';

  @override
  String get nodeprogTimelineAddSource => 'タイムラインを追加';

  @override
  String get nodeprogTimelineClockHeader => '自動更新';

  @override
  String nodeprogTimelineClockInterval(String interval) {
    return '間隔: $interval';
  }

  @override
  String get nodeprogTimelineAlgorithmMenuTooltip => 'アルゴリズムの操作';

  @override
  String get nodeprogTimelineSourceMenuTooltip => 'タイムラインの操作';

  @override
  String nodeprogTimelineTendencyGenres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '好きなジャンル $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyDisliked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '好きではない $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '例 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyStimulus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '刺激性の上限 $count',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTendencyPinnedTitle => '指向性/刺激性(傾向)';

  @override
  String get nodeprogTimelineTendencyPinnedSubtitle => 'いつも最後';

  @override
  String get nodeprogTimelineTendencyPinnedEmpty => '傾向 FOW の設定';

  @override
  String get nodeprogTimelineTendencyPinnedInfo =>
      '傾向 FOW で設定した指向性/刺激性を、アルゴリズムの一番最後に掛けます。ここでは外せません(変える / 止めるときは傾向 FOW で)';

  @override
  String get nodeprogTimelineParamsSuggestWhat => 'なにをサジェストする?';

  @override
  String get nodeprogTimelineParamsSuggestFrom => 'なにから読み取る?';

  @override
  String get nodeprogTimelineParamsPluginPending => 'このプラグインの設定は準備中です。';

  @override
  String get nodeprogTimelineParamsQueryFilter =>
      'ワードが空のときは、このページの検索ワード/タグで絞り込みます。ワードは下の欄で指定できます。';

  @override
  String get nodeprogTimelineParamsTendency => '好みの設定を使います。下から変えられます。';

  @override
  String get nodeprogTimelineParamsChrono => '時系列順にパラメーターはありません。';

  @override
  String get nodeprogTimelineParamsPluginPendingDetail =>
      'このプラグインのパラメーター(RRL 設定ページ)は、ノード定義の配布(ストア統合)でここに表示されます。';

  @override
  String get nodeprogTimelineParamsTendencyDetail =>
      'storage.safe のトレンドプロファイルを使います。下のオプションから指向性/刺激性・好きなジャンル・アクションからのジャンル選択を編集できます(検索ホームのトレンド ⚙ と同じもの)。';

  @override
  String get nodeprogTimelineParamsTrendPlugin =>
      'トレンドプラグインが出した候補のワードを、選んだ形式で出します。';

  @override
  String get nodeprogTimelineParamsTrendPluginDetail =>
      'スロット trend.suggest の答え(候補のワード)を、トレンドを取得 = トレンドのタイル / Today = 上位の語の投稿のダイジェスト / カスタム = 候補のチップ で出します。件数は … から。';

  @override
  String get nodeprogTimelineParamsForm => '形式';

  @override
  String get nodeprogTimelineParamsRasq =>
      '自分とフォロー中の人の RASQ の投稿を取り込みます。RASQ にログインしているときだけ流れます。';

  @override
  String get nodeprogTimelineParamsRasqDetail =>
      '自分とフォロー中の RASQ アカウントの投稿 / リブロードを取り込みます。RASQ アカウントにログインしているときだけ流れます。パラメーターはありません。';

  @override
  String get nodeprogTimelineParamsRasqSearch =>
      'RASQ の公開の投稿を検索して取り込みます。フォローしていない人の投稿も入ります。';

  @override
  String get nodeprogTimelineParamsRasqSearchDetail =>
      'RASQ の公開の投稿(フォロー中かどうかに関係なく)を、下のワードで検索して取り込みます。空にすると、このページの検索ワード / タグで探します。表示モードを「ユーザー」にすると、投稿した人のタイルで並びます。';

  @override
  String get nodeprogTimelineParamsRasqList =>
      'RASQ リストの投稿を取り込みます。下で選ぶと、そのリストをフォローします。';

  @override
  String get nodeprogTimelineParamsRasqListDetail =>
      'RASQ リストの投稿を取り込みます(Central が、見たときにリスト内の人の投稿を集めます)。下の欄で、自分のリスト・フォロー中のリストから選ぶか、公開リストを検索して選びます。選ぶと、そのリストをフォローします。';

  @override
  String nodeprogTimelineParamsSelfDetail(String name) {
    return '$nameをそのまま取り込みます。パラメーターはありません。';
  }

  @override
  String get nodeprogTimelineParamsAccount => 'アカウント';

  @override
  String get nodeprogTimelineParamsTlKind => 'TL 種別(この SNS が出せるもの)';

  @override
  String get nodeprogTimelineParamsList => 'リスト(このアカウントのもの)';

  @override
  String get nodeprogTimelineParamsNoLists => 'このアカウントにはリストがありません(または取得できません)。';

  @override
  String get nodeprogTimelineParamsFeed => 'カスタムフィード(下の欄で検索して選ぶ)';

  @override
  String get nodeprogTimelineParamsTendencyEdit => 'トレンドの指向性/刺激性';

  @override
  String get nodeprogTimelineParamsGenresEdit => '好きなジャンル/方向性';

  @override
  String get nodeprogTimelineParamsPickGenresSubtitle =>
      '類似した話題でまとめて、話題性の強いものから';

  @override
  String get nodeprogTimelineParamsRasqSearchWordLabel =>
      '検索ワード(空 = このページのワード / タグ)';

  @override
  String get nodeprogTimelineParamsRasqListSearchLabel =>
      'RASQ リストを検索(名前 / @作った人 / 共有リンク)';

  @override
  String get nodeprogTimelineParamsFeedSearchLabel => 'フィードを検索';

  @override
  String get nodeprogTimelineParamsFeedNotFound => '見つかりません';

  @override
  String get nodeprogTimelineParamsQueryLabel => '検索ワード(空 = このページの検索ワード)';

  @override
  String get nodeprogTimelineParamsExcludeTitle => 'このワードを含む投稿を除外する';

  @override
  String get nodeprogTimelineParamsExcludeSubtitle => 'オフなら含む投稿だけ通します';

  @override
  String get nodeprogTimelineCreateTitle => 'タイムラインを作成';

  @override
  String nodeprogTimelineCreateDefaultName(int number) {
    return 'タイムライン $number';
  }

  @override
  String get nodeprogTimelineCreateShareTitle => '他のアカウントにも適用しますか';

  @override
  String get nodeprogTimelineCreateShareMessage =>
      '「すべてのアカウントに適用」にすると、どのアカウントでもこのタイムラインが並び、中身の変更も全部に効きます(あとで … メニューから変えられます)。';

  @override
  String get nodeprogTimelineCreateShareConfirm => 'すべてのアカウントに適用';

  @override
  String get nodeprogTimelineCreateShareCancel => 'このアカウントだけ';

  @override
  String get nodeprogTimelineLoadFailed => '読み込めませんでした';

  @override
  String get nodeprogTimelineNodeTrend => 'トレンド';

  @override
  String get nodeprogTimelineNodeTabFallback => 'ノード TL';

  @override
  String get nodeprogTimelineReload => '読み直す';

  @override
  String get nodeprogTimelineAstellEmpty => 'いま開いている ASTell はありません';

  @override
  String nodeprogTimelineAstellEmptyQuery(String query) {
    return '「$query」の ASTell はありません';
  }

  @override
  String get nodeprogTimelineSwingEmpty => 'いま Swing はありません';

  @override
  String nodeprogTimelineSwingEmptyQuery(String query) {
    return '「$query」の Swing はありません';
  }

  @override
  String get nodeprogTimelineTrendEmpty => 'トレンドはまだありません';

  @override
  String get nodeprogTimelineTrendFollowingNoQuery => 'トレンド TL で出ます';

  @override
  String get nodeprogTimelineTrendFollowingEmpty => 'フォロー中の人の反応はまだありません';

  @override
  String get nodeprogTimelinePostsEmpty => 'まだありません';

  @override
  String get nodeprogTimelineEventsEmpty => '会話のまとまりはまだありません';

  @override
  String get nodeprogTimelineUsersEmpty => 'まだいません';

  @override
  String nodeprogTimelineUserPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の投稿',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTempSemantics => 'タイムラインを一時的に変える';

  @override
  String get nodeprogTimelineSearchPrev => '前の該当投稿';

  @override
  String get nodeprogTimelineSearchNext => '次の該当投稿';

  @override
  String get nodeprogTimelineSearchHint => 'このタイムラインから探す';

  @override
  String get nodeprogTimelineSearchFuzzy => '近似検索';

  @override
  String get nodeprogTimelineTempClose => '閉じる';

  @override
  String get nodeprogTimelineTempTitle => 'タイムラインを一時変更';

  @override
  String get nodeprogTimelinePaletteSuggestTitle => 'サジェスト';

  @override
  String get nodeprogTimelinePaletteSuggestDescription =>
      'あなたの投稿や反応に近い投稿を先頭に並べます。';

  @override
  String get nodeprogTimelinePaletteSuggestDetail =>
      '[キーワード/類似性] を [投稿内容/リアクション/会話内容] から読み取り、合う投稿を先頭へ並べ替えます。';

  @override
  String get nodeprogTimelinePaletteFilterTitle => '絞り込み';

  @override
  String get nodeprogTimelinePaletteFilterDescription =>
      'あなたの投稿や反応に合わない投稿を除きます。';

  @override
  String get nodeprogTimelinePaletteFilterDetail =>
      '[キーワード/類似性] を [投稿内容/リアクション/会話内容] から読み取り、合わない投稿を除外します(サジェストと同じパラメーター)。';

  @override
  String get nodeprogTimelinePaletteQueryFilterTitle => '検索絞り込み';

  @override
  String get nodeprogTimelinePaletteQueryFilterDescription =>
      'このページの検索ワード/タグ(または指定ワード)に合う投稿だけ通します。';

  @override
  String get nodeprogTimelinePaletteTendencyTitle => '指向性/刺激性';

  @override
  String get nodeprogTimelinePaletteTendencyDescription =>
      '好みの設定に合わない投稿を除き、合う順に並べます。';

  @override
  String get nodeprogTimelinePaletteTendencyDetail =>
      'トレンドプロファイル(好きなジャンル/方向性・指向性のしきい値・刺激性の上限)に合わない投稿を除外し、適合度順に並べます。プロファイルは検索ホームのトレンド ⚙ で編集します。';

  @override
  String get nodeprogTimelinePalettePickGenresTitle => 'アクションからジャンルを選択';

  @override
  String get nodeprogTimelinePalettePickGenresDescription =>
      '反応した投稿の話題から、好きなジャンルを選びます。';

  @override
  String get nodeprogTimelinePalettePickGenresDetail =>
      'リアクションした投稿を類似した話題でまとめ、話題性の強いものから「好き / 好きではない」で好きなジャンルを決めます(指向性/刺激性の部品がこのプロファイルを使います)。';

  @override
  String get nodeprogTimelinePaletteChronoTitle => '時系列順';

  @override
  String get nodeprogTimelinePaletteChronoDescription => '取得したままの時刻順に整えます。';

  @override
  String get nodeprogTimelinePaletteThisDmDescription =>
      'この DM ページのメッセージをそのまま取り込みます。';

  @override
  String get nodeprogTimelinePaletteThisDmDetail =>
      'この DM ページのメッセージをそのまま取り込みます(共通設定ではそれぞれのページの DM)。';

  @override
  String get nodeprogTimelinePaletteSearchResultsDescription =>
      'このアカウントで、このページの検索ワード / タグを検索した結果を取り込みます。';

  @override
  String get nodeprogTimelinePaletteRasqPostsTitle => 'RASQ の投稿';

  @override
  String get nodeprogTimelinePaletteRasqPostsDescription =>
      '自分とフォロー中の人の RASQ の投稿を取り込みます。';

  @override
  String get nodeprogTimelinePaletteRasqPostsDetail =>
      '自分とフォロー中の RASQ アカウントの投稿 / リブロードを取り込みます。SNS の投稿と同じタイムラインに混ぜられます。';

  @override
  String get nodeprogTimelinePaletteTimelineTitle => 'タイムライン';

  @override
  String get nodeprogTimelinePaletteTimelineDescription =>
      'アカウントのタイムラインを取り込みます。種類は追加後に選べます。';

  @override
  String get nodeprogTimelinePaletteTimelineDetail =>
      'アカウントの基本タイムラインを取り込みます。種類はその SNS が出せるもの(フォロー中 / ローカル / グローバル / Discover …)から、アカウントと合わせて追加後のタイルで選べます。';

  @override
  String get nodeprogTimelinePaletteListTlTitle => 'リストTL';

  @override
  String get nodeprogTimelinePaletteListTlDescription =>
      'アカウントのリストを取り込みます。リストは追加後に選べます。';

  @override
  String get nodeprogTimelinePaletteListTlDetail =>
      'アカウントと、そのアカウントに含まれるリストのタイムラインを取り込みます(追加後のタイルで選択)。';

  @override
  String get nodeprogTimelinePaletteFeedTitle => 'カスタムフィード(Bluesky)';

  @override
  String get nodeprogTimelinePaletteFeedDescription =>
      'Bluesky のカスタムフィードを探して取り込みます。';

  @override
  String get nodeprogTimelinePaletteFeedDetail =>
      'Bluesky のカスタムフィードを検索して取り込みます(SNS を跨いだリストは「RASQ リスト」)。';

  @override
  String get nodeprogTimelinePaletteRasqListTitle => 'RASQ リスト';

  @override
  String get nodeprogTimelinePaletteRasqListDescription =>
      'いくつもの SNS の人をまとめたリストの投稿を取り込みます。';

  @override
  String get nodeprogTimelinePaletteRasqListDetail =>
      'RASQ リスト(Misskey / Mastodon / Bluesky の人を 1 つにまとめたリスト)の投稿を取り込みます。自分のリスト・フォロー中のリストから選ぶか、公開リストを検索します。選べるのは、リスト内の人の情報を取れる(同じサーバーのアカウントがある / 入っている人をフォローしている)リストだけです。';

  @override
  String get nodeprogTimelinePaletteTrendDescription =>
      'いまのトレンドを取り込みます。種別(トレンドタイル / トレンド TL)は追加後に切り替えます。';

  @override
  String get nodeprogTimelinePaletteTrendDetail =>
      'トレンドタイル = サーバーのトレンドのワードのタイル、トレンド TL = いまのトレンド上位タグの検索結果を 1 本に合流した投稿。';

  @override
  String get nodeprogTimelinePaletteTrendFollowingDescription =>
      'フォロー中の人の、このページのワード / タグの投稿を出します。';

  @override
  String nodeprogTimelinePaletteDmPeerDescription(String peer) {
    return '@$peer との DM を取り込みます。';
  }

  @override
  String get nodeprogTimelinePaletteSectionDescription =>
      'ノードを 3 つまで包む枠です。画面では見出しの下に、入れた順で出します。';

  @override
  String get nodeprogTimelinePaletteAstellDescription =>
      'いま開いている ASTell のルームをタイルで出します。';

  @override
  String get nodeprogTimelinePaletteSwingDescription => 'Swing を出している人を並べます。';

  @override
  String nodeprogTimelinePaletteTrendPluginTitle(String form, String name) {
    return '$form: $name';
  }

  @override
  String nodeprogTimelinePaletteTrendPluginDetail(String form) {
    return '$form(スロット trend.suggest の答えを、この形式のノードで出します)';
  }

  @override
  String nodeprogTimelinePaletteTodayTitle(String account) {
    return 'Today: $account';
  }

  @override
  String get nodeprogTimelinePaletteSnsPluginAuthor => 'SNSプラグイン';

  @override
  String get nodeprogTimelinePaletteListsAuthor => 'リスト系';

  @override
  String get nodeprogTimelinePaletteTodayDescription =>
      'このアカウントの Today(注目の投稿)を取り込みます。';

  @override
  String nodeprogTimelinePaletteTrendTagsTitle(String account) {
    return 'トレンド: $account';
  }

  @override
  String get nodeprogTimelinePaletteTrendTagsAllDescription =>
      'RASQ アカウントの SNS アカウント全部のトレンドのワードを、タイルで出します。';

  @override
  String get nodeprogTimelinePaletteTrendTagsDescription =>
      'このアカウントのサーバーのトレンドのワードを、タイルで出します。';

  @override
  String nodeprogTimelinePaletteSearchResultsTitle(String account) {
    return '検索結果: $account';
  }

  @override
  String nodeprogTimelinePaletteSelfDescription(String name) {
    return '$nameをそのまま取り込みます。';
  }

  @override
  String get nodeprogTimelinePaletteRasqSearchDescription =>
      'フォローしていない人も含めて、RASQ の投稿を検索して取り込みます。表示モード「ユーザー」で人のタイルに。';

  @override
  String get nodeprogTimelinePaletteEmptyTitle => 'コンポーネントが見つかりません';

  @override
  String get nodeprogTimelinePaletteEmptyHint => '検索ワードを変えてみてください';

  @override
  String get onboardingBack => '戻る';

  @override
  String get onboardingHandleTooShort => '3 文字以上にしてください';

  @override
  String get onboardingHandleTooLong => '32 文字までです';

  @override
  String get onboardingHandleInvalid => '半角の英小文字・数字・_ だけ使えます';

  @override
  String get onboardingAccountTitleNew => '新しい RASQ アカウントを作る';

  @override
  String get onboardingAccountTitle => 'RASQ アカウントを作る';

  @override
  String get onboardingAccountDescription =>
      'RASQ アカウントは、ログインした SNS アカウントをひとつに束ねる「あなた」の入れ物です。入れたプラグイン・設定・アカウントのまとまりを、ほかの端末でも使えます。';

  @override
  String get onboardingHandleLabel => 'ユーザー名(@ のあとの名前)';

  @override
  String get onboardingHandleHelper => '半角の英小文字・数字・_ で 3〜32 文字';

  @override
  String onboardingPasswordLabel(int min) {
    return 'パスワード($min 文字以上)';
  }

  @override
  String get onboardingPasswordHide => '隠す';

  @override
  String get onboardingPasswordShow => '表示';

  @override
  String get onboardingPasswordConfirmLabel => 'パスワード(確認)';

  @override
  String get onboardingPasswordMismatch => '一致しません';

  @override
  String get onboardingPasswordCaption =>
      'ほかの端末や Web 版から、このアカウントにログインするときに使います。';

  @override
  String get onboardingAgeHeading => '年齢';

  @override
  String get onboardingAgeCaption =>
      'RASQ は 13 歳以上で使えます。18 歳未満の人は、次のページで保護者の同意を確かめます。';

  @override
  String get onboardingNoCentral => 'RASQ Central の接続先が未設定です';

  @override
  String get onboardingSetCentral => '接続先を設定';

  @override
  String get onboardingNext => '次へ';

  @override
  String onboardingCreateFailed(String error) {
    return 'RASQ アカウントを作成できませんでした: $error';
  }

  @override
  String get onboardingTermsTitle => '利用規約とプライバシーポリシー';

  @override
  String get onboardingTermsNoDraft => '先に ① のページでユーザー名などを入れてください';

  @override
  String get onboardingTermsRead => '利用規約を読む';

  @override
  String get onboardingPrivacyRead => 'プライバシーポリシーを読む';

  @override
  String get onboardingAgree => '利用規約とプライバシーポリシーに同意する';

  @override
  String get onboardingChildSafeHeading => 'チャイルドセーフ(18 歳未満)';

  @override
  String onboardingChildSafeNote(String age) {
    return '$ageの人は、保護者の同意が必要です。保護者の RASQ アカウントとつなぐと、保護者が使い方(見られる投稿の強さ・時間・使える機能)を決められます(設定 → チャイルドセーフ → チャイルドモード)。';
  }

  @override
  String get onboardingGuardianConsent => '保護者の同意を得ています';

  @override
  String get onboardingChildLogin => '保護者からのコードでログインする';

  @override
  String get onboardingChildLoginCaption =>
      '保護者があなたのアカウントを作ってくれた場合は、ここで登録せず、受け取ったコードでログインしてください。';

  @override
  String get onboardingBundleHeading => 'アカウントバンドル';

  @override
  String get onboardingBundleReplace => 'この端末の SNS アカウントで置き換える';

  @override
  String onboardingBundleReplaceSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ログイン中の $count 件を、この RASQ アカウントにまとめます',
    );
    return '$_temp0';
  }

  @override
  String get onboardingBundleKeep => '置き換えない';

  @override
  String get onboardingBundleKeepSubtitle => 'SNS アカウントはこの端末だけに残します';

  @override
  String get onboardingTermsContributionNote =>
      '「アルゴリズムとコミュニティへの貢献」は、この登録には含まれません(別の任意の同意で、既定は「提供しない」です)。RASQ アカウントはいつでも削除できます。';

  @override
  String get onboardingRegister => '同意して登録する';

  @override
  String get onboardingSnsTitle => 'SNS アカウントでログイン';

  @override
  String get onboardingSnsDescription =>
      'RASQ アカウントができました。使っている SNS のアカウントでログインしてください。まだ SNS を使っていなければ、「SNS サービスを探す」から合うサーバーやリストを探せます。';

  @override
  String onboardingSnsLoginWith(String service) {
    return '$serviceでログイン';
  }

  @override
  String get onboardingSnsPluginLoadNote =>
      '初回ログイン前に、プラグインのロードが行われます。ネット環境の良い場所で行ってください。';

  @override
  String onboardingSignupGuideClosed(String name) {
    return '$name はいま新しい登録を受け付けていないか、招待制です。招待のリンクを持っていなければ、別のサーバーを選んでください。';
  }

  @override
  String onboardingSignupGuideMastodonOpened(String name) {
    return '$name の登録ページを開きました。サーバーのルールが出たら読んで、「同意する」を押してください。';
  }

  @override
  String get onboardingSignupGuideMastodonForm =>
      '表示名・ユーザー名・メールアドレス・パスワードを入れます。ユーザー名はあとから変えられないので、気に入ったものを選んでください。';

  @override
  String get onboardingSignupGuideMastodonMail =>
      '登録を押すと、確認のメールが届きます。メールのリンクを開いて、メールアドレスを確かめてください。';

  @override
  String onboardingSignupGuideOpened(String name) {
    return '$name のページを開きました。ページの「新規登録」を押してください。';
  }

  @override
  String get onboardingSignupGuideForm =>
      'ユーザー名とパスワードを決めます。ユーザー名はあとから変えられないので、気に入ったものを選んでください。';

  @override
  String get onboardingSignupGuideChecks =>
      'サーバーによっては、メールアドレス・招待コード・ロボットでないことの確認を聞かれます。画面の案内のとおりに入れてください。';

  @override
  String get onboardingSignupGuideRules =>
      'サーバーのルール(利用規約)を読んで同意します。メールの確認を求められたら、届いたメールのリンクを開いてください。';

  @override
  String get onboardingSignupGuideDone =>
      '登録が終わったら、下の「登録できた」を押してください。RASQ からこのサーバーにログインします。';

  @override
  String get onboardingSignupGuideThenPost => 'ログインできたら、さっきの投稿を開きます。';

  @override
  String onboardingSignupGuideThenList(String name) {
    return 'ログインできたら、RASQ リスト「$name」を開きます。';
  }

  @override
  String get onboardingSignupGuideRasqLater =>
      'RASQ アカウントは、あとからサイドバーの … で作れます。';

  @override
  String get onboardingSignupTitleFallback => 'サーバーに登録';

  @override
  String get onboardingSignupNoTarget => '登録するサーバーが選ばれていません';

  @override
  String get onboardingSignupDone => '登録できた(ログインへ)';

  @override
  String onboardingSignupTitle(String name) {
    return '$name に登録';
  }

  @override
  String get onboardingSignupGuideHeading => 'RAi の案内';

  @override
  String get onboardingSignupGuidePrev => '前へ';

  @override
  String get onboardingSignupNoWebView =>
      'この端末では、アプリの中で登録ページを開けません。ブラウザで開いて登録し、終わったらこの画面に戻ってください。';

  @override
  String get onboardingSignupOpenBrowser => 'ブラウザで登録ページを開く';

  @override
  String onboardingSignupPostNotFound(String account) {
    return '$account では、さっきの投稿を見つけられませんでした';
  }

  @override
  String get onboardingEntryCreateNew => '新しく RASQ アカウントを作成';

  @override
  String get onboardingEntryCreate => 'RASQ アカウントを作成';

  @override
  String get onboardingEntryLogin => 'RASQ アカウントにログイン';

  @override
  String get onboardingEntryDiscover => 'SNS サービスを探す(画像・人・RAi から)';

  @override
  String onboardingEntryResume(String name) {
    return '$nameで続ける';
  }

  @override
  String onboardingEntryResumeWithHandle(String name, String handle) {
    return '$name(@$handle)で続ける';
  }

  @override
  String get onboardingEntryResumeFallbackName => 'RASQ アカウント';

  @override
  String get onboardingEntrySnsOnly => 'SNS アカウントだけで使う';

  @override
  String get onboardingEntrySkip => 'スキップしてこの端末だけで使う';

  @override
  String get onboardingEntryHaveAccount => 'RASQ アカウントを持っている';

  @override
  String get onboardingEntryLoginQuestion => 'RASQ アカウントにログインしますか?';

  @override
  String get onboardingEntryCreateQuestion => 'RASQ アカウントを作成しますか?';

  @override
  String get onboardingEntryLoginBody =>
      'RASQ アカウントに入ると、束ねた SNS アカウント・導入したプラグイン・設定が、この端末に戻ります。';

  @override
  String get onboardingEntryCreateBody =>
      'RASQ アカウントは、ログインした SNS アカウントをひとつに束ねる「あなた」の入れ物です。作成すると、導入したプラグイン・設定・アカウントの束ね方が RASQ Central に保存され、別の端末からも同じ状態で使えます。';

  @override
  String get onboardingEntryWebNote =>
      'Web 版では、SNS のログイン情報を RASQ のサーバーの保管庫に預けます(サーバーの鍵で暗号化し、RASQ のサーバーは復号できます)。SNS だけで使うこともできますが、そのときはこのタブを閉じるとログインが消えます。';

  @override
  String get onboardingEntrySnsOnlyNote =>
      'SNS アカウントだけで使うこともできます。その場合、導入したプラグインや設定はこの端末の中にだけ保存されます。';

  @override
  String get onboardingEntrySkipNote =>
      'スキップしても RASQ は使えます。その場合、導入したプラグインや設定はこの端末の中にだけ保存されます(あとからサイドバーの … で作成できます)。';

  @override
  String get onboardingShowcaseTitle => 'サーバーとリストを見てみる';

  @override
  String get onboardingShowcaseServersHint => 'タップすると、そのサーバーに登録できます';

  @override
  String get onboardingShowcaseOpenServer => 'サーバーを開く';

  @override
  String get onboardingShowcaseSignupServer => 'このサーバーに登録';

  @override
  String get onboardingShowcaseListsHint =>
      'SNS をまたいだ人のリストです。タップすると、リストの人がいるサーバーに登録できます';

  @override
  String get onboardingShowcaseListCannotSignup => 'このリストのサーバーには、アプリから登録できません';

  @override
  String get onboardingShowcasePickServer => 'どのサーバーに登録しますか?';

  @override
  String onboardingShowcasePickServerSubtitle(String host, String kind) {
    return '$host ・ $kind';
  }

  @override
  String onboardingShowcasePostImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '画像 $count 枚',
    );
    return '$_temp0';
  }

  @override
  String get onboardingGenreGame => 'ゲーム';

  @override
  String get onboardingGenreAnime => 'アニメ・マンガ';

  @override
  String get onboardingGenreMusic => '音楽';

  @override
  String get onboardingGenreArt => 'イラスト・創作';

  @override
  String get onboardingGenrePhoto => '写真';

  @override
  String get onboardingGenreFood => '食べ物';

  @override
  String get onboardingGenreTech => 'IT・プログラミング';

  @override
  String get onboardingGenreAnimal => '動物・ペット';

  @override
  String get onboardingGenreSports => 'スポーツ';

  @override
  String get onboardingGenreTravel => '旅行・おでかけ';

  @override
  String get onboardingGenreBooks => '本・読書';

  @override
  String get onboardingGenreMovie => '映画・ドラマ';

  @override
  String get onboardingGenreNature => '季節・自然';

  @override
  String onboardingPasswordTooShort(int min) {
    return '$min 文字以上にしてください';
  }

  @override
  String get onboardingPasswordTooLong => '256 文字までです';

  @override
  String get onboardingPasswordRepeated => '同じ字の繰り返しは使えません';

  @override
  String get onboardingTermsOutdated =>
      '利用規約が新しくなっています。アプリを更新してから、もう一度登録してください';

  @override
  String get onboardingNoServer => 'RASQ サーバーの接続先が設定されていません';

  @override
  String get onboardingHandleTaken => 'このユーザー名はもう使われています';

  @override
  String onboardingHandleUnusable(String error) {
    return 'このユーザー名は使えません($error)';
  }

  @override
  String onboardingHandleKept(String reason, String handle) {
    return '$reason。ユーザー名は @$handle のままです(プロフィールの編集で変えられます)';
  }

  @override
  String onboardingPasswordSetFailed(String error) {
    return 'アカウントは作成しましたが、パスワードを設定できませんでした($error)。設定 →「アカウントの保護」から設定してください';
  }

  @override
  String get onboardingRestored => 'この端末の RASQ アカウントへ戻りました';

  @override
  String get onboardingNudgeTitle => 'RASQ アカウントを作りますか?';

  @override
  String get onboardingNudgeMessage =>
      'RASQ アカウントがあると、入れたプラグインや設定・SNS のアカウントのまとまりを、ほかの端末でも使えます。Swing や RASQ リストも RASQ アカウントから使います。あとからサイドバーの … でも作れます。';

  @override
  String get onboardingNudgeCreate => '作る';

  @override
  String get onboardingNudgeLogin => 'ログイン(持っている人)';

  @override
  String get onboardingNudgeLater => 'あとで';

  @override
  String onboardingNudgeCreated(String handle) {
    return 'RASQ アカウント @$handle を作成しました';
  }

  @override
  String get onboardingFeedTitle => '公開 RASQ リストから';

  @override
  String get onboardingFeedCaption => 'SNS をまたいだ人のリストで、よく読まれている投稿です';

  @override
  String get onboardingFeedEmpty => 'いまは表示できる投稿がありません';

  @override
  String onboardingFeedListName(String name) {
    return 'リスト「$name」';
  }

  @override
  String get onboardingDiscoverTitle => 'SNS サービスを探す';

  @override
  String get onboardingDiscoverIntro =>
      '好きなものから、合いそうな SNS のサーバーと RASQ リスト(SNS をまたいだ人のリスト)を探します。';

  @override
  String get onboardingDiscoverContentTitle => '好きな画像やコンテンツから探す';

  @override
  String get onboardingDiscoverContentSubtitle => '画像を選んで、探したい部分を囲んで';

  @override
  String get onboardingDiscoverPeopleTitle => '有力なユーザー / インフルエンサーから探す';

  @override
  String get onboardingDiscoverPeopleSubtitle => '好きな人の名前や分野から';

  @override
  String get onboardingDiscoverExportTitle => '外部 SNS のエクスポートデータから探す';

  @override
  String get onboardingDiscoverExportSubtitle => '準備中';

  @override
  String get onboardingDiscoverAskTitle => 'RAi に聞く';

  @override
  String get onboardingDiscoverAskSubtitle => 'どんな SNS が合うか、話しながら探します';

  @override
  String get onboardingDiscoverRaiBlocked => '保護者が RAi を止めています';

  @override
  String onboardingDiscoverCannotLogin(String host) {
    return '$host には、アプリからログインできません';
  }

  @override
  String onboardingDiscoverCannotSignup(String host) {
    return '$host には、アプリから登録できません';
  }

  @override
  String get onboardingDiscoverAddAccountBlocked => '保護者が SNS アカウントの追加を止めています';

  @override
  String get onboardingDiscoverDummyResult => '見本の結果です(サーバーの外部サービスが未設定)';

  @override
  String get onboardingDiscoverPeopleWebHeading => 'SNS の人(Web 検索)';

  @override
  String get onboardingDiscoverListsHeading => 'RASQ リスト';

  @override
  String get onboardingDiscoverServersHeading => 'サーバー';

  @override
  String onboardingDiscoverListMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverListOwner(String handle) {
    return '@$handle のリスト';
  }

  @override
  String onboardingDiscoverListHosts(String hosts) {
    return 'サーバー: $hosts';
  }

  @override
  String get onboardingDiscoverListSeparator => '、';

  @override
  String get onboardingDiscoverListOpenImport => 'リストを開いて取り込む';

  @override
  String get onboardingDiscoverListSignup => 'リストの人のサーバーに登録';

  @override
  String get onboardingDiscoverLoginButton => 'ログイン';

  @override
  String get onboardingDiscoverSignupButton => '登録する';

  @override
  String get onboardingDiscoverSearchFailed => 'うまく探せませんでした。時間をおいて、もう一度試してください';

  @override
  String get onboardingDiscoverGlimpseStoppedSystem =>
      '画面の読み取りが止められました(端末の「共有を停止」や画面のロック)。もう一度「いつものブラウザで見て探す」から始めてください';

  @override
  String get onboardingDiscoverGlimpseStoppedShort =>
      '配信がすぐに止まったので、読み取れませんでした。ブラウザで探したい画面を開いてから止めてください';

  @override
  String get onboardingDiscoverGlimpseStoppedTimeout =>
      '10 分たったので、画面の読み取りの準備を止めました';

  @override
  String get onboardingDiscoverGlimpseStoppedKilled =>
      '画面の読み取りが端末に止められました。もう一度始めてください';

  @override
  String get onboardingDiscoverGlimpseStoppedEmpty =>
      '画面を読み取れませんでした(写しが取れませんでした)';

  @override
  String get onboardingDiscoverGlimpseFailed => '画面を読み取れませんでした';

  @override
  String get onboardingDiscoverGlimpseBroadcastDenied =>
      '画面の配信が始まりませんでした。読み取るには、もう一度押して「ブロードキャストを開始」を選んでください(読み取るのは配信を止める直前の 3 秒だけです)';

  @override
  String get onboardingDiscoverGlimpseDenied =>
      '画面の読み取りが許可されませんでした。読み取るには、もう一度押して「開始」を選んでください(読み取るのはボタンを押したあとの 3 秒だけです)';

  @override
  String get onboardingDiscoverGlimpseNotificationsDenied =>
      '通知を出せませんでした。読み取りのボタンは通知に出るので、端末の設定で RASQ の通知を許可してください';

  @override
  String get onboardingDiscoverGlimpseUnavailable =>
      'この端末では画面を読み取れません。画像を選ぶか、アプリの中のブラウザで探してください';

  @override
  String get onboardingDiscoverNotificationFailed =>
      '通知を出せませんでした。端末の設定で RASQ の通知を許可してください';

  @override
  String get onboardingDiscoverGlimpseResultMissing =>
      '読み取った画面が見つかりませんでした(時間がたって消えたか、もう送りました)';

  @override
  String onboardingDiscoverPicksFull(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '画像は $max 枚までです。外してから追加してください',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickFailed => '画像を読み込めませんでした';

  @override
  String onboardingDiscoverPicksOver(int over, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      over,
      locale: localeName,
      other: '画像は $max 枚までです。$over 枚は追加しませんでした',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPicksUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '読み込めない画像が $count 枚ありました',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverNoticeSeparator => '。';

  @override
  String onboardingDiscoverPicksSkipped(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '送れる大きさ(1 枚 10 MiB・合計 24 MiB・$max 枚まで)に収まらない画像を $count 枚外しました',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverImageFormat => 'JPEG / PNG / WebP の画像を選んでください';

  @override
  String get onboardingDiscoverImageFormatSize =>
      'JPEG / PNG / WebP の 10 MiB までの画像を選んでください';

  @override
  String get onboardingDiscoverNoCentral => 'RASQ Central の接続先が未設定です';

  @override
  String get onboardingDiscoverContentIntro =>
      '好きな画像を選んで、探したい部分を囲むと、探す言葉を RAi が作ります。画像はサーバーに保存しません(探し終えたら捨てます)。';

  @override
  String onboardingDiscoverPicksCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count / $max 枚。タップで囲み直し、長押しで並べ替えます',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickImages => '画像を選ぶ';

  @override
  String get onboardingDiscoverAddImages => '画像を追加';

  @override
  String get onboardingDiscoverTakePhoto => '写真を撮る';

  @override
  String get onboardingDiscoverSearchOne => 'この画像で探す';

  @override
  String onboardingDiscoverSearchMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'この $count 枚で探す',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverOtherWays => 'ほかの方法';

  @override
  String get onboardingDiscoverGlimpseButton => 'いつものブラウザで見て探す';

  @override
  String get onboardingDiscoverBrowseButton => 'アプリの中のブラウザで探す';

  @override
  String get onboardingDiscoverGlimpseCancel => 'やめる';

  @override
  String onboardingDiscoverGlimpseCapturing(int elapsed, int total) {
    return '画面を読み取っています($elapsed / $total 秒)';
  }

  @override
  String onboardingDiscoverGlimpseDone(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '画面を $seconds 秒読み取りました($frames コマ)',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverGlimpseDoneDummy(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '画面を $seconds 秒読み取りました($frames コマ)。いまは試作のため、ダミーの写しです',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPictureIndex(int index) {
    return '$index 枚目';
  }

  @override
  String onboardingDiscoverFrameIndex(int index) {
    return '$index コマ目';
  }

  @override
  String get onboardingDiscoverQueryHeading => '探す言葉';

  @override
  String get onboardingDiscoverNoResults => '合うリストやサーバーは見つかりませんでした';

  @override
  String get onboardingDiscoverPickWhole => '全体';

  @override
  String get onboardingDiscoverPickRect => '四角';

  @override
  String get onboardingDiscoverPickLasso => 'なぞり';

  @override
  String get onboardingDiscoverPickRemove => '外す';

  @override
  String get onboardingDiscoverGlimpseDummyNote =>
      'いまは試作のため、画面は読まずにダミーの写しを送ります';

  @override
  String get onboardingDiscoverCaptureFailed => 'この画面を読み取れませんでした';

  @override
  String get onboardingDiscoverBrowseAddressHint => '調べたい言葉 / URL';

  @override
  String get onboardingDiscoverBrowseCapture => 'この画面から探す';

  @override
  String get onboardingDiscoverManualIntro =>
      'この端末では、アプリの中でブラウザを開けません。いつものブラウザで見て、ページの URL と気になった文を貼り付けてください。';

  @override
  String get onboardingDiscoverManualOpenBrowser => 'ブラウザを開く';

  @override
  String get onboardingDiscoverManualUrl => 'ページの URL';

  @override
  String get onboardingDiscoverManualText => '気になった文(任意)';

  @override
  String get onboardingDiscoverManualSubmit => 'この内容で探す';

  @override
  String get onboardingDiscoverPeopleIntro =>
      '好きな人の名前や、気になる分野を入れてください。まず公開の RASQ リストの中から探します。';

  @override
  String get onboardingDiscoverPeopleQueryLabel => '人の名前 / 分野';

  @override
  String get onboardingDiscoverPeopleQueryHint => '例: 鉄道写真、イラストレーター';

  @override
  String get onboardingDiscoverPeopleSearch => '探す';

  @override
  String get onboardingDiscoverPeopleNotFound => 'RASQ リストでは見つかりませんでした';

  @override
  String get onboardingDiscoverPeopleNotFoundHint =>
      '好きな画像やページから探すか、RAi に聞いてみてください。';

  @override
  String get onboardingDiscoverPeopleTryContent => '画像やコンテンツから探す';

  @override
  String get onboardingDiscoverPeopleBrave =>
      'RASQ リストに無かったので、Web 検索から見つけた候補です';

  @override
  String get onboardingDiscoverPersonOpenProfile => 'プロフィールをブラウザで開く';

  @override
  String get onboardingDiscoverPersonLists => 'この人が入っている RASQ リスト';

  @override
  String get onboardingDiscoverAskFailed => 'うまく答えられませんでした。時間をおいて、もう一度聞いてください';

  @override
  String get onboardingDiscoverAskEmptyTitle => '合う SNS、一緒に探します！';

  @override
  String get onboardingDiscoverAskEmptyBody =>
      '好きなこと・見たいもの・どんな人とつながりたいかを教えてください。合いそうな SNS のサーバーと RASQ リストを探します。';

  @override
  String get onboardingDiscoverAskEmptyCloud =>
      '会話は RASQ のサーバーの RAi(クラウド)に送ります。';

  @override
  String get onboardingDiscoverAskModelLabel => 'クラウド版 RAi';

  @override
  String get onboardingDiscoverAskHint => 'どんなことが好きですか?';

  @override
  String get onboardingDiscoverEditorTitle => '囲って検索';

  @override
  String onboardingDiscoverEditorTitleStep(String step) {
    return '囲って検索($step)';
  }

  @override
  String get onboardingDiscoverEditorHint =>
      '探したい部分を囲んでください。囲まずに決定すると、画像全体で探します。2 本の指で拡大・移動できます。';

  @override
  String get onboardingDiscoverEditorHintSelected =>
      '囲んだ部分だけを切り抜いて探します。描き直すと囲みを置き換えます。';

  @override
  String get onboardingDiscoverEditorToolRect => '四角';

  @override
  String get onboardingDiscoverEditorToolLasso => 'なぞる';

  @override
  String get onboardingDiscoverEditorResetView => '元の大きさに戻す';

  @override
  String get onboardingDiscoverEditorClear => '囲みを消す';

  @override
  String get onboardingDiscoverEditorDoneWhole => '決定(画像全体)';

  @override
  String get onboardingDiscoverEditorDone => '決定';

  @override
  String get onboardingDiscoverGlimpseArmedBroadcast =>
      '画面の配信を始めました。ブラウザで探したい画面を開いたら、画面上部の赤い表示(またはコントロールセンター)から配信を止めてください。止める直前の 3 秒だけを読み取り、RASQ に戻ると結果が出ます。';

  @override
  String get onboardingDiscoverGlimpseArmedNotification =>
      '通知を出しました。ブラウザで探したい画面を開いてから、通知をタップしてください。タップすると、その画面を 3 秒だけ読み取ります。';

  @override
  String get onboardingDiscoverGlimpseNotificationTitle => 'RASQ で探す';

  @override
  String get onboardingDiscoverGlimpseNotificationBody =>
      'タップすると、いま見ている画面を 3 秒だけ読み取ります';

  @override
  String get onboardingDiscoverApiImageFormat => 'jpeg / png / webp の画像だけ送れます';

  @override
  String get onboardingDiscoverApiImageSize => '画像は 10 MiB までです';

  @override
  String get onboardingDiscoverApiImageAndFrames => '画像とコマは一緒に送れません';

  @override
  String onboardingDiscoverApiFramesCount(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'コマは $max 枚までです',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverApiFrameFormat => 'jpeg / png / webp のコマだけ送れます';

  @override
  String get onboardingDiscoverApiFrameSize => 'コマは 1 枚 10 MiB までです';

  @override
  String get onboardingDiscoverApiFramesTotal => 'コマは合計 24 MiB までです';

  @override
  String get onboardingDiscoverApiEmpty => '画像・本文・URL のどれかが要ります';

  @override
  String get onboardingTourPageSnsTitle => 'いくつもの SNS を、ひとつの場所で';

  @override
  String get onboardingTourPageSnsBody =>
      'Misskey・Mastodon・Bluesky などのアカウントを、まとめて使えます。RASQ アカウントがあれば、設定やアカウントのまとまりを、ほかの端末でも使えます。';

  @override
  String get onboardingTourPageSnsPicture =>
      'Bluesky・Misskey・mixi2・Mastodon が RASQ にまとまる絵';

  @override
  String get onboardingTourPageTimelineTitle => 'タイムラインは、ノードで組み立てる';

  @override
  String get onboardingTourPageTimelineBody =>
      'ホームの TL は、ノードを並べて自分好みに組み立てられます。トレンドや Today も、ノードとして TL に置けます。';

  @override
  String get onboardingTourPageTimelineNote => 'TL の歯車から変えられます。';

  @override
  String get onboardingTourPageTimelinePicture =>
      '「SNS タイムライン」「トレンドを取得」「Today」のノードが縦に並んだ絵';

  @override
  String get onboardingTourPageTrendTitle => 'トレンドと Today';

  @override
  String get onboardingTourPageTrendBody =>
      'いま話題の言葉と投稿を、トレンドと Today で見られます。はじめは恐れ・嫌悪・怒りを 45% までに抑えているので、強い怒りや嫌悪の投稿は、おすすめ / トレンド / Today / 関連 TL で下がるか、出なくなります。';

  @override
  String get onboardingTourPageTrendNoteSupervised =>
      'この上限はいつでも変えられます。見守り中は、保護者の設定でさらに抑えます。';

  @override
  String get onboardingTourPageTrendNote => 'この上限はいつでも変えられます。';

  @override
  String get onboardingTourPageTrendPicture => '刺激性のレーダー';

  @override
  String get onboardingTourPageAstellTitle => 'ASTell で、声でつながる';

  @override
  String get onboardingTourPageAstellBody =>
      'ASTell は、声で話せるルームです。聞くだけの参加もでき、下の ASTell のタブから入れます。';

  @override
  String get onboardingTourPageAstellPicture => 'ASTell のアンテナと、話している印の波形';

  @override
  String get onboardingTourPageSwingTitle => 'Swing で、気軽に流す';

  @override
  String get onboardingTourPageSwingBody =>
      'Swing は、時間がたつと消える投稿です。フォロワーや RASQ リストの人に届き、1〜24 時間で消えます。';

  @override
  String get onboardingTourPageSwingNote => 'RASQ アカウントで使えます。';

  @override
  String get onboardingTourPageSwingPicture => 'Swing の丸いアイコンが並んだ絵';

  @override
  String get onboardingTourPageRaiTitle => '迷ったら RAi に';

  @override
  String get onboardingTourPageRaiBody =>
      'RAi は RASQ のアシスタントです。やりたいことを聞くと、ボタンの場所まで案内したり、代わりに操作したりします。';

  @override
  String get onboardingTourPageRaiPicture => 'RAi と吹き出し';

  @override
  String get onboardingTourPagePluginsTitle => 'プラグインで、広げる';

  @override
  String get onboardingTourPagePluginsBody =>
      'SNS も、表示も、機能も、プラグインで足せます。プラグインストアで探して入れられます。';

  @override
  String get onboardingTourPagePluginsPicture => 'プラグインのタイルが並んだ絵';

  @override
  String get onboardingTourTitle => 'RASQ の使い方';

  @override
  String get onboardingTourSkip => 'スキップ';

  @override
  String get onboardingTourBack => '戻る';

  @override
  String onboardingTourPageSemantics(int number, int total) {
    return '$number / $total ページ';
  }

  @override
  String get onboardingTourStart => 'はじめる';

  @override
  String get onboardingTourNext => '次へ';

  @override
  String get onboardingTourOpenTendency => 'いま設定を見る';

  @override
  String get onboardingTourNodeSnsTimeline => 'SNS タイムライン';

  @override
  String get onboardingTourNodeTrend => 'トレンドを取得';

  @override
  String get onboardingTourRaiBubble => 'TL にリストを足したい';

  @override
  String get pluginsCancel => 'キャンセル';

  @override
  String get pluginsClose => '閉じる';

  @override
  String get pluginsSwingNotPackage => 'Swing のプラグインは .rasqpkg か .wasm です';

  @override
  String get pluginsSwingNoRequires => 'Swing では、ほかのプラグインを土台にする子プラグインは配れません';

  @override
  String get pluginsSwingSingleOnly => 'Swing で配れるのは、プラグイン 1 つだけの入れ物です';

  @override
  String get pluginsPageNotPage => 'ページ型のプラグインではありません';

  @override
  String pluginsPageSwingRequires(String ids) {
    return 'ほかのプラグイン($ids)を土台にしているため、Swing では配れません';
  }

  @override
  String get pluginsPageSwingChild =>
      'ほかのプラグインの入れ物に入っている子プラグインのため、Swing では配れません';

  @override
  String pluginsPageSwingSiblings(String names) {
    return '子プラグイン($names)と一緒の入れ物のため、Swing では配れません';
  }

  @override
  String pluginsArtifactMismatch(String pluginId) {
    return '$pluginId: 取り直した配布物がインストール時と違うため読み込みません(ストアで入れ直してください)';
  }

  @override
  String pluginsIsSnsPlugin(String id) {
    return '$id は SNS プラグインです(スロットには登録できません)';
  }

  @override
  String get pluginsManifestMissing => 'plugin.manifest がありません';

  @override
  String get pluginsManifestIdEmpty => 'plugin.manifest.id が空です';

  @override
  String get pluginsSwingSurfaceOnly =>
      'Swing で配れるのは、Swing の面(surfaces: swing、solo)のページ型だけです';

  @override
  String get pluginsRasqPageSurfaceOnly =>
      'RASQ のページに置けるのは、プロフィールの面(surfaces: profile、solo)のページ型だけです';

  @override
  String pluginsIdMismatch(String expected, String actual) {
    return '配布物の目次は $expected なのに、wasm は $actual を名乗っています';
  }

  @override
  String pluginsRegistered(String name, String slots) {
    return '$name を登録しました($slots)';
  }

  @override
  String pluginsRegisterFailed(String error) {
    return '登録できませんでした: $error';
  }

  @override
  String pluginsImageReceiveFailed(String name, String error) {
    return '$name: 画像を受け取れませんでした($error)';
  }

  @override
  String pluginsSharedNoSession(String name) {
    return '$name: 共有セッションに入っていないため、みんなの値は変えられません';
  }

  @override
  String get pluginsMuteAddTitle => 'ミュート語に追加';

  @override
  String pluginsMuteAddMessage(String name, String word) {
    return '$name が「$word」をミュート語に追加しようとしています。';
  }

  @override
  String get pluginsMuteAddConfirm => '追加';

  @override
  String pluginsMuteAdded(String word) {
    return '「$word」をミュート語に追加しました';
  }

  @override
  String pluginsEffectSendFailed(String name, String error) {
    return '$name: 効果映像を送れませんでした($error)';
  }

  @override
  String pluginsImageScaled(String name) {
    return '$name: 編集のため画像を小さくしました';
  }

  @override
  String get pluginsErrorReturned => 'プラグインがエラーを返しました';

  @override
  String get pluginsGenreTone => '色調';

  @override
  String get pluginsGenreProcess => '加工';

  @override
  String get pluginsGenreTransform => '変形';

  @override
  String get pluginsGenreAdd => '追加';

  @override
  String get pluginsGenreDraw => '描画';

  @override
  String get pluginsTrustFull => 'フル';

  @override
  String get pluginsTrustBundled => 'フル(同梱)';

  @override
  String get pluginsTrustRestricted => '制限';

  @override
  String get pluginsTrustSwing => '制限(Swing)';

  @override
  String get pluginsTrustHint =>
      '自分の開発者鍵で署名した .rspkg / .rasqpkg はフル機能。rasq build が署名します';

  @override
  String get pluginsEditorCancel => 'キャンセル';

  @override
  String get pluginsEditorUndo => 'ひとつ戻す';

  @override
  String get pluginsEditorRedo => 'やり直す';

  @override
  String get pluginsEditorDone => '完了';

  @override
  String get pluginsEditorRemove => '削除';

  @override
  String get pluginsEditorBack => '戻る';

  @override
  String get pluginsEditorMore => 'その他';

  @override
  String get pluginsEditorApplying => '変更を適用しています';

  @override
  String get pluginsEditorPreparing => 'エディターを準備しています';

  @override
  String get pluginsEditorPleaseWait => 'お待ちください…';

  @override
  String get pluginsEditorCloseWarningTitle => '加工をやめますか？';

  @override
  String get pluginsEditorCloseWarningMessage => '変更は保存されません。';

  @override
  String get pluginsEditorCloseWarningConfirm => 'やめる';

  @override
  String get pluginsEditorCloseWarningCancel => '続ける';

  @override
  String get pluginsEditorLayerEdit => '編集';

  @override
  String get pluginsEditorLayerRotateScale => '回転と拡縮';

  @override
  String get pluginsEditorPaint => 'ペイント';

  @override
  String get pluginsEditorZoom => 'ズーム';

  @override
  String get pluginsEditorFreehand => 'フリーハンド';

  @override
  String get pluginsEditorArrow => '矢印';

  @override
  String get pluginsEditorLine => '直線';

  @override
  String get pluginsEditorRectangle => '四角';

  @override
  String get pluginsEditorCircle => '丸';

  @override
  String get pluginsEditorDashLine => '点線';

  @override
  String get pluginsEditorBlur => 'ぼかし';

  @override
  String get pluginsEditorPixelate => 'モザイク';

  @override
  String get pluginsEditorLineWidth => '線の太さ';

  @override
  String get pluginsEditorEraser => '消しゴム';

  @override
  String get pluginsEditorFill => '塗り';

  @override
  String get pluginsEditorOpacity => '不透明度';

  @override
  String get pluginsEditorColor => '色';

  @override
  String get pluginsEditorTextHint => 'テキストを入力';

  @override
  String get pluginsEditorText => 'テキスト';

  @override
  String get pluginsEditorTextAlign => '揃え';

  @override
  String get pluginsEditorFontScale => '文字の大きさ';

  @override
  String get pluginsEditorTextBackground => '背景';

  @override
  String get pluginsEditorCropRotate => 'クロップ / 回転';

  @override
  String get pluginsEditorRotate => '回転';

  @override
  String get pluginsEditorFlip => '反転';

  @override
  String get pluginsEditorTilt => '傾き';

  @override
  String get pluginsEditorTiltHorizontal => '水平';

  @override
  String get pluginsEditorTiltVertical => '垂直';

  @override
  String get pluginsEditorRatio => '比率';

  @override
  String get pluginsEditorReset => 'リセット';

  @override
  String get pluginsEditorTune => '調整';

  @override
  String get pluginsEditorBrightness => '明るさ';

  @override
  String get pluginsEditorContrast => 'コントラスト';

  @override
  String get pluginsEditorSaturation => '彩度';

  @override
  String get pluginsEditorExposure => '露出';

  @override
  String get pluginsEditorHue => '色相';

  @override
  String get pluginsEditorTemperature => '色温度';

  @override
  String get pluginsEditorFade => 'フェード';

  @override
  String get pluginsEditorTint => 'ティント';

  @override
  String get pluginsEditorFilter => 'フィルター';

  @override
  String get pluginsEditorSticker => 'ステッカー';

  @override
  String get pluginsEditorEmoji => '絵文字';

  @override
  String get pluginsEditorEmojiSearch => '検索';

  @override
  String get pluginsEditorEmojiRecent => '最近';

  @override
  String get pluginsEditorEmojiSmileys => '顔と人';

  @override
  String get pluginsEditorEmojiAnimals => '動物と自然';

  @override
  String get pluginsEditorEmojiFood => '食べ物';

  @override
  String get pluginsEditorEmojiActivities => 'アクティビティ';

  @override
  String get pluginsEditorEmojiTravel => '旅行と場所';

  @override
  String get pluginsEditorEmojiObjects => 'もの';

  @override
  String get pluginsEditorEmojiSymbols => '記号';

  @override
  String get pluginsEditorEmojiFlags => '旗';

  @override
  String get pluginsMediaCancel => 'キャンセル';

  @override
  String get pluginsMediaClose => '閉じる';

  @override
  String get pluginsMediaApply => '適用';

  @override
  String pluginsMediaNotSvg(String name) {
    return '$name が SVG を返さなかったので、使いませんでした';
  }

  @override
  String get pluginsMediaPaperDoneMissing => 'いまは使えません(紙の「完了」が見つかりません)';

  @override
  String get pluginsMediaBarEdit => 'バーの編集';

  @override
  String get pluginsMediaAudioUnsupported =>
      'この端末では音声を動画にできません(Android / iOS / macOS だけ)。音声のまま添付できます';

  @override
  String pluginsMediaOpenAudioFailed(String error) {
    return '音声を開けませんでした: $error';
  }

  @override
  String pluginsMediaOpenVideoFailed(String error) {
    return '動画を開けませんでした: $error';
  }

  @override
  String pluginsMediaReexportFailed(String error) {
    return '動画を書き出し直せませんでした: $error';
  }

  @override
  String get pluginsMediaCropWithMovingObject =>
      'クロップ / 回転と、動くオブジェクトは一緒に使えません。静止画で入れました';

  @override
  String pluginsMediaExportFailed(String error) {
    return '動画を書き出せませんでした: $error';
  }

  @override
  String pluginsMediaOverlayFailed(String error) {
    return '動くオブジェクトを重ねられなかったので、静止画で入れました: $error';
  }

  @override
  String pluginsMediaFilterNotReceived(String label) {
    return '$label: フィルターを受け取れませんでした';
  }

  @override
  String pluginsMediaFilterDropped(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個',
    );
    return '$label: 描画が多すぎるので $_temp0を省きました';
  }

  @override
  String pluginsMediaFiltersFailed(String names) {
    return '適用できなかったフィルター: $names(この加工は入っていません)';
  }

  @override
  String get pluginsMediaCropWithMovingPost =>
      'クロップ / 回転と、動く投稿は一緒に使えません。投稿は静止画で入れました';

  @override
  String get pluginsMediaVideoImageUnreadable =>
      '動画にできなかったので、静止画で入れました(画像を読めませんでした)';

  @override
  String pluginsMediaVideoPostFailed(String error) {
    return '動画にできなかったので、投稿は静止画で入れました: $error';
  }

  @override
  String get pluginsMediaToVideoTitle => '動画に変換しますか?';

  @override
  String pluginsMediaToVideoMessage(String note) {
    return '$note\n「動画にする」と、置いた場所で動く動画として書き出します。「静止画で貼る」は今の画像だけを貼ります。';
  }

  @override
  String get pluginsMediaToVideoConfirm => '動画にする';

  @override
  String get pluginsMediaToVideoStill => '静止画で貼る';

  @override
  String get pluginsMediaImageUnreadable => '画像を読めませんでした';

  @override
  String get pluginsMediaExportOnDone => '完了すると、動画として書き出します';

  @override
  String get pluginsMediaObjectNote => 'ノート';

  @override
  String get pluginsMediaObjectVideo => '動画';

  @override
  String get pluginsMediaObjectImage => '画像';

  @override
  String get pluginsMediaAddImage => '画像を追加';

  @override
  String get pluginsMediaAddVideo => '動画を追加';

  @override
  String get pluginsMediaVideoLoadFailed => '動画を読み込めませんでした';

  @override
  String pluginsMediaVideoLoadFailedDetail(
    String ext,
    int bytes,
    String error,
  ) {
    return '動画(.$ext、$bytes バイト)の最初のコマを取れませんでした: $error';
  }

  @override
  String get pluginsMediaFirstFrameFailed => '動画の最初のコマを取れませんでした';

  @override
  String get pluginsMediaVideoAsObject => '動画をオブジェクトとして置きます。';

  @override
  String pluginsMediaAddFailed(String error) {
    return 'メディアを追加できませんでした: $error';
  }

  @override
  String get pluginsMediaAudioConverting => '音声を動画に変換しています…';

  @override
  String pluginsMediaPanelNotEditable(String name) {
    return '$name はここでは編集できません(プラグインのパネルで操作してください)';
  }

  @override
  String get pluginsMediaSnapDragUnset => 'この上にドラッグ(解除)';

  @override
  String get pluginsMediaSnapDragSet => 'この上にドラッグ(合わせる先にする)';

  @override
  String get pluginsMediaSnapPick => '合わせる先を選ぶ…';

  @override
  String get pluginsMediaSnapClearAll => '合わせる先をすべて解除';

  @override
  String get pluginsMediaSnapTitle => '合わせる先';

  @override
  String get pluginsMediaSnapEmpty => '名前の付いた枠がありません';

  @override
  String pluginsMediaSnapSize(int width, int height) {
    return '$width × $height';
  }

  @override
  String pluginsMediaSnapSizeAngle(int width, int height, int angle) {
    return '$width × $height、$angle°';
  }

  @override
  String get pluginsMediaPanelNoResult => '適用できませんでした(プラグインが結果を返しませんでした)';

  @override
  String get pluginsMediaPanelNoEdits => 'このプラグインに編集はありません';

  @override
  String pluginsMediaObjectEditSemantics(String title) {
    return '$title の編集';
  }

  @override
  String get pluginsMediaObjectLoop => '繰り返し再生';

  @override
  String get pluginsMediaObjectLoopSubtitle => 'オフ = 終わったら最後のコマで止まる';

  @override
  String get pluginsMediaObjectSpeed => '再生の速さ';

  @override
  String get pluginsMediaObjectVolume => '音';

  @override
  String get pluginsMediaObjectMuted => '消音';

  @override
  String get pluginsMediaObjectOpacity => '不透明度';

  @override
  String get pluginsMediaObjectRemove => 'このオブジェクトを削除';

  @override
  String pluginsMediaFilterAdjustSemantics(String title) {
    return '$title の調整';
  }

  @override
  String get pluginsMediaFilterObjectHint => '絵の上で、ドラッグで移動、つまんで拡縮 / 回転できます。';

  @override
  String get pluginsMediaFilterRemove => 'このフィルターを外す';

  @override
  String get pluginsMediaStickerEmpty => 'ステッカーがありません。ストアで入れると、ここに並びます';

  @override
  String get pluginsMediaStickerEmptyDetail =>
      'ステッカーがありません。ストアでアセットパック(カテゴリ「assets」)を入れると、ここに並びます。';

  @override
  String get pluginsMediaStickerGenerate => 'プラグインで作る';

  @override
  String get pluginsPaintTitle => '落書き';

  @override
  String get pluginsPaintCancel => 'キャンセル';

  @override
  String get pluginsPaintDone => '完了';

  @override
  String get pluginsPaintCanvasSemantics => '落書きの紙';

  @override
  String get pluginsPaintFillLeak => '線で閉じた形の中をタップしてください';

  @override
  String get pluginsPaintFillOnLine => '線の内側をタップしてください';

  @override
  String get pluginsPaintFillEmpty => '塗れる形がありませんでした';

  @override
  String get pluginsPaintToolPen => 'ペン';

  @override
  String get pluginsPaintToolEraser => '消しゴム';

  @override
  String get pluginsPaintToolLasso => '投げ輪';

  @override
  String get pluginsPaintToolFill => '塗る';

  @override
  String get pluginsPaintUndo => '取り消し';

  @override
  String get pluginsPaintRedo => 'やり直し';

  @override
  String get pluginsPaintClear => '全部消す';

  @override
  String get pluginsPaintStabilizer => '手ぶれ補正';

  @override
  String get pluginsPaintStabilizerOff => '切';

  @override
  String get pluginsPaintEraserCut => '切る';

  @override
  String get pluginsPaintEraserWhole => '線ごと';

  @override
  String get pluginsPaintLassoHint => '囲んで選ぶ(線の半分以上が入ったもの)';

  @override
  String get pluginsPaintSelectionDelete => '削除';

  @override
  String get pluginsPaintSelectionDuplicate => '複製';

  @override
  String get pluginsPaintSelectionRecolor => '色を変える';

  @override
  String get pluginsPaintSelectionDeselect => '解除';

  @override
  String get pluginsPaintFillHint => '線で閉じた形の中をタップすると、線の下に塗ります';

  @override
  String pluginsPaintWidthSemantics(String width) {
    return '太さ $width';
  }

  @override
  String pluginsPaintColorSemantics(String color) {
    return '色 $color';
  }

  @override
  String get pluginsPaintNibMili => 'ミリペン';

  @override
  String get pluginsPaintNibKabura => 'カプラペン';

  @override
  String get pluginsPaintNibBrush => 'ブラシニブ';

  @override
  String get profileEditTitle => 'プロフィールの更新';

  @override
  String get profileEditSave => '決定';

  @override
  String get profileEditNotLoggedIn => 'RASQ アカウントにログインしていません。';

  @override
  String get profileEditBannerRemove => 'バナーを外す';

  @override
  String get profileEditBannerPick => 'バナーを選ぶ';

  @override
  String get profileEditAvatarPick => 'アイコンを選ぶ';

  @override
  String get profileEditAvatarRemove => 'アイコンを外す';

  @override
  String get profileEditPickImage => '画像を選択';

  @override
  String get profileEditNameHint => '名前を入力..';

  @override
  String get profileEditBirthdayHint => '誕生日 (YYYY-MM-DD / MM-DD)';

  @override
  String get profileEditBirthdayHintSns => '誕生日 (YYYY-MM-DD)';

  @override
  String get profileEditHandleLabel => 'ハンドル(@ なし、a-z 0-9 _、3〜32 文字)';

  @override
  String get profileEditBioLabel => '自己紹介';

  @override
  String get profileEditBioHint => '自己紹介(500 文字まで)';

  @override
  String get profileEditLocationLabel => '場所';

  @override
  String get profileEditLinksLabel => 'リンク';

  @override
  String get profileEditLinkRemove => '削除';

  @override
  String get profileEditLinkCaptionHint => 'キャプション';

  @override
  String get profileEditLinkAdd => '追加';

  @override
  String get profileEditReload => '再読み込み';

  @override
  String get profileEditSnsTilesLabel => 'アカウントページに出す SNS アカウント';

  @override
  String get profileEditSnsTilesCaption =>
      '「自動」では、鍵アカウントなどは出しません。薄いタイルは、いま出ていないものです。';

  @override
  String get profileEditSnsTilesCaptionDetail =>
      '「自動」は、鍵アカウントと、直近の投稿の公開範囲がフォロワーのみに寄っているアカウントを出しません。薄いタイルは、いまは出ていないものです。変更はすぐ反映されます。';

  @override
  String profileEditSnsTileAuto(String state) {
    return '自動($state)';
  }

  @override
  String get profileEditSnsTileShown => '表示';

  @override
  String get profileEditSnsTileHidden => '非表示';

  @override
  String profileEditVerified(String method) {
    return '持ち主を確認済み($method)';
  }

  @override
  String get profileEditVerify => '持ち主を確認';

  @override
  String get profileEditShowOnSnsLabel => 'SNS のプロフィール';

  @override
  String get profileEditShowOnSnsTitle => 'SNS のプロフィールにも、つないだアカウントを出す';

  @override
  String get profileEditShowOnSnsSubtitle =>
      'RASQ で誰かがあなたの SNS のプロフィールを見たとき、つないだアカウントを出します。';

  @override
  String get profileEditShowOnSnsDetail =>
      'アプリで誰かがあなたの SNS のプロフィールを見たとき、この RASQ アカウントと、アカウントページに出しているほかのアカウントを出します。自己紹介に書いてあるものは重ねて出しません。変更はすぐ反映されます。';

  @override
  String get profileEditKeybaseConnect => 'Keybase をつなぐ';

  @override
  String get profileEditKeybaseConnectSubtitle =>
      'Keybase で本人確認して、アカウントページに出します';

  @override
  String get profileEditKeybaseLinkedSubtitle => '確認済み。アカウントページに出ます';

  @override
  String get profileEditNotice =>
      'プロフィールは、公開ページとストアのレビューに出ます。メールとパスワードは「セキュリティ」から。';

  @override
  String get profileEditNoticeDetail =>
      'プロフィールは、RASQ の公開ページとストアのレビューに出ます。画像はサーバーで縮めて保存し直します(位置情報などは残りません)。メールアドレスとパスワードは「セキュリティ」から。';

  @override
  String get profileEditErrorHandleTaken => 'そのハンドルは使われています';

  @override
  String get profileEditErrorHandle => 'ハンドルは 3〜32 文字の a-z 0-9 _ にしてください';

  @override
  String get profileEditErrorBirthday => '誕生日は YYYY-MM-DD か MM-DD の形で入れてください';

  @override
  String get profileEditErrorLink =>
      'リンクは、キャプション(40 文字まで)と http(s) の URL の組にしてください(8 組まで)';

  @override
  String get profileEditErrorImage =>
      'その画像は使えません(PNG / JPEG / WebP / GIF、8 MiB まで)';

  @override
  String get profileEditErrorBio => '自己紹介は 500 文字までです';

  @override
  String get profileEditErrorLocation => '場所は 60 文字までです';

  @override
  String profileEditErrorFailed(String message) {
    return '更新に失敗しました: $message';
  }

  @override
  String get profileEditSnsPostsWithdrawn => '預けた鍵と、取ってきた投稿を消しました';

  @override
  String profileEditSnsPostsWithdrawFailed(String message) {
    return '消せませんでした: $message';
  }

  @override
  String get profileEditSnsPostsNoLogin => 'この端末に、そのアカウントのログインがありません';

  @override
  String get profileEditSnsPostsNoDid => 'このアカウントの DID が分かりません。ログインし直してください';

  @override
  String get profileEditSnsPostsBlueskyConsentTitle =>
      'Bluesky の投稿をアカウントページに出します';

  @override
  String profileEditSnsPostsBlueskyConsentMessage(String account) {
    return '$account の投稿を、RASQ のサーバーが Bluesky の公開の API から読み、**RASQ のアカウントページで誰でも見られる状態**にします。\n\n・Bluesky の投稿は、もともと誰でも読めます。返信とリポストは取り込みません。\n・**ログインの鍵(アプリパスワード / セッション)は預けません**。サーバーに渡すのは、このアカウントの DID とハンドルだけです。\n・使えるのは、持ち主の確認が済んだアカウントだけです(他人のアカウントの投稿を出せないように)。\n・このスイッチを切ると、取ってきた投稿は、すぐに消えます。';
  }

  @override
  String get profileEditSnsPostsAgreeShow => '同意して出す';

  @override
  String get profileEditCancel => 'やめる';

  @override
  String get profileEditSnsPostsTokenConsentTitle => 'ログインの鍵を RASQ に預けます';

  @override
  String profileEditSnsPostsTokenConsentMessage(String account) {
    return '$account の投稿をアカウントページに出すために、この SNS の**ログインの鍵(アクセストークン)を RASQ のサーバーに預けます**。\n\n・あなたの「公開」と「ホーム(未収載)」の投稿が、**RASQ のアカウントページで誰でも見られる状態**になります。「ホーム」はフォロワー限定ではありません。\n・フォロワー限定 / 指名・DM / ローカルのみ / 公開範囲が分からない投稿は、取り込みません。\n・鍵は、あなたの投稿を読むためだけに使います。投稿・フォローなどの操作や、ほかの目的には使いません。\n・鍵はサーバーの鍵で暗号化して保存します(RASQ のサーバーは復号できます)。アプリにも他の人にも返しません。\n・このスイッチを切ると、預けた鍵と取ってきた投稿は、すぐに消えます。\n\nこの鍵があれば、そのアカウントを操作できます。心配なときは、預けたあとでも SNS 側の設定からこの鍵(トークン)を無効にできます。';
  }

  @override
  String get profileEditSnsPostsAgreeDeposit => '同意して預ける';

  @override
  String profileEditSnsPostsFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の投稿を取ってきました',
    );
    return '$_temp0';
  }

  @override
  String profileEditSnsPostsFetchFailed(String error) {
    return '預けましたが、投稿を取れませんでした($error)';
  }

  @override
  String get profileEditSnsPostsUnsupported => 'このサーバーでは、まだ使えません';

  @override
  String get profileEditSnsPostsVerifyFirst => '先に、このアカウントの「持ち主の確認」を済ませてください';

  @override
  String profileEditSnsPostsDepositFailed(String message) {
    return '預けられませんでした: $message';
  }

  @override
  String get profileEditSnsPostsSwitchTitle => '投稿もアカウントページに出す';

  @override
  String profileEditSnsPostsFetchError(String error) {
    return '取得に失敗しています: $error';
  }

  @override
  String profileEditSnsPostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件(公開 / ホームの投稿。30 分ごとに更新)',
    );
    return '$_temp0';
  }

  @override
  String get profileEditSnsPostsBlueskySubtitle =>
      'RASQ のサーバーが Bluesky の公開の投稿を読みます(鍵は預けません)';

  @override
  String get profileEditSnsPostsTokenSubtitle =>
      'SNS のログインの鍵を RASQ に預けます(入れるときに確認が出ます)';

  @override
  String get profileEditSnsPostsCollectionsTitle => 'この鍵を RASQ リストにも使う';

  @override
  String get profileEditSnsPostsCollectionsSubtitle =>
      '開いた RASQ リストの取得と、見られるかの確認に使います';

  @override
  String get profileEditSnsPostsCollectionsDetail =>
      'RASQ リスト・クリップを開いたとき、この鍵で SNS に「リストの人をフォローしているか」を問い合わせ、中の人の公開の投稿を取りに行く。投稿の表示のために預けた鍵とは別の目的なので、別に選ぶ(既定はオフ、選ぶ / やめるは同意の記録に残る)。';

  @override
  String get profileEditSnsPostsCollectionsConsentTitle =>
      '預けた鍵を RASQ リストにも使います';

  @override
  String get profileEditSnsPostsCollectionsConsentMessage =>
      '投稿の表示のために預けた鍵を、別の目的にも使います。\n\n・RASQ リストやクリップを開いたとき、この鍵で SNS に「リストの人をフォローしているか」を問い合わせます(見られるかの確認)。\n・リストの人の公開 / ホームの投稿を、この鍵で取りに行きます。\n・投稿・フォローなどの操作には使いません。\n・このスイッチを切ると、すぐに使わなくなります。';

  @override
  String get profileEditSnsPostsCollectionsAgree => '同意して使う';

  @override
  String profileEditSnsPostsCollectionsFailed(String message) {
    return '変えられませんでした: $message';
  }

  @override
  String get profileOwnershipWhereMisskey =>
      '自己紹介か、プロフィールの「追加情報」のどれかに貼って、保存してください。';

  @override
  String get profileOwnershipWhereMastodon =>
      '自己紹介か、プロフィールの「補足情報」のどれかに貼って、保存してください。';

  @override
  String get profileOwnershipWhereBluesky => '自己紹介(プロフィールの説明)に貼って、保存してください。';

  @override
  String get profileOwnershipWhereFields => '自己紹介か、プロフィールの項目のどれかに貼って、保存してください。';

  @override
  String get profileOwnershipWhereBio => '自己紹介に貼って、保存してください。';

  @override
  String get profileOwnershipErrorNotLinked =>
      'この SNS アカウントは、RASQ アカウントにつながっていません';

  @override
  String get profileOwnershipErrorUnsupported => 'この SNS は、まだ持ち主の確認に対応していません';

  @override
  String get profileOwnershipErrorTooMany => '試す回数が多すぎます。しばらく待ってから、もう一度お試しください';

  @override
  String get profileOwnershipErrorNotStarted =>
      'まだ確認の文を作っていないか、期限が切れています。「確認の文を作る」からやり直してください';

  @override
  String get profileOwnershipErrorCodeNotFound =>
      'プロフィールに確認の文が見つかりませんでした。保存したか、公開のプロフィールに出ているかを確かめてください(反映まで少しかかることがあります)';

  @override
  String get profileOwnershipErrorProfileNotFound =>
      'その SNS アカウントの公開のプロフィールが見つかりませんでした';

  @override
  String get profileOwnershipErrorReadFailed =>
      'その SNS のプロフィールを読めませんでした。少し待ってから、もう一度お試しください';

  @override
  String profileOwnershipErrorFailed(String message) {
    return '確認できませんでした: $message';
  }

  @override
  String get profileOwnershipKeybaseErrorUsername =>
      'Keybase のユーザー名(英小文字・数字・_、2〜16 文字)を入れてください';

  @override
  String get profileOwnershipKeybaseErrorSignature =>
      '署名を読めませんでした。BEGIN KEYBASE SALTPACK SIGNED MESSAGE から END KEYBASE SALTPACK SIGNED MESSAGE. までを、そのまま貼ってください';

  @override
  String get profileOwnershipKeybaseErrorStatement =>
      '署名した文が違います。上のコマンドを、そのまま使ってください';

  @override
  String get profileOwnershipKeybaseErrorKey => 'その Keybase のユーザーの鍵で署名されていません';

  @override
  String get profileOwnershipKeybaseErrorNoUser =>
      'その Keybase のユーザーは見つかりませんでした';

  @override
  String get profileOwnershipKeybaseErrorOtherAccount =>
      'その Keybase は、別の RASQ アカウントにつながっています';

  @override
  String get profileOwnershipKeybaseErrorExpired =>
      '文の期限が切れたか、まだ作っていません。「署名する文を作る」からやり直してください';

  @override
  String get profileOwnershipKeybaseErrorUnreachable =>
      'Keybase に繋がりませんでした。少し待ってから、もう一度お試しください';

  @override
  String profileOwnershipKeybaseErrorFailed(String message) {
    return '確かめられませんでした: $message';
  }

  @override
  String get profileOwnershipVerifyTitle => '持ち主を確認';

  @override
  String get profileOwnershipNotLinked => 'この SNS アカウントは、RASQ アカウントにつながっていません。';

  @override
  String profileOwnershipVerified(String method) {
    return '確認済み($method)';
  }

  @override
  String get profileOwnershipJustVerified =>
      '確認できました。プロフィールに貼った文は、もう消してかまいません。';

  @override
  String get profileOwnershipVerifiedCaption =>
      'アカウントページと SNS のプロフィールに、確認済みの印が付きます。';

  @override
  String get profileOwnershipVerifiedCaptionDetail =>
      'アカウントページと、SNS のプロフィールに出る RASQ アカウントの欄に、確認済みの印が付きます。この SNS アカウントを外すまで続きます。';

  @override
  String get profileOwnershipUnsupportedKind =>
      'この SNS は、まだ本人確認に対応していません(Misskey / Mastodon / Bluesky のみ)。';

  @override
  String get profileOwnershipIntro =>
      'この SNS アカウントがあなたのものか確かめます。プロフィールに確認の文を一時的に貼ってください。';

  @override
  String get profileOwnershipIntroDetail =>
      'この SNS アカウントが、あなたのものかを確かめます。確認の文をその SNS のプロフィールに一時的に貼ってもらい、RASQ がその公開のプロフィールを読んで確かめます。';

  @override
  String get profileOwnershipEffect => '確かめると、確認済みの印が付きます。';

  @override
  String get profileOwnershipEffectDetail =>
      '確かめると、アカウントページと SNS のプロフィールの RASQ アカウントの欄に、確認済みの印が付きます。同じ SNS アカウントをほかの人がつないでいても、確認した人が優先されます。';

  @override
  String get profileOwnershipStart => '確認の文を作る';

  @override
  String get profileOwnershipStep1 => '1. この文をコピーする';

  @override
  String get profileOwnershipCopied => '確認の文をコピーしました';

  @override
  String get profileOwnershipCopy => 'コピー';

  @override
  String profileOwnershipValidUntil(String time) {
    return '$time まで有効';
  }

  @override
  String get profileOwnershipStep2 => '2. その SNS のプロフィールに貼る';

  @override
  String get profileOwnershipNoRewrite =>
      'RASQ からプロフィールを書き換えることはしません。その SNS で、ご自分で貼ってください。';

  @override
  String get profileOwnershipStep3 => '3. 貼ったら「確認する」';

  @override
  String get profileOwnershipCheck => '確認する';

  @override
  String get profileOwnershipRestart => '文を作り直す';

  @override
  String get profileOwnershipKeybaseNoLinks =>
      'Keybase の証明に、つないでいる SNS アカウントはありませんでした。';

  @override
  String profileOwnershipKeybaseLinksVerified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keybase の証明で、つないでいる SNS アカウント $count 件も確認済みになりました。',
    );
    return '$_temp0';
  }

  @override
  String profileOwnershipKeybaseLinked(String username, String links) {
    return '@$username をつなぎました。$links';
  }

  @override
  String get profileOwnershipKeybaseUnlinked =>
      'Keybase を外しました。Keybase の証明で確認していた SNS アカウントは、未確認に戻ります。';

  @override
  String profileOwnershipKeybaseVerifiedAt(String time) {
    return '$time に確認';
  }

  @override
  String profileOwnershipKeybaseCaption(String username) {
    return 'アカウントページに「Keybase: @$username」が出ます。';
  }

  @override
  String profileOwnershipKeybaseCaptionDetail(String username) {
    return 'アカウントページに「Keybase: @$username」が出ます。Keybase で Mastodon などの証明を足したら、「証明を読み直す」で、つないでいる SNS アカウントも確認済みになります。';
  }

  @override
  String get profileOwnershipKeybaseRefresh => '証明を読み直す';

  @override
  String get profileOwnershipKeybaseUnlink => 'Keybase を外す';

  @override
  String get profileOwnershipKeybaseIntro =>
      'Keybase で署名して、この RASQ アカウントとつなぎます。つないだ Keybase は公開されます。';

  @override
  String get profileOwnershipKeybaseIntroDetail =>
      'Keybase のアカウントで署名して、この RASQ アカウントとつなぎます。つないだ Keybase は、アカウントページに出ます(Keybase のプロフィールと同じく公開です)。';

  @override
  String get profileOwnershipKeybaseUsername => 'Keybase のユーザー名';

  @override
  String get profileOwnershipKeybaseStart => '署名する文を作る';

  @override
  String get profileOwnershipKeybaseStep1 => '1. Keybase が入っている端末で、このコマンドを実行する';

  @override
  String get profileOwnershipKeybaseCopied => 'コマンドをコピーしました';

  @override
  String profileOwnershipKeybaseStatement(String statement) {
    return '署名する文: $statement';
  }

  @override
  String get profileOwnershipKeybaseStep2 =>
      '2. 出てきた署名を、BEGIN から END … MESSAGE. まで貼る';

  @override
  String get profileOwnershipKeybaseVerify => '確かめる';

  @override
  String profilePagePostLimit(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: '投稿は $limit 件までです。古い投稿を消してから投稿してください',
    );
    return '$_temp0';
  }

  @override
  String get profilePageEdit => '編集';

  @override
  String get profilePageCompose => 'RASQ に投稿';

  @override
  String profilePageNotFound(String handle) {
    return '@$handle という RASQ アカウントはありません';
  }

  @override
  String profilePageLoadFailed(String message) {
    return '読み込めませんでした: $message';
  }

  @override
  String get profilePageLoadFailedShort => '読み込めませんでした。';

  @override
  String get profilePageTabPosts => '投稿';

  @override
  String get profilePageTabMedia => 'メディア';

  @override
  String get profilePageTabPages => 'ページ';

  @override
  String get profilePageTabLists => 'リスト';

  @override
  String get profilePageTabClips => 'クリップ';

  @override
  String get profilePageTabPlugins => 'プラグイン';

  @override
  String get profilePageTabReviews => 'レビュー';

  @override
  String get profilePageTileNoDestination => 'このアカウントの行き先が分かりません';

  @override
  String profilePageOpenFailed(String url) {
    return '開けませんでした: $url';
  }

  @override
  String get profilePageListsEmptyMine => '公開した RASQ リストがここに出ます(リストの画面から作れます)。';

  @override
  String get profilePageClipsEmptyMine =>
      '公開した RASQ クリップがここに出ます(クリップのページの「公開する」)。';

  @override
  String get profilePageListsEmpty => '公開しているリストはありません。';

  @override
  String get profilePageClipsEmpty => '公開しているクリップはありません。';

  @override
  String profilePageSince(String date) {
    return '$dateから';
  }

  @override
  String profilePagePinLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '固定できるのは $count 件までです',
    );
    return '$_temp0';
  }

  @override
  String profilePagePinFailed(String message) {
    return '固定できませんでした: $message';
  }

  @override
  String get profilePagePinned => '固定された投稿';

  @override
  String profilePagePostsNote(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'RASQ の投稿は $limit 件までです($used / $limit)。SNS の投稿は、ログインの鍵を預けると一緒に出ます。',
    );
    return '$_temp0';
  }

  @override
  String profilePagePostsNoteDetail(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'RASQ アカウントとしての投稿は、いまは $limit 件までです($used / $limit)。SNS アカウントの投稿は、そのアカウントのアクセストークンを RASQ に預けると、ここに一緒に出ます。',
    );
    return '$_temp0';
  }

  @override
  String get profilePageSnsHintTitle => 'つないだ SNS アカウントの投稿は、まだここに出ていません。';

  @override
  String get profilePageSnsHint => 'プロフィール編集で「投稿もアカウントページに出す」を入れると、ここに出ます。';

  @override
  String get profilePageSnsHintDetail =>
      'プロフィール編集の「アカウントページに出す SNS アカウント」で、アカウントごとに「投稿もアカウントページに出す」を入れると(その SNS のアクセストークンを RASQ に預けます)、公開 / ホームの投稿がここに出ます。';

  @override
  String get profilePageSnsHintOpen => 'SNS の投稿を出す設定へ';

  @override
  String get profilePageNoPostsYet => '投稿はまだありません。';

  @override
  String get profilePageNoMediaYet => 'メディアはまだありません。';

  @override
  String get profilePageNoReviewsYet => 'レビューはまだありません。';

  @override
  String get profilePageNoPluginsPublished => '公開したプラグインはありません。';

  @override
  String get profilePageImageUrlMissing => '画像の URL が返りませんでした';

  @override
  String get profilePageNotConnected => 'RASQ のサーバーにつないでいません';

  @override
  String get profilePagePackageTypeLabel => 'プラグイン(.rspkg / .rasqpkg)';

  @override
  String get profilePageImage => '画像';

  @override
  String profilePageImageAlt(String alt) {
    return '(画像: $alt)';
  }

  @override
  String get profilePageMdFallbackTitle => 'ページ';

  @override
  String get profilePageMdLoadFailed => 'ページを読めませんでした';

  @override
  String get profilePageMdToolBold => '太字';

  @override
  String get profilePageMdToolHeading => '見出し';

  @override
  String get profilePageMdToolBullet => '箇条書き';

  @override
  String get profilePageMdToolLink => 'リンク';

  @override
  String get profilePageMdToolCenter => '中央';

  @override
  String get profilePageMdToolBig => '大きく';

  @override
  String get profilePageMdToolSmall => '小さく';

  @override
  String get profilePageMdToolSpin => '回転';

  @override
  String get profilePageMdToolJump => '跳ねる';

  @override
  String get profilePageMdToolColor => '色';

  @override
  String get profilePageMdToolRainbow => '虹';

  @override
  String get profilePageMdToolRuby => 'ルビ';

  @override
  String get profilePageMdToolRubyReading => 'よみ';

  @override
  String profilePageImageUploadFailed(String error) {
    return '画像を上げられませんでした: $error';
  }

  @override
  String get profilePageMdTitleRequired => 'タイトルを入れてください';

  @override
  String get profilePageMdLoginToPublish => 'RASQ アカウントにログインすると公開できます';

  @override
  String get profilePageMdPublished => '公開しました';

  @override
  String profilePageMdPublishFailed(String error) {
    return '公開できませんでした: $error';
  }

  @override
  String get profilePageMdDeleteTitle => 'ページを削除';

  @override
  String get profilePageMdDeleteDraft => '下書きを削除します。';

  @override
  String get profilePageMdDeletePublished => '公開したページと下書きを削除します。元に戻せません。';

  @override
  String get profilePageDeleteConfirm => '削除する';

  @override
  String get profilePageCancel => 'キャンセル';

  @override
  String profilePageMdDeleteFailed(String error) {
    return '削除できませんでした: $error';
  }

  @override
  String get profilePageMdEditTitle => 'ページを編集';

  @override
  String get profilePageMdDelete => '削除';

  @override
  String get profilePageMdWrite => '書く';

  @override
  String get profilePageMdPreview => 'プレビュー';

  @override
  String get profilePageMdPublish => '公開';

  @override
  String get profilePageMdTitleHint => 'タイトル';

  @override
  String get profilePageMdBodyHint =>
      'Markdown で書きます。@メンション / #ハッシュタグ / :絵文字: / <center> などの MFM のタグも使えます';

  @override
  String get profilePageMdDraftCaption => '下書きはこの端末に残ります。「公開」で RASQ のページに出します';

  @override
  String get profilePageRasqAccount => 'RASQ アカウント';

  @override
  String profilePageViewingVerified(String method) {
    return 'このアカウントの持ち主を確認済み($method)';
  }

  @override
  String get profilePageVerifiedSemantics => '持ち主を確認済み';

  @override
  String get profilePostLoginToUse => 'RASQ アカウントにログインすると使えます';

  @override
  String get profilePostLoginToReply => 'RASQ アカウントにログインすると返信できます';

  @override
  String get profilePostLoginToRebroad => 'RASQ アカウントにログインするとリブロードできます';

  @override
  String get profilePostLoginToQueue => 'RASQ アカウントにログインするとキューできます';

  @override
  String get profilePostErrorInstallPack => 'このパックをストアからインストールすると、この絵でキューできます';

  @override
  String get profilePostErrorForbidden => 'この投稿には操作できません';

  @override
  String get profilePostErrorRebroadLimit => 'この投稿は、これ以上リブロードできません';

  @override
  String get profilePostErrorReplyLimit => '返信は 100 件までです。古い返信を消してください';

  @override
  String get profilePostErrorGone => 'この投稿 / 絵は、もうありません';

  @override
  String profilePostErrorFailed(String message) {
    return '失敗しました: $message';
  }

  @override
  String get profilePostMenuReactions => 'リアクションを表示';

  @override
  String get profilePostMenuCopyLink => 'リンクをコピー';

  @override
  String get profilePostMenuOpenBrowser => 'ブラウザで開く';

  @override
  String get profilePostMenuEditActions => 'アクションバーを編集';

  @override
  String get profilePostMenuUnpin => '固定を外す';

  @override
  String get profilePostMenuPin => '固定する';

  @override
  String get profilePostMenuDelete => '削除';

  @override
  String get profilePostLinkCopied => 'リンクをコピーしました';

  @override
  String get profilePostDeleteTitle => '投稿を削除';

  @override
  String get profilePostDeleteMessage => 'この投稿と、付いている画像を削除します。元に戻せません。';

  @override
  String get profilePostDeleteConfirm => '削除する';

  @override
  String get profilePostCancel => 'キャンセル';

  @override
  String get profilePostQuoteUnavailable => '引用元の投稿は見られません';

  @override
  String get profilePostReply => '返信';

  @override
  String get profilePostRebroad => 'リブロード';

  @override
  String get profilePostRebroadUndo => 'リブロードを取り消す';

  @override
  String get profilePostQuote => '引用';

  @override
  String get profilePostQueue => 'キュー';

  @override
  String get profilePostLike => 'いいね';

  @override
  String get profilePostQuoteFollowersOnly => 'フォロワー限定の投稿は引用できません';

  @override
  String profilePostRebroadedBy(String name) {
    return '$name がリブロード';
  }

  @override
  String get profilePostReplyToDeleted => '削除された投稿への返信';

  @override
  String get profilePostShare => '共有';

  @override
  String get profilePostCwHide => '隠す';

  @override
  String get profilePostCwShow => 'もっと見る';

  @override
  String get profilePostNoPacksTitle => 'アセットパックがありません';

  @override
  String get profilePostNoPacksMessage => 'キューは、ストアで入れたアセットパックの絵でするリアクションです。';

  @override
  String get profilePostNoPacksStore => 'ストアで探す';

  @override
  String get profilePostClose => '閉じる';

  @override
  String profilePostOverlayQueueTooltip(String label) {
    return '$label(長押しで絵を選ぶ)';
  }

  @override
  String get profilePostMenu => 'メニュー';

  @override
  String get profilePostTitle => '投稿';

  @override
  String get profilePostGone => 'この投稿は、もうありません';

  @override
  String profilePostLoadFailed(String message) {
    return '読み込めませんでした: $message';
  }

  @override
  String get profilePostParentDeleted => '元の投稿は削除されています。';

  @override
  String profilePostRepliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '返信 $count',
    );
    return '$_temp0';
  }

  @override
  String get profilePostNoRepliesYet => '返信はまだありません。';

  @override
  String get profilePostNoReplies => '返信はありません';

  @override
  String get profilePostNoRebroads => 'リブロードはありません';

  @override
  String get profilePostNoQuotes => '引用はありません';

  @override
  String get profilePostNoQueues => 'キューはありません';

  @override
  String get profilePostReactionsTitle => 'リアクション';

  @override
  String get profilePostYou => 'あなた';

  @override
  String get raiModeInstruction => 'インストラクション';

  @override
  String get raiModeAssistant => 'アシスタント';

  @override
  String get raiGuideDefaultTitle => '案内';

  @override
  String raiHeldDeclined(String calls) {
    return '実行しませんでした($calls)';
  }

  @override
  String raiAutoDeclined(String title) {
    return 'わかりました。「$title」は案内で進めるときに「この手順で案内」を押してください';
  }

  @override
  String raiAutoProgress(int step, int total, String text) {
    return '自動で進めています($step / $total): $text';
  }

  @override
  String raiAutoAskingDetail(String label) {
    return '$label を選ぶ';
  }

  @override
  String raiAutoAskDestination(String title) {
    return '「$title」の取り込み先はどれにしますか？';
  }

  @override
  String raiAutoAskWhich(String label) {
    return '$label はどれにしますか？';
  }

  @override
  String get raiAutoAskHint => '候補から選ぶか、ほかの語を入れてください';

  @override
  String raiAutoNotFoundDetail(String label) {
    return '$label が見つからない';
  }

  @override
  String raiAutoNotFoundAsk(String label) {
    return '$label が見つかりません。別の $label で探しますか？';
  }

  @override
  String raiAutoAskWhichCount(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label はどれにしますか？($count 件)',
    );
    return '$_temp0';
  }

  @override
  String raiAutoCancelled(String title) {
    return '「$title」の自動化をやめました';
  }

  @override
  String raiAutoFailedAt(String title, int step, String detail) {
    return '「$title」の $step 手順目で止まりました: $detail';
  }

  @override
  String raiAutoPartlyDone(int done, int step, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      done,
      locale: localeName,
      other: '$done 手順を関数で進めました。$step 手順目「$text」からは押す部品があるので案内します',
    );
    return '$_temp0';
  }

  @override
  String raiAutoDone(String title) {
    return '「$title」を関数で進めました';
  }

  @override
  String get raiInstructionUnknown =>
      'まだ覚えていない操作です。「投稿」「ログイン」「共有」などで聞いてみてください。';

  @override
  String get raiAskChoice => 'どれのことですか？ 上の選択肢から選んでください';

  @override
  String get raiNoReply => '返事がありませんでした';

  @override
  String raiFailureDevice(String message) {
    return '端末内モデル: $message';
  }

  @override
  String raiFailureFallUp(String message) {
    return 'フォールアップ: $message';
  }

  @override
  String raiProposalReady(String title) {
    return '案内「$title」を用意しました(下のタイルから始められます)';
  }

  @override
  String raiProposalReadyStopAt(String title, int step) {
    return '案内「$title」を $step 手順目まで進める用意をしました(下のタイルから)';
  }

  @override
  String raiHeldNote(String calls) {
    return '(取得した情報をもとにした操作は、確かめてから実行します: $calls)';
  }

  @override
  String get raiNoReplyParen => '(返事がありませんでした)';

  @override
  String raiRestartInjecting(String keys) {
    return '取得した情報($keys)を注入してモデルを再始動します';
  }

  @override
  String get raiAutoDetailReplaced => '関数で代替';

  @override
  String get raiAutoDetailNoFunction => '関数の対応が無い';

  @override
  String get raiAutoDetailGuideParts => '押す部品は案内で';

  @override
  String get raiAutoDetailExplanationOnly => '説明だけ';

  @override
  String raiAutoDescribeNoBound(String title) {
    return '「$title」は関数で代わりにできる手順が無いので、案内(指差し)で進めます。';
  }

  @override
  String raiAutoDescribeHead(String title) {
    return '「$title」は案内を出さずに私が関数でやります:';
  }

  @override
  String raiAutoDescribeGuideMark(String detail) {
    return '(ここからは案内: $detail)';
  }

  @override
  String get raiListSeparator => '、';

  @override
  String raiAutoDescribeFromQuestion(String inputs) {
    return '質問から: $inputs';
  }

  @override
  String raiAutoDescribeEntrusted(String labels) {
    return '$labels は候補の先頭で進めます(任されているので)';
  }

  @override
  String raiAutoDescribeAskLater(String labels) {
    return '$labels は実行の途中で選んでもらいます';
  }

  @override
  String get raiAutoDescribeConfirm => 'よければ「実行する」を押してください。';

  @override
  String raiProposalHead(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '「$title」なら、この順で進めます($count 手順)',
    );
    return '$_temp0';
  }

  @override
  String raiProposalFunction(String function) {
    return '〔$function〕';
  }

  @override
  String raiProposalInputs(String inputs) {
    return ' 入力: $inputs';
  }

  @override
  String raiProposalPresets(String presets) {
    return ' 固定: $presets';
  }

  @override
  String get raiModeSemantics => 'RAi モード';

  @override
  String get raiAskButton => '質問する';

  @override
  String get raiInputHint => '困ったとき、お手伝いします！';

  @override
  String raiInputPredicted(String prediction) {
    return '$prediction(スペースで入力)';
  }

  @override
  String get raiCollapse => '畳む';

  @override
  String get raiExpand => '広げる';

  @override
  String get raiAskMore => 'さらに尋ねる';

  @override
  String get raiHistoryClose => '履歴を閉じる';

  @override
  String get raiHistory => '発言の履歴';

  @override
  String get raiClose => 'RAi を閉じる';

  @override
  String get raiNext => '次へ';

  @override
  String get raiDone => '了解(閉じる)';

  @override
  String get raiSpeechClose => '閉じる';

  @override
  String get raiHistoryEmpty => 'まだ発言はありません';

  @override
  String get raiCopy => 'コピー';

  @override
  String get raiCopied => 'コピーしました';

  @override
  String raiChatSuspended(int step, int total) {
    return '案内を一時停止中($step / $total 手順目)。戻ると続きます。';
  }

  @override
  String get raiChatResume => '続きへ';

  @override
  String get raiChatHeadline => 'マクロとか、お任せください！';

  @override
  String get raiChatIntro => '操作を聞くと、RAi がボタンを指差して教えます。';

  @override
  String get raiChatIntroDetail =>
      'インストラクション: 操作を聞くと RAi がボタンまで移動して指差します。\nアシスタント: 端末内モデルで答えます。モデルはバーのチップから選べます(マクロは第二期)。';

  @override
  String get raiChatRecent => '最近の質問';

  @override
  String get raiChatRejectCandidates => 'これじゃない(候補を外して答え直す)';

  @override
  String raiChatProposalTitle(String title, int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$title · $steps 手順',
    );
    return '$_temp0';
  }

  @override
  String get raiChatSkip => 'スキップ';

  @override
  String get raiChatGuide => 'この手順で案内';

  @override
  String raiChatGuideTitle(String title) {
    return '案内「$title」';
  }

  @override
  String get raiChatTrace => '工程';

  @override
  String get raiChatShowGraph => 'グラフビューで表示';

  @override
  String get raiChatApproveHeld => 'この操作を実行しますか？(取得した情報から出た操作です)';

  @override
  String get raiChatApprove => 'RAi に任せますか？';

  @override
  String get raiChatDecline => 'やめる';

  @override
  String get raiChatRun => '実行する';

  @override
  String get raiHomeSidebarSemantics => 'RAi サイドバー';

  @override
  String get raiHomeClose => '閉じる';

  @override
  String get raiHomeNewConversation => '新しい会話';

  @override
  String get raiHomeHistory => '会話の履歴';

  @override
  String raiHomeCurrentConversation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'いまの会話 · $count 件',
    );
    return '$_temp0';
  }

  @override
  String raiHomeConversationSubtitle(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$when · $count 件',
    );
    return '$_temp0';
  }

  @override
  String get raiHomeDelete => '削除';

  @override
  String get raiHomeHistoryEmpty => 'まだありません。質問すると、ここに会話が残ります。';

  @override
  String get raiHomeOther => 'その他';

  @override
  String get raiAchievementsTitle => 'アチーブメント';

  @override
  String raiAchievementsProgress(int unlocked, int total) {
    return '$unlocked / $total 達成';
  }

  @override
  String get raiHomeMacro => 'マクロ';

  @override
  String get raiHomeMacroSoon => '準備中';

  @override
  String get raiBarSemantics => 'RAi バー';

  @override
  String get raiAskCancel => 'やめる';

  @override
  String raiAskInputHint(String label) {
    return '$labelを入れる';
  }

  @override
  String raiAskInputOtherHint(String label) {
    return 'ほかの$labelを入れる';
  }

  @override
  String get raiAskDone => '決定';

  @override
  String raiAchievementsStats(
    int instructions,
    int assistant,
    int app,
    int completed,
    int repeated,
  ) {
    return 'インストラクション $instructions 回 · アシスタント $assistant 回(アプリの話 $app 回)· 完走 $completed 回 · 聞き直し $repeated 回';
  }

  @override
  String get raiAchievementAsk1Title => 'はじめての質問';

  @override
  String get raiAchievementAsk1Description => 'インストラクションを 1 回聞いた';

  @override
  String get raiAchievementAsk10Title => '聞き上手';

  @override
  String get raiAchievementAsk10Description => 'インストラクションを 10 回聞いた';

  @override
  String get raiAchievementAsk50Title => 'RAi の常連';

  @override
  String get raiAchievementAsk50Description => 'インストラクションを 50 回聞いた';

  @override
  String get raiAchievementApp5Title => 'アプリ通';

  @override
  String get raiAchievementApp5Description => 'アシスタントとアプリについて 5 回話した';

  @override
  String get raiAchievementChat20Title => 'おしゃべり';

  @override
  String get raiAchievementChat20Description => 'アシスタントに 20 回話しかけた';

  @override
  String get raiAchievementDone1Title => '一発で完走';

  @override
  String get raiAchievementDone1Description => '案内を最後の手順まで進めた';

  @override
  String get raiAchievementDone10Title => '完走マスター';

  @override
  String get raiAchievementDone10Description => '案内を 10 回最後まで進めた';

  @override
  String get raiAchievementAgain3Title => '復習中';

  @override
  String get raiAchievementAgain3Description => '同じ操作を 3 回聞き直した';

  @override
  String get raiAchievementAuto1Title => 'おまかせ';

  @override
  String get raiAchievementAuto1Description => '「スキップ」で RAi に任せた';

  @override
  String get raiTracePortPrev => '前';

  @override
  String get raiTracePortState => '状態';

  @override
  String get raiTracePortFunction => '関数';

  @override
  String get raiTracePortResult => '結果';

  @override
  String get raiTracePortNext => '次';

  @override
  String get raiTraceStatusDone => '関数で済';

  @override
  String get raiTraceStatusSkipped => '畳んだ';

  @override
  String get raiTraceStatusGuide => '案内へ';

  @override
  String get raiTraceStatusFailed => '失敗';

  @override
  String get raiTraceStatusAsking => '選択待ち';

  @override
  String get raiTraceStatusRunning => '実行中';

  @override
  String get raiTraceStatusPending => '未実行';

  @override
  String raiTraceCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '工程 $count 手順',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsSettingMissing(String area, String key, String keys) {
    return '「$area」に「$key」という設定はありません(ある: $keys)';
  }

  @override
  String raiFunctionsSettingNotWritable(String key) {
    return '「$key」は画面から書ける設定ではありません';
  }

  @override
  String raiFunctionsSettingNeedsPassword(String key) {
    return '「$key」はパスワードが要るので RAi からは書きません';
  }

  @override
  String raiFunctionsSettingLocked(String key) {
    return '「$key」は操作禁止タグが付いているので RAi からは書きません';
  }

  @override
  String raiFunctionsFoldEmpty(String head) {
    return '$head: 該当なし';
  }

  @override
  String raiFunctionsFoldHead(String head, int total, int shown) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$head $total 件中 $shown 件:',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsUnsupported(String name) {
    return 'この SNS では使えません($name)';
  }

  @override
  String raiFunctionsNotAutomatable(String name, String alt, String result) {
    return '$name は自動化不可です(送信はユーザーが押します)。代わりに $alt: $result';
  }

  @override
  String raiFunctionsUnknown(String name) {
    return '知らない関数です: $name';
  }

  @override
  String raiFunctionsFailed(String name, String error) {
    return '$name に失敗: $error';
  }

  @override
  String get raiFunctionsNotLoggedInSns => 'SNS にログインしていません';

  @override
  String raiFunctionsLineReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '(反応 $count)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsPostsNone => '該当する投稿はありませんでした';

  @override
  String raiFunctionsPostsHead(int count, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '投稿 $count 件($total 件中):',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsReferenceOperation(String title, String id, String steps) {
    return '操作「$title」($id): $steps';
  }

  @override
  String raiFunctionsReferenceFunction(String id, String does) {
    return '関数 $id: $does';
  }

  @override
  String raiFunctionsReferenceParams(String params) {
    return ' 引数: $params';
  }

  @override
  String get raiFunctionsReferenceParamInput => '入力';

  @override
  String raiFunctionsReferenceParamFixed(String value) {
    return '固定=$value';
  }

  @override
  String raiFunctionsReferenceMissing(String id) {
    return 'リファレンスに $id はありません';
  }

  @override
  String raiFunctionsActionMissing(String id) {
    return 'アクション $id はありません';
  }

  @override
  String raiFunctionsActionNotAllowed(String label) {
    return '「$label」は自動化が許可されていません(RAi からは実行しません)。代わりに案内(この手順で案内)で進めるか、ユーザーが押してください';
  }

  @override
  String raiFunctionsActionDone(String label, String state) {
    return '$label を実行しました($state)';
  }

  @override
  String get raiFunctionsActionDoneYes => '済';

  @override
  String get raiFunctionsActionDoneNo => '未';

  @override
  String get raiFunctionsAstellNoRooms => 'ASTell のルームはありません';

  @override
  String raiFunctionsAstellRooms(String rooms) {
    return 'ASTell のルーム: $rooms';
  }

  @override
  String get raiFunctionsAstellNoTitle => '題名がありません';

  @override
  String raiFunctionsAstellCreated(String title, String id) {
    return 'ASTell「$title」を作りました [$id]';
  }

  @override
  String raiFunctionsNotifReaction(String who, String reaction) {
    return '$who がリアクション$reaction';
  }

  @override
  String raiFunctionsNotifRepost(String who) {
    return '$who がリノート';
  }

  @override
  String raiFunctionsNotifQuote(String who) {
    return '$who が引用';
  }

  @override
  String raiFunctionsNotifReply(String who) {
    return '$who が返信';
  }

  @override
  String raiFunctionsNotifMention(String who) {
    return '$who がメンション';
  }

  @override
  String raiFunctionsNotifFollow(String who) {
    return '$who がフォロー';
  }

  @override
  String raiFunctionsNotifFollowRequest(String who) {
    return '$who がフォロー申請';
  }

  @override
  String raiFunctionsNotifFollowAccepted(String who) {
    return '$who がフォロー承認';
  }

  @override
  String raiFunctionsNotifListAdded(String who) {
    return '$who がリストに追加';
  }

  @override
  String get raiFunctionsNotifPollEnded => 'アンケート終了';

  @override
  String get raiFunctionsNotifTimer => 'タイマー通知';

  @override
  String get raiFunctionsNotifVc => 'ASTell 通知';

  @override
  String get raiFunctionsNotifSystem => 'システム通知';

  @override
  String get raiFunctionsNotifOther => 'その他の通知';

  @override
  String get raiFunctionsUnreadMark => '(未読)';

  @override
  String get raiFunctionsMissingPostId => '投稿 id (id=) がありません';

  @override
  String get raiFunctionsMissingPostArg => '投稿 id (post=) がありません';

  @override
  String raiFunctionsThreadReply(String line) {
    return '返信: $line';
  }

  @override
  String get raiFunctionsHeadThread => 'スレッド';

  @override
  String get raiFunctionsHeadReactions => '反応';

  @override
  String get raiFunctionsHeadReposters => 'リノートした人';

  @override
  String get raiFunctionsHeadQuotes => '引用';

  @override
  String get raiFunctionsHeadFavorites => 'お気に入り';

  @override
  String get raiFunctionsHeadReacted => 'リアクション済み';

  @override
  String raiFunctionsMe(String user, String plugin) {
    return '自分: $user プラグイン=$plugin';
  }

  @override
  String get raiFunctionsUserIdOrHandle => 'id= か handle= を指定してください';

  @override
  String get raiFunctionsNotFound => '見つかりませんでした';

  @override
  String raiFunctionsUserCounts(String followers, String following) {
    return ' フォロワー$followers フォロー$following';
  }

  @override
  String get raiFunctionsMissingUser => 'user id (user=) がありません';

  @override
  String raiFunctionsHeadUserPosts(String filter) {
    return '投稿($filter)';
  }

  @override
  String get raiFunctionsMissingKeyword => 'keyword がありません';

  @override
  String raiFunctionsHeadUserSearch(String keyword) {
    return 'ユーザー検索「$keyword」';
  }

  @override
  String get raiFunctionsHeadFollowing => 'フォロー中';

  @override
  String get raiFunctionsHeadFollowers => 'フォロワー';

  @override
  String get raiFunctionsRelFollowing => 'フォロー中';

  @override
  String get raiFunctionsRelFollowedBy => 'フォローされています';

  @override
  String get raiFunctionsRelRequested => '申請中';

  @override
  String get raiFunctionsRelMuted => 'ミュート中';

  @override
  String get raiFunctionsRelBlocked => 'ブロック中';

  @override
  String get raiFunctionsRelBlockedBy => 'ブロックされています';

  @override
  String get raiFunctionsRelNone => 'なし';

  @override
  String raiFunctionsRelation(String flags) {
    return '関係: $flags';
  }

  @override
  String raiFunctionsRequestLine(String user, String id) {
    return '$user [申請 $id]';
  }

  @override
  String raiFunctionsHeadModeration(String kind) {
    return 'モデレーション($kind)';
  }

  @override
  String raiFunctionsHeadNotifications(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '通知(未読 $unread 件)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNotificationsRead => '通知を既読にしました';

  @override
  String raiFunctionsTrendLine(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag($count 人)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadTrends => 'トレンド';

  @override
  String raiFunctionsListLine(String name, String id, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name [$id]($count 人)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadLists => 'リスト';

  @override
  String get raiFunctionsMissingList => 'list id (list=) がありません';

  @override
  String get raiFunctionsHeadListMembers => 'リストのメンバー';

  @override
  String raiFunctionsClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count 件)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadClips => 'クリップ';

  @override
  String get raiFunctionsMissingClip => 'clip id (clip=) がありません';

  @override
  String get raiFunctionsHeadClipNotes => 'クリップの中身';

  @override
  String get raiFunctionsHeadFeeds => 'フィード';

  @override
  String raiFunctionsDmUnread(int count) {
    return '(未読 $count)';
  }

  @override
  String raiFunctionsHeadEmoji(String keyword) {
    return '絵文字「$keyword」';
  }

  @override
  String get raiFunctionsUnfollowed => 'フォローを外しました';

  @override
  String get raiFunctionsFollowRequested => 'フォロー申請しました';

  @override
  String get raiFunctionsFollowed => 'フォローしました';

  @override
  String get raiFunctionsListUserArgs => 'list= と user= を指定してください';

  @override
  String get raiFunctionsListAdded => 'リストに追加しました';

  @override
  String get raiFunctionsListRemoved => 'リストから外しました';

  @override
  String get raiFunctionsMissingName => '名前 (name=) がありません';

  @override
  String raiFunctionsListCreated(String name, String id) {
    return 'リスト「$name」を作りました [$id]';
  }

  @override
  String get raiFunctionsClipPostArgs => 'clip= と post= を指定してください';

  @override
  String get raiFunctionsClipAdded => 'クリップに追加しました';

  @override
  String get raiFunctionsClipRemoved => 'クリップから外しました';

  @override
  String raiFunctionsClipCreated(String name, String id) {
    return 'クリップ「$name」を作りました [$id]';
  }

  @override
  String get raiFunctionsAreaKeyArgs => 'area= と key= を指定してください';

  @override
  String raiFunctionsSettingsPageMissing(String area) {
    return '設定ページ「$area」はありません';
  }

  @override
  String get raiFunctionsAreaKeyValueArgs => 'area= と key= と value= を指定してください';

  @override
  String raiFunctionsSettingBadValue(String key, String value, String current) {
    return '「$key」に「$value」は入れられません(今の値: $current)';
  }

  @override
  String raiFunctionsSettingSet(String area, String key, String value) {
    return '$area.$key を $value にしました';
  }

  @override
  String get raiFunctionsMissingText => '本文(text=)がありません';

  @override
  String get raiFunctionsMissingRoom => 'ルーム id (room=) がありません';

  @override
  String raiFunctionsDmRoomMissing(String id) {
    return 'DM ルーム $id はありません';
  }

  @override
  String raiFunctionsComposeFilled(String target) {
    return '$targetの下書きをコンポーザーに入れました(送信はしていません)';
  }

  @override
  String raiFunctionsFeedNotFound(String feed) {
    return 'フィード「$feed」が見つかりません';
  }

  @override
  String raiFunctionsFeedSaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '「$name」を保存しました(保存済み $count 件)',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsFeedUnsaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '「$name」を保存から外しました(保存済み $count 件)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNoBluesky =>
      'Bluesky のアカウントがありません(カスタムフィードは Bluesky のみ)';

  @override
  String raiFunctionsFeedAlreadyHome(String name) {
    return '「$name」はもうホームのタイムラインに入っています';
  }

  @override
  String raiFunctionsFeedAddedHome(String name, String account) {
    return '「$name」($account)をホームのタイムラインに取り込みました';
  }

  @override
  String get raiFunctionsNotLoggedInRasq => 'RASQ アカウントにログインしていません';

  @override
  String get raiFunctionsRasqListMine => '自分';

  @override
  String get raiFunctionsRasqListUnfetchable => '取り込めない';

  @override
  String get raiFunctionsRasqListFollowing => 'フォロー中';

  @override
  String raiFunctionsRasqListLine(String name, int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name($count人・$state)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadRasqLists => 'RASQ リスト';

  @override
  String get raiFunctionsMissingListArg => 'リスト(list=)がありません';

  @override
  String raiFunctionsRasqListNotFound(String query) {
    return 'RASQ リスト「$query」が見つかりません';
  }

  @override
  String get raiFunctionsMissingWord => 'ワード(word=)がありません';

  @override
  String get raiFunctionsNotLoggedIn => 'ログインしていません';

  @override
  String raiFunctionsWordExcludeAlready(String word) {
    return '「$word」の除外はもう入っています';
  }

  @override
  String raiFunctionsWordIncludeAlready(String word) {
    return '「$word」の絞り込みはもう入っています';
  }

  @override
  String raiFunctionsWordExcluded(String word, String scope) {
    return '「$word」を含む投稿を $scope のタイムラインから除外するようにしました';
  }

  @override
  String raiFunctionsWordIncluded(String word, String scope) {
    return '「$word」を含む投稿だけを $scope のタイムラインに通すようにしました';
  }

  @override
  String get raiFunctionsFeedKindLabel => 'フィード';

  @override
  String get raiFunctionsHeadFeedTimeline => 'フィード TL';

  @override
  String raiFunctionsPageList(String name, String id) {
    return 'リスト $name [$id]';
  }

  @override
  String raiFunctionsPageFeed(String name, String uri) {
    return 'フィード $name [$uri]';
  }

  @override
  String get raiFunctionsHeadListsPage => 'リストページ';

  @override
  String get raiFunctionsHeadNotificationsPage => '通知';

  @override
  String get raiFunctionsHeadHomeTimeline => 'ホーム TL';

  @override
  String get raiFunctionsMissingSource => '取り込み元(source=)がありません';

  @override
  String raiFunctionsSeedNoPosts(String label) {
    return '「$label」に投稿が無いので特徴語を取れません';
  }

  @override
  String raiFunctionsSeedNoWords(String label) {
    return '「$label」から特徴語を取れませんでした';
  }

  @override
  String get raiFunctionsSeedWordSeparator => '、';

  @override
  String raiFunctionsSeedAdded(String label, String words) {
    return '「$label」の特徴語($words)をトレンドの指向性(好きなジャンル)に足しました';
  }

  @override
  String get raiFunctionsMissingQuery => '検索語(q=)がありません';

  @override
  String raiFunctionsHeadWeb(String query) {
    return 'web「$query」';
  }

  @override
  String get raiFunctionsNotAutomatableMark => '(自動化不可)';

  @override
  String get raiFunctionsHeadActions => 'アクション';

  @override
  String get raiModelsTitle => 'モデル';

  @override
  String get raiModelsClose => '閉じる';

  @override
  String get raiModelsRamUnknown => 'RAM: 不明';

  @override
  String raiModelsRamFree(String gb) {
    return '(空き $gb GB)';
  }

  @override
  String raiModelsCaption(String codename, String ram) {
    return '$codename = この端末で動くモデル。$ram';
  }

  @override
  String raiModelsCaptionDetail(String codename, String label, String ram) {
    return '$codename = 端末内で動くモデル($label)。$ram';
  }

  @override
  String get raiModelsSectionLocal => 'ローカル';

  @override
  String get raiModelsSectionEmbedding => 'RAi の検索と投稿の埋め込み';

  @override
  String get raiModelsPostVisionReady => '関連 TL と TL のアルゴリズムで、投稿の画像も比べます';

  @override
  String get raiModelsPostVisionIdle =>
      '関連 TL と TL のアルゴリズムで、投稿の本文に加えて画像も比べられるようになります(文のモデルも入れてください)';

  @override
  String get raiModelsSectionEmoji => '絵文字の画像検索(2 つとも要ります)';

  @override
  String get raiModelsEmojiTextReady => '打った文で、絵文字の絵を探せます';

  @override
  String get raiModelsEmojiTextIdle => '絵文字の絵を、意味で探せるようになります(画像側も入れてください)';

  @override
  String get raiModelsEmojiVisionReady => '絵文字の絵を、裏で少しずつ読み込みます(サーバーごとに 1 回)';

  @override
  String get raiModelsEmojiVisionIdle => '名前が意味を持たない絵文字も、絵の中身で探せるようになります';

  @override
  String get raiModelsSectionCloud => 'クラウド(端末で答えられないとき)';

  @override
  String get raiModelsCompletionCaption => '完遂率 = 案内や返答が最後までうまくいった割合です。';

  @override
  String get raiModelsCompletionCaptionDetail =>
      '完遂率 = 操作の案内 / 返答が最後まで成立した割合の集計(35B 未満のモデルだけ集計、デモでは「-%」)。';

  @override
  String get raiModelsRateExcluded => '集計外';

  @override
  String get raiModelsNotConnected => '未接続';

  @override
  String get raiModelsPhaseNotInstalled => '未ダウンロード';

  @override
  String raiModelsPhaseDownloading(int percent) {
    return 'ダウンロード中 $percent%';
  }

  @override
  String get raiModelsPhaseReady => '準備完了';

  @override
  String get raiModelsPhaseLoading => '読み込み中';

  @override
  String get raiModelsPhaseGenerating => '生成中';

  @override
  String get raiModelsPhaseUnavailable => '使えません';

  @override
  String get raiModelsPillCloud => 'クラウド';

  @override
  String get raiModelsPillLocal => 'ローカル';

  @override
  String raiModelsCloudLine(String label, String params) {
    return '$label · ${params}B · クラウド';
  }

  @override
  String raiModelsCompletionRate(String rate) {
    return '完遂率 $rate';
  }

  @override
  String get raiModelsMemoryNotNeeded => 'メモリ: 端末不要';

  @override
  String raiModelsMemory(String verdict) {
    return 'メモリ: $verdict';
  }

  @override
  String get raiModelsUse => '使う';

  @override
  String get raiModelsExtract => '展開(同梱)';

  @override
  String get raiModelsDownload => 'ダウンロード';

  @override
  String get raiModelsRelease => 'メモリを解放';

  @override
  String get raiModelsDeleteTitle => 'モデルを削除しますか';

  @override
  String raiModelsDeleteMessage(String file) {
    return '$file を端末から消します。';
  }

  @override
  String get raiModelsDelete => '削除';

  @override
  String get raiModelsCancel => 'キャンセル';

  @override
  String raiModelsEmbeddingLine(String file, int size, int dims) {
    return 'onnxruntime · $file · 約 $size MB · $dims 次元';
  }

  @override
  String get raiModelsSearchSemantic => '意味の近さで探します';

  @override
  String raiModelsSearchSemanticDetail(String label) {
    return '検索: $label(意味で引く)';
  }

  @override
  String get raiModelsSearchNgram => 'いまは語の一致で探します。ダウンロードすると言い換えにも強くなります';

  @override
  String get raiModelsSearchNgramDetail =>
      '検索: n-gram 代替(語の一致で引く。ダウンロードすると言い換えにも強くなる)';

  @override
  String get raiModelsServerTitle => 'ローカル推論サーバー';

  @override
  String get raiModelsServerConfigured => '接続先あり';

  @override
  String get raiModelsServerNotConfigured => '未設定';

  @override
  String get raiModelsServerCaption => '端末のモデルが答えられないとき、ここに聞きます。';

  @override
  String get raiModelsServerCaptionDetail =>
      'OpenAI 互換のチャット API(llama-server / vLLM など)。端末内モデルが失敗 / 無応答のとき、質問と近かったリファレンスを添えて渡します。';

  @override
  String get raiModelsServerModelHint => 'モデル名(省略可)';

  @override
  String get raiModelsRamOk => '動作可';

  @override
  String get raiModelsRamTight => 'ぎりぎり';

  @override
  String get raiModelsRamNo => 'メモリ不足';

  @override
  String get raiModelsRamUnknownVerdict => '不明';

  @override
  String get raiModelsFallUpNotConnected => 'フォールアップ先(サーバー側)が未接続です';

  @override
  String raiModelsServerHttpError(int status) {
    return '推論サーバー HTTP $status';
  }

  @override
  String get raiModelsServerNoReply => '推論サーバーから返事がありませんでした';

  @override
  String raiModelsServerUnreachable(String error) {
    return '推論サーバーに届きません: $error';
  }

  @override
  String get raiModelsLlmUnavailableHere => 'この環境では端末内モデルを使えません';

  @override
  String raiModelsLlamaFetching(String tag) {
    return 'llama.cpp のランタイム($tag)を取得中';
  }

  @override
  String get raiModelsLlamaMissingIos =>
      'llama.cpp が組み込まれていません(Runner に llama.xcframework を追加)';

  @override
  String get raiModelsLlamaMissing => 'llama.cpp のライブラリがありません';

  @override
  String raiModelsLlamaFetchFailed(int status) {
    return 'llama.cpp のランタイムを取得できません(HTTP $status)';
  }

  @override
  String raiModelsStateCheckFailed(String error) {
    return 'モデルの状態を確認できません: $error';
  }

  @override
  String get raiModelsExtracting => '同梱モデルを展開中';

  @override
  String get raiModelsExtractTooLarge => 'この端末では同梱モデルを展開できません(ダウンロードしてください)';

  @override
  String raiModelsExtractFailed(String error) {
    return '展開に失敗しました: $error';
  }

  @override
  String raiModelsDownloadFailed(String error) {
    return 'ダウンロードに失敗しました: $error';
  }

  @override
  String raiModelsNotDownloaded(String codename) {
    return '端末内モデル($codename)がまだダウンロードされていません';
  }

  @override
  String get raiModelsDeviceUnavailable => '端末内モデルを使えません';

  @override
  String raiModelsFileMissing(String path) {
    return 'モデルファイルがありません: $path';
  }

  @override
  String get raiModelsTimeoutFirstToken => '端末内モデルが 30 秒返事をしませんでした';

  @override
  String get raiModelsTimeoutOverall => '端末内モデルの返事が長すぎるので打ち切りました';

  @override
  String get raiModelsOnlyThinking => '端末内モデルから返事がありませんでした(思考だけで終わった可能性)';

  @override
  String raiModelsGenerateFailed(String error) {
    return '生成に失敗しました: $error';
  }

  @override
  String get raiModelsHintSystemPolicy =>
      '「system policy」= サンドボックス / ライブラリ検証で拒否。Debug の entitlements(app-sandbox=false、disable-library-validation)で再ビルドしてください';

  @override
  String get raiModelsHintGatekeeper =>
      'Gatekeeper に止められた場合: 「システム設定 > プライバシーとセキュリティ」で許可するか、Application Support/llama_cpp の dylib に xattr -dr com.apple.quarantine を実行してください';

  @override
  String raiModelsLoadFailedLlama(String error) {
    return 'モデルを読み込めません(llama.cpp): $error';
  }

  @override
  String raiModelsLoadFailed(String error) {
    return 'モデルを読み込めません: $error';
  }

  @override
  String get raiModelsEmbeddingRasqText => 'RASQ MiniLM(文)';

  @override
  String get raiModelsEmbeddingMiniLmL12 => 'MiniLM-L12 多言語(paraphrase, int8)';

  @override
  String get raiModelsEmbeddingRasqVision => 'RASQ MobileNet(投稿の画像)';

  @override
  String get raiModelsEmbeddingSiglipText => 'SigLIP2 base(テキスト塔・int8)';

  @override
  String get raiModelsEmbeddingSiglipVision => 'SigLIP2 base(画像側・int8)';

  @override
  String raiModelsEmbeddingFailed(String message) {
    return '失敗: $message';
  }

  @override
  String get raiModelsEmbeddingUnavailableHere => 'この環境では端末内の埋め込みモデルを使えません';

  @override
  String get raiModelsCentralNotConfigured => 'RASQ サーバーの接続先が未設定です';

  @override
  String raiModelsLoadFailedOnnx(String error) {
    return 'モデルを読み込めません(onnxruntime): $error';
  }

  @override
  String get raiModelsWebDisabled => 'web 検索はまだ使えません';

  @override
  String get raiModelsWebNoKey => 'Brave Search の鍵が設定されていません';

  @override
  String get raiModelsWebAnswerTitle => 'web の答え';

  @override
  String raiModelsWebFailed(String error) {
    return '検索に失敗: $error';
  }

  @override
  String get raiModelsNoteNotInstalled => '未DL';

  @override
  String get settingsActionBarTitle => 'プラグインボタン';

  @override
  String get settingsActionBarBackTooltip => '戻る';

  @override
  String get settingsActionBarBundleManual => '手動配置(バーの (+) から足すまで出ない)';

  @override
  String get settingsActionBarBundleAlone => '単体で末尾';

  @override
  String settingsActionBarBundleInto(String label, String percent) {
    return '「$label」のバンドル($percent%)';
  }

  @override
  String get settingsActionBarAutoOnTitle => '面を開いたとき自動でオン';

  @override
  String get settingsActionBarOn => 'オン';

  @override
  String get settingsActionBarOff => 'オフ';

  @override
  String settingsActionBarAutoDefault(String state) {
    return '既定($state)';
  }

  @override
  String settingsActionBarAutoDefaultDeclared(String state) {
    return '既定($state、プラグインの宣言)';
  }

  @override
  String settingsActionBarAutoOverridden(String state) {
    return '設定で上書き中(既定は $state)';
  }

  @override
  String get settingsActionBarEmptyCaption => 'ストアで追加したプラグインがここに並びます';

  @override
  String get settingsActionBarIntroCaption => 'スイッチを切ると、すべてのアカウントで出なくなります。';

  @override
  String get settingsActionBarIntroDetail =>
      'スイッチは端末全体の主電源(オフなら全アカウント・全面で出ず、自動でも動きません)。「面を開いたとき自動でオン」は、その面を開いた瞬間の初期状態です(面の中で切り替えた値は次に持ち越しません)。';

  @override
  String get settingsActionBarPostTileHeader => '投稿タイル';

  @override
  String get settingsActionBarPostTileEmptyDetail =>
      'post.action を宣言したプラグインがここに並びます(ストアから追加)';

  @override
  String get settingsActionBarViewerHeader => '全画面';

  @override
  String get settingsActionBarViewerEmptyDetail =>
      'viewer.overlay を宣言したプラグイン(QR コード検出など)がここに並びます';

  @override
  String get settingsActionBarViewerPlacement => '全画面アクションバーの ON / OFF ボタン';

  @override
  String get settingsActionBarMediaHeader => '加工画面';

  @override
  String get settingsActionBarMediaEmptyDetail =>
      'composer.media を宣言したプラグインがここに並びます';

  @override
  String settingsActionBarFilterPlacement(String placement) {
    return 'フィルター · $placement';
  }

  @override
  String get settingsActionBarComposerTextHeader => 'コンポーザー本文';

  @override
  String get settingsActionBarComposerTextEmptyDetail =>
      'composer.text を宣言したプラグインがここに並びます';

  @override
  String get settingsActionBarComposerTextPlacement =>
      'コンポーザーのアクションバーの ON / OFF ボタン(長押しで設定)';

  @override
  String get settingsActionBarTransformHeader => '投稿加工(自動)';

  @override
  String get settingsActionBarTransformEmptyDetail =>
      'post.transform を宣言したプラグインがここに並びます';

  @override
  String get settingsActionBarTransformPlacement => '表示前に本文を加工(ボタン無し)';

  @override
  String settingsActionBarThisAccountHeader(String account) {
    return 'このアカウント($account)';
  }

  @override
  String get settingsActionBarNoAccount => '未選択';

  @override
  String get settingsActionBarThisAccountEmptyCaption => 'このアカウントで出すかどうか';

  @override
  String get settingsActionBarThisAccountEmptyDetail =>
      '投稿タイルのボタンを、このアカウントで出すかどうか';

  @override
  String settingsActionBarSlotSubtitle(String plugin, String tags) {
    return '$plugin · タグ: $tags';
  }

  @override
  String get settingsActionBarThresholdTitle => '束ねる閾値';

  @override
  String get settingsActionBarThresholdSubtitle => '似たボタンをまとめる度合い';

  @override
  String get settingsActionBarThresholdDetail => 'タグの類似度がこれ以上なら既存ボタンのバンドルに入る';

  @override
  String get settingsActionBarEditButton => 'アクションバーを編集';

  @override
  String get settingsBackendTitle => 'RASQ サーバー';

  @override
  String get settingsBackendErrorUnparseable =>
      '接続先を解釈できません。「http://192.168.3.14:8080」や「https://central.example」の形で入れてください。';

  @override
  String get settingsBackendSaved => '保存しました';

  @override
  String get settingsBackendErrorEnterUrl =>
      '接続先を入力してください(例: http://192.168.3.14:8080)';

  @override
  String get settingsBackendCentralNotCentralHint =>
      'Central の欄に、ORGATE ではなく RASQ Central の接続先を入れてください';

  @override
  String settingsBackendCentralConnectFailed(
    String url,
    String error,
    String hint,
  ) {
    return '接続できませんでした($url)— $error$hint';
  }

  @override
  String settingsBackendCentralOk(String algorithm, String keyHead) {
    return '接続 OK — 署名鍵 $algorithm $keyHead…';
  }

  @override
  String settingsBackendAccountLine(String handle, String displayName) {
    return 'RASQ アカウント: @$handle ($displayName)';
  }

  @override
  String get settingsBackendAccountNotCreatedLine =>
      'RASQ アカウント: 未作成(下の「RASQ アカウントを開く」から作成できます)';

  @override
  String settingsBackendAccountLoadFailedLine(String error) {
    return 'RASQ アカウントを取得できませんでした — $error';
  }

  @override
  String get settingsBackendOrgateNotConfiguredLine =>
      'ORGATE: 未設定(RASQ アカウントにログインできません)';

  @override
  String settingsBackendOrgateOk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 個',
    );
    return 'ORGATE: 接続 OK — トークンの公開鍵 $_temp0';
  }

  @override
  String settingsBackendOrgateNoKeys(String url) {
    return 'ORGATE: 応答にトークンの公開鍵がありません($url)';
  }

  @override
  String settingsBackendOrgateConnectFailed(String url, String error) {
    return 'ORGATE に接続できませんでした($url)— $error';
  }

  @override
  String get settingsBackendCaption =>
      'RASQ アカウントやストアのサーバーの接続先です。SNS の投稿やタイムラインは、ここを通りません。';

  @override
  String get settingsBackendCaptionDetail =>
      'RASQ Central は公開・共有のもの(プロフィール・ストア・ASTell・投稿・リストなど)のサーバー、ORGATE は本人だけの情報(ログイン・パスワード・メールアドレス)と Mastodon などのログイン(OAuth ブローカー)のサーバーです。RASQ アカウントへのログインは ORGATE で行い、そのトークンを Central にも使います。SNS の投稿やタイムラインはどちらも通らず、プラグインが各インスタンスへ直接接続します。';

  @override
  String get settingsBackendCentralLabel => 'RASQ Central の接続先(空なら ORGATE を流用)';

  @override
  String get settingsBackendOrgateLabel => 'ORGATE(ログイン・本人だけの情報)の接続先';

  @override
  String get settingsBackendSaveButton => '保存';

  @override
  String get settingsBackendTestButton => '接続テスト';

  @override
  String get settingsBackendCentralDisconnected =>
      'Central: 未接続(RASQ アカウントは作れません)';

  @override
  String get settingsBackendCentralDisconnectedDetail =>
      'Central: 未接続 — プラグインストアは同梱のものだけ、RASQ アカウントは作成できません(この端末のみ)。';

  @override
  String get settingsBackendOrgateDisconnected =>
      'ORGATE: 未接続(RASQ アカウントにログインできません)';

  @override
  String get settingsBackendTestEndpointsSection => 'テスト用の接続先';

  @override
  String get settingsBackendTestEndpointsTitle =>
      'ダミーの SNS とデモの Central / ORGATE を使う';

  @override
  String get settingsBackendTestEndpointsSubtitle => 'プレビューの録画用';

  @override
  String settingsBackendTestEndpointsDetail(
    String misskeyHost,
    String mastodonHost,
    String blueskyHost,
    String centralPort,
    String orgatePort,
  ) {
    return 'プレビュー録画用。Misskey / Mastodon / Bluesky の $misskeyHost / $mastodonHost / $blueskyHost をこのアドレスのダミーへ向け、Central(:$centralPort)と ORGATE(:$orgatePort)も切り替えます';
  }

  @override
  String get settingsBackendTestAddressLabel =>
      'ダミー環境のアドレス(同じ機械なら 127.0.0.1、ほかの機械なら その IP)';

  @override
  String get settingsBackendTestCaption => 'SNS のログイン画面で、サーバーに上のホスト名を入れてください。';

  @override
  String get settingsBackendTestCaptionDetail =>
      'SNS は各ログイン画面でサーバーに上のホスト名を入れます(許可ページは自動で通ります。Bluesky の ID / パスワードは何でも可)。RASQ アカウントはアカウントのログインから。切り替えたら、すでにログインしている SNS は次の読み込みから新しい接続先になります。';

  @override
  String get settingsBackendAccountSection => 'RASQ アカウント';

  @override
  String settingsBackendAccountLoadError(String error) {
    return 'アカウントを取得できませんでした: $error';
  }

  @override
  String get settingsBackendNoServer => '接続先が設定されていません。';

  @override
  String get settingsBackendAccountNotCreated => 'RASQ アカウントは未作成です。';

  @override
  String get settingsBackendOpenAccountButton => 'RASQ アカウントを開く';

  @override
  String get settingsBackendAccountDeviceOnly =>
      'この端末でだけ有効なアカウントです。ハンドルと表示名はプロフィール編集から変更できます。';

  @override
  String get settingsBackendBundleSection => 'アカウントバンドル';

  @override
  String get settingsBackendBundleCaption =>
      'まとめるときに送るのは、SNS アカウントの一覧だけです。ログインの鍵は、端末間の共有・Web 版・アカウントページへの投稿の表示を選んだときだけ送ります。';

  @override
  String get settingsBackendBundleCaptionDetail =>
      '束ねるときにサーバーへ送るのは、SNS の種類・サーバー・アカウント・表示名だけ。アクセストークンは、端末間の共有(E2E、サーバーは読めない)、Web 版の保管庫(サーバーの鍵で暗号化、サーバーは復号できる)、アカウントページへの投稿の表示(同上)を選んだときだけ送る(プライバシーポリシー第 4 項)。';

  @override
  String get settingsBackendNoSessions => 'ログイン中のアカウントはありません。';

  @override
  String get settingsColumnsTitle => 'カラムの幅';

  @override
  String get settingsColumnsIntroCaption => 'タブレットや PC など広い画面で、左右のカラムの幅を決めます。';

  @override
  String get settingsColumnsIntroDetail =>
      '幅の広い画面(タブレット / デスクトップ / Web)で、小型カラム(検索や、ページを開いた側)と大型カラム(開いたページ)の幅の比を決めます。';

  @override
  String get settingsColumnsSplitHeader => '小型 / 大型カラムの比';

  @override
  String settingsColumnsSplitDefault(String hint) {
    return '$hint(既定)';
  }

  @override
  String get settingsColumnsLargeWidthLabel => '大型カラムの幅';

  @override
  String get settingsColumnsSmallWidthLabel => '小型カラムの幅';

  @override
  String get settingsColumnsShrinkCaption => '画面に入らないときは、自動で縮めます。';

  @override
  String settingsColumnsShrinkDetail(String minWidth) {
    return '画面が狭くて入らないときは、もう片方のカラムを $minWidth px 以上残し、小型カラムが大型カラムより広くならないように縮めます。';
  }

  @override
  String get settingsColumnsSwingInColumnTitle => 'Swing を右のカラムで開く';

  @override
  String get settingsColumnsSwingInColumnSubtitle =>
      'オフのときは全画面で開きます(はじめはオン。全画面を指定したプラグインの Swing はいつも全画面)';

  @override
  String get settingsColumnsCurrentHeader => 'いまの画面での幅';

  @override
  String settingsColumnsPreviewWidths(String small, String large) {
    return '小型 $small px / 大型 $large px';
  }

  @override
  String get settingsColumnsNarrowCaption => 'いまの画面は狭いので、カラムは 1 つです。';

  @override
  String settingsColumnsNarrowDetail(String breakpoint) {
    return 'いまの画面は幅が狭いので、カラムを 1 つだけ出しています($breakpoint px 以上で小型 / 大型のカラムに分かれます)。';
  }

  @override
  String get settingsColumnsPreviewSmall => '小型';

  @override
  String get settingsColumnsPreviewLarge => '大型';

  @override
  String get settingsComposerTitle => '投稿コンポーザー';

  @override
  String get settingsComposerAutoAccountTitle => '投稿アカウントの自動選択';

  @override
  String get settingsComposerAutoAccountSubtitle =>
      '下書きに合うアカウントへ、投稿先を自動で切り替えます';

  @override
  String get settingsComposerAutoAccountDetail =>
      '下書きの内容がポスト先の絞り込みに合うアカウントへ、投稿先を自動で切り替えます(手動選択が常に優先)';

  @override
  String get settingsComposerRasqLinkedTitle => 'RASQ アカウントへも連動投稿する';

  @override
  String get settingsComposerRasqLinkedSubtitle =>
      '複数のアカウントに投稿するとき、RASQ アカウントも選べます';

  @override
  String get settingsComposerRasqLinkedDetail =>
      '複数選択モードで、RASQ アカウントの行も選べるようになります(通常投稿 / ノード連動)。届け方と絞り込みは「投稿先のカスタマイズ」の RASQ のタブで決めます。RASQ の上限(1000 文字 / 添付 6 つ / 投票 6 個 / 投稿 3 件)を超える投稿は、RASQ へは送られません';

  @override
  String get settingsEmomTitle => 'EmoM の閾値';

  @override
  String get settingsEmomBandLow => '控えめ — 運営が制限したトレンドを早めに隠します';

  @override
  String get settingsEmomBandMiddle => 'ふつう';

  @override
  String get settingsEmomBandHigh => '広め — 運営が強く制限したトレンドだけを隠します';

  @override
  String get settingsEmomStatusSending => '送っています…';

  @override
  String get settingsEmomStatusNoAccount =>
      'RASQ アカウントでログインすると公開できます(この端末では使えます)';

  @override
  String get settingsEmomStatusFailed =>
      '送れませんでした。次に開いたとき(またはトレンドを読み直したとき)送り直します';

  @override
  String settingsEmomStatusDisclosed(String value) {
    return '公開しています(値 $value)';
  }

  @override
  String get settingsEmomStatusPending => 'まだ届いていません';

  @override
  String get settingsEmomStatusNotDisclosed => '公開していません';

  @override
  String get settingsEmomIntro =>
      'EmoM は、投稿やトレンドの気持ちの強さ・刺激の強さを見積もる RASQ のモデルです(準備中)。いまはこの閾値を、RASQ の運営が通報を確かめてトレンドを制限するときの目安にだけ使います。';

  @override
  String get settingsEmomThresholdLabel => '閾値';

  @override
  String get settingsEmomScaleLow => '低い(隠れやすい)';

  @override
  String get settingsEmomScaleHigh => '高い(隠れにくい)';

  @override
  String settingsEmomExplanation(String defaultValue) {
    return '閾値が高いほど、刺激の強い話題も受け入れる設定です。運営が制限したトレンドが隠れにくくなります。低いほど、制限されたトレンドを早めに隠します。既定は $defaultValue です。';
  }

  @override
  String get settingsEmomDiscloseTitle => '閾値を公開する(制限の目安に使う)';

  @override
  String get settingsEmomDiscloseSubtitle =>
      '値だけを RASQ のサーバーに送ります。運営は、公開された値をまとめた分布(どの値の人が何人いるか)だけを使い、あなたの値を個別に見ることはありません。オフにすると、送った値を消します。';

  @override
  String get settingsEmomRestrictionExplanation =>
      '運営がトレンドを「N%」で制限すると、公開された閾値の低いほうから N% ほどの人に、そのトレンドが出なくなります。公開していなくても、この端末の閾値で同じように判定します(閾値はこの端末に保存されます)。「全員に非表示」にされたトレンドは、閾値に関係なく出ません。隠れたトレンドは、検索のトレンドの一覧に並ばなくなるだけです。';

  @override
  String get settingsHomeTitle => '全ての設定';

  @override
  String get settingsHomeSearchHint => '設定や操作を検索';

  @override
  String get settingsHomeSearchClear => '消す';

  @override
  String get settingsHomeSearchError => '設定を探せませんでした';

  @override
  String get settingsHomeSearchEmpty => '見つかりませんでした';

  @override
  String settingsHomeSearchEmptyHint(String query) {
    return '「$query」に当たる設定はありません。言い方を変えるか、RAi に聞いてみてください';
  }

  @override
  String get settingsHomeSearchOperations => '操作(RAi が案内します)';

  @override
  String get settingsHomeOtherHeader => 'その他の設定';

  @override
  String get settingsHomeComposer => '投稿コンポーザー';

  @override
  String get settingsHomeComposerKeywords => '投稿の画面,下書き';

  @override
  String get settingsHomeThemeKeywords => '着せ替え,テーマ,ダークモード,ライト,色,フォント';

  @override
  String get settingsHomeAccountImportant => 'アカウントの重要設定';

  @override
  String get settingsHomeAccountImportantSubtitle => 'パスワードの変更やアカウント削除は web 版で';

  @override
  String get settingsHomeAccountImportantDetail =>
      'パスワードの再設定やアカウント削除など、パスワードがいる処理は web 版で行います';

  @override
  String settingsHomeLogout(String handle) {
    return '@$handleからログアウト';
  }

  @override
  String get settingsHomeLogoutConfirmTitle => 'ログアウトしますか？';

  @override
  String get settingsHomeLogoutConfirmMessage => 'このアカウントのプラグイン構成はデバイスに残ります。';

  @override
  String get settingsHomeLogoutConfirm => 'ログアウト';

  @override
  String get settingsHomeCancel => 'キャンセル';

  @override
  String get settingsHomeOk => 'OK';

  @override
  String get settingsHomeGenericTitle => '設定';

  @override
  String get settingsHomeUnknownSection => '不明な設定セクション';

  @override
  String get settingsHomeThemeModeSystem => 'システム';

  @override
  String get settingsHomeThemeModeLight => 'ライト';

  @override
  String get settingsHomeThemeModeDark => 'ダーク';

  @override
  String get settingsHomePlaceholder => 'この設定は準備中です。';

  @override
  String get settingsHomePlaceholderDetail =>
      'この設定は第二階層以降の仕様確定後(M4: FOW/DSL 描画)に実装します。';

  @override
  String get settingsHomePageMissing => 'このページはありません';

  @override
  String get settingsHomePageMissingHint => 'このアカウントの SNS には、この設定がありません。';

  @override
  String get settingsHomePageLoadError => '設定ページを読み込めません';

  @override
  String get settingsHomeRemoteLoadError => 'サーバーから設定を取得できません';

  @override
  String get settingsHomeRemotePermissionHint =>
      '\n\nアプリの権限が不足しています。一度ログアウトして再ログインすると、新しい権限が付与されます。';

  @override
  String get settingsHomeSaveFailed => '保存できませんでした';

  @override
  String get settingsHomeChildLocked => '見守り中のため、ここは変えられません(閲覧注意のメディアは必ず隠します)。';

  @override
  String get settingsHomeTargetAccount => '設定するアカウント';

  @override
  String settingsHomeMissingSnsPage(String area) {
    return 'SNS プラグインが設定ページ \"$area\" を提供していません';
  }

  @override
  String get settingsLearningTitle => 'アルゴリズムとコミュニティへの貢献';

  @override
  String settingsLearningError(String error) {
    return 'できませんでした — $error';
  }

  @override
  String get settingsLearningGrantConfirmButton => '同意して参加する';

  @override
  String get settingsLearningGrantPointOptional =>
      '任意です。断っても、やめても、RASQ の機能や有料機能はそのまま使えます';

  @override
  String get settingsLearningGrantPointScope =>
      '対象は、あなたが自分で書いた公開の投稿と、その投稿どうしが同じ会話かどうかだけです';

  @override
  String get settingsLearningGrantPointExcluded =>
      'ほかの人の投稿、DM、限定公開の投稿、ASTell の会話、RAi の質問と答えは送りません';

  @override
  String get settingsLearningGrantPointVerifiedOnly =>
      '持ち主の確認が済んだ SNS アカウントの投稿だけを受け付けます';

  @override
  String get settingsLearningGrantPointPurpose =>
      'リレーショナルタイムラインの会話のまとめ方の改善に使います';

  @override
  String get settingsLearningGrantPointDeletion => 'やめたときは、送ったデータをすぐに消します';

  @override
  String get settingsLearningGrantExtendedNotice =>
      '検証用の設定です。ほかの人の投稿の判定や RAi のやりとりも送ります。';

  @override
  String get settingsLearningGrantExtendedNoticeDetail =>
      'CENTRAL_LEARNING_SCOPE=extended(S-049 / S-050)。正式な環境では使わない。';

  @override
  String get settingsLearningGrantScopeDetail =>
      'D-370 / S-051。関連 TL の会話イベントから自分の投稿(公開と分かるもの。Bluesky はすべて公開)だけを POST /me/learning/contributions へ(v2、self = 自分の SNS アカウント)。Central は持ち主の確認(sns_links.verified_at)と、全投稿が a=-1・vis=public かを確かめる。受け取るたびに年齢と保護者の同意も確かめ直す。本文の @メンションと URL は伏せる。';

  @override
  String get settingsLearningGrantReadFullButton => '説明の全文を読む';

  @override
  String get settingsLearningGrantAgreeCheckbox => '説明を読み、データの提供に同意します';

  @override
  String settingsLearningDocumentVersion(String version) {
    return '文書の版: $version';
  }

  @override
  String get settingsLearningAgeTitle => '年齢の申告';

  @override
  String get settingsLearningAgeConfirmButton => '申告する';

  @override
  String get settingsLearningGuardianConsent => '保護者の同意を得ています';

  @override
  String get settingsLearningAgeDeclared => '年齢を申告しました';

  @override
  String get settingsLearningCodeSheetTitle => '撤回用のコードで撤回';

  @override
  String get settingsLearningCodeConfirmButton => '撤回する';

  @override
  String get settingsLearningCodeSheetBody =>
      '同意したときに発行されたコードを入れます。提供した RASQ アカウントに入れなくなった場合でも撤回できます。';

  @override
  String get settingsLearningCodeHint => '撤回用のコード';

  @override
  String get settingsLearningWithdrawnByCode => 'やめました。送ったデータは消します';

  @override
  String get settingsLearningReasonAgeRequired => '年齢の申告が必要です';

  @override
  String get settingsLearningReasonUnder16 => '16 歳以上から参加できます';

  @override
  String get settingsLearningReasonGuardianRequired => '16〜17 歳の人は、保護者の同意が必要です';

  @override
  String get settingsLearningIntroNotice =>
      'あなたが書いた公開の投稿を送って、会話のまとめ方の改善に協力できます。任意で、いつでもやめられます。';

  @override
  String get settingsLearningIntroNoticeDetail =>
      'D-243 / D-363 / D-370。同意は Central の account_consents(kind = learning)に記録。既定の範囲(own)では、関連 TL の会話の中の自分の公開投稿だけを POST /me/learning/contributions へ送る。正式な環境では受付を閉じる(CENTRAL_LEARNING_OPEN=false)。';

  @override
  String get settingsLearningReadAboutTitle => '説明を読む';

  @override
  String get settingsLearningReadAboutSubtitle => '送るもの、使いみち、保存する期間';

  @override
  String get settingsLearningStatusSection => '状態';

  @override
  String get settingsLearningServerNotConfiguredTitle => 'RASQ サーバーの接続先が未設定です';

  @override
  String get settingsLearningServerNotConfiguredSubtitle => '接続先を入れると確認できます';

  @override
  String get settingsLearningNoAccountTitle => 'RASQ アカウントが未作成です';

  @override
  String get settingsLearningNoAccountSubtitle => 'データの提供は RASQ アカウントごとに記録します';

  @override
  String settingsLearningLoadError(String error) {
    return '取得できませんでした: $error';
  }

  @override
  String get settingsLearningStatusTitle => '貢献';

  @override
  String get settingsLearningStatusJoined => '参加中';

  @override
  String get settingsLearningStatusNotJoined => '参加していません';

  @override
  String get settingsLearningSinceTitle => '同意した日';

  @override
  String get settingsLearningOpenTitle => '受付';

  @override
  String get settingsLearningOpenYes => '受付中';

  @override
  String get settingsLearningOpenNo => 'まだ始まっていません';

  @override
  String get settingsLearningAgeUndeclared => '未申告';

  @override
  String get settingsLearningSentTitle => '送ったデータ';

  @override
  String settingsLearningSentValue(int relational, int rai) {
    String _temp0 = intl.Intl.pluralLogic(
      relational,
      locale: localeName,
      other: '$relational 件',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rai,
      locale: localeName,
      other: '$rai 件',
    );
    return '会話 $_temp0 ・ RAi $_temp1';
  }

  @override
  String get settingsLearningExamplesTitle => 'クラウドの判定の例';

  @override
  String settingsLearningExamplesValue(int examples, int hardNegative) {
    String _temp0 = intl.Intl.pluralLogic(
      examples,
      locale: localeName,
      other: '$examples 件',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hardNegative,
      locale: localeName,
      other: '$hardNegative 件',
    );
    return '$_temp0(怪しいけど違う $_temp1)';
  }

  @override
  String get settingsLearningPostsLabelsTitle => '投稿 / ラベル';

  @override
  String get settingsLearningModelsTitle => 'このデータを使ったモデル';

  @override
  String get settingsLearningModelsNone => 'なし';

  @override
  String get settingsLearningModelsSeparator => '、';

  @override
  String get settingsLearningWithdrawTitle => '貢献をやめる';

  @override
  String get settingsLearningWithdrawMessage => 'データを送るのをすぐに止め、送ったデータも消します。';

  @override
  String get settingsLearningWithdrawConfirm => 'やめる';

  @override
  String get settingsLearningCancel => 'キャンセル';

  @override
  String get settingsLearningWithdrawn => '撤回しました';

  @override
  String get settingsLearningDeclareAgeButton => '年齢を申告する';

  @override
  String get settingsLearningGranted =>
      '参加しました。下のコードを控えておくと、ログインできなくなってもやめられます';

  @override
  String get settingsLearningGrantButton => '内容を確認して参加する';

  @override
  String get settingsLearningGrantClosedButton => '受付はまだ始まっていません';

  @override
  String get settingsLearningCodeSection => '撤回用のコード';

  @override
  String get settingsLearningCodeSubtitle =>
      'タップでコピー。ログインできなくなっても、このコードでやめられます';

  @override
  String get settingsLearningCodeCopied => '撤回用のコードをコピーしました';

  @override
  String get settingsLearningCodeStoredOnGrantDevice =>
      '撤回用のコードは、同意した端末に控えてあります。';

  @override
  String get settingsLearningOtherSection => 'そのほか';

  @override
  String get settingsLearningByCodeTitle => '撤回用のコードでやめる';

  @override
  String get settingsLearningByCodeSubtitle => 'ログインできなくなったとき';

  @override
  String get settingsLearningDeletionCaption =>
      'アカウントを削除したときも、送ったデータは消えます。ほかの人が参加しているかは、だれにも調べられません。';

  @override
  String get settingsLearningDeletionCaptionDetail =>
      'RASQ アカウントを削除したときも、提供の停止と提供済みデータの削除が同時に始まります(learning_contributions は accounts の削除で消える)。ほかの人がデータを提供しているかどうかは、だれにも調べられません(GET /me/learning は自分の状態だけ)。';

  @override
  String get settingsLearningKindsSection => '送るもの';

  @override
  String get settingsLearningKindRelationalTitle => '自分の公開投稿';

  @override
  String get settingsLearningKindRelationalSubtitleExtended => 'タイムラインでまとまった会話';

  @override
  String get settingsLearningKindRelationalSubtitle =>
      'タイムラインで会話にまとまった、あなたの公開の投稿';

  @override
  String get settingsLearningKindRelationalDetailExtended =>
      '会話イベント(束)の公開の投稿。書き手ごとに学習してよいかを判定し、許可の書き手と自分の投稿だけを送る。本文の @メンションと URL は伏せる。';

  @override
  String get settingsLearningKindRelationalDetail =>
      'D-370。会話イベントの中の自分の投稿(公開と分かるもの)と、その投稿どうしが同じ会話であること(関連のラベル)。ほかの人の投稿は数(参加者・投稿数)だけ。';

  @override
  String get settingsLearningUnverifiedNotice =>
      '持ち主の確認が済んでいない SNS アカウントの投稿は受け付けられませんでした。プロフィールの編集から確認できます。';

  @override
  String get settingsLearningUnverifiedButton => '確認する';

  @override
  String get settingsLearningKindCloudTitle => 'クラウドでまとめる';

  @override
  String get settingsLearningKindCloudSubtitle => '迷う会話のまとまりを、クラウドの RAi が判断します';

  @override
  String get settingsLearningKindCloudDetail =>
      'D-367 / S-050。端末のエンジンがしきい値の近くで決めた結び付き(投稿 → 会話)を POST /me/relational/judge に送り、クラウドの LLM の判定で組み直す。書き手が許可済みの組だけ。判定の例(怪しいけど違う = hard_negative、分けたけど同じ = hard_positive)は学習用に残り、やめると消える。';

  @override
  String get settingsLearningKindRaiSubtitle => 'RAi への質問と答え';

  @override
  String get settingsLearningKindRaiDetail =>
      '質問(@メンションと URL は伏せる)、答え、モード、使った関数の名前、モデルの id。ほかの人の投稿は含めない。';

  @override
  String get settingsLearningPreloadTitle => '端末のモデルを先に読み込む';

  @override
  String get settingsLearningPreloadSubtitle => '判定の下見を早くします(ダウンロード済みのときだけ)';

  @override
  String get settingsLearningPreloadDetail =>
      'RAi の端末内モデル(既定 Qwen3.5 2B)を起動の少しあとに読み込み、書き手の下見に使う。未ダウンロードならダウンロードはしない(規則だけで下見)。';

  @override
  String get settingsLearningDebugSection => '開発者向けの詳細';

  @override
  String get settingsLearningDebugActiveTitle => '集めているか';

  @override
  String get settingsLearningDebugActiveYes => 'はい';

  @override
  String get settingsLearningDebugActiveNo => 'いいえ(同意・受付・見守りを確認)';

  @override
  String get settingsLearningDebugScopeTitle => '受け付ける範囲';

  @override
  String get settingsLearningDebugScopeExtended => 'extended(検証用)';

  @override
  String get settingsLearningDebugScopeOwn => 'own(自分の公開投稿だけ)';

  @override
  String get settingsLearningDebugPendingTitle => '送信待ち';

  @override
  String settingsLearningDebugPendingValue(String relational, String rai) {
    return '会話 $relational ・ RAi $rai';
  }

  @override
  String get settingsLearningDebugSentTitle => 'この起動で送った';

  @override
  String settingsLearningDebugSentValue(
    String relational,
    String rai,
    String skipped,
  ) {
    return '会話 $relational ・ RAi $rai ・ 見送り $skipped';
  }

  @override
  String settingsLearningDebugCloudValue(
    String decisions,
    String hardNegative,
    String hardPositive,
    String agree,
    String pending,
    String skipped,
  ) {
    return '判定 $decisions(怪しいけど違う $hardNegative ・ 分けたけど同じ $hardPositive ・ 一致 $agree)・ 待ち $pending ・ 見送り $skipped';
  }

  @override
  String get settingsLearningDebugCloudOff => 'オフ';

  @override
  String get settingsLearningDebugModelTitle => '端末のモデル';

  @override
  String get settingsLearningDebugFlushing => '送信中…';

  @override
  String get settingsLearningDebugFlushButton => '今すぐ送る';

  @override
  String get settingsLearningDebugVerdictsSection => '書き手の判定';

  @override
  String get settingsLearningDebugLogSection => '記録';

  @override
  String get settingsLegalTitle => 'ヘルプ、法的表示';

  @override
  String get settingsLegalVersionTitle => 'バージョン';

  @override
  String get settingsLegalHelpTitle => 'ヘルプ';

  @override
  String get settingsLegalTourTitle => 'RASQ の使い方をもう一度見る';

  @override
  String get settingsLegalCookiesTitle => 'クッキーについて';

  @override
  String get settingsLegalPluginTermsHeader => 'SNS プラグインの規約';

  @override
  String get settingsLegalPluginNoTerms => '規約の記載なし';

  @override
  String get settingsLegalLicensesHeader => 'ライセンス';

  @override
  String get settingsLegalLicensesTitle => 'オープンソースライセンス';

  @override
  String get settingsLegalLicensesSubtitle => 'Flutter と同梱ライブラリ';

  @override
  String get settingsMuteBlockTitle => 'ミュート/ブロック';

  @override
  String get settingsMuteBlockBlockTab => 'ブロック';

  @override
  String get settingsMuteBlockMuteTab => 'ミュート';

  @override
  String get settingsMuteBlockBlockedUsers => 'ブロックしたユーザー';

  @override
  String get settingsMuteBlockBlockedWords => 'ブロックしたワード';

  @override
  String get settingsMuteBlockBlockedLists => 'ブロックしたリスト';

  @override
  String get settingsMuteBlockComingSoonHint => '準備中です';

  @override
  String get settingsMuteBlockComingSoonDetail => 'ワード/リストのブロックは M2 後半';

  @override
  String get settingsMuteBlockRetryButton => '再読み込み';

  @override
  String get settingsMuteBlockNoBlockedUsers => 'ブロックしたユーザーはいません';

  @override
  String get settingsMuteBlockNoMutedUsers => 'ミュートしたユーザーはいません';

  @override
  String get settingsMuteBlockBlockButton => 'ブロック';

  @override
  String get settingsMuteBlockMuteButton => 'ミュート';

  @override
  String get settingsMuteBlockBlockingButton => 'ブロック中';

  @override
  String get settingsMuteBlockMutingButton => 'ミュート中';

  @override
  String get settingsNotifyTokenTitle => '通知専用のアクセストークン';

  @override
  String settingsNotifyTokenError(String error) {
    return 'できませんでした — $error';
  }

  @override
  String get settingsNotifyTokenCaption => '通知を受け取るためだけの鍵です。投稿やアカウントの操作はできません。';

  @override
  String get settingsNotifyTokenCaptionDetail =>
      '通知トークンは、RASQ サーバーからの通知を受け取るためだけのトークンです(読めるのは自分宛ての通知の受信箱だけ。投稿やアカウントの操作はできません)。マクロ / ASTell 用の配下トークンもここから発行します。';

  @override
  String get settingsNotifyTokenStatusSection => '状態';

  @override
  String get settingsNotifyTokenPushTitle => 'プッシュ配信';

  @override
  String get settingsNotifyTokenPushPending => '準備中';

  @override
  String get settingsNotifyTokenPushPendingDetail => 'ダミー(APNs / FCM は未接続)';

  @override
  String get settingsNotifyTokenServerNotConfiguredTitle =>
      'RASQ サーバーの接続先が未設定です';

  @override
  String get settingsNotifyTokenServerNotConfiguredSubtitle => '接続先を入れると発行できます';

  @override
  String get settingsNotifyTokenNoAccountTitle => 'RASQ アカウントが未作成です';

  @override
  String get settingsNotifyTokenNoAccountSubtitle => '作成すると通知トークンを発行できます';

  @override
  String settingsNotifyTokenLoadError(String error) {
    return '取得できませんでした: $error';
  }

  @override
  String get settingsNotifyTokenLocalTokenTitle => 'この端末のトークン';

  @override
  String get settingsNotifyTokenLocalTokenActive => '有効';

  @override
  String get settingsNotifyTokenLocalTokenNone => '未発行';

  @override
  String get settingsNotifyTokenDevicesTitle => 'プッシュ登録している端末';

  @override
  String settingsNotifyTokenDevicesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return '$_temp0';
  }

  @override
  String get settingsNotifyTokenTestNotFound => 'テスト通知を積みましたが、受信箱で見つかりませんでした';

  @override
  String settingsNotifyTokenTestFound(
    String title,
    String status,
    int devices,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      devices,
      locale: localeName,
      other: '$devices 台',
    );
    return '受信箱で確認できました: 「$title」($status、端末 $_temp0)';
  }

  @override
  String get settingsNotifyTokenTestButton => 'テスト通知を送る';

  @override
  String get settingsNotifyTokenLocalRevoked => 'この端末のトークンを失効しました';

  @override
  String get settingsNotifyTokenRevokeButton => '失効する';

  @override
  String get settingsNotifyTokenEnabled => '発行して、この端末をプッシュ登録しました';

  @override
  String get settingsNotifyTokenEnableButton => '通知トークンを発行してこの端末を登録';

  @override
  String get settingsNotifyTokenTokensSection => '発行済みのトークン';

  @override
  String get settingsNotifyTokenKindRoot => '通知トークン';

  @override
  String get settingsNotifyTokenKindChild => '配下トークン';

  @override
  String settingsNotifyTokenLabelSuffix(String label) {
    return '($label)';
  }

  @override
  String get settingsNotifyTokenThisDevice => 'この端末';

  @override
  String settingsNotifyTokenIssuedAt(String time) {
    return '発行 $time';
  }

  @override
  String get settingsNotifyTokenUnused => '未使用';

  @override
  String settingsNotifyTokenLastUsedAt(String time) {
    return '最終使用 $time';
  }

  @override
  String get settingsNotifyTokenIssueChildTooltip =>
      '配下トークンを発行(マクロ / ASTell 共用)';

  @override
  String get settingsNotifyTokenChildIssued =>
      '配下トークンを発行してクリップボードにコピーしました(生の値が見られるのは今だけです)';

  @override
  String get settingsNotifyTokenRevoked => '失効しました';

  @override
  String get settingsNotifyTokenStorageCaption => '鍵はこの端末の中に安全に保存します。';

  @override
  String get settingsNotifyTokenStorageCaptionDetail =>
      '生のトークンは発行時にだけ受け取り、端末内の安全な領域に保存します。サーバーに残るのはハッシュだけです。親のトークンを失効すると配下のトークンも失効します。';

  @override
  String get settingsSectionsPluginsTitle => 'プラグインの構成';

  @override
  String get settingsSectionsPluginsProxyTitle => 'RASQプラグインプロキシの購読';

  @override
  String get settingsSectionsPluginsProxySubtitle => '準備中';

  @override
  String get settingsSectionsPluginsProxyDetail => '未購読(第二期)';

  @override
  String get settingsSectionsPluginsActionBarTitle => '投稿にプラグインオートメーションを配置';

  @override
  String get settingsSectionsPluginsActionBarSubtitle => '投稿の下に出すプラグインのボタン';

  @override
  String get settingsSectionsPluginsActionBarDetail =>
      '投稿のアクションバーに出すプラグインボタン(主電源 / 自動でオン / 配置)';

  @override
  String get settingsSectionsPluginsTrendTitle => 'カスタムトレンドの配信';

  @override
  String get settingsSectionsPluginsComposerTitle => '投稿プラグイン';

  @override
  String get settingsSectionsPluginsTimelineTitle => 'カスタムタイムラインを配置';

  @override
  String get settingsSectionsPluginsStoreTitle => 'プラグインの詳細設定';

  @override
  String get settingsSectionsPluginsStoreSubtitle => 'プラグインストア(インストール済みの管理)';

  @override
  String get settingsSectionsPluginsTelemetryTitle => '怪しい通信の通報';

  @override
  String get settingsSectionsPluginsTelemetrySubtitle => '既定はオフ';

  @override
  String get settingsSectionsPluginsTelemetryDetail =>
      '通信の形の報告: プラグインの通信の形(値は含まない)を、初めて見たときだけストアへ。既定はオフ';

  @override
  String get settingsSectionsSnsTitle => 'SNSプラグイン';

  @override
  String get settingsSectionsSnsAccountTitle => 'アカウント';

  @override
  String get settingsSectionsSnsTimelineTitle => 'タイムライン';

  @override
  String get settingsSectionsSnsSecurityTitle => 'セキュリティ';

  @override
  String get settingsSectionsSnsSafetyTitle => 'プライバシーとセーフモード';

  @override
  String get settingsSectionsSnsChildSafeTitle => 'チャイルドセーフ';

  @override
  String get settingsSectionsSnsChildSafeSubtitle => '保護者の見守り / チャイルドモード';

  @override
  String get settingsSectionsSnsChildSafeDetail =>
      '保護者として見守る / チャイルドモード(保護者のコードでつなぐ)';

  @override
  String get settingsSectionsSnsListsTitle => 'リスト';

  @override
  String get settingsSectionsSnsMuteBlockTitle => 'ミュート/ブロック';

  @override
  String get settingsSectionsSnsPluginButtonsTitle => 'プラグインボタン';

  @override
  String get settingsSectionsSnsPluginButtonsSubtitle => 'プラグインのボタンの出し方';

  @override
  String get settingsSectionsSnsPluginButtonsDetail =>
      '面ごとの主電源と「開いたとき自動でオン」、このアカウントの有効 / 無効と束ねる閾値';

  @override
  String get settingsSectionsSnsEmojiSearchTitle => '絵文字の検索';

  @override
  String get settingsSectionsSnsEmojiSearchSubtitle => '意味の近い絵文字も探す';

  @override
  String get settingsSectionsSnsEmojiSearchDetail => '意味の近い絵文字も探す(端末内のモデル)';

  @override
  String get settingsSectionsSnsReactionPredictTitle => 'リアクションの予測';

  @override
  String get settingsSectionsSnsReactionPredictSubtitle => 'だれも付けていない投稿でも予測するか';

  @override
  String get settingsSectionsSnsAccountPickTitle => '共有 / リノートに使うアカウント';

  @override
  String get settingsSectionsSnsAccountPickSubtitle => '同じ投稿が複数のアカウントに見えるとき';

  @override
  String get settingsSectionsSnsAccountPickDetail =>
      '複数のアカウントに見えている投稿を、どのアカウントで扱うか';

  @override
  String get settingsSectionsSnsMfmTitle => 'カスタムモーションとアニメーション';

  @override
  String get settingsSectionsSnsResourcesTitle => 'リソースと広告';

  @override
  String get settingsSectionsSnsLegalTitle => 'ヘルプ、法的表示';

  @override
  String get settingsSectionsSnsNote =>
      'アカウント / タイムライン / セキュリティ / プライバシーは、使っている SNS のプラグインが用意するページです(プラグインが用意していないものは出ません)。';

  @override
  String get settingsSectionsSnsNoteDetail =>
      'アカウント / タイムライン / セキュリティ / プライバシーは、設定するアカウントの SNS プラグインが提供する設定ページです(sns.settingsPages。宣言されていないページの行は出さない、D-482)。';

  @override
  String get settingsSectionsAppearanceTitle => 'アプリの外観';

  @override
  String get settingsSectionsAppearanceDisplayTitle => 'インターフェースの表示サイズ';

  @override
  String get settingsSectionsAppearanceThemeTitle => 'フォントやカラースキーム';

  @override
  String get settingsSectionsAppearanceThemeSubtitle => '着せ替え(色・アイコン・背景の画像)';

  @override
  String get settingsSectionsAppearanceColumnsTitle => 'カラムの幅';

  @override
  String get settingsSectionsAppearanceColumnsSubtitle => '広い画面での左右のカラムの幅';

  @override
  String get settingsSectionsAppearanceColumnsDetail =>
      '幅の広い画面の小型 / 大型カラムの比(1:1 / 2:3 / 3:5 / 幅を固定)';

  @override
  String get settingsSectionsAppearanceMotionTitle => 'モーションの抑制';

  @override
  String get settingsSectionsAppearanceTimelineTitle => 'タイムラインの表示';

  @override
  String get settingsSectionsAppearanceTimelineSubtitle => 'タイムラインの「投稿を読み込む」';

  @override
  String get settingsSectionsAppearanceTimelineDetail => 'TL の上下の「投稿を読み込む」';

  @override
  String get settingsSectionsAppearancePipTitle => 'ピクチャインピクチャ';

  @override
  String get settingsSectionsAppearanceFabTitle => '＋ ボタンの割り当て';

  @override
  String get settingsSectionsAppearanceFabSubtitle => '押したときに始めるもの';

  @override
  String get settingsSectionsAppearanceMediaSaveTitle => '画像・動画の保存先';

  @override
  String get settingsSectionsAppearanceMediaSaveSubtitle =>
      '写真(カメラロール)/ ファイル / 保存するたびに選ぶ';

  @override
  String get settingsSectionsAppearanceNotificationsTitle => '通知の表示形式';

  @override
  String get settingsSectionsAstellTitle => 'ASTell';

  @override
  String get settingsSectionsAstellSubscriptionTitle => 'ASTell 4Uを購読';

  @override
  String get settingsSectionsAstellSubscriptionSubtitle => '準備中';

  @override
  String get settingsSectionsAstellSubscriptionDetail => '未購読(第二期)';

  @override
  String get settingsSectionsAstellTilesTitle => 'Tellタイル';

  @override
  String get settingsSectionsAstellTrendTitle => 'トレンドタイムラインへの配信';

  @override
  String get settingsSectionsAstellRoomButtonsTitle => 'ルームのボタン';

  @override
  String get settingsSectionsAstellRoomButtonsSubtitle => '入力欄の左に並ぶボタン';

  @override
  String get settingsSectionsAstellRoomButtonsDetail =>
      'ルームの下段、入力欄の左の丸いボタンの並び(並べ替え / 表示 / 非表示 / プラグインのボタンを追加)';

  @override
  String get settingsSectionsAstellStoreTitle => 'プラグインの詳細設定';

  @override
  String get settingsSectionsAstellStoreSubtitle => 'ASTell で使うプラグイン';

  @override
  String get settingsSectionsAstellStoreDetail => 'ASTell のアクションプラグイン(ストア)';

  @override
  String get settingsSectionsAstellBackgroundTitle => '画面オフ時の動作';

  @override
  String get settingsSectionsRelationalTitle => 'リレーショナルタイムライン';

  @override
  String get settingsSectionsRelationalClusterTitle => '投稿クラスター';

  @override
  String get settingsSectionsRelationalClusterSubtitle => '会話のまとめ方';

  @override
  String get settingsSectionsRelationalClusterDetail =>
      '会話イベントの束ね方(束ねやすさ / 重み / 沈むまでの時間)';

  @override
  String get settingsSectionsRelationalRelayTitle => 'Relayタイル';

  @override
  String get settingsSectionsRelationalTrendTitle => 'トレンドタイムラインへの配信';

  @override
  String get settingsSectionsRelationalPluginsTitle => 'プラグインの詳細設定';

  @override
  String get settingsSectionsRelationalSamplingTitle => 'トレンドのサンプリングレベル';

  @override
  String get settingsSectionsRelationalSamplingSubtitle => '候補に入れる時間の幅';

  @override
  String get settingsSectionsRelationalSamplingDetail =>
      '候補に入れる時間の幅(束ね判定の詳細設定)';

  @override
  String get settingsSectionsRelationalNote => 'Relay タイルとトレンドへの配信は準備中です。';

  @override
  String get settingsSectionsRelationalNoteDetail =>
      'Relay タイルとトレンドへの配信はアルゴリズム確定後(D-011)。';

  @override
  String get settingsSectionsTrendTitle => 'トレンド';

  @override
  String get settingsSectionsTrendGenresTitle => 'ジャンル';

  @override
  String get settingsSectionsTrendTendencyTitle => 'トレンドの指向性/刺激性';

  @override
  String get settingsSectionsTrendEmomTitle => 'EmoM の閾値';

  @override
  String get settingsSectionsTrendEmomSubtitle => '運営が制限したトレンドの隠し方 / 閾値の公開';

  @override
  String get settingsSectionsTrendEmomDetail =>
      'EmoM の閾値(0〜100、既定 50)と「閾値を公開する」(既定オフ)。運営の制限の点数がこの値より大きいトレンドを一覧に出さない (D-404)';

  @override
  String get settingsSectionsTrendPluginsTitle => 'プラグインの詳細設定';

  @override
  String get settingsSectionsTrendCdnTitle => 'キャッシュネットワークの設定';

  @override
  String get settingsSectionsTrendCdnSubtitle => '準備中';

  @override
  String get settingsSectionsTrendCdnDetail => '未提供(第二期)';

  @override
  String get settingsSectionsRaiTitle => 'RAi(アシスタント)';

  @override
  String get settingsSectionsRaiGraphTitle => '工程グラフの自動表示';

  @override
  String get settingsSectionsNotificationsTitle => '通知';

  @override
  String get settingsSectionsNotificationsProfileTitle => 'プロファイル';

  @override
  String get settingsSectionsNotificationsAccessTokenTitle => 'アクセストークン';

  @override
  String get settingsSectionsNotificationsAccessTokenSubtitle => '通知を受け取るための設定';

  @override
  String get settingsSectionsNotificationsAccessTokenDetail =>
      '通知専用のトークンの発行 / 失効、端末のプッシュ登録';

  @override
  String get settingsSectionsNotificationsSecurityTitle => 'セキュリティ';

  @override
  String get settingsSectionsNotificationsSecuritySubtitle =>
      'SNS の権限とアクセストークン';

  @override
  String get settingsSectionsAboutTitle => 'RASQについて';

  @override
  String get settingsSectionsAboutServerTitle => 'RASQ サーバー';

  @override
  String get settingsSectionsAboutServerSubtitle => 'つなぐ先のサーバー';

  @override
  String get settingsSectionsAboutServerDetail =>
      'プラグインストア / RASQ アカウント / ログインの接続先';

  @override
  String get settingsSectionsAboutHelpTitle => 'ヘルプ';

  @override
  String get settingsSectionsAboutTourTitle => 'RASQ の使い方をもう一度見る';

  @override
  String get settingsSectionsAboutTourSubtitle =>
      '機能の紹介(TL・トレンド・ASTell・RAi など)';

  @override
  String get settingsSectionsAboutSubscriptionTitle => '購読状況';

  @override
  String get settingsSectionsAboutCookiesTitle => 'クッキーについて';

  @override
  String get settingsSectionsAboutPrivacyTitle => 'プライバシーポリシー';

  @override
  String get settingsSectionsAboutTermsTitle => '利用規約';

  @override
  String get settingsSectionsAboutLearningTitle => 'アルゴリズムとコミュニティへの貢献';

  @override
  String get settingsSectionsAboutLearningSubtitle => '任意。既定は「提供しない」';

  @override
  String get settingsSectionsAboutAstellTermsTitle => 'ASTell の利用条件';

  @override
  String get settingsSectionsAboutRaiTermsTitle => 'RAi の利用条件';

  @override
  String get settingsSectionsAboutStoreTermsTitle => 'プラグインストアの利用条件';

  @override
  String get settingsSectionsAboutDevTermsTitle => 'プラグイン開発者の掲載・審査条件';

  @override
  String get settingsSectionsAboutDevTermsSubtitle => '審査料を含む';

  @override
  String get settingsSectionsAboutBillingTitle => '料金・ポイントの条件';

  @override
  String get settingsSectionsAboutCommerceTitle => '特定商取引法に基づく表記';

  @override
  String get settingsSectionsAboutResourcesTitle => 'リソースと広告';

  @override
  String get settingsSectionsAboutLegalTitle => 'ヘルプ、法的表示';

  @override
  String get settingsSectionsAboutDeveloperTitle => '開発者モード';

  @override
  String get settingsSectionsAboutDeveloperSubtitle => '画面の説明を詳しく表示する';

  @override
  String get settingsSecurityAgoJustNow => 'たった今';

  @override
  String settingsSecurityAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 時間前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 日前',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityCodeSentTo(String to) {
    return '$to へ確認コードを送りました';
  }

  @override
  String get settingsSecurityTitle => 'アカウントのセキュリティ';

  @override
  String get settingsSecurityNotSignedIn => 'RASQ アカウントにログインしていません。';

  @override
  String get settingsSecurityToLoginTitle => '既存の RASQ アカウントにログイン';

  @override
  String get settingsSecurityToLoginSubtitle => 'ハンドル(かメール)とパスワード';

  @override
  String get settingsSecurityEmailHeader => 'メールアドレス';

  @override
  String get settingsSecurityEmailCaption =>
      'パスワードを忘れたときの再設定と、ログインの 2 段階目の確認に使います。ほかの人には見えません。';

  @override
  String get settingsSecurityEmailDetail =>
      '登録すると、パスワードを忘れたときの再設定、ほかの端末からログインするときの 2 段階目の確認(パスワードのあとにメールの確認コード)、大事な操作の確認とお知らせに使えます。メールを確認していないと、パスワードを忘れたときに再設定できません。ほかの人には見えません。';

  @override
  String get settingsSecurityEmailCurrentTitle => 'いまのメール';

  @override
  String get settingsSecurityEmailUnregistered => '未登録';

  @override
  String get settingsSecurityEmailNewHint => '新しいメールアドレス';

  @override
  String get settingsSecurityEmailHint => 'メールアドレス';

  @override
  String get settingsSecuritySendCodeButton => 'コードを送る';

  @override
  String get settingsSecurityEmailChangeNeedsPasswordOrCode =>
      '付け替えるには、いまのパスワードか、いまのメールに届く確認コードが要ります。';

  @override
  String get settingsSecurityEmailChangeNeedsCode =>
      '付け替えるには、いまのメールに届く確認コードが要ります。';

  @override
  String get settingsSecurityCurrentPasswordHint => 'いまのパスワード';

  @override
  String get settingsSecurityEmailSendCodeToCurrentButton => 'いまのメールにコードを送る';

  @override
  String get settingsSecurityEmailNeedsPassword =>
      'パスワードを設定したアカウントでは、メールアドレスを付けるのにいまのパスワードが要ります。';

  @override
  String settingsSecurityEmailPendingCaption(String email) {
    return '$email に届いたコードを入れてください(15 分で無効になります)。';
  }

  @override
  String get settingsSecurityEmailVerified => 'メールアドレスを確認しました';

  @override
  String get settingsSecurityVerifyButton => '確認';

  @override
  String get settingsSecurityEmailRemoveTitle => 'メールアドレスを外す';

  @override
  String get settingsSecurityEmailRemoveSubtitle => '確認コードが要ります';

  @override
  String get settingsSecurityPasswordHeader => 'パスワード';

  @override
  String get settingsSecurityPasswordChangeCaption =>
      '変えると、ほかの端末はログアウトになります。いまのパスワードか、メールの確認コードが要ります。';

  @override
  String get settingsSecurityPasswordNoneCaption =>
      'パスワードが無いと、ほかの端末からはログインできません(この端末でだけ使えます)。付けると、別の端末からハンドル(かメール)とパスワードで同じアカウントに入れます。';

  @override
  String get settingsSecurityPasswordNewHint => '新しいパスワード(8 文字以上)';

  @override
  String get settingsSecurityPasswordHint => 'パスワード(8 文字以上)';

  @override
  String get settingsSecurityPasswordChanged => 'パスワードを変えました';

  @override
  String get settingsSecurityPasswordSet => 'パスワードを設定しました';

  @override
  String get settingsSecurityPasswordChangeButton => 'パスワードを変える';

  @override
  String get settingsSecurityPasswordSetButton => 'パスワードを設定';

  @override
  String get settingsSecurityPasswordByCodeButton => 'メールのコードで変える';

  @override
  String get settingsSecurityPasswordResetWarning =>
      'パスワードを「再設定」すると、同期した設定は読めなくなります。';

  @override
  String get settingsSecurityPasswordResetWarningDetail =>
      'パスワードは、同期した設定の暗号化にも使います。「パスワードの再設定」(ログイン画面)をすると、前のパスワードで暗号化したデータは復号できなくなります。';

  @override
  String get settingsSecuritySecondFactorHeader => 'ログインの 2 段階目';

  @override
  String get settingsSecuritySecondFactorNeedsEmailCaption =>
      'メールアドレスを確認すると、ほかの端末からログインするとき、パスワードのあとにメールの確認コードも求めます(既定で ON)。';

  @override
  String get settingsSecuritySecondFactorActiveCaption =>
      'ほかの端末からログインするとき、パスワードのあとに、メールに届く確認コード(10 分有効)も求めます。';

  @override
  String get settingsSecuritySecondFactorOffCaption =>
      '切っています。ほかの端末からは、パスワードだけでログインできます。';

  @override
  String get settingsSecuritySecondFactorTitle => 'メールの確認コードも求める';

  @override
  String get settingsSecuritySecondFactorNeedsEmailSubtitle =>
      'メールアドレスの確認が要ります';

  @override
  String get settingsSecuritySecondFactorEnabled => 'ログインの 2 段階目を入れました';

  @override
  String get settingsSecuritySecondFactorDisableNeedsPasswordOrCode =>
      '切るには、いまのパスワードか、メールに届く確認コードが要ります。';

  @override
  String get settingsSecuritySecondFactorDisableNeedsCode =>
      '切るには、メールに届く確認コードが要ります。';

  @override
  String get settingsSecuritySendCodeToEmailButton => 'メールにコードを送る';

  @override
  String get settingsSecurityCancelButton => 'やめる';

  @override
  String get settingsSecuritySecondFactorDisabled => 'ログインの 2 段階目を切りました';

  @override
  String get settingsSecuritySecondFactorDisableButton => '2 段階目を切る';

  @override
  String get settingsSecuritySessionsHeader => 'ログイン中の端末';

  @override
  String settingsSecuritySessionsRevokedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return 'ほかの $_temp0をログアウトさせました';
  }

  @override
  String get settingsSecuritySessionsRevokeOthersButton => 'ほかを全部ログアウト';

  @override
  String get settingsSecuritySessionUnnamed => '名前のない端末';

  @override
  String get settingsSecurityThisDeviceSuffix => '(この端末)';

  @override
  String settingsSecuritySessionLastUsed(String ago) {
    return '最後に使った: $ago';
  }

  @override
  String settingsSecuritySessionExpires(String date) {
    return '期限 $date';
  }

  @override
  String get settingsSecuritySessionRevoked => 'ログアウトさせました';

  @override
  String get settingsSecuritySessionLogoutButton => 'ログアウト';

  @override
  String get settingsSecurityConfirmDeleteHeader => 'アカウントの削除の確認';

  @override
  String get settingsSecurityConfirmEmailRemoveHeader => 'メールアドレスを外す確認';

  @override
  String settingsSecurityConfirmCodeCaption(String to) {
    return '$to に届いたコードを入れてください。';
  }

  @override
  String get settingsSecurityDeleteButton => '削除する';

  @override
  String get settingsSecurityRemoveButton => '外す';

  @override
  String get settingsSecurityDeleteHeader => 'アカウントの削除';

  @override
  String get settingsSecurityDeleteTitle => 'RASQ アカウントを削除';

  @override
  String get settingsSecurityDeleteSubtitleWithEmail =>
      'メールの確認コードが要ります。元に戻せません';

  @override
  String get settingsSecurityDeleteSubtitle => '元に戻せません';

  @override
  String get settingsSecurityRolesHeader => '役割';

  @override
  String get settingsSecurityRolesTitle => 'このアカウントの役割';

  @override
  String get settingsSecurityRoleDeveloper => '開発者';

  @override
  String get settingsSecurityRoleReviewer => '審査員';

  @override
  String get settingsSecurityEmailReplaceNeedsPasswordOrCodeError =>
      'いまのパスワードを入れるか、いまのメールに届く確認コードで確かめてください';

  @override
  String get settingsSecurityEmailReplaceNeedsCodeError =>
      'いまのメールに届く確認コードで確かめてください';

  @override
  String get settingsSecurityEnterCurrentPasswordError => 'いまのパスワードを入れてください';

  @override
  String get settingsSecurityCodeSent => '確認コードを送りました';

  @override
  String get settingsSecurityDeleteConfirmMessage =>
      'サーバー上のプロフィール、アカウントバンドル、同期した設定、レビューとブックマーク、ASTell のルームと共有、通知トークン、同意の記録を削除します。元に戻せません。';

  @override
  String get settingsSecuritySendConfirmCodeButton => '確認コードを送る';

  @override
  String get settingsSecurityDeleted => 'RASQ アカウントを削除しました';

  @override
  String get settingsSecurityEmailRemoved => 'メールアドレスを外しました';

  @override
  String get settingsSecurityCodeHint => '確認コード(例 3mJr7-AoUXx)';

  @override
  String get settingsSecurityCodeHelper => 'メールのリンクを貼り付けても確認できます';

  @override
  String get settingsSecurityLoginFailedHelp =>
      'ハンドル(メール)かパスワードが違います。\nパスワードを設定していない RASQ アカウントには、ほかの端末からはログインできません。そのアカウントを作った端末(いまもログインしている端末)で「設定 → アカウントのセキュリティ」からパスワードを設定してから、もう一度ログインしてください。';

  @override
  String get settingsSecurityServerNotConfiguredError => 'RASQ サーバーの接続先が未設定です';

  @override
  String get settingsSecurityLoginFailed => 'ログインできませんでした';

  @override
  String settingsSecurityLoggedInAs(String handle) {
    return '@$handle にログインしました';
  }

  @override
  String get settingsSecurityLoginEnterCredentialsError =>
      'ハンドル(かメール)とパスワードを入れてください';

  @override
  String get settingsSecurityVerifiedEmailFallback => '確認済みのメール';

  @override
  String get settingsSecurityLoginTitle => 'RASQ アカウントにログイン';

  @override
  String get settingsSecurityLoginCaption =>
      'ハンドル(@ は無くてもよい)か確認済みのメールアドレスと、パスワードで入ります。';

  @override
  String get settingsSecurityLoginDetail =>
      'ハンドル(@ は無くてもよい)か確認済みのメールアドレスと、パスワードで入ります。確認済みのメールがあるアカウントは、そのあとメールに届く確認コードも入れます(2 段階目の確認)。';

  @override
  String get settingsSecurityLoginIdentifierHint => 'ハンドル または メールアドレス';

  @override
  String get settingsSecurityLoginPasswordHint => 'パスワード';

  @override
  String get settingsSecurityLoginButton => 'ログイン';

  @override
  String get settingsSecurityLoginForgotButton => 'パスワードを忘れた';

  @override
  String get settingsSecurityLoginNoPasswordHint =>
      'パスワードを設定していないアカウントは、ほかの端末からはログインできません(作った端末でだけ使えます)。その端末の「設定 → アカウントのセキュリティ」でパスワードを設定してください。';

  @override
  String get settingsSecurityLoginCodeHeader => '確認コード';

  @override
  String settingsSecurityLoginChallengeCaption(String email, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分有効',
    );
    return '$email に確認コードを送りました($_temp0、1 回きり)。届いたコードを入れてください。';
  }

  @override
  String get settingsSecurityVerifiedEmailAddressFallback => '確認済みのメールアドレス';

  @override
  String get settingsSecurityLoginConfirmButton => '確認してログイン';

  @override
  String get settingsSecurityLoginResendButton => 'コードを送り直す';

  @override
  String get settingsSecurityLoginBackButton => 'ハンドル / パスワードに戻る';

  @override
  String get settingsSecurityLoginNoMailHint =>
      'メールが届かないときは、迷惑メールのフォルダも見てください。ログインに心当たりが無いメールが届いたら、パスワードを変えてください。';

  @override
  String get settingsSecurityLoginChildHeader => '子のアカウント';

  @override
  String get settingsSecurityLoginChildTitle => '保護者からのコードでログイン';

  @override
  String get settingsSecurityLoginChildSubtitle => '保護者が作った子のアカウントに入ります';

  @override
  String get settingsSecurityResetEnterEmailError => '確認済みのメールアドレスを入れてください';

  @override
  String get settingsSecurityResetCodeSent =>
      'そのメールアドレスを確認済みのアカウントがあれば、確認コードを送りました(10 分有効)';

  @override
  String settingsSecurityResetDoneKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return 'パスワードを再設定しました。ほかの $_temp0の端末をログアウトしました';
  }

  @override
  String settingsSecurityResetDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 台',
    );
    return 'パスワードを再設定しました($_temp0の端末をログアウトしました)。新しいパスワードでログインしてください';
  }

  @override
  String get settingsSecurityResetTitle => 'パスワードの再設定';

  @override
  String get settingsSecurityResetCaption =>
      '確認済みのメールアドレスへ確認コード(10 分有効、1 回きり)を送り、新しいパスワードを決めます。ほかの端末はすべてログアウトになります。';

  @override
  String get settingsSecurityResetNoEmailWarning =>
      'メールアドレスを確認していないアカウントは、パスワードを再設定できません。';

  @override
  String get settingsSecurityResetNoEmailDetail =>
      'そのアカウントを作った端末(いまもログインしている端末)で「設定 → アカウントのセキュリティ」から新しいパスワードを設定してください。その端末も無いときは、アカウントに戻る方法はありません。';

  @override
  String get settingsSecurityResetEmailHint => '確認済みのメールアドレス';

  @override
  String get settingsSecurityResendButton => '送り直す';

  @override
  String settingsSecurityResetNewPasswordHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 文字以上',
    );
    return '新しいパスワード($_temp0)';
  }

  @override
  String get settingsSecurityResetConfirmPasswordHint => '新しいパスワード(確認)';

  @override
  String get settingsSecurityResetMismatchError => '一致しません';

  @override
  String get settingsSecurityResetKeepTitle => 'この端末のログインは残す';

  @override
  String get settingsSecurityResetKeepSubtitle =>
      'いまこの端末でログインしているアカウントの再設定のときだけ残ります';

  @override
  String get settingsSecurityResetSyncWarning => '再設定すると、同期した設定は読めなくなります。';

  @override
  String get settingsSecurityResetSyncWarningDetail =>
      'パスワードは、同期した設定の暗号化にも使います。前のパスワードで暗号化したデータは復号できなくなります。';

  @override
  String get settingsSecurityResetSubmitButton => 'パスワードを再設定';

  @override
  String get settingsSnsShareConflictError => 'ほかの端末が先に変えました。もう一度お試しください';

  @override
  String get settingsSnsShareOffConfirmTitle => 'SNS のログインの共有をやめますか?';

  @override
  String get settingsSnsShareOffConfirmMessage =>
      '共有のデータと、すべての端末の鍵を消します。各端末の SNS のログインはそのまま残ります。';

  @override
  String get settingsSnsShareOffConfirmDetail =>
      'RASQ Central にある共有の中身(暗号化したもの)と、すべての端末の鍵を消します。それぞれの端末の SNS のログインはそのまま残ります。';

  @override
  String get settingsSnsShareOffConfirmButton => 'やめる';

  @override
  String get settingsSnsShareCancelButton => 'キャンセル';

  @override
  String get settingsSnsShareStopped => '共有をやめました';

  @override
  String get settingsSnsShareSubtitleLoading => '読み込み中…';

  @override
  String get settingsSnsShareSubtitleUnsupported =>
      'この端末のログインは共有に対応していません。ログインし直してください';

  @override
  String get settingsSnsShareSubtitleOffAsk => 'オフ(別の端末でログインしたときに聞きます)';

  @override
  String get settingsSnsShareSubtitleOff => 'オフ';

  @override
  String get settingsSnsShareSubtitleOnHolding => 'オン ・ この端末は共有しています';

  @override
  String get settingsSnsShareSubtitleOnWaiting => 'オン ・ 共有している端末での承認を待っています';

  @override
  String get settingsSnsShareSubtitleOnNotYet => 'オン ・ この端末は、まだ共有していません';

  @override
  String get settingsSnsShareHeader => 'SNS のログインを端末間で共有';

  @override
  String get settingsSnsShareCaption =>
      '新しい端末でも、SNS に自動でログインできます。中身は暗号化され、RASQ のサーバーは読めません。';

  @override
  String get settingsSnsShareDetail =>
      'SNS のアクセストークンを、この RASQ アカウントでログインしている端末のあいだで暗号化(E2E)して共有します。新しい端末でログインすると、共有している端末で承認したあと、その端末も SNS アカウントに一斉ログインします。RASQ のサーバーは中身を読めません。';

  @override
  String get settingsSnsShareSwitchTitle => 'ほかの端末と SNS のログインを共有';

  @override
  String get settingsSnsShareRequestTitle => 'この端末にも共有してもらう';

  @override
  String get settingsSnsShareRequestSubtitle => '共有している端末に、承認の問いが出ます';

  @override
  String get settingsSnsShareRequested => '共有している端末に、承認を求めました';

  @override
  String get settingsSnsShareDevicesLabel => '端末';

  @override
  String get settingsSnsShareThisDeviceSuffix => '(この端末)';

  @override
  String get settingsSnsShareDeviceShared => '共有しています';

  @override
  String get settingsSnsShareDeviceWaiting => '承認を待っています';

  @override
  String get settingsSnsShareDeviceNotShared => '共有していません';

  @override
  String settingsSnsShareApproved(String name) {
    return '$name に共有しました';
  }

  @override
  String get settingsSnsShareApproveButton => '共有する';

  @override
  String get settingsSnsShareDeclineButton => '断る';

  @override
  String settingsSnsShareRemoved(String name) {
    return '$name を共有から外しました';
  }

  @override
  String get settingsSnsShareRemoveButton => '外す';

  @override
  String get settingsSnsShareRemovedCaption =>
      '外した端末は、それまでのログインを持ったままです。心当たりが無ければ SNS 側でもログアウトしてください。';

  @override
  String get settingsSnsShareRemovedDetail =>
      '「ログイン中の端末」でその端末をログアウトさせると、その端末の鍵も消えます。外した端末は、それまでに受け取ったアクセストークンを持っています(心当たりが無ければ、SNS 側でもログアウトしてください)。';

  @override
  String get shellColumnSplitSmallFixedLabel => '小型カラムの幅を固定';

  @override
  String get shellColumnSplitLargeFixedLabel => '大型カラムの幅を固定';

  @override
  String get shellColumnSplitEvenHint => '同じ幅';

  @override
  String get shellColumnSplitTwoThreeHint => '小型 2 : 大型 3';

  @override
  String get shellColumnSplitThreeFiveHint => '小型 3 : 大型 5';

  @override
  String get shellColumnSplitSmallFixedHint => '小型カラムを決めた幅にし、残りを大型カラムに';

  @override
  String get shellColumnSplitLargeFixedHint => '大型カラムを決めた幅にし、残りを小型カラムに';

  @override
  String get shellColumnWidthErrorEmpty => '幅を入れてください';

  @override
  String get shellColumnWidthErrorNotInteger => '数字(整数)で入れてください';

  @override
  String shellColumnWidthErrorRange(String min, String max) {
    return '$min〜$max px の間で入れてください';
  }

  @override
  String get shellColumnThirdEmptySearch => '検索';

  @override
  String get shellColumnThirdEmptyNotifications => '通知';

  @override
  String get shellColumnThirdEmptyNone => '表示しない';

  @override
  String get shellColumnThirdSettingsTooltip => '第3カラムの設定';

  @override
  String get shellColumnThirdCloseTooltip => '閉じる';

  @override
  String get shellColumnThirdEmptyTitle => '第3カラム';

  @override
  String get shellColumnThirdEmptyHint => '開いている画面をここへ移動できます';

  @override
  String get shellColumnThirdEmptyHintDetail => 'FOW をここへ移動できます(M5c)';

  @override
  String get shellNavHome => 'ホーム';

  @override
  String get shellNavSearch => '検索';

  @override
  String get shellNavNotifications => '通知';

  @override
  String get shellHeaderTimelineSwitchTooltip => 'タイムライン切り替え';

  @override
  String get shellHeaderExpandTooltip => 'ヘッダーを戻す';

  @override
  String get shellHeaderScrollToTopTooltip => '先頭へ';

  @override
  String get shellHeaderSearchHint => '検索';

  @override
  String get shellHeaderBackTooltip => '戻る';

  @override
  String get shellHeaderCloseButton => '閉じる';

  @override
  String get shellHeaderMenuTooltip => 'メニュー';

  @override
  String get shellHeaderOpenSidebarSemantics => 'サイドバーを開く';

  @override
  String get shellSidebarSemantics => 'サイドバー';

  @override
  String shellSidebarSwitchToAccountTooltip(String name) {
    return '$name に切り替える';
  }

  @override
  String get shellSidebarRasqAccountTooltip => 'RASQ アカウント';

  @override
  String get shellSidebarHideAccountsTooltip => 'アカウントリストを隠す';

  @override
  String get shellSidebarShowAccountsTooltip => 'アカウントリストを表示';

  @override
  String get shellSidebarAccountSettingsButton => 'アカウントの設定';

  @override
  String get shellSidebarBookmarks => 'ブックマーク';

  @override
  String get shellSidebarLists => 'リスト';

  @override
  String get shellSidebarPlugins => 'プラグイン';

  @override
  String get shellSidebarCustomPlugins => 'カスタムプラグイン';

  @override
  String get shellSidebarAllSettings => '全ての設定';

  @override
  String get shellSidebarHelp => 'ヘルプ';

  @override
  String get shellSidebarDevCatalog => 'コンポーネントカタログ (dev)';

  @override
  String get shellSidebarDevWasmPlugin => 'WASMプラグイン試験 (dev)';

  @override
  String get shellSidebarWebConsole => 'Webコンソール';

  @override
  String get shellSidebarAccountActionsTooltip => 'アカウントの操作';

  @override
  String get shellSidebarShowAccountMenu => 'このアカウントを表示';

  @override
  String get shellSidebarLogoutMenu => 'ログアウト';

  @override
  String get shellAccountHeaderPickTooltip => 'アカウントを選ぶ';

  @override
  String shellAccountHeaderReadingAsTooltip(String account) {
    return '$account で読んでいます';
  }

  @override
  String get shellAccountHeaderSwitchSemantics => 'アカウントを切り替える';

  @override
  String get shellAccountHeaderAvatarSemantics => 'アカウント';

  @override
  String get shellAccountPickerSemantics => 'アカウントの選択';

  @override
  String get shellAccountPickerCloseTooltip => '閉じる';

  @override
  String get shellAccountFowTitle => 'RASQ アカウント';

  @override
  String get shellAccountFowCloseButton => '閉じる';

  @override
  String get shellAccountAppealSheetTitle => '処置の解除を申請';

  @override
  String get shellAccountAppealCaption => '運営の担当者が読んで、受理なら処置が解除されます。';

  @override
  String get shellAccountAppealCaptionDetail =>
      '運営(rasq-judge)の担当者が読んで、受理なら処置が解除されます。自動判定は通りません。';

  @override
  String get shellAccountAppealReasonHint => '申請の理由(必須)';

  @override
  String shellAccountAppealFailedError(String error) {
    return '申請できませんでした: $error';
  }

  @override
  String get shellAccountAppealSubmitButton => '申請する';

  @override
  String get shellAccountAppealSentSnack => '解除を申請しました。担当者が確認します';

  @override
  String get shellAccountLocalDisplayName => 'この端末';

  @override
  String get shellAccountMenuAddSns => 'SNS アカウントを追加';

  @override
  String get shellAccountMenuAllSettings => '設定';

  @override
  String get shellAccountMenuAccountPage => 'アカウントページ';

  @override
  String get shellAccountMenuEditProfile => 'プロフィール編集';

  @override
  String get shellAccountMenuAccountSettings => 'アカウント設定';

  @override
  String get shellAccountMenuNotificationSettings => '通知設定';

  @override
  String get shellAccountMenuSecurity => 'セキュリティ(メール / パスワード / 端末)';

  @override
  String get shellAccountMenuLogout => 'ログアウト';

  @override
  String get shellAccountMenuDelete => 'RASQ アカウントを削除';

  @override
  String get shellAccountLogoutTitle => 'RASQ アカウントからログアウト';

  @override
  String get shellAccountLogoutMessage => 'この端末から RASQ アカウントを外します。';

  @override
  String get shellAccountLogoutConfirmButton => 'ログアウト';

  @override
  String get shellAccountLoggedOutWithSnsSnack =>
      'RASQ アカウントと、その SNS アカウントからログアウトしました';

  @override
  String get shellAccountLoggedOutKeptSnsSnack =>
      'RASQ アカウントからログアウトしました。SNS アカウントは「この端末のみ」に移しました';

  @override
  String get shellAccountDeleteReloginRequiredError =>
      'このアカウントに、もう一度ログインしてから削除してください';

  @override
  String get shellAccountDeleteNeedsEmailCodeSnack =>
      '削除には、メールの確認コードが要ります。「アカウントの削除」から進めてください';

  @override
  String get shellAccountDeleteTitle => 'RASQ アカウントを削除';

  @override
  String get shellAccountDeleteMessage =>
      'サーバー上のプロフィール、アカウントバンドル、同期した設定、レビューとブックマーク、ASTell のルームと共有、通知トークン、同意の記録を削除します。「アルゴリズムとコミュニティへの貢献」に同意していた場合は、提供の停止と提供済みデータの削除も同時に始まります。\n元に戻せません。各 SNS 上のアカウントと投稿は消えません。';

  @override
  String get shellAccountDeleteConfirmButton => '削除する';

  @override
  String get shellAccountDeletedSnack => 'RASQ アカウントを削除しました';

  @override
  String shellAccountDeleteFailedError(String error) {
    return '削除できませんでした: $error';
  }

  @override
  String shellAccountCreatedSnack(String handle) {
    return 'RASQ アカウント @$handle を作成しました';
  }

  @override
  String shellAccountSanctionActive(String level) {
    return 'このアカウントには処置が掛かっています: $level';
  }

  @override
  String shellAccountSanctionRestrictedFeatures(String features) {
    return '止まっている機能: $features';
  }

  @override
  String shellAccountSanctionReviewDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '発言ごとに $seconds 秒の検閲遅延が入ります',
    );
    return '$_temp0';
  }

  @override
  String shellAccountSanctionStaffNote(String note) {
    return '運営より: $note';
  }

  @override
  String get shellAccountSanctionNoExpiry => '期限: なし';

  @override
  String shellAccountSanctionExpiry(String expiresAt) {
    return '期限: $expiresAt';
  }

  @override
  String shellAccountSanctionAppealButton(String category, String level) {
    return '解除を申請($category / $level)';
  }

  @override
  String shellAccountSanctionAppealPending(String category) {
    return '申請中($category)';
  }

  @override
  String get shellAccountEmpty => 'RASQ アカウントはまだありません。';

  @override
  String shellAccountRowSubtitle(String kind, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件',
    );
    return '$kind ・ SNS $_temp0';
  }

  @override
  String get shellAccountRowInUseSuffix => ' ・ 使用中';

  @override
  String get shellAccountRowNeedsLoginSuffix => ' ・ ログインが必要';

  @override
  String get shellAccountCollapseActionsTooltip => '操作を畳む';

  @override
  String get shellAccountActionsTooltip => 'アカウントの操作';

  @override
  String shellAccountReloginSnack(String handle) {
    return '@$handle に、もう一度ログインしてください';
  }

  @override
  String get shellAccountChildSafeButton => 'チャイルドセーフ';

  @override
  String get shellAccountCreateButton => 'アカウントを新規作成';

  @override
  String get shellAccountLoginButton => 'ログイン';

  @override
  String get shellAccountServerNotConfigured => 'RASQ サーバーの接続先が未設定です';

  @override
  String get shellAccountConfigureServerButton => '接続先を設定';

  @override
  String get shellAccountProfileSheetTitle => 'プロフィール編集';

  @override
  String get shellAccountProfileSaveButton => '保存';

  @override
  String get shellAccountProfileDisplayNameLabel => '表示名';

  @override
  String get shellAccountProfileDisplayNameHint => '表示名';

  @override
  String get shellAccountProfileHandleLabel => 'ハンドル(@なし、a-z 0-9 _)';

  @override
  String get shellAccountProfileCentralCaption => 'RASQ のサーバー上のプロフィールを更新します。';

  @override
  String get shellAccountProfileLocalCaption =>
      'この端末だけのアカウントです。ハンドルは RASQ アカウントを作成すると付きます。';

  @override
  String get shellAccountProfileSavedSnack => 'プロフィールを保存しました';

  @override
  String shellAccountProfileSaveFailedError(String error) {
    return '保存できませんでした: $error';
  }

  @override
  String get shellAccountTileMenuTooltip => 'RASQ アカウント';

  @override
  String get shellTermsSheetTitle => '利用規約への同意';

  @override
  String get shellTermsAgreeButton => '同意する';

  @override
  String get shellTermsNotice =>
      'RASQ アカウントを使い続けるには、いまの利用規約とプライバシーポリシーへの同意が必要です。同意するまで、ASTell・購入・データの預け入れは使えません。';

  @override
  String shellTermsNoticeDetail(String endpoints) {
    return 'D-371 / S-053。サーバーの CENTRAL_TERMS_VERSION / CENTRAL_PRIVACY_VERSION と同じ版の承諾がそろうまで「同意待ち」。PUT /me/consents/$endpoints。';
  }

  @override
  String get shellTermsReadTermsButton => '利用規約を読む';

  @override
  String get shellTermsReadPrivacyButton => 'プライバシーポリシーを読む';

  @override
  String get shellTermsAgeHeader => '年齢';

  @override
  String get shellTermsGuardianConsentCheck => '保護者の同意を得ています';

  @override
  String get shellTermsAgreeCheck => '利用規約とプライバシーポリシーを読み、同意します';

  @override
  String shellTermsVersionCaption(String termsVersion, String privacyVersion) {
    return '版: 利用規約 $termsVersion ・ プライバシーポリシー $privacyVersion';
  }

  @override
  String get shellTermsAcceptedSnack => '利用規約に同意しました';

  @override
  String get shellTermsOutdatedError => '利用規約が新しくなっています。アプリを更新してから同意してください';

  @override
  String shellTermsRecordFailedError(String error) {
    return '同意を記録できませんでした: $error';
  }

  @override
  String get shellTermsBannerText => '利用規約への同意が必要です。同意するまで ASTell・購入などは使えません。';

  @override
  String get shellTermsBannerOpenButton => '確認する';

  @override
  String get storeStatusInReview => '審査中';

  @override
  String get storeStatusPublished => '公開中';

  @override
  String get storeStatusUpdateAvailable => '更新あり';

  @override
  String get storeStatusWarning => '警告';

  @override
  String get storeStatusSuspended => '停止';

  @override
  String get storeStatusWithdrawn => '取り下げ';

  @override
  String get storeStatusUnlisted => '非公開';

  @override
  String get storeStatusBeta => 'ベータ';

  @override
  String get storeStatusRevoked => '失効';

  @override
  String get storeOriginOfficial => '公式';

  @override
  String get storeOriginVerified => '検証済み';

  @override
  String get storeOriginCommunity => 'コミュニティ';

  @override
  String get storeTypeComposer => '投稿作成';

  @override
  String get storeTypePost => '投稿';

  @override
  String get storeTypeViewer => '全画面表示';

  @override
  String get storeTypeTimeline => 'タイムライン';

  @override
  String get storeTypeTrend => 'トレンド';

  @override
  String get storeTypeTheme => '着せ替え';

  @override
  String get storeTypeAssets => 'ステッカー / 素材';

  @override
  String get storeTypeCustom => 'カスタム';

  @override
  String get storeTypeOther => 'その他';

  @override
  String get storeFilterFree => '無料';

  @override
  String get storeFilterNoAds => '広告なし';

  @override
  String get storeFilterOfficial => '公式';

  @override
  String get storeFilterVerified => '認証済み';

  @override
  String get storeFilterRecent => '30 日以内';

  @override
  String get storeFilterLightweight => '軽量(5MB 未満)';

  @override
  String get storeFilterOffline => 'オフライン';

  @override
  String get storePermNetwork => 'ネットワーク';

  @override
  String get storePermNetworkDescription => '外部への通信';

  @override
  String get storePermStorage => 'ストレージ';

  @override
  String get storePermStorageDescription => '端末内の保存領域';

  @override
  String get storePermFiles => 'ファイル';

  @override
  String get storePermFilesDescription => 'ユーザーが選んだファイルの読み書き';

  @override
  String get storePermSns => '投稿とアカウント';

  @override
  String get storePermSnsDescription => 'SNS アカウントを使った操作';

  @override
  String get storePermDm => 'ダイレクトメッセージ';

  @override
  String get storePermDmDescription => 'DM の読み書き';

  @override
  String get storePermGpuMl => 'GPU / 機械学習';

  @override
  String get storePermGpuMlDescription => 'GPU 実行・モデル推論';

  @override
  String get storePermClipboard => 'クリップボード';

  @override
  String get storePermClipboardDescription => 'コピー内容の読み書き';

  @override
  String get storePermBackground => 'バックグラウンド実行';

  @override
  String get storePermBackgroundDescription => '画面を閉じても動作';

  @override
  String get storePermUi => '画面と配置';

  @override
  String get storePermUiDescription => '画面の表示とボタンの配置';

  @override
  String get storePermOther => 'その他';

  @override
  String get storeReviewSortHelpful => '関連性';

  @override
  String get storeReviewSortRecent => '最新';

  @override
  String get storeReviewSortRatingHigh => '評価が高い';

  @override
  String get storeReviewSortRatingLow => '評価が低い';

  @override
  String storeScopePermission(String permission) {
    return '権限 $permission';
  }

  @override
  String storeScopeHost(String host) {
    return '接続先 $host';
  }

  @override
  String get storeScopeInstance => '接続先 ログイン先のインスタンス';

  @override
  String storeScopeSlot(String slot) {
    return '使う場所 $slot';
  }

  @override
  String storeScopeReason(String permission, String reason) {
    return '用途 $permission — $reason';
  }

  @override
  String storeScopeDataHandling(String text) {
    return 'データの扱い — $text';
  }

  @override
  String storeNeedsOrgate(String feature) {
    return '$featureは ORGATE-Server につなぐと使えます(接続先が設定されていません)';
  }

  @override
  String get storeFeaturePurchase => '購入';

  @override
  String get storeFeaturePoints => 'ポイント';

  @override
  String get storeFeatureReview => 'レビュー';

  @override
  String storeSessionPluginMismatch(String actual, String expected) {
    return '構成のプラグイン ($actual) が頼んだもの ($expected) と違います';
  }

  @override
  String storeSessionVersionMismatch(String actual, String expected) {
    return '構成の版 ($actual) が頼んだ版 ($expected) と違います';
  }

  @override
  String get storeNoBundle => '配布物がありません';

  @override
  String get storeListSeparator => '、';

  @override
  String get storeDotSeparator => ' ・ ';

  @override
  String get storeVerifyHashOnly => 'SHA-512 照合 OK(署名なし)';

  @override
  String get storeVerifyFull => 'SHA-512 + ed25519 署名 検証 OK';

  @override
  String get storeVerifyHashMismatch =>
      '整合性検証に失敗しました(SHA-512 不一致)。時間をおいて再取得してください';

  @override
  String get storeVerifyKeyMismatch => 'ストアの署名鍵がアプリに焼き込んだ鍵と一致しません。接続先を確認してください';

  @override
  String get storeVerifyUnsigned => '配布物に署名がありません(このビルドは署名済みストアのみを許可します)';

  @override
  String get storeVerifyBadSignature => '配布物の署名が正しくありません。インストールを中止しました';

  @override
  String storeVerifyError(String error) {
    return '署名を検証できませんでした: $error';
  }

  @override
  String get storeWidenedNoRecord => '最後に許可した内容の記録がないため(プラグインを管理から確かめて入れてください)';

  @override
  String storeWidenedOver(String items) {
    return '最後に許可した内容より広がるため($items)';
  }

  @override
  String get storeManifestUnavailable => '構成(マニフェスト)を取得できませんでした';

  @override
  String storeManifestVersionNotFound(String version) {
    return 'Ver.$version の構成が見つかりませんでした';
  }

  @override
  String storeConsentChanged(String version) {
    return '確認した内容(Ver.$version)と、ストアの構成が変わりました。もう一度確かめてください';
  }

  @override
  String storePackageInvalid(String error) {
    return '配布物の中身を検証できませんでした: $error';
  }

  @override
  String storePackageMismatch(String actual, String expected) {
    return '配布物の中身($actual)がストアの掲載($expected)と違います';
  }

  @override
  String storePackageRequires(String plugins) {
    return 'このプラグインには $plugins が必要です(未対応のため入れられません)';
  }

  @override
  String storeThemeSaveFailed(String error) {
    return '着せ替えを保存できませんでした: $error';
  }

  @override
  String storeAssetsSaveFailed(String error) {
    return 'アセットパックを保存できませんでした: $error';
  }

  @override
  String get storeSlotRegisterFailed => 'スロットに登録できませんでした';

  @override
  String storeVersionBundleChanged(String version) {
    return 'Ver.$version の配布物がインストール時と違うため読み込みません(入れ直してください)';
  }

  @override
  String storeVersionLoadFailed(String version, String error) {
    return 'Ver.$version を読み込めませんでした: $error';
  }

  @override
  String get storeVersionNoScopeRecord => 'この版で許す内容の記録がありません(入れ直すと確かめられます)';

  @override
  String storeVersionNotInstalled(String version) {
    return 'Ver.$version は入っていません';
  }

  @override
  String get storeNotInstalled => 'インストールされていません';

  @override
  String storeVersionInUse(String version) {
    return 'Ver.$version は使われています(既定 / アカウントの指定を外してから)';
  }

  @override
  String get storeManageTitle => 'プラグインを管理';

  @override
  String get storeManageUpdatesHeader => 'アップデート';

  @override
  String get storeManageUpdateSettingsTitle => 'アップデートの設定';

  @override
  String get storeManageUpdateSettingsSubtitle => '自動で更新するかどうか ・ 更新ログ';

  @override
  String get storeManageUpdateSettingsDetail =>
      'SNS / アクション / ビューごとに、おまかせ・インストールだけ・手動 ・ 更新ログ';

  @override
  String get storeManagePointsTitle => 'ポイント';

  @override
  String get storeManagePointsDisabled => '公開テストでは使えません';

  @override
  String storeManagePointsBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ポイント $count',
    );
    return '$_temp0';
  }

  @override
  String get storeManagePointsSignIn => 'RASQ アカウントにログインすると使えます';

  @override
  String get storeManagePointsBuyInConsole => 'Web コンソールで買えます(付与から 1 か月で失効)';

  @override
  String storeManagePointsExpiring(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$month/$day に $count ポイントが失効 ・ Web コンソールで買う',
    );
    return '$_temp0';
  }

  @override
  String get storeNoInstalledPlugins => 'インストール済みのプラグインはありません';

  @override
  String get storeManageImportTitle => 'プラグインのインポート';

  @override
  String get storeManageImportSubtitle => '開発中のプラグインを入れる(審査前)';

  @override
  String get storeManageImportDetail => '開発中の wasm / .rasqpkg を入れる(審査を通っていません)';

  @override
  String get storeManageHomeHeader => 'ホームの表示';

  @override
  String get storeManageShowInstalledTitle => 'インストール済みもホームに出す';

  @override
  String get storeManageShowInstalledSubtitle =>
      '今週のトレンド / 新着の列に、入れたプラグインも並べます';

  @override
  String get storeBookmarksTitle => 'ブックマーク';

  @override
  String storeManageSwitchTo(String version) {
    return '$version に切り替え';
  }

  @override
  String storeVersionMadeDefault(String version) {
    return '$version を既定の版にしました';
  }

  @override
  String storeManageUpdateTo(String version) {
    return '$version に更新';
  }

  @override
  String get storeManageOffline => 'ストアに接続できません';

  @override
  String get storeManageUpToDate => '最新です';

  @override
  String get storeManageDeployedVersion => 'デプロイしたバージョン';

  @override
  String get storeAccountVersionsTitle => 'アカウントごとにバージョンを設定';

  @override
  String storeManageAccountVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'アカウントごと($count 件指定)',
    );
    return '$_temp0';
  }

  @override
  String get storePluginNotFound => 'このプラグインは見つかりませんでした';

  @override
  String storeInstallFailed(String error) {
    return 'インストールできませんでした: $error';
  }

  @override
  String get storeHasAds => '広告あり';

  @override
  String get storeBuyDisabled => '公開テストでは購入できません';

  @override
  String get storeTileGet => '入手';

  @override
  String get storeTileUpdate => '更新';

  @override
  String get storeOpen => '開く';

  @override
  String get storeTileUnavailable => '停止中';

  @override
  String storeDownloadsTenThousands(String value) {
    return '$value万';
  }

  @override
  String storeNotAssetPack(String id) {
    return 'アセットパックではありません: $id';
  }

  @override
  String get storeUpdatesNoneApplied => '自動で入れる更新はありませんでした';

  @override
  String get storeUpdateSettingsTitle => 'アップデート/デプロイの設定';

  @override
  String get storeUpdateSettingsModeHeader => 'アップデート/デプロイ';

  @override
  String get storeUpdateSettingsPopup => 'アップデート後の起動時にポップアップを表示';

  @override
  String get storeUpdateLogTitle => '更新ログ';

  @override
  String get storeUpdateSettingsCheckNow => 'いま確かめる';

  @override
  String get storeUpdateSettingsCaption => '許可した内容が広がる版と有料の版は、自動では入りません';

  @override
  String get storeUpdateSettingsCaptionDetail =>
      '最後に許可した内容より権限・接続先・使う場所・用途が広がる版(確かめられない版も)と、買っていない有料の版は、どのモードでも自動では使い始めません(更新ログに理由が残ります)。起動するたびに 1 回確かめます。';

  @override
  String get storeUpdateLogEmpty => 'まだありません';

  @override
  String get storeUpdateLogEmptyHint => 'アップデートすると、ここに残ります';

  @override
  String get storeInstalledTitle => 'インストール済み';

  @override
  String get storeInstalledEmptyHint => 'ストアから追加できます';

  @override
  String storeInstalledItemSubtitle(String version, String id) {
    return 'v$version ・ $id';
  }

  @override
  String get storeUnknown => '不明';

  @override
  String get storeInstalledMissingHint => '削除済みか、別の端末で入れたものです';

  @override
  String get storeInstalledSourceSnapshot => 'インストールしたときの掲載の写しです。';

  @override
  String get storeInstalledSourceManifest => 'プラグイン自身の宣言(権限の id だけ)です。';

  @override
  String get storeInstalledRemoveTitle => '削除しますか？';

  @override
  String storeInstalledRemoveMessage(String name) {
    return '$name を端末から削除します。';
  }

  @override
  String get storeRemove => '削除';

  @override
  String get storeCancel => 'キャンセル';

  @override
  String get storeInstalledOffline => 'ストアに接続できないので、手元の情報を出しています。';

  @override
  String get storeInstalledUnlisted =>
      'ストアの掲載は見つかりません(取り下げられた可能性があります)。このまま使い続けることも、削除することもできます。';

  @override
  String get storeInstalledVersionHeader => 'インストール済みのバージョン';

  @override
  String storeInstalledAt(String date) {
    return 'インストール: $date';
  }

  @override
  String storeInstalledAtVerified(String date, String sha512) {
    return 'インストール: $date ・ 検証済み SHA-512 $sha512';
  }

  @override
  String storeInstalledNewerTitle(String version) {
    return 'ストアには v$version があります';
  }

  @override
  String get storeInstalledNewerSubtitle => 'ストアのページから入れ直せます';

  @override
  String storeInstalledSlots(String slots) {
    return '動いている場所: $slots';
  }

  @override
  String get storeInstalledOpenStore => 'ストアのページを開く';

  @override
  String get storePrivacyHeader => 'プライバシーと必要な権限';

  @override
  String get storeVersionsInstalledHeader => '入っている版';

  @override
  String get storeVersionsDefault => '既定の版';

  @override
  String storeVersionsUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count アカウントが使用中',
    );
    return '$_temp0';
  }

  @override
  String storeVersionsInstalledOn(int year, int month, int day) {
    return '入れた日 $year/$month/$day';
  }

  @override
  String get storeMenu => 'メニュー';

  @override
  String get storeVersionsMakeDefault => '既定の版にする';

  @override
  String get storeVersionsRemove => 'この版を消す';

  @override
  String storeVersionsRemoved(String version) {
    return '$version を消しました';
  }

  @override
  String get storeVersionsOthersHeader => 'ほかの版を入れる';

  @override
  String get storeVersionsMorePermissions => '権限が増えます';

  @override
  String get storeVersionsInstall => '入れる';

  @override
  String get storeVersionsPerAccountHeader => 'アカウントごと';

  @override
  String get storeVersionsPerAccountCaption => 'アカウントごとに、使う版を選べます';

  @override
  String get storeVersionsPerAccountDetail =>
      'そのアカウントを使っている間、スロットプラグインとノードの並べ替えは、ここで選んだ版で動きます。';

  @override
  String storeVersionsFollowDefault(String version) {
    return '既定に従う($version)';
  }

  @override
  String storeVersionsAccountFollows(String account) {
    return '$account は既定の版に従います';
  }

  @override
  String storeVersionsAccountUses(String account, String version) {
    return '$account は $version を使います';
  }

  @override
  String storeVersionsDefaultShort(String version) {
    return '既定($version)';
  }

  @override
  String get storeVersionsPackNote => '着せ替え / ステッカー・素材は端末全体で 1 つの版を使います(既定の版)。';

  @override
  String get storeUpdateModeAuto => 'おまかせ';

  @override
  String get storeUpdateModeAutoDescription =>
      '新しい版を入れて、既定の版にします(アカウントごとに指定した版はそのまま)';

  @override
  String get storeUpdateModeInstallOnly => 'インストールだけおまかせ';

  @override
  String get storeUpdateModeInstallOnlyDescription => '新しい版を入れておくだけで、使う版は変えません';

  @override
  String get storeUpdateModeManual => '全て手動で構成';

  @override
  String get storeUpdateModeManualDescription => '自動では何もしません(プラグインを管理から入れます)';

  @override
  String get storeUpdateGroupSns => 'SNSプラグイン';

  @override
  String get storeUpdateGroupAction => 'アクションプラグイン';

  @override
  String get storeUpdateGroupView => 'ビュープラグイン';

  @override
  String storeUpdateLogActivated(String from, String to) {
    return '$from → $to(既定の版にしました)';
  }

  @override
  String storeUpdateLogInstalled(String from, String to) {
    return '$to を入れました(使う版は $from のまま)';
  }

  @override
  String storeUpdateLogSwitched(String from, String to) {
    return '$from → $to(入っていた版を既定に)';
  }

  @override
  String storeUpdateLogSkipped(String to) {
    return '$to は自動では入れません';
  }

  @override
  String storeUpdateLogSkippedNote(String to, String note) {
    return '$to は自動では入れません($note)';
  }

  @override
  String storeUpdateLogFailed(String to) {
    return '$to を入れられませんでした';
  }

  @override
  String storeUpdateLogFailedNote(String to, String note) {
    return '$to を入れられませんでした($note)';
  }

  @override
  String get storeUpdatePopupTitle => 'プラグインをアップデートしました';

  @override
  String get storeClose => '閉じる';

  @override
  String get storeReviewsTitle => 'レビュー';

  @override
  String get storeReviewsLoadFailed => 'レビューを取得できませんでした';

  @override
  String get storeReviewWrite => 'レビューを書く';

  @override
  String get storeReviewsEmpty => 'まだレビューがありません';

  @override
  String get storeReviewsEmptyHint => '右下の + から最初のレビューを書けます';

  @override
  String get storeCopyLink => 'リンクをコピー';

  @override
  String get storeReviewReport => 'レビューを報告';

  @override
  String get storeReviewLinkCopied => 'レビューのリンクをコピーしました';

  @override
  String get storeReviewReportUnavailable => 'レビューの報告は準備中です';

  @override
  String storeReloadFailed(String error) {
    return '読み直せませんでした: $error';
  }

  @override
  String get storeNoNewPlugins => '新しく公開されたプラグインはありません';

  @override
  String storeNewPluginsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '新しく公開されたプラグインを $count 件追加しました',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchTitle => 'プラグインを検索';

  @override
  String get storeSearchRecentPick => '最近の投稿内容から選出';

  @override
  String get storeSearchFailed => '検索できませんでした';

  @override
  String get storeSearchNoRecentPosts => '最近の投稿が見つかりませんでした';

  @override
  String get storeSearchNoRecentPostsHint =>
      'SNS アカウントで投稿すると、その内容に近いプラグインを選びます';

  @override
  String storeSearchRecentCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最近の投稿 $count 件の内容に近い順(端末の中で選んでいます)',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchNoRecentMatches => '最近の投稿に近いプラグインは見つかりませんでした';

  @override
  String get storeSearchNoResults => '見つかりませんでした';

  @override
  String get storeSearchNoResultsHint => 'ワードや絞り込みを変えてみてください';

  @override
  String get storeHomeTitle => 'プラグインストア';

  @override
  String get storeConnectFailed => 'ストアに接続できませんでした';

  @override
  String get storeHomeOffline => 'RASQ サーバーにつながっていません。アプリに入っているプラグインだけを表示しています';

  @override
  String get storeHomeOfflineDetail =>
      'Central 未接続: 同梱の実物(Misskey コネクタとスロットのサンプル)だけ。評価 / ダウンロード数 / レビュー / 購入はサーバーにつなぐと出ます。';

  @override
  String get storeHomeTrending => '今週のトレンド';

  @override
  String get storeHomeRecent => '新着';

  @override
  String get storeHomeReviewedOnly => '掲載されるのは審査済みのプラグインだけです';

  @override
  String get storeHomeReviewedOnlyDetail =>
      '開発中のプラグインは、開発者モードで右上の歯車 → プラグインを管理 →「プラグインのインポート」から入れられます。';

  @override
  String get storeRowEmpty => 'いまは表示できるプラグインがありません';

  @override
  String get storeInstallManifestUnavailable => '構成を取得できませんでした';

  @override
  String storeInstallSheetTitle(String name, String version) {
    return '$name $version をインストール';
  }

  @override
  String get storeInstallPermissionsHeader => 'このプラグインが使う権限';

  @override
  String get storeInstallHostsHeader => '接続先';

  @override
  String get storeInstallLoginInstance => 'ログイン先のインスタンス';

  @override
  String get storeInstallScopeNoRecord => '許可する内容(前に入れたときの記録がありません)';

  @override
  String get storeInstallScopeWidened => '最後に許可した内容から広がるもの';

  @override
  String get storeInstallPermissionsAdded => '前のバージョンから増えた権限';

  @override
  String storeInstallBundleSummary(String size, String signature) {
    return '${size}MB ・ $signature';
  }

  @override
  String get storeInstallSignedShort => 'ストアの署名あり';

  @override
  String get storeInstallUnsignedShort => 'ストアの署名なし';

  @override
  String storeInstallBundleDetail(
    String size,
    String sha512,
    String signature,
  ) {
    return '配布物: ${size}MB ・ SHA-512 $sha512… ・ $signature';
  }

  @override
  String get storeInstallSignedDetail => 'ストア署名つき (ed25519)';

  @override
  String get storeInstallUnsignedDetail => 'ストア署名なし(ハッシュ照合のみ)';

  @override
  String get storeInstallConfirm => 'インストールする';

  @override
  String storeInstallThemeDarkOnly(String name) {
    return '$name を使います。暗いモードのときに効きます';
  }

  @override
  String storeInstallThemeLightOnly(String name) {
    return '$name を使います。明るいモードのときに効きます';
  }

  @override
  String storeInstallThemeApplied(String name) {
    return '$name を使います';
  }

  @override
  String storeInstallDone(String name, String version) {
    return '$name $version をインストールしました';
  }

  @override
  String storeVersionScopeTitle(String version) {
    return 'Ver.$version は許可する内容が広がります';
  }

  @override
  String get storeVersionScopeConfirm => '許可して使う';

  @override
  String get storeVersionScopeCancel => 'やめる';

  @override
  String storePurchasePointsFailed(String error) {
    return 'ポイントを確かめられませんでした(RASQ アカウントにログインしていますか?): $error';
  }

  @override
  String storePurchaseTitle(String name) {
    return '$name を購入';
  }

  @override
  String storePurchasePrice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ポイント',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '残り $count ポイント',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalanceExpiring(int count, String date, int expiring) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '残り $count ポイント ・ $date に $expiring ポイントが失効',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseCaption => '買ったプラグインは、同じアカウントならどの端末でも使えます';

  @override
  String get storePurchaseCaptionDetail =>
      '買ったプラグインは、同じ RASQ アカウントならどの端末でも入れられます。ポイントは有効期限の近いものから使います。';

  @override
  String storePurchaseBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ポイントで購入する',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ポイントが足りません(あと $count ポイント)',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseConsole => 'Web コンソールでポイントを買う';

  @override
  String get storePurchaseFailed => '購入できませんでした';

  @override
  String storeReleaseNotesSemantics(String version) {
    return 'リリースノート $version';
  }

  @override
  String get storeReleaseBeta => 'プレビュー版 (β)';

  @override
  String get storeReleaseStable => '安定版';

  @override
  String storeReleasePublishedOn(int year, int month, int day) {
    return '$year/$month/$day 公開';
  }

  @override
  String get storeReleaseCurrentListing => '現在の掲載版';

  @override
  String get storeReleaseInstalled => 'インストール中';

  @override
  String get storeReleaseNoNotes => 'この版のリリースノートはありません。';

  @override
  String get storeReleasePermissionsAdded => 'この版で増えた権限';

  @override
  String get storeReleasePermissionsNote =>
      '権限が増える更新は自動アップデートの対象外です。内容を確認してから入れてください。';

  @override
  String storeReleaseAlreadyInstalled(String version) {
    return 'Ver.$version はインストール済み';
  }

  @override
  String storeReleaseBlocked(String status) {
    return '$statusのためインストールできません';
  }

  @override
  String storeReleaseInstall(String version) {
    return 'Ver.$version をインストール';
  }

  @override
  String storeReleaseReplaces(String version) {
    return '現在 v$version が入っています。この版に置き換わります。';
  }

  @override
  String get storeReviewNoVotes => 'まだ評価がありません';

  @override
  String storeReviewHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人が役に立ったと考えました。',
    );
    return '$_temp0';
  }

  @override
  String get storeShare => '共有';

  @override
  String get storeReviewHelpful => '参考になった';

  @override
  String get storeReviewNotHelpful => '参考にならなかった';

  @override
  String get storeReviewAnonymous => '匿名';

  @override
  String get storeReviewVerifiedUse => '実利用済み';

  @override
  String storeReviewDeveloperReply(String reply) {
    return '開発者の返信: $reply';
  }

  @override
  String get storeReviewNoBody => '(本文なし)';

  @override
  String get storeReviewComposeTitle => 'レビューの作成';

  @override
  String get storeReviewSend => '送信';

  @override
  String get storeRatingLabel => '評価';

  @override
  String get storeReviewTitleHint => '見出し(任意)';

  @override
  String get storeReviewBodyHint => '使用感や気になった点を入力してください';

  @override
  String storeReviewUsedVersion(String version) {
    return '利用バージョン: v$version';
  }

  @override
  String get storeReviewPickRating => '★ を選んでください';

  @override
  String get storeReviewSent => 'レビューを送信しました';

  @override
  String storeReviewSendFailed(String error) {
    return 'レビューを送信できませんでした: $error';
  }

  @override
  String get storeSafetyNoPermissions => '必要な権限: なし';

  @override
  String get storeSafetyExternalHeader => '外部通信とデータ';

  @override
  String get storeSafetyNoHosts => '外部通信先: なし';

  @override
  String storeSafetyHosts(String hosts) {
    return '外部通信先: $hosts';
  }

  @override
  String storeSafetyDataHandling(String text) {
    return 'データの扱い: $text';
  }

  @override
  String storeSafetySdks(String sdks) {
    return '外部 SDK: $sdks';
  }

  @override
  String get storeSafetyRuntimeHeader => '実行環境';

  @override
  String storeSafetyCrashFree(String rate) {
    return '正常起動率 $rate%';
  }

  @override
  String get storeSafetyBackground => 'バックグラウンド実行あり';

  @override
  String get storeSafetyNoBackground => 'バックグラウンド実行なし';

  @override
  String get storeSafetyGpu => 'GPU 使用';

  @override
  String get storeSafetyNoGpu => 'GPU 不使用';

  @override
  String get storeSafetyNoAds => '広告なし';

  @override
  String storeSafetyAds(String placements) {
    return '広告あり($placements)';
  }

  @override
  String get storePageMenuPostReview => 'レビューを投稿';

  @override
  String get storePageMenuReport => 'プラグインを報告';

  @override
  String get storePageLinkCopied => 'ストアページのリンクをコピーしました';

  @override
  String get storePageTitle => 'プラグイン';

  @override
  String get storePageMaybeWithdrawn => '取り下げられた可能性があります';

  @override
  String get storePageOpenInstalled => 'インストール済みの情報を見る';

  @override
  String get storePageRequiresPrefix => 'このプラグインを利用するには ';

  @override
  String get storePageRequiresSuffix => ' のインストールが必要です。';

  @override
  String storePageInstalledVersion(String version) {
    return 'インストール済み v$version';
  }

  @override
  String storePageInstalledVersionVerified(String version) {
    return 'インストール済み v$version(SHA-512 検証済み)';
  }

  @override
  String get storeFree => '無料';

  @override
  String storePriceYen(String amount) {
    return '¥$amount';
  }

  @override
  String get storePageInstall => 'インストール';

  @override
  String storePageBuy(String amount) {
    return '¥$amount で購入';
  }

  @override
  String get storePageThemeInUse => '使用中';

  @override
  String get storePageThemeUse => '使う';

  @override
  String get storePageUnknownDeveloper => '提供元不明';

  @override
  String storePageRatingDownloads(String rating, String downloads) {
    return '★$rating ・ $downloads DL';
  }

  @override
  String storePageStatus(String status) {
    return '状態: $status';
  }

  @override
  String get storePagePreview => 'プレビュー';

  @override
  String get storePageDownloadsLastMonth => '先月のダウンロード数';

  @override
  String storePageReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件',
    );
    return '$_temp0';
  }

  @override
  String get storePageReviewsEmptyBody => '最初のレビューを書いてみませんか。';

  @override
  String get storePageUpdatesHeader => 'アップデートとバージョン';

  @override
  String get storePageNoReleaseNotes => 'リリースノートはまだありません。';

  @override
  String get storeInUse => '利用中';

  @override
  String storePermissionsAddedList(String permissions) {
    return '権限の追加: $permissions';
  }

  @override
  String get storePagePermissionsHeader => '権限';

  @override
  String get storePageNoPermissions => 'このプラグインは追加の権限を要求しません。';

  @override
  String get storePageCompatibilityHeader => '互換性';

  @override
  String storePageRuntimes(String runtimes) {
    return 'ランタイム: $runtimes';
  }

  @override
  String storePageRequiredPlugins(String plugins) {
    return '必要プラグイン: $plugins';
  }

  @override
  String storePageConflicts(String plugins) {
    return '競合: $plugins';
  }

  @override
  String storePageRasqFeatures(String features) {
    return '利用する RASQ 機能: $features';
  }

  @override
  String get storePageVersionsTitle => 'バージョン';

  @override
  String storePageNoPreview(String name) {
    return '$name のプレビュー画像はまだありません';
  }

  @override
  String get storePageBookmarkRemove => 'ブックマークを外す';

  @override
  String get storePageBookmarkAdd => 'ブックマークする';

  @override
  String storePageBookmarkFailed(String error) {
    return 'ブックマークを更新できませんでした: $error';
  }

  @override
  String storeNeedsServer(String feature) {
    return '$featureは RASQ サーバーにつなぐと使えます';
  }

  @override
  String get storeNoListing => '掲載がありません';

  @override
  String get storeCatalogMisskeyName => 'Misskey コネクタ';

  @override
  String get storeCatalogMisskeySummary =>
      'Misskey を RASQ に繋ぐ SNS プラグイン(wasm サンプル)。TL 取得/投稿/リアクション/絵文字/投稿加工まで一式。';

  @override
  String get storeCatalogMisskeyDescription =>
      'rasq-sdk-sample の Rust 製 wasm プラグインです。sns.login / sns.timeline / post.transform / tl.sort などの契約(PROTOCOL.md)を実装し、RRL タイルで TL を描画します。ノード定義を持たない投稿加工は、取得ノードに渡す直前に適用されます。';

  @override
  String get storeCatalogFeatureTimelineRrl => 'タイムライン描画 (RRL)';

  @override
  String get storeCatalogFeatureNodeGraph => 'ノードグラフ (tl.sort)';

  @override
  String get storeCatalogMisskeyPerm1 =>
      'Misskey インスタンスの API を呼ぶため(接続先はログイン時に指定したホストのみ)';

  @override
  String get storeCatalogMisskeyPerm2 => 'セッショントークンと TL 設定の保存';

  @override
  String get storeCatalogMisskeyHost => '<ログインした Misskey インスタンス>';

  @override
  String get storeCatalogMisskeyDataHandling =>
      '投稿・トークンは端末内(storage.safe)にのみ保存。開発元への送信はありません。';

  @override
  String get storeCatalogSampleDataHandling => '処理は端末内の wasm で完結し、外部送信はありません。';

  @override
  String get storeCatalogAstellName => 'ASTell 効果音・効果映像';

  @override
  String get storeCatalogAstellSummary =>
      'ASTell のプラグインアクションから効果音 / 生成した効果映像 / 定型テキストを流します。';

  @override
  String get storeCatalogAstellDescription =>
      'スロット `astell.action`。ルーム下段の、このプラグインが宣言したボタンで FOW を開き、システム音(ピンポン / クリック)、紙吹雪・花火・拍手の生成 PNG、定型テキストを共有します。「ASTell で共有」した投稿の受け取りも表示します。';

  @override
  String get storeCatalogFeatureAstellAction => 'ASTell プラグインアクション';

  @override
  String get storeCatalogAstellPerm1 => '操作パネル(FOW)を出すため';

  @override
  String get storeCatalogAstellPerm2 => '効果の使用回数の保存';

  @override
  String get storeCatalogComposerMediaName => 'メディア加工';

  @override
  String get storeCatalogComposerMediaSummary => '添付画像のガンマ補正 / 回転 / 色相 / クロップ。';

  @override
  String get storeCatalogComposerMediaDescription =>
      'スロット `composer.media`。コンポーザーの添付タイルの「プラグインで加工」で FOW を開き、プレビューを見ながら適用します。処理は端末内の wasm だけで完結します。';

  @override
  String get storeCatalogFeatureMediaComposer => 'メディアコンポーザー';

  @override
  String get storeCatalogComposerMediaPerm1 => '加工パネル(FOW)を出すため';

  @override
  String get storeCatalogComposerMediaPerm2 => '前回の設定の保存';

  @override
  String get storeCatalogComposerTextName => 'ハッシュタグ候補';

  @override
  String get storeCatalogComposerTextSummary => '本文で # を打つと候補が出て、タップで挿入します。';

  @override
  String get storeCatalogComposerTextDescription =>
      'スロット `composer.text`。本文の変化を受け取り、カーソル直前が #〜 のときに候補 FOW(最近使ったタグ + 辞書)を出します。';

  @override
  String get storeCatalogFeatureTextComposer => 'テキストコンポーザー';

  @override
  String get storeCatalogComposerTextPerm1 => '候補パネル(FOW)を出すため';

  @override
  String get storeCatalogComposerTextPerm2 => '最近使ったタグの保存';

  @override
  String get storeCatalogMediaFullscreenName => 'QR コード検出';

  @override
  String get storeCatalogMediaFullscreenSummary =>
      '全画面表示の画像から QR コードを見つけて枠を出し、タップでリンクを開けます。';

  @override
  String get storeCatalogMediaFullscreenDescription =>
      'スロット `viewer.overlay`。全画面ビューワーの画像を受け取って QR を検出し、バウンディングボックスを重ねます。タップでリンク FOW(コピー / ブラウザで開く / ミュート語に追加)。';

  @override
  String get storeCatalogFeatureViewerPlugin => '全画面表示プラグイン';

  @override
  String get storeCatalogMediaFullscreenPerm1 => 'リンクパネル(FOW)を出すため';

  @override
  String get storeCatalogMediaFullscreenPerm2 =>
      '「このリンクをミュート」でミュート語に追加するため(毎回確認)';

  @override
  String get storeCatalogPostProcessName => '相対日付を日付に';

  @override
  String get storeCatalogPostProcessSummary => '「今日」「昨日」「明日」を投稿日基準の日付に置き換えます。';

  @override
  String get storeCatalogPostProcessDescription =>
      'スロット `post.transform`。全 TL の表示直前に本文の相対日付を「9/10(今日)」のように書き換えます(JST)。URL の中は触りません。';

  @override
  String get storeCatalogFeaturePostTransform => '投稿加工 (post.transform)';

  @override
  String get storeCatalogTimelineName => 'Unicode 昇順 TL';

  @override
  String get storeCatalogTimelineSummary => 'ホームに本文の Unicode 順で並ぶタブを足します。';

  @override
  String get storeCatalogTimelineDescription =>
      'スロット `tl`。基礎 TL(ホーム)を受け取り、本文の Unicode コードポイント昇順で並べ替えたカスタムタブを出します。';

  @override
  String get storeCatalogFeatureTimelineSort => 'タイムライン (tl.sort)';

  @override
  String get storeCatalogPostShareName => '共有テンプレート';

  @override
  String get storeCatalogPostShareSummary =>
      '共有 FOW から投稿をテンプレート(リンク / 引用 / 作者に言及)で整えてコンポーザーへ。';

  @override
  String get storeCatalogPostShareDescription =>
      'スロット `post.share`。投稿の共有 FOW の「プラグイン」節に自動で並び、タップするとインライン FOW で文面を選んでコンポーザー / コピー / ブラウザ / ASTell へ渡します。';

  @override
  String get storeCatalogFeaturePostShare => '投稿共有 (post.share)';

  @override
  String get storeCatalogPostSharePerm1 => 'テンプレート選択パネル(FOW)を出すため';

  @override
  String get storeCatalogPostSharePerm2 => '前回のテンプレートの保存';

  @override
  String get storeCatalogMediaTransformName => '変形ハンドル';

  @override
  String get storeCatalogMediaTransformSummary =>
      '画像の上に回転 / クロップのハンドルを重ねて編集します。';

  @override
  String get storeCatalogMediaTransformDescription =>
      'スロット `composer.media`(変形)。メディアエディターのプレビューに RRL の重ね(契約 v0.5 `composer.media.overlay`)でハンドルを描き、指でなぞって回転角やクロップ範囲を決めます。';

  @override
  String get storeCatalogFeatureOverlay => '重ね (overlay)';

  @override
  String get storeCatalogMediaTransformPerm1 => 'パネル(FOW)を出すため';

  @override
  String get storeCatalogMediaProcessName => '加工(顔ぼかし / スタンプ)';

  @override
  String get storeCatalogMediaProcessSummary =>
      '顔を検知してぼかす、スタンプをオブジェクトとして貼る(移動 / 拡縮 / 回転 / 削除 / 複製)。';

  @override
  String get storeCatalogMediaProcessDescription =>
      'スロット `composer.media`(加工)。顔検知は端末内の wasm(rustface)で行い、外部送信はありません。スタンプは重ねの枠とハンドルで動かせます。';

  @override
  String get storeCatalogMediaProcessPerm1 => 'スタンプ選択パネル(FOW)を出すため';

  @override
  String get storeCatalogMediaDrawName => '描画(ペン / 図形)';

  @override
  String get storeCatalogMediaDrawSummary =>
      'ペンの軌跡をスプライン曲線で描く、四角 / 丸を追加して編集します。';

  @override
  String get storeCatalogMediaDrawDescription =>
      'スロット `composer.media`(描画)。ペンは指の軌跡を Catmull-Rom スプラインで滑らかにして描きます。図形はオブジェクトとして移動 / 拡縮 / 削除 / 複製できます。';

  @override
  String get storeCatalogMediaDrawPerm1 => 'ペンの太さ / 色のパネル(FOW)を出すため';

  @override
  String get storeCatalogMediaDrawPerm2 => 'ペンの設定の保存';

  @override
  String get storeCatalogPostActionName => '投稿ボタン';

  @override
  String get storeCatalogPostActionSummary =>
      '後で読む / 本文をコピー / 引用の下書き — タグで既存ボタンのバンドルに入ります。';

  @override
  String get storeCatalogPostActionDescription =>
      'スロット `post.action`。マニフェストのタグ(希望スロット)が既存のアクションボタンに近ければ、そのバンドルの最下層に自動で入ります。「アクションリストの編集」でアカウントごとに有効 / 無効と閾値を変えられます。';

  @override
  String get storeCatalogFeaturePostAction => '投稿のアクションボタン (post.action)';

  @override
  String get storeCatalogPostActionPerm1 => '後で読む一覧(FOW)を出すため';

  @override
  String get storeCatalogPostActionPerm2 => '後で読むの保存';

  @override
  String get storeCatalogThemeStarryName => '着せ替え「星空」';

  @override
  String get storeCatalogThemeStarrySummary => '夜空の背景、星の粒を重ねた投稿タイル、星のいいね。';

  @override
  String get storeCatalogThemeStarryDescription =>
      '着せ替え(`kind: \"theme\"`、契約 v0.16)。コードを持たない配布物で、色 / アイコンの差し替え / 画面・投稿タイル・FOW・ボタンの背景の画像のレイヤーを宣言します。インストール後に 設定 → アプリの外観 → フォントやカラースキーム で選びます(暗いモードのときに効きます)。';

  @override
  String get storeCatalogFeatureTheme => '着せ替え';

  @override
  String get storeCatalogThemeRasqName => '着せ替え「RASQ」';

  @override
  String get storeCatalogThemeRasqSummary =>
      '投稿の上に紺のグラデーションの帯と薄い RASQ のマーク、FOW は緑のグラデーション。';

  @override
  String get storeCatalogThemeRasqDescription =>
      '着せ替え(`kind: \"theme\"`、契約 v0.17)。投稿タイルの上辺に #1F1E33 から投稿の背景色へ溶けるグラデーションの帯、背景に薄い RASQ のマーク、FOW の背景は上から下へ #02775C → #178178 のグラデーション(文字は白)。明るい / 暗いモードのどちらでも効きます。';

  @override
  String get storeCatalogPaintName => 'みんなで落書き';

  @override
  String get storeCatalogPaintSummary =>
      '1 人 1 マスの落書きを、期限つきでみんなに見せ合います。ASTell のルームやプロフィールで。';

  @override
  String get storeCatalogPaintDescription =>
      'カスタムプラグイン(スロット `page`、契約 v0.23)。3:4 のマスを 2 列に並べ(並びは人ごとにシャッフル)、自分のマスを押すとメディア編集画面の SVG モードで落書きします(保存は zstd で縮めて送ります)。表示期間は各自が選び、管理者(セッションの持ち主)が既定と上限を決めます。期限が来ると Central が消します。管理者は他人の落書きを削除できます。';

  @override
  String get storeCatalogFeatureCustomPage => 'カスタムプラグイン (page)';

  @override
  String get storeCatalogFeatureSvgPaint => 'SVG の落書き';

  @override
  String get storeCatalogFeatureDisplayPeriod => '表示期間';

  @override
  String get storeCatalogFeatureProfile => 'プロフィール';

  @override
  String get storeCatalogPaintPerm1 => '落書きのマスを表示し、編集画面を開くため';

  @override
  String get storeCatalogPaintPerm2 => 'みんなの落書きと管理者の設定を、期限つきで共有するため';

  @override
  String get storeCatalogBoardName => 'みんなのボード';

  @override
  String get storeCatalogBoardSummary =>
      'カウンター・投票・寄せ書き・🎉。ASTell のルームやプロフィールで、みんなで同じボードを使えます。';

  @override
  String get storeCatalogBoardDescription =>
      'カスタムプラグイン(スロット `page`、契約 v0.18)。ページを 1 枚足し、共有セッションではサーバー変数(カウンター / 投票 / 寄せ書き)とサーバー関数(🎉 を全員に)で同じ画面を共有します。セッションが無いときは端末の中だけで動きます。';

  @override
  String get storeCatalogBoardPerm1 => 'ページを描くため';

  @override
  String get storeCatalogBoardPerm2 => 'みんなの値(カウンター / 投票 / 寄せ書き)を共有するため';

  @override
  String get storeCatalogBoardPerm3 => '1 人で使うときのボードの保存';

  @override
  String get storeCatalogTrendName => 'トレンドサジェスト';

  @override
  String get storeCatalogTrendSummary => '今のトレンド語から関連タグをローカル規則で提案します。';

  @override
  String get storeCatalogTrendDescription =>
      'スロット `trend.suggest`。TL のノード(トレンドを取得 / Today / 候補のチップ)と、検索ホームの「検索の候補」で出します。サーバー無しの共起辞書 + 前方一致です。';

  @override
  String get storeCatalogFeatureTrendSuggest => 'トレンド (trend.suggest)';

  @override
  String storePkgMissingPlugin(String id) {
    return '配布物に $id がありません';
  }

  @override
  String get storePkgNotPackage => '配布物が .rasqpkg(zstd)ではありません';

  @override
  String storePkgUnpack(String error) {
    return '配布物を展開できません(壊れているか、大きすぎます): $error';
  }

  @override
  String storePkgTar(String error) {
    return '配布物の tar を読めません: $error';
  }

  @override
  String get storePkgTooManyFiles => '配布物のファイル数が多すぎます';

  @override
  String storePkgNotRegularFile(String path) {
    return '配布物に通常ファイルでないものがあります: $path';
  }

  @override
  String storePkgDuplicatePath(String path) {
    return '配布物内のパスが重複しています: $path';
  }

  @override
  String get storePkgBundleFirst => '配布物の先頭が bundle.json ではありません';

  @override
  String storePkgBundleRead(String error) {
    return 'bundle.json を読めません: $error';
  }

  @override
  String storePkgBundleSchema(String schema) {
    return 'bundle.json の schema が rasq.bundle/1 ではありません: $schema';
  }

  @override
  String storePkgFileShape(String what) {
    return 'bundle.json: $what の wasm / file の形が違います';
  }

  @override
  String storePkgNoPath(String what) {
    return 'bundle.json: $what に path がありません';
  }

  @override
  String storePkgSizeMismatch(String path) {
    return '$path: 大きさが目次と違います';
  }

  @override
  String storePkgHashMismatch(String path) {
    return '$path: SHA-512 が目次と違います';
  }

  @override
  String storePkgNoSha512(String what) {
    return 'bundle.json: $what に sha512 がありません';
  }

  @override
  String storePkgNotWasm(String path) {
    return '$path: wasm ではありません';
  }

  @override
  String storePkgPluginShape(String what) {
    return 'bundle.json: $what の形が違います';
  }

  @override
  String storePkgBadId(String what, String id) {
    return 'bundle.json: $what の id が不正です: $id';
  }

  @override
  String storePkgBadVersion(String id, String version) {
    return 'bundle.json: $id の version が不正です: $version';
  }

  @override
  String storePkgBadKind(String id, String kind) {
    return 'bundle.json: $id の kind が不正です: $kind';
  }

  @override
  String storePkgNoManifest(String id) {
    return 'bundle.json: $id に manifest がありません';
  }

  @override
  String storePkgManifestRead(String path, String error) {
    return '$path を読めません: $error';
  }

  @override
  String storePkgManifestMismatch(
    String path,
    String id,
    String version,
    String kind,
  ) {
    return '$path: id / version / kind が目次($id $version $kind)と違います';
  }

  @override
  String storePkgChildPackKind(String id, String kind) {
    return 'bundle.json: 子 $id は kind = $kind にできません';
  }

  @override
  String storePkgPackHasWasm(String kind, String id) {
    return 'bundle.json: $kind $id が wasm を持っています';
  }

  @override
  String storePkgMissingKey(String key) {
    return 'bundle.json: $key がありません';
  }

  @override
  String get storePkgChildrenNotSns =>
      'bundle.json: sns 以外の root は children を持てません';

  @override
  String storePkgChildPrefix(String id, String root) {
    return 'bundle.json: 子 $id の id が $root. で始まっていません';
  }

  @override
  String storePkgChildSns(String id) {
    return 'bundle.json: 子 $id は kind = sns にできません';
  }

  @override
  String get storePkgDuplicateId => 'bundle.json: プラグインの id が重複しています';

  @override
  String get storePkgLibsShape => 'bundle.json: libs の形が違います';

  @override
  String get storePkgAssetsShape => 'bundle.json: assets の形が違います';

  @override
  String get storePkgPackExtras =>
      'bundle.json: アセットパック / 着せ替えは children / libs / models を持てません';

  @override
  String get storePkgPackWasm => 'アセットパック / 着せ替えに wasm が入っています';

  @override
  String storePkgPackImageCount(int max, int count) {
    return 'アセットパックの画像は 1〜$max 枚です: $count';
  }

  @override
  String storePkgNotImage(String path) {
    return '$path: 画像(PNG / JPEG / WebP / GIF)ではありません';
  }

  @override
  String storePkgImageTooLarge(String path, int mib) {
    return '$path: 大きすぎます(1 枚 $mib MiB まで)';
  }

  @override
  String storePkgAssetNotListed(String path) {
    return 'manifest.assets の $path が配布物の目次にありません';
  }

  @override
  String get storePkgModelsShape => 'bundle.json: models の形が違います';

  @override
  String get storePkgRequiresShape => 'bundle.json: requires の形が違います';

  @override
  String get storePkgNoSums => 'SHA512SUMS がありません';

  @override
  String storePkgSumsMissingFile(String path) {
    return '$path: SHA512SUMS にあるのに中にありません';
  }

  @override
  String storePkgSumsMismatch(String path) {
    return '$path: SHA512SUMS と違います';
  }

  @override
  String storePkgUnlisted(String path) {
    return '$path: 目次に載っていないファイルがあります';
  }

  @override
  String get storePkgThemeMissing => '着せ替えのマニフェストに theme がありません';

  @override
  String storePkgThemeAsset(String where, String id) {
    return 'theme.$where の画像 $id が assets(use: theme)にありません';
  }

  @override
  String storePkgThemeSurface(String surface) {
    return 'theme.surfaces の $surface は使えません(app / postTile / fow / actionButton)';
  }

  @override
  String storePkgThemeLayer(String surface) {
    return 'theme.surfaces.$surface.layers: asset か gradient のどちらか 1 つを書いてください';
  }

  @override
  String storePkgThemeColors(String surface) {
    return 'theme.surfaces.$surface.layers: gradient.colors は 2〜8 色です';
  }

  @override
  String storePkgThemeStops(String surface) {
    return 'theme.surfaces.$surface.layers: gradient.stops は colors と同じ数です';
  }

  @override
  String storePkgBadPath(String path) {
    return '配布物内のパスとして使えません: $path';
  }

  @override
  String storePkgSigAlg(String alg) {
    return '署名の alg が ed25519 ではありません: $alg';
  }

  @override
  String get storePkgSigDigest => 'sig.json の digest が配布物と違います(配布物が差し替わっています)';

  @override
  String get storePkgSigRead => 'sig.json の publicKey / signature を読めません';

  @override
  String get storePkgSigLength => 'sig.json の鍵 / 署名の長さが違います';

  @override
  String get storePkgSigInvalid => '開発者鍵の署名が合いません';

  @override
  String storePkgFileMissing(String path) {
    return '$path: 目次にあるのに中にありません';
  }

  @override
  String storePkgTwice(String path) {
    return 'bundle.json: $path が 2 回出てきます';
  }

  @override
  String get storePkgKindTheme => '着せ替え';

  @override
  String get storePkgKindAssets => 'アセットパック';

  @override
  String swingActionFailed(String error) {
    return 'できませんでした: $error';
  }

  @override
  String get swingReplyHint => '返信を送る…';

  @override
  String swingReplyToHint(String handle) {
    return '@$handle に返信…';
  }

  @override
  String swingReplyCount(int count) {
    return '返信 $count';
  }

  @override
  String get swingQueueTooltip => 'キュー(長押しで絵を選ぶ)';

  @override
  String get swingThreadBackReply => '前の返信へ戻る';

  @override
  String get swingThreadBackSwing => 'Swing の返信へ戻る';

  @override
  String swingRepliesTo(String handle, int count) {
    return '@$handle への返信 $count';
  }

  @override
  String get swingThreadClose => '返信をしまう';

  @override
  String swingLoadFailed(String error) {
    return '読み込めませんでした: $error';
  }

  @override
  String get swingNoReplies => '返信はまだありません。';

  @override
  String swingViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '返信 $_temp0を見る';
  }

  @override
  String swingAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '添付 $_temp0';
  }

  @override
  String get swingPoll => '投票';

  @override
  String swingReplyOf(String name) {
    return '$name の返信';
  }

  @override
  String get swingImageSwing => '画像の Swing';

  @override
  String get swingVideoSwing => '動画の Swing';

  @override
  String get swingPluginSwing => 'プラグインの Swing';

  @override
  String swingOf(String name) {
    return '$name の Swing';
  }

  @override
  String get swingBarSemantics => 'Swing の返信とシークバー';

  @override
  String swingReportIntro(String name) {
    return '$name の Swing を通報します。RASQ の審査で確認します。';
  }

  @override
  String get swingReported => '通報しました。審査で確認します';

  @override
  String swingReportFailed(String error) {
    return '通報できませんでした: $error';
  }

  @override
  String get swingDeleteTitle => 'Swing を削除';

  @override
  String get swingDeleteMessage => 'この Swing と、付いている返信を削除します。元に戻せません。';

  @override
  String get swingDeleteConfirm => '削除する';

  @override
  String get swingCancel => 'キャンセル';

  @override
  String swingDeleteFailed(String error) {
    return '削除できませんでした: $error';
  }

  @override
  String get swingDeleted => 'Swing を削除しました';

  @override
  String get swingViewerEmptyMine => '出している Swing はありません';

  @override
  String get swingViewerEmptyMineHint => '＋ を上へスワイプすると Swing を作れます';

  @override
  String get swingViewerEmpty => 'Swing はありません';

  @override
  String get swingViewerEmptyHint =>
      'フォローしている人や、RASQ リストに入れてくれた人の Swing がここに流れます';

  @override
  String get swingClose => '閉じる';

  @override
  String swingRemainingHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 時間',
    );
    return 'あと $_temp0';
  }

  @override
  String swingRemainingMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes 分',
    );
    return 'あと $_temp0';
  }

  @override
  String get swingRemainingSoon => 'まもなく消えます';

  @override
  String swingRemainingAndPosition(String remaining, String position) {
    return '$remaining ・ $position';
  }

  @override
  String swingViewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人',
    );
    return '見た人 $_temp0';
  }

  @override
  String get swingReport => '通報';

  @override
  String get swingMenu => 'メニュー';

  @override
  String get swingDelete => '削除';

  @override
  String get swingSensitive => 'センシティブな内容';

  @override
  String get swingReveal => '表示する';

  @override
  String swingPluginJoinNote(String name) {
    return '$name さんのページにみんなで入ります。インストールせずに、この Swing を見ている間だけ動かします。';
  }

  @override
  String get swingPluginJoin => '参加する';

  @override
  String get swingPluginConsent =>
      '審査されていないプラグインです。通信はできない状態で、この Swing を見ている間だけ動かします。';

  @override
  String get swingPluginConsentDetail =>
      '制限モード(network / storage.unsafe / interstitial・system の FOW / URL を開くなどは閉、GPU は可)。子プラグインを持たない 1 つだけ。';

  @override
  String get swingPluginRun => '動かす';

  @override
  String swingPluginNeedsInstall(String name) {
    return '$name を入れると見られます';
  }

  @override
  String get swingPluginNeedsInstallHint => 'プラグインの Swing です。ストアからインストールしてください';

  @override
  String get swingViewInStore => 'ストアで見る';

  @override
  String get swingPluginOpenFailed => '開けませんでした';

  @override
  String get swingPluginTapToExpand => '押すと全画面に戻ります';

  @override
  String get swingPluginSwipeHint => '左右・上下にスワイプで次の Swing へ';

  @override
  String get swingPluginShrink => '全画面から縮小';

  @override
  String get swingAd => '広告';

  @override
  String get swingAdSwipeHint => 'スワイプで次の Swing へ';

  @override
  String get swingKindText => 'テキスト';

  @override
  String get swingKindImage => '画像';

  @override
  String get swingKindVideo => '動画';

  @override
  String get swingKindPlugin => 'プラグイン';

  @override
  String swingKindSwing(String kind) {
    return '$kindの Swing';
  }

  @override
  String swingBannerNew(int count) {
    return '新着 $count';
  }

  @override
  String swingBannerTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '$_temp0';
  }

  @override
  String get swingComposerPluginShared => 'みんなで使う: 見た人は、あなたが作る同じページに入ります';

  @override
  String get swingComposerPluginFullscreen => '見る人の端末で全画面で動きます';

  @override
  String get swingComposerPluginPage => '見る人の端末でページとして動きます';

  @override
  String swingTtlLabel(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 時間で消える',
    );
    return '$_temp0';
  }

  @override
  String get swingTtl => '消えるまで';

  @override
  String swingTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 時間',
    );
    return '$_temp0';
  }

  @override
  String get swingBackgroundImage => '画像を背景にする';

  @override
  String get swingBackgroundVideo => '動画を背景にする';

  @override
  String get swingPickVideoFile => '動画のファイルを選んでください';

  @override
  String get swingPickImageFile => '画像のファイルを選んでください';

  @override
  String get swingChangeBackground => '背景を変える';

  @override
  String get swingAudience => '届け先';

  @override
  String get swingLoadFailedShort => '読み込めませんでした';

  @override
  String swingSent(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 時間で消えます',
    );
    return 'Swing を出しました($_temp0)';
  }

  @override
  String get swingErrorLimit => '同時に出しておける Swing は 20 個までです';

  @override
  String swingSendFailed(String error) {
    return '出せませんでした: $error';
  }

  @override
  String get swingComposerTitle => 'Swing を作る';

  @override
  String get swingNext => '次へ';

  @override
  String get swingSend => '出す';

  @override
  String get swingNeedsAccount => 'RASQ アカウントが要ります';

  @override
  String get swingNeedsAccountHint =>
      'Swing は RASQ アカウントから出します。サイドバーからログインしてください';

  @override
  String swingUnreviewed(String name) {
    return '$name(未審査)';
  }

  @override
  String swingTtlRemaining(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours 時間で消えます',
    );
    return '$_temp0';
  }

  @override
  String get swingRepick => '選び直す';

  @override
  String get swingReedit => '編集し直す';

  @override
  String swingCwTooLong(int max) {
    return 'CW は $max 文字までです';
  }

  @override
  String get swingCwHint => 'CW の文';

  @override
  String get swingCwOff => 'CW をはずす';

  @override
  String get swingCwOn => 'CW を付ける(センシティブな内容)';

  @override
  String get swingPluginSection => '配るプラグイン';

  @override
  String get swingPluginNone =>
      'Swing で配れるカスタムプラグインが入っていません。ストアで入れるか、下の「ファイルから」で自分のプラグインを配れます。';

  @override
  String get swingPluginNoneDetail =>
      'ページ型(カスタムプラグイン)のうち、ほかのプラグインと親子関係の無いもの(solo / shared どちらも)。';

  @override
  String get swingFromFile => 'ファイルから(未審査)';

  @override
  String get swingFromFileSubtitle => '自分で作った .rspkg / .rasqpkg / .wasm を配ります';

  @override
  String get swingFromFileDetail =>
      '審査していないプラグインは、見る人の端末で通信できない状態で動きます(GPU は使えます)。ほかのプラグインを土台にする子プラグインは配れません。';

  @override
  String get swingAudienceEmpty => '届け先を 1 つ以上選んでください';

  @override
  String get swingAudienceFollowers => 'フォロワー';

  @override
  String get swingAudienceFollowersSubtitle => 'RASQ アカウントをフォローしている人';

  @override
  String get swingAudienceList => 'RASQ リスト';

  @override
  String get swingAudienceNoLists => 'RASQ リストを作ると、リストに入れた人にも届けられます';

  @override
  String swingPackageFetchFailed(int status) {
    return 'プラグインを取れませんでした(HTTP $status)';
  }

  @override
  String get swingNotLoggedIn => 'RASQ アカウントにログインしていません';

  @override
  String get swingUnreadable => 'Swing を読めませんでした';

  @override
  String get trendTitle => 'トレンド';

  @override
  String get trendTabNotes => 'ノート';

  @override
  String get trendTabFollowing => 'フォロー中';

  @override
  String get trendTabUsers => 'ユーザー';

  @override
  String get trendBackToHome => 'トレンドホームへ戻る';

  @override
  String get trendSourceAccountMark => 'トレンドに出したアカウント';

  @override
  String get trendSettingsTooltip => 'トレンド設定';

  @override
  String get trendCustomizeTooltip => 'トレンド TL をカスタマイズ';

  @override
  String get trendReload => '再読み込み';

  @override
  String get trendEmptyTitle => 'なんにもないようです';

  @override
  String get trendEmptyHint => 'ワードやフィルタを変えると見つかるかもしれません';

  @override
  String get trendFollowingEmptyTitle => 'フォロー中の投稿はありません';

  @override
  String get trendFollowingEmptyHint => 'このワードについてフォロイーはまだ投稿していません';

  @override
  String get trendUsersBlocked => '保護者がユーザーの検索を止めています';

  @override
  String get trendUsersEmpty => 'ユーザーはいません';

  @override
  String trendUserReactions(int count) {
    return 'リアクション $count';
  }

  @override
  String get trendMenuOpenAs => '別のアカウントで開く';

  @override
  String get trendMenuReport => '通報';

  @override
  String trendMenuAccountSourced(String account) {
    return '$account(トレンドに出したアカウント)';
  }

  @override
  String get trendReportTitle => '通報';

  @override
  String trendReportMessage(String tag) {
    return 'トレンド「$tag」を通報します。RASQ の審査で確認します。通報したトレンドは、トレンドの一覧に出なくなります。';
  }

  @override
  String trendReportMessageWithServer(String tag, String server) {
    return 'トレンド「$tag」($server)を通報します。RASQ の審査で確認します。通報したトレンドは、トレンドの一覧に出なくなります。';
  }

  @override
  String get trendReportNoteHint => '補足(任意)';

  @override
  String get trendReportSend => '通報する';

  @override
  String get trendReportSent => '通報しました。RASQ の審査で確認します';

  @override
  String get trendReportStored => 'この端末に控えました。RASQ アカウントに繋がったら送ります';

  @override
  String get trendReportFailed => '送れなかったので、この端末に控えました(あとで送り直します)';

  @override
  String get trendReportUnhide => '表示に戻す';

  @override
  String get trendPluginFallbackName => 'トレンドプラグイン';

  @override
  String get trendPluginLoadFailed => '読み込めませんでした';

  @override
  String get trendPluginNoWords => '候補のワードはまだありません';

  @override
  String trendPluginWordQuoted(String word) {
    return '「$word」';
  }

  @override
  String trendPluginTodayEmpty(String words) {
    return '$wordsの投稿はまだありません';
  }

  @override
  String trendPluginTodayHeading(String words) {
    return '$wordsの投稿';
  }

  @override
  String get trendEmotionJoy => '喜び';

  @override
  String get trendEmotionTrust => '信頼';

  @override
  String get trendEmotionFear => '恐れ';

  @override
  String get trendEmotionSurprise => '驚き';

  @override
  String get trendEmotionSadness => '悲しみ';

  @override
  String get trendEmotionDisgust => '嫌悪';

  @override
  String get trendEmotionAnger => '怒り';

  @override
  String get trendEmotionAnticipation => '期待';

  @override
  String get trendExamplesNoCandidates => '候補がありません';

  @override
  String get trendExamplesAllow => '好き';

  @override
  String get trendExamplesDeny => '好きではない';

  @override
  String get trendExamplesDecide => '決定';

  @override
  String trendExamplesLoadFailed(String source, String error) {
    return '$sourceを読み込めませんでした: $error';
  }

  @override
  String get trendExamplesAllSeen => '全部見ました';

  @override
  String trendExamplesAllSeenHint(
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
  ) {
    return '$allowLabel $allow / $denyLabel $deny。決定で保存します';
  }

  @override
  String trendExamplesIntro(String allowLabel, String denyLabel) {
    return '中身を見て、下の「$allowLabel」/「$denyLabel」(右 / 左スワイプでも)で例にします。新しいものは、例との近さで分けます。';
  }

  @override
  String trendExamplesSummary(
    String intro,
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
    int remaining,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining 件',
    );
    return '$intro($allowLabel $allow / $denyLabel $deny・残り $_temp0)';
  }

  @override
  String get trendExamplesSearch => '探す';

  @override
  String get trendExamplesSkip => 'とばす';

  @override
  String trendExamplesMorePosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '+$_temp0';
  }

  @override
  String get trendExamplesPostsUnreadable => '投稿を読めませんでした(名前と説明で比べます)';

  @override
  String trendExamplesOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return 'ほか $_temp0';
  }

  @override
  String get trendExamplesSourceActions => '最近のアクション';

  @override
  String get trendExamplesSourceActionsEmpty => '最近のアクションがありません';

  @override
  String get trendExamplesSourceActionsEmptyHint =>
      'リアクションやブックマークをすると、ここから選べます';

  @override
  String get trendExamplesSourcePlugins => 'プラグイン';

  @override
  String get trendExamplesSourcePluginsEmpty => '入れているプラグインはありません';

  @override
  String get trendExamplesSourceClips => 'クリップ';

  @override
  String get trendExamplesSourceClipsEmpty => 'クリップはありません';

  @override
  String get trendExamplesSourceLists => 'リスト';

  @override
  String get trendExamplesSourceListsEmpty => 'リストはありません';

  @override
  String get trendExamplesSourceStore => 'ストア';

  @override
  String get trendExamplesSourceStoreHint => 'ストアを探す(空 = 一覧)';

  @override
  String get trendExamplesSourceStoreEmpty => '見つかりませんでした';

  @override
  String get trendExamplesKindPlugin => 'プラグイン';

  @override
  String get trendExamplesKindClip => 'クリップ';

  @override
  String get trendExamplesKindList => 'リスト';

  @override
  String get trendExamplesKindPost => '投稿';

  @override
  String get trendExamplesKindText => 'ことば';

  @override
  String get trendProfileSheetTitle => 'トレンドプロファイル設定';

  @override
  String get trendProfileClose => '閉じる';

  @override
  String get trendProfileDecide => '決定';

  @override
  String get trendProfileGenres => '好きなジャンル/方向性';

  @override
  String get trendProfileGenresSnsDefault => '好きなジャンル/方向性(SNS 側の設定に任せる)';

  @override
  String get trendProfileGenresAuto => '好きなジャンル/方向性(アクションから自動抽出)';

  @override
  String get trendProfileAddGenrePill => '+ ジャンルを追加';

  @override
  String get trendProfileEdit => '編集';

  @override
  String get trendProfileTendencyTitle => 'トレンドの指向性/刺激性';

  @override
  String trendProfileTendencySummary(String directivity, String stimulus) {
    return '指向性 $directivity ・ 刺激性 $stimulus';
  }

  @override
  String get trendProfilePluginsTitle => 'トレンドプラグインの設定';

  @override
  String get trendProfilePluginsSubtitle => 'TL のノード / 検索の候補';

  @override
  String get trendProfilePluginsDetail =>
      'trend.suggest のプラグイン。TL のカスタマイズのノード(トレンドを取得 / Today / カスタム)と検索の候補で出します';

  @override
  String get trendProfileCacheNetworkTitle => 'キャッシュネットワークの設定';

  @override
  String get trendProfileComingSoon => '準備中';

  @override
  String get trendProfileAlgorithmTitle => 'アルゴリズム(ノード)を編集';

  @override
  String get trendProfileAlgorithmSubtitle => 'トレンドの集め方・並べ方を編集します';

  @override
  String get trendProfileAlgorithmDetail =>
      'トレンドの取得・並べ替えの鎖(ml.tendency ノードでこのプロファイルを使えます)';

  @override
  String get trendProfileSharedCaption => 'この設定は、おすすめ / トレンド / 関連 TL で共通です。';

  @override
  String get trendProfileSharedCaptionDetail =>
      'このプロファイルは storage.safe(trend.profile)に保存され、おすすめ / トレンド / 関連 TL の既定と、ノードエディタの「指向性/刺激性」ノードが共通で読みます。';

  @override
  String get trendProfileDirNarrow => '狭い';

  @override
  String get trendProfileDirWide => '広い';

  @override
  String get trendProfileDirNormal => 'ふつう';

  @override
  String get trendProfileStimNone => '制限なし';

  @override
  String trendProfileStimCapped(String emotions) {
    return '$emotionsを抑える';
  }

  @override
  String get trendProfileListSeparator => '・';

  @override
  String get trendProfileDirectivityTitle => 'トレンドの指向性';

  @override
  String get trendProfileDirectivitySubtitle => '狭いほど、好きなジャンルから外れた投稿を出しません。';

  @override
  String get trendProfileDirectivityDetail =>
      '好きなジャンル/方向性への近さのしきい値(狭い ⇄ 広い)。狭いほど外れた投稿を落とします。';

  @override
  String get trendProfileShareTitle => '設定を共有';

  @override
  String get trendProfileShareSubtitle => 'おすすめ / トレンド / 関連 TL にこの設定を使います';

  @override
  String get trendProfileShareDetail => 'オフにすると TL の既定適用を止めます(ノードで明示した分は効きます)';

  @override
  String get trendProfileStimulusTitle => 'トレンドの刺激性';

  @override
  String get trendProfileStimulusCaption => '各感情の上限。中心に寄せるほど抑えます';

  @override
  String get trendProfileStimulusReset => '刺激性をリセット';

  @override
  String get trendProfileEchoChamberWarning =>
      'トレンドの指向性/刺激性を強くすると、エコーチェンバーの影響を受けやすくなる危険性があります。';

  @override
  String get trendProfileStimulusEstimate => '刺激性は、いまは言葉の傾向から推定しています。';

  @override
  String get trendProfileStimulusEstimateDetail => '刺激性は語彙ルールで推定しています。';

  @override
  String get trendProfileTendencySaved => 'トレンドの指向性/刺激性を保存しました';

  @override
  String get trendProfileSnsDefaultTitle => 'SNS 側の設定に任せる';

  @override
  String get trendProfileSnsDefaultSubtitle => 'オンの間は端末側で絞りません';

  @override
  String get trendProfileAutoGenreTitle => 'あなたのアクションから自動抽出';

  @override
  String get trendProfileAutoGenreSubtitle => 'リアクションした投稿の特徴語を好きなジャンルに足します';

  @override
  String get trendProfilePickFromActions => '最近のアクションから好きなものを選択';

  @override
  String get trendProfileGenresTapToRemove => '好きなジャンル/方向性(タップで外す)';

  @override
  String get trendProfileNoneYet => 'まだありません';

  @override
  String get trendProfileAddGenreHint => 'ジャンル/キーワードを追加';

  @override
  String get trendProfileAddGenre => 'ジャンルを追加';

  @override
  String trendProfileExamplesLabel(int allow, int deny) {
    return '例(好き $allow / 好きではない $deny。タップで外す)';
  }

  @override
  String trendProfileExampleAllow(String label) {
    return '好き: $label';
  }

  @override
  String trendProfileExampleDeny(String label) {
    return '好きではない: $label';
  }

  @override
  String get trendProfileDislikedTapToRemove => '好きではない(タップで外す)';

  @override
  String get trendProfileGenresSaved => '好きなジャンル/方向性を保存しました';

  @override
  String get trendProfilePickTitle => 'アクションからジャンルを選択';

  @override
  String get trendProfilePickIntro =>
      '最近のアクションを話題ごとに出しています。カードを選んで「好き」/「好きではない」へ(右/左スワイプでも)。';

  @override
  String trendProfilePickIntroDetail(int perPage) {
    String _temp0 = intl.Intl.pluralLogic(
      perPage,
      locale: localeName,
      other: '$perPage 件',
    );
    return '最近のアクションを類似した話題でまとめ、話題性の強いものから $_temp0ずつ出しています(上のチップでプラグイン / クリップ / リストからも)。カードをタップして選び、候補のジャンルを選んで下の「好き」/「好きではない」(右/左スワイプでも)。';
  }

  @override
  String get vcSectionInvited => '招待';

  @override
  String get vcSectionRecommended => 'おすすめ';

  @override
  String get vcSectionUpcoming => '近日開催';

  @override
  String get vcSectionTrending => 'トレンド';

  @override
  String get vcSectionFollowing => 'フォロー中';

  @override
  String vcSectionSettingsTooltip(String title) {
    return '$titleの設定';
  }

  @override
  String get vcSearchHint => 'ASTell / Swing を検索';

  @override
  String get vcSearchRefineHint => 'さらに絞る';

  @override
  String vcSearchTermChip(String term) {
    return '「$term」 ×';
  }

  @override
  String get vcSearchClear => '消す';

  @override
  String get vcCreateTooltip => 'VC を作成';

  @override
  String get vcHomeLoadError => 'VC を取得できませんでした';

  @override
  String vcJoinedRoom(String title) {
    return '参加中: $title';
  }

  @override
  String vcJoinedPeers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count人 ・ タップで開く',
    );
    return '$_temp0';
  }

  @override
  String get vcConnecting => '接続しています…';

  @override
  String vcInvitedBy(String name) {
    return '$name から招待 ・ タップで見る';
  }

  @override
  String get vcInviteDecline => '辞退';

  @override
  String get vcRecommendedEmpty => 'おすすめの VC はまだありません';

  @override
  String get vcTrendingEmpty => 'トレンドの VC はまだありません';

  @override
  String get vcFollowingEmpty => 'フォロー中のユーザーの VC はありません';

  @override
  String get vcSearchNoResults => '見つかりませんでした';

  @override
  String get vcSearchNoResultsInSection => 'この節にはありません';

  @override
  String vcSearchNoResultsFor(String query) {
    return '「$query」に当たる ASTell / Swing はありません';
  }

  @override
  String get vcTileOpen => '見てみる';

  @override
  String get vcBookmarkRemove => 'ブックマークから削除';

  @override
  String get vcBookmarkSave => 'ブックマークに保存';

  @override
  String get vcRemindCancel => '開始通知を解除';

  @override
  String get vcRemindSet => '開始を通知';

  @override
  String get vcMenuTooltip => 'メニュー';

  @override
  String vcScheduledAt(String when) {
    return '開催予定 $when';
  }

  @override
  String get vcSummaryPrivate => 'ざっくり要約は非公開です。';

  @override
  String get vcTileStripEmpty => 'VC はまだありません';

  @override
  String get vcLinkCopied => 'リンクをコピーしました';

  @override
  String get vcBookmarkSaved => 'ブックマークに保存しました';

  @override
  String get vcBookmarkRemoved => 'ブックマークから削除しました';

  @override
  String vcRemindRegistered(String when) {
    return '$when に通知します';
  }

  @override
  String get vcRemindRemoved => '通知を解除しました';

  @override
  String get vcRemindUnavailable => 'この端末では通知を登録できませんでした';

  @override
  String get vcRemindNotScheduled => '開催予定のないルームです';

  @override
  String get vcMenuShareAsPost => '投稿で共有';

  @override
  String get vcMenuCopyLink => 'リンクをコピー';

  @override
  String get vcMenuStartNow => '今すぐ開催する';

  @override
  String get vcMenuBackToRoom => 'ルームへ戻る';

  @override
  String get vcMenuJoin => '参加する';

  @override
  String get vcMenuClose => '終了する';

  @override
  String get vcMenuUnfollowHost => 'ホストのフォローを解除';

  @override
  String get vcMenuFollowHost => 'ホストをフォロー';

  @override
  String get vcMenuMute => 'ミュート';

  @override
  String get vcMenuReport => '報告';

  @override
  String vcUnfollowed(String name) {
    return '$name のフォローを解除しました';
  }

  @override
  String vcFollowed(String name) {
    return '$name をフォローしました';
  }

  @override
  String vcReportWhatRoom(String title) {
    return 'ルーム「$title」';
  }

  @override
  String vcMenuNotYet(String title, String action) {
    return '「$title」の操作($action)は M5 後段で入ります';
  }

  @override
  String get vcCloseRoomTitle => 'ルームを終了';

  @override
  String vcCloseScheduledBody(String title) {
    return '「$title」の予約を取り消します。ブックマークや開始通知を登録した人には届きません。';
  }

  @override
  String vcCloseRoomBody(String title) {
    return '「$title」を終了します。参加中のメンバーは退出になります。';
  }

  @override
  String vcClosedScheduled(String title) {
    return '「$title」の予約を取り消しました';
  }

  @override
  String vcClosedRoom(String title) {
    return '「$title」を終了しました';
  }

  @override
  String vcCloseFailed(String error) {
    return '終了できませんでした: $error';
  }

  @override
  String get vcTileBack => '戻る';

  @override
  String get vcReminderNotificationTitle => 'ブックマークしたVCが始まります！';

  @override
  String vcReminderNotificationBody(String host, String title) {
    return '$host の「$title」';
  }

  @override
  String vcShareTextScheduled(String title, String when) {
    return '「$title」を $when に開催します';
  }

  @override
  String vcShareTextOpen(String title) {
    return '「$title」を開催中です';
  }

  @override
  String get vcViewerPluginsTooltip => '全画面表示プラグイン(準備中)';

  @override
  String vcViewerSharedBy(String name) {
    return '$name が共有';
  }

  @override
  String get vcViewerSave => '保存';

  @override
  String get vcViewerSaveNotYet => '保存は準備中です';

  @override
  String get vcViewerShare => '共有';

  @override
  String get vcViewerShareNotYet => '共有は準備中です';

  @override
  String get vcBarSpeaker => 'スピーカー';

  @override
  String get vcBarMic => 'マイク';

  @override
  String get vcBarScreen => '画面共有';

  @override
  String get vcBarFullscreen => '全画面(共有枠に画面があるとき)';

  @override
  String get vcBarCaptions => '字幕(文字起こし)';

  @override
  String vcCallConnectFailed(String error) {
    return '通話の接続に失敗しました: $error';
  }

  @override
  String get vcOpenNotFound => 'このルームは見つかりません(終了したか、リンクが違うかもしれません)';

  @override
  String get vcOpenFailed => 'ルームを開けませんでした';

  @override
  String get vcOpenGoHome => 'ASTell のホームへ';

  @override
  String vcOpenHost(String name, String handle) {
    return 'ホスト: $name(@$handle)';
  }

  @override
  String get vcOpenRoom => 'ルームを開く';

  @override
  String get vcShareBlockDirect => 'ダイレクトの投稿は ASTell に共有できません';

  @override
  String get vcShareBlockLocalOnly => 'ローカル限定の投稿は ASTell に共有できません';

  @override
  String get vcShareBlockUnknownVisibility => '公開範囲が分からない投稿は ASTell に共有できません';

  @override
  String get vcShareBlockLimited => '公開範囲が限定された投稿は ASTell に共有できません';

  @override
  String get vcShares => '共有';

  @override
  String vcSharesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共有 ($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcSharesShowAll => 'すべての共有を見る';

  @override
  String get vcSharesEmpty => 'チャットで 📌 したものがここに並びます。';

  @override
  String get vcShareActions => '共有の操作';

  @override
  String get vcShareTranscriptSource => 'RASQ ・ 文字起こし';

  @override
  String get vcUnpin => 'ピン留めを外す';

  @override
  String get vcYou => 'あなた';

  @override
  String get vcNoDescription => '説明はありません。';

  @override
  String get vcReportReasonSpam => 'スパム';

  @override
  String get vcReportReasonHarassment => '嫌がらせ・暴言';

  @override
  String get vcReportReasonIllegal => '違法・危険な内容';

  @override
  String get vcReportReasonOther => 'その他';

  @override
  String get vcJoinPolicyAnyone => '誰でも';

  @override
  String get vcJoinPolicyAnyoneHint => '公開ルームは誰でも参加できます';

  @override
  String get vcJoinPolicyFollowers => 'フォロワーだけ';

  @override
  String get vcJoinPolicyFollowersHint => 'あなた(ホスト)を RASQ アカウントでフォローしている人';

  @override
  String get vcJoinPolicyFollowing => 'フォロー中の人だけ';

  @override
  String get vcJoinPolicyFollowingHint => 'あなたがフォローしている人';

  @override
  String get vcJoinPolicyMutual => '相互フォローだけ';

  @override
  String get vcJoinPolicyMutualHint => 'お互いにフォローしている人';

  @override
  String get vcSharePolicyEveryone => '全員';

  @override
  String get vcSharePolicyModerators => 'モデレーターだけ';

  @override
  String vcShareContentWarning(String warning) {
    return '⚠ $warning(閲覧注意)';
  }

  @override
  String vcSharePluginWant(String name) {
    return '「$name」を使いたい';
  }

  @override
  String get vcKindPost => '投稿';

  @override
  String get vcKindMedia => 'メディア';

  @override
  String get vcKindVideo => '動画';

  @override
  String get vcKindLink => 'リンク';

  @override
  String get vcKindText => 'テキスト';

  @override
  String get vcKindPlugin => 'プラグイン';

  @override
  String get vcMediaInsecureContext => 'Web 版の通話は https で開いたときだけ使えます';

  @override
  String get vcMediaPermissionDenied => 'マイク(カメラ)の許可がありません。端末の設定で許可してください';

  @override
  String get vcMediaNoDevice => 'マイク(カメラ)が見つかりません';

  @override
  String get vcMediaUnsupported => 'この端末では使えません';

  @override
  String vcMediaUnsupportedDetail(String detail) {
    return 'この端末では使えません($detail)';
  }

  @override
  String get vcMediaMicClosed => '閉じた通話のマイクは開けません';

  @override
  String get vcStreamNotConnected => '配信サーバーに繋がっていません';

  @override
  String get vcStreamPublishFailed => '映像を配信サーバーに上げられませんでした';

  @override
  String get vcScreenSharingNotification => '画面を共有しています';

  @override
  String get vcScreenPickTitle => '共有する画面を選ぶ';

  @override
  String get vcScreenPickScreen => '画面全体';

  @override
  String get vcScreenPickWindow => 'ウィンドウ';

  @override
  String get vcScreenPickCancel => 'やめる';

  @override
  String get vcScreenPickShare => '共有する';

  @override
  String get vcNoticeAudioBlocked => '音が止まっています。画面をタップすると鳴ります';

  @override
  String vcNoticeCallFull(int cap) {
    return '通話は満員です($cap 人まで)。配信があれば、配信で聞けます';
  }

  @override
  String get vcNoticeHoldWaiting => '開催までお待ちください。保留音を鳴らしています';

  @override
  String get vcNoticeStarted => '開催が始まりました';

  @override
  String get vcNoticeHoldIdle => '静かなので保留音を鳴らしています';

  @override
  String get vcShareClassImage => '画像';

  @override
  String get vcShareClassFile => 'ファイル';

  @override
  String get vcShareClassTranscript => '文字起こし';

  @override
  String get vcShareStyleCards => 'カード(横スライド)';

  @override
  String get vcShareStyleList => '一覧(レガシー)';

  @override
  String get vcTermsRequired => '利用規約への同意が必要です(ASTell のいちばん上の案内から同意できます)';

  @override
  String get vcClosedByModeration => '運営によりルームが閉鎖されました';

  @override
  String get vcClosedByHost => 'ホストがルームを終了しました';

  @override
  String get vcKickedBanned => 'このルームから BAN されました';

  @override
  String get vcKickedSanctioned => 'アカウントの処置により退出させられました';

  @override
  String get vcKickedByModerator => 'モデレーターにルームから退出させられました';

  @override
  String vcShareHeld(String seconds) {
    return '検閲中: $seconds 秒後に判定して配信されます(アカウントの処置)';
  }

  @override
  String vcShareRejected(String source) {
    return '検閲で却下されました($source)。この発言は配信されていません';
  }

  @override
  String get vcNotInRoom => 'ルームに入っていません';

  @override
  String vcStreamReceiveFailed(String error) {
    return '映像を受けられません: $error';
  }

  @override
  String get vcStreamBlockedByScreenShare => '画面共有中は配信を始められません(共有をやめてから)';

  @override
  String vcStreamStartFailed(String error) {
    return '配信を始められません: $error';
  }

  @override
  String vcStreamClearFailed(String error) {
    return '配信の印を消せませんでした: $error';
  }

  @override
  String get vcScreenShareBlockedByStream => '配信中は画面共有を始められません(配信を止めてから)';

  @override
  String vcScreenShareStartFailed(String error) {
    return '画面共有を始められません: $error';
  }

  @override
  String get vcStreamUnavailable => '配信はまだ使えません(配信サーバーが未設定)';

  @override
  String vcStreamForbidden(String message) {
    return '許可されていません($message)';
  }

  @override
  String get vcTtsNotConfigured => '読み上げバックエンドが未設定です(CENTRAL_TTS_URL)';

  @override
  String get vcLoginRequired => 'RASQ アカウントにログインしてください';

  @override
  String vcCreateUninvite(String name) {
    return '$name の招待をやめる';
  }

  @override
  String vcCreateInvite(String name) {
    return '$name を招待';
  }

  @override
  String get vcCreateCancel => 'キャンセル';

  @override
  String get vcCreateShareAfterOn => '作成後に投稿で共有する(オン)';

  @override
  String get vcCreateShareAfter => '作成後に投稿で共有する';

  @override
  String vcCreateScheduled(String title, String when) {
    return '「$title」を $when に予約しました';
  }

  @override
  String get vcCreateScheduleInPast => '開催予定は今より後にしてください';

  @override
  String vcCreateGenresMax(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'ジャンルは $max 個までです',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateTitleRequired => 'タイトルを入力してください';

  @override
  String vcCreateInviteFailed(String error) {
    return '招待を送れませんでした: $error';
  }

  @override
  String vcCreateFailed(String error) {
    return '作成できませんでした: $error';
  }

  @override
  String get vcCreateSearchAdd => '検索して追加';

  @override
  String get vcCreateHandleHint => '@handle(RASQ アカウント)';

  @override
  String vcCreateHandleNotFound(String handle) {
    return '見つかりませんでした: $handle';
  }

  @override
  String get vcCreateAddInvitee => '招待に追加';

  @override
  String get vcCreateTitleHint => 'タイトル';

  @override
  String get vcCreateInviteFollowers => 'フォロワーを招待';

  @override
  String vcCreateInviteFollowersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'フォロワーを招待($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateWelcomeToggle => '参加時にウェルカムメッセージを表示する';

  @override
  String get vcCreateWelcomeHint => 'ウェルカムメッセージを設定..';

  @override
  String vcCreateGenresLabel(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'ジャンルを選定(最大 $max)',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateGenreHint => 'ジャンルを入力';

  @override
  String get vcCreateGenreAdd => 'ジャンルを追加';

  @override
  String get vcCreateSchedule => '開催を予約する';

  @override
  String get vcCreateScheduleCaption => '予約中は、あなたが入るまで他の人は入れません。';

  @override
  String get vcCreateScheduleCaptionDetail =>
      '予約中はあなた(とモデレーター)が入るまで他の人は参加できません。近日開催の節と共有リンクから開始通知を登録できます。';

  @override
  String get vcCreateSummaryHint => 'ざっくり要約(任意。空なら自動で作ります)';

  @override
  String get vcCreateMicAfterCreate => 'マイク(作成後に切替)';

  @override
  String get vcCreateScheduleButton => '予約';

  @override
  String get vcCreateButton => '作成';

  @override
  String get vcRoomHostPresent => '参加中';

  @override
  String get vcRoomHostBeforeStart => '開催前';

  @override
  String get vcRoomHostAbsent => '不在';

  @override
  String vcRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人が参加しています',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomMembersHostOnly => 'ホストのほかには、まだ誰もいません';

  @override
  String get vcRoomMembersNone => 'まだ誰もいません';

  @override
  String vcRoomMembersRest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '他$count人',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomScreenShown => '共有枠に表示中';

  @override
  String get vcRoomScreenShow => '画面共有を表示';

  @override
  String vcRoomNotYet(String what) {
    return '$what は準備中です';
  }

  @override
  String get vcRoomDeviceSettingsTitle => 'ASTell の設定(この端末)';

  @override
  String get vcRoomEditBar => '下段のボタンの並びを編集';

  @override
  String get vcRoomEditBarSubtitle => '並べ替え / 表示 / 非表示 / プラグインのボタンを追加';

  @override
  String get vcRoomAutoShareLabel => 'チャットの内容を自動で共有欄に出す(ピン留めしなくても)';

  @override
  String get vcRoomShareStyleLabel => '共有欄の表示';

  @override
  String get vcRoomAutoPlayLabel => '自動再生';

  @override
  String get vcRoomAutoPlayScreen => '画面共有が始まったら共有枠に出す';

  @override
  String get vcRoomHoldMusicLabel => '保留音';

  @override
  String get vcRoomHoldMusicDevice => '保留音を鳴らす(この端末)';

  @override
  String get vcRoomDeviceSettingsCaption => 'ルームの設定は、参加後にルームの歯車から変えられます(オーナー)。';

  @override
  String get vcRoomDeviceSettingsCaptionDetail =>
      'ルームごとの設定(参加できる人・読み上げなど)は、参加してからルームの歯車で変えられます(オーナー)。';

  @override
  String get vcRoomClose => '閉じる';

  @override
  String get vcRoomShare => '共有';

  @override
  String get vcRoomHost => 'ホスト';

  @override
  String get vcRoomMembers => '参加メンバー';

  @override
  String get vcRoomLocked => '運営により新しい入室が止められています。';

  @override
  String get vcRoomLockedDetail => '運営により新規入室が停止されています(D-151)。';

  @override
  String get vcRoomRemindOn => '開始を通知します';

  @override
  String get vcRoomWaitForHost => 'ホストが始めるまで参加できません';

  @override
  String get vcRoomRemindOff => '通知を解除';

  @override
  String get vcRoomSummary => 'ざっくり要約';

  @override
  String get vcRoomSummaryPrivate => 'このルームはざっくり要約を公開していません。';

  @override
  String vcRoomWelcome(String message) {
    return 'ようこそ: $message';
  }

  @override
  String get vcRoomMicAfterJoin => 'マイク(参加後に切替)';

  @override
  String get vcRoomCaptions => '字幕';

  @override
  String get vcRoomJoin => '参加';

  @override
  String get vcRoomSettings => '設定';

  @override
  String get vcRoomTabHome => 'ホーム';

  @override
  String get vcRoomTabChat => 'チャット';

  @override
  String get vcRoomTabToc => '目次';

  @override
  String get vcRoomTabRoom => 'ルーム';

  @override
  String get vcRoomLeft => '退出しました';

  @override
  String get vcRoomLeave => '退出';

  @override
  String get vcRoomStreamingScreen => '画面を配信しています';

  @override
  String get vcRoomStreamingCamera => 'カメラで配信しています';

  @override
  String get vcRoomStopSharing => '共有をやめる';

  @override
  String get vcRoomStopStream => '配信を止める';

  @override
  String get vcRoomSpeakerUnmute => 'スピーカーミュート解除';

  @override
  String get vcRoomSpeakerMute => 'スピーカーミュート';

  @override
  String get vcRoomMutedByModerator => 'モデレーターにミュートされています';

  @override
  String get vcRoomMicOpening => 'マイクを準備中(押すとやめる)';

  @override
  String get vcRoomMicOff => 'マイクオフ';

  @override
  String get vcRoomMicOn => 'マイクオン';

  @override
  String get vcRoomScreenShareOff => '画面共有オフ';

  @override
  String get vcRoomFullscreen => '全画面';

  @override
  String get vcRoomCaptionsOff => '字幕オフ';

  @override
  String get vcRoomCaptionsOn => '字幕オン';

  @override
  String get vcRoomShareAsLinkLimited => '公開範囲が限定された投稿なので、リンクとして共有します';

  @override
  String vcRoomShareAsLinkFailed(String error) {
    return '投稿を取れなかったのでリンクとして共有します: $error';
  }

  @override
  String vcRoomPickFileFailed(String error) {
    return 'ファイルを選択できませんでした: $error';
  }

  @override
  String get vcRoomStream => '配信';

  @override
  String vcRoomLiveCardTitle(String kind, String title) {
    return '$kind: $title';
  }

  @override
  String vcRoomPeerScreen(String name) {
    return '$name の画面';
  }

  @override
  String vcRoomPeerScreenTitled(String name, String title) {
    return '$name の画面 — $title';
  }

  @override
  String get vcRoomAllShares => 'すべての共有';

  @override
  String get vcRoomSettingsTitle => 'VC の設定';

  @override
  String get vcRoomModerationLabel => 'モデレーション(オーナー)';

  @override
  String get vcRoomJoinPolicyLabel => '参加できる人';

  @override
  String get vcRoomSharePolicyLabel => '共有(チャットへの投稿)できる人';

  @override
  String vcRoomModeratorsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'モデレーター($count)— メンバーの「…」から追加',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomRemoveModerator => 'モデレーターを外す';

  @override
  String get vcRoomTendencyLabel => '発信傾向';

  @override
  String get vcRoomTendencyFilter => '荒らしの入室を断る(試験中)';

  @override
  String get vcRoomTendencyCaption => 'オンにすると、敵対的と判定された人は入れません。判定はまだ仮のものです。';

  @override
  String get vcRoomTendencyCaptionDetail =>
      '本命は rasq-judge の GoEmotion(発信の感情傾向)で、学習が要るので今はサーバーのダミー判定(表示名に hostile / 荒らし を含む人だけ敵対的)。オンにすると敵対的と判定された人は入室できません。メンバー行の「…」から判定結果を見られます。';

  @override
  String get vcRoomHostStreamLabel => '配信(ホスト)';

  @override
  String get vcRoomStreamCamera => 'カメラで配信する';

  @override
  String get vcRoomStreamScreen => '画面を配信する';

  @override
  String get vcRoomStreamScreenIos => 'iPhone / iPad はこのアプリの画面だけ(ほかのアプリは映りません)';

  @override
  String get vcRoomHostStreamCaption => '映像と声を配信します。通話に入りきらない人も配信で聞けます。';

  @override
  String vcRoomHostStreamCaptionDetail(int cap) {
    return '映像とマイクを配信サーバー(LiveKit)に上げます。参加者は通話の声のまま映像を見られ、通話に入りきらない人($cap 人目より後)は配信であなたの声を聞きます。';
  }

  @override
  String get vcRoomHoldMusicRoom => 'このルームで保留音を許す(オーナー)';

  @override
  String get vcRoomHoldMusicCaption => '開始を待つ間や、しばらく誰も話さないときに鳴ります。';

  @override
  String vcRoomHoldMusicCaptionDetail(int minutes) {
    return '開催予約の開始を待っている間と、全員がマイクを下ろして(画面共有 / 配信も無く)チャットが $minutes 分以上流れていない間に鳴ります。誰かが話し始めるか、チャットが流れると止まります。';
  }

  @override
  String get vcRoomTts => '読み上げ';

  @override
  String get vcRoomTtsUnavailable => '読み上げ(使えません)';

  @override
  String vcRoomTtsDetail(String model) {
    return '読み上げ($model、プリセット音声)';
  }

  @override
  String vcRoomTtsDetailUnavailable(String model) {
    return '読み上げ($model、プリセット音声) — サーバー未設定';
  }

  @override
  String get vcRoomTtsNone => '読み上げなし';

  @override
  String get vcRoomTtsCaptionOwner => '読み上げの声はサーバーで作ります(アプリでの再生は準備中)。';

  @override
  String get vcRoomTtsCaptionGuest => '読み上げ音声はホストが選びます。';

  @override
  String get vcRoomTtsCaptionOwnerDetail =>
      'チャットと共有の読み上げは Central 側で合成します(端末での再生は今後の対応)。';

  @override
  String get vcRoomDiagnosticsLabel => '接続の状態(開発者向け)';

  @override
  String get vcRoomDiagnosticsOpen => '通話 / 配信の接続を見る';

  @override
  String get vcRoomDiagnosticsOpenSubtitle => 'ICE の状態・候補・送受信の量・受けているトラック';

  @override
  String get vcRoomDiagnosticsTitle => '接続の状態';

  @override
  String vcRoomHostStreamTitle(String name) {
    return '$name の配信';
  }

  @override
  String get vcRoomPostViewNotYet => 'この投稿の表示(対応 SNS プラグインが未導入)';

  @override
  String get vcRoomOpen => '開く';

  @override
  String get vcRoomDelete => '削除';

  @override
  String get vcRoomCopied => 'コピーしました';

  @override
  String vcRoomReportWhatShare(String headline) {
    return '共有「$headline」';
  }

  @override
  String get vcRoomPinToFrame => '共有枠に表示';

  @override
  String get vcRoomUnfollow => 'フォロー解除';

  @override
  String get vcRoomFollow => 'フォロー';

  @override
  String get vcRoomUnmute => 'ミュート解除';

  @override
  String get vcRoomModUnmute => '全員向けミュートを解除';

  @override
  String get vcRoomModMute => '全員向けにミュート';

  @override
  String get vcRoomKick => 'キック';

  @override
  String get vcRoomMakeModerator => 'モデレーターにする';

  @override
  String get vcRoomShowTendency => '発信傾向を見る(試験中)';

  @override
  String get vcRoomUnblock => 'ブロック解除';

  @override
  String get vcRoomBlock => 'ブロック';

  @override
  String get vcRoomReport => '通報';

  @override
  String vcRoomTendencyResult(String name, String source, String summary) {
    return '$name の発信傾向($source): $summary';
  }

  @override
  String vcRoomTendencyResultHostile(
    String name,
    String source,
    String summary,
  ) {
    return '$name の発信傾向($source): $summary — 敵対的';
  }

  @override
  String vcRoomUnblocked(String name) {
    return '$name のブロックを解除しました';
  }

  @override
  String vcRoomBlocked(String name) {
    return '$name をブロックしました(発言を隠し、あなたのルームには入れません)';
  }

  @override
  String vcRoomActionFailed(String error) {
    return 'できませんでした: $error';
  }

  @override
  String get vcRoomPinToShares => '共有欄にピン留め';

  @override
  String vcRoomReportWhatChat(String name) {
    return '$name の発言';
  }

  @override
  String get vcRoomShowSummary => 'プレビューにざっくり要約を表示する';

  @override
  String get vcRoomAutoGenre => 'ジャンルを自動選択する';

  @override
  String get vcRoomEditAutoGenres => '自動選択されたジャンルを編集';

  @override
  String get vcRoomGenres => 'ジャンル';

  @override
  String get vcRoomChatEmpty => '話した内容の文字起こしと、チャット・共有がここに並びます。';

  @override
  String vcRoomChatHiddenBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ブロック中のユーザーの発言 $count 件を隠しています',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomTyping => '入力中…';

  @override
  String get vcRoomDraft => '下書き';

  @override
  String get vcRoomTypingLabel => '入力中';

  @override
  String get vcRoomChatActions => 'チャットの操作';

  @override
  String vcRoomTocStart(String title) {
    return '開始: $title';
  }

  @override
  String vcRoomTocShared(String name, String kind, String headline) {
    return '$name が $kind を共有: $headline';
  }

  @override
  String get vcRoomTocCaption => '共有と文字起こしの区切りです。';

  @override
  String vcRoomMembersWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '参加メンバー($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomModerator => 'モデレーター';

  @override
  String get vcRoomCustomPlugins => 'カスタムプラグイン';

  @override
  String vcRoomUpdateFailed(String error) {
    return '設定を更新できませんでした: $error';
  }

  @override
  String get vcRoomShareAction => '共有する';

  @override
  String get vcRoomSendDone => '送信完了する';

  @override
  String vcRoomPeerScreenTap(String name) {
    return '$name の画面(タップで全画面)';
  }

  @override
  String get vcRoomPinnedSharesEmpty => 'ピン留めした共有がここに出ます';

  @override
  String vcRoomCompactShare(String headline) {
    return '共有: $headline';
  }

  @override
  String get vcRoomNoTranscripts => '文字起こしはまだありません';

  @override
  String get vcRoomTranscriptsDisabled => '文字起こしは無効(要約非公開)';

  @override
  String get vcRoomSharesCollapse => '共有を畳む';

  @override
  String get vcRoomSharesExpand => '共有をすべて表示';

  @override
  String vcRoomSharedByPinned(String name) {
    return '$name が共有 ・ 📌';
  }

  @override
  String vcRoomSharedByAuto(String name) {
    return '$name が共有 ・ 自動表示';
  }

  @override
  String vcRoomTranscriptMetaPinned(String name, String time) {
    return '$name ・ $time ・ 📌';
  }

  @override
  String vcRoomTranscriptMetaAuto(String name, String time) {
    return '$name ・ $time ・ 自動表示';
  }

  @override
  String get vcRoomMuted => 'ミュート中';

  @override
  String get vcRoomScreenFrameActions => '共有枠の操作';

  @override
  String vcRoomMemberSelf(String name) {
    return '$name(あなた)';
  }

  @override
  String get vcRoomForceMuted => '強制ミュート';

  @override
  String get vcRoomMemberActions => 'メンバーの操作';

  @override
  String get vcRoomDiagnosticsLogHint =>
      'ブラウザ / Xcode のログにも「astell call:」「astell stream:」で出ます。';

  @override
  String get vcRoomCopy => 'コピー';

  @override
  String vcRoomBansLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'BAN($count)— メンバー行の「…」から',
    );
    return '$_temp0';
  }

  @override
  String vcRoomBansLoadFailed(String error) {
    return 'BAN 一覧を読めませんでした: $error';
  }

  @override
  String get vcRoomUnban => 'BAN を解除';

  @override
  String vcRoomReportBody(String what) {
    return '$what を通報します。RASQ の審査で確認します。';
  }

  @override
  String get vcRoomReportNoteHint => '補足(任意)';

  @override
  String vcRoomReportFailed(String error) {
    return '通報できませんでした: $error';
  }

  @override
  String get vcRoomReportSubmit => '通報する';

  @override
  String get vcRoomReported => '通報しました。審査で確認します';

  @override
  String vcRoomLiveBy(String name, String kind) {
    return '$name が$kind中';
  }
}
