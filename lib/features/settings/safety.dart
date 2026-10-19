import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../child_safe/child_safe_providers.dart' show childGateProvider;
import 'settings_dsl.dart';

/// プラグイン設定「プライバシーとセーフモード」(D-044, `sns.safety`) の
/// 適用ヘルパー。投稿タイル(post_row)が読む。
class SafetySettings {
  const SafetySettings({this.sensitiveMedia = 'blur', this.openCw = false});

  /// 閲覧注意メディアの表示: `blur`(ぼかし・標準)/ `show`(ぼかさず)/
  /// `hide`(セーフモード: タイルから取り除く)。
  final String sensitiveMedia;

  /// 注釈(CW)付き投稿を自動で開く。
  final bool openCw;

  factory SafetySettings.of(Map<String, Object?> values) => SafetySettings(
        sensitiveMedia: values['sensitiveMedia'] as String? ?? 'blur',
        openCw: values['openCw'] == true,
      );

  /// メディア列に適用する。返り値 = (表示リスト, 表示 index → 元 index)。
  /// `hide` で取り除くと index がずれるので、ビューワーへは元 index を渡す。
  ///
  /// センシティブは**1 枚ずつ** (D-510): Misskey はファイルごとの `isSensitive`、Mastodon は投稿の `sensitive` を
  /// プラグインが各メディアへ配る(どちらも [MediaItem.sensitive])。[cw] = 注釈(CW)付きの投稿: 印の無いメディアも
  /// 1 枚ずつクッションを付ける(`show` と「注釈を自動で開く」のときは付けない。`hide` でも取り除かずクッションだけ)。
  (List<MediaItem>, List<int>) applyTo(List<MediaItem> items, {bool cw = false}) {
    final cushionCw = cw && !openCw;
    switch (sensitiveMedia) {
      case 'hide':
        final kept = <MediaItem>[];
        final map = <int>[];
        for (var i = 0; i < items.length; i++) {
          if (!items[i].sensitive) {
            kept.add(cushionCw ? items[i].copyWith(sensitive: true) : items[i]);
            map.add(i);
          }
        }
        return (kept, map);
      case 'show':
        return ([for (final m in items) m.sensitive ? m.copyWith(sensitive: false) : m], [for (var i = 0; i < items.length; i++) i]);
      default:
        return ([for (final m in items) cushionCw && !m.sensitive ? m.copyWith(sensitive: true) : m], [for (var i = 0; i < items.length; i++) i]);
    }
  }

  /// 投稿の添付に適用する(注釈(CW)の有無は投稿から)。タイルと全画面表示で同じ答えにする (D-510)。
  (List<MediaItem>, List<int>) applyToPost(Post post) => applyTo(post.media, cw: post.contentWarning?.isNotEmpty ?? false);
}

final safetySettingsProvider = Provider<SafetySettings>((ref) {
  final s = SafetySettings.of(ref.watch(snsSettingValuesProvider('safety')).value ?? const {});
  // チャイルドセーフ (D-307): 見守り中は、閲覧注意のメディアを必ず取り除く(設定は読むだけ)。
  if (ref.watch(childGateProvider.select((g) => g.forceHideSensitive))) return SafetySettings(sensitiveMedia: 'hide', openCw: s.openCw);
  return s;
});
