import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:video_player/video_player.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../home/post_row.dart';

/// 動画の再生 (D-201): 1 本の動画のセッション(video_player のコントローラー + 状態)。
/// 初期化できない環境(テスト / 未対応形式)は [error] に落ちる。
/// [autoplay] は準備ができ次第再生する(全画面ビューワー、D-202)。[hold] の間は再生しない
/// (全画面表示プラグインが起動している間)。
/// 動画の設定 (D-238「ピクチャインピクチャ」、設定エリア `appearance.video`): アプリの根が設定の変化で書き換える。
class VideoPrefs {
  static bool autoplay = true;
  static double defaultSpeed = 1.0;
  static bool pipKeepPosition = true;
}

class VideoSession extends ChangeNotifier {
  VideoSession(this.item, {this.autoplay = false, this.startAt}) {
    _init();
  }
  final MediaItem item;
  final bool autoplay;

  /// 開始位置(PiP へ移るときに再生位置を引き継ぐ、D-204)。
  final Duration? startAt;
  VideoPlayerController? controller;
  String? error;
  bool ready = false;
  double speed = 1;
  bool _disposed = false;
  bool _hold = false;
  static const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(item.url);
      controller = c;
      await c.initialize();
      if (_disposed) return;
      c.addListener(notifyListeners);
      await c.setLooping(true);
      if (startAt != null && startAt! > Duration.zero) await c.seekTo(startAt!);
      ready = true;
      // 既定の再生速度 / 自動再生 (D-238)。
      speed = VideoPrefs.defaultSpeed;
      if (speed != 1.0) await c.setPlaybackSpeed(speed);
      if (autoplay && VideoPrefs.autoplay && !_hold) await c.play();
      if (!_disposed) notifyListeners();
    } catch (e) {
      if (_disposed) return;
      error = '再生できません: $e';
      notifyListeners();
    }
  }

  bool get playing => controller?.value.isPlaying ?? false;
  Duration get position => controller?.value.position ?? Duration.zero;
  Duration get duration => controller?.value.duration ?? Duration.zero;

  /// ホストが止めている(全画面表示プラグインの起動中、D-202)。true にすると一時停止し、自動再生もしない。
  bool get hold => _hold;
  set hold(bool v) {
    if (_hold == v) return;
    _hold = v;
    if (v) pause();
    notifyListeners();
  }

  Future<void> toggle() async {
    final c = controller;
    if (c == null || !ready) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
  }

  Future<void> play() async {
    if (ready && !_hold) await controller?.play();
  }

  Future<void> pause() async {
    if (ready) await controller?.pause();
  }

  /// ±秒(5 秒送り / 戻し)。
  Future<void> seekBy(int seconds) async {
    final c = controller;
    if (c == null || !ready) return;
    var to = c.value.position + Duration(seconds: seconds);
    if (to < Duration.zero) to = Duration.zero;
    if (c.value.duration > Duration.zero && to > c.value.duration) to = c.value.duration;
    await c.seekTo(to);
  }

  Future<void> seekTo(Duration d) async {
    if (ready) await controller?.seekTo(d);
  }

  Future<void> setSpeed(double v) async {
    speed = v;
    if (ready) await controller?.setPlaybackSpeed(v);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    controller?.removeListener(notifyListeners);
    controller?.dispose();
    super.dispose();
  }
}

String fmtDuration(Duration d) {
  final s = d.inSeconds;
  final m = s ~/ 60;
  final h = m ~/ 60;
  final ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${(m % 60).toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// 動画の面(タップで再生 / 一時停止)。初期化前はサムネイル + くるくる、失敗は案内。
class RasqVideoView extends StatelessWidget {
  const RasqVideoView({super.key, required this.session, this.fit = BoxFit.contain, this.tapToggles = true});
  final VideoSession session;
  final BoxFit fit;

  /// 面のタップで再生 / 一時停止するか(全画面ビューワーはタップを FOW の開き直しに使うので false、D-203)。
  final bool tapToggles;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final c = session.controller;
        if (session.error != null || c == null || !session.ready) {
          final thumb = session.item.thumbnailUrl;
          return Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
            if (thumb != null) Image.network(thumb.toString(), fit: fit, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            if (session.error == null)
              const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))
            else
              Center(child: Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(session.error!, key: const ValueKey('viewer.video.error'), style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center))),
          ]);
        }
        final face = Stack(alignment: Alignment.center, fit: StackFit.expand, children: [
          Center(child: AspectRatio(aspectRatio: c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio, child: VideoPlayer(c))),
          if (!c.value.isPlaying) const Icon(Icons.play_circle_fill, color: Colors.white70, size: 72),
        ]);
        if (!tapToggles) return face;
        return GestureDetector(key: const ValueKey('viewer.video.toggle'), onTap: session.toggle, child: face);
      },
    );
  }
}

/// 再生の操作 (D-201 → D-202 の配置): **左にシークバー(+ 時間)、右に制御ボタン類**(5 秒戻し / 再生 /
/// 5 秒送り / 速度)。幅が [stackBelow] 未満の小画面環境ではボタン類を下の行へ回す。
class VideoControls extends StatelessWidget {
  const VideoControls({super.key, required this.session, this.light = false, this.stackBelow = 440});
  final VideoSession session;

  /// 明るい文字(暗い背景に直接置くとき)。false = テーマの onSurface。
  final bool light;

  /// この幅未満ならボタン類を下の行へ(小画面環境)。
  final double stackBelow;

