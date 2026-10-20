// tool/l10n_merge.dart が lib/l10n/parts/*.arb から作る(手で直さない)。Flutter に依らない部品の文言 (D-533、docs/I18N.md)。
// ignore_for_file: type=lint

import 'package:intl/intl.dart' as intl;

/// 文言(言語ごとの実装は [lookupSnsMisskeyLocalizations])。
abstract class SnsMisskeyLocalizations {
  const SnsMisskeyLocalizations(this.localeName);

  /// この文言の言語(`ja` など)。
  final String localeName;

  /// 訳のある言語。
  static const supportedLocales = <String>['ja', 'en', 'ko', 'zh', 'zh_Hant'];

  /// アカウントの設定の節の見出し
  ///
  /// ja: **"アカウントの種類"**
  String get misskeyAccountKind;

  /// アカウントの設定のページの下の説明
  ///
  /// ja: **"これらの設定は接続先の Misskey サーバーに保存されます。"**
  String get misskeyAccountNote;

  /// Misskey の設定のページの見出し: アカウント(サーバーに保存する設定)
  ///
  /// ja: **"アカウント"**
  String get misskeyAccountTitle;

  /// 投稿のアクションの名前: お気に入り
  ///
  /// ja: **"お気に入り"**
  String get misskeyActionFavorite;

  /// 投稿のアクションの名前: リアクション
  ///
  /// ja: **"リアクション"**
  String get misskeyActionReaction;

  /// 投稿のアクションの名前: リノート(Misskey の再投稿の呼び名)
  ///
  /// ja: **"リノート"**
  String get misskeyActionRenote;

  /// 投稿のアクションの名前: 返信
  ///
  /// ja: **"返信"**
  String get misskeyActionReply;

  /// Misskey のサーバーにつなげなかった理由が「許可されていない」のとき、誤りの後ろに足す手がかり(頭に空白)
  ///
  /// ja: **" (アプリのネットワーク権限/サンドボックス設定を確認してください)"**
  String get misskeyApiSandboxHint;

  /// Misskey のサーバーが時間内に答えなかったとき。host はサーバー、seconds は待った秒数
  ///
  /// ja: **"{seconds, plural, other{{host} からの応答がありません({seconds}秒)。インターネット接続を確認してください}}"**
  String misskeyApiTimeout(String host, int seconds);

  /// Misskey のサーバーにつなげなかったとき。host はサーバー、error は理由(英語のことがある)、hint は misskeyApiSandboxHint か空
  ///
  /// ja: **"{host} に接続できません: {error}{hint}"**
  String misskeyApiUnreachable(String host, String error, String hint);

  /// Misskey のサーバーにつなげなかったとき(アップロード)。host はサーバー、error は理由
  ///
  /// ja: **"{host} に接続できません: {error}"**
  String misskeyApiUnreachablePlain(String host, String error);

  /// MiAuth(Misskey のブラウザでの認証)を始めたときの案内。「許可する」は Misskey のボタン、「認証を確認」はアプリのボタンの名前
  ///
  /// ja: **"ブラウザで「許可する」を押したら、このアプリに戻って「認証を確認」を押してください。"**
  String get misskeyAuthHint;

  /// 「認証を確認」を押したが、まだブラウザで許可していないとき
  ///
  /// ja: **"まだ許可されていません。ブラウザで許可してから再度お試しください。"**
  String get misskeyAuthNotYet;

  /// スイッチ: 自分がフォローしている人からのフォローは自動で承認する
  ///
  /// ja: **"フォロー中の人からのフォローは自動で承認"**
  String get misskeyAutoAcceptFollowed;

  /// プロフィールの欄: 誕生日。例の日付の形(年-月-日)は変えない
  ///
  /// ja: **"誕生日(例: 2000-01-31)"**
  String get misskeyBirthday;

  /// セーフモードの設定の節の見出し。CW は Content Warning の略
  ///
  /// ja: **"注釈(CW)"**
  String get misskeyCw;

  /// プロフィールの欄: 自己紹介
  ///
  /// ja: **"自己紹介"**
  String get misskeyDescription;

  /// アカウントの設定の節の見出し
  ///
  /// ja: **"フォロワーの一覧を見せる相手"**
  String get misskeyFollowersVisibility;

  /// アカウントの設定の節の見出し
  ///
  /// ja: **"フォローの一覧を見せる相手"**
  String get misskeyFollowingVisibility;

  /// スイッチ: オンラインかどうかを人に見せない
  ///
  /// ja: **"オンライン状態を隠す"**
  String get misskeyHideOnlineStatus;

  /// 誕生日の形が違うとき。日付の形(年-月-日)は変えない
  ///
  /// ja: **"誕生日は 2000-01-31 の形で入れてください"**
  String get misskeyInvalidBirthday;

  /// 設定の値の形が違うとき(真偽の値)
  ///
  /// ja: **"値は true / false です"**
  String get misskeyInvalidBool;

  /// 公開範囲の値が違うとき。public / followers / private は値の名前で訳さない
  ///
  /// ja: **"公開範囲は public / followers / private です"**
  String get misskeyInvalidVisibility;

  /// スイッチ: 自動で投稿するアカウント(Bot)として印を付ける
  ///
  /// ja: **"Botとして設定"**
  String get misskeyIsBot;

  /// スイッチ: Misskey の「Cat」(猫のアカウント)にする
  ///
  /// ja: **"Catにする"**
  String get misskeyIsCat;

  /// 上のスイッチの補足
  ///
  /// ja: **"発言が Cat 語になり、猫耳が付きます"**
  String get misskeyIsCatSubtitle;

  /// スイッチ: アカウントを見つけやすくする
  ///
  /// ja: **"アカウントを見つけやすくする"**
  String get misskeyIsExplorable;

  /// 上のスイッチの補足。「みつける」は Misskey の画面の名前
  ///
  /// ja: **"「みつける」やユーザー検索に表示されます"**
  String get misskeyIsExplorableSubtitle;

  /// スイッチ: フォローを承認制にする
  ///
  /// ja: **"フォローを承認制にする"**
  String get misskeyIsLocked;

  /// 上のスイッチの補足
  ///
  /// ja: **"フォローされる前にあなたの承認が必要になります"**
  String get misskeyIsLockedSubtitle;

  /// プロフィールの欄: 場所
  ///
  /// ja: **"場所"**
  String get misskeyLocation;

  /// プロフィールの欄: 表示名
  ///
  /// ja: **"名前"**
  String get misskeyName;

  /// スイッチ: 検索エンジンに載せない
  ///
  /// ja: **"検索エンジンに載せない"**
  String get misskeyNoCrawle;

  /// 上のスイッチの補足
  ///
  /// ja: **"検索エンジンによるインデックスを避けるよう求めます"**
  String get misskeyNoCrawleSubtitle;

  /// Misskey のシステム通知の見出し: 実績(Misskey の機能)を得た
  ///
  /// ja: **"実績を獲得しました"**
  String get misskeyNoticeAchievement;

  /// Misskey のシステム通知の見出し: 外部のアプリからの通知(アプリが見出しを付けなかったとき)
  ///
  /// ja: **"アプリからの通知"**
  String get misskeyNoticeApp;

