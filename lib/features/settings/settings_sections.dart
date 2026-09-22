import '../../app/router.dart';

/// 設定第一階層 (テキストベース仕様 — UI_status「設定第2階層以降はテキストベースで仕様を決める方針」).
/// Wireframe P7: 各セクションの項目名。この画面群は M4 で FOW/DSL 描画に置き換わる。
class SettingsRow {
  const SettingsRow(this.title, {this.subtitle, this.warning = false, this.external = false, this.route});
  final String title;
  final String? subtitle;
  final bool warning;
  final bool external;

  /// Internal route to push when tapped (null = placeholder).
  final String? route;
}

class SettingsSection {
  const SettingsSection(this.title, this.rows, {this.note});
  final String title;
  final List<SettingsRow> rows;
  final String? note;
}

const settingsSections = <String, SettingsSection>{
  'plugins': SettingsSection('プラグインの構成', [
    SettingsRow('RASQプラグインプロキシの購読', subtitle: '未購読(第二期)', route: '/settings/dsl/plugins.proxy'),
    SettingsRow('投稿にプラグインオートメーションを配置', subtitle: '投稿のアクションバーに出すプラグインボタン', route: Routes.actionBarPlugins),
    SettingsRow('カスタムトレンドの配信', route: '/settings/dsl/plugins.trend'),
    SettingsRow('投稿プラグイン', route: '/settings/dsl/plugins.composer'),
    SettingsRow('カスタムタイムラインを配置', route: '/settings/dsl/plugins.timeline'),
    SettingsRow('プラグインの詳細設定', subtitle: 'プラグインストア(インストール済みの管理)', route: Routes.store),
    SettingsRow('通信の形の報告', subtitle: 'プラグインの通信の形(値は含まない)を、初めて見たときだけストアへ。既定はオフ', route: '/settings/dsl/plugins.telemetry'),
  ]),
  'sns': SettingsSection('SNSプラグイン', [
    // 第二階層 = プラグイン提供の設定 DSL ページ (D-044, `sns.<短area>`)。
    SettingsRow('アカウント', route: '/settings/dsl/sns.account'),
    SettingsRow('タイムライン', route: '/settings/dsl/sns.timeline'),
    SettingsRow('セキュリティ', route: '/settings/dsl/sns.security'),
    SettingsRow('プライバシーとセーフモード', route: '/settings/dsl/sns.safety'),
    SettingsRow('リスト', route: '/lists'),
    SettingsRow('ミュート/ブロック', route: '/settings/mute-block'),
    SettingsRow('プラグインボタン', subtitle: '宣言されたボタンの有効 / 無効と束ねる閾値', route: Routes.actionBarPlugins),
    SettingsRow('絵文字の検索', subtitle: '意味の近い絵文字も探す(端末内のモデル)', route: '/settings/dsl/plugins.emoji'),
    SettingsRow('リアクションの予測', subtitle: 'だれも付けていない投稿でも予測するか', route: '/settings/dsl/plugins.reaction'),
    SettingsRow('共有 / リノートに使うアカウント', subtitle: '複数のアカウントに見えている投稿を、どのアカウントで扱うか', route: '/settings/dsl/plugins.accountPick'),
    SettingsRow('カスタムモーションとアニメーション', route: '/settings/dsl/appearance.mfm'),
    SettingsRow('リソースと広告', route: '/settings/dsl/resources'),
    SettingsRow('ヘルプ、法的表示', route: Routes.settingsLegal),
  ], note: 'アカウント / タイムライン / セキュリティ / プライバシーは、選んでいる SNS のプラグインが提供する設定ページです(プラグインが持たないページは開けません)。'),
  'appearance': SettingsSection('アプリの外観', [
    SettingsRow('インターフェースの表示サイズ', route: '/settings/dsl/appearance.display'),
    SettingsRow('フォントやカラースキーム'),
    SettingsRow('モーションの抑制', route: '/settings/dsl/appearance.motion'),
    SettingsRow('ピクチャインピクチャ', route: '/settings/dsl/appearance.video'),
    SettingsRow('通知の表示形式', route: '/settings/dsl/appearance.notifications'),
  ]),
  'astell': SettingsSection('ASTell', [
    SettingsRow('ASTell 4Uを購読', subtitle: '未購読(第二期)', route: '/settings/dsl/astell.subscription'),
    SettingsRow('Tellタイル', route: '/settings/dsl/astell.tiles'),
    SettingsRow('トレンドタイムラインへの配信', route: '/settings/dsl/astell.trend'),
    SettingsRow('プラグインの詳細設定', subtitle: 'AsTell のアクションプラグイン(ストア)', route: Routes.store),
    SettingsRow('画面オフ時の動作', route: '/settings/dsl/astell.background'),
  ]),
  'relational': SettingsSection('リレーショナルタイムライン', [
    SettingsRow('投稿クラスター', subtitle: '会話イベントの束ね方(束ねやすさ / 重み / 沈むまでの時間)', route: settingsActionRelationalTuning),
    SettingsRow('Relayタイル', route: '/settings/dsl/relational.relay'),
    SettingsRow('トレンドタイムラインへの配信', route: '/settings/dsl/relational.trend'),
    SettingsRow('プラグインの詳細設定', route: '/settings/dsl/relational.plugins'),
    SettingsRow('トレンドのサンプリングレベル', subtitle: '候補に入れる時間の幅(束ね判定の詳細設定)', route: settingsActionRelationalTuning),
  ], note: 'Relay タイルとトレンドへの配信はアルゴリズム確定後(D-011)。'),
  'trend': SettingsSection('トレンド', [
    SettingsRow('ジャンル', route: settingsActionTrendGenres),
    SettingsRow('トレンドの指向性/刺激性', warning: true, route: settingsActionTrendTendency),
    SettingsRow('プラグインの詳細設定', route: '/settings/dsl/plugins.trend'),
    SettingsRow('キャッシュネットワークの設定', subtitle: '未提供(第二期)', route: '/settings/dsl/trend.cdn'),
  ]),
  'rai': SettingsSection('RAi(アシスタント)', [
    SettingsRow('工程グラフの自動表示', route: '/settings/dsl/rai'),
  ]),
  'notifications': SettingsSection('通知', [
    SettingsRow('プロファイル', route: 'notificationPrefs'),
    SettingsRow('アクセストークン', subtitle: '通知専用のトークンの発行 / 失効、端末のプッシュ登録', route: Routes.settingsNotifyToken),
    SettingsRow('セキュリティ', subtitle: 'SNS の権限とアクセストークン', route: '/settings/dsl/sns.security'),
  ]),
  'about': SettingsSection('RASQについて', [
    SettingsRow('RASQ サーバー', subtitle: 'プラグインストア / RASQ アカウント / ログインの接続先', route: '/settings/server'),
    SettingsRow('ヘルプ', route: '/settings/dsl/about.help'),
    SettingsRow('購読状況', route: '/settings/dsl/about.subscription'),
    SettingsRow('クッキーについて', route: '/settings/dsl/about.cookies'),
    SettingsRow('プライバシーポリシー', route: '/settings/dsl/about.privacy'),
    SettingsRow('利用規約', route: '/settings/dsl/about.terms'),
    SettingsRow('学習へのデータ提供', subtitle: '任意。既定は「提供しない」', route: Routes.settingsLearning),
    SettingsRow('AsTell の利用について', route: '/settings/dsl/about.astell'),
    SettingsRow('リソースと広告', route: '/settings/dsl/resources'),
    SettingsRow('ヘルプ、法的表示', route: Routes.settingsLegal),
  ]),
};

/// 画面ではなく FOW / シートを開く行の印 (D-238)。[SettingsSectionScreen] が解釈する。
const settingsActionTrendGenres = 'action:trend.genres';
const settingsActionTrendTendency = 'action:trend.tendency';
const settingsActionRelationalTuning = 'action:relational.tuning';
