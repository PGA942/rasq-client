import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../l10n/l10n.dart';
import '../../session/session_storage.dart';
import 'child_gate.dart';
import 'child_safe_api.dart';
import 'child_safe_policy.dart';

/// 子の端末のチャイルドセーフ (D-307): 制限を取りに行き、署名を確かめ、端末に控え、関所 ([childGateProvider]) に渡す。
///
/// - 取りに行くのは 起動 / アプリへ戻ったとき / 画面の「更新」/ `child_safe` の知らせ([ChildSafeController.onNotification])。
/// - 署名を確かめられた制限だけを当てはめ、セキュアストレージ `childSafe.policy.v1` に控える(確かめられなければ前の制限のまま)。
///   当てはめたら `POST /me/child-safe/ack`。
/// - **一度でも見守られた端末は、オンラインで「終わった」と確かめるまで制限を外さない**(オフライン / ログアウト / 別の
///   アカウントでも)。ただし保護者がまだ何も決めていない(`pending_setup` で控えも無い)ままログアウトしたら、控えを消す
///   (守る制限がまだ無いので)。
/// - 控えは**見守られたアカウントごと**。別のアカウントの控えで上書きするときも、前のアカウントの守る制限(署名つきの設定)は
///   `held` にそのアカウントのぶんとして残し、そのアカウントでオンラインで終わりを確かめるまで消さない。いまのアカウントの
///   控えが消えたら(設定待ちのままログアウト / 終わりを確かめた)、残してあるぶんを戻して当てはめる。前は控えが 1 つだけで、
///   設定待ちの別のアカウントへログインして出ると、前のアカウントの制限ごと消えた(セキュリティ確認 2026-10-09 の [23])。

/// 端末の控え(セキュアストレージ)。
const childSafePolicyStorageKey = 'childSafe.policy.v1';

