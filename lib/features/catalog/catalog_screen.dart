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

/// Component catalog (Widgetbook-lite). Dev-only; lists every L2 atomic
/// component with its variants plus Overlay Manager presets.
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
      RasqActionBarItem(id: 'reply', label: '返信', icon: Icons.subdirectory_arrow_left, count: 2, onTap: () {}),
      RasqActionBarItem(id: 'renote', label: 'リノート', icon: Icons.repeat, doneIcon: Icons.repeat_on, count: 12, onTap: () {}),
      RasqActionBarItem(id: 'reaction', label: 'リアクション', icon: Icons.add_reaction_outlined, doneIcon: Icons.add_reaction, done: true, doneColor: tokens.live, count: 48, onTap: () {}),
      RasqActionBarItem(id: 'favorite', label: 'お気に入り', icon: Icons.star_border, doneIcon: Icons.star, showCount: false, onTap: () {}),
    ];
    return Scaffold(
      appBar: const RasqPageHeader(title: 'コンポーネントカタログ'),
      body: ListView(padding: const EdgeInsets.only(bottom: 48), children: [
        const RasqSectionHeader(title: 'Brand (特殊なコンポーネント置き場)', topMargin: 0),
        _row([
          const RasqLogo(height: 36),
          const RasqBrandIcon(size: 32),
          const RasqVerifiedBadge(kind: UserVerification.person, size: 24),
          const RasqVerifiedBadge(kind: UserVerification.company, size: 24),
          const RasqVerifiedBadge(kind: UserVerification.government, size: 24),
          const RasqAsTellIcon(size: 28),
          const RasqAsTellIcon(size: 28, selected: false),
        ]),
        const RasqSectionHeader(title: 'PostTile — 通常 (アクションバー / 投票 / メディア)'),
        RasqPostTile(
          author: posts[0].author,
          createdAt: posts[0].createdAt,
          repostedBy: MockData.tivard,
          content: RasqRichText(postSpans[0], style: RasqTypography.body),
          actionBar: RasqActionBar(items: demoActions, trailing: [RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {})]),
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
          content: RasqContentWarning(cw: '誕生日の話', child: RasqRichText(postSpans[2], style: RasqTypography.body)),
          media: RasqMediaGrid(items: posts[2].media),
          linkBanner: RasqLinkBanner(url: Uri.parse('https://example.com/article'), title: 'リンク先バナー', description: 'OGP のタイトルと説明', onTap: () {}),
          actionBar: RasqActionBar(items: demoActions),
          onTap: () {},
        ),
        const RasqSectionHeader(title: 'PostTile — 埋め込み (引用 / リアクション表示 / タイマー通知) & スレッドまとめ'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: RasqPostTile(variant: RasqPostTileVariant.embedded, author: posts[0].author, createdAt: posts[0].createdAt, content: RasqRichText(postSpans[0], style: RasqTypography.bodySmall, maxLines: 4, overflow: TextOverflow.ellipsis), onTap: () {}),
        ),
        RasqPostTile(variant: RasqPostTileVariant.threadSummary, author: posts[2].author, createdAt: posts[2].createdAt, content: RasqRichText(postSpans[2], style: RasqTypography.body, maxLines: 2, overflow: TextOverflow.ellipsis), threadReplyCount: 3, onTap: () {}),
        const RasqSectionHeader(title: 'CollapsedPost (省略表示: 既読 + 長文)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: RasqCollapsedPost(spans: InlineSpans.parse('既読の長い投稿は先頭数行だけ表示します。\n2行目\n3行目\n4行目は隠れます\n5行目'), onExpand: () {}),
        ),
        const RasqSectionHeader(title: 'PollWidget (未投票 単一 / 複数, 投票済み, 期限切れ)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(children: [
            RasqPollWidget(poll: const Poll(options: [PollOption(text: '猫派', votes: 3), PollOption(text: '犬派', votes: 2)]), onVote: (_) {}),
            const SizedBox(height: RasqSpacing.md),
            RasqPollWidget(poll: Poll(options: const [PollOption(text: 'A', votes: 1), PollOption(text: 'B'), PollOption(text: 'C', votes: 4)], multiple: true, expiresAt: now.add(const Duration(hours: 3))), onVote: (_) {}),
            const SizedBox(height: RasqSpacing.md),
            RasqPollWidget(poll: const Poll(options: [PollOption(text: '猫派', votes: 30), PollOption(text: '犬派', votes: 20), PollOption(text: 'その他', votes: 5)], votedIndices: {0})),
            const SizedBox(height: RasqSpacing.md),
            RasqPollWidget(poll: Poll(options: const [PollOption(text: '賛成', votes: 7), PollOption(text: '反対', votes: 3)], expiresAt: now.subtract(const Duration(days: 1)))),
          ]),
        ),
        const RasqSectionHeader(title: 'ActionBar (spread / leading = コンポーザーツールバー)'),
        Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: RasqActionBar(items: demoActions, trailing: [RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {})])),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: RasqActionBar(layout: RasqActionBarLayout.leading, items: [
            RasqActionBarItem(id: 'image', label: '画像', icon: Icons.image_outlined, showCount: false, onTap: () {}),
            RasqActionBarItem(id: 'emoji', label: '絵文字', icon: Icons.emoji_emotions_outlined, showCount: false, onTap: () {}),
            RasqActionBarItem(id: 'poll', label: '投票', icon: Icons.poll_outlined, showCount: false, onTap: () {}),
            RasqActionBarItem(id: 'cw', label: '注釈', icon: Icons.visibility_off_outlined, showCount: false, onTap: () {}),
          ]),
        ),
        const RasqSectionHeader(title: 'RRL レンダラー (M3: post-tile.rrl.json → L1/L2/L3)'),
        RrlRenderer(
          node: RrlDocument.fromSnapshot((jsonDecode(_postTileRrl) as Map).cast<String, Object?>()).root,
          host: RrlHost(
            instanceScope: 'rasq.official.misskey:misskey:misskey.io:yamada:0.1.0:catalog',
            scope: RrlScope({
              'post': {
                'id': 'p1',
                'key': 'misskey:misskey.io:yamada:p1',
                'author': {'displayName': 'ダグラス', 'handle': 'username', 'kind': 'misskey', 'instance': 'misskey.io', 'avatarUrl': 'https://picsum.photos/seed/douglas/200'},
                'createdAt': now.subtract(const Duration(minutes: 3)).toIso8601String(),
                'bodyRSL': 'WASM プラグインが出した snapshot を #RRL レンダラーが描画しています',
                'contentWarning': null,
                'media': [
                  {'id': 'm1', 'type': 'image', 'url': 'https://picsum.photos/seed/rrl1/600/400'},
                  {'id': 'm2', 'type': 'image', 'url': 'https://picsum.photos/seed/rrl2/600/400'},
                ],
                'poll': null,
                'quote': null,
              },
              'actions': [
                {'id': 'reply', 'label': '返信', 'icon': 'subdirectory_arrow_left'},
                {'id': 'renote', 'label': 'リノート', 'icon': 'repeat', 'doneIcon': 'repeat_on'},
                {'id': 'reaction', 'label': 'リアクション', 'icon': 'add_reaction_outlined', 'doneIcon': 'add_reaction'},
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
        const RasqSectionHeader(title: 'Avatar / Badge'),
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
        RasqListTile(title: 'BlueSky Plugin', subtitle: 'RASQ Official', leading: const Icon(Icons.extension_outlined), trailing: const RasqBrandIcon(size: 18, semanticsLabel: 'RASQ Official'), onTap: () {}),
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

/// `rasq-sdk-sample/examples/post-tile.rrl.json` — the wire-format snapshot a
/// WASM SNS plugin emits (PROTOCOL.md §3.1), rendered live above.
const _postTileRrl = '''
{
  "schema": "rasq.boundary/1",
  "scope": "rasq.official.misskey:misskey:misskey.io:yamada:0.1.0:tl-home",
  "type": "snapshot",
  "rev": 1,
  "root": {
    "t": "PostTile", "k": "post-{{post.id}}", "role": "contentBody",
    "p": { "post": "\$.post", "variant": "normal" },
    "c": [
      { "t": "Avatar", "k": "avatar", "p": { "user": "\$.post.author" }, "on": { "tap": "openUser" } },
      { "t": "Row", "k": "header", "c": [
        { "t": "RichText", "k": "name", "tag": "user_name", "p": { "source": "\$.post.author.displayName" } },
        { "t": "Text", "k": "handle", "tag": "user_handle", "p": { "text": "\$.post.author.handle" } },
        { "t": "Timestamp", "k": "time", "tag": "time", "p": { "time": "\$.post.createdAt" } }
      ]},
      { "t": "If", "k": "cw?", "p": { "cond": "\$.post.contentWarning" }, "c": [
        { "t": "Text", "k": "cw", "tag": "cw", "p": { "text": "\$.post.contentWarning" } }
      ]},
      { "t": "RichText", "k": "body", "tag": "main_text", "p": { "source": "\$.post.bodyRSL" } },
      { "t": "MediaGrid", "k": "media", "p": { "items": "\$.post.media" }, "on": { "tap": "openViewer" } },
      { "t": "If", "k": "poll?", "p": { "cond": "\$.post.poll" }, "c": [
        { "t": "PollWidget", "k": "poll", "tag": "vote", "p": { "poll": "\$.post.poll" }, "on": { "confirm": "vote" } }
      ]},
      { "t": "ActionBar", "k": "actions", "role": "actionBar", "p": { "actions": "\$.actions", "states": "\$.actionStates[post.key]" }, "on": { "tap": "performAction", "longPress": "pickReaction" } }
    ]
  }
}
''';

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
