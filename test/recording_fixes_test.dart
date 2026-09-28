import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/redact.dart';
import 'package:rasq_client/features/lists/lists_screens.dart' show withMemberIds;
import 'package:rasq_client/features/store/store_models.dart';
import 'package:rasq_client/features/vc/astell_fows.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_post_share.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// 2026-09-28 の録画で見つかった課題 (REC-03 / 04 / 10、TERMS-10) の修正。
void main() {
  test('REC-03: エラー文から URL のクエリ / トークン / Bearer を外す', () {
    const raw = "WebSocketException: Connection to 'http://192.168.32.161:8080/api/v1/astell/rooms/r1/ws?token=SECRET123&x=1#' was not upgraded to websocket";
    final r = redactSecrets(raw);
    expect(r, isNot(contains('SECRET123')));
    expect(r, contains('http://192.168.32.161:8080/api/v1/astell/rooms/r1/ws?…'));
    expect(redactSecrets('token=abc Bearer eyJhbGciOi.x.y i=zzz'), 'token=… Bearer … i=…');
    expect(wsConnectErrorMessage(Exception(raw)), 'ルームに入れませんでした(ルームが閉じているか、見つかりません)');
    expect(wsConnectErrorMessage(Exception('boom ws://h/ws?token=SECRET')), isNot(contains('SECRET')));
  });

  test('REC-10: 版の比較(数字ごと / プレリリースは前 / v 付き)', () {
    expect(compareVersions('0.1.1', '0.1.0'), greaterThan(0));
    expect(compareVersions('0.1.0', '0.1.1'), lessThan(0));
    expect(compareVersions('1.2.10', '1.2.9'), greaterThan(0));
    expect(compareVersions('1.0.0', '1.0'), 0);
    expect(compareVersions('1.0.0-beta', '1.0.0'), lessThan(0));
    expect(compareVersions('v2.0.0', '1.9.9'), greaterThan(0));
    expect(isNewerVersion('0.1.0', '0.1.1'), isFalse);
    expect(isNewerVersion('0.3.0', '0.1.0'), isTrue);
    expect(isNewerVersion('', '0.1.0'), isFalse);
    expect(isNewerVersion('0.1.0', null), isTrue);
  });

  test('TERMS-10: 共有しても閲覧注意と CW を引き継ぐ(payload → 復元 / 見出し / サムネイル)', () {
    const acct = AccountId(kind: SnsKind.misskey, instance: 'misskey.rasq.test', handle: 'me');
    final post = Post(
      id: 'n1',
      account: acct,
      author: UserSummary(id: 'u', account: acct, displayName: 'あなた'),
      createdAt: DateTime(2026, 9, 28),
      body: '本文',
      contentWarning: 'ネタバレ',
      visibility: 'public',
      media: [MediaItem(id: 'm', type: MediaType.image, url: Uri.parse('https://x/a.jpg'), sensitive: true)],
    );
    final payload = astellPostPayloadOf(post);
    expect(payload['sensitive'], isTrue);
    expect(((payload['media'] as List).single as Map)['sensitive'], isTrue);
    expect(payload['cw'], 'ネタバレ');
    final back = postFromSharePayload(payload, acct)!;
    expect(back.contentWarning, 'ネタバレ');
    expect(back.body, '本文');
    expect(back.media.single.sensitive, isTrue);
    final share = AstellShare(id: 's', accountId: 'a', handle: 'me', displayName: 'あなた', kind: 'post', payload: payload, createdAt: DateTime(2026, 9, 28));
    expect(share.isSensitive, isTrue);
    expect(share.contentWarning, 'ネタバレ');
    expect(share.headline, '⚠ ネタバレ(閲覧注意)');
    expect(share.thumbnailUrl, isNull);
  });

  testWidgets('REC-04: 顔ぶれが取れなくても人数は出す / ホストだけのとき', (tester) async {
    Future<String> textOf(Widget w) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
      return tester.widget<Text>(find.byKey(const ValueKey('astell.members.empty'))).data!;
    }

    expect(await textOf(const AstellMembersRow(peers: [], totalCount: 4)), '4 人が参加しています');
    expect(await textOf(const AstellMembersRow(peers: [], totalCount: 0, hostOnly: true)), 'ホストのほかには、まだ誰もいません');
    expect(await textOf(const AstellMembersRow(peers: [])), 'まだ誰もいません');
  });

  test('REC-06: メンバーの id を返さないリストは、メンバーを取って人数を埋める', () async {
    final s = _ListSession();
    final out = await withMemberIds(s, const [UserListInfo(id: 'a', name: 'A'), UserListInfo(id: 'b', name: 'B', memberIds: ['x']), UserListInfo(id: 'bad', name: 'Bad')]);
    expect([for (final l in out) l.memberIds.length], [3, 1, 0]);
    expect(s.asked, ['a', 'bad']);
  });
}

class _ListSession extends SnsSessionBase {
  @override
  final AccountId account = const AccountId(kind: SnsKind.mastodon, instance: 'mstdn.rasq.test', handle: 'me');
  @override
  String get pluginId => 'test.lists';
  final asked = <String>[];
  @override
  Future<List<UserSummary>> listMembers(String listId) async {
    asked.add(listId);
    if (listId == 'bad') throw StateError('x');
    return [for (var i = 0; i < 3; i++) UserSummary(id: 'u$i', account: account, displayName: 'u$i')];
  }
}
