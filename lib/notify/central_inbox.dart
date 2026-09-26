import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../features/child_safe/child_safe_notices.dart';
import '../session/session_providers.dart';
import '../session/session_storage.dart';
import '../session/sns_share.dart' show handleSnsShareNotices, snsShareRequestKind;

/// Central の受信箱の軽い見回り (D-309)。
///
/// プッシュはまだダミー(S-014: 受信箱に積むだけで APNs / FCM へは送らない)なので、アプリが自分で
/// `GET /me/notifications`(端末トークン、新しい順)を読む。読むのは **起動 / アプリへ戻ったとき / ログインの変化** の
/// 1 回ずつだけ(**タイマーでは回さない**)。前に見た印(アカウントごとの最新の時刻と、その時刻の id)より新しい項目を、
/// 種類ごとの受け手 ([centralNoticeHandlersProvider]) へ古い順に渡す。はじめて読むアカウントは、印を付けるだけで渡さない
/// (入れ直した端末で、昔の知らせを並べ直さない)。
///
/// いまの受け手は `child_safe`(子 = 制限を取り直す、保護者 = 子の一覧を取り直して知らせを出す。
/// [handleChildSafeNotices])と、`sns_share.request`(新しい端末が SNS アカウントの共有を求めた = すぐ見回って承認の問いを出す。
/// [handleSnsShareNotices]、D-322)。どちらも通知の画面には出さない(メンションなどの通知欄 (S-026) は、これまでどおり通知の画面が読む)。
///
/// **開いている間の即時の知らせ** (D-322): 読んだあと、`GET /me/notifications/wait`(長いポーリング。新しい項目が積まれるまで
/// Central が [liveWait] 待って返す)を回し、何か届いたらすぐ読む。アプリが裏へ回ったら止め、戻ったら読み直してまた回す。
/// 口の無い Central(404)/ ログアウト(401)では止める(次のログインの変化 / 復帰でまた始める)。失敗は間を空けて(上限つき)やり直す。
/// プッシュ(本物になったら)をタップして開いたときも、起動 / 復帰の読みで同じ受け手へ渡る。

/// 受信箱の 1 件(`notify_outbox` の形: `{id, kind, title, body, payload, status, devices, createdAt, deliveredAt}`)。
@immutable
class CentralNotice {
  const CentralNotice({required this.id, required this.kind, this.title = '', this.body = '', this.payload = const {}, this.createdAt});
  final String id;
  final String kind;
  final String title;
  final String body;
  final Map<String, Object?> payload;
  final DateTime? createdAt;

  factory CentralNotice.fromJson(Map<String, Object?> j) => CentralNotice(
        id: '${j['id'] ?? ''}',
        kind: '${j['kind'] ?? ''}',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        payload: j['payload'] is Map ? (j['payload'] as Map).cast<String, Object?>() : const {},
        createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}')?.toUtc(),
      );
}

/// 種類の受け手: 新しく届いた分(古い順)を受け取る。
typedef CentralNoticeHandler = Future<void> Function(Ref ref, List<CentralNotice> notices);

/// 種類 → 受け手(テストで差し替える)。
final centralNoticeHandlersProvider = Provider<Map<String, CentralNoticeHandler>>((ref) => const {'child_safe': handleChildSafeNotices, snsShareRequestKind: handleSnsShareNotices});

/// 即時の知らせ(長いポーリング)を回すか(テストで止める / 間隔を縮める)。
final centralInboxLiveProvider = Provider<({bool enabled, Duration retry})>((ref) => (enabled: true, retry: const Duration(seconds: 15)));

class CentralInbox extends Notifier<int> {
  /// 見た印(セキュアストレージ): `{<accountId>: {"at": RFC3339, "ids": [その時刻の id]}}`。
  static const storageKey = 'notify.inbox.seen.v1';

  /// 1 回に読む数(Central の既定と同じ 30)。
  static const limit = 30;

  /// Central が待つ長さ(`wait` 秒)。[OrgateClient] の期限 (20 秒) より短く。
  static const liveWait = Duration(seconds: 15);

