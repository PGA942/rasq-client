import 'package:rasq_store/rasq_store.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  test('ActionStateStore apply / optimistic / sum', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = c.read(actionStateProvider.notifier);
    s.apply('acc:p1', 'like', const ActionState(done: false, count: 10));
    s.applyOptimistic('acc:p1', 'like', done: true);
    expect(c.read(actionStateOfProvider((postKey: 'acc:p1', actionId: 'like'))), const ActionState(done: true, count: 11));
    s.apply('acc2:p1', 'like', const ActionState(done: true, count: 4));
    expect(s.sumCounts(['acc:p1', 'acc2:p1'], 'like'), 15);
    s.clearForAccount('acc');
    expect(s.of('acc:p1', 'like'), const ActionState());
    expect(s.of('acc2:p1', 'like').count, 4);
  });

  test('ReadStateStore', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = c.read(readStateProvider.notifier);
    expect(c.read(isReadProvider('a:1')), isFalse);
    s.markRead('a:1');
    expect(c.read(isReadProvider('a:1')), isTrue);
    s.markUnread('a:1');
    expect(c.read(isReadProvider('a:1')), isFalse);
  });

  test('FollowStateStore', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(followStateProvider.notifier).apply('v', 'u', const FollowState(following: true, followedBy: true));
    expect(c.read(followStateOfProvider((viewer: 'v', user: 'u'))).followedBy, isTrue);
  });

  test('TtlCache evicts by TTL and LRU', () {
    var now = DateTime(2026);
    final cache = TtlCache<String, int>(const CachePolicy(ttl: Duration(minutes: 1), maxEntries: 2), clock: () => now);
    cache.put('a', 1);
    cache.put('b', 2);
    cache.get('a'); // a becomes MRU
    cache.put('c', 3); // evicts b
    expect(cache.get('b'), isNull);
    expect(cache.get('a'), 1);
    now = now.add(const Duration(minutes: 2));
    expect(cache.get('a'), isNull);
    expect(cache.evictExpired(), 1); // c
  });
}
