import 'package:meta/meta.dart';

import 'user.dart';

/// One user's reaction on a post (リアクションを表示).
@immutable
class ReactionEntry {
  const ReactionEntry({required this.id, required this.user, required this.reaction, required this.createdAt, this.emojiUrl});
  final String id;
  final UserSummary user;

  /// Reaction string: unicode emoji or `:shortcode:` / `:shortcode@host:`.
  final String reaction;
  final DateTime createdAt;
  final Uri? emojiUrl;
}

/// Custom emoji available for composing / reacting.
@immutable
class EmojiInfo {
  const EmojiInfo({required this.name, required this.url, this.category, this.aliases = const []});
  final String name;
  final Uri url;
  final String? category;
  final List<String> aliases;
}
