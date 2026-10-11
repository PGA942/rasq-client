import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/compose_policy/compose_policy.dart';
import 'package:rasq_client/features/compose_policy/compose_signals.dart';

/// 送る前の判定 (D-462 / Central S-102): 端末の測り方と、閾値・倒し方の決まり。
void main() {
  group('測り方', () {
    test('語彙: 当たり数で飽和、英字の語は単語の切れ目だけ', () {
      expect(lexiconScore(0), 0);
      expect(lexiconScore(1), 0.5);
      expect(lexiconScore(2), 0.75);
      expect(measureText('lexicon', 'sexual', 'Sussex に行った')!.score, 0);
      expect(measureText('lexicon', 'sexual', 'send nudes')!.score, 0.5);
      final m = measureText('lexicon', 'harassment', 'お前クズ、死ね')!;
      expect(m.score, 0.75);
      expect('お前クズ、死ね'.substring(m.hit!.start, m.hit!.end), 'クズ');
      // 誤判定しやすい語は入れていない。
      expect(measureText('lexicon', 'harassment', 'カスタムのゴミ出しばかり')!.score, 0);
    });

    test('形: 電話番号 / メール / 郵便番号 / 住所 / LINE の ID / URL。SNS の宛先や日付は当てない', () {
      double pi(String t) => measureText('pattern', 'personal-info', t)!.score.toDouble();
      expect(pi('090-1234-5678'), 1);
      expect(pi('03 1234 5678 まで'), 1);
      expect(pi('kid@example.com に送って'), 1);
      expect(pi('〒100-0001'), 1);
      expect(pi('千代田区千代田1-1 です'), 1);
      expect(pi('LINE ID: kid_123'), 1);
      expect(pi('@alice@misskey.io おはよう'), 0);
      expect(pi('2026-10-11 の 12:30'), 0);
      expect(pi('電話は 12345'), 0);
      expect(measureText('pattern', 'link', 'みて https://example.test/x')!.score, 1);
      expect(measureText('pattern', 'link', 'リンクなし')!.score, 0);
      expect(measureText('model-x', 'sexual', 'x'), isNull);
    });
  });

  group('方針', () {
    test('Central の応答を読む(閾値 / 動き / モード / 種類の名前)、控えの形で往復できる', () {
      final p = ComposePolicy.fromJson({
        'schema': 'rasq.compose-policy/1',
        'version': 'abc',
        'refreshSeconds': 3600,
        'modes': [
          {'mode': 'sanction', 'level': 'moderate', 'expiresAt': '2026-10-12T00:00:00Z'},
        ],
        'rules': [
          {'type': 'personal-info', 'mode': 'sanction', 'action': 'block', 'threshold': 1, 'signal': 'pattern'},
          {'type': 'x', 'mode': 'sanction', 'action': 'maybe', 'threshold': 1, 'signal': 'pattern'},
        ],
        'types': [
          {'id': 'personal-info', 'label': '個人情報', 'signal': 'pattern'},
        ],
      });
      expect(p.modes, {'sanction': 'moderate'});
      expect(p.rules, hasLength(1));
      expect(p.labelOf('personal-info'), '個人情報');
      expect(p.labelOf('sexual'), '性的な表現');
      final back = ComposePolicy.fromJson(p.toJson());
      expect(back.version, p.version);
      expect(back.modes, p.modes);
      expect(back.labels, p.labels);
      expect(back.rules, p.rules);
    });

    test('見守り: Central の方針が無い / 見守りのモードが無ければ、組み込みの既定(強さごと)を足す', () {
      expect(effectiveComposePolicy(null).rules, isEmpty);
      final fallback = effectiveComposePolicy(null, childLevel: 'standard');
      expect(fallback.modes, {'child-safe': 'standard'});
      expect(fallback.rules.map((r) => '$r'), contains('child-safe:link:warn:1.0'));
      const sanctionOnly = ComposePolicy(modes: {'sanction': 'light'}, rules: [ComposeRule(type: 'link', mode: 'sanction', action: ComposeAction.warn, threshold: 1, signal: 'pattern')]);
      expect(effectiveComposePolicy(sanctionOnly, childLevel: 'strict').rules, hasLength(1 + childSafeFallbackRules('strict').length));
      const central = ComposePolicy(modes: {'child-safe': 'mild'}, rules: []);
      expect(effectiveComposePolicy(central, childLevel: 'strict').rules, isEmpty);
    });

    test('判定: 閾値以上で当たり。止めるもの → 見守りが先。止めた種類はモードごとに 1 つ', () {
      final p = ComposePolicy(rules: [
        ...childSafeFallbackRules('strict'),
        const ComposeRule(type: 'harassment', mode: 'sanction', action: ComposeAction.block, threshold: 0.5, signal: 'lexicon'),
        const ComposeRule(type: 'violence', mode: 'sanction', action: ComposeAction.warn, threshold: 0.5, signal: 'lexicon'),
      ]);
      expect(evaluateCompose(p, const ComposeInput(texts: ['今日は晴れ'])).first, isNull);
      final v = evaluateCompose(p, const ComposeInput(texts: ['お前バーカ', 'お前バーカ(加工)']));
      expect(v.blocked, isTrue);
      expect(v.first!.mode, 'child-safe');
      expect(v.first!.message, '保護者の設定により、「暴言・嫌がらせ」に当たる内容は送れません。書き換えてください');
      expect(v.blockedTypes, [(type: 'harassment', mode: 'child-safe'), (type: 'harassment', mode: 'sanction')]);
      // 範囲は入力欄の本文(先頭)にだけ。
      expect((v.first!.start, v.first!.end), (2, 5));
      // 2 回当たらないと止めない閾値(0.75)。
      final mild = ComposePolicy(rules: childSafeFallbackRules('mild'));
      expect(evaluateCompose(mild, const ComposeInput(texts: ['セックス'])).blocked, isFalse);
      expect(evaluateCompose(mild, const ComposeInput(texts: ['セックス セックス'])).blocked, isTrue);
      final warn = evaluateCompose(mild, const ComposeInput(texts: ['うざい']));
      expect((warn.blocked, warn.warns.single.type), (false, 'harassment'));
      expect(warn.first!.message, contains('このまま送りますか'));
    });

    test('判定できない種類: 見守りの block は止める側、制限 / warn は通す側', () {
      final cs = ComposePolicy(rules: childSafeFallbackRules('strict'));
      // 添付が無ければ画像の判定は要らない。
      expect(evaluateCompose(cs, const ComposeInput(texts: ['ねこ'])).blocked, isFalse);
      final media = evaluateCompose(cs, const ComposeInput(texts: ['ねこ'], mediaCount: 1));
      expect((media.blocked, media.first!.type, media.first!.unmeasured), (true, 'media', true));
      expect(media.first!.message, contains('添付を外してください'));
      // 端末に判定があれば、その点数で決める。
      expect(evaluateCompose(cs, const ComposeInput(texts: ['ねこ'], mediaCount: 1, imageScores: {'media': 0.1})).blocked, isFalse);
      const sanction = ComposePolicy(rules: [
        ComposeRule(type: 'media', mode: 'sanction', action: ComposeAction.block, threshold: 0.5, signal: 'image'),
        ComposeRule(type: 'sexual', mode: 'sanction', action: ComposeAction.block, threshold: 0.5, signal: 'text-model'),
        ComposeRule(type: 'sexual', mode: 'child-safe', action: ComposeAction.warn, threshold: 0.5, signal: 'text-model'),
      ]);
      expect(evaluateCompose(sanction, const ComposeInput(texts: ['ねこ'], mediaCount: 2)).trips, isEmpty);
      // 知らない測り方: 見守りの block だけ止める(中身があるとき)。
      const unknown = ComposePolicy(rules: [ComposeRule(type: 'sexual', mode: 'child-safe', action: ComposeAction.block, threshold: 0.5, signal: 'text-model')]);
      expect(evaluateCompose(unknown, const ComposeInput(texts: ['ねこ'])).first?.unmeasured, isTrue);
      expect(evaluateCompose(unknown, const ComposeInput(texts: [''])).blocked, isFalse);
    });

    test('Central の既定と同じ値(見守り)', () {
      expect(childSafeFallbackRules('strict').map((r) => '$r'), [
        'child-safe:sexual:block:0.5',
        'child-safe:violence:block:0.5',
        'child-safe:self-harm:block:0.5',
        'child-safe:harassment:block:0.5',
        'child-safe:personal-info:block:1.0',
        'child-safe:link:block:1.0',
        'child-safe:media:block:0.5',
      ]);
      expect(childSafeFallbackRules('nope'), childSafeFallbackRules('strict'));
    });
  });
}
