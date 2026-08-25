import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../home/timeline_providers.dart';
import 'relational_engine.dart';

class RelationalSettingsStore extends Notifier<RelationalSettings> {
  @override
  RelationalSettings build() => const RelationalSettings();

  void set(RelationalSettings next) => state = next;
}

final relationalSettingsProvider = NotifierProvider<RelationalSettingsStore, RelationalSettings>(RelationalSettingsStore.new);

/// フォロイーTL(home)+ 候補(local があれば)からクラスタを組む。
/// どちらの TL も既存の timelineProvider を共有(追加フェッチは local のみ)。
final relationalClustersProvider = Provider<AsyncValue<List<RelationalCluster>>>((ref) {
  final settings = ref.watch(relationalSettingsProvider);
  final session = ref.watch(currentSnsSessionProvider);
  final home = ref.watch(timelineProvider(TimelineKind.home));
  final supportsLocal = session?.timelines.contains(TimelineKind.local) ?? false;
  final local = supportsLocal ? ref.watch(timelineProvider(TimelineKind.local)) : null;

  return home.whenData((h) {
    final followeePosts = h.posts;
    final followeeKeys = {for (final p in followeePosts) p.key};
    final candidates = [
      for (final p in local?.value?.posts ?? const <Post>[])
        if (!followeeKeys.contains(p.key)) p,
    ];
    final engine = RelationalEngine(settings: settings);
    return engine.build(followeePosts: followeePosts, candidatePosts: candidates);
  });
});
