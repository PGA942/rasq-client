import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart' show RasqDateFormat;

import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../l10n/l10n.dart';

/// 自分に掛かっているアカウント処置 (D-151 / Central S-009 `GET /me/sanctions`)。
///
/// - `light`: [restrictedFeatures] の機能が止まる(投稿系はクライアントが止める)。
/// - `moderate`: 発言ごとに検閲遅延 [reviewDelaySeconds](投稿はクライアントが待つ、
///   AsTell はサーバーが `held` → 判定 → 配信 / `rejected`)。
/// - `severe`: 全機能停止(期限つき)。`permanent`: 凍結(サーバーが 403)。
/// 有効な処置の 1 件(解除申請の対象、D-152)。
@immutable
class RasqSanctionEntry {
  const RasqSanctionEntry({required this.id, required this.category, required this.level, this.note, this.expiresAt, this.appealStatus});
  final String id;
  final String category;
  final String level;
  final String? note;
  final DateTime? expiresAt;

  /// 直近の解除申請: open | accepted | rejected | null。
  final String? appealStatus;
  bool get canAppeal => appealStatus != 'open';
  factory RasqSanctionEntry.fromJson(Map<String, Object?> j) => RasqSanctionEntry(
        id: j['id'] as String? ?? '',
        category: j['category'] as String? ?? '',
        level: j['level'] as String? ?? '',
        note: (j['note'] as String?)?.let((n) => n.isEmpty ? null : n),
        expiresAt: j['expiresAt'] is String ? DateTime.tryParse(j['expiresAt'] as String) : null,
        appealStatus: j['appealStatus'] as String?,
      );
}

extension<T extends Object> on T {
  R let<R>(R Function(T it) f) => f(this);
}

@immutable
class RasqSanctions {
  const RasqSanctions({this.level, this.restrictedFeatures = const [], this.reviewDelaySeconds = 0, this.categories = const [], this.expiresAt, this.notes = const [], this.entries = const []});
  final String? level;
  final List<String> restrictedFeatures;
  final int reviewDelaySeconds;
  final List<String> categories;
  final DateTime? expiresAt;

  /// 処置メモ(judge が書いた本人向けの説明)。
  final List<String> notes;

  /// 有効な処置(解除申請の単位)。
  final List<RasqSanctionEntry> entries;

  static const none = RasqSanctions();

  bool get active => level != null;
  bool get moderated => reviewDelaySeconds > 0;
  bool restricts(String feature) => restrictedFeatures.contains(feature);

  String get levelLabel => switch (level) {
        'light' => appL10n.sessionSanctionLight,
        'moderate' => appL10n.sessionSanctionModerate,
        'severe' => appL10n.sessionSanctionSevere,
        'permanent' => appL10n.sessionSanctionPermanent,
        _ => appL10n.sessionSanctionNone,
      };

  /// 機能が止まっている時の案内文。止まっていなければ null。
  String? blockedMessage(String feature) {
    if (!restricts(feature)) return null;
    final f = featureLabel(feature) ?? feature;
    return expiresAt == null ? appL10n.sessionSanctionBlocked(f) : appL10n.sessionSanctionBlockedUntil(f, _fmt(expiresAt!));
  }

  /// 機能の id(サーバーの `restrictedFeatures` の値)→ 表示の名前(表示の言語)。知らない id は null。
  static String? featureLabel(String feature) {
    final l = appL10n;
    return switch (feature) {
      'astell.join' => l.sessionFeatureAstellJoin,
      'astell.create' => l.sessionFeatureAstellCreate,
      'astell.share' => l.sessionFeatureAstellShare,
      'astell.stream' => l.sessionFeatureAstellStream,
      'store.review' => l.sessionFeatureStoreReview,
      'account.follow' => l.sessionFeatureAccountFollow,
      'post' => l.sessionFeaturePost,
      'post.media' => l.sessionFeaturePostMedia,
      'dm' => l.sessionFeatureDm,
      'reaction' => l.sessionFeatureReaction,
      _ => null,
    };
  }

  factory RasqSanctions.fromJson(Map<String, Object?> j) => RasqSanctions(
        level: j['level'] as String?,
        restrictedFeatures: [for (final f in (j['restrictedFeatures'] as List? ?? const [])) if (f is String) f],
        reviewDelaySeconds: (j['reviewDelaySeconds'] as num?)?.toInt() ?? 0,
        categories: [for (final c in (j['categories'] as List? ?? const [])) if (c is String) c],
        expiresAt: j['expiresAt'] is String ? DateTime.tryParse(j['expiresAt'] as String) : null,
        notes: [for (final s in (j['sanctions'] as List? ?? const [])) if (s is Map && s['note'] is String && (s['note'] as String).isNotEmpty) s['note'] as String],
        entries: [for (final s in (j['sanctions'] as List? ?? const [])) if (s is Map) RasqSanctionEntry.fromJson(s.cast<String, Object?>())],
      );

  static String _fmt(DateTime t) => RasqDateFormat.numericMonthDayTime(t.toLocal());
}

/// 自分の処置。Central 未接続 / 未ログインなら [RasqSanctions.none]。取得に失敗しても
/// 機能は止めない(サーバー側が本命のゲート)。
final rasqSanctionsProvider = FutureProvider<RasqSanctions>((ref) async {
  final client = ref.watch(centralClientProvider);
  final account = ref.watch(orgateAccountProvider).value;
  if (client == null || account == null) return RasqSanctions.none;
  try {
    return RasqSanctions.fromJson(await client.getJson('/me/sanctions'));
  } catch (e) {
    debugPrint('sanctions: $e');
    return RasqSanctions.none;
  }
});

/// 解除申請 (D-152): `POST /me/sanctions/{id}/appeal`。judge の人が受理 / 却下する。
Future<void> submitSanctionAppeal(WidgetRef ref, String sanctionId, String message) async {
  final client = ref.read(centralClientProvider);
  if (client == null) throw StateError(appL10n.sessionCentralNotConfigured);
  await client.postJson('/me/sanctions/${Uri.encodeComponent(sanctionId)}/appeal', {'message': message});
  ref.invalidate(rasqSanctionsProvider);
}
