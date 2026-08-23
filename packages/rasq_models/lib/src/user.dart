import 'package:meta/meta.dart';

import 'account.dart';

/// Presence flags rendered on avatars (LIVE / VC中).
enum UserPresence { none, inVc, live }

/// RASQ account verification tier, rendered as a badge next to the display
/// name (`RasqVerifiedBadge`). Issued by the RASQ account server, not by the
/// SNS plugin — SNS adapters leave it [none]; the host fills it in once the
/// RASQ account ↔ SNS account link (第二期) exists.
enum UserVerification { none, person, company, government }

@immutable
class UserSummary {
  const UserSummary({
    required this.id,
    required this.account,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.presence = UserPresence.none,
    this.verification = UserVerification.none,
  });

  /// Plugin-scoped stable id (DID / Misskey id …).
  final String id;
  final AccountId account;
  final String displayName;
  final Uri? avatarUrl;
  final String? bio;
  final UserPresence presence;
  final UserVerification verification;

  String get handle => account.handle;

  /// Store key: `kind:instance:id`.
  String get key => '${account.kind.name}:${account.instance}:$id';

  @override
  bool operator ==(Object other) => other is UserSummary && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