  /// Misskey のシステム通知の見出し: データの書き出しが終わった
  ///
  /// ja: **"エクスポートが完了しました"**
  String get misskeyNoticeExportCompleted;

  /// Misskey のシステム通知の見出し: アカウントに新しいログインがあった
  ///
  /// ja: **"新しいログインがありました"**
  String get misskeyNoticeLogin;

  /// Misskey のシステム通知の見出し: ロール(サーバーの役割)が付いた
  ///
  /// ja: **"ロールが付与されました"**
  String get misskeyNoticeRoleAssigned;

  /// Misskey のシステム通知の見出し: 試しの通知
  ///
  /// ja: **"テスト通知"**
  String get misskeyNoticeTest;

  /// Misskey の知らない種類のシステム通知の見出し。type は通知の種類の名前(英字)
  ///
  /// ja: **"通知 ({type})"**
  String misskeyNoticeUnknown(String type);

  /// スイッチ: 注釈の付いた投稿を初めから開いて出す
  ///
  /// ja: **"注釈付き投稿を自動で開く"**
  String get misskeyOpenCw;

  /// セキュリティの設定の節の見出し。MiAuth は Misskey の認証の方式の名前
  ///
  /// ja: **"このアプリに許可された権限 (MiAuth)"**
  String get misskeyPermissions;

  /// アカウントの設定の節の見出し
  ///
  /// ja: **"プロフィール"**
  String get misskeyProfile;

  /// Misskey の Web 版で編集する項目へ進む行
  ///
  /// ja: **"アイコン・バナー・補足情報"**
  String get misskeyProfileWeb;

  /// 上の行の補足
  ///
  /// ja: **"web 版で編集します"**
  String get misskeyProfileWebSubtitle;

  /// スイッチ: 自分のリアクションの一覧を人に見せる
  ///
  /// ja: **"リアクション一覧を公開する"**
  String get misskeyPublicReactions;

  /// アカウントの設定の節の見出し
  ///
  /// ja: **"公開範囲"**
  String get misskeyPublicity;

  /// Misskey の設定のページの見出し
  ///
  /// ja: **"プライバシーとセーフモード"**
  String get misskeySafetyTitle;

  /// MiAuth の権限(read:account)の説明
  ///
  /// ja: **"アカウント情報の読み取り"**
  String get misskeyScopeReadAccount;

  /// MiAuth の権限(read:blocks)の説明
  ///
  /// ja: **"ブロックの読み取り"**
  String get misskeyScopeReadBlocks;

  /// MiAuth の権限(read:chat)の説明
  ///
  /// ja: **"チャットの読み取り"**
  String get misskeyScopeReadChat;

  /// MiAuth の権限(read:drive)の説明。ドライブは Misskey のファイルの置き場
  ///
  /// ja: **"ドライブの読み取り"**
  String get misskeyScopeReadDrive;

  /// MiAuth の権限(read:favorites)の説明
  ///
  /// ja: **"お気に入りの読み取り"**
  String get misskeyScopeReadFavorites;

  /// MiAuth の権限(read:following)の説明
  ///
  /// ja: **"フォローの読み取り"**
  String get misskeyScopeReadFollowing;

  /// MiAuth の権限(read:messaging)の説明
  ///
  /// ja: **"ダイレクト投稿の読み取り"**
  String get misskeyScopeReadMessaging;

  /// MiAuth の権限(read:mutes)の説明
  ///
  /// ja: **"ミュートの読み取り"**
  String get misskeyScopeReadMutes;

  /// MiAuth の権限(read:notifications)の説明
  ///
  /// ja: **"通知の読み取り"**
  String get misskeyScopeReadNotifications;

  /// MiAuth の権限(read:reactions)の説明
  ///
  /// ja: **"リアクションの読み取り"**
  String get misskeyScopeReadReactions;

  /// MiAuth の権限(write:blocks)の説明
  ///
  /// ja: **"ブロック・解除"**
  String get misskeyScopeWriteBlocks;

  /// MiAuth の権限(write:chat)の説明
  ///
  /// ja: **"チャットの送信"**
  String get misskeyScopeWriteChat;

  /// MiAuth の権限(write:drive)の説明
  ///
  /// ja: **"ドライブへのアップロード"**
  String get misskeyScopeWriteDrive;

  /// MiAuth の権限(write:favorites)の説明
  ///
  /// ja: **"お気に入りの追加・削除"**
  String get misskeyScopeWriteFavorites;

  /// MiAuth の権限(write:following)の説明
  ///
  /// ja: **"フォロー・解除"**
  String get misskeyScopeWriteFollowing;

  /// MiAuth の権限(write:messaging)の説明
  ///
  /// ja: **"ダイレクト投稿の送信"**
  String get misskeyScopeWriteMessaging;

  /// MiAuth の権限(write:mutes)の説明
  ///
  /// ja: **"ミュート・解除"**
  String get misskeyScopeWriteMutes;

  /// MiAuth の権限(write:notes)の説明。ノートは Misskey の投稿の呼び名
  ///
  /// ja: **"ノートの作成・削除"**
  String get misskeyScopeWriteNotes;

  /// MiAuth の権限(write:notifications)の説明
  ///
  /// ja: **"通知の既読化"**
  String get misskeyScopeWriteNotifications;

  /// MiAuth の権限(write:reactions)の説明
  ///
  /// ja: **"リアクションの追加・削除"**
  String get misskeyScopeWriteReactions;

  /// セキュリティの設定のページの下の説明
  ///
  /// ja: **"パスワードが必要な操作は web 版で行います。アクセストークンは端末内の安全な領域にのみ保存されます。"**
  String get misskeySecurityNote;

  /// Misskey の設定のページの見出し
  ///
  /// ja: **"セキュリティ"**
  String get misskeySecurityTitle;

  /// 閲覧注意のメディアの出し方: ぼかす
  ///
  /// ja: **"ぼかして表示"**
  String get misskeySensitiveBlur;

  /// 上の選択肢の補足
  ///
  /// ja: **"タップで開きます(標準)"**
  String get misskeySensitiveBlurSubtitle;

  /// 閲覧注意のメディアの出し方: 出さない
  ///
  /// ja: **"表示しない(セーフモード)"**
  String get misskeySensitiveHide;

  /// 上の選択肢の補足
  ///
  /// ja: **"閲覧注意メディアをタイルから取り除きます"**
  String get misskeySensitiveHideSubtitle;

  /// セーフモードの設定の節の見出し
  ///
  /// ja: **"閲覧注意(センシティブ)メディア"**
  String get misskeySensitiveMedia;

  /// 閲覧注意のメディアの出し方: そのまま出す
  ///
  /// ja: **"ぼかさず表示"**
  String get misskeySensitiveShow;

  /// Misskey の設定の文字の欄の、保存するボタン
  ///
  /// ja: **"保存"**
  String get misskeySettingsSave;

  /// タイムラインの設定の節の見出し
  ///
  /// ja: **"表示する投稿"**
  String get misskeyTimelinePosts;

