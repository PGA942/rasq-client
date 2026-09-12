import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import 'media_editor_screen.dart';
import 'slot_plugins.dart';

/// 添付の加工 (D-173): 基本動作は **pro_image_editor**(ネイティブ実装: クロップ / 回転 / ペイント /
/// テキスト / 絵文字 / フィルター / ぼかし / 調整)、アセットに無いフィルターや wasm / ONNX を使う編集は
/// **プラグインのメディアエディター**([MediaEditorScreen]、D-169〜D-172)へバイパスする。
///
/// バイパス: 下段バーの「プラグイン」→ 今の見た目を `captureEditorImage` で 1 枚に焼き込み → プラグイン画面 →
/// 適用結果を新しい背景にして戻る(レイヤー / フィルター / 調整 / ぼかし / 変形は焼き込み済みなので空にする)。
/// 「ひとつ戻す」でプラグイン適用前には戻れない(背景を差し替えるため)。
///
/// 動画 (D-174): `mimeType` が `video/*` なら pro_image_editor の動画モード(トリム / ペイント / テキスト /
/// 絵文字 / フィルター / ぼかし / 調整)。再生は `video_player`、書き出しは `pro_video_editor`(端末ネイティブ、
/// mp4)。動画にはプラグインのバイパスは無い。
class ProMediaEditorArgs {
  const ProMediaEditorArgs({required this.bytes, required this.name, required this.mimeType});
  final Uint8List bytes;
  final String name;
  final String mimeType;
}

const proMediaEditorPluginKey = Key('media.pro.plugin');

/// pro_image_editor の日本語。
const rasqEditorI18n = I18n(
  cancel: 'キャンセル',
  undo: 'ひとつ戻す',
  redo: 'やり直す',
  done: '完了',
  remove: '削除',
  doneLoadingMsg: '変更を適用しています',
  importStateHistoryMsg: 'エディターを準備しています',
  various: I18nVarious(loadingDialogMsg: 'お待ちください…', closeEditorWarningTitle: '加工をやめますか？', closeEditorWarningMessage: '変更は保存されません。', closeEditorWarningConfirmBtn: 'やめる', closeEditorWarningCancelBtn: '続ける'),
  layerInteraction: I18nLayerInteraction(remove: '削除', edit: '編集', rotateScale: '回転と拡縮'),
  paintEditor: I18nPaintEditor(
    bottomNavigationBarText: 'ペイント',
    moveAndZoom: 'ズーム',
    freestyle: 'フリーハンド',
    arrow: '矢印',
    line: '直線',
    rectangle: '四角',
    circle: '丸',
    dashLine: '点線',
    blur: 'ぼかし',
    pixelate: 'モザイク',
    lineWidth: '線の太さ',
    eraser: '消しゴム',
    toggleFill: '塗り',
    changeOpacity: '不透明度',
    undo: 'ひとつ戻す',
    redo: 'やり直す',
    done: '完了',
    back: '戻る',
    smallScreenMoreTooltip: 'その他',
    opacity: '不透明度',
    color: '色',
    strokeWidth: '線の太さ',
    fill: '塗り',
    cancel: 'キャンセル',
  ),
  textEditor: I18nTextEditor(inputHintText: 'テキストを入力', bottomNavigationBarText: 'テキスト', back: '戻る', done: '完了', textAlign: '揃え', fontScale: '文字の大きさ', backgroundMode: '背景', smallScreenMoreTooltip: 'その他'),
  cropRotateEditor: I18nCropRotateEditor(bottomNavigationBarText: 'クロップ / 回転', rotate: '回転', flip: '反転', tilt: '傾き', tiltRotate: '回転', tiltHorizontal: '水平', tiltVertical: '垂直', ratio: '比率', back: '戻る', done: '完了', cancel: 'キャンセル', undo: 'ひとつ戻す', redo: 'やり直す', smallScreenMoreTooltip: 'その他', reset: 'リセット'),
  tuneEditor: I18nTuneEditor(bottomNavigationBarText: '調整', back: '戻る', done: '完了', brightness: '明るさ', contrast: 'コントラスト', saturation: '彩度', exposure: '露出', hue: '色相', temperature: '色温度', fade: 'フェード', tint: 'ティント', undo: 'ひとつ戻す', redo: 'やり直す'),
  filterEditor: I18nFilterEditor(bottomNavigationBarText: 'フィルター', back: '戻る', done: '完了'),
  blurEditor: I18nBlurEditor(bottomNavigationBarText: 'ぼかし', back: '戻る', done: '完了'),
  emojiEditor: I18nEmojiEditor(bottomNavigationBarText: '絵文字', search: '検索', categoryRecent: '最近', categorySmileys: '顔と人', categoryAnimals: '動物と自然', categoryFood: '食べ物', categoryActivities: 'アクティビティ', categoryTravel: '旅行と場所', categoryObjects: 'もの', categorySymbols: '記号', categoryFlags: '旗'),
);

