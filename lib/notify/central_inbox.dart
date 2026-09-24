import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../features/child_safe/child_safe_notices.dart';
import '../session/session_providers.dart';
import '../session/session_storage.dart';

/// Central の受信箱の軽い見回り (D-309)。
///
/// プッシュはまだダミー(S-014: 受信箱に積むだけで APNs / FCM へは送らない)なので、アプリが自分で
/// `GET /me/notifications`(端末トークン、新しい順)を読む。読むのは **起動 / アプリへ戻ったとき / ログインの変化** の
/// 1 回ずつだけ(**タイマーでは回さない**)。前に見た印(アカウントごとの最新の時刻と、その時刻の id)より新しい項目を、
/// 種類ごとの受け手 ([centralNoticeHandlersProvider]) へ古い順に渡す。はじめて読むアカウントは、印を付けるだけで渡さない
/// (入れ直した端末で、昔の知らせを並べ直さない)。
///
/// いまの受け手は `child_safe` だけ(子 = 制限を取り直す、保護者 = 子の一覧を取り直して知らせを出す。
/// [handleChildSafeNotices])。メンションなどの通知欄 (S-026) は、これまでどおり通知の画面が読む。

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
final centralNoticeHandlersProvider = Provider<Map<String, CentralNoticeHandler>>((ref) => const {'child_safe': handleChildSafeNotices});

class CentralInbox extends Notifier<int> {
  /// 見た印(セキュアストレージ): `{<accountId>: {"at": RFC3339, "ids": [その時刻の id]}}`。
  static const storageKey = 'notify.inbox.seen.v1';

  /// 1 回に読む数(Central の既定と同じ 30)。
  static const limit = 30;

  AppLifecycleListener? _lifecycle;
  Future<void>? _inflight;

  /// 渡した件数(起動してからの合計。画面では使わない)。
  @override
  int build() {
    try {
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(poll()));
    } catch (_) {
      _lifecycle = null; // バインディングの無いテスト
    }
    ref.onDispose(() => _lifecycle?.dispose());
    ref.listen(orgateAccountProvider, (prev, next) {
      if (next.isLoading || next.value == null || prev?.value?.id == next.value?.id) return;
      unawaited(poll());
    });
    Future.microtask(poll);
    return 0;
  }

  /// 1 回読む(重ねて呼ばれたら、走っている 1 回を待つ)。
  Future<void> poll() => _inflight ??= _poll().whenComplete(() => _inflight = null);

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
