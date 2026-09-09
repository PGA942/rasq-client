import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../shell/headers.dart';
import 'user_list.dart';
import 'user_providers.dart';

/// フォロー中 / フォロワー を表示 (tabs ∨フォロー中 / フォロワー).
class FollowsScreen extends ConsumerWidget {
  const FollowsScreen({super.key, required this.userId, this.initialFollowers = false, this.user});
  final String userId;
  final bool initialFollowers;
  final UserSummary? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = [const RasqTabItem('フォロー中'), const RasqTabItem('フォロワー')];
    return DefaultTabController(
      length: 2,
      initialIndex: initialFollowers ? 1 : 0,
      child: Scaffold(
        appBar: RasqPageHeader(title: user?.displayName ?? 'フォロー/フォロワー', onMore: () {}, bottom: RasqTabs(items: tabs)),
        body: TabBarView(children: [
          _List(k: (id: userId, followers: false, account: user?.account.key)),
          _List(k: (id: userId, followers: true, account: user?.account.key)),
        ]),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.k});
  final ({String id, bool followers, String? account}) k;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(followsProvider(k));
    return page.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(followsProvider(k)), retryLabel: '再読み込み'),
      data: (p) => p.items.isEmpty ? RasqEmptyView(title: k.followers ? 'フォロワーはいません' : 'フォロー中のユーザーはいません') : UserList(users: p.items),
    );
  }
}