class ProMediaEditorScreen extends ConsumerStatefulWidget {
  const ProMediaEditorScreen({super.key, required this.args});
  final ProMediaEditorArgs args;
  @override
  ConsumerState<ProMediaEditorScreen> createState() => _ProMediaEditorScreenState();
}

class _ProMediaEditorScreenState extends ConsumerState<ProMediaEditorScreen> {
  final _editorKey = GlobalKey<ProImageEditorState>();
  final _barScroll = ScrollController();
  bool _closing = false;
  bool _bypassing = false;
  late final OverlayManager _overlay = ref.read(overlayManagerProvider);

  // ── 動画 (D-174) ──
  bool get _isVideo => widget.args.mimeType.startsWith('video/');
  VideoPlayerController? _player;
  ProVideoController? _video;
  pve.VideoMetadata? _meta;
  File? _videoFile;
  String? _videoError;
  TrimDurationSpan? _trim;
  bool _seeking = false;
  TrimDurationSpan? _pendingSeek;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 下の FOW(コンポーザー等)は退避 (D-174): エディターの前に出ないように。State は保持される。
      _overlay.setFowSuspend((e) => true);
    });
    if (_isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/rasq_edit_${DateTime.now().microsecondsSinceEpoch}_${widget.args.name}');
      await f.writeAsBytes(widget.args.bytes, flush: true);
      _videoFile = f;
      final player = VideoPlayerController.file(f);
      await player.initialize();
      await player.setLooping(false);
      await player.pause();
      final meta = await pve.ProVideoEditor.instance.getMetadata(pve.EditorVideo.file(f.path));
      if (!mounted) return;
      _player = player;
      _meta = meta;
      _video = ProVideoController(
        videoPlayer: AspectRatio(aspectRatio: player.value.aspectRatio == 0 ? 16 / 9 : player.value.aspectRatio, child: VideoPlayer(player)),
        initialResolution: meta.resolution,
        videoDuration: meta.duration,
        fileSize: meta.fileSize,
        bitrate: meta.bitrate,
      );
      player.addListener(_onPlayerTick);
      setState(() {});
      // サムネイル(トリムバー)は端末ネイティブでだけ作る。
      if (!Platform.isLinux && !Platform.isWindows) {
        final frames = await pve.ProVideoEditor.instance.getKeyFrames(pve.KeyFramesConfigs(video: pve.EditorVideo.file(f.path), outputSize: const Size.square(120), boxFit: pve.ThumbnailBoxFit.cover, maxOutputFrames: 10, outputFormat: pve.ThumbnailFormat.jpeg));
        if (mounted) _video?.thumbnails = [for (final b in frames) MemoryImage(b)];
      }
    } catch (e) {
      if (mounted) setState(() => _videoError = '動画を開けませんでした: $e');
    }
  }

  void _onPlayerTick() {
    final p = _player;
    final v = _video;
    final m = _meta;
    if (p == null || v == null || m == null) return;
    final pos = p.value.position;
    v.setPlayTime(pos);
    final span = _trim;
    if (span != null && pos >= span.end) {
      _seekTo(span);
    } else if (pos >= m.duration) {
      _seekTo(TrimDurationSpan(start: Duration.zero, end: m.duration));
    }
  }

  Future<void> _seekTo(TrimDurationSpan span) async {
    _trim = span;
    if (_seeking) {
      _pendingSeek = span;
      return;
    }
    _seeking = true;
    _video?.pause();
    _video?.setPlayTime(span.start);
    await _player?.pause();
    await _player?.seekTo(span.start);
    _seeking = false;
    final next = _pendingSeek;
    if (next != null) {
      _pendingSeek = null;
      await _seekTo(next);
    }
  }

  /// 書き出し (D-174): トリム / レイヤー(1 枚に焼き込み)/ ぼかし / 色フィルター / 変形を pro_video_editor で mp4 に。
  Future<void> _renderVideo(CompleteParameters p) async {
    final f = _videoFile;
    final m = _meta;
    if (f == null || m == null) return;
    try {
      final data = pve.VideoRenderData(
        id: 'rasq-${DateTime.now().microsecondsSinceEpoch}',
        videoSegments: [pve.VideoSegment(video: pve.EditorVideo.file(f.path))],
        imageLayers: [if (p.layers.isNotEmpty) pve.ImageLayer(image: pve.EditorLayerImage.memory(p.image))],
        blur: p.blur,
        colorFilters: [pve.ColorFilter(matrix: p.colorFiltersCombined)],
        startTime: p.startTime,
        endTime: p.endTime,
        transform: p.isTransformed ? pve.ExportTransform(width: p.cropWidth, height: p.cropHeight, rotateTurns: 4 - p.rotateTurns, x: p.cropX, y: p.cropY, flipX: p.flipX, flipY: p.flipY) : null,
        enableAudio: _video?.isAudioEnabled ?? true,
        outputFormat: pve.VideoOutputFormat.mp4,
        bitrate: m.bitrate,
      );
      final bytes = await pve.ProVideoEditor.instance.renderVideo(data);
      if (!mounted) return;
      final n = widget.args.name;
      final dot = n.lastIndexOf('.');
      _finish(MediaEditResult(bytes: bytes, mimeType: 'video/mp4', name: '${dot > 0 ? n.substring(0, dot) : n}.mp4'));
    } catch (e) {
      if (mounted) setState(() => _videoError = '動画を書き出せませんでした: $e');
    }
  }

  /// 差し替え後のファイル名(pro_image_editor の出力は PNG)。
  String get _outName {
    final n = widget.args.name;
    final dot = n.lastIndexOf('.');
    return '${dot > 0 ? n.substring(0, dot) : n}.png';
  }

  @override
  void dispose() {
    _overlay.setFowSuspend(null);
    _barScroll.dispose();
    _player?.removeListener(_onPlayerTick);
    _player?.dispose();
    _video?.dispose();
    _videoFile?.delete().catchError((_) => _videoFile!);
    super.dispose();
  }

  void _finish(MediaEditResult? result) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  /// プラグインへバイパス (D-173): 焼き込み → プラグインのエディター → 結果を新しい背景に。
  Future<void> _bypass(ProImageEditorState editor) async {
    if (_bypassing) return;
    final plugins = ref.read(slotPluginsForProvider(SlotIds.composerMedia));
    if (plugins.isEmpty) return;
    // 選択シートは挟まない(D-174: 動線を増やさない)。プラグインの切り替えはメディアエディター側の右列で。
    final pick = plugins.first;
    _bypassing = true;
    try {
      final bytes = await editor.captureEditorImage();
      if (!mounted || bytes.isEmpty) return;
      final result = await context.pushMediaEditor(plugin: pick, bytes: bytes, name: _outName, mimeType: 'image/png');
      if (!mounted) return;
      _overlay.setFowSuspend((e) => true); // メディアエディターが戻すので、こちらでまた退避する
      if (result == null) return;
      // 焼き込み済みの状態を空にして、結果を背景に。
      editor.addHistory(layers: [], filters: [], tuneAdjustments: [], blur: 0, transformConfigs: TransformConfigs.empty());
      await editor.updateBackgroundImage(EditorImage(byteArray: result.bytes), updateHistory: false);
    } finally {
      _bypassing = false;
    }
  }

  Widget _bar(ProImageEditorState editor, Key key, bool hasPlugins) {
    const style = TextStyle(fontSize: 10, color: Colors.white);
    Widget item(String label, IconData icon, VoidCallback onTap, {Key? key, Color color = Colors.white}) =>
        FlatIconTextButton(key: key, label: Text(label, style: style.copyWith(color: color)), icon: Icon(icon, size: 22, color: color), onPressed: onTap);
    return Scrollbar(
      key: key,
      controller: _barScroll,
      thickness: 0,
      // material_ui の Scaffold の下なので flutter/material の BottomAppBar は使わない(素の箱で十分)。
      child: Container(
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        child: Center(
          child: SingleChildScrollView(
            controller: _barScroll,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                item('クロップ / 回転', Icons.crop_rotate_rounded, editor.openCropRotateEditor),
                item('ペイント', Icons.edit_rounded, editor.openPaintEditor),
                item('テキスト', Icons.text_fields, editor.openTextEditor),
                item('絵文字', Icons.sentiment_satisfied_alt_rounded, editor.openEmojiEditor),
                item('フィルター', Icons.filter, editor.openFilterEditor),
                item('ぼかし', Icons.blur_on, editor.openBlurEditor),
                item('調整', Icons.tune_rounded, editor.openTuneEditor),
                // プラグイン (D-173): アセットに無いフィルター / wasm / ONNX はこちらへバイパス。
                if (hasPlugins) item('プラグイン', Icons.extension_outlined, () => _bypass(editor), key: proMediaEditorPluginKey, color: RasqColors.accent),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) return _buildVideo(context);
    final hasPlugins = ref.watch(slotPluginsForProvider(SlotIds.composerMedia)).isNotEmpty;
    return ProImageEditor.memory(
      widget.args.bytes,
      key: _editorKey,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: (bytes) async => _finish(MediaEditResult(bytes: bytes, mimeType: 'image/png', name: _outName)),
        onCloseEditor: (mode) {
          if (mode == EditorMode.main) _finish(null);
        },
      ),
      configs: ProImageEditorConfigs(
        i18n: rasqEditorI18n,
        // 出力は PNG(バイパスの往復で劣化させない。添付の差し替えも PNG)。
        imageGeneration: const ImageGenerationConfigs(outputFormat: OutputFormat.png),
        mainEditor: MainEditorConfigs(
          widgets: MainEditorWidgets(
            bottomBar: (editor, rebuildStream, key) => ReactiveWidget(stream: rebuildStream, builder: (_) => _bar(editor, key, hasPlugins)),
          ),
        ),
      ),
    );
  }

  Widget _buildVideo(BuildContext context) {
    final v = _video;
    final err = _videoError;
    if (v == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: [
            Center(child: err == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: Text(err, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center))),
            Positioned(left: 8, top: 8, child: RasqIconButton(icon: Icons.close, color: Colors.white, tooltip: 'キャンセル', onPressed: () => _finish(null))),
          ]),
        ),
      );
    }
    return ProImageEditor.video(
      v,
      key: _editorKey,
      callbacks: ProImageEditorCallbacks(
        onCompleteWithParameters: _renderVideo,
        onCloseEditor: (mode) {
          if (mode == EditorMode.main) _finish(null);
        },
        videoEditorCallbacks: VideoEditorCallbacks(
          onPlay: () => _player?.play(),
          onPause: () => _player?.pause(),
          onMuteToggle: (muted) => _player?.setVolume(muted ? 0 : 1),
          onTrimSpanUpdate: (span) {
            if (_player?.value.isPlaying == true) _player?.pause();
          },
          onTrimSpanEnd: _seekTo,
        ),
      ),
      configs: ProImageEditorConfigs(
        i18n: rasqEditorI18n,
        videoEditor: const VideoEditorConfigs(initialMuted: false, initialPlay: false, isAudioSupported: false, minTrimDuration: Duration(seconds: 1)),
        mainEditor: MainEditorConfigs(
          tools: const [SubEditorMode.paint, SubEditorMode.text, SubEditorMode.cropRotate, SubEditorMode.tune, SubEditorMode.filter, SubEditorMode.blur, SubEditorMode.emoji],
          widgets: MainEditorWidgets(
            bottomBar: (editor, rebuildStream, key) => ReactiveWidget(stream: rebuildStream, builder: (_) => _bar(editor, key, false)),
          ),
        ),
      ),
    );
  }
}