/// 時計(テストで差し替える)。
final childSafeNowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class ChildSafeController extends AsyncNotifier<ChildSafeState> {
  Map<String, Object?>? _cache;
  AppLifecycleListener? _lifecycle;
  Future<void>? _inflight;

  @override
  Future<ChildSafeState> build() async {
    final storage = ref.watch(sessionStorageProvider);
    _cache = null;
    final raw = await storage.read(childSafePolicyStorageKey);
    if (raw != null) {
      try {
        _cache = (jsonDecode(raw) as Map).cast<String, Object?>();
      } catch (e) {
        debugPrint('child-safe: corrupt cache: $e');
      }
    }
    try {
      _lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
    } catch (_) {
      _lifecycle = null; // バインディングの無いテスト
    }
    ref.onDispose(() => _lifecycle?.dispose());
    // 使ってよい SNS をセッションの一覧へ渡す(依存の無い箱に書く。build の最中は書かない)。
    listenSelf((_, next) {
      final v = next.value;
      final sns = v != null && v.managed ? v.policy?.allow?.sns : null;
      Future.microtask(() {
        if (ref.mounted) ref.read(childSnsAllowProvider.notifier).set(sns);
      });
    });
    // ログイン / ログアウト / 別のアカウントで取り直す。起動のときの 1 回もここから(build の後)。
    ref.listen(orgateAccountProvider, (prev, next) {
      if (next.isLoading || prev?.value?.id == next.value?.id && prev?.hasValue == true) return;
      unawaited(refresh());
    });
    Future.microtask(refresh);
    return _fromCache(_cache, guardian: ChildSafeGuardianStatus.none);
  }

  /// 控えから状態を作る(控えの制限の署名も確かめ直す: 端末の中で書き換えられていないこと)。
  Future<ChildSafeState> _fromCache(Map<String, Object?>? c, {required ChildSafeGuardianStatus guardian, bool offline = false, String? error}) async {
    if (c == null || c['managed'] != true) return ChildSafeState(guardian: guardian, offline: offline);
    final settings = c['settings'];
    ChildSafePolicy? policy;
    var state = '${c['state'] ?? 'pending_setup'}';
    if (settings is Map) {
      final key = pinnedStorePublicKey.isNotEmpty ? pinnedStorePublicKey : '${c['storeKey'] ?? ''}';
      final ok = await verifyChildSafeSignature(
        publicKey: key,
        signature: '${c['signature'] ?? ''}',
        childAccountId: '${c['accountId'] ?? ''}',
        revision: (c['revision'] as num?)?.toInt() ?? 0,
        settings: settings,
        issuedAt: '${c['issuedAt'] ?? ''}',
      );
      if (ok) {
        policy = ChildSafePolicy.fromJson(settings.cast<String, Object?>());
      } else {
        state = 'unverified';
        error ??= appL10n.childSafeCacheUnverified;
      }
    }
    final parent = c['parent'] is Map ? (c['parent'] as Map).cast<String, Object?>() : const <String, Object?>{};
    return ChildSafeState(
      managed: true,
      state: state,
      policy: policy,
      revision: (c['revision'] as num?)?.toInt() ?? 0,
      parentHandle: parent['handle'] as String?,
      parentDisplayName: parent['displayName'] as String?,
      accountId: c['accountId'] as String?,
      guardian: guardian,
      offline: offline,
      error: error,
    );
  }

  /// 控えに残してある、ほかのアカウントの守る制限(アカウント → そのアカウントの控え)。
  static Map<String, Map<String, Object?>> _heldOf(Map<String, Object?>? c) => {
        for (final e in ((c?['held'] as Map?) ?? const {}).entries)
          if (e.value is Map) '${e.key}': (e.value as Map).cast<String, Object?>(),
      };

  /// [c] をいまのアカウントの控えにする(null = いまのアカウントの控えを消す)。前の控えが別のアカウントの守る制限なら
  /// `held` に残す。いまのぶんが無くなって残してあるぶんがあれば、それをいまの控えに戻す ([23])。
  Future<void> _writeCache(Map<String, Object?>? c) async {
    final old = _cache;
    final held = _heldOf(old);
    final next = c == null ? null : ({...c}..remove('held'));
    if (next != null && old != null && old['settings'] is Map && old['accountId'] != next['accountId']) {
      held['${old['accountId']}'] = {...old}..remove('held');
    }
    if (next != null) held.remove('${next['accountId']}');
    var cur = next ?? (held.isEmpty ? null : held.remove(held.keys.first));
    if (cur != null && held.isNotEmpty) cur = {...cur, 'held': held};
    _cache = cur;
    final storage = ref.read(sessionStorageProvider);
    if (cur == null) {
      await storage.delete(childSafePolicyStorageKey);
    } else {
      await storage.write(childSafePolicyStorageKey, jsonEncode(cur));
    }
  }

  /// 取り直す(重ねて呼ばれたら、走っている 1 回を待つ)。
  Future<void> refresh() => _inflight ??= _sync().whenComplete(() => _inflight = null);

  /// 知らせ(受信箱 / プッシュ)の種類が `child_safe` なら取り直す。受信箱は `CentralInbox`(起動 / 復帰 / ログインで
  /// `GET /me/notifications` を読む)が `handleChildSafeNotices` を通して呼ぶ (D-309)。プッシュが本物になったら同じ口へ。
  Future<void> onNotification(String kind) async {
    if (kind == 'child_safe') await refresh();
  }

  Future<void> _sync() async {
    // build の直後の microtask で来るので、そのあいだに捨てられていたら何もしない(サイドロードの段 D-308 が
    // 見守りの有無を読むようになり、登録の一覧と一緒に作られて捨てられることが増えた)。
    if (!ref.mounted) return;
    final api = ref.read(childSafeApiProvider);
    if (api == null) return;
    RasqAccount? me;
    try {
      me = await ref.read(orgateAccountProvider.future);
    } catch (_) {
      if (ref.mounted) state = AsyncData((state.value ?? const ChildSafeState()).copyWith(offline: true));
      return;
    }
    if (!ref.mounted) return;
    if (me == null) {
      // ログアウト: 守る制限がまだ無い(設定待ち)なら控えを消す。制限があれば残す。
      // 残してあるほかのアカウントの制限があれば、それに戻す ([23])。
      if (_cache != null && _cache!['settings'] is! Map) {
        await _writeCache(null);
        if (ref.mounted) state = AsyncData(await _fromCache(_cache, guardian: ChildSafeGuardianStatus.none));
      }
      return;
    }
    final Map<String, Object?> j;
    try {
      j = await api.status();
    } catch (e) {
      debugPrint('child-safe: status unavailable (${e is OrgateException ? e.code.code : 'error'})');
      if (ref.mounted) state = AsyncData((state.value ?? const ChildSafeState()).copyWith(offline: true));
      return;
    }
    if (!ref.mounted) return;
    final guardian = j['guardian'] is Map ? ChildSafeGuardianStatus.fromJson((j['guardian'] as Map).cast<String, Object?>()) : ChildSafeGuardianStatus.none;
    // このアカウントの控えを残してあれば、いまの控えに戻してから比べる(いまのぶんは、守る制限なら残る。[23])。
    final mine = _heldOf(_cache)[me.id];
    if (mine != null && _cache!['accountId'] != me.id) await _writeCache(mine);
    if (!ref.mounted) return;
    final sameAccount = _cache == null || _cache!['accountId'] == me.id;

    if (j['managed'] != true) {
      if (sameAccount) {
        // オンラインで「見守られていない」と確かめた = 終わった(か、はじめから)。このアカウントの控えだけ消す
        // (残してあるほかのアカウントの制限は、そのアカウントで終わりを確かめるまで当てはめる。[23])。
        if (_cache != null) await _writeCache(null);
        if (!ref.mounted) return;
        state = AsyncData(_cache == null ? ChildSafeState(guardian: guardian) : await _fromCache(_cache, guardian: guardian));
      } else {
        // 別のアカウント: 前のアカウントの制限は、そのアカウントで終わりを確かめるまで残す。
        state = AsyncData(await _fromCache(_cache, guardian: guardian));
      }
      return;
    }

    final revision = (j['revision'] as num?)?.toInt() ?? 0;
    final applied = (j['appliedRevision'] as num?)?.toInt() ?? 0;
    final parent = j['parent'] is Map ? (j['parent'] as Map).cast<String, Object?>() : const <String, Object?>{};
    final settings = j['settings'];
    final base = <String, Object?>{'accountId': me.id, 'managed': true, 'parent': {'handle': parent['handle'], 'displayName': parent['displayName']}};
    final prev = sameAccount ? _cache : null;
    final prevSettings = prev == null ? null : prev['settings'];

    if (j['state'] != 'active' || settings is! Map) {
      await _writeCache({...?prev, ...base, 'state': 'pending_setup', 'revision': revision});
      if (ref.mounted) state = AsyncData(await _fromCache(_cache, guardian: guardian));
      return;
    }

    final signature = '${j['signature'] ?? ''}';
    final issuedAt = '${j['issuedAt'] ?? ''}';
    final unchanged = sameAccount && prevSettings is Map && _cache!['state'] == 'active' && _cache!['revision'] == revision && _cache!['signature'] == signature;
    String? error;
    if (!unchanged) {
      final key = await _storeKey(api);
      final ok = key != null && await verifyChildSafeSignature(publicKey: key, signature: signature, childAccountId: me.id, revision: revision, settings: settings, issuedAt: issuedAt);
      if (!ref.mounted) return;
      if (ok) {
        await _writeCache({...base, 'state': 'active', 'revision': revision, 'settings': settings, 'signature': signature, 'issuedAt': issuedAt, 'storeKey': key});
      } else {
        // 確かめられない制限は当てはめない(前の制限のまま。無ければ使わせない)。
        error = appL10n.childSafeNewSettingsUnverified;
        await _writeCache(prevSettings is Map ? {..._cache!, ...base} : {...base, 'state': 'unverified', 'revision': revision});
      }
    }
    if (!ref.mounted) return;
    state = AsyncData(await _fromCache(_cache, guardian: guardian, error: error));
    final cur = state.value!;
    if (!cur.locked && cur.revision > applied) {
      try {
        await api.ack(cur.revision);
      } on OrgateException catch (e) {
        debugPrint('child-safe: ack failed (${e.code.code})');
      }
    }
    if (!cur.locked) await ref.read(childSafeDailyProvider).flush(api, now: ref.read(childSafeNowProvider)());
  }

  /// ストアの鍵: 焼き込み → サーバー(`GET /store-key`)→ 控え。
  Future<String?> _storeKey(ChildSafeApi api) async {
    if (pinnedStorePublicKey.isNotEmpty) return pinnedStorePublicKey;
    try {
      final k = await api.storeKey();
      if (k != null && k.isNotEmpty) return k;
    } on OrgateException catch (e) {
      debugPrint('child-safe: store key unavailable (${e.code.code})');
    }
    final cached = _cache?['storeKey'];
    return cached is String && cached.isNotEmpty ? cached : null;
  }

  /// 既にある子のアカウントを、保護者のコードでつなぐ(`POST /me/child-safe/pair`)。
  Future<void> pair(String code) async {
    final api = ref.read(childSafeApiProvider);
    if (api == null) throw StateError(appL10n.childSafeNoServer);
    await api.pair(code.trim().toUpperCase());
    await refresh();
  }
}