  AppLifecycleListener? _lifecycle;
  Future<void>? _inflight;

  /// 即時の知らせの回し手の世代(止める / 回し直すたびに進める)。
  int _liveGen = 0;
  bool _liveRunning = false;
  Timer? _livePause;
  Completer<void>? _livePauseDone;

  /// アカウントごとの、即時の知らせで最後に受け取った項目の時刻(Central の文字列のまま。Web の DateTime はミリ秒までなので)。
  final Map<String, String> _liveSince = {};

  /// 渡した件数(起動してからの合計。画面では使わない)。
  @override
  int build() {
    try {
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(poll()), onHide: _stopLive);
    } catch (_) {
      _lifecycle = null; // バインディングの無いテスト
    }
    ref.onDispose(() {
      _lifecycle?.dispose();
      _stopLive();
    });
    ref.listen(orgateAccountProvider, (prev, next) {
      if (next.isLoading || next.value == null || prev?.value?.id == next.value?.id) return;
      _stopLive();
      unawaited(poll());
    });
    Future.microtask(poll);
    return 0;
  }

  /// 1 回読む(重ねて呼ばれたら、走っている 1 回を待つ)。読み終えたら、即時の知らせを回す(回っていなければ)。
  Future<void> poll() => _inflight ??= _poll().whenComplete(() {
        _inflight = null;
        _startLive();
      });

  void _startLive() {
    if (_liveRunning || !ref.mounted || !ref.read(centralInboxLiveProvider).enabled) return;
    _liveRunning = true;
    final gen = ++_liveGen;
    unawaited(_live(gen).whenComplete(() {
      if (gen == _liveGen) _liveRunning = false;
    }));
  }

  void _stopLive() {
    _liveGen++;
    _liveRunning = false;
    _livePause?.cancel();
    _livePause = null;
    final done = _livePauseDone;
    _livePauseDone = null;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// 止めたら(世代が変わったら)すぐ抜ける待ち。
  Future<void> _pause(Duration d) {
    final done = _livePauseDone = Completer<void>();
    _livePause = Timer(d, () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  Future<void> _live(int gen) async {
    var failures = 0;
    bool stopped() => !ref.mounted || gen != _liveGen;
    while (!stopped()) {
      final client = ref.read(centralClientProvider);
      if (client == null) return;
      final RasqAccount? me;
      try {
        me = await ref.read(orgateAccountProvider.future);
      } catch (_) {
        return;
      }
      if (me == null || stopped()) return;
      final since = await _since(me.id);
      if (stopped()) return;
      final started = DateTime.now();
      try {
        final items = await client.getList('/me/notifications/wait', {'since': since, 'wait': '${liveWait.inSeconds}'});
        failures = 0;
        if (stopped()) return;
        String? newest;
        DateTime? newestAt;
        for (final e in items) {
          final raw = e is Map ? e['createdAt'] : null;
          final at = raw is String ? DateTime.tryParse(raw) : null;
          if (at != null && (newestAt == null || at.isAfter(newestAt))) (newest, newestAt) = (raw as String, at);
        }
        if (newest != null) {
          _liveSince[me.id] = newest;
          await poll();
          continue;
        }
      } on OrgateException catch (e) {
        // 口の無い Central / ログアウトした / 権限が無い: 止める(ログインの変化 / 復帰でまた始める)。
        if (const {'401', '403', '404'}.contains(e.code.code)) return;
        failures++;
      } catch (_) {
        failures++;
      }
      if (stopped()) return;
      final retry = ref.read(centralInboxLiveProvider).retry;
      // 失敗は間を空けて(上限 8 倍)。早すぎる空の答え(待たない Central)も詰めて回さない。
      final wait = failures > 0 ? retry * (failures < 8 ? failures : 8) : (DateTime.now().difference(started) < const Duration(seconds: 1) ? retry : Duration.zero);
      if (wait > Duration.zero) await _pause(wait);
    }
  }

  /// 待つ起点: 見た印と、即時の知らせで受け取った最後の時刻の、新しいほう(同じなら Central の文字列のほう)。
  Future<String> _since(String accountId) async {
    final mark = (await _readSeen(ref.read(sessionStorageProvider)))[accountId];
    final seen = mark == null ? null : '${mark['at'] ?? ''}';
    final live = _liveSince[accountId];
    final seenAt = seen == null ? null : DateTime.tryParse(seen);
    final liveAt = live == null ? null : DateTime.tryParse(live);
    if (live != null && liveAt != null && (seenAt == null || !seenAt.isAfter(liveAt))) return live;
    if (seen != null && seenAt != null) return seenAt.toUtc().toIso8601String();
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String();
  }

  Future<void> _poll() async {
    if (!ref.mounted) return;
    final client = ref.read(centralClientProvider);
    if (client == null) return;
    final RasqAccount? me;
    try {
      me = await ref.read(orgateAccountProvider.future);
    } catch (_) {
      return;
    }
    if (me == null || !ref.mounted) return;
    final List<CentralNotice> items;
    try {
      items = [for (final e in await client.getList('/me/notifications', {'limit': '$limit'})) if (e is Map) CentralNotice.fromJson(e.cast<String, Object?>())];
    } on OrgateException catch (e) {
      debugPrint('inbox: unavailable (${e.code.code})');
      return;
    } catch (e) {
      debugPrint('inbox: unavailable ($e)');
      return;
    }
    if (!ref.mounted) return;
    final storage = ref.read(sessionStorageProvider);
    final seen = await _readSeen(storage);
    final mark = seen[me.id];
    final at = mark == null ? null : DateTime.tryParse('${mark['at'] ?? ''}')?.toUtc();
    final ids = {for (final i in mark?['ids'] as List? ?? const []) '$i'};
    bool isNew(CentralNotice n) => n.createdAt != null && at != null && (n.createdAt!.isAfter(at) || (n.createdAt == at && !ids.contains(n.id)));
    final fresh = [for (final n in items) if (isNew(n)) n]..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

    // 印を進める(いちばん新しい時刻と、その時刻の id)。1 件も無いはじめての読みは「いま」ではなく 0 を印にする
    // (端末の時計に頼らない。次に来たものは全部新しい)。
    final dated = [for (final n in items) if (n.createdAt != null) n];
    if (dated.isNotEmpty) {
      final newest = dated.map((n) => n.createdAt!).reduce((a, b) => a.isAfter(b) ? a : b);
      final keep = at != null && at.isAfter(newest) ? null : {'at': newest.toIso8601String(), 'ids': [for (final n in dated) if (n.createdAt == newest) n.id]};
      if (keep != null) seen[me.id] = keep;
    } else if (mark == null) {
      seen[me.id] = {'at': DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String(), 'ids': const <String>[]};
    }
    await storage.write(storageKey, jsonEncode(seen));
    if (fresh.isEmpty || !ref.mounted) return;

    final handlers = ref.read(centralNoticeHandlersProvider);
    final byKind = <String, List<CentralNotice>>{};
    for (final n in fresh) {
      (byKind[n.kind] ??= []).add(n);
    }
    for (final e in byKind.entries) {
      final h = handlers[e.key];
      if (h == null) continue;
      try {
        await h(ref, e.value);
      } catch (err) {
        debugPrint('inbox: ${e.key} handler failed ($err)');
      }
    }
    if (ref.mounted) state = state + fresh.length;
  }

  static Future<Map<String, Map<String, Object?>>> _readSeen(SessionStorage storage) async {
    try {
      final raw = await storage.read(storageKey);
      if (raw != null) {
        return {for (final e in (jsonDecode(raw) as Map).entries) if (e.value is Map) '${e.key}': (e.value as Map).cast<String, Object?>()};
      }
    } catch (e) {
      debugPrint('inbox: corrupt mark: $e');
    }
    return {};
  }
}

/// アプリの根 ([RasqApp]) が見ておく(作られたときから、起動 / 復帰 / ログインで読む)。
final centralInboxProvider = NotifierProvider<CentralInbox, int>(CentralInbox.new);