  /// Misskey の設定のページの見出し: タイムライン
  ///
  /// ja: **"タイムライン"**
  String get misskeyTimelineTitle;

  /// Misskey の Web 版の、アクセストークンの画面へ進む行
  ///
  /// ja: **"アクセストークンの管理"**
  String get misskeyTokens;

  /// 上の行の補足
  ///
  /// ja: **"発行済みトークンの確認と失効"**
  String get misskeyTokensSubtitle;

  /// Misskey の Web 版の、セキュリティの画面へ進む行
  ///
  /// ja: **"二要素認証・ログイン履歴"**
  String get misskeyTwoFactor;

  /// Misskey へのファイルのアップロードが時間内に終わらなかったとき
  ///
  /// ja: **"アップロードがタイムアウトしました"**
  String get misskeyUploadTimeout;

  /// 一覧を見せる相手の選択肢: フォロワーだけ
  ///
  /// ja: **"フォロワーだけ"**
  String get misskeyVisibilityFollowers;

  /// 一覧を見せる相手の選択肢: 自分だけ
  ///
  /// ja: **"非公開"**
  String get misskeyVisibilityPrivate;

  /// 一覧を見せる相手の選択肢: 誰でも
  ///
  /// ja: **"公開"**
  String get misskeyVisibilityPublic;

  /// セキュリティの設定の節の見出し
  ///
  /// ja: **"web で行う設定"**
  String get misskeyWebSettings;

  /// スイッチ: TL にリノートを出す
  ///
  /// ja: **"リノートを表示"**
  String get misskeyWithRenotes;

  /// 上のスイッチの補足
  ///
  /// ja: **"オフにすると引用のないリノートを取得しません"**
  String get misskeyWithRenotesSubtitle;

  /// スイッチ: TL にほかの人への返信を出す
  ///
  /// ja: **"他の人への返信を表示"**
  String get misskeyWithReplies;

  /// 上のスイッチの補足
  ///
  /// ja: **"フォロー中の人が他の人へ送った返信をTLに含めます"**
  String get misskeyWithRepliesSubtitle;
}

/// `ja` の文言(テンプレート)。
class SnsMisskeyLocalizationsJa extends SnsMisskeyLocalizations {
  const SnsMisskeyLocalizationsJa([super.localeName = 'ja']);

  @override
  String get misskeyAccountKind => 'アカウントの種類';

  @override
  String get misskeyAccountNote => 'これらの設定は接続先の Misskey サーバーに保存されます。';

  @override
  String get misskeyAccountTitle => 'アカウント';

  @override
  String get misskeyActionFavorite => 'お気に入り';

  @override
  String get misskeyActionReaction => 'リアクション';

  @override
  String get misskeyActionRenote => 'リノート';

  @override
  String get misskeyActionReply => '返信';

  @override
  String get misskeyApiSandboxHint => ' (アプリのネットワーク権限/サンドボックス設定を確認してください)';

  @override
  String misskeyApiTimeout(String host, int seconds) => '${intl.Intl.pluralLogic(seconds, locale: localeName, other: '${host} からの応答がありません(${seconds}秒)。インターネット接続を確認してください')}';

  @override
  String misskeyApiUnreachable(String host, String error, String hint) => '${host} に接続できません: ${error}${hint}';

  @override
  String misskeyApiUnreachablePlain(String host, String error) => '${host} に接続できません: ${error}';

  @override
  String get misskeyAuthHint => 'ブラウザで「許可する」を押したら、このアプリに戻って「認証を確認」を押してください。';

  @override
  String get misskeyAuthNotYet => 'まだ許可されていません。ブラウザで許可してから再度お試しください。';

  @override
  String get misskeyAutoAcceptFollowed => 'フォロー中の人からのフォローは自動で承認';

  @override
  String get misskeyBirthday => '誕生日(例: 2000-01-31)';

  @override
  String get misskeyCw => '注釈(CW)';

  @override
  String get misskeyDescription => '自己紹介';

  @override
  String get misskeyFollowersVisibility => 'フォロワーの一覧を見せる相手';

  @override
  String get misskeyFollowingVisibility => 'フォローの一覧を見せる相手';

  @override
  String get misskeyHideOnlineStatus => 'オンライン状態を隠す';

  @override
  String get misskeyInvalidBirthday => '誕生日は 2000-01-31 の形で入れてください';

  @override
  String get misskeyInvalidBool => '値は true / false です';

  @override
  String get misskeyInvalidVisibility => '公開範囲は public / followers / private です';

  @override
  String get misskeyIsBot => 'Botとして設定';

  @override
  String get misskeyIsCat => 'Catにする';

  @override
  String get misskeyIsCatSubtitle => '発言が Cat 語になり、猫耳が付きます';

  @override
  String get misskeyIsExplorable => 'アカウントを見つけやすくする';

  @override
  String get misskeyIsExplorableSubtitle => '「みつける」やユーザー検索に表示されます';

  @override
  String get misskeyIsLocked => 'フォローを承認制にする';

  @override
  String get misskeyIsLockedSubtitle => 'フォローされる前にあなたの承認が必要になります';

  @override
  String get misskeyLocation => '場所';

  @override
  String get misskeyName => '名前';

  @override
  String get misskeyNoCrawle => '検索エンジンに載せない';

  @override
  String get misskeyNoCrawleSubtitle => '検索エンジンによるインデックスを避けるよう求めます';

  @override
  String get misskeyNoticeAchievement => '実績を獲得しました';

  @override
  String get misskeyNoticeApp => 'アプリからの通知';

  @override
  String get misskeyNoticeExportCompleted => 'エクスポートが完了しました';

  @override
  String get misskeyNoticeLogin => '新しいログインがありました';

  @override
  String get misskeyNoticeRoleAssigned => 'ロールが付与されました';

  @override
  String get misskeyNoticeTest => 'テスト通知';

  @override
  String misskeyNoticeUnknown(String type) => '通知 (${type})';

  @override
  String get misskeyOpenCw => '注釈付き投稿を自動で開く';

  @override
  String get misskeyPermissions => 'このアプリに許可された権限 (MiAuth)';

  @override
  String get misskeyProfile => 'プロフィール';

  @override
  String get misskeyProfileWeb => 'アイコン・バナー・補足情報';

  @override
  String get misskeyProfileWebSubtitle => 'web 版で編集します';

  @override
  String get misskeyPublicReactions => 'リアクション一覧を公開する';

  @override
  String get misskeyPublicity => '公開範囲';

  @override
  String get misskeySafetyTitle => 'プライバシーとセーフモード';

  @override
  String get misskeyScopeReadAccount => 'アカウント情報の読み取り';

  @override
  String get misskeyScopeReadBlocks => 'ブロックの読み取り';

  @override
  String get misskeyScopeReadChat => 'チャットの読み取り';

  @override
  String get misskeyScopeReadDrive => 'ドライブの読み取り';

  @override
  String get misskeyScopeReadFavorites => 'お気に入りの読み取り';

  @override
  String get misskeyScopeReadFollowing => 'フォローの読み取り';

