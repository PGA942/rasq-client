import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// まだ出さない機能の切り替え (D-566)。**既定はすべて無効**で、無効の機能は入口(設定の行・画面の飾り)も出さず、
/// サーバーにも問い合わせない。
///
/// - 開発中に試すときは `--dart-define=RASQ_FEATURES=communityTagThemes,atmos`(カンマ区切り)。
/// - テストは [featureFlagsProvider] を差し替える。
/// - サーバーから切り替える仕組みは入れていない(公開の判断はアプリの版で行う)。
@immutable
class RasqFeatureFlags {
  const RasqFeatureFlags({this.communityTagThemes = false, this.atmos = false});

  /// コミュハッシュタグのテーマ (D-567): 自分のコミュニティのハッシュタグにテーマを付ける申請と、そのタグのページのテーマ。
  final bool communityTagThemes;

  /// RASQ Atmos (D-568): ハッシュタグがきっかけの SVG アイコン / アクションのアニメーション / スレッドだけのテーマ。
  /// 規模が大きくなるまで無効。
  final bool atmos;

  /// どちらかが有効(タグのテーマの一覧を取りに行くか)。
  bool get anyTagThemes => communityTagThemes || atmos;

  /// `--dart-define=RASQ_FEATURES=a,b` の名前から。知らない名前は無視する。
  factory RasqFeatureFlags.parse(String names) {
    final set = {for (final n in names.split(',')) n.trim()};
    return RasqFeatureFlags(communityTagThemes: set.contains('communityTagThemes'), atmos: set.contains('atmos'));
  }

  static const _define = String.fromEnvironment('RASQ_FEATURES');

  @override
  bool operator ==(Object other) => other is RasqFeatureFlags && other.communityTagThemes == communityTagThemes && other.atmos == atmos;
  @override
  int get hashCode => Object.hash(communityTagThemes, atmos);
}

/// いまの切り替え。既定 = すべて無効(`RASQ_FEATURES` を渡したときだけ有効)。
final featureFlagsProvider = Provider<RasqFeatureFlags>((ref) => RasqFeatureFlags.parse(RasqFeatureFlags._define));
