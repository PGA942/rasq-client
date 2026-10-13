import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart' show orgateClientProvider;
import '../../backend/rasq_account.dart' show orgateAccountProvider;
import '../../session/session_storage.dart' show SessionStorage;
import 'rasq_account_nudge.dart' show rasqAccountNudgeProvider;

/// RASQ の機能の紹介(初回のツアー、D-471)。
///
/// **いつ出すか**: アプリを入れてから**最初のログインのあと**だけ。SNS の「新規登録」から入ったときは、その SNS 側の
/// オンボーディング(D-412 の登録ページ → ログイン → タップしたものを開く → RASQ アカウントのポップアップ D-413)が
/// 終わってから。無ければログインの直後(シェルが出たとき)。同じ端末の 2 回目以降のログインでは出さない。
///
/// - **端末の印**([featureTourDeviceKey]、端末の保存領域): `pending` = 入れて最初の起動で立て、ツアーを終える /
///   スキップすると下ろす。`seen` = 見終えたツアーの版。「入れて最初の起動」は [FeatureTourInstallMarker]
///   (アプリの置き場のファイル。アンインストールで消える)で見分ける。iOS のキーチェーンのように保存領域だけが入れ直しを
///   越えて残っても、ファイルは消えているので `pending` を立て直し、`seen` が残っていれば「スキップ」を出す。
///   起動したときにもう SNS にログインしている(前の版から上げた / 入れ直しでログインが戻った)なら立てない。
/// - **RASQ アカウントの印**: ユーザーデータ同期 `/me/data/`[featureTourDataArea](`{"seenVersion": n}`)。
///   ほかの端末で見たことがあれば、最初から「スキップ」を出す。
/// - **版** [featureTourVersion]: 中身を改めたら上げる。前の版を見た人(`seen` が 1 以上で今の版より小さい)には、
///   ログインのあとにもう一度出す(このときは「スキップ」あり)。
/// - 設定 → RASQ について / ヘルプ の「RASQ の使い方をもう一度見る」と RAi(`help.tour`)からも開ける
///   ([featureTourLocation] の `again`)。

/// いまのツアーの版。中身を改めて、見た人にももう一度出したいときに上げる。
const featureTourVersion = 1;

/// 端末の印(`{"pending": bool, "seen": int}`)。
const featureTourDeviceKey = 'onboarding.featureTour.v1';

/// RASQ アカウントのユーザーデータ同期の領域。
const featureTourDataArea = 'onboarding.tour.v1';

/// ツアーの場所。[skip] = 「スキップ」を出す(見たことがある)。[again] = 設定 / RAi から開いた(いつでも閉じられる)。
String featureTourLocation({bool skip = false, bool again = false}) => again ? '${Routes.featureTour}?again=1' : (skip ? '${Routes.featureTour}?skip=1' : Routes.featureTour);

/// 端末の印。
@immutable
class FeatureTourDevice {
  const FeatureTourDevice({this.pending = false, this.seen = 0});

  /// 入れてから最初のログインのあとに出すのを待っている。
  final bool pending;

  /// 見終えたツアーの版(0 = まだ)。
  final int seen;

  factory FeatureTourDevice.parse(String? raw) {
    if (raw == null) return const FeatureTourDevice();
    try {
      final j = jsonDecode(raw);
      if (j is Map) return FeatureTourDevice(pending: j['pending'] == true, seen: (j['seen'] as num?)?.toInt() ?? 0);
    } catch (_) {}
    return const FeatureTourDevice();
  }

  String encode() => jsonEncode({'pending': pending, 'seen': seen});

  FeatureTourDevice copyWith({bool? pending, int? seen}) => FeatureTourDevice(pending: pending ?? this.pending, seen: seen ?? this.seen);
}

/// ログインのあとに自分から出すか。[accountSeen] = RASQ アカウントの印(null = RASQ アカウントが無い / 読めなかった)。
bool featureTourShouldShow(FeatureTourDevice device, {int? accountSeen}) {
  if (device.pending) return true;
  final seen = math.max(device.seen, accountSeen ?? 0);
  return seen > 0 && seen < featureTourVersion;
}

/// 「スキップ」を出すか(この端末か RASQ アカウントで、前に見たことがある)。
bool featureTourCanSkip(FeatureTourDevice device, {int? accountSeen}) => math.max(device.seen, accountSeen ?? 0) > 0;

/// 「入れてから最初の起動か」の見分け。true = 最初(印を付けた)/ false = 前にも起動した / null = 確かめられない
/// (このときは `pending` を立てない)。
abstract interface class FeatureTourInstallMarker {
  Future<bool?> checkAndMark(SessionStorage storage);
}

/// アプリの置き場(Application Support)のファイルで見分ける。アンインストールで消える。Web はブラウザの保存領域の印。
class PlatformFeatureTourInstallMarker implements FeatureTourInstallMarker {
  const PlatformFeatureTourInstallMarker();

  static const fileName = 'rasq_install.v1';
  static const webKey = 'onboarding.install.v1';

  @override
  Future<bool?> checkAndMark(SessionStorage storage) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      if (kIsWeb) {
        if (await storage.read(webKey) != null) return false;
        await storage.write(webKey, now);
        return true;
      }
      final dir = await getApplicationSupportDirectory();
      final f = File('${dir.path}/$fileName');
      if (await f.exists()) return false;
      await f.create(recursive: true);
      await f.writeAsString(now);
      return true;
    } catch (e) {
      debugPrint('feature tour: install marker unavailable: $e');
      return null;
    }
  }
}

