import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../session/sanctions.dart';
import '../../session/session_providers.dart' show sessionStorageProvider;
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import 'compose_policy.dart';

/// 送る前の判定の方針 (D-462) を Central から取り、アカウントごとに端末へ控える。
///
/// - 取りに行くのは: ログインのアカウント / 処置 / 見守りの「投稿」の設定が変わって最初に送るとき([composePolicyKey])/
///   `refreshSeconds` ごと。取れなければ控え(前に取ったもの)を使う。控えも無ければ null(見守りは組み込みの既定へ倒す。
///   [effectiveComposePolicy])。
/// - 控えに置くのは Central の応答そのもの(閾値と種類の名前だけ。本文は入らない)。
String composePolicyStorageKey(String accountId) => 'composePolicy.v1.$accountId';

/// [key] = `<アカウント id>|<処置のレベルと分類>|<見守りの「投稿」の設定>`([composePolicyKey])。どれかが変われば別の鍵になり、
/// 取り直す(非同期のプロバイダーは見張らない: 送る直前に鍵を作って読む)。
final composePolicyProvider = FutureProvider.family<ComposePolicy?, String>((ref, key) async {
  final client = ref.watch(centralClientProvider);
  final accountId = key.split('|').first;
  if (client == null || accountId.isEmpty) return null;
  final storage = ref.read(sessionStorageProvider);
  final storageKey = composePolicyStorageKey(accountId);
  ComposePolicy? cached;
  try {
    final raw = await storage.read(storageKey);
    if (raw != null) cached = ComposePolicy.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  } catch (e) {
    debugPrint('compose-policy: corrupt cache: $e');
  }
  try {
    final j = await client.getJson('/me/compose-policy').timeout(const Duration(seconds: 8));
    final fresh = ComposePolicy.fromJson(j);
    if (fresh.version != cached?.version) await storage.write(storageKey, jsonEncode(fresh.toJson()));
    final t = Timer(Duration(seconds: fresh.refreshSeconds), ref.invalidateSelf);
    ref.onDispose(t.cancel);
    return fresh;
  } catch (e) {
    debugPrint('compose-policy: fetch failed, using the cached copy: $e');
    final t = Timer(const Duration(minutes: 10), ref.invalidateSelf);
    ref.onDispose(t.cancel);
    return cached;
  }
});

/// [composePolicyProvider] の鍵(いまのアカウント / 処置 / 見守りの「投稿」の設定)。
String composePolicyKey(WidgetRef ref) {
  final account = ref.read(orgateAccountProvider).value;
  final s = ref.read(rasqSanctionsProvider).value;
  final g = ref.read(childGateProvider);
  return '${account?.id ?? ''}|${s?.level}:${s?.categories.join(',')}|${g.supervised}:${g.policy?.composer.enabled}:${g.policy?.composer.level.wire}';
}

/// いま当てる方針(Central の方針 / 控え + 見守りの組み込みの既定)。取りに行くのは 8 秒まで(それ以上は控えか既定)。
Future<ComposePolicy> currentComposePolicy(WidgetRef ref) async {
  final gate = ref.read(childGateProvider);
  final composer = gate.policy?.composer;
  final childLevel = gate.supervised && !gate.locked && composer != null && composer.enabled ? composer.level.wire : null;
  ComposePolicy? central;
  try {
    central = await ref.read(composePolicyProvider(composePolicyKey(ref)).future).timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('compose-policy: $e');
  }
  return effectiveComposePolicy(central, childLevel: childLevel);
}

/// 止めた種類を Central へ知らせる(**種類 / モード / 面だけ**。本文・画像は送らない)。失敗しても何もしない(送信を止めた
/// 事実は変わらない)。
void reportComposeTrips(WidgetRef ref, Iterable<({String type, String mode})> trips, {String? surface}) {
  final client = ref.read(centralClientProvider);
  if (client == null || ref.read(orgateAccountProvider).value == null) return;
  for (final t in trips) {
    unawaited(client
        .postJson('/me/compose-policy/trips', {'type': t.type, 'mode': t.mode, 'surface': ?surface})
        .then((_) {}, onError: (Object e) => debugPrint('compose-policy: trip report failed: $e')));
  }
}
