// tool/l10n_merge.dart が部品(parts)から作る(手で直さない)。言語パックの上書きの層 (D-592、docs/I18N.md「言語パック」)。
// ignore_for_file: type=lint

import 'package:rasq_models/rasq_models.dart' show RasqLangOverride;

import 'gen/rasq_design_localizations.dart';

/// 言語パック (D-592) の上書きを先に引く [RasqDesignLocalizations]。上書きの無いキー・壊れていて捨てたキーは [base](同梱)の文言。
/// 引く先は `RasqLangOverride.text(localeName, 'rasq_design', キー, 引数)`。
class RasqDesignLocalizationsOverlay extends RasqDesignLocalizations {
  RasqDesignLocalizationsOverlay(this.base, [String? localeName]) : super(localeName ?? base.localeName);

  /// 同梱の文言(上書きが無いときに使う)。
  final RasqDesignLocalizations base;

  /// 言語パックの中の領域の名前。
  static const domain = 'rasq_design';

  /// キー → 使えるプレースホルダ(言語パックを読み込むときの検証に使う)。
  static const placeholders = <String, List<String>>{
    'designActionBarSemantics': [],
    'designContentWarningHide': [],
    'designContentWarningShow': [],
    'designErrorRetry': [],
    'designExpandPost': [],
    'designFilterReset': [],
    'designFollow': [],
    'designFollowRequested': [],
    'designFollowedBy': [],
    'designFollowers': [],
    'designFollowing': [],
    'designInlinePostSemantics': ['name'],
    'designListSeparator': [],
    'designMediaHidden': [],
    'designMediaPlay': [],
    'designMediaReveal': [],
    'designMediaSensitive': [],
    'designMenu': [],
    'designOverlayCancel': [],
    'designOverlayClose': [],
    'designOverlayResizeHandle': [],
    'designOverlaySwitcher': [],
    'designPollEnded': [],
    'designPollSubmit': [],
    'designPollVote': [],
    'designPollVoted': [],
    'designPollVotes': ['count'],
    'designPostSemantics': ['name'],
    'designProfileBanner': [],
    'designProfileCountFollowersOnly': [],
    'designProfileCountPrivate': [],
    'designProfileEdit': [],
    'designProfileJoined': ['date'],
    'designProfileNotes': ['count'],
    'designProfileNotifications': [],
    'designProfileRestricted': [],
    'designProfileRestrictedShow': [],
    'designRaiComingSoon': [],
    'designRangeValue': ['start', 'end'],
    'designReactionMorePeople': ['count'],
    'designReplyParentSemantics': ['name'],
    'designRepostedBy': ['name'],
    'designRrlNoAuthFlow': ['pluginId'],
    'designRrlRange': ['start', 'end', 'unit'],
    'designRrlSend': [],
    'designSearchHint': [],
    'designSortDefault': [],
    'designSortReactionsAsc': [],
    'designSortReactionsDesc': [],
    'designThreadReplies': ['count'],
    'designTimeDaysAgo': ['count'],
    'designTimeEnded': [],
    'designTimeHoursAgo': ['count'],
    'designTimeJustNow': [],
    'designTimeMinutesAgo': ['count'],
    'designTimeRemainingDays': ['count'],
    'designTimeRemainingHours': ['count'],
    'designTimeRemainingMinutes': ['count'],
    'designTimeRemainingSeconds': ['count'],
    'designVerifiedCompany': [],
    'designVerifiedGovernment': [],
    'designVerifiedPerson': [],
  };

  @override
  String get designActionBarSemantics => RasqLangOverride.text(localeName, domain, 'designActionBarSemantics') ?? base.designActionBarSemantics;

  @override
  String get designContentWarningHide => RasqLangOverride.text(localeName, domain, 'designContentWarningHide') ?? base.designContentWarningHide;

  @override
  String get designContentWarningShow => RasqLangOverride.text(localeName, domain, 'designContentWarningShow') ?? base.designContentWarningShow;

  @override
  String get designErrorRetry => RasqLangOverride.text(localeName, domain, 'designErrorRetry') ?? base.designErrorRetry;

  @override
  String get designExpandPost => RasqLangOverride.text(localeName, domain, 'designExpandPost') ?? base.designExpandPost;

  @override
  String get designFilterReset => RasqLangOverride.text(localeName, domain, 'designFilterReset') ?? base.designFilterReset;

  @override
  String get designFollow => RasqLangOverride.text(localeName, domain, 'designFollow') ?? base.designFollow;

