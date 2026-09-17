import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_providers.dart';
import 'orgate_client.dart';
import 'rasq_account.dart';

/// 学習へのデータ提供 (D-243 / Central S-018)。
///
/// 任意で、既定は「提供しない」。断っても RASQ の機能はそのまま使える。受付はサーバーの設定
/// (`CENTRAL_LEARNING_OPEN`)で開く。撤回は受付が閉じていてもできる。同意のときに**撤回用のコード**が
/// 1 度だけ返るので、端末の安全な領域に控える(RASQ アカウントに入れなくなっても撤回できるように)。

/// 説明文書(`assets/settings/about.learning.rrl.json`)の版。文書を変えたら上げる。
const rasqLearningVersion = '2026-09-17-draft';

/// 撤回用のコードの控え(`{accountId: code}`)。
const learningCodeStorageKey = 'rasq.learning.codes.v1';

class LearningStatus {
  const LearningStatus({
    required this.open,
    required this.granted,
    this.since,
    this.version,
    required this.eligible,
    this.reason,
    this.ageBand,
    this.posts = 0,
    this.labels = 0,
    this.models = const [],
    this.hasWithdrawCode = false,
    this.retentionYears = 5,
    this.withdrawDays = 30,
  });

  /// 受付が開いているか。
  final bool open;
  final bool granted;
  final DateTime? since;
  final String? version;

  /// 年齢の条件(16 歳以上、16〜17 歳は保護者の同意)を満たすか。
  final bool eligible;

  /// 満たさない理由: `age-required` / `under-16` / `guardian-required`。
  final String? reason;
  final String? ageBand;
  final int posts;
  final int labels;
  final List<String> models;
  final bool hasWithdrawCode;
  final int retentionYears;
  final int withdrawDays;

  factory LearningStatus.fromJson(Map<String, Object?> j) => LearningStatus(
        open: j['open'] == true,
        granted: j['granted'] == true,
        since: DateTime.tryParse(j['since'] as String? ?? ''),
        version: j['version'] as String?,
        eligible: j['eligible'] == true,
        reason: j['reason'] as String?,
        ageBand: j['ageBand'] as String?,
        posts: (j['posts'] as num?)?.toInt() ?? 0,
        labels: (j['labels'] as num?)?.toInt() ?? 0,
        models: [for (final m in (j['models'] as List? ?? const [])) if (m is String) m],
        hasWithdrawCode: j['hasWithdrawCode'] == true,
        retentionYears: (j['retentionYears'] as num?)?.toInt() ?? 5,
        withdrawDays: (j['withdrawDays'] as num?)?.toInt() ?? 30,
      );
}

class LearningApi {
  const LearningApi(this._client);
  final OrgateClient _client;

  Future<LearningStatus> status() async => LearningStatus.fromJson(await _client.getJson('/me/learning'));

  /// 同意を記録する。戻り値の code は**ここでしか返らない**。
  Future<({LearningStatus status, String code})> grant() async {
    final res = await _client.postJson('/me/learning/grant', {'version': rasqLearningVersion});
    return (status: LearningStatus.fromJson((res['status'] as Map).cast<String, Object?>()), code: res['withdrawCode'] as String? ?? '');
  }

  Future<LearningStatus> withdraw() async => LearningStatus.fromJson(await _client.postJson('/me/learning/withdraw', const {}));

  /// 撤回用のコードで撤回する(RASQ アカウントのトークンは要らない)。
  Future<void> withdrawByCode(String code) => _client.postJson('/learning/withdraw', {'code': code.trim()});
}

/// いまの RASQ アカウントの状態。接続先か RASQ アカウントが無ければ null。
class LearningNotifier extends AsyncNotifier<LearningStatus?> {
  LearningApi? get _api {
    final c = ref.read(centralClientProvider);
    return c == null ? null : LearningApi(c);
  }

  @override
  Future<LearningStatus?> build() async {
    final client = ref.watch(centralClientProvider);
    final account = await ref.watch(orgateAccountProvider.future);
    if (client == null || account == null) return null;
    return LearningApi(client).status();
  }

  Future<Map<String, String>> _codes() async {
    final raw = await ref.read(sessionStorageProvider).read(learningCodeStorageKey);
    if (raw == null) return {};
    try {
      return {for (final e in (jsonDecode(raw) as Map).entries) if (e.value is String) '${e.key}': e.value as String};
    } catch (_) {
      return {};
    }
  }

  /// この端末に控えてある、いまのアカウントの撤回用のコード。
  Future<String?> savedCode() async {
    final id = ref.read(orgateAccountProvider).value?.id;
    return id == null ? null : (await _codes())[id];
  }

  Future<void> _saveCode(String? code) async {
    final id = ref.read(orgateAccountProvider).value?.id;
    if (id == null) return;
    final codes = await _codes();
    if (code == null) {
      codes.remove(id);
    } else {
      codes[id] = code;
    }
    await ref.read(sessionStorageProvider).write(learningCodeStorageKey, jsonEncode(codes));
  }

  /// 同意する。撤回用のコードを返す(端末にも控える)。
  Future<String> grant() async {
    final res = await _api!.grant();
    await _saveCode(res.code);
    state = AsyncData(res.status);
    return res.code;
  }

  Future<void> withdraw() async {
    final s = await _api!.withdraw();
    await _saveCode(null);
    state = AsyncData(s);
  }

  Future<void> withdrawByCode(String code) async {
    await _api!.withdrawByCode(code);
    ref.invalidateSelf();
  }
}

final learningProvider = AsyncNotifierProvider<LearningNotifier, LearningStatus?>(LearningNotifier.new);