  @override
  String get misskeyScopeReadMessaging => 'ダイレクト投稿の読み取り';

  @override
  String get misskeyScopeReadMutes => 'ミュートの読み取り';

  @override
  String get misskeyScopeReadNotifications => '通知の読み取り';

  @override
  String get misskeyScopeReadReactions => 'リアクションの読み取り';

  @override
  String get misskeyScopeWriteBlocks => 'ブロック・解除';

  @override
  String get misskeyScopeWriteChat => 'チャットの送信';

  @override
  String get misskeyScopeWriteDrive => 'ドライブへのアップロード';

  @override
  String get misskeyScopeWriteFavorites => 'お気に入りの追加・削除';

  @override
  String get misskeyScopeWriteFollowing => 'フォロー・解除';

  @override
  String get misskeyScopeWriteMessaging => 'ダイレクト投稿の送信';

  @override
  String get misskeyScopeWriteMutes => 'ミュート・解除';

  @override
  String get misskeyScopeWriteNotes => 'ノートの作成・削除';

  @override
  String get misskeyScopeWriteNotifications => '通知の既読化';

  @override
  String get misskeyScopeWriteReactions => 'リアクションの追加・削除';

  @override
  String get misskeySecurityNote => 'パスワードが必要な操作は web 版で行います。アクセストークンは端末内の安全な領域にのみ保存されます。';

  @override
  String get misskeySecurityTitle => 'セキュリティ';

  @override
  String get misskeySensitiveBlur => 'ぼかして表示';

  @override
  String get misskeySensitiveBlurSubtitle => 'タップで開きます(標準)';

  @override
  String get misskeySensitiveHide => '表示しない(セーフモード)';

  @override
  String get misskeySensitiveHideSubtitle => '閲覧注意メディアをタイルから取り除きます';

  @override
  String get misskeySensitiveMedia => '閲覧注意(センシティブ)メディア';

  @override
  String get misskeySensitiveShow => 'ぼかさず表示';

  @override
  String get misskeySettingsSave => '保存';

  @override
  String get misskeyTimelinePosts => '表示する投稿';

  @override
  String get misskeyTimelineTitle => 'タイムライン';

  @override
  String get misskeyTokens => 'アクセストークンの管理';

  @override
  String get misskeyTokensSubtitle => '発行済みトークンの確認と失効';

  @override
  String get misskeyTwoFactor => '二要素認証・ログイン履歴';

  @override
  String get misskeyUploadTimeout => 'アップロードがタイムアウトしました';

  @override
  String get misskeyVisibilityFollowers => 'フォロワーだけ';

  @override
  String get misskeyVisibilityPrivate => '非公開';

  @override
  String get misskeyVisibilityPublic => '公開';

  @override
  String get misskeyWebSettings => 'web で行う設定';

  @override
  String get misskeyWithRenotes => 'リノートを表示';

  @override
  String get misskeyWithRenotesSubtitle => 'オフにすると引用のないリノートを取得しません';

  @override
  String get misskeyWithReplies => '他の人への返信を表示';

  @override
  String get misskeyWithRepliesSubtitle => 'フォロー中の人が他の人へ送った返信をTLに含めます';
}

/// `en` の文言(訳の無いキーは ja の文言)。
class SnsMisskeyLocalizationsEn extends SnsMisskeyLocalizationsJa {
  const SnsMisskeyLocalizationsEn([super.localeName = 'en']);

  @override
  String get misskeyAccountKind => 'Account type';

  @override
  String get misskeyAccountNote => 'These settings are saved on the connected Misskey server.';

  @override
  String get misskeyAccountTitle => 'Account';

  @override
  String get misskeyActionFavorite => 'Favorite';

  @override
  String get misskeyActionReaction => 'Reaction';

  @override
  String get misskeyActionRenote => 'Renote';

  @override
  String get misskeyActionReply => 'Reply';

  @override
  String get misskeyApiSandboxHint => ' (check the app\'s network permission / sandbox settings)';

  @override
  String misskeyApiTimeout(String host, int seconds) => '${intl.Intl.pluralLogic(seconds, locale: localeName, one: 'No response from ${host} (1 second). Check your internet connection', other: 'No response from ${host} (${seconds} seconds). Check your internet connection')}';

  @override
  String misskeyApiUnreachable(String host, String error, String hint) => 'Can\'t connect to ${host}: ${error}${hint}';

  @override
  String misskeyApiUnreachablePlain(String host, String error) => 'Can\'t connect to ${host}: ${error}';

  @override
  String get misskeyAuthHint => 'After tapping "Allow" in the browser, come back to this app and tap "Check authentication".';

  @override
  String get misskeyAuthNotYet => 'Not authorized yet. Allow access in the browser, then try again.';

  @override
  String get misskeyAutoAcceptFollowed => 'Automatically approve follows from people you follow';

  @override
  String get misskeyBirthday => 'Birthday (e.g. 2000-01-31)';

  @override
  String get misskeyCw => 'Content warning (CW)';

  @override
  String get misskeyDescription => 'Bio';

  @override
  String get misskeyFollowersVisibility => 'Who can see your followers list';

  @override
  String get misskeyFollowingVisibility => 'Who can see your following list';

  @override
  String get misskeyHideOnlineStatus => 'Hide online status';

  @override
  String get misskeyInvalidBirthday => 'Enter your birthday in the form 2000-01-31';

  @override
  String get misskeyInvalidBool => 'The value must be true or false';

  @override
  String get misskeyInvalidVisibility => 'Visibility must be public, followers, or private';

  @override
  String get misskeyIsBot => 'This is a bot account';

  @override
  String get misskeyIsCat => 'Become a Cat';

  @override
  String get misskeyIsCatSubtitle => 'Your posts turn into cat speak and you get cat ears';

  @override
  String get misskeyIsExplorable => 'Make your account discoverable';

  @override
  String get misskeyIsExplorableSubtitle => 'Shown in "Explore" and user search';

  @override
  String get misskeyIsLocked => 'Require approval for follows';

  @override
  String get misskeyIsLockedSubtitle => 'People need your approval before they can follow you';

  @override
  String get misskeyLocation => 'Location';

  @override
  String get misskeyName => 'Name';

  @override
  String get misskeyNoCrawle => 'Keep out of search engines';

  @override
  String get misskeyNoCrawleSubtitle => 'Asks search engines not to index your account';

  @override
  String get misskeyNoticeAchievement => 'Achievement unlocked';

  @override
  String get misskeyNoticeApp => 'Notification from an app';

  @override
  String get misskeyNoticeExportCompleted => 'Export completed';

  @override
  String get misskeyNoticeLogin => 'New login to your account';

  @override
  String get misskeyNoticeRoleAssigned => 'A role was assigned to you';

  @override
  String get misskeyNoticeTest => 'Test notification';

  @override
  String misskeyNoticeUnknown(String type) => 'Notification (${type})';

  @override
  String get misskeyOpenCw => 'Automatically expand posts with a content warning';

  @override
  String get misskeyPermissions => 'Permissions granted to this app (MiAuth)';

  @override
  String get misskeyProfile => 'Profile';

