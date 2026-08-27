import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

Widget wrap(Widget child) => MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: Center(child: SizedBox(width: 380, child: SingleChildScrollView(child: child)))));

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');
const author = UserSummary(id: 'u1', account: account, displayName: 'タロ・ヤマダ');
const verifiedAuthor = UserSummary(id: 'u2', account: account, displayName: '法人アカウント', verification: UserVerification.company);
final when = DateTime(2026, 8, 22, 12);

List<RasqActionBarItem> actions({VoidCallback? onReply, VoidCallback? onLong}) => [
      RasqActionBarItem(id: 'reply', label: '返信', icon: Icons.reply, count: 2, onTap: onReply),
      RasqActionBarItem(id: 'renote', label: 'リノート', icon: Icons.repeat, doneIcon: Icons.repeat_on, count: 0, onTap: () {}),
      RasqActionBarItem(id: 'reaction', label: 'リアクション', icon: Icons.add_reaction_outlined, doneIcon: Icons.add_reaction, done: true, count: 48, onTap: () {}, onLongPress: onLong),
      RasqActionBarItem(id: 'favorite', label: 'お気に入り', icon: Icons.star_border, doneIcon: Icons.star, showCount: false, onTap: () {}),
    ];

void main() {
  group('RasqPostTile', () {
    testWidgets('normal variant renders header, body, action bar and reposter line', (tester) async {
      var tapped = 0;
      Rect? moreAnchor;
      await tester.pumpWidget(wrap(RasqPostTile(
        author: author,
        createdAt: when,
        repostedBy: const UserSummary(id: 'u3', account: account, displayName: 'ダグラス'),
        content: const Text('本文です'),
        actionBar: RasqActionBar(items: actions(onReply: () => tapped++)),
        onMore: (r) => moreAnchor = r,
      )));
      expect(find.text('タロ・ヤマダ'), findsOneWidget);
      expect(find.text('@yamada'), findsOneWidget);
      expect(find.text('本文です'), findsOneWidget);
      expect(find.text('ダグラスがリノートしました'), findsOneWidget);
      expect(find.byTooltip('返信'), findsOneWidget);
      await tester.tap(find.byTooltip('返信'));
      expect(tapped, 1);
      await tester.tap(find.byTooltip('メニュー'));
      expect(moreAnchor, isNotNull);
      expect(moreAnchor!.width, greaterThan(0));
    });

    testWidgets('embedded variant hides the action bar and `…`, shows inline name', (tester) async {
      await tester.pumpWidget(wrap(RasqPostTile(
        variant: RasqPostTileVariant.embedded,
        author: author,
        createdAt: when,
        content: const Text('引用本文'),
        actionBar: RasqActionBar(items: actions()),
        onMore: (_) {},
      )));
      expect(find.text('引用本文'), findsOneWidget);
      expect(find.byTooltip('返信'), findsNothing);
      expect(find.byTooltip('メニュー'), findsNothing);
    });

    testWidgets('threadSummary shows reply count footer and no action bar', (tester) async {
      await tester.pumpWidget(wrap(RasqPostTile(
        variant: RasqPostTileVariant.threadSummary,
        author: author,
        createdAt: when,
        content: const Text('まとめ'),
        threadReplyCount: 3,
        actionBar: RasqActionBar(items: actions()),
      )));
      expect(find.text('3件の返信'), findsOneWidget);
      expect(find.byTooltip('返信'), findsNothing);
    });

    testWidgets('verified author shows the RASQ verified badge', (tester) async {
      await tester.pumpWidget(wrap(RasqPostTile(author: verifiedAuthor, createdAt: when, content: const Text('x'))));
      expect(find.byTooltip(RasqVerifiedBadge.labelOf(UserVerification.company)), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
    });
  });

  group('RasqActionBar', () {
    testWidgets('renders one button per item, count formatting, long press', (tester) async {
      var long = 0;
      await tester.pumpWidget(wrap(RasqActionBar(items: actions(onLong: () => long++), trailing: [RasqActionButton.icon(icon: Icons.ios_share, tooltip: '共有', onTap: () {})])));
      expect(find.byTooltip('返信'), findsOneWidget);
      expect(find.byTooltip('共有'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.longPress(find.byTooltip('リアクション'));
      expect(long, 1);
    });

    testWidgets('showCount=false hides the number', (tester) async {
      await tester.pumpWidget(wrap(RasqActionBar(items: [RasqActionBarItem(id: 'f', label: 'お気に入り', icon: Icons.star_border, count: 99, showCount: false)])));
      expect(find.text('99'), findsNothing);
    });
  });

  group('RasqPollWidget', () {
    const options = [PollOption(text: '猫派', votes: 3), PollOption(text: '犬派', votes: 1)];

    testWidgets('未投票 single: tapping an option votes immediately', (tester) async {
      Set<int>? voted;
      await tester.pumpWidget(wrap(RasqPollWidget(poll: const Poll(options: options), now: when, onVote: (s) => voted = s)));
      expect(find.text('投票する'), findsNothing);
      expect(find.text('4票'), findsOneWidget);
      await tester.tap(find.text('犬派'));
      expect(voted, {1});
    });

    testWidgets('未投票 multiple: checkboxes + 投票する', (tester) async {
      Set<int>? voted;
      await tester.pumpWidget(wrap(RasqPollWidget(poll: const Poll(options: options, multiple: true), now: when, onVote: (s) => voted = s)));
      final button = find.widgetWithText(FilledButton, '投票する');
      expect(tester.widget<FilledButton>(button).onPressed, isNull); // nothing selected yet
      await tester.tap(find.text('猫派'));
      await tester.tap(find.text('犬派'));
      await tester.pump();
      await tester.tap(button);
      expect(voted, {0, 1});
    });

    testWidgets('投票済み shows result bars with percent and votes', (tester) async {
      await tester.pumpWidget(wrap(RasqPollWidget(poll: const Poll(options: options, votedIndices: {0}), now: when)));
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('3票'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('期限切れ shows results even when not voted, plus 終了', (tester) async {
      await tester.pumpWidget(wrap(RasqPollWidget(poll: Poll(options: options, expiresAt: when.subtract(const Duration(hours: 1))), now: when, onVote: (_) {})));
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('終了'), findsOneWidget);
      expect(find.text('投票する'), findsNothing);
    });

    testWidgets('read-only (no onVote) keeps options but disabled', (tester) async {
      await tester.pumpWidget(wrap(RasqPollWidget(poll: const Poll(options: options), now: when)));
      await tester.tap(find.text('猫派'));
      await tester.pump();
      expect(find.text('75%'), findsNothing);
    });
  });

  testWidgets('RasqCollapsedPost: whole area taps expand', (tester) async {
    var expanded = 0;
    await tester.pumpWidget(wrap(RasqCollapsedPost(spans: const [RasqTextSpan('1\n2\n3\n4\n5')], onExpand: () => expanded++)));
    expect(find.text('展開する'), findsOneWidget);
    await tester.tapAt(tester.getTopLeft(find.byType(RasqCollapsedPost)) + const Offset(4, 4));
    expect(expanded, 1);
  });

  testWidgets('RasqContentWarning toggles the hidden body', (tester) async {
    await tester.pumpWidget(wrap(const RasqContentWarning(cw: '注釈', child: Text('隠れた本文'))));
    expect(find.text('隠れた本文'), findsNothing);
    await tester.tap(find.text('もっと見る'));
    await tester.pump();
    expect(find.text('隠れた本文'), findsOneWidget);
    expect(find.text('隠す'), findsOneWidget);
  });

  group('brand', () {
    testWidgets('RasqVerifiedBadge renders nothing for none', (tester) async {
      await tester.pumpWidget(wrap(const RasqVerifiedBadge(kind: UserVerification.none)));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('RasqLogo tints in dark theme, RasqAsTellIcon picks variant by brightness', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: RasqTheme.dark(), home: const Scaffold(body: Column(children: [RasqLogo(), RasqAsTellIcon()]))));
      final logoFilter = find.descendant(of: find.byType(RasqLogo), matching: find.byType(ColorFiltered));
      expect(logoFilter, findsOneWidget);
      final img = tester.widget<Image>(find.byType(Image).last).image as AssetImage;
      expect(img.assetName, RasqBrandAssets.asTellLight);
      await tester.pumpWidget(MaterialApp(theme: RasqTheme.light(), home: const Scaffold(body: Column(children: [RasqLogo(), RasqAsTellIcon()]))));
      await tester.pumpAndSettle(); // AnimatedTheme: brightness flips half-way through the lerp
      expect(logoFilter, findsNothing);
      final img2 = tester.widget<Image>(find.byType(Image).last).image as AssetImage;
      expect(img2.assetName, RasqBrandAssets.asTellDark);
    });
  });
}
