import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_stats.dart';

/// RAi の実績と会話の保存 (D-214)。
void main() {
  test('RaiStats は JSON で往復し、実績は閾値で達成になる', () {
    const s = RaiStats(instructionsAsked: 10, assistantAsked: 3, assistantAppAsked: 2, instructionsCompleted: 1, repeatedAsks: 3);
    expect(RaiStats.fromJson(s.toJson()), s);
    expect(RaiStats.fromJson(const {}), const RaiStats());
    final p = {for (final x in raiAchievementProgress(s)) x.achievement.id: x};
    expect(p['ask1']!.unlocked, isTrue);
    expect(p['ask10']!.unlocked, isTrue);
    expect(p['ask50']!.unlocked, isFalse);
    expect(p['ask50']!.fraction, closeTo(0.2, 1e-9));
    expect(p['app5']!.unlocked, isFalse);
    expect(p['done1']!.unlocked, isTrue);
    expect(p['again3']!.unlocked, isTrue);
    expect(raiAchievements.map((a) => a.id).toSet().length, raiAchievements.length); // id は一意
  });

  test('会話は発言の履歴(新しい順)から作り、最初の質問が題名。JSON で往復', () {
    expect(RaiConversation.fromLog(const []), isNull);
    final log = [
      RaiUtterance(text: '2 つ目', at: DateTime(2026, 9, 14, 10, 5), query: 'q2'),
      RaiUtterance(text: '1 つ目', at: DateTime(2026, 9, 14, 10, 0), query: 'q1', error: true),
    ];
    final c = RaiConversation.fromLog(log)!;
    expect(c.title, 'q1');
    expect(c.startedAt, DateTime(2026, 9, 14, 10, 0));
    final back = RaiConversation.fromJson(c.toJson());
    expect(back.id, c.id);
    expect(back.title, 'q1');
    expect(back.log.length, 2);
    expect(back.log.first.text, '2 つ目');
    expect(back.log.last.error, isTrue);
    expect(back.log.last.query, 'q1');
    // 題名は質問が無ければ発言。
    expect(RaiConversation.fromLog([RaiUtterance(text: 'こんにちは', at: DateTime(2026))])!.title, 'こんにちは');
  });
}
