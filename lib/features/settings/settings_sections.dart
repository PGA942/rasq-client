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
    SettingsRow('RASQプラグインプロキシの購読'),
    SettingsRow('投稿にプラグインオートメーションを配置'),
    SettingsRow('カスタムトレンドの配信'),
    SettingsRow('投稿プラグイン'),
    SettingsRow('カスタムタイムラインを配置'),
    SettingsRow('プラグインの詳細設定'),
  ]),
  'sns': SettingsSection('SNSプラグイン', [
    // 第二階層 = プラグイン提供の設定 DSL ページ (D-044, `sns.<短area>`)。
    SettingsRow('アカウント', route: '/settings/dsl/sns.account'),
    SettingsRow('タイムライン', route: '/settings/dsl/sns.timeline'),
    SettingsRow('セキュリティ', route: '/settings/dsl/sns.security'),
    SettingsRow('プライバシーとセーフモード', route: '/settings/dsl/sns.safety'),
    SettingsRow('リスト', route: '/lists'),
    SettingsRow('ミュート/ブロック', route: '/settings/mute-block'),
    SettingsRow('カスタムモーションとアニメーション'),
    SettingsRow('リソースと広告'),
    SettingsRow('ヘルプ、法的表示'),
  ], note: 'この画面ではインストールされたプラグインのうち、SNS変換プラグインの設定画面だけセクションが表示される。この画面は FOW の DSL で作る(第一階層以降)。'),
  'appearance': SettingsSection('アプリの外観', [
    SettingsRow('インターフェースの表示サイズ', route: '/settings/dsl/appearance.display'),
    SettingsRow('フォントやカラースキーム'),
    SettingsRow('モーションの抑制', route: '/settings/dsl/appearance.motion'),
    SettingsRow('ピクチャインピクチャ'),
    SettingsRow('通知の表示形式'),
  ]),
  'astell': SettingsSection('ASTell', [
    SettingsRow('ASTell 4Uを購読'),
    SettingsRow('Tellタイル'),
    SettingsRow('トレンドタイムラインへの配信'),
    SettingsRow('プラグインの詳細設定'),
    SettingsRow('画面オフ時の動作'),
  ], note: 'AsTell は当面実装しない(D-011)。項目は仕様確定用のプレースホルダー。'),
  'relational': SettingsSection('リレーショナルタイムライン', [
    SettingsRow('投稿クラスター'),
    SettingsRow('Relayタイル'),
    SettingsRow('トレンドタイムラインへの配信'),
    SettingsRow('プラグインの詳細設定'),
    SettingsRow('トレンドのサンプリングレベル'),
  ], note: 'リレーショナルTL はアルゴリズム確定後(D-011)。'),
  'trend': SettingsSection('トレンド', [
    SettingsRow('ジャンル'),
    SettingsRow('トレンドの指向性/刺激性', warning: true),
    SettingsRow('プラグインの詳細設定'),
    SettingsRow('キャッシュネットワークの設定'),
  ]),
  'notifications': SettingsSection('通知', [
    SettingsRow('プロファイル', route: 'notificationPrefs'),
    SettingsRow('アクセストークン'),
    SettingsRow('セキュリティ'),
  ]),
  'about': SettingsSection('RASQについて', [
    SettingsRow('アカウント'),
    SettingsRow('ヘルプ'),
    SettingsRow('購読状況'),
    SettingsRow('クッキーについて'),
    SettingsRow('プライバシーポリシー'),
    SettingsRow('利用規約'),
    SettingsRow('リソースと広告'),
    SettingsRow('ヘルプ、法的表示'),
  ]),
};
