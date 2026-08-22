/// Cache policy: TTL + entry cap (UI_status「キャッシュ戦略」— アプリ側保存方針は確定、
/// TTL/容量上限は未確定 → defaults here are placeholders to be tuned).
class CachePolicy {
  const CachePolicy({this.ttl = const Duration(minutes: 30), this.maxEntries = 500});
  final Duration ttl;
  final int maxEntries;

  static const timeline = CachePolicy(ttl: Duration(minutes: 30), maxEntries: 1000);
  static const profile = CachePolicy(ttl: Duration(hours: 6), maxEntries: 300);
  static const media = CachePolicy(ttl: Duration(days: 7), maxEntries: 2000);
}

class _Entry<V> {
  _Entry(this.value, this.storedAt);
  final V value;
  final DateTime storedAt;
}

/// Small in-memory LRU with TTL. Persistent cache (drift) lands in M1.
class TtlCache<K, V> {
  TtlCache(this.policy, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final CachePolicy policy;
  final DateTime Function() _clock;
  final Map<K, _Entry<V>> _map = {};

  int get length => _map.length;

  V? get(K key) {
    final e = _map.remove(key);
    if (e == null) return null;
    if (_clock().difference(e.storedAt) > policy.ttl) return null;
    _map[key] = e; // move to MRU
    return e.value;
  }

  void put(K key, V value) {
    _map.remove(key);
    _map[key] = _Entry(value, _clock());
    while (_map.length > policy.maxEntries) {
      _map.remove(_map.keys.first);
    }
  }

  void invalidate(K key) => _map.remove(key);
  void clear() => _map.clear();

  /// Drops expired entries; returns how many were removed.
  int evictExpired() {
    final now = _clock();
    final expired = [for (final e in _map.entries) if (now.difference(e.value.storedAt) > policy.ttl) e.key];
    for (final k in expired) {
      _map.remove(k);
    }
    return expired.length;
  }
}
