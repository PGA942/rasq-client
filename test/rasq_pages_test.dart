import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/custom/custom_client.dart';
import 'package:rasq_client/features/custom/custom_profile.dart';
import 'package:rasq_client/features/profile/rasq_pages.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/text/inline_spans.dart';
import 'package:rasq_design/rasq_design.dart';

/// D-446: RASQ のページ(Markdown ページの表示 / 編集、HTML 風の MFM)。
class _FakeApi implements RasqPagesApi {
  final published = <String, ({String title, String body})>{};
  final images = <String>[];
  @override
  Uri? get base => null;
  @override
  Future<RasqMdPage> publishMdPage(String id, {required String title, required String body}) async {
    published[id] = (title: title, body: body);
    return RasqMdPage(id: id, title: title, body: body);
  }

  @override
  Future<Uri> uploadImage(List<int> bytes, String contentType) async {
    images.add(contentType);
    return Uri.parse('https://central.test/api/v1/profile-images/i${images.length}');
  }

  @override
  Future<List<RasqMdPageInfo>> mdPages(String handle) async => const [RasqMdPageInfo(id: 'pg1', title: '自己紹介')];

  @override
  Future<List<RasqSideloadPage>> sideloadPages(String handle) async => const [RasqSideloadPage(id: 'sl1', pluginId: 'me.game', version: '0.1.0', name: 'ミニゲーム')];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('HTML 風の MFM (InlineSpans, htmlFns)', () {
    test('タグ → 変形のスパン(属性 = 引数、入れ子、ルビ)。htmlFns が無ければ文字のまま', () {
      final spin = InlineSpans.parse('<spin speed="1s" left>回る</spin>', htmlFns: true).single as RasqTransformSpan;
      expect((spin.fn, spin.args['speed'], spin.args['left']), ('spin', '1s', true));
      final nested = InlineSpans.parse('<x2><flip h>a<flip v>b</flip></flip></x2>', htmlFns: true).single as RasqTransformSpan;
      expect(nested.fn, 'x2');
      final flip = nested.children.single as RasqTransformSpan;
      expect((flip.fn, flip.args['h']), ('flip', true));
      expect(flip.children.whereType<RasqTransformSpan>().single.args['v'], true, reason: '同じタグの入れ子');
      final ruby = InlineSpans.parse('<ruby>本<rt>ほん</rt></ruby>', htmlFns: true).single as RasqTransformSpan;
      expect((ruby.fn, ruby.args['rt'], (ruby.children.single as RasqTextSpan).text), ('ruby', 'ほん', '本'));
      final fg = InlineSpans.parse('<fg color="f00">赤</fg>', htmlFns: true).single as RasqTransformSpan;
      expect(fg.args['color'], 'f00');
      expect(InlineSpans.parse('<spin>回る</spin>').whereType<RasqTransformSpan>(), isEmpty, reason: '投稿は今までどおり');
      expect(InlineSpans.parse('<spin>閉じていない', htmlFns: true).whereType<RasqTransformSpan>(), isEmpty);
    });
  });

  test('Markdown のブロック: 見出し / 箇条書き / 画像 / 区切り / コード / 段落', () {
    final b = RasqMarkdownView.blocks('# 題\n\n本文 @alice #花火\n続き\n\n- いち\n1. に\n\n![猫](https://x.test/c.png)\n---\n```\ncode\n```');
    expect([for (final x in b) x.kind], ['h1', 'p', 'li', 'li', 'img', 'hr', 'code']);
    expect(b[1].text, '本文 @alice #花火\n続き');
    expect((b[3].extra, b[4].extra), ('1.', 'https://x.test/c.png'));
    expect(b.last.text, 'code');
  });

