import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'rasq_design_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of RasqDesignLocalizations
/// returned by `RasqDesignLocalizations.of(context)`.
///
/// Applications need to include `RasqDesignLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/rasq_design_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: RasqDesignLocalizations.localizationsDelegates,
///   supportedLocales: RasqDesignLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the RasqDesignLocalizations.supportedLocales
/// property.
abstract class RasqDesignLocalizations {
  RasqDesignLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static RasqDesignLocalizations? of(BuildContext context) {
    return Localizations.of<RasqDesignLocalizations>(
      context,
      RasqDesignLocalizations,
    );
  }

  static const LocalizationsDelegate<RasqDesignLocalizations> delegate =
      _RasqDesignLocalizationsDelegate();

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

  /// No description provided for @designSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'検索'**
  String get designSearchHint;

  /// No description provided for @designFilterReset.
  ///
  /// In ja, this message translates to:
  /// **'リセット'**
  String get designFilterReset;

  /// No description provided for @designReplyParentSemantics.
  ///
  /// In ja, this message translates to:
  /// **'{name} のリプライ元投稿'**
  String designReplyParentSemantics(String name);

  /// No description provided for @designInlinePostSemantics.
  ///
  /// In ja, this message translates to:
  /// **'{name}の投稿(インラインフレーム)'**
  String designInlinePostSemantics(String name);

  /// No description provided for @designPostSemantics.
  ///
  /// In ja, this message translates to:
  /// **'{name}の投稿'**
  String designPostSemantics(String name);

  /// No description provided for @designFollowedBy.
  ///
  /// In ja, this message translates to:
  /// **'フォローされています'**
  String get designFollowedBy;

  /// No description provided for @designFollow.
  ///
  /// In ja, this message translates to:
  /// **'フォロー'**
  String get designFollow;

  /// No description provided for @designFollowing.
  ///
  /// In ja, this message translates to:
  /// **'フォロー中'**
  String get designFollowing;

  /// No description provided for @designFollowRequested.
  ///
  /// In ja, this message translates to:
  /// **'申請中'**
  String get designFollowRequested;

  /// No description provided for @designFollowers.
  ///
  /// In ja, this message translates to:
  /// **'フォロワー'**
  String get designFollowers;

  /// No description provided for @designMenu.
  ///
  /// In ja, this message translates to:
  /// **'メニュー'**
  String get designMenu;

  /// No description provided for @designContentWarningHide.
  ///
  /// In ja, this message translates to:
  /// **'隠す'**
  String get designContentWarningHide;

  /// No description provided for @designContentWarningShow.
  ///
  /// In ja, this message translates to:
  /// **'もっと見る'**
  String get designContentWarningShow;

  /// No description provided for @designMediaPlay.
  ///
  /// In ja, this message translates to:
  /// **'再生'**
  String get designMediaPlay;

  /// No description provided for @designMediaSensitive.
  ///
  /// In ja, this message translates to:
  /// **'センシティブな可能性のあるメディアです'**
  String get designMediaSensitive;

  /// No description provided for @designMediaReveal.
  ///
  /// In ja, this message translates to:
  /// **'表示する'**
  String get designMediaReveal;

  /// 全画面表示で、セーフモード / 見守り中のため出さないメディアの面(表示するボタンは無い)
  ///
  /// In ja, this message translates to:
  /// **'表示しない設定のメディアです'**
  String get designMediaHidden;

  /// No description provided for @designReactionMorePeople.
  ///
  /// In ja, this message translates to:
  /// **'+{count}人'**
  String designReactionMorePeople(int count);

  /// 範囲のスライダーの値(下限〜上限)。
  ///
  /// In ja, this message translates to:
  /// **'{start}〜{end}'**
  String designRangeValue(int start, int end);

  /// 名前を並べて読み上げるときの区切り。
  ///
  /// In ja, this message translates to:
  /// **'、'**
  String get designListSeparator;

  /// No description provided for @designThreadReplies.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}件の返信}}'**
  String designThreadReplies(int count);

  /// No description provided for @designRepostedBy.
  ///
  /// In ja, this message translates to:
  /// **'{name}がリノートしました'**
  String designRepostedBy(String name);

  /// No description provided for @designActionBarSemantics.
  ///
  /// In ja, this message translates to:
  /// **'アクションバー'**
  String get designActionBarSemantics;

  /// No description provided for @designRaiComingSoon.
  ///
  /// In ja, this message translates to:
  /// **'RAi(準備中)'**
  String get designRaiComingSoon;

  /// No description provided for @designVerifiedPerson.
  ///
  /// In ja, this message translates to:
  /// **'認証済み(個人)'**
  String get designVerifiedPerson;

