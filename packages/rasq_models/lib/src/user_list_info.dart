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
