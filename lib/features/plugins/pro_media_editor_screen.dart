import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
// LayerInteraction は公開ライブラリから export されていない(レイヤーを「動かせない / 選べない」にする唯一の口)。
// ignore: implementation_imports
import 'package:pro_image_editor/core/models/layers/layer_interaction.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../compose/post_image_fow.dart';
import '../home/action_bar_config.dart';
import '../media/audio_visualizer_fow.dart';
import '../media/audio_visualizer_video.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/action_bundle_fow.dart';
import '../home/plugin_actions.dart';
import '../home/post_row.dart';
import 'media_filter.dart';
import 'media_filter_fow.dart';
import 'media_plugin_panel.dart';
import 'slot_plugins.dart';
import 'sticker_picker.dart';

/// 添付の加工 (D-173 → D-249): 基本動作は **pro_image_editor**(ネイティブ実装: クロップ / 回転 / ペイント /
/// テキスト / 絵文字 / フィルター / ぼかし / 調整)、アセットに無いフィルターや wasm / ONNX を使う編集は
/// **プラグインの編集パネル**([MediaPluginPanel])をこの画面の上に重ねる。
///
/// 下段バー (D-249、契約 v0.10): 内蔵の編集(`editor:<tool>`)+ プラグインが宣言したボタン(マニフェストの `actions` の
/// `slot: "composer.media"`、添付の種類は `accepts`)を、投稿 / 全画面のアクションバーと同じ仕組みで並べる
/// (並べ替え / バンドル / 削除、タグが近い内蔵の編集へ自動で束ねる)。構成は `editor:image` / `editor:video`。
///
/// プラグインのボタン: 今の見た目を `captureEditorImage` で 1 枚に焼き込み → パネル → 適用結果を新しい背景にする
/// (レイヤー / フィルター / 調整 / ぼかし / 変形は焼き込み済みなので空にする)。「ひとつ戻す」でプラグイン適用前には
/// 戻れない(背景を差し替えるため)。
///
/// 動画 (D-174): `mimeType` が `video/*` なら pro_image_editor の動画モード。再生は `video_player`、書き出しは
/// `pro_video_editor`(端末ネイティブ、mp4)。動画を受ける(`accepts`)プラグインのボタンは、元のファイルをそのまま
/// プラグインへ渡し、結果で添付を差し替えて閉じる(焼き込みはしない)。
class ProMediaEditorArgs {
  const ProMediaEditorArgs({required this.bytes, required this.name, required this.mimeType});
  final Uint8List bytes;
  final String name;
  final String mimeType;
}

/// 動画編集の一時ファイル (D-248)。
/// - 置き場を先に作る: macOS(サンドボックス無し)の `~/Library/Caches/<bundle id>` は path_provider が作らないので、
///   無いと書き込みの open が PathNotFoundException になる。
/// - ファイル名に元の名前を使わない(空白 / 日本語 / `/` をネイティブ側のパス処理へ渡さない)。拡張子だけ引き継ぐ。
Future<File> videoEditTempFile(Directory dir, String name) async {
  await dir.create(recursive: true);
  final m = RegExp(r'\.([A-Za-z0-9]{1,5})$').firstMatch(name);
  final ext = (m?.group(1) ?? 'mp4').toLowerCase();
  return File('${dir.path}/rasq_edit_${DateTime.now().microsecondsSinceEpoch}.$ext');
}

/// Visualizer の設定で選んだファイル(左の絵 / 背景の動画)の置き場 (D-253)。ピッカーの一時ファイルは消えるので、
/// アプリの保存領域へ写して、設定にはそのパスを持つ。テストで差し替える。
final visualizerDirProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}/visualizer');
    });

