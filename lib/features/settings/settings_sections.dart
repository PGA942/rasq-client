import '../../app/router.dart';

/// 設定第一階層 (テキストベース仕様 — UI_status「設定第2階層以降はテキストベースで仕様を決める方針」).
/// Wireframe P7: 各セクションの項目名。この画面群は M4 で FOW/DSL 描画に置き換わる。
class SettingsRow {
  const SettingsRow(this.title, {this.subtitle, this.detail, this.warning = false, this.external = false, this.route});
  final String title;
  final String? subtitle;

  /// 開発者モードのときだけ subtitle の代わりに出す詳しい説明 (D-362)。
  final String? detail;
  final bool warning;
  final bool external;

  /// Internal route to push when tapped (null = placeholder).
  final String? route;
}

class SettingsSection {
  const SettingsSection(this.title, this.rows, {this.note, this.noteDetail});
  final String title;
  final List<SettingsRow> rows;
  final String? note;

  /// 開発者モードのときだけ [note] の代わりに出す詳しい説明 (D-362)。
  final String? noteDetail;
}

const settingsSections = <String, SettingsSection>{
  'plugins': SettingsSection('プラグインの構成', [
    SettingsRow('RASQプラグインプロキシの購読', subtitle: '準備中', detail: '未購読(第二期)', route: '/settings/dsl/plugins.proxy'),
    SettingsRow('投稿にプラグインオートメーションを配置', subtitle: '投稿の下に出すプラグインのボタン', detail: '投稿のアクションバーに出すプラグインボタン(主電源 / 自動でオン / 配置)', route: Routes.actionBarPlugins),
    SettingsRow('カスタムトレンドの配信', route: '/settings/dsl/plugins.trend'),
    SettingsRow('投稿プラグイン', route: '/settings/dsl/plugins.composer'),
    SettingsRow('カスタムタイムラインを配置', route: '/settings/dsl/plugins.timeline'),
    SettingsRow('プラグインの詳細設定', subtitle: 'プラグインストア(インストール済みの管理)', route: Routes.store),
    SettingsRow('怪しい通信の通報', subtitle: '既定はオフ', detail: '通信の形の報告: プラグインの通信の形(値は含まない)を、初めて見たときだけストアへ。既定はオフ', route: '/settings/dsl/plugins.telemetry'),
  ]),
  'sns': SettingsSection('SNSプラグイン', [
    // 第二階層 = プラグイン提供の設定 DSL ページ (D-044, `sns.<短area>`)。
    SettingsRow('アカウント', route: '/settings/dsl/sns.account'),
    SettingsRow('タイムライン', route: '/settings/dsl/sns.timeline'),
    SettingsRow('セキュリティ', route: '/settings/dsl/sns.security'),
    SettingsRow('プライバシーとセーフモード', route: '/settings/dsl/sns.safety'),
    SettingsRow('チャイルドセーフ', subtitle: '保護者の見守り / チャイルドモード', detail: '保護者として見守る / チャイルドモード(保護者のコードでつなぐ)', route: Routes.childSafe),
    SettingsRow('リスト', route: '/lists'),
    SettingsRow('ミュート/ブロック', route: '/settings/mute-block'),
    SettingsRow('プラグインボタン', subtitle: 'プラグインのボタンの出し方', detail: '面ごとの主電源と「開いたとき自動でオン」、このアカウントの有効 / 無効と束ねる閾値', route: Routes.actionBarPlugins),
    SettingsRow('絵文字の検索', subtitle: '意味の近い絵文字も探す', detail: '意味の近い絵文字も探す(端末内のモデル)', route: '/settings/dsl/plugins.emoji'),
    SettingsRow('リアクションの予測', subtitle: 'だれも付けていない投稿でも予測するか', route: '/settings/dsl/plugins.reaction'),
    SettingsRow('共有 / リノートに使うアカウント', subtitle: '同じ投稿が複数のアカウントに見えるとき', detail: '複数のアカウントに見えている投稿を、どのアカウントで扱うか', route: '/settings/dsl/plugins.accountPick'),
    SettingsRow('カスタムモーションとアニメーション', route: '/settings/dsl/appearance.mfm'),
    SettingsRow('リソースと広告', route: '/settings/dsl/resources'),
    SettingsRow('ヘルプ、法的表示', route: Routes.settingsLegal),
  ],
      note: '上の 4 つは、使っている SNS のプラグインが用意するページです。',
      noteDetail: 'アカウント / タイムライン / セキュリティ / プライバシーは、選んでいる SNS のプラグインが提供する設定ページです(プラグインが持たないページは開けません)。'),
  'appearance': SettingsSection('アプリの外観', [
    SettingsRow('インターフェースの表示サイズ', route: '/settings/dsl/appearance.display'),
    SettingsRow('フォントやカラースキーム', subtitle: '着せ替え(色・アイコン・背景の画像)', route: Routes.settingsTheme),
    SettingsRow('カラムの幅', subtitle: '広い画面での左右のカラムの幅', detail: '幅の広い画面の小型 / 大型カラムの比(1:1 / 2:3 / 3:5 / 幅を固定)', route: Routes.settingsColumns),
    SettingsRow('モーションの抑制', route: '/settings/dsl/appearance.motion'),
    SettingsRow('タイムラインの表示', subtitle: 'タイムラインの「投稿を読み込む」', detail: 'TL の上下の「投稿を読み込む」', route: '/settings/dsl/appearance.timeline'),
    SettingsRow('ピクチャインピクチャ', route: '/settings/dsl/appearance.video'),
    SettingsRow('＋ ボタンの割り当て', subtitle: '押したときに始めるもの', route: '/settings/dsl/appearance.fab'),
    SettingsRow('画像・動画の保存先', subtitle: '写真(カメラロール)/ ファイル / 保存するたびに選ぶ', route: '/settings/dsl/media.save'),
    SettingsRow('通知の表示形式', route: '/settings/dsl/appearance.notifications'),
  ]),
  'astell': SettingsSection('ASTell', [
    SettingsRow('ASTell 4Uを購読', subtitle: '準備中', detail: '未購読(第二期)', route: '/settings/dsl/astell.subscription'),
    SettingsRow('Tellタイル', route: '/settings/dsl/astell.tiles'),
    SettingsRow('トレンドタイムラインへの配信', route: '/settings/dsl/astell.trend'),
    SettingsRow('ルームのボタン', subtitle: '入力欄の左に並ぶボタン', detail: 'ルームの下段、入力欄の左の丸いボタンの並び(並べ替え / 表示 / 非表示 / プラグインのボタンを追加)', route: settingsActionAstellBar),
    SettingsRow('プラグインの詳細設定', subtitle: 'ASTell で使うプラグイン', detail: 'ASTell のアクションプラグイン(ストア)', route: Routes.store),
    SettingsRow('画面オフ時の動作', route: '/settings/dsl/astell.background'),
  ]),
  'relational': SettingsSection('リレーショナルタイムライン', [
    SettingsRow('投稿クラスター', subtitle: '会話のまとめ方', detail: '会話イベントの束ね方(束ねやすさ / 重み / 沈むまでの時間)', route: settingsActionRelationalTuning),
    SettingsRow('Relayタイル', route: '/settings/dsl/relational.relay'),
    SettingsRow('トレンドタイムラインへの配信', route: '/settings/dsl/relational.trend'),
    SettingsRow('プラグインの詳細設定', route: '/settings/dsl/relational.plugins'),
    SettingsRow('トレンドのサンプリングレベル', subtitle: '候補に入れる時間の幅', detail: '候補に入れる時間の幅(束ね判定の詳細設定)', route: settingsActionRelationalTuning),
  ], note: 'Relay タイルとトレンドへの配信は準備中です。', noteDetail: 'Relay タイルとトレンドへの配信はアルゴリズム確定後(D-011)。'),
  'trend': SettingsSection('トレンド', [
    SettingsRow('ジャンル', route: settingsActionTrendGenres),
    SettingsRow('トレンドの指向性/刺激性', warning: true, route: settingsActionTrendTendency),
    SettingsRow('EmoM の閾値', subtitle: '運営が制限したトレンドの隠し方 / 閾値の公開', detail: 'EmoM の閾値(0〜100、既定 50)と「閾値を公開する」(既定オフ)。運営の制限の点数がこの値より大きいトレンドを一覧に出さない (D-404)', route: Routes.settingsEmom),
    SettingsRow('プラグインの詳細設定', route: '/settings/dsl/plugins.trend'),
    SettingsRow('キャッシュネットワークの設定', subtitle: '準備中', detail: '未提供(第二期)', route: '/settings/dsl/trend.cdn'),
  ]),
  'rai': SettingsSection('RAi(アシスタント)', [
    SettingsRow('工程グラフの自動表示', route: '/settings/dsl/rai'),
  ]),
  'notifications': SettingsSection('通知', [
    SettingsRow('プロファイル', route: 'notificationPrefs'),
    SettingsRow('アクセストークン', subtitle: '通知を受け取るための設定', detail: '通知専用のトークンの発行 / 失効、端末のプッシュ登録', route: Routes.settingsNotifyToken),
    SettingsRow('セキュリティ', subtitle: 'SNS の権限とアクセストークン', route: '/settings/dsl/sns.security'),
  ]),
  'about': SettingsSection('RASQについて', [
    SettingsRow('RASQ サーバー', subtitle: 'つなぐ先のサーバー', detail: 'プラグインストア / RASQ アカウント / ログインの接続先', route: '/settings/server'),
    SettingsRow('ヘルプ', route: '/settings/dsl/about.help'),
    // RASQ の機能の紹介 (D-471) をもう一度。RAi の `help.tour` もここ(とヘルプのページ)を指す。
    SettingsRow('RASQ の使い方をもう一度見る', subtitle: '機能の紹介(TL・トレンド・ASTell・RAi など)', route: '${Routes.featureTour}?again=1'),
    SettingsRow('購読状況', route: '/settings/dsl/about.subscription'),
    SettingsRow('クッキーについて', route: '/settings/dsl/about.cookies'),
    SettingsRow('プライバシーポリシー', route: '/settings/dsl/about.privacy'),
    SettingsRow('利用規約', route: '/settings/dsl/about.terms'),
    SettingsRow('アルゴリズムとコミュニティへの貢献', subtitle: '任意。既定は「提供しない」', route: Routes.settingsLearning),
    SettingsRow('ASTell の利用条件', route: '/settings/dsl/about.astell'),
    SettingsRow('RAi の利用条件', route: '/settings/dsl/about.rai'),
    SettingsRow('プラグインストアの利用条件', route: '/settings/dsl/about.store'),
    SettingsRow('プラグイン開発者の掲載・審査条件', subtitle: '審査料を含む', route: '/settings/dsl/about.devterms'),
    SettingsRow('料金・ポイントの条件', route: '/settings/dsl/about.billing'),
    SettingsRow('特定商取引法に基づく表記', route: '/settings/dsl/about.commerce'),
    SettingsRow('リソースと広告', route: '/settings/dsl/resources'),
    SettingsRow('ヘルプ、法的表示', route: Routes.settingsLegal),
    SettingsRow('開発者モード', subtitle: '画面の説明を詳しく表示する', route: '/settings/dsl/about.developer'),
  ]),
};

/// 画面ではなく FOW / シートを開く行の印 (D-238)。[SettingsSectionScreen] が解釈する。
const settingsActionTrendGenres = 'action:trend.genres';
const settingsActionTrendTendency = 'action:trend.tendency';
const settingsActionRelationalTuning = 'action:relational.tuning';

/// AsTell のルームの下段のボタンの編集 (D-324、アクションバーの編集 FOW の AsTell の面)。
const settingsActionAstellBar = 'action:astell.bar';
