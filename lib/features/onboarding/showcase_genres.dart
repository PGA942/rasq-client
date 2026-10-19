import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/server_info_api.dart' show ShowcaseCandidate;
import '../../l10n/l10n.dart';
import '../child_safe/child_gate.dart';
import '../rai/rai_reference.dart' show RaiEmbedder, cosine;

/// オンボーディングのタイルに出す見本の投稿のジャンル (D-412)。**ひと目で分かる**ものだけ(ゲーム / 食べ物 / 猫 …)。
/// ジャンルの分からない投稿(挨拶・雑談・内輪の話)は見本にしない。
@immutable
class ShowcaseGenre {
  const ShowcaseGenre(this.id, {required this.words, required this.prototypes});
  final String id;

  /// 画面に出す名前(チップ)。
  String get label => switch (id) {
        'game' => appL10n.onboardingGenreGame,
        'anime' => appL10n.onboardingGenreAnime,
        'music' => appL10n.onboardingGenreMusic,
        'art' => appL10n.onboardingGenreArt,
        'photo' => appL10n.onboardingGenrePhoto,
        'food' => appL10n.onboardingGenreFood,
        'tech' => appL10n.onboardingGenreTech,
        'animal' => appL10n.onboardingGenreAnimal,
        'sports' => appL10n.onboardingGenreSports,
        'travel' => appL10n.onboardingGenreTravel,
        'books' => appL10n.onboardingGenreBooks,
        'movie' => appL10n.onboardingGenreMovie,
        'nature' => appL10n.onboardingGenreNature,
        _ => id,
      };

  /// 語の辞書(小文字で比べる。ハッシュタグもこれで当たる)。
  final List<String> words;

  /// MiniLM で比べる見本の文(端末に RASQ MiniLM があるとき、D-390)。
  final List<String> prototypes;
}

