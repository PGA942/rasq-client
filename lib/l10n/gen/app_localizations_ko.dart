// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get adsShowLess => '덜 표시하기';

  @override
  String get adsShowLessDone => '이 광고를 덜 표시합니다';

  @override
  String get adsLabel => '광고';

  @override
  String adsLabelWithHost(String host) {
    return '광고 · $host';
  }

  @override
  String get adsMenu => '광고 메뉴';

  @override
  String get adsOpen => '광고 열기';

  @override
  String get appNavPostTitle => '게시물';

  @override
  String get appNavReactionsTitle => '리액션';

  @override
  String get appNavFollowersTitle => '팔로워';

  @override
  String get appNavFollowingTitle => '팔로잉';

  @override
  String get appNavShortcutSearch => '검색';

  @override
  String get appNavShortcutNewPost => '새 게시물';

  @override
  String get appNavShortcutNewMessage => '메시지 작성';

  @override
  String get appNavShortcutAskRai => 'RAi와 찾기';

  @override
  String get appNavShortcutGuardianPending => '보호자가 설정을 마칠 때까지 사용할 수 없습니다';

  @override
  String get appNavShortcutLoginHint => 'SNS 계정에 로그인하면 사용할 수 있습니다';

  @override
  String get backendOauthNoToken => '액세스 토큰을 가져올 수 없습니다';

  @override
  String backendOauthServerRequired(String service) {
    return '$service에 로그인하려면 RASQ 서버가 필요합니다. 설정 → \'RASQ 서버\'에서 연결할 서버를 설정하세요.';
  }

  @override
  String get backendOauthNoUrl => '인증 URL을 가져올 수 없습니다';

  @override
  String get backendOauthHint => '브라우저에서 허용한 뒤 앱으로 돌아와 \'인증 확인\'을 누르세요.';

  @override
  String backendResponseTooLarge(int maxBytes) {
    return '응답이 너무 큽니다($maxBytes바이트 초과)';
  }

  @override
  String get backendSecurityPasswordlessRemoved =>
      '이메일 코드만으로 로그인하는 방식은 종료되었습니다. 핸들(또는 이메일)과 비밀번호로 로그인하세요';

  @override
  String get backendSecuritySecondFactor => '이메일로 받은 인증 코드를 입력하세요';

  @override
  String get backendSecurityTooMany => '시도 횟수가 너무 많습니다. 잠시 후 다시 시도하세요';

  @override
  String get backendSecurityNoMail => '이 서버는 이메일을 보낼 수 있도록 설정되어 있지 않습니다';

  @override
  String get backendSecurityEmailUsed => '이 이메일 주소는 다른 계정에서 사용 중입니다';

  @override
  String get backendSecurityBadCredentials => '핸들(이메일) 또는 비밀번호가 올바르지 않습니다';

  @override
  String get backendSecurityBadCode => '코드가 올바르지 않거나 만료되었습니다';

  @override
  String get backendSecurityWeakPassword =>
      '이 비밀번호는 너무 약합니다(자주 쓰이는 비밀번호, 같은 문자의 반복, 핸들이나 이메일과 같은 비밀번호는 사용할 수 없습니다)';

  @override
  String get backendSecurityShortPassword => '비밀번호는 8자 이상이어야 합니다';

  @override
  String get backendSecurityBadEmail => '이메일 주소 형식이 올바르지 않습니다';

  @override
  String get backendSecurityWrongPassword => '현재 비밀번호가 올바르지 않습니다';

  @override
  String get backendSecurityNoPassword =>
      '이 계정에는 비밀번호가 없습니다. 현재 이메일로 받은 인증 코드로 확인하세요';

  @override
  String get backendSecurityConfirmRequired =>
      '이 작업에는 현재 비밀번호 또는 현재 이메일로 받은 인증 코드가 필요합니다';

  @override
  String get backendRoomClosed => '룸에 들어갈 수 없습니다(룸이 닫혔거나 찾을 수 없음)';

  @override
  String get backendRoomForbidden => '룸에 들어갈 수 없습니다(이 계정으로는 참가할 수 없음)';

  @override
  String backendRoomConnectFailed(String error) {
    return '룸에 연결할 수 없습니다: $error';
  }

  @override
  String get backendPaidFeaturesDisabled => '공개 테스트 기간에는 유료 플러그인을 사용할 수 없습니다';

  @override
  String get backendAgeTeen => '13~15세';

  @override
  String get backendAgeUpperTeen => '16~17세';

  @override
  String get backendAgeAdult => '18세 이상';

  @override
  String get backendNoToken => 'ORGATE가 토큰을 반환하지 않았습니다';

  @override
  String get backendTileAuto => '자동';

  @override
  String get backendTileShow => '표시';

  @override
  String get backendTileHide => '숨기기';

  @override
  String get backendVerifiedKeybase => 'Keybase 증명으로 확인됨';

  @override
  String get backendVerifiedProfile => '프로필로 확인됨';

  @override
  String get backendAudioFileName => '음성';

  @override
  String get backendServerNotConfigured => 'RASQ 서버 연결 주소가 설정되지 않았습니다';

  @override
  String backendServerError(int status) {
    return '서버 오류($status)';
  }

  @override
  String get backendCollectionList => '리스트';

  @override
  String get backendCollectionClip => '클립';

  @override
  String get bookmarksRemoved => '북마크를 해제했습니다';

  @override
  String bookmarksRemoveFailed(String error) {
    return '해제하지 못했습니다: $error';
  }

  @override
  String get bookmarksTitle => '북마크';

  @override
  String get bookmarksRetry => '다시 불러오기';

  @override
  String get bookmarksEmptyTitle => '북마크가 없습니다';

  @override
  String get bookmarksEmptyHint => '게시물의 🔖, 클립에 추가, ASTell 책갈피로 모을 수 있습니다';

  @override
  String get bookmarksEmptyNoSnsHint =>
      '이 서비스에는 북마크가 없습니다. 게시물의 🔖를 길게 누르면 RASQ 클립에 모을 수 있습니다';

  @override
  String get bookmarksClips => '클립';

  @override
  String bookmarksClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String get bookmarksClipHost => 'RASQ (SNS 통합)';

  @override
  String get bookmarksClipPrivate => '비공개 클립';

  @override
  String get bookmarksSeparator => ' · ';

  @override
  String get bookmarksFavorites => '즐겨찾기';

  @override
  String get bookmarksSwipeRemove => '해제';

  @override
  String get bookmarksRemove => '북마크 해제';

  @override
  String get catalogTitle => '컴포넌트 카탈로그';

  @override
  String get catalogSectionBrand => 'Brand (특수 컴포넌트)';

  @override
  String get catalogSectionPostTile => 'PostTile — 일반 (액션 바 / 투표 / 미디어)';

  @override
  String get catalogSectionPostTileEmbedded =>
      'PostTile — 임베드 (인용 / 리액션 표시 / 타이머 알림) & 스레드 요약';

  @override
  String get catalogSectionCollapsed => 'CollapsedPost (축약 표시: 읽음 + 긴 글)';

  @override
  String get catalogSectionPoll => 'PollWidget (미투표 단일 / 복수, 투표 완료, 기한 만료)';

  @override
  String get catalogSectionActionBar => 'ActionBar (spread / leading = 작성기 툴바)';

  @override
  String get catalogSectionRrl => 'RRL 렌더러 (post-tile.rrl.json → L1/L2/L3)';

  @override
  String get catalogSheetTitle => '바텀 시트';

  @override
  String get catalogSheetConfirm => '확인';

  @override
  String get catalogSheetBody =>
      '배경을 탭하거나 취소하면 변경이 취소됩니다.\n이 위에 모달을 띄울 수 있습니다.';

  @override
  String get catalogAlertTitle => '차단할까요?';

  @override
  String get catalogAlertMessage => '배경 탭은 무효 (명시적인 조작 필요)';

  @override
  String get catalogAlertConfirm => '차단';

  @override
  String get catalogAlertCancel => '취소';

  @override
  String get catalogDropdownAsc => '오름차순';

  @override
  String get catalogDropdownDesc => '내림차순';

  @override
  String get catalogDropdownDefault => '기본';

  @override
  String get catalogDropdownReport => '신고';

  @override
  String get catalogSheetModalTitle => '시트 → 모달 끼어들기';

  @override
  String get catalogModalTitle => '모달';

  @override
  String get catalogModalMessage => '시트는 유지됩니다';

  @override
  String get catalogModalOpen => '모달 띄우기';

  @override
  String get childSafeLevelStrict => '엄격';

  @override
  String get childSafeLevelStandard => '보통';

  @override
  String get childSafeLevelMild => '느슨';

  @override
  String get childSafeTopicModeAllow => '허용 목록';

  @override
  String get childSafeTopicModeDeny => '차단 목록';

  @override
  String get childSafeInstallNone => '설치 불가';

  @override
  String get childSafeInstallListed => '선택한 것만';

  @override
  String get childSafeInstallAny => '자유';

  @override
  String get childSafeInstallExamples => '예시와 비슷한 것';

  @override
  String get childSafeEmptyWhitelistError =>
      '허용 목록이 비어 있습니다. 주제를 하나 이상 넣거나 차단 목록으로 바꿔 주세요';

  @override
  String get childSafeMethodJpki => '마이넘버 카드 (JPKI)';

  @override
  String get childSafeMethodSelfDeclared => '자기 신고';

  @override
  String get childSafeErrorCodeInvalid => '코드가 올바르지 않거나 만료되었습니다';

  @override
  String get childSafeErrorHandleTaken => '그 핸들은 이미 사용 중입니다';

  @override
  String get childSafeErrorAlreadyLinked => '이미 보호받고 있는(또는 누군가를 보호하고 있는) 계정입니다';

  @override
  String get childSafeErrorCodeGone =>
      '코드가 만료되었거나 이미 사용되었습니다. 보호자에게 다시 발급해 달라고 해 주세요';

  @override
  String get childSafeErrorDevice => '이 기기에서는 로그인할 수 없습니다';

  @override
  String get childSafeErrorTooMany => '시도 횟수가 너무 많습니다. 잠시 후 다시 시도하세요';

  @override
  String get childSafeNoServer => 'RASQ 서버 연결 주소가 설정되지 않았습니다';

  @override
  String childSafeNoticeMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' (외 $count건)',
    );
    return '$_temp0';
  }

  @override
  String get childSafeNoticeRefreshed => '차일드 세이프: 보호자 설정을 다시 가져왔습니다';

  @override
  String get childSafeNoticeView => '보기';

  @override
  String get childSafeBlocked => '보호자가 막아 두었습니다';

  @override
  String childSafeBlockedWith(String label) {
    return '보호자가 막아 두었습니다 ($label)';
  }

  @override
  String childSafeTimeRange(String start, String end) {
    return '$start~$end';
  }

  @override
  String get childSafeLockedUntilSetup => '보호자가 설정을 마칠 때까지 사용할 수 없습니다';

  @override
  String childSafeWindowNoDm(String window) {
    return '보호 시간($window)에는 DM을 사용할 수 없습니다';
  }

  @override
  String get childSafeBlockedAstell => '보호자가 ASTell을 막아 두었습니다';

  @override
  String childSafeWindowNoAstell(String window) {
    return '보호 시간($window)에는 ASTell을 사용할 수 없습니다';
  }

  @override
  String get childSafeBlockedDm => '보호자가 DM을 막아 두었습니다';

  @override
  String childSafeWindowNoNotifications(String window) {
    return '보호 시간($window)에는 알림을 볼 수 없습니다';
  }

  @override
  String get childSafeBlockedRai => '보호자가 RAi를 막아 두었습니다';

  @override
  String get childSafeBlockedStore => '보호자가 플러그인 스토어를 막아 두었습니다';

  @override
  String get childSafeBlockedSearch => '보호자가 검색을 막아 두었습니다';

  @override
  String get childSafeBlockedAddAccount => '보호자가 SNS 계정 추가를 막아 두었습니다';

  @override
  String get childSafeBlockedCustomPlugins => '보호자가 커스텀 플러그인을 막아 두었습니다';

  @override
  String get childSafeBlockedPlugins => '보호자가 플러그인을 막아 두었습니다';

  @override
  String childSafeWindowNoPostDetail(String window) {
    return '보호 시간($window)에는 게시물 상세를 열 수 없습니다';
  }

  @override
  String get childSafePostHidden => '이 게시물은 표시할 수 없습니다';

  @override
  String get childSafeListSeparator => ', ';

  @override
  String childSafeBullet(String text) {
    return '• $text';
  }

  @override
  String childSafeTopicsEtc(String topics) {
    return '$topics 등';
  }

  @override
  String get childSafeComposeNoTopicsAllowed =>
      '보호자의 설정에 따라 지금은 게시물을 보낼 수 없습니다';

  @override
  String childSafeComposeTopicsOnly(String topics) {
    return '보호자의 설정에 따라 정해진 주제($topics)의 게시물만 보낼 수 있습니다. 주제에 맞게 써 주세요';
  }

  @override
  String childSafeComposeTopicDenied(String topic) {
    return '보호자의 설정에 따라 \'$topic\' 주제의 게시물은 보낼 수 없습니다. 고쳐 써 주세요';
  }

  @override
  String childSafeQuoted(String text) {
    return '\'$text\'';
  }

  @override
  String childSafeComposeStimulus(String level, String word) {
    return '보호자의 설정($level)에 따라 이 표현$word은 보낼 수 없습니다. 다르게 표현해 주세요';
  }

  @override
  String get childSafeBlockedThisPlugin => '보호자가 이 플러그인을 막아 두었습니다';

  @override
  String get childSafeDevPreviewUnknown =>
      '보호자가 선택한 플러그인만 실행할 수 있습니다(이 불러오기 방식으로는 어떤 플러그인인지 확인할 수 없습니다)';

  @override
  String get childSafeBlockedInstall => '보호자가 플러그인 설치를 막아 두었습니다';

  @override
  String get childSafeNearDenyPlugin => '보호자가 막아 둔 예시와 비슷한 플러그인입니다';

  @override
  String get childSafeInstallListedOnly => '보호자가 선택한 플러그인만 설치할 수 있습니다';

  @override
  String get childSafeInstallExamplesOnly =>
      '보호자가 선택한 플러그인과 허용 예시와 비슷한 것만 설치할 수 있습니다';

  @override
  String get childSafeCacheUnverified =>
      '저장해 둔 제한의 서명을 확인할 수 없습니다. 온라인에서 다시 가져와 주세요';

  @override
  String get childSafeNewSettingsUnverified =>
      '보호자의 새 설정의 서명을 확인하지 못했습니다(이전 설정 유지)';

  @override
  String get childSafeComposeLocked => '보호자가 설정을 정할 때까지 보낼 수 없습니다';

  @override
  String childSafeComposeDailyLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '오늘은 이미 $count건을 보냈습니다(보호자가 정한 하루 개수). 내일 다시',
    );
    return '$_temp0';
  }

  @override
  String childSafeComposeAfterTransform(String message) {
    return '$message (보내기 전 가공 후의 본문)';
  }

  @override
  String get childSafeStatePending => '설정 대기';

  @override
  String get childSafeWatchAsGuardian => '보호하기 (보호자)';

  @override
  String get childSafeLoginWithCode => '보호자에게 받은 코드로 로그인';

  @override
  String get childSafeChildMode => '차일드 모드';

  @override
  String get childSafeGuardianStateApplied => '보호 중 (기기에 전달됨)';

  @override
  String childSafeGuardianStateNotApplied(int revision) {
    return '보호 중 (설정 $revision이(가) 아직 기기에 전달되지 않음)';
  }

  @override
  String childSafeGuardianPledgeTitle(String version) {
    return '보호자 서약 (버전 $version)';
  }

  @override
  String childSafeGuardianPledgeMessage(String pledge) {
    return '$pledge\n\n동의하면 마이넘버 카드(디지털 인증 앱)로 확인하는 단계로 넘어갑니다(일본 거주자).';
  }

  @override
  String get childSafeGuardianPledgeConfirm => '동의하고 진행';

  @override
  String get childSafeGuardianCancel => '취소';

  @override
  String get childSafeGuardianLoadError => '불러오지 못했습니다';

  @override
  String get childSafeGuardianReload => '다시 불러오기';

  @override
  String get childSafeGuardianVerifySection => '보호자 확인';

  @override
  String get childSafeGuardianVerified => '확인 완료';

  @override
  String get childSafeGuardianNotVerified => '아직 확인하지 않았습니다';

  @override
  String get childSafeGuardianVerifyIntro =>
      '자녀 계정을 만들거나 연결하기 전에 보호자 확인을 합니다(일본은 마이넘버 카드).';

  @override
  String get childSafeGuardianVerifyIntroDetail =>
      '자녀 계정을 만들거나 연결하기 전에 보호자 확인을 합니다(일본은 마이넘버 카드(JPKI), 다른 나라는 웹 콘솔에서 자기 신고).';

  @override
  String get childSafeGuardianVerifyJpki => '마이넘버 카드로 확인';

  @override
  String get childSafeGuardianVerifyJpkiSubtitle =>
      '일본 거주자용. 서약에 동의한 뒤 외부 브라우저에서 엽니다';

  @override
  String get childSafeGuardianVerifyWeb => '웹 콘솔에서 확인';

  @override
  String get childSafeGuardianOpensInBrowser => '외부 브라우저에서 엽니다';

  @override
  String childSafeGuardianChildrenSection(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '보호 중인 자녀 ($count / $max)',
    );
    return '$_temp0';
  }

  @override
  String get childSafeGuardianNoChildren => '아직 없습니다.';

  @override
  String get childSafeGuardianCreatedByGuardian => ' · 보호자가 생성';

  @override
  String get childSafeGuardianAddSection => '자녀 추가';

  @override
  String get childSafeGuardianCreate => '자녀 계정 만들기';

  @override
  String get childSafeGuardianCreateSubtitle =>
      '핸들 / 이름 / 연령대를 정하면 자녀 기기에서 로그인하기 위한 코드가 한 번만 표시됩니다';

  @override
  String get childSafeGuardianHandleHint => '핸들 (영문·숫자)';

  @override
  String get childSafeGuardianNameHint => '표시 이름';

  @override
  String get childSafeGuardianCreateButton => '만들기';

  @override
  String childSafeGuardianNewLoginCodeTitle(String handle) {
    return '@$handle의 로그인 코드 (자녀 기기의 \'보호자에게 받은 코드로 로그인\'에 입력하거나 자녀 기기의 카메라로 QR을 읽으세요)';
  }

  @override
  String get childSafeGuardianPair => '코드로 연결';

  @override
  String get childSafeGuardianPairSubtitle =>
      '자녀가 이미 가진 RASQ 계정을 자녀 기기의 \'차일드 모드\'로 연결합니다(10분·1회만)';

  @override
  String get childSafeGuardianPairCodeTitle =>
      '연결 코드 (자녀 기기의 \'차일드 모드\'에 입력하거나 자녀 기기의 카메라로 QR을 읽으세요)';

  @override
  String childSafeGuardianCodeExpires(String time) {
    return '$time까지. 이 화면을 닫으면 다시 표시할 수 없습니다(다시 발급하면 이전 코드는 사용할 수 없게 됩니다).';
  }

  @override
  String get childSafeGuardianCodeQr => '코드 QR';

  @override
  String get childSafeGuardianCopy => '복사';

  @override
  String get childSafeGuardianCopyLink => '링크 복사';

  @override
  String get childSafeGuardianClose => '닫기';

  @override
  String get childSafeGuardianPageTimeline => '타임라인';

  @override
  String get childSafeGuardianPageComposer => '게시물';

  @override
  String get childSafeGuardianPageAstell => 'ASTell';

  @override
  String get childSafeGuardianPagePlugins => '플러그인';

  @override
  String get childSafeGuardianPageSns => 'SNS';

  @override
  String get childSafeGuardianPageScreenTime => '스크린 타임';

  @override
  String get childSafeGuardianPageOther => '기타';

  @override
  String get childSafeGuardianTimeFormatError => '시각은 HH:MM 형식으로 입력해 주세요';

  @override
  String get childSafeGuardianConfirmTitle => '이 설정 보내기';

  @override
  String get childSafeGuardianConfirmSend => '보내기';

  @override
  String childSafeGuardianConfirmIntro(String handle) {
    return '@$handle의 기기에 이 설정이 전달됩니다.';
  }

  @override
  String childSafeGuardianConfirmIntroDetail(String handle) {
    return '@$handle의 기기에는 Central이 서명한 설정이 전달됩니다(기기에서 확인한 뒤 적용합니다).';
  }

  @override
  String childSafeGuardianSaved(int revision) {
    return '저장했습니다(설정 $revision). 자녀 기기에 전달되면 \'전달됨\'으로 표시됩니다';
  }

  @override
  String childSafeGuardianImportPreset(String band) {
    return '$band 기본값 불러오기';
  }

  @override
  String get childSafeGuardianImportCopy => '다른 자녀의 설정 복사';

  @override
  String childSafeGuardianImportedPreset(String band) {
    return '$band 기본값을 불러왔습니다';
  }

  @override
  String get childSafeGuardianCopyWhich => '어느 자녀의 설정을 복사할까요?';

  @override
  String childSafeGuardianNotSetUp(String handle) {
    return '@$handle은(는) 아직 설정이 끝나지 않았습니다';
  }

  @override
  String childSafeGuardianCopied(String handle) {
    return '@$handle의 설정을 복사했습니다';
  }

  @override
  String childSafeGuardianNotSavedYet(String what) {
    return '$what (아직 저장하지 않음)';
  }

  @override
  String get childSafeGuardianEnd => '보호 끝내기';

  @override
  String childSafeGuardianEndMessage(String handle) {
    return '@$handle의 제한을 모두 해제합니다. 자녀 기기는 다음에 연결될 때 해제됩니다. 되돌리려면 다시 연결하세요.';
  }

  @override
  String childSafeGuardianEndMessageDetail(String handle) {
    return '@$handle의 제한을 모두 해제합니다. 자녀 기기는 다음에 Central에 연결될 때 해제됩니다. 되돌리려면 다시 연결하세요.';
  }

  @override
  String get childSafeGuardianEndConfirm => '끝내기';

  @override
  String get childSafeGuardianEndSubtitle => '제한을 모두 해제합니다';

  @override
  String get childSafeGuardianSummarySection => '최근 발신 내용 요약 (14일)';

  @override
  String get childSafeGuardianLoginSection => '자녀 기기 로그인';

  @override
  String get childSafeGuardianReissue => '코드 다시 발급';

  @override
  String get childSafeGuardianReissueSubtitle =>
      '자녀 기기의 \'보호자에게 받은 코드로 로그인\'에 입력하는 코드(10분·1회만. 이전 코드는 사용할 수 없게 됩니다)';

  @override
  String childSafeGuardianLoginCodeTitle(String handle) {
    return '@$handle의 로그인 코드';
  }

  @override
  String get childSafeGuardianSaveButton => '저장하고 자녀 기기로 보내기';

  @override
  String get childSafeGuardianImportTooltip => '설정 가져오기';

  @override
  String childSafeGuardianPresetCaption(String band) {
    return '강도를 고르면 타임라인과 게시물의 판정 강도가 맞춰집니다. 오른쪽의 둥근 버튼으로 $band 기본값이나 다른 자녀의 설정을 불러올 수 있습니다.';
  }

  @override
  String get childSafeGuardianSummaryEmpty =>
      '아직 보고가 없습니다(자녀 기기는 끝난 날의 수를 하루 한 번 보냅니다).';

  @override
  String get childSafeGuardianSummaryCaption =>
      '보낸 수 / 막은 수 / 막은 종류만입니다(게시물 본문이나 주제는 전달되지 않습니다. 보내기 전 판정은 자녀의 기기에서 합니다).';

  @override
  String childSafeGuardianSummaryDay(int posts, int blocked, String trips) {
    return '보냄 $posts · 막음 $blocked$trips';
  }

  @override
  String childSafeGuardianSummaryTrips(String list) {
    return ' ($list)';
  }

  @override
  String get childSafeGuardianSummaryTripsSeparator => ', ';

  @override
  String get childSafeGuardianTimelineEnabled => '타임라인 거르기';

  @override
  String get childSafeGuardianTimelineEnabledSubtitle =>
      '강한 말이 담긴 게시물을 숨기고 주제로 거릅니다';

  @override
  String get childSafeGuardianTimelineLevel => '타임라인 강도';

  @override
  String get childSafeGuardianTimelineTopics => '타임라인 주제';

  @override
  String get childSafeGuardianTimelineAllowHint => '표시할 주제 (단어나 태그를 \',\'로 구분)';

  @override
  String get childSafeGuardianTimelineDenyHint => '숨길 주제 (단어나 태그를 \',\'로 구분)';

  @override
  String get childSafeGuardianTimelineAllowNote =>
      '허용 목록: 주제 중 하나에 해당하는 게시물만 타임라인에 표시됩니다.';

  @override
  String get childSafeGuardianTimelineDenyNote =>
      '차단 목록: 해당하는 게시물을 숨깁니다(비어 있음 = 주제로 거르지 않음).';

  @override
  String get childSafeGuardianComposerEnabled => '게시물 판정';

  @override
  String get childSafeGuardianComposerEnabledSubtitle =>
      '강한 말과 주제로 보내기 전에 막습니다(해당하는 말에 표시를 붙여 막음)';

  @override
  String get childSafeGuardianComposerLevel => '게시물 강도';

  @override
  String get childSafeGuardianPostsPerDayHint =>
      '하루에 보낼 수 있는 게시물 수 (비어 있음 = 정하지 않음, 0~1000)';

  @override
  String get childSafeGuardianComposerTopics => '게시물 주제';

  @override
  String get childSafeGuardianComposerAllowHint =>
      '보낼 수 있는 주제 (단어나 태그를 \',\'로 구분)';

  @override
  String get childSafeGuardianComposerDenyHint =>
      '보낼 수 없는 주제 (단어나 태그를 \',\'로 구분)';

  @override
  String get childSafeGuardianComposerAllowNote =>
      '허용 목록: 주제 중 하나에 해당하는 게시물만 보낼 수 있습니다(DM에는 적용하지 않음).';

  @override
  String get childSafeGuardianComposerDenyNote =>
      '차단 목록: 해당하는 게시물은 보낼 수 없습니다(비어 있음 = 주제로 막지 않음. DM에는 적용하지 않음).';

  @override
  String get childSafeGuardianAstellCaption =>
      'ASTell(룸 통화·채팅·공유)에서 자녀가 할 수 있는 것.';

  @override
  String get childSafeGuardianInstallSection => '설치';

  @override
  String get childSafeGuardianInstallCaption =>
      '자녀가 직접 설치할 수 있는 범위. 플러그인은 계속 늘어나므로 하나씩이 아니라 아래의 \'예시\'로 대략 정합니다.';

  @override
  String get childSafeGuardianNamedSection => '이름으로 허용한 플러그인';

  @override
  String get childSafeGuardianNamedNone => '없습니다.';

  @override
  String get childSafeGuardianNamedCaption =>
      '여기에 있는 것은 차단 예시와 비슷해도 사용할 수 있습니다(✕로 제외).';

  @override
  String get childSafeGuardianRemove => '제외';

  @override
  String get childSafeGuardianAddIdHint => 'id로 추가 (예: jp.example.quiz)';

  @override
  String get childSafeGuardianAddIdButton => '추가';

  @override
  String get childSafeGuardianIdShapeError =>
      '플러그인 id 형식이 아닙니다 (영문 소문자·숫자·\'.\', \'_\', \'-\', 예: jp.example.quiz)';

  @override
  String get childSafeGuardianSnsCaption =>
      '자녀가 사용해도 되는 SNS 종류와 서버(내 번들에서). 서버를 고르지 않으면 그 종류라면 어디든 가능. 보호자의 SNS 로그인은 빌려주지 않습니다.';

  @override
  String get childSafeGuardianSnsAdd => '자녀가 SNS 계정을 추가할 수 있음';

  @override
  String get childSafeGuardianTimeEnabled => '보호 시간';

  @override
  String get childSafeGuardianTimeEnabledSubtitle =>
      '그동안은 타임라인이 하나가 됩니다(자녀 기기의 시계 기준)';

  @override
  String get childSafeGuardianTimeStartHint => '시작 21:00';

  @override
  String get childSafeGuardianTimeEndHint => '종료 06:00';

  @override
  String get childSafeGuardianTimeRangeSeparator => '~';

  @override
  String get childSafeGuardianTimeLegacyNote =>
      '현재 설정은 이전 형식인 \'그동안 아무것도 표시하지 않음\'입니다. 이 형식은 새로 저장할 수 없으므로, 표시할 주제를 넣거나 차단 목록으로 바꾼 뒤 저장해 주세요.';

  @override
  String get childSafeGuardianTimeTopics => '그동안의 주제';

  @override
  String get childSafeGuardianTimeAllowHint => '그동안 표시할 주제 (단어나 태그를 \',\'로 구분)';

  @override
  String get childSafeGuardianTimeDenyHint =>
      '그동안 표시하지 않을 주제 (단어나 태그를 \',\'로 구분)';

  @override
  String get childSafeGuardianTimeAllowNote =>
      '허용 목록: 그동안은 주제 중 하나에 해당하는 게시물만 표시됩니다.';

  @override
  String get childSafeGuardianTimeDenyNote =>
      '차단 목록: 그동안은 해당하는 게시물을 표시하지 않습니다(비어 있음 = 주제로 거르지 않음).';

  @override
  String get childSafeGuardianHideNotifications => '알림 숨기기';

  @override
  String get childSafeGuardianHidePostDetail => '게시물 상세를 열지 못하게 하기';

  @override
  String get childSafeGuardianHideDm => 'DM 숨기기';

  @override
  String get childSafeGuardianRaiEnabled => 'RAi 사용 가능';

  @override
  String get childSafeGuardianRaiComingSoon => '준비 중 (현재 적용되지 않음)';

  @override
  String get childSafeGuardianRaiAutomation => '함수로 자동화';

  @override
  String get childSafeGuardianRaiAutomationSubtitle => '끄면 안내(가리키기)만으로 진행합니다';

  @override
  String get childSafeGuardianSearchSection => '검색';

  @override
  String get childSafeGuardianFeaturesSection => '기능';

  @override
  String get childSafeGuardianExamplesTitlePlugins => '예시로 정하기 (플러그인)';

  @override
  String get childSafeGuardianExamplesTitleTl => '예시로 정하기 (클립 / 리스트)';

  @override
  String get childSafeGuardianExamplesCaptionPlugins =>
      '\'이런 플러그인은 허용 / 차단\'을 예시로 고릅니다. 자녀 기기는 플러그인의 이름·설명이 예시와 비슷한지로 정합니다. 차단 예시와 비슷한 것은 \'자유\'여도 사용할 수 없습니다. \'예시와 비슷한 것\'으로 하면 이름으로 허용한 것과 허용 예시와 비슷한 것을 사용할 수 있습니다.';

  @override
  String get childSafeGuardianExamplesCaptionTl =>
      '\'이런 것은 허용 / 차단\'을 내 최근 액션 / 클립 / 리스트에서 고릅니다. 자녀의 클립 / 리스트 중 내용이 차단 예시와 비슷한 것은 목록에도 타임라인에도 나오지 않습니다.';

  @override
  String get childSafeGuardianPickPlugins => '예시 고르기 (플러그인 / 스토어)';

  @override
  String get childSafeGuardianPickTl => '예시 고르기 (최근 액션 / 클립 / 리스트)';

  @override
  String childSafeGuardianPickCounts(int allow, int deny) {
    return '허용 예시 $allow / 차단 예시 $deny';
  }

  @override
  String childSafeGuardianPickTitlePlugins(String handle) {
    return '플러그인 예시 (@$handle)';
  }

  @override
  String childSafeGuardianPickTitleTl(String handle) {
    return '타임라인 예시 (@$handle)';
  }

  @override
  String get childSafeGuardianAllowLabel => '허용 예시';

  @override
  String get childSafeGuardianDenyLabel => '차단 예시';

  @override
  String get childSafeGuardianPickIntroPlugins =>
      '내용을 보고 자녀에게 \'허용 예시\'/\'차단 예시\'를 고릅니다(오른쪽 / 왼쪽 스와이프도 가능). 자녀 기기는 새 플러그인을 예시와의 근접도로 나눕니다.';

  @override
  String get childSafeGuardianPickIntroTl =>
      '내용을 보고 자녀에게 \'허용 예시\'/\'차단 예시\'를 고릅니다(오른쪽 / 왼쪽 스와이프도 가능). 자녀 기기는 클립 / 리스트를 예시와의 근접도로 나눕니다.';

  @override
  String get childSafeScreensBadge => '보호 중';

  @override
  String childSafeScreensWindowBanner(String window, String detail) {
    return '보호 시간대($window)입니다. $detail';
  }

  @override
  String get childSafeScreensWindowNothing => '게시물이 표시되지 않습니다';

  @override
  String childSafeScreensWindowAllowOnly(String topics) {
    return '\'$topics\' 관련 주제만 표시됩니다';
  }

  @override
  String childSafeScreensWindowDenied(String topics) {
    return '\'$topics\' 관련 주제는 표시되지 않습니다';
  }

  @override
  String get childSafeScreensBlockedHint => '보호 설정은 보호자가 정합니다';

  @override
  String get childSafeScreensHubTitle => '차일드 세이프';

  @override
  String get childSafeScreensHubIntro =>
      '보호자가 자녀 계정의 사용 방식을 정합니다. 보호자에게는 개수와 차단한 종류만 전달되며, 게시물 본문은 보내지 않습니다.';

  @override
  String get childSafeScreensHubIntroDetail =>
      '보호자의 RASQ 계정이 자녀의 RASQ 계정 사용 방식을 정합니다. 게시물 판정은 이 기기 안에서 이루어지며, 보호자에게는 보낸 수, 차단한 수, 보내기 전에 차단한 종류만 전달됩니다(게시물 본문이나 주제는 보내지 않습니다).';

  @override
  String get childSafeScreensHubManagedSection => '보호받고 있습니다';

  @override
  String get childSafeScreensHubParent => '보호자';

  @override
  String get childSafeScreensHubState => '상태';

  @override
  String childSafeScreensHubStateActive(int revision) {
    return '보호 중(설정 $revision)';
  }

  @override
  String get childSafeScreensHubOffline =>
      '지금은 서버에 연결할 수 없습니다. 이전 설정대로 보호를 계속합니다.';

  @override
  String get childSafeScreensHubRefresh => '보호자 설정 다시 가져오기';

  @override
  String get childSafeScreensHubAsGuardian => '보호자로서';

  @override
  String childSafeScreensHubGuardianVerified(String method) {
    return '확인됨($method). 자녀 계정 만들기 / 연결 / 설정';
  }

  @override
  String get childSafeScreensHubGuardianUnverified =>
      '보호자 확인은 웹 콘솔에서 합니다(일본은 마이넘버 카드, 그 외 지역은 자기 신고)';

  @override
  String get childSafeScreensHubAsChild => '자녀로서';

  @override
  String get childSafeScreensHubChildModeLogin => '보호자에게 받은 코드로 로그인합니다';

  @override
  String get childSafeScreensHubChildModePair => '보호자의 코드로 이 계정을 연결합니다';

  @override
  String get childSafeScreensHubLoginSubtitle => '보호자가 만든 자녀 계정에 들어갑니다';

  @override
  String get childSafeScreensHubThisDevice => '이 기기';

  @override
  String get childSafeScreensHubSafety => '개인정보 보호 및 세이프 모드';

  @override
  String get childSafeScreensHubSafetyManaged =>
      '보호 중에는 민감한 미디어를 항상 숨깁니다(변경할 수 없음)';

  @override
  String get childSafeScreensHubSafetyNormal => '민감한 미디어 처리';

  @override
  String childSafeScreensTopicsNote(String label, String topics) {
    return '($label: $topics)';
  }

  @override
  String get childSafeScreensTopicsNone => '없음';

  @override
  String get childSafeScreensTopicsShown => '표시할 주제';

  @override
  String get childSafeScreensTopicsHidden => '숨길 주제';

  @override
  String get childSafeScreensTopicsSendable => '보낼 수 있는 주제';

  @override
  String get childSafeScreensTopicsUnsendable => '보낼 수 없는 주제';

  @override
  String get childSafeScreensTopicsNotShown => '표시하지 않을 주제';

  @override
  String childSafeScreensSummaryTimeline(String level, String note) {
    return '타임라인: $level$note';
  }

  @override
  String childSafeScreensSummaryComposer(String level, String note) {
    return '게시물 판정: $level$note';
  }

  @override
  String childSafeScreensSummaryPostsPerDay(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '하루에 보낼 수 있는 게시물: $count개',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryTime(String window, String note) {
    return '보호 시간대: $window$note';
  }

  @override
  String get childSafeScreensSummaryTimeNothing => '(게시물 표시 안 함)';

  @override
  String childSafeScreensSummarySns(
    String kinds,
    String servers,
    String noAdd,
  ) {
    return '사용 가능한 SNS: $kinds$servers$noAdd';
  }

  @override
  String get childSafeScreensSummaryAny => '모두';

  @override
  String childSafeScreensSummarySnsServers(String servers) {
    return '($servers)';
  }

  @override
  String get childSafeScreensSummarySnsNoAdd => ', 추가 불가';

  @override
  String childSafeScreensSummaryFeaturesOff(String list) {
    return '중지한 기능: $list';
  }

  @override
  String childSafeScreensSummarySearchOff(String list) {
    return '중지한 검색: $list';
  }

  @override
  String childSafeScreensSummaryPlugins(String scope, String install) {
    return '플러그인: $scope, 설치: $install';
  }

  @override
  String childSafeScreensSummaryPluginsExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '선택한 $count개와 허용 예시에 가까운 것',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryPluginsListed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '선택한 $count개만',
    );
    return '$_temp0';
  }

  @override
  String childSafeScreensSummaryExamples(int allow, int deny) {
    return '예시: 허용 $allow개 / 차단 $deny개(차단 예시에 가까운 플러그인 / 클립 / 리스트는 표시되지 않습니다)';
  }

  @override
  String childSafeScreensSummaryRai(int count, String noAuto) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RAi: 함수 $count종류$noAuto',
    );
    return '$_temp0';
  }

  @override
  String get childSafeScreensSummaryRaiNoAuto => '(자동화 없음)';

  @override
  String get childSafeScreensSummaryRaiOff => 'RAi: 사용 불가';

  @override
  String childSafeScreensFromLink(String action) {
    return '링크(QR)에서 코드를 입력했습니다. 자신의 보호자에게 받은 것인지 확인한 후 \'$action\'을(를) 누르세요. 모르는 사람의 링크라면 누르지 말고 닫으세요.';
  }

  @override
  String get childSafeScreensPaired => '보호자와 연결했습니다. 보호자가 설정을 정할 때까지 기다려 주세요';

  @override
  String get childSafeScreensPairNotLoggedIn =>
      'RASQ 계정에 로그인하지 않았습니다. 보호자가 만든 계정이라면 보호자에게 받은 코드로 로그인합니다.';

  @override
  String get childSafeScreensPairExistingLogin => '기존 RASQ 계정에 로그인';

  @override
  String childSafeScreensPairIntro(String handle) {
    return '@$handle을(를) 보호자의 보호에 연결합니다. 보호자 화면에 표시된 코드(8자)를 입력하세요. 연결하면 보호자가 설정을 정할 때까지 사용할 수 없습니다.';
  }

  @override
  String childSafeScreensPairIntroDetail(String handle) {
    return '@$handle을(를) 보호자의 보호에 연결합니다. 보호자 화면(앱 또는 웹 콘솔)에 표시된 코드(8자, 예: ABCD-EFGH)를 입력하세요. 연결하면 보호자가 설정을 정할 때까지 앱을 사용할 수 없습니다.';
  }

  @override
  String get childSafeScreensPairButton => '연결';

  @override
  String get childSafeScreensPairQrHint =>
      '보호자 화면의 QR을 이 기기의 카메라 앱으로 읽어도 연결할 수 있습니다.';

  @override
  String get childSafeScreensPairQrHintDetail =>
      '보호자 화면의 QR을 이 기기의 카메라 앱으로 읽으면 코드가 입력된 상태로 이 화면이 열립니다. 링크(rasq://child-safe/pair?code=…)를 붙여 넣어도 연결할 수 있습니다.';

  @override
  String get childSafeScreensPairNoQr => '이 기기에서는 QR을 읽을 수 없습니다. 코드를 입력하세요.';

  @override
  String get childSafeScreensPairNoQrDetail =>
      '이 기기에서는 QR을 읽을 수 없습니다. 코드를 입력하거나 링크(rasq://child-safe/pair?code=…)를 붙여 넣으세요.';

  @override
  String get childSafeScreensLoginFailed => '로그인하지 못했습니다';

  @override
  String childSafeScreensLoggedIn(String handle, String device) {
    return '@$handle에 로그인했습니다($device)';
  }

  @override
  String get childSafeScreensLoginIntro =>
      '보호자가 앱에서 자녀 계정을 만들면 한 번만 쓸 수 있는 코드가 표시됩니다. 그 코드를 입력하면 이 기기가 그 계정이 됩니다. 이 기기의 SNS 계정은 이어받지 않습니다.';

  @override
  String get childSafeScreensLoginCodeHint => '로그인 코드';

  @override
  String get childSafeScreensLoginButton => '로그인';

  @override
  String get childSafeScreensPendingUnverifiedTitle => '보호자의 설정을 확인할 수 없습니다';

  @override
  String get childSafeScreensPendingTitle => '보호자가 설정을 정할 때까지 기다려 주세요';

  @override
  String get childSafeScreensPendingSignatureMismatch => '설정의 서명이 일치하지 않습니다.';

  @override
  String childSafeScreensPendingBody(String parent) {
    return '$parent와(과) 보호로 연결되어 있습니다. $parent이(가) 사용 방식을 정하면 사용할 수 있습니다.';
  }

  @override
  String get childSafeScreensPendingParent => '보호자';

  @override
  String get childSafeScreensPendingOffline => '지금은 서버에 연결할 수 없습니다.';

  @override
  String get childSafeScreensPendingRefresh => '새로고침';

  @override
  String get childSafeScreensPendingLogout => '로그아웃';

  @override
  String get childSafeScreensPendingRasqLogin => 'RASQ 계정에 로그인';

  @override
  String get clipsNoSession => '세션이 없습니다';

  @override
  String get clipsChildSafeBlocked => '보호자가 이 클립을 막아 두었습니다';

  @override
  String get clipsRetry => '다시 불러오기';

  @override
  String get clipsEmptyTitle => '클립이 비어 있습니다';

  @override
  String get clipsEmptyHint => '게시물 메뉴의 \'클립에 추가\'로 여기에 모을 수 있습니다';

  @override
  String clipsPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String get clipsKindHost => 'RASQ 클립(SNS 통합)';

  @override
  String get clipsKindPrivate => '비공개 클립';

  @override
  String get clipsCaptionSeparator => ' · ';

  @override
  String get clipsLoading => '불러오는 중…';

  @override
  String get clipsLoadMore => '더 불러오기';

  @override
  String clipsActionFailed(String error) {
    return '실패했습니다: $error';
  }

  @override
  String get clipsPublishHint => '공개하면 계정 페이지와 공유 링크에서 볼 수 있습니다';

  @override
  String clipsPublishHintSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '공개하면 계정 페이지와 공유 링크에서 볼 수 있습니다(팔로워 전용 등 $count개는 포함하지 않습니다)',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublishNeedsAccount => '공개하려면 RASQ 계정이 필요합니다';

  @override
  String get clipsPublish => '공개하기';

  @override
  String clipsPublishedPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '공개했습니다(공개 범위를 확인 중인 게시물이 $count개 있습니다)',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublished => '공개했습니다';

  @override
  String clipsPublishedStatusSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '공개 중(팔로워 전용 등 $count개는 포함하지 않았습니다)',
    );
    return '$_temp0';
  }

  @override
  String get clipsPublishedStatus => '공개 중';

  @override
  String get clipsLinkCopied => '링크를 복사했습니다';

  @override
  String get clipsCopyLink => '링크 복사';

  @override
  String get clipsUnpublished => '공개를 중단했습니다';

  @override
  String get clipsUnpublish => '공개 중단';

  @override
  String get clipsAddTitle => '클립에 추가';

  @override
  String get clipsAddAddedHost => '추가됨 · RASQ 클립';

  @override
  String get clipsAddAddedHostPublished => '추가됨 · RASQ 클립(공개 중)';

  @override
  String clipsAddHostRow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 · RASQ 클립(SNS 통합)',
    );
    return '$_temp0';
  }

  @override
  String clipsAddHostRowPublished(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개 · RASQ 클립(SNS 통합) · 공개 중',
    );
    return '$_temp0';
  }

  @override
  String get clipsAddCreate => '새 클립 만들기';

  @override
  String clipsAdded(String name) {
    return '\'$name\'에 추가했습니다';
  }

  @override
  String clipsAddFailed(String error) {
    return '클립에 추가하지 못했습니다: $error';
  }

  @override
  String get clipsCreateTitle => '새 클립';

  @override
  String get clipsCreateNameHint => '클립 이름';

  @override
  String get clipsCreateDescriptionHint => '설명(선택)';

  @override
  String get clipsCreateHost => 'RASQ 클립(SNS 통합)으로 만들기';

  @override
  String get clipsCreateHostSubtitle =>
      '기기에 저장되며, 다른 SNS의 게시물도 같은 클립에 넣을 수 있습니다';

  @override
  String get clipsCreateAndAdd => '만들고 추가';

  @override
  String get clipsIndexFallback => '주제를 특정할 수 없는 게시물';

  @override
  String get clipsIndexSingles => '단발 게시물';

  @override
  String clipsIndexRelated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '관련 게시물 $count개',
    );
    return '$_temp0';
  }

  @override
  String get clipsTocTitle => '목차';

  @override
  String clipsTocPeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$_temp0';
  }

  @override
  String get clipsTocFiltering => '필터링 중';

  @override
  String get clipsNoServer => 'RASQ 계정의 서버가 설정되어 있지 않습니다';

  @override
  String get clipsNotFound => '클립이 없습니다';

  @override
  String get collectionsImportToTimeline => '타임라인에 가져오기';

  @override
  String get collectionsNotFound => '찾을 수 없습니다';

  @override
  String get collectionsNotFoundHint => '삭제되었거나 비공개로 바뀌었습니다';

  @override
  String get collectionsReload => '새로고침';

  @override
  String get collectionsBlockedList => '보호자가 이 리스트를 막아 두었습니다';

  @override
  String get collectionsBlockedClip => '보호자가 이 클립을 막아 두었습니다';

  @override
  String get collectionsMenuCopyLink => '링크 복사';

  @override
  String get collectionsMenuRefresh => '지금 다시 가져오기';

  @override
  String get collectionsMenuMakePrivate => '비공개로 설정';

  @override
  String get collectionsMenuMakePublic => '공개하기';

  @override
  String get collectionsMenuRename => '이름 및 설명 변경';

  @override
  String get collectionsMenuDelete => '삭제';

  @override
  String get collectionsMenuUnpublish => '공개 중지';

  @override
  String get collectionsLinkCopied => '링크를 복사했습니다';

  @override
  String get collectionsRefreshFailed => '다시 가져오지 못했습니다';

  @override
  String get collectionsRefreshed => '다시 가져왔습니다';

  @override
  String get collectionsRenameTitle => '이름 및 설명';

  @override
  String get collectionsSave => '저장';

  @override
  String get collectionsNameHint => '이름';

  @override
  String get collectionsDescriptionHint => '설명(선택)';

  @override
  String collectionsDeleteConfirmTitle(String name) {
    return '\'$name\'을(를) 삭제할까요?';
  }

  @override
  String get collectionsDeleteConfirmMessage => '팔로우한 사람들의 목록에서도 사라집니다.';

  @override
  String get collectionsDeleteButton => '삭제';

  @override
  String get collectionsCancel => '취소';

  @override
  String collectionsActionFailed(String error) {
    return '실패했습니다: $error';
  }

  @override
  String get collectionsTabPosts => '게시물';

  @override
  String get collectionsTabTopics => '화제 목차';

  @override
  String get collectionsTabMembers => '멤버';

  @override
  String get collectionsTabServers => '서버';

  @override
  String get collectionsStatusRefreshedOnView => '볼 때 새로 고쳤습니다';

  @override
  String get collectionsStatusRefreshFailed => '다시 가져오지 못했습니다(이전 내용입니다)';

  @override
  String get collectionsStatusFollowingHint =>
      '멤버와 같은 서버에 속해 있거나 멤버를 팔로우하고 있으면 볼 때 새로워집니다';

  @override
  String get collectionsKindList => 'RASQ 리스트';

  @override
  String get collectionsKindClip => 'RASQ 클립';

  @override
  String get collectionsPrivate => '비공개';

  @override
  String get collectionsPublic => '공개';

  @override
  String collectionsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$_temp0';
  }

  @override
  String collectionsItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String collectionsFollowerCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '팔로워 $count',
    );
    return '$_temp0';
  }

  @override
  String collectionsUpdatedAgo(String ago) {
    return '업데이트 $ago';
  }

  @override
  String get collectionsSeparator => ' · ';

  @override
  String get collectionsFollowing => '팔로잉';

  @override
  String get collectionsFollow => '팔로우';

  @override
  String get collectionsNoPostsYet => '아직 게시물이 없습니다';

  @override
  String get collectionsNoPostsHintEmpty =>
      '사용자 페이지의 … → \'RASQ 리스트에 추가\'로 사람을 넣을 수 있습니다';

  @override
  String get collectionsNoPostsHintCollecting => '볼 수 있는 사람이 열 때 모입니다';

  @override
  String get collectionsClipEmpty => '클립이 비어 있습니다';

  @override
  String get collectionsItemGone =>
      '이 게시물은 더 이상 볼 수 없습니다(삭제되었거나 공개 범위가 바뀌었습니다)';

  @override
  String get collectionsItemChecking => '공개 범위를 확인하는 중';

  @override
  String get collectionsAddMembers => '멤버 추가';

  @override
  String collectionsMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명을 추가했습니다',
    );
    return '$_temp0';
  }

  @override
  String collectionsAddFailed(String error) {
    return '추가하지 못했습니다: $error';
  }

  @override
  String get collectionsNoMembers => '멤버가 없습니다';

  @override
  String get collectionsNoMembersHint =>
      '\'멤버 추가\' 또는 사용자 페이지의 … → \'RASQ 리스트에 추가\'';

  @override
  String collectionsMemberSubtitle(String handle, String kind) {
    return '@$handle · $kind';
  }

  @override
  String get collectionsRemoveFromListTooltip => '리스트에서 제거';

  @override
  String collectionsRemoveFailed(String error) {
    return '제거하지 못했습니다: $error';
  }

  @override
  String get collectionsNotFetchableHint =>
      '리스트에 있는 사람의 정보를 가져올 수 있는 계정이 없습니다(멤버와 같은 서버의 계정이거나 멤버를 팔로우해야 합니다)';

  @override
  String get collectionsNoServer => 'RASQ 계정의 서버가 설정되어 있지 않습니다';

  @override
  String collectionsCheckFailed(String error) {
    return '확인하지 못했습니다: $error';
  }

  @override
  String get collectionsPickerEmpty => '아직 RASQ 리스트가 없습니다';

  @override
  String get collectionsPickerNoHits => '찾을 수 없습니다';

  @override
  String get collectionsPickerMine => '내 리스트';

  @override
  String get collectionsPickerNotFetchable => '가져올 수 없음';

  @override
  String get collectionsNotLoggedIn => '로그인하지 않았습니다';

  @override
  String collectionsImportRejected(String name, String reason) {
    return '\'$name\'을(를) 가져올 수 없습니다($reason)';
  }

  @override
  String collectionsAlreadyImported(String name) {
    return '\'$name\'은(는) 이미 홈 타임라인에 들어 있습니다';
  }

  @override
  String collectionsImported(String name) {
    return '\'$name\'을(를) 홈 타임라인에 가져왔습니다(탭 줄의 톱니바퀴에서 확인할 수 있습니다)';
  }

  @override
  String get collectionsTileOpen => '보러 가기';

  @override
  String get collectionsCreateNeedsAccount => 'RASQ 리스트를 만들려면 RASQ 계정이 필요합니다';

  @override
  String get collectionsCreateTitle => '새 RASQ 리스트';

  @override
  String get collectionsListNameHint => '리스트 이름';

  @override
  String get collectionsPublishSwitch => '공개하기';

  @override
  String get collectionsPublishSwitchSubtitle =>
      '계정 페이지와 공유 링크에서 볼 수 있습니다. 팔로우한 사람이 볼 때도 새로워집니다';

  @override
  String get collectionsCreateButton => '만들기';

  @override
  String collectionsCreateFailed(String error) {
    return '만들지 못했습니다: $error';
  }

  @override
  String get collectionsUseNeedsAccount => 'RASQ 리스트를 사용하려면 RASQ 계정이 필요합니다';

  @override
  String collectionsLoadListsFailed(String error) {
    return '리스트를 불러오지 못했습니다: $error';
  }

  @override
  String get collectionsAddToListTitle => 'RASQ 리스트에 추가';

  @override
  String collectionsAddToListSubtitlePublic(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$_temp0 · 공개';
  }

  @override
  String collectionsAddToListSubtitlePrivate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$_temp0 · 비공개';
  }

  @override
  String get collectionsCreateNewList => '새 리스트 만들기';

  @override
  String collectionsAddedTo(String name) {
    return '\'$name\'에 추가했습니다';
  }

  @override
  String collectionsAlreadyIn(String name) {
    return '이미 \'$name\'에 들어 있습니다';
  }

  @override
  String get composeTargetNormalTitle => '노트 작성';

  @override
  String get composeTargetReplyTitle => '답글';

  @override
  String get composeTargetQuoteTitle => '인용';

  @override
  String get composeEmojiPickerTitle => '이모지';

  @override
  String get composeEmojiPickerClose => '닫기';

  @override
  String get composePollRemoveTooltip => '투표 삭제';

  @override
  String composePollChoiceHint(int index) {
    return '선택지 $index';
  }

  @override
  String get composePollChoiceDeleteTooltip => '삭제';

  @override
  String get composePollAddChoice => '선택지 추가';

  @override
  String get composePollTimed => '기한 설정';

  @override
  String get composePollMultiple => '복수 선택';

  @override
  String get composePollUnitDays => '일';

  @override
  String get composePollUnitHours => '시간';

  @override
  String get composePollUnitMinutes => '분';

  @override
  String get composePollUnitSeconds => '초';

  @override
  String get composeDraftsTitle => '초안';

  @override
  String get composeDraftsCancel => '취소';

  @override
  String get composeDraftsDelete => '삭제';

  @override
  String get composeDraftsSaveAndClose => '현재 내용을 저장하고 닫기';

  @override
  String get composeDraftsOverwriteAndClose => '현재 내용으로 덮어쓰고 닫기';

  @override
  String get composeDraftsSaveNewAndClose => '현재 내용을 새 초안으로 만들고 닫기';

  @override
  String get composeDraftsEmpty => '초안이 없습니다';

  @override
  String composeDraftsAttachmentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '첨부 $count',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftsOpenNow => '편집 중';

  @override
  String get composeDraftsSelectOff => '선택 해제';

  @override
  String get composeDraftsSelect => '선택';

  @override
  String composeDraftsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String composeDraftTitleAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '(첨부 $count개)',
    );
    return '$_temp0';
  }

  @override
  String get composeDraftTitleEmpty => '(본문 없음)';

  @override
  String get composeDraftTargetReply => '답글';

  @override
  String get composeDraftTargetQuote => '인용';

  @override
  String get composeDraftTargetPost => '게시물';

  @override
  String get composeReactionAcceptanceAll => '전체';

  @override
  String get composeReactionAcceptanceLikeOnly => '좋아요만';

  @override
  String get composeReactionAcceptanceLikeOnlyForRemote => '외부에서는 좋아요만';

  @override
  String get composeReactionAcceptanceNonSensitiveOnly => '민감하지 않은 것만';

  @override
  String
  get composeReactionAcceptanceNonSensitiveOnlyForLocalLikeOnlyForRemote =>
      '민감하지 않은 것만 & 외부에서는 좋아요만';

  @override
  String get composeEmojiResizeHandleSemantics => '크기 조절 핸들';

  @override
  String get composeEmojiSectionHistory => '최근 사용';

  @override
  String get composeEmojiSectionPrediction => '추천';

  @override
  String get composeEmojiBundleEditTitle => '번들 편집';

  @override
  String get composeEmojiBundleEditMessage => '번들 편집은 준비 중입니다.';

  @override
  String get composeEmojiSectionDefault => '기본';

  @override
  String get composeEmojiCustomEmpty => '커스텀 이모지가 없습니다';

  @override
  String get composeEmojiSectionServer => '서버';

  @override
  String get composeEmojiGenreOther => '기타';

  @override
  String composeEmojiGroupHeading(String name) {
    return '· $name';
  }

  @override
  String get composeEmojiSearchHint => '검색';

  @override
  String get composeEmojiStickersEmpty =>
      '사용할 수 있는 에셋 팩이 없습니다(스토어에서 설치할 수 있습니다)';

  @override
  String get composeEmojiSectionSearchResults => '검색 결과';

  @override
  String get composeEmojiSearchNoHit => '찾을 수 없습니다';

  @override
  String composeEmojiIndexProgress(int done, int total) {
    return '의미 검색 준비 중 $done / $total';
  }

  @override
  String get composeVisibilityHome => '홈';

  @override
  String get composeVisibilityFollowers => '팔로워';

  @override
  String get composeVisibilityPublic => '공개';

  @override
  String composeVisibilityTooltip(String label) {
    return '공개 범위: $label';
  }

  @override
  String get composeLocalOnlyOnTooltip => '연합 안 함(이 서버만)';

  @override
  String get composeLocalOnlyOffTooltip => '연합함(탭하여 연합 안 함으로)';

  @override
  String composeReactionAcceptanceTooltip(String label) {
    return '리액션 허용: $label';
  }

  @override
  String get composeOn => '켜짐';

  @override
  String get composeOff => '꺼짐';

  @override
  String composeTextPluginTooltip(String label, String state) {
    return '$label($state · 길게 눌러 설정)';
  }

  @override
  String get composeTextPluginHereTitle => '이 작성 화면에서 켜기';

  @override
  String get composeTextPluginHereSubtitle => '본문의 변화를 이 플러그인에 전달합니다';

  @override
  String get composeTextPluginAutoTitle => '다음에도 자동으로 켜기';

  @override
  String composeTextPluginAutoDefault(String state) {
    return '플러그인 기본값($state)';
  }

  @override
  String composeTextPluginAutoOverridden(String state) {
    return '설정에서 덮어씀(기본값은 $state)';
  }

  @override
  String get composeTextPluginResetDefault => '플러그인 기본값으로 되돌리기';

  @override
  String composeTextPluginCaption(String name) {
    return '$name · 텍스트 가공';
  }

  @override
  String get composeHeaderPost => '게시';

  @override
  String get composeHeaderReply => '답글';

  @override
  String get composeHeaderQuote => '인용';

  @override
  String get composeCloseOverwriteTitle => '초안을 덮어쓸까요?';

  @override
  String get composeCloseSaveTitle => '초안으로 저장할까요?';

  @override
  String get composeCloseOverwriteMessage => '열려 있는 초안을 현재 내용으로 덮어쓰고 닫습니다.';

  @override
  String get composeCloseSaveMessage => '현재 내용을 초안으로 남기고 닫습니다.';

  @override
  String get composeCloseOverwrite => '덮어쓰기';

  @override
  String get composeCloseSaveNew => '새로 저장';

  @override
  String get composeCloseSave => '저장';

  @override
  String get composeCloseDiscard => '변경 사항 버리기';

  @override
  String get composeCancel => '취소';

  @override
  String get composeMultiNormal => '일반 게시';

  @override
  String get composeMultiLinked => '노드 연동';

  @override
  String get composeRasqTarget => 'RASQ에 게시';

  @override
  String get composeTargetMatchedTooltip => '게시 대상 노드의 조건과 일치';

  @override
  String get composeTargetCustomize => '게시 대상 맞춤 설정';

  @override
  String get composeMultiSelectOff => '복수 선택 해제';

  @override
  String get composeMultiSelectOn => '복수 선택 모드';

  @override
  String get composeLinkedConfirmTitle => '연동 게시 확인';

  @override
  String get composeLinkedConfirmSame => '같은 내용으로 연동 게시';

  @override
  String get composeLinkedConfirmAlt => '대체 형식으로 연동 게시';

  @override
  String get composeLinkedConfirmPost => '이 내용으로 게시';

  @override
  String get composeRasqNoServer => 'RASQ 서버가 설정되지 않았습니다';

  @override
  String get composeRasqOverLimit => 'RASQ의 제한을 초과했습니다';

  @override
  String get composeRasqTextOnlyTip => 'RASQ의 답글은 텍스트만 가능합니다';

  @override
  String composePickImageFailed(String error) {
    return '이미지를 선택할 수 없습니다: $error';
  }

  @override
  String get composePickVideoLibrary => '보관함의 동영상';

  @override
  String get composePickVideoFile => '파일에서(동영상 / 오디오)';

  @override
  String composePickNotMedia(String name) {
    return '동영상 / 오디오 파일이 아닙니다: $name';
  }

  @override
  String composePickMediaFailed(String error) {
    return '동영상 / 오디오를 선택할 수 없습니다: $error';
  }

  @override
  String get composeRasqNotLoggedIn => 'RASQ 계정에 로그인하지 않았습니다';

  @override
  String composeRasqMediaTooLarge(int mb) {
    return 'RASQ에 게시할 때 동영상 / 오디오는 1개당 $mb MB까지입니다';
  }

  @override
  String get composeRasqReplyTextOnly =>
      'RASQ의 답글은 텍스트만 가능합니다(첨부 / 투표는 추가할 수 없습니다)';

  @override
  String composeRasqReplyMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ의 답글은 $count자까지입니다',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ 게시물의 첨부는 $count개까지입니다',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxChars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ 게시물은 $count자까지입니다',
    );
    return '$_temp0';
  }

  @override
  String composeRasqMaxPollChoices(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'RASQ 게시물의 투표 선택지는 $count개까지입니다',
    );
    return '$_temp0';
  }

  @override
  String get composeRasqPosted => 'RASQ에 게시했습니다';

  @override
  String get composeRasqReplyQuota => 'RASQ의 답글은 100개까지입니다. 오래된 답글을 삭제해 주세요';

  @override
  String get composeRasqPostQuota => 'RASQ 게시물은 3개까지입니다. 오래된 게시물을 삭제해 주세요';

  @override
  String composeRasqPostFailed(String error) {
    return 'RASQ에 게시할 수 없습니다: $error';
  }

  @override
  String get composePolicyConfirmTitle => '보내기 전 확인';

  @override
  String get composePolicyConfirmSend => '이대로 보내기';

  @override
  String get composePolicyConfirmEdit => '다시 쓰기';

  @override
  String get composeSending => '보내는 중…';

  @override
  String composeModerationDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '검열로 인한 지연: $seconds초 남음',
    );
    return '$_temp0';
  }

  @override
  String composeUploading(int index, int total) {
    return '업로드 중 $index/$total';
  }

  @override
  String composeLinkedFailed(String errors) {
    return '연동 게시에 실패했습니다: $errors(본 게시물은 게시되었습니다)';
  }

  @override
  String composeSendFailed(String error) {
    return '전송에 실패했습니다: $error';
  }

  @override
  String composePostNoticeForAccount(String account, String message) {
    return '$account: $message';
  }

  @override
  String get composeDraftsButton => '초안';

  @override
  String get composeDirectReplyNote => '다이렉트 게시물에 대한 답글(상대방에게만 전달됩니다)';

  @override
  String get composeChooseTargetTooltip => '게시 대상 선택';

  @override
  String get composeCwHint => '내용 경고..';

  @override
  String get composeCwRemoveTooltip => '내용 경고 제거';

  @override
  String get composeDmHint => '메시지 입력..';

  @override
  String get composeTextHint => '좋은 일이 있기를!';

  @override
  String composeHashtagUsers(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag  $count명',
    );
    return '$_temp0';
  }

  @override
  String get composeToolCamera => '카메라';

  @override
  String get composeToolImage => '이미지';

  @override
  String get composeToolVideo => '동영상 / 오디오';

  @override
  String get composeToolCw => '숨기기(내용 경고)';

  @override
  String get composeToolPoll => '투표';

  @override
  String get composeToolEmoji => '이모지';

  @override
  String get composeSendReply => '답글';

  @override
  String get composeSend => '보내기';

  @override
  String get composeAttachmentRemove => '삭제';

  @override
  String get composeAttachmentEdit => '편집';

  @override
  String get composeAttachmentUnsensitive => '민감 해제';

  @override
  String get composeAttachmentSensitive => '민감으로 설정';

  @override
  String get composeMediaPickTypeLabel => '동영상 / 오디오';

  @override
  String get composeMediaMotionVideoLabel =>
      '동영상으로 만들기(첨부된 동영상을 타일 안에서 재생, 소리 포함)';

  @override
  String get composeMediaMotionAudioLabel => '동영상으로 만들기(타일 정지 이미지 + 첨부된 오디오)';

  @override
  String composeMediaMotionAnimatedLabel(int fps, int seconds) {
    return '동영상으로 만들기(움직이는 모습을 초당 $fps프레임으로 $seconds초)';
  }

  @override
  String get composeMediaMotionVideoNote => '이 게시물에는 동영상이 첨부되어 있습니다.';

  @override
  String get composeMediaMotionAudioNote => '이 게시물에는 오디오가 첨부되어 있습니다.';

  @override
  String get composeMediaMotionAnimatedNote =>
      '이 게시물에는 움직이는 그림(GIF / 움직이는 MFM)이 있습니다.';

  @override
  String get composeMediaPostNotOnScreen => '게시물이 화면에 표시되어 있지 않습니다';

  @override
  String get composeMediaSourceFetchFailed => '원본 파일을 가져오지 못했습니다';

  @override
  String composeMediaFormatUnreadable(String ext) {
    return '이 기기는 $ext 형식을 읽을 수 없습니다(정지 이미지로는 붙일 수 있습니다)';
  }

  @override
  String composeMediaSourceOpenFailed(String ext, int bytes) {
    return '원본 파일(.$ext, $bytes바이트)을 열지 못했습니다';
  }

  @override
  String get composeMediaTabMine => '내 게시물';

  @override
  String get composeMediaTabReacted => '리액션';

  @override
  String get composeMediaTabFavorites => '북마크';

  @override
  String get composeMediaTabSearches => '최근 검색';

  @override
  String get composeMediaStyleThread => '스레드';

  @override
  String get composeMediaStyleInline => '인라인';

  @override
  String get composeMediaPostImageTitle => '노트 이미지 추가';

  @override
  String get composeMediaCancel => '취소';

  @override
  String get composeMediaConfirm => '확인';

  @override
  String get composeMediaNoAccount => '계정이 없습니다';

  @override
  String get composeMediaSearchUnsupported => '이 SNS에서는 게시물 검색을 사용할 수 없습니다';

  @override
  String composeMediaTabUnsupported(String tab) {
    return '이 SNS에서는 \'$tab\'을(를) 사용할 수 없습니다';
  }

  @override
  String composeMediaFetchFailed(String error) {
    return '가져오지 못했습니다: $error';
  }

  @override
  String get composeMediaCaptureRetry =>
      '선택한 게시물이 화면에 표시된 상태에서 \'확인\'을 다시 눌러 주세요';

  @override
  String composeMediaVideoFailed(String error) {
    return '동영상으로 만들지 못했습니다: $error';
  }

  @override
  String get composeMediaFilterHistoryHint => '검색 기록 필터';

  @override
  String get composeMediaFilterListHint => '목록 필터';

  @override
  String get composeMediaFilterFromHistoryTooltip => '최근 검색에서 입력';

  @override
  String get composeMediaStyleHeading => '모양';

  @override
  String composeMediaSearchResultsTitle(String query) {
    return '\'$query\' 검색 결과';
  }

  @override
  String get composeMediaSearchBack => '최근 검색으로 돌아가기';

  @override
  String composeMediaExcludedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '공개 범위를 제한한 게시물 $count개는 표시하지 않습니다.',
    );
    return '$_temp0';
  }

  @override
  String get composeMediaAsVideoOffNote => '끔 = 그 순간의 정지 이미지';

  @override
  String get composeMediaExporting => '동영상으로 만드는 중…';

  @override
  String get composeMediaHistoryEmpty => '최근 검색이 없습니다(검색 홈에서 검색하면 여기에 표시됩니다)';

  @override
  String get composeMediaHistoryNoMatch => '일치하는 검색이 없습니다';

  @override
  String get composeMediaPostsEmpty => '게시물이 없습니다';

  @override
  String get composeMediaPostsNoMatch =>
      '일치하는 게시물이 없습니다(\'더 보기\'로 계속 찾을 수 있습니다)';

  @override
  String get composeMediaLoadMore => '더 보기';

  @override
  String get composeMfmFnX2 => '2배로 확대';

  @override
  String get composeMfmFnX3 => '3배로 확대';

  @override
  String get composeMfmFnX4 => '4배로 확대';

  @override
  String get composeMfmFnSmall => '작게 표시';

  @override
  String get composeMfmFnCenter => '가운데 정렬';

  @override
  String get composeMfmFnBlur => '흐리게(호버 / 탭하면 해제)';

  @override
  String get composeMfmFnRotate => '회전';

  @override
  String get composeMfmPropRotateDeg => '각도(기본값 90)';

  @override
  String get composeMfmFnFlip => '반전';

  @override
  String get composeMfmPropFlipH => '좌우';

  @override
  String get composeMfmPropFlipV => '상하';

  @override
  String get composeMfmFnFg => '글자 색';

  @override
  String get composeMfmPropFgColor => '16진수(예: ff0000)';

  @override
  String get composeMfmFnBg => '배경색';

  @override
  String get composeMfmPropBgColor => '16진수(예: ffff00)';

  @override
  String get composeMfmFnShake => '흔들기';

  @override
  String get composeMfmPropShakeSpeed => '예: 0.5s';

  @override
  String get composeMfmFnSpin => '회전 애니메이션';

  @override
  String get composeMfmPropSpinSpeed => '예: 1.5s';

  @override
  String get composeMfmPropSpinLeft => '역회전';

  @override
  String get composeMfmPropSpinAlternate => '왕복';

  @override
  String get composeMfmPropSpinX => '가로축';

  @override
  String get composeMfmPropSpinY => '세로축';

  @override
  String get composeMfmFnJump => '점프';

  @override
  String get composeMfmPropJumpSpeed => '예: 0.75s';

  @override
  String get composeMfmFnBounce => '바운스';

  @override
  String get composeMfmPropBounceSpeed => '예: 0.75s';

  @override
  String get composeMfmFnRainbow => '무지개색';

  @override
  String get composeMfmPropRainbowSpeed => '예: 1s';

  @override
  String get composeMfmFnTwitch => '움찔움찔';

  @override
  String get composeMfmPropTwitchSpeed => '예: 0.5s';

  @override
  String get composeMfmFnJelly => '말랑말랑';

  @override
  String get composeMfmPropJellySpeed => '예: 1s';

  @override
  String get composeMfmFnTada => '짜잔';

  @override
  String get composeMfmPropTadaSpeed => '예: 1s';

  @override
  String get composeMfmFnPlain => '꾸밈 비활성화';

  @override
  String get composeMfmFnFont => '글꼴 바꾸기';

  @override
  String get composeMfmPropFontSerif => '명조체(serif)';

  @override
  String get composeMfmPropFontMonospace => '고정폭(monospace)';

  @override
  String get composeMfmPropFontCursive => '필기체(cursive)';

  @override
  String get composeMfmPropFontFantasy => '장식체(fantasy)';

  @override
  String get composeMfmFnPosition => '위치 옮기기';

  @override
  String get composeMfmPropPositionX => '가로(글자 크기 단위, 예: 0.5)';

  @override
  String get composeMfmPropPositionY => '세로(글자 크기 단위, 예: -1)';

  @override
  String get composeMfmFnScale => '확대/축소(최대 5배)';

  @override
  String get composeMfmPropScaleX => '가로 배율(예: 0.5)';

  @override
  String get composeMfmPropScaleY => '세로 배율(예: 1.5)';

  @override
  String get composeMfmFnBorder => '테두리';

  @override
  String get composeMfmPropBorderStyle => '선 종류(solid / dashed / dotted 등)';

  @override
  String get composeMfmPropBorderWidth => '굵기(px, 기본값 1)';

  @override
  String get composeMfmPropBorderColor => '16진수(기본값은 강조색)';

  @override
  String get composeMfmPropBorderRadius => '모서리 둥글기(px)';

  @override
  String get composeMfmPropBorderNoclip => '넘치는 부분을 자르지 않음';

  @override
  String get composeMfmFnRuby => '루비(\'본문 읽는 법\' 형식으로 작성)';

  @override
  String get composeMfmSampleRuby => '漢字 한자';

  @override
  String get composeMfmFnUnixtime => 'UNIX 시간(초)을 날짜와 시간으로 표시';

  @override
  String get composeMfmFnSparkle => '반짝반짝';

  @override
  String get composeMfmPropDelay => '시작 지연(예: 0.5s)';

  @override
  String get composeMfmSearchButton => '검색';

  @override
  String get composeMfmMarkdownBoldName => '굵게';

  @override
  String get composeMfmMarkdownBoldDescription => '**굵게**로 표시';

  @override
  String get composeMfmMarkdownItalicName => '기울임꼴';

  @override
  String get composeMfmMarkdownItalicDescription => '*기울임꼴*로 표시';

  @override
  String get composeMfmMarkdownStrikeName => '취소선';

  @override
  String get composeMfmMarkdownStrikeDescription => '~~취소선~~으로 표시';

  @override
  String get composeMfmMarkdownInlineCodeName => '인라인 코드';

  @override
  String get composeMfmMarkdownInlineCodeDescription => '`코드`로 표시';

  @override
  String get composeMfmMarkdownCodeBlockName => '코드 블록';

  @override
  String get composeMfmMarkdownCodeBlockDescription => '여러 줄의 코드를 테두리 안에 표시';

  @override
  String get composeMfmMarkdownHeadingName => '제목';

  @override
  String get composeMfmMarkdownHeadingDescription => '줄 앞에 #을 붙이기';

  @override
  String get composeMfmMarkdownLinkName => '링크';

  @override
  String get composeMfmMarkdownLinkDescription => '[표시 이름](URL) 형식';

  @override
  String get composeMfmClose => '닫기';

  @override
  String get composeMfmSample => '샘플';

  @override
  String composeMfmSampleWithEmoji(String emoji) {
    return '샘플 $emoji';
  }

  @override
  String get composeMfmBackTooltip => '목록으로 돌아가기';

  @override
  String get composeMfmApply => '확인';

  @override
  String get composeMfmNoProps => '이 함수에는 속성이 없습니다.';

  @override
  String get composePolicyTypeSexual => '성적인 표현';

  @override
  String get composePolicyTypeViolence => '폭력·협박';

  @override
  String get composePolicyTypeSelfHarm => '자해·자살';

  @override
  String get composePolicyTypeHarassment => '폭언·괴롭힘';

  @override
  String get composePolicyTypePersonalInfo => '개인정보(전화번호, 이메일 주소, 주소 등)';

  @override
  String get composePolicyTypeLink => '외부 링크';

  @override
  String get composePolicyTypeMedia => '이미지·동영상';

  @override
  String get composePolicyTypeStimulus => '강한 표현';

  @override
  String get composePolicyTypeTopic => '지정된 주제';

  @override
  String get composePolicyWhoGuardian => '보호자 설정';

  @override
  String get composePolicyWhoSanction => '계정 제한';

  @override
  String composePolicyBlockedMediaUnmeasured(String who) {
    return '$who에 따라 이미지·동영상을 보낼 수 없습니다(이 기기에서는 첨부를 확인할 수 없습니다). 첨부를 제거해 주세요';
  }

  @override
  String composePolicyBlockedUnmeasured(String who, String label) {
    return '$who에 따라 지금은 보낼 수 없습니다(이 기기에서는 \'$label\'을(를) 확인할 수 없습니다)';
  }

  @override
  String composePolicyBlocked(String who, String label) {
    return '$who에 따라 \'$label\'에 해당하는 내용은 보낼 수 없습니다. 고쳐 써 주세요';
  }

  @override
  String composePolicyWarn(String label, String who) {
    return '\'$label\'에 해당할 수 있습니다($who). 이대로 보낼까요?';
  }

  @override
  String customShareAddToRoom(String room) {
    return '\'$room\'에 추가';
  }

  @override
  String customShareProposeToRoom(String room) {
    return '\'$room\'에서 제안';
  }

  @override
  String get customSharePlaceOnProfile => '프로필에 두기';

  @override
  String get customShareInviteBySwing => 'Swing으로 초대(함께 사용)';

  @override
  String get customShareInstallToShare => '설치하면 프로필이나 초대로 공유할 수 있습니다';

  @override
  String customAddedToRoom(String name) {
    return '\'$name\'을(를) 룸에 추가했습니다';
  }

  @override
  String customAddToRoomFailed(String error) {
    return '추가하지 못했습니다: $error';
  }

  @override
  String customShareProposedToRoom(String name) {
    return '\'$name\'을(를) 룸에서 제안했습니다';
  }

  @override
  String get customSharePlacedOnProfile => '프로필에 두었습니다';

  @override
  String customPlaceFailed(String error) {
    return '두지 못했습니다: $error';
  }

  @override
  String customInvitedBySwingNotified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return 'Swing으로 초대했습니다(RASQ 알림 $_temp0)';
  }

  @override
  String get customInvitedBySwing => 'Swing으로 초대했습니다';

  @override
  String get customInviteTitle => 'Swing으로 초대';

  @override
  String customInviteSendFailed(String error) {
    return '보내지 못했습니다: $error';
  }

  @override
  String customInviteHeading(String title) {
    return '\'$title\'에 초대';
  }

  @override
  String get customInviteIntroOwnPage =>
      'Swing으로 전달합니다. 본 사람은 내 페이지에 함께 들어옵니다.';

  @override
  String get customInviteIntroCurrentPage =>
      'Swing으로 전달합니다. 본 사람은 지금 열려 있는 페이지에 함께 들어옵니다.';

  @override
  String get customInviteHelp =>
      '받는 사람: 누르기 = Swing 전달 · 두 번 연속 누르기 = RASQ 알림도 보내기 🔔';

  @override
  String get customInviteFollowers => '팔로워';

  @override
  String get customInviteNoLists => 'RASQ 리스트를 만들면 리스트에 넣은 사람도 초대할 수 있습니다';

  @override
  String get customInviteTextHint => '한마디(선택 사항)';

  @override
  String get customInviteTtl => '사라지기까지';

  @override
  String customInviteTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간',
    );
    return '$_temp0';
  }

  @override
  String get customInviteSendWithNotify => 'Swing으로 초대(알림도 보내기)';

  @override
  String get customInviteErrorVersionNotAvailable =>
      '이 플러그인은 연결된 RASQ 서버의 스토어에서 배포되지 않습니다(심사를 통과한 버전이 없습니다). 앱에 들어 있는 샘플 그대로는 함께 사용할 수 없습니다';

  @override
  String get customInviteErrorNotShared => '함께 사용하는 플러그인이 아닙니다';

  @override
  String get customInviteErrorSessionNotShareable =>
      '이 페이지의 세션은 Swing으로 초대할 수 없습니다';

  @override
  String get customInviteErrorSwingLimit => '동시에 보내 둘 수 있는 Swing은 최대 20개입니다';

  @override
  String customInviteTargetWithNotify(String label) {
    return '$label(알림도 보내기)';
  }

  @override
  String get customInviteTargetHint => '누르면 선택 / 해제. 두 번 연속 누르면 알림도 보냅니다';

  @override
  String get customProfileLimit => '페이지에는 최대 8개까지 둘 수 있습니다';

  @override
  String get customProfileSideloadReplace => '다시 올리기(새 버전)';

  @override
  String get customProfileSideloadRemove => '페이지에서 제거';

  @override
  String customProfileRemoveFailed(String error) {
    return '제거하지 못했습니다: $error';
  }

  @override
  String customLoadFailed(String error) {
    return '불러오지 못했습니다: $error';
  }

  @override
  String get customProfileEmptyMine =>
      '\'+ 추가\'로 Markdown 페이지나 커스텀 플러그인을 둘 수 있습니다. 방문자가 여기서 열 수 있습니다.';

  @override
  String get customProfileEmpty => '아직 페이지가 없습니다.';

  @override
  String get customProfileSharedNotStarted => '함께 사용(아직 시작되지 않음)';

  @override
  String get customProfileShared => '함께 사용';

  @override
  String get customSolo => '혼자 사용';

  @override
  String customProfileHostPage(String title) {
    return '$title 호스트용 페이지';
  }

  @override
  String get customProfileHostPageSubtitle => '나에게만 표시됩니다';

  @override
  String get customProfileMdPageWithDraft => '페이지 · 작성 중인 초안 있음';

  @override
  String get customProfileMdPage => '페이지';

  @override
  String get customProfileUntitled => '(제목 없음)';

  @override
  String get customProfileDraft => '초안(이 기기에만)';

  @override
  String customProfileSideloadSubtitle(String version) {
    return '직접 만든 플러그인 · 제한 모드 · v$version';
  }

  @override
  String get customMenu => '메뉴';

  @override
  String get customProfileAdd => '추가';

  @override
  String get customProfileLoginToPlace => 'RASQ 계정에 로그인하면 둘 수 있습니다';

  @override
  String customProfileSideloadPlaced(String name) {
    return '\'$name\'을(를) 두었습니다(방문자의 기기에서는 제한 모드로 작동합니다)';
  }

  @override
  String get customProfileSideloadErrorNotProfilePage =>
      'RASQ 페이지에 둘 수 있는 것은 프로필 화면이 있는 혼자 사용하는 페이지형뿐입니다';

  @override
  String get customProfileSideloadErrorLimit => '직접 만든 플러그인은 최대 4개입니다';

  @override
  String get customProfileSideloadErrorInvalidPackage =>
      '패키지를 읽지 못했습니다(.rspkg / .rasqpkg)';

  @override
  String get customClose => '닫기';

  @override
  String get customProfileAddTitle => '페이지 추가';

  @override
  String get customProfileAddMd => 'Markdown 페이지 작성';

  @override
  String get customProfileAddMdSubtitle =>
      '초안은 이 기기에 남고 \'공개\'를 누르면 게시됩니다. MFM은 HTML 같은 태그로';

  @override
  String get customProfileAddSideload => '직접 만든 플러그인 두기(.rspkg / .rasqpkg)';

  @override
  String get customProfileAddSideloadSubtitle =>
      '심사하지 않은 플러그인입니다. 방문자의 기기에서는 제한 모드(통신 등 없음)로 작동합니다';

  @override
  String get customProfileAddStoreSection => '스토어의 커스텀 플러그인';

  @override
  String get customProfileAddStoreEmpty => '페이지에 둘 수 있는 커스텀 플러그인을 설치하지 않았습니다';

  @override
  String get customProfileAddStorePlaced => '두는 중(누르면 제거)';

  @override
  String get customProfileAddStoreTapToPlace => '누르면 두기';

  @override
  String get customProfileAddStoreHasHostPage => '호스트용 페이지 있음';

  @override
  String get customListSeparator => ' · ';

  @override
  String customProfileChangeFailed(String error) {
    return '변경하지 못했습니다: $error';
  }

  @override
  String get customSearchStore => '스토어에서 찾기';

  @override
  String get customPluginsTitle => '커스텀 플러그인';

  @override
  String get customPluginsJoinByCode => '초대 코드로 참가';

  @override
  String get customPluginsInviteCode => '초대 코드';

  @override
  String get customPluginsJoin => '참가';

  @override
  String get customPluginsInstalled => '설치됨';

  @override
  String get customPluginsEmpty => '아직 없습니다. 스토어의 \'커스텀\'에서 찾을 수 있습니다.';

  @override
  String get customPluginsShared => '함께 사용 가능';

  @override
  String get customPluginsProfile => '프로필';

  @override
  String get customPluginsSearchStore => '스토어에서 커스텀 플러그인 찾기';

  @override
  String get customPluginsInviteNotFound =>
      '이 초대 코드의 세션을 찾을 수 없습니다(닫혔을 수 있습니다)';

  @override
  String get customPluginsInviteTitle => '초대';

  @override
  String get customPluginsJoinFailed => '참가하지 못했습니다';

  @override
  String get customPageLoadFailed => '불러오지 못했습니다';

  @override
  String customPageNotPagePlugin(String name) {
    return '$name은(는) 페이지형 플러그인이 아닙니다';
  }

  @override
  String customPageSoloPlugin(String name) {
    return '$name은(는) 혼자 사용하는 플러그인입니다(함께 사용할 수 없습니다)';
  }

  @override
  String customPageJoinFailed(String error) {
    return '세션에 들어가지 못했습니다: $error';
  }

  @override
  String get customPageNoPage => '플러그인이 페이지를 반환하지 않았습니다';

  @override
  String customPageWrongSession(String name) {
    return '$name의 세션이 아닙니다';
  }

  @override
  String customPageLeftWrongSession(String name) {
    return '$name의 세션이 아니어서 나왔습니다';
  }

  @override
  String customPageDisconnectedWithError(String error) {
    return '연결이 끊겼습니다: $error';
  }

  @override
  String get customPageDisconnected => '연결이 끊겼습니다';

  @override
  String get customPageError => '오류';

  @override
  String get customPageMenuInvite => '초대(Swing으로 보내기)';

  @override
  String get customPageMenuCopyCode => '초대 코드 복사';

  @override
  String get customPageMenuCopyLink => '초대 링크 복사';

  @override
  String customPageMenuParticipants(int count) {
    return '참가자($count)';
  }

  @override
  String get customPageMenuCloseSession => '세션 닫기';

  @override
  String get customPageViewInStore => '스토어에서 보기';

  @override
  String customPageCodeCopied(String code) {
    return '초대 코드 $code를 복사했습니다';
  }

  @override
  String get customPageLinkCopied => '초대 링크를 복사했습니다';

  @override
  String get customPageParticipants => '참가자';

  @override
  String get customPageCloseConfirmTitle => '세션을 닫을까요?';

  @override
  String get customPageCloseConfirmMessage => '참가 중인 모든 사람의 페이지에서 공유 값이 멈춥니다.';

  @override
  String get customCancel => '취소';

  @override
  String customPageCloseFailed(String error) {
    return '닫지 못했습니다: $error';
  }

  @override
  String get customPageClosedBanner => '이 세션은 닫혔습니다(공유 값은 더 이상 바뀌지 않습니다)';

  @override
  String get customPageConsentBody =>
      '이 페이지를 열어 둔 동안에만 설치하지 않고 실행합니다(닫으면 사라집니다).';

  @override
  String get customPageConsentPermissions => '사용하는 권한';

  @override
  String get customPageConsentAccept => '사용';

  @override
  String get customPageConsentDecline => '그만두기';

  @override
  String get customPageNotInstalled => '설치되어 있지 않습니다';

  @override
  String get customPageNotInstalledHint => '스토어에서 설치하면 열 수 있습니다';

  @override
  String get customPageOpenFailed => '열지 못했습니다';

  @override
  String get customClientHostOnly => '호스트만 배포할 수 있습니다';

  @override
  String get customClientSessionClosed => '세션이 닫혀 있습니다';

  @override
  String get customClientNoToken => 'RASQ 계정의 토큰이 없습니다';

  @override
  String customAstellWaitingApproval(String name) {
    return '\'$name\'은(는) 호스트의 승인을 기다리고 있습니다';
  }

  @override
  String customAstellApproveTitle(String name) {
    return '\'$name\'을(를) 이 룸에서 사용할까요?';
  }

  @override
  String customAstellApproveMessage(String name) {
    return '$name님의 제안입니다. 승인하면 참가 중인 모든 사람이 열 수 있게 됩니다(설치하지 않은 사람은 열 때 임시로 불러옵니다).';
  }

  @override
  String get customAstellApprove => '승인';

  @override
  String customAstellProposed(String name) {
    return '\'$name\'을(를) 제안했습니다(호스트가 승인하면 사용할 수 있습니다)';
  }

  @override
  String get customAstellEmptyHost =>
      '이 룸에서 작동하는 플러그인이 아직 없습니다. 아래의 \'플러그인 추가\'로 추가할 수 있습니다.';

  @override
  String get customAstellEmptyMember =>
      '이 룸에서 작동하는 플러그인이 아직 없습니다. \'플러그인 제안\'으로 호스트에게 요청할 수 있습니다.';

  @override
  String customAstellInUse(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명이 사용 중',
    );
    return '$_temp0';
  }

  @override
  String customAstellInUseAddedBy(int count, String handle) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명이 사용 중',
    );
    return '$_temp0 · @$handle님이 추가';
  }

  @override
  String get customAstellOpen => '열기';

  @override
  String get customAstellRemove => '룸에서 제거';

  @override
  String get customAstellAdd => '플러그인 추가';

  @override
  String get customAstellPropose => '플러그인 제안';

  @override
  String get devGrantDebugAll => '디버그 빌드: 모든 권한';

  @override
  String get devUrlInvalid => 'http(s) URL을 입력해 주세요';

  @override
  String devUrlLoadFailed(String error) {
    return 'URL에서 읽지 못했습니다: $error';
  }

  @override
  String devBoundaryTimelineFailed(String error) {
    return '경계 TL: $error';
  }

  @override
  String devAssetLoadFailed(String error) {
    return '에셋 불러오기 실패: $error';
  }

  @override
  String devPkgLoaded(
    String rootId,
    String version,
    int children,
    String target,
  ) {
    return '.rasqpkg: $rootId $version(하위 $children) → $target을(를) 불러옴.';
  }

  @override
  String devPkgSigned(String fingerprint) {
    return '개발자 키 서명 OK (지문 $fingerprint). 스토어 심사는 통과하지 않았습니다.';
  }

  @override
  String get devPkgUnsigned => '서명 없음 (.sig.json이 없습니다). 출처를 확인할 수 없습니다.';

  @override
  String get devPkgSlotFull => '슬롯에 등록하면 전체 기능 (내 키로 서명)';

  @override
  String get devPkgSlotRestricted =>
      '슬롯에 등록하면 제한 모드 (내 키로 서명하지 않았으므로 통신 / GPU / storage.unsafe / interstitial·system의 FOW / 공유·작성기·뮤트·URL 열기 함수는 차단)';

  @override
  String devPathLoadFailed(String path, String error) {
    return '$path 불러오기 실패 (절대 경로나 ~/로 시작하는 경로로 지정해 주세요): $error';
  }

  @override
  String get devFowClose => '닫기';

  @override
  String get devFowSemantics => '플러그인 FOW';

  @override
  String get devRegisterNeedsMisskey => '실제 등록에는 Misskey 계정으로 로그인해야 합니다';

  @override
  String get devTitle => 'WASM 플러그인 테스트 (dev)';

  @override
  String get devHostHint => '인스턴스 (예: misskey.io)';

  @override
  String get devFetchTimeline => 'TL 가져오기';

  @override
  String get devBoundaryTimeline => '경계 TL';

  @override
  String get devPathHint => '.wasm 경로에서 가져오기 (빈칸 = 동봉 에셋)';

  @override
  String get devLoad => '불러오기';

  @override
  String get devRegisterReal => '실제 등록';

  @override
  String get devUrlHint => 'URL에서 읽기 (심사용 임시 가져오기 링크)';

  @override
  String get devUrlLoad => 'URL에서 읽기';

  @override
  String get devOpenedFromLink =>
      '링크에서 열었습니다. 출처를 확인한 뒤 \'URL에서 읽기\'를 눌러 주세요(심사 중인 버전은 제한 모드로 실행됩니다).';

  @override
  String devParentInstalled(String id, String version) {
    return '부모(기반) 플러그인: $id $version (설치됨)';
  }

  @override
  String devParentMissing(String id, String version) {
    return '부모(기반) 플러그인: $id $version — 먼저 설치해 주세요';
  }

  @override
  String get devOpenInStore => '스토어에서 열기';

  @override
  String devGrantDebugNote(String grant, String hint) {
    return '$grant (release 빌드에서는 단계로 제한: $hint)';
  }

  @override
  String devGrantMode(String mode, String hint) {
    return '이 화면: $mode — $hint';
  }

  @override
  String get devModeFull => '전체 기능';

  @override
  String get devModeBundled => '전체 기능 (앱 동봉)';

  @override
  String get devModeRestricted => '제한 모드';

  @override
  String get devModeSwing => '제한 모드 (Swing)';

  @override
  String get devSlotRegister => '슬롯에 등록';

  @override
  String devSlotRegistered(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '등록됨: $count',
    );
    return '$_temp0';
  }

  @override
  String devSlotModeHint(String hint) {
    return '슬롯 단계: 전체 / 제한 — $hint';
  }

  @override
  String get devSlotReviewed => '심사 완료';

  @override
  String get devSlotUnregister => '해제';

  @override
  String get devBoundaryHeader => '경계 세션: sns.timeline → Post 와이어 → PostRow';

  @override
  String get devBoundaryClose => '닫기';

  @override
  String devActionFailed(String action, String error) {
    return 'performAction($action) 실패: $error';
  }

  @override
  String devReviewImportTooLarge(int maxBytes) {
    return '크기가 올바르지 않습니다 ($maxBytes바이트 초과)';
  }

  @override
  String get devReviewImportExpired => '링크가 만료되었거나 잘못되었습니다. 심사 화면에서 다시 만들어 주세요';

  @override
  String devReviewImportHttpFailed(int status) {
    return '가져오지 못했습니다 (HTTP $status)';
  }

  @override
  String devReviewImportBadSize(int bytes) {
    return '크기가 올바르지 않습니다 ($bytes바이트)';
  }

  @override
  String get dmRoomSettings => '이 DM 설정';

  @override
  String get dmRetry => '새로고침';

  @override
  String get dmRoomEmpty => '아직 메시지가 없습니다';

  @override
  String get dmTabAll => '전체';

  @override
  String get dmTabFollowing => '팔로잉';

  @override
  String get dmSettings => 'DM 설정';

  @override
  String get dmFollowingEmpty => '팔로우 중인 사람과의 DM이 없습니다';

  @override
  String get dmNewMessage => '새 메시지';

  @override
  String get dmUserSearchHint => '사용자 이름으로 검색..';

  @override
  String get dmUserSearchIntro => 'DM을 보낼 상대를 검색합니다.';

  @override
  String get dmUserNotFound => '찾을 수 없습니다';

  @override
  String get dmEmptyTitle => 'DM이 없습니다';

  @override
  String get dmEmptyHint => '다이렉트 게시물(한정 공개)이 여기에 표시됩니다';

  @override
  String get dmYouPrefix => '나: ';

  @override
  String get dmMediaPlaceholder => '[미디어]';

  @override
  String get homeCreateMissingAccount => '(없는 계정)';

  @override
  String get homeCreatePost => '게시물';

  @override
  String get homeCreateNone => '없음';

  @override
  String homeCreateNeedsRasqAccount(String label) {
    return '$label에는 RASQ 계정이 필요합니다';
  }

  @override
  String get homeCreateAstellBlocked => '보호 설정에 의해 ASTell이 막혀 있습니다';

  @override
  String get homeCreateAccountGone => '이 계정은 더 이상 없습니다';

  @override
  String get homeCreate => '만들기';

  @override
  String get homeClose => '닫기';

  @override
  String get homeFabEditorTitle => '＋ 버튼';

  @override
  String homeFabEditorHelp(int count, int max) {
    return '아래 버튼을 칸으로 드래그하면 들어갑니다(칸끼리는 서로 바뀌고, 아래 줄로 되돌리면 빠집니다). 안쪽에 3개, 바깥쪽에 4개까지 · $count / $max';
  }

  @override
  String get homeHeaderCollapse => '헤더 접기';

  @override
  String get homeTimelineTemp => '타임라인 일시 변경';

  @override
  String get homeTimelineSettings => '타임라인 설정';

  @override
  String get homeTabRecommended => '추천';

  @override
  String get homeEmpty => '게시물이 없습니다';

  @override
  String get homePullToRefresh => '당겨서 새로고침';

  @override
  String get homeLoadNewer => '새 게시물 불러오기';

  @override
  String get homeNewPostsPill => '새 게시물';

  @override
  String get homeNewPostsPillSemantics => '새 게시물 보기';

  @override
  String get homeLoadingNewer => '새로고침 중…';

  @override
  String get homeLoadMoreFailed => '불러오지 못했습니다. 다시 시도';

  @override
  String get homeLoadMore => '더 불러오기';

  @override
  String get homeLoadingMore => '불러오는 중…';

  @override
  String get homeReload => '다시 불러오기';

  @override
  String homeSwingOf(String name) {
    return '$name의 Swing';
  }

  @override
  String homeSwingOfSeen(String name) {
    return '$name의 Swing (다 봄)';
  }

  @override
  String homeMySwingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '내 Swing ($_temp0)';
  }

  @override
  String get homeMySwing => '내 Swing';

  @override
  String get homeLiveNoToken => 'RASQ 계정의 토큰이 없습니다';

  @override
  String homePostAttachmentFiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '첨부 파일 $count개',
    );
    return '$_temp0';
  }

  @override
  String get homePostAttachmentLink => '첨부 링크 1개';

  @override
  String get homePostShare => '공유';

  @override
  String get homePostSelectAccount => '계정 선택';

  @override
  String get homePostLike => '좋아요';

  @override
  String get homePostReaction => '리액션';

  @override
  String homePostRepostVia(String handle, String instance) {
    return ' (@$handle@$instance로)';
  }

  @override
  String get homePostUndoRepost => '리노트 취소';

  @override
  String homePostCw(String cw) {
    return '[CW: $cw]';
  }

  @override
  String homePostAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '첨부 $count개',
    );
    return '$_temp0';
  }

  @override
  String get homeActionReply => '답글';

  @override
  String get homeActionRebroad => '리브로드';

  @override
  String get homeActionQueue => '대기열';

  @override
  String get homeEditorCropRotate => '자르기 / 회전';

  @override
  String get homeEditorPaint => '페인트';

  @override
  String get homeEditorText => '텍스트';

  @override
  String get homeEditorPost => '노트';

  @override
  String get homeEditorMedia => '미디어';

  @override
  String get homeEditorSticker => '스티커';

  @override
  String get homeEditorEmoji => '이모지';

  @override
  String get homeEditorFilter => '필터';

  @override
  String get homeEditorBlur => '흐림';

  @override
  String get homeEditorTune => '조정';

  @override
  String get homeActionAutoOn => '다음에도 자동으로 켜기';

  @override
  String get homeActionAutoOff => '다음부터도 자동으로 끄기';

  @override
  String get homeActionAutoReset => '플러그인 기본값으로 되돌리기';

  @override
  String get homeChildSafeWindowTab => '보호 시간';

  @override
  String get homeCancel => '취소';

  @override
  String get homeBarPost => '게시물 액션 바';

  @override
  String get homeBarViewer => '전체 화면 액션 바';

  @override
  String get homeBarEditorImage => '편집 화면 바 (이미지)';

  @override
  String get homeBarEditorVideo => '편집 화면 바 (동영상 / 음성)';

  @override
  String get homeBarEditorSvg => '편집 화면 바 (SVG)';

  @override
  String get homeBarRasqViewer => '전체 화면 액션 바 (Swing)';

  @override
  String get homeBarAstell => 'ASTell 룸 하단';

  @override
  String get homeBarEditAstellTitle => '룸 버튼 편집';

  @override
  String get homeBarEditTitle => '액션 바 편집';

  @override
  String get homeBarSearchPlugins => '플러그인 검색';

  @override
  String get homeBarSearchPluginButtons => '플러그인 버튼 검색';

  @override
  String homeBarSearchSubtitle(String source, String detail) {
    return '$source · $detail';
  }

  @override
  String get homeBarBuiltinEditor => '내장 편집';

  @override
  String get homeBarRasqActions => 'RASQ 액션';

  @override
  String get homeBarAstellButtons => 'ASTell 버튼';

  @override
  String get homeBarSnsActions => 'SNS 액션';

  @override
  String get homeBarViewerTogglePlugin => '전체 화면 표시 플러그인 (ON / OFF 버튼)';

  @override
  String get homeBarAstellPlugin => 'ASTell 플러그인 (누르면 그 플러그인을 엶)';

  @override
  String homeBarPluginTags(String tags) {
    return '태그: $tags';
  }

  @override
  String get homeBarManualPlacement => ' · 수동 배치';

  @override
  String get homeBarAllGenres => '전체';

  @override
  String get homeBarSearchHint => '버튼 이름 / 플러그인 이름 / 태그';

  @override
  String get homeBarSearchEmptyAstell =>
      '추가할 수 있는 버튼이 없습니다. 플러그인은 스토어에서 추가할 수 있습니다';

  @override
  String get homeBarSearchEmpty => '여기에 둘 수 있는 플러그인이 없습니다. 스토어에서 추가할 수 있습니다';

  @override
  String get homeBarSearchEmptyEditorDetail =>
      'composer.media를 선언한 플러그인이 없습니다 (스토어에서 추가)';

  @override
  String get homeBarSearchEmptyAstellDetail =>
      '숨긴 버튼 / ASTell 플러그인(astell.action)이 없습니다 (플러그인은 스토어에서 추가)';

  @override
  String get homeBarSearchEmptyViewerDetail =>
      '전체 화면 표시 플러그인 / post.action을 선언한 플러그인이 없습니다 (스토어에서 추가)';

  @override
  String get homeBarSearchEmptyPostDetail =>
      'post.action을 선언한 플러그인이 없습니다 (스토어에서 추가)';

  @override
  String get homeBarSearchNoHits => '찾을 수 없습니다';

  @override
  String get homeBarDetailTitle => '액션 상세';

  @override
  String get homeBarDetailUnknownDeveloper => '제공자 불명';

  @override
  String homeBarDetailStats(String rating, int downloads) {
    return '★$rating · $downloads 다운로드';
  }

  @override
  String get homeBarDetailAction => '액션';

  @override
  String get homeBarDetailSlot => '슬롯 (장르)';

  @override
  String get homeBarDetailConfirm => '확인';

  @override
  String get homeBarDetailAutomation => '자동화';

  @override
  String get homeBarDetailTags => '태그';

  @override
  String get homeBarIconSearchHint => '아이콘 이름으로 검색 (예: star, bolt)';

  @override
  String get homeBarBundleTitle => '번들 설정';

  @override
  String get homeBarBundleDissolved => '해제했습니다';

  @override
  String get homeBarPlugin => '플러그인';

  @override
  String homeBarBundleAstellMember(String label) {
    return '룸 하단 버튼 ($label)';
  }

  @override
  String homeBarBundleSnsMember(String genre) {
    return 'SNS 플러그인이 제공하는 액션 ($genre)';
  }

  @override
  String get homeBarBundleName => '리스트 이름';

  @override
  String get homeBarBundleIcon => '아이콘';

  @override
  String get homeBarBundlePhoto => '사진';

  @override
  String get homeBarBundlePhotoFailed => '사진을 사용할 수 없습니다';

  @override
  String get homeBarBundleMembers => '멤버';

  @override
  String get homeBarMenuDetail => '상세';

  @override
  String get homeBarBundleRemoveMember => '번들에서 빼기';

  @override
  String get homeBarDissolveList => '리스트 해제';

  @override
  String get homeBarMemberMenu => '멤버 조작';

  @override
  String get homeBarRasqAccount => 'RASQ 계정';

  @override
  String get homeBarHelpAstell =>
      '(…)나 오른쪽 클릭으로 메뉴. 길게 눌러 순서 변경, 다른 아이콘에 겹치면 묶입니다. (+)로 버튼 추가.';

  @override
  String get homeBarHelp => '(…)나 오른쪽 클릭으로 메뉴. 길게 눌러 순서 변경, 다른 아이콘에 겹치면 묶입니다.';

  @override
  String get homeBarHelpAstellDetail =>
      '(…) / shift + 클릭 / 오른쪽 클릭으로 메뉴(숨기기 / 번들). 길게 눌러 움직이면 순서 변경, 다른 아이콘 위에서 놓으면 번들. (+)로 숨긴 버튼이나 ASTell 플러그인을 추가. 폭에 다 들어가지 않으면 앞에서부터 들어가는 만큼과 마지막 하나(입력란 옆)를 표시하고, 나머지는 룸의 톱니바퀴 메뉴로.';

  @override
  String get homeBarHelpDetail =>
      '(…) / shift + 클릭 / 오른쪽 클릭으로 메뉴. 길게 눌러 움직이면 순서 변경, 다른 아이콘 위에서 놓으면 번들. 선언된 플러그인 버튼과 묶는 임계값은 설정 → SNS 플러그인 → \'플러그인 버튼\'.';

  @override
  String get homeBarRasqBuiltinEditor => 'RASQ (내장 편집)';

  @override
  String get homeBarNewBundleName => '내 리스트';

  @override
  String get homeBarMenuMakeList => '액션 리스트로 만들기';

  @override
  String get homeBarMenuHide => '숨기기';

  @override
  String get homeBarMenuDelete => '삭제';

  @override
  String get homeBarMenuListSettings => '액션 리스트 설정';

  @override
  String get homeBarMenuPinList => '고정 리스트로 만들기';

  @override
  String get homeBarAddButton => '버튼 추가';

  @override
  String get homeBarNoHidden => '숨긴 버튼이 없습니다';

  @override
  String get homeBarHiddenLabel => '숨김 (누르면 표시):';

  @override
  String homeBarShowHidden(String label) {
    return '$label 표시';
  }

  @override
  String get homeBarResetOrder => '기본 순서로 되돌리기';

  @override
  String get languageSelfName => '한국어';

  @override
  String get languageSettingsTitle => '언어';

  @override
  String get languageSettingsRowSubtitle => '앱 표시 언어';

  @override
  String get languageSettingsCaption =>
      '앱 문자의 언어를 선택합니다. 기기 언어를 지원하지 않으면 일본어로 표시합니다.';

  @override
  String get languageSettingsCaptionDetail =>
      '앱 문자의 언어를 선택합니다. \'시스템 설정 따르기\'는 기기의 언어 설정을 따르며, 지원하지 않는 언어이면 일본어로 표시합니다. 선택한 언어는 이 기기에 저장되며, RASQ 계정에 로그인해 있으면 ORGATE에도 전달합니다(이메일과 알림의 언어, D-484).';

  @override
  String get languageSettingsSystem => '시스템 설정 따르기';

  @override
  String languageSettingsSystemCurrent(String language) {
    return '현재 $language';
  }

  @override
  String get languageSettingsListHeader => '표시 언어';

  @override
  String get listsTitle => '리스트';

  @override
  String get listsTabAllLabel => '전체';

  @override
  String get listsSearchHint => '리스트·클립 검색';

  @override
  String get listsShowPrivateClips => '비공개 클립 표시';

  @override
  String get listsImportTitle => '리스트 가져오기';

  @override
  String get listsCreateTitle => '리스트 만들기';

  @override
  String listsCreateAccountList(String account) {
    return '$account의 리스트';
  }

  @override
  String get listsRasqCrossSns => 'RASQ 리스트 (SNS 통합)';

  @override
  String get listsCreateConfirm => '만들기';

  @override
  String get listsNameHint => '리스트 이름';

  @override
  String listsCreated(String name) {
    return '\'$name\'을(를) 만들었습니다';
  }

  @override
  String listsCreateUnsupported(String sns) {
    return '$sns에서는 리스트를 만들 수 없습니다';
  }

  @override
  String listsCreateFailed(String error) {
    return '리스트를 만들지 못했습니다: $error';
  }

  @override
  String get listsEmpty => '리스트가 없습니다';

  @override
  String get listsNoHits => '찾을 수 없습니다';

  @override
  String get listsEmptyHint => '＋로 리스트를 만들 수 있습니다';

  @override
  String get listsRasqCreateTitle => '새 RASQ 리스트';

  @override
  String get listsRasqCreateSubtitle =>
      'Misskey / Mastodon / Bluesky 사람을 하나의 리스트에';

  @override
  String listsSwitchedAccount(String account) {
    return '$account(으)로 전환했습니다';
  }

  @override
  String get listsSectionClips => '클립';

  @override
  String get listsSectionLists => '리스트';

  @override
  String get listsSectionFeeds => '커스텀 피드';

  @override
  String listsMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '사용자 $count명',
    );
    return '$_temp0';
  }

  @override
  String listsClipNotesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String get listsClipKindHost => 'RASQ (SNS 통합)';

  @override
  String get listsClipKindPrivate => '비공개 클립';

  @override
  String get listsClipKindPublic => '클립';

  @override
  String get listsSeparator => ' · ';

  @override
  String get listsFeedUnsave => '저장 해제';

  @override
  String get listsFeedSave => '피드 저장';

  @override
  String get listsFeedUnsaveFailed => '저장을 해제하지 못했습니다';

  @override
  String get listsFeedSaveFailed => '저장하지 못했습니다';

  @override
  String get listsFeedSaveUnsupported => '이 SNS는 피드 저장을 지원하지 않습니다';

  @override
  String get listsNotLoggedIn => '로그인하지 않았습니다';

  @override
  String listsFeedAlreadyImported(String name) {
    return '\'$name\'은(는) 이미 홈 타임라인에 들어 있습니다';
  }

  @override
  String listsFeedImported(String name) {
    return '\'$name\'을(를) 홈 타임라인에 가져왔습니다(탭 줄의 톱니바퀴에서 확인할 수 있습니다)';
  }

  @override
  String get listsTabUsers => '사용자';

  @override
  String get listsTabPosts => '게시물';

  @override
  String get listsTabTopics => '화제 목차';

  @override
  String get listsBlockedByGuardian => '보호자가 이 리스트를 막아 두었습니다';

  @override
  String get listsTimelineSettingsTooltip => '리스트 타임라인 설정';

  @override
  String get listsAddMembers => '멤버 추가';

  @override
  String listsMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명을 추가했습니다',
    );
    return '$_temp0';
  }

  @override
  String get listsNoUsers => '사용자가 없습니다';

  @override
  String get listsRemoveMember => '제외';

  @override
  String get listsReload => '다시 불러오기';

  @override
  String get listsNoPosts => '게시물이 없습니다';

  @override
  String get listsFeedDefaultTitle => '피드';

  @override
  String get listsImportToTimeline => '타임라인에 가져오기';

  @override
  String get listsFeedTimelineSettingsTooltip => '피드 타임라인 설정';

  @override
  String get listsImportSearchHintFeeds => '커스텀 피드 검색 또는 공유 링크 / URL 입력';

  @override
  String get listsImportSearchHintRasq => 'RASQ 리스트 검색 또는 공유 링크 / URL 입력';

  @override
  String get listsImportSearchHintBoth =>
      '커스텀 피드 / RASQ 리스트 검색 또는 공유 링크 / URL 입력';

  @override
  String get listsImportSearchPlain => '검색';

  @override
  String get listsImportFeedsHelp =>
      '피드를 검색하거나 URL을 붙여 넣으면 리스트 타일로 표시합니다. 탭하면 그 피드의 타임라인으로.';

  @override
  String get listsImportRasqHelp =>
      'RASQ 리스트는 \'가져오기\'로 홈 타임라인에(리스트를 팔로우합니다). 가져올 수 있는 것은 리스트 내 사람의 정보를 가져올 수 있는 리스트뿐입니다.';

  @override
  String get listsImportGenericHelp => '리스트를 검색해 일괄 조작을 할 수 있습니다.';

  @override
  String get listsImportLocal => '로컬에서 가져오기';

  @override
  String get listsImportLocalMessage => '파일에서 가져오기는 준비 중입니다.';

  @override
  String get listsImportLocalDetail =>
      'CSV/JSON에서 가져오기는 리스트 기능(서버 측)과 함께 구현합니다.';

  @override
  String get listsImportPopularFeeds => '인기 피드';

  @override
  String get listsImportFeedResults => '피드 검색 결과';

  @override
  String get listsImportEnterQuery => '검색어나 URL을 입력해 주세요';

  @override
  String get listsImportRasqMine => 'RASQ 리스트 (내 것 / 팔로잉)';

  @override
  String get listsImportRasqResults => 'RASQ 리스트 검색 결과';

  @override
  String get listsImportButton => '가져오기';

  @override
  String get listsImportHistory => '기록';

  @override
  String get listsImportHistoryEmpty => '기록이 없습니다';

  @override
  String get listsTopicsEmpty => '아직 화제가 없습니다';

  @override
  String get listsTopicsEmptyHint => '게시물이 모이면 화제별로 나눕니다';

  @override
  String get listsTopicsCaption => '화제별 구분입니다. 탭하면 그 화제의 게시물만 표시합니다.';

  @override
  String get listsTopicsCaptionDetail =>
      '대화 이벤트(게시물 2개 이상, 관계형 TL과 같은 엔진)를 장으로 삼고, 단발 게시물은 하나로 묶습니다(indexForListTimeline). 제목은 게시물 안에 있는 말(태그 / 특징어 / 도메인).';

  @override
  String listsTopicTimeRange(String start, String end) {
    return '$start~$end';
  }

  @override
  String listsTopicSubtitle(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count건',
    );
    return '$time · $_temp0';
  }

  @override
  String listsTopicSubtitleWithPeople(String time, int count, int people) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count건',
    );
    String _temp1 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people명',
    );
    return '$time · $_temp0 · $_temp1';
  }

  @override
  String listsTopicSnippet(String name, String body) {
    return '$name \'$body\'';
  }

  @override
  String listsTopicFilterChip(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count건',
    );
    return '화제: $label ($_temp0)';
  }

  @override
  String get listsTopicFilterClear => '필터 해제';

  @override
  String listsMemberCandidateSubtitle(String handle, String instance) {
    return '@$handle · $instance';
  }

  @override
  String listsMemberNotPublished(String name) {
    return '$name 님은 이 SNS의 계정을 공개하지 않았습니다';
  }

  @override
  String listsMemberSnsNotFound(String name) {
    return '$name 님의 SNS 계정을 찾을 수 없습니다';
  }

  @override
  String get listsPickerConfirm => '추가';

  @override
  String get listsPickerNoServer => 'RASQ 서버에 연결되어 있지 않습니다';

  @override
  String get listsPickerLookupFailed => '조회하지 못했습니다';

  @override
  String get listsPickerUnavailable => '선택할 수 없습니다';

  @override
  String get listsPickerNone => '없습니다';

  @override
  String get listsPickerSearchHint => '사용자 검색 (SNS / RASQ)';

  @override
  String get listsPickerSnsUsers => 'SNS 사용자';

  @override
  String get listsPickerRasqUsers => 'RASQ 사용자';

  @override
  String get listsPickerSnsFollowing => 'SNS 팔로잉';

  @override
  String get listsPickerRasqFollowing => 'RASQ 팔로잉';

  @override
  String get listsPickerRasqNotice => 'RASQ 사용자는 그 사람이 공개한 같은 SNS 계정으로 추가합니다.';

  @override
  String listsPickerRasqNoticeDetail(String path) {
    return 'Central 공개 페이지($path)의 snsAccounts에서 이 세션과 같은 SNS(같은 서버 우선, 확인 완료 우선)를 골라 userByHandle로 조회한 id를 추가합니다.';
  }

  @override
  String listsPickerSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명 선택됨',
    );
    return '$_temp0';
  }

  @override
  String get listsPickerRasqBadgeSemantics => 'RASQ 사용자';

  @override
  String get loginBack => '뒤로';

  @override
  String get loginTitle => 'SNS에 로그인';

  @override
  String get loginPluginLoadNote =>
      '처음 로그인하기 전에 플러그인을 불러옵니다. 네트워크 환경이 좋은 곳에서 진행해 주세요.';

  @override
  String get loginChildSafeBlocked => '보호자가 SNS 계정 추가를 막아 두었습니다';

  @override
  String get loginShareDeviceOnly =>
      '이메일로 이 기기를 승인했습니다. SNS 계정은 아래 버튼으로 이 기기에서 로그인해 주세요';

  @override
  String get loginWithBluesky => 'Bluesky로 로그인';

  @override
  String get loginWithMisskey => 'Misskey로 로그인';

  @override
  String get loginWithMixi2 => 'mixi2로 로그인';

  @override
  String get loginWithMastodon => 'Mastodon으로 로그인';

  @override
  String get loginDiscover => '서비스를 찾아 로그인';

  @override
  String get loginRaiInstruction => 'RAi 안내';

  @override
  String get loginShareMailUnavailable => '지금은 보낼 수 없습니다';

  @override
  String loginShareMailSent(String to) {
    return '$to(으)로 승인 링크를 보냈습니다(30분간 유효). 브라우저에서 열고 RASQ 계정으로 로그인한 뒤 승인해 주세요';
  }

  @override
  String get loginShareMailSentVerified =>
      '확인된 이메일 주소로 승인 링크를 보냈습니다(30분간 유효). 브라우저에서 열고 RASQ 계정으로 로그인한 뒤 승인해 주세요';

  @override
  String get loginShareMailNoVerified =>
      '확인된 이메일 주소가 없습니다. 원래 기기에서 승인하거나, 이 기기에서 SNS 계정에 로그인해 주세요';

  @override
  String get loginShareMailTooMany => '너무 많이 보냈습니다. 잠시 후 다시 보내 주세요';

  @override
  String get loginShareMailNotSupported => '이 서버에서는 이메일 승인을 사용할 수 없습니다';

  @override
  String loginShareMailFailed(String code) {
    return '보내지 못했습니다($code)';
  }

  @override
  String get loginShareWaiting =>
      '원래 기기에서 공유를 승인하면 SNS 계정에 한꺼번에 로그인합니다. 확인된 이메일로 받은 링크로도 승인할 수 있습니다';

  @override
  String get loginShareMailButton => '이메일로 승인(링크 보내기)';

  @override
  String get loginBundleTitleThis => '이 RASQ 계정의 SNS 계정';

  @override
  String loginBundleTitle(String handle) {
    return '@$handle의 SNS 계정';
  }

  @override
  String get loginBundleHint => '이 기기에서는 아직 로그인하지 않았습니다. 누르면 로그인할 수 있습니다.';

  @override
  String get loginBundleUse => '사용';

  @override
  String get loginBundleLogin => '로그인';

  @override
  String get loginTermsTitle => '플러그인 약관';

  @override
  String get loginTermsAgree => '동의';

  @override
  String loginTermsBullet(String text) {
    return '• $text';
  }

  @override
  String loginSignupDivider(String service) {
    return '$service 계정이 없나요?';
  }

  @override
  String get loginSignupButton => '회원가입';

  @override
  String get loginSignupReopen => '가입 페이지 다시 열기';

  @override
  String loginBrowserOpenFailed(String url) {
    return '브라우저를 열지 못했습니다. URL: $url';
  }

  @override
  String get loginPluginMissingMixi2 => 'mixi2 플러그인을 찾을 수 없습니다';

  @override
  String loginMixi2BrowserPending(String url) {
    return '브라우저에서 허용한 뒤 앱으로 돌아와 주세요: $url';
  }

  @override
  String loginFailed(String error) {
    return '로그인하지 못했습니다: $error';
  }

  @override
  String get loginMixi2HostHint => '호스트 (예: mixi.social)';

  @override
  String get loginMixi2Note =>
      'mixi2 공식 API는 신청제이며, 로그인은 RASQ 서버를 거칩니다. 준비가 끝날 때까지 \'브라우저에서 인증\'은 사용할 수 없습니다.';

  @override
  String get loginMixi2Browser => '브라우저에서 인증';

  @override
  String get loginMixi2Dummy => '더미 계정으로 시험';

  @override
  String get loginMixi2DummyNote =>
      '더미 계정은 네트워크를 사용하지 않으며, 플러그인에 들어 있는 게시물로 타임라인 / 좋아요 / 리포스트 / 게시 / 알림 흐름을 확인할 수 있습니다.';

  @override
  String get loginMixi2SignupHint =>
      'mixi2 계정은 브라우저(또는 mixi2 앱)에서 만듭니다. 만든 뒤 이 화면으로 돌아와 \'브라우저에서 인증\'으로 로그인해 주세요.';

  @override
  String get loginPluginMissingBluesky => 'Bluesky 플러그인을 찾을 수 없습니다';

  @override
  String get loginBlueskyHostHint => 'PDS (예: bsky.social)';

  @override
  String get loginBlueskyIdHint => '핸들 (예: you.bsky.social) 또는 이메일';

  @override
  String get loginBlueskyPasswordHint => '앱 비밀번호';

  @override
  String get loginPasswordHide => '숨기기';

  @override
  String get loginPasswordShow => '표시';

  @override
  String get loginBlueskyPasswordNote =>
      'Bluesky의 \'설정 → 개인정보 및 보안 → 앱 비밀번호\'에서 만든 비밀번호를 사용해 주세요. 원래 비밀번호는 입력하지 마세요.';

  @override
  String get loginButton => '로그인';

  @override
  String get loginBlueskySignupHint =>
      '브라우저의 Bluesky에서 \'계정 만들기\'로 가입해 주세요. 가입한 뒤 Bluesky의 \'설정 → 개인정보 및 보안 → 앱 비밀번호\'에서 비밀번호를 만들고, 위의 핸들과 앱 비밀번호로 로그인합니다.';

  @override
  String get loginServerUnreachable => '서버에 연결하지 못했습니다';

  @override
  String loginServerUnreachableWithError(String error) {
    return '서버에 연결하지 못했습니다: $error';
  }

  @override
  String loginAuthStartFailed(String error) {
    return '인증을 시작하지 못했습니다: $error';
  }

  @override
  String loginAuthCheckFailed(String error) {
    return '인증 확인에 실패했습니다: $error';
  }

  @override
  String get loginSnsTitle => 'PDS 변경';

  @override
  String get loginSnsNote => 'PDS를 변경하면 앱 밖에서 표시되는 URL이 바뀝니다.';

  @override
  String loginSnsHostHint(String example) {
    return '이전할 URL 입력 (예: $example)';
  }

  @override
  String get loginSnsSearch => '서버 검색';

  @override
  String get loginSnsServerSection => '서버 검색';

  @override
  String loginSnsMaintainer(String name) {
    return '관리자: $name';
  }

  @override
  String get loginSnsRegistrationClosed => '가입 중지';

  @override
  String get loginSnsAuthCheck => '인증 확인';

  @override
  String get loginSnsReopenBrowser => '브라우저 다시 열기';

  @override
  String get loginMisskeyAuthButton => '브라우저에서 인증 (MiAuth)';

  @override
  String get loginMastodonAuthButton => '브라우저에서 인증 (OAuth)';

  @override
  String get loginMastodonHostHint => '인스턴스 URL 입력 (예: mastodon.social)';

  @override
  String get mediaVizStyleMirror => '상하 대칭 막대';

  @override
  String get mediaVizStyleBars => '아래에서 올라오는 막대';

  @override
  String get mediaVizStyleLine => '꺾은선';

  @override
  String get mediaVizLeftAvatar => '계정 아이콘';

  @override
  String get mediaVizLeftFile => '선택한 이미지';

  @override
  String get mediaVizLeftGlyph => '음표 아이콘';

  @override
  String get mediaVizLeftNone => '없음(파형을 가로 가득)';

  @override
  String get mediaVizTextBelow => '그림 아래';

  @override
  String get mediaVizTextAbove => '그림 위';

  @override
  String get mediaVizQualityFast => '빠름(960×540)';

  @override
  String get mediaVizQualityStandard => '표준(1280×720)';

  @override
  String get mediaVizQualityFine => '세밀(2560×1440, 약 4배 소요)';

  @override
  String get mediaWavInvalid => 'WAV가 아닙니다';

  @override
  String get mediaWavMissingChunks => 'WAV의 fmt / data가 없습니다';

  @override
  String mediaWavUnsupported(int format, int bits) {
    return '지원하지 않는 WAV(format $format, ${bits}bit)';
  }

  @override
  String mediaSeconds(String seconds) {
    return '$seconds초';
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
      other: '합계 $total($frameCount프레임: 그리기 $frames / 인코딩 $encode / 마무리 $mux)',
    );
    return '$_temp0';
  }

  @override
  String get mediaAudioVideoUnsupported =>
      '이 기기에서는 오디오를 동영상으로 만들 수 없습니다(Android / iOS / macOS만)';

  @override
  String get mediaViewerSemantics => '게시물';

  @override
  String get mediaViewerBack => '뒤로';

  @override
  String get mediaViewerPip => 'PiP로 재생';

  @override
  String get mediaViewerMenu => '메뉴';

  @override
  String get mediaViewerShare => '공유';

  @override
  String get mediaPluginAsking => '이미지를 보는 중…';

  @override
  String get mediaPluginFound => '감지됨';

  @override
  String get mediaPluginNotFound => '감지 안 됨';

  @override
  String mediaPluginFailed(String reason) {
    return '실패: $reason(껐다 켜면 다시 시도)';
  }

  @override
  String get mediaPluginFetchFailed => '이미지를 가져오지 못했습니다';

  @override
  String mediaPluginFetchFailedWithError(String error) {
    return '이미지를 가져오지 못했습니다($error)';
  }

  @override
  String get mediaPluginDecodeFailed => '이미지를 읽지 못했습니다';

  @override
  String mediaVideoCannotPlay(String error) {
    return '재생할 수 없습니다: $error';
  }

  @override
  String get mediaVideoBack5 => '5초 뒤로';

  @override
  String get mediaVideoPause => '일시정지';

  @override
  String get mediaVideoPlay => '재생';

  @override
  String get mediaVideoForward5 => '5초 앞으로';

  @override
  String get mediaVideoSpeed => '재생 속도';

  @override
  String get mediaVideoFowTitle => '동영상';

  @override
  String get mediaVideoFowClose => '닫기';

  @override
  String get mediaSaveAsk => '저장할 때마다 선택';

  @override
  String get mediaSavePhotos => '사진(카메라 롤)';

  @override
  String get mediaSaveFiles => '파일';

  @override
  String get mediaSaveBadFileName => '저장할 파일 이름이 올바르지 않습니다';

  @override
  String get mediaSaveOutsideFolder => '저장 폴더 밖에는 쓰지 않습니다';

  @override
  String get mediaSaveTooManySameName => '같은 이름의 파일이 너무 많습니다';

  @override
  String get mediaSavePhotosDenied => '사진에 저장하는 것이 허용되지 않았습니다(설정 앱에서 허용해 주세요)';

  @override
  String get mediaSavedToPhotos => '사진(앨범 \'RASQ\')에 저장했습니다';

  @override
  String mediaSavedToFilesApp(String folder, String fileName) {
    return '\'파일\' 앱의 RASQ › $folder에 저장했습니다($fileName)';
  }

  @override
  String mediaSavedToPath(String path) {
    return '저장했습니다: $path';
  }

  @override
  String get mediaColorBlack => '검정';

  @override
  String get mediaColorNavy => '남색';

  @override
  String get mediaColorInk => '먹색';

  @override
  String get mediaColorDeepGreen => '짙은 녹색';

  @override
  String get mediaColorCrimson => '연지색';

  @override
  String get mediaColorWhite => '흰색';

  @override
  String get mediaColorLightGray => '연회색';

  @override
  String get mediaColorYellow => '노랑';

  @override
  String get mediaColorSkyBlue => '하늘색';

  @override
  String get mediaColorPink => '분홍';

  @override
  String get mediaColorBlue => '파랑';

  @override
  String get mediaColorGreen => '초록';

  @override
  String get mediaColorOrange => '주황';

  @override
  String get mediaColorPurple => '보라';

  @override
  String get mediaVizCancel => '취소';

  @override
  String get mediaVizConfirm => '확인';

  @override
  String get mediaVizSemantics => 'Visualizer 설정';

  @override
  String get mediaVizRebuildWarning => '확인하면 동영상을 다시 만듭니다. 지금까지의 편집은 사라집니다';

  @override
  String mediaVizRebuildDetail(int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other:
          '현재 재생 위치의 프레임. 확인하면 동영상을 다시 내보냅니다($frames프레임). 페인트나 텍스트 등 지금까지의 편집은 사라집니다.',
    );
    return '$_temp0';
  }

  @override
  String mediaVizRebuildDetailReducedFps(int frames, String fps) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other:
          '현재 재생 위치의 프레임. 확인하면 동영상을 다시 내보냅니다($frames프레임, 길어서 ${fps}fps로 낮춥니다). 페인트나 텍스트 등 지금까지의 편집은 사라집니다.',
    );
    return '$_temp0';
  }

  @override
  String get mediaVizWaveform => '파형';

  @override
  String get mediaVizBands => '대역 수(저음 → 고음)';

  @override
  String get mediaVizFrameRate => '프레임 레이트';

  @override
  String get mediaVizBarColor => '막대 색';

  @override
  String get mediaVizBackgroundColor => '배경색';

  @override
  String get mediaVizLeftImage => '왼쪽 그림';

  @override
  String get mediaVizPickImage => '이미지 선택';

  @override
  String get mediaVizRepickImage => '이미지 다시 선택';

  @override
  String get mediaVizPickImageHint => '선택하기 전까지는 음표 아이콘';

  @override
  String get mediaVizTitleSection => '제목 / 설명';

  @override
  String get mediaVizShowTitle => '제목 / 설명 표시';

  @override
  String get mediaVizTitleHint => '제목(비우면 파일 이름)';

  @override
  String get mediaVizDescriptionHint => '설명(선택)';

  @override
  String get mediaVizTextScale => '글자 크기';

  @override
  String get mediaVizTextColorAuto => '글자 색: 자동';

  @override
  String get mediaVizBackgroundVideo => '배경 동영상';

  @override
  String get mediaVizPickVideo => '동영상 선택';

  @override
  String get mediaVizRepickVideo => '동영상 다시 선택';

  @override
  String get mediaVizPickVideoHint => '배경색 대신 동영상을 재생합니다(소리는 사용하지 않습니다)';

  @override
  String mediaVizVideoSelected(String fileName) {
    return '$fileName — 오디오보다 짧으면 반복합니다';
  }

  @override
  String get mediaVizRemoveVideo => '배경 동영상 제거';

  @override
  String get mediaVizDim => '동영상 위에 씌우는 어둡기';

  @override
  String get mediaVizDimHint => '파형과 글자를 읽기 쉽게 합니다';

  @override
  String get mediaVizFade => '페이드(그림)';

  @override
  String get mediaVizFadeIn => '페이드 인';

  @override
  String get mediaVizFadeOut => '페이드 아웃';

  @override
  String get mediaVizFadeNone => '없음';

  @override
  String get mediaVizExport => '내보내기';

  @override
  String get mediaVizExportCaption => '세밀할수록 내보내기에 시간이 걸립니다';

  @override
  String get mediaVizExportDetail =>
      '파형을 그리는 크기(출력은 항상 2560×1440). 왼쪽 그림과 문자는 별도의 1장으로 항상 세밀하게 그립니다. 내보내기 시간은 대략 프레임 수 × 그리는 크기로 정해집니다(fps를 낮추는 것도 효과가 있습니다). 배경 동영상을 사용하면 느려집니다.';

  @override
  String mediaVizExportDetailWithLast(String timings) {
    return '지난 내보내기: $timings.\n파형을 그리는 크기(출력은 항상 2560×1440). 왼쪽 그림과 문자는 별도의 1장으로 항상 세밀하게 그립니다. 내보내기 시간은 대략 프레임 수 × 그리는 크기로 정해집니다(fps를 낮추는 것도 효과가 있습니다). 배경 동영상을 사용하면 느려집니다.';
  }

  @override
  String get nodeprogCatalogGenreGenerate => '생성';

  @override
  String get nodeprogCatalogGenreConvert => '변환';

  @override
  String get nodeprogCatalogGenreInput => '입력';

  @override
  String get nodeprogCatalogGenreTimeline => '타임라인';

  @override
  String get nodeprogCatalogGenreProcess => '가공';

  @override
  String get nodeprogCatalogGenreCondition => '조건';

  @override
  String get nodeprogCatalogGenreFunction => '함수';

  @override
  String get nodeprogCatalogGenreFetch => '가져오기';

  @override
  String get nodeprogCatalogGenreComposer => '작성기';

  @override
  String get nodeprogCatalogGenreStorage => '저장';

  @override
  String get nodeprogCatalogClockTitle => '클록 메이커';

  @override
  String get nodeprogCatalogClockDescription =>
      '일정 간격으로 클록을 출력합니다. TL 자동 갱신 등의 트리거로 사용합니다.';

  @override
  String get nodeprogCatalogTextConstTitle => '텍스트';

  @override
  String get nodeprogCatalogTextConstDescription =>
      '작성한 문장을 텍스트로 출력합니다. 유사성 / 키워드 기준이나 분할 입력에 연결합니다.';

  @override
  String get nodeprogCatalogConvertSplitTitle => '분할';

  @override
  String get nodeprogCatalogConvertSplitDescription =>
      '텍스트를 구분자(줄바꿈 / 쉼표 / 공백)로 텍스트 배열로 만듭니다. 키워드 리스트나 저장 입력에 연결합니다.';

  @override
  String get nodeprogCatalogConvertJoinTitle => '결합';

  @override
  String get nodeprogCatalogConvertJoinDescription =>
      '텍스트 배열을 구분자(줄바꿈 / 쉼표 / 공백)로 하나의 텍스트로 만듭니다.';

  @override
  String get nodeprogCatalogListFirstTitle => '게시물 꺼내기';

  @override
  String get nodeprogCatalogListFirstDescription =>
      '게시물 리스트의 몇 번째 게시물을 1개 꺼냅니다(1 = 맨 앞). 본문을 텍스트로 만들어 기준이나 설정에 연결합니다.';

  @override
  String get nodeprogCatalogPostTextTitle => '게시물 본문';

  @override
  String get nodeprogCatalogPostTextDescription => '게시물 1개의 본문을 텍스트로 만듭니다.';

  @override
  String get nodeprogCatalogRandomTitle => '랜덤';

  @override
  String get nodeprogCatalogRandomDescription =>
      '게시물마다 난수를 출력합니다. 범위는 \'1-7\'처럼 지정하며, 소수점을 넣으면 소수점 이하도 셉니다. 시드로 재현할 수 있습니다.';

  @override
  String get nodeprogCatalogFileTitle => '파일 리더';

  @override
  String get nodeprogCatalogFileDescription => '로컬 파일을 읽어 텍스트로 출력합니다.';

  @override
  String get nodeprogCatalogTimelineTitle => '타임라인';

  @override
  String get nodeprogCatalogTimelineDescription =>
      '최종 출력. 게시물 리스트를 연결하면 이 화면의 타임라인에 흐릅니다.';

  @override
  String get nodeprogCatalogTlSourceTitle => '타임라인 가져오기';

  @override
  String get nodeprogCatalogTlSourceDescription =>
      '선택한 타임라인을 가져와 게시물 리스트로 전달합니다.';

  @override
  String get nodeprogCatalogTlSourceDetail =>
      '선택한 타임라인을 가져와 게시물 리스트(RRL 태그 포함)로 전달합니다.';

  @override
  String get nodeprogCatalogSortTitle => '정렬';

  @override
  String get nodeprogCatalogSortDescription =>
      '아래에 연결한 조건에 맞는 게시물을 맨 앞으로 정렬합니다(원래 순서는 유지됩니다).';

  @override
  String get nodeprogCatalogRemoveTitle => '제거';

  @override
  String get nodeprogCatalogRemoveDescription => '아래에 연결한 조건에 맞는 게시물을 제거합니다.';

  @override
  String get nodeprogCatalogCondTitle => '조건';

  @override
  String get nodeprogCatalogCondDescription =>
      '지정한 태그의 내용을 보고 True/False를 반환합니다. 아래로 이어 붙이면 \'그리고\', 같은 접속부에서 병렬로 연결하면 \'또는\'.';

  @override
  String get nodeprogCatalogNotDescription => '아래에 연결한 조건의 부정을 반환합니다.';

  @override
  String get nodeprogCatalogFnInputTitle => '함수 입력';

  @override
  String get nodeprogCatalogFnInputDescription =>
      '함수 내용의 입구. 호출한 곳에서 전달된 게시물 리스트가 여기서 나옵니다(함수 내용 편집 화면 전용).';

  @override
  String get nodeprogCatalogFnOutputTitle => '함수 출력';

  @override
  String get nodeprogCatalogFnOutputDescription =>
      '함수 내용의 출구. 여기에 연결한 게시물 리스트가 함수 노드의 출력이 됩니다(미연결이면 그대로 통과).';

  @override
  String get nodeprogCatalogFilterQueryTitle => '검색 필터';

  @override
  String get nodeprogCatalogFilterQueryDescription =>
      '검색어에 맞는 게시물만 통과시킵니다(\'제외\'로 반대로 걸러 냅니다).';

  @override
  String get nodeprogCatalogFilterQueryDetail =>
      '검색어에 맞는 게시물만 통과시킵니다. 검색어가 비어 있으면 이 페이지의 검색어/태그를 사용합니다. \'제외\'를 true로 하면 맞는 게시물을 걸러 냅니다(단어 뮤트).';

  @override
  String get nodeprogCatalogMergeTitle => '병합';

  @override
  String get nodeprogCatalogMergeDescription => '연결한 게시물 리스트를 시간순으로 하나로 합칩니다.';

  @override
  String get nodeprogCatalogMergeDetail =>
      '연결한 게시물 리스트를 시간순으로 하나로 합류시킵니다. 다른 계정으로 들어온 같은 게시물은 한 장으로 접히며, 타일의 ↓로 계정을 고를 수 있습니다.';

  @override
  String get nodeprogCatalogTimelineRelationalTitle => '관련 타임라인';

  @override
  String get nodeprogCatalogTimelineRelationalDescription =>
      '관련 타임라인 필터링의 출구입니다.';

  @override
  String get nodeprogCatalogTimelineRelationalDetail =>
      '관련 TL 전단 필터링의 최종 출력. 연결한 게시물 리스트가 대화 이벤트 구축의 입력이 됩니다(처리 방식은 바뀌지 않습니다).';

  @override
  String get nodeprogCatalogTlListTitle => '리스트 TL 가져오기';

  @override
  String get nodeprogCatalogTlListDescription =>
      'Misskey 리스트의 타임라인을 가져옵니다(리스트 이름으로 지정).';

  @override
  String get nodeprogCatalogTlSearchTitle => '검색 TL 가져오기';

  @override
  String get nodeprogCatalogTlSearchDescription => '검색어에 해당하는 게시물을 가져옵니다.';

  @override
  String get nodeprogCatalogTlDmTitle => 'DM 가져오기';

  @override
  String get nodeprogCatalogTlDmDescription => '상대(핸들)와의 DM을 가져옵니다.';

  @override
  String get nodeprogCatalogTrendTagsTitle => '트렌드 가져오기';

  @override
  String get nodeprogCatalogTrendTagsDescription =>
      '지금의 트렌드 태그를 문자열 배열로 출력합니다(유사도/키워드 입력용).';

  @override
  String get nodeprogCatalogTlFeedTitle => '커스텀 피드 가져오기';

  @override
  String get nodeprogCatalogTlFeedDescription => 'Bluesky 커스텀 피드를 가져옵니다.';

  @override
  String get nodeprogCatalogTlFeedDetail =>
      'Bluesky 커스텀 피드(피드 제너레이터)의 타임라인을 가져옵니다(at:// URI로 지정. TL 맞춤 설정에서는 검색해 고를 수 있습니다).';

  @override
  String get nodeprogCatalogTlRasqlistTitle => 'RASQ 리스트 가져오기';

  @override
  String get nodeprogCatalogTlRasqlistDescription =>
      '여러 SNS의 사람을 모은 RASQ 리스트의 게시물을 가져옵니다.';

  @override
  String get nodeprogCatalogTlRasqlistDetail =>
      'RASQ 리스트(Misskey / Mastodon / Bluesky의 사람을 하나로 모은 리스트)의 게시물을 가져옵니다. 고를 수 있는 것은 리스트 내 사람의 정보를 가져올 수 있는(같은 서버의 계정이 있음 / 멤버를 팔로우 중) 리스트뿐입니다.';

  @override
  String get nodeprogCatalogTrendPostsTitle => '트렌드 검색 결과 가져오기';

  @override
  String get nodeprogCatalogTrendPostsDescription =>
      '지금의 상위 트렌드 태그를 검색해 그 게시물을 하나로 합류시켜 출력합니다.';

  @override
  String get nodeprogCatalogComposerTargetTitle => '게시 대상';

  @override
  String get nodeprogCatalogComposerTargetDescription =>
      '게시 대상 계정의 후보입니다. 아래 조건에 맞으면 게시 대상이 됩니다.';

  @override
  String get nodeprogCatalogComposerTargetDetail =>
      '게시 대상 계정의 후보. 아래에 조건을 달면, 게시 내용이 그 조건에 맞을 때 이 계정이 게시 대상이 됩니다(위에 둔 것일수록 우선. 수동으로 다시 고를 수 있습니다).';

  @override
  String get nodeprogCatalogComposerFallbackTitle => '대체 형식으로 게시';

  @override
  String get nodeprogCatalogComposerFallbackDescription =>
      '필터링으로 빠졌을 때 다른 형태로 이 계정에 게시합니다.';

  @override
  String get nodeprogCatalogComposerFallbackDetail =>
      '필터링으로 게시 대상에서 빠진 경우의 우회로. 아래 조건(보통은 직전 비교의 Not)이 성립하면 대체 형식으로 이 계정에 게시합니다.';

  @override
  String get nodeprogCatalogComposerLinkgateTitle => '연동 필터';

  @override
  String get nodeprogCatalogComposerLinkgateDescription =>
      '함께 보내는 게시물에만 적용되는 필터입니다.';

  @override
  String get nodeprogCatalogComposerLinkgateDetail =>
      '연동 게시에만 적용되는 필터입니다. 아래 조건이 성립하지 않으면 이 계정으로의 연동 게시는 보내지 않습니다(일반 게시 대상 판정에는 영향을 주지 않습니다).';

  @override
  String get nodeprogCatalogComposerRegexTitle => '게시물 가공(정규 표현식)';

  @override
  String get nodeprogCatalogComposerRegexDescription => '보낼 때 본문의 일부를 바꿉니다.';

  @override
  String get nodeprogCatalogComposerRegexDetail =>
      '보낼 때 본문에 정규 표현식 치환을 적용합니다(패턴에 일치한 부분을 치환). 계정이 비어 있으면 모든 게시 대상에 적용합니다.';

  @override
  String get nodeprogCatalogTlMyreactionsTitle => '리액션한 게시물 가져오기';

  @override
  String get nodeprogCatalogTlMyreactionsDescription =>
      'TL에서 내가 리액션한 게시물을 가져옵니다(취향 프로필 만들기용).';

  @override
  String get nodeprogCatalogTrendFrameTitle => '트렌드 틀';

  @override
  String get nodeprogCatalogTrendFrameDescription =>
      '트렌드 홈 \'트렌드\' 목록의 최종 출력. 태그(텍스트 배열)를 연결하면 그대로 목록에 표시됩니다.';

  @override
  String get nodeprogCatalogMlSimilarTitle => '유사도 (SigLIP)';

  @override
  String get nodeprogCatalogMlSimilarDescription =>
      '기준과 각 게시물이 닮은 정도를 0~1로 출력합니다.';

  @override
  String get nodeprogCatalogMlSimilarDetail =>
      '기준(텍스트/배열/벡터)과 각 게시물의 유사도를 이 TL 내의 상대값 0~1로 출력합니다(0.8 ≒ 상위 20% 상당). ML을 쓸 수 없으면 n-gram 유사도로 축소됩니다.';

  @override
  String get nodeprogCatalogMlGlinerTitle => 'GLiNER 추출';

  @override
  String get nodeprogCatalogMlGlinerDescription =>
      '게시물 리스트에서 특징어(빈도순)를 추출해 문자열 배열로 출력합니다.';

  @override
  String get nodeprogCatalogMlSiglipTitle => 'SigLIP 임베딩';

  @override
  String get nodeprogCatalogMlSiglipDescription => '게시물 리스트의 경향을 모아서 출력합니다.';

  @override
  String get nodeprogCatalogMlSiglipDetail =>
      '게시물 리스트의 평균 임베딩(프로필)을 벡터로 출력합니다. ML을 쓸 수 없으면 n-gram 프로필로 축소됩니다.';

  @override
  String get nodeprogCatalogStorageSaveTitle => '저장 (storage.safe)';

  @override
  String get nodeprogCatalogStorageSaveDescription => '연결한 데이터를 저장합니다.';

  @override
  String get nodeprogCatalogStorageSaveDetail =>
      '연결한 데이터를 슬롯에 저장합니다. storage.safe는 의존 관계의 하위 플러그인에도 넘길 수 있는 안전한 저장소입니다(플러그인 측의 전달은 첫 실행 시 확인).';

  @override
  String get nodeprogCatalogStorageLoadTitle => '읽기 (storage.safe)';

  @override
  String get nodeprogCatalogStorageLoadDescription => '슬롯에 저장한 데이터를 읽어 옵니다.';

  @override
  String get nodeprogCatalogMlKeywordTitle => '키워드 일치 (GLiNER)';

  @override
  String get nodeprogCatalogMlKeywordDescription =>
      '키워드(또는 배열)와 각 게시물 특징어의 일치 수를 출력합니다.';

  @override
  String get nodeprogCatalogMlTendencyTitle => '성향/자극성 (프로필)';

  @override
  String get nodeprogCatalogMlTendencyDescription =>
      '취향 설정과의 적합도(0~1)를 각 게시물에 출력합니다.';

  @override
  String get nodeprogCatalogMlTendencyDetail =>
      'storage.safe의 트렌드 프로필(좋아하는 장르/방향성·성향 임계값·자극성 상한)에 대한 적합도(0~1)를 각 게시물에 출력합니다. 프로필은 검색 홈의 트렌드 ⚙에서 편집하며, 다른 노드에서도 같은 슬롯을 읽을 수 있습니다.';

  @override
  String get nodeprogCatalogCompareTitle => '비교';

  @override
  String get nodeprogCatalogCompareDescription =>
      '수치와 임계값을 비교해 True/False를 반환합니다.';

  @override
  String get nodeprogCatalogCompareDetail =>
      '수치(유사도·난수 등)와 임계값을 비교해 True/False를 반환하는 연산자 조건입니다. 값의 출처가 미연결이거나 값을 얻을 수 없을 때(슬롯이 비어 있는 등)는 False가 됩니다.';

  @override
  String nodeprogCatalogTypeWithFormat(String type, String format) {
    return '$type($format)';
  }

  @override
  String nodeprogCatalogPortWithType(String label, String type) {
    return '$label($type)';
  }

  @override
  String get nodeprogCatalogIoCond => '조건';

  @override
  String get nodeprogCatalogIoNone => '없음';

  @override
  String get nodeprogCatalogListSeparator => ' · ';

  @override
  String nodeprogCatalogIoSummary(String inputs, String outputs) {
    return '입력: $inputs → 출력: $outputs';
  }

  @override
  String get nodeprogCatalogCustomFunctionAuthor => '사용자 정의 함수';

  @override
  String nodeprogCatalogCustomFunctionCondDescription(String tags) {
    return '조건 $tags을(를) 받는, 직접 만든 함수입니다.';
  }

  @override
  String nodeprogCatalogCustomFunctionCondDetail(String tags) {
    return '조건 태그 $tags을(를) 받는 사용자 정의 함수입니다(내부 배선은 플러그인/RAi로).';
  }

  @override
  String get nodeprogCatalogCustomFunctionDataDescription => '직접 만든 함수입니다.';

  @override
  String get nodeprogCatalogCustomFunctionDataDetail =>
      '사용자 정의 함수입니다(내부 배선은 플러그인/RAi로).';

  @override
  String get nodeprogCatalogGenreSortDictionary => '정렬/사전';

  @override
  String get nodeprogCatalogCustomFunctionDefaultName => '함수';

  @override
  String get nodeprogComponentsTrendFormTilesLabel => '트렌드 가져오기';

  @override
  String get nodeprogComponentsTrendFormChipsLabel => '사용자 지정(후보 칩)';

  @override
  String get nodeprogComponentsTrendFormChipsHeading => '검색 추천';

  @override
  String get nodeprogComponentsTrendFormTilesDescription =>
      '후보 단어를 트렌드 타일 형태로 표시합니다(탭하면 그 단어의 트렌드).';

  @override
  String get nodeprogComponentsTrendFormTodayDescription =>
      '상위 후보 단어의 게시물을 Today처럼 모아서 표시합니다.';

  @override
  String get nodeprogComponentsTrendFormChipsDescription =>
      '후보 단어를 검색 후보 칩으로 표시합니다.';

  @override
  String nodeprogComponentsSuggestTitle(String what, String from) {
    return '$from에서 $what 추천';
  }

  @override
  String nodeprogComponentsFilterTitle(String what, String from) {
    return '$from에서 $what 필터링';
  }

  @override
  String get nodeprogComponentsQueryFilterExcludeTitle => '검색 필터(제외)';

  @override
  String get nodeprogComponentsTendencyTitle => '성향/자극성(프로필)';

  @override
  String get nodeprogComponentsPluginTitle => '사용자 지정(TL 플러그인)';

  @override
  String get nodeprogComponentsDisplayTimeline => '일반 TL';

  @override
  String get nodeprogComponentsDisplayRelational => '관련 TL';

  @override
  String get nodeprogComponentsDeliveryConfirm => '확인 후 게시 (confirm)';

  @override
  String get nodeprogComponentsDeliveryDraft => '초안만 만들기 (draft)';

  @override
  String get nodeprogComponentsDeliveryAuto => '바로 게시 (auto)';

  @override
  String get nodeprogComponentsSelfDm => '이 DM의 메시지';

  @override
  String get nodeprogComponentsSelfSearch => '이 단어의 검색 결과';

  @override
  String get nodeprogComponentsSelfToday => 'Today 게시물';

  @override
  String get nodeprogComponentsSelfTrendWords => '트렌드 단어';

  @override
  String get nodeprogComponentsSelfList => '이 리스트의 게시물';

  @override
  String get nodeprogComponentsSelfFeed => '이 피드의 게시물';

  @override
  String get nodeprogComponentsSelfBundle => '종합 탭의 게시물';

  @override
  String get nodeprogComponentsSelfHome => '팔로잉 탭의 게시물';

  @override
  String get nodeprogComponentsSelfSocial => '추천 탭의 게시물';

  @override
  String get nodeprogComponentsSelfLocal => '로컬 탭의 게시물';

  @override
  String get nodeprogComponentsSelfGlobal => '글로벌 탭의 게시물';

  @override
  String get nodeprogComponentsSelfRelational => '관련 탭의 게시물';

  @override
  String get nodeprogComponentsSelfTab => '이 탭의 게시물';

  @override
  String get nodeprogComponentsTrendTilesNoMl =>
      'ML 모델을 사용하므로 트렌드 타일에서는 사용할 수 없습니다';

  @override
  String get nodeprogComponentsTrendTilesNoPlugin =>
      '게시물을 재정렬하므로(GPU를 쓰기도 함) 트렌드 타일에서는 사용할 수 없습니다';

  @override
  String get nodeprogComposerResetConfig => '이 구성 초기화';

  @override
  String get nodeprogComposerLearnNone => '아직 학습하지 않았습니다(게시하면 학습합니다)';

  @override
  String get nodeprogComposerLearnNoneDetail =>
      '학습 프로필: 아직 확정된 게시물이 없습니다(게시하면 자동으로 학습합니다)';

  @override
  String nodeprogComposerLearnCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '지금까지 게시물 $count개에서 학습하고 있습니다',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerLearnCountDetail(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '학습 프로필: 확정 게시물 $count개(수동으로 전환한 게시물은 강하게 학습, 반감기 90일)',
    );
    return '$_temp0';
  }

  @override
  String nodeprogComposerRelationStats(int pos, int neg) {
    return '실적: 연동 $pos회 / 확인 시 해제 $neg회';
  }

  @override
  String get nodeprogComposerNoAccounts => '계정이 없습니다';

  @override
  String get nodeprogComposerNoAccountsHint => '로그인하면 게시 대상의 조건을 설정할 수 있습니다';

  @override
  String get nodeprogComposerBanner => '초안 내용에 맞는 계정이 게시 대상 후보가 됩니다';

  @override
  String get nodeprogComposerBannerDetail =>
      '계정별로 필터를 설정하면 초안 내용(과 내부 포맷)에 맞는 계정이 게시 대상 후보가 됩니다.';

  @override
  String get nodeprogComposerHandEdited =>
      '게시 대상이 노드 에디터에서 편집되었습니다. 여기서 변경하면 덮어씁니다';

  @override
  String get nodeprogComposerHandEditedDetail =>
      '게시 대상이 노드 에디터에서 편집되었습니다. 여기서 변경하면 간이 구성으로 바뀝니다.';

  @override
  String get nodeprogComposerFiltersHeader => '게시 대상 필터';

  @override
  String get nodeprogComposerFormatHeader => '포맷';

  @override
  String get nodeprogComposerFormatCaption => '필터에 맞지 않아도 다른 형태로 후보에 남길 수 있습니다';

  @override
  String get nodeprogComposerFormatCaptionDetail =>
      '필터에 맞지 않을 때 대체 포맷으로 후보에 남깁니다(제외되기 직전의 비교에서 우회).';

  @override
  String get nodeprogComposerDeliveryHeader => '연동 게시물 전달 방식';

  @override
  String get nodeprogComposerDeliveryCaption => '다른 계정과 함께 보낼 때의 설정입니다';

  @override
  String get nodeprogComposerDeliveryCaptionDetail =>
      '다중 선택 모드의 \'노드 연동\'으로 이 계정에 보낼 때의 전달 방식과 연동할 수 있는 연동 원본입니다.';

  @override
  String nodeprogComposerDeliveryTitle(String delivery) {
    return '전달 방식: $delivery';
  }

  @override
  String get nodeprogComposerLinkSourcesLabel =>
      '연동 원본 계정(주 게시 대상이 여기에 있을 때만 연동)';

  @override
  String get nodeprogComposerLinkFiltersCaption => '연동 필터(함께 보낼 때만 적용)';

  @override
  String get nodeprogComposerLinkFiltersCaptionDetail =>
      '연동 필터(연동 게시물에만 걸리는 관문. 게시 대상 판정에는 영향 없음)';

  @override
  String nodeprogComposerFilterDescription(String basis, String what) {
    return '이 계정의 $basis을(를) 기준으로 초안이 $what에서 맞으면 게시 대상 후보가 됩니다.';
  }

  @override
  String get nodeprogComposerFilterBasisPosts => '게시물';

  @override
  String get nodeprogComposerFilterBasisReplies => '답글';

  @override
  String get nodeprogComposerFilterDisabled =>
      '비활성화됨: 이 계정은 게시 대상 후보가 되지 않습니다.';

  @override
  String nodeprogComposerLinkOnlySubtitle(String account) {
    return '$account · 연동 전용';
  }

  @override
  String nodeprogComposerAndSubtitle(String account) {
    return '$account · 그리고';
  }

  @override
  String get nodeprogComposerLinkFilterDescription =>
      '연동 게시물이 이 조건에 맞지 않으면 이 계정으로 보내지 않습니다.';

  @override
  String get nodeprogComposerAndDescription => '이전 필터와 \'그리고\'로 연결됩니다.';

  @override
  String get nodeprogComposerDeleteNode => '노드 삭제';

  @override
  String nodeprogComposerRegexDescription(String pattern, String replace) {
    return '이 계정으로 보내는 본문의 \'$pattern\'을(를) \'$replace\'(으)로 치환합니다.';
  }

  @override
  String get nodeprogComposerRegexDescriptionEmpty =>
      '전송 시 본문에 정규식 치환을 적용합니다(예: 태그 교체, 가림 글자).';

  @override
  String get nodeprogComposerRegexUnset => '게시물 가공(미설정)';

  @override
  String nodeprogComposerRegexRule(String pattern, String replace) {
    return '\'$pattern\' → \'$replace\'';
  }

  @override
  String nodeprogComposerExtraNodeSubtitle(String account) {
    return '$account · 추가 노드';
  }

  @override
  String get nodeprogComposerExtraRegexDescription => '위의 가공에 이어서 적용됩니다.';

  @override
  String get nodeprogComposerCwLabel => '내용 경고';

  @override
  String get nodeprogComposerNoOtherAccounts => '다른 계정이 없습니다';

  @override
  String get nodeprogComposerRegexMenuTooltip => '게시물 가공 작업';

  @override
  String get nodeprogComposerFilterMenuTooltip => '게시 대상 작업';

  @override
  String get nodeprogComposerParamsRegexEnabled => '게시물 가공 사용';

  @override
  String get nodeprogComposerParamsRegexEnabledSubtitle =>
      '이 계정으로 보내는 본문에 패턴 치환을 적용합니다';

  @override
  String get nodeprogComposerParamsExtraRegex => '위의 가공에 이어서 적용되는 추가 노드입니다.';

  @override
  String get nodeprogComposerParamsFilterEnabled => '필터 사용';

  @override
  String get nodeprogComposerParamsFilterEnabledSubtitle =>
      '끄면 이 계정은 게시 대상 후보가 되지 않습니다';

  @override
  String get nodeprogComposerParamsWhat => '무엇을 볼까요?';

  @override
  String get nodeprogComposerParamsRegexDescription =>
      '전송 시 본문에 정규식 치환을 적용합니다.';

  @override
  String get nodeprogComposerParamsLinkFilterDescription =>
      '함께 보낼 때만 적용되는 조건입니다.';

  @override
  String get nodeprogComposerParamsLinkFilterDetail =>
      '연동 게시물에만 걸리는 관문입니다(게시 대상 판정에는 영향 없음).';

  @override
  String get nodeprogComposerParamsFilterDescription =>
      '초안이 이 조건에 맞으면 이 계정이 게시 대상 후보가 됩니다.';

  @override
  String get nodeprogComposerParamsPatternLabel => '패턴(정규식)';

  @override
  String get nodeprogComposerParamsPatternHint => '예: #스포일러\\s*';

  @override
  String get nodeprogComposerParamsReplaceLabel => '치환(비움 = 삭제)';

  @override
  String get nodeprogEditorCanvasInputs => '입력';

  @override
  String get nodeprogEditorCanvasOutputs => '출력';

  @override
  String get nodeprogEditorBadgeDefaultOwner => '기본';

  @override
  String get nodeprogEditorBadgeNotRegistered => '미등록';

  @override
  String get nodeprogEditorBadgeSeparator => ' · ';

  @override
  String get nodeprogEditorNodeTabDefaultLabel => '노드 TL';

  @override
  String get nodeprogEditorInlineEmpty => '노드가 없습니다';

  @override
  String get nodeprogEditorInlineExpandTooltip => '전체 화면에서 편집';

  @override
  String get nodeprogEditorParamsMissing =>
      '이 플러그인은 등록되어 있지 않습니다(스토어에서 다시 설치해 주세요).';

  @override
  String get nodeprogEditorParamsLoading => '파라미터를 불러오는 중…';

  @override
  String get nodeprogEditorParamsNone => '이 플러그인에는 파라미터가 없습니다.';

  @override
  String get nodeprogEditorCancelButton => '취소';

  @override
  String get nodeprogEditorConfirmButton => '확인';

  @override
  String get nodeprogEditorParamsTitle => '노드 설정';

  @override
  String get nodeprogEditorPluginSortAuthor => 'TL 플러그인';

  @override
  String get nodeprogEditorPluginSortDescription => '플러그인의 정렬 방식으로 게시물을 정렬합니다.';

  @override
  String get nodeprogEditorParamsPluginDetail =>
      '게시물 리스트를 플러그인의 정렬(tl.sort)로 정렬합니다. 파라미터는 노드의 \'파라미터\' 포트로 들어갑니다.';

  @override
  String nodeprogEditorPluginSortTitle(String name) {
    return '$name(으)로 정렬';
  }

  @override
  String get nodeprogEditorPluginSortDetail =>
      '게시물 리스트를 플러그인의 정렬(tl.sort)로 정렬합니다.';

  @override
  String get nodeprogEditorTitleFunctionBody => '함수 본문';

  @override
  String nodeprogEditorTitleFunctionBodyNamed(String name) {
    return '함수 본문 — $name';
  }

  @override
  String get nodeprogEditorTitleComposer => '게시 대상 맞춤 설정';

  @override
  String get nodeprogEditorTitleTrend => '트렌드 맞춤 설정';

  @override
  String get nodeprogEditorTitleTimeline => '타임라인 맞춤 설정';

  @override
  String get nodeprogEditorTabTrendNotes => '노트';

  @override
  String get nodeprogEditorTabFollowing => '팔로잉';

  @override
  String get nodeprogEditorTabTrendUsers => '사용자';

  @override
  String get nodeprogEditorTabBundle => '종합';

  @override
  String get nodeprogEditorTabSocial => '추천';

  @override
  String get nodeprogEditorTabRelational => '관련';

  @override
  String get nodeprogEditorTabLocal => '로컬';

  @override
  String get nodeprogEditorTabGlobal => '글로벌';

  @override
  String get nodeprogEditorAddTabTooltip => '탭 추가';

  @override
  String get nodeprogEditorNewTabTitle => '새 탭';

  @override
  String get nodeprogEditorTabNameHint => '탭 이름';

  @override
  String get nodeprogEditorRenameTab => '탭 이름 변경';

  @override
  String get nodeprogEditorDeleteTab => '탭 삭제';

  @override
  String get nodeprogEditorClearGraph => '그래프 지우기';

  @override
  String get nodeprogEditorBundleTabsToggle => '번들에서 노드 TL 모아 보기';

  @override
  String get nodeprogEditorPaletteSearchHint => '플러그인 노드 검색';

  @override
  String nodeprogEditorConnectTypeMismatch(String from, String to) {
    return '연결할 수 없습니다: $from → $to (형식이 맞지 않습니다)';
  }

  @override
  String get nodeprogEditorCreateFunction => '커스텀 함수 만들기';

  @override
  String get nodeprogEditorFunctionNameHint => '함수 이름';

  @override
  String get nodeprogEditorFunctionSourceLabel => '입력 소스';

  @override
  String get nodeprogEditorFunctionSourceCond => '조건';

  @override
  String get nodeprogEditorFunctionSourceData => '데이터';

  @override
  String get nodeprogEditorFunctionCondTagsLabel =>
      '조건 태그 (여러 개 고르면 아래쪽 분기가 늘어납니다)';

  @override
  String get nodeprogEditorFunctionInputsLabel => '입력 (데이터 형식)';

  @override
  String get nodeprogEditorFunctionOutputsLabel => '출력 (데이터 형식)';

  @override
  String get nodeprogEditorCreateButton => '만들기';

  @override
  String get nodeprogEditorMenuInfo => '노드 정보';

  @override
  String get nodeprogEditorMenuEditFunctionBody => '함수 본문 편집';

  @override
  String get nodeprogEditorMenuStore => '플러그인 스토어로 이동';

  @override
  String get nodeprogEditorMenuCopy => '복사';

  @override
  String get nodeprogEditorMenuPaste => '붙여넣기';

  @override
  String get nodeprogEditorMenuDelete => '삭제';

  @override
  String get nodeprogEditorMoreTooltip => '더 보기';

  @override
  String get nodeprogEditorSearchNodesTooltip => '노드 검색';

  @override
  String get nodeprogEditorEmptyHint => '아래 검색에서 추가 (탭하면 상세, 길게 누르면 드래그)';

  @override
  String get nodeprogEditorToolbarSelect => '범위 선택';

  @override
  String get nodeprogEditorToolbarSelectStop => '범위 선택 그만두기';

  @override
  String get nodeprogEditorToolbarDeleteSelected => '선택한 노드 삭제';

  @override
  String get nodeprogEditorToolbarTidy => '정리';

  @override
  String get nodeprogEditorToolbarZoomOut => '축소';

  @override
  String get nodeprogEditorToolbarZoomIn => '확대';

  @override
  String get nodeprogEditorToolbarFit => '전체 보기';

  @override
  String get nodeprogEditorPaletteSortChip => '정렬: 관련순';

  @override
  String get nodeprogEditorPaletteSortRelevance => '관련순';

  @override
  String nodeprogEditorPaletteGenreChip(String genre) {
    return '장르: $genre';
  }

  @override
  String get nodeprogEditorPaletteGenreAll => '전체';

  @override
  String get nodeprogEditorPaletteSettingsTooltip => '검색 설정 (준비 중)';

  @override
  String get nodeprogEditorPaletteEmptyTitle => '노드를 찾을 수 없습니다';

  @override
  String get nodeprogEditorPaletteEmptyHint => '검색어나 장르를 바꿔 보세요';

  @override
  String get nodeprogEditorCreateFunctionDescription =>
      '조건 태그나 입출력(데이터 형식)을 골라 나만의 함수 노드를 만듭니다. 데이터 함수는 본문을 노드로 짤 수 있습니다.';

  @override
  String nodeprogEditorTileSubtitle(String author, String genre) {
    return '$author · $genre';
  }

  @override
  String get nodeprogEditorBuiltinAuthor => '내장 노드';

  @override
  String get nodeprogEditorAddToCanvas => '캔버스에 추가';

  @override
  String get nodeprogEditorEditFunctionBody => '본문 편집';

  @override
  String get nodeprogEditorDeleteFunction => '함수 삭제';

  @override
  String nodeprogEditorInfoGenre(String genre) {
    return '장르: $genre';
  }

  @override
  String get nodeprogEditorInfoCondIn => '조건 (위쪽)';

  @override
  String get nodeprogEditorInfoCondOut => '조건 (아래쪽)';

  @override
  String get nodeprogTimelineTabDmCommon => 'DM(공통)';

  @override
  String get nodeprogTimelineTabThisDm => '이 DM';

  @override
  String get nodeprogTimelineTabTrendPage => '트렌드 페이지';

  @override
  String get nodeprogTimelineTabTrendTl => '트렌드 타임라인';

  @override
  String get nodeprogTimelineTabThisList => '이 리스트';

  @override
  String get nodeprogTimelineReorderTabs => '탭 순서 변경';

  @override
  String get nodeprogTimelineShareTab => '모든 계정에서 공유';

  @override
  String get nodeprogTimelineResetConfig => '이 타임라인의 구성 초기화';

  @override
  String get nodeprogTimelineEditAsGraph => '그래프로 편집';

  @override
  String nodeprogTimelinePluginWithVersion(String version) {
    return '타임라인 플러그인 · v$version';
  }

  @override
  String get nodeprogTimelineAlgoChronoDescription => '가져온 그대로 시간순으로 정렬합니다.';

  @override
  String get nodeprogTimelineAlgoTendencyDescription =>
      '취향 설정에 맞지 않는 게시물을 제외하고 잘 맞는 순으로 정렬합니다.';

  @override
  String get nodeprogTimelineAlgoTendencyDetail =>
      '트렌드 프로필(성향/자극성, 좋아하는 장르)에 맞지 않는 게시물을 제외하고 적합도순으로 정렬합니다.';

  @override
  String nodeprogTimelineAlgoSuggestDescription(
    String from,
    String kind,
    String what,
  ) {
    return '$from($kind)을(를) 기준으로 $what에서 맞는 게시물을 맨 앞으로 정렬합니다.';
  }

  @override
  String get nodeprogTimelineSuggestFromMyPosts => '내 게시물';

  @override
  String get nodeprogTimelineSuggestFromMyReplies => '내 답글';

  @override
  String get nodeprogTimelineSuggestFromReacted => '리액션한 게시물';

  @override
  String get nodeprogTimelineSourceHomeLabel => '팔로잉(home)';

  @override
  String get nodeprogTimelineSourceRasqTitle => 'RASQ 게시물 가져오기';

  @override
  String get nodeprogTimelineSourceRasqDescription =>
      '타임라인: 나와 팔로잉 중인 RASQ 계정의 게시물';

  @override
  String get nodeprogTimelineSourceRasqSearchTitle => 'RASQ 검색';

  @override
  String get nodeprogTimelineSourceRasqSearchPageQuery =>
      '검색: 이 페이지의 검색어 / 태그(팔로우하지 않은 사람의 게시물 포함)';

  @override
  String nodeprogTimelineSourceRasqSearchWord(String word) {
    return '검색: $word(팔로우하지 않은 사람의 게시물 포함)';
  }

  @override
  String get nodeprogTimelineSourceRasqListTitle => 'RASQ 리스트 가져오기';

  @override
  String nodeprogTimelineSourceRasqListDescription(String name) {
    return 'RASQ 리스트: $name';
  }

  @override
  String get nodeprogTimelineNotSelected => '선택 안 됨';

  @override
  String get nodeprogTimelineSectionTitle => '섹션';

  @override
  String nodeprogTimelineSectionDescription(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '노드를 $max개까지 담는 틀(화면에서는 넣은 순서대로 둥근 모서리 틀로 표시)',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceAstellTitle => 'ASTell 타일';

  @override
  String nodeprogTimelineSourceAstellDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '지금 열려 있는 ASTell 룸(최대 $count개)',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineSourceSwingDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Swing을 띄운 사람(최대 $count명)',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineSourceTrendFollowingTitle => '팔로잉의 반응';

  @override
  String get nodeprogTimelineSourceTrendFollowingDescription =>
      '팔로잉 중인 사람의, 이 페이지의 단어 / 태그 게시물';

  @override
  String get nodeprogTimelineTrendPluginAll => '설치된 트렌드 플러그인 전체';

  @override
  String nodeprogTimelineTrendPluginMissing(String id) {
    return '$id(설치되지 않음)';
  }

  @override
  String get nodeprogTimelineTrendPluginAuthor => '트렌드 플러그인';

  @override
  String nodeprogTimelineTrendPluginDescription(String name, String form) {
    return '$name · $form';
  }

  @override
  String get nodeprogTimelineCurrentAccount => '(현재 계정)';

  @override
  String get nodeprogTimelineAllAccounts => '모든 계정';

  @override
  String get nodeprogTimelineSourceTrendTitle => '트렌드 가져오기';

  @override
  String get nodeprogTimelineSourceTrendTagsAllDescription =>
      '종류: 트렌드 타일(RASQ 계정의 모든 SNS 계정의 트렌드 단어)';

  @override
  String get nodeprogTimelineSourceTrendTagsDescription =>
      '종류: 트렌드 타일(이 계정 서버의 트렌드 단어)';

  @override
  String get nodeprogTimelineSourceSearchTitle => '검색 결과 가져오기';

  @override
  String get nodeprogTimelineSourceSearchPageQuery => '검색: 이 페이지의 검색어 / 태그';

  @override
  String nodeprogTimelineSourceSearchWord(String word) {
    return '검색: $word';
  }

  @override
  String get nodeprogTimelineSourceTodayTitle => 'Today 가져오기';

  @override
  String get nodeprogTimelineSourceTodayDescription => '타임라인: Today(주목할 게시물)';

  @override
  String nodeprogTimelineSourceSelfTitle(String name) {
    return '$name 가져오기';
  }

  @override
  String get nodeprogTimelineSourceDmTitle => 'DM 가져오기';

  @override
  String get nodeprogTimelineSourceFeedTitle => '커스텀 피드 가져오기';

  @override
  String get nodeprogTimelineSourceListTitle => '리스트 타임라인 가져오기';

  @override
  String get nodeprogTimelineSourceTimelineTitle => '타임라인 가져오기';

  @override
  String nodeprogTimelineSourceTlDescription(String tl) {
    return '타임라인: $tl';
  }

  @override
  String nodeprogTimelineSourceDmPeer(String peer) {
    return 'DM: @$peer';
  }

  @override
  String get nodeprogTimelineSourceTrendTlKind =>
      '종류: 트렌드 타임라인(상위 트렌드 태그의 검색 결과)';

  @override
  String nodeprogTimelineSourceFeedName(String name) {
    return '피드: $name';
  }

  @override
  String nodeprogTimelineSourceListName(String name) {
    return '리스트: $name';
  }

  @override
  String get nodeprogTimelineMenuInfo => '상세';

  @override
  String get nodeprogTimelineMenuEditParams => '매개변수 편집';

  @override
  String get nodeprogTimelineMenuDisable => '일시적으로 비활성화';

  @override
  String get nodeprogTimelineMenuEnable => '비활성화 해제';

  @override
  String get nodeprogTimelineMenuStore => '플러그인의 스토어 페이지로 이동';

  @override
  String get nodeprogTimelineMenuKindToTiles => '종류를 트렌드 타일로';

  @override
  String get nodeprogTimelineMenuKindToTl => '종류를 트렌드 타임라인으로';

  @override
  String nodeprogTimelineMenuLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '개수: $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineMenuForm(String form) {
    return '형식: $form';
  }

  @override
  String nodeprogTimelineMenuDisplay(String mode) {
    return '표시 모드: $mode';
  }

  @override
  String nodeprogTimelineLimitItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineInfoProvider(String provider) {
    return '제공: $provider';
  }

  @override
  String nodeprogTimelineInfoSupported(String sns) {
    return '지원: $sns';
  }

  @override
  String get nodeprogTimelineReorderAlgorithms => '알고리즘 순서 변경';

  @override
  String get nodeprogTimelineReorderSources => '타임라인 순서 변경';

  @override
  String get nodeprogTimelineBannerDmCommon => '모든 DM 페이지에 사용하는 설정입니다';

  @override
  String get nodeprogTimelineBannerDmPage => '이 DM 페이지에만 적용되는 설정입니다';

  @override
  String get nodeprogTimelineBanner => '타임라인의 내용과 정렬 방식을 정할 수 있습니다';

  @override
  String get nodeprogTimelineBannerDmCommonDetail =>
      'DM의 기본 설정입니다. 개별 설정이 없는 모든 DM 페이지에 적용됩니다. 알고리즘은 위에서부터 순서대로 적용됩니다.';

  @override
  String get nodeprogTimelineBannerDmPageDetail =>
      '이 DM 페이지만의 설정입니다(저장하면 DM 공통 설정보다 우선합니다). 알고리즘은 위에서부터 순서대로 적용됩니다.';

  @override
  String get nodeprogTimelineBannerDetail =>
      '타임라인의 알고리즘, 가져오기, 표시할 타임라인 등을 지정할 수 있습니다. 알고리즘은 위에서부터 순서대로 적용됩니다.';

  @override
  String get nodeprogTimelineCreateNameLabel => '타임라인 이름';

  @override
  String get nodeprogTimelineCreateNameHint => '예: 친구 / 사진';

  @override
  String get nodeprogTimelineTempSearchOnly =>
      '플러그인이 정렬하는 타임라인입니다. 여기서는 검색만 할 수 있습니다';

  @override
  String get nodeprogTimelineTempChanged => '이 타임라인을 일시적으로 바꾸고 있습니다(저장하지 않음).';

  @override
  String get nodeprogTimelineTempRevert => '되돌리기';

  @override
  String get nodeprogTimelineTempSave => '이 내용으로 저장';

  @override
  String get nodeprogTimelineTempNotice =>
      '여기서의 변경은 일시적입니다. 저장하기 전까지 원래 설정은 바뀌지 않습니다';

  @override
  String get nodeprogTimelineTempNoticeDetail =>
      '여기서의 변경은 이 타임라인에 일시적으로 적용됩니다. 저장하기 전까지 원래 설정은 바뀌지 않습니다.';

  @override
  String get nodeprogTimelineCreateCaption => '가져올 타임라인과 알고리즘을 고른 뒤 \'확인\'';

  @override
  String get nodeprogTimelineHandEdited =>
      '이 타임라인은 노드 에디터에서 편집되었습니다. 여기서 변경하면 덮어씁니다';

  @override
  String get nodeprogTimelineHandEditedDetail =>
      '이 타임라인은 노드 에디터에서 편집되었습니다. 여기서 변경하면 간이 구성으로 바뀝니다.';

  @override
  String get nodeprogTimelineAlgorithmsHeader => '알고리즘';

  @override
  String get nodeprogTimelineAddAlgorithm => '알고리즘 추가';

  @override
  String nodeprogTimelineSectionSubtitle(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '섹션 · $count / $max',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineDisabledSuffix => ' · 비활성화됨';

  @override
  String get nodeprogTimelineDisabled => '비활성화됨';

  @override
  String get nodeprogTimelineMetaSeparator => ' · ';

  @override
  String get nodeprogTimelineSectionMenuTooltip => '섹션 작업';

  @override
  String get nodeprogTimelineAddNode => '노드 추가';

  @override
  String get nodeprogTimelineNodeMenuTooltip => '노드 작업';

  @override
  String get nodeprogTimelineSectionRename => '제목 변경';

  @override
  String get nodeprogTimelineSectionRenameTitle => '섹션 제목';

  @override
  String get nodeprogTimelineMenuTakeOut => '섹션에서 꺼내기';

  @override
  String get nodeprogTimelineDisplayHeader => '표시 모드';

  @override
  String nodeprogTimelineDisplayTitle(String mode) {
    return '표시: $mode';
  }

  @override
  String get nodeprogTimelineDisplaySubtitle =>
      '같은 게시물을 일반 타임라인 / 대화 묶음(관련 타임라인) / 게시한 사람별로 보여 줍니다';

  @override
  String get nodeprogTimelineSourcesHeader => 'SNS 타임라인';

  @override
  String get nodeprogTimelineReorderDone => '순서 변경 완료';

  @override
  String get nodeprogTimelineTrendPageCaption =>
      '검색 홈에 위에서부터 순서대로 표시합니다. 섹션으로 트렌드와 Today 구간을 나눕니다';

  @override
  String get nodeprogTimelineTrendPageCaptionDetail =>
      '검색 홈에 위에서부터 순서대로 표시합니다. 기본값은 \'트렌드\'(모든 계정의 트렌드 타일)와 \'Today\' 섹션입니다. 알고리즘은 트렌드 타일에 적용됩니다(무거운 것은 사용할 수 없습니다).';

  @override
  String get nodeprogTimelineSourcesCaption =>
      '여러 개를 겹치면 하나로 합쳐지고 같은 게시물은 하나가 됩니다';

  @override
  String get nodeprogTimelineSourcesCaptionDetail =>
      '여러 개를 겹치면 하나로 합류하고 같은 게시물은 한 장으로 접힙니다(타일의 ↓로 계정 전환). 게시물 가공 플러그인은 각 타임라인 제공자(SNS 플러그인) 쪽에서 적용됩니다.';

  @override
  String get nodeprogTimelineReorderHint =>
      '길게 눌러 잡고 옮깁니다. 섹션 안(최대 3개)으로 넣고 뺄 수도 있습니다';

  @override
  String get nodeprogTimelineAddSource => '타임라인 추가';

  @override
  String get nodeprogTimelineClockHeader => '자동 새로고침';

  @override
  String nodeprogTimelineClockInterval(String interval) {
    return '간격: $interval';
  }

  @override
  String get nodeprogTimelineAlgorithmMenuTooltip => '알고리즘 작업';

  @override
  String get nodeprogTimelineSourceMenuTooltip => '타임라인 작업';

  @override
  String nodeprogTimelineTendencyGenres(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '좋아하는 장르 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyDisliked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '좋아하지 않음 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyExamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '예시 $count',
    );
    return '$_temp0';
  }

  @override
  String nodeprogTimelineTendencyStimulus(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '자극성 상한 $count',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTendencyPinnedTitle => '성향/자극성(경향)';

  @override
  String get nodeprogTimelineTendencyPinnedSubtitle => '항상 마지막';

  @override
  String get nodeprogTimelineTendencyPinnedEmpty => '경향 FOW 설정';

  @override
  String get nodeprogTimelineTendencyPinnedInfo =>
      '경향 FOW에서 설정한 성향/자극성을 알고리즘의 맨 마지막에 적용합니다. 여기서는 뺄 수 없습니다(변경 / 중지는 경향 FOW에서)';

  @override
  String get nodeprogTimelineParamsSuggestWhat => '무엇으로 추천할까요?';

  @override
  String get nodeprogTimelineParamsSuggestFrom => '무엇에서 읽어 낼까요?';

  @override
  String get nodeprogTimelineParamsPluginPending => '이 플러그인의 설정은 준비 중입니다.';

  @override
  String get nodeprogTimelineParamsQueryFilter =>
      '단어가 비어 있으면 이 페이지의 검색어/태그로 필터링합니다. 단어는 아래 칸에서 지정할 수 있습니다.';

  @override
  String get nodeprogTimelineParamsTendency => '취향 설정을 사용합니다. 아래에서 바꿀 수 있습니다.';

  @override
  String get nodeprogTimelineParamsChrono => '시간순에는 매개변수가 없습니다.';

  @override
  String get nodeprogTimelineParamsPluginPendingDetail =>
      '이 플러그인의 매개변수(RRL 설정 페이지)는 노드 정의 배포(스토어 통합) 후 여기에 표시됩니다.';

  @override
  String get nodeprogTimelineParamsTendencyDetail =>
      'storage.safe의 트렌드 프로필을 사용합니다. 아래 옵션에서 성향/자극성, 좋아하는 장르, 액션에서 장르 선택을 편집할 수 있습니다(검색 홈의 트렌드 ⚙와 같음).';

  @override
  String get nodeprogTimelineParamsTrendPlugin =>
      '트렌드 플러그인이 낸 후보 단어를 선택한 형식으로 표시합니다.';

  @override
  String get nodeprogTimelineParamsTrendPluginDetail =>
      'trend.suggest 슬롯의 답(후보 단어)을 트렌드 가져오기 = 트렌드 타일 / Today = 상위 단어 게시물 다이제스트 / 커스텀 = 후보 칩 으로 표시합니다. 개수는 …에서.';

  @override
  String get nodeprogTimelineParamsForm => '형식';

  @override
  String get nodeprogTimelineParamsRasq =>
      '나와 팔로잉 중인 사람의 RASQ 게시물을 가져옵니다. RASQ에 로그인했을 때만 표시됩니다.';

  @override
  String get nodeprogTimelineParamsRasqDetail =>
      '나와 팔로잉 중인 RASQ 계정의 게시물 / 리브로드를 가져옵니다. RASQ 계정에 로그인했을 때만 표시됩니다. 매개변수는 없습니다.';

  @override
  String get nodeprogTimelineParamsRasqSearch =>
      'RASQ의 공개 게시물을 검색해 가져옵니다. 팔로우하지 않은 사람의 게시물도 포함됩니다.';

  @override
  String get nodeprogTimelineParamsRasqSearchDetail =>
      'RASQ의 공개 게시물(팔로잉 여부와 관계없이)을 아래 단어로 검색해 가져옵니다. 비워 두면 이 페이지의 검색어 / 태그로 찾습니다. 표시 모드를 \'사용자\'로 하면 게시한 사람의 타일로 정렬됩니다.';

  @override
  String get nodeprogTimelineParamsRasqList =>
      'RASQ 리스트의 게시물을 가져옵니다. 아래에서 고르면 그 리스트를 팔로우합니다.';

  @override
  String get nodeprogTimelineParamsRasqListDetail =>
      'RASQ 리스트의 게시물을 가져옵니다(볼 때 Central이 리스트 안 사람들의 게시물을 모읍니다). 아래 칸에서 내 리스트·팔로잉 중인 리스트에서 고르거나 공개 리스트를 검색해 고릅니다. 고르면 그 리스트를 팔로우합니다.';

  @override
  String nodeprogTimelineParamsSelfDetail(String name) {
    return '$name을(를) 그대로 가져옵니다. 매개변수는 없습니다.';
  }

  @override
  String get nodeprogTimelineParamsAccount => '계정';

  @override
  String get nodeprogTimelineParamsTlKind => '타임라인 종류(이 SNS가 제공하는 것)';

  @override
  String get nodeprogTimelineParamsList => '리스트(이 계정의 것)';

  @override
  String get nodeprogTimelineParamsNoLists =>
      '이 계정에는 리스트가 없습니다(또는 가져올 수 없습니다).';

  @override
  String get nodeprogTimelineParamsFeed => '커스텀 피드(아래 칸에서 검색해 선택)';

  @override
  String get nodeprogTimelineParamsTendencyEdit => '트렌드 성향/자극성';

  @override
  String get nodeprogTimelineParamsGenresEdit => '좋아하는 장르/방향성';

  @override
  String get nodeprogTimelineParamsPickGenresSubtitle =>
      '비슷한 화제로 묶어 화제성이 강한 것부터';

  @override
  String get nodeprogTimelineParamsRasqSearchWordLabel =>
      '검색어(비움 = 이 페이지의 단어 / 태그)';

  @override
  String get nodeprogTimelineParamsRasqListSearchLabel =>
      'RASQ 리스트 검색(이름 / @만든 사람 / 공유 링크)';

  @override
  String get nodeprogTimelineParamsFeedSearchLabel => '피드 검색';

  @override
  String get nodeprogTimelineParamsFeedNotFound => '찾을 수 없습니다';

  @override
  String get nodeprogTimelineParamsQueryLabel => '검색어(비움 = 이 페이지의 검색어)';

  @override
  String get nodeprogTimelineParamsExcludeTitle => '이 단어를 포함한 게시물 제외';

  @override
  String get nodeprogTimelineParamsExcludeSubtitle => '끄면 포함한 게시물만 통과시킵니다';

  @override
  String get nodeprogTimelineCreateTitle => '타임라인 만들기';

  @override
  String nodeprogTimelineCreateDefaultName(int number) {
    return '타임라인 $number';
  }

  @override
  String get nodeprogTimelineCreateShareTitle => '다른 계정에도 적용할까요?';

  @override
  String get nodeprogTimelineCreateShareMessage =>
      '\'모든 계정에 적용\'을 선택하면 어느 계정에서든 이 타임라인이 표시되고 내용 변경도 모두에 적용됩니다(나중에 … 메뉴에서 바꿀 수 있습니다).';

  @override
  String get nodeprogTimelineCreateShareConfirm => '모든 계정에 적용';

  @override
  String get nodeprogTimelineCreateShareCancel => '이 계정만';

  @override
  String get nodeprogTimelineLoadFailed => '불러오지 못했습니다';

  @override
  String get nodeprogTimelineNodeTrend => '트렌드';

  @override
  String get nodeprogTimelineNodeTabFallback => '노드 타임라인';

  @override
  String get nodeprogTimelineReload => '다시 불러오기';

  @override
  String get nodeprogTimelineAstellEmpty => '지금 열려 있는 ASTell이 없습니다';

  @override
  String nodeprogTimelineAstellEmptyQuery(String query) {
    return '\'$query\'의 ASTell이 없습니다';
  }

  @override
  String get nodeprogTimelineSwingEmpty => '지금 Swing이 없습니다';

  @override
  String nodeprogTimelineSwingEmptyQuery(String query) {
    return '\'$query\'의 Swing이 없습니다';
  }

  @override
  String get nodeprogTimelineTrendEmpty => '아직 트렌드가 없습니다';

  @override
  String get nodeprogTimelineTrendFollowingNoQuery => '트렌드 타임라인에서 표시됩니다';

  @override
  String get nodeprogTimelineTrendFollowingEmpty => '아직 팔로잉 중인 사람의 반응이 없습니다';

  @override
  String get nodeprogTimelinePostsEmpty => '아직 없습니다';

  @override
  String get nodeprogTimelineEventsEmpty => '아직 대화 묶음이 없습니다';

  @override
  String get nodeprogTimelineUsersEmpty => '아직 아무도 없습니다';

  @override
  String nodeprogTimelineUserPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '게시물 $count개',
    );
    return '$_temp0';
  }

  @override
  String get nodeprogTimelineTempSemantics => '타임라인을 일시적으로 변경';

  @override
  String get nodeprogTimelineSearchPrev => '이전 일치 게시물';

  @override
  String get nodeprogTimelineSearchNext => '다음 일치 게시물';

  @override
  String get nodeprogTimelineSearchHint => '이 타임라인에서 검색';

  @override
  String get nodeprogTimelineSearchFuzzy => '유사 검색';

  @override
  String get nodeprogTimelineTempClose => '닫기';

  @override
  String get nodeprogTimelineTempTitle => '타임라인 일시 변경';

  @override
  String get nodeprogTimelinePaletteSuggestTitle => '추천';

  @override
  String get nodeprogTimelinePaletteSuggestDescription =>
      '내 게시물이나 반응과 비슷한 게시물을 맨 앞에 정렬합니다.';

  @override
  String get nodeprogTimelinePaletteSuggestDetail =>
      '[키워드/유사성]을 [게시물 내용/리액션/대화 내용]에서 읽어 내어 맞는 게시물을 맨 앞으로 정렬합니다.';

  @override
  String get nodeprogTimelinePaletteFilterTitle => '필터';

  @override
  String get nodeprogTimelinePaletteFilterDescription =>
      '내 게시물이나 반응에 맞지 않는 게시물을 제외합니다.';

  @override
  String get nodeprogTimelinePaletteFilterDetail =>
      '[키워드/유사성]을 [게시물 내용/리액션/대화 내용]에서 읽어 내어 맞지 않는 게시물을 제외합니다(추천과 같은 매개변수).';

  @override
  String get nodeprogTimelinePaletteQueryFilterTitle => '검색 필터';

  @override
  String get nodeprogTimelinePaletteQueryFilterDescription =>
      '이 페이지의 검색어/태그(또는 지정한 단어)에 맞는 게시물만 통과시킵니다.';

  @override
  String get nodeprogTimelinePaletteTendencyTitle => '성향/자극성';

  @override
  String get nodeprogTimelinePaletteTendencyDescription =>
      '취향 설정에 맞지 않는 게시물을 제외하고 잘 맞는 순으로 정렬합니다.';

  @override
  String get nodeprogTimelinePaletteTendencyDetail =>
      '트렌드 프로필(좋아하는 장르/방향성, 성향 임계값, 자극성 상한)에 맞지 않는 게시물을 제외하고 적합도순으로 정렬합니다. 프로필은 검색 홈의 트렌드 ⚙에서 편집합니다.';

  @override
  String get nodeprogTimelinePalettePickGenresTitle => '액션에서 장르 선택';

  @override
  String get nodeprogTimelinePalettePickGenresDescription =>
      '반응한 게시물의 화제에서 좋아하는 장르를 고릅니다.';

  @override
  String get nodeprogTimelinePalettePickGenresDetail =>
      '리액션한 게시물을 비슷한 화제로 묶어 화제성이 강한 것부터 \'좋아함 / 좋아하지 않음\'으로 좋아하는 장르를 정합니다(성향/자극성 컴포넌트가 이 프로필을 사용합니다).';

  @override
  String get nodeprogTimelinePaletteChronoTitle => '시간순';

  @override
  String get nodeprogTimelinePaletteChronoDescription => '가져온 그대로 시간순으로 정렬합니다.';

  @override
  String get nodeprogTimelinePaletteThisDmDescription =>
      '이 DM 페이지의 메시지를 그대로 가져옵니다.';

  @override
  String get nodeprogTimelinePaletteThisDmDetail =>
      '이 DM 페이지의 메시지를 그대로 가져옵니다(공통 설정에서는 각 페이지의 DM).';

  @override
  String get nodeprogTimelinePaletteSearchResultsDescription =>
      '이 계정으로 이 페이지의 검색어 / 태그를 검색한 결과를 가져옵니다.';

  @override
  String get nodeprogTimelinePaletteRasqPostsTitle => 'RASQ 게시물';

  @override
  String get nodeprogTimelinePaletteRasqPostsDescription =>
      '나와 팔로잉 중인 사람의 RASQ 게시물을 가져옵니다.';

  @override
  String get nodeprogTimelinePaletteRasqPostsDetail =>
      '나와 팔로잉 중인 RASQ 계정의 게시물 / 리브로드를 가져옵니다. SNS 게시물과 같은 타임라인에 섞을 수 있습니다.';

  @override
  String get nodeprogTimelinePaletteTimelineTitle => '타임라인';

  @override
  String get nodeprogTimelinePaletteTimelineDescription =>
      '계정의 타임라인을 가져옵니다. 종류는 추가한 뒤 고를 수 있습니다.';

  @override
  String get nodeprogTimelinePaletteTimelineDetail =>
      '계정의 기본 타임라인을 가져옵니다. 종류는 그 SNS가 제공하는 것(팔로잉 / 로컬 / 글로벌 / Discover …) 중에서 계정과 함께 추가 후 타일에서 고를 수 있습니다.';

  @override
  String get nodeprogTimelinePaletteListTlTitle => '리스트 타임라인';

  @override
  String get nodeprogTimelinePaletteListTlDescription =>
      '계정의 리스트를 가져옵니다. 리스트는 추가한 뒤 고를 수 있습니다.';

  @override
  String get nodeprogTimelinePaletteListTlDetail =>
      '계정과 그 계정에 포함된 리스트의 타임라인을 가져옵니다(추가 후 타일에서 선택).';

  @override
  String get nodeprogTimelinePaletteFeedTitle => '커스텀 피드(Bluesky)';

  @override
  String get nodeprogTimelinePaletteFeedDescription =>
      'Bluesky의 커스텀 피드를 찾아 가져옵니다.';

  @override
  String get nodeprogTimelinePaletteFeedDetail =>
      'Bluesky의 커스텀 피드를 검색해 가져옵니다(여러 SNS에 걸친 리스트는 \'RASQ 리스트\').';

  @override
  String get nodeprogTimelinePaletteRasqListTitle => 'RASQ 리스트';

  @override
  String get nodeprogTimelinePaletteRasqListDescription =>
      '여러 SNS의 사람을 모은 리스트의 게시물을 가져옵니다.';

  @override
  String get nodeprogTimelinePaletteRasqListDetail =>
      'RASQ 리스트(Misskey / Mastodon / Bluesky의 사람을 하나로 모은 리스트)의 게시물을 가져옵니다. 내 리스트·팔로잉 중인 리스트에서 고르거나 공개 리스트를 검색합니다. 리스트 안 사람의 정보를 가져올 수 있는(같은 서버의 계정이 있음 / 들어 있는 사람을 팔로우하고 있음) 리스트만 고를 수 있습니다.';

  @override
  String get nodeprogTimelinePaletteTrendDescription =>
      '지금의 트렌드를 가져옵니다. 종류(트렌드 타일 / 트렌드 타임라인)는 추가한 뒤 전환합니다.';

  @override
  String get nodeprogTimelinePaletteTrendDetail =>
      '트렌드 타일 = 서버의 트렌드 단어 타일, 트렌드 타임라인 = 지금의 상위 트렌드 태그 검색 결과를 하나로 합류한 게시물.';

  @override
  String get nodeprogTimelinePaletteTrendFollowingDescription =>
      '팔로잉 중인 사람의, 이 페이지의 단어 / 태그 게시물을 표시합니다.';

  @override
  String nodeprogTimelinePaletteDmPeerDescription(String peer) {
    return '@$peer 님과의 DM을 가져옵니다.';
  }

  @override
  String get nodeprogTimelinePaletteSectionDescription =>
      '노드를 3개까지 담는 틀입니다. 화면에서는 제목 아래에 넣은 순서대로 표시합니다.';

  @override
  String get nodeprogTimelinePaletteAstellDescription =>
      '지금 열려 있는 ASTell 룸을 타일로 표시합니다.';

  @override
  String get nodeprogTimelinePaletteSwingDescription => 'Swing을 띄운 사람을 나열합니다.';

  @override
  String nodeprogTimelinePaletteTrendPluginTitle(String form, String name) {
    return '$form: $name';
  }

  @override
  String nodeprogTimelinePaletteTrendPluginDetail(String form) {
    return '$form(trend.suggest 슬롯의 답을 이 형식의 노드로 표시합니다)';
  }

  @override
  String nodeprogTimelinePaletteTodayTitle(String account) {
    return 'Today: $account';
  }

  @override
  String get nodeprogTimelinePaletteSnsPluginAuthor => 'SNS 플러그인';

  @override
  String get nodeprogTimelinePaletteListsAuthor => '리스트 계열';

  @override
  String get nodeprogTimelinePaletteTodayDescription =>
      '이 계정의 Today(주목할 게시물)를 가져옵니다.';

  @override
  String nodeprogTimelinePaletteTrendTagsTitle(String account) {
    return '트렌드: $account';
  }

  @override
  String get nodeprogTimelinePaletteTrendTagsAllDescription =>
      'RASQ 계정의 모든 SNS 계정의 트렌드 단어를 타일로 표시합니다.';

  @override
  String get nodeprogTimelinePaletteTrendTagsDescription =>
      '이 계정 서버의 트렌드 단어를 타일로 표시합니다.';

  @override
  String nodeprogTimelinePaletteSearchResultsTitle(String account) {
    return '검색 결과: $account';
  }

  @override
  String nodeprogTimelinePaletteSelfDescription(String name) {
    return '$name을(를) 그대로 가져옵니다.';
  }

  @override
  String get nodeprogTimelinePaletteRasqSearchDescription =>
      '팔로우하지 않은 사람도 포함해 RASQ 게시물을 검색해 가져옵니다. 표시 모드 \'사용자\'로 사람 타일이 됩니다.';

  @override
  String get nodeprogTimelinePaletteEmptyTitle => '컴포넌트를 찾을 수 없습니다';

  @override
  String get nodeprogTimelinePaletteEmptyHint => '검색어를 바꿔 보세요';

  @override
  String get notificationsPrefReaction => '리액션 알림';

  @override
  String get notificationsPrefRepost => '리노트 알림';

  @override
  String get notificationsPrefQuote => '인용 알림';

  @override
  String get notificationsPrefAstell => 'ASTell 알림';

  @override
  String get notificationsPrefTimer => '타이머 북마크 알림';

  @override
  String get notificationsPrefPollEnded => '투표 종료 알림';

  @override
  String get notificationsPrefFollow => '팔로우 알림';

  @override
  String get notificationsPrefSystem => '시스템 알림 표시';

  @override
  String get notificationsPrefOther => '기타 알림 전송';

  @override
  String get notificationsTabAll => '전체';

  @override
  String get notificationsTabFollowing => '팔로잉';

  @override
  String get notificationsPrefsTitle => '알림 프로필 설정';

  @override
  String get notificationsEmptyFollowing => '팔로잉 알림이 없습니다';

  @override
  String get notificationsClose => '닫기';

  @override
  String get notificationsPrefEnabled => '알림 켜기';

  @override
  String get notificationsPushTitle => '푸시 알림 수신';

  @override
  String get notificationsPushDetail => '알림 전용 액세스 토큰';

  @override
  String get notificationsQuickReadAll => '모든 알림 읽음 처리';

  @override
  String get notificationsQuickReadFollowing => '팔로잉 알림 읽음 처리';

  @override
  String get notificationsQuickOff => '알림 끄기';

  @override
  String get notificationsEmpty => '알림이 없습니다';

  @override
  String get notificationsRetry => '다시 불러오기';

  @override
  String get notificationsRemindersHeader => '시작 알림을 등록한 ASTell';

  @override
  String notificationsReminderSchedule(String when) {
    return '개최 예정 $when';
  }

  @override
  String get notificationsReminderCancel => '해제';

  @override
  String get notificationsSystemFallbackTitle => '시스템 알림';

  @override
  String notificationsActorsOne(String name) {
    return '$name님';
  }

  @override
  String notificationsActorsTwo(String first, String second) {
    return '$first님, $second님';
  }

  @override
  String notificationsActorsMore(String first, String second, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$first님, $second님 외 $count명',
    );
    return '$_temp0';
  }

  @override
  String notificationsActionReacted(String names) {
    return '$names이(가) 내 게시물에 리액션했습니다';
  }

  @override
  String notificationsActionReposted(String names) {
    return '$names이(가) 내 게시물을 리노트했습니다';
  }

  @override
  String notificationsActionPollEnded(String names) {
    return '$names의 투표가 종료되었습니다';
  }

  @override
  String notificationsActionOther(String names) {
    return '$names의 알림';
  }

  @override
  String get notificationsMenuTooltip => '메뉴';

  @override
  String notificationsFollowFollowed(String name) {
    return '$name이(가) 나를 팔로우했습니다';
  }

  @override
  String notificationsFollowRequested(String name) {
    return '$name에게서 팔로우 요청이 왔습니다';
  }

  @override
  String notificationsFollowAccepted(String name) {
    return '$name이(가) 팔로우를 승인했습니다';
  }

  @override
  String notificationsFollowListAdded(String name) {
    return '$name이(가) 나를 리스트에 추가했습니다';
  }

  @override
  String get notificationsFollowButton => '팔로우';

  @override
  String get notificationsFollowingButton => '팔로잉';

  @override
  String get notificationsPostReply => '답글';

  @override
  String get notificationsPostQuote => '인용';

  @override
  String get notificationsPostMention => '멘션';

  @override
  String get notificationsTimerAstell => '북마크한 ASTell이 시작됩니다!';

  @override
  String get notificationsTimerBookmark => '타이머 북마크';

  @override
  String get notificationsRasqLoadError => '불러오지 못했습니다';

  @override
  String get notificationsRasqEmpty => 'RASQ 알림이 없습니다';

  @override
  String get notificationsRasqEmptyHint =>
      '멘션 / 답글 / 인용 / Swing 초대가 오면 여기에 표시됩니다';

  @override
  String get notifyPushChannelName => 'RASQ 알림';

  @override
  String get notifyPushChannelDescription => '멘션, 답글, Swing 등의 알림';

  @override
  String get notifyOpenAction => '열기';

  @override
  String get notifyGlimpseChannelName => '화면 읽기';

  @override
  String get notifyGlimpseChannelDescription => '탭하면 지금 보고 있는 화면을 잠깐 읽습니다';

  @override
  String get notifyAstellChannelName => 'ASTell 시작';

  @override
  String get notifyAstellChannelDescription => '북마크한 ASTell의 시작 알림';

  @override
  String get onboardingBack => '뒤로';

  @override
  String get onboardingHandleTooShort => '3자 이상 입력해 주세요';

  @override
  String get onboardingHandleTooLong => '32자까지 입력할 수 있습니다';

  @override
  String get onboardingHandleInvalid => '영문 소문자, 숫자, _만 사용할 수 있습니다';

  @override
  String get onboardingAccountTitleNew => '새 RASQ 계정 만들기';

  @override
  String get onboardingAccountTitle => 'RASQ 계정 만들기';

  @override
  String get onboardingAccountDescription =>
      'RASQ 계정은 로그인한 SNS 계정을 하나로 묶는 \'나\'의 그릇입니다. 설치한 플러그인, 설정, 계정 묶음을 다른 기기에서도 사용할 수 있습니다.';

  @override
  String get onboardingHandleLabel => '사용자 이름(@ 뒤의 이름)';

  @override
  String get onboardingHandleHelper => '영문 소문자, 숫자, _로 3~32자';

  @override
  String onboardingPasswordLabel(int min) {
    return '비밀번호($min자 이상)';
  }

  @override
  String get onboardingPasswordHide => '숨기기';

  @override
  String get onboardingPasswordShow => '표시';

  @override
  String get onboardingPasswordConfirmLabel => '비밀번호(확인)';

  @override
  String get onboardingPasswordMismatch => '일치하지 않습니다';

  @override
  String get onboardingPasswordCaption => '다른 기기나 웹 버전에서 이 계정에 로그인할 때 사용합니다.';

  @override
  String get onboardingAgeHeading => '나이';

  @override
  String get onboardingAgeCaption =>
      'RASQ는 13세 이상부터 사용할 수 있습니다. 18세 미만인 경우 다음 페이지에서 보호자의 동의를 확인합니다.';

  @override
  String get onboardingNoCentral => 'RASQ Central 접속 주소가 설정되지 않았습니다';

  @override
  String get onboardingSetCentral => '접속 주소 설정';

  @override
  String get onboardingNext => '다음';

  @override
  String onboardingCreateFailed(String error) {
    return 'RASQ 계정을 만들지 못했습니다: $error';
  }

  @override
  String get onboardingTermsTitle => '이용약관 및 개인정보 처리방침';

  @override
  String get onboardingTermsNoDraft => '먼저 ① 페이지에서 사용자 이름 등을 입력해 주세요';

  @override
  String get onboardingTermsRead => '이용약관 읽기';

  @override
  String get onboardingPrivacyRead => '개인정보 처리방침 읽기';

  @override
  String get onboardingAgree => '이용약관 및 개인정보 처리방침에 동의합니다';

  @override
  String get onboardingChildSafeHeading => '차일드 세이프(18세 미만)';

  @override
  String onboardingChildSafeNote(String age) {
    return '$age인 사람은 보호자의 동의가 필요합니다. 보호자의 RASQ 계정과 연결하면 보호자가 사용 방법(볼 수 있는 게시물의 수위, 사용 시간, 사용할 수 있는 기능)을 정할 수 있습니다(설정 → 차일드 세이프 → 차일드 모드).';
  }

  @override
  String get onboardingGuardianConsent => '보호자의 동의를 받았습니다';

  @override
  String get onboardingChildLogin => '보호자에게 받은 코드로 로그인';

  @override
  String get onboardingChildLoginCaption =>
      '보호자가 계정을 만들어 준 경우, 여기서 가입하지 말고 받은 코드로 로그인해 주세요.';

  @override
  String get onboardingBundleHeading => '계정 번들';

  @override
  String get onboardingBundleReplace => '이 기기의 SNS 계정으로 바꾸기';

  @override
  String onboardingBundleReplaceSubtitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '로그인 중인 $count개를 이 RASQ 계정으로 묶습니다',
    );
    return '$_temp0';
  }

  @override
  String get onboardingBundleKeep => '바꾸지 않기';

  @override
  String get onboardingBundleKeepSubtitle => 'SNS 계정은 이 기기에만 남깁니다';

  @override
  String get onboardingTermsContributionNote =>
      '\'알고리즘과 커뮤니티에 기여\'는 이번 가입에 포함되지 않습니다(별도의 선택 동의이며, 기본값은 \'제공하지 않음\'입니다). RASQ 계정은 언제든지 삭제할 수 있습니다.';

  @override
  String get onboardingRegister => '동의하고 가입';

  @override
  String get onboardingSnsTitle => 'SNS 계정으로 로그인';

  @override
  String get onboardingSnsDescription =>
      'RASQ 계정이 만들어졌습니다. 사용 중인 SNS 계정으로 로그인해 주세요. 아직 SNS를 사용하지 않는다면 \'SNS 서비스 찾기\'에서 맞는 서버나 리스트를 찾을 수 있습니다.';

  @override
  String onboardingSnsLoginWith(String service) {
    return '$service(으)로 로그인';
  }

  @override
  String get onboardingSnsPluginLoadNote =>
      '처음 로그인하기 전에 플러그인을 불러옵니다. 네트워크 환경이 좋은 곳에서 진행해 주세요.';

  @override
  String onboardingSignupGuideClosed(String name) {
    return '$name은(는) 지금 새 가입을 받지 않거나 초대제입니다. 초대 링크가 없다면 다른 서버를 선택해 주세요.';
  }

  @override
  String onboardingSignupGuideMastodonOpened(String name) {
    return '$name의 가입 페이지를 열었습니다. 서버 규칙이 나오면 읽고 \'동의\'를 눌러 주세요.';
  }

  @override
  String get onboardingSignupGuideMastodonForm =>
      '표시 이름, 사용자 이름, 이메일 주소, 비밀번호를 입력합니다. 사용자 이름은 나중에 바꿀 수 없으니 마음에 드는 것을 골라 주세요.';

  @override
  String get onboardingSignupGuideMastodonMail =>
      '가입을 누르면 확인 이메일이 도착합니다. 이메일의 링크를 열어 이메일 주소를 인증해 주세요.';

  @override
  String onboardingSignupGuideOpened(String name) {
    return '$name 페이지를 열었습니다. 페이지의 \'회원가입\'을 눌러 주세요.';
  }

  @override
  String get onboardingSignupGuideForm =>
      '사용자 이름과 비밀번호를 정합니다. 사용자 이름은 나중에 바꿀 수 없으니 마음에 드는 것을 골라 주세요.';

  @override
  String get onboardingSignupGuideChecks =>
      '서버에 따라 이메일 주소, 초대 코드, 로봇이 아님을 확인하는 절차를 요구할 수 있습니다. 화면의 안내에 따라 입력해 주세요.';

  @override
  String get onboardingSignupGuideRules =>
      '서버의 규칙(이용약관)을 읽고 동의합니다. 이메일 확인을 요구하면 받은 이메일의 링크를 열어 주세요.';

  @override
  String get onboardingSignupGuideDone =>
      '가입이 끝나면 아래의 \'가입 완료\'를 눌러 주세요. RASQ에서 이 서버에 로그인합니다.';

  @override
  String get onboardingSignupGuideThenPost => '로그인하면 아까의 게시물을 엽니다.';

  @override
  String onboardingSignupGuideThenList(String name) {
    return '로그인하면 RASQ 리스트 \'$name\'을(를) 엽니다.';
  }

  @override
  String get onboardingSignupGuideRasqLater =>
      'RASQ 계정은 나중에 사이드바의 …에서 만들 수 있습니다.';

  @override
  String get onboardingSignupTitleFallback => '서버에 가입';

  @override
  String get onboardingSignupNoTarget => '가입할 서버가 선택되지 않았습니다';

  @override
  String get onboardingSignupDone => '가입 완료(로그인으로)';

  @override
  String onboardingSignupTitle(String name) {
    return '$name에 가입';
  }

  @override
  String get onboardingSignupGuideHeading => 'RAi 안내';

  @override
  String get onboardingSignupGuidePrev => '이전';

  @override
  String get onboardingSignupNoWebView =>
      '이 기기에서는 앱 안에서 가입 페이지를 열 수 없습니다. 브라우저에서 열어 가입한 뒤 이 화면으로 돌아와 주세요.';

  @override
  String get onboardingSignupOpenBrowser => '브라우저에서 가입 페이지 열기';

  @override
  String onboardingSignupPostNotFound(String account) {
    return '$account에서 아까의 게시물을 찾지 못했습니다';
  }

  @override
  String get onboardingEntryCreateNew => '새 RASQ 계정 만들기';

  @override
  String get onboardingEntryCreate => 'RASQ 계정 만들기';

  @override
  String get onboardingEntryLogin => 'RASQ 계정에 로그인';

  @override
  String get onboardingEntryDiscover => 'SNS 서비스 찾기(이미지, 사람, RAi로)';

  @override
  String onboardingEntryResume(String name) {
    return '$name(으)로 계속';
  }

  @override
  String onboardingEntryResumeWithHandle(String name, String handle) {
    return '$name(@$handle)(으)로 계속';
  }

  @override
  String get onboardingEntryResumeFallbackName => 'RASQ 계정';

  @override
  String get onboardingEntrySnsOnly => 'SNS 계정만으로 사용';

  @override
  String get onboardingEntrySkip => '건너뛰고 이 기기에서만 사용';

  @override
  String get onboardingEntryHaveAccount => 'RASQ 계정이 있습니다';

  @override
  String get onboardingEntryLoginQuestion => 'RASQ 계정에 로그인할까요?';

  @override
  String get onboardingEntryCreateQuestion => 'RASQ 계정을 만들까요?';

  @override
  String get onboardingEntryLoginBody =>
      'RASQ 계정에 로그인하면 묶어 둔 SNS 계정, 설치한 플러그인, 설정이 이 기기로 돌아옵니다.';

  @override
  String get onboardingEntryCreateBody =>
      'RASQ 계정은 로그인한 SNS 계정을 하나로 묶는 \'나\'의 그릇입니다. 만들면 설치한 플러그인, 설정, 계정 묶는 방식이 RASQ Central에 저장되어 다른 기기에서도 같은 상태로 사용할 수 있습니다.';

  @override
  String get onboardingEntryWebNote =>
      '웹 버전에서는 SNS 로그인 정보를 RASQ 서버의 보관소에 맡깁니다(서버의 키로 암호화하며, RASQ 서버는 복호화할 수 있습니다). SNS만으로 사용할 수도 있지만, 그 경우 이 탭을 닫으면 로그인이 사라집니다.';

  @override
  String get onboardingEntrySnsOnlyNote =>
      'SNS 계정만으로 사용할 수도 있습니다. 이 경우 설치한 플러그인과 설정은 이 기기 안에만 저장됩니다.';

  @override
  String get onboardingEntrySkipNote =>
      '건너뛰어도 RASQ를 사용할 수 있습니다. 이 경우 설치한 플러그인과 설정은 이 기기 안에만 저장됩니다(나중에 사이드바의 …에서 만들 수 있습니다).';

  @override
  String get onboardingShowcaseTitle => '서버와 리스트 둘러보기';

  @override
  String get onboardingShowcaseServersHint => '탭하면 그 서버에 가입할 수 있습니다';

  @override
  String get onboardingShowcaseOpenServer => '서버 열기';

  @override
  String get onboardingShowcaseSignupServer => '이 서버에 가입';

  @override
  String get onboardingShowcaseListsHint =>
      'SNS를 넘나드는 사람들의 리스트입니다. 탭하면 리스트의 사람이 있는 서버에 가입할 수 있습니다';

  @override
  String get onboardingShowcaseListCannotSignup => '이 리스트의 서버에는 앱에서 가입할 수 없습니다';

  @override
  String get onboardingShowcasePickServer => '어느 서버에 가입할까요?';

  @override
  String onboardingShowcasePickServerSubtitle(String host, String kind) {
    return '$host · $kind';
  }

  @override
  String onboardingShowcasePostImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이미지 $count장',
    );
    return '$_temp0';
  }

  @override
  String get onboardingGenreGame => '게임';

  @override
  String get onboardingGenreAnime => '애니메이션·만화';

  @override
  String get onboardingGenreMusic => '음악';

  @override
  String get onboardingGenreArt => '일러스트·창작';

  @override
  String get onboardingGenrePhoto => '사진';

  @override
  String get onboardingGenreFood => '음식';

  @override
  String get onboardingGenreTech => 'IT·프로그래밍';

  @override
  String get onboardingGenreAnimal => '동물·반려동물';

  @override
  String get onboardingGenreSports => '스포츠';

  @override
  String get onboardingGenreTravel => '여행·나들이';

  @override
  String get onboardingGenreBooks => '책·독서';

  @override
  String get onboardingGenreMovie => '영화·드라마';

  @override
  String get onboardingGenreNature => '계절·자연';

  @override
  String onboardingPasswordTooShort(int min) {
    return '$min자 이상 입력해 주세요';
  }

  @override
  String get onboardingPasswordTooLong => '256자까지 입력할 수 있습니다';

  @override
  String get onboardingPasswordRepeated => '같은 문자의 반복은 사용할 수 없습니다';

  @override
  String get onboardingTermsOutdated => '이용약관이 새로워졌습니다. 앱을 업데이트한 뒤 다시 가입해 주세요';

  @override
  String get onboardingNoServer => 'RASQ 서버 접속 주소가 설정되지 않았습니다';

  @override
  String get onboardingHandleTaken => '이미 사용 중인 사용자 이름입니다';

  @override
  String onboardingHandleUnusable(String error) {
    return '이 사용자 이름은 사용할 수 없습니다($error)';
  }

  @override
  String onboardingHandleKept(String reason, String handle) {
    return '$reason. 사용자 이름은 @$handle 그대로입니다(프로필 편집에서 바꿀 수 있습니다)';
  }

  @override
  String onboardingPasswordSetFailed(String error) {
    return '계정은 만들었지만 비밀번호를 설정하지 못했습니다($error). 설정 → \'계정 보호\'에서 설정해 주세요';
  }

  @override
  String get onboardingRestored => '이 기기의 RASQ 계정으로 돌아왔습니다';

  @override
  String get onboardingNudgeTitle => 'RASQ 계정을 만들까요?';

  @override
  String get onboardingNudgeMessage =>
      'RASQ 계정이 있으면 설치한 플러그인, 설정, SNS 계정 묶음을 다른 기기에서도 사용할 수 있습니다. Swing과 RASQ 리스트도 RASQ 계정으로 사용합니다. 나중에 사이드바의 …에서도 만들 수 있습니다.';

  @override
  String get onboardingNudgeCreate => '만들기';

  @override
  String get onboardingNudgeLogin => '로그인(계정이 있는 경우)';

  @override
  String get onboardingNudgeLater => '나중에';

  @override
  String onboardingNudgeCreated(String handle) {
    return 'RASQ 계정 @$handle을(를) 만들었습니다';
  }

  @override
  String get onboardingFeedTitle => '공개 RASQ 리스트에서';

  @override
  String get onboardingFeedCaption => 'SNS를 넘나드는 사람들의 리스트에서 많이 읽힌 게시물입니다';

  @override
  String get onboardingFeedEmpty => '지금은 표시할 수 있는 게시물이 없습니다';

  @override
  String onboardingFeedListName(String name) {
    return '리스트 \'$name\'';
  }

  @override
  String get onboardingDiscoverTitle => 'SNS 서비스 찾기';

  @override
  String get onboardingDiscoverIntro =>
      '좋아하는 것에서 시작해 나에게 맞는 SNS 서버와 RASQ 리스트(SNS를 넘나드는 사람들의 리스트)를 찾습니다.';

  @override
  String get onboardingDiscoverContentTitle => '좋아하는 이미지나 콘텐츠로 찾기';

  @override
  String get onboardingDiscoverContentSubtitle => '이미지를 고르고 찾고 싶은 부분을 둘러싸세요';

  @override
  String get onboardingDiscoverPeopleTitle => '인기 사용자 / 인플루언서로 찾기';

  @override
  String get onboardingDiscoverPeopleSubtitle => '좋아하는 사람의 이름이나 분야로';

  @override
  String get onboardingDiscoverExportTitle => '다른 SNS의 내보내기 데이터로 찾기';

  @override
  String get onboardingDiscoverExportSubtitle => '준비 중';

  @override
  String get onboardingDiscoverAskTitle => 'RAi에게 묻기';

  @override
  String get onboardingDiscoverAskSubtitle => '대화하며 나에게 맞는 SNS를 찾습니다';

  @override
  String get onboardingDiscoverRaiBlocked => '보호자가 RAi를 막아 두었습니다';

  @override
  String onboardingDiscoverCannotLogin(String host) {
    return '$host에는 앱에서 로그인할 수 없습니다';
  }

  @override
  String onboardingDiscoverCannotSignup(String host) {
    return '$host에는 앱에서 가입할 수 없습니다';
  }

  @override
  String get onboardingDiscoverAddAccountBlocked => '보호자가 SNS 계정 추가를 막아 두었습니다';

  @override
  String get onboardingDiscoverDummyResult => '예시 결과입니다(서버의 외부 서비스가 설정되지 않음)';

  @override
  String get onboardingDiscoverPeopleWebHeading => 'SNS의 사람(웹 검색)';

  @override
  String get onboardingDiscoverListsHeading => 'RASQ 리스트';

  @override
  String get onboardingDiscoverServersHeading => '서버';

  @override
  String onboardingDiscoverListMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverListOwner(String handle) {
    return '@$handle의 리스트';
  }

  @override
  String onboardingDiscoverListHosts(String hosts) {
    return '서버: $hosts';
  }

  @override
  String get onboardingDiscoverListSeparator => ', ';

  @override
  String get onboardingDiscoverListOpenImport => '리스트를 열어 가져오기';

  @override
  String get onboardingDiscoverListSignup => '리스트에 있는 사람의 서버에 가입';

  @override
  String get onboardingDiscoverLoginButton => '로그인';

  @override
  String get onboardingDiscoverSignupButton => '가입하기';

  @override
  String get onboardingDiscoverSearchFailed => '검색하지 못했습니다. 잠시 후 다시 시도해 주세요';

  @override
  String get onboardingDiscoverGlimpseStoppedSystem =>
      '화면 읽기가 중지되었습니다(기기의 \'공유 중지\' 또는 화면 잠금). \'평소 브라우저로 보면서 찾기\'에서 다시 시작해 주세요';

  @override
  String get onboardingDiscoverGlimpseStoppedShort =>
      '방송이 너무 빨리 중지되어 읽지 못했습니다. 브라우저에서 찾고 싶은 화면을 연 다음 중지해 주세요';

  @override
  String get onboardingDiscoverGlimpseStoppedTimeout =>
      '10분이 지나 화면 읽기 준비를 중지했습니다';

  @override
  String get onboardingDiscoverGlimpseStoppedKilled =>
      '기기가 화면 읽기를 중지했습니다. 다시 시작해 주세요';

  @override
  String get onboardingDiscoverGlimpseStoppedEmpty =>
      '화면을 읽지 못했습니다(캡처를 가져오지 못함)';

  @override
  String get onboardingDiscoverGlimpseFailed => '화면을 읽지 못했습니다';

  @override
  String get onboardingDiscoverGlimpseBroadcastDenied =>
      '화면 방송이 시작되지 않았습니다. 읽으려면 다시 누르고 \'방송 시작\'을 선택하세요(방송을 중지하기 직전 3초만 읽습니다)';

  @override
  String get onboardingDiscoverGlimpseDenied =>
      '화면 읽기가 허용되지 않았습니다. 읽으려면 다시 누르고 \'시작\'을 선택하세요(버튼을 누른 뒤 3초만 읽습니다)';

  @override
  String get onboardingDiscoverGlimpseNotificationsDenied =>
      '알림을 표시하지 못했습니다. 읽기 버튼은 알림에 표시되므로 기기 설정에서 RASQ 알림을 허용해 주세요';

  @override
  String get onboardingDiscoverGlimpseUnavailable =>
      '이 기기에서는 화면을 읽을 수 없습니다. 이미지를 고르거나 앱 내 브라우저에서 찾아 주세요';

  @override
  String get onboardingDiscoverNotificationFailed =>
      '알림을 표시하지 못했습니다. 기기 설정에서 RASQ 알림을 허용해 주세요';

  @override
  String get onboardingDiscoverGlimpseResultMissing =>
      '읽은 화면을 찾을 수 없습니다(시간이 지나 사라졌거나 이미 보냈습니다)';

  @override
  String onboardingDiscoverPicksFull(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '이미지는 $max장까지입니다. 빼고 나서 추가해 주세요',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickFailed => '이미지를 불러오지 못했습니다';

  @override
  String onboardingDiscoverPicksOver(int over, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      over,
      locale: localeName,
      other: '이미지는 $max장까지입니다. $over장은 추가하지 않았습니다',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPicksUnreadable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '불러올 수 없는 이미지가 $count장 있었습니다',
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
      other: '보낼 수 있는 크기(1장 10 MiB, 합계 24 MiB, $max장까지)를 넘는 이미지 $count장을 뺐습니다',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverImageFormat => 'JPEG / PNG / WebP 이미지를 골라 주세요';

  @override
  String get onboardingDiscoverImageFormatSize =>
      '10 MiB 이하의 JPEG / PNG / WebP 이미지를 골라 주세요';

  @override
  String get onboardingDiscoverNoCentral => 'RASQ Central 접속 주소가 설정되지 않았습니다';

  @override
  String get onboardingDiscoverContentIntro =>
      '좋아하는 이미지를 고르고 찾고 싶은 부분을 둘러싸면 RAi가 검색어를 만듭니다. 이미지는 서버에 저장하지 않습니다(검색이 끝나면 버립니다).';

  @override
  String onboardingDiscoverPicksCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count / $max장. 탭하면 다시 둘러싸고, 길게 누르면 순서를 바꿉니다',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverPickImages => '이미지 고르기';

  @override
  String get onboardingDiscoverAddImages => '이미지 추가';

  @override
  String get onboardingDiscoverTakePhoto => '사진 찍기';

  @override
  String get onboardingDiscoverSearchOne => '이 이미지로 찾기';

  @override
  String onboardingDiscoverSearchMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이 $count장으로 찾기',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverOtherWays => '다른 방법';

  @override
  String get onboardingDiscoverGlimpseButton => '평소 브라우저로 보면서 찾기';

  @override
  String get onboardingDiscoverBrowseButton => '앱 내 브라우저에서 찾기';

  @override
  String get onboardingDiscoverGlimpseCancel => '그만두기';

  @override
  String onboardingDiscoverGlimpseCapturing(int elapsed, int total) {
    return '화면을 읽는 중($elapsed / $total초)';
  }

  @override
  String onboardingDiscoverGlimpseDone(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '화면을 $seconds초 읽었습니다($frames프레임)',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverGlimpseDoneDummy(int seconds, int frames) {
    String _temp0 = intl.Intl.pluralLogic(
      frames,
      locale: localeName,
      other: '화면을 $seconds초 읽었습니다($frames프레임). 지금은 시험판이라 더미 캡처입니다',
    );
    return '$_temp0';
  }

  @override
  String onboardingDiscoverPictureIndex(int index) {
    return '$index번째 이미지';
  }

  @override
  String onboardingDiscoverFrameIndex(int index) {
    return '$index번째 프레임';
  }

  @override
  String get onboardingDiscoverQueryHeading => '검색어';

  @override
  String get onboardingDiscoverNoResults => '맞는 리스트나 서버를 찾지 못했습니다';

  @override
  String get onboardingDiscoverPickWhole => '전체';

  @override
  String get onboardingDiscoverPickRect => '사각형';

  @override
  String get onboardingDiscoverPickLasso => '자유형';

  @override
  String get onboardingDiscoverPickRemove => '빼기';

  @override
  String get onboardingDiscoverGlimpseDummyNote =>
      '지금은 시험판이라 화면을 읽지 않고 더미 캡처를 보냅니다';

  @override
  String get onboardingDiscoverCaptureFailed => '이 화면을 읽지 못했습니다';

  @override
  String get onboardingDiscoverBrowseAddressHint => '검색할 말 / URL';

  @override
  String get onboardingDiscoverBrowseCapture => '이 화면으로 찾기';

  @override
  String get onboardingDiscoverManualIntro =>
      '이 기기에서는 앱 안에서 브라우저를 열 수 없습니다. 평소 브라우저로 본 다음, 페이지 URL과 관심 가는 문장을 붙여 넣어 주세요.';

  @override
  String get onboardingDiscoverManualOpenBrowser => '브라우저 열기';

  @override
  String get onboardingDiscoverManualUrl => '페이지 URL';

  @override
  String get onboardingDiscoverManualText => '관심 가는 문장(선택)';

  @override
  String get onboardingDiscoverManualSubmit => '이 내용으로 찾기';

  @override
  String get onboardingDiscoverPeopleIntro =>
      '좋아하는 사람의 이름이나 관심 있는 분야를 입력해 주세요. 먼저 공개된 RASQ 리스트에서 찾습니다.';

  @override
  String get onboardingDiscoverPeopleQueryLabel => '사람 이름 / 분야';

  @override
  String get onboardingDiscoverPeopleQueryHint => '예: 철도 사진, 일러스트레이터';

  @override
  String get onboardingDiscoverPeopleSearch => '찾기';

  @override
  String get onboardingDiscoverPeopleNotFound => 'RASQ 리스트에서 찾지 못했습니다';

  @override
  String get onboardingDiscoverPeopleNotFoundHint =>
      '좋아하는 이미지나 페이지로 찾거나 RAi에게 물어보세요.';

  @override
  String get onboardingDiscoverPeopleTryContent => '이미지나 콘텐츠로 찾기';

  @override
  String get onboardingDiscoverPeopleBrave => 'RASQ 리스트에 없어서 웹 검색으로 찾은 후보입니다';

  @override
  String get onboardingDiscoverPersonOpenProfile => '브라우저에서 프로필 열기';

  @override
  String get onboardingDiscoverPersonLists => '이 사람이 들어 있는 RASQ 리스트';

  @override
  String get onboardingDiscoverAskFailed => '답하지 못했습니다. 잠시 후 다시 물어봐 주세요';

  @override
  String get onboardingDiscoverAskEmptyTitle => '나에게 맞는 SNS, 함께 찾아요!';

  @override
  String get onboardingDiscoverAskEmptyBody =>
      '좋아하는 것, 보고 싶은 것, 어떤 사람과 연결되고 싶은지 알려 주세요. 맞을 것 같은 SNS 서버와 RASQ 리스트를 찾아 드립니다.';

  @override
  String get onboardingDiscoverAskEmptyCloud => '대화는 RASQ 서버의 RAi(클라우드)로 보냅니다.';

  @override
  String get onboardingDiscoverAskModelLabel => '클라우드 버전 RAi';

  @override
  String get onboardingDiscoverAskHint => '어떤 것을 좋아하세요?';

  @override
  String get onboardingDiscoverEditorTitle => '둘러싸서 검색';

  @override
  String onboardingDiscoverEditorTitleStep(String step) {
    return '둘러싸서 검색($step)';
  }

  @override
  String get onboardingDiscoverEditorHint =>
      '찾고 싶은 부분을 둘러싸 주세요. 둘러싸지 않고 확인하면 이미지 전체로 찾습니다. 두 손가락으로 확대하거나 이동할 수 있습니다.';

  @override
  String get onboardingDiscoverEditorHintSelected =>
      '둘러싼 부분만 잘라 내어 찾습니다. 다시 그리면 선택 영역이 바뀝니다.';

  @override
  String get onboardingDiscoverEditorToolRect => '사각형';

  @override
  String get onboardingDiscoverEditorToolLasso => '자유형';

  @override
  String get onboardingDiscoverEditorResetView => '원래 크기로';

  @override
  String get onboardingDiscoverEditorClear => '선택 영역 지우기';

  @override
  String get onboardingDiscoverEditorDoneWhole => '확인(이미지 전체)';

  @override
  String get onboardingDiscoverEditorDone => '확인';

  @override
  String get onboardingDiscoverGlimpseArmedBroadcast =>
      '화면 방송을 시작했습니다. 브라우저에서 찾고 싶은 화면을 연 다음, 화면 위쪽의 빨간 표시(또는 제어 센터)에서 방송을 중지해 주세요. 중지하기 직전 3초만 읽으며, RASQ로 돌아오면 결과가 나옵니다.';

  @override
  String get onboardingDiscoverGlimpseArmedNotification =>
      '알림을 표시했습니다. 브라우저에서 찾고 싶은 화면을 연 다음 알림을 탭해 주세요. 탭하면 그 화면을 3초만 읽습니다.';

  @override
  String get onboardingDiscoverGlimpseNotificationTitle => 'RASQ로 찾기';

  @override
  String get onboardingDiscoverGlimpseNotificationBody =>
      '탭하면 지금 보고 있는 화면을 3초만 읽습니다';

  @override
  String get onboardingDiscoverApiImageFormat =>
      'jpeg / png / webp 이미지만 보낼 수 있습니다';

  @override
  String get onboardingDiscoverApiImageSize => '이미지는 10 MiB까지입니다';

  @override
  String get onboardingDiscoverApiImageAndFrames => '이미지와 프레임은 함께 보낼 수 없습니다';

  @override
  String onboardingDiscoverApiFramesCount(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '프레임은 $max장까지입니다',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDiscoverApiFrameFormat =>
      'jpeg / png / webp 프레임만 보낼 수 있습니다';

  @override
  String get onboardingDiscoverApiFrameSize => '프레임은 1장에 10 MiB까지입니다';

  @override
  String get onboardingDiscoverApiFramesTotal => '프레임은 합계 24 MiB까지입니다';

  @override
  String get onboardingDiscoverApiEmpty => '이미지, 본문, URL 중 하나가 필요합니다';

  @override
  String get onboardingTourPageSnsTitle => '여러 SNS를 한곳에서';

  @override
  String get onboardingTourPageSnsBody =>
      'Misskey·Mastodon·Bluesky 등의 계정을 한꺼번에 사용할 수 있습니다. RASQ 계정이 있으면 설정과 계정 묶음을 다른 기기에서도 사용할 수 있습니다.';

  @override
  String get onboardingTourPageSnsPicture =>
      'Bluesky·Misskey·mixi2·Mastodon이 RASQ로 모이는 그림';

  @override
  String get onboardingTourPageTimelineTitle => '타임라인은 노드로 조립합니다';

  @override
  String get onboardingTourPageTimelineBody =>
      '홈 TL은 노드를 배치해 원하는 대로 조립할 수 있습니다. 트렌드와 Today도 노드로 TL에 둘 수 있습니다.';

  @override
  String get onboardingTourPageTimelineNote => 'TL의 톱니바퀴에서 바꿀 수 있습니다.';

  @override
  String get onboardingTourPageTimelinePicture =>
      '\'SNS 타임라인\', \'트렌드 가져오기\', \'Today\' 노드가 세로로 늘어선 그림';

  @override
  String get onboardingTourPageTrendTitle => '트렌드와 Today';

  @override
  String get onboardingTourPageTrendBody =>
      '지금 화제인 단어와 게시물을 트렌드와 Today에서 볼 수 있습니다. 처음에는 두려움·혐오·분노를 45%까지로 억제하므로, 강한 분노나 혐오가 담긴 게시물은 추천 / 트렌드 / Today / 관련 TL에서 순위가 내려가거나 표시되지 않습니다.';

  @override
  String get onboardingTourPageTrendNoteSupervised =>
      '이 상한은 언제든지 바꿀 수 있습니다. 보호 중에는 보호자의 설정으로 더 억제합니다.';

  @override
  String get onboardingTourPageTrendNote => '이 상한은 언제든지 바꿀 수 있습니다.';

  @override
  String get onboardingTourPageTrendPicture => '자극성 레이더';

  @override
  String get onboardingTourPageAstellTitle => 'ASTell로 목소리로 연결되기';

  @override
  String get onboardingTourPageAstellBody =>
      'ASTell은 목소리로 대화할 수 있는 룸입니다. 듣기만 하는 참여도 가능하며, 아래의 ASTell 탭에서 들어갈 수 있습니다.';

  @override
  String get onboardingTourPageAstellPicture => 'ASTell 안테나와 말하는 중임을 나타내는 파형';

  @override
  String get onboardingTourPageSwingTitle => 'Swing으로 가볍게 흘려보내기';

  @override
  String get onboardingTourPageSwingBody =>
      'Swing은 시간이 지나면 사라지는 게시물입니다. 팔로워와 RASQ 리스트의 사람에게 전달되며, 1~24시간 후에 사라집니다.';

  @override
  String get onboardingTourPageSwingNote => 'RASQ 계정으로 사용할 수 있습니다.';

  @override
  String get onboardingTourPageSwingPicture => 'Swing의 동그란 아이콘이 늘어선 그림';

  @override
  String get onboardingTourPageRaiTitle => '헷갈리면 RAi에게';

  @override
  String get onboardingTourPageRaiBody =>
      'RAi는 RASQ의 어시스턴트입니다. 하고 싶은 일을 물어보면 버튼 위치까지 안내하거나 대신 조작해 줍니다.';

  @override
  String get onboardingTourPageRaiPicture => 'RAi와 말풍선';

  @override
  String get onboardingTourPagePluginsTitle => '플러그인으로 넓히기';

  @override
  String get onboardingTourPagePluginsBody =>
      'SNS도, 표시도, 기능도 플러그인으로 추가할 수 있습니다. 플러그인 스토어에서 찾아 설치할 수 있습니다.';

  @override
  String get onboardingTourPagePluginsPicture => '플러그인 타일이 늘어선 그림';

  @override
  String get onboardingTourTitle => 'RASQ 사용법';

  @override
  String get onboardingTourSkip => '건너뛰기';

  @override
  String get onboardingTourBack => '뒤로';

  @override
  String onboardingTourPageSemantics(int number, int total) {
    return '$number / $total 페이지';
  }

  @override
  String get onboardingTourStart => '시작하기';

  @override
  String get onboardingTourNext => '다음';

  @override
  String get onboardingTourOpenTendency => '지금 설정 보기';

  @override
  String get onboardingTourNodeSnsTimeline => 'SNS 타임라인';

  @override
  String get onboardingTourNodeTrend => '트렌드 가져오기';

  @override
  String get onboardingTourRaiBubble => 'TL에 리스트를 추가하고 싶어';

  @override
  String get platformWebRuntimeLoadFailed =>
      '실행에 필요한 파일을 불러오지 못했습니다 (네트워크 / CDN)';

  @override
  String get platformWebServerNotConfigured => 'RASQ 서버 연결 주소가 설정되지 않았습니다';

  @override
  String platformWebDownloadFailed(String error) {
    return '다운로드에 실패했습니다: $error';
  }

  @override
  String platformWebModelLoadFailed(String error) {
    return '모델을 불러올 수 없습니다: $error';
  }

  @override
  String get pluginsCancel => '취소';

  @override
  String get pluginsClose => '닫기';

  @override
  String get pluginsSwingNotPackage => 'Swing 플러그인은 .rasqpkg 또는 .wasm입니다';

  @override
  String get pluginsSwingNoRequires =>
      '다른 플러그인을 기반으로 하는 하위 플러그인은 Swing으로 배포할 수 없습니다';

  @override
  String get pluginsSwingSingleOnly =>
      'Swing으로 배포할 수 있는 것은 플러그인이 하나만 든 패키지뿐입니다';

  @override
  String get pluginsPageNotPage => '페이지형 플러그인이 아닙니다';

  @override
  String pluginsPageSwingRequires(String ids) {
    return '다른 플러그인($ids)을 기반으로 하므로 Swing으로 배포할 수 없습니다';
  }

  @override
  String get pluginsPageSwingChild =>
      '다른 플러그인 패키지에 든 하위 플러그인이므로 Swing으로 배포할 수 없습니다';

  @override
  String pluginsPageSwingSiblings(String names) {
    return '하위 플러그인($names)과 같은 패키지이므로 Swing으로 배포할 수 없습니다';
  }

  @override
  String pluginsArtifactMismatch(String pluginId) {
    return '$pluginId: 다시 받은 배포물이 설치 때와 달라 불러오지 않습니다(스토어에서 다시 설치하세요)';
  }

  @override
  String pluginsIsSnsPlugin(String id) {
    return '$id은(는) SNS 플러그인입니다(슬롯에 등록할 수 없습니다)';
  }

  @override
  String get pluginsManifestMissing => 'plugin.manifest가 없습니다';

  @override
  String get pluginsManifestIdEmpty => 'plugin.manifest.id가 비어 있습니다';

  @override
  String get pluginsSwingSurfaceOnly =>
      'Swing으로 배포할 수 있는 것은 Swing 화면(surfaces: swing, solo)용 페이지형뿐입니다';

  @override
  String get pluginsRasqPageSurfaceOnly =>
      'RASQ 페이지에 둘 수 있는 것은 프로필 화면(surfaces: profile, solo)용 페이지형뿐입니다';

  @override
  String pluginsIdMismatch(String expected, String actual) {
    return '배포물의 목차는 $expected인데 wasm은 $actual(이)라고 밝히고 있습니다';
  }

  @override
  String pluginsRegistered(String name, String slots) {
    return '$name을(를) 등록했습니다($slots)';
  }

  @override
  String pluginsRegisterFailed(String error) {
    return '등록하지 못했습니다: $error';
  }

  @override
  String pluginsImageReceiveFailed(String name, String error) {
    return '$name: 이미지를 받지 못했습니다($error)';
  }

  @override
  String pluginsSharedNoSession(String name) {
    return '$name: 공유 세션에 참여하지 않아 모두의 값을 바꿀 수 없습니다';
  }

  @override
  String get pluginsMuteAddTitle => '뮤트 단어에 추가';

  @override
  String pluginsMuteAddMessage(String name, String word) {
    return '$name이(가) \'$word\'을(를) 뮤트 단어에 추가하려고 합니다.';
  }

  @override
  String get pluginsMuteAddConfirm => '추가';

  @override
  String pluginsMuteAdded(String word) {
    return '\'$word\'을(를) 뮤트 단어에 추가했습니다';
  }

  @override
  String pluginsEffectSendFailed(String name, String error) {
    return '$name: 효과 영상을 보내지 못했습니다($error)';
  }

  @override
  String pluginsImageScaled(String name) {
    return '$name: 편집을 위해 이미지를 축소했습니다';
  }

  @override
  String get pluginsErrorReturned => '플러그인이 오류를 반환했습니다';

  @override
  String get pluginsGenreTone => '색조';

  @override
  String get pluginsGenreProcess => '가공';

  @override
  String get pluginsGenreTransform => '변형';

  @override
  String get pluginsGenreAdd => '추가';

  @override
  String get pluginsGenreDraw => '그리기';

  @override
  String get pluginsTrustFull => '전체';

  @override
  String get pluginsTrustBundled => '전체(내장)';

  @override
  String get pluginsTrustRestricted => '제한';

  @override
  String get pluginsTrustSwing => '제한(Swing)';

  @override
  String get pluginsTrustHint =>
      '자신의 개발자 키로 서명한 .rspkg / .rasqpkg는 전체 기능을 사용합니다. rasq build가 서명합니다';

  @override
  String get pluginsEditorCancel => '취소';

  @override
  String get pluginsEditorUndo => '실행 취소';

  @override
  String get pluginsEditorRedo => '다시 실행';

  @override
  String get pluginsEditorDone => '완료';

  @override
  String get pluginsEditorRemove => '삭제';

  @override
  String get pluginsEditorBack => '뒤로';

  @override
  String get pluginsEditorMore => '더 보기';

  @override
  String get pluginsEditorApplying => '변경 사항을 적용하는 중';

  @override
  String get pluginsEditorPreparing => '편집기를 준비하는 중';

  @override
  String get pluginsEditorPleaseWait => '잠시 기다려 주세요…';

  @override
  String get pluginsEditorCloseWarningTitle => '편집을 그만둘까요?';

  @override
  String get pluginsEditorCloseWarningMessage => '변경 사항은 저장되지 않습니다.';

  @override
  String get pluginsEditorCloseWarningConfirm => '그만두기';

  @override
  String get pluginsEditorCloseWarningCancel => '계속';

  @override
  String get pluginsEditorLayerEdit => '편집';

  @override
  String get pluginsEditorLayerRotateScale => '회전 및 크기 조절';

  @override
  String get pluginsEditorPaint => '페인트';

  @override
  String get pluginsEditorZoom => '확대/축소';

  @override
  String get pluginsEditorFreehand => '자유 곡선';

  @override
  String get pluginsEditorArrow => '화살표';

  @override
  String get pluginsEditorLine => '직선';

  @override
  String get pluginsEditorRectangle => '사각형';

  @override
  String get pluginsEditorCircle => '원';

  @override
  String get pluginsEditorDashLine => '점선';

  @override
  String get pluginsEditorBlur => '흐리게';

  @override
  String get pluginsEditorPixelate => '모자이크';

  @override
  String get pluginsEditorLineWidth => '선 굵기';

  @override
  String get pluginsEditorEraser => '지우개';

  @override
  String get pluginsEditorFill => '채우기';

  @override
  String get pluginsEditorOpacity => '불투명도';

  @override
  String get pluginsEditorColor => '색상';

  @override
  String get pluginsEditorTextHint => '텍스트 입력';

  @override
  String get pluginsEditorText => '텍스트';

  @override
  String get pluginsEditorTextAlign => '정렬';

  @override
  String get pluginsEditorFontScale => '글자 크기';

  @override
  String get pluginsEditorTextBackground => '배경';

  @override
  String get pluginsEditorCropRotate => '자르기 / 회전';

  @override
  String get pluginsEditorRotate => '회전';

  @override
  String get pluginsEditorFlip => '반전';

  @override
  String get pluginsEditorTilt => '기울기';

  @override
  String get pluginsEditorTiltHorizontal => '수평';

  @override
  String get pluginsEditorTiltVertical => '수직';

  @override
  String get pluginsEditorRatio => '비율';

  @override
  String get pluginsEditorReset => '초기화';

  @override
  String get pluginsEditorTune => '조정';

  @override
  String get pluginsEditorBrightness => '밝기';

  @override
  String get pluginsEditorContrast => '대비';

  @override
  String get pluginsEditorSaturation => '채도';

  @override
  String get pluginsEditorExposure => '노출';

  @override
  String get pluginsEditorHue => '색조';

  @override
  String get pluginsEditorTemperature => '색온도';

  @override
  String get pluginsEditorFade => '페이드';

  @override
  String get pluginsEditorTint => '틴트';

  @override
  String get pluginsEditorFilter => '필터';

  @override
  String get pluginsEditorSticker => '스티커';

  @override
  String get pluginsEditorEmoji => '이모지';

  @override
  String get pluginsEditorEmojiSearch => '검색';

  @override
  String get pluginsEditorEmojiRecent => '최근';

  @override
  String get pluginsEditorEmojiSmileys => '얼굴 및 사람';

  @override
  String get pluginsEditorEmojiAnimals => '동물 및 자연';

  @override
  String get pluginsEditorEmojiFood => '음식';

  @override
  String get pluginsEditorEmojiActivities => '활동';

  @override
  String get pluginsEditorEmojiTravel => '여행 및 장소';

  @override
  String get pluginsEditorEmojiObjects => '사물';

  @override
  String get pluginsEditorEmojiSymbols => '기호';

  @override
  String get pluginsEditorEmojiFlags => '깃발';

  @override
  String get pluginsMediaCancel => '취소';

  @override
  String get pluginsMediaClose => '닫기';

  @override
  String get pluginsMediaApply => '적용';

  @override
  String pluginsMediaNotSvg(String name) {
    return '$name이(가) SVG를 반환하지 않아 사용하지 않았습니다';
  }

  @override
  String get pluginsMediaPaperDoneMissing =>
      '지금은 사용할 수 없습니다(종이의 \'완료\'를 찾을 수 없음)';

  @override
  String get pluginsMediaBarEdit => '바 편집';

  @override
  String get pluginsMediaAudioUnsupported =>
      '이 기기에서는 오디오를 동영상으로 만들 수 없습니다(Android / iOS / macOS만). 오디오 그대로 첨부할 수 있습니다';

  @override
  String pluginsMediaOpenAudioFailed(String error) {
    return '오디오를 열지 못했습니다: $error';
  }

  @override
  String pluginsMediaOpenVideoFailed(String error) {
    return '동영상을 열지 못했습니다: $error';
  }

  @override
  String pluginsMediaReexportFailed(String error) {
    return '동영상을 다시 내보내지 못했습니다: $error';
  }

  @override
  String get pluginsMediaCropWithMovingObject =>
      '자르기 / 회전과 움직이는 오브젝트는 함께 사용할 수 없습니다. 정지 이미지로 넣었습니다';

  @override
  String pluginsMediaExportFailed(String error) {
    return '동영상을 내보내지 못했습니다: $error';
  }

  @override
  String pluginsMediaOverlayFailed(String error) {
    return '움직이는 오브젝트를 겹치지 못해 정지 이미지로 넣었습니다: $error';
  }

  @override
  String pluginsMediaFilterNotReceived(String label) {
    return '$label: 필터를 받지 못했습니다';
  }

  @override
  String pluginsMediaFilterDropped(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$label: 그리기가 너무 많아 $_temp0를 생략했습니다';
  }

  @override
  String pluginsMediaFiltersFailed(String names) {
    return '적용하지 못한 필터: $names(이 편집은 들어가지 않았습니다)';
  }

  @override
  String get pluginsMediaCropWithMovingPost =>
      '자르기 / 회전과 움직이는 게시물은 함께 사용할 수 없습니다. 게시물은 정지 이미지로 넣었습니다';

  @override
  String get pluginsMediaVideoImageUnreadable =>
      '동영상으로 만들지 못해 정지 이미지로 넣었습니다(이미지를 읽지 못함)';

  @override
  String pluginsMediaVideoPostFailed(String error) {
    return '동영상으로 만들지 못해 게시물은 정지 이미지로 넣었습니다: $error';
  }

  @override
  String get pluginsMediaToVideoTitle => '동영상으로 변환할까요?';

  @override
  String pluginsMediaToVideoMessage(String note) {
    return '$note\n\'동영상으로 만들기\'를 선택하면 놓은 위치에서 움직이는 동영상으로 내보냅니다. \'정지 이미지로 붙이기\'는 현재 이미지만 붙입니다.';
  }

  @override
  String get pluginsMediaToVideoConfirm => '동영상으로 만들기';

  @override
  String get pluginsMediaToVideoStill => '정지 이미지로 붙이기';

  @override
  String get pluginsMediaImageUnreadable => '이미지를 읽지 못했습니다';

  @override
  String get pluginsMediaExportOnDone => '완료하면 동영상으로 내보냅니다';

  @override
  String get pluginsMediaObjectNote => '노트';

  @override
  String get pluginsMediaObjectVideo => '동영상';

  @override
  String get pluginsMediaObjectImage => '이미지';

  @override
  String get pluginsMediaAddImage => '이미지 추가';

  @override
  String get pluginsMediaAddVideo => '동영상 추가';

  @override
  String get pluginsMediaVideoLoadFailed => '동영상을 불러오지 못했습니다';

  @override
  String pluginsMediaVideoLoadFailedDetail(
    String ext,
    int bytes,
    String error,
  ) {
    return '동영상(.$ext, $bytes바이트)의 첫 프레임을 가져오지 못했습니다: $error';
  }

  @override
  String get pluginsMediaFirstFrameFailed => '동영상의 첫 프레임을 가져오지 못했습니다';

  @override
  String get pluginsMediaVideoAsObject => '동영상을 오브젝트로 놓습니다.';

  @override
  String pluginsMediaAddFailed(String error) {
    return '미디어를 추가하지 못했습니다: $error';
  }

  @override
  String get pluginsMediaAudioConverting => '오디오를 동영상으로 변환하는 중…';

  @override
  String pluginsMediaPanelNotEditable(String name) {
    return '$name은(는) 여기서 편집할 수 없습니다(플러그인 패널에서 조작하세요)';
  }

  @override
  String get pluginsMediaSnapDragUnset => '이 위로 드래그(해제)';

  @override
  String get pluginsMediaSnapDragSet => '이 위로 드래그(맞출 대상으로 설정)';

  @override
  String get pluginsMediaSnapPick => '맞출 대상 선택…';

  @override
  String get pluginsMediaSnapClearAll => '맞출 대상 모두 해제';

  @override
  String get pluginsMediaSnapTitle => '맞출 대상';

  @override
  String get pluginsMediaSnapEmpty => '이름이 붙은 틀이 없습니다';

  @override
  String pluginsMediaSnapSize(int width, int height) {
    return '$width × $height';
  }

  @override
  String pluginsMediaSnapSizeAngle(int width, int height, int angle) {
    return '$width × $height, $angle°';
  }

  @override
  String get pluginsMediaPanelNoResult => '적용하지 못했습니다(플러그인이 결과를 반환하지 않음)';

  @override
  String get pluginsMediaPanelNoEdits => '이 플러그인에는 편집 항목이 없습니다';

  @override
  String pluginsMediaObjectEditSemantics(String title) {
    return '$title 편집';
  }

  @override
  String get pluginsMediaObjectLoop => '반복 재생';

  @override
  String get pluginsMediaObjectLoopSubtitle => '끄기 = 끝나면 마지막 프레임에서 멈춤';

  @override
  String get pluginsMediaObjectSpeed => '재생 속도';

  @override
  String get pluginsMediaObjectVolume => '소리';

  @override
  String get pluginsMediaObjectMuted => '음소거';

  @override
  String get pluginsMediaObjectOpacity => '불투명도';

  @override
  String get pluginsMediaObjectRemove => '이 오브젝트 삭제';

  @override
  String pluginsMediaFilterAdjustSemantics(String title) {
    return '$title 조정';
  }

  @override
  String get pluginsMediaFilterObjectHint =>
      '그림 위에서 드래그로 이동하고, 핀치로 크기 조절 / 회전할 수 있습니다.';

  @override
  String get pluginsMediaFilterRemove => '이 필터 빼기';

  @override
  String get pluginsMediaStickerEmpty => '스티커가 없습니다. 스토어에서 설치하면 여기에 표시됩니다';

  @override
  String get pluginsMediaStickerEmptyDetail =>
      '스티커가 없습니다. 스토어에서 에셋 팩(카테고리 \'assets\')을 설치하면 여기에 표시됩니다.';

  @override
  String get pluginsMediaStickerGenerate => '플러그인으로 만들기';

  @override
  String get pluginsPaintTitle => '낙서';

  @override
  String get pluginsPaintCancel => '취소';

  @override
  String get pluginsPaintDone => '완료';

  @override
  String get pluginsPaintCanvasSemantics => '낙서 캔버스';

  @override
  String get pluginsPaintFillLeak => '선으로 닫힌 도형 안을 탭하세요';

  @override
  String get pluginsPaintFillOnLine => '선 안쪽을 탭하세요';

  @override
  String get pluginsPaintFillEmpty => '칠할 수 있는 도형이 없습니다';

  @override
  String get pluginsPaintToolPen => '펜';

  @override
  String get pluginsPaintToolEraser => '지우개';

  @override
  String get pluginsPaintToolLasso => '올가미';

  @override
  String get pluginsPaintToolFill => '채우기';

  @override
  String get pluginsPaintUndo => '실행 취소';

  @override
  String get pluginsPaintRedo => '다시 실행';

  @override
  String get pluginsPaintClear => '모두 지우기';

  @override
  String get pluginsPaintStabilizer => '손떨림 보정';

  @override
  String get pluginsPaintStabilizerOff => '끔';

  @override
  String get pluginsPaintEraserCut => '자르기';

  @override
  String get pluginsPaintEraserWhole => '선 전체';

  @override
  String get pluginsPaintLassoHint => '둘러싸서 선택(선의 절반 이상이 들어간 것)';

  @override
  String get pluginsPaintSelectionDelete => '삭제';

  @override
  String get pluginsPaintSelectionDuplicate => '복제';

  @override
  String get pluginsPaintSelectionRecolor => '색 바꾸기';

  @override
  String get pluginsPaintSelectionDeselect => '선택 해제';

  @override
  String get pluginsPaintFillHint => '선으로 닫힌 도형 안을 탭하면 선 아래에 칠합니다';

  @override
  String pluginsPaintWidthSemantics(String width) {
    return '굵기 $width';
  }

  @override
  String pluginsPaintColorSemantics(String color) {
    return '색 $color';
  }

  @override
  String get pluginsPaintNibMili => '밀리펜';

  @override
  String get pluginsPaintNibKabura => '카부라펜';

  @override
  String get pluginsPaintNibBrush => '브러시 닙';

  @override
  String get postThreadSortRelevance => '관련순';

  @override
  String get postThreadSortReactions => '리액션 수';

  @override
  String get postThreadSortKeyword => '키워드순';

  @override
  String get postThreadSortDefault => '기본';

  @override
  String get postThreadModeRenotes => '인용(리노트)';

  @override
  String get postThreadModeRenotesShort => '인용';

  @override
  String get postThreadModeReplies => '답글';

  @override
  String get postThreadModeRepliesShort => '답글';

  @override
  String get postThreadModeReactions => '리액션';

  @override
  String get postThreadModeReactionsShort => '리액션';

  @override
  String get postThreadModeQuotes => '공유(인용 노트)';

  @override
  String get postThreadModeQuotesShort => '공유';

  @override
  String get postBookmarkClipTooltip => '클립에 추가(길게 누르기)';

  @override
  String get postBookmarkRemoveTooltip => '북마크 해제(길게 눌러 클립에 추가)';

  @override
  String get postBookmarkAddTooltip => '북마크(길게 눌러 클립에 추가)';

  @override
  String get postBookmarkUnsupported =>
      '이 서비스에는 북마크가 없습니다. 길게 눌러 클립에 추가할 수 있습니다';

  @override
  String get postBookmarkRemoved => '북마크를 해제했습니다';

  @override
  String get postBookmarkAdded => '북마크했습니다';

  @override
  String postBookmarkError(String error) {
    return '북마크할 수 없습니다: $error';
  }

  @override
  String get postReactionsTitle => '리액션';

  @override
  String get postReactionsTabReplies => '답글';

  @override
  String get postReactionsTabQuotes => '인용';

  @override
  String get postReactionsTabReactions => '리액션';

  @override
  String get postReactionsTabShares => '공유';

  @override
  String get postReactionsBookmarkTooltip => '북마크';

  @override
  String get postRepliesEmpty => '답글이 없습니다';

  @override
  String get postQuotesEmpty => '인용 노트가 없습니다';

  @override
  String get postRepostersEmpty => '리노트/인용이 없습니다';

  @override
  String get postReactionsEmpty => '리액션이 없습니다';

  @override
  String get postReactionsMine => '나';

  @override
  String postDetailNotFoundOnAccount(String account) {
    return '$account에서는 이 게시물을 찾을 수 없습니다';
  }

  @override
  String get postDetailTitle => '게시물';

  @override
  String get postDetailOpenedAccount => '열었던 계정';

  @override
  String get postDetailNotFound => '게시물이 없습니다';

  @override
  String get postReload => '다시 불러오기';

  @override
  String get postDetailShowReactions => '리액션 보기';

  @override
  String get postDetailShowMore => '더 보기';

  @override
  String get postRenotesEmpty => '리노트가 없습니다';

  @override
  String get postShareAccountTooltip => '공유에 사용할 계정';

  @override
  String get postShareAccountFixedTooltip => '받은 계정으로만 공유할 수 있습니다';

  @override
  String get postShareSemantics => '공유';

  @override
  String get postShareContentCopied => '내용을 복사했습니다';

  @override
  String get postShareLinkCopied => '링크를 복사했습니다';

  @override
  String get postShareDmTitle => 'DM으로 공유';

  @override
  String get postShareClose => '닫기';

  @override
  String get postShareDmNoRooms => 'DM 상대가 없습니다';

  @override
  String postShareAstellShared(String room) {
    return '\'$room\'에 공유했습니다';
  }

  @override
  String get postShareCopyContent => '내용 복사';

  @override
  String get postShareCopyLink => '링크 복사';

  @override
  String get postShareOtherAccount => '다른 계정으로 공유';

  @override
  String get postSharePluginsHeader => '플러그인에 공유';

  @override
  String get postShareAstellTitle => 'ASTell에 공유';

  @override
  String postShareAstellSubtitle(String room) {
    return '참여 중인 룸 \'$room\'에 게시물을 보냅니다';
  }

  @override
  String get postSharePluginsEmpty => '공유를 지원하는 플러그인이 여기에 표시됩니다';

  @override
  String get postSharePluginsEmptyDetail =>
      'post.share를 선언한 플러그인(과 참여 중인 ASTell)이 여기에 표시됩니다';

  @override
  String get postShareOtherHeader => '기타';

  @override
  String get postShareDmSubtitle => '선택한 계정의 DM으로 링크를 보냅니다';

  @override
  String get postShareOpenBrowser => '브라우저에서 열기';

  @override
  String get postMenuCopyLink => '링크 복사';

  @override
  String get postMenuUnpin => '고정 해제';

  @override
  String get postMenuPin => '고정';

  @override
  String get postMenuDetail => '상세';

  @override
  String get postMenuShare => '공유';

  @override
  String get postMenuEditActionBar => '액션 바 편집';

  @override
  String get postMenuUnfavorite => '즐겨찾기 해제';

  @override
  String get postMenuFavorite => '즐겨찾기';

  @override
  String get postMenuAddToClip => '클립에 추가';

  @override
  String get postMenuUnfollow => '팔로우 해제';

  @override
  String get postMenuFollow => '팔로우';

  @override
  String get postMenuUnmute => '뮤트 해제';

  @override
  String get postMenuMute => '뮤트';

  @override
  String get postMenuUnblock => '차단 해제';

  @override
  String get postMenuBlock => '차단';

  @override
  String get postMenuReport => '신고';

  @override
  String get postMenuDelete => '삭제';

  @override
  String postBlockConfirmTitle(String name) {
    return '$name님을 차단할까요?';
  }

  @override
  String get postCancel => '취소';

  @override
  String get postReportConfirmTitle => '이 게시물을 신고할까요?';

  @override
  String get postReportConfirmMessage => '서버 관리자에게 신고합니다.';

  @override
  String get postDeleteConfirmTitle => '게시물을 삭제할까요?';

  @override
  String get postDeleteConfirmMessage => '이 작업은 되돌릴 수 없습니다.';

  @override
  String postSaveMediaLabel(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '동영상 저장',
      'other': '이미지 저장',
    });
    return '$_temp0';
  }

  @override
  String postSaveDestinationTitle(String kind) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '동영상 저장 위치',
      'other': '이미지 저장 위치',
    });
    return '$_temp0';
  }

  @override
  String get postSaveToPhotosSubtitle => '앨범 \'RASQ\'에 저장됩니다';

  @override
  String get postSaveToFilesIosSubtitle =>
      '\'파일\' 앱의 나의 iPad(나의 iPhone) › RASQ › 保存';

  @override
  String get postSaveToFilesSubtitle => '저장할 위치를 선택합니다';

  @override
  String get postSaveRememberTitle => '다음에도 이 저장 위치 사용';

  @override
  String get postSaveRememberSubtitle =>
      '설정 → 앱 외관 → \'이미지·동영상 저장 위치\'에서 바꿀 수 있습니다';

  @override
  String postSaveFailed(String kind, String error) {
    String _temp0 = intl.Intl.selectLogic(kind, {
      'video': '동영상을 저장할 수 없습니다: $error',
      'other': '이미지를 저장할 수 없습니다: $error',
    });
    return '$_temp0';
  }

  @override
  String get profileEditTitle => '프로필 업데이트';

  @override
  String get profileEditSave => '확인';

  @override
  String get profileEditNotLoggedIn => 'RASQ 계정에 로그인하지 않았습니다.';

  @override
  String get profileEditBannerRemove => '배너 제거';

  @override
  String get profileEditBannerPick => '배너 선택';

  @override
  String get profileEditAvatarPick => '아이콘 선택';

  @override
  String get profileEditAvatarRemove => '아이콘 제거';

  @override
  String get profileEditPickImage => '이미지 선택';

  @override
  String get profileEditNameHint => '이름 입력…';

  @override
  String get profileEditBirthdayHint => '생일 (YYYY-MM-DD / MM-DD)';

  @override
  String get profileEditBirthdayHintSns => '생일 (YYYY-MM-DD)';

  @override
  String get profileEditHandleLabel => '핸들 (@ 없이, a-z 0-9 _, 3~32자)';

  @override
  String get profileEditBioLabel => '자기소개';

  @override
  String get profileEditBioHint => '자기소개 (500자까지)';

  @override
  String get profileEditLocationLabel => '위치';

  @override
  String get profileEditLinksLabel => '링크';

  @override
  String get profileEditLinkRemove => '삭제';

  @override
  String get profileEditLinkCaptionHint => '캡션';

  @override
  String get profileEditLinkAdd => '추가';

  @override
  String get profileEditReload => '다시 불러오기';

  @override
  String get profileEditSnsTilesLabel => '계정 페이지에 표시할 SNS 계정';

  @override
  String get profileEditSnsTilesCaption =>
      '\'자동\'에서는 비공개 계정 등은 표시하지 않습니다. 흐린 타일은 현재 표시되지 않는 것입니다.';

  @override
  String get profileEditSnsTilesCaptionDetail =>
      '\'자동\'은 비공개 계정과, 최근 게시물의 공개 범위가 팔로워 전용에 치우친 계정을 표시하지 않습니다. 흐린 타일은 현재 표시되지 않는 것입니다. 변경은 바로 반영됩니다.';

  @override
  String profileEditSnsTileAuto(String state) {
    return '자동 ($state)';
  }

  @override
  String get profileEditSnsTileShown => '표시';

  @override
  String get profileEditSnsTileHidden => '숨김';

  @override
  String profileEditVerified(String method) {
    return '소유자 확인 완료 ($method)';
  }

  @override
  String get profileEditVerify => '소유자 확인';

  @override
  String get profileEditShowOnSnsLabel => 'SNS 프로필';

  @override
  String get profileEditShowOnSnsTitle => 'SNS 프로필에도 연결한 계정 표시';

  @override
  String get profileEditShowOnSnsSubtitle =>
      'RASQ에서 누군가 내 SNS 프로필을 볼 때 연결한 계정을 표시합니다.';

  @override
  String get profileEditShowOnSnsDetail =>
      '앱에서 누군가 내 SNS 프로필을 볼 때 이 RASQ 계정과 계정 페이지에 표시 중인 다른 계정을 표시합니다. 자기소개에 적혀 있는 것은 중복해서 표시하지 않습니다. 변경은 바로 반영됩니다.';

  @override
  String get profileEditKeybaseConnect => 'Keybase 연결';

  @override
  String get profileEditKeybaseConnectSubtitle =>
      'Keybase로 본인 확인을 하고 계정 페이지에 표시합니다';

  @override
  String get profileEditKeybaseLinkedSubtitle => '확인 완료. 계정 페이지에 표시됩니다';

  @override
  String get profileEditNotice =>
      '프로필은 공개 페이지와 스토어 리뷰에 표시됩니다. 이메일과 비밀번호는 \'보안\'에서.';

  @override
  String get profileEditNoticeDetail =>
      '프로필은 RASQ 공개 페이지와 스토어 리뷰에 표시됩니다. 이미지는 서버에서 축소해 다시 저장합니다(위치 정보 등은 남지 않습니다). 이메일 주소와 비밀번호는 \'보안\'에서.';

  @override
  String get profileEditErrorHandleTaken => '그 핸들은 이미 사용 중입니다';

  @override
  String get profileEditErrorHandle => '핸들은 a-z 0-9 _로 된 3~32자로 해 주세요';

  @override
  String get profileEditErrorBirthday => '생일은 YYYY-MM-DD 또는 MM-DD 형식으로 입력해 주세요';

  @override
  String get profileEditErrorLink =>
      '링크는 캡션(40자까지)과 http(s) URL의 쌍으로 해 주세요(8쌍까지)';

  @override
  String get profileEditErrorImage =>
      '그 이미지는 사용할 수 없습니다 (PNG / JPEG / WebP / GIF, 8 MiB까지)';

  @override
  String get profileEditErrorBio => '자기소개는 500자까지입니다';

  @override
  String get profileEditErrorLocation => '위치는 60자까지입니다';

  @override
  String profileEditErrorFailed(String message) {
    return '업데이트에 실패했습니다: $message';
  }

  @override
  String get profileEditSnsPostsWithdrawn => '맡긴 키와 가져온 게시물을 삭제했습니다';

  @override
  String profileEditSnsPostsWithdrawFailed(String message) {
    return '삭제하지 못했습니다: $message';
  }

  @override
  String get profileEditSnsPostsNoLogin => '이 기기에 그 계정의 로그인이 없습니다';

  @override
  String get profileEditSnsPostsNoDid => '이 계정의 DID를 알 수 없습니다. 다시 로그인해 주세요';

  @override
  String get profileEditSnsPostsBlueskyConsentTitle =>
      'Bluesky 게시물을 계정 페이지에 표시합니다';

  @override
  String profileEditSnsPostsBlueskyConsentMessage(String account) {
    return 'RASQ 서버가 Bluesky의 공개 API에서 $account의 게시물을 읽어 **RASQ 계정 페이지에서 누구나 볼 수 있는 상태**로 만듭니다.\n\n• Bluesky 게시물은 원래 누구나 읽을 수 있습니다. 답글과 리포스트는 가져오지 않습니다.\n• **로그인 키(앱 비밀번호 / 세션)는 맡기지 않습니다**. 서버에 넘기는 것은 이 계정의 DID와 핸들뿐입니다.\n• 소유자 확인이 끝난 계정만 사용할 수 있습니다(다른 사람의 계정 게시물을 표시할 수 없도록).\n• 이 스위치를 끄면 가져온 게시물은 바로 삭제됩니다.';
  }

  @override
  String get profileEditSnsPostsAgreeShow => '동의하고 표시';

  @override
  String get profileEditCancel => '취소';

  @override
  String get profileEditSnsPostsTokenConsentTitle => '로그인 키를 RASQ에 맡깁니다';

  @override
  String profileEditSnsPostsTokenConsentMessage(String account) {
    return '$account의 게시물을 계정 페이지에 표시하기 위해 이 SNS의 **로그인 키(액세스 토큰)를 RASQ 서버에 맡깁니다**.\n\n• 내 \'공개\'와 \'홈(미등재)\' 게시물이 **RASQ 계정 페이지에서 누구나 볼 수 있는 상태**가 됩니다. \'홈\'은 팔로워 전용이 아닙니다.\n• 팔로워 전용 / 지정·DM / 로컬 전용 / 공개 범위를 알 수 없는 게시물은 가져오지 않습니다.\n• 키는 내 게시물을 읽는 데만 사용합니다. 게시·팔로우 등의 조작이나 다른 목적에는 사용하지 않습니다.\n• 키는 서버의 키로 암호화해 저장합니다(RASQ 서버는 복호화할 수 있습니다). 앱에도 다른 사람에게도 돌려주지 않습니다.\n• 이 스위치를 끄면 맡긴 키와 가져온 게시물은 바로 삭제됩니다.\n\n이 키가 있으면 그 계정을 조작할 수 있습니다. 걱정된다면 맡긴 뒤에도 SNS 쪽 설정에서 이 키(토큰)를 무효화할 수 있습니다.';
  }

  @override
  String get profileEditSnsPostsAgreeDeposit => '동의하고 맡기기';

  @override
  String profileEditSnsPostsFetched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '게시물 $count건을 가져왔습니다',
    );
    return '$_temp0';
  }

  @override
  String profileEditSnsPostsFetchFailed(String error) {
    return '맡겼지만 게시물을 가져오지 못했습니다 ($error)';
  }

  @override
  String get profileEditSnsPostsUnsupported => '이 서버에서는 아직 사용할 수 없습니다';

  @override
  String get profileEditSnsPostsVerifyFirst => '먼저 이 계정의 \'소유자 확인\'을 마쳐 주세요';

  @override
  String profileEditSnsPostsDepositFailed(String message) {
    return '맡기지 못했습니다: $message';
  }

  @override
  String get profileEditSnsPostsSwitchTitle => '게시물도 계정 페이지에 표시';

  @override
  String profileEditSnsPostsFetchError(String error) {
    return '가져오기에 실패하고 있습니다: $error';
  }

  @override
  String profileEditSnsPostsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count건 (공개 / 홈 게시물. 30분마다 업데이트)',
    );
    return '$_temp0';
  }

  @override
  String get profileEditSnsPostsBlueskySubtitle =>
      'RASQ 서버가 Bluesky의 공개 게시물을 읽습니다 (키는 맡기지 않음)';

  @override
  String get profileEditSnsPostsTokenSubtitle =>
      'SNS 로그인 키를 RASQ에 맡깁니다 (켤 때 확인이 표시됩니다)';

  @override
  String get profileEditSnsPostsCollectionsTitle => '이 키를 RASQ 리스트에도 사용';

  @override
  String get profileEditSnsPostsCollectionsSubtitle =>
      '연 RASQ 리스트를 가져오고 볼 수 있는지 확인하는 데 사용합니다';

  @override
  String get profileEditSnsPostsCollectionsDetail =>
      'RASQ 리스트·클립을 열 때 이 키로 SNS에 \'리스트의 사람을 팔로우하고 있는지\'를 문의하고, 안에 있는 사람의 공개 게시물을 가져옵니다. 게시물 표시를 위해 맡긴 키와는 다른 목적이므로 따로 선택합니다(기본값은 꺼짐, 선택 / 해제는 동의 기록에 남습니다).';

  @override
  String get profileEditSnsPostsCollectionsConsentTitle =>
      '맡긴 키를 RASQ 리스트에도 사용합니다';

  @override
  String get profileEditSnsPostsCollectionsConsentMessage =>
      '게시물 표시를 위해 맡긴 키를 다른 목적에도 사용합니다.\n\n• RASQ 리스트나 클립을 열 때 이 키로 SNS에 \'리스트의 사람을 팔로우하고 있는지\'를 문의합니다(볼 수 있는지 확인).\n• 리스트에 있는 사람의 공개 / 홈 게시물을 이 키로 가져옵니다.\n• 게시·팔로우 등의 조작에는 사용하지 않습니다.\n• 이 스위치를 끄면 바로 사용하지 않게 됩니다.';

  @override
  String get profileEditSnsPostsCollectionsAgree => '동의하고 사용';

  @override
  String profileEditSnsPostsCollectionsFailed(String message) {
    return '변경하지 못했습니다: $message';
  }

  @override
  String get profileOwnershipWhereMisskey =>
      '자기소개 또는 프로필의 \'추가 정보\' 중 한 곳에 붙여 넣고 저장해 주세요.';

  @override
  String get profileOwnershipWhereMastodon =>
      '자기소개 또는 프로필의 \'보충 정보\' 중 한 곳에 붙여 넣고 저장해 주세요.';

  @override
  String get profileOwnershipWhereBluesky => '자기소개(프로필 설명)에 붙여 넣고 저장해 주세요.';

  @override
  String get profileOwnershipWhereFields =>
      '자기소개 또는 프로필 항목 중 한 곳에 붙여 넣고 저장해 주세요.';

  @override
  String get profileOwnershipWhereBio => '자기소개에 붙여 넣고 저장해 주세요.';

  @override
  String get profileOwnershipErrorNotLinked =>
      '이 SNS 계정은 RASQ 계정에 연결되어 있지 않습니다';

  @override
  String get profileOwnershipErrorUnsupported => '이 SNS는 아직 소유자 확인을 지원하지 않습니다';

  @override
  String get profileOwnershipErrorTooMany =>
      '시도 횟수가 너무 많습니다. 잠시 기다린 후 다시 시도해 주세요';

  @override
  String get profileOwnershipErrorNotStarted =>
      '아직 확인 문구를 만들지 않았거나 기한이 지났습니다. \'확인 문구 만들기\'부터 다시 해 주세요';

  @override
  String get profileOwnershipErrorCodeNotFound =>
      '프로필에서 확인 문구를 찾지 못했습니다. 저장했는지, 공개 프로필에 표시되는지 확인해 주세요(반영까지 시간이 조금 걸릴 수 있습니다)';

  @override
  String get profileOwnershipErrorProfileNotFound =>
      '해당 SNS 계정의 공개 프로필을 찾지 못했습니다';

  @override
  String get profileOwnershipErrorReadFailed =>
      '해당 SNS의 프로필을 읽지 못했습니다. 잠시 기다린 후 다시 시도해 주세요';

  @override
  String profileOwnershipErrorFailed(String message) {
    return '확인하지 못했습니다: $message';
  }

  @override
  String get profileOwnershipKeybaseErrorUsername =>
      'Keybase 사용자 이름(영문 소문자·숫자·_, 2~16자)을 입력해 주세요';

  @override
  String get profileOwnershipKeybaseErrorSignature =>
      '서명을 읽지 못했습니다. BEGIN KEYBASE SALTPACK SIGNED MESSAGE부터 END KEYBASE SALTPACK SIGNED MESSAGE.까지 그대로 붙여 넣어 주세요';

  @override
  String get profileOwnershipKeybaseErrorStatement =>
      '서명한 문구가 다릅니다. 위의 명령을 그대로 사용해 주세요';

  @override
  String get profileOwnershipKeybaseErrorKey => '해당 Keybase 사용자의 키로 서명되지 않았습니다';

  @override
  String get profileOwnershipKeybaseErrorNoUser => '해당 Keybase 사용자를 찾지 못했습니다';

  @override
  String get profileOwnershipKeybaseErrorOtherAccount =>
      '해당 Keybase는 다른 RASQ 계정에 연결되어 있습니다';

  @override
  String get profileOwnershipKeybaseErrorExpired =>
      '문구의 기한이 지났거나 아직 만들지 않았습니다. \'서명할 문구 만들기\'부터 다시 해 주세요';

  @override
  String get profileOwnershipKeybaseErrorUnreachable =>
      'Keybase에 연결하지 못했습니다. 잠시 기다린 후 다시 시도해 주세요';

  @override
  String profileOwnershipKeybaseErrorFailed(String message) {
    return '확인하지 못했습니다: $message';
  }

  @override
  String get profileOwnershipVerifyTitle => '소유자 확인';

  @override
  String get profileOwnershipNotLinked => '이 SNS 계정은 RASQ 계정에 연결되어 있지 않습니다.';

  @override
  String profileOwnershipVerified(String method) {
    return '확인됨($method)';
  }

  @override
  String get profileOwnershipJustVerified => '확인되었습니다. 프로필에 붙인 문구는 이제 지워도 됩니다.';

  @override
  String get profileOwnershipVerifiedCaption =>
      '계정 페이지와 SNS 프로필에 확인됨 표시가 붙습니다.';

  @override
  String get profileOwnershipVerifiedCaptionDetail =>
      '계정 페이지와 SNS 프로필에 표시되는 RASQ 계정 칸에 확인됨 표시가 붙습니다. 이 SNS 계정을 해제할 때까지 유지됩니다.';

  @override
  String get profileOwnershipUnsupportedKind =>
      '이 SNS는 아직 본인 확인을 지원하지 않습니다(Misskey / Mastodon / Bluesky만).';

  @override
  String get profileOwnershipIntro =>
      '이 SNS 계정이 회원님의 것인지 확인합니다. 프로필에 확인 문구를 일시적으로 붙여 주세요.';

  @override
  String get profileOwnershipIntroDetail =>
      '이 SNS 계정이 회원님의 것인지 확인합니다. 확인 문구를 해당 SNS 프로필에 일시적으로 붙여 주시면, RASQ가 그 공개 프로필을 읽어 확인합니다.';

  @override
  String get profileOwnershipEffect => '확인하면 확인됨 표시가 붙습니다.';

  @override
  String get profileOwnershipEffectDetail =>
      '확인하면 계정 페이지와 SNS 프로필의 RASQ 계정 칸에 확인됨 표시가 붙습니다. 같은 SNS 계정을 다른 사람이 연결하고 있어도 확인한 사람이 우선됩니다.';

  @override
  String get profileOwnershipStart => '확인 문구 만들기';

  @override
  String get profileOwnershipStep1 => '1. 이 문구를 복사하기';

  @override
  String get profileOwnershipCopied => '확인 문구를 복사했습니다';

  @override
  String get profileOwnershipCopy => '복사';

  @override
  String profileOwnershipValidUntil(String time) {
    return '$time까지 유효';
  }

  @override
  String get profileOwnershipStep2 => '2. 해당 SNS 프로필에 붙이기';

  @override
  String get profileOwnershipNoRewrite =>
      'RASQ가 프로필을 수정하지는 않습니다. 해당 SNS에서 직접 붙여 주세요.';

  @override
  String get profileOwnershipStep3 => '3. 붙였으면 \'확인하기\'';

  @override
  String get profileOwnershipCheck => '확인하기';

  @override
  String get profileOwnershipRestart => '문구 다시 만들기';

  @override
  String get profileOwnershipKeybaseNoLinks => 'Keybase 증명에 연결된 SNS 계정이 없었습니다.';

  @override
  String profileOwnershipKeybaseLinksVerified(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Keybase 증명으로 연결된 SNS 계정 $count개도 확인되었습니다.',
    );
    return '$_temp0';
  }

  @override
  String profileOwnershipKeybaseLinked(String username, String links) {
    return '@$username을(를) 연결했습니다. $links';
  }

  @override
  String get profileOwnershipKeybaseUnlinked =>
      'Keybase를 해제했습니다. Keybase 증명으로 확인했던 SNS 계정은 미확인으로 돌아갑니다.';

  @override
  String profileOwnershipKeybaseVerifiedAt(String time) {
    return '$time에 확인';
  }

  @override
  String profileOwnershipKeybaseCaption(String username) {
    return '계정 페이지에 \'Keybase: @$username\'이 표시됩니다.';
  }

  @override
  String profileOwnershipKeybaseCaptionDetail(String username) {
    return '계정 페이지에 \'Keybase: @$username\'이 표시됩니다. Keybase에서 Mastodon 등의 증명을 추가하면 \'증명 다시 읽기\'로 연결된 SNS 계정도 확인됩니다.';
  }

  @override
  String get profileOwnershipKeybaseRefresh => '증명 다시 읽기';

  @override
  String get profileOwnershipKeybaseUnlink => 'Keybase 해제';

  @override
  String get profileOwnershipKeybaseIntro =>
      'Keybase로 서명하여 이 RASQ 계정과 연결합니다. 연결한 Keybase는 공개됩니다.';

  @override
  String get profileOwnershipKeybaseIntroDetail =>
      'Keybase 계정으로 서명하여 이 RASQ 계정과 연결합니다. 연결한 Keybase는 계정 페이지에 표시됩니다(Keybase 프로필과 마찬가지로 공개입니다).';

  @override
  String get profileOwnershipKeybaseUsername => 'Keybase 사용자 이름';

  @override
  String get profileOwnershipKeybaseStart => '서명할 문구 만들기';

  @override
  String get profileOwnershipKeybaseStep1 => '1. Keybase가 설치된 기기에서 이 명령을 실행하기';

  @override
  String get profileOwnershipKeybaseCopied => '명령을 복사했습니다';

  @override
  String profileOwnershipKeybaseStatement(String statement) {
    return '서명할 문구: $statement';
  }

  @override
  String get profileOwnershipKeybaseStep2 =>
      '2. 나온 서명을 BEGIN부터 END … MESSAGE.까지 붙이기';

  @override
  String get profileOwnershipKeybaseVerify => '확인하기';

  @override
  String profilePagePostLimit(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: '게시물은 $limit개까지입니다. 오래된 게시물을 지운 후 게시해 주세요',
    );
    return '$_temp0';
  }

  @override
  String get profilePageEdit => '편집';

  @override
  String get profilePageCompose => 'RASQ에 게시';

  @override
  String profilePageNotFound(String handle) {
    return '@$handle라는 RASQ 계정이 없습니다';
  }

  @override
  String profilePageLoadFailed(String message) {
    return '불러오지 못했습니다: $message';
  }

  @override
  String get profilePageLoadFailedShort => '불러오지 못했습니다.';

  @override
  String get profilePageTabPosts => '게시물';

  @override
  String get profilePageTabMedia => '미디어';

  @override
  String get profilePageTabPages => '페이지';

  @override
  String get profilePageTabLists => '리스트';

  @override
  String get profilePageTabClips => '클립';

  @override
  String get profilePageTabPlugins => '플러그인';

  @override
  String get profilePageTabReviews => '리뷰';

  @override
  String get profilePageTileNoDestination => '이 계정의 이동할 곳을 알 수 없습니다';

  @override
  String profilePageOpenFailed(String url) {
    return '열지 못했습니다: $url';
  }

  @override
  String get profilePageListsEmptyMine =>
      '공개한 RASQ 리스트가 여기에 표시됩니다(리스트 화면에서 만들 수 있습니다).';

  @override
  String get profilePageClipsEmptyMine =>
      '공개한 RASQ 클립이 여기에 표시됩니다(클립 페이지의 \'공개하기\').';

  @override
  String get profilePageListsEmpty => '공개한 리스트가 없습니다.';

  @override
  String get profilePageClipsEmpty => '공개한 클립이 없습니다.';

  @override
  String profilePageSince(String date) {
    return '$date부터';
  }

  @override
  String profilePagePinLimit(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '고정은 $count개까지 가능합니다',
    );
    return '$_temp0';
  }

  @override
  String profilePagePinFailed(String message) {
    return '고정하지 못했습니다: $message';
  }

  @override
  String get profilePagePinned => '고정된 게시물';

  @override
  String profilePagePostsNote(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'RASQ 게시물은 $limit개까지입니다($used / $limit). 로그인 키를 맡기면 SNS 게시물도 함께 표시됩니다.',
    );
    return '$_temp0';
  }

  @override
  String profilePagePostsNoteDetail(int limit, int used) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other:
          'RASQ 계정으로서의 게시물은 현재 $limit개까지입니다($used / $limit). SNS 계정의 게시물은 해당 계정의 액세스 토큰을 RASQ에 맡기면 여기에 함께 표시됩니다.',
    );
    return '$_temp0';
  }

  @override
  String get profilePageSnsHintTitle => '연결한 SNS 계정의 게시물은 아직 여기에 표시되지 않습니다.';

  @override
  String get profilePageSnsHint =>
      '프로필 편집에서 \'게시물도 계정 페이지에 표시\'를 켜면 여기에 표시됩니다.';

  @override
  String get profilePageSnsHintDetail =>
      '프로필 편집의 \'계정 페이지에 표시할 SNS 계정\'에서 계정마다 \'게시물도 계정 페이지에 표시\'를 켜면(해당 SNS의 액세스 토큰을 RASQ에 맡깁니다) 공개 / 홈 게시물이 여기에 표시됩니다.';

  @override
  String get profilePageSnsHintOpen => 'SNS 게시물 표시 설정으로';

  @override
  String get profilePageNoPostsYet => '아직 게시물이 없습니다.';

  @override
  String get profilePageNoMediaYet => '아직 미디어가 없습니다.';

  @override
  String get profilePageNoReviewsYet => '아직 리뷰가 없습니다.';

  @override
  String get profilePageNoPluginsPublished => '공개한 플러그인이 없습니다.';

  @override
  String get profilePageImageUrlMissing => '이미지 URL이 반환되지 않았습니다';

  @override
  String get profilePageNotConnected => 'RASQ 서버에 연결되어 있지 않습니다';

  @override
  String get profilePagePackageTypeLabel => '플러그인(.rspkg / .rasqpkg)';

  @override
  String get profilePageImage => '이미지';

  @override
  String profilePageImageAlt(String alt) {
    return '(이미지: $alt)';
  }

  @override
  String get profilePageMdFallbackTitle => '페이지';

  @override
  String get profilePageMdLoadFailed => '페이지를 불러오지 못했습니다';

  @override
  String get profilePageMdToolBold => '굵게';

  @override
  String get profilePageMdToolHeading => '제목';

  @override
  String get profilePageMdToolBullet => '글머리 기호';

  @override
  String get profilePageMdToolLink => '링크';

  @override
  String get profilePageMdToolCenter => '가운데';

  @override
  String get profilePageMdToolBig => '크게';

  @override
  String get profilePageMdToolSmall => '작게';

  @override
  String get profilePageMdToolSpin => '회전';

  @override
  String get profilePageMdToolJump => '튀기';

  @override
  String get profilePageMdToolColor => '색상';

  @override
  String get profilePageMdToolRainbow => '무지개';

  @override
  String get profilePageMdToolRuby => '루비';

  @override
  String get profilePageMdToolRubyReading => '읽기';

  @override
  String profilePageImageUploadFailed(String error) {
    return '이미지를 올리지 못했습니다: $error';
  }

  @override
  String get profilePageMdTitleRequired => '제목을 입력해 주세요';

  @override
  String get profilePageMdLoginToPublish => 'RASQ 계정에 로그인하면 공개할 수 있습니다';

  @override
  String get profilePageMdPublished => '공개했습니다';

  @override
  String profilePageMdPublishFailed(String error) {
    return '공개하지 못했습니다: $error';
  }

  @override
  String get profilePageMdDeleteTitle => '페이지 삭제';

  @override
  String get profilePageMdDeleteDraft => '초안을 삭제합니다.';

  @override
  String get profilePageMdDeletePublished => '공개한 페이지와 초안을 삭제합니다. 되돌릴 수 없습니다.';

  @override
  String get profilePageDeleteConfirm => '삭제하기';

  @override
  String get profilePageCancel => '취소';

  @override
  String profilePageMdDeleteFailed(String error) {
    return '삭제하지 못했습니다: $error';
  }

  @override
  String get profilePageMdEditTitle => '페이지 편집';

  @override
  String get profilePageMdDelete => '삭제';

  @override
  String get profilePageMdWrite => '쓰기';

  @override
  String get profilePageMdPreview => '미리보기';

  @override
  String get profilePageMdPublish => '공개';

  @override
  String get profilePageMdTitleHint => '제목';

  @override
  String get profilePageMdBodyHint =>
      'Markdown으로 작성합니다. @멘션 / #해시태그 / :이모지: / <center> 등의 MFM 태그도 사용할 수 있습니다';

  @override
  String get profilePageMdDraftCaption =>
      '초안은 이 기기에 남습니다. \'공개\'로 RASQ 페이지에 게시합니다';

  @override
  String get profilePageRasqAccount => 'RASQ 계정';

  @override
  String profilePageViewingVerified(String method) {
    return '이 계정의 소유자 확인됨($method)';
  }

  @override
  String get profilePageVerifiedSemantics => '소유자 확인됨';

  @override
  String get profilePostLoginToUse => 'RASQ 계정에 로그인하면 사용할 수 있습니다';

  @override
  String get profilePostLoginToReply => 'RASQ 계정에 로그인하면 답글을 달 수 있습니다';

  @override
  String get profilePostLoginToRebroad => 'RASQ 계정에 로그인하면 리브로드할 수 있습니다';

  @override
  String get profilePostLoginToQueue => 'RASQ 계정에 로그인하면 큐할 수 있습니다';

  @override
  String get profilePostErrorInstallPack => '스토어에서 이 팩을 설치하면 이 그림으로 큐할 수 있습니다';

  @override
  String get profilePostErrorForbidden => '이 게시물에는 이 작업을 할 수 없습니다';

  @override
  String get profilePostErrorRebroadLimit => '이 게시물은 더 이상 리브로드할 수 없습니다';

  @override
  String get profilePostErrorReplyLimit => '답글은 100개까지입니다. 오래된 답글을 삭제해 주세요';

  @override
  String get profilePostErrorGone => '이 게시물 / 그림은 더 이상 없습니다';

  @override
  String profilePostErrorFailed(String message) {
    return '실패했습니다: $message';
  }

  @override
  String get profilePostMenuReactions => '리액션 보기';

  @override
  String get profilePostMenuCopyLink => '링크 복사';

  @override
  String get profilePostMenuOpenBrowser => '브라우저에서 열기';

  @override
  String get profilePostMenuEditActions => '액션 바 편집';

  @override
  String get profilePostMenuUnpin => '고정 해제';

  @override
  String get profilePostMenuPin => '고정';

  @override
  String get profilePostMenuDelete => '삭제';

  @override
  String get profilePostLinkCopied => '링크를 복사했습니다';

  @override
  String get profilePostDeleteTitle => '게시물 삭제';

  @override
  String get profilePostDeleteMessage => '이 게시물과 첨부된 이미지를 삭제합니다. 되돌릴 수 없습니다.';

  @override
  String get profilePostDeleteConfirm => '삭제';

  @override
  String get profilePostCancel => '취소';

  @override
  String get profilePostQuoteUnavailable => '인용한 게시물을 볼 수 없습니다';

  @override
  String get profilePostReply => '답글';

  @override
  String get profilePostRebroad => '리브로드';

  @override
  String get profilePostRebroadUndo => '리브로드 취소';

  @override
  String get profilePostQuote => '인용';

  @override
  String get profilePostQueue => '큐';

  @override
  String get profilePostLike => '좋아요';

  @override
  String get profilePostQuoteFollowersOnly => '팔로워 전용 게시물은 인용할 수 없습니다';

  @override
  String profilePostRebroadedBy(String name) {
    return '$name 님이 리브로드';
  }

  @override
  String get profilePostReplyToDeleted => '삭제된 게시물에 대한 답글';

  @override
  String get profilePostShare => '공유';

  @override
  String get profilePostCwHide => '숨기기';

  @override
  String get profilePostCwShow => '더 보기';

  @override
  String get profilePostNoPacksTitle => '에셋 팩이 없습니다';

  @override
  String get profilePostNoPacksMessage => '큐는 스토어에서 받은 에셋 팩의 그림으로 하는 리액션입니다.';

  @override
  String get profilePostNoPacksStore => '스토어에서 찾기';

  @override
  String get profilePostClose => '닫기';

  @override
  String profilePostOverlayQueueTooltip(String label) {
    return '$label(길게 눌러 그림 선택)';
  }

  @override
  String get profilePostMenu => '메뉴';

  @override
  String get profilePostTitle => '게시물';

  @override
  String get profilePostGone => '이 게시물은 더 이상 없습니다';

  @override
  String profilePostLoadFailed(String message) {
    return '불러오지 못했습니다: $message';
  }

  @override
  String get profilePostParentDeleted => '원래 게시물은 삭제되었습니다.';

  @override
  String profilePostRepliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '답글 $count',
    );
    return '$_temp0';
  }

  @override
  String get profilePostNoRepliesYet => '아직 답글이 없습니다.';

  @override
  String get profilePostNoReplies => '답글이 없습니다';

  @override
  String get profilePostNoRebroads => '리브로드가 없습니다';

  @override
  String get profilePostNoQuotes => '인용이 없습니다';

  @override
  String get profilePostNoQueues => '큐가 없습니다';

  @override
  String get profilePostReactionsTitle => '리액션';

  @override
  String get profilePostYou => '나';

  @override
  String get quickPickEmojiTitle => '빠른 이모지';

  @override
  String get quickPickEmojiMore => '다른 이모지';

  @override
  String get quickPickSettingsCaption =>
      '리액션 버튼이나 작성 화면의 이모지 버튼을 길게 누르면 버튼에 붙은 패널에 여기의 이모지와 최근 사용한 이모지가 표시됩니다. 손가락을 떼지 않고 밀어서 뗀 위치의 이모지를 추가(입력)합니다. 밀지 않고 떼면 패널이 열린 채로 남아 탭해서 고를 수 있습니다.';

  @override
  String get quickPickSettingsAdd => '이모지 추가';

  @override
  String get quickPickSettingsReset => '기본값으로 되돌리기';

  @override
  String quickPickSettingsRemove(String name) {
    return '$name 제거';
  }

  @override
  String get quickPickSettingsEmpty => '이모지가 없습니다. 패널에는 최근 사용한 이모지만 표시됩니다';

  @override
  String get raiModeInstruction => '인스트럭션';

  @override
  String get raiModeAssistant => '어시스턴트';

  @override
  String get raiGuideDefaultTitle => '안내';

  @override
  String raiHeldDeclined(String calls) {
    return '실행하지 않았습니다($calls)';
  }

  @override
  String raiAutoDeclined(String title) {
    return '알겠습니다. \'$title\'을(를) 안내로 진행하려면 \'이 순서로 안내\'를 눌러 주세요';
  }

  @override
  String raiAutoProgress(int step, int total, String text) {
    return '자동으로 진행 중($step / $total): $text';
  }

  @override
  String raiAutoAskingDetail(String label) {
    return '$label 선택';
  }

  @override
  String raiAutoAskDestination(String title) {
    return '\'$title\'을(를) 어디로 가져올까요?';
  }

  @override
  String raiAutoAskWhich(String label) {
    return '$label은(는) 어느 것으로 할까요?';
  }

  @override
  String get raiAutoAskHint => '후보에서 고르거나 다른 단어를 입력해 주세요';

  @override
  String raiAutoNotFoundDetail(String label) {
    return '$label을(를) 찾을 수 없음';
  }

  @override
  String raiAutoNotFoundAsk(String label) {
    return '$label을(를) 찾을 수 없습니다. 다른 $label(으)로 찾을까요?';
  }

  @override
  String raiAutoAskWhichCount(String label, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$label은(는) 어느 것으로 할까요?($count개)',
    );
    return '$_temp0';
  }

  @override
  String raiAutoCancelled(String title) {
    return '\'$title\' 자동화를 중지했습니다';
  }

  @override
  String raiAutoFailedAt(String title, int step, String detail) {
    return '\'$title\'이(가) $step단계에서 멈췄습니다: $detail';
  }

  @override
  String raiAutoPartlyDone(int done, int step, String text) {
    String _temp0 = intl.Intl.pluralLogic(
      done,
      locale: localeName,
      other: '$done단계를 함수로 진행했습니다. $step단계 \'$text\'부터는 누를 부품이 있으므로 안내합니다',
    );
    return '$_temp0';
  }

  @override
  String raiAutoDone(String title) {
    return '\'$title\'을(를) 함수로 진행했습니다';
  }

  @override
  String get raiInstructionUnknown =>
      '아직 익히지 못한 조작입니다. \'게시\', \'로그인\', \'공유\' 등으로 물어봐 주세요.';

  @override
  String get raiAskChoice => '어느 것을 말씀하시나요? 위의 선택지에서 골라 주세요';

  @override
  String get raiNoReply => '응답이 없었습니다';

  @override
  String raiFailureDevice(String message) {
    return '기기 내 모델: $message';
  }

  @override
  String raiFailureFallUp(String message) {
    return '폴업: $message';
  }

  @override
  String raiProposalReady(String title) {
    return '안내 \'$title\'을(를) 준비했습니다(아래 타일에서 시작할 수 있습니다)';
  }

  @override
  String raiProposalReadyStopAt(String title, int step) {
    return '안내 \'$title\'을(를) $step단계까지 진행할 준비를 했습니다(아래 타일에서)';
  }

  @override
  String raiHeldNote(String calls) {
    return '(가져온 정보를 바탕으로 한 조작은 확인 후 실행합니다: $calls)';
  }

  @override
  String get raiNoReplyParen => '(응답이 없었습니다)';

  @override
  String raiRestartInjecting(String keys) {
    return '가져온 정보($keys)를 주입해 모델을 다시 시작합니다';
  }

  @override
  String get raiAutoDetailReplaced => '함수로 대체';

  @override
  String get raiAutoDetailNoFunction => '대응하는 함수 없음';

  @override
  String get raiAutoDetailGuideParts => '누를 부품은 안내로';

  @override
  String get raiAutoDetailExplanationOnly => '설명만';

  @override
  String raiAutoDescribeNoBound(String title) {
    return '\'$title\'은(는) 함수로 대신할 수 있는 단계가 없으므로 안내(가리키기)로 진행합니다.';
  }

  @override
  String raiAutoDescribeHead(String title) {
    return '\'$title\'은(는) 안내 없이 제가 함수로 하겠습니다:';
  }

  @override
  String raiAutoDescribeGuideMark(String detail) {
    return '(여기부터는 안내: $detail)';
  }

  @override
  String get raiListSeparator => ', ';

  @override
  String raiAutoDescribeFromQuestion(String inputs) {
    return '질문에서: $inputs';
  }

  @override
  String raiAutoDescribeEntrusted(String labels) {
    return '$labels은(는) 후보의 첫 번째로 진행합니다(맡기셨으므로)';
  }

  @override
  String raiAutoDescribeAskLater(String labels) {
    return '$labels은(는) 실행 도중에 골라 주세요';
  }

  @override
  String get raiAutoDescribeConfirm => '괜찮으면 \'실행하기\'를 눌러 주세요.';

  @override
  String raiProposalHead(String title, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '\'$title\'이라면 이 순서로 진행합니다($count단계)',
    );
    return '$_temp0';
  }

  @override
  String raiProposalFunction(String function) {
    return '〔$function〕';
  }

  @override
  String raiProposalInputs(String inputs) {
    return ' 입력: $inputs';
  }

  @override
  String raiProposalPresets(String presets) {
    return ' 고정: $presets';
  }

  @override
  String get raiModeSemantics => 'RAi 모드';

  @override
  String get raiAskButton => '질문하기';

  @override
  String get raiInputHint => '곤란할 때 도와드릴게요!';

  @override
  String raiInputPredicted(String prediction) {
    return '$prediction(스페이스로 입력)';
  }

  @override
  String get raiCollapse => '접기';

  @override
  String get raiExpand => '펼치기';

  @override
  String get raiAskMore => '더 묻기';

  @override
  String get raiHistoryClose => '기록 닫기';

  @override
  String get raiHistory => '발언 기록';

  @override
  String get raiClose => 'RAi 닫기';

  @override
  String get raiNext => '다음';

  @override
  String get raiDone => '알겠어요(닫기)';

  @override
  String get raiSpeechClose => '닫기';

  @override
  String get raiHistoryEmpty => '아직 발언이 없습니다';

  @override
  String get raiCopy => '복사';

  @override
  String get raiCopied => '복사했습니다';

  @override
  String raiChatSuspended(int step, int total) {
    return '안내를 일시 정지했습니다($step / $total단계). 돌아가면 이어집니다.';
  }

  @override
  String get raiChatResume => '이어서';

  @override
  String get raiChatHeadline => '매크로 같은 건 맡겨 주세요!';

  @override
  String get raiChatIntro => '조작을 물으면 RAi가 버튼을 가리키며 알려 줍니다.';

  @override
  String get raiChatIntroDetail =>
      '인스트럭션: 조작을 물으면 RAi가 버튼까지 이동해 가리킵니다.\n어시스턴트: 기기 내 모델로 답합니다. 모델은 바의 칩에서 고를 수 있습니다(매크로는 2기).';

  @override
  String get raiChatRecent => '최근 질문';

  @override
  String get raiChatRejectCandidates => '이게 아니에요(후보를 빼고 다시 답하기)';

  @override
  String raiChatProposalTitle(String title, int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$title · $steps단계',
    );
    return '$_temp0';
  }

  @override
  String get raiChatSkip => '건너뛰기';

  @override
  String get raiChatGuide => '이 순서로 안내';

  @override
  String raiChatGuideTitle(String title) {
    return '안내 \'$title\'';
  }

  @override
  String get raiChatTrace => '공정';

  @override
  String get raiChatShowGraph => '그래프 뷰로 표시';

  @override
  String get raiChatApproveHeld => '이 조작을 실행할까요?(가져온 정보에서 나온 조작입니다)';

  @override
  String get raiChatApprove => 'RAi에게 맡길까요?';

  @override
  String get raiChatDecline => '그만두기';

  @override
  String get raiChatRun => '실행하기';

  @override
  String get raiHomeSidebarSemantics => 'RAi 사이드바';

  @override
  String get raiHomeClose => '닫기';

  @override
  String get raiHomeNewConversation => '새 대화';

  @override
  String get raiHomeHistory => '대화 기록';

  @override
  String raiHomeCurrentConversation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '현재 대화 · $count개',
    );
    return '$_temp0';
  }

  @override
  String raiHomeConversationSubtitle(String when, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$when · $count개',
    );
    return '$_temp0';
  }

  @override
  String get raiHomeDelete => '삭제';

  @override
  String get raiHomeHistoryEmpty => '아직 없습니다. 질문하면 여기에 대화가 남습니다.';

  @override
  String get raiHomeOther => '기타';

  @override
  String get raiAchievementsTitle => '업적';

  @override
  String raiAchievementsProgress(int unlocked, int total) {
    return '$unlocked / $total 달성';
  }

  @override
  String get raiHomeMacro => '매크로';

  @override
  String get raiHomeMacroSoon => '준비 중';

  @override
  String get raiBarSemantics => 'RAi 바';

  @override
  String get raiAskCancel => '그만두기';

  @override
  String raiAskInputHint(String label) {
    return '$label 입력';
  }

  @override
  String raiAskInputOtherHint(String label) {
    return '다른 $label 입력';
  }

  @override
  String get raiAskDone => '확인';

  @override
  String raiAchievementsStats(
    int instructions,
    int assistant,
    int app,
    int completed,
    int repeated,
  ) {
    return '인스트럭션 $instructions회 · 어시스턴트 $assistant회(앱 이야기 $app회) · 완주 $completed회 · 다시 묻기 $repeated회';
  }

  @override
  String get raiAchievementAsk1Title => '첫 질문';

  @override
  String get raiAchievementAsk1Description => '인스트럭션을 1회 물었다';

  @override
  String get raiAchievementAsk10Title => '질문의 달인';

  @override
  String get raiAchievementAsk10Description => '인스트럭션을 10회 물었다';

  @override
  String get raiAchievementAsk50Title => 'RAi 단골';

  @override
  String get raiAchievementAsk50Description => '인스트럭션을 50회 물었다';

  @override
  String get raiAchievementApp5Title => '앱 박사';

  @override
  String get raiAchievementApp5Description => '어시스턴트와 앱에 대해 5회 이야기했다';

  @override
  String get raiAchievementChat20Title => '수다쟁이';

  @override
  String get raiAchievementChat20Description => '어시스턴트에게 20회 말을 걸었다';

  @override
  String get raiAchievementDone1Title => '한 번에 완주';

  @override
  String get raiAchievementDone1Description => '안내를 마지막 단계까지 진행했다';

  @override
  String get raiAchievementDone10Title => '완주 마스터';

  @override
  String get raiAchievementDone10Description => '안내를 10회 끝까지 진행했다';

  @override
  String get raiAchievementAgain3Title => '복습 중';

  @override
  String get raiAchievementAgain3Description => '같은 조작을 3회 다시 물었다';

  @override
  String get raiAchievementAuto1Title => '맡김';

  @override
  String get raiAchievementAuto1Description => '\'건너뛰기\'로 RAi에게 맡겼다';

  @override
  String get raiTracePortPrev => '이전';

  @override
  String get raiTracePortState => '상태';

  @override
  String get raiTracePortFunction => '함수';

  @override
  String get raiTracePortResult => '결과';

  @override
  String get raiTracePortNext => '다음';

  @override
  String get raiTraceStatusDone => '함수로 완료';

  @override
  String get raiTraceStatusSkipped => '접음';

  @override
  String get raiTraceStatusGuide => '안내로';

  @override
  String get raiTraceStatusFailed => '실패';

  @override
  String get raiTraceStatusAsking => '선택 대기';

  @override
  String get raiTraceStatusRunning => '실행 중';

  @override
  String get raiTraceStatusPending => '미실행';

  @override
  String raiTraceCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '공정 $count단계',
    );
    return '$_temp0';
  }

  @override
  String get raiDiagTitle => '진단(개발자 모드)';

  @override
  String get raiDiag3dOn => '3D RAi: 사용';

  @override
  String get raiDiag3dOff => '3D RAi: 사용 안 함(2D로 표시)';

  @override
  String get raiDiag3dOffAndroid =>
      '3D RAi: 사용 안 함(Android는 기본 2D. 개발자 모드의 \'3D RAi 사용해 보기(Android)\'로 켜기)';

  @override
  String raiDiag3dFailed(String reason) {
    return '3D RAi: 실패하여 2D로 전환했습니다($reason)';
  }

  @override
  String raiDiagLlm(String phase, String message) {
    return '기기 내 LLM: $phase($message)';
  }

  @override
  String raiDiagEmbedding(String phase, String message) {
    return '임베딩 모델: $phase($message)';
  }

  @override
  String get raiDiagEmpty => '기록된 실패가 없습니다';

  @override
  String get raiDiagRetry3d => '3D 다시 시도';

  @override
  String raiFunctionsSettingMissing(String area, String key, String keys) {
    return '\'$area\'에 \'$key\'라는 설정이 없습니다(있는 설정: $keys)';
  }

  @override
  String raiFunctionsSettingNotWritable(String key) {
    return '\'$key\'는 화면에서 변경할 수 있는 설정이 아닙니다';
  }

  @override
  String raiFunctionsSettingNeedsPassword(String key) {
    return '\'$key\'는 비밀번호가 필요하므로 RAi가 변경하지 않습니다';
  }

  @override
  String raiFunctionsSettingLocked(String key) {
    return '\'$key\'에 조작 금지 태그가 붙어 있으므로 RAi가 변경하지 않습니다';
  }

  @override
  String raiFunctionsFoldEmpty(String head) {
    return '$head: 해당 없음';
  }

  @override
  String raiFunctionsFoldHead(String head, int total, int shown) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$head $total건 중 $shown건:',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsUnsupported(String name) {
    return '이 SNS에서는 사용할 수 없습니다($name)';
  }

  @override
  String raiFunctionsNotAutomatable(String name, String alt, String result) {
    return '$name는 자동화할 수 없습니다(전송은 사용자가 누릅니다). 대신 $alt: $result';
  }

  @override
  String raiFunctionsUnknown(String name) {
    return '알 수 없는 함수입니다: $name';
  }

  @override
  String raiFunctionsFailed(String name, String error) {
    return '$name 실패: $error';
  }

  @override
  String get raiFunctionsNotLoggedInSns => 'SNS에 로그인하지 않았습니다';

  @override
  String raiFunctionsLineReactions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '(반응 $count)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsPostsNone => '해당하는 게시물이 없습니다';

  @override
  String raiFunctionsPostsHead(int count, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '게시물 $count건($total건 중):',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsReferenceOperation(String title, String id, String steps) {
    return '조작 \'$title\'($id): $steps';
  }

  @override
  String raiFunctionsReferenceFunction(String id, String does) {
    return '함수 $id: $does';
  }

  @override
  String raiFunctionsReferenceParams(String params) {
    return ' 인수: $params';
  }

  @override
  String get raiFunctionsReferenceParamInput => '입력';

  @override
  String raiFunctionsReferenceParamFixed(String value) {
    return '고정=$value';
  }

  @override
  String raiFunctionsReferenceMissing(String id) {
    return '레퍼런스에 $id가 없습니다';
  }

  @override
  String raiFunctionsActionMissing(String id) {
    return '액션 $id가 없습니다';
  }

  @override
  String raiFunctionsActionNotAllowed(String label) {
    return '\'$label\'는 자동화가 허용되지 않았습니다(RAi가 실행하지 않습니다). 대신 단계별로 안내하거나 사용자가 직접 누르게 하세요';
  }

  @override
  String raiFunctionsActionDone(String label, String state) {
    return '$label을(를) 실행했습니다($state)';
  }

  @override
  String get raiFunctionsActionDoneYes => '완료';

  @override
  String get raiFunctionsActionDoneNo => '미완료';

  @override
  String get raiFunctionsAstellNoRooms => 'ASTell 룸이 없습니다';

  @override
  String raiFunctionsAstellRooms(String rooms) {
    return 'ASTell 룸: $rooms';
  }

  @override
  String get raiFunctionsAstellNoTitle => '제목이 없습니다';

  @override
  String raiFunctionsAstellCreated(String title, String id) {
    return 'ASTell \'$title\'을(를) 만들었습니다 [$id]';
  }

  @override
  String raiFunctionsNotifReaction(String who, String reaction) {
    return '$who님이 리액션$reaction';
  }

  @override
  String raiFunctionsNotifRepost(String who) {
    return '$who님이 리노트';
  }

  @override
  String raiFunctionsNotifQuote(String who) {
    return '$who님이 인용';
  }

  @override
  String raiFunctionsNotifReply(String who) {
    return '$who님이 답글';
  }

  @override
  String raiFunctionsNotifMention(String who) {
    return '$who님이 멘션';
  }

  @override
  String raiFunctionsNotifFollow(String who) {
    return '$who님이 팔로우';
  }

  @override
  String raiFunctionsNotifFollowRequest(String who) {
    return '$who님이 팔로우 요청';
  }

  @override
  String raiFunctionsNotifFollowAccepted(String who) {
    return '$who님이 팔로우 승인';
  }

  @override
  String raiFunctionsNotifListAdded(String who) {
    return '$who님이 리스트에 추가';
  }

  @override
  String get raiFunctionsNotifPollEnded => '투표 종료';

  @override
  String get raiFunctionsNotifTimer => '타이머 알림';

  @override
  String get raiFunctionsNotifVc => 'ASTell 알림';

  @override
  String get raiFunctionsNotifSystem => '시스템 알림';

  @override
  String get raiFunctionsNotifOther => '기타 알림';

  @override
  String get raiFunctionsUnreadMark => '(읽지 않음)';

  @override
  String get raiFunctionsMissingPostId => '게시물 id(id=)가 없습니다';

  @override
  String get raiFunctionsMissingPostArg => '게시물 id(post=)가 없습니다';

  @override
  String raiFunctionsThreadReply(String line) {
    return '답글: $line';
  }

  @override
  String get raiFunctionsHeadThread => '스레드';

  @override
  String get raiFunctionsHeadReactions => '반응';

  @override
  String get raiFunctionsHeadReposters => '리노트한 사람';

  @override
  String get raiFunctionsHeadQuotes => '인용';

  @override
  String get raiFunctionsHeadFavorites => '즐겨찾기';

  @override
  String get raiFunctionsHeadReacted => '리액션함';

  @override
  String raiFunctionsMe(String user, String plugin) {
    return '나: $user 플러그인=$plugin';
  }

  @override
  String get raiFunctionsUserIdOrHandle => 'id= 또는 handle=을 지정하세요';

  @override
  String get raiFunctionsNotFound => '찾을 수 없습니다';

  @override
  String raiFunctionsUserCounts(String followers, String following) {
    return ' 팔로워 $followers 팔로잉 $following';
  }

  @override
  String get raiFunctionsMissingUser => 'user id(user=)가 없습니다';

  @override
  String raiFunctionsHeadUserPosts(String filter) {
    return '게시물($filter)';
  }

  @override
  String get raiFunctionsMissingKeyword => 'keyword가 없습니다';

  @override
  String raiFunctionsHeadUserSearch(String keyword) {
    return '사용자 검색 \'$keyword\'';
  }

  @override
  String get raiFunctionsHeadFollowing => '팔로잉';

  @override
  String get raiFunctionsHeadFollowers => '팔로워';

  @override
  String get raiFunctionsRelFollowing => '팔로잉';

  @override
  String get raiFunctionsRelFollowedBy => '나를 팔로우함';

  @override
  String get raiFunctionsRelRequested => '요청 중';

  @override
  String get raiFunctionsRelMuted => '뮤트 중';

  @override
  String get raiFunctionsRelBlocked => '차단 중';

  @override
  String get raiFunctionsRelBlockedBy => '나를 차단함';

  @override
  String get raiFunctionsRelNone => '없음';

  @override
  String raiFunctionsRelation(String flags) {
    return '관계: $flags';
  }

  @override
  String raiFunctionsRequestLine(String user, String id) {
    return '$user [요청 $id]';
  }

  @override
  String raiFunctionsHeadModeration(String kind) {
    return '모더레이션($kind)';
  }

  @override
  String raiFunctionsHeadNotifications(int unread) {
    String _temp0 = intl.Intl.pluralLogic(
      unread,
      locale: localeName,
      other: '알림(읽지 않음 $unread건)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNotificationsRead => '알림을 읽음으로 표시했습니다';

  @override
  String raiFunctionsTrendLine(String tag, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$tag($count명)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadTrends => '트렌드';

  @override
  String raiFunctionsListLine(String name, String id, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name [$id]($count명)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadLists => '리스트';

  @override
  String get raiFunctionsMissingList => 'list id(list=)가 없습니다';

  @override
  String get raiFunctionsHeadListMembers => '리스트 멤버';

  @override
  String raiFunctionsClipCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '($count건)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadClips => '클립';

  @override
  String get raiFunctionsMissingClip => 'clip id(clip=)가 없습니다';

  @override
  String get raiFunctionsHeadClipNotes => '클립 내용';

  @override
  String get raiFunctionsHeadFeeds => '피드';

  @override
  String raiFunctionsDmUnread(int count) {
    return '(읽지 않음 $count)';
  }

  @override
  String raiFunctionsHeadEmoji(String keyword) {
    return '이모지 \'$keyword\'';
  }

  @override
  String get raiFunctionsUnfollowed => '팔로우를 해제했습니다';

  @override
  String get raiFunctionsFollowRequested => '팔로우를 요청했습니다';

  @override
  String get raiFunctionsFollowed => '팔로우했습니다';

  @override
  String get raiFunctionsListUserArgs => 'list=와 user=를 지정하세요';

  @override
  String get raiFunctionsListAdded => '리스트에 추가했습니다';

  @override
  String get raiFunctionsListRemoved => '리스트에서 제외했습니다';

  @override
  String get raiFunctionsMissingName => '이름(name=)이 없습니다';

  @override
  String raiFunctionsListCreated(String name, String id) {
    return '리스트 \'$name\'을(를) 만들었습니다 [$id]';
  }

  @override
  String get raiFunctionsClipPostArgs => 'clip=과 post=를 지정하세요';

  @override
  String get raiFunctionsClipAdded => '클립에 추가했습니다';

  @override
  String get raiFunctionsClipRemoved => '클립에서 제외했습니다';

  @override
  String raiFunctionsClipCreated(String name, String id) {
    return '클립 \'$name\'을(를) 만들었습니다 [$id]';
  }

  @override
  String get raiFunctionsAreaKeyArgs => 'area=와 key=를 지정하세요';

  @override
  String raiFunctionsSettingsPageMissing(String area) {
    return '설정 페이지 \'$area\'가 없습니다';
  }

  @override
  String get raiFunctionsAreaKeyValueArgs => 'area=, key=, value=를 지정하세요';

  @override
  String raiFunctionsSettingBadValue(String key, String value, String current) {
    return '\'$key\'에 \'$value\'을(를) 넣을 수 없습니다(현재 값: $current)';
  }

  @override
  String raiFunctionsSettingSet(String area, String key, String value) {
    return '$area.$key을(를) $value(으)로 설정했습니다';
  }

  @override
  String get raiFunctionsMissingText => '본문(text=)이 없습니다';

  @override
  String get raiFunctionsMissingRoom => '룸 id(room=)가 없습니다';

  @override
  String raiFunctionsDmRoomMissing(String id) {
    return 'DM 룸 $id가 없습니다';
  }

  @override
  String raiFunctionsComposeFilled(String target) {
    return '$target 초안을 작성 화면에 넣었습니다(전송하지 않았습니다)';
  }

  @override
  String raiFunctionsFeedNotFound(String feed) {
    return '피드 \'$feed\'를 찾을 수 없습니다';
  }

  @override
  String raiFunctionsFeedSaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '\'$name\'을(를) 저장했습니다(저장됨 $count개)',
    );
    return '$_temp0';
  }

  @override
  String raiFunctionsFeedUnsaved(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '\'$name\'을(를) 저장에서 제외했습니다(저장됨 $count개)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsNoBluesky => 'Bluesky 계정이 없습니다(커스텀 피드는 Bluesky 전용)';

  @override
  String raiFunctionsFeedAlreadyHome(String name) {
    return '\'$name\'은(는) 이미 홈 타임라인에 들어 있습니다';
  }

  @override
  String raiFunctionsFeedAddedHome(String name, String account) {
    return '\'$name\'($account)을(를) 홈 타임라인에 추가했습니다';
  }

  @override
  String get raiFunctionsNotLoggedInRasq => 'RASQ 계정에 로그인하지 않았습니다';

  @override
  String get raiFunctionsRasqListMine => '내 리스트';

  @override
  String get raiFunctionsRasqListUnfetchable => '가져올 수 없음';

  @override
  String get raiFunctionsRasqListFollowing => '팔로잉';

  @override
  String raiFunctionsRasqListLine(String name, int count, String state) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name($count명 · $state)',
    );
    return '$_temp0';
  }

  @override
  String get raiFunctionsHeadRasqLists => 'RASQ 리스트';

  @override
  String get raiFunctionsMissingListArg => '리스트(list=)가 없습니다';

  @override
  String raiFunctionsRasqListNotFound(String query) {
    return 'RASQ 리스트 \'$query\'를 찾을 수 없습니다';
  }

  @override
  String get raiFunctionsMissingWord => '단어(word=)가 없습니다';

  @override
  String get raiFunctionsNotLoggedIn => '로그인하지 않았습니다';

  @override
  String raiFunctionsWordExcludeAlready(String word) {
    return '\'$word\' 제외는 이미 설정되어 있습니다';
  }

  @override
  String raiFunctionsWordIncludeAlready(String word) {
    return '\'$word\' 필터는 이미 설정되어 있습니다';
  }

  @override
  String raiFunctionsWordExcluded(String word, String scope) {
    return '\'$word\'를 포함한 게시물을 $scope 타임라인에서 제외하도록 설정했습니다';
  }

  @override
  String raiFunctionsWordIncluded(String word, String scope) {
    return '\'$word\'를 포함한 게시물만 $scope 타임라인에 표시하도록 설정했습니다';
  }

  @override
  String get raiFunctionsFeedKindLabel => '피드';

  @override
  String get raiFunctionsHeadFeedTimeline => '피드 타임라인';

  @override
  String raiFunctionsPageList(String name, String id) {
    return '리스트 $name [$id]';
  }

  @override
  String raiFunctionsPageFeed(String name, String uri) {
    return '피드 $name [$uri]';
  }

  @override
  String get raiFunctionsHeadListsPage => '리스트 페이지';

  @override
  String get raiFunctionsHeadNotificationsPage => '알림';

  @override
  String get raiFunctionsHeadHomeTimeline => '홈 타임라인';

  @override
  String get raiFunctionsMissingSource => '가져올 소스(source=)가 없습니다';

  @override
  String raiFunctionsSeedNoPosts(String label) {
    return '\'$label\'에 게시물이 없어 특징어를 추출할 수 없습니다';
  }

  @override
  String raiFunctionsSeedNoWords(String label) {
    return '\'$label\'에서 특징어를 추출하지 못했습니다';
  }

  @override
  String get raiFunctionsSeedWordSeparator => ', ';

  @override
  String raiFunctionsSeedAdded(String label, String words) {
    return '\'$label\'의 특징어($words)를 트렌드 성향(좋아하는 장르)에 추가했습니다';
  }

  @override
  String get raiFunctionsMissingQuery => '검색어(q=)가 없습니다';

  @override
  String raiFunctionsHeadWeb(String query) {
    return '웹 \'$query\'';
  }

  @override
  String get raiFunctionsNotAutomatableMark => '(자동화 불가)';

  @override
  String get raiFunctionsHeadActions => '액션';

  @override
  String get raiModelsTitle => '모델';

  @override
  String get raiModelsClose => '닫기';

  @override
  String get raiModelsRamUnknown => 'RAM: 알 수 없음';

  @override
  String raiModelsRamFree(String gb) {
    return '(여유 $gb GB)';
  }

  @override
  String raiModelsCaption(String codename, String ram) {
    return '$codename = 이 기기에서 실행되는 모델. $ram';
  }

  @override
  String raiModelsCaptionDetail(String codename, String label, String ram) {
    return '$codename = 기기 내에서 실행되는 모델($label). $ram';
  }

  @override
  String get raiModelsSectionLocal => '로컬';

  @override
  String get raiModelsSectionEmbedding => 'RAi 검색 및 게시물 임베딩';

  @override
  String get raiModelsPostVisionReady => '관련 TL과 TL 알고리즘에서 게시물 이미지도 비교합니다';

  @override
  String get raiModelsPostVisionIdle =>
      '관련 TL과 TL 알고리즘에서 게시물 본문뿐 아니라 이미지도 비교할 수 있게 됩니다(문장 모델도 설치해 주세요)';

  @override
  String get raiModelsSectionEmoji => '이모지 이미지 검색(둘 다 필요합니다)';

  @override
  String get raiModelsEmojiTextReady => '입력한 문장으로 이모지 그림을 찾을 수 있습니다';

  @override
  String get raiModelsEmojiTextIdle =>
      '이모지 그림을 의미로 찾을 수 있게 됩니다(이미지 쪽도 설치해 주세요)';

  @override
  String get raiModelsEmojiVisionReady =>
      '이모지 그림을 백그라운드에서 조금씩 읽어 들입니다(서버마다 1회)';

  @override
  String get raiModelsEmojiVisionIdle => '이름에 의미가 없는 이모지도 그림 내용으로 찾을 수 있게 됩니다';

  @override
  String get raiModelsSectionCloud => '클라우드(기기에서 답할 수 없을 때)';

  @override
  String get raiModelsCompletionCaption => '완수율 = 안내나 답변이 끝까지 잘 된 비율입니다.';

  @override
  String get raiModelsCompletionCaptionDetail =>
      '완수율 = 조작 안내 / 답변이 끝까지 성립한 비율의 집계(35B 미만 모델만 집계, 데모에서는 \'-%\').';

  @override
  String get raiModelsRateExcluded => '집계 제외';

  @override
  String get raiModelsNotConnected => '미연결';

  @override
  String get raiModelsPhaseNotInstalled => '다운로드 안 됨';

  @override
  String raiModelsPhaseDownloading(int percent) {
    return '다운로드 중 $percent%';
  }

  @override
  String get raiModelsPhaseReady => '준비 완료';

  @override
  String get raiModelsPhaseReadyBundled => '준비 완료(동봉)';

  @override
  String get raiModelsPhaseLoading => '불러오는 중';

  @override
  String get raiModelsPhaseGenerating => '생성 중';

  @override
  String get raiModelsPhaseUnavailable => '사용할 수 없음';

  @override
  String get raiModelsPillCloud => '클라우드';

  @override
  String get raiModelsPillLocal => '로컬';

  @override
  String raiModelsCloudLine(String label, String params) {
    return '$label · ${params}B · 클라우드';
  }

  @override
  String raiModelsCompletionRate(String rate) {
    return '완수율 $rate';
  }

  @override
  String get raiModelsMemoryNotNeeded => '메모리: 기기 불필요';

  @override
  String raiModelsMemory(String verdict) {
    return '메모리: $verdict';
  }

  @override
  String get raiModelsUse => '사용';

  @override
  String get raiModelsExtract => '풀기(동봉)';

  @override
  String get raiModelsDownload => '다운로드';

  @override
  String get raiModelsRelease => '메모리 해제';

  @override
  String get raiModelsDeleteTitle => '모델을 삭제할까요?';

  @override
  String raiModelsDeleteMessage(String file) {
    return '$file을(를) 기기에서 지웁니다.';
  }

  @override
  String get raiModelsDelete => '삭제';

  @override
  String get raiModelsCancel => '취소';

  @override
  String raiModelsEmbeddingLine(String file, int size, int dims) {
    return 'onnxruntime · $file · 약 $size MB · $dims차원';
  }

  @override
  String get raiModelsSearchSemantic => '의미의 유사성으로 찾습니다';

  @override
  String raiModelsSearchSemanticDetail(String label) {
    return '검색: $label(의미로 찾기)';
  }

  @override
  String get raiModelsSearchNgram => '현재는 단어 일치로 찾습니다. 다운로드하면 바꿔 말하기에도 강해집니다';

  @override
  String get raiModelsSearchNgramDetail =>
      '검색: n-gram 대체(단어 일치로 찾기. 다운로드하면 바꿔 말하기에도 강해짐)';

  @override
  String get raiModelsServerTitle => '로컬 추론 서버';

  @override
  String get raiModelsServerConfigured => '접속 대상 있음';

  @override
  String get raiModelsServerNotConfigured => '미설정';

  @override
  String get raiModelsServerCaption => '기기의 모델이 답하지 못할 때 여기에 묻습니다.';

  @override
  String get raiModelsServerCaptionDetail =>
      'OpenAI 호환 채팅 API(llama-server / vLLM 등). 기기 내 모델이 실패 / 무응답일 때 질문과 가까운 레퍼런스를 붙여 전달합니다.';

  @override
  String get raiModelsServerModelHint => '모델 이름(생략 가능)';

  @override
  String get raiModelsRamOk => '동작 가능';

  @override
  String get raiModelsRamTight => '빠듯함';

  @override
  String get raiModelsRamNo => '메모리 부족';

  @override
  String get raiModelsRamUnknownVerdict => '알 수 없음';

  @override
  String get raiModelsFallUpNotConnected => '폴업 대상(서버 측)이 연결되어 있지 않습니다';

  @override
  String raiModelsServerHttpError(int status) {
    return '추론 서버 HTTP $status';
  }

  @override
  String get raiModelsServerNoReply => '추론 서버에서 응답이 없었습니다';

  @override
  String raiModelsServerUnreachable(String error) {
    return '추론 서버에 연결할 수 없습니다: $error';
  }

  @override
  String get raiModelsLlmUnavailableHere => '이 환경에서는 기기 내 모델을 사용할 수 없습니다';

  @override
  String raiModelsLlamaFetching(String tag) {
    return 'llama.cpp 런타임($tag)을 가져오는 중';
  }

  @override
  String get raiModelsLlamaMissingIos =>
      'llama.cpp가 포함되어 있지 않습니다(Runner에 llama.xcframework 추가)';

  @override
  String get raiModelsLlamaMissing => 'llama.cpp 라이브러리가 없습니다';

  @override
  String raiModelsLlamaFetchFailed(int status) {
    return 'llama.cpp 런타임을 가져올 수 없습니다(HTTP $status)';
  }

  @override
  String raiModelsStateCheckFailed(String error) {
    return '모델 상태를 확인할 수 없습니다: $error';
  }

  @override
  String get raiModelsExtracting => '동봉 모델을 푸는 중';

  @override
  String get raiModelsExtractTooLarge => '이 기기에서는 동봉 모델을 풀 수 없습니다(다운로드해 주세요)';

  @override
  String raiModelsExtractFailed(String error) {
    return '풀기에 실패했습니다: $error';
  }

  @override
  String raiModelsDownloadFailed(String error) {
    return '다운로드에 실패했습니다: $error';
  }

  @override
  String raiModelsNotDownloaded(String codename) {
    return '기기 내 모델($codename)이 아직 다운로드되지 않았습니다';
  }

  @override
  String get raiModelsDeviceUnavailable => '기기 내 모델을 사용할 수 없습니다';

  @override
  String raiModelsFileMissing(String path) {
    return '모델 파일이 없습니다: $path';
  }

  @override
  String get raiModelsTimeoutFirstToken => '기기 내 모델이 30초 동안 응답하지 않았습니다';

  @override
  String get raiModelsTimeoutOverall => '기기 내 모델의 응답이 너무 길어 중단했습니다';

  @override
  String get raiModelsOnlyThinking => '기기 내 모델에서 응답이 없었습니다(사고만 하고 끝났을 가능성)';

  @override
  String raiModelsGenerateFailed(String error) {
    return '생성에 실패했습니다: $error';
  }

  @override
  String get raiModelsHintSystemPolicy =>
      '\'system policy\' = 샌드박스 / 라이브러리 검증에서 거부됨. Debug entitlements(app-sandbox=false, disable-library-validation)로 다시 빌드해 주세요';

  @override
  String get raiModelsHintGatekeeper =>
      'Gatekeeper에 막힌 경우: \'시스템 설정 > 개인정보 보호 및 보안\'에서 허용하거나, Application Support/llama_cpp의 dylib에 xattr -dr com.apple.quarantine을 실행해 주세요';

  @override
  String raiModelsLoadFailedLlama(String error) {
    return '모델을 불러올 수 없습니다(llama.cpp): $error';
  }

  @override
  String raiModelsLoadFailed(String error) {
    return '모델을 불러올 수 없습니다: $error';
  }

  @override
  String get raiModelsEmbeddingRasqText => 'RASQ MiniLM(문장)';

  @override
  String get raiModelsEmbeddingMiniLmL12 => 'MiniLM-L12 다국어(paraphrase, int8)';

  @override
  String get raiModelsEmbeddingRasqVision => 'RASQ MobileNet(게시물 이미지)';

  @override
  String get raiModelsEmbeddingSiglipText => 'SigLIP2 base(텍스트 타워·int8)';

  @override
  String get raiModelsEmbeddingSiglipVision => 'SigLIP2 base(이미지 측·int8)';

  @override
  String raiModelsEmbeddingFailed(String message) {
    return '실패: $message';
  }

  @override
  String get raiModelsEmbeddingUnavailableHere =>
      '이 환경에서는 기기 내 임베딩 모델을 사용할 수 없습니다';

  @override
  String get raiModelsChecksumMismatch => '모델 파일이 손상되었습니다(sha256이 다릅니다)';

  @override
  String get raiModelsSizeMismatch => '모델 파일이 중간에 잘렸습니다';

  @override
  String get raiModelsCentralNotConfigured => 'RASQ 서버 연결 주소가 설정되지 않았습니다';

  @override
  String raiModelsLoadFailedOnnx(String error) {
    return '모델을 불러올 수 없습니다(onnxruntime): $error';
  }

  @override
  String get raiModelsWebDisabled => '웹 검색은 아직 사용할 수 없습니다';

  @override
  String get raiModelsWebNoKey => 'Brave Search 키가 설정되어 있지 않습니다';

  @override
  String get raiModelsWebAnswerTitle => '웹 답변';

  @override
  String raiModelsWebFailed(String error) {
    return '검색 실패: $error';
  }

  @override
  String get raiModelsNoteNotInstalled => '미DL';

  @override
  String get regionHeading => '거주 지역';

  @override
  String get regionCaption => '거주하는 국가 또는 지역을 선택해 주세요(자기 신고). 미국의 경우 주도 선택합니다.';

  @override
  String get regionChoose => '선택해 주세요';

  @override
  String regionCountryAndState(String country, String state) {
    return '$country · $state';
  }

  @override
  String get regionPickerTitle => '거주 지역 선택';

  @override
  String get regionStatePickerTitle => '주 선택';

  @override
  String get regionSearchHint => '국가 또는 지역 이름으로 검색';

  @override
  String get regionStateSearchHint => '주 이름으로 검색';

  @override
  String get regionNoMatch => '찾을 수 없습니다';

  @override
  String get regionUnavailableBadge => '제공 안 함';

  @override
  String get regionUnavailableTitle => '현재 거주 지역에서는 RASQ를 제공하지 않습니다';

  @override
  String get regionUnavailableBody =>
      'RASQ는 현재 일부 지역에서만 제공됩니다. 거주 지역에서는 RASQ 계정을 만들 수 없습니다. 제공 지역은 앞으로 바뀔 수 있습니다.';

  @override
  String regionUnavailableBodyWith(String region) {
    return 'RASQ는 현재 일부 지역에서만 제공됩니다. $region에서는 RASQ 계정을 만들 수 없습니다. 제공 지역은 앞으로 바뀔 수 있습니다.';
  }

  @override
  String get regionUnavailableBack => '뒤로';

  @override
  String get regionRequiredError => '거주 지역을 선택한 후 다시 시도해 주세요.';

  @override
  String get relationalPostTitle => '게시물';

  @override
  String relationalEventTitle(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$name 외 $count명',
    );
    return '$_temp0';
  }

  @override
  String relationalEventCaption(int posts, int members) {
    String _temp0 = intl.Intl.pluralLogic(
      posts,
      locale: localeName,
      other: '$posts개',
    );
    String _temp1 = intl.Intl.pluralLogic(
      members,
      locale: localeName,
      other: '$members명',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String relationalEventPostCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String relationalDurationHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간',
    );
    return '$_temp0';
  }

  @override
  String relationalDurationHoursMinutes(int hours, int minutes) {
    return '$hours시간 $minutes분';
  }

  @override
  String relationalDurationMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes분',
    );
    return '$_temp0';
  }

  @override
  String relationalLookback(String duration) {
    return '$duration 전 대화까지 표시 중';
  }

  @override
  String get relationalLookbackReset => '되돌리기';

  @override
  String get relationalHeader => '대화별로 묶어서 표시하고 있습니다';

  @override
  String relationalHeaderDetail(int bias, int maxMinutes) {
    return '묶임 정도 $bias / 대화 템포에 따라 최대 $maxMinutes분 후 가라앉음';
  }

  @override
  String get relationalTuningTitle => '릴레이셔널 타임라인 조정';

  @override
  String get relationalRetry => '새로고침';

  @override
  String get relationalEmptyTitle => '지금 진행 중인 대화가 없습니다';

  @override
  String get relationalEmptyHint =>
      '팔로우 중인 사람들의 대화가 여기에 묶여서 표시됩니다. 당기면 지난 대화도 볼 수 있습니다';

  @override
  String get relationalTuningCancel => '취소';

  @override
  String get relationalTuningConfirm => '확인';

  @override
  String get relationalAdvanced => '고급 설정';

  @override
  String get relationalSectionLinking => '묶음 판정';

  @override
  String get relationalCandidateWindow => '후보 윈도';

  @override
  String get relationalCandidateWindowSubtitle => '부모 후보를 찾는 최근 범위';

  @override
  String relationalMinutesValue(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes분',
    );
    return '$_temp0';
  }

  @override
  String relationalSecondsValue(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds초',
    );
    return '$_temp0';
  }

  @override
  String get relationalSectionWeightsPlain => '가중치(일반 게시물)';

  @override
  String get relationalWeightContent => '내용 유사도';

  @override
  String get relationalWeightEntity => '엔티티 일치';

  @override
  String get relationalWeightTime => '시간 감쇠';

  @override
  String get relationalWeightAffinity => '쌍 친밀도';

  @override
  String get relationalWeightTurn => '발화 교대';

  @override
  String get relationalWeightAnchor => '앵커';

  @override
  String get relationalSectionFlatBonus => '고정 가점';

  @override
  String get relationalWeightCommunityPrior => '커뮤니티 사전 분포 ±';

  @override
  String get relationalSectionLifecycle => '라이프사이클';

  @override
  String get relationalTentativeHold => '임시 ROOT 보류';

  @override
  String get relationalTentativeHoldSubtitle => '새 화제로 확정하기까지의 보류 시간';

  @override
  String get relationalResetDefaults => '기본값으로 되돌리기';

  @override
  String get relationalLinkBias => '묶임 정도';

  @override
  String get relationalLinkBiasSubtitle => '낮을수록 넓게 묶음(임곗값은 커뮤니티별로 자동 조정)';

  @override
  String get relationalTauSubtitle => '클수록 시간이 떨어진 게시물도 쉽게 연결됨(τ)';

  @override
  String get relationalSectionWeights => '가중치';

  @override
  String get relationalSimilarity => '유사성';

  @override
  String get relationalSimilaritySubtitle => '내용 유사도 + 엔티티 일치(세부 항목은 고급 설정)';

  @override
  String get relationalCloseness => '친밀도';

  @override
  String get relationalClosenessSubtitle => '쌍 친밀도 + 발화 교대(세부 항목은 고급 설정)';

  @override
  String get relationalSectionExtra => '추가 판정';

  @override
  String get relationalHardAnchor => '하드 앵커(URL/인용 대상)';

  @override
  String get relationalReactive => '반응 표현(\'그니까\', \'인정\' 등)';

  @override
  String get relationalTtlSubtitle =>
      '대화가 가라앉기까지의 시간. 게시 간격에 따라 이 범위 안에서 자동 조정';

  @override
  String relationalTtlValue(int min, int max) {
    return '$min~$max분';
  }

  @override
  String get searchChildSafePostsBlocked => '보호자가 게시물 검색을 막아 두었습니다';

  @override
  String get searchChildSafeTrendBlocked => '보호자가 트렌드를 막아 두었습니다';

  @override
  String get searchTrendSettings => '트렌드 설정';

  @override
  String get searchTrendCustomize => '트렌드 페이지 맞춤 설정';

  @override
  String get searchTrendPage => '트렌드 페이지';

  @override
  String get searchTrendMenu => '메뉴';

  @override
  String get searchHint => '검색';

  @override
  String get searchSettings => '검색 설정';

  @override
  String get searchSettingsTendency => '검색 결과의 성향/자극성';

  @override
  String get searchSettingsTrendPlugins => '트렌드 플러그인 설정';

  @override
  String get searchSettingsCacheNetwork => '캐시 네트워크 설정';

  @override
  String get searchSettingsComingSoon => '이 설정은 준비 중입니다.';

  @override
  String get searchSortRelevance => '관련순';

  @override
  String get searchSortNewest => '최신순';

  @override
  String get searchSortOldest => '오래된 순';

  @override
  String get searchSortReactions => '리액션 많은 순';

  @override
  String get searchPeriodAll => '전체';

  @override
  String get searchPeriodDay => '24시간';

  @override
  String get searchPeriodWeek => '1주';

  @override
  String get searchPeriodMonth => '1개월';

  @override
  String get searchPeriodChip => '기간';

  @override
  String get searchAgoJustNow => '방금';

  @override
  String searchAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분 전',
    );
    return '$_temp0';
  }

  @override
  String searchAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간 전',
    );
    return '$_temp0';
  }

  @override
  String searchAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일 전',
    );
    return '$_temp0';
  }

  @override
  String get serversOpen => '서버 열기';

  @override
  String serversUsers(String count) {
    return '$count명';
  }

  @override
  String serversPosts(String count) {
    return '게시물 $count개';
  }

  @override
  String get serversRegistrationOpen => '가입 가능';

  @override
  String get serversRegistrationClosed => '초대제 / 가입 중단';

  @override
  String get serversStatsSeparator => ' · ';

  @override
  String get serversRaiTitle => 'RAi가 분석한 사용자 경향';

  @override
  String serversRaiSource(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '클라우드 RAi가 공개 게시물 $count개를 바탕으로 정리했습니다',
    );
    return '$_temp0';
  }

  @override
  String get serversInfoTitle => '서버 정보';

  @override
  String serversInfoUnavailable(String host) {
    return '$host은(는) 서버 정보를 제공하지 않습니다(인스턴스가 없는 서비스이거나 가져올 수 없었습니다)';
  }

  @override
  String serversCountHundredMillions(String value) {
    return '$value억';
  }

  @override
  String serversCountTenThousands(String value) {
    return '$value만';
  }

  @override
  String get sessionUnnamedDevice => '이름 없는 기기';

  @override
  String get sessionShareAskFirstTitle => '액세스 토큰을 공유해 SNS 계정에 한꺼번에 로그인할까요?';

  @override
  String sessionShareAskDeviceTitle(String device) {
    return '새 기기($device)에도 SNS 액세스 토큰을 공유할까요?';
  }

  @override
  String sessionShareAskFirstMessage(String devices) {
    return '새 기기($devices)에서 이 RASQ 계정에 로그인했습니다. \'예\'를 선택하면 SNS 액세스 토큰을 기기 간에 종단간 암호화(E2E)하여 공유하고, 새 기기도 SNS 계정에 로그인합니다. RASQ 서버는 내용을 읽을 수 없습니다. 나중에 \'계정 보안\'에서 바꿀 수 있습니다.';
  }

  @override
  String sessionShareAskFirstMessageHandle(String devices, String handle) {
    return '새 기기($devices)에서 RASQ 계정 @$handle에 로그인했습니다. \'예\'를 선택하면 SNS 액세스 토큰을 기기 간에 종단간 암호화(E2E)하여 공유하고, 새 기기도 SNS 계정에 로그인합니다. RASQ 서버는 내용을 읽을 수 없습니다. 나중에 \'계정 보안\'에서 바꿀 수 있습니다.';
  }

  @override
  String get sessionShareAskDeviceMessage =>
      '새 기기에서 이 RASQ 계정에 로그인했습니다. 짐작 가는 바가 없다면 \'아니요\'를 선택하고 \'계정 보안\'에서 그 기기를 로그아웃시켜 주세요.';

  @override
  String sessionShareAskDeviceMessageHandle(String handle) {
    return '새 기기에서 RASQ 계정 @$handle에 로그인했습니다. 짐작 가는 바가 없다면 \'아니요\'를 선택하고 \'계정 보안\'에서 그 기기를 로그아웃시켜 주세요.';
  }

  @override
  String get sessionDeviceListSeparator => ', ';

  @override
  String get sessionShareYes => '예';

  @override
  String get sessionShareNo => '아니요';

  @override
  String sessionShareEmailApproved(String device) {
    return '이메일로 승인된 기기($device)에 SNS 액세스 토큰을 공유했습니다';
  }

  @override
  String sessionShareImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '공유된 액세스 토큰으로 SNS 계정에 한꺼번에 로그인했습니다($count개)',
    );
    return '$_temp0';
  }

  @override
  String get sessionLoginFailed => '로그인에 실패했습니다';

  @override
  String get sessionSanctionLight => '경미한 제한';

  @override
  String get sessionSanctionModerate => '중간 수준의 제한(발언 검열 지연)';

  @override
  String get sessionSanctionSevere => '중대한 제한(기능 정지)';

  @override
  String get sessionSanctionPermanent => '영구 정지';

  @override
  String get sessionSanctionNone => '제한 없음';

  @override
  String sessionSanctionBlocked(String feature) {
    return '계정 조치로 인해 $feature을(를) 이용할 수 없습니다.';
  }

  @override
  String sessionSanctionBlockedUntil(String feature, String until) {
    return '계정 조치로 인해 $feature을(를) 이용할 수 없습니다($until까지).';
  }

  @override
  String get sessionFeatureAstellJoin => 'ASTell 참여';

  @override
  String get sessionFeatureAstellCreate => 'ASTell 룸 만들기';

  @override
  String get sessionFeatureAstellShare => 'ASTell에서의 공유·채팅';

  @override
  String get sessionFeatureAstellStream => 'ASTell 화면 공유·방송';

  @override
  String get sessionFeatureStoreReview => '스토어 리뷰 작성';

  @override
  String get sessionFeatureAccountFollow => 'RASQ 계정 팔로우';

  @override
  String get sessionFeaturePost => '게시';

  @override
  String get sessionFeaturePostMedia => '미디어 포함 게시';

  @override
  String get sessionFeatureDm => 'DM';

  @override
  String get sessionFeatureReaction => '리액션';

  @override
  String get sessionCentralNotConfigured => 'RASQ Central 접속 대상이 설정되어 있지 않습니다';

  @override
  String get sessionLogoutSnsHeading => '이 RASQ 계정의 SNS 계정';

  @override
  String get sessionLogoutSnsLogout => 'SNS 계정도 로그아웃';

  @override
  String get sessionLogoutSnsLogoutSubtitle => '이 기기에서 SNS 로그인을 지웁니다';

  @override
  String get sessionLogoutSnsMoveToLocal => '\'이 기기만\'으로 옮기기';

  @override
  String get sessionLogoutSnsMoveToLocalSubtitle =>
      '\'이 기기만\' 계정으로 그대로 사용할 수 있습니다';

  @override
  String get sessionCancel => '취소';

  @override
  String get sessionChildSafeAddBlocked => '보호자가 SNS 계정 추가를 막아 두었습니다';

  @override
  String get sessionAccountKindLocal => '이 기기만';

  @override
  String get sessionAccountKindCentral => 'RASQ Central';

  @override
  String get sessionCarryThisAccount => '이 RASQ 계정';

  @override
  String get sessionCarrySemantics => '이 기기의 SNS 계정을 추가할까요?';

  @override
  String sessionCarryTitle(int count, String account) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '이 기기에서 열려 있던 계정 $count개를 $account에 추가할까요?',
    );
    return '$_temp0';
  }

  @override
  String sessionCarryMessage(String account) {
    return '추가한 계정은 $account의 SNS 계정이 되어 다른 기기와 Web 콘솔에도 표시됩니다. 추가하지 않은 계정은 \'이 기기만\'에 남습니다(나중에라도 $account로 SNS에 로그인하면 추가됩니다).';
  }

  @override
  String get sessionCarryInBundle => ' (이전에 이 RASQ 계정으로 연결한 것)';

  @override
  String get sessionCarryNone => '추가하지 않기';

  @override
  String sessionCarryAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '선택한 $count개 추가',
    );
    return '$_temp0';
  }

  @override
  String get settingsActionBarTitle => '플러그인 버튼';

  @override
  String get settingsActionBarBackTooltip => '뒤로';

  @override
  String get settingsActionBarBundleManual => '수동 배치(바의 (+)에서 추가하기 전에는 표시 안 됨)';

  @override
  String get settingsActionBarBundleAlone => '단독으로 맨 끝에';

  @override
  String settingsActionBarBundleInto(String label, String percent) {
    return '\'$label\' 묶음($percent%)';
  }

  @override
  String get settingsActionBarAutoOnTitle => '화면을 열 때 자동으로 켜기';

  @override
  String get settingsActionBarOn => '켬';

  @override
  String get settingsActionBarOff => '끔';

  @override
  String settingsActionBarAutoDefault(String state) {
    return '기본값($state)';
  }

  @override
  String settingsActionBarAutoDefaultDeclared(String state) {
    return '기본값($state, 플러그인 선언)';
  }

  @override
  String settingsActionBarAutoOverridden(String state) {
    return '설정에서 덮어씀(기본값은 $state)';
  }

  @override
  String get settingsActionBarEmptyCaption => '스토어에서 추가한 플러그인이 여기에 표시됩니다';

  @override
  String get settingsActionBarIntroCaption => '스위치를 끄면 모든 계정에서 표시되지 않습니다.';

  @override
  String get settingsActionBarIntroDetail =>
      '스위치는 기기 전체의 주 전원입니다(끄면 모든 계정·모든 화면에서 표시되지 않고 자동으로도 작동하지 않습니다). \'화면을 열 때 자동으로 켜기\'는 그 화면을 연 순간의 초기 상태입니다(화면 안에서 바꾼 값은 다음으로 이어지지 않습니다).';

  @override
  String get settingsActionBarPostTileHeader => '게시물 타일';

  @override
  String get settingsActionBarPostTileEmptyDetail =>
      'post.action을 선언한 플러그인이 여기에 표시됩니다(스토어에서 추가)';

  @override
  String get settingsActionBarViewerHeader => '전체 화면';

  @override
  String get settingsActionBarViewerEmptyDetail =>
      'viewer.overlay를 선언한 플러그인(QR 코드 인식 등)이 여기에 표시됩니다';

  @override
  String get settingsActionBarViewerPlacement => '전체 화면 액션 바의 ON / OFF 버튼';

  @override
  String get settingsActionBarMediaHeader => '편집 화면';

  @override
  String get settingsActionBarMediaEmptyDetail =>
      'composer.media를 선언한 플러그인이 여기에 표시됩니다';

  @override
  String settingsActionBarFilterPlacement(String placement) {
    return '필터 · $placement';
  }

  @override
  String get settingsActionBarComposerTextHeader => '작성기 본문';

  @override
  String get settingsActionBarComposerTextEmptyDetail =>
      'composer.text를 선언한 플러그인이 여기에 표시됩니다';

  @override
  String get settingsActionBarComposerTextPlacement =>
      '작성기 액션 바의 ON / OFF 버튼(길게 눌러 설정)';

  @override
  String get settingsActionBarTransformHeader => '게시물 가공(자동)';

  @override
  String get settingsActionBarTransformEmptyDetail =>
      'post.transform을 선언한 플러그인이 여기에 표시됩니다';

  @override
  String get settingsActionBarTransformPlacement => '표시 전에 본문을 가공(버튼 없음)';

  @override
  String settingsActionBarThisAccountHeader(String account) {
    return '이 계정($account)';
  }

  @override
  String get settingsActionBarNoAccount => '선택 안 됨';

  @override
  String get settingsActionBarThisAccountEmptyCaption => '이 계정에서 표시할지 여부';

  @override
  String get settingsActionBarThisAccountEmptyDetail =>
      '게시물 타일의 버튼을 이 계정에서 표시할지 여부';

  @override
  String settingsActionBarSlotSubtitle(String plugin, String tags) {
    return '$plugin · 태그: $tags';
  }

  @override
  String get settingsActionBarThresholdTitle => '묶음 임계값';

  @override
  String get settingsActionBarThresholdSubtitle => '비슷한 버튼을 묶는 정도';

  @override
  String get settingsActionBarThresholdDetail =>
      '태그 유사도가 이 값 이상이면 기존 버튼의 묶음에 들어갑니다';

  @override
  String get settingsActionBarEditButton => '액션 바 편집';

  @override
  String get settingsBackendTitle => 'RASQ 서버';

  @override
  String get settingsBackendErrorUnparseable =>
      '연결 주소를 해석할 수 없습니다. \'http://192.168.3.14:8080\'이나 \'https://central.example\' 형식으로 입력하세요.';

  @override
  String get settingsBackendSaved => '저장했습니다';

  @override
  String get settingsBackendErrorEnterUrl =>
      '연결 주소를 입력하세요(예: http://192.168.3.14:8080)';

  @override
  String get settingsBackendCentralNotCentralHint =>
      'Central 칸에는 ORGATE가 아닌 RASQ Central의 연결 주소를 입력하세요';

  @override
  String settingsBackendCentralConnectFailed(
    String url,
    String error,
    String hint,
  ) {
    return '연결할 수 없습니다($url) — $error$hint';
  }

  @override
  String settingsBackendCentralOk(String algorithm, String keyHead) {
    return '연결 OK — 서명 키 $algorithm $keyHead…';
  }

  @override
  String settingsBackendAccountLine(String handle, String displayName) {
    return 'RASQ 계정: @$handle ($displayName)';
  }

  @override
  String get settingsBackendAccountNotCreatedLine =>
      'RASQ 계정: 미생성(아래 \'RASQ 계정 열기\'에서 만들 수 있습니다)';

  @override
  String settingsBackendAccountLoadFailedLine(String error) {
    return 'RASQ 계정을 가져올 수 없습니다 — $error';
  }

  @override
  String get settingsBackendOrgateNotConfiguredLine =>
      'ORGATE: 미설정(RASQ 계정에 로그인할 수 없음)';

  @override
  String settingsBackendOrgateOk(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return 'ORGATE: 연결 OK — 토큰 공개 키 $_temp0';
  }

  @override
  String settingsBackendOrgateNoKeys(String url) {
    return 'ORGATE: 응답에 토큰 공개 키가 없습니다($url)';
  }

  @override
  String settingsBackendOrgateConnectFailed(String url, String error) {
    return 'ORGATE에 연결할 수 없습니다($url) — $error';
  }

  @override
  String get settingsBackendCaption =>
      'RASQ 계정과 스토어 서버의 연결 주소입니다. SNS 게시물과 타임라인은 여기를 거치지 않습니다.';

  @override
  String get settingsBackendCaptionDetail =>
      'RASQ Central은 공개·공유되는 것(프로필, 스토어, ASTell, 게시물, 리스트 등)의 서버이고, ORGATE는 본인만의 정보(로그인, 비밀번호, 이메일 주소)와 Mastodon 등의 로그인(OAuth 브로커) 서버입니다. RASQ 계정 로그인은 ORGATE에서 하며, 그 토큰을 Central에도 사용합니다. SNS 게시물과 타임라인은 어느 쪽도 거치지 않고 플러그인이 각 인스턴스에 직접 연결합니다.';

  @override
  String get settingsBackendCentralLabel =>
      'RASQ Central 연결 주소(비우면 ORGATE를 사용)';

  @override
  String get settingsBackendOrgateLabel => 'ORGATE(로그인·본인 정보) 연결 주소';

  @override
  String get settingsBackendSaveButton => '저장';

  @override
  String get settingsBackendTestButton => '연결 테스트';

  @override
  String get settingsBackendCentralDisconnected =>
      'Central: 연결 안 됨(RASQ 계정을 만들 수 없음)';

  @override
  String get settingsBackendCentralDisconnectedDetail =>
      'Central: 연결 안 됨 — 플러그인 스토어는 포함된 것만, RASQ 계정은 만들 수 없습니다(이 기기만).';

  @override
  String get settingsBackendOrgateDisconnected =>
      'ORGATE: 연결 안 됨(RASQ 계정에 로그인할 수 없음)';

  @override
  String get settingsBackendTestEndpointsSection => '테스트용 연결 주소';

  @override
  String get settingsBackendTestEndpointsTitle =>
      '더미 SNS와 데모 Central / ORGATE 사용';

  @override
  String get settingsBackendTestEndpointsSubtitle => '미리보기 녹화용';

  @override
  String settingsBackendTestEndpointsDetail(
    String misskeyHost,
    String mastodonHost,
    String blueskyHost,
    String centralPort,
    String orgatePort,
  ) {
    return '미리보기 녹화용. Misskey / Mastodon / Bluesky의 $misskeyHost / $mastodonHost / $blueskyHost를 이 주소의 더미로 향하게 하고, Central(:$centralPort)과 ORGATE(:$orgatePort)도 전환합니다';
  }

  @override
  String get settingsBackendTestAddressLabel =>
      '더미 환경 주소(같은 기기면 127.0.0.1, 다른 기기면 그 IP)';

  @override
  String get settingsBackendTestCaption => 'SNS 로그인 화면에서 서버에 위의 호스트 이름을 입력하세요.';

  @override
  String get settingsBackendTestCaptionDetail =>
      '각 SNS의 로그인 화면에서 서버에 위의 호스트 이름을 입력합니다(허가 페이지는 자동으로 통과, Bluesky의 ID / 비밀번호는 아무거나 가능). RASQ 계정은 계정 로그인에서. 전환하면 이미 로그인한 SNS는 다음 불러오기부터 새 연결 주소를 사용합니다.';

  @override
  String get settingsBackendAccountSection => 'RASQ 계정';

  @override
  String settingsBackendAccountLoadError(String error) {
    return '계정을 가져올 수 없습니다: $error';
  }

  @override
  String get settingsBackendNoServer => '연결 주소가 설정되지 않았습니다.';

  @override
  String get settingsBackendAccountNotCreated => 'RASQ 계정이 아직 없습니다.';

  @override
  String get settingsBackendOpenAccountButton => 'RASQ 계정 열기';

  @override
  String get settingsBackendAccountDeviceOnly =>
      '이 기기에서만 유효한 계정입니다. 핸들과 표시 이름은 프로필 편집에서 변경할 수 있습니다.';

  @override
  String get settingsBackendBundleSection => '계정 번들';

  @override
  String get settingsBackendBundleCaption =>
      '묶을 때 보내는 것은 SNS 계정 목록뿐입니다. 로그인 키는 기기 간 공유, 웹 버전, 계정 페이지의 게시물 표시를 선택했을 때만 보냅니다.';

  @override
  String get settingsBackendBundleCaptionDetail =>
      '묶을 때 서버에 보내는 것은 SNS 종류, 서버, 계정, 표시 이름뿐입니다. 액세스 토큰은 기기 간 공유(E2E, 서버는 읽을 수 없음), 웹 버전 보관함(서버 키로 암호화, 서버가 복호화 가능), 계정 페이지의 게시물 표시(위와 같음)를 선택했을 때만 보냅니다(개인정보 처리방침 제4항).';

  @override
  String get settingsBackendNoSessions => '로그인 중인 계정이 없습니다.';

  @override
  String get settingsColumnsTitle => '칼럼 너비';

  @override
  String get settingsColumnsIntroCaption =>
      '태블릿이나 PC 등 넓은 화면에서 좌우 칼럼의 너비를 정합니다.';

  @override
  String get settingsColumnsIntroDetail =>
      '넓은 화면(태블릿 / 데스크톱 / 웹)에서 소형 칼럼(검색이나 페이지를 연 쪽)과 대형 칼럼(연 페이지)의 너비 비율을 정합니다.';

  @override
  String get settingsColumnsSplitHeader => '소형 / 대형 칼럼 비율';

  @override
  String settingsColumnsSplitDefault(String hint) {
    return '$hint(기본값)';
  }

  @override
  String get settingsColumnsLargeWidthLabel => '대형 칼럼 너비';

  @override
  String get settingsColumnsSmallWidthLabel => '소형 칼럼 너비';

  @override
  String get settingsColumnsShrinkCaption => '화면에 들어가지 않으면 자동으로 줄입니다.';

  @override
  String settingsColumnsShrinkDetail(String minWidth) {
    return '화면이 좁아 들어가지 않으면 다른 쪽 칼럼을 $minWidth px 이상 남기고, 소형 칼럼이 대형 칼럼보다 넓어지지 않도록 줄입니다.';
  }

  @override
  String get settingsColumnsSwingInColumnTitle => 'Swing을 오른쪽 칼럼에서 열기';

  @override
  String get settingsColumnsSwingInColumnSubtitle =>
      '끄면 전체 화면으로 엽니다(처음에는 켜짐. 전체 화면을 지정한 플러그인의 Swing은 항상 전체 화면)';

  @override
  String get settingsColumnsCurrentHeader => '현재 화면에서의 너비';

  @override
  String settingsColumnsPreviewWidths(String small, String large) {
    return '소형 $small px / 대형 $large px';
  }

  @override
  String get settingsColumnsNarrowCaption => '현재 화면이 좁아서 칼럼이 하나입니다.';

  @override
  String settingsColumnsNarrowDetail(String breakpoint) {
    return '현재 화면이 좁아서 칼럼을 하나만 표시합니다($breakpoint px 이상이면 소형 / 대형 칼럼으로 나뉩니다).';
  }

  @override
  String get settingsColumnsPreviewSmall => '소형';

  @override
  String get settingsColumnsPreviewLarge => '대형';

  @override
  String get settingsCommonSeparator => ' · ';

  @override
  String settingsCommonBullet(String text) {
    return '• $text';
  }

  @override
  String settingsCommonRange(int min, int max) {
    return '$min~$max';
  }

  @override
  String get settingsComposerTitle => '게시물 작성기';

  @override
  String get settingsComposerAutoAccountTitle => '게시 계정 자동 선택';

  @override
  String get settingsComposerAutoAccountSubtitle =>
      '초안에 맞는 계정으로 게시 대상을 자동 전환합니다';

  @override
  String get settingsComposerAutoAccountDetail =>
      '초안 내용이 게시 대상 필터에 맞는 계정으로 게시 대상을 자동 전환합니다(수동 선택이 항상 우선)';

  @override
  String get settingsComposerRasqLinkedTitle => 'RASQ 계정에도 연동 게시';

  @override
  String get settingsComposerRasqLinkedSubtitle =>
      '여러 계정에 게시할 때 RASQ 계정도 선택할 수 있습니다';

  @override
  String get settingsComposerRasqLinkedDetail =>
      '복수 선택 모드에서 RASQ 계정 행도 선택할 수 있게 됩니다(일반 게시 / 노드 연동). 전달 방식과 필터는 \'게시 대상 맞춤 설정\'의 RASQ 탭에서 정합니다. RASQ 제한(1000자 / 첨부 6개 / 투표 6개 / 게시물 3개)을 넘는 게시물은 RASQ로 보내지지 않습니다';

  @override
  String get settingsEmomTitle => 'EmoM 임계값';

  @override
  String get settingsEmomBandLow => '보수적 — 운영자가 제한한 트렌드를 일찍 숨깁니다';

  @override
  String get settingsEmomBandMiddle => '보통';

  @override
  String get settingsEmomBandHigh => '넓게 — 운영자가 강하게 제한한 트렌드만 숨깁니다';

  @override
  String get settingsEmomStatusSending => '보내는 중…';

  @override
  String get settingsEmomStatusNoAccount =>
      'RASQ 계정으로 로그인하면 공개할 수 있습니다(이 기기에서는 사용할 수 있습니다)';

  @override
  String get settingsEmomStatusFailed =>
      '보내지 못했습니다. 다음에 열 때(또는 트렌드를 다시 불러올 때) 다시 보냅니다';

  @override
  String settingsEmomStatusDisclosed(String value) {
    return '공개 중(값 $value)';
  }

  @override
  String get settingsEmomStatusPending => '아직 전달되지 않았습니다';

  @override
  String get settingsEmomStatusNotDisclosed => '공개하지 않음';

  @override
  String get settingsEmomIntro =>
      'EmoM은 게시물과 트렌드의 감정 강도와 자극 강도를 추정하는 RASQ의 모델입니다(준비 중). 현재 이 임계값은 RASQ 운영자가 신고를 확인하고 트렌드를 제한할 때의 기준으로만 사용됩니다.';

  @override
  String get settingsEmomThresholdLabel => '임계값';

  @override
  String get settingsEmomScaleLow => '낮음(숨겨지기 쉬움)';

  @override
  String get settingsEmomScaleHigh => '높음(숨겨지기 어려움)';

  @override
  String settingsEmomExplanation(String defaultValue) {
    return '임계값이 높을수록 자극이 강한 화제도 받아들이는 설정이며, 운영자가 제한한 트렌드가 잘 숨겨지지 않습니다. 낮을수록 제한된 트렌드를 일찍 숨깁니다. 기본값은 $defaultValue입니다.';
  }

  @override
  String get settingsEmomDiscloseTitle => '임계값 공개(제한 기준으로 사용)';

  @override
  String get settingsEmomDiscloseSubtitle =>
      '값만 RASQ 서버로 보냅니다. 운영자는 공개된 값을 모은 분포(어떤 값의 사람이 몇 명인지)만 사용하며, 회원님의 값을 개별적으로 보지 않습니다. 끄면 보낸 값을 삭제합니다.';

  @override
  String get settingsEmomRestrictionExplanation =>
      '운영자가 트렌드를 \'N%\'로 제한하면, 공개된 임계값이 낮은 쪽부터 약 N%의 사람에게 그 트렌드가 표시되지 않습니다. 공개하지 않아도 이 기기의 임계값으로 똑같이 판정합니다(임계값은 이 기기에 저장됩니다). \'모두에게 숨김\'으로 설정된 트렌드는 임계값과 관계없이 표시되지 않습니다. 숨겨진 트렌드는 검색의 트렌드 목록에 표시되지 않을 뿐입니다.';

  @override
  String get settingsHomeTitle => '모든 설정';

  @override
  String get settingsHomeSearchHint => '설정 및 조작 검색';

  @override
  String get settingsHomeSearchClear => '지우기';

  @override
  String get settingsHomeSearchError => '설정을 검색하지 못했습니다';

  @override
  String get settingsHomeSearchEmpty => '결과가 없습니다';

  @override
  String settingsHomeSearchEmptyHint(String query) {
    return '\'$query\'에 해당하는 설정이 없습니다. 다른 말로 찾거나 RAi에게 물어보세요';
  }

  @override
  String get settingsHomeSearchOperations => '조작 (RAi가 안내합니다)';

  @override
  String get settingsHomeOtherHeader => '기타 설정';

  @override
  String get settingsHomeComposer => '게시물 작성기';

  @override
  String get settingsHomeComposerKeywords => '게시 화면,초안';

  @override
  String get settingsHomeThemeKeywords => '테마,스킨,다크 모드,라이트,색상,글꼴';

  @override
  String get settingsHomeAccountImportant => '계정 중요 설정';

  @override
  String get settingsHomeAccountImportantSubtitle => '비밀번호 변경이나 계정 삭제는 웹에서';

  @override
  String get settingsHomeAccountImportantDetail =>
      '비밀번호 재설정이나 계정 삭제 등 비밀번호가 필요한 작업은 웹에서 합니다';

  @override
  String settingsHomeLogout(String handle) {
    return '@$handle에서 로그아웃';
  }

  @override
  String get settingsHomeLogoutConfirmTitle => '로그아웃할까요?';

  @override
  String get settingsHomeLogoutConfirmMessage => '이 계정의 플러그인 구성은 기기에 남습니다.';

  @override
  String get settingsHomeLogoutConfirm => '로그아웃';

  @override
  String get settingsHomeCancel => '취소';

  @override
  String get settingsHomeOk => '확인';

  @override
  String get settingsHomeGenericTitle => '설정';

  @override
  String get settingsHomeUnknownSection => '알 수 없는 설정 섹션';

  @override
  String get settingsHomeThemeModeSystem => '시스템';

  @override
  String get settingsHomeThemeModeLight => '라이트';

  @override
  String get settingsHomeThemeModeDark => '다크';

  @override
  String get settingsHomePlaceholder => '이 설정은 준비 중입니다.';

  @override
  String get settingsHomePlaceholderDetail =>
      '이 설정은 두 번째 계층 이후의 사양이 확정된 뒤(M4: FOW/DSL 렌더링) 구현합니다.';

  @override
  String get settingsHomePageMissing => '이 페이지가 없습니다';

  @override
  String get settingsHomePageMissingHint => '이 계정의 SNS에는 이 설정이 없습니다.';

  @override
  String get settingsHomePageLoadError => '설정 페이지를 불러올 수 없습니다';

  @override
  String get settingsHomeRemoteLoadError => '서버에서 설정을 가져올 수 없습니다';

  @override
  String get settingsHomeRemotePermissionHint =>
      '\n\n앱 권한이 부족합니다. 로그아웃한 뒤 다시 로그인하면 새 권한이 부여됩니다.';

  @override
  String get settingsHomeSaveFailed => '저장하지 못했습니다';

  @override
  String get settingsHomeChildLocked =>
      '보호 중이므로 여기는 변경할 수 없습니다(민감한 미디어는 항상 숨깁니다).';

  @override
  String get settingsHomeTargetAccount => '설정할 계정';

  @override
  String settingsHomeMissingSnsPage(String area) {
    return 'SNS 플러그인이 설정 페이지 \"$area\"를 제공하지 않습니다';
  }

  @override
  String get settingsLearningTitle => '알고리즘과 커뮤니티에 기여';

  @override
  String settingsLearningError(String error) {
    return '실패했습니다 — $error';
  }

  @override
  String get settingsLearningGrantConfirmButton => '동의하고 참여하기';

  @override
  String get settingsLearningGrantPointOptional =>
      '선택 사항입니다. 거절하거나 그만두어도 RASQ의 기능과 유료 기능은 그대로 사용할 수 있습니다';

  @override
  String get settingsLearningGrantPointScope =>
      '대상은 직접 작성한 공개 게시물과, 그 게시물들이 같은 대화인지 여부뿐입니다';

  @override
  String get settingsLearningGrantPointExcluded =>
      '다른 사람의 게시물, DM, 한정 공개 게시물, ASTell 대화, RAi 질문과 답변은 보내지 않습니다';

  @override
  String get settingsLearningGrantPointVerifiedOnly =>
      '소유자 확인이 끝난 SNS 계정의 게시물만 받습니다';

  @override
  String get settingsLearningGrantPointPurpose =>
      '릴레이셔널 타임라인이 대화를 묶는 방식을 개선하는 데 사용합니다';

  @override
  String get settingsLearningGrantPointDeletion => '그만두면 보낸 데이터를 바로 삭제합니다';

  @override
  String get settingsLearningGrantExtendedNotice =>
      '검증용 설정입니다. 다른 사람의 게시물에 대한 판정과 RAi 대화도 보냅니다.';

  @override
  String get settingsLearningGrantExtendedNoticeDetail =>
      'CENTRAL_LEARNING_SCOPE=extended(S-049 / S-050). 정식 환경에서는 사용하지 않음.';

  @override
  String get settingsLearningGrantScopeDetail =>
      'D-370 / S-051. 관련 TL의 대화 이벤트에서 자신의 게시물(공개로 확인되는 것. Bluesky는 모두 공개)만 POST /me/learning/contributions로 보냄(v2, self = 자신의 SNS 계정). Central은 소유자 확인(sns_links.verified_at)과, 모든 게시물이 a=-1·vis=public인지 확인한다. 받을 때마다 나이와 보호자 동의도 다시 확인한다. 본문의 @멘션과 URL은 가린다.';

  @override
  String get settingsLearningGrantReadFullButton => '설명 전문 읽기';

  @override
  String get settingsLearningGrantAgreeCheckbox => '설명을 읽었으며 데이터 제공에 동의합니다';

  @override
  String settingsLearningDocumentVersion(String version) {
    return '문서 버전: $version';
  }

  @override
  String get settingsLearningAgeTitle => '나이 신고';

  @override
  String get settingsLearningAgeConfirmButton => '신고하기';

  @override
  String get settingsLearningGuardianConsent => '보호자의 동의를 받았습니다';

  @override
  String get settingsLearningAgeDeclared => '나이를 신고했습니다';

  @override
  String get settingsLearningCodeSheetTitle => '철회 코드로 철회';

  @override
  String get settingsLearningCodeConfirmButton => '철회하기';

  @override
  String get settingsLearningCodeSheetBody =>
      '동의할 때 발급된 코드를 입력합니다. 데이터를 제공한 RASQ 계정에 로그인할 수 없게 되어도 철회할 수 있습니다.';

  @override
  String get settingsLearningCodeHint => '철회 코드';

  @override
  String get settingsLearningWithdrawnByCode => '그만두었습니다. 보낸 데이터는 삭제합니다';

  @override
  String get settingsLearningReasonAgeRequired => '나이를 신고해야 합니다';

  @override
  String get settingsLearningReasonUnder16 => '16세 이상부터 참여할 수 있습니다';

  @override
  String get settingsLearningReasonGuardianRequired => '16~17세는 보호자의 동의가 필요합니다';

  @override
  String get settingsLearningIntroNotice =>
      '직접 작성한 공개 게시물을 보내 대화를 묶는 방식의 개선에 협력할 수 있습니다. 선택 사항이며 언제든지 그만둘 수 있습니다.';

  @override
  String get settingsLearningIntroNoticeDetail =>
      'D-243 / D-363 / D-370. 동의는 Central의 account_consents(kind = learning)에 기록. 기본 범위(own)에서는 관련 TL 대화 안의 자신의 공개 게시물만 POST /me/learning/contributions로 보냄. 정식 환경에서는 접수를 닫음(CENTRAL_LEARNING_OPEN=false).';

  @override
  String get settingsLearningReadAboutTitle => '설명 읽기';

  @override
  String get settingsLearningReadAboutSubtitle => '보내는 것, 용도, 보관 기간';

  @override
  String get settingsLearningStatusSection => '상태';

  @override
  String get settingsLearningServerNotConfiguredTitle =>
      'RASQ 서버 연결 주소가 설정되지 않았습니다';

  @override
  String get settingsLearningServerNotConfiguredSubtitle =>
      '연결 대상을 입력하면 확인할 수 있습니다';

  @override
  String get settingsLearningNoAccountTitle => 'RASQ 계정이 아직 없습니다';

  @override
  String get settingsLearningNoAccountSubtitle => '데이터 제공은 RASQ 계정별로 기록합니다';

  @override
  String settingsLearningLoadError(String error) {
    return '가져오지 못했습니다: $error';
  }

  @override
  String get settingsLearningStatusTitle => '기여';

  @override
  String get settingsLearningStatusJoined => '참여 중';

  @override
  String get settingsLearningStatusNotJoined => '참여하지 않음';

  @override
  String get settingsLearningSinceTitle => '동의한 날';

  @override
  String get settingsLearningOpenTitle => '접수';

  @override
  String get settingsLearningOpenYes => '접수 중';

  @override
  String get settingsLearningOpenNo => '아직 시작되지 않았습니다';

  @override
  String get settingsLearningAgeUndeclared => '미신고';

  @override
  String get settingsLearningSentTitle => '보낸 데이터';

  @override
  String settingsLearningSentValue(int relational, int rai) {
    String _temp0 = intl.Intl.pluralLogic(
      relational,
      locale: localeName,
      other: '$relational건',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rai,
      locale: localeName,
      other: '$rai건',
    );
    return '대화 $_temp0 · RAi $_temp1';
  }

  @override
  String get settingsLearningExamplesTitle => '클라우드 판정 예시';

  @override
  String settingsLearningExamplesValue(int examples, int hardNegative) {
    String _temp0 = intl.Intl.pluralLogic(
      examples,
      locale: localeName,
      other: '$examples건',
    );
    String _temp1 = intl.Intl.pluralLogic(
      hardNegative,
      locale: localeName,
      other: '$hardNegative건',
    );
    return '$_temp0(의심스럽지만 다름 $_temp1)';
  }

  @override
  String get settingsLearningPostsLabelsTitle => '게시물 / 라벨';

  @override
  String get settingsLearningModelsTitle => '이 데이터를 사용한 모델';

  @override
  String get settingsLearningModelsNone => '없음';

  @override
  String get settingsLearningModelsSeparator => ', ';

  @override
  String get settingsLearningWithdrawTitle => '기여 그만두기';

  @override
  String get settingsLearningWithdrawMessage =>
      '데이터 전송을 바로 멈추고, 보낸 데이터도 삭제합니다.';

  @override
  String get settingsLearningWithdrawConfirm => '그만두기';

  @override
  String get settingsLearningCancel => '취소';

  @override
  String get settingsLearningWithdrawn => '철회했습니다';

  @override
  String get settingsLearningDeclareAgeButton => '나이 신고하기';

  @override
  String get settingsLearningGranted =>
      '참여했습니다. 아래 코드를 적어 두면 로그인할 수 없게 되어도 그만둘 수 있습니다';

  @override
  String get settingsLearningGrantButton => '내용을 확인하고 참여하기';

  @override
  String get settingsLearningGrantClosedButton => '접수가 아직 시작되지 않았습니다';

  @override
  String get settingsLearningCodeSection => '철회 코드';

  @override
  String get settingsLearningCodeSubtitle =>
      '탭하여 복사. 로그인할 수 없게 되어도 이 코드로 그만둘 수 있습니다';

  @override
  String get settingsLearningCodeCopied => '철회 코드를 복사했습니다';

  @override
  String get settingsLearningCodeStoredOnGrantDevice =>
      '철회 코드는 동의한 기기에 저장되어 있습니다.';

  @override
  String get settingsLearningOtherSection => '기타';

  @override
  String get settingsLearningByCodeTitle => '철회 코드로 그만두기';

  @override
  String get settingsLearningByCodeSubtitle => '로그인할 수 없게 되었을 때';

  @override
  String get settingsLearningDeletionCaption =>
      '계정을 삭제했을 때도 보낸 데이터는 삭제됩니다. 다른 사람이 참여하고 있는지는 누구도 조회할 수 없습니다.';

  @override
  String get settingsLearningDeletionCaptionDetail =>
      'RASQ 계정을 삭제하면 제공 중지와 제공된 데이터 삭제가 동시에 시작됩니다(learning_contributions는 accounts 삭제 시 함께 삭제됨). 다른 사람이 데이터를 제공하고 있는지는 누구도 조회할 수 없습니다(GET /me/learning은 자신의 상태만 반환).';

  @override
  String get settingsLearningKindsSection => '보내는 것';

  @override
  String get settingsLearningKindRelationalTitle => '내 공개 게시물';

  @override
  String get settingsLearningKindRelationalSubtitleExtended => '타임라인에서 묶인 대화';

  @override
  String get settingsLearningKindRelationalSubtitle => '타임라인에서 대화로 묶인 내 공개 게시물';

  @override
  String get settingsLearningKindRelationalDetailExtended =>
      '대화 이벤트(묶음)의 공개 게시물. 작성자별로 학습해도 되는지 판정하여, 허용된 작성자와 자신의 게시물만 보낸다. 본문의 @멘션과 URL은 가린다.';

  @override
  String get settingsLearningKindRelationalDetail =>
      'D-370. 대화 이벤트 안의 자신의 게시물(공개로 확인되는 것)과, 그 게시물들이 같은 대화라는 정보(관련 라벨). 다른 사람의 게시물은 수(참여자·게시물 수)만.';

  @override
  String get settingsLearningUnverifiedNotice =>
      '소유자 확인이 끝나지 않은 SNS 계정의 게시물은 받지 못했습니다. 프로필 편집에서 확인할 수 있습니다.';

  @override
  String get settingsLearningUnverifiedButton => '확인하기';

  @override
  String get settingsLearningKindCloudTitle => '클라우드에서 묶기';

  @override
  String get settingsLearningKindCloudSubtitle => '애매한 대화 묶음을 클라우드의 RAi가 판단합니다';

  @override
  String get settingsLearningKindCloudDetail =>
      'D-367 / S-050. 기기 엔진이 임계값 근처에서 결정한 연결(게시물 → 대화)을 POST /me/relational/judge로 보내 클라우드 LLM의 판정으로 다시 묶는다. 작성자가 허용한 조합만. 판정 예시(의심스럽지만 다름 = hard_negative, 나눴지만 같음 = hard_positive)는 학습용으로 남고, 그만두면 삭제된다.';

  @override
  String get settingsLearningKindRaiSubtitle => 'RAi에 대한 질문과 답변';

  @override
  String get settingsLearningKindRaiDetail =>
      '질문(@멘션과 URL은 가림), 답변, 모드, 사용한 함수 이름, 모델 id. 다른 사람의 게시물은 포함하지 않는다.';

  @override
  String get settingsLearningPreloadTitle => '기기 모델 미리 불러오기';

  @override
  String get settingsLearningPreloadSubtitle =>
      '판정 사전 검토를 빠르게 합니다(다운로드되어 있을 때만)';

  @override
  String get settingsLearningPreloadDetail =>
      'RAi의 기기 내 모델(기본 Qwen3.5 2B)을 실행 직후 조금 뒤에 불러와 작성자 사전 검토에 사용한다. 다운로드되지 않았으면 다운로드하지 않는다(규칙만으로 사전 검토).';

  @override
  String get settingsLearningDebugSection => '개발자용 상세 정보';

  @override
  String get settingsLearningDebugActiveTitle => '수집 중 여부';

  @override
  String get settingsLearningDebugActiveYes => '예';

  @override
  String get settingsLearningDebugActiveNo => '아니요(동의·접수·보호 상태를 확인)';

  @override
  String get settingsLearningDebugScopeTitle => '받는 범위';

  @override
  String get settingsLearningDebugScopeExtended => 'extended(검증용)';

  @override
  String get settingsLearningDebugScopeOwn => 'own(내 공개 게시물만)';

  @override
  String get settingsLearningDebugPendingTitle => '전송 대기';

  @override
  String settingsLearningDebugPendingValue(String relational, String rai) {
    return '대화 $relational · RAi $rai';
  }

  @override
  String get settingsLearningDebugSentTitle => '이번 실행에서 보냄';

  @override
  String settingsLearningDebugSentValue(
    String relational,
    String rai,
    String skipped,
  ) {
    return '대화 $relational · RAi $rai · 건너뜀 $skipped';
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
    return '판정 $decisions(의심스럽지만 다름 $hardNegative · 나눴지만 같음 $hardPositive · 일치 $agree)· 대기 $pending · 건너뜀 $skipped';
  }

  @override
  String get settingsLearningDebugCloudOff => '끄기';

  @override
  String get settingsLearningDebugModelTitle => '기기 모델';

  @override
  String get settingsLearningDebugFlushing => '보내는 중…';

  @override
  String get settingsLearningDebugFlushButton => '지금 보내기';

  @override
  String get settingsLearningDebugVerdictsSection => '작성자 판정';

  @override
  String get settingsLearningDebugLogSection => '기록';

  @override
  String get settingsLegalTitle => '도움말, 법적 고지';

  @override
  String get settingsLegalVersionTitle => '버전';

  @override
  String get settingsLegalHelpTitle => '도움말';

  @override
  String get settingsLegalTourTitle => 'RASQ 사용법 다시 보기';

  @override
  String get settingsLegalCookiesTitle => '쿠키 안내';

  @override
  String get settingsLegalPluginTermsHeader => 'SNS 플러그인 약관';

  @override
  String get settingsLegalPluginNoTerms => '약관 없음';

  @override
  String get settingsLegalLicensesHeader => '라이선스';

  @override
  String get settingsLegalLicensesTitle => '오픈 소스 라이선스';

  @override
  String get settingsLegalLicensesSubtitle => 'Flutter 및 포함된 라이브러리';

  @override
  String get settingsMuteBlockTitle => '뮤트/차단';

  @override
  String get settingsMuteBlockBlockTab => '차단';

  @override
  String get settingsMuteBlockMuteTab => '뮤트';

  @override
  String get settingsMuteBlockBlockedUsers => '차단한 사용자';

  @override
  String get settingsMuteBlockBlockedWords => '차단한 단어';

  @override
  String get settingsMuteBlockBlockedLists => '차단한 리스트';

  @override
  String get settingsMuteBlockComingSoonHint => '준비 중입니다';

  @override
  String get settingsMuteBlockComingSoonDetail => '단어/리스트 차단은 M2 후반에 제공 예정';

  @override
  String get settingsMuteBlockRetryButton => '새로고침';

  @override
  String get settingsMuteBlockNoBlockedUsers => '차단한 사용자가 없습니다';

  @override
  String get settingsMuteBlockNoMutedUsers => '뮤트한 사용자가 없습니다';

  @override
  String get settingsMuteBlockBlockButton => '차단';

  @override
  String get settingsMuteBlockMuteButton => '뮤트';

  @override
  String get settingsMuteBlockBlockingButton => '차단 중';

  @override
  String get settingsMuteBlockMutingButton => '뮤트 중';

  @override
  String get settingsNotifyTokenTitle => '알림 전용 액세스 토큰';

  @override
  String settingsNotifyTokenError(String error) {
    return '실패했습니다 — $error';
  }

  @override
  String get settingsNotifyTokenCaption =>
      '알림을 받기 위한 전용 키입니다. 게시나 계정 조작은 할 수 없습니다.';

  @override
  String get settingsNotifyTokenCaptionDetail =>
      '알림 토큰은 RASQ 서버의 알림을 받기 위한 전용 토큰입니다(읽을 수 있는 것은 나에게 온 알림 수신함뿐이며, 게시나 계정 조작은 할 수 없습니다). 매크로 / ASTell용 하위 토큰도 여기서 발급합니다.';

  @override
  String get settingsNotifyTokenStatusSection => '상태';

  @override
  String get settingsNotifyTokenPushTitle => '푸시 전송';

  @override
  String get settingsNotifyTokenPushPending => '준비 중';

  @override
  String get settingsNotifyTokenPushPendingDetail => '더미 (APNs / FCM 미연결)';

  @override
  String get settingsNotifyTokenServerNotConfiguredTitle =>
      'RASQ 서버 연결 주소가 설정되지 않았습니다';

  @override
  String get settingsNotifyTokenServerNotConfiguredSubtitle =>
      '연결 주소를 입력하면 발급할 수 있습니다';

  @override
  String get settingsNotifyTokenNoAccountTitle => 'RASQ 계정이 아직 없습니다';

  @override
  String get settingsNotifyTokenNoAccountSubtitle => '만들면 알림 토큰을 발급할 수 있습니다';

  @override
  String settingsNotifyTokenLoadError(String error) {
    return '가져오지 못했습니다: $error';
  }

  @override
  String get settingsNotifyTokenLocalTokenTitle => '이 기기의 토큰';

  @override
  String get settingsNotifyTokenLocalTokenActive => '유효';

  @override
  String get settingsNotifyTokenLocalTokenNone => '미발급';

  @override
  String get settingsNotifyTokenDevicesTitle => '푸시 등록된 기기';

  @override
  String settingsNotifyTokenDevicesValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count대',
    );
    return '$_temp0';
  }

  @override
  String get settingsNotifyTokenTestNotFound => '테스트 알림을 쌓았지만 수신함에서 찾지 못했습니다';

  @override
  String settingsNotifyTokenTestFound(
    String title,
    String status,
    int devices,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      devices,
      locale: localeName,
      other: '$devices대',
    );
    return '수신함에서 확인했습니다: \'$title\' ($status, 기기 $_temp0)';
  }

  @override
  String get settingsNotifyTokenTestButton => '테스트 알림 보내기';

  @override
  String get settingsNotifyTokenLocalRevoked => '이 기기의 토큰을 폐기했습니다';

  @override
  String get settingsNotifyTokenRevokeButton => '폐기';

  @override
  String get settingsNotifyTokenEnabled => '발급하고 이 기기를 푸시 등록했습니다';

  @override
  String get settingsNotifyTokenEnableButton => '알림 토큰을 발급하고 이 기기 등록';

  @override
  String get settingsNotifyTokenTokensSection => '발급된 토큰';

  @override
  String get settingsNotifyTokenKindRoot => '알림 토큰';

  @override
  String get settingsNotifyTokenKindChild => '하위 토큰';

  @override
  String settingsNotifyTokenLabelSuffix(String label) {
    return ' ($label)';
  }

  @override
  String get settingsNotifyTokenThisDevice => '이 기기';

  @override
  String settingsNotifyTokenIssuedAt(String time) {
    return '발급 $time';
  }

  @override
  String get settingsNotifyTokenUnused => '미사용';

  @override
  String settingsNotifyTokenLastUsedAt(String time) {
    return '마지막 사용 $time';
  }

  @override
  String get settingsNotifyTokenIssueChildTooltip =>
      '하위 토큰 발급 (매크로 / ASTell 공용)';

  @override
  String get settingsNotifyTokenChildIssued =>
      '하위 토큰을 발급하고 클립보드에 복사했습니다(원래 값은 지금만 볼 수 있습니다)';

  @override
  String get settingsNotifyTokenRevoked => '폐기했습니다';

  @override
  String get settingsNotifyTokenStorageCaption => '키는 이 기기 안에 안전하게 저장합니다.';

  @override
  String get settingsNotifyTokenStorageCaptionDetail =>
      '원래 토큰은 발급할 때만 받아 기기 내의 안전한 영역에 저장합니다. 서버에는 해시만 남습니다. 상위 토큰을 폐기하면 하위 토큰도 폐기됩니다.';

  @override
  String get settingsPagesAboutCookiesTitle => '쿠키 안내';

  @override
  String get settingsPagesAboutCookiesSection1Title => '쿠키';

  @override
  String get settingsPagesAboutCookiesText1 =>
      'iOS·Android·데스크톱 앱은 RASQ 서버와 통신할 때 쿠키를 사용하지 않습니다. RASQ 서버와의 통신은 기기 토큰(Authorization 헤더)으로 하며, 각 SNS의 액세스 토큰은 기기 내 안전한 영역에 저장합니다.';

  @override
  String get settingsPagesAboutCookiesText2 =>
      'iOS·Android 앱의 광고(Google AdMob)는 쿠키 대신 기기의 광고 ID를 사용합니다. 처음 표시되는 Google 동의 화면에서 맞춤 광고 사용 여부를 선택할 수 있습니다.';

  @override
  String get settingsPagesAboutCookiesText3 =>
      '웹 버전과 RASQ의 공개 프로필·게시물 웹 페이지에서는 광고(Google AdSense)를 위해 Google이 쿠키를 사용합니다. 광고 쿠키의 처리는 Google 정책을 따릅니다.';

  @override
  String get settingsPagesAboutCookiesText4 =>
      'SNS의 웹 버전이나 가입 페이지를 앱 내 브라우저로 열면 해당 SNS의 쿠키 처리 방침을 따릅니다.';

  @override
  String get settingsPagesAboutDeveloperTitle => '개발자 모드';

  @override
  String get settingsPagesAboutDeveloperEnabledSubtitle =>
      '화면 설명을 작동 방식과 보내는 데이터의 형태까지 자세히 표시합니다';

  @override
  String get settingsPagesAboutDeveloperEnabledDetail =>
      '켜져 있는 동안 설정과 동의 화면에서 짧게 줄인 설명 대신 원래의 자세한 설명(저장 위치의 KV, 보내는 JSON의 형태 등)을 표시합니다. 표시만 바뀌고 동작은 바뀌지 않습니다.';

  @override
  String get settingsPagesAboutDeveloperNotice1 =>
      '표시만 바뀝니다. 설정과 보내는 데이터는 바뀌지 않습니다.';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseTitle =>
      '화면 읽기 사용해 보기(iOS)';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseSubtitle =>
      'iPhone / iPad의 \'SNS 서비스 찾기\'에 \'평소 브라우저로 보면서 찾기\'를 표시합니다';

  @override
  String get settingsPagesAboutDeveloperIosScreenGlimpseDetail =>
      '일부 기기에서 화면 읽기의 Broadcast Upload Extension(ScreenGlimpseBroadcast)이 화면 녹화 선택에 나타나지 않아(미해결) iOS에서는 기본적으로 숨깁니다. 켜면 진입점을 표시합니다. Android에서는 항상 표시합니다.';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dTitle =>
      '3D RAi 사용해 보기(Android)';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dSubtitle =>
      'Android에서도 RAi 마스코트를 3D로 표시합니다';

  @override
  String get settingsPagesAboutDeveloperRaiAndroid3dDetail =>
      'Android에서 RAi가 열리지 않는다는 보고가 있고 3D 기반(flutter_angle)의 초기화가 의심되어 기본값은 2D입니다. 켜면 3D를 시도합니다. 20초가 지나도 나타나지 않거나 실패하면 자동으로 2D로 되돌리고 RAi 사이드바의 \'진단\'에 이유를 남깁니다. iPhone / iPad / Mac은 항상 3D입니다.';

  @override
  String get settingsPagesAboutHelpTitle => '도움말';

  @override
  String get settingsPagesAboutHelpSection1Title => '사용 방법';

  @override
  String get settingsPagesAboutHelpText1 => '조작이 막히면 사이드 메뉴의 RAi에게 물어보세요.';

  @override
  String get settingsPagesAboutHelpText1Detail =>
      '조작이 막히면 RAi에게 물어보세요. 사이드 메뉴의 RAi에서 인스트럭션(버튼까지 안내)과 어시스턴트(기기 내 모델로 답변, 함수로 대신 수행)를 사용할 수 있습니다.';

  @override
  String get settingsPagesAboutHelpRaiTitle => 'RAi 열기';

  @override
  String get settingsPagesAboutHelpTourAgain1Title => 'RASQ 사용법 다시 보기';

  @override
  String get settingsPagesAboutHelpTourAgain1Subtitle =>
      '기능 소개(타임라인·트렌드·ASTell·RAi 등)';

  @override
  String get settingsPagesAboutHelpSection2Title => '문제가 있을 때';

  @override
  String get settingsPagesAboutHelpText2 =>
      '로그인이나 게시가 잘 되지 않으면 권한을 확인하고 다시 로그인하세요.';

  @override
  String get settingsPagesAboutHelpText2Detail =>
      '로그인할 수 없거나 게시물이 전달되지 않으면 먼저 \'SNS 플러그인 → 보안\'에서 권한을 확인하고, 한 번 로그아웃한 뒤 다시 로그인하세요.';

  @override
  String get settingsPagesAboutHelpSettingsDslSnsSecurityTitle => '보안(권한과 토큰)';

  @override
  String get settingsPagesAboutHelpSettingsServerTitle => 'RASQ 서버 연결 대상';

  @override
  String get settingsPagesAboutSubscriptionTitle => '구독 상태';

  @override
  String get settingsPagesAboutSubscriptionSection1Title => 'RASQ 구독';

  @override
  String get settingsPagesAboutSubscriptionValueRow1Title => '플랜';

  @override
  String get settingsPagesAboutSubscriptionValueRow1Value => '무료';

  @override
  String get settingsPagesAboutSubscriptionValueRow2Title => '플러그인 프록시';

  @override
  String get settingsPagesAboutSubscriptionValueRow2Value => '구독 안 함';

  @override
  String get settingsPagesAboutSubscriptionText1 => '유료 플랜은 준비 중입니다.';

  @override
  String get settingsPagesAboutSubscriptionText1Detail =>
      '플랜: 무료(현재 구독 플랜 없음). 유료 플랜은 앞으로 RASQ 계정에 연결하여 제공합니다.';

  @override
  String get settingsPagesAppearanceDisplayTitle => '인터페이스 표시 크기';

  @override
  String get settingsPagesAppearanceDisplaySection1Title => '표시 크기';

  @override
  String get settingsPagesAppearanceDisplayTextScaleTitle => '글자와 UI 크기';

  @override
  String get settingsPagesAppearanceDisplayTextScaleSubtitle =>
      '앱 전체의 글자 크기를 바꿉니다(즉시 반영)';

  @override
  String get settingsPagesAppearanceFabTitle => '＋ 버튼 기능';

  @override
  String get settingsPagesAppearanceFabNotice1 =>
      '＋를 눌렀을 때 시작할 기능을 고를 수 있습니다. 주변 버튼(안쪽 최대 3개, 바깥쪽 최대 4개)은 ＋를 길게 눌러(마우스는 올려 두기) 톱니바퀴에서 재배치합니다.';

  @override
  String get settingsPagesAppearanceFabNotice1Detail =>
      '영역 appearance.fab(<scope>Tap / <scope>Slots = 배치 순서, 최대 7개).';

  @override
  String get settingsPagesAppearanceFabSection1Title => '홈에서 ＋를 눌렀을 때';

  @override
  String get settingsPagesAppearanceFabHomeTapPostTitle => '게시';

  @override
  String get settingsPagesAppearanceFabHomeTapRasqTitle => 'RASQ에 게시';

  @override
  String get settingsPagesAppearanceFabHomeTapSwingTitle => 'Swing 만들기';

  @override
  String get settingsPagesAppearanceFabHomeTapAstellTitle => 'ASTell 만들기';

  @override
  String get settingsPagesAppearanceFabSection2Title => '트렌드에서 ＋를 눌렀을 때';

  @override
  String get settingsPagesAppearanceFabSection3Title => 'ASTell에서 ＋를 눌렀을 때';

  @override
  String get settingsPagesAppearanceMfmTitle => '사용자 지정 모션과 애니메이션';

  @override
  String get settingsPagesAppearanceMfmSection1Title => 'MFM 애니메이션';

  @override
  String get settingsPagesAppearanceMfmAnimationsTitle => '움직이는 장식 재생';

  @override
  String get settingsPagesAppearanceMfmAnimationsSubtitle =>
      '회전이나 무지개색 등 움직이는 장식을 재생합니다';

  @override
  String get settingsPagesAppearanceMfmAnimationsDetail =>
      'spin / jump / rainbow 등의 MFM을 움직입니다. 끄면 정지 화면이 됩니다(\'모션 줄이기\'가 켜져 있으면 항상 정지)';

  @override
  String get settingsPagesAppearanceMfmSpeedTitle => '애니메이션 속도';

  @override
  String get settingsPagesAppearanceMfmSpeedSubtitle =>
      '100%가 표준입니다. 클수록 빠르게 움직입니다';

  @override
  String get settingsPagesAppearanceMfmSettingsDslAppearanceMotionTitle =>
      '모션 줄이기';

  @override
  String get settingsPagesAppearanceMfmSettingsDslAppearanceMotionSubtitle =>
      '화면 전환 등을 포함해 한꺼번에 줄이기';

  @override
  String get settingsPagesAppearanceMotionTitle => '모션 줄이기';

  @override
  String get settingsPagesAppearanceMotionSection1Title => '애니메이션';

  @override
  String get settingsPagesAppearanceMotionReduceMotionTitle => '모션 줄이기';

  @override
  String get settingsPagesAppearanceMotionReduceMotionSubtitle =>
      '움직이는 장식을 멈추고 화면의 움직임을 줄입니다';

  @override
  String get settingsPagesAppearanceMotionReduceMotionDetail =>
      'MFM의 spin / rainbow 등의 애니메이션을 정지 화면으로 바꾸고 화면 전환의 움직임을 줄입니다';

  @override
  String get settingsPagesAppearanceNotificationsTitle => '알림 표시 형식';

  @override
  String get settingsPagesAppearanceNotificationsSection1Title => '알림 페이지';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabAllTitle =>
      '\'전체\'에서 열기';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabFollowingTitle =>
      '\'팔로잉\'에서 열기';

  @override
  String get settingsPagesAppearanceNotificationsDefaultTabFollowingSubtitle =>
      '팔로우하는 사람의 알림만 먼저 봅니다';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersTitle =>
      'ASTell 시작 알림 예정을 위에 표시';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersSubtitle =>
      '등록한 시작 알림을 알림 페이지 위에 표시합니다';

  @override
  String get settingsPagesAppearanceNotificationsShowRemindersDetail =>
      '등록한 시작 알림(기기의 로컬 알림) 목록을 알림 페이지 위에 표시합니다';

  @override
  String get settingsPagesAppearanceNotificationsText1 =>
      '알림 받을 종류는 \'알림 → 프로필\'에서 선택합니다(기기에 저장됩니다).';

  @override
  String get settingsPagesAppearanceTimelineTitle => '타임라인 표시';

  @override
  String get settingsPagesAppearanceTimelineSection1Title => '새로고침';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesTitle =>
      '타임라인 위아래에 \'게시물 불러오기\' 표시';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesSubtitle =>
      '스마트폰에서는 기본적으로 표시하지 않습니다(당겨서 새로고침)';

  @override
  String get settingsPagesAppearanceTimelineEdgeTilesDetail =>
      '보이면 새 게시물 / 이어지는 게시물을 불러옵니다. 기본값은 휴대폰 앱에서는 표시하지 않고(아래로 당겨 새로고침), 웹 버전과 컴퓨터에서는 표시합니다';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillTitle => '새 게시물 알림 표시';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillSubtitle =>
      '새로고침해서 새 게시물이 오면 헤더 바로 아래에 \'새 게시물\'';

  @override
  String get settingsPagesAppearanceTimelineNewPostsPillDetail =>
      '게시한 사람의 얼굴(최대 3명)과 \'새 게시물\'을 표시합니다. 누르면 맨 위로 이동합니다. 잠시 지나거나 맨 위까지 스크롤하면 사라집니다. 헤더를 숨긴 동안에는 표시하지 않습니다';

  @override
  String get settingsPagesAppearanceVideoTitle => 'PIP 모드';

  @override
  String get settingsPagesAppearanceVideoSection1Title => '동영상';

  @override
  String get settingsPagesAppearanceVideoAutoplayTitle => '열면 자동 재생';

  @override
  String get settingsPagesAppearanceVideoAutoplaySubtitle =>
      '전체 화면과 작은 창에서 바로 재생합니다';

  @override
  String get settingsPagesAppearanceVideoAutoplayDetail =>
      '전체 화면 뷰어와 작은 창(PiP)에서 준비되는 대로 재생합니다';

  @override
  String get settingsPagesAppearanceVideoPipKeepPositionTitle =>
      '작은 창으로 옮길 때 재생 위치 이어가기';

  @override
  String get settingsPagesAppearanceVideoPipKeepPositionSubtitle =>
      '전체 화면에서 \'작은 창에서 재생\'을 누르면 이어서 재생합니다';

  @override
  String get settingsPagesAppearanceVideoSection2Title => '기본 재생 속도';

  @override
  String get settingsPagesAppearanceVideoDefaultSpeed10Title => '1.0×(표준)';

  @override
  String get settingsPagesAppearanceVideoText1 =>
      '작은 창은 잡아서 원하는 곳으로 옮길 수 있습니다.';

  @override
  String get settingsPagesAppearanceVideoText1Detail =>
      '작은 창은 FOW이므로 잡아서 칼럼이나 위아래로 옮길 수 있습니다.';

  @override
  String get settingsPagesAstellBackgroundTitle => '화면이 꺼졌을 때의 동작';

  @override
  String get settingsPagesAstellBackgroundSection1Title => '통화 중 화면을 껐을 때';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffKeepTitle => '통화 계속하기';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffKeepSubtitle =>
      '음성은 그대로 두고 화면 공유 수신만 멈춥니다';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffMuteTitle =>
      '마이크를 음소거하고 계속하기';

  @override
  String get settingsPagesAstellBackgroundOnScreenOffLeaveTitle => '룸에서 나가기';

  @override
  String get settingsPagesAstellBackgroundNotice1 =>
      '이 설정은 준비 중입니다. 현재 ASTell은 화면이 켜져 있는 동안에만 작동합니다.';

  @override
  String get settingsPagesAstellBackgroundNotice1Detail =>
      '이 설정은 저장되지만, 통화 상주화(백그라운드 음성)가 구현된 뒤에 적용됩니다. 현재 ASTell은 화면이 켜져 있는 동안에만 작동합니다.';

  @override
  String get settingsPagesAstellSubscriptionTitle => 'ASTell 4U 구독';

  @override
  String get settingsPagesAstellSubscriptionSection1Title => '상태';

  @override
  String get settingsPagesAstellSubscriptionValueRow1Title => '구독';

  @override
  String get settingsPagesAstellSubscriptionValueRow1Value => '구독 안 함';

  @override
  String get settingsPagesAstellSubscriptionValueRow2Title => '제공';

  @override
  String get settingsPagesAstellSubscriptionValueRow2Value => '준비 중';

  @override
  String get settingsPagesAstellSubscriptionText1 =>
      'ASTell 4U는 준비 중인 유료 플랜입니다. 추천 영역은 무료로 사용할 수 있습니다.';

  @override
  String get settingsPagesAstellSubscriptionText1Detail =>
      'ASTell 4U는 ASTell 추천(For You) 전달과 서버 측 받아쓰기 / 요약을 위한 유료 플랜입니다. 아직 제공하지 않습니다. 추천 영역은 RASQ 서버의 무료 추천으로 작동합니다.';

  @override
  String get settingsPagesAstellTilesTitle => 'Tell 타일';

  @override
  String get settingsPagesAstellTilesSection1Title => '홈 헤더';

  @override
  String get settingsPagesAstellTilesHeaderStripTitle =>
      '팔로우 중인 호스트의 ASTell을 헤더에 표시';

  @override
  String get settingsPagesAstellTilesHeaderStripSubtitle =>
      '진행 중인 룸을 홈 위쪽에 나열합니다';

  @override
  String get settingsPagesAstellTilesHeaderStripDetail =>
      '진행 중인 룸을 홈 헤더의 둥근 모서리 틀에 나열합니다';

  @override
  String get settingsPagesAstellTilesHeaderMaxTitle => '표시 개수';

  @override
  String get settingsPagesAstellTilesHeaderMaxUnit => '개';

  @override
  String get settingsPagesAstellTrendTitle => '트렌드 타임라인으로 전달';

  @override
  String get settingsPagesAstellTrendSection1Title => 'ASTell 홈 영역';

  @override
  String get settingsPagesAstellTrendShowRecommendedTitle => '\'추천\' 표시';

  @override
  String get settingsPagesAstellTrendShowTrendingTitle => '\'트렌드\' 표시';

  @override
  String get settingsPagesAstellTrendShowTrendingSubtitle =>
      '트렌드 룸을 ASTell 홈에 나열합니다';

  @override
  String get settingsPagesAstellTrendText1 =>
      '검색 홈의 트렌드에 룸을 표시하려면 \'트렌드 맞춤 설정\'에서 구성합니다.';

  @override
  String get settingsPagesAstellTrendText1Detail =>
      '트렌드 타임라인(검색 홈)에 룸을 끼워 넣는 것은 트렌드의 노드(알고리즘) 쪽에서 구성합니다.';

  @override
  String get settingsPagesAstellTrendTlconfigTrendTitle => '트렌드 맞춤 설정';

  @override
  String get settingsPagesMediaSaveTitle => '이미지·동영상 저장 위치';

  @override
  String get settingsPagesMediaSaveSection1Title =>
      '\'이미지 저장\'·\'동영상 저장\'의 저장 위치';

  @override
  String get settingsPagesMediaSaveDestinationAskTitle => '저장할 때마다 선택';

  @override
  String get settingsPagesMediaSaveDestinationAskSubtitle =>
      '사진과 파일 중 어디에 할지 매번 묻습니다';

  @override
  String get settingsPagesMediaSaveDestinationAskDetail =>
      '사진과 파일 중 어디에 저장할지 매번 묻습니다(선택할 수 있는 곳이 하나뿐인 기기에서는 묻지 않습니다)';

  @override
  String get settingsPagesMediaSaveDestinationPhotosTitle => '사진(카메라 롤)';

  @override
  String get settingsPagesMediaSaveDestinationPhotosSubtitle =>
      '앨범 \'RASQ\'에 저장됩니다';

  @override
  String get settingsPagesMediaSaveDestinationPhotosDetail =>
      'iPhone / iPad / Mac의 \'사진\', Android 갤러리의 \'RASQ\' 앨범에 들어갑니다';

  @override
  String get settingsPagesMediaSaveDestinationFilesTitle => '파일';

  @override
  String get settingsPagesMediaSaveDestinationFilesSubtitle =>
      '\'파일\' 앱이나 선택한 위치에 저장합니다';

  @override
  String get settingsPagesMediaSaveDestinationFilesDetail =>
      'iPhone / iPad는 \'파일\' 앱의 나의 iPad(나의 iPhone) › RASQ › 保存에 저장합니다. 컴퓨터는 저장할 위치를 선택합니다. Android는 갤러리에 들어갑니다';

  @override
  String get settingsPagesPluginsAccountPickTitle => '공유 / 리노트에 사용할 계정';

  @override
  String get settingsPagesPluginsAccountPickSection1Title =>
      '같은 게시물이 여러 계정에서 보일 때';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentTitle => '지정한 계정 우선';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentSubtitle =>
      '끄면 상대와 자주 대화하는 계정을 선택합니다';

  @override
  String get settingsPagesPluginsAccountPickPreferCurrentDetail =>
      'SNS 계정을 선택해서 보고 있을 때는 그 계정으로 공유 / 리노트합니다. 끄면 최근 상호작용(리액션 / 리노트 / 답글)을 바탕으로 그 상대와 자주 대화하는 계정을 예측해 선택합니다. RASQ 계정으로 한꺼번에 보고 있을 때는 항상 예측으로 선택합니다';

  @override
  String get settingsPagesPluginsComposerTitle => '게시 플러그인';

  @override
  String get settingsPagesPluginsComposerSection1Title => '컴포저';

  @override
  String get settingsPagesPluginsComposerEnabledTitle => '게시 플러그인 사용';

  @override
  String get settingsPagesPluginsComposerEnabledSubtitle =>
      '게시물의 글자나 이미지를 가공하는 플러그인을 사용합니다';

  @override
  String get settingsPagesPluginsComposerEnabledDetail =>
      '컴포저의 텍스트 변환(composer.text)과 미디어 편집(composer.media) 플러그인을 활성화합니다';

  @override
  String get settingsPagesPluginsComposerText1 =>
      '끄면 컴포저와 미디어 편집기의 플러그인 영역이 비게 됩니다.';

  @override
  String get settingsPagesPluginsComposerSettingsComposerTitle => '게시 컴포저 설정';

  @override
  String get settingsPagesPluginsComposerStoreTitle => '플러그인 스토어';

  @override
  String get settingsPagesPluginsEmojiTitle => '이모지 검색';

  @override
  String get settingsPagesPluginsEmojiSection1Title => '이모지 선택기 검색';

  @override
  String get settingsPagesPluginsEmojiSemanticTitle => '의미가 비슷한 이모지도 찾기';

  @override
  String get settingsPagesPluginsEmojiSemanticSubtitle =>
      '이름이 맞지 않아도 의미가 비슷한 이모지를 표시합니다. 입력한 글자는 외부로 보내지 않습니다';

  @override
  String get settingsPagesPluginsEmojiSemanticDetail =>
      '이름이나 별칭에 입력한 글자가 없어도 의미가 비슷한 이모지를 뒤에 나열합니다. 기기 내 검색용 모델(RAi → \'모델\' → 검색)을 설치했을 때만 작동합니다. 계산은 기기 안에서만 하며 입력한 글자는 외부로 보내지 않습니다. 처음 연 서버에서는 백그라운드에서 색인을 만드는 동안 \'준비 중\'으로 표시됩니다';

  @override
  String get settingsPagesPluginsProxyTitle => 'RASQ 플러그인 프록시 구독';

  @override
  String get settingsPagesPluginsProxySection1Title => '상태';

  @override
  String get settingsPagesPluginsProxyValueRow1Title => '구독';

  @override
  String get settingsPagesPluginsProxyValueRow1Value => '구독 안 함';

  @override
  String get settingsPagesPluginsProxyValueRow2Title => '제공';

  @override
  String get settingsPagesPluginsProxyValueRow2Value => '준비 중';

  @override
  String get settingsPagesPluginsProxyText1 =>
      '플러그인 프록시는 준비 중입니다. 지금은 플러그인이 기기에서 직접 통신합니다.';

  @override
  String get settingsPagesPluginsProxyText1Detail =>
      '플러그인 프록시는 wasm 플러그인의 외부 통신을 RASQ 서버를 거치도록 묶는 유료 서비스입니다. 아직 제공하지 않으므로 플러그인은 기기에서 직접 SNS / 자체 서버와 통신합니다. 제공: RASQ 서버의 결제 기반과 동시.';

  @override
  String get settingsPagesPluginsProxySettingsServerTitle => 'RASQ 서버 연결 대상';

  @override
  String get settingsPagesPluginsProxySettingsServerSubtitle =>
      '제공이 시작되면 여기서 선택한 서버를 사용합니다';

  @override
  String get settingsPagesPluginsReactionTitle => '리액션 예측';

  @override
  String get settingsPagesPluginsReactionSection1Title => '리액션 버튼 짧게 누르기';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptyTitle =>
      '아무도 리액션하지 않은 게시물에서도 예측';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptySubtitle =>
      '자주 쓰는 이모지를 예측해서 짧게 누르면 답니다';

  @override
  String get settingsPagesPluginsReactionPredictWhenEmptyDetail =>
      '꺼져 있으면 아직 리액션이 없는 게시물에서는 예측하지 않고, 누르면 이모지 선택기가 열립니다. 켜면 자주 쓰는 이모지를 예측으로 표시하고, 짧게 누르면 그 이모지를 답니다';

  @override
  String get settingsPagesPluginsTelemetryTitle => '의심스러운 통신 신고';

  @override
  String get settingsPagesPluginsTelemetrySection1Title =>
      '플러그인의 수상한 통신을 스토어에 신고';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesTitle => '수상한 통신 신고하기';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesSubtitle =>
      '통신의 형태만 심사에 보냅니다. 본문이나 토큰 등의 내용은 보내지 않습니다. 기본값은 끔';

  @override
  String get settingsPagesPluginsTelemetryFetchShapesDetail =>
      '플러그인이 하는 통신의 \'형태\'(접속 대상 호스트, 메서드, 경로 패턴, 헤더 이름, 보내는 JSON의 키 구조)만을 이 기기에서 처음 봤을 때 한 번만 RASQ 스토어로 보냅니다. 토큰, 본문, 사용자 이름, URL 안의 ID 등의 값은 보내지 않습니다. 심사에서는 승인 후 통신 형태가 바뀐 플러그인을 다시 검토하는 데 사용합니다. 기본값은 끔입니다.';

  @override
  String get settingsPagesPluginsTelemetryText1 =>
      '같은 형태는 두 번 보내지 않습니다. 끄면 동의 철회로 기록됩니다.';

  @override
  String settingsPagesPluginsTelemetryText1Detail(String example) {
    return '보내는 것: 예 $example. 보내지 않는 것: 값 자체. 같은 형태는 두 번 보내지 않습니다. 동의는 스토어의 동의 기록에도 남으며, 끄면 철회로 기록됩니다.';
  }

  @override
  String get settingsPagesPluginsTimelineTitle => '사용자 지정 타임라인 배치';

  @override
  String get settingsPagesPluginsTimelineSection1Title => '타임라인 플러그인';

  @override
  String get settingsPagesPluginsTimelineEnabledTitle => '사용자 지정 타임라인 사용';

  @override
  String get settingsPagesPluginsTimelineEnabledSubtitle =>
      '플러그인의 타임라인을 홈의 탭에 표시합니다';

  @override
  String get settingsPagesPluginsTimelineEnabledDetail =>
      'TL 플러그인(tl)이 선언한 타임라인을 홈의 탭과 \'타임라인 맞춤 설정\'의 알고리즘에 표시합니다';

  @override
  String get settingsPagesPluginsTimelineText1 =>
      '순서와 가져오기는 홈 탭 줄의 톱니바퀴(타임라인 맞춤 설정)에서 구성합니다.';

  @override
  String get settingsPagesPluginsTimelineStoreTitle => '플러그인 스토어';

  @override
  String get settingsPagesPluginsTrendTitle => '커스텀 트렌드 배포';

  @override
  String get settingsPagesPluginsTrendSection1Title => '트렌드 플러그인';

  @override
  String get settingsPagesPluginsTrendEnabledTitle => '트렌드 플러그인 후보 표시';

  @override
  String get settingsPagesPluginsTrendEnabledSubtitle =>
      '검색 홈의 트렌드 영역에 플러그인 후보를 표시합니다';

  @override
  String get settingsPagesPluginsTrendEnabledDetail =>
      '검색 홈의 트렌드 영역에 설치한 트렌드 플러그인(trend.suggest)의 후보 칩을 표시합니다';

  @override
  String get settingsPagesPluginsTrendText1 =>
      '끄면 플러그인이 호출되지 않습니다(설치한 채로 두어도 통신하지 않습니다).';

  @override
  String get settingsPagesPluginsTrendStoreTitle => '플러그인 스토어';

  @override
  String get settingsPagesPluginsTrendStoreSubtitle => '트렌드 플러그인 찾기 / 관리';

  @override
  String get settingsPagesRaiTitle => 'RAi(어시스턴트)';

  @override
  String get settingsPagesRaiSection1Title => '자동화';

  @override
  String get settingsPagesRaiTraceGraphAutoTitle => '공정 그래프 자동 표시';

  @override
  String get settingsPagesRaiTraceGraphAutoSubtitle =>
      '3단계 이상의 자동화를 그래프로 표시합니다';

  @override
  String get settingsPagesRaiTraceGraphAutoDetail =>
      'RAi에게 맡긴 자동화가 3단계 이상이면 공정을 노드 그래프로 자동 표시합니다. 끄면 \'그래프 뷰로 표시\' 버튼이 됩니다';

  @override
  String get settingsPagesRaiText1 => 'AI 모델과 웹 검색은 RAi 바의 모델 버튼에서 설정합니다.';

  @override
  String get settingsPagesRaiText1Detail =>
      '추론 서버와 웹 검색 키는 RAi 바의 모델 칩에서 설정합니다.';

  @override
  String get settingsPagesRelationalPluginsTitle => '플러그인 고급 설정';

  @override
  String get settingsPagesRelationalPluginsSection1Title => '상태';

  @override
  String get settingsPagesRelationalPluginsValueRow1Title => '플러그인 슬롯';

  @override
  String get settingsPagesRelationalPluginsValueRow1Value => '준비 중';

  @override
  String get settingsPagesRelationalPluginsText1 => '이 화면의 플러그인은 준비 중입니다.';

  @override
  String get settingsPagesRelationalPluginsText1Detail =>
      '계약 v0.7에는 아직 관계형 타임라인용 플러그인 슬롯(묶는 방식 교체)이 없습니다. ML 유사도는 RASQ 서버의 ML 게이트웨이를 사용합니다. 플러그인 슬롯: 미정의.';

  @override
  String get settingsPagesRelationalPluginsSettingsServerTitle =>
      'RASQ 서버 연결 대상';

  @override
  String get settingsPagesRelationalRelayTitle => 'Relay 타일';

  @override
  String get settingsPagesRelationalRelaySection1Title => '상태';

  @override
  String get settingsPagesRelationalRelayValueRow1Title => '제공';

  @override
  String get settingsPagesRelationalRelayValueRow1Value => '준비 중';

  @override
  String get settingsPagesRelationalRelayText1 =>
      'Relay 타일은 준비 중입니다. 지금은 \'게시물 클러스터\'에서 대화를 묶는 방식을 바꿀 수 있습니다.';

  @override
  String get settingsPagesRelationalRelayText1Detail =>
      'Relay 타일은 대화 이벤트를 넘나들며 화제가 이어진 흐름(릴레이)을 한 장의 타일로 묶어 보여 주는 표시입니다. 묶는 방식이 정해진 뒤에 추가합니다. 지금은 \'게시물 클러스터\'를 조정해 대화 이벤트를 묶는 방식을 바꿀 수 있습니다. 제공: 알고리즘 확정 후.';

  @override
  String get settingsPagesRelationalTrendTitle => '트렌드 타임라인으로 전달';

  @override
  String get settingsPagesRelationalTrendSection1Title => '상태';

  @override
  String get settingsPagesRelationalTrendValueRow1Title => '제공';

  @override
  String get settingsPagesRelationalTrendValueRow1Value => '준비 중';

  @override
  String get settingsPagesRelationalTrendText1 =>
      '\'트렌드 맞춤 설정\'에서 관련 타임라인을 트렌드로 흘려보낼 수 있습니다.';

  @override
  String get settingsPagesRelationalTrendText1Detail =>
      '관련 탭의 대화 이벤트를 트렌드 타임라인으로 흘려보내는 전달은 트렌드 쪽 노드(알고리즘)에 \'관련 타임라인\' 노드를 두는 형태로 구성할 수 있습니다. 제공: 알고리즘 확정 후.';

  @override
  String get settingsPagesRelationalTrendTlconfigTrendTitle => '트렌드 맞춤 설정';

  @override
  String get settingsPagesResourcesTitle => '리소스 및 광고';

  @override
  String get settingsPagesResourcesSection1Title => '광고';

  @override
  String get settingsPagesResourcesShowAdsTitle => '광고 표시';

  @override
  String get settingsPagesResourcesShowAdsSubtitle =>
      '타임라인의 게시물 사이와 검색 홈의 광고입니다';

  @override
  String get settingsPagesResourcesShowAdsDetail =>
      '타임라인의 게시물 사이(10개마다, 내용 경고가 붙거나 민감한 게시물 옆에는 두지 않음)와 검색 홈의 광고 영역(AdMob, 현재는 테스트 광고). 맞춤 광고는 표시하지 않습니다';

  @override
  String get settingsPagesResourcesSection2Title => '리소스';

  @override
  String get settingsPagesResourcesValueRow1Title => '플러그인 통신';

  @override
  String get settingsPagesResourcesValueRow1Value => '기기에서 직접';

  @override
  String get settingsPagesResourcesValueRow2Title => '추론';

  @override
  String get settingsPagesResourcesValueRow2Value => '기기 내 + 선택한 서버';

  @override
  String get settingsPagesResourcesText1 =>
      '플러그인별 광고 유무와 가격은 플러그인 스토어의 각 페이지에 표시됩니다.';

  @override
  String get settingsPagesResourcesText1Detail =>
      '플러그인별 광고 유무와 가격은 플러그인 스토어의 각 페이지에 표시됩니다. 플러그인 통신: 기기에서 직접(프록시 없음). 추론: 기기 내 모델(RAi) + 임의의 추론 서버.';

  @override
  String get settingsPagesResourcesStoreTitle => '플러그인 스토어';

  @override
  String get settingsPagesTrendCdnTitle => '캐시 네트워크 설정';

  @override
  String get settingsPagesTrendCdnSection1Title => '상태';

  @override
  String get settingsPagesTrendCdnValueRow1Title => '캐시 네트워크';

  @override
  String get settingsPagesTrendCdnValueRow1Value => '준비 중';

  @override
  String get settingsPagesTrendCdnText1 => '준비 중입니다. 지금은 각 SNS에서 직접 가져옵니다.';

  @override
  String get settingsPagesTrendCdnText1Detail =>
      'CDN(캐시 네트워크)에서 트렌드 결과를 읽는 구조는 RASQ 서버의 배포 기반과 함께 도입됩니다. 지금은 각 SNS에서 직접 가져옵니다. 캐시 네트워크: 미제공.';

  @override
  String get settingsSectionsPluginsTitle => '플러그인 구성';

  @override
  String get settingsSectionsPluginsProxyTitle => 'RASQ 플러그인 프록시 구독';

  @override
  String get settingsSectionsPluginsProxySubtitle => '준비 중';

  @override
  String get settingsSectionsPluginsProxyDetail => '미구독(2단계)';

  @override
  String get settingsSectionsPluginsActionBarTitle => '게시물에 플러그인 자동화 배치';

  @override
  String get settingsSectionsPluginsActionBarSubtitle => '게시물 아래에 표시되는 플러그인 버튼';

  @override
  String get settingsSectionsPluginsActionBarDetail =>
      '게시물 액션 바에 표시되는 플러그인 버튼(메인 스위치 / 자동으로 켜기 / 배치)';

  @override
  String get settingsSectionsPluginsTrendTitle => '커스텀 트렌드 배포';

  @override
  String get settingsSectionsPluginsComposerTitle => '게시 플러그인';

  @override
  String get settingsSectionsPluginsTimelineTitle => '사용자 지정 타임라인 배치';

  @override
  String get settingsSectionsPluginsStoreTitle => '플러그인 고급 설정';

  @override
  String get settingsSectionsPluginsStoreSubtitle => '플러그인 스토어(설치된 플러그인 관리)';

  @override
  String get settingsSectionsPluginsTelemetryTitle => '의심스러운 통신 신고';

  @override
  String get settingsSectionsPluginsTelemetrySubtitle => '기본값은 꺼짐';

  @override
  String get settingsSectionsPluginsTelemetryDetail =>
      '통신 형태 보고: 플러그인의 통신 형태(값은 포함하지 않음)를 처음 발견했을 때만 스토어로 보냅니다. 기본값은 꺼짐';

  @override
  String get settingsSectionsSnsTitle => 'SNS 플러그인';

  @override
  String get settingsSectionsSnsAccountTitle => '계정';

  @override
  String get settingsSectionsSnsTimelineTitle => '타임라인';

  @override
  String get settingsSectionsSnsSecurityTitle => '보안';

  @override
  String get settingsSectionsSnsSafetyTitle => '개인정보 보호 및 세이프 모드';

  @override
  String get settingsSectionsSnsChildSafeTitle => '차일드 세이프';

  @override
  String get settingsSectionsSnsChildSafeSubtitle => '보호자 모니터링 / 차일드 모드';

  @override
  String get settingsSectionsSnsChildSafeDetail =>
      '보호자로서 지켜보기 / 차일드 모드(보호자의 코드로 연결)';

  @override
  String get settingsSectionsSnsListsTitle => '리스트';

  @override
  String get settingsSectionsSnsMuteBlockTitle => '뮤트/차단';

  @override
  String get settingsSectionsSnsPluginButtonsTitle => '플러그인 버튼';

  @override
  String get settingsSectionsSnsPluginButtonsSubtitle => '플러그인 버튼 표시 방식';

  @override
  String get settingsSectionsSnsPluginButtonsDetail =>
      '화면별 메인 스위치와 \'열 때 자동으로 켜기\', 이 계정의 사용 / 사용 안 함 및 묶음 임계값';

  @override
  String get settingsSectionsSnsEmojiSearchTitle => '이모지 검색';

  @override
  String get settingsSectionsSnsEmojiSearchSubtitle => '의미가 비슷한 이모지도 찾기';

  @override
  String get settingsSectionsSnsEmojiSearchDetail => '의미가 비슷한 이모지도 찾기(기기 내 모델)';

  @override
  String get settingsSectionsSnsReactionPredictTitle => '리액션 예측';

  @override
  String get settingsSectionsSnsReactionPredictSubtitle =>
      '아무도 리액션하지 않은 게시물도 예측할지 여부';

  @override
  String get settingsSectionsSnsQuickEmojiTitle => '빠른 이모지';

  @override
  String get settingsSectionsSnsQuickEmojiSubtitle =>
      '리액션 버튼을 길게 누르고 밀어서 고르는 이모지';

  @override
  String get settingsSectionsSnsAccountPickTitle => '공유 / 리노트에 사용할 계정';

  @override
  String get settingsSectionsSnsAccountPickSubtitle => '같은 게시물이 여러 계정에 보일 때';

  @override
  String get settingsSectionsSnsAccountPickDetail =>
      '여러 계정에 보이는 게시물을 어느 계정으로 다룰지';

  @override
  String get settingsSectionsSnsMfmTitle => '사용자 지정 모션과 애니메이션';

  @override
  String get settingsSectionsSnsResourcesTitle => '리소스 및 광고';

  @override
  String get settingsSectionsSnsLegalTitle => '도움말, 법적 고지';

  @override
  String get settingsSectionsSnsNote =>
      '계정 / 타임라인 / 보안 / 개인정보 보호는 사용 중인 SNS의 플러그인이 제공하는 페이지입니다(플러그인이 제공하지 않는 페이지는 표시되지 않습니다).';

  @override
  String get settingsSectionsSnsNoteDetail =>
      '계정 / 타임라인 / 보안 / 개인정보 보호는 설정할 계정의 SNS 플러그인이 제공하는 설정 페이지입니다(sns.settingsPages. 선언되지 않은 페이지의 행은 표시하지 않음, D-482).';

  @override
  String get settingsSectionsAppearanceTitle => '앱 외관';

  @override
  String get settingsSectionsAppearanceDisplayTitle => '인터페이스 표시 크기';

  @override
  String get settingsSectionsAppearanceThemeTitle => '글꼴 및 색 구성표';

  @override
  String get settingsSectionsAppearanceThemeSubtitle => '테마(색상, 아이콘, 배경 이미지)';

  @override
  String get settingsSectionsAppearanceColumnsTitle => '칼럼 너비';

  @override
  String get settingsSectionsAppearanceColumnsSubtitle => '넓은 화면에서 좌우 칼럼의 너비';

  @override
  String get settingsSectionsAppearanceColumnsDetail =>
      '넓은 화면에서 소형 / 대형 칼럼의 비율(1:1 / 2:3 / 3:5 / 너비 고정)';

  @override
  String get settingsSectionsAppearanceMotionTitle => '모션 줄이기';

  @override
  String get settingsSectionsAppearanceTimelineTitle => '타임라인 표시';

  @override
  String get settingsSectionsAppearanceTimelineSubtitle => '타임라인의 \'게시물 불러오기\'';

  @override
  String get settingsSectionsAppearanceTimelineDetail => 'TL 위아래의 \'게시물 불러오기\'';

  @override
  String get settingsSectionsAppearancePipTitle => '화면 속 화면';

  @override
  String get settingsSectionsAppearanceFabTitle => '＋ 버튼 기능';

  @override
  String get settingsSectionsAppearanceFabSubtitle => '눌렀을 때 시작할 작업';

  @override
  String get settingsSectionsAppearanceMediaSaveTitle => '이미지·동영상 저장 위치';

  @override
  String get settingsSectionsAppearanceMediaSaveSubtitle =>
      '사진(카메라 롤) / 파일 / 저장할 때마다 선택';

  @override
  String get settingsSectionsAppearanceNotificationsTitle => '알림 표시 형식';

  @override
  String get settingsSectionsAstellTitle => 'ASTell';

  @override
  String get settingsSectionsAstellSubscriptionTitle => 'ASTell 4U 구독';

  @override
  String get settingsSectionsAstellSubscriptionSubtitle => '준비 중';

  @override
  String get settingsSectionsAstellSubscriptionDetail => '미구독(2단계)';

  @override
  String get settingsSectionsAstellTilesTitle => 'Tell 타일';

  @override
  String get settingsSectionsAstellTrendTitle => '트렌드 타임라인으로 전달';

  @override
  String get settingsSectionsAstellRoomButtonsTitle => '룸 버튼';

  @override
  String get settingsSectionsAstellRoomButtonsSubtitle => '입력란 왼쪽의 버튼';

  @override
  String get settingsSectionsAstellRoomButtonsDetail =>
      '룸 하단, 입력란 왼쪽의 둥근 버튼 배열(순서 변경 / 표시 / 숨기기 / 플러그인 버튼 추가)';

  @override
  String get settingsSectionsAstellStoreTitle => '플러그인 고급 설정';

  @override
  String get settingsSectionsAstellStoreSubtitle => 'ASTell에서 사용하는 플러그인';

  @override
  String get settingsSectionsAstellStoreDetail => 'ASTell 액션 플러그인(스토어)';

  @override
  String get settingsSectionsAstellBackgroundTitle => '화면이 꺼졌을 때의 동작';

  @override
  String get settingsSectionsRelationalTitle => '릴레이셔널 타임라인';

  @override
  String get settingsSectionsRelationalClusterTitle => '게시물 클러스터';

  @override
  String get settingsSectionsRelationalClusterSubtitle => '대화를 묶는 방식';

  @override
  String get settingsSectionsRelationalClusterDetail =>
      '대화 이벤트를 묶는 방식(묶이기 쉬운 정도 / 가중치 / 가라앉기까지의 시간)';

  @override
  String get settingsSectionsRelationalRelayTitle => 'Relay 타일';

  @override
  String get settingsSectionsRelationalTrendTitle => '트렌드 타임라인으로 전달';

  @override
  String get settingsSectionsRelationalPluginsTitle => '플러그인 고급 설정';

  @override
  String get settingsSectionsRelationalSamplingTitle => '트렌드 샘플링 수준';

  @override
  String get settingsSectionsRelationalSamplingSubtitle => '후보에 넣을 시간 범위';

  @override
  String get settingsSectionsRelationalSamplingDetail =>
      '후보에 넣을 시간 범위(묶음 판정의 고급 설정)';

  @override
  String get settingsSectionsRelationalNote => 'Relay 타일과 트렌드 배포는 준비 중입니다.';

  @override
  String get settingsSectionsRelationalNoteDetail =>
      'Relay 타일과 트렌드 배포는 알고리즘 확정 후 제공됩니다(D-011).';

  @override
  String get settingsSectionsTrendTitle => '트렌드';

  @override
  String get settingsSectionsTrendGenresTitle => '장르';

  @override
  String get settingsSectionsTrendTendencyTitle => '트렌드 성향/자극성';

  @override
  String get settingsSectionsTrendEmomTitle => 'EmoM 임계값';

  @override
  String get settingsSectionsTrendEmomSubtitle => '운영진이 제한한 트렌드 숨기기 / 임계값 공개';

  @override
  String get settingsSectionsTrendEmomDetail =>
      'EmoM 임계값(0~100, 기본값 50)과 \'임계값 공개\'(기본값 꺼짐). 운영진 제한 점수가 이 값보다 큰 트렌드는 목록에 표시하지 않습니다(D-404)';

  @override
  String get settingsSectionsTrendPluginsTitle => '플러그인 고급 설정';

  @override
  String get settingsSectionsTrendCdnTitle => '캐시 네트워크 설정';

  @override
  String get settingsSectionsTrendCdnSubtitle => '준비 중';

  @override
  String get settingsSectionsTrendCdnDetail => '미제공(2단계)';

  @override
  String get settingsSectionsRaiTitle => 'RAi(어시스턴트)';

  @override
  String get settingsSectionsRaiGraphTitle => '공정 그래프 자동 표시';

  @override
  String get settingsSectionsNotificationsTitle => '알림';

  @override
  String get settingsSectionsNotificationsProfileTitle => '프로필';

  @override
  String get settingsSectionsNotificationsAccessTokenTitle => '액세스 토큰';

  @override
  String get settingsSectionsNotificationsAccessTokenSubtitle => '알림을 받기 위한 설정';

  @override
  String get settingsSectionsNotificationsAccessTokenDetail =>
      '알림 전용 토큰 발급 / 폐기, 기기 푸시 등록';

  @override
  String get settingsSectionsNotificationsSecurityTitle => '보안';

  @override
  String get settingsSectionsNotificationsSecuritySubtitle => 'SNS 권한 및 액세스 토큰';

  @override
  String get settingsSectionsAboutTitle => 'RASQ 정보';

  @override
  String get settingsSectionsAboutServerTitle => 'RASQ 서버';

  @override
  String get settingsSectionsAboutServerSubtitle => '연결할 서버';

  @override
  String get settingsSectionsAboutServerDetail =>
      '플러그인 스토어 / RASQ 계정 / 로그인의 연결 대상';

  @override
  String get settingsSectionsAboutHelpTitle => '도움말';

  @override
  String get settingsSectionsAboutTourTitle => 'RASQ 사용법 다시 보기';

  @override
  String get settingsSectionsAboutTourSubtitle =>
      '기능 소개(타임라인·트렌드·ASTell·RAi 등)';

  @override
  String get settingsSectionsAboutSubscriptionTitle => '구독 상태';

  @override
  String get settingsSectionsAboutCookiesTitle => '쿠키 안내';

  @override
  String get settingsSectionsAboutPrivacyTitle => '개인정보 처리방침';

  @override
  String get settingsSectionsAboutTermsTitle => '이용약관';

  @override
  String get settingsSectionsAboutLearningTitle => '알고리즘과 커뮤니티에 기여';

  @override
  String get settingsSectionsAboutLearningSubtitle => '선택 사항. 기본값은 \'제공하지 않음\'';

  @override
  String get settingsSectionsAboutAstellTermsTitle => 'ASTell 이용 조건';

  @override
  String get settingsSectionsAboutRaiTermsTitle => 'RAi 이용 조건';

  @override
  String get settingsSectionsAboutStoreTermsTitle => '플러그인 스토어 이용 조건';

  @override
  String get settingsSectionsAboutDevTermsTitle => '플러그인 개발자 등록 및 심사 조건';

  @override
  String get settingsSectionsAboutDevTermsSubtitle => '심사료 포함';

  @override
  String get settingsSectionsAboutBillingTitle => '요금 및 포인트 조건';

  @override
  String get settingsSectionsAboutCommerceTitle => '특정상거래법에 따른 표기';

  @override
  String get settingsSectionsAboutResourcesTitle => '리소스 및 광고';

  @override
  String get settingsSectionsAboutLegalTitle => '도움말, 법적 고지';

  @override
  String get settingsSectionsAboutDeveloperTitle => '개발자 모드';

  @override
  String get settingsSectionsAboutDeveloperSubtitle => '화면 설명을 자세히 표시';

  @override
  String get settingsSecurityAgoJustNow => '방금';

  @override
  String settingsSecurityAgoMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분 전',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count시간 전',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count일 전',
    );
    return '$_temp0';
  }

  @override
  String settingsSecurityCodeSentTo(String to) {
    return '$to(으)로 확인 코드를 보냈습니다';
  }

  @override
  String get settingsSecurityTitle => '계정 보안';

  @override
  String get settingsSecurityNotSignedIn => 'RASQ 계정에 로그인하지 않았습니다.';

  @override
  String get settingsSecurityToLoginTitle => '기존 RASQ 계정에 로그인';

  @override
  String get settingsSecurityToLoginSubtitle => '핸들(또는 이메일)과 비밀번호';

  @override
  String get settingsSecurityEmailHeader => '이메일 주소';

  @override
  String get settingsSecurityEmailCaption =>
      '비밀번호를 잊었을 때의 재설정과 로그인 2단계 확인에 사용합니다. 다른 사람에게는 보이지 않습니다.';

  @override
  String get settingsSecurityEmailDetail =>
      '등록하면 비밀번호를 잊었을 때의 재설정, 다른 기기에서 로그인할 때의 2단계 확인(비밀번호 다음에 이메일 확인 코드), 중요한 조작의 확인과 알림에 사용할 수 있습니다. 이메일을 확인하지 않으면 비밀번호를 잊었을 때 재설정할 수 없습니다. 다른 사람에게는 보이지 않습니다.';

  @override
  String get settingsSecurityEmailCurrentTitle => '현재 이메일';

  @override
  String get settingsSecurityEmailUnregistered => '미등록';

  @override
  String get settingsSecurityEmailNewHint => '새 이메일 주소';

  @override
  String get settingsSecurityEmailHint => '이메일 주소';

  @override
  String get settingsSecuritySendCodeButton => '코드 보내기';

  @override
  String get settingsSecurityEmailChangeNeedsPasswordOrCode =>
      '바꾸려면 현재 비밀번호 또는 현재 이메일로 받은 확인 코드가 필요합니다.';

  @override
  String get settingsSecurityEmailChangeNeedsCode =>
      '바꾸려면 현재 이메일로 받은 확인 코드가 필요합니다.';

  @override
  String get settingsSecurityCurrentPasswordHint => '현재 비밀번호';

  @override
  String get settingsSecurityEmailSendCodeToCurrentButton => '현재 이메일로 코드 보내기';

  @override
  String get settingsSecurityEmailNeedsPassword =>
      '비밀번호를 설정한 계정은 이메일 주소를 추가할 때 현재 비밀번호가 필요합니다.';

  @override
  String settingsSecurityEmailPendingCaption(String email) {
    return '$email(으)로 받은 코드를 입력해 주세요(15분 후 무효가 됩니다).';
  }

  @override
  String get settingsSecurityEmailVerified => '이메일 주소를 확인했습니다';

  @override
  String get settingsSecurityVerifyButton => '확인';

  @override
  String get settingsSecurityEmailRemoveTitle => '이메일 주소 제거';

  @override
  String get settingsSecurityEmailRemoveSubtitle => '확인 코드가 필요합니다';

  @override
  String get settingsSecurityPasswordHeader => '비밀번호';

  @override
  String get settingsSecurityPasswordChangeCaption =>
      '바꾸면 다른 기기는 로그아웃됩니다. 현재 비밀번호 또는 이메일 확인 코드가 필요합니다.';

  @override
  String get settingsSecurityPasswordNoneCaption =>
      '비밀번호가 없으면 다른 기기에서 로그인할 수 없습니다(이 기기에서만 사용 가능). 설정하면 다른 기기에서 핸들(또는 이메일)과 비밀번호로 같은 계정에 들어갈 수 있습니다.';

  @override
  String get settingsSecurityPasswordNewHint => '새 비밀번호(8자 이상)';

  @override
  String get settingsSecurityPasswordHint => '비밀번호(8자 이상)';

  @override
  String get settingsSecurityPasswordChanged => '비밀번호를 바꿨습니다';

  @override
  String get settingsSecurityPasswordSet => '비밀번호를 설정했습니다';

  @override
  String get settingsSecurityPasswordChangeButton => '비밀번호 변경';

  @override
  String get settingsSecurityPasswordSetButton => '비밀번호 설정';

  @override
  String get settingsSecurityPasswordByCodeButton => '이메일 코드로 변경';

  @override
  String get settingsSecurityPasswordResetWarning =>
      '비밀번호를 \'재설정\'하면 동기화한 설정을 읽을 수 없게 됩니다.';

  @override
  String get settingsSecurityPasswordResetWarningDetail =>
      '비밀번호는 동기화한 설정의 암호화에도 사용합니다. \'비밀번호 재설정\'(로그인 화면)을 하면 이전 비밀번호로 암호화한 데이터를 복호화할 수 없게 됩니다.';

  @override
  String get settingsSecuritySecondFactorHeader => '로그인 2단계';

  @override
  String get settingsSecuritySecondFactorNeedsEmailCaption =>
      '이메일 주소를 확인하면 다른 기기에서 로그인할 때 비밀번호 다음에 이메일 확인 코드도 요구합니다(기본 ON).';

  @override
  String get settingsSecuritySecondFactorActiveCaption =>
      '다른 기기에서 로그인할 때 비밀번호 다음에 이메일로 받은 확인 코드(10분 유효)도 요구합니다.';

  @override
  String get settingsSecuritySecondFactorOffCaption =>
      '꺼져 있습니다. 다른 기기에서는 비밀번호만으로 로그인할 수 있습니다.';

  @override
  String get settingsSecuritySecondFactorTitle => '이메일 확인 코드도 요구';

  @override
  String get settingsSecuritySecondFactorNeedsEmailSubtitle =>
      '이메일 주소 확인이 필요합니다';

  @override
  String get settingsSecuritySecondFactorEnabled => '로그인 2단계를 켰습니다';

  @override
  String get settingsSecuritySecondFactorDisableNeedsPasswordOrCode =>
      '끄려면 현재 비밀번호 또는 이메일로 받은 확인 코드가 필요합니다.';

  @override
  String get settingsSecuritySecondFactorDisableNeedsCode =>
      '끄려면 이메일로 받은 확인 코드가 필요합니다.';

  @override
  String get settingsSecuritySendCodeToEmailButton => '이메일로 코드 보내기';

  @override
  String get settingsSecurityCancelButton => '그만두기';

  @override
  String get settingsSecuritySecondFactorDisabled => '로그인 2단계를 껐습니다';

  @override
  String get settingsSecuritySecondFactorDisableButton => '2단계 끄기';

  @override
  String get settingsSecuritySessionsHeader => '로그인 중인 기기';

  @override
  String settingsSecuritySessionsRevokedOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count대',
    );
    return '다른 $_temp0를 로그아웃시켰습니다';
  }

  @override
  String get settingsSecuritySessionsRevokeOthersButton => '다른 기기 모두 로그아웃';

  @override
  String get settingsSecuritySessionUnnamed => '이름 없는 기기';

  @override
  String get settingsSecurityThisDeviceSuffix => ' (이 기기)';

  @override
  String settingsSecuritySessionLastUsed(String ago) {
    return '마지막 사용: $ago';
  }

  @override
  String settingsSecuritySessionExpires(String date) {
    return '만료 $date';
  }

  @override
  String get settingsSecuritySessionRevoked => '로그아웃시켰습니다';

  @override
  String get settingsSecuritySessionLogoutButton => '로그아웃';

  @override
  String get settingsSecurityConfirmDeleteHeader => '계정 삭제 확인';

  @override
  String get settingsSecurityConfirmEmailRemoveHeader => '이메일 주소 제거 확인';

  @override
  String settingsSecurityConfirmCodeCaption(String to) {
    return '$to(으)로 받은 코드를 입력해 주세요.';
  }

  @override
  String get settingsSecurityDeleteButton => '삭제하기';

  @override
  String get settingsSecurityRemoveButton => '제거';

  @override
  String get settingsSecurityDeleteHeader => '계정 삭제';

  @override
  String get settingsSecurityDeleteTitle => 'RASQ 계정 삭제';

  @override
  String get settingsSecurityDeleteSubtitleWithEmail =>
      '이메일 확인 코드가 필요합니다. 되돌릴 수 없습니다';

  @override
  String get settingsSecurityDeleteSubtitle => '되돌릴 수 없습니다';

  @override
  String get settingsSecurityRolesHeader => '역할';

  @override
  String get settingsSecurityRolesTitle => '이 계정의 역할';

  @override
  String get settingsSecurityRoleDeveloper => '개발자';

  @override
  String get settingsSecurityRoleReviewer => '심사원';

  @override
  String get settingsSecurityEmailReplaceNeedsPasswordOrCodeError =>
      '현재 비밀번호를 입력하거나, 현재 이메일로 받은 확인 코드로 확인해 주세요';

  @override
  String get settingsSecurityEmailReplaceNeedsCodeError =>
      '현재 이메일로 받은 확인 코드로 확인해 주세요';

  @override
  String get settingsSecurityEnterCurrentPasswordError => '현재 비밀번호를 입력해 주세요';

  @override
  String get settingsSecurityCodeSent => '확인 코드를 보냈습니다';

  @override
  String get settingsSecurityDeleteConfirmMessage =>
      '서버의 프로필, 계정 번들, 동기화한 설정, 리뷰와 북마크, ASTell 룸과 공유, 알림 토큰, 동의 기록을 삭제합니다. 되돌릴 수 없습니다.';

  @override
  String get settingsSecuritySendConfirmCodeButton => '확인 코드 보내기';

  @override
  String get settingsSecurityDeleted => 'RASQ 계정을 삭제했습니다';

  @override
  String get settingsSecurityEmailRemoved => '이메일 주소를 제거했습니다';

  @override
  String get settingsSecurityCodeHint => '확인 코드(예: 3mJr7-AoUXx)';

  @override
  String get settingsSecurityCodeHelper => '이메일의 링크를 붙여 넣어도 확인할 수 있습니다';

  @override
  String get settingsSecurityLoginFailedHelp =>
      '핸들(이메일) 또는 비밀번호가 다릅니다.\n비밀번호를 설정하지 않은 RASQ 계정에는 다른 기기에서 로그인할 수 없습니다. 그 계정을 만든 기기(지금도 로그인 중인 기기)에서 \'설정 → 계정 보안\'으로 비밀번호를 설정한 후 다시 로그인해 주세요.';

  @override
  String get settingsSecurityServerNotConfiguredError =>
      'RASQ 서버 연결 주소가 설정되지 않았습니다';

  @override
  String get settingsSecurityLoginFailed => '로그인하지 못했습니다';

  @override
  String settingsSecurityLoggedInAs(String handle) {
    return '@$handle에 로그인했습니다';
  }

  @override
  String get settingsSecurityLoginEnterCredentialsError =>
      '핸들(또는 이메일)과 비밀번호를 입력해 주세요';

  @override
  String get settingsSecurityVerifiedEmailFallback => '확인된 이메일';

  @override
  String get settingsSecurityLoginTitle => 'RASQ 계정에 로그인';

  @override
  String get settingsSecurityLoginCaption =>
      '핸들(@는 없어도 됨) 또는 확인된 이메일 주소와 비밀번호로 들어갑니다.';

  @override
  String get settingsSecurityLoginDetail =>
      '핸들(@는 없어도 됨) 또는 확인된 이메일 주소와 비밀번호로 들어갑니다. 확인된 이메일이 있는 계정은 그다음 이메일로 받은 확인 코드도 입력합니다(2단계 확인).';

  @override
  String get settingsSecurityLoginIdentifierHint => '핸들 또는 이메일 주소';

  @override
  String get settingsSecurityLoginPasswordHint => '비밀번호';

  @override
  String get settingsSecurityLoginButton => '로그인';

  @override
  String get settingsSecurityLoginForgotButton => '비밀번호를 잊었어요';

  @override
  String get settingsSecurityLoginNoPasswordHint =>
      '비밀번호를 설정하지 않은 계정은 다른 기기에서 로그인할 수 없습니다(만든 기기에서만 사용 가능). 그 기기의 \'설정 → 계정 보안\'에서 비밀번호를 설정해 주세요.';

  @override
  String get settingsSecurityLoginCodeHeader => '확인 코드';

  @override
  String settingsSecurityLoginChallengeCaption(String email, int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes분 유효',
    );
    return '$email(으)로 확인 코드를 보냈습니다($_temp0, 1회용). 받은 코드를 입력해 주세요.';
  }

  @override
  String get settingsSecurityVerifiedEmailAddressFallback => '확인된 이메일 주소';

  @override
  String get settingsSecurityLoginConfirmButton => '확인하고 로그인';

  @override
  String get settingsSecurityLoginResendButton => '코드 다시 보내기';

  @override
  String get settingsSecurityLoginBackButton => '핸들 / 비밀번호로 돌아가기';

  @override
  String get settingsSecurityLoginNoMailHint =>
      '이메일이 오지 않으면 스팸 이메일함도 확인해 주세요. 짐작 가지 않는 로그인 이메일이 오면 비밀번호를 바꿔 주세요.';

  @override
  String get settingsSecurityLoginChildHeader => '자녀 계정';

  @override
  String get settingsSecurityLoginChildTitle => '보호자에게 받은 코드로 로그인';

  @override
  String get settingsSecurityLoginChildSubtitle => '보호자가 만든 자녀 계정에 들어갑니다';

  @override
  String get settingsSecurityResetEnterEmailError => '확인된 이메일 주소를 입력해 주세요';

  @override
  String get settingsSecurityResetCodeSent =>
      '그 이메일 주소를 확인한 계정이 있다면 확인 코드를 보냈습니다(10분 유효)';

  @override
  String settingsSecurityResetDoneKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count대',
    );
    return '비밀번호를 재설정했습니다. 다른 $_temp0의 기기를 로그아웃했습니다';
  }

  @override
  String settingsSecurityResetDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count대',
    );
    return '비밀번호를 재설정했습니다($_temp0의 기기를 로그아웃했습니다). 새 비밀번호로 로그인해 주세요';
  }

  @override
  String get settingsSecurityResetTitle => '비밀번호 재설정';

  @override
  String get settingsSecurityResetCaption =>
      '확인된 이메일 주소로 확인 코드(10분 유효, 1회용)를 보내고 새 비밀번호를 정합니다. 다른 기기는 모두 로그아웃됩니다.';

  @override
  String get settingsSecurityResetNoEmailWarning =>
      '이메일 주소를 확인하지 않은 계정은 비밀번호를 재설정할 수 없습니다.';

  @override
  String get settingsSecurityResetNoEmailDetail =>
      '그 계정을 만든 기기(지금도 로그인 중인 기기)에서 \'설정 → 계정 보안\'으로 새 비밀번호를 설정해 주세요. 그 기기도 없다면 계정으로 돌아갈 방법은 없습니다.';

  @override
  String get settingsSecurityResetEmailHint => '확인된 이메일 주소';

  @override
  String get settingsSecurityResendButton => '다시 보내기';

  @override
  String settingsSecurityResetNewPasswordHint(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count자 이상',
    );
    return '새 비밀번호($_temp0)';
  }

  @override
  String get settingsSecurityResetConfirmPasswordHint => '새 비밀번호(확인)';

  @override
  String get settingsSecurityResetMismatchError => '일치하지 않습니다';

  @override
  String get settingsSecurityResetKeepTitle => '이 기기의 로그인은 유지';

  @override
  String get settingsSecurityResetKeepSubtitle =>
      '지금 이 기기에서 로그인 중인 계정을 재설정할 때만 유지됩니다';

  @override
  String get settingsSecurityResetSyncWarning => '재설정하면 동기화한 설정을 읽을 수 없게 됩니다.';

  @override
  String get settingsSecurityResetSyncWarningDetail =>
      '비밀번호는 동기화한 설정의 암호화에도 사용합니다. 이전 비밀번호로 암호화한 데이터는 복호화할 수 없게 됩니다.';

  @override
  String get settingsSecurityResetSubmitButton => '비밀번호 재설정';

  @override
  String get settingsSnsShareConflictError => '다른 기기가 먼저 변경했습니다. 다시 시도해 주세요';

  @override
  String get settingsSnsShareOffConfirmTitle => 'SNS 로그인 공유를 중지할까요?';

  @override
  String get settingsSnsShareOffConfirmMessage =>
      '공유 데이터와 모든 기기의 키를 삭제합니다. 각 기기의 SNS 로그인은 그대로 남습니다.';

  @override
  String get settingsSnsShareOffConfirmDetail =>
      'RASQ Central에 있는 공유 내용(암호화된 것)과 모든 기기의 키를 삭제합니다. 각 기기의 SNS 로그인은 그대로 남습니다.';

  @override
  String get settingsSnsShareOffConfirmButton => '중지';

  @override
  String get settingsSnsShareCancelButton => '취소';

  @override
  String get settingsSnsShareStopped => '공유를 중지했습니다';

  @override
  String get settingsSnsShareSubtitleLoading => '불러오는 중…';

  @override
  String get settingsSnsShareSubtitleUnsupported =>
      '이 기기의 로그인은 공유를 지원하지 않습니다. 다시 로그인해 주세요';

  @override
  String get settingsSnsShareSubtitleOffAsk => '끔 (다른 기기에서 로그인할 때 묻습니다)';

  @override
  String get settingsSnsShareSubtitleOff => '끔';

  @override
  String get settingsSnsShareSubtitleOnHolding => '켬 · 이 기기는 공유 중입니다';

  @override
  String get settingsSnsShareSubtitleOnWaiting => '켬 · 공유 중인 기기의 승인을 기다리고 있습니다';

  @override
  String get settingsSnsShareSubtitleOnNotYet => '켬 · 이 기기는 아직 공유하지 않았습니다';

  @override
  String get settingsSnsShareHeader => '기기 간 SNS 로그인 공유';

  @override
  String get settingsSnsShareCaption =>
      '새 기기에서도 SNS에 자동으로 로그인할 수 있습니다. 내용은 암호화되어 RASQ 서버는 읽을 수 없습니다.';

  @override
  String get settingsSnsShareDetail =>
      'SNS 액세스 토큰을 이 RASQ 계정으로 로그인한 기기들 사이에서 암호화(E2E)하여 공유합니다. 새 기기에서 로그인하면 공유 중인 기기에서 승인한 뒤 그 기기도 SNS 계정에 일괄 로그인합니다. RASQ 서버는 내용을 읽을 수 없습니다.';

  @override
  String get settingsSnsShareSwitchTitle => '다른 기기와 SNS 로그인 공유';

  @override
  String get settingsSnsShareRequestTitle => '이 기기에도 공유 요청';

  @override
  String get settingsSnsShareRequestSubtitle => '공유 중인 기기에 승인 요청이 표시됩니다';

  @override
  String get settingsSnsShareRequested => '공유 중인 기기에 승인을 요청했습니다';

  @override
  String get settingsSnsShareDevicesLabel => '기기';

  @override
  String get settingsSnsShareThisDeviceSuffix => ' (이 기기)';

  @override
  String get settingsSnsShareDeviceShared => '공유 중';

  @override
  String get settingsSnsShareDeviceWaiting => '승인 대기 중';

  @override
  String get settingsSnsShareDeviceNotShared => '공유하지 않음';

  @override
  String settingsSnsShareApproved(String name) {
    return '$name에 공유했습니다';
  }

  @override
  String get settingsSnsShareApproveButton => '공유';

  @override
  String get settingsSnsShareDeclineButton => '거절';

  @override
  String settingsSnsShareRemoved(String name) {
    return '$name을(를) 공유에서 제외했습니다';
  }

  @override
  String get settingsSnsShareRemoveButton => '제외';

  @override
  String get settingsSnsShareRemovedCaption =>
      '제외한 기기는 그동안의 로그인을 그대로 가지고 있습니다. 짐작 가는 바가 없다면 SNS 쪽에서도 로그아웃하세요.';

  @override
  String get settingsSnsShareRemovedDetail =>
      '\'로그인 중인 기기\'에서 그 기기를 로그아웃시키면 그 기기의 키도 삭제됩니다. 제외한 기기는 그동안 받은 액세스 토큰을 가지고 있습니다(짐작 가는 바가 없다면 SNS 쪽에서도 로그아웃하세요).';

  @override
  String get shellColumnSplitSmallFixedLabel => '소형 칼럼 너비 고정';

  @override
  String get shellColumnSplitLargeFixedLabel => '대형 칼럼 너비 고정';

  @override
  String get shellColumnSplitEvenHint => '같은 너비';

  @override
  String get shellColumnSplitTwoThreeHint => '소형 2 : 대형 3';

  @override
  String get shellColumnSplitThreeFiveHint => '소형 3 : 대형 5';

  @override
  String get shellColumnSplitSmallFixedHint => '소형 칼럼을 정한 너비로, 나머지는 대형 칼럼으로';

  @override
  String get shellColumnSplitLargeFixedHint => '대형 칼럼을 정한 너비로, 나머지는 소형 칼럼으로';

  @override
  String get shellColumnWidthErrorEmpty => '너비를 입력해 주세요';

  @override
  String get shellColumnWidthErrorNotInteger => '숫자(정수)로 입력해 주세요';

  @override
  String shellColumnWidthErrorRange(String min, String max) {
    return '$min~$max px 사이로 입력해 주세요';
  }

  @override
  String get shellColumnThirdEmptySearch => '검색';

  @override
  String get shellColumnThirdEmptyNotifications => '알림';

  @override
  String get shellColumnThirdEmptyNone => '표시하지 않음';

  @override
  String get shellColumnThirdSettingsTooltip => '세 번째 칼럼 설정';

  @override
  String get shellColumnThirdCloseTooltip => '닫기';

  @override
  String get shellColumnThirdEmptyTitle => '세 번째 칼럼';

  @override
  String get shellColumnThirdEmptyHint => '열려 있는 화면을 여기로 옮길 수 있습니다';

  @override
  String get shellColumnThirdEmptyHintDetail => 'FOW를 여기로 옮길 수 있습니다(M5c)';

  @override
  String get shellNavHome => '홈';

  @override
  String get shellNavSearch => '검색';

  @override
  String get shellNavNotifications => '알림';

  @override
  String get shellHeaderTimelineSwitchTooltip => '타임라인 전환';

  @override
  String get shellHeaderExpandTooltip => '헤더 되돌리기';

  @override
  String get shellHeaderScrollToTopTooltip => '맨 위로';

  @override
  String get shellHeaderSearchHint => '검색';

  @override
  String get shellHeaderBackTooltip => '뒤로';

  @override
  String get shellHeaderCloseButton => '닫기';

  @override
  String get shellHeaderMenuTooltip => '메뉴';

  @override
  String get shellHeaderOpenSidebarSemantics => '사이드바 열기';

  @override
  String get shellSidebarSemantics => '사이드바';

  @override
  String shellSidebarSwitchToAccountTooltip(String name) {
    return '$name(으)로 전환';
  }

  @override
  String get shellSidebarRasqAccountTooltip => 'RASQ 계정';

  @override
  String get shellSidebarHideAccountsTooltip => '계정 목록 숨기기';

  @override
  String get shellSidebarShowAccountsTooltip => '계정 목록 표시';

  @override
  String get shellSidebarAccountSettingsButton => '계정 설정';

  @override
  String get shellSidebarBookmarks => '북마크';

  @override
  String get shellSidebarLists => '리스트';

  @override
  String get shellSidebarPlugins => '플러그인';

  @override
  String get shellSidebarCustomPlugins => '커스텀 플러그인';

  @override
  String get shellSidebarAllSettings => '모든 설정';

  @override
  String get shellSidebarHelp => '도움말';

  @override
  String get shellSidebarDevCatalog => '컴포넌트 카탈로그 (dev)';

  @override
  String get shellSidebarDevWasmPlugin => 'WASM 플러그인 테스트 (dev)';

  @override
  String get shellSidebarWebConsole => '웹 콘솔';

  @override
  String get shellSidebarAccountActionsTooltip => '계정 작업';

  @override
  String get shellSidebarShowAccountMenu => '이 계정 보기';

  @override
  String get shellSidebarLogoutMenu => '로그아웃';

  @override
  String get shellAccountHeaderPickTooltip => '계정 선택';

  @override
  String shellAccountHeaderReadingAsTooltip(String account) {
    return '$account(으)로 읽는 중';
  }

  @override
  String get shellAccountHeaderSwitchSemantics => '계정 전환';

  @override
  String get shellAccountHeaderAvatarSemantics => '계정';

  @override
  String get shellAccountPickerSemantics => '계정 선택';

  @override
  String get shellAccountPickerCloseTooltip => '닫기';

  @override
  String get shellAccountFowTitle => 'RASQ 계정';

  @override
  String get shellAccountFowCloseButton => '닫기';

  @override
  String get shellAccountAppealSheetTitle => '조치 해제 신청';

  @override
  String get shellAccountAppealCaption => '운영 담당자가 읽고, 수리되면 조치가 해제됩니다.';

  @override
  String get shellAccountAppealCaptionDetail =>
      '운영(rasq-judge) 담당자가 읽고, 수리되면 조치가 해제됩니다. 자동 판정을 거치지 않습니다.';

  @override
  String get shellAccountAppealReasonHint => '신청 사유(필수)';

  @override
  String shellAccountAppealFailedError(String error) {
    return '신청하지 못했습니다: $error';
  }

  @override
  String get shellAccountAppealSubmitButton => '신청하기';

  @override
  String get shellAccountAppealSentSnack => '해제를 신청했습니다. 담당자가 확인합니다';

  @override
  String get shellAccountLocalDisplayName => '이 기기';

  @override
  String get shellAccountMenuAddSns => 'SNS 계정 추가';

  @override
  String get shellAccountMenuAllSettings => '설정';

  @override
  String get shellAccountMenuAccountPage => '계정 페이지';

  @override
  String get shellAccountMenuEditProfile => '프로필 편집';

  @override
  String get shellAccountMenuAccountSettings => '계정 설정';

  @override
  String get shellAccountMenuNotificationSettings => '알림 설정';

  @override
  String get shellAccountMenuSecurity => '보안(이메일 / 비밀번호 / 기기)';

  @override
  String get shellAccountMenuLogout => '로그아웃';

  @override
  String get shellAccountMenuDelete => 'RASQ 계정 삭제';

  @override
  String get shellAccountLogoutTitle => 'RASQ 계정에서 로그아웃';

  @override
  String get shellAccountLogoutMessage => '이 기기에서 RASQ 계정을 제거합니다.';

  @override
  String get shellAccountLogoutConfirmButton => '로그아웃';

  @override
  String get shellAccountLoggedOutWithSnsSnack =>
      'RASQ 계정과 해당 SNS 계정에서 로그아웃했습니다';

  @override
  String get shellAccountLoggedOutKeptSnsSnack =>
      'RASQ 계정에서 로그아웃했습니다. SNS 계정은 \'이 기기만\'으로 옮겼습니다';

  @override
  String get shellAccountDeleteReloginRequiredError => '이 계정에 다시 로그인한 후 삭제하세요';

  @override
  String get shellAccountDeleteNeedsEmailCodeSnack =>
      '삭제하려면 이메일 인증 코드가 필요합니다. \'계정 삭제\'에서 진행하세요';

  @override
  String get shellAccountDeleteTitle => 'RASQ 계정 삭제';

  @override
  String get shellAccountDeleteMessage =>
      '서버의 프로필, 계정 번들, 동기화된 설정, 리뷰와 북마크, ASTell 룸과 공유, 알림 토큰, 동의 기록을 삭제합니다. \'알고리즘과 커뮤니티에 기여\'에 동의한 경우 제공 중지와 이미 제공된 데이터 삭제도 함께 시작됩니다.\n되돌릴 수 없습니다. 각 SNS의 계정과 게시물은 삭제되지 않습니다.';

  @override
  String get shellAccountDeleteConfirmButton => '삭제';

  @override
  String get shellAccountDeletedSnack => 'RASQ 계정을 삭제했습니다';

  @override
  String shellAccountDeleteFailedError(String error) {
    return '삭제하지 못했습니다: $error';
  }

  @override
  String shellAccountCreatedSnack(String handle) {
    return 'RASQ 계정 @$handle을(를) 만들었습니다';
  }

  @override
  String shellAccountSanctionActive(String level) {
    return '이 계정에 조치가 적용되어 있습니다: $level';
  }

  @override
  String shellAccountSanctionRestrictedFeatures(String features) {
    return '중지된 기능: $features';
  }

  @override
  String shellAccountSanctionReviewDelay(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '발언마다 $seconds초의 검열 지연이 적용됩니다',
    );
    return '$_temp0';
  }

  @override
  String shellAccountSanctionStaffNote(String note) {
    return '운영진: $note';
  }

  @override
  String get shellAccountSanctionNoExpiry => '기한: 없음';

  @override
  String shellAccountSanctionExpiry(String expiresAt) {
    return '기한: $expiresAt';
  }

  @override
  String shellAccountSanctionAppealButton(String category, String level) {
    return '해제 신청($category / $level)';
  }

  @override
  String shellAccountSanctionAppealPending(String category) {
    return '신청 중($category)';
  }

  @override
  String get shellAccountEmpty => '아직 RASQ 계정이 없습니다.';

  @override
  String shellAccountRowSubtitle(String kind, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$kind · SNS $_temp0';
  }

  @override
  String get shellAccountRowInUseSuffix => ' · 사용 중';

  @override
  String get shellAccountRowNeedsLoginSuffix => ' · 로그인 필요';

  @override
  String get shellAccountCollapseActionsTooltip => '작업 접기';

  @override
  String get shellAccountActionsTooltip => '계정 작업';

  @override
  String shellAccountReloginSnack(String handle) {
    return '@$handle에 다시 로그인하세요';
  }

  @override
  String get shellAccountChildSafeButton => '차일드 세이프';

  @override
  String get shellAccountCreateButton => '새 계정 만들기';

  @override
  String get shellAccountLoginButton => '로그인';

  @override
  String get shellAccountServerNotConfigured => 'RASQ 서버 연결 주소가 설정되지 않았습니다';

  @override
  String get shellAccountConfigureServerButton => '연결 대상 설정';

  @override
  String get shellAccountProfileSheetTitle => '프로필 편집';

  @override
  String get shellAccountProfileSaveButton => '저장';

  @override
  String get shellAccountProfileDisplayNameLabel => '표시 이름';

  @override
  String get shellAccountProfileDisplayNameHint => '표시 이름';

  @override
  String get shellAccountProfileHandleLabel => '핸들(@ 제외, a-z 0-9 _)';

  @override
  String get shellAccountProfileCentralCaption => 'RASQ 서버의 프로필을 업데이트합니다.';

  @override
  String get shellAccountProfileLocalCaption =>
      '이 기기에만 있는 계정입니다. 핸들은 RASQ 계정을 만들면 부여됩니다.';

  @override
  String get shellAccountProfileSavedSnack => '프로필을 저장했습니다';

  @override
  String shellAccountProfileSaveFailedError(String error) {
    return '저장하지 못했습니다: $error';
  }

  @override
  String get shellAccountTileMenuTooltip => 'RASQ 계정';

  @override
  String get shellTermsSheetTitle => '이용약관 동의';

  @override
  String get shellTermsAgreeButton => '동의';

  @override
  String get shellTermsNotice =>
      'RASQ 계정을 계속 사용하려면 현재 이용약관과 개인정보 처리방침에 동의해야 합니다. 동의하기 전까지 ASTell, 구매, 데이터 보관은 사용할 수 없습니다.';

  @override
  String shellTermsNoticeDetail(String endpoints) {
    return 'D-371 / S-053. 서버의 CENTRAL_TERMS_VERSION / CENTRAL_PRIVACY_VERSION과 같은 버전의 동의가 모두 기록될 때까지 \'동의 대기\' 상태입니다. PUT /me/consents/$endpoints.';
  }

  @override
  String get shellTermsReadTermsButton => '이용약관 읽기';

  @override
  String get shellTermsReadPrivacyButton => '개인정보 처리방침 읽기';

  @override
  String get shellTermsAgeHeader => '나이';

  @override
  String get shellTermsGuardianConsentCheck => '보호자의 동의를 받았습니다';

  @override
  String get shellTermsAgreeCheck => '이용약관과 개인정보 처리방침을 읽었으며 동의합니다';

  @override
  String shellTermsVersionCaption(String termsVersion, String privacyVersion) {
    return '버전: 이용약관 $termsVersion · 개인정보 처리방침 $privacyVersion';
  }

  @override
  String get shellTermsAcceptedSnack => '이용약관에 동의했습니다';

  @override
  String get shellTermsOutdatedError => '이용약관이 새로워졌습니다. 앱을 업데이트한 뒤 동의하세요';

  @override
  String shellTermsRecordFailedError(String error) {
    return '동의를 기록할 수 없습니다: $error';
  }

  @override
  String get shellTermsBannerText =>
      '이용약관 동의가 필요합니다. 동의하기 전까지 ASTell, 구매 등은 사용할 수 없습니다.';

  @override
  String get shellTermsBannerOpenButton => '확인하기';

  @override
  String get storeStatusInReview => '심사 중';

  @override
  String get storeStatusPublished => '공개 중';

  @override
  String get storeStatusUpdateAvailable => '업데이트 있음';

  @override
  String get storeStatusWarning => '경고';

  @override
  String get storeStatusSuspended => '정지';

  @override
  String get storeStatusWithdrawn => '철회';

  @override
  String get storeStatusUnlisted => '비공개';

  @override
  String get storeStatusBeta => '베타';

  @override
  String get storeStatusRevoked => '폐기';

  @override
  String get storeOriginOfficial => '공식';

  @override
  String get storeOriginVerified => '검증됨';

  @override
  String get storeOriginCommunity => '커뮤니티';

  @override
  String get storeTypeComposer => '게시물 작성';

  @override
  String get storeTypePost => '게시물';

  @override
  String get storeTypeViewer => '전체 화면 표시';

  @override
  String get storeTypeTimeline => '타임라인';

  @override
  String get storeTypeTrend => '트렌드';

  @override
  String get storeTypeTheme => '테마';

  @override
  String get storeTypeAssets => '스티커 / 소재';

  @override
  String get storeTypeCustom => '커스텀';

  @override
  String get storeTypeOther => '기타';

  @override
  String get storeFilterFree => '무료';

  @override
  String get storeFilterNoAds => '광고 없음';

  @override
  String get storeFilterOfficial => '공식';

  @override
  String get storeFilterVerified => '인증됨';

  @override
  String get storeFilterRecent => '30일 이내';

  @override
  String get storeFilterLightweight => '경량 (5MB 미만)';

  @override
  String get storeFilterOffline => '오프라인';

  @override
  String get storePermNetwork => '네트워크';

  @override
  String get storePermNetworkDescription => '외부 통신';

  @override
  String get storePermStorage => '저장소';

  @override
  String get storePermStorageDescription => '기기 내 저장 영역';

  @override
  String get storePermFiles => '파일';

  @override
  String get storePermFilesDescription => '사용자가 선택한 파일 읽기·쓰기';

  @override
  String get storePermSns => '게시물과 계정';

  @override
  String get storePermSnsDescription => 'SNS 계정을 사용한 조작';

  @override
  String get storePermDm => '다이렉트 메시지';

  @override
  String get storePermDmDescription => 'DM 읽기·쓰기';

  @override
  String get storePermGpuMl => 'GPU / 머신러닝';

  @override
  String get storePermGpuMlDescription => 'GPU 실행·모델 추론';

  @override
  String get storePermClipboard => '클립보드';

  @override
  String get storePermClipboardDescription => '복사한 내용 읽기·쓰기';

  @override
  String get storePermBackground => '백그라운드 실행';

  @override
  String get storePermBackgroundDescription => '화면을 닫아도 동작';

  @override
  String get storePermUi => '화면과 배치';

  @override
  String get storePermUiDescription => '화면 표시와 버튼 배치';

  @override
  String get storePermOther => '기타';

  @override
  String get storeReviewSortHelpful => '관련성';

  @override
  String get storeReviewSortRecent => '최신';

  @override
  String get storeReviewSortRatingHigh => '평가 높은 순';

  @override
  String get storeReviewSortRatingLow => '평가 낮은 순';

  @override
  String storeScopePermission(String permission) {
    return '권한 $permission';
  }

  @override
  String storeScopeHost(String host) {
    return '연결 대상 $host';
  }

  @override
  String get storeScopeInstance => '연결 대상 로그인한 인스턴스';

  @override
  String storeScopeSlot(String slot) {
    return '사용 위치 $slot';
  }

  @override
  String storeScopeReason(String permission, String reason) {
    return '용도 $permission — $reason';
  }

  @override
  String storeScopeDataHandling(String text) {
    return '데이터 취급 — $text';
  }

  @override
  String storeNeedsOrgate(String feature) {
    return '$feature은(는) ORGATE-Server에 연결하면 사용할 수 있습니다(연결 주소가 설정되지 않았습니다)';
  }

  @override
  String get storeFeaturePurchase => '구매';

  @override
  String get storeFeaturePoints => '포인트';

  @override
  String get storeFeatureReview => '리뷰';

  @override
  String storeSessionPluginMismatch(String actual, String expected) {
    return '구성의 플러그인($actual)이 요청한 것($expected)과 다릅니다';
  }

  @override
  String storeSessionVersionMismatch(String actual, String expected) {
    return '구성의 버전($actual)이 요청한 버전($expected)과 다릅니다';
  }

  @override
  String get storeNoBundle => '배포물이 없습니다';

  @override
  String get storeListSeparator => ', ';

  @override
  String get storeDotSeparator => ' · ';

  @override
  String get storeVerifyHashOnly => 'SHA-512 대조 OK (서명 없음)';

  @override
  String get storeVerifyFull => 'SHA-512 + ed25519 서명 검증 OK';

  @override
  String get storeVerifyHashMismatch =>
      '무결성 검증에 실패했습니다 (SHA-512 불일치). 잠시 후 다시 가져와 주세요';

  @override
  String get storeVerifyKeyMismatch =>
      '스토어의 서명 키가 앱에 내장된 키와 일치하지 않습니다. 연결 주소를 확인해 주세요';

  @override
  String get storeVerifyUnsigned => '배포물에 서명이 없습니다(이 빌드는 서명된 스토어만 허용합니다)';

  @override
  String get storeVerifyBadSignature => '배포물의 서명이 올바르지 않습니다. 설치를 중지했습니다';

  @override
  String storeVerifyError(String error) {
    return '서명을 검증하지 못했습니다: $error';
  }

  @override
  String get storeWidenedNoRecord =>
      '마지막으로 허용한 내용의 기록이 없기 때문 (플러그인 관리에서 확인하고 설치해 주세요)';

  @override
  String storeWidenedOver(String items) {
    return '마지막으로 허용한 내용보다 넓어지기 때문 ($items)';
  }

  @override
  String get storeManifestUnavailable => '구성(매니페스트)을 가져오지 못했습니다';

  @override
  String storeManifestVersionNotFound(String version) {
    return 'Ver.$version의 구성을 찾지 못했습니다';
  }

  @override
  String storeConsentChanged(String version) {
    return '확인한 내용(Ver.$version)과 스토어의 구성이 바뀌었습니다. 다시 확인해 주세요';
  }

  @override
  String storePackageInvalid(String error) {
    return '배포물의 내용을 검증하지 못했습니다: $error';
  }

  @override
  String storePackageMismatch(String actual, String expected) {
    return '배포물의 내용($actual)이 스토어 게재($expected)와 다릅니다';
  }

  @override
  String storePackageRequires(String plugins) {
    return '이 플러그인에는 $plugins이(가) 필요합니다(지원하지 않아 설치할 수 없습니다)';
  }

  @override
  String storeThemeSaveFailed(String error) {
    return '테마를 저장하지 못했습니다: $error';
  }

  @override
  String storeAssetsSaveFailed(String error) {
    return '에셋 팩을 저장하지 못했습니다: $error';
  }

  @override
  String get storeSlotRegisterFailed => '슬롯에 등록하지 못했습니다';

  @override
  String storeVersionBundleChanged(String version) {
    return 'Ver.$version의 배포물이 설치할 때와 달라 불러오지 않습니다(다시 설치해 주세요)';
  }

  @override
  String storeVersionLoadFailed(String version, String error) {
    return 'Ver.$version을(를) 불러오지 못했습니다: $error';
  }

  @override
  String get storeVersionNoScopeRecord =>
      '이 버전에서 허용하는 내용의 기록이 없습니다(다시 설치하면 확인할 수 있습니다)';

  @override
  String storeVersionNotInstalled(String version) {
    return 'Ver.$version은(는) 설치되어 있지 않습니다';
  }

  @override
  String get storeNotInstalled => '설치되어 있지 않습니다';

  @override
  String storeVersionInUse(String version) {
    return 'Ver.$version은(는) 사용 중입니다(기본 / 계정 지정을 먼저 해제)';
  }

  @override
  String get storeManageTitle => '플러그인 관리';

  @override
  String get storeManageUpdatesHeader => '업데이트';

  @override
  String get storeManageUpdateSettingsTitle => '업데이트 설정';

  @override
  String get storeManageUpdateSettingsSubtitle => '자동 업데이트 여부 · 업데이트 로그';

  @override
  String get storeManageUpdateSettingsDetail =>
      'SNS / 액션 / 뷰별로 자동·설치만·수동 · 업데이트 로그';

  @override
  String get storeManagePointsTitle => '포인트';

  @override
  String get storeManagePointsDisabled => '공개 테스트에서는 사용할 수 없습니다';

  @override
  String storeManagePointsBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '포인트 $count',
    );
    return '$_temp0';
  }

  @override
  String get storeManagePointsSignIn => 'RASQ 계정에 로그인하면 사용할 수 있습니다';

  @override
  String get storeManagePointsBuyInConsole => '웹 콘솔에서 살 수 있습니다(지급 후 1개월 뒤 만료)';

  @override
  String storeManagePointsExpiring(int month, int day, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$month/$day에 $count포인트 만료 · 웹 콘솔에서 구매',
    );
    return '$_temp0';
  }

  @override
  String get storeNoInstalledPlugins => '설치된 플러그인이 없습니다';

  @override
  String get storeManageImportTitle => '플러그인 가져오기';

  @override
  String get storeManageImportSubtitle => '개발 중인 플러그인 설치 (심사 전)';

  @override
  String get storeManageImportDetail =>
      '개발 중인 wasm / .rasqpkg 설치 (심사를 통과하지 않음)';

  @override
  String get storeManageHomeHeader => '홈 표시';

  @override
  String get storeManageShowInstalledTitle => '설치된 것도 홈에 표시';

  @override
  String get storeManageShowInstalledSubtitle =>
      '이번 주 트렌드 / 신규 줄에 설치한 플러그인도 표시합니다';

  @override
  String get storeBookmarksTitle => '북마크';

  @override
  String storeManageSwitchTo(String version) {
    return '$version(으)로 전환';
  }

  @override
  String storeVersionMadeDefault(String version) {
    return '$version을(를) 기본 버전으로 했습니다';
  }

  @override
  String storeManageUpdateTo(String version) {
    return '$version(으)로 업데이트';
  }

  @override
  String get storeManageOffline => '스토어에 연결할 수 없습니다';

  @override
  String get storeManageUpToDate => '최신입니다';

  @override
  String get storeManageDeployedVersion => '배포한 버전';

  @override
  String get storeAccountVersionsTitle => '계정별 버전 설정';

  @override
  String storeManageAccountVersionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '계정별 ($count건 지정)',
    );
    return '$_temp0';
  }

  @override
  String get storePluginNotFound => '이 플러그인을 찾을 수 없습니다';

  @override
  String storeInstallFailed(String error) {
    return '설치하지 못했습니다: $error';
  }

  @override
  String get storeHasAds => '광고 있음';

  @override
  String get storeBuyDisabled => '공개 테스트에서는 구매할 수 없습니다';

  @override
  String get storeTileGet => '받기';

  @override
  String get storeTileUpdate => '업데이트';

  @override
  String get storeOpen => '열기';

  @override
  String get storeTileUnavailable => '정지 중';

  @override
  String storeDownloadsTenThousands(String value) {
    return '$value만';
  }

  @override
  String storeNotAssetPack(String id) {
    return '에셋 팩이 아닙니다: $id';
  }

  @override
  String get storeUpdatesNoneApplied => '자동으로 설치할 업데이트가 없었습니다';

  @override
  String get storeUpdateSettingsTitle => '업데이트/배포 설정';

  @override
  String get storeUpdateSettingsModeHeader => '업데이트/배포';

  @override
  String get storeUpdateSettingsPopup => '업데이트 후 실행 시 팝업 표시';

  @override
  String get storeUpdateLogTitle => '업데이트 로그';

  @override
  String get storeUpdateSettingsCheckNow => '지금 확인';

  @override
  String get storeUpdateSettingsCaption =>
      '허용한 내용이 넓어지는 버전과 유료 버전은 자동으로 설치되지 않습니다';

  @override
  String get storeUpdateSettingsCaptionDetail =>
      '마지막으로 허용한 내용보다 권한·연결 대상·사용 위치·용도가 넓어지는 버전(확인할 수 없는 버전 포함)과 구매하지 않은 유료 버전은 어떤 모드에서도 자동으로 사용을 시작하지 않습니다(업데이트 로그에 이유가 남습니다). 실행할 때마다 한 번 확인합니다.';

  @override
  String get storeUpdateLogEmpty => '아직 없습니다';

  @override
  String get storeUpdateLogEmptyHint => '업데이트하면 여기에 남습니다';

  @override
  String get storeInstalledTitle => '설치됨';

  @override
  String get storeInstalledEmptyHint => '스토어에서 추가할 수 있습니다';

  @override
  String storeInstalledItemSubtitle(String version, String id) {
    return 'v$version · $id';
  }

  @override
  String get storeUnknown => '알 수 없음';

  @override
  String get storeInstalledMissingHint => '삭제되었거나 다른 기기에서 설치한 것입니다';

  @override
  String get storeInstalledSourceSnapshot => '설치할 때의 게재 사본입니다.';

  @override
  String get storeInstalledSourceManifest => '플러그인 자체의 선언(권한 id만)입니다.';

  @override
  String get storeInstalledRemoveTitle => '삭제할까요?';

  @override
  String storeInstalledRemoveMessage(String name) {
    return '$name을(를) 기기에서 삭제합니다.';
  }

  @override
  String get storeRemove => '삭제';

  @override
  String get storeCancel => '취소';

  @override
  String get storeInstalledOffline => '스토어에 연결할 수 없어 기기에 있는 정보를 표시합니다.';

  @override
  String get storeInstalledUnlisted =>
      '스토어 게재를 찾을 수 없습니다(철회되었을 수 있습니다). 그대로 계속 사용할 수도, 삭제할 수도 있습니다.';

  @override
  String get storeInstalledVersionHeader => '설치된 버전';

  @override
  String storeInstalledAt(String date) {
    return '설치: $date';
  }

  @override
  String storeInstalledAtVerified(String date, String sha512) {
    return '설치: $date · 검증됨 SHA-512 $sha512';
  }

  @override
  String storeInstalledNewerTitle(String version) {
    return '스토어에 v$version이(가) 있습니다';
  }

  @override
  String get storeInstalledNewerSubtitle => '스토어 페이지에서 다시 설치할 수 있습니다';

  @override
  String storeInstalledSlots(String slots) {
    return '동작 중인 위치: $slots';
  }

  @override
  String get storeInstalledOpenStore => '스토어 페이지 열기';

  @override
  String get storePrivacyHeader => '개인정보와 필요한 권한';

  @override
  String get storeVersionsInstalledHeader => '설치된 버전';

  @override
  String get storeVersionsDefault => '기본 버전';

  @override
  String storeVersionsUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '계정 $count개가 사용 중',
    );
    return '$_temp0';
  }

  @override
  String storeVersionsInstalledOn(int year, int month, int day) {
    return '설치일 $year/$month/$day';
  }

  @override
  String get storeMenu => '메뉴';

  @override
  String get storeVersionsMakeDefault => '기본 버전으로 설정';

  @override
  String get storeVersionsRemove => '이 버전 삭제';

  @override
  String storeVersionsRemoved(String version) {
    return '$version을(를) 삭제했습니다';
  }

  @override
  String get storeVersionsOthersHeader => '다른 버전 설치';

  @override
  String get storeVersionsMorePermissions => '권한이 늘어납니다';

  @override
  String get storeVersionsInstall => '설치';

  @override
  String get storeVersionsPerAccountHeader => '계정별';

  @override
  String get storeVersionsPerAccountCaption => '계정마다 사용할 버전을 고를 수 있습니다';

  @override
  String get storeVersionsPerAccountDetail =>
      '그 계정을 사용하는 동안 슬롯 플러그인과 노드 정렬은 여기서 고른 버전으로 동작합니다.';

  @override
  String storeVersionsFollowDefault(String version) {
    return '기본값 따르기 ($version)';
  }

  @override
  String storeVersionsAccountFollows(String account) {
    return '$account은(는) 기본 버전을 따릅니다';
  }

  @override
  String storeVersionsAccountUses(String account, String version) {
    return '$account은(는) $version을(를) 사용합니다';
  }

  @override
  String storeVersionsDefaultShort(String version) {
    return '기본 ($version)';
  }

  @override
  String get storeVersionsPackNote =>
      '테마 / 스티커·소재는 기기 전체에서 하나의 버전(기본 버전)을 사용합니다.';

  @override
  String get storeUpdateModeAuto => '자동';

  @override
  String get storeUpdateModeAutoDescription =>
      '새 버전을 설치하고 기본 버전으로 합니다(계정별로 지정한 버전은 그대로)';

  @override
  String get storeUpdateModeInstallOnly => '설치만 자동';

  @override
  String get storeUpdateModeInstallOnlyDescription =>
      '새 버전을 설치만 해 두고 사용하는 버전은 바꾸지 않습니다';

  @override
  String get storeUpdateModeManual => '모두 수동으로 구성';

  @override
  String get storeUpdateModeManualDescription =>
      '자동으로는 아무것도 하지 않습니다(플러그인 관리에서 설치)';

  @override
  String get storeUpdateGroupSns => 'SNS 플러그인';

  @override
  String get storeUpdateGroupAction => '액션 플러그인';

  @override
  String get storeUpdateGroupView => '뷰 플러그인';

  @override
  String storeUpdateLogActivated(String from, String to) {
    return '$from → $to (기본 버전으로 함)';
  }

  @override
  String storeUpdateLogInstalled(String from, String to) {
    return '$to을(를) 설치했습니다 (사용 버전은 $from 그대로)';
  }

  @override
  String storeUpdateLogSwitched(String from, String to) {
    return '$from → $to (설치되어 있던 버전을 기본으로)';
  }

  @override
  String storeUpdateLogSkipped(String to) {
    return '$to은(는) 자동으로 설치하지 않습니다';
  }

  @override
  String storeUpdateLogSkippedNote(String to, String note) {
    return '$to은(는) 자동으로 설치하지 않습니다 ($note)';
  }

  @override
  String storeUpdateLogFailed(String to) {
    return '$to을(를) 설치하지 못했습니다';
  }

  @override
  String storeUpdateLogFailedNote(String to, String note) {
    return '$to을(를) 설치하지 못했습니다 ($note)';
  }

  @override
  String get storeUpdatePopupTitle => '플러그인을 업데이트했습니다';

  @override
  String get storeClose => '닫기';

  @override
  String get storeReviewsTitle => '리뷰';

  @override
  String get storeReviewsLoadFailed => '리뷰를 가져오지 못했습니다';

  @override
  String get storeReviewWrite => '리뷰 쓰기';

  @override
  String get storeReviewsEmpty => '아직 리뷰가 없습니다';

  @override
  String get storeReviewsEmptyHint => '오른쪽 아래 +에서 첫 리뷰를 쓸 수 있습니다';

  @override
  String get storeCopyLink => '링크 복사';

  @override
  String get storeReviewReport => '리뷰 신고';

  @override
  String get storeReviewLinkCopied => '리뷰 링크를 복사했습니다';

  @override
  String get storeReviewReportUnavailable => '리뷰 신고는 준비 중입니다';

  @override
  String storeReloadFailed(String error) {
    return '다시 불러오지 못했습니다: $error';
  }

  @override
  String get storeNoNewPlugins => '새로 공개된 플러그인이 없습니다';

  @override
  String storeNewPluginsAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '새로 공개된 플러그인 $count개를 추가했습니다',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchTitle => '플러그인 검색';

  @override
  String get storeSearchRecentPick => '최근 게시물 내용에서 선정';

  @override
  String get storeSearchFailed => '검색하지 못했습니다';

  @override
  String get storeSearchNoRecentPosts => '최근 게시물을 찾지 못했습니다';

  @override
  String get storeSearchNoRecentPostsHint =>
      'SNS 계정으로 게시하면 그 내용에 가까운 플러그인을 고릅니다';

  @override
  String storeSearchRecentCaption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '최근 게시물 $count건의 내용에 가까운 순 (기기 안에서 고르고 있습니다)',
    );
    return '$_temp0';
  }

  @override
  String get storeSearchNoRecentMatches => '최근 게시물에 가까운 플러그인을 찾지 못했습니다';

  @override
  String get storeSearchNoResults => '결과가 없습니다';

  @override
  String get storeSearchNoResultsHint => '단어나 필터를 바꿔 보세요';

  @override
  String get storeHomeTitle => '플러그인 스토어';

  @override
  String get storeConnectFailed => '스토어에 연결하지 못했습니다';

  @override
  String get storeHomeOffline => 'RASQ 서버에 연결되어 있지 않습니다. 앱에 들어 있는 플러그인만 표시합니다';

  @override
  String get storeHomeOfflineDetail =>
      'Central 미연결: 동봉된 실물(Misskey 커넥터와 슬롯 샘플)만. 평가 / 다운로드 수 / 리뷰 / 구매는 서버에 연결하면 표시됩니다.';

  @override
  String get storeHomeTrending => '이번 주 트렌드';

  @override
  String get storeHomeRecent => '신규';

  @override
  String get storeHomeReviewedOnly => '심사를 마친 플러그인만 게재됩니다';

  @override
  String get storeHomeReviewedOnlyDetail =>
      '개발 중인 플러그인은 개발자 모드에서 오른쪽 위 톱니바퀴 → 플러그인 관리 → \'플러그인 가져오기\'에서 설치할 수 있습니다.';

  @override
  String get storeRowEmpty => '지금은 표시할 수 있는 플러그인이 없습니다';

  @override
  String get storeInstallManifestUnavailable => '구성을 가져오지 못했습니다';

  @override
  String storeInstallSheetTitle(String name, String version) {
    return '$name $version 설치';
  }

  @override
  String get storeInstallPermissionsHeader => '이 플러그인이 사용하는 권한';

  @override
  String get storeInstallHostsHeader => '연결 대상';

  @override
  String get storeInstallLoginInstance => '로그인한 인스턴스';

  @override
  String get storeInstallScopeNoRecord => '허용할 내용 (이전 설치 기록이 없습니다)';

  @override
  String get storeInstallScopeWidened => '마지막으로 허용한 내용에서 넓어지는 것';

  @override
  String get storeInstallPermissionsAdded => '이전 버전에서 늘어난 권한';

  @override
  String storeInstallBundleSummary(String size, String signature) {
    return '${size}MB · $signature';
  }

  @override
  String get storeInstallSignedShort => '스토어 서명 있음';

  @override
  String get storeInstallUnsignedShort => '스토어 서명 없음';

  @override
  String storeInstallBundleDetail(
    String size,
    String sha512,
    String signature,
  ) {
    return '배포물: ${size}MB · SHA-512 $sha512… · $signature';
  }

  @override
  String get storeInstallSignedDetail => '스토어 서명 있음 (ed25519)';

  @override
  String get storeInstallUnsignedDetail => '스토어 서명 없음 (해시 대조만)';

  @override
  String get storeInstallConfirm => '설치';

  @override
  String storeInstallThemeDarkOnly(String name) {
    return '$name을(를) 사용합니다. 다크 모드일 때 적용됩니다';
  }

  @override
  String storeInstallThemeLightOnly(String name) {
    return '$name을(를) 사용합니다. 라이트 모드일 때 적용됩니다';
  }

  @override
  String storeInstallThemeApplied(String name) {
    return '$name을(를) 사용합니다';
  }

  @override
  String storeInstallDone(String name, String version) {
    return '$name $version을(를) 설치했습니다';
  }

  @override
  String storeVersionScopeTitle(String version) {
    return 'Ver.$version은(는) 허용하는 내용이 넓어집니다';
  }

  @override
  String get storeVersionScopeConfirm => '허용하고 사용';

  @override
  String get storeVersionScopeCancel => '취소';

  @override
  String storePurchasePointsFailed(String error) {
    return '포인트를 확인하지 못했습니다(RASQ 계정에 로그인했나요?): $error';
  }

  @override
  String storePurchaseTitle(String name) {
    return '$name 구매';
  }

  @override
  String storePurchasePrice(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count포인트',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalance(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '잔여 $count포인트',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseBalanceExpiring(int count, String date, int expiring) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '잔여 $count포인트 · $date에 $expiring포인트 만료',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseCaption => '구매한 플러그인은 같은 계정이라면 어느 기기에서든 사용할 수 있습니다';

  @override
  String get storePurchaseCaptionDetail =>
      '구매한 플러그인은 같은 RASQ 계정이라면 어느 기기에서든 설치할 수 있습니다. 포인트는 유효기간이 가까운 것부터 사용합니다.';

  @override
  String storePurchaseBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count포인트로 구매',
    );
    return '$_temp0';
  }

  @override
  String storePurchaseShort(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '포인트가 부족합니다 ($count포인트 부족)',
    );
    return '$_temp0';
  }

  @override
  String get storePurchaseConsole => '웹 콘솔에서 포인트 구매';

  @override
  String get storePurchaseFailed => '구매하지 못했습니다';

  @override
  String storeReleaseNotesSemantics(String version) {
    return '릴리스 노트 $version';
  }

  @override
  String get storeReleaseBeta => '프리뷰 버전 (β)';

  @override
  String get storeReleaseStable => '안정 버전';

  @override
  String storeReleasePublishedOn(int year, int month, int day) {
    return '$year/$month/$day 공개';
  }

  @override
  String get storeReleaseCurrentListing => '현재 게재 버전';

  @override
  String get storeReleaseInstalled => '설치됨';

  @override
  String get storeReleaseNoNotes => '이 버전의 릴리스 노트가 없습니다.';

  @override
  String get storeReleasePermissionsAdded => '이 버전에서 늘어난 권한';

  @override
  String get storeReleasePermissionsNote =>
      '권한이 늘어나는 업데이트는 자동 업데이트 대상이 아닙니다. 내용을 확인한 뒤 설치해 주세요.';

  @override
  String storeReleaseAlreadyInstalled(String version) {
    return 'Ver.$version 설치됨';
  }

  @override
  String storeReleaseBlocked(String status) {
    return '$status 상태이므로 설치할 수 없습니다';
  }

  @override
  String storeReleaseInstall(String version) {
    return 'Ver.$version 설치';
  }

  @override
  String storeReleaseReplaces(String version) {
    return '현재 v$version이(가) 설치되어 있습니다. 이 버전으로 교체됩니다.';
  }

  @override
  String get storeReviewNoVotes => '아직 평가가 없습니다';

  @override
  String storeReviewHelpfulCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명이 도움이 되었다고 생각했습니다.',
    );
    return '$_temp0';
  }

  @override
  String get storeShare => '공유';

  @override
  String get storeReviewHelpful => '도움이 됨';

  @override
  String get storeReviewNotHelpful => '도움이 안 됨';

  @override
  String get storeReviewAnonymous => '익명';

  @override
  String get storeReviewVerifiedUse => '실사용 확인';

  @override
  String storeReviewDeveloperReply(String reply) {
    return '개발자 답글: $reply';
  }

  @override
  String get storeReviewNoBody => '(본문 없음)';

  @override
  String get storeReviewComposeTitle => '리뷰 작성';

  @override
  String get storeReviewSend => '보내기';

  @override
  String get storeRatingLabel => '평가';

  @override
  String get storeReviewTitleHint => '제목 (선택)';

  @override
  String get storeReviewBodyHint => '사용감이나 신경 쓰인 점을 입력해 주세요';

  @override
  String storeReviewUsedVersion(String version) {
    return '사용 버전: v$version';
  }

  @override
  String get storeReviewPickRating => '★를 선택해 주세요';

  @override
  String get storeReviewSent => '리뷰를 보냈습니다';

  @override
  String storeReviewSendFailed(String error) {
    return '리뷰를 보내지 못했습니다: $error';
  }

  @override
  String get storeReviewNeedsInstall => '설치한 플러그인에만 리뷰를 쓸 수 있습니다';

  @override
  String get storeReviewNeedsInstallServer =>
      '설치한 플러그인에만 리뷰를 쓸 수 있습니다. 로그인한 상태로 다시 설치(또는 업데이트)하면 쓸 수 있게 됩니다';

  @override
  String get storeSafetyNoPermissions => '필요한 권한: 없음';

  @override
  String get storeSafetyExternalHeader => '외부 통신과 데이터';

  @override
  String get storeSafetyNoHosts => '외부 통신 대상: 없음';

  @override
  String storeSafetyHosts(String hosts) {
    return '외부 통신 대상: $hosts';
  }

  @override
  String storeSafetyDataHandling(String text) {
    return '데이터 취급: $text';
  }

  @override
  String storeSafetySdks(String sdks) {
    return '외부 SDK: $sdks';
  }

  @override
  String get storeSafetyRuntimeHeader => '실행 환경';

  @override
  String storeSafetyCrashFree(String rate) {
    return '정상 실행률 $rate%';
  }

  @override
  String get storeSafetyBackground => '백그라운드 실행 있음';

  @override
  String get storeSafetyNoBackground => '백그라운드 실행 없음';

  @override
  String get storeSafetyGpu => 'GPU 사용';

  @override
  String get storeSafetyNoGpu => 'GPU 미사용';

  @override
  String get storeSafetyNoAds => '광고 없음';

  @override
  String storeSafetyAds(String placements) {
    return '광고 있음 ($placements)';
  }

  @override
  String get storePageMenuPostReview => '리뷰 게시';

  @override
  String get storePageMenuReport => '플러그인 신고';

  @override
  String get storePageLinkCopied => '스토어 페이지 링크를 복사했습니다';

  @override
  String get storePageTitle => '플러그인';

  @override
  String get storePageMaybeWithdrawn => '철회되었을 수 있습니다';

  @override
  String get storePageOpenInstalled => '설치된 정보 보기';

  @override
  String get storePageRequiresPrefix => '이 플러그인을 사용하려면 ';

  @override
  String get storePageRequiresSuffix => '을(를) 설치해야 합니다.';

  @override
  String storePageInstalledVersion(String version) {
    return '설치됨 v$version';
  }

  @override
  String storePageInstalledVersionVerified(String version) {
    return '설치됨 v$version (SHA-512 검증됨)';
  }

  @override
  String get storeFree => '무료';

  @override
  String storePriceYen(String amount) {
    return '¥$amount';
  }

  @override
  String get storePageInstall => '설치';

  @override
  String storePageBuy(String amount) {
    return '¥$amount에 구매';
  }

  @override
  String get storePageThemeInUse => '사용 중';

  @override
  String get storePageThemeUse => '사용';

  @override
  String get storePageUnknownDeveloper => '제공자 불명';

  @override
  String storePageRatingDownloads(String rating, String downloads) {
    return '★$rating · $downloads 다운로드';
  }

  @override
  String storePageStatus(String status) {
    return '상태: $status';
  }

  @override
  String get storePagePreview => '미리보기';

  @override
  String get storePageDownloadsLastMonth => '지난달 다운로드 수';

  @override
  String storePageReviewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count건',
    );
    return '$_temp0';
  }

  @override
  String get storePageReviewsEmptyBody => '첫 리뷰를 써 보지 않겠어요?';

  @override
  String get storePageUpdatesHeader => '업데이트와 버전';

  @override
  String get storePageNoReleaseNotes => '아직 릴리스 노트가 없습니다.';

  @override
  String get storeInUse => '사용 중';

  @override
  String storePermissionsAddedList(String permissions) {
    return '권한 추가: $permissions';
  }

  @override
  String get storePagePermissionsHeader => '권한';

  @override
  String get storePageNoPermissions => '이 플러그인은 추가 권한을 요구하지 않습니다.';

  @override
  String get storePageCompatibilityHeader => '호환성';

  @override
  String storePageRuntimes(String runtimes) {
    return '런타임: $runtimes';
  }

  @override
  String storePageRequiredPlugins(String plugins) {
    return '필요 플러그인: $plugins';
  }

  @override
  String storePageConflicts(String plugins) {
    return '충돌: $plugins';
  }

  @override
  String storePageRasqFeatures(String features) {
    return '사용하는 RASQ 기능: $features';
  }

  @override
  String get storePageVersionsTitle => '버전';

  @override
  String storePageNoPreview(String name) {
    return '$name의 미리보기 이미지가 아직 없습니다';
  }

  @override
  String get storePageBookmarkRemove => '북마크 해제';

  @override
  String get storePageBookmarkAdd => '북마크';

  @override
  String storePageBookmarkFailed(String error) {
    return '북마크를 업데이트하지 못했습니다: $error';
  }

  @override
  String storeNeedsServer(String feature) {
    return '$feature은(는) RASQ 서버에 연결하면 사용할 수 있습니다';
  }

  @override
  String get storeNoListing => '게재가 없습니다';

  @override
  String get storeCatalogMisskeyName => 'Misskey 커넥터';

  @override
  String get storeCatalogMisskeySummary =>
      'Misskey를 RASQ에 연결하는 SNS 플러그인(wasm 샘플). 타임라인 가져오기, 게시, 리액션, 이모지, 게시물 가공까지 모두 지원합니다.';

  @override
  String get storeCatalogMisskeyDescription =>
      'rasq-sdk-sample의 Rust로 만든 wasm 플러그인입니다. sns.login / sns.timeline / post.transform / tl.sort 등의 계약(PROTOCOL.md)을 구현하고 RRL 타일로 타임라인을 그립니다. 노드 정의가 없는 게시물 가공은 가져오기 노드에 넘기기 직전에 적용됩니다.';

  @override
  String get storeCatalogFeatureTimelineRrl => '타임라인 렌더링 (RRL)';

  @override
  String get storeCatalogFeatureNodeGraph => '노드 그래프 (tl.sort)';

  @override
  String get storeCatalogMisskeyPerm1 =>
      'Misskey 인스턴스의 API를 호출하기 위해(접속 대상은 로그인할 때 지정한 호스트뿐)';

  @override
  String get storeCatalogMisskeyPerm2 => '세션 토큰과 타임라인 설정 저장';

  @override
  String get storeCatalogMisskeyHost => '<로그인한 Misskey 인스턴스>';

  @override
  String get storeCatalogMisskeyDataHandling =>
      '게시물과 토큰은 기기 안(storage.safe)에만 저장됩니다. 개발자에게 전송하지 않습니다.';

  @override
  String get storeCatalogSampleDataHandling =>
      '처리는 기기 안의 wasm에서 모두 이루어지며 외부로 전송하지 않습니다.';

  @override
  String get storeCatalogAstellName => 'ASTell 효과음·효과 영상';

  @override
  String get storeCatalogAstellSummary =>
      'ASTell의 플러그인 액션에서 효과음 / 생성한 효과 영상 / 정형 텍스트를 내보냅니다.';

  @override
  String get storeCatalogAstellDescription =>
      '슬롯 `astell.action`. 룸 하단에 이 플러그인이 선언한 버튼으로 FOW를 열고, 시스템 사운드(딩동 / 클릭), 생성한 색종이·불꽃놀이·박수 PNG, 정형 텍스트를 공유합니다. \'ASTell로 공유\'한 게시물을 받은 것도 표시합니다.';

  @override
  String get storeCatalogFeatureAstellAction => 'ASTell 플러그인 액션';

  @override
  String get storeCatalogAstellPerm1 => '조작 패널(FOW)을 표시하기 위해';

  @override
  String get storeCatalogAstellPerm2 => '효과 사용 횟수 저장';

  @override
  String get storeCatalogComposerMediaName => '미디어 가공';

  @override
  String get storeCatalogComposerMediaSummary =>
      '첨부 이미지의 감마 보정 / 회전 / 색조 / 자르기.';

  @override
  String get storeCatalogComposerMediaDescription =>
      '슬롯 `composer.media`. 작성 화면의 첨부 타일에서 \'플러그인으로 가공\'을 눌러 FOW를 열고, 미리보기를 보면서 적용합니다. 처리는 기기 안의 wasm에서만 이루어집니다.';

  @override
  String get storeCatalogFeatureMediaComposer => '미디어 컴포저';

  @override
  String get storeCatalogComposerMediaPerm1 => '가공 패널(FOW)을 표시하기 위해';

  @override
  String get storeCatalogComposerMediaPerm2 => '이전 설정 저장';

  @override
  String get storeCatalogComposerTextName => '해시태그 추천';

  @override
  String get storeCatalogComposerTextSummary =>
      '본문에 #을 입력하면 추천이 나오고, 탭하면 삽입합니다.';

  @override
  String get storeCatalogComposerTextDescription =>
      '슬롯 `composer.text`. 본문 변경을 받아 커서 바로 앞이 #… 일 때 추천 FOW(최근 사용한 태그 + 사전)를 표시합니다.';

  @override
  String get storeCatalogFeatureTextComposer => '텍스트 컴포저';

  @override
  String get storeCatalogComposerTextPerm1 => '추천 패널(FOW)을 표시하기 위해';

  @override
  String get storeCatalogComposerTextPerm2 => '최근 사용한 태그 저장';

  @override
  String get storeCatalogMediaFullscreenName => 'QR 코드 감지';

  @override
  String get storeCatalogMediaFullscreenSummary =>
      '전체 화면 이미지에서 QR 코드를 찾아 테두리를 표시하고, 탭하면 링크를 열 수 있습니다.';

  @override
  String get storeCatalogMediaFullscreenDescription =>
      '슬롯 `viewer.overlay`. 전체 화면 뷰어의 이미지를 받아 QR을 감지하고 바운딩 박스를 겹쳐 표시합니다. 탭하면 링크 FOW(복사 / 브라우저에서 열기 / 뮤트 단어에 추가).';

  @override
  String get storeCatalogFeatureViewerPlugin => '전체 화면 표시 플러그인';

  @override
  String get storeCatalogMediaFullscreenPerm1 => '링크 패널(FOW)을 표시하기 위해';

  @override
  String get storeCatalogMediaFullscreenPerm2 =>
      '\'이 링크 뮤트\'로 뮤트 단어에 추가하기 위해(매번 확인)';

  @override
  String get storeCatalogPostProcessName => '상대 날짜를 날짜로';

  @override
  String get storeCatalogPostProcessSummary =>
      '\'오늘\', \'어제\', \'내일\'을 게시일 기준 날짜로 바꿉니다.';

  @override
  String get storeCatalogPostProcessDescription =>
      '슬롯 `post.transform`. 모든 타임라인에 표시하기 직전에 본문의 상대 날짜를 \'9/10(오늘)\'처럼 바꿉니다(JST). URL 안은 건드리지 않습니다.';

  @override
  String get storeCatalogFeaturePostTransform => '게시물 가공 (post.transform)';

  @override
  String get storeCatalogTimelineName => 'Unicode 오름차순 타임라인';

  @override
  String get storeCatalogTimelineSummary => '홈에 본문의 Unicode 순으로 정렬되는 탭을 추가합니다.';

  @override
  String get storeCatalogTimelineDescription =>
      '슬롯 `tl`. 기본 타임라인(홈)을 받아 본문의 Unicode 코드 포인트 오름차순으로 정렬한 사용자 지정 탭을 표시합니다.';

  @override
  String get storeCatalogFeatureTimelineSort => '타임라인 (tl.sort)';

  @override
  String get storeCatalogPostShareName => '공유 템플릿';

  @override
  String get storeCatalogPostShareSummary =>
      '공유 FOW에서 게시물을 템플릿(링크 / 인용 / 작성자 언급)으로 정리해 작성 화면으로 보냅니다.';

  @override
  String get storeCatalogPostShareDescription =>
      '슬롯 `post.share`. 게시물 공유 FOW의 \'플러그인\' 섹션에 자동으로 표시되며, 탭하면 인라인 FOW에서 문구를 골라 작성 화면 / 복사 / 브라우저 / ASTell로 넘깁니다.';

  @override
  String get storeCatalogFeaturePostShare => '게시물 공유 (post.share)';

  @override
  String get storeCatalogPostSharePerm1 => '템플릿 선택 패널(FOW)을 표시하기 위해';

  @override
  String get storeCatalogPostSharePerm2 => '이전 템플릿 저장';

  @override
  String get storeCatalogMediaTransformName => '변형 핸들';

  @override
  String get storeCatalogMediaTransformSummary =>
      '이미지 위에 회전 / 자르기 핸들을 겹쳐 편집합니다.';

  @override
  String get storeCatalogMediaTransformDescription =>
      '슬롯 `composer.media`(변형). 미디어 편집기의 미리보기에 RRL 오버레이(계약 v0.5 `composer.media.overlay`)로 핸들을 그리고, 손가락으로 따라 그려 회전 각도나 자르기 범위를 정합니다.';

  @override
  String get storeCatalogFeatureOverlay => '오버레이 (overlay)';

  @override
  String get storeCatalogMediaTransformPerm1 => '패널(FOW)을 표시하기 위해';

  @override
  String get storeCatalogMediaProcessName => '가공(얼굴 흐림 / 스탬프)';

  @override
  String get storeCatalogMediaProcessSummary =>
      '얼굴을 감지해 흐리게 하고, 스탬프를 오브젝트로 붙입니다(이동 / 확대·축소 / 회전 / 삭제 / 복제).';

  @override
  String get storeCatalogMediaProcessDescription =>
      '슬롯 `composer.media`(가공). 얼굴 감지는 기기 안의 wasm(rustface)에서 이루어지며 외부로 전송하지 않습니다. 스탬프는 오버레이의 테두리와 핸들로 움직일 수 있습니다.';

  @override
  String get storeCatalogMediaProcessPerm1 => '스탬프 선택 패널(FOW)을 표시하기 위해';

  @override
  String get storeCatalogMediaDrawName => '그리기(펜 / 도형)';

  @override
  String get storeCatalogMediaDrawSummary =>
      '펜의 궤적을 스플라인 곡선으로 그리고, 사각형 / 원을 추가해 편집합니다.';

  @override
  String get storeCatalogMediaDrawDescription =>
      '슬롯 `composer.media`(그리기). 펜은 손가락 궤적을 Catmull-Rom 스플라인으로 매끄럽게 그립니다. 도형은 오브젝트로 이동 / 확대·축소 / 삭제 / 복제할 수 있습니다.';

  @override
  String get storeCatalogMediaDrawPerm1 => '펜 굵기 / 색상 패널(FOW)을 표시하기 위해';

  @override
  String get storeCatalogMediaDrawPerm2 => '펜 설정 저장';

  @override
  String get storeCatalogPostActionName => '게시물 버튼';

  @override
  String get storeCatalogPostActionSummary =>
      '나중에 읽기 / 본문 복사 / 인용 초안 — 태그에 따라 기존 버튼 묶음에 들어갑니다.';

  @override
  String get storeCatalogPostActionDescription =>
      '슬롯 `post.action`. 매니페스트의 태그(희망 슬롯)가 기존 액션 버튼에 가까우면 그 묶음의 맨 아래에 자동으로 들어갑니다. \'액션 목록 편집\'에서 계정별로 사용 / 사용 안 함과 임계값을 바꿀 수 있습니다.';

  @override
  String get storeCatalogFeaturePostAction => '게시물 액션 버튼 (post.action)';

  @override
  String get storeCatalogPostActionPerm1 => '나중에 읽기 목록(FOW)을 표시하기 위해';

  @override
  String get storeCatalogPostActionPerm2 => '나중에 읽기 저장';

  @override
  String get storeCatalogThemeStarryName => '테마 \'별하늘\'';

  @override
  String get storeCatalogThemeStarrySummary =>
      '밤하늘 배경, 별 입자를 겹친 게시물 타일, 별 모양 좋아요.';

  @override
  String get storeCatalogThemeStarryDescription =>
      '테마(`kind: \"theme\"`, 계약 v0.16). 코드가 없는 배포물로, 색상 / 아이콘 교체 / 화면·게시물 타일·FOW·버튼 배경의 이미지 레이어를 선언합니다. 설치 후 설정 → 앱 외관 → 글꼴 및 색 구성표에서 선택합니다(다크 모드일 때 적용).';

  @override
  String get storeCatalogFeatureTheme => '테마';

  @override
  String get storeCatalogThemeRasqName => '테마 \'RASQ\'';

  @override
  String get storeCatalogThemeRasqSummary =>
      '게시물 위에 남색 그라데이션 띠와 옅은 RASQ 마크, FOW는 초록색 그라데이션.';

  @override
  String get storeCatalogThemeRasqDescription =>
      '테마(`kind: \"theme\"`, 계약 v0.17). 게시물 타일 윗변에 #1F1E33에서 게시물 배경색으로 녹아드는 그라데이션 띠, 배경에 옅은 RASQ 마크, FOW 배경은 위에서 아래로 #02775C → #178178 그라데이션(글자는 흰색). 라이트 / 다크 모드 모두 적용됩니다.';

  @override
  String get storeCatalogPaintName => '다 함께 낙서';

  @override
  String get storeCatalogPaintSummary =>
      '한 사람당 한 칸의 낙서를 기한을 정해 서로 보여 줍니다. ASTell 룸이나 프로필에서.';

  @override
  String get storeCatalogPaintDescription =>
      '사용자 지정 플러그인(슬롯 `page`, 계약 v0.23). 3:4 칸을 2열로 배치하고(순서는 사람마다 섞임), 자기 칸을 누르면 미디어 편집 화면의 SVG 모드로 낙서합니다(저장 시 zstd로 압축해 보냄). 표시 기간은 각자가 고르고, 관리자(세션 소유자)가 기본값과 상한을 정합니다. 기한이 되면 Central이 삭제합니다. 관리자는 다른 사람의 낙서를 삭제할 수 있습니다.';

  @override
  String get storeCatalogFeatureCustomPage => '사용자 지정 플러그인 (page)';

  @override
  String get storeCatalogFeatureSvgPaint => 'SVG 낙서';

  @override
  String get storeCatalogFeatureDisplayPeriod => '표시 기간';

  @override
  String get storeCatalogFeatureProfile => '프로필';

  @override
  String get storeCatalogPaintPerm1 => '낙서 칸을 표시하고 편집 화면을 열기 위해';

  @override
  String get storeCatalogPaintPerm2 => '모두의 낙서와 관리자의 설정을 기한을 정해 공유하기 위해';

  @override
  String get storeCatalogBoardName => '모두의 보드';

  @override
  String get storeCatalogBoardSummary =>
      '카운터·투표·롤링페이퍼·🎉. ASTell 룸이나 프로필에서 모두가 같은 보드를 쓸 수 있습니다.';

  @override
  String get storeCatalogBoardDescription =>
      '사용자 지정 플러그인(슬롯 `page`, 계약 v0.18). 페이지를 1장 추가하고, 공유 세션에서는 서버 변수(카운터 / 투표 / 롤링페이퍼)와 서버 함수(모두에게 🎉)로 같은 화면을 공유합니다. 세션이 없을 때는 기기 안에서만 동작합니다.';

  @override
  String get storeCatalogBoardPerm1 => '페이지를 그리기 위해';

  @override
  String get storeCatalogBoardPerm2 => '모두의 값(카운터 / 투표 / 롤링페이퍼)을 공유하기 위해';

  @override
  String get storeCatalogBoardPerm3 => '혼자 쓸 때의 보드 저장';

  @override
  String get storeCatalogTrendName => '트렌드 추천';

  @override
  String get storeCatalogTrendSummary => '지금의 트렌드 단어에서 관련 태그를 로컬 규칙으로 추천합니다.';

  @override
  String get storeCatalogTrendDescription =>
      '슬롯 `trend.suggest`. 타임라인 노드(트렌드 가져오기 / Today / 추천 칩)와 검색 홈의 \'검색 추천\'에 표시합니다. 서버 없는 동시 출현 사전 + 접두사 일치입니다.';

  @override
  String get storeCatalogFeatureTrendSuggest => '트렌드 (trend.suggest)';

  @override
  String storePkgMissingPlugin(String id) {
    return '배포물에 $id이(가) 없습니다';
  }

  @override
  String get storePkgNotPackage => '배포물이 .rasqpkg(zstd)가 아닙니다';

  @override
  String storePkgUnpack(String error) {
    return '배포물을 풀 수 없습니다(손상되었거나 너무 큽니다): $error';
  }

  @override
  String storePkgTar(String error) {
    return '배포물의 tar를 읽을 수 없습니다: $error';
  }

  @override
  String get storePkgTooManyFiles => '배포물의 파일 수가 너무 많습니다';

  @override
  String storePkgNotRegularFile(String path) {
    return '배포물에 일반 파일이 아닌 것이 있습니다: $path';
  }

  @override
  String storePkgDuplicatePath(String path) {
    return '배포물 내 경로가 중복되었습니다: $path';
  }

  @override
  String get storePkgBundleFirst => '배포물의 첫 항목이 bundle.json이 아닙니다';

  @override
  String storePkgBundleRead(String error) {
    return 'bundle.json을 읽을 수 없습니다: $error';
  }

  @override
  String storePkgBundleSchema(String schema) {
    return 'bundle.json의 schema가 rasq.bundle/1이 아닙니다: $schema';
  }

  @override
  String storePkgFileShape(String what) {
    return 'bundle.json: $what의 wasm / file 형식이 다릅니다';
  }

  @override
  String storePkgNoPath(String what) {
    return 'bundle.json: $what에 path가 없습니다';
  }

  @override
  String storePkgSizeMismatch(String path) {
    return '$path: 크기가 목차와 다릅니다';
  }

  @override
  String storePkgHashMismatch(String path) {
    return '$path: SHA-512가 목차와 다릅니다';
  }

  @override
  String storePkgNoSha512(String what) {
    return 'bundle.json: $what에 sha512가 없습니다';
  }

  @override
  String storePkgNotWasm(String path) {
    return '$path: wasm이 아닙니다';
  }

  @override
  String storePkgPluginShape(String what) {
    return 'bundle.json: $what의 형식이 다릅니다';
  }

  @override
  String storePkgBadId(String what, String id) {
    return 'bundle.json: $what의 id가 올바르지 않습니다: $id';
  }

  @override
  String storePkgBadVersion(String id, String version) {
    return 'bundle.json: $id의 version이 올바르지 않습니다: $version';
  }

  @override
  String storePkgBadKind(String id, String kind) {
    return 'bundle.json: $id의 kind가 올바르지 않습니다: $kind';
  }

  @override
  String storePkgNoManifest(String id) {
    return 'bundle.json: $id에 manifest가 없습니다';
  }

  @override
  String storePkgManifestRead(String path, String error) {
    return '$path을(를) 읽을 수 없습니다: $error';
  }

  @override
  String storePkgManifestMismatch(
    String path,
    String id,
    String version,
    String kind,
  ) {
    return '$path: id / version / kind가 목차($id $version $kind)와 다릅니다';
  }

  @override
  String storePkgChildPackKind(String id, String kind) {
    return 'bundle.json: 하위 $id은(는) kind = $kind일 수 없습니다';
  }

  @override
  String storePkgPackHasWasm(String kind, String id) {
    return 'bundle.json: $kind $id에 wasm이 있습니다';
  }

  @override
  String storePkgMissingKey(String key) {
    return 'bundle.json: $key이(가) 없습니다';
  }

  @override
  String get storePkgChildrenNotSns =>
      'bundle.json: sns 이외의 root는 children을 가질 수 없습니다';

  @override
  String storePkgChildPrefix(String id, String root) {
    return 'bundle.json: 하위 $id의 id가 $root.(으)로 시작하지 않습니다';
  }

  @override
  String storePkgChildSns(String id) {
    return 'bundle.json: 하위 $id은(는) kind = sns일 수 없습니다';
  }

  @override
  String get storePkgDuplicateId => 'bundle.json: 플러그인 id가 중복되었습니다';

  @override
  String get storePkgLibsShape => 'bundle.json: libs의 형식이 다릅니다';

  @override
  String get storePkgAssetsShape => 'bundle.json: assets의 형식이 다릅니다';

  @override
  String get storePkgPackExtras =>
      'bundle.json: 에셋 팩 / 테마는 children / libs / models를 가질 수 없습니다';

  @override
  String get storePkgPackWasm => '에셋 팩 / 테마에 wasm이 들어 있습니다';

  @override
  String storePkgPackImageCount(int max, int count) {
    return '에셋 팩의 이미지는 1~$max장이어야 합니다: $count';
  }

  @override
  String storePkgNotImage(String path) {
    return '$path: 이미지(PNG / JPEG / WebP / GIF)가 아닙니다';
  }

  @override
  String storePkgImageTooLarge(String path, int mib) {
    return '$path: 너무 큽니다(1장당 $mib MiB까지)';
  }

  @override
  String storePkgAssetNotListed(String path) {
    return 'manifest.assets의 $path이(가) 배포물 목차에 없습니다';
  }

  @override
  String get storePkgModelsShape => 'bundle.json: models의 형식이 다릅니다';

  @override
  String get storePkgRequiresShape => 'bundle.json: requires의 형식이 다릅니다';

  @override
  String get storePkgNoSums => 'SHA512SUMS가 없습니다';

  @override
  String storePkgSumsMissingFile(String path) {
    return '$path: SHA512SUMS에는 있지만 안에 없습니다';
  }

  @override
  String storePkgSumsMismatch(String path) {
    return '$path: SHA512SUMS와 다릅니다';
  }

  @override
  String storePkgUnlisted(String path) {
    return '$path: 목차에 없는 파일이 있습니다';
  }

  @override
  String get storePkgThemeMissing => '테마 매니페스트에 theme가 없습니다';

  @override
  String storePkgThemeAsset(String where, String id) {
    return 'theme.$where의 이미지 $id이(가) assets(use: theme)에 없습니다';
  }

  @override
  String storePkgThemeSurface(String surface) {
    return 'theme.surfaces의 $surface은(는) 사용할 수 없습니다(app / postTile / fow / actionButton)';
  }

  @override
  String storePkgThemeLayer(String surface) {
    return 'theme.surfaces.$surface.layers: asset 또는 gradient 중 하나만 작성해 주세요';
  }

  @override
  String storePkgThemeColors(String surface) {
    return 'theme.surfaces.$surface.layers: gradient.colors는 2~8색이어야 합니다';
  }

  @override
  String storePkgThemeStops(String surface) {
    return 'theme.surfaces.$surface.layers: gradient.stops는 colors와 같은 개수여야 합니다';
  }

  @override
  String storePkgBadPath(String path) {
    return '배포물 내 경로로 사용할 수 없습니다: $path';
  }

  @override
  String storePkgSigAlg(String alg) {
    return '서명의 alg가 ed25519가 아닙니다: $alg';
  }

  @override
  String get storePkgSigDigest => 'sig.json의 digest가 배포물과 다릅니다(배포물이 바뀌었습니다)';

  @override
  String get storePkgSigRead => 'sig.json의 publicKey / signature를 읽을 수 없습니다';

  @override
  String get storePkgSigLength => 'sig.json의 키 / 서명 길이가 다릅니다';

  @override
  String get storePkgSigInvalid => '개발자 키 서명이 맞지 않습니다';

  @override
  String storePkgFileMissing(String path) {
    return '$path: 목차에는 있지만 안에 없습니다';
  }

  @override
  String storePkgTwice(String path) {
    return 'bundle.json: $path이(가) 2번 나옵니다';
  }

  @override
  String get storePkgKindTheme => '테마';

  @override
  String get storePkgKindAssets => '에셋 팩';

  @override
  String swingActionFailed(String error) {
    return '실패했습니다: $error';
  }

  @override
  String get swingReplyHint => '답글 보내기…';

  @override
  String swingReplyToHint(String handle) {
    return '@$handle에게 답글…';
  }

  @override
  String swingReplyCount(int count) {
    return '답글 $count';
  }

  @override
  String get swingQueueTooltip => '대기열 (길게 눌러 그림 선택)';

  @override
  String get swingThreadBackReply => '이전 답글로 돌아가기';

  @override
  String get swingThreadBackSwing => 'Swing 답글로 돌아가기';

  @override
  String swingRepliesTo(String handle, int count) {
    return '@$handle에 대한 답글 $count';
  }

  @override
  String get swingThreadClose => '답글 접기';

  @override
  String swingLoadFailed(String error) {
    return '불러오지 못했습니다: $error';
  }

  @override
  String get swingNoReplies => '아직 답글이 없습니다.';

  @override
  String swingViewReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '답글 $_temp0 보기';
  }

  @override
  String swingAttachments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '첨부 $_temp0';
  }

  @override
  String get swingPoll => '투표';

  @override
  String swingReplyOf(String name) {
    return '$name의 답글';
  }

  @override
  String get swingImageSwing => '이미지 Swing';

  @override
  String get swingVideoSwing => '동영상 Swing';

  @override
  String get swingPluginSwing => '플러그인 Swing';

  @override
  String swingOf(String name) {
    return '$name의 Swing';
  }

  @override
  String get swingBarSemantics => 'Swing 답글과 탐색 바';

  @override
  String swingReportIntro(String name) {
    return '$name의 Swing을 신고합니다. RASQ 심사에서 확인합니다.';
  }

  @override
  String get swingReported => '신고했습니다. 심사에서 확인합니다';

  @override
  String swingReportFailed(String error) {
    return '신고하지 못했습니다: $error';
  }

  @override
  String get swingDeleteTitle => 'Swing 삭제';

  @override
  String get swingDeleteMessage => '이 Swing과 달린 답글을 삭제합니다. 되돌릴 수 없습니다.';

  @override
  String get swingDeleteConfirm => '삭제';

  @override
  String get swingCancel => '취소';

  @override
  String swingDeleteFailed(String error) {
    return '삭제하지 못했습니다: $error';
  }

  @override
  String get swingDeleted => 'Swing을 삭제했습니다';

  @override
  String get swingViewerEmptyMine => '올린 Swing이 없습니다';

  @override
  String get swingViewerEmptyMineHint => '＋를 위로 스와이프하면 Swing을 만들 수 있습니다';

  @override
  String get swingViewerEmpty => 'Swing이 없습니다';

  @override
  String get swingViewerEmptyHint =>
      '팔로우하는 사람이나 나를 RASQ 리스트에 넣은 사람의 Swing이 여기에 표시됩니다';

  @override
  String get swingClose => '닫기';

  @override
  String swingRemainingHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간',
    );
    return '$_temp0 남음';
  }

  @override
  String swingRemainingMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes분',
    );
    return '$_temp0 남음';
  }

  @override
  String get swingRemainingSoon => '곧 사라집니다';

  @override
  String swingRemainingAndPosition(String remaining, String position) {
    return '$remaining · $position';
  }

  @override
  String swingViewCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명',
    );
    return '본 사람 $_temp0';
  }

  @override
  String get swingReport => '신고';

  @override
  String get swingMenu => '메뉴';

  @override
  String get swingDelete => '삭제';

  @override
  String get swingSensitive => '민감한 내용';

  @override
  String get swingReveal => '표시';

  @override
  String swingPluginJoinNote(String name) {
    return '$name 님의 페이지에 모두 함께 들어갑니다. 설치하지 않고 이 Swing을 보는 동안만 실행합니다.';
  }

  @override
  String get swingPluginJoin => '참여';

  @override
  String get swingPluginConsent =>
      '심사되지 않은 플러그인입니다. 통신할 수 없는 상태로 이 Swing을 보는 동안만 실행합니다.';

  @override
  String get swingPluginConsentDetail =>
      '제한 모드(network / storage.unsafe / interstitial·system의 FOW / URL 열기 등은 차단, GPU는 가능). 하위 플러그인이 없는 단일 플러그인만.';

  @override
  String get swingPluginRun => '실행';

  @override
  String swingPluginNeedsInstall(String name) {
    return '$name을(를) 설치하면 볼 수 있습니다';
  }

  @override
  String get swingPluginNeedsInstallHint => '플러그인 Swing입니다. 스토어에서 설치해 주세요';

  @override
  String get swingViewInStore => '스토어에서 보기';

  @override
  String get swingPluginOpenFailed => '열지 못했습니다';

  @override
  String get swingPluginTapToExpand => '누르면 전체 화면으로 돌아갑니다';

  @override
  String get swingPluginSwipeHint => '좌우·상하로 스와이프하면 다음 Swing으로';

  @override
  String get swingPluginShrink => '전체 화면에서 축소';

  @override
  String get swingAd => '광고';

  @override
  String get swingAdSwipeHint => '스와이프하면 다음 Swing으로';

  @override
  String get swingKindText => '텍스트';

  @override
  String get swingKindImage => '이미지';

  @override
  String get swingKindVideo => '동영상';

  @override
  String get swingKindPlugin => '플러그인';

  @override
  String swingKindSwing(String kind) {
    return '$kind Swing';
  }

  @override
  String swingBannerNew(int count) {
    return '새 글 $count';
  }

  @override
  String swingBannerTotal(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String get swingComposerPluginShared =>
      '모두 함께 사용: 본 사람은 내가 만드는 같은 페이지에 들어갑니다';

  @override
  String get swingComposerPluginFullscreen => '보는 사람의 기기에서 전체 화면으로 실행됩니다';

  @override
  String get swingComposerPluginPage => '보는 사람의 기기에서 페이지로 실행됩니다';

  @override
  String swingTtlLabel(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간 후 사라짐',
    );
    return '$_temp0';
  }

  @override
  String get swingTtl => '사라지기까지';

  @override
  String swingTtlHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간',
    );
    return '$_temp0';
  }

  @override
  String get swingBackgroundImage => '이미지를 배경으로';

  @override
  String get swingBackgroundVideo => '동영상을 배경으로';

  @override
  String get swingPickVideoFile => '동영상 파일을 선택해 주세요';

  @override
  String get swingPickImageFile => '이미지 파일을 선택해 주세요';

  @override
  String get swingChangeBackground => '배경 변경';

  @override
  String get swingAudience => '받는 사람';

  @override
  String get swingLoadFailedShort => '불러오지 못했습니다';

  @override
  String swingSent(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간 후 사라집니다',
    );
    return 'Swing을 올렸습니다($_temp0)';
  }

  @override
  String get swingErrorLimit => '동시에 보내 둘 수 있는 Swing은 최대 20개입니다';

  @override
  String swingSendFailed(String error) {
    return '올리지 못했습니다: $error';
  }

  @override
  String get swingComposerTitle => 'Swing 만들기';

  @override
  String get swingNext => '다음';

  @override
  String get swingSend => '올리기';

  @override
  String get swingNeedsAccount => 'RASQ 계정이 필요합니다';

  @override
  String get swingNeedsAccountHint => 'Swing은 RASQ 계정으로 올립니다. 사이드바에서 로그인해 주세요';

  @override
  String swingUnreviewed(String name) {
    return '$name (미심사)';
  }

  @override
  String swingTtlRemaining(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours시간 후 사라집니다',
    );
    return '$_temp0';
  }

  @override
  String get swingRepick => '다시 선택';

  @override
  String get swingReedit => '다시 편집';

  @override
  String swingCwTooLong(int max) {
    return 'CW는 $max자까지입니다';
  }

  @override
  String get swingCwHint => 'CW 문구';

  @override
  String get swingCwOff => 'CW 해제';

  @override
  String get swingCwOn => 'CW 붙이기 (민감한 내용)';

  @override
  String get swingPluginSection => '배포할 플러그인';

  @override
  String get swingPluginNone =>
      'Swing으로 배포할 수 있는 커스텀 플러그인이 설치되어 있지 않습니다. 스토어에서 설치하거나, 아래의 \'파일에서\'로 내 플러그인을 배포할 수 있습니다.';

  @override
  String get swingPluginNoneDetail =>
      '페이지형(커스텀 플러그인) 중 다른 플러그인과 부모·자식 관계가 없는 것(solo / shared 모두).';

  @override
  String get swingFromFile => '파일에서 (미심사)';

  @override
  String get swingFromFileSubtitle => '직접 만든 .rspkg / .rasqpkg / .wasm을 배포합니다';

  @override
  String get swingFromFileDetail =>
      '심사하지 않은 플러그인은 보는 사람의 기기에서 통신할 수 없는 상태로 실행됩니다(GPU는 사용 가능). 다른 플러그인을 바탕으로 하는 하위 플러그인은 배포할 수 없습니다.';

  @override
  String get swingAudienceEmpty => '받는 사람을 하나 이상 선택해 주세요';

  @override
  String get swingAudienceFollowers => '팔로워';

  @override
  String get swingAudienceFollowersSubtitle => 'RASQ 계정을 팔로우하는 사람';

  @override
  String get swingAudienceList => 'RASQ 리스트';

  @override
  String get swingAudienceNoLists => 'RASQ 리스트를 만들면 리스트에 넣은 사람에게도 보낼 수 있습니다';

  @override
  String swingPackageFetchFailed(int status) {
    return '플러그인을 가져오지 못했습니다 (HTTP $status)';
  }

  @override
  String get swingNotLoggedIn => 'RASQ 계정에 로그인하지 않았습니다';

  @override
  String get swingUnreadable => 'Swing을 읽지 못했습니다';

  @override
  String themeNotAThemePack(String id) {
    return '테마 팩이 아닙니다: $id';
  }

  @override
  String get themePickerLabel => '테마(.rspkg / .rasqpkg)';

  @override
  String themeNotATheme(String id, String kind) {
    return '테마(kind: theme)가 아닙니다: $id($kind)';
  }

  @override
  String themeLoadFailed(String error) {
    return '불러오지 못했습니다: $error';
  }

  @override
  String get themeTitle => '글꼴 및 색 구성표';

  @override
  String get themeCaption => '색상, 아이콘, 배경을 바꿀 수 있습니다. 하나만 사용할 수 있습니다';

  @override
  String get themeCaptionDetail =>
      '테마는 색상, 아이콘, 화면 / 게시물 타일 / FOW / 버튼의 배경을 바꾸는 팩입니다. 코드는 실행되지 않습니다. 한 번에 하나만 사용할 수 있습니다.';

  @override
  String get themeColorScheme => '색 구성';

  @override
  String get themeModeSystem => '시스템 설정 따르기';

  @override
  String get themeModeLight => '라이트';

  @override
  String get themeModeDark => '다크';

  @override
  String get themePacks => '테마';

  @override
  String get themeNone => '테마 없음(기본값)';

  @override
  String get themeDarkOnly => '다크 모드에서 적용됩니다';

  @override
  String get themeLightOnly => '라이트 모드에서 적용됩니다';

  @override
  String get themeSideloaded => '파일에서 불러옴(미심사)';

  @override
  String get themeSeparator => ' · ';

  @override
  String get themeRemove => '삭제';

  @override
  String themeDarkOnlyNotice(String name) {
    return '\'$name\'은(는) 다크 모드에서 적용됩니다. 지금은 라이트 모드입니다.';
  }

  @override
  String themeLightOnlyNotice(String name) {
    return '\'$name\'은(는) 라이트 모드에서 적용됩니다. 지금은 다크 모드입니다.';
  }

  @override
  String get themeSwitchToDark => '다크 모드로 전환';

  @override
  String get themeSwitchToLight => '라이트 모드로 전환';

  @override
  String get themeEmpty => '설치한 테마가 아직 없습니다.';

  @override
  String get themeFindInStore => '스토어에서 테마 찾기';

  @override
  String get themeImport => '파일에서 불러오기(.rspkg / .rasqpkg)';

  @override
  String get themeImportSubtitle => '직접 만든 테마를 불러옵니다';

  @override
  String get themeImportDetail =>
      'rasq build로 만든 테마 팩. 코드를 포함하지 않으므로 심사 전이라도 그대로 사용할 수 있습니다';

  @override
  String get trendTitle => '트렌드';

  @override
  String get trendTabNotes => '노트';

  @override
  String get trendTabFollowing => '팔로잉';

  @override
  String get trendTabUsers => '사용자';

  @override
  String get trendBackToHome => '트렌드 홈으로 돌아가기';

  @override
  String get trendSourceAccountMark => '이 트렌드를 제공한 계정';

  @override
  String get trendSettingsTooltip => '트렌드 설정';

  @override
  String get trendCustomizeTooltip => '트렌드 타임라인 맞춤 설정';

  @override
  String get trendReload => '새로고침';

  @override
  String get trendEmptyTitle => '아무것도 없는 것 같아요';

  @override
  String get trendEmptyHint => '단어나 필터를 바꾸면 찾을 수 있을지도 몰라요';

  @override
  String get trendFollowingEmptyTitle => '팔로우 중인 게시물이 없습니다';

  @override
  String get trendFollowingEmptyHint => '팔로우한 사람이 아직 이 단어에 대해 게시하지 않았습니다';

  @override
  String get trendUsersBlocked => '보호자가 사용자 검색을 막아 두었습니다';

  @override
  String get trendUsersEmpty => '사용자가 없습니다';

  @override
  String trendUserReactions(int count) {
    return '리액션 $count';
  }

  @override
  String get trendMenuOpenAs => '다른 계정으로 열기';

  @override
  String get trendMenuReport => '신고';

  @override
  String trendMenuAccountSourced(String account) {
    return '$account (이 트렌드를 제공한 계정)';
  }

  @override
  String get trendReportTitle => '신고';

  @override
  String trendReportMessage(String tag) {
    return '트렌드 \'$tag\'을(를) 신고합니다. RASQ 심사에서 확인합니다. 신고한 트렌드는 트렌드 목록에 더 이상 표시되지 않습니다.';
  }

  @override
  String trendReportMessageWithServer(String tag, String server) {
    return '트렌드 \'$tag\'($server)을(를) 신고합니다. RASQ 심사에서 확인합니다. 신고한 트렌드는 트렌드 목록에 더 이상 표시되지 않습니다.';
  }

  @override
  String get trendReportNoteHint => '추가 설명(선택)';

  @override
  String get trendReportSend => '신고하기';

  @override
  String get trendReportSent => '신고했습니다. RASQ 심사에서 확인합니다';

  @override
  String get trendReportStored => '이 기기에 저장했습니다. RASQ 계정에 연결되면 보냅니다';

  @override
  String get trendReportFailed => '보내지 못해 이 기기에 저장했습니다(나중에 다시 보냅니다)';

  @override
  String get trendReportUnhide => '다시 표시';

  @override
  String get trendPluginFallbackName => '트렌드 플러그인';

  @override
  String get trendPluginLoadFailed => '불러오지 못했습니다';

  @override
  String get trendPluginNoWords => '후보 단어가 아직 없습니다';

  @override
  String trendPluginWordQuoted(String word) {
    return '\'$word\'';
  }

  @override
  String trendPluginTodayEmpty(String words) {
    return '$words에 대한 게시물이 아직 없습니다';
  }

  @override
  String trendPluginTodayHeading(String words) {
    return '$words에 대한 게시물';
  }

  @override
  String get trendEmotionJoy => '기쁨';

  @override
  String get trendEmotionTrust => '신뢰';

  @override
  String get trendEmotionFear => '두려움';

  @override
  String get trendEmotionSurprise => '놀람';

  @override
  String get trendEmotionSadness => '슬픔';

  @override
  String get trendEmotionDisgust => '혐오';

  @override
  String get trendEmotionAnger => '분노';

  @override
  String get trendEmotionAnticipation => '기대';

  @override
  String get trendExamplesNoCandidates => '후보가 없습니다';

  @override
  String get trendExamplesAllow => '좋아요';

  @override
  String get trendExamplesDeny => '별로예요';

  @override
  String get trendExamplesDecide => '결정';

  @override
  String trendExamplesLoadFailed(String source, String error) {
    return '$source을(를) 불러오지 못했습니다: $error';
  }

  @override
  String get trendExamplesAllSeen => '모두 확인했습니다';

  @override
  String trendExamplesAllSeenHint(
    String allowLabel,
    int allow,
    String denyLabel,
    int deny,
  ) {
    return '$allowLabel $allow / $denyLabel $deny. 결정을 누르면 저장됩니다';
  }

  @override
  String trendExamplesIntro(String allowLabel, String denyLabel) {
    return '내용을 보고 아래의 \'$allowLabel\' / \'$denyLabel\'(오른쪽 / 왼쪽 스와이프도 가능)로 예시로 지정합니다. 새 항목은 예시와 얼마나 가까운지로 분류합니다.';
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
      other: '$remaining개',
    );
    return '$intro($allowLabel $allow / $denyLabel $deny · 남은 항목 $_temp0)';
  }

  @override
  String get trendExamplesSearch => '찾기';

  @override
  String get trendExamplesSkip => '건너뛰기';

  @override
  String trendExamplesMorePosts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '+$_temp0';
  }

  @override
  String get trendExamplesPostsUnreadable => '게시물을 읽지 못했습니다(이름과 설명으로 비교합니다)';

  @override
  String trendExamplesOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '외 $_temp0';
  }

  @override
  String get trendExamplesSourceActions => '최근 활동';

  @override
  String get trendExamplesSourceActionsEmpty => '최근 활동이 없습니다';

  @override
  String get trendExamplesSourceActionsEmptyHint =>
      '리액션하거나 북마크하면 여기에서 고를 수 있습니다';

  @override
  String get trendExamplesSourcePlugins => '플러그인';

  @override
  String get trendExamplesSourcePluginsEmpty => '설치한 플러그인이 없습니다';

  @override
  String get trendExamplesSourceClips => '클립';

  @override
  String get trendExamplesSourceClipsEmpty => '클립이 없습니다';

  @override
  String get trendExamplesSourceLists => '리스트';

  @override
  String get trendExamplesSourceListsEmpty => '리스트가 없습니다';

  @override
  String get trendExamplesSourceStore => '스토어';

  @override
  String get trendExamplesSourceStoreHint => '스토어 검색(비우면 = 목록)';

  @override
  String get trendExamplesSourceStoreEmpty => '찾지 못했습니다';

  @override
  String get trendExamplesKindPlugin => '플러그인';

  @override
  String get trendExamplesKindClip => '클립';

  @override
  String get trendExamplesKindList => '리스트';

  @override
  String get trendExamplesKindPost => '게시물';

  @override
  String get trendExamplesKindText => '텍스트';

  @override
  String get trendProfileSheetTitle => '트렌드 프로필 설정';

  @override
  String get trendProfileClose => '닫기';

  @override
  String get trendProfileDecide => '확인';

  @override
  String get trendProfileGenres => '좋아하는 장르/방향성';

  @override
  String get trendProfileGenresSnsDefault => '좋아하는 장르/방향성 (SNS 설정에 맡김)';

  @override
  String get trendProfileGenresAuto => '좋아하는 장르/방향성 (액션에서 자동 추출)';

  @override
  String get trendProfileAddGenrePill => '+ 장르 추가';

  @override
  String get trendProfileEdit => '편집';

  @override
  String get trendProfileTendencyTitle => '트렌드 성향/자극성';

  @override
  String trendProfileTendencySummary(String directivity, String stimulus) {
    return '성향 $directivity · 자극성 $stimulus';
  }

  @override
  String get trendProfilePluginsTitle => '트렌드 플러그인 설정';

  @override
  String get trendProfilePluginsSubtitle => '타임라인 노드 / 검색 후보';

  @override
  String get trendProfilePluginsDetail =>
      'trend.suggest 플러그인. 타임라인 맞춤 설정의 노드(트렌드 가져오기 / Today / 커스텀)와 검색 후보에 표시합니다';

  @override
  String get trendProfileCacheNetworkTitle => '캐시 네트워크 설정';

  @override
  String get trendProfileComingSoon => '준비 중';

  @override
  String get trendProfileAlgorithmTitle => '알고리즘(노드) 편집';

  @override
  String get trendProfileAlgorithmSubtitle => '트렌드를 모으고 정렬하는 방식을 편집합니다';

  @override
  String get trendProfileAlgorithmDetail =>
      '트렌드 가져오기·정렬 체인 (ml.tendency 노드에서 이 프로필을 사용할 수 있습니다)';

  @override
  String get trendProfileSharedCaption => '이 설정은 추천 / 트렌드 / 관련 타임라인에서 공통입니다.';

  @override
  String get trendProfileSharedCaptionDetail =>
      '이 프로필은 storage.safe(trend.profile)에 저장되며, 추천 / 트렌드 / 관련 타임라인의 기본값과 노드 편집기의 \'성향/자극성\' 노드가 공통으로 읽습니다.';

  @override
  String get trendProfileDirNarrow => '좁음';

  @override
  String get trendProfileDirWide => '넓음';

  @override
  String get trendProfileDirNormal => '보통';

  @override
  String get trendProfileStimNone => '제한 없음';

  @override
  String trendProfileStimCapped(String emotions) {
    return '$emotions 억제';
  }

  @override
  String get trendProfileListSeparator => '·';

  @override
  String get trendProfileDirectivityTitle => '트렌드 성향';

  @override
  String get trendProfileDirectivitySubtitle =>
      '좁을수록 좋아하는 장르에서 벗어난 게시물을 표시하지 않습니다.';

  @override
  String get trendProfileDirectivityDetail =>
      '좋아하는 장르/방향성과의 근접도 임계값(좁음 ⇄ 넓음). 좁을수록 벗어난 게시물을 제외합니다.';

  @override
  String get trendProfileShareTitle => '설정 공유';

  @override
  String get trendProfileShareSubtitle => '추천 / 트렌드 / 관련 타임라인에 이 설정을 사용합니다';

  @override
  String get trendProfileShareDetail =>
      '끄면 타임라인 기본 적용을 중지합니다(노드에서 명시한 부분은 적용됩니다)';

  @override
  String get trendProfileStimulusTitle => '트렌드 자극성';

  @override
  String get trendProfileStimulusCaption => '각 감정의 상한. 중심에 가까울수록 억제합니다';

  @override
  String get trendProfileStimulusReset => '자극성 초기화';

  @override
  String get trendProfileEchoChamberWarning =>
      '트렌드 성향/자극성을 강하게 하면 에코 체임버의 영향을 받기 쉬워질 위험이 있습니다.';

  @override
  String get trendProfileStimulusEstimate => '자극성은 현재 단어의 경향으로 추정하고 있습니다.';

  @override
  String get trendProfileStimulusEstimateDetail => '자극성은 어휘 규칙으로 추정하고 있습니다.';

  @override
  String get trendProfileTendencySaved => '트렌드 성향/자극성을 저장했습니다';

  @override
  String get trendProfileSnsDefaultTitle => 'SNS 설정에 맡기기';

  @override
  String get trendProfileSnsDefaultSubtitle => '켜져 있는 동안 기기에서 거르지 않습니다';

  @override
  String get trendProfileAutoGenreTitle => '내 액션에서 자동 추출';

  @override
  String get trendProfileAutoGenreSubtitle => '리액션한 게시물의 특징어를 좋아하는 장르에 추가합니다';

  @override
  String get trendProfilePickFromActions => '최근 액션에서 좋아하는 것 선택';

  @override
  String get trendProfileGenresTapToRemove => '좋아하는 장르/방향성 (탭하여 제외)';

  @override
  String get trendProfileNoneYet => '아직 없습니다';

  @override
  String get trendProfileAddGenreHint => '장르/키워드 추가';

  @override
  String get trendProfileAddGenre => '장르 추가';

  @override
  String trendProfileExamplesLabel(int allow, int deny) {
    return '예시 (좋아함 $allow / 좋아하지 않음 $deny. 탭하여 제외)';
  }

  @override
  String trendProfileExampleAllow(String label) {
    return '좋아함: $label';
  }

  @override
  String trendProfileExampleDeny(String label) {
    return '좋아하지 않음: $label';
  }

  @override
  String get trendProfileDislikedTapToRemove => '좋아하지 않음 (탭하여 제외)';

  @override
  String get trendProfileGenresSaved => '좋아하는 장르/방향성을 저장했습니다';

  @override
  String get trendProfilePickTitle => '액션에서 장르 선택';

  @override
  String get trendProfilePickIntro =>
      '최근 액션을 주제별로 보여 줍니다. 카드를 골라 \'좋아요\'/\'별로예요\'로 옮기세요(오른쪽/왼쪽 스와이프도 가능).';

  @override
  String trendProfilePickIntroDetail(int perPage) {
    String _temp0 = intl.Intl.pluralLogic(
      perPage,
      locale: localeName,
      other: '$perPage개',
    );
    return '최근 액션을 비슷한 주제로 묶어, 화제성이 강한 것부터 $_temp0씩 보여 줍니다(위의 칩으로 플러그인 / 클립 / 리스트에서도). 카드를 탭해 고르고, 후보 장르를 고른 뒤 아래의 \'좋아요\'/\'별로예요\'을 누르세요(오른쪽/왼쪽 스와이프도 가능).';
  }

  @override
  String userPageViewTitle(String tab) {
    return '$tab 표시';
  }

  @override
  String get userPageViewClose => '닫기';

  @override
  String userPageViewSearchHint(String tab) {
    return '이 사람의 $tab에서 찾기';
  }

  @override
  String get userPageViewSortLabel => '정렬';

  @override
  String get userPageViewSortNewest => '최신순';

  @override
  String get userPageViewSortOldest => '오래된 순';

  @override
  String get userPageViewSortReactions => '리액션 수';

  @override
  String get userPageViewSortTendency => '경향에 맞는 순';

  @override
  String get userPageViewShowLabel => '표시';

  @override
  String get userPageViewShowPinned => '고정됨';

  @override
  String get userPageViewShowRenotes => '리노트';

  @override
  String get userPageViewShowQuotes => '인용 노트';

  @override
  String get userPageViewShowDigest => '다이제스트';

  @override
  String get userPageViewTendencyLabel => '성향 / 자극성';

  @override
  String get userPageViewDirectivityTitle => '성향';

  @override
  String get userPageViewDirectivityNoGenres => '좋아하는 장르를 정하면 적용됩니다';

  @override
  String get userPageViewStimulusTitle => '자극성';

  @override
  String get userPageViewReset => '초기화';

  @override
  String userPageViewCount(int shown, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total개 중 $shown개',
    );
    return '$_temp0';
  }

  @override
  String get userPageViewEmptyTitle => '조건에 맞는 게시물이 없습니다';

  @override
  String get userPageViewEmptyHint => '탭을 다시 눌러 표시 설정을 변경하거나 초기화하세요';

  @override
  String get usersImageViewerBack => '뒤로';

  @override
  String get usersFollowRequestsTabRelevance => '관련성';

  @override
  String get usersFollowRequestsTabFollowing => '팔로잉';

  @override
  String get usersFollowRequestsTabOther => '기타';

  @override
  String get usersFollowRequestsTitle => '팔로우 요청';

  @override
  String get usersReload => '새로고침';

  @override
  String get usersFollowRequestsEmpty => '팔로우 요청이 없습니다';

  @override
  String get usersFollowRequestsEmptyOther => '없음';

  @override
  String get usersFollowRequestAccept => '수락';

  @override
  String get usersFollowRequestReject => '거절';

  @override
  String get usersFollowsTabFollowing => '팔로잉';

  @override
  String get usersFollowsTabFollowers => '팔로워';

  @override
  String get usersFollowsTitle => '팔로잉/팔로워';

  @override
  String get usersFollowersEmpty => '팔로워가 없습니다';

  @override
  String get usersFollowingEmpty => '팔로우 중인 사용자가 없습니다';

  @override
  String get usersPageTabNotes => '노트';

  @override
  String get usersPageTabReplies => '답글';

  @override
  String get usersPageTabQuotes => '인용';

  @override
  String get usersPageTabMedia => '미디어';

  @override
  String get usersPageTabClips => '클립/Play';

  @override
  String get usersRestrictedTitle => '제한된 사용자입니다';

  @override
  String get usersRestrictedHint => '\'표시\'를 누르면 내용을 표시합니다';

  @override
  String get usersMenuCopyLink => '링크 복사';

  @override
  String get usersMenuAddToRasqList => 'RASQ 리스트에 추가';

  @override
  String get usersMenuServerInfo => '서버 정보';

  @override
  String get usersMenuUnmute => '뮤트 해제';

  @override
  String get usersMenuMute => '뮤트';

  @override
  String get usersMenuUnblock => '차단 해제';

  @override
  String get usersMenuBlock => '차단';

  @override
  String get usersMenuReport => '신고';

  @override
  String usersBlockConfirmTitle(String name) {
    return '$name님을 차단할까요?';
  }

  @override
  String get usersBlockConfirmMessage => '상대의 팔로우, 리액션, 답글이 더 이상 오지 않습니다.';

  @override
  String get usersCancel => '취소';

  @override
  String usersReportConfirmTitle(String name) {
    return '$name님을 신고할까요?';
  }

  @override
  String get usersReportConfirmMessage => '서버 관리자에게 신고합니다.';

  @override
  String get usersPostsEmpty => '게시물이 없습니다';

  @override
  String get usersPinnedBadge => '고정됨';

  @override
  String get usersClipsUnsupportedTitle => '클립 / Play';

  @override
  String get usersClipsUnsupportedHint => '이 SNS는 클립과 Play를 지원하지 않습니다';

  @override
  String get usersClipsEmpty => '공개 클립이나 Play가 없습니다';

  @override
  String get usersClipsHeader => '클립';

  @override
  String usersClipNoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개',
    );
    return '$_temp0';
  }

  @override
  String get usersClipSubtitleSeparator => ' · ';

  @override
  String get usersNotFound => '이 사용자는 존재하지 않는 것 같습니다.';

  @override
  String get vcSectionInvited => '초대';

  @override
  String get vcSectionRecommended => '추천';

  @override
  String get vcSectionUpcoming => '곧 개최';

  @override
  String get vcSectionTrending => '트렌드';

  @override
  String get vcSectionFollowing => '팔로잉';

  @override
  String vcSectionSettingsTooltip(String title) {
    return '$title 설정';
  }

  @override
  String get vcSearchHint => 'ASTell / Swing 검색';

  @override
  String get vcSearchRefineHint => '더 좁히기';

  @override
  String vcSearchTermChip(String term) {
    return '\'$term\' ×';
  }

  @override
  String get vcSearchClear => '지우기';

  @override
  String get vcCreateTooltip => 'ASTell 만들기';

  @override
  String get vcHomeLoadError => 'ASTell을 가져오지 못했습니다';

  @override
  String vcJoinedRoom(String title) {
    return '참여 중: $title';
  }

  @override
  String vcJoinedPeers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명 · 탭하여 열기',
    );
    return '$_temp0';
  }

  @override
  String get vcConnecting => '연결하는 중…';

  @override
  String vcInvitedBy(String name) {
    return '$name님이 초대 · 탭하여 보기';
  }

  @override
  String get vcInviteDecline => '거절';

  @override
  String get vcRecommendedEmpty => '추천 ASTell이 아직 없습니다';

  @override
  String get vcTrendingEmpty => '트렌드 ASTell이 아직 없습니다';

  @override
  String get vcFollowingEmpty => '팔로우 중인 사용자의 ASTell이 없습니다';

  @override
  String get vcSearchNoResults => '찾지 못했습니다';

  @override
  String get vcSearchNoResultsInSection => '이 섹션에는 없습니다';

  @override
  String vcSearchNoResultsFor(String query) {
    return '\'$query\'에 해당하는 ASTell / Swing이 없습니다';
  }

  @override
  String get vcTileOpen => '보러 가기';

  @override
  String get vcBookmarkRemove => '북마크에서 삭제';

  @override
  String get vcBookmarkSave => '북마크에 저장';

  @override
  String get vcRemindCancel => '시작 알림 해제';

  @override
  String get vcRemindSet => '시작 알림 받기';

  @override
  String get vcMenuTooltip => '메뉴';

  @override
  String vcScheduledAt(String when) {
    return '개최 예정 $when';
  }

  @override
  String get vcSummaryPrivate => '간단 요약은 비공개입니다.';

  @override
  String get vcTileStripEmpty => '아직 ASTell이 없습니다';

  @override
  String get vcLinkCopied => '링크를 복사했습니다';

  @override
  String get vcBookmarkSaved => '북마크에 저장했습니다';

  @override
  String get vcBookmarkRemoved => '북마크에서 삭제했습니다';

  @override
  String vcRemindRegistered(String when) {
    return '$when에 알려 드립니다';
  }

  @override
  String get vcRemindRemoved => '알림을 해제했습니다';

  @override
  String get vcRemindUnavailable => '이 기기에서는 알림을 등록하지 못했습니다';

  @override
  String get vcRemindNotScheduled => '개최 예정이 없는 룸입니다';

  @override
  String get vcMenuShareAsPost => '게시물로 공유';

  @override
  String get vcMenuCopyLink => '링크 복사';

  @override
  String get vcMenuStartNow => '지금 바로 개최';

  @override
  String get vcMenuBackToRoom => '룸으로 돌아가기';

  @override
  String get vcMenuJoin => '참여하기';

  @override
  String get vcMenuClose => '종료하기';

  @override
  String get vcMenuUnfollowHost => '호스트 팔로우 해제';

  @override
  String get vcMenuFollowHost => '호스트 팔로우';

  @override
  String get vcMenuMute => '뮤트';

  @override
  String get vcMenuReport => '신고';

  @override
  String vcUnfollowed(String name) {
    return '$name님의 팔로우를 해제했습니다';
  }

  @override
  String vcFollowed(String name) {
    return '$name님을 팔로우했습니다';
  }

  @override
  String vcReportWhatRoom(String title) {
    return '룸 \'$title\'';
  }

  @override
  String vcMenuNotYet(String title, String action) {
    return '\'$title\'의 조작($action)은 M5 후반에 추가됩니다';
  }

  @override
  String get vcCloseRoomTitle => '룸 종료';

  @override
  String vcCloseScheduledBody(String title) {
    return '\'$title\'의 예약을 취소합니다. 북마크나 시작 알림을 등록한 사람에게는 전달되지 않습니다.';
  }

  @override
  String vcCloseRoomBody(String title) {
    return '\'$title\'을(를) 종료합니다. 참여 중인 멤버는 퇴장하게 됩니다.';
  }

  @override
  String vcClosedScheduled(String title) {
    return '\'$title\'의 예약을 취소했습니다';
  }

  @override
  String vcClosedRoom(String title) {
    return '\'$title\'을(를) 종료했습니다';
  }

  @override
  String vcCloseFailed(String error) {
    return '종료하지 못했습니다: $error';
  }

  @override
  String get vcTileBack => '돌아가기';

  @override
  String get vcReminderNotificationTitle => '북마크한 ASTell이 시작됩니다!';

  @override
  String vcReminderNotificationBody(String host, String title) {
    return '$host의 \'$title\'';
  }

  @override
  String vcShareTextScheduled(String title, String when) {
    return '\'$title\'을(를) $when에 개최합니다';
  }

  @override
  String vcShareTextOpen(String title) {
    return '\'$title\'을(를) 개최 중입니다';
  }

  @override
  String get vcViewerPluginsTooltip => '전체 화면 플러그인(준비 중)';

  @override
  String vcViewerSharedBy(String name) {
    return '$name님이 공유';
  }

  @override
  String get vcViewerSave => '저장';

  @override
  String get vcViewerSaveNotYet => '저장은 준비 중입니다';

  @override
  String get vcViewerShare => '공유';

  @override
  String get vcViewerShareNotYet => '공유는 준비 중입니다';

  @override
  String get vcBarSpeaker => '스피커';

  @override
  String get vcBarMic => '마이크';

  @override
  String get vcBarScreen => '화면 공유';

  @override
  String get vcBarFullscreen => '전체 화면(공유 틀에 화면이 있을 때)';

  @override
  String get vcBarCaptions => '자막(텍스트 변환)';

  @override
  String vcCallConnectFailed(String error) {
    return '통화 연결에 실패했습니다: $error';
  }

  @override
  String get vcOpenNotFound => '이 룸을 찾을 수 없습니다(종료되었거나 링크가 잘못되었을 수 있습니다)';

  @override
  String get vcOpenFailed => '룸을 열지 못했습니다';

  @override
  String get vcOpenGoHome => 'ASTell 홈으로';

  @override
  String vcOpenHost(String name, String handle) {
    return '호스트: $name(@$handle)';
  }

  @override
  String get vcOpenRoom => '룸 열기';

  @override
  String get vcShareBlockDirect => '다이렉트 게시물은 ASTell에 공유할 수 없습니다';

  @override
  String get vcShareBlockLocalOnly => '로컬 한정 게시물은 ASTell에 공유할 수 없습니다';

  @override
  String get vcShareBlockUnknownVisibility =>
      '공개 범위를 알 수 없는 게시물은 ASTell에 공유할 수 없습니다';

  @override
  String get vcShareBlockLimited => '공개 범위가 제한된 게시물은 ASTell에 공유할 수 없습니다';

  @override
  String get vcShares => '공유';

  @override
  String vcSharesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '공유 ($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcSharesShowAll => '모든 공유 보기';

  @override
  String get vcSharesEmpty => '채팅에서 📌한 것이 여기에 표시됩니다.';

  @override
  String get vcShareActions => '공유 조작';

  @override
  String get vcShareTranscriptSource => 'RASQ · 텍스트 변환';

  @override
  String get vcUnpin => '고정 해제';

  @override
  String get vcYou => '나';

  @override
  String get vcNoDescription => '설명이 없습니다.';

  @override
  String get vcReportReasonSpam => '스팸';

  @override
  String get vcReportReasonHarassment => '괴롭힘·폭언';

  @override
  String get vcReportReasonIllegal => '불법·위험한 내용';

  @override
  String get vcReportReasonOther => '기타';

  @override
  String get vcJoinPolicyAnyone => '누구나';

  @override
  String get vcJoinPolicyAnyoneHint => '공개 룸은 누구나 참여할 수 있습니다';

  @override
  String get vcJoinPolicyFollowers => '팔로워만';

  @override
  String get vcJoinPolicyFollowersHint => 'RASQ 계정으로 회원님(호스트)을 팔로우하는 사람';

  @override
  String get vcJoinPolicyFollowing => '팔로우 중인 사람만';

  @override
  String get vcJoinPolicyFollowingHint => '회원님이 팔로우하는 사람';

  @override
  String get vcJoinPolicyMutual => '맞팔로우만';

  @override
  String get vcJoinPolicyMutualHint => '서로 팔로우하는 사람';

  @override
  String get vcSharePolicyEveryone => '전원';

  @override
  String get vcSharePolicyModerators => '모더레이터만';

  @override
  String vcShareContentWarning(String warning) {
    return '⚠ $warning(민감한 내용)';
  }

  @override
  String vcSharePluginWant(String name) {
    return '\'$name\'을(를) 쓰고 싶어요';
  }

  @override
  String get vcKindPost => '게시물';

  @override
  String get vcKindMedia => '미디어';

  @override
  String get vcKindVideo => '동영상';

  @override
  String get vcKindLink => '링크';

  @override
  String get vcKindText => '텍스트';

  @override
  String get vcKindPlugin => '플러그인';

  @override
  String get vcMediaInsecureContext => 'Web 버전의 통화는 https로 열었을 때만 사용할 수 있습니다';

  @override
  String get vcMediaPermissionDenied => '마이크(카메라) 권한이 없습니다. 기기 설정에서 허용해 주세요';

  @override
  String get vcMediaNoDevice => '마이크(카메라)를 찾을 수 없습니다';

  @override
  String get vcMediaUnsupported => '이 기기에서는 사용할 수 없습니다';

  @override
  String vcMediaUnsupportedDetail(String detail) {
    return '이 기기에서는 사용할 수 없습니다($detail)';
  }

  @override
  String get vcMediaMicClosed => '종료된 통화의 마이크는 열 수 없습니다';

  @override
  String get vcStreamNotConnected => '방송 서버에 연결되어 있지 않습니다';

  @override
  String get vcStreamPublishFailed => '영상을 방송 서버에 올리지 못했습니다';

  @override
  String get vcScreenSharingNotification => '화면을 공유하고 있습니다';

  @override
  String get vcScreenPickTitle => '공유할 화면 선택';

  @override
  String get vcScreenPickScreen => '전체 화면';

  @override
  String get vcScreenPickWindow => '창';

  @override
  String get vcScreenPickCancel => '그만두기';

  @override
  String get vcScreenPickShare => '공유하기';

  @override
  String get vcNoticeAudioBlocked => '소리가 멈춰 있습니다. 화면을 탭하면 재생됩니다';

  @override
  String vcNoticeCallFull(int cap) {
    return '통화가 만원입니다($cap명까지). 방송이 있으면 방송으로 들을 수 있습니다';
  }

  @override
  String get vcNoticeHoldWaiting => '개최까지 기다려 주세요. 대기음을 재생하고 있습니다';

  @override
  String get vcNoticeStarted => '개최가 시작되었습니다';

  @override
  String get vcNoticeHoldIdle => '조용해서 대기음을 재생하고 있습니다';

  @override
  String get vcShareClassImage => '이미지';

  @override
  String get vcShareClassFile => '파일';

  @override
  String get vcShareClassTranscript => '텍스트 변환';

  @override
  String get vcShareStyleCards => '카드(가로 슬라이드)';

  @override
  String get vcShareStyleList => '목록(레거시)';

  @override
  String get vcTermsRequired => '이용약관에 동의해야 합니다(ASTell 맨 위의 안내에서 동의할 수 있습니다)';

  @override
  String get vcClosedByModeration => '운영자에 의해 룸이 폐쇄되었습니다';

  @override
  String get vcClosedByHost => '호스트가 룸을 종료했습니다';

  @override
  String get vcKickedBanned => '이 룸에서 BAN되었습니다';

  @override
  String get vcKickedSanctioned => '계정 조치로 인해 퇴장당했습니다';

  @override
  String get vcKickedByModerator => '모더레이터가 룸에서 퇴장시켰습니다';

  @override
  String vcShareHeld(String seconds) {
    return '검열 중: $seconds초 후 판정되어 전달됩니다(계정 조치)';
  }

  @override
  String vcShareRejected(String source) {
    return '검열에서 거부되었습니다($source). 이 발언은 전달되지 않았습니다';
  }

  @override
  String get vcNotInRoom => '룸에 들어가 있지 않습니다';

  @override
  String vcStreamReceiveFailed(String error) {
    return '영상을 받을 수 없습니다: $error';
  }

  @override
  String get vcStreamBlockedByScreenShare =>
      '화면 공유 중에는 방송을 시작할 수 없습니다(공유를 멈춘 후에)';

  @override
  String vcStreamStartFailed(String error) {
    return '방송을 시작할 수 없습니다: $error';
  }

  @override
  String vcStreamClearFailed(String error) {
    return '방송 표시를 지우지 못했습니다: $error';
  }

  @override
  String get vcScreenShareBlockedByStream =>
      '방송 중에는 화면 공유를 시작할 수 없습니다(방송을 멈춘 후에)';

  @override
  String vcScreenShareStartFailed(String error) {
    return '화면 공유를 시작할 수 없습니다: $error';
  }

  @override
  String get vcStreamUnavailable => '방송은 아직 사용할 수 없습니다(방송 서버 미설정)';

  @override
  String vcStreamForbidden(String message) {
    return '허용되지 않았습니다($message)';
  }

  @override
  String get vcTtsNotConfigured => '읽어 주기 백엔드가 설정되지 않았습니다(CENTRAL_TTS_URL)';

  @override
  String get vcLoginRequired => 'RASQ 계정에 로그인해 주세요';

  @override
  String vcCreateUninvite(String name) {
    return '$name 초대 취소';
  }

  @override
  String vcCreateInvite(String name) {
    return '$name 초대';
  }

  @override
  String get vcCreateCancel => '취소';

  @override
  String get vcCreateShareAfterOn => '만든 후 게시물로 공유(켜짐)';

  @override
  String get vcCreateShareAfter => '만든 후 게시물로 공유';

  @override
  String vcCreateScheduled(String title, String when) {
    return '\'$title\'을(를) $when에 예약했습니다';
  }

  @override
  String get vcCreateScheduleInPast => '예정 시간은 지금 이후로 설정하세요';

  @override
  String vcCreateGenresMax(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '장르는 최대 $max개까지입니다',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateTitleRequired => '제목을 입력하세요';

  @override
  String vcCreateInviteFailed(String error) {
    return '초대를 보낼 수 없습니다: $error';
  }

  @override
  String vcCreateFailed(String error) {
    return '만들지 못했습니다: $error';
  }

  @override
  String get vcCreateSearchAdd => '검색해서 추가';

  @override
  String get vcCreateHandleHint => '@handle(RASQ 계정)';

  @override
  String vcCreateHandleNotFound(String handle) {
    return '찾을 수 없습니다: $handle';
  }

  @override
  String get vcCreateAddInvitee => '초대에 추가';

  @override
  String get vcCreateTitleHint => '제목';

  @override
  String get vcCreateInviteFollowers => '팔로워 초대';

  @override
  String vcCreateInviteFollowersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '팔로워 초대($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateWelcomeToggle => '참가 시 환영 메시지 표시';

  @override
  String get vcCreateWelcomeHint => '환영 메시지 설정..';

  @override
  String vcCreateGenresLabel(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '장르 선택(최대 $max개)',
    );
    return '$_temp0';
  }

  @override
  String get vcCreateGenreHint => '장르 입력';

  @override
  String get vcCreateGenreAdd => '장르 추가';

  @override
  String get vcCreateSchedule => '개최 예약';

  @override
  String get vcCreateScheduleCaption => '예약 중에는 내가 들어갈 때까지 다른 사람은 들어올 수 없습니다.';

  @override
  String get vcCreateScheduleCaptionDetail =>
      '예약 중에는 나(와 모더레이터)가 들어갈 때까지 다른 사람은 참가할 수 없습니다. 곧 개최 섹션과 공유 링크에서 시작 알림을 등록할 수 있습니다.';

  @override
  String get vcCreateSummaryHint => '간단한 요약(선택. 비우면 자동으로 만듭니다)';

  @override
  String get vcCreateMicAfterCreate => '마이크(만든 후 전환)';

  @override
  String get vcCreateScheduleButton => '예약';

  @override
  String get vcCreateButton => '만들기';

  @override
  String get vcRoomHostPresent => '참여 중';

  @override
  String get vcRoomHostBeforeStart => '개최 전';

  @override
  String get vcRoomHostAbsent => '부재';

  @override
  String vcRoomMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count명이 참여하고 있습니다',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomMembersHostOnly => '호스트 외에는 아직 아무도 없습니다';

  @override
  String get vcRoomMembersNone => '아직 아무도 없습니다';

  @override
  String vcRoomMembersRest(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '외 $count명',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomScreenShown => '공유 틀에 표시 중';

  @override
  String get vcRoomScreenShow => '화면 공유 표시';

  @override
  String vcRoomNotYet(String what) {
    return '$what은(는) 준비 중입니다';
  }

  @override
  String get vcRoomDeviceSettingsTitle => 'ASTell 설정(이 기기)';

  @override
  String get vcRoomEditBar => '하단 버튼 배열 편집';

  @override
  String get vcRoomEditBarSubtitle => '재정렬 / 표시 / 숨김 / 플러그인 버튼 추가';

  @override
  String get vcRoomAutoShareLabel => '채팅 내용을 자동으로 공유란에 표시(고정하지 않아도)';

  @override
  String get vcRoomShareStyleLabel => '공유란 표시';

  @override
  String get vcRoomAutoPlayLabel => '자동 재생';

  @override
  String get vcRoomAutoPlayScreen => '화면 공유가 시작되면 공유 틀에 표시';

  @override
  String get vcRoomHoldMusicLabel => '대기음';

  @override
  String get vcRoomHoldMusicDevice => '대기음 재생(이 기기)';

  @override
  String get vcRoomHoldMusicSourceLabel => '대기음 음원';

  @override
  String get vcRoomHoldMusicSourceAstronomies =>
      'We：Astronomies on the Blue Planet';

  @override
  String get vcRoomHoldMusicSourceClassic => '기본 대기음';

  @override
  String get vcRoomHoldMusicVolume => '대기음 음량';

  @override
  String vcRoomHoldMusicVolumeValue(int percent) {
    return '$percent%';
  }

  @override
  String get vcRoomDeviceSettingsCaption =>
      '룸 설정은 참여 후 룸의 톱니바퀴에서 바꿀 수 있습니다(오너).';

  @override
  String get vcRoomDeviceSettingsCaptionDetail =>
      '룸별 설정(참여할 수 있는 사람·읽어 주기 등)은 참여한 후 룸의 톱니바퀴에서 바꿀 수 있습니다(오너).';

  @override
  String get vcRoomClose => '닫기';

  @override
  String get vcRoomShare => '공유';

  @override
  String get vcRoomHost => '호스트';

  @override
  String get vcRoomMembers => '참여 멤버';

  @override
  String get vcRoomLocked => '운영자에 의해 새 입장이 중지되었습니다.';

  @override
  String get vcRoomLockedDetail => '운영자에 의해 신규 입장이 정지되었습니다(D-151).';

  @override
  String get vcRoomRemindOn => '시작을 알려 드립니다';

  @override
  String get vcRoomWaitForHost => '호스트가 시작할 때까지 참여할 수 없습니다';

  @override
  String get vcRoomRemindOff => '알림 해제';

  @override
  String get vcRoomSummary => '간단 요약';

  @override
  String get vcRoomSummaryPrivate => '이 룸은 간단 요약을 공개하지 않습니다.';

  @override
  String vcRoomWelcome(String message) {
    return '환영합니다: $message';
  }

  @override
  String get vcRoomMicAfterJoin => '마이크(참여 후 전환)';

  @override
  String get vcRoomCaptions => '자막';

  @override
  String get vcRoomJoin => '참여';

  @override
  String get vcRoomSettings => '설정';

  @override
  String get vcRoomTabHome => '홈';

  @override
  String get vcRoomTabChat => '채팅';

  @override
  String get vcRoomTabToc => '목차';

  @override
  String get vcRoomTabRoom => '룸';

  @override
  String get vcRoomLeft => '퇴장했습니다';

  @override
  String get vcRoomLeave => '퇴장';

  @override
  String get vcRoomStreamingScreen => '화면을 방송하고 있습니다';

  @override
  String get vcRoomStreamingCamera => '카메라로 방송하고 있습니다';

  @override
  String get vcRoomStopSharing => '공유 중지';

  @override
  String get vcRoomStopStream => '방송 중지';

  @override
  String get vcRoomSpeakerUnmute => '스피커 뮤트 해제';

  @override
  String get vcRoomSpeakerMute => '스피커 뮤트';

  @override
  String get vcRoomMutedByModerator => '모더레이터에 의해 뮤트되었습니다';

  @override
  String get vcRoomMicOpening => '마이크 준비 중(누르면 중지)';

  @override
  String get vcRoomMicOff => '마이크 끄기';

  @override
  String get vcRoomMicOn => '마이크 켜기';

  @override
  String get vcRoomScreenShareOff => '화면 공유 끄기';

  @override
  String get vcRoomFullscreen => '전체 화면';

  @override
  String get vcRoomCaptionsOff => '자막 끄기';

  @override
  String get vcRoomCaptionsOn => '자막 켜기';

  @override
  String get vcRoomShareAsLinkLimited => '공개 범위가 제한된 게시물이므로 링크로 공유합니다';

  @override
  String vcRoomShareAsLinkFailed(String error) {
    return '게시물을 가져오지 못해 링크로 공유합니다: $error';
  }

  @override
  String vcRoomPickFileFailed(String error) {
    return '파일을 선택하지 못했습니다: $error';
  }

  @override
  String get vcRoomStream => '방송';

  @override
  String vcRoomLiveCardTitle(String kind, String title) {
    return '$kind: $title';
  }

  @override
  String vcRoomPeerScreen(String name) {
    return '$name님의 화면';
  }

  @override
  String vcRoomPeerScreenTitled(String name, String title) {
    return '$name님의 화면 — $title';
  }

  @override
  String get vcRoomAllShares => '모든 공유';

  @override
  String get vcRoomSettingsTitle => 'ASTell 설정';

  @override
  String get vcRoomModerationLabel => '모더레이션(오너)';

  @override
  String get vcRoomJoinPolicyLabel => '참여할 수 있는 사람';

  @override
  String get vcRoomSharePolicyLabel => '공유(채팅에 게시)할 수 있는 사람';

  @override
  String vcRoomModeratorsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '모더레이터($count) — 멤버의 \'…\'에서 추가',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomRemoveModerator => '모더레이터 해제';

  @override
  String get vcRoomTendencyLabel => '발신 경향';

  @override
  String get vcRoomTendencyFilter => '악성 사용자 입장 거부(시험 중)';

  @override
  String get vcRoomTendencyCaption =>
      '켜면 적대적으로 판정된 사람은 들어올 수 없습니다. 판정은 아직 임시입니다.';

  @override
  String get vcRoomTendencyCaptionDetail =>
      '본래는 rasq-judge의 GoEmotion(발신의 감정 경향)이지만 학습이 필요하므로 지금은 서버의 더미 판정(표시 이름에 hostile 또는 \'악성 사용자\'를 뜻하는 일본어가 포함된 사람만 적대적)입니다. 켜면 적대적으로 판정된 사람은 입장할 수 없습니다. 멤버 행의 \'…\'에서 판정 결과를 볼 수 있습니다.';

  @override
  String get vcRoomHostStreamLabel => '방송(호스트)';

  @override
  String get vcRoomStreamCamera => '카메라로 방송하기';

  @override
  String get vcRoomStreamScreen => '화면 방송하기';

  @override
  String get vcRoomStreamScreenIos => 'iPhone / iPad는 이 앱의 화면만(다른 앱은 비치지 않습니다)';

  @override
  String get vcRoomHostStreamCaption =>
      '영상과 목소리를 방송합니다. 통화에 다 들어오지 못한 사람도 방송으로 들을 수 있습니다.';

  @override
  String vcRoomHostStreamCaptionDetail(int cap) {
    return '영상과 마이크를 방송 서버(LiveKit)에 올립니다. 참여자는 통화 음성 그대로 영상을 볼 수 있으며, 통화에 다 들어오지 못한 사람($cap번째 이후)은 방송으로 회원님의 목소리를 듣습니다.';
  }

  @override
  String get vcRoomHoldMusicRoom => '이 룸에서 대기음 허용(오너)';

  @override
  String get vcRoomHoldMusicCaption => '시작을 기다리는 동안이나 한동안 아무도 말하지 않을 때 재생됩니다.';

  @override
  String vcRoomHoldMusicCaptionDetail(int minutes) {
    return '개최 예약의 시작을 기다리는 동안, 그리고 전원이 마이크를 내리고(화면 공유 / 방송도 없이) 채팅이 $minutes분 이상 흐르지 않는 동안 재생됩니다. 누군가 말하기 시작하거나 채팅이 흐르면 멈춥니다.';
  }

  @override
  String get vcRoomTts => '읽어 주기';

  @override
  String get vcRoomTtsUnavailable => '읽어 주기(사용 불가)';

  @override
  String vcRoomTtsDetail(String model) {
    return '읽어 주기($model, 프리셋 음성)';
  }

  @override
  String vcRoomTtsDetailUnavailable(String model) {
    return '읽어 주기($model, 프리셋 음성) — 서버 미설정';
  }

  @override
  String get vcRoomTtsNone => '읽어 주기 없음';

  @override
  String get vcRoomTtsCaptionOwner => '읽어 주기 음성은 서버에서 만듭니다(앱에서의 재생은 준비 중).';

  @override
  String get vcRoomTtsCaptionGuest => '읽어 주기 음성은 호스트가 고릅니다.';

  @override
  String get vcRoomTtsCaptionOwnerDetail =>
      '채팅과 공유의 읽어 주기는 Central 측에서 합성합니다(기기에서의 재생은 향후 지원).';

  @override
  String get vcRoomDiagnosticsLabel => '연결 상태(개발자용)';

  @override
  String get vcRoomDiagnosticsOpen => '통화 / 방송 연결 보기';

  @override
  String get vcRoomDiagnosticsOpenSubtitle => 'ICE 상태·후보·송수신량·수신 중인 트랙';

  @override
  String get vcRoomDiagnosticsTitle => '연결 상태';

  @override
  String vcRoomHostStreamTitle(String name) {
    return '$name님의 방송';
  }

  @override
  String get vcRoomPostViewNotYet => '이 게시물 표시(대응 SNS 플러그인 미설치)';

  @override
  String get vcRoomOpen => '열기';

  @override
  String get vcRoomDelete => '삭제';

  @override
  String get vcRoomCopied => '복사했습니다';

  @override
  String vcRoomReportWhatShare(String headline) {
    return '공유 \'$headline\'';
  }

  @override
  String get vcRoomPinToFrame => '공유 틀에 표시';

  @override
  String get vcRoomUnfollow => '팔로우 해제';

  @override
  String get vcRoomFollow => '팔로우';

  @override
  String get vcRoomUnmute => '뮤트 해제';

  @override
  String get vcRoomModUnmute => '전원 대상 뮤트 해제';

  @override
  String get vcRoomModMute => '전원 대상 뮤트';

  @override
  String get vcRoomKick => '강퇴';

  @override
  String get vcRoomMakeModerator => '모더레이터로 지정';

  @override
  String get vcRoomShowTendency => '발신 경향 보기(시험 중)';

  @override
  String get vcRoomUnblock => '차단 해제';

  @override
  String get vcRoomBlock => '차단';

  @override
  String get vcRoomReport => '신고';

  @override
  String vcRoomTendencyResult(String name, String source, String summary) {
    return '$name님의 발신 경향($source): $summary';
  }

  @override
  String vcRoomTendencyResultHostile(
    String name,
    String source,
    String summary,
  ) {
    return '$name님의 발신 경향($source): $summary — 적대적';
  }

  @override
  String vcRoomUnblocked(String name) {
    return '$name님의 차단을 해제했습니다';
  }

  @override
  String vcRoomBlocked(String name) {
    return '$name님을 차단했습니다(발언을 숨기고, 회원님의 룸에는 들어올 수 없습니다)';
  }

  @override
  String vcRoomActionFailed(String error) {
    return '실패했습니다: $error';
  }

  @override
  String get vcRoomPinToShares => '공유란에 고정';

  @override
  String vcRoomReportWhatChat(String name) {
    return '$name님의 발언';
  }

  @override
  String get vcRoomShowSummary => '미리보기에 간단 요약 표시';

  @override
  String get vcRoomAutoGenre => '장르 자동 선택';

  @override
  String get vcRoomEditAutoGenres => '자동 선택된 장르 편집';

  @override
  String get vcRoomGenres => '장르';

  @override
  String get vcRoomChatEmpty => '말한 내용의 텍스트 변환과 채팅·공유가 여기에 표시됩니다.';

  @override
  String vcRoomChatHiddenBlocked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '차단 중인 사용자의 발언 $count개를 숨기고 있습니다',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomTyping => '입력 중…';

  @override
  String get vcRoomDraft => '초안';

  @override
  String get vcRoomTypingLabel => '입력 중';

  @override
  String get vcRoomChatActions => '채팅 조작';

  @override
  String vcRoomTocStart(String title) {
    return '시작: $title';
  }

  @override
  String vcRoomTocShared(String name, String kind, String headline) {
    return '$name님이 $kind을(를) 공유: $headline';
  }

  @override
  String get vcRoomTocCaption => '공유와 텍스트 변환의 구분입니다.';

  @override
  String vcRoomMembersWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '참여 멤버($count)',
    );
    return '$_temp0';
  }

  @override
  String get vcRoomModerator => '모더레이터';

  @override
  String get vcRoomCustomPlugins => '커스텀 플러그인';

  @override
  String vcRoomUpdateFailed(String error) {
    return '설정을 업데이트하지 못했습니다: $error';
  }

  @override
  String get vcRoomShareAction => '공유하기';

  @override
  String get vcRoomSendDone => '전송 완료하기';

  @override
  String vcRoomPeerScreenTap(String name) {
    return '$name님의 화면(탭하면 전체 화면)';
  }

  @override
  String get vcRoomPinnedSharesEmpty => '고정한 공유가 여기에 표시됩니다';

  @override
  String vcRoomCompactShare(String headline) {
    return '공유: $headline';
  }

  @override
  String get vcRoomNoTranscripts => '아직 텍스트 변환이 없습니다';

  @override
  String get vcRoomTranscriptsDisabled => '텍스트 변환 비활성(요약 비공개)';

  @override
  String get vcRoomSharesCollapse => '공유 접기';

  @override
  String get vcRoomSharesExpand => '공유 모두 표시';

  @override
  String vcRoomSharedByPinned(String name) {
    return '$name님이 공유 · 📌';
  }

  @override
  String vcRoomSharedByAuto(String name) {
    return '$name님이 공유 · 자동 표시';
  }

  @override
  String vcRoomTranscriptMetaPinned(String name, String time) {
    return '$name · $time · 📌';
  }

  @override
  String vcRoomTranscriptMetaAuto(String name, String time) {
    return '$name · $time · 자동 표시';
  }

  @override
  String get vcRoomMuted => '뮤트 중';

  @override
  String get vcRoomScreenFrameActions => '공유 틀 조작';

  @override
  String vcRoomMemberSelf(String name) {
    return '$name(나)';
  }

  @override
  String get vcRoomForceMuted => '강제 뮤트';

  @override
  String get vcRoomMemberActions => '멤버 조작';

  @override
  String get vcRoomDiagnosticsLogHint =>
      '브라우저 / Xcode 로그에도 \'astell call:\', \'astell stream:\'으로 출력됩니다.';

  @override
  String get vcRoomCopy => '복사';

  @override
  String vcRoomBansLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'BAN($count) — 멤버 행의 \'…\'에서',
    );
    return '$_temp0';
  }

  @override
  String vcRoomBansLoadFailed(String error) {
    return 'BAN 목록을 읽지 못했습니다: $error';
  }

  @override
  String get vcRoomUnban => 'BAN 해제';

  @override
  String vcRoomReportBody(String what) {
    return '$what을(를) 신고합니다. RASQ 심사에서 확인합니다.';
  }

  @override
  String get vcRoomReportNoteHint => '추가 설명(선택)';

  @override
  String vcRoomReportFailed(String error) {
    return '신고하지 못했습니다: $error';
  }

  @override
  String get vcRoomReportSubmit => '신고하기';

  @override
  String get vcRoomReported => '신고했습니다. 심사에서 확인합니다';

  @override
  String vcRoomLiveBy(String name, String kind) {
    return '$name님이 $kind 중';
  }
}
