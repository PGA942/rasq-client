import 'package:meta/meta.dart';

/// Backend family of an SNS account. Phase 1 targets Bluesky / Misskey /
/// Mastodon (D-008). `mixi2` only has a contract placeholder.
enum SnsKind {
  bluesky,
  misskey,
  mastodon,
  mixi2,
  other;

  /// Human readable label used in pills next to handles (e.g. "BlueSky").
  String get label => switch (this) {
        SnsKind.bluesky => 'BlueSky',
        SnsKind.misskey => 'Misskey',
        SnsKind.mastodon => 'Mastodon',
        SnsKind.mixi2 => 'mixi2',
        SnsKind.other => 'SNS',
      };
}

/// Identifies one logged-in account. Plugins are versioned per account
/// (原典: 何をやる.md「プラグインはSNSアカウント毎に違うバージョンを適用できる」),
/// so most keys in the store are scoped by [AccountId].
@immutable
class AccountId {
  const AccountId({required this.kind, required this.instance, required this.handle});

  final SnsKind kind;

  /// Instance / PDS host (e.g. `bsky.social`, `misskey.io`).
  final String instance;

  /// Handle without the leading `@`.
  final String handle;

  /// Stable textual key: `kind:instance:handle`.
  String get key => '${kind.name}:$instance:$handle';

  @override
  bool operator ==(Object other) => other is AccountId && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => '@$handle@$instance';
}