  @override
  String get misskeyProfileWeb => 'Avatar, banner, and additional info';

  @override
  String get misskeyProfileWebSubtitle => 'Edit on the web';

  @override
  String get misskeyPublicReactions => 'Make your reactions public';

  @override
  String get misskeyPublicity => 'Visibility';

  @override
  String get misskeySafetyTitle => 'Privacy and safe mode';

  @override
  String get misskeyScopeReadAccount => 'Read account information';

  @override
  String get misskeyScopeReadBlocks => 'Read blocks';

  @override
  String get misskeyScopeReadChat => 'Read chats';

  @override
  String get misskeyScopeReadDrive => 'Read Drive';

  @override
  String get misskeyScopeReadFavorites => 'Read favorites';

  @override
  String get misskeyScopeReadFollowing => 'Read follows';

  @override
  String get misskeyScopeReadMessaging => 'Read direct posts';

  @override
  String get misskeyScopeReadMutes => 'Read mutes';

  @override
  String get misskeyScopeReadNotifications => 'Read notifications';

  @override
  String get misskeyScopeReadReactions => 'Read reactions';

  @override
  String get misskeyScopeWriteBlocks => 'Block and unblock';

  @override
  String get misskeyScopeWriteChat => 'Send chats';

  @override
  String get misskeyScopeWriteDrive => 'Upload to Drive';

  @override
  String get misskeyScopeWriteFavorites => 'Add and remove favorites';

  @override
  String get misskeyScopeWriteFollowing => 'Follow and unfollow';

  @override
  String get misskeyScopeWriteMessaging => 'Send direct posts';

  @override
  String get misskeyScopeWriteMutes => 'Mute and unmute';

  @override
  String get misskeyScopeWriteNotes => 'Create and delete notes';

  @override
  String get misskeyScopeWriteNotifications => 'Mark notifications as read';

  @override
  String get misskeyScopeWriteReactions => 'Add and remove reactions';

  @override
  String get misskeySecurityNote => 'Actions that require your password are done on the web. Access tokens are stored only in the secure storage on your device.';

  @override
  String get misskeySecurityTitle => 'Security';

  @override
  String get misskeySensitiveBlur => 'Blur';

  @override
  String get misskeySensitiveBlurSubtitle => 'Tap to open (default)';

  @override
  String get misskeySensitiveHide => 'Hide (safe mode)';

  @override
  String get misskeySensitiveHideSubtitle => 'Removes sensitive media from tiles';

  @override
  String get misskeySensitiveMedia => 'Sensitive media';

  @override
  String get misskeySensitiveShow => 'Show without blur';

  @override
  String get misskeySettingsSave => 'Save';

  @override
  String get misskeyTimelinePosts => 'Posts to show';

  @override
  String get misskeyTimelineTitle => 'Timeline';

  @override
  String get misskeyTokens => 'Manage access tokens';

  @override
  String get misskeyTokensSubtitle => 'Review and revoke issued tokens';

  @override
  String get misskeyTwoFactor => 'Two-factor authentication and login history';

  @override
  String get misskeyUploadTimeout => 'The upload timed out';

  @override
  String get misskeyVisibilityFollowers => 'Followers only';

  @override
  String get misskeyVisibilityPrivate => 'Private';

  @override
  String get misskeyVisibilityPublic => 'Public';

  @override
  String get misskeyWebSettings => 'Settings on the web';

  @override
  String get misskeyWithRenotes => 'Show renotes';

  @override
  String get misskeyWithRenotesSubtitle => 'When off, renotes without a quote are not fetched';

  @override
  String get misskeyWithReplies => 'Show replies to others';

  @override
  String get misskeyWithRepliesSubtitle => 'Include replies that people you follow send to others in your timeline';
}

/// `ko` の文言(訳の無いキーは ja の文言)。
class SnsMisskeyLocalizationsKo extends SnsMisskeyLocalizationsJa {
  const SnsMisskeyLocalizationsKo([super.localeName = 'ko']);

  @override
  String get misskeyAccountKind => '계정 유형';

  @override
  String get misskeyAccountNote => '이 설정은 연결된 Misskey 서버에 저장됩니다.';

  @override
  String get misskeyAccountTitle => '계정';

  @override
  String get misskeyActionFavorite => '즐겨찾기';

  @override
  String get misskeyActionReaction => '리액션';

  @override
  String get misskeyActionRenote => '리노트';

  @override
  String get misskeyActionReply => '답글';

  @override
  String get misskeyApiSandboxHint => ' (앱의 네트워크 권한/샌드박스 설정을 확인해 주세요)';

  @override
  String misskeyApiTimeout(String host, int seconds) => '${intl.Intl.pluralLogic(seconds, locale: localeName, other: '${host}에서 응답이 없습니다(${seconds}초). 인터넷 연결을 확인해 주세요')}';

  @override
  String misskeyApiUnreachable(String host, String error, String hint) => '${host}에 연결할 수 없습니다: ${error}${hint}';

  @override
  String misskeyApiUnreachablePlain(String host, String error) => '${host}에 연결할 수 없습니다: ${error}';

  @override
  String get misskeyAuthHint => '브라우저에서 "허용"을 누른 뒤 이 앱으로 돌아와 "인증 확인"을 눌러 주세요.';

  @override
  String get misskeyAuthNotYet => '아직 허용되지 않았습니다. 브라우저에서 허용한 뒤 다시 시도해 주세요.';

  @override
  String get misskeyAutoAcceptFollowed => '내가 팔로우 중인 사람의 팔로우는 자동 승인';

  @override
  String get misskeyBirthday => '생일(예: 2000-01-31)';

  @override
  String get misskeyCw => '내용 경고(CW)';

  @override
  String get misskeyDescription => '자기소개';

  @override
  String get misskeyFollowersVisibility => '팔로워 목록을 볼 수 있는 사람';

  @override
  String get misskeyFollowingVisibility => '팔로잉 목록을 볼 수 있는 사람';

  @override
  String get misskeyHideOnlineStatus => '온라인 상태 숨기기';

  @override
  String get misskeyInvalidBirthday => '생일은 2000-01-31 형식으로 입력해 주세요';

  @override
  String get misskeyInvalidBool => '값은 true / false 입니다';

  @override
  String get misskeyInvalidVisibility => '공개 범위는 public / followers / private 입니다';

  @override
  String get misskeyIsBot => 'Bot으로 설정';

  @override
  String get misskeyIsCat => 'Cat으로 설정';

  @override
  String get misskeyIsCatSubtitle => '말투가 고양이 말투가 되고 고양이 귀가 생깁니다';

  @override
  String get misskeyIsExplorable => '계정을 쉽게 찾을 수 있게 하기';

  @override
  String get misskeyIsExplorableSubtitle => '"탐색"과 사용자 검색에 표시됩니다';

  @override
  String get misskeyIsLocked => '팔로우를 승인제로 하기';

  @override
  String get misskeyIsLockedSubtitle => '다른 사람이 나를 팔로우하려면 내 승인이 필요합니다';

  @override
  String get misskeyLocation => '위치';

  @override
  String get misskeyName => '이름';

