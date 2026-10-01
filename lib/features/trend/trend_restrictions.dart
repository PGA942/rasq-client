import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../settings/settings_dsl.dart';
import 'trend_reports.dart' show trendReportClientProvider;

/// 閾値によるトレンドの制限 (D-404 / Central S-068 / rasq-judge J-014、ユーザー決定 2026-10-01)。
///
/// - 端末ごとに **EmoM の閾値**(0〜100、既定 50)。EmoM = これから作る感情 / 刺激の度合いのモデル。いまはこの閾値を、
///   運営のトレンドの制限にだけ使う。**高いほど許容が広い = 隠れるトレンドが少ない**。
/// - 「閾値を公開する」(既定オフ)をオンにすると、値だけを Central の `PUT /me/emom-threshold` へ送る(変えたら送り直し、
///   オフで `DELETE`)。Central は公開された値の分布だけを使う(人ごとの値は出さない)。
/// - 運営が制限したトレンドは Central の `GET /trend-restrictions` が `{tag, instance, score}` で返す。この端末の閾値
///   (公開していなくても)より `score` が大きければ(`"all"` = オーバーフローは常に)、**検索のトレンドの一覧に出さない**。
///   場所取りの印は出さない(ただ並ばない)。トレンドの画面を直接開いたとき(検索で同じワードを打ったなど)は隠さない。
const emomArea = 'trend.emom';

/// 閾値の目盛りと既定値。
const emomThresholdMin = 0;
const emomThresholdMax = 100;
const emomThresholdDefault = 50;

/// 取ってきた制限の控え(Central に繋がらないときに使う)。
const trendRestrictionsCacheArea = 'trend.restrictions';

/// この端末の EmoM の閾値(0〜100)。
int emomThresholdOf(Map<String, Object?> m) {
  final v = m['threshold'];
  return v is num ? v.round().clamp(emomThresholdMin, emomThresholdMax) : emomThresholdDefault;
}

final emomThresholdProvider = Provider<int>((ref) => emomThresholdOf(ref.watch(settingsAreaProvider(emomArea)).value ?? const {}));

/// 閾値を公開するか(既定オフ)。
final emomDiscloseProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(emomArea)).value?['disclose'] == true);

/// Central のトレンドのワードのそろえ方(rasq-central `normalize_trend_tag` と同じ): 前後の空白と先頭の `#` / `＃` を落とし、
/// 全角の英数記号を半角に、空白を 1 つに、小文字に。
String normalizeTrendTag(String tag) {
  final folded = String.fromCharCodes([
    for (final c in tag.runes)
      if (c >= 0xFF01 && c <= 0xFF5E) c - 0xFEE0 else if (c == 0x3000) 0x20 else c,
  ]);
  var t = folded.trim();
  while (t.startsWith('#')) {
    t = t.substring(1);
  }
  final out = t.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).join(' ').toLowerCase();
  return out.length > 100 ? String.fromCharCodes(out.runes.take(100)) : out;
}

/// 運営の制限 1 つ(端末に届く形。理由やレベルは来ない)。
@immutable
class TrendRestriction {
  const TrendRestriction({required this.tag, this.instance, this.score});

  /// そろえたワード。
  final String tag;

  /// そのサーバーのトレンドだけ(null = どのサーバーでも)。
  final String? instance;

  /// 点数(1〜101)。null = オーバーフロー(全員に隠す)。
  final int? score;

  bool get all => score == null;

  /// この閾値の人に隠すか: 点数 > 閾値(オーバーフローは閾値に関係なく)。
  bool hides(int threshold) => score == null || score! > threshold;

  static TrendRestriction? fromJson(Object? j) {
    if (j is! Map || j['tag'] is! String || j['lifted'] == true) return null;
    final s = j['score'];
    if (s != 'all' && s is! num) return null;
    final instance = j['instance'];
    return TrendRestriction(tag: j['tag'] as String, instance: instance is String && instance.isNotEmpty ? instance.toLowerCase() : null, score: s is num ? s.round() : null);
  }

  Map<String, Object?> toJson() => {'tag': tag, 'instance': instance, 'score': score ?? 'all'};
}

