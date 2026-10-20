// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'rasq_design_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class RasqDesignLocalizationsJa extends RasqDesignLocalizations {
  RasqDesignLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get designSearchHint => '検索';

  @override
  String get designFilterReset => 'リセット';

  @override
  String designReplyParentSemantics(String name) {
    return '$name のリプライ元投稿';
  }

  @override
  String designInlinePostSemantics(String name) {
    return '$nameの投稿(インラインフレーム)';
  }

  @override
  String designPostSemantics(String name) {
    return '$nameの投稿';
  }

  @override
  String get designFollowedBy => 'フォローされています';

  @override
  String get designFollow => 'フォロー';

  @override
  String get designFollowing => 'フォロー中';

  @override
  String get designFollowRequested => '申請中';

  @override
  String get designFollowers => 'フォロワー';

  @override
  String get designMenu => 'メニュー';

  @override
  String get designContentWarningHide => '隠す';

  @override
  String get designContentWarningShow => 'もっと見る';

  @override
  String get designMediaPlay => '再生';

  @override
  String get designMediaSensitive => 'センシティブな可能性のあるメディアです';

  @override
  String get designMediaReveal => '表示する';

  @override
  String get designMediaHidden => '表示しない設定のメディアです';

  @override
  String designReactionMorePeople(int count) {
    return '+$count人';
  }

  @override
  String designRangeValue(int start, int end) {
    return '$start〜$end';
  }

  @override
  String get designListSeparator => '、';

  @override
  String designThreadReplies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の返信',
    );
    return '$_temp0';
  }

  @override
  String designRepostedBy(String name) {
    return '$nameがリノートしました';
  }

  @override
  String get designActionBarSemantics => 'アクションバー';

  @override
  String get designRaiComingSoon => 'RAi(準備中)';

  @override
  String get designVerifiedPerson => '認証済み(個人)';

  @override
  String get designVerifiedCompany => '認証済み(法人)';

  @override
  String get designVerifiedGovernment => '認証済み(公的機関)';

  @override
  String get designExpandPost => '展開する';

  @override
  String get designSortDefault => 'デフォルト';

  @override
  String get designSortReactionsDesc => 'リアクション数(降順)';

  @override
  String get designSortReactionsAsc => 'リアクション数(昇順)';

  @override
  String get designProfileBanner => 'バナー画像';

  @override
  String get designProfileEdit => '編集する';

  @override
  String get designProfileNotifications => '通知';

  @override
  String get designProfileRestricted => 'このユーザーは制限されています。';

  @override
  String get designProfileRestrictedShow => '表示';

  @override
  String designProfileJoined(String date) {
    return '$dateに登録';
  }

  @override
  String designProfileNotes(String count) {
    return '$count ノート';
  }

  @override
  String get designPollVote => '投票';

  @override
  String get designPollSubmit => '投票する';

  @override
  String designPollVotes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count票',
    );
    return '$_temp0';
  }

  @override
  String get designPollEnded => '終了';

  @override
  String get designPollVoted => ' 投票済み';

  @override
  String get designTimeEnded => '終了';

  @override
  String designTimeRemainingDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '残り $count日',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '残り $count時間',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '残り $count分',
    );
    return '$_temp0';
  }

  @override
  String designTimeRemainingSeconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '残り $count秒',
    );
    return '$_temp0';
  }

  @override
  String get designTimeJustNow => 'たった今';

  @override
  String designTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count分前',
    );
    return '$_temp0';
  }

  @override
  String designTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count時間前',
    );
    return '$_temp0';
  }

  @override
  String designTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count日前',
    );
    return '$_temp0';
  }

  @override
  String get designErrorRetry => '見てみる';

  @override
  String get designOverlayCancel => 'キャンセル';

  @override
  String get designOverlayClose => '閉じる';

  @override
  String get designOverlaySwitcher => 'FOW切り替え';

  @override
  String get designOverlayResizeHandle => 'サイズ変更ハンドル';

  @override
  String designRrlRange(int start, int end, String unit) {
    return '$start〜$end$unit';
  }

  @override
  String get designRrlSend => '送信';

  @override
  String designRrlNoAuthFlow(String pluginId) {
    return '$pluginId: 認証フローが構成されていません(既存トークンでの実登録のみ)';
  }
}
