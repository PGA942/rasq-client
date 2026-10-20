// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'rasq_design_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class RasqDesignLocalizationsKo extends RasqDesignLocalizations {
  RasqDesignLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get designSearchHint => '검색';

  @override
  String get designFilterReset => '초기화';

  @override
  String designReplyParentSemantics(String name) {
    return '$name님의 답글 원본 게시물';
  }

  @override
  String designInlinePostSemantics(String name) {
    return '$name님의 게시물(인라인 프레임)';
  }

  @override
  String designPostSemantics(String name) {
    return '$name님의 게시물';
  }

  @override
  String get designFollowedBy => '나를 팔로우함';

  @override
  String get designFollow => '팔로우';

  @override
  String get designFollowing => '팔로잉';

  @override
  String get designFollowRequested => '요청됨';

  @override
  String get designFollowers => '팔로워';

  @override
  String get designMenu => '메뉴';

  @override
  String get designContentWarningHide => '숨기기';

  @override
  String get designContentWarningShow => '더 보기';

  @override
  String get designMediaPlay => '재생';

  @override
  String get designMediaSensitive => '민감한 내용일 수 있는 미디어입니다';

  @override
  String get designMediaReveal => '표시';

  @override
  String get designMediaHidden => '설정에 따라 표시하지 않는 미디어입니다';

  @override
  String designReactionMorePeople(int count) {
    return '+$count명';
  }

  @override
  String designRangeValue(int start, int end) {
    return '$start~$end';
  }

  @override
  String get designListSeparator => ', ';

  @override
  String designThreadReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '답글 $count개',
    );
    return '$_temp0';
  }

  @override
  String designRepostedBy(String name) {
    return '$name님이 리노트함';
  }

  @override
  String get designActionBarSemantics => '액션 바';

  @override
  String get designRaiComingSoon => 'RAi(준비 중)';

  @override
  String get designVerifiedPerson => '인증됨(개인)';

  @override
  String get designVerifiedCompany => '인증됨(법인)';

  @override
  String get designVerifiedGovernment => '인증됨(공공기관)';

  @override
  String get designExpandPost => '펼치기';

  @override
  String get designSortDefault => '기본';

  @override
  String get designSortReactionsDesc => '리액션 수(내림차순)';

  @override
  String get designSortReactionsAsc => '리액션 수(오름차순)';

  @override
  String get designProfileBanner => '배너 이미지';

  @override
  String get designProfileEdit => '편집';

  @override
  String get designProfileNotifications => '알림';

  @override
  String get designProfileRestricted => '이 사용자는 제한되어 있습니다.';

  @override
  String get designProfileRestrictedShow => '표시';

  @override
  String designProfileJoined(String date) {
    return '$date 가입';
  }

  @override
  String designProfileNotes(String count) {
    return '노트 $count개';
  }

  @override
  String get designPollVote => '투표';

  @override
  String get designPollSubmit => '투표하기';

  @override
  String designPollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count표',
    );
    return '$_temp0';
  }

  @override
  String get designPollEnded => '종료';

  @override
  String get designPollVoted => ' 투표함';

  @override
  String get designTimeEnded => '종료';

  @override
  String designTimeRemainingDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일 남음',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간 남음',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분 남음',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count초 남음',
    );
    return '$_temp0';
  }

  @override
  String get designTimeJustNow => '방금';

  @override
  String designTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분 전',
    );
    return '$_temp0';
  }

  @override
  String designTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간 전',
    );
    return '$_temp0';
  }

  @override
  String designTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일 전',
    );
    return '$_temp0';
  }

  @override
  String get designErrorRetry => '다시 시도';

  @override
  String get designOverlayCancel => '취소';

  @override
  String get designOverlayClose => '닫기';

  @override
  String get designOverlaySwitcher => 'FOW 전환';

  @override
  String get designOverlayResizeHandle => '크기 조절 핸들';

  @override
  String designRrlRange(int start, int end, String unit) {
    return '$start~$end$unit';
  }

  @override
  String get designRrlSend => '보내기';

  @override
  String designRrlNoAuthFlow(String pluginId) {
    return '$pluginId: 로그인 절차가 구성되어 있지 않습니다(기존 토큰으로 등록만 가능)';
  }
}
