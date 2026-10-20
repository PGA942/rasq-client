import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'orgate_client.dart';
import '../l10n/l10n.dart';

/// お金まわりの設定 (D-401 / ORGATE O-004): ORGATE-Server の `GET /payments/config`(認証なし)。
///
/// お金は ORGATE が持つ(第 4 段階): ポイントの残高 (`GET /me/points`)・有料プラグインの購入 (`POST /plugins/{id}/purchase`)も
/// ORGATE の口。**公開テストでは有料の機能を止める**(`ORGATE_PAID_FEATURES=off` が既定)。止まっている間、サーバーは
/// ポイント / 購入の口を `403 paid_features_disabled` で断り、アプリはポイントの UI を灰色にして買わせない。
/// Stripe は公開テストでは開発者の審査料にだけ使う([reviewFee])。
@immutable
class PaymentsConfig {
  const PaymentsConfig({
    this.paidFeatures = false,
    this.stripeMode = 'off',
    this.pointsAvailable = false,
    this.packs = const [],
    this.pointsExpireAfterMonths = 1,
    this.reviewFee = const ReviewFeeConfig(),
  });

  /// 有料の機能(ポイント / ポイントの購入 / 有料プラグイン)が使えるか。false = 公開テスト。
  final bool paidFeatures;

  /// `off` | `dummy` | `live`。
  final String stripeMode;

  /// ポイントを買える(= [paidFeatures] かつ Stripe が off でない)。
  final bool pointsAvailable;
  final List<PointPack> packs;
  final int pointsExpireAfterMonths;
  final ReviewFeeConfig reviewFee;

  /// 取れない / ORGATE につながない構成 = 有料の機能は止まっている扱い。
  static const off = PaymentsConfig();

  factory PaymentsConfig.fromJson(Map<String, Object?> j) {
    final points = (j['points'] as Map?)?.cast<String, Object?>() ?? const {};
    final fee = (j['reviewFee'] as Map?)?.cast<String, Object?>() ?? const {};
    return PaymentsConfig(
      paidFeatures: j['paidFeatures'] == true,
      stripeMode: '${j['stripeMode'] ?? 'off'}',
      pointsAvailable: points['available'] == true,
      packs: [for (final p in points['packs'] as List? ?? const []) if (p is Map) PointPack.fromJson(p.cast<String, Object?>())],
      pointsExpireAfterMonths: (points['expiresAfterMonths'] as num?)?.toInt() ?? 1,
      reviewFee: ReviewFeeConfig.fromJson(fee),
    );
  }
}

/// ポイントのパック(Web コンソールで買う単位)。
@immutable
class PointPack {
  const PointPack({required this.id, required this.points, required this.amountJpy});
  final String id;
  final int points;
  final int amountJpy;
  factory PointPack.fromJson(Map<String, Object?> j) =>
      PointPack(id: '${j['id']}', points: (j['points'] as num?)?.toInt() ?? 0, amountJpy: (j['amountJpy'] as num?)?.toInt() ?? 0);
}

/// 開発者の審査料(税込、仮の金額)。
@immutable
class ReviewFeeConfig {
  const ReviewFeeConfig({this.enabled = false, this.amountJpy = 0, this.taxIncluded = true, this.currency = 'jpy', this.provisional = false});
  final bool enabled;
  final int amountJpy;
  final bool taxIncluded;
  final String currency;
  final bool provisional;
  factory ReviewFeeConfig.fromJson(Map<String, Object?> j) => ReviewFeeConfig(
        enabled: j['enabled'] == true,
        amountJpy: (j['amountJpy'] as num?)?.toInt() ?? 0,
        taxIncluded: j['taxIncluded'] != false,
        currency: '${j['currency'] ?? 'jpy'}',
        provisional: j['provisional'] == true,
      );
}

/// サーバーが有料の機能を止めているときのエラーの語 (`403 paid_features_disabled`)。
const paidFeaturesDisabledCode = 'paid_features_disabled';

/// 有料の機能が止まっているときにアプリが出す文(サーバーの `paid_features_disabled` も同じ文にそろえる)。
String get paidFeaturesDisabledMessage => appL10n.backendPaidFeaturesDisabled;

/// `paid_features_disabled` の断りか。
bool isPaidFeaturesDisabled(Object e) => e is OrgateException && e.serverCode == paidFeaturesDisabledCode;

/// ORGATE の `GET /payments/config`。ORGATE につながない / 取れない = [PaymentsConfig.off]。
final paymentsConfigProvider = FutureProvider<PaymentsConfig>((ref) async {
  final client = ref.watch(orgateClientProvider);
  if (client == null) return PaymentsConfig.off;
  try {
    return PaymentsConfig.fromJson(await client.getJson('/payments/config'));
  } catch (e) {
    debugPrint('payments: config unavailable ($e) — paid features off');
    return PaymentsConfig.off;
  }
});

/// 有料の機能が使えるか(読めるまでは false = 買わせない側に倒す)。
final paidFeaturesProvider = Provider<bool>((ref) => ref.watch(paymentsConfigProvider).value?.paidFeatures ?? false);
