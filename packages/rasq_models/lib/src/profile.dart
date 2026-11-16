import 'package:meta/meta.dart';

import 'post.dart';
import 'user.dart';

/// Key/value meta row on a profile (リンク / 誕生日 / 場所 …).
@immutable
class ProfileField {
  const ProfileField({required this.name, required this.value, this.verified = false});
  final String name;
  final String value;
  final bool verified;
}

/// Full profile used by UserTileLarge.
@immutable
class UserProfile {
  const UserProfile({
    required this.summary,
    this.bannerUrl,
    this.description,
    this.followersCount,
    this.followingCount,
    this.postsCount,
    this.fields = const [],
    this.createdAt,
    this.birthday,
    this.location,
    this.url,
    this.isLocked = false,
    this.isBot = false,
    this.isSuspended = false,
    this.pinnedPosts = const [],
    this.profileUrl,
    this.followingVisibility,
    this.followersVisibility,
  });

  final UserSummary summary;
  final Uri? bannerUrl;
  final String? description;
  final int? followersCount;
  final int? followingCount;
  final int? postsCount;
  final List<ProfileField> fields;
  final DateTime? createdAt;
  final String? birthday;
  final String? location;
  final Uri? url;
  final bool isLocked;
  final bool isBot;
  final bool isSuspended;
  final List<Post> pinnedPosts;

  /// Profile web URL (リンクをコピー).
  final Uri? profileUrl;

  /// フォロー / フォロワーの一覧の公開範囲 (D-560、Misskey の `followingVisibility` / `followersVisibility`)。
  /// 分からなければ null(公開として扱う)。公開していなくて人数が来ない(null)とき、人数の代わりに印を出す。
  final FollowListVisibility? followingVisibility;
  final FollowListVisibility? followersVisibility;
}

/// フォロー / フォロワーの一覧の公開範囲 (D-560)。
enum FollowListVisibility {
  public,

  /// フォロワーにだけ(フォローしていなければ見えない)。
  followers,

  /// 本人だけ。
  private;

  /// `public` / `followers` / `private`(Misskey の値)。ほかは null。
  static FollowListVisibility? parse(Object? v) => switch (v) { 'public' => public, 'followers' => followers, 'private' => private, _ => null };
}
