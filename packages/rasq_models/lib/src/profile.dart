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
}
