// tool/l10n_merge.dart が lib/l10n/parts/*.arb から作る(手で直さない)。Flutter に依らない部品の文言 (D-533、docs/I18N.md)。
// ignore_for_file: type=lint

import 'package:intl/intl.dart' as intl;

/// 文言(言語ごとの実装は [lookupSnsMisskeyLocalizations])。
abstract class SnsMisskeyLocalizations {
  const SnsMisskeyLocalizations(this.localeName);

  /// この文言の言語(`ja` など)。
  final String localeName;

  /// 訳のある言語。
  static const supportedLocales = <String>['ja'];

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

/// [tag](BCP-47。`ja` / `en-US` / `zh_Hant`)の文言。そのタグ → 言語だけ → `ja` の順に倒す。
SnsMisskeyLocalizations lookupSnsMisskeyLocalizations(String tag) {
  final t = tag.replaceAll('_', '-').toLowerCase();
  for (final c in [t, t.split('-').first]) {
    switch (c) {
      case 'ja':
        return const SnsMisskeyLocalizationsJa();
    }
  }
  return const SnsMisskeyLocalizationsJa();
}
