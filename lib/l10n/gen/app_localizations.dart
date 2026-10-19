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
