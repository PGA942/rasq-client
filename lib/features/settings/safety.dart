import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

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
  (List<MediaItem>, List<int>) applyTo(List<MediaItem> items) {
    switch (sensitiveMedia) {
      case 'hide':
        final kept = <MediaItem>[];
        final map = <int>[];
        for (var i = 0; i < items.length; i++) {
          if (!items[i].sensitive) {
            kept.add(items[i]);
            map.add(i);
          }
        }
        return (kept, map);
      case 'show':
        return ([for (final m in items) m.sensitive ? m.copyWith(sensitive: false) : m], [for (var i = 0; i < items.length; i++) i]);
      default:
        return (items, [for (var i = 0; i < items.length; i++) i]);
    }
  }
}

final safetySettingsProvider = Provider<SafetySettings>((ref) => SafetySettings.of(ref.watch(snsSettingValuesProvider('safety')).value ?? const {}));
