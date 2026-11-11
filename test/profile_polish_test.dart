import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/login/server_pick.dart';
import 'package:rasq_client/features/notifications/notifications_screen.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/text/inline_spans.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:sns_misskey/sns_misskey.dart';

// D-560: サーバーのカードの列 / プロフィールの項目(リンクと追加情報)/ 名前の絵文字 / フォロー数の公開範囲。

const _acct = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'me');

UserSummary _user(String name, {Map<String, Uri> emojis = const {}}) =>
    UserSummary(id: 'u-$name', account: const AccountId(kind: SnsKind.misskey, instance: 'remote.example', handle: 'hana'), displayName: name, emojis: emojis);

void main() {
  group('サーバーのカードの列', () {
    test('AsTell と同じ幅(220〜600px): 広がったら列を増やし(最大 5 列)、そのあとで 600px まで大きくする', () {
      expect(serverCardMinWidth, 220);
      expect(serverCardMaxWidth, 600);
      expect(serverGridColumns(240), 1);
      expect(serverGridColumns(342), 2, reason: '電話の幅は 2 列(カードは 220 より細くなる)');
      expect(serverGridColumns(700), 3);
      expect(serverGridColumns(1232), 5);
      expect(serverGridColumns(4000), 5, reason: '最大 5 列');
      expect(serverCardWidth(1232, 5), closeTo((1232 - 8 * 4) / 5, 0.01));
      expect(serverCardWidth(4000, 5), 600, reason: '5 列でも余れば 600px まで');
    });

    testWidgets('大きな画面: 5 列、カードは 600px を超えず、行は中央', (tester) async {
      tester.view.physicalSize = const Size(4000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [popularServersProvider(SnsKind.misskey).overrideWithValue(const ['a.example', 'b.example', 'c.example', 'd.example', 'e.example', 'f.example'])],
        child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ServerPickList(kind: SnsKind.misskey, onPick: (_) {})))),
      ));
      await tester.pumpAndSettle();
      final rects = [for (final h in ['a', 'b', 'c', 'd', 'e', 'f']) tester.getRect(find.byKey(ValueKey('login.server.$h.example')))];
      expect(rects.take(5).map((r) => r.top).toSet().length, 1, reason: '1 行に 5 枚');
      expect(rects[5].top, greaterThan(rects[0].bottom), reason: '6 枚目は次の行');
      expect(rects[0].width, 600);
      expect(rects[5].left, rects[0].left, reason: '最後の行も左の位置をそろえる');
      final rowCenter = (rects[0].left + rects[4].right) / 2;
      expect(rowCenter, closeTo(2000, 1), reason: '中央に寄せる');
    });
  });

  group('プロフィールの項目', () {
    test('URL と @ハンドルはリンク、それ以外は追加情報', () {
      expect(classifyProfileField('https://example.com/a').kind, ProfileFieldKind.link);
      expect(classifyProfileField('<a href="https://x.example/me" rel="me">x.example/me</a>').kind, ProfileFieldKind.info, reason: 'タグを外すと URL の形でない');
      expect(classifyProfileField('<a href="https://x.example/me">https://x.example/me</a>').url, Uri.parse('https://x.example/me'));
      final m = classifyProfileField('@hana');
      expect((m.kind, m.handle, m.host), (ProfileFieldKind.mention, 'hana', null));
      final r = classifyProfileField(' @Hana_2@Misskey.IO ');
      expect((r.kind, r.handle, r.host), (ProfileFieldKind.mention, 'Hana_2', 'misskey.io'));
      for (final v in ['猫が好き', '東京', '@ 二つの 言葉', 'email@example.com', 'ftp://x.example', 'example.com', '']) {
        expect(classifyProfileField(v).kind, ProfileFieldKind.info, reason: v);
      }
    });

    Future<void> pumpTile(WidgetTester tester, UserProfile p, {List<RasqSpan>? nameSpans, List<Uri>? links, List<(String, String?)>? mentions}) async {
      tester.view.physicalSize = const Size(420, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: RasqTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RasqUserTileLarge(profile: p, nameSpans: nameSpans, onLinkTap: links?.add, onMentionTap: mentions == null ? null : (h, host) => mentions.add((h, host))),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('リンクは押せてリンクの色、@ハンドルはその人へ、追加情報は名前と値のまま(押せない)', (tester) async {
      final links = <Uri>[], mentions = <(String, String?)>[];
      await pumpTile(
        tester,
        UserProfile(summary: _user('はな'), fields: const [
          ProfileField(name: 'Web', value: 'https://hana.example/'),
          ProfileField(name: 'X', value: '@hana_x@x.example'),
          ProfileField(name: 'サブ', value: '@hana2'),
          ProfileField(name: '好きなもの', value: '猫とコーヒー'),
        ]),
        links: links,
        mentions: mentions,
      );
      await tester.tap(find.byKey(const ValueKey('profile.field.0')));
      await tester.tap(find.byKey(const ValueKey('profile.field.1')));
      await tester.tap(find.byKey(const ValueKey('profile.field.2')));
      expect(links, [Uri.parse('https://hana.example/')]);
      expect(mentions, [('hana_x', 'x.example'), ('hana2', null)]);
      // 追加情報は別の欄に、押せない形で。
      final info = find.byKey(const ValueKey('profile.info'));
      expect(find.descendant(of: info, matching: find.text('好きなもの')), findsOneWidget);
      expect(find.descendant(of: info, matching: find.text('猫とコーヒー')), findsOneWidget);
      expect(find.descendant(of: info, matching: find.byType(InkWell)), findsNothing);
      expect(find.descendant(of: info, matching: find.text('Web')), findsNothing);
    });

    testWidgets('フォロー数: 本人だけなら 🔒、フォロワーにだけなら ?、見えていれば数', (tester) async {
      await pumpTile(
        tester,
        UserProfile(
          summary: _user('はな'),
          followingCount: null,
          followersCount: null,
          followingVisibility: FollowListVisibility.private,
          followersVisibility: FollowListVisibility.followers,
        ),
      );
      expect(find.descendant(of: find.byKey(const ValueKey('profile.count.following.hidden')), matching: find.text('🔒')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('profile.count.followers.hidden')), matching: find.text('?')), findsOneWidget);

      await pumpTile(tester, UserProfile(summary: _user('はな'), followingCount: 12, followersCount: 34, followingVisibility: FollowListVisibility.followers));
      expect(find.text('12'), findsOneWidget, reason: 'フォローしていて見えるなら数');
      expect(find.byKey(const ValueKey('profile.count.following.hidden')), findsNothing);

      await pumpTile(tester, UserProfile(summary: _user('はな')));
      expect(find.byKey(const ValueKey('profile.count.following.hidden')), findsNothing, reason: '公開範囲の分からない SNS で数が無ければ出さない');
    });

    testWidgets('名前の絵文字: その人が持ってきた絵文字(認証マークなど)で描く', (tester) async {
      final u = _user('はな :verified:', emojis: {'verified': Uri.parse('https://remote.example/emoji/verified.png')});
      await pumpTile(tester, UserProfile(summary: u), nameSpans: InlineSpans.name(u));
      final rich = tester.widget<RasqRichText>(find.byKey(const ValueKey('profile.name')));
      final emoji = rich.spans.whereType<RasqEmojiSpan>().single;
      expect((emoji.shortcode, emoji.url), ('verified', Uri.parse('https://remote.example/emoji/verified.png')));
    });
  });

  group('名前の絵文字', () {
    test('閲覧中のサーバーの絵文字に、その人の絵文字を重ねる。持ってきた絵文字が無ければ同じ表を使う', () {
      final local = <String, Uri?>{'cat': Uri.parse('https://misskey.io/cat.png')};
      final spans = InlineSpans.name(_user(':cat: はな :badge:', emojis: {'badge': Uri.parse('https://remote.example/badge.png')}), emojis: local, bold: true);
      expect([for (final s in spans.whereType<RasqEmojiSpan>()) s.url.toString()], ['https://misskey.io/cat.png', 'https://remote.example/badge.png']);
      expect(spans.whereType<RasqTextSpan>().every((t) => t.bold), isTrue);
    });

    test('Misskey: リモートの人の emojis と、フォロー / フォロワーの公開範囲(古い ffVisibility も)', () {
      final p = MisskeyMappers.profile({
        'id': 'u1',
        'username': 'hana',
        'host': 'remote.example',
        'name': 'はな :verified:',
        'emojis': {'verified': 'https://remote.example/emoji/verified.png'},
        'followingVisibility': 'private',
        'followersVisibility': 'followers',
      }, account: _acct, host: 'misskey.io');
      expect(p.summary.emojis, {'verified': Uri.parse('https://remote.example/emoji/verified.png')});
      expect((p.followingVisibility, p.followersVisibility), (FollowListVisibility.private, FollowListVisibility.followers));
      expect((p.followingCount, p.followersCount), (null, null));
      final old = MisskeyMappers.profile({'id': 'u2', 'username': 'jiro', 'ffVisibility': 'followers'}, account: _acct, host: 'misskey.io');
      expect((old.followingVisibility, old.followersVisibility), (FollowListVisibility.followers, FollowListVisibility.followers));
    });

    test('wire: 名前の絵文字は {名前: URL} と Mastodon の [{shortcode, url}] の両方。http(s) だけ', () {
      expect(SnsWire.emojisFrom({'a': 'https://x.example/a.png', 'bad': 'javascript:1'}), {'a': Uri.parse('https://x.example/a.png')});
      expect(SnsWire.emojisFrom([{'shortcode': 'b', 'url': 'https://x.example/b.png'}]), {'b': Uri.parse('https://x.example/b.png')});
      final u = SnsWire.userFrom(SnsWire.user(_user('x', emojis: {'c': Uri.parse('https://x.example/c.png')})));
      expect(u.emojis, {'c': Uri.parse('https://x.example/c.png')});
      final p = SnsWire.profileFrom({'user': SnsWire.user(_user('x')), 'followingVisibility': 'private'}, account: _acct);
      expect(p.followingVisibility, FollowListVisibility.private);
    });
  });

  testWidgets('通知: 名前は絵文字つきの太字、リモートのリアクションの絵文字も描く', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final actor = _user('はな :verified:', emojis: {'verified': Uri.parse('https://remote.example/verified.png')});
    final post = Post(
      id: 'p1',
      account: _acct,
      author: _user('me'),
      body: 'こんにちは',
      createdAt: DateTime.utc(2026, 11, 11),
      reactionEmojis: {'blob@remote.example': Uri.parse('https://remote.example/blob.png')},
    );
    final item = NotificationItem(id: 'n1', account: _acct, kind: NotificationKind.reaction, createdAt: DateTime.utc(2026, 11, 11), actors: [actor], post: post, reaction: ':blob@remote.example:');
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage({}))],
      child: MaterialApp(home: Scaffold(body: NotificationTile(item: item))),
    ));
    await tester.pump();
    final texts = [for (final r in tester.widgetList<RasqRichText>(find.byType(RasqRichText))) ...r.spans];
    final verified = texts.whereType<RasqEmojiSpan>().where((e) => e.shortcode == 'verified');
    expect(verified.single.url, Uri.parse('https://remote.example/verified.png'));
    expect(texts.whereType<RasqTextSpan>().where((t) => t.text.contains('はな')).single.bold, isTrue);
    // 絵文字の部品が URL つきで置かれる(画像が読めないテストでは、代わりにショートコードの字が出る)。
    expect(tester.widgetList<RasqCustomEmoji>(find.byType(RasqCustomEmoji)).map((e) => e.url), contains(Uri.parse('https://remote.example/verified.png')));
    final img = tester.widgetList<Image>(find.byType(Image)).map((i) => i.image).whereType<NetworkImage>().map((n) => n.url);
    expect(img, contains('https://remote.example/blob.png'));
  });
}