/// [tag] のトレンド(出どころのサーバー [instances])を、閾値 [threshold] の人に隠すか。どれか 1 つの出どころで
/// 制限に当たれば隠す(同じワードはまとめて 1 行にしているので)。
bool isTrendRestricted(String tag, Iterable<String> instances, Iterable<TrendRestriction> restrictions, int threshold) {
  final t = normalizeTrendTag(tag);
  if (t.isEmpty) return false;
  final hosts = {for (final i in instances) i.toLowerCase()};
  return restrictions.any((r) => r.tag == t && (r.instance == null || hosts.contains(r.instance)) && r.hides(threshold));
}

/// 運営の制限(Central の `GET /trend-restrictions`、認証なし)。繋がっているアカウントのサーバーの分と、サーバーを限らない分。
/// 読めなければ前に読めた控えを使う(控えも無ければ空 = 何も隠さない)。検索のトレンドの一覧を読み直すときと 10 分おきに読み直す。
final trendRestrictionsProvider = FutureProvider.autoDispose<List<TrendRestriction>>((ref) async {
  final client = ref.watch(centralClientProvider);
  final sessions = ref.watch(sessionsProvider).value?.sessions ?? const [];
  final instances = {for (final s in sessions) s.account.instance.toLowerCase()}.toList()..sort();
  final cache = ref.read(settingsAreaProvider(trendRestrictionsCacheArea).notifier);
  List<TrendRestriction> parse(Object? list) => [for (final j in list is List ? list : const []) ?TrendRestriction.fromJson(j)];
  // ついでに、送れていない閾値の公開 / 取り下げを送る。
  final read = ref.read;
  unawaited(syncEmomDisclosure(read).catchError((Object _) => EmomSyncResult.failed));
  if (client != null) {
    try {
      final res = await client.getJson('/trend-restrictions', {if (instances.isNotEmpty) 'instance': instances.join(',')});
      final list = parse(res['restrictions']);
      await cache.set('items', [for (final r in list) r.toJson()]);
      return list;
    } catch (e) {
      debugPrint('trend restrictions: $e');
    }
  }
  try {
    return parse((await ref.read(settingsAreaProvider(trendRestrictionsCacheArea).future))['items']);
  } catch (_) {
    return const [];
  }
});

/// 一覧の絞り込み: `(ワード, 出どころのサーバー) → 隠すか`。制限を読めていないうちは何も隠さない。
final trendRestrictionFilterProvider = Provider.autoDispose<bool Function(String tag, Iterable<String> instances)>((ref) {
  final restrictions = ref.watch(trendRestrictionsProvider).value ?? const <TrendRestriction>[];
  final threshold = ref.watch(emomThresholdProvider);
  if (restrictions.isEmpty) return (_, _) => false;
  return (tag, instances) => isTrendRestricted(tag, instances, restrictions, threshold);
});

/// 閾値の公開を Central に合わせた結果。
enum EmomSyncResult {
  /// もう合っている(送るものが無い)。
  upToDate,

  /// 送った(公開 / 変更 / 取り下げ)。
  sent,

  /// RASQ アカウントが無い / 接続先が無いので送れない(繋がったら送る)。
  noAccount,

  /// 送れなかった(次の機会に送り直す)。
  failed,
}

/// 端末の設定(`disclose` / `threshold`)と、Central に送ってある値(`sent`、null = 公開していない)を合わせる。
/// 公開がオンで値が違えば `PUT /me/emom-threshold`、オフで送ってあれば `DELETE`。
Future<EmomSyncResult> syncEmomDisclosure(T Function<T>(ProviderListenable<T>) read) async {
  final m = await read(settingsAreaProvider(emomArea).future);
  final disclose = m['disclose'] == true;
  final value = emomThresholdOf(m);
  final sent = m['sent'];
  if (disclose ? sent == value : sent == null) return EmomSyncResult.upToDate;
  final client = read(trendReportClientProvider);
  if (client == null) return EmomSyncResult.noAccount;
  final store = read(settingsAreaProvider(emomArea).notifier);
  try {
    if (disclose) {
      await client.putJson('/me/emom-threshold', {'value': value});
      await store.set('sent', value);
    } else {
      await client.delete('/me/emom-threshold');
      await store.set('sent', null);
    }
    return EmomSyncResult.sent;
  } on OrgateException catch (e) {
    debugPrint('emom threshold: $e');
    return EmomSyncResult.failed;
  } catch (e) {
    debugPrint('emom threshold: $e');
    return EmomSyncResult.failed;
  }
}
