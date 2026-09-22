import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../session/session_providers.dart';
import '../settings/settings_dsl.dart';

/// どのアカウントで共有 / リノートするかの予測 (D-280)。
///
/// 同じ投稿が**持っている複数のアカウントから見える**とき、直近の自分のやりとり(リアクション / リノート / 返信 / 引用)から、
/// いちばん「その相手と話しているアカウント」を選ぶ。事前学習なし・純ローカルのヒューリスティック:
/// 相手(著者)が同じやりとり = 3 点、相手のサーバーが同じ = 1 点、に**新しさ**(半減期 7 日)を掛けて足す。0 点なら予測しない。
///
/// 保存は KV `account.affinity.v1`(直近 [maxRecords] 件)。
const accountAffinityStorageKey = 'account.affinity.v1';

/// 設定エリア。`preferCurrent`(既定 true): SNS アカウントを指定して見ているときは、予測よりそのアカウントを優先する。
/// RASQ アカウント(バンドル)で見ているときは、いつも予測を使う。
const accountPickSettingsArea = 'plugins.accountPick';

typedef AffinityRecord = ({String account, String author, String host, int at});

class AccountAffinityStore extends AsyncNotifier<List<AffinityRecord>> {
  static const maxRecords = 300;

  @override
  Future<List<AffinityRecord>> build() async {
    try {
      final raw = await ref.watch(sessionStorageProvider).read(accountAffinityStorageKey);
      if (raw != null) {
        return [
          for (final r in jsonDecode(raw) as List)
            if (r is Map) (account: '${r['a']}', author: '${r['u']}', host: '${r['h']}', at: (r['t'] as num?)?.toInt() ?? 0),
        ];
      }
    } catch (_) {}
    return const [];
  }

  /// [post] に、[post] が流れてきたアカウントとして関わった(リアクション / リノート / 返信 / 引用)。
  Future<void> record(Post post, {DateTime? now}) async {
    final next = [
      (account: post.account.key, author: post.author.account.key, host: post.author.account.instance, at: (now ?? DateTime.now()).millisecondsSinceEpoch),
      ...state.value ?? const <AffinityRecord>[],
    ].take(maxRecords).toList();
    state = AsyncData(next);
    await ref.read(sessionStorageProvider).write(accountAffinityStorageKey, jsonEncode([for (final r in next) {'a': r.account, 'u': r.author, 'h': r.host, 't': r.at}]));
  }

  /// [candidates](アカウントの key)のうち、[post] の相手といちばん話しているもの。決め手が無ければ null。
  String? predict(Post post, Iterable<String> candidates, {DateTime? now}) => predictAccount(state.value ?? const [], post, candidates, now: now);
}

final accountAffinityProvider = AsyncNotifierProvider<AccountAffinityStore, List<AffinityRecord>>(AccountAffinityStore.new);

String? predictAccount(List<AffinityRecord> records, Post post, Iterable<String> candidates, {DateTime? now}) {
  final pool = candidates.toSet();
  if (pool.length < 2) return null;
  final t = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final author = post.author.account.key;
  final host = post.author.account.instance;
  final scores = <String, double>{};
  for (final r in records) {
    if (!pool.contains(r.account)) continue;
    final base = r.author == author ? 3.0 : (r.host == host ? 1.0 : 0.0);
    if (base == 0) continue;
    final ageDays = math.max(0, t - r.at) / Duration.millisecondsPerDay;
    scores[r.account] = (scores[r.account] ?? 0) + base * math.pow(0.5, ageDays / 7);
  }
  if (scores.isEmpty) return null;
  return (scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first.key;
}

/// 共有 / リノートに使うアカウントの選び方 (D-280)。
/// - SNS アカウントを指定して見ていて、`preferCurrent`(既定)→ そのアカウント(候補にあれば)。
/// - それ以外(RASQ アカウントのバンドルで見ている / 設定を切った)→ 予測。
/// どちらも決まらなければ null(呼び出し側の従来の順に任せる)。
String? pickActingAccount(WidgetRef ref, Post post, Iterable<String> candidates) {
  final pool = candidates.toList();
  final sessions = ref.read(sessionsProvider).value;
  final preferCurrent = ref.read(settingsAreaProvider(accountPickSettingsArea)).value?['preferCurrent'] != false;
  final current = sessions?.currentKey;
  if (sessions != null && !sessions.bundleView && preferCurrent && current != null && pool.contains(current)) return current;
  return predictAccount(ref.read(accountAffinityProvider).value ?? const [], post, pool);
}
