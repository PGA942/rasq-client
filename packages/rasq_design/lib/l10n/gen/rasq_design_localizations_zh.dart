// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'rasq_design_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class RasqDesignLocalizationsZh extends RasqDesignLocalizations {
  RasqDesignLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get designSearchHint => '搜索';

  @override
  String get designFilterReset => '重置';

  @override
  String designReplyParentSemantics(String name) {
    return '$name 的被回复帖子';
  }

  @override
  String designInlinePostSemantics(String name) {
    return '$name 的帖子（内嵌框架）';
  }

  @override
  String designPostSemantics(String name) {
    return '$name 的帖子';
  }

  @override
  String get designFollowedBy => '关注了你';

  @override
  String get designFollow => '关注';

  @override
  String get designFollowing => '关注中';

  @override
  String get designFollowRequested => '已申请';

  @override
  String get designFollowers => '关注者';

  @override
  String get designMenu => '菜单';

  @override
  String get designContentWarningHide => '隐藏';

  @override
  String get designContentWarningShow => '显示更多';

  @override
  String get designMediaPlay => '播放';

  @override
  String get designMediaSensitive => '此媒体可能含有敏感内容';

  @override
  String get designMediaReveal => '显示';

  @override
  String get designMediaHidden => '根据设置，此媒体不予显示';

  @override
  String designReactionMorePeople(int count) {
    return '+$count人';
  }

  @override
  String designRangeValue(int start, int end) {
    return '$start～$end';
  }

  @override
  String get designListSeparator => '、';

  @override
  String designThreadReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条回复',
    );
    return '$_temp0';
  }

  @override
  String designRepostedBy(String name) {
    return '$name 转帖了';
  }

  @override
  String get designActionBarSemantics => '操作栏';

  @override
  String get designRaiComingSoon => 'RAi（即将推出）';

  @override
  String get designVerifiedPerson => '已认证（个人）';

  @override
  String get designVerifiedCompany => '已认证（法人）';

  @override
  String get designVerifiedGovernment => '已认证（公共机构）';

  @override
  String get designExpandPost => '展开';

  @override
  String get designSortDefault => '默认';

  @override
  String get designSortReactionsDesc => '回应数（降序）';

  @override
  String get designSortReactionsAsc => '回应数（升序）';

  @override
  String get designProfileBanner => '横幅图片';

  @override
  String get designProfileEdit => '编辑';

  @override
  String get designProfileNotifications => '通知';

  @override
  String get designProfileRestricted => '该用户已被限制。';

  @override
  String get designProfileRestrictedShow => '显示';

  @override
  String designProfileJoined(String date) {
    return '$date注册';
  }

  @override
  String designProfileNotes(String count) {
    return '$count 条帖子';
  }

  @override
  String get designPollVote => '投票';

  @override
  String get designPollSubmit => '投票';

  @override
  String designPollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
    );
    return '$_temp0';
  }

  @override
  String get designPollEnded => '已结束';

  @override
  String get designPollVoted => ' 已投票';

  @override
  String get designTimeEnded => '已结束';

  @override
  String designTimeRemainingDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 天',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 小时',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 分钟',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩余 $count 秒',
    );
    return '$_temp0';
  }

  @override
  String get designTimeJustNow => '刚刚';

  @override
  String designTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟前',
    );
    return '$_temp0';
  }

  @override
  String designTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小时前',
    );
    return '$_temp0';
  }

  @override
  String designTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get designErrorRetry => '重试';

  @override
  String get designOverlayCancel => '取消';

  @override
  String get designOverlayClose => '关闭';

  @override
  String get designOverlaySwitcher => '切换 FOW';

  @override
  String get designOverlayResizeHandle => '调整大小手柄';

  @override
  String designRrlRange(int start, int end, String unit) {
    return '$start~$end$unit';
  }

  @override
  String get designRrlSend => '发送';

  @override
  String designRrlNoAuthFlow(String pluginId) {
    return '$pluginId:未配置登录流程（仅支持使用现有令牌注册）';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class RasqDesignLocalizationsZhHant extends RasqDesignLocalizationsZh {
  RasqDesignLocalizationsZhHant() : super('zh_Hant');

  @override
  String get designSearchHint => '搜尋';

  @override
  String get designFilterReset => '重設';

  @override
  String designReplyParentSemantics(String name) {
    return '$name 的被回覆貼文';
  }

  @override
  String designInlinePostSemantics(String name) {
    return '$name 的貼文（內嵌框架）';
  }

  @override
  String designPostSemantics(String name) {
    return '$name 的貼文';
  }

  @override
  String get designFollowedBy => '已追蹤你';

  @override
  String get designFollow => '追蹤';

  @override
  String get designFollowing => '追蹤中';

  @override
  String get designFollowRequested => '已申請';

  @override
  String get designFollowers => '追蹤者';

  @override
  String get designMenu => '選單';

  @override
  String get designContentWarningHide => '隱藏';

  @override
  String get designContentWarningShow => '顯示更多';

  @override
  String get designMediaPlay => '播放';

  @override
  String get designMediaSensitive => '此媒體可能含有敏感內容';

  @override
  String get designMediaReveal => '顯示';

  @override
  String get designMediaHidden => '依照設定，此媒體不予顯示';

  @override
  String designReactionMorePeople(int count) {
    return '+$count人';
  }

  @override
  String designRangeValue(int start, int end) {
    return '$start～$end';
  }

  @override
  String get designListSeparator => '、';

  @override
  String designThreadReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 則回覆',
    );
    return '$_temp0';
  }

  @override
  String designRepostedBy(String name) {
    return '$name 轉貼了';
  }

  @override
  String get designActionBarSemantics => '操作列';

  @override
  String get designRaiComingSoon => 'RAi（即將推出）';

  @override
  String get designVerifiedPerson => '已驗證（個人）';

  @override
  String get designVerifiedCompany => '已驗證（法人）';

  @override
  String get designVerifiedGovernment => '已驗證（公共機關）';

  @override
  String get designExpandPost => '展開';

  @override
  String get designSortDefault => '預設';

  @override
  String get designSortReactionsDesc => '回應數（由多到少）';

  @override
  String get designSortReactionsAsc => '回應數（由少到多）';

  @override
  String get designProfileBanner => '橫幅圖片';

  @override
  String get designProfileEdit => '編輯';

  @override
  String get designProfileNotifications => '通知';

  @override
  String get designProfileRestricted => '此使用者已被限制。';

  @override
  String get designProfileRestrictedShow => '顯示';

  @override
  String designProfileJoined(String date) {
    return '$date加入';
  }

  @override
  String designProfileNotes(String count) {
    return '$count 則貼文';
  }

  @override
  String get designPollVote => '投票';

  @override
  String get designPollSubmit => '投票';

  @override
  String designPollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 票',
    );
    return '$_temp0';
  }

  @override
  String get designPollEnded => '已結束';

  @override
  String get designPollVoted => ' 已投票';

  @override
  String get designTimeEnded => '已結束';

  @override
  String designTimeRemainingDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩餘 $count 天',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩餘 $count 小時',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩餘 $count 分鐘',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '剩餘 $count 秒',
    );
    return '$_temp0';
  }

  @override
  String get designTimeJustNow => '剛剛';

  @override
  String designTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分鐘前',
    );
    return '$_temp0';
  }

  @override
  String designTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 小時前',
    );
    return '$_temp0';
  }

  @override
  String designTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天前',
    );
    return '$_temp0';
  }

  @override
  String get designErrorRetry => '重試';

  @override
  String get designOverlayCancel => '取消';

  @override
  String get designOverlayClose => '關閉';

  @override
  String get designOverlaySwitcher => '切換 FOW';

  @override
  String get designOverlayResizeHandle => '調整大小控點';

  @override
  String designRrlRange(int start, int end, String unit) {
    return '$start~$end$unit';
  }

  @override
  String get designRrlSend => '傳送';

  @override
  String designRrlNoAuthFlow(String pluginId) {
    return '$pluginId:未設定登入流程（僅支援使用現有權杖註冊）';
  }
}
