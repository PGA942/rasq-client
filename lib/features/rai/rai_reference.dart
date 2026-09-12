import '../../app/router.dart';
import '../home/plugin_actions.dart' show tagSimilarity;

/// RAi インストラクションの基本リファレンス (D-179)。
///
/// 端末側に持つ「ベースのインストラクション」(ワイヤーフレーム p.4 の注)。質問に一番近い
/// ものを選び、手順ごとに RAi がその部品まで移動して指差す。SBERT / ハイブリッド DB
/// (SQLite + vector)への置き換えは後段 — 契約はこの [RaiInstruction] のまま。
class RaiInstruction {
  const RaiInstruction({required this.id, required this.title, required this.keywords, required this.steps});
  final String id;
  final String title;
  final List<String> keywords;
  final List<RaiStep> steps;
}

/// 1 手順: 文と、指差す部品(ツールチップ / 表示テキスト)、必要なら先に開く画面。
class RaiStep {
  const RaiStep(this.text, {this.tooltip, this.label, this.route});
  final String text;
  final String? tooltip;
  final String? label;
  final String? route;
  bool get hasTarget => tooltip != null || label != null;
}

const raiReference = <RaiInstruction>[
  RaiInstruction(id: 'login-bluesky', title: 'Bluesky でログイン', keywords: ['Bluesky', 'ブルースカイ', 'bsky', 'ログイン'], steps: [
    RaiStep('「Blueskyでログイン」をクリックしてください', label: 'Blueskyでログイン', route: Routes.login),
    RaiStep('PDS(通常は bsky.social)とハンドル、アプリパスワードを入れて「ログイン」を押します', label: 'ログイン'),
  ]),
  RaiInstruction(id: 'login-misskey', title: 'Misskey でログイン', keywords: ['Misskey', 'ミスキー', 'ログイン'], steps: [
    RaiStep('「Misskeyでログイン」をクリックしてください', label: 'Misskeyでログイン', route: Routes.login),
    RaiStep('インスタンスの URL を入れて認証すると、アカウントが追加されます'),
  ]),
  RaiInstruction(id: 'login-mastodon', title: 'Mastodon でログイン', keywords: ['Mastodon', 'マストドン', 'ログイン'], steps: [
    RaiStep('「Mastodonでログイン」をクリックしてください', label: 'Mastodonでログイン', route: Routes.login),
    RaiStep('インスタンスの URL を入れて認証すると、アカウントが追加されます'),
  ]),
  RaiInstruction(id: 'post', title: '投稿する', keywords: ['投稿', 'ノート', '書く', 'ポスト', 'つぶやく'], steps: [
    RaiStep('右下の「投稿」でコンポーザーが開きます', tooltip: '投稿', route: Routes.home),
    RaiStep('本文を書いて、ヘッダーの「投稿」で送ります。添付は下のツールバーから', tooltip: '画像'),
  ]),
  RaiInstruction(id: 'draft', title: '下書き', keywords: ['下書き', 'ドラフト', '保存'], steps: [
    RaiStep('コンポーザーを開きます', tooltip: '投稿', route: Routes.home),
    RaiStep('ヘッダー右の「下書き」から保存 / 開く / 削除ができます', label: '下書き'),
  ]),
  RaiInstruction(id: 'share', title: '投稿を共有', keywords: ['共有', 'シェア', 'リンク', 'AsTell に共有'], steps: [
    RaiStep('投稿のアクションバー右端の「共有」を押します', tooltip: '共有', route: Routes.home),
    RaiStep('内容 / リンクのコピー、プラグインに共有、DM へ共有が選べます'),
  ]),
  RaiInstruction(id: 'tl-config', title: 'タイムライン設定', keywords: ['タイムライン', 'TL', 'アルゴリズム', '並び', 'おすすめ'], steps: [
    RaiStep('タブ行の右端の歯車でタイムラインの設定が開きます', tooltip: 'タイムライン設定', route: Routes.home),
  ]),
  RaiInstruction(id: 'astell', title: 'AsTell(VC)', keywords: ['AsTell', 'アステル', 'VC', 'ルーム', '通話'], steps: [
    RaiStep('下のタブの「AsTell」でルーム一覧へ', tooltip: 'AsTell'),
    RaiStep('タイルの「見てみる」→「参加」でルーム FOW が開きます', label: '見てみる'),
  ]),
  RaiInstruction(id: 'plugins', title: 'プラグインを追加', keywords: ['プラグイン', 'ストア', '拡張', '追加'], steps: [
    RaiStep('サイドメニュー(ヘッダー左のアイコン)の「プラグイン」でストアが開きます', label: 'プラグイン', route: Routes.store),
  ]),
  RaiInstruction(id: 'settings', title: '設定', keywords: ['設定', 'オプション', 'テーマ', 'ダーク'], steps: [
    RaiStep('サイドメニューの「全ての設定」から', route: Routes.settings),
  ]),
];

/// 質問に最も近いインストラクション(閾値未満なら null)。完全一致 / 含む = 1.0、
/// それ以外は 2-gram Dice(`tagSimilarity`)。
({RaiInstruction instruction, double score})? matchInstruction(String query, {double threshold = 0.45}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return null;
  ({RaiInstruction instruction, double score})? best;
  for (final ins in raiReference) {
    var score = 0.0;
    for (final k in [ins.title, ...ins.keywords]) {
      final kk = k.toLowerCase();
      final s = q.contains(kk) || kk.contains(q) ? 1.0 : tagSimilarity(q, kk);
      if (s > score) score = s;
    }
    // 複数キーワードが当たる(Bluesky + ログイン)ほど上へ。
    final hits = ins.keywords.where((k) => q.contains(k.toLowerCase())).length;
    score += hits * 0.05;
    if (best == null || score > best.score) best = (instruction: ins, score: score);
  }
  if (best == null || best.score < threshold) return null;
  return best;
}
