import 'package:meta/meta.dart';

import 'account.dart';

/// Presence flags rendered on avatars (LIVE / VC中).
enum UserPresence { none, inVc, live }

@immutable
class UserSummary {
  const UserSummary({
    required this.id,
    required this.account,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.presence = UserPresence.none,
  });

  /// Plugin-scoped stable id (DID / Misskey id …).
  final String id;
  final AccountId account;
  final String displayName;
  final Uri? avatarUrl;
  final String? bio;
  final UserPresence presence;

  String get handle => account.handle;

  /// Store key: `kind:instance:id`.
  String get key => '${account.kind.name}:${account.instance}:$id';

  @override
  bool operator ==(Object other) => other is UserSummary && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