const showcaseGenres = <ShowcaseGenre>[
  ShowcaseGenre('game', words: [
    'ゲーム', 'game', 'スプラ', 'ポケモン', 'ガチャ', 'switch', 'スイッチ', 'steam', 'マイクラ', 'minecraft', 'プレイ', 'ランクマ', 'ガチマ', 'ウデマエ', '攻略', 'ボス', 'レベル上げ', 'モンハン', 'ドラクエ', 'ff14', 'apex', 'valorant', 'ソシャゲ', 'ゲーセン', '音ゲー', // l10n-ignore
  ], prototypes: ['ゲームをプレイした感想', '新作ゲームの攻略とガチャ', 'Playing a video game']), // l10n-ignore
  ShowcaseGenre('anime', words: [
    'アニメ', 'anime', 'マンガ', '漫画', 'manga', '今期', '作画', '声優', '推し', '最新話', 'コミック', '単行本', 'ジャンプ', 'vtuber', '配信見', 'コミケ', '同人', // l10n-ignore
  ], prototypes: ['アニメやマンガの感想', '推しのキャラクターと声優', 'Watching anime and reading manga']), // l10n-ignore
  ShowcaseGenre('music', words: [
    '音楽', 'music', '新曲', 'この曲', 'アルバム', 'ライブ', 'live', 'ギター', 'ピアノ', 'ベース', 'ドラム', '歌', 'カラオケ', 'バンド', 'フェス', 'dtm', '作曲', 'ボカロ', 'spotify', 'プレイリスト', // l10n-ignore
  ], prototypes: ['音楽を聴いた感想、好きな曲', 'ライブやコンサートに行った', 'Listening to music and songs']), // l10n-ignore
  ShowcaseGenre('art', words: [
    'イラスト', '絵を', 'お絵かき', '落書き', 'らくがき', 'illust', 'drawing', 'art', '創作', '模写', '描いた', '厚塗り', 'clip studio', 'クリスタ', '手芸', '刺繍', 'ハンドメイド', '工作', 'プラモ', // l10n-ignore
  ], prototypes: ['イラストを描いた、絵の練習', '創作や作品づくり、ものづくり', 'Drawing an illustration']), // l10n-ignore
  ShowcaseGenre('photo', words: [
    '写真', 'photo', 'カメラ', 'camera', '撮った', '撮影', '一枚', 'レンズ', 'フィルム', '夕焼け', '朝焼け', '星空', '風景', // l10n-ignore
  ], prototypes: ['写真を撮った、カメラと風景', '空と景色の写真', 'Taking photos of scenery']), // l10n-ignore
  ShowcaseGenre('food', words: [
    'ごはん', 'ご飯', 'ランチ', 'ディナー', '朝ごはん', '晩ごはん', '料理', '自炊', 'レシピ', 'ラーメン', 'カレー', 'パン', 'ケーキ', 'スイーツ', 'お菓子', 'カフェ', 'コーヒー', '紅茶', 'おいしい', '美味しい', 'うまい', '弁当', '寿司', '焼肉', 'food', 'lunch', 'cooking', // l10n-ignore
  ], prototypes: ['ご飯を食べた、料理とおいしいもの', 'ラーメンやカフェ、お菓子', 'Cooking and eating food']), // l10n-ignore
  ShowcaseGenre('tech', words: [
    'プログラミング', 'プログラム', 'コード', 'code', 'rust', 'python', 'javascript', 'typescript', 'flutter', 'dart', 'linux', 'github', 'gitlab', 'エンジニア', '開発', 'バグ', 'デプロイ', 'サーバー構築', '自宅サーバー', 'pc', '自作pc', 'キーボード', 'ai', 'llm', 'android', 'iphone', // l10n-ignore
  ], prototypes: ['プログラミングとソフトウェア開発', 'パソコンやサーバー、コードを書く', 'Programming and software']), // l10n-ignore
  ShowcaseGenre('animal', words: [
    '猫', 'ねこ', 'ネコ', 'にゃん', 'cat', '犬', 'いぬ', 'イヌ', 'わんこ', 'dog', '柴犬', 'ペット', 'うさぎ', 'ハムスター', 'インコ', '動物園', '水族館', // l10n-ignore
  ], prototypes: ['猫や犬などペットの様子', '動物がかわいい', 'Pets, cats and dogs']), // l10n-ignore
  ShowcaseGenre('sports', words: [
    'スポーツ', '野球', 'サッカー', 'バスケ', 'テニス', 'ラグビー', 'バレー', '陸上', 'マラソン', 'ランニング', '筋トレ', 'ジム', '試合', '優勝', 'ゴール', 'ホームラン', '代表戦', 'f1', '競馬', 'sports', 'soccer', 'baseball', // l10n-ignore
  ], prototypes: ['スポーツの試合を観戦した', '野球やサッカーの応援', 'Watching a sports game']), // l10n-ignore
  ShowcaseGenre('travel', words: [
    '旅行', '旅', 'おでかけ', 'お出かけ', '観光', '温泉', 'ホテル', '旅館', '新幹線', '飛行機', '空港', '鉄道', '電車旅', 'ドライブ', 'キャンプ', '登山', 'travel', 'trip', // l10n-ignore
  ], prototypes: ['旅行やおでかけに行った', '観光地と電車の旅', 'Traveling and sightseeing']), // l10n-ignore
  ShowcaseGenre('books', words: [
    '読書', '小説', '読了', '読んだ', '新刊', '書店', '本屋', '図書館', 'エッセイ', 'book', 'novel', 'reading', // l10n-ignore
  ], prototypes: ['本を読んだ感想、読書', '小説を読み終えた', 'Reading a book']), // l10n-ignore
  ShowcaseGenre('movie', words: [
    '映画', 'ドラマ', '映画館', '上映', '試写', 'netflix', 'ネトフリ', 'アマプラ', '特撮', 'movie', 'film', 'cinema', // l10n-ignore
  ], prototypes: ['映画やドラマを観た感想', '映画館で新作を観た', 'Watching a movie']), // l10n-ignore
  ShowcaseGenre('nature', words: [
    '紅葉', '桜', 'お花見', '紫陽花', 'あじさい', 'ひまわり', '花が', '雪景色', '初雪', '梅雨', '季節', '散歩道', '植物', '家庭菜園', 'ガーデニング', '盆栽', '虹', // l10n-ignore
  ], prototypes: ['天気と季節の移り変わり', '花が咲いた、紅葉', 'Weather and seasons']), // l10n-ignore
];

