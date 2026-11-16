import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/error_journal.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/app/router.dart';
import 'package:rasq_client/features/settings/bug_report_screen.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'support/fakes.dart';

/// バグレポート (D-570): 端末に残す例外の記録(起動ごとに最初の 1 件 + 直近)、個人の情報を伏せる、画面とコピー。
void main() {
  group('伏せる', () {
    test('引用された文(投稿の本文など)は中身を伏せ、プログラムの名前らしいものは残す', () {
      expect(redactReportText('Text("ひみつの本文です")'), 'Text("…")');
      expect(redactReportText("caption: 'hello my friend'"), "caption: '…'");
      expect(redactReportText('「今日のごはん」'), '「…」');
      expect(redactReportText("'!_debugDuringDeviceUpdate': is not true"), "'!_debugDuringDeviceUpdate': is not true");
      expect(redactReportText("'package:flutter/src/rendering/mouse_tracker.dart'"), "'package:flutter/src/rendering/mouse_tracker.dart'");
    });

    test('URL はスキームだけ、ハンドル / メール / トークン / パスは伏せる', () {
      final r = redactReportText('GET https://misskey.example/api/notes?i=abcdef0123456789abcdef0123456789#frag failed for @alice@misskey.example (mail bob@example.com)');
      expect(r, isNot(contains('misskey.example')));
      expect(r, isNot(contains('abcdef0123')));
      expect(r, isNot(contains('alice')));
      expect(r, isNot(contains('bob@')));
      expect(r, contains('https://…'));
      expect(r, contains('@…'));
      expect(r, contains('<email>'));
      expect(redactReportText('Authorization: Bearer xyz.secret'), isNot(contains('secret')));
      expect(redactReportText('token=Zx9_aB3dEf6Gh1Jk2Lm4Np5Qr7'), 'token=<redacted>');
      expect(redactReportText('jwt eyJhbGciOi.eyJzdWIiOiIx.c2lnbmF0dXJl here'), 'jwt <token> here');
      expect(redactReportText('key 0123456789abcdef0123456789abcdef end'), 'key <redacted> end');
      expect(redactReportText('#0 main (file:///Users/someone/dev/app/lib/main.dart:3:1)'), '#0 main (file://~/dev/app/lib/main.dart:3:1)');
      expect(redactReportText('/private/var/mobile/Containers/Data/Application/1A2B3C4D-0000-1111-2222-333344445555/Documents/x'), '<app>/Documents/x');
      // ソースの場所 / 長い識別子は残す(どこで落ちたか分からなくなる)。
      expect(redactReportText('#1 State.build (package:rasq_client/features/media/media_viewer_screen.dart:123:4)'), '#1 State.build (package:rasq_client/features/media/media_viewer_screen.dart:123:4)');
      expect(redactReportText('_RenderDeferredLayoutBoxWithLongName#987f8'), '_RenderDeferredLayoutBoxWithLongName#987f8');
    });
  });

  group('記録', () {
    ErrorRecord rec(String summary, {int sec = 0}) => ErrorRecord(at: DateTime.utc(2026, 11, 16, 10, 0, sec), source: 'flutter', type: 'StateError', summary: summary);

    test('起動ごとに最初の 1 件は上書きせず、直近は新しい順に 5 件、起動は 3 回まで。書き出し / 読み込みで同じ', () {
      var j = const ErrorJournal();
      final a = DateTime.utc(2026, 11, 16, 9);
      for (var i = 0; i < 8; i++) {
        j = j.add(a, rec('e$i', sec: i));
      }
      expect(j.latest!.first.summary, 'e0');
      expect([for (final r in j.latest!.recent) r.summary], ['e7', 'e6', 'e5', 'e4', 'e3']);
      expect(j.latest!.count, 8);
      for (var k = 1; k <= 3; k++) {
        j = j.add(a.add(Duration(hours: k)), rec('launch$k'));
      }
      expect(j.launches.length, ErrorJournal.launchLimit);
      expect(j.latest!.first.summary, 'launch3');
      final back = ErrorJournal.decode(j.encode());
      expect(back.encode(), j.encode());
      expect(ErrorJournal.decode('{broken').isEmpty, isTrue);
    });

    test('最初の 1 件はすぐ書き、続く分はまとめて書く。読み込む前に来た分も残す。消去で空に', () async {
      final store = MemoryErrorJournalStore(ErrorJournal(launches: [LaunchErrors(startedAt: DateTime.utc(2026, 11, 15), first: rec('old'))]).encode());
      final r = ErrorJournalRecorder(store, launchedAt: DateTime.utc(2026, 11, 16), screenSize: () => '1024×1366 @2x');
      r.record(rec('before load'));
      await r.load();
      await r.flush();
      expect(r.journal.launches.map((l) => l.first.summary), ['before load', 'old']);
      final saves = store.saves;
      r.record(rec('second'));
      r.record(rec('third'));
      await r.flush();
      expect(store.saves, saves + 1, reason: '続く分はまとめて 1 回');
      expect(ErrorJournal.decode(store.data).latest!.recent.map((x) => x.summary), ['third', 'second']);
      await r.clear();
      expect(store.data, isNull);
      expect(r.journal.isEmpty, isTrue);
      r.dispose();
    });

    testWidgets('組み立ての例外: 型 / 伏せた要約 / 失敗した部品の経路 / スタックの先頭 / 画面の大きさ', (tester) async {
      final r = ErrorJournalRecorder(MemoryErrorJournalStore(), screenSize: () => '390×844 @3x');
      await r.load();
      final prev = FlutterError.onError;
      FlutterError.onError = r.recordFlutterError;
      await tester.pumpWidget(const Directionality(textDirection: TextDirection.ltr, child: Center(child: _Boom())));
      FlutterError.onError = prev;
      final first = r.journal.latest!.first;
      expect(first.type, 'StateError');
      expect(first.summary, contains('本文'));
      expect(first.summary, isNot(contains('ひみつ')));
      expect(first.summary, isNot(contains('zz9Kq')));
      expect(first.context, contains('_Boom'));
      expect(first.widgetPath.join('\n'), contains('_Boom'));
      expect(first.stack, isNotEmpty);
      expect(first.stack.join('\n'), isNot(contains('/Users/')));
      expect(first.screen, '390×844 @3x');
      r.dispose();
    });

    test('install: 前の受け手もそのまま呼ぶ(動きは変えない)', () {
      final prevFlutter = FlutterError.onError;
      final prevPlatform = PlatformDispatcher.instance.onError;
      final seen = <String>[];
      FlutterError.onError = (d) => seen.add('flutter');
      PlatformDispatcher.instance.onError = (e, s) {
        seen.add('platform');
        return true;
      };
      final r = ErrorJournalRecorder(MemoryErrorJournalStore());
      try {
        r.install();
        FlutterError.onError!(FlutterErrorDetails(exception: StateError('x'), stack: StackTrace.current));
        final handled = PlatformDispatcher.instance.onError!(ArgumentError('y'), StackTrace.current);
        expect(seen, ['flutter', 'platform']);
        expect(handled, isTrue, reason: '前の受け手の答えを返す');
        expect(r.journal.latest!.count, 2);
        expect(r.journal.latest!.recent.single.source, 'platform');
      } finally {
        FlutterError.onError = prevFlutter;
        PlatformDispatcher.instance.onError = prevPlatform;
        r.dispose();
      }
    });

    test('同じ起動で上限を超えたら記録しない(毎フレームの例外で重くならない)。最初の 1 件は残る', () {
      final r = ErrorJournalRecorder(MemoryErrorJournalStore());
      for (var i = 0; i < ErrorJournalRecorder.perLaunchLimit + 50; i++) {
        r.recordError(StateError('e$i'), StackTrace.empty);
      }
      expect(r.journal.latest!.count, ErrorJournalRecorder.perLaunchLimit);
      expect(r.journal.latest!.first.summary, contains('e0'));
      r.dispose();
    });

    test('アプリの版は pubspec の version と同じ', () {
      final v = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
      expect(rasqAppVersion, v);
    });
  });

  group('画面', () {
    Future<void> reveal(WidgetTester tester, Key key) => tester.scrollUntilVisible(find.byKey(key), 200, scrollable: find.descendant(of: find.byType(BugReportScreen), matching: find.byType(Scrollable)).first);
    Future<(ProviderContainer, ErrorJournalRecorder)> pump(WidgetTester tester, {bool withError = true}) async {
      tester.view.physicalSize = const Size(1170, 2532); // 390×844 @3x(スクリーンショットの大きさ)
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final store = MemoryErrorJournalStore();
      final recorder = ErrorJournalRecorder(store, launchedAt: DateTime(2026, 11, 16, 9), screenSize: () => '1024×1366 @2x');
      await recorder.load();
      if (withError) {
        recorder.record(ErrorRecord(
          at: DateTime(2026, 11, 16, 9, 1),
          source: 'flutter',
          type: 'FlutterError',
          library: 'widgets library',
          summary: redactReportText('Cannot hit test a render box that has never been laid out. Text("ひみつの本文") @alice@misskey.example'),
          context: 'building _ViewerPanel',
          widgetPath: const ['_ViewerPanel ← ListView ← FowPanel ← Positioned ← Stack ← OverlayHost ← …'],
          stack: const ['#0 RenderBox.hitTest (package:flutter/src/rendering/box.dart:2920:11)', '#1 _RenderTheaterMixin.hitTestChildren (package:flutter/src/widgets/overlay.dart:1145:22)'],
          screen: '1024×1366 @2x',
        ));
        for (var i = 0; i < 3; i++) {
          recorder.record(ErrorRecord(at: DateTime(2026, 11, 16, 9, 2, i), source: 'flutter', type: 'AssertionError', summary: "'!_debugDuringDeviceUpdate': is not true."));
        }
      }
      final storage = MemorySessionStorage({
        SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
      });
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline));
      await tester.pumpWidget(ProviderScope(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        errorJournalProvider.overrideWithValue(recorder),
        bugReportDeviceModelProvider.overrideWith((ref) async => 'iPad (iPad14,5)'),
      ], child: const RasqApp()));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      addTearDown(recorder.dispose);
      return (c, recorder);
    }

    testWidgets('設定 → RASQ について に「バグレポート」の行(ヘルプのすぐ下)', (tester) async {
      final (c, _) = await pump(tester, withError: false);
      c.read(routerProvider).push('/settings/section/about');
      await tester.pumpAndSettle();
      final row = find.text('バグレポート');
      expect(row, findsOneWidget);
      expect(tester.getRect(row).top, greaterThan(tester.getRect(find.text('ヘルプ')).top));
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byType(BugReportScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('bugReport.empty')), findsOneWidget);
    });

    testWidgets('要点が 1〜2 枚に収まる: 端末 → 最初の例外(型 / 要約 / 場所 / 経路 / スタック)→ 直近。全文はコピーで、個人の情報は入らない', (tester) async {
      final (c, _) = await pump(tester);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      c.read(routerProvider).push(Routes.settingsBugReport);
      await tester.pumpAndSettle();
      // 端末(版 / 端末の型 / 画面)。
      expect(find.text('$rasqAppVersion (debug)'), findsOneWidget);
      expect(find.text('iPad (iPad14,5)'), findsOneWidget);
      // 最初の例外。
      final first = find.byKey(bugReportFirstKey);
      expect(find.descendant(of: first, matching: find.textContaining('FlutterError')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.textContaining('Cannot hit test a render box')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.text('building _ViewerPanel')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.textContaining('_ViewerPanel ← ListView')), findsOneWidget);
      expect(find.descendant(of: first, matching: find.textContaining('RenderBox.hitTest')), findsOneWidget);
      expect(find.textContaining('ひみつ'), findsNothing);
      expect(find.textContaining('alice'), findsNothing);
      // 2 枚(画面の高さ 844 × 2)に、最初の例外の終わりまで入る。
      expect(tester.getRect(first).bottom, lessThan(844 * 2));
      // 全文をコピー。
      await reveal(tester, bugReportCopyKey);
      await tester.tap(find.byKey(bugReportCopyKey));
      await tester.pumpAndSettle();
      expect(copied, isNotNull);
      expect(copied, contains('RASQ bug report'));
      expect(copied, contains('-- FIRST'));
      expect(copied, contains('device: iPad (iPad14,5)'));
      expect(copied, contains('recent 3'));
      expect(copied, isNot(contains('ひみつ')));
      expect(copied, isNot(contains('alice')));
      expect(copied, isNot(contains('misskey.example')));
      expect(find.text('バグレポートの全文をコピーしました'), findsOneWidget);
    });

    testWidgets('消去は確かめてから(やめれば残る)', (tester) async {
      final (c, recorder) = await pump(tester);
      c.read(routerProvider).push(Routes.settingsBugReport);
      await tester.pumpAndSettle();
      await reveal(tester, bugReportClearKey);
      await tester.tap(find.byKey(bugReportClearKey));
      await tester.pumpAndSettle();
      expect(find.text('記録した例外を消しますか?'), findsOneWidget);
      await tester.tap(find.text('キャンセル').last);
      await tester.pumpAndSettle();
      expect(recorder.journal.isEmpty, isFalse);
      await tester.tap(find.byKey(bugReportClearKey));
      await tester.pumpAndSettle();
      await tester.tap(find.text('消去').last);
      await tester.pumpAndSettle();
      expect(recorder.journal.isEmpty, isTrue);
      expect(find.byKey(const ValueKey('bugReport.empty')), findsOneWidget);
    });
  });

  test('全文: 記録が無くても端末の情報だけは出る', () {
    const env = BugReportEnv(appVersion: '0.1.0+1', buildMode: 'release', os: 'ios 27.2.1', device: 'iPad (iPad14,5)', screen: '1024×1366 @2x', locale: 'ja');
    final text = buildBugReportText(const ErrorJournal(), env, now: DateTime(2026, 11, 16));
    expect(text, contains('app: 0.1.0+1 (release)'));
    expect(text, contains('(no errors recorded)'));
    expect(bugReportFileName(DateTime(2026, 11, 16, 9, 5, 7)), 'rasq-bug-report-20261116-090507.txt');
  });
}

class _Boom extends StatelessWidget {
  const _Boom();
  @override
  Widget build(BuildContext context) => throw StateError('本文: "ひみつの本文" token=zz9Kq3Lm5Np7Rs1Tv3Wx5Yz7Ab9Cd');
}
