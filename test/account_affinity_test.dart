import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/home/account_affinity.dart';
import 'package:rasq_models/rasq_models.dart';

/// どのアカウントで共有 / リノートするかの予測 (D-280)。
void main() {
  const mk = AccountId(kind: SnsKind.misskey, instance: 'mk.example', handle: 'me');
  const md = AccountId(kind: SnsKind.mastodon, instance: 'md.example', handle: 'me');
  const hanako = UserSummary(id: 'u1', account: AccountId(kind: SnsKind.misskey, instance: 'other.example', handle: 'hanako'), displayName: 'ハナコ');
  final now = DateTime(2026, 9, 20);
  final post = Post(id: 'p1', account: mk, author: hanako, createdAt: now, body: 'x');
  AffinityRecord rec(AccountId a, String author, String host, int daysAgo) => (account: a.key, author: author, host: host, at: now.subtract(Duration(days: daysAgo)).millisecondsSinceEpoch);

  test('その相手とよく話しているアカウントを選ぶ。新しいやりとりほど重い', () {
    final records = [rec(md, hanako.account.key, 'other.example', 1), rec(mk, hanako.account.key, 'other.example', 30)];
    expect(predictAccount(records, post, [mk.key, md.key], now: now), md.key);
    // 同じサーバーの別の人とのやりとりは、弱い手がかり。本人とのやりとりが勝つ。
    final mixed = [rec(mk, 'misskey:other.example:someone', 'other.example', 0), rec(md, hanako.account.key, 'other.example', 0)];
    expect(predictAccount(mixed, post, [mk.key, md.key], now: now), md.key);
  });

  test('決め手が無い / 候補が 1 つなら、予測しない', () {
    expect(predictAccount(const [], post, [mk.key, md.key], now: now), isNull);
    expect(predictAccount([rec(md, 'misskey:far.example:x', 'far.example', 0)], post, [mk.key, md.key], now: now), isNull);
    expect(predictAccount([rec(md, hanako.account.key, 'other.example', 0)], post, [md.key], now: now), isNull);
    // 候補に無いアカウントの履歴は使わない。
    expect(predictAccount([rec(md, hanako.account.key, 'other.example', 0)], post, [mk.key, 'bluesky:bsky.social:me'], now: now), isNull);
  });
}
