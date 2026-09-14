import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_functions.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// RAi の関数呼び出し (D-221): タグの解釈、注入の予算、自動化の可否。
void main() {
  test('[[call:<関数>|k=v|…]] を拾い、本文から外す', () {
    final calls = raiFunctionCallsIn('見てみます [[call:posts.fetch|keyword=打ち上げ|limit=2|sort=reactions]] と [[call:astell.rooms]]');
    expect(calls.length, 2);
    expect(calls.first.name, 'posts.fetch');
    expect(calls.first.args, {'keyword': '打ち上げ', 'limit': '2', 'sort': 'reactions'});
    expect(calls.last.name, 'astell.rooms');
    expect(calls.last.args, isEmpty);
    expect(raiStripFunctionCalls('見てみます [[call:posts.fetch|keyword=x]] \nはい'), '見てみます\nはい');
    expect(raiFunctionCallsIn('無し'), isEmpty);
  });

  test('注入の予算 = コンテキストの 4%(1 トークン ≒ 1.8 文字)、下限 80', () {
    expect(raiInjectionBudgetChars(2048), 147);
    expect(raiInjectionBudgetChars(8192), 590);
    expect(raiInjectionBudgetChars(100), 80);
    expect(raiTruncate('あいう', 2), 'あい…');
    expect(raiTruncate('あいう', 3), 'あいう');
  });

  test('自動化の可否: allowed かつ FOW を開かないものだけ', () {
    expect(raiCanAutomate(const ActionDescriptor(id: 'a', genreTag: 'Reaction', label: 'A')), isTrue);
    expect(raiCanAutomate(const ActionDescriptor(id: 'b', genreTag: 'Reaction', label: 'B', autoHookForbidden: true)), isFalse);
    expect(raiCanAutomate(const ActionDescriptor(id: 'c', genreTag: 'Reaction', label: 'C', confirmMode: ConfirmMode.confirm)), isFalse);
    expect(raiCanAutomate(const ActionDescriptor(id: 'd', genreTag: 'Reply', label: 'D', fow: FowType.interstitial)), isFalse);
  });

  group('raiFoldLines (D-223): 一覧の行を予算まで積む共有ヘルパー', () {
    test('全部収まれば全部、頭に「head N 件中 M 件」を添える', () {
      expect(raiFoldLines(['a', 'b', 'c'], 147, head: 'TL'), 'TL 3 件中 3 件:\na\nb\nc');
    });

    test('空なら「該当なし」', () {
      expect(raiFoldLines(const [], 147, head: 'TL'), 'TL: 該当なし');
    });

    test('予算 147 文字: 40 文字弱の行なら 3 件までしか入らない(D-221 の想定どおり)', () {
      final lines = [for (var i = 0; i < 8; i++) '@user$i: ${'あ' * 30} [p$i]']; // 1 行 ≒ 40 文字
      final out = raiFoldLines(lines, raiInjectionBudgetChars(2048), head: '投稿');
      expect(raiInjectionBudgetChars(2048), 147);
      final kept = out.split('\n').skip(1).length;
      expect(kept, lessThan(lines.length)); // 8 件全部は入らない
      expect(kept, inInclusiveRange(2, 4));
      expect(out, startsWith('投稿 8 件中 $kept 件:'));
    });

    test('最初の 1 行すら入らなければ切り詰めて 1 行だけ残す', () {
      final huge = 'x' * 500;
      final out = raiFoldLines([huge], 50, head: 'X');
      final body = out.split('\n').sublist(1).join('\n');
      expect(body.length, 51); // raiTruncate: 50 文字 + '…'
      expect(body, endsWith('…'));
    });
  });

  group('raiGuard (D-223): 非対応の例外を日本語の短文へ', () {
    test('UnsupportedError → 「この SNS では使えません(関数名)」', () async {
      final r = await raiGuard('post.reactions', () async => throw UnsupportedError('no'));
      expect(r.ok, isFalse);
      expect(r.fetched, isFalse);
      expect(r.text, 'この SNS では使えません(post.reactions)');
    });

    test('SnsApiException(C01) → 同じ短文、C01 以外はそのまま投げ直す', () async {
      final r = await raiGuard('feeds.list', () async => throw SnsApiException(ErrorCode.app(ErrorFamily.pluginTransfer, '01')));
      expect(r.text, 'この SNS では使えません(feeds.list)');
      expect(() => raiGuard('user.get', () async => throw SnsApiException(ErrorCode.notFound)), throwsA(isA<SnsApiException>()));
    });

    test('StateError(未ログイン等)→ そのメッセージを短文として返す', () async {
      final r = await raiGuard('me.get', () async => throw StateError('SNS にログインしていません'));
      expect(r.text, 'SNS にログインしていません');
      expect(r.ok, isFalse);
    });

    test('成功時はそのまま通す', () async {
      final r = await raiGuard('x', () async => const RaiFunctionResult(name: 'x', text: 'ok', fetched: true));
      expect(r.text, 'ok');
      expect(r.fetched, isTrue);
    });
  });

  test('raiFunctionUsage: 25 行未満に収まる(system への注入が肥大化しないよう D-223 でも維持)', () {
    expect(raiFunctionUsage.length, lessThan(25));
    for (final u in raiFunctionUsage) {
      expect(u, isNot(contains('\n')));
    }
  });
}