  @override
  String get misskeyNoCrawle => '검색 엔진에 노출하지 않기';

  @override
  String get misskeyNoCrawleSubtitle => '검색 엔진이 색인하지 않도록 요청합니다';

  @override
  String get misskeyNoticeAchievement => '업적을 달성했습니다';

  @override
  String get misskeyNoticeApp => '앱에서 보낸 알림';

  @override
  String get misskeyNoticeExportCompleted => '내보내기가 완료되었습니다';

  @override
  String get misskeyNoticeLogin => '새 로그인이 있었습니다';

  @override
  String get misskeyNoticeRoleAssigned => '역할이 부여되었습니다';

  @override
  String get misskeyNoticeTest => '테스트 알림';

  @override
  String misskeyNoticeUnknown(String type) => '알림 (${type})';

  @override
  String get misskeyOpenCw => 'CW가 달린 게시물 자동으로 펼치기';

  @override
  String get misskeyPermissions => '이 앱에 허용된 권한 (MiAuth)';

  @override
  String get misskeyProfile => '프로필';

  @override
  String get misskeyProfileWeb => '아이콘·배너·추가 정보';

  @override
  String get misskeyProfileWebSubtitle => '웹 버전에서 편집합니다';

  @override
  String get misskeyPublicReactions => '리액션 목록 공개';

  @override
  String get misskeyPublicity => '공개 범위';

  @override
  String get misskeySafetyTitle => '개인정보 보호 및 세이프 모드';

  @override
  String get misskeyScopeReadAccount => '계정 정보 읽기';

  @override
  String get misskeyScopeReadBlocks => '차단 읽기';

  @override
  String get misskeyScopeReadChat => '채팅 읽기';

  @override
  String get misskeyScopeReadDrive => '드라이브 읽기';

  @override
  String get misskeyScopeReadFavorites => '즐겨찾기 읽기';

  @override
  String get misskeyScopeReadFollowing => '팔로우 읽기';

  @override
  String get misskeyScopeReadMessaging => '다이렉트 게시물 읽기';

  @override
  String get misskeyScopeReadMutes => '뮤트 읽기';

  @override
  String get misskeyScopeReadNotifications => '알림 읽기';

  @override
  String get misskeyScopeReadReactions => '리액션 읽기';

  @override
  String get misskeyScopeWriteBlocks => '차단·차단 해제';

  @override
  String get misskeyScopeWriteChat => '채팅 보내기';

  @override
  String get misskeyScopeWriteDrive => '드라이브에 업로드';

  @override
  String get misskeyScopeWriteFavorites => '즐겨찾기 추가·삭제';

  @override
  String get misskeyScopeWriteFollowing => '팔로우·언팔로우';

  @override
  String get misskeyScopeWriteMessaging => '다이렉트 게시물 보내기';

  @override
  String get misskeyScopeWriteMutes => '뮤트·뮤트 해제';

  @override
  String get misskeyScopeWriteNotes => '노트 작성·삭제';

  @override
  String get misskeyScopeWriteNotifications => '알림 읽음 처리';

  @override
  String get misskeyScopeWriteReactions => '리액션 추가·삭제';

  @override
  String get misskeySecurityNote => '비밀번호가 필요한 작업은 웹 버전에서 합니다. 액세스 토큰은 기기 내 안전한 영역에만 저장됩니다.';

  @override
  String get misskeySecurityTitle => '보안';

  @override
  String get misskeySensitiveBlur => '흐리게 표시';

  @override
  String get misskeySensitiveBlurSubtitle => '탭하면 열립니다(기본)';

  @override
  String get misskeySensitiveHide => '표시하지 않음(세이프 모드)';

  @override
  String get misskeySensitiveHideSubtitle => '민감한 미디어를 타일에서 제거합니다';

  @override
  String get misskeySensitiveMedia => '민감한 미디어';

  @override
  String get misskeySensitiveShow => '흐리지 않고 표시';

  @override
  String get misskeySettingsSave => '저장';

  @override
  String get misskeyTimelinePosts => '표시할 게시물';

  @override
  String get misskeyTimelineTitle => '타임라인';

  @override
  String get misskeyTokens => '액세스 토큰 관리';

  @override
  String get misskeyTokensSubtitle => '발급된 토큰 확인 및 폐기';

  @override
  String get misskeyTwoFactor => '2단계 인증·로그인 기록';

  @override
  String get misskeyUploadTimeout => '업로드 시간이 초과되었습니다';

  @override
  String get misskeyVisibilityFollowers => '팔로워만';

  @override
  String get misskeyVisibilityPrivate => '비공개';

  @override
  String get misskeyVisibilityPublic => '공개';

  @override
  String get misskeyWebSettings => '웹에서 하는 설정';

  @override
  String get misskeyWithRenotes => '리노트 표시';

  @override
  String get misskeyWithRenotesSubtitle => '끄면 인용 없는 리노트를 가져오지 않습니다';

  @override
  String get misskeyWithReplies => '다른 사람에게 보낸 답글 표시';

  @override
  String get misskeyWithRepliesSubtitle => '팔로우 중인 사람이 다른 사람에게 보낸 답글을 타임라인에 포함합니다';
}

/// `zh` の文言(訳の無いキーは ja の文言)。
class SnsMisskeyLocalizationsZh extends SnsMisskeyLocalizationsJa {
  const SnsMisskeyLocalizationsZh([super.localeName = 'zh']);

  @override
  String get misskeyAccountKind => '账号类型';

  @override
  String get misskeyAccountNote => '这些设置会保存在所连接的 Misskey 服务器上。';

  @override
  String get misskeyAccountTitle => '账号';

  @override
  String get misskeyActionFavorite => '收藏';

  @override
  String get misskeyActionReaction => '回应';

  @override
  String get misskeyActionRenote => '转帖';

  @override
  String get misskeyActionReply => '回复';

  @override
  String get misskeyApiSandboxHint => '（请检查应用的网络权限/沙盒设置）';

  @override
  String misskeyApiTimeout(String host, int seconds) => '${intl.Intl.pluralLogic(seconds, locale: localeName, other: '${host} 无响应（${seconds} 秒）。请检查网络连接')}';

  @override
  String misskeyApiUnreachable(String host, String error, String hint) => '无法连接到 ${host}:${error}${hint}';

  @override
  String misskeyApiUnreachablePlain(String host, String error) => '无法连接到 ${host}:${error}';

  @override
  String get misskeyAuthHint => '在浏览器中点击“允许”后，请返回本应用并点击“确认认证”。';

  @override
  String get misskeyAuthNotYet => '尚未获得授权。请在浏览器中允许后再试一次。';

  @override
  String get misskeyAutoAcceptFollowed => '自动批准你关注的人的关注';

  @override
  String get misskeyBirthday => '生日（例：2000-01-31）';

  @override
  String get misskeyCw => '内容警告（CW）';

  @override
  String get misskeyDescription => '自我介绍';

  @override
  String get misskeyFollowersVisibility => '谁可以查看你的关注者列表';

  @override
  String get misskeyFollowingVisibility => '谁可以查看你的关注列表';

