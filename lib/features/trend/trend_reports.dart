import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../settings/settings_dsl.dart';
import 'trend_providers.dart';

/// トレンドの通報 (D-402 / Central S-066)。
///
/// - 送り先は Central の `POST /reports {trend: {tag, accountKey}, reason, note?}`(トークンの取り直しつきの Central の口)。
///   `accountKey` = そのトレンドを出した SNS アカウント。Central が `kind` / `instance` だけを取る(ハンドルは持たない)。
/// - 端末の控え(KV `trend.reports.v1`、キー = [trendKey])は**送れなかったときの控え**と「通報したトレンドを隠す」印。
///   RASQ アカウントが無い / Central に繋がらない / 送るのに失敗したら `sent: false` で残し、次にトレンドの「…」を開いたときと、
///   次に通報したときに送り直す([flushPendingTrendReports])。
/// - **通報したトレンドは、この端末のトレンドの一覧に出さない**(`hidden: true`。どのサーバーのものでも同じワードは隠す)。
///   通報の直後のスナックバーの「表示に戻す」で戻せる(通報は取り下げない)。
const trendReportsArea = 'trend.reports';

/// トレンドの通報を送る口。RASQ アカウントがあって Central に繋がっているときだけ(無ければ端末に控える)。
final trendReportClientProvider = Provider<OrgateClient?>((ref) {
  final client = ref.watch(centralClientProvider);
  if (client == null || ref.watch(orgateAccountProvider).value == null) return null;
  return client;
});

/// 送った結果。
enum TrendReportOutcome {
  /// Central に届いた。
  sent,

  /// 繋がっていない(RASQ アカウントが無い / 接続先が無い)ので端末に控えた。
  stored,

  /// 送れなかったので端末に控えた(あとで送り直す)。
  failed,
}

/// 通報の本文(Central の `POST /reports`)。
Map<String, Object?> trendReportBody(Map<String, Object?> record) => {
      'trend': {'tag': record['tag'], 'accountKey': ?record['account']},
      'reason': record['reason'],
      'note': ?record['note'],
    };

/// 通報したトレンド(隠す印のあるもの)の [trendKey] の集合。
final hiddenTrendKeysProvider = Provider<Set<String>>((ref) {
  final m = ref.watch(settingsAreaProvider(trendReportsArea)).value ?? const <String, Object?>{};
  return {
    for (final e in m.entries)
      if (e.value is Map && (e.value as Map)['hidden'] != false) e.key,
  };
});

/// トレンドを通報する: 控えを書いてから Central へ送る。[ref] はコンテナ(控えを書くとトレンドの行が消えるので、行の
/// `WidgetRef` は使えない)。
Future<TrendReportOutcome> reportTrend(ProviderContainer ref, {required TrendTag trend, required String reason, String? note, AccountId? account}) async {
  final store = ref.read(settingsAreaProvider(trendReportsArea).notifier);
  final key = trendKey(trend.tag);
  final record = <String, Object?>{
    'tag': trend.tag,
    'reason': reason,
    if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    'account': ?account?.key,
    'at': DateTime.now().toUtc().toIso8601String(),
    'sent': false,
    'hidden': true,
  };
  await store.set(key, record);
  final client = ref.read(trendReportClientProvider);
  if (client == null) return TrendReportOutcome.stored;
  try {
    final res = await client.postJson('/reports', trendReportBody(record));
    await store.set(key, {...record, 'sent': true, 'reportId': ?res['id']});
  } catch (e) {
    debugPrint('trend report: $e');
    return TrendReportOutcome.failed;
  }
  // ついでに、前に送れなかった分も送る。
  await flushPendingTrendReports(ref);
  return TrendReportOutcome.sent;
}

/// 送れていない控えを送る。戻り = 送れた数。繋がっていなければ何もしない。
Future<int> flushPendingTrendReports(ProviderContainer ref) async {
  final client = ref.read(trendReportClientProvider);
  if (client == null) return 0;
  final store = ref.read(settingsAreaProvider(trendReportsArea).notifier);
  final Map<String, Object?> all;
  try {
    all = await ref.read(settingsAreaProvider(trendReportsArea).future);
  } catch (_) {
    return 0;
  }
  var n = 0;
  for (final e in all.entries) {
    final r = e.value;
    if (r is! Map || r['sent'] == true || r['tag'] is! String || r['reason'] is! String) continue;
    final record = r.cast<String, Object?>();
    try {
      final res = await client.postJson('/reports', trendReportBody(record));
      await store.set(e.key, {...record, 'sent': true, 'reportId': ?res['id']});
      n++;
    } catch (err) {
      debugPrint('trend report (resend): $err');
      break; // 繋がらないなら残りも同じ。次の機会に。
    }
  }
  return n;
}

/// 通報したトレンドを一覧に戻す(通報は取り下げない)。
Future<void> unhideTrend(ProviderContainer ref, String tag) async {
  final key = trendKey(tag);
  final r = (await ref.read(settingsAreaProvider(trendReportsArea).future))[key];
  if (r is! Map) return;
  await ref.read(settingsAreaProvider(trendReportsArea).notifier).set(key, {...r.cast<String, Object?>(), 'hidden': false});
}
