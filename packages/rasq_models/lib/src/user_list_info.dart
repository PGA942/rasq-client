import 'package:meta/meta.dart';

import 'user.dart';

/// A user list (リスト). Members are resolved lazily via `SnsSession.listMembers`.
@immutable
class UserListInfo {
  const UserListInfo({required this.id, required this.name, this.memberIds = const [], this.owner, this.description, this.isPublic = false});
  final String id;
  final String name;
  final List<String> memberIds;
  final UserSummary? owner;
  final String? description;
  final bool isPublic;
}

/// カスタムフィード (D-194: Bluesky のフィードジェネレーター。第二期以降は RASQ リストもここへ)。
@immutable
class FeedInfo {
  const FeedInfo({required this.uri, required this.name, this.description, this.likeCount, this.creator});
  final String uri;
  final String name;
  final String? description;
  final int? likeCount;
  final String? creator;
}

/// Profile fields the user may edit (プロフィール編集). null = unchanged.
@immutable
class ProfileUpdate {
  const ProfileUpdate({this.displayName, this.description, this.location, this.birthday, this.fields, this.avatarMediaId, this.bannerMediaId});
  final String? displayName;
  final String? description;
  final String? location;

  /// `YYYY-MM-DD`.
  final String? birthday;
  final List<({String name, String value})>? fields;
  final String? avatarMediaId;
  final String? bannerMediaId;
}
