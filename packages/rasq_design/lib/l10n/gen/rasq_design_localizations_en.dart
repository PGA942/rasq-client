// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'rasq_design_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class RasqDesignLocalizationsEn extends RasqDesignLocalizations {
  RasqDesignLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get designSearchHint => 'Search';

  @override
  String get designFilterReset => 'Reset';

  @override
  String designReplyParentSemantics(String name) {
    return 'Post by $name being replied to';
  }

  @override
  String designInlinePostSemantics(String name) {
    return 'Post by $name (inline frame)';
  }

  @override
  String designPostSemantics(String name) {
    return 'Post by $name';
  }

  @override
  String get designFollowedBy => 'Follows you';

  @override
  String get designFollow => 'Follow';

  @override
  String get designFollowing => 'Following';

  @override
  String get designFollowRequested => 'Requested';

  @override
  String get designFollowers => 'Followers';

  @override
  String get designMenu => 'Menu';

  @override
  String get designContentWarningHide => 'Hide';

  @override
  String get designContentWarningShow => 'Show more';

  @override
  String get designMediaPlay => 'Play';

  @override
  String get designMediaSensitive => 'This media may be sensitive';

  @override
  String get designMediaReveal => 'Show';

  @override
  String get designMediaHidden => 'This media is hidden by your settings';

  @override
  String designReactionMorePeople(int count) {
    return '+$count';
  }

  @override
  String designRangeValue(int start, int end) {
    return '$start–$end';
  }

  @override
  String get designListSeparator => ', ';

  @override
  String designThreadReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String designRepostedBy(String name) {
    return '$name renoted';
  }

  @override
  String get designActionBarSemantics => 'Action bar';

  @override
  String get designRaiComingSoon => 'RAi (coming soon)';

  @override
  String get designVerifiedPerson => 'Verified (individual)';

  @override
  String get designVerifiedCompany => 'Verified (organization)';

  @override
  String get designVerifiedGovernment => 'Verified (public institution)';

  @override
  String get designExpandPost => 'Expand';

  @override
  String get designSortDefault => 'Default';

  @override
  String get designSortReactionsDesc => 'Reactions (most first)';

  @override
  String get designSortReactionsAsc => 'Reactions (fewest first)';

  @override
  String get designProfileBanner => 'Banner image';

  @override
  String get designProfileEdit => 'Edit';

  @override
  String get designProfileNotifications => 'Notifications';

  @override
  String get designProfileRestricted => 'This user is restricted.';

  @override
  String get designProfileRestrictedShow => 'Show';

  @override
  String designProfileJoined(String date) {
    return 'Joined $date';
  }

  @override
  String designProfileNotes(String count) {
    return '$count notes';
  }

  @override
  String get designPollVote => 'Vote';

  @override
  String get designPollSubmit => 'Vote';

  @override
  String designPollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String get designPollEnded => 'Ended';

  @override
  String get designPollVoted => ' Voted';

  @override
  String get designTimeEnded => 'Ended';

  @override
  String designTimeRemainingDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours left',
      one: '1 hour left',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes left',
      one: '1 minute left',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds left',
      one: '1 second left',
    );
    return '$_temp0';
  }

  @override
  String get designTimeJustNow => 'Just now';

  @override
  String designTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String designTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String designTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get designErrorRetry => 'Try again';

  @override
  String get designOverlayCancel => 'Cancel';

  @override
  String get designOverlayClose => 'Close';

  @override
  String get designOverlaySwitcher => 'Switch FOW';

  @override
  String get designOverlayResizeHandle => 'Resize handle';

  @override
  String designRrlRange(int start, int end, String unit) {
    return '$start–$end$unit';
  }

  @override
  String get designRrlSend => 'Send';

  @override
  String designRrlNoAuthFlow(String pluginId) {
    return '$pluginId: No sign-in flow is configured (only registration with an existing token is supported)';
  }
}
