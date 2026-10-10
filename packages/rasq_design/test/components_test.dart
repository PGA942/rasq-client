import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

Widget wrap(Widget child) => MaterialApp(theme: RasqTheme.light(), home: Scaffold(body: Center(child: SizedBox(width: 360, child: child))));

List<MediaItem> items(int n, {bool sensitive = false}) => [
      for (var i = 0; i < n; i++) MediaItem(id: '$i', type: MediaType.image, url: Uri.parse('https://example.invalid/$i.png'), sensitive: sensitive && i == 0),
    ];

void main() {
  group('RasqMediaGrid', () {
    testWidgets('shows up to 4 tiles and a +N overflow', (tester) async {
      await tester.pumpWidget(wrap(RasqMediaGrid(items: items(6))));
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('sensitive tile is blurred until revealed, per tile', (tester) async {
      await tester.pumpWidget(wrap(RasqMediaGrid(items: items(2, sensitive: true))));
      expect(find.text('センシティブな可能性のあるメディアです'), findsOneWidget);
      await tester.tap(find.byTooltip('表示する'));
      await tester.pump();
      expect(find.text('センシティブな可能性のあるメディアです'), findsNothing);
    });
  });

  group('RasqActionButton', () {
    testWidgets('done without doneIcon is disabled', (tester) async {
      var taps = 0;
      await tester.pumpWidget(wrap(RasqActionButton.icon(icon: Icons.star_border, done: true, onTap: () => taps++)));
      await tester.tap(find.byType(InkResponse));
      expect(taps, 0);
    });

    testWidgets('count formatting', (tester) async {
      await tester.pumpWidget(wrap(Column(children: [
        RasqActionButton.iconCount(icon: Icons.repeat, count: 1200),
        RasqActionButton.iconCount(icon: Icons.repeat, count: 48),
        RasqActionButton.iconCount(icon: Icons.repeat, count: 0),
      ])));
      expect(find.text('1.2k'), findsOneWidget);
      expect(find.text('48'), findsOneWidget);
    });
  });

  test('RasqTimestamp.format', () {
    final now = DateTime(2026, 8, 22, 12, 0);
    expect(RasqTimestamp.format(now.subtract(const Duration(seconds: 30)), now: now), 'たった今');
    expect(RasqTimestamp.format(now.subtract(const Duration(minutes: 3)), now: now), '3分前');
    expect(RasqTimestamp.format(now.subtract(const Duration(hours: 5)), now: now), '5時間前');
    expect(RasqTimestamp.format(now.subtract(const Duration(days: 2)), now: now), '2日前');
    expect(RasqTimestamp.format(DateTime(2026, 2, 1), now: now), '2月1日');
    expect(RasqTimestamp.format(DateTime(2017, 2, 1), now: now), '2017年2月');
    expect(RasqTimestamp.format(now.add(const Duration(minutes: 12)), mode: RasqTimestampMode.remaining, now: now), '残り 12分');
    expect(RasqTimestamp.format(now, mode: RasqTimestampMode.absolute), '2026/08/22 12:00');
  });

  testWidgets('RasqTabs: ≥5 items becomes scrollable, capped at 10', (tester) async {
    final many = [for (var i = 0; i < 12; i++) RasqTabItem('t$i')];
    final tabs = RasqTabs(items: many);
    expect(tabs.items.length, 10);
    expect(tabs.isScrollable, isTrue);
    expect(RasqTabs(items: many.take(4).toList()).isScrollable, isFalse);
    expect(RasqTabs(items: many, mode: RasqTabsMode.fixed).items.length, 12);
  });

  testWidgets('RasqRangeSliderListTile: 範囲表示とドラッグ変更 (D-028)', (tester) async {
    RangeValues? changed;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RasqRangeSliderListTile(
          title: 'TTL',
          values: const RangeValues(5, 30),
          min: 1,
          max: 60,
          divisions: 59,
          onChanged: (v) => changed = v,
        ),
      ),
    ));
    expect(find.text('TTL'), findsOneWidget);
    expect(find.text('5〜30'), findsOneWidget);
    // 下限つまみを右へドラッグ → onChanged が呼ばれ start が上がる。
    final slider = find.byType(RangeSlider);
    final box = tester.getRect(slider);
    final startThumbX = box.left + box.width * (5 - 1) / (60 - 1);
    await tester.dragFrom(Offset(startThumbX, box.center.dy), const Offset(60, 0));
    await tester.pumpAndSettle();
    expect(changed, isNotNull);
    expect(changed!.start, greaterThan(5));
    expect(changed!.end, closeTo(30, 1));
  });

  test('RasqCustomEmoji.displayWidth: 可変幅ルール (D-040)', () {
    // アスペクト比 3 まで → 高さ固定・幅可変。
    expect(RasqCustomEmoji.displayWidth(1.0, 20), 20);
    expect(RasqCustomEmoji.displayWidth(2.5, 20), 50);
    expect(RasqCustomEmoji.displayWidth(3.0, 20), 60);
    // それ以上に横長 → 幅 2×高さで固定。
    expect(RasqCustomEmoji.displayWidth(3.1, 20), 40);
    expect(RasqCustomEmoji.displayWidth(8.0, 20), 40);
  });

  testWidgets('RasqReactionChips: 件数・+N・自分のハイライト・タップ (D-040)', (tester) async {
    String? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RasqReactionChips(
          reactions: const {'👍': 3, '🎉': 2, '😂': 1},
          myReaction: '🎉',
          maxChips: 2,
          onTap: (r) => tapped = r,
        ),
      ),
    ));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('+1'), findsOneWidget); // maxChips 超過分
    await tester.tap(find.text('3'));
    expect(tapped, '👍');
    // 自分のリアクション(🎉)タイルは枠線ハイライト。
    final highlighted = tester.widgetList<Container>(find.byType(Container)).where((c) => (c.decoration as BoxDecoration?)?.border != null);
    expect(highlighted, isNotEmpty);
  });

  test('RasqReactionChips.group: 同名の変種を合算・ローカル優先・枠なし判定 (D-041)', () {
    final groups = RasqReactionChips.group(const {':cat@remote.example:': 3, ':cat@.:': 2, '👍': 1, ':dog@remote.example:': 2}, ':cat@.:');
    final cat = groups.firstWhere((g) => g.name == 'cat');
    expect(cat.count, 5, reason: '変種は合算');
    expect(cat.representative, ':cat@.:', reason: 'ローカルサーバーの絵文字を優先');
    expect(cat.hasLocal, isTrue);
    expect(cat.mine, isTrue);
    final dog = groups.firstWhere((g) => g.name == 'dog');
    expect(dog.hasLocal, isFalse, reason: 'ローカルに無い → 枠なし表示・タップ不可');
    expect(groups.firstWhere((g) => g.name == '👍').hasLocal, isTrue);
  });

  test('ErrorCode grammar', () {
    expect(ErrorCode.tryParse('a25')?.family, ErrorFamily.settings);
    expect(ErrorCode.tryParse('D2F')?.code, 'D2F');
    expect(ErrorCode.tryParse('404')?.isCompact, isTrue);
    expect(ErrorCode.tryParse('G00'), isNull);
    expect(ErrorCode.noTrendRequirement.display, 'Error:A25 No Trend Requirement');
  });
  // セキュリティ確認 2026-10-09 の [11]: 制限のある面では、プラグインが選んだ URL をリダイレクトの各ホップで確かめる読み方で読む。
  group('media redirects', () {
    final allowed = Uri.parse('https://cdn.allowed.example/a.png');
    List<ImageProvider> images(WidgetTester tester) => [for (final i in tester.widgetList<Image>(find.byType(Image))) i.image];
    Widget all() => Column(children: [
          RasqAvatar(imageUrl: allowed),
          RasqCustomEmoji(url: allowed, fallbackText: ':a:', height: 20),
          RasqMediaGrid(items: [MediaItem(id: 'm', type: MediaType.image, url: allowed)]),
        ]);

    testWidgets('plugin surfaces: avatar / emoji / media use the per-hop loader', (tester) async {
      await tester.pumpWidget(wrap(RasqMediaPolicyScope(policy: RasqMediaPolicy.plugin(hostAllowed: (h) => h == 'cdn.allowed.example'), child: all())));
      await tester.pump();
      final got = images(tester);
      expect(got, hasLength(3));
      expect(got, everyElement(isA<RasqPolicyNetworkImage>()));
    });

    testWidgets('host screens and host-given URLs keep the normal loader', (tester) async {
      await tester.pumpWidget(wrap(all()));
      await tester.pump();
      expect(images(tester), everyElement(isA<NetworkImage>()));
      await tester.pumpWidget(wrap(RasqMediaPolicyScope(policy: RasqMediaPolicy.plugin(allowedUrls: {allowed.toString()}), child: all())));
      await tester.pump();
      expect(images(tester), everyElement(isA<NetworkImage>()));
    });
  });
}
