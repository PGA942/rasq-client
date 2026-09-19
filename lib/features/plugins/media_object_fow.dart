import 'package:flutter/material.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

/// 加工画面に置いたメディアのオブジェクト(画像 / 動画 / 投稿)の設定 (D-266)。
class MediaObjectSettings {
  const MediaObjectSettings({this.loop = true, this.speed = 1, this.volume = 1, this.opacity = 1});

  /// 土台より短いとき、繰り返すか(オフ = 最後のコマで止まる)。
  final bool loop;

  /// 再生の速さ(0.25〜2)。
  final double speed;

  /// 音の大きさ(0 = 消音)。
  final double volume;

  /// 不透明度(0.1〜1)。
  final double opacity;

  MediaObjectSettings copyWith({bool? loop, double? speed, double? volume, double? opacity}) =>
      MediaObjectSettings(loop: loop ?? this.loop, speed: speed ?? this.speed, volume: volume ?? this.volume, opacity: opacity ?? this.opacity);
}

const mediaObjectFowId = 'media.pro.object';

/// オブジェクトの編集 FOW: 値を動かすたびに [settings] を書き換える(加工画面がそのまま見た目 / 再生に反映する)。
/// [isVideo] = 動くオブジェクト(繰り返し / 速さ / 音が出る)。静止画は不透明度だけ。戻り: true = 「削除」。
Future<bool?> showMediaObjectFow(OverlayManager manager, {required String title, required bool isVideo, required ValueNotifier<MediaObjectSettings> settings}) {
  if (manager.contains(mediaObjectFowId)) manager.close(mediaObjectFowId);
  return manager.showFow<bool>(
    id: mediaObjectFowId,
    spec: FowSpec(title: title, cancelText: '閉じる', initialHeightFactor: 0.4, minHeightFactor: 0.2, maxHeightFactor: 0.7, maxWidth: 560, dockAboveFooter: true),
    semanticsLabel: '$title の編集',
    builder: (context, _) {
      final scheme = Theme.of(context).colorScheme;
      return ValueListenableBuilder<MediaObjectSettings>(
        valueListenable: settings,
        builder: (_, s, _) => ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.md), children: [
          if (isVideo) ...[
            RasqSwitchListTile(key: const ValueKey('mediaObject.loop'), title: '繰り返し再生', subtitle: 'オフ = 終わったら最後のコマで止まる', value: s.loop, onChanged: (v) => settings.value = s.copyWith(loop: v)),
            RasqSliderListTile(key: const ValueKey('mediaObject.speed'), title: '再生の速さ', value: s.speed, min: 0.25, max: 2, divisions: 7, valueLabel: '× ${s.speed.toStringAsFixed(2)}', onChanged: (v) => settings.value = s.copyWith(speed: v)),
            RasqSliderListTile(key: const ValueKey('mediaObject.volume'), title: '音', value: s.volume, min: 0, max: 1, divisions: 20, valueLabel: s.volume == 0 ? '消音' : '${(s.volume * 100).round()}%', onChanged: (v) => settings.value = s.copyWith(volume: v)),
          ],
          RasqSliderListTile(key: const ValueKey('mediaObject.opacity'), title: '不透明度', value: s.opacity, min: 0.1, max: 1, divisions: 18, valueLabel: '${(s.opacity * 100).round()}%', onChanged: (v) => settings.value = s.copyWith(opacity: v)),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: TextButton(key: const ValueKey('mediaObject.remove'), onPressed: () => manager.close(mediaObjectFowId, result: true), child: Text('このオブジェクトを削除', style: TextStyle(color: scheme.error))),
          ),
        ]),
      );
    },
  );
}