/// MiniLM で「ジャンルの無い投稿」に寄せる見本の文(挨拶・雑談・内輪)。これより近いジャンルが無ければ、見本にしない。
const _noGenrePrototypes = [
  'おはようございます、おやすみなさい', // l10n-ignore
  '疲れた、眠い、ただいま', // l10n-ignore
  'それな、わかる、ありがとう', // l10n-ignore
  'よろしくお願いします、フォローありがとう', // l10n-ignore
  '今日も一日がんばろう', // l10n-ignore
  'このサーバーの管理人さん、住人のみなさん', // l10n-ignore
];

/// 判定の結果。
@immutable
class ShowcaseGenreMatch {
  const ShowcaseGenreMatch(this.genre, this.confidence, {required this.byModel});
  final ShowcaseGenre genre;

  /// 0〜1。
  final double confidence;

  /// MiniLM で決めたか(false = 語の辞書)。
  final bool byModel;
}

/// ジャンルの判定 (D-412)。**新しいモデルは足さない**: 端末に RASQ MiniLM(D-390、RAi の検索と共用)が入っていればそれで見本の文と比べ、
/// 無ければ(初回のオンボーディングはたいていこちら)語の辞書だけ。どちらも当たらない投稿は「ジャンルが分からない」= 見本にしない。
///
/// MiniLM のしきい値は、RASQ MiniLM(uint8、onnxruntime)で日本語の SNS 風の文 38 件を測って決めた: いちばん近いジャンル ≥ [minModelScore]、
/// 2 番目との差 ≥ [minModelMargin]、「ジャンルの無い」見本の文より近いこと。辞書 + モデル + 15 文字以上で、ジャンルの投稿 23 件のうち 18 件が
/// 付けたとおり、2 件は別の読み方(「推しの新刊」→ 本・読書、「京都の紅葉」→ 季節・自然)、3 件は短くて採らない。挨拶・雑談・内輪の 15 件は 1 件も採らない。
class ShowcaseGenreClassifier {
  ShowcaseGenreClassifier({this.embedder});

  /// RASQ MiniLM のときだけ渡す(ほかの埋め込みはしきい値が合わない)。
  final RaiEmbedder? embedder;

  static const minModelScore = 0.42;
  static const minModelMargin = 0.05;

  /// 渡された埋め込みが RASQ MiniLM か(端末 / Web)。
  static bool isRasqMiniLm(RaiEmbedder e) => e.name.contains('rasq-minilm');

  List<List<double>>? _protos;
  List<List<double>>? _none;

  Future<void> _ensure() async {
    final e = embedder;
    if (e == null || _protos != null) return;
    _protos = await e.embed([for (final g in showcaseGenres) ...g.prototypes]);
    _none = await e.embed(_noGenrePrototypes);
  }

  /// 語の辞書: 当たった語の数がいちばん多いジャンル(同じ数なら先に並べたもの)。
  static ShowcaseGenreMatch? byWords(String text) {
    final t = text.toLowerCase();
    ShowcaseGenre? best;
    var hits = 0;
    for (final g in showcaseGenres) {
      var n = 0;
      for (final w in g.words) {
        if (_hasWord(t, w)) n++;
      }
      if (n > hits) {
        hits = n;
        best = g;
      }
    }
    return best == null ? null : ShowcaseGenreMatch(best, math.min(1, 0.55 + 0.15 * hits), byModel: false);
  }

  /// ASCII の語は語の境目で(`ai` が `said` に当たらないように)、それ以外は含むかどうかで。
  static bool _hasWord(String text, String word) {
    if (!RegExp(r'^[a-z0-9 ]+$').hasMatch(word)) return text.contains(word);
    return RegExp('(^|[^a-z0-9])${RegExp.escape(word)}(\$|[^a-z0-9])').hasMatch(text);
  }

  /// 投稿の本文たち → ジャンル(分からなければ null)。並びは渡した順。
  Future<List<ShowcaseGenreMatch?>> classify(List<String> texts) async {
    final words = [for (final t in texts) byWords(t)];
    final e = embedder;
    if (e == null || texts.isEmpty) return words;
    try {
      await _ensure();
      final vecs = await e.embed(texts);
      return [for (var i = 0; i < texts.length; i++) _combine(words[i], _byModel(vecs[i]))];
    } catch (err) {
      debugPrint('showcase genre: model failed, words only: $err');
      return words;
    }
  }

