import 'package:flutter/material.dart';

import '../tokens/sizes.dart';
import '../tokens/typography.dart';
import 'action_button.dart';

/// One registered button of an [RasqActionBar] (L2 composite `ActionBar`).
///
/// This is the **props** view of a plugin's `ActionDescriptor` + the Store's
/// `ActionState`: the bar never talks to the Store or the plugin itself
/// (原典: 「アクション済み・アクション数は SNS プラグインからの返り値を Store が保持
/// してコンポーネントに流す」). The host maps descriptor → item once per post.
@immutable
class RasqActionBarItem {
  const RasqActionBarItem({
    required this.id,
    required this.label,
    required this.icon,
    this.doneIcon,
    this.done = false,
    this.count,
    this.showCount = true,
    this.enabled = true,
    this.doneColor,
    this.iconUrl,
    this.iconText,
    this.mutedIcon = false,
    this.onTap,
    this.onLongPress,
    this.onAnchorTap,
  });

  /// タップ時にボタンの矩形が要る場合([onTap] より優先)。アクションリストの
  /// ドロップダウン展開などに使う。

  final String id;
  final String label;
  final IconData icon;

  /// Icon for the done state. Absent → the button is disabled once done
  /// (「済みアイコン未定義なら無効」), handled by [RasqActionButton].
  final IconData? doneIcon;
  final bool done;

  /// Count shown next to the icon. `null`/0 → no number.
  final int? count;

  /// `false` for actions whose plugin declares `countSource: none`.
  final bool showCount;
  final bool enabled;
  final Color? doneColor;

  /// Per-post icon override (D-017 `iconPerPost`: 予測リアクション等). When set it
  /// replaces [icon]; the host validation gate decides whether a plugin may
  /// set this at all, the bar just renders what it is given.
  final Uri? iconUrl;

  /// テキスト(絵文字)アイコン差し替え (D-040)。[iconUrl] より優先。
  final String? iconText;

  /// true = 予測表示 (D-042): アイコンをグレースケール + 70% に減光して
  /// 「まだ押していない」ことを視覚的に区別する。
  final bool mutedIcon;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Rect>? onAnchorTap;
}

/// How buttons are distributed across the bar.
enum RasqActionBarLayout {
  /// Evenly spread across the full width (投稿カードのアクションバー).
  spread,

  /// Packed to the leading edge (コンポーザーツールバー「左寄せバリエーション」).
  leading,
}

/// Action bar: plugin-registered buttons in genre-tag slots, state from the
/// Store via props. Used at the bottom of [RasqPostTile] (normal variant) and,
/// in [RasqActionBarLayout.leading] form, as the composer toolbar.
class RasqActionBar extends StatelessWidget {
  const RasqActionBar({
    super.key,
    required this.items,
    this.trailing = const [],
    this.layout = RasqActionBarLayout.spread,
  });

  final List<RasqActionBarItem> items;

  /// Extra host-owned buttons appended after the registered ones (e.g. 共有).
  final List<Widget> trailing;
  final RasqActionBarLayout layout;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[for (final i in items) _ActionBarButton(item: i), ...trailing];
    return Semantics(
      container: true,
      label: 'アクションバー',
      child: Row(
        mainAxisAlignment: layout == RasqActionBarLayout.spread ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: layout == RasqActionBarLayout.spread ? children : [for (final c in children) Padding(padding: const EdgeInsets.only(right: 4), child: c)],
      ),
    );
  }
}

class _ActionBarButton extends StatelessWidget {
  const _ActionBarButton({required this.item});
  final RasqActionBarItem item;

  @override
  Widget build(BuildContext context) {
    final count = item.count ?? 0;
    final showCount = item.showCount;
    // 予測表示の減光 (D-042): グレースケール + 70%。
    Widget mute(Widget child) => item.mutedIcon
        ? Opacity(
            opacity: 0.7,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                0.2126, 0.7152, 0.0722, 0, 0, //
                0.2126, 0.7152, 0.0722, 0, 0,
                0.2126, 0.7152, 0.0722, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: child,
            ),
          )
        : child;
    if (item.iconText != null) {
      // テキスト(絵文字)アイコン差し替え (D-040: リアクション済み/予測表示)。
      return Tooltip(
        message: item.label,
        child: Semantics(
          button: true,
          enabled: item.enabled,
          selected: item.done,
          label: item.label,
          child: InkResponse(
            onTap: item.enabled ? item.onTap : null,
            onLongPress: item.enabled ? item.onLongPress : null,
            radius: 24,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: RasqSizes.minTap, minHeight: RasqSizes.minTap),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                mute(Text(item.iconText!, style: const TextStyle(fontSize: 17))),
                if (showCount && count > 0) Padding(padding: const EdgeInsets.only(left: 4), child: Text('$count', style: RasqTypography.count)),
              ]),
            ),
          ),
        ),
      );
    }
    if (item.iconUrl != null) {
      // 投稿ごとのアイコン差し替え(SNS プラグイン配下のみ、D-017).
      return Tooltip(
        message: item.label,
        child: Semantics(
          button: true,
          enabled: item.enabled,
          selected: item.done,
          label: item.label,
          child: InkResponse(
            onTap: item.enabled ? item.onTap : null,
            onLongPress: item.enabled ? item.onLongPress : null,
            radius: 24,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: RasqSizes.minTap, minHeight: RasqSizes.minTap),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                mute(Image.network(item.iconUrl.toString(), width: 20, height: 20, errorBuilder: (_, _, _) => Icon(item.icon, size: 20))),
                if (showCount && count > 0) Padding(padding: const EdgeInsets.only(left: 4), child: Text('$count', style: RasqTypography.count)),
              ]),
            ),
          ),
        ),
      );
    }
    return Builder(
      builder: (ctx) {
        VoidCallback? onTap = item.onTap;
        final anchorTap = item.onAnchorTap;
        if (anchorTap != null) {
          onTap = () {
            final box = ctx.findRenderObject() as RenderBox;
            anchorTap(box.localToGlobal(Offset.zero) & box.size);
          };
        }
        return showCount
            ? RasqActionButton.iconCount(
                icon: item.icon,
                doneIcon: item.doneIcon,
                done: item.done,
                doneColor: item.doneColor,
                count: count,
                tooltip: item.label,
                onTap: onTap,
                onLongPress: item.onLongPress,
                enabled: item.enabled,
              )
            : RasqActionButton.icon(
                icon: item.icon,
                doneIcon: item.doneIcon,
                done: item.done,
                doneColor: item.doneColor,
                tooltip: item.label,
                onTap: onTap,
                onLongPress: item.onLongPress,
                enabled: item.enabled,
              );
      },
    );
  }
}
