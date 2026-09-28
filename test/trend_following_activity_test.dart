import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/trend/trend_providers.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_models/rasq_models.dart';

/// 「フォロー中の反応」(D-364): AsTell のルームとリレーショナル TL の会話イベントを、トレンドのワードで拾う。
void main() {
  const viewer = AccountId(kind: SnsKind.misskey, instance: 'misskey.rasq.test', handle: 'me');
  final alice = UserSummary(id: 'alice', account: const AccountId(kind: SnsKind.misskey, instance: 'misskey.rasq.test', handle: 'alice'), displayName: 'alice');
  Post post(String id, String body) => Post(id: id, account: viewer, author: alice, createdAt: DateTime.utc(2026, 9, 28, 12), body: body);

  test('会話イベント: タグ / 特徴語 / 本文のどれかにワード(# と大文字小文字は無視)', () {
    expect(conversationMatchesTag(ConversationEvent.root(post('1', '打ち上げ見てる #Rocket')), '#rocket'), isTrue);
    expect(conversationMatchesTag(ConversationEvent.root(post('2', 'ロケットの打ち上げ成功')), 'ロケット'), isTrue);
    expect(conversationMatchesTag(ConversationEvent.root(post('3', '今日のラーメン')), 'ロケット'), isFalse);
    expect(conversationMatchesTag(ConversationEvent.root(post('4', 'x')), ''), isFalse);
  });

  test('AsTell のルーム: タイトル / 要約 / ジャンルにワード', () {
    AstellRoom room(Map<String, Object?> j) => AstellRoom.fromJson({'id': 'r', 'ownerId': 'o', 'title': '', 'createdAt': '2026-09-28T12:00:00Z', ...j});
    expect(astellRoomMatchesTag(room({'title': 'ロケット打ち上げ実況'}), '#ロケット'), isTrue);
    expect(astellRoomMatchesTag(room({'title': '雑談', 'genres': ['Rocket']}), 'rocket'), isTrue);
    expect(astellRoomMatchesTag(room({'title': '雑談', 'description': '打ち上げの話'}), '打ち上げ'), isTrue);
    expect(astellRoomMatchesTag(room({'title': '雑談'}), 'ロケット'), isFalse);
  });
}