  Future<(ProviderContainer, _FakeApi)> pumpEditor(WidgetTester tester, {RasqMdPage? published}) async {
    final api = _FakeApi();
    final storage = MemorySessionStorage({});
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        rasqPagesApiProvider.overrideWithValue(api),
        rasqPageImagePickerProvider.overrideWithValue(() async => (bytes: Uint8List.fromList([1, 2, 3]), contentType: 'image/png')),
      ],
      child: MaterialApp(home: Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(builder: (_) => RasqMdPageEditorScreen(id: 'pg1', published: published))), child: const Text('open')))))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (ProviderScope.containerOf(tester.element(find.byType(RasqMdPageEditorScreen))), api);
  }

  testWidgets('編集: 書くと端末に下書き、道具で MFM のタグ、画像は上げて貼る、プレビュー、「公開」で Central へ送り下書きを消す', (tester) async {
    final (c, api) = await pumpEditor(tester);
    await tester.enterText(find.byKey(const ValueKey('rasqPage.md.title')), 'わたしのページ');
    await tester.enterText(find.byKey(const ValueKey('rasqPage.md.body')), 'こんにちは');
    await tester.tap(find.byKey(const ValueKey('rasqPage.md.tool.中央')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rasqPage.md.tool.image')));
    await tester.pumpAndSettle();
    final body = tester.widget<TextField>(find.byKey(const ValueKey('rasqPage.md.body'))).controller!.text;
    // 道具はタグで包み、カーソルをタグの中に置く(続けて貼った画像はタグの中)。
    expect(body, 'こんにちは<center>\n![画像](https://central.test/api/v1/profile-images/i1)\n</center>');
    expect(api.images, ['image/png']);
    await tester.pump(const Duration(seconds: 1));
    expect(c.read(rasqPageDraftsProvider)['pg1']?.title, 'わたしのページ', reason: '端末の下書き');
    await tester.tap(find.byKey(const ValueKey('rasqPage.md.preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rasqPage.md.previewView')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rasqPage.md.publish')));
    await tester.pumpAndSettle();
    expect(api.published['pg1']?.title, 'わたしのページ');
    expect(c.read(rasqPageDraftsProvider).containsKey('pg1'), isFalse, reason: '公開したら下書きは消す');
    expect(find.byType(RasqMdPageEditorScreen), findsNothing);
    final raw = await c.read(sessionStorageProvider).read('$rasqPageDraftsArea.v1');
    expect((jsonDecode(raw!) as Map)['pg1'], isNull);
    expect(c.read(settingsAreaProvider(rasqPageDraftsArea)).value?['pg1'], isNull);
  });

  testWidgets('編集: 公開済みのページは中身から始まる(下書きがあれば下書きが先)', (tester) async {
    await pumpEditor(tester, published: const RasqMdPage(id: 'pg1', title: '前の題', body: '前の本文'));
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rasqPage.md.title'))).controller!.text, '前の題');
    expect(tester.widget<TextField>(find.byKey(const ValueKey('rasqPage.md.body'))).controller!.text, '前の本文');
  });

  Future<void> pumpTab(WidgetTester tester, {required bool isMine, Map<String, String> seed = const {}}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage(seed)),
        customSessionClientProvider.overrideWithValue(MockCustomSessionClient()),
        rasqPagesApiProvider.overrideWithValue(_FakeApi()),
      ],
      child: MaterialApp(home: Scaffold(body: CustomProfilePagesTab(handle: 'tester', isMine: isMine))),
    ));
    await tester.pump();
    await tester.pump();
  }

  testWidgets('「ページ」タブ (D-446): Markdown ページ / 自作プラグイン(制限モード)。持ち主には端末の下書きと「+ 追加」', (tester) async {
    await pumpTab(tester, isMine: true, seed: {'$rasqPageDraftsArea.v1': jsonEncode({'d1': {'title': '書きかけ', 'body': 'x', 'at': '2026-10-06T00:00:00Z'}})});
    expect(find.byKey(const ValueKey('rasqPage.md.pg1')), findsOneWidget);
    expect(find.text('自己紹介'), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.sideload.sl1')), findsOneWidget);
    expect(find.text('自作プラグイン ・ 制限モード ・ v0.1.0'), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.draft.d1')), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.add')), findsOneWidget);
    await pumpTab(tester, isMine: false, seed: {'$rasqPageDraftsArea.v1': jsonEncode({'d1': {'title': '書きかけ', 'body': 'x'}})});
    expect(find.byKey(const ValueKey('rasqPage.md.pg1')), findsOneWidget);
    expect(find.byKey(const ValueKey('rasqPage.draft.d1')), findsNothing, reason: '下書きは持ち主の端末だけ');
    expect(find.byKey(const ValueKey('rasqPage.add')), findsNothing);
    expect(find.byKey(const ValueKey('rasqPage.sideload.sl1.more')), findsNothing);
  });
}
