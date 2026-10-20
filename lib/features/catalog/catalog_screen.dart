import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/providers.dart';
import '../../mock/mock_data.dart';
import '../../shell/headers.dart';
import '../../text/inline_spans.dart';
import '../onboarding/onboarding_previews.dart' show postTileSampleRrl;
import '../../l10n/l10n.dart';

/// Component catalog (Widgetbook-lite). Dev-only; lists every L2 atomic
/// component with its variants plus Overlay Manager presets.
///
/// 文言 (D-526): 見出し・説明・オーバーレイの見本の文は部品 catalog から引く。部品の中に入れる見本の中身(投稿の本文・
/// 名前・投票の選択肢・タブ / ボタン / 行の見本のラベル)は、実際の画面ではサーバーや利用者の中身にあたるので
/// 訳さずに `// l10n-ignore` で残す。
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(overlayManagerProvider);
    final tokens = RasqTokens.of(context);
    final now = DateTime.now();
    final posts = MockData.timeline(MockData.accountMisskey);
    final postSpans = [for (final p in posts) InlineSpans.parse(p.body)];
    final demoActions = [
      RasqActionBarItem(id: 'reply', label: '返信', icon: Icons.subdirectory_arrow_left, count: 2, onTap: () {}), // l10n-ignore
      RasqActionBarItem(id: 'renote', label: 'リノート', icon: Icons.repeat, doneIcon: Icons.repeat_on, count: 12, onTap: () {}), // l10n-ignore
      RasqActionBarItem(id: 'reaction', label: 'リアクション', icon: Icons.add_reaction_outlined, doneIcon: Icons.add_reaction, done: true, doneColor: tokens.live, count: 48, onTap: () {}), // l10n-ignore
      RasqActionBarItem(id: 'favorite', label: 'お気に入り', icon: Icons.star_border, doneIcon: Icons.star, showCount: false, onTap: () {}), // l10n-ignore
    ];
    return Scaffold(
      appBar: RasqPageHeader(title: context.l10n.catalogTitle),
      body: ListView(padding: const EdgeInsets.only(bottom: 48), children: [
        RasqSectionHeader(title: context.l10n.catalogSectionBrand, topMargin: 0),
        _row([
          const RasqLogo(height: 36),
          const RasqBrandIcon(size: 32),
          const RasqVerifiedBadge(kind: UserVerification.person, size: 24),
          const RasqVerifiedBadge(kind: UserVerification.company, size: 24),
          const RasqVerifiedBadge(kind: UserVerification.government, size: 24),
          const RasqAsTellIcon(size: 28),
          const RasqAsTellIcon(size: 28, selected: false),
        ]),
        RasqSectionHeader(title: context.l10n.catalogSectionPostTile),
        RasqPostTile(
          author: posts[0].author,
          createdAt: posts[0].createdAt,
          repostedBy: MockData.tivard,
          content: RasqRichText(postSpans[0], style: RasqTypography.body),
          actionBar: RasqActionBar(items: demoActions, trailing: [RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {})]), // l10n-ignore
          onMore: (_) {},
          onTap: () {},
        ),
        const Divider(),
        RasqPostTile(
          author: posts[1].author,
          createdAt: posts[1].createdAt,
          content: RasqRichText(postSpans[1], style: RasqTypography.body),
          poll: RasqPollWidget(poll: posts[1].poll!, onVote: (_) {}),
          actionBar: RasqActionBar(items: demoActions),
          onTap: () {},
        ),
        const Divider(),
        RasqPostTile(
          author: posts[2].author,
          createdAt: posts[2].createdAt,
          content: RasqContentWarning(cw: '誕生日の話', child: RasqRichText(postSpans[2], style: RasqTypography.body)), // l10n-ignore
          media: RasqMediaGrid(items: posts[2].media),
          linkBanner: RasqLinkBanner(url: Uri.parse('https://example.com/article'), title: 'リンク先バナー', description: 'OGP のタイトルと説明', onTap: () {}), // l10n-ignore
          actionBar: RasqActionBar(items: demoActions),
          onTap: () {},
        ),
        RasqSectionHeader(title: context.l10n.catalogSectionPostTileEmbedded),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: RasqPostTile(variant: RasqPostTileVariant.embedded, author: posts[0].author, createdAt: posts[0].createdAt, content: RasqRichText(postSpans[0], style: RasqTypography.bodySmall, maxLines: 4, overflow: TextOverflow.ellipsis), onTap: () {}),
        ),
        RasqPostTile(variant: RasqPostTileVariant.threadSummary, author: posts[2].author, createdAt: posts[2].createdAt, content: RasqRichText(postSpans[2], style: RasqTypography.body, maxLines: 2, overflow: TextOverflow.ellipsis), threadReplyCount: 3, onTap: () {}),
        RasqSectionHeader(title: context.l10n.catalogSectionCollapsed),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: RasqCollapsedPost(spans: InlineSpans.parse('既読の長い投稿は先頭数行だけ表示します。\n2行目\n3行目\n4行目は隠れます\n5行目'), onExpand: () {}), // l10n-ignore
        ),
        RasqSectionHeader(title: context.l10n.catalogSectionPoll),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(children: [
            RasqPollWidget(poll: const Poll(options: [PollOption(text: '猫派', votes: 3), PollOption(text: '犬派', votes: 2)]), onVote: (_) {}), // l10n-ignore
            const SizedBox(height: RasqSpacing.md),
            RasqPollWidget(poll: Poll(options: const [PollOption(text: 'A', votes: 1), PollOption(text: 'B'), PollOption(text: 'C', votes: 4)], multiple: true, expiresAt: now.add(const Duration(hours: 3))), onVote: (_) {}),
            const SizedBox(height: RasqSpacing.md),
            RasqPollWidget(poll: const Poll(options: [PollOption(text: '猫派', votes: 30), PollOption(text: '犬派', votes: 20), PollOption(text: 'その他', votes: 5)], votedIndices: {0})), // l10n-ignore
            const SizedBox(height: RasqSpacing.md),
            RasqPollWidget(poll: Poll(options: const [PollOption(text: '賛成', votes: 7), PollOption(text: '反対', votes: 3)], expiresAt: now.subtract(const Duration(days: 1)))), // l10n-ignore
          ]),
        ),
        RasqSectionHeader(title: context.l10n.catalogSectionActionBar),
        Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: RasqActionBar(items: demoActions, trailing: [RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {})])), // l10n-ignore
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: RasqActionBar(layout: RasqActionBarLayout.leading, items: [
            RasqActionBarItem(id: 'image', label: '画像', icon: Icons.image_outlined, showCount: false, onTap: () {}), // l10n-ignore
            RasqActionBarItem(id: 'emoji', label: '絵文字', icon: Icons.emoji_emotions_outlined, showCount: false, onTap: () {}), // l10n-ignore
            RasqActionBarItem(id: 'poll', label: '投票', icon: Icons.poll_outlined, showCount: false, onTap: () {}), // l10n-ignore
            RasqActionBarItem(id: 'cw', label: '注釈', icon: Icons.visibility_off_outlined, showCount: false, onTap: () {}), // l10n-ignore
          ]),
        ),
        // post-tile.rrl.json = WASM の SNS プラグインが出す snapshot (PROTOCOL.md §3.1)。オンボーディングの見本 (D-405) と同じもの。
        RasqSectionHeader(title: context.l10n.catalogSectionRrl),
        RrlRenderer(
          node: RrlDocument.fromSnapshot((jsonDecode(postTileSampleRrl) as Map).cast<String, Object?>()).root,
          host: RrlHost(
            // ホストが同梱した見本の木 (D-407)。
            mediaPolicy: RasqMediaPolicy.unrestricted,
            instanceScope: 'rasq.official.misskey:misskey:misskey.io:yamada:0.1.0:catalog',
            scope: RrlScope({
              'post': {
                'id': 'p1',
                'key': 'misskey:misskey.io:yamada:p1',
                'author': {'displayName': 'ダグラス', 'handle': 'username', 'kind': 'misskey', 'instance': 'misskey.io', 'avatarUrl': 'https://picsum.photos/seed/douglas/200'}, // l10n-ignore
                'createdAt': now.subtract(const Duration(minutes: 3)).toIso8601String(),
                'bodyRSL': 'WASM プラグインが出した snapshot を #RRL レンダラーが描画しています', // l10n-ignore
                'contentWarning': null,
                'media': [
                  {'id': 'm1', 'type': 'image', 'url': 'https://picsum.photos/seed/rrl1/600/400'},
                  {'id': 'm2', 'type': 'image', 'url': 'https://picsum.photos/seed/rrl2/600/400'},
                ],
                'poll': null,
                'quote': null,
              },
              'actions': [
                {'id': 'reply', 'label': '返信', 'icon': 'subdirectory_arrow_left'}, // l10n-ignore
                {'id': 'renote', 'label': 'リノート', 'icon': 'repeat', 'doneIcon': 'repeat_on'}, // l10n-ignore
                {'id': 'reaction', 'label': 'リアクション', 'icon': 'add_reaction_outlined', 'doneIcon': 'add_reaction'}, // l10n-ignore
              ],
              'actionStates': {
                'misskey:misskey.io:yamada:p1': {
                  'renote': {'done': true, 'count': 12},
                  'reply': {'count': 2},
                  'reaction': {'count': 48},
                },
              },
            }),
            rslParser: InlineSpans.parse,
            onEvent: (nodeId, kind, {fn, payload = const {}}) => manager.showAlert(
              id: 'catalog.rrl.event',
              title: 'RRL event',
              message: 'nodeId: $nodeId\nkind: $kind${fn == null ? '' : '\nfn: $fn'}${payload.isEmpty ? '' : '\npayload: $payload'}',
              confirmText: 'OK',
            ),
          ),
        ),
        const RasqSectionHeader(title: 'MFM transform (rsl-span: \$[fn args …])'),
        Padding(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: RasqRichText(
            InlineSpans.parse(r'$[tada 🎉] $[spin.speed=1.5s $[x2 回る]] **太字** $[rainbow 虹色] $[jelly ぷるぷる] $[blur ぼかし] $[fg.color=ff5555 赤字] $[rotate.deg=15 傾き] $[unknown_fn 未知fnは中身のみ]'), // l10n-ignore
            style: RasqTypography.body,
          ),
        ),
        const RasqSectionHeader(title: 'Avatar / Badge'),
        _row([
          RasqAvatar(imageUrl: MockData.me.avatarUrl, fallbackLabel: 'タ'), // l10n-ignore
          RasqAvatar(imageUrl: MockData.douglas.avatarUrl, presence: UserPresence.inVc),
          RasqAvatar(fallbackLabel: 'TiV', presence: UserPresence.live, size: 48),
          RasqAvatar(fallbackLabel: 'アイコン', size: 48, badge: const RasqBadge(count: 3)), // l10n-ignore
          RasqGroupAvatar(users: [MockData.douglas, MockData.tivard, MockData.jikoAppeal], overflowCount: 2),
          const RasqBadged(badge: RasqBadge(count: 1), child: Icon(Icons.notifications_none, size: 28)),
          const RasqBadge(count: 120),
          const RasqBadge(dot: true),
        ]),
        const RasqSectionHeader(title: 'Pills / SNS'),
        _row([
          const RasqPill(label: 'フォローされています'), // l10n-ignore
          const RasqPill(label: 'ブロック中', color: RasqColors.danger), // l10n-ignore
          const RasqPill(label: 'フォロー中', outlined: true), // l10n-ignore
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
            RasqHashtagSpan('打上会', onTap: () {}), // l10n-ignore
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
          RasqActionButton.icon(icon: Icons.reply, tooltip: '返信', onTap: () {}), // l10n-ignore
          RasqActionButton.iconCount(icon: Icons.repeat, count: 1200, onTap: () {}),
          RasqActionButton.iconCount(icon: Icons.favorite_border, doneIcon: Icons.favorite, done: true, doneColor: tokens.live, count: 48, onTap: () {}),
          RasqActionButton.icon(icon: Icons.emoji_emotions_outlined, done: true, onTap: () {}), // done without doneIcon → disabled
          RasqActionButton.text(label: 'フォロー中', done: true, onTap: () {}), // l10n-ignore
          RasqActionButton.iconText(icon: Icons.settings_outlined, label: '設定', onTap: () {}), // l10n-ignore
        ]),
        const RasqSectionHeader(title: 'Buttons'),
        _row([
          RasqTogglePillButton(label: 'フォロー', activeLabel: 'フォロー中', active: true, onPressed: () {}), // l10n-ignore
          RasqTogglePillButton(label: 'フォロー', active: false, onPressed: () {}), // l10n-ignore
          RasqTogglePillButton(label: 'ブロック中', active: true, activeColor: tokens.danger, onPressed: () {}), // l10n-ignore
          SizedBox(width: 160, child: RasqGradientButton(label: '参加', onPressed: () {})), // l10n-ignore
          const SizedBox(width: 120, child: RasqGradientButton(label: '参加', enabled: false)), // l10n-ignore
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
        RasqListTile(title: 'プラグインの構成', onTap: () {}), // l10n-ignore
        RasqListTile(title: 'BlueSky Plugin', subtitle: 'RASQ Official', leading: const Icon(Icons.extension_outlined), trailing: const RasqBrandIcon(size: 18, semanticsLabel: 'RASQ Official'), onTap: () {}),
        const _SwitchDemo(),
        RasqValueListTile(title: 'インターフェースの表示サイズ', value: '標準', onTap: () {}), // l10n-ignore
        RasqWarningListTile(title: 'トレンドの指向性/刺激性', onTap: () {}), // l10n-ignore
        RasqDestructiveListTile(title: '@yamada_tar_gzからログアウト', onTap: () {}), // l10n-ignore
        const RasqSectionHeader(title: 'Tabs (≤4 fill / ≥5 scroll, max 10)'),
        DefaultTabController(length: 3, child: RasqTabs(items: const [RasqTabItem('ノート'), RasqTabItem('引用'), RasqTabItem('メディア')])), // l10n-ignore
        DefaultTabController(
          length: 6,
          child: RasqTabs(items: const [RasqTabItem('ノート'), RasqTabItem('引用'), RasqTabItem('メディア'), RasqTabItem('クリップ/Play'), RasqTabItem('VC'), RasqTabItem('プラグインA')]), // l10n-ignore
        ),
        const RasqSectionHeader(title: 'Inputs'),
        const Padding(
          padding: EdgeInsets.all(RasqSpacing.page),
          child: Column(children: [RasqInput(hintText: 'ユーザー名'), SizedBox(height: 8), RasqInput(hintText: 'パスワード', obscureText: true, suffix: Icon(Icons.visibility_outlined)), SizedBox(height: 12), RasqSearchBar(hintText: '検索')]), // l10n-ignore
        ),
        const RasqSectionHeader(title: 'Feedback'),
        RasqErrorView(code: ErrorCode.noTrendRequirement, onRetry: () {}),
        RasqErrorView(code: ErrorCode.timeout),
        RasqErrorView(code: ErrorCode.relationalTimelineBroken, compact: true),
        Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: RasqInlineErrorTile(code: ErrorCode.unauthorized.copyWith(message: 'misskey.socialでログインすると見れるかもしれません'))), // l10n-ignore
        const RasqEmptyView(title: 'なんにもないようです', hint: 'ワードを変えると見つかるかもしれません'), // l10n-ignore
        const RasqLoading(),
        const RasqSectionHeader(title: 'Overlay Manager'),
        _row([
          FilledButton.tonal(
            onPressed: () => manager.showBottomSheet(
              id: 'catalog.sheet',
              title: context.l10n.catalogSheetTitle,
              confirmText: context.l10n.catalogSheetConfirm,
              builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Text(context.l10n.catalogSheetBody)),
            ),
            child: const Text('BottomSheet'),
          ),
          FilledButton.tonal(
            onPressed: () => manager.showAlert(id: 'catalog.alert', title: context.l10n.catalogAlertTitle, message: context.l10n.catalogAlertMessage, confirmText: context.l10n.catalogAlertConfirm, cancelText: context.l10n.catalogAlertCancel, destructive: true),
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
                  items: [
                    RasqDropdownItem(context.l10n.catalogDropdownAsc, 'asc', checked: true),
                    RasqDropdownItem(context.l10n.catalogDropdownDesc, 'desc'),
                    RasqDropdownItem(context.l10n.catalogDropdownDefault, 'default'),
                    RasqDropdownItem(context.l10n.catalogDropdownReport, 'report', destructive: true),
                  ],
                );
              },
              child: const Text('Dropdown'),
            ),
          ),
          FilledButton.tonal(
            onPressed: () => manager.showBottomSheet(
              id: 'catalog.sheet2',
              title: context.l10n.catalogSheetModalTitle,
              builder: (ctx) => Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(onPressed: () => manager.showAlert(id: 'catalog.alert2', title: context.l10n.catalogModalTitle, message: context.l10n.catalogModalMessage, confirmText: 'OK'), child: Text(context.l10n.catalogModalOpen)),
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
  Widget build(BuildContext context) => RasqSwitchListTile(title: 'リアクションを通知する', value: _on, onChanged: (v) => setState(() => _on = v)); // l10n-ignore
}
