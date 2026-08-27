import 'package:meta/meta.dart';

import 'user.dart';

/// Incoming follow request (フォロー申請).
@immutable
class FollowRequest {
  const FollowRequest({required this.id, required this.user, this.createdAt});
  final String id;
  final UserSummary user;
  final DateTime? createdAt;
}
