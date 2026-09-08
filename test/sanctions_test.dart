import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/session/sanctions.dart';

void main() {
  group('アカウント処置 (D-151)', () {
    test('GET /me/sanctions の形を読む', () {
      final s = RasqSanctions.fromJson({
        'level': 'light',
        'restrictedFeatures': ['post', 'astell.create'],
        'reviewDelaySeconds': 0,
        'categories': ['spam'],
        'expiresAt': '2026-09-09T06:00:00Z',
        'sanctions': [
          {'note': 'スパム投稿のため', 'level': 'light'},
          {'note': '', 'level': 'light'},
        ],
      });
      expect(s.active, isTrue);
      expect(s.levelLabel, '軽度な制限');
      expect(s.restricts('post'), isTrue);
      expect(s.restricts('dm'), isFalse);
      expect(s.blockedMessage('post'), contains('投稿 は利用できません'));
      expect(s.blockedMessage('post'), contains('まで'));
      expect(s.blockedMessage('dm'), isNull);
      expect(s.notes, ['スパム投稿のため']);
      expect(s.moderated, isFalse);
    });

    test('中レベル = 検閲遅延、恒久 = 期限なし', () {
      final m = RasqSanctions.fromJson({'level': 'moderate', 'reviewDelaySeconds': 30});
      expect(m.moderated, isTrue);
      expect(m.levelLabel, contains('検閲遅延'));
      final p = RasqSanctions.fromJson({'level': 'permanent', 'restrictedFeatures': ['post']});
      expect(p.expiresAt, isNull);
      expect(p.blockedMessage('post'), isNot(contains('まで')));
      expect(RasqSanctions.none.active, isFalse);
      expect(RasqSanctions.fromJson({}).levelLabel, '制限なし');
    });
  });
}
