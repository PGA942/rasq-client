import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../users/user_providers.dart';

/// ミュート/ブロック一覧: tabs ∨ブロック / ミュート. ∨ → ブロックしたユーザー/ワード/リスト.
class MuteBlockScreen extends ConsumerStatefulWidget {
  const MuteBlockScreen({super.key});
  @override
  ConsumerState<MuteBlockScreen> createState() => _MuteBlockScreenState();
}

class _MuteBlockScreenState extends ConsumerState<MuteBlockScreen> {
  String _blockKind = 'users';

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(overlayManagerProvider);
    final l = context.l10n;
    final tabs = [RasqTabItem(l.settingsMuteBlockBlockTab), RasqTabItem(l.settingsMuteBlockMuteTab)];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: RasqPageHeader(
          title: l.settingsMuteBlockTitle,
          onMore: () {},
          bottom: RasqTabs(
            items: tabs,
            mode: RasqTabsMode.fixed,
            onSelectedTabTap: (i, rect) async {
              if (i != 0) return;
              final pick = await manager.showDropdown<String>(id: 'block.kind', anchor: rect, dense: true, items: [
                RasqDropdownItem(l.settingsMuteBlockBlockedUsers, 'users', checked: _blockKind == 'users'),
                RasqDropdownItem(l.settingsMuteBlockBlockedWords, 'words', checked: _blockKind == 'words'),
                RasqDropdownItem(l.settingsMuteBlockBlockedLists, 'lists', checked: _blockKind == 'lists'),
              ]);
              if (pick != null) setState(() => _blockKind = pick);
            },
          ),
        ),
        body: TabBarView(children: [
          _blockKind == 'users' ? const _Users(blocked: true) : RasqEmptyView(title: _blockKind == 'words' ? l.settingsMuteBlockBlockedWords : l.settingsMuteBlockBlockedLists, hint: rasqDetail(context, l.settingsMuteBlockComingSoonHint, l.settingsMuteBlockComingSoonDetail)),
          const _Users(blocked: false),
        ]),
      ),
    );
  }
}

class _Users extends ConsumerWidget {
  const _Users({required this.blocked});
  final bool blocked;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = blocked ? ref.watch(blockedUsersProvider) : ref.watch(mutedUsersProvider);
    final s = ref.watch(currentSnsSessionProvider);
    final tokens = RasqTokens.of(context);
    final l = context.l10n;
    Future<void> undo(UserSummary u) async {
      if (s == null) return;
      blocked ? await s.setBlocked(u.id, false) : await s.setMuted(u.id, false);
      ref.invalidate(blocked ? blockedUsersProvider : mutedUsersProvider);
    }

    return page.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(blocked ? blockedUsersProvider : mutedUsersProvider), retryLabel: l.settingsMuteBlockRetryButton),
      data: (p) => p.items.isEmpty
          ? RasqEmptyView(title: blocked ? l.settingsMuteBlockNoBlockedUsers : l.settingsMuteBlockNoMutedUsers)
          : ListView.separated(
              itemCount: p.items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) => RasqUserRow(
                user: p.items[i],
                onTap: () => context.pushUser(p.items[i]),
                trailing: RasqTogglePillButton(label: blocked ? l.settingsMuteBlockBlockButton : l.settingsMuteBlockMuteButton, activeLabel: blocked ? l.settingsMuteBlockBlockingButton : l.settingsMuteBlockMutingButton, active: true, activeColor: blocked ? tokens.danger : null, onPressed: () => undo(p.items[i])),
                onMore: () {},
              ),
            ),
    );
  }
}
