import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:rasq_client/app/app.dart';

/// 実セッション(キーチェーン)+実ネットワークでのナビゲーション往復。
/// リストページ / クリップページの再発エラーの一次例外をフルスタックで
/// 捕まえる調査用。例外は収集して最後にまとめて報告する。
/// `flutter test integration_test -d macos`
Future<void> settle(WidgetTester tester, [int ms = 400]) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(Duration(milliseconds: ms ~/ 4));
  }
}

Future<bool> waitFor(WidgetTester tester, Finder f, {int seconds = 15}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('リスト⇄クリップ往復ストレス(実データ)', (tester) async {
    final collected = <String>[];
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      collected.add('--- ${details.toString().split('\n').take(40).join('\n')}');
      // テストバインディングには渡さない(収集して続行)。
    };
    addTearDown(() => FlutterError.onError = prev);
    void drain(String where) {
      final e = tester.takeException();
      if (e != null) collected.add('--- [takeException @$where] $e');
    }

    await tester.pumpWidget(const ProviderScope(child: RasqApp()));
    final loggedIn = await waitFor(tester, find.bySemanticsLabel('サイドバーを開く'), seconds: 30);
    expect(loggedIn, isTrue, reason: 'キーチェーンのセッションでログインできること');
    await settle(tester);
    drain('boot');

    Future<void> back(String where) async {
      final b = find.byTooltip('戻る');
      if (b.evaluate().isNotEmpty) {
        await tester.tap(b.last, warnIfMissed: false);
        await settle(tester);
      }
      drain(where);
    }

    for (var round = 0; round < 2; round++) {
      await tester.tap(find.bySemanticsLabel('サイドバーを開く').first, warnIfMissed: false);
      await settle(tester);
      await tester.tap(find.text('リスト').last, warnIfMissed: false);
      await waitFor(tester, find.text('リスト・クリップを検索'), seconds: 10);
      await settle(tester, 800);
      drain('lists r$round');

      final clipRow = find.textContaining('クリップ');
      if (clipRow.evaluate().isNotEmpty) {
        await tester.tap(clipRow.first, warnIfMissed: false);
        await settle(tester, 1600);
        drain('clip page r$round');
        await back('clip back r$round');
      }

      final anyList = find.byIcon(Icons.list_alt_outlined);
      if (anyList.evaluate().isNotEmpty) {
        await tester.tap(anyList.first, warnIfMissed: false);
        await settle(tester, 1600);
        final postsTab = find.text('投稿');
        if (postsTab.evaluate().isNotEmpty) {
          await tester.tap(postsTab.last, warnIfMissed: false);
          await settle(tester, 1600);
        }
        drain('list detail r$round');
        await back('list detail back r$round');
      }
      await back('lists back r$round');
    }

    debugPrint('===== collected ${collected.length} exception(s) =====');
    for (final c in collected) {
      debugPrint(c);
    }
    debugPrint('===== end =====');
  });
}
