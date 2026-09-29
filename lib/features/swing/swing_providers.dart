import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../child_safe/child_safe_providers.dart';
import 'swing_client.dart';
import 'swing_models.dart';

/// Swing (D-377 / Central S-056) の状態。
///
/// - RASQ アカウントがあって Central に繋がっているときだけ。**見守られている端末では出さない**(見守りの設定に Swing の
///   項目がまだ無いので、止めておく)。
/// - フィードは起動時と [SwingFeed.interval] ごとに読み直す。見終えたもの([SwingFeed.markSeen])は手元からもすぐ消す。

final swingApiProvider = Provider<SwingApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  if (client == null || ref.watch(orgateAccountProvider).value == null) return null;
  if (ref.watch(childGateProvider).supervised) return null;
  return SwingApi(client);
});

class SwingFeed extends AsyncNotifier<List<Swing>> {
  /// 読み直す間隔(テストで短く / 止める)。null = 読み直さない。
  static Duration? interval = const Duration(seconds: 60);

  Timer? _timer;
  final _seen = <String>{};

  @override
  Future<List<Swing>> build() async {
    final api = ref.watch(swingApiProvider);
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (api == null) return const [];
    final every = interval;
    if (every != null) _timer = Timer.periodic(every, (_) => unawaited(refresh()));
    return _load(api);
  }

  Future<List<Swing>> _load(SwingApi api) async => [
        for (final s in await api.feed())
          if (!_seen.contains(s.id)) s,
      ];

  Future<void> refresh() async {
    final api = ref.read(swingApiProvider);
    if (api == null) return;
    try {
      final next = await _load(api);
      state = AsyncData(next);
    } catch (_) {
      // 読めないときは前のまま(次の間隔でまた読む)。
    }
  }

  /// 見終えた: 手元から消して Central へ。
  Future<void> markSeen(String id) async {
    if (!_seen.add(id)) return;
    final cur = state.value;
    if (cur != null) state = AsyncData([for (final s in cur) if (s.id != id) s]);
    try {
      await ref.read(swingApiProvider)?.seen(id);
    } catch (_) {
      // 送れなくても手元では消したまま(期限が来れば Central でも消える)。
    }
  }
}

final swingFeedProvider = AsyncNotifierProvider<SwingFeed, List<Swing>>(SwingFeed.new);

/// 自分が出している Swing(作る画面の下に出す)。
final mySwingsProvider = FutureProvider.autoDispose<List<Swing>>((ref) async {
  final api = ref.watch(swingApiProvider);
  if (api == null) return const [];
  return api.mine();
});

/// ヘッダーに並べる、Swing を出している人(新しい順)と、その人の見ていない数。
typedef SwingAuthorEntry = ({Swing first, int count});

final swingAuthorsProvider = Provider<List<SwingAuthorEntry>>((ref) {
  final feed = ref.watch(swingFeedProvider).value ?? const <Swing>[];
  final ordered = orderForViewer(feed);
  final out = <String, SwingAuthorEntry>{};
  for (final s in ordered) {
    final cur = out[s.authorAccountId];
    out[s.authorAccountId] = cur == null ? (first: s, count: 1) : (first: cur.first, count: cur.count + 1);
  }
  return out.values.toList();
});