  @override
  String get misskeyHideOnlineStatus => '隐藏在线状态';

  @override
  String get misskeyInvalidBirthday => '请按 2000-01-31 的格式输入生日';

  @override
  String get misskeyInvalidBool => '值应为 true / false';

  @override
  String get misskeyInvalidVisibility => '公开范围应为 public / followers / private';

  @override
  String get misskeyIsBot => '设为 Bot';

  @override
  String get misskeyIsCat => '变成 Cat';

  @override
  String get misskeyIsCatSubtitle => '发言会变成猫语，并长出猫耳朵';

  @override
  String get misskeyIsExplorable => '让账号更容易被发现';

  @override
  String get misskeyIsExplorableSubtitle => '会显示在“发现”和用户搜索中';

  @override
  String get misskeyIsLocked => '关注需要批准';

  @override
  String get misskeyIsLockedSubtitle => '他人关注你之前需要你的批准';

  @override
  String get misskeyLocation => '所在地';

  @override
  String get misskeyName => '名称';

  @override
  String get misskeyNoCrawle => '不被搜索引擎收录';

  @override
  String get misskeyNoCrawleSubtitle => '要求搜索引擎不要建立索引';

  @override
  String get misskeyNoticeAchievement => '获得了成就';

  @override
  String get misskeyNoticeApp => '来自应用的通知';

  @override
  String get misskeyNoticeExportCompleted => '导出已完成';

  @override
  String get misskeyNoticeLogin => '有新的登录';

  @override
  String get misskeyNoticeRoleAssigned => '已被授予角色';

  @override
  String get misskeyNoticeTest => '测试通知';

  @override
  String misskeyNoticeUnknown(String type) => '通知 (${type})';

  @override
  String get misskeyOpenCw => '自动展开带内容警告的帖子';

  @override
  String get misskeyPermissions => '已授予本应用的权限 (MiAuth)';

  @override
  String get misskeyProfile => '个人资料';

  @override
  String get misskeyProfileWeb => '头像、横幅和补充信息';

  @override
  String get misskeyProfileWebSubtitle => '在网页版中编辑';

  @override
  String get misskeyPublicReactions => '公开回应列表';

  @override
  String get misskeyPublicity => '公开范围';

  @override
  String get misskeySafetyTitle => '隐私与安全模式';

  @override
  String get misskeyScopeReadAccount => '读取账号信息';

  @override
  String get misskeyScopeReadBlocks => '读取屏蔽';

  @override
  String get misskeyScopeReadChat => '读取聊天';

  @override
  String get misskeyScopeReadDrive => '读取网盘';

  @override
  String get misskeyScopeReadFavorites => '读取收藏';

  @override
  String get misskeyScopeReadFollowing => '读取关注';

  @override
  String get misskeyScopeReadMessaging => '读取私信帖子';

  @override
  String get misskeyScopeReadMutes => '读取静音';

  @override
  String get misskeyScopeReadNotifications => '读取通知';

  @override
  String get misskeyScopeReadReactions => '读取回应';

  @override
  String get misskeyScopeWriteBlocks => '屏蔽和取消屏蔽';

  @override
  String get misskeyScopeWriteChat => '发送聊天';

  @override
  String get misskeyScopeWriteDrive => '上传到网盘';

  @override
  String get misskeyScopeWriteFavorites => '添加和删除收藏';

  @override
  String get misskeyScopeWriteFollowing => '关注和取消关注';

  @override
  String get misskeyScopeWriteMessaging => '发送私信帖子';

  @override
  String get misskeyScopeWriteMutes => '静音和取消静音';

  @override
  String get misskeyScopeWriteNotes => '发布和删除帖子';

  @override
  String get misskeyScopeWriteNotifications => '将通知标为已读';

  @override
  String get misskeyScopeWriteReactions => '添加和删除回应';

  @override
  String get misskeySecurityNote => '需要密码的操作请在网页版中进行。访问令牌仅保存在设备内的安全区域。';

  @override
  String get misskeySecurityTitle => '安全';

  @override
  String get misskeySensitiveBlur => '模糊显示';

  @override
  String get misskeySensitiveBlurSubtitle => '点按即可打开（默认）';

  @override
  String get misskeySensitiveHide => '不显示（安全模式）';

  @override
  String get misskeySensitiveHideSubtitle => '从卡片中移除敏感媒体';

  @override
  String get misskeySensitiveMedia => '敏感媒体';

  @override
  String get misskeySensitiveShow => '不模糊直接显示';

  @override
  String get misskeySettingsSave => '保存';

  @override
  String get misskeyTimelinePosts => '显示的帖子';

  @override
  String get misskeyTimelineTitle => '时间线';

  @override
  String get misskeyTokens => '管理访问令牌';

  @override
  String get misskeyTokensSubtitle => '查看和撤销已签发的令牌';

  @override
  String get misskeyTwoFactor => '双重验证与登录记录';

  @override
  String get misskeyUploadTimeout => '上传超时';

  @override
  String get misskeyVisibilityFollowers => '仅关注者';

  @override
  String get misskeyVisibilityPrivate => '不公开';

  @override
  String get misskeyVisibilityPublic => '公开';

  @override
  String get misskeyWebSettings => '在网页版中进行的设置';

  @override
  String get misskeyWithRenotes => '显示转帖';

  @override
  String get misskeyWithRenotesSubtitle => '关闭后将不获取不带引用的转帖';

  @override
  String get misskeyWithReplies => '显示对他人的回复';

  @override
  String get misskeyWithRepliesSubtitle => '在时间线中包含你关注的人发给他人的回复';
}

/// `zh_Hant` の文言(訳の無いキーは ja の文言)。
class SnsMisskeyLocalizationsZhHant extends SnsMisskeyLocalizationsJa {
  const SnsMisskeyLocalizationsZhHant([super.localeName = 'zh_Hant']);

  @override
  String get misskeyAccountKind => '帳號類型';

  @override
  String get misskeyAccountNote => '這些設定會儲存在所連線的 Misskey 伺服器上。';

  @override
  String get misskeyAccountTitle => '帳號';

  @override
  String get misskeyActionFavorite => '最愛';

  @override
  String get misskeyActionReaction => '回應';

  @override
  String get misskeyActionRenote => '轉貼';

  @override
  String get misskeyActionReply => '回覆';

  @override
  String get misskeyApiSandboxHint => '（請檢查 App 的網路權限/沙箱設定）';

  @override
  String misskeyApiTimeout(String host, int seconds) => '${intl.Intl.pluralLogic(seconds, locale: localeName, other: '${host} 沒有回應（${seconds} 秒）。請檢查網路連線')}';

  @override
  String misskeyApiUnreachable(String host, String error, String hint) => '無法連線到 ${host}:${error}${hint}';

  @override
  String misskeyApiUnreachablePlain(String host, String error) => '無法連線到 ${host}:${error}';

  @override
  String get misskeyAuthHint => '在瀏覽器中點選「允許」後，請返回本 App 並點選「確認驗證」。';

  @override
  String get misskeyAuthNotYet => '尚未獲得授權。請在瀏覽器中允許後再試一次。';