  @override
  String get designFollowRequested => RasqLangOverride.text(localeName, domain, 'designFollowRequested') ?? base.designFollowRequested;

  @override
  String get designFollowedBy => RasqLangOverride.text(localeName, domain, 'designFollowedBy') ?? base.designFollowedBy;

  @override
  String get designFollowers => RasqLangOverride.text(localeName, domain, 'designFollowers') ?? base.designFollowers;

  @override
  String get designFollowing => RasqLangOverride.text(localeName, domain, 'designFollowing') ?? base.designFollowing;

  @override
  String designInlinePostSemantics(String name) => RasqLangOverride.text(localeName, domain, 'designInlinePostSemantics', {'name': name}) ?? base.designInlinePostSemantics(name);

  @override
  String get designListSeparator => RasqLangOverride.text(localeName, domain, 'designListSeparator') ?? base.designListSeparator;

  @override
  String get designMediaHidden => RasqLangOverride.text(localeName, domain, 'designMediaHidden') ?? base.designMediaHidden;

  @override
  String get designMediaPlay => RasqLangOverride.text(localeName, domain, 'designMediaPlay') ?? base.designMediaPlay;

  @override
  String get designMediaReveal => RasqLangOverride.text(localeName, domain, 'designMediaReveal') ?? base.designMediaReveal;

  @override
  String get designMediaSensitive => RasqLangOverride.text(localeName, domain, 'designMediaSensitive') ?? base.designMediaSensitive;

  @override
  String get designMenu => RasqLangOverride.text(localeName, domain, 'designMenu') ?? base.designMenu;

  @override
  String get designOverlayCancel => RasqLangOverride.text(localeName, domain, 'designOverlayCancel') ?? base.designOverlayCancel;

  @override
  String get designOverlayClose => RasqLangOverride.text(localeName, domain, 'designOverlayClose') ?? base.designOverlayClose;

  @override
  String get designOverlayResizeHandle => RasqLangOverride.text(localeName, domain, 'designOverlayResizeHandle') ?? base.designOverlayResizeHandle;

  @override
  String get designOverlaySwitcher => RasqLangOverride.text(localeName, domain, 'designOverlaySwitcher') ?? base.designOverlaySwitcher;

  @override
  String get designPollEnded => RasqLangOverride.text(localeName, domain, 'designPollEnded') ?? base.designPollEnded;

  @override
  String get designPollSubmit => RasqLangOverride.text(localeName, domain, 'designPollSubmit') ?? base.designPollSubmit;

  @override
  String get designPollVote => RasqLangOverride.text(localeName, domain, 'designPollVote') ?? base.designPollVote;

  @override
  String get designPollVoted => RasqLangOverride.text(localeName, domain, 'designPollVoted') ?? base.designPollVoted;

  @override
  String designPollVotes(int count) => RasqLangOverride.text(localeName, domain, 'designPollVotes', {'count': count}) ?? base.designPollVotes(count);

  @override
  String designPostSemantics(String name) => RasqLangOverride.text(localeName, domain, 'designPostSemantics', {'name': name}) ?? base.designPostSemantics(name);

  @override
  String get designProfileBanner => RasqLangOverride.text(localeName, domain, 'designProfileBanner') ?? base.designProfileBanner;

  @override
  String get designProfileCountFollowersOnly => RasqLangOverride.text(localeName, domain, 'designProfileCountFollowersOnly') ?? base.designProfileCountFollowersOnly;

  @override
  String get designProfileCountPrivate => RasqLangOverride.text(localeName, domain, 'designProfileCountPrivate') ?? base.designProfileCountPrivate;

  @override
  String get designProfileEdit => RasqLangOverride.text(localeName, domain, 'designProfileEdit') ?? base.designProfileEdit;

  @override
  String designProfileJoined(String date) => RasqLangOverride.text(localeName, domain, 'designProfileJoined', {'date': date}) ?? base.designProfileJoined(date);

  @override
  String designProfileNotes(String count) => RasqLangOverride.text(localeName, domain, 'designProfileNotes', {'count': count}) ?? base.designProfileNotes(count);

  @override
  String get designProfileNotifications => RasqLangOverride.text(localeName, domain, 'designProfileNotifications') ?? base.designProfileNotifications;

  @override
  String get designProfileRestricted => RasqLangOverride.text(localeName, domain, 'designProfileRestricted') ?? base.designProfileRestricted;

  @override
  String get designProfileRestrictedShow => RasqLangOverride.text(localeName, domain, 'designProfileRestrictedShow') ?? base.designProfileRestrictedShow;

