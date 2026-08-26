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

  test('ErrorCode grammar', () {
    expect(ErrorCode.tryParse('a25')?.family, ErrorFamily.settings);
    expect(ErrorCode.tryParse('D2F')?.code, 'D2F');
    expect(ErrorCode.tryParse('404')?.isCompact, isTrue);
    expect(ErrorCode.tryParse('G00'), isNull);
    expect(ErrorCode.noTrendRequirement.display, 'Error:A25 No Trend Requirement');
  });
}
