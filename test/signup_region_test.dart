import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/features/onboarding/region/region.dart';
import 'package:rasq_client/features/onboarding/region/region_names_ja.dart';
import 'package:rasq_models/rasq_models.dart';

/// 住んでいる地域の申告 (D-542 / ORGATE O-018): 一覧の読み方・提供の可否・名前と探し方・エラーの理由。
void main() {
  test('GET /regions の答えを読み、提供していない国 / 州を見分ける(国ごと止めた国は州も)', () {
    final r = RasqRegions.fromJson({
      'countries': [
        {'code': 'JP', 'available': true},
        {'code': 'DE', 'available': false},
        {
          'code': 'US',
          'available': true,
          'subdivisions': [
            {'code': 'US-CA', 'available': true},
            {'code': 'US-UT', 'available': false},
          ],
        },
        {'code': 'AU'},
        'broken',
        {'available': true},
      ],
      'unavailable': ['DE', 'US-UT', 'AU'],
    });
    expect(r.fromServer, isTrue);
    expect(r.countries.map((c) => c.code), ['JP', 'DE', 'US', 'AU']);
    expect(r.country('US')!.subdivisions.map((s) => s.code), ['US-CA', 'US-UT']);
    expect(r.isAvailable('JP'), isTrue);
    expect(r.isAvailable('DE'), isFalse);
    expect(r.isAvailable('AU'), isFalse, reason: 'unavailable の一覧にある');
    expect(r.isAvailable('US-CA'), isTrue);
    expect(r.isAvailable('US-UT'), isFalse);
    final blockedUs = RasqRegions.fromJson({
      'countries': [
        {'code': 'US', 'available': false},
      ],
      'unavailable': ['US'],
    });
    expect(blockedUs.isAvailable('US-CA'), isFalse);
  });

  test('一覧を読めないときは、名前の表の地域を全部選べる(サーバーが作るときに決める)', () {
    final r = RasqRegions.fallback();
    expect(r.fromServer, isFalse);
    expect(r.countries.length, regionNamesJa.length);
    expect(r.country('US')!.subdivisions.length, 51);
    expect(r.isAvailable('GB'), isTrue);
    expect(r.isAvailable('US-UT'), isTrue);
  });

  test('名前は表示の言語の表から(州は「国・州」)。名前・かなの読み・コードで探せる', () {
    expect(RasqUiLocale.tag, 'ja');
    expect(regionNamesJa.length, 250);
    expect(usStateNamesJa.length, 51);
    expect(regionName('JP'), '日本');
    expect(regionName('US-CA'), 'アメリカ合衆国・カリフォルニア州');
    expect(regionStateName('US-UT'), 'ユタ州');
    expect(regionName('ZZ'), 'ZZ', reason: '表に無いコードはそのまま');
    expect(regionMatches('JP', 'にほん'), isTrue);
    expect(regionMatches('JP', 'jp'), isTrue);
    expect(regionMatches('DE', 'どいつ'), isTrue, reason: 'ひらがなでカタカナの名前に当たる');
    expect(regionMatches('DE', 'にほん'), isFalse);
    expect(regionMatches('US-CA', 'カリフォルニア'), isTrue);
    expect(regionMatches('KR', ''), isTrue);
    // 並べる順は読みで(漢字の名前も五十音の中に入る)。
    final sorted = ['JP', 'DE', 'KR', 'AU']..sort((a, b) => regionSortKey(a).compareTo(regionSortKey(b)));
    expect(sorted, ['AU', 'KR', 'DE', 'JP']);
  });

  test('作るときのエラーは理由の名前で見る(region_not_served / region_required)', () {
    final notServed = OrgateException(ErrorCode.http(403), 'お住まいの地域では、いまは RASQ を提供していません', serverCode: 'region_not_served');
    final required = OrgateException(ErrorCode.http(400), '住んでいる地域を選んでください', serverCode: 'region_required');
    expect(notServed.isReason('region_not_served'), isTrue);
    expect(notServed.isReason('region_required'), isFalse);
    expect(required.isReason('region_required'), isTrue);
  });
}
