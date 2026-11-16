import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/features/rai/prompts/rai_prompts.dart';
import 'package:rasq_client/features/rai/rai_embedding_model.dart';
import 'package:rasq_client/features/rai/rai_llm.dart';
import 'package:rasq_client/features/rai/rai_providers.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/features/rai/rai_reference_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../tool/rai_reference_eval.dart';
import 'support/fake_rai_embedding_model.dart';
import 'support/fake_rai_llm.dart';
import 'support/fakes.dart';

/// RAi のインストラクションの拡充 (D-585): 案内の無かった機能の操作リファレンス / 当たらなかったときに近い操作を添える。
void main() {
  const added = ['bug-report', 'settings-language', 'onboarding-language', 'viewer-next-post', 'viewer-close', 'viewer-actions', 'attach-drop', 'attach-reorder', 'emoji-name-search', 'region-search', 'password-weak', 'icon-theme'];

  Future<RaiReferenceIndex> load() => RaiReferenceIndex.fromJsonl(
        functionsJsonl: File('assets/rai/functions.jsonl').readAsStringSync(),
        operationsJsonl: File('assets/rai/operations.jsonl').readAsStringSync(),
        embedder: const NgramRaiEmbedder(),
      );

  group('足した操作リファレンス', () {
    test('どれも手順が展開でき、関数が引ける', () async {
      final index = await load();
      for (final id in added) {
        final op = index.operation(id);
        expect(op, isNotNull, reason: id);
        expect(index.expand(op!), isNotEmpty, reason: id);
        for (final s in op.steps) {
          if (s.fn != null) expect(index.function(s.fn!), isNotNull, reason: '$id: ${s.fn}');
        }
      }
    });

    test('評価の問い(足した分)は n-gram の代わりでも上位 3 つに入る(9 割以上)', () async {
      final index = await load();
      final evals = [for (final j in parseJsonl(File('assets/rai/eval.jsonl').readAsStringSync())) if (added.contains(j['op'])) j];
      expect(evals.length, greaterThanOrEqualTo(added.length * 2));
      final r = await evaluate(index, evals);
      expect(r.topK, greaterThanOrEqualTo(0.9), reason: r.misses.map((m) => '${m.query} → ${m.got}').join('; '));
    });
  });

  group('近い操作を添える文 (D-585)', () {
    for (final e in raiPromptCatalogs.entries) {
      test('表 ${e.key}', () {
        final p = e.value;
        final withOps = p.instructionNearBlock(['- 設定: 全ての設定', '- 投稿する: ＋ → 送信']);
        expect(withOps, startsWith('\n'));
        expect(withOps, allOf(contains('- 設定: 全ての設定'), contains('- 投稿する: ＋ → 送信')));
        final none = p.instructionNearBlock(const []);
        expect(none, startsWith('\n'));
        expect(none.trim(), isNotEmpty, reason: '近いものが無くても「作らない」頼みは添える');
      });
    }
  });

  group('インストラクションで当たらなかったとき', () {
    late FakeRaiLlm llm;
    setUp(() => llm = FakeRaiLlm(phase: RaiLlmPhase.ready));

    Future<ProviderContainer> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = MemorySessionStorage({SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key})});
      final registry = PluginRegistry()..register(FakeSnsPlugin(posts: (_) => const []));
      await tester.pumpWidget(ProviderScope(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
        raiLlmProvider.overrideWithValue(llm),
        raiEmbeddingModelProvider.overrideWithValue(FakeRaiEmbeddingModel()),
        deviceRamReaderProvider.overrideWithValue(() async => (totalMb: 8192, availableMb: 4096)),
      ], child: const RasqApp()));
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      await tester.runAsync(() => c.read(raiReferenceProvider.future));
      await tester.pumpAndSettle();
      c.read(raiProvider.notifier).setMode(RaiMode.instruction);
      await tester.pumpAndSettle();
      return c;
    }

    Future<void> ask(WidgetTester tester, String q) async {
      final c = ProviderScope.containerOf(tester.element(find.byType(RasqApp)));
      final done = c.read(raiProvider.notifier).ask(q);
      await tester.pumpAndSettle();
      await done;
    }

    testWidgets('近い操作(案内の閾値には届かない)を LLM の指示に添え、作らないよう頼む', (tester) async {
      final c = await pump(tester);
      final index = c.read(raiReferenceProvider).value!;
      // 案内は始まらないが、近い操作のある問いを選ぶ(n-gram の代わりの埋め込みで決まる)。
      String? q;
      for (final cand in ['設定の色あいを変えるやり方', 'ほかのアプリの写真を入れたい感じ', 'エラーが出てしまったときの記録', '言葉の表示をどうにかしたい', '投稿の公開のしかたを知りたい']) {
        final hits = await tester.runAsync(() => index.searchOperations(cand));
        final near = await tester.runAsync(() => index.searchOperations(cand, threshold: raiInstructionNearThreshold));
        if (hits!.isEmpty && near!.isNotEmpty) {
          q = cand;
          break;
        }
      }
      expect(q, isNotNull, reason: '閾値の間に入る問いが見本にある');
      llm.reply = '設定から変えられます。';
      await ask(tester, q!);
      expect(llm.systems.last, startsWith(raiPrompts.instructionSystem));
      expect(llm.systems.last, contains(raiPrompts.instructionNearBlock(const []).trim()));
      expect(llm.systems.last, contains('参考(近い操作'));
      expect(c.read(raiProvider).bubble, '設定から変えられます。');
    });

    testWidgets('まったく関係の無い問いには参考を添えない(頼みだけ)', (tester) async {
      await pump(tester);
      await ask(tester, 'zzzz qqqq');
      expect(llm.systems.last, '${raiPrompts.instructionSystem}${raiPrompts.instructionNearBlock(const [])}');
    });
  });
}
