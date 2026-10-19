// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

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
}
