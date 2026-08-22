import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../mock/mock_data.dart';
import '../../shell/headers.dart';

/// Component catalog (Widgetbook-lite). Dev-only; lists every L2 atomic
/// component with its variants plus Overlay Manager presets.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(overlayManagerProvider);
    final tokens = RasqTokens.of(context);
    final now = DateTime.now();
    return Scaffold(
      appBar: const RasqPageHeader(title: 'コンポーネントカタログ'),
      body: ListView(padding: const EdgeInsets.only(bottom: 48), children: [
        const RasqSectionHeader(title: 'Avatar / Badge', topMargin: 0),
        _row([
          RasqAvatar(imageUrl: MockData.me.avatarUrl, fallbackLabel: 'タ'),
          RasqAvatar(imageUrl: MockData.douglas.avatarUrl, presence: UserPresence.inVc),
          RasqAvatar(fallbackLabel: 'TiV', presence: UserPresence.live, size: 48),
          RasqAvatar(fallbackLabel: 'アイコン', size: 48, badge: const RasqBadge(count: 3)),
          RasqGroupAvatar(users: [MockData.douglas, MockData.tivard, MockData.jikoAppeal], overflowCount: 2),
          const RasqBadged(badge: RasqBadge(count: 1), child: Icon(Icons.notifications_none, size: 28)),
          const RasqBadge(count: 120),
          const RasqBadge(dot: true),
        ]),
        const RasqSectionHeader(title: 'Pills / SNS'),
        _row([
          const RasqPill(label: 'フォローされています'),
          const RasqPill(label: 'ブロック中', color: RasqColors.danger),
          const RasqPill(label: 'フォロー中', outlined: true),
          RasqSnsPill(account: MockData.accountBluesky),
          RasqSnsPill(account: MockData.accountMisskey),
        ]),
        const RasqSectionHeader(title: 'RichText (RSL spans)'),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: RasqRichText([
            const RasqTextSpan('Happy birthday to me, '),
            RasqEmojiSpan(shortcode: 'cake', url: Uri.parse('https://picsum.photos/seed/cake/40')),
            const RasqTextSpan(' '),
            RasqMentionSpan('username', onTap: () {}),
            const RasqTextSpan(' '),
            RasqHashtagSpan('打上会', onTap: () {}),
            const RasqTextSpan(' '),
            RasqLinkSpan('amzn.jp/19f253fc', url: Uri.parse('https://amzn.jp/19f253fc'), onTap: () {}),
            const RasqTextSpan(' bold', bold: true),
            const RasqTextSpan(' strike', strike: true),
          ], style: RasqTypography.body),
        ),
        const RasqSectionHeader(title: 'MediaGrid 1 / 2 / 3 / 4+ (sensitive per tile)'),
        for (final n in [1, 2, 3, 5])
          Padding(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0), child: RasqMediaGrid(items: MockData.media(n, sensitiveFirst: n != 2))),
        const RasqSectionHeader(title: 'ActionButton (4 variants, done / disabled)'),
        _row([
          RasqActionButton.icon(icon: Icons.reply, tooltip: '返信', onTap: () {}),
          RasqActionButton.iconCount(icon: Icons.repeat, count: 1200, onTap: () {}),
          RasqActionButton.iconCount(icon: Icons.favorite_border, doneIcon: Icons.favorite, done: true, doneColor: tokens.live, count: 48, onTap: () {}),
          RasqActionButton.icon(icon: Icons.emoji_emotions_outlined, done: true, onTap: () {}), // done without doneIcon → disabled
          RasqActionButton.text(label: 'フォロー中', done: true, onTap: () {}),
          RasqActionButton.iconText(icon: Icons.settings_outlined, label: '設定', onTap: () {}),
        ]),
        const RasqSectionHeader(title: 'Buttons'),
        _row([
          RasqTogglePillButton(label: 'フォロー', activeLabel: 'フォロー中', active: true, onPressed: () {}),
          RasqTogglePillButton(label: 'フォロー', active: false, onPressed: () {}),
          RasqTogglePillButton(label: 'ブロック中', active: true, activeColor: tokens.danger, onPressed: () {}),
          SizedBox(width: 160, child: RasqGradientButton(label: '参加', onPressed: () {})),
          const SizedBox(width: 120, child: RasqGradientButton(label: '参加', enabled: false)),
        ]),
        const RasqSectionHeader(title: 'Timestamp'),
        _row([
          RasqTimestamp(now.subtract(const Duration(minutes: 3))),
          RasqTimestamp(now.subtract(const Duration(hours: 5))),
          RasqTimestamp(now.subtract(const Duration(days: 40))),
          RasqTimestamp(now.add(const Duration(minutes: 12, seconds: 25)), mode: RasqTimestampMode.remaining),
          RasqTimestamp(now, mode: RasqTimestampMode.absolute),
        ]),
        const RasqSectionHeader(title: 'ListTile family'),
        RasqListTile(title: 'プラグインの構成', onTap: () {}),
        RasqListTile(title: 'BlueSky Plugin', subtitle: 'RASQ Official', leading: const Icon(Icons.extension_outlined), trailing: const Icon(Icons.verified, color: Color(0xFF34C759), size: 18), onTap: () {}),
        const _SwitchDemo(),
        RasqValueListTile(title: 'インターフェースの表示サイズ', value: '標準', onTap: () {}),
        RasqWarningListTile(title: 'トレンドの指向性/刺激性', onTap: () {}),
        RasqDestructiveListTile(title: '@yamada_tar_gzからログアウト', onTap: () {}),
        const RasqSectionHeader(title: 'Tabs (≤4 fill / ≥5 scroll, max 10)'),
        DefaultTabController(length: 3, child: RasqTabs(items: const [RasqTabItem('ノート'), RasqTabItem('引用'), RasqTabItem('メディア')])),
        DefaultTabController(
          length: 6,
          child: RasqTabs(items: const [RasqTabItem('ノート'), RasqTabItem('引用'), RasqTabItem('メディア'), RasqTabItem('クリップ/Play'), RasqTabItem('VC'), RasqTabItem('プラグインA')]),
        ),
        const RasqSectionHeader(title: 'Inputs'),
        const Padding(
          padding: EdgeInsets.all(RasqSpacing.page),
          child: Column(children: [RasqInput(hintText: 'ユーザー名'), SizedBox(height: 8), RasqInput(hintText: 'パスワード', obscureText: true, suffix: Icon(Icons.visibility_outlined)), SizedBox(height: 12), RasqSearchBar(hintText: '検索')]),
        ),
        const RasqSectionHeader(title: 'Feedback'),
        RasqErrorView(code: ErrorCode.noTrendRequirement, onRetry: () {}),
        RasqErrorView(code: ErrorCode.timeout),
        RasqErrorView(code: ErrorCode.relationalTimelineBroken, compact: true),
        Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: RasqInlineErrorTile(code: ErrorCode.unauthorized.copyWith(message: 'misskey.socialでログインすると見れるかもしれません'))),
        const RasqEmptyView(title: 'なんにもないようです', hint: 'ワードを変えると見つかるかもしれません'),
        const RasqLoading(),
        const RasqSectionHeader(title: 'Overlay Manager'),
        _row([
          FilledButton.tonal(
            onPressed: () => manager.showBottomSheet(
              id: 'catalog.sheet',
              title: 'ボトムシート',
              confirmText: '決定',
              builder: (_) => const Padding(padding: EdgeInsets.all(24), child: Text('背面タップ or キャンセルで変更破棄。\nこの上にモーダルは割り込めます。')),
            ),
            child: const Text('BottomSheet'),
          ),
          FilledButton.tonal(
            onPressed: () => manager.showAlert(id: 'catalog.alert', title: 'ブロックしますか？', message: '背面タップは無効(明示的操作必須)', confirmText: 'ブロック', cancelText: 'キャンセル', destructive: true),
            child: const Text('Modal'),
          ),
          Builder(
            builder: (ctx) => FilledButton.tonal(
              onPressed: () {
                final box = ctx.findRenderObject() as RenderBox;
                final rect = box.localToGlobal(Offset.zero) & box.size;
                manager.showDropdown<String>(
                  id: 'catalog.dropdown',
                  anchor: rect,
                  items: const [
                    RasqDropdownItem('昇順', 'asc', checked: true),
                    RasqDropdownItem('降順', 'desc'),
                    RasqDropdownItem('デフォルト', 'default'),
                    RasqDropdownItem('通報', 'report', destructive: true),
                  ],
                );
              },
              child: const Text('Dropdown'),
            ),
          ),
          FilledButton.tonal(
            onPressed: () => manager.showBottomSheet(
              id: 'catalog.sheet2',
              title: 'シート→モーダル割り込み',
              builder: (ctx) => Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(onPressed: () => manager.showAlert(id: 'catalog.alert2', title: 'モーダル', message: 'シートは維持されます', confirmText: 'OK'), child: const Text('モーダルを出す')),
              ),
            ),
            child: const Text('Sheet + Modal'),
          ),
        ]),
      ]),
    );
  }

  static Widget _row(List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
        child: Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: children),
      );
}

class _SwitchDemo extends StatefulWidget {
  const _SwitchDemo();
  @override
  State<_SwitchDemo> createState() => _SwitchDemoState();
}

class _SwitchDemoState extends State<_SwitchDemo> {
  bool _on = true;
  @override
  Widget build(BuildContext context) => RasqSwitchListTile(title: 'リアクションを通知する', value: _on, onChanged: (v) => setState(() => _on = v));
}