/// 差し替え口(テスト)。
final featureTourInstallMarkerProvider = Provider<FeatureTourInstallMarker>((ref) => const PlatformFeatureTourInstallMarker());

/// 端末の印(起動したときに 1 度だけ「入れて最初の起動か」を見る)。アプリの一番上 (RasqApp) から起こしておく。
class FeatureTourNotifier extends AsyncNotifier<FeatureTourDevice> {
  @override
  Future<FeatureTourDevice> build() async {
    final storage = ref.read(sessionStorageProvider);
    var device = FeatureTourDevice.parse(await _read(storage));
    final fresh = await ref.read(featureTourInstallMarkerProvider).checkAndMark(storage);
    if (fresh == true && !device.pending) {
      var loggedIn = false;
      try {
        loggedIn = (await ref.read(sessionsProvider.future)).isLoggedIn;
      } catch (_) {}
      if (!loggedIn) {
        device = device.copyWith(pending: true);
        await _write(storage, device);
      }
    }
    return device;
  }

  static Future<String?> _read(SessionStorage storage) async {
    try {
      return await storage.read(featureTourDeviceKey);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _write(SessionStorage storage, FeatureTourDevice device) async {
    try {
      await storage.write(featureTourDeviceKey, device.encode());
    } catch (e) {
      debugPrint('feature tour: device flag not saved: $e');
    }
  }

  /// RASQ アカウントの印(見終えた版)。RASQ アカウントが無い / 読めなければ null。
  Future<int?> accountSeen() async {
    final client = ref.read(orgateClientProvider);
    if (client == null) return null;
    try {
      final account = await ref.read(orgateAccountProvider.future).timeout(const Duration(seconds: 4));
      if (account == null) return null;
      final data = await client.getData(featureTourDataArea).timeout(const Duration(seconds: 4));
      if (data == null) return 0;
      final j = jsonDecode(utf8.decode(data.bytes));
      return j is Map ? (j['seenVersion'] as num?)?.toInt() ?? 0 : 0;
    } catch (e) {
      debugPrint('feature tour: account flag unavailable: $e');
      return null;
    }
  }

  /// 見終えた / スキップした: 端末の `pending` を下ろして `seen` を今の版に。RASQ アカウントがあれば、そちらにも残す。
  Future<void> markSeen() async {
    FeatureTourDevice cur;
    try {
      cur = state.value ?? await future;
    } catch (_) {
      cur = const FeatureTourDevice();
    }
    final next = FeatureTourDevice(seen: math.max(cur.seen, featureTourVersion));
    state = AsyncData(next);
    await _write(ref.read(sessionStorageProvider), next);
    final had = await accountSeen();
    if (had == null || had >= featureTourVersion) return;
    try {
      await ref
          .read(orgateClientProvider)
          ?.putData(featureTourDataArea, utf8.encode(jsonEncode({'seenVersion': featureTourVersion, 'seenAt': DateTime.now().toUtc().toIso8601String()})))
          .timeout(const Duration(seconds: 6));
    } catch (e) {
      debugPrint('feature tour: account flag not saved: $e');
    }
  }
}

final featureTourProvider = AsyncNotifierProvider<FeatureTourNotifier, FeatureTourDevice>(FeatureTourNotifier.new);

/// ツアーを待たせている理由(SNS の新規登録のあとの流れ / RASQ アカウントのポップアップ)。空になったら出す。
class FeatureTourHolds extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};
  void hold(String reason) => state = {...state, reason};
  void release(String reason) => state = {...state}..remove(reason);
}

final featureTourHoldsProvider = NotifierProvider<FeatureTourHolds, Set<String>>(FeatureTourHolds.new);

/// 待たせる理由の名前。
const featureTourHoldSignup = 'signup.follow';
const featureTourHoldNudge = 'rasq.nudge';

/// シェルに置く: ログインして(シェルが出て)、端末の印が「待っている」なら、ほかのオンボーディングが済んでからツアーを開く。
class FeatureTourListener extends ConsumerStatefulWidget {
  const FeatureTourListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<FeatureTourListener> createState() => _FeatureTourListenerState();
}

class _FeatureTourListenerState extends ConsumerState<FeatureTourListener> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_maybeShow()));
  }

  bool get _held => ref.read(featureTourHoldsProvider).isNotEmpty || ref.read(rasqAccountNudgeProvider);

  Future<void> _maybeShow() async {
    if (_busy || !mounted || _held) return;
    final device = ref.read(featureTourProvider).value;
    if (device == null) return;
    // 自分から出すことがなければ、RASQ アカウントの印は読みに行かない(前の版を見た人だけ版を比べる)。
    if (!device.pending && device.seen == 0) return;
    _busy = true;
    try {
      final accountSeen = await ref.read(featureTourProvider.notifier).accountSeen();
      if (!mounted || _held || !featureTourShouldShow(device, accountSeen: accountSeen)) return;
      final router = ref.read(routerProvider);
      if (router.routerDelegate.currentConfiguration.uri.path == Routes.featureTour) return;
      await router.push(featureTourLocation(skip: featureTourCanSkip(device, accountSeen: accountSeen)));
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(featureTourProvider, (_, _) => unawaited(_maybeShow()));
    ref.listen(featureTourHoldsProvider, (_, _) => unawaited(_maybeShow()));
    ref.listen(rasqAccountNudgeProvider, (_, _) => unawaited(_maybeShow()));
    return widget.child;
  }
}
