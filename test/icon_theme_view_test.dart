import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rasq_client/features/theme/icon_theme/icon_theme_backdrop.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_codec.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_editor_screen.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_library.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_pipeline.dart';
import 'package:rasq_client/features/theme/icon_theme/icon_theme_reader.dart';
import 'package:rasq_client/features/theme/icon_theme/rasq_theme_spec.dart';
import 'package:rasq_client/features/theme/icon_theme/theme_frames.dart';
import 'package:rasq_client/features/users/profile_image_viewer.dart';
import 'package:rasq_client/l10n/gen/app_localizations.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

/// アイコンのテーマの、データの形 (D-562)・テーマフレーム (D-563)・閲覧 (D-564)・編集 (D-565)。
void main() {
  const theme = IconThemeBasic(bgMode: IconThemeBg.gradient, gradient: 2, bg: [17, 34, 68], text: [255, 255, 255], accent: [0, 204, 255], particle: 3, amount: 10, speed: 5, hint: 5);
  final ext = iconThemeExtFromDrafts([IconThemeSlotDraft(trigger: IconThemeTrigger.always, shape: 3, orbit: 'fall'), IconThemeSlotDraft(trigger: IconThemeTrigger.tap, shape: 4, orbit: 'rise')]);

  /// テーマを書いたアイコン(JPEG、品質 75)。
  Uint8List themedJpeg({IconThemeBasic t = theme, IconThemeExt? e}) {
    final d = iconThemeSampleSource();
    iconThemeEncode(d, t, ext: e ?? ext);
    return Uint8List.fromList(img.encodeJpg(img.Image.fromBytes(width: iconThemeSize, height: iconThemeSize, bytes: d.buffer, numChannels: 4), quality: 75));
  }

  Widget app(Widget home, {List overrides = const []}) => ProviderScope(
        overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage()), ...overrides.cast()],
        child: MaterialApp(theme: RasqTheme.light(), locale: const Locale('ja'), localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, home: home),
      );

  group('データの形 (D-562)', () {
    test('アイコン / コミュハッシュタグ / Atmos の形が JSON で往復する', () {
      final spec = RasqThemeSpec(
        basic: theme,
        ext: ext,
        frames: const [RasqThemeFrameRef(svgId: 'sakura', x: 0.2, y: 0.8, size: 0.3, opacity: 0.5, rotation: 15)],
        scope: const RasqThemeScope.thread('misskey:mk.example:9abc'),
        triggers: const [RasqThemeTrigger.hashtagBadge(hashtag: 'rasq', svgId: 'star'), RasqThemeTrigger.actionAnimation(actionId: 'reaction', svgId: 'sparkle')],
        source: RasqThemeSource.atmos,
      );
      expect(RasqThemeSpec.fromJson(spec.toJson()), spec);
      final url = RasqThemeSpec(basic: theme, ext: const IconThemeExt.url('plugins.example.social/t/x'), scope: const RasqThemeScope.hashtag('rasq'), source: RasqThemeSource.communityTag);
      expect(RasqThemeSpec.fromJson(url.toJson()), url);
    });

    test('読めないものは読まない: 新しい版・色の外れ・アイコンに詰められない拡張・ID の形が違う枠', () {
      final j = RasqThemeSpec(basic: theme, ext: ext).toJson();
      expect(RasqThemeSpec.fromJson({...j, 'v': 2}), isNull);
      expect(RasqThemeSpec.fromJson({...j, 'basic': {...theme.toJson(), 'bg': [300, 0, 0]}}), isNull);
      final big = RasqThemeSpec.fromJson({...j, 'ext': {'url': 'x' * 100}});
      expect(big, isNotNull);
      expect(big!.ext, isNull, reason: '65 バイトに入らない拡張は捨てて、基本だけ');
      final frames = RasqThemeSpec.fromJson({...j, 'frames': [{'svg': '../etc/passwd'}, {'svg': 'https://evil.example/x.svg'}, {'svg': 'star', 'size': 9}]});
      expect(frames!.frames.map((f) => (f.svgId, f.size)), [('star', 1.0)]);
    });

    test('アイコンのテーマの枠は、基本パーティクルの種類で決まる(アイコンに ID を入れる余地が無い)', () {
      expect(iconThemeFramesFor(theme).map((f) => f.svgId), ['star', 'sparkle', 'sparkle']);
      expect(iconThemeFramesFor(const IconThemeBasic()), isEmpty);
      expect({for (final p in [1, 2, 3, 4, 5]) for (final f in iconThemeFramesFor(IconThemeBasic(particle: p))) f.svgId}.difference(bundledThemeSvgIds.toSet()), isEmpty);
    });
  });

  group('テーマフレーム (D-563)', () {
    test('消毒: script・イベント属性・外部参照・style を捨て、形だけ残す。上限を超えるものは使わない', () {
      const evil = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10" onload="alert(1)"><script>alert(1)</script>'
          '<image href="https://evil.example/x.png"/><foreignObject><div>x</div></foreignObject><use href="#a"/>'
          '<path d="M0 0L10 10" style="fill:url(https://evil.example)" onclick="x()" stroke="#fff"/></svg>';
      final doc = sanitizeThemeSvg(evil);
      expect(doc, isNotNull);
      expect(doc!.shapes.length, 1, reason: 'path だけ');
      expect(sanitizeThemeSvg('<svg viewBox="0 0 1 1"><path d="M0 0"/></svg>${' ' * (themeSvgMaxBytes)}'), isNull, reason: '16 KiB を超える');
      final many = '<svg viewBox="0 0 1 1">${'<circle cx="1" cy="1" r="1"/>' * 500}</svg>';
      expect(sanitizeThemeSvg(many)!.shapes.length, themeSvgMaxElements, reason: '要素は上限で読むのをやめる');
      expect(sanitizeThemeSvg('<html><script>x</script></html>'), isNull);
    });

    testWidgets('ID で引く: 同梱 → 外の置き場(偽物)。形の違う ID と消毒で空になるものは描かない', (tester) async {
      final asked = <String>[];
      final remote = _FakeRemote({
        'moon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><circle cx="5" cy="5" r="4" fill="#fff"/></svg>',
        'evil': '<svg viewBox="0 0 10 10"><script>alert(1)</script></svg>',
      }, asked);
      await tester.pumpWidget(app(
        const SizedBox(width: 400, height: 400, child: ThemeFramesLayer(frames: [
          RasqThemeFrameRef(svgId: 'star', x: 0.2, y: 0.2),
          RasqThemeFrameRef(svgId: 'moon', x: 0.8, y: 0.8),
          RasqThemeFrameRef(svgId: 'evil'),
          RasqThemeFrameRef(svgId: 'missing'),
        ])),
        overrides: [themeSvgRemoteProvider.overrideWithValue(remote)],
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
      expect(find.byKey(const ValueKey('theme.frame.0.star')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme.frame.1.moon')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme.frame.2.evil')), findsNothing);
      expect(find.byKey(const ValueKey('theme.frame.3.missing')), findsNothing);
      expect(find.byType(SvgLiteView), findsNWidgets(2));
      expect(asked, containsAll(['moon', 'evil', 'missing']));
      expect(asked, isNot(contains('star')), reason: '同梱は外へ聞かない');
    });
  });

  group('閲覧 (D-564)', () {
    test('アイコンのバイト列から読む。正方形でない / テーマの無い画像は null', () {
      final d = decodeIconThemeBytes(themedJpeg());
      expect(d?.theme, theme);
      expect(d?.ext, ext);
      final plain = img.encodePng(img.Image(width: 400, height: 400));
      expect(decodeIconThemeBytes(Uint8List.fromList(plain)), isNull);
      final wide = img.encodePng(img.copyResize(img.decodeJpg(themedJpeg())!, width: 400, height: 300));
      expect(decodeIconThemeBytes(Uint8List.fromList(wide)), isNull);
      expect(decodeIconThemeBytes(Uint8List.fromList([1, 2, 3])), isNull);
    });

    test('URL ごとに覚える(読めなかったことも)。同時に取るのは 2 つまで', () async {
      final calls = <String>[];
      var inFlight = 0, peak = 0;
      final gates = <String, Completer<void>>{};
      final cache = IconThemeCache((u) async {
        calls.add(u.path);
        inFlight++;
        if (inFlight > peak) peak = inFlight;
        await (gates[u.path] = Completer<void>()).future;
        inFlight--;
        return u.path == '/themed' ? themedJpeg() : null;
      });
      final a = cache.read('https://e.test/themed'), b = cache.read('https://e.test/none'), c = cache.read('https://e.test/three');
      expect(identical(cache.read('https://e.test/themed'), a), isTrue, reason: '同じ URL は 1 回だけ取る');
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['/themed', '/none'], reason: '3 つ目は待つ');
      gates['/themed']!.complete();
      gates['/none']!.complete();
      final spec = await a;
      expect(spec?.basic, theme);
      expect(spec?.frames.map((f) => f.svgId), ['star', 'sparkle', 'sparkle']);
      expect(await b, isNull);
      await Future<void>.delayed(Duration.zero);
      gates['/three']!.complete();
      expect(await c, isNull);
      expect(peak, 2);
      expect(cache.peek('https://e.test/none').known, isTrue);
      await cache.read('https://e.test/none');
      expect(calls.where((p) => p == '/none').length, 1, reason: '読めなかったことも覚える');
    });

    testWidgets('設定で止めると読まない', (tester) async {
      var fetched = 0;
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(MemorySessionStorage()),
        iconThemeFetcherProvider.overrideWithValue((_) async {
          fetched++;
          return themedJpeg();
        }),
        iconThemesEnabledProvider.overrideWithValue(false),
      ]);
      addTearDown(c.dispose);
      expect(await c.read(iconThemeProvider('https://e.test/a').future), isNull);
      expect(fetched, 0);
    });

    test('添付の並べ方は予約ビットの「縦」「詰める」から', () {
      expect(RasqMediaArrangement.of(vertical: false, packed: false), RasqMediaArrangement.horizontal);
      expect(RasqMediaArrangement.of(vertical: false, packed: true), RasqMediaArrangement.horizontalPacked);
      expect(RasqMediaArrangement.of(vertical: true, packed: false), RasqMediaArrangement.vertical);
      expect(RasqMediaArrangement.of(vertical: true, packed: true), RasqMediaArrangement.verticalPacked);
    });

    testWidgets('タイムライン: 作者のアイコンの予約ビットで、アイコンの枠(角丸)と添付の並びが替わる', (tester) async {
      final author = UserSummary(id: 'u', account: const AccountId(kind: SnsKind.misskey, instance: 'mk.example', handle: 'a'), displayName: 'A', avatarUrl: Uri.parse('https://e.test/a.png'));
      final media = [for (var i = 0; i < 5; i++) MediaItem(id: 'm$i', type: MediaType.image, url: Uri.parse('https://e.test/m$i.png'), width: i.isEven ? 300 : 300, height: i.isEven ? 200 : 400)];
      for (final arrangement in RasqMediaArrangement.values) {
        await tester.pumpWidget(app(SingleChildScrollView(
          child: RasqPostTile(
            author: author,
            createdAt: DateTime(2026),
            content: const Text('x'),
            avatarRounded: arrangement != RasqMediaArrangement.auto,
            media: RasqMediaGrid(items: media, maxVisible: 5, arrangement: arrangement),
          ),
        )));
        await tester.pump();
        expect(tester.widget<RasqAvatar>(find.byType(RasqAvatar)).rounded, arrangement != RasqMediaArrangement.auto);
        if (arrangement == RasqMediaArrangement.auto) {
          expect(find.byKey(ValueKey('media.arranged.${RasqMediaArrangement.horizontal.name}')), findsNothing);
        } else {
          expect(find.byKey(ValueKey('media.arranged.${arrangement.name}')), findsOneWidget, reason: arrangement.name);
        }
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('アイコンの拡大: テーマが読めたら、背景・枠・パーティクル・文字色。読めなければ今までどおり黒', (tester) async {
      final spec = RasqThemeSpec.fromIcon(decodeIconThemeBytes(themedJpeg())!, frames: iconThemeFramesFor(theme));
      Future<void> open(RasqThemeSpec? s) async {
        await tester.pumpWidget(const SizedBox()); // 前の ProviderScope を捨てる(差し替えを効かせる)
        await tester.pumpWidget(app(
          MediaQuery(data: const MediaQueryData(disableAnimations: true), child: ProfileImageViewerScreen(url: Uri.parse('https://e.test/a.png'), title: 'タロ')),
          overrides: [iconThemeProvider.overrideWith((ref, url) async => s)],
        ));
        await tester.pump();
        await tester.pump();
      }

      await open(spec);
      expect(find.byKey(const ValueKey('profileImage.backdrop')), findsOneWidget);
      expect(find.byKey(const ValueKey('iconTheme.particles')), findsOneWidget);
      expect(find.byKey(const ValueKey('profileImage.themed')), findsOneWidget);
      expect(tester.widget<Text>(find.text('タロ')).style?.color, themeColor(theme.text));
      expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, Colors.transparent);
      // 押すとパーティクル(クリックのスロット)が出る。止めた表示では出さないので、例外が出ないことだけ。
      await tester.tapAt(const Offset(200, 500));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await open(null);
      expect(find.byKey(const ValueKey('profileImage.backdrop')), findsNothing);
      expect(tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor, Colors.black);
    });

    testWidgets('背景のパーティクルは動き続け、押すと出る(動きを減らさない表示)', (tester) async {
      final spec = RasqThemeSpec(basic: theme, ext: ext);
      await tester.pumpWidget(app(Scaffold(body: IconThemeBackdrop(spec: spec))));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tapAt(const Offset(200, 300));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('テーマ編集 (D-565)', () {
    Future<void> settle(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 200 && !done(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 130));
      }
    }

    testWidgets('01〜04: 見本を変換 → 見本の再圧縮 → 読み戻して一致。予約ビットを替えると見本の投稿も替わる。容量オーバーは知らせる。「このアイコンを使う」で PNG', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Uint8List? result;
      await tester.pumpWidget(app(Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () async => result = await openIconThemeEditor(context), child: const Text('open')))))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(IconThemeEditorScreen), findsOneWidget);
      Text pillText(String k) => tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('iconTheme.result.$k')), matching: find.byType(Text)));
      await settle(tester, () => find.byKey(const ValueKey('iconTheme.encoded')).evaluate().isNotEmpty && pillText('basic').data != '—');
      expect(pillText('basic').data, '復元できた');
      expect(pillText('ext').data, '復元できた');
      expect(pillText('hint').data, '読めた');
      expect(pillText('match').data, 'DSL が一致');
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('iconTheme.dsl'))).data, '[ G 2 1 2 4 T f f f A 0 c f P 3 S a 5 R5 ]');
      expect(find.byKey(const ValueKey('iconTheme.sampleAvatar.rounded')), findsOneWidget);
      expect(find.byKey(const ValueKey('media.arranged.horizontalPacked')), findsOneWidget);

      // 予約ビット: 丸・縦 → 見本の投稿のアイコンと並びが替わる。
      for (final (key, label) in const [('iconTheme.hint.frame', '丸'), ('iconTheme.hint.dir', '縦')]) {
        final target = find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(label));
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.tap(target);
        await tester.pump();
      }
      await settle(tester, () => find.byKey(const ValueKey('iconTheme.sampleAvatar.circle')).evaluate().isNotEmpty && find.byKey(const ValueKey('media.arranged.verticalPacked')).evaluate().isNotEmpty);
      expect(find.byKey(const ValueKey('media.arranged.verticalPacked')), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byKey(const ValueKey('iconTheme.dsl'))).data, endsWith('R3 ]'));

      // 配信 URL が長すぎる → 容量オーバー(アイコンは直前のまま)。
      await tester.ensureVisible(find.byKey(const ValueKey('iconTheme.extMode')));
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('iconTheme.extMode')), matching: find.text('配信 URL')));
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('iconTheme.url')), 'plugins.example.social/${'x' * 80}');
      await tester.pump();
      await settle(tester, () => find.byKey(const ValueKey('iconTheme.over')).evaluate().isNotEmpty);
      expect(find.textContaining('容量オーバー'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('iconTheme.use'))).onPressed, isNull);
      await tester.enterText(find.byKey(const ValueKey('iconTheme.url')), 'plugins.example.social/t/a');
      await tester.pump();
      await settle(tester, () => find.byKey(const ValueKey('iconTheme.over')).evaluate().isEmpty && pillText('ext').data == '復元できた');
      expect(find.textContaining('https://plugins.example.social/t/a'), findsOneWidget);

      // 拡大して見る → 閉じる。
      await tester.ensureVisible(find.byKey(const ValueKey('iconTheme.preview')));
      await tester.tap(find.byKey(const ValueKey('iconTheme.preview')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('iconTheme.profilePreview')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('iconTheme.preview.close')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('iconTheme.profilePreview')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('iconTheme.use')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, isNotNull);
      final back = img.decodePng(result!)!;
      final d = iconThemeDecode(back.convert(numChannels: 4).getBytes(order: img.ChannelOrder.rgba), back.width, back.height);
      expect(d.ok, isTrue);
      expect(d.theme!.hints!.roundedFrame, isFalse);
      expect(d.ext?.url, 'plugins.example.social/t/a');
    });

    testWidgets('「実際の SNS から保存した画像で試す」: 選んだ画像をそのまま読み戻す', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final themed = themedJpeg(t: const IconThemeBasic(bg: [255, 0, 0], text: [0, 0, 0], accent: [0, 0, 255], particle: 2, hint: 0));
      await tester.pumpWidget(app(const IconThemeEditorScreen(), overrides: [iconThemeImagePickerProvider.overrideWithValue(() async => themed)]));
      Text pillText(String k) => tester.widget<Text>(find.descendant(of: find.byKey(ValueKey('iconTheme.result.$k')), matching: find.byType(Text)));
      await settle(tester, () => pillText('basic').data != '—');
      await tester.ensureVisible(find.byKey(const ValueKey('iconTheme.external')));
      await tester.tap(find.byKey(const ValueKey('iconTheme.external')));
      await tester.pump();
      await settle(tester, () => find.byKey(const ValueKey('iconTheme.dummy')).evaluate().isNotEmpty && (tester.widget<Text>(find.byKey(const ValueKey('iconTheme.dslBack'))).data ?? '').startsWith('[ B'));
      expect(pillText('match').data, '外の画像なので比べない');
      expect(pillText('basic').data, '復元できた');
      expect(tester.widget<Text>(find.byKey(const ValueKey('iconTheme.dslBack'))).data, '[ B f 0 0 T 0 0 0 A 0 0 f P 2 S 8 4 R0 ]');
      expect(find.byKey(const ValueKey('iconTheme.sampleAvatar.circle')), findsOneWidget);
    });
  });
}

class _FakeRemote implements ThemeSvgRemote {
  _FakeRemote(this.svgs, this.asked);
  final Map<String, String> svgs;
  final List<String> asked;
  @override
  Future<String?> fetch(String id) async {
    asked.add(id);
    return svgs[id];
  }
}
