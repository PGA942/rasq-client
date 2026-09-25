import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 投稿のリアクションの受け方 (D-321)。投稿の行が、リアクションのチップ(角丸の絵文字 + 数)/ ピッカー / 予測絵文字を出すかを決める。
enum PostReactionMode {
  /// 絵文字でリアクションできる(Misskey のふつうのノート): チップ / 長押しのピッカー / 予測絵文字。
  emoji,

  /// 絵文字でリアクションできる SNS だが、この投稿は「いいねのみ」(Misskey の `reactionAcceptance`):
  /// チップもピッカーも出さず、ボタン(❤)を押すと [likeOnlyReaction] を付ける。数はボタンに。
  likeOnly,

  /// 絵文字リアクションの仕組みが無い SNS(Mastodon のお気に入り / Bluesky・mixi2 のいいね):
  /// チップもピッカーも出さず、ボタンは宣言どおりのいいね(押すと入り切り)。数はボタンに。
  like,
}

/// 「いいねのみ」の投稿に付けるリアクション(Misskey の公式クライアントと同じ ❤)。
const likeOnlyReaction = '❤️';

/// 「いいねのみ」の `reactionAcceptance`。`…ForRemote` は、リアクションする側(見ているアカウント)が投稿のサーバーの外のときだけ。
const _likeOnlyAcceptance = {'likeOnly'};
const _likeOnlyForRemoteAcceptance = {'likeOnlyForRemote', 'nonSensitiveOnlyForLocalLikeOnlyForRemote'};

/// [post] のリアクションの受け方。[reaction] = その投稿の SNS の `Reaction` ジャンルの宣言。
///
/// **絵文字でリアクションできるか = `Reaction` の宣言の `iconPerPost`**(投稿ごとにボタンのアイコンを付けた絵文字 / 予測絵文字に
/// 差し替える。CONTRACT の D-017 / V7)。プラグイン名(Misskey か)では決めない: 絵文字の仕組みを持つ SNS だけがこれを宣言し
/// (Misskey / RASQ のキュー)、いいね / お気に入りだけの SNS(Mastodon / Bluesky / mixi2)は宣言しない。
/// 宣言が見つからない(アクションを持たない面)ときは、これまでどおり [PostReactionMode.emoji]。
PostReactionMode reactionModeOf(Post post, ActionDescriptor? reaction) {
  if (reaction == null) return PostReactionMode.emoji;
  if (!reaction.iconPerPost) return PostReactionMode.like;
  final acceptance = post.reactionAcceptance;
  if (_likeOnlyAcceptance.contains(acceptance)) return PostReactionMode.likeOnly;
  // 外から(見ているアカウントのサーバー ≠ 投稿者のサーバー)は、いいねだけ。
  if (_likeOnlyForRemoteAcceptance.contains(acceptance) && post.author.account.instance != post.account.instance) return PostReactionMode.likeOnly;
  return PostReactionMode.emoji;
}
