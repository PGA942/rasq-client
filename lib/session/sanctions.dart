import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';

/// 自分に掛かっているアカウント処置 (D-151 / Central S-009 `GET /me/sanctions`)。
///
/// - `light`: [restrictedFeatures] の機能が止まる(投稿系はクライアントが止める)。
/// - `moderate`: 発言ごとに検閲遅延 [reviewDelaySeconds](投稿はクライアントが待つ、
///   AsTell はサーバーが `held` → 判定 → 配信 / `rejected`)。
/// - `severe`: 全機能停止(期限つき)。`permanent`: 凍結(サーバーが 403)。
@immutable
class RasqSanctions {
  const RasqSanctions({this.level, this.restrictedFeatures = const [], this.reviewDelaySeconds = 0, this.categories = const [], this.expiresAt, this.notes = const []});
  final String? level;
  final List<String> restrictedFeatures;
  final int reviewDelaySeconds;
  final List<String> categories;
  final DateTime? expiresAt;

  /// 処置メモ(judge が書いた本人向けの説明)。
  final List<String> notes;

  static const none = RasqSanctions();

  bool get active => level != null;
  bool get moderated => reviewDelaySeconds > 0;
  bool restricts(String feature) => restrictedFeatures.contains(feature);

  String get levelLabel => switch (level) {
        'light' => '軽度な制限',
        'moderate' => '中レベルの制限(発言に検閲遅延)',
        'severe' => '重度の制限(機能停止)',
        'permanent' => '恒久的な凍結',
        _ => '制限なし',
      };

  /// 機能が止まっている時の案内文。止まっていなければ null。
  String? blockedMessage(String feature) {
    if (!restricts(feature)) return null;
    final f = featureLabels[feature] ?? feature;
    final until = expiresAt == null ? '' : '(${_fmt(expiresAt!)} まで)';
    return 'アカウントの処置により $f は利用できません$until。';
  }

  static const featureLabels = {
    'astell.join': 'AsTell への参加',
    'astell.create': 'AsTell ルームの作成',
    'astell.share': 'AsTell での共有・チャット',
    'astell.stream': 'AsTell の画面共有・配信',
    'store.review': 'ストアのレビュー投稿',
    'account.follow': 'RASQ アカウントのフォロー',
    'post': '投稿',
    'post.media': 'メディア付き投稿',
    'dm': 'DM',
    'reaction': 'リアクション',
  };

  factory RasqSanctions.fromJson(Map<String, Object?> j) => RasqSanctions(
        level: j['level'] as String?,
        restrictedFeatures: [for (final f in (j['restrictedFeatures'] as List? ?? const [])) if (f is String) f],
        reviewDelaySeconds: (j['reviewDelaySeconds'] as num?)?.toInt() ?? 0,
        categories: [for (final c in (j['categories'] as List? ?? const [])) if (c is String) c],
        expiresAt: j['expiresAt'] is String ? DateTime.tryParse(j['expiresAt'] as String) : null,
        notes: [for (final s in (j['sanctions'] as List? ?? const [])) if (s is Map && s['note'] is String && (s['note'] as String).isNotEmpty) s['note'] as String],
      );

  static String _fmt(DateTime t) {
    final l = t.toLocal();
    return '${l.month}/${l.day} ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
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
