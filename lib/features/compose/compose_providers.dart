import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';

/// Custom emoji of the current instance (絵文字ピッカー「独自の絵文字」).
final customEmojisProvider = FutureProvider<List<EmojiInfo>>((ref) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  return s.customEmojis();
});

/// Recently used emoji (「履歴」) — in-memory for now (persist in M2 settings).
class RecentEmojiStore extends Notifier<List<String>> {
  @override
  List<String> build() => const [];
  void push(String e) => state = [e, ...state.where((x) => x != e)].take(24).toList();
}

final recentEmojiProvider = NotifierProvider<RecentEmojiStore, List<String>>(RecentEmojiStore.new);
