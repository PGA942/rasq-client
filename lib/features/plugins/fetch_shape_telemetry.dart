import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/orgate_client.dart';
import '../../backend/rasq_consent.dart';
import '../settings/settings_dsl.dart';

/// 通信の形の報告(ストアの `fetch_shapes`)。
///
/// ランタイムは `net.fetch` の要求から**値を持たない形**だけを控える: host / method /
/// パスのテンプレート(`/api/users/{hex}/notes`)/ query のキー / ヘッダ名 / JSON 本文の
/// キー構造。トークン・本文・ユーザー名は端末の外に出ない。ここは、その形のうち
/// **この端末が初めて見たもの**だけを、ユーザーが同意しているときに Central へ送る。
///
/// 送るのは「承認済みの版で新しく届くようになった形」そのもの。審査はそれを読んで
/// 版を読み直す(承認したあとの振る舞いを追う唯一の口)。同じ形は 2 度と送らない
/// ので、量はプラグインが持つ API の口の数(数十)で頭打ちになる。
///
/// 設定: `plugins.telemetry` の `fetchShapes`(既定 false。設定画面の DSL ページ)。
/// 同意は Central の consents(`fetchShapes`)にも 1 度だけ記録し、切ったら撤回を記録する。
class FetchShapeTelemetry {
  FetchShapeTelemetry(this._ref);
  final Ref _ref;

  static const settingsArea = 'plugins.telemetry';
  static const seenArea = 'plugins.telemetry.seen';
  static const consentKind = 'fetchShapes';
  static const consentVersion = '1';

  /// 1 つの (plugin, version) につき覚えておく形の数。Central の上限 (64) より多めに。
  static const maxSeen = 256;

  /// まとめて送るまでの待ち(起動直後は一気に来るので 1 件ずつ POST しない)。
  static const flushDelay = Duration(seconds: 3);

  final Map<String, List<Map<String, Object?>>> _pending = {};
  Timer? _timer;
  bool _consentSynced = false;

  bool get enabled => _ref.read(settingsAreaProvider(settingsArea)).value?['fetchShapes'] == true;

  /// ランタイムから 1 件(`{hash, shape}` / `{overflow: true}`)。同意が無ければ捨てる。
  void report(String pluginId, String version, Map<String, Object?> item) {
    if (!enabled) return;
    if (item['overflow'] == true) return; // 上限超えは Central が自分で数える
    final hash = item['hash'];
    final shape = item['shape'];
    if (hash is! String || shape is! Map) return;
    final key = '$pluginId@$version';
    if (_seen(key).contains(hash)) return;
    _pending.putIfAbsent(key, () => []).add({'hash': hash, 'shape': shape});
    _timer ??= Timer(flushDelay, () {
      _timer = null;
      flush();
    });
  }

  Set<String> _seen(String key) {
    final raw = _ref.read(settingsAreaProvider(seenArea)).value?[key];
    if (raw is! String || raw.isEmpty) return const {};
    try {
      return {for (final h in jsonDecode(raw) as List) if (h is String) h};
    } catch (_) {
      return const {};
    }
  }

  Future<void> _remember(String key, Iterable<String> hashes) async {
    final next = [..._seen(key), ...hashes];
    final kept = next.length > maxSeen ? next.sublist(next.length - maxSeen) : next;
    await _ref.read(settingsAreaProvider(seenArea).notifier).set(key, jsonEncode(kept));
  }

  /// 溜まった形を Central へ。失敗は黙る(報告は任意で、次に見たときにまた送る)。
  Future<void> flush() async {
    final client = _ref.read(centralClientProvider);
    if (client == null || !enabled) return;
    final batch = Map.of(_pending);
    _pending.clear();
    var sent = false;
    for (final e in batch.entries) {
      final at = e.key.lastIndexOf('@');
      final pluginId = e.key.substring(0, at);
      final version = e.key.substring(at + 1);
      // 1 回に 16 件まで(Central の上限)。
      for (var i = 0; i < e.value.length; i += 16) {
        if (!enabled) return; // 送っている間に同意が切れた: 残りは捨てる(同意の記録も触らない)
        final chunk = e.value.sublist(i, i + 16 > e.value.length ? e.value.length : i + 16);
        try {
          await client.postJson('/plugins/${Uri.encodeComponent(pluginId)}/versions/${Uri.encodeComponent(version)}/fetch-shapes', {'shapes': chunk});
          await _remember(e.key, chunk.map((s) => s['hash'] as String));
          sent = true;
        } on OrgateException catch (err) {
          // 404 = ストアに無い版(サイドロード / 同梱)。覚えて、二度と送らない。
          if (err.code.code == '404' || err.message.contains('no approved version')) {
            await _remember(e.key, chunk.map((s) => s['hash'] as String));
          } else {
            debugPrint('fetch shapes: not reported (${err.code.code}): ${err.message}');
          }
        } catch (err) {
          debugPrint('fetch shapes: not reported: $err');
        }
      }
    }
    // 同意の記録は、実際に何かを送ったときに 1 度だけ(送っていないのに記録だけ残さない)。
    // 送り終わるまでに切られていたら、撤回の記録を上書きしない。
    if (sent && enabled) await _syncConsent(granted: true);
  }

  /// 同意を Central にも残す(1 度だけ)。切ったときは撤回を記録する。
  Future<void> _syncConsent({required bool granted}) async {
    final client = _ref.read(centralClientProvider);
    if (client == null) return;
    final area = _ref.read(settingsAreaProvider(settingsArea));
    final recorded = area.value?['consentRecorded'];
    if (granted && (_consentSynced || recorded == consentVersion)) return;
    try {
      await RasqConsentApi(client).put(consentKind, version: consentVersion, granted: granted);
      _consentSynced = granted;
      await _ref.read(settingsAreaProvider(settingsArea).notifier).set('consentRecorded', granted ? consentVersion : '');
    } catch (err) {
      debugPrint('fetch shapes: consent not recorded: $err');
    }
  }

  /// 設定が false になったら撤回を記録し、溜まっているものは捨てる。
  void onSettingChanged(bool now) {
    if (!now) {
      _pending.clear();
      _timer?.cancel();
      _timer = null;
      unawaited(_syncConsent(granted: false));
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}

final fetchShapeTelemetryProvider = Provider<FetchShapeTelemetry>((ref) {
  final t = FetchShapeTelemetry(ref);
  ref.listen<AsyncValue<Map<String, Object?>>>(settingsAreaProvider(FetchShapeTelemetry.settingsArea), (prev, next) {
    final was = prev?.value?['fetchShapes'] == true;
    final now = next.value?['fetchShapes'] == true;
    if (was != now) t.onSettingChanged(now);
  });
  ref.onDispose(t.dispose);
  return t;
});
