import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/media/media_viewer_screen.dart';
import 'package:rasq_client/shell/sidebar.dart';
import 'package:rasq_design/rasq_design.dart';

/// 全画面表示のフリーズの調査 (D-552、ユーザー報告 2026-11-16: 「全画面表示にしたらグレーアウトし、何か(サイドバーのアカウント関連?)を
/// 操作するとフリーズ」)。実セッション(キーチェーン)+ 実ネットワーク + 入れてあるプラグインのまま、TL のメディアを全画面で開き、
/// サイドバー / アカウントの操作 / 戻るを重ねる。例外と、開いている重ね(FOW / サイドバー / バリア)を集めて最後に出す。
/// 報告は iPadOS 27.2(タッチ): `flutter test integration_test/viewer_freeze_test.dart -d <iPad の id>`(macOS なら `-d macos`)。
Future<void> settle(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(Duration(milliseconds: ms ~/ 6));
  }
}

Future<bool> waitFor(WidgetTester tester, Finder f, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('TL のメディアを全画面で開いて、サイドバー / アカウントの操作 / 戻るを重ねても固まらない(実データ)', (tester) async {
    final collected = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (details) => collected.add('--- ${details.toString().split('\n').take(40).join('\n')}');
    addTearDown(() => FlutterError.onError = prev);
    void drain(String where) {
      final e = tester.takeException();
      if (e != null) collected.add('--- [takeException @$where] $e');
    }

    await tester.pumpWidget(const ProviderScope(child: RasqApp()));
    expect(await waitFor(tester, find.bySemanticsLabel('サイドバーを開く'), seconds: 40), isTrue, reason: 'キーチェーンのセッションでログインできること');
    await settle(tester);
    drain('boot');
    final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
    final manager = c.read(overlayManagerProvider);
    String overlays() => manager.entries.map((e) => '${e.id}[${e.layer.name}/${e.effectiveBarrierBehavior.name}${manager.isFowSuspended(e) ? '/suspended' : ''}]').join(', ');
    String scrims() => find
        .byWidgetPredicate((w) => w is ColoredBox && w.color.a > 0.2 && w.color.a < 0.8 && w.color.r < 0.1 && w.color.g < 0.1)
        .evaluate()
        .map((e) => '${(e.renderObject as RenderBox?)?.size}')
        .join(' ');

    // メディア付きの投稿が出るまで TL を送る。
    final grid = find.byType(RasqMediaGrid);
    for (var i = 0; i < 25 && grid.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500), warnIfMissed: false);
      await settle(tester, 300);
    }
    expect(grid, findsWidgets, reason: 'TL にメディア付きの投稿があること');
    await tester.ensureVisible(grid.first);
    await settle(tester);
    final tile = find.descendant(of: grid.first, matching: find.byType(GestureDetector)).first;
    await tester.tap(tile, warnIfMissed: false);
    final opened = await waitFor(tester, find.byType(MediaViewerScreen), seconds: 10);
    await settle(tester, 1500);
    drain('open');
    debugPrint('VIEWER opened=$opened overlays=[${overlays()}] scrims=[${scrims()}]');

    // 「グレーアウト」の正体を記録: スクリム / バリアの有無。
    final stamp = Stopwatch()..start();
    Future<void> step(String name, Future<void> Function() run) async {
      stamp.reset();
      await run();
      await settle(tester);
      drain(name);
      debugPrint('STEP $name ${stamp.elapsedMilliseconds}ms overlays=[${overlays()}] scrims=[${scrims()}] viewer=${find.byType(MediaViewerScreen).evaluate().isNotEmpty}');
    }

    await step('tap.topLeft', () async => tester.tapAt(const Offset(28, 60)));
    if (find.byType(MediaViewerScreen).evaluate().isEmpty) {
      await tester.tap(tile, warnIfMissed: false);
      await waitFor(tester, find.byType(MediaViewerScreen), seconds: 10);
      await settle(tester, 1500);
    }
    await step('sidebar.open', () async => RasqSidebar.open(manager));
    await step('sidebar.more', () async => tester.tap(find.descendant(of: find.byType(RasqSidebar), matching: find.byIcon(Icons.more_horiz)).first, warnIfMissed: false));
    await step('escape', () async => manager.handleBack());
    await step('sidebar.reopen', () async => RasqSidebar.open(manager));
    await step('sidebar.bundleTile', () async => tester.tap(find.descendant(of: find.byType(RasqSidebar), matching: find.byType(RasqAvatar)).first, warnIfMissed: false));
    await step('viewer.swipe', () async => tester.drag(find.byType(PageView).first, const Offset(-400, 0), warnIfMissed: false));
    await step('viewer.back', () async {
      final back = find.byTooltip('戻る');
      if (back.evaluate().isNotEmpty) await tester.tap(back.last, warnIfMissed: false);
    });
    await step('home.after', () async {});

    debugPrint('==== collected ${collected.length} ====');
    for (final e in collected) {
      debugPrint(e);
    }
    expect(collected, isEmpty);
  });
}