  @override
  String get misskeyAutoAcceptFollowed => '自動核准你所追蹤的人的追蹤';

  @override
  String get misskeyBirthday => '生日（例：2000-01-31）';

  @override
  String get misskeyCw => '內容警告（CW）';

  @override
  String get misskeyDescription => '自我介紹';

  @override
  String get misskeyFollowersVisibility => '誰可以查看你的追蹤者列表';

  @override
  String get misskeyFollowingVisibility => '誰可以查看你的追蹤中列表';

  @override
  String get misskeyHideOnlineStatus => '隱藏上線狀態';

  @override
  String get misskeyInvalidBirthday => '請以 2000-01-31 的格式輸入生日';

  @override
  String get misskeyInvalidBool => '值應為 true / false';

  @override
  String get misskeyInvalidVisibility => '公開範圍應為 public / followers / private';

  @override
  String get misskeyIsBot => '設為 Bot';

  @override
  String get misskeyIsCat => '變成 Cat';

  @override
  String get misskeyIsCatSubtitle => '發言會變成貓語，並長出貓耳朵';

  @override
  String get misskeyIsExplorable => '讓帳號更容易被找到';

  @override
  String get misskeyIsExplorableSubtitle => '會顯示在「探索」和使用者搜尋中';

  @override
  String get misskeyIsLocked => '追蹤需經核准';

  @override
  String get misskeyIsLockedSubtitle => '他人追蹤你之前需要你的核准';

  @override
  String get misskeyLocation => '所在地';

  @override
  String get misskeyName => '名稱';

  @override
  String get misskeyNoCrawle => '不被搜尋引擎收錄';

  @override
  String get misskeyNoCrawleSubtitle => '要求搜尋引擎不要建立索引';

  @override
  String get misskeyNoticeAchievement => '獲得了成就';

  @override
  String get misskeyNoticeApp => '來自 App 的通知';

  @override
  String get misskeyNoticeExportCompleted => '匯出已完成';

  @override
  String get misskeyNoticeLogin => '有新的登入';

  @override
  String get misskeyNoticeRoleAssigned => '已獲指派角色';

  @override
  String get misskeyNoticeTest => '測試通知';

  @override
  String misskeyNoticeUnknown(String type) => '通知 (${type})';

  @override
  String get misskeyOpenCw => '自動展開含內容警告的貼文';

  @override
  String get misskeyPermissions => '已授予本 App 的權限 (MiAuth)';

  @override
  String get misskeyProfile => '個人檔案';

  @override
  String get misskeyProfileWeb => '頭像、橫幅與補充資訊';

  @override
  String get misskeyProfileWebSubtitle => '在網頁版中編輯';

  @override
  String get misskeyPublicReactions => '公開回應列表';

  @override
  String get misskeyPublicity => '公開範圍';

  @override
  String get misskeySafetyTitle => '隱私與安全模式';

  @override
  String get misskeyScopeReadAccount => '讀取帳號資訊';

  @override
  String get misskeyScopeReadBlocks => '讀取封鎖';

  @override
  String get misskeyScopeReadChat => '讀取聊天';

  @override
  String get misskeyScopeReadDrive => '讀取雲端硬碟';

  @override
  String get misskeyScopeReadFavorites => '讀取最愛';

  @override
  String get misskeyScopeReadFollowing => '讀取追蹤';

  @override
  String get misskeyScopeReadMessaging => '讀取私訊貼文';

  @override
  String get misskeyScopeReadMutes => '讀取靜音';

  @override
  String get misskeyScopeReadNotifications => '讀取通知';

  @override
  String get misskeyScopeReadReactions => '讀取回應';

  @override
  String get misskeyScopeWriteBlocks => '封鎖與解除封鎖';

  @override
  String get misskeyScopeWriteChat => '傳送聊天';

  @override
  String get misskeyScopeWriteDrive => '上傳到雲端硬碟';

  @override
  String get misskeyScopeWriteFavorites => '新增與移除最愛';

  @override
  String get misskeyScopeWriteFollowing => '追蹤與取消追蹤';

  @override
  String get misskeyScopeWriteMessaging => '傳送私訊貼文';

  @override
  String get misskeyScopeWriteMutes => '靜音與解除靜音';

  @override
  String get misskeyScopeWriteNotes => '發布與刪除貼文';

  @override
  String get misskeyScopeWriteNotifications => '將通知標為已讀';

  @override
  String get misskeyScopeWriteReactions => '新增與移除回應';

  @override
  String get misskeySecurityNote => '需要密碼的操作請在網頁版中進行。存取權杖僅儲存在裝置內的安全區域。';

  @override
  String get misskeySecurityTitle => '安全性';

  @override
  String get misskeySensitiveBlur => '模糊顯示';

  @override
  String get misskeySensitiveBlurSubtitle => '點按即可開啟（預設）';

  @override
  String get misskeySensitiveHide => '不顯示（安全模式）';

  @override
  String get misskeySensitiveHideSubtitle => '從卡片中移除敏感媒體';

  @override
  String get misskeySensitiveMedia => '敏感媒體';

  @override
  String get misskeySensitiveShow => '不模糊直接顯示';

  @override
  String get misskeySettingsSave => '儲存';

  @override
  String get misskeyTimelinePosts => '顯示的貼文';

  @override
  String get misskeyTimelineTitle => '時間軸';

  @override
  String get misskeyTokens => '管理存取權杖';

  @override
  String get misskeyTokensSubtitle => '查看與撤銷已核發的權杖';

  @override
  String get misskeyTwoFactor => '雙重驗證與登入紀錄';

  @override
  String get misskeyUploadTimeout => '上傳逾時';

  @override
  String get misskeyVisibilityFollowers => '僅追蹤者';

  @override
  String get misskeyVisibilityPrivate => '不公開';

  @override
  String get misskeyVisibilityPublic => '公開';

  @override
  String get misskeyWebSettings => '在網頁版中進行的設定';

  @override
  String get misskeyWithRenotes => '顯示轉貼';

  @override
  String get misskeyWithRenotesSubtitle => '關閉後將不取得不含引用的轉貼';

  @override
  String get misskeyWithReplies => '顯示對他人的回覆';

  @override
  String get misskeyWithRepliesSubtitle => '在時間軸中包含你追蹤的人發給他人的回覆';
}

/// [tag](BCP-47。`ja` / `en-US` / `zh_Hant`)の文言。そのタグ → 言語だけ → `ja` の順に倒す。
SnsMisskeyLocalizations lookupSnsMisskeyLocalizations(String tag) {
  final t = tag.replaceAll('_', '-').toLowerCase();
  for (final c in [t, t.split('-').first]) {
    switch (c) {
      case 'ja':
        return const SnsMisskeyLocalizationsJa();
      case 'en':
        return const SnsMisskeyLocalizationsEn();
      case 'ko':
        return const SnsMisskeyLocalizationsKo();
      case 'zh':
        return const SnsMisskeyLocalizationsZh();
      case 'zh-hant':
        return const SnsMisskeyLocalizationsZhHant();
    }
  }
  return const SnsMisskeyLocalizationsJa();
}
