import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_image_editor/features/crop_rotate_editor/models/transform_configs.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
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

  /// 差し替え後のファイル名(pro_image_editor の出力は PNG)。
  String get _outName {
    final n = widget.args.name;
    final dot = n.lastIndexOf('.');
    return '${dot > 0 ? n.substring(0, dot) : n}.png';
  }

  @override
  void dispose() {
    _barScroll.dispose();
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
    var pick = plugins.length == 1 ? plugins.first : null;
    if (pick == null) {
      final manager = ref.read(overlayManagerProvider);
      pick = await manager.showBottomSheet<SlotPlugin>(
        id: 'media.pro.plugin',
        title: 'プラグインで加工',
        builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
          for (final p in plugins) RasqListTile(title: p.manifest.name, subtitle: p.manifest.description, onTap: () => manager.close('media.pro.plugin', result: p)),
        ]),
      );
    }
    if (pick == null || !mounted) return;
    _bypassing = true;
    try {
      final bytes = await editor.captureEditorImage();
      if (!mounted || bytes.isEmpty) return;
      final result = await context.pushMediaEditor(plugin: pick, bytes: bytes, name: _outName, mimeType: 'image/png');
      if (!mounted || result == null) return;
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
}
