import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import 'user_providers.dart';

/// フォロー申請を表示: tabs ∨関連性 / フォロー中 / その他、各行に 許可 / 拒否.
class FollowRequestsScreen extends ConsumerWidget {
  const FollowRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(followRequestsProvider);
    final s = ref.watch(currentSnsSessionProvider);
    final tabs = [RasqTabItem(context.l10n.usersFollowRequestsTabRelevance), RasqTabItem(context.l10n.usersFollowRequestsTabFollowing), RasqTabItem(context.l10n.usersFollowRequestsTabOther)];
    Future<void> act(String userId, bool accept) async {
      if (s == null) return;
      accept ? await s.acceptFollowRequest(userId) : await s.rejectFollowRequest(userId);
      ref.invalidate(followRequestsProvider);
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: RasqPageHeader(title: context.l10n.usersFollowRequestsTitle, onMore: () {}, bottom: RasqTabs(items: tabs)),
        body: list.when(
          loading: () => const RasqLoading(),
          error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(followRequestsProvider), retryLabel: context.l10n.usersReload),
          data: (reqs) => TabBarView(children: [
            for (var t = 0; t < 3; t++)
              reqs.isEmpty || t > 0
                  ? RasqEmptyView(title: t == 0 ? context.l10n.usersFollowRequestsEmpty : context.l10n.usersFollowRequestsEmptyOther)
                  : ListView.separated(
                      itemCount: reqs.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, i) {
                        final r = reqs[i];
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          RasqUserRow(user: r.user, trailing: const SizedBox.shrink(), onTap: () => context.pushUser(r.user), onMore: () {}),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(RasqSpacing.page + RasqSizes.avatarLg + RasqSpacing.md, 0, RasqSpacing.page, RasqSpacing.md),
                            child: Row(children: [
                              Expanded(child: FilledButton(onPressed: () => act(r.user.id, true), child: Text(context.l10n.usersFollowRequestAccept))),
                              const SizedBox(width: RasqSpacing.md),
                              Expanded(child: OutlinedButton(onPressed: () => act(r.user.id, false), child: Text(context.l10n.usersFollowRequestReject))),
                            ]),
                          ),
                        ]);
                      },
                    ),
          ]),
        ),
      ),
    );
  }
}