final childSafeProvider = AsyncNotifierProvider<ChildSafeController, ChildSafeState>(ChildSafeController.new);

/// 見守りの時間の切り替わりに合わせて「いま」を進める(切り替わりが無い設定ではタイマーを置かない)。
class ChildSafeClock extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final time = ref.watch(childSafeProvider.select((s) => s.value?.managed == true ? s.value?.policy?.time : null));
    ref.onDispose(() => _timer?.cancel());
    final now = ref.read(childSafeNowProvider)();
    _schedule(time, now);
    return now;
  }

  void _schedule(ChildSafeTime? time, DateTime now) {
    _timer?.cancel();
    final next = time?.nextBoundary(now);
    if (next == null) return;
    _timer = Timer(next.difference(now) + const Duration(seconds: 1), () {
      final t = ref.read(childSafeNowProvider)();
      state = t;
      _schedule(time, t);
    });
  }
}

final childSafeClockProvider = NotifierProvider<ChildSafeClock, DateTime>(ChildSafeClock.new);

/// 関所 (D-307)。見守られていなければ素通しの [ChildGate]。
/// 使ってよい SNS(見守られていなければ null)。セッションの一覧 ([SessionsNotifier]) が見せる分を絞る。
/// [childSafeProvider] が書き込む**依存の無い箱**(セッション → チャイルドセーフ → RASQ アカウント → セッション の
/// 循環を作らないため。[OrgateTokenHolder] と同じ考え方)。
class ChildSnsAllowStore extends Notifier<ChildSafeSnsAllow?> {
  @override
  ChildSafeSnsAllow? build() => null;
  void set(ChildSafeSnsAllow? v) {
    if (jsonEncode(v?.toJson()) == jsonEncode(state?.toJson())) return;
    state = v;
  }
}