  /// No description provided for @designVerifiedCompany.
  ///
  /// In ja, this message translates to:
  /// **'認証済み(法人)'**
  String get designVerifiedCompany;

  /// No description provided for @designVerifiedGovernment.
  ///
  /// In ja, this message translates to:
  /// **'認証済み(公的機関)'**
  String get designVerifiedGovernment;

  /// No description provided for @designExpandPost.
  ///
  /// In ja, this message translates to:
  /// **'展開する'**
  String get designExpandPost;

  /// No description provided for @designSortDefault.
  ///
  /// In ja, this message translates to:
  /// **'デフォルト'**
  String get designSortDefault;

  /// No description provided for @designSortReactionsDesc.
  ///
  /// In ja, this message translates to:
  /// **'リアクション数(降順)'**
  String get designSortReactionsDesc;

  /// No description provided for @designSortReactionsAsc.
  ///
  /// In ja, this message translates to:
  /// **'リアクション数(昇順)'**
  String get designSortReactionsAsc;

  /// No description provided for @designProfileBanner.
  ///
  /// In ja, this message translates to:
  /// **'バナー画像'**
  String get designProfileBanner;

  /// No description provided for @designProfileEdit.
  ///
  /// In ja, this message translates to:
  /// **'編集する'**
  String get designProfileEdit;

  /// No description provided for @designProfileNotifications.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get designProfileNotifications;

  /// No description provided for @designProfileRestricted.
  ///
  /// In ja, this message translates to:
  /// **'このユーザーは制限されています。'**
  String get designProfileRestricted;

  /// No description provided for @designProfileRestrictedShow.
  ///
  /// In ja, this message translates to:
  /// **'表示'**
  String get designProfileRestrictedShow;

  /// {date} = 登録した年月(例: 2017年2月)。
  ///
  /// In ja, this message translates to:
  /// **'{date}に登録'**
  String designProfileJoined(String date);

  /// No description provided for @designProfileNotes.
  ///
  /// In ja, this message translates to:
  /// **'{count} ノート'**
  String designProfileNotes(String count);

  /// No description provided for @designPollVote.
  ///
  /// In ja, this message translates to:
  /// **'投票'**
  String get designPollVote;

  /// No description provided for @designPollSubmit.
  ///
  /// In ja, this message translates to:
  /// **'投票する'**
  String get designPollSubmit;

  /// No description provided for @designPollVotes.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}票}}'**
  String designPollVotes(int count);

  /// No description provided for @designPollEnded.
  ///
  /// In ja, this message translates to:
  /// **'終了'**
  String get designPollEnded;

  /// No description provided for @designPollVoted.
  ///
  /// In ja, this message translates to:
  /// **' 投票済み'**
  String get designPollVoted;

  /// No description provided for @designTimeEnded.
  ///
  /// In ja, this message translates to:
  /// **'終了'**
  String get designTimeEnded;

  /// No description provided for @designTimeRemainingDays.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{残り {count}日}}'**
  String designTimeRemainingDays(int count);

  /// No description provided for @designTimeRemainingHours.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{残り {count}時間}}'**
  String designTimeRemainingHours(int count);

  /// No description provided for @designTimeRemainingMinutes.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{残り {count}分}}'**
  String designTimeRemainingMinutes(int count);

  /// No description provided for @designTimeRemainingSeconds.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{残り {count}秒}}'**
  String designTimeRemainingSeconds(int count);

  /// No description provided for @designTimeJustNow.
  ///
  /// In ja, this message translates to:
  /// **'たった今'**
  String get designTimeJustNow;

  /// No description provided for @designTimeMinutesAgo.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}分前}}'**
  String designTimeMinutesAgo(int count);

  /// No description provided for @designTimeHoursAgo.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}時間前}}'**
  String designTimeHoursAgo(int count);

  /// No description provided for @designTimeDaysAgo.
  ///
  /// In ja, this message translates to:
  /// **'{count, plural, other{{count}日前}}'**
  String designTimeDaysAgo(int count);

  /// No description provided for @designErrorRetry.
  ///
  /// In ja, this message translates to:
  /// **'見てみる'**
  String get designErrorRetry;
}

class _RasqDesignLocalizationsDelegate
    extends LocalizationsDelegate<RasqDesignLocalizations> {
  const _RasqDesignLocalizationsDelegate();

  @override
  Future<RasqDesignLocalizations> load(Locale locale) {
    return SynchronousFuture<RasqDesignLocalizations>(
      lookupRasqDesignLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_RasqDesignLocalizationsDelegate old) => false;
}

RasqDesignLocalizations lookupRasqDesignLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ja':
      return RasqDesignLocalizationsJa();
  }

  throw FlutterError(
    'RasqDesignLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
