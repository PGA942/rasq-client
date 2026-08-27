import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';

/// トレンドワード. Phase-1 sample: `hashtags/trend` of the current SNS
/// (server-side trend provider lands later).
final trendingTagsProvider = FutureProvider.autoDispose<List<TrendTag>>((ref) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  return s.trendingTags();
});
