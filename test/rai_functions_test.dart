import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_functions.dart';
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
}
