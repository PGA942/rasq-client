import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ja')];

  /// 見守りの判定の強さ(プリセット / タイムライン / 投稿の強さの選択肢)
  ///
  /// In ja, this message translates to:
  /// **'きびしめ'**
  String get childSafeLevelStrict;

  /// 見守りの判定の強さ
  ///
  /// In ja, this message translates to:
  /// **'ふつう'**
  String get childSafeLevelStandard;

  /// 見守りの判定の強さ
  ///
  /// In ja, this message translates to:
  /// **'ゆるめ'**
  String get childSafeLevelMild;

  /// 話題の一覧の見方: どれかの話題に当たるものだけ通す
  ///
  /// In ja, this message translates to:
  /// **'ホワイトリスト'**
  String get childSafeTopicModeAllow;

  /// 話題の一覧の見方: 当たるものを止める
  ///
  /// In ja, this message translates to:
  /// **'ブラックリスト'**
  String get childSafeTopicModeDeny;

  /// 子のプラグインのインストールの範囲の選択肢
  ///
  /// In ja, this message translates to:
  /// **'入れられない'**
  String get childSafeInstallNone;

  /// 子のプラグインのインストールの範囲の選択肢(保護者が名前で選んだものだけ)
  ///
  /// In ja, this message translates to:
  /// **'選んだものだけ'**
  String get childSafeInstallListed;

  /// 子のプラグインのインストールの範囲の選択肢
  ///
  /// In ja, this message translates to:
  /// **'自由'**
  String get childSafeInstallAny;

  /// 子のプラグインのインストールの範囲の選択肢(許す例に近いもの)
  ///
  /// In ja, this message translates to:
  /// **'例に近いもの'**
  String get childSafeInstallExamples;

  /// 保護者の設定の保存の前の確かめ: 有効な面の話題のホワイトリストが空
  ///
  /// In ja, this message translates to:
  /// **'ホワイトリストが空です。話題を 1 つ以上入れるか、ブラックリストにしてください'**
  String get childSafeEmptyWhitelistError;

  /// 保護者の確認の方法
  ///
  /// In ja, this message translates to:
  /// **'マイナンバーカード (JPKI)'**
  String get childSafeMethodJpki;

  /// 保護者の確認の方法
  ///
  /// In ja, this message translates to:
  /// **'自己申告'**
  String get childSafeMethodSelfDeclared;

  /// つなぐ / ログインのコードが見つからない(サーバーの 404)
  ///
  /// In ja, this message translates to:
  /// **'コードが違うか、期限が切れています'**
  String get childSafeErrorCodeInvalid;

  /// 子のアカウントを作るときのハンドルの重複
  ///
  /// In ja, this message translates to:
  /// **'そのハンドルは使われています'**
  String get childSafeErrorHandleTaken;

  /// つなげないアカウント(サーバーの 409)
  ///
  /// In ja, this message translates to:
  /// **'もう見守られている(か、だれかを見守っている)アカウントです'**
  String get childSafeErrorAlreadyLinked;

  /// コードが使えない(サーバーの 410)
  ///
  /// In ja, this message translates to:
  /// **'コードの期限が切れたか、もう使われています。保護者に出し直してもらってください'**
  String get childSafeErrorCodeGone;

  /// 子のログインを端末の理由で断られた
  ///
  /// In ja, this message translates to:
  /// **'この端末ではログインできません'**
  String get childSafeErrorDevice;

  /// 試行の回数の上限(サーバーの 429)
  ///
  /// In ja, this message translates to:
  /// **'試行が多すぎます。しばらく待ってから、やり直してください'**
  String get childSafeErrorTooMany;

  /// RASQ サーバー(Central)の接続先が無いときの誤り
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーの接続先が未設定です'**
  String get childSafeNoServer;

  /// チャイルドセーフの知らせのトーストの末尾。count はほかに届いた知らせの数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{(ほか {count} 件)}}'**
  String childSafeNoticeMore(int count);

  /// 子の端末の知らせのトースト(知らせに題が無いとき)
  ///
  /// In ja, this message translates to:
  /// **'チャイルドセーフ: 保護者の設定を取り直しました'**
  String get childSafeNoticeRefreshed;

  /// 保護者への知らせのトーストのボタン(保護者の画面を開く)
  ///
  /// In ja, this message translates to:
  /// **'見る'**
  String get childSafeNoticeView;

  /// 保護者が止めている機能を使おうとしたときの決まり文句
  ///
  /// In ja, this message translates to:
  /// **'保護者が止めています'**
  String get childSafeBlocked;

  /// 保護者が止めている機能。label は機能の名前(RAi の関数のときは関数の名前)
  ///
  /// In ja, this message translates to:
  /// **'保護者が止めています({label})'**
  String childSafeBlockedWith(String label);

  /// 見守りの時間の範囲。start / end は HH:MM
  ///
  /// In ja, this message translates to:
  /// **'{start}〜{end}'**
  String childSafeTimeRange(String start, String end);

  /// 保護者が設定を決める前の子の端末
  ///
  /// In ja, this message translates to:
  /// **'保護者が設定を決めるまで使えません'**
  String get childSafeLockedUntilSetup;

  /// window は見守りの時間の範囲(21:00〜06:00 など)
  ///
  /// In ja, this message translates to:
  /// **'見守りの時間({window})は DM を使えません'**
  String childSafeWindowNoDm(String window);

  /// No description provided for @childSafeBlockedAstell.
  ///
  /// In ja, this message translates to:
  /// **'保護者が ASTell を止めています'**
  String get childSafeBlockedAstell;

  /// window は見守りの時間の範囲
  ///
  /// In ja, this message translates to:
  /// **'見守りの時間({window})は ASTell を使えません'**
  String childSafeWindowNoAstell(String window);

  /// No description provided for @childSafeBlockedDm.
  ///
  /// In ja, this message translates to:
  /// **'保護者が DM を止めています'**
  String get childSafeBlockedDm;

  /// window は見守りの時間の範囲
  ///
  /// In ja, this message translates to:
  /// **'見守りの時間({window})は通知を見られません'**
  String childSafeWindowNoNotifications(String window);

  /// No description provided for @childSafeBlockedRai.
  ///
  /// In ja, this message translates to:
  /// **'保護者が RAi を止めています'**
  String get childSafeBlockedRai;

  /// No description provided for @childSafeBlockedStore.
  ///
  /// In ja, this message translates to:
  /// **'保護者がプラグインストアを止めています'**
  String get childSafeBlockedStore;

  /// No description provided for @childSafeBlockedSearch.
  ///
  /// In ja, this message translates to:
  /// **'保護者が検索を止めています'**
  String get childSafeBlockedSearch;

  /// No description provided for @childSafeBlockedAddAccount.
  ///
  /// In ja, this message translates to:
  /// **'保護者が SNS アカウントの追加を止めています'**
  String get childSafeBlockedAddAccount;

  /// No description provided for @childSafeBlockedCustomPlugins.
  ///
  /// In ja, this message translates to:
  /// **'保護者がカスタムプラグインを止めています'**
  String get childSafeBlockedCustomPlugins;

  /// No description provided for @childSafeBlockedPlugins.
  ///
  /// In ja, this message translates to:
  /// **'保護者がプラグインを止めています'**
  String get childSafeBlockedPlugins;

  /// window は見守りの時間の範囲
  ///
  /// In ja, this message translates to:
  /// **'見守りの時間({window})は投稿の詳細を開けません'**
  String childSafeWindowNoPostDetail(String window);

  /// 見守りの判定で隠した投稿の詳細を開こうとした
  ///
  /// In ja, this message translates to:
  /// **'この投稿は表示できません'**
  String get childSafePostHidden;

  /// 話題・機能などを並べるときの区切り
  ///
  /// In ja, this message translates to:
  /// **'・'**
  String get childSafeListSeparator;

  /// 箇条書きの 1 行
  ///
  /// In ja, this message translates to:
  /// **'・{text}'**
  String childSafeBullet(String text);

  /// 話題が多くて一部だけ見せるとき。topics は並べた話題
  ///
  /// In ja, this message translates to:
  /// **'{topics} など'**
  String childSafeTopicsEtc(String topics);

  /// 投稿の話題のホワイトリストが空のとき
  ///
  /// In ja, this message translates to:
  /// **'保護者の設定により、いまは投稿を送れません'**
  String get childSafeComposeNoTopicsAllowed;

  /// 投稿の話題のホワイトリストに当たらない。topics は話題(5 つまで)
  ///
  /// In ja, this message translates to:
  /// **'保護者の設定により、決められた話題({topics})の投稿だけ送れます。話題に合うように書いてください'**
  String childSafeComposeTopicsOnly(String topics);

  /// 投稿の話題のブラックリストに当たった。topic は当たった話題
  ///
  /// In ja, this message translates to:
  /// **'保護者の設定により、「{topic}」の話題の投稿は送れません。書き換えてください'**
  String childSafeComposeTopicDenied(String topic);

  /// 本文から引いた語
  ///
  /// In ja, this message translates to:
  /// **'「{text}」'**
  String childSafeQuoted(String text);

  /// 強い言葉で止めた。level は判定の強さ、word は当たった語(「…」の形。無ければ空)
  ///
  /// In ja, this message translates to:
  /// **'保護者の設定({level})により、この表現{word}は送れません。言い換えてください'**
  String childSafeComposeStimulus(String level, String word);

  /// No description provided for @childSafeBlockedThisPlugin.
  ///
  /// In ja, this message translates to:
  /// **'保護者がこのプラグインを止めています'**
  String get childSafeBlockedThisPlugin;

  /// どのプラグインか分からない読み込み方(素の .wasm など)で動かそうとした
  ///
  /// In ja, this message translates to:
  /// **'保護者が選んだプラグインだけ動かせます(この読み込み方では、どのプラグインか確かめられません)'**
  String get childSafeDevPreviewUnknown;

  /// No description provided for @childSafeBlockedInstall.
  ///
  /// In ja, this message translates to:
  /// **'保護者がプラグインのインストールを止めています'**
  String get childSafeBlockedInstall;

  /// No description provided for @childSafeNearDenyPlugin.
  ///
  /// In ja, this message translates to:
  /// **'保護者が止めている例に近いプラグインです'**
  String get childSafeNearDenyPlugin;

  /// No description provided for @childSafeInstallListedOnly.
  ///
  /// In ja, this message translates to:
  /// **'保護者が選んだプラグインだけ入れられます'**
  String get childSafeInstallListedOnly;

  /// No description provided for @childSafeInstallExamplesOnly.
  ///
  /// In ja, this message translates to:
  /// **'保護者が選んだプラグインと、許す例に近いものだけ入れられます'**
  String get childSafeInstallExamplesOnly;

  /// 端末に控えた保護者の設定の署名が合わない
  ///
  /// In ja, this message translates to:
  /// **'控えた制限の署名を確かめられません。オンラインで取り直してください'**
  String get childSafeCacheUnverified;

  /// No description provided for @childSafeNewSettingsUnverified.
  ///
  /// In ja, this message translates to:
  /// **'保護者の新しい設定の署名を確かめられませんでした(前の設定のまま)'**
  String get childSafeNewSettingsUnverified;

  /// No description provided for @childSafeComposeLocked.
  ///
  /// In ja, this message translates to:
  /// **'保護者が設定を決めるまで送れません'**
  String get childSafeComposeLocked;

  /// 1 日に送れる投稿の数に達した。count はその数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{今日はもう {count} 件送りました(保護者が決めた 1 日の数)。また明日}}'**
  String childSafeComposeDailyLimit(int count);

  /// 送る前の加工(テキスト加工プラグイン)のあとの本文で止めた。message は止めた理由
  ///
  /// In ja, this message translates to:
  /// **'{message}(送る前の加工のあとの本文)'**
  String childSafeComposeAfterTransform(String message);

  /// 見守りの状態: 保護者が設定を決める前
  ///
  /// In ja, this message translates to:
  /// **'設定待ち'**
  String get childSafeStatePending;

  /// 保護者の画面の見出し / 入口の行
  ///
  /// In ja, this message translates to:
  /// **'見守る(保護者)'**
  String get childSafeWatchAsGuardian;

  /// 保護者が作った子のアカウントへログインする画面の見出し / 入口
  ///
  /// In ja, this message translates to:
  /// **'保護者からのコードでログイン'**
  String get childSafeLoginWithCode;

  /// 子の端末で保護者のコードでつなぐ画面の見出し / 入口
  ///
  /// In ja, this message translates to:
  /// **'チャイルドモード'**
  String get childSafeChildMode;

  /// 見守っている子の状態: 最新の設定が子の端末に届いている
  ///
  /// In ja, this message translates to:
  /// **'見守り中(端末に届いています)'**
  String get childSafeGuardianStateApplied;

  /// revision は保護者の設定の版の番号
  ///
  /// In ja, this message translates to:
  /// **'見守り中(設定 {revision} はまだ端末に届いていません)'**
  String childSafeGuardianStateNotApplied(int revision);

  /// version は誓約の版(日付)
  ///
  /// In ja, this message translates to:
  /// **'保護者の誓約(版 {version})'**
  String childSafeGuardianPledgeTitle(String version);

  /// pledge は誓約の文(箇条書き)
  ///
  /// In ja, this message translates to:
  /// **'{pledge}\n\n同意すると、マイナンバーカード(デジタル認証アプリ)での確認に進みます(日本にお住まいの方)。'**
  String childSafeGuardianPledgeMessage(String pledge);

  /// No description provided for @childSafeGuardianPledgeConfirm.
  ///
  /// In ja, this message translates to:
  /// **'同意して進む'**
  String get childSafeGuardianPledgeConfirm;

  /// No description provided for @childSafeGuardianCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get childSafeGuardianCancel;

  /// No description provided for @childSafeGuardianLoadError.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした'**
  String get childSafeGuardianLoadError;

  /// No description provided for @childSafeGuardianReload.
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get childSafeGuardianReload;

  /// No description provided for @childSafeGuardianVerifySection.
  ///
  /// In ja, this message translates to:
  /// **'保護者の確認'**
  String get childSafeGuardianVerifySection;

  /// No description provided for @childSafeGuardianVerified.
  ///
  /// In ja, this message translates to:
  /// **'確認済み'**
  String get childSafeGuardianVerified;

  /// No description provided for @childSafeGuardianNotVerified.
  ///
  /// In ja, this message translates to:
  /// **'まだ確認していません'**
  String get childSafeGuardianNotVerified;

  /// No description provided for @childSafeGuardianVerifyIntro.
  ///
  /// In ja, this message translates to:
  /// **'子のアカウントを作る / つなぐ前に、保護者の確認をします(日本はマイナンバーカード)。'**
  String get childSafeGuardianVerifyIntro;

  /// No description provided for @childSafeGuardianVerifyIntroDetail.
  ///
  /// In ja, this message translates to:
  /// **'子のアカウントを作る / つなぐ前に、保護者の確認をします(日本はマイナンバーカード (JPKI)、ほかの国は Web コンソールでの自己申告)。'**
  String get childSafeGuardianVerifyIntroDetail;

  /// No description provided for @childSafeGuardianVerifyJpki.
  ///
  /// In ja, this message translates to:
  /// **'マイナンバーカードで確認する'**
  String get childSafeGuardianVerifyJpki;

  /// No description provided for @childSafeGuardianVerifyJpkiSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'日本にお住まいの方。誓約に同意してから、外のブラウザで開きます'**
  String get childSafeGuardianVerifyJpkiSubtitle;

  /// No description provided for @childSafeGuardianVerifyWeb.
  ///
  /// In ja, this message translates to:
  /// **'Web コンソールで確認する'**
  String get childSafeGuardianVerifyWeb;

  /// No description provided for @childSafeGuardianOpensInBrowser.
  ///
  /// In ja, this message translates to:
  /// **'外のブラウザで開きます'**
  String get childSafeGuardianOpensInBrowser;

  /// count は見守っている子の数、max は上限
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{見守っている子({count} / {max})}}'**
  String childSafeGuardianChildrenSection(int count, int max);

  /// No description provided for @childSafeGuardianNoChildren.
  ///
  /// In ja, this message translates to:
  /// **'まだいません。'**
  String get childSafeGuardianNoChildren;

  /// 子の行の末尾(保護者が作った子のアカウント)
  ///
  /// In ja, this message translates to:
  /// **'・保護者が作成'**
  String get childSafeGuardianCreatedByGuardian;

  /// No description provided for @childSafeGuardianAddSection.
  ///
  /// In ja, this message translates to:
  /// **'子を足す'**
  String get childSafeGuardianAddSection;

  /// No description provided for @childSafeGuardianCreate.
  ///
  /// In ja, this message translates to:
  /// **'子のアカウントを作る'**
  String get childSafeGuardianCreate;

  /// No description provided for @childSafeGuardianCreateSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル / 名前 / 年齢の帯を決めると、子の端末でログインするためのコードが 1 度だけ出ます'**
  String get childSafeGuardianCreateSubtitle;

  /// No description provided for @childSafeGuardianHandleHint.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル(英数字)'**
  String get childSafeGuardianHandleHint;

  /// No description provided for @childSafeGuardianNameHint.
  ///
  /// In ja, this message translates to:
  /// **'表示名'**
  String get childSafeGuardianNameHint;

  /// No description provided for @childSafeGuardianCreateButton.
  ///
  /// In ja, this message translates to:
  /// **'作る'**
  String get childSafeGuardianCreateButton;

  /// No description provided for @childSafeGuardianNewLoginCodeTitle.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} のログインのコード(子の端末の「保護者からのコードでログイン」に入れるか、子の端末のカメラで QR を読む)'**
  String childSafeGuardianNewLoginCodeTitle(String handle);

  /// No description provided for @childSafeGuardianPair.
  ///
  /// In ja, this message translates to:
  /// **'コードでつなぐ'**
  String get childSafeGuardianPair;

  /// No description provided for @childSafeGuardianPairSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'子がもう持っている RASQ アカウントを、子の端末の「チャイルドモード」でつなぎます(10 分・1 回だけ)'**
  String get childSafeGuardianPairSubtitle;

  /// No description provided for @childSafeGuardianPairCodeTitle.
  ///
  /// In ja, this message translates to:
  /// **'つなぐコード(子の端末の「チャイルドモード」に入れるか、子の端末のカメラで QR を読む)'**
  String get childSafeGuardianPairCodeTitle;

  /// time はコードの期限(月/日 時:分)
  ///
  /// In ja, this message translates to:
  /// **'{time} まで。この画面を閉じると、もう出せません(出し直すと前のコードは使えなくなります)。'**
  String childSafeGuardianCodeExpires(String time);

  /// No description provided for @childSafeGuardianCodeQr.
  ///
  /// In ja, this message translates to:
  /// **'コードの QR'**
  String get childSafeGuardianCodeQr;

  /// No description provided for @childSafeGuardianCopy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get childSafeGuardianCopy;

  /// No description provided for @childSafeGuardianCopyLink.
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get childSafeGuardianCopyLink;

  /// No description provided for @childSafeGuardianClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get childSafeGuardianClose;

  /// 保護者の設定のページのタブ(タイムライン)
  ///
  /// In ja, this message translates to:
  /// **'TL'**
  String get childSafeGuardianPageTimeline;

  /// No description provided for @childSafeGuardianPageComposer.
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get childSafeGuardianPageComposer;

  /// No description provided for @childSafeGuardianPageAstell.
  ///
  /// In ja, this message translates to:
  /// **'ASTell'**
  String get childSafeGuardianPageAstell;

  /// No description provided for @childSafeGuardianPagePlugins.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get childSafeGuardianPagePlugins;

  /// No description provided for @childSafeGuardianPageSns.
  ///
  /// In ja, this message translates to:
  /// **'SNS'**
  String get childSafeGuardianPageSns;

  /// No description provided for @childSafeGuardianPageScreenTime.
  ///
  /// In ja, this message translates to:
  /// **'スクリーンタイム'**
  String get childSafeGuardianPageScreenTime;

  /// No description provided for @childSafeGuardianPageOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get childSafeGuardianPageOther;

  /// No description provided for @childSafeGuardianTimeFormatError.
  ///
  /// In ja, this message translates to:
  /// **'時刻は HH:MM で入れてください'**
  String get childSafeGuardianTimeFormatError;

  /// No description provided for @childSafeGuardianConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'この設定を送る'**
  String get childSafeGuardianConfirmTitle;

  /// No description provided for @childSafeGuardianConfirmSend.
  ///
  /// In ja, this message translates to:
  /// **'送る'**
  String get childSafeGuardianConfirmSend;

  /// No description provided for @childSafeGuardianConfirmIntro.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} の端末に、この設定が届きます。'**
  String childSafeGuardianConfirmIntro(String handle);

  /// No description provided for @childSafeGuardianConfirmIntroDetail.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} の端末には、Central が署名した設定が届きます(端末で確かめてから当てはめます)。'**
  String childSafeGuardianConfirmIntroDetail(String handle);

  /// No description provided for @childSafeGuardianSaved.
  ///
  /// In ja, this message translates to:
  /// **'保存しました(設定 {revision})。子の端末に届くと「届いています」になります'**
  String childSafeGuardianSaved(int revision);

  /// band は年齢の帯(13-15 など)
  ///
  /// In ja, this message translates to:
  /// **'{band} の既定を読み込む'**
  String childSafeGuardianImportPreset(String band);

  /// No description provided for @childSafeGuardianImportCopy.
  ///
  /// In ja, this message translates to:
  /// **'ほかの子の設定をコピー'**
  String get childSafeGuardianImportCopy;

  /// No description provided for @childSafeGuardianImportedPreset.
  ///
  /// In ja, this message translates to:
  /// **'{band} の既定を読み込みました'**
  String childSafeGuardianImportedPreset(String band);

  /// No description provided for @childSafeGuardianCopyWhich.
  ///
  /// In ja, this message translates to:
  /// **'どの子の設定をコピーしますか'**
  String get childSafeGuardianCopyWhich;

  /// No description provided for @childSafeGuardianNotSetUp.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} は、まだ設定が済んでいません'**
  String childSafeGuardianNotSetUp(String handle);

  /// No description provided for @childSafeGuardianCopied.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} の設定をコピーしました'**
  String childSafeGuardianCopied(String handle);

  /// what は読み込んだ / コピーした知らせ
  ///
  /// In ja, this message translates to:
  /// **'{what}(まだ保存していません)'**
  String childSafeGuardianNotSavedYet(String what);

  /// No description provided for @childSafeGuardianEnd.
  ///
  /// In ja, this message translates to:
  /// **'見守りを終える'**
  String get childSafeGuardianEnd;

  /// No description provided for @childSafeGuardianEndMessage.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} の制限をすべて外します。子の端末は、次につながったときに外れます。元に戻すには、もう一度つなぎます。'**
  String childSafeGuardianEndMessage(String handle);

  /// No description provided for @childSafeGuardianEndMessageDetail.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} の制限をすべて外します。子の端末は、次に Central に届いたときに外れます。元に戻すには、もう一度つなぎます。'**
  String childSafeGuardianEndMessageDetail(String handle);

  /// No description provided for @childSafeGuardianEndConfirm.
  ///
  /// In ja, this message translates to:
  /// **'終える'**
  String get childSafeGuardianEndConfirm;

  /// No description provided for @childSafeGuardianEndSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'制限をすべて外します'**
  String get childSafeGuardianEndSubtitle;

  /// No description provided for @childSafeGuardianSummarySection.
  ///
  /// In ja, this message translates to:
  /// **'最近の発信内容の要約(14 日)'**
  String get childSafeGuardianSummarySection;

  /// No description provided for @childSafeGuardianLoginSection.
  ///
  /// In ja, this message translates to:
  /// **'子の端末のログイン'**
  String get childSafeGuardianLoginSection;

  /// No description provided for @childSafeGuardianReissue.
  ///
  /// In ja, this message translates to:
  /// **'コードを出し直す'**
  String get childSafeGuardianReissue;

  /// No description provided for @childSafeGuardianReissueSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'子の端末の「保護者からのコードでログイン」に入れるコード(10 分・1 回だけ。前のコードは使えなくなります)'**
  String get childSafeGuardianReissueSubtitle;

  /// No description provided for @childSafeGuardianLoginCodeTitle.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} のログインのコード'**
  String childSafeGuardianLoginCodeTitle(String handle);

  /// No description provided for @childSafeGuardianSaveButton.
  ///
  /// In ja, this message translates to:
  /// **'保存して子の端末へ送る'**
  String get childSafeGuardianSaveButton;

  /// No description provided for @childSafeGuardianImportTooltip.
  ///
  /// In ja, this message translates to:
  /// **'設定をインポート'**
  String get childSafeGuardianImportTooltip;

  /// No description provided for @childSafeGuardianPresetCaption.
  ///
  /// In ja, this message translates to:
  /// **'強さを選ぶと、タイムラインと投稿の判定の強さがそろいます。右の丸いボタンで、{band} の既定やほかの子の設定を読み込めます。'**
  String childSafeGuardianPresetCaption(String band);

  /// No description provided for @childSafeGuardianSummaryEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ報告はありません(子の端末は、終わった日の数を 1 日 1 回送ります)。'**
  String get childSafeGuardianSummaryEmpty;

  /// No description provided for @childSafeGuardianSummaryCaption.
  ///
  /// In ja, this message translates to:
  /// **'送った数 / 止めた数 / 止めた種類だけです(投稿の本文や話題は届きません。送る前の判定はお子さんの端末で行います)。'**
  String get childSafeGuardianSummaryCaption;

  /// 1 日の要約。trips は止めた種類ごとの数の注記(無ければ空)
  ///
  /// In ja, this message translates to:
  /// **'送った {posts}・止めた {blocked}{trips}'**
  String childSafeGuardianSummaryDay(int posts, int blocked, String trips);

  /// No description provided for @childSafeGuardianSummaryTrips.
  ///
  /// In ja, this message translates to:
  /// **'({list})'**
  String childSafeGuardianSummaryTrips(String list);

  /// No description provided for @childSafeGuardianSummaryTripsSeparator.
  ///
  /// In ja, this message translates to:
  /// **'、'**
  String get childSafeGuardianSummaryTripsSeparator;

  /// No description provided for @childSafeGuardianTimelineEnabled.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインを絞る'**
  String get childSafeGuardianTimelineEnabled;

  /// No description provided for @childSafeGuardianTimelineEnabledSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'強い言葉の投稿を見せず、話題で絞ります'**
  String get childSafeGuardianTimelineEnabledSubtitle;

  /// No description provided for @childSafeGuardianTimelineLevel.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの強さ'**
  String get childSafeGuardianTimelineLevel;

  /// No description provided for @childSafeGuardianTimelineTopics.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの話題'**
  String get childSafeGuardianTimelineTopics;

  /// No description provided for @childSafeGuardianTimelineAllowHint.
  ///
  /// In ja, this message translates to:
  /// **'流す話題(語やタグを「,」で区切る)'**
  String get childSafeGuardianTimelineAllowHint;

  /// No description provided for @childSafeGuardianTimelineDenyHint.
  ///
  /// In ja, this message translates to:
  /// **'見せない話題(語やタグを「,」で区切る)'**
  String get childSafeGuardianTimelineDenyHint;

  /// No description provided for @childSafeGuardianTimelineAllowNote.
  ///
  /// In ja, this message translates to:
  /// **'ホワイトリスト: どれかの話題に当たる投稿だけが、タイムラインに流れます。'**
  String get childSafeGuardianTimelineAllowNote;

  /// No description provided for @childSafeGuardianTimelineDenyNote.
  ///
  /// In ja, this message translates to:
  /// **'ブラックリスト: 当たる投稿を見せません(空 = 話題では絞りません)。'**
  String get childSafeGuardianTimelineDenyNote;

  /// No description provided for @childSafeGuardianComposerEnabled.
  ///
  /// In ja, this message translates to:
  /// **'投稿を判定する'**
  String get childSafeGuardianComposerEnabled;

  /// No description provided for @childSafeGuardianComposerEnabledSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'強い言葉と話題で、送る前に止めます(当たった語に印を付けて止める)'**
  String get childSafeGuardianComposerEnabledSubtitle;

  /// No description provided for @childSafeGuardianComposerLevel.
  ///
  /// In ja, this message translates to:
  /// **'投稿の強さ'**
  String get childSafeGuardianComposerLevel;

  /// No description provided for @childSafeGuardianPostsPerDayHint.
  ///
  /// In ja, this message translates to:
  /// **'1 日に送れる投稿の数(空 = 決めない、0〜1000)'**
  String get childSafeGuardianPostsPerDayHint;

  /// No description provided for @childSafeGuardianComposerTopics.
  ///
  /// In ja, this message translates to:
  /// **'投稿の話題'**
  String get childSafeGuardianComposerTopics;

  /// No description provided for @childSafeGuardianComposerAllowHint.
  ///
  /// In ja, this message translates to:
  /// **'送れる話題(語やタグを「,」で区切る)'**
  String get childSafeGuardianComposerAllowHint;

  /// No description provided for @childSafeGuardianComposerDenyHint.
  ///
  /// In ja, this message translates to:
  /// **'送れない話題(語やタグを「,」で区切る)'**
  String get childSafeGuardianComposerDenyHint;

  /// No description provided for @childSafeGuardianComposerAllowNote.
  ///
  /// In ja, this message translates to:
  /// **'ホワイトリスト: どれかの話題に当たる投稿だけ送れます(DM には当てません)。'**
  String get childSafeGuardianComposerAllowNote;

  /// No description provided for @childSafeGuardianComposerDenyNote.
  ///
  /// In ja, this message translates to:
  /// **'ブラックリスト: 当たる投稿は送れません(空 = 話題では止めません。DM には当てません)。'**
  String get childSafeGuardianComposerDenyNote;

  /// No description provided for @childSafeGuardianAstellCaption.
  ///
  /// In ja, this message translates to:
  /// **'ASTell(ルームの通話・チャット・共有)で、子ができること。'**
  String get childSafeGuardianAstellCaption;

  /// No description provided for @childSafeGuardianInstallSection.
  ///
  /// In ja, this message translates to:
  /// **'インストール'**
  String get childSafeGuardianInstallSection;

  /// No description provided for @childSafeGuardianInstallCaption.
  ///
  /// In ja, this message translates to:
  /// **'子が自分で入れられる範囲。プラグインは増えていくので、ひとつずつではなく、下の「例」で大まかに決めます。'**
  String get childSafeGuardianInstallCaption;

  /// No description provided for @childSafeGuardianNamedSection.
  ///
  /// In ja, this message translates to:
  /// **'名前で許しているプラグイン'**
  String get childSafeGuardianNamedSection;

  /// No description provided for @childSafeGuardianNamedNone.
  ///
  /// In ja, this message translates to:
  /// **'ありません。'**
  String get childSafeGuardianNamedNone;

  /// No description provided for @childSafeGuardianNamedCaption.
  ///
  /// In ja, this message translates to:
  /// **'ここにあるものは、止める例に近くても使えます(✕ で外す)。'**
  String get childSafeGuardianNamedCaption;

  /// No description provided for @childSafeGuardianRemove.
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get childSafeGuardianRemove;

  /// No description provided for @childSafeGuardianAddIdHint.
  ///
  /// In ja, this message translates to:
  /// **'id で足す(例: jp.example.quiz)'**
  String get childSafeGuardianAddIdHint;

  /// No description provided for @childSafeGuardianAddIdButton.
  ///
  /// In ja, this message translates to:
  /// **'足す'**
  String get childSafeGuardianAddIdButton;

  /// No description provided for @childSafeGuardianIdShapeError.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの id の形ではありません(英小文字・数字・「.」「_」「-」、例: jp.example.quiz)'**
  String get childSafeGuardianIdShapeError;

  /// No description provided for @childSafeGuardianSnsCaption.
  ///
  /// In ja, this message translates to:
  /// **'子が使ってよい SNS の種類とサーバー(あなたのバンドルから)。サーバーを選ばなければ、その種類ならどこでも。保護者の SNS のログインは貸しません。'**
  String get childSafeGuardianSnsCaption;

  /// No description provided for @childSafeGuardianSnsAdd.
  ///
  /// In ja, this message translates to:
  /// **'子が SNS アカウントを足せる'**
  String get childSafeGuardianSnsAdd;

  /// No description provided for @childSafeGuardianTimeEnabled.
  ///
  /// In ja, this message translates to:
  /// **'見守りの時間'**
  String get childSafeGuardianTimeEnabled;

  /// No description provided for @childSafeGuardianTimeEnabledSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'その間は、1 本のタイムラインになります(子の端末の時計)'**
  String get childSafeGuardianTimeEnabledSubtitle;

  /// No description provided for @childSafeGuardianTimeStartHint.
  ///
  /// In ja, this message translates to:
  /// **'始まり 21:00'**
  String get childSafeGuardianTimeStartHint;

  /// No description provided for @childSafeGuardianTimeEndHint.
  ///
  /// In ja, this message translates to:
  /// **'終わり 06:00'**
  String get childSafeGuardianTimeEndHint;

  /// No description provided for @childSafeGuardianTimeRangeSeparator.
  ///
  /// In ja, this message translates to:
  /// **'〜'**
  String get childSafeGuardianTimeRangeSeparator;

  /// No description provided for @childSafeGuardianTimeLegacyNote.
  ///
  /// In ja, this message translates to:
  /// **'いまの設定は、以前の形の「その間は何も流さない」です。この形は新しく保存できないので、流す話題を入れるか、ブラックリストにしてから保存してください。'**
  String get childSafeGuardianTimeLegacyNote;

  /// No description provided for @childSafeGuardianTimeTopics.
  ///
  /// In ja, this message translates to:
  /// **'その間の話題'**
  String get childSafeGuardianTimeTopics;

  /// No description provided for @childSafeGuardianTimeAllowHint.
  ///
  /// In ja, this message translates to:
  /// **'その間に流す話題(語やタグを「,」で区切る)'**
  String get childSafeGuardianTimeAllowHint;

  /// No description provided for @childSafeGuardianTimeDenyHint.
  ///
  /// In ja, this message translates to:
  /// **'その間に流さない話題(語やタグを「,」で区切る)'**
  String get childSafeGuardianTimeDenyHint;

  /// No description provided for @childSafeGuardianTimeAllowNote.
  ///
  /// In ja, this message translates to:
  /// **'ホワイトリスト: その間は、どれかの話題に当たる投稿だけが流れます。'**
  String get childSafeGuardianTimeAllowNote;

  /// No description provided for @childSafeGuardianTimeDenyNote.
  ///
  /// In ja, this message translates to:
  /// **'ブラックリスト: その間は、当たる投稿を流しません(空 = 話題では絞りません)。'**
  String get childSafeGuardianTimeDenyNote;

  /// No description provided for @childSafeGuardianHideNotifications.
  ///
  /// In ja, this message translates to:
  /// **'通知を隠す'**
  String get childSafeGuardianHideNotifications;

  /// No description provided for @childSafeGuardianHidePostDetail.
  ///
  /// In ja, this message translates to:
  /// **'投稿の詳細を開かせない'**
  String get childSafeGuardianHidePostDetail;

  /// No description provided for @childSafeGuardianHideDm.
  ///
  /// In ja, this message translates to:
  /// **'DM を隠す'**
  String get childSafeGuardianHideDm;

  /// No description provided for @childSafeGuardianRaiEnabled.
  ///
  /// In ja, this message translates to:
  /// **'RAi を使える'**
  String get childSafeGuardianRaiEnabled;

  /// まだ効かない RAi の関数のまとまりの補足
  ///
  /// In ja, this message translates to:
  /// **'準備中(いまは効きません)'**
  String get childSafeGuardianRaiComingSoon;

  /// No description provided for @childSafeGuardianRaiAutomation.
  ///
  /// In ja, this message translates to:
  /// **'関数での自動化'**
  String get childSafeGuardianRaiAutomation;

  /// No description provided for @childSafeGuardianRaiAutomationSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'オフなら、案内(指差し)だけで進めます'**
  String get childSafeGuardianRaiAutomationSubtitle;

  /// No description provided for @childSafeGuardianSearchSection.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get childSafeGuardianSearchSection;

  /// No description provided for @childSafeGuardianFeaturesSection.
  ///
  /// In ja, this message translates to:
  /// **'機能'**
  String get childSafeGuardianFeaturesSection;

  /// No description provided for @childSafeGuardianExamplesTitlePlugins.
  ///
  /// In ja, this message translates to:
  /// **'例で決める(プラグイン)'**
  String get childSafeGuardianExamplesTitlePlugins;

  /// No description provided for @childSafeGuardianExamplesTitleTl.
  ///
  /// In ja, this message translates to:
  /// **'例で決める(クリップ / リスト)'**
  String get childSafeGuardianExamplesTitleTl;

  /// No description provided for @childSafeGuardianExamplesCaptionPlugins.
  ///
  /// In ja, this message translates to:
  /// **'「こういうプラグインは許す / 止める」を例で選びます。子の端末は、プラグインの名前・説明が例に近いかで決めます。止める例に近いものは「自由」でも使えません。「例に近いもの」にすると、名前で許したものと、許す例に近いものを使えます。'**
  String get childSafeGuardianExamplesCaptionPlugins;

  /// No description provided for @childSafeGuardianExamplesCaptionTl.
  ///
  /// In ja, this message translates to:
  /// **'「こういうものは許す / 止める」を、あなたの最近のアクション / クリップ / リストから選びます。子のクリップ / リストのうち、中身が止める例に近いものは、一覧にもタイムラインにも出ません。'**
  String get childSafeGuardianExamplesCaptionTl;

  /// No description provided for @childSafeGuardianPickPlugins.
  ///
  /// In ja, this message translates to:
  /// **'例を選ぶ(プラグイン / ストア)'**
  String get childSafeGuardianPickPlugins;

  /// No description provided for @childSafeGuardianPickTl.
  ///
  /// In ja, this message translates to:
  /// **'例を選ぶ(最近のアクション / クリップ / リスト)'**
  String get childSafeGuardianPickTl;

  /// No description provided for @childSafeGuardianPickCounts.
  ///
  /// In ja, this message translates to:
  /// **'許す例 {allow} / 止める例 {deny}'**
  String childSafeGuardianPickCounts(int allow, int deny);

  /// No description provided for @childSafeGuardianPickTitlePlugins.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの例(@{handle})'**
  String childSafeGuardianPickTitlePlugins(String handle);

  /// No description provided for @childSafeGuardianPickTitleTl.
  ///
  /// In ja, this message translates to:
  /// **'TL の例(@{handle})'**
  String childSafeGuardianPickTitleTl(String handle);

  /// No description provided for @childSafeGuardianAllowLabel.
  ///
  /// In ja, this message translates to:
  /// **'許す例'**
  String get childSafeGuardianAllowLabel;

  /// No description provided for @childSafeGuardianDenyLabel.
  ///
  /// In ja, this message translates to:
  /// **'止める例'**
  String get childSafeGuardianDenyLabel;

  /// No description provided for @childSafeGuardianPickIntroPlugins.
  ///
  /// In ja, this message translates to:
  /// **'中身を見て、子に「許す例」/「止める例」を選びます(右 / 左スワイプでも)。子の端末は、新しいプラグインを例との近さで分けます。'**
  String get childSafeGuardianPickIntroPlugins;

  /// No description provided for @childSafeGuardianPickIntroTl.
  ///
  /// In ja, this message translates to:
  /// **'中身を見て、子に「許す例」/「止める例」を選びます(右 / 左スワイプでも)。子の端末は、クリップ / リストを例との近さで分けます。'**
  String get childSafeGuardianPickIntroTl;

  /// 見守られているアカウントの印
  ///
  /// In ja, this message translates to:
  /// **'見守り中'**
  String get childSafeScreensBadge;

  /// 見守りの時間の帯(シェルの上)。window は時間の範囲、detail は流れる話題の説明(無ければ空)
  ///
  /// In ja, this message translates to:
  /// **'見守りの時間({window})です。{detail}'**
  String childSafeScreensWindowBanner(String window, String detail);

  /// No description provided for @childSafeScreensWindowNothing.
  ///
  /// In ja, this message translates to:
  /// **'投稿は流れません'**
  String get childSafeScreensWindowNothing;

  /// No description provided for @childSafeScreensWindowAllowOnly.
  ///
  /// In ja, this message translates to:
  /// **'「{topics}」の話題だけが流れます'**
  String childSafeScreensWindowAllowOnly(String topics);

  /// No description provided for @childSafeScreensWindowDenied.
  ///
  /// In ja, this message translates to:
  /// **'「{topics}」の話題は流れません'**
  String childSafeScreensWindowDenied(String topics);

  /// 止めている画面の代わりに出す表示の補足
  ///
  /// In ja, this message translates to:
  /// **'見守りの設定は保護者が決めています'**
  String get childSafeScreensBlockedHint;

  /// No description provided for @childSafeScreensHubTitle.
  ///
  /// In ja, this message translates to:
  /// **'チャイルドセーフ'**
  String get childSafeScreensHubTitle;

  /// No description provided for @childSafeScreensHubIntro.
  ///
  /// In ja, this message translates to:
  /// **'保護者が、子のアカウントの使い方を決めます。保護者に届くのは数と止めた種類だけで、投稿の本文は送りません。'**
  String get childSafeScreensHubIntro;

  /// No description provided for @childSafeScreensHubIntroDetail.
  ///
  /// In ja, this message translates to:
  /// **'保護者の RASQ アカウントが、子の RASQ アカウントの使い方を決めます。投稿の判定はこの端末の中で行い、保護者に届くのは、送った数と止めた数と、送る前に止めた種類だけです(投稿の本文や話題は送りません)。'**
  String get childSafeScreensHubIntroDetail;

  /// No description provided for @childSafeScreensHubManagedSection.
  ///
  /// In ja, this message translates to:
  /// **'見守られています'**
  String get childSafeScreensHubManagedSection;

  /// No description provided for @childSafeScreensHubParent.
  ///
  /// In ja, this message translates to:
  /// **'保護者'**
  String get childSafeScreensHubParent;

  /// No description provided for @childSafeScreensHubState.
  ///
  /// In ja, this message translates to:
  /// **'状態'**
  String get childSafeScreensHubState;

  /// revision は保護者の設定の版の番号
  ///
  /// In ja, this message translates to:
  /// **'見守り中(設定 {revision})'**
  String childSafeScreensHubStateActive(int revision);

  /// No description provided for @childSafeScreensHubOffline.
  ///
  /// In ja, this message translates to:
  /// **'いまはサーバーに届きません。前の設定のまま見守ります。'**
  String get childSafeScreensHubOffline;

  /// No description provided for @childSafeScreensHubRefresh.
  ///
  /// In ja, this message translates to:
  /// **'保護者の設定を取り直す'**
  String get childSafeScreensHubRefresh;

  /// No description provided for @childSafeScreensHubAsGuardian.
  ///
  /// In ja, this message translates to:
  /// **'保護者として'**
  String get childSafeScreensHubAsGuardian;

  /// method は保護者の確認の方法
  ///
  /// In ja, this message translates to:
  /// **'確認済み({method})。子のアカウントを作る / つなぐ / 設定'**
  String childSafeScreensHubGuardianVerified(String method);

  /// No description provided for @childSafeScreensHubGuardianUnverified.
  ///
  /// In ja, this message translates to:
  /// **'保護者の確認は Web コンソールで(日本はマイナンバーカード、ほかは自己申告)'**
  String get childSafeScreensHubGuardianUnverified;

  /// No description provided for @childSafeScreensHubAsChild.
  ///
  /// In ja, this message translates to:
  /// **'子として'**
  String get childSafeScreensHubAsChild;

  /// No description provided for @childSafeScreensHubChildModeLogin.
  ///
  /// In ja, this message translates to:
  /// **'保護者からのコードでログインします'**
  String get childSafeScreensHubChildModeLogin;

  /// No description provided for @childSafeScreensHubChildModePair.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントを、保護者のコードでつなぎます'**
  String get childSafeScreensHubChildModePair;

  /// No description provided for @childSafeScreensHubLoginSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'保護者が作った子のアカウントに入ります'**
  String get childSafeScreensHubLoginSubtitle;

  /// No description provided for @childSafeScreensHubThisDevice.
  ///
  /// In ja, this message translates to:
  /// **'この端末'**
  String get childSafeScreensHubThisDevice;

  /// No description provided for @childSafeScreensHubSafety.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーとセーフモード'**
  String get childSafeScreensHubSafety;

  /// No description provided for @childSafeScreensHubSafetyManaged.
  ///
  /// In ja, this message translates to:
  /// **'見守り中は、閲覧注意のメディアを必ず隠します(変えられません)'**
  String get childSafeScreensHubSafetyManaged;

  /// No description provided for @childSafeScreensHubSafetyNormal.
  ///
  /// In ja, this message translates to:
  /// **'閲覧注意メディアの扱い'**
  String get childSafeScreensHubSafetyNormal;

  /// 見守りの要約の行の話題の注記。label は「流す話題」など、topics は並べた話題
  ///
  /// In ja, this message translates to:
  /// **'({label}: {topics})'**
  String childSafeScreensTopicsNote(String label, String topics);

  /// No description provided for @childSafeScreensTopicsNone.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get childSafeScreensTopicsNone;

  /// No description provided for @childSafeScreensTopicsShown.
  ///
  /// In ja, this message translates to:
  /// **'流す話題'**
  String get childSafeScreensTopicsShown;

  /// No description provided for @childSafeScreensTopicsHidden.
  ///
  /// In ja, this message translates to:
  /// **'見せない話題'**
  String get childSafeScreensTopicsHidden;

  /// No description provided for @childSafeScreensTopicsSendable.
  ///
  /// In ja, this message translates to:
  /// **'送れる話題'**
  String get childSafeScreensTopicsSendable;

  /// No description provided for @childSafeScreensTopicsUnsendable.
  ///
  /// In ja, this message translates to:
  /// **'送れない話題'**
  String get childSafeScreensTopicsUnsendable;

  /// No description provided for @childSafeScreensTopicsNotShown.
  ///
  /// In ja, this message translates to:
  /// **'流さない話題'**
  String get childSafeScreensTopicsNotShown;

  /// 見守りの要約の行。level は判定の強さ、note は話題の注記(無ければ空)
  ///
  /// In ja, this message translates to:
  /// **'タイムライン: {level}{note}'**
  String childSafeScreensSummaryTimeline(String level, String note);

  /// No description provided for @childSafeScreensSummaryComposer.
  ///
  /// In ja, this message translates to:
  /// **'投稿の判定: {level}{note}'**
  String childSafeScreensSummaryComposer(String level, String note);

  /// No description provided for @childSafeScreensSummaryPostsPerDay.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{1 日に送れる投稿: {count} 件}}'**
  String childSafeScreensSummaryPostsPerDay(int count);

  /// window は時間の範囲、note は話題の注記
  ///
  /// In ja, this message translates to:
  /// **'見守りの時間: {window}{note}'**
  String childSafeScreensSummaryTime(String window, String note);

  /// No description provided for @childSafeScreensSummaryTimeNothing.
  ///
  /// In ja, this message translates to:
  /// **'(投稿は流れません)'**
  String get childSafeScreensSummaryTimeNothing;

  /// kinds は SNS の種類(または「どれでも」)、servers はサーバーの注記、noAdd は追加できないときの注記
  ///
  /// In ja, this message translates to:
  /// **'使える SNS: {kinds}{servers}{noAdd}'**
  String childSafeScreensSummarySns(String kinds, String servers, String noAdd);

  /// No description provided for @childSafeScreensSummaryAny.
  ///
  /// In ja, this message translates to:
  /// **'どれでも'**
  String get childSafeScreensSummaryAny;

  /// No description provided for @childSafeScreensSummarySnsServers.
  ///
  /// In ja, this message translates to:
  /// **'({servers})'**
  String childSafeScreensSummarySnsServers(String servers);

  /// No description provided for @childSafeScreensSummarySnsNoAdd.
  ///
  /// In ja, this message translates to:
  /// **'、追加はできません'**
  String get childSafeScreensSummarySnsNoAdd;

  /// No description provided for @childSafeScreensSummaryFeaturesOff.
  ///
  /// In ja, this message translates to:
  /// **'止めている機能: {list}'**
  String childSafeScreensSummaryFeaturesOff(String list);

  /// No description provided for @childSafeScreensSummarySearchOff.
  ///
  /// In ja, this message translates to:
  /// **'止めている検索: {list}'**
  String childSafeScreensSummarySearchOff(String list);

  /// scope は使えるプラグインの範囲、install はインストールの範囲
  ///
  /// In ja, this message translates to:
  /// **'プラグイン: {scope}・インストールは{install}'**
  String childSafeScreensSummaryPlugins(String scope, String install);

  /// No description provided for @childSafeScreensSummaryPluginsExamples.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{選んだ {count} 個と、許す例に近いもの}}'**
  String childSafeScreensSummaryPluginsExamples(int count);

  /// No description provided for @childSafeScreensSummaryPluginsListed.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{選んだ {count} 個だけ}}'**
  String childSafeScreensSummaryPluginsListed(int count);

  /// No description provided for @childSafeScreensSummaryExamples.
  ///
  /// In ja, this message translates to:
  /// **'例: 許す例 {allow} / 止める例 {deny}(止める例に近いプラグイン / クリップ / リストは出ません)'**
  String childSafeScreensSummaryExamples(int allow, int deny);

  /// count は使える関数のまとまりの数、noAuto は自動化なしの注記(無ければ空)
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{RAi: {count} 種類の関数{noAuto}}}'**
  String childSafeScreensSummaryRai(int count, String noAuto);

  /// No description provided for @childSafeScreensSummaryRaiNoAuto.
  ///
  /// In ja, this message translates to:
  /// **'(自動化なし)'**
  String get childSafeScreensSummaryRaiNoAuto;

  /// No description provided for @childSafeScreensSummaryRaiOff.
  ///
  /// In ja, this message translates to:
  /// **'RAi: 使えません'**
  String get childSafeScreensSummaryRaiOff;

  /// リンクから開いたときの注意。action は押すボタンの名前
  ///
  /// In ja, this message translates to:
  /// **'リンク(QR)からコードを入れました。自分の保護者から受け取ったものか確かめてから「{action}」を押してください。知らない人のリンクなら、押さずに閉じてください。'**
  String childSafeScreensFromLink(String action);

  /// No description provided for @childSafeScreensPaired.
  ///
  /// In ja, this message translates to:
  /// **'保護者とつなぎました。保護者が設定を決めるまで待ってください'**
  String get childSafeScreensPaired;

  /// No description provided for @childSafeScreensPairNotLoggedIn.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインしていません。保護者が作ったアカウントなら、保護者からのコードでログインします。'**
  String get childSafeScreensPairNotLoggedIn;

  /// No description provided for @childSafeScreensPairExistingLogin.
  ///
  /// In ja, this message translates to:
  /// **'既存の RASQ アカウントにログイン'**
  String get childSafeScreensPairExistingLogin;

  /// No description provided for @childSafeScreensPairIntro.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} を保護者の見守りにつなぎます。保護者の画面に出ているコード(8 字)を入れてください。つないだら、保護者が設定を決めるまで使えません。'**
  String childSafeScreensPairIntro(String handle);

  /// No description provided for @childSafeScreensPairIntroDetail.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} を、保護者の見守りにつなぎます。保護者の画面(アプリか Web コンソール)に出ているコード(8 字、例 ABCD-EFGH)を入れてください。つないだら、保護者が設定を決めるまでアプリは使えません。'**
  String childSafeScreensPairIntroDetail(String handle);

  /// No description provided for @childSafeScreensPairButton.
  ///
  /// In ja, this message translates to:
  /// **'つなぐ'**
  String get childSafeScreensPairButton;

  /// No description provided for @childSafeScreensPairQrHint.
  ///
  /// In ja, this message translates to:
  /// **'保護者の画面の QR を、この端末のカメラアプリで読んでもつなげます。'**
  String get childSafeScreensPairQrHint;

  /// No description provided for @childSafeScreensPairQrHintDetail.
  ///
  /// In ja, this message translates to:
  /// **'保護者の画面の QR は、この端末のカメラアプリで読むと、コードが入った状態でこの画面が開きます。リンク(rasq://child-safe/pair?code=…)を貼り付けても、つなげます。'**
  String get childSafeScreensPairQrHintDetail;

  /// No description provided for @childSafeScreensPairNoQr.
  ///
  /// In ja, this message translates to:
  /// **'この端末では QR を読めません。コードを入れてください。'**
  String get childSafeScreensPairNoQr;

  /// No description provided for @childSafeScreensPairNoQrDetail.
  ///
  /// In ja, this message translates to:
  /// **'この端末では QR を読めません。コードを入れるか、リンク(rasq://child-safe/pair?code=…)を貼り付けてください。'**
  String get childSafeScreensPairNoQrDetail;

  /// No description provided for @childSafeScreensLoginFailed.
  ///
  /// In ja, this message translates to:
  /// **'ログインできませんでした'**
  String get childSafeScreensLoginFailed;

  /// device は端末の名前
  ///
  /// In ja, this message translates to:
  /// **'@{handle} にログインしました({device})'**
  String childSafeScreensLoggedIn(String handle, String device);

  /// No description provided for @childSafeScreensLoginIntro.
  ///
  /// In ja, this message translates to:
  /// **'保護者がアプリで子のアカウントを作ると、1 度だけ使えるコードが出ます。そのコードを入れると、この端末がそのアカウントになります。この端末の SNS アカウントは引き継ぎません。'**
  String get childSafeScreensLoginIntro;

  /// No description provided for @childSafeScreensLoginCodeHint.
  ///
  /// In ja, this message translates to:
  /// **'ログインのコード'**
  String get childSafeScreensLoginCodeHint;

  /// No description provided for @childSafeScreensLoginButton.
  ///
  /// In ja, this message translates to:
  /// **'ログイン'**
  String get childSafeScreensLoginButton;

  /// No description provided for @childSafeScreensPendingUnverifiedTitle.
  ///
  /// In ja, this message translates to:
  /// **'保護者の設定を確かめられません'**
  String get childSafeScreensPendingUnverifiedTitle;

  /// No description provided for @childSafeScreensPendingTitle.
  ///
  /// In ja, this message translates to:
  /// **'保護者が設定を決めるまで待ってください'**
  String get childSafeScreensPendingTitle;

  /// No description provided for @childSafeScreensPendingSignatureMismatch.
  ///
  /// In ja, this message translates to:
  /// **'設定の署名が合いません。'**
  String get childSafeScreensPendingSignatureMismatch;

  /// parent は保護者の名前か @ハンドル
  ///
  /// In ja, this message translates to:
  /// **'{parent} と見守りでつながっています。{parent} が使い方を決めると、使えるようになります。'**
  String childSafeScreensPendingBody(String parent);

  /// 保護者の名前が分からないときの呼び方
  ///
  /// In ja, this message translates to:
  /// **'保護者'**
  String get childSafeScreensPendingParent;

  /// No description provided for @childSafeScreensPendingOffline.
  ///
  /// In ja, this message translates to:
  /// **'いまはサーバーに届きません。'**
  String get childSafeScreensPendingOffline;

  /// No description provided for @childSafeScreensPendingRefresh.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get childSafeScreensPendingRefresh;

  /// No description provided for @childSafeScreensPendingLogout.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get childSafeScreensPendingLogout;

  /// No description provided for @childSafeScreensPendingRasqLogin.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログイン'**
  String get childSafeScreensPendingRasqLogin;

  /// RASQ リストのページの右上のボタンの説明と、押したあとの知らせの見出し。このリストをホームのタイムラインの取り込み元に足す
  ///
  /// In ja, this message translates to:
  /// **'タイムラインに取り込む'**
  String get collectionsImportToTimeline;

  /// RASQ リスト / クリップのページを開いたが、無かったとき
  ///
  /// In ja, this message translates to:
  /// **'見つかりません'**
  String get collectionsNotFound;

  /// RASQ リスト / クリップが見つからないときの補足
  ///
  /// In ja, this message translates to:
  /// **'消されたか、非公開になっています'**
  String get collectionsNotFoundHint;

  /// RASQ リスト / クリップのページを読めなかったときの、もう一度読むボタン
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get collectionsReload;

  /// 見守り(チャイルドセーフ)で、保護者が止めた内容に近い RASQ リストを開いたとき
  ///
  /// In ja, this message translates to:
  /// **'保護者がこのリストを止めています'**
  String get collectionsBlockedList;

  /// 見守り(チャイルドセーフ)で、保護者が止めた内容に近い RASQ クリップを開いたとき
  ///
  /// In ja, this message translates to:
  /// **'保護者がこのクリップを止めています'**
  String get collectionsBlockedClip;

  /// RASQ リスト / クリップのページの … のメニュー: 共有リンクをコピー
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get collectionsMenuCopyLink;

  /// … のメニュー: 中身(投稿)を SNS からいま取り直す
  ///
  /// In ja, this message translates to:
  /// **'いま取り直す'**
  String get collectionsMenuRefresh;

  /// … のメニュー: 公開している RASQ リストを非公開にする(作った人だけ)
  ///
  /// In ja, this message translates to:
  /// **'非公開にする'**
  String get collectionsMenuMakePrivate;

  /// … のメニュー: 非公開の RASQ リストを公開する(作った人だけ)
  ///
  /// In ja, this message translates to:
  /// **'公開する'**
  String get collectionsMenuMakePublic;

  /// … のメニュー: RASQ リストの名前と説明を変える(作った人だけ)
  ///
  /// In ja, this message translates to:
  /// **'名前と説明を変更'**
  String get collectionsMenuRename;

  /// … のメニュー: RASQ リストを消す(作った人だけ)
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get collectionsMenuDelete;

  /// … のメニュー: 公開した RASQ クリップの公開をやめる(クリップは端末に残る)
  ///
  /// In ja, this message translates to:
  /// **'公開をやめる'**
  String get collectionsMenuUnpublish;

  /// 共有リンクをコピーしたときの知らせ
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピーしました'**
  String get collectionsLinkCopied;

  /// 「いま取り直す」で取り直せなかったときの知らせ
  ///
  /// In ja, this message translates to:
  /// **'取り直せませんでした'**
  String get collectionsRefreshFailed;

  /// 「いま取り直す」で取り直したときの知らせ
  ///
  /// In ja, this message translates to:
  /// **'取り直しました'**
  String get collectionsRefreshed;

  /// RASQ リストの名前と説明を変えるシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'名前と説明'**
  String get collectionsRenameTitle;

  /// 名前と説明を変えるシートの決定のボタン
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get collectionsSave;

  /// 名前と説明を変えるシートの、名前の欄の薄い文字
  ///
  /// In ja, this message translates to:
  /// **'名前'**
  String get collectionsNameHint;

  /// RASQ リストの説明の欄の薄い文字(書かなくてよい)
  ///
  /// In ja, this message translates to:
  /// **'説明(任意)'**
  String get collectionsDescriptionHint;

  /// RASQ リストを消す前の確かめの見出し。name はリストの名前
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を削除しますか？'**
  String collectionsDeleteConfirmTitle(String name);

  /// RASQ リストを消す前の確かめの本文
  ///
  /// In ja, this message translates to:
  /// **'フォローしている人の一覧からも消えます。'**
  String get collectionsDeleteConfirmMessage;

  /// RASQ リストを消す前の確かめの、消すボタン
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get collectionsDeleteButton;

  /// RASQ リストを消す前の確かめの、やめるボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get collectionsCancel;

  /// メニューの操作やフォローができなかったときの知らせ。error はエラーの内容
  ///
  /// In ja, this message translates to:
  /// **'できませんでした: {error}'**
  String collectionsActionFailed(String error);

  /// RASQ リスト / クリップのページのタブ: 投稿
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get collectionsTabPosts;

  /// RASQ リストのページのタブ: 投稿を話題ごとに区切った目次
  ///
  /// In ja, this message translates to:
  /// **'話題の目次'**
  String get collectionsTabTopics;

  /// RASQ リストのページのタブ: 入っている人
  ///
  /// In ja, this message translates to:
  /// **'メンバー'**
  String get collectionsTabMembers;

  /// RASQ リスト / クリップのページのタブ: 入っている人 / 投稿のサーバーの情報
  ///
  /// In ja, this message translates to:
  /// **'サーバー'**
  String get collectionsTabServers;

  /// RASQ リスト / クリップのページの見出しの下: 開いたときに中身を取り直した
  ///
  /// In ja, this message translates to:
  /// **'見たときに新しくしました'**
  String get collectionsStatusRefreshedOnView;

  /// 見出しの下: 開いたときに取り直せず、前に取った中身を出している
  ///
  /// In ja, this message translates to:
  /// **'取り直せませんでした(前の内容です)'**
  String get collectionsStatusRefreshFailed;

  /// 見出しの下: フォローしているが、取り直しの資格が無い人への説明
  ///
  /// In ja, this message translates to:
  /// **'同じサーバーに所属しているか、入っている人をフォローしていると、見たときに新しくなります'**
  String get collectionsStatusFollowingHint;

  /// ページ / タイルの上の種類の名前: RASQ リスト(複数の SNS の人をまとめたもの)
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト'**
  String get collectionsKindList;

  /// ページ / タイルの上の種類の名前: RASQ クリップ(複数の SNS の投稿をまとめたもの)
  ///
  /// In ja, this message translates to:
  /// **'RASQ クリップ'**
  String get collectionsKindClip;

  /// RASQ リスト / クリップが非公開であることの印
  ///
  /// In ja, this message translates to:
  /// **'非公開'**
  String get collectionsPrivate;

  /// RASQ リスト / クリップが公開であることの印
  ///
  /// In ja, this message translates to:
  /// **'公開'**
  String get collectionsPublic;

  /// RASQ リストに入っている人の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}人}}'**
  String collectionsMemberCount(int count);

  /// RASQ クリップに入っている投稿の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件}}'**
  String collectionsItemCount(int count);

  /// RASQ リスト / クリップをフォローしている人の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{フォロワー {count}}}'**
  String collectionsFollowerCount(int count);

  /// RASQ リスト / クリップを最後に取り直した時。ago は「5分前」のような経った時間
  ///
  /// In ja, this message translates to:
  /// **'更新 {ago}'**
  String collectionsUpdatedAgo(String ago);

  /// 補足の項目(人数・フォロワー・更新・公開かどうかなど)を並べるときの区切り
  ///
  /// In ja, this message translates to:
  /// **' ・ '**
  String get collectionsSeparator;

  /// RASQ リストのページのフォローのボタン(フォローしているとき)と、リストの候補の行の印
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get collectionsFollowing;

  /// RASQ リスト / クリップのページのフォローのボタン(フォローしていないとき)
  ///
  /// In ja, this message translates to:
  /// **'フォロー'**
  String get collectionsFollow;

  /// RASQ リストの投稿のタブが空のとき
  ///
  /// In ja, this message translates to:
  /// **'まだ投稿がありません'**
  String get collectionsNoPostsYet;

  /// RASQ リストに誰も入っていないときの補足。「RASQ リストに追加」はユーザーページの … のメニューの項目
  ///
  /// In ja, this message translates to:
  /// **'ユーザーページの … →「RASQ リストに追加」で人を入れられます'**
  String get collectionsNoPostsHintEmpty;

  /// RASQ リストに人はいるが、投稿をまだ取っていないときの補足
  ///
  /// In ja, this message translates to:
  /// **'見られる人が開いたときに集まります'**
  String get collectionsNoPostsHintCollecting;

  /// RASQ クリップに投稿が無いとき
  ///
  /// In ja, this message translates to:
  /// **'クリップは空です'**
  String get collectionsClipEmpty;

  /// RASQ クリップの投稿が見られなくなったときの行
  ///
  /// In ja, this message translates to:
  /// **'この投稿は見られなくなりました(消されたか、公開範囲が変わりました)'**
  String get collectionsItemGone;

  /// RASQ クリップの投稿が見られるか確かめている途中の行
  ///
  /// In ja, this message translates to:
  /// **'公開範囲を確かめています'**
  String get collectionsItemChecking;

  /// RASQ リストのメンバーのタブのボタン(作った人だけ)
  ///
  /// In ja, this message translates to:
  /// **'メンバーを追加'**
  String get collectionsAddMembers;

  /// RASQ リストに人を足したときの知らせ。count は足した人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 人を追加しました}}'**
  String collectionsMembersAdded(int count);

  /// RASQ リストに人を足せなかったときの知らせ。error はエラーの内容
  ///
  /// In ja, this message translates to:
  /// **'追加できませんでした: {error}'**
  String collectionsAddFailed(String error);

  /// RASQ リストに誰も入っていないとき
  ///
  /// In ja, this message translates to:
  /// **'メンバーはいません'**
  String get collectionsNoMembers;

  /// RASQ リストに誰もいないときの、作った人への補足。「メンバーを追加」はこのタブのボタン、「RASQ リストに追加」はユーザーページの … のメニューの項目
  ///
  /// In ja, this message translates to:
  /// **'「メンバーを追加」か、ユーザーページの … →「RASQ リストに追加」'**
  String get collectionsNoMembersHint;

  /// RASQ リストのメンバーの行の補足。handle はユーザー名、kind は SNS の種類(misskey など)
  ///
  /// In ja, this message translates to:
  /// **'@{handle} ・ {kind}'**
  String collectionsMemberSubtitle(String handle, String kind);

  /// RASQ リストのメンバーの行の ✕ のボタンの説明(作った人だけ)
  ///
  /// In ja, this message translates to:
  /// **'リストから外す'**
  String get collectionsRemoveFromListTooltip;

  /// RASQ リストから人を外せなかったときの知らせ。error はエラーの内容
  ///
  /// In ja, this message translates to:
  /// **'外せませんでした: {error}'**
  String collectionsRemoveFailed(String error);

  /// RASQ リストをタイムラインに取り込めない理由
  ///
  /// In ja, this message translates to:
  /// **'リスト内の人の情報を取れるアカウントがありません(入っている人と同じサーバーのアカウントか、入っている人のフォローが要ります)'**
  String get collectionsNotFetchableHint;

  /// RASQ アカウントのサーバー(Central)が設定されていないとき
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントのサーバーが設定されていません'**
  String get collectionsNoServer;

  /// RASQ リストを取り込めるか確かめられなかったとき。error はエラーの内容
  ///
  /// In ja, this message translates to:
  /// **'確かめられませんでした: {error}'**
  String collectionsCheckFailed(String error);

  /// RASQ リストの候補の列が空のとき(検索語が空)
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストはまだありません'**
  String get collectionsPickerEmpty;

  /// RASQ リストの検索に当たるものが無いとき
  ///
  /// In ja, this message translates to:
  /// **'見つかりません'**
  String get collectionsPickerNoHits;

  /// RASQ リストの候補の行の印: 自分が作ったリスト
  ///
  /// In ja, this message translates to:
  /// **'自分のリスト'**
  String get collectionsPickerMine;

  /// RASQ リストの候補の行の印: リスト内の人の情報を取れない(取り込めない)
  ///
  /// In ja, this message translates to:
  /// **'取れません'**
  String get collectionsPickerNotFetchable;

  /// RASQ リストを取り込もうとしたが、アカウントにログインしていないとき
  ///
  /// In ja, this message translates to:
  /// **'ログインしていません'**
  String get collectionsNotLoggedIn;

  /// RASQ リストを取り込めないとき。name はリストの名前、reason は理由の文
  ///
  /// In ja, this message translates to:
  /// **'「{name}」は取り込めません({reason})'**
  String collectionsImportRejected(String name, String reason);

  /// 取り込もうとした RASQ リストが、もうホームのタイムラインの取り込み元にあるとき。name はリストの名前
  ///
  /// In ja, this message translates to:
  /// **'「{name}」はもうホームのタイムラインに入っています'**
  String collectionsAlreadyImported(String name);

  /// RASQ リストをホームのタイムラインの取り込み元に足したとき。name はリストの名前。歯車はホームのタブの行の設定のボタン
  ///
  /// In ja, this message translates to:
  /// **'「{name}」をホームのタイムラインに取り込みました(タブ行の歯車で確認できます)'**
  String collectionsImported(String name);

  /// 投稿などに埋めた RASQ リスト / クリップのタイルの、開くボタン
  ///
  /// In ja, this message translates to:
  /// **'見てみる'**
  String get collectionsTileOpen;

  /// RASQ アカウントが無いのに RASQ リストを作ろうとしたとき
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストを作るには RASQ アカウントが必要です'**
  String get collectionsCreateNeedsAccount;

  /// RASQ リストを作るシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'新しい RASQ リスト'**
  String get collectionsCreateTitle;

  /// RASQ リストを作るシートの、名前の欄の薄い文字
  ///
  /// In ja, this message translates to:
  /// **'リスト名'**
  String get collectionsListNameHint;

  /// RASQ リストを作るシートの、公開するかのスイッチ
  ///
  /// In ja, this message translates to:
  /// **'公開する'**
  String get collectionsPublishSwitch;

  /// 公開するかのスイッチの補足
  ///
  /// In ja, this message translates to:
  /// **'アカウントページと共有リンクから見られます。フォローした人が見たときにも新しくなります'**
  String get collectionsPublishSwitchSubtitle;

  /// RASQ リストを作るシートの決定のボタン
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get collectionsCreateButton;

  /// RASQ リストを作れなかったときの知らせ。error はエラーの内容
  ///
  /// In ja, this message translates to:
  /// **'作成できませんでした: {error}'**
  String collectionsCreateFailed(String error);

  /// RASQ アカウントが無いのに RASQ リストに人を足そうとしたとき
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストを使うには RASQ アカウントが必要です'**
  String get collectionsUseNeedsAccount;

  /// 自分の RASQ リストの一覧を読めなかったときの知らせ。error はエラーの内容
  ///
  /// In ja, this message translates to:
  /// **'リストを読めませんでした: {error}'**
  String collectionsLoadListsFailed(String error);

  /// ユーザーを RASQ リストに足すシートの見出し(ユーザーページの … のメニューから)
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストに追加'**
  String get collectionsAddToListTitle;

  /// RASQ リストに足すシートの、公開のリストの行の補足。count は入っている人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}人}} ・ 公開'**
  String collectionsAddToListSubtitlePublic(int count);

  /// RASQ リストに足すシートの、非公開のリストの行の補足。count は入っている人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}人}} ・ 非公開'**
  String collectionsAddToListSubtitlePrivate(int count);

  /// RASQ リストに足すシートの末尾の行。新しい RASQ リストを作ってそこに足す
  ///
  /// In ja, this message translates to:
  /// **'新しいリストを作成'**
  String get collectionsCreateNewList;

  /// ユーザーを RASQ リストに足したときの知らせ。name はリストの名前
  ///
  /// In ja, this message translates to:
  /// **'「{name}」に追加しました'**
  String collectionsAddedTo(String name);

  /// 足そうとしたユーザーが、もうその RASQ リストに入っているとき。name はリストの名前
  ///
  /// In ja, this message translates to:
  /// **'すでに「{name}」に入っています'**
  String collectionsAlreadyIn(String name);

  /// コンポーザーの題(新しい投稿)
  ///
  /// In ja, this message translates to:
  /// **'ノートの作成'**
  String get composeTargetNormalTitle;

  /// コンポーザーの題(返信)
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get composeTargetReplyTitle;

  /// コンポーザーの題(引用)
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get composeTargetQuoteTitle;

  /// 絵文字ピッカーの題(既定)
  ///
  /// In ja, this message translates to:
  /// **'絵文字'**
  String get composeEmojiPickerTitle;

  /// No description provided for @composeEmojiPickerClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get composeEmojiPickerClose;

  /// No description provided for @composePollRemoveTooltip.
  ///
  /// In ja, this message translates to:
  /// **'投票を削除'**
  String get composePollRemoveTooltip;

  /// 投票の選択肢の入力欄のヒント。index は 1 から
  ///
  /// In ja, this message translates to:
  /// **'回答{index}'**
  String composePollChoiceHint(int index);

  /// 投票の選択肢を消すボタン
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get composePollChoiceDeleteTooltip;

  /// 投票の選択肢を足すボタン
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get composePollAddChoice;

  /// 投票の締め切りを決める欄の開閉
  ///
  /// In ja, this message translates to:
  /// **'時間指定'**
  String get composePollTimed;

  /// No description provided for @composePollMultiple.
  ///
  /// In ja, this message translates to:
  /// **'複数回答'**
  String get composePollMultiple;

  /// 投票の期間の単位
  ///
  /// In ja, this message translates to:
  /// **'日'**
  String get composePollUnitDays;

  /// 投票の期間の単位
  ///
  /// In ja, this message translates to:
  /// **'時間'**
  String get composePollUnitHours;

  /// 投票の期間の単位
  ///
  /// In ja, this message translates to:
  /// **'分'**
  String get composePollUnitMinutes;

  /// 投票の期間の単位
  ///
  /// In ja, this message translates to:
  /// **'秒'**
  String get composePollUnitSeconds;

  /// 下書きの一覧(FOW)の題
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get composeDraftsTitle;

  /// No description provided for @composeDraftsCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get composeDraftsCancel;

  /// 選んだ下書きを消すボタン
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get composeDraftsDelete;

  /// No description provided for @composeDraftsSaveAndClose.
  ///
  /// In ja, this message translates to:
  /// **'今の内容を保存して閉じる'**
  String get composeDraftsSaveAndClose;

  /// No description provided for @composeDraftsOverwriteAndClose.
  ///
  /// In ja, this message translates to:
  /// **'今の内容を上書き保存して閉じる'**
  String get composeDraftsOverwriteAndClose;

  /// No description provided for @composeDraftsSaveNewAndClose.
  ///
  /// In ja, this message translates to:
  /// **'今の内容を新しい下書きにして閉じる'**
  String get composeDraftsSaveNewAndClose;

  /// No description provided for @composeDraftsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'下書きはありません'**
  String get composeDraftsEmpty;

  /// 下書きの行の注記: 添付の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{添付 {count}}}'**
  String composeDraftsAttachmentCount(int count);

  /// 下書きの行の注記: いまコンポーザーで開いている
  ///
  /// In ja, this message translates to:
  /// **'開いている'**
  String get composeDraftsOpenNow;

  /// No description provided for @composeDraftsSelectOff.
  ///
  /// In ja, this message translates to:
  /// **'選択解除'**
  String get composeDraftsSelectOff;

  /// No description provided for @composeDraftsSelect.
  ///
  /// In ja, this message translates to:
  /// **'選択'**
  String get composeDraftsSelect;

  /// 選んだ下書きの数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 件}}'**
  String composeDraftsSelectedCount(int count);

  /// 本文の無い下書きの見出し
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{(添付 {count} 件)}}'**
  String composeDraftTitleAttachments(int count);

  /// 本文も添付も無い下書きの見出し
  ///
  /// In ja, this message translates to:
  /// **'(本文なし)'**
  String get composeDraftTitleEmpty;

  /// 下書きの対象の種類
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get composeDraftTargetReply;

  /// 下書きの対象の種類
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get composeDraftTargetQuote;

  /// 下書きの対象の種類
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get composeDraftTargetPost;

  /// リアクションの受け入れ(Misskey)
  ///
  /// In ja, this message translates to:
  /// **'全て'**
  String get composeReactionAcceptanceAll;

  /// リアクションの受け入れ(Misskey)
  ///
  /// In ja, this message translates to:
  /// **'いいねのみ'**
  String get composeReactionAcceptanceLikeOnly;

  /// リアクションの受け入れ(Misskey)
  ///
  /// In ja, this message translates to:
  /// **'外部からはいいね'**
  String get composeReactionAcceptanceLikeOnlyForRemote;

  /// リアクションの受け入れ(Misskey)
  ///
  /// In ja, this message translates to:
  /// **'非センシティブのみ'**
  String get composeReactionAcceptanceNonSensitiveOnly;

  /// リアクションの受け入れ(Misskey)
  ///
  /// In ja, this message translates to:
  /// **'非センシティブ&外部からはいいねのみ'**
  String get composeReactionAcceptanceNonSensitiveOnlyForLocalLikeOnlyForRemote;

  /// No description provided for @composeEmojiResizeHandleSemantics.
  ///
  /// In ja, this message translates to:
  /// **'サイズ変更ハンドル'**
  String get composeEmojiResizeHandleSemantics;

  /// 絵文字ピッカーの節: 最近使った絵文字
  ///
  /// In ja, this message translates to:
  /// **'履歴'**
  String get composeEmojiSectionHistory;

  /// 絵文字ピッカーの節: 予測した絵文字
  ///
  /// In ja, this message translates to:
  /// **'予測'**
  String get composeEmojiSectionPrediction;

  /// No description provided for @composeEmojiBundleEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'バンドル編集'**
  String get composeEmojiBundleEditTitle;

  /// No description provided for @composeEmojiBundleEditMessage.
  ///
  /// In ja, this message translates to:
  /// **'バンドルの編集は準備中です。'**
  String get composeEmojiBundleEditMessage;

  /// 絵文字ピッカーの節: Unicode の絵文字
  ///
  /// In ja, this message translates to:
  /// **'デフォルト'**
  String get composeEmojiSectionDefault;

  /// No description provided for @composeEmojiCustomEmpty.
  ///
  /// In ja, this message translates to:
  /// **'独自の絵文字はありません'**
  String get composeEmojiCustomEmpty;

  /// 絵文字ピッカーの節: サーバーの独自の絵文字
  ///
  /// In ja, this message translates to:
  /// **'サーバー'**
  String get composeEmojiSectionServer;

  /// ジャンルの無い独自の絵文字のまとまり
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get composeEmojiGenreOther;

  /// 絵文字のジャンル / ステッカーのパックの見出し
  ///
  /// In ja, this message translates to:
  /// **'・{name}'**
  String composeEmojiGroupHeading(String name);

  /// No description provided for @composeEmojiSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get composeEmojiSearchHint;

  /// No description provided for @composeEmojiStickersEmpty.
  ///
  /// In ja, this message translates to:
  /// **'使えるアセットパックがありません(ストアからインストールできます)'**
  String get composeEmojiStickersEmpty;

  /// No description provided for @composeEmojiSectionSearchResults.
  ///
  /// In ja, this message translates to:
  /// **'検索結果'**
  String get composeEmojiSectionSearchResults;

  /// No description provided for @composeEmojiSearchNoHit.
  ///
  /// In ja, this message translates to:
  /// **'見つかりません'**
  String get composeEmojiSearchNoHit;

  /// 絵文字の意味検索の索引づくりの進み
  ///
  /// In ja, this message translates to:
  /// **'意味検索を準備中 {done} / {total}'**
  String composeEmojiIndexProgress(int done, int total);

  /// 投稿の公開範囲
  ///
  /// In ja, this message translates to:
  /// **'ホーム'**
  String get composeVisibilityHome;

  /// 投稿の公開範囲
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get composeVisibilityFollowers;

  /// 投稿の公開範囲
  ///
  /// In ja, this message translates to:
  /// **'パブリック'**
  String get composeVisibilityPublic;

  /// No description provided for @composeVisibilityTooltip.
  ///
  /// In ja, this message translates to:
  /// **'公開範囲: {label}'**
  String composeVisibilityTooltip(String label);

  /// No description provided for @composeLocalOnlyOnTooltip.
  ///
  /// In ja, this message translates to:
  /// **'連合なし(このサーバーのみ)'**
  String get composeLocalOnlyOnTooltip;

  /// No description provided for @composeLocalOnlyOffTooltip.
  ///
  /// In ja, this message translates to:
  /// **'連合あり(タップで連合なしに)'**
  String get composeLocalOnlyOffTooltip;

  /// No description provided for @composeReactionAcceptanceTooltip.
  ///
  /// In ja, this message translates to:
  /// **'リアクションの受け入れ: {label}'**
  String composeReactionAcceptanceTooltip(String label);

  /// No description provided for @composeOn.
  ///
  /// In ja, this message translates to:
  /// **'オン'**
  String get composeOn;

  /// No description provided for @composeOff.
  ///
  /// In ja, this message translates to:
  /// **'オフ'**
  String get composeOff;

  /// テキスト加工プラグインのボタン。state は「オン」/「オフ」
  ///
  /// In ja, this message translates to:
  /// **'{label}({state}・長押しで設定)'**
  String composeTextPluginTooltip(String label, String state);

  /// No description provided for @composeTextPluginHereTitle.
  ///
  /// In ja, this message translates to:
  /// **'このコンポーザーでオン'**
  String get composeTextPluginHereTitle;

  /// No description provided for @composeTextPluginHereSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'本文の変化をこのプラグインに渡します'**
  String get composeTextPluginHereSubtitle;

  /// No description provided for @composeTextPluginAutoTitle.
  ///
  /// In ja, this message translates to:
  /// **'次からも自動でオン'**
  String get composeTextPluginAutoTitle;

  /// state は「オン」/「オフ」
  ///
  /// In ja, this message translates to:
  /// **'プラグインの既定({state})'**
  String composeTextPluginAutoDefault(String state);

  /// state は「オン」/「オフ」
  ///
  /// In ja, this message translates to:
  /// **'設定で上書き中(既定は {state})'**
  String composeTextPluginAutoOverridden(String state);

  /// No description provided for @composeTextPluginResetDefault.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの既定に戻す'**
  String get composeTextPluginResetDefault;

  /// name はプラグインの名前
  ///
  /// In ja, this message translates to:
  /// **'{name} · テキスト加工'**
  String composeTextPluginCaption(String name);

  /// コンポーザーのヘッダーの題
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get composeHeaderPost;

  /// コンポーザーのヘッダーの題
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get composeHeaderReply;

  /// コンポーザーのヘッダーの題
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get composeHeaderQuote;

  /// No description provided for @composeCloseOverwriteTitle.
  ///
  /// In ja, this message translates to:
  /// **'下書きを上書きしますか'**
  String get composeCloseOverwriteTitle;

  /// No description provided for @composeCloseSaveTitle.
  ///
  /// In ja, this message translates to:
  /// **'下書きに保存しますか'**
  String get composeCloseSaveTitle;

  /// No description provided for @composeCloseOverwriteMessage.
  ///
  /// In ja, this message translates to:
  /// **'開いている下書きを今の内容で上書きして閉じます。'**
  String get composeCloseOverwriteMessage;

  /// No description provided for @composeCloseSaveMessage.
  ///
  /// In ja, this message translates to:
  /// **'今の内容を下書きに残して閉じます。'**
  String get composeCloseSaveMessage;

  /// No description provided for @composeCloseOverwrite.
  ///
  /// In ja, this message translates to:
  /// **'上書き'**
  String get composeCloseOverwrite;

  /// No description provided for @composeCloseSaveNew.
  ///
  /// In ja, this message translates to:
  /// **'新規保存'**
  String get composeCloseSaveNew;

  /// No description provided for @composeCloseSave.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get composeCloseSave;

  /// No description provided for @composeCloseDiscard.
  ///
  /// In ja, this message translates to:
  /// **'変更を破棄'**
  String get composeCloseDiscard;

  /// No description provided for @composeCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get composeCancel;

  /// 複数選択モード: 同じ内容で投稿するアカウントの印
  ///
  /// In ja, this message translates to:
  /// **'通常投稿'**
  String get composeMultiNormal;

  /// 複数選択モード: ポスト先グラフを通して投稿するアカウントの印
  ///
  /// In ja, this message translates to:
  /// **'ノード連動'**
  String get composeMultiLinked;

  /// No description provided for @composeRasqTarget.
  ///
  /// In ja, this message translates to:
  /// **'RASQ に投稿'**
  String get composeRasqTarget;

  /// No description provided for @composeTargetMatchedTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ポスト先ノードの条件に一致'**
  String get composeTargetMatchedTooltip;

  /// No description provided for @composeTargetCustomize.
  ///
  /// In ja, this message translates to:
  /// **'投稿先のカスタマイズ'**
  String get composeTargetCustomize;

  /// No description provided for @composeMultiSelectOff.
  ///
  /// In ja, this message translates to:
  /// **'複数選択を解除'**
  String get composeMultiSelectOff;

  /// No description provided for @composeMultiSelectOn.
  ///
  /// In ja, this message translates to:
  /// **'複数選択モード'**
  String get composeMultiSelectOn;

  /// No description provided for @composeLinkedConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'連動投稿の確認'**
  String get composeLinkedConfirmTitle;

  /// No description provided for @composeLinkedConfirmSame.
  ///
  /// In ja, this message translates to:
  /// **'同内容で連動投稿'**
  String get composeLinkedConfirmSame;

  /// No description provided for @composeLinkedConfirmAlt.
  ///
  /// In ja, this message translates to:
  /// **'代わりのフォーマットで連動投稿'**
  String get composeLinkedConfirmAlt;

  /// No description provided for @composeLinkedConfirmPost.
  ///
  /// In ja, this message translates to:
  /// **'この内容で投稿する'**
  String get composeLinkedConfirmPost;

  /// No description provided for @composeRasqNoServer.
  ///
  /// In ja, this message translates to:
  /// **'RASQ のサーバーが設定されていません'**
  String get composeRasqNoServer;

  /// No description provided for @composeRasqOverLimit.
  ///
  /// In ja, this message translates to:
  /// **'RASQ の上限を超えています'**
  String get composeRasqOverLimit;

  /// RASQ の返信で添付のボタンを押せないときのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'RASQ の返信は文字だけです'**
  String get composeRasqTextOnlyTip;

  /// No description provided for @composePickImageFailed.
  ///
  /// In ja, this message translates to:
  /// **'画像を選択できませんでした: {error}'**
  String composePickImageFailed(String error);

  /// No description provided for @composePickVideoLibrary.
  ///
  /// In ja, this message translates to:
  /// **'ライブラリの動画'**
  String get composePickVideoLibrary;

  /// No description provided for @composePickVideoFile.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから(動画 / 音声)'**
  String get composePickVideoFile;

  /// No description provided for @composePickNotMedia.
  ///
  /// In ja, this message translates to:
  /// **'動画 / 音声のファイルではありません: {name}'**
  String composePickNotMedia(String name);

  /// No description provided for @composePickMediaFailed.
  ///
  /// In ja, this message translates to:
  /// **'動画 / 音声を選択できませんでした: {error}'**
  String composePickMediaFailed(String error);

  /// No description provided for @composeRasqNotLoggedIn.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインしていません'**
  String get composeRasqNotLoggedIn;

  /// No description provided for @composeRasqMediaTooLarge.
  ///
  /// In ja, this message translates to:
  /// **'RASQ への投稿では、動画 / 音声は 1 つ {mb} MB までです'**
  String composeRasqMediaTooLarge(int mb);

  /// No description provided for @composeRasqReplyTextOnly.
  ///
  /// In ja, this message translates to:
  /// **'RASQ の返信は、文字だけです(添付 / 投票は付けられません)'**
  String get composeRasqReplyTextOnly;

  /// No description provided for @composeRasqReplyMaxChars.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{RASQ の返信は {count} 文字までです}}'**
  String composeRasqReplyMaxChars(int count);

  /// No description provided for @composeRasqMaxImages.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{RASQ への投稿は、添付 {count} つまでです}}'**
  String composeRasqMaxImages(int count);

  /// No description provided for @composeRasqMaxChars.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{RASQ への投稿は {count} 文字までです}}'**
  String composeRasqMaxChars(int count);

  /// No description provided for @composeRasqMaxPollChoices.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{RASQ への投稿は、投票の選択肢 {count} 個までです}}'**
  String composeRasqMaxPollChoices(int count);

  /// No description provided for @composeRasqPosted.
  ///
  /// In ja, this message translates to:
  /// **'RASQ に投稿しました'**
  String get composeRasqPosted;

  /// No description provided for @composeRasqReplyQuota.
  ///
  /// In ja, this message translates to:
  /// **'RASQ の返信は 100 件までです。古い返信を消してください'**
  String get composeRasqReplyQuota;

  /// No description provided for @composeRasqPostQuota.
  ///
  /// In ja, this message translates to:
  /// **'RASQ への投稿は 3 件までです。古い投稿を消してください'**
  String get composeRasqPostQuota;

  /// No description provided for @composeRasqPostFailed.
  ///
  /// In ja, this message translates to:
  /// **'RASQ に投稿できませんでした: {error}'**
  String composeRasqPostFailed(String error);

  /// No description provided for @composePolicyConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'送る前の確認'**
  String get composePolicyConfirmTitle;

  /// No description provided for @composePolicyConfirmSend.
  ///
  /// In ja, this message translates to:
  /// **'このまま送る'**
  String get composePolicyConfirmSend;

  /// No description provided for @composePolicyConfirmEdit.
  ///
  /// In ja, this message translates to:
  /// **'書き直す'**
  String get composePolicyConfirmEdit;

  /// No description provided for @composeSending.
  ///
  /// In ja, this message translates to:
  /// **'送信中…'**
  String get composeSending;

  /// No description provided for @composeModerationDelay.
  ///
  /// In ja, this message translates to:
  /// **'{seconds, plural, other{検閲による遅延: あと {seconds} 秒}}'**
  String composeModerationDelay(int seconds);

  /// No description provided for @composeUploading.
  ///
  /// In ja, this message translates to:
  /// **'アップロード中 {index}/{total}'**
  String composeUploading(int index, int total);

  /// errors は失敗したアカウントの理由(「 / 」区切り)
  ///
  /// In ja, this message translates to:
  /// **'連動投稿に失敗しました: {errors}(本体は投稿済みです)'**
  String composeLinkedFailed(String errors);

  /// No description provided for @composeSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'送信に失敗しました: {error}'**
  String composeSendFailed(String error);

  /// 複数のアカウントへ同時に送ったあとのスナックバーで、SNS プラグインからの知らせ(D-500。例: 引用の代わりに引用元の URL を付けて投稿した)の前にアカウント名を添える。account はアカウント表記(@name@host)、message はプラグインが表示の言語で返した文
  ///
  /// In ja, this message translates to:
  /// **'{account}: {message}'**
  String composePostNoticeForAccount(String account, String message);

  /// コンポーザーのヘッダーの、下書きの一覧を開くボタン
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get composeDraftsButton;

  /// No description provided for @composeDirectReplyNote.
  ///
  /// In ja, this message translates to:
  /// **'ダイレクト投稿への返信(相手にだけ届きます)'**
  String get composeDirectReplyNote;

  /// No description provided for @composeChooseTargetTooltip.
  ///
  /// In ja, this message translates to:
  /// **'投稿先を選ぶ'**
  String get composeChooseTargetTooltip;

  /// No description provided for @composeCwHint.
  ///
  /// In ja, this message translates to:
  /// **'注釈..'**
  String get composeCwHint;

  /// No description provided for @composeCwRemoveTooltip.
  ///
  /// In ja, this message translates to:
  /// **'注釈を外す'**
  String get composeCwRemoveTooltip;

  /// No description provided for @composeDmHint.
  ///
  /// In ja, this message translates to:
  /// **'メッセージを入力..'**
  String get composeDmHint;

  /// コンポーザーの本文の欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'いいことがありますように！'**
  String get composeTextHint;

  /// ハッシュタグの候補。tag はタグ、count は使っている人の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{tag}  {count}人}}'**
  String composeHashtagUsers(String tag, int count);

  /// No description provided for @composeToolCamera.
  ///
  /// In ja, this message translates to:
  /// **'カメラ'**
  String get composeToolCamera;

  /// No description provided for @composeToolImage.
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get composeToolImage;

  /// No description provided for @composeToolVideo.
  ///
  /// In ja, this message translates to:
  /// **'動画 / 音声'**
  String get composeToolVideo;

  /// No description provided for @composeToolCw.
  ///
  /// In ja, this message translates to:
  /// **'隠す(注釈)'**
  String get composeToolCw;

  /// No description provided for @composeToolPoll.
  ///
  /// In ja, this message translates to:
  /// **'投票'**
  String get composeToolPoll;

  /// No description provided for @composeToolEmoji.
  ///
  /// In ja, this message translates to:
  /// **'絵文字'**
  String get composeToolEmoji;

  /// 送信ボタン(返信のとき)
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get composeSendReply;

  /// 送信ボタン
  ///
  /// In ja, this message translates to:
  /// **'送信'**
  String get composeSend;

  /// 添付を外すボタン
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get composeAttachmentRemove;

  /// 添付を加工するボタン
  ///
  /// In ja, this message translates to:
  /// **'加工'**
  String get composeAttachmentEdit;

  /// No description provided for @composeAttachmentUnsensitive.
  ///
  /// In ja, this message translates to:
  /// **'センシティブ解除'**
  String get composeAttachmentUnsensitive;

  /// No description provided for @composeAttachmentSensitive.
  ///
  /// In ja, this message translates to:
  /// **'センシティブにする'**
  String get composeAttachmentSensitive;

  /// ファイル選択ダイアログの種類の名前
  ///
  /// In ja, this message translates to:
  /// **'動画 / 音声'**
  String get composeMediaPickTypeLabel;

  /// 投稿の画像の加工: 動画にするスイッチ(動画の付いた投稿)
  ///
  /// In ja, this message translates to:
  /// **'動画にする(付いている動画を、タイルの中で再生。音つき)'**
  String get composeMediaMotionVideoLabel;

  /// 投稿の画像の加工: 動画にするスイッチ(音声の付いた投稿)
  ///
  /// In ja, this message translates to:
  /// **'動画にする(タイルの静止画 + 付いている音声)'**
  String get composeMediaMotionAudioLabel;

  /// 投稿の画像の加工: 動画にするスイッチ(GIF / 動く MFM の投稿)
  ///
  /// In ja, this message translates to:
  /// **'動画にする(動いている様子を {fps} コマ/秒で {seconds} 秒)'**
  String composeMediaMotionAnimatedLabel(int fps, int seconds);

  /// 「動画に変換しますか?」に添える説明
  ///
  /// In ja, this message translates to:
  /// **'この投稿には動画が付いています。'**
  String get composeMediaMotionVideoNote;

  /// 「動画に変換しますか?」に添える説明
  ///
  /// In ja, this message translates to:
  /// **'この投稿には音声が付いています。'**
  String get composeMediaMotionAudioNote;

  /// 「動画に変換しますか?」に添える説明
  ///
  /// In ja, this message translates to:
  /// **'この投稿には動く絵(GIF / 動く MFM)があります。'**
  String get composeMediaMotionAnimatedNote;

  /// 投稿を動画にするときのエラー
  ///
  /// In ja, this message translates to:
  /// **'投稿が画面に出ていません'**
  String get composeMediaPostNotOnScreen;

  /// 投稿を動画にするときのエラー(後ろに「: 詳しい理由」が付く)
  ///
  /// In ja, this message translates to:
  /// **'元のファイルを取得できませんでした'**
  String get composeMediaSourceFetchFailed;

  /// ext はファイルの拡張子(webm など)
  ///
  /// In ja, this message translates to:
  /// **'この端末は {ext} 形式を読めません(静止画なら貼れます)'**
  String composeMediaFormatUnreadable(String ext);

  /// 投稿を動画にするときのエラー(後ろに「: 詳しい理由」が付く)
  ///
  /// In ja, this message translates to:
  /// **'元のファイル(.{ext}、{bytes} バイト)を開けませんでした'**
  String composeMediaSourceOpenFailed(String ext, int bytes);

  /// ノート画像の追加: タブ
  ///
  /// In ja, this message translates to:
  /// **'自分の投稿'**
  String get composeMediaTabMine;

  /// ノート画像の追加: タブ(リアクションした投稿)
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get composeMediaTabReacted;

  /// ノート画像の追加: タブ
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク'**
  String get composeMediaTabFavorites;

  /// ノート画像の追加: タブ
  ///
  /// In ja, this message translates to:
  /// **'最近の検索'**
  String get composeMediaTabSearches;

  /// 貼る投稿の見た目: スレッド展開時の本文
  ///
  /// In ja, this message translates to:
  /// **'スレッド'**
  String get composeMediaStyleThread;

  /// 貼る投稿の見た目: 一番小さい表示
  ///
  /// In ja, this message translates to:
  /// **'インライン'**
  String get composeMediaStyleInline;

  /// 投稿を画像にして貼る FOW の題
  ///
  /// In ja, this message translates to:
  /// **'ノート画像の追加'**
  String get composeMediaPostImageTitle;

  /// No description provided for @composeMediaCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get composeMediaCancel;

  /// No description provided for @composeMediaConfirm.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get composeMediaConfirm;

  /// No description provided for @composeMediaNoAccount.
  ///
  /// In ja, this message translates to:
  /// **'アカウントがありません'**
  String get composeMediaNoAccount;

  /// No description provided for @composeMediaSearchUnsupported.
  ///
  /// In ja, this message translates to:
  /// **'この SNS では投稿の検索が使えません'**
  String get composeMediaSearchUnsupported;

  /// No description provided for @composeMediaTabUnsupported.
  ///
  /// In ja, this message translates to:
  /// **'この SNS では「{tab}」が使えません'**
  String composeMediaTabUnsupported(String tab);

  /// No description provided for @composeMediaFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'取得できませんでした: {error}'**
  String composeMediaFetchFailed(String error);

  /// No description provided for @composeMediaCaptureRetry.
  ///
  /// In ja, this message translates to:
  /// **'選んだ投稿が画面に出ている状態で、もう一度「決定」を押してください'**
  String get composeMediaCaptureRetry;

  /// No description provided for @composeMediaVideoFailed.
  ///
  /// In ja, this message translates to:
  /// **'動画にできませんでした: {error}'**
  String composeMediaVideoFailed(String error);

  /// No description provided for @composeMediaFilterHistoryHint.
  ///
  /// In ja, this message translates to:
  /// **'検索の履歴を絞り込む'**
  String get composeMediaFilterHistoryHint;

  /// No description provided for @composeMediaFilterListHint.
  ///
  /// In ja, this message translates to:
  /// **'一覧を絞り込む'**
  String get composeMediaFilterListHint;

  /// No description provided for @composeMediaFilterFromHistoryTooltip.
  ///
  /// In ja, this message translates to:
  /// **'最近の検索から入れる'**
  String get composeMediaFilterFromHistoryTooltip;

  /// 貼る投稿の見た目の選択の見出し
  ///
  /// In ja, this message translates to:
  /// **'見た目'**
  String get composeMediaStyleHeading;

  /// No description provided for @composeMediaSearchResultsTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{query}」の検索結果'**
  String composeMediaSearchResultsTitle(String query);

  /// No description provided for @composeMediaSearchBack.
  ///
  /// In ja, this message translates to:
  /// **'最近の検索に戻る'**
  String get composeMediaSearchBack;

  /// No description provided for @composeMediaExcludedNote.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{公開範囲を限った投稿 {count} 件は出していません。}}'**
  String composeMediaExcludedNote(int count);

  /// 動画にするスイッチの説明
  ///
  /// In ja, this message translates to:
  /// **'オフ = その瞬間の静止画'**
  String get composeMediaAsVideoOffNote;

  /// No description provided for @composeMediaExporting.
  ///
  /// In ja, this message translates to:
  /// **'動画にしています…'**
  String get composeMediaExporting;

  /// No description provided for @composeMediaHistoryEmpty.
  ///
  /// In ja, this message translates to:
  /// **'最近の検索はありません(検索ホームで検索すると、ここに並びます)'**
  String get composeMediaHistoryEmpty;

  /// No description provided for @composeMediaHistoryNoMatch.
  ///
  /// In ja, this message translates to:
  /// **'当てはまる検索はありません'**
  String get composeMediaHistoryNoMatch;

  /// No description provided for @composeMediaPostsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'投稿はありません'**
  String get composeMediaPostsEmpty;

  /// No description provided for @composeMediaPostsNoMatch.
  ///
  /// In ja, this message translates to:
  /// **'当てはまる投稿はありません(「もっと読む」で続きも探せます)'**
  String get composeMediaPostsNoMatch;

  /// No description provided for @composeMediaLoadMore.
  ///
  /// In ja, this message translates to:
  /// **'もっと読む'**
  String get composeMediaLoadMore;

  /// MFM の関数 x2 の説明
  ///
  /// In ja, this message translates to:
  /// **'2倍に拡大'**
  String get composeMfmFnX2;

  /// MFM の関数 x3 の説明
  ///
  /// In ja, this message translates to:
  /// **'3倍に拡大'**
  String get composeMfmFnX3;

  /// MFM の関数 x4 の説明
  ///
  /// In ja, this message translates to:
  /// **'4倍に拡大'**
  String get composeMfmFnX4;

  /// MFM の関数 small の説明
  ///
  /// In ja, this message translates to:
  /// **'小さく表示'**
  String get composeMfmFnSmall;

  /// MFM の関数 center の説明
  ///
  /// In ja, this message translates to:
  /// **'中央寄せ'**
  String get composeMfmFnCenter;

  /// MFM の関数 blur の説明
  ///
  /// In ja, this message translates to:
  /// **'ぼかし(ホバー/タップで解除)'**
  String get composeMfmFnBlur;

  /// MFM の関数 rotate の説明
  ///
  /// In ja, this message translates to:
  /// **'回転'**
  String get composeMfmFnRotate;

  /// MFM の関数 rotate のプロパティー deg の説明
  ///
  /// In ja, this message translates to:
  /// **'角度(既定 90)'**
  String get composeMfmPropRotateDeg;

  /// MFM の関数 flip の説明
  ///
  /// In ja, this message translates to:
  /// **'反転'**
  String get composeMfmFnFlip;

  /// MFM の関数 flip のプロパティー h の説明
  ///
  /// In ja, this message translates to:
  /// **'左右'**
  String get composeMfmPropFlipH;

  /// MFM の関数 flip のプロパティー v の説明
  ///
  /// In ja, this message translates to:
  /// **'上下'**
  String get composeMfmPropFlipV;

  /// MFM の関数 fg の説明
  ///
  /// In ja, this message translates to:
  /// **'文字色'**
  String get composeMfmFnFg;

  /// MFM の関数 fg のプロパティー color の説明
  ///
  /// In ja, this message translates to:
  /// **'16進(例: ff0000)'**
  String get composeMfmPropFgColor;

  /// MFM の関数 bg の説明
  ///
  /// In ja, this message translates to:
  /// **'背景色'**
  String get composeMfmFnBg;

  /// MFM の関数 bg のプロパティー color の説明
  ///
  /// In ja, this message translates to:
  /// **'16進(例: ffff00)'**
  String get composeMfmPropBgColor;

  /// MFM の関数 shake の説明
  ///
  /// In ja, this message translates to:
  /// **'振動'**
  String get composeMfmFnShake;

  /// MFM の関数 shake のプロパティー speed の説明
  ///
  /// In ja, this message translates to:
  /// **'例: 0.5s'**
  String get composeMfmPropShakeSpeed;

  /// MFM の関数 spin の説明
  ///
  /// In ja, this message translates to:
  /// **'回転アニメ'**
  String get composeMfmFnSpin;

  /// MFM の関数 spin のプロパティー speed の説明
  ///
  /// In ja, this message translates to:
  /// **'例: 1.5s'**
  String get composeMfmPropSpinSpeed;

  /// MFM の関数 spin のプロパティー left の説明
  ///
  /// In ja, this message translates to:
  /// **'逆回転'**
  String get composeMfmPropSpinLeft;

  /// MFM の関数 spin のプロパティー alternate の説明
  ///
  /// In ja, this message translates to:
  /// **'往復'**
  String get composeMfmPropSpinAlternate;

  /// MFM の関数 spin のプロパティー x の説明
  ///
  /// In ja, this message translates to:
  /// **'横軸'**
  String get composeMfmPropSpinX;

  /// MFM の関数 spin のプロパティー y の説明
  ///
  /// In ja, this message translates to:
  /// **'縦軸'**
  String get composeMfmPropSpinY;

  /// MFM の関数 jump の説明
  ///
  /// In ja, this message translates to:
  /// **'ジャンプ'**
  String get composeMfmFnJump;

  /// MFM の関数 jump のプロパティー speed の説明
  ///
  /// In ja, this message translates to:
  /// **'例: 0.75s'**
  String get composeMfmPropJumpSpeed;

  /// MFM の関数 bounce の説明
  ///
  /// In ja, this message translates to:
  /// **'バウンド'**
  String get composeMfmFnBounce;

  /// MFM の関数 bounce のプロパティー speed の説明
  ///
  /// In ja, this message translates to:
  /// **'例: 0.75s'**
  String get composeMfmPropBounceSpeed;

  /// MFM の関数 rainbow の説明
  ///
  /// In ja, this message translates to:
  /// **'虹色'**
  String get composeMfmFnRainbow;

  /// MFM の関数 rainbow のプロパティー speed の説明
  ///
  /// In ja, this message translates to:
  /// **'例: 1s'**
  String get composeMfmPropRainbowSpeed;

  /// MFM の関数 twitch の説明
  ///
  /// In ja, this message translates to:
  /// **'ぴくぴく'**
  String get composeMfmFnTwitch;

  /// MFM の関数 twitch のプロパティー speed の説明
  ///
  /// In ja, this message translates to:
  /// **'例: 0.5s'**
  String get composeMfmPropTwitchSpeed;

  /// MFM の関数 jelly の説明
  ///
  /// In ja, this message translates to:
  /// **'ぷるぷる'**
  String get composeMfmFnJelly;

  /// MFM の関数 jelly のプロパティー speed の説明
  ///
  /// In ja, this message translates to:
  /// **'例: 1s'**
  String get composeMfmPropJellySpeed;

  /// MFM の関数 tada の説明
  ///
  /// In ja, this message translates to:
  /// **'じゃーん'**
  String get composeMfmFnTada;

  /// MFM の関数 tada のプロパティー speed の説明
  ///
  /// In ja, this message translates to:
  /// **'例: 1s'**
  String get composeMfmPropTadaSpeed;

  /// MFM の関数 plain の説明
  ///
  /// In ja, this message translates to:
  /// **'装飾を無効化'**
  String get composeMfmFnPlain;

  /// MFM の関数 font の説明
  ///
  /// In ja, this message translates to:
  /// **'書体を変える'**
  String get composeMfmFnFont;

  /// MFM の関数 font のプロパティー serif の説明
  ///
  /// In ja, this message translates to:
  /// **'明朝体(serif)'**
  String get composeMfmPropFontSerif;

  /// MFM の関数 font のプロパティー monospace の説明
  ///
  /// In ja, this message translates to:
  /// **'等幅(monospace)'**
  String get composeMfmPropFontMonospace;

  /// MFM の関数 font のプロパティー cursive の説明
  ///
  /// In ja, this message translates to:
  /// **'筆記体(cursive)'**
  String get composeMfmPropFontCursive;

  /// MFM の関数 font のプロパティー fantasy の説明
  ///
  /// In ja, this message translates to:
  /// **'装飾体(fantasy)'**
  String get composeMfmPropFontFantasy;

  /// MFM の関数 position の説明
  ///
  /// In ja, this message translates to:
  /// **'位置をずらす'**
  String get composeMfmFnPosition;

  /// MFM の関数 position のプロパティー x の説明
  ///
  /// In ja, this message translates to:
  /// **'横(文字の大きさ単位、例: 0.5)'**
  String get composeMfmPropPositionX;

  /// MFM の関数 position のプロパティー y の説明
  ///
  /// In ja, this message translates to:
  /// **'縦(文字の大きさ単位、例: -1)'**
  String get composeMfmPropPositionY;

  /// MFM の関数 scale の説明
  ///
  /// In ja, this message translates to:
  /// **'拡大・縮小(最大 5 倍)'**
  String get composeMfmFnScale;

  /// MFM の関数 scale のプロパティー x の説明
  ///
  /// In ja, this message translates to:
  /// **'横の倍率(例: 0.5)'**
  String get composeMfmPropScaleX;

  /// MFM の関数 scale のプロパティー y の説明
  ///
  /// In ja, this message translates to:
  /// **'縦の倍率(例: 1.5)'**
  String get composeMfmPropScaleY;

  /// MFM の関数 border の説明
  ///
  /// In ja, this message translates to:
  /// **'枠線'**
  String get composeMfmFnBorder;

  /// MFM の関数 border のプロパティー style の説明
  ///
  /// In ja, this message translates to:
  /// **'線の種類(solid / dashed / dotted など)'**
  String get composeMfmPropBorderStyle;

  /// MFM の関数 border のプロパティー width の説明
  ///
  /// In ja, this message translates to:
  /// **'太さ(px、既定 1)'**
  String get composeMfmPropBorderWidth;

  /// MFM の関数 border のプロパティー color の説明
  ///
  /// In ja, this message translates to:
  /// **'16進(既定はアクセント色)'**
  String get composeMfmPropBorderColor;

  /// MFM の関数 border のプロパティー radius の説明
  ///
  /// In ja, this message translates to:
  /// **'角の丸み(px)'**
  String get composeMfmPropBorderRadius;

  /// MFM の関数 border のプロパティー noclip の説明
  ///
  /// In ja, this message translates to:
  /// **'はみ出しを切らない'**
  String get composeMfmPropBorderNoclip;

  /// MFM の関数 ruby の説明
  ///
  /// In ja, this message translates to:
  /// **'ルビ(「本文 読み」の形で書く)'**
  String get composeMfmFnRuby;

  /// MFM の関数 ruby のプレビューに入れる見本(本文と読みを半角の空白で区切る)
  ///
  /// In ja, this message translates to:
  /// **'漢字 かんじ'**
  String get composeMfmSampleRuby;

  /// MFM の関数 unixtime の説明
  ///
  /// In ja, this message translates to:
  /// **'UNIX 時刻(秒)を日時で表示'**
  String get composeMfmFnUnixtime;

  /// MFM の関数 sparkle の説明
  ///
  /// In ja, this message translates to:
  /// **'きらきら'**
  String get composeMfmFnSparkle;

  /// MFM のアニメーションの関数のプロパティー delay の説明
  ///
  /// In ja, this message translates to:
  /// **'開始を遅らせる(例: 0.5s)'**
  String get composeMfmPropDelay;

  /// MFM の検索ブロック(「… 検索」の行)のボタン
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get composeMfmSearchButton;

  /// Markdown のスニペットの名前
  ///
  /// In ja, this message translates to:
  /// **'太字'**
  String get composeMfmMarkdownBoldName;

  /// Markdown のスニペットの説明
  ///
  /// In ja, this message translates to:
  /// **'**強調** で表示'**
  String get composeMfmMarkdownBoldDescription;

  /// Markdown のスニペットの名前
  ///
  /// In ja, this message translates to:
  /// **'斜体'**
  String get composeMfmMarkdownItalicName;

  /// Markdown のスニペットの説明
  ///
  /// In ja, this message translates to:
  /// **'*斜体* で表示'**
  String get composeMfmMarkdownItalicDescription;

  /// Markdown のスニペットの名前
  ///
  /// In ja, this message translates to:
  /// **'取り消し線'**
  String get composeMfmMarkdownStrikeName;

  /// Markdown のスニペットの説明
  ///
  /// In ja, this message translates to:
  /// **'~~取り消し~~ で表示'**
  String get composeMfmMarkdownStrikeDescription;

  /// Markdown のスニペットの名前
  ///
  /// In ja, this message translates to:
  /// **'インラインコード'**
  String get composeMfmMarkdownInlineCodeName;

  /// Markdown のスニペットの説明
  ///
  /// In ja, this message translates to:
  /// **'`コード` で表示'**
  String get composeMfmMarkdownInlineCodeDescription;

  /// Markdown のスニペットの名前
  ///
  /// In ja, this message translates to:
  /// **'コードブロック'**
  String get composeMfmMarkdownCodeBlockName;

  /// Markdown のスニペットの説明
  ///
  /// In ja, this message translates to:
  /// **'複数行のコードを枠で表示'**
  String get composeMfmMarkdownCodeBlockDescription;

  /// Markdown のスニペットの名前
  ///
  /// In ja, this message translates to:
  /// **'見出し'**
  String get composeMfmMarkdownHeadingName;

  /// Markdown のスニペットの説明
  ///
  /// In ja, this message translates to:
  /// **'行頭に # を付ける'**
  String get composeMfmMarkdownHeadingDescription;

  /// Markdown のスニペットの名前
  ///
  /// In ja, this message translates to:
  /// **'リンク'**
  String get composeMfmMarkdownLinkName;

  /// Markdown のスニペットの説明
  ///
  /// In ja, this message translates to:
  /// **'[表示名](URL) の形'**
  String get composeMfmMarkdownLinkDescription;

  /// No description provided for @composeMfmClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get composeMfmClose;

  /// MFM のプレビューに入れる見本の文
  ///
  /// In ja, this message translates to:
  /// **'サンプル'**
  String get composeMfmSample;

  /// MFM のプレビューに入れる見本の文。emoji はサーバーの絵文字(:name:)
  ///
  /// In ja, this message translates to:
  /// **'サンプル {emoji}'**
  String composeMfmSampleWithEmoji(String emoji);

  /// No description provided for @composeMfmBackTooltip.
  ///
  /// In ja, this message translates to:
  /// **'一覧へ戻る'**
  String get composeMfmBackTooltip;

  /// MFM / Markdown をコンポーザーに入れるボタン
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get composeMfmApply;

  /// No description provided for @composeMfmNoProps.
  ///
  /// In ja, this message translates to:
  /// **'この関数にプロパティーはありません。'**
  String get composeMfmNoProps;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'性的な表現'**
  String get composePolicyTypeSexual;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'暴力・脅し'**
  String get composePolicyTypeViolence;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'自傷・自殺'**
  String get composePolicyTypeSelfHarm;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'暴言・嫌がらせ'**
  String get composePolicyTypeHarassment;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'個人情報(電話番号・メールアドレス・住所など)'**
  String get composePolicyTypePersonalInfo;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'外部へのリンク'**
  String get composePolicyTypeLink;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'画像・動画'**
  String get composePolicyTypeMedia;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'強い言葉'**
  String get composePolicyTypeStimulus;

  /// 送る前の判定の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'決められた話題'**
  String get composePolicyTypeTopic;

  /// 送れない理由の主語(見守り)
  ///
  /// In ja, this message translates to:
  /// **'保護者の設定'**
  String get composePolicyWhoGuardian;

  /// 送れない理由の主語(アカウントの処置)
  ///
  /// In ja, this message translates to:
  /// **'アカウントの制限'**
  String get composePolicyWhoSanction;

  /// who は「保護者の設定」/「アカウントの制限」
  ///
  /// In ja, this message translates to:
  /// **'{who}により、画像・動画は送れません(この端末では添付の確認ができません)。添付を外してください'**
  String composePolicyBlockedMediaUnmeasured(String who);

  /// who は「保護者の設定」/「アカウントの制限」、label は種類の名前
  ///
  /// In ja, this message translates to:
  /// **'{who}により、いまは送れません(この端末では「{label}」の確認ができません)'**
  String composePolicyBlockedUnmeasured(String who, String label);

  /// who は「保護者の設定」/「アカウントの制限」、label は種類の名前
  ///
  /// In ja, this message translates to:
  /// **'{who}により、「{label}」に当たる内容は送れません。書き換えてください'**
  String composePolicyBlocked(String who, String label);

  /// who は「保護者の設定」/「アカウントの制限」、label は種類の名前
  ///
  /// In ja, this message translates to:
  /// **'「{label}」に当たるかもしれません({who})。このまま送りますか?'**
  String composePolicyWarn(String label, String who);

  /// ストアのプラグインページの共有メニュー。room は参加中の AsTell のルームの名前
  ///
  /// In ja, this message translates to:
  /// **'「{room}」に追加'**
  String customShareAddToRoom(String room);

  /// No description provided for @customShareProposeToRoom.
  ///
  /// In ja, this message translates to:
  /// **'「{room}」で提案'**
  String customShareProposeToRoom(String room);

  /// No description provided for @customSharePlaceOnProfile.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールに置く'**
  String get customSharePlaceOnProfile;

  /// No description provided for @customShareInviteBySwing.
  ///
  /// In ja, this message translates to:
  /// **'Swing で招待(みんなで使う)'**
  String get customShareInviteBySwing;

  /// No description provided for @customShareInstallToShare.
  ///
  /// In ja, this message translates to:
  /// **'インストールするとプロフィールや招待で共有できます'**
  String get customShareInstallToShare;

  /// name はプラグインの名前
  ///
  /// In ja, this message translates to:
  /// **'「{name}」をルームに追加しました'**
  String customAddedToRoom(String name);

  /// No description provided for @customAddToRoomFailed.
  ///
  /// In ja, this message translates to:
  /// **'追加できませんでした: {error}'**
  String customAddToRoomFailed(String error);

  /// No description provided for @customShareProposedToRoom.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」をルームで提案しました'**
  String customShareProposedToRoom(String name);

  /// No description provided for @customSharePlacedOnProfile.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールに置きました'**
  String get customSharePlacedOnProfile;

  /// No description provided for @customPlaceFailed.
  ///
  /// In ja, this message translates to:
  /// **'置けませんでした: {error}'**
  String customPlaceFailed(String error);

  /// count は RASQ の通知でも知らせた人の数
  ///
  /// In ja, this message translates to:
  /// **'Swing で招待しました(RASQ の通知 {count, plural, other{{count} 人}})'**
  String customInvitedBySwingNotified(int count);

  /// No description provided for @customInvitedBySwing.
  ///
  /// In ja, this message translates to:
  /// **'Swing で招待しました'**
  String get customInvitedBySwing;

  /// No description provided for @customInviteTitle.
  ///
  /// In ja, this message translates to:
  /// **'Swing で招待'**
  String get customInviteTitle;

  /// No description provided for @customInviteSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'送れませんでした: {error}'**
  String customInviteSendFailed(String error);

  /// title はプラグインのページの名前
  ///
  /// In ja, this message translates to:
  /// **'「{title}」に招待'**
  String customInviteHeading(String title);

  /// No description provided for @customInviteIntroOwnPage.
  ///
  /// In ja, this message translates to:
  /// **'Swing で届けます。見た人は、あなたのページに一緒に入ります。'**
  String get customInviteIntroOwnPage;

  /// No description provided for @customInviteIntroCurrentPage.
  ///
  /// In ja, this message translates to:
  /// **'Swing で届けます。見た人は、いま開いているページに一緒に入ります。'**
  String get customInviteIntroCurrentPage;

  /// No description provided for @customInviteHelp.
  ///
  /// In ja, this message translates to:
  /// **'届け先: 押す = Swing を届ける ・ 2 回続けて押す = RASQ の通知でも知らせる 🔔'**
  String get customInviteHelp;

  /// No description provided for @customInviteFollowers.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get customInviteFollowers;

  /// No description provided for @customInviteNoLists.
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストを作ると、リストに入れた人も招待できます'**
  String get customInviteNoLists;

  /// No description provided for @customInviteTextHint.
  ///
  /// In ja, this message translates to:
  /// **'ひとこと(なくてもよい)'**
  String get customInviteTextHint;

  /// No description provided for @customInviteTtl.
  ///
  /// In ja, this message translates to:
  /// **'消えるまで'**
  String get customInviteTtl;

  /// No description provided for @customInviteTtlHours.
  ///
  /// In ja, this message translates to:
  /// **'{hours, plural, other{{hours} 時間}}'**
  String customInviteTtlHours(int hours);

  /// No description provided for @customInviteSendWithNotify.
  ///
  /// In ja, this message translates to:
  /// **'Swing で招待(通知も送る)'**
  String get customInviteSendWithNotify;

  /// No description provided for @customInviteErrorVersionNotAvailable.
  ///
  /// In ja, this message translates to:
  /// **'このプラグインは、つないでいる RASQ サーバーのストアで配られていません(審査を通った版がありません)。アプリに入っているサンプルのままでは、みんなで使えません'**
  String get customInviteErrorVersionNotAvailable;

  /// No description provided for @customInviteErrorNotShared.
  ///
  /// In ja, this message translates to:
  /// **'みんなで使うプラグインではありません'**
  String get customInviteErrorNotShared;

  /// No description provided for @customInviteErrorSessionNotShareable.
  ///
  /// In ja, this message translates to:
  /// **'このページのセッションは Swing では招待できません'**
  String get customInviteErrorSessionNotShareable;

  /// No description provided for @customInviteErrorSwingLimit.
  ///
  /// In ja, this message translates to:
  /// **'同時に出しておける Swing は 20 個までです'**
  String get customInviteErrorSwingLimit;

  /// 届け先のボタンの読み上げ。label はフォロワー / リストの名前
  ///
  /// In ja, this message translates to:
  /// **'{label}(通知も送る)'**
  String customInviteTargetWithNotify(String label);

  /// No description provided for @customInviteTargetHint.
  ///
  /// In ja, this message translates to:
  /// **'押すと選ぶ / 外す。2 回続けて押すと、通知も送る'**
  String get customInviteTargetHint;

  /// No description provided for @customProfileLimit.
  ///
  /// In ja, this message translates to:
  /// **'ページに置けるのは 8 個までです'**
  String get customProfileLimit;

  /// No description provided for @customProfileSideloadReplace.
  ///
  /// In ja, this message translates to:
  /// **'上げ直す(新しい版)'**
  String get customProfileSideloadReplace;

  /// No description provided for @customProfileSideloadRemove.
  ///
  /// In ja, this message translates to:
  /// **'ページから外す'**
  String get customProfileSideloadRemove;

  /// No description provided for @customProfileRemoveFailed.
  ///
  /// In ja, this message translates to:
  /// **'外せませんでした: {error}'**
  String customProfileRemoveFailed(String error);

  /// No description provided for @customLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした: {error}'**
  String customLoadFailed(String error);

  /// No description provided for @customProfileEmptyMine.
  ///
  /// In ja, this message translates to:
  /// **'「+ 追加」で Markdown のページや、カスタムプラグインを置けます。訪れた人がここから開けます。'**
  String get customProfileEmptyMine;

  /// No description provided for @customProfileEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ページはまだありません。'**
  String get customProfileEmpty;

  /// No description provided for @customProfileSharedNotStarted.
  ///
  /// In ja, this message translates to:
  /// **'みんなで使う(まだ始まっていません)'**
  String get customProfileSharedNotStarted;

  /// No description provided for @customProfileShared.
  ///
  /// In ja, this message translates to:
  /// **'みんなで使う'**
  String get customProfileShared;

  /// No description provided for @customSolo.
  ///
  /// In ja, this message translates to:
  /// **'1 人で使う'**
  String get customSolo;

  /// title はプラグインのページの名前
  ///
  /// In ja, this message translates to:
  /// **'{title} のホスト用ページ'**
  String customProfileHostPage(String title);

  /// No description provided for @customProfileHostPageSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'あなたにだけ出ます'**
  String get customProfileHostPageSubtitle;

  /// No description provided for @customProfileMdPageWithDraft.
  ///
  /// In ja, this message translates to:
  /// **'ページ ・ 書きかけの下書きあり'**
  String get customProfileMdPageWithDraft;

  /// No description provided for @customProfileMdPage.
  ///
  /// In ja, this message translates to:
  /// **'ページ'**
  String get customProfileMdPage;

  /// No description provided for @customProfileUntitled.
  ///
  /// In ja, this message translates to:
  /// **'(無題)'**
  String get customProfileUntitled;

  /// No description provided for @customProfileDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書き(この端末だけ)'**
  String get customProfileDraft;

  /// No description provided for @customProfileSideloadSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'自作プラグイン ・ 制限モード ・ v{version}'**
  String customProfileSideloadSubtitle(String version);

  /// No description provided for @customMenu.
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get customMenu;

  /// No description provided for @customProfileAdd.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get customProfileAdd;

  /// No description provided for @customProfileLoginToPlace.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインすると置けます'**
  String get customProfileLoginToPlace;

  /// No description provided for @customProfileSideloadPlaced.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を置きました(訪れた人の端末では制限モードで動きます)'**
  String customProfileSideloadPlaced(String name);

  /// No description provided for @customProfileSideloadErrorNotProfilePage.
  ///
  /// In ja, this message translates to:
  /// **'RASQ のページに置けるのは、プロフィールの面を持つ 1 人で使うページ型だけです'**
  String get customProfileSideloadErrorNotProfilePage;

  /// No description provided for @customProfileSideloadErrorLimit.
  ///
  /// In ja, this message translates to:
  /// **'自作プラグインは 4 つまでです'**
  String get customProfileSideloadErrorLimit;

  /// No description provided for @customProfileSideloadErrorInvalidPackage.
  ///
  /// In ja, this message translates to:
  /// **'配布物を読めませんでした(.rspkg / .rasqpkg)'**
  String get customProfileSideloadErrorInvalidPackage;

  /// No description provided for @customClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get customClose;

  /// No description provided for @customProfileAddTitle.
  ///
  /// In ja, this message translates to:
  /// **'ページを追加'**
  String get customProfileAddTitle;

  /// No description provided for @customProfileAddMd.
  ///
  /// In ja, this message translates to:
  /// **'Markdown のページを書く'**
  String get customProfileAddMd;

  /// No description provided for @customProfileAddMdSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'下書きはこの端末に残し、「公開」で出します。MFM は HTML 風のタグで'**
  String get customProfileAddMdSubtitle;

  /// No description provided for @customProfileAddSideload.
  ///
  /// In ja, this message translates to:
  /// **'自作プラグインを置く(.rspkg / .rasqpkg)'**
  String get customProfileAddSideload;

  /// No description provided for @customProfileAddSideloadSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'審査していないプラグイン。訪れた人の端末では制限モード(通信などなし)で動きます'**
  String get customProfileAddSideloadSubtitle;

  /// No description provided for @customProfileAddStoreSection.
  ///
  /// In ja, this message translates to:
  /// **'ストアのカスタムプラグイン'**
  String get customProfileAddStoreSection;

  /// No description provided for @customProfileAddStoreEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ページに置けるカスタムプラグインを入れていません'**
  String get customProfileAddStoreEmpty;

  /// No description provided for @customProfileAddStorePlaced.
  ///
  /// In ja, this message translates to:
  /// **'置いています(押すと外す)'**
  String get customProfileAddStorePlaced;

  /// No description provided for @customProfileAddStoreTapToPlace.
  ///
  /// In ja, this message translates to:
  /// **'押すと置く'**
  String get customProfileAddStoreTapToPlace;

  /// No description provided for @customProfileAddStoreHasHostPage.
  ///
  /// In ja, this message translates to:
  /// **'ホスト用ページあり'**
  String get customProfileAddStoreHasHostPage;

  /// 一覧の補足の項目をつなぐ区切り
  ///
  /// In ja, this message translates to:
  /// **' ・ '**
  String get customListSeparator;

  /// No description provided for @customProfileChangeFailed.
  ///
  /// In ja, this message translates to:
  /// **'変えられませんでした: {error}'**
  String customProfileChangeFailed(String error);

  /// No description provided for @customSearchStore.
  ///
  /// In ja, this message translates to:
  /// **'ストアで探す'**
  String get customSearchStore;

  /// No description provided for @customPluginsTitle.
  ///
  /// In ja, this message translates to:
  /// **'カスタムプラグイン'**
  String get customPluginsTitle;

  /// No description provided for @customPluginsJoinByCode.
  ///
  /// In ja, this message translates to:
  /// **'招待コードで参加'**
  String get customPluginsJoinByCode;

  /// No description provided for @customPluginsInviteCode.
  ///
  /// In ja, this message translates to:
  /// **'招待コード'**
  String get customPluginsInviteCode;

  /// No description provided for @customPluginsJoin.
  ///
  /// In ja, this message translates to:
  /// **'参加'**
  String get customPluginsJoin;

  /// No description provided for @customPluginsInstalled.
  ///
  /// In ja, this message translates to:
  /// **'インストール済み'**
  String get customPluginsInstalled;

  /// No description provided for @customPluginsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだありません。ストアの「カスタム」から探せます。'**
  String get customPluginsEmpty;

  /// No description provided for @customPluginsShared.
  ///
  /// In ja, this message translates to:
  /// **'みんなで使える'**
  String get customPluginsShared;

  /// No description provided for @customPluginsProfile.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール'**
  String get customPluginsProfile;

  /// No description provided for @customPluginsSearchStore.
  ///
  /// In ja, this message translates to:
  /// **'ストアでカスタムプラグインを探す'**
  String get customPluginsSearchStore;

  /// No description provided for @customPluginsInviteNotFound.
  ///
  /// In ja, this message translates to:
  /// **'この招待コードのセッションは見つかりません(閉じられたかもしれません)'**
  String get customPluginsInviteNotFound;

  /// No description provided for @customPluginsInviteTitle.
  ///
  /// In ja, this message translates to:
  /// **'招待'**
  String get customPluginsInviteTitle;

  /// No description provided for @customPluginsJoinFailed.
  ///
  /// In ja, this message translates to:
  /// **'参加できませんでした'**
  String get customPluginsJoinFailed;

  /// No description provided for @customPageLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした'**
  String get customPageLoadFailed;

  /// name はプラグインの名前
  ///
  /// In ja, this message translates to:
  /// **'{name} はページ型のプラグインではありません'**
  String customPageNotPagePlugin(String name);

  /// No description provided for @customPageSoloPlugin.
  ///
  /// In ja, this message translates to:
  /// **'{name} は 1 人で使うプラグインです(みんなでは使えません)'**
  String customPageSoloPlugin(String name);

  /// No description provided for @customPageJoinFailed.
  ///
  /// In ja, this message translates to:
  /// **'セッションに入れませんでした: {error}'**
  String customPageJoinFailed(String error);

  /// No description provided for @customPageNoPage.
  ///
  /// In ja, this message translates to:
  /// **'プラグインがページを返しませんでした'**
  String get customPageNoPage;

  /// No description provided for @customPageWrongSession.
  ///
  /// In ja, this message translates to:
  /// **'{name} のセッションではありません'**
  String customPageWrongSession(String name);

  /// No description provided for @customPageLeftWrongSession.
  ///
  /// In ja, this message translates to:
  /// **'{name} のセッションではないため抜けました'**
  String customPageLeftWrongSession(String name);

  /// No description provided for @customPageDisconnectedWithError.
  ///
  /// In ja, this message translates to:
  /// **'接続が切れました: {error}'**
  String customPageDisconnectedWithError(String error);

  /// No description provided for @customPageDisconnected.
  ///
  /// In ja, this message translates to:
  /// **'接続が切れました'**
  String get customPageDisconnected;

  /// サーバーが文を付けずに誤りを知らせたときの既定
  ///
  /// In ja, this message translates to:
  /// **'エラー'**
  String get customPageError;

  /// No description provided for @customPageMenuInvite.
  ///
  /// In ja, this message translates to:
  /// **'招待(Swing で送る)'**
  String get customPageMenuInvite;

  /// No description provided for @customPageMenuCopyCode.
  ///
  /// In ja, this message translates to:
  /// **'招待コードをコピー'**
  String get customPageMenuCopyCode;

  /// No description provided for @customPageMenuCopyLink.
  ///
  /// In ja, this message translates to:
  /// **'招待リンクをコピー'**
  String get customPageMenuCopyLink;

  /// No description provided for @customPageMenuParticipants.
  ///
  /// In ja, this message translates to:
  /// **'参加者({count})'**
  String customPageMenuParticipants(int count);

  /// No description provided for @customPageMenuCloseSession.
  ///
  /// In ja, this message translates to:
  /// **'セッションを閉じる'**
  String get customPageMenuCloseSession;

  /// No description provided for @customPageViewInStore.
  ///
  /// In ja, this message translates to:
  /// **'ストアで見る'**
  String get customPageViewInStore;

  /// No description provided for @customPageCodeCopied.
  ///
  /// In ja, this message translates to:
  /// **'招待コード {code} をコピーしました'**
  String customPageCodeCopied(String code);

  /// No description provided for @customPageLinkCopied.
  ///
  /// In ja, this message translates to:
  /// **'招待リンクをコピーしました'**
  String get customPageLinkCopied;

  /// No description provided for @customPageParticipants.
  ///
  /// In ja, this message translates to:
  /// **'参加者'**
  String get customPageParticipants;

  /// No description provided for @customPageCloseConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'セッションを閉じますか?'**
  String get customPageCloseConfirmTitle;

  /// No description provided for @customPageCloseConfirmMessage.
  ///
  /// In ja, this message translates to:
  /// **'参加している全員のページで、共有の値が止まります。'**
  String get customPageCloseConfirmMessage;

  /// No description provided for @customCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get customCancel;

  /// No description provided for @customPageCloseFailed.
  ///
  /// In ja, this message translates to:
  /// **'閉じられませんでした: {error}'**
  String customPageCloseFailed(String error);

  /// No description provided for @customPageClosedBanner.
  ///
  /// In ja, this message translates to:
  /// **'このセッションは閉じられました(共有の値はもう変わりません)'**
  String get customPageClosedBanner;

  /// No description provided for @customPageConsentBody.
  ///
  /// In ja, this message translates to:
  /// **'このページを開いている間だけ、インストールせずに動かします(閉じると消えます)。'**
  String get customPageConsentBody;

  /// No description provided for @customPageConsentPermissions.
  ///
  /// In ja, this message translates to:
  /// **'使う権限'**
  String get customPageConsentPermissions;

  /// No description provided for @customPageConsentAccept.
  ///
  /// In ja, this message translates to:
  /// **'使う'**
  String get customPageConsentAccept;

  /// No description provided for @customPageConsentDecline.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get customPageConsentDecline;

  /// No description provided for @customPageNotInstalled.
  ///
  /// In ja, this message translates to:
  /// **'インストールされていません'**
  String get customPageNotInstalled;

  /// No description provided for @customPageNotInstalledHint.
  ///
  /// In ja, this message translates to:
  /// **'ストアからインストールすると開けます'**
  String get customPageNotInstalledHint;

  /// No description provided for @customPageOpenFailed.
  ///
  /// In ja, this message translates to:
  /// **'開けませんでした'**
  String get customPageOpenFailed;

  /// No description provided for @customClientHostOnly.
  ///
  /// In ja, this message translates to:
  /// **'ホストだけがデプロイできます'**
  String get customClientHostOnly;

  /// No description provided for @customClientSessionClosed.
  ///
  /// In ja, this message translates to:
  /// **'セッションが閉じています'**
  String get customClientSessionClosed;

  /// No description provided for @customClientNoToken.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントのトークンがありません'**
  String get customClientNoToken;

  /// No description provided for @customAstellWaitingApproval.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」はホストの承認を待っています'**
  String customAstellWaitingApproval(String name);

  /// No description provided for @customAstellApproveTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」をこのルームで使いますか?'**
  String customAstellApproveTitle(String name);

  /// name は提案した人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} さんからの提案です。承認すると、参加している全員が開けるようになります(インストールしていない人は、開くときに一時的に読み込みます)。'**
  String customAstellApproveMessage(String name);

  /// No description provided for @customAstellApprove.
  ///
  /// In ja, this message translates to:
  /// **'承認する'**
  String get customAstellApprove;

  /// No description provided for @customAstellProposed.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を提案しました(ホストが承認すると使えます)'**
  String customAstellProposed(String name);

  /// No description provided for @customAstellEmptyHost.
  ///
  /// In ja, this message translates to:
  /// **'このルームで動くプラグインはまだありません。下の「プラグインを追加」から足せます。'**
  String get customAstellEmptyHost;

  /// No description provided for @customAstellEmptyMember.
  ///
  /// In ja, this message translates to:
  /// **'このルームで動くプラグインはまだありません。「プラグインを提案」でホストに頼めます。'**
  String get customAstellEmptyMember;

  /// No description provided for @customAstellInUse.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 人が使用中}}'**
  String customAstellInUse(int count);

  /// handle はルームに追加した人のハンドル(@ なし)
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 人が使用中}} ・ @{handle} が追加'**
  String customAstellInUseAddedBy(int count, String handle);

  /// No description provided for @customAstellOpen.
  ///
  /// In ja, this message translates to:
  /// **'開く'**
  String get customAstellOpen;

  /// No description provided for @customAstellRemove.
  ///
  /// In ja, this message translates to:
  /// **'ルームから外す'**
  String get customAstellRemove;

  /// No description provided for @customAstellAdd.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを追加'**
  String get customAstellAdd;

  /// No description provided for @customAstellPropose.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを提案'**
  String get customAstellPropose;

  /// ＋ のボタンに置いた投稿のアカウントが、もうログインしていないとき
  ///
  /// In ja, this message translates to:
  /// **'(いないアカウント)'**
  String get homeCreateMissingAccount;

  /// No description provided for @homeCreatePost.
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get homeCreatePost;

  /// No description provided for @homeCreateNone.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get homeCreateNone;

  /// label はボタンの名前(RASQ / Swing)
  ///
  /// In ja, this message translates to:
  /// **'{label}には RASQ アカウントが要ります'**
  String homeCreateNeedsRasqAccount(String label);

  /// No description provided for @homeCreateAstellBlocked.
  ///
  /// In ja, this message translates to:
  /// **'見守りの設定で ASTell が止められています'**
  String get homeCreateAstellBlocked;

  /// No description provided for @homeCreateAccountGone.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントはもうありません'**
  String get homeCreateAccountGone;

  /// No description provided for @homeCreate.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get homeCreate;

  /// No description provided for @homeClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get homeClose;

  /// No description provided for @homeFabEditorTitle.
  ///
  /// In ja, this message translates to:
  /// **'＋ のボタン'**
  String get homeFabEditorTitle;

  /// count は置いている数、max は置ける数
  ///
  /// In ja, this message translates to:
  /// **'下のボタンを枠へドラッグすると入ります(枠どうしは入れ替え、下の列へ戻すと外れます)。内側に 3 つ、外側に 4 つまで ・ {count} / {max}'**
  String homeFabEditorHelp(int count, int max);

  /// No description provided for @homeHeaderCollapse.
  ///
  /// In ja, this message translates to:
  /// **'ヘッダーをしまう'**
  String get homeHeaderCollapse;

  /// No description provided for @homeTimelineTemp.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインを一時変更'**
  String get homeTimelineTemp;

  /// No description provided for @homeTimelineSettings.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン設定'**
  String get homeTimelineSettings;

  /// No description provided for @homeTabRecommended.
  ///
  /// In ja, this message translates to:
  /// **'おすすめ'**
  String get homeTabRecommended;

  /// No description provided for @homeEmpty.
  ///
  /// In ja, this message translates to:
  /// **'投稿はありません'**
  String get homeEmpty;

  /// No description provided for @homePullToRefresh.
  ///
  /// In ja, this message translates to:
  /// **'下に引っ張って更新'**
  String get homePullToRefresh;

  /// No description provided for @homeLoadNewer.
  ///
  /// In ja, this message translates to:
  /// **'新しい投稿を読み込む'**
  String get homeLoadNewer;

  /// TL を更新して新しい投稿が届いたとき、ヘッダーのすぐ下に浮かべる札(左に投稿した人の顔が並ぶ)
  ///
  /// In ja, this message translates to:
  /// **'新しい投稿'**
  String get homeNewPostsPill;

  /// 「新しい投稿」の札の読み上げ。押すといちばん上へ送る
  ///
  /// In ja, this message translates to:
  /// **'新しい投稿を見る'**
  String get homeNewPostsPillSemantics;

  /// No description provided for @homeLoadingNewer.
  ///
  /// In ja, this message translates to:
  /// **'更新しています…'**
  String get homeLoadingNewer;

  /// No description provided for @homeLoadMoreFailed.
  ///
  /// In ja, this message translates to:
  /// **'読み込みに失敗しました。再試行'**
  String get homeLoadMoreFailed;

  /// No description provided for @homeLoadMore.
  ///
  /// In ja, this message translates to:
  /// **'続きを読み込む'**
  String get homeLoadMore;

  /// No description provided for @homeLoadingMore.
  ///
  /// In ja, this message translates to:
  /// **'読み込んでいます…'**
  String get homeLoadingMore;

  /// No description provided for @homeReload.
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get homeReload;

  /// ヘッダーの Swing の輪の説明。name は出した人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} の Swing'**
  String homeSwingOf(String name);

  /// No description provided for @homeSwingOfSeen.
  ///
  /// In ja, this message translates to:
  /// **'{name} の Swing(見終えました)'**
  String homeSwingOfSeen(String name);

  /// No description provided for @homeMySwingCount.
  ///
  /// In ja, this message translates to:
  /// **'自分の Swing({count, plural, other{{count} 個}})'**
  String homeMySwingCount(int count);

  /// No description provided for @homeMySwing.
  ///
  /// In ja, this message translates to:
  /// **'自分の Swing'**
  String get homeMySwing;

  /// No description provided for @homeLiveNoToken.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントのトークンがありません'**
  String get homeLiveNoToken;

  /// リプライ元の投稿の添付のまとめ
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件の添付ファイル}}'**
  String homePostAttachmentFiles(int count);

  /// No description provided for @homePostAttachmentLink.
  ///
  /// In ja, this message translates to:
  /// **'1件の添付リンク'**
  String get homePostAttachmentLink;

  /// No description provided for @homePostShare.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get homePostShare;

  /// No description provided for @homePostSelectAccount.
  ///
  /// In ja, this message translates to:
  /// **'アカウント選択'**
  String get homePostSelectAccount;

  /// No description provided for @homePostLike.
  ///
  /// In ja, this message translates to:
  /// **'いいね'**
  String get homePostLike;

  /// No description provided for @homePostReaction.
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get homePostReaction;

  /// リノート / 引用ノートの行の名前の後ろ。どのアカウントで行うか(handle@instance)
  ///
  /// In ja, this message translates to:
  /// **'(@{handle}@{instance} で)'**
  String homePostRepostVia(String handle, String instance);

  /// No description provided for @homePostUndoRepost.
  ///
  /// In ja, this message translates to:
  /// **'リノートを取り消す'**
  String get homePostUndoRepost;

  /// 注釈(CW)つきの投稿を 1 行で見せるとき。cw は注釈の文
  ///
  /// In ja, this message translates to:
  /// **'【CW: {cw}】'**
  String homePostCw(String cw);

  /// No description provided for @homePostAttachments.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件の添付}}'**
  String homePostAttachments(int count);

  /// No description provided for @homeActionReply.
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get homeActionReply;

  /// No description provided for @homeActionRebroad.
  ///
  /// In ja, this message translates to:
  /// **'リブロード'**
  String get homeActionRebroad;

  /// No description provided for @homeActionQueue.
  ///
  /// In ja, this message translates to:
  /// **'キュー'**
  String get homeActionQueue;

  /// No description provided for @homeEditorCropRotate.
  ///
  /// In ja, this message translates to:
  /// **'クロップ / 回転'**
  String get homeEditorCropRotate;

  /// No description provided for @homeEditorPaint.
  ///
  /// In ja, this message translates to:
  /// **'ペイント'**
  String get homeEditorPaint;

  /// No description provided for @homeEditorText.
  ///
  /// In ja, this message translates to:
  /// **'テキスト'**
  String get homeEditorText;

  /// No description provided for @homeEditorPost.
  ///
  /// In ja, this message translates to:
  /// **'ノート'**
  String get homeEditorPost;

  /// No description provided for @homeEditorMedia.
  ///
  /// In ja, this message translates to:
  /// **'メディア'**
  String get homeEditorMedia;

  /// No description provided for @homeEditorSticker.
  ///
  /// In ja, this message translates to:
  /// **'ステッカー'**
  String get homeEditorSticker;

  /// No description provided for @homeEditorEmoji.
  ///
  /// In ja, this message translates to:
  /// **'絵文字'**
  String get homeEditorEmoji;

  /// No description provided for @homeEditorFilter.
  ///
  /// In ja, this message translates to:
  /// **'フィルター'**
  String get homeEditorFilter;

  /// No description provided for @homeEditorBlur.
  ///
  /// In ja, this message translates to:
  /// **'ぼかし'**
  String get homeEditorBlur;

  /// No description provided for @homeEditorTune.
  ///
  /// In ja, this message translates to:
  /// **'調整'**
  String get homeEditorTune;

  /// No description provided for @homeActionAutoOn.
  ///
  /// In ja, this message translates to:
  /// **'次からも自動でオン'**
  String get homeActionAutoOn;

  /// No description provided for @homeActionAutoOff.
  ///
  /// In ja, this message translates to:
  /// **'次からも自動でオフ'**
  String get homeActionAutoOff;

  /// No description provided for @homeActionAutoReset.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの既定に戻す'**
  String get homeActionAutoReset;

  /// 子の端末で見守りの時間のあいだ、ホームに出る 1 本のタイムラインのタブの名前
  ///
  /// In ja, this message translates to:
  /// **'見守りの時間'**
  String get homeChildSafeWindowTab;

  /// No description provided for @homeCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get homeCancel;

  /// No description provided for @homeBarPost.
  ///
  /// In ja, this message translates to:
  /// **'投稿アクションバー'**
  String get homeBarPost;

  /// No description provided for @homeBarViewer.
  ///
  /// In ja, this message translates to:
  /// **'全画面アクションバー'**
  String get homeBarViewer;

  /// No description provided for @homeBarEditorImage.
  ///
  /// In ja, this message translates to:
  /// **'加工画面のバー(画像)'**
  String get homeBarEditorImage;

  /// No description provided for @homeBarEditorVideo.
  ///
  /// In ja, this message translates to:
  /// **'加工画面のバー(動画 / 音声)'**
  String get homeBarEditorVideo;

  /// No description provided for @homeBarEditorSvg.
  ///
  /// In ja, this message translates to:
  /// **'加工画面のバー(SVG)'**
  String get homeBarEditorSvg;

  /// No description provided for @homeBarRasqViewer.
  ///
  /// In ja, this message translates to:
  /// **'全画面アクションバー(Swing)'**
  String get homeBarRasqViewer;

  /// No description provided for @homeBarAstell.
  ///
  /// In ja, this message translates to:
  /// **'ASTell のルームの下段'**
  String get homeBarAstell;

  /// No description provided for @homeBarEditAstellTitle.
  ///
  /// In ja, this message translates to:
  /// **'ルームのボタンの編集'**
  String get homeBarEditAstellTitle;

  /// No description provided for @homeBarEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'アクションバーの編集'**
  String get homeBarEditTitle;

  /// No description provided for @homeBarSearchPlugins.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを検索'**
  String get homeBarSearchPlugins;

  /// No description provided for @homeBarSearchPluginButtons.
  ///
  /// In ja, this message translates to:
  /// **'プラグインボタンを検索'**
  String get homeBarSearchPluginButtons;

  /// ボタンを検索する FOW の行の補足。source は出どころ(プラグインの名前 / SNS のアクション など)、detail はジャンルや種類
  ///
  /// In ja, this message translates to:
  /// **'{source} · {detail}'**
  String homeBarSearchSubtitle(String source, String detail);

  /// No description provided for @homeBarBuiltinEditor.
  ///
  /// In ja, this message translates to:
  /// **'内蔵の編集'**
  String get homeBarBuiltinEditor;

  /// No description provided for @homeBarRasqActions.
  ///
  /// In ja, this message translates to:
  /// **'RASQ のアクション'**
  String get homeBarRasqActions;

  /// No description provided for @homeBarAstellButtons.
  ///
  /// In ja, this message translates to:
  /// **'ASTell のボタン'**
  String get homeBarAstellButtons;

  /// No description provided for @homeBarSnsActions.
  ///
  /// In ja, this message translates to:
  /// **'SNS のアクション'**
  String get homeBarSnsActions;

  /// No description provided for @homeBarViewerTogglePlugin.
  ///
  /// In ja, this message translates to:
  /// **'全画面表示プラグイン(ON / OFF のボタン)'**
  String get homeBarViewerTogglePlugin;

  /// No description provided for @homeBarAstellPlugin.
  ///
  /// In ja, this message translates to:
  /// **'ASTell プラグイン(押すとそのプラグインを開く)'**
  String get homeBarAstellPlugin;

  /// No description provided for @homeBarPluginTags.
  ///
  /// In ja, this message translates to:
  /// **'タグ: {tags}'**
  String homeBarPluginTags(String tags);

  /// No description provided for @homeBarManualPlacement.
  ///
  /// In ja, this message translates to:
  /// **' · 手動配置'**
  String get homeBarManualPlacement;

  /// No description provided for @homeBarAllGenres.
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get homeBarAllGenres;

  /// No description provided for @homeBarSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'ボタン名 / プラグイン名 / タグ'**
  String get homeBarSearchHint;

  /// No description provided for @homeBarSearchEmptyAstell.
  ///
  /// In ja, this message translates to:
  /// **'追加できるボタンがありません。プラグインはストアから追加できます'**
  String get homeBarSearchEmptyAstell;

  /// No description provided for @homeBarSearchEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ここに置けるプラグインがありません。ストアから追加できます'**
  String get homeBarSearchEmpty;

  /// 開発者モードの詳しい説明。composer.media はスロットの名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'composer.media を宣言したプラグインがありません(ストアから追加)'**
  String get homeBarSearchEmptyEditorDetail;

  /// 開発者モードの詳しい説明。astell.action はスロットの名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'非表示にしたボタン / ASTell のプラグイン(astell.action)がありません(プラグインはストアから追加)'**
  String get homeBarSearchEmptyAstellDetail;

  /// 開発者モードの詳しい説明。post.action はスロットの名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'全画面表示プラグイン / post.action を宣言したプラグインがありません(ストアから追加)'**
  String get homeBarSearchEmptyViewerDetail;

  /// 開発者モードの詳しい説明。post.action はスロットの名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'post.action を宣言したプラグインがありません(ストアから追加)'**
  String get homeBarSearchEmptyPostDetail;

  /// No description provided for @homeBarSearchNoHits.
  ///
  /// In ja, this message translates to:
  /// **'見つかりません'**
  String get homeBarSearchNoHits;

  /// No description provided for @homeBarDetailTitle.
  ///
  /// In ja, this message translates to:
  /// **'アクションの詳細'**
  String get homeBarDetailTitle;

  /// No description provided for @homeBarDetailUnknownDeveloper.
  ///
  /// In ja, this message translates to:
  /// **'提供元不明'**
  String get homeBarDetailUnknownDeveloper;

  /// rating は評価(小数 1 桁の文字)、downloads はダウンロード数
  ///
  /// In ja, this message translates to:
  /// **'★{rating} ・ {downloads} DL'**
  String homeBarDetailStats(String rating, int downloads);

  /// No description provided for @homeBarDetailAction.
  ///
  /// In ja, this message translates to:
  /// **'アクション'**
  String get homeBarDetailAction;

  /// No description provided for @homeBarDetailSlot.
  ///
  /// In ja, this message translates to:
  /// **'スロット(ジャンル)'**
  String get homeBarDetailSlot;

  /// No description provided for @homeBarDetailConfirm.
  ///
  /// In ja, this message translates to:
  /// **'確認'**
  String get homeBarDetailConfirm;

  /// No description provided for @homeBarDetailAutomation.
  ///
  /// In ja, this message translates to:
  /// **'自動化'**
  String get homeBarDetailAutomation;

  /// No description provided for @homeBarDetailTags.
  ///
  /// In ja, this message translates to:
  /// **'タグ'**
  String get homeBarDetailTags;

  /// No description provided for @homeBarIconSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'アイコン名で検索(例: star, bolt)'**
  String get homeBarIconSearchHint;

  /// No description provided for @homeBarBundleTitle.
  ///
  /// In ja, this message translates to:
  /// **'バンドルの設定'**
  String get homeBarBundleTitle;

  /// No description provided for @homeBarBundleDissolved.
  ///
  /// In ja, this message translates to:
  /// **'解除しました'**
  String get homeBarBundleDissolved;

  /// No description provided for @homeBarPlugin.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get homeBarPlugin;

  /// No description provided for @homeBarBundleAstellMember.
  ///
  /// In ja, this message translates to:
  /// **'ルームの下段のボタン({label})'**
  String homeBarBundleAstellMember(String label);

  /// genre はアクションのジャンル(英字のタグ)
  ///
  /// In ja, this message translates to:
  /// **'SNS プラグインが提供するアクション({genre})'**
  String homeBarBundleSnsMember(String genre);

  /// No description provided for @homeBarBundleName.
  ///
  /// In ja, this message translates to:
  /// **'リスト名'**
  String get homeBarBundleName;

  /// No description provided for @homeBarBundleIcon.
  ///
  /// In ja, this message translates to:
  /// **'アイコン'**
  String get homeBarBundleIcon;

  /// No description provided for @homeBarBundlePhoto.
  ///
  /// In ja, this message translates to:
  /// **'写真'**
  String get homeBarBundlePhoto;

  /// No description provided for @homeBarBundlePhotoFailed.
  ///
  /// In ja, this message translates to:
  /// **'写真を使えません'**
  String get homeBarBundlePhotoFailed;

  /// No description provided for @homeBarBundleMembers.
  ///
  /// In ja, this message translates to:
  /// **'メンバー'**
  String get homeBarBundleMembers;

  /// No description provided for @homeBarMenuDetail.
  ///
  /// In ja, this message translates to:
  /// **'詳細'**
  String get homeBarMenuDetail;

  /// No description provided for @homeBarBundleRemoveMember.
  ///
  /// In ja, this message translates to:
  /// **'バンドルから外す'**
  String get homeBarBundleRemoveMember;

  /// No description provided for @homeBarDissolveList.
  ///
  /// In ja, this message translates to:
  /// **'リストの解除'**
  String get homeBarDissolveList;

  /// No description provided for @homeBarMemberMenu.
  ///
  /// In ja, this message translates to:
  /// **'メンバーの操作'**
  String get homeBarMemberMenu;

  /// No description provided for @homeBarRasqAccount.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント'**
  String get homeBarRasqAccount;

  /// No description provided for @homeBarHelpAstell.
  ///
  /// In ja, this message translates to:
  /// **'(…) か右クリックでメニュー。長押しで並び替え、ほかのアイコンに重ねるとまとめます。(+) でボタンを追加。'**
  String get homeBarHelpAstell;

  /// No description provided for @homeBarHelp.
  ///
  /// In ja, this message translates to:
  /// **'(…) か右クリックでメニュー。長押しで並び替え、ほかのアイコンに重ねるとまとめます。'**
  String get homeBarHelp;

  /// No description provided for @homeBarHelpAstellDetail.
  ///
  /// In ja, this message translates to:
  /// **'(…) / shift + クリック / 右クリックでメニュー(非表示 / バンドル)。長押しして動かすと並び替え、別のアイコンの上で離すとバンドル。(+) で非表示にしたボタンや ASTell のプラグインを足す。幅に収まらないときは、先頭から入るだけと最後の 1 つ(入力欄の隣)を出し、残りはルームの歯車のメニューへ。'**
  String get homeBarHelpAstellDetail;

  /// No description provided for @homeBarHelpDetail.
  ///
  /// In ja, this message translates to:
  /// **'(…) / shift + クリック / 右クリックでメニュー。長押しして動かすと並び替え、別のアイコンの上で離すとバンドル。宣言されたプラグインボタンと束ねる閾値は 設定 → SNSプラグイン →「プラグインボタン」。'**
  String get homeBarHelpDetail;

  /// No description provided for @homeBarRasqBuiltinEditor.
  ///
  /// In ja, this message translates to:
  /// **'RASQ(内蔵の編集)'**
  String get homeBarRasqBuiltinEditor;

  /// 新しく作ったバンドル(アクションリスト)の名前の既定。あとで利用者が変えられる
  ///
  /// In ja, this message translates to:
  /// **'マイリスト'**
  String get homeBarNewBundleName;

  /// No description provided for @homeBarMenuMakeList.
  ///
  /// In ja, this message translates to:
  /// **'アクションリスト化'**
  String get homeBarMenuMakeList;

  /// No description provided for @homeBarMenuHide.
  ///
  /// In ja, this message translates to:
  /// **'非表示にする'**
  String get homeBarMenuHide;

  /// No description provided for @homeBarMenuDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get homeBarMenuDelete;

  /// No description provided for @homeBarMenuListSettings.
  ///
  /// In ja, this message translates to:
  /// **'アクションリストの設定'**
  String get homeBarMenuListSettings;

  /// No description provided for @homeBarMenuPinList.
  ///
  /// In ja, this message translates to:
  /// **'固定リストにする'**
  String get homeBarMenuPinList;

  /// No description provided for @homeBarAddButton.
  ///
  /// In ja, this message translates to:
  /// **'ボタンを追加'**
  String get homeBarAddButton;

  /// No description provided for @homeBarNoHidden.
  ///
  /// In ja, this message translates to:
  /// **'非表示のボタンはありません'**
  String get homeBarNoHidden;

  /// No description provided for @homeBarHiddenLabel.
  ///
  /// In ja, this message translates to:
  /// **'非表示(押すと表示):'**
  String get homeBarHiddenLabel;

  /// No description provided for @homeBarShowHidden.
  ///
  /// In ja, this message translates to:
  /// **'{label} を表示'**
  String homeBarShowHidden(String label);

  /// No description provided for @homeBarResetOrder.
  ///
  /// In ja, this message translates to:
  /// **'既定の並びに戻す'**
  String get homeBarResetOrder;

  /// この言語の、その言語での名前(設定の「言語」の一覧に出す)。訳すときは、その言語での自分の名前にする(English / 한국어 など)。
  ///
  /// In ja, this message translates to:
  /// **'日本語'**
  String get languageSelfName;

  /// No description provided for @languageSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get languageSettingsTitle;

  /// No description provided for @languageSettingsRowSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'アプリの表示の言語'**
  String get languageSettingsRowSubtitle;

  /// No description provided for @languageSettingsCaption.
  ///
  /// In ja, this message translates to:
  /// **'アプリの文字の言語を選びます。端末の言語に対応していないときは日本語で表示します。'**
  String get languageSettingsCaption;

  /// No description provided for @languageSettingsCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'アプリの文字の言語を選びます。「システムに合わせる」は端末の言語の設定に従い、対応していない言語なら日本語にします。選んだ言語はこの端末に保存し、RASQ アカウントにログインしていれば ORGATE にも伝えます(メールや通知の言語、D-484)。'**
  String get languageSettingsCaptionDetail;

  /// No description provided for @languageSettingsSystem.
  ///
  /// In ja, this message translates to:
  /// **'システムに合わせる'**
  String get languageSettingsSystem;

  /// 「システムに合わせる」の下の説明。{language} = 端末の言語から決まった、いまの表示の言語の名前。
  ///
  /// In ja, this message translates to:
  /// **'いまは {language}'**
  String languageSettingsSystemCurrent(String language);

  /// No description provided for @languageSettingsListHeader.
  ///
  /// In ja, this message translates to:
  /// **'表示の言語'**
  String get languageSettingsListHeader;

  /// リストの画面の見出し。名前の分からない SNS のリストの見出し・タイムラインの名前にも使う
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get listsTitle;

  /// リストの画面のタブ。全アカウントのリスト / クリップ / フィードと RASQ リストをまとめて出す
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get listsTabAllLabel;

  /// リストの画面の検索欄の薄い文字
  ///
  /// In ja, this message translates to:
  /// **'リスト・クリップを検索'**
  String get listsSearchHint;

  /// リストの画面の検索欄を広げると出る絞り込みのチップ。非公開のクリップも一覧に出す
  ///
  /// In ja, this message translates to:
  /// **'非公開クリップを表示'**
  String get listsShowPrivateClips;

  /// リストのインポートの画面の見出しと、リストの画面の右上のボタンの説明
  ///
  /// In ja, this message translates to:
  /// **'リストのインポート'**
  String get listsImportTitle;

  /// リストの画面の右下の ＋ のボタンの説明と、押すと出る作成先を選ぶメニューの見出し
  ///
  /// In ja, this message translates to:
  /// **'リストを作成'**
  String get listsCreateTitle;

  /// 作成先を選ぶメニューの項目と、SNS のリストの名前を入れるシートの見出し。account はアカウント(@handle@サーバー)
  ///
  /// In ja, this message translates to:
  /// **'{account} のリスト'**
  String listsCreateAccountList(String account);

  /// 作成先を選ぶメニューの項目と、リストの画面の RASQ リストの欄の見出し。RASQ リストは複数の SNS の人を 1 つにまとめられる
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト(SNS 横断)'**
  String get listsRasqCrossSns;

  /// SNS のリストの名前を入れるシートの決定のボタン
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get listsCreateConfirm;

  /// SNS のリストの名前を入れる欄の薄い文字
  ///
  /// In ja, this message translates to:
  /// **'リスト名'**
  String get listsNameHint;

  /// SNS のリストを作ったときの知らせ。name はリストの名前
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を作りました'**
  String listsCreated(String name);

  /// その SNS がリストの作成に対応していないときの知らせ。sns は SNS の名前(Misskey / Mastodon など)
  ///
  /// In ja, this message translates to:
  /// **'{sns} ではリストを作れません'**
  String listsCreateUnsupported(String sns);

  /// SNS のリストを作れなかったときの知らせ。error はエラーの内容
  ///
  /// In ja, this message translates to:
  /// **'リストを作れませんでした: {error}'**
  String listsCreateFailed(String error);

  /// リストの画面のタブに何も無いとき
  ///
  /// In ja, this message translates to:
  /// **'リストはありません'**
  String get listsEmpty;

  /// リストの画面 / インポートの画面で、検索に当たるものが無いとき
  ///
  /// In ja, this message translates to:
  /// **'見つかりません'**
  String get listsNoHits;

  /// リストが無いときの補足。＋ は右下のボタン
  ///
  /// In ja, this message translates to:
  /// **'＋でリストを作成できます'**
  String get listsEmptyHint;

  /// リストの画面の RASQ リストの欄の末尾の行(押すと作成のシート)
  ///
  /// In ja, this message translates to:
  /// **'新しい RASQ リスト'**
  String get listsRasqCreateTitle;

  /// 「新しい RASQ リスト」の行の補足
  ///
  /// In ja, this message translates to:
  /// **'Misskey / Mastodon / Bluesky の人を 1 つのリストに'**
  String get listsRasqCreateSubtitle;

  /// 別のアカウントのリストを開くために、そのアカウントに切り替えたときの知らせ。account はアカウント(@handle@サーバー)
  ///
  /// In ja, this message translates to:
  /// **'{account} に切り替えました'**
  String listsSwitchedAccount(String account);

  /// アカウントのタブの、クリップの欄の見出し
  ///
  /// In ja, this message translates to:
  /// **'クリップ'**
  String get listsSectionClips;

  /// アカウントのタブの、SNS のリストの欄の見出し
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get listsSectionLists;

  /// アカウントのタブの、保存したカスタムフィード(Bluesky)の欄の見出し
  ///
  /// In ja, this message translates to:
  /// **'カスタムフィード'**
  String get listsSectionFeeds;

  /// SNS のリストの行の、入っている人の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} ユーザー}}'**
  String listsMemberCount(int count);

  /// クリップの行の、入っている投稿の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件}}'**
  String listsClipNotesCount(int count);

  /// クリップの行の種類: 端末の RASQ クリップ(複数の SNS の投稿を入れられる)
  ///
  /// In ja, this message translates to:
  /// **'RASQ(SNS 横断)'**
  String get listsClipKindHost;

  /// クリップの行の種類: SNS の非公開のクリップ
  ///
  /// In ja, this message translates to:
  /// **'非公開クリップ'**
  String get listsClipKindPrivate;

  /// クリップの行の種類: SNS の公開のクリップ
  ///
  /// In ja, this message translates to:
  /// **'クリップ'**
  String get listsClipKindPublic;

  /// 行の補足の項目(件数・種類・作者・♥ の数など)を並べるときの区切り
  ///
  /// In ja, this message translates to:
  /// **' ・ '**
  String get listsSeparator;

  /// 保存済みのカスタムフィードの、しおりのボタンの説明
  ///
  /// In ja, this message translates to:
  /// **'保存を外す'**
  String get listsFeedUnsave;

  /// 保存していないカスタムフィードの、しおりのボタンの説明
  ///
  /// In ja, this message translates to:
  /// **'フィードを保存'**
  String get listsFeedSave;

  /// フィードの保存を外せなかったときの知らせの見出し
  ///
  /// In ja, this message translates to:
  /// **'保存を外せませんでした'**
  String get listsFeedUnsaveFailed;

  /// フィードを保存できなかったときの知らせの見出し
  ///
  /// In ja, this message translates to:
  /// **'保存できませんでした'**
  String get listsFeedSaveFailed;

  /// フィードの保存に対応していない SNS で、しおりのボタンを押したとき
  ///
  /// In ja, this message translates to:
  /// **'この SNS はフィードの保存に対応していません'**
  String get listsFeedSaveUnsupported;

  /// フィードをタイムラインに取り込もうとしたが、アカウントにログインしていないとき
  ///
  /// In ja, this message translates to:
  /// **'ログインしていません'**
  String get listsNotLoggedIn;

  /// 取り込もうとしたフィードが、もうホームのタイムラインの取り込み元にあるとき。name はフィードの名前
  ///
  /// In ja, this message translates to:
  /// **'「{name}」はもうホームのタイムラインに入っています'**
  String listsFeedAlreadyImported(String name);

  /// フィードをホームのタイムラインの取り込み元に足したとき。name はフィードの名前。歯車はホームのタブの行の設定のボタン
  ///
  /// In ja, this message translates to:
  /// **'「{name}」をホームのタイムラインに取り込みました(タブ行の歯車で確認できます)'**
  String listsFeedImported(String name);

  /// SNS のリストの画面のタブ: 入っている人
  ///
  /// In ja, this message translates to:
  /// **'ユーザー'**
  String get listsTabUsers;

  /// SNS のリスト / フィードの画面のタブ: タイムライン
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get listsTabPosts;

  /// SNS のリスト / フィードの画面のタブ: 投稿を話題ごとに区切った目次
  ///
  /// In ja, this message translates to:
  /// **'話題の目次'**
  String get listsTabTopics;

  /// 見守り(チャイルドセーフ)で、保護者が止めた内容に近いリストを開いたとき
  ///
  /// In ja, this message translates to:
  /// **'保護者がこのリストを止めています'**
  String get listsBlockedByGuardian;

  /// SNS のリストの画面の右上の歯車のボタンの説明(このリストのタイムラインの設定)
  ///
  /// In ja, this message translates to:
  /// **'リストTL設定'**
  String get listsTimelineSettingsTooltip;

  /// SNS のリストのユーザーのタブのボタンと、人を選ぶシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'メンバーを追加'**
  String get listsAddMembers;

  /// リストに人を足したときの知らせ。count は足した人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 人を追加しました}}'**
  String listsMembersAdded(int count);

  /// SNS のリストに誰も入っていないとき
  ///
  /// In ja, this message translates to:
  /// **'ユーザーはいません'**
  String get listsNoUsers;

  /// SNS のリストのユーザーの行の右のボタン。その人をリストから外す
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get listsRemoveMember;

  /// タイムラインを読めなかったときの、もう一度読むボタン
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get listsReload;

  /// リスト / フィードのタイムラインに投稿が無いとき
  ///
  /// In ja, this message translates to:
  /// **'投稿はありません'**
  String get listsNoPosts;

  /// 名前の分からないカスタムフィードの画面の見出し・タイムラインの名前
  ///
  /// In ja, this message translates to:
  /// **'フィード'**
  String get listsFeedDefaultTitle;

  /// フィードの画面の右上のボタンの説明と、押したあとの知らせの見出し。開いているフィードをホームのタイムラインの取り込み元に足す
  ///
  /// In ja, this message translates to:
  /// **'タイムラインに取り込む'**
  String get listsImportToTimeline;

  /// フィードの画面の右上の歯車のボタンの説明(このフィードのタイムラインの設定)
  ///
  /// In ja, this message translates to:
  /// **'フィードTL設定'**
  String get listsFeedTimelineSettingsTooltip;

  /// リストのインポートの画面の検索欄の薄い文字(Bluesky のアカウントで、RASQ アカウントが無いとき)
  ///
  /// In ja, this message translates to:
  /// **'カスタムフィードを検索、または共有リンク / URL を入力'**
  String get listsImportSearchHintFeeds;

  /// リストのインポートの画面の検索欄の薄い文字(Bluesky 以外のアカウントで、RASQ アカウントがあるとき)
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストを検索、または共有リンク / URL を入力'**
  String get listsImportSearchHintRasq;

  /// リストのインポートの画面の検索欄の薄い文字(Bluesky のアカウントで、RASQ アカウントもあるとき)
  ///
  /// In ja, this message translates to:
  /// **'カスタムフィード / RASQ リストを検索、または共有リンク / URL を入力'**
  String get listsImportSearchHintBoth;

  /// リストのインポートの画面の検索欄の薄い文字(フィードも RASQ リストも探せないとき)
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get listsImportSearchPlain;

  /// リストのインポートの画面の説明(Bluesky のカスタムフィード)
  ///
  /// In ja, this message translates to:
  /// **'フィードを検索するか URL を貼ると、リストタイルで表示します。タップでそのフィードのタイムラインへ。'**
  String get listsImportFeedsHelp;

  /// リストのインポートの画面の説明(RASQ リスト)。「取り込む」は行の右のボタン
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストは「取り込む」でホームのタイムラインへ(リストをフォローします)。取り込めるのは、リスト内の人の情報を取れるリストだけです。'**
  String get listsImportRasqHelp;

  /// リストのインポートの画面の説明(フィードも RASQ リストも探せないとき)
  ///
  /// In ja, this message translates to:
  /// **'リストを検索して一括操作を行うことができます。'**
  String get listsImportGenericHelp;

  /// リストのインポートの画面のリンクと、押すと出る知らせの見出し(ファイルから読み込む)
  ///
  /// In ja, this message translates to:
  /// **'ローカルからインポート'**
  String get listsImportLocal;

  /// 「ローカルからインポート」を押したときの知らせ
  ///
  /// In ja, this message translates to:
  /// **'ファイルからのインポートは準備中です。'**
  String get listsImportLocalMessage;

  /// 「ローカルからインポート」の知らせの、開発者モードの詳しい説明
  ///
  /// In ja, this message translates to:
  /// **'CSV/JSON からのインポートはリスト機能(サーバー側)と合わせて実装します。'**
  String get listsImportLocalDetail;

  /// リストのインポートの画面で、検索語が空のときのフィードの欄の見出し
  ///
  /// In ja, this message translates to:
  /// **'人気のフィード'**
  String get listsImportPopularFeeds;

  /// リストのインポートの画面で、検索したときのフィードの欄の見出し
  ///
  /// In ja, this message translates to:
  /// **'フィードの検索結果'**
  String get listsImportFeedResults;

  /// リストのインポートの画面で、フィードの候補が無く、検索語も空のとき
  ///
  /// In ja, this message translates to:
  /// **'検索語か URL を入れてください'**
  String get listsImportEnterQuery;

  /// リストのインポートの画面で、検索語が空のときの RASQ リストの欄の見出し(自分のリストとフォロー中のリスト)
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト(自分 / フォロー中)'**
  String get listsImportRasqMine;

  /// リストのインポートの画面で、検索したときの RASQ リストの欄の見出し
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストの検索結果'**
  String get listsImportRasqResults;

  /// リストのインポートの画面の RASQ リストの行の右のボタン。ホームのタイムラインの取り込み元に足す
  ///
  /// In ja, this message translates to:
  /// **'取り込む'**
  String get listsImportButton;

  /// リストのインポートの画面の、インポートの履歴の欄の見出し
  ///
  /// In ja, this message translates to:
  /// **'履歴'**
  String get listsImportHistory;

  /// インポートの履歴が無いとき
  ///
  /// In ja, this message translates to:
  /// **'履歴はありません'**
  String get listsImportHistoryEmpty;

  /// 話題の目次のタブに話題が無いとき
  ///
  /// In ja, this message translates to:
  /// **'話題はまだありません'**
  String get listsTopicsEmpty;

  /// 話題の目次が空のときの補足
  ///
  /// In ja, this message translates to:
  /// **'投稿が集まると、話題ごとに区切ります'**
  String get listsTopicsEmptyHint;

  /// 話題の目次のタブの上の説明
  ///
  /// In ja, this message translates to:
  /// **'話題ごとの区切りです。タップすると、その話題の投稿だけを表示します。'**
  String get listsTopicsCaption;

  /// 話題の目次の説明の、開発者モードの詳しい説明。indexForListTimeline は関数の名前なので訳さない
  ///
  /// In ja, this message translates to:
  /// **'会話イベント(2 投稿以上、リレーショナル TL と同じエンジン)を章にし、単発投稿は 1 つにまとめる(indexForListTimeline)。見出しは投稿の中にある語(タグ / 特徴語 / ドメイン)。'**
  String get listsTopicsCaptionDetail;

  /// 話題の目次の行の、話題の始まりと終わりの時刻。start / end は時刻(「12:34」か「8/31 12:34」)
  ///
  /// In ja, this message translates to:
  /// **'{start}〜{end}'**
  String listsTopicTimeRange(String start, String end);

  /// 話題の目次の行の補足(話している人が 1 人のとき)。time は時刻か時刻の範囲、count は投稿の数
  ///
  /// In ja, this message translates to:
  /// **'{time} ・ {count, plural, other{{count} 件}}'**
  String listsTopicSubtitle(String time, int count);

  /// 話題の目次の行の補足(話している人が 2 人以上のとき)。time は時刻か時刻の範囲、count は投稿の数、people は話している人の数
  ///
  /// In ja, this message translates to:
  /// **'{time} ・ {count, plural, other{{count} 件}} ・ {people, plural, other{{people} 人}}'**
  String listsTopicSubtitleWithPeople(String time, int count, int people);

  /// 話題の目次の行の、代表の投稿の抜き出し。name は投稿した人の表示名、body は本文の頭(40 文字まで)
  ///
  /// In ja, this message translates to:
  /// **'{name}「{body}」'**
  String listsTopicSnippet(String name, String body);

  /// 投稿のタブの上の、話題で絞っているときのチップ。label は話題の見出し、count はその話題の投稿の数
  ///
  /// In ja, this message translates to:
  /// **'話題: {label}({count, plural, other{{count} 件}})'**
  String listsTopicFilterChip(String label, int count);

  /// 話題で絞っているときのチップの ✕ のボタンの説明
  ///
  /// In ja, this message translates to:
  /// **'絞り込みをやめる'**
  String get listsTopicFilterClear;

  /// リストに足す人を選ぶシートの、SNS のユーザーの説明(長押しで出る)。handle はユーザー名、instance はサーバー
  ///
  /// In ja, this message translates to:
  /// **'@{handle} ・ {instance}'**
  String listsMemberCandidateSubtitle(String handle, String instance);

  /// RASQ のユーザーをリストに足そうとしたが、その人が同じ SNS のアカウントを公開ページに出していないとき。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} さんは、この SNS のアカウントを公開していません'**
  String listsMemberNotPublished(String name);

  /// RASQ のユーザーが公開している SNS のアカウントを、いまのアカウントから引けなかったとき。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} さんの SNS アカウントが見つかりません'**
  String listsMemberSnsNotFound(String name);

  /// リストに足す人を選ぶシートの決定のボタン
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get listsPickerConfirm;

  /// RASQ のユーザーを選ぼうとしたが、RASQ のサーバーに繋がっていないとき
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーに繋がっていません'**
  String get listsPickerNoServer;

  /// RASQ のユーザーの SNS のアカウントを調べられなかったとき
  ///
  /// In ja, this message translates to:
  /// **'調べられませんでした'**
  String get listsPickerLookupFailed;

  /// RASQ のユーザーを選べないとき(理由が分からないとき)
  ///
  /// In ja, this message translates to:
  /// **'選べません'**
  String get listsPickerUnavailable;

  /// リストに足す人を選ぶシートの、候補の列に誰もいないとき
  ///
  /// In ja, this message translates to:
  /// **'いません'**
  String get listsPickerNone;

  /// リストに足す人を選ぶシートの検索欄の薄い文字
  ///
  /// In ja, this message translates to:
  /// **'ユーザーを検索(SNS / RASQ)'**
  String get listsPickerSearchHint;

  /// リストに足す人を選ぶシートの列の見出し: SNS のユーザーの検索結果
  ///
  /// In ja, this message translates to:
  /// **'SNS のユーザー'**
  String get listsPickerSnsUsers;

  /// リストに足す人を選ぶシートの列の見出し: RASQ のユーザーの検索結果
  ///
  /// In ja, this message translates to:
  /// **'RASQ のユーザー'**
  String get listsPickerRasqUsers;

  /// リストに足す人を選ぶシートの列の見出し: いまの SNS のアカウントがフォローしている人
  ///
  /// In ja, this message translates to:
  /// **'SNS のフォロー中'**
  String get listsPickerSnsFollowing;

  /// リストに足す人を選ぶシートの列の見出し: RASQ アカウントでフォローしている人
  ///
  /// In ja, this message translates to:
  /// **'RASQ のフォロー中'**
  String get listsPickerRasqFollowing;

  /// リストに足す人を選ぶシートの下の説明
  ///
  /// In ja, this message translates to:
  /// **'RASQ のユーザーは、その人が公開している同じ SNS のアカウントで追加します。'**
  String get listsPickerRasqNotice;

  /// 上の説明の、開発者モードの詳しい説明。path は API の道(GET /accounts/{handle})。Central / snsAccounts / userByHandle は名前なので訳さない
  ///
  /// In ja, this message translates to:
  /// **'Central の公開ページ({path})の snsAccounts から、このセッションと同じ SNS(同じサーバーを優先、確認済みを優先)を選び、userByHandle で引いた id を足す。'**
  String listsPickerRasqNoticeDetail(String path);

  /// リストに足す人を選ぶシートの、選んでいる人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 人を選んでいます}}'**
  String listsPickerSelectedCount(int count);

  /// 候補のアバターの左下の RASQ の印の読み上げ
  ///
  /// In ja, this message translates to:
  /// **'RASQ のユーザー'**
  String get listsPickerRasqBadgeSemantics;

  /// 音声を動画にするときの波形の形の選択肢(Visualizer の設定)。中央から上下に伸びるバー
  ///
  /// In ja, this message translates to:
  /// **'上下対称のバー'**
  String get mediaVizStyleMirror;

  /// 音声を動画にするときの波形の形の選択肢。下から上へ伸びるバー
  ///
  /// In ja, this message translates to:
  /// **'下から伸びるバー'**
  String get mediaVizStyleBars;

  /// 音声を動画にするときの波形の形の選択肢。折れ線グラフ
  ///
  /// In ja, this message translates to:
  /// **'折れ線'**
  String get mediaVizStyleLine;

  /// 音声の動画の左に出す絵の選択肢。投稿するアカウントのアイコン
  ///
  /// In ja, this message translates to:
  /// **'アカウントのアイコン'**
  String get mediaVizLeftAvatar;

  /// 音声の動画の左に出す絵の選択肢。端末から選んだ画像
  ///
  /// In ja, this message translates to:
  /// **'選んだ画像'**
  String get mediaVizLeftFile;

  /// 音声の動画の左に出す絵の選択肢。音符の記号
  ///
  /// In ja, this message translates to:
  /// **'音符のアイコン'**
  String get mediaVizLeftGlyph;

  /// 音声の動画の左に出す絵の選択肢。絵を出さず、波形を横幅いっぱいに描く
  ///
  /// In ja, this message translates to:
  /// **'なし(波形を横いっぱいに)'**
  String get mediaVizLeftNone;

  /// 音声の動画のタイトル / 説明を置く位置の選択肢。左の絵の下
  ///
  /// In ja, this message translates to:
  /// **'絵の下'**
  String get mediaVizTextBelow;

  /// 音声の動画のタイトル / 説明を置く位置の選択肢。左の絵の上
  ///
  /// In ja, this message translates to:
  /// **'絵の上'**
  String get mediaVizTextAbove;

  /// 音声の動画の書き出しの細かさの選択肢。波形を小さく描いて拡大するので速い。数字は描く大きさ(ピクセル)
  ///
  /// In ja, this message translates to:
  /// **'速い(960×540)'**
  String get mediaVizQualityFast;

  /// 音声の動画の書き出しの細かさの選択肢。標準。数字は描く大きさ(ピクセル)
  ///
  /// In ja, this message translates to:
  /// **'標準(1280×720)'**
  String get mediaVizQualityStandard;

  /// 音声の動画の書き出しの細かさの選択肢。出力と同じ大きさで描く。標準の約 4 倍の時間がかかる
  ///
  /// In ja, this message translates to:
  /// **'細かい(2560×1440、約 4 倍かかる)'**
  String get mediaVizQualityFine;

  /// 音声を動画にするとき、取り出した音声が WAV の形式でなかったときのエラー
  ///
  /// In ja, this message translates to:
  /// **'WAV ではありません'**
  String get mediaWavInvalid;

  /// 音声を動画にするとき、WAV のファイルに必要な部分(fmt / data のチャンク。訳さない)が無かったときのエラー
  ///
  /// In ja, this message translates to:
  /// **'WAV の fmt / data がありません'**
  String get mediaWavMissingChunks;

  /// 音声を動画にするとき、対応していない WAV の形式だったときのエラー。format は形式の番号、bits は標本のビット数
  ///
  /// In ja, this message translates to:
  /// **'未対応の WAV(format {format}、{bits} bit)'**
  String mediaWavUnsupported(int format, int bits);

  /// かかった時間 / フェードの長さの秒数。seconds は小数 1 桁まで書式済みの数
  ///
  /// In ja, this message translates to:
  /// **'{seconds} 秒'**
  String mediaSeconds(String seconds);

  /// 前回の音声の動画の書き出しにかかった時間の内訳(Visualizer の設定の「書き出し」の補足に出る)。total / frames / encode / mux は mediaSeconds の文(合計 / フレームを描く時間 / 動画にエンコードする時間 / 音声と重ねて仕上げる時間)、frameCount はフレームの数
  ///
  /// In ja, this message translates to:
  /// **'{frameCount, plural, other{合計 {total}({frameCount} フレーム: 描画 {frames} / エンコード {encode} / 仕上げ {mux})}}'**
  String mediaVizTimings(
    String total,
    int frameCount,
    String frames,
    String encode,
    String mux,
  );

  /// 音声を動画にする機能が使えない端末のときのエラー。使えるのは Android / iOS / macOS だけ
  ///
  /// In ja, this message translates to:
  /// **'この端末では音声を動画にできません(Android / iOS / macOS だけ)'**
  String get mediaAudioVideoUnsupported;

  /// 全画面のビューワーで開く投稿のパネルの、読み上げ用の名前
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get mediaViewerSemantics;

  /// 全画面のビューワーの左上の戻るボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get mediaViewerBack;

  /// 全画面のビューワーで動画を小さな窓(ピクチャー・イン・ピクチャー)で再生するボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'PiP で再生'**
  String get mediaViewerPip;

  /// 全画面のビューワーの … のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get mediaViewerMenu;

  /// 全画面のビューワーの下の共有ボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get mediaViewerShare;

  /// 全画面のビューワーで、画像を読むプラグイン(QR コードの検出など)が処理している最中の表示
  ///
  /// In ja, this message translates to:
  /// **'画像を見ています…'**
  String get mediaPluginAsking;

  /// 画像を読むプラグインが何かを見つけて、画像の上に重ねたときの表示
  ///
  /// In ja, this message translates to:
  /// **'検出あり'**
  String get mediaPluginFound;

  /// 画像を読むプラグインが何も見つけなかったときの表示
  ///
  /// In ja, this message translates to:
  /// **'検出なし'**
  String get mediaPluginNotFound;

  /// 画像を読むプラグインが失敗したときの表示。reason は理由(エラーの文。空のこともある)。プラグインのボタンをオフにしてオンにするとやり直せる
  ///
  /// In ja, this message translates to:
  /// **'失敗: {reason}(オフ → オンでやり直す)'**
  String mediaPluginFailed(String reason);

  /// 画像を読むプラグインに渡す画像をダウンロードできなかったときの理由(mediaPluginFailed の reason に入る)
  ///
  /// In ja, this message translates to:
  /// **'画像を取得できませんでした'**
  String get mediaPluginFetchFailed;

  /// 画像を読むプラグインに渡す画像をダウンロードできなかったときの理由。error はエラーの中身(英語のことがある)
  ///
  /// In ja, this message translates to:
  /// **'画像を取得できませんでした({error})'**
  String mediaPluginFetchFailedWithError(String error);

  /// 画像を読むプラグインに渡す画像を開けなかった(大きさが 0 など)ときの理由
  ///
  /// In ja, this message translates to:
  /// **'画像を読めませんでした'**
  String get mediaPluginDecodeFailed;

  /// 動画を再生できなかったときの表示。error はエラーの中身(英語のことがある)
  ///
  /// In ja, this message translates to:
  /// **'再生できません: {error}'**
  String mediaVideoCannotPlay(String error);

  /// 動画の操作のボタンのツールチップ。5 秒前へ戻る
  ///
  /// In ja, this message translates to:
  /// **'5 秒戻す'**
  String get mediaVideoBack5;

  /// 動画の操作のボタンのツールチップ。再生中に止める
  ///
  /// In ja, this message translates to:
  /// **'一時停止'**
  String get mediaVideoPause;

  /// 動画の操作のボタンのツールチップ。止まっているときに再生する
  ///
  /// In ja, this message translates to:
  /// **'再生'**
  String get mediaVideoPlay;

  /// 動画の操作のボタンのツールチップ。5 秒先へ進む
  ///
  /// In ja, this message translates to:
  /// **'5 秒送る'**
  String get mediaVideoForward5;

  /// 動画の再生速度を選ぶメニューのボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'再生速度'**
  String get mediaVideoSpeed;

  /// タイムラインから動画を開いた窓(FOW)の見出し
  ///
  /// In ja, this message translates to:
  /// **'動画'**
  String get mediaVideoFowTitle;

  /// 動画の窓(FOW)を閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get mediaVideoFowClose;

  /// 画像・動画の保存先の設定の選択肢。保存するたびに写真かファイルかを聞く
  ///
  /// In ja, this message translates to:
  /// **'保存するたびに選ぶ'**
  String get mediaSaveAsk;

  /// 画像・動画の保存先の選択肢。端末の写真(ギャラリー)
  ///
  /// In ja, this message translates to:
  /// **'写真(カメラロール)'**
  String get mediaSavePhotos;

  /// 画像・動画の保存先の選択肢。ファイルとして保存する
  ///
  /// In ja, this message translates to:
  /// **'ファイル'**
  String get mediaSaveFiles;

  /// 画像・動画を保存するとき、ファイル名が 1 つの名前になっていなかったときのエラー
  ///
  /// In ja, this message translates to:
  /// **'保存するファイル名が正しくありません'**
  String get mediaSaveBadFileName;

  /// 画像・動画を保存するとき、書く先が保存先のフォルダーの外になったので止めたときのエラー
  ///
  /// In ja, this message translates to:
  /// **'保存先のフォルダーの外には書きません'**
  String get mediaSaveOutsideFolder;

  /// 画像・動画を保存するとき、同じ名前のファイルが多くて新しい名前を作れなかったときのエラー
  ///
  /// In ja, this message translates to:
  /// **'同じ名前のファイルが多すぎます'**
  String get mediaSaveTooManySameName;

  /// 画像・動画を写真に保存しようとしたが、端末で許可されていなかったときのエラー。設定 App は端末の設定のアプリ
  ///
  /// In ja, this message translates to:
  /// **'写真への保存が許可されていません(設定 App で許可してください)'**
  String get mediaSavePhotosDenied;

  /// 画像・動画を写真に保存したときのお知らせ。RASQ はアルバムの名前で訳さない
  ///
  /// In ja, this message translates to:
  /// **'写真(アルバム「RASQ」)に保存しました'**
  String get mediaSavedToPhotos;

  /// iPhone / iPad で画像・動画を「ファイル」App から見える場所に保存したときのお知らせ。「ファイル」App は iOS のアプリの名前(その言語での名前にする)。folder は保存したフォルダーの名前(端末の上の名前で、訳さない)、fileName は保存したファイルの名前
  ///
  /// In ja, this message translates to:
  /// **'「ファイル」App の RASQ › {folder} に保存しました({fileName})'**
  String mediaSavedToFilesApp(String folder, String fileName);

  /// パソコンで画像・動画を保存したときのお知らせ。path は保存したファイルの場所
  ///
  /// In ja, this message translates to:
  /// **'保存しました: {path}'**
  String mediaSavedToPath(String path);

  /// 音声の動画の色の見本の名前(色の丸にマウスを載せたときのツールチップ)
  ///
  /// In ja, this message translates to:
  /// **'黒'**
  String get mediaColorBlack;

  /// 音声の動画の背景色の見本の名前(ツールチップ)。濃い紺色
  ///
  /// In ja, this message translates to:
  /// **'濃紺'**
  String get mediaColorNavy;

  /// 音声の動画の背景色の見本の名前(ツールチップ)。墨のような、ほぼ黒の灰色
  ///
  /// In ja, this message translates to:
  /// **'墨'**
  String get mediaColorInk;

  /// 音声の動画の背景色の見本の名前(ツールチップ)。濃い緑
  ///
  /// In ja, this message translates to:
  /// **'深緑'**
  String get mediaColorDeepGreen;

  /// 音声の動画の背景色の見本の名前(ツールチップ)。暗い赤(えんじ色)
  ///
  /// In ja, this message translates to:
  /// **'えんじ'**
  String get mediaColorCrimson;

  /// 音声の動画の色の見本の名前(ツールチップ)
  ///
  /// In ja, this message translates to:
  /// **'白'**
  String get mediaColorWhite;

  /// 音声の動画の文字の色の見本の名前(ツールチップ)。薄い灰色
  ///
  /// In ja, this message translates to:
  /// **'薄い灰'**
  String get mediaColorLightGray;

  /// 音声の動画の色の見本の名前(ツールチップ)。黄色
  ///
  /// In ja, this message translates to:
  /// **'黄'**
  String get mediaColorYellow;

  /// 音声の動画の色の見本の名前(ツールチップ)
  ///
  /// In ja, this message translates to:
  /// **'水色'**
  String get mediaColorSkyBlue;

  /// 音声の動画の色の見本の名前(ツールチップ)。桃色
  ///
  /// In ja, this message translates to:
  /// **'桃'**
  String get mediaColorPink;

  /// 音声の動画のバーの色の見本の名前(ツールチップ)
  ///
  /// In ja, this message translates to:
  /// **'青'**
  String get mediaColorBlue;

  /// 音声の動画のバーの色の見本の名前(ツールチップ)
  ///
  /// In ja, this message translates to:
  /// **'緑'**
  String get mediaColorGreen;

  /// 音声の動画のバーの色の見本の名前(ツールチップ)。オレンジ色
  ///
  /// In ja, this message translates to:
  /// **'橙'**
  String get mediaColorOrange;

  /// 音声の動画のバーの色の見本の名前(ツールチップ)
  ///
  /// In ja, this message translates to:
  /// **'紫'**
  String get mediaColorPurple;

  /// Visualizer の設定の窓を、変えずに閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get mediaVizCancel;

  /// Visualizer の設定の窓で、設定を決めて動画を書き出し直すボタン
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get mediaVizConfirm;

  /// 音声を動画にするときの見た目の設定の窓の、読み上げ用の名前。Visualizer は機能の名前で訳さない
  ///
  /// In ja, this message translates to:
  /// **'Visualizer の設定'**
  String get mediaVizSemantics;

  /// Visualizer の設定の窓の上の注意
  ///
  /// In ja, this message translates to:
  /// **'決定すると動画を作り直します。ここまでの編集は消えます'**
  String get mediaVizRebuildWarning;

  /// Visualizer の設定の窓の上の注意の詳しい説明(上のプレビューは今の再生位置のフレーム)。frames は書き出すフレームの数
  ///
  /// In ja, this message translates to:
  /// **'{frames, plural, other{今の再生位置のフレーム。決定で動画を書き出し直します({frames} フレーム)。ペイントやテキストなど、ここまでの編集は消えます。}}'**
  String mediaVizRebuildDetail(int frames);

  /// mediaVizRebuildDetail と同じ説明で、音声が長いのでフレームレートを下げるとき。frames は書き出すフレームの数、fps は下げた後のフレームレート(小数 1 桁まで書式済み)
  ///
  /// In ja, this message translates to:
  /// **'{frames, plural, other{今の再生位置のフレーム。決定で動画を書き出し直します({frames} フレーム、長いので {fps}fps に下げます)。ペイントやテキストなど、ここまでの編集は消えます。}}'**
  String mediaVizRebuildDetailReducedFps(int frames, String fps);

  /// Visualizer の設定の節の見出し。波形の形
  ///
  /// In ja, this message translates to:
  /// **'波形'**
  String get mediaVizWaveform;

  /// Visualizer の設定のスライダー。波形のバーの数(左から低い音 → 高い音)
  ///
  /// In ja, this message translates to:
  /// **'帯域の数(低音 → 高音)'**
  String get mediaVizBands;

  /// Visualizer の設定のスライダー。動画の 1 秒あたりのコマ数
  ///
  /// In ja, this message translates to:
  /// **'フレームレート'**
  String get mediaVizFrameRate;

  /// Visualizer の設定の節の見出し。波形のバーの色
  ///
  /// In ja, this message translates to:
  /// **'バーの色'**
  String get mediaVizBarColor;

  /// Visualizer の設定の節の見出し。動画の背景の色
  ///
  /// In ja, this message translates to:
  /// **'背景色'**
  String get mediaVizBackgroundColor;

  /// Visualizer の設定の節の見出し。動画の左に出す絵
  ///
  /// In ja, this message translates to:
  /// **'左の絵'**
  String get mediaVizLeftImage;

  /// Visualizer の設定の行。左の絵に使う画像を端末から選ぶ(まだ選んでいないとき)
  ///
  /// In ja, this message translates to:
  /// **'画像を選ぶ'**
  String get mediaVizPickImage;

  /// Visualizer の設定の行。左の絵に使う画像を選び直す(もう選んでいるとき。下にファイル名が出る)
  ///
  /// In ja, this message translates to:
  /// **'画像を選び直す'**
  String get mediaVizRepickImage;

  /// 「画像を選ぶ」の行の補足。画像を選ぶまでは音符の記号を出す
  ///
  /// In ja, this message translates to:
  /// **'選ぶまでは音符のアイコン'**
  String get mediaVizPickImageHint;

  /// Visualizer の設定の節の見出し。動画に出す文字
  ///
  /// In ja, this message translates to:
  /// **'タイトル / 説明'**
  String get mediaVizTitleSection;

  /// Visualizer の設定のスイッチ。動画にタイトルと説明を出すか
  ///
  /// In ja, this message translates to:
  /// **'タイトル / 説明を出す'**
  String get mediaVizShowTitle;

  /// Visualizer の設定の入力欄の薄い字。動画に出すタイトル。空ならファイル名を出す
  ///
  /// In ja, this message translates to:
  /// **'タイトル(空ならファイル名)'**
  String get mediaVizTitleHint;

  /// Visualizer の設定の入力欄の薄い字。動画に出す説明(省略できる)
  ///
  /// In ja, this message translates to:
  /// **'説明(無くてもよい)'**
  String get mediaVizDescriptionHint;

  /// Visualizer の設定のスライダー。タイトル / 説明の文字の大きさ
  ///
  /// In ja, this message translates to:
  /// **'文字の大きさ'**
  String get mediaVizTextScale;

  /// Visualizer の設定の選択肢。タイトル / 説明の文字の色を背景に合わせて自動で決める
  ///
  /// In ja, this message translates to:
  /// **'文字の色: 自動'**
  String get mediaVizTextColorAuto;

  /// Visualizer の設定の節の見出し。背景に流す動画
  ///
  /// In ja, this message translates to:
  /// **'背景の動画'**
  String get mediaVizBackgroundVideo;

  /// Visualizer の設定の行。背景に流す動画を選ぶ(まだ選んでいないとき)
  ///
  /// In ja, this message translates to:
  /// **'動画を選ぶ'**
  String get mediaVizPickVideo;

  /// Visualizer の設定の行。背景に流す動画を選び直す(もう選んでいるとき)
  ///
  /// In ja, this message translates to:
  /// **'動画を選び直す'**
  String get mediaVizRepickVideo;

  /// 「動画を選ぶ」の行の補足。選んだ動画の音は使わない
  ///
  /// In ja, this message translates to:
  /// **'背景色の代わりに動画を流します(音は使いません)'**
  String get mediaVizPickVideoHint;

  /// 「動画を選び直す」の行の補足。fileName は選んだ動画のファイル名。動画が音声より短ければ繰り返す
  ///
  /// In ja, this message translates to:
  /// **'{fileName} — 音声より短ければループします'**
  String mediaVizVideoSelected(String fileName);

  /// Visualizer の設定の行。背景の動画をやめて背景色に戻す
  ///
  /// In ja, this message translates to:
  /// **'背景の動画を外す'**
  String get mediaVizRemoveVideo;

  /// Visualizer の設定のスライダー。背景の動画の上に重ねる暗い膜の濃さ
  ///
  /// In ja, this message translates to:
  /// **'動画の上に掛ける暗さ'**
  String get mediaVizDim;

  /// 「動画の上に掛ける暗さ」の補足
  ///
  /// In ja, this message translates to:
  /// **'波形と文字を読みやすくします'**
  String get mediaVizDimHint;

  /// Visualizer の設定の節の見出し。動画の始めと終わりで絵を徐々に出す / 消す
  ///
  /// In ja, this message translates to:
  /// **'フェード(絵)'**
  String get mediaVizFade;

  /// Visualizer の設定のスライダー。始めに絵を徐々に出す長さ
  ///
  /// In ja, this message translates to:
  /// **'フェードイン'**
  String get mediaVizFadeIn;

  /// Visualizer の設定のスライダー。終わりに絵を徐々に消す長さ
  ///
  /// In ja, this message translates to:
  /// **'フェードアウト'**
  String get mediaVizFadeOut;

  /// フェードイン / フェードアウトのスライダーの値が 0 のときの表示
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get mediaVizFadeNone;

  /// Visualizer の設定の節の見出し。動画の書き出しの細かさ
  ///
  /// In ja, this message translates to:
  /// **'書き出し'**
  String get mediaVizExport;

  /// 書き出しの細かさの選択肢の下の説明
  ///
  /// In ja, this message translates to:
  /// **'細かくするほど、書き出しに時間がかかります'**
  String get mediaVizExportCaption;

  /// 書き出しの細かさの説明の詳しい補足(前回の書き出しの記録が無いとき)
  ///
  /// In ja, this message translates to:
  /// **'波形を描く大きさ(出力はいつも 2560×1440)。左の絵と文字は別の 1 枚で、いつも細かく描きます。書き出しの時間はほぼ フレーム数 × 描く大きさ で決まります(fps を下げるのも効きます)。背景の動画を使うと遅くなります。'**
  String get mediaVizExportDetail;

  /// mediaVizExportDetail と同じ補足で、先頭に前回の書き出しにかかった時間を付けたもの。timings は mediaVizTimings の文
  ///
  /// In ja, this message translates to:
  /// **'前回の書き出し: {timings}。\n波形を描く大きさ(出力はいつも 2560×1440)。左の絵と文字は別の 1 枚で、いつも細かく描きます。書き出しの時間はほぼ フレーム数 × 描く大きさ で決まります(fps を下げるのも効きます)。背景の動画を使うと遅くなります。'**
  String mediaVizExportDetailWithLast(String timings);

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'生成'**
  String get nodeprogCatalogGenreGenerate;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'変換'**
  String get nodeprogCatalogGenreConvert;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'入力'**
  String get nodeprogCatalogGenreInput;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'タイムライン'**
  String get nodeprogCatalogGenreTimeline;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'加工'**
  String get nodeprogCatalogGenreProcess;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'条件'**
  String get nodeprogCatalogGenreCondition;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'関数'**
  String get nodeprogCatalogGenreFunction;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'取得'**
  String get nodeprogCatalogGenreFetch;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'コンポーザー'**
  String get nodeprogCatalogGenreComposer;

  /// ノードのジャンル(パレットの絞り込み・タイルの副題)。
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get nodeprogCatalogGenreStorage;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'クロックメーカー'**
  String get nodeprogCatalogClockTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'一定間隔でクロックを出します。TL の自動更新などのトリガーに使います。'**
  String get nodeprogCatalogClockDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'テキスト'**
  String get nodeprogCatalogTextConstTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'書いた文をテキストとして出します。類似性 / キーワードの基準や、分割の入力に繋げます。'**
  String get nodeprogCatalogTextConstDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'分割'**
  String get nodeprogCatalogConvertSplitTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'テキストを区切り(改行 / カンマ / 空白)でテキスト配列にします。キーワードリストや保存の入力に繋げます。'**
  String get nodeprogCatalogConvertSplitDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'結合'**
  String get nodeprogCatalogConvertJoinTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'テキスト配列を区切り(改行 / カンマ / 空白)で 1 つのテキストにします。'**
  String get nodeprogCatalogConvertJoinDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'投稿を取り出す'**
  String get nodeprogCatalogListFirstTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'投稿リストの何番目かの投稿を 1 件取り出します(1 = 先頭)。本文をテキストにして基準や設定に繋げます。'**
  String get nodeprogCatalogListFirstDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'投稿の本文'**
  String get nodeprogCatalogPostTextTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'投稿 1 件の本文をテキストにします。'**
  String get nodeprogCatalogPostTextDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'ランダム'**
  String get nodeprogCatalogRandomTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'投稿ごとに乱数を出します。範囲は「1-7」のように指定し、小数点を入れると小数点以下もカウントします。シードで再現できます。'**
  String get nodeprogCatalogRandomDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'ファイルリーダー'**
  String get nodeprogCatalogFileTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'ローカルファイルを読み込んでテキストとして出します。'**
  String get nodeprogCatalogFileDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'タイムライン'**
  String get nodeprogCatalogTimelineTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'最終出力。投稿リストを繋ぐと、この画面のタイムラインに流れます。'**
  String get nodeprogCatalogTimelineDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'タイムライン取得'**
  String get nodeprogCatalogTlSourceTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'選んだタイムラインを取得して、投稿リストとして渡します。'**
  String get nodeprogCatalogTlSourceDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'選んだタイムラインを取得して、投稿リスト(RRLタグ付き)として渡します。'**
  String get nodeprogCatalogTlSourceDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'並べ替え'**
  String get nodeprogCatalogSortTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'下に繋いだ条件に合う投稿を先頭に並べ替えます(元の順序は保たれます)。'**
  String get nodeprogCatalogSortDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'消去'**
  String get nodeprogCatalogRemoveTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'下に繋いだ条件に合う投稿を取り除きます。'**
  String get nodeprogCatalogRemoveDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'条件'**
  String get nodeprogCatalogCondTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'指定したタグの内容を見て True/False を返します。下に数珠繋ぎで「かつ」、同じ接続部から並列で「または」。'**
  String get nodeprogCatalogCondDescription;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'下に繋いだ条件の否定を返します。'**
  String get nodeprogCatalogNotDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'関数入力'**
  String get nodeprogCatalogFnInputTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'関数の中身の入口。呼び出し元から渡された投稿リストがここから出ます(関数の中身の編集画面専用)。'**
  String get nodeprogCatalogFnInputDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'関数出力'**
  String get nodeprogCatalogFnOutputTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'関数の中身の出口。ここに繋いだ投稿リストが関数ノードの出力になります(未接続なら素通し)。'**
  String get nodeprogCatalogFnOutputDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'検索絞り込み'**
  String get nodeprogCatalogFilterQueryTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'検索ワードに合う投稿だけ通します(「除外」で逆に落とします)。'**
  String get nodeprogCatalogFilterQueryDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'検索ワードに合う投稿だけ通します。ワードが空のときは、このページの検索ワード/タグを使います。「除外」を true にすると、合う投稿を落とします(ワードミュート)。'**
  String get nodeprogCatalogFilterQueryDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'マージ'**
  String get nodeprogCatalogMergeTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'繋いだ投稿リストを時刻順に 1 本にまとめます。'**
  String get nodeprogCatalogMergeDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'繋いだ投稿リストを時刻順に 1 本へ合流します。別アカウントに流れてきた同じ投稿は 1 枚に畳み、タイルの ↓ でアカウントを選べます。'**
  String get nodeprogCatalogMergeDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'関連タイムライン'**
  String get nodeprogCatalogTimelineRelationalTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'関連タイムラインの絞り込みの出口です。'**
  String get nodeprogCatalogTimelineRelationalDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'関連TLの前段絞り込みの最終出力。繋いだ投稿リストが会話イベント構築の入力になります(処理系は変わりません)。'**
  String get nodeprogCatalogTimelineRelationalDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'リストTL取得'**
  String get nodeprogCatalogTlListTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'Misskey のリストのタイムラインを取得します(リスト名で指定)。'**
  String get nodeprogCatalogTlListDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'検索TL取得'**
  String get nodeprogCatalogTlSearchTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'検索ワードにヒットする投稿を取得します。'**
  String get nodeprogCatalogTlSearchDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'DM取得'**
  String get nodeprogCatalogTlDmTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'相手(ハンドル)との DM を取得します。'**
  String get nodeprogCatalogTlDmDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'トレンド取得'**
  String get nodeprogCatalogTrendTagsTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'いまのトレンドタグを文字列の配列として出します(類似度/キーワードの入力に)。'**
  String get nodeprogCatalogTrendTagsDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'カスタムフィード取得'**
  String get nodeprogCatalogTlFeedTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'Bluesky のカスタムフィードを取得します。'**
  String get nodeprogCatalogTlFeedDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'Bluesky のカスタムフィード(フィードジェネレーター)のタイムラインを取得します(at:// の URI で指定。TL カスタマイズでは検索して選べます)。'**
  String get nodeprogCatalogTlFeedDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト取得'**
  String get nodeprogCatalogTlRasqlistTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'いくつもの SNS の人をまとめた RASQ リストの投稿を取得します。'**
  String get nodeprogCatalogTlRasqlistDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト(Misskey / Mastodon / Bluesky の人を 1 つにまとめたリスト)の投稿を取得します。選べるのは、リスト内の人の情報を取れる(同じサーバーのアカウントがある / 入っている人をフォローしている)リストだけです。'**
  String get nodeprogCatalogTlRasqlistDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'トレンド検索結果取得'**
  String get nodeprogCatalogTrendPostsTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'いまのトレンド上位タグを検索して、その投稿を 1 本に合流して出します。'**
  String get nodeprogCatalogTrendPostsDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'ポスト先'**
  String get nodeprogCatalogComposerTargetTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'投稿先アカウントの候補です。下の条件に合うと投稿先になります。'**
  String get nodeprogCatalogComposerTargetDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'投稿先アカウントの候補。下に条件をぶら下げると、投稿内容がその条件に合うときこのアカウントが投稿先になります(上に置いたものほど優先。手動で選び直せます)。'**
  String get nodeprogCatalogComposerTargetDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'代わりのフォーマットで投稿'**
  String get nodeprogCatalogComposerFallbackTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'絞り込みで外れたとき、別の形でこのアカウントに投稿します。'**
  String get nodeprogCatalogComposerFallbackDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'絞り込みで投稿先から外れた場合のバイパス。下の条件(通常は直前の比較の Not)が成立したとき、代わりのフォーマットでこのアカウントに投稿します。'**
  String get nodeprogCatalogComposerFallbackDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'連動の絞り込み'**
  String get nodeprogCatalogComposerLinkgateTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'一緒に送る投稿だけに効く絞り込みです。'**
  String get nodeprogCatalogComposerLinkgateDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'連動投稿だけに掛かる絞り込みです。下の条件が成立しないと、このアカウントへの連動投稿は送られません(通常のポスト先判定には影響しません)。'**
  String get nodeprogCatalogComposerLinkgateDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'投稿加工(正規表現)'**
  String get nodeprogCatalogComposerRegexTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'送信するときに本文の一部を置き換えます。'**
  String get nodeprogCatalogComposerRegexDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'送信時に本文へ正規表現の置換をかけます(パターンに一致した部分を置換)。アカウントが空のときは全ての投稿先に適用します。'**
  String get nodeprogCatalogComposerRegexDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'リアクション済み取得'**
  String get nodeprogCatalogTlMyreactionsTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'TL で自分がリアクションした投稿を取得します(好みのプロファイル作りに)。'**
  String get nodeprogCatalogTlMyreactionsDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'トレンド枠'**
  String get nodeprogCatalogTrendFrameTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'トレンドホームの「トレンド」一覧の最終出力。タグ(テキスト配列)を繋ぐとそのまま一覧に出ます。'**
  String get nodeprogCatalogTrendFrameDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'類似度 (SigLIP)'**
  String get nodeprogCatalogMlSimilarTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'基準と各投稿の似ている度合いを 0〜1 で出します。'**
  String get nodeprogCatalogMlSimilarDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'基準(テキスト/配列/ベクトル)と各投稿の類似度を、この TL 内での相対値 0〜1 で出します(0.8 ≒ 上位 2 割相当)。ML 不達時は n-gram 類似度に縮退します。'**
  String get nodeprogCatalogMlSimilarDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'GLiNER抽出'**
  String get nodeprogCatalogMlGlinerTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'投稿リストから特徴語(頻出順)を抽出して文字列の配列で出します。'**
  String get nodeprogCatalogMlGlinerDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'SigLIP埋め込み'**
  String get nodeprogCatalogMlSiglipTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'投稿リストの傾向をまとめて出します。'**
  String get nodeprogCatalogMlSiglipDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'投稿リストの平均埋め込み(プロファイル)をベクトルで出します。ML 不達時は n-gram プロファイルに縮退します。'**
  String get nodeprogCatalogMlSiglipDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'保存 (storage.safe)'**
  String get nodeprogCatalogStorageSaveTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'繋いだデータを保存します。'**
  String get nodeprogCatalogStorageSaveDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'繋いだデータをスロットに保存します。storage.safe は依存関係の子プラグインにも渡せる安全な置き場(プラグイン側の受け渡しは初回起動時に確認)。'**
  String get nodeprogCatalogStorageSaveDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'読み出し (storage.safe)'**
  String get nodeprogCatalogStorageLoadTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'スロットに保存したデータを読み出します。'**
  String get nodeprogCatalogStorageLoadDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'キーワード一致 (GLiNER)'**
  String get nodeprogCatalogMlKeywordTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'キーワード(または配列)と各投稿の特徴語の一致数を出します。'**
  String get nodeprogCatalogMlKeywordDescription;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'指向性/刺激性 (プロファイル)'**
  String get nodeprogCatalogMlTendencyTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'好みの設定への合い具合(0〜1)を各投稿に出します。'**
  String get nodeprogCatalogMlTendencyDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'storage.safe のトレンドプロファイル(好きなジャンル/方向性・指向性のしきい値・刺激性の上限)への適合度(0〜1)を各投稿に出します。プロファイルは検索ホームのトレンド ⚙ で編集し、他のノードからも同じスロットを読めます。'**
  String get nodeprogCatalogMlTendencyDetail;

  /// ノードの名前(キャンバスのノードの見出し・パレットのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'比較'**
  String get nodeprogCatalogCompareTitle;

  /// パレットのタイル・ノード情報の説明。
  ///
  /// In ja, this message translates to:
  /// **'数値としきい値を比べて True/False を返します。'**
  String get nodeprogCatalogCompareDescription;

  /// 開発者モードで説明の代わりに出す詳しい説明。
  ///
  /// In ja, this message translates to:
  /// **'数値(類似度・乱数など)としきい値を比べて True/False を返す演算子条件です。値元が未接続・値が取れないとき(スロットが空など)は False になります。'**
  String get nodeprogCatalogCompareDetail;

  /// ポートのデータ形式の表示。{type} = データ形式(ジャンル)、{format} = プラグインが指定する細かい形式(例: .dic)。
  ///
  /// In ja, this message translates to:
  /// **'{type}({format})'**
  String nodeprogCatalogTypeWithFormat(String type, String format);

  /// パレットのタイルの入出力の 1 行の、ポート 1 つ。{label} = ポートの名前、{type} = データ形式。
  ///
  /// In ja, this message translates to:
  /// **'{label}({type})'**
  String nodeprogCatalogPortWithType(String label, String type);

  /// 入出力の 1 行で、条件接続部を表す語。
  ///
  /// In ja, this message translates to:
  /// **'条件'**
  String get nodeprogCatalogIoCond;

  /// 入出力の 1 行で、入力 / 出力が無いとき。
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get nodeprogCatalogIoNone;

  /// 並べた語の区切り(ポートの一覧・条件タグの一覧)。
  ///
  /// In ja, this message translates to:
  /// **'・'**
  String get nodeprogCatalogListSeparator;

  /// パレットのタイルの入出力の 1 行。{inputs} / {outputs} = ポートの一覧(区切りで繋いだもの)。
  ///
  /// In ja, this message translates to:
  /// **'入力: {inputs} → 出力: {outputs}'**
  String nodeprogCatalogIoSummary(String inputs, String outputs);

  /// 自分で作った関数ノードの提供元の欄。
  ///
  /// In ja, this message translates to:
  /// **'カスタム関数'**
  String get nodeprogCatalogCustomFunctionAuthor;

  /// 条件を受けるカスタム関数の説明。{tags} = 選んだ条件タグの一覧。
  ///
  /// In ja, this message translates to:
  /// **'条件 {tags} を受ける、自分で作った関数です。'**
  String nodeprogCatalogCustomFunctionCondDescription(String tags);

  /// 開発者モードの説明。{tags} = 選んだ条件タグの一覧。
  ///
  /// In ja, this message translates to:
  /// **'条件タグ {tags} を受けるカスタム関数です(中身の配線はプラグイン/RAi で)。'**
  String nodeprogCatalogCustomFunctionCondDetail(String tags);

  /// データを受けるカスタム関数の説明。
  ///
  /// In ja, this message translates to:
  /// **'自分で作った関数です。'**
  String get nodeprogCatalogCustomFunctionDataDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'カスタム関数です(中身の配線はプラグイン/RAi で)。'**
  String get nodeprogCatalogCustomFunctionDataDetail;

  /// ノードのジャンル: TL プラグインの並べ替えノード(パレットのジャンルの絞り込みの既定の表示も)。
  ///
  /// In ja, this message translates to:
  /// **'ソート/辞書'**
  String get nodeprogCatalogGenreSortDictionary;

  /// カスタム関数の名前が保存されていないときの名前。
  ///
  /// In ja, this message translates to:
  /// **'関数'**
  String get nodeprogCatalogCustomFunctionDefaultName;

  /// トレンドプラグインのノードの形式の名前(トレンドのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'トレンドを取得'**
  String get nodeprogComponentsTrendFormTilesLabel;

  /// トレンドプラグインのノードの形式の名前(候補のチップ)。
  ///
  /// In ja, this message translates to:
  /// **'カスタム(候補のチップ)'**
  String get nodeprogComponentsTrendFormChipsLabel;

  /// トレンドプラグインのノード(候補のチップ)の画面の見出し(後ろにプラグインの名前)。
  ///
  /// In ja, this message translates to:
  /// **'検索の候補'**
  String get nodeprogComponentsTrendFormChipsHeading;

  /// トレンドプラグインのノードの形式の説明。
  ///
  /// In ja, this message translates to:
  /// **'候補のワードを、トレンドのタイルの形で出します(タップでそのワードのトレンド)。'**
  String get nodeprogComponentsTrendFormTilesDescription;

  /// トレンドプラグインのノードの形式の説明。
  ///
  /// In ja, this message translates to:
  /// **'候補の上位のワードの投稿を、Today のようにまとめて出します。'**
  String get nodeprogComponentsTrendFormTodayDescription;

  /// トレンドプラグインのノードの形式の説明。
  ///
  /// In ja, this message translates to:
  /// **'候補のワードを、検索の候補のチップで出します。'**
  String get nodeprogComponentsTrendFormChipsDescription;

  /// アルゴリズム「サジェスト」の名前。{what} = なにを(キーワード / 類似性)、{from} = なにから(投稿内容 など)。
  ///
  /// In ja, this message translates to:
  /// **'{what}を{from}からサジェスト'**
  String nodeprogComponentsSuggestTitle(String what, String from);

  /// アルゴリズム「絞り込み」の名前。{what} = なにを、{from} = なにから。
  ///
  /// In ja, this message translates to:
  /// **'{what}を{from}から絞り込み'**
  String nodeprogComponentsFilterTitle(String what, String from);

  /// アルゴリズム「検索絞り込み」で除外にしたときの名前。
  ///
  /// In ja, this message translates to:
  /// **'検索絞り込み(除外)'**
  String get nodeprogComponentsQueryFilterExcludeTitle;

  /// アルゴリズム「指向性/刺激性」の名前。
  ///
  /// In ja, this message translates to:
  /// **'指向性/刺激性(プロファイル)'**
  String get nodeprogComponentsTendencyTitle;

  /// TL プラグインのアルゴリズムの名前(名前が無いとき)。
  ///
  /// In ja, this message translates to:
  /// **'カスタム(TLプラグイン)'**
  String get nodeprogComponentsPluginTitle;

  /// 表示モードの名前。
  ///
  /// In ja, this message translates to:
  /// **'通常 TL'**
  String get nodeprogComponentsDisplayTimeline;

  /// 表示モードの名前。
  ///
  /// In ja, this message translates to:
  /// **'関連 TL'**
  String get nodeprogComponentsDisplayRelational;

  /// 連動投稿の届け方の名前。
  ///
  /// In ja, this message translates to:
  /// **'確認して投稿 (confirm)'**
  String get nodeprogComponentsDeliveryConfirm;

  /// 連動投稿の届け方の名前。
  ///
  /// In ja, this message translates to:
  /// **'下書きだけ作る (draft)'**
  String get nodeprogComponentsDeliveryDraft;

  /// 連動投稿の届け方の名前。
  ///
  /// In ja, this message translates to:
  /// **'そのまま投稿 (auto)'**
  String get nodeprogComponentsDeliveryAuto;

  /// 「画面の投稿」ノードの名前(DM のページ)。
  ///
  /// In ja, this message translates to:
  /// **'この DM のメッセージ'**
  String get nodeprogComponentsSelfDm;

  /// 「画面の投稿」ノードの名前(トレンド / 検索のページ)。
  ///
  /// In ja, this message translates to:
  /// **'このワードの検索結果'**
  String get nodeprogComponentsSelfSearch;

  /// 「画面の投稿」ノードの名前(Today)。
  ///
  /// In ja, this message translates to:
  /// **'Today の投稿'**
  String get nodeprogComponentsSelfToday;

  /// 「画面の投稿」ノードの名前(トレンドページ)。
  ///
  /// In ja, this message translates to:
  /// **'トレンドのワード'**
  String get nodeprogComponentsSelfTrendWords;

  /// 「画面の投稿」ノードの名前(リストの TL)。
  ///
  /// In ja, this message translates to:
  /// **'このリストの投稿'**
  String get nodeprogComponentsSelfList;

  /// 「画面の投稿」ノードの名前(カスタムフィード)。
  ///
  /// In ja, this message translates to:
  /// **'このフィードの投稿'**
  String get nodeprogComponentsSelfFeed;

  /// 「画面の投稿」ノードの名前。
  ///
  /// In ja, this message translates to:
  /// **'総合タブの投稿'**
  String get nodeprogComponentsSelfBundle;

  /// 「画面の投稿」ノードの名前。
  ///
  /// In ja, this message translates to:
  /// **'フォロー中タブの投稿'**
  String get nodeprogComponentsSelfHome;

  /// 「画面の投稿」ノードの名前。
  ///
  /// In ja, this message translates to:
  /// **'おすすめタブの投稿'**
  String get nodeprogComponentsSelfSocial;

  /// 「画面の投稿」ノードの名前。
  ///
  /// In ja, this message translates to:
  /// **'ローカルタブの投稿'**
  String get nodeprogComponentsSelfLocal;

  /// 「画面の投稿」ノードの名前。
  ///
  /// In ja, this message translates to:
  /// **'グローバルタブの投稿'**
  String get nodeprogComponentsSelfGlobal;

  /// 「画面の投稿」ノードの名前。
  ///
  /// In ja, this message translates to:
  /// **'関連タブの投稿'**
  String get nodeprogComponentsSelfRelational;

  /// 「画面の投稿」ノードの名前(そのほかのタブ)。
  ///
  /// In ja, this message translates to:
  /// **'このタブの投稿'**
  String get nodeprogComponentsSelfTab;

  /// トレンドタイルで使えないアルゴリズムの理由。
  ///
  /// In ja, this message translates to:
  /// **'ML モデルを使うので、トレンドタイルでは使えません'**
  String get nodeprogComponentsTrendTilesNoMl;

  /// トレンドタイルで使えないアルゴリズムの理由。
  ///
  /// In ja, this message translates to:
  /// **'投稿の並べ替え(GPU を使うことも)なので、トレンドタイルでは使えません'**
  String get nodeprogComponentsTrendTilesNoPlugin;

  /// 投稿先のカスタマイズの … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'この構成をリセット'**
  String get nodeprogComposerResetConfig;

  /// 学習プロファイルの状況(まだ学習していない)。
  ///
  /// In ja, this message translates to:
  /// **'まだ学習していません(投稿すると学習します)'**
  String get nodeprogComposerLearnNone;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'学習プロファイル: まだ確定投稿がありません(投稿すると自動で学習します)'**
  String get nodeprogComposerLearnNoneDetail;

  /// 学習プロファイルの状況。{count} = 学習した投稿の数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{これまでの投稿 {count} 件から学習しています}}'**
  String nodeprogComposerLearnCount(int count);

  /// 開発者モードの説明。{count} = 学習した投稿の数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{学習プロファイル: 確定投稿 {count} 件(手動で切り替えた投稿は強く学習・半減期 90 日)}}'**
  String nodeprogComposerLearnCountDetail(int count);

  /// 連動の実績。{pos} = 連動した回数、{neg} = 確認で外した回数。
  ///
  /// In ja, this message translates to:
  /// **'実績: 連動 {pos} 回 / 確認で解除 {neg} 回'**
  String nodeprogComposerRelationStats(int pos, int neg);

  /// 投稿先のカスタマイズ: アカウントが無いとき。
  ///
  /// In ja, this message translates to:
  /// **'アカウントがありません'**
  String get nodeprogComposerNoAccounts;

  /// 投稿先のカスタマイズ: アカウントが無いときのヒント。
  ///
  /// In ja, this message translates to:
  /// **'ログインすると投稿先の条件を組めます'**
  String get nodeprogComposerNoAccountsHint;

  /// 投稿先のカスタマイズの説明のバナー。
  ///
  /// In ja, this message translates to:
  /// **'下書きの内容に合うアカウントが、投稿先の候補になります'**
  String get nodeprogComposerBanner;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'アカウントごとに絞り込みを組むと、下書きの内容(と内部のフォーマット)が合うアカウントが投稿先の候補になります。'**
  String get nodeprogComposerBannerDetail;

  /// ノードエディターで手を入れた構成の警告。
  ///
  /// In ja, this message translates to:
  /// **'ポスト先はノードエディタで編集されています。ここで変えると上書きされます'**
  String get nodeprogComposerHandEdited;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'ポスト先はノードエディタで編集されています。ここで変更すると簡易構成で置き換えます。'**
  String get nodeprogComposerHandEditedDetail;

  /// 投稿先のカスタマイズの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'ポスト先の絞り込み'**
  String get nodeprogComposerFiltersHeader;

  /// 投稿先のカスタマイズの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'フォーマット'**
  String get nodeprogComposerFormatHeader;

  /// フォーマットの節の説明。
  ///
  /// In ja, this message translates to:
  /// **'絞り込みに合わなかったときも、別の形で候補に残せます'**
  String get nodeprogComposerFormatCaption;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'絞り込みに合わなかったとき、代わりのフォーマットで候補に残します(無くなる直前の比較からバイパス)。'**
  String get nodeprogComposerFormatCaptionDetail;

  /// 投稿先のカスタマイズの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'連動投稿の届け方'**
  String get nodeprogComposerDeliveryHeader;

  /// 連動投稿の届け方の節の説明。
  ///
  /// In ja, this message translates to:
  /// **'ほかのアカウントと一緒に送るときの設定です'**
  String get nodeprogComposerDeliveryCaption;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'複数選択モードの「ノード連動」でこのアカウントへ送るときの届け方と、連動できる連動元です。'**
  String get nodeprogComposerDeliveryCaptionDetail;

  /// 届け方の行。{delivery} = いまの届け方。
  ///
  /// In ja, this message translates to:
  /// **'届け方: {delivery}'**
  String nodeprogComposerDeliveryTitle(String delivery);

  /// 連動元のアカウントの選択の見出し。
  ///
  /// In ja, this message translates to:
  /// **'連動元のアカウント(主投稿先がここにあるときだけ連動)'**
  String get nodeprogComposerLinkSourcesLabel;

  /// 連動の絞り込みの説明。
  ///
  /// In ja, this message translates to:
  /// **'連動の絞り込み(一緒に送るときだけ効きます)'**
  String get nodeprogComposerLinkFiltersCaption;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'連動の絞り込み(連動投稿だけに掛かる関門。ポスト先判定には影響しません)'**
  String get nodeprogComposerLinkFiltersCaptionDetail;

  /// ポスト先の絞り込みのタイルの説明。{basis} = 基準(投稿 / リアクションした投稿 / 返信)、{what} = 比べ方。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントの{basis}を基準に、下書きが{what}で合うとき投稿先候補になります。'**
  String nodeprogComposerFilterDescription(String basis, String what);

  /// ポスト先の絞り込みの基準。
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get nodeprogComposerFilterBasisPosts;

  /// ポスト先の絞り込みの基準。
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get nodeprogComposerFilterBasisReplies;

  /// ポスト先の絞り込みのタイルの説明(無効のとき)。
  ///
  /// In ja, this message translates to:
  /// **'無効化中: このアカウントはポスト先の候補になりません。'**
  String get nodeprogComposerFilterDisabled;

  /// 連動の絞り込みのタイルの副題。{account} = アカウント。
  ///
  /// In ja, this message translates to:
  /// **'{account} ・ 連動のみ'**
  String nodeprogComposerLinkOnlySubtitle(String account);

  /// 追加の絞り込みのタイルの副題。{account} = アカウント。
  ///
  /// In ja, this message translates to:
  /// **'{account} ・ かつ'**
  String nodeprogComposerAndSubtitle(String account);

  /// 連動の絞り込みのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'連動投稿がこの条件に合わないとき、このアカウントへは送られません。'**
  String get nodeprogComposerLinkFilterDescription;

  /// 追加の絞り込みのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'前の絞り込みと「かつ」で連結されます。'**
  String get nodeprogComposerAndDescription;

  /// 追加のノードを外すボタン。
  ///
  /// In ja, this message translates to:
  /// **'ノードを削除'**
  String get nodeprogComposerDeleteNode;

  /// 投稿加工のタイルの説明。{pattern} = パターン、{replace} = 置換。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントへ送る本文の「{pattern}」を「{replace}」に置換します。'**
  String nodeprogComposerRegexDescription(String pattern, String replace);

  /// 投稿加工のタイルの説明(未設定 / 無効)。
  ///
  /// In ja, this message translates to:
  /// **'送信時に本文へ正規表現の置換をかけます(例: タグの付け替え・伏せ字)。'**
  String get nodeprogComposerRegexDescriptionEmpty;

  /// 追加の投稿加工のタイルの名前(パターンが空)。
  ///
  /// In ja, this message translates to:
  /// **'投稿加工(未設定)'**
  String get nodeprogComposerRegexUnset;

  /// 追加の投稿加工のタイルの名前。{pattern} = パターン、{replace} = 置換。
  ///
  /// In ja, this message translates to:
  /// **'「{pattern}」→「{replace}」'**
  String nodeprogComposerRegexRule(String pattern, String replace);

  /// 追加の投稿加工のタイルの副題。{account} = アカウント。
  ///
  /// In ja, this message translates to:
  /// **'{account} ・ 追加ノード'**
  String nodeprogComposerExtraNodeSubtitle(String account);

  /// 追加の投稿加工のタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'上の加工に続けて適用されます。'**
  String get nodeprogComposerExtraRegexDescription;

  /// 代わりのフォーマット「注釈を付ける」の注釈の欄。
  ///
  /// In ja, this message translates to:
  /// **'注釈'**
  String get nodeprogComposerCwLabel;

  /// 連動元のアカウントの選択: ほかにアカウントが無いとき。
  ///
  /// In ja, this message translates to:
  /// **'他のアカウントがありません'**
  String get nodeprogComposerNoOtherAccounts;

  /// 投稿加工のタイルの … ボタン。
  ///
  /// In ja, this message translates to:
  /// **'投稿加工の操作'**
  String get nodeprogComposerRegexMenuTooltip;

  /// ポスト先の絞り込みのタイルの … ボタン。
  ///
  /// In ja, this message translates to:
  /// **'ポスト先の操作'**
  String get nodeprogComposerFilterMenuTooltip;

  /// 投稿加工のパラメーターのスイッチ。
  ///
  /// In ja, this message translates to:
  /// **'投稿加工を有効にする'**
  String get nodeprogComposerParamsRegexEnabled;

  /// 投稿加工のパラメーターのスイッチの説明。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントへ送る本文にパターン置換をかけます'**
  String get nodeprogComposerParamsRegexEnabledSubtitle;

  /// 追加の投稿加工のパラメーターの説明。
  ///
  /// In ja, this message translates to:
  /// **'上の加工に続けて適用される追加ノードです。'**
  String get nodeprogComposerParamsExtraRegex;

  /// ポスト先の絞り込みのパラメーターのスイッチ。
  ///
  /// In ja, this message translates to:
  /// **'絞り込みを有効にする'**
  String get nodeprogComposerParamsFilterEnabled;

  /// ポスト先の絞り込みのパラメーターのスイッチの説明。
  ///
  /// In ja, this message translates to:
  /// **'無効のときこのアカウントはポスト先の候補になりません'**
  String get nodeprogComposerParamsFilterEnabledSubtitle;

  /// ポスト先の絞り込みのパラメーターの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'なにを見る?'**
  String get nodeprogComposerParamsWhat;

  /// 投稿加工のパラメーターの説明。
  ///
  /// In ja, this message translates to:
  /// **'送信時に本文へ正規表現の置換をかけます。'**
  String get nodeprogComposerParamsRegexDescription;

  /// 連動の絞り込みのパラメーターの説明。
  ///
  /// In ja, this message translates to:
  /// **'一緒に送るときだけ効く条件です。'**
  String get nodeprogComposerParamsLinkFilterDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'連動投稿だけに掛かる関門です(ポスト先判定には影響しません)。'**
  String get nodeprogComposerParamsLinkFilterDetail;

  /// ポスト先の絞り込みのパラメーターの説明。
  ///
  /// In ja, this message translates to:
  /// **'下書きがこの条件に合うとき、このアカウントが投稿先候補になります。'**
  String get nodeprogComposerParamsFilterDescription;

  /// 投稿加工のパターンの欄。
  ///
  /// In ja, this message translates to:
  /// **'パターン(正規表現)'**
  String get nodeprogComposerParamsPatternLabel;

  /// 投稿加工のパターンの欄のヒント(正規表現の例)。
  ///
  /// In ja, this message translates to:
  /// **'例: #ネタバレ\\s*'**
  String get nodeprogComposerParamsPatternHint;

  /// 投稿加工の置換の欄。
  ///
  /// In ja, this message translates to:
  /// **'置換(空 = 削除)'**
  String get nodeprogComposerParamsReplaceLabel;

  /// キャンバスのノードの、入力ポートの並びの見出し。
  ///
  /// In ja, this message translates to:
  /// **'入力'**
  String get nodeprogEditorCanvasInputs;

  /// キャンバスのノードの、出力ポートの並びの見出し。
  ///
  /// In ja, this message translates to:
  /// **'出力'**
  String get nodeprogEditorCanvasOutputs;

  /// プラグインのノードの印のツールチップ: 持ち主のアカウントが無い(総合 / 関数の中身)とき。
  ///
  /// In ja, this message translates to:
  /// **'既定'**
  String get nodeprogEditorBadgeDefaultOwner;

  /// プラグインのノードの印のツールチップ: プラグインが登録されていないとき。
  ///
  /// In ja, this message translates to:
  /// **'未登録'**
  String get nodeprogEditorBadgeNotRegistered;

  /// プラグインのノードの印のツールチップの、アカウントと版の区切り(前後に空白)。
  ///
  /// In ja, this message translates to:
  /// **' ・ '**
  String get nodeprogEditorBadgeSeparator;

  /// ノードのタブの名前が保存されていないときの名前。
  ///
  /// In ja, this message translates to:
  /// **'ノードTL'**
  String get nodeprogEditorNodeTabDefaultLabel;

  /// 埋め込みのノードグラフが空のとき。
  ///
  /// In ja, this message translates to:
  /// **'ノードがありません'**
  String get nodeprogEditorInlineEmpty;

  /// 埋め込みのノードグラフを全画面のエディターで開くボタン。
  ///
  /// In ja, this message translates to:
  /// **'全画面で編集'**
  String get nodeprogEditorInlineExpandTooltip;

  /// 「ノードを設定」で、プラグインが登録されていないとき。
  ///
  /// In ja, this message translates to:
  /// **'このプラグインは登録されていません(ストアから入れ直してください)。'**
  String get nodeprogEditorParamsMissing;

  /// 「ノードを設定」で、パラメーターの画面を読み込んでいるあいだ。
  ///
  /// In ja, this message translates to:
  /// **'パラメーターを読み込んでいます…'**
  String get nodeprogEditorParamsLoading;

  /// 「ノードを設定」で、プラグインにパラメーターが無いとき。
  ///
  /// In ja, this message translates to:
  /// **'このプラグインにパラメーターはありません。'**
  String get nodeprogEditorParamsNone;

  /// No description provided for @nodeprogEditorCancelButton.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get nodeprogEditorCancelButton;

  /// No description provided for @nodeprogEditorConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get nodeprogEditorConfirmButton;

  /// プラグインのノードのパラメーターを編集する FOW の見出し(ノードのメニューの項目も)。
  ///
  /// In ja, this message translates to:
  /// **'ノードを設定'**
  String get nodeprogEditorParamsTitle;

  /// TL プラグインの並べ替えノードの提供元の欄。
  ///
  /// In ja, this message translates to:
  /// **'TLプラグイン'**
  String get nodeprogEditorPluginSortAuthor;

  /// TL プラグインの並べ替えノードの説明。
  ///
  /// In ja, this message translates to:
  /// **'プラグインの並べ方で投稿を並べ替えます。'**
  String get nodeprogEditorPluginSortDescription;

  /// 開発者モードの説明(「ノードを設定」の中)。
  ///
  /// In ja, this message translates to:
  /// **'投稿リストをプラグインのソート(tl.sort)で並べ替えます。パラメーターはノードの「パラメーター」ポートに入ります。'**
  String get nodeprogEditorParamsPluginDetail;

  /// TL プラグインの並べ替えノードの名前。{name} = プラグインのタイムラインの名前。
  ///
  /// In ja, this message translates to:
  /// **'{name}でソート'**
  String nodeprogEditorPluginSortTitle(String name);

  /// 開発者モードの説明(パレット)。
  ///
  /// In ja, this message translates to:
  /// **'投稿リストをプラグインのソート(tl.sort)で並べ替えます。'**
  String get nodeprogEditorPluginSortDetail;

  /// ノードエディターの見出し: カスタム関数の中身の編集(関数が見つからないとき)。
  ///
  /// In ja, this message translates to:
  /// **'関数の中身'**
  String get nodeprogEditorTitleFunctionBody;

  /// ノードエディターの見出し: カスタム関数の中身の編集。{name} = 関数の名前。
  ///
  /// In ja, this message translates to:
  /// **'関数の中身 — {name}'**
  String nodeprogEditorTitleFunctionBodyNamed(String name);

  /// ノードエディターの見出し(投稿コンポーザー)。
  ///
  /// In ja, this message translates to:
  /// **'投稿先のカスタマイズ'**
  String get nodeprogEditorTitleComposer;

  /// ノードエディターの見出し(トレンド)。
  ///
  /// In ja, this message translates to:
  /// **'トレンドをカスタマイズ'**
  String get nodeprogEditorTitleTrend;

  /// ノードエディターの見出し(タイムライン)。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインをカスタマイズ'**
  String get nodeprogEditorTitleTimeline;

  /// トレンドのノードエディターのタブ。
  ///
  /// In ja, this message translates to:
  /// **'ノート'**
  String get nodeprogEditorTabTrendNotes;

  /// ノードエディターのタブ(タイムライン / トレンド)。
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get nodeprogEditorTabFollowing;

  /// トレンドのノードエディターのタブ。
  ///
  /// In ja, this message translates to:
  /// **'ユーザー'**
  String get nodeprogEditorTabTrendUsers;

  /// ノードエディターのタブ(全アカウントをまとめたタイムライン)。
  ///
  /// In ja, this message translates to:
  /// **'総合'**
  String get nodeprogEditorTabBundle;

  /// ノードエディターのタブ。
  ///
  /// In ja, this message translates to:
  /// **'おすすめ'**
  String get nodeprogEditorTabSocial;

  /// ノードエディターのタブ。
  ///
  /// In ja, this message translates to:
  /// **'関連'**
  String get nodeprogEditorTabRelational;

  /// ノードエディターのタブ。
  ///
  /// In ja, this message translates to:
  /// **'ローカル'**
  String get nodeprogEditorTabLocal;

  /// ノードエディターのタブ。
  ///
  /// In ja, this message translates to:
  /// **'グローバル'**
  String get nodeprogEditorTabGlobal;

  /// No description provided for @nodeprogEditorAddTabTooltip.
  ///
  /// In ja, this message translates to:
  /// **'タブを追加'**
  String get nodeprogEditorAddTabTooltip;

  /// タブを足すダイアログの見出し。
  ///
  /// In ja, this message translates to:
  /// **'新しいタブ'**
  String get nodeprogEditorNewTabTitle;

  /// タブの名前の入力欄のヒント。
  ///
  /// In ja, this message translates to:
  /// **'タブ名'**
  String get nodeprogEditorTabNameHint;

  /// ダイアログの見出しと … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'タブ名を変更'**
  String get nodeprogEditorRenameTab;

  /// … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'タブを削除'**
  String get nodeprogEditorDeleteTab;

  /// … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'グラフをクリア'**
  String get nodeprogEditorClearGraph;

  /// … メニューの項目(チェック付き)。
  ///
  /// In ja, this message translates to:
  /// **'バンドルでノードTLを集合表示'**
  String get nodeprogEditorBundleTabsToggle;

  /// ノードのパレット(FOW)の検索欄のヒントと読み上げ。
  ///
  /// In ja, this message translates to:
  /// **'プラグインノードを検索'**
  String get nodeprogEditorPaletteSearchHint;

  /// データ形式が合わないポート同士を繋ごうとしたときのスナックバー。{from} / {to} = 出力 / 入力のデータ形式。
  ///
  /// In ja, this message translates to:
  /// **'接続できません: {from} → {to}(形式が合いません)'**
  String nodeprogEditorConnectTypeMismatch(String from, String to);

  /// カスタム関数を作るダイアログの見出し・パレットの先頭のタイル。
  ///
  /// In ja, this message translates to:
  /// **'カスタム関数を作成'**
  String get nodeprogEditorCreateFunction;

  /// カスタム関数の名前の入力欄のヒント。
  ///
  /// In ja, this message translates to:
  /// **'関数名'**
  String get nodeprogEditorFunctionNameHint;

  /// カスタム関数のダイアログ: 入力元の選択の見出し。
  ///
  /// In ja, this message translates to:
  /// **'入力元'**
  String get nodeprogEditorFunctionSourceLabel;

  /// カスタム関数のダイアログ: 入力元 = 条件。
  ///
  /// In ja, this message translates to:
  /// **'条件'**
  String get nodeprogEditorFunctionSourceCond;

  /// カスタム関数のダイアログ: 入力元 = データ。
  ///
  /// In ja, this message translates to:
  /// **'データ'**
  String get nodeprogEditorFunctionSourceData;

  /// カスタム関数のダイアログ: 条件タグの選択の見出し。
  ///
  /// In ja, this message translates to:
  /// **'条件タグ(複数選ぶと下側の分岐が増えます)'**
  String get nodeprogEditorFunctionCondTagsLabel;

  /// カスタム関数のダイアログ: 入力のデータ形式の選択の見出し。
  ///
  /// In ja, this message translates to:
  /// **'入力(データ形式)'**
  String get nodeprogEditorFunctionInputsLabel;

  /// カスタム関数のダイアログ: 出力のデータ形式の選択の見出し。
  ///
  /// In ja, this message translates to:
  /// **'出力(データ形式)'**
  String get nodeprogEditorFunctionOutputsLabel;

  /// No description provided for @nodeprogEditorCreateButton.
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get nodeprogEditorCreateButton;

  /// ノードのメニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'ノード情報'**
  String get nodeprogEditorMenuInfo;

  /// ノードのメニューの項目(カスタム関数)。
  ///
  /// In ja, this message translates to:
  /// **'関数の中身を編集'**
  String get nodeprogEditorMenuEditFunctionBody;

  /// ノードのメニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'プラグインストアに移動'**
  String get nodeprogEditorMenuStore;

  /// ノードのメニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get nodeprogEditorMenuCopy;

  /// ノードのメニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'ペースト'**
  String get nodeprogEditorMenuPaste;

  /// ノードのメニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get nodeprogEditorMenuDelete;

  /// ノードエディターの見出しの … ボタン。
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get nodeprogEditorMoreTooltip;

  /// ノードのパレットを開き直すボタン。
  ///
  /// In ja, this message translates to:
  /// **'ノードを検索'**
  String get nodeprogEditorSearchNodesTooltip;

  /// キャンバスにノードが無いときのヒント。
  ///
  /// In ja, this message translates to:
  /// **'下の検索から追加(タップで詳細、長押しでドラッグ)'**
  String get nodeprogEditorEmptyHint;

  /// キャンバスのツールバー。
  ///
  /// In ja, this message translates to:
  /// **'範囲選択'**
  String get nodeprogEditorToolbarSelect;

  /// キャンバスのツールバー(範囲選択のとき)。
  ///
  /// In ja, this message translates to:
  /// **'範囲選択をやめる'**
  String get nodeprogEditorToolbarSelectStop;

  /// キャンバスのツールバー。
  ///
  /// In ja, this message translates to:
  /// **'選んだノードを削除'**
  String get nodeprogEditorToolbarDeleteSelected;

  /// キャンバスのツールバー。
  ///
  /// In ja, this message translates to:
  /// **'整理整頓'**
  String get nodeprogEditorToolbarTidy;

  /// キャンバスのツールバー。
  ///
  /// In ja, this message translates to:
  /// **'縮小'**
  String get nodeprogEditorToolbarZoomOut;

  /// キャンバスのツールバー。
  ///
  /// In ja, this message translates to:
  /// **'拡大'**
  String get nodeprogEditorToolbarZoomIn;

  /// キャンバスのツールバー。
  ///
  /// In ja, this message translates to:
  /// **'全体表示'**
  String get nodeprogEditorToolbarFit;

  /// パレットの並び替えのチップ。
  ///
  /// In ja, this message translates to:
  /// **'並び替え: 関連順'**
  String get nodeprogEditorPaletteSortChip;

  /// パレットの並び替えの選択肢。
  ///
  /// In ja, this message translates to:
  /// **'関連順'**
  String get nodeprogEditorPaletteSortRelevance;

  /// パレットのジャンルのチップ。{genre} = 選んだジャンル。
  ///
  /// In ja, this message translates to:
  /// **'ジャンル: {genre}'**
  String nodeprogEditorPaletteGenreChip(String genre);

  /// パレットのジャンルの選択肢: 絞り込まない。
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get nodeprogEditorPaletteGenreAll;

  /// パレットの検索の設定ボタン。
  ///
  /// In ja, this message translates to:
  /// **'検索設定(準備中)'**
  String get nodeprogEditorPaletteSettingsTooltip;

  /// パレットの検索で何も当たらないとき。
  ///
  /// In ja, this message translates to:
  /// **'ノードが見つかりません'**
  String get nodeprogEditorPaletteEmptyTitle;

  /// パレットの検索で何も当たらないときのヒント。
  ///
  /// In ja, this message translates to:
  /// **'検索ワードやジャンルを変えてみてください'**
  String get nodeprogEditorPaletteEmptyHint;

  /// パレットの「カスタム関数を作成」のタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'条件タグまたは入出力(データ形式)を選んで、自分の関数ノードを作ります。データ関数は中身をノードで組めます。'**
  String get nodeprogEditorCreateFunctionDescription;

  /// パレットのタイルの副題。{author} = 提供元、{genre} = ジャンル。
  ///
  /// In ja, this message translates to:
  /// **'{author} · {genre}'**
  String nodeprogEditorTileSubtitle(String author, String genre);

  /// パレットのタイルの提供元: アプリに組み込みのノード。
  ///
  /// In ja, this message translates to:
  /// **'組み込みノード'**
  String get nodeprogEditorBuiltinAuthor;

  /// ノードの詳細のボタン。
  ///
  /// In ja, this message translates to:
  /// **'キャンバスに追加'**
  String get nodeprogEditorAddToCanvas;

  /// ノードの詳細のボタン(カスタム関数)。
  ///
  /// In ja, this message translates to:
  /// **'中身を編集'**
  String get nodeprogEditorEditFunctionBody;

  /// ノードの詳細のボタン(カスタム関数)。
  ///
  /// In ja, this message translates to:
  /// **'関数を削除'**
  String get nodeprogEditorDeleteFunction;

  /// ノード情報の 1 行目。{genre} = ノードのジャンル。
  ///
  /// In ja, this message translates to:
  /// **'ジャンル: {genre}'**
  String nodeprogEditorInfoGenre(String genre);

  /// ノード情報: 上辺の条件接続部。
  ///
  /// In ja, this message translates to:
  /// **'条件(上辺)'**
  String get nodeprogEditorInfoCondIn;

  /// ノード情報: 下辺の条件接続部。
  ///
  /// In ja, this message translates to:
  /// **'条件(下辺)'**
  String get nodeprogEditorInfoCondOut;

  /// TL のカスタマイズのタブ: すべての DM のページに効く共通の設定。
  ///
  /// In ja, this message translates to:
  /// **'DM(共通)'**
  String get nodeprogTimelineTabDmCommon;

  /// TL のカスタマイズのタブ: この DM のページだけの設定。
  ///
  /// In ja, this message translates to:
  /// **'このDM'**
  String get nodeprogTimelineTabThisDm;

  /// トレンドの TL のカスタマイズのタブ。
  ///
  /// In ja, this message translates to:
  /// **'トレンドページ'**
  String get nodeprogTimelineTabTrendPage;

  /// トレンドの TL のカスタマイズのタブ。
  ///
  /// In ja, this message translates to:
  /// **'トレンド TL'**
  String get nodeprogTimelineTabTrendTl;

  /// TL のカスタマイズのタブ: 開いているリストの TL。
  ///
  /// In ja, this message translates to:
  /// **'このリスト'**
  String get nodeprogTimelineTabThisList;

  /// タブを並べ替えるシートの見出しとボタン。
  ///
  /// In ja, this message translates to:
  /// **'タブの並べ替え'**
  String get nodeprogTimelineReorderTabs;

  /// … メニューの項目(チェック付き)。
  ///
  /// In ja, this message translates to:
  /// **'すべてのアカウントで共有'**
  String get nodeprogTimelineShareTab;

  /// … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'このTLの構成をリセット'**
  String get nodeprogTimelineResetConfig;

  /// … メニューの項目(ノードエディターで開く)。
  ///
  /// In ja, this message translates to:
  /// **'グラフで編集'**
  String get nodeprogTimelineEditAsGraph;

  /// アルゴリズムのタイルの副題(プラグインの版つき)。{version} = 版。
  ///
  /// In ja, this message translates to:
  /// **'TLプラグイン ・ v{version}'**
  String nodeprogTimelinePluginWithVersion(String version);

  /// アルゴリズム「時刻順」の説明。
  ///
  /// In ja, this message translates to:
  /// **'取得したままの時刻順に整えます。'**
  String get nodeprogTimelineAlgoChronoDescription;

  /// アルゴリズム「指向性/刺激性」の説明。
  ///
  /// In ja, this message translates to:
  /// **'好みの設定に合わない投稿を除き、合う順に並べます。'**
  String get nodeprogTimelineAlgoTendencyDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'トレンドプロファイル(指向性/刺激性・好きなジャンル)に合わない投稿を除外し、適合度順に並べます。'**
  String get nodeprogTimelineAlgoTendencyDetail;

  /// アルゴリズム「おすすめ」の説明。{from} = 基準の取得元、{kind} = 基準の種類、{what} = 比べ方。
  ///
  /// In ja, this message translates to:
  /// **'{from}({kind})を基準に、{what}で合う投稿を先頭へ並べ替えます。'**
  String nodeprogTimelineAlgoSuggestDescription(
    String from,
    String kind,
    String what,
  );

  /// おすすめの基準の種類。
  ///
  /// In ja, this message translates to:
  /// **'自分の投稿'**
  String get nodeprogTimelineSuggestFromMyPosts;

  /// おすすめの基準の種類。
  ///
  /// In ja, this message translates to:
  /// **'自分の返信'**
  String get nodeprogTimelineSuggestFromMyReplies;

  /// おすすめの基準の種類。
  ///
  /// In ja, this message translates to:
  /// **'リアクションした投稿'**
  String get nodeprogTimelineSuggestFromReacted;

  /// 取得元のタイルの説明: SNS が宣言していないときの home の TL の名前。
  ///
  /// In ja, this message translates to:
  /// **'フォロー中 (home)'**
  String get nodeprogTimelineSourceHomeLabel;

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'RASQ の投稿を取得'**
  String get nodeprogTimelineSourceRasqTitle;

  /// 取得元のタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'TL: 自分とフォロー中の RASQ アカウントの投稿'**
  String get nodeprogTimelineSourceRasqDescription;

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'RASQ 検索'**
  String get nodeprogTimelineSourceRasqSearchTitle;

  /// 取得元のタイルの説明(検索ワードが空)。
  ///
  /// In ja, this message translates to:
  /// **'検索: このページの検索ワード / タグ(フォローしていない人の投稿も)'**
  String get nodeprogTimelineSourceRasqSearchPageQuery;

  /// 取得元のタイルの説明。{word} = 検索ワード。
  ///
  /// In ja, this message translates to:
  /// **'検索: {word}(フォローしていない人の投稿も)'**
  String nodeprogTimelineSourceRasqSearchWord(String word);

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストを取得'**
  String get nodeprogTimelineSourceRasqListTitle;

  /// 取得元のタイルの説明。{name} = リストの名前(未選択なら「未選択」)。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト: {name}'**
  String nodeprogTimelineSourceRasqListDescription(String name);

  /// リスト / フィードなどがまだ選ばれていないとき。
  ///
  /// In ja, this message translates to:
  /// **'未選択'**
  String get nodeprogTimelineNotSelected;

  /// セクション(ノードを包む枠)の名前・提供元の欄。
  ///
  /// In ja, this message translates to:
  /// **'セクション'**
  String get nodeprogTimelineSectionTitle;

  /// セクションの説明。{max} = 入れられるノードの数。
  ///
  /// In ja, this message translates to:
  /// **'{max, plural, other{ノードを {max} つまで包む枠(画面では入れた順に角丸の枠で出す)}}'**
  String nodeprogTimelineSectionDescription(int max);

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'ASTell のタイル'**
  String get nodeprogTimelineSourceAstellTitle;

  /// 取得元のタイルの説明。{count} = 出す件数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{いま開いている ASTell のルーム({count} 件まで)}}'**
  String nodeprogTimelineSourceAstellDescription(int count);

  /// 取得元のタイルの説明。{count} = 出す件数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{Swing を出している人({count} 件まで)}}'**
  String nodeprogTimelineSourceSwingDescription(int count);

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'フォロー中の反応'**
  String get nodeprogTimelineSourceTrendFollowingTitle;

  /// 取得元のタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'フォロー中の人の、このページのワード / タグの投稿'**
  String get nodeprogTimelineSourceTrendFollowingDescription;

  /// トレンドプラグインのノード: プラグインを選んでいないとき。
  ///
  /// In ja, this message translates to:
  /// **'入れているトレンドプラグイン全部'**
  String get nodeprogTimelineTrendPluginAll;

  /// トレンドプラグインのノード: 選んだプラグインが入っていないとき。{id} = プラグインの id。
  ///
  /// In ja, this message translates to:
  /// **'{id}(入っていません)'**
  String nodeprogTimelineTrendPluginMissing(String id);

  /// トレンドプラグインのノードの提供元の欄。
  ///
  /// In ja, this message translates to:
  /// **'トレンドプラグイン'**
  String get nodeprogTimelineTrendPluginAuthor;

  /// トレンドプラグインのノードの説明。{name} = プラグインの名前、{form} = 形式の説明。
  ///
  /// In ja, this message translates to:
  /// **'{name} ・ {form}'**
  String nodeprogTimelineTrendPluginDescription(String name, String form);

  /// 取得元のアカウントが空のとき。
  ///
  /// In ja, this message translates to:
  /// **'(現在のアカウント)'**
  String get nodeprogTimelineCurrentAccount;

  /// トレンドを取得のノード: アカウントが空(全部のアカウント)のときの提供元の欄。
  ///
  /// In ja, this message translates to:
  /// **'全部のアカウント'**
  String get nodeprogTimelineAllAccounts;

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'トレンドを取得'**
  String get nodeprogTimelineSourceTrendTitle;

  /// 取得元のタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'種別: トレンドタイル(RASQ アカウントの SNS アカウント全部のトレンドのワード)'**
  String get nodeprogTimelineSourceTrendTagsAllDescription;

  /// 取得元のタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'種別: トレンドタイル(このアカウントのサーバーのトレンドのワード)'**
  String get nodeprogTimelineSourceTrendTagsDescription;

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'検索結果を取得'**
  String get nodeprogTimelineSourceSearchTitle;

  /// 取得元のタイルの説明(検索ワードが空)。
  ///
  /// In ja, this message translates to:
  /// **'検索: このページの検索ワード / タグ'**
  String get nodeprogTimelineSourceSearchPageQuery;

  /// 取得元のタイルの説明。{word} = 検索ワード。
  ///
  /// In ja, this message translates to:
  /// **'検索: {word}'**
  String nodeprogTimelineSourceSearchWord(String word);

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'Today を取得'**
  String get nodeprogTimelineSourceTodayTitle;

  /// 取得元のタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'TL: Today(注目の投稿)'**
  String get nodeprogTimelineSourceTodayDescription;

  /// 取得元のタイルの名前: 開いているページそのものの投稿。{name} = ページの名前。
  ///
  /// In ja, this message translates to:
  /// **'{name}を取得'**
  String nodeprogTimelineSourceSelfTitle(String name);

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'DM取得'**
  String get nodeprogTimelineSourceDmTitle;

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'カスタムフィードを取得'**
  String get nodeprogTimelineSourceFeedTitle;

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'リストTLを取得'**
  String get nodeprogTimelineSourceListTitle;

  /// 取得元のタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインを取得'**
  String get nodeprogTimelineSourceTimelineTitle;

  /// 取得元のタイルの説明。{tl} = 取得する TL の説明。
  ///
  /// In ja, this message translates to:
  /// **'TL: {tl}'**
  String nodeprogTimelineSourceTlDescription(String tl);

  /// 取得元のタイルの説明の中身。{peer} = DM の相手のハンドル。
  ///
  /// In ja, this message translates to:
  /// **'DM: @{peer}'**
  String nodeprogTimelineSourceDmPeer(String peer);

  /// 取得元のタイルの説明の中身。
  ///
  /// In ja, this message translates to:
  /// **'種別: トレンド TL(トレンド上位タグの検索結果)'**
  String get nodeprogTimelineSourceTrendTlKind;

  /// 取得元のタイルの説明の中身。{name} = フィードの名前(または URI)。
  ///
  /// In ja, this message translates to:
  /// **'フィード: {name}'**
  String nodeprogTimelineSourceFeedName(String name);

  /// 取得元のタイルの説明の中身。{name} = リストの名前。
  ///
  /// In ja, this message translates to:
  /// **'リスト: {name}'**
  String nodeprogTimelineSourceListName(String name);

  /// 部品の … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'詳細'**
  String get nodeprogTimelineMenuInfo;

  /// 部品の … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'パラメーターを編集'**
  String get nodeprogTimelineMenuEditParams;

  /// 部品の … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'一時的な無効化'**
  String get nodeprogTimelineMenuDisable;

  /// 部品の … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'無効化の解除'**
  String get nodeprogTimelineMenuEnable;

  /// 部品の … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'プラグインのストアページへ移動'**
  String get nodeprogTimelineMenuStore;

  /// 部品の … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'種別をトレンドタイルに'**
  String get nodeprogTimelineMenuKindToTiles;

  /// 部品の … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'種別をトレンド TL に'**
  String get nodeprogTimelineMenuKindToTl;

  /// 部品の … メニューの項目。{count} = いまの件数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{件数: {count}}}'**
  String nodeprogTimelineMenuLimit(int count);

  /// 部品の … メニューの項目。{form} = いまの形式。
  ///
  /// In ja, this message translates to:
  /// **'形式: {form}'**
  String nodeprogTimelineMenuForm(String form);

  /// 部品の … メニューの項目。{mode} = いまの表示モード。
  ///
  /// In ja, this message translates to:
  /// **'表示モード: {mode}'**
  String nodeprogTimelineMenuDisplay(String mode);

  /// 件数の選択肢。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 件}}'**
  String nodeprogTimelineLimitItems(int count);

  /// 部品の詳細のシート。{provider} = 提供元。
  ///
  /// In ja, this message translates to:
  /// **'提供: {provider}'**
  String nodeprogTimelineInfoProvider(String provider);

  /// 部品の詳細のシート。{sns} = 対応する SNS の一覧。
  ///
  /// In ja, this message translates to:
  /// **'対応: {sns}'**
  String nodeprogTimelineInfoSupported(String sns);

  /// 並べ替えのシートの見出しとボタン。
  ///
  /// In ja, this message translates to:
  /// **'アルゴリズムの並べ替え'**
  String get nodeprogTimelineReorderAlgorithms;

  /// 並べ替えのシートの見出し。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの並べ替え'**
  String get nodeprogTimelineReorderSources;

  /// TL のカスタマイズの説明のバナー(DM 共通)。
  ///
  /// In ja, this message translates to:
  /// **'すべての DM ページに使う設定です'**
  String get nodeprogTimelineBannerDmCommon;

  /// TL のカスタマイズの説明のバナー(DM の 1 ページ)。
  ///
  /// In ja, this message translates to:
  /// **'この DM ページだけの設定です'**
  String get nodeprogTimelineBannerDmPage;

  /// TL のカスタマイズの説明のバナー。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの中身と並び方を決められます'**
  String get nodeprogTimelineBanner;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'DM のメイン設定です。個別設定のない全ての DM ページに適用されます。アルゴリズムは上から順に適用されます。'**
  String get nodeprogTimelineBannerDmCommonDetail;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'この DM ページだけの設定です(保存すると DM 共通設定より優先されます)。アルゴリズムは上から順に適用されます。'**
  String get nodeprogTimelineBannerDmPageDetail;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインのアルゴリズムや取り込み、表示するタイムラインなどを指定できます。アルゴリズムは上から順に適用されます。'**
  String get nodeprogTimelineBannerDetail;

  /// タイムラインを作る FOW の名前の欄。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの名前'**
  String get nodeprogTimelineCreateNameLabel;

  /// タイムラインを作る FOW の名前の欄のヒント。
  ///
  /// In ja, this message translates to:
  /// **'例: 友だち / 写真'**
  String get nodeprogTimelineCreateNameHint;

  /// 一時変更 FOW: プラグインが並べる TL のとき。
  ///
  /// In ja, this message translates to:
  /// **'プラグインが並べるタイムラインです。ここでは探すだけできます'**
  String get nodeprogTimelineTempSearchOnly;

  /// 一時変更 FOW: 一時的に変えているとき。
  ///
  /// In ja, this message translates to:
  /// **'このタイムラインを一時的に変えています(保存していません)。'**
  String get nodeprogTimelineTempChanged;

  /// 一時変更 FOW のボタン。
  ///
  /// In ja, this message translates to:
  /// **'元に戻す'**
  String get nodeprogTimelineTempRevert;

  /// 一時変更 FOW のボタン。
  ///
  /// In ja, this message translates to:
  /// **'この内容で保存'**
  String get nodeprogTimelineTempSave;

  /// 一時変更 FOW の案内。
  ///
  /// In ja, this message translates to:
  /// **'ここでの変更は一時的です。保存するまで元の設定は変わりません'**
  String get nodeprogTimelineTempNotice;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'ここでの変更はこのタイムラインに一時的に効きます。保存するまで、元の設定は変わりません。'**
  String get nodeprogTimelineTempNoticeDetail;

  /// タイムラインを作る FOW の案内。
  ///
  /// In ja, this message translates to:
  /// **'取り込むタイムラインとアルゴリズムを選んで「決定」'**
  String get nodeprogTimelineCreateCaption;

  /// ノードエディターで手を入れた TL の警告。
  ///
  /// In ja, this message translates to:
  /// **'この TL はノードエディタで編集されています。ここで変えると上書きされます'**
  String get nodeprogTimelineHandEdited;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'この TL はノードエディタで編集されています。ここで変更すると簡易構成で置き換えます。'**
  String get nodeprogTimelineHandEditedDetail;

  /// TL のカスタマイズの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'アルゴリズム'**
  String get nodeprogTimelineAlgorithmsHeader;

  /// TL のカスタマイズの追加のタイル。
  ///
  /// In ja, this message translates to:
  /// **'アルゴリズムを追加'**
  String get nodeprogTimelineAddAlgorithm;

  /// セクションのタイルの副題。{count} = 入れたノードの数、{max} = 入れられる数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{セクション ・ {count} / {max}}}'**
  String nodeprogTimelineSectionSubtitle(int count, int max);

  /// 副題の後ろに付ける、一時的に無効にしている印(前に区切り)。
  ///
  /// In ja, this message translates to:
  /// **' ・ 無効化中'**
  String get nodeprogTimelineDisabledSuffix;

  /// 一時的に無効にしている印。
  ///
  /// In ja, this message translates to:
  /// **'無効化中'**
  String get nodeprogTimelineDisabled;

  /// 副題に並べる語の区切り(前後に空白)。
  ///
  /// In ja, this message translates to:
  /// **' ・ '**
  String get nodeprogTimelineMetaSeparator;

  /// セクションの … ボタン。
  ///
  /// In ja, this message translates to:
  /// **'セクションの操作'**
  String get nodeprogTimelineSectionMenuTooltip;

  /// セクションにノードを足すボタン・メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'ノードを追加'**
  String get nodeprogTimelineAddNode;

  /// セクションの中のノードの … ボタン。
  ///
  /// In ja, this message translates to:
  /// **'ノードの操作'**
  String get nodeprogTimelineNodeMenuTooltip;

  /// セクションの … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'見出しを変更'**
  String get nodeprogTimelineSectionRename;

  /// セクションの見出しを変えるダイアログの見出し。
  ///
  /// In ja, this message translates to:
  /// **'セクションの見出し'**
  String get nodeprogTimelineSectionRenameTitle;

  /// セクションの中のノードの … メニューの項目。
  ///
  /// In ja, this message translates to:
  /// **'セクションから出す'**
  String get nodeprogTimelineMenuTakeOut;

  /// TL のカスタマイズの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'表示モード'**
  String get nodeprogTimelineDisplayHeader;

  /// 表示モードの行。{mode} = いまの表示モード。
  ///
  /// In ja, this message translates to:
  /// **'表示: {mode}'**
  String nodeprogTimelineDisplayTitle(String mode);

  /// 表示モードの行の説明。
  ///
  /// In ja, this message translates to:
  /// **'同じ投稿を、通常の TL / 会話のまとまり(関連 TL)/ 投稿した人の並びで見せます'**
  String get nodeprogTimelineDisplaySubtitle;

  /// TL のカスタマイズの節の見出し(取得元)。
  ///
  /// In ja, this message translates to:
  /// **'SNSタイムライン'**
  String get nodeprogTimelineSourcesHeader;

  /// 取得元の並べ替えのボタン(並べ替え中)。
  ///
  /// In ja, this message translates to:
  /// **'並べ替えを終える'**
  String get nodeprogTimelineReorderDone;

  /// トレンドページの取得元の節の説明。
  ///
  /// In ja, this message translates to:
  /// **'検索ホームに上から順に出します。セクションでトレンドと Today の区間を分けます'**
  String get nodeprogTimelineTrendPageCaption;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'検索ホームに上から順に出します。既定は「トレンド」(全部のアカウントのトレンドのタイル)と「Today」のセクションです。アルゴリズムはトレンドのタイルに掛かります(重いものは使えません)。'**
  String get nodeprogTimelineTrendPageCaptionDetail;

  /// 取得元の節の説明。
  ///
  /// In ja, this message translates to:
  /// **'複数を重ねると 1 本にまとまり、同じ投稿は 1 つになります'**
  String get nodeprogTimelineSourcesCaption;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'複数を重ねると 1 本に合流し、同じ投稿は 1 枚に畳まれます(タイルの ↓ でアカウント切替)。投稿加工プラグインは各タイムライン提供元(SNSプラグイン)側で適用されます。'**
  String get nodeprogTimelineSourcesCaptionDetail;

  /// 取得元の並べ替え中の案内。
  ///
  /// In ja, this message translates to:
  /// **'長押しでつかんで動かします。セクションの中(3 つまで)へも出し入れできます'**
  String get nodeprogTimelineReorderHint;

  /// 取得元の節の追加のボタン。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインを追加'**
  String get nodeprogTimelineAddSource;

  /// TL のカスタマイズの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'自動更新'**
  String get nodeprogTimelineClockHeader;

  /// 自動更新の間隔の行。{interval} = 間隔(なしなら「なし」)。
  ///
  /// In ja, this message translates to:
  /// **'間隔: {interval}'**
  String nodeprogTimelineClockInterval(String interval);

  /// アルゴリズムのタイルの … ボタン。
  ///
  /// In ja, this message translates to:
  /// **'アルゴリズムの操作'**
  String get nodeprogTimelineAlgorithmMenuTooltip;

  /// 取得元のタイルの … ボタン。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの操作'**
  String get nodeprogTimelineSourceMenuTooltip;

  /// 指向性/刺激性(傾向)の要約。{count} = 好きなジャンルの数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{好きなジャンル {count}}}'**
  String nodeprogTimelineTendencyGenres(int count);

  /// 指向性/刺激性(傾向)の要約。{count} = 好きではないジャンルの数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{好きではない {count}}}'**
  String nodeprogTimelineTendencyDisliked(int count);

  /// 指向性/刺激性(傾向)の要約。{count} = 例の数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{例 {count}}}'**
  String nodeprogTimelineTendencyExamples(int count);

  /// 指向性/刺激性(傾向)の要約。{count} = 上限を下げた刺激性の数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{刺激性の上限 {count}}}'**
  String nodeprogTimelineTendencyStimulus(int count);

  /// アルゴリズムの一番最後に固定で掛かる項目の名前。
  ///
  /// In ja, this message translates to:
  /// **'指向性/刺激性(傾向)'**
  String get nodeprogTimelineTendencyPinnedTitle;

  /// アルゴリズムの一番最後に固定で掛かる項目の副題。
  ///
  /// In ja, this message translates to:
  /// **'いつも最後'**
  String get nodeprogTimelineTendencyPinnedSubtitle;

  /// アルゴリズムの一番最後に固定で掛かる項目の説明(要約が無いとき)。
  ///
  /// In ja, this message translates to:
  /// **'傾向 FOW の設定'**
  String get nodeprogTimelineTendencyPinnedEmpty;

  /// ℹ️ のツールチップ。
  ///
  /// In ja, this message translates to:
  /// **'傾向 FOW で設定した指向性/刺激性を、アルゴリズムの一番最後に掛けます。ここでは外せません(変える / 止めるときは傾向 FOW で)'**
  String get nodeprogTimelineTendencyPinnedInfo;

  /// 部品のパラメーターの節の見出し(サジェスト)。
  ///
  /// In ja, this message translates to:
  /// **'なにをサジェストする?'**
  String get nodeprogTimelineParamsSuggestWhat;

  /// 部品のパラメーターの節の見出し(サジェスト)。
  ///
  /// In ja, this message translates to:
  /// **'なにから読み取る?'**
  String get nodeprogTimelineParamsSuggestFrom;

  /// 部品のパラメーターの説明。
  ///
  /// In ja, this message translates to:
  /// **'このプラグインの設定は準備中です。'**
  String get nodeprogTimelineParamsPluginPending;

  /// 部品のパラメーターの説明(検索絞り込み)。
  ///
  /// In ja, this message translates to:
  /// **'ワードが空のときは、このページの検索ワード/タグで絞り込みます。ワードは下の欄で指定できます。'**
  String get nodeprogTimelineParamsQueryFilter;

  /// 部品のパラメーターの説明(指向性/刺激性)。
  ///
  /// In ja, this message translates to:
  /// **'好みの設定を使います。下から変えられます。'**
  String get nodeprogTimelineParamsTendency;

  /// 部品のパラメーターの説明(時系列順)。
  ///
  /// In ja, this message translates to:
  /// **'時系列順にパラメーターはありません。'**
  String get nodeprogTimelineParamsChrono;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'このプラグインのパラメーター(RRL 設定ページ)は、ノード定義の配布(ストア統合)でここに表示されます。'**
  String get nodeprogTimelineParamsPluginPendingDetail;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'storage.safe のトレンドプロファイルを使います。下のオプションから指向性/刺激性・好きなジャンル・アクションからのジャンル選択を編集できます(検索ホームのトレンド ⚙ と同じもの)。'**
  String get nodeprogTimelineParamsTendencyDetail;

  /// 部品のパラメーターの説明(トレンドプラグイン)。
  ///
  /// In ja, this message translates to:
  /// **'トレンドプラグインが出した候補のワードを、選んだ形式で出します。'**
  String get nodeprogTimelineParamsTrendPlugin;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'スロット trend.suggest の答え(候補のワード)を、トレンドを取得 = トレンドのタイル / Today = 上位の語の投稿のダイジェスト / カスタム = 候補のチップ で出します。件数は … から。'**
  String get nodeprogTimelineParamsTrendPluginDetail;

  /// 部品のパラメーターの節の見出し(トレンドプラグイン)。
  ///
  /// In ja, this message translates to:
  /// **'形式'**
  String get nodeprogTimelineParamsForm;

  /// 部品のパラメーターの説明。
  ///
  /// In ja, this message translates to:
  /// **'自分とフォロー中の人の RASQ の投稿を取り込みます。RASQ にログインしているときだけ流れます。'**
  String get nodeprogTimelineParamsRasq;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'自分とフォロー中の RASQ アカウントの投稿 / リブロードを取り込みます。RASQ アカウントにログインしているときだけ流れます。パラメーターはありません。'**
  String get nodeprogTimelineParamsRasqDetail;

  /// 部品のパラメーターの説明。
  ///
  /// In ja, this message translates to:
  /// **'RASQ の公開の投稿を検索して取り込みます。フォローしていない人の投稿も入ります。'**
  String get nodeprogTimelineParamsRasqSearch;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'RASQ の公開の投稿(フォロー中かどうかに関係なく)を、下のワードで検索して取り込みます。空にすると、このページの検索ワード / タグで探します。表示モードを「ユーザー」にすると、投稿した人のタイルで並びます。'**
  String get nodeprogTimelineParamsRasqSearchDetail;

  /// 部品のパラメーターの説明。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストの投稿を取り込みます。下で選ぶと、そのリストをフォローします。'**
  String get nodeprogTimelineParamsRasqList;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストの投稿を取り込みます(Central が、見たときにリスト内の人の投稿を集めます)。下の欄で、自分のリスト・フォロー中のリストから選ぶか、公開リストを検索して選びます。選ぶと、そのリストをフォローします。'**
  String get nodeprogTimelineParamsRasqListDetail;

  /// 開発者モードの説明。{name} = 開いているページの投稿の名前。
  ///
  /// In ja, this message translates to:
  /// **'{name}をそのまま取り込みます。パラメーターはありません。'**
  String nodeprogTimelineParamsSelfDetail(String name);

  /// 部品のパラメーターの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'アカウント'**
  String get nodeprogTimelineParamsAccount;

  /// 部品のパラメーターの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'TL 種別(この SNS が出せるもの)'**
  String get nodeprogTimelineParamsTlKind;

  /// 部品のパラメーターの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'リスト(このアカウントのもの)'**
  String get nodeprogTimelineParamsList;

  /// 部品のパラメーター: リストが無いとき。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントにはリストがありません(または取得できません)。'**
  String get nodeprogTimelineParamsNoLists;

  /// 部品のパラメーターの節の見出し。
  ///
  /// In ja, this message translates to:
  /// **'カスタムフィード(下の欄で検索して選ぶ)'**
  String get nodeprogTimelineParamsFeed;

  /// 部品のパラメーター(指向性/刺激性)の項目。
  ///
  /// In ja, this message translates to:
  /// **'トレンドの指向性/刺激性'**
  String get nodeprogTimelineParamsTendencyEdit;

  /// 部品のパラメーター(指向性/刺激性)の項目。
  ///
  /// In ja, this message translates to:
  /// **'好きなジャンル/方向性'**
  String get nodeprogTimelineParamsGenresEdit;

  /// 部品のパラメーター(指向性/刺激性)の項目「アクションからジャンルを選択」の説明。
  ///
  /// In ja, this message translates to:
  /// **'類似した話題でまとめて、話題性の強いものから'**
  String get nodeprogTimelineParamsPickGenresSubtitle;

  /// RASQ 検索のワードの欄。
  ///
  /// In ja, this message translates to:
  /// **'検索ワード(空 = このページのワード / タグ)'**
  String get nodeprogTimelineParamsRasqSearchWordLabel;

  /// RASQ リストの検索の欄。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストを検索(名前 / @作った人 / 共有リンク)'**
  String get nodeprogTimelineParamsRasqListSearchLabel;

  /// カスタムフィードの検索の欄。
  ///
  /// In ja, this message translates to:
  /// **'フィードを検索'**
  String get nodeprogTimelineParamsFeedSearchLabel;

  /// カスタムフィードの検索で何も当たらないとき。
  ///
  /// In ja, this message translates to:
  /// **'見つかりません'**
  String get nodeprogTimelineParamsFeedNotFound;

  /// 検索絞り込みのワードの欄。
  ///
  /// In ja, this message translates to:
  /// **'検索ワード(空 = このページの検索ワード)'**
  String get nodeprogTimelineParamsQueryLabel;

  /// 検索絞り込みのスイッチ。
  ///
  /// In ja, this message translates to:
  /// **'このワードを含む投稿を除外する'**
  String get nodeprogTimelineParamsExcludeTitle;

  /// 検索絞り込みのスイッチの説明。
  ///
  /// In ja, this message translates to:
  /// **'オフなら含む投稿だけ通します'**
  String get nodeprogTimelineParamsExcludeSubtitle;

  /// タイムラインを作る FOW の見出しと読み上げ。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインを作成'**
  String get nodeprogTimelineCreateTitle;

  /// 名前を入れずに作ったタイムラインの名前。{number} = 通し番号。
  ///
  /// In ja, this message translates to:
  /// **'タイムライン {number}'**
  String nodeprogTimelineCreateDefaultName(int number);

  /// タイムラインを作るときの確認の見出し。
  ///
  /// In ja, this message translates to:
  /// **'他のアカウントにも適用しますか'**
  String get nodeprogTimelineCreateShareTitle;

  /// タイムラインを作るときの確認の本文。
  ///
  /// In ja, this message translates to:
  /// **'「すべてのアカウントに適用」にすると、どのアカウントでもこのタイムラインが並び、中身の変更も全部に効きます(あとで … メニューから変えられます)。'**
  String get nodeprogTimelineCreateShareMessage;

  /// タイムラインを作るときの確認のボタン。
  ///
  /// In ja, this message translates to:
  /// **'すべてのアカウントに適用'**
  String get nodeprogTimelineCreateShareConfirm;

  /// タイムラインを作るときの確認のボタン。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントだけ'**
  String get nodeprogTimelineCreateShareCancel;

  /// セクションのノードの中身が読み込めなかったとき。
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした'**
  String get nodeprogTimelineLoadFailed;

  /// ノードの名前(トレンドのタイル)。
  ///
  /// In ja, this message translates to:
  /// **'トレンド'**
  String get nodeprogTimelineNodeTrend;

  /// ノードの名前: 見つからないノードのタブ。
  ///
  /// In ja, this message translates to:
  /// **'ノード TL'**
  String get nodeprogTimelineNodeTabFallback;

  /// セクションの読み直しのボタン。
  ///
  /// In ja, this message translates to:
  /// **'読み直す'**
  String get nodeprogTimelineReload;

  /// ASTell のタイルのノードが空のとき。
  ///
  /// In ja, this message translates to:
  /// **'いま開いている ASTell はありません'**
  String get nodeprogTimelineAstellEmpty;

  /// ASTell のタイルのノードが空のとき。{query} = このページの検索ワード。
  ///
  /// In ja, this message translates to:
  /// **'「{query}」の ASTell はありません'**
  String nodeprogTimelineAstellEmptyQuery(String query);

  /// Swing のノードが空のとき。
  ///
  /// In ja, this message translates to:
  /// **'いま Swing はありません'**
  String get nodeprogTimelineSwingEmpty;

  /// Swing のノードが空のとき。{query} = このページの検索ワード。
  ///
  /// In ja, this message translates to:
  /// **'「{query}」の Swing はありません'**
  String nodeprogTimelineSwingEmptyQuery(String query);

  /// トレンドのノードが空のとき。
  ///
  /// In ja, this message translates to:
  /// **'トレンドはまだありません'**
  String get nodeprogTimelineTrendEmpty;

  /// フォロー中の反応のノード: このページにワードが無いとき。
  ///
  /// In ja, this message translates to:
  /// **'トレンド TL で出ます'**
  String get nodeprogTimelineTrendFollowingNoQuery;

  /// フォロー中の反応のノードが空のとき。
  ///
  /// In ja, this message translates to:
  /// **'フォロー中の人の反応はまだありません'**
  String get nodeprogTimelineTrendFollowingEmpty;

  /// TL のノードが空のとき。
  ///
  /// In ja, this message translates to:
  /// **'まだありません'**
  String get nodeprogTimelinePostsEmpty;

  /// 表示モード「関連」で空のとき。
  ///
  /// In ja, this message translates to:
  /// **'会話のまとまりはまだありません'**
  String get nodeprogTimelineEventsEmpty;

  /// 表示モード「ユーザー」で空のとき。
  ///
  /// In ja, this message translates to:
  /// **'まだいません'**
  String get nodeprogTimelineUsersEmpty;

  /// 表示モード「ユーザー」の人の副題。{count} = その人の投稿の数。
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 件の投稿}}'**
  String nodeprogTimelineUserPostCount(int count);

  /// 一時変更 FOW の読み上げ。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインを一時的に変える'**
  String get nodeprogTimelineTempSemantics;

  /// TL 内の検索のボタン。
  ///
  /// In ja, this message translates to:
  /// **'前の該当投稿'**
  String get nodeprogTimelineSearchPrev;

  /// TL 内の検索のボタン。
  ///
  /// In ja, this message translates to:
  /// **'次の該当投稿'**
  String get nodeprogTimelineSearchNext;

  /// TL 内の検索の欄のヒント。
  ///
  /// In ja, this message translates to:
  /// **'このタイムラインから探す'**
  String get nodeprogTimelineSearchHint;

  /// TL 内の検索のチップ。
  ///
  /// In ja, this message translates to:
  /// **'近似検索'**
  String get nodeprogTimelineSearchFuzzy;

  /// 一時変更 FOW を閉じるボタン。
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get nodeprogTimelineTempClose;

  /// 一時変更 FOW の見出し。
  ///
  /// In ja, this message translates to:
  /// **'タイムラインを一時変更'**
  String get nodeprogTimelineTempTitle;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'サジェスト'**
  String get nodeprogTimelinePaletteSuggestTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'あなたの投稿や反応に近い投稿を先頭に並べます。'**
  String get nodeprogTimelinePaletteSuggestDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'[キーワード/類似性] を [投稿内容/リアクション/会話内容] から読み取り、合う投稿を先頭へ並べ替えます。'**
  String get nodeprogTimelinePaletteSuggestDetail;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'絞り込み'**
  String get nodeprogTimelinePaletteFilterTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'あなたの投稿や反応に合わない投稿を除きます。'**
  String get nodeprogTimelinePaletteFilterDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'[キーワード/類似性] を [投稿内容/リアクション/会話内容] から読み取り、合わない投稿を除外します(サジェストと同じパラメーター)。'**
  String get nodeprogTimelinePaletteFilterDetail;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'検索絞り込み'**
  String get nodeprogTimelinePaletteQueryFilterTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'このページの検索ワード/タグ(または指定ワード)に合う投稿だけ通します。'**
  String get nodeprogTimelinePaletteQueryFilterDescription;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'指向性/刺激性'**
  String get nodeprogTimelinePaletteTendencyTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'好みの設定に合わない投稿を除き、合う順に並べます。'**
  String get nodeprogTimelinePaletteTendencyDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'トレンドプロファイル(好きなジャンル/方向性・指向性のしきい値・刺激性の上限)に合わない投稿を除外し、適合度順に並べます。プロファイルは検索ホームのトレンド ⚙ で編集します。'**
  String get nodeprogTimelinePaletteTendencyDetail;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'アクションからジャンルを選択'**
  String get nodeprogTimelinePalettePickGenresTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'反応した投稿の話題から、好きなジャンルを選びます。'**
  String get nodeprogTimelinePalettePickGenresDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'リアクションした投稿を類似した話題でまとめ、話題性の強いものから「好き / 好きではない」で好きなジャンルを決めます(指向性/刺激性の部品がこのプロファイルを使います)。'**
  String get nodeprogTimelinePalettePickGenresDetail;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'時系列順'**
  String get nodeprogTimelinePaletteChronoTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'取得したままの時刻順に整えます。'**
  String get nodeprogTimelinePaletteChronoDescription;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'この DM ページのメッセージをそのまま取り込みます。'**
  String get nodeprogTimelinePaletteThisDmDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'この DM ページのメッセージをそのまま取り込みます(共通設定ではそれぞれのページの DM)。'**
  String get nodeprogTimelinePaletteThisDmDetail;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントで、このページの検索ワード / タグを検索した結果を取り込みます。'**
  String get nodeprogTimelinePaletteSearchResultsDescription;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'RASQ の投稿'**
  String get nodeprogTimelinePaletteRasqPostsTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'自分とフォロー中の人の RASQ の投稿を取り込みます。'**
  String get nodeprogTimelinePaletteRasqPostsDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'自分とフォロー中の RASQ アカウントの投稿 / リブロードを取り込みます。SNS の投稿と同じタイムラインに混ぜられます。'**
  String get nodeprogTimelinePaletteRasqPostsDetail;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'タイムライン'**
  String get nodeprogTimelinePaletteTimelineTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'アカウントのタイムラインを取り込みます。種類は追加後に選べます。'**
  String get nodeprogTimelinePaletteTimelineDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'アカウントの基本タイムラインを取り込みます。種類はその SNS が出せるもの(フォロー中 / ローカル / グローバル / Discover …)から、アカウントと合わせて追加後のタイルで選べます。'**
  String get nodeprogTimelinePaletteTimelineDetail;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'リストTL'**
  String get nodeprogTimelinePaletteListTlTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'アカウントのリストを取り込みます。リストは追加後に選べます。'**
  String get nodeprogTimelinePaletteListTlDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'アカウントと、そのアカウントに含まれるリストのタイムラインを取り込みます(追加後のタイルで選択)。'**
  String get nodeprogTimelinePaletteListTlDetail;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'カスタムフィード(Bluesky)'**
  String get nodeprogTimelinePaletteFeedTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'Bluesky のカスタムフィードを探して取り込みます。'**
  String get nodeprogTimelinePaletteFeedDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'Bluesky のカスタムフィードを検索して取り込みます(SNS を跨いだリストは「RASQ リスト」)。'**
  String get nodeprogTimelinePaletteFeedDetail;

  /// 部品の追加のパレットのタイルの名前。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト'**
  String get nodeprogTimelinePaletteRasqListTitle;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'いくつもの SNS の人をまとめたリストの投稿を取り込みます。'**
  String get nodeprogTimelinePaletteRasqListDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト(Misskey / Mastodon / Bluesky の人を 1 つにまとめたリスト)の投稿を取り込みます。自分のリスト・フォロー中のリストから選ぶか、公開リストを検索します。選べるのは、リスト内の人の情報を取れる(同じサーバーのアカウントがある / 入っている人をフォローしている)リストだけです。'**
  String get nodeprogTimelinePaletteRasqListDetail;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'いまのトレンドを取り込みます。種別(トレンドタイル / トレンド TL)は追加後に切り替えます。'**
  String get nodeprogTimelinePaletteTrendDescription;

  /// 開発者モードの説明。
  ///
  /// In ja, this message translates to:
  /// **'トレンドタイル = サーバーのトレンドのワードのタイル、トレンド TL = いまのトレンド上位タグの検索結果を 1 本に合流した投稿。'**
  String get nodeprogTimelinePaletteTrendDetail;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'フォロー中の人の、このページのワード / タグの投稿を出します。'**
  String get nodeprogTimelinePaletteTrendFollowingDescription;

  /// 部品の追加のパレット(DM)のタイルの説明。{peer} = 相手のハンドル。
  ///
  /// In ja, this message translates to:
  /// **'@{peer} との DM を取り込みます。'**
  String nodeprogTimelinePaletteDmPeerDescription(String peer);

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'ノードを 3 つまで包む枠です。画面では見出しの下に、入れた順で出します。'**
  String get nodeprogTimelinePaletteSectionDescription;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'いま開いている ASTell のルームをタイルで出します。'**
  String get nodeprogTimelinePaletteAstellDescription;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'Swing を出している人を並べます。'**
  String get nodeprogTimelinePaletteSwingDescription;

  /// 部品の追加のパレットのタイルの名前。{form} = 形式、{name} = トレンドプラグインの名前。
  ///
  /// In ja, this message translates to:
  /// **'{form}: {name}'**
  String nodeprogTimelinePaletteTrendPluginTitle(String form, String name);

  /// 開発者モードの説明。{form} = 形式の説明。
  ///
  /// In ja, this message translates to:
  /// **'{form}(スロット trend.suggest の答えを、この形式のノードで出します)'**
  String nodeprogTimelinePaletteTrendPluginDetail(String form);

  /// 部品の追加のパレットのタイルの名前。{account} = アカウントの表記。
  ///
  /// In ja, this message translates to:
  /// **'Today: {account}'**
  String nodeprogTimelinePaletteTodayTitle(String account);

  /// 部品の追加のパレットのタイルの提供元(ジャンルの絞り込みにも使う)。
  ///
  /// In ja, this message translates to:
  /// **'SNSプラグイン'**
  String get nodeprogTimelinePaletteSnsPluginAuthor;

  /// 部品の追加のパレットのタイルの提供元(ジャンルの絞り込みにも使う)。
  ///
  /// In ja, this message translates to:
  /// **'リスト系'**
  String get nodeprogTimelinePaletteListsAuthor;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントの Today(注目の投稿)を取り込みます。'**
  String get nodeprogTimelinePaletteTodayDescription;

  /// 部品の追加のパレットのタイルの名前。{account} = アカウントの表記(または「全部のアカウント」)。
  ///
  /// In ja, this message translates to:
  /// **'トレンド: {account}'**
  String nodeprogTimelinePaletteTrendTagsTitle(String account);

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントの SNS アカウント全部のトレンドのワードを、タイルで出します。'**
  String get nodeprogTimelinePaletteTrendTagsAllDescription;

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントのサーバーのトレンドのワードを、タイルで出します。'**
  String get nodeprogTimelinePaletteTrendTagsDescription;

  /// 部品の追加のパレットのタイルの名前。{account} = アカウントの表記。
  ///
  /// In ja, this message translates to:
  /// **'検索結果: {account}'**
  String nodeprogTimelinePaletteSearchResultsTitle(String account);

  /// 部品の追加のパレットのタイルの説明。{name} = 開いているページの投稿の名前。
  ///
  /// In ja, this message translates to:
  /// **'{name}をそのまま取り込みます。'**
  String nodeprogTimelinePaletteSelfDescription(String name);

  /// 部品の追加のパレットのタイルの説明。
  ///
  /// In ja, this message translates to:
  /// **'フォローしていない人も含めて、RASQ の投稿を検索して取り込みます。表示モード「ユーザー」で人のタイルに。'**
  String get nodeprogTimelinePaletteRasqSearchDescription;

  /// 部品の追加のパレットで何も当たらないとき。
  ///
  /// In ja, this message translates to:
  /// **'コンポーネントが見つかりません'**
  String get nodeprogTimelinePaletteEmptyTitle;

  /// 部品の追加のパレットで何も当たらないときのヒント。
  ///
  /// In ja, this message translates to:
  /// **'検索ワードを変えてみてください'**
  String get nodeprogTimelinePaletteEmptyHint;

  /// 通知プロファイル設定のシートのスイッチ。リアクションの通知を出すか
  ///
  /// In ja, this message translates to:
  /// **'リアクションを通知する'**
  String get notificationsPrefReaction;

  /// 通知プロファイル設定のシートのスイッチ。リノートの通知を出すか
  ///
  /// In ja, this message translates to:
  /// **'リノートを通知する'**
  String get notificationsPrefRepost;

  /// 通知プロファイル設定のシートのスイッチ。引用の通知を出すか
  ///
  /// In ja, this message translates to:
  /// **'引用を通知する'**
  String get notificationsPrefQuote;

  /// 通知プロファイル設定のシートのスイッチ。ASTell(音声のルーム)の通知を出すか。ASTell は製品名で訳さない
  ///
  /// In ja, this message translates to:
  /// **'ASTellを通知する'**
  String get notificationsPrefAstell;

  /// 通知プロファイル設定のシートのスイッチ。タイマーを付けたブックマークの時刻が来たときの通知を出すか
  ///
  /// In ja, this message translates to:
  /// **'タイマー付きブックマークを通知する'**
  String get notificationsPrefTimer;

  /// 通知プロファイル設定のシートのスイッチ。投票が締め切られたときの通知を出すか
  ///
  /// In ja, this message translates to:
  /// **'投票の完了を通知する'**
  String get notificationsPrefPollEnded;

  /// 通知プロファイル設定のシートのスイッチ。フォローされた / フォロー申請 / 承認の通知を出すか
  ///
  /// In ja, this message translates to:
  /// **'フォローを通知する'**
  String get notificationsPrefFollow;

  /// 通知プロファイル設定のシートのスイッチ。サーバーやアプリからのお知らせを出すか
  ///
  /// In ja, this message translates to:
  /// **'システム通知を表示する'**
  String get notificationsPrefSystem;

  /// 通知プロファイル設定のシートのスイッチ。返信・メンション・リストへの追加などの残りの通知を出すか
  ///
  /// In ja, this message translates to:
  /// **'その他の通知を配信する'**
  String get notificationsPrefOther;

  /// 通知の画面のタブ。すべての通知
  ///
  /// In ja, this message translates to:
  /// **'すべて'**
  String get notificationsTabAll;

  /// 通知の画面のタブ。フォローしている人からの通知だけ
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get notificationsTabFollowing;

  /// 通知の種類ごとの ON / OFF を選ぶシートの見出し。通知の画面の歯車のボタンのツールチップにも使う
  ///
  /// In ja, this message translates to:
  /// **'通知プロファイル設定'**
  String get notificationsPrefsTitle;

  /// 通知の画面の「フォロー中」のタブが空のとき
  ///
  /// In ja, this message translates to:
  /// **'フォロー中の通知はありません'**
  String get notificationsEmptyFollowing;

  /// 通知プロファイル設定のシートを閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get notificationsClose;

  /// 通知プロファイル設定のシートの一番上のスイッチ。通知全体を出すか
  ///
  /// In ja, this message translates to:
  /// **'通知オン'**
  String get notificationsPrefEnabled;

  /// 通知プロファイル設定のシートの行。押すとプッシュ通知の設定へ進む
  ///
  /// In ja, this message translates to:
  /// **'プッシュ通知の受け取り'**
  String get notificationsPushTitle;

  /// 「プッシュ通知の受け取り」の行の補足。通知を受け取るためだけに使うアクセストークンを設定する
  ///
  /// In ja, this message translates to:
  /// **'通知専用のアクセストークン'**
  String get notificationsPushDetail;

  /// 下のナビの通知のボタンを長押ししたときのメニュー。全部の通知を既読にする
  ///
  /// In ja, this message translates to:
  /// **'全ての通知を既読'**
  String get notificationsQuickReadAll;

  /// 下のナビの通知のボタンを長押ししたときのメニュー。フォローしている人からの通知を既読にする
  ///
  /// In ja, this message translates to:
  /// **'フォロー中の通知を既読'**
  String get notificationsQuickReadFollowing;

  /// 下のナビの通知のボタンを長押ししたときのメニュー。通知を止める
  ///
  /// In ja, this message translates to:
  /// **'通知オフ'**
  String get notificationsQuickOff;

  /// 通知の一覧が空のとき
  ///
  /// In ja, this message translates to:
  /// **'通知はありません'**
  String get notificationsEmpty;

  /// 通知を読み込めなかったときの、やり直すボタン
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get notificationsRetry;

  /// 通知の画面の上の欄の見出し。開始の通知を登録した、これから始まる音声のルーム(VC)の一覧
  ///
  /// In ja, this message translates to:
  /// **'開始通知を登録した VC'**
  String get notificationsRemindersHeader;

  /// 開始通知を登録したルームの行の補足。when は開催の日時(書式済みの文字列)
  ///
  /// In ja, this message translates to:
  /// **'開催予定 {when}'**
  String notificationsReminderSchedule(String when);

  /// 開始通知を登録したルームの行の右端のボタン。登録を外す
  ///
  /// In ja, this message translates to:
  /// **'解除'**
  String get notificationsReminderCancel;

  /// サーバー / アプリからのお知らせに見出しが無いときの見出し
  ///
  /// In ja, this message translates to:
  /// **'システム通知'**
  String get notificationsSystemFallbackTitle;

  /// 通知をした人が 1 人のときの呼び名(太字で出る)。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name}さん'**
  String notificationsActorsOne(String name);

  /// 通知をした人が 2 人のときの呼び名(太字で出る)。first / second は表示名
  ///
  /// In ja, this message translates to:
  /// **'{first}さん、{second}さん'**
  String notificationsActorsTwo(String first, String second);

  /// 通知をした人が 3 人以上のときの呼び名(太字で出る)。first / second は最初の 2 人の表示名、count は残りの人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{first}さん、{second}さんと他{count}人}}'**
  String notificationsActorsMore(String first, String second, int count);

  /// リアクションの通知の文。names は通知をした人の呼び名(notificationsActors… の文。太字で出る)
  ///
  /// In ja, this message translates to:
  /// **'{names}があなたの投稿にリアクションしました'**
  String notificationsActionReacted(String names);

  /// リノートの通知の文。names は通知をした人の呼び名(太字で出る)
  ///
  /// In ja, this message translates to:
  /// **'{names}があなたの投稿をリノートしました'**
  String notificationsActionReposted(String names);

  /// 投票が締め切られた通知の文。names は投票を作った人などの呼び名(太字で出る。空のこともある)
  ///
  /// In ja, this message translates to:
  /// **'{names}が投票が終了しました'**
  String notificationsActionPollEnded(String names);

  /// 種類の分からない通知の文。names は通知をした人の呼び名(太字で出る。空のこともある)
  ///
  /// In ja, this message translates to:
  /// **'{names}が通知'**
  String notificationsActionOther(String names);

  /// 通知の行の右端の … のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get notificationsMenuTooltip;

  /// フォローされた通知の文。name はその人の表示名(太字で出る)
  ///
  /// In ja, this message translates to:
  /// **'{name}にフォローされました'**
  String notificationsFollowFollowed(String name);

  /// フォロー申請が届いた通知の文。name はその人の表示名(太字で出る)
  ///
  /// In ja, this message translates to:
  /// **'{name}からフォロー申請が届きました'**
  String notificationsFollowRequested(String name);

  /// こちらのフォロー申請が承認された通知の文。name は承認した人の表示名(太字で出る)
  ///
  /// In ja, this message translates to:
  /// **'{name}がフォローを承認しました'**
  String notificationsFollowAccepted(String name);

  /// 誰かがこちらを自分のリストに追加した通知の文。name はその人の表示名(太字で出る)
  ///
  /// In ja, this message translates to:
  /// **'{name}がリストに追加しました'**
  String notificationsFollowListAdded(String name);

  /// フォローの通知の行の右のボタン(まだフォローしていないとき)
  ///
  /// In ja, this message translates to:
  /// **'フォロー'**
  String get notificationsFollowButton;

  /// フォローの通知の行の右のボタン(フォローしているとき)
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get notificationsFollowingButton;

  /// 投稿付きの通知の上の小さなラベル。返信が来た
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get notificationsPostReply;

  /// 投稿付きの通知の上の小さなラベル。引用された
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get notificationsPostQuote;

  /// 投稿付きの通知の上の小さなラベル。メンションされた
  ///
  /// In ja, this message translates to:
  /// **'メンション'**
  String get notificationsPostMention;

  /// ブックマークした音声のルーム(VC)が始まる時刻になった通知の文
  ///
  /// In ja, this message translates to:
  /// **'ブックマークしたVCが始まります！'**
  String get notificationsTimerAstell;

  /// タイマーを付けたブックマークの時刻が来た通知の文
  ///
  /// In ja, this message translates to:
  /// **'タイマー付きブックマーク'**
  String get notificationsTimerBookmark;

  /// RASQ のタブで通知を読み込めなかったとき(下にエラーの中身が出る)
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした'**
  String get notificationsRasqLoadError;

  /// RASQ のタブが空のとき。RASQ は製品名で訳さない
  ///
  /// In ja, this message translates to:
  /// **'RASQ の通知はありません'**
  String get notificationsRasqEmpty;

  /// RASQ のタブが空のときの補足。Swing は機能の名前で訳さない
  ///
  /// In ja, this message translates to:
  /// **'メンション / 返信 / 引用 / Swing の招待が届くと、ここに出ます'**
  String get notificationsRasqEmptyHint;

  /// No description provided for @onboardingBack.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get onboardingBack;

  /// No description provided for @onboardingHandleTooShort.
  ///
  /// In ja, this message translates to:
  /// **'3 文字以上にしてください'**
  String get onboardingHandleTooShort;

  /// No description provided for @onboardingHandleTooLong.
  ///
  /// In ja, this message translates to:
  /// **'32 文字までです'**
  String get onboardingHandleTooLong;

  /// No description provided for @onboardingHandleInvalid.
  ///
  /// In ja, this message translates to:
  /// **'半角の英小文字・数字・_ だけ使えます'**
  String get onboardingHandleInvalid;

  /// No description provided for @onboardingAccountTitleNew.
  ///
  /// In ja, this message translates to:
  /// **'新しい RASQ アカウントを作る'**
  String get onboardingAccountTitleNew;

  /// No description provided for @onboardingAccountTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを作る'**
  String get onboardingAccountTitle;

  /// No description provided for @onboardingAccountDescription.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントは、ログインした SNS アカウントをひとつに束ねる「あなた」の入れ物です。入れたプラグイン・設定・アカウントのまとまりを、ほかの端末でも使えます。'**
  String get onboardingAccountDescription;

  /// No description provided for @onboardingHandleLabel.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー名(@ のあとの名前)'**
  String get onboardingHandleLabel;

  /// No description provided for @onboardingHandleHelper.
  ///
  /// In ja, this message translates to:
  /// **'半角の英小文字・数字・_ で 3〜32 文字'**
  String get onboardingHandleHelper;

  /// No description provided for @onboardingPasswordLabel.
  ///
  /// In ja, this message translates to:
  /// **'パスワード({min} 文字以上)'**
  String onboardingPasswordLabel(int min);

  /// No description provided for @onboardingPasswordHide.
  ///
  /// In ja, this message translates to:
  /// **'隠す'**
  String get onboardingPasswordHide;

  /// No description provided for @onboardingPasswordShow.
  ///
  /// In ja, this message translates to:
  /// **'表示'**
  String get onboardingPasswordShow;

  /// No description provided for @onboardingPasswordConfirmLabel.
  ///
  /// In ja, this message translates to:
  /// **'パスワード(確認)'**
  String get onboardingPasswordConfirmLabel;

  /// No description provided for @onboardingPasswordMismatch.
  ///
  /// In ja, this message translates to:
  /// **'一致しません'**
  String get onboardingPasswordMismatch;

  /// No description provided for @onboardingPasswordCaption.
  ///
  /// In ja, this message translates to:
  /// **'ほかの端末や Web 版から、このアカウントにログインするときに使います。'**
  String get onboardingPasswordCaption;

  /// No description provided for @onboardingAgeHeading.
  ///
  /// In ja, this message translates to:
  /// **'年齢'**
  String get onboardingAgeHeading;

  /// No description provided for @onboardingAgeCaption.
  ///
  /// In ja, this message translates to:
  /// **'RASQ は 13 歳以上で使えます。18 歳未満の人は、次のページで保護者の同意を確かめます。'**
  String get onboardingAgeCaption;

  /// No description provided for @onboardingNoCentral.
  ///
  /// In ja, this message translates to:
  /// **'RASQ Central の接続先が未設定です'**
  String get onboardingNoCentral;

  /// No description provided for @onboardingSetCentral.
  ///
  /// In ja, this message translates to:
  /// **'接続先を設定'**
  String get onboardingSetCentral;

  /// No description provided for @onboardingNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get onboardingNext;

  /// No description provided for @onboardingCreateFailed.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを作成できませんでした: {error}'**
  String onboardingCreateFailed(String error);

  /// No description provided for @onboardingTermsTitle.
  ///
  /// In ja, this message translates to:
  /// **'利用規約とプライバシーポリシー'**
  String get onboardingTermsTitle;

  /// No description provided for @onboardingTermsNoDraft.
  ///
  /// In ja, this message translates to:
  /// **'先に ① のページでユーザー名などを入れてください'**
  String get onboardingTermsNoDraft;

  /// No description provided for @onboardingTermsRead.
  ///
  /// In ja, this message translates to:
  /// **'利用規約を読む'**
  String get onboardingTermsRead;

  /// No description provided for @onboardingPrivacyRead.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシーを読む'**
  String get onboardingPrivacyRead;

  /// No description provided for @onboardingAgree.
  ///
  /// In ja, this message translates to:
  /// **'利用規約とプライバシーポリシーに同意する'**
  String get onboardingAgree;

  /// No description provided for @onboardingChildSafeHeading.
  ///
  /// In ja, this message translates to:
  /// **'チャイルドセーフ(18 歳未満)'**
  String get onboardingChildSafeHeading;

  /// age = 年齢の区分の名前(例: 13〜15 歳)
  ///
  /// In ja, this message translates to:
  /// **'{age}の人は、保護者の同意が必要です。保護者の RASQ アカウントとつなぐと、保護者が使い方(見られる投稿の強さ・時間・使える機能)を決められます(設定 → チャイルドセーフ → チャイルドモード)。'**
  String onboardingChildSafeNote(String age);

  /// No description provided for @onboardingGuardianConsent.
  ///
  /// In ja, this message translates to:
  /// **'保護者の同意を得ています'**
  String get onboardingGuardianConsent;

  /// No description provided for @onboardingChildLogin.
  ///
  /// In ja, this message translates to:
  /// **'保護者からのコードでログインする'**
  String get onboardingChildLogin;

  /// No description provided for @onboardingChildLoginCaption.
  ///
  /// In ja, this message translates to:
  /// **'保護者があなたのアカウントを作ってくれた場合は、ここで登録せず、受け取ったコードでログインしてください。'**
  String get onboardingChildLoginCaption;

  /// No description provided for @onboardingBundleHeading.
  ///
  /// In ja, this message translates to:
  /// **'アカウントバンドル'**
  String get onboardingBundleHeading;

  /// No description provided for @onboardingBundleReplace.
  ///
  /// In ja, this message translates to:
  /// **'この端末の SNS アカウントで置き換える'**
  String get onboardingBundleReplace;

  /// No description provided for @onboardingBundleReplaceSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{ログイン中の {count} 件を、この RASQ アカウントにまとめます}}'**
  String onboardingBundleReplaceSubtitle(int count);

  /// No description provided for @onboardingBundleKeep.
  ///
  /// In ja, this message translates to:
  /// **'置き換えない'**
  String get onboardingBundleKeep;

  /// No description provided for @onboardingBundleKeepSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'SNS アカウントはこの端末だけに残します'**
  String get onboardingBundleKeepSubtitle;

  /// No description provided for @onboardingTermsContributionNote.
  ///
  /// In ja, this message translates to:
  /// **'「アルゴリズムとコミュニティへの貢献」は、この登録には含まれません(別の任意の同意で、既定は「提供しない」です)。RASQ アカウントはいつでも削除できます。'**
  String get onboardingTermsContributionNote;

  /// No description provided for @onboardingRegister.
  ///
  /// In ja, this message translates to:
  /// **'同意して登録する'**
  String get onboardingRegister;

  /// No description provided for @onboardingSnsTitle.
  ///
  /// In ja, this message translates to:
  /// **'SNS アカウントでログイン'**
  String get onboardingSnsTitle;

  /// No description provided for @onboardingSnsDescription.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントができました。使っている SNS のアカウントでログインしてください。まだ SNS を使っていなければ、「SNS サービスを探す」から合うサーバーやリストを探せます。'**
  String get onboardingSnsDescription;

  /// service = SNS の名前(Bluesky / Misskey / mixi2 / Mastodon)
  ///
  /// In ja, this message translates to:
  /// **'{service}でログイン'**
  String onboardingSnsLoginWith(String service);

  /// No description provided for @onboardingSnsPluginLoadNote.
  ///
  /// In ja, this message translates to:
  /// **'初回ログイン前に、プラグインのロードが行われます。ネット環境の良い場所で行ってください。'**
  String get onboardingSnsPluginLoadNote;

  /// RAi の登録の案内。name = サーバーの名前
  ///
  /// In ja, this message translates to:
  /// **'{name} はいま新しい登録を受け付けていないか、招待制です。招待のリンクを持っていなければ、別のサーバーを選んでください。'**
  String onboardingSignupGuideClosed(String name);

  /// No description provided for @onboardingSignupGuideMastodonOpened.
  ///
  /// In ja, this message translates to:
  /// **'{name} の登録ページを開きました。サーバーのルールが出たら読んで、「同意する」を押してください。'**
  String onboardingSignupGuideMastodonOpened(String name);

  /// No description provided for @onboardingSignupGuideMastodonForm.
  ///
  /// In ja, this message translates to:
  /// **'表示名・ユーザー名・メールアドレス・パスワードを入れます。ユーザー名はあとから変えられないので、気に入ったものを選んでください。'**
  String get onboardingSignupGuideMastodonForm;

  /// No description provided for @onboardingSignupGuideMastodonMail.
  ///
  /// In ja, this message translates to:
  /// **'登録を押すと、確認のメールが届きます。メールのリンクを開いて、メールアドレスを確かめてください。'**
  String get onboardingSignupGuideMastodonMail;

  /// No description provided for @onboardingSignupGuideOpened.
  ///
  /// In ja, this message translates to:
  /// **'{name} のページを開きました。ページの「新規登録」を押してください。'**
  String onboardingSignupGuideOpened(String name);

  /// No description provided for @onboardingSignupGuideForm.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー名とパスワードを決めます。ユーザー名はあとから変えられないので、気に入ったものを選んでください。'**
  String get onboardingSignupGuideForm;

  /// No description provided for @onboardingSignupGuideChecks.
  ///
  /// In ja, this message translates to:
  /// **'サーバーによっては、メールアドレス・招待コード・ロボットでないことの確認を聞かれます。画面の案内のとおりに入れてください。'**
  String get onboardingSignupGuideChecks;

  /// No description provided for @onboardingSignupGuideRules.
  ///
  /// In ja, this message translates to:
  /// **'サーバーのルール(利用規約)を読んで同意します。メールの確認を求められたら、届いたメールのリンクを開いてください。'**
  String get onboardingSignupGuideRules;

  /// 最後の手順。このあとに onboardingSignupGuideThen… などの文が続けて並ぶ
  ///
  /// In ja, this message translates to:
  /// **'登録が終わったら、下の「登録できた」を押してください。RASQ からこのサーバーにログインします。'**
  String get onboardingSignupGuideDone;

  /// No description provided for @onboardingSignupGuideThenPost.
  ///
  /// In ja, this message translates to:
  /// **'ログインできたら、さっきの投稿を開きます。'**
  String get onboardingSignupGuideThenPost;

  /// No description provided for @onboardingSignupGuideThenList.
  ///
  /// In ja, this message translates to:
  /// **'ログインできたら、RASQ リスト「{name}」を開きます。'**
  String onboardingSignupGuideThenList(String name);

  /// No description provided for @onboardingSignupGuideRasqLater.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントは、あとからサイドバーの … で作れます。'**
  String get onboardingSignupGuideRasqLater;

  /// No description provided for @onboardingSignupTitleFallback.
  ///
  /// In ja, this message translates to:
  /// **'サーバーに登録'**
  String get onboardingSignupTitleFallback;

  /// No description provided for @onboardingSignupNoTarget.
  ///
  /// In ja, this message translates to:
  /// **'登録するサーバーが選ばれていません'**
  String get onboardingSignupNoTarget;

  /// No description provided for @onboardingSignupDone.
  ///
  /// In ja, this message translates to:
  /// **'登録できた(ログインへ)'**
  String get onboardingSignupDone;

  /// No description provided for @onboardingSignupTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name} に登録'**
  String onboardingSignupTitle(String name);

  /// No description provided for @onboardingSignupGuideHeading.
  ///
  /// In ja, this message translates to:
  /// **'RAi の案内'**
  String get onboardingSignupGuideHeading;

  /// No description provided for @onboardingSignupGuidePrev.
  ///
  /// In ja, this message translates to:
  /// **'前へ'**
  String get onboardingSignupGuidePrev;

  /// No description provided for @onboardingSignupNoWebView.
  ///
  /// In ja, this message translates to:
  /// **'この端末では、アプリの中で登録ページを開けません。ブラウザで開いて登録し、終わったらこの画面に戻ってください。'**
  String get onboardingSignupNoWebView;

  /// No description provided for @onboardingSignupOpenBrowser.
  ///
  /// In ja, this message translates to:
  /// **'ブラウザで登録ページを開く'**
  String get onboardingSignupOpenBrowser;

  /// account = ログインしたアカウント(handle@instance)
  ///
  /// In ja, this message translates to:
  /// **'{account} では、さっきの投稿を見つけられませんでした'**
  String onboardingSignupPostNotFound(String account);

  /// No description provided for @onboardingEntryCreateNew.
  ///
  /// In ja, this message translates to:
  /// **'新しく RASQ アカウントを作成'**
  String get onboardingEntryCreateNew;

  /// No description provided for @onboardingEntryCreate.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを作成'**
  String get onboardingEntryCreate;

  /// No description provided for @onboardingEntryLogin.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログイン'**
  String get onboardingEntryLogin;

  /// No description provided for @onboardingEntryDiscover.
  ///
  /// In ja, this message translates to:
  /// **'SNS サービスを探す(画像・人・RAi から)'**
  String get onboardingEntryDiscover;

  /// name = RASQ アカウントの表示名
  ///
  /// In ja, this message translates to:
  /// **'{name}で続ける'**
  String onboardingEntryResume(String name);

  /// name = 表示名(無ければユーザー名)、handle = ユーザー名
  ///
  /// In ja, this message translates to:
  /// **'{name}(@{handle})で続ける'**
  String onboardingEntryResumeWithHandle(String name, String handle);

  /// 表示名もユーザー名も無いときの名前
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント'**
  String get onboardingEntryResumeFallbackName;

  /// No description provided for @onboardingEntrySnsOnly.
  ///
  /// In ja, this message translates to:
  /// **'SNS アカウントだけで使う'**
  String get onboardingEntrySnsOnly;

  /// No description provided for @onboardingEntrySkip.
  ///
  /// In ja, this message translates to:
  /// **'スキップしてこの端末だけで使う'**
  String get onboardingEntrySkip;

  /// No description provided for @onboardingEntryHaveAccount.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを持っている'**
  String get onboardingEntryHaveAccount;

  /// No description provided for @onboardingEntryLoginQuestion.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインしますか?'**
  String get onboardingEntryLoginQuestion;

  /// No description provided for @onboardingEntryCreateQuestion.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを作成しますか?'**
  String get onboardingEntryCreateQuestion;

  /// No description provided for @onboardingEntryLoginBody.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントに入ると、束ねた SNS アカウント・導入したプラグイン・設定が、この端末に戻ります。'**
  String get onboardingEntryLoginBody;

  /// No description provided for @onboardingEntryCreateBody.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントは、ログインした SNS アカウントをひとつに束ねる「あなた」の入れ物です。作成すると、導入したプラグイン・設定・アカウントの束ね方が RASQ Central に保存され、別の端末からも同じ状態で使えます。'**
  String get onboardingEntryCreateBody;

  /// No description provided for @onboardingEntryWebNote.
  ///
  /// In ja, this message translates to:
  /// **'Web 版では、SNS のログイン情報を RASQ のサーバーの保管庫に預けます(サーバーの鍵で暗号化し、RASQ のサーバーは復号できます)。SNS だけで使うこともできますが、そのときはこのタブを閉じるとログインが消えます。'**
  String get onboardingEntryWebNote;

  /// No description provided for @onboardingEntrySnsOnlyNote.
  ///
  /// In ja, this message translates to:
  /// **'SNS アカウントだけで使うこともできます。その場合、導入したプラグインや設定はこの端末の中にだけ保存されます。'**
  String get onboardingEntrySnsOnlyNote;

  /// No description provided for @onboardingEntrySkipNote.
  ///
  /// In ja, this message translates to:
  /// **'スキップしても RASQ は使えます。その場合、導入したプラグインや設定はこの端末の中にだけ保存されます(あとからサイドバーの … で作成できます)。'**
  String get onboardingEntrySkipNote;

  /// No description provided for @onboardingShowcaseTitle.
  ///
  /// In ja, this message translates to:
  /// **'サーバーとリストを見てみる'**
  String get onboardingShowcaseTitle;

  /// No description provided for @onboardingShowcaseServersHint.
  ///
  /// In ja, this message translates to:
  /// **'タップすると、そのサーバーに登録できます'**
  String get onboardingShowcaseServersHint;

  /// No description provided for @onboardingShowcaseOpenServer.
  ///
  /// In ja, this message translates to:
  /// **'サーバーを開く'**
  String get onboardingShowcaseOpenServer;

  /// No description provided for @onboardingShowcaseSignupServer.
  ///
  /// In ja, this message translates to:
  /// **'このサーバーに登録'**
  String get onboardingShowcaseSignupServer;

  /// No description provided for @onboardingShowcaseListsHint.
  ///
  /// In ja, this message translates to:
  /// **'SNS をまたいだ人のリストです。タップすると、リストの人がいるサーバーに登録できます'**
  String get onboardingShowcaseListsHint;

  /// No description provided for @onboardingShowcaseListCannotSignup.
  ///
  /// In ja, this message translates to:
  /// **'このリストのサーバーには、アプリから登録できません'**
  String get onboardingShowcaseListCannotSignup;

  /// No description provided for @onboardingShowcasePickServer.
  ///
  /// In ja, this message translates to:
  /// **'どのサーバーに登録しますか?'**
  String get onboardingShowcasePickServer;

  /// kind = SNS の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'{host} ・ {kind}'**
  String onboardingShowcasePickServerSubtitle(String host, String kind);

  /// 見本の投稿の添付の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{画像 {count} 枚}}'**
  String onboardingShowcasePostImages(int count);

  /// 見本の投稿のジャンルのチップ
  ///
  /// In ja, this message translates to:
  /// **'ゲーム'**
  String get onboardingGenreGame;

  /// No description provided for @onboardingGenreAnime.
  ///
  /// In ja, this message translates to:
  /// **'アニメ・マンガ'**
  String get onboardingGenreAnime;

  /// No description provided for @onboardingGenreMusic.
  ///
  /// In ja, this message translates to:
  /// **'音楽'**
  String get onboardingGenreMusic;

  /// No description provided for @onboardingGenreArt.
  ///
  /// In ja, this message translates to:
  /// **'イラスト・創作'**
  String get onboardingGenreArt;

  /// No description provided for @onboardingGenrePhoto.
  ///
  /// In ja, this message translates to:
  /// **'写真'**
  String get onboardingGenrePhoto;

  /// No description provided for @onboardingGenreFood.
  ///
  /// In ja, this message translates to:
  /// **'食べ物'**
  String get onboardingGenreFood;

  /// No description provided for @onboardingGenreTech.
  ///
  /// In ja, this message translates to:
  /// **'IT・プログラミング'**
  String get onboardingGenreTech;

  /// No description provided for @onboardingGenreAnimal.
  ///
  /// In ja, this message translates to:
  /// **'動物・ペット'**
  String get onboardingGenreAnimal;

  /// No description provided for @onboardingGenreSports.
  ///
  /// In ja, this message translates to:
  /// **'スポーツ'**
  String get onboardingGenreSports;

  /// No description provided for @onboardingGenreTravel.
  ///
  /// In ja, this message translates to:
  /// **'旅行・おでかけ'**
  String get onboardingGenreTravel;

  /// No description provided for @onboardingGenreBooks.
  ///
  /// In ja, this message translates to:
  /// **'本・読書'**
  String get onboardingGenreBooks;

  /// No description provided for @onboardingGenreMovie.
  ///
  /// In ja, this message translates to:
  /// **'映画・ドラマ'**
  String get onboardingGenreMovie;

  /// No description provided for @onboardingGenreNature.
  ///
  /// In ja, this message translates to:
  /// **'季節・自然'**
  String get onboardingGenreNature;

  /// No description provided for @onboardingPasswordTooShort.
  ///
  /// In ja, this message translates to:
  /// **'{min} 文字以上にしてください'**
  String onboardingPasswordTooShort(int min);

  /// No description provided for @onboardingPasswordTooLong.
  ///
  /// In ja, this message translates to:
  /// **'256 文字までです'**
  String get onboardingPasswordTooLong;

  /// No description provided for @onboardingPasswordRepeated.
  ///
  /// In ja, this message translates to:
  /// **'同じ字の繰り返しは使えません'**
  String get onboardingPasswordRepeated;

  /// No description provided for @onboardingTermsOutdated.
  ///
  /// In ja, this message translates to:
  /// **'利用規約が新しくなっています。アプリを更新してから、もう一度登録してください'**
  String get onboardingTermsOutdated;

  /// No description provided for @onboardingNoServer.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーの接続先が設定されていません'**
  String get onboardingNoServer;

  /// No description provided for @onboardingHandleTaken.
  ///
  /// In ja, this message translates to:
  /// **'このユーザー名はもう使われています'**
  String get onboardingHandleTaken;

  /// No description provided for @onboardingHandleUnusable.
  ///
  /// In ja, this message translates to:
  /// **'このユーザー名は使えません({error})'**
  String onboardingHandleUnusable(String error);

  /// reason = onboardingHandleTaken / onboardingHandleUnusable の文
  ///
  /// In ja, this message translates to:
  /// **'{reason}。ユーザー名は @{handle} のままです(プロフィールの編集で変えられます)'**
  String onboardingHandleKept(String reason, String handle);

  /// No description provided for @onboardingPasswordSetFailed.
  ///
  /// In ja, this message translates to:
  /// **'アカウントは作成しましたが、パスワードを設定できませんでした({error})。設定 →「アカウントの保護」から設定してください'**
  String onboardingPasswordSetFailed(String error);

  /// No description provided for @onboardingRestored.
  ///
  /// In ja, this message translates to:
  /// **'この端末の RASQ アカウントへ戻りました'**
  String get onboardingRestored;

  /// No description provided for @onboardingNudgeTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを作りますか?'**
  String get onboardingNudgeTitle;

  /// No description provided for @onboardingNudgeMessage.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントがあると、入れたプラグインや設定・SNS のアカウントのまとまりを、ほかの端末でも使えます。Swing や RASQ リストも RASQ アカウントから使います。あとからサイドバーの … でも作れます。'**
  String get onboardingNudgeMessage;

  /// No description provided for @onboardingNudgeCreate.
  ///
  /// In ja, this message translates to:
  /// **'作る'**
  String get onboardingNudgeCreate;

  /// No description provided for @onboardingNudgeLogin.
  ///
  /// In ja, this message translates to:
  /// **'ログイン(持っている人)'**
  String get onboardingNudgeLogin;

  /// No description provided for @onboardingNudgeLater.
  ///
  /// In ja, this message translates to:
  /// **'あとで'**
  String get onboardingNudgeLater;

  /// No description provided for @onboardingNudgeCreated.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント @{handle} を作成しました'**
  String onboardingNudgeCreated(String handle);

  /// No description provided for @onboardingFeedTitle.
  ///
  /// In ja, this message translates to:
  /// **'公開 RASQ リストから'**
  String get onboardingFeedTitle;

  /// No description provided for @onboardingFeedCaption.
  ///
  /// In ja, this message translates to:
  /// **'SNS をまたいだ人のリストで、よく読まれている投稿です'**
  String get onboardingFeedCaption;

  /// No description provided for @onboardingFeedEmpty.
  ///
  /// In ja, this message translates to:
  /// **'いまは表示できる投稿がありません'**
  String get onboardingFeedEmpty;

  /// No description provided for @onboardingFeedListName.
  ///
  /// In ja, this message translates to:
  /// **'リスト「{name}」'**
  String onboardingFeedListName(String name);

  /// No description provided for @onboardingDiscoverTitle.
  ///
  /// In ja, this message translates to:
  /// **'SNS サービスを探す'**
  String get onboardingDiscoverTitle;

  /// No description provided for @onboardingDiscoverIntro.
  ///
  /// In ja, this message translates to:
  /// **'好きなものから、合いそうな SNS のサーバーと RASQ リスト(SNS をまたいだ人のリスト)を探します。'**
  String get onboardingDiscoverIntro;

  /// 探す画面の入口と、その画面の見出し
  ///
  /// In ja, this message translates to:
  /// **'好きな画像やコンテンツから探す'**
  String get onboardingDiscoverContentTitle;

  /// No description provided for @onboardingDiscoverContentSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'画像を選んで、探したい部分を囲んで'**
  String get onboardingDiscoverContentSubtitle;

  /// 探す画面の入口と、その画面の見出し
  ///
  /// In ja, this message translates to:
  /// **'有力なユーザー / インフルエンサーから探す'**
  String get onboardingDiscoverPeopleTitle;

  /// No description provided for @onboardingDiscoverPeopleSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'好きな人の名前や分野から'**
  String get onboardingDiscoverPeopleSubtitle;

  /// No description provided for @onboardingDiscoverExportTitle.
  ///
  /// In ja, this message translates to:
  /// **'外部 SNS のエクスポートデータから探す'**
  String get onboardingDiscoverExportTitle;

  /// No description provided for @onboardingDiscoverExportSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'準備中'**
  String get onboardingDiscoverExportSubtitle;

  /// 探す画面の入口・見出し・人から探すで見つからなかったときのボタン
  ///
  /// In ja, this message translates to:
  /// **'RAi に聞く'**
  String get onboardingDiscoverAskTitle;

  /// No description provided for @onboardingDiscoverAskSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'どんな SNS が合うか、話しながら探します'**
  String get onboardingDiscoverAskSubtitle;

  /// No description provided for @onboardingDiscoverRaiBlocked.
  ///
  /// In ja, this message translates to:
  /// **'保護者が RAi を止めています'**
  String get onboardingDiscoverRaiBlocked;

  /// No description provided for @onboardingDiscoverCannotLogin.
  ///
  /// In ja, this message translates to:
  /// **'{host} には、アプリからログインできません'**
  String onboardingDiscoverCannotLogin(String host);

  /// No description provided for @onboardingDiscoverCannotSignup.
  ///
  /// In ja, this message translates to:
  /// **'{host} には、アプリから登録できません'**
  String onboardingDiscoverCannotSignup(String host);

  /// No description provided for @onboardingDiscoverAddAccountBlocked.
  ///
  /// In ja, this message translates to:
  /// **'保護者が SNS アカウントの追加を止めています'**
  String get onboardingDiscoverAddAccountBlocked;

  /// No description provided for @onboardingDiscoverDummyResult.
  ///
  /// In ja, this message translates to:
  /// **'見本の結果です(サーバーの外部サービスが未設定)'**
  String get onboardingDiscoverDummyResult;

  /// No description provided for @onboardingDiscoverPeopleWebHeading.
  ///
  /// In ja, this message translates to:
  /// **'SNS の人(Web 検索)'**
  String get onboardingDiscoverPeopleWebHeading;

  /// No description provided for @onboardingDiscoverListsHeading.
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト'**
  String get onboardingDiscoverListsHeading;

  /// No description provided for @onboardingDiscoverServersHeading.
  ///
  /// In ja, this message translates to:
  /// **'サーバー'**
  String get onboardingDiscoverServersHeading;

  /// RASQ リストの候補の人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 人}}'**
  String onboardingDiscoverListMembers(int count);

  /// No description provided for @onboardingDiscoverListOwner.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} のリスト'**
  String onboardingDiscoverListOwner(String handle);

  /// hosts = サーバー名を onboardingDiscoverListSeparator でつないだもの
  ///
  /// In ja, this message translates to:
  /// **'サーバー: {hosts}'**
  String onboardingDiscoverListHosts(String hosts);

  /// サーバー名の区切り
  ///
  /// In ja, this message translates to:
  /// **'、'**
  String get onboardingDiscoverListSeparator;

  /// No description provided for @onboardingDiscoverListOpenImport.
  ///
  /// In ja, this message translates to:
  /// **'リストを開いて取り込む'**
  String get onboardingDiscoverListOpenImport;

  /// No description provided for @onboardingDiscoverListSignup.
  ///
  /// In ja, this message translates to:
  /// **'リストの人のサーバーに登録'**
  String get onboardingDiscoverListSignup;

  /// No description provided for @onboardingDiscoverLoginButton.
  ///
  /// In ja, this message translates to:
  /// **'ログイン'**
  String get onboardingDiscoverLoginButton;

  /// No description provided for @onboardingDiscoverSignupButton.
  ///
  /// In ja, this message translates to:
  /// **'登録する'**
  String get onboardingDiscoverSignupButton;

  /// No description provided for @onboardingDiscoverSearchFailed.
  ///
  /// In ja, this message translates to:
  /// **'うまく探せませんでした。時間をおいて、もう一度試してください'**
  String get onboardingDiscoverSearchFailed;

  /// No description provided for @onboardingDiscoverGlimpseStoppedSystem.
  ///
  /// In ja, this message translates to:
  /// **'画面の読み取りが止められました(端末の「共有を停止」や画面のロック)。もう一度「いつものブラウザで見て探す」から始めてください'**
  String get onboardingDiscoverGlimpseStoppedSystem;

  /// No description provided for @onboardingDiscoverGlimpseStoppedShort.
  ///
  /// In ja, this message translates to:
  /// **'配信がすぐに止まったので、読み取れませんでした。ブラウザで探したい画面を開いてから止めてください'**
  String get onboardingDiscoverGlimpseStoppedShort;

  /// No description provided for @onboardingDiscoverGlimpseStoppedTimeout.
  ///
  /// In ja, this message translates to:
  /// **'10 分たったので、画面の読み取りの準備を止めました'**
  String get onboardingDiscoverGlimpseStoppedTimeout;

  /// No description provided for @onboardingDiscoverGlimpseStoppedKilled.
  ///
  /// In ja, this message translates to:
  /// **'画面の読み取りが端末に止められました。もう一度始めてください'**
  String get onboardingDiscoverGlimpseStoppedKilled;

  /// No description provided for @onboardingDiscoverGlimpseStoppedEmpty.
  ///
  /// In ja, this message translates to:
  /// **'画面を読み取れませんでした(写しが取れませんでした)'**
  String get onboardingDiscoverGlimpseStoppedEmpty;

  /// No description provided for @onboardingDiscoverGlimpseFailed.
  ///
  /// In ja, this message translates to:
  /// **'画面を読み取れませんでした'**
  String get onboardingDiscoverGlimpseFailed;

  /// No description provided for @onboardingDiscoverGlimpseBroadcastDenied.
  ///
  /// In ja, this message translates to:
  /// **'画面の配信が始まりませんでした。読み取るには、もう一度押して「ブロードキャストを開始」を選んでください(読み取るのは配信を止める直前の 3 秒だけです)'**
  String get onboardingDiscoverGlimpseBroadcastDenied;

  /// No description provided for @onboardingDiscoverGlimpseDenied.
  ///
  /// In ja, this message translates to:
  /// **'画面の読み取りが許可されませんでした。読み取るには、もう一度押して「開始」を選んでください(読み取るのはボタンを押したあとの 3 秒だけです)'**
  String get onboardingDiscoverGlimpseDenied;

  /// No description provided for @onboardingDiscoverGlimpseNotificationsDenied.
  ///
  /// In ja, this message translates to:
  /// **'通知を出せませんでした。読み取りのボタンは通知に出るので、端末の設定で RASQ の通知を許可してください'**
  String get onboardingDiscoverGlimpseNotificationsDenied;

  /// No description provided for @onboardingDiscoverGlimpseUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'この端末では画面を読み取れません。画像を選ぶか、アプリの中のブラウザで探してください'**
  String get onboardingDiscoverGlimpseUnavailable;

  /// No description provided for @onboardingDiscoverNotificationFailed.
  ///
  /// In ja, this message translates to:
  /// **'通知を出せませんでした。端末の設定で RASQ の通知を許可してください'**
  String get onboardingDiscoverNotificationFailed;

  /// No description provided for @onboardingDiscoverGlimpseResultMissing.
  ///
  /// In ja, this message translates to:
  /// **'読み取った画面が見つかりませんでした(時間がたって消えたか、もう送りました)'**
  String get onboardingDiscoverGlimpseResultMissing;

  /// No description provided for @onboardingDiscoverPicksFull.
  ///
  /// In ja, this message translates to:
  /// **'{max, plural, other{画像は {max} 枚までです。外してから追加してください}}'**
  String onboardingDiscoverPicksFull(int max);

  /// No description provided for @onboardingDiscoverPickFailed.
  ///
  /// In ja, this message translates to:
  /// **'画像を読み込めませんでした'**
  String get onboardingDiscoverPickFailed;

  /// No description provided for @onboardingDiscoverPicksOver.
  ///
  /// In ja, this message translates to:
  /// **'{over, plural, other{画像は {max} 枚までです。{over} 枚は追加しませんでした}}'**
  String onboardingDiscoverPicksOver(int over, int max);

  /// No description provided for @onboardingDiscoverPicksUnreadable.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{読み込めない画像が {count} 枚ありました}}'**
  String onboardingDiscoverPicksUnreadable(int count);

  /// 画像の追加の知らせを 2 つ並べるときの区切り
  ///
  /// In ja, this message translates to:
  /// **'。'**
  String get onboardingDiscoverNoticeSeparator;

  /// No description provided for @onboardingDiscoverPicksSkipped.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{送れる大きさ(1 枚 10 MiB・合計 24 MiB・{max} 枚まで)に収まらない画像を {count} 枚外しました}}'**
  String onboardingDiscoverPicksSkipped(int count, int max);

  /// No description provided for @onboardingDiscoverImageFormat.
  ///
  /// In ja, this message translates to:
  /// **'JPEG / PNG / WebP の画像を選んでください'**
  String get onboardingDiscoverImageFormat;

  /// No description provided for @onboardingDiscoverImageFormatSize.
  ///
  /// In ja, this message translates to:
  /// **'JPEG / PNG / WebP の 10 MiB までの画像を選んでください'**
  String get onboardingDiscoverImageFormatSize;

  /// No description provided for @onboardingDiscoverNoCentral.
  ///
  /// In ja, this message translates to:
  /// **'RASQ Central の接続先が未設定です'**
  String get onboardingDiscoverNoCentral;

  /// No description provided for @onboardingDiscoverContentIntro.
  ///
  /// In ja, this message translates to:
  /// **'好きな画像を選んで、探したい部分を囲むと、探す言葉を RAi が作ります。画像はサーバーに保存しません(探し終えたら捨てます)。'**
  String get onboardingDiscoverContentIntro;

  /// No description provided for @onboardingDiscoverPicksCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} / {max} 枚。タップで囲み直し、長押しで並べ替えます}}'**
  String onboardingDiscoverPicksCount(int count, int max);

  /// No description provided for @onboardingDiscoverPickImages.
  ///
  /// In ja, this message translates to:
  /// **'画像を選ぶ'**
  String get onboardingDiscoverPickImages;

  /// No description provided for @onboardingDiscoverAddImages.
  ///
  /// In ja, this message translates to:
  /// **'画像を追加'**
  String get onboardingDiscoverAddImages;

  /// No description provided for @onboardingDiscoverTakePhoto.
  ///
  /// In ja, this message translates to:
  /// **'写真を撮る'**
  String get onboardingDiscoverTakePhoto;

  /// No description provided for @onboardingDiscoverSearchOne.
  ///
  /// In ja, this message translates to:
  /// **'この画像で探す'**
  String get onboardingDiscoverSearchOne;

  /// No description provided for @onboardingDiscoverSearchMany.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{この {count} 枚で探す}}'**
  String onboardingDiscoverSearchMany(int count);

  /// No description provided for @onboardingDiscoverOtherWays.
  ///
  /// In ja, this message translates to:
  /// **'ほかの方法'**
  String get onboardingDiscoverOtherWays;

  /// No description provided for @onboardingDiscoverGlimpseButton.
  ///
  /// In ja, this message translates to:
  /// **'いつものブラウザで見て探す'**
  String get onboardingDiscoverGlimpseButton;

  /// ボタンと、その画面の見出し
  ///
  /// In ja, this message translates to:
  /// **'アプリの中のブラウザで探す'**
  String get onboardingDiscoverBrowseButton;

  /// No description provided for @onboardingDiscoverGlimpseCancel.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get onboardingDiscoverGlimpseCancel;

  /// No description provided for @onboardingDiscoverGlimpseCapturing.
  ///
  /// In ja, this message translates to:
  /// **'画面を読み取っています({elapsed} / {total} 秒)'**
  String onboardingDiscoverGlimpseCapturing(int elapsed, int total);

  /// No description provided for @onboardingDiscoverGlimpseDone.
  ///
  /// In ja, this message translates to:
  /// **'{frames, plural, other{画面を {seconds} 秒読み取りました({frames} コマ)}}'**
  String onboardingDiscoverGlimpseDone(int seconds, int frames);

  /// No description provided for @onboardingDiscoverGlimpseDoneDummy.
  ///
  /// In ja, this message translates to:
  /// **'{frames, plural, other{画面を {seconds} 秒読み取りました({frames} コマ)。いまは試作のため、ダミーの写しです}}'**
  String onboardingDiscoverGlimpseDoneDummy(int seconds, int frames);

  /// 選んだ画像の何枚目か(1 から)
  ///
  /// In ja, this message translates to:
  /// **'{index} 枚目'**
  String onboardingDiscoverPictureIndex(int index);

  /// 画面の読み取りの何コマ目か(1 から)
  ///
  /// In ja, this message translates to:
  /// **'{index} コマ目'**
  String onboardingDiscoverFrameIndex(int index);

  /// No description provided for @onboardingDiscoverQueryHeading.
  ///
  /// In ja, this message translates to:
  /// **'探す言葉'**
  String get onboardingDiscoverQueryHeading;

  /// No description provided for @onboardingDiscoverNoResults.
  ///
  /// In ja, this message translates to:
  /// **'合うリストやサーバーは見つかりませんでした'**
  String get onboardingDiscoverNoResults;

  /// 選んだ画像の囲み: 画像全体
  ///
  /// In ja, this message translates to:
  /// **'全体'**
  String get onboardingDiscoverPickWhole;

  /// 選んだ画像の囲み: 四角
  ///
  /// In ja, this message translates to:
  /// **'四角'**
  String get onboardingDiscoverPickRect;

  /// 選んだ画像の囲み: なぞって囲った
  ///
  /// In ja, this message translates to:
  /// **'なぞり'**
  String get onboardingDiscoverPickLasso;

  /// No description provided for @onboardingDiscoverPickRemove.
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get onboardingDiscoverPickRemove;

  /// No description provided for @onboardingDiscoverGlimpseDummyNote.
  ///
  /// In ja, this message translates to:
  /// **'いまは試作のため、画面は読まずにダミーの写しを送ります'**
  String get onboardingDiscoverGlimpseDummyNote;

  /// No description provided for @onboardingDiscoverCaptureFailed.
  ///
  /// In ja, this message translates to:
  /// **'この画面を読み取れませんでした'**
  String get onboardingDiscoverCaptureFailed;

  /// No description provided for @onboardingDiscoverBrowseAddressHint.
  ///
  /// In ja, this message translates to:
  /// **'調べたい言葉 / URL'**
  String get onboardingDiscoverBrowseAddressHint;

  /// No description provided for @onboardingDiscoverBrowseCapture.
  ///
  /// In ja, this message translates to:
  /// **'この画面から探す'**
  String get onboardingDiscoverBrowseCapture;

  /// No description provided for @onboardingDiscoverManualIntro.
  ///
  /// In ja, this message translates to:
  /// **'この端末では、アプリの中でブラウザを開けません。いつものブラウザで見て、ページの URL と気になった文を貼り付けてください。'**
  String get onboardingDiscoverManualIntro;

  /// No description provided for @onboardingDiscoverManualOpenBrowser.
  ///
  /// In ja, this message translates to:
  /// **'ブラウザを開く'**
  String get onboardingDiscoverManualOpenBrowser;

  /// No description provided for @onboardingDiscoverManualUrl.
  ///
  /// In ja, this message translates to:
  /// **'ページの URL'**
  String get onboardingDiscoverManualUrl;

  /// No description provided for @onboardingDiscoverManualText.
  ///
  /// In ja, this message translates to:
  /// **'気になった文(任意)'**
  String get onboardingDiscoverManualText;

  /// No description provided for @onboardingDiscoverManualSubmit.
  ///
  /// In ja, this message translates to:
  /// **'この内容で探す'**
  String get onboardingDiscoverManualSubmit;

  /// No description provided for @onboardingDiscoverPeopleIntro.
  ///
  /// In ja, this message translates to:
  /// **'好きな人の名前や、気になる分野を入れてください。まず公開の RASQ リストの中から探します。'**
  String get onboardingDiscoverPeopleIntro;

  /// No description provided for @onboardingDiscoverPeopleQueryLabel.
  ///
  /// In ja, this message translates to:
  /// **'人の名前 / 分野'**
  String get onboardingDiscoverPeopleQueryLabel;

  /// No description provided for @onboardingDiscoverPeopleQueryHint.
  ///
  /// In ja, this message translates to:
  /// **'例: 鉄道写真、イラストレーター'**
  String get onboardingDiscoverPeopleQueryHint;

  /// No description provided for @onboardingDiscoverPeopleSearch.
  ///
  /// In ja, this message translates to:
  /// **'探す'**
  String get onboardingDiscoverPeopleSearch;

  /// No description provided for @onboardingDiscoverPeopleNotFound.
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストでは見つかりませんでした'**
  String get onboardingDiscoverPeopleNotFound;

  /// No description provided for @onboardingDiscoverPeopleNotFoundHint.
  ///
  /// In ja, this message translates to:
  /// **'好きな画像やページから探すか、RAi に聞いてみてください。'**
  String get onboardingDiscoverPeopleNotFoundHint;

  /// No description provided for @onboardingDiscoverPeopleTryContent.
  ///
  /// In ja, this message translates to:
  /// **'画像やコンテンツから探す'**
  String get onboardingDiscoverPeopleTryContent;

  /// No description provided for @onboardingDiscoverPeopleBrave.
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストに無かったので、Web 検索から見つけた候補です'**
  String get onboardingDiscoverPeopleBrave;

  /// No description provided for @onboardingDiscoverPersonOpenProfile.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールをブラウザで開く'**
  String get onboardingDiscoverPersonOpenProfile;

  /// No description provided for @onboardingDiscoverPersonLists.
  ///
  /// In ja, this message translates to:
  /// **'この人が入っている RASQ リスト'**
  String get onboardingDiscoverPersonLists;

  /// No description provided for @onboardingDiscoverAskFailed.
  ///
  /// In ja, this message translates to:
  /// **'うまく答えられませんでした。時間をおいて、もう一度聞いてください'**
  String get onboardingDiscoverAskFailed;

  /// No description provided for @onboardingDiscoverAskEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'合う SNS、一緒に探します！'**
  String get onboardingDiscoverAskEmptyTitle;

  /// No description provided for @onboardingDiscoverAskEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'好きなこと・見たいもの・どんな人とつながりたいかを教えてください。合いそうな SNS のサーバーと RASQ リストを探します。'**
  String get onboardingDiscoverAskEmptyBody;

  /// No description provided for @onboardingDiscoverAskEmptyCloud.
  ///
  /// In ja, this message translates to:
  /// **'会話は RASQ のサーバーの RAi(クラウド)に送ります。'**
  String get onboardingDiscoverAskEmptyCloud;

  /// No description provided for @onboardingDiscoverAskModelLabel.
  ///
  /// In ja, this message translates to:
  /// **'クラウド版 RAi'**
  String get onboardingDiscoverAskModelLabel;

  /// No description provided for @onboardingDiscoverAskHint.
  ///
  /// In ja, this message translates to:
  /// **'どんなことが好きですか?'**
  String get onboardingDiscoverAskHint;

  /// No description provided for @onboardingDiscoverEditorTitle.
  ///
  /// In ja, this message translates to:
  /// **'囲って検索'**
  String get onboardingDiscoverEditorTitle;

  /// step = 「1 / 3」のような何枚目か
  ///
  /// In ja, this message translates to:
  /// **'囲って検索({step})'**
  String onboardingDiscoverEditorTitleStep(String step);

  /// No description provided for @onboardingDiscoverEditorHint.
  ///
  /// In ja, this message translates to:
  /// **'探したい部分を囲んでください。囲まずに決定すると、画像全体で探します。2 本の指で拡大・移動できます。'**
  String get onboardingDiscoverEditorHint;

  /// No description provided for @onboardingDiscoverEditorHintSelected.
  ///
  /// In ja, this message translates to:
  /// **'囲んだ部分だけを切り抜いて探します。描き直すと囲みを置き換えます。'**
  String get onboardingDiscoverEditorHintSelected;

  /// No description provided for @onboardingDiscoverEditorToolRect.
  ///
  /// In ja, this message translates to:
  /// **'四角'**
  String get onboardingDiscoverEditorToolRect;

  /// No description provided for @onboardingDiscoverEditorToolLasso.
  ///
  /// In ja, this message translates to:
  /// **'なぞる'**
  String get onboardingDiscoverEditorToolLasso;

  /// No description provided for @onboardingDiscoverEditorResetView.
  ///
  /// In ja, this message translates to:
  /// **'元の大きさに戻す'**
  String get onboardingDiscoverEditorResetView;

  /// No description provided for @onboardingDiscoverEditorClear.
  ///
  /// In ja, this message translates to:
  /// **'囲みを消す'**
  String get onboardingDiscoverEditorClear;

  /// No description provided for @onboardingDiscoverEditorDoneWhole.
  ///
  /// In ja, this message translates to:
  /// **'決定(画像全体)'**
  String get onboardingDiscoverEditorDoneWhole;

  /// No description provided for @onboardingDiscoverEditorDone.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get onboardingDiscoverEditorDone;

  /// No description provided for @onboardingDiscoverGlimpseArmedBroadcast.
  ///
  /// In ja, this message translates to:
  /// **'画面の配信を始めました。ブラウザで探したい画面を開いたら、画面上部の赤い表示(またはコントロールセンター)から配信を止めてください。止める直前の 3 秒だけを読み取り、RASQ に戻ると結果が出ます。'**
  String get onboardingDiscoverGlimpseArmedBroadcast;

  /// No description provided for @onboardingDiscoverGlimpseArmedNotification.
  ///
  /// In ja, this message translates to:
  /// **'通知を出しました。ブラウザで探したい画面を開いてから、通知をタップしてください。タップすると、その画面を 3 秒だけ読み取ります。'**
  String get onboardingDiscoverGlimpseArmedNotification;

  /// 画面の読み取りの通知の見出し
  ///
  /// In ja, this message translates to:
  /// **'RASQ で探す'**
  String get onboardingDiscoverGlimpseNotificationTitle;

  /// 画面の読み取りの通知の本文
  ///
  /// In ja, this message translates to:
  /// **'タップすると、いま見ている画面を 3 秒だけ読み取ります'**
  String get onboardingDiscoverGlimpseNotificationBody;

  /// No description provided for @onboardingDiscoverApiImageFormat.
  ///
  /// In ja, this message translates to:
  /// **'jpeg / png / webp の画像だけ送れます'**
  String get onboardingDiscoverApiImageFormat;

  /// No description provided for @onboardingDiscoverApiImageSize.
  ///
  /// In ja, this message translates to:
  /// **'画像は 10 MiB までです'**
  String get onboardingDiscoverApiImageSize;

  /// No description provided for @onboardingDiscoverApiImageAndFrames.
  ///
  /// In ja, this message translates to:
  /// **'画像とコマは一緒に送れません'**
  String get onboardingDiscoverApiImageAndFrames;

  /// No description provided for @onboardingDiscoverApiFramesCount.
  ///
  /// In ja, this message translates to:
  /// **'{max, plural, other{コマは {max} 枚までです}}'**
  String onboardingDiscoverApiFramesCount(int max);

  /// No description provided for @onboardingDiscoverApiFrameFormat.
  ///
  /// In ja, this message translates to:
  /// **'jpeg / png / webp のコマだけ送れます'**
  String get onboardingDiscoverApiFrameFormat;

  /// No description provided for @onboardingDiscoverApiFrameSize.
  ///
  /// In ja, this message translates to:
  /// **'コマは 1 枚 10 MiB までです'**
  String get onboardingDiscoverApiFrameSize;

  /// No description provided for @onboardingDiscoverApiFramesTotal.
  ///
  /// In ja, this message translates to:
  /// **'コマは合計 24 MiB までです'**
  String get onboardingDiscoverApiFramesTotal;

  /// No description provided for @onboardingDiscoverApiEmpty.
  ///
  /// In ja, this message translates to:
  /// **'画像・本文・URL のどれかが要ります'**
  String get onboardingDiscoverApiEmpty;

  /// No description provided for @onboardingTourPageSnsTitle.
  ///
  /// In ja, this message translates to:
  /// **'いくつもの SNS を、ひとつの場所で'**
  String get onboardingTourPageSnsTitle;

  /// No description provided for @onboardingTourPageSnsBody.
  ///
  /// In ja, this message translates to:
  /// **'Misskey・Mastodon・Bluesky などのアカウントを、まとめて使えます。RASQ アカウントがあれば、設定やアカウントのまとまりを、ほかの端末でも使えます。'**
  String get onboardingTourPageSnsBody;

  /// 機能の紹介のページの絵の説明(読み上げ)
  ///
  /// In ja, this message translates to:
  /// **'Bluesky・Misskey・mixi2・Mastodon が RASQ にまとまる絵'**
  String get onboardingTourPageSnsPicture;

  /// No description provided for @onboardingTourPageTimelineTitle.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインは、ノードで組み立てる'**
  String get onboardingTourPageTimelineTitle;

  /// No description provided for @onboardingTourPageTimelineBody.
  ///
  /// In ja, this message translates to:
  /// **'ホームの TL は、ノードを並べて自分好みに組み立てられます。トレンドや Today も、ノードとして TL に置けます。'**
  String get onboardingTourPageTimelineBody;

  /// No description provided for @onboardingTourPageTimelineNote.
  ///
  /// In ja, this message translates to:
  /// **'TL の歯車から変えられます。'**
  String get onboardingTourPageTimelineNote;

  /// 機能の紹介のページの絵の説明(読み上げ)
  ///
  /// In ja, this message translates to:
  /// **'「SNS タイムライン」「トレンドを取得」「Today」のノードが縦に並んだ絵'**
  String get onboardingTourPageTimelinePicture;

  /// No description provided for @onboardingTourPageTrendTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドと Today'**
  String get onboardingTourPageTrendTitle;

  /// No description provided for @onboardingTourPageTrendBody.
  ///
  /// In ja, this message translates to:
  /// **'いま話題の言葉と投稿を、トレンドと Today で見られます。はじめは恐れ・嫌悪・怒りを 45% までに抑えているので、強い怒りや嫌悪の投稿は、おすすめ / トレンド / Today / 関連 TL で下がるか、出なくなります。'**
  String get onboardingTourPageTrendBody;

  /// No description provided for @onboardingTourPageTrendNoteSupervised.
  ///
  /// In ja, this message translates to:
  /// **'この上限はいつでも変えられます。見守り中は、保護者の設定でさらに抑えます。'**
  String get onboardingTourPageTrendNoteSupervised;

  /// No description provided for @onboardingTourPageTrendNote.
  ///
  /// In ja, this message translates to:
  /// **'この上限はいつでも変えられます。'**
  String get onboardingTourPageTrendNote;

  /// 機能の紹介のページの絵の説明(読み上げ)
  ///
  /// In ja, this message translates to:
  /// **'刺激性のレーダー'**
  String get onboardingTourPageTrendPicture;

  /// No description provided for @onboardingTourPageAstellTitle.
  ///
  /// In ja, this message translates to:
  /// **'ASTell で、声でつながる'**
  String get onboardingTourPageAstellTitle;

  /// No description provided for @onboardingTourPageAstellBody.
  ///
  /// In ja, this message translates to:
  /// **'ASTell は、声で話せるルームです。聞くだけの参加もでき、下の ASTell のタブから入れます。'**
  String get onboardingTourPageAstellBody;

  /// 機能の紹介のページの絵の説明(読み上げ)
  ///
  /// In ja, this message translates to:
  /// **'ASTell のアンテナと、話している印の波形'**
  String get onboardingTourPageAstellPicture;

  /// No description provided for @onboardingTourPageSwingTitle.
  ///
  /// In ja, this message translates to:
  /// **'Swing で、気軽に流す'**
  String get onboardingTourPageSwingTitle;

  /// No description provided for @onboardingTourPageSwingBody.
  ///
  /// In ja, this message translates to:
  /// **'Swing は、時間がたつと消える投稿です。フォロワーや RASQ リストの人に届き、1〜24 時間で消えます。'**
  String get onboardingTourPageSwingBody;

  /// No description provided for @onboardingTourPageSwingNote.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントで使えます。'**
  String get onboardingTourPageSwingNote;

  /// 機能の紹介のページの絵の説明(読み上げ)
  ///
  /// In ja, this message translates to:
  /// **'Swing の丸いアイコンが並んだ絵'**
  String get onboardingTourPageSwingPicture;

  /// No description provided for @onboardingTourPageRaiTitle.
  ///
  /// In ja, this message translates to:
  /// **'迷ったら RAi に'**
  String get onboardingTourPageRaiTitle;

  /// No description provided for @onboardingTourPageRaiBody.
  ///
  /// In ja, this message translates to:
  /// **'RAi は RASQ のアシスタントです。やりたいことを聞くと、ボタンの場所まで案内したり、代わりに操作したりします。'**
  String get onboardingTourPageRaiBody;

  /// 機能の紹介のページの絵の説明(読み上げ)
  ///
  /// In ja, this message translates to:
  /// **'RAi と吹き出し'**
  String get onboardingTourPageRaiPicture;

  /// No description provided for @onboardingTourPagePluginsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインで、広げる'**
  String get onboardingTourPagePluginsTitle;

  /// No description provided for @onboardingTourPagePluginsBody.
  ///
  /// In ja, this message translates to:
  /// **'SNS も、表示も、機能も、プラグインで足せます。プラグインストアで探して入れられます。'**
  String get onboardingTourPagePluginsBody;

  /// 機能の紹介のページの絵の説明(読み上げ)
  ///
  /// In ja, this message translates to:
  /// **'プラグインのタイルが並んだ絵'**
  String get onboardingTourPagePluginsPicture;

  /// No description provided for @onboardingTourTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ の使い方'**
  String get onboardingTourTitle;

  /// No description provided for @onboardingTourSkip.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get onboardingTourSkip;

  /// No description provided for @onboardingTourBack.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get onboardingTourBack;

  /// 読み上げ: いま何ページ目か
  ///
  /// In ja, this message translates to:
  /// **'{number} / {total} ページ'**
  String onboardingTourPageSemantics(int number, int total);

  /// No description provided for @onboardingTourStart.
  ///
  /// In ja, this message translates to:
  /// **'はじめる'**
  String get onboardingTourStart;

  /// No description provided for @onboardingTourNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get onboardingTourNext;

  /// No description provided for @onboardingTourOpenTendency.
  ///
  /// In ja, this message translates to:
  /// **'いま設定を見る'**
  String get onboardingTourOpenTendency;

  /// タイムラインのページの絵のノードの名前
  ///
  /// In ja, this message translates to:
  /// **'SNS タイムライン'**
  String get onboardingTourNodeSnsTimeline;

  /// タイムラインのページの絵のノードの名前
  ///
  /// In ja, this message translates to:
  /// **'トレンドを取得'**
  String get onboardingTourNodeTrend;

  /// RAi のページの絵の吹き出し(利用者の質問の例)
  ///
  /// In ja, this message translates to:
  /// **'TL にリストを足したい'**
  String get onboardingTourRaiBubble;

  /// No description provided for @pluginsCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get pluginsCancel;

  /// No description provided for @pluginsClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get pluginsClose;

  /// No description provided for @pluginsSwingNotPackage.
  ///
  /// In ja, this message translates to:
  /// **'Swing のプラグインは .rasqpkg か .wasm です'**
  String get pluginsSwingNotPackage;

  /// No description provided for @pluginsSwingNoRequires.
  ///
  /// In ja, this message translates to:
  /// **'Swing では、ほかのプラグインを土台にする子プラグインは配れません'**
  String get pluginsSwingNoRequires;

  /// No description provided for @pluginsSwingSingleOnly.
  ///
  /// In ja, this message translates to:
  /// **'Swing で配れるのは、プラグイン 1 つだけの入れ物です'**
  String get pluginsSwingSingleOnly;

  /// No description provided for @pluginsPageNotPage.
  ///
  /// In ja, this message translates to:
  /// **'ページ型のプラグインではありません'**
  String get pluginsPageNotPage;

  /// ids は土台のプラグインの id を「 / 」でつないだもの
  ///
  /// In ja, this message translates to:
  /// **'ほかのプラグイン({ids})を土台にしているため、Swing では配れません'**
  String pluginsPageSwingRequires(String ids);

  /// No description provided for @pluginsPageSwingChild.
  ///
  /// In ja, this message translates to:
  /// **'ほかのプラグインの入れ物に入っている子プラグインのため、Swing では配れません'**
  String get pluginsPageSwingChild;

  /// names はプラグインの名前を「 / 」でつないだもの
  ///
  /// In ja, this message translates to:
  /// **'子プラグイン({names})と一緒の入れ物のため、Swing では配れません'**
  String pluginsPageSwingSiblings(String names);

  /// No description provided for @pluginsArtifactMismatch.
  ///
  /// In ja, this message translates to:
  /// **'{pluginId}: 取り直した配布物がインストール時と違うため読み込みません(ストアで入れ直してください)'**
  String pluginsArtifactMismatch(String pluginId);

  /// No description provided for @pluginsIsSnsPlugin.
  ///
  /// In ja, this message translates to:
  /// **'{id} は SNS プラグインです(スロットには登録できません)'**
  String pluginsIsSnsPlugin(String id);

  /// plugin.manifest はプラグインの関数の名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'plugin.manifest がありません'**
  String get pluginsManifestMissing;

  /// No description provided for @pluginsManifestIdEmpty.
  ///
  /// In ja, this message translates to:
  /// **'plugin.manifest.id が空です'**
  String get pluginsManifestIdEmpty;

  /// surfaces: swing、solo はマニフェストの書き方(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'Swing で配れるのは、Swing の面(surfaces: swing、solo)のページ型だけです'**
  String get pluginsSwingSurfaceOnly;

  /// No description provided for @pluginsRasqPageSurfaceOnly.
  ///
  /// In ja, this message translates to:
  /// **'RASQ のページに置けるのは、プロフィールの面(surfaces: profile、solo)のページ型だけです'**
  String get pluginsRasqPageSurfaceOnly;

  /// No description provided for @pluginsIdMismatch.
  ///
  /// In ja, this message translates to:
  /// **'配布物の目次は {expected} なのに、wasm は {actual} を名乗っています'**
  String pluginsIdMismatch(String expected, String actual);

  /// slots はスロットの id を「, 」でつないだもの
  ///
  /// In ja, this message translates to:
  /// **'{name} を登録しました({slots})'**
  String pluginsRegistered(String name, String slots);

  /// No description provided for @pluginsRegisterFailed.
  ///
  /// In ja, this message translates to:
  /// **'登録できませんでした: {error}'**
  String pluginsRegisterFailed(String error);

  /// No description provided for @pluginsImageReceiveFailed.
  ///
  /// In ja, this message translates to:
  /// **'{name}: 画像を受け取れませんでした({error})'**
  String pluginsImageReceiveFailed(String name, String error);

  /// No description provided for @pluginsSharedNoSession.
  ///
  /// In ja, this message translates to:
  /// **'{name}: 共有セッションに入っていないため、みんなの値は変えられません'**
  String pluginsSharedNoSession(String name);

  /// No description provided for @pluginsMuteAddTitle.
  ///
  /// In ja, this message translates to:
  /// **'ミュート語に追加'**
  String get pluginsMuteAddTitle;

  /// name はプラグインの名前
  ///
  /// In ja, this message translates to:
  /// **'{name} が「{word}」をミュート語に追加しようとしています。'**
  String pluginsMuteAddMessage(String name, String word);

  /// No description provided for @pluginsMuteAddConfirm.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get pluginsMuteAddConfirm;

  /// No description provided for @pluginsMuteAdded.
  ///
  /// In ja, this message translates to:
  /// **'「{word}」をミュート語に追加しました'**
  String pluginsMuteAdded(String word);

  /// No description provided for @pluginsEffectSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'{name}: 効果映像を送れませんでした({error})'**
  String pluginsEffectSendFailed(String name, String error);

  /// No description provided for @pluginsImageScaled.
  ///
  /// In ja, this message translates to:
  /// **'{name}: 編集のため画像を小さくしました'**
  String pluginsImageScaled(String name);

  /// No description provided for @pluginsErrorReturned.
  ///
  /// In ja, this message translates to:
  /// **'プラグインがエラーを返しました'**
  String get pluginsErrorReturned;

  /// メディアの加工のジャンル(既定の 5 種)
  ///
  /// In ja, this message translates to:
  /// **'色調'**
  String get pluginsGenreTone;

  /// No description provided for @pluginsGenreProcess.
  ///
  /// In ja, this message translates to:
  /// **'加工'**
  String get pluginsGenreProcess;

  /// No description provided for @pluginsGenreTransform.
  ///
  /// In ja, this message translates to:
  /// **'変形'**
  String get pluginsGenreTransform;

  /// No description provided for @pluginsGenreAdd.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get pluginsGenreAdd;

  /// No description provided for @pluginsGenreDraw.
  ///
  /// In ja, this message translates to:
  /// **'描画'**
  String get pluginsGenreDraw;

  /// サイドロードしたプラグインの段(フル機能)
  ///
  /// In ja, this message translates to:
  /// **'フル'**
  String get pluginsTrustFull;

  /// No description provided for @pluginsTrustBundled.
  ///
  /// In ja, this message translates to:
  /// **'フル(同梱)'**
  String get pluginsTrustBundled;

  /// No description provided for @pluginsTrustRestricted.
  ///
  /// In ja, this message translates to:
  /// **'制限'**
  String get pluginsTrustRestricted;

  /// No description provided for @pluginsTrustSwing.
  ///
  /// In ja, this message translates to:
  /// **'制限(Swing)'**
  String get pluginsTrustSwing;

  /// 開発者向けの説明。rasq build はコマンド(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'自分の開発者鍵で署名した .rspkg / .rasqpkg はフル機能。rasq build が署名します'**
  String get pluginsTrustHint;

  /// 画像 / 動画の加工画面(pro_image_editor)の共通のボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get pluginsEditorCancel;

  /// No description provided for @pluginsEditorUndo.
  ///
  /// In ja, this message translates to:
  /// **'ひとつ戻す'**
  String get pluginsEditorUndo;

  /// No description provided for @pluginsEditorRedo.
  ///
  /// In ja, this message translates to:
  /// **'やり直す'**
  String get pluginsEditorRedo;

  /// No description provided for @pluginsEditorDone.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get pluginsEditorDone;

  /// No description provided for @pluginsEditorRemove.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get pluginsEditorRemove;

  /// No description provided for @pluginsEditorBack.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get pluginsEditorBack;

  /// 狭い画面で道具をまとめたボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get pluginsEditorMore;

  /// No description provided for @pluginsEditorApplying.
  ///
  /// In ja, this message translates to:
  /// **'変更を適用しています'**
  String get pluginsEditorApplying;

  /// No description provided for @pluginsEditorPreparing.
  ///
  /// In ja, this message translates to:
  /// **'エディターを準備しています'**
  String get pluginsEditorPreparing;

  /// No description provided for @pluginsEditorPleaseWait.
  ///
  /// In ja, this message translates to:
  /// **'お待ちください…'**
  String get pluginsEditorPleaseWait;

  /// No description provided for @pluginsEditorCloseWarningTitle.
  ///
  /// In ja, this message translates to:
  /// **'加工をやめますか？'**
  String get pluginsEditorCloseWarningTitle;

  /// No description provided for @pluginsEditorCloseWarningMessage.
  ///
  /// In ja, this message translates to:
  /// **'変更は保存されません。'**
  String get pluginsEditorCloseWarningMessage;

  /// No description provided for @pluginsEditorCloseWarningConfirm.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get pluginsEditorCloseWarningConfirm;

  /// No description provided for @pluginsEditorCloseWarningCancel.
  ///
  /// In ja, this message translates to:
  /// **'続ける'**
  String get pluginsEditorCloseWarningCancel;

  /// No description provided for @pluginsEditorLayerEdit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get pluginsEditorLayerEdit;

  /// No description provided for @pluginsEditorLayerRotateScale.
  ///
  /// In ja, this message translates to:
  /// **'回転と拡縮'**
  String get pluginsEditorLayerRotateScale;

  /// No description provided for @pluginsEditorPaint.
  ///
  /// In ja, this message translates to:
  /// **'ペイント'**
  String get pluginsEditorPaint;

  /// No description provided for @pluginsEditorZoom.
  ///
  /// In ja, this message translates to:
  /// **'ズーム'**
  String get pluginsEditorZoom;

  /// No description provided for @pluginsEditorFreehand.
  ///
  /// In ja, this message translates to:
  /// **'フリーハンド'**
  String get pluginsEditorFreehand;

  /// No description provided for @pluginsEditorArrow.
  ///
  /// In ja, this message translates to:
  /// **'矢印'**
  String get pluginsEditorArrow;

  /// No description provided for @pluginsEditorLine.
  ///
  /// In ja, this message translates to:
  /// **'直線'**
  String get pluginsEditorLine;

  /// No description provided for @pluginsEditorRectangle.
  ///
  /// In ja, this message translates to:
  /// **'四角'**
  String get pluginsEditorRectangle;

  /// No description provided for @pluginsEditorCircle.
  ///
  /// In ja, this message translates to:
  /// **'丸'**
  String get pluginsEditorCircle;

  /// No description provided for @pluginsEditorDashLine.
  ///
  /// In ja, this message translates to:
  /// **'点線'**
  String get pluginsEditorDashLine;

  /// No description provided for @pluginsEditorBlur.
  ///
  /// In ja, this message translates to:
  /// **'ぼかし'**
  String get pluginsEditorBlur;

  /// No description provided for @pluginsEditorPixelate.
  ///
  /// In ja, this message translates to:
  /// **'モザイク'**
  String get pluginsEditorPixelate;

  /// No description provided for @pluginsEditorLineWidth.
  ///
  /// In ja, this message translates to:
  /// **'線の太さ'**
  String get pluginsEditorLineWidth;

  /// No description provided for @pluginsEditorEraser.
  ///
  /// In ja, this message translates to:
  /// **'消しゴム'**
  String get pluginsEditorEraser;

  /// No description provided for @pluginsEditorFill.
  ///
  /// In ja, this message translates to:
  /// **'塗り'**
  String get pluginsEditorFill;

  /// No description provided for @pluginsEditorOpacity.
  ///
  /// In ja, this message translates to:
  /// **'不透明度'**
  String get pluginsEditorOpacity;

  /// No description provided for @pluginsEditorColor.
  ///
  /// In ja, this message translates to:
  /// **'色'**
  String get pluginsEditorColor;

  /// No description provided for @pluginsEditorTextHint.
  ///
  /// In ja, this message translates to:
  /// **'テキストを入力'**
  String get pluginsEditorTextHint;

  /// No description provided for @pluginsEditorText.
  ///
  /// In ja, this message translates to:
  /// **'テキスト'**
  String get pluginsEditorText;

  /// No description provided for @pluginsEditorTextAlign.
  ///
  /// In ja, this message translates to:
  /// **'揃え'**
  String get pluginsEditorTextAlign;

  /// No description provided for @pluginsEditorFontScale.
  ///
  /// In ja, this message translates to:
  /// **'文字の大きさ'**
  String get pluginsEditorFontScale;

  /// No description provided for @pluginsEditorTextBackground.
  ///
  /// In ja, this message translates to:
  /// **'背景'**
  String get pluginsEditorTextBackground;

  /// No description provided for @pluginsEditorCropRotate.
  ///
  /// In ja, this message translates to:
  /// **'クロップ / 回転'**
  String get pluginsEditorCropRotate;

  /// No description provided for @pluginsEditorRotate.
  ///
  /// In ja, this message translates to:
  /// **'回転'**
  String get pluginsEditorRotate;

  /// No description provided for @pluginsEditorFlip.
  ///
  /// In ja, this message translates to:
  /// **'反転'**
  String get pluginsEditorFlip;

  /// No description provided for @pluginsEditorTilt.
  ///
  /// In ja, this message translates to:
  /// **'傾き'**
  String get pluginsEditorTilt;

  /// No description provided for @pluginsEditorTiltHorizontal.
  ///
  /// In ja, this message translates to:
  /// **'水平'**
  String get pluginsEditorTiltHorizontal;

  /// No description provided for @pluginsEditorTiltVertical.
  ///
  /// In ja, this message translates to:
  /// **'垂直'**
  String get pluginsEditorTiltVertical;

  /// No description provided for @pluginsEditorRatio.
  ///
  /// In ja, this message translates to:
  /// **'比率'**
  String get pluginsEditorRatio;

  /// No description provided for @pluginsEditorReset.
  ///
  /// In ja, this message translates to:
  /// **'リセット'**
  String get pluginsEditorReset;

  /// No description provided for @pluginsEditorTune.
  ///
  /// In ja, this message translates to:
  /// **'調整'**
  String get pluginsEditorTune;

  /// No description provided for @pluginsEditorBrightness.
  ///
  /// In ja, this message translates to:
  /// **'明るさ'**
  String get pluginsEditorBrightness;

  /// No description provided for @pluginsEditorContrast.
  ///
  /// In ja, this message translates to:
  /// **'コントラスト'**
  String get pluginsEditorContrast;

  /// No description provided for @pluginsEditorSaturation.
  ///
  /// In ja, this message translates to:
  /// **'彩度'**
  String get pluginsEditorSaturation;

  /// No description provided for @pluginsEditorExposure.
  ///
  /// In ja, this message translates to:
  /// **'露出'**
  String get pluginsEditorExposure;

  /// No description provided for @pluginsEditorHue.
  ///
  /// In ja, this message translates to:
  /// **'色相'**
  String get pluginsEditorHue;

  /// No description provided for @pluginsEditorTemperature.
  ///
  /// In ja, this message translates to:
  /// **'色温度'**
  String get pluginsEditorTemperature;

  /// No description provided for @pluginsEditorFade.
  ///
  /// In ja, this message translates to:
  /// **'フェード'**
  String get pluginsEditorFade;

  /// No description provided for @pluginsEditorTint.
  ///
  /// In ja, this message translates to:
  /// **'ティント'**
  String get pluginsEditorTint;

  /// No description provided for @pluginsEditorFilter.
  ///
  /// In ja, this message translates to:
  /// **'フィルター'**
  String get pluginsEditorFilter;

  /// No description provided for @pluginsEditorSticker.
  ///
  /// In ja, this message translates to:
  /// **'ステッカー'**
  String get pluginsEditorSticker;

  /// No description provided for @pluginsEditorEmoji.
  ///
  /// In ja, this message translates to:
  /// **'絵文字'**
  String get pluginsEditorEmoji;

  /// No description provided for @pluginsEditorEmojiSearch.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get pluginsEditorEmojiSearch;

  /// No description provided for @pluginsEditorEmojiRecent.
  ///
  /// In ja, this message translates to:
  /// **'最近'**
  String get pluginsEditorEmojiRecent;

  /// No description provided for @pluginsEditorEmojiSmileys.
  ///
  /// In ja, this message translates to:
  /// **'顔と人'**
  String get pluginsEditorEmojiSmileys;

  /// No description provided for @pluginsEditorEmojiAnimals.
  ///
  /// In ja, this message translates to:
  /// **'動物と自然'**
  String get pluginsEditorEmojiAnimals;

  /// No description provided for @pluginsEditorEmojiFood.
  ///
  /// In ja, this message translates to:
  /// **'食べ物'**
  String get pluginsEditorEmojiFood;

  /// No description provided for @pluginsEditorEmojiActivities.
  ///
  /// In ja, this message translates to:
  /// **'アクティビティ'**
  String get pluginsEditorEmojiActivities;

  /// No description provided for @pluginsEditorEmojiTravel.
  ///
  /// In ja, this message translates to:
  /// **'旅行と場所'**
  String get pluginsEditorEmojiTravel;

  /// No description provided for @pluginsEditorEmojiObjects.
  ///
  /// In ja, this message translates to:
  /// **'もの'**
  String get pluginsEditorEmojiObjects;

  /// No description provided for @pluginsEditorEmojiSymbols.
  ///
  /// In ja, this message translates to:
  /// **'記号'**
  String get pluginsEditorEmojiSymbols;

  /// No description provided for @pluginsEditorEmojiFlags.
  ///
  /// In ja, this message translates to:
  /// **'旗'**
  String get pluginsEditorEmojiFlags;

  /// No description provided for @pluginsMediaCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get pluginsMediaCancel;

  /// No description provided for @pluginsMediaClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get pluginsMediaClose;

  /// No description provided for @pluginsMediaApply.
  ///
  /// In ja, this message translates to:
  /// **'適用'**
  String get pluginsMediaApply;

  /// 落書きの紙から SVG を渡したプラグインが SVG を返さなかった。name はプラグインの名前
  ///
  /// In ja, this message translates to:
  /// **'{name} が SVG を返さなかったので、使いませんでした'**
  String pluginsMediaNotSvg(String name);

  /// 落書きの紙(SVG の加工)でプラグインのボタンを押したが、今の絵を受け取れなかった
  ///
  /// In ja, this message translates to:
  /// **'いまは使えません(紙の「完了」が見つかりません)'**
  String get pluginsMediaPaperDoneMissing;

  /// No description provided for @pluginsMediaBarEdit.
  ///
  /// In ja, this message translates to:
  /// **'バーの編集'**
  String get pluginsMediaBarEdit;

  /// No description provided for @pluginsMediaAudioUnsupported.
  ///
  /// In ja, this message translates to:
  /// **'この端末では音声を動画にできません(Android / iOS / macOS だけ)。音声のまま添付できます'**
  String get pluginsMediaAudioUnsupported;

  /// No description provided for @pluginsMediaOpenAudioFailed.
  ///
  /// In ja, this message translates to:
  /// **'音声を開けませんでした: {error}'**
  String pluginsMediaOpenAudioFailed(String error);

  /// No description provided for @pluginsMediaOpenVideoFailed.
  ///
  /// In ja, this message translates to:
  /// **'動画を開けませんでした: {error}'**
  String pluginsMediaOpenVideoFailed(String error);

  /// No description provided for @pluginsMediaReexportFailed.
  ///
  /// In ja, this message translates to:
  /// **'動画を書き出し直せませんでした: {error}'**
  String pluginsMediaReexportFailed(String error);

  /// No description provided for @pluginsMediaCropWithMovingObject.
  ///
  /// In ja, this message translates to:
  /// **'クロップ / 回転と、動くオブジェクトは一緒に使えません。静止画で入れました'**
  String get pluginsMediaCropWithMovingObject;

  /// No description provided for @pluginsMediaExportFailed.
  ///
  /// In ja, this message translates to:
  /// **'動画を書き出せませんでした: {error}'**
  String pluginsMediaExportFailed(String error);

  /// No description provided for @pluginsMediaOverlayFailed.
  ///
  /// In ja, this message translates to:
  /// **'動くオブジェクトを重ねられなかったので、静止画で入れました: {error}'**
  String pluginsMediaOverlayFailed(String error);

  /// label はプラグインのボタンの名前
  ///
  /// In ja, this message translates to:
  /// **'{label}: フィルターを受け取れませんでした'**
  String pluginsMediaFilterNotReceived(String label);

  /// label はプラグインのボタンの名前
  ///
  /// In ja, this message translates to:
  /// **'{label}: 描画が多すぎるので {count, plural, other{{count} 個}}を省きました'**
  String pluginsMediaFilterDropped(String label, int count);

  /// names はフィルターの名前を「 / 」でつないだもの
  ///
  /// In ja, this message translates to:
  /// **'適用できなかったフィルター: {names}(この加工は入っていません)'**
  String pluginsMediaFiltersFailed(String names);

  /// No description provided for @pluginsMediaCropWithMovingPost.
  ///
  /// In ja, this message translates to:
  /// **'クロップ / 回転と、動く投稿は一緒に使えません。投稿は静止画で入れました'**
  String get pluginsMediaCropWithMovingPost;

  /// No description provided for @pluginsMediaVideoImageUnreadable.
  ///
  /// In ja, this message translates to:
  /// **'動画にできなかったので、静止画で入れました(画像を読めませんでした)'**
  String get pluginsMediaVideoImageUnreadable;

  /// No description provided for @pluginsMediaVideoPostFailed.
  ///
  /// In ja, this message translates to:
  /// **'動画にできなかったので、投稿は静止画で入れました: {error}'**
  String pluginsMediaVideoPostFailed(String error);

  /// No description provided for @pluginsMediaToVideoTitle.
  ///
  /// In ja, this message translates to:
  /// **'動画に変換しますか?'**
  String get pluginsMediaToVideoTitle;

  /// note は置くもの(動く投稿 / 動画)の説明の 1 行。「動画にする」「静止画で貼る」は pluginsMediaToVideoConfirm / pluginsMediaToVideoStill と同じ語
  ///
  /// In ja, this message translates to:
  /// **'{note}\n「動画にする」と、置いた場所で動く動画として書き出します。「静止画で貼る」は今の画像だけを貼ります。'**
  String pluginsMediaToVideoMessage(String note);

  /// No description provided for @pluginsMediaToVideoConfirm.
  ///
  /// In ja, this message translates to:
  /// **'動画にする'**
  String get pluginsMediaToVideoConfirm;

  /// No description provided for @pluginsMediaToVideoStill.
  ///
  /// In ja, this message translates to:
  /// **'静止画で貼る'**
  String get pluginsMediaToVideoStill;

  /// No description provided for @pluginsMediaImageUnreadable.
  ///
  /// In ja, this message translates to:
  /// **'画像を読めませんでした'**
  String get pluginsMediaImageUnreadable;

  /// No description provided for @pluginsMediaExportOnDone.
  ///
  /// In ja, this message translates to:
  /// **'完了すると、動画として書き出します'**
  String get pluginsMediaExportOnDone;

  /// 加工画面に置いた投稿のオブジェクトの編集の見出し
  ///
  /// In ja, this message translates to:
  /// **'ノート'**
  String get pluginsMediaObjectNote;

  /// No description provided for @pluginsMediaObjectVideo.
  ///
  /// In ja, this message translates to:
  /// **'動画'**
  String get pluginsMediaObjectVideo;

  /// No description provided for @pluginsMediaObjectImage.
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get pluginsMediaObjectImage;

  /// No description provided for @pluginsMediaAddImage.
  ///
  /// In ja, this message translates to:
  /// **'画像を追加'**
  String get pluginsMediaAddImage;

  /// No description provided for @pluginsMediaAddVideo.
  ///
  /// In ja, this message translates to:
  /// **'動画を追加'**
  String get pluginsMediaAddVideo;

  /// No description provided for @pluginsMediaVideoLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'動画を読み込めませんでした'**
  String get pluginsMediaVideoLoadFailed;

  /// 開発者モードの詳しい説明。ext は拡張子、bytes はファイルの大きさ
  ///
  /// In ja, this message translates to:
  /// **'動画(.{ext}、{bytes} バイト)の最初のコマを取れませんでした: {error}'**
  String pluginsMediaVideoLoadFailedDetail(String ext, int bytes, String error);

  /// No description provided for @pluginsMediaFirstFrameFailed.
  ///
  /// In ja, this message translates to:
  /// **'動画の最初のコマを取れませんでした'**
  String get pluginsMediaFirstFrameFailed;

  /// No description provided for @pluginsMediaVideoAsObject.
  ///
  /// In ja, this message translates to:
  /// **'動画をオブジェクトとして置きます。'**
  String get pluginsMediaVideoAsObject;

  /// No description provided for @pluginsMediaAddFailed.
  ///
  /// In ja, this message translates to:
  /// **'メディアを追加できませんでした: {error}'**
  String pluginsMediaAddFailed(String error);

  /// No description provided for @pluginsMediaAudioConverting.
  ///
  /// In ja, this message translates to:
  /// **'音声を動画に変換しています…'**
  String get pluginsMediaAudioConverting;

  /// name はプラグインの名前
  ///
  /// In ja, this message translates to:
  /// **'{name} はここでは編集できません(プラグインのパネルで操作してください)'**
  String pluginsMediaPanelNotEditable(String name);

  /// No description provided for @pluginsMediaSnapDragUnset.
  ///
  /// In ja, this message translates to:
  /// **'この上にドラッグ(解除)'**
  String get pluginsMediaSnapDragUnset;

  /// No description provided for @pluginsMediaSnapDragSet.
  ///
  /// In ja, this message translates to:
  /// **'この上にドラッグ(合わせる先にする)'**
  String get pluginsMediaSnapDragSet;

  /// No description provided for @pluginsMediaSnapPick.
  ///
  /// In ja, this message translates to:
  /// **'合わせる先を選ぶ…'**
  String get pluginsMediaSnapPick;

  /// No description provided for @pluginsMediaSnapClearAll.
  ///
  /// In ja, this message translates to:
  /// **'合わせる先をすべて解除'**
  String get pluginsMediaSnapClearAll;

  /// No description provided for @pluginsMediaSnapTitle.
  ///
  /// In ja, this message translates to:
  /// **'合わせる先'**
  String get pluginsMediaSnapTitle;

  /// No description provided for @pluginsMediaSnapEmpty.
  ///
  /// In ja, this message translates to:
  /// **'名前の付いた枠がありません'**
  String get pluginsMediaSnapEmpty;

  /// 合わせる先の枠の大きさ(画素)
  ///
  /// In ja, this message translates to:
  /// **'{width} × {height}'**
  String pluginsMediaSnapSize(int width, int height);

  /// 合わせる先の枠の大きさ(画素)と傾き(度)
  ///
  /// In ja, this message translates to:
  /// **'{width} × {height}、{angle}°'**
  String pluginsMediaSnapSizeAngle(int width, int height, int angle);

  /// No description provided for @pluginsMediaPanelNoResult.
  ///
  /// In ja, this message translates to:
  /// **'適用できませんでした(プラグインが結果を返しませんでした)'**
  String get pluginsMediaPanelNoResult;

  /// No description provided for @pluginsMediaPanelNoEdits.
  ///
  /// In ja, this message translates to:
  /// **'このプラグインに編集はありません'**
  String get pluginsMediaPanelNoEdits;

  /// No description provided for @pluginsMediaObjectEditSemantics.
  ///
  /// In ja, this message translates to:
  /// **'{title} の編集'**
  String pluginsMediaObjectEditSemantics(String title);

  /// No description provided for @pluginsMediaObjectLoop.
  ///
  /// In ja, this message translates to:
  /// **'繰り返し再生'**
  String get pluginsMediaObjectLoop;

  /// No description provided for @pluginsMediaObjectLoopSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'オフ = 終わったら最後のコマで止まる'**
  String get pluginsMediaObjectLoopSubtitle;

  /// No description provided for @pluginsMediaObjectSpeed.
  ///
  /// In ja, this message translates to:
  /// **'再生の速さ'**
  String get pluginsMediaObjectSpeed;

  /// No description provided for @pluginsMediaObjectVolume.
  ///
  /// In ja, this message translates to:
  /// **'音'**
  String get pluginsMediaObjectVolume;

  /// No description provided for @pluginsMediaObjectMuted.
  ///
  /// In ja, this message translates to:
  /// **'消音'**
  String get pluginsMediaObjectMuted;

  /// No description provided for @pluginsMediaObjectOpacity.
  ///
  /// In ja, this message translates to:
  /// **'不透明度'**
  String get pluginsMediaObjectOpacity;

  /// No description provided for @pluginsMediaObjectRemove.
  ///
  /// In ja, this message translates to:
  /// **'このオブジェクトを削除'**
  String get pluginsMediaObjectRemove;

  /// No description provided for @pluginsMediaFilterAdjustSemantics.
  ///
  /// In ja, this message translates to:
  /// **'{title} の調整'**
  String pluginsMediaFilterAdjustSemantics(String title);

  /// No description provided for @pluginsMediaFilterObjectHint.
  ///
  /// In ja, this message translates to:
  /// **'絵の上で、ドラッグで移動、つまんで拡縮 / 回転できます。'**
  String get pluginsMediaFilterObjectHint;

  /// No description provided for @pluginsMediaFilterRemove.
  ///
  /// In ja, this message translates to:
  /// **'このフィルターを外す'**
  String get pluginsMediaFilterRemove;

  /// No description provided for @pluginsMediaStickerEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ステッカーがありません。ストアで入れると、ここに並びます'**
  String get pluginsMediaStickerEmpty;

  /// 開発者モードの詳しい説明。assets はストアのカテゴリの id(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'ステッカーがありません。ストアでアセットパック(カテゴリ「assets」)を入れると、ここに並びます。'**
  String get pluginsMediaStickerEmptyDetail;

  /// No description provided for @pluginsMediaStickerGenerate.
  ///
  /// In ja, this message translates to:
  /// **'プラグインで作る'**
  String get pluginsMediaStickerGenerate;

  /// SVG の落書きの画面の既定の見出し
  ///
  /// In ja, this message translates to:
  /// **'落書き'**
  String get pluginsPaintTitle;

  /// No description provided for @pluginsPaintCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get pluginsPaintCancel;

  /// No description provided for @pluginsPaintDone.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get pluginsPaintDone;

  /// No description provided for @pluginsPaintCanvasSemantics.
  ///
  /// In ja, this message translates to:
  /// **'落書きの紙'**
  String get pluginsPaintCanvasSemantics;

  /// No description provided for @pluginsPaintFillLeak.
  ///
  /// In ja, this message translates to:
  /// **'線で閉じた形の中をタップしてください'**
  String get pluginsPaintFillLeak;

  /// No description provided for @pluginsPaintFillOnLine.
  ///
  /// In ja, this message translates to:
  /// **'線の内側をタップしてください'**
  String get pluginsPaintFillOnLine;

  /// No description provided for @pluginsPaintFillEmpty.
  ///
  /// In ja, this message translates to:
  /// **'塗れる形がありませんでした'**
  String get pluginsPaintFillEmpty;

  /// No description provided for @pluginsPaintToolPen.
  ///
  /// In ja, this message translates to:
  /// **'ペン'**
  String get pluginsPaintToolPen;

  /// No description provided for @pluginsPaintToolEraser.
  ///
  /// In ja, this message translates to:
  /// **'消しゴム'**
  String get pluginsPaintToolEraser;

  /// No description provided for @pluginsPaintToolLasso.
  ///
  /// In ja, this message translates to:
  /// **'投げ輪'**
  String get pluginsPaintToolLasso;

  /// No description provided for @pluginsPaintToolFill.
  ///
  /// In ja, this message translates to:
  /// **'塗る'**
  String get pluginsPaintToolFill;

  /// No description provided for @pluginsPaintUndo.
  ///
  /// In ja, this message translates to:
  /// **'取り消し'**
  String get pluginsPaintUndo;

  /// No description provided for @pluginsPaintRedo.
  ///
  /// In ja, this message translates to:
  /// **'やり直し'**
  String get pluginsPaintRedo;

  /// No description provided for @pluginsPaintClear.
  ///
  /// In ja, this message translates to:
  /// **'全部消す'**
  String get pluginsPaintClear;

  /// No description provided for @pluginsPaintStabilizer.
  ///
  /// In ja, this message translates to:
  /// **'手ぶれ補正'**
  String get pluginsPaintStabilizer;

  /// 手ぶれ補正のスライダーが 0 のときの短い表示(1 文字程度)
  ///
  /// In ja, this message translates to:
  /// **'切'**
  String get pluginsPaintStabilizerOff;

  /// No description provided for @pluginsPaintEraserCut.
  ///
  /// In ja, this message translates to:
  /// **'切る'**
  String get pluginsPaintEraserCut;

  /// No description provided for @pluginsPaintEraserWhole.
  ///
  /// In ja, this message translates to:
  /// **'線ごと'**
  String get pluginsPaintEraserWhole;

  /// No description provided for @pluginsPaintLassoHint.
  ///
  /// In ja, this message translates to:
  /// **'囲んで選ぶ(線の半分以上が入ったもの)'**
  String get pluginsPaintLassoHint;

  /// No description provided for @pluginsPaintSelectionDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get pluginsPaintSelectionDelete;

  /// No description provided for @pluginsPaintSelectionDuplicate.
  ///
  /// In ja, this message translates to:
  /// **'複製'**
  String get pluginsPaintSelectionDuplicate;

  /// No description provided for @pluginsPaintSelectionRecolor.
  ///
  /// In ja, this message translates to:
  /// **'色を変える'**
  String get pluginsPaintSelectionRecolor;

  /// No description provided for @pluginsPaintSelectionDeselect.
  ///
  /// In ja, this message translates to:
  /// **'解除'**
  String get pluginsPaintSelectionDeselect;

  /// No description provided for @pluginsPaintFillHint.
  ///
  /// In ja, this message translates to:
  /// **'線で閉じた形の中をタップすると、線の下に塗ります'**
  String get pluginsPaintFillHint;

  /// No description provided for @pluginsPaintWidthSemantics.
  ///
  /// In ja, this message translates to:
  /// **'太さ {width}'**
  String pluginsPaintWidthSemantics(String width);

  /// color は #rrggbb の色の値
  ///
  /// In ja, this message translates to:
  /// **'色 {color}'**
  String pluginsPaintColorSemantics(String color);

  /// No description provided for @pluginsPaintNibMili.
  ///
  /// In ja, this message translates to:
  /// **'ミリペン'**
  String get pluginsPaintNibMili;

  /// No description provided for @pluginsPaintNibKabura.
  ///
  /// In ja, this message translates to:
  /// **'カプラペン'**
  String get pluginsPaintNibKabura;

  /// No description provided for @pluginsPaintNibBrush.
  ///
  /// In ja, this message translates to:
  /// **'ブラシニブ'**
  String get pluginsPaintNibBrush;

  /// 投稿の詳細の返信欄の並び順(ドロップダウンの項目と、欄の帯の右の小さい字)。元の投稿との関連の強い順
  ///
  /// In ja, this message translates to:
  /// **'関連順'**
  String get postThreadSortRelevance;

  /// 返信欄の並び順: リアクションの多い順
  ///
  /// In ja, this message translates to:
  /// **'リアクション数'**
  String get postThreadSortReactions;

  /// 返信欄の並び順: 元の投稿と同じ語(人名・地名など)を多く含む順
  ///
  /// In ja, this message translates to:
  /// **'キーワード順'**
  String get postThreadSortKeyword;

  /// 返信欄の並び順: SNS が返した順のまま
  ///
  /// In ja, this message translates to:
  /// **'デフォルト'**
  String get postThreadSortDefault;

  /// 返信欄の帯を長押しして出す、欄の切り替えの項目。投稿をリノートした人の一覧
  ///
  /// In ja, this message translates to:
  /// **'引用(リノート)'**
  String get postThreadModeRenotes;

  /// 返信欄の帯に出す欄の名前(リノートした人の一覧のとき)。短く
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get postThreadModeRenotesShort;

  /// 欄の切り替えの項目: 返信の一覧
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get postThreadModeReplies;

  /// 返信欄の帯に出す欄の名前(返信の一覧のとき)。短く
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get postThreadModeRepliesShort;

  /// 欄の切り替えの項目: リアクション(絵文字ごと)の一覧。Misskey だけ
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get postThreadModeReactions;

  /// 返信欄の帯に出す欄の名前(リアクションの一覧のとき)。短く
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get postThreadModeReactionsShort;

  /// 欄の切り替えの項目: この投稿を引用した投稿(引用ノート)の一覧
  ///
  /// In ja, this message translates to:
  /// **'共有(引用ノート)'**
  String get postThreadModeQuotes;

  /// 返信欄の帯に出す欄の名前(引用ノートの一覧のとき)。短く
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get postThreadModeQuotesShort;

  /// 投稿の詳細の見出しのブックマークのボタンのツールチップ。ブックマークの無い SNS で、長押しでクリップに入れられる
  ///
  /// In ja, this message translates to:
  /// **'クリップに追加(長押し)'**
  String get postBookmarkClipTooltip;

  /// ブックマークのボタンのツールチップ(ブックマーク済み)。長押しでクリップに入れる
  ///
  /// In ja, this message translates to:
  /// **'ブックマークを外す(長押しでクリップへ)'**
  String get postBookmarkRemoveTooltip;

  /// ブックマークのボタンのツールチップ(未ブックマーク)。長押しでクリップに入れる
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク(長押しでクリップへ)'**
  String get postBookmarkAddTooltip;

  /// ブックマークの無い SNS でボタンを短く押したときのスナックバー
  ///
  /// In ja, this message translates to:
  /// **'このサービスにはブックマークがありません。長押しでクリップに追加できます'**
  String get postBookmarkUnsupported;

  /// ブックマークを外したときのスナックバー
  ///
  /// In ja, this message translates to:
  /// **'ブックマークを外しました'**
  String get postBookmarkRemoved;

  /// ブックマークしたときのスナックバー
  ///
  /// In ja, this message translates to:
  /// **'ブックマークしました'**
  String get postBookmarkAdded;

  /// ブックマーク / 解除に失敗したときのスナックバー。error は失敗の理由(SNS から返った文など)
  ///
  /// In ja, this message translates to:
  /// **'ブックマークできませんでした: {error}'**
  String postBookmarkError(String error);

  /// 投稿のリアクションの画面(返信 / 引用 / リアクション / 共有のタブ)の見出し
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get postReactionsTitle;

  /// リアクションの画面のタブ: 返信の一覧
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get postReactionsTabReplies;

  /// リアクションの画面のタブ: リノート・引用した人の一覧
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get postReactionsTabQuotes;

  /// リアクションの画面のタブ: 絵文字ごとのリアクションの一覧
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get postReactionsTabReactions;

  /// リアクションの画面のタブ: この投稿を引用した投稿(引用ノート)の一覧
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get postReactionsTabShares;

  /// リアクションの画面の見出しのブックマークのボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク'**
  String get postReactionsBookmarkTooltip;

  /// 返信の一覧が空のとき
  ///
  /// In ja, this message translates to:
  /// **'返信はありません'**
  String get postRepliesEmpty;

  /// 引用ノート(この投稿を引用した投稿)の一覧が空のとき。リアクションの画面の共有のタブと、投稿の詳細の共有の欄
  ///
  /// In ja, this message translates to:
  /// **'引用ノートはありません'**
  String get postQuotesEmpty;

  /// リアクションの画面の引用のタブ(リノートした人の一覧)が空のとき
  ///
  /// In ja, this message translates to:
  /// **'リノート・引用はありません'**
  String get postRepostersEmpty;

  /// リアクションの一覧が空のとき
  ///
  /// In ja, this message translates to:
  /// **'リアクションはありません'**
  String get postReactionsEmpty;

  /// リアクションの一覧で、自分が付けたリアクションの行に付ける小さな印
  ///
  /// In ja, this message translates to:
  /// **'あなた'**
  String get postReactionsMine;

  /// 投稿の詳細の見出しのアカウントのボタンで別のアカウントを選んだが、そのアカウントのサーバーで同じ投稿が見つからなかったときのスナックバー。account はアカウント(@名前@サーバー)
  ///
  /// In ja, this message translates to:
  /// **'{account} ではこの投稿を見つけられませんでした'**
  String postDetailNotFoundOnAccount(String account);

  /// 投稿の詳細の画面の見出し
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get postDetailTitle;

  /// 投稿の詳細の見出しのアカウントの選択で、投稿を開いたときのアカウントに付ける印の説明
  ///
  /// In ja, this message translates to:
  /// **'開いたアカウント'**
  String get postDetailOpenedAccount;

  /// 投稿の詳細で、投稿が消えている(404)とき
  ///
  /// In ja, this message translates to:
  /// **'投稿はありません'**
  String get postDetailNotFound;

  /// 読み込みに失敗したときのやり直しのボタン
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get postReload;

  /// 投稿の詳細の返信欄の帯の右のボタン。リアクションの画面を開く
  ///
  /// In ja, this message translates to:
  /// **'リアクションを表示'**
  String get postDetailShowReactions;

  /// 投稿の詳細の返信の一覧の下のボタン
  ///
  /// In ja, this message translates to:
  /// **'さらに表示'**
  String get postDetailShowMore;

  /// 投稿の詳細の引用(リノート)の欄が空のとき
  ///
  /// In ja, this message translates to:
  /// **'リノートはありません'**
  String get postRenotesEmpty;

  /// 投稿の共有の画面の見出しのアカウントの選択のツールチップ(選べるアカウントが複数のとき)
  ///
  /// In ja, this message translates to:
  /// **'共有に使うアカウント'**
  String get postShareAccountTooltip;

  /// アカウントの選択のツールチップ(非公開の投稿などで、受け取ったアカウントでしか共有できないとき)
  ///
  /// In ja, this message translates to:
  /// **'受け取ったアカウントだけで共有できます'**
  String get postShareAccountFixedTooltip;

  /// 投稿の共有の画面(FOW)の読み上げの名前
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get postShareSemantics;

  /// 共有の画面で「内容をコピー」を押したときのスナックバー
  ///
  /// In ja, this message translates to:
  /// **'内容をコピーしました'**
  String get postShareContentCopied;

  /// 共有の画面で「リンクをコピー」を押したときのスナックバー
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピーしました'**
  String get postShareLinkCopied;

  /// DM の相手を選ぶ画面の見出し
  ///
  /// In ja, this message translates to:
  /// **'DM へ共有'**
  String get postShareDmTitle;

  /// 共有の画面 / DM の相手を選ぶ画面を閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get postShareClose;

  /// DM の相手を選ぶ画面で、DM の相手が 1 人もいないとき
  ///
  /// In ja, this message translates to:
  /// **'DM の相手がいません'**
  String get postShareDmNoRooms;

  /// 投稿を ASTell のルームに共有したときのスナックバー。room はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'「{room}」に共有しました'**
  String postShareAstellShared(String room);

  /// 共有の画面の上段のボタン: 投稿の本文(注意書き付き)をコピーする
  ///
  /// In ja, this message translates to:
  /// **'内容をコピー'**
  String get postShareCopyContent;

  /// 共有の画面の上段のボタン: 投稿のリンクをコピーする
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get postShareCopyLink;

  /// 共有の画面の上段のボタン: 選んだアカウントのコンポーザーにリンクを入れて開く
  ///
  /// In ja, this message translates to:
  /// **'他のアカウントで共有'**
  String get postShareOtherAccount;

  /// 共有の画面の節の見出し。参加中の ASTell と、共有に対応したプラグインが並ぶ
  ///
  /// In ja, this message translates to:
  /// **'プラグインに共有'**
  String get postSharePluginsHeader;

  /// 共有の画面の行: 参加中の ASTell のルームに投稿を流す
  ///
  /// In ja, this message translates to:
  /// **'ASTell に共有'**
  String get postShareAstellTitle;

  /// 「ASTell に共有」の行の補足。room はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'参加中のルーム「{room}」へ投稿を流す'**
  String postShareAstellSubtitle(String room);

  /// 共有の画面で、共有に対応したプラグインが 1 つも無いときの説明
  ///
  /// In ja, this message translates to:
  /// **'共有に対応したプラグインがここに並びます'**
  String get postSharePluginsEmpty;

  /// 上と同じ説明の、開発者モードのときの文。post.share はプラグインの宣言の名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'post.share を宣言したプラグイン(と参加中の ASTell)がここに並びます'**
  String get postSharePluginsEmptyDetail;

  /// 共有の画面の節の見出し(DM へ共有など)
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get postShareOtherHeader;

  /// 共有の画面の「DM へ共有」の行の補足
  ///
  /// In ja, this message translates to:
  /// **'選んだアカウントの DM にリンクを送る'**
  String get postShareDmSubtitle;

  /// 共有の画面の下のボタン: 投稿のリンクをブラウザで開く
  ///
  /// In ja, this message translates to:
  /// **'ブラウザで開く'**
  String get postShareOpenBrowser;

  /// 投稿の「…」のメニューの項目
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get postMenuCopyLink;

  /// 投稿のメニューの項目: 自分のアカウントページの固定を外す
  ///
  /// In ja, this message translates to:
  /// **'固定を外す'**
  String get postMenuUnpin;

  /// 投稿のメニューの項目: 自分のアカウントページに固定する
  ///
  /// In ja, this message translates to:
  /// **'固定する'**
  String get postMenuPin;

  /// 投稿のメニューの項目: 投稿の詳細を開く
  ///
  /// In ja, this message translates to:
  /// **'詳細'**
  String get postMenuDetail;

  /// 投稿のメニューの項目: 共有の画面を開く
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get postMenuShare;

  /// 投稿のメニューの項目: 投稿の下のボタンの並び(アクションバー)を編集する
  ///
  /// In ja, this message translates to:
  /// **'アクションバーを編集'**
  String get postMenuEditActionBar;

  /// 投稿のメニューの項目(お気に入り済み)
  ///
  /// In ja, this message translates to:
  /// **'お気に入り解除'**
  String get postMenuUnfavorite;

  /// 投稿のメニューの項目: お気に入りに入れる
  ///
  /// In ja, this message translates to:
  /// **'お気に入り'**
  String get postMenuFavorite;

  /// 投稿のメニューの項目
  ///
  /// In ja, this message translates to:
  /// **'クリップに追加'**
  String get postMenuAddToClip;

  /// 投稿のメニューの項目: 投稿した人のフォローを外す
  ///
  /// In ja, this message translates to:
  /// **'フォロー解除'**
  String get postMenuUnfollow;

  /// 投稿のメニューの項目: 投稿した人をフォローする
  ///
  /// In ja, this message translates to:
  /// **'フォロー'**
  String get postMenuFollow;

  /// 投稿のメニューの項目: 投稿した人のミュートを外す
  ///
  /// In ja, this message translates to:
  /// **'ミュート解除'**
  String get postMenuUnmute;

  /// 投稿のメニューの項目: 投稿した人をミュートする
  ///
  /// In ja, this message translates to:
  /// **'ミュート'**
  String get postMenuMute;

  /// 投稿のメニューの項目: 投稿した人のブロックを外す
  ///
  /// In ja, this message translates to:
  /// **'ブロック解除'**
  String get postMenuUnblock;

  /// 投稿のメニューの項目、およびブロックの確認のボタン
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get postMenuBlock;

  /// 投稿のメニューの項目、および報告の確認のボタン
  ///
  /// In ja, this message translates to:
  /// **'報告'**
  String get postMenuReport;

  /// 投稿のメニューの項目(自分の投稿)、および削除の確認のボタン
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get postMenuDelete;

  /// ブロックの確認の見出し。name は投稿した人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} をブロックしますか？'**
  String postBlockConfirmTitle(String name);

  /// 確認のダイアログのやめるボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get postCancel;

  /// 投稿の報告の確認の見出し
  ///
  /// In ja, this message translates to:
  /// **'この投稿を報告しますか？'**
  String get postReportConfirmTitle;

  /// 投稿の報告の確認の説明
  ///
  /// In ja, this message translates to:
  /// **'サーバー管理者に報告します。'**
  String get postReportConfirmMessage;

  /// 投稿の削除の確認の見出し
  ///
  /// In ja, this message translates to:
  /// **'投稿を削除しますか？'**
  String get postDeleteConfirmTitle;

  /// 投稿の削除の確認の説明
  ///
  /// In ja, this message translates to:
  /// **'この操作は取り消せません。'**
  String get postDeleteConfirmMessage;

  /// 投稿のメニュー / 共有の画面の、添付を端末に保存する項目。kind は video(動画)か image(画像)
  ///
  /// In ja, this message translates to:
  /// **'{kind, select, video{動画を保存} other{画像を保存}}'**
  String postSaveMediaLabel(String kind);

  /// 保存するたびに保存先を選ぶ設定のとき、保存先を選ぶシートの見出し。kind は video(動画)か image(画像)
  ///
  /// In ja, this message translates to:
  /// **'{kind, select, video{動画の保存先} other{画像の保存先}}'**
  String postSaveDestinationTitle(String kind);

  /// 保存先の選択の「写真」の行の補足。RASQ はアルバムの名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'アルバム「RASQ」に入ります'**
  String get postSaveToPhotosSubtitle;

  /// 保存先の選択の「ファイル」の行の補足(iOS)。「ファイル」App の中のフォルダーの場所。「ファイル」App / このiPad / このiPhone は iOS の表示に合わせる。「RASQ › 保存」は端末に作るフォルダーの実際の名前なので訳さない
  ///
  /// In ja, this message translates to:
  /// **'「ファイル」App の このiPad(このiPhone)› RASQ › 保存'**
  String get postSaveToFilesIosSubtitle;

  /// 保存先の選択の「ファイル」の行の補足(iOS 以外)
  ///
  /// In ja, this message translates to:
  /// **'保存する場所を選びます'**
  String get postSaveToFilesSubtitle;

  /// 保存先の選択のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'次からもこの保存先にする'**
  String get postSaveRememberTitle;

  /// 上のスイッチの補足。設定の画面の場所(設定の画面の見出しと揃える)
  ///
  /// In ja, this message translates to:
  /// **'設定 → アプリの外観 →「画像・動画の保存先」で変えられます'**
  String get postSaveRememberSubtitle;

  /// 添付の保存に失敗したときのスナックバー。kind は video(動画)か image(画像)、error は失敗の理由
  ///
  /// In ja, this message translates to:
  /// **'{kind, select, video{動画を保存できませんでした: {error}} other{画像を保存できませんでした: {error}}}'**
  String postSaveFailed(String kind, String error);

  /// プロフィールの編集画面(RASQ アカウント / SNS)の見出し
  ///
  /// In ja, this message translates to:
  /// **'プロフィールの更新'**
  String get profileEditTitle;

  /// プロフィールの編集画面の右上の保存のボタン
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get profileEditSave;

  /// No description provided for @profileEditNotLoggedIn.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインしていません。'**
  String get profileEditNotLoggedIn;

  /// No description provided for @profileEditBannerRemove.
  ///
  /// In ja, this message translates to:
  /// **'バナーを外す'**
  String get profileEditBannerRemove;

  /// No description provided for @profileEditBannerPick.
  ///
  /// In ja, this message translates to:
  /// **'バナーを選ぶ'**
  String get profileEditBannerPick;

  /// No description provided for @profileEditAvatarPick.
  ///
  /// In ja, this message translates to:
  /// **'アイコンを選ぶ'**
  String get profileEditAvatarPick;

  /// No description provided for @profileEditAvatarRemove.
  ///
  /// In ja, this message translates to:
  /// **'アイコンを外す'**
  String get profileEditAvatarRemove;

  /// SNS のプロフィール編集: バナー / アイコンの画像を選ぶボタン
  ///
  /// In ja, this message translates to:
  /// **'画像を選択'**
  String get profileEditPickImage;

  /// No description provided for @profileEditNameHint.
  ///
  /// In ja, this message translates to:
  /// **'名前を入力..'**
  String get profileEditNameHint;

  /// RASQ アカウントの誕生日の入力欄のヒント(書式はサーバーが受けるもの)
  ///
  /// In ja, this message translates to:
  /// **'誕生日 (YYYY-MM-DD / MM-DD)'**
  String get profileEditBirthdayHint;

  /// SNS のプロフィール編集の誕生日の入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'誕生日 (YYYY-MM-DD)'**
  String get profileEditBirthdayHintSns;

  /// No description provided for @profileEditHandleLabel.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル(@ なし、a-z 0-9 _、3〜32 文字)'**
  String get profileEditHandleLabel;

  /// No description provided for @profileEditBioLabel.
  ///
  /// In ja, this message translates to:
  /// **'自己紹介'**
  String get profileEditBioLabel;

  /// No description provided for @profileEditBioHint.
  ///
  /// In ja, this message translates to:
  /// **'自己紹介(500 文字まで)'**
  String get profileEditBioHint;

  /// No description provided for @profileEditLocationLabel.
  ///
  /// In ja, this message translates to:
  /// **'場所'**
  String get profileEditLocationLabel;

  /// No description provided for @profileEditLinksLabel.
  ///
  /// In ja, this message translates to:
  /// **'リンク'**
  String get profileEditLinksLabel;

  /// No description provided for @profileEditLinkRemove.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get profileEditLinkRemove;

  /// リンクの見出し(表示する名前)の入力欄
  ///
  /// In ja, this message translates to:
  /// **'キャプション'**
  String get profileEditLinkCaptionHint;

  /// No description provided for @profileEditLinkAdd.
  ///
  /// In ja, this message translates to:
  /// **'追加'**
  String get profileEditLinkAdd;

  /// No description provided for @profileEditReload.
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get profileEditReload;

  /// No description provided for @profileEditSnsTilesLabel.
  ///
  /// In ja, this message translates to:
  /// **'アカウントページに出す SNS アカウント'**
  String get profileEditSnsTilesLabel;

  /// No description provided for @profileEditSnsTilesCaption.
  ///
  /// In ja, this message translates to:
  /// **'「自動」では、鍵アカウントなどは出しません。薄いタイルは、いま出ていないものです。'**
  String get profileEditSnsTilesCaption;

  /// No description provided for @profileEditSnsTilesCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'「自動」は、鍵アカウントと、直近の投稿の公開範囲がフォロワーのみに寄っているアカウントを出しません。薄いタイルは、いまは出ていないものです。変更はすぐ反映されます。'**
  String get profileEditSnsTilesCaptionDetail;

  /// SNS のタイルを出すかの 3 択の「自動」。state はいまの結果(表示 / 非表示)
  ///
  /// In ja, this message translates to:
  /// **'自動({state})'**
  String profileEditSnsTileAuto(String state);

  /// No description provided for @profileEditSnsTileShown.
  ///
  /// In ja, this message translates to:
  /// **'表示'**
  String get profileEditSnsTileShown;

  /// No description provided for @profileEditSnsTileHidden.
  ///
  /// In ja, this message translates to:
  /// **'非表示'**
  String get profileEditSnsTileHidden;

  /// method は確認の方法(サーバーが返す名前)
  ///
  /// In ja, this message translates to:
  /// **'持ち主を確認済み({method})'**
  String profileEditVerified(String method);

  /// No description provided for @profileEditVerify.
  ///
  /// In ja, this message translates to:
  /// **'持ち主を確認'**
  String get profileEditVerify;

  /// No description provided for @profileEditShowOnSnsLabel.
  ///
  /// In ja, this message translates to:
  /// **'SNS のプロフィール'**
  String get profileEditShowOnSnsLabel;

  /// No description provided for @profileEditShowOnSnsTitle.
  ///
  /// In ja, this message translates to:
  /// **'SNS のプロフィールにも、つないだアカウントを出す'**
  String get profileEditShowOnSnsTitle;

  /// No description provided for @profileEditShowOnSnsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ で誰かがあなたの SNS のプロフィールを見たとき、つないだアカウントを出します。'**
  String get profileEditShowOnSnsSubtitle;

  /// No description provided for @profileEditShowOnSnsDetail.
  ///
  /// In ja, this message translates to:
  /// **'アプリで誰かがあなたの SNS のプロフィールを見たとき、この RASQ アカウントと、アカウントページに出しているほかのアカウントを出します。自己紹介に書いてあるものは重ねて出しません。変更はすぐ反映されます。'**
  String get profileEditShowOnSnsDetail;

  /// No description provided for @profileEditKeybaseConnect.
  ///
  /// In ja, this message translates to:
  /// **'Keybase をつなぐ'**
  String get profileEditKeybaseConnect;

  /// No description provided for @profileEditKeybaseConnectSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'Keybase で本人確認して、アカウントページに出します'**
  String get profileEditKeybaseConnectSubtitle;

  /// No description provided for @profileEditKeybaseLinkedSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'確認済み。アカウントページに出ます'**
  String get profileEditKeybaseLinkedSubtitle;

  /// No description provided for @profileEditNotice.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールは、公開ページとストアのレビューに出ます。メールとパスワードは「セキュリティ」から。'**
  String get profileEditNotice;

  /// No description provided for @profileEditNoticeDetail.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールは、RASQ の公開ページとストアのレビューに出ます。画像はサーバーで縮めて保存し直します(位置情報などは残りません)。メールアドレスとパスワードは「セキュリティ」から。'**
  String get profileEditNoticeDetail;

  /// No description provided for @profileEditErrorHandleTaken.
  ///
  /// In ja, this message translates to:
  /// **'そのハンドルは使われています'**
  String get profileEditErrorHandleTaken;

  /// No description provided for @profileEditErrorHandle.
  ///
  /// In ja, this message translates to:
  /// **'ハンドルは 3〜32 文字の a-z 0-9 _ にしてください'**
  String get profileEditErrorHandle;

  /// No description provided for @profileEditErrorBirthday.
  ///
  /// In ja, this message translates to:
  /// **'誕生日は YYYY-MM-DD か MM-DD の形で入れてください'**
  String get profileEditErrorBirthday;

  /// No description provided for @profileEditErrorLink.
  ///
  /// In ja, this message translates to:
  /// **'リンクは、キャプション(40 文字まで)と http(s) の URL の組にしてください(8 組まで)'**
  String get profileEditErrorLink;

  /// No description provided for @profileEditErrorImage.
  ///
  /// In ja, this message translates to:
  /// **'その画像は使えません(PNG / JPEG / WebP / GIF、8 MiB まで)'**
  String get profileEditErrorImage;

  /// No description provided for @profileEditErrorBio.
  ///
  /// In ja, this message translates to:
  /// **'自己紹介は 500 文字までです'**
  String get profileEditErrorBio;

  /// No description provided for @profileEditErrorLocation.
  ///
  /// In ja, this message translates to:
  /// **'場所は 60 文字までです'**
  String get profileEditErrorLocation;

  /// message はサーバー / SNS の誤りの文
  ///
  /// In ja, this message translates to:
  /// **'更新に失敗しました: {message}'**
  String profileEditErrorFailed(String message);

  /// No description provided for @profileEditSnsPostsWithdrawn.
  ///
  /// In ja, this message translates to:
  /// **'預けた鍵と、取ってきた投稿を消しました'**
  String get profileEditSnsPostsWithdrawn;

  /// No description provided for @profileEditSnsPostsWithdrawFailed.
  ///
  /// In ja, this message translates to:
  /// **'消せませんでした: {message}'**
  String profileEditSnsPostsWithdrawFailed(String message);

  /// No description provided for @profileEditSnsPostsNoLogin.
  ///
  /// In ja, this message translates to:
  /// **'この端末に、そのアカウントのログインがありません'**
  String get profileEditSnsPostsNoLogin;

  /// No description provided for @profileEditSnsPostsNoDid.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントの DID が分かりません。ログインし直してください'**
  String get profileEditSnsPostsNoDid;

  /// No description provided for @profileEditSnsPostsBlueskyConsentTitle.
  ///
  /// In ja, this message translates to:
  /// **'Bluesky の投稿をアカウントページに出します'**
  String get profileEditSnsPostsBlueskyConsentTitle;

  /// Bluesky の投稿をアカウントページに出す前の確認(** は太字)。account はアカウントの表記
  ///
  /// In ja, this message translates to:
  /// **'{account} の投稿を、RASQ のサーバーが Bluesky の公開の API から読み、**RASQ のアカウントページで誰でも見られる状態**にします。\n\n・Bluesky の投稿は、もともと誰でも読めます。返信とリポストは取り込みません。\n・**ログインの鍵(アプリパスワード / セッション)は預けません**。サーバーに渡すのは、このアカウントの DID とハンドルだけです。\n・使えるのは、持ち主の確認が済んだアカウントだけです(他人のアカウントの投稿を出せないように)。\n・このスイッチを切ると、取ってきた投稿は、すぐに消えます。'**
  String profileEditSnsPostsBlueskyConsentMessage(String account);

  /// No description provided for @profileEditSnsPostsAgreeShow.
  ///
  /// In ja, this message translates to:
  /// **'同意して出す'**
  String get profileEditSnsPostsAgreeShow;

  /// No description provided for @profileEditCancel.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get profileEditCancel;

  /// No description provided for @profileEditSnsPostsTokenConsentTitle.
  ///
  /// In ja, this message translates to:
  /// **'ログインの鍵を RASQ に預けます'**
  String get profileEditSnsPostsTokenConsentTitle;

  /// SNS のアクセストークンを預ける前の確認(** は太字)。account はアカウントの表記
  ///
  /// In ja, this message translates to:
  /// **'{account} の投稿をアカウントページに出すために、この SNS の**ログインの鍵(アクセストークン)を RASQ のサーバーに預けます**。\n\n・あなたの「公開」と「ホーム(未収載)」の投稿が、**RASQ のアカウントページで誰でも見られる状態**になります。「ホーム」はフォロワー限定ではありません。\n・フォロワー限定 / 指名・DM / ローカルのみ / 公開範囲が分からない投稿は、取り込みません。\n・鍵は、あなたの投稿を読むためだけに使います。投稿・フォローなどの操作や、ほかの目的には使いません。\n・鍵はサーバーの鍵で暗号化して保存します(RASQ のサーバーは復号できます)。アプリにも他の人にも返しません。\n・このスイッチを切ると、預けた鍵と取ってきた投稿は、すぐに消えます。\n\nこの鍵があれば、そのアカウントを操作できます。心配なときは、預けたあとでも SNS 側の設定からこの鍵(トークン)を無効にできます。'**
  String profileEditSnsPostsTokenConsentMessage(String account);

  /// No description provided for @profileEditSnsPostsAgreeDeposit.
  ///
  /// In ja, this message translates to:
  /// **'同意して預ける'**
  String get profileEditSnsPostsAgreeDeposit;

  /// No description provided for @profileEditSnsPostsFetched.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 件の投稿を取ってきました}}'**
  String profileEditSnsPostsFetched(int count);

  /// error はサーバーの誤りの文
  ///
  /// In ja, this message translates to:
  /// **'預けましたが、投稿を取れませんでした({error})'**
  String profileEditSnsPostsFetchFailed(String error);

  /// No description provided for @profileEditSnsPostsUnsupported.
  ///
  /// In ja, this message translates to:
  /// **'このサーバーでは、まだ使えません'**
  String get profileEditSnsPostsUnsupported;

  /// No description provided for @profileEditSnsPostsVerifyFirst.
  ///
  /// In ja, this message translates to:
  /// **'先に、このアカウントの「持ち主の確認」を済ませてください'**
  String get profileEditSnsPostsVerifyFirst;

  /// No description provided for @profileEditSnsPostsDepositFailed.
  ///
  /// In ja, this message translates to:
  /// **'預けられませんでした: {message}'**
  String profileEditSnsPostsDepositFailed(String message);

  /// No description provided for @profileEditSnsPostsSwitchTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿もアカウントページに出す'**
  String get profileEditSnsPostsSwitchTitle;

  /// error はサーバーの誤りの文
  ///
  /// In ja, this message translates to:
  /// **'取得に失敗しています: {error}'**
  String profileEditSnsPostsFetchError(String error);

  /// No description provided for @profileEditSnsPostsCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 件(公開 / ホームの投稿。30 分ごとに更新)}}'**
  String profileEditSnsPostsCount(int count);

  /// No description provided for @profileEditSnsPostsBlueskySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ のサーバーが Bluesky の公開の投稿を読みます(鍵は預けません)'**
  String get profileEditSnsPostsBlueskySubtitle;

  /// No description provided for @profileEditSnsPostsTokenSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'SNS のログインの鍵を RASQ に預けます(入れるときに確認が出ます)'**
  String get profileEditSnsPostsTokenSubtitle;

  /// No description provided for @profileEditSnsPostsCollectionsTitle.
  ///
  /// In ja, this message translates to:
  /// **'この鍵を RASQ リストにも使う'**
  String get profileEditSnsPostsCollectionsTitle;

  /// No description provided for @profileEditSnsPostsCollectionsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'開いた RASQ リストの取得と、見られるかの確認に使います'**
  String get profileEditSnsPostsCollectionsSubtitle;

  /// 開発者モードの詳しい説明
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト・クリップを開いたとき、この鍵で SNS に「リストの人をフォローしているか」を問い合わせ、中の人の公開の投稿を取りに行く。投稿の表示のために預けた鍵とは別の目的なので、別に選ぶ(既定はオフ、選ぶ / やめるは同意の記録に残る)。'**
  String get profileEditSnsPostsCollectionsDetail;

  /// No description provided for @profileEditSnsPostsCollectionsConsentTitle.
  ///
  /// In ja, this message translates to:
  /// **'預けた鍵を RASQ リストにも使います'**
  String get profileEditSnsPostsCollectionsConsentTitle;

  /// No description provided for @profileEditSnsPostsCollectionsConsentMessage.
  ///
  /// In ja, this message translates to:
  /// **'投稿の表示のために預けた鍵を、別の目的にも使います。\n\n・RASQ リストやクリップを開いたとき、この鍵で SNS に「リストの人をフォローしているか」を問い合わせます(見られるかの確認)。\n・リストの人の公開 / ホームの投稿を、この鍵で取りに行きます。\n・投稿・フォローなどの操作には使いません。\n・このスイッチを切ると、すぐに使わなくなります。'**
  String get profileEditSnsPostsCollectionsConsentMessage;

  /// No description provided for @profileEditSnsPostsCollectionsAgree.
  ///
  /// In ja, this message translates to:
  /// **'同意して使う'**
  String get profileEditSnsPostsCollectionsAgree;

  /// No description provided for @profileEditSnsPostsCollectionsFailed.
  ///
  /// In ja, this message translates to:
  /// **'変えられませんでした: {message}'**
  String profileEditSnsPostsCollectionsFailed(String message);

  /// 持ち主の確認の文を貼る場所(Misskey の呼び名)
  ///
  /// In ja, this message translates to:
  /// **'自己紹介か、プロフィールの「追加情報」のどれかに貼って、保存してください。'**
  String get profileOwnershipWhereMisskey;

  /// 持ち主の確認の文を貼る場所(Mastodon の呼び名)
  ///
  /// In ja, this message translates to:
  /// **'自己紹介か、プロフィールの「補足情報」のどれかに貼って、保存してください。'**
  String get profileOwnershipWhereMastodon;

  /// No description provided for @profileOwnershipWhereBluesky.
  ///
  /// In ja, this message translates to:
  /// **'自己紹介(プロフィールの説明)に貼って、保存してください。'**
  String get profileOwnershipWhereBluesky;

  /// No description provided for @profileOwnershipWhereFields.
  ///
  /// In ja, this message translates to:
  /// **'自己紹介か、プロフィールの項目のどれかに貼って、保存してください。'**
  String get profileOwnershipWhereFields;

  /// No description provided for @profileOwnershipWhereBio.
  ///
  /// In ja, this message translates to:
  /// **'自己紹介に貼って、保存してください。'**
  String get profileOwnershipWhereBio;

  /// No description provided for @profileOwnershipErrorNotLinked.
  ///
  /// In ja, this message translates to:
  /// **'この SNS アカウントは、RASQ アカウントにつながっていません'**
  String get profileOwnershipErrorNotLinked;

  /// No description provided for @profileOwnershipErrorUnsupported.
  ///
  /// In ja, this message translates to:
  /// **'この SNS は、まだ持ち主の確認に対応していません'**
  String get profileOwnershipErrorUnsupported;

  /// No description provided for @profileOwnershipErrorTooMany.
  ///
  /// In ja, this message translates to:
  /// **'試す回数が多すぎます。しばらく待ってから、もう一度お試しください'**
  String get profileOwnershipErrorTooMany;

  /// No description provided for @profileOwnershipErrorNotStarted.
  ///
  /// In ja, this message translates to:
  /// **'まだ確認の文を作っていないか、期限が切れています。「確認の文を作る」からやり直してください'**
  String get profileOwnershipErrorNotStarted;

  /// No description provided for @profileOwnershipErrorCodeNotFound.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールに確認の文が見つかりませんでした。保存したか、公開のプロフィールに出ているかを確かめてください(反映まで少しかかることがあります)'**
  String get profileOwnershipErrorCodeNotFound;

  /// No description provided for @profileOwnershipErrorProfileNotFound.
  ///
  /// In ja, this message translates to:
  /// **'その SNS アカウントの公開のプロフィールが見つかりませんでした'**
  String get profileOwnershipErrorProfileNotFound;

  /// No description provided for @profileOwnershipErrorReadFailed.
  ///
  /// In ja, this message translates to:
  /// **'その SNS のプロフィールを読めませんでした。少し待ってから、もう一度お試しください'**
  String get profileOwnershipErrorReadFailed;

  /// message はサーバーの誤りの文
  ///
  /// In ja, this message translates to:
  /// **'確認できませんでした: {message}'**
  String profileOwnershipErrorFailed(String message);

  /// No description provided for @profileOwnershipKeybaseErrorUsername.
  ///
  /// In ja, this message translates to:
  /// **'Keybase のユーザー名(英小文字・数字・_、2〜16 文字)を入れてください'**
  String get profileOwnershipKeybaseErrorUsername;

  /// BEGIN … / END … は Keybase の署名の区切りの行(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'署名を読めませんでした。BEGIN KEYBASE SALTPACK SIGNED MESSAGE から END KEYBASE SALTPACK SIGNED MESSAGE. までを、そのまま貼ってください'**
  String get profileOwnershipKeybaseErrorSignature;

  /// No description provided for @profileOwnershipKeybaseErrorStatement.
  ///
  /// In ja, this message translates to:
  /// **'署名した文が違います。上のコマンドを、そのまま使ってください'**
  String get profileOwnershipKeybaseErrorStatement;

  /// No description provided for @profileOwnershipKeybaseErrorKey.
  ///
  /// In ja, this message translates to:
  /// **'その Keybase のユーザーの鍵で署名されていません'**
  String get profileOwnershipKeybaseErrorKey;

  /// No description provided for @profileOwnershipKeybaseErrorNoUser.
  ///
  /// In ja, this message translates to:
  /// **'その Keybase のユーザーは見つかりませんでした'**
  String get profileOwnershipKeybaseErrorNoUser;

  /// No description provided for @profileOwnershipKeybaseErrorOtherAccount.
  ///
  /// In ja, this message translates to:
  /// **'その Keybase は、別の RASQ アカウントにつながっています'**
  String get profileOwnershipKeybaseErrorOtherAccount;

  /// No description provided for @profileOwnershipKeybaseErrorExpired.
  ///
  /// In ja, this message translates to:
  /// **'文の期限が切れたか、まだ作っていません。「署名する文を作る」からやり直してください'**
  String get profileOwnershipKeybaseErrorExpired;

  /// No description provided for @profileOwnershipKeybaseErrorUnreachable.
  ///
  /// In ja, this message translates to:
  /// **'Keybase に繋がりませんでした。少し待ってから、もう一度お試しください'**
  String get profileOwnershipKeybaseErrorUnreachable;

  /// message はサーバーの誤りの文
  ///
  /// In ja, this message translates to:
  /// **'確かめられませんでした: {message}'**
  String profileOwnershipKeybaseErrorFailed(String message);

  /// No description provided for @profileOwnershipVerifyTitle.
  ///
  /// In ja, this message translates to:
  /// **'持ち主を確認'**
  String get profileOwnershipVerifyTitle;

  /// No description provided for @profileOwnershipNotLinked.
  ///
  /// In ja, this message translates to:
  /// **'この SNS アカウントは、RASQ アカウントにつながっていません。'**
  String get profileOwnershipNotLinked;

  /// method は確認の方法(サーバーが返す名前)
  ///
  /// In ja, this message translates to:
  /// **'確認済み({method})'**
  String profileOwnershipVerified(String method);

  /// No description provided for @profileOwnershipJustVerified.
  ///
  /// In ja, this message translates to:
  /// **'確認できました。プロフィールに貼った文は、もう消してかまいません。'**
  String get profileOwnershipJustVerified;

  /// No description provided for @profileOwnershipVerifiedCaption.
  ///
  /// In ja, this message translates to:
  /// **'アカウントページと SNS のプロフィールに、確認済みの印が付きます。'**
  String get profileOwnershipVerifiedCaption;

  /// No description provided for @profileOwnershipVerifiedCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'アカウントページと、SNS のプロフィールに出る RASQ アカウントの欄に、確認済みの印が付きます。この SNS アカウントを外すまで続きます。'**
  String get profileOwnershipVerifiedCaptionDetail;

  /// No description provided for @profileOwnershipUnsupportedKind.
  ///
  /// In ja, this message translates to:
  /// **'この SNS は、まだ本人確認に対応していません(Misskey / Mastodon / Bluesky のみ)。'**
  String get profileOwnershipUnsupportedKind;

  /// No description provided for @profileOwnershipIntro.
  ///
  /// In ja, this message translates to:
  /// **'この SNS アカウントがあなたのものか確かめます。プロフィールに確認の文を一時的に貼ってください。'**
  String get profileOwnershipIntro;

  /// No description provided for @profileOwnershipIntroDetail.
  ///
  /// In ja, this message translates to:
  /// **'この SNS アカウントが、あなたのものかを確かめます。確認の文をその SNS のプロフィールに一時的に貼ってもらい、RASQ がその公開のプロフィールを読んで確かめます。'**
  String get profileOwnershipIntroDetail;

  /// No description provided for @profileOwnershipEffect.
  ///
  /// In ja, this message translates to:
  /// **'確かめると、確認済みの印が付きます。'**
  String get profileOwnershipEffect;

  /// No description provided for @profileOwnershipEffectDetail.
  ///
  /// In ja, this message translates to:
  /// **'確かめると、アカウントページと SNS のプロフィールの RASQ アカウントの欄に、確認済みの印が付きます。同じ SNS アカウントをほかの人がつないでいても、確認した人が優先されます。'**
  String get profileOwnershipEffectDetail;

  /// No description provided for @profileOwnershipStart.
  ///
  /// In ja, this message translates to:
  /// **'確認の文を作る'**
  String get profileOwnershipStart;

  /// No description provided for @profileOwnershipStep1.
  ///
  /// In ja, this message translates to:
  /// **'1. この文をコピーする'**
  String get profileOwnershipStep1;

  /// No description provided for @profileOwnershipCopied.
  ///
  /// In ja, this message translates to:
  /// **'確認の文をコピーしました'**
  String get profileOwnershipCopied;

  /// No description provided for @profileOwnershipCopy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get profileOwnershipCopy;

  /// time は期限の日時
  ///
  /// In ja, this message translates to:
  /// **'{time} まで有効'**
  String profileOwnershipValidUntil(String time);

  /// No description provided for @profileOwnershipStep2.
  ///
  /// In ja, this message translates to:
  /// **'2. その SNS のプロフィールに貼る'**
  String get profileOwnershipStep2;

  /// No description provided for @profileOwnershipNoRewrite.
  ///
  /// In ja, this message translates to:
  /// **'RASQ からプロフィールを書き換えることはしません。その SNS で、ご自分で貼ってください。'**
  String get profileOwnershipNoRewrite;

  /// No description provided for @profileOwnershipStep3.
  ///
  /// In ja, this message translates to:
  /// **'3. 貼ったら「確認する」'**
  String get profileOwnershipStep3;

  /// No description provided for @profileOwnershipCheck.
  ///
  /// In ja, this message translates to:
  /// **'確認する'**
  String get profileOwnershipCheck;

  /// No description provided for @profileOwnershipRestart.
  ///
  /// In ja, this message translates to:
  /// **'文を作り直す'**
  String get profileOwnershipRestart;

  /// No description provided for @profileOwnershipKeybaseNoLinks.
  ///
  /// In ja, this message translates to:
  /// **'Keybase の証明に、つないでいる SNS アカウントはありませんでした。'**
  String get profileOwnershipKeybaseNoLinks;

  /// No description provided for @profileOwnershipKeybaseLinksVerified.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{Keybase の証明で、つないでいる SNS アカウント {count} 件も確認済みになりました。}}'**
  String profileOwnershipKeybaseLinksVerified(int count);

  /// username は Keybase のユーザー名、links は証明で確認済みになった SNS アカウントの文
  ///
  /// In ja, this message translates to:
  /// **'@{username} をつなぎました。{links}'**
  String profileOwnershipKeybaseLinked(String username, String links);

  /// No description provided for @profileOwnershipKeybaseUnlinked.
  ///
  /// In ja, this message translates to:
  /// **'Keybase を外しました。Keybase の証明で確認していた SNS アカウントは、未確認に戻ります。'**
  String get profileOwnershipKeybaseUnlinked;

  /// No description provided for @profileOwnershipKeybaseVerifiedAt.
  ///
  /// In ja, this message translates to:
  /// **'{time} に確認'**
  String profileOwnershipKeybaseVerifiedAt(String time);

  /// No description provided for @profileOwnershipKeybaseCaption.
  ///
  /// In ja, this message translates to:
  /// **'アカウントページに「Keybase: @{username}」が出ます。'**
  String profileOwnershipKeybaseCaption(String username);

  /// No description provided for @profileOwnershipKeybaseCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'アカウントページに「Keybase: @{username}」が出ます。Keybase で Mastodon などの証明を足したら、「証明を読み直す」で、つないでいる SNS アカウントも確認済みになります。'**
  String profileOwnershipKeybaseCaptionDetail(String username);

  /// No description provided for @profileOwnershipKeybaseRefresh.
  ///
  /// In ja, this message translates to:
  /// **'証明を読み直す'**
  String get profileOwnershipKeybaseRefresh;

  /// No description provided for @profileOwnershipKeybaseUnlink.
  ///
  /// In ja, this message translates to:
  /// **'Keybase を外す'**
  String get profileOwnershipKeybaseUnlink;

  /// No description provided for @profileOwnershipKeybaseIntro.
  ///
  /// In ja, this message translates to:
  /// **'Keybase で署名して、この RASQ アカウントとつなぎます。つないだ Keybase は公開されます。'**
  String get profileOwnershipKeybaseIntro;

  /// No description provided for @profileOwnershipKeybaseIntroDetail.
  ///
  /// In ja, this message translates to:
  /// **'Keybase のアカウントで署名して、この RASQ アカウントとつなぎます。つないだ Keybase は、アカウントページに出ます(Keybase のプロフィールと同じく公開です)。'**
  String get profileOwnershipKeybaseIntroDetail;

  /// No description provided for @profileOwnershipKeybaseUsername.
  ///
  /// In ja, this message translates to:
  /// **'Keybase のユーザー名'**
  String get profileOwnershipKeybaseUsername;

  /// No description provided for @profileOwnershipKeybaseStart.
  ///
  /// In ja, this message translates to:
  /// **'署名する文を作る'**
  String get profileOwnershipKeybaseStart;

  /// No description provided for @profileOwnershipKeybaseStep1.
  ///
  /// In ja, this message translates to:
  /// **'1. Keybase が入っている端末で、このコマンドを実行する'**
  String get profileOwnershipKeybaseStep1;

  /// No description provided for @profileOwnershipKeybaseCopied.
  ///
  /// In ja, this message translates to:
  /// **'コマンドをコピーしました'**
  String get profileOwnershipKeybaseCopied;

  /// statement はサーバーが作った署名する文(英語のまま)
  ///
  /// In ja, this message translates to:
  /// **'署名する文: {statement}'**
  String profileOwnershipKeybaseStatement(String statement);

  /// No description provided for @profileOwnershipKeybaseStep2.
  ///
  /// In ja, this message translates to:
  /// **'2. 出てきた署名を、BEGIN から END … MESSAGE. まで貼る'**
  String get profileOwnershipKeybaseStep2;

  /// No description provided for @profileOwnershipKeybaseVerify.
  ///
  /// In ja, this message translates to:
  /// **'確かめる'**
  String get profileOwnershipKeybaseVerify;

  /// No description provided for @profilePagePostLimit.
  ///
  /// In ja, this message translates to:
  /// **'{limit, plural, other{投稿は {limit} 件までです。古い投稿を消してから投稿してください}}'**
  String profilePagePostLimit(int limit);

  /// No description provided for @profilePageEdit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get profilePageEdit;

  /// No description provided for @profilePageCompose.
  ///
  /// In ja, this message translates to:
  /// **'RASQ に投稿'**
  String get profilePageCompose;

  /// No description provided for @profilePageNotFound.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} という RASQ アカウントはありません'**
  String profilePageNotFound(String handle);

  /// message はサーバーの誤りの文
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした: {message}'**
  String profilePageLoadFailed(String message);

  /// No description provided for @profilePageLoadFailedShort.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした。'**
  String get profilePageLoadFailedShort;

  /// No description provided for @profilePageTabPosts.
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get profilePageTabPosts;

  /// No description provided for @profilePageTabMedia.
  ///
  /// In ja, this message translates to:
  /// **'メディア'**
  String get profilePageTabMedia;

  /// No description provided for @profilePageTabPages.
  ///
  /// In ja, this message translates to:
  /// **'ページ'**
  String get profilePageTabPages;

  /// No description provided for @profilePageTabLists.
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get profilePageTabLists;

  /// No description provided for @profilePageTabClips.
  ///
  /// In ja, this message translates to:
  /// **'クリップ'**
  String get profilePageTabClips;

  /// No description provided for @profilePageTabPlugins.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get profilePageTabPlugins;

  /// No description provided for @profilePageTabReviews.
  ///
  /// In ja, this message translates to:
  /// **'レビュー'**
  String get profilePageTabReviews;

  /// No description provided for @profilePageTileNoDestination.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントの行き先が分かりません'**
  String get profilePageTileNoDestination;

  /// No description provided for @profilePageOpenFailed.
  ///
  /// In ja, this message translates to:
  /// **'開けませんでした: {url}'**
  String profilePageOpenFailed(String url);

  /// No description provided for @profilePageListsEmptyMine.
  ///
  /// In ja, this message translates to:
  /// **'公開した RASQ リストがここに出ます(リストの画面から作れます)。'**
  String get profilePageListsEmptyMine;

  /// No description provided for @profilePageClipsEmptyMine.
  ///
  /// In ja, this message translates to:
  /// **'公開した RASQ クリップがここに出ます(クリップのページの「公開する」)。'**
  String get profilePageClipsEmptyMine;

  /// No description provided for @profilePageListsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'公開しているリストはありません。'**
  String get profilePageListsEmpty;

  /// No description provided for @profilePageClipsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'公開しているクリップはありません。'**
  String get profilePageClipsEmpty;

  /// アカウントを作った年月。date は年と月
  ///
  /// In ja, this message translates to:
  /// **'{date}から'**
  String profilePageSince(String date);

  /// No description provided for @profilePagePinLimit.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{固定できるのは {count} 件までです}}'**
  String profilePagePinLimit(int count);

  /// No description provided for @profilePagePinFailed.
  ///
  /// In ja, this message translates to:
  /// **'固定できませんでした: {message}'**
  String profilePagePinFailed(String message);

  /// No description provided for @profilePagePinned.
  ///
  /// In ja, this message translates to:
  /// **'固定された投稿'**
  String get profilePagePinned;

  /// used はいまの投稿の数、limit は上限
  ///
  /// In ja, this message translates to:
  /// **'{limit, plural, other{RASQ の投稿は {limit} 件までです({used} / {limit})。SNS の投稿は、ログインの鍵を預けると一緒に出ます。}}'**
  String profilePagePostsNote(int limit, int used);

  /// used はいまの投稿の数、limit は上限
  ///
  /// In ja, this message translates to:
  /// **'{limit, plural, other{RASQ アカウントとしての投稿は、いまは {limit} 件までです({used} / {limit})。SNS アカウントの投稿は、そのアカウントのアクセストークンを RASQ に預けると、ここに一緒に出ます。}}'**
  String profilePagePostsNoteDetail(int limit, int used);

  /// No description provided for @profilePageSnsHintTitle.
  ///
  /// In ja, this message translates to:
  /// **'つないだ SNS アカウントの投稿は、まだここに出ていません。'**
  String get profilePageSnsHintTitle;

  /// No description provided for @profilePageSnsHint.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール編集で「投稿もアカウントページに出す」を入れると、ここに出ます。'**
  String get profilePageSnsHint;

  /// No description provided for @profilePageSnsHintDetail.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール編集の「アカウントページに出す SNS アカウント」で、アカウントごとに「投稿もアカウントページに出す」を入れると(その SNS のアクセストークンを RASQ に預けます)、公開 / ホームの投稿がここに出ます。'**
  String get profilePageSnsHintDetail;

  /// No description provided for @profilePageSnsHintOpen.
  ///
  /// In ja, this message translates to:
  /// **'SNS の投稿を出す設定へ'**
  String get profilePageSnsHintOpen;

  /// No description provided for @profilePageNoPostsYet.
  ///
  /// In ja, this message translates to:
  /// **'投稿はまだありません。'**
  String get profilePageNoPostsYet;

  /// No description provided for @profilePageNoMediaYet.
  ///
  /// In ja, this message translates to:
  /// **'メディアはまだありません。'**
  String get profilePageNoMediaYet;

  /// No description provided for @profilePageNoReviewsYet.
  ///
  /// In ja, this message translates to:
  /// **'レビューはまだありません。'**
  String get profilePageNoReviewsYet;

  /// No description provided for @profilePageNoPluginsPublished.
  ///
  /// In ja, this message translates to:
  /// **'公開したプラグインはありません。'**
  String get profilePageNoPluginsPublished;

  /// No description provided for @profilePageImageUrlMissing.
  ///
  /// In ja, this message translates to:
  /// **'画像の URL が返りませんでした'**
  String get profilePageImageUrlMissing;

  /// No description provided for @profilePageNotConnected.
  ///
  /// In ja, this message translates to:
  /// **'RASQ のサーバーにつないでいません'**
  String get profilePageNotConnected;

  /// 自作プラグインのファイルを選ぶ画面の種類の名前
  ///
  /// In ja, this message translates to:
  /// **'プラグイン(.rspkg / .rasqpkg)'**
  String get profilePagePackageTypeLabel;

  /// ページに貼る画像(ファイルを選ぶ画面の種類 / 道具の行のボタン / 貼った画像の代替の文の既定)
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get profilePageImage;

  /// 読めなかった画像の代わりに出す文。alt は画像の代替の文
  ///
  /// In ja, this message translates to:
  /// **'(画像: {alt})'**
  String profilePageImageAlt(String alt);

  /// No description provided for @profilePageMdFallbackTitle.
  ///
  /// In ja, this message translates to:
  /// **'ページ'**
  String get profilePageMdFallbackTitle;

  /// No description provided for @profilePageMdLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'ページを読めませんでした'**
  String get profilePageMdLoadFailed;

  /// No description provided for @profilePageMdToolBold.
  ///
  /// In ja, this message translates to:
  /// **'太字'**
  String get profilePageMdToolBold;

  /// No description provided for @profilePageMdToolHeading.
  ///
  /// In ja, this message translates to:
  /// **'見出し'**
  String get profilePageMdToolHeading;

  /// No description provided for @profilePageMdToolBullet.
  ///
  /// In ja, this message translates to:
  /// **'箇条書き'**
  String get profilePageMdToolBullet;

  /// No description provided for @profilePageMdToolLink.
  ///
  /// In ja, this message translates to:
  /// **'リンク'**
  String get profilePageMdToolLink;

  /// No description provided for @profilePageMdToolCenter.
  ///
  /// In ja, this message translates to:
  /// **'中央'**
  String get profilePageMdToolCenter;

  /// No description provided for @profilePageMdToolBig.
  ///
  /// In ja, this message translates to:
  /// **'大きく'**
  String get profilePageMdToolBig;

  /// No description provided for @profilePageMdToolSmall.
  ///
  /// In ja, this message translates to:
  /// **'小さく'**
  String get profilePageMdToolSmall;

  /// No description provided for @profilePageMdToolSpin.
  ///
  /// In ja, this message translates to:
  /// **'回転'**
  String get profilePageMdToolSpin;

  /// No description provided for @profilePageMdToolJump.
  ///
  /// In ja, this message translates to:
  /// **'跳ねる'**
  String get profilePageMdToolJump;

  /// No description provided for @profilePageMdToolColor.
  ///
  /// In ja, this message translates to:
  /// **'色'**
  String get profilePageMdToolColor;

  /// No description provided for @profilePageMdToolRainbow.
  ///
  /// In ja, this message translates to:
  /// **'虹'**
  String get profilePageMdToolRainbow;

  /// No description provided for @profilePageMdToolRuby.
  ///
  /// In ja, this message translates to:
  /// **'ルビ'**
  String get profilePageMdToolRuby;

  /// ルビの道具で差し込む読みの仮の文字(利用者が書き換える)
  ///
  /// In ja, this message translates to:
  /// **'よみ'**
  String get profilePageMdToolRubyReading;

  /// No description provided for @profilePageImageUploadFailed.
  ///
  /// In ja, this message translates to:
  /// **'画像を上げられませんでした: {error}'**
  String profilePageImageUploadFailed(String error);

  /// No description provided for @profilePageMdTitleRequired.
  ///
  /// In ja, this message translates to:
  /// **'タイトルを入れてください'**
  String get profilePageMdTitleRequired;

  /// No description provided for @profilePageMdLoginToPublish.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインすると公開できます'**
  String get profilePageMdLoginToPublish;

  /// No description provided for @profilePageMdPublished.
  ///
  /// In ja, this message translates to:
  /// **'公開しました'**
  String get profilePageMdPublished;

  /// No description provided for @profilePageMdPublishFailed.
  ///
  /// In ja, this message translates to:
  /// **'公開できませんでした: {error}'**
  String profilePageMdPublishFailed(String error);

  /// No description provided for @profilePageMdDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'ページを削除'**
  String get profilePageMdDeleteTitle;

  /// No description provided for @profilePageMdDeleteDraft.
  ///
  /// In ja, this message translates to:
  /// **'下書きを削除します。'**
  String get profilePageMdDeleteDraft;

  /// No description provided for @profilePageMdDeletePublished.
  ///
  /// In ja, this message translates to:
  /// **'公開したページと下書きを削除します。元に戻せません。'**
  String get profilePageMdDeletePublished;

  /// No description provided for @profilePageDeleteConfirm.
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get profilePageDeleteConfirm;

  /// No description provided for @profilePageCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get profilePageCancel;

  /// No description provided for @profilePageMdDeleteFailed.
  ///
  /// In ja, this message translates to:
  /// **'削除できませんでした: {error}'**
  String profilePageMdDeleteFailed(String error);

  /// No description provided for @profilePageMdEditTitle.
  ///
  /// In ja, this message translates to:
  /// **'ページを編集'**
  String get profilePageMdEditTitle;

  /// No description provided for @profilePageMdDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get profilePageMdDelete;

  /// No description provided for @profilePageMdWrite.
  ///
  /// In ja, this message translates to:
  /// **'書く'**
  String get profilePageMdWrite;

  /// No description provided for @profilePageMdPreview.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get profilePageMdPreview;

  /// No description provided for @profilePageMdPublish.
  ///
  /// In ja, this message translates to:
  /// **'公開'**
  String get profilePageMdPublish;

  /// No description provided for @profilePageMdTitleHint.
  ///
  /// In ja, this message translates to:
  /// **'タイトル'**
  String get profilePageMdTitleHint;

  /// No description provided for @profilePageMdBodyHint.
  ///
  /// In ja, this message translates to:
  /// **'Markdown で書きます。@メンション / #ハッシュタグ / :絵文字: / <center> などの MFM のタグも使えます'**
  String get profilePageMdBodyHint;

  /// No description provided for @profilePageMdDraftCaption.
  ///
  /// In ja, this message translates to:
  /// **'下書きはこの端末に残ります。「公開」で RASQ のページに出します'**
  String get profilePageMdDraftCaption;

  /// SNS のプロフィールに出す、つないだ RASQ アカウントの欄の見出し
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント'**
  String get profilePageRasqAccount;

  /// method は確認の方法(サーバーが返す名前)
  ///
  /// In ja, this message translates to:
  /// **'このアカウントの持ち主を確認済み({method})'**
  String profilePageViewingVerified(String method);

  /// No description provided for @profilePageVerifiedSemantics.
  ///
  /// In ja, this message translates to:
  /// **'持ち主を確認済み'**
  String get profilePageVerifiedSemantics;

  /// No description provided for @profilePostLoginToUse.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインすると使えます'**
  String get profilePostLoginToUse;

  /// No description provided for @profilePostLoginToReply.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインすると返信できます'**
  String get profilePostLoginToReply;

  /// No description provided for @profilePostLoginToRebroad.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインするとリブロードできます'**
  String get profilePostLoginToRebroad;

  /// No description provided for @profilePostLoginToQueue.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインするとキューできます'**
  String get profilePostLoginToQueue;

  /// No description provided for @profilePostErrorInstallPack.
  ///
  /// In ja, this message translates to:
  /// **'このパックをストアからインストールすると、この絵でキューできます'**
  String get profilePostErrorInstallPack;

  /// No description provided for @profilePostErrorForbidden.
  ///
  /// In ja, this message translates to:
  /// **'この投稿には操作できません'**
  String get profilePostErrorForbidden;

  /// No description provided for @profilePostErrorRebroadLimit.
  ///
  /// In ja, this message translates to:
  /// **'この投稿は、これ以上リブロードできません'**
  String get profilePostErrorRebroadLimit;

  /// No description provided for @profilePostErrorReplyLimit.
  ///
  /// In ja, this message translates to:
  /// **'返信は 100 件までです。古い返信を消してください'**
  String get profilePostErrorReplyLimit;

  /// No description provided for @profilePostErrorGone.
  ///
  /// In ja, this message translates to:
  /// **'この投稿 / 絵は、もうありません'**
  String get profilePostErrorGone;

  /// message はサーバーの誤りの文
  ///
  /// In ja, this message translates to:
  /// **'失敗しました: {message}'**
  String profilePostErrorFailed(String message);

  /// No description provided for @profilePostMenuReactions.
  ///
  /// In ja, this message translates to:
  /// **'リアクションを表示'**
  String get profilePostMenuReactions;

  /// No description provided for @profilePostMenuCopyLink.
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get profilePostMenuCopyLink;

  /// No description provided for @profilePostMenuOpenBrowser.
  ///
  /// In ja, this message translates to:
  /// **'ブラウザで開く'**
  String get profilePostMenuOpenBrowser;

  /// No description provided for @profilePostMenuEditActions.
  ///
  /// In ja, this message translates to:
  /// **'アクションバーを編集'**
  String get profilePostMenuEditActions;

  /// No description provided for @profilePostMenuUnpin.
  ///
  /// In ja, this message translates to:
  /// **'固定を外す'**
  String get profilePostMenuUnpin;

  /// No description provided for @profilePostMenuPin.
  ///
  /// In ja, this message translates to:
  /// **'固定する'**
  String get profilePostMenuPin;

  /// No description provided for @profilePostMenuDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get profilePostMenuDelete;

  /// No description provided for @profilePostLinkCopied.
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピーしました'**
  String get profilePostLinkCopied;

  /// No description provided for @profilePostDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿を削除'**
  String get profilePostDeleteTitle;

  /// No description provided for @profilePostDeleteMessage.
  ///
  /// In ja, this message translates to:
  /// **'この投稿と、付いている画像を削除します。元に戻せません。'**
  String get profilePostDeleteMessage;

  /// No description provided for @profilePostDeleteConfirm.
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get profilePostDeleteConfirm;

  /// No description provided for @profilePostCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get profilePostCancel;

  /// No description provided for @profilePostQuoteUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'引用元の投稿は見られません'**
  String get profilePostQuoteUnavailable;

  /// RASQ の投稿の返信(ボタン / 欄の名前)
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get profilePostReply;

  /// RASQ の再投稿(ReBroad)。SNS のリノート / リポストにあたる RASQ の呼び名
  ///
  /// In ja, this message translates to:
  /// **'リブロード'**
  String get profilePostRebroad;

  /// No description provided for @profilePostRebroadUndo.
  ///
  /// In ja, this message translates to:
  /// **'リブロードを取り消す'**
  String get profilePostRebroadUndo;

  /// No description provided for @profilePostQuote.
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get profilePostQuote;

  /// RASQ の投稿へのリアクション(Queue)。アセットパックの絵で付ける
  ///
  /// In ja, this message translates to:
  /// **'キュー'**
  String get profilePostQueue;

  /// No description provided for @profilePostLike.
  ///
  /// In ja, this message translates to:
  /// **'いいね'**
  String get profilePostLike;

  /// No description provided for @profilePostQuoteFollowersOnly.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー限定の投稿は引用できません'**
  String get profilePostQuoteFollowersOnly;

  /// 投稿の上の帯。name はリブロードした人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} がリブロード'**
  String profilePostRebroadedBy(String name);

  /// No description provided for @profilePostReplyToDeleted.
  ///
  /// In ja, this message translates to:
  /// **'削除された投稿への返信'**
  String get profilePostReplyToDeleted;

  /// No description provided for @profilePostShare.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get profilePostShare;

  /// No description provided for @profilePostCwHide.
  ///
  /// In ja, this message translates to:
  /// **'隠す'**
  String get profilePostCwHide;

  /// No description provided for @profilePostCwShow.
  ///
  /// In ja, this message translates to:
  /// **'もっと見る'**
  String get profilePostCwShow;

  /// No description provided for @profilePostNoPacksTitle.
  ///
  /// In ja, this message translates to:
  /// **'アセットパックがありません'**
  String get profilePostNoPacksTitle;

  /// No description provided for @profilePostNoPacksMessage.
  ///
  /// In ja, this message translates to:
  /// **'キューは、ストアで入れたアセットパックの絵でするリアクションです。'**
  String get profilePostNoPacksMessage;

  /// No description provided for @profilePostNoPacksStore.
  ///
  /// In ja, this message translates to:
  /// **'ストアで探す'**
  String get profilePostNoPacksStore;

  /// No description provided for @profilePostClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get profilePostClose;

  /// 全画面の上のキューのボタンの説明。label はボタンの名前
  ///
  /// In ja, this message translates to:
  /// **'{label}(長押しで絵を選ぶ)'**
  String profilePostOverlayQueueTooltip(String label);

  /// No description provided for @profilePostMenu.
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get profilePostMenu;

  /// No description provided for @profilePostTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get profilePostTitle;

  /// No description provided for @profilePostGone.
  ///
  /// In ja, this message translates to:
  /// **'この投稿は、もうありません'**
  String get profilePostGone;

  /// message はサーバーの誤りの文
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした: {message}'**
  String profilePostLoadFailed(String message);

  /// No description provided for @profilePostParentDeleted.
  ///
  /// In ja, this message translates to:
  /// **'元の投稿は削除されています。'**
  String get profilePostParentDeleted;

  /// 返信の欄の帯
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{返信 {count}}}'**
  String profilePostRepliesCount(int count);

  /// No description provided for @profilePostNoRepliesYet.
  ///
  /// In ja, this message translates to:
  /// **'返信はまだありません。'**
  String get profilePostNoRepliesYet;

  /// No description provided for @profilePostNoReplies.
  ///
  /// In ja, this message translates to:
  /// **'返信はありません'**
  String get profilePostNoReplies;

  /// No description provided for @profilePostNoRebroads.
  ///
  /// In ja, this message translates to:
  /// **'リブロードはありません'**
  String get profilePostNoRebroads;

  /// No description provided for @profilePostNoQuotes.
  ///
  /// In ja, this message translates to:
  /// **'引用はありません'**
  String get profilePostNoQuotes;

  /// No description provided for @profilePostNoQueues.
  ///
  /// In ja, this message translates to:
  /// **'キューはありません'**
  String get profilePostNoQueues;

  /// No description provided for @profilePostReactionsTitle.
  ///
  /// In ja, this message translates to:
  /// **'リアクション'**
  String get profilePostReactionsTitle;

  /// キューの欄で、自分が付けた絵の印
  ///
  /// In ja, this message translates to:
  /// **'あなた'**
  String get profilePostYou;

  /// リアクション / コンポーザーの絵文字のボタンを長押しして出るパネルの見出しと、その設定の画面の名前 (D-512)
  ///
  /// In ja, this message translates to:
  /// **'すぐ選べる絵文字'**
  String get quickPickEmojiTitle;

  /// すぐ選べる絵文字のパネルの最後のマス。絵文字ピッカー全体を開く
  ///
  /// In ja, this message translates to:
  /// **'その他の絵文字'**
  String get quickPickEmojiMore;

  /// No description provided for @quickPickSettingsCaption.
  ///
  /// In ja, this message translates to:
  /// **'リアクションのボタンやコンポーザーの絵文字のボタンを長押しすると、ボタンにつながったパネルにここの絵文字と最近使った絵文字が並びます。指を離さずに滑らせて、離したところの絵文字を付けます(入れます)。滑らせずに離すと、パネルは開いたままでタップで選べます。'**
  String get quickPickSettingsCaption;

  /// No description provided for @quickPickSettingsAdd.
  ///
  /// In ja, this message translates to:
  /// **'絵文字を追加'**
  String get quickPickSettingsAdd;

  /// No description provided for @quickPickSettingsReset.
  ///
  /// In ja, this message translates to:
  /// **'既定に戻す'**
  String get quickPickSettingsReset;

  /// 外すボタンのツールチップ。name = 絵文字の :名前:
  ///
  /// In ja, this message translates to:
  /// **'{name} を外す'**
  String quickPickSettingsRemove(String name);

  /// No description provided for @quickPickSettingsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'絵文字がありません。パネルには最近使った絵文字だけが並びます'**
  String get quickPickSettingsEmpty;

  /// RAi のモード: 操作を教える(RAi がボタンまで移動して指差す)
  ///
  /// In ja, this message translates to:
  /// **'インストラクション'**
  String get raiModeInstruction;

  /// RAi のモード: 端末内モデルで答える
  ///
  /// In ja, this message translates to:
  /// **'アシスタント'**
  String get raiModeAssistant;

  /// 一時停止した案内に操作の名前が無いときの題
  ///
  /// In ja, this message translates to:
  /// **'案内'**
  String get raiGuideDefaultTitle;

  /// 保留した関数の「やめる」。calls は「 / 」区切りの関数の呼び出し
  ///
  /// In ja, this message translates to:
  /// **'実行しませんでした({calls})'**
  String raiHeldDeclined(String calls);

  /// No description provided for @raiAutoDeclined.
  ///
  /// In ja, this message translates to:
  /// **'わかりました。「{title}」は案内で進めるときに「この手順で案内」を押してください'**
  String raiAutoDeclined(String title);

  /// No description provided for @raiAutoProgress.
  ///
  /// In ja, this message translates to:
  /// **'自動で進めています({step} / {total}): {text}'**
  String raiAutoProgress(int step, int total, String text);

  /// 工程の手順の注記(入力の選択待ち)。label は入力のラベル(「RASQ リスト」など)
  ///
  /// In ja, this message translates to:
  /// **'{label} を選ぶ'**
  String raiAutoAskingDetail(String label);

  /// No description provided for @raiAutoAskDestination.
  ///
  /// In ja, this message translates to:
  /// **'「{title}」の取り込み先はどれにしますか？'**
  String raiAutoAskDestination(String title);

  /// label は入力の名前(フィード / RASQ リスト / ワードなど)
  ///
  /// In ja, this message translates to:
  /// **'{label} はどれにしますか？'**
  String raiAutoAskWhich(String label);

  /// No description provided for @raiAutoAskHint.
  ///
  /// In ja, this message translates to:
  /// **'候補から選ぶか、ほかの語を入れてください'**
  String get raiAutoAskHint;

  /// No description provided for @raiAutoNotFoundDetail.
  ///
  /// In ja, this message translates to:
  /// **'{label} が見つからない'**
  String raiAutoNotFoundDetail(String label);

  /// No description provided for @raiAutoNotFoundAsk.
  ///
  /// In ja, this message translates to:
  /// **'{label} が見つかりません。別の {label} で探しますか？'**
  String raiAutoNotFoundAsk(String label);

  /// No description provided for @raiAutoAskWhichCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{label} はどれにしますか？({count} 件)}}'**
  String raiAutoAskWhichCount(String label, int count);

  /// No description provided for @raiAutoCancelled.
  ///
  /// In ja, this message translates to:
  /// **'「{title}」の自動化をやめました'**
  String raiAutoCancelled(String title);

  /// No description provided for @raiAutoFailedAt.
  ///
  /// In ja, this message translates to:
  /// **'「{title}」の {step} 手順目で止まりました: {detail}'**
  String raiAutoFailedAt(String title, int step, String detail);

  /// No description provided for @raiAutoPartlyDone.
  ///
  /// In ja, this message translates to:
  /// **'{done, plural, other{{done} 手順を関数で進めました。{step} 手順目「{text}」からは押す部品があるので案内します}}'**
  String raiAutoPartlyDone(int done, int step, String text);

  /// このあとに「:」と結果の行が続くことがある
  ///
  /// In ja, this message translates to:
  /// **'「{title}」を関数で進めました'**
  String raiAutoDone(String title);

  /// No description provided for @raiInstructionUnknown.
  ///
  /// In ja, this message translates to:
  /// **'まだ覚えていない操作です。「投稿」「ログイン」「共有」などで聞いてみてください。'**
  String get raiInstructionUnknown;

  /// No description provided for @raiAskChoice.
  ///
  /// In ja, this message translates to:
  /// **'どれのことですか？ 上の選択肢から選んでください'**
  String get raiAskChoice;

  /// No description provided for @raiNoReply.
  ///
  /// In ja, this message translates to:
  /// **'返事がありませんでした'**
  String get raiNoReply;

  /// No description provided for @raiFailureDevice.
  ///
  /// In ja, this message translates to:
  /// **'端末内モデル: {message}'**
  String raiFailureDevice(String message);

  /// フォールアップ = 端末内モデルが答えられないときのサーバーの推論
  ///
  /// In ja, this message translates to:
  /// **'フォールアップ: {message}'**
  String raiFailureFallUp(String message);

  /// No description provided for @raiProposalReady.
  ///
  /// In ja, this message translates to:
  /// **'案内「{title}」を用意しました(下のタイルから始められます)'**
  String raiProposalReady(String title);

  /// No description provided for @raiProposalReadyStopAt.
  ///
  /// In ja, this message translates to:
  /// **'案内「{title}」を {step} 手順目まで進める用意をしました(下のタイルから)'**
  String raiProposalReadyStopAt(String title, int step);

  /// No description provided for @raiHeldNote.
  ///
  /// In ja, this message translates to:
  /// **'(取得した情報をもとにした操作は、確かめてから実行します: {calls})'**
  String raiHeldNote(String calls);

  /// No description provided for @raiNoReplyParen.
  ///
  /// In ja, this message translates to:
  /// **'(返事がありませんでした)'**
  String get raiNoReplyParen;

  /// No description provided for @raiRestartInjecting.
  ///
  /// In ja, this message translates to:
  /// **'取得した情報({keys})を注入してモデルを再始動します'**
  String raiRestartInjecting(String keys);

  /// 工程の手順の注記: 後ろの関数で済むので畳んだ手順
  ///
  /// In ja, this message translates to:
  /// **'関数で代替'**
  String get raiAutoDetailReplaced;

  /// No description provided for @raiAutoDetailNoFunction.
  ///
  /// In ja, this message translates to:
  /// **'関数の対応が無い'**
  String get raiAutoDetailNoFunction;

  /// No description provided for @raiAutoDetailGuideParts.
  ///
  /// In ja, this message translates to:
  /// **'押す部品は案内で'**
  String get raiAutoDetailGuideParts;

  /// No description provided for @raiAutoDetailExplanationOnly.
  ///
  /// In ja, this message translates to:
  /// **'説明だけ'**
  String get raiAutoDetailExplanationOnly;

  /// No description provided for @raiAutoDescribeNoBound.
  ///
  /// In ja, this message translates to:
  /// **'「{title}」は関数で代わりにできる手順が無いので、案内(指差し)で進めます。'**
  String raiAutoDescribeNoBound(String title);

  /// 承認タイルの説明の 1 行目。このあとに手順が 1 行ずつ続く
  ///
  /// In ja, this message translates to:
  /// **'「{title}」は案内を出さずに私が関数でやります:'**
  String raiAutoDescribeHead(String title);

  /// No description provided for @raiAutoDescribeGuideMark.
  ///
  /// In ja, this message translates to:
  /// **'(ここからは案内: {detail})'**
  String raiAutoDescribeGuideMark(String detail);

  /// 語を並べるときの区切り
  ///
  /// In ja, this message translates to:
  /// **'、'**
  String get raiListSeparator;

  /// inputs は「ラベル=値」の並び
  ///
  /// In ja, this message translates to:
  /// **'質問から: {inputs}'**
  String raiAutoDescribeFromQuestion(String inputs);

  /// No description provided for @raiAutoDescribeEntrusted.
  ///
  /// In ja, this message translates to:
  /// **'{labels} は候補の先頭で進めます(任されているので)'**
  String raiAutoDescribeEntrusted(String labels);

  /// No description provided for @raiAutoDescribeAskLater.
  ///
  /// In ja, this message translates to:
  /// **'{labels} は実行の途中で選んでもらいます'**
  String raiAutoDescribeAskLater(String labels);

  /// No description provided for @raiAutoDescribeConfirm.
  ///
  /// In ja, this message translates to:
  /// **'よければ「実行する」を押してください。'**
  String get raiAutoDescribeConfirm;

  /// アシスタントの提案の 1 行目。このあとに手順が 1 行ずつ続く
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{「{title}」なら、この順で進めます({count} 手順)}}'**
  String raiProposalHead(String title, int count);

  /// 手順の行の末尾の関数 id
  ///
  /// In ja, this message translates to:
  /// **'〔{function}〕'**
  String raiProposalFunction(String function);

  /// 先頭の空白も文言のうち
  ///
  /// In ja, this message translates to:
  /// **' 入力: {inputs}'**
  String raiProposalInputs(String inputs);

  /// 先頭の空白も文言のうち。presets は「名前=値」の空白区切り
  ///
  /// In ja, this message translates to:
  /// **' 固定: {presets}'**
  String raiProposalPresets(String presets);

  /// モードの切り替えの読み上げの名前
  ///
  /// In ja, this message translates to:
  /// **'RAi モード'**
  String get raiModeSemantics;

  /// No description provided for @raiAskButton.
  ///
  /// In ja, this message translates to:
  /// **'質問する'**
  String get raiAskButton;

  /// RAi の入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'困ったとき、お手伝いします！'**
  String get raiInputHint;

  /// 空の入力欄に薄く出す予測。prediction は予測した質問
  ///
  /// In ja, this message translates to:
  /// **'{prediction}(スペースで入力)'**
  String raiInputPredicted(String prediction);

  /// No description provided for @raiCollapse.
  ///
  /// In ja, this message translates to:
  /// **'畳む'**
  String get raiCollapse;

  /// No description provided for @raiExpand.
  ///
  /// In ja, this message translates to:
  /// **'広げる'**
  String get raiExpand;

  /// No description provided for @raiAskMore.
  ///
  /// In ja, this message translates to:
  /// **'さらに尋ねる'**
  String get raiAskMore;

  /// No description provided for @raiHistoryClose.
  ///
  /// In ja, this message translates to:
  /// **'履歴を閉じる'**
  String get raiHistoryClose;

  /// No description provided for @raiHistory.
  ///
  /// In ja, this message translates to:
  /// **'発言の履歴'**
  String get raiHistory;

  /// No description provided for @raiClose.
  ///
  /// In ja, this message translates to:
  /// **'RAi を閉じる'**
  String get raiClose;

  /// No description provided for @raiNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get raiNext;

  /// No description provided for @raiDone.
  ///
  /// In ja, this message translates to:
  /// **'了解(閉じる)'**
  String get raiDone;

  /// No description provided for @raiSpeechClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get raiSpeechClose;

  /// No description provided for @raiHistoryEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだ発言はありません'**
  String get raiHistoryEmpty;

  /// No description provided for @raiCopy.
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get raiCopy;

  /// No description provided for @raiCopied.
  ///
  /// In ja, this message translates to:
  /// **'コピーしました'**
  String get raiCopied;

  /// No description provided for @raiChatSuspended.
  ///
  /// In ja, this message translates to:
  /// **'案内を一時停止中({step} / {total} 手順目)。戻ると続きます。'**
  String raiChatSuspended(int step, int total);

  /// No description provided for @raiChatResume.
  ///
  /// In ja, this message translates to:
  /// **'続きへ'**
  String get raiChatResume;

  /// No description provided for @raiChatHeadline.
  ///
  /// In ja, this message translates to:
  /// **'マクロとか、お任せください！'**
  String get raiChatHeadline;

  /// No description provided for @raiChatIntro.
  ///
  /// In ja, this message translates to:
  /// **'操作を聞くと、RAi がボタンを指差して教えます。'**
  String get raiChatIntro;

  /// 開発者モードの詳しい説明
  ///
  /// In ja, this message translates to:
  /// **'インストラクション: 操作を聞くと RAi がボタンまで移動して指差します。\nアシスタント: 端末内モデルで答えます。モデルはバーのチップから選べます(マクロは第二期)。'**
  String get raiChatIntroDetail;

  /// No description provided for @raiChatRecent.
  ///
  /// In ja, this message translates to:
  /// **'最近の質問'**
  String get raiChatRecent;

  /// No description provided for @raiChatRejectCandidates.
  ///
  /// In ja, this message translates to:
  /// **'これじゃない(候補を外して答え直す)'**
  String get raiChatRejectCandidates;

  /// No description provided for @raiChatProposalTitle.
  ///
  /// In ja, this message translates to:
  /// **'{steps, plural, other{{title} · {steps} 手順}}'**
  String raiChatProposalTitle(String title, int steps);

  /// No description provided for @raiChatSkip.
  ///
  /// In ja, this message translates to:
  /// **'スキップ'**
  String get raiChatSkip;

  /// No description provided for @raiChatGuide.
  ///
  /// In ja, this message translates to:
  /// **'この手順で案内'**
  String get raiChatGuide;

  /// No description provided for @raiChatGuideTitle.
  ///
  /// In ja, this message translates to:
  /// **'案内「{title}」'**
  String raiChatGuideTitle(String title);

  /// No description provided for @raiChatTrace.
  ///
  /// In ja, this message translates to:
  /// **'工程'**
  String get raiChatTrace;

  /// No description provided for @raiChatShowGraph.
  ///
  /// In ja, this message translates to:
  /// **'グラフビューで表示'**
  String get raiChatShowGraph;

  /// No description provided for @raiChatApproveHeld.
  ///
  /// In ja, this message translates to:
  /// **'この操作を実行しますか？(取得した情報から出た操作です)'**
  String get raiChatApproveHeld;

  /// No description provided for @raiChatApprove.
  ///
  /// In ja, this message translates to:
  /// **'RAi に任せますか？'**
  String get raiChatApprove;

  /// No description provided for @raiChatDecline.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get raiChatDecline;

  /// No description provided for @raiChatRun.
  ///
  /// In ja, this message translates to:
  /// **'実行する'**
  String get raiChatRun;

  /// No description provided for @raiHomeSidebarSemantics.
  ///
  /// In ja, this message translates to:
  /// **'RAi サイドバー'**
  String get raiHomeSidebarSemantics;

  /// No description provided for @raiHomeClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get raiHomeClose;

  /// No description provided for @raiHomeNewConversation.
  ///
  /// In ja, this message translates to:
  /// **'新しい会話'**
  String get raiHomeNewConversation;

  /// No description provided for @raiHomeHistory.
  ///
  /// In ja, this message translates to:
  /// **'会話の履歴'**
  String get raiHomeHistory;

  /// No description provided for @raiHomeCurrentConversation.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{いまの会話 · {count} 件}}'**
  String raiHomeCurrentConversation(int count);

  /// when は会話を始めた日時(M/d HH:mm)
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{when} · {count} 件}}'**
  String raiHomeConversationSubtitle(String when, int count);

  /// No description provided for @raiHomeDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get raiHomeDelete;

  /// No description provided for @raiHomeHistoryEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだありません。質問すると、ここに会話が残ります。'**
  String get raiHomeHistoryEmpty;

  /// No description provided for @raiHomeOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get raiHomeOther;

  /// No description provided for @raiAchievementsTitle.
  ///
  /// In ja, this message translates to:
  /// **'アチーブメント'**
  String get raiAchievementsTitle;

  /// No description provided for @raiAchievementsProgress.
  ///
  /// In ja, this message translates to:
  /// **'{unlocked} / {total} 達成'**
  String raiAchievementsProgress(int unlocked, int total);

  /// No description provided for @raiHomeMacro.
  ///
  /// In ja, this message translates to:
  /// **'マクロ'**
  String get raiHomeMacro;

  /// No description provided for @raiHomeMacroSoon.
  ///
  /// In ja, this message translates to:
  /// **'準備中'**
  String get raiHomeMacroSoon;

  /// No description provided for @raiBarSemantics.
  ///
  /// In ja, this message translates to:
  /// **'RAi バー'**
  String get raiBarSemantics;

  /// No description provided for @raiAskCancel.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get raiAskCancel;

  /// No description provided for @raiAskInputHint.
  ///
  /// In ja, this message translates to:
  /// **'{label}を入れる'**
  String raiAskInputHint(String label);

  /// No description provided for @raiAskInputOtherHint.
  ///
  /// In ja, this message translates to:
  /// **'ほかの{label}を入れる'**
  String raiAskInputOtherHint(String label);

  /// No description provided for @raiAskDone.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get raiAskDone;

  /// No description provided for @raiAchievementsStats.
  ///
  /// In ja, this message translates to:
  /// **'インストラクション {instructions} 回 · アシスタント {assistant} 回(アプリの話 {app} 回)· 完走 {completed} 回 · 聞き直し {repeated} 回'**
  String raiAchievementsStats(
    int instructions,
    int assistant,
    int app,
    int completed,
    int repeated,
  );

  /// No description provided for @raiAchievementAsk1Title.
  ///
  /// In ja, this message translates to:
  /// **'はじめての質問'**
  String get raiAchievementAsk1Title;

  /// No description provided for @raiAchievementAsk1Description.
  ///
  /// In ja, this message translates to:
  /// **'インストラクションを 1 回聞いた'**
  String get raiAchievementAsk1Description;

  /// No description provided for @raiAchievementAsk10Title.
  ///
  /// In ja, this message translates to:
  /// **'聞き上手'**
  String get raiAchievementAsk10Title;

  /// No description provided for @raiAchievementAsk10Description.
  ///
  /// In ja, this message translates to:
  /// **'インストラクションを 10 回聞いた'**
  String get raiAchievementAsk10Description;

  /// No description provided for @raiAchievementAsk50Title.
  ///
  /// In ja, this message translates to:
  /// **'RAi の常連'**
  String get raiAchievementAsk50Title;

  /// No description provided for @raiAchievementAsk50Description.
  ///
  /// In ja, this message translates to:
  /// **'インストラクションを 50 回聞いた'**
  String get raiAchievementAsk50Description;

  /// No description provided for @raiAchievementApp5Title.
  ///
  /// In ja, this message translates to:
  /// **'アプリ通'**
  String get raiAchievementApp5Title;

  /// No description provided for @raiAchievementApp5Description.
  ///
  /// In ja, this message translates to:
  /// **'アシスタントとアプリについて 5 回話した'**
  String get raiAchievementApp5Description;

  /// No description provided for @raiAchievementChat20Title.
  ///
  /// In ja, this message translates to:
  /// **'おしゃべり'**
  String get raiAchievementChat20Title;

  /// No description provided for @raiAchievementChat20Description.
  ///
  /// In ja, this message translates to:
  /// **'アシスタントに 20 回話しかけた'**
  String get raiAchievementChat20Description;

  /// No description provided for @raiAchievementDone1Title.
  ///
  /// In ja, this message translates to:
  /// **'一発で完走'**
  String get raiAchievementDone1Title;

  /// No description provided for @raiAchievementDone1Description.
  ///
  /// In ja, this message translates to:
  /// **'案内を最後の手順まで進めた'**
  String get raiAchievementDone1Description;

  /// No description provided for @raiAchievementDone10Title.
  ///
  /// In ja, this message translates to:
  /// **'完走マスター'**
  String get raiAchievementDone10Title;

  /// No description provided for @raiAchievementDone10Description.
  ///
  /// In ja, this message translates to:
  /// **'案内を 10 回最後まで進めた'**
  String get raiAchievementDone10Description;

  /// No description provided for @raiAchievementAgain3Title.
  ///
  /// In ja, this message translates to:
  /// **'復習中'**
  String get raiAchievementAgain3Title;

  /// No description provided for @raiAchievementAgain3Description.
  ///
  /// In ja, this message translates to:
  /// **'同じ操作を 3 回聞き直した'**
  String get raiAchievementAgain3Description;

  /// No description provided for @raiAchievementAuto1Title.
  ///
  /// In ja, this message translates to:
  /// **'おまかせ'**
  String get raiAchievementAuto1Title;

  /// No description provided for @raiAchievementAuto1Description.
  ///
  /// In ja, this message translates to:
  /// **'「スキップ」で RAi に任せた'**
  String get raiAchievementAuto1Description;

  /// 工程グラフのノードの入力の名前
  ///
  /// In ja, this message translates to:
  /// **'前'**
  String get raiTracePortPrev;

  /// No description provided for @raiTracePortState.
  ///
  /// In ja, this message translates to:
  /// **'状態'**
  String get raiTracePortState;

  /// No description provided for @raiTracePortFunction.
  ///
  /// In ja, this message translates to:
  /// **'関数'**
  String get raiTracePortFunction;

  /// No description provided for @raiTracePortResult.
  ///
  /// In ja, this message translates to:
  /// **'結果'**
  String get raiTracePortResult;

  /// No description provided for @raiTracePortNext.
  ///
  /// In ja, this message translates to:
  /// **'次'**
  String get raiTracePortNext;

  /// No description provided for @raiTraceStatusDone.
  ///
  /// In ja, this message translates to:
  /// **'関数で済'**
  String get raiTraceStatusDone;

  /// No description provided for @raiTraceStatusSkipped.
  ///
  /// In ja, this message translates to:
  /// **'畳んだ'**
  String get raiTraceStatusSkipped;

  /// No description provided for @raiTraceStatusGuide.
  ///
  /// In ja, this message translates to:
  /// **'案内へ'**
  String get raiTraceStatusGuide;

  /// No description provided for @raiTraceStatusFailed.
  ///
  /// In ja, this message translates to:
  /// **'失敗'**
  String get raiTraceStatusFailed;

  /// No description provided for @raiTraceStatusAsking.
  ///
  /// In ja, this message translates to:
  /// **'選択待ち'**
  String get raiTraceStatusAsking;

  /// No description provided for @raiTraceStatusRunning.
  ///
  /// In ja, this message translates to:
  /// **'実行中'**
  String get raiTraceStatusRunning;

  /// No description provided for @raiTraceStatusPending.
  ///
  /// In ja, this message translates to:
  /// **'未実行'**
  String get raiTraceStatusPending;

  /// No description provided for @raiTraceCaption.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{工程 {count} 手順}}'**
  String raiTraceCaption(int count);

  /// No description provided for @raiDiagTitle.
  ///
  /// In ja, this message translates to:
  /// **'診断(開発者モード)'**
  String get raiDiagTitle;

  /// No description provided for @raiDiag3dOn.
  ///
  /// In ja, this message translates to:
  /// **'3D の RAi: 使う'**
  String get raiDiag3dOn;

  /// No description provided for @raiDiag3dOff.
  ///
  /// In ja, this message translates to:
  /// **'3D の RAi: 使わない(2D で表示)'**
  String get raiDiag3dOff;

  /// No description provided for @raiDiag3dOffAndroid.
  ///
  /// In ja, this message translates to:
  /// **'3D の RAi: 使わない(Android は既定で 2D。開発者モードの「3D の RAi を試す(Android)」でオン)'**
  String get raiDiag3dOffAndroid;

  /// reason は失敗の理由(英語のログの文のまま)
  ///
  /// In ja, this message translates to:
  /// **'3D の RAi: 失敗したので 2D に切り替えました({reason})'**
  String raiDiag3dFailed(String reason);

  /// phase は状態の名前(notInstalled など、そのまま)、message は理由
  ///
  /// In ja, this message translates to:
  /// **'端末内 LLM: {phase}({message})'**
  String raiDiagLlm(String phase, String message);

  /// phase は状態の名前(ready など、そのまま)、message は理由
  ///
  /// In ja, this message translates to:
  /// **'埋め込みモデル: {phase}({message})'**
  String raiDiagEmbedding(String phase, String message);

  /// No description provided for @raiDiagEmpty.
  ///
  /// In ja, this message translates to:
  /// **'記録された失敗はありません'**
  String get raiDiagEmpty;

  /// No description provided for @raiDiagRetry3d.
  ///
  /// In ja, this message translates to:
  /// **'3D をもう一度試す'**
  String get raiDiagRetry3d;

  /// RAi の関数 settings.get / set の結果(ユーザーにも注記で見える)。keys は「, 」区切りのある設定のキー
  ///
  /// In ja, this message translates to:
  /// **'「{area}」に「{key}」という設定はありません(ある: {keys})'**
  String raiFunctionsSettingMissing(String area, String key, String keys);

  /// No description provided for @raiFunctionsSettingNotWritable.
  ///
  /// In ja, this message translates to:
  /// **'「{key}」は画面から書ける設定ではありません'**
  String raiFunctionsSettingNotWritable(String key);

  /// No description provided for @raiFunctionsSettingNeedsPassword.
  ///
  /// In ja, this message translates to:
  /// **'「{key}」はパスワードが要るので RAi からは書きません'**
  String raiFunctionsSettingNeedsPassword(String key);

  /// No description provided for @raiFunctionsSettingLocked.
  ///
  /// In ja, this message translates to:
  /// **'「{key}」は操作禁止タグが付いているので RAi からは書きません'**
  String raiFunctionsSettingLocked(String key);

  /// 関数の取得結果の一覧が空のとき。head は一覧の見出し
  ///
  /// In ja, this message translates to:
  /// **'{head}: 該当なし'**
  String raiFunctionsFoldEmpty(String head);

  /// 関数の取得結果の一覧の見出し(このあとに 1 行ずつ続く)。total = 全件、shown = 載せた件数
  ///
  /// In ja, this message translates to:
  /// **'{total, plural, other{{head} {total} 件中 {shown} 件:}}'**
  String raiFunctionsFoldHead(String head, int total, int shown);

  /// name は関数の名前(posts.fetch など)
  ///
  /// In ja, this message translates to:
  /// **'この SNS では使えません({name})'**
  String raiFunctionsUnsupported(String name);

  /// No description provided for @raiFunctionsNotAutomatable.
  ///
  /// In ja, this message translates to:
  /// **'{name} は自動化不可です(送信はユーザーが押します)。代わりに {alt}: {result}'**
  String raiFunctionsNotAutomatable(String name, String alt, String result);

  /// No description provided for @raiFunctionsUnknown.
  ///
  /// In ja, this message translates to:
  /// **'知らない関数です: {name}'**
  String raiFunctionsUnknown(String name);

  /// No description provided for @raiFunctionsFailed.
  ///
  /// In ja, this message translates to:
  /// **'{name} に失敗: {error}'**
  String raiFunctionsFailed(String name, String error);

  /// No description provided for @raiFunctionsNotLoggedInSns.
  ///
  /// In ja, this message translates to:
  /// **'SNS にログインしていません'**
  String get raiFunctionsNotLoggedInSns;

  /// 投稿 1 行の末尾に付ける反応の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{(反応 {count})}}'**
  String raiFunctionsLineReactions(int count);

  /// No description provided for @raiFunctionsPostsNone.
  ///
  /// In ja, this message translates to:
  /// **'該当する投稿はありませんでした'**
  String get raiFunctionsPostsNone;

  /// No description provided for @raiFunctionsPostsHead.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{投稿 {count} 件({total} 件中):}}'**
  String raiFunctionsPostsHead(int count, int total);

  /// No description provided for @raiFunctionsReferenceOperation.
  ///
  /// In ja, this message translates to:
  /// **'操作「{title}」({id}): {steps}'**
  String raiFunctionsReferenceOperation(String title, String id, String steps);

  /// No description provided for @raiFunctionsReferenceFunction.
  ///
  /// In ja, this message translates to:
  /// **'関数 {id}: {does}'**
  String raiFunctionsReferenceFunction(String id, String does);

  /// 先頭の空白も文言のうち
  ///
  /// In ja, this message translates to:
  /// **' 引数: {params}'**
  String raiFunctionsReferenceParams(String params);

  /// No description provided for @raiFunctionsReferenceParamInput.
  ///
  /// In ja, this message translates to:
  /// **'入力'**
  String get raiFunctionsReferenceParamInput;

  /// No description provided for @raiFunctionsReferenceParamFixed.
  ///
  /// In ja, this message translates to:
  /// **'固定={value}'**
  String raiFunctionsReferenceParamFixed(String value);

  /// No description provided for @raiFunctionsReferenceMissing.
  ///
  /// In ja, this message translates to:
  /// **'リファレンスに {id} はありません'**
  String raiFunctionsReferenceMissing(String id);

  /// No description provided for @raiFunctionsActionMissing.
  ///
  /// In ja, this message translates to:
  /// **'アクション {id} はありません'**
  String raiFunctionsActionMissing(String id);

  /// No description provided for @raiFunctionsActionNotAllowed.
  ///
  /// In ja, this message translates to:
  /// **'「{label}」は自動化が許可されていません(RAi からは実行しません)。代わりに案内(この手順で案内)で進めるか、ユーザーが押してください'**
  String raiFunctionsActionNotAllowed(String label);

  /// state は「済」か「未」
  ///
  /// In ja, this message translates to:
  /// **'{label} を実行しました({state})'**
  String raiFunctionsActionDone(String label, String state);

  /// No description provided for @raiFunctionsActionDoneYes.
  ///
  /// In ja, this message translates to:
  /// **'済'**
  String get raiFunctionsActionDoneYes;

  /// No description provided for @raiFunctionsActionDoneNo.
  ///
  /// In ja, this message translates to:
  /// **'未'**
  String get raiFunctionsActionDoneNo;

  /// No description provided for @raiFunctionsAstellNoRooms.
  ///
  /// In ja, this message translates to:
  /// **'ASTell のルームはありません'**
  String get raiFunctionsAstellNoRooms;

  /// No description provided for @raiFunctionsAstellRooms.
  ///
  /// In ja, this message translates to:
  /// **'ASTell のルーム: {rooms}'**
  String raiFunctionsAstellRooms(String rooms);

  /// No description provided for @raiFunctionsAstellNoTitle.
  ///
  /// In ja, this message translates to:
  /// **'題名がありません'**
  String get raiFunctionsAstellNoTitle;

  /// No description provided for @raiFunctionsAstellCreated.
  ///
  /// In ja, this message translates to:
  /// **'ASTell「{title}」を作りました [{id}]'**
  String raiFunctionsAstellCreated(String title, String id);

  /// reaction は「(絵文字)」か空
  ///
  /// In ja, this message translates to:
  /// **'{who} がリアクション{reaction}'**
  String raiFunctionsNotifReaction(String who, String reaction);

  /// No description provided for @raiFunctionsNotifRepost.
  ///
  /// In ja, this message translates to:
  /// **'{who} がリノート'**
  String raiFunctionsNotifRepost(String who);

  /// No description provided for @raiFunctionsNotifQuote.
  ///
  /// In ja, this message translates to:
  /// **'{who} が引用'**
  String raiFunctionsNotifQuote(String who);

  /// No description provided for @raiFunctionsNotifReply.
  ///
  /// In ja, this message translates to:
  /// **'{who} が返信'**
  String raiFunctionsNotifReply(String who);

  /// No description provided for @raiFunctionsNotifMention.
  ///
  /// In ja, this message translates to:
  /// **'{who} がメンション'**
  String raiFunctionsNotifMention(String who);

  /// No description provided for @raiFunctionsNotifFollow.
  ///
  /// In ja, this message translates to:
  /// **'{who} がフォロー'**
  String raiFunctionsNotifFollow(String who);

  /// No description provided for @raiFunctionsNotifFollowRequest.
  ///
  /// In ja, this message translates to:
  /// **'{who} がフォロー申請'**
  String raiFunctionsNotifFollowRequest(String who);

  /// No description provided for @raiFunctionsNotifFollowAccepted.
  ///
  /// In ja, this message translates to:
  /// **'{who} がフォロー承認'**
  String raiFunctionsNotifFollowAccepted(String who);

  /// No description provided for @raiFunctionsNotifListAdded.
  ///
  /// In ja, this message translates to:
  /// **'{who} がリストに追加'**
  String raiFunctionsNotifListAdded(String who);

  /// No description provided for @raiFunctionsNotifPollEnded.
  ///
  /// In ja, this message translates to:
  /// **'アンケート終了'**
  String get raiFunctionsNotifPollEnded;

  /// No description provided for @raiFunctionsNotifTimer.
  ///
  /// In ja, this message translates to:
  /// **'タイマー通知'**
  String get raiFunctionsNotifTimer;

  /// No description provided for @raiFunctionsNotifVc.
  ///
  /// In ja, this message translates to:
  /// **'ASTell 通知'**
  String get raiFunctionsNotifVc;

  /// No description provided for @raiFunctionsNotifSystem.
  ///
  /// In ja, this message translates to:
  /// **'システム通知'**
  String get raiFunctionsNotifSystem;

  /// No description provided for @raiFunctionsNotifOther.
  ///
  /// In ja, this message translates to:
  /// **'その他の通知'**
  String get raiFunctionsNotifOther;

  /// No description provided for @raiFunctionsUnreadMark.
  ///
  /// In ja, this message translates to:
  /// **'(未読)'**
  String get raiFunctionsUnreadMark;

  /// No description provided for @raiFunctionsMissingPostId.
  ///
  /// In ja, this message translates to:
  /// **'投稿 id (id=) がありません'**
  String get raiFunctionsMissingPostId;

  /// No description provided for @raiFunctionsMissingPostArg.
  ///
  /// In ja, this message translates to:
  /// **'投稿 id (post=) がありません'**
  String get raiFunctionsMissingPostArg;

  /// No description provided for @raiFunctionsThreadReply.
  ///
  /// In ja, this message translates to:
  /// **'返信: {line}'**
  String raiFunctionsThreadReply(String line);

  /// No description provided for @raiFunctionsHeadThread.
  ///
  /// In ja, this message translates to:
  /// **'スレッド'**
  String get raiFunctionsHeadThread;

  /// No description provided for @raiFunctionsHeadReactions.
  ///
  /// In ja, this message translates to:
  /// **'反応'**
  String get raiFunctionsHeadReactions;

  /// No description provided for @raiFunctionsHeadReposters.
  ///
  /// In ja, this message translates to:
  /// **'リノートした人'**
  String get raiFunctionsHeadReposters;

  /// No description provided for @raiFunctionsHeadQuotes.
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get raiFunctionsHeadQuotes;

  /// No description provided for @raiFunctionsHeadFavorites.
  ///
  /// In ja, this message translates to:
  /// **'お気に入り'**
  String get raiFunctionsHeadFavorites;

  /// No description provided for @raiFunctionsHeadReacted.
  ///
  /// In ja, this message translates to:
  /// **'リアクション済み'**
  String get raiFunctionsHeadReacted;

  /// No description provided for @raiFunctionsMe.
  ///
  /// In ja, this message translates to:
  /// **'自分: {user} プラグイン={plugin}'**
  String raiFunctionsMe(String user, String plugin);

  /// No description provided for @raiFunctionsUserIdOrHandle.
  ///
  /// In ja, this message translates to:
  /// **'id= か handle= を指定してください'**
  String get raiFunctionsUserIdOrHandle;

  /// No description provided for @raiFunctionsNotFound.
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした'**
  String get raiFunctionsNotFound;

  /// 先頭の空白も文言のうち。数が分からなければ ?
  ///
  /// In ja, this message translates to:
  /// **' フォロワー{followers} フォロー{following}'**
  String raiFunctionsUserCounts(String followers, String following);

  /// No description provided for @raiFunctionsMissingUser.
  ///
  /// In ja, this message translates to:
  /// **'user id (user=) がありません'**
  String get raiFunctionsMissingUser;

  /// No description provided for @raiFunctionsHeadUserPosts.
  ///
  /// In ja, this message translates to:
  /// **'投稿({filter})'**
  String raiFunctionsHeadUserPosts(String filter);

  /// No description provided for @raiFunctionsMissingKeyword.
  ///
  /// In ja, this message translates to:
  /// **'keyword がありません'**
  String get raiFunctionsMissingKeyword;

  /// No description provided for @raiFunctionsHeadUserSearch.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー検索「{keyword}」'**
  String raiFunctionsHeadUserSearch(String keyword);

  /// No description provided for @raiFunctionsHeadFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get raiFunctionsHeadFollowing;

  /// No description provided for @raiFunctionsHeadFollowers.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get raiFunctionsHeadFollowers;

  /// No description provided for @raiFunctionsRelFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get raiFunctionsRelFollowing;

  /// No description provided for @raiFunctionsRelFollowedBy.
  ///
  /// In ja, this message translates to:
  /// **'フォローされています'**
  String get raiFunctionsRelFollowedBy;

  /// No description provided for @raiFunctionsRelRequested.
  ///
  /// In ja, this message translates to:
  /// **'申請中'**
  String get raiFunctionsRelRequested;

  /// No description provided for @raiFunctionsRelMuted.
  ///
  /// In ja, this message translates to:
  /// **'ミュート中'**
  String get raiFunctionsRelMuted;

  /// No description provided for @raiFunctionsRelBlocked.
  ///
  /// In ja, this message translates to:
  /// **'ブロック中'**
  String get raiFunctionsRelBlocked;

  /// No description provided for @raiFunctionsRelBlockedBy.
  ///
  /// In ja, this message translates to:
  /// **'ブロックされています'**
  String get raiFunctionsRelBlockedBy;

  /// No description provided for @raiFunctionsRelNone.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get raiFunctionsRelNone;

  /// No description provided for @raiFunctionsRelation.
  ///
  /// In ja, this message translates to:
  /// **'関係: {flags}'**
  String raiFunctionsRelation(String flags);

  /// No description provided for @raiFunctionsRequestLine.
  ///
  /// In ja, this message translates to:
  /// **'{user} [申請 {id}]'**
  String raiFunctionsRequestLine(String user, String id);

  /// No description provided for @raiFunctionsHeadModeration.
  ///
  /// In ja, this message translates to:
  /// **'モデレーション({kind})'**
  String raiFunctionsHeadModeration(String kind);

  /// No description provided for @raiFunctionsHeadNotifications.
  ///
  /// In ja, this message translates to:
  /// **'{unread, plural, other{通知(未読 {unread} 件)}}'**
  String raiFunctionsHeadNotifications(int unread);

  /// No description provided for @raiFunctionsNotificationsRead.
  ///
  /// In ja, this message translates to:
  /// **'通知を既読にしました'**
  String get raiFunctionsNotificationsRead;

  /// No description provided for @raiFunctionsTrendLine.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{tag}({count} 人)}}'**
  String raiFunctionsTrendLine(String tag, int count);

  /// No description provided for @raiFunctionsHeadTrends.
  ///
  /// In ja, this message translates to:
  /// **'トレンド'**
  String get raiFunctionsHeadTrends;

  /// No description provided for @raiFunctionsListLine.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{name} [{id}]({count} 人)}}'**
  String raiFunctionsListLine(String name, String id, int count);

  /// No description provided for @raiFunctionsHeadLists.
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get raiFunctionsHeadLists;

  /// No description provided for @raiFunctionsMissingList.
  ///
  /// In ja, this message translates to:
  /// **'list id (list=) がありません'**
  String get raiFunctionsMissingList;

  /// No description provided for @raiFunctionsHeadListMembers.
  ///
  /// In ja, this message translates to:
  /// **'リストのメンバー'**
  String get raiFunctionsHeadListMembers;

  /// No description provided for @raiFunctionsClipCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{({count} 件)}}'**
  String raiFunctionsClipCount(int count);

  /// No description provided for @raiFunctionsHeadClips.
  ///
  /// In ja, this message translates to:
  /// **'クリップ'**
  String get raiFunctionsHeadClips;

  /// No description provided for @raiFunctionsMissingClip.
  ///
  /// In ja, this message translates to:
  /// **'clip id (clip=) がありません'**
  String get raiFunctionsMissingClip;

  /// No description provided for @raiFunctionsHeadClipNotes.
  ///
  /// In ja, this message translates to:
  /// **'クリップの中身'**
  String get raiFunctionsHeadClipNotes;

  /// No description provided for @raiFunctionsHeadFeeds.
  ///
  /// In ja, this message translates to:
  /// **'フィード'**
  String get raiFunctionsHeadFeeds;

  /// No description provided for @raiFunctionsDmUnread.
  ///
  /// In ja, this message translates to:
  /// **'(未読 {count})'**
  String raiFunctionsDmUnread(int count);

  /// No description provided for @raiFunctionsHeadEmoji.
  ///
  /// In ja, this message translates to:
  /// **'絵文字「{keyword}」'**
  String raiFunctionsHeadEmoji(String keyword);

  /// No description provided for @raiFunctionsUnfollowed.
  ///
  /// In ja, this message translates to:
  /// **'フォローを外しました'**
  String get raiFunctionsUnfollowed;

  /// No description provided for @raiFunctionsFollowRequested.
  ///
  /// In ja, this message translates to:
  /// **'フォロー申請しました'**
  String get raiFunctionsFollowRequested;

  /// No description provided for @raiFunctionsFollowed.
  ///
  /// In ja, this message translates to:
  /// **'フォローしました'**
  String get raiFunctionsFollowed;

  /// No description provided for @raiFunctionsListUserArgs.
  ///
  /// In ja, this message translates to:
  /// **'list= と user= を指定してください'**
  String get raiFunctionsListUserArgs;

  /// No description provided for @raiFunctionsListAdded.
  ///
  /// In ja, this message translates to:
  /// **'リストに追加しました'**
  String get raiFunctionsListAdded;

  /// No description provided for @raiFunctionsListRemoved.
  ///
  /// In ja, this message translates to:
  /// **'リストから外しました'**
  String get raiFunctionsListRemoved;

  /// No description provided for @raiFunctionsMissingName.
  ///
  /// In ja, this message translates to:
  /// **'名前 (name=) がありません'**
  String get raiFunctionsMissingName;

  /// No description provided for @raiFunctionsListCreated.
  ///
  /// In ja, this message translates to:
  /// **'リスト「{name}」を作りました [{id}]'**
  String raiFunctionsListCreated(String name, String id);

  /// No description provided for @raiFunctionsClipPostArgs.
  ///
  /// In ja, this message translates to:
  /// **'clip= と post= を指定してください'**
  String get raiFunctionsClipPostArgs;

  /// No description provided for @raiFunctionsClipAdded.
  ///
  /// In ja, this message translates to:
  /// **'クリップに追加しました'**
  String get raiFunctionsClipAdded;

  /// No description provided for @raiFunctionsClipRemoved.
  ///
  /// In ja, this message translates to:
  /// **'クリップから外しました'**
  String get raiFunctionsClipRemoved;

  /// No description provided for @raiFunctionsClipCreated.
  ///
  /// In ja, this message translates to:
  /// **'クリップ「{name}」を作りました [{id}]'**
  String raiFunctionsClipCreated(String name, String id);

  /// No description provided for @raiFunctionsAreaKeyArgs.
  ///
  /// In ja, this message translates to:
  /// **'area= と key= を指定してください'**
  String get raiFunctionsAreaKeyArgs;

  /// No description provided for @raiFunctionsSettingsPageMissing.
  ///
  /// In ja, this message translates to:
  /// **'設定ページ「{area}」はありません'**
  String raiFunctionsSettingsPageMissing(String area);

  /// No description provided for @raiFunctionsAreaKeyValueArgs.
  ///
  /// In ja, this message translates to:
  /// **'area= と key= と value= を指定してください'**
  String get raiFunctionsAreaKeyValueArgs;

  /// No description provided for @raiFunctionsSettingBadValue.
  ///
  /// In ja, this message translates to:
  /// **'「{key}」に「{value}」は入れられません(今の値: {current})'**
  String raiFunctionsSettingBadValue(String key, String value, String current);

  /// No description provided for @raiFunctionsSettingSet.
  ///
  /// In ja, this message translates to:
  /// **'{area}.{key} を {value} にしました'**
  String raiFunctionsSettingSet(String area, String key, String value);

  /// No description provided for @raiFunctionsMissingText.
  ///
  /// In ja, this message translates to:
  /// **'本文(text=)がありません'**
  String get raiFunctionsMissingText;

  /// No description provided for @raiFunctionsMissingRoom.
  ///
  /// In ja, this message translates to:
  /// **'ルーム id (room=) がありません'**
  String get raiFunctionsMissingRoom;

  /// No description provided for @raiFunctionsDmRoomMissing.
  ///
  /// In ja, this message translates to:
  /// **'DM ルーム {id} はありません'**
  String raiFunctionsDmRoomMissing(String id);

  /// target はコンポーザーの題(返信 / 引用など)
  ///
  /// In ja, this message translates to:
  /// **'{target}の下書きをコンポーザーに入れました(送信はしていません)'**
  String raiFunctionsComposeFilled(String target);

  /// No description provided for @raiFunctionsFeedNotFound.
  ///
  /// In ja, this message translates to:
  /// **'フィード「{feed}」が見つかりません'**
  String raiFunctionsFeedNotFound(String feed);

  /// No description provided for @raiFunctionsFeedSaved.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{「{name}」を保存しました(保存済み {count} 件)}}'**
  String raiFunctionsFeedSaved(String name, int count);

  /// No description provided for @raiFunctionsFeedUnsaved.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{「{name}」を保存から外しました(保存済み {count} 件)}}'**
  String raiFunctionsFeedUnsaved(String name, int count);

  /// No description provided for @raiFunctionsNoBluesky.
  ///
  /// In ja, this message translates to:
  /// **'Bluesky のアカウントがありません(カスタムフィードは Bluesky のみ)'**
  String get raiFunctionsNoBluesky;

  /// No description provided for @raiFunctionsFeedAlreadyHome.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」はもうホームのタイムラインに入っています'**
  String raiFunctionsFeedAlreadyHome(String name);

  /// No description provided for @raiFunctionsFeedAddedHome.
  ///
  /// In ja, this message translates to:
  /// **'「{name}」({account})をホームのタイムラインに取り込みました'**
  String raiFunctionsFeedAddedHome(String name, String account);

  /// No description provided for @raiFunctionsNotLoggedInRasq.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインしていません'**
  String get raiFunctionsNotLoggedInRasq;

  /// No description provided for @raiFunctionsRasqListMine.
  ///
  /// In ja, this message translates to:
  /// **'自分'**
  String get raiFunctionsRasqListMine;

  /// No description provided for @raiFunctionsRasqListUnfetchable.
  ///
  /// In ja, this message translates to:
  /// **'取り込めない'**
  String get raiFunctionsRasqListUnfetchable;

  /// No description provided for @raiFunctionsRasqListFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get raiFunctionsRasqListFollowing;

  /// このあとに「 — 説明」と「 [id]」が続く
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{name}({count}人・{state})}}'**
  String raiFunctionsRasqListLine(String name, int count, String state);

  /// No description provided for @raiFunctionsHeadRasqLists.
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト'**
  String get raiFunctionsHeadRasqLists;

  /// No description provided for @raiFunctionsMissingListArg.
  ///
  /// In ja, this message translates to:
  /// **'リスト(list=)がありません'**
  String get raiFunctionsMissingListArg;

  /// No description provided for @raiFunctionsRasqListNotFound.
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト「{query}」が見つかりません'**
  String raiFunctionsRasqListNotFound(String query);

  /// No description provided for @raiFunctionsMissingWord.
  ///
  /// In ja, this message translates to:
  /// **'ワード(word=)がありません'**
  String get raiFunctionsMissingWord;

  /// No description provided for @raiFunctionsNotLoggedIn.
  ///
  /// In ja, this message translates to:
  /// **'ログインしていません'**
  String get raiFunctionsNotLoggedIn;

  /// No description provided for @raiFunctionsWordExcludeAlready.
  ///
  /// In ja, this message translates to:
  /// **'「{word}」の除外はもう入っています'**
  String raiFunctionsWordExcludeAlready(String word);

  /// No description provided for @raiFunctionsWordIncludeAlready.
  ///
  /// In ja, this message translates to:
  /// **'「{word}」の絞り込みはもう入っています'**
  String raiFunctionsWordIncludeAlready(String word);

  /// scope は home / social / local / global
  ///
  /// In ja, this message translates to:
  /// **'「{word}」を含む投稿を {scope} のタイムラインから除外するようにしました'**
  String raiFunctionsWordExcluded(String word, String scope);

  /// No description provided for @raiFunctionsWordIncluded.
  ///
  /// In ja, this message translates to:
  /// **'「{word}」を含む投稿だけを {scope} のタイムラインに通すようにしました'**
  String raiFunctionsWordIncluded(String word, String scope);

  /// No description provided for @raiFunctionsFeedKindLabel.
  ///
  /// In ja, this message translates to:
  /// **'フィード'**
  String get raiFunctionsFeedKindLabel;

  /// No description provided for @raiFunctionsHeadFeedTimeline.
  ///
  /// In ja, this message translates to:
  /// **'フィード TL'**
  String get raiFunctionsHeadFeedTimeline;

  /// No description provided for @raiFunctionsPageList.
  ///
  /// In ja, this message translates to:
  /// **'リスト {name} [{id}]'**
  String raiFunctionsPageList(String name, String id);

  /// No description provided for @raiFunctionsPageFeed.
  ///
  /// In ja, this message translates to:
  /// **'フィード {name} [{uri}]'**
  String raiFunctionsPageFeed(String name, String uri);

  /// No description provided for @raiFunctionsHeadListsPage.
  ///
  /// In ja, this message translates to:
  /// **'リストページ'**
  String get raiFunctionsHeadListsPage;

  /// No description provided for @raiFunctionsHeadNotificationsPage.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get raiFunctionsHeadNotificationsPage;

  /// No description provided for @raiFunctionsHeadHomeTimeline.
  ///
  /// In ja, this message translates to:
  /// **'ホーム TL'**
  String get raiFunctionsHeadHomeTimeline;

  /// No description provided for @raiFunctionsMissingSource.
  ///
  /// In ja, this message translates to:
  /// **'取り込み元(source=)がありません'**
  String get raiFunctionsMissingSource;

  /// No description provided for @raiFunctionsSeedNoPosts.
  ///
  /// In ja, this message translates to:
  /// **'「{label}」に投稿が無いので特徴語を取れません'**
  String raiFunctionsSeedNoPosts(String label);

  /// No description provided for @raiFunctionsSeedNoWords.
  ///
  /// In ja, this message translates to:
  /// **'「{label}」から特徴語を取れませんでした'**
  String raiFunctionsSeedNoWords(String label);

  /// No description provided for @raiFunctionsSeedWordSeparator.
  ///
  /// In ja, this message translates to:
  /// **'、'**
  String get raiFunctionsSeedWordSeparator;

  /// No description provided for @raiFunctionsSeedAdded.
  ///
  /// In ja, this message translates to:
  /// **'「{label}」の特徴語({words})をトレンドの指向性(好きなジャンル)に足しました'**
  String raiFunctionsSeedAdded(String label, String words);

  /// No description provided for @raiFunctionsMissingQuery.
  ///
  /// In ja, this message translates to:
  /// **'検索語(q=)がありません'**
  String get raiFunctionsMissingQuery;

  /// No description provided for @raiFunctionsHeadWeb.
  ///
  /// In ja, this message translates to:
  /// **'web「{query}」'**
  String raiFunctionsHeadWeb(String query);

  /// No description provided for @raiFunctionsNotAutomatableMark.
  ///
  /// In ja, this message translates to:
  /// **'(自動化不可)'**
  String get raiFunctionsNotAutomatableMark;

  /// No description provided for @raiFunctionsHeadActions.
  ///
  /// In ja, this message translates to:
  /// **'アクション'**
  String get raiFunctionsHeadActions;

  /// RAi のモデルを選ぶ FOW の題
  ///
  /// In ja, this message translates to:
  /// **'モデル'**
  String get raiModelsTitle;

  /// No description provided for @raiModelsClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get raiModelsClose;

  /// No description provided for @raiModelsRamUnknown.
  ///
  /// In ja, this message translates to:
  /// **'RAM: 不明'**
  String get raiModelsRamUnknown;

  /// gb は小数 1 桁の空きメモリ
  ///
  /// In ja, this message translates to:
  /// **'(空き {gb} GB)'**
  String raiModelsRamFree(String gb);

  /// ram は「RAM: 8.0 GB(空き …)」の文
  ///
  /// In ja, this message translates to:
  /// **'{codename} = この端末で動くモデル。{ram}'**
  String raiModelsCaption(String codename, String ram);

  /// 開発者モードの詳しい説明
  ///
  /// In ja, this message translates to:
  /// **'{codename} = 端末内で動くモデル({label})。{ram}'**
  String raiModelsCaptionDetail(String codename, String label, String ram);

  /// No description provided for @raiModelsSectionLocal.
  ///
  /// In ja, this message translates to:
  /// **'ローカル'**
  String get raiModelsSectionLocal;

  /// No description provided for @raiModelsSectionEmbedding.
  ///
  /// In ja, this message translates to:
  /// **'RAi の検索と投稿の埋め込み'**
  String get raiModelsSectionEmbedding;

  /// No description provided for @raiModelsPostVisionReady.
  ///
  /// In ja, this message translates to:
  /// **'関連 TL と TL のアルゴリズムで、投稿の画像も比べます'**
  String get raiModelsPostVisionReady;

  /// No description provided for @raiModelsPostVisionIdle.
  ///
  /// In ja, this message translates to:
  /// **'関連 TL と TL のアルゴリズムで、投稿の本文に加えて画像も比べられるようになります(文のモデルも入れてください)'**
  String get raiModelsPostVisionIdle;

  /// No description provided for @raiModelsSectionEmoji.
  ///
  /// In ja, this message translates to:
  /// **'絵文字の画像検索(2 つとも要ります)'**
  String get raiModelsSectionEmoji;

  /// No description provided for @raiModelsEmojiTextReady.
  ///
  /// In ja, this message translates to:
  /// **'打った文で、絵文字の絵を探せます'**
  String get raiModelsEmojiTextReady;

  /// No description provided for @raiModelsEmojiTextIdle.
  ///
  /// In ja, this message translates to:
  /// **'絵文字の絵を、意味で探せるようになります(画像側も入れてください)'**
  String get raiModelsEmojiTextIdle;

  /// No description provided for @raiModelsEmojiVisionReady.
  ///
  /// In ja, this message translates to:
  /// **'絵文字の絵を、裏で少しずつ読み込みます(サーバーごとに 1 回)'**
  String get raiModelsEmojiVisionReady;

  /// No description provided for @raiModelsEmojiVisionIdle.
  ///
  /// In ja, this message translates to:
  /// **'名前が意味を持たない絵文字も、絵の中身で探せるようになります'**
  String get raiModelsEmojiVisionIdle;

  /// No description provided for @raiModelsSectionCloud.
  ///
  /// In ja, this message translates to:
  /// **'クラウド(端末で答えられないとき)'**
  String get raiModelsSectionCloud;

  /// No description provided for @raiModelsCompletionCaption.
  ///
  /// In ja, this message translates to:
  /// **'完遂率 = 案内や返答が最後までうまくいった割合です。'**
  String get raiModelsCompletionCaption;

  /// 開発者モードの詳しい説明
  ///
  /// In ja, this message translates to:
  /// **'完遂率 = 操作の案内 / 返答が最後まで成立した割合の集計(35B 未満のモデルだけ集計、デモでは「-%」)。'**
  String get raiModelsCompletionCaptionDetail;

  /// No description provided for @raiModelsRateExcluded.
  ///
  /// In ja, this message translates to:
  /// **'集計外'**
  String get raiModelsRateExcluded;

  /// No description provided for @raiModelsNotConnected.
  ///
  /// In ja, this message translates to:
  /// **'未接続'**
  String get raiModelsNotConnected;

  /// No description provided for @raiModelsPhaseNotInstalled.
  ///
  /// In ja, this message translates to:
  /// **'未ダウンロード'**
  String get raiModelsPhaseNotInstalled;

  /// No description provided for @raiModelsPhaseDownloading.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード中 {percent}%'**
  String raiModelsPhaseDownloading(int percent);

  /// No description provided for @raiModelsPhaseReady.
  ///
  /// In ja, this message translates to:
  /// **'準備完了'**
  String get raiModelsPhaseReady;

  /// アプリに同梱した埋め込みモデル(RASQ MiniLM)を使っているときの状態
  ///
  /// In ja, this message translates to:
  /// **'準備完了(同梱)'**
  String get raiModelsPhaseReadyBundled;

  /// No description provided for @raiModelsPhaseLoading.
  ///
  /// In ja, this message translates to:
  /// **'読み込み中'**
  String get raiModelsPhaseLoading;

  /// No description provided for @raiModelsPhaseGenerating.
  ///
  /// In ja, this message translates to:
  /// **'生成中'**
  String get raiModelsPhaseGenerating;

  /// No description provided for @raiModelsPhaseUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'使えません'**
  String get raiModelsPhaseUnavailable;

  /// No description provided for @raiModelsPillCloud.
  ///
  /// In ja, this message translates to:
  /// **'クラウド'**
  String get raiModelsPillCloud;

  /// No description provided for @raiModelsPillLocal.
  ///
  /// In ja, this message translates to:
  /// **'ローカル'**
  String get raiModelsPillLocal;

  /// No description provided for @raiModelsCloudLine.
  ///
  /// In ja, this message translates to:
  /// **'{label} · {params}B · クラウド'**
  String raiModelsCloudLine(String label, String params);

  /// No description provided for @raiModelsCompletionRate.
  ///
  /// In ja, this message translates to:
  /// **'完遂率 {rate}'**
  String raiModelsCompletionRate(String rate);

  /// No description provided for @raiModelsMemoryNotNeeded.
  ///
  /// In ja, this message translates to:
  /// **'メモリ: 端末不要'**
  String get raiModelsMemoryNotNeeded;

  /// No description provided for @raiModelsMemory.
  ///
  /// In ja, this message translates to:
  /// **'メモリ: {verdict}'**
  String raiModelsMemory(String verdict);

  /// No description provided for @raiModelsUse.
  ///
  /// In ja, this message translates to:
  /// **'使う'**
  String get raiModelsUse;

  /// No description provided for @raiModelsExtract.
  ///
  /// In ja, this message translates to:
  /// **'展開(同梱)'**
  String get raiModelsExtract;

  /// No description provided for @raiModelsDownload.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロード'**
  String get raiModelsDownload;

  /// No description provided for @raiModelsRelease.
  ///
  /// In ja, this message translates to:
  /// **'メモリを解放'**
  String get raiModelsRelease;

  /// No description provided for @raiModelsDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'モデルを削除しますか'**
  String get raiModelsDeleteTitle;

  /// No description provided for @raiModelsDeleteMessage.
  ///
  /// In ja, this message translates to:
  /// **'{file} を端末から消します。'**
  String raiModelsDeleteMessage(String file);

  /// No description provided for @raiModelsDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get raiModelsDelete;

  /// No description provided for @raiModelsCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get raiModelsCancel;

  /// No description provided for @raiModelsEmbeddingLine.
  ///
  /// In ja, this message translates to:
  /// **'onnxruntime · {file} · 約 {size} MB · {dims} 次元'**
  String raiModelsEmbeddingLine(String file, int size, int dims);

  /// No description provided for @raiModelsSearchSemantic.
  ///
  /// In ja, this message translates to:
  /// **'意味の近さで探します'**
  String get raiModelsSearchSemantic;

  /// No description provided for @raiModelsSearchSemanticDetail.
  ///
  /// In ja, this message translates to:
  /// **'検索: {label}(意味で引く)'**
  String raiModelsSearchSemanticDetail(String label);

  /// No description provided for @raiModelsSearchNgram.
  ///
  /// In ja, this message translates to:
  /// **'いまは語の一致で探します。ダウンロードすると言い換えにも強くなります'**
  String get raiModelsSearchNgram;

  /// No description provided for @raiModelsSearchNgramDetail.
  ///
  /// In ja, this message translates to:
  /// **'検索: n-gram 代替(語の一致で引く。ダウンロードすると言い換えにも強くなる)'**
  String get raiModelsSearchNgramDetail;

  /// No description provided for @raiModelsServerTitle.
  ///
  /// In ja, this message translates to:
  /// **'ローカル推論サーバー'**
  String get raiModelsServerTitle;

  /// No description provided for @raiModelsServerConfigured.
  ///
  /// In ja, this message translates to:
  /// **'接続先あり'**
  String get raiModelsServerConfigured;

  /// No description provided for @raiModelsServerNotConfigured.
  ///
  /// In ja, this message translates to:
  /// **'未設定'**
  String get raiModelsServerNotConfigured;

  /// No description provided for @raiModelsServerCaption.
  ///
  /// In ja, this message translates to:
  /// **'端末のモデルが答えられないとき、ここに聞きます。'**
  String get raiModelsServerCaption;

  /// 開発者モードの詳しい説明
  ///
  /// In ja, this message translates to:
  /// **'OpenAI 互換のチャット API(llama-server / vLLM など)。端末内モデルが失敗 / 無応答のとき、質問と近かったリファレンスを添えて渡します。'**
  String get raiModelsServerCaptionDetail;

  /// No description provided for @raiModelsServerModelHint.
  ///
  /// In ja, this message translates to:
  /// **'モデル名(省略可)'**
  String get raiModelsServerModelHint;

  /// モデルの大きさと端末のメモリの見立て
  ///
  /// In ja, this message translates to:
  /// **'動作可'**
  String get raiModelsRamOk;

  /// No description provided for @raiModelsRamTight.
  ///
  /// In ja, this message translates to:
  /// **'ぎりぎり'**
  String get raiModelsRamTight;

  /// No description provided for @raiModelsRamNo.
  ///
  /// In ja, this message translates to:
  /// **'メモリ不足'**
  String get raiModelsRamNo;

  /// No description provided for @raiModelsRamUnknownVerdict.
  ///
  /// In ja, this message translates to:
  /// **'不明'**
  String get raiModelsRamUnknownVerdict;

  /// No description provided for @raiModelsFallUpNotConnected.
  ///
  /// In ja, this message translates to:
  /// **'フォールアップ先(サーバー側)が未接続です'**
  String get raiModelsFallUpNotConnected;

  /// No description provided for @raiModelsServerHttpError.
  ///
  /// In ja, this message translates to:
  /// **'推論サーバー HTTP {status}'**
  String raiModelsServerHttpError(int status);

  /// No description provided for @raiModelsServerNoReply.
  ///
  /// In ja, this message translates to:
  /// **'推論サーバーから返事がありませんでした'**
  String get raiModelsServerNoReply;

  /// No description provided for @raiModelsServerUnreachable.
  ///
  /// In ja, this message translates to:
  /// **'推論サーバーに届きません: {error}'**
  String raiModelsServerUnreachable(String error);

  /// No description provided for @raiModelsLlmUnavailableHere.
  ///
  /// In ja, this message translates to:
  /// **'この環境では端末内モデルを使えません'**
  String get raiModelsLlmUnavailableHere;

  /// No description provided for @raiModelsLlamaFetching.
  ///
  /// In ja, this message translates to:
  /// **'llama.cpp のランタイム({tag})を取得中'**
  String raiModelsLlamaFetching(String tag);

  /// No description provided for @raiModelsLlamaMissingIos.
  ///
  /// In ja, this message translates to:
  /// **'llama.cpp が組み込まれていません(Runner に llama.xcframework を追加)'**
  String get raiModelsLlamaMissingIos;

  /// No description provided for @raiModelsLlamaMissing.
  ///
  /// In ja, this message translates to:
  /// **'llama.cpp のライブラリがありません'**
  String get raiModelsLlamaMissing;

  /// No description provided for @raiModelsLlamaFetchFailed.
  ///
  /// In ja, this message translates to:
  /// **'llama.cpp のランタイムを取得できません(HTTP {status})'**
  String raiModelsLlamaFetchFailed(int status);

  /// No description provided for @raiModelsStateCheckFailed.
  ///
  /// In ja, this message translates to:
  /// **'モデルの状態を確認できません: {error}'**
  String raiModelsStateCheckFailed(String error);

  /// No description provided for @raiModelsExtracting.
  ///
  /// In ja, this message translates to:
  /// **'同梱モデルを展開中'**
  String get raiModelsExtracting;

  /// No description provided for @raiModelsExtractTooLarge.
  ///
  /// In ja, this message translates to:
  /// **'この端末では同梱モデルを展開できません(ダウンロードしてください)'**
  String get raiModelsExtractTooLarge;

  /// No description provided for @raiModelsExtractFailed.
  ///
  /// In ja, this message translates to:
  /// **'展開に失敗しました: {error}'**
  String raiModelsExtractFailed(String error);

  /// No description provided for @raiModelsDownloadFailed.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロードに失敗しました: {error}'**
  String raiModelsDownloadFailed(String error);

  /// No description provided for @raiModelsNotDownloaded.
  ///
  /// In ja, this message translates to:
  /// **'端末内モデル({codename})がまだダウンロードされていません'**
  String raiModelsNotDownloaded(String codename);

  /// No description provided for @raiModelsDeviceUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'端末内モデルを使えません'**
  String get raiModelsDeviceUnavailable;

  /// No description provided for @raiModelsFileMissing.
  ///
  /// In ja, this message translates to:
  /// **'モデルファイルがありません: {path}'**
  String raiModelsFileMissing(String path);

  /// No description provided for @raiModelsTimeoutFirstToken.
  ///
  /// In ja, this message translates to:
  /// **'端末内モデルが 30 秒返事をしませんでした'**
  String get raiModelsTimeoutFirstToken;

  /// No description provided for @raiModelsTimeoutOverall.
  ///
  /// In ja, this message translates to:
  /// **'端末内モデルの返事が長すぎるので打ち切りました'**
  String get raiModelsTimeoutOverall;

  /// No description provided for @raiModelsOnlyThinking.
  ///
  /// In ja, this message translates to:
  /// **'端末内モデルから返事がありませんでした(思考だけで終わった可能性)'**
  String get raiModelsOnlyThinking;

  /// No description provided for @raiModelsGenerateFailed.
  ///
  /// In ja, this message translates to:
  /// **'生成に失敗しました: {error}'**
  String raiModelsGenerateFailed(String error);

  /// macOS で llama.cpp を読めないときに添える案内(前に改行が入る)
  ///
  /// In ja, this message translates to:
  /// **'「system policy」= サンドボックス / ライブラリ検証で拒否。Debug の entitlements(app-sandbox=false、disable-library-validation)で再ビルドしてください'**
  String get raiModelsHintSystemPolicy;

  /// macOS で llama.cpp を読めないときに添える案内(前に改行が入る)
  ///
  /// In ja, this message translates to:
  /// **'Gatekeeper に止められた場合: 「システム設定 > プライバシーとセキュリティ」で許可するか、Application Support/llama_cpp の dylib に xattr -dr com.apple.quarantine を実行してください'**
  String get raiModelsHintGatekeeper;

  /// error のあとに案内が続くことがある
  ///
  /// In ja, this message translates to:
  /// **'モデルを読み込めません(llama.cpp): {error}'**
  String raiModelsLoadFailedLlama(String error);

  /// No description provided for @raiModelsLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'モデルを読み込めません: {error}'**
  String raiModelsLoadFailed(String error);

  /// 埋め込みモデルの名前
  ///
  /// In ja, this message translates to:
  /// **'RASQ MiniLM(文)'**
  String get raiModelsEmbeddingRasqText;

  /// No description provided for @raiModelsEmbeddingMiniLmL12.
  ///
  /// In ja, this message translates to:
  /// **'MiniLM-L12 多言語(paraphrase, int8)'**
  String get raiModelsEmbeddingMiniLmL12;

  /// No description provided for @raiModelsEmbeddingRasqVision.
  ///
  /// In ja, this message translates to:
  /// **'RASQ MobileNet(投稿の画像)'**
  String get raiModelsEmbeddingRasqVision;

  /// No description provided for @raiModelsEmbeddingSiglipText.
  ///
  /// In ja, this message translates to:
  /// **'SigLIP2 base(テキスト塔・int8)'**
  String get raiModelsEmbeddingSiglipText;

  /// No description provided for @raiModelsEmbeddingSiglipVision.
  ///
  /// In ja, this message translates to:
  /// **'SigLIP2 base(画像側・int8)'**
  String get raiModelsEmbeddingSiglipVision;

  /// No description provided for @raiModelsEmbeddingFailed.
  ///
  /// In ja, this message translates to:
  /// **'失敗: {message}'**
  String raiModelsEmbeddingFailed(String message);

  /// No description provided for @raiModelsEmbeddingUnavailableHere.
  ///
  /// In ja, this message translates to:
  /// **'この環境では端末内の埋め込みモデルを使えません'**
  String get raiModelsEmbeddingUnavailableHere;

  /// 同梱から写した / ダウンロードしたモデルの sha256 が期待と違うとき
  ///
  /// In ja, this message translates to:
  /// **'モデルのファイルが壊れています(sha256 が違います)'**
  String get raiModelsChecksumMismatch;

  /// 同梱から写したモデルの長さが元と違うとき
  ///
  /// In ja, this message translates to:
  /// **'モデルのファイルが途中で切れています'**
  String get raiModelsSizeMismatch;

  /// No description provided for @raiModelsCentralNotConfigured.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーの接続先が未設定です'**
  String get raiModelsCentralNotConfigured;

  /// No description provided for @raiModelsLoadFailedOnnx.
  ///
  /// In ja, this message translates to:
  /// **'モデルを読み込めません(onnxruntime): {error}'**
  String raiModelsLoadFailedOnnx(String error);

  /// No description provided for @raiModelsWebDisabled.
  ///
  /// In ja, this message translates to:
  /// **'web 検索はまだ使えません'**
  String get raiModelsWebDisabled;

  /// No description provided for @raiModelsWebNoKey.
  ///
  /// In ja, this message translates to:
  /// **'Brave Search の鍵が設定されていません'**
  String get raiModelsWebNoKey;

  /// web 検索の答えを 1 件の結果として出すときの題
  ///
  /// In ja, this message translates to:
  /// **'web の答え'**
  String get raiModelsWebAnswerTitle;

  /// No description provided for @raiModelsWebFailed.
  ///
  /// In ja, this message translates to:
  /// **'検索に失敗: {error}'**
  String raiModelsWebFailed(String error);

  /// RAi バーのモデルのチップの横の短い状態(未ダウンロード)
  ///
  /// In ja, this message translates to:
  /// **'未DL'**
  String get raiModelsNoteNotInstalled;

  /// No description provided for @settingsActionBarTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインボタン'**
  String get settingsActionBarTitle;

  /// No description provided for @settingsActionBarBackTooltip.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get settingsActionBarBackTooltip;

  /// No description provided for @settingsActionBarBundleManual.
  ///
  /// In ja, this message translates to:
  /// **'手動配置(バーの (+) から足すまで出ない)'**
  String get settingsActionBarBundleManual;

  /// No description provided for @settingsActionBarBundleAlone.
  ///
  /// In ja, this message translates to:
  /// **'単体で末尾'**
  String get settingsActionBarBundleAlone;

  /// ボタンがまとめられる先の説明。{label} = 既存のボタンの名前、{percent} = タグの類似度(0〜100 の整数)。
  ///
  /// In ja, this message translates to:
  /// **'「{label}」のバンドル({percent}%)'**
  String settingsActionBarBundleInto(String label, String percent);

  /// No description provided for @settingsActionBarAutoOnTitle.
  ///
  /// In ja, this message translates to:
  /// **'面を開いたとき自動でオン'**
  String get settingsActionBarAutoOnTitle;

  /// No description provided for @settingsActionBarOn.
  ///
  /// In ja, this message translates to:
  /// **'オン'**
  String get settingsActionBarOn;

  /// No description provided for @settingsActionBarOff.
  ///
  /// In ja, this message translates to:
  /// **'オフ'**
  String get settingsActionBarOff;

  /// {state} = settingsActionBarOn / settingsActionBarOff の文言。
  ///
  /// In ja, this message translates to:
  /// **'既定({state})'**
  String settingsActionBarAutoDefault(String state);

  /// 既定値が審査済みプラグインの宣言によるとき。{state} = settingsActionBarOn / settingsActionBarOff の文言。
  ///
  /// In ja, this message translates to:
  /// **'既定({state}、プラグインの宣言)'**
  String settingsActionBarAutoDefaultDeclared(String state);

  /// {state} = settingsActionBarOn / settingsActionBarOff の文言。
  ///
  /// In ja, this message translates to:
  /// **'設定で上書き中(既定は {state})'**
  String settingsActionBarAutoOverridden(String state);

  /// No description provided for @settingsActionBarEmptyCaption.
  ///
  /// In ja, this message translates to:
  /// **'ストアで追加したプラグインがここに並びます'**
  String get settingsActionBarEmptyCaption;

  /// No description provided for @settingsActionBarIntroCaption.
  ///
  /// In ja, this message translates to:
  /// **'スイッチを切ると、すべてのアカウントで出なくなります。'**
  String get settingsActionBarIntroCaption;

  /// No description provided for @settingsActionBarIntroDetail.
  ///
  /// In ja, this message translates to:
  /// **'スイッチは端末全体の主電源(オフなら全アカウント・全面で出ず、自動でも動きません)。「面を開いたとき自動でオン」は、その面を開いた瞬間の初期状態です(面の中で切り替えた値は次に持ち越しません)。'**
  String get settingsActionBarIntroDetail;

  /// No description provided for @settingsActionBarPostTileHeader.
  ///
  /// In ja, this message translates to:
  /// **'投稿タイル'**
  String get settingsActionBarPostTileHeader;

  /// No description provided for @settingsActionBarPostTileEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'post.action を宣言したプラグインがここに並びます(ストアから追加)'**
  String get settingsActionBarPostTileEmptyDetail;

  /// No description provided for @settingsActionBarViewerHeader.
  ///
  /// In ja, this message translates to:
  /// **'全画面'**
  String get settingsActionBarViewerHeader;

  /// No description provided for @settingsActionBarViewerEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'viewer.overlay を宣言したプラグイン(QR コード検出など)がここに並びます'**
  String get settingsActionBarViewerEmptyDetail;

  /// No description provided for @settingsActionBarViewerPlacement.
  ///
  /// In ja, this message translates to:
  /// **'全画面アクションバーの ON / OFF ボタン'**
  String get settingsActionBarViewerPlacement;

  /// No description provided for @settingsActionBarMediaHeader.
  ///
  /// In ja, this message translates to:
  /// **'加工画面'**
  String get settingsActionBarMediaHeader;

  /// No description provided for @settingsActionBarMediaEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'composer.media を宣言したプラグインがここに並びます'**
  String get settingsActionBarMediaEmptyDetail;

  /// フィルターとして出力するボタンの配置の説明。{placement} = バンドル先の説明。
  ///
  /// In ja, this message translates to:
  /// **'フィルター · {placement}'**
  String settingsActionBarFilterPlacement(String placement);

  /// No description provided for @settingsActionBarComposerTextHeader.
  ///
  /// In ja, this message translates to:
  /// **'コンポーザー本文'**
  String get settingsActionBarComposerTextHeader;

  /// No description provided for @settingsActionBarComposerTextEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'composer.text を宣言したプラグインがここに並びます'**
  String get settingsActionBarComposerTextEmptyDetail;

  /// No description provided for @settingsActionBarComposerTextPlacement.
  ///
  /// In ja, this message translates to:
  /// **'コンポーザーのアクションバーの ON / OFF ボタン(長押しで設定)'**
  String get settingsActionBarComposerTextPlacement;

  /// No description provided for @settingsActionBarTransformHeader.
  ///
  /// In ja, this message translates to:
  /// **'投稿加工(自動)'**
  String get settingsActionBarTransformHeader;

  /// No description provided for @settingsActionBarTransformEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'post.transform を宣言したプラグインがここに並びます'**
  String get settingsActionBarTransformEmptyDetail;

  /// No description provided for @settingsActionBarTransformPlacement.
  ///
  /// In ja, this message translates to:
  /// **'表示前に本文を加工(ボタン無し)'**
  String get settingsActionBarTransformPlacement;

  /// {account} = いまのアカウントの表示、または settingsActionBarNoAccount。
  ///
  /// In ja, this message translates to:
  /// **'このアカウント({account})'**
  String settingsActionBarThisAccountHeader(String account);

  /// No description provided for @settingsActionBarNoAccount.
  ///
  /// In ja, this message translates to:
  /// **'未選択'**
  String get settingsActionBarNoAccount;

  /// No description provided for @settingsActionBarThisAccountEmptyCaption.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントで出すかどうか'**
  String get settingsActionBarThisAccountEmptyCaption;

  /// No description provided for @settingsActionBarThisAccountEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'投稿タイルのボタンを、このアカウントで出すかどうか'**
  String get settingsActionBarThisAccountEmptyDetail;

  /// {plugin} = プラグイン名、{tags} = タグを「 / 」でつないだもの。
  ///
  /// In ja, this message translates to:
  /// **'{plugin} · タグ: {tags}'**
  String settingsActionBarSlotSubtitle(String plugin, String tags);

  /// No description provided for @settingsActionBarThresholdTitle.
  ///
  /// In ja, this message translates to:
  /// **'束ねる閾値'**
  String get settingsActionBarThresholdTitle;

  /// No description provided for @settingsActionBarThresholdSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'似たボタンをまとめる度合い'**
  String get settingsActionBarThresholdSubtitle;

  /// No description provided for @settingsActionBarThresholdDetail.
  ///
  /// In ja, this message translates to:
  /// **'タグの類似度がこれ以上なら既存ボタンのバンドルに入る'**
  String get settingsActionBarThresholdDetail;

  /// No description provided for @settingsActionBarEditButton.
  ///
  /// In ja, this message translates to:
  /// **'アクションバーを編集'**
  String get settingsActionBarEditButton;

  /// No description provided for @settingsBackendTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバー'**
  String get settingsBackendTitle;

  /// No description provided for @settingsBackendErrorUnparseable.
  ///
  /// In ja, this message translates to:
  /// **'接続先を解釈できません。「http://192.168.3.14:8080」や「https://central.example」の形で入れてください。'**
  String get settingsBackendErrorUnparseable;

  /// No description provided for @settingsBackendSaved.
  ///
  /// In ja, this message translates to:
  /// **'保存しました'**
  String get settingsBackendSaved;

  /// No description provided for @settingsBackendErrorEnterUrl.
  ///
  /// In ja, this message translates to:
  /// **'接続先を入力してください(例: http://192.168.3.14:8080)'**
  String get settingsBackendErrorEnterUrl;

  /// No description provided for @settingsBackendCentralNotCentralHint.
  ///
  /// In ja, this message translates to:
  /// **'Central の欄に、ORGATE ではなく RASQ Central の接続先を入れてください'**
  String get settingsBackendCentralNotCentralHint;

  /// 接続テストの結果(Central)。{url} = Central の接続先、{error} = エラー、{hint} = 改行と補足(無いときは空)。
  ///
  /// In ja, this message translates to:
  /// **'接続できませんでした({url})— {error}{hint}'**
  String settingsBackendCentralConnectFailed(
    String url,
    String error,
    String hint,
  );

  /// 接続テストの結果(Central)。{algorithm} = 署名鍵の方式、{keyHead} = 公開鍵の先頭 12 文字。
  ///
  /// In ja, this message translates to:
  /// **'接続 OK — 署名鍵 {algorithm} {keyHead}…'**
  String settingsBackendCentralOk(String algorithm, String keyHead);

  /// No description provided for @settingsBackendAccountLine.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント: @{handle} ({displayName})'**
  String settingsBackendAccountLine(String handle, String displayName);

  /// No description provided for @settingsBackendAccountNotCreatedLine.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント: 未作成(下の「RASQ アカウントを開く」から作成できます)'**
  String get settingsBackendAccountNotCreatedLine;

  /// No description provided for @settingsBackendAccountLoadFailedLine.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを取得できませんでした — {error}'**
  String settingsBackendAccountLoadFailedLine(String error);

  /// No description provided for @settingsBackendOrgateNotConfiguredLine.
  ///
  /// In ja, this message translates to:
  /// **'ORGATE: 未設定(RASQ アカウントにログインできません)'**
  String get settingsBackendOrgateNotConfiguredLine;

  /// No description provided for @settingsBackendOrgateOk.
  ///
  /// In ja, this message translates to:
  /// **'ORGATE: 接続 OK — トークンの公開鍵 {count, plural, other{{count} 個}}'**
  String settingsBackendOrgateOk(int count);

  /// No description provided for @settingsBackendOrgateNoKeys.
  ///
  /// In ja, this message translates to:
  /// **'ORGATE: 応答にトークンの公開鍵がありません({url})'**
  String settingsBackendOrgateNoKeys(String url);

  /// No description provided for @settingsBackendOrgateConnectFailed.
  ///
  /// In ja, this message translates to:
  /// **'ORGATE に接続できませんでした({url})— {error}'**
  String settingsBackendOrgateConnectFailed(String url, String error);

  /// No description provided for @settingsBackendCaption.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントやストアのサーバーの接続先です。SNS の投稿やタイムラインは、ここを通りません。'**
  String get settingsBackendCaption;

  /// No description provided for @settingsBackendCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'RASQ Central は公開・共有のもの(プロフィール・ストア・ASTell・投稿・リストなど)のサーバー、ORGATE は本人だけの情報(ログイン・パスワード・メールアドレス)と Mastodon などのログイン(OAuth ブローカー)のサーバーです。RASQ アカウントへのログインは ORGATE で行い、そのトークンを Central にも使います。SNS の投稿やタイムラインはどちらも通らず、プラグインが各インスタンスへ直接接続します。'**
  String get settingsBackendCaptionDetail;

  /// No description provided for @settingsBackendCentralLabel.
  ///
  /// In ja, this message translates to:
  /// **'RASQ Central の接続先(空なら ORGATE を流用)'**
  String get settingsBackendCentralLabel;

  /// No description provided for @settingsBackendOrgateLabel.
  ///
  /// In ja, this message translates to:
  /// **'ORGATE(ログイン・本人だけの情報)の接続先'**
  String get settingsBackendOrgateLabel;

  /// No description provided for @settingsBackendSaveButton.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get settingsBackendSaveButton;

  /// No description provided for @settingsBackendTestButton.
  ///
  /// In ja, this message translates to:
  /// **'接続テスト'**
  String get settingsBackendTestButton;

  /// No description provided for @settingsBackendCentralDisconnected.
  ///
  /// In ja, this message translates to:
  /// **'Central: 未接続(RASQ アカウントは作れません)'**
  String get settingsBackendCentralDisconnected;

  /// No description provided for @settingsBackendCentralDisconnectedDetail.
  ///
  /// In ja, this message translates to:
  /// **'Central: 未接続 — プラグインストアは同梱のものだけ、RASQ アカウントは作成できません(この端末のみ)。'**
  String get settingsBackendCentralDisconnectedDetail;

  /// No description provided for @settingsBackendOrgateDisconnected.
  ///
  /// In ja, this message translates to:
  /// **'ORGATE: 未接続(RASQ アカウントにログインできません)'**
  String get settingsBackendOrgateDisconnected;

  /// No description provided for @settingsBackendTestEndpointsSection.
  ///
  /// In ja, this message translates to:
  /// **'テスト用の接続先'**
  String get settingsBackendTestEndpointsSection;

  /// No description provided for @settingsBackendTestEndpointsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ダミーの SNS とデモの Central / ORGATE を使う'**
  String get settingsBackendTestEndpointsTitle;

  /// No description provided for @settingsBackendTestEndpointsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'プレビューの録画用'**
  String get settingsBackendTestEndpointsSubtitle;

  /// 開発者モードの説明。各 Host = ダミーのホスト名、各 Port = ポート番号。
  ///
  /// In ja, this message translates to:
  /// **'プレビュー録画用。Misskey / Mastodon / Bluesky の {misskeyHost} / {mastodonHost} / {blueskyHost} をこのアドレスのダミーへ向け、Central(:{centralPort})と ORGATE(:{orgatePort})も切り替えます'**
  String settingsBackendTestEndpointsDetail(
    String misskeyHost,
    String mastodonHost,
    String blueskyHost,
    String centralPort,
    String orgatePort,
  );

  /// No description provided for @settingsBackendTestAddressLabel.
  ///
  /// In ja, this message translates to:
  /// **'ダミー環境のアドレス(同じ機械なら 127.0.0.1、ほかの機械なら その IP)'**
  String get settingsBackendTestAddressLabel;

  /// No description provided for @settingsBackendTestCaption.
  ///
  /// In ja, this message translates to:
  /// **'SNS のログイン画面で、サーバーに上のホスト名を入れてください。'**
  String get settingsBackendTestCaption;

  /// No description provided for @settingsBackendTestCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'SNS は各ログイン画面でサーバーに上のホスト名を入れます(許可ページは自動で通ります。Bluesky の ID / パスワードは何でも可)。RASQ アカウントはアカウントのログインから。切り替えたら、すでにログインしている SNS は次の読み込みから新しい接続先になります。'**
  String get settingsBackendTestCaptionDetail;

  /// No description provided for @settingsBackendAccountSection.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント'**
  String get settingsBackendAccountSection;

  /// No description provided for @settingsBackendAccountLoadError.
  ///
  /// In ja, this message translates to:
  /// **'アカウントを取得できませんでした: {error}'**
  String settingsBackendAccountLoadError(String error);

  /// No description provided for @settingsBackendNoServer.
  ///
  /// In ja, this message translates to:
  /// **'接続先が設定されていません。'**
  String get settingsBackendNoServer;

  /// No description provided for @settingsBackendAccountNotCreated.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントは未作成です。'**
  String get settingsBackendAccountNotCreated;

  /// No description provided for @settingsBackendOpenAccountButton.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを開く'**
  String get settingsBackendOpenAccountButton;

  /// No description provided for @settingsBackendAccountDeviceOnly.
  ///
  /// In ja, this message translates to:
  /// **'この端末でだけ有効なアカウントです。ハンドルと表示名はプロフィール編集から変更できます。'**
  String get settingsBackendAccountDeviceOnly;

  /// No description provided for @settingsBackendBundleSection.
  ///
  /// In ja, this message translates to:
  /// **'アカウントバンドル'**
  String get settingsBackendBundleSection;

  /// No description provided for @settingsBackendBundleCaption.
  ///
  /// In ja, this message translates to:
  /// **'まとめるときに送るのは、SNS アカウントの一覧だけです。ログインの鍵は、端末間の共有・Web 版・アカウントページへの投稿の表示を選んだときだけ送ります。'**
  String get settingsBackendBundleCaption;

  /// No description provided for @settingsBackendBundleCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'束ねるときにサーバーへ送るのは、SNS の種類・サーバー・アカウント・表示名だけ。アクセストークンは、端末間の共有(E2E、サーバーは読めない)、Web 版の保管庫(サーバーの鍵で暗号化、サーバーは復号できる)、アカウントページへの投稿の表示(同上)を選んだときだけ送る(プライバシーポリシー第 4 項)。'**
  String get settingsBackendBundleCaptionDetail;

  /// No description provided for @settingsBackendNoSessions.
  ///
  /// In ja, this message translates to:
  /// **'ログイン中のアカウントはありません。'**
  String get settingsBackendNoSessions;

  /// No description provided for @settingsColumnsTitle.
  ///
  /// In ja, this message translates to:
  /// **'カラムの幅'**
  String get settingsColumnsTitle;

  /// No description provided for @settingsColumnsIntroCaption.
  ///
  /// In ja, this message translates to:
  /// **'タブレットや PC など広い画面で、左右のカラムの幅を決めます。'**
  String get settingsColumnsIntroCaption;

  /// No description provided for @settingsColumnsIntroDetail.
  ///
  /// In ja, this message translates to:
  /// **'幅の広い画面(タブレット / デスクトップ / Web)で、小型カラム(検索や、ページを開いた側)と大型カラム(開いたページ)の幅の比を決めます。'**
  String get settingsColumnsIntroDetail;

  /// No description provided for @settingsColumnsSplitHeader.
  ///
  /// In ja, this message translates to:
  /// **'小型 / 大型カラムの比'**
  String get settingsColumnsSplitHeader;

  /// 既定の比の行の説明。{hint} = その比の説明文。
  ///
  /// In ja, this message translates to:
  /// **'{hint}(既定)'**
  String settingsColumnsSplitDefault(String hint);

  /// No description provided for @settingsColumnsLargeWidthLabel.
  ///
  /// In ja, this message translates to:
  /// **'大型カラムの幅'**
  String get settingsColumnsLargeWidthLabel;

  /// No description provided for @settingsColumnsSmallWidthLabel.
  ///
  /// In ja, this message translates to:
  /// **'小型カラムの幅'**
  String get settingsColumnsSmallWidthLabel;

  /// No description provided for @settingsColumnsShrinkCaption.
  ///
  /// In ja, this message translates to:
  /// **'画面に入らないときは、自動で縮めます。'**
  String get settingsColumnsShrinkCaption;

  /// {minWidth} = カラムの最小の幅(px の数)。
  ///
  /// In ja, this message translates to:
  /// **'画面が狭くて入らないときは、もう片方のカラムを {minWidth} px 以上残し、小型カラムが大型カラムより広くならないように縮めます。'**
  String settingsColumnsShrinkDetail(String minWidth);

  /// No description provided for @settingsColumnsSwingInColumnTitle.
  ///
  /// In ja, this message translates to:
  /// **'Swing を右のカラムで開く'**
  String get settingsColumnsSwingInColumnTitle;

  /// No description provided for @settingsColumnsSwingInColumnSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'オフのときは全画面で開きます(はじめはオン。全画面を指定したプラグインの Swing はいつも全画面)'**
  String get settingsColumnsSwingInColumnSubtitle;

  /// No description provided for @settingsColumnsCurrentHeader.
  ///
  /// In ja, this message translates to:
  /// **'いまの画面での幅'**
  String get settingsColumnsCurrentHeader;

  /// いまの画面での小型 / 大型カラムの幅。{small} / {large} = px の数。
  ///
  /// In ja, this message translates to:
  /// **'小型 {small} px / 大型 {large} px'**
  String settingsColumnsPreviewWidths(String small, String large);

  /// No description provided for @settingsColumnsNarrowCaption.
  ///
  /// In ja, this message translates to:
  /// **'いまの画面は狭いので、カラムは 1 つです。'**
  String get settingsColumnsNarrowCaption;

  /// {breakpoint} = カラムが分かれる画面の幅(px の数)。
  ///
  /// In ja, this message translates to:
  /// **'いまの画面は幅が狭いので、カラムを 1 つだけ出しています({breakpoint} px 以上で小型 / 大型のカラムに分かれます)。'**
  String settingsColumnsNarrowDetail(String breakpoint);

  /// No description provided for @settingsColumnsPreviewSmall.
  ///
  /// In ja, this message translates to:
  /// **'小型'**
  String get settingsColumnsPreviewSmall;

  /// No description provided for @settingsColumnsPreviewLarge.
  ///
  /// In ja, this message translates to:
  /// **'大型'**
  String get settingsColumnsPreviewLarge;

  /// No description provided for @settingsComposerTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿コンポーザー'**
  String get settingsComposerTitle;

  /// No description provided for @settingsComposerAutoAccountTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿アカウントの自動選択'**
  String get settingsComposerAutoAccountTitle;

  /// No description provided for @settingsComposerAutoAccountSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'下書きに合うアカウントへ、投稿先を自動で切り替えます'**
  String get settingsComposerAutoAccountSubtitle;

  /// No description provided for @settingsComposerAutoAccountDetail.
  ///
  /// In ja, this message translates to:
  /// **'下書きの内容がポスト先の絞り込みに合うアカウントへ、投稿先を自動で切り替えます(手動選択が常に優先)'**
  String get settingsComposerAutoAccountDetail;

  /// No description provided for @settingsComposerRasqLinkedTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントへも連動投稿する'**
  String get settingsComposerRasqLinkedTitle;

  /// No description provided for @settingsComposerRasqLinkedSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'複数のアカウントに投稿するとき、RASQ アカウントも選べます'**
  String get settingsComposerRasqLinkedSubtitle;

  /// No description provided for @settingsComposerRasqLinkedDetail.
  ///
  /// In ja, this message translates to:
  /// **'複数選択モードで、RASQ アカウントの行も選べるようになります(通常投稿 / ノード連動)。届け方と絞り込みは「投稿先のカスタマイズ」の RASQ のタブで決めます。RASQ の上限(1000 文字 / 添付 6 つ / 投票 6 個 / 投稿 3 件)を超える投稿は、RASQ へは送られません'**
  String get settingsComposerRasqLinkedDetail;

  /// No description provided for @settingsEmomTitle.
  ///
  /// In ja, this message translates to:
  /// **'EmoM の閾値'**
  String get settingsEmomTitle;

  /// No description provided for @settingsEmomBandLow.
  ///
  /// In ja, this message translates to:
  /// **'控えめ — 運営が制限したトレンドを早めに隠します'**
  String get settingsEmomBandLow;

  /// No description provided for @settingsEmomBandMiddle.
  ///
  /// In ja, this message translates to:
  /// **'ふつう'**
  String get settingsEmomBandMiddle;

  /// No description provided for @settingsEmomBandHigh.
  ///
  /// In ja, this message translates to:
  /// **'広め — 運営が強く制限したトレンドだけを隠します'**
  String get settingsEmomBandHigh;

  /// No description provided for @settingsEmomStatusSending.
  ///
  /// In ja, this message translates to:
  /// **'送っています…'**
  String get settingsEmomStatusSending;

  /// No description provided for @settingsEmomStatusNoAccount.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントでログインすると公開できます(この端末では使えます)'**
  String get settingsEmomStatusNoAccount;

  /// No description provided for @settingsEmomStatusFailed.
  ///
  /// In ja, this message translates to:
  /// **'送れませんでした。次に開いたとき(またはトレンドを読み直したとき)送り直します'**
  String get settingsEmomStatusFailed;

  /// {value} = 公開している閾値(0〜100 の整数)。
  ///
  /// In ja, this message translates to:
  /// **'公開しています(値 {value})'**
  String settingsEmomStatusDisclosed(String value);

  /// No description provided for @settingsEmomStatusPending.
  ///
  /// In ja, this message translates to:
  /// **'まだ届いていません'**
  String get settingsEmomStatusPending;

  /// No description provided for @settingsEmomStatusNotDisclosed.
  ///
  /// In ja, this message translates to:
  /// **'公開していません'**
  String get settingsEmomStatusNotDisclosed;

  /// No description provided for @settingsEmomIntro.
  ///
  /// In ja, this message translates to:
  /// **'EmoM は、投稿やトレンドの気持ちの強さ・刺激の強さを見積もる RASQ のモデルです(準備中)。いまはこの閾値を、RASQ の運営が通報を確かめてトレンドを制限するときの目安にだけ使います。'**
  String get settingsEmomIntro;

  /// No description provided for @settingsEmomThresholdLabel.
  ///
  /// In ja, this message translates to:
  /// **'閾値'**
  String get settingsEmomThresholdLabel;

  /// No description provided for @settingsEmomScaleLow.
  ///
  /// In ja, this message translates to:
  /// **'低い(隠れやすい)'**
  String get settingsEmomScaleLow;

  /// No description provided for @settingsEmomScaleHigh.
  ///
  /// In ja, this message translates to:
  /// **'高い(隠れにくい)'**
  String get settingsEmomScaleHigh;

  /// {defaultValue} = 閾値の既定値(整数)。
  ///
  /// In ja, this message translates to:
  /// **'閾値が高いほど、刺激の強い話題も受け入れる設定です。運営が制限したトレンドが隠れにくくなります。低いほど、制限されたトレンドを早めに隠します。既定は {defaultValue} です。'**
  String settingsEmomExplanation(String defaultValue);

  /// No description provided for @settingsEmomDiscloseTitle.
  ///
  /// In ja, this message translates to:
  /// **'閾値を公開する(制限の目安に使う)'**
  String get settingsEmomDiscloseTitle;

  /// No description provided for @settingsEmomDiscloseSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'値だけを RASQ のサーバーに送ります。運営は、公開された値をまとめた分布(どの値の人が何人いるか)だけを使い、あなたの値を個別に見ることはありません。オフにすると、送った値を消します。'**
  String get settingsEmomDiscloseSubtitle;

  /// No description provided for @settingsEmomRestrictionExplanation.
  ///
  /// In ja, this message translates to:
  /// **'運営がトレンドを「N%」で制限すると、公開された閾値の低いほうから N% ほどの人に、そのトレンドが出なくなります。公開していなくても、この端末の閾値で同じように判定します(閾値はこの端末に保存されます)。「全員に非表示」にされたトレンドは、閾値に関係なく出ません。隠れたトレンドは、検索のトレンドの一覧に並ばなくなるだけです。'**
  String get settingsEmomRestrictionExplanation;

  /// No description provided for @settingsHomeTitle.
  ///
  /// In ja, this message translates to:
  /// **'全ての設定'**
  String get settingsHomeTitle;

  /// No description provided for @settingsHomeSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'設定や操作を検索'**
  String get settingsHomeSearchHint;

  /// No description provided for @settingsHomeSearchClear.
  ///
  /// In ja, this message translates to:
  /// **'消す'**
  String get settingsHomeSearchClear;

  /// No description provided for @settingsHomeSearchError.
  ///
  /// In ja, this message translates to:
  /// **'設定を探せませんでした'**
  String get settingsHomeSearchError;

  /// No description provided for @settingsHomeSearchEmpty.
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした'**
  String get settingsHomeSearchEmpty;

  /// No description provided for @settingsHomeSearchEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'「{query}」に当たる設定はありません。言い方を変えるか、RAi に聞いてみてください'**
  String settingsHomeSearchEmptyHint(String query);

  /// No description provided for @settingsHomeSearchOperations.
  ///
  /// In ja, this message translates to:
  /// **'操作(RAi が案内します)'**
  String get settingsHomeSearchOperations;

  /// No description provided for @settingsHomeOtherHeader.
  ///
  /// In ja, this message translates to:
  /// **'その他の設定'**
  String get settingsHomeOtherHeader;

  /// No description provided for @settingsHomeComposer.
  ///
  /// In ja, this message translates to:
  /// **'投稿コンポーザー'**
  String get settingsHomeComposer;

  /// 設定の検索で「投稿コンポーザー」に当てる語(, 区切り)。
  ///
  /// In ja, this message translates to:
  /// **'投稿の画面,下書き'**
  String get settingsHomeComposerKeywords;

  /// 設定の検索で「フォントやカラースキーム」に当てる語(, 区切り)。
  ///
  /// In ja, this message translates to:
  /// **'着せ替え,テーマ,ダークモード,ライト,色,フォント'**
  String get settingsHomeThemeKeywords;

  /// No description provided for @settingsHomeAccountImportant.
  ///
  /// In ja, this message translates to:
  /// **'アカウントの重要設定'**
  String get settingsHomeAccountImportant;

  /// No description provided for @settingsHomeAccountImportantSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'パスワードの変更やアカウント削除は web 版で'**
  String get settingsHomeAccountImportantSubtitle;

  /// No description provided for @settingsHomeAccountImportantDetail.
  ///
  /// In ja, this message translates to:
  /// **'パスワードの再設定やアカウント削除など、パスワードがいる処理は web 版で行います'**
  String get settingsHomeAccountImportantDetail;

  /// No description provided for @settingsHomeLogout.
  ///
  /// In ja, this message translates to:
  /// **'@{handle}からログアウト'**
  String settingsHomeLogout(String handle);

  /// No description provided for @settingsHomeLogoutConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'ログアウトしますか？'**
  String get settingsHomeLogoutConfirmTitle;

  /// No description provided for @settingsHomeLogoutConfirmMessage.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントのプラグイン構成はデバイスに残ります。'**
  String get settingsHomeLogoutConfirmMessage;

  /// No description provided for @settingsHomeLogoutConfirm.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get settingsHomeLogoutConfirm;

  /// No description provided for @settingsHomeCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get settingsHomeCancel;

  /// No description provided for @settingsHomeOk.
  ///
  /// In ja, this message translates to:
  /// **'OK'**
  String get settingsHomeOk;

  /// No description provided for @settingsHomeGenericTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsHomeGenericTitle;

  /// No description provided for @settingsHomeUnknownSection.
  ///
  /// In ja, this message translates to:
  /// **'不明な設定セクション'**
  String get settingsHomeUnknownSection;

  /// No description provided for @settingsHomeThemeModeSystem.
  ///
  /// In ja, this message translates to:
  /// **'システム'**
  String get settingsHomeThemeModeSystem;

  /// No description provided for @settingsHomeThemeModeLight.
  ///
  /// In ja, this message translates to:
  /// **'ライト'**
  String get settingsHomeThemeModeLight;

  /// No description provided for @settingsHomeThemeModeDark.
  ///
  /// In ja, this message translates to:
  /// **'ダーク'**
  String get settingsHomeThemeModeDark;

  /// No description provided for @settingsHomePlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'この設定は準備中です。'**
  String get settingsHomePlaceholder;

  /// No description provided for @settingsHomePlaceholderDetail.
  ///
  /// In ja, this message translates to:
  /// **'この設定は第二階層以降の仕様確定後(M4: FOW/DSL 描画)に実装します。'**
  String get settingsHomePlaceholderDetail;

  /// No description provided for @settingsHomePageMissing.
  ///
  /// In ja, this message translates to:
  /// **'このページはありません'**
  String get settingsHomePageMissing;

  /// No description provided for @settingsHomePageMissingHint.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントの SNS には、この設定がありません。'**
  String get settingsHomePageMissingHint;

  /// No description provided for @settingsHomePageLoadError.
  ///
  /// In ja, this message translates to:
  /// **'設定ページを読み込めません'**
  String get settingsHomePageLoadError;

  /// No description provided for @settingsHomeRemoteLoadError.
  ///
  /// In ja, this message translates to:
  /// **'サーバーから設定を取得できません'**
  String get settingsHomeRemoteLoadError;

  /// No description provided for @settingsHomeRemotePermissionHint.
  ///
  /// In ja, this message translates to:
  /// **'\n\nアプリの権限が不足しています。一度ログアウトして再ログインすると、新しい権限が付与されます。'**
  String get settingsHomeRemotePermissionHint;

  /// No description provided for @settingsHomeSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'保存できませんでした'**
  String get settingsHomeSaveFailed;

  /// No description provided for @settingsHomeChildLocked.
  ///
  /// In ja, this message translates to:
  /// **'見守り中のため、ここは変えられません(閲覧注意のメディアは必ず隠します)。'**
  String get settingsHomeChildLocked;

  /// No description provided for @settingsHomeTargetAccount.
  ///
  /// In ja, this message translates to:
  /// **'設定するアカウント'**
  String get settingsHomeTargetAccount;

  /// No description provided for @settingsHomeMissingSnsPage.
  ///
  /// In ja, this message translates to:
  /// **'SNS プラグインが設定ページ \"{area}\" を提供していません'**
  String settingsHomeMissingSnsPage(String area);

  /// No description provided for @settingsLearningTitle.
  ///
  /// In ja, this message translates to:
  /// **'アルゴリズムとコミュニティへの貢献'**
  String get settingsLearningTitle;

  /// No description provided for @settingsLearningError.
  ///
  /// In ja, this message translates to:
  /// **'できませんでした — {error}'**
  String settingsLearningError(String error);

  /// No description provided for @settingsLearningGrantConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'同意して参加する'**
  String get settingsLearningGrantConfirmButton;

  /// No description provided for @settingsLearningGrantPointOptional.
  ///
  /// In ja, this message translates to:
  /// **'任意です。断っても、やめても、RASQ の機能や有料機能はそのまま使えます'**
  String get settingsLearningGrantPointOptional;

  /// No description provided for @settingsLearningGrantPointScope.
  ///
  /// In ja, this message translates to:
  /// **'対象は、あなたが自分で書いた公開の投稿と、その投稿どうしが同じ会話かどうかだけです'**
  String get settingsLearningGrantPointScope;

  /// No description provided for @settingsLearningGrantPointExcluded.
  ///
  /// In ja, this message translates to:
  /// **'ほかの人の投稿、DM、限定公開の投稿、ASTell の会話、RAi の質問と答えは送りません'**
  String get settingsLearningGrantPointExcluded;

  /// No description provided for @settingsLearningGrantPointVerifiedOnly.
  ///
  /// In ja, this message translates to:
  /// **'持ち主の確認が済んだ SNS アカウントの投稿だけを受け付けます'**
  String get settingsLearningGrantPointVerifiedOnly;

  /// No description provided for @settingsLearningGrantPointPurpose.
  ///
  /// In ja, this message translates to:
  /// **'リレーショナルタイムラインの会話のまとめ方の改善に使います'**
  String get settingsLearningGrantPointPurpose;

  /// No description provided for @settingsLearningGrantPointDeletion.
  ///
  /// In ja, this message translates to:
  /// **'やめたときは、送ったデータをすぐに消します'**
  String get settingsLearningGrantPointDeletion;

  /// No description provided for @settingsLearningGrantExtendedNotice.
  ///
  /// In ja, this message translates to:
  /// **'検証用の設定です。ほかの人の投稿の判定や RAi のやりとりも送ります。'**
  String get settingsLearningGrantExtendedNotice;

  /// No description provided for @settingsLearningGrantExtendedNoticeDetail.
  ///
  /// In ja, this message translates to:
  /// **'CENTRAL_LEARNING_SCOPE=extended(S-049 / S-050)。正式な環境では使わない。'**
  String get settingsLearningGrantExtendedNoticeDetail;

  /// No description provided for @settingsLearningGrantScopeDetail.
  ///
  /// In ja, this message translates to:
  /// **'D-370 / S-051。関連 TL の会話イベントから自分の投稿(公開と分かるもの。Bluesky はすべて公開)だけを POST /me/learning/contributions へ(v2、self = 自分の SNS アカウント)。Central は持ち主の確認(sns_links.verified_at)と、全投稿が a=-1・vis=public かを確かめる。受け取るたびに年齢と保護者の同意も確かめ直す。本文の @メンションと URL は伏せる。'**
  String get settingsLearningGrantScopeDetail;

  /// No description provided for @settingsLearningGrantReadFullButton.
  ///
  /// In ja, this message translates to:
  /// **'説明の全文を読む'**
  String get settingsLearningGrantReadFullButton;

  /// No description provided for @settingsLearningGrantAgreeCheckbox.
  ///
  /// In ja, this message translates to:
  /// **'説明を読み、データの提供に同意します'**
  String get settingsLearningGrantAgreeCheckbox;

  /// No description provided for @settingsLearningDocumentVersion.
  ///
  /// In ja, this message translates to:
  /// **'文書の版: {version}'**
  String settingsLearningDocumentVersion(String version);

  /// No description provided for @settingsLearningAgeTitle.
  ///
  /// In ja, this message translates to:
  /// **'年齢の申告'**
  String get settingsLearningAgeTitle;

  /// No description provided for @settingsLearningAgeConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'申告する'**
  String get settingsLearningAgeConfirmButton;

  /// No description provided for @settingsLearningGuardianConsent.
  ///
  /// In ja, this message translates to:
  /// **'保護者の同意を得ています'**
  String get settingsLearningGuardianConsent;

  /// No description provided for @settingsLearningAgeDeclared.
  ///
  /// In ja, this message translates to:
  /// **'年齢を申告しました'**
  String get settingsLearningAgeDeclared;

  /// No description provided for @settingsLearningCodeSheetTitle.
  ///
  /// In ja, this message translates to:
  /// **'撤回用のコードで撤回'**
  String get settingsLearningCodeSheetTitle;

  /// No description provided for @settingsLearningCodeConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'撤回する'**
  String get settingsLearningCodeConfirmButton;

  /// No description provided for @settingsLearningCodeSheetBody.
  ///
  /// In ja, this message translates to:
  /// **'同意したときに発行されたコードを入れます。提供した RASQ アカウントに入れなくなった場合でも撤回できます。'**
  String get settingsLearningCodeSheetBody;

  /// No description provided for @settingsLearningCodeHint.
  ///
  /// In ja, this message translates to:
  /// **'撤回用のコード'**
  String get settingsLearningCodeHint;

  /// No description provided for @settingsLearningWithdrawnByCode.
  ///
  /// In ja, this message translates to:
  /// **'やめました。送ったデータは消します'**
  String get settingsLearningWithdrawnByCode;

  /// No description provided for @settingsLearningReasonAgeRequired.
  ///
  /// In ja, this message translates to:
  /// **'年齢の申告が必要です'**
  String get settingsLearningReasonAgeRequired;

  /// No description provided for @settingsLearningReasonUnder16.
  ///
  /// In ja, this message translates to:
  /// **'16 歳以上から参加できます'**
  String get settingsLearningReasonUnder16;

  /// No description provided for @settingsLearningReasonGuardianRequired.
  ///
  /// In ja, this message translates to:
  /// **'16〜17 歳の人は、保護者の同意が必要です'**
  String get settingsLearningReasonGuardianRequired;

  /// No description provided for @settingsLearningIntroNotice.
  ///
  /// In ja, this message translates to:
  /// **'あなたが書いた公開の投稿を送って、会話のまとめ方の改善に協力できます。任意で、いつでもやめられます。'**
  String get settingsLearningIntroNotice;

  /// No description provided for @settingsLearningIntroNoticeDetail.
  ///
  /// In ja, this message translates to:
  /// **'D-243 / D-363 / D-370。同意は Central の account_consents(kind = learning)に記録。既定の範囲(own)では、関連 TL の会話の中の自分の公開投稿だけを POST /me/learning/contributions へ送る。正式な環境では受付を閉じる(CENTRAL_LEARNING_OPEN=false)。'**
  String get settingsLearningIntroNoticeDetail;

  /// No description provided for @settingsLearningReadAboutTitle.
  ///
  /// In ja, this message translates to:
  /// **'説明を読む'**
  String get settingsLearningReadAboutTitle;

  /// No description provided for @settingsLearningReadAboutSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'送るもの、使いみち、保存する期間'**
  String get settingsLearningReadAboutSubtitle;

  /// No description provided for @settingsLearningStatusSection.
  ///
  /// In ja, this message translates to:
  /// **'状態'**
  String get settingsLearningStatusSection;

  /// No description provided for @settingsLearningServerNotConfiguredTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーの接続先が未設定です'**
  String get settingsLearningServerNotConfiguredTitle;

  /// No description provided for @settingsLearningServerNotConfiguredSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'接続先を入れると確認できます'**
  String get settingsLearningServerNotConfiguredSubtitle;

  /// No description provided for @settingsLearningNoAccountTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントが未作成です'**
  String get settingsLearningNoAccountTitle;

  /// No description provided for @settingsLearningNoAccountSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'データの提供は RASQ アカウントごとに記録します'**
  String get settingsLearningNoAccountSubtitle;

  /// No description provided for @settingsLearningLoadError.
  ///
  /// In ja, this message translates to:
  /// **'取得できませんでした: {error}'**
  String settingsLearningLoadError(String error);

  /// No description provided for @settingsLearningStatusTitle.
  ///
  /// In ja, this message translates to:
  /// **'貢献'**
  String get settingsLearningStatusTitle;

  /// No description provided for @settingsLearningStatusJoined.
  ///
  /// In ja, this message translates to:
  /// **'参加中'**
  String get settingsLearningStatusJoined;

  /// No description provided for @settingsLearningStatusNotJoined.
  ///
  /// In ja, this message translates to:
  /// **'参加していません'**
  String get settingsLearningStatusNotJoined;

  /// No description provided for @settingsLearningSinceTitle.
  ///
  /// In ja, this message translates to:
  /// **'同意した日'**
  String get settingsLearningSinceTitle;

  /// No description provided for @settingsLearningOpenTitle.
  ///
  /// In ja, this message translates to:
  /// **'受付'**
  String get settingsLearningOpenTitle;

  /// No description provided for @settingsLearningOpenYes.
  ///
  /// In ja, this message translates to:
  /// **'受付中'**
  String get settingsLearningOpenYes;

  /// No description provided for @settingsLearningOpenNo.
  ///
  /// In ja, this message translates to:
  /// **'まだ始まっていません'**
  String get settingsLearningOpenNo;

  /// No description provided for @settingsLearningAgeUndeclared.
  ///
  /// In ja, this message translates to:
  /// **'未申告'**
  String get settingsLearningAgeUndeclared;

  /// No description provided for @settingsLearningSentTitle.
  ///
  /// In ja, this message translates to:
  /// **'送ったデータ'**
  String get settingsLearningSentTitle;

  /// 送ったデータの件数。{relational} = 会話の件数、{rai} = RAi の件数。
  ///
  /// In ja, this message translates to:
  /// **'会話 {relational, plural, other{{relational} 件}} ・ RAi {rai, plural, other{{rai} 件}}'**
  String settingsLearningSentValue(int relational, int rai);

  /// No description provided for @settingsLearningExamplesTitle.
  ///
  /// In ja, this message translates to:
  /// **'クラウドの判定の例'**
  String get settingsLearningExamplesTitle;

  /// {examples} = クラウドの判定の例の件数、{hardNegative} = そのうち「怪しいけど違う」の件数。
  ///
  /// In ja, this message translates to:
  /// **'{examples, plural, other{{examples} 件}}(怪しいけど違う {hardNegative, plural, other{{hardNegative} 件}})'**
  String settingsLearningExamplesValue(int examples, int hardNegative);

  /// No description provided for @settingsLearningPostsLabelsTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿 / ラベル'**
  String get settingsLearningPostsLabelsTitle;

  /// No description provided for @settingsLearningModelsTitle.
  ///
  /// In ja, this message translates to:
  /// **'このデータを使ったモデル'**
  String get settingsLearningModelsTitle;

  /// No description provided for @settingsLearningModelsNone.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get settingsLearningModelsNone;

  /// モデルの名前を並べるときの区切り。
  ///
  /// In ja, this message translates to:
  /// **'、'**
  String get settingsLearningModelsSeparator;

  /// No description provided for @settingsLearningWithdrawTitle.
  ///
  /// In ja, this message translates to:
  /// **'貢献をやめる'**
  String get settingsLearningWithdrawTitle;

  /// No description provided for @settingsLearningWithdrawMessage.
  ///
  /// In ja, this message translates to:
  /// **'データを送るのをすぐに止め、送ったデータも消します。'**
  String get settingsLearningWithdrawMessage;

  /// No description provided for @settingsLearningWithdrawConfirm.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get settingsLearningWithdrawConfirm;

  /// No description provided for @settingsLearningCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get settingsLearningCancel;

  /// No description provided for @settingsLearningWithdrawn.
  ///
  /// In ja, this message translates to:
  /// **'撤回しました'**
  String get settingsLearningWithdrawn;

  /// No description provided for @settingsLearningDeclareAgeButton.
  ///
  /// In ja, this message translates to:
  /// **'年齢を申告する'**
  String get settingsLearningDeclareAgeButton;

  /// No description provided for @settingsLearningGranted.
  ///
  /// In ja, this message translates to:
  /// **'参加しました。下のコードを控えておくと、ログインできなくなってもやめられます'**
  String get settingsLearningGranted;

  /// No description provided for @settingsLearningGrantButton.
  ///
  /// In ja, this message translates to:
  /// **'内容を確認して参加する'**
  String get settingsLearningGrantButton;

  /// No description provided for @settingsLearningGrantClosedButton.
  ///
  /// In ja, this message translates to:
  /// **'受付はまだ始まっていません'**
  String get settingsLearningGrantClosedButton;

  /// No description provided for @settingsLearningCodeSection.
  ///
  /// In ja, this message translates to:
  /// **'撤回用のコード'**
  String get settingsLearningCodeSection;

  /// No description provided for @settingsLearningCodeSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'タップでコピー。ログインできなくなっても、このコードでやめられます'**
  String get settingsLearningCodeSubtitle;

  /// No description provided for @settingsLearningCodeCopied.
  ///
  /// In ja, this message translates to:
  /// **'撤回用のコードをコピーしました'**
  String get settingsLearningCodeCopied;

  /// No description provided for @settingsLearningCodeStoredOnGrantDevice.
  ///
  /// In ja, this message translates to:
  /// **'撤回用のコードは、同意した端末に控えてあります。'**
  String get settingsLearningCodeStoredOnGrantDevice;

  /// No description provided for @settingsLearningOtherSection.
  ///
  /// In ja, this message translates to:
  /// **'そのほか'**
  String get settingsLearningOtherSection;

  /// No description provided for @settingsLearningByCodeTitle.
  ///
  /// In ja, this message translates to:
  /// **'撤回用のコードでやめる'**
  String get settingsLearningByCodeTitle;

  /// No description provided for @settingsLearningByCodeSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ログインできなくなったとき'**
  String get settingsLearningByCodeSubtitle;

  /// No description provided for @settingsLearningDeletionCaption.
  ///
  /// In ja, this message translates to:
  /// **'アカウントを削除したときも、送ったデータは消えます。ほかの人が参加しているかは、だれにも調べられません。'**
  String get settingsLearningDeletionCaption;

  /// No description provided for @settingsLearningDeletionCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを削除したときも、提供の停止と提供済みデータの削除が同時に始まります(learning_contributions は accounts の削除で消える)。ほかの人がデータを提供しているかどうかは、だれにも調べられません(GET /me/learning は自分の状態だけ)。'**
  String get settingsLearningDeletionCaptionDetail;

  /// No description provided for @settingsLearningKindsSection.
  ///
  /// In ja, this message translates to:
  /// **'送るもの'**
  String get settingsLearningKindsSection;

  /// No description provided for @settingsLearningKindRelationalTitle.
  ///
  /// In ja, this message translates to:
  /// **'自分の公開投稿'**
  String get settingsLearningKindRelationalTitle;

  /// No description provided for @settingsLearningKindRelationalSubtitleExtended.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインでまとまった会話'**
  String get settingsLearningKindRelationalSubtitleExtended;

  /// No description provided for @settingsLearningKindRelationalSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインで会話にまとまった、あなたの公開の投稿'**
  String get settingsLearningKindRelationalSubtitle;

  /// No description provided for @settingsLearningKindRelationalDetailExtended.
  ///
  /// In ja, this message translates to:
  /// **'会話イベント(束)の公開の投稿。書き手ごとに学習してよいかを判定し、許可の書き手と自分の投稿だけを送る。本文の @メンションと URL は伏せる。'**
  String get settingsLearningKindRelationalDetailExtended;

  /// No description provided for @settingsLearningKindRelationalDetail.
  ///
  /// In ja, this message translates to:
  /// **'D-370。会話イベントの中の自分の投稿(公開と分かるもの)と、その投稿どうしが同じ会話であること(関連のラベル)。ほかの人の投稿は数(参加者・投稿数)だけ。'**
  String get settingsLearningKindRelationalDetail;

  /// No description provided for @settingsLearningUnverifiedNotice.
  ///
  /// In ja, this message translates to:
  /// **'持ち主の確認が済んでいない SNS アカウントの投稿は受け付けられませんでした。プロフィールの編集から確認できます。'**
  String get settingsLearningUnverifiedNotice;

  /// No description provided for @settingsLearningUnverifiedButton.
  ///
  /// In ja, this message translates to:
  /// **'確認する'**
  String get settingsLearningUnverifiedButton;

  /// No description provided for @settingsLearningKindCloudTitle.
  ///
  /// In ja, this message translates to:
  /// **'クラウドでまとめる'**
  String get settingsLearningKindCloudTitle;

  /// No description provided for @settingsLearningKindCloudSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'迷う会話のまとまりを、クラウドの RAi が判断します'**
  String get settingsLearningKindCloudSubtitle;

  /// No description provided for @settingsLearningKindCloudDetail.
  ///
  /// In ja, this message translates to:
  /// **'D-367 / S-050。端末のエンジンがしきい値の近くで決めた結び付き(投稿 → 会話)を POST /me/relational/judge に送り、クラウドの LLM の判定で組み直す。書き手が許可済みの組だけ。判定の例(怪しいけど違う = hard_negative、分けたけど同じ = hard_positive)は学習用に残り、やめると消える。'**
  String get settingsLearningKindCloudDetail;

  /// No description provided for @settingsLearningKindRaiSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'RAi への質問と答え'**
  String get settingsLearningKindRaiSubtitle;

  /// No description provided for @settingsLearningKindRaiDetail.
  ///
  /// In ja, this message translates to:
  /// **'質問(@メンションと URL は伏せる)、答え、モード、使った関数の名前、モデルの id。ほかの人の投稿は含めない。'**
  String get settingsLearningKindRaiDetail;

  /// No description provided for @settingsLearningPreloadTitle.
  ///
  /// In ja, this message translates to:
  /// **'端末のモデルを先に読み込む'**
  String get settingsLearningPreloadTitle;

  /// No description provided for @settingsLearningPreloadSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'判定の下見を早くします(ダウンロード済みのときだけ)'**
  String get settingsLearningPreloadSubtitle;

  /// No description provided for @settingsLearningPreloadDetail.
  ///
  /// In ja, this message translates to:
  /// **'RAi の端末内モデル(既定 Qwen3.5 2B)を起動の少しあとに読み込み、書き手の下見に使う。未ダウンロードならダウンロードはしない(規則だけで下見)。'**
  String get settingsLearningPreloadDetail;

  /// No description provided for @settingsLearningDebugSection.
  ///
  /// In ja, this message translates to:
  /// **'開発者向けの詳細'**
  String get settingsLearningDebugSection;

  /// No description provided for @settingsLearningDebugActiveTitle.
  ///
  /// In ja, this message translates to:
  /// **'集めているか'**
  String get settingsLearningDebugActiveTitle;

  /// No description provided for @settingsLearningDebugActiveYes.
  ///
  /// In ja, this message translates to:
  /// **'はい'**
  String get settingsLearningDebugActiveYes;

  /// No description provided for @settingsLearningDebugActiveNo.
  ///
  /// In ja, this message translates to:
  /// **'いいえ(同意・受付・見守りを確認)'**
  String get settingsLearningDebugActiveNo;

  /// No description provided for @settingsLearningDebugScopeTitle.
  ///
  /// In ja, this message translates to:
  /// **'受け付ける範囲'**
  String get settingsLearningDebugScopeTitle;

  /// No description provided for @settingsLearningDebugScopeExtended.
  ///
  /// In ja, this message translates to:
  /// **'extended(検証用)'**
  String get settingsLearningDebugScopeExtended;

  /// No description provided for @settingsLearningDebugScopeOwn.
  ///
  /// In ja, this message translates to:
  /// **'own(自分の公開投稿だけ)'**
  String get settingsLearningDebugScopeOwn;

  /// No description provided for @settingsLearningDebugPendingTitle.
  ///
  /// In ja, this message translates to:
  /// **'送信待ち'**
  String get settingsLearningDebugPendingTitle;

  /// No description provided for @settingsLearningDebugPendingValue.
  ///
  /// In ja, this message translates to:
  /// **'会話 {relational} ・ RAi {rai}'**
  String settingsLearningDebugPendingValue(String relational, String rai);

  /// No description provided for @settingsLearningDebugSentTitle.
  ///
  /// In ja, this message translates to:
  /// **'この起動で送った'**
  String get settingsLearningDebugSentTitle;

  /// No description provided for @settingsLearningDebugSentValue.
  ///
  /// In ja, this message translates to:
  /// **'会話 {relational} ・ RAi {rai} ・ 見送り {skipped}'**
  String settingsLearningDebugSentValue(
    String relational,
    String rai,
    String skipped,
  );

  /// No description provided for @settingsLearningDebugCloudValue.
  ///
  /// In ja, this message translates to:
  /// **'判定 {decisions}(怪しいけど違う {hardNegative} ・ 分けたけど同じ {hardPositive} ・ 一致 {agree})・ 待ち {pending} ・ 見送り {skipped}'**
  String settingsLearningDebugCloudValue(
    String decisions,
    String hardNegative,
    String hardPositive,
    String agree,
    String pending,
    String skipped,
  );

  /// No description provided for @settingsLearningDebugCloudOff.
  ///
  /// In ja, this message translates to:
  /// **'オフ'**
  String get settingsLearningDebugCloudOff;

  /// No description provided for @settingsLearningDebugModelTitle.
  ///
  /// In ja, this message translates to:
  /// **'端末のモデル'**
  String get settingsLearningDebugModelTitle;

  /// No description provided for @settingsLearningDebugFlushing.
  ///
  /// In ja, this message translates to:
  /// **'送信中…'**
  String get settingsLearningDebugFlushing;

  /// No description provided for @settingsLearningDebugFlushButton.
  ///
  /// In ja, this message translates to:
  /// **'今すぐ送る'**
  String get settingsLearningDebugFlushButton;

  /// No description provided for @settingsLearningDebugVerdictsSection.
  ///
  /// In ja, this message translates to:
  /// **'書き手の判定'**
  String get settingsLearningDebugVerdictsSection;

  /// No description provided for @settingsLearningDebugLogSection.
  ///
  /// In ja, this message translates to:
  /// **'記録'**
  String get settingsLearningDebugLogSection;

  /// No description provided for @settingsLegalTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ、法的表示'**
  String get settingsLegalTitle;

  /// No description provided for @settingsLegalVersionTitle.
  ///
  /// In ja, this message translates to:
  /// **'バージョン'**
  String get settingsLegalVersionTitle;

  /// No description provided for @settingsLegalHelpTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ'**
  String get settingsLegalHelpTitle;

  /// No description provided for @settingsLegalTourTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ の使い方をもう一度見る'**
  String get settingsLegalTourTitle;

  /// No description provided for @settingsLegalCookiesTitle.
  ///
  /// In ja, this message translates to:
  /// **'クッキーについて'**
  String get settingsLegalCookiesTitle;

  /// No description provided for @settingsLegalPluginTermsHeader.
  ///
  /// In ja, this message translates to:
  /// **'SNS プラグインの規約'**
  String get settingsLegalPluginTermsHeader;

  /// No description provided for @settingsLegalPluginNoTerms.
  ///
  /// In ja, this message translates to:
  /// **'規約の記載なし'**
  String get settingsLegalPluginNoTerms;

  /// No description provided for @settingsLegalLicensesHeader.
  ///
  /// In ja, this message translates to:
  /// **'ライセンス'**
  String get settingsLegalLicensesHeader;

  /// No description provided for @settingsLegalLicensesTitle.
  ///
  /// In ja, this message translates to:
  /// **'オープンソースライセンス'**
  String get settingsLegalLicensesTitle;

  /// No description provided for @settingsLegalLicensesSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'Flutter と同梱ライブラリ'**
  String get settingsLegalLicensesSubtitle;

  /// No description provided for @settingsMuteBlockTitle.
  ///
  /// In ja, this message translates to:
  /// **'ミュート/ブロック'**
  String get settingsMuteBlockTitle;

  /// No description provided for @settingsMuteBlockBlockTab.
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get settingsMuteBlockBlockTab;

  /// No description provided for @settingsMuteBlockMuteTab.
  ///
  /// In ja, this message translates to:
  /// **'ミュート'**
  String get settingsMuteBlockMuteTab;

  /// No description provided for @settingsMuteBlockBlockedUsers.
  ///
  /// In ja, this message translates to:
  /// **'ブロックしたユーザー'**
  String get settingsMuteBlockBlockedUsers;

  /// No description provided for @settingsMuteBlockBlockedWords.
  ///
  /// In ja, this message translates to:
  /// **'ブロックしたワード'**
  String get settingsMuteBlockBlockedWords;

  /// No description provided for @settingsMuteBlockBlockedLists.
  ///
  /// In ja, this message translates to:
  /// **'ブロックしたリスト'**
  String get settingsMuteBlockBlockedLists;

  /// No description provided for @settingsMuteBlockComingSoonHint.
  ///
  /// In ja, this message translates to:
  /// **'準備中です'**
  String get settingsMuteBlockComingSoonHint;

  /// No description provided for @settingsMuteBlockComingSoonDetail.
  ///
  /// In ja, this message translates to:
  /// **'ワード/リストのブロックは M2 後半'**
  String get settingsMuteBlockComingSoonDetail;

  /// No description provided for @settingsMuteBlockRetryButton.
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get settingsMuteBlockRetryButton;

  /// No description provided for @settingsMuteBlockNoBlockedUsers.
  ///
  /// In ja, this message translates to:
  /// **'ブロックしたユーザーはいません'**
  String get settingsMuteBlockNoBlockedUsers;

  /// No description provided for @settingsMuteBlockNoMutedUsers.
  ///
  /// In ja, this message translates to:
  /// **'ミュートしたユーザーはいません'**
  String get settingsMuteBlockNoMutedUsers;

  /// No description provided for @settingsMuteBlockBlockButton.
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get settingsMuteBlockBlockButton;

  /// No description provided for @settingsMuteBlockMuteButton.
  ///
  /// In ja, this message translates to:
  /// **'ミュート'**
  String get settingsMuteBlockMuteButton;

  /// No description provided for @settingsMuteBlockBlockingButton.
  ///
  /// In ja, this message translates to:
  /// **'ブロック中'**
  String get settingsMuteBlockBlockingButton;

  /// No description provided for @settingsMuteBlockMutingButton.
  ///
  /// In ja, this message translates to:
  /// **'ミュート中'**
  String get settingsMuteBlockMutingButton;

  /// No description provided for @settingsNotifyTokenTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知専用のアクセストークン'**
  String get settingsNotifyTokenTitle;

  /// No description provided for @settingsNotifyTokenError.
  ///
  /// In ja, this message translates to:
  /// **'できませんでした — {error}'**
  String settingsNotifyTokenError(String error);

  /// No description provided for @settingsNotifyTokenCaption.
  ///
  /// In ja, this message translates to:
  /// **'通知を受け取るためだけの鍵です。投稿やアカウントの操作はできません。'**
  String get settingsNotifyTokenCaption;

  /// No description provided for @settingsNotifyTokenCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'通知トークンは、RASQ サーバーからの通知を受け取るためだけのトークンです(読めるのは自分宛ての通知の受信箱だけ。投稿やアカウントの操作はできません)。マクロ / ASTell 用の配下トークンもここから発行します。'**
  String get settingsNotifyTokenCaptionDetail;

  /// No description provided for @settingsNotifyTokenStatusSection.
  ///
  /// In ja, this message translates to:
  /// **'状態'**
  String get settingsNotifyTokenStatusSection;

  /// No description provided for @settingsNotifyTokenPushTitle.
  ///
  /// In ja, this message translates to:
  /// **'プッシュ配信'**
  String get settingsNotifyTokenPushTitle;

  /// No description provided for @settingsNotifyTokenPushPending.
  ///
  /// In ja, this message translates to:
  /// **'準備中'**
  String get settingsNotifyTokenPushPending;

  /// No description provided for @settingsNotifyTokenPushPendingDetail.
  ///
  /// In ja, this message translates to:
  /// **'ダミー(APNs / FCM は未接続)'**
  String get settingsNotifyTokenPushPendingDetail;

  /// No description provided for @settingsNotifyTokenServerNotConfiguredTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーの接続先が未設定です'**
  String get settingsNotifyTokenServerNotConfiguredTitle;

  /// No description provided for @settingsNotifyTokenServerNotConfiguredSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'接続先を入れると発行できます'**
  String get settingsNotifyTokenServerNotConfiguredSubtitle;

  /// No description provided for @settingsNotifyTokenNoAccountTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントが未作成です'**
  String get settingsNotifyTokenNoAccountTitle;

  /// No description provided for @settingsNotifyTokenNoAccountSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'作成すると通知トークンを発行できます'**
  String get settingsNotifyTokenNoAccountSubtitle;

  /// No description provided for @settingsNotifyTokenLoadError.
  ///
  /// In ja, this message translates to:
  /// **'取得できませんでした: {error}'**
  String settingsNotifyTokenLoadError(String error);

  /// No description provided for @settingsNotifyTokenLocalTokenTitle.
  ///
  /// In ja, this message translates to:
  /// **'この端末のトークン'**
  String get settingsNotifyTokenLocalTokenTitle;

  /// No description provided for @settingsNotifyTokenLocalTokenActive.
  ///
  /// In ja, this message translates to:
  /// **'有効'**
  String get settingsNotifyTokenLocalTokenActive;

  /// No description provided for @settingsNotifyTokenLocalTokenNone.
  ///
  /// In ja, this message translates to:
  /// **'未発行'**
  String get settingsNotifyTokenLocalTokenNone;

  /// No description provided for @settingsNotifyTokenDevicesTitle.
  ///
  /// In ja, this message translates to:
  /// **'プッシュ登録している端末'**
  String get settingsNotifyTokenDevicesTitle;

  /// No description provided for @settingsNotifyTokenDevicesValue.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 台}}'**
  String settingsNotifyTokenDevicesValue(int count);

  /// No description provided for @settingsNotifyTokenTestNotFound.
  ///
  /// In ja, this message translates to:
  /// **'テスト通知を積みましたが、受信箱で見つかりませんでした'**
  String get settingsNotifyTokenTestNotFound;

  /// {title} = テスト通知の題、{status} = 配信の状態、{devices} = 届けた端末の数。
  ///
  /// In ja, this message translates to:
  /// **'受信箱で確認できました: 「{title}」({status}、端末 {devices, plural, other{{devices} 台}})'**
  String settingsNotifyTokenTestFound(String title, String status, int devices);

  /// No description provided for @settingsNotifyTokenTestButton.
  ///
  /// In ja, this message translates to:
  /// **'テスト通知を送る'**
  String get settingsNotifyTokenTestButton;

  /// No description provided for @settingsNotifyTokenLocalRevoked.
  ///
  /// In ja, this message translates to:
  /// **'この端末のトークンを失効しました'**
  String get settingsNotifyTokenLocalRevoked;

  /// No description provided for @settingsNotifyTokenRevokeButton.
  ///
  /// In ja, this message translates to:
  /// **'失効する'**
  String get settingsNotifyTokenRevokeButton;

  /// No description provided for @settingsNotifyTokenEnabled.
  ///
  /// In ja, this message translates to:
  /// **'発行して、この端末をプッシュ登録しました'**
  String get settingsNotifyTokenEnabled;

  /// No description provided for @settingsNotifyTokenEnableButton.
  ///
  /// In ja, this message translates to:
  /// **'通知トークンを発行してこの端末を登録'**
  String get settingsNotifyTokenEnableButton;

  /// No description provided for @settingsNotifyTokenTokensSection.
  ///
  /// In ja, this message translates to:
  /// **'発行済みのトークン'**
  String get settingsNotifyTokenTokensSection;

  /// No description provided for @settingsNotifyTokenKindRoot.
  ///
  /// In ja, this message translates to:
  /// **'通知トークン'**
  String get settingsNotifyTokenKindRoot;

  /// No description provided for @settingsNotifyTokenKindChild.
  ///
  /// In ja, this message translates to:
  /// **'配下トークン'**
  String get settingsNotifyTokenKindChild;

  /// トークンの種類のうしろに付ける名前。
  ///
  /// In ja, this message translates to:
  /// **'({label})'**
  String settingsNotifyTokenLabelSuffix(String label);

  /// No description provided for @settingsNotifyTokenThisDevice.
  ///
  /// In ja, this message translates to:
  /// **'この端末'**
  String get settingsNotifyTokenThisDevice;

  /// No description provided for @settingsNotifyTokenIssuedAt.
  ///
  /// In ja, this message translates to:
  /// **'発行 {time}'**
  String settingsNotifyTokenIssuedAt(String time);

  /// No description provided for @settingsNotifyTokenUnused.
  ///
  /// In ja, this message translates to:
  /// **'未使用'**
  String get settingsNotifyTokenUnused;

  /// No description provided for @settingsNotifyTokenLastUsedAt.
  ///
  /// In ja, this message translates to:
  /// **'最終使用 {time}'**
  String settingsNotifyTokenLastUsedAt(String time);

  /// No description provided for @settingsNotifyTokenIssueChildTooltip.
  ///
  /// In ja, this message translates to:
  /// **'配下トークンを発行(マクロ / ASTell 共用)'**
  String get settingsNotifyTokenIssueChildTooltip;

  /// No description provided for @settingsNotifyTokenChildIssued.
  ///
  /// In ja, this message translates to:
  /// **'配下トークンを発行してクリップボードにコピーしました(生の値が見られるのは今だけです)'**
  String get settingsNotifyTokenChildIssued;

  /// No description provided for @settingsNotifyTokenRevoked.
  ///
  /// In ja, this message translates to:
  /// **'失効しました'**
  String get settingsNotifyTokenRevoked;

  /// No description provided for @settingsNotifyTokenStorageCaption.
  ///
  /// In ja, this message translates to:
  /// **'鍵はこの端末の中に安全に保存します。'**
  String get settingsNotifyTokenStorageCaption;

  /// No description provided for @settingsNotifyTokenStorageCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'生のトークンは発行時にだけ受け取り、端末内の安全な領域に保存します。サーバーに残るのはハッシュだけです。親のトークンを失効すると配下のトークンも失効します。'**
  String get settingsNotifyTokenStorageCaptionDetail;

  /// No description provided for @settingsSectionsPluginsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの構成'**
  String get settingsSectionsPluginsTitle;

  /// No description provided for @settingsSectionsPluginsProxyTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQプラグインプロキシの購読'**
  String get settingsSectionsPluginsProxyTitle;

  /// No description provided for @settingsSectionsPluginsProxySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'準備中'**
  String get settingsSectionsPluginsProxySubtitle;

  /// No description provided for @settingsSectionsPluginsProxyDetail.
  ///
  /// In ja, this message translates to:
  /// **'未購読(第二期)'**
  String get settingsSectionsPluginsProxyDetail;

  /// No description provided for @settingsSectionsPluginsActionBarTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿にプラグインオートメーションを配置'**
  String get settingsSectionsPluginsActionBarTitle;

  /// No description provided for @settingsSectionsPluginsActionBarSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿の下に出すプラグインのボタン'**
  String get settingsSectionsPluginsActionBarSubtitle;

  /// No description provided for @settingsSectionsPluginsActionBarDetail.
  ///
  /// In ja, this message translates to:
  /// **'投稿のアクションバーに出すプラグインボタン(主電源 / 自動でオン / 配置)'**
  String get settingsSectionsPluginsActionBarDetail;

  /// No description provided for @settingsSectionsPluginsTrendTitle.
  ///
  /// In ja, this message translates to:
  /// **'カスタムトレンドの配信'**
  String get settingsSectionsPluginsTrendTitle;

  /// No description provided for @settingsSectionsPluginsComposerTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿プラグイン'**
  String get settingsSectionsPluginsComposerTitle;

  /// No description provided for @settingsSectionsPluginsTimelineTitle.
  ///
  /// In ja, this message translates to:
  /// **'カスタムタイムラインを配置'**
  String get settingsSectionsPluginsTimelineTitle;

  /// No description provided for @settingsSectionsPluginsStoreTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの詳細設定'**
  String get settingsSectionsPluginsStoreTitle;

  /// No description provided for @settingsSectionsPluginsStoreSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインストア(インストール済みの管理)'**
  String get settingsSectionsPluginsStoreSubtitle;

  /// No description provided for @settingsSectionsPluginsTelemetryTitle.
  ///
  /// In ja, this message translates to:
  /// **'怪しい通信の通報'**
  String get settingsSectionsPluginsTelemetryTitle;

  /// No description provided for @settingsSectionsPluginsTelemetrySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'既定はオフ'**
  String get settingsSectionsPluginsTelemetrySubtitle;

  /// No description provided for @settingsSectionsPluginsTelemetryDetail.
  ///
  /// In ja, this message translates to:
  /// **'通信の形の報告: プラグインの通信の形(値は含まない)を、初めて見たときだけストアへ。既定はオフ'**
  String get settingsSectionsPluginsTelemetryDetail;

  /// No description provided for @settingsSectionsSnsTitle.
  ///
  /// In ja, this message translates to:
  /// **'SNSプラグイン'**
  String get settingsSectionsSnsTitle;

  /// No description provided for @settingsSectionsSnsAccountTitle.
  ///
  /// In ja, this message translates to:
  /// **'アカウント'**
  String get settingsSectionsSnsAccountTitle;

  /// No description provided for @settingsSectionsSnsTimelineTitle.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン'**
  String get settingsSectionsSnsTimelineTitle;

  /// No description provided for @settingsSectionsSnsSecurityTitle.
  ///
  /// In ja, this message translates to:
  /// **'セキュリティ'**
  String get settingsSectionsSnsSecurityTitle;

  /// No description provided for @settingsSectionsSnsSafetyTitle.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーとセーフモード'**
  String get settingsSectionsSnsSafetyTitle;

  /// No description provided for @settingsSectionsSnsChildSafeTitle.
  ///
  /// In ja, this message translates to:
  /// **'チャイルドセーフ'**
  String get settingsSectionsSnsChildSafeTitle;

  /// No description provided for @settingsSectionsSnsChildSafeSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'保護者の見守り / チャイルドモード'**
  String get settingsSectionsSnsChildSafeSubtitle;

  /// No description provided for @settingsSectionsSnsChildSafeDetail.
  ///
  /// In ja, this message translates to:
  /// **'保護者として見守る / チャイルドモード(保護者のコードでつなぐ)'**
  String get settingsSectionsSnsChildSafeDetail;

  /// No description provided for @settingsSectionsSnsListsTitle.
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get settingsSectionsSnsListsTitle;

  /// No description provided for @settingsSectionsSnsMuteBlockTitle.
  ///
  /// In ja, this message translates to:
  /// **'ミュート/ブロック'**
  String get settingsSectionsSnsMuteBlockTitle;

  /// No description provided for @settingsSectionsSnsPluginButtonsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインボタン'**
  String get settingsSectionsSnsPluginButtonsTitle;

  /// No description provided for @settingsSectionsSnsPluginButtonsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインのボタンの出し方'**
  String get settingsSectionsSnsPluginButtonsSubtitle;

  /// No description provided for @settingsSectionsSnsPluginButtonsDetail.
  ///
  /// In ja, this message translates to:
  /// **'面ごとの主電源と「開いたとき自動でオン」、このアカウントの有効 / 無効と束ねる閾値'**
  String get settingsSectionsSnsPluginButtonsDetail;

  /// No description provided for @settingsSectionsSnsEmojiSearchTitle.
  ///
  /// In ja, this message translates to:
  /// **'絵文字の検索'**
  String get settingsSectionsSnsEmojiSearchTitle;

  /// No description provided for @settingsSectionsSnsEmojiSearchSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'意味の近い絵文字も探す'**
  String get settingsSectionsSnsEmojiSearchSubtitle;

  /// No description provided for @settingsSectionsSnsEmojiSearchDetail.
  ///
  /// In ja, this message translates to:
  /// **'意味の近い絵文字も探す(端末内のモデル)'**
  String get settingsSectionsSnsEmojiSearchDetail;

  /// No description provided for @settingsSectionsSnsReactionPredictTitle.
  ///
  /// In ja, this message translates to:
  /// **'リアクションの予測'**
  String get settingsSectionsSnsReactionPredictTitle;

  /// No description provided for @settingsSectionsSnsReactionPredictSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'だれも付けていない投稿でも予測するか'**
  String get settingsSectionsSnsReactionPredictSubtitle;

  /// No description provided for @settingsSectionsSnsQuickEmojiTitle.
  ///
  /// In ja, this message translates to:
  /// **'すぐ選べる絵文字'**
  String get settingsSectionsSnsQuickEmojiTitle;

  /// No description provided for @settingsSectionsSnsQuickEmojiSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'リアクションのボタンを長押しして、滑らせて選ぶ絵文字'**
  String get settingsSectionsSnsQuickEmojiSubtitle;

  /// No description provided for @settingsSectionsSnsAccountPickTitle.
  ///
  /// In ja, this message translates to:
  /// **'共有 / リノートに使うアカウント'**
  String get settingsSectionsSnsAccountPickTitle;

  /// No description provided for @settingsSectionsSnsAccountPickSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'同じ投稿が複数のアカウントに見えるとき'**
  String get settingsSectionsSnsAccountPickSubtitle;

  /// No description provided for @settingsSectionsSnsAccountPickDetail.
  ///
  /// In ja, this message translates to:
  /// **'複数のアカウントに見えている投稿を、どのアカウントで扱うか'**
  String get settingsSectionsSnsAccountPickDetail;

  /// No description provided for @settingsSectionsSnsMfmTitle.
  ///
  /// In ja, this message translates to:
  /// **'カスタムモーションとアニメーション'**
  String get settingsSectionsSnsMfmTitle;

  /// No description provided for @settingsSectionsSnsResourcesTitle.
  ///
  /// In ja, this message translates to:
  /// **'リソースと広告'**
  String get settingsSectionsSnsResourcesTitle;

  /// No description provided for @settingsSectionsSnsLegalTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ、法的表示'**
  String get settingsSectionsSnsLegalTitle;

  /// No description provided for @settingsSectionsSnsNote.
  ///
  /// In ja, this message translates to:
  /// **'アカウント / タイムライン / セキュリティ / プライバシーは、使っている SNS のプラグインが用意するページです(プラグインが用意していないものは出ません)。'**
  String get settingsSectionsSnsNote;

  /// No description provided for @settingsSectionsSnsNoteDetail.
  ///
  /// In ja, this message translates to:
  /// **'アカウント / タイムライン / セキュリティ / プライバシーは、設定するアカウントの SNS プラグインが提供する設定ページです(sns.settingsPages。宣言されていないページの行は出さない、D-482)。'**
  String get settingsSectionsSnsNoteDetail;

  /// No description provided for @settingsSectionsAppearanceTitle.
  ///
  /// In ja, this message translates to:
  /// **'アプリの外観'**
  String get settingsSectionsAppearanceTitle;

  /// No description provided for @settingsSectionsAppearanceDisplayTitle.
  ///
  /// In ja, this message translates to:
  /// **'インターフェースの表示サイズ'**
  String get settingsSectionsAppearanceDisplayTitle;

  /// No description provided for @settingsSectionsAppearanceThemeTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォントやカラースキーム'**
  String get settingsSectionsAppearanceThemeTitle;

  /// No description provided for @settingsSectionsAppearanceThemeSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え(色・アイコン・背景の画像)'**
  String get settingsSectionsAppearanceThemeSubtitle;

  /// No description provided for @settingsSectionsAppearanceColumnsTitle.
  ///
  /// In ja, this message translates to:
  /// **'カラムの幅'**
  String get settingsSectionsAppearanceColumnsTitle;

  /// No description provided for @settingsSectionsAppearanceColumnsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'広い画面での左右のカラムの幅'**
  String get settingsSectionsAppearanceColumnsSubtitle;

  /// No description provided for @settingsSectionsAppearanceColumnsDetail.
  ///
  /// In ja, this message translates to:
  /// **'幅の広い画面の小型 / 大型カラムの比(1:1 / 2:3 / 3:5 / 幅を固定)'**
  String get settingsSectionsAppearanceColumnsDetail;

  /// No description provided for @settingsSectionsAppearanceMotionTitle.
  ///
  /// In ja, this message translates to:
  /// **'モーションの抑制'**
  String get settingsSectionsAppearanceMotionTitle;

  /// No description provided for @settingsSectionsAppearanceTimelineTitle.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの表示'**
  String get settingsSectionsAppearanceTimelineTitle;

  /// No description provided for @settingsSectionsAppearanceTimelineSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'タイムラインの「投稿を読み込む」'**
  String get settingsSectionsAppearanceTimelineSubtitle;

  /// No description provided for @settingsSectionsAppearanceTimelineDetail.
  ///
  /// In ja, this message translates to:
  /// **'TL の上下の「投稿を読み込む」'**
  String get settingsSectionsAppearanceTimelineDetail;

  /// No description provided for @settingsSectionsAppearancePipTitle.
  ///
  /// In ja, this message translates to:
  /// **'ピクチャインピクチャ'**
  String get settingsSectionsAppearancePipTitle;

  /// No description provided for @settingsSectionsAppearanceFabTitle.
  ///
  /// In ja, this message translates to:
  /// **'＋ ボタンの割り当て'**
  String get settingsSectionsAppearanceFabTitle;

  /// No description provided for @settingsSectionsAppearanceFabSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'押したときに始めるもの'**
  String get settingsSectionsAppearanceFabSubtitle;

  /// No description provided for @settingsSectionsAppearanceMediaSaveTitle.
  ///
  /// In ja, this message translates to:
  /// **'画像・動画の保存先'**
  String get settingsSectionsAppearanceMediaSaveTitle;

  /// No description provided for @settingsSectionsAppearanceMediaSaveSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'写真(カメラロール)/ ファイル / 保存するたびに選ぶ'**
  String get settingsSectionsAppearanceMediaSaveSubtitle;

  /// No description provided for @settingsSectionsAppearanceNotificationsTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知の表示形式'**
  String get settingsSectionsAppearanceNotificationsTitle;

  /// No description provided for @settingsSectionsAstellTitle.
  ///
  /// In ja, this message translates to:
  /// **'ASTell'**
  String get settingsSectionsAstellTitle;

  /// No description provided for @settingsSectionsAstellSubscriptionTitle.
  ///
  /// In ja, this message translates to:
  /// **'ASTell 4Uを購読'**
  String get settingsSectionsAstellSubscriptionTitle;

  /// No description provided for @settingsSectionsAstellSubscriptionSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'準備中'**
  String get settingsSectionsAstellSubscriptionSubtitle;

  /// No description provided for @settingsSectionsAstellSubscriptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'未購読(第二期)'**
  String get settingsSectionsAstellSubscriptionDetail;

  /// No description provided for @settingsSectionsAstellTilesTitle.
  ///
  /// In ja, this message translates to:
  /// **'Tellタイル'**
  String get settingsSectionsAstellTilesTitle;

  /// No description provided for @settingsSectionsAstellTrendTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドタイムラインへの配信'**
  String get settingsSectionsAstellTrendTitle;

  /// No description provided for @settingsSectionsAstellRoomButtonsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ルームのボタン'**
  String get settingsSectionsAstellRoomButtonsTitle;

  /// No description provided for @settingsSectionsAstellRoomButtonsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'入力欄の左に並ぶボタン'**
  String get settingsSectionsAstellRoomButtonsSubtitle;

  /// No description provided for @settingsSectionsAstellRoomButtonsDetail.
  ///
  /// In ja, this message translates to:
  /// **'ルームの下段、入力欄の左の丸いボタンの並び(並べ替え / 表示 / 非表示 / プラグインのボタンを追加)'**
  String get settingsSectionsAstellRoomButtonsDetail;

  /// No description provided for @settingsSectionsAstellStoreTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの詳細設定'**
  String get settingsSectionsAstellStoreTitle;

  /// No description provided for @settingsSectionsAstellStoreSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ASTell で使うプラグイン'**
  String get settingsSectionsAstellStoreSubtitle;

  /// No description provided for @settingsSectionsAstellStoreDetail.
  ///
  /// In ja, this message translates to:
  /// **'ASTell のアクションプラグイン(ストア)'**
  String get settingsSectionsAstellStoreDetail;

  /// No description provided for @settingsSectionsAstellBackgroundTitle.
  ///
  /// In ja, this message translates to:
  /// **'画面オフ時の動作'**
  String get settingsSectionsAstellBackgroundTitle;

  /// No description provided for @settingsSectionsRelationalTitle.
  ///
  /// In ja, this message translates to:
  /// **'リレーショナルタイムライン'**
  String get settingsSectionsRelationalTitle;

  /// No description provided for @settingsSectionsRelationalClusterTitle.
  ///
  /// In ja, this message translates to:
  /// **'投稿クラスター'**
  String get settingsSectionsRelationalClusterTitle;

  /// No description provided for @settingsSectionsRelationalClusterSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'会話のまとめ方'**
  String get settingsSectionsRelationalClusterSubtitle;

  /// No description provided for @settingsSectionsRelationalClusterDetail.
  ///
  /// In ja, this message translates to:
  /// **'会話イベントの束ね方(束ねやすさ / 重み / 沈むまでの時間)'**
  String get settingsSectionsRelationalClusterDetail;

  /// No description provided for @settingsSectionsRelationalRelayTitle.
  ///
  /// In ja, this message translates to:
  /// **'Relayタイル'**
  String get settingsSectionsRelationalRelayTitle;

  /// No description provided for @settingsSectionsRelationalTrendTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドタイムラインへの配信'**
  String get settingsSectionsRelationalTrendTitle;

  /// No description provided for @settingsSectionsRelationalPluginsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの詳細設定'**
  String get settingsSectionsRelationalPluginsTitle;

  /// No description provided for @settingsSectionsRelationalSamplingTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドのサンプリングレベル'**
  String get settingsSectionsRelationalSamplingTitle;

  /// No description provided for @settingsSectionsRelationalSamplingSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'候補に入れる時間の幅'**
  String get settingsSectionsRelationalSamplingSubtitle;

  /// No description provided for @settingsSectionsRelationalSamplingDetail.
  ///
  /// In ja, this message translates to:
  /// **'候補に入れる時間の幅(束ね判定の詳細設定)'**
  String get settingsSectionsRelationalSamplingDetail;

  /// No description provided for @settingsSectionsRelationalNote.
  ///
  /// In ja, this message translates to:
  /// **'Relay タイルとトレンドへの配信は準備中です。'**
  String get settingsSectionsRelationalNote;

  /// No description provided for @settingsSectionsRelationalNoteDetail.
  ///
  /// In ja, this message translates to:
  /// **'Relay タイルとトレンドへの配信はアルゴリズム確定後(D-011)。'**
  String get settingsSectionsRelationalNoteDetail;

  /// No description provided for @settingsSectionsTrendTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンド'**
  String get settingsSectionsTrendTitle;

  /// No description provided for @settingsSectionsTrendGenresTitle.
  ///
  /// In ja, this message translates to:
  /// **'ジャンル'**
  String get settingsSectionsTrendGenresTitle;

  /// No description provided for @settingsSectionsTrendTendencyTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドの指向性/刺激性'**
  String get settingsSectionsTrendTendencyTitle;

  /// No description provided for @settingsSectionsTrendEmomTitle.
  ///
  /// In ja, this message translates to:
  /// **'EmoM の閾値'**
  String get settingsSectionsTrendEmomTitle;

  /// No description provided for @settingsSectionsTrendEmomSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'運営が制限したトレンドの隠し方 / 閾値の公開'**
  String get settingsSectionsTrendEmomSubtitle;

  /// No description provided for @settingsSectionsTrendEmomDetail.
  ///
  /// In ja, this message translates to:
  /// **'EmoM の閾値(0〜100、既定 50)と「閾値を公開する」(既定オフ)。運営の制限の点数がこの値より大きいトレンドを一覧に出さない (D-404)'**
  String get settingsSectionsTrendEmomDetail;

  /// No description provided for @settingsSectionsTrendPluginsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの詳細設定'**
  String get settingsSectionsTrendPluginsTitle;

  /// No description provided for @settingsSectionsTrendCdnTitle.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュネットワークの設定'**
  String get settingsSectionsTrendCdnTitle;

  /// No description provided for @settingsSectionsTrendCdnSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'準備中'**
  String get settingsSectionsTrendCdnSubtitle;

  /// No description provided for @settingsSectionsTrendCdnDetail.
  ///
  /// In ja, this message translates to:
  /// **'未提供(第二期)'**
  String get settingsSectionsTrendCdnDetail;

  /// No description provided for @settingsSectionsRaiTitle.
  ///
  /// In ja, this message translates to:
  /// **'RAi(アシスタント)'**
  String get settingsSectionsRaiTitle;

  /// No description provided for @settingsSectionsRaiGraphTitle.
  ///
  /// In ja, this message translates to:
  /// **'工程グラフの自動表示'**
  String get settingsSectionsRaiGraphTitle;

  /// No description provided for @settingsSectionsNotificationsTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get settingsSectionsNotificationsTitle;

  /// No description provided for @settingsSectionsNotificationsProfileTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロファイル'**
  String get settingsSectionsNotificationsProfileTitle;

  /// No description provided for @settingsSectionsNotificationsAccessTokenTitle.
  ///
  /// In ja, this message translates to:
  /// **'アクセストークン'**
  String get settingsSectionsNotificationsAccessTokenTitle;

  /// No description provided for @settingsSectionsNotificationsAccessTokenSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'通知を受け取るための設定'**
  String get settingsSectionsNotificationsAccessTokenSubtitle;

  /// No description provided for @settingsSectionsNotificationsAccessTokenDetail.
  ///
  /// In ja, this message translates to:
  /// **'通知専用のトークンの発行 / 失効、端末のプッシュ登録'**
  String get settingsSectionsNotificationsAccessTokenDetail;

  /// No description provided for @settingsSectionsNotificationsSecurityTitle.
  ///
  /// In ja, this message translates to:
  /// **'セキュリティ'**
  String get settingsSectionsNotificationsSecurityTitle;

  /// No description provided for @settingsSectionsNotificationsSecuritySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'SNS の権限とアクセストークン'**
  String get settingsSectionsNotificationsSecuritySubtitle;

  /// No description provided for @settingsSectionsAboutTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQについて'**
  String get settingsSectionsAboutTitle;

  /// No description provided for @settingsSectionsAboutServerTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバー'**
  String get settingsSectionsAboutServerTitle;

  /// No description provided for @settingsSectionsAboutServerSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'つなぐ先のサーバー'**
  String get settingsSectionsAboutServerSubtitle;

  /// No description provided for @settingsSectionsAboutServerDetail.
  ///
  /// In ja, this message translates to:
  /// **'プラグインストア / RASQ アカウント / ログインの接続先'**
  String get settingsSectionsAboutServerDetail;

  /// No description provided for @settingsSectionsAboutHelpTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ'**
  String get settingsSectionsAboutHelpTitle;

  /// No description provided for @settingsSectionsAboutTourTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ の使い方をもう一度見る'**
  String get settingsSectionsAboutTourTitle;

  /// No description provided for @settingsSectionsAboutTourSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'機能の紹介(TL・トレンド・ASTell・RAi など)'**
  String get settingsSectionsAboutTourSubtitle;

  /// No description provided for @settingsSectionsAboutSubscriptionTitle.
  ///
  /// In ja, this message translates to:
  /// **'購読状況'**
  String get settingsSectionsAboutSubscriptionTitle;

  /// No description provided for @settingsSectionsAboutCookiesTitle.
  ///
  /// In ja, this message translates to:
  /// **'クッキーについて'**
  String get settingsSectionsAboutCookiesTitle;

  /// No description provided for @settingsSectionsAboutPrivacyTitle.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get settingsSectionsAboutPrivacyTitle;

  /// No description provided for @settingsSectionsAboutTermsTitle.
  ///
  /// In ja, this message translates to:
  /// **'利用規約'**
  String get settingsSectionsAboutTermsTitle;

  /// No description provided for @settingsSectionsAboutLearningTitle.
  ///
  /// In ja, this message translates to:
  /// **'アルゴリズムとコミュニティへの貢献'**
  String get settingsSectionsAboutLearningTitle;

  /// No description provided for @settingsSectionsAboutLearningSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'任意。既定は「提供しない」'**
  String get settingsSectionsAboutLearningSubtitle;

  /// No description provided for @settingsSectionsAboutAstellTermsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ASTell の利用条件'**
  String get settingsSectionsAboutAstellTermsTitle;

  /// No description provided for @settingsSectionsAboutRaiTermsTitle.
  ///
  /// In ja, this message translates to:
  /// **'RAi の利用条件'**
  String get settingsSectionsAboutRaiTermsTitle;

  /// No description provided for @settingsSectionsAboutStoreTermsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインストアの利用条件'**
  String get settingsSectionsAboutStoreTermsTitle;

  /// No description provided for @settingsSectionsAboutDevTermsTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン開発者の掲載・審査条件'**
  String get settingsSectionsAboutDevTermsTitle;

  /// No description provided for @settingsSectionsAboutDevTermsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'審査料を含む'**
  String get settingsSectionsAboutDevTermsSubtitle;

  /// No description provided for @settingsSectionsAboutBillingTitle.
  ///
  /// In ja, this message translates to:
  /// **'料金・ポイントの条件'**
  String get settingsSectionsAboutBillingTitle;

  /// No description provided for @settingsSectionsAboutCommerceTitle.
  ///
  /// In ja, this message translates to:
  /// **'特定商取引法に基づく表記'**
  String get settingsSectionsAboutCommerceTitle;

  /// No description provided for @settingsSectionsAboutResourcesTitle.
  ///
  /// In ja, this message translates to:
  /// **'リソースと広告'**
  String get settingsSectionsAboutResourcesTitle;

  /// No description provided for @settingsSectionsAboutLegalTitle.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ、法的表示'**
  String get settingsSectionsAboutLegalTitle;

  /// No description provided for @settingsSectionsAboutDeveloperTitle.
  ///
  /// In ja, this message translates to:
  /// **'開発者モード'**
  String get settingsSectionsAboutDeveloperTitle;

  /// No description provided for @settingsSectionsAboutDeveloperSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'画面の説明を詳しく表示する'**
  String get settingsSectionsAboutDeveloperSubtitle;

  /// No description provided for @settingsSecurityAgoJustNow.
  ///
  /// In ja, this message translates to:
  /// **'たった今'**
  String get settingsSecurityAgoJustNow;

  /// No description provided for @settingsSecurityAgoMinutes.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 分前}}'**
  String settingsSecurityAgoMinutes(int count);

  /// No description provided for @settingsSecurityAgoHours.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 時間前}}'**
  String settingsSecurityAgoHours(int count);

  /// No description provided for @settingsSecurityAgoDays.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 日前}}'**
  String settingsSecurityAgoDays(int count);

  /// 確認コードを送ったときのお知らせ。to は送り先(メールアドレスの目安)
  ///
  /// In ja, this message translates to:
  /// **'{to} へ確認コードを送りました'**
  String settingsSecurityCodeSentTo(String to);

  /// No description provided for @settingsSecurityTitle.
  ///
  /// In ja, this message translates to:
  /// **'アカウントのセキュリティ'**
  String get settingsSecurityTitle;

  /// No description provided for @settingsSecurityNotSignedIn.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインしていません。'**
  String get settingsSecurityNotSignedIn;

  /// No description provided for @settingsSecurityToLoginTitle.
  ///
  /// In ja, this message translates to:
  /// **'既存の RASQ アカウントにログイン'**
  String get settingsSecurityToLoginTitle;

  /// No description provided for @settingsSecurityToLoginSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル(かメール)とパスワード'**
  String get settingsSecurityToLoginSubtitle;

  /// No description provided for @settingsSecurityEmailHeader.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレス'**
  String get settingsSecurityEmailHeader;

  /// No description provided for @settingsSecurityEmailCaption.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを忘れたときの再設定と、ログインの 2 段階目の確認に使います。ほかの人には見えません。'**
  String get settingsSecurityEmailCaption;

  /// No description provided for @settingsSecurityEmailDetail.
  ///
  /// In ja, this message translates to:
  /// **'登録すると、パスワードを忘れたときの再設定、ほかの端末からログインするときの 2 段階目の確認(パスワードのあとにメールの確認コード)、大事な操作の確認とお知らせに使えます。メールを確認していないと、パスワードを忘れたときに再設定できません。ほかの人には見えません。'**
  String get settingsSecurityEmailDetail;

  /// No description provided for @settingsSecurityEmailCurrentTitle.
  ///
  /// In ja, this message translates to:
  /// **'いまのメール'**
  String get settingsSecurityEmailCurrentTitle;

  /// No description provided for @settingsSecurityEmailUnregistered.
  ///
  /// In ja, this message translates to:
  /// **'未登録'**
  String get settingsSecurityEmailUnregistered;

  /// No description provided for @settingsSecurityEmailNewHint.
  ///
  /// In ja, this message translates to:
  /// **'新しいメールアドレス'**
  String get settingsSecurityEmailNewHint;

  /// No description provided for @settingsSecurityEmailHint.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレス'**
  String get settingsSecurityEmailHint;

  /// No description provided for @settingsSecuritySendCodeButton.
  ///
  /// In ja, this message translates to:
  /// **'コードを送る'**
  String get settingsSecuritySendCodeButton;

  /// No description provided for @settingsSecurityEmailChangeNeedsPasswordOrCode.
  ///
  /// In ja, this message translates to:
  /// **'付け替えるには、いまのパスワードか、いまのメールに届く確認コードが要ります。'**
  String get settingsSecurityEmailChangeNeedsPasswordOrCode;

  /// No description provided for @settingsSecurityEmailChangeNeedsCode.
  ///
  /// In ja, this message translates to:
  /// **'付け替えるには、いまのメールに届く確認コードが要ります。'**
  String get settingsSecurityEmailChangeNeedsCode;

  /// No description provided for @settingsSecurityCurrentPasswordHint.
  ///
  /// In ja, this message translates to:
  /// **'いまのパスワード'**
  String get settingsSecurityCurrentPasswordHint;

  /// No description provided for @settingsSecurityEmailSendCodeToCurrentButton.
  ///
  /// In ja, this message translates to:
  /// **'いまのメールにコードを送る'**
  String get settingsSecurityEmailSendCodeToCurrentButton;

  /// No description provided for @settingsSecurityEmailNeedsPassword.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを設定したアカウントでは、メールアドレスを付けるのにいまのパスワードが要ります。'**
  String get settingsSecurityEmailNeedsPassword;

  /// email は確認待ちのメールアドレス
  ///
  /// In ja, this message translates to:
  /// **'{email} に届いたコードを入れてください(15 分で無効になります)。'**
  String settingsSecurityEmailPendingCaption(String email);

  /// No description provided for @settingsSecurityEmailVerified.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを確認しました'**
  String get settingsSecurityEmailVerified;

  /// No description provided for @settingsSecurityVerifyButton.
  ///
  /// In ja, this message translates to:
  /// **'確認'**
  String get settingsSecurityVerifyButton;

  /// No description provided for @settingsSecurityEmailRemoveTitle.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを外す'**
  String get settingsSecurityEmailRemoveTitle;

  /// No description provided for @settingsSecurityEmailRemoveSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'確認コードが要ります'**
  String get settingsSecurityEmailRemoveSubtitle;

  /// No description provided for @settingsSecurityPasswordHeader.
  ///
  /// In ja, this message translates to:
  /// **'パスワード'**
  String get settingsSecurityPasswordHeader;

  /// No description provided for @settingsSecurityPasswordChangeCaption.
  ///
  /// In ja, this message translates to:
  /// **'変えると、ほかの端末はログアウトになります。いまのパスワードか、メールの確認コードが要ります。'**
  String get settingsSecurityPasswordChangeCaption;

  /// No description provided for @settingsSecurityPasswordNoneCaption.
  ///
  /// In ja, this message translates to:
  /// **'パスワードが無いと、ほかの端末からはログインできません(この端末でだけ使えます)。付けると、別の端末からハンドル(かメール)とパスワードで同じアカウントに入れます。'**
  String get settingsSecurityPasswordNoneCaption;

  /// No description provided for @settingsSecurityPasswordNewHint.
  ///
  /// In ja, this message translates to:
  /// **'新しいパスワード(8 文字以上)'**
  String get settingsSecurityPasswordNewHint;

  /// No description provided for @settingsSecurityPasswordHint.
  ///
  /// In ja, this message translates to:
  /// **'パスワード(8 文字以上)'**
  String get settingsSecurityPasswordHint;

  /// No description provided for @settingsSecurityPasswordChanged.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを変えました'**
  String get settingsSecurityPasswordChanged;

  /// No description provided for @settingsSecurityPasswordSet.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを設定しました'**
  String get settingsSecurityPasswordSet;

  /// No description provided for @settingsSecurityPasswordChangeButton.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを変える'**
  String get settingsSecurityPasswordChangeButton;

  /// No description provided for @settingsSecurityPasswordSetButton.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを設定'**
  String get settingsSecurityPasswordSetButton;

  /// No description provided for @settingsSecurityPasswordByCodeButton.
  ///
  /// In ja, this message translates to:
  /// **'メールのコードで変える'**
  String get settingsSecurityPasswordByCodeButton;

  /// No description provided for @settingsSecurityPasswordResetWarning.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを「再設定」すると、同期した設定は読めなくなります。'**
  String get settingsSecurityPasswordResetWarning;

  /// No description provided for @settingsSecurityPasswordResetWarningDetail.
  ///
  /// In ja, this message translates to:
  /// **'パスワードは、同期した設定の暗号化にも使います。「パスワードの再設定」(ログイン画面)をすると、前のパスワードで暗号化したデータは復号できなくなります。'**
  String get settingsSecurityPasswordResetWarningDetail;

  /// No description provided for @settingsSecuritySecondFactorHeader.
  ///
  /// In ja, this message translates to:
  /// **'ログインの 2 段階目'**
  String get settingsSecuritySecondFactorHeader;

  /// No description provided for @settingsSecuritySecondFactorNeedsEmailCaption.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを確認すると、ほかの端末からログインするとき、パスワードのあとにメールの確認コードも求めます(既定で ON)。'**
  String get settingsSecuritySecondFactorNeedsEmailCaption;

  /// No description provided for @settingsSecuritySecondFactorActiveCaption.
  ///
  /// In ja, this message translates to:
  /// **'ほかの端末からログインするとき、パスワードのあとに、メールに届く確認コード(10 分有効)も求めます。'**
  String get settingsSecuritySecondFactorActiveCaption;

  /// No description provided for @settingsSecuritySecondFactorOffCaption.
  ///
  /// In ja, this message translates to:
  /// **'切っています。ほかの端末からは、パスワードだけでログインできます。'**
  String get settingsSecuritySecondFactorOffCaption;

  /// No description provided for @settingsSecuritySecondFactorTitle.
  ///
  /// In ja, this message translates to:
  /// **'メールの確認コードも求める'**
  String get settingsSecuritySecondFactorTitle;

  /// No description provided for @settingsSecuritySecondFactorNeedsEmailSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスの確認が要ります'**
  String get settingsSecuritySecondFactorNeedsEmailSubtitle;

  /// No description provided for @settingsSecuritySecondFactorEnabled.
  ///
  /// In ja, this message translates to:
  /// **'ログインの 2 段階目を入れました'**
  String get settingsSecuritySecondFactorEnabled;

  /// No description provided for @settingsSecuritySecondFactorDisableNeedsPasswordOrCode.
  ///
  /// In ja, this message translates to:
  /// **'切るには、いまのパスワードか、メールに届く確認コードが要ります。'**
  String get settingsSecuritySecondFactorDisableNeedsPasswordOrCode;

  /// No description provided for @settingsSecuritySecondFactorDisableNeedsCode.
  ///
  /// In ja, this message translates to:
  /// **'切るには、メールに届く確認コードが要ります。'**
  String get settingsSecuritySecondFactorDisableNeedsCode;

  /// No description provided for @settingsSecuritySendCodeToEmailButton.
  ///
  /// In ja, this message translates to:
  /// **'メールにコードを送る'**
  String get settingsSecuritySendCodeToEmailButton;

  /// No description provided for @settingsSecurityCancelButton.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get settingsSecurityCancelButton;

  /// No description provided for @settingsSecuritySecondFactorDisabled.
  ///
  /// In ja, this message translates to:
  /// **'ログインの 2 段階目を切りました'**
  String get settingsSecuritySecondFactorDisabled;

  /// No description provided for @settingsSecuritySecondFactorDisableButton.
  ///
  /// In ja, this message translates to:
  /// **'2 段階目を切る'**
  String get settingsSecuritySecondFactorDisableButton;

  /// No description provided for @settingsSecuritySessionsHeader.
  ///
  /// In ja, this message translates to:
  /// **'ログイン中の端末'**
  String get settingsSecuritySessionsHeader;

  /// No description provided for @settingsSecuritySessionsRevokedOthers.
  ///
  /// In ja, this message translates to:
  /// **'ほかの {count, plural, other{{count} 台}}をログアウトさせました'**
  String settingsSecuritySessionsRevokedOthers(int count);

  /// No description provided for @settingsSecuritySessionsRevokeOthersButton.
  ///
  /// In ja, this message translates to:
  /// **'ほかを全部ログアウト'**
  String get settingsSecuritySessionsRevokeOthersButton;

  /// No description provided for @settingsSecuritySessionUnnamed.
  ///
  /// In ja, this message translates to:
  /// **'名前のない端末'**
  String get settingsSecuritySessionUnnamed;

  /// 端末の一覧で、この端末の名前のうしろに付ける
  ///
  /// In ja, this message translates to:
  /// **'(この端末)'**
  String get settingsSecurityThisDeviceSuffix;

  /// ago は「3 分前」などの経過時間
  ///
  /// In ja, this message translates to:
  /// **'最後に使った: {ago}'**
  String settingsSecuritySessionLastUsed(String ago);

  /// date はログインの期限の日付(YYYY-MM-DD)
  ///
  /// In ja, this message translates to:
  /// **'期限 {date}'**
  String settingsSecuritySessionExpires(String date);

  /// No description provided for @settingsSecuritySessionRevoked.
  ///
  /// In ja, this message translates to:
  /// **'ログアウトさせました'**
  String get settingsSecuritySessionRevoked;

  /// No description provided for @settingsSecuritySessionLogoutButton.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get settingsSecuritySessionLogoutButton;

  /// No description provided for @settingsSecurityConfirmDeleteHeader.
  ///
  /// In ja, this message translates to:
  /// **'アカウントの削除の確認'**
  String get settingsSecurityConfirmDeleteHeader;

  /// No description provided for @settingsSecurityConfirmEmailRemoveHeader.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを外す確認'**
  String get settingsSecurityConfirmEmailRemoveHeader;

  /// to は確認コードの送り先(メールアドレスの目安)
  ///
  /// In ja, this message translates to:
  /// **'{to} に届いたコードを入れてください。'**
  String settingsSecurityConfirmCodeCaption(String to);

  /// No description provided for @settingsSecurityDeleteButton.
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get settingsSecurityDeleteButton;

  /// No description provided for @settingsSecurityRemoveButton.
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get settingsSecurityRemoveButton;

  /// No description provided for @settingsSecurityDeleteHeader.
  ///
  /// In ja, this message translates to:
  /// **'アカウントの削除'**
  String get settingsSecurityDeleteHeader;

  /// No description provided for @settingsSecurityDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを削除'**
  String get settingsSecurityDeleteTitle;

  /// No description provided for @settingsSecurityDeleteSubtitleWithEmail.
  ///
  /// In ja, this message translates to:
  /// **'メールの確認コードが要ります。元に戻せません'**
  String get settingsSecurityDeleteSubtitleWithEmail;

  /// No description provided for @settingsSecurityDeleteSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'元に戻せません'**
  String get settingsSecurityDeleteSubtitle;

  /// No description provided for @settingsSecurityRolesHeader.
  ///
  /// In ja, this message translates to:
  /// **'役割'**
  String get settingsSecurityRolesHeader;

  /// No description provided for @settingsSecurityRolesTitle.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントの役割'**
  String get settingsSecurityRolesTitle;

  /// No description provided for @settingsSecurityRoleDeveloper.
  ///
  /// In ja, this message translates to:
  /// **'開発者'**
  String get settingsSecurityRoleDeveloper;

  /// No description provided for @settingsSecurityRoleReviewer.
  ///
  /// In ja, this message translates to:
  /// **'審査員'**
  String get settingsSecurityRoleReviewer;

  /// No description provided for @settingsSecurityEmailReplaceNeedsPasswordOrCodeError.
  ///
  /// In ja, this message translates to:
  /// **'いまのパスワードを入れるか、いまのメールに届く確認コードで確かめてください'**
  String get settingsSecurityEmailReplaceNeedsPasswordOrCodeError;

  /// No description provided for @settingsSecurityEmailReplaceNeedsCodeError.
  ///
  /// In ja, this message translates to:
  /// **'いまのメールに届く確認コードで確かめてください'**
  String get settingsSecurityEmailReplaceNeedsCodeError;

  /// No description provided for @settingsSecurityEnterCurrentPasswordError.
  ///
  /// In ja, this message translates to:
  /// **'いまのパスワードを入れてください'**
  String get settingsSecurityEnterCurrentPasswordError;

  /// No description provided for @settingsSecurityCodeSent.
  ///
  /// In ja, this message translates to:
  /// **'確認コードを送りました'**
  String get settingsSecurityCodeSent;

  /// No description provided for @settingsSecurityDeleteConfirmMessage.
  ///
  /// In ja, this message translates to:
  /// **'サーバー上のプロフィール、アカウントバンドル、同期した設定、レビューとブックマーク、ASTell のルームと共有、通知トークン、同意の記録を削除します。元に戻せません。'**
  String get settingsSecurityDeleteConfirmMessage;

  /// No description provided for @settingsSecuritySendConfirmCodeButton.
  ///
  /// In ja, this message translates to:
  /// **'確認コードを送る'**
  String get settingsSecuritySendConfirmCodeButton;

  /// No description provided for @settingsSecurityDeleted.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを削除しました'**
  String get settingsSecurityDeleted;

  /// No description provided for @settingsSecurityEmailRemoved.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを外しました'**
  String get settingsSecurityEmailRemoved;

  /// No description provided for @settingsSecurityCodeHint.
  ///
  /// In ja, this message translates to:
  /// **'確認コード(例 3mJr7-AoUXx)'**
  String get settingsSecurityCodeHint;

  /// No description provided for @settingsSecurityCodeHelper.
  ///
  /// In ja, this message translates to:
  /// **'メールのリンクを貼り付けても確認できます'**
  String get settingsSecurityCodeHelper;

  /// No description provided for @settingsSecurityLoginFailedHelp.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル(メール)かパスワードが違います。\nパスワードを設定していない RASQ アカウントには、ほかの端末からはログインできません。そのアカウントを作った端末(いまもログインしている端末)で「設定 → アカウントのセキュリティ」からパスワードを設定してから、もう一度ログインしてください。'**
  String get settingsSecurityLoginFailedHelp;

  /// No description provided for @settingsSecurityServerNotConfiguredError.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーの接続先が未設定です'**
  String get settingsSecurityServerNotConfiguredError;

  /// No description provided for @settingsSecurityLoginFailed.
  ///
  /// In ja, this message translates to:
  /// **'ログインできませんでした'**
  String get settingsSecurityLoginFailed;

  /// handle は RASQ アカウントのハンドル(@ を除く)
  ///
  /// In ja, this message translates to:
  /// **'@{handle} にログインしました'**
  String settingsSecurityLoggedInAs(String handle);

  /// No description provided for @settingsSecurityLoginEnterCredentialsError.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル(かメール)とパスワードを入れてください'**
  String get settingsSecurityLoginEnterCredentialsError;

  /// No description provided for @settingsSecurityVerifiedEmailFallback.
  ///
  /// In ja, this message translates to:
  /// **'確認済みのメール'**
  String get settingsSecurityVerifiedEmailFallback;

  /// No description provided for @settingsSecurityLoginTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログイン'**
  String get settingsSecurityLoginTitle;

  /// No description provided for @settingsSecurityLoginCaption.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル(@ は無くてもよい)か確認済みのメールアドレスと、パスワードで入ります。'**
  String get settingsSecurityLoginCaption;

  /// No description provided for @settingsSecurityLoginDetail.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル(@ は無くてもよい)か確認済みのメールアドレスと、パスワードで入ります。確認済みのメールがあるアカウントは、そのあとメールに届く確認コードも入れます(2 段階目の確認)。'**
  String get settingsSecurityLoginDetail;

  /// No description provided for @settingsSecurityLoginIdentifierHint.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル または メールアドレス'**
  String get settingsSecurityLoginIdentifierHint;

  /// No description provided for @settingsSecurityLoginPasswordHint.
  ///
  /// In ja, this message translates to:
  /// **'パスワード'**
  String get settingsSecurityLoginPasswordHint;

  /// No description provided for @settingsSecurityLoginButton.
  ///
  /// In ja, this message translates to:
  /// **'ログイン'**
  String get settingsSecurityLoginButton;

  /// No description provided for @settingsSecurityLoginForgotButton.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを忘れた'**
  String get settingsSecurityLoginForgotButton;

  /// No description provided for @settingsSecurityLoginNoPasswordHint.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを設定していないアカウントは、ほかの端末からはログインできません(作った端末でだけ使えます)。その端末の「設定 → アカウントのセキュリティ」でパスワードを設定してください。'**
  String get settingsSecurityLoginNoPasswordHint;

  /// No description provided for @settingsSecurityLoginCodeHeader.
  ///
  /// In ja, this message translates to:
  /// **'確認コード'**
  String get settingsSecurityLoginCodeHeader;

  /// email は確認コードの送り先、minutes はコードの有効な分数
  ///
  /// In ja, this message translates to:
  /// **'{email} に確認コードを送りました({minutes, plural, other{{minutes} 分有効}}、1 回きり)。届いたコードを入れてください。'**
  String settingsSecurityLoginChallengeCaption(String email, int minutes);

  /// No description provided for @settingsSecurityVerifiedEmailAddressFallback.
  ///
  /// In ja, this message translates to:
  /// **'確認済みのメールアドレス'**
  String get settingsSecurityVerifiedEmailAddressFallback;

  /// No description provided for @settingsSecurityLoginConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'確認してログイン'**
  String get settingsSecurityLoginConfirmButton;

  /// No description provided for @settingsSecurityLoginResendButton.
  ///
  /// In ja, this message translates to:
  /// **'コードを送り直す'**
  String get settingsSecurityLoginResendButton;

  /// No description provided for @settingsSecurityLoginBackButton.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル / パスワードに戻る'**
  String get settingsSecurityLoginBackButton;

  /// No description provided for @settingsSecurityLoginNoMailHint.
  ///
  /// In ja, this message translates to:
  /// **'メールが届かないときは、迷惑メールのフォルダも見てください。ログインに心当たりが無いメールが届いたら、パスワードを変えてください。'**
  String get settingsSecurityLoginNoMailHint;

  /// No description provided for @settingsSecurityLoginChildHeader.
  ///
  /// In ja, this message translates to:
  /// **'子のアカウント'**
  String get settingsSecurityLoginChildHeader;

  /// No description provided for @settingsSecurityLoginChildTitle.
  ///
  /// In ja, this message translates to:
  /// **'保護者からのコードでログイン'**
  String get settingsSecurityLoginChildTitle;

  /// No description provided for @settingsSecurityLoginChildSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'保護者が作った子のアカウントに入ります'**
  String get settingsSecurityLoginChildSubtitle;

  /// No description provided for @settingsSecurityResetEnterEmailError.
  ///
  /// In ja, this message translates to:
  /// **'確認済みのメールアドレスを入れてください'**
  String get settingsSecurityResetEnterEmailError;

  /// No description provided for @settingsSecurityResetCodeSent.
  ///
  /// In ja, this message translates to:
  /// **'そのメールアドレスを確認済みのアカウントがあれば、確認コードを送りました(10 分有効)'**
  String get settingsSecurityResetCodeSent;

  /// count はログアウトさせた端末の数
  ///
  /// In ja, this message translates to:
  /// **'パスワードを再設定しました。ほかの {count, plural, other{{count} 台}}の端末をログアウトしました'**
  String settingsSecurityResetDoneKept(int count);

  /// count はログアウトさせた端末の数
  ///
  /// In ja, this message translates to:
  /// **'パスワードを再設定しました({count, plural, other{{count} 台}}の端末をログアウトしました)。新しいパスワードでログインしてください'**
  String settingsSecurityResetDone(int count);

  /// No description provided for @settingsSecurityResetTitle.
  ///
  /// In ja, this message translates to:
  /// **'パスワードの再設定'**
  String get settingsSecurityResetTitle;

  /// No description provided for @settingsSecurityResetCaption.
  ///
  /// In ja, this message translates to:
  /// **'確認済みのメールアドレスへ確認コード(10 分有効、1 回きり)を送り、新しいパスワードを決めます。ほかの端末はすべてログアウトになります。'**
  String get settingsSecurityResetCaption;

  /// No description provided for @settingsSecurityResetNoEmailWarning.
  ///
  /// In ja, this message translates to:
  /// **'メールアドレスを確認していないアカウントは、パスワードを再設定できません。'**
  String get settingsSecurityResetNoEmailWarning;

  /// No description provided for @settingsSecurityResetNoEmailDetail.
  ///
  /// In ja, this message translates to:
  /// **'そのアカウントを作った端末(いまもログインしている端末)で「設定 → アカウントのセキュリティ」から新しいパスワードを設定してください。その端末も無いときは、アカウントに戻る方法はありません。'**
  String get settingsSecurityResetNoEmailDetail;

  /// No description provided for @settingsSecurityResetEmailHint.
  ///
  /// In ja, this message translates to:
  /// **'確認済みのメールアドレス'**
  String get settingsSecurityResetEmailHint;

  /// No description provided for @settingsSecurityResendButton.
  ///
  /// In ja, this message translates to:
  /// **'送り直す'**
  String get settingsSecurityResendButton;

  /// count はパスワードの最小の文字数
  ///
  /// In ja, this message translates to:
  /// **'新しいパスワード({count, plural, other{{count} 文字以上}})'**
  String settingsSecurityResetNewPasswordHint(int count);

  /// No description provided for @settingsSecurityResetConfirmPasswordHint.
  ///
  /// In ja, this message translates to:
  /// **'新しいパスワード(確認)'**
  String get settingsSecurityResetConfirmPasswordHint;

  /// No description provided for @settingsSecurityResetMismatchError.
  ///
  /// In ja, this message translates to:
  /// **'一致しません'**
  String get settingsSecurityResetMismatchError;

  /// No description provided for @settingsSecurityResetKeepTitle.
  ///
  /// In ja, this message translates to:
  /// **'この端末のログインは残す'**
  String get settingsSecurityResetKeepTitle;

  /// No description provided for @settingsSecurityResetKeepSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'いまこの端末でログインしているアカウントの再設定のときだけ残ります'**
  String get settingsSecurityResetKeepSubtitle;

  /// No description provided for @settingsSecurityResetSyncWarning.
  ///
  /// In ja, this message translates to:
  /// **'再設定すると、同期した設定は読めなくなります。'**
  String get settingsSecurityResetSyncWarning;

  /// No description provided for @settingsSecurityResetSyncWarningDetail.
  ///
  /// In ja, this message translates to:
  /// **'パスワードは、同期した設定の暗号化にも使います。前のパスワードで暗号化したデータは復号できなくなります。'**
  String get settingsSecurityResetSyncWarningDetail;

  /// No description provided for @settingsSecurityResetSubmitButton.
  ///
  /// In ja, this message translates to:
  /// **'パスワードを再設定'**
  String get settingsSecurityResetSubmitButton;

  /// No description provided for @settingsSnsShareConflictError.
  ///
  /// In ja, this message translates to:
  /// **'ほかの端末が先に変えました。もう一度お試しください'**
  String get settingsSnsShareConflictError;

  /// No description provided for @settingsSnsShareOffConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'SNS のログインの共有をやめますか?'**
  String get settingsSnsShareOffConfirmTitle;

  /// No description provided for @settingsSnsShareOffConfirmMessage.
  ///
  /// In ja, this message translates to:
  /// **'共有のデータと、すべての端末の鍵を消します。各端末の SNS のログインはそのまま残ります。'**
  String get settingsSnsShareOffConfirmMessage;

  /// No description provided for @settingsSnsShareOffConfirmDetail.
  ///
  /// In ja, this message translates to:
  /// **'RASQ Central にある共有の中身(暗号化したもの)と、すべての端末の鍵を消します。それぞれの端末の SNS のログインはそのまま残ります。'**
  String get settingsSnsShareOffConfirmDetail;

  /// No description provided for @settingsSnsShareOffConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get settingsSnsShareOffConfirmButton;

  /// No description provided for @settingsSnsShareCancelButton.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get settingsSnsShareCancelButton;

  /// No description provided for @settingsSnsShareStopped.
  ///
  /// In ja, this message translates to:
  /// **'共有をやめました'**
  String get settingsSnsShareStopped;

  /// No description provided for @settingsSnsShareSubtitleLoading.
  ///
  /// In ja, this message translates to:
  /// **'読み込み中…'**
  String get settingsSnsShareSubtitleLoading;

  /// No description provided for @settingsSnsShareSubtitleUnsupported.
  ///
  /// In ja, this message translates to:
  /// **'この端末のログインは共有に対応していません。ログインし直してください'**
  String get settingsSnsShareSubtitleUnsupported;

  /// No description provided for @settingsSnsShareSubtitleOffAsk.
  ///
  /// In ja, this message translates to:
  /// **'オフ(別の端末でログインしたときに聞きます)'**
  String get settingsSnsShareSubtitleOffAsk;

  /// No description provided for @settingsSnsShareSubtitleOff.
  ///
  /// In ja, this message translates to:
  /// **'オフ'**
  String get settingsSnsShareSubtitleOff;

  /// No description provided for @settingsSnsShareSubtitleOnHolding.
  ///
  /// In ja, this message translates to:
  /// **'オン ・ この端末は共有しています'**
  String get settingsSnsShareSubtitleOnHolding;

  /// No description provided for @settingsSnsShareSubtitleOnWaiting.
  ///
  /// In ja, this message translates to:
  /// **'オン ・ 共有している端末での承認を待っています'**
  String get settingsSnsShareSubtitleOnWaiting;

  /// No description provided for @settingsSnsShareSubtitleOnNotYet.
  ///
  /// In ja, this message translates to:
  /// **'オン ・ この端末は、まだ共有していません'**
  String get settingsSnsShareSubtitleOnNotYet;

  /// No description provided for @settingsSnsShareHeader.
  ///
  /// In ja, this message translates to:
  /// **'SNS のログインを端末間で共有'**
  String get settingsSnsShareHeader;

  /// No description provided for @settingsSnsShareCaption.
  ///
  /// In ja, this message translates to:
  /// **'新しい端末でも、SNS に自動でログインできます。中身は暗号化され、RASQ のサーバーは読めません。'**
  String get settingsSnsShareCaption;

  /// No description provided for @settingsSnsShareDetail.
  ///
  /// In ja, this message translates to:
  /// **'SNS のアクセストークンを、この RASQ アカウントでログインしている端末のあいだで暗号化(E2E)して共有します。新しい端末でログインすると、共有している端末で承認したあと、その端末も SNS アカウントに一斉ログインします。RASQ のサーバーは中身を読めません。'**
  String get settingsSnsShareDetail;

  /// No description provided for @settingsSnsShareSwitchTitle.
  ///
  /// In ja, this message translates to:
  /// **'ほかの端末と SNS のログインを共有'**
  String get settingsSnsShareSwitchTitle;

  /// No description provided for @settingsSnsShareRequestTitle.
  ///
  /// In ja, this message translates to:
  /// **'この端末にも共有してもらう'**
  String get settingsSnsShareRequestTitle;

  /// No description provided for @settingsSnsShareRequestSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'共有している端末に、承認の問いが出ます'**
  String get settingsSnsShareRequestSubtitle;

  /// No description provided for @settingsSnsShareRequested.
  ///
  /// In ja, this message translates to:
  /// **'共有している端末に、承認を求めました'**
  String get settingsSnsShareRequested;

  /// No description provided for @settingsSnsShareDevicesLabel.
  ///
  /// In ja, this message translates to:
  /// **'端末'**
  String get settingsSnsShareDevicesLabel;

  /// 端末の一覧で、この端末の名前のうしろに付ける
  ///
  /// In ja, this message translates to:
  /// **'(この端末)'**
  String get settingsSnsShareThisDeviceSuffix;

  /// No description provided for @settingsSnsShareDeviceShared.
  ///
  /// In ja, this message translates to:
  /// **'共有しています'**
  String get settingsSnsShareDeviceShared;

  /// No description provided for @settingsSnsShareDeviceWaiting.
  ///
  /// In ja, this message translates to:
  /// **'承認を待っています'**
  String get settingsSnsShareDeviceWaiting;

  /// No description provided for @settingsSnsShareDeviceNotShared.
  ///
  /// In ja, this message translates to:
  /// **'共有していません'**
  String get settingsSnsShareDeviceNotShared;

  /// 端末に共有したときのお知らせ。name は端末の名前
  ///
  /// In ja, this message translates to:
  /// **'{name} に共有しました'**
  String settingsSnsShareApproved(String name);

  /// No description provided for @settingsSnsShareApproveButton.
  ///
  /// In ja, this message translates to:
  /// **'共有する'**
  String get settingsSnsShareApproveButton;

  /// No description provided for @settingsSnsShareDeclineButton.
  ///
  /// In ja, this message translates to:
  /// **'断る'**
  String get settingsSnsShareDeclineButton;

  /// 端末を共有から外したときのお知らせ。name は端末の名前
  ///
  /// In ja, this message translates to:
  /// **'{name} を共有から外しました'**
  String settingsSnsShareRemoved(String name);

  /// No description provided for @settingsSnsShareRemoveButton.
  ///
  /// In ja, this message translates to:
  /// **'外す'**
  String get settingsSnsShareRemoveButton;

  /// No description provided for @settingsSnsShareRemovedCaption.
  ///
  /// In ja, this message translates to:
  /// **'外した端末は、それまでのログインを持ったままです。心当たりが無ければ SNS 側でもログアウトしてください。'**
  String get settingsSnsShareRemovedCaption;

  /// No description provided for @settingsSnsShareRemovedDetail.
  ///
  /// In ja, this message translates to:
  /// **'「ログイン中の端末」でその端末をログアウトさせると、その端末の鍵も消えます。外した端末は、それまでに受け取ったアクセストークンを持っています(心当たりが無ければ、SNS 側でもログアウトしてください)。'**
  String get settingsSnsShareRemovedDetail;

  /// No description provided for @shellColumnSplitSmallFixedLabel.
  ///
  /// In ja, this message translates to:
  /// **'小型カラムの幅を固定'**
  String get shellColumnSplitSmallFixedLabel;

  /// No description provided for @shellColumnSplitLargeFixedLabel.
  ///
  /// In ja, this message translates to:
  /// **'大型カラムの幅を固定'**
  String get shellColumnSplitLargeFixedLabel;

  /// No description provided for @shellColumnSplitEvenHint.
  ///
  /// In ja, this message translates to:
  /// **'同じ幅'**
  String get shellColumnSplitEvenHint;

  /// No description provided for @shellColumnSplitTwoThreeHint.
  ///
  /// In ja, this message translates to:
  /// **'小型 2 : 大型 3'**
  String get shellColumnSplitTwoThreeHint;

  /// No description provided for @shellColumnSplitThreeFiveHint.
  ///
  /// In ja, this message translates to:
  /// **'小型 3 : 大型 5'**
  String get shellColumnSplitThreeFiveHint;

  /// No description provided for @shellColumnSplitSmallFixedHint.
  ///
  /// In ja, this message translates to:
  /// **'小型カラムを決めた幅にし、残りを大型カラムに'**
  String get shellColumnSplitSmallFixedHint;

  /// No description provided for @shellColumnSplitLargeFixedHint.
  ///
  /// In ja, this message translates to:
  /// **'大型カラムを決めた幅にし、残りを小型カラムに'**
  String get shellColumnSplitLargeFixedHint;

  /// No description provided for @shellColumnWidthErrorEmpty.
  ///
  /// In ja, this message translates to:
  /// **'幅を入れてください'**
  String get shellColumnWidthErrorEmpty;

  /// No description provided for @shellColumnWidthErrorNotInteger.
  ///
  /// In ja, this message translates to:
  /// **'数字(整数)で入れてください'**
  String get shellColumnWidthErrorNotInteger;

  /// カラムの固定幅の入力の検証。{min} / {max} = 入れられる幅の下限 / 上限(px)。
  ///
  /// In ja, this message translates to:
  /// **'{min}〜{max} px の間で入れてください'**
  String shellColumnWidthErrorRange(String min, String max);

  /// No description provided for @shellColumnThirdEmptySearch.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get shellColumnThirdEmptySearch;

  /// No description provided for @shellColumnThirdEmptyNotifications.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get shellColumnThirdEmptyNotifications;

  /// No description provided for @shellColumnThirdEmptyNone.
  ///
  /// In ja, this message translates to:
  /// **'表示しない'**
  String get shellColumnThirdEmptyNone;

  /// No description provided for @shellColumnThirdSettingsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'第3カラムの設定'**
  String get shellColumnThirdSettingsTooltip;

  /// No description provided for @shellColumnThirdCloseTooltip.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get shellColumnThirdCloseTooltip;

  /// No description provided for @shellColumnThirdEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'第3カラム'**
  String get shellColumnThirdEmptyTitle;

  /// No description provided for @shellColumnThirdEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'開いている画面をここへ移動できます'**
  String get shellColumnThirdEmptyHint;

  /// No description provided for @shellColumnThirdEmptyHintDetail.
  ///
  /// In ja, this message translates to:
  /// **'FOW をここへ移動できます(M5c)'**
  String get shellColumnThirdEmptyHintDetail;

  /// No description provided for @shellNavHome.
  ///
  /// In ja, this message translates to:
  /// **'ホーム'**
  String get shellNavHome;

  /// No description provided for @shellNavSearch.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get shellNavSearch;

  /// No description provided for @shellNavNotifications.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get shellNavNotifications;

  /// No description provided for @shellHeaderTimelineSwitchTooltip.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン切り替え'**
  String get shellHeaderTimelineSwitchTooltip;

  /// No description provided for @shellHeaderExpandTooltip.
  ///
  /// In ja, this message translates to:
  /// **'ヘッダーを戻す'**
  String get shellHeaderExpandTooltip;

  /// No description provided for @shellHeaderScrollToTopTooltip.
  ///
  /// In ja, this message translates to:
  /// **'先頭へ'**
  String get shellHeaderScrollToTopTooltip;

  /// No description provided for @shellHeaderSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get shellHeaderSearchHint;

  /// No description provided for @shellHeaderBackTooltip.
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get shellHeaderBackTooltip;

  /// 第3カラムのページの「戻る」を長押ししたときのドロップダウンの最後の項目(カラムを閉じる)。
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get shellHeaderCloseButton;

  /// No description provided for @shellHeaderMenuTooltip.
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get shellHeaderMenuTooltip;

  /// No description provided for @shellHeaderOpenSidebarSemantics.
  ///
  /// In ja, this message translates to:
  /// **'サイドバーを開く'**
  String get shellHeaderOpenSidebarSemantics;

  /// No description provided for @shellSidebarSemantics.
  ///
  /// In ja, this message translates to:
  /// **'サイドバー'**
  String get shellSidebarSemantics;

  /// サイドバー上部の、いま使っていない RASQ アカウントのアイコンのツールチップ。{name} = 表示名。
  ///
  /// In ja, this message translates to:
  /// **'{name} に切り替える'**
  String shellSidebarSwitchToAccountTooltip(String name);

  /// No description provided for @shellSidebarRasqAccountTooltip.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント'**
  String get shellSidebarRasqAccountTooltip;

  /// No description provided for @shellSidebarHideAccountsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'アカウントリストを隠す'**
  String get shellSidebarHideAccountsTooltip;

  /// No description provided for @shellSidebarShowAccountsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'アカウントリストを表示'**
  String get shellSidebarShowAccountsTooltip;

  /// No description provided for @shellSidebarAccountSettingsButton.
  ///
  /// In ja, this message translates to:
  /// **'アカウントの設定'**
  String get shellSidebarAccountSettingsButton;

  /// No description provided for @shellSidebarBookmarks.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク'**
  String get shellSidebarBookmarks;

  /// No description provided for @shellSidebarLists.
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get shellSidebarLists;

  /// No description provided for @shellSidebarPlugins.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get shellSidebarPlugins;

  /// No description provided for @shellSidebarCustomPlugins.
  ///
  /// In ja, this message translates to:
  /// **'カスタムプラグイン'**
  String get shellSidebarCustomPlugins;

  /// No description provided for @shellSidebarAllSettings.
  ///
  /// In ja, this message translates to:
  /// **'全ての設定'**
  String get shellSidebarAllSettings;

  /// No description provided for @shellSidebarHelp.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ'**
  String get shellSidebarHelp;

  /// No description provided for @shellSidebarDevCatalog.
  ///
  /// In ja, this message translates to:
  /// **'コンポーネントカタログ (dev)'**
  String get shellSidebarDevCatalog;

  /// No description provided for @shellSidebarDevWasmPlugin.
  ///
  /// In ja, this message translates to:
  /// **'WASMプラグイン試験 (dev)'**
  String get shellSidebarDevWasmPlugin;

  /// No description provided for @shellSidebarWebConsole.
  ///
  /// In ja, this message translates to:
  /// **'Webコンソール'**
  String get shellSidebarWebConsole;

  /// No description provided for @shellSidebarAccountActionsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'アカウントの操作'**
  String get shellSidebarAccountActionsTooltip;

  /// No description provided for @shellSidebarShowAccountMenu.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントを表示'**
  String get shellSidebarShowAccountMenu;

  /// No description provided for @shellSidebarLogoutMenu.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get shellSidebarLogoutMenu;

  /// No description provided for @shellAccountHeaderPickTooltip.
  ///
  /// In ja, this message translates to:
  /// **'アカウントを選ぶ'**
  String get shellAccountHeaderPickTooltip;

  /// ヘッダーのアカウントのボタンのツールチップ。{account} = 読んでいる SNS アカウント(@handle@instance など)。
  ///
  /// In ja, this message translates to:
  /// **'{account} で読んでいます'**
  String shellAccountHeaderReadingAsTooltip(String account);

  /// No description provided for @shellAccountHeaderSwitchSemantics.
  ///
  /// In ja, this message translates to:
  /// **'アカウントを切り替える'**
  String get shellAccountHeaderSwitchSemantics;

  /// No description provided for @shellAccountHeaderAvatarSemantics.
  ///
  /// In ja, this message translates to:
  /// **'アカウント'**
  String get shellAccountHeaderAvatarSemantics;

  /// No description provided for @shellAccountPickerSemantics.
  ///
  /// In ja, this message translates to:
  /// **'アカウントの選択'**
  String get shellAccountPickerSemantics;

  /// No description provided for @shellAccountPickerCloseTooltip.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get shellAccountPickerCloseTooltip;

  /// No description provided for @shellAccountFowTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント'**
  String get shellAccountFowTitle;

  /// No description provided for @shellAccountFowCloseButton.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get shellAccountFowCloseButton;

  /// No description provided for @shellAccountAppealSheetTitle.
  ///
  /// In ja, this message translates to:
  /// **'処置の解除を申請'**
  String get shellAccountAppealSheetTitle;

  /// No description provided for @shellAccountAppealCaption.
  ///
  /// In ja, this message translates to:
  /// **'運営の担当者が読んで、受理なら処置が解除されます。'**
  String get shellAccountAppealCaption;

  /// No description provided for @shellAccountAppealCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'運営(rasq-judge)の担当者が読んで、受理なら処置が解除されます。自動判定は通りません。'**
  String get shellAccountAppealCaptionDetail;

  /// No description provided for @shellAccountAppealReasonHint.
  ///
  /// In ja, this message translates to:
  /// **'申請の理由(必須)'**
  String get shellAccountAppealReasonHint;

  /// No description provided for @shellAccountAppealFailedError.
  ///
  /// In ja, this message translates to:
  /// **'申請できませんでした: {error}'**
  String shellAccountAppealFailedError(String error);

  /// No description provided for @shellAccountAppealSubmitButton.
  ///
  /// In ja, this message translates to:
  /// **'申請する'**
  String get shellAccountAppealSubmitButton;

  /// No description provided for @shellAccountAppealSentSnack.
  ///
  /// In ja, this message translates to:
  /// **'解除を申請しました。担当者が確認します'**
  String get shellAccountAppealSentSnack;

  /// 表示名の無い「この端末のみ」の RASQ アカウントの表示名。
  ///
  /// In ja, this message translates to:
  /// **'この端末'**
  String get shellAccountLocalDisplayName;

  /// No description provided for @shellAccountMenuAddSns.
  ///
  /// In ja, this message translates to:
  /// **'SNS アカウントを追加'**
  String get shellAccountMenuAddSns;

  /// No description provided for @shellAccountMenuAllSettings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get shellAccountMenuAllSettings;

  /// No description provided for @shellAccountMenuAccountPage.
  ///
  /// In ja, this message translates to:
  /// **'アカウントページ'**
  String get shellAccountMenuAccountPage;

  /// No description provided for @shellAccountMenuEditProfile.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール編集'**
  String get shellAccountMenuEditProfile;

  /// No description provided for @shellAccountMenuAccountSettings.
  ///
  /// In ja, this message translates to:
  /// **'アカウント設定'**
  String get shellAccountMenuAccountSettings;

  /// No description provided for @shellAccountMenuNotificationSettings.
  ///
  /// In ja, this message translates to:
  /// **'通知設定'**
  String get shellAccountMenuNotificationSettings;

  /// No description provided for @shellAccountMenuSecurity.
  ///
  /// In ja, this message translates to:
  /// **'セキュリティ(メール / パスワード / 端末)'**
  String get shellAccountMenuSecurity;

  /// No description provided for @shellAccountMenuLogout.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get shellAccountMenuLogout;

  /// No description provided for @shellAccountMenuDelete.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを削除'**
  String get shellAccountMenuDelete;

  /// No description provided for @shellAccountLogoutTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントからログアウト'**
  String get shellAccountLogoutTitle;

  /// No description provided for @shellAccountLogoutMessage.
  ///
  /// In ja, this message translates to:
  /// **'この端末から RASQ アカウントを外します。'**
  String get shellAccountLogoutMessage;

  /// No description provided for @shellAccountLogoutConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'ログアウト'**
  String get shellAccountLogoutConfirmButton;

  /// No description provided for @shellAccountLoggedOutWithSnsSnack.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントと、その SNS アカウントからログアウトしました'**
  String get shellAccountLoggedOutWithSnsSnack;

  /// No description provided for @shellAccountLoggedOutKeptSnsSnack.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントからログアウトしました。SNS アカウントは「この端末のみ」に移しました'**
  String get shellAccountLoggedOutKeptSnsSnack;

  /// No description provided for @shellAccountDeleteReloginRequiredError.
  ///
  /// In ja, this message translates to:
  /// **'このアカウントに、もう一度ログインしてから削除してください'**
  String get shellAccountDeleteReloginRequiredError;

  /// No description provided for @shellAccountDeleteNeedsEmailCodeSnack.
  ///
  /// In ja, this message translates to:
  /// **'削除には、メールの確認コードが要ります。「アカウントの削除」から進めてください'**
  String get shellAccountDeleteNeedsEmailCodeSnack;

  /// No description provided for @shellAccountDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを削除'**
  String get shellAccountDeleteTitle;

  /// No description provided for @shellAccountDeleteMessage.
  ///
  /// In ja, this message translates to:
  /// **'サーバー上のプロフィール、アカウントバンドル、同期した設定、レビューとブックマーク、ASTell のルームと共有、通知トークン、同意の記録を削除します。「アルゴリズムとコミュニティへの貢献」に同意していた場合は、提供の停止と提供済みデータの削除も同時に始まります。\n元に戻せません。各 SNS 上のアカウントと投稿は消えません。'**
  String get shellAccountDeleteMessage;

  /// No description provided for @shellAccountDeleteConfirmButton.
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get shellAccountDeleteConfirmButton;

  /// No description provided for @shellAccountDeletedSnack.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを削除しました'**
  String get shellAccountDeletedSnack;

  /// No description provided for @shellAccountDeleteFailedError.
  ///
  /// In ja, this message translates to:
  /// **'削除できませんでした: {error}'**
  String shellAccountDeleteFailedError(String error);

  /// No description provided for @shellAccountCreatedSnack.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント @{handle} を作成しました'**
  String shellAccountCreatedSnack(String handle);

  /// {level} = 処置の段階の名前。
  ///
  /// In ja, this message translates to:
  /// **'このアカウントには処置が掛かっています: {level}'**
  String shellAccountSanctionActive(String level);

  /// {features} = 止まっている機能の名前を「 / 」でつないだもの。
  ///
  /// In ja, this message translates to:
  /// **'止まっている機能: {features}'**
  String shellAccountSanctionRestrictedFeatures(String features);

  /// No description provided for @shellAccountSanctionReviewDelay.
  ///
  /// In ja, this message translates to:
  /// **'{seconds, plural, other{発言ごとに {seconds} 秒の検閲遅延が入ります}}'**
  String shellAccountSanctionReviewDelay(int seconds);

  /// No description provided for @shellAccountSanctionStaffNote.
  ///
  /// In ja, this message translates to:
  /// **'運営より: {note}'**
  String shellAccountSanctionStaffNote(String note);

  /// No description provided for @shellAccountSanctionNoExpiry.
  ///
  /// In ja, this message translates to:
  /// **'期限: なし'**
  String get shellAccountSanctionNoExpiry;

  /// {expiresAt} = 処置の期限の日時。
  ///
  /// In ja, this message translates to:
  /// **'期限: {expiresAt}'**
  String shellAccountSanctionExpiry(String expiresAt);

  /// {category} / {level} = 処置の種類 / 段階(サーバーの値)。
  ///
  /// In ja, this message translates to:
  /// **'解除を申請({category} / {level})'**
  String shellAccountSanctionAppealButton(String category, String level);

  /// No description provided for @shellAccountSanctionAppealPending.
  ///
  /// In ja, this message translates to:
  /// **'申請中({category})'**
  String shellAccountSanctionAppealPending(String category);

  /// No description provided for @shellAccountEmpty.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントはまだありません。'**
  String get shellAccountEmpty;

  /// アカウント FOW の RASQ アカウントの行の下の行。{kind} = アカウントの種類、{count} = 所属する SNS アカウントの数。
  ///
  /// In ja, this message translates to:
  /// **'{kind} ・ SNS {count, plural, other{{count}件}}'**
  String shellAccountRowSubtitle(String kind, int count);

  /// No description provided for @shellAccountRowInUseSuffix.
  ///
  /// In ja, this message translates to:
  /// **' ・ 使用中'**
  String get shellAccountRowInUseSuffix;

  /// No description provided for @shellAccountRowNeedsLoginSuffix.
  ///
  /// In ja, this message translates to:
  /// **' ・ ログインが必要'**
  String get shellAccountRowNeedsLoginSuffix;

  /// No description provided for @shellAccountCollapseActionsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'操作を畳む'**
  String get shellAccountCollapseActionsTooltip;

  /// No description provided for @shellAccountActionsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'アカウントの操作'**
  String get shellAccountActionsTooltip;

  /// No description provided for @shellAccountReloginSnack.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} に、もう一度ログインしてください'**
  String shellAccountReloginSnack(String handle);

  /// No description provided for @shellAccountChildSafeButton.
  ///
  /// In ja, this message translates to:
  /// **'チャイルドセーフ'**
  String get shellAccountChildSafeButton;

  /// No description provided for @shellAccountCreateButton.
  ///
  /// In ja, this message translates to:
  /// **'アカウントを新規作成'**
  String get shellAccountCreateButton;

  /// No description provided for @shellAccountLoginButton.
  ///
  /// In ja, this message translates to:
  /// **'ログイン'**
  String get shellAccountLoginButton;

  /// No description provided for @shellAccountServerNotConfigured.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーの接続先が未設定です'**
  String get shellAccountServerNotConfigured;

  /// No description provided for @shellAccountConfigureServerButton.
  ///
  /// In ja, this message translates to:
  /// **'接続先を設定'**
  String get shellAccountConfigureServerButton;

  /// No description provided for @shellAccountProfileSheetTitle.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール編集'**
  String get shellAccountProfileSheetTitle;

  /// No description provided for @shellAccountProfileSaveButton.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get shellAccountProfileSaveButton;

  /// No description provided for @shellAccountProfileDisplayNameLabel.
  ///
  /// In ja, this message translates to:
  /// **'表示名'**
  String get shellAccountProfileDisplayNameLabel;

  /// No description provided for @shellAccountProfileDisplayNameHint.
  ///
  /// In ja, this message translates to:
  /// **'表示名'**
  String get shellAccountProfileDisplayNameHint;

  /// No description provided for @shellAccountProfileHandleLabel.
  ///
  /// In ja, this message translates to:
  /// **'ハンドル(@なし、a-z 0-9 _)'**
  String get shellAccountProfileHandleLabel;

  /// No description provided for @shellAccountProfileCentralCaption.
  ///
  /// In ja, this message translates to:
  /// **'RASQ のサーバー上のプロフィールを更新します。'**
  String get shellAccountProfileCentralCaption;

  /// No description provided for @shellAccountProfileLocalCaption.
  ///
  /// In ja, this message translates to:
  /// **'この端末だけのアカウントです。ハンドルは RASQ アカウントを作成すると付きます。'**
  String get shellAccountProfileLocalCaption;

  /// No description provided for @shellAccountProfileSavedSnack.
  ///
  /// In ja, this message translates to:
  /// **'プロフィールを保存しました'**
  String get shellAccountProfileSavedSnack;

  /// No description provided for @shellAccountProfileSaveFailedError.
  ///
  /// In ja, this message translates to:
  /// **'保存できませんでした: {error}'**
  String shellAccountProfileSaveFailedError(String error);

  /// No description provided for @shellAccountTileMenuTooltip.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウント'**
  String get shellAccountTileMenuTooltip;

  /// No description provided for @shellTermsSheetTitle.
  ///
  /// In ja, this message translates to:
  /// **'利用規約への同意'**
  String get shellTermsSheetTitle;

  /// No description provided for @shellTermsAgreeButton.
  ///
  /// In ja, this message translates to:
  /// **'同意する'**
  String get shellTermsAgreeButton;

  /// No description provided for @shellTermsNotice.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントを使い続けるには、いまの利用規約とプライバシーポリシーへの同意が必要です。同意するまで、ASTell・購入・データの預け入れは使えません。'**
  String get shellTermsNotice;

  /// 開発者モードの詳しい説明。{endpoints} = API のパスの一部「{terms,privacy,age,guardian}」(波かっこを含む固定の文字列。訳さない)。
  ///
  /// In ja, this message translates to:
  /// **'D-371 / S-053。サーバーの CENTRAL_TERMS_VERSION / CENTRAL_PRIVACY_VERSION と同じ版の承諾がそろうまで「同意待ち」。PUT /me/consents/{endpoints}。'**
  String shellTermsNoticeDetail(String endpoints);

  /// No description provided for @shellTermsReadTermsButton.
  ///
  /// In ja, this message translates to:
  /// **'利用規約を読む'**
  String get shellTermsReadTermsButton;

  /// No description provided for @shellTermsReadPrivacyButton.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシーを読む'**
  String get shellTermsReadPrivacyButton;

  /// No description provided for @shellTermsAgeHeader.
  ///
  /// In ja, this message translates to:
  /// **'年齢'**
  String get shellTermsAgeHeader;

  /// No description provided for @shellTermsGuardianConsentCheck.
  ///
  /// In ja, this message translates to:
  /// **'保護者の同意を得ています'**
  String get shellTermsGuardianConsentCheck;

  /// No description provided for @shellTermsAgreeCheck.
  ///
  /// In ja, this message translates to:
  /// **'利用規約とプライバシーポリシーを読み、同意します'**
  String get shellTermsAgreeCheck;

  /// {termsVersion} / {privacyVersion} = 利用規約 / プライバシーポリシーの版。
  ///
  /// In ja, this message translates to:
  /// **'版: 利用規約 {termsVersion} ・ プライバシーポリシー {privacyVersion}'**
  String shellTermsVersionCaption(String termsVersion, String privacyVersion);

  /// No description provided for @shellTermsAcceptedSnack.
  ///
  /// In ja, this message translates to:
  /// **'利用規約に同意しました'**
  String get shellTermsAcceptedSnack;

  /// No description provided for @shellTermsOutdatedError.
  ///
  /// In ja, this message translates to:
  /// **'利用規約が新しくなっています。アプリを更新してから同意してください'**
  String get shellTermsOutdatedError;

  /// No description provided for @shellTermsRecordFailedError.
  ///
  /// In ja, this message translates to:
  /// **'同意を記録できませんでした: {error}'**
  String shellTermsRecordFailedError(String error);

  /// No description provided for @shellTermsBannerText.
  ///
  /// In ja, this message translates to:
  /// **'利用規約への同意が必要です。同意するまで ASTell・購入などは使えません。'**
  String get shellTermsBannerText;

  /// No description provided for @shellTermsBannerOpenButton.
  ///
  /// In ja, this message translates to:
  /// **'確認する'**
  String get shellTermsBannerOpenButton;

  /// No description provided for @storeStatusInReview.
  ///
  /// In ja, this message translates to:
  /// **'審査中'**
  String get storeStatusInReview;

  /// No description provided for @storeStatusPublished.
  ///
  /// In ja, this message translates to:
  /// **'公開中'**
  String get storeStatusPublished;

  /// No description provided for @storeStatusUpdateAvailable.
  ///
  /// In ja, this message translates to:
  /// **'更新あり'**
  String get storeStatusUpdateAvailable;

  /// No description provided for @storeStatusWarning.
  ///
  /// In ja, this message translates to:
  /// **'警告'**
  String get storeStatusWarning;

  /// No description provided for @storeStatusSuspended.
  ///
  /// In ja, this message translates to:
  /// **'停止'**
  String get storeStatusSuspended;

  /// No description provided for @storeStatusWithdrawn.
  ///
  /// In ja, this message translates to:
  /// **'取り下げ'**
  String get storeStatusWithdrawn;

  /// No description provided for @storeStatusUnlisted.
  ///
  /// In ja, this message translates to:
  /// **'非公開'**
  String get storeStatusUnlisted;

  /// No description provided for @storeStatusBeta.
  ///
  /// In ja, this message translates to:
  /// **'ベータ'**
  String get storeStatusBeta;

  /// No description provided for @storeStatusRevoked.
  ///
  /// In ja, this message translates to:
  /// **'失効'**
  String get storeStatusRevoked;

  /// No description provided for @storeOriginOfficial.
  ///
  /// In ja, this message translates to:
  /// **'公式'**
  String get storeOriginOfficial;

  /// No description provided for @storeOriginVerified.
  ///
  /// In ja, this message translates to:
  /// **'検証済み'**
  String get storeOriginVerified;

  /// No description provided for @storeOriginCommunity.
  ///
  /// In ja, this message translates to:
  /// **'コミュニティ'**
  String get storeOriginCommunity;

  /// No description provided for @storeTypeComposer.
  ///
  /// In ja, this message translates to:
  /// **'投稿作成'**
  String get storeTypeComposer;

  /// No description provided for @storeTypePost.
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get storeTypePost;

  /// No description provided for @storeTypeViewer.
  ///
  /// In ja, this message translates to:
  /// **'全画面表示'**
  String get storeTypeViewer;

  /// No description provided for @storeTypeTimeline.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン'**
  String get storeTypeTimeline;

  /// No description provided for @storeTypeTrend.
  ///
  /// In ja, this message translates to:
  /// **'トレンド'**
  String get storeTypeTrend;

  /// No description provided for @storeTypeTheme.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え'**
  String get storeTypeTheme;

  /// No description provided for @storeTypeAssets.
  ///
  /// In ja, this message translates to:
  /// **'ステッカー / 素材'**
  String get storeTypeAssets;

  /// No description provided for @storeTypeCustom.
  ///
  /// In ja, this message translates to:
  /// **'カスタム'**
  String get storeTypeCustom;

  /// No description provided for @storeTypeOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get storeTypeOther;

  /// No description provided for @storeFilterFree.
  ///
  /// In ja, this message translates to:
  /// **'無料'**
  String get storeFilterFree;

  /// No description provided for @storeFilterNoAds.
  ///
  /// In ja, this message translates to:
  /// **'広告なし'**
  String get storeFilterNoAds;

  /// No description provided for @storeFilterOfficial.
  ///
  /// In ja, this message translates to:
  /// **'公式'**
  String get storeFilterOfficial;

  /// No description provided for @storeFilterVerified.
  ///
  /// In ja, this message translates to:
  /// **'認証済み'**
  String get storeFilterVerified;

  /// No description provided for @storeFilterRecent.
  ///
  /// In ja, this message translates to:
  /// **'30 日以内'**
  String get storeFilterRecent;

  /// No description provided for @storeFilterLightweight.
  ///
  /// In ja, this message translates to:
  /// **'軽量(5MB 未満)'**
  String get storeFilterLightweight;

  /// No description provided for @storeFilterOffline.
  ///
  /// In ja, this message translates to:
  /// **'オフライン'**
  String get storeFilterOffline;

  /// No description provided for @storePermNetwork.
  ///
  /// In ja, this message translates to:
  /// **'ネットワーク'**
  String get storePermNetwork;

  /// No description provided for @storePermNetworkDescription.
  ///
  /// In ja, this message translates to:
  /// **'外部への通信'**
  String get storePermNetworkDescription;

  /// No description provided for @storePermStorage.
  ///
  /// In ja, this message translates to:
  /// **'ストレージ'**
  String get storePermStorage;

  /// No description provided for @storePermStorageDescription.
  ///
  /// In ja, this message translates to:
  /// **'端末内の保存領域'**
  String get storePermStorageDescription;

  /// No description provided for @storePermFiles.
  ///
  /// In ja, this message translates to:
  /// **'ファイル'**
  String get storePermFiles;

  /// No description provided for @storePermFilesDescription.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーが選んだファイルの読み書き'**
  String get storePermFilesDescription;

  /// No description provided for @storePermSns.
  ///
  /// In ja, this message translates to:
  /// **'投稿とアカウント'**
  String get storePermSns;

  /// No description provided for @storePermSnsDescription.
  ///
  /// In ja, this message translates to:
  /// **'SNS アカウントを使った操作'**
  String get storePermSnsDescription;

  /// No description provided for @storePermDm.
  ///
  /// In ja, this message translates to:
  /// **'ダイレクトメッセージ'**
  String get storePermDm;

  /// No description provided for @storePermDmDescription.
  ///
  /// In ja, this message translates to:
  /// **'DM の読み書き'**
  String get storePermDmDescription;

  /// No description provided for @storePermGpuMl.
  ///
  /// In ja, this message translates to:
  /// **'GPU / 機械学習'**
  String get storePermGpuMl;

  /// No description provided for @storePermGpuMlDescription.
  ///
  /// In ja, this message translates to:
  /// **'GPU 実行・モデル推論'**
  String get storePermGpuMlDescription;

  /// No description provided for @storePermClipboard.
  ///
  /// In ja, this message translates to:
  /// **'クリップボード'**
  String get storePermClipboard;

  /// No description provided for @storePermClipboardDescription.
  ///
  /// In ja, this message translates to:
  /// **'コピー内容の読み書き'**
  String get storePermClipboardDescription;

  /// No description provided for @storePermBackground.
  ///
  /// In ja, this message translates to:
  /// **'バックグラウンド実行'**
  String get storePermBackground;

  /// No description provided for @storePermBackgroundDescription.
  ///
  /// In ja, this message translates to:
  /// **'画面を閉じても動作'**
  String get storePermBackgroundDescription;

  /// No description provided for @storePermUi.
  ///
  /// In ja, this message translates to:
  /// **'画面と配置'**
  String get storePermUi;

  /// No description provided for @storePermUiDescription.
  ///
  /// In ja, this message translates to:
  /// **'画面の表示とボタンの配置'**
  String get storePermUiDescription;

  /// No description provided for @storePermOther.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get storePermOther;

  /// No description provided for @storeReviewSortHelpful.
  ///
  /// In ja, this message translates to:
  /// **'関連性'**
  String get storeReviewSortHelpful;

  /// No description provided for @storeReviewSortRecent.
  ///
  /// In ja, this message translates to:
  /// **'最新'**
  String get storeReviewSortRecent;

  /// No description provided for @storeReviewSortRatingHigh.
  ///
  /// In ja, this message translates to:
  /// **'評価が高い'**
  String get storeReviewSortRatingHigh;

  /// No description provided for @storeReviewSortRatingLow.
  ///
  /// In ja, this message translates to:
  /// **'評価が低い'**
  String get storeReviewSortRatingLow;

  /// 許可した内容から広がるもの(権限)。permission は権限の id
  ///
  /// In ja, this message translates to:
  /// **'権限 {permission}'**
  String storeScopePermission(String permission);

  /// 広がるもの(接続先)。host はホスト名
  ///
  /// In ja, this message translates to:
  /// **'接続先 {host}'**
  String storeScopeHost(String host);

  /// No description provided for @storeScopeInstance.
  ///
  /// In ja, this message translates to:
  /// **'接続先 ログイン先のインスタンス'**
  String get storeScopeInstance;

  /// 広がるもの(使う場所)。slot はスロットの id
  ///
  /// In ja, this message translates to:
  /// **'使う場所 {slot}'**
  String storeScopeSlot(String slot);

  /// 権限の用途の理由が変わった。permission は権限の id、reason は開発者が書いた理由
  ///
  /// In ja, this message translates to:
  /// **'用途 {permission} — {reason}'**
  String storeScopeReason(String permission, String reason);

  /// データの扱いの文が変わった。text はその文(長ければ省略)
  ///
  /// In ja, this message translates to:
  /// **'データの扱い — {text}'**
  String storeScopeDataHandling(String text);

  /// feature は機能の名前(storeFeaturePurchase など)
  ///
  /// In ja, this message translates to:
  /// **'{feature}は ORGATE-Server につなぐと使えます(接続先が設定されていません)'**
  String storeNeedsOrgate(String feature);

  /// No description provided for @storeFeaturePurchase.
  ///
  /// In ja, this message translates to:
  /// **'購入'**
  String get storeFeaturePurchase;

  /// No description provided for @storeFeaturePoints.
  ///
  /// In ja, this message translates to:
  /// **'ポイント'**
  String get storeFeaturePoints;

  /// No description provided for @storeFeatureReview.
  ///
  /// In ja, this message translates to:
  /// **'レビュー'**
  String get storeFeatureReview;

  /// 共有セッションの配布物の検証の失敗。actual / expected はプラグインの id
  ///
  /// In ja, this message translates to:
  /// **'構成のプラグイン ({actual}) が頼んだもの ({expected}) と違います'**
  String storeSessionPluginMismatch(String actual, String expected);

  /// actual / expected は版
  ///
  /// In ja, this message translates to:
  /// **'構成の版 ({actual}) が頼んだ版 ({expected}) と違います'**
  String storeSessionVersionMismatch(String actual, String expected);

  /// No description provided for @storeNoBundle.
  ///
  /// In ja, this message translates to:
  /// **'配布物がありません'**
  String get storeNoBundle;

  /// 一覧を 1 行につなぐときの区切り
  ///
  /// In ja, this message translates to:
  /// **'、'**
  String get storeListSeparator;

  /// 情報を 1 行に並べるときの区切り(前後に空白)
  ///
  /// In ja, this message translates to:
  /// **' ・ '**
  String get storeDotSeparator;

  /// No description provided for @storeVerifyHashOnly.
  ///
  /// In ja, this message translates to:
  /// **'SHA-512 照合 OK(署名なし)'**
  String get storeVerifyHashOnly;

  /// No description provided for @storeVerifyFull.
  ///
  /// In ja, this message translates to:
  /// **'SHA-512 + ed25519 署名 検証 OK'**
  String get storeVerifyFull;

  /// No description provided for @storeVerifyHashMismatch.
  ///
  /// In ja, this message translates to:
  /// **'整合性検証に失敗しました(SHA-512 不一致)。時間をおいて再取得してください'**
  String get storeVerifyHashMismatch;

  /// No description provided for @storeVerifyKeyMismatch.
  ///
  /// In ja, this message translates to:
  /// **'ストアの署名鍵がアプリに焼き込んだ鍵と一致しません。接続先を確認してください'**
  String get storeVerifyKeyMismatch;

  /// No description provided for @storeVerifyUnsigned.
  ///
  /// In ja, this message translates to:
  /// **'配布物に署名がありません(このビルドは署名済みストアのみを許可します)'**
  String get storeVerifyUnsigned;

  /// No description provided for @storeVerifyBadSignature.
  ///
  /// In ja, this message translates to:
  /// **'配布物の署名が正しくありません。インストールを中止しました'**
  String get storeVerifyBadSignature;

  /// error は例外の文
  ///
  /// In ja, this message translates to:
  /// **'署名を検証できませんでした: {error}'**
  String storeVerifyError(String error);

  /// No description provided for @storeWidenedNoRecord.
  ///
  /// In ja, this message translates to:
  /// **'最後に許可した内容の記録がないため(プラグインを管理から確かめて入れてください)'**
  String get storeWidenedNoRecord;

  /// 自動では有効にしない理由。items は広がるもの(storeScope…)を区切りでつないだもの
  ///
  /// In ja, this message translates to:
  /// **'最後に許可した内容より広がるため({items})'**
  String storeWidenedOver(String items);

  /// No description provided for @storeManifestUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'構成(マニフェスト)を取得できませんでした'**
  String get storeManifestUnavailable;

  /// No description provided for @storeManifestVersionNotFound.
  ///
  /// In ja, this message translates to:
  /// **'Ver.{version} の構成が見つかりませんでした'**
  String storeManifestVersionNotFound(String version);

  /// No description provided for @storeConsentChanged.
  ///
  /// In ja, this message translates to:
  /// **'確認した内容(Ver.{version})と、ストアの構成が変わりました。もう一度確かめてください'**
  String storeConsentChanged(String version);

  /// No description provided for @storePackageInvalid.
  ///
  /// In ja, this message translates to:
  /// **'配布物の中身を検証できませんでした: {error}'**
  String storePackageInvalid(String error);

  /// actual / expected は「プラグインの id 版」
  ///
  /// In ja, this message translates to:
  /// **'配布物の中身({actual})がストアの掲載({expected})と違います'**
  String storePackageMismatch(String actual, String expected);

  /// plugins は「id 版」を / でつないだもの
  ///
  /// In ja, this message translates to:
  /// **'このプラグインには {plugins} が必要です(未対応のため入れられません)'**
  String storePackageRequires(String plugins);

  /// No description provided for @storeThemeSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'着せ替えを保存できませんでした: {error}'**
  String storeThemeSaveFailed(String error);

  /// No description provided for @storeAssetsSaveFailed.
  ///
  /// In ja, this message translates to:
  /// **'アセットパックを保存できませんでした: {error}'**
  String storeAssetsSaveFailed(String error);

  /// No description provided for @storeSlotRegisterFailed.
  ///
  /// In ja, this message translates to:
  /// **'スロットに登録できませんでした'**
  String get storeSlotRegisterFailed;

  /// No description provided for @storeVersionBundleChanged.
  ///
  /// In ja, this message translates to:
  /// **'Ver.{version} の配布物がインストール時と違うため読み込みません(入れ直してください)'**
  String storeVersionBundleChanged(String version);

  /// No description provided for @storeVersionLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'Ver.{version} を読み込めませんでした: {error}'**
  String storeVersionLoadFailed(String version, String error);

  /// No description provided for @storeVersionNoScopeRecord.
  ///
  /// In ja, this message translates to:
  /// **'この版で許す内容の記録がありません(入れ直すと確かめられます)'**
  String get storeVersionNoScopeRecord;

  /// No description provided for @storeVersionNotInstalled.
  ///
  /// In ja, this message translates to:
  /// **'Ver.{version} は入っていません'**
  String storeVersionNotInstalled(String version);

  /// No description provided for @storeNotInstalled.
  ///
  /// In ja, this message translates to:
  /// **'インストールされていません'**
  String get storeNotInstalled;

  /// No description provided for @storeVersionInUse.
  ///
  /// In ja, this message translates to:
  /// **'Ver.{version} は使われています(既定 / アカウントの指定を外してから)'**
  String storeVersionInUse(String version);

  /// No description provided for @storeManageTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを管理'**
  String get storeManageTitle;

  /// No description provided for @storeManageUpdatesHeader.
  ///
  /// In ja, this message translates to:
  /// **'アップデート'**
  String get storeManageUpdatesHeader;

  /// No description provided for @storeManageUpdateSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'アップデートの設定'**
  String get storeManageUpdateSettingsTitle;

  /// No description provided for @storeManageUpdateSettingsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'自動で更新するかどうか ・ 更新ログ'**
  String get storeManageUpdateSettingsSubtitle;

  /// No description provided for @storeManageUpdateSettingsDetail.
  ///
  /// In ja, this message translates to:
  /// **'SNS / アクション / ビューごとに、おまかせ・インストールだけ・手動 ・ 更新ログ'**
  String get storeManageUpdateSettingsDetail;

  /// No description provided for @storeManagePointsTitle.
  ///
  /// In ja, this message translates to:
  /// **'ポイント'**
  String get storeManagePointsTitle;

  /// No description provided for @storeManagePointsDisabled.
  ///
  /// In ja, this message translates to:
  /// **'公開テストでは使えません'**
  String get storeManagePointsDisabled;

  /// ポイントの残高
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{ポイント {count}}}'**
  String storeManagePointsBalance(int count);

  /// No description provided for @storeManagePointsSignIn.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインすると使えます'**
  String get storeManagePointsSignIn;

  /// No description provided for @storeManagePointsBuyInConsole.
  ///
  /// In ja, this message translates to:
  /// **'Web コンソールで買えます(付与から 1 か月で失効)'**
  String get storeManagePointsBuyInConsole;

  /// month / day は次に失効する日、count は失効するポイント
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{month}/{day} に {count} ポイントが失効 ・ Web コンソールで買う}}'**
  String storeManagePointsExpiring(int month, int day, int count);

  /// No description provided for @storeNoInstalledPlugins.
  ///
  /// In ja, this message translates to:
  /// **'インストール済みのプラグインはありません'**
  String get storeNoInstalledPlugins;

  /// No description provided for @storeManageImportTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインのインポート'**
  String get storeManageImportTitle;

  /// No description provided for @storeManageImportSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'開発中のプラグインを入れる(審査前)'**
  String get storeManageImportSubtitle;

  /// No description provided for @storeManageImportDetail.
  ///
  /// In ja, this message translates to:
  /// **'開発中の wasm / .rasqpkg を入れる(審査を通っていません)'**
  String get storeManageImportDetail;

  /// No description provided for @storeManageHomeHeader.
  ///
  /// In ja, this message translates to:
  /// **'ホームの表示'**
  String get storeManageHomeHeader;

  /// No description provided for @storeManageShowInstalledTitle.
  ///
  /// In ja, this message translates to:
  /// **'インストール済みもホームに出す'**
  String get storeManageShowInstalledTitle;

  /// No description provided for @storeManageShowInstalledSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'今週のトレンド / 新着の列に、入れたプラグインも並べます'**
  String get storeManageShowInstalledSubtitle;

  /// No description provided for @storeBookmarksTitle.
  ///
  /// In ja, this message translates to:
  /// **'ブックマーク'**
  String get storeBookmarksTitle;

  /// No description provided for @storeManageSwitchTo.
  ///
  /// In ja, this message translates to:
  /// **'{version} に切り替え'**
  String storeManageSwitchTo(String version);

  /// No description provided for @storeVersionMadeDefault.
  ///
  /// In ja, this message translates to:
  /// **'{version} を既定の版にしました'**
  String storeVersionMadeDefault(String version);

  /// No description provided for @storeManageUpdateTo.
  ///
  /// In ja, this message translates to:
  /// **'{version} に更新'**
  String storeManageUpdateTo(String version);

  /// No description provided for @storeManageOffline.
  ///
  /// In ja, this message translates to:
  /// **'ストアに接続できません'**
  String get storeManageOffline;

  /// No description provided for @storeManageUpToDate.
  ///
  /// In ja, this message translates to:
  /// **'最新です'**
  String get storeManageUpToDate;

  /// No description provided for @storeManageDeployedVersion.
  ///
  /// In ja, this message translates to:
  /// **'デプロイしたバージョン'**
  String get storeManageDeployedVersion;

  /// No description provided for @storeAccountVersionsTitle.
  ///
  /// In ja, this message translates to:
  /// **'アカウントごとにバージョンを設定'**
  String get storeAccountVersionsTitle;

  /// No description provided for @storeManageAccountVersionsCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{アカウントごと({count} 件指定)}}'**
  String storeManageAccountVersionsCount(int count);

  /// No description provided for @storePluginNotFound.
  ///
  /// In ja, this message translates to:
  /// **'このプラグインは見つかりませんでした'**
  String get storePluginNotFound;

  /// No description provided for @storeInstallFailed.
  ///
  /// In ja, this message translates to:
  /// **'インストールできませんでした: {error}'**
  String storeInstallFailed(String error);

  /// No description provided for @storeHasAds.
  ///
  /// In ja, this message translates to:
  /// **'広告あり'**
  String get storeHasAds;

  /// No description provided for @storeBuyDisabled.
  ///
  /// In ja, this message translates to:
  /// **'公開テストでは購入できません'**
  String get storeBuyDisabled;

  /// No description provided for @storeTileGet.
  ///
  /// In ja, this message translates to:
  /// **'入手'**
  String get storeTileGet;

  /// No description provided for @storeTileUpdate.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get storeTileUpdate;

  /// No description provided for @storeOpen.
  ///
  /// In ja, this message translates to:
  /// **'開く'**
  String get storeOpen;

  /// No description provided for @storeTileUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'停止中'**
  String get storeTileUnavailable;

  /// ダウンロード数(1 万以上)。value は 1 万で割った数(小数 1 桁)
  ///
  /// In ja, this message translates to:
  /// **'{value}万'**
  String storeDownloadsTenThousands(String value);

  /// No description provided for @storeNotAssetPack.
  ///
  /// In ja, this message translates to:
  /// **'アセットパックではありません: {id}'**
  String storeNotAssetPack(String id);

  /// No description provided for @storeUpdatesNoneApplied.
  ///
  /// In ja, this message translates to:
  /// **'自動で入れる更新はありませんでした'**
  String get storeUpdatesNoneApplied;

  /// No description provided for @storeUpdateSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'アップデート/デプロイの設定'**
  String get storeUpdateSettingsTitle;

  /// No description provided for @storeUpdateSettingsModeHeader.
  ///
  /// In ja, this message translates to:
  /// **'アップデート/デプロイ'**
  String get storeUpdateSettingsModeHeader;

  /// No description provided for @storeUpdateSettingsPopup.
  ///
  /// In ja, this message translates to:
  /// **'アップデート後の起動時にポップアップを表示'**
  String get storeUpdateSettingsPopup;

  /// No description provided for @storeUpdateLogTitle.
  ///
  /// In ja, this message translates to:
  /// **'更新ログ'**
  String get storeUpdateLogTitle;

  /// No description provided for @storeUpdateSettingsCheckNow.
  ///
  /// In ja, this message translates to:
  /// **'いま確かめる'**
  String get storeUpdateSettingsCheckNow;

  /// No description provided for @storeUpdateSettingsCaption.
  ///
  /// In ja, this message translates to:
  /// **'許可した内容が広がる版と有料の版は、自動では入りません'**
  String get storeUpdateSettingsCaption;

  /// No description provided for @storeUpdateSettingsCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'最後に許可した内容より権限・接続先・使う場所・用途が広がる版(確かめられない版も)と、買っていない有料の版は、どのモードでも自動では使い始めません(更新ログに理由が残ります)。起動するたびに 1 回確かめます。'**
  String get storeUpdateSettingsCaptionDetail;

  /// No description provided for @storeUpdateLogEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだありません'**
  String get storeUpdateLogEmpty;

  /// No description provided for @storeUpdateLogEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'アップデートすると、ここに残ります'**
  String get storeUpdateLogEmptyHint;

  /// No description provided for @storeInstalledTitle.
  ///
  /// In ja, this message translates to:
  /// **'インストール済み'**
  String get storeInstalledTitle;

  /// No description provided for @storeInstalledEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'ストアから追加できます'**
  String get storeInstalledEmptyHint;

  /// No description provided for @storeInstalledItemSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'v{version} ・ {id}'**
  String storeInstalledItemSubtitle(String version, String id);

  /// No description provided for @storeUnknown.
  ///
  /// In ja, this message translates to:
  /// **'不明'**
  String get storeUnknown;

  /// No description provided for @storeInstalledMissingHint.
  ///
  /// In ja, this message translates to:
  /// **'削除済みか、別の端末で入れたものです'**
  String get storeInstalledMissingHint;

  /// No description provided for @storeInstalledSourceSnapshot.
  ///
  /// In ja, this message translates to:
  /// **'インストールしたときの掲載の写しです。'**
  String get storeInstalledSourceSnapshot;

  /// No description provided for @storeInstalledSourceManifest.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン自身の宣言(権限の id だけ)です。'**
  String get storeInstalledSourceManifest;

  /// No description provided for @storeInstalledRemoveTitle.
  ///
  /// In ja, this message translates to:
  /// **'削除しますか？'**
  String get storeInstalledRemoveTitle;

  /// No description provided for @storeInstalledRemoveMessage.
  ///
  /// In ja, this message translates to:
  /// **'{name} を端末から削除します。'**
  String storeInstalledRemoveMessage(String name);

  /// No description provided for @storeRemove.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get storeRemove;

  /// No description provided for @storeCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get storeCancel;

  /// No description provided for @storeInstalledOffline.
  ///
  /// In ja, this message translates to:
  /// **'ストアに接続できないので、手元の情報を出しています。'**
  String get storeInstalledOffline;

  /// No description provided for @storeInstalledUnlisted.
  ///
  /// In ja, this message translates to:
  /// **'ストアの掲載は見つかりません(取り下げられた可能性があります)。このまま使い続けることも、削除することもできます。'**
  String get storeInstalledUnlisted;

  /// No description provided for @storeInstalledVersionHeader.
  ///
  /// In ja, this message translates to:
  /// **'インストール済みのバージョン'**
  String get storeInstalledVersionHeader;

  /// date は入れた日(2026/10/19 の形)
  ///
  /// In ja, this message translates to:
  /// **'インストール: {date}'**
  String storeInstalledAt(String date);

  /// sha512 はダイジェストの先頭
  ///
  /// In ja, this message translates to:
  /// **'インストール: {date} ・ 検証済み SHA-512 {sha512}'**
  String storeInstalledAtVerified(String date, String sha512);

  /// No description provided for @storeInstalledNewerTitle.
  ///
  /// In ja, this message translates to:
  /// **'ストアには v{version} があります'**
  String storeInstalledNewerTitle(String version);

  /// No description provided for @storeInstalledNewerSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'ストアのページから入れ直せます'**
  String get storeInstalledNewerSubtitle;

  /// slots はスロットの id を区切りでつないだもの
  ///
  /// In ja, this message translates to:
  /// **'動いている場所: {slots}'**
  String storeInstalledSlots(String slots);

  /// No description provided for @storeInstalledOpenStore.
  ///
  /// In ja, this message translates to:
  /// **'ストアのページを開く'**
  String get storeInstalledOpenStore;

  /// No description provided for @storePrivacyHeader.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーと必要な権限'**
  String get storePrivacyHeader;

  /// No description provided for @storeVersionsInstalledHeader.
  ///
  /// In ja, this message translates to:
  /// **'入っている版'**
  String get storeVersionsInstalledHeader;

  /// No description provided for @storeVersionsDefault.
  ///
  /// In ja, this message translates to:
  /// **'既定の版'**
  String get storeVersionsDefault;

  /// No description provided for @storeVersionsUsers.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} アカウントが使用中}}'**
  String storeVersionsUsers(int count);

  /// No description provided for @storeVersionsInstalledOn.
  ///
  /// In ja, this message translates to:
  /// **'入れた日 {year}/{month}/{day}'**
  String storeVersionsInstalledOn(int year, int month, int day);

  /// No description provided for @storeMenu.
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get storeMenu;

  /// No description provided for @storeVersionsMakeDefault.
  ///
  /// In ja, this message translates to:
  /// **'既定の版にする'**
  String get storeVersionsMakeDefault;

  /// No description provided for @storeVersionsRemove.
  ///
  /// In ja, this message translates to:
  /// **'この版を消す'**
  String get storeVersionsRemove;

  /// No description provided for @storeVersionsRemoved.
  ///
  /// In ja, this message translates to:
  /// **'{version} を消しました'**
  String storeVersionsRemoved(String version);

  /// No description provided for @storeVersionsOthersHeader.
  ///
  /// In ja, this message translates to:
  /// **'ほかの版を入れる'**
  String get storeVersionsOthersHeader;

  /// No description provided for @storeVersionsMorePermissions.
  ///
  /// In ja, this message translates to:
  /// **'権限が増えます'**
  String get storeVersionsMorePermissions;

  /// No description provided for @storeVersionsInstall.
  ///
  /// In ja, this message translates to:
  /// **'入れる'**
  String get storeVersionsInstall;

  /// No description provided for @storeVersionsPerAccountHeader.
  ///
  /// In ja, this message translates to:
  /// **'アカウントごと'**
  String get storeVersionsPerAccountHeader;

  /// No description provided for @storeVersionsPerAccountCaption.
  ///
  /// In ja, this message translates to:
  /// **'アカウントごとに、使う版を選べます'**
  String get storeVersionsPerAccountCaption;

  /// No description provided for @storeVersionsPerAccountDetail.
  ///
  /// In ja, this message translates to:
  /// **'そのアカウントを使っている間、スロットプラグインとノードの並べ替えは、ここで選んだ版で動きます。'**
  String get storeVersionsPerAccountDetail;

  /// No description provided for @storeVersionsFollowDefault.
  ///
  /// In ja, this message translates to:
  /// **'既定に従う({version})'**
  String storeVersionsFollowDefault(String version);

  /// account は SNS アカウント(handle@host)
  ///
  /// In ja, this message translates to:
  /// **'{account} は既定の版に従います'**
  String storeVersionsAccountFollows(String account);

  /// No description provided for @storeVersionsAccountUses.
  ///
  /// In ja, this message translates to:
  /// **'{account} は {version} を使います'**
  String storeVersionsAccountUses(String account, String version);

  /// No description provided for @storeVersionsDefaultShort.
  ///
  /// In ja, this message translates to:
  /// **'既定({version})'**
  String storeVersionsDefaultShort(String version);

  /// No description provided for @storeVersionsPackNote.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え / ステッカー・素材は端末全体で 1 つの版を使います(既定の版)。'**
  String get storeVersionsPackNote;

  /// No description provided for @storeUpdateModeAuto.
  ///
  /// In ja, this message translates to:
  /// **'おまかせ'**
  String get storeUpdateModeAuto;

  /// No description provided for @storeUpdateModeAutoDescription.
  ///
  /// In ja, this message translates to:
  /// **'新しい版を入れて、既定の版にします(アカウントごとに指定した版はそのまま)'**
  String get storeUpdateModeAutoDescription;

  /// No description provided for @storeUpdateModeInstallOnly.
  ///
  /// In ja, this message translates to:
  /// **'インストールだけおまかせ'**
  String get storeUpdateModeInstallOnly;

  /// No description provided for @storeUpdateModeInstallOnlyDescription.
  ///
  /// In ja, this message translates to:
  /// **'新しい版を入れておくだけで、使う版は変えません'**
  String get storeUpdateModeInstallOnlyDescription;

  /// No description provided for @storeUpdateModeManual.
  ///
  /// In ja, this message translates to:
  /// **'全て手動で構成'**
  String get storeUpdateModeManual;

  /// No description provided for @storeUpdateModeManualDescription.
  ///
  /// In ja, this message translates to:
  /// **'自動では何もしません(プラグインを管理から入れます)'**
  String get storeUpdateModeManualDescription;

  /// No description provided for @storeUpdateGroupSns.
  ///
  /// In ja, this message translates to:
  /// **'SNSプラグイン'**
  String get storeUpdateGroupSns;

  /// No description provided for @storeUpdateGroupAction.
  ///
  /// In ja, this message translates to:
  /// **'アクションプラグイン'**
  String get storeUpdateGroupAction;

  /// No description provided for @storeUpdateGroupView.
  ///
  /// In ja, this message translates to:
  /// **'ビュープラグイン'**
  String get storeUpdateGroupView;

  /// 更新ログの 1 行。from / to は版
  ///
  /// In ja, this message translates to:
  /// **'{from} → {to}(既定の版にしました)'**
  String storeUpdateLogActivated(String from, String to);

  /// No description provided for @storeUpdateLogInstalled.
  ///
  /// In ja, this message translates to:
  /// **'{to} を入れました(使う版は {from} のまま)'**
  String storeUpdateLogInstalled(String from, String to);

  /// No description provided for @storeUpdateLogSwitched.
  ///
  /// In ja, this message translates to:
  /// **'{from} → {to}(入っていた版を既定に)'**
  String storeUpdateLogSwitched(String from, String to);

  /// No description provided for @storeUpdateLogSkipped.
  ///
  /// In ja, this message translates to:
  /// **'{to} は自動では入れません'**
  String storeUpdateLogSkipped(String to);

  /// note は理由
  ///
  /// In ja, this message translates to:
  /// **'{to} は自動では入れません({note})'**
  String storeUpdateLogSkippedNote(String to, String note);

  /// No description provided for @storeUpdateLogFailed.
  ///
  /// In ja, this message translates to:
  /// **'{to} を入れられませんでした'**
  String storeUpdateLogFailed(String to);

  /// note は理由
  ///
  /// In ja, this message translates to:
  /// **'{to} を入れられませんでした({note})'**
  String storeUpdateLogFailedNote(String to, String note);

  /// No description provided for @storeUpdatePopupTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインをアップデートしました'**
  String get storeUpdatePopupTitle;

  /// No description provided for @storeClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get storeClose;

  /// No description provided for @storeReviewsTitle.
  ///
  /// In ja, this message translates to:
  /// **'レビュー'**
  String get storeReviewsTitle;

  /// No description provided for @storeReviewsLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'レビューを取得できませんでした'**
  String get storeReviewsLoadFailed;

  /// No description provided for @storeReviewWrite.
  ///
  /// In ja, this message translates to:
  /// **'レビューを書く'**
  String get storeReviewWrite;

  /// No description provided for @storeReviewsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'まだレビューがありません'**
  String get storeReviewsEmpty;

  /// No description provided for @storeReviewsEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'右下の + から最初のレビューを書けます'**
  String get storeReviewsEmptyHint;

  /// No description provided for @storeCopyLink.
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get storeCopyLink;

  /// No description provided for @storeReviewReport.
  ///
  /// In ja, this message translates to:
  /// **'レビューを報告'**
  String get storeReviewReport;

  /// No description provided for @storeReviewLinkCopied.
  ///
  /// In ja, this message translates to:
  /// **'レビューのリンクをコピーしました'**
  String get storeReviewLinkCopied;

  /// No description provided for @storeReviewReportUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'レビューの報告は準備中です'**
  String get storeReviewReportUnavailable;

  /// No description provided for @storeReloadFailed.
  ///
  /// In ja, this message translates to:
  /// **'読み直せませんでした: {error}'**
  String storeReloadFailed(String error);

  /// No description provided for @storeNoNewPlugins.
  ///
  /// In ja, this message translates to:
  /// **'新しく公開されたプラグインはありません'**
  String get storeNoNewPlugins;

  /// No description provided for @storeNewPluginsAdded.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{新しく公開されたプラグインを {count} 件追加しました}}'**
  String storeNewPluginsAdded(int count);

  /// No description provided for @storeSearchTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを検索'**
  String get storeSearchTitle;

  /// No description provided for @storeSearchRecentPick.
  ///
  /// In ja, this message translates to:
  /// **'最近の投稿内容から選出'**
  String get storeSearchRecentPick;

  /// No description provided for @storeSearchFailed.
  ///
  /// In ja, this message translates to:
  /// **'検索できませんでした'**
  String get storeSearchFailed;

  /// No description provided for @storeSearchNoRecentPosts.
  ///
  /// In ja, this message translates to:
  /// **'最近の投稿が見つかりませんでした'**
  String get storeSearchNoRecentPosts;

  /// No description provided for @storeSearchNoRecentPostsHint.
  ///
  /// In ja, this message translates to:
  /// **'SNS アカウントで投稿すると、その内容に近いプラグインを選びます'**
  String get storeSearchNoRecentPostsHint;

  /// No description provided for @storeSearchRecentCaption.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{最近の投稿 {count} 件の内容に近い順(端末の中で選んでいます)}}'**
  String storeSearchRecentCaption(int count);

  /// No description provided for @storeSearchNoRecentMatches.
  ///
  /// In ja, this message translates to:
  /// **'最近の投稿に近いプラグインは見つかりませんでした'**
  String get storeSearchNoRecentMatches;

  /// No description provided for @storeSearchNoResults.
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした'**
  String get storeSearchNoResults;

  /// No description provided for @storeSearchNoResultsHint.
  ///
  /// In ja, this message translates to:
  /// **'ワードや絞り込みを変えてみてください'**
  String get storeSearchNoResultsHint;

  /// No description provided for @storeHomeTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグインストア'**
  String get storeHomeTitle;

  /// No description provided for @storeConnectFailed.
  ///
  /// In ja, this message translates to:
  /// **'ストアに接続できませんでした'**
  String get storeConnectFailed;

  /// No description provided for @storeHomeOffline.
  ///
  /// In ja, this message translates to:
  /// **'RASQ サーバーにつながっていません。アプリに入っているプラグインだけを表示しています'**
  String get storeHomeOffline;

  /// No description provided for @storeHomeOfflineDetail.
  ///
  /// In ja, this message translates to:
  /// **'Central 未接続: 同梱の実物(Misskey コネクタとスロットのサンプル)だけ。評価 / ダウンロード数 / レビュー / 購入はサーバーにつなぐと出ます。'**
  String get storeHomeOfflineDetail;

  /// No description provided for @storeHomeTrending.
  ///
  /// In ja, this message translates to:
  /// **'今週のトレンド'**
  String get storeHomeTrending;

  /// No description provided for @storeHomeRecent.
  ///
  /// In ja, this message translates to:
  /// **'新着'**
  String get storeHomeRecent;

  /// No description provided for @storeHomeReviewedOnly.
  ///
  /// In ja, this message translates to:
  /// **'掲載されるのは審査済みのプラグインだけです'**
  String get storeHomeReviewedOnly;

  /// No description provided for @storeHomeReviewedOnlyDetail.
  ///
  /// In ja, this message translates to:
  /// **'開発中のプラグインは、開発者モードで右上の歯車 → プラグインを管理 →「プラグインのインポート」から入れられます。'**
  String get storeHomeReviewedOnlyDetail;

  /// No description provided for @storeRowEmpty.
  ///
  /// In ja, this message translates to:
  /// **'いまは表示できるプラグインがありません'**
  String get storeRowEmpty;

  /// No description provided for @storeInstallManifestUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'構成を取得できませんでした'**
  String get storeInstallManifestUnavailable;

  /// インストールの確認シートの見出し
  ///
  /// In ja, this message translates to:
  /// **'{name} {version} をインストール'**
  String storeInstallSheetTitle(String name, String version);

  /// No description provided for @storeInstallPermissionsHeader.
  ///
  /// In ja, this message translates to:
  /// **'このプラグインが使う権限'**
  String get storeInstallPermissionsHeader;

  /// No description provided for @storeInstallHostsHeader.
  ///
  /// In ja, this message translates to:
  /// **'接続先'**
  String get storeInstallHostsHeader;

  /// No description provided for @storeInstallLoginInstance.
  ///
  /// In ja, this message translates to:
  /// **'ログイン先のインスタンス'**
  String get storeInstallLoginInstance;

  /// No description provided for @storeInstallScopeNoRecord.
  ///
  /// In ja, this message translates to:
  /// **'許可する内容(前に入れたときの記録がありません)'**
  String get storeInstallScopeNoRecord;

  /// No description provided for @storeInstallScopeWidened.
  ///
  /// In ja, this message translates to:
  /// **'最後に許可した内容から広がるもの'**
  String get storeInstallScopeWidened;

  /// No description provided for @storeInstallPermissionsAdded.
  ///
  /// In ja, this message translates to:
  /// **'前のバージョンから増えた権限'**
  String get storeInstallPermissionsAdded;

  /// 配布物の大きさ(MB、小数 1 桁)と署名の有無(storeInstallSignedShort / storeInstallUnsignedShort)
  ///
  /// In ja, this message translates to:
  /// **'{size}MB ・ {signature}'**
  String storeInstallBundleSummary(String size, String signature);

  /// No description provided for @storeInstallSignedShort.
  ///
  /// In ja, this message translates to:
  /// **'ストアの署名あり'**
  String get storeInstallSignedShort;

  /// No description provided for @storeInstallUnsignedShort.
  ///
  /// In ja, this message translates to:
  /// **'ストアの署名なし'**
  String get storeInstallUnsignedShort;

  /// sha512 はダイジェストの先頭 16 文字。signature は storeInstallSignedDetail / storeInstallUnsignedDetail
  ///
  /// In ja, this message translates to:
  /// **'配布物: {size}MB ・ SHA-512 {sha512}… ・ {signature}'**
  String storeInstallBundleDetail(String size, String sha512, String signature);

  /// No description provided for @storeInstallSignedDetail.
  ///
  /// In ja, this message translates to:
  /// **'ストア署名つき (ed25519)'**
  String get storeInstallSignedDetail;

  /// No description provided for @storeInstallUnsignedDetail.
  ///
  /// In ja, this message translates to:
  /// **'ストア署名なし(ハッシュ照合のみ)'**
  String get storeInstallUnsignedDetail;

  /// No description provided for @storeInstallConfirm.
  ///
  /// In ja, this message translates to:
  /// **'インストールする'**
  String get storeInstallConfirm;

  /// No description provided for @storeInstallThemeDarkOnly.
  ///
  /// In ja, this message translates to:
  /// **'{name} を使います。暗いモードのときに効きます'**
  String storeInstallThemeDarkOnly(String name);

  /// No description provided for @storeInstallThemeLightOnly.
  ///
  /// In ja, this message translates to:
  /// **'{name} を使います。明るいモードのときに効きます'**
  String storeInstallThemeLightOnly(String name);

  /// No description provided for @storeInstallThemeApplied.
  ///
  /// In ja, this message translates to:
  /// **'{name} を使います'**
  String storeInstallThemeApplied(String name);

  /// No description provided for @storeInstallDone.
  ///
  /// In ja, this message translates to:
  /// **'{name} {version} をインストールしました'**
  String storeInstallDone(String name, String version);

  /// No description provided for @storeVersionScopeTitle.
  ///
  /// In ja, this message translates to:
  /// **'Ver.{version} は許可する内容が広がります'**
  String storeVersionScopeTitle(String version);

  /// No description provided for @storeVersionScopeConfirm.
  ///
  /// In ja, this message translates to:
  /// **'許可して使う'**
  String get storeVersionScopeConfirm;

  /// No description provided for @storeVersionScopeCancel.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get storeVersionScopeCancel;

  /// No description provided for @storePurchasePointsFailed.
  ///
  /// In ja, this message translates to:
  /// **'ポイントを確かめられませんでした(RASQ アカウントにログインしていますか?): {error}'**
  String storePurchasePointsFailed(String error);

  /// No description provided for @storePurchaseTitle.
  ///
  /// In ja, this message translates to:
  /// **'{name} を購入'**
  String storePurchaseTitle(String name);

  /// No description provided for @storePurchasePrice.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} ポイント}}'**
  String storePurchasePrice(int count);

  /// No description provided for @storePurchaseBalance.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{残り {count} ポイント}}'**
  String storePurchaseBalance(int count);

  /// date は次に失効する日(2026/10/19 の形)、expiring は失効するポイント
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{残り {count} ポイント ・ {date} に {expiring} ポイントが失効}}'**
  String storePurchaseBalanceExpiring(int count, String date, int expiring);

  /// No description provided for @storePurchaseCaption.
  ///
  /// In ja, this message translates to:
  /// **'買ったプラグインは、同じアカウントならどの端末でも使えます'**
  String get storePurchaseCaption;

  /// No description provided for @storePurchaseCaptionDetail.
  ///
  /// In ja, this message translates to:
  /// **'買ったプラグインは、同じ RASQ アカウントならどの端末でも入れられます。ポイントは有効期限の近いものから使います。'**
  String get storePurchaseCaptionDetail;

  /// No description provided for @storePurchaseBuy.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} ポイントで購入する}}'**
  String storePurchaseBuy(int count);

  /// No description provided for @storePurchaseShort.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{ポイントが足りません(あと {count} ポイント)}}'**
  String storePurchaseShort(int count);

  /// No description provided for @storePurchaseConsole.
  ///
  /// In ja, this message translates to:
  /// **'Web コンソールでポイントを買う'**
  String get storePurchaseConsole;

  /// No description provided for @storePurchaseFailed.
  ///
  /// In ja, this message translates to:
  /// **'購入できませんでした'**
  String get storePurchaseFailed;

  /// No description provided for @storeReleaseNotesSemantics.
  ///
  /// In ja, this message translates to:
  /// **'リリースノート {version}'**
  String storeReleaseNotesSemantics(String version);

  /// No description provided for @storeReleaseBeta.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー版 (β)'**
  String get storeReleaseBeta;

  /// No description provided for @storeReleaseStable.
  ///
  /// In ja, this message translates to:
  /// **'安定版'**
  String get storeReleaseStable;

  /// No description provided for @storeReleasePublishedOn.
  ///
  /// In ja, this message translates to:
  /// **'{year}/{month}/{day} 公開'**
  String storeReleasePublishedOn(int year, int month, int day);

  /// No description provided for @storeReleaseCurrentListing.
  ///
  /// In ja, this message translates to:
  /// **'現在の掲載版'**
  String get storeReleaseCurrentListing;

  /// No description provided for @storeReleaseInstalled.
  ///
  /// In ja, this message translates to:
  /// **'インストール中'**
  String get storeReleaseInstalled;

  /// No description provided for @storeReleaseNoNotes.
  ///
  /// In ja, this message translates to:
  /// **'この版のリリースノートはありません。'**
  String get storeReleaseNoNotes;

  /// No description provided for @storeReleasePermissionsAdded.
  ///
  /// In ja, this message translates to:
  /// **'この版で増えた権限'**
  String get storeReleasePermissionsAdded;

  /// No description provided for @storeReleasePermissionsNote.
  ///
  /// In ja, this message translates to:
  /// **'権限が増える更新は自動アップデートの対象外です。内容を確認してから入れてください。'**
  String get storeReleasePermissionsNote;

  /// No description provided for @storeReleaseAlreadyInstalled.
  ///
  /// In ja, this message translates to:
  /// **'Ver.{version} はインストール済み'**
  String storeReleaseAlreadyInstalled(String version);

  /// status は掲載の状態(停止 / 失効)
  ///
  /// In ja, this message translates to:
  /// **'{status}のためインストールできません'**
  String storeReleaseBlocked(String status);

  /// No description provided for @storeReleaseInstall.
  ///
  /// In ja, this message translates to:
  /// **'Ver.{version} をインストール'**
  String storeReleaseInstall(String version);

  /// No description provided for @storeReleaseReplaces.
  ///
  /// In ja, this message translates to:
  /// **'現在 v{version} が入っています。この版に置き換わります。'**
  String storeReleaseReplaces(String version);

  /// No description provided for @storeReviewNoVotes.
  ///
  /// In ja, this message translates to:
  /// **'まだ評価がありません'**
  String get storeReviewNoVotes;

  /// No description provided for @storeReviewHelpfulCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}人が役に立ったと考えました。}}'**
  String storeReviewHelpfulCount(int count);

  /// No description provided for @storeShare.
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get storeShare;

  /// No description provided for @storeReviewHelpful.
  ///
  /// In ja, this message translates to:
  /// **'参考になった'**
  String get storeReviewHelpful;

  /// No description provided for @storeReviewNotHelpful.
  ///
  /// In ja, this message translates to:
  /// **'参考にならなかった'**
  String get storeReviewNotHelpful;

  /// No description provided for @storeReviewAnonymous.
  ///
  /// In ja, this message translates to:
  /// **'匿名'**
  String get storeReviewAnonymous;

  /// No description provided for @storeReviewVerifiedUse.
  ///
  /// In ja, this message translates to:
  /// **'実利用済み'**
  String get storeReviewVerifiedUse;

  /// No description provided for @storeReviewDeveloperReply.
  ///
  /// In ja, this message translates to:
  /// **'開発者の返信: {reply}'**
  String storeReviewDeveloperReply(String reply);

  /// No description provided for @storeReviewNoBody.
  ///
  /// In ja, this message translates to:
  /// **'(本文なし)'**
  String get storeReviewNoBody;

  /// No description provided for @storeReviewComposeTitle.
  ///
  /// In ja, this message translates to:
  /// **'レビューの作成'**
  String get storeReviewComposeTitle;

  /// No description provided for @storeReviewSend.
  ///
  /// In ja, this message translates to:
  /// **'送信'**
  String get storeReviewSend;

  /// No description provided for @storeRatingLabel.
  ///
  /// In ja, this message translates to:
  /// **'評価'**
  String get storeRatingLabel;

  /// No description provided for @storeReviewTitleHint.
  ///
  /// In ja, this message translates to:
  /// **'見出し(任意)'**
  String get storeReviewTitleHint;

  /// No description provided for @storeReviewBodyHint.
  ///
  /// In ja, this message translates to:
  /// **'使用感や気になった点を入力してください'**
  String get storeReviewBodyHint;

  /// No description provided for @storeReviewUsedVersion.
  ///
  /// In ja, this message translates to:
  /// **'利用バージョン: v{version}'**
  String storeReviewUsedVersion(String version);

  /// No description provided for @storeReviewPickRating.
  ///
  /// In ja, this message translates to:
  /// **'★ を選んでください'**
  String get storeReviewPickRating;

  /// No description provided for @storeReviewSent.
  ///
  /// In ja, this message translates to:
  /// **'レビューを送信しました'**
  String get storeReviewSent;

  /// No description provided for @storeReviewSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'レビューを送信できませんでした: {error}'**
  String storeReviewSendFailed(String error);

  /// インストールしていないプラグインのストアのページ / レビュー TL に出す案内。レビューを書く欄の代わり (D-515)
  ///
  /// In ja, this message translates to:
  /// **'インストールしたプラグインにだけレビューを書けます'**
  String get storeReviewNeedsInstall;

  /// 端末には入っているが、サーバーにインストールの記録が無い(ログインせずに入れた など)とき (review_requires_install、D-515)
  ///
  /// In ja, this message translates to:
  /// **'インストールしたプラグインにだけレビューを書けます。ログインした状態でインストール(または更新)し直すと書けるようになります'**
  String get storeReviewNeedsInstallServer;

  /// No description provided for @storeSafetyNoPermissions.
  ///
  /// In ja, this message translates to:
  /// **'必要な権限: なし'**
  String get storeSafetyNoPermissions;

  /// No description provided for @storeSafetyExternalHeader.
  ///
  /// In ja, this message translates to:
  /// **'外部通信とデータ'**
  String get storeSafetyExternalHeader;

  /// No description provided for @storeSafetyNoHosts.
  ///
  /// In ja, this message translates to:
  /// **'外部通信先: なし'**
  String get storeSafetyNoHosts;

  /// hosts は接続先を区切りでつないだもの
  ///
  /// In ja, this message translates to:
  /// **'外部通信先: {hosts}'**
  String storeSafetyHosts(String hosts);

  /// No description provided for @storeSafetyDataHandling.
  ///
  /// In ja, this message translates to:
  /// **'データの扱い: {text}'**
  String storeSafetyDataHandling(String text);

  /// No description provided for @storeSafetySdks.
  ///
  /// In ja, this message translates to:
  /// **'外部 SDK: {sdks}'**
  String storeSafetySdks(String sdks);

  /// No description provided for @storeSafetyRuntimeHeader.
  ///
  /// In ja, this message translates to:
  /// **'実行環境'**
  String get storeSafetyRuntimeHeader;

  /// rate は百分率(小数 1 桁)
  ///
  /// In ja, this message translates to:
  /// **'正常起動率 {rate}%'**
  String storeSafetyCrashFree(String rate);

  /// No description provided for @storeSafetyBackground.
  ///
  /// In ja, this message translates to:
  /// **'バックグラウンド実行あり'**
  String get storeSafetyBackground;

  /// No description provided for @storeSafetyNoBackground.
  ///
  /// In ja, this message translates to:
  /// **'バックグラウンド実行なし'**
  String get storeSafetyNoBackground;

  /// No description provided for @storeSafetyGpu.
  ///
  /// In ja, this message translates to:
  /// **'GPU 使用'**
  String get storeSafetyGpu;

  /// No description provided for @storeSafetyNoGpu.
  ///
  /// In ja, this message translates to:
  /// **'GPU 不使用'**
  String get storeSafetyNoGpu;

  /// No description provided for @storeSafetyNoAds.
  ///
  /// In ja, this message translates to:
  /// **'広告なし'**
  String get storeSafetyNoAds;

  /// placements は広告の場所を区切りでつないだもの
  ///
  /// In ja, this message translates to:
  /// **'広告あり({placements})'**
  String storeSafetyAds(String placements);

  /// No description provided for @storePageMenuPostReview.
  ///
  /// In ja, this message translates to:
  /// **'レビューを投稿'**
  String get storePageMenuPostReview;

  /// No description provided for @storePageMenuReport.
  ///
  /// In ja, this message translates to:
  /// **'プラグインを報告'**
  String get storePageMenuReport;

  /// No description provided for @storePageLinkCopied.
  ///
  /// In ja, this message translates to:
  /// **'ストアページのリンクをコピーしました'**
  String get storePageLinkCopied;

  /// No description provided for @storePageTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get storePageTitle;

  /// No description provided for @storePageMaybeWithdrawn.
  ///
  /// In ja, this message translates to:
  /// **'取り下げられた可能性があります'**
  String get storePageMaybeWithdrawn;

  /// No description provided for @storePageOpenInstalled.
  ///
  /// In ja, this message translates to:
  /// **'インストール済みの情報を見る'**
  String get storePageOpenInstalled;

  /// 必要プラグインのリンクの前に置く文(リンクは / で区切って並ぶ)
  ///
  /// In ja, this message translates to:
  /// **'このプラグインを利用するには '**
  String get storePageRequiresPrefix;

  /// 必要プラグインのリンクの後ろに置く文
  ///
  /// In ja, this message translates to:
  /// **' のインストールが必要です。'**
  String get storePageRequiresSuffix;

  /// No description provided for @storePageInstalledVersion.
  ///
  /// In ja, this message translates to:
  /// **'インストール済み v{version}'**
  String storePageInstalledVersion(String version);

  /// No description provided for @storePageInstalledVersionVerified.
  ///
  /// In ja, this message translates to:
  /// **'インストール済み v{version}(SHA-512 検証済み)'**
  String storePageInstalledVersionVerified(String version);

  /// No description provided for @storeFree.
  ///
  /// In ja, this message translates to:
  /// **'無料'**
  String get storeFree;

  /// 値段(円、整数)
  ///
  /// In ja, this message translates to:
  /// **'¥{amount}'**
  String storePriceYen(String amount);

  /// No description provided for @storePageInstall.
  ///
  /// In ja, this message translates to:
  /// **'インストール'**
  String get storePageInstall;

  /// No description provided for @storePageBuy.
  ///
  /// In ja, this message translates to:
  /// **'¥{amount} で購入'**
  String storePageBuy(String amount);

  /// No description provided for @storePageThemeInUse.
  ///
  /// In ja, this message translates to:
  /// **'使用中'**
  String get storePageThemeInUse;

  /// No description provided for @storePageThemeUse.
  ///
  /// In ja, this message translates to:
  /// **'使う'**
  String get storePageThemeUse;

  /// No description provided for @storePageUnknownDeveloper.
  ///
  /// In ja, this message translates to:
  /// **'提供元不明'**
  String get storePageUnknownDeveloper;

  /// rating は小数 1 桁、downloads は整形したダウンロード数
  ///
  /// In ja, this message translates to:
  /// **'★{rating} ・ {downloads} DL'**
  String storePageRatingDownloads(String rating, String downloads);

  /// No description provided for @storePageStatus.
  ///
  /// In ja, this message translates to:
  /// **'状態: {status}'**
  String storePageStatus(String status);

  /// No description provided for @storePagePreview.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get storePagePreview;

  /// No description provided for @storePageDownloadsLastMonth.
  ///
  /// In ja, this message translates to:
  /// **'先月のダウンロード数'**
  String get storePageDownloadsLastMonth;

  /// No description provided for @storePageReviewCount.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件}}'**
  String storePageReviewCount(int count);

  /// No description provided for @storePageReviewsEmptyBody.
  ///
  /// In ja, this message translates to:
  /// **'最初のレビューを書いてみませんか。'**
  String get storePageReviewsEmptyBody;

  /// No description provided for @storePageUpdatesHeader.
  ///
  /// In ja, this message translates to:
  /// **'アップデートとバージョン'**
  String get storePageUpdatesHeader;

  /// No description provided for @storePageNoReleaseNotes.
  ///
  /// In ja, this message translates to:
  /// **'リリースノートはまだありません。'**
  String get storePageNoReleaseNotes;

  /// No description provided for @storeInUse.
  ///
  /// In ja, this message translates to:
  /// **'利用中'**
  String get storeInUse;

  /// permissions は権限の id を区切りでつないだもの
  ///
  /// In ja, this message translates to:
  /// **'権限の追加: {permissions}'**
  String storePermissionsAddedList(String permissions);

  /// No description provided for @storePagePermissionsHeader.
  ///
  /// In ja, this message translates to:
  /// **'権限'**
  String get storePagePermissionsHeader;

  /// No description provided for @storePageNoPermissions.
  ///
  /// In ja, this message translates to:
  /// **'このプラグインは追加の権限を要求しません。'**
  String get storePageNoPermissions;

  /// No description provided for @storePageCompatibilityHeader.
  ///
  /// In ja, this message translates to:
  /// **'互換性'**
  String get storePageCompatibilityHeader;

  /// No description provided for @storePageRuntimes.
  ///
  /// In ja, this message translates to:
  /// **'ランタイム: {runtimes}'**
  String storePageRuntimes(String runtimes);

  /// No description provided for @storePageRequiredPlugins.
  ///
  /// In ja, this message translates to:
  /// **'必要プラグイン: {plugins}'**
  String storePageRequiredPlugins(String plugins);

  /// No description provided for @storePageConflicts.
  ///
  /// In ja, this message translates to:
  /// **'競合: {plugins}'**
  String storePageConflicts(String plugins);

  /// No description provided for @storePageRasqFeatures.
  ///
  /// In ja, this message translates to:
  /// **'利用する RASQ 機能: {features}'**
  String storePageRasqFeatures(String features);

  /// No description provided for @storePageVersionsTitle.
  ///
  /// In ja, this message translates to:
  /// **'バージョン'**
  String get storePageVersionsTitle;

  /// No description provided for @storePageNoPreview.
  ///
  /// In ja, this message translates to:
  /// **'{name} のプレビュー画像はまだありません'**
  String storePageNoPreview(String name);

  /// No description provided for @storePageBookmarkRemove.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークを外す'**
  String get storePageBookmarkRemove;

  /// No description provided for @storePageBookmarkAdd.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークする'**
  String get storePageBookmarkAdd;

  /// No description provided for @storePageBookmarkFailed.
  ///
  /// In ja, this message translates to:
  /// **'ブックマークを更新できませんでした: {error}'**
  String storePageBookmarkFailed(String error);

  /// feature は機能の名前(storeFeaturePurchase など)
  ///
  /// In ja, this message translates to:
  /// **'{feature}は RASQ サーバーにつなぐと使えます'**
  String storeNeedsServer(String feature);

  /// No description provided for @storeNoListing.
  ///
  /// In ja, this message translates to:
  /// **'掲載がありません'**
  String get storeNoListing;

  /// No description provided for @storeCatalogMisskeyName.
  ///
  /// In ja, this message translates to:
  /// **'Misskey コネクタ'**
  String get storeCatalogMisskeyName;

  /// No description provided for @storeCatalogMisskeySummary.
  ///
  /// In ja, this message translates to:
  /// **'Misskey を RASQ に繋ぐ SNS プラグイン(wasm サンプル)。TL 取得/投稿/リアクション/絵文字/投稿加工まで一式。'**
  String get storeCatalogMisskeySummary;

  /// No description provided for @storeCatalogMisskeyDescription.
  ///
  /// In ja, this message translates to:
  /// **'rasq-sdk-sample の Rust 製 wasm プラグインです。sns.login / sns.timeline / post.transform / tl.sort などの契約(PROTOCOL.md)を実装し、RRL タイルで TL を描画します。ノード定義を持たない投稿加工は、取得ノードに渡す直前に適用されます。'**
  String get storeCatalogMisskeyDescription;

  /// No description provided for @storeCatalogFeatureTimelineRrl.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン描画 (RRL)'**
  String get storeCatalogFeatureTimelineRrl;

  /// No description provided for @storeCatalogFeatureNodeGraph.
  ///
  /// In ja, this message translates to:
  /// **'ノードグラフ (tl.sort)'**
  String get storeCatalogFeatureNodeGraph;

  /// No description provided for @storeCatalogMisskeyPerm1.
  ///
  /// In ja, this message translates to:
  /// **'Misskey インスタンスの API を呼ぶため(接続先はログイン時に指定したホストのみ)'**
  String get storeCatalogMisskeyPerm1;

  /// No description provided for @storeCatalogMisskeyPerm2.
  ///
  /// In ja, this message translates to:
  /// **'セッショントークンと TL 設定の保存'**
  String get storeCatalogMisskeyPerm2;

  /// No description provided for @storeCatalogMisskeyHost.
  ///
  /// In ja, this message translates to:
  /// **'<ログインした Misskey インスタンス>'**
  String get storeCatalogMisskeyHost;

  /// No description provided for @storeCatalogMisskeyDataHandling.
  ///
  /// In ja, this message translates to:
  /// **'投稿・トークンは端末内(storage.safe)にのみ保存。開発元への送信はありません。'**
  String get storeCatalogMisskeyDataHandling;

  /// No description provided for @storeCatalogSampleDataHandling.
  ///
  /// In ja, this message translates to:
  /// **'処理は端末内の wasm で完結し、外部送信はありません。'**
  String get storeCatalogSampleDataHandling;

  /// No description provided for @storeCatalogAstellName.
  ///
  /// In ja, this message translates to:
  /// **'ASTell 効果音・効果映像'**
  String get storeCatalogAstellName;

  /// No description provided for @storeCatalogAstellSummary.
  ///
  /// In ja, this message translates to:
  /// **'ASTell のプラグインアクションから効果音 / 生成した効果映像 / 定型テキストを流します。'**
  String get storeCatalogAstellSummary;

  /// No description provided for @storeCatalogAstellDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `astell.action`。ルーム下段の、このプラグインが宣言したボタンで FOW を開き、システム音(ピンポン / クリック)、紙吹雪・花火・拍手の生成 PNG、定型テキストを共有します。「ASTell で共有」した投稿の受け取りも表示します。'**
  String get storeCatalogAstellDescription;

  /// No description provided for @storeCatalogFeatureAstellAction.
  ///
  /// In ja, this message translates to:
  /// **'ASTell プラグインアクション'**
  String get storeCatalogFeatureAstellAction;

  /// No description provided for @storeCatalogAstellPerm1.
  ///
  /// In ja, this message translates to:
  /// **'操作パネル(FOW)を出すため'**
  String get storeCatalogAstellPerm1;

  /// No description provided for @storeCatalogAstellPerm2.
  ///
  /// In ja, this message translates to:
  /// **'効果の使用回数の保存'**
  String get storeCatalogAstellPerm2;

  /// No description provided for @storeCatalogComposerMediaName.
  ///
  /// In ja, this message translates to:
  /// **'メディア加工'**
  String get storeCatalogComposerMediaName;

  /// No description provided for @storeCatalogComposerMediaSummary.
  ///
  /// In ja, this message translates to:
  /// **'添付画像のガンマ補正 / 回転 / 色相 / クロップ。'**
  String get storeCatalogComposerMediaSummary;

  /// No description provided for @storeCatalogComposerMediaDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `composer.media`。コンポーザーの添付タイルの「プラグインで加工」で FOW を開き、プレビューを見ながら適用します。処理は端末内の wasm だけで完結します。'**
  String get storeCatalogComposerMediaDescription;

  /// No description provided for @storeCatalogFeatureMediaComposer.
  ///
  /// In ja, this message translates to:
  /// **'メディアコンポーザー'**
  String get storeCatalogFeatureMediaComposer;

  /// No description provided for @storeCatalogComposerMediaPerm1.
  ///
  /// In ja, this message translates to:
  /// **'加工パネル(FOW)を出すため'**
  String get storeCatalogComposerMediaPerm1;

  /// No description provided for @storeCatalogComposerMediaPerm2.
  ///
  /// In ja, this message translates to:
  /// **'前回の設定の保存'**
  String get storeCatalogComposerMediaPerm2;

  /// No description provided for @storeCatalogComposerTextName.
  ///
  /// In ja, this message translates to:
  /// **'ハッシュタグ候補'**
  String get storeCatalogComposerTextName;

  /// No description provided for @storeCatalogComposerTextSummary.
  ///
  /// In ja, this message translates to:
  /// **'本文で # を打つと候補が出て、タップで挿入します。'**
  String get storeCatalogComposerTextSummary;

  /// No description provided for @storeCatalogComposerTextDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `composer.text`。本文の変化を受け取り、カーソル直前が #〜 のときに候補 FOW(最近使ったタグ + 辞書)を出します。'**
  String get storeCatalogComposerTextDescription;

  /// No description provided for @storeCatalogFeatureTextComposer.
  ///
  /// In ja, this message translates to:
  /// **'テキストコンポーザー'**
  String get storeCatalogFeatureTextComposer;

  /// No description provided for @storeCatalogComposerTextPerm1.
  ///
  /// In ja, this message translates to:
  /// **'候補パネル(FOW)を出すため'**
  String get storeCatalogComposerTextPerm1;

  /// No description provided for @storeCatalogComposerTextPerm2.
  ///
  /// In ja, this message translates to:
  /// **'最近使ったタグの保存'**
  String get storeCatalogComposerTextPerm2;

  /// No description provided for @storeCatalogMediaFullscreenName.
  ///
  /// In ja, this message translates to:
  /// **'QR コード検出'**
  String get storeCatalogMediaFullscreenName;

  /// No description provided for @storeCatalogMediaFullscreenSummary.
  ///
  /// In ja, this message translates to:
  /// **'全画面表示の画像から QR コードを見つけて枠を出し、タップでリンクを開けます。'**
  String get storeCatalogMediaFullscreenSummary;

  /// No description provided for @storeCatalogMediaFullscreenDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `viewer.overlay`。全画面ビューワーの画像を受け取って QR を検出し、バウンディングボックスを重ねます。タップでリンク FOW(コピー / ブラウザで開く / ミュート語に追加)。'**
  String get storeCatalogMediaFullscreenDescription;

  /// No description provided for @storeCatalogFeatureViewerPlugin.
  ///
  /// In ja, this message translates to:
  /// **'全画面表示プラグイン'**
  String get storeCatalogFeatureViewerPlugin;

  /// No description provided for @storeCatalogMediaFullscreenPerm1.
  ///
  /// In ja, this message translates to:
  /// **'リンクパネル(FOW)を出すため'**
  String get storeCatalogMediaFullscreenPerm1;

  /// No description provided for @storeCatalogMediaFullscreenPerm2.
  ///
  /// In ja, this message translates to:
  /// **'「このリンクをミュート」でミュート語に追加するため(毎回確認)'**
  String get storeCatalogMediaFullscreenPerm2;

  /// No description provided for @storeCatalogPostProcessName.
  ///
  /// In ja, this message translates to:
  /// **'相対日付を日付に'**
  String get storeCatalogPostProcessName;

  /// No description provided for @storeCatalogPostProcessSummary.
  ///
  /// In ja, this message translates to:
  /// **'「今日」「昨日」「明日」を投稿日基準の日付に置き換えます。'**
  String get storeCatalogPostProcessSummary;

  /// No description provided for @storeCatalogPostProcessDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `post.transform`。全 TL の表示直前に本文の相対日付を「9/10(今日)」のように書き換えます(JST)。URL の中は触りません。'**
  String get storeCatalogPostProcessDescription;

  /// No description provided for @storeCatalogFeaturePostTransform.
  ///
  /// In ja, this message translates to:
  /// **'投稿加工 (post.transform)'**
  String get storeCatalogFeaturePostTransform;

  /// No description provided for @storeCatalogTimelineName.
  ///
  /// In ja, this message translates to:
  /// **'Unicode 昇順 TL'**
  String get storeCatalogTimelineName;

  /// No description provided for @storeCatalogTimelineSummary.
  ///
  /// In ja, this message translates to:
  /// **'ホームに本文の Unicode 順で並ぶタブを足します。'**
  String get storeCatalogTimelineSummary;

  /// No description provided for @storeCatalogTimelineDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `tl`。基礎 TL(ホーム)を受け取り、本文の Unicode コードポイント昇順で並べ替えたカスタムタブを出します。'**
  String get storeCatalogTimelineDescription;

  /// No description provided for @storeCatalogFeatureTimelineSort.
  ///
  /// In ja, this message translates to:
  /// **'タイムライン (tl.sort)'**
  String get storeCatalogFeatureTimelineSort;

  /// No description provided for @storeCatalogPostShareName.
  ///
  /// In ja, this message translates to:
  /// **'共有テンプレート'**
  String get storeCatalogPostShareName;

  /// No description provided for @storeCatalogPostShareSummary.
  ///
  /// In ja, this message translates to:
  /// **'共有 FOW から投稿をテンプレート(リンク / 引用 / 作者に言及)で整えてコンポーザーへ。'**
  String get storeCatalogPostShareSummary;

  /// No description provided for @storeCatalogPostShareDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `post.share`。投稿の共有 FOW の「プラグイン」節に自動で並び、タップするとインライン FOW で文面を選んでコンポーザー / コピー / ブラウザ / ASTell へ渡します。'**
  String get storeCatalogPostShareDescription;

  /// No description provided for @storeCatalogFeaturePostShare.
  ///
  /// In ja, this message translates to:
  /// **'投稿共有 (post.share)'**
  String get storeCatalogFeaturePostShare;

  /// No description provided for @storeCatalogPostSharePerm1.
  ///
  /// In ja, this message translates to:
  /// **'テンプレート選択パネル(FOW)を出すため'**
  String get storeCatalogPostSharePerm1;

  /// No description provided for @storeCatalogPostSharePerm2.
  ///
  /// In ja, this message translates to:
  /// **'前回のテンプレートの保存'**
  String get storeCatalogPostSharePerm2;

  /// No description provided for @storeCatalogMediaTransformName.
  ///
  /// In ja, this message translates to:
  /// **'変形ハンドル'**
  String get storeCatalogMediaTransformName;

  /// No description provided for @storeCatalogMediaTransformSummary.
  ///
  /// In ja, this message translates to:
  /// **'画像の上に回転 / クロップのハンドルを重ねて編集します。'**
  String get storeCatalogMediaTransformSummary;

  /// No description provided for @storeCatalogMediaTransformDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `composer.media`(変形)。メディアエディターのプレビューに RRL の重ね(契約 v0.5 `composer.media.overlay`)でハンドルを描き、指でなぞって回転角やクロップ範囲を決めます。'**
  String get storeCatalogMediaTransformDescription;

  /// No description provided for @storeCatalogFeatureOverlay.
  ///
  /// In ja, this message translates to:
  /// **'重ね (overlay)'**
  String get storeCatalogFeatureOverlay;

  /// No description provided for @storeCatalogMediaTransformPerm1.
  ///
  /// In ja, this message translates to:
  /// **'パネル(FOW)を出すため'**
  String get storeCatalogMediaTransformPerm1;

  /// No description provided for @storeCatalogMediaProcessName.
  ///
  /// In ja, this message translates to:
  /// **'加工(顔ぼかし / スタンプ)'**
  String get storeCatalogMediaProcessName;

  /// No description provided for @storeCatalogMediaProcessSummary.
  ///
  /// In ja, this message translates to:
  /// **'顔を検知してぼかす、スタンプをオブジェクトとして貼る(移動 / 拡縮 / 回転 / 削除 / 複製)。'**
  String get storeCatalogMediaProcessSummary;

  /// No description provided for @storeCatalogMediaProcessDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `composer.media`(加工)。顔検知は端末内の wasm(rustface)で行い、外部送信はありません。スタンプは重ねの枠とハンドルで動かせます。'**
  String get storeCatalogMediaProcessDescription;

  /// No description provided for @storeCatalogMediaProcessPerm1.
  ///
  /// In ja, this message translates to:
  /// **'スタンプ選択パネル(FOW)を出すため'**
  String get storeCatalogMediaProcessPerm1;

  /// No description provided for @storeCatalogMediaDrawName.
  ///
  /// In ja, this message translates to:
  /// **'描画(ペン / 図形)'**
  String get storeCatalogMediaDrawName;

  /// No description provided for @storeCatalogMediaDrawSummary.
  ///
  /// In ja, this message translates to:
  /// **'ペンの軌跡をスプライン曲線で描く、四角 / 丸を追加して編集します。'**
  String get storeCatalogMediaDrawSummary;

  /// No description provided for @storeCatalogMediaDrawDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `composer.media`(描画)。ペンは指の軌跡を Catmull-Rom スプラインで滑らかにして描きます。図形はオブジェクトとして移動 / 拡縮 / 削除 / 複製できます。'**
  String get storeCatalogMediaDrawDescription;

  /// No description provided for @storeCatalogMediaDrawPerm1.
  ///
  /// In ja, this message translates to:
  /// **'ペンの太さ / 色のパネル(FOW)を出すため'**
  String get storeCatalogMediaDrawPerm1;

  /// No description provided for @storeCatalogMediaDrawPerm2.
  ///
  /// In ja, this message translates to:
  /// **'ペンの設定の保存'**
  String get storeCatalogMediaDrawPerm2;

  /// No description provided for @storeCatalogPostActionName.
  ///
  /// In ja, this message translates to:
  /// **'投稿ボタン'**
  String get storeCatalogPostActionName;

  /// No description provided for @storeCatalogPostActionSummary.
  ///
  /// In ja, this message translates to:
  /// **'後で読む / 本文をコピー / 引用の下書き — タグで既存ボタンのバンドルに入ります。'**
  String get storeCatalogPostActionSummary;

  /// No description provided for @storeCatalogPostActionDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `post.action`。マニフェストのタグ(希望スロット)が既存のアクションボタンに近ければ、そのバンドルの最下層に自動で入ります。「アクションリストの編集」でアカウントごとに有効 / 無効と閾値を変えられます。'**
  String get storeCatalogPostActionDescription;

  /// No description provided for @storeCatalogFeaturePostAction.
  ///
  /// In ja, this message translates to:
  /// **'投稿のアクションボタン (post.action)'**
  String get storeCatalogFeaturePostAction;

  /// No description provided for @storeCatalogPostActionPerm1.
  ///
  /// In ja, this message translates to:
  /// **'後で読む一覧(FOW)を出すため'**
  String get storeCatalogPostActionPerm1;

  /// No description provided for @storeCatalogPostActionPerm2.
  ///
  /// In ja, this message translates to:
  /// **'後で読むの保存'**
  String get storeCatalogPostActionPerm2;

  /// No description provided for @storeCatalogThemeStarryName.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え「星空」'**
  String get storeCatalogThemeStarryName;

  /// No description provided for @storeCatalogThemeStarrySummary.
  ///
  /// In ja, this message translates to:
  /// **'夜空の背景、星の粒を重ねた投稿タイル、星のいいね。'**
  String get storeCatalogThemeStarrySummary;

  /// No description provided for @storeCatalogThemeStarryDescription.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え(`kind: \"theme\"`、契約 v0.16)。コードを持たない配布物で、色 / アイコンの差し替え / 画面・投稿タイル・FOW・ボタンの背景の画像のレイヤーを宣言します。インストール後に 設定 → アプリの外観 → フォントやカラースキーム で選びます(暗いモードのときに効きます)。'**
  String get storeCatalogThemeStarryDescription;

  /// No description provided for @storeCatalogFeatureTheme.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え'**
  String get storeCatalogFeatureTheme;

  /// No description provided for @storeCatalogThemeRasqName.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え「RASQ」'**
  String get storeCatalogThemeRasqName;

  /// No description provided for @storeCatalogThemeRasqSummary.
  ///
  /// In ja, this message translates to:
  /// **'投稿の上に紺のグラデーションの帯と薄い RASQ のマーク、FOW は緑のグラデーション。'**
  String get storeCatalogThemeRasqSummary;

  /// No description provided for @storeCatalogThemeRasqDescription.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え(`kind: \"theme\"`、契約 v0.17)。投稿タイルの上辺に #1F1E33 から投稿の背景色へ溶けるグラデーションの帯、背景に薄い RASQ のマーク、FOW の背景は上から下へ #02775C → #178178 のグラデーション(文字は白)。明るい / 暗いモードのどちらでも効きます。'**
  String get storeCatalogThemeRasqDescription;

  /// No description provided for @storeCatalogPaintName.
  ///
  /// In ja, this message translates to:
  /// **'みんなで落書き'**
  String get storeCatalogPaintName;

  /// No description provided for @storeCatalogPaintSummary.
  ///
  /// In ja, this message translates to:
  /// **'1 人 1 マスの落書きを、期限つきでみんなに見せ合います。ASTell のルームやプロフィールで。'**
  String get storeCatalogPaintSummary;

  /// No description provided for @storeCatalogPaintDescription.
  ///
  /// In ja, this message translates to:
  /// **'カスタムプラグイン(スロット `page`、契約 v0.23)。3:4 のマスを 2 列に並べ(並びは人ごとにシャッフル)、自分のマスを押すとメディア編集画面の SVG モードで落書きします(保存は zstd で縮めて送ります)。表示期間は各自が選び、管理者(セッションの持ち主)が既定と上限を決めます。期限が来ると Central が消します。管理者は他人の落書きを削除できます。'**
  String get storeCatalogPaintDescription;

  /// No description provided for @storeCatalogFeatureCustomPage.
  ///
  /// In ja, this message translates to:
  /// **'カスタムプラグイン (page)'**
  String get storeCatalogFeatureCustomPage;

  /// No description provided for @storeCatalogFeatureSvgPaint.
  ///
  /// In ja, this message translates to:
  /// **'SVG の落書き'**
  String get storeCatalogFeatureSvgPaint;

  /// No description provided for @storeCatalogFeatureDisplayPeriod.
  ///
  /// In ja, this message translates to:
  /// **'表示期間'**
  String get storeCatalogFeatureDisplayPeriod;

  /// No description provided for @storeCatalogFeatureProfile.
  ///
  /// In ja, this message translates to:
  /// **'プロフィール'**
  String get storeCatalogFeatureProfile;

  /// No description provided for @storeCatalogPaintPerm1.
  ///
  /// In ja, this message translates to:
  /// **'落書きのマスを表示し、編集画面を開くため'**
  String get storeCatalogPaintPerm1;

  /// No description provided for @storeCatalogPaintPerm2.
  ///
  /// In ja, this message translates to:
  /// **'みんなの落書きと管理者の設定を、期限つきで共有するため'**
  String get storeCatalogPaintPerm2;

  /// No description provided for @storeCatalogBoardName.
  ///
  /// In ja, this message translates to:
  /// **'みんなのボード'**
  String get storeCatalogBoardName;

  /// No description provided for @storeCatalogBoardSummary.
  ///
  /// In ja, this message translates to:
  /// **'カウンター・投票・寄せ書き・🎉。ASTell のルームやプロフィールで、みんなで同じボードを使えます。'**
  String get storeCatalogBoardSummary;

  /// No description provided for @storeCatalogBoardDescription.
  ///
  /// In ja, this message translates to:
  /// **'カスタムプラグイン(スロット `page`、契約 v0.18)。ページを 1 枚足し、共有セッションではサーバー変数(カウンター / 投票 / 寄せ書き)とサーバー関数(🎉 を全員に)で同じ画面を共有します。セッションが無いときは端末の中だけで動きます。'**
  String get storeCatalogBoardDescription;

  /// No description provided for @storeCatalogBoardPerm1.
  ///
  /// In ja, this message translates to:
  /// **'ページを描くため'**
  String get storeCatalogBoardPerm1;

  /// No description provided for @storeCatalogBoardPerm2.
  ///
  /// In ja, this message translates to:
  /// **'みんなの値(カウンター / 投票 / 寄せ書き)を共有するため'**
  String get storeCatalogBoardPerm2;

  /// No description provided for @storeCatalogBoardPerm3.
  ///
  /// In ja, this message translates to:
  /// **'1 人で使うときのボードの保存'**
  String get storeCatalogBoardPerm3;

  /// No description provided for @storeCatalogTrendName.
  ///
  /// In ja, this message translates to:
  /// **'トレンドサジェスト'**
  String get storeCatalogTrendName;

  /// No description provided for @storeCatalogTrendSummary.
  ///
  /// In ja, this message translates to:
  /// **'今のトレンド語から関連タグをローカル規則で提案します。'**
  String get storeCatalogTrendSummary;

  /// No description provided for @storeCatalogTrendDescription.
  ///
  /// In ja, this message translates to:
  /// **'スロット `trend.suggest`。TL のノード(トレンドを取得 / Today / 候補のチップ)と、検索ホームの「検索の候補」で出します。サーバー無しの共起辞書 + 前方一致です。'**
  String get storeCatalogTrendDescription;

  /// No description provided for @storeCatalogFeatureTrendSuggest.
  ///
  /// In ja, this message translates to:
  /// **'トレンド (trend.suggest)'**
  String get storeCatalogFeatureTrendSuggest;

  /// No description provided for @storePkgMissingPlugin.
  ///
  /// In ja, this message translates to:
  /// **'配布物に {id} がありません'**
  String storePkgMissingPlugin(String id);

  /// No description provided for @storePkgNotPackage.
  ///
  /// In ja, this message translates to:
  /// **'配布物が .rasqpkg(zstd)ではありません'**
  String get storePkgNotPackage;

  /// No description provided for @storePkgUnpack.
  ///
  /// In ja, this message translates to:
  /// **'配布物を展開できません(壊れているか、大きすぎます): {error}'**
  String storePkgUnpack(String error);

  /// No description provided for @storePkgTar.
  ///
  /// In ja, this message translates to:
  /// **'配布物の tar を読めません: {error}'**
  String storePkgTar(String error);

  /// No description provided for @storePkgTooManyFiles.
  ///
  /// In ja, this message translates to:
  /// **'配布物のファイル数が多すぎます'**
  String get storePkgTooManyFiles;

  /// No description provided for @storePkgNotRegularFile.
  ///
  /// In ja, this message translates to:
  /// **'配布物に通常ファイルでないものがあります: {path}'**
  String storePkgNotRegularFile(String path);

  /// No description provided for @storePkgDuplicatePath.
  ///
  /// In ja, this message translates to:
  /// **'配布物内のパスが重複しています: {path}'**
  String storePkgDuplicatePath(String path);

  /// No description provided for @storePkgBundleFirst.
  ///
  /// In ja, this message translates to:
  /// **'配布物の先頭が bundle.json ではありません'**
  String get storePkgBundleFirst;

  /// No description provided for @storePkgBundleRead.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json を読めません: {error}'**
  String storePkgBundleRead(String error);

  /// No description provided for @storePkgBundleSchema.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json の schema が rasq.bundle/1 ではありません: {schema}'**
  String storePkgBundleSchema(String schema);

  /// No description provided for @storePkgFileShape.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {what} の wasm / file の形が違います'**
  String storePkgFileShape(String what);

  /// No description provided for @storePkgNoPath.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {what} に path がありません'**
  String storePkgNoPath(String what);

  /// No description provided for @storePkgSizeMismatch.
  ///
  /// In ja, this message translates to:
  /// **'{path}: 大きさが目次と違います'**
  String storePkgSizeMismatch(String path);

  /// No description provided for @storePkgHashMismatch.
  ///
  /// In ja, this message translates to:
  /// **'{path}: SHA-512 が目次と違います'**
  String storePkgHashMismatch(String path);

  /// No description provided for @storePkgNoSha512.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {what} に sha512 がありません'**
  String storePkgNoSha512(String what);

  /// No description provided for @storePkgNotWasm.
  ///
  /// In ja, this message translates to:
  /// **'{path}: wasm ではありません'**
  String storePkgNotWasm(String path);

  /// No description provided for @storePkgPluginShape.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {what} の形が違います'**
  String storePkgPluginShape(String what);

  /// No description provided for @storePkgBadId.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {what} の id が不正です: {id}'**
  String storePkgBadId(String what, String id);

  /// No description provided for @storePkgBadVersion.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {id} の version が不正です: {version}'**
  String storePkgBadVersion(String id, String version);

  /// No description provided for @storePkgBadKind.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {id} の kind が不正です: {kind}'**
  String storePkgBadKind(String id, String kind);

  /// No description provided for @storePkgNoManifest.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {id} に manifest がありません'**
  String storePkgNoManifest(String id);

  /// No description provided for @storePkgManifestRead.
  ///
  /// In ja, this message translates to:
  /// **'{path} を読めません: {error}'**
  String storePkgManifestRead(String path, String error);

  /// No description provided for @storePkgManifestMismatch.
  ///
  /// In ja, this message translates to:
  /// **'{path}: id / version / kind が目次({id} {version} {kind})と違います'**
  String storePkgManifestMismatch(
    String path,
    String id,
    String version,
    String kind,
  );

  /// No description provided for @storePkgChildPackKind.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: 子 {id} は kind = {kind} にできません'**
  String storePkgChildPackKind(String id, String kind);

  /// No description provided for @storePkgPackHasWasm.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {kind} {id} が wasm を持っています'**
  String storePkgPackHasWasm(String kind, String id);

  /// No description provided for @storePkgMissingKey.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {key} がありません'**
  String storePkgMissingKey(String key);

  /// No description provided for @storePkgChildrenNotSns.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: sns 以外の root は children を持てません'**
  String get storePkgChildrenNotSns;

  /// No description provided for @storePkgChildPrefix.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: 子 {id} の id が {root}. で始まっていません'**
  String storePkgChildPrefix(String id, String root);

  /// No description provided for @storePkgChildSns.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: 子 {id} は kind = sns にできません'**
  String storePkgChildSns(String id);

  /// No description provided for @storePkgDuplicateId.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: プラグインの id が重複しています'**
  String get storePkgDuplicateId;

  /// No description provided for @storePkgLibsShape.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: libs の形が違います'**
  String get storePkgLibsShape;

  /// No description provided for @storePkgAssetsShape.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: assets の形が違います'**
  String get storePkgAssetsShape;

  /// No description provided for @storePkgPackExtras.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: アセットパック / 着せ替えは children / libs / models を持てません'**
  String get storePkgPackExtras;

  /// No description provided for @storePkgPackWasm.
  ///
  /// In ja, this message translates to:
  /// **'アセットパック / 着せ替えに wasm が入っています'**
  String get storePkgPackWasm;

  /// No description provided for @storePkgPackImageCount.
  ///
  /// In ja, this message translates to:
  /// **'アセットパックの画像は 1〜{max} 枚です: {count}'**
  String storePkgPackImageCount(int max, int count);

  /// No description provided for @storePkgNotImage.
  ///
  /// In ja, this message translates to:
  /// **'{path}: 画像(PNG / JPEG / WebP / GIF)ではありません'**
  String storePkgNotImage(String path);

  /// No description provided for @storePkgImageTooLarge.
  ///
  /// In ja, this message translates to:
  /// **'{path}: 大きすぎます(1 枚 {mib} MiB まで)'**
  String storePkgImageTooLarge(String path, int mib);

  /// No description provided for @storePkgAssetNotListed.
  ///
  /// In ja, this message translates to:
  /// **'manifest.assets の {path} が配布物の目次にありません'**
  String storePkgAssetNotListed(String path);

  /// No description provided for @storePkgModelsShape.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: models の形が違います'**
  String get storePkgModelsShape;

  /// No description provided for @storePkgRequiresShape.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: requires の形が違います'**
  String get storePkgRequiresShape;

  /// No description provided for @storePkgNoSums.
  ///
  /// In ja, this message translates to:
  /// **'SHA512SUMS がありません'**
  String get storePkgNoSums;

  /// No description provided for @storePkgSumsMissingFile.
  ///
  /// In ja, this message translates to:
  /// **'{path}: SHA512SUMS にあるのに中にありません'**
  String storePkgSumsMissingFile(String path);

  /// No description provided for @storePkgSumsMismatch.
  ///
  /// In ja, this message translates to:
  /// **'{path}: SHA512SUMS と違います'**
  String storePkgSumsMismatch(String path);

  /// No description provided for @storePkgUnlisted.
  ///
  /// In ja, this message translates to:
  /// **'{path}: 目次に載っていないファイルがあります'**
  String storePkgUnlisted(String path);

  /// No description provided for @storePkgThemeMissing.
  ///
  /// In ja, this message translates to:
  /// **'着せ替えのマニフェストに theme がありません'**
  String get storePkgThemeMissing;

  /// No description provided for @storePkgThemeAsset.
  ///
  /// In ja, this message translates to:
  /// **'theme.{where} の画像 {id} が assets(use: theme)にありません'**
  String storePkgThemeAsset(String where, String id);

  /// No description provided for @storePkgThemeSurface.
  ///
  /// In ja, this message translates to:
  /// **'theme.surfaces の {surface} は使えません(app / postTile / fow / actionButton)'**
  String storePkgThemeSurface(String surface);

  /// No description provided for @storePkgThemeLayer.
  ///
  /// In ja, this message translates to:
  /// **'theme.surfaces.{surface}.layers: asset か gradient のどちらか 1 つを書いてください'**
  String storePkgThemeLayer(String surface);

  /// No description provided for @storePkgThemeColors.
  ///
  /// In ja, this message translates to:
  /// **'theme.surfaces.{surface}.layers: gradient.colors は 2〜8 色です'**
  String storePkgThemeColors(String surface);

  /// No description provided for @storePkgThemeStops.
  ///
  /// In ja, this message translates to:
  /// **'theme.surfaces.{surface}.layers: gradient.stops は colors と同じ数です'**
  String storePkgThemeStops(String surface);

  /// No description provided for @storePkgBadPath.
  ///
  /// In ja, this message translates to:
  /// **'配布物内のパスとして使えません: {path}'**
  String storePkgBadPath(String path);

  /// No description provided for @storePkgSigAlg.
  ///
  /// In ja, this message translates to:
  /// **'署名の alg が ed25519 ではありません: {alg}'**
  String storePkgSigAlg(String alg);

  /// No description provided for @storePkgSigDigest.
  ///
  /// In ja, this message translates to:
  /// **'sig.json の digest が配布物と違います(配布物が差し替わっています)'**
  String get storePkgSigDigest;

  /// No description provided for @storePkgSigRead.
  ///
  /// In ja, this message translates to:
  /// **'sig.json の publicKey / signature を読めません'**
  String get storePkgSigRead;

  /// No description provided for @storePkgSigLength.
  ///
  /// In ja, this message translates to:
  /// **'sig.json の鍵 / 署名の長さが違います'**
  String get storePkgSigLength;

  /// No description provided for @storePkgSigInvalid.
  ///
  /// In ja, this message translates to:
  /// **'開発者鍵の署名が合いません'**
  String get storePkgSigInvalid;

  /// No description provided for @storePkgFileMissing.
  ///
  /// In ja, this message translates to:
  /// **'{path}: 目次にあるのに中にありません'**
  String storePkgFileMissing(String path);

  /// No description provided for @storePkgTwice.
  ///
  /// In ja, this message translates to:
  /// **'bundle.json: {path} が 2 回出てきます'**
  String storePkgTwice(String path);

  /// No description provided for @storePkgKindTheme.
  ///
  /// In ja, this message translates to:
  /// **'着せ替え'**
  String get storePkgKindTheme;

  /// No description provided for @storePkgKindAssets.
  ///
  /// In ja, this message translates to:
  /// **'アセットパック'**
  String get storePkgKindAssets;

  /// No description provided for @swingActionFailed.
  ///
  /// In ja, this message translates to:
  /// **'できませんでした: {error}'**
  String swingActionFailed(String error);

  /// No description provided for @swingReplyHint.
  ///
  /// In ja, this message translates to:
  /// **'返信を送る…'**
  String get swingReplyHint;

  /// No description provided for @swingReplyToHint.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} に返信…'**
  String swingReplyToHint(String handle);

  /// No description provided for @swingReplyCount.
  ///
  /// In ja, this message translates to:
  /// **'返信 {count}'**
  String swingReplyCount(int count);

  /// No description provided for @swingQueueTooltip.
  ///
  /// In ja, this message translates to:
  /// **'キュー(長押しで絵を選ぶ)'**
  String get swingQueueTooltip;

  /// No description provided for @swingThreadBackReply.
  ///
  /// In ja, this message translates to:
  /// **'前の返信へ戻る'**
  String get swingThreadBackReply;

  /// No description provided for @swingThreadBackSwing.
  ///
  /// In ja, this message translates to:
  /// **'Swing の返信へ戻る'**
  String get swingThreadBackSwing;

  /// No description provided for @swingRepliesTo.
  ///
  /// In ja, this message translates to:
  /// **'@{handle} への返信 {count}'**
  String swingRepliesTo(String handle, int count);

  /// No description provided for @swingThreadClose.
  ///
  /// In ja, this message translates to:
  /// **'返信をしまう'**
  String get swingThreadClose;

  /// No description provided for @swingLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした: {error}'**
  String swingLoadFailed(String error);

  /// No description provided for @swingNoReplies.
  ///
  /// In ja, this message translates to:
  /// **'返信はまだありません。'**
  String get swingNoReplies;

  /// No description provided for @swingViewReplies.
  ///
  /// In ja, this message translates to:
  /// **'返信 {count, plural, other{{count} 件}}を見る'**
  String swingViewReplies(int count);

  /// No description provided for @swingAttachments.
  ///
  /// In ja, this message translates to:
  /// **'添付 {count, plural, other{{count} 件}}'**
  String swingAttachments(int count);

  /// No description provided for @swingPoll.
  ///
  /// In ja, this message translates to:
  /// **'投票'**
  String get swingPoll;

  /// No description provided for @swingReplyOf.
  ///
  /// In ja, this message translates to:
  /// **'{name} の返信'**
  String swingReplyOf(String name);

  /// No description provided for @swingImageSwing.
  ///
  /// In ja, this message translates to:
  /// **'画像の Swing'**
  String get swingImageSwing;

  /// No description provided for @swingVideoSwing.
  ///
  /// In ja, this message translates to:
  /// **'動画の Swing'**
  String get swingVideoSwing;

  /// No description provided for @swingPluginSwing.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの Swing'**
  String get swingPluginSwing;

  /// name は Swing を出した人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} の Swing'**
  String swingOf(String name);

  /// No description provided for @swingBarSemantics.
  ///
  /// In ja, this message translates to:
  /// **'Swing の返信とシークバー'**
  String get swingBarSemantics;

  /// No description provided for @swingReportIntro.
  ///
  /// In ja, this message translates to:
  /// **'{name} の Swing を通報します。RASQ の審査で確認します。'**
  String swingReportIntro(String name);

  /// No description provided for @swingReported.
  ///
  /// In ja, this message translates to:
  /// **'通報しました。審査で確認します'**
  String get swingReported;

  /// No description provided for @swingReportFailed.
  ///
  /// In ja, this message translates to:
  /// **'通報できませんでした: {error}'**
  String swingReportFailed(String error);

  /// No description provided for @swingDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'Swing を削除'**
  String get swingDeleteTitle;

  /// No description provided for @swingDeleteMessage.
  ///
  /// In ja, this message translates to:
  /// **'この Swing と、付いている返信を削除します。元に戻せません。'**
  String get swingDeleteMessage;

  /// No description provided for @swingDeleteConfirm.
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get swingDeleteConfirm;

  /// No description provided for @swingCancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get swingCancel;

  /// No description provided for @swingDeleteFailed.
  ///
  /// In ja, this message translates to:
  /// **'削除できませんでした: {error}'**
  String swingDeleteFailed(String error);

  /// No description provided for @swingDeleted.
  ///
  /// In ja, this message translates to:
  /// **'Swing を削除しました'**
  String get swingDeleted;

  /// No description provided for @swingViewerEmptyMine.
  ///
  /// In ja, this message translates to:
  /// **'出している Swing はありません'**
  String get swingViewerEmptyMine;

  /// No description provided for @swingViewerEmptyMineHint.
  ///
  /// In ja, this message translates to:
  /// **'＋ を上へスワイプすると Swing を作れます'**
  String get swingViewerEmptyMineHint;

  /// No description provided for @swingViewerEmpty.
  ///
  /// In ja, this message translates to:
  /// **'Swing はありません'**
  String get swingViewerEmpty;

  /// No description provided for @swingViewerEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'フォローしている人や、RASQ リストに入れてくれた人の Swing がここに流れます'**
  String get swingViewerEmptyHint;

  /// No description provided for @swingClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get swingClose;

  /// No description provided for @swingRemainingHours.
  ///
  /// In ja, this message translates to:
  /// **'あと {hours, plural, other{{hours} 時間}}'**
  String swingRemainingHours(int hours);

  /// No description provided for @swingRemainingMinutes.
  ///
  /// In ja, this message translates to:
  /// **'あと {minutes, plural, other{{minutes} 分}}'**
  String swingRemainingMinutes(int minutes);

  /// No description provided for @swingRemainingSoon.
  ///
  /// In ja, this message translates to:
  /// **'まもなく消えます'**
  String get swingRemainingSoon;

  /// remaining は残りの時間(あと 3 時間 など)、position は何枚目か(2 / 5)
  ///
  /// In ja, this message translates to:
  /// **'{remaining} ・ {position}'**
  String swingRemainingAndPosition(String remaining, String position);

  /// No description provided for @swingViewCount.
  ///
  /// In ja, this message translates to:
  /// **'見た人 {count, plural, other{{count} 人}}'**
  String swingViewCount(int count);

  /// No description provided for @swingReport.
  ///
  /// In ja, this message translates to:
  /// **'通報'**
  String get swingReport;

  /// No description provided for @swingMenu.
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get swingMenu;

  /// No description provided for @swingDelete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get swingDelete;

  /// No description provided for @swingSensitive.
  ///
  /// In ja, this message translates to:
  /// **'センシティブな内容'**
  String get swingSensitive;

  /// No description provided for @swingReveal.
  ///
  /// In ja, this message translates to:
  /// **'表示する'**
  String get swingReveal;

  /// No description provided for @swingPluginJoinNote.
  ///
  /// In ja, this message translates to:
  /// **'{name} さんのページにみんなで入ります。インストールせずに、この Swing を見ている間だけ動かします。'**
  String swingPluginJoinNote(String name);

  /// No description provided for @swingPluginJoin.
  ///
  /// In ja, this message translates to:
  /// **'参加する'**
  String get swingPluginJoin;

  /// No description provided for @swingPluginConsent.
  ///
  /// In ja, this message translates to:
  /// **'審査されていないプラグインです。通信はできない状態で、この Swing を見ている間だけ動かします。'**
  String get swingPluginConsent;

  /// 開発者モードの詳しい説明。network などは権限の名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'制限モード(network / storage.unsafe / interstitial・system の FOW / URL を開くなどは閉、GPU は可)。子プラグインを持たない 1 つだけ。'**
  String get swingPluginConsentDetail;

  /// No description provided for @swingPluginRun.
  ///
  /// In ja, this message translates to:
  /// **'動かす'**
  String get swingPluginRun;

  /// No description provided for @swingPluginNeedsInstall.
  ///
  /// In ja, this message translates to:
  /// **'{name} を入れると見られます'**
  String swingPluginNeedsInstall(String name);

  /// No description provided for @swingPluginNeedsInstallHint.
  ///
  /// In ja, this message translates to:
  /// **'プラグインの Swing です。ストアからインストールしてください'**
  String get swingPluginNeedsInstallHint;

  /// No description provided for @swingViewInStore.
  ///
  /// In ja, this message translates to:
  /// **'ストアで見る'**
  String get swingViewInStore;

  /// No description provided for @swingPluginOpenFailed.
  ///
  /// In ja, this message translates to:
  /// **'開けませんでした'**
  String get swingPluginOpenFailed;

  /// No description provided for @swingPluginTapToExpand.
  ///
  /// In ja, this message translates to:
  /// **'押すと全画面に戻ります'**
  String get swingPluginTapToExpand;

  /// No description provided for @swingPluginSwipeHint.
  ///
  /// In ja, this message translates to:
  /// **'左右・上下にスワイプで次の Swing へ'**
  String get swingPluginSwipeHint;

  /// No description provided for @swingPluginShrink.
  ///
  /// In ja, this message translates to:
  /// **'全画面から縮小'**
  String get swingPluginShrink;

  /// No description provided for @swingAd.
  ///
  /// In ja, this message translates to:
  /// **'広告'**
  String get swingAd;

  /// No description provided for @swingAdSwipeHint.
  ///
  /// In ja, this message translates to:
  /// **'スワイプで次の Swing へ'**
  String get swingAdSwipeHint;

  /// No description provided for @swingKindText.
  ///
  /// In ja, this message translates to:
  /// **'テキスト'**
  String get swingKindText;

  /// No description provided for @swingKindImage.
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get swingKindImage;

  /// No description provided for @swingKindVideo.
  ///
  /// In ja, this message translates to:
  /// **'動画'**
  String get swingKindVideo;

  /// No description provided for @swingKindPlugin.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get swingKindPlugin;

  /// 文の無い Swing のバナーの文。kind は種類の名前(画像 / 動画 など)
  ///
  /// In ja, this message translates to:
  /// **'{kind}の Swing'**
  String swingKindSwing(String kind);

  /// No description provided for @swingBannerNew.
  ///
  /// In ja, this message translates to:
  /// **'新着 {count}'**
  String swingBannerNew(int count);

  /// No description provided for @swingBannerTotal.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 件}}'**
  String swingBannerTotal(int count);

  /// No description provided for @swingComposerPluginShared.
  ///
  /// In ja, this message translates to:
  /// **'みんなで使う: 見た人は、あなたが作る同じページに入ります'**
  String get swingComposerPluginShared;

  /// No description provided for @swingComposerPluginFullscreen.
  ///
  /// In ja, this message translates to:
  /// **'見る人の端末で全画面で動きます'**
  String get swingComposerPluginFullscreen;

  /// No description provided for @swingComposerPluginPage.
  ///
  /// In ja, this message translates to:
  /// **'見る人の端末でページとして動きます'**
  String get swingComposerPluginPage;

  /// 編集画面のバーのボタン
  ///
  /// In ja, this message translates to:
  /// **'{hours, plural, other{{hours} 時間で消える}}'**
  String swingTtlLabel(int hours);

  /// No description provided for @swingTtl.
  ///
  /// In ja, this message translates to:
  /// **'消えるまで'**
  String get swingTtl;

  /// No description provided for @swingTtlHours.
  ///
  /// In ja, this message translates to:
  /// **'{hours, plural, other{{hours} 時間}}'**
  String swingTtlHours(int hours);

  /// No description provided for @swingBackgroundImage.
  ///
  /// In ja, this message translates to:
  /// **'画像を背景にする'**
  String get swingBackgroundImage;

  /// No description provided for @swingBackgroundVideo.
  ///
  /// In ja, this message translates to:
  /// **'動画を背景にする'**
  String get swingBackgroundVideo;

  /// No description provided for @swingPickVideoFile.
  ///
  /// In ja, this message translates to:
  /// **'動画のファイルを選んでください'**
  String get swingPickVideoFile;

  /// No description provided for @swingPickImageFile.
  ///
  /// In ja, this message translates to:
  /// **'画像のファイルを選んでください'**
  String get swingPickImageFile;

  /// No description provided for @swingChangeBackground.
  ///
  /// In ja, this message translates to:
  /// **'背景を変える'**
  String get swingChangeBackground;

  /// No description provided for @swingAudience.
  ///
  /// In ja, this message translates to:
  /// **'届け先'**
  String get swingAudience;

  /// No description provided for @swingLoadFailedShort.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした'**
  String get swingLoadFailedShort;

  /// No description provided for @swingSent.
  ///
  /// In ja, this message translates to:
  /// **'Swing を出しました({hours, plural, other{{hours} 時間で消えます}})'**
  String swingSent(int hours);

  /// No description provided for @swingErrorLimit.
  ///
  /// In ja, this message translates to:
  /// **'同時に出しておける Swing は 20 個までです'**
  String get swingErrorLimit;

  /// No description provided for @swingSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'出せませんでした: {error}'**
  String swingSendFailed(String error);

  /// No description provided for @swingComposerTitle.
  ///
  /// In ja, this message translates to:
  /// **'Swing を作る'**
  String get swingComposerTitle;

  /// No description provided for @swingNext.
  ///
  /// In ja, this message translates to:
  /// **'次へ'**
  String get swingNext;

  /// No description provided for @swingSend.
  ///
  /// In ja, this message translates to:
  /// **'出す'**
  String get swingSend;

  /// No description provided for @swingNeedsAccount.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントが要ります'**
  String get swingNeedsAccount;

  /// No description provided for @swingNeedsAccountHint.
  ///
  /// In ja, this message translates to:
  /// **'Swing は RASQ アカウントから出します。サイドバーからログインしてください'**
  String get swingNeedsAccountHint;

  /// No description provided for @swingUnreviewed.
  ///
  /// In ja, this message translates to:
  /// **'{name}(未審査)'**
  String swingUnreviewed(String name);

  /// No description provided for @swingTtlRemaining.
  ///
  /// In ja, this message translates to:
  /// **'{hours, plural, other{{hours} 時間で消えます}}'**
  String swingTtlRemaining(int hours);

  /// No description provided for @swingRepick.
  ///
  /// In ja, this message translates to:
  /// **'選び直す'**
  String get swingRepick;

  /// No description provided for @swingReedit.
  ///
  /// In ja, this message translates to:
  /// **'編集し直す'**
  String get swingReedit;

  /// No description provided for @swingCwTooLong.
  ///
  /// In ja, this message translates to:
  /// **'CW は {max} 文字までです'**
  String swingCwTooLong(int max);

  /// No description provided for @swingCwHint.
  ///
  /// In ja, this message translates to:
  /// **'CW の文'**
  String get swingCwHint;

  /// No description provided for @swingCwOff.
  ///
  /// In ja, this message translates to:
  /// **'CW をはずす'**
  String get swingCwOff;

  /// No description provided for @swingCwOn.
  ///
  /// In ja, this message translates to:
  /// **'CW を付ける(センシティブな内容)'**
  String get swingCwOn;

  /// No description provided for @swingPluginSection.
  ///
  /// In ja, this message translates to:
  /// **'配るプラグイン'**
  String get swingPluginSection;

  /// No description provided for @swingPluginNone.
  ///
  /// In ja, this message translates to:
  /// **'Swing で配れるカスタムプラグインが入っていません。ストアで入れるか、下の「ファイルから」で自分のプラグインを配れます。'**
  String get swingPluginNone;

  /// 開発者モードの詳しい説明。solo / shared はページの使い方の名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'ページ型(カスタムプラグイン)のうち、ほかのプラグインと親子関係の無いもの(solo / shared どちらも)。'**
  String get swingPluginNoneDetail;

  /// No description provided for @swingFromFile.
  ///
  /// In ja, this message translates to:
  /// **'ファイルから(未審査)'**
  String get swingFromFile;

  /// No description provided for @swingFromFileSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'自分で作った .rspkg / .rasqpkg / .wasm を配ります'**
  String get swingFromFileSubtitle;

  /// No description provided for @swingFromFileDetail.
  ///
  /// In ja, this message translates to:
  /// **'審査していないプラグインは、見る人の端末で通信できない状態で動きます(GPU は使えます)。ほかのプラグインを土台にする子プラグインは配れません。'**
  String get swingFromFileDetail;

  /// No description provided for @swingAudienceEmpty.
  ///
  /// In ja, this message translates to:
  /// **'届け先を 1 つ以上選んでください'**
  String get swingAudienceEmpty;

  /// No description provided for @swingAudienceFollowers.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get swingAudienceFollowers;

  /// No description provided for @swingAudienceFollowersSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントをフォローしている人'**
  String get swingAudienceFollowersSubtitle;

  /// No description provided for @swingAudienceList.
  ///
  /// In ja, this message translates to:
  /// **'RASQ リスト'**
  String get swingAudienceList;

  /// No description provided for @swingAudienceNoLists.
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストを作ると、リストに入れた人にも届けられます'**
  String get swingAudienceNoLists;

  /// status は HTTP の状態の番号
  ///
  /// In ja, this message translates to:
  /// **'プラグインを取れませんでした(HTTP {status})'**
  String swingPackageFetchFailed(int status);

  /// No description provided for @swingNotLoggedIn.
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインしていません'**
  String get swingNotLoggedIn;

  /// No description provided for @swingUnreadable.
  ///
  /// In ja, this message translates to:
  /// **'Swing を読めませんでした'**
  String get swingUnreadable;

  /// No description provided for @trendTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンド'**
  String get trendTitle;

  /// No description provided for @trendTabNotes.
  ///
  /// In ja, this message translates to:
  /// **'ノート'**
  String get trendTabNotes;

  /// No description provided for @trendTabFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get trendTabFollowing;

  /// No description provided for @trendTabUsers.
  ///
  /// In ja, this message translates to:
  /// **'ユーザー'**
  String get trendTabUsers;

  /// No description provided for @trendBackToHome.
  ///
  /// In ja, this message translates to:
  /// **'トレンドホームへ戻る'**
  String get trendBackToHome;

  /// アカウントの選択で、このトレンドを出したアカウントに付ける印の説明
  ///
  /// In ja, this message translates to:
  /// **'トレンドに出したアカウント'**
  String get trendSourceAccountMark;

  /// No description provided for @trendSettingsTooltip.
  ///
  /// In ja, this message translates to:
  /// **'トレンド設定'**
  String get trendSettingsTooltip;

  /// No description provided for @trendCustomizeTooltip.
  ///
  /// In ja, this message translates to:
  /// **'トレンド TL をカスタマイズ'**
  String get trendCustomizeTooltip;

  /// No description provided for @trendReload.
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get trendReload;

  /// No description provided for @trendEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'なんにもないようです'**
  String get trendEmptyTitle;

  /// No description provided for @trendEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'ワードやフィルタを変えると見つかるかもしれません'**
  String get trendEmptyHint;

  /// No description provided for @trendFollowingEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中の投稿はありません'**
  String get trendFollowingEmptyTitle;

  /// No description provided for @trendFollowingEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'このワードについてフォロイーはまだ投稿していません'**
  String get trendFollowingEmptyHint;

  /// No description provided for @trendUsersBlocked.
  ///
  /// In ja, this message translates to:
  /// **'保護者がユーザーの検索を止めています'**
  String get trendUsersBlocked;

  /// No description provided for @trendUsersEmpty.
  ///
  /// In ja, this message translates to:
  /// **'ユーザーはいません'**
  String get trendUsersEmpty;

  /// トレンドのユーザーの一覧の行の補足。count はリアクションの合計
  ///
  /// In ja, this message translates to:
  /// **'リアクション {count}'**
  String trendUserReactions(int count);

  /// No description provided for @trendMenuOpenAs.
  ///
  /// In ja, this message translates to:
  /// **'別のアカウントで開く'**
  String get trendMenuOpenAs;

  /// No description provided for @trendMenuReport.
  ///
  /// In ja, this message translates to:
  /// **'通報'**
  String get trendMenuReport;

  /// account は SNS アカウント(@名前@サーバー)
  ///
  /// In ja, this message translates to:
  /// **'{account}(トレンドに出したアカウント)'**
  String trendMenuAccountSourced(String account);

  /// No description provided for @trendReportTitle.
  ///
  /// In ja, this message translates to:
  /// **'通報'**
  String get trendReportTitle;

  /// No description provided for @trendReportMessage.
  ///
  /// In ja, this message translates to:
  /// **'トレンド「{tag}」を通報します。RASQ の審査で確認します。通報したトレンドは、トレンドの一覧に出なくなります。'**
  String trendReportMessage(String tag);

  /// server はトレンドを出したサーバー
  ///
  /// In ja, this message translates to:
  /// **'トレンド「{tag}」({server})を通報します。RASQ の審査で確認します。通報したトレンドは、トレンドの一覧に出なくなります。'**
  String trendReportMessageWithServer(String tag, String server);

  /// No description provided for @trendReportNoteHint.
  ///
  /// In ja, this message translates to:
  /// **'補足(任意)'**
  String get trendReportNoteHint;

  /// No description provided for @trendReportSend.
  ///
  /// In ja, this message translates to:
  /// **'通報する'**
  String get trendReportSend;

  /// No description provided for @trendReportSent.
  ///
  /// In ja, this message translates to:
  /// **'通報しました。RASQ の審査で確認します'**
  String get trendReportSent;

  /// No description provided for @trendReportStored.
  ///
  /// In ja, this message translates to:
  /// **'この端末に控えました。RASQ アカウントに繋がったら送ります'**
  String get trendReportStored;

  /// No description provided for @trendReportFailed.
  ///
  /// In ja, this message translates to:
  /// **'送れなかったので、この端末に控えました(あとで送り直します)'**
  String get trendReportFailed;

  /// No description provided for @trendReportUnhide.
  ///
  /// In ja, this message translates to:
  /// **'表示に戻す'**
  String get trendReportUnhide;

  /// ノードの見出しで、プラグインが 1 つに決まらないときの名前
  ///
  /// In ja, this message translates to:
  /// **'トレンドプラグイン'**
  String get trendPluginFallbackName;

  /// No description provided for @trendPluginLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした'**
  String get trendPluginLoadFailed;

  /// No description provided for @trendPluginNoWords.
  ///
  /// In ja, this message translates to:
  /// **'候補のワードはまだありません'**
  String get trendPluginNoWords;

  /// Today のノードで、候補のワードを 1 つずつかぎかっこで囲む
  ///
  /// In ja, this message translates to:
  /// **'「{word}」'**
  String trendPluginWordQuoted(String word);

  /// words は trendPluginWordQuoted を並べたもの
  ///
  /// In ja, this message translates to:
  /// **'{words}の投稿はまだありません'**
  String trendPluginTodayEmpty(String words);

  /// words は trendPluginWordQuoted を並べたもの
  ///
  /// In ja, this message translates to:
  /// **'{words}の投稿'**
  String trendPluginTodayHeading(String words);

  /// 刺激性の 8 つの感情の名前
  ///
  /// In ja, this message translates to:
  /// **'喜び'**
  String get trendEmotionJoy;

  /// No description provided for @trendEmotionTrust.
  ///
  /// In ja, this message translates to:
  /// **'信頼'**
  String get trendEmotionTrust;

  /// No description provided for @trendEmotionFear.
  ///
  /// In ja, this message translates to:
  /// **'恐れ'**
  String get trendEmotionFear;

  /// No description provided for @trendEmotionSurprise.
  ///
  /// In ja, this message translates to:
  /// **'驚き'**
  String get trendEmotionSurprise;

  /// No description provided for @trendEmotionSadness.
  ///
  /// In ja, this message translates to:
  /// **'悲しみ'**
  String get trendEmotionSadness;

  /// No description provided for @trendEmotionDisgust.
  ///
  /// In ja, this message translates to:
  /// **'嫌悪'**
  String get trendEmotionDisgust;

  /// No description provided for @trendEmotionAnger.
  ///
  /// In ja, this message translates to:
  /// **'怒り'**
  String get trendEmotionAnger;

  /// No description provided for @trendEmotionAnticipation.
  ///
  /// In ja, this message translates to:
  /// **'期待'**
  String get trendEmotionAnticipation;

  /// No description provided for @trendExamplesNoCandidates.
  ///
  /// In ja, this message translates to:
  /// **'候補がありません'**
  String get trendExamplesNoCandidates;

  /// No description provided for @trendExamplesAllow.
  ///
  /// In ja, this message translates to:
  /// **'好き'**
  String get trendExamplesAllow;

  /// No description provided for @trendExamplesDeny.
  ///
  /// In ja, this message translates to:
  /// **'好きではない'**
  String get trendExamplesDeny;

  /// No description provided for @trendExamplesDecide.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get trendExamplesDecide;

  /// source は出どころの名前(最近のアクション / プラグインなど)
  ///
  /// In ja, this message translates to:
  /// **'{source}を読み込めませんでした: {error}'**
  String trendExamplesLoadFailed(String source, String error);

  /// No description provided for @trendExamplesAllSeen.
  ///
  /// In ja, this message translates to:
  /// **'全部見ました'**
  String get trendExamplesAllSeen;

  /// allowLabel / denyLabel はボタンの名前(好き / 好きではない など)、allow / deny はその数
  ///
  /// In ja, this message translates to:
  /// **'{allowLabel} {allow} / {denyLabel} {deny}。決定で保存します'**
  String trendExamplesAllSeenHint(
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
  );

  /// No description provided for @trendExamplesIntro.
  ///
  /// In ja, this message translates to:
  /// **'中身を見て、下の「{allowLabel}」/「{denyLabel}」(右 / 左スワイプでも)で例にします。新しいものは、例との近さで分けます。'**
  String trendExamplesIntro(String allowLabel, String denyLabel);

  /// intro は説明の文(trendExamplesIntro など)
  ///
  /// In ja, this message translates to:
  /// **'{intro}({allowLabel} {allow} / {denyLabel} {deny}・残り {remaining, plural, other{{remaining} 件}})'**
  String trendExamplesSummary(
    String intro,
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
    int remaining,
  );

  /// No description provided for @trendExamplesSearch.
  ///
  /// In ja, this message translates to:
  /// **'探す'**
  String get trendExamplesSearch;

  /// No description provided for @trendExamplesSkip.
  ///
  /// In ja, this message translates to:
  /// **'とばす'**
  String get trendExamplesSkip;

  /// 話題のカードの右上の、ほかの投稿の数
  ///
  /// In ja, this message translates to:
  /// **'+{count, plural, other{{count} 件}}'**
  String trendExamplesMorePosts(int count);

  /// No description provided for @trendExamplesPostsUnreadable.
  ///
  /// In ja, this message translates to:
  /// **'投稿を読めませんでした(名前と説明で比べます)'**
  String get trendExamplesPostsUnreadable;

  /// No description provided for @trendExamplesOthers.
  ///
  /// In ja, this message translates to:
  /// **'ほか {count, plural, other{{count} 件}}'**
  String trendExamplesOthers(int count);

  /// No description provided for @trendExamplesSourceActions.
  ///
  /// In ja, this message translates to:
  /// **'最近のアクション'**
  String get trendExamplesSourceActions;

  /// No description provided for @trendExamplesSourceActionsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'最近のアクションがありません'**
  String get trendExamplesSourceActionsEmpty;

  /// No description provided for @trendExamplesSourceActionsEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'リアクションやブックマークをすると、ここから選べます'**
  String get trendExamplesSourceActionsEmptyHint;

  /// No description provided for @trendExamplesSourcePlugins.
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get trendExamplesSourcePlugins;

  /// No description provided for @trendExamplesSourcePluginsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'入れているプラグインはありません'**
  String get trendExamplesSourcePluginsEmpty;

  /// No description provided for @trendExamplesSourceClips.
  ///
  /// In ja, this message translates to:
  /// **'クリップ'**
  String get trendExamplesSourceClips;

  /// No description provided for @trendExamplesSourceClipsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'クリップはありません'**
  String get trendExamplesSourceClipsEmpty;

  /// No description provided for @trendExamplesSourceLists.
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get trendExamplesSourceLists;

  /// No description provided for @trendExamplesSourceListsEmpty.
  ///
  /// In ja, this message translates to:
  /// **'リストはありません'**
  String get trendExamplesSourceListsEmpty;

  /// No description provided for @trendExamplesSourceStore.
  ///
  /// In ja, this message translates to:
  /// **'ストア'**
  String get trendExamplesSourceStore;

  /// No description provided for @trendExamplesSourceStoreHint.
  ///
  /// In ja, this message translates to:
  /// **'ストアを探す(空 = 一覧)'**
  String get trendExamplesSourceStoreHint;

  /// No description provided for @trendExamplesSourceStoreEmpty.
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした'**
  String get trendExamplesSourceStoreEmpty;

  /// 例の種類の札
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get trendExamplesKindPlugin;

  /// No description provided for @trendExamplesKindClip.
  ///
  /// In ja, this message translates to:
  /// **'クリップ'**
  String get trendExamplesKindClip;

  /// No description provided for @trendExamplesKindList.
  ///
  /// In ja, this message translates to:
  /// **'リスト'**
  String get trendExamplesKindList;

  /// No description provided for @trendExamplesKindPost.
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get trendExamplesKindPost;

  /// No description provided for @trendExamplesKindText.
  ///
  /// In ja, this message translates to:
  /// **'ことば'**
  String get trendExamplesKindText;

  /// No description provided for @trendProfileSheetTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドプロファイル設定'**
  String get trendProfileSheetTitle;

  /// No description provided for @trendProfileClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get trendProfileClose;

  /// No description provided for @trendProfileDecide.
  ///
  /// In ja, this message translates to:
  /// **'決定'**
  String get trendProfileDecide;

  /// No description provided for @trendProfileGenres.
  ///
  /// In ja, this message translates to:
  /// **'好きなジャンル/方向性'**
  String get trendProfileGenres;

  /// No description provided for @trendProfileGenresSnsDefault.
  ///
  /// In ja, this message translates to:
  /// **'好きなジャンル/方向性(SNS 側の設定に任せる)'**
  String get trendProfileGenresSnsDefault;

  /// No description provided for @trendProfileGenresAuto.
  ///
  /// In ja, this message translates to:
  /// **'好きなジャンル/方向性(アクションから自動抽出)'**
  String get trendProfileGenresAuto;

  /// No description provided for @trendProfileAddGenrePill.
  ///
  /// In ja, this message translates to:
  /// **'+ ジャンルを追加'**
  String get trendProfileAddGenrePill;

  /// No description provided for @trendProfileEdit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get trendProfileEdit;

  /// No description provided for @trendProfileTendencyTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドの指向性/刺激性'**
  String get trendProfileTendencyTitle;

  /// directivity は trendProfileDirNarrow などの語、stimulus は trendProfileStimNone か trendProfileStimCapped
  ///
  /// In ja, this message translates to:
  /// **'指向性 {directivity} ・ 刺激性 {stimulus}'**
  String trendProfileTendencySummary(String directivity, String stimulus);

  /// No description provided for @trendProfilePluginsTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドプラグインの設定'**
  String get trendProfilePluginsTitle;

  /// No description provided for @trendProfilePluginsSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'TL のノード / 検索の候補'**
  String get trendProfilePluginsSubtitle;

  /// 開発者モードの詳しい説明。trend.suggest はスロットの id(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'trend.suggest のプラグイン。TL のカスタマイズのノード(トレンドを取得 / Today / カスタム)と検索の候補で出します'**
  String get trendProfilePluginsDetail;

  /// No description provided for @trendProfileCacheNetworkTitle.
  ///
  /// In ja, this message translates to:
  /// **'キャッシュネットワークの設定'**
  String get trendProfileCacheNetworkTitle;

  /// No description provided for @trendProfileComingSoon.
  ///
  /// In ja, this message translates to:
  /// **'準備中'**
  String get trendProfileComingSoon;

  /// No description provided for @trendProfileAlgorithmTitle.
  ///
  /// In ja, this message translates to:
  /// **'アルゴリズム(ノード)を編集'**
  String get trendProfileAlgorithmTitle;

  /// No description provided for @trendProfileAlgorithmSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドの集め方・並べ方を編集します'**
  String get trendProfileAlgorithmSubtitle;

  /// 開発者モードの詳しい説明。ml.tendency はノードの id(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'トレンドの取得・並べ替えの鎖(ml.tendency ノードでこのプロファイルを使えます)'**
  String get trendProfileAlgorithmDetail;

  /// No description provided for @trendProfileSharedCaption.
  ///
  /// In ja, this message translates to:
  /// **'この設定は、おすすめ / トレンド / 関連 TL で共通です。'**
  String get trendProfileSharedCaption;

  /// 開発者モードの詳しい説明。storage.safe / trend.profile は保存先の名前(訳さない)
  ///
  /// In ja, this message translates to:
  /// **'このプロファイルは storage.safe(trend.profile)に保存され、おすすめ / トレンド / 関連 TL の既定と、ノードエディタの「指向性/刺激性」ノードが共通で読みます。'**
  String get trendProfileSharedCaptionDetail;

  /// No description provided for @trendProfileDirNarrow.
  ///
  /// In ja, this message translates to:
  /// **'狭い'**
  String get trendProfileDirNarrow;

  /// No description provided for @trendProfileDirWide.
  ///
  /// In ja, this message translates to:
  /// **'広い'**
  String get trendProfileDirWide;

  /// No description provided for @trendProfileDirNormal.
  ///
  /// In ja, this message translates to:
  /// **'ふつう'**
  String get trendProfileDirNormal;

  /// No description provided for @trendProfileStimNone.
  ///
  /// In ja, this message translates to:
  /// **'制限なし'**
  String get trendProfileStimNone;

  /// emotions は感情の名前(最大 3 つ)を trendProfileListSeparator でつないだもの
  ///
  /// In ja, this message translates to:
  /// **'{emotions}を抑える'**
  String trendProfileStimCapped(String emotions);

  /// 感情の名前を並べるときの区切り
  ///
  /// In ja, this message translates to:
  /// **'・'**
  String get trendProfileListSeparator;

  /// No description provided for @trendProfileDirectivityTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドの指向性'**
  String get trendProfileDirectivityTitle;

  /// No description provided for @trendProfileDirectivitySubtitle.
  ///
  /// In ja, this message translates to:
  /// **'狭いほど、好きなジャンルから外れた投稿を出しません。'**
  String get trendProfileDirectivitySubtitle;

  /// No description provided for @trendProfileDirectivityDetail.
  ///
  /// In ja, this message translates to:
  /// **'好きなジャンル/方向性への近さのしきい値(狭い ⇄ 広い)。狭いほど外れた投稿を落とします。'**
  String get trendProfileDirectivityDetail;

  /// No description provided for @trendProfileShareTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定を共有'**
  String get trendProfileShareTitle;

  /// No description provided for @trendProfileShareSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'おすすめ / トレンド / 関連 TL にこの設定を使います'**
  String get trendProfileShareSubtitle;

  /// No description provided for @trendProfileShareDetail.
  ///
  /// In ja, this message translates to:
  /// **'オフにすると TL の既定適用を止めます(ノードで明示した分は効きます)'**
  String get trendProfileShareDetail;

  /// No description provided for @trendProfileStimulusTitle.
  ///
  /// In ja, this message translates to:
  /// **'トレンドの刺激性'**
  String get trendProfileStimulusTitle;

  /// No description provided for @trendProfileStimulusCaption.
  ///
  /// In ja, this message translates to:
  /// **'各感情の上限。中心に寄せるほど抑えます'**
  String get trendProfileStimulusCaption;

  /// No description provided for @trendProfileStimulusReset.
  ///
  /// In ja, this message translates to:
  /// **'刺激性をリセット'**
  String get trendProfileStimulusReset;

  /// No description provided for @trendProfileEchoChamberWarning.
  ///
  /// In ja, this message translates to:
  /// **'トレンドの指向性/刺激性を強くすると、エコーチェンバーの影響を受けやすくなる危険性があります。'**
  String get trendProfileEchoChamberWarning;

  /// No description provided for @trendProfileStimulusEstimate.
  ///
  /// In ja, this message translates to:
  /// **'刺激性は、いまは言葉の傾向から推定しています。'**
  String get trendProfileStimulusEstimate;

  /// 開発者モードの詳しい説明
  ///
  /// In ja, this message translates to:
  /// **'刺激性は語彙ルールで推定しています。'**
  String get trendProfileStimulusEstimateDetail;

  /// No description provided for @trendProfileTendencySaved.
  ///
  /// In ja, this message translates to:
  /// **'トレンドの指向性/刺激性を保存しました'**
  String get trendProfileTendencySaved;

  /// No description provided for @trendProfileSnsDefaultTitle.
  ///
  /// In ja, this message translates to:
  /// **'SNS 側の設定に任せる'**
  String get trendProfileSnsDefaultTitle;

  /// No description provided for @trendProfileSnsDefaultSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'オンの間は端末側で絞りません'**
  String get trendProfileSnsDefaultSubtitle;

  /// No description provided for @trendProfileAutoGenreTitle.
  ///
  /// In ja, this message translates to:
  /// **'あなたのアクションから自動抽出'**
  String get trendProfileAutoGenreTitle;

  /// No description provided for @trendProfileAutoGenreSubtitle.
  ///
  /// In ja, this message translates to:
  /// **'リアクションした投稿の特徴語を好きなジャンルに足します'**
  String get trendProfileAutoGenreSubtitle;

  /// No description provided for @trendProfilePickFromActions.
  ///
  /// In ja, this message translates to:
  /// **'最近のアクションから好きなものを選択'**
  String get trendProfilePickFromActions;

  /// No description provided for @trendProfileGenresTapToRemove.
  ///
  /// In ja, this message translates to:
  /// **'好きなジャンル/方向性(タップで外す)'**
  String get trendProfileGenresTapToRemove;

  /// No description provided for @trendProfileNoneYet.
  ///
  /// In ja, this message translates to:
  /// **'まだありません'**
  String get trendProfileNoneYet;

  /// No description provided for @trendProfileAddGenreHint.
  ///
  /// In ja, this message translates to:
  /// **'ジャンル/キーワードを追加'**
  String get trendProfileAddGenreHint;

  /// No description provided for @trendProfileAddGenre.
  ///
  /// In ja, this message translates to:
  /// **'ジャンルを追加'**
  String get trendProfileAddGenre;

  /// allow / deny は好きな例 / 好きではない例の数
  ///
  /// In ja, this message translates to:
  /// **'例(好き {allow} / 好きではない {deny}。タップで外す)'**
  String trendProfileExamplesLabel(int allow, int deny);

  /// 好きな例のチップ。label は例の短い名前
  ///
  /// In ja, this message translates to:
  /// **'好き: {label}'**
  String trendProfileExampleAllow(String label);

  /// 好きではない例のチップ。label は例の短い名前
  ///
  /// In ja, this message translates to:
  /// **'好きではない: {label}'**
  String trendProfileExampleDeny(String label);

  /// No description provided for @trendProfileDislikedTapToRemove.
  ///
  /// In ja, this message translates to:
  /// **'好きではない(タップで外す)'**
  String get trendProfileDislikedTapToRemove;

  /// No description provided for @trendProfileGenresSaved.
  ///
  /// In ja, this message translates to:
  /// **'好きなジャンル/方向性を保存しました'**
  String get trendProfileGenresSaved;

  /// No description provided for @trendProfilePickTitle.
  ///
  /// In ja, this message translates to:
  /// **'アクションからジャンルを選択'**
  String get trendProfilePickTitle;

  /// No description provided for @trendProfilePickIntro.
  ///
  /// In ja, this message translates to:
  /// **'最近のアクションを話題ごとに出しています。カードを選んで「好き」/「好きではない」へ(右/左スワイプでも)。'**
  String get trendProfilePickIntro;

  /// 開発者モードの詳しい説明。perPage は 1 ページのカードの数
  ///
  /// In ja, this message translates to:
  /// **'最近のアクションを類似した話題でまとめ、話題性の強いものから {perPage, plural, other{{perPage} 件}}ずつ出しています(上のチップでプラグイン / クリップ / リストからも)。カードをタップして選び、候補のジャンルを選んで下の「好き」/「好きではない」(右/左スワイプでも)。'**
  String trendProfilePickIntroDetail(int perPage);

  /// ユーザーページのタブの並べ替え・絞り込みのパネル(選んでいるタブをもう一度押すと開く)の見出し。tab はタブの名前(ノート / 返信 など)
  ///
  /// In ja, this message translates to:
  /// **'{tab}の表示'**
  String userPageViewTitle(String tab);

  /// No description provided for @userPageViewClose.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get userPageViewClose;

  /// パネルの検索欄の薄い字。読み込んだ投稿の本文を探す。tab はタブの名前
  ///
  /// In ja, this message translates to:
  /// **'この人の{tab}から探す'**
  String userPageViewSearchHint(String tab);

  /// No description provided for @userPageViewSortLabel.
  ///
  /// In ja, this message translates to:
  /// **'並べ替え'**
  String get userPageViewSortLabel;

  /// No description provided for @userPageViewSortNewest.
  ///
  /// In ja, this message translates to:
  /// **'新しい順'**
  String get userPageViewSortNewest;

  /// No description provided for @userPageViewSortOldest.
  ///
  /// In ja, this message translates to:
  /// **'古い順'**
  String get userPageViewSortOldest;

  /// No description provided for @userPageViewSortReactions.
  ///
  /// In ja, this message translates to:
  /// **'リアクション数'**
  String get userPageViewSortReactions;

  /// No description provided for @userPageViewSortTendency.
  ///
  /// In ja, this message translates to:
  /// **'傾向に合う順'**
  String get userPageViewSortTendency;

  /// No description provided for @userPageViewShowLabel.
  ///
  /// In ja, this message translates to:
  /// **'表示'**
  String get userPageViewShowLabel;

  /// No description provided for @userPageViewShowPinned.
  ///
  /// In ja, this message translates to:
  /// **'ピン留め'**
  String get userPageViewShowPinned;

  /// No description provided for @userPageViewShowRenotes.
  ///
  /// In ja, this message translates to:
  /// **'リノート'**
  String get userPageViewShowRenotes;

  /// No description provided for @userPageViewShowQuotes.
  ///
  /// In ja, this message translates to:
  /// **'引用ノート'**
  String get userPageViewShowQuotes;

  /// No description provided for @userPageViewShowDigest.
  ///
  /// In ja, this message translates to:
  /// **'ダイジェスト'**
  String get userPageViewShowDigest;

  /// パネルの指向性 / 刺激性の欄の見出し(トレンドの指向性 / 刺激性と同じ部品)
  ///
  /// In ja, this message translates to:
  /// **'指向性 / 刺激性'**
  String get userPageViewTendencyLabel;

  /// 好きなジャンルへの近さで絞るスライダーの見出し(トレンドの指向性と同じ考え方)
  ///
  /// In ja, this message translates to:
  /// **'指向性'**
  String get userPageViewDirectivityTitle;

  /// トレンドの設定で好きなジャンル / 好きな例を決めていないとき、指向性のスライダーの説明の代わりに出す注意
  ///
  /// In ja, this message translates to:
  /// **'好きなジャンルを決めると効きます'**
  String get userPageViewDirectivityNoGenres;

  /// 8 つの感情の上限を決めるレーダーの見出し。上限を超えたぶんの合計が大きい投稿を隠す(トレンドと同じ)
  ///
  /// In ja, this message translates to:
  /// **'刺激性'**
  String get userPageViewStimulusTitle;

  /// No description provided for @userPageViewReset.
  ///
  /// In ja, this message translates to:
  /// **'リセット'**
  String get userPageViewReset;

  /// パネルの下の、読み込んだ投稿のうち表示している数
  ///
  /// In ja, this message translates to:
  /// **'{total, plural, other{{total} 件中 {shown} 件}}'**
  String userPageViewCount(int shown, int total);

  /// No description provided for @userPageViewEmptyTitle.
  ///
  /// In ja, this message translates to:
  /// **'条件に合う投稿はありません'**
  String get userPageViewEmptyTitle;

  /// No description provided for @userPageViewEmptyHint.
  ///
  /// In ja, this message translates to:
  /// **'タブをもう一度押して、表示の設定を変えるかリセットしてください'**
  String get userPageViewEmptyHint;

  /// プロフィールのアイコン / バナーの全画面表示の左上の戻るボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get usersImageViewerBack;

  /// フォロー申請の画面のタブ: 関連の強い順
  ///
  /// In ja, this message translates to:
  /// **'関連性'**
  String get usersFollowRequestsTabRelevance;

  /// フォロー申請の画面のタブ: 自分がフォローしている人からの申請
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get usersFollowRequestsTabFollowing;

  /// フォロー申請の画面のタブ: それ以外
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get usersFollowRequestsTabOther;

  /// フォロー申請の画面の見出し
  ///
  /// In ja, this message translates to:
  /// **'フォロー申請'**
  String get usersFollowRequestsTitle;

  /// 読み込みに失敗したときのやり直しのボタン
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get usersReload;

  /// フォロー申請が無いとき
  ///
  /// In ja, this message translates to:
  /// **'フォロー申請はありません'**
  String get usersFollowRequestsEmpty;

  /// フォロー申請の画面の、最初以外のタブが空のとき
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get usersFollowRequestsEmptyOther;

  /// フォロー申請の行のボタン: 申請を受け入れる
  ///
  /// In ja, this message translates to:
  /// **'許可'**
  String get usersFollowRequestAccept;

  /// フォロー申請の行のボタン: 申請を断る
  ///
  /// In ja, this message translates to:
  /// **'拒否'**
  String get usersFollowRequestReject;

  /// フォロー / フォロワーの画面のタブ: この人がフォローしている人
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get usersFollowsTabFollowing;

  /// フォロー / フォロワーの画面のタブ: この人をフォローしている人
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get usersFollowsTabFollowers;

  /// フォロー / フォロワーの画面の見出し(ユーザーの名前が分からないとき)
  ///
  /// In ja, this message translates to:
  /// **'フォロー/フォロワー'**
  String get usersFollowsTitle;

  /// フォロワーの一覧が空のとき
  ///
  /// In ja, this message translates to:
  /// **'フォロワーはいません'**
  String get usersFollowersEmpty;

  /// フォロー中の一覧が空のとき
  ///
  /// In ja, this message translates to:
  /// **'フォロー中のユーザーはいません'**
  String get usersFollowingEmpty;

  /// ユーザーページのタブ: 投稿(返信・引用以外)。Misskey の言い方
  ///
  /// In ja, this message translates to:
  /// **'ノート'**
  String get usersPageTabNotes;

  /// ユーザーページのタブ: 返信
  ///
  /// In ja, this message translates to:
  /// **'返信'**
  String get usersPageTabReplies;

  /// ユーザーページのタブ: 引用した投稿
  ///
  /// In ja, this message translates to:
  /// **'引用'**
  String get usersPageTabQuotes;

  /// ユーザーページのタブ: 画像・動画の付いた投稿
  ///
  /// In ja, this message translates to:
  /// **'メディア'**
  String get usersPageTabMedia;

  /// ユーザーページのタブ: 公開クリップと Play(Misskey の機能の名前)
  ///
  /// In ja, this message translates to:
  /// **'クリップ/Play'**
  String get usersPageTabClips;

  /// ユーザーページで、凍結中 / ブロック中などのため中身を隠しているとき
  ///
  /// In ja, this message translates to:
  /// **'制限されたユーザーです'**
  String get usersRestrictedTitle;

  /// 上の補足。「表示」はプロフィールの欄のボタンの名前
  ///
  /// In ja, this message translates to:
  /// **'「表示」を押すと内容を表示します'**
  String get usersRestrictedHint;

  /// ユーザーページの「…」のメニューの項目
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get usersMenuCopyLink;

  /// ユーザーページのメニューの項目: RASQ のリストにこの人を入れる
  ///
  /// In ja, this message translates to:
  /// **'RASQ リストに追加'**
  String get usersMenuAddToRasqList;

  /// ユーザーページのメニューの項目: この人のサーバーの情報を開く
  ///
  /// In ja, this message translates to:
  /// **'サーバー情報'**
  String get usersMenuServerInfo;

  /// ユーザーページのメニューの項目
  ///
  /// In ja, this message translates to:
  /// **'ミュート解除'**
  String get usersMenuUnmute;

  /// ユーザーページのメニューの項目
  ///
  /// In ja, this message translates to:
  /// **'ミュート'**
  String get usersMenuMute;

  /// ユーザーページのメニューの項目
  ///
  /// In ja, this message translates to:
  /// **'ブロック解除'**
  String get usersMenuUnblock;

  /// ユーザーページのメニューの項目、およびブロックの確認のボタン
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get usersMenuBlock;

  /// ユーザーページのメニューの項目、および報告の確認のボタン
  ///
  /// In ja, this message translates to:
  /// **'報告'**
  String get usersMenuReport;

  /// ユーザーのブロックの確認の見出し。name はその人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} をブロックしますか？'**
  String usersBlockConfirmTitle(String name);

  /// ユーザーのブロックの確認の説明
  ///
  /// In ja, this message translates to:
  /// **'相手からのフォロー・リアクション・返信が届かなくなります。'**
  String get usersBlockConfirmMessage;

  /// 確認のダイアログのやめるボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get usersCancel;

  /// ユーザーの報告の確認の見出し。name はその人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} を報告しますか？'**
  String usersReportConfirmTitle(String name);

  /// ユーザーの報告の確認の説明
  ///
  /// In ja, this message translates to:
  /// **'サーバー管理者に報告します。'**
  String get usersReportConfirmMessage;

  /// ユーザーページのタブの投稿が無いとき
  ///
  /// In ja, this message translates to:
  /// **'投稿はありません'**
  String get usersPostsEmpty;

  /// ユーザーページで、プロフィールに固定(ピン留め)された投稿の上に付ける印
  ///
  /// In ja, this message translates to:
  /// **'ピン留め'**
  String get usersPinnedBadge;

  /// クリップ/Play のタブで、SNS がクリップにも Play にも対応していないときの見出し
  ///
  /// In ja, this message translates to:
  /// **'クリップ / Play'**
  String get usersClipsUnsupportedTitle;

  /// 上の説明
  ///
  /// In ja, this message translates to:
  /// **'この SNS はクリップ・Play に対応していません'**
  String get usersClipsUnsupportedHint;

  /// クリップ/Play のタブで、公開されたクリップも Play も無いとき
  ///
  /// In ja, this message translates to:
  /// **'公開クリップ・Play はありません'**
  String get usersClipsEmpty;

  /// クリップ/Play のタブの節の見出し(公開クリップの一覧)
  ///
  /// In ja, this message translates to:
  /// **'クリップ'**
  String get usersClipsHeader;

  /// 公開クリップの行の補足の、クリップに入っている投稿の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件}}'**
  String usersClipNoteCount(int count);

  /// 公開クリップの行の補足で、投稿の数とクリップの説明のあいだに入れる区切り
  ///
  /// In ja, this message translates to:
  /// **' ・ '**
  String get usersClipSubtitleSeparator;

  /// ユーザーページで、ユーザーが見つからない(404 など)とき
  ///
  /// In ja, this message translates to:
  /// **'このユーザーは存在しないようです。'**
  String get usersNotFound;

  /// VC ホームの節の見出し / 検索の節のチップ(招待されているルーム)
  ///
  /// In ja, this message translates to:
  /// **'招待'**
  String get vcSectionInvited;

  /// VC ホームの節の見出し / 検索の節のチップ
  ///
  /// In ja, this message translates to:
  /// **'おすすめ'**
  String get vcSectionRecommended;

  /// VC ホームの節の見出し / 検索の節のチップ(開催予約中のルーム)
  ///
  /// In ja, this message translates to:
  /// **'近日開催'**
  String get vcSectionUpcoming;

  /// VC ホームの節の見出し / 検索の節のチップ
  ///
  /// In ja, this message translates to:
  /// **'トレンド'**
  String get vcSectionTrending;

  /// VC ホームの節の見出し / 検索の節のチップ(フォロー中のユーザーのルーム)
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get vcSectionFollowing;

  /// 節の見出しの歯車のツールチップ。title は節の見出し
  ///
  /// In ja, this message translates to:
  /// **'{title}の設定'**
  String vcSectionSettingsTooltip(String title);

  /// VC ホームの検索欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'ASTell / Swing を検索'**
  String get vcSearchHint;

  /// 語を重ねたあとの検索欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'さらに絞る'**
  String get vcSearchRefineHint;

  /// 重ねた検索語のチップ(押すと外す)。term は語
  ///
  /// In ja, this message translates to:
  /// **'「{term}」 ×'**
  String vcSearchTermChip(String term);

  /// 検索欄の入力を消すボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'消す'**
  String get vcSearchClear;

  /// VC ホームの + ボタンのツールチップ / 作成 FOW の見出し
  ///
  /// In ja, this message translates to:
  /// **'VC を作成'**
  String get vcCreateTooltip;

  /// VC ホームを読めなかったときの見出し
  ///
  /// In ja, this message translates to:
  /// **'VC を取得できませんでした'**
  String get vcHomeLoadError;

  /// 参加中のルームへの戻り口の行。title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'参加中: {title}'**
  String vcJoinedRoom(String title);

  /// 参加中のルームの行の補足。count は参加人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}人 ・ タップで開く}}'**
  String vcJoinedPeers(int count);

  /// ルームに接続中の表示
  ///
  /// In ja, this message translates to:
  /// **'接続しています…'**
  String get vcConnecting;

  /// 招待されたルームの行の補足。name はホストの表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} から招待 ・ タップで見る'**
  String vcInvitedBy(String name);

  /// 招待を辞退するボタン
  ///
  /// In ja, this message translates to:
  /// **'辞退'**
  String get vcInviteDecline;

  /// おすすめの節が空のとき
  ///
  /// In ja, this message translates to:
  /// **'おすすめの VC はまだありません'**
  String get vcRecommendedEmpty;

  /// トレンドの節が空のとき
  ///
  /// In ja, this message translates to:
  /// **'トレンドの VC はまだありません'**
  String get vcTrendingEmpty;

  /// フォロー中の節が空のとき
  ///
  /// In ja, this message translates to:
  /// **'フォロー中のユーザーの VC はありません'**
  String get vcFollowingEmpty;

  /// 検索の結果が無いときの見出し
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした'**
  String get vcSearchNoResults;

  /// 節だけで絞って結果が無いとき
  ///
  /// In ja, this message translates to:
  /// **'この節にはありません'**
  String get vcSearchNoResultsInSection;

  /// 検索の結果が無いとき。query は検索語
  ///
  /// In ja, this message translates to:
  /// **'「{query}」に当たる ASTell / Swing はありません'**
  String vcSearchNoResultsFor(String query);

  /// VC タイルの下のボタン(ルームのプレビューを開く)
  ///
  /// In ja, this message translates to:
  /// **'見てみる'**
  String get vcTileOpen;

  /// ルームのブックマークを外す(ツールチップ / メニュー)
  ///
  /// In ja, this message translates to:
  /// **'ブックマークから削除'**
  String get vcBookmarkRemove;

  /// ルームをブックマークする(ツールチップ / メニュー)
  ///
  /// In ja, this message translates to:
  /// **'ブックマークに保存'**
  String get vcBookmarkSave;

  /// 開催予約のルームの開始通知を外す(ツールチップ / メニュー)
  ///
  /// In ja, this message translates to:
  /// **'開始通知を解除'**
  String get vcRemindCancel;

  /// 開催予約のルームの開始を通知する(ツールチップ / メニュー)
  ///
  /// In ja, this message translates to:
  /// **'開始を通知'**
  String get vcRemindSet;

  /// … ボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get vcMenuTooltip;

  /// 開催予約の時刻。when は「9/6 20:00」の形の日時
  ///
  /// In ja, this message translates to:
  /// **'開催予定 {when}'**
  String vcScheduledAt(String when);

  /// ざっくり要約を公開していないルームのタイル
  ///
  /// In ja, this message translates to:
  /// **'ざっくり要約は非公開です。'**
  String get vcSummaryPrivate;

  /// タイルの並びが空のとき
  ///
  /// In ja, this message translates to:
  /// **'VC はまだありません'**
  String get vcTileStripEmpty;

  /// ルームのリンクをコピーしたときのスナックバー
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピーしました'**
  String get vcLinkCopied;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'ブックマークに保存しました'**
  String get vcBookmarkSaved;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'ブックマークから削除しました'**
  String get vcBookmarkRemoved;

  /// 開始通知を登録したときのスナックバー。when は開催予定の日時(formatAstellSchedule)
  ///
  /// In ja, this message translates to:
  /// **'{when} に通知します'**
  String vcRemindRegistered(String when);

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'通知を解除しました'**
  String get vcRemindRemoved;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'この端末では通知を登録できませんでした'**
  String get vcRemindUnavailable;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'開催予定のないルームです'**
  String get vcRemindNotScheduled;

  /// タイルの … メニュー
  ///
  /// In ja, this message translates to:
  /// **'投稿で共有'**
  String get vcMenuShareAsPost;

  /// タイルの … メニュー / 共有の操作
  ///
  /// In ja, this message translates to:
  /// **'リンクをコピー'**
  String get vcMenuCopyLink;

  /// タイルの … メニュー(自分の開催予約のルーム)
  ///
  /// In ja, this message translates to:
  /// **'今すぐ開催する'**
  String get vcMenuStartNow;

  /// タイルの … メニュー(参加中の自分のルーム)
  ///
  /// In ja, this message translates to:
  /// **'ルームへ戻る'**
  String get vcMenuBackToRoom;

  /// タイルの … メニュー(自分のルーム)
  ///
  /// In ja, this message translates to:
  /// **'参加する'**
  String get vcMenuJoin;

  /// タイルの … メニュー / ルームを終了する確認シートのボタン
  ///
  /// In ja, this message translates to:
  /// **'終了する'**
  String get vcMenuClose;

  /// タイルの … メニュー
  ///
  /// In ja, this message translates to:
  /// **'ホストのフォローを解除'**
  String get vcMenuUnfollowHost;

  /// タイルの … メニュー
  ///
  /// In ja, this message translates to:
  /// **'ホストをフォロー'**
  String get vcMenuFollowHost;

  /// タイルの … メニュー
  ///
  /// In ja, this message translates to:
  /// **'ミュート'**
  String get vcMenuMute;

  /// タイルの … メニュー / 共有の操作
  ///
  /// In ja, this message translates to:
  /// **'報告'**
  String get vcMenuReport;

  /// スナックバー。name はホストの表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} のフォローを解除しました'**
  String vcUnfollowed(String name);

  /// スナックバー。name はホストの表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} をフォローしました'**
  String vcFollowed(String name);

  /// 通報シートの対象の名前(「〜を通報します」に入る)。title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'ルーム「{title}」'**
  String vcReportWhatRoom(String title);

  /// まだ無い操作を選んだとき。title はルームの名前、action は操作の id
  ///
  /// In ja, this message translates to:
  /// **'「{title}」の操作({action})は M5 後段で入ります'**
  String vcMenuNotYet(String title, String action);

  /// ルームを終了する確認シートの見出し
  ///
  /// In ja, this message translates to:
  /// **'ルームを終了'**
  String get vcCloseRoomTitle;

  /// 開催予約を取り消す確認の本文。title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'「{title}」の予約を取り消します。ブックマークや開始通知を登録した人には届きません。'**
  String vcCloseScheduledBody(String title);

  /// ルームを終了する確認の本文。title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'「{title}」を終了します。参加中のメンバーは退出になります。'**
  String vcCloseRoomBody(String title);

  /// スナックバー。title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'「{title}」の予約を取り消しました'**
  String vcClosedScheduled(String title);

  /// スナックバー。title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'「{title}」を終了しました'**
  String vcClosedRoom(String title);

  /// スナックバー。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'終了できませんでした: {error}'**
  String vcCloseFailed(String error);

  /// VC タイルの下のボタン(参加中のルームへ戻る)
  ///
  /// In ja, this message translates to:
  /// **'戻る'**
  String get vcTileBack;

  /// 開始通知(端末の通知)の見出し
  ///
  /// In ja, this message translates to:
  /// **'ブックマークしたVCが始まります！'**
  String get vcReminderNotificationTitle;

  /// 開始通知(端末の通知)の本文。host はホストの表示名、title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'{host} の「{title}」'**
  String vcReminderNotificationBody(String host, String title);

  /// ルームを投稿で共有するときの本文の頭。title はルームの名前、when は開催予定の日時
  ///
  /// In ja, this message translates to:
  /// **'「{title}」を {when} に開催します'**
  String vcShareTextScheduled(String title, String when);

  /// ルームを投稿で共有するときの本文の頭。title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'「{title}」を開催中です'**
  String vcShareTextOpen(String title);

  /// 共有メディアの全画面表示の下段のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'全画面表示プラグイン(準備中)'**
  String get vcViewerPluginsTooltip;

  /// 共有メディアの全画面表示の下段。name は共有した人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} が共有'**
  String vcViewerSharedBy(String name);

  /// 共有メディアの全画面表示の保存ボタン
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get vcViewerSave;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'保存は準備中です'**
  String get vcViewerSaveNotYet;

  /// 共有メディアの全画面表示の共有ボタン
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get vcViewerShare;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'共有は準備中です'**
  String get vcViewerShareNotYet;

  /// ルームの下段のボタンの名前(並びの編集画面に出る)
  ///
  /// In ja, this message translates to:
  /// **'スピーカー'**
  String get vcBarSpeaker;

  /// ルームの下段のボタンの名前(並びの編集画面に出る)
  ///
  /// In ja, this message translates to:
  /// **'マイク'**
  String get vcBarMic;

  /// ルームの下段のボタンの名前(並びの編集画面に出る)
  ///
  /// In ja, this message translates to:
  /// **'画面共有'**
  String get vcBarScreen;

  /// ルームの下段のボタンの名前(並びの編集画面に出る)
  ///
  /// In ja, this message translates to:
  /// **'全画面(共有枠に画面があるとき)'**
  String get vcBarFullscreen;

  /// ルームの下段のボタンの名前(並びの編集画面に出る)
  ///
  /// In ja, this message translates to:
  /// **'字幕(文字起こし)'**
  String get vcBarCaptions;

  /// 通話(WebRTC)の接続の失敗。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'通話の接続に失敗しました: {error}'**
  String vcCallConnectFailed(String error);

  /// リンクから開いたルームが無いとき
  ///
  /// In ja, this message translates to:
  /// **'このルームは見つかりません(終了したか、リンクが違うかもしれません)'**
  String get vcOpenNotFound;

  /// リンクから開いたルームを開けなかったときの見出し
  ///
  /// In ja, this message translates to:
  /// **'ルームを開けませんでした'**
  String get vcOpenFailed;

  /// リンクから開いた画面のボタン
  ///
  /// In ja, this message translates to:
  /// **'ASTell のホームへ'**
  String get vcOpenGoHome;

  /// リンクから開いたルームのホスト。name は表示名、handle はハンドル
  ///
  /// In ja, this message translates to:
  /// **'ホスト: {name}(@{handle})'**
  String vcOpenHost(String name, String handle);

  /// リンクから開いた画面のボタン
  ///
  /// In ja, this message translates to:
  /// **'ルームを開く'**
  String get vcOpenRoom;

  /// 投稿を ASTell に本文ごと共有できない理由
  ///
  /// In ja, this message translates to:
  /// **'ダイレクトの投稿は ASTell に共有できません'**
  String get vcShareBlockDirect;

  /// 投稿を ASTell に本文ごと共有できない理由
  ///
  /// In ja, this message translates to:
  /// **'ローカル限定の投稿は ASTell に共有できません'**
  String get vcShareBlockLocalOnly;

  /// 投稿を ASTell に本文ごと共有できない理由
  ///
  /// In ja, this message translates to:
  /// **'公開範囲が分からない投稿は ASTell に共有できません'**
  String get vcShareBlockUnknownVisibility;

  /// 投稿を ASTell に本文ごと共有できない理由
  ///
  /// In ja, this message translates to:
  /// **'公開範囲が限定された投稿は ASTell に共有できません'**
  String get vcShareBlockLimited;

  /// ルームの共有欄の見出し(共有が無いとき)
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get vcShares;

  /// ルームの共有欄の見出し。count は共有の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{共有 ({count})}}'**
  String vcSharesCount(int count);

  /// 共有欄の「>」のツールチップ
  ///
  /// In ja, this message translates to:
  /// **'すべての共有を見る'**
  String get vcSharesShowAll;

  /// 共有欄が空のとき
  ///
  /// In ja, this message translates to:
  /// **'チャットで 📌 したものがここに並びます。'**
  String get vcSharesEmpty;

  /// 共有カードの … のツールチップ
  ///
  /// In ja, this message translates to:
  /// **'共有の操作'**
  String get vcShareActions;

  /// ピン留めした文字起こしのカードの出どころ
  ///
  /// In ja, this message translates to:
  /// **'RASQ ・ 文字起こし'**
  String get vcShareTranscriptSource;

  /// 共有 / 文字起こしのピン留めを外す(ツールチップ / メニュー)
  ///
  /// In ja, this message translates to:
  /// **'ピン留めを外す'**
  String get vcUnpin;

  /// 自分の表示名の代わり
  ///
  /// In ja, this message translates to:
  /// **'あなた'**
  String get vcYou;

  /// ルームの要約が空のとき(タイル / プレビュー)
  ///
  /// In ja, this message translates to:
  /// **'説明はありません。'**
  String get vcNoDescription;

  /// 通報の理由
  ///
  /// In ja, this message translates to:
  /// **'スパム'**
  String get vcReportReasonSpam;

  /// 通報の理由
  ///
  /// In ja, this message translates to:
  /// **'嫌がらせ・暴言'**
  String get vcReportReasonHarassment;

  /// 通報の理由
  ///
  /// In ja, this message translates to:
  /// **'違法・危険な内容'**
  String get vcReportReasonIllegal;

  /// 通報の理由
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get vcReportReasonOther;

  /// ルームに参加できる人(参加ポリシー)
  ///
  /// In ja, this message translates to:
  /// **'誰でも'**
  String get vcJoinPolicyAnyone;

  /// 参加ポリシーの説明
  ///
  /// In ja, this message translates to:
  /// **'公開ルームは誰でも参加できます'**
  String get vcJoinPolicyAnyoneHint;

  /// ルームに参加できる人(参加ポリシー)
  ///
  /// In ja, this message translates to:
  /// **'フォロワーだけ'**
  String get vcJoinPolicyFollowers;

  /// 参加ポリシーの説明
  ///
  /// In ja, this message translates to:
  /// **'あなた(ホスト)を RASQ アカウントでフォローしている人'**
  String get vcJoinPolicyFollowersHint;

  /// ルームに参加できる人(参加ポリシー)
  ///
  /// In ja, this message translates to:
  /// **'フォロー中の人だけ'**
  String get vcJoinPolicyFollowing;

  /// 参加ポリシーの説明
  ///
  /// In ja, this message translates to:
  /// **'あなたがフォローしている人'**
  String get vcJoinPolicyFollowingHint;

  /// ルームに参加できる人(参加ポリシー)
  ///
  /// In ja, this message translates to:
  /// **'相互フォローだけ'**
  String get vcJoinPolicyMutual;

  /// 参加ポリシーの説明
  ///
  /// In ja, this message translates to:
  /// **'お互いにフォローしている人'**
  String get vcJoinPolicyMutualHint;

  /// 共有(チャットへの投稿)できる人
  ///
  /// In ja, this message translates to:
  /// **'全員'**
  String get vcSharePolicyEveryone;

  /// 共有(チャットへの投稿)できる人
  ///
  /// In ja, this message translates to:
  /// **'モデレーターだけ'**
  String get vcSharePolicyModerators;

  /// CW 付きの投稿の共有の見出し(本文は出さない)。warning は CW の文
  ///
  /// In ja, this message translates to:
  /// **'⚠ {warning}(閲覧注意)'**
  String vcShareContentWarning(String warning);

  /// プラグインの共有の見出し。name はプラグインの名前
  ///
  /// In ja, this message translates to:
  /// **'「{name}」を使いたい'**
  String vcSharePluginWant(String name);

  /// 共有の種別
  ///
  /// In ja, this message translates to:
  /// **'投稿'**
  String get vcKindPost;

  /// 共有の種別
  ///
  /// In ja, this message translates to:
  /// **'メディア'**
  String get vcKindMedia;

  /// 共有の種別
  ///
  /// In ja, this message translates to:
  /// **'動画'**
  String get vcKindVideo;

  /// 共有の種別
  ///
  /// In ja, this message translates to:
  /// **'リンク'**
  String get vcKindLink;

  /// 共有の種別
  ///
  /// In ja, this message translates to:
  /// **'テキスト'**
  String get vcKindText;

  /// 共有の種別
  ///
  /// In ja, this message translates to:
  /// **'プラグイン'**
  String get vcKindPlugin;

  /// 通話のマイクを使えない理由
  ///
  /// In ja, this message translates to:
  /// **'Web 版の通話は https で開いたときだけ使えます'**
  String get vcMediaInsecureContext;

  /// 通話のマイクを使えない理由
  ///
  /// In ja, this message translates to:
  /// **'マイク(カメラ)の許可がありません。端末の設定で許可してください'**
  String get vcMediaPermissionDenied;

  /// 通話のマイクを使えない理由
  ///
  /// In ja, this message translates to:
  /// **'マイク(カメラ)が見つかりません'**
  String get vcMediaNoDevice;

  /// 通話のマイクを使えない理由
  ///
  /// In ja, this message translates to:
  /// **'この端末では使えません'**
  String get vcMediaUnsupported;

  /// 通話のマイクを使えない理由。detail は端末の例外の内容
  ///
  /// In ja, this message translates to:
  /// **'この端末では使えません({detail})'**
  String vcMediaUnsupportedDetail(String detail);

  /// 退出したあとにマイクを開こうとしたときの失敗
  ///
  /// In ja, this message translates to:
  /// **'閉じた通話のマイクは開けません'**
  String get vcMediaMicClosed;

  /// 配信を上げようとしたが配信サーバー(LiveKit)に繋がっていないとき
  ///
  /// In ja, this message translates to:
  /// **'配信サーバーに繋がっていません'**
  String get vcStreamNotConnected;

  /// 配信 / 画面共有の映像を上げられなかったとき
  ///
  /// In ja, this message translates to:
  /// **'映像を配信サーバーに上げられませんでした'**
  String get vcStreamPublishFailed;

  /// Android の画面共有中の前面サービスの通知の本文
  ///
  /// In ja, this message translates to:
  /// **'画面を共有しています'**
  String get vcScreenSharingNotification;

  /// デスクトップの画面 / ウィンドウを選ぶダイアログの見出し
  ///
  /// In ja, this message translates to:
  /// **'共有する画面を選ぶ'**
  String get vcScreenPickTitle;

  /// 画面を選ぶダイアログのタブ
  ///
  /// In ja, this message translates to:
  /// **'画面全体'**
  String get vcScreenPickScreen;

  /// 画面を選ぶダイアログのタブ
  ///
  /// In ja, this message translates to:
  /// **'ウィンドウ'**
  String get vcScreenPickWindow;

  /// 画面を選ぶダイアログのボタン
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get vcScreenPickCancel;

  /// 画面を選ぶダイアログのボタン
  ///
  /// In ja, this message translates to:
  /// **'共有する'**
  String get vcScreenPickShare;

  /// Web: ブラウザが声の自動再生を止めているときの案内
  ///
  /// In ja, this message translates to:
  /// **'音が止まっています。画面をタップすると鳴ります'**
  String get vcNoticeAudioBlocked;

  /// 満員で通話に入れなかったときの案内。cap は通話に入れる人数
  ///
  /// In ja, this message translates to:
  /// **'通話は満員です({cap} 人まで)。配信があれば、配信で聞けます'**
  String vcNoticeCallFull(int cap);

  /// 開催予約の開始待ちの案内
  ///
  /// In ja, this message translates to:
  /// **'開催までお待ちください。保留音を鳴らしています'**
  String get vcNoticeHoldWaiting;

  /// 開催予約のルームが始まったときの案内
  ///
  /// In ja, this message translates to:
  /// **'開催が始まりました'**
  String get vcNoticeStarted;

  /// しばらく誰も話さないときの案内
  ///
  /// In ja, this message translates to:
  /// **'静かなので保留音を鳴らしています'**
  String get vcNoticeHoldIdle;

  /// 共有欄に自動で出すメディアの種類
  ///
  /// In ja, this message translates to:
  /// **'画像'**
  String get vcShareClassImage;

  /// 共有欄に自動で出すメディアの種類 / ファイルを共有するボタン
  ///
  /// In ja, this message translates to:
  /// **'ファイル'**
  String get vcShareClassFile;

  /// 共有欄に自動で出すメディアの種類 / 文字起こしのカード
  ///
  /// In ja, this message translates to:
  /// **'文字起こし'**
  String get vcShareClassTranscript;

  /// 共有欄の表示の選択肢
  ///
  /// In ja, this message translates to:
  /// **'カード(横スライド)'**
  String get vcShareStyleCards;

  /// 共有欄の表示の選択肢
  ///
  /// In ja, this message translates to:
  /// **'一覧(レガシー)'**
  String get vcShareStyleList;

  /// 同意待ちのアカウントがルームに入れなかったとき
  ///
  /// In ja, this message translates to:
  /// **'利用規約への同意が必要です(ASTell のいちばん上の案内から同意できます)'**
  String get vcTermsRequired;

  /// ルームが閉じられたときの案内
  ///
  /// In ja, this message translates to:
  /// **'運営によりルームが閉鎖されました'**
  String get vcClosedByModeration;

  /// ルームが閉じられたときの案内
  ///
  /// In ja, this message translates to:
  /// **'ホストがルームを終了しました'**
  String get vcClosedByHost;

  /// ルームから追い出されたときの案内
  ///
  /// In ja, this message translates to:
  /// **'このルームから BAN されました'**
  String get vcKickedBanned;

  /// ルームから追い出されたときの案内
  ///
  /// In ja, this message translates to:
  /// **'アカウントの処置により退出させられました'**
  String get vcKickedSanctioned;

  /// ルームから追い出されたときの案内
  ///
  /// In ja, this message translates to:
  /// **'モデレーターにルームから退出させられました'**
  String get vcKickedByModerator;

  /// アカウントの処置で共有が保留されたとき。seconds は秒数(不明なら ?)
  ///
  /// In ja, this message translates to:
  /// **'検閲中: {seconds} 秒後に判定して配信されます(アカウントの処置)'**
  String vcShareHeld(String seconds);

  /// 共有が却下されたとき。source は判定の出どころ(review など)
  ///
  /// In ja, this message translates to:
  /// **'検閲で却下されました({source})。この発言は配信されていません'**
  String vcShareRejected(String source);

  /// ルームに入らずに配信へ繋ごうとしたときの失敗
  ///
  /// In ja, this message translates to:
  /// **'ルームに入っていません'**
  String get vcNotInRoom;

  /// 配信 / 画面共有の映像を受けられないときの案内。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'映像を受けられません: {error}'**
  String vcStreamReceiveFailed(String error);

  /// 配信を始められないとき
  ///
  /// In ja, this message translates to:
  /// **'画面共有中は配信を始められません(共有をやめてから)'**
  String get vcStreamBlockedByScreenShare;

  /// 配信を始められないとき。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'配信を始められません: {error}'**
  String vcStreamStartFailed(String error);

  /// 配信を止めたあとルームの印を消せなかったとき。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'配信の印を消せませんでした: {error}'**
  String vcStreamClearFailed(String error);

  /// 画面共有を始められないとき
  ///
  /// In ja, this message translates to:
  /// **'配信中は画面共有を始められません(配信を止めてから)'**
  String get vcScreenShareBlockedByStream;

  /// 画面共有を始められないとき。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'画面共有を始められません: {error}'**
  String vcScreenShareStartFailed(String error);

  /// 配信の失敗(サーバーが 501)
  ///
  /// In ja, this message translates to:
  /// **'配信はまだ使えません(配信サーバーが未設定)'**
  String get vcStreamUnavailable;

  /// 配信の失敗(サーバーが 403)。message はサーバーの文
  ///
  /// In ja, this message translates to:
  /// **'許可されていません({message})'**
  String vcStreamForbidden(String message);

  /// 読み上げを使えないとき(モック)
  ///
  /// In ja, this message translates to:
  /// **'読み上げバックエンドが未設定です(CENTRAL_TTS_URL)'**
  String get vcTtsNotConfigured;

  /// ログインせずにルームへ繋ごうとしたとき
  ///
  /// In ja, this message translates to:
  /// **'RASQ アカウントにログインしてください'**
  String get vcLoginRequired;

  /// 作成画面の招待のチップのツールチップ。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} の招待をやめる'**
  String vcCreateUninvite(String name);

  /// 作成画面の招待のチップのツールチップ。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} を招待'**
  String vcCreateInvite(String name);

  /// 作成 FOW の閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get vcCreateCancel;

  /// 作成 FOW の共有のアイコンのツールチップ(オン)
  ///
  /// In ja, this message translates to:
  /// **'作成後に投稿で共有する(オン)'**
  String get vcCreateShareAfterOn;

  /// 作成 FOW の共有のアイコンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'作成後に投稿で共有する'**
  String get vcCreateShareAfter;

  /// スナックバー。title はルームの名前、when は開催予定の日時
  ///
  /// In ja, this message translates to:
  /// **'「{title}」を {when} に予約しました'**
  String vcCreateScheduled(String title, String when);

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'開催予定は今より後にしてください'**
  String get vcCreateScheduleInPast;

  /// スナックバー。max はジャンルの上限
  ///
  /// In ja, this message translates to:
  /// **'{max, plural, other{ジャンルは {max} 個までです}}'**
  String vcCreateGenresMax(int max);

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'タイトルを入力してください'**
  String get vcCreateTitleRequired;

  /// スナックバー。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'招待を送れませんでした: {error}'**
  String vcCreateInviteFailed(String error);

  /// スナックバー。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'作成できませんでした: {error}'**
  String vcCreateFailed(String error);

  /// 作成画面の招待の「+」/ そのシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'検索して追加'**
  String get vcCreateSearchAdd;

  /// 招待するアカウントを探す入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'@handle(RASQ アカウント)'**
  String get vcCreateHandleHint;

  /// 招待するアカウントが見つからないとき。handle は入力した値
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした: {handle}'**
  String vcCreateHandleNotFound(String handle);

  /// 招待するアカウントを探すシートのボタン
  ///
  /// In ja, this message translates to:
  /// **'招待に追加'**
  String get vcCreateAddInvitee;

  /// 作成画面のタイトルの入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'タイトル'**
  String get vcCreateTitleHint;

  /// 作成画面の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'フォロワーを招待'**
  String get vcCreateInviteFollowers;

  /// 作成画面の節の見出し。count は招待する人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{フォロワーを招待({count})}}'**
  String vcCreateInviteFollowersCount(int count);

  /// 作成画面のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'参加時にウェルカムメッセージを表示する'**
  String get vcCreateWelcomeToggle;

  /// 作成画面の入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'ウェルカムメッセージを設定..'**
  String get vcCreateWelcomeHint;

  /// 作成画面の節の見出し。max はジャンルの上限
  ///
  /// In ja, this message translates to:
  /// **'{max, plural, other{ジャンルを選定(最大 {max})}}'**
  String vcCreateGenresLabel(int max);

  /// 作成画面の入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'ジャンルを入力'**
  String get vcCreateGenreHint;

  /// 作成画面のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'ジャンルを追加'**
  String get vcCreateGenreAdd;

  /// 作成画面のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'開催を予約する'**
  String get vcCreateSchedule;

  /// 開催予約の注記
  ///
  /// In ja, this message translates to:
  /// **'予約中は、あなたが入るまで他の人は入れません。'**
  String get vcCreateScheduleCaption;

  /// 開催予約の注記(開発者モードの詳しい説明)
  ///
  /// In ja, this message translates to:
  /// **'予約中はあなた(とモデレーター)が入るまで他の人は参加できません。近日開催の節と共有リンクから開始通知を登録できます。'**
  String get vcCreateScheduleCaptionDetail;

  /// 作成画面の入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'ざっくり要約(任意。空なら自動で作ります)'**
  String get vcCreateSummaryHint;

  /// 作成画面のマイクのボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'マイク(作成後に切替)'**
  String get vcCreateMicAfterCreate;

  /// 作成画面のボタン(開催予約)
  ///
  /// In ja, this message translates to:
  /// **'予約'**
  String get vcCreateScheduleButton;

  /// 作成画面のボタン
  ///
  /// In ja, this message translates to:
  /// **'作成'**
  String get vcCreateButton;

  /// ホストの行のピル(ホストがルームにいる)
  ///
  /// In ja, this message translates to:
  /// **'参加中'**
  String get vcRoomHostPresent;

  /// ホストの行のピル(開催予約中)
  ///
  /// In ja, this message translates to:
  /// **'開催前'**
  String get vcRoomHostBeforeStart;

  /// ホストの行のピル(ホストがいない)
  ///
  /// In ja, this message translates to:
  /// **'不在'**
  String get vcRoomHostAbsent;

  /// 参加メンバーの顔ぶれが取れていないときの人数。count は人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count} 人が参加しています}}'**
  String vcRoomMembersCount(int count);

  /// 参加メンバーがホストだけのとき
  ///
  /// In ja, this message translates to:
  /// **'ホストのほかには、まだ誰もいません'**
  String get vcRoomMembersHostOnly;

  /// 参加メンバーがいないとき
  ///
  /// In ja, this message translates to:
  /// **'まだ誰もいません'**
  String get vcRoomMembersNone;

  /// 参加メンバー行の 3 人より後の人数。count は人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{他{count}人}}'**
  String vcRoomMembersRest(int count);

  /// 画面共有の枠のツールチップ(表示中)
  ///
  /// In ja, this message translates to:
  /// **'共有枠に表示中'**
  String get vcRoomScreenShown;

  /// 画面共有の枠のツールチップ
  ///
  /// In ja, this message translates to:
  /// **'画面共有を表示'**
  String get vcRoomScreenShow;

  /// まだ無い機能を押したとき。what は機能の名前
  ///
  /// In ja, this message translates to:
  /// **'{what} は準備中です'**
  String vcRoomNotYet(String what);

  /// 参加前 / 作成前の歯車のシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'ASTell の設定(この端末)'**
  String get vcRoomDeviceSettingsTitle;

  /// 設定の行
  ///
  /// In ja, this message translates to:
  /// **'下段のボタンの並びを編集'**
  String get vcRoomEditBar;

  /// 設定の行の補足
  ///
  /// In ja, this message translates to:
  /// **'並べ替え / 表示 / 非表示 / プラグインのボタンを追加'**
  String get vcRoomEditBarSubtitle;

  /// 設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'チャットの内容を自動で共有欄に出す(ピン留めしなくても)'**
  String get vcRoomAutoShareLabel;

  /// 設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'共有欄の表示'**
  String get vcRoomShareStyleLabel;

  /// 設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'自動再生'**
  String get vcRoomAutoPlayLabel;

  /// 設定のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'画面共有が始まったら共有枠に出す'**
  String get vcRoomAutoPlayScreen;

  /// 設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'保留音'**
  String get vcRoomHoldMusicLabel;

  /// 設定のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'保留音を鳴らす(この端末)'**
  String get vcRoomHoldMusicDevice;

  /// 設定の小見出し(この端末で鳴らす保留音の曲を選ぶ)
  ///
  /// In ja, this message translates to:
  /// **'保留音の音源'**
  String get vcRoomHoldMusicSourceLabel;

  /// 保留音の音源の選択肢(曲名。既定)。訳さない
  ///
  /// In ja, this message translates to:
  /// **'We：Astronomies on the Blue Planet'**
  String get vcRoomHoldMusicSourceAstronomies;

  /// 保留音の音源の選択肢(昔からの保留音の曲)
  ///
  /// In ja, this message translates to:
  /// **'保留音'**
  String get vcRoomHoldMusicSourceClassic;

  /// 設定のスライダー
  ///
  /// In ja, this message translates to:
  /// **'保留音の音量'**
  String get vcRoomHoldMusicVolume;

  /// 保留音の音量の表示。percent は 0〜100
  ///
  /// In ja, this message translates to:
  /// **'{percent}%'**
  String vcRoomHoldMusicVolumeValue(int percent);

  /// 参加前の設定のシートの注記
  ///
  /// In ja, this message translates to:
  /// **'ルームの設定は、参加後にルームの歯車から変えられます(オーナー)。'**
  String get vcRoomDeviceSettingsCaption;

  /// 参加前の設定のシートの注記(開発者モードの詳しい説明)
  ///
  /// In ja, this message translates to:
  /// **'ルームごとの設定(参加できる人・読み上げなど)は、参加してからルームの歯車で変えられます(オーナー)。'**
  String get vcRoomDeviceSettingsCaptionDetail;

  /// FOW / シートを閉じるボタン
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get vcRoomClose;

  /// 共有ボタン(ツールチップ / ボタン / 見出し)
  ///
  /// In ja, this message translates to:
  /// **'共有'**
  String get vcRoomShare;

  /// プレビュー / ルームの節の見出し、メンバーの役割
  ///
  /// In ja, this message translates to:
  /// **'ホスト'**
  String get vcRoomHost;

  /// プレビュー / ルームの節の見出し
  ///
  /// In ja, this message translates to:
  /// **'参加メンバー'**
  String get vcRoomMembers;

  /// 新規入室が止められたルームの注記
  ///
  /// In ja, this message translates to:
  /// **'運営により新しい入室が止められています。'**
  String get vcRoomLocked;

  /// 新規入室が止められたルームの注記(開発者モードの詳しい説明)
  ///
  /// In ja, this message translates to:
  /// **'運営により新規入室が停止されています(D-151)。'**
  String get vcRoomLockedDetail;

  /// 開始通知を登録済みのときの補足
  ///
  /// In ja, this message translates to:
  /// **'開始を通知します'**
  String get vcRoomRemindOn;

  /// 開催予約中のルームの補足
  ///
  /// In ja, this message translates to:
  /// **'ホストが始めるまで参加できません'**
  String get vcRoomWaitForHost;

  /// 開始通知を外すボタン
  ///
  /// In ja, this message translates to:
  /// **'通知を解除'**
  String get vcRoomRemindOff;

  /// プレビューの節の見出し
  ///
  /// In ja, this message translates to:
  /// **'ざっくり要約'**
  String get vcRoomSummary;

  /// ざっくり要約を公開していないルームのプレビュー
  ///
  /// In ja, this message translates to:
  /// **'このルームはざっくり要約を公開していません。'**
  String get vcRoomSummaryPrivate;

  /// プレビューのウェルカムメッセージ。message はホストが書いた文
  ///
  /// In ja, this message translates to:
  /// **'ようこそ: {message}'**
  String vcRoomWelcome(String message);

  /// プレビューのマイクのボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'マイク(参加後に切替)'**
  String get vcRoomMicAfterJoin;

  /// 字幕のボタンのツールチップ / 作成画面のボタン
  ///
  /// In ja, this message translates to:
  /// **'字幕'**
  String get vcRoomCaptions;

  /// プレビューの参加ボタン
  ///
  /// In ja, this message translates to:
  /// **'参加'**
  String get vcRoomJoin;

  /// 歯車のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get vcRoomSettings;

  /// ルームのタブ
  ///
  /// In ja, this message translates to:
  /// **'ホーム'**
  String get vcRoomTabHome;

  /// ルームのタブ
  ///
  /// In ja, this message translates to:
  /// **'チャット'**
  String get vcRoomTabChat;

  /// ルームのタブ
  ///
  /// In ja, this message translates to:
  /// **'目次'**
  String get vcRoomTabToc;

  /// ルームのタブ
  ///
  /// In ja, this message translates to:
  /// **'ルーム'**
  String get vcRoomTabRoom;

  /// ルームから退出したあとの表示
  ///
  /// In ja, this message translates to:
  /// **'退出しました'**
  String get vcRoomLeft;

  /// ルームから退出するボタン
  ///
  /// In ja, this message translates to:
  /// **'退出'**
  String get vcRoomLeave;

  /// 自分が配信中の帯 / 配信の設定
  ///
  /// In ja, this message translates to:
  /// **'画面を配信しています'**
  String get vcRoomStreamingScreen;

  /// 自分が配信中の帯 / 配信の設定
  ///
  /// In ja, this message translates to:
  /// **'カメラで配信しています'**
  String get vcRoomStreamingCamera;

  /// 画面共有中の帯のボタン
  ///
  /// In ja, this message translates to:
  /// **'共有をやめる'**
  String get vcRoomStopSharing;

  /// 配信中の帯のボタン / 配信の設定
  ///
  /// In ja, this message translates to:
  /// **'配信を止める'**
  String get vcRoomStopStream;

  /// 下段のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'スピーカーミュート解除'**
  String get vcRoomSpeakerUnmute;

  /// 下段のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'スピーカーミュート'**
  String get vcRoomSpeakerMute;

  /// 下段のマイクのボタンのツールチップ(強制ミュート中)
  ///
  /// In ja, this message translates to:
  /// **'モデレーターにミュートされています'**
  String get vcRoomMutedByModerator;

  /// 下段のマイクのボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'マイクを準備中(押すとやめる)'**
  String get vcRoomMicOpening;

  /// 下段のマイクのボタンのツールチップ(押すとオフ)
  ///
  /// In ja, this message translates to:
  /// **'マイクオフ'**
  String get vcRoomMicOff;

  /// 下段のマイクのボタンのツールチップ(押すとオン)
  ///
  /// In ja, this message translates to:
  /// **'マイクオン'**
  String get vcRoomMicOn;

  /// 下段の画面共有のボタンのツールチップ(押すとやめる)
  ///
  /// In ja, this message translates to:
  /// **'画面共有オフ'**
  String get vcRoomScreenShareOff;

  /// 全画面のボタン / メニュー
  ///
  /// In ja, this message translates to:
  /// **'全画面'**
  String get vcRoomFullscreen;

  /// 下段の字幕のボタンのツールチップ(押すとオフ)/ 字幕が切れているときの表示
  ///
  /// In ja, this message translates to:
  /// **'字幕オフ'**
  String get vcRoomCaptionsOff;

  /// 下段の字幕のボタンのツールチップ(押すとオン)
  ///
  /// In ja, this message translates to:
  /// **'字幕オン'**
  String get vcRoomCaptionsOn;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'公開範囲が限定された投稿なので、リンクとして共有します'**
  String get vcRoomShareAsLinkLimited;

  /// スナックバー。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'投稿を取れなかったのでリンクとして共有します: {error}'**
  String vcRoomShareAsLinkFailed(String error);

  /// スナックバー。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'ファイルを選択できませんでした: {error}'**
  String vcRoomPickFileFailed(String error);

  /// ホストの配信(画面共有と並べる種別の名前)
  ///
  /// In ja, this message translates to:
  /// **'配信'**
  String get vcRoomStream;

  /// 配信のカードの見出し。kind は「画面共有」か「配信」、title は配信の題(無ければホストの表示名)
  ///
  /// In ja, this message translates to:
  /// **'{kind}: {title}'**
  String vcRoomLiveCardTitle(String kind, String title);

  /// 参加者の画面共有の見出し。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} の画面'**
  String vcRoomPeerScreen(String name);

  /// 参加者の画面共有の見出し。name は表示名、title は画面の題
  ///
  /// In ja, this message translates to:
  /// **'{name} の画面 — {title}'**
  String vcRoomPeerScreenTitled(String name, String title);

  /// すべての共有のシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'すべての共有'**
  String get vcRoomAllShares;

  /// ルームの歯車のシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'VC の設定'**
  String get vcRoomSettingsTitle;

  /// ルームの設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'モデレーション(オーナー)'**
  String get vcRoomModerationLabel;

  /// ルームの設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'参加できる人'**
  String get vcRoomJoinPolicyLabel;

  /// ルームの設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'共有(チャットへの投稿)できる人'**
  String get vcRoomSharePolicyLabel;

  /// ルームの設定の節の見出し。count はモデレーターの数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{モデレーター({count})— メンバーの「…」から追加}}'**
  String vcRoomModeratorsLabel(int count);

  /// モデレーターを外す(ツールチップ / メニュー)
  ///
  /// In ja, this message translates to:
  /// **'モデレーターを外す'**
  String get vcRoomRemoveModerator;

  /// ルームの設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'発信傾向'**
  String get vcRoomTendencyLabel;

  /// ルームの設定のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'荒らしの入室を断る(試験中)'**
  String get vcRoomTendencyFilter;

  /// 発信傾向の注記
  ///
  /// In ja, this message translates to:
  /// **'オンにすると、敵対的と判定された人は入れません。判定はまだ仮のものです。'**
  String get vcRoomTendencyCaption;

  /// 発信傾向の注記(開発者モードの詳しい説明)
  ///
  /// In ja, this message translates to:
  /// **'本命は rasq-judge の GoEmotion(発信の感情傾向)で、学習が要るので今はサーバーのダミー判定(表示名に hostile / 荒らし を含む人だけ敵対的)。オンにすると敵対的と判定された人は入室できません。メンバー行の「…」から判定結果を見られます。'**
  String get vcRoomTendencyCaptionDetail;

  /// ルームの設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'配信(ホスト)'**
  String get vcRoomHostStreamLabel;

  /// ルームの設定の行
  ///
  /// In ja, this message translates to:
  /// **'カメラで配信する'**
  String get vcRoomStreamCamera;

  /// ルームの設定の行
  ///
  /// In ja, this message translates to:
  /// **'画面を配信する'**
  String get vcRoomStreamScreen;

  /// 画面の配信の補足(iOS)
  ///
  /// In ja, this message translates to:
  /// **'iPhone / iPad はこのアプリの画面だけ(ほかのアプリは映りません)'**
  String get vcRoomStreamScreenIos;

  /// 配信の注記
  ///
  /// In ja, this message translates to:
  /// **'映像と声を配信します。通話に入りきらない人も配信で聞けます。'**
  String get vcRoomHostStreamCaption;

  /// 配信の注記(開発者モードの詳しい説明)。cap は通話に入れる人数
  ///
  /// In ja, this message translates to:
  /// **'映像とマイクを配信サーバー(LiveKit)に上げます。参加者は通話の声のまま映像を見られ、通話に入りきらない人({cap} 人目より後)は配信であなたの声を聞きます。'**
  String vcRoomHostStreamCaptionDetail(int cap);

  /// ルームの設定のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'このルームで保留音を許す(オーナー)'**
  String get vcRoomHoldMusicRoom;

  /// 保留音の注記
  ///
  /// In ja, this message translates to:
  /// **'開始を待つ間や、しばらく誰も話さないときに鳴ります。'**
  String get vcRoomHoldMusicCaption;

  /// 保留音の注記(開発者モードの詳しい説明)。minutes は分
  ///
  /// In ja, this message translates to:
  /// **'開催予約の開始を待っている間と、全員がマイクを下ろして(画面共有 / 配信も無く)チャットが {minutes} 分以上流れていない間に鳴ります。誰かが話し始めるか、チャットが流れると止まります。'**
  String vcRoomHoldMusicCaptionDetail(int minutes);

  /// ルームの設定の節の見出し
  ///
  /// In ja, this message translates to:
  /// **'読み上げ'**
  String get vcRoomTts;

  /// ルームの設定の節の見出し(読み上げを使えないとき)
  ///
  /// In ja, this message translates to:
  /// **'読み上げ(使えません)'**
  String get vcRoomTtsUnavailable;

  /// ルームの設定の節の見出し(開発者モード)。model は音声合成のモデル名
  ///
  /// In ja, this message translates to:
  /// **'読み上げ({model}、プリセット音声)'**
  String vcRoomTtsDetail(String model);

  /// ルームの設定の節の見出し(開発者モード、使えないとき)。model は音声合成のモデル名
  ///
  /// In ja, this message translates to:
  /// **'読み上げ({model}、プリセット音声) — サーバー未設定'**
  String vcRoomTtsDetailUnavailable(String model);

  /// 読み上げの声の選択肢
  ///
  /// In ja, this message translates to:
  /// **'読み上げなし'**
  String get vcRoomTtsNone;

  /// 読み上げの注記(オーナー)
  ///
  /// In ja, this message translates to:
  /// **'読み上げの声はサーバーで作ります(アプリでの再生は準備中)。'**
  String get vcRoomTtsCaptionOwner;

  /// 読み上げの注記(参加者)
  ///
  /// In ja, this message translates to:
  /// **'読み上げ音声はホストが選びます。'**
  String get vcRoomTtsCaptionGuest;

  /// 読み上げの注記(開発者モードの詳しい説明)
  ///
  /// In ja, this message translates to:
  /// **'チャットと共有の読み上げは Central 側で合成します(端末での再生は今後の対応)。'**
  String get vcRoomTtsCaptionOwnerDetail;

  /// ルームの設定の節の見出し(開発者モード)
  ///
  /// In ja, this message translates to:
  /// **'接続の状態(開発者向け)'**
  String get vcRoomDiagnosticsLabel;

  /// ルームの設定の行(開発者モード)
  ///
  /// In ja, this message translates to:
  /// **'通話 / 配信の接続を見る'**
  String get vcRoomDiagnosticsOpen;

  /// ルームの設定の行の補足(開発者モード)
  ///
  /// In ja, this message translates to:
  /// **'ICE の状態・候補・送受信の量・受けているトラック'**
  String get vcRoomDiagnosticsOpenSubtitle;

  /// 接続の状態のシートの見出し
  ///
  /// In ja, this message translates to:
  /// **'接続の状態'**
  String get vcRoomDiagnosticsTitle;

  /// ホストの配信の全画面の見出し。name はホストの表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} の配信'**
  String vcRoomHostStreamTitle(String name);

  /// まだ無い機能の名前(「〜 は準備中です」に入る)
  ///
  /// In ja, this message translates to:
  /// **'この投稿の表示(対応 SNS プラグインが未導入)'**
  String get vcRoomPostViewNotYet;

  /// 共有の操作のメニュー
  ///
  /// In ja, this message translates to:
  /// **'開く'**
  String get vcRoomOpen;

  /// 共有の操作のメニュー
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get vcRoomDelete;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'コピーしました'**
  String get vcRoomCopied;

  /// 通報シートの対象の名前。headline は共有の見出し
  ///
  /// In ja, this message translates to:
  /// **'共有「{headline}」'**
  String vcRoomReportWhatShare(String headline);

  /// 参加者の … メニュー(画面共有を共有枠に出す)
  ///
  /// In ja, this message translates to:
  /// **'共有枠に表示'**
  String get vcRoomPinToFrame;

  /// 参加者 / チャットの … メニュー
  ///
  /// In ja, this message translates to:
  /// **'フォロー解除'**
  String get vcRoomUnfollow;

  /// 参加者 / チャットの … メニュー
  ///
  /// In ja, this message translates to:
  /// **'フォロー'**
  String get vcRoomFollow;

  /// 参加者 / チャットの … メニュー、メンバー行のツールチップ
  ///
  /// In ja, this message translates to:
  /// **'ミュート解除'**
  String get vcRoomUnmute;

  /// 参加者 / チャットの … メニュー(モデレーター)
  ///
  /// In ja, this message translates to:
  /// **'全員向けミュートを解除'**
  String get vcRoomModUnmute;

  /// 参加者 / チャットの … メニュー(モデレーター)
  ///
  /// In ja, this message translates to:
  /// **'全員向けにミュート'**
  String get vcRoomModMute;

  /// 参加者 / チャットの … メニュー(モデレーター)
  ///
  /// In ja, this message translates to:
  /// **'キック'**
  String get vcRoomKick;

  /// 参加者の … メニュー(オーナー)
  ///
  /// In ja, this message translates to:
  /// **'モデレーターにする'**
  String get vcRoomMakeModerator;

  /// 参加者の … メニュー(モデレーター)
  ///
  /// In ja, this message translates to:
  /// **'発信傾向を見る(試験中)'**
  String get vcRoomShowTendency;

  /// 参加者 / チャットの … メニュー
  ///
  /// In ja, this message translates to:
  /// **'ブロック解除'**
  String get vcRoomUnblock;

  /// 参加者 / チャットの … メニュー
  ///
  /// In ja, this message translates to:
  /// **'ブロック'**
  String get vcRoomBlock;

  /// 参加者 / チャットの … メニュー、通報シートの見出し
  ///
  /// In ja, this message translates to:
  /// **'通報'**
  String get vcRoomReport;

  /// スナックバー。name は表示名、source は判定の出どころ、summary はラベルと割合の並び
  ///
  /// In ja, this message translates to:
  /// **'{name} の発信傾向({source}): {summary}'**
  String vcRoomTendencyResult(String name, String source, String summary);

  /// スナックバー(敵対的と判定)。name は表示名、source は判定の出どころ、summary はラベルと割合の並び
  ///
  /// In ja, this message translates to:
  /// **'{name} の発信傾向({source}): {summary} — 敵対的'**
  String vcRoomTendencyResultHostile(
    String name,
    String source,
    String summary,
  );

  /// スナックバー。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} のブロックを解除しました'**
  String vcRoomUnblocked(String name);

  /// スナックバー。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} をブロックしました(発言を隠し、あなたのルームには入れません)'**
  String vcRoomBlocked(String name);

  /// 操作の失敗のスナックバー。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'できませんでした: {error}'**
  String vcRoomActionFailed(String error);

  /// チャットの … メニュー / ピンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'共有欄にピン留め'**
  String get vcRoomPinToShares;

  /// 通報シートの対象の名前。name は発言者の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} の発言'**
  String vcRoomReportWhatChat(String name);

  /// ルームのホームのスイッチ / 作成画面のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'プレビューにざっくり要約を表示する'**
  String get vcRoomShowSummary;

  /// ルームのホームのスイッチ / 作成画面のスイッチ
  ///
  /// In ja, this message translates to:
  /// **'ジャンルを自動選択する'**
  String get vcRoomAutoGenre;

  /// ルームのホームの節の見出し(オーナー)
  ///
  /// In ja, this message translates to:
  /// **'自動選択されたジャンルを編集'**
  String get vcRoomEditAutoGenres;

  /// ルームのホームの節の見出し
  ///
  /// In ja, this message translates to:
  /// **'ジャンル'**
  String get vcRoomGenres;

  /// チャットのタブが空のとき
  ///
  /// In ja, this message translates to:
  /// **'話した内容の文字起こしと、チャット・共有がここに並びます。'**
  String get vcRoomChatEmpty;

  /// チャットのタブの注記。count は隠した数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{ブロック中のユーザーの発言 {count} 件を隠しています}}'**
  String vcRoomChatHiddenBlocked(int count);

  /// 下書きが空のときの表示
  ///
  /// In ja, this message translates to:
  /// **'入力中…'**
  String get vcRoomTyping;

  /// 自分の下書きの印
  ///
  /// In ja, this message translates to:
  /// **'下書き'**
  String get vcRoomDraft;

  /// ほかの人の下書きの印
  ///
  /// In ja, this message translates to:
  /// **'入力中'**
  String get vcRoomTypingLabel;

  /// チャット行の … のツールチップ
  ///
  /// In ja, this message translates to:
  /// **'チャットの操作'**
  String get vcRoomChatActions;

  /// 目次の最初の行。title はルームの名前
  ///
  /// In ja, this message translates to:
  /// **'開始: {title}'**
  String vcRoomTocStart(String title);

  /// 目次の共有の行。name は表示名、kind は共有の種別の id、headline は共有の見出し
  ///
  /// In ja, this message translates to:
  /// **'{name} が {kind} を共有: {headline}'**
  String vcRoomTocShared(String name, String kind, String headline);

  /// 目次のタブの注記
  ///
  /// In ja, this message translates to:
  /// **'共有と文字起こしの区切りです。'**
  String get vcRoomTocCaption;

  /// ルームのタブの節の見出し。count は人数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{参加メンバー({count})}}'**
  String vcRoomMembersWithCount(int count);

  /// メンバーの役割のピル
  ///
  /// In ja, this message translates to:
  /// **'モデレーター'**
  String get vcRoomModerator;

  /// ルームのタブの節の見出し
  ///
  /// In ja, this message translates to:
  /// **'カスタムプラグイン'**
  String get vcRoomCustomPlugins;

  /// スナックバー。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'設定を更新できませんでした: {error}'**
  String vcRoomUpdateFailed(String error);

  /// 下段の共有のボタン(ファイルを選んで共有)
  ///
  /// In ja, this message translates to:
  /// **'共有する'**
  String get vcRoomShareAction;

  /// 下段の送信のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'送信完了する'**
  String get vcRoomSendDone;

  /// stick の画面のツールチップ。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} の画面(タップで全画面)'**
  String vcRoomPeerScreenTap(String name);

  /// 共有枠が空のとき
  ///
  /// In ja, this message translates to:
  /// **'ピン留めした共有がここに出ます'**
  String get vcRoomPinnedSharesEmpty;

  /// 縮めたルームの最後の共有の行。headline は共有の見出し
  ///
  /// In ja, this message translates to:
  /// **'共有: {headline}'**
  String vcRoomCompactShare(String headline);

  /// 縮めたルームの字幕の行
  ///
  /// In ja, this message translates to:
  /// **'文字起こしはまだありません'**
  String get vcRoomNoTranscripts;

  /// 縮めたルームの字幕の行
  ///
  /// In ja, this message translates to:
  /// **'文字起こしは無効(要約非公開)'**
  String get vcRoomTranscriptsDisabled;

  /// 共有欄の開け閉めのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'共有を畳む'**
  String get vcRoomSharesCollapse;

  /// 共有欄の開け閉めのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'共有をすべて表示'**
  String get vcRoomSharesExpand;

  /// 共有の一覧の行の補足(ピン留め)。name は共有した人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} が共有 ・ 📌'**
  String vcRoomSharedByPinned(String name);

  /// 共有の一覧の行の補足(自動表示)。name は共有した人の表示名
  ///
  /// In ja, this message translates to:
  /// **'{name} が共有 ・ 自動表示'**
  String vcRoomSharedByAuto(String name);

  /// 文字起こしの一覧の行の補足(ピン留め)。name は話した人、time は時刻(HH:mm)
  ///
  /// In ja, this message translates to:
  /// **'{name} ・ {time} ・ 📌'**
  String vcRoomTranscriptMetaPinned(String name, String time);

  /// 文字起こしの一覧の行の補足(自動表示)。name は話した人、time は時刻(HH:mm)
  ///
  /// In ja, this message translates to:
  /// **'{name} ・ {time} ・ 自動表示'**
  String vcRoomTranscriptMetaAuto(String name, String time);

  /// 共有枠のピル
  ///
  /// In ja, this message translates to:
  /// **'ミュート中'**
  String get vcRoomMuted;

  /// 共有枠の … のツールチップ
  ///
  /// In ja, this message translates to:
  /// **'共有枠の操作'**
  String get vcRoomScreenFrameActions;

  /// メンバー行の自分の名前。name は表示名
  ///
  /// In ja, this message translates to:
  /// **'{name}(あなた)'**
  String vcRoomMemberSelf(String name);

  /// メンバー行のピル(モデレーターにミュートされた)
  ///
  /// In ja, this message translates to:
  /// **'強制ミュート'**
  String get vcRoomForceMuted;

  /// メンバー行の … のツールチップ
  ///
  /// In ja, this message translates to:
  /// **'メンバーの操作'**
  String get vcRoomMemberActions;

  /// 接続の状態のシートの注記(開発者向け)
  ///
  /// In ja, this message translates to:
  /// **'ブラウザ / Xcode のログにも「astell call:」「astell stream:」で出ます。'**
  String get vcRoomDiagnosticsLogHint;

  /// 接続の状態のシートのボタン
  ///
  /// In ja, this message translates to:
  /// **'コピー'**
  String get vcRoomCopy;

  /// ルームの設定の節の見出し。count は BAN の数
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{BAN({count})— メンバー行の「…」から}}'**
  String vcRoomBansLabel(int count);

  /// BAN 一覧の読み込みの失敗。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'BAN 一覧を読めませんでした: {error}'**
  String vcRoomBansLoadFailed(String error);

  /// BAN の行のボタンのツールチップ
  ///
  /// In ja, this message translates to:
  /// **'BAN を解除'**
  String get vcRoomUnban;

  /// 通報シートの本文。what は対象の名前(表示名 / ルーム「…」/ 共有「…」など)
  ///
  /// In ja, this message translates to:
  /// **'{what} を通報します。RASQ の審査で確認します。'**
  String vcRoomReportBody(String what);

  /// 通報シートの入力欄のヒント
  ///
  /// In ja, this message translates to:
  /// **'補足(任意)'**
  String get vcRoomReportNoteHint;

  /// スナックバー。error は失敗の内容
  ///
  /// In ja, this message translates to:
  /// **'通報できませんでした: {error}'**
  String vcRoomReportFailed(String error);

  /// 通報シートのボタン
  ///
  /// In ja, this message translates to:
  /// **'通報する'**
  String get vcRoomReportSubmit;

  /// スナックバー
  ///
  /// In ja, this message translates to:
  /// **'通報しました。審査で確認します'**
  String get vcRoomReported;

  /// 配信の帯の見出し。name はホストの表示名、kind は「画面共有」か「配信」
  ///
  /// In ja, this message translates to:
  /// **'{name} が{kind}中'**
  String vcRoomLiveBy(String name, String kind);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
