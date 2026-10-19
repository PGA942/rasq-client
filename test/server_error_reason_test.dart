import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_consent.dart';
import 'package:rasq_client/features/child_safe/child_safe_api.dart';
import 'package:rasq_models/rasq_models.dart';

/// D-503: サーバーの誤りは、表示の言語に訳される文(`message`)ではなく、名前つきの理由(`error.code`)で見る。
/// 名前を返さない古いサーバーのときだけ、前の版の英語の文の一部で見る。
void main() {
  OrgateException ex(int status, String message, {String? code}) => OrgateException(ErrorCode.http(status), message, serverCode: code ?? '$status');

  test('isReason: 名前が来ればそれだけで決まり、文は見ない', () {
    expect(ex(429, 'Swing は同時に 20 個まで', code: 'swing_limit').isReason('swing_limit', legacyText: 'swing_limit'), isTrue);
    // 名前つきの理由が別のものなら、文に古い語が入っていても当てない。
    expect(ex(400, 'swing_limit', code: 'invalid_package').isReason('swing_limit', legacyText: 'swing_limit'), isFalse);
    expect(ex(400, 'x', code: 'invalid_package').hasNamedReason, isTrue);
    expect(ex(409, 'x').hasNamedReason, isFalse);
    // 古いサーバー(数字のコードだけ / コード無し)は文で見る。
    expect(ex(409, 'up to 20 Swings at a time: swing_limit').isReason('swing_limit', legacyText: 'swing_limit'), isTrue);
    expect(OrgateException(ErrorCode.http(409), 'swing_limit').isReason('swing_limit', legacyText: 'swing_limit'), isTrue);
    expect(ex(409, 'other').isReason('swing_limit', legacyText: 'swing_limit'), isFalse);
    expect(ex(409, 'swing_limit').isReason('swing_limit'), isFalse, reason: 'legacyText が無ければ名前だけ');
  });

  test('規約の誤り: 名前(terms_version / terms_required)で見る。文が訳されていても当たる', () {
    expect(isTermsVersionError(ex(409, '利用規約は最新の版で承諾してください', code: 'terms_version')), isTrue);
    expect(isTermsRequiredError(ex(403, '先に利用規約に同意してください', code: 'terms_required')), isTrue);
    expect(isTermsVersionError(ex(409, 'x', code: 'terms_required')), isFalse);
    // 古いサーバー(英語の文)。
    expect(isTermsVersionError(ex(409, 'terms must be accepted at the current version 2026-09-01')), isTrue);
    expect(isTermsRequiredError(ex(403, 'accept the current terms of service and privacy policy first')), isTrue);
    expect(isTermsVersionError(ex(400, 'terms must be accepted at the current version 2026-09-01')), isFalse);
  });

  test('チャイルドセーフ: Central の文(err-child-02)はそのまま、名前つきの理由が来たらハンドルの言い換えはしない', () {
    expect(childSafeErrorMessage(ex(403, '保護者の確認が済んでいません。「チャイルドセーフ」の「保護者の確認」から確認してください')), '保護者の確認が済んでいません。「チャイルドセーフ」の「保護者の確認」から確認してください');
    expect(childSafeErrorMessage(ex(409, 'that handle is taken')), 'そのハンドルは使われています');
    expect(childSafeErrorMessage(ex(409, 'handle_conflict', code: 'managed_collection')), 'handle_conflict');
  });
}
