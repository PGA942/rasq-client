import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/redact.dart';
import '../swing/swing_models.dart';
import '../swing/swing_providers.dart';
import '../vc/astell_models.dart';
import '../vc/astell_providers.dart';
import 'home_header.dart';
import '../../l10n/l10n.dart';

/// フォロー中の人の Swing / AsTell を、出たときにすぐヘッダーへ (D-449)。
///
/// Central の `GET /api/v1/me/events`(WebSocket、S-087)を開いておき、届いたものをその場で並べる:
/// - `{"type":"swing","swing":{…}}` → Swing のフィードに足す(ヘッダーの新着 [HeaderArrivals] がフィードを見ている)。
/// - `{"type":"astell","room":{…}}` → ヘッダーの新着に足し、AsTell のホームを読み直す。
/// これまでの読み直し(Swing は 60 秒おき)はそのまま残す(つながらないときの縮退)。WebTransport は Flutter に
/// クライアントが無く、HTTP/3 も要るので、AsTell / カスタムセッションと同じ WebSocket にした。
/// 切れたら 5 秒 → 倍々(5 分まで)で繋ぎ直す。RASQ アカウントにログインしていなければ繋がない。

/// 繋ぐ口(テストで差し替える)。null = 繋がない(ログインしていない)。
typedef LiveEventsConnect = Future<Stream<Map<String, Object?>>> Function();

final liveEventsConnectProvider = Provider<LiveEventsConnect?>((ref) {
  // テスト中(`FLUTTER_TEST`)は繋がない(繋ぎ直しのタイマーを残さない)。確かめるテストはこのプロバイダーを差し替える。
  if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return null;
  final base = ref.watch(centralBaseUrlProvider);
  final account = ref.watch(orgateAccountProvider).value;
  if (base == null || account == null) return null;
  final holder = ref.read(orgateTokenHolderProvider);
  return () async {
    await holder.ensureFresh();
    final t = holder.token;
    if (t == null) throw StateError(appL10n.homeLiveNoToken);
    // ほかの WS と同じく Bearer はクエリで(Web 版でも繋がる)。
    final url = base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '${base.path}/api/v1/me/events', queryParameters: {'token': t});
    final ws = WebSocketChannel.connect(url);
    try {
      await ws.ready;
    } catch (e) {
      throw StateError(wsConnectErrorMessage(e)); // URL の token を出さない
    }
    return ws.stream.map((e) {
      final j = jsonDecode(e is String ? e : utf8.decode(e as List<int>));
      return j is Map ? j.cast<String, Object?>() : const <String, Object?>{};
    });
  };
});

/// 繋いでいるか。ヘッダーの新着が見ている間だけ生きる。
class LiveEvents extends Notifier<bool> {
  StreamSubscription<Map<String, Object?>>? _sub;
  Timer? _retry;
  int _failures = 0;
  bool _disposed = false;

  /// 繋ぎ直すまでの待ち(テストで短く)。
  static Duration baseDelay = const Duration(seconds: 5);

  @override
  bool build() {
    final connect = ref.watch(liveEventsConnectProvider);
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _retry?.cancel();
      unawaited(_sub?.cancel());
    });
    if (connect != null) unawaited(_open(connect));
    return false;
  }

  Future<void> _open(LiveEventsConnect connect) async {
    try {
      final stream = await connect();
      if (_disposed) return;
      _failures = 0;
      state = true;
      _sub = stream.listen(_onMessage, onDone: () => _again(connect), onError: (Object _) => _again(connect), cancelOnError: true);
    } catch (e) {
      debugPrint('live events: $e');
      _again(connect);
    }
  }

  void _again(LiveEventsConnect connect) {
    if (_disposed) return;
    state = false;
    _failures++;
    final wait = baseDelay * (1 << (_failures - 1).clamp(0, 6));
    _retry?.cancel();
    _retry = Timer(wait > const Duration(minutes: 5) ? const Duration(minutes: 5) : wait, () => _open(connect));
  }

  void _onMessage(Map<String, Object?> m) {
    switch (m['type']) {
      case 'swing':
        final s = Swing.tryParse(m['swing']);
        if (s != null) ref.read(swingFeedProvider.notifier).upsertLocal(s);
      case 'astell':
        final raw = m['room'];
        if (raw is Map) {
          try {
            ref.read(headerArrivalsProvider.notifier).liveRoom(AstellRoom.fromJson(raw.cast<String, Object?>()));
          } catch (e) {
            debugPrint('live events: astell: $e');
          }
          ref.invalidate(astellHomeProvider);
        }
    }
  }
}

final liveEventsProvider = NotifierProvider<LiveEvents, bool>(LiveEvents.new);