final childSnsAllowProvider = NotifierProvider<ChildSnsAllowStore, ChildSafeSnsAllow?>(ChildSnsAllowStore.new);

final childGateProvider = Provider<ChildGate>((ref) {
  final s = ref.watch(childSafeProvider).value;
  if (s == null || !s.managed) return ChildGate.off;
  return ChildGate(state: s, now: ref.watch(childSafeClockProvider));
});

// ── 1 日の数(投稿の上限と、保護者への報告)──────────────────────────────

/// 端末の中の 1 日の数。**本文は残さない**(送った数 / 止めた数だけ)。
/// - `childSafe.posts.<YYYY-MM-DD>` = その日に送った数(1 日の上限の判定)。
/// - `childSafe.report.v1` = 日ごとの止めた数、送った日。14 日で捨てる。
/// 話題の見出し(本文から取り出した語)は、もう数えない・送らない(D-462 / Central S-102: 投稿の中身に当たるので)。
/// 止めた種類は、止めたときに `POST /me/compose-policy/trips` で別に届く。
class ChildSafeDaily {
  ChildSafeDaily(this._storage);
  final SessionStorage _storage;
  static const reportKey = 'childSafe.report.v1';
  static String postsKey(String date) => 'childSafe.posts.$date';

  static String dateOf(DateTime t) => '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  Future<int> postsOn(String date) async => int.tryParse(await _storage.read(postsKey(date)) ?? '') ?? 0;