  ShowcaseGenreMatch? _byModel(List<double> v) {
    final protos = _protos!;
    final scores = <ShowcaseGenre, double>{};
    var k = 0;
    for (final g in showcaseGenres) {
      for (var j = 0; j < g.prototypes.length; j++) {
        final s = cosine(v, protos[k++]);
        if (s > (scores[g] ?? -1)) scores[g] = s;
      }
    }
    final ranked = scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.first;
    final second = ranked.length > 1 ? ranked[1].value : 0.0;
    final none = _none!.map((n) => cosine(v, n)).reduce(math.max);
    if (top.value < minModelScore || top.value - second < minModelMargin || top.value <= none) return null;
    return ShowcaseGenreMatch(top.key, top.value.clamp(0, 1).toDouble(), byModel: true);
  }

  /// 辞書とモデルを合わせる: 同じなら強く、食い違えば辞書(語ははっきりしている)、片方だけならそれ。
  static ShowcaseGenreMatch? _combine(ShowcaseGenreMatch? words, ShowcaseGenreMatch? model) {
    if (words == null) return model;
    if (model == null) return words;
    if (words.genre.id == model.genre.id) return ShowcaseGenreMatch(words.genre, math.min(1, words.confidence + 0.2), byModel: true);
    return words;
  }
}

/// 選んだ見本の投稿 1 件。
@immutable
class ShowcasePick {
  const ShowcasePick({required this.post, required this.genre, required this.score});
  final Post post;
  final ShowcaseGenreMatch genre;
  final double score;
}

/// 見本にしない語(本文と、投稿した人の名前に。Central S-072 と同じ最低限の網。名前に 🔞 を付けている人の投稿は出さない)。
const _blockWords = ['nsfw', 'r18', 'r-18', '18禁', '閲覧注意', 'エロ', 'グロ', '🔞']; // l10n-ignore

/// 見本に出してよい投稿か(Central でも落としているが、RASQ リストのスナップショットにも同じ網をかける)。
/// 公開だけ / ローカルのみでない / 返信・リノートでない / CW・センシティブな添付が無い / 15 文字以上 / 刺激の強い語が無い / 見守りの判定 (D-307) で隠れない。
bool showcaseEligible(Post p, {ChildGate? gate}) {
  if (p.visibility != 'public' || p.localOnly) return false;
  if (p.replyToId != null || p.replyTo != null || p.repostedBy != null) return false;
  if (p.contentWarning?.trim().isNotEmpty ?? false) return false;
  if (p.media.any((m) => m.sensitive)) return false;
  if (p.body.trim().runes.length < 15) return false;
  final text = '${p.body}\n${p.author.displayName}'.toLowerCase();
  if (_blockWords.any(text.contains)) return false;
  if (gate != null && gate.supervised && gate.postHidden(p)) return false;
  return true;
}

/// 候補から見本を [max] 件選ぶ (D-412): 出してよいもの → ジャンルが分かるものだけ → 強さ × 確からしさの順。
/// 同じジャンルは後回し(並べたときにいろいろ見えるように)。
Future<List<ShowcasePick>> selectShowcasePosts(List<ShowcaseCandidate> candidates, ShowcaseGenreClassifier classifier, {int max = 3, ChildGate? gate}) async {
  final ok = [for (final c in candidates) if (showcaseEligible(c.post, gate: gate)) c];
  if (ok.isEmpty) return const [];
  final genres = await classifier.classify([for (final c in ok) c.post.body]);
  final picks = <ShowcasePick>[
    for (var i = 0; i < ok.length; i++)
      if (genres[i] != null) ShowcasePick(post: ok[i].post, genre: genres[i]!, score: (1 + ok[i].score) * genres[i]!.confidence),
  ]..sort((a, b) => b.score.compareTo(a.score));
  final out = <ShowcasePick>[];
  final used = <String>{};
  for (final p in picks) {
    if (out.length >= max) break;
    if (used.add(p.genre.genre.id)) out.add(p);
  }
  for (final p in picks) {
    if (out.length >= max) break;
    if (!out.contains(p)) out.add(p);
  }
  return out;
}
