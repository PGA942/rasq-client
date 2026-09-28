import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
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
    final tabs = [const RasqTabItem('ブロック'), const RasqTabItem('ミュート')];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: RasqPageHeader(
          title: 'ミュート/ブロック',
          onMore: () {},
          bottom: RasqTabs(
            items: tabs,
            mode: RasqTabsMode.fixed,
            onSelectedTabTap: (i, rect) async {
              if (i != 0) return;
              final pick = await manager.showDropdown<String>(id: 'block.kind', anchor: rect, dense: true, items: [
                RasqDropdownItem('ブロックしたユーザー', 'users', checked: _blockKind == 'users'),
                RasqDropdownItem('ブロックしたワード', 'words', checked: _blockKind == 'words'),
                RasqDropdownItem('ブロックしたリスト', 'lists', checked: _blockKind == 'lists'),
              ]);
              if (pick != null) setState(() => _blockKind = pick);
            },
          ),
        ),
        body: TabBarView(children: [
          _blockKind == 'users' ? const _Users(blocked: true) : RasqEmptyView(title: _blockKind == 'words' ? 'ブロックしたワード' : 'ブロックしたリスト', hint: rasqDetail(context, '準備中です', 'ワード/リストのブロックは M2 後半')),
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
    Future<void> undo(UserSummary u) async {
      if (s == null) return;
      blocked ? await s.setBlocked(u.id, false) : await s.setMuted(u.id, false);
      ref.invalidate(blocked ? blockedUsersProvider : mutedUsersProvider);
    }

    return page.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(blocked ? blockedUsersProvider : mutedUsersProvider), retryLabel: '再読み込み'),
      data: (p) => p.items.isEmpty
          ? RasqEmptyView(title: blocked ? 'ブロックしたユーザーはいません' : 'ミュートしたユーザーはいません')
          : ListView.separated(
              itemCount: p.items.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, i) => RasqUserRow(
                user: p.items[i],
                onTap: () => context.pushUser(p.items[i]),
                trailing: RasqTogglePillButton(label: blocked ? 'ブロック' : 'ミュート', activeLabel: blocked ? 'ブロック中' : 'ミュート中', active: true, activeColor: blocked ? tokens.danger : null, onPressed: () => undo(p.items[i])),
                onMore: () {},
              ),
            ),
    );
  }
}
