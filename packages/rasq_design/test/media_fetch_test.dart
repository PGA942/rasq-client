// セキュリティ確認 2026-10-09 の [11]: 制限のある面の画像は、リダイレクトの各ホップで方針を確かめ直す(端末版)。
// 宣言した接続先が宣言の外 / loopback / LAN へ転送しても、ホストはそこへ送らない。
// (testWidgets の binding は HttpClient を差し替えるので、このファイルは test だけ。)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_design/rasq_design.dart';

void main() {
  late HttpServer server;
  final hits = <String>[];
  late String base;
  setUp(() async {
    hits.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}';
    server.listen((req) async {
      hits.add(req.uri.path);
      final res = req.response;
      switch (req.uri.path) {
        case '/img':
          res.add([1, 2, 3]);
        case '/same':
          res.redirect(Uri.parse('/img'), status: HttpStatus.found);
          return;
        case '/away':
          // 同じサーバーでも名前が違う(宣言していない接続先)。
          res.redirect(Uri.parse('http://localhost:${server.port}/secret?d=leak'), status: HttpStatus.found);
          return;
        case '/lan':
          res.redirect(Uri.parse('http://192.168.0.1/x'), status: HttpStatus.movedPermanently);
          return;
        case '/file':
          res.redirect(Uri.parse('file:///etc/passwd'), status: HttpStatus.temporaryRedirect);
          return;
        case '/loop':
          res.redirect(Uri.parse('/loop'), status: HttpStatus.found);
          return;
        case '/big':
          res.add(List.filled(2048, 0));
        default:
          res.statusCode = HttpStatus.notFound;
      }
      await res.close();
    });
  });
  tearDown(() => server.close(force: true));

  final policy = RasqMediaPolicy.plugin(hostAllowed: (h) => h == '127.0.0.1');

  test('宣言した接続先の中の転送は追う(各ホップを確かめて)', () async {
    expect(await rasqFetchMedia(Uri.parse('$base/img'), policy.allows), [1, 2, 3]);
    expect(await rasqFetchMedia(Uri.parse('$base/same'), policy.allows), [1, 2, 3]);
    expect(hits, ['/img', '/same', '/img']);
  });

  test('宣言の外 / LAN / file: への転送は、転送先へ送らずに断る', () async {
    for (final path in ['/away', '/lan', '/file']) {
      await expectLater(rasqFetchMedia(Uri.parse('$base$path'), policy.allows), throwsA(isA<RasqMediaBlocked>()), reason: path);
    }
    expect(hits, ['/away', '/lan', '/file']); // /secret には届いていない
  });

  test('転送の回数 / 本文の大きさ / 最初の URL も方針で絞る', () async {
    await expectLater(rasqFetchMedia(Uri.parse('$base/loop'), policy.allows), throwsA(isA<RasqMediaBlocked>()));
    expect(hits.length, rasqMediaMaxRedirects + 1);
    await expectLater(rasqFetchMedia(Uri.parse('$base/big'), policy.allows, maxBytes: 1024), throwsA(isA<RasqMediaBlocked>()));
    hits.clear();
    await expectLater(rasqFetchMedia(Uri.parse('http://localhost:${server.port}/img'), policy.allows), throwsA(isA<RasqMediaBlocked>()));
    expect(hits, isEmpty);
  });
}