/// 下段バーのボタンのキー: `media.pro.bar.<id>`(id = `editor:<tool>` / `slot:<pluginId>:<actionId>` / `list:<listId>`)。
Key proMediaEditorBarKey(String id) => ValueKey('media.pro.bar.$id');
const proMediaEditorBarEditKey = Key('media.pro.bar.edit');
const proMediaEditorAudioNoteKey = Key('media.pro.audio.note');

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
  stickerEditor: I18nStickerEditor(bottomNavigationBarText: 'ステッカー'),
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

  /// 掛かっているカスタムフィルター (D-255、契約 v0.12)。ボタンの id → 状態(フラグ管理: 掛かっているか / 完了時に apply が要るか)。
  final Map<String, _ActiveFilter> _filters = {};

  /// 完了時の処理中(二重に走らせない)。
  bool _completing = false;

  /// 今のエディター(バーを描くたびに覚える。ステッカー一覧からプラグインを呼ぶ用)。
  ProImageEditorState? _imageEditor;

  /// 重ねているプラグインの編集パネル(無ければ null)。
  ({PluginAction action, Uint8List bytes, String name, String mimeType, Completer<MediaEditResult?> done})? _panel;
  late final OverlayManager _overlay = ref.read(overlayManagerProvider);

  // ── 動画 (D-174) ──
  /// 動画のエディターで開くもの: 動画と、音声だけのファイル (D-250: 開くときに Visualizer の動画へ変換する)。
  bool get _isVideo => widget.args.mimeType.startsWith('video/') || _isAudio;
  bool get _isAudio => widget.args.mimeType.startsWith('audio/');

  /// 音声 → 動画の変換の進み具合(0..1、変換中だけ)。
  double? _audioProgress;

  /// 音声 (D-251): 元の音声(一時ファイル)/ 標本 / Visualizer の設定。設定を変えたら動画を書き出し直す。
  File? _audioFile;
  AudioPcm? _pcm;
  AudioVisualizerConfig _vizConfig = const AudioVisualizerConfig();

  /// 前回の書き出しの内訳(設定 FOW に出す)。
  AudioBuildTimings? _vizTimings;

  /// 左の絵に使うアカウントのアイコン(読み込み済み。無ければ null = 音符)。
  ui.Image? _avatar;
  bool _avatarTried = false;

  /// エディターの作り直し(書き出し直した動画で開き直す)ごとに増やす。
  int _videoGeneration = 0;
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
      _overlay.setFowSuspend(_suspendAll);
    });
    if (_isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      // 変換できない端末では、ファイルを書く前に伝える。
      if (_isAudio && !audioVideoSupported) throw UnsupportedError('この端末では音声を動画にできません(Android / iOS / macOS だけ)。音声のまま添付できます');
      var f = await videoEditTempFile(await getTemporaryDirectory(), widget.args.name);
      await f.writeAsBytes(widget.args.bytes, flush: true);
      if (!mounted) {
        _deleteQuietly(f);
        return;
      }
      if (_isAudio) {
        _audioFile = f;
        _vizConfig = AudioVisualizerConfig.decode(await ref.read(sessionStorageProvider).read(audioVisualizerStorageKey));
        final video = await _buildVisualizer();
        if (video == null) return;
        f = video;
      }
      _videoFile = f;
      await _openVideo(f);
    } catch (e) {
      if (mounted) setState(() => _videoError = e is UnsupportedError ? '${e.message}' : '${_isAudio ? '音声' : '動画'}を開けませんでした: $e');
    }
  }

  Future<ui.Image?> _loadImageFile(String path) async {
    try {
      return await decodeUiImage(await File(path).readAsBytes());
    } catch (_) {
      return null;
    }
  }

  /// アカウントのアイコン(1 回だけ取りに行く。取れなければ音符のまま)。
  Future<ui.Image?> _loadAvatar() async {
    if (_avatarTried) return _avatar;
    _avatarTried = true;
    final url = ref.read(currentUserProvider).avatarUrl;
    if (url == null) return null;
    try {
      final r = await http.get(url).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) _avatar = await decodeUiImage(r.bodyBytes);
    } catch (_) {}
    return _avatar;
  }

  Future<ui.Image?> _leftImageFor(AudioVisualizerConfig c) async => switch (c.left) {
        AudioVisualizerLeft.avatar => await _loadAvatar(),
        AudioVisualizerLeft.file => c.leftImagePath == null ? null : await _loadImageFile(c.leftImagePath!),
        _ => null,
      };

  /// 選んだファイルをアプリの保存領域へ写す(同じ種類の古いものは消す)。戻りは写した先のパス。
  Future<String?> _keepPicked(XFile? picked, String kind) async {
    if (picked == null) return null;
    final dir = await ref.read(visualizerDirProvider)();
    await dir.create(recursive: true);
    for (final old in dir.listSync().whereType<File>()) {
      if (old.uri.pathSegments.last.startsWith('${kind}_')) _deleteQuietly(old);
    }
    final m = RegExp(r'\.([A-Za-z0-9]{1,5})$').firstMatch(picked.name);
    final out = File('${dir.path}/${kind}_${DateTime.now().microsecondsSinceEpoch}.${(m?.group(1) ?? (kind == 'bg' ? 'mp4' : 'png')).toLowerCase()}');
    await out.writeAsBytes(await picked.readAsBytes(), flush: true);
    return out.path;
  }

  /// 背景の動画の、その時刻の 1 枚(設定 FOW のプレビュー用。端末ネイティブだけ)。
  Future<ui.Image?> _videoFrameAt(String path, Duration at) async {
    if (!audioVideoSupported) return null;
    try {
      final video = pve.EditorVideo.file(path);
      final meta = await pve.ProVideoEditor.instance.getMetadata(video);
      final frames = await pve.ProVideoEditor.instance.getThumbnails(pve.ThumbnailConfigs(video: video, outputSize: const Size(640, 360), timestamps: [audioBackgroundTimeAt(at, meta.duration)], boxFit: pve.ThumbnailBoxFit.cover, outputFormat: pve.ThumbnailFormat.jpeg));
      return frames.isEmpty ? null : await decodeUiImage(frames.first);
    } catch (_) {
      return null;
    }
  }

  /// 音声 → 2560×1440 の動画(その瞬間のスペクトル + シークバー、D-251 / D-253)。画面が閉じられていたら null。
  Future<File?> _buildVisualizer() async {
    final audio = _audioFile!;
    if (mounted) setState(() => _audioProgress = 0);
    _pcm ??= await loadAudioPcm(audio, audio.parent);
    final leftImage = await _leftImageFor(_vizConfig);
    File video;
    try {
      video = await buildAudioVisualizerVideo(
        audio: audio,
        pcm: _pcm!,
        workDir: audio.parent,
        config: _vizConfig,
        title: widget.args.name,
        leftImage: leftImage,
        cancelled: () => !mounted,
        onTimings: (t) => _vizTimings = t,
        onProgress: (p) {
          if (mounted) setState(() => _audioProgress = p);
        },
      );
    } finally {
      // 選んだ画像はその都度読む(アイコンは持ち続ける)。
      if (leftImage != null && !identical(leftImage, _avatar)) leftImage.dispose();
    }
    if (!mounted) {
      _deleteQuietly(video);
      return null;
    }
    setState(() => _audioProgress = null);
    return video;
  }

  Future<void> _openVideo(File f) async {
    final player = VideoPlayerController.file(f);
    _player = player;
    await player.initialize();
    await player.setLooping(false);
    await player.pause();
    final meta = await pve.ProVideoEditor.instance.getMetadata(pve.EditorVideo.file(f.path));
    if (!mounted) return;
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
  }

  /// 下段バーの「Visualizer」(D-251): 設定 FOW → 決定で保存して、動画を書き出し直して開き直す。
  Future<void> _editVisualizer() async {
    final next = await showAudioVisualizerFow(
      _overlay,
      initial: _vizConfig,
      pcm: _pcm,
      position: _player?.value.position ?? Duration.zero,
      title: widget.args.name,
      host: AudioVisualizerFowHost(
        avatar: await _loadAvatar(),
        lastTimings: _vizTimings,
        loadImage: _loadImageFile,
        loadVideoFrame: _videoFrameAt,
        pickImage: () async => _keepPicked(await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024), 'left'),
        pickVideo: () async => _keepPicked(await ImagePicker().pickVideo(source: ImageSource.gallery), 'bg'),
      ),
    );
    if (next == null || next == _vizConfig || !mounted) return;
    _vizConfig = next;
    await ref.read(sessionStorageProvider).write(audioVisualizerStorageKey, jsonEncode(next.toJson()));
    final old = _videoFile;
    final player = _player;
    player?.removeListener(_onPlayerTick);
    setState(() {
      _player = null;
      _video = null;
      _meta = null;
      _trim = null;
      _videoGeneration++;
    });
    await player?.dispose();
    try {
      final video = await _buildVisualizer();
      if (video == null) return;
      if (old != null) _deleteQuietly(old);
      _videoFile = video;
      await _openVideo(video);
    } catch (e) {
      if (mounted) setState(() => _videoError = '動画を書き出し直せませんでした: $e');
    }
  }

  static void _deleteQuietly(File f) => unawaited(f.delete().then<void>((_) {}, onError: (_) {}));

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
    final f = _videoFile;
    if (f != null) _deleteQuietly(f);
    final a = _audioFile;
    if (a != null) _deleteQuietly(a);
    _avatar?.dispose();
    super.dispose();
  }

  void _finish(MediaEditResult? result) {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context).pop(result);
  }

  /// プラグインの編集パネルを重ねて、結果を待つ。
  Future<MediaEditResult?> _runPanel(PluginAction action, {required Uint8List bytes, required String name, required String mimeType}) async {
    final done = Completer<MediaEditResult?>();
    setState(() => _panel = (action: action, bytes: bytes, name: name, mimeType: mimeType, done: done));
    final result = await done.future;
    if (!mounted) return null;
    setState(() => _panel = null);
    _overlay.setFowSuspend(_suspendAll); // パネルが戻すので、こちらでまた退避する
    return result;
  }

  /// 下の FOW(コンポーザー等)は退避。下段バーの編集(`actionbar.*`)と、そこから開く FOW / ドロップダウンは出す。
  static bool _suspendAll(RasqOverlayEntry e) => !e.id.startsWith('actionbar.') && !e.id.startsWith('media.pro.');

  /// プラグインのボタン (D-173 → D-249): 焼き込み → パネル → 結果を新しい背景に。動画は元のファイルを渡して差し替え。
  Future<void> _runPlugin(ProImageEditorState editor, PluginAction action) async {
    if (action.decl.isFilterOutput && !_isVideo) return _toggleFilter(editor, action);
    if (_bypassing) return;
    _bypassing = true;
    try {
      if (_isVideo) {
        final result = await _runPanel(action, bytes: widget.args.bytes, name: widget.args.name, mimeType: widget.args.mimeType);
        if (result != null) _finish(result);
        return;
      }
      final bytes = await editor.captureEditorImage();
      if (!mounted || bytes.isEmpty) return;
      final result = await _runPanel(action, bytes: bytes, name: _outName, mimeType: 'image/png');
      if (result == null || !mounted) return;
      // ジェネレーター(契約 v0.11 の `output: "sticker"`): 背景は変えず、結果をステッカーのレイヤーとして置く。
      if (action.decl.isStickerOutput) {
        editor.addLayer(WidgetLayer(widget: Image.memory(result.bytes, fit: BoxFit.contain, gaplessPlayback: true)));
        return;
      }
      // 焼き込み済みの状態を空にして、結果を背景に。
      editor.addHistory(layers: [], filters: [], tuneAdjustments: [], blur: 0, transformConfigs: TransformConfigs.empty());
      await editor.updateBackgroundImage(EditorImage(byteArray: result.bytes), updateHistory: false);
    } finally {
      _bypassing = false;
    }
  }

  /// カスタムフィルターのボタン (D-255 → D-257): OFF → ON(`filter.preview` の描画リストをレイヤーとして重ねる。パラメーターが
  /// あれば調整の FOW も開く)。ON のとき: パラメーターがあれば FOW を開き直す(外すのは FOW の「外す」)、無ければ OFF。
  Future<void> _toggleFilter(ProImageEditorState editor, PluginAction action) async {
    final active = _filters[action.id];
    if (active != null) {
      if (active.spec.value.params.isEmpty) return _removeFilter(editor, active);
      return _openFilterFow(editor, active);
    }
    if (_bypassing) return;
    _bypassing = true;
    final _ActiveFilter added;
    try {
      final size = editor.sizesManager.originalImageSize ?? editor.sizesManager.decodedImageSize;
      final seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
      final raw = await ref.read(slotPluginsProvider.notifier).filterPreview(action.plugin, actionId: action.decl.id, width: size.width.round(), height: size.height.round(), seed: seed);
      final spec = parseMediaFilterSpec(raw);
      if (!mounted) return;
      if (spec == null || spec.ops.isEmpty) {
        _notify('${action.decl.label}: フィルターを受け取れませんでした');
        return;
      }
      final shown = editor.sizesManager.decodedImageSize;
      final live = ValueNotifier(spec);
      final object = spec.object;
      final WidgetLayer layer;
      if (object == null) {
        // 絵いっぱい・動かせない・選べない(ただの見た目)。
        layer = WidgetLayer(
          width: shown.width,
          interaction: LayerInteraction(enableMove: false, enableScale: false, enableRotate: false, enableSelection: false, enableEdit: false),
          meta: {'rasqFilter': action.id},
          widget: IgnorePointer(child: SizedBox(width: shown.width, height: shown.height, child: CustomPaint(painter: MediaFilterPainter(live)))),
        );
      } else {
        // 動かせるオブジェクト (契約 v0.13): 短辺 × size の正方形を、絵の (x, y) に置く。移動 / 拡縮 / 回転はできる(中身の編集は無い)。
        final side = object.size * shown.shortestSide;
        layer = WidgetLayer(
          width: side,
          offset: Offset((object.x - 0.5) * shown.width, (object.y - 0.5) * shown.height),
          interaction: LayerInteraction(enableEdit: false),
          meta: {'rasqFilter': action.id},
          widget: SizedBox(width: side, height: side, child: CustomPaint(painter: MediaFilterPainter(live))),
        );
      }
      editor.addLayer(layer, blockSelectLayer: true);
      added = _filters[action.id] = _ActiveFilter(action: action, seed: seed, spec: live, layer: layer, width: size.width.round(), height: size.height.round(), params: {for (final p in spec.params) p.id: p.value});
      if (spec.dropped > 0) _notify('${action.decl.label}: 描画が多すぎるので ${spec.dropped} 個を省きました');
      setState(() {});
    } finally {
      _bypassing = false;
    }
    if (added.spec.value.params.isNotEmpty && mounted) await _openFilterFow(editor, added);
  }

  void _removeFilter(ProImageEditorState editor, _ActiveFilter f) {
    _filters.remove(f.action.id);
    editor.removeLayer(f.layer);
    if (mounted) setState(() {});
  }

  /// 調整の FOW (D-257、契約 v0.13): スライダーを動かすたびに `filter.preview` を呼び直して、置いてあるレイヤーの絵を差し替える。
  Future<void> _openFilterFow(ProImageEditorState editor, _ActiveFilter f) async {
    final remove = await showMediaFilterFow(
      _overlay,
      title: f.action.decl.label,
      spec: f.spec,
      onChanged: (id, value) async {
        f.params[id] = value;
        // 呼び直しは 1 つずつ(動かしている間に溜まったぶんは、最後の値だけ送る)。
        if (f.busy) {
          f.dirty = true;
          return;
        }
        f.busy = true;
        try {
          do {
            f.dirty = false;
            final raw = await ref.read(slotPluginsProvider.notifier).filterPreview(f.action.plugin, actionId: f.action.decl.id, width: f.width, height: f.height, seed: f.seed, params: Map.of(f.params));
            final next = parseMediaFilterSpec(raw);
            if (next != null && next.ops.isNotEmpty && _filters[f.action.id] == f) f.spec.value = next;
          } while (f.dirty && mounted);
        } finally {
          f.busy = false;
        }
      },
    );
    if (remove == true && mounted && _filters[f.action.id] == f) _removeFilter(editor, f);
  }

  void _notify(String message) => ref.read(rootMessengerKeyProvider).currentState?.showSnackBar(SnackBar(content: Text(message)));

  /// 完了 (D-255): `mode: "pixels"` のフィルターが掛かっていれば、そのプレビューを外して焼き込み直し、押した順に `filter.apply` を通す。
  /// 失敗したフィルターは飛ばして伝える(プレビューの見た目を黙って焼き込まない)。
  Future<void> _complete(Uint8List bytes) async {
    if (_completing) return;
    _completing = true;
    try {
      final pixels = [for (final f in _filters.values) if (f.spec.value.mode == MediaFilterMode.pixels) f];
      final editor = _imageEditor;
      if (pixels.isEmpty || editor == null) return _finish(MediaEditResult(bytes: bytes, mimeType: 'image/png', name: _outName));
      for (final f in pixels) {
        editor.removeLayer(f.layer);
      }
      var out = await editor.captureEditorImage();
      if (!mounted) return;
      if (out.isEmpty) out = bytes;
      var mime = 'image/png';
      final failed = <String>[];
      final slots = ref.read(slotPluginsProvider.notifier);
      for (final f in pixels) {
        final r = await slots.filterApply(f.action.plugin, actionId: f.action.decl.id, seed: f.seed, width: f.width, height: f.height, bytes: out, mimeType: mime, params: f.params.isEmpty ? null : Map.of(f.params));
        if (!mounted) return;
        if (r == null) {
          failed.add(f.action.decl.label);
        } else {
          out = r.$1;
          mime = r.$2;
        }
      }
      if (failed.isNotEmpty) _notify('適用できなかったフィルター: ${failed.join(' / ')}(この加工は入っていません)');
      final n = _outName;
      _finish(MediaEditResult(bytes: out, mimeType: mime, name: mime == 'image/png' ? n : '${n.substring(0, n.lastIndexOf('.'))}.${mime == 'image/jpeg' ? 'jpg' : mime.split('/').last}'));
    } finally {
      _completing = false;
    }
  }

  /// 「ノート」(D-260): 「ノート画像の追加」FOW で投稿を選び、その投稿タイルの画像を**オブジェクト(レイヤー)**として置く
  /// (動かす / 拡縮 / 回転 / 削除は pro_image_editor)。画像にも動画にも置ける。オブジェクトは静止画だけ。
  Future<void> _addPostObject(ProImageEditorState editor) async {
    final picked = await showPostImageFow(ref, id: 'media.pro.postImage', allowVideo: false);
    if (picked == null || !mounted) return;
    editor.addLayer(WidgetLayer(widget: Image.memory(picked.bytes, fit: BoxFit.contain, gaplessPlayback: true), meta: {'rasqPost': picked.post.key}));
  }

  String get _configKey => editorConfigKeyFor(widget.args.mimeType);

  /// この添付に出るプラグインボタン(宣言の `accepts` を実際の MIME / ファイル名で絞る)。
  List<PluginAction> get _pluginActions => [
        for (final a in ref.watch(pluginActionsForProvider(_configKey)))
          if (mediaAccepts(a.decl.accepts, mimeType: widget.args.mimeType, name: widget.args.name)) a,
      ];

  void _perform(ProImageEditorState editor, ActionDescriptor a, List<PluginAction> plugins) {
    switch (a.id) {
      case 'editor:cropRotate':
        editor.openCropRotateEditor();
      case 'editor:paint':
        editor.openPaintEditor();
      case 'editor:text':
        editor.openTextEditor();
      case 'editor:post':
        _addPostObject(editor);
      case 'editor:sticker':
        editor.openStickerEditor();
      case 'editor:emoji':
        editor.openEmojiEditor();
      case 'editor:filter':
        editor.openFilterEditor();
      case 'editor:blur':
        editor.openBlurEditor();
      case 'editor:tune':
        editor.openTuneEditor();
      case editorVisualizerActionId:
        _editVisualizer();
      default:
        final p = plugins.where((x) => x.id == a.id).firstOrNull;
        if (p != null) _runPlugin(editor, p);
    }
  }

  Widget _bar(ProImageEditorState editor, Key key) {
    _imageEditor = editor;
    const style = TextStyle(fontSize: 10, color: Colors.white);
    Widget item(String id, String label, Widget icon, void Function(BuildContext ctx) onTap, {Color color = Colors.white, Key? key}) => Builder(
          builder: (ctx) => FlatIconTextButton(key: key ?? proMediaEditorBarKey(id), label: Text(label, style: style.copyWith(color: color)), icon: icon, onPressed: () => onTap(ctx)),
        );
    final plugins = _pluginActions;
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(_configKey)),
      // 「Visualizer」は音声を開いているときだけ(動画のバーの構成には常に居る)。
      snsActions: [for (final a in editorBuiltinActionsFor(_configKey)) if (a.id != editorVisualizerActionId || _isAudio) a],
      plugins: plugins,
      settings: ref.watch(slotActionSettingsProvider(slotSettingsKeyFor(_configKey, ''))),
    );
    final entries = merged.config.apply(merged.actions);
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
                for (final e in entries)
                  switch (e) {
                    SingleActionEntry() => item(
                        e.action.id,
                        e.action.label,
                        Icon(_filters.containsKey(e.action.id) ? Icons.check_circle : PostRow.iconFor(e.action.icon, Icons.extension_outlined), size: 22, color: isPluginActionId(e.action.id) ? RasqColors.accent : Colors.white),
                        (_) => _perform(editor, e.action, plugins),
                        color: isPluginActionId(e.action.id) ? RasqColors.accent : Colors.white,
                      ),
                    ActionListEntry() => item(
                        ActionBarConfig.listKey(e.list.id),
                        e.list.name,
                        SizedBox(width: 22, height: 22, child: Center(child: bundleIconWidget(e.list, e.members, size: 22, color: Colors.white))),
                        (ctx) {
                          final box = ctx.findRenderObject() as RenderBox;
                          showActionBundleMenuFow(ref, anchor: box.localToGlobal(Offset.zero) & box.size, entry: e, onPick: (a) async => _perform(editor, a, plugins));
                        },
                      ),
                  },
                // バーの編集(並べ替え / バンドル / プラグインボタンの追加・削除)。
                item('edit', 'バーの編集', const Icon(Icons.dashboard_customize_outlined, size: 22, color: Colors.white54), (_) => showActionBarEditSheet(ref, surfaces: [_isVideo ? ActionBarSurface.editorVideo : ActionBarSurface.editorImage]), color: Colors.white54, key: proMediaEditorBarEditKey),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  /// エディターの上にプラグインの編集パネルを重ねる。
  Widget _withPanel(Widget editor) {
    final p = _panel;
    return Stack(fit: StackFit.expand, children: [
      editor,
      if (p != null)
        Positioned.fill(
          child: MediaPluginPanel(
            key: ValueKey('media.panel.${p.action.id}'),
            plugin: p.action.plugin,
            bytes: p.bytes,
            name: p.name,
            mimeType: p.mimeType,
            actionId: p.action.decl.id == mediaEditDefaultActionId ? null : p.action.decl.id,
            onDone: (r) {
              if (!p.done.isCompleted) p.done.complete(r);
            },
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_isVideo) return _buildVideo(context);
    // バーの中身(プラグイン / 構成)の変化で作り直す。
    ref.watch(pluginActionsForProvider(_configKey));
    ref.watch(actionBarConfigProvider(_configKey));
    ref.watch(slotActionSettingsProvider('editor'));
    return _withPanel(ProImageEditor.memory(
      widget.args.bytes,
      key: _editorKey,
      callbacks: ProImageEditorCallbacks(
        onImageEditingComplete: _complete,
        onCloseEditor: (mode) {
          if (mode == EditorMode.main) _finish(null);
        },
      ),
      configs: ProImageEditorConfigs(
        i18n: rasqEditorI18n,
        stickerEditor: StickerEditorConfigs(
          builder: (setLayer, scrollController) => StickerPicker(
            setLayer: setLayer,
            scrollController: scrollController,
            generators: [for (final a in _pluginActions) if (a.decl.isStickerOutput && !_isVideo) a],
            onGenerate: (a) {
              // ステッカー一覧を閉じてから、プラグインの編集パネルへ。
              Navigator.of(context).maybePop();
              final editor = _imageEditor;
              if (editor != null) _runPlugin(editor, a);
            },
          ),
        ),
        // 出力は PNG(バイパスの往復で劣化させない。添付の差し替えも PNG)。
        imageGeneration: const ImageGenerationConfigs(outputFormat: OutputFormat.png),
        mainEditor: MainEditorConfigs(
          widgets: MainEditorWidgets(
            bottomBar: (editor, rebuildStream, key) => ReactiveWidget(stream: rebuildStream, builder: (_) => _bar(editor, key)),
          ),
        ),
      ),
    ));
  }

  Widget _buildVideo(BuildContext context) {
    final v = _video;
    final err = _videoError;
    if (v == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: [
            Center(
              child: err == null
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(value: _audioProgress),
                      if (_audioProgress != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text('音声を動画に変換しています… ${(_audioProgress! * 100).round()}%', key: proMediaEditorAudioNoteKey, style: const TextStyle(color: Colors.white70))),
                    ])
                  : Padding(padding: const EdgeInsets.all(24), child: Text(err, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center))),
            Positioned(left: 8, top: 8, child: RasqIconButton(icon: Icons.close, color: Colors.white, tooltip: 'キャンセル', onPressed: () => _finish(null))),
          ]),
        ),
      );
    }
    ref.watch(pluginActionsForProvider(_configKey));
    ref.watch(actionBarConfigProvider(_configKey));
    ref.watch(slotActionSettingsProvider('editor'));
    return _withPanel(ProImageEditor.video(
      v,
      key: ValueKey('media.pro.video.$_videoGeneration'),
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
        stickerEditor: StickerEditorConfigs(
          builder: (setLayer, scrollController) => StickerPicker(
            setLayer: setLayer,
            scrollController: scrollController,
            generators: [for (final a in _pluginActions) if (a.decl.isStickerOutput && !_isVideo) a],
            onGenerate: (a) {
              // ステッカー一覧を閉じてから、プラグインの編集パネルへ。
              Navigator.of(context).maybePop();
              final editor = _imageEditor;
              if (editor != null) _runPlugin(editor, a);
            },
          ),
        ),
        videoEditor: const VideoEditorConfigs(initialMuted: false, initialPlay: false, isAudioSupported: false, minTrimDuration: Duration(seconds: 1)),
        mainEditor: MainEditorConfigs(
          tools: const [SubEditorMode.paint, SubEditorMode.text, SubEditorMode.cropRotate, SubEditorMode.tune, SubEditorMode.filter, SubEditorMode.blur, SubEditorMode.emoji, SubEditorMode.sticker],
          widgets: MainEditorWidgets(
            bottomBar: (editor, rebuildStream, key) => ReactiveWidget(stream: rebuildStream, builder: (_) => _bar(editor, key)),
          ),
        ),
      ),
    ));
  }
}

/// 掛かっているカスタムフィルター 1 つ (D-255 / D-257)。
class _ActiveFilter {
  _ActiveFilter({required this.action, required this.seed, required this.spec, required this.layer, required this.width, required this.height, required this.params});
  final PluginAction action;

  /// 掛けている間変わらない乱数の種(プレビューと `filter.apply` で同じ絵になるように)。
  final int seed;

  /// いまの描画リスト(パラメーターを変えると差し替わる。レイヤーはこれを見て描き直す)。
  final ValueNotifier<MediaFilterSpec> spec;
  final WidgetLayer layer;
  final int width;
  final int height;

  /// いまのパラメーター(id → 値)。`filter.preview` の呼び直しと `filter.apply` に付ける。
  final Map<String, double> params;
  bool busy = false;
  bool dirty = false;
}
