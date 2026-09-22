import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/backend/rasq_account_page_api.dart';
import 'package:rasq_client/features/profile/rasq_queue_prediction.dart';

/// キューの予測 (D-279)。
void main() {
  final central = Uri.parse('https://central.test');
  RasqQueueCount q(String pack, String sticker, int count, {bool like = false}) =>
      RasqQueueCount(packId: like ? null : pack, stickerId: sticker, url: like ? null : Uri.parse('https://central.test/api/v1/plugins/$pack/stickers/$sticker'), like: like, count: count);

  test('投稿に付いているキューのうち、持っているパックの絵だけが候補。投稿ごとに決まった 1 つ', () {
    final post = RasqAccountPost(id: 'p1', body: '', queues: [q('pack.a', 'star', 9), q('pack.b', 'moon', 3), q('', 'like', 20, like: true)]);
    // 持っていないパックしか付いていなければ、予測しない(いいねは候補にしない)。
    expect(predictQueue(post, ownedPacks: const {}, central: central), isNull);
    final one = predictQueue(post, ownedPacks: const {'pack.b'}, central: central)!;
    expect((one.packId, one.stickerId), ('pack.b', 'moon'));
    // 同じ投稿なら、何度聞いても同じ。
    final a = predictQueue(post, ownedPacks: const {'pack.a', 'pack.b'}, central: central)!;
    final b = predictQueue(post, ownedPacks: const {'pack.a', 'pack.b'}, central: central)!;
    expect((a.packId, a.stickerId), (b.packId, b.stickerId));
  });

  test('だれも付けていなければ、最近使った自分の絵(持っているパックのものだけ)', () {
    const post = RasqAccountPost(id: 'p2', body: '');
    expect(predictQueue(post, ownedPacks: const {'pack.a'}, recent: const ['👍', 'pack.gone|x', 'pack.a|star'], central: central)?.url.toString(), 'https://central.test/api/v1/plugins/pack.a/stickers/star');
    expect(predictQueue(post, ownedPacks: const {'pack.a'}, recent: const ['👍'], central: central), isNull);
    expect(predictQueue(post, ownedPacks: const {'pack.a'}, recent: const ['pack.a|star']), isNull, reason: '接続先が無ければ、絵の URL を作れない');
  });
}