  Future<Map<String, Object?>> _report() async {
    try {
      final raw = await _storage.read(reportKey);
      if (raw != null) return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {}
    return {'days': <String, Object?>{}, 'sent': <String>[]};
  }

  Map<String, Object?> _day(Map<String, Object?> r, String date) {
    final days = (r['days'] as Map? ?? {}).cast<String, Object?>();
    r['days'] = days;
    return (days[date] as Map? ?? {'blocked': 0}).cast<String, Object?>();
  }

  Future<void> _putDay(Map<String, Object?> r, String date, Map<String, Object?> day) async {
    (r['days'] as Map<String, Object?>)[date] = day;
    await _storage.write(reportKey, jsonEncode(r));
  }

  /// 送った: 数を 1 つ足す(本文は見ない・残さない)。その日を報告の一覧に載せる。
  Future<void> recordSent({required DateTime now}) async {
    final date = dateOf(now);
    await _storage.write(postsKey(date), '${await postsOn(date) + 1}');
    final r = await _report();
    await _putDay(r, date, _day(r, date));
  }

  /// 止めた(判定 / 上限で送らなかった)。
  Future<void> recordBlocked({required DateTime now}) async {
    final date = dateOf(now);
    final r = await _report();
    final day = _day(r, date);
    day['blocked'] = ((day['blocked'] as num?) ?? 0) + 1;
    await _putDay(r, date, day);
  }

  /// 終わった日(今日より前)のまだ送っていない分を、1 日 1 回ずつ報告する。Central が受けるのは直近 14 日
  /// (今日を入れて 14 日 = 13 日前まで)なので、それより前は捨てる。Central が `400` で断った日(日本の日付との
  /// ずれなど)も捨てて先へ進む(1 日が詰まって、後の日が送れなくならないように)。
  Future<void> flush(ChildSafeApi api, {required DateTime now}) async {
    final today = dateOf(now);
    final oldest = dateOf(now.subtract(const Duration(days: 13)));
    final r = await _report();
    final days = (r['days'] as Map? ?? {}).cast<String, Object?>();
    final sent = [for (final s in r['sent'] as List? ?? const []) '$s'];
    for (final date in [...days.keys]..sort()) {
      if (date.compareTo(oldest) < 0) {
        days.remove(date);
        sent.remove(date);
        await _storage.delete(postsKey(date));
        continue;
      }
      if (date.compareTo(today) >= 0 || sent.contains(date)) continue;
      final day = (days[date] as Map).cast<String, Object?>();
      try {
        await api.report(date: date, posts: await postsOn(date), blocked: (day['blocked'] as num?)?.toInt() ?? 0);
        sent.add(date);
      } on OrgateException catch (e) {
        debugPrint('child-safe: report failed (${e.code.code})');
        if (e.code.code == '400') {
          sent.add(date);
          continue;
        }
        break;
      }
    }
    r['days'] = days;
    r['sent'] = sent;
    await _storage.write(reportKey, jsonEncode(r));
  }
}

final childSafeDailyProvider = Provider<ChildSafeDaily>((ref) => ChildSafeDaily(ref.watch(sessionStorageProvider)));

/// 送る前の判定 (D-307): 見守りの制限(機能 / 1 日の上限 / 本文の強さ / 投稿の話題 (D-315。DM には当てない))。通れば null。止めたら「止めた数」を数える。
/// [direct] = 投稿だが公開範囲がダイレクト(ダイレクト投稿への返信など、D-047)。DM の機能も要る(本文は投稿として判定。
/// セキュリティ確認 2026-10-09 の [19])。
/// [sentTexts] = 実際に送る本文(正規表現の加工 (D-130) のあと、送り先ごと)。入力欄の [text] と同じ判定に通す
/// (加工で止める内容に変えられないように。[20])。印の範囲は入力欄の本文にしか付けない。
Future<ChildComposeVerdict?> childComposeVerdictFor(ChildGate gate, ChildSafeDaily daily, DateTime now,
    {required String text, bool dm = false, bool direct = false, bool media = false, List<String> sentTexts = const []}) async {
  if (!gate.supervised) return null;
  ChildComposeVerdict? v;
  final feature = (dm || direct ? gate.blockedMessage('dm') : null) ?? (!dm && media ? gate.blockedMessage('post.media') : null);
  if (gate.locked) {
    v = ChildComposeVerdict(appL10n.childSafeComposeLocked);
  } else if (feature != null) {
    v = ChildComposeVerdict(feature);
  } else if (gate.postsPerDay != null && await daily.postsOn(ChildSafeDaily.dateOf(now)) >= gate.postsPerDay!) {
    v = ChildComposeVerdict(appL10n.childSafeComposeDailyLimit(gate.postsPerDay!));
  } else {
    v = gate.judgeText(text, dm: dm);
    for (final t in sentTexts) {
      if (v != null) break;
      if (t.trim() == text.trim()) continue;
      if (gate.judgeText(t, dm: dm) case final w?) v = ChildComposeVerdict(appL10n.childSafeComposeAfterTransform(w.message), type: w.type);
    }
  }
  if (v != null) await daily.recordBlocked(now: now);
  return v;
}

/// [childComposeVerdictFor] の画面用。
Future<ChildComposeVerdict?> childComposeVerdict(WidgetRef ref, {required String text, bool dm = false, bool direct = false, bool media = false, List<String> sentTexts = const []}) =>
    childComposeVerdictFor(ref.read(childGateProvider), ref.read(childSafeDailyProvider), ref.read(childSafeNowProvider)(),
        text: text, dm: dm, direct: direct, media: media, sentTexts: sentTexts);

/// 送れた (D-307): 1 日の数を数える(見守られていなければ何もしない。本文は見ない)。
Future<void> childComposeSent(WidgetRef ref) async {
  if (!ref.read(childGateProvider).supervised) return;
  await ref.read(childSafeDailyProvider).recordSent(now: ref.read(childSafeNowProvider)());
}

/// 送る前の判定で止めた (D-462): 見守りの「止めた数」を 1 つ足す(見守られていなければ何もしない)。
Future<void> childComposeBlocked(WidgetRef ref) async {
  if (!ref.read(childGateProvider).supervised) return;
  await ref.read(childSafeDailyProvider).recordBlocked(now: ref.read(childSafeNowProvider)());
}
