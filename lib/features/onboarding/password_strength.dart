import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../l10n/l10n.dart';

/// 弱いパスワードの要件 (D-576)。判定はサーバー(ORGATE `src/auth/password.rs` の `validate_password_for`、S-019)と同じ規則を
/// 端末でも行い、当たった要件をすべてチップで出す。サーバーは**最初に当たった 1 つだけ**を文で返す
/// (`400 "password is too weak: <理由>"`)ので、要件の一覧はここで作る。サーバーが一覧を返す形の案は docs/PASSWORD_STRENGTH.md。
enum PasswordWeakness {
  /// よく使われるもの(サーバーの [rasqCommonPasswords] と同じ表、大文字小文字は見ない)。
  common('common'),

  /// 同じ字の繰り返し(1 種類の字だけ)。
  repeated('repeated'),

  /// ハンドル / 確認済みのメール / メールの @ より前と同じ(大文字小文字は見ない)。
  sameAsIdentity('same_as_identity');

  const PasswordWeakness(this.wire);

  /// サーバーが一覧を返すようになったときの名前(docs/PASSWORD_STRENGTH.md)。
  final String wire;

  String get label => switch (this) {
        common => appL10n.passwordStrengthCommon,
        repeated => appL10n.passwordStrengthRepeated,
        sameAsIdentity => appL10n.passwordStrengthSameAsIdentity,
      };

  IconData get icon => switch (this) {
        common => Icons.groups_outlined,
        repeated => Icons.repeat,
        sameAsIdentity => Icons.alternate_email,
      };
}

/// ORGATE の `COMMON_PASSWORDS` と同じ表(変えるときはサーバーと一緒に)。
const rasqCommonPasswords = {
  'password', 'password1', 'password123', 'passw0rd', '12345678', '123456789', '1234567890', '11111111', '00000000', //
  'qwertyui', 'qwerty123', 'qwertyuiop', 'asdfghjk', 'iloveyou', 'letmein123', 'admin1234', 'welcome1', 'abc12345', //
  'abcd1234', '1q2w3e4r', '1qaz2wsx', 'zaq12wsx', 'sunshine1', 'football1',
};

/// [password] が当たる弱い要件(当たった順ではなく、要件の並びで全部)。空なら無し。長さ(8〜256 文字)は別に見る。
/// [handle] / [email] は分かるときだけ(新規登録ではメールは無い。サーバーも確認済みのメールだけを見る)。
List<PasswordWeakness> passwordWeaknesses(String password, {String? handle, String? email}) {
  if (password.isEmpty) return const [];
  final lower = password.toLowerCase();
  final runes = password.runes.toSet();
  final local = email?.split('@').first ?? '';
  return [
    if (rasqCommonPasswords.contains(lower)) PasswordWeakness.common,
    if (runes.length == 1) PasswordWeakness.repeated,
    if ((handle != null && handle.isNotEmpty && lower == handle.toLowerCase()) || (email != null && lower == email.toLowerCase()) || (local.isNotEmpty && lower == local.toLowerCase()))
      PasswordWeakness.sameAsIdentity,
  ];
}

/// サーバーの「弱すぎる」の答えから要件を読む。一覧(`weaknesses`、docs/PASSWORD_STRENGTH.md の案)があればそれ、
/// 無ければ今の文(`password is too weak: <理由>`)から 1 つ。弱すぎるの答えでなければ null。
List<PasswordWeakness>? passwordWeaknessesFromServer({required String message, String? reason, Object? weaknesses}) {
  if (weaknesses is List) {
    final list = [for (final w in weaknesses) ...PasswordWeakness.values.where((v) => v.wire == w)];
    if (list.isNotEmpty) return list;
  }
  if (reason != 'password_weak' && !message.contains('too weak')) return null;
  if (message.contains('commonly used')) return const [PasswordWeakness.common];
  if (message.contains('repeats a single character')) return const [PasswordWeakness.repeated];
  if (message.contains('handle or email')) return const [PasswordWeakness.sameAsIdentity];
  return const [];
}

/// 「脆弱なパスワードです」+ 当たった要件のチップ。
class WeakPasswordNotice extends StatelessWidget {
  const WeakPasswordNotice({super.key, required this.weaknesses});
  final List<PasswordWeakness> weaknesses;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return Column(
      key: const ValueKey('password.weak'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Icon(Icons.gpp_maybe_outlined, size: 16, color: error),
          const SizedBox(width: 4),
          Flexible(child: Text(context.l10n.passwordStrengthWeakTitle, style: RasqTypography.bodySmall.copyWith(color: error, fontWeight: FontWeight.w600))),
        ]),
        if (weaknesses.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 4, children: [
            for (final w in weaknesses)
              Chip(
                key: ValueKey('password.weak.${w.wire}'),
                avatar: Icon(w.icon, size: 16, color: error),
                label: Text(w.label, style: RasqTypography.caption.copyWith(color: error)),
                side: BorderSide(color: error.withValues(alpha: 0.6)),
                backgroundColor: error.withValues(alpha: 0.06),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
          ]),
        ],
      ],
    );
  }
}
