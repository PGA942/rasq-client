// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get adsShowLess => 'Show less often';

  @override
  String get adsShowLessDone => 'You\'ll see this ad less often';

  @override
  String get adsLabel => 'Ad';

  @override
  String adsLabelWithHost(String host) {
    return 'Ad · $host';
  }

  @override
  String get adsMenu => 'Ad menu';

  @override
  String get adsOpen => 'Open ad';

  @override
  String get appNavPostTitle => 'Post';

  @override
  String get appNavReactionsTitle => 'Reactions';

  @override
  String get appNavFollowersTitle => 'Followers';

  @override
  String get appNavFollowingTitle => 'Following';

  @override
  String get appNavShortcutSearch => 'Search';

  @override
  String get appNavShortcutNewPost => 'New post';

  @override
  String get appNavShortcutNewMessage => 'New message';

  @override
  String get appNavShortcutAskRai => 'Search with RAi';

  @override
  String get appNavShortcutGuardianPending =>
      'Unavailable until your guardian finishes the settings';

  @override
  String get appNavShortcutLoginHint => 'Log in to an SNS account to use this';

  @override
  String get backendOauthNoToken => 'Couldn\'t get an access token';

  @override
  String backendOauthServerRequired(String service) {
    return 'Logging in to $service requires a RASQ server. Set the server in Settings → \"RASQ server\".';
  }

  @override
  String get backendOauthNoUrl => 'Couldn\'t get the authorization URL';

  @override
  String get backendOauthHint =>
      'After you allow access in the browser, come back to the app and tap \"Check authentication\".';

  @override
  String backendResponseTooLarge(int maxBytes) {
    return 'Response too large (over $maxBytes bytes)';
  }

  @override
  String get backendSecurityPasswordlessRemoved =>
      'Login with only an email code is no longer available. Log in with your handle (or email) and password';

  @override
  String get backendSecuritySecondFactor =>
      'Enter the verification code sent to your email';

  @override
  String get backendSecurityTooMany =>
      'Too many attempts. Wait a while and try again';

  @override
  String get backendSecurityNoMail => 'This server isn\'t set up to send email';

  @override
  String get backendSecurityEmailUsed =>
      'This email address is used by another account';

  @override
  String get backendSecurityBadCredentials =>
      'Incorrect handle (email) or password';

  @override
  String get backendSecurityBadCode => 'The code is wrong or has expired';

  @override
  String get backendSecurityWeakPassword =>
      'This password is too weak (common passwords, repeated characters, or ones matching your handle or email can\'t be used)';

  @override
  String get backendSecurityShortPassword =>
      'Password must be at least 8 characters';

  @override
  String get backendSecurityBadEmail => 'Invalid email address format';

  @override
  String get backendSecurityWrongPassword =>
      'Your current password is incorrect';

  @override
  String get backendSecurityNoPassword =>
      'This account has no password. Verify with a code sent to your current email';

  @override
  String get backendSecurityConfirmRequired =>
      'This action requires your current password or a verification code sent to your current email';

  @override
  String get backendRoomClosed =>
      'Couldn\'t join the room (it\'s closed or not found)';

  @override
  String get backendRoomForbidden =>
      'Couldn\'t join the room (this account can\'t participate)';

  @override
  String backendRoomConnectFailed(String error) {
    return 'Couldn\'t connect to the room: $error';
  }

  @override
  String get backendPaidFeaturesDisabled =>
      'Paid plugins aren\'t available during the public test';

  @override
  String get backendAgeTeen => '13–15 years old';

  @override
  String get backendAgeUpperTeen => '16–17 years old';

  @override
  String get backendAgeAdult => '18 or older';

  @override
  String get backendNoToken => 'ORGATE didn\'t return a token';

  @override
  String get backendTileAuto => 'Auto';

  @override
  String get backendTileShow => 'Show';

  @override
  String get backendTileHide => 'Hide';

  @override
  String get backendVerifiedKeybase => 'Verified with Keybase proof';

  @override
  String get backendVerifiedProfile => 'Verified via profile';

  @override
  String get backendAudioFileName => 'Audio';

  @override
  String get backendServerNotConfigured => 'RASQ server address is not set';

  @override
  String backendServerError(int status) {
    return 'Server error ($status)';
  }

  @override
  String get backendCollectionList => 'List';

  @override
  String get backendCollectionClip => 'Clip';

  @override
  String get bookmarksRemoved => 'Bookmark removed';

  @override
  String bookmarksRemoveFailed(String error) {
    return 'Couldn\'t remove: $error';
  }

  @override
  String get bookmarksTitle => 'Bookmarks';

  @override
  String get bookmarksRetry => 'Reload';

  @override
  String get bookmarksEmptyTitle => 'No bookmarks';

  @override
  String get bookmarksEmptyHint =>
      'Collect posts with 🔖 on a post, Add to clip, or ASTell bookmarks';

  @override
  String get bookmarksEmptyNoSnsHint =>
      'This service has no bookmarks. Long-press 🔖 on a post to collect it in a RASQ clip';

  @override
  String get bookmarksClips => 'Clips';

  @override
  String bookmarksClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get bookmarksClipHost => 'RASQ (cross-SNS)';

  @override
  String get bookmarksClipPrivate => 'Private clip';

  @override
  String get bookmarksSeparator => ' · ';

  @override
  String get bookmarksFavorites => 'Favorites';

  @override
  String get bookmarksSwipeRemove => 'Remove';

  @override
  String get bookmarksRemove => 'Remove bookmark';

  @override
  String get catalogTitle => 'Component catalog';

  @override
  String get catalogSectionBrand => 'Brand (special components)';

  @override
  String get catalogSectionPostTile =>
      'PostTile — standard (action bar / poll / media)';

  @override
  String get catalogSectionPostTileEmbedded =>
      'PostTile — embedded (quote / reaction display / timer notification) & thread summary';

  @override
  String get catalogSectionCollapsed =>
      'CollapsedPost (collapsed: read + long text)';

  @override
  String get catalogSectionPoll =>
      'PollWidget (not voted single / multiple, voted, expired)';

  @override
  String get catalogSectionActionBar =>
      'ActionBar (spread / leading = composer toolbar)';

  @override
  String get catalogSectionRrl =>
      'RRL renderer (post-tile.rrl.json → L1/L2/L3)';

  @override
  String get catalogSheetTitle => 'Bottom sheet';

  @override
  String get catalogSheetConfirm => 'Done';

  @override
  String get catalogSheetBody =>
      'Tap the background or Cancel to discard changes.\nA modal can appear on top of this.';

  @override
  String get catalogAlertTitle => 'Block?';

  @override
  String get catalogAlertMessage =>
      'Tapping the background does nothing (explicit action required)';

  @override
  String get catalogAlertConfirm => 'Block';

  @override
  String get catalogAlertCancel => 'Cancel';

  @override
  String get catalogDropdownAsc => 'Ascending';

  @override
  String get catalogDropdownDesc => 'Descending';

  @override
  String get catalogDropdownDefault => 'Default';

  @override
  String get catalogDropdownReport => 'Report';

  @override
  String get catalogSheetModalTitle => 'Sheet → modal overlay';

  @override
  String get catalogModalTitle => 'Modal';

  @override
  String get catalogModalMessage => 'The sheet stays open';

  @override
  String get catalogModalOpen => 'Show modal';

  @override
  String get childSafeLevelStrict => 'Strict';

  @override
  String get childSafeLevelStandard => 'Standard';

  @override
  String get childSafeLevelMild => 'Lenient';

  @override
  String get childSafeTopicModeAllow => 'Allowlist';

  @override
  String get childSafeTopicModeDeny => 'Blocklist';

  @override
  String get childSafeInstallNone => 'Not allowed';

  @override
  String get childSafeInstallListed => 'Selected only';

  @override
  String get childSafeInstallAny => 'Unrestricted';

  @override
  String get childSafeInstallExamples => 'Similar to examples';

  @override
  String get childSafeEmptyWhitelistError =>
      'The allowlist is empty. Add at least one topic, or switch to a blocklist';

  @override
  String get childSafeMethodJpki => 'My Number Card (JPKI)';

  @override
  String get childSafeMethodSelfDeclared => 'Self-declared';

  @override
  String get childSafeErrorCodeInvalid => 'The code is wrong or has expired';

  @override
  String get childSafeErrorHandleTaken => 'That handle is already taken';

  @override
  String get childSafeErrorAlreadyLinked =>
      'This account is already supervised (or supervising someone)';

  @override
  String get childSafeErrorCodeGone =>
      'The code has expired or was already used. Ask your guardian to issue a new one';

  @override
  String get childSafeErrorDevice => 'You can\'t log in on this device';

  @override
  String get childSafeErrorTooMany =>
      'Too many attempts. Wait a while and try again';

  @override
  String get childSafeNoServer => 'RASQ server address is not set';

  @override
  String childSafeNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' (+$count more)',
      one: ' (+1 more)',
    );
    return '$_temp0';
  }

  @override
  String get childSafeNoticeRefreshed =>
      'Child Safe: Reloaded guardian settings';

  @override
  String get childSafeNoticeView => 'View';

  @override
  String get childSafeBlocked => 'Blocked by your guardian';

  @override
  String childSafeBlockedWith(String label) {
    return 'Blocked by your guardian ($label)';
  }

  @override
  String childSafeTimeRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String get childSafeLockedUntilSetup =>
      'Unavailable until your guardian finishes the settings';

  @override
  String childSafeWindowNoDm(String window) {
    return 'DMs aren\'t available during supervised hours ($window)';
  }

  @override
  String get childSafeBlockedAstell => 'Your guardian has blocked ASTell';

  @override
  String childSafeWindowNoAstell(String window) {
    return 'ASTell isn\'t available during supervised hours ($window)';
  }

  @override
  String get childSafeBlockedDm => 'Your guardian has blocked DMs';

  @override
  String childSafeWindowNoNotifications(String window) {
    return 'Notifications can\'t be viewed during supervised hours ($window)';
  }

  @override
  String get childSafeBlockedRai => 'Your guardian has blocked RAi';

  @override
  String get childSafeBlockedStore =>
      'Your guardian has blocked the Plugin Store';

  @override
  String get childSafeBlockedSearch => 'Your guardian has blocked search';

  @override
  String get childSafeBlockedAddAccount =>
      'Your guardian has blocked adding SNS accounts';

  @override
  String get childSafeBlockedCustomPlugins =>
      'Your guardian has blocked custom plugins';

  @override
  String get childSafeBlockedPlugins => 'Your guardian has blocked plugins';

  @override
  String childSafeWindowNoPostDetail(String window) {
    return 'Post details can\'t be opened during supervised hours ($window)';
  }

  @override
  String get childSafePostHidden => 'This post can\'t be shown';

  @override
  String get childSafeListSeparator => ', ';

  @override
  String childSafeBullet(String text) {
    return '• $text';
  }

  @override
  String childSafeTopicsEtc(String topics) {
    return '$topics, etc.';
  }

  @override
  String get childSafeComposeNoTopicsAllowed =>
      'Your guardian\'s settings don\'t allow posting right now';

  @override
  String childSafeComposeTopicsOnly(String topics) {
    return 'Your guardian\'s settings only allow posts on certain topics ($topics). Please write to fit those topics';
  }

  @override
  String childSafeComposeTopicDenied(String topic) {
    return 'Your guardian\'s settings don\'t allow posts on \"$topic\". Please rewrite it';
  }

  @override
  String childSafeQuoted(String text) {
    return '\"$text\"';
  }

  @override
  String childSafeComposeStimulus(String level, String word) {
    return 'Your guardian\'s settings ($level) don\'t allow this expression$word. Please rephrase it';
  }

  @override
  String get childSafeBlockedThisPlugin =>
      'Your guardian has blocked this plugin';

  @override
  String get childSafeDevPreviewUnknown =>
      'Only plugins your guardian selected can run (this loading method can\'t identify the plugin)';

  @override
  String get childSafeBlockedInstall =>
      'Your guardian has blocked plugin installation';

  @override
  String get childSafeNearDenyPlugin =>
      'This plugin is similar to examples your guardian has blocked';

  @override
  String get childSafeInstallListedOnly =>
      'Only plugins your guardian selected can be installed';

  @override
  String get childSafeInstallExamplesOnly =>
      'Only plugins your guardian selected, or similar to allowed examples, can be installed';

  @override
  String get childSafeCacheUnverified =>
      'Can\'t verify the signature of the saved restrictions. Please reload them online';

  @override
  String get childSafeNewSettingsUnverified =>
      'Couldn\'t verify the signature of your guardian\'s new settings (keeping the previous settings)';

  @override
  String get childSafeComposeLocked =>
      'Can\'t post until your guardian finishes setup';

  @override
  String childSafeComposeDailyLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You\'ve already sent $count posts today (your guardian\'s daily limit). Try again tomorrow',
      one: 'You\'ve already sent 1 post today (your guardian\'s daily limit). Try again tomorrow',
    );
    return '$_temp0';
  }

  @override
  String childSafeComposeAfterTransform(String message) {
    return '$message (text after pre-send processing)';
  }

  @override
  String get childSafeStatePending => 'Awaiting setup';

  @override
  String get childSafeWatchAsGuardian => 'Supervise (guardian)';

  @override
  String get childSafeLoginWithCode => 'Log in with a code from your guardian';

  @override
  String get childSafeChildMode => 'Child mode';

  @override
  String get childSafeGuardianStateApplied =>
      'Supervising (delivered to device)';

  @override
  String childSafeGuardianStateNotApplied(int revision) {
    return 'Supervising (settings $revision not yet delivered to device)';
  }

  @override
  String childSafeGuardianPledgeTitle(String version) {
    return 'Guardian pledge (version $version)';
  }

  @override
  String childSafeGuardianPledgeMessage(String pledge) {
    return '$pledge\n\nIf you agree, you\'ll proceed to verification with your My Number Card (Digital Authentication App) (for residents of Japan).';
  }

  @override
  String get childSafeGuardianPledgeConfirm => 'Agree and continue';

  @override
  String get childSafeGuardianCancel => 'Cancel';

  @override
  String get childSafeGuardianLoadError => 'Couldn\'t load';

  @override
  String get childSafeGuardianReload => 'Reload';

  @override
  String get childSafeGuardianVerifySection => 'Guardian verification';

  @override
  String get childSafeGuardianVerified => 'Verified';

  @override
  String get childSafeGuardianNotVerified => 'Not verified yet';

  @override
  String get childSafeGuardianVerifyIntro =>
      'Before creating or linking a child account, verify that you are a guardian (in Japan, with a My Number Card).';

  @override
  String get childSafeGuardianVerifyIntroDetail =>
      'Before creating or linking a child account, verify that you are a guardian (My Number Card (JPKI) in Japan; self-declaration in the web console in other countries).';

  @override
  String get childSafeGuardianVerifyJpki => 'Verify with My Number Card';

  @override
  String get childSafeGuardianVerifyJpkiSubtitle =>
      'For residents of Japan. After agreeing to the pledge, it opens in an external browser';

  @override
  String get childSafeGuardianVerifyWeb => 'Verify in the web console';

  @override
  String get childSafeGuardianOpensInBrowser => 'Opens in an external browser';

  @override
  String childSafeGuardianChildrenSection(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supervised children ($count / $max)',
      one: 'Supervised children (1 / $max)',
    );
    return '$_temp0';
  }

  @override
  String get childSafeGuardianNoChildren => 'None yet.';

  @override
  String get childSafeGuardianCreatedByGuardian => ' · Created by guardian';

  @override
  String get childSafeGuardianAddSection => 'Add a child';

  @override
  String get childSafeGuardianCreate => 'Create a child account';

  @override
  String get childSafeGuardianCreateSubtitle =>
      'Set a handle, name and age band, and a code for logging in on the child\'s device is shown once';

  @override
  String get childSafeGuardianHandleHint => 'Handle (letters and numbers)';

  @override
  String get childSafeGuardianNameHint => 'Display name';

  @override
  String get childSafeGuardianCreateButton => 'Create';

  @override
  String childSafeGuardianNewLoginCodeTitle(String handle) {
    return 'Login code for @$handle (enter it in \"Log in with a code from your guardian\" on the child\'s device, or scan the QR with its camera)';
  }

  @override
  String get childSafeGuardianPair => 'Link with a code';

  @override
  String get childSafeGuardianPairSubtitle =>
      'Link a RASQ account the child already has via \"Child mode\" on the child\'s device (10 minutes, one time only)';

  @override
  String get childSafeGuardianPairCodeTitle =>
      'Link code (enter it in \"Child mode\" on the child\'s device, or scan the QR with its camera)';

  @override
  String childSafeGuardianCodeExpires(String time) {
    return 'Valid until $time. Once you close this screen, it can\'t be shown again (reissuing makes the previous code unusable).';
  }

  @override
  String get childSafeGuardianCodeQr => 'Code QR';

  @override
  String get childSafeGuardianCopy => 'Copy';

  @override
  String get childSafeGuardianCopyLink => 'Copy link';

  @override
  String get childSafeGuardianClose => 'Close';

  @override
  String get childSafeGuardianPageTimeline => 'Timeline';

  @override
  String get childSafeGuardianPageComposer => 'Posts';

  @override
  String get childSafeGuardianPageAstell => 'ASTell';

  @override
  String get childSafeGuardianPagePlugins => 'Plugins';

  @override
  String get childSafeGuardianPageSns => 'SNS';

  @override
  String get childSafeGuardianPageScreenTime => 'Screen time';

  @override
  String get childSafeGuardianPageOther => 'Other';

  @override
  String get childSafeGuardianTimeFormatError => 'Enter times as HH:MM';

  @override
  String get childSafeGuardianConfirmTitle => 'Send these settings';

  @override
  String get childSafeGuardianConfirmSend => 'Send';

  @override
  String childSafeGuardianConfirmIntro(String handle) {
    return 'These settings will be delivered to @$handle\'s device.';
  }

  @override
  String childSafeGuardianConfirmIntroDetail(String handle) {
    return '@$handle\'s device receives settings signed by Central (the device verifies them before applying).';
  }

  @override
  String childSafeGuardianSaved(int revision) {
    return 'Saved (settings $revision). Shows \"delivered\" once it reaches the child\'s device';
  }

  @override
  String childSafeGuardianImportPreset(String band) {
    return 'Load $band defaults';
  }

  @override
  String get childSafeGuardianImportCopy => 'Copy another child\'s settings';

  @override
  String childSafeGuardianImportedPreset(String band) {
    return 'Loaded $band defaults';
  }

  @override
  String get childSafeGuardianCopyWhich =>
      'Which child\'s settings do you want to copy?';

  @override
  String childSafeGuardianNotSetUp(String handle) {
    return '@$handle hasn\'t been set up yet';
  }

  @override
  String childSafeGuardianCopied(String handle) {
    return 'Copied @$handle\'s settings';
  }

  @override
  String childSafeGuardianNotSavedYet(String what) {
    return '$what (not saved yet)';
  }

  @override
  String get childSafeGuardianEnd => 'End supervision';

  @override
  String childSafeGuardianEndMessage(String handle) {
    return 'This removes all restrictions for @$handle. They\'re lifted on the child\'s device the next time it connects. To restore them, link again.';
  }

  @override
  String childSafeGuardianEndMessageDetail(String handle) {
    return 'This removes all restrictions for @$handle. They\'re lifted on the child\'s device the next time it reaches Central. To restore them, link again.';
  }

  @override
  String get childSafeGuardianEndConfirm => 'End';

  @override
  String get childSafeGuardianEndSubtitle => 'Removes all restrictions';

  @override
  String get childSafeGuardianSummarySection =>
      'Summary of recent activity (14 days)';

  @override
  String get childSafeGuardianLoginSection => 'Child\'s device login';

  @override
  String get childSafeGuardianReissue => 'Reissue code';

  @override
  String get childSafeGuardianReissueSubtitle =>
      'A code to enter in \"Log in with a code from your guardian\" on the child\'s device (10 minutes, one time only; the previous code stops working)';

  @override
  String childSafeGuardianLoginCodeTitle(String handle) {
    return 'Login code for @$handle';
  }

  @override
  String get childSafeGuardianSaveButton => 'Save and send to child\'s device';

  @override
  String get childSafeGuardianImportTooltip => 'Import settings';

  @override
  String childSafeGuardianPresetCaption(String band) {
    return 'Choosing a strength aligns the timeline and post check strengths. Use the round button on the right to load $band defaults or another child\'s settings.';
  }

  @override
  String get childSafeGuardianSummaryEmpty =>
      'No reports yet (the child\'s device sends the counts for completed days once a day).';

  @override
  String get childSafeGuardianSummaryCaption =>
      'Only the number sent, number blocked, and the kinds blocked (post text and topics aren\'t sent; pre-send checks happen on your child\'s device).';

  @override
  String childSafeGuardianSummaryDay(int posts, int blocked, String trips) {
    return 'Sent $posts · Blocked $blocked$trips';
  }

  @override
  String childSafeGuardianSummaryTrips(String list) {
    return ' ($list)';
  }

  @override
  String get childSafeGuardianSummaryTripsSeparator => ', ';

  @override
  String get childSafeGuardianTimelineEnabled => 'Filter the timeline';

  @override
  String get childSafeGuardianTimelineEnabledSubtitle =>
      'Hides posts with strong language and filters by topic';

  @override
  String get childSafeGuardianTimelineLevel => 'Timeline strength';

  @override
  String get childSafeGuardianTimelineTopics => 'Timeline topics';

  @override
  String get childSafeGuardianTimelineAllowHint =>
      'Topics to show (separate words or tags with \",\")';

  @override
  String get childSafeGuardianTimelineDenyHint =>
      'Topics to hide (separate words or tags with \",\")';

  @override
  String get childSafeGuardianTimelineAllowNote =>
      'Allowlist: only posts matching one of the topics appear in the timeline.';

  @override
  String get childSafeGuardianTimelineDenyNote =>
      'Blocklist: matching posts are hidden (empty = no topic filtering).';

  @override
  String get childSafeGuardianComposerEnabled => 'Check posts';

  @override
  String get childSafeGuardianComposerEnabledSubtitle =>
      'Stops posts before sending based on strong language and topics (marks the matched words)';

  @override
  String get childSafeGuardianComposerLevel => 'Post strength';

  @override
  String get childSafeGuardianPostsPerDayHint =>
      'Posts allowed per day (empty = no limit, 0–1000)';

  @override
  String get childSafeGuardianComposerTopics => 'Post topics';

  @override
  String get childSafeGuardianComposerAllowHint =>
      'Allowed topics (separate words or tags with \",\")';

  @override
  String get childSafeGuardianComposerDenyHint =>
      'Blocked topics (separate words or tags with \",\")';

  @override
  String get childSafeGuardianComposerAllowNote =>
      'Allowlist: only posts matching one of the topics can be sent (doesn\'t apply to DMs).';

  @override
  String get childSafeGuardianComposerDenyNote =>
      'Blocklist: matching posts can\'t be sent (empty = no topic blocking; doesn\'t apply to DMs).';

  @override
  String get childSafeGuardianAstellCaption =>
      'What the child can do in ASTell (room calls, chat and sharing).';

  @override
  String get childSafeGuardianInstallSection => 'Installation';

  @override
  String get childSafeGuardianInstallCaption =>
      'What the child can install on their own. Since plugins keep increasing, decide broadly with \"Examples\" below rather than one by one.';

  @override
  String get childSafeGuardianNamedSection => 'Plugins allowed by name';

  @override
  String get childSafeGuardianNamedNone => 'None.';

  @override
  String get childSafeGuardianNamedCaption =>
      'Plugins listed here can be used even if they\'re similar to blocked examples (remove with ✕).';

  @override
  String get childSafeGuardianRemove => 'Remove';

  @override
  String get childSafeGuardianAddIdHint => 'Add by id (e.g. jp.example.quiz)';

  @override
  String get childSafeGuardianAddIdButton => 'Add';

  @override
  String get childSafeGuardianIdShapeError =>
      'Not a valid plugin id (lowercase letters, digits, \".\", \"_\", \"-\"; e.g. jp.example.quiz)';

  @override
  String get childSafeGuardianSnsCaption =>
      'SNS types and servers the child may use (from your bundle). If no server is selected, any server of that type is allowed. The guardian\'s SNS logins aren\'t lent.';

  @override
  String get childSafeGuardianSnsAdd => 'Child can add SNS accounts';

  @override
  String get childSafeGuardianTimeEnabled => 'Supervised hours';

  @override
  String get childSafeGuardianTimeEnabledSubtitle =>
      'During that time, there\'s a single timeline (by the child\'s device clock)';

  @override
  String get childSafeGuardianTimeStartHint => 'Start 21:00';

  @override
  String get childSafeGuardianTimeEndHint => 'End 06:00';

  @override
  String get childSafeGuardianTimeRangeSeparator => '–';

  @override
  String get childSafeGuardianTimeLegacyNote =>
      'The current setting uses the old \"show nothing during that time\" form. This form can no longer be saved, so add topics to show or switch to a blocklist before saving.';

  @override
  String get childSafeGuardianTimeTopics => 'Topics during that time';

  @override
  String get childSafeGuardianTimeAllowHint =>
      'Topics to show during that time (separate words or tags with \",\")';

  @override
  String get childSafeGuardianTimeDenyHint =>
      'Topics to hide during that time (separate words or tags with \",\")';

  @override
  String get childSafeGuardianTimeAllowNote =>
      'Allowlist: during that time, only posts matching one of the topics appear.';

  @override
  String get childSafeGuardianTimeDenyNote =>
      'Blocklist: during that time, matching posts are hidden (empty = no topic filtering).';

  @override
  String get childSafeGuardianHideNotifications => 'Hide notifications';

  @override
  String get childSafeGuardianHidePostDetail =>
      'Don\'t allow opening post details';

  @override
  String get childSafeGuardianHideDm => 'Hide DMs';

  @override
  String get childSafeGuardianRaiEnabled => 'Can use RAi';

  @override
  String get childSafeGuardianRaiComingSoon =>
      'Coming soon (not in effect yet)';

  @override
  String get childSafeGuardianRaiAutomation => 'Automation with functions';

  @override
  String get childSafeGuardianRaiAutomationSubtitle =>
      'When off, RAi only guides (points the way)';

  @override
  String get childSafeGuardianSearchSection => 'Search';

  @override
  String get childSafeGuardianFeaturesSection => 'Features';

  @override
  String get childSafeGuardianExamplesTitlePlugins =>
      'Decide by examples (plugins)';

  @override
  String get childSafeGuardianExamplesTitleTl =>
      'Decide by examples (clips / lists)';

  @override
  String get childSafeGuardianExamplesCaptionPlugins =>
      'Choose examples of \"allow / block plugins like this\". The child\'s device decides by how close a plugin\'s name and description are to the examples. Plugins similar to blocked examples can\'t be used even under \"Unrestricted\". With \"Similar to examples\", plugins allowed by name and those similar to allowed examples can be used.';

  @override
  String get childSafeGuardianExamplesCaptionTl =>
      'Choose examples of \"allow / block things like this\" from your recent actions / clips / lists. Any of the child\'s clips / lists whose contents are similar to blocked examples won\'t appear in lists or the timeline.';

  @override
  String get childSafeGuardianPickPlugins =>
      'Choose examples (plugins / Store)';

  @override
  String get childSafeGuardianPickTl =>
      'Choose examples (recent actions / clips / lists)';

  @override
  String childSafeGuardianPickCounts(int allow, int deny) {
    return 'Allowed examples $allow / Blocked examples $deny';
  }

  @override
  String childSafeGuardianPickTitlePlugins(String handle) {
    return 'Plugin examples (@$handle)';
  }

  @override
  String childSafeGuardianPickTitleTl(String handle) {
    return 'Timeline examples (@$handle)';
  }

  @override
  String get childSafeGuardianAllowLabel => 'Allowed examples';

  @override
  String get childSafeGuardianDenyLabel => 'Blocked examples';

  @override
  String get childSafeGuardianPickIntroPlugins =>
      'Review the contents and choose \"Allowed examples\" / \"Blocked examples\" for the child (or swipe right / left). The child\'s device sorts new plugins by how close they are to the examples.';

  @override
  String get childSafeGuardianPickIntroTl =>
      'Review the contents and choose \"Allowed examples\" / \"Blocked examples\" for the child (or swipe right / left). The child\'s device sorts clips / lists by how close they are to the examples.';

  @override
  String get childSafeScreensBadge => 'Supervised';

  @override
  String childSafeScreensWindowBanner(String window, String detail) {
    return 'Supervised hours ($window). $detail';
  }

  @override
  String get childSafeScreensWindowNothing => 'No posts are shown';

  @override
  String childSafeScreensWindowAllowOnly(String topics) {
    return 'Only posts about \"$topics\" are shown';
  }

  @override
  String childSafeScreensWindowDenied(String topics) {
    return 'Posts about \"$topics\" are not shown';
  }

  @override
  String get childSafeScreensBlockedHint =>
      'Supervision settings are decided by your guardian';

  @override
  String get childSafeScreensHubTitle => 'Child Safe';

  @override
  String get childSafeScreensHubIntro =>
      'A guardian decides how a child\'s account can be used. The guardian only receives counts and the types of things that were blocked, never the text of posts.';

  @override
  String get childSafeScreensHubIntroDetail =>
      'The guardian\'s RASQ account decides how the child\'s RASQ account can be used. Posts are checked on this device, and the guardian only receives the number sent, the number blocked, and the types blocked before sending (never the text or topics of posts).';

  @override
  String get childSafeScreensHubManagedSection => 'You are supervised';

  @override
  String get childSafeScreensHubParent => 'Guardian';

  @override
  String get childSafeScreensHubState => 'Status';

  @override
  String childSafeScreensHubStateActive(int revision) {
    return 'Supervised (settings rev. $revision)';
  }

  @override
  String get childSafeScreensHubOffline =>
      'Can\'t reach the server right now. Supervision continues with the previous settings.';

  @override
  String get childSafeScreensHubRefresh => 'Reload guardian settings';

  @override
  String get childSafeScreensHubAsGuardian => 'As a guardian';

  @override
  String childSafeScreensHubGuardianVerified(String method) {
    return 'Verified ($method). Create, link, or configure a child account';
  }

  @override
  String get childSafeScreensHubGuardianUnverified =>
      'Guardian verification is done in the web console (My Number Card in Japan, self-declaration elsewhere)';

  @override
  String get childSafeScreensHubAsChild => 'As a child';

  @override
  String get childSafeScreensHubChildModeLogin =>
      'Log in with a code from your guardian';

  @override
  String get childSafeScreensHubChildModePair =>
      'Link this account using your guardian\'s code';

  @override
  String get childSafeScreensHubLoginSubtitle =>
      'Sign in to a child account your guardian created';

  @override
  String get childSafeScreensHubThisDevice => 'This device';

  @override
  String get childSafeScreensHubSafety => 'Privacy and safe mode';

  @override
  String get childSafeScreensHubSafetyManaged =>
      'While supervised, sensitive media is always hidden (cannot be changed)';

  @override
  String get childSafeScreensHubSafetyNormal => 'Sensitive media handling';

  @override
  String childSafeScreensTopicsNote(String label, String topics) {
    return ' ($label: $topics)';
  }

  @override
  String get childSafeScreensTopicsNone => 'None';

  @override
  String get childSafeScreensTopicsShown => 'Topics shown';

  @override
  String get childSafeScreensTopicsHidden => 'Hidden topics';

  @override
  String get childSafeScreensTopicsSendable => 'Allowed topics to post';

  @override
  String get childSafeScreensTopicsUnsendable => 'Blocked topics to post';

  @override
  String get childSafeScreensTopicsNotShown => 'Topics not shown';

  @override
  String childSafeScreensSummaryTimeline(String level, String note) {
    return 'Timeline: $level$note';
  }

  @override
  String childSafeScreensSummaryComposer(String level, String note) {
    return 'Post check: $level$note';
  }

  @override
  String childSafeScreensSummaryPostsPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posts per day: $count',
      one: 'Posts per day: 1',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryTime(String window, String note) {
    return 'Supervised hours: $window$note';
  }

  @override
  String get childSafeScreensSummaryTimeNothing => ' (no posts shown)';

  @override
  String childSafeScreensSummarySns(
    String kinds,
    String servers,
    String noAdd,
  ) {
    return 'Allowed SNS: $kinds$servers$noAdd';
  }

  @override
  String get childSafeScreensSummaryAny => 'Any';

  @override
  String childSafeScreensSummarySnsServers(String servers) {
    return ' ($servers)';
  }

  @override
  String get childSafeScreensSummarySnsNoAdd => ', no new accounts';

  @override
  String childSafeScreensSummaryFeaturesOff(String list) {
    return 'Disabled features: $list';
  }

  @override
  String childSafeScreensSummarySearchOff(String list) {
    return 'Disabled search: $list';
  }

  @override
  String childSafeScreensSummaryPlugins(String scope, String install) {
    return 'Plugins: $scope, install: $install';
  }

  @override
  String childSafeScreensSummaryPluginsExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected, plus ones similar to allowed examples',
      one: '1 selected, plus ones similar to allowed examples',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryPluginsListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Only $count selected',
      one: 'Only 1 selected',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryExamples(int allow, int deny) {
    return 'Examples: $allow allowed / $deny blocked (plugins, clips and lists similar to blocked examples are hidden)';
  }

  @override
  String childSafeScreensSummaryRai(int count, String noAuto) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RAi: $count function groups$noAuto',
      one: 'RAi: 1 function group$noAuto',
    );
    return '$_temp0';
  }

  @override
  String get childSafeScreensSummaryRaiNoAuto => ' (no automation)';

  @override
  String get childSafeScreensSummaryRaiOff => 'RAi: unavailable';

  @override
  String childSafeScreensFromLink(String action) {
    return 'The code was filled in from a link (QR). Make sure you received it from your own guardian before tapping \"$action\". If the link came from someone you don\'t know, close this without tapping.';
  }

  @override
  String get childSafeScreensPaired =>
      'Linked with your guardian. Please wait until your guardian sets things up';

  @override
  String get childSafeScreensPairNotLoggedIn =>
      'You\'re not logged in to a RASQ account. If your guardian created the account, log in with the code from your guardian.';

  @override
  String get childSafeScreensPairExistingLogin =>
      'Log in to an existing RASQ account';

  @override
  String childSafeScreensPairIntro(String handle) {
    return 'Link @$handle to your guardian\'s supervision. Enter the code (8 characters) shown on your guardian\'s screen. Once linked, you can\'t use the app until your guardian sets things up.';
  }

  @override
  String childSafeScreensPairIntroDetail(String handle) {
    return 'Link @$handle to your guardian\'s supervision. Enter the code (8 characters, e.g. ABCD-EFGH) shown on your guardian\'s screen (in the app or the web console). Once linked, you can\'t use the app until your guardian sets things up.';
  }

  @override
  String get childSafeScreensPairButton => 'Link';

  @override
  String get childSafeScreensPairQrHint =>
      'You can also link by scanning the QR on your guardian\'s screen with this device\'s camera app.';

  @override
  String get childSafeScreensPairQrHintDetail =>
      'Scanning the QR on your guardian\'s screen with this device\'s camera app opens this screen with the code filled in. You can also link by pasting the link (rasq://child-safe/pair?code=…).';

  @override
  String get childSafeScreensPairNoQr =>
      'This device can\'t scan QR codes. Please enter the code.';

  @override
  String get childSafeScreensPairNoQrDetail =>
      'This device can\'t scan QR codes. Enter the code or paste the link (rasq://child-safe/pair?code=…).';

  @override
  String get childSafeScreensLoginFailed => 'Couldn\'t log in';

  @override
  String childSafeScreensLoggedIn(String handle, String device) {
    return 'Logged in as @$handle ($device)';
  }

  @override
  String get childSafeScreensLoginIntro =>
      'When your guardian creates a child account in the app, a one-time code is shown. Enter that code and this device becomes that account. SNS accounts on this device are not carried over.';

  @override
  String get childSafeScreensLoginCodeHint => 'Login code';

  @override
  String get childSafeScreensLoginButton => 'Log in';

  @override
  String get childSafeScreensPendingUnverifiedTitle =>
      'Can\'t verify your guardian\'s settings';

  @override
  String get childSafeScreensPendingTitle =>
      'Please wait until your guardian sets things up';

  @override
  String get childSafeScreensPendingSignatureMismatch =>
      'The settings signature doesn\'t match.';

  @override
  String childSafeScreensPendingBody(String parent) {
    return 'You\'re linked with $parent for supervision. You can use the app once $parent decides how it can be used.';
  }

  @override
  String get childSafeScreensPendingParent => 'your guardian';

  @override
  String get childSafeScreensPendingOffline =>
      'Can\'t reach the server right now.';

  @override
  String get childSafeScreensPendingRefresh => 'Refresh';

  @override
  String get childSafeScreensPendingLogout => 'Log out';

  @override
  String get childSafeScreensPendingRasqLogin => 'Log in to a RASQ account';

  @override
  String get clipsNoSession => 'No session';

  @override
  String get clipsChildSafeBlocked => 'Your guardian has blocked this clip';

  @override
  String get clipsRetry => 'Reload';

  @override
  String get clipsEmptyTitle => 'This clip is empty';

  @override
  String get clipsEmptyHint =>
      'Collect posts here with \"Add to clip\" in the post menu';

  @override
  String clipsPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String get clipsKindHost => 'RASQ clip (cross-SNS)';

  @override
  String get clipsKindPrivate => 'Private clip';

  @override
  String get clipsCaptionSeparator => ' · ';

  @override
  String get clipsLoading => 'Loading…';

  @override
  String get clipsLoadMore => 'Load more';

  @override
  String clipsActionFailed(String error) {
    return 'Couldn\'t do that: $error';
  }

  @override
  String get clipsPublishHint =>
      'Once published, it can be viewed from your account page and a share link';

  @override
  String clipsPublishHintSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Once published, it can be viewed from your account page and a share link ($count posts, such as followers-only ones, won\'t be included)',
      one: 'Once published, it can be viewed from your account page and a share link (1 post, such as a followers-only one, won\'t be included)',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublishNeedsAccount =>
      'A RASQ account is required to publish';

  @override
  String get clipsPublish => 'Publish';

  @override
  String clipsPublishedPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Published (checking the visibility of $count posts)',
      one: 'Published (checking the visibility of 1 post)',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublished => 'Published';

  @override
  String clipsPublishedStatusSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Public ($count posts, such as followers-only ones, are not included)',
      one: 'Public (1 post, such as a followers-only one, is not included)',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublishedStatus => 'Public';

  @override
  String get clipsLinkCopied => 'Link copied';

  @override
  String get clipsCopyLink => 'Copy link';

  @override
  String get clipsUnpublished => 'Unpublished';

  @override
  String get clipsUnpublish => 'Unpublish';

  @override
  String get clipsAddTitle => 'Add to clip';

  @override
  String get clipsAddAddedHost => 'Added · RASQ clip';

  @override
  String get clipsAddAddedHostPublished => 'Added · RASQ clip (public)';

  @override
  String clipsAddHostRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts · RASQ clip (cross-SNS)',
      one: '1 post · RASQ clip (cross-SNS)',
    );
    return '$_temp0';
  }

  @override
  String clipsAddHostRowPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts · RASQ clip (cross-SNS) · Public',
      one: '1 post · RASQ clip (cross-SNS) · Public',
    );
    return '$_temp0';
  }

  @override
  String get clipsAddCreate => 'Create new clip';

  @override
  String clipsAdded(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String clipsAddFailed(String error) {
    return 'Couldn\'t add to clip: $error';
  }

  @override
  String get clipsCreateTitle => 'New clip';

  @override
  String get clipsCreateNameHint => 'Clip name';

  @override
  String get clipsCreateDescriptionHint => 'Description (optional)';

  @override
  String get clipsCreateHost => 'Make it a RASQ clip (cross-SNS)';

  @override
  String get clipsCreateHostSubtitle =>
      'Saved on this device; posts from other SNS can go in the same clip';

  @override
  String get clipsCreateAndAdd => 'Create and add';

  @override
  String get clipsIndexFallback => 'Posts without a clear topic';

  @override
  String get clipsIndexSingles => 'Standalone posts';

  @override
  String clipsIndexRelated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count related posts',
      one: '1 related post',
    );
    return '$_temp0';
  }

  @override
  String get clipsTocTitle => 'Contents';

  @override
  String clipsTocPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get clipsTocFiltering => 'Filtering';

  @override
  String get clipsNoServer => 'No server is set for your RASQ account';

  @override
  String get clipsNotFound => 'Clip not found';

  @override
  String get collectionsImportToTimeline => 'Add to timeline';

  @override
  String get collectionsNotFound => 'Not found';

  @override
  String get collectionsNotFoundHint => 'It was deleted or made private';

  @override
  String get collectionsReload => 'Reload';

  @override
  String get collectionsBlockedList => 'Your guardian has blocked this list';

  @override
  String get collectionsBlockedClip => 'Your guardian has blocked this clip';

  @override
  String get collectionsMenuCopyLink => 'Copy link';

  @override
  String get collectionsMenuRefresh => 'Refresh now';

  @override
  String get collectionsMenuMakePrivate => 'Make private';

  @override
  String get collectionsMenuMakePublic => 'Make public';

  @override
  String get collectionsMenuRename => 'Edit name and description';

  @override
  String get collectionsMenuDelete => 'Delete';

  @override
  String get collectionsMenuUnpublish => 'Unpublish';

  @override
  String get collectionsLinkCopied => 'Link copied';

  @override
  String get collectionsRefreshFailed => 'Couldn\'t refresh';

  @override
  String get collectionsRefreshed => 'Refreshed';

  @override
  String get collectionsRenameTitle => 'Name and description';

  @override
  String get collectionsSave => 'Save';

  @override
  String get collectionsNameHint => 'Name';

  @override
  String get collectionsDescriptionHint => 'Description (optional)';

  @override
  String collectionsDeleteConfirmTitle(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get collectionsDeleteConfirmMessage =>
      'It will also be removed for people who follow it.';

  @override
  String get collectionsDeleteButton => 'Delete';

  @override
  String get collectionsCancel => 'Cancel';

  @override
  String collectionsActionFailed(String error) {
    return 'Couldn\'t complete: $error';
  }

  @override
  String get collectionsTabPosts => 'Posts';

  @override
  String get collectionsTabTopics => 'Topics';

  @override
  String get collectionsTabMembers => 'Members';

  @override
  String get collectionsTabServers => 'Servers';

  @override
  String get collectionsStatusRefreshedOnView => 'Refreshed when viewed';

  @override
  String get collectionsStatusRefreshFailed =>
      'Couldn\'t refresh (showing previous content)';

  @override
  String get collectionsStatusFollowingHint =>
      'It refreshes when you view it if you\'re on the same server as its members or follow them';

  @override
  String get collectionsKindList => 'RASQ list';

  @override
  String get collectionsKindClip => 'RASQ clip';

  @override
  String get collectionsPrivate => 'Private';

  @override
  String get collectionsPublic => 'Public';

  @override
  String collectionsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String collectionsItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String collectionsFollowerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count followers',
      one: '1 follower',
    );
    return '$_temp0';
  }

  @override
  String collectionsUpdatedAgo(String ago) {
    return 'Updated $ago';
  }

  @override
  String get collectionsSeparator => ' · ';

  @override
  String get collectionsFollowing => 'Following';

  @override
  String get collectionsFollow => 'Follow';

  @override
  String get collectionsNoPostsYet => 'No posts yet';

  @override
  String get collectionsNoPostsHintEmpty =>
      'Add people from a user page via … → \"Add to RASQ list\"';

  @override
  String get collectionsNoPostsHintCollecting =>
      'Posts are collected when someone who can see them opens it';

  @override
  String get collectionsClipEmpty => 'This clip is empty';

  @override
  String get collectionsItemGone =>
      'This post is no longer available (it was deleted or its visibility changed)';

  @override
  String get collectionsItemChecking => 'Checking visibility';

  @override
  String get collectionsAddMembers => 'Add members';

  @override
  String collectionsMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count people',
      one: 'Added 1 person',
    );
    return '$_temp0';
  }

  @override
  String collectionsAddFailed(String error) {
    return 'Couldn\'t add: $error';
  }

  @override
  String get collectionsNoMembers => 'No members';

  @override
  String get collectionsNoMembersHint =>
      'Use \"Add members\", or … → \"Add to RASQ list\" on a user page';

  @override
  String collectionsMemberSubtitle(String handle, String kind) {
    return '@$handle · $kind';
  }

  @override
  String get collectionsRemoveFromListTooltip => 'Remove from list';

  @override
  String collectionsRemoveFailed(String error) {
    return 'Couldn\'t remove: $error';
  }

  @override
  String get collectionsNotFetchableHint =>
      'None of your accounts can fetch info about the people in this list (you need an account on the same server as them, or to follow them)';

  @override
  String get collectionsNoServer => 'No server is set for your RASQ account';

  @override
  String collectionsCheckFailed(String error) {
    return 'Couldn\'t check: $error';
  }

  @override
  String get collectionsPickerEmpty => 'No RASQ lists yet';

  @override
  String get collectionsPickerNoHits => 'Not found';

  @override
  String get collectionsPickerMine => 'My list';

  @override
  String get collectionsPickerNotFetchable => 'Unavailable';

  @override
  String get collectionsNotLoggedIn => 'Not logged in';

  @override
  String collectionsImportRejected(String name, String reason) {
    return 'Can\'t import \"$name\" ($reason)';
  }

  @override
  String collectionsAlreadyImported(String name) {
    return '\"$name\" is already in your home timeline';
  }

  @override
  String collectionsImported(String name) {
    return 'Added \"$name\" to your home timeline (check it with the gear in the tab row)';
  }

  @override
  String get collectionsTileOpen => 'Take a look';

  @override
  String get collectionsCreateNeedsAccount =>
      'You need a RASQ account to create RASQ lists';

  @override
  String get collectionsCreateTitle => 'New RASQ list';

  @override
  String get collectionsListNameHint => 'List name';

  @override
  String get collectionsPublishSwitch => 'Public';

  @override
  String get collectionsPublishSwitchSubtitle =>
      'Visible from your account page and share link. It also refreshes when followers view it';

  @override
  String get collectionsCreateButton => 'Create';

  @override
  String collectionsCreateFailed(String error) {
    return 'Couldn\'t create: $error';
  }

  @override
  String get collectionsUseNeedsAccount =>
      'You need a RASQ account to use RASQ lists';

  @override
  String collectionsLoadListsFailed(String error) {
    return 'Couldn\'t load lists: $error';
  }

  @override
  String get collectionsAddToListTitle => 'Add to RASQ list';

  @override
  String collectionsAddToListSubtitlePublic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0 · Public';
  }

  @override
  String collectionsAddToListSubtitlePrivate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0 · Private';
  }

  @override
  String get collectionsCreateNewList => 'Create new list';

  @override
  String collectionsAddedTo(String name) {
    return 'Added to \"$name\"';
  }

  @override
  String collectionsAlreadyIn(String name) {
    return 'Already in \"$name\"';
  }

  @override
  String get composeTargetNormalTitle => 'New note';

  @override
  String get composeTargetReplyTitle => 'Reply';

  @override
  String get composeTargetQuoteTitle => 'Quote';

  @override
  String get composeEmojiPickerTitle => 'Emoji';

  @override
  String get composeEmojiPickerClose => 'Close';

  @override
  String get composePollRemoveTooltip => 'Remove poll';

  @override
  String composePollChoiceHint(int index) {
    return 'Choice $index';
  }

  @override
  String get composePollChoiceDeleteTooltip => 'Delete';

  @override
  String get composePollAddChoice => 'Add choice';

  @override
  String get composePollTimed => 'Set deadline';

  @override
  String get composePollMultiple => 'Multiple choice';

  @override
  String get composePollUnitDays => 'days';

  @override
  String get composePollUnitHours => 'hours';

  @override
  String get composePollUnitMinutes => 'minutes';

  @override
  String get composePollUnitSeconds => 'seconds';

  @override
  String get composeDraftsTitle => 'Drafts';

  @override
  String get composeDraftsCancel => 'Cancel';

  @override
  String get composeDraftsDelete => 'Delete';

  @override
  String get composeDraftsSaveAndClose => 'Save current content and close';

  @override
  String get composeDraftsOverwriteAndClose =>
      'Overwrite with current content and close';

  @override
  String get composeDraftsSaveNewAndClose =>
      'Save current content as a new draft and close';

  @override
  String get composeDraftsEmpty => 'No drafts';

  @override
  String composeDraftsAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftsOpenNow => 'Open now';

  @override
  String get composeDraftsSelectOff => 'Deselect';

  @override
  String get composeDraftsSelect => 'Select';

  @override
  String composeDraftsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
    );
    return '$_temp0';
  }

  @override
  String composeDraftTitleAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count attachments)',
      one: '(1 attachment)',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftTitleEmpty => '(No text)';

  @override
  String get composeDraftTargetReply => 'Reply';

  @override
  String get composeDraftTargetQuote => 'Quote';

  @override
  String get composeDraftTargetPost => 'Post';

  @override
  String get composeReactionAcceptanceAll => 'All';

  @override
  String get composeReactionAcceptanceLikeOnly => 'Likes only';

  @override
  String get composeReactionAcceptanceLikeOnlyForRemote =>
      'Likes only from remote';

  @override
  String get composeReactionAcceptanceNonSensitiveOnly => 'Non-sensitive only';

  @override
  String
  get composeReactionAcceptanceNonSensitiveOnlyForLocalLikeOnlyForRemote =>
      'Non-sensitive only & likes only from remote';

  @override
  String get composeEmojiResizeHandleSemantics => 'Resize handle';

  @override
  String get composeEmojiSectionHistory => 'Recent';

  @override
  String get composeEmojiSectionPrediction => 'Suggested';

  @override
  String get composeEmojiBundleEditTitle => 'Edit bundle';

  @override
  String get composeEmojiBundleEditMessage => 'Bundle editing is coming soon.';

  @override
  String get composeEmojiSectionDefault => 'Default';

  @override
  String get composeEmojiCustomEmpty => 'No custom emoji';

  @override
  String get composeEmojiSectionServer => 'Server';

  @override
  String get composeEmojiGenreOther => 'Other';

  @override
  String composeEmojiGroupHeading(String name) {
    return '· $name';
  }

  @override
  String get composeEmojiSearchHint => 'Search';

  @override
  String get composeEmojiStickersEmpty =>
      'No asset packs available (you can install them from the Store)';

  @override
  String get composeEmojiSectionSearchResults => 'Search results';

  @override
  String get composeEmojiSearchNoHit => 'No results';

  @override
  String composeEmojiIndexProgress(int done, int total) {
    return 'Preparing semantic search $done / $total';
  }

  @override
  String get composeVisibilityHome => 'Home';

  @override
  String get composeVisibilityFollowers => 'Followers';

  @override
  String get composeVisibilityPublic => 'Public';

  @override
  String composeVisibilityTooltip(String label) {
    return 'Visibility: $label';
  }

  @override
  String get composeLocalOnlyOnTooltip => 'Not federated (this server only)';

  @override
  String get composeLocalOnlyOffTooltip =>
      'Federated (tap to disable federation)';

  @override
  String composeReactionAcceptanceTooltip(String label) {
    return 'Reaction acceptance: $label';
  }

  @override
  String get composeOn => 'On';

  @override
  String get composeOff => 'Off';

  @override
  String composeTextPluginTooltip(String label, String state) {
    return '$label ($state · long-press for settings)';
  }

  @override
  String get composeTextPluginHereTitle => 'On in this composer';

  @override
  String get composeTextPluginHereSubtitle =>
      'Passes text changes to this plugin';

  @override
  String get composeTextPluginAutoTitle => 'Turn on automatically next time';

  @override
  String composeTextPluginAutoDefault(String state) {
    return 'Plugin default ($state)';
  }

  @override
  String composeTextPluginAutoOverridden(String state) {
    return 'Overridden in settings (default: $state)';
  }

  @override
  String get composeTextPluginResetDefault => 'Reset to plugin default';

  @override
  String composeTextPluginCaption(String name) {
    return '$name · Text processing';
  }

  @override
  String get composeHeaderPost => 'Post';

  @override
  String get composeHeaderReply => 'Reply';

  @override
  String get composeHeaderQuote => 'Quote';

  @override
  String get composeCloseOverwriteTitle => 'Overwrite draft?';

  @override
  String get composeCloseSaveTitle => 'Save as draft?';

  @override
  String get composeCloseOverwriteMessage =>
      'The open draft will be overwritten with the current content and the composer will close.';

  @override
  String get composeCloseSaveMessage =>
      'The current content will be kept as a draft and the composer will close.';

  @override
  String get composeCloseOverwrite => 'Overwrite';

  @override
  String get composeCloseSaveNew => 'Save as new';

  @override
  String get composeCloseSave => 'Save';

  @override
  String get composeCloseDiscard => 'Discard changes';

  @override
  String get composeCancel => 'Cancel';

  @override
  String get composeMultiNormal => 'Normal post';

  @override
  String get composeMultiLinked => 'Node-linked';

  @override
  String get composeRasqTarget => 'Post to RASQ';

  @override
  String get composeTargetMatchedTooltip =>
      'Matches the post target node\'s conditions';

  @override
  String get composeTargetCustomize => 'Customize post targets';

  @override
  String get composeMultiSelectOff => 'Exit multi-select';

  @override
  String get composeMultiSelectOn => 'Multi-select mode';

  @override
  String get composeLinkedConfirmTitle => 'Confirm linked posts';

  @override
  String get composeLinkedConfirmSame => 'Linked post with the same content';

  @override
  String get composeLinkedConfirmAlt => 'Linked post in an alternative format';

  @override
  String get composeLinkedConfirmPost => 'Post this';

  @override
  String get composeRasqNoServer => 'No RASQ server is set';

  @override
  String get composeRasqOverLimit => 'Exceeds the RASQ limit';

  @override
  String get composeRasqTextOnlyTip => 'RASQ replies are text only';

  @override
  String composePickImageFailed(String error) {
    return 'Couldn\'t select the image: $error';
  }

  @override
  String get composePickVideoLibrary => 'Videos from library';

  @override
  String get composePickVideoFile => 'From files (video / audio)';

  @override
  String composePickNotMedia(String name) {
    return 'Not a video or audio file: $name';
  }

  @override
  String composePickMediaFailed(String error) {
    return 'Couldn\'t select the video / audio: $error';
  }

  @override
  String get composeRasqNotLoggedIn => 'Not logged in to a RASQ account';

  @override
  String composeRasqMediaTooLarge(int mb) {
    return 'When posting to RASQ, each video / audio file can be up to $mb MB';
  }

  @override
  String get composeRasqReplyTextOnly =>
      'RASQ replies are text only (no attachments or polls)';

  @override
  String composeRasqReplyMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ replies can be up to $count characters',
      one: 'RASQ replies can be up to 1 character',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ posts can have up to $count attachments',
      one: 'RASQ posts can have up to 1 attachment',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ posts can be up to $count characters',
      one: 'RASQ posts can be up to 1 character',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxPollChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ posts can have up to $count poll choices',
      one: 'RASQ posts can have up to 1 poll choice',
    );
    return '$_temp0';
  }

  @override
  String get composeRasqPosted => 'Posted to RASQ';

  @override
  String get composeRasqReplyQuota =>
      'You can have up to 100 RASQ replies. Please delete older replies';

  @override
  String get composeRasqPostQuota =>
      'You can have up to 3 RASQ posts. Please delete older posts';

  @override
  String composeRasqPostFailed(String error) {
    return 'Couldn\'t post to RASQ: $error';
  }

  @override
  String get composePolicyConfirmTitle => 'Check before sending';

  @override
  String get composePolicyConfirmSend => 'Send anyway';

  @override
  String get composePolicyConfirmEdit => 'Edit';

  @override
  String get composeSending => 'Sending…';

  @override
  String composeModerationDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Moderation delay: $seconds seconds left',
      one: 'Moderation delay: 1 second left',
    );
    return '$_temp0';
  }

  @override
  String composeUploading(int index, int total) {
    return 'Uploading $index/$total';
  }

  @override
  String composeLinkedFailed(String errors) {
    return 'Linked posting failed: $errors (the main post was sent)';
  }

  @override
  String composeSendFailed(String error) {
    return 'Failed to send: $error';
  }

  @override
  String composePostNoticeForAccount(String account, String message) {
    return '$account: $message';
  }

  @override
  String get composeDraftsButton => 'Drafts';

  @override
  String get composeDirectReplyNote =>
      'Reply to a direct post (only the recipient will see it)';

  @override
  String get composeChooseTargetTooltip => 'Choose post target';

  @override
  String get composeCwHint => 'Content warning..';

  @override
  String get composeCwRemoveTooltip => 'Remove content warning';

  @override
  String get composeDmHint => 'Type a message..';

  @override
  String get composeTextHint => 'Hope something good happens!';

  @override
  String composeHashtagUsers(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag  $count people',
      one: '$tag  1 person',
    );
    return '$_temp0';
  }

  @override
  String get composeToolCamera => 'Camera';

  @override
  String get composeToolImage => 'Image';

  @override
  String get composeToolVideo => 'Video / audio';

  @override
  String get composeToolCw => 'Hide (CW)';

  @override
  String get composeToolPoll => 'Poll';

  @override
  String get composeToolEmoji => 'Emoji';

  @override
  String get composeSendReply => 'Reply';

  @override
  String get composeSend => 'Send';

  @override
  String get composeAttachmentRemove => 'Remove';

  @override
  String get composeAttachmentEdit => 'Edit';

  @override
  String get composeAttachmentUnsensitive => 'Unmark sensitive';

  @override
  String get composeAttachmentSensitive => 'Mark as sensitive';

  @override
  String get composeMediaPickTypeLabel => 'Video / audio';

  @override
  String get composeMediaMotionVideoLabel =>
      'Make a video (plays the attached video inside the tile, with sound)';

  @override
  String get composeMediaMotionAudioLabel =>
      'Make a video (tile still image + attached audio)';

  @override
  String composeMediaMotionAnimatedLabel(int fps, int seconds) {
    return 'Make a video ($seconds s of the animation at $fps fps)';
  }

  @override
  String get composeMediaMotionVideoNote => 'This post has a video attached.';

  @override
  String get composeMediaMotionAudioNote => 'This post has audio attached.';

  @override
  String get composeMediaMotionAnimatedNote =>
      'This post has animation (GIF / animated MFM).';

  @override
  String get composeMediaPostNotOnScreen => 'The post isn\'t on screen';

  @override
  String get composeMediaSourceFetchFailed =>
      'Couldn\'t fetch the original file';

  @override
  String composeMediaFormatUnreadable(String ext) {
    return 'This device can\'t read the $ext format (you can still attach it as a still image)';
  }

  @override
  String composeMediaSourceOpenFailed(String ext, int bytes) {
    return 'Couldn\'t open the original file (.$ext, $bytes bytes)';
  }

  @override
  String get composeMediaTabMine => 'My posts';

  @override
  String get composeMediaTabReacted => 'Reactions';

  @override
  String get composeMediaTabFavorites => 'Bookmarks';

  @override
  String get composeMediaTabSearches => 'Recent searches';

  @override
  String get composeMediaStyleThread => 'Thread';

  @override
  String get composeMediaStyleInline => 'Inline';

  @override
  String get composeMediaPostImageTitle => 'Add note image';

  @override
  String get composeMediaCancel => 'Cancel';

  @override
  String get composeMediaConfirm => 'Done';

  @override
  String get composeMediaNoAccount => 'No accounts';

  @override
  String get composeMediaSearchUnsupported =>
      'Post search isn\'t available on this SNS';

  @override
  String composeMediaTabUnsupported(String tab) {
    return '\"$tab\" isn\'t available on this SNS';
  }

  @override
  String composeMediaFetchFailed(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String get composeMediaCaptureRetry =>
      'With the selected post on screen, tap \"Done\" again';

  @override
  String composeMediaVideoFailed(String error) {
    return 'Couldn\'t make a video: $error';
  }

  @override
  String get composeMediaFilterHistoryHint => 'Filter search history';

  @override
  String get composeMediaFilterListHint => 'Filter list';

  @override
  String get composeMediaFilterFromHistoryTooltip =>
      'Insert from recent searches';

  @override
  String get composeMediaStyleHeading => 'Appearance';

  @override
  String composeMediaSearchResultsTitle(String query) {
    return 'Search results for \"$query\"';
  }

  @override
  String get composeMediaSearchBack => 'Back to recent searches';

  @override
  String composeMediaExcludedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts with limited visibility are not shown.',
      one: '1 post with limited visibility is not shown.',
    );
    return '$_temp0';
  }

  @override
  String get composeMediaAsVideoOffNote => 'Off = still image of that moment';

  @override
  String get composeMediaExporting => 'Making video…';

  @override
  String get composeMediaHistoryEmpty =>
      'No recent searches (searches from the search home will appear here)';

  @override
  String get composeMediaHistoryNoMatch => 'No matching searches';

  @override
  String get composeMediaPostsEmpty => 'No posts';

  @override
  String get composeMediaPostsNoMatch =>
      'No matching posts (\"Load more\" can find more)';

  @override
  String get composeMediaLoadMore => 'Load more';

  @override
  String get composeMfmFnX2 => 'Enlarge 2x';

  @override
  String get composeMfmFnX3 => 'Enlarge 3x';

  @override
  String get composeMfmFnX4 => 'Enlarge 4x';

  @override
  String get composeMfmFnSmall => 'Show smaller';

  @override
  String get composeMfmFnCenter => 'Center';

  @override
  String get composeMfmFnBlur => 'Blur (hover / tap to reveal)';

  @override
  String get composeMfmFnRotate => 'Rotate';

  @override
  String get composeMfmPropRotateDeg => 'Angle (default 90)';

  @override
  String get composeMfmFnFlip => 'Flip';

  @override
  String get composeMfmPropFlipH => 'Horizontal';

  @override
  String get composeMfmPropFlipV => 'Vertical';

  @override
  String get composeMfmFnFg => 'Text color';

  @override
  String get composeMfmPropFgColor => 'Hex (e.g. ff0000)';

  @override
  String get composeMfmFnBg => 'Background color';

  @override
  String get composeMfmPropBgColor => 'Hex (e.g. ffff00)';

  @override
  String get composeMfmFnShake => 'Shake';

  @override
  String get composeMfmPropShakeSpeed => 'e.g. 0.5s';

  @override
  String get composeMfmFnSpin => 'Spin animation';

  @override
  String get composeMfmPropSpinSpeed => 'e.g. 1.5s';

  @override
  String get composeMfmPropSpinLeft => 'Reverse direction';

  @override
  String get composeMfmPropSpinAlternate => 'Back and forth';

  @override
  String get composeMfmPropSpinX => 'Horizontal axis';

  @override
  String get composeMfmPropSpinY => 'Vertical axis';

  @override
  String get composeMfmFnJump => 'Jump';

  @override
  String get composeMfmPropJumpSpeed => 'e.g. 0.75s';

  @override
  String get composeMfmFnBounce => 'Bounce';

  @override
  String get composeMfmPropBounceSpeed => 'e.g. 0.75s';

  @override
  String get composeMfmFnRainbow => 'Rainbow';

  @override
  String get composeMfmPropRainbowSpeed => 'e.g. 1s';

  @override
  String get composeMfmFnTwitch => 'Twitch';

  @override
  String get composeMfmPropTwitchSpeed => 'e.g. 0.5s';

  @override
  String get composeMfmFnJelly => 'Jelly';

  @override
  String get composeMfmPropJellySpeed => 'e.g. 1s';

  @override
  String get composeMfmFnTada => 'Tada';

  @override
  String get composeMfmPropTadaSpeed => 'e.g. 1s';

  @override
  String get composeMfmFnPlain => 'Disable formatting';

  @override
  String get composeMfmFnFont => 'Change font';

  @override
  String get composeMfmPropFontSerif => 'Serif';

  @override
  String get composeMfmPropFontMonospace => 'Monospace';

  @override
  String get composeMfmPropFontCursive => 'Cursive';

  @override
  String get composeMfmPropFontFantasy => 'Fantasy';

  @override
  String get composeMfmFnPosition => 'Shift position';

  @override
  String get composeMfmPropPositionX =>
      'Horizontal (in font-size units, e.g. 0.5)';

  @override
  String get composeMfmPropPositionY =>
      'Vertical (in font-size units, e.g. -1)';

  @override
  String get composeMfmFnScale => 'Scale (up to 5x)';

  @override
  String get composeMfmPropScaleX => 'Horizontal scale (e.g. 0.5)';

  @override
  String get composeMfmPropScaleY => 'Vertical scale (e.g. 1.5)';

  @override
  String get composeMfmFnBorder => 'Border';

  @override
  String get composeMfmPropBorderStyle =>
      'Line style (solid / dashed / dotted, etc.)';

  @override
  String get composeMfmPropBorderWidth => 'Width (px, default 1)';

  @override
  String get composeMfmPropBorderColor => 'Hex (default is the accent color)';

  @override
  String get composeMfmPropBorderRadius => 'Corner radius (px)';

  @override
  String get composeMfmPropBorderNoclip => 'Don\'t clip overflow';

  @override
  String get composeMfmFnRuby => 'Ruby (write as \"text reading\")';

  @override
  String get composeMfmSampleRuby => '漢字 kanji';

  @override
  String get composeMfmFnUnixtime =>
      'Show UNIX time (seconds) as date and time';

  @override
  String get composeMfmFnSparkle => 'Sparkle';

  @override
  String get composeMfmPropDelay => 'Delay start (e.g. 0.5s)';

  @override
  String get composeMfmSearchButton => 'Search';

  @override
  String get composeMfmMarkdownBoldName => 'Bold';

  @override
  String get composeMfmMarkdownBoldDescription => 'Shows as **bold**';

  @override
  String get composeMfmMarkdownItalicName => 'Italic';

  @override
  String get composeMfmMarkdownItalicDescription => 'Shows as *italic*';

  @override
  String get composeMfmMarkdownStrikeName => 'Strikethrough';

  @override
  String get composeMfmMarkdownStrikeDescription =>
      'Shows as ~~strikethrough~~';

  @override
  String get composeMfmMarkdownInlineCodeName => 'Inline code';

  @override
  String get composeMfmMarkdownInlineCodeDescription => 'Shows as `code`';

  @override
  String get composeMfmMarkdownCodeBlockName => 'Code block';

  @override
  String get composeMfmMarkdownCodeBlockDescription =>
      'Shows multi-line code in a box';

  @override
  String get composeMfmMarkdownHeadingName => 'Heading';

  @override
  String get composeMfmMarkdownHeadingDescription =>
      'Add # at the start of a line';

  @override
  String get composeMfmMarkdownLinkName => 'Link';

  @override
  String get composeMfmMarkdownLinkDescription => 'In the form [label](URL)';

  @override
  String get composeMfmClose => 'Close';

  @override
  String get composeMfmSample => 'Sample';

  @override
  String composeMfmSampleWithEmoji(String emoji) {
    return 'Sample $emoji';
  }

  @override
  String get composeMfmBackTooltip => 'Back to list';

  @override
  String get composeMfmApply => 'Apply';

  @override
  String get composeMfmNoProps => 'This function has no properties.';

  @override
  String get composePolicyTypeSexual => 'Sexual content';

  @override
  String get composePolicyTypeViolence => 'Violence / threats';

  @override
  String get composePolicyTypeSelfHarm => 'Self-harm / suicide';

  @override
  String get composePolicyTypeHarassment => 'Abuse / harassment';

  @override
  String get composePolicyTypePersonalInfo =>
      'Personal information (phone numbers, email addresses, home addresses, etc.)';

  @override
  String get composePolicyTypeLink => 'External links';

  @override
  String get composePolicyTypeMedia => 'Images / videos';

  @override
  String get composePolicyTypeStimulus => 'Strong language';

  @override
  String get composePolicyTypeTopic => 'Restricted topics';

  @override
  String get composePolicyWhoGuardian => 'Guardian settings';

  @override
  String get composePolicyWhoSanction => 'Account restrictions';

  @override
  String composePolicyBlockedMediaUnmeasured(String who) {
    return 'Due to $who, images and videos can\'t be sent (this device can\'t check attachments). Please remove the attachments';
  }

  @override
  String composePolicyBlockedUnmeasured(String who, String label) {
    return 'Due to $who, this can\'t be sent right now (this device can\'t check for \"$label\")';
  }

  @override
  String composePolicyBlocked(String who, String label) {
    return 'Due to $who, content containing \"$label\" can\'t be sent. Please revise it';
  }

  @override
  String composePolicyWarn(String label, String who) {
    return 'This may contain \"$label\" ($who). Send anyway?';
  }

  @override
  String customShareAddToRoom(String room) {
    return 'Add to \"$room\"';
  }

  @override
  String customShareProposeToRoom(String room) {
    return 'Propose in \"$room\"';
  }

  @override
  String get customSharePlaceOnProfile => 'Place on profile';

  @override
  String get customShareInviteBySwing => 'Invite via Swing (use together)';

  @override
  String get customShareInstallToShare =>
      'Install it to share on your profile or by invitation';

  @override
  String customAddedToRoom(String name) {
    return 'Added \"$name\" to the room';
  }

  @override
  String customAddToRoomFailed(String error) {
    return 'Couldn\'t add: $error';
  }

  @override
  String customShareProposedToRoom(String name) {
    return 'Proposed \"$name\" in the room';
  }

  @override
  String get customSharePlacedOnProfile => 'Placed on your profile';

  @override
  String customPlaceFailed(String error) {
    return 'Couldn\'t place: $error';
  }

  @override
  String customInvitedBySwingNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return 'Invited via Swing (also notified $_temp0 on RASQ)';
  }

  @override
  String get customInvitedBySwing => 'Invited via Swing';

  @override
  String get customInviteTitle => 'Invite via Swing';

  @override
  String customInviteSendFailed(String error) {
    return 'Couldn\'t send: $error';
  }

  @override
  String customInviteHeading(String title) {
    return 'Invite to \"$title\"';
  }

  @override
  String get customInviteIntroOwnPage =>
      'Delivered via Swing. People who see it will join your page together.';

  @override
  String get customInviteIntroCurrentPage =>
      'Delivered via Swing. People who see it will join the page you have open now.';

  @override
  String get customInviteHelp =>
      'Recipients: tap = deliver Swing · double-tap = also send a RASQ notification 🔔';

  @override
  String get customInviteFollowers => 'Followers';

  @override
  String get customInviteNoLists =>
      'Create a RASQ list to invite the people in it too';

  @override
  String get customInviteTextHint => 'A short message (optional)';

  @override
  String get customInviteTtl => 'Disappears after';

  @override
  String customInviteTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get customInviteSendWithNotify =>
      'Invite via Swing (with notification)';

  @override
  String get customInviteErrorVersionNotAvailable =>
      'This plugin isn\'t distributed in the Store of the RASQ server you\'re connected to (no reviewed version). The sample bundled with the app can\'t be used together';

  @override
  String get customInviteErrorNotShared => 'This isn\'t a shared plugin';

  @override
  String get customInviteErrorSessionNotShareable =>
      'This page\'s session can\'t be invited via Swing';

  @override
  String get customInviteErrorSwingLimit =>
      'You can have up to 20 Swings out at once';

  @override
  String customInviteTargetWithNotify(String label) {
    return '$label (with notification)';
  }

  @override
  String get customInviteTargetHint =>
      'Tap to select or deselect. Double-tap to also send a notification';

  @override
  String get customProfileLimit => 'You can place up to 8 items on your page';

  @override
  String get customProfileSideloadReplace => 'Re-upload (new version)';

  @override
  String get customProfileSideloadRemove => 'Remove from page';

  @override
  String customProfileRemoveFailed(String error) {
    return 'Couldn\'t remove: $error';
  }

  @override
  String customLoadFailed(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String get customProfileEmptyMine =>
      'Use \"+ Add\" to place Markdown pages or custom plugins. Visitors can open them from here.';

  @override
  String get customProfileEmpty => 'No pages yet.';

  @override
  String get customProfileSharedNotStarted => 'Shared (not started yet)';

  @override
  String get customProfileShared => 'Shared';

  @override
  String get customSolo => 'Solo';

  @override
  String customProfileHostPage(String title) {
    return 'Host page for $title';
  }

  @override
  String get customProfileHostPageSubtitle => 'Only visible to you';

  @override
  String get customProfileMdPageWithDraft => 'Page · has an unfinished draft';

  @override
  String get customProfileMdPage => 'Page';

  @override
  String get customProfileUntitled => '(Untitled)';

  @override
  String get customProfileDraft => 'Draft (this device only)';

  @override
  String customProfileSideloadSubtitle(String version) {
    return 'Your own plugin · restricted mode · v$version';
  }

  @override
  String get customMenu => 'Menu';

  @override
  String get customProfileAdd => 'Add';

  @override
  String get customProfileLoginToPlace =>
      'Log in to a RASQ account to place items';

  @override
  String customProfileSideloadPlaced(String name) {
    return 'Placed \"$name\" (it runs in restricted mode on visitors\' devices)';
  }

  @override
  String get customProfileSideloadErrorNotProfilePage =>
      'Only solo page-type plugins with a profile view can be placed on a RASQ page';

  @override
  String get customProfileSideloadErrorLimit =>
      'You can place up to 4 of your own plugins';

  @override
  String get customProfileSideloadErrorInvalidPackage =>
      'Couldn\'t read the package (.rspkg / .rasqpkg)';

  @override
  String get customClose => 'Close';

  @override
  String get customProfileAddTitle => 'Add a page';

  @override
  String get customProfileAddMd => 'Write a Markdown page';

  @override
  String get customProfileAddMdSubtitle =>
      'Drafts stay on this device; \"Publish\" makes it public. MFM uses HTML-like tags';

  @override
  String get customProfileAddSideload =>
      'Place your own plugin (.rspkg / .rasqpkg)';

  @override
  String get customProfileAddSideloadSubtitle =>
      'An unreviewed plugin. It runs in restricted mode (no network access, etc.) on visitors\' devices';

  @override
  String get customProfileAddStoreSection => 'Custom plugins from the Store';

  @override
  String get customProfileAddStoreEmpty =>
      'You haven\'t installed any custom plugins that can be placed on a page';

  @override
  String get customProfileAddStorePlaced => 'Placed (tap to remove)';

  @override
  String get customProfileAddStoreTapToPlace => 'Tap to place';

  @override
  String get customProfileAddStoreHasHostPage => 'Has a host page';

  @override
  String get customListSeparator => ' · ';

  @override
  String customProfileChangeFailed(String error) {
    return 'Couldn\'t change: $error';
  }

  @override
  String get customSearchStore => 'Search the Store';

  @override
  String get customPluginsTitle => 'Custom plugins';

  @override
  String get customPluginsJoinByCode => 'Join with an invite code';

  @override
  String get customPluginsInviteCode => 'Invite code';

  @override
  String get customPluginsJoin => 'Join';

  @override
  String get customPluginsInstalled => 'Installed';

  @override
  String get customPluginsEmpty =>
      'Nothing yet. You can find some under \"Custom\" in the Store.';

  @override
  String get customPluginsShared => 'Shared';

  @override
  String get customPluginsProfile => 'Profile';

  @override
  String get customPluginsSearchStore => 'Find custom plugins in the Store';

  @override
  String get customPluginsInviteNotFound =>
      'No session found for this invite code (it may have been closed)';

  @override
  String get customPluginsInviteTitle => 'Invitation';

  @override
  String get customPluginsJoinFailed => 'Couldn\'t join';

  @override
  String get customPageLoadFailed => 'Couldn\'t load';

  @override
  String customPageNotPagePlugin(String name) {
    return '$name is not a page-type plugin';
  }

  @override
  String customPageSoloPlugin(String name) {
    return '$name is a solo plugin (it can\'t be used together)';
  }

  @override
  String customPageJoinFailed(String error) {
    return 'Couldn\'t join the session: $error';
  }

  @override
  String get customPageNoPage => 'The plugin didn\'t return a page';

  @override
  String customPageWrongSession(String name) {
    return 'This isn\'t a session of $name';
  }

  @override
  String customPageLeftWrongSession(String name) {
    return 'Left because this isn\'t a session of $name';
  }

  @override
  String customPageDisconnectedWithError(String error) {
    return 'Disconnected: $error';
  }

  @override
  String get customPageDisconnected => 'Disconnected';

  @override
  String get customPageError => 'Error';

  @override
  String get customPageMenuInvite => 'Invite (send via Swing)';

  @override
  String get customPageMenuCopyCode => 'Copy invite code';

  @override
  String get customPageMenuCopyLink => 'Copy invite link';

  @override
  String customPageMenuParticipants(int count) {
    return 'Participants ($count)';
  }

  @override
  String get customPageMenuCloseSession => 'Close session';

  @override
  String get customPageViewInStore => 'View in Store';

  @override
  String customPageCodeCopied(String code) {
    return 'Copied invite code $code';
  }

  @override
  String get customPageLinkCopied => 'Copied invite link';

  @override
  String get customPageParticipants => 'Participants';

  @override
  String get customPageCloseConfirmTitle => 'Close the session?';

  @override
  String get customPageCloseConfirmMessage =>
      'Shared values will stop updating on every participant\'s page.';

  @override
  String get customCancel => 'Cancel';

  @override
  String customPageCloseFailed(String error) {
    return 'Couldn\'t close: $error';
  }

  @override
  String get customPageClosedBanner =>
      'This session has been closed (shared values will no longer change)';

  @override
  String get customPageConsentBody =>
      'This runs without installing, only while this page is open (it\'s removed when you close it).';

  @override
  String get customPageConsentPermissions => 'Permissions used';

  @override
  String get customPageConsentAccept => 'Use';

  @override
  String get customPageConsentDecline => 'Cancel';

  @override
  String get customPageNotInstalled => 'Not installed';

  @override
  String get customPageNotInstalledHint =>
      'Install it from the Store to open it';

  @override
  String get customPageOpenFailed => 'Couldn\'t open';

  @override
  String get customClientHostOnly => 'Only the host can deploy';

  @override
  String get customClientSessionClosed => 'The session is closed';

  @override
  String get customClientNoToken => 'No RASQ account token';

  @override
  String customAstellWaitingApproval(String name) {
    return '\"$name\" is waiting for the host\'s approval';
  }

  @override
  String customAstellApproveTitle(String name) {
    return 'Use \"$name\" in this room?';
  }

  @override
  String customAstellApproveMessage(String name) {
    return 'Proposed by $name. Once approved, everyone in the room can open it (people who haven\'t installed it will load it temporarily when opening).';
  }

  @override
  String get customAstellApprove => 'Approve';

  @override
  String customAstellProposed(String name) {
    return 'Proposed \"$name\" (it can be used once the host approves)';
  }

  @override
  String get customAstellEmptyHost =>
      'No plugins are running in this room yet. Add one with \"Add plugin\" below.';

  @override
  String get customAstellEmptyMember =>
      'No plugins are running in this room yet. Ask the host with \"Propose plugin\".';

  @override
  String customAstellInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people using',
      one: '1 person using',
    );
    return '$_temp0';
  }

  @override
  String customAstellInUseAddedBy(int count, String handle) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people using',
      one: '1 person using',
    );
    return '$_temp0 · added by @$handle';
  }

  @override
  String get customAstellOpen => 'Open';

  @override
  String get customAstellRemove => 'Remove from room';

  @override
  String get customAstellAdd => 'Add plugin';

  @override
  String get customAstellPropose => 'Propose plugin';

  @override
  String get devGrantDebugAll => 'Debug build: all permissions';

  @override
  String get devUrlInvalid => 'Enter an http(s) URL';

  @override
  String devUrlLoadFailed(String error) {
    return 'Couldn\'t load from URL: $error';
  }

  @override
  String devBoundaryTimelineFailed(String error) {
    return 'Boundary TL: $error';
  }

  @override
  String devAssetLoadFailed(String error) {
    return 'Failed to load asset: $error';
  }

  @override
  String devPkgLoaded(
    String rootId,
    String version,
    int children,
    String target,
  ) {
    return '.rasqpkg: loaded $rootId $version ($children children) → $target.';
  }

  @override
  String devPkgSigned(String fingerprint) {
    return 'Developer key signature OK (fingerprint $fingerprint). Not reviewed by the Store.';
  }

  @override
  String get devPkgUnsigned =>
      'Unsigned (no .sig.json). Its origin can\'t be verified.';

  @override
  String get devPkgSlotFull =>
      'Registering to a slot gives full features (signed with your own key)';

  @override
  String get devPkgSlotRestricted =>
      'Registering to a slot gives restricted mode (not signed with your own key, so network / GPU / storage.unsafe / interstitial and system FOW / share, composer, mute and URL-opening functions are blocked)';

  @override
  String devPathLoadFailed(String path, String error) {
    return 'Failed to load $path (use an absolute path or one starting with ~/): $error';
  }

  @override
  String get devFowClose => 'Close';

  @override
  String get devFowSemantics => 'Plugin FOW';

  @override
  String get devRegisterNeedsMisskey =>
      'Real registration requires logging in with a Misskey account';

  @override
  String get devTitle => 'WASM plugin test (dev)';

  @override
  String get devHostHint => 'Instance (e.g. misskey.io)';

  @override
  String get devFetchTimeline => 'Fetch TL';

  @override
  String get devBoundaryTimeline => 'Boundary TL';

  @override
  String get devPathHint => 'Import from a .wasm path (empty = bundled asset)';

  @override
  String get devLoad => 'Load';

  @override
  String get devRegisterReal => 'Real registration';

  @override
  String get devUrlHint => 'Load from URL (review test-import link)';

  @override
  String get devUrlLoad => 'Load from URL';

  @override
  String get devOpenedFromLink =>
      'Opened from a link. Check its origin, then press \"Load from URL\" (versions under review run in restricted mode).';

  @override
  String devParentInstalled(String id, String version) {
    return 'Parent (base) plugin: $id $version (installed)';
  }

  @override
  String devParentMissing(String id, String version) {
    return 'Parent (base) plugin: $id $version — install it first';
  }

  @override
  String get devOpenInStore => 'Open in Store';

  @override
  String devGrantDebugNote(String grant, String hint) {
    return '$grant (release builds restrict by tier: $hint)';
  }

  @override
  String devGrantMode(String mode, String hint) {
    return 'This screen: $mode — $hint';
  }

  @override
  String get devModeFull => 'Full features';

  @override
  String get devModeBundled => 'Full features (bundled with app)';

  @override
  String get devModeRestricted => 'Restricted mode';

  @override
  String get devModeSwing => 'Restricted mode (Swing)';

  @override
  String get devSlotRegister => 'Register to slot';

  @override
  String devSlotRegistered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Registered: $count',
    );
    return '$_temp0';
  }

  @override
  String devSlotModeHint(String hint) {
    return 'Slot tier: full / restricted — $hint';
  }

  @override
  String get devSlotReviewed => 'Reviewed';

  @override
  String get devSlotUnregister => 'Unregister';

  @override
  String get devBoundaryHeader =>
      'Boundary session: sns.timeline → Post wire → PostRow';

  @override
  String get devBoundaryClose => 'Close';

  @override
  String devActionFailed(String action, String error) {
    return 'performAction($action) failed: $error';
  }

  @override
  String devReviewImportTooLarge(int maxBytes) {
    return 'Invalid size (exceeds $maxBytes bytes)';
  }

  @override
  String get devReviewImportExpired =>
      'The link has expired or is wrong. Recreate it on the review screen';

  @override
  String devReviewImportHttpFailed(int status) {
    return 'Failed to fetch (HTTP $status)';
  }

  @override
  String devReviewImportBadSize(int bytes) {
    return 'Invalid size ($bytes bytes)';
  }

  @override
  String get dmRoomSettings => 'Settings for this DM';

  @override
  String get dmRetry => 'Reload';

  @override
  String get dmRoomEmpty => 'No messages yet';

  @override
  String get dmTabAll => 'All';

  @override
  String get dmTabFollowing => 'Following';

  @override
  String get dmSettings => 'DM settings';

  @override
  String get dmFollowingEmpty => 'No DMs with people you follow';

  @override
  String get dmNewMessage => 'New message';

  @override
  String get dmUserSearchHint => 'Search by username..';

  @override
  String get dmUserSearchIntro => 'Search for someone to send a DM to.';

  @override
  String get dmUserNotFound => 'No results';

  @override
  String get dmEmptyTitle => 'No DMs';

  @override
  String get dmEmptyHint => 'Direct posts (limited visibility) appear here';

  @override
  String get dmYouPrefix => 'You: ';

  @override
  String get dmMediaPlaceholder => '[Media]';

  @override
  String get homeCreateMissingAccount => '(missing account)';

  @override
  String get homeCreatePost => 'Post';

  @override
  String get homeCreateNone => 'None';

  @override
  String homeCreateNeedsRasqAccount(String label) {
    return '$label requires a RASQ account';
  }

  @override
  String get homeCreateAstellBlocked =>
      'ASTell is blocked by supervision settings';

  @override
  String get homeCreateAccountGone => 'This account no longer exists';

  @override
  String get homeCreate => 'Create';

  @override
  String get homeClose => 'Close';

  @override
  String get homeFabEditorTitle => '＋ button';

  @override
  String homeFabEditorHelp(int count, int max) {
    return 'Drag a button below into a slot to add it (slots swap with each other; drag back to the row below to remove). Up to 3 inside and 4 outside · $count / $max';
  }

  @override
  String get homeHeaderCollapse => 'Collapse header';

  @override
  String get homeTimelineTemp => 'Temporarily change timeline';

  @override
  String get homeTimelineSettings => 'Timeline settings';

  @override
  String get homeTabRecommended => 'Recommended';

  @override
  String get homeEmpty => 'No posts';

  @override
  String get homePullToRefresh => 'Pull down to refresh';

  @override
  String get homeLoadNewer => 'Load newer posts';

  @override
  String get homeNewPostsPill => 'New posts';

  @override
  String get homeNewPostsPillSemantics => 'View new posts';

  @override
  String get homeLoadingNewer => 'Refreshing…';

  @override
  String get homeLoadMoreFailed => 'Failed to load. Retry';

  @override
  String get homeLoadMore => 'Load more';

  @override
  String get homeLoadingMore => 'Loading…';

  @override
  String get homeReload => 'Reload';

  @override
  String homeSwingOf(String name) {
    return '$name\'s Swing';
  }

  @override
  String homeSwingOfSeen(String name) {
    return '$name\'s Swing (viewed)';
  }

  @override
  String homeMySwingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count',
      one: '1',
    );
    return 'My Swings ($_temp0)';
  }

  @override
  String get homeMySwing => 'My Swing';

  @override
  String get homeLiveNoToken => 'No RASQ account token';

  @override
  String homePostAttachmentFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attached files',
      one: '1 attached file',
    );
    return '$_temp0';
  }

  @override
  String get homePostAttachmentLink => '1 attached link';

  @override
  String get homePostShare => 'Share';

  @override
  String get homePostSelectAccount => 'Select account';

  @override
  String get homePostLike => 'Like';

  @override
  String get homePostReaction => 'Reaction';

  @override
  String homePostRepostVia(String handle, String instance) {
    return ' (as @$handle@$instance)';
  }

  @override
  String get homePostUndoRepost => 'Undo Renote';

  @override
  String homePostCw(String cw) {
    return '[CW: $cw]';
  }

  @override
  String homePostAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String get homeActionReply => 'Reply';

  @override
  String get homeActionRebroad => 'Rebroad';

  @override
  String get homeActionQueue => 'Queue';

  @override
  String get homeEditorCropRotate => 'Crop / Rotate';

  @override
  String get homeEditorPaint => 'Paint';

  @override
  String get homeEditorText => 'Text';

  @override
  String get homeEditorPost => 'Note';

  @override
  String get homeEditorMedia => 'Media';

  @override
  String get homeEditorSticker => 'Sticker';

  @override
  String get homeEditorEmoji => 'Emoji';

  @override
  String get homeEditorFilter => 'Filter';

  @override
  String get homeEditorBlur => 'Blur';

  @override
  String get homeEditorTune => 'Adjust';

  @override
  String get homeActionAutoOn => 'Turn on automatically next time';

  @override
  String get homeActionAutoOff => 'Auto-off from now on';

  @override
  String get homeActionAutoReset => 'Reset to plugin default';

  @override
  String get homeChildSafeWindowTab => 'Supervised hours';

  @override
  String get homeCancel => 'Cancel';

  @override
  String get homeBarPost => 'Post action bar';

  @override
  String get homeBarViewer => 'Full-screen action bar';

  @override
  String get homeBarEditorImage => 'Editor bar (image)';

  @override
  String get homeBarEditorVideo => 'Editor bar (video / audio)';

  @override
  String get homeBarEditorSvg => 'Editor bar (SVG)';

  @override
  String get homeBarRasqViewer => 'Full-screen action bar (Swing)';

  @override
  String get homeBarAstell => 'ASTell room bottom row';

  @override
  String get homeBarEditAstellTitle => 'Edit room buttons';

  @override
  String get homeBarEditTitle => 'Edit action bar';

  @override
  String get homeBarSearchPlugins => 'Search plugins';

  @override
  String get homeBarSearchPluginButtons => 'Search plugin buttons';

  @override
  String homeBarSearchSubtitle(String source, String detail) {
    return '$source · $detail';
  }

  @override
  String get homeBarBuiltinEditor => 'Built-in editor';

  @override
  String get homeBarRasqActions => 'RASQ actions';

  @override
  String get homeBarAstellButtons => 'ASTell buttons';

  @override
  String get homeBarSnsActions => 'SNS actions';

  @override
  String get homeBarViewerTogglePlugin =>
      'Full-screen plugin (ON / OFF button)';

  @override
  String get homeBarAstellPlugin => 'ASTell plugin (tap to open that plugin)';

  @override
  String homeBarPluginTags(String tags) {
    return 'Tags: $tags';
  }

  @override
  String get homeBarManualPlacement => ' · Manually placed';

  @override
  String get homeBarAllGenres => 'All';

  @override
  String get homeBarSearchHint => 'Button name / plugin name / tag';

  @override
  String get homeBarSearchEmptyAstell =>
      'No buttons to add. You can add plugins from the Store';

  @override
  String get homeBarSearchEmpty =>
      'No plugins can be placed here. You can add them from the Store';

  @override
  String get homeBarSearchEmptyEditorDetail =>
      'No plugins declare composer.media (add them from the Store)';

  @override
  String get homeBarSearchEmptyAstellDetail =>
      'No hidden buttons / ASTell plugins (astell.action) (add plugins from the Store)';

  @override
  String get homeBarSearchEmptyViewerDetail =>
      'No full-screen plugins / plugins declaring post.action (add them from the Store)';

  @override
  String get homeBarSearchEmptyPostDetail =>
      'No plugins declare post.action (add them from the Store)';

  @override
  String get homeBarSearchNoHits => 'No results';

  @override
  String get homeBarDetailTitle => 'Action details';

  @override
  String get homeBarDetailUnknownDeveloper => 'Unknown provider';

  @override
  String homeBarDetailStats(String rating, int downloads) {
    return '★$rating · $downloads downloads';
  }

  @override
  String get homeBarDetailAction => 'Action';

  @override
  String get homeBarDetailSlot => 'Slot (genre)';

  @override
  String get homeBarDetailConfirm => 'Confirmation';

  @override
  String get homeBarDetailAutomation => 'Automation';

  @override
  String get homeBarDetailTags => 'Tags';

  @override
  String get homeBarIconSearchHint => 'Search by icon name (e.g. star, bolt)';

  @override
  String get homeBarBundleTitle => 'Bundle settings';

  @override
  String get homeBarBundleDissolved => 'Ungrouped';

  @override
  String get homeBarPlugin => 'Plugin';

  @override
  String homeBarBundleAstellMember(String label) {
    return 'Room bottom-row button ($label)';
  }

  @override
  String homeBarBundleSnsMember(String genre) {
    return 'Action provided by an SNS plugin ($genre)';
  }

  @override
  String get homeBarBundleName => 'List name';

  @override
  String get homeBarBundleIcon => 'Icon';

  @override
  String get homeBarBundlePhoto => 'Photo';

  @override
  String get homeBarBundlePhotoFailed => 'Can\'t use this photo';

  @override
  String get homeBarBundleMembers => 'Members';

  @override
  String get homeBarMenuDetail => 'Details';

  @override
  String get homeBarBundleRemoveMember => 'Remove from bundle';

  @override
  String get homeBarDissolveList => 'Ungroup list';

  @override
  String get homeBarMemberMenu => 'Member actions';

  @override
  String get homeBarRasqAccount => 'RASQ account';

  @override
  String get homeBarHelpAstell =>
      'Tap (…) or right-click for the menu. Long-press to reorder; drop onto another icon to group. Tap (+) to add buttons.';

  @override
  String get homeBarHelp =>
      'Tap (…) or right-click for the menu. Long-press to reorder; drop onto another icon to group.';

  @override
  String get homeBarHelpAstellDetail =>
      '(…) / shift + click / right-click for the menu (hide / bundle). Long-press and drag to reorder; release over another icon to bundle. (+) adds hidden buttons or ASTell plugins. When they don\'t fit the width, as many as fit from the start plus the last one (next to the input field) are shown, and the rest go into the room\'s gear menu.';

  @override
  String get homeBarHelpDetail =>
      '(…) / shift + click / right-click for the menu. Long-press and drag to reorder; release over another icon to bundle. Declared plugin buttons and the bundling threshold are in Settings → SNS plugins → \"Plugin buttons\".';

  @override
  String get homeBarRasqBuiltinEditor => 'RASQ (built-in editor)';

  @override
  String get homeBarNewBundleName => 'My list';

  @override
  String get homeBarMenuMakeList => 'Make action list';

  @override
  String get homeBarMenuHide => 'Hide';

  @override
  String get homeBarMenuDelete => 'Delete';

  @override
  String get homeBarMenuListSettings => 'Action list settings';

  @override
  String get homeBarMenuPinList => 'Make fixed list';

  @override
  String get homeBarAddButton => 'Add button';

  @override
  String get homeBarNoHidden => 'No hidden buttons';

  @override
  String get homeBarHiddenLabel => 'Hidden (tap to show):';

  @override
  String homeBarShowHidden(String label) {
    return 'Show $label';
  }

  @override
  String get homeBarResetOrder => 'Reset to default order';

  @override
  String get languageSelfName => 'English';

  @override
  String get languageSettingsTitle => 'Language';

  @override
  String get languageSettingsRowSubtitle => 'App display language';

  @override
  String get languageSettingsCaption =>
      'Choose the language for the app\'s text. If your device\'s language isn\'t supported, Japanese is shown.';

  @override
  String get languageSettingsCaptionDetail =>
      'Choose the language for the app\'s text. \"Use system setting\" follows your device\'s language setting and falls back to Japanese for unsupported languages. The selected language is saved on this device and, if you\'re logged in to a RASQ account, also sent to ORGATE (language for emails and notifications, D-484).';

  @override
  String get languageSettingsSystem => 'Use system setting';

  @override
  String languageSettingsSystemCurrent(String language) {
    return 'Currently $language';
  }

  @override
  String get languageSettingsListHeader => 'Display language';

  @override
  String get listsTitle => 'Lists';

  @override
  String get listsTabAllLabel => 'All';

  @override
  String get listsSearchHint => 'Search lists and clips';

  @override
  String get listsShowPrivateClips => 'Show private clips';

  @override
  String get listsImportTitle => 'Import lists';

  @override
  String get listsCreateTitle => 'Create list';

  @override
  String listsCreateAccountList(String account) {
    return 'List for $account';
  }

  @override
  String get listsRasqCrossSns => 'RASQ lists (cross-SNS)';

  @override
  String get listsCreateConfirm => 'Create';

  @override
  String get listsNameHint => 'List name';

  @override
  String listsCreated(String name) {
    return 'Created \"$name\"';
  }

  @override
  String listsCreateUnsupported(String sns) {
    return 'Lists can\'t be created on $sns';
  }

  @override
  String listsCreateFailed(String error) {
    return 'Couldn\'t create the list: $error';
  }

  @override
  String get listsEmpty => 'No lists';

  @override
  String get listsNoHits => 'No results';

  @override
  String get listsEmptyHint => 'Tap ＋ to create a list';

  @override
  String get listsRasqCreateTitle => 'New RASQ list';

  @override
  String get listsRasqCreateSubtitle =>
      'People from Misskey / Mastodon / Bluesky in one list';

  @override
  String listsSwitchedAccount(String account) {
    return 'Switched to $account';
  }

  @override
  String get listsSectionClips => 'Clips';

  @override
  String get listsSectionLists => 'Lists';

  @override
  String get listsSectionFeeds => 'Custom feeds';

  @override
  String listsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users',
      one: '1 user',
    );
    return '$_temp0';
  }

  @override
  String listsClipNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get listsClipKindHost => 'RASQ (cross-SNS)';

  @override
  String get listsClipKindPrivate => 'Private clip';

  @override
  String get listsClipKindPublic => 'Clip';

  @override
  String get listsSeparator => ' · ';

  @override
  String get listsFeedUnsave => 'Unsave';

  @override
  String get listsFeedSave => 'Save feed';

  @override
  String get listsFeedUnsaveFailed => 'Couldn\'t unsave';

  @override
  String get listsFeedSaveFailed => 'Couldn\'t save';

  @override
  String get listsFeedSaveUnsupported =>
      'This SNS doesn\'t support saving feeds';

  @override
  String get listsNotLoggedIn => 'Not logged in';

  @override
  String listsFeedAlreadyImported(String name) {
    return '\"$name\" is already in your home timeline';
  }

  @override
  String listsFeedImported(String name) {
    return 'Added \"$name\" to your home timeline (check it with the gear in the tab row)';
  }

  @override
  String get listsTabUsers => 'Users';

  @override
  String get listsTabPosts => 'Posts';

  @override
  String get listsTabTopics => 'Topic index';

  @override
  String get listsBlockedByGuardian => 'Your guardian has blocked this list';

  @override
  String get listsTimelineSettingsTooltip => 'List timeline settings';

  @override
  String get listsAddMembers => 'Add members';

  @override
  String listsMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count people',
      one: 'Added 1 person',
    );
    return '$_temp0';
  }

  @override
  String get listsNoUsers => 'No users';

  @override
  String get listsRemoveMember => 'Remove';

  @override
  String get listsReload => 'Reload';

  @override
  String get listsNoPosts => 'No posts';

  @override
  String get listsFeedDefaultTitle => 'Feed';

  @override
  String get listsImportToTimeline => 'Add to timeline';

  @override
  String get listsFeedTimelineSettingsTooltip => 'Feed timeline settings';

  @override
  String get listsImportSearchHintFeeds =>
      'Search custom feeds, or enter a share link / URL';

  @override
  String get listsImportSearchHintRasq =>
      'Search RASQ lists, or enter a share link / URL';

  @override
  String get listsImportSearchHintBoth =>
      'Search custom feeds / RASQ lists, or enter a share link / URL';

  @override
  String get listsImportSearchPlain => 'Search';

  @override
  String get listsImportFeedsHelp =>
      'Search for feeds or paste a URL to show them as list tiles. Tap to go to that feed\'s timeline.';

  @override
  String get listsImportRasqHelp =>
      'Use \"Add\" to bring a RASQ list into your home timeline (this follows the list). Only lists whose members\' info can be retrieved can be added.';

  @override
  String get listsImportGenericHelp =>
      'Search for lists and perform bulk actions.';

  @override
  String get listsImportLocal => 'Import from local';

  @override
  String get listsImportLocalMessage => 'Importing from a file is coming soon.';

  @override
  String get listsImportLocalDetail =>
      'Import from CSV/JSON will be implemented together with the list feature (server side).';

  @override
  String get listsImportPopularFeeds => 'Popular feeds';

  @override
  String get listsImportFeedResults => 'Feed results';

  @override
  String get listsImportEnterQuery => 'Enter a search term or URL';

  @override
  String get listsImportRasqMine => 'RASQ lists (yours / following)';

  @override
  String get listsImportRasqResults => 'RASQ list results';

  @override
  String get listsImportButton => 'Add';

  @override
  String get listsImportHistory => 'History';

  @override
  String get listsImportHistoryEmpty => 'No history';

  @override
  String get listsTopicsEmpty => 'No topics yet';

  @override
  String get listsTopicsEmptyHint =>
      'Once posts accumulate, they\'re divided by topic';

  @override
  String get listsTopicsCaption =>
      'Divided by topic. Tap one to show only posts on that topic.';

  @override
  String get listsTopicsCaptionDetail =>
      'Conversation events (2+ posts, same engine as the relational TL) become chapters, and standalone posts are grouped into one (indexForListTimeline). Headings are words found in the posts (tags / keywords / domains).';

  @override
  String listsTopicTimeRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String listsTopicSubtitle(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return '$time · $_temp0';
  }

  @override
  String listsTopicSubtitleWithPeople(String time, int count, int people) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    String _temp1 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: '1 person',
    );
    return '$time · $_temp0 · $_temp1';
  }

  @override
  String listsTopicSnippet(String name, String body) {
    return '$name: \"$body\"';
  }

  @override
  String listsTopicFilterChip(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return 'Topic: $label ($_temp0)';
  }

  @override
  String get listsTopicFilterClear => 'Clear filter';

  @override
  String listsMemberCandidateSubtitle(String handle, String instance) {
    return '@$handle · $instance';
  }

  @override
  String listsMemberNotPublished(String name) {
    return '$name hasn\'t made their account on this SNS public';
  }

  @override
  String listsMemberSnsNotFound(String name) {
    return 'Couldn\'t find $name\'s SNS account';
  }

  @override
  String get listsPickerConfirm => 'Add';

  @override
  String get listsPickerNoServer => 'Not connected to the RASQ server';

  @override
  String get listsPickerLookupFailed => 'Couldn\'t look it up';

  @override
  String get listsPickerUnavailable => 'Can\'t select';

  @override
  String get listsPickerNone => 'No one';

  @override
  String get listsPickerSearchHint => 'Search users (SNS / RASQ)';

  @override
  String get listsPickerSnsUsers => 'SNS users';

  @override
  String get listsPickerRasqUsers => 'RASQ users';

  @override
  String get listsPickerSnsFollowing => 'Following on SNS';

  @override
  String get listsPickerRasqFollowing => 'Following on RASQ';

  @override
  String get listsPickerRasqNotice =>
      'RASQ users are added via the account on the same SNS that they\'ve made public.';

  @override
  String listsPickerRasqNoticeDetail(String path) {
    return 'From snsAccounts on the Central public page ($path), picks the same SNS as this session (same server preferred, verified preferred) and adds the id looked up with userByHandle.';
  }

  @override
  String listsPickerSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people selected',
      one: '1 person selected',
    );
    return '$_temp0';
  }

  @override
  String get listsPickerRasqBadgeSemantics => 'RASQ user';

  @override
  String get loginBack => 'Back';

  @override
  String get loginTitle => 'Log in to social media';

  @override
  String get loginPluginLoadNote =>
      'Plugins will be loaded before your first login. Please use a good network connection.';

  @override
  String get loginChildSafeBlocked =>
      'Your guardian has blocked adding SNS accounts';

  @override
  String get loginShareDeviceOnly =>
      'This device has been approved by email. Log in to your SNS accounts on this device using the buttons below';

  @override
  String get loginWithBluesky => 'Log in with Bluesky';

  @override
  String get loginWithMisskey => 'Log in with Misskey';

  @override
  String get loginWithMixi2 => 'Log in with mixi2';

  @override
  String get loginWithMastodon => 'Log in with Mastodon';

  @override
  String get loginDiscover => 'Find a service and log in';

  @override
  String get loginRaiInstruction => 'Ask RAi';

  @override
  String get loginShareMailUnavailable => 'Can\'t send right now';

  @override
  String loginShareMailSent(String to) {
    return 'Sent an approval link to $to (valid for 30 minutes). Open it in a browser, log in with your RASQ account, and approve';
  }

  @override
  String get loginShareMailSentVerified =>
      'Sent an approval link to your verified email address (valid for 30 minutes). Open it in a browser, log in with your RASQ account, and approve';

  @override
  String get loginShareMailNoVerified =>
      'No verified email address. Approve on your original device, or log in to your SNS accounts on this device';

  @override
  String get loginShareMailTooMany =>
      'Too many requests. Please wait a while and try again';

  @override
  String get loginShareMailNotSupported =>
      'This server doesn\'t support approval by email';

  @override
  String loginShareMailFailed(String code) {
    return 'Couldn\'t send ($code)';
  }

  @override
  String get loginShareWaiting =>
      'Once you approve sharing on your original device, you\'ll be logged in to all your SNS accounts at once. You can also approve from the link sent to your verified email';

  @override
  String get loginShareMailButton => 'Approve by email (send link)';

  @override
  String get loginBundleTitleThis =>
      'Social media accounts of this RASQ account';

  @override
  String loginBundleTitle(String handle) {
    return 'Social media accounts of @$handle';
  }

  @override
  String get loginBundleHint =>
      'Not logged in on this device yet. Tap to log in.';

  @override
  String get loginBundleUse => 'Use';

  @override
  String get loginBundleLogin => 'Log in';

  @override
  String get loginTermsTitle => 'Plugin terms';

  @override
  String get loginTermsAgree => 'Agree';

  @override
  String loginTermsBullet(String text) {
    return '• $text';
  }

  @override
  String loginSignupDivider(String service) {
    return 'Don\'t have a $service account?';
  }

  @override
  String get loginSignupButton => 'Sign up';

  @override
  String get loginSignupReopen => 'Open sign-up page again';

  @override
  String loginBrowserOpenFailed(String url) {
    return 'Couldn\'t open the browser. URL: $url';
  }

  @override
  String get loginPluginMissingMixi2 => 'mixi2 plugin not found';

  @override
  String loginMixi2BrowserPending(String url) {
    return 'Allow access in the browser, then return to the app: $url';
  }

  @override
  String loginFailed(String error) {
    return 'Couldn\'t log in: $error';
  }

  @override
  String get loginMixi2HostHint => 'Host (e.g. mixi.social)';

  @override
  String get loginMixi2Note =>
      'The official mixi2 API requires an application, so login goes through RASQ\'s server. \"Authenticate in browser\" is unavailable until this is ready.';

  @override
  String get loginMixi2Browser => 'Authenticate in browser';

  @override
  String get loginMixi2Dummy => 'Try with a dummy account';

  @override
  String get loginMixi2DummyNote =>
      'The dummy account doesn\'t use the network. You can check the timeline / like / repost / post / notification flows with posts bundled in the plugin.';

  @override
  String get loginMixi2SignupHint =>
      'Create a mixi2 account in your browser (or the mixi2 app). Once created, come back to this screen and log in with \"Authenticate in browser\".';

  @override
  String get loginPluginMissingBluesky => 'Bluesky plugin not found';

  @override
  String get loginBlueskyHostHint => 'PDS (e.g. bsky.social)';

  @override
  String get loginBlueskyIdHint => 'Handle (e.g. you.bsky.social) or email';

  @override
  String get loginBlueskyPasswordHint => 'App password';

  @override
  String get loginPasswordHide => 'Hide';

  @override
  String get loginPasswordShow => 'Show';

  @override
  String get loginBlueskyPasswordNote =>
      'Use a password created in Bluesky under \"Settings → Privacy and security → App passwords\". Do not enter your main password.';

  @override
  String get loginButton => 'Log in';

  @override
  String get loginBlueskySignupHint =>
      'Sign up via \"Create account\" on Bluesky in your browser. Once registered, create a password in Bluesky under \"Settings → Privacy and security → App passwords\", then log in with your handle and app password above.';

  @override
  String get loginServerUnreachable => 'Couldn\'t connect to the server';

  @override
  String loginServerUnreachableWithError(String error) {
    return 'Couldn\'t connect to the server: $error';
  }

  @override
  String loginAuthStartFailed(String error) {
    return 'Couldn\'t start authentication: $error';
  }

  @override
  String loginAuthCheckFailed(String error) {
    return 'Failed to verify authentication: $error';
  }

  @override
  String get loginSnsTitle => 'Change PDS';

  @override
  String get loginSnsNote =>
      'Changing the PDS changes how URLs are shown outside the app.';

  @override
  String loginSnsHostHint(String example) {
    return 'Enter the destination URL (e.g. $example)';
  }

  @override
  String get loginSnsSearch => 'Search server';

  @override
  String get loginSnsServerSection => 'Server search';

  @override
  String loginSnsMaintainer(String name) {
    return 'Admin: $name';
  }

  @override
  String get loginSnsRegistrationClosed => 'Registration closed';

  @override
  String get loginSnsAuthCheck => 'Check authentication';

  @override
  String get loginSnsReopenBrowser => 'Open browser again';

  @override
  String get loginMisskeyAuthButton => 'Authenticate in browser (MiAuth)';

  @override
  String get loginMastodonAuthButton => 'Authenticate in browser (OAuth)';

  @override
  String get loginMastodonHostHint =>
      'Enter instance URL (e.g. mastodon.social)';

  @override
  String get mediaVizStyleMirror => 'Mirrored bars';

  @override
  String get mediaVizStyleBars => 'Bars from the bottom';

  @override
  String get mediaVizStyleLine => 'Line';

  @override
  String get mediaVizLeftAvatar => 'Account icon';

  @override
  String get mediaVizLeftFile => 'Selected image';

  @override
  String get mediaVizLeftGlyph => 'Music note icon';

  @override
  String get mediaVizLeftNone => 'None (full-width waveform)';

  @override
  String get mediaVizTextBelow => 'Below image';

  @override
  String get mediaVizTextAbove => 'Above image';

  @override
  String get mediaVizQualityFast => 'Fast (960×540)';

  @override
  String get mediaVizQualityStandard => 'Standard (1280×720)';

  @override
  String get mediaVizQualityFine => 'Fine (2560×1440, about 4× slower)';

  @override
  String get mediaWavInvalid => 'Not a WAV file';

  @override
  String get mediaWavMissingChunks => 'WAV fmt / data chunk is missing';

  @override
  String mediaWavUnsupported(int format, int bits) {
    return 'Unsupported WAV (format $format, $bits-bit)';
  }

  @override
  String mediaSeconds(String seconds) {
    return '${seconds}s';
  }

  @override
  String mediaVizTimings(
    String total,
    int frameCount,
    String frames,
    String encode,
    String mux,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      frameCount,
      locale: localeName,
      other:
          'Total $total ($frameCount frames: render $frames / encode $encode / finish $mux)',
      one:
          'Total $total ($frameCount frame: render $frames / encode $encode / finish $mux)',
    );
    return '$_temp0';
  }

  @override
  String get mediaAudioVideoUnsupported =>
      'This device can\'t turn audio into video (Android / iOS / macOS only)';

  @override
  String get mediaViewerSemantics => 'Post';

  @override
  String get mediaViewerBack => 'Back';

  @override
  String get mediaViewerPip => 'Play in PiP';

  @override
  String get mediaViewerMenu => 'Menu';

  @override
  String get mediaViewerShare => 'Share';

  @override
  String get mediaPluginAsking => 'Looking at the image…';

  @override
  String get mediaPluginFound => 'Found';

  @override
  String get mediaPluginNotFound => 'Nothing found';

  @override
  String mediaPluginFailed(String reason) {
    return 'Failed: $reason (turn off and on to retry)';
  }

  @override
  String get mediaPluginFetchFailed => 'Couldn\'t fetch the image';

  @override
  String mediaPluginFetchFailedWithError(String error) {
    return 'Couldn\'t fetch the image ($error)';
  }

  @override
  String get mediaPluginDecodeFailed => 'Couldn\'t read the image';

  @override
  String mediaVideoCannotPlay(String error) {
    return 'Can\'t play: $error';
  }

  @override
  String get mediaVideoBack5 => 'Back 5 seconds';

  @override
  String get mediaVideoPause => 'Pause';

  @override
  String get mediaVideoPlay => 'Play';

  @override
  String get mediaVideoForward5 => 'Forward 5 seconds';

  @override
  String get mediaVideoSpeed => 'Playback speed';

  @override
  String get mediaVideoFowTitle => 'Video';

  @override
  String get mediaVideoFowClose => 'Close';

  @override
  String get mediaSaveAsk => 'Ask every time';

  @override
  String get mediaSavePhotos => 'Photos (camera roll)';

  @override
  String get mediaSaveFiles => 'Files';

  @override
  String get mediaSaveBadFileName => 'Invalid file name for saving';

  @override
  String get mediaSaveOutsideFolder => 'Won\'t write outside the save folder';

  @override
  String get mediaSaveTooManySameName => 'Too many files with the same name';

  @override
  String get mediaSavePhotosDenied =>
      'Saving to Photos isn\'t allowed (allow it in the Settings app)';

  @override
  String get mediaSavedToPhotos => 'Saved to Photos (album \"RASQ\")';

  @override
  String mediaSavedToFilesApp(String folder, String fileName) {
    return 'Saved to RASQ › $folder in the Files app ($fileName)';
  }

  @override
  String mediaSavedToPath(String path) {
    return 'Saved: $path';
  }

  @override
  String get mediaColorBlack => 'Black';

  @override
  String get mediaColorNavy => 'Navy';

  @override
  String get mediaColorInk => 'Ink';

  @override
  String get mediaColorDeepGreen => 'Deep green';

  @override
  String get mediaColorCrimson => 'Crimson';

  @override
  String get mediaColorWhite => 'White';

  @override
  String get mediaColorLightGray => 'Light gray';

  @override
  String get mediaColorYellow => 'Yellow';

  @override
  String get mediaColorSkyBlue => 'Sky blue';

  @override
  String get mediaColorPink => 'Pink';

  @override
  String get mediaColorBlue => 'Blue';

  @override
  String get mediaColorGreen => 'Green';

  @override
  String get mediaColorOrange => 'Orange';

  @override
  String get mediaColorPurple => 'Purple';

  @override
  String get mediaVizCancel => 'Cancel';

  @override
  String get mediaVizConfirm => 'Apply';

  @override
  String get mediaVizSemantics => 'Visualizer settings';

  @override
  String get mediaVizRebuildWarning =>
      'Applying rebuilds the video. Edits made so far will be lost';

  @override
  String mediaVizRebuildDetail(int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other:
          'Frame at the current playback position. Applying re-exports the video ($frames frames). Edits made so far, such as paint and text, will be lost.',
      one:
          'Frame at the current playback position. Applying re-exports the video ($frames frame). Edits made so far, such as paint and text, will be lost.',
    );
    return '$_temp0';
  }

  @override
  String mediaVizRebuildDetailReducedFps(int frames, String fps) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other:
          'Frame at the current playback position. Applying re-exports the video ($frames frames, lowered to ${fps}fps because it\'s long). Edits made so far, such as paint and text, will be lost.',
      one:
          'Frame at the current playback position. Applying re-exports the video ($frames frame, lowered to ${fps}fps because it\'s long). Edits made so far, such as paint and text, will be lost.',
    );
    return '$_temp0';
  }

  @override
  String get mediaVizWaveform => 'Waveform';

  @override
  String get mediaVizBands => 'Number of bands (low → high)';

  @override
  String get mediaVizFrameRate => 'Frame rate';

  @override
  String get mediaVizBarColor => 'Bar color';

  @override
  String get mediaVizBackgroundColor => 'Background color';

  @override
  String get mediaVizLeftImage => 'Left image';

  @override
  String get mediaVizPickImage => 'Choose image';

  @override
  String get mediaVizRepickImage => 'Choose another image';

  @override
  String get mediaVizPickImageHint => 'Music note icon until you choose one';

  @override
  String get mediaVizTitleSection => 'Title / description';

  @override
  String get mediaVizShowTitle => 'Show title / description';

  @override
  String get mediaVizTitleHint => 'Title (file name if empty)';

  @override
  String get mediaVizDescriptionHint => 'Description (optional)';

  @override
  String get mediaVizTextScale => 'Text size';

  @override
  String get mediaVizTextColorAuto => 'Text color: Auto';

  @override
  String get mediaVizBackgroundVideo => 'Background video';

  @override
  String get mediaVizPickVideo => 'Choose video';

  @override
  String get mediaVizRepickVideo => 'Choose another video';

  @override
  String get mediaVizPickVideoHint =>
      'Plays a video instead of the background color (its audio isn\'t used)';

  @override
  String mediaVizVideoSelected(String fileName) {
    return '$fileName — loops if shorter than the audio';
  }

  @override
  String get mediaVizRemoveVideo => 'Remove background video';

  @override
  String get mediaVizDim => 'Dimming over the video';

  @override
  String get mediaVizDimHint => 'Makes the waveform and text easier to read';

  @override
  String get mediaVizFade => 'Fade (image)';

  @override
  String get mediaVizFadeIn => 'Fade in';

  @override
  String get mediaVizFadeOut => 'Fade out';

  @override
  String get mediaVizFadeNone => 'None';

  @override
  String get mediaVizExport => 'Export';

  @override
  String get mediaVizExportCaption => 'Finer settings take longer to export';

  @override
  String get mediaVizExportDetail =>
      'The size the waveform is drawn at (output is always 2560×1440). The left image and text are drawn separately and always in fine detail. Export time is roughly frame count × drawing size (lowering the fps also helps). Using a background video makes it slower.';

  @override
  String mediaVizExportDetailWithLast(String timings) {
    return 'Last export: $timings.\nThe size the waveform is drawn at (output is always 2560×1440). The left image and text are drawn separately and always in fine detail. Export time is roughly frame count × drawing size (lowering the fps also helps). Using a background video makes it slower.';
  }

  @override
  String get nodeprogCatalogGenreGenerate => 'Generate';

  @override
  String get nodeprogCatalogGenreConvert => 'Convert';

  @override
  String get nodeprogCatalogGenreInput => 'Input';

  @override
  String get nodeprogCatalogGenreTimeline => 'Timeline';

  @override
  String get nodeprogCatalogGenreProcess => 'Process';

  @override
  String get nodeprogCatalogGenreCondition => 'Condition';

  @override
  String get nodeprogCatalogGenreFunction => 'Function';

  @override
  String get nodeprogCatalogGenreFetch => 'Fetch';

  @override
  String get nodeprogCatalogGenreComposer => 'Composer';

  @override
  String get nodeprogCatalogGenreStorage => 'Storage';

  @override
  String get nodeprogCatalogClockTitle => 'Clock maker';

  @override
  String get nodeprogCatalogClockDescription =>
      'Emits a clock at a fixed interval. Use it as a trigger, e.g. for auto-refreshing the TL.';

  @override
  String get nodeprogCatalogTextConstTitle => 'Text';

  @override
  String get nodeprogCatalogTextConstDescription =>
      'Outputs the text you write. Connect it to a similarity / keyword reference or to a split input.';

  @override
  String get nodeprogCatalogConvertSplitTitle => 'Split';

  @override
  String get nodeprogCatalogConvertSplitDescription =>
      'Splits text into a text array by a separator (newline / comma / space). Connect it to a keyword list or a save input.';

  @override
  String get nodeprogCatalogConvertJoinTitle => 'Join';

  @override
  String get nodeprogCatalogConvertJoinDescription =>
      'Joins a text array into one text with a separator (newline / comma / space).';

  @override
  String get nodeprogCatalogListFirstTitle => 'Pick a post';

  @override
  String get nodeprogCatalogListFirstDescription =>
      'Picks one post at a given position in a post list (1 = first). Turn its text into text to connect to references or settings.';

  @override
  String get nodeprogCatalogPostTextTitle => 'Post text';

  @override
  String get nodeprogCatalogPostTextDescription =>
      'Turns the text of a single post into text.';

  @override
  String get nodeprogCatalogRandomTitle => 'Random';

  @override
  String get nodeprogCatalogRandomDescription =>
      'Emits a random number for each post. Specify the range like \"1-7\"; include a decimal point to count fractional values too. A seed makes it reproducible.';

  @override
  String get nodeprogCatalogFileTitle => 'File reader';

  @override
  String get nodeprogCatalogFileDescription =>
      'Reads a local file and outputs it as text.';

  @override
  String get nodeprogCatalogTimelineTitle => 'Timeline';

  @override
  String get nodeprogCatalogTimelineDescription =>
      'Final output. Connect a post list and it flows into this screen\'s timeline.';

  @override
  String get nodeprogCatalogTlSourceTitle => 'Fetch timeline';

  @override
  String get nodeprogCatalogTlSourceDescription =>
      'Fetches the selected timeline and passes it on as a post list.';

  @override
  String get nodeprogCatalogTlSourceDetail =>
      'Fetches the selected timeline and passes it on as a post list (with RRL tags).';

  @override
  String get nodeprogCatalogSortTitle => 'Sort';

  @override
  String get nodeprogCatalogSortDescription =>
      'Moves posts matching the conditions connected below to the top (original order is kept).';

  @override
  String get nodeprogCatalogRemoveTitle => 'Remove';

  @override
  String get nodeprogCatalogRemoveDescription =>
      'Removes posts matching the conditions connected below.';

  @override
  String get nodeprogCatalogCondTitle => 'Condition';

  @override
  String get nodeprogCatalogCondDescription =>
      'Checks the specified tag and returns True/False. Chain below for \"and\"; connect in parallel from the same connector for \"or\".';

  @override
  String get nodeprogCatalogNotDescription =>
      'Returns the negation of the conditions connected below.';

  @override
  String get nodeprogCatalogFnInputTitle => 'Function input';

  @override
  String get nodeprogCatalogFnInputDescription =>
      'Entry point of the function body. The post list passed by the caller comes out here (only in the function body editor).';

  @override
  String get nodeprogCatalogFnOutputTitle => 'Function output';

  @override
  String get nodeprogCatalogFnOutputDescription =>
      'Exit point of the function body. The post list connected here becomes the function node\'s output (passed through unchanged if not connected).';

  @override
  String get nodeprogCatalogFilterQueryTitle => 'Search filter';

  @override
  String get nodeprogCatalogFilterQueryDescription =>
      'Only lets through posts matching the search words (\"Exclude\" drops them instead).';

  @override
  String get nodeprogCatalogFilterQueryDetail =>
      'Only lets through posts matching the search words. When the words are empty, this page\'s search words/tags are used. Setting \"Exclude\" to true drops matching posts instead (word mute).';

  @override
  String get nodeprogCatalogMergeTitle => 'Merge';

  @override
  String get nodeprogCatalogMergeDescription =>
      'Merges the connected post lists into one in chronological order.';

  @override
  String get nodeprogCatalogMergeDetail =>
      'Merges the connected post lists into one in chronological order. The same post arriving via different accounts is folded into one card, and you can choose the account with ↓ on the tile.';

  @override
  String get nodeprogCatalogTimelineRelationalTitle => 'Related timeline';

  @override
  String get nodeprogCatalogTimelineRelationalDescription =>
      'The exit of the related timeline\'s filtering.';

  @override
  String get nodeprogCatalogTimelineRelationalDetail =>
      'Final output of the related TL\'s pre-filtering. The connected post list becomes the input for building conversation events (the processing is unchanged).';

  @override
  String get nodeprogCatalogTlListTitle => 'Fetch list TL';

  @override
  String get nodeprogCatalogTlListDescription =>
      'Fetches a Misskey list timeline (specified by list name).';

  @override
  String get nodeprogCatalogTlSearchTitle => 'Fetch search TL';

  @override
  String get nodeprogCatalogTlSearchDescription =>
      'Fetches posts matching the search words.';

  @override
  String get nodeprogCatalogTlDmTitle => 'Fetch DMs';

  @override
  String get nodeprogCatalogTlDmDescription =>
      'Fetches DMs with a person (by handle).';

  @override
  String get nodeprogCatalogTrendTagsTitle => 'Fetch trends';

  @override
  String get nodeprogCatalogTrendTagsDescription =>
      'Outputs the current trend tags as an array of strings (for similarity/keyword inputs).';

  @override
  String get nodeprogCatalogTlFeedTitle => 'Fetch custom feed';

  @override
  String get nodeprogCatalogTlFeedDescription =>
      'Fetches a Bluesky custom feed.';

  @override
  String get nodeprogCatalogTlFeedDetail =>
      'Fetches the timeline of a Bluesky custom feed (feed generator) (specified by at:// URI; in TL customization you can search and choose).';

  @override
  String get nodeprogCatalogTlRasqlistTitle => 'Fetch RASQ list';

  @override
  String get nodeprogCatalogTlRasqlistDescription =>
      'Fetches posts from a RASQ list that groups people across multiple social networks.';

  @override
  String get nodeprogCatalogTlRasqlistDetail =>
      'Fetches posts from a RASQ list (a single list grouping people from Misskey / Mastodon / Bluesky). You can only choose lists whose members\' info you can fetch (you have an account on the same server / follow its members).';

  @override
  String get nodeprogCatalogTrendPostsTitle => 'Fetch trend search results';

  @override
  String get nodeprogCatalogTrendPostsDescription =>
      'Searches the current top trend tags and merges their posts into one output.';

  @override
  String get nodeprogCatalogComposerTargetTitle => 'Post destination';

  @override
  String get nodeprogCatalogComposerTargetDescription =>
      'A candidate account to post to. It becomes the destination when the conditions below match.';

  @override
  String get nodeprogCatalogComposerTargetDetail =>
      'A candidate account to post to. Hang conditions below it, and this account becomes the destination when the post content matches them (higher ones take priority; you can re-select manually).';

  @override
  String get nodeprogCatalogComposerFallbackTitle =>
      'Post in an alternative format';

  @override
  String get nodeprogCatalogComposerFallbackDescription =>
      'When filtered out, posts to this account in a different form.';

  @override
  String get nodeprogCatalogComposerFallbackDetail =>
      'A bypass for when filtering removes this account as a destination. When the condition below (usually Not of the preceding comparison) holds, posts to this account in an alternative format.';

  @override
  String get nodeprogCatalogComposerLinkgateTitle => 'Linked post filter';

  @override
  String get nodeprogCatalogComposerLinkgateDescription =>
      'A filter that only applies to posts sent together.';

  @override
  String get nodeprogCatalogComposerLinkgateDetail =>
      'A filter that only applies to linked posts. Unless the condition below holds, linked posts to this account aren\'t sent (it doesn\'t affect normal destination selection).';

  @override
  String get nodeprogCatalogComposerRegexTitle => 'Post rewrite (regex)';

  @override
  String get nodeprogCatalogComposerRegexDescription =>
      'Replaces part of the text when sending.';

  @override
  String get nodeprogCatalogComposerRegexDetail =>
      'Applies a regex replacement to the text when sending (replaces the parts matching the pattern). When the account is empty, it applies to all destinations.';

  @override
  String get nodeprogCatalogTlMyreactionsTitle => 'Fetch reacted posts';

  @override
  String get nodeprogCatalogTlMyreactionsDescription =>
      'Fetches posts you reacted to in the TL (for building a preference profile).';

  @override
  String get nodeprogCatalogTrendFrameTitle => 'Trend frame';

  @override
  String get nodeprogCatalogTrendFrameDescription =>
      'Final output of the \"Trends\" list on the trend home. Connect tags (a text array) and they appear in the list as is.';

  @override
  String get nodeprogCatalogMlSimilarTitle => 'Similarity (SigLIP)';

  @override
  String get nodeprogCatalogMlSimilarDescription =>
      'Outputs how similar each post is to the reference, from 0 to 1.';

  @override
  String get nodeprogCatalogMlSimilarDetail =>
      'Outputs the similarity between the reference (text/array/vector) and each post as a relative value from 0 to 1 within this TL (0.8 ≈ top 20%). Falls back to n-gram similarity when ML is unavailable.';

  @override
  String get nodeprogCatalogMlGlinerTitle => 'GLiNER extraction';

  @override
  String get nodeprogCatalogMlGlinerDescription =>
      'Extracts characteristic words (by frequency) from a post list and outputs them as an array of strings.';

  @override
  String get nodeprogCatalogMlSiglipTitle => 'SigLIP embedding';

  @override
  String get nodeprogCatalogMlSiglipDescription =>
      'Outputs a summary of the post list\'s tendencies.';

  @override
  String get nodeprogCatalogMlSiglipDetail =>
      'Outputs the post list\'s average embedding (profile) as a vector. Falls back to an n-gram profile when ML is unavailable.';

  @override
  String get nodeprogCatalogStorageSaveTitle => 'Save (storage.safe)';

  @override
  String get nodeprogCatalogStorageSaveDescription =>
      'Saves the connected data.';

  @override
  String get nodeprogCatalogStorageSaveDetail =>
      'Saves the connected data to a slot. storage.safe is a safe place that can also be passed to dependent child plugins (handover on the plugin side is confirmed at first launch).';

  @override
  String get nodeprogCatalogStorageLoadTitle => 'Load (storage.safe)';

  @override
  String get nodeprogCatalogStorageLoadDescription =>
      'Loads data saved in a slot.';

  @override
  String get nodeprogCatalogMlKeywordTitle => 'Keyword match (GLiNER)';

  @override
  String get nodeprogCatalogMlKeywordDescription =>
      'Outputs the number of matches between the keyword (or array) and each post\'s characteristic words.';

  @override
  String get nodeprogCatalogMlTendencyTitle =>
      'Orientation/intensity (profile)';

  @override
  String get nodeprogCatalogMlTendencyDescription =>
      'Outputs how well each post fits your preference settings (0 to 1).';

  @override
  String get nodeprogCatalogMlTendencyDetail =>
      'Outputs, for each post, its fit (0 to 1) to the trend profile in storage.safe (favorite genres/direction, orientation thresholds, intensity caps). Edit the profile with the trend ⚙ on the search home; other nodes can read the same slot.';

  @override
  String get nodeprogCatalogCompareTitle => 'Compare';

  @override
  String get nodeprogCatalogCompareDescription =>
      'Compares a number with a threshold and returns True/False.';

  @override
  String get nodeprogCatalogCompareDetail =>
      'An operator condition that compares a number (similarity, random number, etc.) with a threshold and returns True/False. It is False when the value source isn\'t connected or no value can be obtained (e.g. the slot is empty).';

  @override
  String nodeprogCatalogTypeWithFormat(String type, String format) {
    return '$type ($format)';
  }

  @override
  String nodeprogCatalogPortWithType(String label, String type) {
    return '$label ($type)';
  }

  @override
  String get nodeprogCatalogIoCond => 'Condition';

  @override
  String get nodeprogCatalogIoNone => 'None';

  @override
  String get nodeprogCatalogListSeparator => ' · ';

  @override
  String nodeprogCatalogIoSummary(String inputs, String outputs) {
    return 'Input: $inputs → Output: $outputs';
  }

  @override
  String get nodeprogCatalogCustomFunctionAuthor => 'Custom function';

  @override
  String nodeprogCatalogCustomFunctionCondDescription(String tags) {
    return 'A function you made that takes the conditions $tags.';
  }

  @override
  String nodeprogCatalogCustomFunctionCondDetail(String tags) {
    return 'A custom function that takes the condition tags $tags (its internal wiring is done by a plugin/RAi).';
  }

  @override
  String get nodeprogCatalogCustomFunctionDataDescription =>
      'A function you made.';

  @override
  String get nodeprogCatalogCustomFunctionDataDetail =>
      'A custom function (its internal wiring is done by a plugin/RAi).';

  @override
  String get nodeprogCatalogGenreSortDictionary => 'Sort/dictionary';

  @override
  String get nodeprogCatalogCustomFunctionDefaultName => 'Function';

  @override
  String get nodeprogComponentsTrendFormTilesLabel => 'Get trends';

  @override
  String get nodeprogComponentsTrendFormChipsLabel =>
      'Custom (suggestion chips)';

  @override
  String get nodeprogComponentsTrendFormChipsHeading => 'Search suggestions';

  @override
  String get nodeprogComponentsTrendFormTilesDescription =>
      'Shows candidate words as trend tiles (tap to see that word\'s trend).';

  @override
  String get nodeprogComponentsTrendFormTodayDescription =>
      'Shows posts for the top candidate words together, like Today.';

  @override
  String get nodeprogComponentsTrendFormChipsDescription =>
      'Shows candidate words as search suggestion chips.';

  @override
  String nodeprogComponentsSuggestTitle(String what, String from) {
    return 'Suggest $what from $from';
  }

  @override
  String nodeprogComponentsFilterTitle(String what, String from) {
    return 'Filter $what by $from';
  }

  @override
  String get nodeprogComponentsQueryFilterExcludeTitle =>
      'Search filter (exclude)';

  @override
  String get nodeprogComponentsTendencyTitle =>
      'Orientation/intensity (profile)';

  @override
  String get nodeprogComponentsPluginTitle => 'Custom (TL plugin)';

  @override
  String get nodeprogComponentsDisplayTimeline => 'Standard TL';

  @override
  String get nodeprogComponentsDisplayRelational => 'Related TL';

  @override
  String get nodeprogComponentsDeliveryConfirm =>
      'Review before posting (confirm)';

  @override
  String get nodeprogComponentsDeliveryDraft => 'Create draft only (draft)';

  @override
  String get nodeprogComponentsDeliveryAuto => 'Post directly (auto)';

  @override
  String get nodeprogComponentsSelfDm => 'Messages in this DM';

  @override
  String get nodeprogComponentsSelfSearch => 'Search results for this word';

  @override
  String get nodeprogComponentsSelfToday => 'Today posts';

  @override
  String get nodeprogComponentsSelfTrendWords => 'Trend words';

  @override
  String get nodeprogComponentsSelfList => 'Posts in this list';

  @override
  String get nodeprogComponentsSelfFeed => 'Posts in this feed';

  @override
  String get nodeprogComponentsSelfBundle => 'Posts in the All tab';

  @override
  String get nodeprogComponentsSelfHome => 'Posts in the Following tab';

  @override
  String get nodeprogComponentsSelfSocial => 'Posts in the Recommended tab';

  @override
  String get nodeprogComponentsSelfLocal => 'Posts in the Local tab';

  @override
  String get nodeprogComponentsSelfGlobal => 'Posts in the Global tab';

  @override
  String get nodeprogComponentsSelfRelational => 'Posts in the Related tab';

  @override
  String get nodeprogComponentsSelfTab => 'Posts in this tab';

  @override
  String get nodeprogComponentsTrendTilesNoMl =>
      'Uses an ML model, so it can\'t be used in trend tiles';

  @override
  String get nodeprogComponentsTrendTilesNoPlugin =>
      'Reorders posts (and may use the GPU), so it can\'t be used in trend tiles';

  @override
  String get nodeprogComposerResetConfig => 'Reset this setup';

  @override
  String get nodeprogComposerLearnNone =>
      'Not learned yet (learns as you post)';

  @override
  String get nodeprogComposerLearnNoneDetail =>
      'Learning profile: no confirmed posts yet (learns automatically as you post)';

  @override
  String nodeprogComposerLearnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Learning from $count posts so far',
      one: 'Learning from 1 post so far',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerLearnCountDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Learning profile: $count confirmed posts (manually switched posts are weighted strongly; 90-day half-life)',
      one: 'Learning profile: 1 confirmed post (manually switched posts are weighted strongly; 90-day half-life)',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerRelationStats(int pos, int neg) {
    return 'History: linked $pos times / unlinked on review $neg times';
  }

  @override
  String get nodeprogComposerNoAccounts => 'No accounts';

  @override
  String get nodeprogComposerNoAccountsHint =>
      'Log in to set up conditions for post destinations';

  @override
  String get nodeprogComposerBanner =>
      'Accounts that match your draft become destination candidates';

  @override
  String get nodeprogComposerBannerDetail =>
      'Set up filters per account, and accounts whose filters match the draft (and its internal format) become destination candidates.';

  @override
  String get nodeprogComposerHandEdited =>
      'Destinations were edited in the node editor. Changing them here will overwrite those edits';

  @override
  String get nodeprogComposerHandEditedDetail =>
      'Destinations were edited in the node editor. Changing them here replaces them with the simple setup.';

  @override
  String get nodeprogComposerFiltersHeader => 'Destination filters';

  @override
  String get nodeprogComposerFormatHeader => 'Format';

  @override
  String get nodeprogComposerFormatCaption =>
      'Even when a filter doesn\'t match, the account can stay a candidate in another form';

  @override
  String get nodeprogComposerFormatCaptionDetail =>
      'When a filter doesn\'t match, keeps the account as a candidate with an alternative format (bypasses from the comparison just before it would drop out).';

  @override
  String get nodeprogComposerDeliveryHeader => 'Linked post delivery';

  @override
  String get nodeprogComposerDeliveryCaption =>
      'Settings for sending together with other accounts';

  @override
  String get nodeprogComposerDeliveryCaptionDetail =>
      'How posts are delivered to this account via \"Node-linked\" in multi-select mode, and which source accounts can link to it.';

  @override
  String nodeprogComposerDeliveryTitle(String delivery) {
    return 'Delivery: $delivery';
  }

  @override
  String get nodeprogComposerLinkSourcesLabel =>
      'Source accounts (links only when the main destination is one of these)';

  @override
  String get nodeprogComposerLinkFiltersCaption =>
      'Link filters (apply only when sending together)';

  @override
  String get nodeprogComposerLinkFiltersCaptionDetail =>
      'Link filters (a gate applied only to linked posts; doesn\'t affect destination matching)';

  @override
  String nodeprogComposerFilterDescription(String basis, String what) {
    return 'Becomes a destination candidate when the draft matches this account\'s $basis by $what.';
  }

  @override
  String get nodeprogComposerFilterBasisPosts => 'posts';

  @override
  String get nodeprogComposerFilterBasisReplies => 'replies';

  @override
  String get nodeprogComposerFilterDisabled =>
      'Disabled: this account won\'t be a destination candidate.';

  @override
  String nodeprogComposerLinkOnlySubtitle(String account) {
    return '$account · Link only';
  }

  @override
  String nodeprogComposerAndSubtitle(String account) {
    return '$account · AND';
  }

  @override
  String get nodeprogComposerLinkFilterDescription =>
      'If a linked post doesn\'t meet this condition, it isn\'t sent to this account.';

  @override
  String get nodeprogComposerAndDescription =>
      'Combined with the previous filter using AND.';

  @override
  String get nodeprogComposerDeleteNode => 'Delete node';

  @override
  String nodeprogComposerRegexDescription(String pattern, String replace) {
    return 'Replaces \"$pattern\" with \"$replace\" in the text sent to this account.';
  }

  @override
  String get nodeprogComposerRegexDescriptionEmpty =>
      'Applies a regex replacement to the text when sending (e.g. swapping tags, masking words).';

  @override
  String get nodeprogComposerRegexUnset => 'Post transform (not set)';

  @override
  String nodeprogComposerRegexRule(String pattern, String replace) {
    return '\"$pattern\" → \"$replace\"';
  }

  @override
  String nodeprogComposerExtraNodeSubtitle(String account) {
    return '$account · Extra node';
  }

  @override
  String get nodeprogComposerExtraRegexDescription =>
      'Applied after the transform above.';

  @override
  String get nodeprogComposerCwLabel => 'Content warning';

  @override
  String get nodeprogComposerNoOtherAccounts => 'No other accounts';

  @override
  String get nodeprogComposerRegexMenuTooltip => 'Post transform actions';

  @override
  String get nodeprogComposerFilterMenuTooltip => 'Destination actions';

  @override
  String get nodeprogComposerParamsRegexEnabled => 'Enable post transform';

  @override
  String get nodeprogComposerParamsRegexEnabledSubtitle =>
      'Applies a pattern replacement to the text sent to this account';

  @override
  String get nodeprogComposerParamsExtraRegex =>
      'An extra node applied after the transform above.';

  @override
  String get nodeprogComposerParamsFilterEnabled => 'Enable filter';

  @override
  String get nodeprogComposerParamsFilterEnabledSubtitle =>
      'When off, this account won\'t be a destination candidate';

  @override
  String get nodeprogComposerParamsWhat => 'What to compare?';

  @override
  String get nodeprogComposerParamsRegexDescription =>
      'Applies a regex replacement to the text when sending.';

  @override
  String get nodeprogComposerParamsLinkFilterDescription =>
      'A condition that applies only when sending together.';

  @override
  String get nodeprogComposerParamsLinkFilterDetail =>
      'A gate applied only to linked posts (doesn\'t affect destination matching).';

  @override
  String get nodeprogComposerParamsFilterDescription =>
      'When the draft meets this condition, this account becomes a destination candidate.';

  @override
  String get nodeprogComposerParamsPatternLabel => 'Pattern (regex)';

  @override
  String get nodeprogComposerParamsPatternHint => 'e.g. #spoiler\\s*';

  @override
  String get nodeprogComposerParamsReplaceLabel =>
      'Replacement (empty = remove)';

  @override
  String get nodeprogEditorCanvasInputs => 'Inputs';

  @override
  String get nodeprogEditorCanvasOutputs => 'Outputs';

  @override
  String get nodeprogEditorBadgeDefaultOwner => 'Default';

  @override
  String get nodeprogEditorBadgeNotRegistered => 'Not registered';

  @override
  String get nodeprogEditorBadgeSeparator => ' · ';

  @override
  String get nodeprogEditorNodeTabDefaultLabel => 'Node TL';

  @override
  String get nodeprogEditorInlineEmpty => 'No nodes';

  @override
  String get nodeprogEditorInlineExpandTooltip => 'Edit in full screen';

  @override
  String get nodeprogEditorParamsMissing =>
      'This plugin isn\'t registered (reinstall it from the Store).';

  @override
  String get nodeprogEditorParamsLoading => 'Loading parameters…';

  @override
  String get nodeprogEditorParamsNone => 'This plugin has no parameters.';

  @override
  String get nodeprogEditorCancelButton => 'Cancel';

  @override
  String get nodeprogEditorConfirmButton => 'Done';

  @override
  String get nodeprogEditorParamsTitle => 'Configure node';

  @override
  String get nodeprogEditorPluginSortAuthor => 'TL plugin';

  @override
  String get nodeprogEditorPluginSortDescription =>
      'Sorts posts using the plugin\'s ordering.';

  @override
  String get nodeprogEditorParamsPluginDetail =>
      'Sorts the post list with the plugin\'s sort (tl.sort). Parameters go into the node\'s \"Parameters\" port.';

  @override
  String nodeprogEditorPluginSortTitle(String name) {
    return 'Sort by $name';
  }

  @override
  String get nodeprogEditorPluginSortDetail =>
      'Sorts the post list with the plugin\'s sort (tl.sort).';

  @override
  String get nodeprogEditorTitleFunctionBody => 'Function body';

  @override
  String nodeprogEditorTitleFunctionBodyNamed(String name) {
    return 'Function body — $name';
  }

  @override
  String get nodeprogEditorTitleComposer => 'Customize post targets';

  @override
  String get nodeprogEditorTitleTrend => 'Customize trends';

  @override
  String get nodeprogEditorTitleTimeline => 'Customize timeline';

  @override
  String get nodeprogEditorTabTrendNotes => 'Notes';

  @override
  String get nodeprogEditorTabFollowing => 'Following';

  @override
  String get nodeprogEditorTabTrendUsers => 'Users';

  @override
  String get nodeprogEditorTabBundle => 'Combined';

  @override
  String get nodeprogEditorTabSocial => 'Recommended';

  @override
  String get nodeprogEditorTabRelational => 'Related';

  @override
  String get nodeprogEditorTabLocal => 'Local';

  @override
  String get nodeprogEditorTabGlobal => 'Global';

  @override
  String get nodeprogEditorAddTabTooltip => 'Add tab';

  @override
  String get nodeprogEditorNewTabTitle => 'New tab';

  @override
  String get nodeprogEditorTabNameHint => 'Tab name';

  @override
  String get nodeprogEditorRenameTab => 'Rename tab';

  @override
  String get nodeprogEditorDeleteTab => 'Delete tab';

  @override
  String get nodeprogEditorClearGraph => 'Clear graph';

  @override
  String get nodeprogEditorBundleTabsToggle =>
      'Show node TLs together in the bundle';

  @override
  String get nodeprogEditorPaletteSearchHint => 'Search plugin nodes';

  @override
  String nodeprogEditorConnectTypeMismatch(String from, String to) {
    return 'Can\'t connect: $from → $to (types don\'t match)';
  }

  @override
  String get nodeprogEditorCreateFunction => 'Create custom function';

  @override
  String get nodeprogEditorFunctionNameHint => 'Function name';

  @override
  String get nodeprogEditorFunctionSourceLabel => 'Input source';

  @override
  String get nodeprogEditorFunctionSourceCond => 'Condition';

  @override
  String get nodeprogEditorFunctionSourceData => 'Data';

  @override
  String get nodeprogEditorFunctionCondTagsLabel =>
      'Condition tags (selecting more adds branches at the bottom)';

  @override
  String get nodeprogEditorFunctionInputsLabel => 'Inputs (data types)';

  @override
  String get nodeprogEditorFunctionOutputsLabel => 'Outputs (data types)';

  @override
  String get nodeprogEditorCreateButton => 'Create';

  @override
  String get nodeprogEditorMenuInfo => 'Node info';

  @override
  String get nodeprogEditorMenuEditFunctionBody => 'Edit function body';

  @override
  String get nodeprogEditorMenuStore => 'Go to Plugin Store';

  @override
  String get nodeprogEditorMenuCopy => 'Copy';

  @override
  String get nodeprogEditorMenuPaste => 'Paste';

  @override
  String get nodeprogEditorMenuDelete => 'Delete';

  @override
  String get nodeprogEditorMoreTooltip => 'More';

  @override
  String get nodeprogEditorSearchNodesTooltip => 'Search nodes';

  @override
  String get nodeprogEditorEmptyHint =>
      'Add from the search below (tap for details, long-press to drag)';

  @override
  String get nodeprogEditorToolbarSelect => 'Box select';

  @override
  String get nodeprogEditorToolbarSelectStop => 'Stop box select';

  @override
  String get nodeprogEditorToolbarDeleteSelected => 'Delete selected nodes';

  @override
  String get nodeprogEditorToolbarTidy => 'Tidy up';

  @override
  String get nodeprogEditorToolbarZoomOut => 'Zoom out';

  @override
  String get nodeprogEditorToolbarZoomIn => 'Zoom in';

  @override
  String get nodeprogEditorToolbarFit => 'Fit to view';

  @override
  String get nodeprogEditorPaletteSortChip => 'Sort: Relevance';

  @override
  String get nodeprogEditorPaletteSortRelevance => 'Relevance';

  @override
  String nodeprogEditorPaletteGenreChip(String genre) {
    return 'Genre: $genre';
  }

  @override
  String get nodeprogEditorPaletteGenreAll => 'All';

  @override
  String get nodeprogEditorPaletteSettingsTooltip =>
      'Search settings (coming soon)';

  @override
  String get nodeprogEditorPaletteEmptyTitle => 'No nodes found';

  @override
  String get nodeprogEditorPaletteEmptyHint =>
      'Try different search words or genres';

  @override
  String get nodeprogEditorCreateFunctionDescription =>
      'Choose condition tags or inputs/outputs (data types) to create your own function node. Data functions can be built from nodes.';

  @override
  String nodeprogEditorTileSubtitle(String author, String genre) {
    return '$author · $genre';
  }

  @override
  String get nodeprogEditorBuiltinAuthor => 'Built-in node';

  @override
  String get nodeprogEditorAddToCanvas => 'Add to canvas';

  @override
  String get nodeprogEditorEditFunctionBody => 'Edit body';

  @override
  String get nodeprogEditorDeleteFunction => 'Delete function';

  @override
  String nodeprogEditorInfoGenre(String genre) {
    return 'Genre: $genre';
  }

  @override
  String get nodeprogEditorInfoCondIn => 'Condition (top edge)';

  @override
  String get nodeprogEditorInfoCondOut => 'Condition (bottom edge)';

  @override
  String get nodeprogTimelineTabDmCommon => 'DM (shared)';

  @override
  String get nodeprogTimelineTabThisDm => 'This DM';

  @override
  String get nodeprogTimelineTabTrendPage => 'Trends page';

  @override
  String get nodeprogTimelineTabTrendTl => 'Trend timeline';

  @override
  String get nodeprogTimelineTabThisList => 'This list';

  @override
  String get nodeprogTimelineReorderTabs => 'Reorder tabs';

  @override
  String get nodeprogTimelineShareTab => 'Share across all accounts';

  @override
  String get nodeprogTimelineResetConfig => 'Reset this timeline\'s setup';

  @override
  String get nodeprogTimelineEditAsGraph => 'Edit as graph';

  @override
  String nodeprogTimelinePluginWithVersion(String version) {
    return 'Timeline plugin · v$version';
  }

  @override
  String get nodeprogTimelineAlgoChronoDescription =>
      'Keeps posts in the order they were fetched.';

  @override
  String get nodeprogTimelineAlgoTendencyDescription =>
      'Removes posts that don\'t match your preferences and sorts by best match.';

  @override
  String get nodeprogTimelineAlgoTendencyDetail =>
      'Excludes posts that don\'t fit the trend profile (orientation/intensity, favorite genres) and sorts by fit score.';

  @override
  String nodeprogTimelineAlgoSuggestDescription(
    String from,
    String kind,
    String what,
  ) {
    return 'Moves posts that match $from ($kind) by $what to the top.';
  }

  @override
  String get nodeprogTimelineSuggestFromMyPosts => 'my posts';

  @override
  String get nodeprogTimelineSuggestFromMyReplies => 'my replies';

  @override
  String get nodeprogTimelineSuggestFromReacted => 'posts I reacted to';

  @override
  String get nodeprogTimelineSourceHomeLabel => 'Following (home)';

  @override
  String get nodeprogTimelineSourceRasqTitle => 'Fetch RASQ posts';

  @override
  String get nodeprogTimelineSourceRasqDescription =>
      'Timeline: posts from you and RASQ accounts you follow';

  @override
  String get nodeprogTimelineSourceRasqSearchTitle => 'RASQ search';

  @override
  String get nodeprogTimelineSourceRasqSearchPageQuery =>
      'Search: this page\'s search term / tag (includes people you don\'t follow)';

  @override
  String nodeprogTimelineSourceRasqSearchWord(String word) {
    return 'Search: $word (includes people you don\'t follow)';
  }

  @override
  String get nodeprogTimelineSourceRasqListTitle => 'Fetch RASQ list';

  @override
  String nodeprogTimelineSourceRasqListDescription(String name) {
    return 'RASQ list: $name';
  }

  @override
  String get nodeprogTimelineNotSelected => 'Not selected';

  @override
  String get nodeprogTimelineSectionTitle => 'Section';

  @override
  String nodeprogTimelineSectionDescription(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other:
          'A frame that holds up to $max nodes (shown as a rounded frame in the order added)',
      one: 'A frame that holds up to 1 node (shown as a rounded frame in the order added)',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceAstellTitle => 'ASTell tiles';

  @override
  String nodeprogTimelineSourceAstellDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ASTell rooms open now (up to $count)',
      one: 'ASTell rooms open now (up to 1)',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineSourceSwingDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'People showing a Swing (up to $count)',
      one: 'People showing a Swing (up to 1)',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceTrendFollowingTitle =>
      'Reactions from people you follow';

  @override
  String get nodeprogTimelineSourceTrendFollowingDescription =>
      'Posts from people you follow about this page\'s term / tag';

  @override
  String get nodeprogTimelineTrendPluginAll => 'All installed trend plugins';

  @override
  String nodeprogTimelineTrendPluginMissing(String id) {
    return '$id (not installed)';
  }

  @override
  String get nodeprogTimelineTrendPluginAuthor => 'Trend plugin';

  @override
  String nodeprogTimelineTrendPluginDescription(String name, String form) {
    return '$name · $form';
  }

  @override
  String get nodeprogTimelineCurrentAccount => '(Current account)';

  @override
  String get nodeprogTimelineAllAccounts => 'All accounts';

  @override
  String get nodeprogTimelineSourceTrendTitle => 'Fetch trends';

  @override
  String get nodeprogTimelineSourceTrendTagsAllDescription =>
      'Type: Trend tiles (trending terms from all SNS accounts on your RASQ account)';

  @override
  String get nodeprogTimelineSourceTrendTagsDescription =>
      'Type: Trend tiles (trending terms on this account\'s server)';

  @override
  String get nodeprogTimelineSourceSearchTitle => 'Fetch search results';

  @override
  String get nodeprogTimelineSourceSearchPageQuery =>
      'Search: this page\'s search term / tag';

  @override
  String nodeprogTimelineSourceSearchWord(String word) {
    return 'Search: $word';
  }

  @override
  String get nodeprogTimelineSourceTodayTitle => 'Fetch Today';

  @override
  String get nodeprogTimelineSourceTodayDescription =>
      'Timeline: Today (featured posts)';

  @override
  String nodeprogTimelineSourceSelfTitle(String name) {
    return 'Fetch $name';
  }

  @override
  String get nodeprogTimelineSourceDmTitle => 'Fetch DMs';

  @override
  String get nodeprogTimelineSourceFeedTitle => 'Fetch custom feed';

  @override
  String get nodeprogTimelineSourceListTitle => 'Fetch list timeline';

  @override
  String get nodeprogTimelineSourceTimelineTitle => 'Fetch timeline';

  @override
  String nodeprogTimelineSourceTlDescription(String tl) {
    return 'Timeline: $tl';
  }

  @override
  String nodeprogTimelineSourceDmPeer(String peer) {
    return 'DM: @$peer';
  }

  @override
  String get nodeprogTimelineSourceTrendTlKind =>
      'Type: Trend timeline (search results for top trending tags)';

  @override
  String nodeprogTimelineSourceFeedName(String name) {
    return 'Feed: $name';
  }

  @override
  String nodeprogTimelineSourceListName(String name) {
    return 'List: $name';
  }

  @override
  String get nodeprogTimelineMenuInfo => 'Details';

  @override
  String get nodeprogTimelineMenuEditParams => 'Edit parameters';

  @override
  String get nodeprogTimelineMenuDisable => 'Disable temporarily';

  @override
  String get nodeprogTimelineMenuEnable => 'Re-enable';

  @override
  String get nodeprogTimelineMenuStore => 'Go to the plugin\'s Store page';

  @override
  String get nodeprogTimelineMenuKindToTiles => 'Change type to trend tiles';

  @override
  String get nodeprogTimelineMenuKindToTl => 'Change type to trend timeline';

  @override
  String nodeprogTimelineMenuLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Count: $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineMenuForm(String form) {
    return 'Form: $form';
  }

  @override
  String nodeprogTimelineMenuDisplay(String mode) {
    return 'Display mode: $mode';
  }

  @override
  String nodeprogTimelineLimitItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineInfoProvider(String provider) {
    return 'Provided by: $provider';
  }

  @override
  String nodeprogTimelineInfoSupported(String sns) {
    return 'Supports: $sns';
  }

  @override
  String get nodeprogTimelineReorderAlgorithms => 'Reorder algorithms';

  @override
  String get nodeprogTimelineReorderSources => 'Reorder timelines';

  @override
  String get nodeprogTimelineBannerDmCommon =>
      'These settings apply to all DM pages';

  @override
  String get nodeprogTimelineBannerDmPage =>
      'These settings apply only to this DM page';

  @override
  String get nodeprogTimelineBanner =>
      'Choose what goes into the timeline and how it\'s ordered';

  @override
  String get nodeprogTimelineBannerDmCommonDetail =>
      'Main DM settings. Applied to every DM page without its own settings. Algorithms are applied from top to bottom.';

  @override
  String get nodeprogTimelineBannerDmPageDetail =>
      'Settings for this DM page only (once saved, they take priority over the shared DM settings). Algorithms are applied from top to bottom.';

  @override
  String get nodeprogTimelineBannerDetail =>
      'Specify the timeline\'s algorithms, sources, the timelines to show, and more. Algorithms are applied from top to bottom.';

  @override
  String get nodeprogTimelineCreateNameLabel => 'Timeline name';

  @override
  String get nodeprogTimelineCreateNameHint => 'e.g. Friends / Photos';

  @override
  String get nodeprogTimelineTempSearchOnly =>
      'This timeline is ordered by a plugin. You can only search here';

  @override
  String get nodeprogTimelineTempChanged =>
      'This timeline is temporarily changed (not saved).';

  @override
  String get nodeprogTimelineTempRevert => 'Revert';

  @override
  String get nodeprogTimelineTempSave => 'Save these changes';

  @override
  String get nodeprogTimelineTempNotice =>
      'Changes here are temporary. Your original settings stay the same until you save';

  @override
  String get nodeprogTimelineTempNoticeDetail =>
      'Changes here apply temporarily to this timeline. Your original settings stay the same until you save.';

  @override
  String get nodeprogTimelineCreateCaption =>
      'Choose the timelines to include and the algorithms, then tap \"Done\"';

  @override
  String get nodeprogTimelineHandEdited =>
      'This timeline was edited in the node editor. Changing it here will overwrite those edits';

  @override
  String get nodeprogTimelineHandEditedDetail =>
      'This timeline was edited in the node editor. Changing it here replaces it with the simple setup.';

  @override
  String get nodeprogTimelineAlgorithmsHeader => 'Algorithms';

  @override
  String get nodeprogTimelineAddAlgorithm => 'Add algorithm';

  @override
  String nodeprogTimelineSectionSubtitle(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Section · $count / $max',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineDisabledSuffix => ' · Disabled';

  @override
  String get nodeprogTimelineDisabled => 'Disabled';

  @override
  String get nodeprogTimelineMetaSeparator => ' · ';

  @override
  String get nodeprogTimelineSectionMenuTooltip => 'Section actions';

  @override
  String get nodeprogTimelineAddNode => 'Add node';

  @override
  String get nodeprogTimelineNodeMenuTooltip => 'Node actions';

  @override
  String get nodeprogTimelineSectionRename => 'Change heading';

  @override
  String get nodeprogTimelineSectionRenameTitle => 'Section heading';

  @override
  String get nodeprogTimelineMenuTakeOut => 'Move out of section';

  @override
  String get nodeprogTimelineDisplayHeader => 'Display mode';

  @override
  String nodeprogTimelineDisplayTitle(String mode) {
    return 'Display: $mode';
  }

  @override
  String get nodeprogTimelineDisplaySubtitle =>
      'Show the same posts as a normal timeline, as conversation groups (related timeline), or by who posted them';

  @override
  String get nodeprogTimelineSourcesHeader => 'SNS timelines';

  @override
  String get nodeprogTimelineReorderDone => 'Done reordering';

  @override
  String get nodeprogTimelineTrendPageCaption =>
      'Shown on the search home from top to bottom. Use sections to separate the trends and Today areas';

  @override
  String get nodeprogTimelineTrendPageCaptionDetail =>
      'Shown on the search home from top to bottom. By default there are \"Trends\" (trend tiles from all accounts) and \"Today\" sections. Algorithms apply to the trend tiles (heavy ones can\'t be used).';

  @override
  String get nodeprogTimelineSourcesCaption =>
      'Stacking several merges them into one, and duplicate posts appear once';

  @override
  String get nodeprogTimelineSourcesCaptionDetail =>
      'Stacking several merges them into one stream, and duplicate posts collapse into one card (switch accounts with ↓ on the tile). Post transform plugins are applied on each timeline provider\'s (SNS plugin\'s) side.';

  @override
  String get nodeprogTimelineReorderHint =>
      'Long-press to grab and move. You can also move items into and out of sections (up to 3)';

  @override
  String get nodeprogTimelineAddSource => 'Add timeline';

  @override
  String get nodeprogTimelineClockHeader => 'Auto-refresh';

  @override
  String nodeprogTimelineClockInterval(String interval) {
    return 'Interval: $interval';
  }

  @override
  String get nodeprogTimelineAlgorithmMenuTooltip => 'Algorithm actions';

  @override
  String get nodeprogTimelineSourceMenuTooltip => 'Timeline actions';

  @override
  String nodeprogTimelineTendencyGenres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count favorite genres',
      one: '1 favorite genre',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyDisliked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count disliked',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count examples',
      one: '1 example',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyStimulus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count intensity limits',
      one: '1 intensity limit',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTendencyPinnedTitle =>
      'Orientation/intensity (tendency)';

  @override
  String get nodeprogTimelineTendencyPinnedSubtitle => 'Always last';

  @override
  String get nodeprogTimelineTendencyPinnedEmpty => 'Tendency FOW settings';

  @override
  String get nodeprogTimelineTendencyPinnedInfo =>
      'Applies the orientation/intensity set in the Tendency FOW at the very end of the algorithms. It can\'t be removed here (to change or stop it, use the Tendency FOW)';

  @override
  String get nodeprogTimelineParamsSuggestWhat => 'What to suggest by?';

  @override
  String get nodeprogTimelineParamsSuggestFrom => 'What to learn from?';

  @override
  String get nodeprogTimelineParamsPluginPending =>
      'Settings for this plugin are coming soon.';

  @override
  String get nodeprogTimelineParamsQueryFilter =>
      'When the term is empty, filters by this page\'s search term/tag. You can specify a term in the field below.';

  @override
  String get nodeprogTimelineParamsTendency =>
      'Uses your preference settings. You can change them below.';

  @override
  String get nodeprogTimelineParamsChrono =>
      'Chronological order has no parameters.';

  @override
  String get nodeprogTimelineParamsPluginPendingDetail =>
      'This plugin\'s parameters (RRL settings page) will appear here once node definitions are distributed (Store integration).';

  @override
  String get nodeprogTimelineParamsTendencyDetail =>
      'Uses the trend profile in storage.safe. Use the options below to edit orientation/intensity, favorite genres, and genre picks from actions (same as the trends ⚙ on the search home).';

  @override
  String get nodeprogTimelineParamsTrendPlugin =>
      'Shows the candidate terms from trend plugins in the chosen form.';

  @override
  String get nodeprogTimelineParamsTrendPluginDetail =>
      'Shows the answers (candidate terms) of the trend.suggest slot as: Fetch trends = trend tiles / Today = digest of posts for top terms / Custom = candidate chips. Set the count from ….';

  @override
  String get nodeprogTimelineParamsForm => 'Form';

  @override
  String get nodeprogTimelineParamsRasq =>
      'Includes RASQ posts from you and people you follow. Only shows while you\'re logged in to RASQ.';

  @override
  String get nodeprogTimelineParamsRasqDetail =>
      'Includes posts / Rebroads from you and RASQ accounts you follow. Only shows while you\'re logged in to a RASQ account. No parameters.';

  @override
  String get nodeprogTimelineParamsRasqSearch =>
      'Searches public RASQ posts and includes them. Posts from people you don\'t follow are included too.';

  @override
  String get nodeprogTimelineParamsRasqSearchDetail =>
      'Searches public RASQ posts (whether or not you follow the author) using the term below. If empty, searches this page\'s search term / tag. Set the display mode to \"Users\" to list results as tiles for each poster.';

  @override
  String get nodeprogTimelineParamsRasqList =>
      'Includes posts from a RASQ list. Choosing one below follows that list.';

  @override
  String get nodeprogTimelineParamsRasqListDetail =>
      'Includes posts from a RASQ list (Central gathers posts from the list\'s members when you view it). Below, pick from your lists or lists you follow, or search for a public list. Choosing one follows that list.';

  @override
  String nodeprogTimelineParamsSelfDetail(String name) {
    return 'Includes $name as is. No parameters.';
  }

  @override
  String get nodeprogTimelineParamsAccount => 'Account';

  @override
  String get nodeprogTimelineParamsTlKind =>
      'Timeline type (available on this SNS)';

  @override
  String get nodeprogTimelineParamsList => 'List (from this account)';

  @override
  String get nodeprogTimelineParamsNoLists =>
      'This account has no lists (or they couldn\'t be fetched).';

  @override
  String get nodeprogTimelineParamsFeed =>
      'Custom feed (search and pick in the field below)';

  @override
  String get nodeprogTimelineParamsTendencyEdit =>
      'Trend orientation/intensity';

  @override
  String get nodeprogTimelineParamsGenresEdit => 'Favorite genres/directions';

  @override
  String get nodeprogTimelineParamsPickGenresSubtitle =>
      'Grouped by similar topics, most trending first';

  @override
  String get nodeprogTimelineParamsRasqSearchWordLabel =>
      'Search term (empty = this page\'s term / tag)';

  @override
  String get nodeprogTimelineParamsRasqListSearchLabel =>
      'Search RASQ lists (name / @creator / share link)';

  @override
  String get nodeprogTimelineParamsFeedSearchLabel => 'Search feeds';

  @override
  String get nodeprogTimelineParamsFeedNotFound => 'Not found';

  @override
  String get nodeprogTimelineParamsQueryLabel =>
      'Search term (empty = this page\'s search term)';

  @override
  String get nodeprogTimelineParamsExcludeTitle =>
      'Exclude posts containing this term';

  @override
  String get nodeprogTimelineParamsExcludeSubtitle =>
      'When off, only posts containing it pass';

  @override
  String get nodeprogTimelineCreateTitle => 'Create timeline';

  @override
  String nodeprogTimelineCreateDefaultName(int number) {
    return 'Timeline $number';
  }

  @override
  String get nodeprogTimelineCreateShareTitle => 'Apply to other accounts too?';

  @override
  String get nodeprogTimelineCreateShareMessage =>
      'With \"Apply to all accounts\", this timeline appears on every account, and changes to its contents apply to all of them (you can change this later from the … menu).';

  @override
  String get nodeprogTimelineCreateShareConfirm => 'Apply to all accounts';

  @override
  String get nodeprogTimelineCreateShareCancel => 'Only this account';

  @override
  String get nodeprogTimelineLoadFailed => 'Couldn\'t load';

  @override
  String get nodeprogTimelineNodeTrend => 'Trends';

  @override
  String get nodeprogTimelineNodeTabFallback => 'Node timeline';

  @override
  String get nodeprogTimelineReload => 'Reload';

  @override
  String get nodeprogTimelineAstellEmpty =>
      'No ASTell rooms are open right now';

  @override
  String nodeprogTimelineAstellEmptyQuery(String query) {
    return 'No ASTell rooms for \"$query\"';
  }

  @override
  String get nodeprogTimelineSwingEmpty => 'No Swings right now';

  @override
  String nodeprogTimelineSwingEmptyQuery(String query) {
    return 'No Swings for \"$query\"';
  }

  @override
  String get nodeprogTimelineTrendEmpty => 'No trends yet';

  @override
  String get nodeprogTimelineTrendFollowingNoQuery =>
      'Shown in the trend timeline';

  @override
  String get nodeprogTimelineTrendFollowingEmpty =>
      'No reactions from people you follow yet';

  @override
  String get nodeprogTimelinePostsEmpty => 'Nothing here yet';

  @override
  String get nodeprogTimelineEventsEmpty => 'No conversation groups yet';

  @override
  String get nodeprogTimelineUsersEmpty => 'No one here yet';

  @override
  String nodeprogTimelineUserPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTempSemantics => 'Temporarily change the timeline';

  @override
  String get nodeprogTimelineSearchPrev => 'Previous match';

  @override
  String get nodeprogTimelineSearchNext => 'Next match';

  @override
  String get nodeprogTimelineSearchHint => 'Search this timeline';

  @override
  String get nodeprogTimelineSearchFuzzy => 'Fuzzy search';

  @override
  String get nodeprogTimelineTempClose => 'Close';

  @override
  String get nodeprogTimelineTempTitle => 'Temporarily change timeline';

  @override
  String get nodeprogTimelinePaletteSuggestTitle => 'Suggest';

  @override
  String get nodeprogTimelinePaletteSuggestDescription =>
      'Moves posts similar to your posts and reactions to the top.';

  @override
  String get nodeprogTimelinePaletteSuggestDetail =>
      'Reads [keywords/similarity] from [post content/reactions/conversations] and moves matching posts to the top.';

  @override
  String get nodeprogTimelinePaletteFilterTitle => 'Filter';

  @override
  String get nodeprogTimelinePaletteFilterDescription =>
      'Removes posts that don\'t match your posts and reactions.';

  @override
  String get nodeprogTimelinePaletteFilterDetail =>
      'Reads [keywords/similarity] from [post content/reactions/conversations] and excludes posts that don\'t match (same parameters as Suggest).';

  @override
  String get nodeprogTimelinePaletteQueryFilterTitle => 'Search filter';

  @override
  String get nodeprogTimelinePaletteQueryFilterDescription =>
      'Only lets through posts matching this page\'s search term/tag (or a specified term).';

  @override
  String get nodeprogTimelinePaletteTendencyTitle => 'Orientation/intensity';

  @override
  String get nodeprogTimelinePaletteTendencyDescription =>
      'Removes posts that don\'t match your preferences and sorts by best match.';

  @override
  String get nodeprogTimelinePaletteTendencyDetail =>
      'Excludes posts that don\'t fit the trend profile (favorite genres/directions, orientation threshold, intensity limit) and sorts by fit score. Edit the profile from the trends ⚙ on the search home.';

  @override
  String get nodeprogTimelinePalettePickGenresTitle =>
      'Pick genres from actions';

  @override
  String get nodeprogTimelinePalettePickGenresDescription =>
      'Pick favorite genres from the topics of posts you reacted to.';

  @override
  String get nodeprogTimelinePalettePickGenresDetail =>
      'Groups posts you reacted to by similar topic and, starting with the most trending, lets you mark them \"Like / Don\'t like\" to set favorite genres (the orientation/intensity component uses this profile).';

  @override
  String get nodeprogTimelinePaletteChronoTitle => 'Chronological';

  @override
  String get nodeprogTimelinePaletteChronoDescription =>
      'Keeps posts in the order they were fetched.';

  @override
  String get nodeprogTimelinePaletteThisDmDescription =>
      'Includes the messages on this DM page as is.';

  @override
  String get nodeprogTimelinePaletteThisDmDetail =>
      'Includes the messages on this DM page as is (in the shared settings, each page\'s DMs).';

  @override
  String get nodeprogTimelinePaletteSearchResultsDescription =>
      'Includes the results of searching this page\'s search term / tag with this account.';

  @override
  String get nodeprogTimelinePaletteRasqPostsTitle => 'RASQ posts';

  @override
  String get nodeprogTimelinePaletteRasqPostsDescription =>
      'Includes RASQ posts from you and people you follow.';

  @override
  String get nodeprogTimelinePaletteRasqPostsDetail =>
      'Includes posts / Rebroads from you and RASQ accounts you follow. Can be mixed into the same timeline as SNS posts.';

  @override
  String get nodeprogTimelinePaletteTimelineTitle => 'Timeline';

  @override
  String get nodeprogTimelinePaletteTimelineDescription =>
      'Includes an account\'s timeline. Choose the type after adding.';

  @override
  String get nodeprogTimelinePaletteTimelineDetail =>
      'Includes an account\'s basic timeline. After adding, choose the account and a type the SNS offers (Following / Local / Global / Discover …) on the tile.';

  @override
  String get nodeprogTimelinePaletteListTlTitle => 'List timeline';

  @override
  String get nodeprogTimelinePaletteListTlDescription =>
      'Includes an account\'s list. Choose the list after adding.';

  @override
  String get nodeprogTimelinePaletteListTlDetail =>
      'Includes the timeline of an account and one of its lists (choose on the tile after adding).';

  @override
  String get nodeprogTimelinePaletteFeedTitle => 'Custom feed (Bluesky)';

  @override
  String get nodeprogTimelinePaletteFeedDescription =>
      'Find and include a Bluesky custom feed.';

  @override
  String get nodeprogTimelinePaletteFeedDetail =>
      'Search for and include a Bluesky custom feed (for lists spanning multiple SNS, use \"RASQ list\").';

  @override
  String get nodeprogTimelinePaletteRasqListTitle => 'RASQ list';

  @override
  String get nodeprogTimelinePaletteRasqListDescription =>
      'Includes posts from a list of people across multiple SNS.';

  @override
  String get nodeprogTimelinePaletteRasqListDetail =>
      'Includes posts from a RASQ list (a single list combining people from Misskey / Mastodon / Bluesky). Pick from your lists or lists you follow, or search for a public list. Only lists whose members\' info can be fetched (you have an account on the same server / you follow a member) can be chosen.';

  @override
  String get nodeprogTimelinePaletteTrendDescription =>
      'Includes current trends. Switch the type (trend tiles / trend timeline) after adding.';

  @override
  String get nodeprogTimelinePaletteTrendDetail =>
      'Trend tiles = tiles of the server\'s trending terms; trend timeline = posts from search results for the current top trending tags, merged into one stream.';

  @override
  String get nodeprogTimelinePaletteTrendFollowingDescription =>
      'Shows posts from people you follow about this page\'s term / tag.';

  @override
  String nodeprogTimelinePaletteDmPeerDescription(String peer) {
    return 'Includes DMs with @$peer.';
  }

  @override
  String get nodeprogTimelinePaletteSectionDescription =>
      'A frame that holds up to 3 nodes. Shown under the heading in the order added.';

  @override
  String get nodeprogTimelinePaletteAstellDescription =>
      'Shows currently open ASTell rooms as tiles.';

  @override
  String get nodeprogTimelinePaletteSwingDescription =>
      'Lists people showing a Swing.';

  @override
  String nodeprogTimelinePaletteTrendPluginTitle(String form, String name) {
    return '$form: $name';
  }

  @override
  String nodeprogTimelinePaletteTrendPluginDetail(String form) {
    return '$form (shows the answers of the trend.suggest slot as a node of this form)';
  }

  @override
  String nodeprogTimelinePaletteTodayTitle(String account) {
    return 'Today: $account';
  }

  @override
  String get nodeprogTimelinePaletteSnsPluginAuthor => 'SNS plugin';

  @override
  String get nodeprogTimelinePaletteListsAuthor => 'Lists';

  @override
  String get nodeprogTimelinePaletteTodayDescription =>
      'Includes this account\'s Today (featured posts).';

  @override
  String nodeprogTimelinePaletteTrendTagsTitle(String account) {
    return 'Trends: $account';
  }

  @override
  String get nodeprogTimelinePaletteTrendTagsAllDescription =>
      'Shows trending terms from all SNS accounts on your RASQ account as tiles.';

  @override
  String get nodeprogTimelinePaletteTrendTagsDescription =>
      'Shows trending terms on this account\'s server as tiles.';

  @override
  String nodeprogTimelinePaletteSearchResultsTitle(String account) {
    return 'Search results: $account';
  }

  @override
  String nodeprogTimelinePaletteSelfDescription(String name) {
    return 'Includes $name as is.';
  }

  @override
  String get nodeprogTimelinePaletteRasqSearchDescription =>
      'Searches and includes RASQ posts, including from people you don\'t follow. Use the \"Users\" display mode to show tiles of people.';

  @override
  String get nodeprogTimelinePaletteEmptyTitle => 'No components found';

  @override
  String get nodeprogTimelinePaletteEmptyHint => 'Try a different search term';

  @override
  String get notificationsPrefReaction => 'Notify reactions';

  @override
  String get notificationsPrefRepost => 'Notify renotes';

  @override
  String get notificationsPrefQuote => 'Notify quotes';

  @override
  String get notificationsPrefAstell => 'Notify ASTell';

  @override
  String get notificationsPrefTimer => 'Notify timed bookmarks';

  @override
  String get notificationsPrefPollEnded => 'Notify when polls end';

  @override
  String get notificationsPrefFollow => 'Notify follows';

  @override
  String get notificationsPrefSystem => 'Show system notifications';

  @override
  String get notificationsPrefOther => 'Deliver other notifications';

  @override
  String get notificationsTabAll => 'All';

  @override
  String get notificationsTabFollowing => 'Following';

  @override
  String get notificationsPrefsTitle => 'Notification profile settings';

  @override
  String get notificationsEmptyFollowing =>
      'No notifications from people you follow';

  @override
  String get notificationsClose => 'Close';

  @override
  String get notificationsPrefEnabled => 'Notifications on';

  @override
  String get notificationsPushTitle => 'Receiving push notifications';

  @override
  String get notificationsPushDetail => 'Notification-only access token';

  @override
  String get notificationsQuickReadAll => 'Mark all notifications as read';

  @override
  String get notificationsQuickReadFollowing =>
      'Mark notifications from people you follow as read';

  @override
  String get notificationsQuickOff => 'Turn off notifications';

  @override
  String get notificationsEmpty => 'No notifications';

  @override
  String get notificationsRetry => 'Reload';

  @override
  String get notificationsRemindersHeader =>
      'ASTell rooms with start reminders';

  @override
  String notificationsReminderSchedule(String when) {
    return 'Scheduled for $when';
  }

  @override
  String get notificationsReminderCancel => 'Cancel';

  @override
  String get notificationsSystemFallbackTitle => 'System notification';

  @override
  String notificationsActorsOne(String name) {
    return '$name';
  }

  @override
  String notificationsActorsTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String notificationsActorsMore(String first, String second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$first, $second and $count others',
      one: '$first, $second and 1 other',
    );
    return '$_temp0';
  }

  @override
  String notificationsActionReacted(String names) {
    return '$names reacted to your post';
  }

  @override
  String notificationsActionReposted(String names) {
    return '$names renoted your post';
  }

  @override
  String notificationsActionPollEnded(String names) {
    return '$names\'s poll has ended';
  }

  @override
  String notificationsActionOther(String names) {
    return '$names sent a notification';
  }

  @override
  String get notificationsMenuTooltip => 'Menu';

  @override
  String notificationsFollowFollowed(String name) {
    return '$name followed you';
  }

  @override
  String notificationsFollowRequested(String name) {
    return '$name sent you a follow request';
  }

  @override
  String notificationsFollowAccepted(String name) {
    return '$name accepted your follow request';
  }

  @override
  String notificationsFollowListAdded(String name) {
    return '$name added you to a list';
  }

  @override
  String get notificationsFollowButton => 'Follow';

  @override
  String get notificationsFollowingButton => 'Following';

  @override
  String get notificationsPostReply => 'Reply';

  @override
  String get notificationsPostQuote => 'Quote';

  @override
  String get notificationsPostMention => 'Mention';

  @override
  String get notificationsTimerAstell => 'A bookmarked ASTell is starting!';

  @override
  String get notificationsTimerBookmark => 'Timed bookmark';

  @override
  String get notificationsRasqLoadError => 'Couldn\'t load';

  @override
  String get notificationsRasqEmpty => 'No RASQ notifications';

  @override
  String get notificationsRasqEmptyHint =>
      'Mentions / replies / quotes / Swing invites will appear here';

  @override
  String get notifyPushChannelName => 'RASQ notifications';

  @override
  String get notifyPushChannelDescription =>
      'Mentions, replies, Swing and more';

  @override
  String get notifyOpenAction => 'Open';

  @override
  String get notifyGlimpseChannelName => 'Screen reading';

  @override
  String get notifyGlimpseChannelDescription =>
      'Tap to briefly read the screen you\'re viewing';

  @override
  String get notifyAstellChannelName => 'ASTell starts';

  @override
  String get notifyAstellChannelDescription =>
      'Notifications when bookmarked ASTell rooms start';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingHandleTooShort => 'Use at least 3 characters';

  @override
  String get onboardingHandleTooLong => 'Up to 32 characters';

  @override
  String get onboardingHandleInvalid =>
      'Only lowercase letters, numbers and _ are allowed';

  @override
  String get onboardingAccountTitleNew => 'Create a new RASQ account';

  @override
  String get onboardingAccountTitle => 'Create a RASQ account';

  @override
  String get onboardingAccountDescription =>
      'A RASQ account is the container for \"you\" that bundles the SNS accounts you log in with. Your installed plugins, settings and account bundle can be used on your other devices too.';

  @override
  String get onboardingHandleLabel => 'Username (the name after @)';

  @override
  String get onboardingHandleHelper => '3–32 lowercase letters, numbers or _';

  @override
  String onboardingPasswordLabel(int min) {
    return 'Password ($min+ characters)';
  }

  @override
  String get onboardingPasswordHide => 'Hide';

  @override
  String get onboardingPasswordShow => 'Show';

  @override
  String get onboardingPasswordConfirmLabel => 'Password (confirm)';

  @override
  String get onboardingPasswordMismatch => 'Passwords don\'t match';

  @override
  String get onboardingPasswordCaption =>
      'Used to log in to this account from other devices or the web version.';

  @override
  String get onboardingAgeHeading => 'Age';

  @override
  String get onboardingAgeCaption =>
      'RASQ is for people aged 13 and over. If you\'re under 18, we\'ll confirm your guardian\'s consent on the next page.';

  @override
  String get onboardingNoCentral => 'No RASQ Central server is set';

  @override
  String get onboardingSetCentral => 'Set server';

  @override
  String get onboardingNext => 'Next';

  @override
  String onboardingCreateFailed(String error) {
    return 'Couldn\'t create the RASQ account: $error';
  }

  @override
  String get onboardingTermsTitle => 'Terms of Service and Privacy Policy';

  @override
  String get onboardingTermsNoDraft =>
      'Enter your username and other details on page ① first';

  @override
  String get onboardingTermsRead => 'Read the Terms of Service';

  @override
  String get onboardingPrivacyRead => 'Read the Privacy Policy';

  @override
  String get onboardingAgree =>
      'I agree to the Terms of Service and Privacy Policy';

  @override
  String get onboardingChildSafeHeading => 'Child Safe (under 18)';

  @override
  String onboardingChildSafeNote(String age) {
    return 'People aged $age need their guardian\'s consent. Once linked to a guardian\'s RASQ account, the guardian can decide how RASQ is used (how strong the visible posts can be, usage time and available features) (Settings → Child Safe → Child mode).';
  }

  @override
  String get onboardingGuardianConsent => 'I have my guardian\'s consent';

  @override
  String get onboardingChildLogin => 'Log in with a code from my guardian';

  @override
  String get onboardingChildLoginCaption =>
      'If your guardian created an account for you, don\'t register here — log in with the code you received.';

  @override
  String get onboardingBundleHeading => 'Account bundle';

  @override
  String get onboardingBundleReplace =>
      'Replace with this device\'s SNS accounts';

  @override
  String onboardingBundleReplaceSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bundle the $count logged-in accounts into this RASQ account',
      one: 'Bundle the 1 logged-in account into this RASQ account',
    );
    return '$_temp0';
  }

  @override
  String get onboardingBundleKeep => 'Don\'t replace';

  @override
  String get onboardingBundleKeepSubtitle =>
      'Keep SNS accounts on this device only';

  @override
  String get onboardingTermsContributionNote =>
      '\"Contributing to algorithms and the community\" is not part of this registration (it\'s a separate optional consent, and the default is \"Don\'t share\"). You can delete your RASQ account at any time.';

  @override
  String get onboardingRegister => 'Agree and register';

  @override
  String get onboardingSnsTitle => 'Log in with an SNS account';

  @override
  String get onboardingSnsDescription =>
      'Your RASQ account is ready. Log in with the account of the social network you use. If you don\'t use one yet, you can find a server or list that suits you under \"Find SNS services\".';

  @override
  String onboardingSnsLoginWith(String service) {
    return 'Log in with $service';
  }

  @override
  String get onboardingSnsPluginLoadNote =>
      'Plugins will be loaded before your first login. Please use a good network connection.';

  @override
  String onboardingSignupGuideClosed(String name) {
    return '$name isn\'t accepting new registrations right now, or is invite-only. If you don\'t have an invite link, choose another server.';
  }

  @override
  String onboardingSignupGuideMastodonOpened(String name) {
    return 'Opened the sign-up page for $name. When the server rules appear, read them and tap \"Agree\".';
  }

  @override
  String get onboardingSignupGuideMastodonForm =>
      'Enter a display name, username, email address and password. You can\'t change the username later, so pick one you like.';

  @override
  String get onboardingSignupGuideMastodonMail =>
      'After you tap Sign up, you\'ll get a confirmation email. Open the link in it to verify your email address.';

  @override
  String onboardingSignupGuideOpened(String name) {
    return 'Opened the $name page. Tap \"Sign up\" on the page.';
  }

  @override
  String get onboardingSignupGuideForm =>
      'Choose a username and password. You can\'t change the username later, so pick one you like.';

  @override
  String get onboardingSignupGuideChecks =>
      'Depending on the server, you may be asked for an email address, an invite code or a check that you\'re not a robot. Follow the instructions on screen.';

  @override
  String get onboardingSignupGuideRules =>
      'Read and agree to the server\'s rules (Terms of Service). If asked to confirm your email, open the link in the email you received.';

  @override
  String get onboardingSignupGuideDone =>
      'When registration is finished, tap \"Registered\" below. RASQ will then log in to this server.';

  @override
  String get onboardingSignupGuideThenPost =>
      'Once logged in, the post from earlier will open.';

  @override
  String onboardingSignupGuideThenList(String name) {
    return 'Once logged in, the RASQ list \"$name\" will open.';
  }

  @override
  String get onboardingSignupGuideRasqLater =>
      'You can create a RASQ account later from … in the sidebar.';

  @override
  String get onboardingSignupTitleFallback => 'Sign up for a server';

  @override
  String get onboardingSignupNoTarget => 'No server selected to sign up for';

  @override
  String get onboardingSignupDone => 'Registered (go to login)';

  @override
  String onboardingSignupTitle(String name) {
    return 'Sign up for $name';
  }

  @override
  String get onboardingSignupGuideHeading => 'RAi guide';

  @override
  String get onboardingSignupGuidePrev => 'Previous';

  @override
  String get onboardingSignupNoWebView =>
      'This device can\'t open the sign-up page inside the app. Open it in a browser to sign up, then come back to this screen.';

  @override
  String get onboardingSignupOpenBrowser =>
      'Open the sign-up page in a browser';

  @override
  String onboardingSignupPostNotFound(String account) {
    return 'Couldn\'t find the post from earlier on $account';
  }

  @override
  String get onboardingEntryCreateNew => 'Create a new RASQ account';

  @override
  String get onboardingEntryCreate => 'Create a RASQ account';

  @override
  String get onboardingEntryLogin => 'Log in to a RASQ account';

  @override
  String get onboardingEntryDiscover =>
      'Find social networks (by images, people or RAi)';

  @override
  String onboardingEntryResume(String name) {
    return 'Continue as $name';
  }

  @override
  String onboardingEntryResumeWithHandle(String name, String handle) {
    return 'Continue as $name (@$handle)';
  }

  @override
  String get onboardingEntryResumeFallbackName => 'RASQ account';

  @override
  String get onboardingEntrySnsOnly => 'Use with SNS accounts only';

  @override
  String get onboardingEntrySkip => 'Skip and use on this device only';

  @override
  String get onboardingEntryHaveAccount => 'I have a RASQ account';

  @override
  String get onboardingEntryLoginQuestion => 'Log in to your RASQ account?';

  @override
  String get onboardingEntryCreateQuestion => 'Create a RASQ account?';

  @override
  String get onboardingEntryLoginBody =>
      'When you log in to your RASQ account, your bundled SNS accounts, installed plugins and settings come back to this device.';

  @override
  String get onboardingEntryCreateBody =>
      'A RASQ account is the container for \"you\" that bundles the SNS accounts you log in with. Once created, your installed plugins, settings and how your accounts are bundled are saved to RASQ Central, so you can pick up where you left off on another device.';

  @override
  String get onboardingEntryWebNote =>
      'On the web version, your social media login credentials are stored in a vault on RASQ\'s servers (encrypted with the server\'s key; RASQ\'s servers can decrypt them). You can also use it with social media accounts only, but then your logins are lost when you close this tab.';

  @override
  String get onboardingEntrySnsOnlyNote =>
      'You can also use RASQ with SNS accounts only. In that case, your installed plugins and settings are saved on this device only.';

  @override
  String get onboardingEntrySkipNote =>
      'You can still use RASQ if you skip. In that case, your installed plugins and settings are saved on this device only (you can create an account later from … in the sidebar).';

  @override
  String get onboardingShowcaseTitle => 'Browse servers and lists';

  @override
  String get onboardingShowcaseServersHint => 'Tap a server to sign up for it';

  @override
  String get onboardingShowcaseOpenServer => 'Open server';

  @override
  String get onboardingShowcaseSignupServer => 'Sign up for this server';

  @override
  String get onboardingShowcaseListsHint =>
      'Lists of people across social networks. Tap one to sign up for a server where people on the list are.';

  @override
  String get onboardingShowcaseListCannotSignup =>
      'You can\'t sign up for this list\'s servers from the app';

  @override
  String get onboardingShowcasePickServer =>
      'Which server do you want to sign up for?';

  @override
  String onboardingShowcasePickServerSubtitle(String host, String kind) {
    return '$host · $kind';
  }

  @override
  String onboardingShowcasePostImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return '$_temp0';
  }

  @override
  String get onboardingGenreGame => 'Games';

  @override
  String get onboardingGenreAnime => 'Anime & manga';

  @override
  String get onboardingGenreMusic => 'Music';

  @override
  String get onboardingGenreArt => 'Art & creative';

  @override
  String get onboardingGenrePhoto => 'Photos';

  @override
  String get onboardingGenreFood => 'Food';

  @override
  String get onboardingGenreTech => 'Tech & programming';

  @override
  String get onboardingGenreAnimal => 'Animals & pets';

  @override
  String get onboardingGenreSports => 'Sports';

  @override
  String get onboardingGenreTravel => 'Travel & outings';

  @override
  String get onboardingGenreBooks => 'Books & reading';

  @override
  String get onboardingGenreMovie => 'Movies & TV';

  @override
  String get onboardingGenreNature => 'Seasons & nature';

  @override
  String onboardingPasswordTooShort(int min) {
    return 'Use at least $min characters';
  }

  @override
  String get onboardingPasswordTooLong => 'Up to 256 characters';

  @override
  String get onboardingPasswordRepeated =>
      'Can\'t be the same character repeated';

  @override
  String get onboardingTermsOutdated =>
      'The Terms of Service have been updated. Update the app and try registering again';

  @override
  String get onboardingNoServer => 'No RASQ server is set';

  @override
  String get onboardingHandleTaken => 'This username is already taken';

  @override
  String onboardingHandleUnusable(String error) {
    return 'This username can\'t be used ($error)';
  }

  @override
  String onboardingHandleKept(String reason, String handle) {
    return '$reason. Your username stays @$handle (you can change it in Edit profile)';
  }

  @override
  String onboardingPasswordSetFailed(String error) {
    return 'The account was created, but the password couldn\'t be set ($error). Set it from Settings → \"Account protection\"';
  }

  @override
  String get onboardingRestored =>
      'Switched back to this device\'s RASQ account';

  @override
  String get onboardingNudgeTitle => 'Create a RASQ account?';

  @override
  String get onboardingNudgeMessage =>
      'With a RASQ account, your installed plugins, settings and bundle of social media accounts can be used on your other devices too. Swing and RASQ lists also work through your RASQ account. You can also create one later from … in the sidebar.';

  @override
  String get onboardingNudgeCreate => 'Create';

  @override
  String get onboardingNudgeLogin => 'Log in (if you have one)';

  @override
  String get onboardingNudgeLater => 'Later';

  @override
  String onboardingNudgeCreated(String handle) {
    return 'Created RASQ account @$handle';
  }

  @override
  String get onboardingFeedTitle => 'From public RASQ lists';

  @override
  String get onboardingFeedCaption =>
      'Popular posts from lists of people across social networks';

  @override
  String get onboardingFeedEmpty => 'No posts to show right now';

  @override
  String onboardingFeedListName(String name) {
    return 'List \"$name\"';
  }

  @override
  String get onboardingDiscoverTitle => 'Find SNS services';

  @override
  String get onboardingDiscoverIntro =>
      'Start from what you like to find social network servers and RASQ lists (lists of people across networks) that suit you.';

  @override
  String get onboardingDiscoverContentTitle =>
      'Find from images or content you like';

  @override
  String get onboardingDiscoverContentSubtitle =>
      'Pick an image and circle the part you\'re interested in';

  @override
  String get onboardingDiscoverPeopleTitle =>
      'Find from popular users / influencers';

  @override
  String get onboardingDiscoverPeopleSubtitle =>
      'By the name of someone you like or a topic';

  @override
  String get onboardingDiscoverExportTitle =>
      'Find from data exported from other networks';

  @override
  String get onboardingDiscoverExportSubtitle => 'Coming soon';

  @override
  String get onboardingDiscoverAskTitle => 'Ask RAi';

  @override
  String get onboardingDiscoverAskSubtitle =>
      'Chat to find which social networks suit you';

  @override
  String get onboardingDiscoverRaiBlocked => 'Your guardian has blocked RAi';

  @override
  String onboardingDiscoverCannotLogin(String host) {
    return 'You can\'t log in to $host from the app';
  }

  @override
  String onboardingDiscoverCannotSignup(String host) {
    return 'You can\'t sign up for $host from the app';
  }

  @override
  String get onboardingDiscoverAddAccountBlocked =>
      'Your guardian has blocked adding SNS accounts';

  @override
  String get onboardingDiscoverDummyResult =>
      'Sample results (the server\'s external services aren\'t set up)';

  @override
  String get onboardingDiscoverPeopleWebHeading =>
      'People on social networks (web search)';

  @override
  String get onboardingDiscoverListsHeading => 'RASQ lists';

  @override
  String get onboardingDiscoverServersHeading => 'Servers';

  @override
  String onboardingDiscoverListMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverListOwner(String handle) {
    return 'List by @$handle';
  }

  @override
  String onboardingDiscoverListHosts(String hosts) {
    return 'Servers: $hosts';
  }

  @override
  String get onboardingDiscoverListSeparator => ', ';

  @override
  String get onboardingDiscoverListOpenImport => 'Open and import list';

  @override
  String get onboardingDiscoverListSignup =>
      'Sign up on a server of people in this list';

  @override
  String get onboardingDiscoverLoginButton => 'Log in';

  @override
  String get onboardingDiscoverSignupButton => 'Sign up';

  @override
  String get onboardingDiscoverSearchFailed =>
      'Search didn\'t work. Please wait a while and try again';

  @override
  String get onboardingDiscoverGlimpseStoppedSystem =>
      'Screen reading was stopped (\"Stop sharing\" on the device or the screen locked). Start again from \"Browse in your usual browser\"';

  @override
  String get onboardingDiscoverGlimpseStoppedShort =>
      'The broadcast stopped too soon to read anything. Open the page you want in your browser, then stop it';

  @override
  String get onboardingDiscoverGlimpseStoppedTimeout =>
      'Stopped getting ready to read the screen after 10 minutes';

  @override
  String get onboardingDiscoverGlimpseStoppedKilled =>
      'The device stopped screen reading. Please start again';

  @override
  String get onboardingDiscoverGlimpseStoppedEmpty =>
      'Couldn\'t read the screen (no capture was taken)';

  @override
  String get onboardingDiscoverGlimpseFailed => 'Couldn\'t read the screen';

  @override
  String get onboardingDiscoverGlimpseBroadcastDenied =>
      'The screen broadcast didn\'t start. To read the screen, tap again and choose \"Start Broadcast\" (only the last 3 seconds before you stop the broadcast are read)';

  @override
  String get onboardingDiscoverGlimpseDenied =>
      'Screen reading wasn\'t allowed. To read the screen, tap again and choose \"Start\" (only the 3 seconds after you tap the button are read)';

  @override
  String get onboardingDiscoverGlimpseNotificationsDenied =>
      'Couldn\'t show a notification. The button to read the screen appears in a notification, so allow notifications for RASQ in your device settings';

  @override
  String get onboardingDiscoverGlimpseUnavailable =>
      'Screen reading isn\'t available on this device. Pick an image or search in the in-app browser';

  @override
  String get onboardingDiscoverNotificationFailed =>
      'Couldn\'t show a notification. Allow notifications for RASQ in your device settings';

  @override
  String get onboardingDiscoverGlimpseResultMissing =>
      'The captured screen wasn\'t found (it expired or was already sent)';

  @override
  String onboardingDiscoverPicksFull(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'You can add up to $max images. Remove one before adding more',
      one: 'You can add up to 1 image. Remove it before adding another',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickFailed => 'Couldn\'t load the image';

  @override
  String onboardingDiscoverPicksOver(int over, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      over,
      locale: localeName,
      other: 'You can add up to $max images. $over images weren\'t added',
      one: 'You can add up to $max images. 1 image wasn\'t added',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPicksUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images couldn\'t be loaded',
      one: '1 image couldn\'t be loaded',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverNoticeSeparator => '. ';

  @override
  String onboardingDiscoverPicksSkipped(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Removed $count images that didn\'t fit the upload limits (10 MiB each, 24 MiB total, up to $max images)',
      one:
          'Removed 1 image that didn\'t fit the upload limits (10 MiB each, 24 MiB total, up to $max images)',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverImageFormat =>
      'Choose a JPEG, PNG or WebP image';

  @override
  String get onboardingDiscoverImageFormatSize =>
      'Choose a JPEG, PNG or WebP image up to 10 MiB';

  @override
  String get onboardingDiscoverNoCentral => 'No RASQ Central server is set';

  @override
  String get onboardingDiscoverContentIntro =>
      'Pick images you like and circle the part you\'re interested in, and RAi will come up with search terms. Images aren\'t stored on the server (they\'re discarded after the search).';

  @override
  String onboardingDiscoverPicksCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count / $max images. Tap to re-circle, long-press to reorder',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickImages => 'Pick images';

  @override
  String get onboardingDiscoverAddImages => 'Add images';

  @override
  String get onboardingDiscoverTakePhoto => 'Take a photo';

  @override
  String get onboardingDiscoverSearchOne => 'Search with this image';

  @override
  String onboardingDiscoverSearchMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Search with these $count images',
      one: 'Search with this image',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverOtherWays => 'Other ways';

  @override
  String get onboardingDiscoverGlimpseButton => 'Browse in your usual browser';

  @override
  String get onboardingDiscoverBrowseButton => 'Search in the in-app browser';

  @override
  String get onboardingDiscoverGlimpseCancel => 'Cancel';

  @override
  String onboardingDiscoverGlimpseCapturing(int elapsed, int total) {
    return 'Reading the screen ($elapsed / $total s)';
  }

  @override
  String onboardingDiscoverGlimpseDone(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: 'Read the screen for $seconds s ($frames frames)',
      one: 'Read the screen for $seconds s (1 frame)',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverGlimpseDoneDummy(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other:
          'Read the screen for $seconds s ($frames frames). This is a prototype, so the captures are dummies',
      one:
          'Read the screen for $seconds s (1 frame). This is a prototype, so the capture is a dummy',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPictureIndex(int index) {
    return 'Image $index';
  }

  @override
  String onboardingDiscoverFrameIndex(int index) {
    return 'Frame $index';
  }

  @override
  String get onboardingDiscoverQueryHeading => 'Search terms';

  @override
  String get onboardingDiscoverNoResults =>
      'No matching lists or servers were found';

  @override
  String get onboardingDiscoverPickWhole => 'Whole';

  @override
  String get onboardingDiscoverPickRect => 'Rectangle';

  @override
  String get onboardingDiscoverPickLasso => 'Lasso';

  @override
  String get onboardingDiscoverPickRemove => 'Remove';

  @override
  String get onboardingDiscoverGlimpseDummyNote =>
      'This is a prototype, so it sends a dummy capture without reading the screen';

  @override
  String get onboardingDiscoverCaptureFailed => 'Couldn\'t read this screen';

  @override
  String get onboardingDiscoverBrowseAddressHint => 'Search terms / URL';

  @override
  String get onboardingDiscoverBrowseCapture => 'Find from this page';

  @override
  String get onboardingDiscoverManualIntro =>
      'The in-app browser isn\'t available on this device. Browse in your usual browser, then paste the page URL and any text that caught your eye.';

  @override
  String get onboardingDiscoverManualOpenBrowser => 'Open browser';

  @override
  String get onboardingDiscoverManualUrl => 'Page URL';

  @override
  String get onboardingDiscoverManualText =>
      'Text that caught your eye (optional)';

  @override
  String get onboardingDiscoverManualSubmit => 'Search with this';

  @override
  String get onboardingDiscoverPeopleIntro =>
      'Enter the name of someone you like or a topic you\'re interested in. We\'ll search public RASQ lists first.';

  @override
  String get onboardingDiscoverPeopleQueryLabel => 'Name / topic';

  @override
  String get onboardingDiscoverPeopleQueryHint =>
      'e.g. train photography, illustrators';

  @override
  String get onboardingDiscoverPeopleSearch => 'Search';

  @override
  String get onboardingDiscoverPeopleNotFound => 'Not found in RASQ lists';

  @override
  String get onboardingDiscoverPeopleNotFoundHint =>
      'Try finding from images or pages you like, or ask RAi.';

  @override
  String get onboardingDiscoverPeopleTryContent =>
      'Find from images or content';

  @override
  String get onboardingDiscoverPeopleBrave =>
      'Nothing in RASQ lists, so these are suggestions from a web search';

  @override
  String get onboardingDiscoverPersonOpenProfile => 'Open profile in browser';

  @override
  String get onboardingDiscoverPersonLists => 'RASQ lists this person is in';

  @override
  String get onboardingDiscoverAskFailed =>
      'Couldn\'t answer. Please wait a while and ask again';

  @override
  String get onboardingDiscoverAskEmptyTitle =>
      'Let\'s find a social network that suits you!';

  @override
  String get onboardingDiscoverAskEmptyBody =>
      'Tell me what you like, what you want to see, and what kind of people you want to connect with. I\'ll find social network servers and RASQ lists that suit you.';

  @override
  String get onboardingDiscoverAskEmptyCloud =>
      'Your conversation is sent to RAi (cloud) on RASQ\'s server.';

  @override
  String get onboardingDiscoverAskModelLabel => 'RAi (cloud)';

  @override
  String get onboardingDiscoverAskHint => 'What do you like?';

  @override
  String get onboardingDiscoverEditorTitle => 'Circle to search';

  @override
  String onboardingDiscoverEditorTitleStep(String step) {
    return 'Circle to search ($step)';
  }

  @override
  String get onboardingDiscoverEditorHint =>
      'Circle the part you want to search for. If you confirm without circling, the whole image is used. Use two fingers to zoom and pan.';

  @override
  String get onboardingDiscoverEditorHintSelected =>
      'Only the circled part is cropped and searched. Drawing again replaces the selection.';

  @override
  String get onboardingDiscoverEditorToolRect => 'Rectangle';

  @override
  String get onboardingDiscoverEditorToolLasso => 'Lasso';

  @override
  String get onboardingDiscoverEditorResetView => 'Reset zoom';

  @override
  String get onboardingDiscoverEditorClear => 'Clear selection';

  @override
  String get onboardingDiscoverEditorDoneWhole => 'Done (whole image)';

  @override
  String get onboardingDiscoverEditorDone => 'Done';

  @override
  String get onboardingDiscoverGlimpseArmedBroadcast =>
      'Screen broadcast started. Open the page you want in your browser, then stop the broadcast from the red indicator at the top of the screen (or Control Center). Only the last 3 seconds before stopping are read, and results appear when you return to RASQ.';

  @override
  String get onboardingDiscoverGlimpseArmedNotification =>
      'A notification has been shown. Open the page you want in your browser, then tap the notification. Tapping it reads that screen for just 3 seconds.';

  @override
  String get onboardingDiscoverGlimpseNotificationTitle => 'Find with RASQ';

  @override
  String get onboardingDiscoverGlimpseNotificationBody =>
      'Tap to read the screen you\'re viewing for just 3 seconds';

  @override
  String get onboardingDiscoverApiImageFormat =>
      'Only jpeg / png / webp images can be sent';

  @override
  String get onboardingDiscoverApiImageSize =>
      'Images must be 10 MiB or smaller';

  @override
  String get onboardingDiscoverApiImageAndFrames =>
      'Images and frames can\'t be sent together';

  @override
  String onboardingDiscoverApiFramesCount(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Up to $max frames',
      one: 'Up to 1 frame',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverApiFrameFormat =>
      'Only jpeg / png / webp frames can be sent';

  @override
  String get onboardingDiscoverApiFrameSize =>
      'Each frame must be 10 MiB or smaller';

  @override
  String get onboardingDiscoverApiFramesTotal =>
      'Frames must be 24 MiB or smaller in total';

  @override
  String get onboardingDiscoverApiEmpty => 'An image, text or URL is required';

  @override
  String get onboardingTourPageSnsTitle => 'Many social networks, one place';

  @override
  String get onboardingTourPageSnsBody =>
      'Use your Misskey, Mastodon, Bluesky and other accounts all together. With a RASQ account, your settings and account groups also work on your other devices.';

  @override
  String get onboardingTourPageSnsPicture =>
      'Illustration of Bluesky, Misskey, mixi2 and Mastodon coming together in RASQ';

  @override
  String get onboardingTourPageTimelineTitle =>
      'Build your timeline from nodes';

  @override
  String get onboardingTourPageTimelineBody =>
      'Arrange nodes to build your home TL the way you like. Trends and Today can also be placed in the TL as nodes.';

  @override
  String get onboardingTourPageTimelineNote =>
      'You can change it from the TL\'s gear icon.';

  @override
  String get onboardingTourPageTimelinePicture =>
      'Illustration of \"SNS timeline\", \"Get trends\" and \"Today\" nodes stacked vertically';

  @override
  String get onboardingTourPageTrendTitle => 'Trends and Today';

  @override
  String get onboardingTourPageTrendBody =>
      'See trending words and posts in Trends and Today. Fear, disgust and anger are capped at 45% to start with, so posts with strong anger or disgust rank lower or don\'t appear in Recommended / Trends / Today / Related TL.';

  @override
  String get onboardingTourPageTrendNoteSupervised =>
      'You can change this cap at any time. While supervised, your guardian\'s settings restrict it further.';

  @override
  String get onboardingTourPageTrendNote =>
      'You can change this cap at any time.';

  @override
  String get onboardingTourPageTrendPicture => 'Intensity radar chart';

  @override
  String get onboardingTourPageAstellTitle => 'Connect by voice with ASTell';

  @override
  String get onboardingTourPageAstellBody =>
      'ASTell is a room where you can talk by voice. You can also join just to listen, from the ASTell tab at the bottom.';

  @override
  String get onboardingTourPageAstellPicture =>
      'ASTell antenna and a waveform showing someone speaking';

  @override
  String get onboardingTourPageSwingTitle => 'Share casually with Swing';

  @override
  String get onboardingTourPageSwingBody =>
      'Swing posts disappear over time. They reach your followers and people in your RASQ lists, and vanish after 1–24 hours.';

  @override
  String get onboardingTourPageSwingNote => 'Available with a RASQ account.';

  @override
  String get onboardingTourPageSwingPicture =>
      'Illustration of round Swing icons in a row';

  @override
  String get onboardingTourPageRaiTitle => 'Ask RAi when you\'re unsure';

  @override
  String get onboardingTourPageRaiBody =>
      'RAi is RASQ\'s assistant. Tell it what you want to do and it will guide you to the right button or do it for you.';

  @override
  String get onboardingTourPageRaiPicture => 'RAi and a speech bubble';

  @override
  String get onboardingTourPagePluginsTitle => 'Extend with plugins';

  @override
  String get onboardingTourPagePluginsBody =>
      'Add social networks, views and features with plugins. Find and install them in the plugin store.';

  @override
  String get onboardingTourPagePluginsPicture =>
      'Illustration of plugin tiles in a row';

  @override
  String get onboardingTourTitle => 'How to use RASQ';

  @override
  String get onboardingTourSkip => 'Skip';

  @override
  String get onboardingTourBack => 'Back';

  @override
  String onboardingTourPageSemantics(int number, int total) {
    return 'Page $number of $total';
  }

  @override
  String get onboardingTourStart => 'Get started';

  @override
  String get onboardingTourNext => 'Next';

  @override
  String get onboardingTourOpenTendency => 'View settings now';

  @override
  String get onboardingTourNodeSnsTimeline => 'SNS timeline';

  @override
  String get onboardingTourNodeTrend => 'Get trends';

  @override
  String get onboardingTourRaiBubble => 'I want to add a list to my TL';

  @override
  String get platformWebRuntimeLoadFailed =>
      'Couldn\'t load files needed to run (network / CDN)';

  @override
  String get platformWebServerNotConfigured => 'RASQ server address is not set';

  @override
  String platformWebDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String platformWebModelLoadFailed(String error) {
    return 'Couldn\'t load the model: $error';
  }

  @override
  String get pluginsCancel => 'Cancel';

  @override
  String get pluginsClose => 'Close';

  @override
  String get pluginsSwingNotPackage =>
      'Swing plugins must be .rasqpkg or .wasm';

  @override
  String get pluginsSwingNoRequires =>
      'Child plugins that build on other plugins can\'t be distributed via Swing';

  @override
  String get pluginsSwingSingleOnly =>
      'Swing can only distribute packages that contain a single plugin';

  @override
  String get pluginsPageNotPage => 'This is not a page plugin';

  @override
  String pluginsPageSwingRequires(String ids) {
    return 'Can\'t be distributed via Swing because it builds on other plugins ($ids)';
  }

  @override
  String get pluginsPageSwingChild =>
      'Can\'t be distributed via Swing because it is a child plugin inside another plugin\'s package';

  @override
  String pluginsPageSwingSiblings(String names) {
    return 'Can\'t be distributed via Swing because it shares a package with child plugins ($names)';
  }

  @override
  String pluginsArtifactMismatch(String pluginId) {
    return '$pluginId: Not loaded because the re-downloaded artifact differs from the one installed (reinstall it from the Store)';
  }

  @override
  String pluginsIsSnsPlugin(String id) {
    return '$id is an SNS plugin (it can\'t be registered to a slot)';
  }

  @override
  String get pluginsManifestMissing => 'plugin.manifest is missing';

  @override
  String get pluginsManifestIdEmpty => 'plugin.manifest.id is empty';

  @override
  String get pluginsSwingSurfaceOnly =>
      'Swing can only distribute page plugins for Swing surfaces (surfaces: swing, solo)';

  @override
  String get pluginsRasqPageSurfaceOnly =>
      'Only page plugins for the profile surface (surfaces: profile, solo) can be placed on RASQ pages';

  @override
  String pluginsIdMismatch(String expected, String actual) {
    return 'The package index says $expected, but the wasm identifies itself as $actual';
  }

  @override
  String pluginsRegistered(String name, String slots) {
    return 'Registered $name ($slots)';
  }

  @override
  String pluginsRegisterFailed(String error) {
    return 'Couldn\'t register: $error';
  }

  @override
  String pluginsImageReceiveFailed(String name, String error) {
    return '$name: Couldn\'t receive the image ($error)';
  }

  @override
  String pluginsSharedNoSession(String name) {
    return '$name: You\'re not in a shared session, so shared values can\'t be changed';
  }

  @override
  String get pluginsMuteAddTitle => 'Add muted word';

  @override
  String pluginsMuteAddMessage(String name, String word) {
    return '$name wants to add \"$word\" to your muted words.';
  }

  @override
  String get pluginsMuteAddConfirm => 'Add';

  @override
  String pluginsMuteAdded(String word) {
    return 'Added \"$word\" to muted words';
  }

  @override
  String pluginsEffectSendFailed(String name, String error) {
    return '$name: Couldn\'t send the effect video ($error)';
  }

  @override
  String pluginsImageScaled(String name) {
    return '$name: Image was downscaled for editing';
  }

  @override
  String get pluginsErrorReturned => 'The plugin returned an error';

  @override
  String get pluginsGenreTone => 'Tone';

  @override
  String get pluginsGenreProcess => 'Effects';

  @override
  String get pluginsGenreTransform => 'Transform';

  @override
  String get pluginsGenreAdd => 'Add';

  @override
  String get pluginsGenreDraw => 'Draw';

  @override
  String get pluginsTrustFull => 'Full';

  @override
  String get pluginsTrustBundled => 'Full (bundled)';

  @override
  String get pluginsTrustRestricted => 'Restricted';

  @override
  String get pluginsTrustSwing => 'Restricted (Swing)';

  @override
  String get pluginsTrustHint =>
      '.rspkg / .rasqpkg signed with your own developer key get full features. rasq build signs them';

  @override
  String get pluginsEditorCancel => 'Cancel';

  @override
  String get pluginsEditorUndo => 'Undo';

  @override
  String get pluginsEditorRedo => 'Redo';

  @override
  String get pluginsEditorDone => 'Done';

  @override
  String get pluginsEditorRemove => 'Delete';

  @override
  String get pluginsEditorBack => 'Back';

  @override
  String get pluginsEditorMore => 'More';

  @override
  String get pluginsEditorApplying => 'Applying changes';

  @override
  String get pluginsEditorPreparing => 'Preparing editor';

  @override
  String get pluginsEditorPleaseWait => 'Please wait…';

  @override
  String get pluginsEditorCloseWarningTitle => 'Stop editing?';

  @override
  String get pluginsEditorCloseWarningMessage =>
      'Your changes won\'t be saved.';

  @override
  String get pluginsEditorCloseWarningConfirm => 'Stop';

  @override
  String get pluginsEditorCloseWarningCancel => 'Continue';

  @override
  String get pluginsEditorLayerEdit => 'Edit';

  @override
  String get pluginsEditorLayerRotateScale => 'Rotate and scale';

  @override
  String get pluginsEditorPaint => 'Paint';

  @override
  String get pluginsEditorZoom => 'Zoom';

  @override
  String get pluginsEditorFreehand => 'Freehand';

  @override
  String get pluginsEditorArrow => 'Arrow';

  @override
  String get pluginsEditorLine => 'Line';

  @override
  String get pluginsEditorRectangle => 'Rectangle';

  @override
  String get pluginsEditorCircle => 'Circle';

  @override
  String get pluginsEditorDashLine => 'Dashed line';

  @override
  String get pluginsEditorBlur => 'Blur';

  @override
  String get pluginsEditorPixelate => 'Pixelate';

  @override
  String get pluginsEditorLineWidth => 'Line width';

  @override
  String get pluginsEditorEraser => 'Eraser';

  @override
  String get pluginsEditorFill => 'Fill';

  @override
  String get pluginsEditorOpacity => 'Opacity';

  @override
  String get pluginsEditorColor => 'Color';

  @override
  String get pluginsEditorTextHint => 'Enter text';

  @override
  String get pluginsEditorText => 'Text';

  @override
  String get pluginsEditorTextAlign => 'Align';

  @override
  String get pluginsEditorFontScale => 'Text size';

  @override
  String get pluginsEditorTextBackground => 'Background';

  @override
  String get pluginsEditorCropRotate => 'Crop / Rotate';

  @override
  String get pluginsEditorRotate => 'Rotate';

  @override
  String get pluginsEditorFlip => 'Flip';

  @override
  String get pluginsEditorTilt => 'Tilt';

  @override
  String get pluginsEditorTiltHorizontal => 'Horizontal';

  @override
  String get pluginsEditorTiltVertical => 'Vertical';

  @override
  String get pluginsEditorRatio => 'Ratio';

  @override
  String get pluginsEditorReset => 'Reset';

  @override
  String get pluginsEditorTune => 'Adjust';

  @override
  String get pluginsEditorBrightness => 'Brightness';

  @override
  String get pluginsEditorContrast => 'Contrast';

  @override
  String get pluginsEditorSaturation => 'Saturation';

  @override
  String get pluginsEditorExposure => 'Exposure';

  @override
  String get pluginsEditorHue => 'Hue';

  @override
  String get pluginsEditorTemperature => 'Temperature';

  @override
  String get pluginsEditorFade => 'Fade';

  @override
  String get pluginsEditorTint => 'Tint';

  @override
  String get pluginsEditorFilter => 'Filter';

  @override
  String get pluginsEditorSticker => 'Sticker';

  @override
  String get pluginsEditorEmoji => 'Emoji';

  @override
  String get pluginsEditorEmojiSearch => 'Search';

  @override
  String get pluginsEditorEmojiRecent => 'Recent';

  @override
  String get pluginsEditorEmojiSmileys => 'Smileys & People';

  @override
  String get pluginsEditorEmojiAnimals => 'Animals & Nature';

  @override
  String get pluginsEditorEmojiFood => 'Food & Drink';

  @override
  String get pluginsEditorEmojiActivities => 'Activities';

  @override
  String get pluginsEditorEmojiTravel => 'Travel & Places';

  @override
  String get pluginsEditorEmojiObjects => 'Objects';

  @override
  String get pluginsEditorEmojiSymbols => 'Symbols';

  @override
  String get pluginsEditorEmojiFlags => 'Flags';

  @override
  String get pluginsMediaCancel => 'Cancel';

  @override
  String get pluginsMediaClose => 'Close';

  @override
  String get pluginsMediaApply => 'Apply';

  @override
  String pluginsMediaNotSvg(String name) {
    return '$name didn\'t return an SVG, so it wasn\'t used';
  }

  @override
  String get pluginsMediaPaperDoneMissing =>
      'Not available right now (the paper\'s \"Done\" wasn\'t found)';

  @override
  String get pluginsMediaBarEdit => 'Edit bar';

  @override
  String get pluginsMediaAudioUnsupported =>
      'Audio can\'t be turned into video on this device (Android / iOS / macOS only). You can attach it as audio';

  @override
  String pluginsMediaOpenAudioFailed(String error) {
    return 'Couldn\'t open the audio: $error';
  }

  @override
  String pluginsMediaOpenVideoFailed(String error) {
    return 'Couldn\'t open the video: $error';
  }

  @override
  String pluginsMediaReexportFailed(String error) {
    return 'Couldn\'t re-export the video: $error';
  }

  @override
  String get pluginsMediaCropWithMovingObject =>
      'Crop / rotate can\'t be used together with moving objects. Added as a still image';

  @override
  String pluginsMediaExportFailed(String error) {
    return 'Couldn\'t export the video: $error';
  }

  @override
  String pluginsMediaOverlayFailed(String error) {
    return 'Couldn\'t overlay the moving object, so it was added as a still image: $error';
  }

  @override
  String pluginsMediaFilterNotReceived(String label) {
    return '$label: Couldn\'t receive the filter';
  }

  @override
  String pluginsMediaFilterDropped(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count were',
      one: '1 was',
    );
    return '$label: Too many drawings, so $_temp0 left out';
  }

  @override
  String pluginsMediaFiltersFailed(String names) {
    return 'Filters that couldn\'t be applied: $names (these edits aren\'t included)';
  }

  @override
  String get pluginsMediaCropWithMovingPost =>
      'Crop / rotate can\'t be used together with moving posts. The post was added as a still image';

  @override
  String get pluginsMediaVideoImageUnreadable =>
      'Couldn\'t make a video, so it was added as a still image (the image couldn\'t be read)';

  @override
  String pluginsMediaVideoPostFailed(String error) {
    return 'Couldn\'t make a video, so the post was added as a still image: $error';
  }

  @override
  String get pluginsMediaToVideoTitle => 'Convert to video?';

  @override
  String pluginsMediaToVideoMessage(String note) {
    return '$note\n\"Make video\" exports it as a video that moves where you placed it. \"Paste as still\" pastes only the current image.';
  }

  @override
  String get pluginsMediaToVideoConfirm => 'Make video';

  @override
  String get pluginsMediaToVideoStill => 'Paste as still';

  @override
  String get pluginsMediaImageUnreadable => 'Couldn\'t read the image';

  @override
  String get pluginsMediaExportOnDone =>
      'It will be exported as a video when you finish';

  @override
  String get pluginsMediaObjectNote => 'Note';

  @override
  String get pluginsMediaObjectVideo => 'Video';

  @override
  String get pluginsMediaObjectImage => 'Image';

  @override
  String get pluginsMediaAddImage => 'Add image';

  @override
  String get pluginsMediaAddVideo => 'Add video';

  @override
  String get pluginsMediaVideoLoadFailed => 'Couldn\'t load the video';

  @override
  String pluginsMediaVideoLoadFailedDetail(
    String ext,
    int bytes,
    String error,
  ) {
    return 'Couldn\'t get the first frame of the video (.$ext, $bytes bytes): $error';
  }

  @override
  String get pluginsMediaFirstFrameFailed =>
      'Couldn\'t get the first frame of the video';

  @override
  String get pluginsMediaVideoAsObject => 'The video is placed as an object.';

  @override
  String pluginsMediaAddFailed(String error) {
    return 'Couldn\'t add media: $error';
  }

  @override
  String get pluginsMediaAudioConverting => 'Converting audio to video…';

  @override
  String pluginsMediaPanelNotEditable(String name) {
    return '$name can\'t be edited here (use the plugin\'s panel)';
  }

  @override
  String get pluginsMediaSnapDragUnset => 'Drag onto this (unset)';

  @override
  String get pluginsMediaSnapDragSet => 'Drag onto this (set as snap target)';

  @override
  String get pluginsMediaSnapPick => 'Choose snap target…';

  @override
  String get pluginsMediaSnapClearAll => 'Clear all snap targets';

  @override
  String get pluginsMediaSnapTitle => 'Snap target';

  @override
  String get pluginsMediaSnapEmpty => 'No named frames';

  @override
  String pluginsMediaSnapSize(int width, int height) {
    return '$width × $height';
  }

  @override
  String pluginsMediaSnapSizeAngle(int width, int height, int angle) {
    return '$width × $height, $angle°';
  }

  @override
  String get pluginsMediaPanelNoResult =>
      'Couldn\'t apply (the plugin returned no result)';

  @override
  String get pluginsMediaPanelNoEdits => 'This plugin has no edits';

  @override
  String pluginsMediaObjectEditSemantics(String title) {
    return 'Edit $title';
  }

  @override
  String get pluginsMediaObjectLoop => 'Loop';

  @override
  String get pluginsMediaObjectLoopSubtitle =>
      'Off = stops on the last frame when it ends';

  @override
  String get pluginsMediaObjectSpeed => 'Playback speed';

  @override
  String get pluginsMediaObjectVolume => 'Volume';

  @override
  String get pluginsMediaObjectMuted => 'Mute';

  @override
  String get pluginsMediaObjectOpacity => 'Opacity';

  @override
  String get pluginsMediaObjectRemove => 'Delete this object';

  @override
  String pluginsMediaFilterAdjustSemantics(String title) {
    return 'Adjust $title';
  }

  @override
  String get pluginsMediaFilterObjectHint =>
      'On the picture, drag to move and pinch to resize / rotate.';

  @override
  String get pluginsMediaFilterRemove => 'Remove this filter';

  @override
  String get pluginsMediaStickerEmpty =>
      'No stickers. Install some from the Store and they\'ll appear here';

  @override
  String get pluginsMediaStickerEmptyDetail =>
      'No stickers. Install an asset pack (category \"assets\") from the Store and they\'ll appear here.';

  @override
  String get pluginsMediaStickerGenerate => 'Create with a plugin';

  @override
  String get pluginsPaintTitle => 'Doodle';

  @override
  String get pluginsPaintCancel => 'Cancel';

  @override
  String get pluginsPaintDone => 'Done';

  @override
  String get pluginsPaintCanvasSemantics => 'Doodle canvas';

  @override
  String get pluginsPaintFillLeak => 'Tap inside a shape closed by lines';

  @override
  String get pluginsPaintFillOnLine => 'Tap inside the lines';

  @override
  String get pluginsPaintFillEmpty => 'No shape to fill';

  @override
  String get pluginsPaintToolPen => 'Pen';

  @override
  String get pluginsPaintToolEraser => 'Eraser';

  @override
  String get pluginsPaintToolLasso => 'Lasso';

  @override
  String get pluginsPaintToolFill => 'Fill';

  @override
  String get pluginsPaintUndo => 'Undo';

  @override
  String get pluginsPaintRedo => 'Redo';

  @override
  String get pluginsPaintClear => 'Clear all';

  @override
  String get pluginsPaintStabilizer => 'Stabilizer';

  @override
  String get pluginsPaintStabilizerOff => 'Off';

  @override
  String get pluginsPaintEraserCut => 'Cut';

  @override
  String get pluginsPaintEraserWhole => 'Whole stroke';

  @override
  String get pluginsPaintLassoHint =>
      'Circle to select (strokes at least half inside)';

  @override
  String get pluginsPaintSelectionDelete => 'Delete';

  @override
  String get pluginsPaintSelectionDuplicate => 'Duplicate';

  @override
  String get pluginsPaintSelectionRecolor => 'Change color';

  @override
  String get pluginsPaintSelectionDeselect => 'Deselect';

  @override
  String get pluginsPaintFillHint =>
      'Tap inside a shape closed by lines to fill it beneath the lines';

  @override
  String pluginsPaintWidthSemantics(String width) {
    return 'Width $width';
  }

  @override
  String pluginsPaintColorSemantics(String color) {
    return 'Color $color';
  }

  @override
  String get pluginsPaintNibMili => 'Fineliner';

  @override
  String get pluginsPaintNibKabura => 'Kabura pen';

  @override
  String get pluginsPaintNibBrush => 'Brush nib';

  @override
  String get postThreadSortRelevance => 'Relevance';

  @override
  String get postThreadSortReactions => 'Reactions';

  @override
  String get postThreadSortKeyword => 'Keywords';

  @override
  String get postThreadSortDefault => 'Default';

  @override
  String get postThreadModeRenotes => 'Quotes (renotes)';

  @override
  String get postThreadModeRenotesShort => 'Quotes';

  @override
  String get postThreadModeReplies => 'Replies';

  @override
  String get postThreadModeRepliesShort => 'Replies';

  @override
  String get postThreadModeReactions => 'Reactions';

  @override
  String get postThreadModeReactionsShort => 'Reactions';

  @override
  String get postThreadModeQuotes => 'Shares (quote notes)';

  @override
  String get postThreadModeQuotesShort => 'Shares';

  @override
  String get postBookmarkClipTooltip => 'Add to clip (long-press)';

  @override
  String get postBookmarkRemoveTooltip =>
      'Remove bookmark (long-press for clip)';

  @override
  String get postBookmarkAddTooltip => 'Bookmark (long-press for clip)';

  @override
  String get postBookmarkUnsupported =>
      'This service has no bookmarks. Long-press to add to a clip';

  @override
  String get postBookmarkRemoved => 'Bookmark removed';

  @override
  String get postBookmarkAdded => 'Bookmarked';

  @override
  String postBookmarkError(String error) {
    return 'Couldn\'t bookmark: $error';
  }

  @override
  String get postReactionsTitle => 'Reactions';

  @override
  String get postReactionsTabReplies => 'Replies';

  @override
  String get postReactionsTabQuotes => 'Quotes';

  @override
  String get postReactionsTabReactions => 'Reactions';

  @override
  String get postReactionsTabShares => 'Shares';

  @override
  String get postReactionsBookmarkTooltip => 'Bookmark';

  @override
  String get postRepliesEmpty => 'No replies';

  @override
  String get postQuotesEmpty => 'No quote notes';

  @override
  String get postRepostersEmpty => 'No renotes or quotes';

  @override
  String get postReactionsEmpty => 'No reactions';

  @override
  String get postReactionsMine => 'You';

  @override
  String postDetailNotFoundOnAccount(String account) {
    return 'Couldn\'t find this post on $account';
  }

  @override
  String get postDetailTitle => 'Post';

  @override
  String get postDetailOpenedAccount => 'Account it was opened with';

  @override
  String get postDetailNotFound => 'Post not found';

  @override
  String get postReload => 'Reload';

  @override
  String get postDetailShowReactions => 'Show reactions';

  @override
  String get postDetailShowMore => 'Show more';

  @override
  String get postRenotesEmpty => 'No renotes';

  @override
  String get postShareAccountTooltip => 'Account to share with';

  @override
  String get postShareAccountFixedTooltip =>
      'Can only be shared with the receiving account';

  @override
  String get postShareSemantics => 'Share';

  @override
  String get postShareContentCopied => 'Content copied';

  @override
  String get postShareLinkCopied => 'Link copied';

  @override
  String get postShareDmTitle => 'Share via DM';

  @override
  String get postShareClose => 'Close';

  @override
  String get postShareDmNoRooms => 'No DM contacts';

  @override
  String postShareAstellShared(String room) {
    return 'Shared to \"$room\"';
  }

  @override
  String get postShareCopyContent => 'Copy content';

  @override
  String get postShareCopyLink => 'Copy link';

  @override
  String get postShareOtherAccount => 'Share from another account';

  @override
  String get postSharePluginsHeader => 'Share to plugins';

  @override
  String get postShareAstellTitle => 'Share to ASTell';

  @override
  String postShareAstellSubtitle(String room) {
    return 'Send the post to the room you\'re in, \"$room\"';
  }

  @override
  String get postSharePluginsEmpty =>
      'Plugins that support sharing will appear here';

  @override
  String get postSharePluginsEmptyDetail =>
      'Plugins that declare post.share (and the ASTell room you\'re in) will appear here';

  @override
  String get postShareOtherHeader => 'Other';

  @override
  String get postShareDmSubtitle =>
      'Send the link via DM from the selected account';

  @override
  String get postShareOpenBrowser => 'Open in browser';

  @override
  String get postMenuCopyLink => 'Copy link';

  @override
  String get postMenuUnpin => 'Unpin';

  @override
  String get postMenuPin => 'Pin';

  @override
  String get postMenuDetail => 'Details';

  @override
  String get postMenuShare => 'Share';

  @override
  String get postMenuEditActionBar => 'Edit action bar';

  @override
  String get postMenuUnfavorite => 'Unfavorite';

  @override
  String get postMenuFavorite => 'Favorite';

  @override
  String get postMenuAddToClip => 'Add to clip';

  @override
  String get postMenuUnfollow => 'Unfollow';

  @override
  String get postMenuFollow => 'Follow';

  @override
  String get postMenuUnmute => 'Unmute';

  @override
  String get postMenuMute => 'Mute';

  @override
  String get postMenuUnblock => 'Unblock';

  @override
  String get postMenuBlock => 'Block';

  @override
  String get postMenuReport => 'Report';

  @override
  String get postMenuDelete => 'Delete';

  @override
  String postBlockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get postCancel => 'Cancel';

  @override
  String get postReportConfirmTitle => 'Report this post?';

  @override
  String get postReportConfirmMessage =>
      'It will be reported to the server admins.';

  @override
  String get postDeleteConfirmTitle => 'Delete post?';

  @override
  String get postDeleteConfirmMessage => 'This can\'t be undone.';

  @override
  String postSaveMediaLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': 'Save video',
      'other': 'Save image',
    });
    return '$_temp0';
  }

  @override
  String postSaveDestinationTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': 'Save video to',
      'other': 'Save image to',
    });
    return '$_temp0';
  }

  @override
  String get postSaveToPhotosSubtitle => 'Goes into the \"RASQ\" album';

  @override
  String get postSaveToFilesIosSubtitle =>
      'Files app › On My iPad (On My iPhone) › RASQ › 保存';

  @override
  String get postSaveToFilesSubtitle => 'Choose where to save';

  @override
  String get postSaveRememberTitle => 'Use this location from now on';

  @override
  String get postSaveRememberSubtitle =>
      'You can change this in Settings → App appearance → \"Image and video save location\"';

  @override
  String postSaveFailed(String kind, String error) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': 'Couldn\'t save the video: $error',
      'other': 'Couldn\'t save the image: $error',
    });
    return '$_temp0';
  }

  @override
  String get profileEditTitle => 'Update profile';

  @override
  String get profileEditSave => 'Done';

  @override
  String get profileEditNotLoggedIn => 'Not logged in to a RASQ account.';

  @override
  String get profileEditBannerRemove => 'Remove banner';

  @override
  String get profileEditBannerPick => 'Choose banner';

  @override
  String get profileEditAvatarPick => 'Choose icon';

  @override
  String get profileEditAvatarRemove => 'Remove icon';

  @override
  String get profileEditPickImage => 'Choose image';

  @override
  String get profileEditNameHint => 'Enter your name…';

  @override
  String get profileEditBirthdayHint => 'Birthday (YYYY-MM-DD / MM-DD)';

  @override
  String get profileEditBirthdayHintSns => 'Birthday (YYYY-MM-DD)';

  @override
  String get profileEditHandleLabel =>
      'Handle (no @, a-z 0-9 _, 3–32 characters)';

  @override
  String get profileEditBioLabel => 'Bio';

  @override
  String get profileEditBioHint => 'Bio (up to 500 characters)';

  @override
  String get profileEditLocationLabel => 'Location';

  @override
  String get profileEditLinksLabel => 'Links';

  @override
  String get profileEditLinkRemove => 'Delete';

  @override
  String get profileEditLinkCaptionHint => 'Caption';

  @override
  String get profileEditLinkAdd => 'Add';

  @override
  String get profileEditReload => 'Reload';

  @override
  String get profileEditSnsTilesLabel =>
      'SNS accounts shown on your account page';

  @override
  String get profileEditSnsTilesCaption =>
      '\"Auto\" doesn\'t show locked accounts and the like. Faded tiles aren\'t currently shown.';

  @override
  String get profileEditSnsTilesCaptionDetail =>
      '\"Auto\" doesn\'t show locked accounts or accounts whose recent posts are mostly followers-only. Faded tiles aren\'t currently shown. Changes take effect immediately.';

  @override
  String profileEditSnsTileAuto(String state) {
    return 'Auto ($state)';
  }

  @override
  String get profileEditSnsTileShown => 'Shown';

  @override
  String get profileEditSnsTileHidden => 'Hidden';

  @override
  String profileEditVerified(String method) {
    return 'Ownership verified ($method)';
  }

  @override
  String get profileEditVerify => 'Verify ownership';

  @override
  String get profileEditShowOnSnsLabel => 'SNS profile';

  @override
  String get profileEditShowOnSnsTitle =>
      'Also show linked accounts on your SNS profiles';

  @override
  String get profileEditShowOnSnsSubtitle =>
      'When someone views your SNS profile in RASQ, your linked accounts are shown.';

  @override
  String get profileEditShowOnSnsDetail =>
      'When someone views your SNS profile in the app, this RASQ account and the other accounts shown on your account page are displayed. Anything already written in your bio isn\'t shown twice. Changes take effect immediately.';

  @override
  String get profileEditKeybaseConnect => 'Connect Keybase';

  @override
  String get profileEditKeybaseConnectSubtitle =>
      'Verify your identity with Keybase and show it on your account page';

  @override
  String get profileEditKeybaseLinkedSubtitle =>
      'Verified. Shown on your account page';

  @override
  String get profileEditNotice =>
      'Your profile appears on your public page and Store reviews. Email and password are under \"Security\".';

  @override
  String get profileEditNoticeDetail =>
      'Your profile appears on your RASQ public page and Store reviews. Images are downscaled and re-saved on the server (location data and the like aren\'t kept). Email address and password are under \"Security\".';

  @override
  String get profileEditErrorHandleTaken => 'That handle is already taken';

  @override
  String get profileEditErrorHandle =>
      'Handles must be 3–32 characters of a-z 0-9 _';

  @override
  String get profileEditErrorBirthday =>
      'Enter your birthday as YYYY-MM-DD or MM-DD';

  @override
  String get profileEditErrorLink =>
      'Each link must be a caption (up to 40 characters) paired with an http(s) URL (up to 8 links)';

  @override
  String get profileEditErrorImage =>
      'That image can\'t be used (PNG / JPEG / WebP / GIF, up to 8 MiB)';

  @override
  String get profileEditErrorBio => 'Bio can be up to 500 characters';

  @override
  String get profileEditErrorLocation => 'Location can be up to 60 characters';

  @override
  String profileEditErrorFailed(String message) {
    return 'Update failed: $message';
  }

  @override
  String get profileEditSnsPostsWithdrawn =>
      'Deleted the deposited key and fetched posts';

  @override
  String profileEditSnsPostsWithdrawFailed(String message) {
    return 'Couldn\'t delete: $message';
  }

  @override
  String get profileEditSnsPostsNoLogin =>
      'This device has no login for that account';

  @override
  String get profileEditSnsPostsNoDid =>
      'This account\'s DID is unknown. Please log in again';

  @override
  String get profileEditSnsPostsBlueskyConsentTitle =>
      'Show Bluesky posts on your account page';

  @override
  String profileEditSnsPostsBlueskyConsentMessage(String account) {
    return 'RASQ\'s server reads $account\'s posts from Bluesky\'s public API and makes them **viewable by anyone on your RASQ account page**.\n\n• Bluesky posts are readable by anyone to begin with. Replies and reposts aren\'t imported.\n• **Your login key (app password / session) isn\'t deposited.** Only this account\'s DID and handle are sent to the server.\n• Only accounts whose ownership has been verified can use this (so no one can show someone else\'s posts).\n• Turning this switch off deletes the fetched posts immediately.';
  }

  @override
  String get profileEditSnsPostsAgreeShow => 'Agree and show';

  @override
  String get profileEditCancel => 'Cancel';

  @override
  String get profileEditSnsPostsTokenConsentTitle =>
      'Deposit your login key with RASQ';

  @override
  String profileEditSnsPostsTokenConsentMessage(String account) {
    return 'To show $account\'s posts on your account page, **your login key (access token) for this SNS will be deposited with RASQ\'s server**.\n\n• Your \"Public\" and \"Home (unlisted)\" posts become **viewable by anyone on your RASQ account page**. \"Home\" is not followers-only.\n• Followers-only / specified users and DMs / local-only / posts with unknown visibility aren\'t imported.\n• The key is used only to read your posts. It isn\'t used for actions like posting or following, or for any other purpose.\n• The key is stored encrypted with the server\'s key (RASQ\'s server can decrypt it). It isn\'t returned to the app or anyone else.\n• Turning this switch off immediately deletes the deposited key and fetched posts.\n\nWith this key, the account can be operated. If you\'re concerned, you can revoke this key (token) from the SNS\'s settings even after depositing it.';
  }

  @override
  String get profileEditSnsPostsAgreeDeposit => 'Agree and deposit';

  @override
  String profileEditSnsPostsFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Fetched $count posts',
      one: 'Fetched 1 post',
    );
    return '$_temp0';
  }

  @override
  String profileEditSnsPostsFetchFailed(String error) {
    return 'Deposited, but couldn\'t fetch posts ($error)';
  }

  @override
  String get profileEditSnsPostsUnsupported =>
      'Not available on this server yet';

  @override
  String get profileEditSnsPostsVerifyFirst =>
      'First complete \"Verify ownership\" for this account';

  @override
  String profileEditSnsPostsDepositFailed(String message) {
    return 'Couldn\'t deposit: $message';
  }

  @override
  String get profileEditSnsPostsSwitchTitle =>
      'Also show posts on your account page';

  @override
  String profileEditSnsPostsFetchError(String error) {
    return 'Fetching is failing: $error';
  }

  @override
  String profileEditSnsPostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts (public / home posts; updated every 30 minutes)',
      one: '1 post (public / home posts; updated every 30 minutes)',
    );
    return '$_temp0';
  }

  @override
  String get profileEditSnsPostsBlueskySubtitle =>
      'RASQ\'s server reads your public Bluesky posts (no key deposited)';

  @override
  String get profileEditSnsPostsTokenSubtitle =>
      'Deposits your SNS login key with RASQ (you\'ll be asked to confirm when turning it on)';

  @override
  String get profileEditSnsPostsCollectionsTitle =>
      'Also use this key for RASQ lists';

  @override
  String get profileEditSnsPostsCollectionsSubtitle =>
      'Used to fetch opened RASQ lists and check whether you can view them';

  @override
  String get profileEditSnsPostsCollectionsDetail =>
      'When a RASQ list or clip is opened, this key is used to ask the SNS whether you follow the people in the list and to fetch their public posts. This is a different purpose from the key deposited for showing posts, so it\'s chosen separately (off by default; opting in / out is recorded in the consent log).';

  @override
  String get profileEditSnsPostsCollectionsConsentTitle =>
      'Also use the deposited key for RASQ lists';

  @override
  String get profileEditSnsPostsCollectionsConsentMessage =>
      'The key deposited for showing posts will also be used for another purpose.\n\n• When a RASQ list or clip is opened, this key is used to ask the SNS whether you follow the people in the list (to check whether you can view it).\n• This key is used to fetch the public / home posts of the people in the list.\n• It isn\'t used for actions like posting or following.\n• Turning this switch off stops using it immediately.';

  @override
  String get profileEditSnsPostsCollectionsAgree => 'Agree and use';

  @override
  String profileEditSnsPostsCollectionsFailed(String message) {
    return 'Couldn\'t change: $message';
  }

  @override
  String get profileOwnershipWhereMisskey =>
      'Paste it into your bio or one of the \"Additional information\" fields on your profile, then save.';

  @override
  String get profileOwnershipWhereMastodon =>
      'Paste it into your bio or one of the \"Extra fields\" on your profile, then save.';

  @override
  String get profileOwnershipWhereBluesky =>
      'Paste it into your bio (profile description), then save.';

  @override
  String get profileOwnershipWhereFields =>
      'Paste it into your bio or one of your profile fields, then save.';

  @override
  String get profileOwnershipWhereBio => 'Paste it into your bio, then save.';

  @override
  String get profileOwnershipErrorNotLinked =>
      'This SNS account isn\'t linked to your RASQ account';

  @override
  String get profileOwnershipErrorUnsupported =>
      'This SNS doesn\'t support ownership verification yet';

  @override
  String get profileOwnershipErrorTooMany =>
      'Too many attempts. Please wait a while and try again';

  @override
  String get profileOwnershipErrorNotStarted =>
      'You haven\'t created a verification text yet, or it has expired. Start over from \"Create verification text\"';

  @override
  String get profileOwnershipErrorCodeNotFound =>
      'The verification text wasn\'t found in your profile. Check that you saved it and that it appears on your public profile (it may take a moment to show up)';

  @override
  String get profileOwnershipErrorProfileNotFound =>
      'Couldn\'t find the public profile for that SNS account';

  @override
  String get profileOwnershipErrorReadFailed =>
      'Couldn\'t read the profile on that SNS. Please wait a moment and try again';

  @override
  String profileOwnershipErrorFailed(String message) {
    return 'Couldn\'t verify: $message';
  }

  @override
  String get profileOwnershipKeybaseErrorUsername =>
      'Enter your Keybase username (lowercase letters, numbers and _, 2–16 characters)';

  @override
  String get profileOwnershipKeybaseErrorSignature =>
      'Couldn\'t read the signature. Paste everything from BEGIN KEYBASE SALTPACK SIGNED MESSAGE to END KEYBASE SALTPACK SIGNED MESSAGE. as is';

  @override
  String get profileOwnershipKeybaseErrorStatement =>
      'The signed text doesn\'t match. Use the command above as is';

  @override
  String get profileOwnershipKeybaseErrorKey =>
      'It wasn\'t signed with that Keybase user\'s key';

  @override
  String get profileOwnershipKeybaseErrorNoUser =>
      'That Keybase user wasn\'t found';

  @override
  String get profileOwnershipKeybaseErrorOtherAccount =>
      'That Keybase is linked to another RASQ account';

  @override
  String get profileOwnershipKeybaseErrorExpired =>
      'The text has expired or hasn\'t been created yet. Start over from \"Create text to sign\"';

  @override
  String get profileOwnershipKeybaseErrorUnreachable =>
      'Couldn\'t connect to Keybase. Please wait a moment and try again';

  @override
  String profileOwnershipKeybaseErrorFailed(String message) {
    return 'Couldn\'t verify: $message';
  }

  @override
  String get profileOwnershipVerifyTitle => 'Verify ownership';

  @override
  String get profileOwnershipNotLinked =>
      'This SNS account isn\'t linked to your RASQ account.';

  @override
  String profileOwnershipVerified(String method) {
    return 'Verified ($method)';
  }

  @override
  String get profileOwnershipJustVerified =>
      'Verified. You can now remove the text you pasted into your profile.';

  @override
  String get profileOwnershipVerifiedCaption =>
      'A verified badge appears on your account page and SNS profile.';

  @override
  String get profileOwnershipVerifiedCaptionDetail =>
      'A verified badge appears on your account page and in the RASQ account section shown on your SNS profile. It stays until you unlink this SNS account.';

  @override
  String get profileOwnershipUnsupportedKind =>
      'This SNS doesn\'t support identity verification yet (Misskey / Mastodon / Bluesky only).';

  @override
  String get profileOwnershipIntro =>
      'Verify that this SNS account is yours. Temporarily paste a verification text into your profile.';

  @override
  String get profileOwnershipIntroDetail =>
      'Verify that this SNS account is yours. You temporarily paste a verification text into that SNS profile, and RASQ reads the public profile to confirm it.';

  @override
  String get profileOwnershipEffect =>
      'Once verified, a verified badge is added.';

  @override
  String get profileOwnershipEffectDetail =>
      'Once verified, a verified badge appears on your account page and in the RASQ account section of your SNS profile. If someone else has linked the same SNS account, the verified person takes priority.';

  @override
  String get profileOwnershipStart => 'Create verification text';

  @override
  String get profileOwnershipStep1 => '1. Copy this text';

  @override
  String get profileOwnershipCopied => 'Verification text copied';

  @override
  String get profileOwnershipCopy => 'Copy';

  @override
  String profileOwnershipValidUntil(String time) {
    return 'Valid until $time';
  }

  @override
  String get profileOwnershipStep2 => '2. Paste it into that SNS profile';

  @override
  String get profileOwnershipNoRewrite =>
      'RASQ won\'t edit your profile. Please paste it yourself on that SNS.';

  @override
  String get profileOwnershipStep3 => '3. After pasting, tap \"Verify\"';

  @override
  String get profileOwnershipCheck => 'Verify';

  @override
  String get profileOwnershipRestart => 'Create new text';

  @override
  String get profileOwnershipKeybaseNoLinks =>
      'The Keybase proofs didn\'t include any linked SNS accounts.';

  @override
  String profileOwnershipKeybaseLinksVerified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count linked SNS accounts were also verified through Keybase proofs.',
      one: '1 linked SNS account was also verified through Keybase proofs.',
    );
    return '$_temp0';
  }

  @override
  String profileOwnershipKeybaseLinked(String username, String links) {
    return 'Linked @$username. $links';
  }

  @override
  String get profileOwnershipKeybaseUnlinked =>
      'Keybase unlinked. SNS accounts verified through Keybase proofs are back to unverified.';

  @override
  String profileOwnershipKeybaseVerifiedAt(String time) {
    return 'Verified on $time';
  }

  @override
  String profileOwnershipKeybaseCaption(String username) {
    return '\"Keybase: @$username\" appears on your account page.';
  }

  @override
  String profileOwnershipKeybaseCaptionDetail(String username) {
    return '\"Keybase: @$username\" appears on your account page. If you add proofs for Mastodon or others on Keybase, use \"Reload proofs\" to also verify your linked SNS accounts.';
  }

  @override
  String get profileOwnershipKeybaseRefresh => 'Reload proofs';

  @override
  String get profileOwnershipKeybaseUnlink => 'Unlink Keybase';

  @override
  String get profileOwnershipKeybaseIntro =>
      'Sign with Keybase to link it to this RASQ account. The linked Keybase is public.';

  @override
  String get profileOwnershipKeybaseIntroDetail =>
      'Sign with your Keybase account to link it to this RASQ account. The linked Keybase appears on your account page (public, just like your Keybase profile).';

  @override
  String get profileOwnershipKeybaseUsername => 'Keybase username';

  @override
  String get profileOwnershipKeybaseStart => 'Create text to sign';

  @override
  String get profileOwnershipKeybaseStep1 =>
      '1. Run this command on a device with Keybase installed';

  @override
  String get profileOwnershipKeybaseCopied => 'Command copied';

  @override
  String profileOwnershipKeybaseStatement(String statement) {
    return 'Text to sign: $statement';
  }

  @override
  String get profileOwnershipKeybaseStep2 =>
      '2. Paste the resulting signature, from BEGIN to END … MESSAGE.';

  @override
  String get profileOwnershipKeybaseVerify => 'Verify';

  @override
  String profilePagePostLimit(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'You can have up to $limit posts. Delete old posts before posting',
      one: 'You can have up to 1 post. Delete an old post before posting',
    );
    return '$_temp0';
  }

  @override
  String get profilePageEdit => 'Edit';

  @override
  String get profilePageCompose => 'Post to RASQ';

  @override
  String profilePageNotFound(String handle) {
    return 'There\'s no RASQ account named @$handle';
  }

  @override
  String profilePageLoadFailed(String message) {
    return 'Couldn\'t load: $message';
  }

  @override
  String get profilePageLoadFailedShort => 'Couldn\'t load.';

  @override
  String get profilePageTabPosts => 'Posts';

  @override
  String get profilePageTabMedia => 'Media';

  @override
  String get profilePageTabPages => 'Pages';

  @override
  String get profilePageTabLists => 'Lists';

  @override
  String get profilePageTabClips => 'Clips';

  @override
  String get profilePageTabPlugins => 'Plugins';

  @override
  String get profilePageTabReviews => 'Reviews';

  @override
  String get profilePageTileNoDestination =>
      'Can\'t tell where this account leads';

  @override
  String profilePageOpenFailed(String url) {
    return 'Couldn\'t open: $url';
  }

  @override
  String get profilePageListsEmptyMine =>
      'RASQ lists you publish appear here (you can create them from the lists screen).';

  @override
  String get profilePageClipsEmptyMine =>
      'RASQ clips you publish appear here (\"Make public\" on the clip page).';

  @override
  String get profilePageListsEmpty => 'No public lists.';

  @override
  String get profilePageClipsEmpty => 'No public clips.';

  @override
  String profilePageSince(String date) {
    return 'Since $date';
  }

  @override
  String profilePagePinLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'You can pin up to $count posts',
      one: 'You can pin up to 1 post',
    );
    return '$_temp0';
  }

  @override
  String profilePagePinFailed(String message) {
    return 'Couldn\'t pin: $message';
  }

  @override
  String get profilePagePinned => 'Pinned post';

  @override
  String profilePagePostsNote(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'RASQ posts are limited to $limit ($used / $limit). SNS posts also appear here if you entrust their login keys.',
    );
    return '$_temp0';
  }

  @override
  String profilePagePostsNoteDetail(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'Posts as a RASQ account are currently limited to $limit ($used / $limit). Posts from an SNS account also appear here if you entrust that account\'s access token to RASQ.',
    );
    return '$_temp0';
  }

  @override
  String get profilePageSnsHintTitle =>
      'Posts from your linked SNS accounts don\'t appear here yet.';

  @override
  String get profilePageSnsHint =>
      'Turn on \"Also show posts on your account page\" in profile editing to show them here.';

  @override
  String get profilePageSnsHintDetail =>
      'In profile editing, under \"SNS accounts shown on your account page\", turn on \"Also show posts on your account page\" for each account (this entrusts that SNS\'s access token to RASQ), and its public / home posts appear here.';

  @override
  String get profilePageSnsHintOpen => 'Go to SNS post settings';

  @override
  String get profilePageNoPostsYet => 'No posts yet.';

  @override
  String get profilePageNoMediaYet => 'No media yet.';

  @override
  String get profilePageNoReviewsYet => 'No reviews yet.';

  @override
  String get profilePageNoPluginsPublished => 'No published plugins.';

  @override
  String get profilePageImageUrlMissing => 'No image URL was returned';

  @override
  String get profilePageNotConnected => 'Not connected to the RASQ server';

  @override
  String get profilePagePackageTypeLabel => 'Plugin (.rspkg / .rasqpkg)';

  @override
  String get profilePageImage => 'Image';

  @override
  String profilePageImageAlt(String alt) {
    return '(Image: $alt)';
  }

  @override
  String get profilePageMdFallbackTitle => 'Page';

  @override
  String get profilePageMdLoadFailed => 'Couldn\'t load the page';

  @override
  String get profilePageMdToolBold => 'Bold';

  @override
  String get profilePageMdToolHeading => 'Heading';

  @override
  String get profilePageMdToolBullet => 'Bulleted list';

  @override
  String get profilePageMdToolLink => 'Link';

  @override
  String get profilePageMdToolCenter => 'Center';

  @override
  String get profilePageMdToolBig => 'Bigger';

  @override
  String get profilePageMdToolSmall => 'Smaller';

  @override
  String get profilePageMdToolSpin => 'Spin';

  @override
  String get profilePageMdToolJump => 'Jump';

  @override
  String get profilePageMdToolColor => 'Color';

  @override
  String get profilePageMdToolRainbow => 'Rainbow';

  @override
  String get profilePageMdToolRuby => 'Ruby';

  @override
  String get profilePageMdToolRubyReading => 'reading';

  @override
  String profilePageImageUploadFailed(String error) {
    return 'Couldn\'t upload the image: $error';
  }

  @override
  String get profilePageMdTitleRequired => 'Enter a title';

  @override
  String get profilePageMdLoginToPublish =>
      'Log in to your RASQ account to publish';

  @override
  String get profilePageMdPublished => 'Published';

  @override
  String profilePageMdPublishFailed(String error) {
    return 'Couldn\'t publish: $error';
  }

  @override
  String get profilePageMdDeleteTitle => 'Delete page';

  @override
  String get profilePageMdDeleteDraft => 'This deletes the draft.';

  @override
  String get profilePageMdDeletePublished =>
      'This deletes the published page and the draft. This can\'t be undone.';

  @override
  String get profilePageDeleteConfirm => 'Delete';

  @override
  String get profilePageCancel => 'Cancel';

  @override
  String profilePageMdDeleteFailed(String error) {
    return 'Couldn\'t delete: $error';
  }

  @override
  String get profilePageMdEditTitle => 'Edit page';

  @override
  String get profilePageMdDelete => 'Delete';

  @override
  String get profilePageMdWrite => 'Write';

  @override
  String get profilePageMdPreview => 'Preview';

  @override
  String get profilePageMdPublish => 'Publish';

  @override
  String get profilePageMdTitleHint => 'Title';

  @override
  String get profilePageMdBodyHint =>
      'Write in Markdown. You can also use @mentions / #hashtags / :emoji: / MFM tags like <center>';

  @override
  String get profilePageMdDraftCaption =>
      'Drafts stay on this device. \"Publish\" puts it on your RASQ page';

  @override
  String get profilePageRasqAccount => 'RASQ account';

  @override
  String profilePageViewingVerified(String method) {
    return 'This account\'s owner is verified ($method)';
  }

  @override
  String get profilePageVerifiedSemantics => 'Owner verified';

  @override
  String get profilePostLoginToUse => 'Log in to your RASQ account to use this';

  @override
  String get profilePostLoginToReply => 'Log in to your RASQ account to reply';

  @override
  String get profilePostLoginToRebroad =>
      'Log in to your RASQ account to Rebroad';

  @override
  String get profilePostLoginToQueue => 'Log in to your RASQ account to Queue';

  @override
  String get profilePostErrorInstallPack =>
      'Install this pack from the Store to Queue with this image';

  @override
  String get profilePostErrorForbidden =>
      'You can\'t perform this action on this post';

  @override
  String get profilePostErrorRebroadLimit =>
      'This post can\'t be rebroaded any more';

  @override
  String get profilePostErrorReplyLimit =>
      'Up to 100 replies are allowed. Please delete older replies';

  @override
  String get profilePostErrorGone => 'This post / image no longer exists';

  @override
  String profilePostErrorFailed(String message) {
    return 'Failed: $message';
  }

  @override
  String get profilePostMenuReactions => 'Show reactions';

  @override
  String get profilePostMenuCopyLink => 'Copy link';

  @override
  String get profilePostMenuOpenBrowser => 'Open in browser';

  @override
  String get profilePostMenuEditActions => 'Edit action bar';

  @override
  String get profilePostMenuUnpin => 'Unpin';

  @override
  String get profilePostMenuPin => 'Pin';

  @override
  String get profilePostMenuDelete => 'Delete';

  @override
  String get profilePostLinkCopied => 'Link copied';

  @override
  String get profilePostDeleteTitle => 'Delete post';

  @override
  String get profilePostDeleteMessage =>
      'This post and its attached images will be deleted. This can\'t be undone.';

  @override
  String get profilePostDeleteConfirm => 'Delete';

  @override
  String get profilePostCancel => 'Cancel';

  @override
  String get profilePostQuoteUnavailable => 'The quoted post can\'t be viewed';

  @override
  String get profilePostReply => 'Reply';

  @override
  String get profilePostRebroad => 'Rebroad';

  @override
  String get profilePostRebroadUndo => 'Undo Rebroad';

  @override
  String get profilePostQuote => 'Quote';

  @override
  String get profilePostQueue => 'Queue';

  @override
  String get profilePostLike => 'Like';

  @override
  String get profilePostQuoteFollowersOnly =>
      'Followers-only posts can\'t be quoted';

  @override
  String profilePostRebroadedBy(String name) {
    return 'Rebroaded by $name';
  }

  @override
  String get profilePostReplyToDeleted => 'Reply to a deleted post';

  @override
  String get profilePostShare => 'Share';

  @override
  String get profilePostCwHide => 'Hide';

  @override
  String get profilePostCwShow => 'Show more';

  @override
  String get profilePostNoPacksTitle => 'No asset packs';

  @override
  String get profilePostNoPacksMessage =>
      'Queue is a reaction made with images from asset packs you got in the Store.';

  @override
  String get profilePostNoPacksStore => 'Find in Store';

  @override
  String get profilePostClose => 'Close';

  @override
  String profilePostOverlayQueueTooltip(String label) {
    return '$label (long-press to choose an image)';
  }

  @override
  String get profilePostMenu => 'Menu';

  @override
  String get profilePostTitle => 'Post';

  @override
  String get profilePostGone => 'This post no longer exists';

  @override
  String profilePostLoadFailed(String message) {
    return 'Couldn\'t load: $message';
  }

  @override
  String get profilePostParentDeleted => 'The original post has been deleted.';

  @override
  String profilePostRepliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return '$_temp0';
  }

  @override
  String get profilePostNoRepliesYet => 'No replies yet.';

  @override
  String get profilePostNoReplies => 'No replies';

  @override
  String get profilePostNoRebroads => 'No Rebroads';

  @override
  String get profilePostNoQuotes => 'No quotes';

  @override
  String get profilePostNoQueues => 'No Queues';

  @override
  String get profilePostReactionsTitle => 'Reactions';

  @override
  String get profilePostYou => 'You';

  @override
  String get quickPickEmojiTitle => 'Quick emoji';

  @override
  String get quickPickEmojiMore => 'More emoji';

  @override
  String get quickPickSettingsCaption =>
      'Long-press the reaction button or the composer\'s emoji button to open a panel attached to the button, showing the emoji here and your recently used emoji. Slide without lifting your finger and release on an emoji to add (insert) it. If you release without sliding, the panel stays open and you can tap to choose.';

  @override
  String get quickPickSettingsAdd => 'Add emoji';

  @override
  String get quickPickSettingsReset => 'Reset to default';

  @override
  String quickPickSettingsRemove(String name) {
    return 'Remove $name';
  }

  @override
  String get quickPickSettingsEmpty =>
      'No emoji. The panel will show only recently used emoji';

  @override
  String get raiModeInstruction => 'Instruction';

  @override
  String get raiModeAssistant => 'Assistant';

  @override
  String get raiGuideDefaultTitle => 'Guide';

  @override
  String raiHeldDeclined(String calls) {
    return 'Not run ($calls)';
  }

  @override
  String raiAutoDeclined(String title) {
    return 'Got it. To go through \"$title\" with a guide, tap \"Guide me through these steps\"';
  }

  @override
  String raiAutoProgress(int step, int total, String text) {
    return 'Running automatically ($step / $total): $text';
  }

  @override
  String raiAutoAskingDetail(String label) {
    return 'Choose $label';
  }

  @override
  String raiAutoAskDestination(String title) {
    return 'Where should \"$title\" import to?';
  }

  @override
  String raiAutoAskWhich(String label) {
    return 'Which $label?';
  }

  @override
  String get raiAutoAskHint =>
      'Choose from the suggestions or enter another term';

  @override
  String raiAutoNotFoundDetail(String label) {
    return '$label not found';
  }

  @override
  String raiAutoNotFoundAsk(String label) {
    return '$label wasn\'t found. Search for a different $label?';
  }

  @override
  String raiAutoAskWhichCount(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Which $label? ($count options)',
      one: 'Which $label? (1 option)',
    );
    return '$_temp0';
  }

  @override
  String raiAutoCancelled(String title) {
    return 'Stopped automating \"$title\"';
  }

  @override
  String raiAutoFailedAt(String title, int step, String detail) {
    return '\"$title\" stopped at step $step: $detail';
  }

  @override
  String raiAutoPartlyDone(int done, int step, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      done,
      locale: localeName,
      other:
          'Completed $done steps with functions. From step $step \"$text\" there are controls to tap, so I\'ll guide you',
      one:
          'Completed 1 step with functions. From step $step \"$text\" there are controls to tap, so I\'ll guide you',
    );
    return '$_temp0';
  }

  @override
  String raiAutoDone(String title) {
    return 'Completed \"$title\" with functions';
  }

  @override
  String get raiInstructionUnknown =>
      'I haven\'t learned that one yet. Try asking about \"post\", \"log in\" or \"share\".';

  @override
  String get raiAskChoice =>
      'Which one do you mean? Choose from the options above';

  @override
  String get raiNoReply => 'No response';

  @override
  String raiFailureDevice(String message) {
    return 'On-device model: $message';
  }

  @override
  String raiFailureFallUp(String message) {
    return 'Fall-up: $message';
  }

  @override
  String raiProposalReady(String title) {
    return 'Prepared the guide \"$title\" (start it from the tile below)';
  }

  @override
  String raiProposalReadyStopAt(String title, int step) {
    return 'Prepared the guide \"$title\" up to step $step (from the tile below)';
  }

  @override
  String raiHeldNote(String calls) {
    return '(Actions based on the fetched info will run after you confirm: $calls)';
  }

  @override
  String get raiNoReplyParen => '(No response)';

  @override
  String raiRestartInjecting(String keys) {
    return 'Restarting the model with the fetched info ($keys) injected';
  }

  @override
  String get raiAutoDetailReplaced => 'Replaced by a function';

  @override
  String get raiAutoDetailNoFunction => 'No matching function';

  @override
  String get raiAutoDetailGuideParts => 'Guided for controls to tap';

  @override
  String get raiAutoDetailExplanationOnly => 'Explanation only';

  @override
  String raiAutoDescribeNoBound(String title) {
    return '\"$title\" has no steps that functions can do instead, so I\'ll guide you (by pointing).';
  }

  @override
  String raiAutoDescribeHead(String title) {
    return 'I\'ll do \"$title\" with functions, without showing a guide:';
  }

  @override
  String raiAutoDescribeGuideMark(String detail) {
    return '(guided from here: $detail)';
  }

  @override
  String get raiListSeparator => ', ';

  @override
  String raiAutoDescribeFromQuestion(String inputs) {
    return 'From your question: $inputs';
  }

  @override
  String raiAutoDescribeEntrusted(String labels) {
    return '$labels will use the first suggestion (since you left it to me)';
  }

  @override
  String raiAutoDescribeAskLater(String labels) {
    return 'You\'ll choose $labels during the run';
  }

  @override
  String get raiAutoDescribeConfirm => 'If that\'s OK, tap \"Run\".';

  @override
  String raiProposalHead(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'For \"$title\", I\'ll go in this order ($count steps)',
      one: 'For \"$title\", I\'ll go in this order (1 step)',
    );
    return '$_temp0';
  }

  @override
  String raiProposalFunction(String function) {
    return '[$function]';
  }

  @override
  String raiProposalInputs(String inputs) {
    return ' Input: $inputs';
  }

  @override
  String raiProposalPresets(String presets) {
    return ' Fixed: $presets';
  }

  @override
  String get raiModeSemantics => 'RAi mode';

  @override
  String get raiAskButton => 'Ask';

  @override
  String get raiInputHint => 'Stuck? I\'m here to help!';

  @override
  String raiInputPredicted(String prediction) {
    return '$prediction (Space to enter)';
  }

  @override
  String get raiCollapse => 'Collapse';

  @override
  String get raiExpand => 'Expand';

  @override
  String get raiAskMore => 'Ask more';

  @override
  String get raiHistoryClose => 'Close history';

  @override
  String get raiHistory => 'Message history';

  @override
  String get raiClose => 'Close RAi';

  @override
  String get raiNext => 'Next';

  @override
  String get raiDone => 'Got it (close)';

  @override
  String get raiSpeechClose => 'Close';

  @override
  String get raiHistoryEmpty => 'No messages yet';

  @override
  String get raiCopy => 'Copy';

  @override
  String get raiCopied => 'Copied';

  @override
  String raiChatSuspended(int step, int total) {
    return 'Guide paused (step $step / $total). Go back to continue.';
  }

  @override
  String get raiChatResume => 'Continue';

  @override
  String get raiChatHeadline => 'Leave macros and more to me!';

  @override
  String get raiChatIntro =>
      'Ask how to do something, and RAi will point to the button.';

  @override
  String get raiChatIntroDetail =>
      'Instruction: ask how to do something and RAi moves to the button and points at it.\nAssistant: answers with an on-device model. Choose the model from the chips in the bar (macros come in phase two).';

  @override
  String get raiChatRecent => 'Recent questions';

  @override
  String get raiChatRejectCandidates =>
      'Not this (drop these suggestions and answer again)';

  @override
  String raiChatProposalTitle(String title, int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$title · $steps steps',
      one: '$title · 1 step',
    );
    return '$_temp0';
  }

  @override
  String get raiChatSkip => 'Skip';

  @override
  String get raiChatGuide => 'Guide me through these steps';

  @override
  String raiChatGuideTitle(String title) {
    return 'Guide \"$title\"';
  }

  @override
  String get raiChatTrace => 'Process';

  @override
  String get raiChatShowGraph => 'Show in graph view';

  @override
  String get raiChatApproveHeld =>
      'Run this action? (It came from the fetched info)';

  @override
  String get raiChatApprove => 'Leave it to RAi?';

  @override
  String get raiChatDecline => 'Cancel';

  @override
  String get raiChatRun => 'Run';

  @override
  String get raiHomeSidebarSemantics => 'RAi sidebar';

  @override
  String get raiHomeClose => 'Close';

  @override
  String get raiHomeNewConversation => 'New conversation';

  @override
  String get raiHomeHistory => 'Conversation history';

  @override
  String raiHomeCurrentConversation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Current conversation · $count messages',
      one: 'Current conversation · 1 message',
    );
    return '$_temp0';
  }

  @override
  String raiHomeConversationSubtitle(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$when · $count messages',
      one: '$when · 1 message',
    );
    return '$_temp0';
  }

  @override
  String get raiHomeDelete => 'Delete';

  @override
  String get raiHomeHistoryEmpty =>
      'Nothing yet. Ask a question and the conversation will be saved here.';

  @override
  String get raiHomeOther => 'Other';

  @override
  String get raiAchievementsTitle => 'Achievements';

  @override
  String raiAchievementsProgress(int unlocked, int total) {
    return '$unlocked / $total achieved';
  }

  @override
  String get raiHomeMacro => 'Macros';

  @override
  String get raiHomeMacroSoon => 'Coming soon';

  @override
  String get raiBarSemantics => 'RAi bar';

  @override
  String get raiAskCancel => 'Cancel';

  @override
  String raiAskInputHint(String label) {
    return 'Enter $label';
  }

  @override
  String raiAskInputOtherHint(String label) {
    return 'Enter another $label';
  }

  @override
  String get raiAskDone => 'Done';

  @override
  String raiAchievementsStats(
    int instructions,
    int assistant,
    int app,
    int completed,
    int repeated,
  ) {
    return 'Instruction $instructions times · Assistant $assistant times ($app about the app) · Completed $completed times · Asked again $repeated times';
  }

  @override
  String get raiAchievementAsk1Title => 'First question';

  @override
  String get raiAchievementAsk1Description => 'Asked for an instruction once';

  @override
  String get raiAchievementAsk10Title => 'Good listener';

  @override
  String get raiAchievementAsk10Description =>
      'Asked for instructions 10 times';

  @override
  String get raiAchievementAsk50Title => 'RAi regular';

  @override
  String get raiAchievementAsk50Description =>
      'Asked for instructions 50 times';

  @override
  String get raiAchievementApp5Title => 'App expert';

  @override
  String get raiAchievementApp5Description =>
      'Talked with the assistant about the app 5 times';

  @override
  String get raiAchievementChat20Title => 'Chatterbox';

  @override
  String get raiAchievementChat20Description =>
      'Talked to the assistant 20 times';

  @override
  String get raiAchievementDone1Title => 'First finish';

  @override
  String get raiAchievementDone1Description =>
      'Followed a guide to the last step';

  @override
  String get raiAchievementDone10Title => 'Finishing master';

  @override
  String get raiAchievementDone10Description =>
      'Followed guides to the end 10 times';

  @override
  String get raiAchievementAgain3Title => 'Reviewing';

  @override
  String get raiAchievementAgain3Description =>
      'Asked about the same action 3 times';

  @override
  String get raiAchievementAuto1Title => 'Leave it to RAi';

  @override
  String get raiAchievementAuto1Description => 'Left it to RAi with \"Skip\"';

  @override
  String get raiTracePortPrev => 'Prev';

  @override
  String get raiTracePortState => 'State';

  @override
  String get raiTracePortFunction => 'Function';

  @override
  String get raiTracePortResult => 'Result';

  @override
  String get raiTracePortNext => 'Next';

  @override
  String get raiTraceStatusDone => 'Done by function';

  @override
  String get raiTraceStatusSkipped => 'Collapsed';

  @override
  String get raiTraceStatusGuide => 'To guide';

  @override
  String get raiTraceStatusFailed => 'Failed';

  @override
  String get raiTraceStatusAsking => 'Awaiting choice';

  @override
  String get raiTraceStatusRunning => 'Running';

  @override
  String get raiTraceStatusPending => 'Not run';

  @override
  String raiTraceCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Process: $count steps',
      one: 'Process: 1 step',
    );
    return '$_temp0';
  }

  @override
  String get raiDiagTitle => 'Diagnostics (developer mode)';

  @override
  String get raiDiag3dOn => '3D RAi: on';

  @override
  String get raiDiag3dOff => '3D RAi: off (shown in 2D)';

  @override
  String get raiDiag3dOffAndroid =>
      '3D RAi: off (2D by default on Android; turn on with \"Try 3D RAi (Android)\" in developer mode)';

  @override
  String raiDiag3dFailed(String reason) {
    return '3D RAi: failed, so switched to 2D ($reason)';
  }

  @override
  String raiDiagLlm(String phase, String message) {
    return 'On-device LLM: $phase ($message)';
  }

  @override
  String raiDiagEmbedding(String phase, String message) {
    return 'Embedding model: $phase ($message)';
  }

  @override
  String get raiDiagEmpty => 'No recorded failures';

  @override
  String get raiDiagRetry3d => 'Try 3D again';

  @override
  String raiFunctionsSettingMissing(String area, String key, String keys) {
    return 'There is no setting \"$key\" in \"$area\" (available: $keys)';
  }

  @override
  String raiFunctionsSettingNotWritable(String key) {
    return '\"$key\" is not a setting that can be written from the screen';
  }

  @override
  String raiFunctionsSettingNeedsPassword(String key) {
    return '\"$key\" requires a password, so RAi won\'t write it';
  }

  @override
  String raiFunctionsSettingLocked(String key) {
    return '\"$key\" has a no-operation tag, so RAi won\'t write it';
  }

  @override
  String raiFunctionsFoldEmpty(String head) {
    return '$head: none found';
  }

  @override
  String raiFunctionsFoldHead(String head, int total, int shown) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$head ($shown of $total):',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsUnsupported(String name) {
    return 'Not available on this SNS ($name)';
  }

  @override
  String raiFunctionsNotAutomatable(String name, String alt, String result) {
    return '$name can\'t be automated (the user presses send). Instead, $alt: $result';
  }

  @override
  String raiFunctionsUnknown(String name) {
    return 'Unknown function: $name';
  }

  @override
  String raiFunctionsFailed(String name, String error) {
    return '$name failed: $error';
  }

  @override
  String get raiFunctionsNotLoggedInSns => 'Not logged in to an SNS';

  @override
  String raiFunctionsLineReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count reactions)',
      one: '(1 reaction)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsPostsNone => 'No matching posts found';

  @override
  String raiFunctionsPostsHead(int count, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts (of $total):',
      one: '1 post (of $total):',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsReferenceOperation(String title, String id, String steps) {
    return 'Operation \"$title\" ($id): $steps';
  }

  @override
  String raiFunctionsReferenceFunction(String id, String does) {
    return 'Function $id: $does';
  }

  @override
  String raiFunctionsReferenceParams(String params) {
    return ' Arguments: $params';
  }

  @override
  String get raiFunctionsReferenceParamInput => 'input';

  @override
  String raiFunctionsReferenceParamFixed(String value) {
    return 'fixed=$value';
  }

  @override
  String raiFunctionsReferenceMissing(String id) {
    return '$id is not in the reference';
  }

  @override
  String raiFunctionsActionMissing(String id) {
    return 'There is no action $id';
  }

  @override
  String raiFunctionsActionNotAllowed(String label) {
    return '\"$label\" is not allowed to be automated (RAi won\'t run it). Instead, guide the user through the steps, or have the user press it';
  }

  @override
  String raiFunctionsActionDone(String label, String state) {
    return 'Ran $label ($state)';
  }

  @override
  String get raiFunctionsActionDoneYes => 'done';

  @override
  String get raiFunctionsActionDoneNo => 'not done';

  @override
  String get raiFunctionsAstellNoRooms => 'No ASTell rooms';

  @override
  String raiFunctionsAstellRooms(String rooms) {
    return 'ASTell rooms: $rooms';
  }

  @override
  String get raiFunctionsAstellNoTitle => 'No title given';

  @override
  String raiFunctionsAstellCreated(String title, String id) {
    return 'Created ASTell \"$title\" [$id]';
  }

  @override
  String raiFunctionsNotifReaction(String who, String reaction) {
    return '$who reacted$reaction';
  }

  @override
  String raiFunctionsNotifRepost(String who) {
    return '$who renoted';
  }

  @override
  String raiFunctionsNotifQuote(String who) {
    return '$who quoted';
  }

  @override
  String raiFunctionsNotifReply(String who) {
    return '$who replied';
  }

  @override
  String raiFunctionsNotifMention(String who) {
    return '$who mentioned you';
  }

  @override
  String raiFunctionsNotifFollow(String who) {
    return '$who followed you';
  }

  @override
  String raiFunctionsNotifFollowRequest(String who) {
    return '$who sent a follow request';
  }

  @override
  String raiFunctionsNotifFollowAccepted(String who) {
    return '$who accepted your follow request';
  }

  @override
  String raiFunctionsNotifListAdded(String who) {
    return '$who added you to a list';
  }

  @override
  String get raiFunctionsNotifPollEnded => 'Poll ended';

  @override
  String get raiFunctionsNotifTimer => 'Timer notification';

  @override
  String get raiFunctionsNotifVc => 'ASTell notification';

  @override
  String get raiFunctionsNotifSystem => 'System notification';

  @override
  String get raiFunctionsNotifOther => 'Other notification';

  @override
  String get raiFunctionsUnreadMark => '(unread)';

  @override
  String get raiFunctionsMissingPostId => 'Missing post id (id=)';

  @override
  String get raiFunctionsMissingPostArg => 'Missing post id (post=)';

  @override
  String raiFunctionsThreadReply(String line) {
    return 'Reply: $line';
  }

  @override
  String get raiFunctionsHeadThread => 'Thread';

  @override
  String get raiFunctionsHeadReactions => 'Reactions';

  @override
  String get raiFunctionsHeadReposters => 'Renoted by';

  @override
  String get raiFunctionsHeadQuotes => 'Quotes';

  @override
  String get raiFunctionsHeadFavorites => 'Favorites';

  @override
  String get raiFunctionsHeadReacted => 'Reacted';

  @override
  String raiFunctionsMe(String user, String plugin) {
    return 'Me: $user plugin=$plugin';
  }

  @override
  String get raiFunctionsUserIdOrHandle => 'Specify id= or handle=';

  @override
  String get raiFunctionsNotFound => 'Not found';

  @override
  String raiFunctionsUserCounts(String followers, String following) {
    return ' followers $followers following $following';
  }

  @override
  String get raiFunctionsMissingUser => 'Missing user id (user=)';

  @override
  String raiFunctionsHeadUserPosts(String filter) {
    return 'Posts ($filter)';
  }

  @override
  String get raiFunctionsMissingKeyword => 'Missing keyword';

  @override
  String raiFunctionsHeadUserSearch(String keyword) {
    return 'User search \"$keyword\"';
  }

  @override
  String get raiFunctionsHeadFollowing => 'Following';

  @override
  String get raiFunctionsHeadFollowers => 'Followers';

  @override
  String get raiFunctionsRelFollowing => 'following';

  @override
  String get raiFunctionsRelFollowedBy => 'follows you';

  @override
  String get raiFunctionsRelRequested => 'requested';

  @override
  String get raiFunctionsRelMuted => 'muted';

  @override
  String get raiFunctionsRelBlocked => 'blocked';

  @override
  String get raiFunctionsRelBlockedBy => 'blocks you';

  @override
  String get raiFunctionsRelNone => 'none';

  @override
  String raiFunctionsRelation(String flags) {
    return 'Relationship: $flags';
  }

  @override
  String raiFunctionsRequestLine(String user, String id) {
    return '$user [request $id]';
  }

  @override
  String raiFunctionsHeadModeration(String kind) {
    return 'Moderation ($kind)';
  }

  @override
  String raiFunctionsHeadNotifications(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: 'Notifications ($unread unread)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNotificationsRead => 'Marked notifications as read';

  @override
  String raiFunctionsTrendLine(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag ($count people)',
      one: '$tag (1 person)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadTrends => 'Trends';

  @override
  String raiFunctionsListLine(String name, String id, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name [$id] ($count members)',
      one: '$name [$id] (1 member)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadLists => 'Lists';

  @override
  String get raiFunctionsMissingList => 'Missing list id (list=)';

  @override
  String get raiFunctionsHeadListMembers => 'List members';

  @override
  String raiFunctionsClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count items)',
      one: '(1 item)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadClips => 'Clips';

  @override
  String get raiFunctionsMissingClip => 'Missing clip id (clip=)';

  @override
  String get raiFunctionsHeadClipNotes => 'Clip contents';

  @override
  String get raiFunctionsHeadFeeds => 'Feeds';

  @override
  String raiFunctionsDmUnread(int count) {
    return '($count unread)';
  }

  @override
  String raiFunctionsHeadEmoji(String keyword) {
    return 'Emoji \"$keyword\"';
  }

  @override
  String get raiFunctionsUnfollowed => 'Unfollowed';

  @override
  String get raiFunctionsFollowRequested => 'Sent a follow request';

  @override
  String get raiFunctionsFollowed => 'Followed';

  @override
  String get raiFunctionsListUserArgs => 'Specify list= and user=';

  @override
  String get raiFunctionsListAdded => 'Added to the list';

  @override
  String get raiFunctionsListRemoved => 'Removed from the list';

  @override
  String get raiFunctionsMissingName => 'Missing name (name=)';

  @override
  String raiFunctionsListCreated(String name, String id) {
    return 'Created list \"$name\" [$id]';
  }

  @override
  String get raiFunctionsClipPostArgs => 'Specify clip= and post=';

  @override
  String get raiFunctionsClipAdded => 'Added to the clip';

  @override
  String get raiFunctionsClipRemoved => 'Removed from the clip';

  @override
  String raiFunctionsClipCreated(String name, String id) {
    return 'Created clip \"$name\" [$id]';
  }

  @override
  String get raiFunctionsAreaKeyArgs => 'Specify area= and key=';

  @override
  String raiFunctionsSettingsPageMissing(String area) {
    return 'There is no settings page \"$area\"';
  }

  @override
  String get raiFunctionsAreaKeyValueArgs => 'Specify area=, key= and value=';

  @override
  String raiFunctionsSettingBadValue(String key, String value, String current) {
    return '\"$value\" can\'t be set for \"$key\" (current value: $current)';
  }

  @override
  String raiFunctionsSettingSet(String area, String key, String value) {
    return 'Set $area.$key to $value';
  }

  @override
  String get raiFunctionsMissingText => 'Missing text (text=)';

  @override
  String get raiFunctionsMissingRoom => 'Missing room id (room=)';

  @override
  String raiFunctionsDmRoomMissing(String id) {
    return 'There is no DM room $id';
  }

  @override
  String raiFunctionsComposeFilled(String target) {
    return 'Put a draft for $target in the composer (not sent)';
  }

  @override
  String raiFunctionsFeedNotFound(String feed) {
    return 'Feed \"$feed\" not found';
  }

  @override
  String raiFunctionsFeedSaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Saved \"$name\" ($count saved)',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsFeedUnsaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Unsaved \"$name\" ($count saved)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNoBluesky =>
      'No Bluesky account (custom feeds are Bluesky only)';

  @override
  String raiFunctionsFeedAlreadyHome(String name) {
    return '\"$name\" is already in your home timeline';
  }

  @override
  String raiFunctionsFeedAddedHome(String name, String account) {
    return 'Added \"$name\" ($account) to the home timeline';
  }

  @override
  String get raiFunctionsNotLoggedInRasq => 'Not logged in to a RASQ account';

  @override
  String get raiFunctionsRasqListMine => 'mine';

  @override
  String get raiFunctionsRasqListUnfetchable => 'can\'t be imported';

  @override
  String get raiFunctionsRasqListFollowing => 'following';

  @override
  String raiFunctionsRasqListLine(String name, int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name ($count people · $state)',
      one: '$name (1 person · $state)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadRasqLists => 'RASQ lists';

  @override
  String get raiFunctionsMissingListArg => 'Missing list (list=)';

  @override
  String raiFunctionsRasqListNotFound(String query) {
    return 'RASQ list \"$query\" not found';
  }

  @override
  String get raiFunctionsMissingWord => 'Missing word (word=)';

  @override
  String get raiFunctionsNotLoggedIn => 'Not logged in';

  @override
  String raiFunctionsWordExcludeAlready(String word) {
    return '\"$word\" is already excluded';
  }

  @override
  String raiFunctionsWordIncludeAlready(String word) {
    return '\"$word\" is already a filter';
  }

  @override
  String raiFunctionsWordExcluded(String word, String scope) {
    return 'Posts containing \"$word\" will now be excluded from the $scope timeline';
  }

  @override
  String raiFunctionsWordIncluded(String word, String scope) {
    return 'Only posts containing \"$word\" will now be shown in the $scope timeline';
  }

  @override
  String get raiFunctionsFeedKindLabel => 'Feed';

  @override
  String get raiFunctionsHeadFeedTimeline => 'Feed timeline';

  @override
  String raiFunctionsPageList(String name, String id) {
    return 'List $name [$id]';
  }

  @override
  String raiFunctionsPageFeed(String name, String uri) {
    return 'Feed $name [$uri]';
  }

  @override
  String get raiFunctionsHeadListsPage => 'Lists page';

  @override
  String get raiFunctionsHeadNotificationsPage => 'Notifications';

  @override
  String get raiFunctionsHeadHomeTimeline => 'Home timeline';

  @override
  String get raiFunctionsMissingSource => 'Missing source (source=)';

  @override
  String raiFunctionsSeedNoPosts(String label) {
    return '\"$label\" has no posts, so no characteristic words could be extracted';
  }

  @override
  String raiFunctionsSeedNoWords(String label) {
    return 'Couldn\'t extract characteristic words from \"$label\"';
  }

  @override
  String get raiFunctionsSeedWordSeparator => ', ';

  @override
  String raiFunctionsSeedAdded(String label, String words) {
    return 'Added the characteristic words of \"$label\" ($words) to your trend orientation (favorite genres)';
  }

  @override
  String get raiFunctionsMissingQuery => 'Missing search query (q=)';

  @override
  String raiFunctionsHeadWeb(String query) {
    return 'Web \"$query\"';
  }

  @override
  String get raiFunctionsNotAutomatableMark => '(can\'t be automated)';

  @override
  String get raiFunctionsHeadActions => 'Actions';

  @override
  String get raiModelsTitle => 'Models';

  @override
  String get raiModelsClose => 'Close';

  @override
  String get raiModelsRamUnknown => 'RAM: unknown';

  @override
  String raiModelsRamFree(String gb) {
    return '($gb GB free)';
  }

  @override
  String raiModelsCaption(String codename, String ram) {
    return '$codename = a model that runs on this device. $ram';
  }

  @override
  String raiModelsCaptionDetail(String codename, String label, String ram) {
    return '$codename = on-device model ($label). $ram';
  }

  @override
  String get raiModelsSectionLocal => 'Local';

  @override
  String get raiModelsSectionEmbedding => 'RAi search and post embeddings';

  @override
  String get raiModelsPostVisionReady =>
      'Related TL and TL algorithms also compare post images';

  @override
  String get raiModelsPostVisionIdle =>
      'Lets related TL and TL algorithms compare post images as well as text (also install the text model)';

  @override
  String get raiModelsSectionEmoji => 'Emoji image search (both are required)';

  @override
  String get raiModelsEmojiTextReady => 'Search emoji images by what you type';

  @override
  String get raiModelsEmojiTextIdle =>
      'Lets you search emoji images by meaning (also install the image model)';

  @override
  String get raiModelsEmojiVisionReady =>
      'Emoji images are loaded gradually in the background (once per server)';

  @override
  String get raiModelsEmojiVisionIdle =>
      'Lets you find emoji whose names aren\'t meaningful by what the image shows';

  @override
  String get raiModelsSectionCloud => 'Cloud (when the device can\'t answer)';

  @override
  String get raiModelsCompletionCaption =>
      'Completion rate = the share of guides and answers that went well all the way to the end.';

  @override
  String get raiModelsCompletionCaptionDetail =>
      'Completion rate = aggregated share of action guides / answers that held up to the end (only models under 35B are counted; \"-%\" in demos).';

  @override
  String get raiModelsRateExcluded => 'Not counted';

  @override
  String get raiModelsNotConnected => 'Not connected';

  @override
  String get raiModelsPhaseNotInstalled => 'Not downloaded';

  @override
  String raiModelsPhaseDownloading(int percent) {
    return 'Downloading $percent%';
  }

  @override
  String get raiModelsPhaseReady => 'Ready';

  @override
  String get raiModelsPhaseReadyBundled => 'Ready (bundled)';

  @override
  String get raiModelsPhaseLoading => 'Loading';

  @override
  String get raiModelsPhaseGenerating => 'Generating';

  @override
  String get raiModelsPhaseUnavailable => 'Unavailable';

  @override
  String get raiModelsPillCloud => 'Cloud';

  @override
  String get raiModelsPillLocal => 'Local';

  @override
  String raiModelsCloudLine(String label, String params) {
    return '$label · ${params}B · Cloud';
  }

  @override
  String raiModelsCompletionRate(String rate) {
    return 'Completion rate $rate';
  }

  @override
  String get raiModelsMemoryNotNeeded => 'Memory: not needed on device';

  @override
  String raiModelsMemory(String verdict) {
    return 'Memory: $verdict';
  }

  @override
  String get raiModelsUse => 'Use';

  @override
  String get raiModelsExtract => 'Extract (bundled)';

  @override
  String get raiModelsDownload => 'Download';

  @override
  String get raiModelsRelease => 'Free memory';

  @override
  String get raiModelsDeleteTitle => 'Delete model?';

  @override
  String raiModelsDeleteMessage(String file) {
    return '$file will be removed from this device.';
  }

  @override
  String get raiModelsDelete => 'Delete';

  @override
  String get raiModelsCancel => 'Cancel';

  @override
  String raiModelsEmbeddingLine(String file, int size, int dims) {
    return 'onnxruntime · $file · approx. $size MB · $dims dimensions';
  }

  @override
  String get raiModelsSearchSemantic => 'Searches by similarity of meaning';

  @override
  String raiModelsSearchSemanticDetail(String label) {
    return 'Search: $label (lookup by meaning)';
  }

  @override
  String get raiModelsSearchNgram =>
      'Currently searches by word match. Downloading makes it better at paraphrases';

  @override
  String get raiModelsSearchNgramDetail =>
      'Search: n-gram fallback (lookup by word match; downloading makes it better at paraphrases)';

  @override
  String get raiModelsServerTitle => 'Local inference server';

  @override
  String get raiModelsServerConfigured => 'Configured';

  @override
  String get raiModelsServerNotConfigured => 'Not set';

  @override
  String get raiModelsServerCaption =>
      'Asked when the on-device model can\'t answer.';

  @override
  String get raiModelsServerCaptionDetail =>
      'An OpenAI-compatible chat API (llama-server / vLLM, etc.). When the on-device model fails or doesn\'t respond, the question is passed along with closely matching references.';

  @override
  String get raiModelsServerModelHint => 'Model name (optional)';

  @override
  String get raiModelsRamOk => 'OK';

  @override
  String get raiModelsRamTight => 'Tight';

  @override
  String get raiModelsRamNo => 'Not enough memory';

  @override
  String get raiModelsRamUnknownVerdict => 'Unknown';

  @override
  String get raiModelsFallUpNotConnected =>
      'The fall-up target (server side) isn\'t connected';

  @override
  String raiModelsServerHttpError(int status) {
    return 'Inference server HTTP $status';
  }

  @override
  String get raiModelsServerNoReply => 'No response from the inference server';

  @override
  String raiModelsServerUnreachable(String error) {
    return 'Can\'t reach the inference server: $error';
  }

  @override
  String get raiModelsLlmUnavailableHere =>
      'On-device models aren\'t available in this environment';

  @override
  String raiModelsLlamaFetching(String tag) {
    return 'Fetching the llama.cpp runtime ($tag)';
  }

  @override
  String get raiModelsLlamaMissingIos =>
      'llama.cpp isn\'t embedded (add llama.xcframework to Runner)';

  @override
  String get raiModelsLlamaMissing => 'The llama.cpp library is missing';

  @override
  String raiModelsLlamaFetchFailed(int status) {
    return 'Can\'t fetch the llama.cpp runtime (HTTP $status)';
  }

  @override
  String raiModelsStateCheckFailed(String error) {
    return 'Can\'t check the model status: $error';
  }

  @override
  String get raiModelsExtracting => 'Extracting bundled model';

  @override
  String get raiModelsExtractTooLarge =>
      'The bundled model can\'t be extracted on this device (please download it)';

  @override
  String raiModelsExtractFailed(String error) {
    return 'Extraction failed: $error';
  }

  @override
  String raiModelsDownloadFailed(String error) {
    return 'Download failed: $error';
  }

  @override
  String raiModelsNotDownloaded(String codename) {
    return 'The on-device model ($codename) hasn\'t been downloaded yet';
  }

  @override
  String get raiModelsDeviceUnavailable => 'The on-device model is unavailable';

  @override
  String raiModelsFileMissing(String path) {
    return 'Model file not found: $path';
  }

  @override
  String get raiModelsTimeoutFirstToken =>
      'The on-device model didn\'t respond for 30 seconds';

  @override
  String get raiModelsTimeoutOverall =>
      'The on-device model\'s response took too long, so it was stopped';

  @override
  String get raiModelsOnlyThinking =>
      'No response from the on-device model (it may have ended with only thinking)';

  @override
  String raiModelsGenerateFailed(String error) {
    return 'Generation failed: $error';
  }

  @override
  String get raiModelsHintSystemPolicy =>
      '\"system policy\" = rejected by sandbox / library validation. Rebuild with the Debug entitlements (app-sandbox=false, disable-library-validation)';

  @override
  String get raiModelsHintGatekeeper =>
      'If blocked by Gatekeeper: allow it in \"System Settings > Privacy & Security\", or run xattr -dr com.apple.quarantine on the dylib in Application Support/llama_cpp';

  @override
  String raiModelsLoadFailedLlama(String error) {
    return 'Can\'t load the model (llama.cpp): $error';
  }

  @override
  String raiModelsLoadFailed(String error) {
    return 'Couldn\'t load the model: $error';
  }

  @override
  String get raiModelsEmbeddingRasqText => 'RASQ MiniLM (text)';

  @override
  String get raiModelsEmbeddingMiniLmL12 =>
      'MiniLM-L12 multilingual (paraphrase, int8)';

  @override
  String get raiModelsEmbeddingRasqVision => 'RASQ MobileNet (post images)';

  @override
  String get raiModelsEmbeddingSiglipText => 'SigLIP2 base (text tower, int8)';

  @override
  String get raiModelsEmbeddingSiglipVision =>
      'SigLIP2 base (image side, int8)';

  @override
  String raiModelsEmbeddingFailed(String message) {
    return 'Failed: $message';
  }

  @override
  String get raiModelsEmbeddingUnavailableHere =>
      'On-device embedding models aren\'t available in this environment';

  @override
  String get raiModelsChecksumMismatch =>
      'The model file is corrupted (sha256 mismatch)';

  @override
  String get raiModelsSizeMismatch => 'The model file is truncated';

  @override
  String get raiModelsCentralNotConfigured => 'RASQ server address is not set';

  @override
  String raiModelsLoadFailedOnnx(String error) {
    return 'Can\'t load the model (onnxruntime): $error';
  }

  @override
  String get raiModelsWebDisabled => 'Web search isn\'t available yet';

  @override
  String get raiModelsWebNoKey => 'No Brave Search key is set';

  @override
  String get raiModelsWebAnswerTitle => 'Web answer';

  @override
  String raiModelsWebFailed(String error) {
    return 'Search failed: $error';
  }

  @override
  String get raiModelsNoteNotInstalled => 'Not DL\'d';

  @override
  String get regionHeading => 'Where you live';

  @override
  String get regionCaption =>
      'Choose the country or region where you live (self-declared). In the United States, also choose your state.';

  @override
  String get regionChoose => 'Choose';

  @override
  String regionCountryAndState(String country, String state) {
    return '$country, $state';
  }

  @override
  String get regionPickerTitle => 'Choose where you live';

  @override
  String get regionStatePickerTitle => 'Choose a state';

  @override
  String get regionSearchHint => 'Search countries and regions';

  @override
  String get regionStateSearchHint => 'Search states';

  @override
  String get regionNoMatch => 'No matches';

  @override
  String get regionUnavailableBadge => 'Not available';

  @override
  String get regionUnavailableTitle =>
      'RASQ isn\'t available in your region yet';

  @override
  String get regionUnavailableBody =>
      'RASQ is currently available only in some regions. You can\'t create a RASQ account in your region. The regions we serve may change in the future.';

  @override
  String regionUnavailableBodyWith(String region) {
    return 'RASQ is currently available only in some regions. You can\'t create a RASQ account in $region. The regions we serve may change in the future.';
  }

  @override
  String get regionUnavailableBack => 'Back';

  @override
  String get regionRequiredError => 'Choose where you live, then try again.';

  @override
  String get relationalPostTitle => 'Post';

  @override
  String relationalEventTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name +$count',
    );
    return '$_temp0';
  }

  @override
  String relationalEventCaption(int posts, int members) {
    String _temp0 = intl.Intl.pluralLogic(
      posts,
      locale: localeName,
      other: '$posts posts',
      one: '1 post',
    );
    String _temp1 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members people',
      one: '1 person',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String relationalEventPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return '$_temp0';
  }

  @override
  String relationalDurationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String relationalDurationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String relationalDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String relationalLookback(String duration) {
    return 'Showing conversations from up to $duration ago';
  }

  @override
  String get relationalLookbackReset => 'Reset';

  @override
  String get relationalHeader => 'Grouped by conversation';

  @override
  String relationalHeaderDetail(int bias, int maxMinutes) {
    return 'Linking ease $bias / sinks after up to $maxMinutes min depending on conversation pace';
  }

  @override
  String get relationalTuningTitle => 'Relational timeline tuning';

  @override
  String get relationalRetry => 'Reload';

  @override
  String get relationalEmptyTitle => 'No conversations in progress';

  @override
  String get relationalEmptyHint =>
      'Conversations among people you follow are grouped here. Pull down to see past conversations too';

  @override
  String get relationalTuningCancel => 'Cancel';

  @override
  String get relationalTuningConfirm => 'Done';

  @override
  String get relationalAdvanced => 'Advanced';

  @override
  String get relationalSectionLinking => 'Linking';

  @override
  String get relationalCandidateWindow => 'Candidate window';

  @override
  String get relationalCandidateWindowSubtitle =>
      'Recent range to search for parent candidates';

  @override
  String relationalMinutesValue(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes min',
      one: '1 min',
    );
    return '$_temp0';
  }

  @override
  String relationalSecondsValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds sec',
      one: '1 sec',
    );
    return '$_temp0';
  }

  @override
  String get relationalSectionWeightsPlain => 'Weights (regular posts)';

  @override
  String get relationalWeightContent => 'Content similarity';

  @override
  String get relationalWeightEntity => 'Entity match';

  @override
  String get relationalWeightTime => 'Time decay';

  @override
  String get relationalWeightAffinity => 'Pair affinity';

  @override
  String get relationalWeightTurn => 'Turn-taking';

  @override
  String get relationalWeightAnchor => 'Anchor';

  @override
  String get relationalSectionFlatBonus => 'Flat bonus';

  @override
  String get relationalWeightCommunityPrior => 'Community prior ±';

  @override
  String get relationalSectionLifecycle => 'Lifecycle';

  @override
  String get relationalTentativeHold => 'Tentative ROOT hold';

  @override
  String get relationalTentativeHoldSubtitle =>
      'How long to wait before confirming a new topic';

  @override
  String get relationalResetDefaults => 'Reset to defaults';

  @override
  String get relationalLinkBias => 'Linking ease';

  @override
  String get relationalLinkBiasSubtitle =>
      'Lower groups more broadly (thresholds auto-tuned per community)';

  @override
  String get relationalTauSubtitle =>
      'Higher links posts further apart in time more easily (τ)';

  @override
  String get relationalSectionWeights => 'Weights';

  @override
  String get relationalSimilarity => 'Similarity';

  @override
  String get relationalSimilaritySubtitle =>
      'Content similarity + entity match (breakdown in Advanced)';

  @override
  String get relationalCloseness => 'Closeness';

  @override
  String get relationalClosenessSubtitle =>
      'Pair affinity + turn-taking (breakdown in Advanced)';

  @override
  String get relationalSectionExtra => 'Extra signals';

  @override
  String get relationalHardAnchor => 'Hard anchor (URL/quoted post)';

  @override
  String get relationalReactive => 'Reactions (\"so true\", \"same\", etc.)';

  @override
  String get relationalTtlSubtitle =>
      'Time until a conversation sinks. Auto-tuned within this range based on posting intervals';

  @override
  String relationalTtlValue(int min, int max) {
    return '$min–$max min';
  }

  @override
  String get searchChildSafePostsBlocked =>
      'Your guardian has turned off post search';

  @override
  String get searchChildSafeTrendBlocked =>
      'Your guardian has turned off trends';

  @override
  String get searchTrendSettings => 'Trend settings';

  @override
  String get searchTrendCustomize => 'Customize trend page';

  @override
  String get searchTrendPage => 'Trend page';

  @override
  String get searchTrendMenu => 'Menu';

  @override
  String get searchHint => 'Search';

  @override
  String get searchSettings => 'Search settings';

  @override
  String get searchSettingsTendency => 'Search result orientation/intensity';

  @override
  String get searchSettingsTrendPlugins => 'Trend plugin settings';

  @override
  String get searchSettingsCacheNetwork => 'Cache network settings';

  @override
  String get searchSettingsComingSoon => 'This setting is coming soon.';

  @override
  String get searchSortRelevance => 'Most relevant';

  @override
  String get searchSortNewest => 'Newest';

  @override
  String get searchSortOldest => 'Oldest';

  @override
  String get searchSortReactions => 'Most reactions';

  @override
  String get searchPeriodAll => 'All time';

  @override
  String get searchPeriodDay => '24 hours';

  @override
  String get searchPeriodWeek => '1 week';

  @override
  String get searchPeriodMonth => '1 month';

  @override
  String get searchPeriodChip => 'Period';

  @override
  String get searchAgoJustNow => 'Just now';

  @override
  String searchAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String searchAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String searchAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get serversOpen => 'Open server';

  @override
  String serversUsers(String count) {
    return '$count users';
  }

  @override
  String serversPosts(String count) {
    return '$count posts';
  }

  @override
  String get serversRegistrationOpen => 'Open for registration';

  @override
  String get serversRegistrationClosed => 'Invite only / closed';

  @override
  String get serversStatsSeparator => ' · ';

  @override
  String get serversRaiTitle => 'User tendencies by RAi';

  @override
  String serversRaiSource(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Summarized by cloud RAi from $count public posts',
      one: 'Summarized by cloud RAi from 1 public post',
    );
    return '$_temp0';
  }

  @override
  String get serversInfoTitle => 'Server info';

  @override
  String serversInfoUnavailable(String host) {
    return '$host doesn\'t provide server info (it may be a service without instances, or it couldn\'t be fetched)';
  }

  @override
  String serversCountHundredMillions(String value) {
    return '$value×100M';
  }

  @override
  String serversCountTenThousands(String value) {
    return '$value×10K';
  }

  @override
  String get sessionUnnamedDevice => 'Unnamed device';

  @override
  String get sessionShareAskFirstTitle =>
      'Share access tokens and log in to your SNS accounts all at once?';

  @override
  String sessionShareAskDeviceTitle(String device) {
    return 'Share SNS access tokens with the new device ($device) too?';
  }

  @override
  String sessionShareAskFirstMessage(String devices) {
    return 'This RASQ account was logged in on a new device ($devices). If you choose \"Yes\", your SNS access tokens are shared between devices with end-to-end (E2E) encryption, and the new device also logs in to your SNS accounts. RASQ\'s server can\'t read the contents. You can change this later in \"Account security\".';
  }

  @override
  String sessionShareAskFirstMessageHandle(String devices, String handle) {
    return 'The RASQ account @$handle was logged in on a new device ($devices). If you choose \"Yes\", your SNS access tokens are shared between devices with end-to-end (E2E) encryption, and the new device also logs in to your SNS accounts. RASQ\'s server can\'t read the contents. You can change this later in \"Account security\".';
  }

  @override
  String get sessionShareAskDeviceMessage =>
      'This RASQ account was logged in from a new device. If you don\'t recognize it, choose \"No\" and log that device out in \"Account security\".';

  @override
  String sessionShareAskDeviceMessageHandle(String handle) {
    return 'The RASQ account @$handle was logged in from a new device. If you don\'t recognize it, choose \"No\" and log that device out in \"Account security\".';
  }

  @override
  String get sessionDeviceListSeparator => ', ';

  @override
  String get sessionShareYes => 'Yes';

  @override
  String get sessionShareNo => 'No';

  @override
  String sessionShareEmailApproved(String device) {
    return 'Shared SNS access tokens with the device approved by email ($device)';
  }

  @override
  String sessionShareImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Logged in to $count SNS accounts with shared access tokens',
      one: 'Logged in to 1 SNS account with shared access tokens',
    );
    return '$_temp0';
  }

  @override
  String get sessionLoginFailed => 'Login failed';

  @override
  String get sessionSanctionLight => 'Light restriction';

  @override
  String get sessionSanctionModerate =>
      'Moderate restriction (posts delayed for review)';

  @override
  String get sessionSanctionSevere => 'Severe restriction (features suspended)';

  @override
  String get sessionSanctionPermanent => 'Permanent suspension';

  @override
  String get sessionSanctionNone => 'No restrictions';

  @override
  String sessionSanctionBlocked(String feature) {
    return '$feature is unavailable due to an action on your account.';
  }

  @override
  String sessionSanctionBlockedUntil(String feature, String until) {
    return '$feature is unavailable due to an action on your account (until $until).';
  }

  @override
  String get sessionFeatureAstellJoin => 'Joining ASTell';

  @override
  String get sessionFeatureAstellCreate => 'Creating ASTell rooms';

  @override
  String get sessionFeatureAstellShare => 'Sharing and chat in ASTell';

  @override
  String get sessionFeatureAstellStream =>
      'Screen sharing and streaming in ASTell';

  @override
  String get sessionFeatureStoreReview => 'Posting Store reviews';

  @override
  String get sessionFeatureAccountFollow => 'Following RASQ accounts';

  @override
  String get sessionFeaturePost => 'Posting';

  @override
  String get sessionFeaturePostMedia => 'Posting with media';

  @override
  String get sessionFeatureDm => 'DMs';

  @override
  String get sessionFeatureReaction => 'Reactions';

  @override
  String get sessionCentralNotConfigured =>
      'No RASQ Central server is configured';

  @override
  String get sessionLogoutSnsHeading => 'SNS accounts in this RASQ account';

  @override
  String get sessionLogoutSnsLogout => 'Also log out of SNS accounts';

  @override
  String get sessionLogoutSnsLogoutSubtitle =>
      'Removes the SNS sign-ins from this device';

  @override
  String get sessionLogoutSnsMoveToLocal => 'Move to This device only';

  @override
  String get sessionLogoutSnsMoveToLocalSubtitle =>
      'Keep using them as \"This device only\" accounts';

  @override
  String get sessionCancel => 'Cancel';

  @override
  String get sessionChildSafeAddBlocked =>
      'Your guardian has blocked adding SNS accounts';

  @override
  String get sessionAccountKindLocal => 'This device only';

  @override
  String get sessionAccountKindCentral => 'RASQ Central';

  @override
  String get sessionCarryThisAccount => 'this RASQ account';

  @override
  String get sessionCarrySemantics => 'Add this device\'s SNS accounts?';

  @override
  String sessionCarryTitle(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add the $count accounts open on this device to $account?',
      one: 'Add the 1 account open on this device to $account?',
    );
    return '$_temp0';
  }

  @override
  String sessionCarryMessage(String account) {
    return 'Added accounts become SNS accounts of $account and also appear on your other devices and the Web console. Accounts you don\'t add stay in \"This device only\" (you can add them later by logging in to the SNS with $account).';
  }

  @override
  String get sessionCarryInBundle =>
      ' (previously linked with this RASQ account)';

  @override
  String get sessionCarryNone => 'Don\'t add';

  @override
  String sessionCarryAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count selected',
      one: 'Add 1 selected',
    );
    return '$_temp0';
  }

  @override
  String get settingsActionBarTitle => 'Plugin buttons';

  @override
  String get settingsActionBarBackTooltip => 'Back';

  @override
  String get settingsActionBarBundleManual =>
      'Manual (hidden until added from (+) on the bar)';

  @override
  String get settingsActionBarBundleAlone => 'On its own, at the end';

  @override
  String settingsActionBarBundleInto(String label, String percent) {
    return 'Bundled with \"$label\" ($percent%)';
  }

  @override
  String get settingsActionBarAutoOnTitle =>
      'Turn on automatically when the surface opens';

  @override
  String get settingsActionBarOn => 'On';

  @override
  String get settingsActionBarOff => 'Off';

  @override
  String settingsActionBarAutoDefault(String state) {
    return 'Default ($state)';
  }

  @override
  String settingsActionBarAutoDefaultDeclared(String state) {
    return 'Default ($state, declared by the plugin)';
  }

  @override
  String settingsActionBarAutoOverridden(String state) {
    return 'Overridden in settings (default: $state)';
  }

  @override
  String get settingsActionBarEmptyCaption =>
      'Plugins you add from the Store appear here';

  @override
  String get settingsActionBarIntroCaption =>
      'Turning a switch off hides it on all accounts.';

  @override
  String get settingsActionBarIntroDetail =>
      'The switch is the device-wide master switch (when off, it doesn\'t appear on any account or surface and doesn\'t run automatically either). \"Turn on automatically when the surface opens\" is the initial state at the moment that surface opens (changes made inside the surface don\'t carry over to next time).';

  @override
  String get settingsActionBarPostTileHeader => 'Post tiles';

  @override
  String get settingsActionBarPostTileEmptyDetail =>
      'Plugins that declare post.action appear here (add them from the Store)';

  @override
  String get settingsActionBarViewerHeader => 'Full screen';

  @override
  String get settingsActionBarViewerEmptyDetail =>
      'Plugins that declare viewer.overlay (such as QR code detection) appear here';

  @override
  String get settingsActionBarViewerPlacement =>
      'On / off button on the full-screen action bar';

  @override
  String get settingsActionBarMediaHeader => 'Media editor';

  @override
  String get settingsActionBarMediaEmptyDetail =>
      'Plugins that declare composer.media appear here';

  @override
  String settingsActionBarFilterPlacement(String placement) {
    return 'Filter · $placement';
  }

  @override
  String get settingsActionBarComposerTextHeader => 'Composer text';

  @override
  String get settingsActionBarComposerTextEmptyDetail =>
      'Plugins that declare composer.text appear here';

  @override
  String get settingsActionBarComposerTextPlacement =>
      'On / off button on the composer action bar (long-press for settings)';

  @override
  String get settingsActionBarTransformHeader => 'Post transform (automatic)';

  @override
  String get settingsActionBarTransformEmptyDetail =>
      'Plugins that declare post.transform appear here';

  @override
  String get settingsActionBarTransformPlacement =>
      'Transforms the text before display (no button)';

  @override
  String settingsActionBarThisAccountHeader(String account) {
    return 'This account ($account)';
  }

  @override
  String get settingsActionBarNoAccount => 'None selected';

  @override
  String get settingsActionBarThisAccountEmptyCaption =>
      'Whether to show on this account';

  @override
  String get settingsActionBarThisAccountEmptyDetail =>
      'Whether to show post tile buttons on this account';

  @override
  String settingsActionBarSlotSubtitle(String plugin, String tags) {
    return '$plugin · Tags: $tags';
  }

  @override
  String get settingsActionBarThresholdTitle => 'Bundling threshold';

  @override
  String get settingsActionBarThresholdSubtitle =>
      'How readily similar buttons are grouped';

  @override
  String get settingsActionBarThresholdDetail =>
      'If tag similarity is at or above this, the button joins an existing button\'s bundle';

  @override
  String get settingsActionBarEditButton => 'Edit action bar';

  @override
  String get settingsBackendTitle => 'RASQ server';

  @override
  String get settingsBackendErrorUnparseable =>
      'Couldn\'t read the address. Enter it like \"http://192.168.3.14:8080\" or \"https://central.example\".';

  @override
  String get settingsBackendSaved => 'Saved';

  @override
  String get settingsBackendErrorEnterUrl =>
      'Enter an address (e.g. http://192.168.3.14:8080)';

  @override
  String get settingsBackendCentralNotCentralHint =>
      'In the Central field, enter the RASQ Central address, not ORGATE';

  @override
  String settingsBackendCentralConnectFailed(
    String url,
    String error,
    String hint,
  ) {
    return 'Couldn\'t connect ($url) — $error$hint';
  }

  @override
  String settingsBackendCentralOk(String algorithm, String keyHead) {
    return 'Connection OK — signing key $algorithm $keyHead…';
  }

  @override
  String settingsBackendAccountLine(String handle, String displayName) {
    return 'RASQ account: @$handle ($displayName)';
  }

  @override
  String get settingsBackendAccountNotCreatedLine =>
      'RASQ account: not created (create one from \"Open RASQ account\" below)';

  @override
  String settingsBackendAccountLoadFailedLine(String error) {
    return 'Couldn\'t load the RASQ account — $error';
  }

  @override
  String get settingsBackendOrgateNotConfiguredLine =>
      'ORGATE: not set (can\'t log in to a RASQ account)';

  @override
  String settingsBackendOrgateOk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count token public keys',
      one: '1 token public key',
    );
    return 'ORGATE: connection OK — $_temp0';
  }

  @override
  String settingsBackendOrgateNoKeys(String url) {
    return 'ORGATE: no token public keys in the response ($url)';
  }

  @override
  String settingsBackendOrgateConnectFailed(String url, String error) {
    return 'Couldn\'t connect to ORGATE ($url) — $error';
  }

  @override
  String get settingsBackendCaption =>
      'Server addresses for your RASQ account and the Store. SNS posts and timelines don\'t go through these.';

  @override
  String get settingsBackendCaptionDetail =>
      'RASQ Central is the server for public and shared things (profiles, Store, ASTell, posts, lists, etc.); ORGATE is the server for private information (login, password, email address) and for logging in to Mastodon and others (OAuth broker). You log in to your RASQ account through ORGATE, and that token is also used for Central. SNS posts and timelines go through neither; plugins connect directly to each instance.';

  @override
  String get settingsBackendCentralLabel =>
      'RASQ Central address (uses ORGATE if empty)';

  @override
  String get settingsBackendOrgateLabel =>
      'ORGATE (login and private info) address';

  @override
  String get settingsBackendSaveButton => 'Save';

  @override
  String get settingsBackendTestButton => 'Test connection';

  @override
  String get settingsBackendCentralDisconnected =>
      'Central: not connected (can\'t create a RASQ account)';

  @override
  String get settingsBackendCentralDisconnectedDetail =>
      'Central: not connected — the plugin Store has only bundled plugins, and you can\'t create a RASQ account (this device only).';

  @override
  String get settingsBackendOrgateDisconnected =>
      'ORGATE: not connected (can\'t log in to a RASQ account)';

  @override
  String get settingsBackendTestEndpointsSection => 'Test endpoints';

  @override
  String get settingsBackendTestEndpointsTitle =>
      'Use dummy SNS and demo Central / ORGATE';

  @override
  String get settingsBackendTestEndpointsSubtitle => 'For recording previews';

  @override
  String settingsBackendTestEndpointsDetail(
    String misskeyHost,
    String mastodonHost,
    String blueskyHost,
    String centralPort,
    String orgatePort,
  ) {
    return 'For recording previews. Points Misskey / Mastodon / Bluesky\'s $misskeyHost / $mastodonHost / $blueskyHost to dummies at this address, and also switches Central (:$centralPort) and ORGATE (:$orgatePort)';
  }

  @override
  String get settingsBackendTestAddressLabel =>
      'Dummy environment address (127.0.0.1 on the same machine, otherwise that machine\'s IP)';

  @override
  String get settingsBackendTestCaption =>
      'On the SNS login screen, enter the host name above as the server.';

  @override
  String get settingsBackendTestCaptionDetail =>
      'For each SNS, enter the host name above as the server on its login screen (the authorization page passes automatically; any Bluesky ID / password works). Log in to a RASQ account from account login. After switching, SNS accounts already logged in use the new address from the next load.';

  @override
  String get settingsBackendAccountSection => 'RASQ account';

  @override
  String settingsBackendAccountLoadError(String error) {
    return 'Couldn\'t load the account: $error';
  }

  @override
  String get settingsBackendNoServer => 'No server is set.';

  @override
  String get settingsBackendAccountNotCreated =>
      'No RASQ account has been created yet.';

  @override
  String get settingsBackendOpenAccountButton => 'Open RASQ account';

  @override
  String get settingsBackendAccountDeviceOnly =>
      'This account works only on this device. You can change the handle and display name from Edit profile.';

  @override
  String get settingsBackendBundleSection => 'Account bundle';

  @override
  String get settingsBackendBundleCaption =>
      'Bundling sends only the list of SNS accounts. Login keys are sent only if you choose sharing between devices, the web version, or showing posts on your account page.';

  @override
  String get settingsBackendBundleCaptionDetail =>
      'When bundling, only the SNS type, server, account, and display name are sent to the server. Access tokens are sent only if you choose sharing between devices (E2E; the server can\'t read them), the web version\'s vault (encrypted with the server\'s key; the server can decrypt it), or showing posts on your account page (same as the vault) (Privacy Policy section 4).';

  @override
  String get settingsBackendNoSessions => 'No accounts are logged in.';

  @override
  String get settingsColumnsTitle => 'Column width';

  @override
  String get settingsColumnsIntroCaption =>
      'Set the widths of the left and right columns on wide screens such as tablets and PCs.';

  @override
  String get settingsColumnsIntroDetail =>
      'On wide screens (tablet / desktop / web), sets the width ratio between the small column (search, or the side a page was opened from) and the large column (the opened page).';

  @override
  String get settingsColumnsSplitHeader => 'Small / large column ratio';

  @override
  String settingsColumnsSplitDefault(String hint) {
    return '$hint (default)';
  }

  @override
  String get settingsColumnsLargeWidthLabel => 'Large column width';

  @override
  String get settingsColumnsSmallWidthLabel => 'Small column width';

  @override
  String get settingsColumnsShrinkCaption =>
      'Shrinks automatically when it doesn\'t fit on screen.';

  @override
  String settingsColumnsShrinkDetail(String minWidth) {
    return 'When the screen is too narrow, columns shrink so the other column keeps at least $minWidth px and the small column never gets wider than the large column.';
  }

  @override
  String get settingsColumnsSwingInColumnTitle =>
      'Open Swing in the right column';

  @override
  String get settingsColumnsSwingInColumnSubtitle =>
      'When off, opens in full screen (on by default; Swing for plugins that request full screen always opens full screen)';

  @override
  String get settingsColumnsCurrentHeader => 'Widths on the current screen';

  @override
  String settingsColumnsPreviewWidths(String small, String large) {
    return 'Small $small px / Large $large px';
  }

  @override
  String get settingsColumnsNarrowCaption =>
      'The current screen is narrow, so there is one column.';

  @override
  String settingsColumnsNarrowDetail(String breakpoint) {
    return 'The current screen is narrow, so only one column is shown (it splits into small / large columns at $breakpoint px or wider).';
  }

  @override
  String get settingsColumnsPreviewSmall => 'Small';

  @override
  String get settingsColumnsPreviewLarge => 'Large';

  @override
  String get settingsCommonSeparator => ' · ';

  @override
  String settingsCommonBullet(String text) {
    return '• $text';
  }

  @override
  String settingsCommonRange(int min, int max) {
    return '$min–$max';
  }

  @override
  String get settingsComposerTitle => 'Post composer';

  @override
  String get settingsComposerAutoAccountTitle => 'Auto-select posting account';

  @override
  String get settingsComposerAutoAccountSubtitle =>
      'Automatically switch the destination to an account that fits the draft';

  @override
  String get settingsComposerAutoAccountDetail =>
      'Automatically switches the destination to an account whose post-target filters match the draft\'s content (manual selection always takes priority)';

  @override
  String get settingsComposerRasqLinkedTitle =>
      'Also post to your RASQ account';

  @override
  String get settingsComposerRasqLinkedSubtitle =>
      'Lets you choose your RASQ account when posting to multiple accounts';

  @override
  String get settingsComposerRasqLinkedDetail =>
      'In multi-select mode, the RASQ account row also becomes selectable (normal post / Node-linked). Delivery and filters are set on the RASQ tab of \"Customize post targets\". Posts exceeding RASQ\'s limits (1000 characters / 6 attachments / 6 poll options / 3 posts) aren\'t sent to RASQ';

  @override
  String get settingsEmomTitle => 'EmoM threshold';

  @override
  String get settingsEmomBandLow =>
      'Conservative — hides trends restricted by moderators earlier';

  @override
  String get settingsEmomBandMiddle => 'Normal';

  @override
  String get settingsEmomBandHigh =>
      'Broad — hides only trends strongly restricted by moderators';

  @override
  String get settingsEmomStatusSending => 'Sending…';

  @override
  String get settingsEmomStatusNoAccount =>
      'Log in with a RASQ account to disclose it (it still works on this device)';

  @override
  String get settingsEmomStatusFailed =>
      'Couldn\'t send. It will be resent next time you open this (or reload trends)';

  @override
  String settingsEmomStatusDisclosed(String value) {
    return 'Disclosed (value $value)';
  }

  @override
  String get settingsEmomStatusPending => 'Not received yet';

  @override
  String get settingsEmomStatusNotDisclosed => 'Not disclosed';

  @override
  String get settingsEmomIntro =>
      'EmoM is RASQ\'s model that estimates the emotional and stimulus intensity of posts and trends (coming soon). For now, this threshold is only used as a guide when RASQ moderators review reports and restrict trends.';

  @override
  String get settingsEmomThresholdLabel => 'Threshold';

  @override
  String get settingsEmomScaleLow => 'Low (hidden more easily)';

  @override
  String get settingsEmomScaleHigh => 'High (hidden less easily)';

  @override
  String settingsEmomExplanation(String defaultValue) {
    return 'A higher threshold accepts more intense topics, so trends restricted by moderators are less likely to be hidden. A lower threshold hides restricted trends earlier. The default is $defaultValue.';
  }

  @override
  String get settingsEmomDiscloseTitle =>
      'Disclose threshold (used as a guide for restrictions)';

  @override
  String get settingsEmomDiscloseSubtitle =>
      'Only the value is sent to RASQ\'s server. Moderators only use the aggregated distribution of disclosed values (how many people have each value) and never look at your individual value. Turning this off deletes the value you sent.';

  @override
  String get settingsEmomRestrictionExplanation =>
      'When moderators restrict a trend at \"N%\", it stops appearing for roughly the N% of people with the lowest disclosed thresholds. Even if you don\'t disclose, the threshold on this device is used the same way (the threshold is stored on this device). Trends set to \"Hidden for everyone\" don\'t appear regardless of threshold. Hidden trends are only removed from the trend list in search.';

  @override
  String get settingsHomeTitle => 'All settings';

  @override
  String get settingsHomeSearchHint => 'Search settings and actions';

  @override
  String get settingsHomeSearchClear => 'Clear';

  @override
  String get settingsHomeSearchError => 'Couldn\'t search settings';

  @override
  String get settingsHomeSearchEmpty => 'No results';

  @override
  String settingsHomeSearchEmptyHint(String query) {
    return 'No settings match \"$query\". Try different words, or ask RAi';
  }

  @override
  String get settingsHomeSearchOperations => 'Actions (RAi will guide you)';

  @override
  String get settingsHomeOtherHeader => 'Other settings';

  @override
  String get settingsHomeComposer => 'Post composer';

  @override
  String get settingsHomeComposerKeywords => 'post screen,draft,compose';

  @override
  String get settingsHomeThemeKeywords =>
      'theme,skin,dark mode,light,color,font';

  @override
  String get settingsHomeAccountImportant => 'Important account settings';

  @override
  String get settingsHomeAccountImportantSubtitle =>
      'Change your password or delete your account on the web';

  @override
  String get settingsHomeAccountImportantDetail =>
      'Actions that require a password, such as resetting your password or deleting your account, are done on the web';

  @override
  String settingsHomeLogout(String handle) {
    return 'Log out of @$handle';
  }

  @override
  String get settingsHomeLogoutConfirmTitle => 'Log out?';

  @override
  String get settingsHomeLogoutConfirmMessage =>
      'This account\'s plugin configuration stays on the device.';

  @override
  String get settingsHomeLogoutConfirm => 'Log out';

  @override
  String get settingsHomeCancel => 'Cancel';

  @override
  String get settingsHomeOk => 'OK';

  @override
  String get settingsHomeGenericTitle => 'Settings';

  @override
  String get settingsHomeUnknownSection => 'Unknown settings section';

  @override
  String get settingsHomeThemeModeSystem => 'System';

  @override
  String get settingsHomeThemeModeLight => 'Light';

  @override
  String get settingsHomeThemeModeDark => 'Dark';

  @override
  String get settingsHomePlaceholder => 'This setting is coming soon.';

  @override
  String get settingsHomePlaceholderDetail =>
      'This setting will be implemented once the second-level and deeper specs are finalized (M4: FOW/DSL rendering).';

  @override
  String get settingsHomePageMissing => 'This page doesn\'t exist';

  @override
  String get settingsHomePageMissingHint =>
      'This account\'s SNS doesn\'t have this setting.';

  @override
  String get settingsHomePageLoadError => 'Couldn\'t load the settings page';

  @override
  String get settingsHomeRemoteLoadError =>
      'Couldn\'t get settings from the server';

  @override
  String get settingsHomeRemotePermissionHint =>
      '\n\nThe app lacks the required permissions. Log out and log back in to grant the new permissions.';

  @override
  String get settingsHomeSaveFailed => 'Couldn\'t save';

  @override
  String get settingsHomeChildLocked =>
      'This can\'t be changed while supervised (sensitive media is always hidden).';

  @override
  String get settingsHomeTargetAccount => 'Account to configure';

  @override
  String settingsHomeMissingSnsPage(String area) {
    return 'The SNS plugin doesn\'t provide the settings page \"$area\"';
  }

  @override
  String get settingsLearningTitle =>
      'Contributing to algorithms and the community';

  @override
  String settingsLearningError(String error) {
    return 'Couldn\'t complete — $error';
  }

  @override
  String get settingsLearningGrantConfirmButton => 'Agree and join';

  @override
  String get settingsLearningGrantPointOptional =>
      'This is optional. Whether you decline or stop later, you can keep using all RASQ features, including paid ones';

  @override
  String get settingsLearningGrantPointScope =>
      'Only public posts you wrote yourself, and whether those posts belong to the same conversation, are included';

  @override
  String get settingsLearningGrantPointExcluded =>
      'Other people\'s posts, DMs, limited-visibility posts, ASTell conversations, and RAi questions and answers are not sent';

  @override
  String get settingsLearningGrantPointVerifiedOnly =>
      'Only posts from SNS accounts with verified ownership are accepted';

  @override
  String get settingsLearningGrantPointPurpose =>
      'Used to improve how the Relational timeline groups conversations';

  @override
  String get settingsLearningGrantPointDeletion =>
      'If you stop, the data you sent is deleted right away';

  @override
  String get settingsLearningGrantExtendedNotice =>
      'This is a testing setting. It also sends judgments on other people\'s posts and RAi conversations.';

  @override
  String get settingsLearningGrantExtendedNoticeDetail =>
      'CENTRAL_LEARNING_SCOPE=extended (S-049 / S-050). Not for use in production.';

  @override
  String get settingsLearningGrantScopeDetail =>
      'D-370 / S-051. From conversation events in the Related TL, only your own posts (known to be public; all Bluesky posts are public) are sent to POST /me/learning/contributions (v2, self = your own SNS account). Central checks ownership verification (sns_links.verified_at) and that every post is a=-1 and vis=public. Age and guardian consent are rechecked on every submission. @mentions and URLs in the text are masked.';

  @override
  String get settingsLearningGrantReadFullButton => 'Read the full explanation';

  @override
  String get settingsLearningGrantAgreeCheckbox =>
      'I have read the explanation and agree to provide data';

  @override
  String settingsLearningDocumentVersion(String version) {
    return 'Document version: $version';
  }

  @override
  String get settingsLearningAgeTitle => 'Declare your age';

  @override
  String get settingsLearningAgeConfirmButton => 'Declare';

  @override
  String get settingsLearningGuardianConsent => 'I have my guardian\'s consent';

  @override
  String get settingsLearningAgeDeclared => 'Age declared';

  @override
  String get settingsLearningCodeSheetTitle =>
      'Withdraw with a withdrawal code';

  @override
  String get settingsLearningCodeConfirmButton => 'Withdraw';

  @override
  String get settingsLearningCodeSheetBody =>
      'Enter the code issued when you agreed. You can withdraw even if you can no longer sign in to the RASQ account that provided the data.';

  @override
  String get settingsLearningCodeHint => 'Withdrawal code';

  @override
  String get settingsLearningWithdrawnByCode =>
      'Stopped. The data you sent will be deleted';

  @override
  String get settingsLearningReasonAgeRequired =>
      'You need to declare your age';

  @override
  String get settingsLearningReasonUnder16 => 'You must be 16 or older to join';

  @override
  String get settingsLearningReasonGuardianRequired =>
      'If you\'re 16 or 17, you need your guardian\'s consent';

  @override
  String get settingsLearningIntroNotice =>
      'You can help improve how conversations are grouped by sending the public posts you wrote. It\'s optional and you can stop anytime.';

  @override
  String get settingsLearningIntroNoticeDetail =>
      'D-243 / D-363 / D-370. Consent is recorded in Central\'s account_consents (kind = learning). With the default scope (own), only your own public posts within Related TL conversations are sent to POST /me/learning/contributions. Submissions are closed in production (CENTRAL_LEARNING_OPEN=false).';

  @override
  String get settingsLearningReadAboutTitle => 'Read the explanation';

  @override
  String get settingsLearningReadAboutSubtitle =>
      'What\'s sent, how it\'s used, and how long it\'s kept';

  @override
  String get settingsLearningStatusSection => 'Status';

  @override
  String get settingsLearningServerNotConfiguredTitle =>
      'RASQ server address is not set';

  @override
  String get settingsLearningServerNotConfiguredSubtitle =>
      'Set a server to check';

  @override
  String get settingsLearningNoAccountTitle => 'No RASQ account yet';

  @override
  String get settingsLearningNoAccountSubtitle =>
      'Data contributions are recorded per RASQ account';

  @override
  String settingsLearningLoadError(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String get settingsLearningStatusTitle => 'Contribution';

  @override
  String get settingsLearningStatusJoined => 'Joined';

  @override
  String get settingsLearningStatusNotJoined => 'Not joined';

  @override
  String get settingsLearningSinceTitle => 'Date agreed';

  @override
  String get settingsLearningOpenTitle => 'Submissions';

  @override
  String get settingsLearningOpenYes => 'Open';

  @override
  String get settingsLearningOpenNo => 'Not started yet';

  @override
  String get settingsLearningAgeUndeclared => 'Not declared';

  @override
  String get settingsLearningSentTitle => 'Data sent';

  @override
  String settingsLearningSentValue(int relational, int rai) {
    String _temp0 = intl.Intl.pluralLogic(
      relational,
      locale: localeName,
      other: '$relational',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rai,
      locale: localeName,
      other: '$rai',
    );
    return 'Conversations: $_temp0 · RAi: $_temp1';
  }

  @override
  String get settingsLearningExamplesTitle => 'Cloud judgment examples';

  @override
  String settingsLearningExamplesValue(int examples, int hardNegative) {
    String _temp0 = intl.Intl.pluralLogic(
      examples,
      locale: localeName,
      other: '$examples',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hardNegative,
      locale: localeName,
      other: '$hardNegative',
    );
    return '$_temp0 ($_temp1 suspicious but different)';
  }

  @override
  String get settingsLearningPostsLabelsTitle => 'Posts / labels';

  @override
  String get settingsLearningModelsTitle => 'Models using this data';

  @override
  String get settingsLearningModelsNone => 'None';

  @override
  String get settingsLearningModelsSeparator => ', ';

  @override
  String get settingsLearningWithdrawTitle => 'Stop contributing';

  @override
  String get settingsLearningWithdrawMessage =>
      'Sending data stops right away, and the data you sent is deleted.';

  @override
  String get settingsLearningWithdrawConfirm => 'Stop';

  @override
  String get settingsLearningCancel => 'Cancel';

  @override
  String get settingsLearningWithdrawn => 'Withdrawn';

  @override
  String get settingsLearningDeclareAgeButton => 'Declare your age';

  @override
  String get settingsLearningGranted =>
      'You\'ve joined. Keep the code below so you can stop even if you can\'t log in';

  @override
  String get settingsLearningGrantButton => 'Review and join';

  @override
  String get settingsLearningGrantClosedButton =>
      'Submissions haven\'t started yet';

  @override
  String get settingsLearningCodeSection => 'Withdrawal code';

  @override
  String get settingsLearningCodeSubtitle =>
      'Tap to copy. You can stop with this code even if you can\'t log in';

  @override
  String get settingsLearningCodeCopied => 'Withdrawal code copied';

  @override
  String get settingsLearningCodeStoredOnGrantDevice =>
      'The withdrawal code is saved on the device where you agreed.';

  @override
  String get settingsLearningOtherSection => 'Other';

  @override
  String get settingsLearningByCodeTitle => 'Stop with a withdrawal code';

  @override
  String get settingsLearningByCodeSubtitle => 'If you can\'t log in';

  @override
  String get settingsLearningDeletionCaption =>
      'If you delete your account, the data you sent is also deleted. No one can look up whether someone else is participating.';

  @override
  String get settingsLearningDeletionCaptionDetail =>
      'Deleting your RASQ account also starts stopping contributions and deleting contributed data at the same time (learning_contributions is removed when accounts is deleted). No one can look up whether someone else is contributing data (GET /me/learning returns only your own status).';

  @override
  String get settingsLearningKindsSection => 'What\'s sent';

  @override
  String get settingsLearningKindRelationalTitle => 'Your public posts';

  @override
  String get settingsLearningKindRelationalSubtitleExtended =>
      'Conversations grouped in the timeline';

  @override
  String get settingsLearningKindRelationalSubtitle =>
      'Your public posts grouped into conversations in the timeline';

  @override
  String get settingsLearningKindRelationalDetailExtended =>
      'Public posts in conversation events (bundles). Whether each author may be learned from is judged, and only posts from permitted authors and your own are sent. @mentions and URLs in the text are masked.';

  @override
  String get settingsLearningKindRelationalDetail =>
      'D-370. Your own posts in conversation events (known to be public), and that those posts belong to the same conversation (relation labels). For other people\'s posts, only counts (participants and posts).';

  @override
  String get settingsLearningUnverifiedNotice =>
      'Posts from SNS accounts without verified ownership couldn\'t be accepted. You can verify from Edit profile.';

  @override
  String get settingsLearningUnverifiedButton => 'Verify';

  @override
  String get settingsLearningKindCloudTitle => 'Group in the cloud';

  @override
  String get settingsLearningKindCloudSubtitle =>
      'RAi in the cloud decides on unclear conversation groupings';

  @override
  String get settingsLearningKindCloudDetail =>
      'D-367 / S-050. Links (post → conversation) that the on-device engine decided near the threshold are sent to POST /me/relational/judge and regrouped by the cloud LLM\'s judgment. Only pairs whose authors have given permission. Judgment examples (suspicious but different = hard_negative, split but same = hard_positive) are kept for learning and deleted when you stop.';

  @override
  String get settingsLearningKindRaiSubtitle =>
      'Questions to RAi and its answers';

  @override
  String get settingsLearningKindRaiDetail =>
      'Questions (@mentions and URLs masked), answers, mode, names of functions used, and model id. Other people\'s posts are not included.';

  @override
  String get settingsLearningPreloadTitle => 'Preload the on-device model';

  @override
  String get settingsLearningPreloadSubtitle =>
      'Speeds up preliminary judgments (only if already downloaded)';

  @override
  String get settingsLearningPreloadDetail =>
      'Loads RAi\'s on-device model (default Qwen3.5 2B) shortly after launch and uses it to pre-screen authors. If not downloaded, it won\'t download (pre-screening uses rules only).';

  @override
  String get settingsLearningDebugSection => 'Developer details';

  @override
  String get settingsLearningDebugActiveTitle => 'Collecting';

  @override
  String get settingsLearningDebugActiveYes => 'Yes';

  @override
  String get settingsLearningDebugActiveNo =>
      'No (check consent, submissions and supervision)';

  @override
  String get settingsLearningDebugScopeTitle => 'Accepted scope';

  @override
  String get settingsLearningDebugScopeExtended => 'extended (testing)';

  @override
  String get settingsLearningDebugScopeOwn =>
      'own (your own public posts only)';

  @override
  String get settingsLearningDebugPendingTitle => 'Waiting to send';

  @override
  String settingsLearningDebugPendingValue(String relational, String rai) {
    return 'Conversations $relational · RAi $rai';
  }

  @override
  String get settingsLearningDebugSentTitle => 'Sent this session';

  @override
  String settingsLearningDebugSentValue(
    String relational,
    String rai,
    String skipped,
  ) {
    return 'Conversations $relational · RAi $rai · Skipped $skipped';
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
    return 'Judgments $decisions (suspicious but different $hardNegative · split but same $hardPositive · agreed $agree) · Pending $pending · Skipped $skipped';
  }

  @override
  String get settingsLearningDebugCloudOff => 'Off';

  @override
  String get settingsLearningDebugModelTitle => 'On-device model';

  @override
  String get settingsLearningDebugFlushing => 'Sending…';

  @override
  String get settingsLearningDebugFlushButton => 'Send now';

  @override
  String get settingsLearningDebugVerdictsSection => 'Author judgments';

  @override
  String get settingsLearningDebugLogSection => 'Log';

  @override
  String get settingsLegalTitle => 'Help and legal';

  @override
  String get settingsLegalVersionTitle => 'Version';

  @override
  String get settingsLegalHelpTitle => 'Help';

  @override
  String get settingsLegalTourTitle => 'Take the RASQ tour again';

  @override
  String get settingsLegalCookiesTitle => 'About cookies';

  @override
  String get settingsLegalPluginTermsHeader => 'SNS plugin terms';

  @override
  String get settingsLegalPluginNoTerms => 'No terms provided';

  @override
  String get settingsLegalLicensesHeader => 'Licenses';

  @override
  String get settingsLegalLicensesTitle => 'Open source licenses';

  @override
  String get settingsLegalLicensesSubtitle => 'Flutter and bundled libraries';

  @override
  String get settingsMuteBlockTitle => 'Mute/block';

  @override
  String get settingsMuteBlockBlockTab => 'Block';

  @override
  String get settingsMuteBlockMuteTab => 'Mute';

  @override
  String get settingsMuteBlockBlockedUsers => 'Blocked users';

  @override
  String get settingsMuteBlockBlockedWords => 'Blocked words';

  @override
  String get settingsMuteBlockBlockedLists => 'Blocked lists';

  @override
  String get settingsMuteBlockComingSoonHint => 'Coming soon';

  @override
  String get settingsMuteBlockComingSoonDetail =>
      'Blocking words/lists is planned for the second half of M2';

  @override
  String get settingsMuteBlockRetryButton => 'Reload';

  @override
  String get settingsMuteBlockNoBlockedUsers => 'No blocked users';

  @override
  String get settingsMuteBlockNoMutedUsers => 'No muted users';

  @override
  String get settingsMuteBlockBlockButton => 'Block';

  @override
  String get settingsMuteBlockMuteButton => 'Mute';

  @override
  String get settingsMuteBlockBlockingButton => 'Blocked';

  @override
  String get settingsMuteBlockMutingButton => 'Muted';

  @override
  String get settingsNotifyTokenTitle => 'Notification-only access token';

  @override
  String settingsNotifyTokenError(String error) {
    return 'Couldn\'t complete — $error';
  }

  @override
  String get settingsNotifyTokenCaption =>
      'A key only for receiving notifications. It can\'t post or change your account.';

  @override
  String get settingsNotifyTokenCaptionDetail =>
      'The notification token is only for receiving notifications from the RASQ server (it can read only your own notification inbox; it can\'t post or change your account). Child tokens for macros / ASTell are also issued here.';

  @override
  String get settingsNotifyTokenStatusSection => 'Status';

  @override
  String get settingsNotifyTokenPushTitle => 'Push delivery';

  @override
  String get settingsNotifyTokenPushPending => 'Coming soon';

  @override
  String get settingsNotifyTokenPushPendingDetail =>
      'Dummy (APNs / FCM not connected)';

  @override
  String get settingsNotifyTokenServerNotConfiguredTitle =>
      'RASQ server address is not set';

  @override
  String get settingsNotifyTokenServerNotConfiguredSubtitle =>
      'Enter the address to issue a token';

  @override
  String get settingsNotifyTokenNoAccountTitle => 'No RASQ account yet';

  @override
  String get settingsNotifyTokenNoAccountSubtitle =>
      'Create one to issue a notification token';

  @override
  String settingsNotifyTokenLoadError(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String get settingsNotifyTokenLocalTokenTitle => 'Token on this device';

  @override
  String get settingsNotifyTokenLocalTokenActive => 'Active';

  @override
  String get settingsNotifyTokenLocalTokenNone => 'Not issued';

  @override
  String get settingsNotifyTokenDevicesTitle => 'Devices registered for push';

  @override
  String settingsNotifyTokenDevicesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
    );
    return '$_temp0';
  }

  @override
  String get settingsNotifyTokenTestNotFound =>
      'A test notification was queued, but it wasn\'t found in the inbox';

  @override
  String settingsNotifyTokenTestFound(
    String title,
    String status,
    int devices,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      devices,
      locale: localeName,
      other: '$devices devices',
      one: '1 device',
    );
    return 'Found in inbox: \"$title\" ($status, $_temp0)';
  }

  @override
  String get settingsNotifyTokenTestButton => 'Send test notification';

  @override
  String get settingsNotifyTokenLocalRevoked => 'Revoked this device\'s token';

  @override
  String get settingsNotifyTokenRevokeButton => 'Revoke';

  @override
  String get settingsNotifyTokenEnabled =>
      'Issued and registered this device for push';

  @override
  String get settingsNotifyTokenEnableButton =>
      'Issue a notification token and register this device';

  @override
  String get settingsNotifyTokenTokensSection => 'Issued tokens';

  @override
  String get settingsNotifyTokenKindRoot => 'Notification token';

  @override
  String get settingsNotifyTokenKindChild => 'Child token';

  @override
  String settingsNotifyTokenLabelSuffix(String label) {
    return ' ($label)';
  }

  @override
  String get settingsNotifyTokenThisDevice => 'This device';

  @override
  String settingsNotifyTokenIssuedAt(String time) {
    return 'Issued $time';
  }

  @override
  String get settingsNotifyTokenUnused => 'Never used';

  @override
  String settingsNotifyTokenLastUsedAt(String time) {
    return 'Last used $time';
  }

  @override
  String get settingsNotifyTokenIssueChildTooltip =>
      'Issue a child token (shared by macros / ASTell)';

  @override
  String get settingsNotifyTokenChildIssued =>
      'Issued a child token and copied it to the clipboard (the raw value is visible only now)';

  @override
  String get settingsNotifyTokenRevoked => 'Revoked';

  @override
  String get settingsNotifyTokenStorageCaption =>
      'The key is stored securely on this device.';

  @override
  String get settingsNotifyTokenStorageCaptionDetail =>
      'The raw token is received only when issued and stored in a secure area on the device. Only a hash remains on the server. Revoking a parent token also revokes its child tokens.';

  @override
  String get settingsPagesAboutCookiesTitle => 'About cookies';

  @override
  String get settingsPagesAboutCookiesSection1Title => 'Cookies';

  @override
  String get settingsPagesAboutCookiesText1 =>
      'The iOS, Android, and desktop apps do not use cookies to communicate with the RASQ server. Communication with the RASQ server uses a device token (Authorization header), and each SNS access token is stored in a secure area on your device.';

  @override
  String get settingsPagesAboutCookiesText2 =>
      'Ads in the iOS and Android apps (Google AdMob) use your device\'s advertising ID instead of cookies. On the Google consent screen shown the first time, you can choose whether to allow personalized ads.';

  @override
  String get settingsPagesAboutCookiesText3 =>
      'On the web version and on RASQ\'s public profile and post web pages, Google uses cookies for ads (Google AdSense). Ad cookies are handled according to Google\'s policies.';

  @override
  String get settingsPagesAboutCookiesText4 =>
      'When you open an SNS\'s web version or sign-up page in the in-app browser, that SNS\'s cookie policy applies.';

  @override
  String get settingsPagesAboutDeveloperTitle => 'Developer mode';

  @override
  String get settingsPagesAboutDeveloperEnabledSubtitle =>
      'Shows detailed explanations on screens, down to how things work and the shape of data sent';

  @override
  String get settingsPagesAboutDeveloperEnabledDetail =>
      'While on, settings and consent screens show the original detailed explanations (storage KV, shape of the JSON sent, etc.) instead of the shortened ones. Only the display changes; behavior does not.';

  @override
  String get settingsPagesAboutDeveloperNotice1 =>
      'Only the display changes. Settings and data sent do not change.';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseTitle =>
      'Try screen reading (iOS)';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseSubtitle =>
      'Shows \"Browse in your usual browser\" under \"Find SNS services\" on iPhone / iPad';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseDetail =>
      'Hidden by default on iOS because on some devices the screen reading Broadcast Upload Extension (ScreenGlimpseBroadcast) does not appear in the screen recording picker (unresolved). Turn on to show the entry point. Always shown on Android.';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dTitle =>
      'Try 3D RAi (Android)';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dSubtitle =>
      'Shows the RAi mascot in 3D on Android too';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dDetail =>
      'Defaults to 2D because RAi was reported not to open on Android and the 3D foundation (flutter_angle) initialization is suspect. Turn on to try 3D. If it does not appear within 20 seconds or fails, it automatically falls back to 2D and records the reason in \"Diagnostics\" in the RAi sidebar. iPhone / iPad / Mac always use 3D.';

  @override
  String get settingsPagesAboutHelpTitle => 'Help';

  @override
  String get settingsPagesAboutHelpSection1Title => 'How to use';

  @override
  String get settingsPagesAboutHelpText1 =>
      'If you get stuck, ask RAi in the side menu.';

  @override
  String get settingsPagesAboutHelpText1Detail =>
      'If you get stuck, ask RAi. From RAi in the side menu you can use Instructions (guides you to the button) and Assistant (answers with an on-device model and acts for you with functions).';

  @override
  String get settingsPagesAboutHelpRaiTitle => 'Open RAi';

  @override
  String get settingsPagesAboutHelpTourAgain1Title =>
      'Take the RASQ tour again';

  @override
  String get settingsPagesAboutHelpTourAgain1Subtitle =>
      'Feature introduction (Timeline, Trends, ASTell, RAi, and more)';

  @override
  String get settingsPagesAboutHelpSection2Title => 'Troubleshooting';

  @override
  String get settingsPagesAboutHelpText2 =>
      'If logging in or posting does not work, check the permissions and log in again.';

  @override
  String get settingsPagesAboutHelpText2Detail =>
      'If you cannot log in or your posts are not delivered, first check permissions in \"SNS plugins → Security\", then log out once and log in again.';

  @override
  String get settingsPagesAboutHelpSettingsDslSnsSecurityTitle =>
      'Security (permissions and tokens)';

  @override
  String get settingsPagesAboutHelpSettingsServerTitle =>
      'RASQ server connection';

  @override
  String get settingsPagesAboutSubscriptionTitle => 'Subscription status';

  @override
  String get settingsPagesAboutSubscriptionSection1Title => 'RASQ subscription';

  @override
  String get settingsPagesAboutSubscriptionValueRow1Title => 'Plan';

  @override
  String get settingsPagesAboutSubscriptionValueRow1Value => 'Free';

  @override
  String get settingsPagesAboutSubscriptionValueRow2Title => 'Plugin proxy';

  @override
  String get settingsPagesAboutSubscriptionValueRow2Value => 'Not subscribed';

  @override
  String get settingsPagesAboutSubscriptionText1 =>
      'Paid plans are coming soon.';

  @override
  String get settingsPagesAboutSubscriptionText1Detail =>
      'Plan: Free (no subscription plans yet). Paid plans will be offered in the future, linked to your RASQ account.';

  @override
  String get settingsPagesAppearanceDisplayTitle => 'Interface size';

  @override
  String get settingsPagesAppearanceDisplaySection1Title => 'Display size';

  @override
  String get settingsPagesAppearanceDisplayTextScaleTitle => 'Text and UI size';

  @override
  String get settingsPagesAppearanceDisplayTextScaleSubtitle =>
      'Changes the text size across the app (applies immediately)';

  @override
  String get settingsPagesAppearanceFabTitle => '＋ button action';

  @override
  String get settingsPagesAppearanceFabNotice1 =>
      'Choose what starts when you press ＋. To rearrange the surrounding buttons (up to 3 inside and 4 outside), long-press ＋ (hover with a mouse) and use the gear.';

  @override
  String get settingsPagesAppearanceFabNotice1Detail =>
      'Area appearance.fab (<scope>Tap / <scope>Slots = in placement order, max 7).';

  @override
  String get settingsPagesAppearanceFabSection1Title =>
      'When pressing ＋ on Home';

  @override
  String get settingsPagesAppearanceFabHomeTapPostTitle => 'Post';

  @override
  String get settingsPagesAppearanceFabHomeTapRasqTitle => 'Post to RASQ';

  @override
  String get settingsPagesAppearanceFabHomeTapSwingTitle => 'Create a Swing';

  @override
  String get settingsPagesAppearanceFabHomeTapAstellTitle => 'Create an ASTell';

  @override
  String get settingsPagesAppearanceFabSection2Title =>
      'When pressing ＋ on Trends';

  @override
  String get settingsPagesAppearanceFabSection3Title =>
      'When pressing ＋ on ASTell';

  @override
  String get settingsPagesAppearanceMfmTitle => 'Custom motion and animation';

  @override
  String get settingsPagesAppearanceMfmSection1Title => 'MFM animation';

  @override
  String get settingsPagesAppearanceMfmAnimationsTitle =>
      'Play animated decorations';

  @override
  String get settingsPagesAppearanceMfmAnimationsSubtitle =>
      'Plays animated decorations such as spinning and rainbow';

  @override
  String get settingsPagesAppearanceMfmAnimationsDetail =>
      'Animates MFM such as spin / jump / rainbow. When off, they are shown as still images (always still while \"Reduce motion\" is on)';

  @override
  String get settingsPagesAppearanceMfmSpeedTitle => 'Animation speed';

  @override
  String get settingsPagesAppearanceMfmSpeedSubtitle =>
      '100% is normal. Higher values move faster';

  @override
  String get settingsPagesAppearanceMfmSettingsDslAppearanceMotionTitle =>
      'Reduce motion';

  @override
  String get settingsPagesAppearanceMfmSettingsDslAppearanceMotionSubtitle =>
      'Reduce everything at once, including screen transitions';

  @override
  String get settingsPagesAppearanceMotionTitle => 'Reduce motion';

  @override
  String get settingsPagesAppearanceMotionSection1Title => 'Animation';

  @override
  String get settingsPagesAppearanceMotionReduceMotionTitle => 'Reduce motion';

  @override
  String get settingsPagesAppearanceMotionReduceMotionSubtitle =>
      'Stops animated decorations and reduces on-screen motion';

  @override
  String get settingsPagesAppearanceMotionReduceMotionDetail =>
      'Turns MFM animations such as spin / rainbow into still images and reduces screen transition motion';

  @override
  String get settingsPagesAppearanceNotificationsTitle => 'Notification style';

  @override
  String get settingsPagesAppearanceNotificationsSection1Title =>
      'Notifications page';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabAllTitle =>
      'Open on \"All\"';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabFollowingTitle =>
      'Open on \"Following\"';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabFollowingSubtitle =>
      'See notifications from people you follow first';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersTitle =>
      'Show scheduled ASTell start notifications at the top';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersSubtitle =>
      'Shows the start notifications you registered at the top of the notifications page';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersDetail =>
      'Shows the list of registered start notifications (local notifications on the device) at the top of the notifications page';

  @override
  String get settingsPagesAppearanceNotificationsText1 =>
      'Choose which notification types to receive in \"Notifications → Profile\" (saved on this device).';

  @override
  String get settingsPagesAppearanceTimelineTitle => 'Timeline display';

  @override
  String get settingsPagesAppearanceTimelineSection1Title => 'Refresh';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesTitle =>
      'Show \"Load posts\" at the top and bottom of the timeline';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesSubtitle =>
      'Hidden by default on phones (pull to refresh)';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesDetail =>
      'When visible, loads new posts / more posts. By default, hidden in the phone app (pull down to refresh) and shown on the web version and computers';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillTitle =>
      'Show new post notice';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillSubtitle =>
      'When new posts arrive after refreshing, shows \"New posts\" just below the header';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillDetail =>
      'Shows the posters\' avatars (up to 3) and \"New posts\". Tap to jump to the top. Disappears after a while or when you scroll to the top. Not shown while the header is hidden';

  @override
  String get settingsPagesAppearanceVideoTitle => 'Picture-in-picture';

  @override
  String get settingsPagesAppearanceVideoSection1Title => 'Video';

  @override
  String get settingsPagesAppearanceVideoAutoplayTitle =>
      'Autoplay when opened';

  @override
  String get settingsPagesAppearanceVideoAutoplaySubtitle =>
      'Plays immediately in full screen and in the mini window';

  @override
  String get settingsPagesAppearanceVideoAutoplayDetail =>
      'Plays as soon as ready in the full-screen viewer and the mini window (PiP)';

  @override
  String get settingsPagesAppearanceVideoPipKeepPositionTitle =>
      'Keep playback position when moving to the mini window';

  @override
  String get settingsPagesAppearanceVideoPipKeepPositionSubtitle =>
      'Continues from where you were when you tap \"Play in mini window\" in full screen';

  @override
  String get settingsPagesAppearanceVideoSection2Title =>
      'Default playback speed';

  @override
  String get settingsPagesAppearanceVideoDefaultSpeed10Title => '1.0× (normal)';

  @override
  String get settingsPagesAppearanceVideoText1 =>
      'You can drag the mini window anywhere you like.';

  @override
  String get settingsPagesAppearanceVideoText1Detail =>
      'The mini window is a FOW, so you can drag it to a column or up and down.';

  @override
  String get settingsPagesAstellBackgroundTitle =>
      'Behavior when the screen is off';

  @override
  String get settingsPagesAstellBackgroundSection1Title =>
      'When the screen turns off during a call';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffKeepTitle =>
      'Stay in the call';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffKeepSubtitle =>
      'Audio continues; only receiving screen shares stops';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffMuteTitle =>
      'Mute the mic and stay';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffLeaveTitle =>
      'Leave the room';

  @override
  String get settingsPagesAstellBackgroundNotice1 =>
      'This setting is coming soon. ASTell currently works only while the screen is on.';

  @override
  String get settingsPagesAstellBackgroundNotice1Detail =>
      'This setting is saved, but it takes effect only after keeping calls running in the background (background audio) is implemented. ASTell currently works only while the screen is on.';

  @override
  String get settingsPagesAstellSubscriptionTitle => 'Subscribe to ASTell 4U';

  @override
  String get settingsPagesAstellSubscriptionSection1Title => 'Status';

  @override
  String get settingsPagesAstellSubscriptionValueRow1Title => 'Subscription';

  @override
  String get settingsPagesAstellSubscriptionValueRow1Value => 'Not subscribed';

  @override
  String get settingsPagesAstellSubscriptionValueRow2Title => 'Availability';

  @override
  String get settingsPagesAstellSubscriptionValueRow2Value => 'Coming soon';

  @override
  String get settingsPagesAstellSubscriptionText1 =>
      'ASTell 4U is a paid plan coming soon. The recommendations section is free to use.';

  @override
  String get settingsPagesAstellSubscriptionText1Detail =>
      'ASTell 4U is a paid plan for ASTell recommendation (For You) delivery and server-side transcription / summaries. It is not available yet. The recommendations section runs on the RASQ server\'s free recommendations.';

  @override
  String get settingsPagesAstellTilesTitle => 'Tell tiles';

  @override
  String get settingsPagesAstellTilesSection1Title => 'Home header';

  @override
  String get settingsPagesAstellTilesHeaderStripTitle =>
      'Show ASTells from hosts you follow in the header';

  @override
  String get settingsPagesAstellTilesHeaderStripSubtitle =>
      'Lines up live rooms at the top of Home';

  @override
  String get settingsPagesAstellTilesHeaderStripDetail =>
      'Lines up live rooms in the rounded frame of the Home header';

  @override
  String get settingsPagesAstellTilesHeaderMaxTitle => 'Number to show';

  @override
  String get settingsPagesAstellTilesHeaderMaxUnit => '';

  @override
  String get settingsPagesAstellTrendTitle => 'Publish to the Trends timeline';

  @override
  String get settingsPagesAstellTrendSection1Title => 'ASTell Home sections';

  @override
  String get settingsPagesAstellTrendShowRecommendedTitle =>
      'Show \"Recommended\"';

  @override
  String get settingsPagesAstellTrendShowTrendingTitle => 'Show \"Trending\"';

  @override
  String get settingsPagesAstellTrendShowTrendingSubtitle =>
      'Lines up trending rooms on ASTell Home';

  @override
  String get settingsPagesAstellTrendText1 =>
      'To show rooms in Trends on the search home, set it up in \"Customize Trends\".';

  @override
  String get settingsPagesAstellTrendText1Detail =>
      'Inserting rooms into the Trends timeline (Search home) is set up on the Trends node (algorithm) side.';

  @override
  String get settingsPagesAstellTrendTlconfigTrendTitle => 'Customize trends';

  @override
  String get settingsPagesMediaSaveTitle => 'Image and video save location';

  @override
  String get settingsPagesMediaSaveSection1Title =>
      'Save location for \"Save image\" and \"Save video\"';

  @override
  String get settingsPagesMediaSaveDestinationAskTitle => 'Ask every time';

  @override
  String get settingsPagesMediaSaveDestinationAskSubtitle =>
      'Asks every time whether to use Photos or Files';

  @override
  String get settingsPagesMediaSaveDestinationAskDetail =>
      'Asks each time whether to save to Photos or Files (does not ask on devices with only one available destination)';

  @override
  String get settingsPagesMediaSaveDestinationPhotosTitle =>
      'Photos (Camera Roll)';

  @override
  String get settingsPagesMediaSaveDestinationPhotosSubtitle =>
      'Goes into the \"RASQ\" album';

  @override
  String get settingsPagesMediaSaveDestinationPhotosDetail =>
      'Saved to the \"RASQ\" album in Photos on iPhone / iPad / Mac, or in the gallery on Android';

  @override
  String get settingsPagesMediaSaveDestinationFilesTitle => 'Files';

  @override
  String get settingsPagesMediaSaveDestinationFilesSubtitle =>
      'Saves to the Files app or a location you choose';

  @override
  String get settingsPagesMediaSaveDestinationFilesDetail =>
      'On iPhone / iPad: Files app › On My iPad (On My iPhone) › RASQ › 保存. On computers, you choose where to save. On Android, saved to the gallery';

  @override
  String get settingsPagesPluginsAccountPickTitle =>
      'Account for sharing / renoting';

  @override
  String get settingsPagesPluginsAccountPickSection1Title =>
      'When the same post is visible to multiple accounts';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentTitle =>
      'Prefer the selected account';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentSubtitle =>
      'When off, picks the account that interacts most with the other person';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentDetail =>
      'When viewing with a specific SNS account selected, shares / renotes with that account. When off, predicts and picks the account that interacts most with that person based on recent interactions (reactions / renotes / replies). When viewing everything together with your RASQ account, it always picks by prediction';

  @override
  String get settingsPagesPluginsComposerTitle => 'Post plugins';

  @override
  String get settingsPagesPluginsComposerSection1Title => 'Composer';

  @override
  String get settingsPagesPluginsComposerEnabledTitle => 'Use post plugins';

  @override
  String get settingsPagesPluginsComposerEnabledSubtitle =>
      'Uses plugins that transform the text and images of your posts';

  @override
  String get settingsPagesPluginsComposerEnabledDetail =>
      'Enables composer text transformation (composer.text) and media editing (composer.media) plugins';

  @override
  String get settingsPagesPluginsComposerText1 =>
      'When off, the plugin sections in the composer and media editor are empty.';

  @override
  String get settingsPagesPluginsComposerSettingsComposerTitle =>
      'Post composer settings';

  @override
  String get settingsPagesPluginsComposerStoreTitle => 'Plugin Store';

  @override
  String get settingsPagesPluginsEmojiTitle => 'Emoji search';

  @override
  String get settingsPagesPluginsEmojiSection1Title => 'Emoji picker search';

  @override
  String get settingsPagesPluginsEmojiSemanticTitle =>
      'Also find emoji with similar meanings';

  @override
  String get settingsPagesPluginsEmojiSemanticSubtitle =>
      'Shows emoji with similar meanings even if the names do not match. What you type is not sent anywhere';

  @override
  String get settingsPagesPluginsEmojiSemanticDetail =>
      'Lists emoji with similar meanings at the end, even if what you typed is not in their names or aliases. Works only when the on-device search model (RAi → \"Models\" → Search) is installed. Computation happens only on the device, and what you type is not sent anywhere. On a server opened for the first time, \"Preparing\" is shown while the index is built in the background';

  @override
  String get settingsPagesPluginsProxyTitle => 'RASQ plugin proxy subscription';

  @override
  String get settingsPagesPluginsProxySection1Title => 'Status';

  @override
  String get settingsPagesPluginsProxyValueRow1Title => 'Subscription';

  @override
  String get settingsPagesPluginsProxyValueRow1Value => 'Not subscribed';

  @override
  String get settingsPagesPluginsProxyValueRow2Title => 'Availability';

  @override
  String get settingsPagesPluginsProxyValueRow2Value => 'Coming soon';

  @override
  String get settingsPagesPluginsProxyText1 =>
      'The plugin proxy is coming soon. For now, plugins communicate directly from your device.';

  @override
  String get settingsPagesPluginsProxyText1Detail =>
      'The plugin proxy is a paid service that routes wasm plugins\' external communication through the RASQ server. Since it is not available yet, plugins communicate directly from your device to SNSs / self-hosted servers. Availability: together with the RASQ server billing platform.';

  @override
  String get settingsPagesPluginsProxySettingsServerTitle =>
      'RASQ server connection';

  @override
  String get settingsPagesPluginsProxySettingsServerSubtitle =>
      'Once available, the server selected here will be used';

  @override
  String get settingsPagesPluginsReactionTitle => 'Reaction prediction';

  @override
  String get settingsPagesPluginsReactionSection1Title =>
      'Short press on the reaction button';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptyTitle =>
      'Predict even on posts with no reactions';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptySubtitle =>
      'Predicts an emoji you often use and adds it with a short press';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptyDetail =>
      'When off, no prediction is made on posts without reactions yet, and pressing opens the emoji picker. When on, an emoji you often use is shown as the prediction, and a short press adds it';

  @override
  String get settingsPagesPluginsTelemetryTitle => 'Report suspicious traffic';

  @override
  String get settingsPagesPluginsTelemetrySection1Title =>
      'Report plugins\' suspicious traffic to the Store';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesTitle =>
      'Report suspicious traffic';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesSubtitle =>
      'Sends only the shape of the traffic for review. Content such as post text or tokens is not sent. Off by default';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesDetail =>
      'Sends only the \"shape\" of a plugin\'s traffic (destination host, method, path pattern, header names, key structure of the JSON sent) to the RASQ Store, once, the first time it is seen on this device. Values such as tokens, post text, user names, and IDs in URLs are not sent. Reviewers use this to re-examine plugins whose traffic shape changed after approval. Off by default.';

  @override
  String get settingsPagesPluginsTelemetryText1 =>
      'The same shape is never sent twice. Turning this off is recorded as withdrawal of consent.';

  @override
  String settingsPagesPluginsTelemetryText1Detail(String example) {
    return 'Sent: e.g. $example. Not sent: the values themselves. The same shape is never sent twice. Consent is also kept in the Store\'s consent record, and turning this off is recorded as withdrawal.';
  }

  @override
  String get settingsPagesPluginsTimelineTitle => 'Place custom timelines';

  @override
  String get settingsPagesPluginsTimelineSection1Title => 'Timeline plugins';

  @override
  String get settingsPagesPluginsTimelineEnabledTitle => 'Use custom timelines';

  @override
  String get settingsPagesPluginsTimelineEnabledSubtitle =>
      'Shows plugin timelines as tabs on Home';

  @override
  String get settingsPagesPluginsTimelineEnabledDetail =>
      'Shows timelines declared by TL plugins (tl) as Home tabs and as algorithms in \"Customize Timeline\"';

  @override
  String get settingsPagesPluginsTimelineText1 =>
      'Set up the order and sources from the gear in the Home tab row (Customize Timeline).';

  @override
  String get settingsPagesPluginsTimelineStoreTitle => 'Plugin Store';

  @override
  String get settingsPagesPluginsTrendTitle => 'Custom trend publishing';

  @override
  String get settingsPagesPluginsTrendSection1Title => 'Trend plugins';

  @override
  String get settingsPagesPluginsTrendEnabledTitle =>
      'Show trend plugin suggestions';

  @override
  String get settingsPagesPluginsTrendEnabledSubtitle =>
      'Shows plugin suggestions in the Trends section of the Search home';

  @override
  String get settingsPagesPluginsTrendEnabledDetail =>
      'Shows suggestion chips from installed trend plugins (trend.suggest) in the Trends section of the Search home';

  @override
  String get settingsPagesPluginsTrendText1 =>
      'When off, plugins are not called (they do not communicate even while installed).';

  @override
  String get settingsPagesPluginsTrendStoreTitle => 'Plugin Store';

  @override
  String get settingsPagesPluginsTrendStoreSubtitle =>
      'Find / manage trend plugins';

  @override
  String get settingsPagesRaiTitle => 'RAi (assistant)';

  @override
  String get settingsPagesRaiSection1Title => 'Automation';

  @override
  String get settingsPagesRaiTraceGraphAutoTitle =>
      'Show the step graph automatically';

  @override
  String get settingsPagesRaiTraceGraphAutoSubtitle =>
      'Shows automations with 3 or more steps as a graph';

  @override
  String get settingsPagesRaiTraceGraphAutoDetail =>
      'When an automation delegated to RAi has 3 or more steps, its steps are automatically shown as a node graph. When off, a \"Show in graph view\" button appears instead';

  @override
  String get settingsPagesRaiText1 =>
      'Set the AI model and web search from the model button in the RAi bar.';

  @override
  String get settingsPagesRaiText1Detail =>
      'Set the inference server and web search keys from the model chip in the RAi bar.';

  @override
  String get settingsPagesRelationalPluginsTitle => 'Advanced plugin settings';

  @override
  String get settingsPagesRelationalPluginsSection1Title => 'Status';

  @override
  String get settingsPagesRelationalPluginsValueRow1Title => 'Plugin slot';

  @override
  String get settingsPagesRelationalPluginsValueRow1Value => 'Coming soon';

  @override
  String get settingsPagesRelationalPluginsText1 =>
      'Plugins for this screen are coming soon.';

  @override
  String get settingsPagesRelationalPluginsText1Detail =>
      'Contract v0.7 does not yet have a plugin slot for the relational timeline (replacing how posts are grouped). ML similarity uses the RASQ server\'s ML gateway. Plugin slot: undefined.';

  @override
  String get settingsPagesRelationalPluginsSettingsServerTitle =>
      'RASQ server connection';

  @override
  String get settingsPagesRelationalRelayTitle => 'Relay tiles';

  @override
  String get settingsPagesRelationalRelaySection1Title => 'Status';

  @override
  String get settingsPagesRelationalRelayValueRow1Title => 'Availability';

  @override
  String get settingsPagesRelationalRelayValueRow1Value => 'Coming soon';

  @override
  String get settingsPagesRelationalRelayText1 =>
      'Relay tiles are coming soon. For now, you can change how conversations are grouped in \"Post clusters\".';

  @override
  String get settingsPagesRelationalRelayText1Detail =>
      'Relay tiles show, in a single tile, the flow of a topic being handed across conversation events (a relay). They will be added once the grouping method is settled. For now, you can change how conversation events are grouped by adjusting \"Post clusters\". Availability: after the algorithm is finalized.';

  @override
  String get settingsPagesRelationalTrendTitle =>
      'Publish to the Trends timeline';

  @override
  String get settingsPagesRelationalTrendSection1Title => 'Status';

  @override
  String get settingsPagesRelationalTrendValueRow1Title => 'Availability';

  @override
  String get settingsPagesRelationalTrendValueRow1Value => 'Coming soon';

  @override
  String get settingsPagesRelationalTrendText1 =>
      'You can feed the Related timeline into Trends with \"Customize Trends\".';

  @override
  String get settingsPagesRelationalTrendText1Detail =>
      'Feeding conversation events from the Related tab into the Trends timeline can be set up by placing a \"Related timeline\" node in the Trends node graph (algorithm). Availability: after the algorithm is finalized.';

  @override
  String get settingsPagesRelationalTrendTlconfigTrendTitle =>
      'Customize trends';

  @override
  String get settingsPagesResourcesTitle => 'Resources and ads';

  @override
  String get settingsPagesResourcesSection1Title => 'Ads';

  @override
  String get settingsPagesResourcesShowAdsTitle => 'Show ads';

  @override
  String get settingsPagesResourcesShowAdsSubtitle =>
      'Ads between timeline posts and on the search home';

  @override
  String get settingsPagesResourcesShowAdsDetail =>
      'Between timeline posts (every 10 posts; never placed next to posts with a content warning or sensitive posts) and in the Search home ad slot (AdMob, currently test ads). Personalized ads are not shown';

  @override
  String get settingsPagesResourcesSection2Title => 'Resources';

  @override
  String get settingsPagesResourcesValueRow1Title => 'Plugin traffic';

  @override
  String get settingsPagesResourcesValueRow1Value => 'Directly from device';

  @override
  String get settingsPagesResourcesValueRow2Title => 'Inference';

  @override
  String get settingsPagesResourcesValueRow2Value =>
      'On device + selected server';

  @override
  String get settingsPagesResourcesText1 =>
      'Whether each plugin has ads, and its price, are shown on its page in the Plugin Store.';

  @override
  String get settingsPagesResourcesText1Detail =>
      'Whether each plugin has ads, and its price, are shown on its page in the Plugin Store. Plugin traffic: directly from device (no proxy). Inference: on-device model (RAi) + optional inference server.';

  @override
  String get settingsPagesResourcesStoreTitle => 'Plugin Store';

  @override
  String get settingsPagesTrendCdnTitle => 'Cache network settings';

  @override
  String get settingsPagesTrendCdnSection1Title => 'Status';

  @override
  String get settingsPagesTrendCdnValueRow1Title => 'Cache network';

  @override
  String get settingsPagesTrendCdnValueRow1Value => 'Coming soon';

  @override
  String get settingsPagesTrendCdnText1 =>
      'Coming soon. For now, data is fetched directly from each SNS.';

  @override
  String get settingsPagesTrendCdnText1Detail =>
      'Reading trend results from a CDN (cache network) will arrive together with the RASQ server\'s delivery platform. For now, data is fetched directly from each SNS. Cache network: not available.';

  @override
  String get settingsSectionsPluginsTitle => 'Plugin setup';

  @override
  String get settingsSectionsPluginsProxyTitle =>
      'RASQ plugin proxy subscription';

  @override
  String get settingsSectionsPluginsProxySubtitle => 'Coming soon';

  @override
  String get settingsSectionsPluginsProxyDetail => 'Not subscribed (phase 2)';

  @override
  String get settingsSectionsPluginsActionBarTitle =>
      'Place plugin automations on posts';

  @override
  String get settingsSectionsPluginsActionBarSubtitle =>
      'Plugin buttons shown below posts';

  @override
  String get settingsSectionsPluginsActionBarDetail =>
      'Plugin buttons on the post action bar (master switch / auto-on / placement)';

  @override
  String get settingsSectionsPluginsTrendTitle => 'Custom trend publishing';

  @override
  String get settingsSectionsPluginsComposerTitle => 'Post plugins';

  @override
  String get settingsSectionsPluginsTimelineTitle => 'Place custom timelines';

  @override
  String get settingsSectionsPluginsStoreTitle => 'Advanced plugin settings';

  @override
  String get settingsSectionsPluginsStoreSubtitle =>
      'Plugin Store (manage installed plugins)';

  @override
  String get settingsSectionsPluginsTelemetryTitle =>
      'Report suspicious traffic';

  @override
  String get settingsSectionsPluginsTelemetrySubtitle => 'Off by default';

  @override
  String get settingsSectionsPluginsTelemetryDetail =>
      'Traffic shape reports: sends the shape of a plugin\'s network traffic (without values) to the Store only the first time it is seen. Off by default';

  @override
  String get settingsSectionsSnsTitle => 'SNS plugins';

  @override
  String get settingsSectionsSnsAccountTitle => 'Account';

  @override
  String get settingsSectionsSnsTimelineTitle => 'Timeline';

  @override
  String get settingsSectionsSnsSecurityTitle => 'Security';

  @override
  String get settingsSectionsSnsSafetyTitle => 'Privacy and safe mode';

  @override
  String get settingsSectionsSnsChildSafeTitle => 'Child Safe';

  @override
  String get settingsSectionsSnsChildSafeSubtitle =>
      'Guardian supervision / Child mode';

  @override
  String get settingsSectionsSnsChildSafeDetail =>
      'Monitor as a guardian / Child mode (connect with the guardian\'s code)';

  @override
  String get settingsSectionsSnsListsTitle => 'Lists';

  @override
  String get settingsSectionsSnsMuteBlockTitle => 'Mute/block';

  @override
  String get settingsSectionsSnsPluginButtonsTitle => 'Plugin buttons';

  @override
  String get settingsSectionsSnsPluginButtonsSubtitle =>
      'How plugin buttons are shown';

  @override
  String get settingsSectionsSnsPluginButtonsDetail =>
      'Master switch and \"Turn on automatically when opened\" per surface, enabled / disabled for this account, and the grouping threshold';

  @override
  String get settingsSectionsSnsEmojiSearchTitle => 'Emoji search';

  @override
  String get settingsSectionsSnsEmojiSearchSubtitle =>
      'Also find emoji with similar meanings';

  @override
  String get settingsSectionsSnsEmojiSearchDetail =>
      'Also find emoji with similar meanings (on-device model)';

  @override
  String get settingsSectionsSnsReactionPredictTitle => 'Reaction prediction';

  @override
  String get settingsSectionsSnsReactionPredictSubtitle =>
      'Whether to predict even on posts nobody has reacted to';

  @override
  String get settingsSectionsSnsQuickEmojiTitle => 'Quick emoji';

  @override
  String get settingsSectionsSnsQuickEmojiSubtitle =>
      'Emoji you pick by long-pressing the Reaction button and sliding';

  @override
  String get settingsSectionsSnsAccountPickTitle =>
      'Account for sharing / renoting';

  @override
  String get settingsSectionsSnsAccountPickSubtitle =>
      'When the same post is visible to multiple accounts';

  @override
  String get settingsSectionsSnsAccountPickDetail =>
      'Which account to use for a post that is visible to multiple accounts';

  @override
  String get settingsSectionsSnsMfmTitle => 'Custom motion and animation';

  @override
  String get settingsSectionsSnsResourcesTitle => 'Resources and ads';

  @override
  String get settingsSectionsSnsLegalTitle => 'Help and legal';

  @override
  String get settingsSectionsSnsNote =>
      'Account / Timeline / Security / Privacy are pages provided by the plugin of the SNS you use (pages the plugin doesn\'t provide are not shown).';

  @override
  String get settingsSectionsSnsNoteDetail =>
      'Account / Timeline / Security / Privacy are settings pages provided by the SNS plugin of the account being configured (sns.settingsPages; rows for undeclared pages are hidden, D-482).';

  @override
  String get settingsSectionsAppearanceTitle => 'App appearance';

  @override
  String get settingsSectionsAppearanceDisplayTitle => 'Interface size';

  @override
  String get settingsSectionsAppearanceThemeTitle => 'Fonts and color scheme';

  @override
  String get settingsSectionsAppearanceThemeSubtitle =>
      'Themes (colors, icons, background images)';

  @override
  String get settingsSectionsAppearanceColumnsTitle => 'Column width';

  @override
  String get settingsSectionsAppearanceColumnsSubtitle =>
      'Width of the left and right columns on wide screens';

  @override
  String get settingsSectionsAppearanceColumnsDetail =>
      'Ratio of small / large Columns on wide screens (1:1 / 2:3 / 3:5 / fixed width)';

  @override
  String get settingsSectionsAppearanceMotionTitle => 'Reduce motion';

  @override
  String get settingsSectionsAppearanceTimelineTitle => 'Timeline display';

  @override
  String get settingsSectionsAppearanceTimelineSubtitle =>
      '\"Load posts\" on the Timeline';

  @override
  String get settingsSectionsAppearanceTimelineDetail =>
      '\"Load posts\" at the top and bottom of the TL';

  @override
  String get settingsSectionsAppearancePipTitle => 'Picture-in-picture';

  @override
  String get settingsSectionsAppearanceFabTitle => '＋ button action';

  @override
  String get settingsSectionsAppearanceFabSubtitle =>
      'What it starts when tapped';

  @override
  String get settingsSectionsAppearanceMediaSaveTitle =>
      'Image and video save location';

  @override
  String get settingsSectionsAppearanceMediaSaveSubtitle =>
      'Photos (camera roll) / Files / Ask every time';

  @override
  String get settingsSectionsAppearanceNotificationsTitle =>
      'Notification style';

  @override
  String get settingsSectionsAstellTitle => 'ASTell';

  @override
  String get settingsSectionsAstellSubscriptionTitle =>
      'Subscribe to ASTell 4U';

  @override
  String get settingsSectionsAstellSubscriptionSubtitle => 'Coming soon';

  @override
  String get settingsSectionsAstellSubscriptionDetail =>
      'Not subscribed (phase 2)';

  @override
  String get settingsSectionsAstellTilesTitle => 'Tell tiles';

  @override
  String get settingsSectionsAstellTrendTitle =>
      'Publish to the Trends timeline';

  @override
  String get settingsSectionsAstellRoomButtonsTitle => 'Room buttons';

  @override
  String get settingsSectionsAstellRoomButtonsSubtitle =>
      'Buttons to the left of the input field';

  @override
  String get settingsSectionsAstellRoomButtonsDetail =>
      'Row of round buttons at the bottom of a room, left of the input field (reorder / show / hide / add plugin buttons)';

  @override
  String get settingsSectionsAstellStoreTitle => 'Advanced plugin settings';

  @override
  String get settingsSectionsAstellStoreSubtitle => 'Plugins used in ASTell';

  @override
  String get settingsSectionsAstellStoreDetail =>
      'ASTell action plugins (Store)';

  @override
  String get settingsSectionsAstellBackgroundTitle =>
      'Behavior when the screen is off';

  @override
  String get settingsSectionsRelationalTitle => 'Relational timeline';

  @override
  String get settingsSectionsRelationalClusterTitle => 'Post clusters';

  @override
  String get settingsSectionsRelationalClusterSubtitle =>
      'How conversations are grouped';

  @override
  String get settingsSectionsRelationalClusterDetail =>
      'How conversation events are grouped (grouping ease / weight / time until they sink)';

  @override
  String get settingsSectionsRelationalRelayTitle => 'Relay tiles';

  @override
  String get settingsSectionsRelationalTrendTitle =>
      'Publish to the Trends timeline';

  @override
  String get settingsSectionsRelationalPluginsTitle =>
      'Advanced plugin settings';

  @override
  String get settingsSectionsRelationalSamplingTitle => 'Trend sampling level';

  @override
  String get settingsSectionsRelationalSamplingSubtitle =>
      'Time range for candidates';

  @override
  String get settingsSectionsRelationalSamplingDetail =>
      'Time range for candidates (advanced grouping settings)';

  @override
  String get settingsSectionsRelationalNote =>
      'Relay tiles and trend publishing are coming soon.';

  @override
  String get settingsSectionsRelationalNoteDetail =>
      'Relay tiles and trend publishing come after the algorithm is finalized (D-011).';

  @override
  String get settingsSectionsTrendTitle => 'Trends';

  @override
  String get settingsSectionsTrendGenresTitle => 'Genres';

  @override
  String get settingsSectionsTrendTendencyTitle =>
      'Trend orientation/intensity';

  @override
  String get settingsSectionsTrendEmomTitle => 'EmoM threshold';

  @override
  String get settingsSectionsTrendEmomSubtitle =>
      'Hiding trends restricted by moderators / publishing the threshold';

  @override
  String get settingsSectionsTrendEmomDetail =>
      'EmoM threshold (0–100, default 50) and \"Publish threshold\" (off by default). Trends whose moderation restriction score exceeds this value are not listed (D-404)';

  @override
  String get settingsSectionsTrendPluginsTitle => 'Advanced plugin settings';

  @override
  String get settingsSectionsTrendCdnTitle => 'Cache network settings';

  @override
  String get settingsSectionsTrendCdnSubtitle => 'Coming soon';

  @override
  String get settingsSectionsTrendCdnDetail => 'Not available yet (phase 2)';

  @override
  String get settingsSectionsRaiTitle => 'RAi (assistant)';

  @override
  String get settingsSectionsRaiGraphTitle =>
      'Show process graph automatically';

  @override
  String get settingsSectionsNotificationsTitle => 'Notifications';

  @override
  String get settingsSectionsNotificationsProfileTitle => 'Profile';

  @override
  String get settingsSectionsNotificationsAccessTokenTitle => 'Access token';

  @override
  String get settingsSectionsNotificationsAccessTokenSubtitle =>
      'Settings for receiving notifications';

  @override
  String get settingsSectionsNotificationsAccessTokenDetail =>
      'Issue / revoke notification-only tokens, device push registration';

  @override
  String get settingsSectionsNotificationsSecurityTitle => 'Security';

  @override
  String get settingsSectionsNotificationsSecuritySubtitle =>
      'SNS permissions and access tokens';

  @override
  String get settingsSectionsAboutTitle => 'About RASQ';

  @override
  String get settingsSectionsAboutServerTitle => 'RASQ server';

  @override
  String get settingsSectionsAboutServerSubtitle => 'Server to connect to';

  @override
  String get settingsSectionsAboutServerDetail =>
      'Connection target for the Plugin Store / RASQ account / login';

  @override
  String get settingsSectionsAboutHelpTitle => 'Help';

  @override
  String get settingsSectionsAboutTourTitle => 'Take the RASQ tour again';

  @override
  String get settingsSectionsAboutTourSubtitle =>
      'Feature introduction (Timeline, Trends, ASTell, RAi, and more)';

  @override
  String get settingsSectionsAboutSubscriptionTitle => 'Subscription status';

  @override
  String get settingsSectionsAboutCookiesTitle => 'About cookies';

  @override
  String get settingsSectionsAboutPrivacyTitle => 'Privacy Policy';

  @override
  String get settingsSectionsAboutTermsTitle => 'Terms of Service';

  @override
  String get settingsSectionsAboutLearningTitle =>
      'Contributing to algorithms and the community';

  @override
  String get settingsSectionsAboutLearningSubtitle =>
      'Optional. Default is \"Don\'t provide\"';

  @override
  String get settingsSectionsAboutAstellTermsTitle => 'ASTell terms of use';

  @override
  String get settingsSectionsAboutRaiTermsTitle => 'RAi terms of use';

  @override
  String get settingsSectionsAboutStoreTermsTitle =>
      'Plugin Store terms of use';

  @override
  String get settingsSectionsAboutDevTermsTitle =>
      'Plugin developer listing and review terms';

  @override
  String get settingsSectionsAboutDevTermsSubtitle => 'Including review fees';

  @override
  String get settingsSectionsAboutBillingTitle => 'Pricing and points terms';

  @override
  String get settingsSectionsAboutCommerceTitle =>
      'Notation based on the Specified Commercial Transactions Act';

  @override
  String get settingsSectionsAboutResourcesTitle => 'Resources and ads';

  @override
  String get settingsSectionsAboutLegalTitle => 'Help and legal';

  @override
  String get settingsSectionsAboutDeveloperTitle => 'Developer mode';

  @override
  String get settingsSectionsAboutDeveloperSubtitle =>
      'Show detailed explanations on screens';

  @override
  String get settingsSecurityAgoJustNow => 'Just now';

  @override
  String settingsSecurityAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min ago',
      one: '1 min ago',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityCodeSentTo(String to) {
    return 'Sent a verification code to $to';
  }

  @override
  String get settingsSecurityTitle => 'Account security';

  @override
  String get settingsSecurityNotSignedIn => 'Not logged in to a RASQ account.';

  @override
  String get settingsSecurityToLoginTitle =>
      'Log in to an existing RASQ account';

  @override
  String get settingsSecurityToLoginSubtitle =>
      'Handle (or email) and password';

  @override
  String get settingsSecurityEmailHeader => 'Email address';

  @override
  String get settingsSecurityEmailCaption =>
      'Used to reset your password if you forget it, and for the second step of login. Not visible to others.';

  @override
  String get settingsSecurityEmailDetail =>
      'Once registered, it\'s used to reset your password if you forget it, for the second step when logging in from another device (an email verification code after your password), and for confirmations and notices about important actions. If your email isn\'t verified, you can\'t reset a forgotten password. Not visible to others.';

  @override
  String get settingsSecurityEmailCurrentTitle => 'Current email';

  @override
  String get settingsSecurityEmailUnregistered => 'Not registered';

  @override
  String get settingsSecurityEmailNewHint => 'New email address';

  @override
  String get settingsSecurityEmailHint => 'Email address';

  @override
  String get settingsSecuritySendCodeButton => 'Send code';

  @override
  String get settingsSecurityEmailChangeNeedsPasswordOrCode =>
      'To change it, you need your current password or a verification code sent to your current email.';

  @override
  String get settingsSecurityEmailChangeNeedsCode =>
      'To change it, you need a verification code sent to your current email.';

  @override
  String get settingsSecurityCurrentPasswordHint => 'Current password';

  @override
  String get settingsSecurityEmailSendCodeToCurrentButton =>
      'Send code to current email';

  @override
  String get settingsSecurityEmailNeedsPassword =>
      'For accounts with a password, adding an email address requires your current password.';

  @override
  String settingsSecurityEmailPendingCaption(String email) {
    return 'Enter the code sent to $email (it expires in 15 minutes).';
  }

  @override
  String get settingsSecurityEmailVerified => 'Email address verified';

  @override
  String get settingsSecurityVerifyButton => 'Verify';

  @override
  String get settingsSecurityEmailRemoveTitle => 'Remove email address';

  @override
  String get settingsSecurityEmailRemoveSubtitle =>
      'Requires a verification code';

  @override
  String get settingsSecurityPasswordHeader => 'Password';

  @override
  String get settingsSecurityPasswordChangeCaption =>
      'Changing it signs out your other devices. You need your current password or an email verification code.';

  @override
  String get settingsSecurityPasswordNoneCaption =>
      'Without a password, you can\'t log in from other devices (it only works on this device). With one, you can log in to the same account from another device using your handle (or email) and password.';

  @override
  String get settingsSecurityPasswordNewHint => 'New password (8+ characters)';

  @override
  String get settingsSecurityPasswordHint => 'Password (8+ characters)';

  @override
  String get settingsSecurityPasswordChanged => 'Password changed';

  @override
  String get settingsSecurityPasswordSet => 'Password set';

  @override
  String get settingsSecurityPasswordChangeButton => 'Change password';

  @override
  String get settingsSecurityPasswordSetButton => 'Set password';

  @override
  String get settingsSecurityPasswordByCodeButton => 'Change with email code';

  @override
  String get settingsSecurityPasswordResetWarning =>
      'If you \"reset\" your password, your synced settings can no longer be read.';

  @override
  String get settingsSecurityPasswordResetWarningDetail =>
      'Your password is also used to encrypt your synced settings. If you use \"Reset password\" (on the login screen), data encrypted with the old password can no longer be decrypted.';

  @override
  String get settingsSecuritySecondFactorHeader => 'Second step of login';

  @override
  String get settingsSecuritySecondFactorNeedsEmailCaption =>
      'Once your email address is verified, logging in from another device also asks for an email verification code after your password (on by default).';

  @override
  String get settingsSecuritySecondFactorActiveCaption =>
      'When logging in from another device, a verification code sent to your email (valid for 10 minutes) is also required after your password.';

  @override
  String get settingsSecuritySecondFactorOffCaption =>
      'Turned off. Other devices can log in with just your password.';

  @override
  String get settingsSecuritySecondFactorTitle =>
      'Also require an email verification code';

  @override
  String get settingsSecuritySecondFactorNeedsEmailSubtitle =>
      'Requires a verified email address';

  @override
  String get settingsSecuritySecondFactorEnabled =>
      'Second login step turned on';

  @override
  String get settingsSecuritySecondFactorDisableNeedsPasswordOrCode =>
      'To turn it off, you need your current password or a verification code sent to your email.';

  @override
  String get settingsSecuritySecondFactorDisableNeedsCode =>
      'To turn it off, you need a verification code sent to your email.';

  @override
  String get settingsSecuritySendCodeToEmailButton => 'Send code to email';

  @override
  String get settingsSecurityCancelButton => 'Cancel';

  @override
  String get settingsSecuritySecondFactorDisabled =>
      'Second login step turned off';

  @override
  String get settingsSecuritySecondFactorDisableButton =>
      'Turn off second step';

  @override
  String get settingsSecuritySessionsHeader => 'Logged-in devices';

  @override
  String settingsSecuritySessionsRevokedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other devices',
      one: '1 other device',
    );
    return 'Signed out $_temp0';
  }

  @override
  String get settingsSecuritySessionsRevokeOthersButton => 'Log out all others';

  @override
  String get settingsSecuritySessionUnnamed => 'Unnamed device';

  @override
  String get settingsSecurityThisDeviceSuffix => ' (this device)';

  @override
  String settingsSecuritySessionLastUsed(String ago) {
    return 'Last used: $ago';
  }

  @override
  String settingsSecuritySessionExpires(String date) {
    return 'Expires $date';
  }

  @override
  String get settingsSecuritySessionRevoked => 'Signed out';

  @override
  String get settingsSecuritySessionLogoutButton => 'Log out';

  @override
  String get settingsSecurityConfirmDeleteHeader => 'Confirm account deletion';

  @override
  String get settingsSecurityConfirmEmailRemoveHeader =>
      'Confirm removing email address';

  @override
  String settingsSecurityConfirmCodeCaption(String to) {
    return 'Enter the code sent to $to.';
  }

  @override
  String get settingsSecurityDeleteButton => 'Delete';

  @override
  String get settingsSecurityRemoveButton => 'Remove';

  @override
  String get settingsSecurityDeleteHeader => 'Delete account';

  @override
  String get settingsSecurityDeleteTitle => 'Delete RASQ account';

  @override
  String get settingsSecurityDeleteSubtitleWithEmail =>
      'Requires an email verification code. This can\'t be undone';

  @override
  String get settingsSecurityDeleteSubtitle => 'This can\'t be undone';

  @override
  String get settingsSecurityRolesHeader => 'Roles';

  @override
  String get settingsSecurityRolesTitle => 'This account\'s roles';

  @override
  String get settingsSecurityRoleDeveloper => 'Developer';

  @override
  String get settingsSecurityRoleReviewer => 'Reviewer';

  @override
  String get settingsSecurityEmailReplaceNeedsPasswordOrCodeError =>
      'Enter your current password, or verify with a code sent to your current email';

  @override
  String get settingsSecurityEmailReplaceNeedsCodeError =>
      'Verify with a code sent to your current email';

  @override
  String get settingsSecurityEnterCurrentPasswordError =>
      'Enter your current password';

  @override
  String get settingsSecurityCodeSent => 'Verification code sent';

  @override
  String get settingsSecurityDeleteConfirmMessage =>
      'This deletes your profile on the server, account bundle, synced settings, reviews and bookmarks, ASTell rooms and shares, notification tokens, and consent records. This can\'t be undone.';

  @override
  String get settingsSecuritySendConfirmCodeButton => 'Send verification code';

  @override
  String get settingsSecurityDeleted => 'RASQ account deleted';

  @override
  String get settingsSecurityEmailRemoved => 'Email address removed';

  @override
  String get settingsSecurityCodeHint => 'Verification code (e.g. 3mJr7-AoUXx)';

  @override
  String get settingsSecurityCodeHelper =>
      'You can also verify by pasting the link from the email';

  @override
  String get settingsSecurityLoginFailedHelp =>
      'Your handle (email) or password is incorrect.\nRASQ accounts without a password can\'t be logged in to from other devices. On the device where you created that account (and are still logged in), set a password from \"Settings → Account security\", then try logging in again.';

  @override
  String get settingsSecurityServerNotConfiguredError =>
      'RASQ server address is not set';

  @override
  String get settingsSecurityLoginFailed => 'Couldn\'t log in';

  @override
  String settingsSecurityLoggedInAs(String handle) {
    return 'Logged in as @$handle';
  }

  @override
  String get settingsSecurityLoginEnterCredentialsError =>
      'Enter your handle (or email) and password';

  @override
  String get settingsSecurityVerifiedEmailFallback => 'your verified email';

  @override
  String get settingsSecurityLoginTitle => 'Log in to a RASQ account';

  @override
  String get settingsSecurityLoginCaption =>
      'Sign in with your handle (@ optional) or verified email address, and your password.';

  @override
  String get settingsSecurityLoginDetail =>
      'Sign in with your handle (@ optional) or verified email address, and your password. For accounts with a verified email, you\'ll then also enter a verification code sent to that email (second-step verification).';

  @override
  String get settingsSecurityLoginIdentifierHint => 'Handle or email address';

  @override
  String get settingsSecurityLoginPasswordHint => 'Password';

  @override
  String get settingsSecurityLoginButton => 'Log in';

  @override
  String get settingsSecurityLoginForgotButton => 'Forgot password';

  @override
  String get settingsSecurityLoginNoPasswordHint =>
      'Accounts without a password can\'t be logged in to from other devices (they only work on the device where they were created). Set a password in \"Settings → Account security\" on that device.';

  @override
  String get settingsSecurityLoginCodeHeader => 'Verification code';

  @override
  String settingsSecurityLoginChallengeCaption(String email, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: 'valid for $minutes minutes',
      one: 'valid for 1 minute',
    );
    return 'We sent a verification code to $email ($_temp0, single use). Enter the code you received.';
  }

  @override
  String get settingsSecurityVerifiedEmailAddressFallback =>
      'your verified email address';

  @override
  String get settingsSecurityLoginConfirmButton => 'Verify and log in';

  @override
  String get settingsSecurityLoginResendButton => 'Resend code';

  @override
  String get settingsSecurityLoginBackButton => 'Back to handle / password';

  @override
  String get settingsSecurityLoginNoMailHint =>
      'If the email doesn\'t arrive, check your spam folder too. If you receive an email about a login you don\'t recognize, change your password.';

  @override
  String get settingsSecurityLoginChildHeader => 'Child account';

  @override
  String get settingsSecurityLoginChildTitle =>
      'Log in with a code from your guardian';

  @override
  String get settingsSecurityLoginChildSubtitle =>
      'Sign in to a child account your guardian created';

  @override
  String get settingsSecurityResetEnterEmailError =>
      'Enter a verified email address';

  @override
  String get settingsSecurityResetCodeSent =>
      'If an account has verified that email address, a verification code has been sent (valid for 10 minutes)';

  @override
  String settingsSecurityResetDoneKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count other devices',
      one: '1 other device',
    );
    return 'Password reset. Signed out $_temp0';
  }

  @override
  String settingsSecurityResetDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices logged out',
      one: '1 device logged out',
    );
    return 'Password reset ($_temp0). Log in with your new password';
  }

  @override
  String get settingsSecurityResetTitle => 'Reset password';

  @override
  String get settingsSecurityResetCaption =>
      'We\'ll send a verification code (valid for 10 minutes, single use) to your verified email address so you can choose a new password. All other devices will be logged out.';

  @override
  String get settingsSecurityResetNoEmailWarning =>
      'Accounts without a verified email address can\'t reset their password.';

  @override
  String get settingsSecurityResetNoEmailDetail =>
      'On the device where you created that account (and are still logged in), set a new password from \"Settings → Account security\". If you don\'t have that device either, there\'s no way to get back into the account.';

  @override
  String get settingsSecurityResetEmailHint => 'Verified email address';

  @override
  String get settingsSecurityResendButton => 'Resend';

  @override
  String settingsSecurityResetNewPasswordHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'at least $count characters',
      one: 'at least 1 character',
    );
    return 'New password ($_temp0)';
  }

  @override
  String get settingsSecurityResetConfirmPasswordHint =>
      'New password (confirm)';

  @override
  String get settingsSecurityResetMismatchError => 'Doesn\'t match';

  @override
  String get settingsSecurityResetKeepTitle => 'Stay logged in on this device';

  @override
  String get settingsSecurityResetKeepSubtitle =>
      'Only applies when resetting the account currently logged in on this device';

  @override
  String get settingsSecurityResetSyncWarning =>
      'After resetting, your synced settings can no longer be read.';

  @override
  String get settingsSecurityResetSyncWarningDetail =>
      'Your password is also used to encrypt your synced settings. Data encrypted with the old password can no longer be decrypted.';

  @override
  String get settingsSecurityResetSubmitButton => 'Reset password';

  @override
  String get settingsSnsShareConflictError =>
      'Another device changed this first. Please try again';

  @override
  String get settingsSnsShareOffConfirmTitle => 'Stop sharing SNS logins?';

  @override
  String get settingsSnsShareOffConfirmMessage =>
      'This deletes the shared data and the keys on all devices. Each device\'s SNS logins remain as they are.';

  @override
  String get settingsSnsShareOffConfirmDetail =>
      'This deletes the shared contents (encrypted) on RASQ Central and the keys on all devices. Each device\'s SNS logins remain as they are.';

  @override
  String get settingsSnsShareOffConfirmButton => 'Stop';

  @override
  String get settingsSnsShareCancelButton => 'Cancel';

  @override
  String get settingsSnsShareStopped => 'Stopped sharing';

  @override
  String get settingsSnsShareSubtitleLoading => 'Loading…';

  @override
  String get settingsSnsShareSubtitleUnsupported =>
      'This device\'s logins don\'t support sharing. Please log in again';

  @override
  String get settingsSnsShareSubtitleOffAsk =>
      'Off (asks when you log in on another device)';

  @override
  String get settingsSnsShareSubtitleOff => 'Off';

  @override
  String get settingsSnsShareSubtitleOnHolding => 'On · This device is sharing';

  @override
  String get settingsSnsShareSubtitleOnWaiting =>
      'On · Waiting for approval on a sharing device';

  @override
  String get settingsSnsShareSubtitleOnNotYet =>
      'On · This device isn\'t sharing yet';

  @override
  String get settingsSnsShareHeader => 'Share SNS logins across devices';

  @override
  String get settingsSnsShareCaption =>
      'Log in to your SNS automatically on new devices too. Contents are encrypted and RASQ\'s servers can\'t read them.';

  @override
  String get settingsSnsShareDetail =>
      'Shares SNS access tokens, end-to-end encrypted, among the devices logged in to this RASQ account. When you log in on a new device, after approval on a sharing device, that device also logs in to all the SNS accounts at once. RASQ\'s servers can\'t read the contents.';

  @override
  String get settingsSnsShareSwitchTitle =>
      'Share SNS logins with other devices';

  @override
  String get settingsSnsShareRequestTitle => 'Request sharing to this device';

  @override
  String get settingsSnsShareRequestSubtitle =>
      'An approval prompt appears on sharing devices';

  @override
  String get settingsSnsShareRequested =>
      'Requested approval from sharing devices';

  @override
  String get settingsSnsShareDevicesLabel => 'Devices';

  @override
  String get settingsSnsShareThisDeviceSuffix => ' (this device)';

  @override
  String get settingsSnsShareDeviceShared => 'Sharing';

  @override
  String get settingsSnsShareDeviceWaiting => 'Waiting for approval';

  @override
  String get settingsSnsShareDeviceNotShared => 'Not sharing';

  @override
  String settingsSnsShareApproved(String name) {
    return 'Shared with $name';
  }

  @override
  String get settingsSnsShareApproveButton => 'Share';

  @override
  String get settingsSnsShareDeclineButton => 'Decline';

  @override
  String settingsSnsShareRemoved(String name) {
    return 'Removed $name from sharing';
  }

  @override
  String get settingsSnsShareRemoveButton => 'Remove';

  @override
  String get settingsSnsShareRemovedCaption =>
      'Removed devices keep the logins they already had. If you don\'t recognize one, log out on the SNS side as well.';

  @override
  String get settingsSnsShareRemovedDetail =>
      'Logging that device out from \"Logged-in devices\" also deletes its key. A removed device still has the access tokens it received before (if you don\'t recognize it, log out on the SNS side as well).';

  @override
  String get shellColumnSplitSmallFixedLabel => 'Fix small column width';

  @override
  String get shellColumnSplitLargeFixedLabel => 'Fix large column width';

  @override
  String get shellColumnSplitEvenHint => 'Equal width';

  @override
  String get shellColumnSplitTwoThreeHint => 'Small 2 : Large 3';

  @override
  String get shellColumnSplitThreeFiveHint => 'Small 3 : Large 5';

  @override
  String get shellColumnSplitSmallFixedHint =>
      'Small column at a set width, large column takes the rest';

  @override
  String get shellColumnSplitLargeFixedHint =>
      'Large column at a set width, small column takes the rest';

  @override
  String get shellColumnWidthErrorEmpty => 'Enter a width';

  @override
  String get shellColumnWidthErrorNotInteger => 'Enter a whole number';

  @override
  String shellColumnWidthErrorRange(String min, String max) {
    return 'Enter a value between $min and $max px';
  }

  @override
  String get shellColumnThirdEmptySearch => 'Search';

  @override
  String get shellColumnThirdEmptyNotifications => 'Notifications';

  @override
  String get shellColumnThirdEmptyNone => 'Don\'t show';

  @override
  String get shellColumnThirdSettingsTooltip => 'Third column settings';

  @override
  String get shellColumnThirdCloseTooltip => 'Close';

  @override
  String get shellColumnThirdEmptyTitle => 'Third column';

  @override
  String get shellColumnThirdEmptyHint => 'You can move open screens here';

  @override
  String get shellColumnThirdEmptyHintDetail => 'You can move FOWs here (M5c)';

  @override
  String get shellNavHome => 'Home';

  @override
  String get shellNavSearch => 'Search';

  @override
  String get shellNavNotifications => 'Notifications';

  @override
  String get shellHeaderTimelineSwitchTooltip => 'Switch timeline';

  @override
  String get shellHeaderExpandTooltip => 'Restore header';

  @override
  String get shellHeaderScrollToTopTooltip => 'Scroll to top';

  @override
  String get shellHeaderSearchHint => 'Search';

  @override
  String get shellHeaderBackTooltip => 'Back';

  @override
  String get shellHeaderCloseButton => 'Close';

  @override
  String get shellHeaderMenuTooltip => 'Menu';

  @override
  String get shellHeaderOpenSidebarSemantics => 'Open sidebar';

  @override
  String get shellSidebarSemantics => 'Sidebar';

  @override
  String shellSidebarSwitchToAccountTooltip(String name) {
    return 'Switch to $name';
  }

  @override
  String get shellSidebarRasqAccountTooltip => 'RASQ account';

  @override
  String get shellSidebarHideAccountsTooltip => 'Hide account list';

  @override
  String get shellSidebarShowAccountsTooltip => 'Show account list';

  @override
  String get shellSidebarAccountSettingsButton => 'Account settings';

  @override
  String get shellSidebarBookmarks => 'Bookmarks';

  @override
  String get shellSidebarLists => 'Lists';

  @override
  String get shellSidebarPlugins => 'Plugins';

  @override
  String get shellSidebarCustomPlugins => 'Custom plugins';

  @override
  String get shellSidebarAllSettings => 'All settings';

  @override
  String get shellSidebarHelp => 'Help';

  @override
  String get shellSidebarDevCatalog => 'Component catalog (dev)';

  @override
  String get shellSidebarDevWasmPlugin => 'WASM plugin test (dev)';

  @override
  String get shellSidebarWebConsole => 'Web console';

  @override
  String get shellSidebarAccountActionsTooltip => 'Account actions';

  @override
  String get shellSidebarShowAccountMenu => 'View this account';

  @override
  String get shellSidebarLogoutMenu => 'Log out';

  @override
  String get shellAccountHeaderPickTooltip => 'Choose account';

  @override
  String shellAccountHeaderReadingAsTooltip(String account) {
    return 'Reading as $account';
  }

  @override
  String get shellAccountHeaderSwitchSemantics => 'Switch account';

  @override
  String get shellAccountHeaderAvatarSemantics => 'Account';

  @override
  String get shellAccountPickerSemantics => 'Account selection';

  @override
  String get shellAccountPickerCloseTooltip => 'Close';

  @override
  String get shellAccountFowTitle => 'RASQ account';

  @override
  String get shellAccountFowCloseButton => 'Close';

  @override
  String get shellAccountAppealSheetTitle => 'Appeal the action';

  @override
  String get shellAccountAppealCaption =>
      'A moderator will read your appeal, and if it is accepted, the action will be lifted.';

  @override
  String get shellAccountAppealCaptionDetail =>
      'A moderator (rasq-judge) will read your appeal, and if it is accepted, the action will be lifted. It does not go through automated review.';

  @override
  String get shellAccountAppealReasonHint => 'Reason for appeal (required)';

  @override
  String shellAccountAppealFailedError(String error) {
    return 'Couldn\'t submit the appeal: $error';
  }

  @override
  String get shellAccountAppealSubmitButton => 'Submit appeal';

  @override
  String get shellAccountAppealSentSnack =>
      'Appeal submitted. A moderator will review it';

  @override
  String get shellAccountLocalDisplayName => 'This device';

  @override
  String get shellAccountMenuAddSns => 'Add SNS account';

  @override
  String get shellAccountMenuAllSettings => 'Settings';

  @override
  String get shellAccountMenuAccountPage => 'Account page';

  @override
  String get shellAccountMenuEditProfile => 'Edit profile';

  @override
  String get shellAccountMenuAccountSettings => 'Account settings';

  @override
  String get shellAccountMenuNotificationSettings => 'Notification settings';

  @override
  String get shellAccountMenuSecurity =>
      'Security (email / password / devices)';

  @override
  String get shellAccountMenuLogout => 'Log out';

  @override
  String get shellAccountMenuDelete => 'Delete RASQ account';

  @override
  String get shellAccountLogoutTitle => 'Log out of RASQ account';

  @override
  String get shellAccountLogoutMessage =>
      'This removes the RASQ account from this device.';

  @override
  String get shellAccountLogoutConfirmButton => 'Log out';

  @override
  String get shellAccountLoggedOutWithSnsSnack =>
      'Logged out of the RASQ account and its SNS accounts';

  @override
  String get shellAccountLoggedOutKeptSnsSnack =>
      'Logged out of the RASQ account. SNS accounts were moved to \"This device only\"';

  @override
  String get shellAccountDeleteReloginRequiredError =>
      'Log in to this account again, then delete it';

  @override
  String get shellAccountDeleteNeedsEmailCodeSnack =>
      'Deleting requires an email verification code. Continue from \"Delete account\"';

  @override
  String get shellAccountDeleteTitle => 'Delete RASQ account';

  @override
  String get shellAccountDeleteMessage =>
      'This deletes your profile on the server, account bundles, synced settings, reviews and bookmarks, ASTell rooms and shares, notification tokens, and consent records. If you agreed to \"Contributing to algorithms and the community\", we will also stop collecting and start deleting the data already provided.\nThis can\'t be undone. Your accounts and posts on each SNS will not be deleted.';

  @override
  String get shellAccountDeleteConfirmButton => 'Delete';

  @override
  String get shellAccountDeletedSnack => 'RASQ account deleted';

  @override
  String shellAccountDeleteFailedError(String error) {
    return 'Couldn\'t delete: $error';
  }

  @override
  String shellAccountCreatedSnack(String handle) {
    return 'Created RASQ account @$handle';
  }

  @override
  String shellAccountSanctionActive(String level) {
    return 'An action has been applied to this account: $level';
  }

  @override
  String shellAccountSanctionRestrictedFeatures(String features) {
    return 'Restricted features: $features';
  }

  @override
  String shellAccountSanctionReviewDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'Each message is held for review for $seconds seconds',
      one: 'Each message is held for review for 1 second',
    );
    return '$_temp0';
  }

  @override
  String shellAccountSanctionStaffNote(String note) {
    return 'From the moderators: $note';
  }

  @override
  String get shellAccountSanctionNoExpiry => 'Expires: never';

  @override
  String shellAccountSanctionExpiry(String expiresAt) {
    return 'Expires: $expiresAt';
  }

  @override
  String shellAccountSanctionAppealButton(String category, String level) {
    return 'Appeal ($category / $level)';
  }

  @override
  String shellAccountSanctionAppealPending(String category) {
    return 'Appeal pending ($category)';
  }

  @override
  String get shellAccountEmpty => 'No RASQ accounts yet.';

  @override
  String shellAccountRowSubtitle(String kind, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count SNS accounts',
      one: '1 SNS account',
    );
    return '$kind · $_temp0';
  }

  @override
  String get shellAccountRowInUseSuffix => ' · In use';

  @override
  String get shellAccountRowNeedsLoginSuffix => ' · Login required';

  @override
  String get shellAccountCollapseActionsTooltip => 'Collapse actions';

  @override
  String get shellAccountActionsTooltip => 'Account actions';

  @override
  String shellAccountReloginSnack(String handle) {
    return 'Please log in to @$handle again';
  }

  @override
  String get shellAccountChildSafeButton => 'Child Safe';

  @override
  String get shellAccountCreateButton => 'Create new account';

  @override
  String get shellAccountLoginButton => 'Log in';

  @override
  String get shellAccountServerNotConfigured =>
      'RASQ server address is not set';

  @override
  String get shellAccountConfigureServerButton => 'Set up connection';

  @override
  String get shellAccountProfileSheetTitle => 'Edit profile';

  @override
  String get shellAccountProfileSaveButton => 'Save';

  @override
  String get shellAccountProfileDisplayNameLabel => 'Display name';

  @override
  String get shellAccountProfileDisplayNameHint => 'Display name';

  @override
  String get shellAccountProfileHandleLabel => 'Handle (without @, a-z 0-9 _)';

  @override
  String get shellAccountProfileCentralCaption =>
      'Updates your profile on the RASQ server.';

  @override
  String get shellAccountProfileLocalCaption =>
      'This account exists only on this device. A handle is assigned when you create a RASQ account.';

  @override
  String get shellAccountProfileSavedSnack => 'Profile saved';

  @override
  String shellAccountProfileSaveFailedError(String error) {
    return 'Couldn\'t save: $error';
  }

  @override
  String get shellAccountTileMenuTooltip => 'RASQ account';

  @override
  String get shellTermsSheetTitle => 'Accept the Terms of Service';

  @override
  String get shellTermsAgreeButton => 'Agree';

  @override
  String get shellTermsNotice =>
      'To keep using your RASQ account, you need to accept the current Terms of Service and Privacy Policy. Until you do, ASTell, purchases, and data storage aren\'t available.';

  @override
  String shellTermsNoticeDetail(String endpoints) {
    return 'D-371 / S-053. Status stays \"awaiting consent\" until acceptances matching the server\'s CENTRAL_TERMS_VERSION / CENTRAL_PRIVACY_VERSION are all recorded. PUT /me/consents/$endpoints.';
  }

  @override
  String get shellTermsReadTermsButton => 'Read the Terms of Service';

  @override
  String get shellTermsReadPrivacyButton => 'Read the Privacy Policy';

  @override
  String get shellTermsAgeHeader => 'Age';

  @override
  String get shellTermsGuardianConsentCheck => 'I have my guardian\'s consent';

  @override
  String get shellTermsAgreeCheck =>
      'I have read and agree to the Terms of Service and Privacy Policy';

  @override
  String shellTermsVersionCaption(String termsVersion, String privacyVersion) {
    return 'Versions: Terms of Service $termsVersion · Privacy Policy $privacyVersion';
  }

  @override
  String get shellTermsAcceptedSnack => 'You\'ve accepted the Terms of Service';

  @override
  String get shellTermsOutdatedError =>
      'The Terms of Service have been updated. Update the app, then accept';

  @override
  String shellTermsRecordFailedError(String error) {
    return 'Couldn\'t record your consent: $error';
  }

  @override
  String get shellTermsBannerText =>
      'You need to accept the Terms of Service. Until you do, ASTell, purchases, and more aren\'t available.';

  @override
  String get shellTermsBannerOpenButton => 'Review';

  @override
  String get storeStatusInReview => 'In review';

  @override
  String get storeStatusPublished => 'Published';

  @override
  String get storeStatusUpdateAvailable => 'Update available';

  @override
  String get storeStatusWarning => 'Warning';

  @override
  String get storeStatusSuspended => 'Suspended';

  @override
  String get storeStatusWithdrawn => 'Withdrawn';

  @override
  String get storeStatusUnlisted => 'Unlisted';

  @override
  String get storeStatusBeta => 'Beta';

  @override
  String get storeStatusRevoked => 'Revoked';

  @override
  String get storeOriginOfficial => 'Official';

  @override
  String get storeOriginVerified => 'Verified';

  @override
  String get storeOriginCommunity => 'Community';

  @override
  String get storeTypeComposer => 'Compose';

  @override
  String get storeTypePost => 'Post';

  @override
  String get storeTypeViewer => 'Full-screen';

  @override
  String get storeTypeTimeline => 'Timeline';

  @override
  String get storeTypeTrend => 'Trends';

  @override
  String get storeTypeTheme => 'Themes';

  @override
  String get storeTypeAssets => 'Stickers / Assets';

  @override
  String get storeTypeCustom => 'Custom';

  @override
  String get storeTypeOther => 'Other';

  @override
  String get storeFilterFree => 'Free';

  @override
  String get storeFilterNoAds => 'No ads';

  @override
  String get storeFilterOfficial => 'Official';

  @override
  String get storeFilterVerified => 'Verified';

  @override
  String get storeFilterRecent => 'Last 30 days';

  @override
  String get storeFilterLightweight => 'Lightweight (under 5 MB)';

  @override
  String get storeFilterOffline => 'Offline';

  @override
  String get storePermNetwork => 'Network';

  @override
  String get storePermNetworkDescription => 'External communication';

  @override
  String get storePermStorage => 'Storage';

  @override
  String get storePermStorageDescription => 'On-device storage';

  @override
  String get storePermFiles => 'Files';

  @override
  String get storePermFilesDescription => 'Read and write files you choose';

  @override
  String get storePermSns => 'Posts and accounts';

  @override
  String get storePermSnsDescription => 'Actions using your SNS accounts';

  @override
  String get storePermDm => 'Direct messages';

  @override
  String get storePermDmDescription => 'Read and write DMs';

  @override
  String get storePermGpuMl => 'GPU / Machine learning';

  @override
  String get storePermGpuMlDescription => 'GPU execution and model inference';

  @override
  String get storePermClipboard => 'Clipboard';

  @override
  String get storePermClipboardDescription => 'Read and write copied content';

  @override
  String get storePermBackground => 'Background execution';

  @override
  String get storePermBackgroundDescription =>
      'Keeps running after the screen is closed';

  @override
  String get storePermUi => 'Screens and layout';

  @override
  String get storePermUiDescription => 'Screen display and button placement';

  @override
  String get storePermOther => 'Other';

  @override
  String get storeReviewSortHelpful => 'Relevance';

  @override
  String get storeReviewSortRecent => 'Newest';

  @override
  String get storeReviewSortRatingHigh => 'Highest rated';

  @override
  String get storeReviewSortRatingLow => 'Lowest rated';

  @override
  String storeScopePermission(String permission) {
    return 'Permission $permission';
  }

  @override
  String storeScopeHost(String host) {
    return 'Connects to $host';
  }

  @override
  String get storeScopeInstance => 'Connects to your login instance';

  @override
  String storeScopeSlot(String slot) {
    return 'Used in $slot';
  }

  @override
  String storeScopeReason(String permission, String reason) {
    return 'Purpose of $permission — $reason';
  }

  @override
  String storeScopeDataHandling(String text) {
    return 'Data handling — $text';
  }

  @override
  String storeNeedsOrgate(String feature) {
    return '$feature is available when connected to ORGATE-Server (no server address set)';
  }

  @override
  String get storeFeaturePurchase => 'Purchasing';

  @override
  String get storeFeaturePoints => 'Points';

  @override
  String get storeFeatureReview => 'Reviews';

  @override
  String storeSessionPluginMismatch(String actual, String expected) {
    return 'The configured plugin ($actual) differs from the one requested ($expected)';
  }

  @override
  String storeSessionVersionMismatch(String actual, String expected) {
    return 'The configured version ($actual) differs from the version requested ($expected)';
  }

  @override
  String get storeNoBundle => 'No package available';

  @override
  String get storeListSeparator => ', ';

  @override
  String get storeDotSeparator => ' · ';

  @override
  String get storeVerifyHashOnly => 'SHA-512 check OK (unsigned)';

  @override
  String get storeVerifyFull => 'SHA-512 + ed25519 signature verified OK';

  @override
  String get storeVerifyHashMismatch =>
      'Integrity check failed (SHA-512 mismatch). Please try again later';

  @override
  String get storeVerifyKeyMismatch =>
      'The Store\'s signing key doesn\'t match the key built into the app. Check the server address';

  @override
  String get storeVerifyUnsigned =>
      'The package is unsigned (this build only allows signed stores)';

  @override
  String get storeVerifyBadSignature =>
      'The package\'s signature is invalid. Installation was cancelled';

  @override
  String storeVerifyError(String error) {
    return 'Couldn\'t verify the signature: $error';
  }

  @override
  String get storeWidenedNoRecord =>
      'Because there\'s no record of what you last allowed (check and install it from Manage plugins)';

  @override
  String storeWidenedOver(String items) {
    return 'Because it goes beyond what you last allowed ($items)';
  }

  @override
  String get storeManifestUnavailable =>
      'Couldn\'t get the configuration (manifest)';

  @override
  String storeManifestVersionNotFound(String version) {
    return 'Couldn\'t find the configuration for Ver.$version';
  }

  @override
  String storeConsentChanged(String version) {
    return 'The Store\'s configuration has changed from what you confirmed (Ver.$version). Please check again';
  }

  @override
  String storePackageInvalid(String error) {
    return 'Couldn\'t verify the package contents: $error';
  }

  @override
  String storePackageMismatch(String actual, String expected) {
    return 'The package contents ($actual) differ from the Store listing ($expected)';
  }

  @override
  String storePackageRequires(String plugins) {
    return 'This plugin requires $plugins (can\'t be installed because it\'s not supported)';
  }

  @override
  String storeThemeSaveFailed(String error) {
    return 'Couldn\'t save the theme: $error';
  }

  @override
  String storeAssetsSaveFailed(String error) {
    return 'Couldn\'t save the asset pack: $error';
  }

  @override
  String get storeSlotRegisterFailed => 'Couldn\'t register to the slot';

  @override
  String storeVersionBundleChanged(String version) {
    return 'Not loading Ver.$version because its package differs from when it was installed (please reinstall)';
  }

  @override
  String storeVersionLoadFailed(String version, String error) {
    return 'Couldn\'t load Ver.$version: $error';
  }

  @override
  String get storeVersionNoScopeRecord =>
      'There\'s no record of what this version is allowed to do (reinstall to review it)';

  @override
  String storeVersionNotInstalled(String version) {
    return 'Ver.$version isn\'t installed';
  }

  @override
  String get storeNotInstalled => 'Not installed';

  @override
  String storeVersionInUse(String version) {
    return 'Ver.$version is in use (unset it as the default / account version first)';
  }

  @override
  String get storeManageTitle => 'Manage plugins';

  @override
  String get storeManageUpdatesHeader => 'Updates';

  @override
  String get storeManageUpdateSettingsTitle => 'Update settings';

  @override
  String get storeManageUpdateSettingsSubtitle =>
      'Whether to update automatically · Update log';

  @override
  String get storeManageUpdateSettingsDetail =>
      'Per SNS / action / view: automatic, install only, or manual · Update log';

  @override
  String get storeManagePointsTitle => 'Points';

  @override
  String get storeManagePointsDisabled => 'Not available in the public test';

  @override
  String storeManagePointsBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String get storeManagePointsSignIn =>
      'Log in to your RASQ account to use this';

  @override
  String get storeManagePointsBuyInConsole =>
      'Buy in the web console (expires 1 month after being granted)';

  @override
  String storeManagePointsExpiring(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points expire on $month/$day · Buy in web console',
      one: '1 point expires on $month/$day · Buy in web console',
    );
    return '$_temp0';
  }

  @override
  String get storeNoInstalledPlugins => 'No installed plugins';

  @override
  String get storeManageImportTitle => 'Import plugin';

  @override
  String get storeManageImportSubtitle =>
      'Install a plugin in development (before review)';

  @override
  String get storeManageImportDetail =>
      'Install a wasm / .rasqpkg in development (not reviewed)';

  @override
  String get storeManageHomeHeader => 'Home display';

  @override
  String get storeManageShowInstalledTitle =>
      'Also show installed plugins on Home';

  @override
  String get storeManageShowInstalledSubtitle =>
      'Includes installed plugins in the This week\'s trends / New rows';

  @override
  String get storeBookmarksTitle => 'Bookmarks';

  @override
  String storeManageSwitchTo(String version) {
    return 'Switch to $version';
  }

  @override
  String storeVersionMadeDefault(String version) {
    return 'Made $version the default version';
  }

  @override
  String storeManageUpdateTo(String version) {
    return 'Update to $version';
  }

  @override
  String get storeManageOffline => 'Can\'t connect to the Store';

  @override
  String get storeManageUpToDate => 'Up to date';

  @override
  String get storeManageDeployedVersion => 'Deployed version';

  @override
  String get storeAccountVersionsTitle => 'Set version per account';

  @override
  String storeManageAccountVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Per account ($count set)',
      one: 'Per account (1 set)',
    );
    return '$_temp0';
  }

  @override
  String get storePluginNotFound => 'This plugin wasn\'t found';

  @override
  String storeInstallFailed(String error) {
    return 'Couldn\'t install: $error';
  }

  @override
  String get storeHasAds => 'Contains ads';

  @override
  String get storeBuyDisabled =>
      'Purchases aren\'t available in the public test';

  @override
  String get storeTileGet => 'Get';

  @override
  String get storeTileUpdate => 'Update';

  @override
  String get storeOpen => 'Open';

  @override
  String get storeTileUnavailable => 'Suspended';

  @override
  String storeDownloadsTenThousands(String value) {
    return '$value×10K';
  }

  @override
  String storeNotAssetPack(String id) {
    return 'Not an asset pack: $id';
  }

  @override
  String get storeUpdatesNoneApplied =>
      'No updates were installed automatically';

  @override
  String get storeUpdateSettingsTitle => 'Update/deploy settings';

  @override
  String get storeUpdateSettingsModeHeader => 'Update/deploy';

  @override
  String get storeUpdateSettingsPopup =>
      'Show a popup on launch after updating';

  @override
  String get storeUpdateLogTitle => 'Update log';

  @override
  String get storeUpdateSettingsCheckNow => 'Check now';

  @override
  String get storeUpdateSettingsCaption =>
      'Versions that expand what you\'ve allowed and paid versions aren\'t installed automatically';

  @override
  String get storeUpdateSettingsCaptionDetail =>
      'Versions whose permissions, connections, usage locations or purposes go beyond what you last allowed (including versions that can\'t be checked), and paid versions you haven\'t bought, are never started automatically in any mode (the reason is kept in the update log). Checked once at every launch.';

  @override
  String get storeUpdateLogEmpty => 'Nothing yet';

  @override
  String get storeUpdateLogEmptyHint => 'Updates will be recorded here';

  @override
  String get storeInstalledTitle => 'Installed';

  @override
  String get storeInstalledEmptyHint => 'You can add plugins from the Store';

  @override
  String storeInstalledItemSubtitle(String version, String id) {
    return 'v$version · $id';
  }

  @override
  String get storeUnknown => 'Unknown';

  @override
  String get storeInstalledMissingHint =>
      'It was removed, or installed on another device';

  @override
  String get storeInstalledSourceSnapshot =>
      'A copy of the listing at install time.';

  @override
  String get storeInstalledSourceManifest =>
      'The plugin\'s own declaration (permission ids only).';

  @override
  String get storeInstalledRemoveTitle => 'Remove?';

  @override
  String storeInstalledRemoveMessage(String name) {
    return '$name will be removed from this device.';
  }

  @override
  String get storeRemove => 'Remove';

  @override
  String get storeCancel => 'Cancel';

  @override
  String get storeInstalledOffline =>
      'Can\'t connect to the Store, so local information is shown.';

  @override
  String get storeInstalledUnlisted =>
      'The Store listing wasn\'t found (it may have been withdrawn). You can keep using it or remove it.';

  @override
  String get storeInstalledVersionHeader => 'Installed version';

  @override
  String storeInstalledAt(String date) {
    return 'Installed: $date';
  }

  @override
  String storeInstalledAtVerified(String date, String sha512) {
    return 'Installed: $date · Verified SHA-512 $sha512';
  }

  @override
  String storeInstalledNewerTitle(String version) {
    return 'v$version is available in the Store';
  }

  @override
  String get storeInstalledNewerSubtitle =>
      'You can reinstall from the Store page';

  @override
  String storeInstalledSlots(String slots) {
    return 'Running in: $slots';
  }

  @override
  String get storeInstalledOpenStore => 'Open Store page';

  @override
  String get storePrivacyHeader => 'Privacy and required permissions';

  @override
  String get storeVersionsInstalledHeader => 'Installed versions';

  @override
  String get storeVersionsDefault => 'Default version';

  @override
  String storeVersionsUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Used by $count accounts',
      one: 'Used by 1 account',
    );
    return '$_temp0';
  }

  @override
  String storeVersionsInstalledOn(int year, int month, int day) {
    return 'Installed $year/$month/$day';
  }

  @override
  String get storeMenu => 'Menu';

  @override
  String get storeVersionsMakeDefault => 'Make default version';

  @override
  String get storeVersionsRemove => 'Remove this version';

  @override
  String storeVersionsRemoved(String version) {
    return 'Removed $version';
  }

  @override
  String get storeVersionsOthersHeader => 'Install another version';

  @override
  String get storeVersionsMorePermissions => 'Requires more permissions';

  @override
  String get storeVersionsInstall => 'Install';

  @override
  String get storeVersionsPerAccountHeader => 'Per account';

  @override
  String get storeVersionsPerAccountCaption =>
      'You can choose which version to use for each account';

  @override
  String get storeVersionsPerAccountDetail =>
      'While that account is in use, slot plugins and node sorting run with the version chosen here.';

  @override
  String storeVersionsFollowDefault(String version) {
    return 'Follow default ($version)';
  }

  @override
  String storeVersionsAccountFollows(String account) {
    return '$account follows the default version';
  }

  @override
  String storeVersionsAccountUses(String account, String version) {
    return '$account uses $version';
  }

  @override
  String storeVersionsDefaultShort(String version) {
    return 'Default ($version)';
  }

  @override
  String get storeVersionsPackNote =>
      'Themes / stickers and assets use one version across the whole device (the default version).';

  @override
  String get storeUpdateModeAuto => 'Automatic';

  @override
  String get storeUpdateModeAutoDescription =>
      'Installs new versions and makes them the default (versions set per account stay as they are)';

  @override
  String get storeUpdateModeInstallOnly => 'Automatic install only';

  @override
  String get storeUpdateModeInstallOnlyDescription =>
      'Only installs new versions; doesn\'t change which version is used';

  @override
  String get storeUpdateModeManual => 'Fully manual';

  @override
  String get storeUpdateModeManualDescription =>
      'Does nothing automatically (install from Manage plugins)';

  @override
  String get storeUpdateGroupSns => 'SNS plugins';

  @override
  String get storeUpdateGroupAction => 'Action plugins';

  @override
  String get storeUpdateGroupView => 'View plugins';

  @override
  String storeUpdateLogActivated(String from, String to) {
    return '$from → $to (made default)';
  }

  @override
  String storeUpdateLogInstalled(String from, String to) {
    return 'Installed $to (still using $from)';
  }

  @override
  String storeUpdateLogSwitched(String from, String to) {
    return '$from → $to (made an installed version the default)';
  }

  @override
  String storeUpdateLogSkipped(String to) {
    return '$to isn\'t installed automatically';
  }

  @override
  String storeUpdateLogSkippedNote(String to, String note) {
    return '$to isn\'t installed automatically ($note)';
  }

  @override
  String storeUpdateLogFailed(String to) {
    return 'Couldn\'t install $to';
  }

  @override
  String storeUpdateLogFailedNote(String to, String note) {
    return 'Couldn\'t install $to ($note)';
  }

  @override
  String get storeUpdatePopupTitle => 'Plugins updated';

  @override
  String get storeClose => 'Close';

  @override
  String get storeReviewsTitle => 'Reviews';

  @override
  String get storeReviewsLoadFailed => 'Couldn\'t load reviews';

  @override
  String get storeReviewWrite => 'Write a review';

  @override
  String get storeReviewsEmpty => 'No reviews yet';

  @override
  String get storeReviewsEmptyHint =>
      'Tap + at the bottom right to write the first review';

  @override
  String get storeCopyLink => 'Copy link';

  @override
  String get storeReviewReport => 'Report review';

  @override
  String get storeReviewLinkCopied => 'Copied review link';

  @override
  String get storeReviewReportUnavailable => 'Reporting reviews is coming soon';

  @override
  String storeReloadFailed(String error) {
    return 'Couldn\'t reload: $error';
  }

  @override
  String get storeNoNewPlugins => 'No newly published plugins';

  @override
  String storeNewPluginsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count newly published plugins',
      one: 'Added 1 newly published plugin',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchTitle => 'Search plugins';

  @override
  String get storeSearchRecentPick => 'Picked from your recent posts';

  @override
  String get storeSearchFailed => 'Couldn\'t search';

  @override
  String get storeSearchNoRecentPosts => 'No recent posts found';

  @override
  String get storeSearchNoRecentPostsHint =>
      'Post with an SNS account and plugins close to that content will be picked';

  @override
  String storeSearchRecentCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Sorted by closeness to your $count recent posts (chosen on your device)',
      one: 'Sorted by closeness to your 1 recent post (chosen on your device)',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchNoRecentMatches =>
      'No plugins close to your recent posts were found';

  @override
  String get storeSearchNoResults => 'No results';

  @override
  String get storeSearchNoResultsHint => 'Try different words or filters';

  @override
  String get storeHomeTitle => 'Plugin Store';

  @override
  String get storeConnectFailed => 'Couldn\'t connect to the Store';

  @override
  String get storeHomeOffline =>
      'Not connected to the RASQ server. Only plugins included in the app are shown';

  @override
  String get storeHomeOfflineDetail =>
      'Central not connected: only the bundled items (Misskey connector and slot samples). Ratings / downloads / reviews / purchases appear when connected to the server.';

  @override
  String get storeHomeTrending => 'This week\'s trends';

  @override
  String get storeHomeRecent => 'New';

  @override
  String get storeHomeReviewedOnly => 'Only reviewed plugins are listed';

  @override
  String get storeHomeReviewedOnlyDetail =>
      'Plugins in development can be installed in developer mode via the gear at the top right → Manage plugins → \"Import plugin\".';

  @override
  String get storeRowEmpty => 'No plugins to show right now';

  @override
  String get storeInstallManifestUnavailable =>
      'Couldn\'t get the configuration';

  @override
  String storeInstallSheetTitle(String name, String version) {
    return 'Install $name $version';
  }

  @override
  String get storeInstallPermissionsHeader => 'Permissions this plugin uses';

  @override
  String get storeInstallHostsHeader => 'Connections';

  @override
  String get storeInstallLoginInstance => 'Your login instance';

  @override
  String get storeInstallScopeNoRecord =>
      'What will be allowed (no record from a previous install)';

  @override
  String get storeInstallScopeWidened =>
      'What goes beyond what you last allowed';

  @override
  String get storeInstallPermissionsAdded =>
      'Permissions added since the previous version';

  @override
  String storeInstallBundleSummary(String size, String signature) {
    return '$size MB · $signature';
  }

  @override
  String get storeInstallSignedShort => 'Store-signed';

  @override
  String get storeInstallUnsignedShort => 'Not Store-signed';

  @override
  String storeInstallBundleDetail(
    String size,
    String sha512,
    String signature,
  ) {
    return 'Package: $size MB · SHA-512 $sha512… · $signature';
  }

  @override
  String get storeInstallSignedDetail => 'Store-signed (ed25519)';

  @override
  String get storeInstallUnsignedDetail => 'Not Store-signed (hash check only)';

  @override
  String get storeInstallConfirm => 'Install';

  @override
  String storeInstallThemeDarkOnly(String name) {
    return 'Using $name. It applies in dark mode';
  }

  @override
  String storeInstallThemeLightOnly(String name) {
    return 'Using $name. It applies in light mode';
  }

  @override
  String storeInstallThemeApplied(String name) {
    return 'Using $name';
  }

  @override
  String storeInstallDone(String name, String version) {
    return 'Installed $name $version';
  }

  @override
  String storeVersionScopeTitle(String version) {
    return 'Ver.$version expands what\'s allowed';
  }

  @override
  String get storeVersionScopeConfirm => 'Allow and use';

  @override
  String get storeVersionScopeCancel => 'Cancel';

  @override
  String storePurchasePointsFailed(String error) {
    return 'Couldn\'t check points (are you logged in to a RASQ account?): $error';
  }

  @override
  String storePurchaseTitle(String name) {
    return 'Purchase $name';
  }

  @override
  String storePurchasePrice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points',
      one: '1 point',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points left',
      one: '1 point left',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalanceExpiring(int count, String date, int expiring) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count points left · $expiring points expire on $date',
      one: '1 point left · $expiring points expire on $date',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseCaption =>
      'Purchased plugins can be used on any device with the same account';

  @override
  String get storePurchaseCaptionDetail =>
      'Purchased plugins can be installed on any device with the same RASQ account. Points closest to expiring are used first.';

  @override
  String storePurchaseBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Buy for $count points',
      one: 'Buy for 1 point',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Not enough points ($count more needed)',
      one: 'Not enough points (1 more needed)',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseConsole => 'Buy points in the web console';

  @override
  String get storePurchaseFailed => 'Couldn\'t complete the purchase';

  @override
  String storeReleaseNotesSemantics(String version) {
    return 'Release notes $version';
  }

  @override
  String get storeReleaseBeta => 'Preview (β)';

  @override
  String get storeReleaseStable => 'Stable';

  @override
  String storeReleasePublishedOn(int year, int month, int day) {
    return 'Published $year/$month/$day';
  }

  @override
  String get storeReleaseCurrentListing => 'Current listed version';

  @override
  String get storeReleaseInstalled => 'Installed';

  @override
  String get storeReleaseNoNotes => 'This version has no release notes.';

  @override
  String get storeReleasePermissionsAdded =>
      'Permissions added in this version';

  @override
  String get storeReleasePermissionsNote =>
      'Updates that add permissions aren\'t applied automatically. Review the details before installing.';

  @override
  String storeReleaseAlreadyInstalled(String version) {
    return 'Ver.$version is installed';
  }

  @override
  String storeReleaseBlocked(String status) {
    return 'Can\'t install because it\'s $status';
  }

  @override
  String storeReleaseInstall(String version) {
    return 'Install Ver.$version';
  }

  @override
  String storeReleaseReplaces(String version) {
    return 'v$version is currently installed. It will be replaced by this version.';
  }

  @override
  String get storeReviewNoVotes => 'No ratings yet';

  @override
  String storeReviewHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people found this helpful.',
      one: '1 person found this helpful.',
    );
    return '$_temp0';
  }

  @override
  String get storeShare => 'Share';

  @override
  String get storeReviewHelpful => 'Helpful';

  @override
  String get storeReviewNotHelpful => 'Not helpful';

  @override
  String get storeReviewAnonymous => 'Anonymous';

  @override
  String get storeReviewVerifiedUse => 'Verified user';

  @override
  String storeReviewDeveloperReply(String reply) {
    return 'Developer reply: $reply';
  }

  @override
  String get storeReviewNoBody => '(no text)';

  @override
  String get storeReviewComposeTitle => 'Write a review';

  @override
  String get storeReviewSend => 'Send';

  @override
  String get storeRatingLabel => 'Rating';

  @override
  String get storeReviewTitleHint => 'Title (optional)';

  @override
  String get storeReviewBodyHint =>
      'Share how it worked for you or anything you noticed';

  @override
  String storeReviewUsedVersion(String version) {
    return 'Version used: v$version';
  }

  @override
  String get storeReviewPickRating => 'Please choose a ★ rating';

  @override
  String get storeReviewSent => 'Review sent';

  @override
  String storeReviewSendFailed(String error) {
    return 'Couldn\'t send the review: $error';
  }

  @override
  String get storeReviewNeedsInstall =>
      'You can only review plugins you\'ve installed';

  @override
  String get storeReviewNeedsInstallServer =>
      'You can only review plugins you\'ve installed. Reinstall (or update) it while logged in to be able to review';

  @override
  String get storeSafetyNoPermissions => 'Required permissions: none';

  @override
  String get storeSafetyExternalHeader => 'External communication and data';

  @override
  String get storeSafetyNoHosts => 'External connections: none';

  @override
  String storeSafetyHosts(String hosts) {
    return 'External connections: $hosts';
  }

  @override
  String storeSafetyDataHandling(String text) {
    return 'Data handling: $text';
  }

  @override
  String storeSafetySdks(String sdks) {
    return 'External SDKs: $sdks';
  }

  @override
  String get storeSafetyRuntimeHeader => 'Runtime';

  @override
  String storeSafetyCrashFree(String rate) {
    return 'Crash-free launches $rate%';
  }

  @override
  String get storeSafetyBackground => 'Runs in background';

  @override
  String get storeSafetyNoBackground => 'No background execution';

  @override
  String get storeSafetyGpu => 'Uses GPU';

  @override
  String get storeSafetyNoGpu => 'Doesn\'t use GPU';

  @override
  String get storeSafetyNoAds => 'No ads';

  @override
  String storeSafetyAds(String placements) {
    return 'Contains ads ($placements)';
  }

  @override
  String get storePageMenuPostReview => 'Post a review';

  @override
  String get storePageMenuReport => 'Report plugin';

  @override
  String get storePageLinkCopied => 'Copied Store page link';

  @override
  String get storePageTitle => 'Plugin';

  @override
  String get storePageMaybeWithdrawn => 'It may have been withdrawn';

  @override
  String get storePageOpenInstalled => 'View installed info';

  @override
  String get storePageRequiresPrefix => 'To use this plugin, ';

  @override
  String get storePageRequiresSuffix => ' must be installed.';

  @override
  String storePageInstalledVersion(String version) {
    return 'Installed v$version';
  }

  @override
  String storePageInstalledVersionVerified(String version) {
    return 'Installed v$version (SHA-512 verified)';
  }

  @override
  String get storeFree => 'Free';

  @override
  String storePriceYen(String amount) {
    return '¥$amount';
  }

  @override
  String get storePageInstall => 'Install';

  @override
  String storePageBuy(String amount) {
    return 'Buy for ¥$amount';
  }

  @override
  String get storePageThemeInUse => 'In use';

  @override
  String get storePageThemeUse => 'Use';

  @override
  String get storePageUnknownDeveloper => 'Unknown provider';

  @override
  String storePageRatingDownloads(String rating, String downloads) {
    return '★$rating · $downloads downloads';
  }

  @override
  String storePageStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get storePagePreview => 'Preview';

  @override
  String get storePageDownloadsLastMonth => 'Downloads last month';

  @override
  String storePageReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reviews',
      one: '1 review',
    );
    return '$_temp0';
  }

  @override
  String get storePageReviewsEmptyBody => 'Why not write the first review?';

  @override
  String get storePageUpdatesHeader => 'Updates and versions';

  @override
  String get storePageNoReleaseNotes => 'No release notes yet.';

  @override
  String get storeInUse => 'In use';

  @override
  String storePermissionsAddedList(String permissions) {
    return 'Added permissions: $permissions';
  }

  @override
  String get storePagePermissionsHeader => 'Permissions';

  @override
  String get storePageNoPermissions =>
      'This plugin doesn\'t request additional permissions.';

  @override
  String get storePageCompatibilityHeader => 'Compatibility';

  @override
  String storePageRuntimes(String runtimes) {
    return 'Runtimes: $runtimes';
  }

  @override
  String storePageRequiredPlugins(String plugins) {
    return 'Required plugins: $plugins';
  }

  @override
  String storePageConflicts(String plugins) {
    return 'Conflicts: $plugins';
  }

  @override
  String storePageRasqFeatures(String features) {
    return 'RASQ features used: $features';
  }

  @override
  String get storePageVersionsTitle => 'Versions';

  @override
  String storePageNoPreview(String name) {
    return 'No preview images for $name yet';
  }

  @override
  String get storePageBookmarkRemove => 'Remove bookmark';

  @override
  String get storePageBookmarkAdd => 'Bookmark';

  @override
  String storePageBookmarkFailed(String error) {
    return 'Couldn\'t update bookmark: $error';
  }

  @override
  String storeNeedsServer(String feature) {
    return '$feature is available when connected to the RASQ server';
  }

  @override
  String get storeNoListing => 'No listing';

  @override
  String get storeCatalogMisskeyName => 'Misskey connector';

  @override
  String get storeCatalogMisskeySummary =>
      'An SNS plugin that connects Misskey to RASQ (wasm sample). Covers timelines, posting, reactions, emoji and post transforms.';

  @override
  String get storeCatalogMisskeyDescription =>
      'A Rust wasm plugin from rasq-sdk-sample. It implements contracts such as sns.login / sns.timeline / post.transform / tl.sort (PROTOCOL.md) and renders the timeline with RRL tiles. Post transforms without a node definition are applied right before posts are passed to the fetch node.';

  @override
  String get storeCatalogFeatureTimelineRrl => 'Timeline rendering (RRL)';

  @override
  String get storeCatalogFeatureNodeGraph => 'Node graph (tl.sort)';

  @override
  String get storeCatalogMisskeyPerm1 =>
      'To call the Misskey instance\'s API (only the host you specified at login)';

  @override
  String get storeCatalogMisskeyPerm2 =>
      'Storing the session token and timeline settings';

  @override
  String get storeCatalogMisskeyHost =>
      '<the Misskey instance you logged in to>';

  @override
  String get storeCatalogMisskeyDataHandling =>
      'Posts and tokens are stored only on the device (storage.safe). Nothing is sent to the developer.';

  @override
  String get storeCatalogSampleDataHandling =>
      'Processing runs entirely in wasm on the device, with nothing sent externally.';

  @override
  String get storeCatalogAstellName => 'ASTell sound and visual effects';

  @override
  String get storeCatalogAstellSummary =>
      'Plays sound effects, generated visual effects and preset text from ASTell plugin actions.';

  @override
  String get storeCatalogAstellDescription =>
      'Slot `astell.action`. The button this plugin declares at the bottom of the room opens a FOW for sharing system sounds (chime / click), generated PNGs of confetti, fireworks and applause, and preset text. It also shows posts received via \"Share to ASTell\".';

  @override
  String get storeCatalogFeatureAstellAction => 'ASTell plugin action';

  @override
  String get storeCatalogAstellPerm1 => 'To show the control panel (FOW)';

  @override
  String get storeCatalogAstellPerm2 =>
      'Storing how many times each effect was used';

  @override
  String get storeCatalogComposerMediaName => 'Media editing';

  @override
  String get storeCatalogComposerMediaSummary =>
      'Gamma correction, rotation, hue and cropping for attached images.';

  @override
  String get storeCatalogComposerMediaDescription =>
      'Slot `composer.media`. \"Edit with plugin\" on an attachment tile in the composer opens a FOW where you apply changes while watching a preview. Processing runs entirely in wasm on the device.';

  @override
  String get storeCatalogFeatureMediaComposer => 'Media composer';

  @override
  String get storeCatalogComposerMediaPerm1 =>
      'To show the editing panel (FOW)';

  @override
  String get storeCatalogComposerMediaPerm2 => 'Storing the last settings';

  @override
  String get storeCatalogComposerTextName => 'Hashtag suggestions';

  @override
  String get storeCatalogComposerTextSummary =>
      'Type # in the text to get suggestions, and tap one to insert it.';

  @override
  String get storeCatalogComposerTextDescription =>
      'Slot `composer.text`. Receives text changes and, when the text right before the cursor is #…, shows a suggestion FOW (recently used tags + dictionary).';

  @override
  String get storeCatalogFeatureTextComposer => 'Text composer';

  @override
  String get storeCatalogComposerTextPerm1 =>
      'To show the suggestion panel (FOW)';

  @override
  String get storeCatalogComposerTextPerm2 => 'Storing recently used tags';

  @override
  String get storeCatalogMediaFullscreenName => 'QR code detection';

  @override
  String get storeCatalogMediaFullscreenSummary =>
      'Finds QR codes in full-screen images, outlines them, and lets you tap to open the link.';

  @override
  String get storeCatalogMediaFullscreenDescription =>
      'Slot `viewer.overlay`. Receives the image in the full-screen viewer, detects QR codes and overlays bounding boxes. Tap for a link FOW (copy / open in browser / add to muted words).';

  @override
  String get storeCatalogFeatureViewerPlugin => 'Full-screen viewer plugin';

  @override
  String get storeCatalogMediaFullscreenPerm1 => 'To show the link panel (FOW)';

  @override
  String get storeCatalogMediaFullscreenPerm2 =>
      'To add to muted words via \"Mute this link\" (asks every time)';

  @override
  String get storeCatalogPostProcessName => 'Relative dates to dates';

  @override
  String get storeCatalogPostProcessSummary =>
      'Replaces \"today\", \"yesterday\" and \"tomorrow\" with dates based on the post date.';

  @override
  String get storeCatalogPostProcessDescription =>
      'Slot `post.transform`. Right before display in every timeline, rewrites relative dates in the text like \"9/10 (today)\" (JST). Text inside URLs is left untouched.';

  @override
  String get storeCatalogFeaturePostTransform =>
      'Post transform (post.transform)';

  @override
  String get storeCatalogTimelineName => 'Unicode ascending timeline';

  @override
  String get storeCatalogTimelineSummary =>
      'Adds a tab to Home that sorts posts by Unicode order of their text.';

  @override
  String get storeCatalogTimelineDescription =>
      'Slot `tl`. Takes the base timeline (Home) and shows a custom tab sorted by the Unicode code points of the text in ascending order.';

  @override
  String get storeCatalogFeatureTimelineSort => 'Timeline (tl.sort)';

  @override
  String get storeCatalogPostShareName => 'Share templates';

  @override
  String get storeCatalogPostShareSummary =>
      'Formats a post with a template (link / quote / mention the author) from the share FOW and sends it to the composer.';

  @override
  String get storeCatalogPostShareDescription =>
      'Slot `post.share`. Appears automatically in the \"Plugins\" section of a post\'s share FOW; tapping it opens an inline FOW to pick the wording and pass it to the composer / copy / browser / ASTell.';

  @override
  String get storeCatalogFeaturePostShare => 'Post sharing (post.share)';

  @override
  String get storeCatalogPostSharePerm1 =>
      'To show the template picker panel (FOW)';

  @override
  String get storeCatalogPostSharePerm2 => 'Storing the last template';

  @override
  String get storeCatalogMediaTransformName => 'Transform handles';

  @override
  String get storeCatalogMediaTransformSummary =>
      'Edit by overlaying rotate / crop handles on the image.';

  @override
  String get storeCatalogMediaTransformDescription =>
      'Slot `composer.media` (transform). Draws handles on the media editor\'s preview with an RRL overlay (contract v0.5 `composer.media.overlay`); trace with your finger to set the rotation angle or crop area.';

  @override
  String get storeCatalogFeatureOverlay => 'Overlay';

  @override
  String get storeCatalogMediaTransformPerm1 => 'To show the panel (FOW)';

  @override
  String get storeCatalogMediaProcessName => 'Editing (face blur / stickers)';

  @override
  String get storeCatalogMediaProcessSummary =>
      'Detects and blurs faces, and places stickers as objects (move / scale / rotate / delete / duplicate).';

  @override
  String get storeCatalogMediaProcessDescription =>
      'Slot `composer.media` (editing). Face detection runs in wasm (rustface) on the device, with nothing sent externally. Stickers can be moved with the overlay\'s frame and handles.';

  @override
  String get storeCatalogMediaProcessPerm1 =>
      'To show the sticker picker panel (FOW)';

  @override
  String get storeCatalogMediaDrawName => 'Drawing (pen / shapes)';

  @override
  String get storeCatalogMediaDrawSummary =>
      'Draws pen strokes as spline curves, and adds and edits rectangles / circles.';

  @override
  String get storeCatalogMediaDrawDescription =>
      'Slot `composer.media` (drawing). The pen smooths your finger\'s path with Catmull-Rom splines. Shapes are objects you can move / scale / delete / duplicate.';

  @override
  String get storeCatalogMediaDrawPerm1 =>
      'To show the pen width / color panel (FOW)';

  @override
  String get storeCatalogMediaDrawPerm2 => 'Storing pen settings';

  @override
  String get storeCatalogPostActionName => 'Post buttons';

  @override
  String get storeCatalogPostActionSummary =>
      'Read later / Copy text / Draft a quote — joins existing button bundles by tag.';

  @override
  String get storeCatalogPostActionDescription =>
      'Slot `post.action`. If the manifest\'s tags (preferred slots) are close to an existing action button, it\'s automatically added at the bottom of that bundle. In \"Edit action list\" you can turn it on or off and change the threshold per account.';

  @override
  String get storeCatalogFeaturePostAction =>
      'Post action buttons (post.action)';

  @override
  String get storeCatalogPostActionPerm1 => 'To show the read-later list (FOW)';

  @override
  String get storeCatalogPostActionPerm2 => 'Storing read-later items';

  @override
  String get storeCatalogThemeStarryName => 'Theme \"Starry Sky\"';

  @override
  String get storeCatalogThemeStarrySummary =>
      'A night-sky background, post tiles sprinkled with stars, and star likes.';

  @override
  String get storeCatalogThemeStarryDescription =>
      'Theme (`kind: \"theme\"`, contract v0.16). A code-free package that declares colors, icon replacements, and image layers for the backgrounds of screens, post tiles, FOWs and buttons. After installing, choose it in Settings → App appearance → Fonts and color scheme (applies in dark mode).';

  @override
  String get storeCatalogFeatureTheme => 'Theme';

  @override
  String get storeCatalogThemeRasqName => 'Theme \"RASQ\"';

  @override
  String get storeCatalogThemeRasqSummary =>
      'A navy gradient band above posts with a faint RASQ mark, and a green gradient for FOWs.';

  @override
  String get storeCatalogThemeRasqDescription =>
      'Theme (`kind: \"theme\"`, contract v0.17). A gradient band along the top edge of post tiles fading from #1F1E33 into the post background color, a faint RASQ mark in the background, and a top-to-bottom #02775C → #178178 gradient for FOW backgrounds (with white text). Works in both light and dark mode.';

  @override
  String get storeCatalogPaintName => 'Doodle together';

  @override
  String get storeCatalogPaintSummary =>
      'Everyone gets one square to doodle in and shows it to others for a limited time. In ASTell rooms and on profiles.';

  @override
  String get storeCatalogPaintDescription =>
      'Custom plugin (slot `page`, contract v0.23). 3:4 squares are laid out in 2 columns (shuffled for each person); tap your own square to doodle in the media editor\'s SVG mode (saved compressed with zstd). Each person picks how long theirs is shown, and the admin (the session owner) sets the default and the maximum. Central deletes doodles when they expire. The admin can delete other people\'s doodles.';

  @override
  String get storeCatalogFeatureCustomPage => 'Custom plugin (page)';

  @override
  String get storeCatalogFeatureSvgPaint => 'SVG doodles';

  @override
  String get storeCatalogFeatureDisplayPeriod => 'Display period';

  @override
  String get storeCatalogFeatureProfile => 'Profile';

  @override
  String get storeCatalogPaintPerm1 =>
      'To show the doodle squares and open the editor';

  @override
  String get storeCatalogPaintPerm2 =>
      'To share everyone\'s doodles and the admin\'s settings for a limited time';

  @override
  String get storeCatalogBoardName => 'Shared board';

  @override
  String get storeCatalogBoardSummary =>
      'Counters, polls, a message board and 🎉. Everyone can use the same board in ASTell rooms and on profiles.';

  @override
  String get storeCatalogBoardDescription =>
      'Custom plugin (slot `page`, contract v0.18). Adds one page; in shared sessions, server variables (counter / poll / message board) and a server function (🎉 for everyone) keep the same screen shared. Without a session it runs only on the device.';

  @override
  String get storeCatalogBoardPerm1 => 'To draw the page';

  @override
  String get storeCatalogBoardPerm2 =>
      'To share everyone\'s values (counter / poll / message board)';

  @override
  String get storeCatalogBoardPerm3 => 'Storing the board when used alone';

  @override
  String get storeCatalogTrendName => 'Trend suggestions';

  @override
  String get storeCatalogTrendSummary =>
      'Suggests related tags from current trending words using local rules.';

  @override
  String get storeCatalogTrendDescription =>
      'Slot `trend.suggest`. Shown in timeline nodes (Get trends / Today / suggestion chips) and in \"Search suggestions\" on the search home. Uses a serverless co-occurrence dictionary + prefix matching.';

  @override
  String get storeCatalogFeatureTrendSuggest => 'Trends (trend.suggest)';

  @override
  String storePkgMissingPlugin(String id) {
    return 'The package doesn\'t contain $id';
  }

  @override
  String get storePkgNotPackage => 'The package isn\'t a .rasqpkg (zstd)';

  @override
  String storePkgUnpack(String error) {
    return 'Can\'t extract the package (it\'s corrupted or too large): $error';
  }

  @override
  String storePkgTar(String error) {
    return 'Can\'t read the package\'s tar: $error';
  }

  @override
  String get storePkgTooManyFiles => 'The package contains too many files';

  @override
  String storePkgNotRegularFile(String path) {
    return 'The package contains something that isn\'t a regular file: $path';
  }

  @override
  String storePkgDuplicatePath(String path) {
    return 'Duplicate path in the package: $path';
  }

  @override
  String get storePkgBundleFirst =>
      'The package doesn\'t start with bundle.json';

  @override
  String storePkgBundleRead(String error) {
    return 'Can\'t read bundle.json: $error';
  }

  @override
  String storePkgBundleSchema(String schema) {
    return 'bundle.json schema isn\'t rasq.bundle/1: $schema';
  }

  @override
  String storePkgFileShape(String what) {
    return 'bundle.json: the wasm / file of $what has the wrong shape';
  }

  @override
  String storePkgNoPath(String what) {
    return 'bundle.json: $what has no path';
  }

  @override
  String storePkgSizeMismatch(String path) {
    return '$path: size doesn\'t match the index';
  }

  @override
  String storePkgHashMismatch(String path) {
    return '$path: SHA-512 doesn\'t match the index';
  }

  @override
  String storePkgNoSha512(String what) {
    return 'bundle.json: $what has no sha512';
  }

  @override
  String storePkgNotWasm(String path) {
    return '$path: not a wasm file';
  }

  @override
  String storePkgPluginShape(String what) {
    return 'bundle.json: $what has the wrong shape';
  }

  @override
  String storePkgBadId(String what, String id) {
    return 'bundle.json: invalid id for $what: $id';
  }

  @override
  String storePkgBadVersion(String id, String version) {
    return 'bundle.json: invalid version for $id: $version';
  }

  @override
  String storePkgBadKind(String id, String kind) {
    return 'bundle.json: invalid kind for $id: $kind';
  }

  @override
  String storePkgNoManifest(String id) {
    return 'bundle.json: $id has no manifest';
  }

  @override
  String storePkgManifestRead(String path, String error) {
    return 'Can\'t read $path: $error';
  }

  @override
  String storePkgManifestMismatch(
    String path,
    String id,
    String version,
    String kind,
  ) {
    return '$path: id / version / kind don\'t match the index ($id $version $kind)';
  }

  @override
  String storePkgChildPackKind(String id, String kind) {
    return 'bundle.json: child $id can\'t have kind = $kind';
  }

  @override
  String storePkgPackHasWasm(String kind, String id) {
    return 'bundle.json: $kind $id contains wasm';
  }

  @override
  String storePkgMissingKey(String key) {
    return 'bundle.json: $key is missing';
  }

  @override
  String get storePkgChildrenNotSns =>
      'bundle.json: only an sns root can have children';

  @override
  String storePkgChildPrefix(String id, String root) {
    return 'bundle.json: child $id\'s id doesn\'t start with $root.';
  }

  @override
  String storePkgChildSns(String id) {
    return 'bundle.json: child $id can\'t have kind = sns';
  }

  @override
  String get storePkgDuplicateId => 'bundle.json: duplicate plugin id';

  @override
  String get storePkgLibsShape => 'bundle.json: libs has the wrong shape';

  @override
  String get storePkgAssetsShape => 'bundle.json: assets has the wrong shape';

  @override
  String get storePkgPackExtras =>
      'bundle.json: asset packs / themes can\'t have children / libs / models';

  @override
  String get storePkgPackWasm => 'The asset pack / theme contains wasm';

  @override
  String storePkgPackImageCount(int max, int count) {
    return 'An asset pack must have 1–$max images: $count';
  }

  @override
  String storePkgNotImage(String path) {
    return '$path: not an image (PNG / JPEG / WebP / GIF)';
  }

  @override
  String storePkgImageTooLarge(String path, int mib) {
    return '$path: too large (up to $mib MiB per image)';
  }

  @override
  String storePkgAssetNotListed(String path) {
    return '$path in manifest.assets isn\'t in the package index';
  }

  @override
  String get storePkgModelsShape => 'bundle.json: models has the wrong shape';

  @override
  String get storePkgRequiresShape =>
      'bundle.json: requires has the wrong shape';

  @override
  String get storePkgNoSums => 'SHA512SUMS is missing';

  @override
  String storePkgSumsMissingFile(String path) {
    return '$path: listed in SHA512SUMS but not in the package';
  }

  @override
  String storePkgSumsMismatch(String path) {
    return '$path: doesn\'t match SHA512SUMS';
  }

  @override
  String storePkgUnlisted(String path) {
    return '$path: file not listed in the index';
  }

  @override
  String get storePkgThemeMissing => 'The theme manifest has no theme';

  @override
  String storePkgThemeAsset(String where, String id) {
    return 'Image $id in theme.$where isn\'t in assets (use: theme)';
  }

  @override
  String storePkgThemeSurface(String surface) {
    return '$surface can\'t be used in theme.surfaces (app / postTile / fow / actionButton)';
  }

  @override
  String storePkgThemeLayer(String surface) {
    return 'theme.surfaces.$surface.layers: specify exactly one of asset or gradient';
  }

  @override
  String storePkgThemeColors(String surface) {
    return 'theme.surfaces.$surface.layers: gradient.colors must have 2–8 colors';
  }

  @override
  String storePkgThemeStops(String surface) {
    return 'theme.surfaces.$surface.layers: gradient.stops must have the same count as colors';
  }

  @override
  String storePkgBadPath(String path) {
    return 'Can\'t be used as a path in the package: $path';
  }

  @override
  String storePkgSigAlg(String alg) {
    return 'Signature alg isn\'t ed25519: $alg';
  }

  @override
  String get storePkgSigDigest =>
      'The digest in sig.json doesn\'t match the package (the package has been replaced)';

  @override
  String get storePkgSigRead => 'Can\'t read publicKey / signature in sig.json';

  @override
  String get storePkgSigLength =>
      'The key / signature length in sig.json is wrong';

  @override
  String get storePkgSigInvalid => 'The developer key signature doesn\'t match';

  @override
  String storePkgFileMissing(String path) {
    return '$path: listed in the index but not in the package';
  }

  @override
  String storePkgTwice(String path) {
    return 'bundle.json: $path appears twice';
  }

  @override
  String get storePkgKindTheme => 'Theme';

  @override
  String get storePkgKindAssets => 'Asset pack';

  @override
  String swingActionFailed(String error) {
    return 'Couldn\'t complete: $error';
  }

  @override
  String get swingReplyHint => 'Send a reply…';

  @override
  String swingReplyToHint(String handle) {
    return 'Reply to @$handle…';
  }

  @override
  String swingReplyCount(int count) {
    return 'Replies $count';
  }

  @override
  String get swingQueueTooltip => 'Queue (long-press to pick a picture)';

  @override
  String get swingThreadBackReply => 'Back to previous reply';

  @override
  String get swingThreadBackSwing => 'Back to Swing replies';

  @override
  String swingRepliesTo(String handle, int count) {
    return 'Replies to @$handle $count';
  }

  @override
  String get swingThreadClose => 'Hide replies';

  @override
  String swingLoadFailed(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String get swingNoReplies => 'No replies yet.';

  @override
  String swingViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count replies',
      one: '1 reply',
    );
    return 'View $_temp0';
  }

  @override
  String swingAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attachments',
      one: '1 attachment',
    );
    return '$_temp0';
  }

  @override
  String get swingPoll => 'Poll';

  @override
  String swingReplyOf(String name) {
    return '$name\'s reply';
  }

  @override
  String get swingImageSwing => 'Image Swing';

  @override
  String get swingVideoSwing => 'Video Swing';

  @override
  String get swingPluginSwing => 'Plugin Swing';

  @override
  String swingOf(String name) {
    return '$name\'s Swing';
  }

  @override
  String get swingBarSemantics => 'Swing replies and seek bar';

  @override
  String swingReportIntro(String name) {
    return 'Report $name\'s Swing. RASQ moderators will review it.';
  }

  @override
  String get swingReported => 'Reported. It will be reviewed';

  @override
  String swingReportFailed(String error) {
    return 'Couldn\'t report: $error';
  }

  @override
  String get swingDeleteTitle => 'Delete Swing';

  @override
  String get swingDeleteMessage =>
      'This deletes this Swing and its replies. This can\'t be undone.';

  @override
  String get swingDeleteConfirm => 'Delete';

  @override
  String get swingCancel => 'Cancel';

  @override
  String swingDeleteFailed(String error) {
    return 'Couldn\'t delete: $error';
  }

  @override
  String get swingDeleted => 'Swing deleted';

  @override
  String get swingViewerEmptyMine => 'You have no active Swings';

  @override
  String get swingViewerEmptyMineHint => 'Swipe ＋ up to create a Swing';

  @override
  String get swingViewerEmpty => 'No Swings';

  @override
  String get swingViewerEmptyHint =>
      'Swings from people you follow and people who added you to a RASQ list appear here';

  @override
  String get swingClose => 'Close';

  @override
  String swingRemainingHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours left',
      one: '1 hour left',
    );
    return '$_temp0';
  }

  @override
  String swingRemainingMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes left',
      one: '1 minute left',
    );
    return '$_temp0';
  }

  @override
  String get swingRemainingSoon => 'Disappearing soon';

  @override
  String swingRemainingAndPosition(String remaining, String position) {
    return '$remaining · $position';
  }

  @override
  String swingViewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count viewers',
      one: '1 viewer',
    );
    return '$_temp0';
  }

  @override
  String get swingReport => 'Report';

  @override
  String get swingMenu => 'Menu';

  @override
  String get swingDelete => 'Delete';

  @override
  String get swingSensitive => 'Sensitive content';

  @override
  String get swingReveal => 'Show';

  @override
  String swingPluginJoinNote(String name) {
    return 'Everyone joins $name\'s page together. It runs without installing, only while you view this Swing.';
  }

  @override
  String get swingPluginJoin => 'Join';

  @override
  String get swingPluginConsent =>
      'This plugin hasn\'t been reviewed. It runs without network access, only while you view this Swing.';

  @override
  String get swingPluginConsentDetail =>
      'Restricted mode (network / storage.unsafe / interstitial and system FOW / opening URLs etc. are blocked; GPU is allowed). A single plugin with no child plugins.';

  @override
  String get swingPluginRun => 'Run';

  @override
  String swingPluginNeedsInstall(String name) {
    return 'Install $name to view';
  }

  @override
  String get swingPluginNeedsInstallHint =>
      'This is a plugin Swing. Install it from the Store';

  @override
  String get swingViewInStore => 'View in Store';

  @override
  String get swingPluginOpenFailed => 'Couldn\'t open';

  @override
  String get swingPluginTapToExpand => 'Tap to return to full screen';

  @override
  String get swingPluginSwipeHint =>
      'Swipe left/right or up/down for the next Swing';

  @override
  String get swingPluginShrink => 'Exit full screen';

  @override
  String get swingAd => 'Ad';

  @override
  String get swingAdSwipeHint => 'Swipe for the next Swing';

  @override
  String get swingKindText => 'Text';

  @override
  String get swingKindImage => 'Image';

  @override
  String get swingKindVideo => 'Video';

  @override
  String get swingKindPlugin => 'Plugin';

  @override
  String swingKindSwing(String kind) {
    return '$kind Swing';
  }

  @override
  String swingBannerNew(int count) {
    return 'New $count';
  }

  @override
  String swingBannerTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get swingComposerPluginShared =>
      'Shared use: viewers join the same page you create';

  @override
  String get swingComposerPluginFullscreen =>
      'Runs full screen on the viewer\'s device';

  @override
  String get swingComposerPluginPage =>
      'Runs as a page on the viewer\'s device';

  @override
  String swingTtlLabel(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Disappears in $hours hours',
      one: 'Disappears in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String get swingTtl => 'Disappears after';

  @override
  String swingTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String get swingBackgroundImage => 'Use an image as background';

  @override
  String get swingBackgroundVideo => 'Use a video as background';

  @override
  String get swingPickVideoFile => 'Please choose a video file';

  @override
  String get swingPickImageFile => 'Please choose an image file';

  @override
  String get swingChangeBackground => 'Change background';

  @override
  String get swingAudience => 'Audience';

  @override
  String get swingLoadFailedShort => 'Couldn\'t load';

  @override
  String swingSent(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'disappears in $hours hours',
      one: 'disappears in 1 hour',
    );
    return 'Swing posted ($_temp0)';
  }

  @override
  String get swingErrorLimit => 'You can have up to 20 Swings out at once';

  @override
  String swingSendFailed(String error) {
    return 'Couldn\'t post: $error';
  }

  @override
  String get swingComposerTitle => 'Create a Swing';

  @override
  String get swingNext => 'Next';

  @override
  String get swingSend => 'Post';

  @override
  String get swingNeedsAccount => 'A RASQ account is required';

  @override
  String get swingNeedsAccountHint =>
      'Swings are posted from your RASQ account. Log in from the sidebar';

  @override
  String swingUnreviewed(String name) {
    return '$name (unreviewed)';
  }

  @override
  String swingTtlRemaining(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: 'Disappears in $hours hours',
      one: 'Disappears in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String get swingRepick => 'Choose again';

  @override
  String get swingReedit => 'Edit again';

  @override
  String swingCwTooLong(int max) {
    return 'CW can be up to $max characters';
  }

  @override
  String get swingCwHint => 'CW text';

  @override
  String get swingCwOff => 'Remove CW';

  @override
  String get swingCwOn => 'Add CW (sensitive content)';

  @override
  String get swingPluginSection => 'Plugin to share';

  @override
  String get swingPluginNone =>
      'No custom plugins that can be shared via Swing are installed. Install one from the Store, or share your own plugin with \"From file\" below.';

  @override
  String get swingPluginNoneDetail =>
      'Page-type (custom) plugins that have no parent/child relationship with other plugins (either solo or shared).';

  @override
  String get swingFromFile => 'From file (unreviewed)';

  @override
  String get swingFromFileSubtitle =>
      'Share a .rspkg / .rasqpkg / .wasm you made';

  @override
  String get swingFromFileDetail =>
      'Unreviewed plugins run without network access on the viewer\'s device (GPU is available). Child plugins built on other plugins can\'t be shared.';

  @override
  String get swingAudienceEmpty => 'Choose at least one audience';

  @override
  String get swingAudienceFollowers => 'Followers';

  @override
  String get swingAudienceFollowersSubtitle =>
      'People who follow your RASQ account';

  @override
  String get swingAudienceList => 'RASQ list';

  @override
  String get swingAudienceNoLists =>
      'Create a RASQ list to also reach the people in it';

  @override
  String swingPackageFetchFailed(int status) {
    return 'Couldn\'t get the plugin (HTTP $status)';
  }

  @override
  String get swingNotLoggedIn => 'Not logged in to a RASQ account';

  @override
  String get swingUnreadable => 'Couldn\'t read the Swing';

  @override
  String themeNotAThemePack(String id) {
    return 'Not a theme pack: $id';
  }

  @override
  String get themePickerLabel => 'Theme (.rspkg / .rasqpkg)';

  @override
  String themeNotATheme(String id, String kind) {
    return 'Not a theme (kind: theme): $id ($kind)';
  }

  @override
  String themeLoadFailed(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String get themeTitle => 'Fonts and color scheme';

  @override
  String get themeCaption =>
      'Change colors, icons and backgrounds. Only one can be used at a time';

  @override
  String get themeCaptionDetail =>
      'A theme is a pack that changes colors, icons, and the backgrounds of screens / post tiles / FOW / buttons. It doesn\'t run code. Only one can be used at a time.';

  @override
  String get themeColorScheme => 'Color scheme';

  @override
  String get themeModeSystem => 'Use system setting';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get themePacks => 'Themes';

  @override
  String get themeNone => 'No theme (default)';

  @override
  String get themeDarkOnly => 'Applies in dark mode';

  @override
  String get themeLightOnly => 'Applies in light mode';

  @override
  String get themeSideloaded => 'Loaded from file (not reviewed)';

  @override
  String get themeSeparator => ' · ';

  @override
  String get themeRemove => 'Delete';

  @override
  String themeDarkOnlyNotice(String name) {
    return '\"$name\" applies in dark mode. You\'re currently in light mode.';
  }

  @override
  String themeLightOnlyNotice(String name) {
    return '\"$name\" applies in light mode. You\'re currently in dark mode.';
  }

  @override
  String get themeSwitchToDark => 'Switch to dark mode';

  @override
  String get themeSwitchToLight => 'Switch to light mode';

  @override
  String get themeEmpty => 'No themes installed yet.';

  @override
  String get themeFindInStore => 'Find themes in the Store';

  @override
  String get themeImport => 'Load from file (.rspkg / .rasqpkg)';

  @override
  String get themeImportSubtitle => 'Load a theme you made yourself';

  @override
  String get themeImportDetail =>
      'A theme pack built with rasq build. It contains no code, so it can be used as is even without review';

  @override
  String get trendTitle => 'Trends';

  @override
  String get trendTabNotes => 'Notes';

  @override
  String get trendTabFollowing => 'Following';

  @override
  String get trendTabUsers => 'Users';

  @override
  String get trendBackToHome => 'Back to trend home';

  @override
  String get trendSourceAccountMark => 'Account that provided this trend';

  @override
  String get trendSettingsTooltip => 'Trend settings';

  @override
  String get trendCustomizeTooltip => 'Customize trend timeline';

  @override
  String get trendReload => 'Reload';

  @override
  String get trendEmptyTitle => 'Nothing here';

  @override
  String get trendEmptyHint => 'Try changing the words or filters';

  @override
  String get trendFollowingEmptyTitle => 'No posts from people you follow';

  @override
  String get trendFollowingEmptyHint =>
      'No one you follow has posted about this word yet';

  @override
  String get trendUsersBlocked => 'Your guardian has turned off user search';

  @override
  String get trendUsersEmpty => 'No users';

  @override
  String trendUserReactions(int count) {
    return '$count reactions';
  }

  @override
  String get trendMenuOpenAs => 'Open with another account';

  @override
  String get trendMenuReport => 'Report';

  @override
  String trendMenuAccountSourced(String account) {
    return '$account (account that provided this trend)';
  }

  @override
  String get trendReportTitle => 'Report';

  @override
  String trendReportMessage(String tag) {
    return 'Report the trend \"$tag\". RASQ moderators will review it. Reported trends no longer appear in the trend list.';
  }

  @override
  String trendReportMessageWithServer(String tag, String server) {
    return 'Report the trend \"$tag\" ($server). RASQ moderators will review it. Reported trends no longer appear in the trend list.';
  }

  @override
  String get trendReportNoteHint => 'Note (optional)';

  @override
  String get trendReportSend => 'Report';

  @override
  String get trendReportSent => 'Reported. RASQ moderators will review it';

  @override
  String get trendReportStored =>
      'Saved on this device. It will be sent once you\'re connected to your RASQ account';

  @override
  String get trendReportFailed =>
      'Couldn\'t send, so it was saved on this device (it will be resent later)';

  @override
  String get trendReportUnhide => 'Show again';

  @override
  String get trendPluginFallbackName => 'Trend plugin';

  @override
  String get trendPluginLoadFailed => 'Couldn\'t load';

  @override
  String get trendPluginNoWords => 'No candidate words yet';

  @override
  String trendPluginWordQuoted(String word) {
    return '\"$word\"';
  }

  @override
  String trendPluginTodayEmpty(String words) {
    return 'No posts about $words yet';
  }

  @override
  String trendPluginTodayHeading(String words) {
    return 'Posts about $words';
  }

  @override
  String get trendEmotionJoy => 'Joy';

  @override
  String get trendEmotionTrust => 'Trust';

  @override
  String get trendEmotionFear => 'Fear';

  @override
  String get trendEmotionSurprise => 'Surprise';

  @override
  String get trendEmotionSadness => 'Sadness';

  @override
  String get trendEmotionDisgust => 'Disgust';

  @override
  String get trendEmotionAnger => 'Anger';

  @override
  String get trendEmotionAnticipation => 'Anticipation';

  @override
  String get trendExamplesNoCandidates => 'No candidates';

  @override
  String get trendExamplesAllow => 'Like';

  @override
  String get trendExamplesDeny => 'Not for me';

  @override
  String get trendExamplesDecide => 'Done';

  @override
  String trendExamplesLoadFailed(String source, String error) {
    return 'Couldn\'t load $source: $error';
  }

  @override
  String get trendExamplesAllSeen => 'You\'ve seen them all';

  @override
  String trendExamplesAllSeenHint(
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
  ) {
    return '$allowLabel $allow / $denyLabel $deny. Tap Done to save';
  }

  @override
  String trendExamplesIntro(String allowLabel, String denyLabel) {
    return 'Look at each item and mark it as an example with \"$allowLabel\" / \"$denyLabel\" below (or swipe right / left). New items are sorted by how close they are to your examples.';
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
      other: '$remaining left',
      one: '1 left',
    );
    return '$intro ($allowLabel $allow / $denyLabel $deny · $_temp0)';
  }

  @override
  String get trendExamplesSearch => 'Search';

  @override
  String get trendExamplesSkip => 'Skip';

  @override
  String trendExamplesMorePosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
    );
    return '+$_temp0';
  }

  @override
  String get trendExamplesPostsUnreadable =>
      'Couldn\'t read the posts (comparing by name and description)';

  @override
  String trendExamplesOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more',
      one: 'and 1 more',
    );
    return '$_temp0';
  }

  @override
  String get trendExamplesSourceActions => 'Recent actions';

  @override
  String get trendExamplesSourceActionsEmpty => 'No recent actions';

  @override
  String get trendExamplesSourceActionsEmptyHint =>
      'React to or bookmark posts to pick from them here';

  @override
  String get trendExamplesSourcePlugins => 'Plugins';

  @override
  String get trendExamplesSourcePluginsEmpty => 'No plugins installed';

  @override
  String get trendExamplesSourceClips => 'Clips';

  @override
  String get trendExamplesSourceClipsEmpty => 'No clips';

  @override
  String get trendExamplesSourceLists => 'Lists';

  @override
  String get trendExamplesSourceListsEmpty => 'No lists';

  @override
  String get trendExamplesSourceStore => 'Store';

  @override
  String get trendExamplesSourceStoreHint =>
      'Search the Store (empty = browse all)';

  @override
  String get trendExamplesSourceStoreEmpty => 'No results';

  @override
  String get trendExamplesKindPlugin => 'Plugin';

  @override
  String get trendExamplesKindClip => 'Clip';

  @override
  String get trendExamplesKindList => 'List';

  @override
  String get trendExamplesKindPost => 'Post';

  @override
  String get trendExamplesKindText => 'Text';

  @override
  String get trendProfileSheetTitle => 'Trend profile settings';

  @override
  String get trendProfileClose => 'Close';

  @override
  String get trendProfileDecide => 'Done';

  @override
  String get trendProfileGenres => 'Favorite genres/directions';

  @override
  String get trendProfileGenresSnsDefault =>
      'Favorite genres/directions (leave it to the SNS)';

  @override
  String get trendProfileGenresAuto =>
      'Favorite genres/directions (auto-extracted from your actions)';

  @override
  String get trendProfileAddGenrePill => '+ Add genre';

  @override
  String get trendProfileEdit => 'Edit';

  @override
  String get trendProfileTendencyTitle => 'Trend orientation/intensity';

  @override
  String trendProfileTendencySummary(String directivity, String stimulus) {
    return 'Orientation $directivity · Intensity $stimulus';
  }

  @override
  String get trendProfilePluginsTitle => 'Trend plugin settings';

  @override
  String get trendProfilePluginsSubtitle =>
      'Timeline nodes / search suggestions';

  @override
  String get trendProfilePluginsDetail =>
      'trend.suggest plugins. Shown in the timeline customization nodes (Get trends / Today / Custom) and search suggestions';

  @override
  String get trendProfileCacheNetworkTitle => 'Cache network settings';

  @override
  String get trendProfileComingSoon => 'Coming soon';

  @override
  String get trendProfileAlgorithmTitle => 'Edit algorithm (nodes)';

  @override
  String get trendProfileAlgorithmSubtitle =>
      'Edit how trends are collected and ordered';

  @override
  String get trendProfileAlgorithmDetail =>
      'The chain for fetching and sorting trends (the ml.tendency node can use this profile)';

  @override
  String get trendProfileSharedCaption =>
      'These settings are shared by the Recommended / Trends / Related timelines.';

  @override
  String get trendProfileSharedCaptionDetail =>
      'This profile is saved in storage.safe (trend.profile) and is read by the defaults of the Recommended / Trends / Related timelines and by the \"Orientation/Intensity\" node in the node editor.';

  @override
  String get trendProfileDirNarrow => 'Narrow';

  @override
  String get trendProfileDirWide => 'Wide';

  @override
  String get trendProfileDirNormal => 'Normal';

  @override
  String get trendProfileStimNone => 'No limit';

  @override
  String trendProfileStimCapped(String emotions) {
    return 'Tone down $emotions';
  }

  @override
  String get trendProfileListSeparator => ', ';

  @override
  String get trendProfileDirectivityTitle => 'Trend orientation';

  @override
  String get trendProfileDirectivitySubtitle =>
      'The narrower it is, the fewer posts outside your favorite genres are shown.';

  @override
  String get trendProfileDirectivityDetail =>
      'Threshold for closeness to your favorite genres/directions (narrow ⇄ wide). The narrower, the more off-topic posts are dropped.';

  @override
  String get trendProfileShareTitle => 'Share settings';

  @override
  String get trendProfileShareSubtitle =>
      'Use these settings for the Recommended / Trends / Related timelines';

  @override
  String get trendProfileShareDetail =>
      'Turning this off stops applying it as the timeline default (anything set explicitly in nodes still applies)';

  @override
  String get trendProfileStimulusTitle => 'Trend intensity';

  @override
  String get trendProfileStimulusCaption =>
      'Upper limit for each emotion. The closer to the center, the more it\'s toned down';

  @override
  String get trendProfileStimulusReset => 'Reset intensity';

  @override
  String get trendProfileEchoChamberWarning =>
      'Strengthening trend orientation/intensity may make you more susceptible to echo-chamber effects.';

  @override
  String get trendProfileStimulusEstimate =>
      'Intensity is currently estimated from word tendencies.';

  @override
  String get trendProfileStimulusEstimateDetail =>
      'Intensity is estimated with vocabulary rules.';

  @override
  String get trendProfileTendencySaved => 'Saved trend orientation/intensity';

  @override
  String get trendProfileSnsDefaultTitle => 'Leave it to the SNS';

  @override
  String get trendProfileSnsDefaultSubtitle =>
      'While on, the device doesn\'t filter';

  @override
  String get trendProfileAutoGenreTitle => 'Auto-extract from your actions';

  @override
  String get trendProfileAutoGenreSubtitle =>
      'Adds keywords from posts you reacted to as favorite genres';

  @override
  String get trendProfilePickFromActions =>
      'Pick favorites from recent actions';

  @override
  String get trendProfileGenresTapToRemove =>
      'Favorite genres/directions (tap to remove)';

  @override
  String get trendProfileNoneYet => 'None yet';

  @override
  String get trendProfileAddGenreHint => 'Add a genre/keyword';

  @override
  String get trendProfileAddGenre => 'Add genre';

  @override
  String trendProfileExamplesLabel(int allow, int deny) {
    return 'Examples (liked $allow / not liked $deny; tap to remove)';
  }

  @override
  String trendProfileExampleAllow(String label) {
    return 'Like: $label';
  }

  @override
  String trendProfileExampleDeny(String label) {
    return 'Don\'t like: $label';
  }

  @override
  String get trendProfileDislikedTapToRemove => 'Not liked (tap to remove)';

  @override
  String get trendProfileGenresSaved => 'Saved favorite genres/directions';

  @override
  String get trendProfilePickTitle => 'Pick genres from actions';

  @override
  String get trendProfilePickIntro =>
      'Your recent actions are grouped by topic. Select cards and move them to \"Like\" / \"Not for me\" (or swipe right/left).';

  @override
  String trendProfilePickIntroDetail(int perPage) {
    String _temp0 = intl.Intl.pluralLogic(
      perPage,
      locale: localeName,
      other: '$perPage at a time',
      one: '1 at a time',
    );
    return 'Recent actions are grouped into similar topics and shown $_temp0, starting with the most topical (also from plugins / clips / lists via the chips above). Tap cards to select them, choose a candidate genre, then tap \"Like\" / \"Not for me\" below (or swipe right/left).';
  }

  @override
  String userPageViewTitle(String tab) {
    return '$tab view';
  }

  @override
  String get userPageViewClose => 'Close';

  @override
  String userPageViewSearchHint(String tab) {
    return 'Search this user\'s $tab';
  }

  @override
  String get userPageViewSortLabel => 'Sort';

  @override
  String get userPageViewSortNewest => 'Newest first';

  @override
  String get userPageViewSortOldest => 'Oldest first';

  @override
  String get userPageViewSortReactions => 'Reactions';

  @override
  String get userPageViewSortTendency => 'Best match for your tendency';

  @override
  String get userPageViewShowLabel => 'Show';

  @override
  String get userPageViewShowPinned => 'Pinned';

  @override
  String get userPageViewShowRenotes => 'Renotes';

  @override
  String get userPageViewShowQuotes => 'Quote notes';

  @override
  String get userPageViewShowDigest => 'Digest';

  @override
  String get userPageViewTendencyLabel => 'Orientation / Intensity';

  @override
  String get userPageViewDirectivityTitle => 'Orientation';

  @override
  String get userPageViewDirectivityNoGenres =>
      'Works once you set your favorite genres';

  @override
  String get userPageViewStimulusTitle => 'Intensity';

  @override
  String get userPageViewReset => 'Reset';

  @override
  String userPageViewCount(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$shown of $total',
      one: '$shown of 1',
    );
    return '$_temp0';
  }

  @override
  String get userPageViewEmptyTitle => 'No posts match';

  @override
  String get userPageViewEmptyHint =>
      'Tap the tab again to change or reset the view settings';

  @override
  String get usersImageViewerBack => 'Back';

  @override
  String get usersFollowRequestsTabRelevance => 'Relevance';

  @override
  String get usersFollowRequestsTabFollowing => 'Following';

  @override
  String get usersFollowRequestsTabOther => 'Other';

  @override
  String get usersFollowRequestsTitle => 'Follow requests';

  @override
  String get usersReload => 'Reload';

  @override
  String get usersFollowRequestsEmpty => 'No follow requests';

  @override
  String get usersFollowRequestsEmptyOther => 'None';

  @override
  String get usersFollowRequestAccept => 'Accept';

  @override
  String get usersFollowRequestReject => 'Reject';

  @override
  String get usersFollowsTabFollowing => 'Following';

  @override
  String get usersFollowsTabFollowers => 'Followers';

  @override
  String get usersFollowsTitle => 'Following/Followers';

  @override
  String get usersFollowersEmpty => 'No followers';

  @override
  String get usersFollowingEmpty => 'Not following anyone';

  @override
  String get usersPageTabNotes => 'Notes';

  @override
  String get usersPageTabReplies => 'Replies';

  @override
  String get usersPageTabQuotes => 'Quotes';

  @override
  String get usersPageTabMedia => 'Media';

  @override
  String get usersPageTabClips => 'Clips/Play';

  @override
  String get usersRestrictedTitle => 'This user is restricted';

  @override
  String get usersRestrictedHint => 'Tap \"Show\" to view the content';

  @override
  String get usersMenuCopyLink => 'Copy link';

  @override
  String get usersMenuAddToRasqList => 'Add to RASQ list';

  @override
  String get usersMenuServerInfo => 'Server info';

  @override
  String get usersMenuUnmute => 'Unmute';

  @override
  String get usersMenuMute => 'Mute';

  @override
  String get usersMenuUnblock => 'Unblock';

  @override
  String get usersMenuBlock => 'Block';

  @override
  String get usersMenuReport => 'Report';

  @override
  String usersBlockConfirmTitle(String name) {
    return 'Block $name?';
  }

  @override
  String get usersBlockConfirmMessage =>
      'You\'ll no longer receive follows, reactions, or replies from them.';

  @override
  String get usersCancel => 'Cancel';

  @override
  String usersReportConfirmTitle(String name) {
    return 'Report $name?';
  }

  @override
  String get usersReportConfirmMessage =>
      'It will be reported to the server admins.';

  @override
  String get usersPostsEmpty => 'No posts';

  @override
  String get usersPinnedBadge => 'Pinned';

  @override
  String get usersClipsUnsupportedTitle => 'Clips / Play';

  @override
  String get usersClipsUnsupportedHint =>
      'This SNS doesn\'t support clips or Play';

  @override
  String get usersClipsEmpty => 'No public clips or Play';

  @override
  String get usersClipsHeader => 'Clips';

  @override
  String usersClipNoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notes',
      one: '1 note',
    );
    return '$_temp0';
  }

  @override
  String get usersClipSubtitleSeparator => ' · ';

  @override
  String get usersNotFound => 'This user doesn\'t seem to exist.';

  @override
  String get vcSectionInvited => 'Invited';

  @override
  String get vcSectionRecommended => 'Recommended';

  @override
  String get vcSectionUpcoming => 'Upcoming';

  @override
  String get vcSectionTrending => 'Trending';

  @override
  String get vcSectionFollowing => 'Following';

  @override
  String vcSectionSettingsTooltip(String title) {
    return '$title settings';
  }

  @override
  String get vcSearchHint => 'Search ASTell / Swing';

  @override
  String get vcSearchRefineHint => 'Narrow down further';

  @override
  String vcSearchTermChip(String term) {
    return '\"$term\" ×';
  }

  @override
  String get vcSearchClear => 'Clear';

  @override
  String get vcCreateTooltip => 'Create ASTell';

  @override
  String get vcHomeLoadError => 'Couldn\'t load ASTell';

  @override
  String vcJoinedRoom(String title) {
    return 'Joined: $title';
  }

  @override
  String vcJoinedPeers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people · Tap to open',
      one: '1 person · Tap to open',
    );
    return '$_temp0';
  }

  @override
  String get vcConnecting => 'Connecting…';

  @override
  String vcInvitedBy(String name) {
    return 'Invited by $name · Tap to view';
  }

  @override
  String get vcInviteDecline => 'Decline';

  @override
  String get vcRecommendedEmpty => 'No recommended ASTell yet';

  @override
  String get vcTrendingEmpty => 'No trending ASTell yet';

  @override
  String get vcFollowingEmpty => 'No ASTell from people you follow';

  @override
  String get vcSearchNoResults => 'No results';

  @override
  String get vcSearchNoResultsInSection => 'Nothing in this section';

  @override
  String vcSearchNoResultsFor(String query) {
    return 'No ASTell / Swing matches \"$query\"';
  }

  @override
  String get vcTileOpen => 'Take a look';

  @override
  String get vcBookmarkRemove => 'Remove from bookmarks';

  @override
  String get vcBookmarkSave => 'Save to bookmarks';

  @override
  String get vcRemindCancel => 'Turn off start notification';

  @override
  String get vcRemindSet => 'Notify me when it starts';

  @override
  String get vcMenuTooltip => 'Menu';

  @override
  String vcScheduledAt(String when) {
    return 'Scheduled $when';
  }

  @override
  String get vcSummaryPrivate => 'The quick summary is private.';

  @override
  String get vcTileStripEmpty => 'No ASTell yet';

  @override
  String get vcLinkCopied => 'Link copied';

  @override
  String get vcBookmarkSaved => 'Saved to bookmarks';

  @override
  String get vcBookmarkRemoved => 'Removed from bookmarks';

  @override
  String vcRemindRegistered(String when) {
    return 'You\'ll be notified at $when';
  }

  @override
  String get vcRemindRemoved => 'Notification turned off';

  @override
  String get vcRemindUnavailable =>
      'Couldn\'t set a notification on this device';

  @override
  String get vcRemindNotScheduled => 'This room has no scheduled time';

  @override
  String get vcMenuShareAsPost => 'Share as a post';

  @override
  String get vcMenuCopyLink => 'Copy link';

  @override
  String get vcMenuStartNow => 'Start now';

  @override
  String get vcMenuBackToRoom => 'Back to room';

  @override
  String get vcMenuJoin => 'Join';

  @override
  String get vcMenuClose => 'End';

  @override
  String get vcMenuUnfollowHost => 'Unfollow host';

  @override
  String get vcMenuFollowHost => 'Follow host';

  @override
  String get vcMenuMute => 'Mute';

  @override
  String get vcMenuReport => 'Report';

  @override
  String vcUnfollowed(String name) {
    return 'Unfollowed $name';
  }

  @override
  String vcFollowed(String name) {
    return 'Followed $name';
  }

  @override
  String vcReportWhatRoom(String title) {
    return 'the room \"$title\"';
  }

  @override
  String vcMenuNotYet(String title, String action) {
    return 'The \"$title\" action ($action) is coming in late M5';
  }

  @override
  String get vcCloseRoomTitle => 'End room';

  @override
  String vcCloseScheduledBody(String title) {
    return 'Cancel the scheduled \"$title\". People who bookmarked it or set a start notification won\'t be notified.';
  }

  @override
  String vcCloseRoomBody(String title) {
    return 'End \"$title\". Members currently in the room will leave.';
  }

  @override
  String vcClosedScheduled(String title) {
    return 'Canceled the scheduled \"$title\"';
  }

  @override
  String vcClosedRoom(String title) {
    return 'Ended \"$title\"';
  }

  @override
  String vcCloseFailed(String error) {
    return 'Couldn\'t end: $error';
  }

  @override
  String get vcTileBack => 'Back';

  @override
  String get vcReminderNotificationTitle => 'A bookmarked ASTell is starting!';

  @override
  String vcReminderNotificationBody(String host, String title) {
    return '\"$title\" by $host';
  }

  @override
  String vcShareTextScheduled(String title, String when) {
    return '\"$title\" will be held at $when';
  }

  @override
  String vcShareTextOpen(String title) {
    return '\"$title\" is live now';
  }

  @override
  String get vcViewerPluginsTooltip => 'Full-screen plugins (coming soon)';

  @override
  String vcViewerSharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String get vcViewerSave => 'Save';

  @override
  String get vcViewerSaveNotYet => 'Saving is coming soon';

  @override
  String get vcViewerShare => 'Share';

  @override
  String get vcViewerShareNotYet => 'Sharing is coming soon';

  @override
  String get vcBarSpeaker => 'Speaker';

  @override
  String get vcBarMic => 'Mic';

  @override
  String get vcBarScreen => 'Screen share';

  @override
  String get vcBarFullscreen =>
      'Full screen (when the share frame has a screen)';

  @override
  String get vcBarCaptions => 'Captions (transcription)';

  @override
  String vcCallConnectFailed(String error) {
    return 'Couldn\'t connect the call: $error';
  }

  @override
  String get vcOpenNotFound =>
      'This room can\'t be found (it may have ended, or the link may be wrong)';

  @override
  String get vcOpenFailed => 'Couldn\'t open the room';

  @override
  String get vcOpenGoHome => 'Go to ASTell home';

  @override
  String vcOpenHost(String name, String handle) {
    return 'Host: $name (@$handle)';
  }

  @override
  String get vcOpenRoom => 'Open room';

  @override
  String get vcShareBlockDirect => 'Direct posts can\'t be shared to ASTell';

  @override
  String get vcShareBlockLocalOnly =>
      'Local-only posts can\'t be shared to ASTell';

  @override
  String get vcShareBlockUnknownVisibility =>
      'Posts with unknown visibility can\'t be shared to ASTell';

  @override
  String get vcShareBlockLimited =>
      'Posts with limited visibility can\'t be shared to ASTell';

  @override
  String get vcShares => 'Shares';

  @override
  String vcSharesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shares ($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcSharesShowAll => 'See all shares';

  @override
  String get vcSharesEmpty => 'Things you 📌 in the chat appear here.';

  @override
  String get vcShareActions => 'Share actions';

  @override
  String get vcShareTranscriptSource => 'RASQ · Transcript';

  @override
  String get vcUnpin => 'Unpin';

  @override
  String get vcYou => 'You';

  @override
  String get vcNoDescription => 'No description.';

  @override
  String get vcReportReasonSpam => 'Spam';

  @override
  String get vcReportReasonHarassment => 'Harassment / abusive language';

  @override
  String get vcReportReasonIllegal => 'Illegal / dangerous content';

  @override
  String get vcReportReasonOther => 'Other';

  @override
  String get vcJoinPolicyAnyone => 'Anyone';

  @override
  String get vcJoinPolicyAnyoneHint => 'Anyone can join a public room';

  @override
  String get vcJoinPolicyFollowers => 'Followers only';

  @override
  String get vcJoinPolicyFollowersHint =>
      'People who follow you (the host) with a RASQ account';

  @override
  String get vcJoinPolicyFollowing => 'People you follow only';

  @override
  String get vcJoinPolicyFollowingHint => 'People you follow';

  @override
  String get vcJoinPolicyMutual => 'Mutual follows only';

  @override
  String get vcJoinPolicyMutualHint => 'People who follow each other with you';

  @override
  String get vcSharePolicyEveryone => 'Everyone';

  @override
  String get vcSharePolicyModerators => 'Moderators only';

  @override
  String vcShareContentWarning(String warning) {
    return '⚠ $warning (sensitive)';
  }

  @override
  String vcSharePluginWant(String name) {
    return 'I want to use \"$name\"';
  }

  @override
  String get vcKindPost => 'Post';

  @override
  String get vcKindMedia => 'Media';

  @override
  String get vcKindVideo => 'Video';

  @override
  String get vcKindLink => 'Link';

  @override
  String get vcKindText => 'Text';

  @override
  String get vcKindPlugin => 'Plugin';

  @override
  String get vcMediaInsecureContext =>
      'Calls on the Web version only work when opened over https';

  @override
  String get vcMediaPermissionDenied =>
      'No microphone (camera) permission. Allow it in your device settings';

  @override
  String get vcMediaNoDevice => 'No microphone (camera) found';

  @override
  String get vcMediaUnsupported => 'Not available on this device';

  @override
  String vcMediaUnsupportedDetail(String detail) {
    return 'Not available on this device ($detail)';
  }

  @override
  String get vcMediaMicClosed =>
      'Can\'t open the mic for a call that has ended';

  @override
  String get vcStreamNotConnected => 'Not connected to the streaming server';

  @override
  String get vcStreamPublishFailed =>
      'Couldn\'t send video to the streaming server';

  @override
  String get vcScreenSharingNotification => 'Sharing your screen';

  @override
  String get vcScreenPickTitle => 'Choose a screen to share';

  @override
  String get vcScreenPickScreen => 'Entire screen';

  @override
  String get vcScreenPickWindow => 'Window';

  @override
  String get vcScreenPickCancel => 'Cancel';

  @override
  String get vcScreenPickShare => 'Share';

  @override
  String get vcNoticeAudioBlocked =>
      'Audio is paused. Tap the screen to play sound';

  @override
  String vcNoticeCallFull(int cap) {
    return 'The call is full (up to $cap people). If there\'s a stream, you can listen there';
  }

  @override
  String get vcNoticeHoldWaiting =>
      'Please wait until it starts. Playing hold music';

  @override
  String get vcNoticeStarted => 'It has started';

  @override
  String get vcNoticeHoldIdle => 'It\'s quiet, so hold music is playing';

  @override
  String get vcShareClassImage => 'Image';

  @override
  String get vcShareClassFile => 'File';

  @override
  String get vcShareClassTranscript => 'Transcript';

  @override
  String get vcShareStyleCards => 'Cards (horizontal scroll)';

  @override
  String get vcShareStyleList => 'List (legacy)';

  @override
  String get vcTermsRequired =>
      'You need to agree to the Terms of Service (you can agree from the notice at the top of ASTell)';

  @override
  String get vcClosedByModeration => 'The room was closed by the moderators';

  @override
  String get vcClosedByHost => 'The host ended the room';

  @override
  String get vcKickedBanned => 'You\'ve been banned from this room';

  @override
  String get vcKickedSanctioned =>
      'You were removed due to an action on your account';

  @override
  String get vcKickedByModerator => 'A moderator removed you from the room';

  @override
  String vcShareHeld(String seconds) {
    return 'Under review: it will be judged and delivered in $seconds seconds (account action)';
  }

  @override
  String vcShareRejected(String source) {
    return 'Rejected in review ($source). This message was not delivered';
  }

  @override
  String get vcNotInRoom => 'You\'re not in the room';

  @override
  String vcStreamReceiveFailed(String error) {
    return 'Can\'t receive video: $error';
  }

  @override
  String get vcStreamBlockedByScreenShare =>
      'Can\'t start streaming while screen sharing (stop sharing first)';

  @override
  String vcStreamStartFailed(String error) {
    return 'Can\'t start streaming: $error';
  }

  @override
  String vcStreamClearFailed(String error) {
    return 'Couldn\'t clear the streaming indicator: $error';
  }

  @override
  String get vcScreenShareBlockedByStream =>
      'Can\'t start screen sharing while streaming (stop streaming first)';

  @override
  String vcScreenShareStartFailed(String error) {
    return 'Can\'t start screen sharing: $error';
  }

  @override
  String get vcStreamUnavailable =>
      'Streaming isn\'t available yet (no streaming server configured)';

  @override
  String vcStreamForbidden(String message) {
    return 'Not allowed ($message)';
  }

  @override
  String get vcTtsNotConfigured =>
      'No text-to-speech backend is configured (CENTRAL_TTS_URL)';

  @override
  String get vcLoginRequired => 'Please log in to your RASQ account';

  @override
  String vcCreateUninvite(String name) {
    return 'Cancel invite for $name';
  }

  @override
  String vcCreateInvite(String name) {
    return 'Invite $name';
  }

  @override
  String get vcCreateCancel => 'Cancel';

  @override
  String get vcCreateShareAfterOn => 'Share in a post after creating (on)';

  @override
  String get vcCreateShareAfter => 'Share in a post after creating';

  @override
  String vcCreateScheduled(String title, String when) {
    return 'Scheduled \"$title\" for $when';
  }

  @override
  String get vcCreateScheduleInPast =>
      'The scheduled time must be in the future';

  @override
  String vcCreateGenresMax(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'You can add up to $max genres',
      one: 'You can add up to 1 genre',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateTitleRequired => 'Enter a title';

  @override
  String vcCreateInviteFailed(String error) {
    return 'Couldn\'t send the invite: $error';
  }

  @override
  String vcCreateFailed(String error) {
    return 'Couldn\'t create: $error';
  }

  @override
  String get vcCreateSearchAdd => 'Search and add';

  @override
  String get vcCreateHandleHint => '@handle (RASQ account)';

  @override
  String vcCreateHandleNotFound(String handle) {
    return 'Not found: $handle';
  }

  @override
  String get vcCreateAddInvitee => 'Add to invites';

  @override
  String get vcCreateTitleHint => 'Title';

  @override
  String get vcCreateInviteFollowers => 'Invite followers';

  @override
  String vcCreateInviteFollowersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Invite followers ($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateWelcomeToggle => 'Show a welcome message when people join';

  @override
  String get vcCreateWelcomeHint => 'Set a welcome message..';

  @override
  String vcCreateGenresLabel(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'Choose genres (up to $max)',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateGenreHint => 'Enter a genre';

  @override
  String get vcCreateGenreAdd => 'Add genre';

  @override
  String get vcCreateSchedule => 'Schedule for later';

  @override
  String get vcCreateScheduleCaption =>
      'While scheduled, no one else can join until you enter.';

  @override
  String get vcCreateScheduleCaptionDetail =>
      'While scheduled, no one else can join until you (or a moderator) enter. People can sign up for a start notification from the Upcoming section and the share link.';

  @override
  String get vcCreateSummaryHint =>
      'Short summary (optional; generated automatically if empty)';

  @override
  String get vcCreateMicAfterCreate => 'Mic (switch after creating)';

  @override
  String get vcCreateScheduleButton => 'Schedule';

  @override
  String get vcCreateButton => 'Create';

  @override
  String get vcRoomHostPresent => 'In room';

  @override
  String get vcRoomHostBeforeStart => 'Not started';

  @override
  String get vcRoomHostAbsent => 'Away';

  @override
  String vcRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people are in the room',
      one: '1 person is in the room',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomMembersHostOnly => 'No one is here yet besides the host';

  @override
  String get vcRoomMembersNone => 'No one is here yet';

  @override
  String vcRoomMembersRest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '+$count more',
      one: '+1 more',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomScreenShown => 'Shown in share frame';

  @override
  String get vcRoomScreenShow => 'Show screen share';

  @override
  String vcRoomNotYet(String what) {
    return '$what is coming soon';
  }

  @override
  String get vcRoomDeviceSettingsTitle => 'ASTell settings (this device)';

  @override
  String get vcRoomEditBar => 'Edit bottom bar buttons';

  @override
  String get vcRoomEditBarSubtitle =>
      'Reorder / show / hide / add plugin buttons';

  @override
  String get vcRoomAutoShareLabel =>
      'Automatically show chat content in the shares area (even without pinning)';

  @override
  String get vcRoomShareStyleLabel => 'Shares area display';

  @override
  String get vcRoomAutoPlayLabel => 'Autoplay';

  @override
  String get vcRoomAutoPlayScreen =>
      'Show in the share frame when screen sharing starts';

  @override
  String get vcRoomHoldMusicLabel => 'Hold music';

  @override
  String get vcRoomHoldMusicDevice => 'Play hold music (this device)';

  @override
  String get vcRoomHoldMusicSourceLabel => 'Hold music source';

  @override
  String get vcRoomHoldMusicSourceAstronomies =>
      'We：Astronomies on the Blue Planet';

  @override
  String get vcRoomHoldMusicSourceClassic => 'Classic hold music';

  @override
  String get vcRoomHoldMusicVolume => 'Hold music volume';

  @override
  String vcRoomHoldMusicVolumeValue(int percent) {
    return '$percent%';
  }

  @override
  String get vcRoomDeviceSettingsCaption =>
      'Room settings can be changed from the room\'s gear after joining (owner).';

  @override
  String get vcRoomDeviceSettingsCaptionDetail =>
      'Per-room settings (who can join, text-to-speech, etc.) can be changed from the room\'s gear after joining (owner).';

  @override
  String get vcRoomClose => 'Close';

  @override
  String get vcRoomShare => 'Share';

  @override
  String get vcRoomHost => 'Host';

  @override
  String get vcRoomMembers => 'Members';

  @override
  String get vcRoomLocked => 'New entries have been stopped by the moderators.';

  @override
  String get vcRoomLockedDetail =>
      'New entries have been suspended by the moderators (D-151).';

  @override
  String get vcRoomRemindOn => 'You\'ll be notified when it starts';

  @override
  String get vcRoomWaitForHost => 'You can join once the host starts';

  @override
  String get vcRoomRemindOff => 'Turn off notification';

  @override
  String get vcRoomSummary => 'Quick summary';

  @override
  String get vcRoomSummaryPrivate =>
      'This room doesn\'t make its quick summary public.';

  @override
  String vcRoomWelcome(String message) {
    return 'Welcome: $message';
  }

  @override
  String get vcRoomMicAfterJoin => 'Mic (toggle after joining)';

  @override
  String get vcRoomCaptions => 'Captions';

  @override
  String get vcRoomJoin => 'Join';

  @override
  String get vcRoomSettings => 'Settings';

  @override
  String get vcRoomTabHome => 'Home';

  @override
  String get vcRoomTabChat => 'Chat';

  @override
  String get vcRoomTabToc => 'Contents';

  @override
  String get vcRoomTabRoom => 'Room';

  @override
  String get vcRoomLeft => 'You left';

  @override
  String get vcRoomLeave => 'Leave';

  @override
  String get vcRoomStreamingScreen => 'Streaming your screen';

  @override
  String get vcRoomStreamingCamera => 'Streaming with camera';

  @override
  String get vcRoomStopSharing => 'Stop sharing';

  @override
  String get vcRoomStopStream => 'Stop streaming';

  @override
  String get vcRoomSpeakerUnmute => 'Unmute speaker';

  @override
  String get vcRoomSpeakerMute => 'Mute speaker';

  @override
  String get vcRoomMutedByModerator => 'Muted by a moderator';

  @override
  String get vcRoomMicOpening => 'Preparing mic (tap to cancel)';

  @override
  String get vcRoomMicOff => 'Mic off';

  @override
  String get vcRoomMicOn => 'Mic on';

  @override
  String get vcRoomScreenShareOff => 'Stop screen share';

  @override
  String get vcRoomFullscreen => 'Full screen';

  @override
  String get vcRoomCaptionsOff => 'Captions off';

  @override
  String get vcRoomCaptionsOn => 'Captions on';

  @override
  String get vcRoomShareAsLinkLimited =>
      'This post has limited visibility, so it will be shared as a link';

  @override
  String vcRoomShareAsLinkFailed(String error) {
    return 'Couldn\'t fetch the post, so sharing it as a link: $error';
  }

  @override
  String vcRoomPickFileFailed(String error) {
    return 'Couldn\'t select a file: $error';
  }

  @override
  String get vcRoomStream => 'Stream';

  @override
  String vcRoomLiveCardTitle(String kind, String title) {
    return '$kind: $title';
  }

  @override
  String vcRoomPeerScreen(String name) {
    return '$name\'s screen';
  }

  @override
  String vcRoomPeerScreenTitled(String name, String title) {
    return '$name\'s screen — $title';
  }

  @override
  String get vcRoomAllShares => 'All shares';

  @override
  String get vcRoomSettingsTitle => 'ASTell settings';

  @override
  String get vcRoomModerationLabel => 'Moderation (owner)';

  @override
  String get vcRoomJoinPolicyLabel => 'Who can join';

  @override
  String get vcRoomSharePolicyLabel => 'Who can share (post to chat)';

  @override
  String vcRoomModeratorsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Moderators ($count) — add from a member\'s \"…\"',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomRemoveModerator => 'Remove moderator';

  @override
  String get vcRoomTendencyLabel => 'Posting tendency';

  @override
  String get vcRoomTendencyFilter => 'Turn away trolls (experimental)';

  @override
  String get vcRoomTendencyCaption =>
      'When on, people judged hostile can\'t enter. The judgment is still provisional.';

  @override
  String get vcRoomTendencyCaptionDetail =>
      'The real one will be rasq-judge\'s GoEmotion (emotional tendency of posts), which needs training, so for now it\'s a dummy server-side judgment (only people whose display name contains \"hostile\" or the Japanese word for \"troll\" are hostile). When on, people judged hostile can\'t enter. You can see the result from \"…\" on a member row.';

  @override
  String get vcRoomHostStreamLabel => 'Streaming (host)';

  @override
  String get vcRoomStreamCamera => 'Stream with camera';

  @override
  String get vcRoomStreamScreen => 'Stream your screen';

  @override
  String get vcRoomStreamScreenIos =>
      'On iPhone / iPad, only this app\'s screen (other apps aren\'t shown)';

  @override
  String get vcRoomHostStreamCaption =>
      'Streams video and voice. People who don\'t fit in the call can listen via the stream.';

  @override
  String vcRoomHostStreamCaptionDetail(int cap) {
    return 'Sends video and mic to the streaming server (LiveKit). Participants see the video while keeping call audio, and people who don\'t fit in the call (after the ${cap}th person) hear your voice through the stream.';
  }

  @override
  String get vcRoomHoldMusicRoom => 'Allow hold music in this room (owner)';

  @override
  String get vcRoomHoldMusicCaption =>
      'Plays while waiting for the start, or when no one has spoken for a while.';

  @override
  String vcRoomHoldMusicCaptionDetail(int minutes) {
    return 'Plays while waiting for a scheduled start, and while everyone has their mic down (with no screen share / stream) and no chat has flowed for $minutes+ minutes. It stops when someone starts talking or the chat moves.';
  }

  @override
  String get vcRoomTts => 'Text-to-speech';

  @override
  String get vcRoomTtsUnavailable => 'Text-to-speech (unavailable)';

  @override
  String vcRoomTtsDetail(String model) {
    return 'Text-to-speech ($model, preset voices)';
  }

  @override
  String vcRoomTtsDetailUnavailable(String model) {
    return 'Text-to-speech ($model, preset voices) — server not configured';
  }

  @override
  String get vcRoomTtsNone => 'No text-to-speech';

  @override
  String get vcRoomTtsCaptionOwner =>
      'Text-to-speech voices are generated on the server (playback in the app is coming soon).';

  @override
  String get vcRoomTtsCaptionGuest =>
      'The host chooses the text-to-speech voice.';

  @override
  String get vcRoomTtsCaptionOwnerDetail =>
      'Text-to-speech for chat and shares is synthesized on the Central side (playback on the device will come later).';

  @override
  String get vcRoomDiagnosticsLabel => 'Connection status (for developers)';

  @override
  String get vcRoomDiagnosticsOpen => 'View call / stream connections';

  @override
  String get vcRoomDiagnosticsOpenSubtitle =>
      'ICE state, candidates, traffic sent/received, and received tracks';

  @override
  String get vcRoomDiagnosticsTitle => 'Connection status';

  @override
  String vcRoomHostStreamTitle(String name) {
    return '$name\'s stream';
  }

  @override
  String get vcRoomPostViewNotYet =>
      'Viewing this post (no supported SNS plugin installed)';

  @override
  String get vcRoomOpen => 'Open';

  @override
  String get vcRoomDelete => 'Delete';

  @override
  String get vcRoomCopied => 'Copied';

  @override
  String vcRoomReportWhatShare(String headline) {
    return 'the share \"$headline\"';
  }

  @override
  String get vcRoomPinToFrame => 'Show in share frame';

  @override
  String get vcRoomUnfollow => 'Unfollow';

  @override
  String get vcRoomFollow => 'Follow';

  @override
  String get vcRoomUnmute => 'Unmute';

  @override
  String get vcRoomModUnmute => 'Unmute for everyone';

  @override
  String get vcRoomModMute => 'Mute for everyone';

  @override
  String get vcRoomKick => 'Kick';

  @override
  String get vcRoomMakeModerator => 'Make moderator';

  @override
  String get vcRoomShowTendency => 'View posting tendency (experimental)';

  @override
  String get vcRoomUnblock => 'Unblock';

  @override
  String get vcRoomBlock => 'Block';

  @override
  String get vcRoomReport => 'Report';

  @override
  String vcRoomTendencyResult(String name, String source, String summary) {
    return '$name\'s posting tendency ($source): $summary';
  }

  @override
  String vcRoomTendencyResultHostile(
    String name,
    String source,
    String summary,
  ) {
    return '$name\'s posting tendency ($source): $summary — hostile';
  }

  @override
  String vcRoomUnblocked(String name) {
    return 'Unblocked $name';
  }

  @override
  String vcRoomBlocked(String name) {
    return 'Blocked $name (their messages are hidden and they can\'t enter your rooms)';
  }

  @override
  String vcRoomActionFailed(String error) {
    return 'Couldn\'t complete: $error';
  }

  @override
  String get vcRoomPinToShares => 'Pin to shares';

  @override
  String vcRoomReportWhatChat(String name) {
    return '$name\'s message';
  }

  @override
  String get vcRoomShowSummary => 'Show quick summary in preview';

  @override
  String get vcRoomAutoGenre => 'Choose genres automatically';

  @override
  String get vcRoomEditAutoGenres => 'Edit auto-selected genres';

  @override
  String get vcRoomGenres => 'Genres';

  @override
  String get vcRoomChatEmpty =>
      'Transcripts of what\'s said, plus chat and shares, appear here.';

  @override
  String vcRoomChatHiddenBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hiding $count messages from blocked users',
      one: 'Hiding 1 message from blocked users',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomTyping => 'Typing…';

  @override
  String get vcRoomDraft => 'Draft';

  @override
  String get vcRoomTypingLabel => 'Typing';

  @override
  String get vcRoomChatActions => 'Chat actions';

  @override
  String vcRoomTocStart(String title) {
    return 'Start: $title';
  }

  @override
  String vcRoomTocShared(String name, String kind, String headline) {
    return '$name shared $kind: $headline';
  }

  @override
  String get vcRoomTocCaption => 'Dividers for shares and transcripts.';

  @override
  String vcRoomMembersWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Members ($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomModerator => 'Moderator';

  @override
  String get vcRoomCustomPlugins => 'Custom plugins';

  @override
  String vcRoomUpdateFailed(String error) {
    return 'Couldn\'t update settings: $error';
  }

  @override
  String get vcRoomShareAction => 'Share';

  @override
  String get vcRoomSendDone => 'Finish sending';

  @override
  String vcRoomPeerScreenTap(String name) {
    return '$name\'s screen (tap for full screen)';
  }

  @override
  String get vcRoomPinnedSharesEmpty => 'Pinned shares appear here';

  @override
  String vcRoomCompactShare(String headline) {
    return 'Share: $headline';
  }

  @override
  String get vcRoomNoTranscripts => 'No transcripts yet';

  @override
  String get vcRoomTranscriptsDisabled =>
      'Transcription disabled (summary private)';

  @override
  String get vcRoomSharesCollapse => 'Collapse shares';

  @override
  String get vcRoomSharesExpand => 'Show all shares';

  @override
  String vcRoomSharedByPinned(String name) {
    return 'Shared by $name · 📌';
  }

  @override
  String vcRoomSharedByAuto(String name) {
    return 'Shared by $name · Auto';
  }

  @override
  String vcRoomTranscriptMetaPinned(String name, String time) {
    return '$name · $time · 📌';
  }

  @override
  String vcRoomTranscriptMetaAuto(String name, String time) {
    return '$name · $time · Auto';
  }

  @override
  String get vcRoomMuted => 'Muted';

  @override
  String get vcRoomScreenFrameActions => 'Share frame actions';

  @override
  String vcRoomMemberSelf(String name) {
    return '$name (you)';
  }

  @override
  String get vcRoomForceMuted => 'Force muted';

  @override
  String get vcRoomMemberActions => 'Member actions';

  @override
  String get vcRoomDiagnosticsLogHint =>
      'Also logged in the browser / Xcode log as \"astell call:\" and \"astell stream:\".';

  @override
  String get vcRoomCopy => 'Copy';

  @override
  String vcRoomBansLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bans ($count) — from \"…\" on a member row',
    );
    return '$_temp0';
  }

  @override
  String vcRoomBansLoadFailed(String error) {
    return 'Couldn\'t load the ban list: $error';
  }

  @override
  String get vcRoomUnban => 'Unban';

  @override
  String vcRoomReportBody(String what) {
    return 'Report $what. RASQ moderators will review it.';
  }

  @override
  String get vcRoomReportNoteHint => 'Note (optional)';

  @override
  String vcRoomReportFailed(String error) {
    return 'Couldn\'t report: $error';
  }

  @override
  String get vcRoomReportSubmit => 'Report';

  @override
  String get vcRoomReported => 'Reported. It will be reviewed';

  @override
  String vcRoomLiveBy(String name, String kind) {
    return '$name: $kind in progress';
  }
}
