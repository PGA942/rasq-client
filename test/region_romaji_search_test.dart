import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/compose/kana_romaji.dart';
import 'package:rasq_client/features/onboarding/region/region.dart';
import 'package:rasq_client/features/onboarding/region/region_picker.dart';
import 'package:rasq_client/l10n/gen/app_localizations.dart';
import 'package:rasq_models/rasq_models.dart';

/// 住んでいる地域のローマ字検索 (D-573)。
void main() {
  group('ローマ字の鍵', () {
    void same(List<String> spellings) {
      final keys = spellings.map(romajiSearchKey).toSet();
      expect(keys.length, 1, reason: '$spellings → $keys');
    }

    test('ヘボン式と訓令式 / 日本式の揺れをそろえる', () {
      same(['shibuya', 'sibuya', 'Shibuya']);
      same(['chiba', 'tiba']);
      same(['fukuoka', 'hukuoka']);
      same(['tsukuba', 'tukuba']);
      same(['shinjuku', 'sinzyuku', 'sinjuku']);
      same(['chuo', 'tyuo']);
      same(['jo', 'zyo', 'jyo']);
      same(['fuji', 'huzi', 'hudi']);
    });

    test('長音の有無・促音・撥音の m / n をそろえる', () {
      same(['tokyo', 'toukyou', 'tookyoo', 'tōkyō', 'Tôkyô', 'tohkyoh']);
      same(['osaka', 'oosaka', 'ōsaka', 'ohsaka']);
      same(['sapporo', 'saporo']);
      same(['shinbashi', 'shimbashi']);
      same(['matcha', 'maccha']);
      // 空白・記号・大文字は見ない。
      same(['new york', 'New-York', 'newyork']);
    });

    test('かなの名前の鍵も同じ形(打った語と比べられる)', () {
      expect(kanaSearchKey('とうきょうと'), contains(romajiSearchKey('tokyo')));
      expect(kanaSearchKey('しぶやく'), contains(romajiSearchKey('shibuya')));
      expect(kanaSearchKey('さっぽろし'), contains(romajiSearchKey('sapporo')));
      expect(kanaSearchKey('ドイツ'), romajiSearchKey('doitsu'));
      expect(kanaSearchKey('ベルギー'), romajiSearchKey('berugii'));
      expect(romajiSearchKey('東京'), '', reason: '英字の無い語は鍵を作らない');
    });
  });

  group('地域の検索', () {
    setUp(() => RasqUiLocale.tag = 'ja');

    test('国の名前をローマ字(長音の有無も)で引ける', () {
      expect(regionMatches('JP', 'nihon'), isTrue);
      expect(regionMatches('JP', 'nippon'), isFalse, reason: '読みは「にほん」');
      expect(regionMatches('FR', 'furansu'), isTrue);
      expect(regionMatches('US', 'amerika'), isTrue);
      expect(regionMatches('DE', 'doitu'), isTrue);
      expect(regionMatches('BE', 'berugii'), isTrue);
      expect(regionMatches('CN', 'chuugoku'), isTrue);
      expect(regionMatches('CN', 'tyugoku'), isTrue);
      expect(regionMatches('DE', 'furansu'), isFalse);
    });

    test('英語の名前でも、語の頭から引ける(2 文字のコードが名前の途中に当たらない)', () {
      expect(regionMatches('JP', 'japan'), isTrue);
      expect(regionMatches('KR', 'korea'), isTrue);
      expect(regionMatches('CI', 'cote'), isTrue, reason: 'アクセントは見ない');
      expect(regionMatches('AU', 'us'), isFalse, reason: 'Australia の途中の us');
      expect(regionMatches('US', 'us'), isTrue);
    });

    test('日本の都道府県・市・区の名前(ローマ字 / 漢字 / かな)で日本に当たり、当たった地名を返す', () {
      expect(regionMatch('JP', 'tokyo')?.via, '東京都');
      expect(regionMatch('JP', 'toukyou')?.via, '東京都');
      expect(regionMatch('JP', 'shibuya')?.via, '渋谷区');
      expect(regionMatch('JP', 'sibuya')?.via, '渋谷区');
      expect(regionMatch('JP', 'sapporo')?.via, '札幌市');
      expect(regionMatch('JP', 'hukuoka')?.via, '福岡県');
      expect(regionMatch('JP', '横浜')?.via, '横浜市');
      expect(regionMatch('JP', 'しぶや')?.via, '渋谷区');
      expect(regionMatch('JP', 'nihon')?.via, isNull, reason: '国の名前そのものに当たれば地名は添えない');
      expect(regionMatches('FR', 'tokyo'), isFalse);
    });

    test('国の一覧では、アメリカの州の名前でアメリカに当たる', () {
      expect(regionMatch('US', 'california')?.via, 'カリフォルニア州');
      expect(regionMatch('US', 'kariforunia')?.via, 'カリフォルニア州');
      expect(regionMatch('US', 'カリフォルニア')?.via, 'カリフォルニア州');
      // 州の一覧の中でも同じに引ける。
      expect(regionMatches('US-CA', 'california'), isTrue);
      expect(regionMatches('US-NY', 'nyuyoku'), isTrue);
    });

    test('表示の言語が英語でも、ローマ字と日本の地名で引ける', () {
      RasqUiLocale.tag = 'en';
      addTearDown(() => RasqUiLocale.tag = 'ja');
      expect(regionMatches('JP', 'japan'), isTrue);
      expect(regionMatches('JP', 'nihon'), isTrue);
      expect(regionMatch('JP', 'shibuya')?.via, '渋谷区');
    });
  });

  testWidgets('選ぶ画面: ローマ字で探すと日本が出て、当たった地名を添える', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('ja'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RegionPickerScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('region.search')), 'shibuya');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('region.country.JP')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('region.country.JP')), matching: find.text('渋谷区')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('region.search')), 'furansu');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('region.country.FR')), findsOneWidget);
    expect(find.byKey(const ValueKey('region.country.JP')), findsNothing);
  });
}
