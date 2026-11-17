import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart' show Routes, routerProvider;
import '../../l10n/l10n.dart';
import '../settings/settings_dsl.dart';

/// 添付の「4 枚まで」(D-589)。
///
/// 添付の並びの既定の向きは横(`RasqMediaArrangement.auto` の 5 枚以上は横に送る)。横に送る並び
/// (`RasqMediaArrangement.horizontalAxis`)では、既定では 4 枚までの制限を掛けない(全部を横に送る)。
/// [mediaLimitFourKey] をオンにすると、横に送る並びでも 4 枚まで(4 枚目に「+N」)。縦の並びはいつも 4 枚まで。
/// スレッドの展開(`PostRow.showAllMedia`)はいつも全部。
///
/// 値は TL の表示の設定(`appearance.timeline`)に置く: [mediaLimitFourKey] = 制限(既定オフ)、
/// [mediaLimitButtonKey] = 投稿のアクションバーの切り替えボタンを出すか(既定は出す)。
const mediaLimitFourKey = 'mediaLimitFour';
const mediaLimitButtonKey = 'mediaLimitButton';

/// 横に送る並びでも 4 枚までにするか(既定オフ = 全部)。
final mediaLimitFourProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(timelineDisplayArea)).value?[mediaLimitFourKey] == true);

/// 投稿のアクションバーに「4 枚まで」の切り替えボタンを出すか(既定は出す)。
final mediaLimitButtonProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(timelineDisplayArea)).value?[mediaLimitButtonKey] != false);

Future<void> setMediaLimitFour(WidgetRef ref, bool on) => ref.read(settingsAreaProvider(timelineDisplayArea).notifier).set(mediaLimitFourKey, on);
Future<void> setMediaLimitButton(WidgetRef ref, bool on) => ref.read(settingsAreaProvider(timelineDisplayArea).notifier).set(mediaLimitButtonKey, on);

/// 見せる枚数: 全部を見せる面([showAll])か、横に送る並びで制限を掛けていなければ全部。ほかは 4 枚。
int mediaMaxVisible({required int count, required RasqMediaArrangement arrangement, required bool showAll, required bool limitFour}) =>
    showAll || (arrangement.horizontalAxis && !limitFour) ? count : 4;

/// 切り替えボタンが意味を持つ投稿か: 5 枚以上で、横に送る並びで、全部を見せる面ではない。
bool mediaLimitApplies({required int count, required RasqMediaArrangement arrangement, required bool showAll}) =>
    count > 4 && arrangement.horizontalAxis && !showAll;

/// 投稿のアクションバー(右端の共有の左)の「4 枚まで」の切り替え。押すと端末全体の設定を切り替える。
/// 長押しで「4 枚までにする / 全部を横に送る」と「アクションバーを編集」(設定 → プラグインボタン、ボタンを出すかもそこで選べる)。
class MediaLimitToggleButton extends ConsumerWidget {
  const MediaLimitToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(mediaLimitFourProvider);
    final l = context.l10n;
    return Builder(
      builder: (ctx) => RasqActionButton.icon(
        key: const ValueKey('post.mediaLimit'),
        icon: Icons.filter_4_outlined,
        doneIcon: Icons.filter_4,
        done: on,
        tooltip: on ? l.homeMediaLimitOnTooltip : l.homeMediaLimitOffTooltip,
        onTap: () => setMediaLimitFour(ref, !on),
        onLongPress: () => _menu(ctx, ref, on),
      ),
    );
  }

  Future<void> _menu(BuildContext context, WidgetRef ref, bool on) async {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final l = context.l10n;
    final pick = await ref.read(overlayManagerProvider).showDropdown<String>(
      id: 'post.mediaLimit.menu',
      anchor: box.localToGlobal(Offset.zero) & box.size,
      dense: true,
      items: [
        RasqDropdownItem(l.homeMediaLimitMenuLimit, 'limit', checked: on),
        RasqDropdownItem(l.homeMediaLimitMenuAll, 'all', checked: !on),
        RasqDropdownItem(l.homeMediaLimitMenuEditBar, 'edit'),
      ],
    );
    switch (pick) {
      case 'limit':
        await setMediaLimitFour(ref, true);
      case 'all':
        await setMediaLimitFour(ref, false);
      case 'edit':
        await ref.read(routerProvider).push(Routes.actionBarPlugins);
    }
  }
}