  @override
  String get designRaiComingSoon => RasqLangOverride.text(localeName, domain, 'designRaiComingSoon') ?? base.designRaiComingSoon;

  @override
  String designRangeValue(int start, int end) => RasqLangOverride.text(localeName, domain, 'designRangeValue', {'start': start, 'end': end}) ?? base.designRangeValue(start, end);

  @override
  String designReactionMorePeople(int count) => RasqLangOverride.text(localeName, domain, 'designReactionMorePeople', {'count': count}) ?? base.designReactionMorePeople(count);

  @override
  String designReplyParentSemantics(String name) => RasqLangOverride.text(localeName, domain, 'designReplyParentSemantics', {'name': name}) ?? base.designReplyParentSemantics(name);

  @override
  String designRepostedBy(String name) => RasqLangOverride.text(localeName, domain, 'designRepostedBy', {'name': name}) ?? base.designRepostedBy(name);

  @override
  String designRrlNoAuthFlow(String pluginId) => RasqLangOverride.text(localeName, domain, 'designRrlNoAuthFlow', {'pluginId': pluginId}) ?? base.designRrlNoAuthFlow(pluginId);

  @override
  String designRrlRange(int start, int end, String unit) => RasqLangOverride.text(localeName, domain, 'designRrlRange', {'start': start, 'end': end, 'unit': unit}) ?? base.designRrlRange(start, end, unit);

  @override
  String get designRrlSend => RasqLangOverride.text(localeName, domain, 'designRrlSend') ?? base.designRrlSend;

  @override
  String get designSearchHint => RasqLangOverride.text(localeName, domain, 'designSearchHint') ?? base.designSearchHint;

  @override
  String get designSortDefault => RasqLangOverride.text(localeName, domain, 'designSortDefault') ?? base.designSortDefault;

  @override
  String get designSortReactionsAsc => RasqLangOverride.text(localeName, domain, 'designSortReactionsAsc') ?? base.designSortReactionsAsc;

  @override
  String get designSortReactionsDesc => RasqLangOverride.text(localeName, domain, 'designSortReactionsDesc') ?? base.designSortReactionsDesc;

  @override
  String designThreadReplies(int count) => RasqLangOverride.text(localeName, domain, 'designThreadReplies', {'count': count}) ?? base.designThreadReplies(count);

  @override
  String designTimeDaysAgo(int count) => RasqLangOverride.text(localeName, domain, 'designTimeDaysAgo', {'count': count}) ?? base.designTimeDaysAgo(count);

  @override
  String get designTimeEnded => RasqLangOverride.text(localeName, domain, 'designTimeEnded') ?? base.designTimeEnded;

  @override
  String designTimeHoursAgo(int count) => RasqLangOverride.text(localeName, domain, 'designTimeHoursAgo', {'count': count}) ?? base.designTimeHoursAgo(count);

  @override
  String get designTimeJustNow => RasqLangOverride.text(localeName, domain, 'designTimeJustNow') ?? base.designTimeJustNow;

  @override
  String designTimeMinutesAgo(int count) => RasqLangOverride.text(localeName, domain, 'designTimeMinutesAgo', {'count': count}) ?? base.designTimeMinutesAgo(count);

  @override
  String designTimeRemainingDays(int count) => RasqLangOverride.text(localeName, domain, 'designTimeRemainingDays', {'count': count}) ?? base.designTimeRemainingDays(count);

  @override
  String designTimeRemainingHours(int count) => RasqLangOverride.text(localeName, domain, 'designTimeRemainingHours', {'count': count}) ?? base.designTimeRemainingHours(count);

  @override
  String designTimeRemainingMinutes(int count) => RasqLangOverride.text(localeName, domain, 'designTimeRemainingMinutes', {'count': count}) ?? base.designTimeRemainingMinutes(count);

  @override
  String designTimeRemainingSeconds(int count) => RasqLangOverride.text(localeName, domain, 'designTimeRemainingSeconds', {'count': count}) ?? base.designTimeRemainingSeconds(count);

  @override
  String get designVerifiedCompany => RasqLangOverride.text(localeName, domain, 'designVerifiedCompany') ?? base.designVerifiedCompany;

  @override
  String get designVerifiedGovernment => RasqLangOverride.text(localeName, domain, 'designVerifiedGovernment') ?? base.designVerifiedGovernment;

  @override
  String get designVerifiedPerson => RasqLangOverride.text(localeName, domain, 'designVerifiedPerson') ?? base.designVerifiedPerson;
}
