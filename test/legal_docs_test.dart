import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';
import 'package:rasq_client/backend/legal_docs.g.dart';
import 'package:rasq_client/backend/rasq_consent.dart';
import 'package:rasq_client/features/settings/settings_dsl.dart';

/// 規約・ポリシーの文書 (D-372 / 規約案 06 CONS-01): 正本(assets/legal/*.md)と表示(設定の文書ページ)と
/// 生成した定数が、同じ版・同じ本文のハッシュか。利用者向けの本文に内部の参照が混ざっていないか。
void main() {
  test('正本・表示・定数の版と本文のハッシュがそろっている', () {
    expect(rasqLegalDocs.keys, containsAll(['rasq.terms', 'rasq.privacy', 'rasq.learning', 'rasq.astell', 'rasq.rai', 'rasq.store', 'rasq.developer', 'rasq.billing', 'rasq.commerce']));
    for (final e in rasqLegalDocs.entries) {
      final md = File('assets/legal/${e.key}.md').readAsStringSync();
      final sha = sha256.convert(utf8.encode(md)).toString();
      expect(sha, e.value.sha256, reason: '${e.key}: 本文を変えたら tool/legal/build_legal.py を回す');
      final page = jsonDecode(File('assets/settings/${e.value.area}.rrl.json').readAsStringSync()) as Map<String, Object?>;
      final doc = page['doc']! as Map;
      expect(doc['id'], e.key);
      expect(doc['version'], rasqLegalVersion);
      expect(doc['bodySha256'], sha, reason: '${e.value.area}: 表示が本文と違う版から作られている');
      // 設定ページとして読める。
      final spec = SettingsPageSpec.fromJson(page);
      expect(spec.area, e.value.area);
    }
  });

  test('参考訳 (D-535): 承諾の値は日本語の正本のまま、訳の本文とハッシュがそろい、先頭に「日本語版が優先」の注記がある', () {
    for (final e in rasqLegalTranslations.entries) {
      final ja = rasqLegalDocs[e.key]!;
      for (final t in e.value.entries) {
        final md = File('assets/legal/${t.key}/${e.key}.md').readAsStringSync();
        expect(md, startsWith('> **'), reason: '${t.key}/${e.key}: 先頭は参考訳の注記');
        expect(sha256.convert(utf8.encode(md)).toString(), t.value.sha256, reason: '${t.key}/${e.key}: 訳を変えたら tool/legal/build_legal.py を回す');
        final page = jsonDecode(File('assets/settings/${t.key}/${ja.area}.rrl.json').readAsStringSync()) as Map<String, Object?>;
        final doc = page['doc']! as Map;
        expect(doc['id'], e.key);
        expect(doc['version'], rasqLegalVersion);
        expect(doc['bodySha256'], ja.sha256, reason: '承諾は日本語の文書に対して記録する');
        expect((page['translation']! as Map)['bodySha256'], t.value.sha256);
        expect(page['title'], t.value.title);
        expect(SettingsPageSpec.fromJson(page).area, ja.area);
        for (final bad in ['/Users/', 'src/', '.rs:', '.dart:']) {
          expect(md.contains(bad), isFalse, reason: '${t.key}/${e.key} に $bad');
        }
      }
    }
  });

  test('利用者向けの本文に内部メモ・コードの参照が混ざっていない', () {
    for (final e in rasqLegalDocs.entries) {
      final text = File('assets/legal/${e.key}.md').readAsStringSync() + File('assets/settings/${e.value.area}.rrl.json').readAsStringSync();
      for (final bad in ['/Users/', 'src/', '.rs:', '.dart:', '内部設計', '根拠コード']) {
        expect(text.contains(bad), isFalse, reason: '${e.key} に $bad');
      }
    }
  });

  test('承諾を求める版は文書の版', () {
    expect(rasqTermsVersion, rasqLegalVersion);
    expect(rasqPrivacyVersion, rasqLegalVersion);
  });

  testWidgets('どの文書ページも描ける(開発者モードでは本文のハッシュも)', (tester) async {
    for (final dev in [false, true]) {
      for (final e in rasqLegalDocs.entries) {
        final page = jsonDecode(File('assets/settings/${e.value.area}.rrl.json').readAsStringSync()) as Map<String, Object?>;
        final spec = SettingsPageSpec.fromJson(page);
        await tester.pumpWidget(MaterialApp(
          theme: RasqTheme.light(),
          home: RasqDeveloperMode(
            enabled: dev,
            child: Scaffold(body: ListView(children: [RrlRenderer(node: spec.root, host: RrlHost(instanceScope: 'test:-:0:x', scope: RrlScope(const {})))])),
          ),
        ));
        expect(tester.takeException(), isNull, reason: e.key);
        expect(find.textContaining('公開前の草案です'), findsOneWidget);
        expect(find.textContaining('本文の SHA-256'), dev ? findsOneWidget : findsNothing);
      }
    }
  });
}