  @override
  Widget build(BuildContext context) {
    final color = light ? Colors.white : Theme.of(context).colorScheme.onSurface;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final enabled = session.ready && session.error == null;
        final total = session.duration;
        final pos = session.position;
        final slider = SliderTheme(
          data: SliderThemeData(trackHeight: 2, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), activeTrackColor: RasqColors.link, inactiveTrackColor: color.withValues(alpha: 0.3), thumbColor: RasqColors.link),
          child: Slider(
            key: const ValueKey('video.seek'),
            value: total.inMilliseconds == 0 ? 0 : (pos.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0),
            onChanged: enabled && total > Duration.zero ? (v) => session.seekTo(Duration(milliseconds: (total.inMilliseconds * v).round())) : null,
          ),
        );
        final time = Text('${fmtDuration(pos)} / ${fmtDuration(total)}', style: RasqTypography.caption.copyWith(color: color));
        final seek = Row(children: [Expanded(child: slider), Padding(padding: const EdgeInsets.only(right: RasqSpacing.sm), child: time)]);
        final buttons = Row(mainAxisSize: MainAxisSize.min, children: [
          RasqIconButton(key: const ValueKey('video.back5'), icon: Icons.replay_5, color: color, tooltip: '5 秒戻す', onPressed: enabled ? () => session.seekBy(-5) : null),
          RasqIconButton(key: const ValueKey('video.play'), icon: session.playing ? Icons.pause_circle_filled : Icons.play_circle_fill, size: 32, color: color, tooltip: session.playing ? '一時停止' : '再生', onPressed: enabled ? session.toggle : null),
          RasqIconButton(key: const ValueKey('video.forward5'), icon: Icons.forward_5, color: color, tooltip: '5 秒送る', onPressed: enabled ? () => session.seekBy(5) : null),
          PopupMenuButton<double>(
            key: const ValueKey('video.speed'),
            tooltip: '再生速度',
            initialValue: session.speed,
            onSelected: session.setSpeed,
            itemBuilder: (_) => [for (final s in VideoSession.speeds) PopupMenuItem(value: s, child: Text('${s}x'))],
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text('${session.speed}x', style: RasqTypography.bodySmall.copyWith(color: color, fontWeight: FontWeight.w600))),
          ),
        ]);
        return LayoutBuilder(
          key: const ValueKey('video.controls'),
          builder: (context, c) {
            if (c.maxWidth < stackBelow) {
              return Column(key: const ValueKey('video.controls.stacked'), mainAxisSize: MainAxisSize.min, children: [seek, buttons]);
            }
            return Row(key: const ValueKey('video.controls.row'), children: [Expanded(child: seek), buttons]);
          },
        );
      },
    );
  }
}

/// 動画 + 操作のブロック (D-201: インライン再生の FOW)。高さを揃え、動画の幅が枠の 1/2 未満(縦長)なら
/// 操作を右に、動画を左寄せに。
class VideoPlayerBlock extends StatelessWidget {
  const VideoPlayerBlock({super.key, required this.session, this.height = 240});
  final VideoSession session;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final ar = session.controller?.value.aspectRatio ?? 16 / 9;
        return LayoutBuilder(builder: (context, c) {
          final videoWidth = height * (ar == 0 ? 16 / 9 : ar);
          final narrow = videoWidth < c.maxWidth / 2;
          final video = SizedBox(height: height, width: narrow ? videoWidth : c.maxWidth, child: ColoredBox(color: Colors.black, child: RasqVideoView(session: session)));
          if (narrow) {
            return Row(key: const ValueKey('video.block.side'), crossAxisAlignment: CrossAxisAlignment.start, children: [
              video,
              const SizedBox(width: RasqSpacing.md),
              Expanded(child: SizedBox(height: height, child: Center(child: VideoControls(session: session)))),
            ]);
          }
          return Column(key: const ValueKey('video.block.below'), mainAxisSize: MainAxisSize.min, children: [video, VideoControls(session: session)]);
        });
      },
    );
  }
}

const videoFowId = 'fow.video';

/// インライン再生の FOW (D-201): TL のタイルの再生バッジから(▶ を押したので再生して開く)。
/// 動画の下に投稿をインラインフレームの小表示で出す(「リアクションを表示」ページと同じ、D-203)。
/// タップでスレッド展開画面へ(FOW は閉じる)。
Future<void> showVideoFow(WidgetRef ref, MediaItem item, {Post? post, int? column}) => showVideoFowWith(ref.read(overlayManagerProvider), item, post: post, column: column);

/// [showVideoFow] の本体(ビューワーを閉じた後の PiP 遷移など、ref を使えない場面から、D-204)。
Future<void> showVideoFowWith(OverlayManager manager, MediaItem item, {Post? post, int? column, Duration? startAt}) async {
  if (manager.contains(videoFowId)) manager.close(videoFowId);
  final session = VideoSession(item, autoplay: true, startAt: startAt);
  try {
    await manager.showFow<void>(
      id: videoFowId,
      spec: FowSpec(title: '動画', cancelText: '閉じる', initialHeightFactor: 0.6, maxHeightFactor: 0.9, columnIndex: column ?? 0),
      // 高さは FOW に合わせる(足りなければスクロール)。動画の高さは枠の高さから操作 + 投稿ぶんを引いた分。
      builder: (_, _) => LayoutBuilder(builder: (context, c) {
        final h = (c.maxHeight.isFinite ? c.maxHeight - (post == null ? 120 : 220) : 240.0).clamp(120.0, 480.0).toDouble();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(RasqSpacing.page),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            VideoPlayerBlock(session: session, height: h),
            if (post != null)
              Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.sm),
                child: InlinePostFrame(
                  key: const ValueKey('video.fow.post'),
                  post: post,
                  maxLines: 4,
                  onTap: () {
                    context.pushPost(post);
                    manager.close(videoFowId);
                  },
                ),
              ),
          ]),
        );
      }),
    );
  } finally {
    session.dispose();
  }
}
