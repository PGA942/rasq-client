import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/account_security_api.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/features/onboarding/password_strength.dart';
import 'package:rasq_client/l10n/gen/app_localizations.dart';
import 'package:rasq_models/rasq_models.dart';

/// 弱いパスワードの要件のチップ (D-560)。判定は ORGATE の validate_password_for と同じ規則。
void main() {
  test('ORGATE のテストと同じ入力で同じ答え(src/auth/password.rs の tests)', () {
    expect(passwordWeaknesses('Password123', handle: 'taro'), [PasswordWeakness.common], reason: '小文字にしてから表と比べる');
    expect(passwordWeaknesses('aaaaaaaaaa', handle: 'taro'), [PasswordWeakness.repeated]);
    expect(passwordWeaknesses('taro_yamada', handle: 'Taro_Yamada'), [PasswordWeakness.sameAsIdentity]);
    expect(passwordWeaknesses('taro.yamada', handle: 'x', email: 'taro.yamada@example.com'), [PasswordWeakness.sameAsIdentity]);
    expect(passwordWeaknesses('T@example.com', email: 't@example.com'), [PasswordWeakness.sameAsIdentity]);
    expect(passwordWeaknesses('correct horse battery', handle: 'taro', email: 't@example.com'), isEmpty);
    expect(passwordWeaknesses(''), isEmpty);
  });

  test('当たった要件は全部出す(サーバーは最初の 1 つしか言わない)', () {
    expect(passwordWeaknesses('11111111', handle: '11111111'), [PasswordWeakness.common, PasswordWeakness.repeated, PasswordWeakness.sameAsIdentity]);
    expect(rasqCommonPasswords.length, 24, reason: 'ORGATE の COMMON_PASSWORDS と同じ数');
  });

  test('サーバーの答えから要件を読む: 今の文 / 一覧(docs/PASSWORD_STRENGTH.md の案)', () {
    expect(passwordWeaknessesFromServer(message: 'password is too weak: it is a commonly used password'), [PasswordWeakness.common]);
    expect(passwordWeaknessesFromServer(message: 'password is too weak: it repeats a single character'), [PasswordWeakness.repeated]);
    expect(passwordWeaknessesFromServer(message: 'password is too weak: it is the same as your handle or email'), [PasswordWeakness.sameAsIdentity]);
    expect(passwordWeaknessesFromServer(message: 'パスワードが弱すぎます', reason: 'password_weak', weaknesses: ['common', 'repeated', 'unknown']), [PasswordWeakness.common, PasswordWeakness.repeated]);
    expect(passwordWeaknessesFromServer(message: 'password must be 8-256 characters'), isNull);
  });

  test('アカウントの保護の 1 行: 「脆弱なパスワードです(当たった要件)」', () {
    RasqUiLocale.tag = 'ja';
    final e = OrgateException(ErrorCode.http(400), 'password is too weak: it repeats a single character', serverCode: '400');
    expect(accountSecurityMessage(e), '脆弱なパスワードです(同じ字の繰り返し)');
    final list = OrgateException(ErrorCode.http(400), 'weak', serverCode: 'password_weak', details: {'weaknesses': ['common', 'same_as_identity']});
    expect(accountSecurityMessage(list), '脆弱なパスワードです(よく使われるもの・ハンドルやメールと同じ)');
  });

  testWidgets('チップは当たった要件ごと', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: WeakPasswordNotice(weaknesses: [PasswordWeakness.common, PasswordWeakness.sameAsIdentity])),
    ));
    expect(find.text('脆弱なパスワードです'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'よく使われるもの'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'ハンドルやメールと同じ'), findsOneWidget);
    expect(find.byKey(const ValueKey('password.weak.repeated')), findsNothing);
  });
}
