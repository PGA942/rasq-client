import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show ValueListenable;
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
import 'package:rrl_renderer/rrl_renderer.dart' show SvgLite;

import '../media/fow_avoid.dart';
import '../../app/providers.dart';
import '../../shell/column_takeover.dart';
import '../../shell/extra_column.dart';
import '../ads/export_ad.dart';
import '../compose/post_image_fow.dart';
import '../compose/post_video.dart';
import '../home/action_bar_config.dart';
import '../media/audio_visualizer_fow.dart';
import '../media/audio_visualizer_video.dart';
import '../home/action_bar_edit_sheet.dart';
import '../home/action_bundle_fow.dart';
import '../home/plugin_actions.dart';
import '../home/post_row.dart';
import 'media_filter.dart';
import 'media_filter_fow.dart';
import 'media_object_fow.dart';
import 'media_plugin_panel.dart';
import 'pro_video_export.dart';
import 'slot_plugins.dart';
import 'sticker_picker.dart';
import 'svg_paint_editor.dart';

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
///
/// **モード (D-472)**: 添付の種類(MIME / 拡張子、[mediaEditorModeOf])で道具と下段バーを変える、1 つの加工画面。
/// - 画像 = pro_image_editor の道具(構成 `editor:image`)、動画 / 音声 = 動画モード(`editor:video`、音声だけ Visualizer)。
/// - **SVG**(`image/svg+xml` / `.svg`。契約 v0.22 の `media.editor.open` = [ProMediaEditorArgs.svg] も)= pro_image_editor が扱えないので、
///   **SVG の道具に載せ替える**: 紙の面は [SvgPaintEditor](ペン / 消しゴム / 色 / 太さ / 取り消し。D-473 が持つ部品をそのまま置く)、
///   その下に同じ仕組みの下段バー(構成 `editor:svg`)= `accepts` に `image/svg+xml` / `.svg` を書いたプラグインのボタンと「バーの編集」
///   ([svgEditorAccepts]。動画 / 音声だけの編集、ラスターの編集、ステッカー / フィルターは出ない)。プラグインのボタンは、そのときの絵を
///   SVG で `media.edit` に渡し、返った SVG(消毒する)で紙を描き直す。閉じると `media.editor.open` なら [SvgPaintResult](保存)か
///   null(やめた)、添付の SVG なら [MediaEditResult]。ページ型プラグインの「みんなで落書き」(plugin-sample custom-plugin-paint)が使う。
class ProMediaEditorArgs {
  const ProMediaEditorArgs({required this.bytes, required this.name, required this.mimeType, this.extraActions = const [], this.avoidFows = false})
      : svgAspect = null,
        svg = null,
        svgTitle = null;

  /// SVG モード (D-465、`media.editor.open`): `aspect` = `"<w>:<h>"`、`svg` = 続きから描く SVG(消毒してから読む)。結果は [SvgPaintResult]。
  ProMediaEditorArgs.svg({String aspect = '3:4', this.svg, String? title})
      : bytes = Uint8List(0),
        name = 'paint.svg',
        mimeType = 'image/svg+xml',
        extraActions = const [],
        avoidFows = false,
        svgAspect = aspect,
        svgTitle = title;

  final Uint8List bytes;

  /// `media.editor.open` の SVG モードの縦横比(null = 添付の編集)。
  final String? svgAspect;
  final String? svg;
  final String? svgTitle;

  /// 道具と下段バーのモード (D-472)。`media.editor.open` はいつも SVG、添付は MIME / 拡張子で。
  MediaEditorMode get mode => svgAspect != null ? MediaEditorMode.svg : mediaEditorModeOf(mimeType: mimeType, name: name);
  bool get isSvg => mode == MediaEditorMode.svg;

  /// `media.editor.open` から開いた(結果は [SvgPaintResult])。添付の SVG は [MediaEditResult]。
  bool get isPaint => svgAspect != null;

  /// 全画面のメディア表示と同じく、出ている FOW(編集の FOW など)の逆サイドへ面を寄せる (D-413: Swing の編集の段)。
  final bool avoidFows;
  final String name;
  final String mimeType;

  /// 下段バーの先頭に足すボタン(呼んだ画面が決める。Swing の「プラグイン」「背景を変える」、D-386)。
  final List<ProEditorExtraAction> extraActions;
}

/// 下段バーに足すボタン。キーは `media.pro.bar.extra:<id>`。
class ProEditorExtraAction {
  const ProEditorExtraAction({required this.id, required this.label, required this.icon, required this.onTap, this.onLongPress, this.liveLabel});
  final String id;
  final String label;

  /// 変わる名前(Swing の「24 時間で消える」など、D-410)。あれば [label] の代わりに出し、変わったら描き直す。
  final ValueListenable<String>? liveLabel;
  final IconData icon;
  final void Function(ProEditorHandle editor) onTap;

  /// 長押し(無ければ長押しでは何もしない)。
  final void Function(ProEditorHandle editor)? onLongPress;
}

/// 足したボタンから使えるエディターの操作。
abstract class ProEditorHandle {
  /// エディター画面(シートを出す / 閉じる)。
  BuildContext get context;

  /// 動画(または音声)を開いているか。動画では背景を差し替えられない。
  bool get isVideo;

  /// 背景の絵を差し替える(「ひとつ戻す」で戻せる)。
  Future<void> setBackground(Uint8List bytes);

  /// 何も返さずに閉じる。
  void close();
}

class _ProEditorHandle implements ProEditorHandle {
  _ProEditorHandle(this.editor, this.context, this.isVideo);
  final ProImageEditorState editor;
  @override
  final BuildContext context;
  @override
  final bool isVideo;
  @override
  Future<void> setBackground(Uint8List bytes) => editor.updateBackgroundImage(EditorImage(byteArray: bytes));
  @override
  void close() => Navigator.of(context).pop();
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

/// FOW を避けるときのエディターの面 ([ProMediaEditorArgs.avoidFows])。
const proMediaEditorAreaKey = Key('media.pro.area');
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

class ProMediaEditorScreen extends StatelessWidget {
  const ProMediaEditorScreen({super.key, required this.args});
  final ProMediaEditorArgs args;
  @override
  Widget build(BuildContext context) => args.isSvg ? _SvgMode(args: args) : _ProMediaEditor(args: args);
}

class _ProMediaEditor extends ConsumerStatefulWidget {
  const _ProMediaEditor({required this.args});
  final ProMediaEditorArgs args;
  @override
  ConsumerState<_ProMediaEditor> createState() => _ProMediaEditorScreenState();
}

/// 加工画面を閉じる: 足したカラム (D-472) / カラムの置き換え (D-413) の中ならそれを閉じ、全画面のルートなら戻る。
void closeMediaEditor(BuildContext context, [Object? result]) {
  if (ExtraColumnScope.closeOf(context, result) || ColumnTakeoverScope.closeOf(context, result)) return;
  Navigator.of(context).pop(result);
}

/// `"<w>:<h>"`(1〜16 の整数)で [w] : [h] にいちばん近いもの(添付の SVG の viewBox の縦横比を、落書きの紙に合わせる、D-472)。
String nearestPaintAspect(double w, double h) {
  if (!(w > 0 && h > 0) || !w.isFinite || !h.isFinite) return '3:4';
  final want = w / h;
  var best = (1, 1);
  var err = double.infinity;
  for (var a = 1; a <= 16; a++) {
    for (var b = 1; b <= 16; b++) {
      final e = (a / b - want).abs() / want;
      if (e < err - 1e-12) {
        err = e;
        best = (a, b);
      }
    }
  }
  final g = best.$1.gcd(best.$2);
  return '${best.$1 ~/ g}:${best.$2 ~/ g}';
}

/// SVG モードのキー (D-472)。
const proMediaEditorSvgKey = ValueKey('media.svg.editor');
const proMediaEditorSvgBarKey = Key('media.pro.svg.bar');

/// SVG モード (D-465 → D-472): 紙の面([SvgPaintEditor]、そのまま置く)+ 加工画面と同じ仕組みの下段バー(構成 `editor:svg`)。
/// アプリの外(ProviderScope の無いところ)でも紙だけで動く(バーとプラグインは無し)。
class _SvgMode extends StatefulWidget {
  const _SvgMode({required this.args});
  final ProMediaEditorArgs args;
  @override
  State<_SvgMode> createState() => _SvgModeState();
}

class _SvgModeState extends State<_SvgMode> {
  final _barScroll = ScrollController();
  bool _closed = false;

  /// 紙に読ませる SVG(プラグインの結果で差し替える)と、描き直しの回数(紙を作り直す鍵)。
  late String? _svg = widget.args.isPaint ? widget.args.svg : _attachmentSvg;
  late final String _aspect = widget.args.svgAspect ?? _attachmentAspect;
  int _generation = 0;

  /// 押されたプラグインのボタン(紙の「完了」で今の絵を受けてから、編集パネルへ渡す)。
  PluginAction? _pending;

  /// 重ねているプラグインの編集パネル。
  ({PluginAction action, Uint8List bytes, Completer<MediaEditResult?> done})? _panel;
  final _paperKey = GlobalKey();

  String? get _attachmentSvg {
    try {
      return utf8.decode(widget.args.bytes, allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  String get _attachmentAspect {
    final doc = _svg == null ? null : SvgLite.parse(_svg!);
    return doc == null ? '3:4' : nearestPaintAspect(doc.viewBox.width, doc.viewBox.height);
  }

  String get _name {
    final n = widget.args.name;
    return n.toLowerCase().endsWith('.svg') ? n : '${n.replaceFirst(RegExp(r'\.[A-Za-z0-9]{1,5}$'), '')}.svg';
  }

  @override
  void dispose() {
    _barScroll.dispose();
    super.dispose();
  }

  void _done(SvgPaintResult? r) {
    // プラグインのボタンのために「完了」を押した: 閉じずに、今の絵をパネルへ。
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      if (r != null) unawaited(_runPlugin(pending, r));
      return;
    }
    if (_closed) return;
    _closed = true;
    final Object? result = r == null || widget.args.isPaint ? r : MediaEditResult(bytes: Uint8List.fromList(utf8.encode(r.svg)), mimeType: svgMimeType, name: _name);
    closeMediaEditor(context, result);
  }

  /// SVG を受けるプラグインのボタン (D-472、契約 v0.23 §2.2)。紙は外から読めない部品なので、紙の「完了」を押して今の絵を受け取り
  /// ([_done] が閉じずにここへ回す)、`media.edit` へ SVG で渡す。返った SVG は消毒して紙を描き直す(取り消しの段はそこから)。
  void _onPlugin(PluginAction a) {
    if (_panel != null || _pending != null) return;
    final done = _findPaperDone();
    if (done == null) return _toast('いまは使えません(紙の「完了」が見つかりません)');
    _pending = a;
    done();
    // 紙が完了を返さなかった(空の絵を返さない作りなど)。
    if (identical(_pending, a)) _pending = null;
  }

  /// 紙の「完了」ボタン(`svgpaint.done`)の押し口。
  VoidCallback? _findPaperDone() {
    VoidCallback? found;
    void visit(Element e) {
      if (found != null) return;
      final w = e.widget;
      if (w.key == const ValueKey('svgpaint.done') && w is ButtonStyleButton) {
        found = w.onPressed;
        return;
      }
      e.visitChildElements(visit);
    }
    final root = _paperKey.currentContext;
    if (root is Element) root.visitChildElements(visit);
    return found;
  }

  Future<void> _runPlugin(PluginAction a, SvgPaintResult current) async {
    final done = Completer<MediaEditResult?>();
    setState(() => _panel = (action: a, bytes: Uint8List.fromList(utf8.encode(current.svg)), done: done));
    final r = await done.future;
    if (!mounted) return;
    String? next;
    if (r != null) {
      final svg = mediaEditorModeOf(mimeType: r.mimeType, name: r.name ?? '') == MediaEditorMode.svg ? SvgLite.parse(utf8.decode(r.bytes, allowMalformed: true)) : null;
      if (svg == null) _toast('${a.plugin.manifest.name} が SVG を返さなかったので、使いませんでした');
      next = svg?.toSvg();
    }
    setState(() {
      _panel = null;
      // 適用しなかったときも、完了で受け取った今の絵から続ける(紙は作り直す)。
      _svg = next ?? current.svg;
      _generation++;
    });
  }

  /// アプリの ProviderScope(無ければ null = 紙だけ)。
  ProviderContainer? get _container {
    try {
      return ProviderScope.containerOf(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  void _toast(String text) {
    _container?.read(rootMessengerKeyProvider).currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  /// SVG を受けるプラグインのボタンのバー(無ければ出さない。SVG の道具は紙の面にある)。
  Widget _bar() => Consumer(builder: (context, ref, _) {
        final plugins = [
          for (final p in ref.watch(pluginActionsForProvider(editorSvgConfigKey)))
            if (mediaAccepts(p.decl.accepts, mimeType: svgMimeType, name: _name)) p,
        ];
        if (plugins.isEmpty) return const SizedBox.shrink();
        return EditorActionBar(
          key: proMediaEditorSvgBarKey,
          configKey: editorSvgConfigKey,
          surface: ActionBarSurface.editorSvg,
          plugins: plugins,
          controller: _barScroll,
          onPerform: (d) {
            final hit = plugins.where((x) => x.id == d.id).firstOrNull;
            if (hit != null) _onPlugin(hit);
          },
        );
      });

  @override
  Widget build(BuildContext context) {
    final a = widget.args;
    final paper = SvgPaintEditor(key: ValueKey('media.svg.paper.$_generation'), aspect: _aspect, initialSvg: _svg, title: a.svgTitle ?? (a.isPaint ? null : a.name), onDone: _done);
    final p = _panel;
    return Material(
      key: proMediaEditorSvgKey,
      child: Stack(fit: StackFit.expand, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: KeyedSubtree(key: _paperKey, child: paper)),
          if (_container != null) _bar(),
        ]),
        if (p != null)
          Positioned.fill(
            child: MediaPluginPanel(
              key: ValueKey('media.panel.${p.action.id}'),
              plugin: p.action.plugin,
              bytes: p.bytes,
              name: _name,
              mimeType: svgMimeType,
              actionId: p.action.decl.id == mediaEditDefaultActionId ? null : p.action.decl.id,
              onDone: (r) {
                if (!p.done.isCompleted) p.done.complete(r);
              },
            ),
          ),
      ]),
    );
  }
}

/// 加工画面の下段バー (D-249 → D-472): 内蔵の編集 + プラグインのボタンを構成([configKey])どおりに並べ、最後に「バーの編集」。
/// 画像 / 動画 / SVG のモードで同じ枠と並べ方(並べ替え / バンドル / プラグインのボタンの追加・削除)を使う。
class EditorActionBar extends ConsumerWidget {
  const EditorActionBar({
    super.key,
    required this.configKey,
    required this.surface,
    required this.plugins,
    required this.controller,
    required this.onPerform,
    this.builtins = const [],
    this.leading = const [],
    this.activeIds = const {},
    this.onLongPressFor,
  });
  final String configKey;
  final ActionBarSurface surface;
  final List<PluginAction> plugins;
  final ScrollController controller;
  final void Function(ActionDescriptor action) onPerform;

  /// 内蔵の編集(モードごと)。
  final List<ActionDescriptor> builtins;

  /// 先頭に足すボタン(呼んだ画面のもの)。
  final List<Widget> leading;

  /// 掛かっている(チェックの印を付ける)ボタン。
  final Set<String> activeIds;

  /// ボタンの長押し(無ければ null)。
  final void Function(BuildContext ctx)? Function(String id)? onLongPressFor;

  static const _style = TextStyle(fontSize: 10, color: Colors.white);

  /// バーのボタン 1 つ。キーは `media.pro.bar.<id>`。
  static Widget item(String id, String label, Widget icon, void Function(BuildContext ctx) onTap, {Color color = Colors.white, Key? key, void Function(BuildContext ctx)? onLongPress}) => Builder(
        builder: (ctx) {
          final button = FlatIconTextButton(key: key ?? proMediaEditorBarKey(id), label: Text(label, style: _style.copyWith(color: color)), icon: icon, onPressed: () => onTap(ctx));
          return onLongPress == null ? button : GestureDetector(onLongPress: () => onLongPress(ctx), child: button);
        },
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merged = mergePluginActions(
      config: ref.watch(actionBarConfigProvider(configKey)),
      snsActions: builtins,
      plugins: plugins,
      settings: ref.watch(slotActionSettingsProvider(slotSettingsKeyFor(configKey, ''))),
      prefs: ref.watch(actionButtonPrefsProvider),
    );
    final entries = merged.config.apply(merged.actions);
    return Scrollbar(
      controller: controller,
      thickness: 0,
      // material_ui の Scaffold の下なので flutter/material の BottomAppBar は使わない(素の箱で十分)。
      child: Container(
        height: kBottomNavigationBarHeight,
        color: Colors.black,
        child: Center(
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                ...leading,
                for (final e in entries)
                  switch (e) {
                    SingleActionEntry() => item(
                        e.action.id,
                        e.action.label,
                        Icon(activeIds.contains(e.action.id) ? Icons.check_circle : PostRow.iconFor(e.action.icon, Icons.extension_outlined), size: 22, color: isPluginActionId(e.action.id) ? RasqColors.accent : Colors.white),
                        (_) => onPerform(e.action),
                        color: isPluginActionId(e.action.id) ? RasqColors.accent : Colors.white,
                        onLongPress: onLongPressFor?.call(e.action.id),
                      ),
                    ActionListEntry() => item(
                        ActionBarConfig.listKey(e.list.id),
                        e.list.name,
                        SizedBox(width: 22, height: 22, child: Center(child: bundleIconWidget(e.list, e.members, size: 22, color: Colors.white))),
                        (ctx) {
                          final box = ctx.findRenderObject() as RenderBox;
                          showActionBundleMenuFow(ref, anchor: box.localToGlobal(Offset.zero) & box.size, entry: e, onPick: (a) async => onPerform(a));
                        },
                      ),
                  },
                // バーの編集(並べ替え / バンドル / プラグインボタンの追加・削除)。
                item('edit', 'バーの編集', const Icon(Icons.dashboard_customize_outlined, size: 22, color: Colors.white54), (_) => showActionBarEditSheet(ref, surfaces: [surface]), color: Colors.white54, key: proMediaEditorBarEditKey),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// `media.editor.open` の開き方(ページの画面が [CustomPageController.editorOpener] に渡す)。
/// 戻り = 結果(保存 = [SvgPaintResult]、やめた / 閉じられた = null)と、外から閉じる口(ページを閉じた / 開き直す)。
typedef SvgPaintOpener = ({Future<SvgPaintResult?> result, VoidCallback close}) Function({required String aspect, String? svg, String? title});

/// 足したカラム (D-472) / 全画面のルートの id。
const svgPaintTakeoverId = 'media.svg.editor';

/// 落書きの編集画面を開く (D-465 → D-472、契約 v0.22 / v0.23 `media.editor.open`)。
/// - **広い画面**(≥ [RasqSizes.tabletBreakpoint])で、ページが**カラムの中**([ColumnTakeoverHost] の下 = ホームのカラムのページ /
///   右のカラムの Swing やページ)にあり、そのカラムが見えている(上に全画面のルートが被っていない、[_shownInShell])なら、
///   **そのカラムの右にもう 1 カラム**足して開く([ExtraColumnStore]。ページも隣のカラムも隠さない。フォーカスは編集画面へ)。
/// - **狭い画面**と、**カラムの外の全画面のルート**(全画面を選んだ / 全画面を指定したプラグインの Swing のビューワー `/swing`、
///   `/custom/page/…`)は全画面のルート。D-468: 全画面のルートはカラムの上に被さっているので、カラムに出すと編集画面がその下に隠れる。
({Future<SvgPaintResult?> result, VoidCallback close}) openSvgPaintEditor(BuildContext context, {required String aspect, String? svg, String? title}) {
  final args = ProMediaEditorArgs.svg(aspect: aspect, svg: svg, title: title);
  final host = context.findAncestorWidgetOfExactType<ColumnTakeoverHost>();
  if (MediaQuery.sizeOf(context).width >= RasqSizes.tabletBreakpoint && host != null && _shownInShell(context)) {
    final store = ProviderScope.containerOf(context, listen: false).read(extraColumnProvider.notifier);
    final result = store.open<SvgPaintResult>(id: svgPaintTakeoverId, afterColumn: host.column, builder: (_) => ProMediaEditorScreen(args: args));
    return (result: result, close: () => store.close(id: svgPaintTakeoverId));
  }
  final route = PageRouteBuilder<SvgPaintResult>(
    settings: const RouteSettings(name: svgPaintTakeoverId),
    pageBuilder: (_, _, _) => ProMediaEditorScreen(args: args),
    transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
  );
  final nav = Navigator.of(context, rootNavigator: true);
  final result = nav.push(route);
  return (
    result: result,
    close: () {
      if (route.isActive) nav.removeRoute(route);
    },
  );
}

/// [context] の画面が、入れ子の Navigator のどの段でもいちばん上のルートにある(全画面のルートが上に被っていない)。
bool _shownInShell(BuildContext context) {
  BuildContext? c = context;
  while (c != null && c.mounted) {
    if (ModalRoute.of(c) case final route? when !route.isCurrent) return false;
    final nav = c.findAncestorStateOfType<NavigatorState>();
    if (nav == null) return true;
    c = nav.context;
  }
  return true;
}

class _ProMediaEditorScreenState extends ConsumerState<_ProMediaEditor> {
  final _editorKey = GlobalKey<ProImageEditorState>();
  final _barScroll = ScrollController();
  bool _closing = false;
  bool _bypassing = false;

  /// 掛かっているカスタムフィルター (D-255、契約 v0.12)。ボタンの id → 状態(フラグ管理: 掛かっているか / 完了時に apply が要るか)。
  final Map<String, _ActiveFilter> _filters = {};

  /// 開いた瞬間に掛けるフィルター(契約 v0.14 temp、D-305)を済ませたか(1 回だけ)。
  bool _autoFiltersDone = false;

  /// 完了時の処理中(二重に走らせない)。
  bool _completing = false;

  /// 置いてある「動く投稿」(D-261): レイヤーの meta `rasqPostVideo` → 動画の中身と、タイルの 高さ / 幅。完了で動画に書き出す。
  final Map<String, ({Uint8List video, double width, double aspect})> _motionPosts = {};

  /// 動くオブジェクトの、加工画面での再生 (D-264): id → 再生器(用意できるまで null)と、その元のファイル。
  final Map<String, ({ValueNotifier<VideoPlayerController?> player, File file})> _objectPlayers = {};

  /// 書き出しのために画面を写す間は false(動画の面は写せないので、下の静止画を見せる)。
  final ValueNotifier<bool> _objectsLive = ValueNotifier(true);

  /// 再生器の入れ物(オブジェクト 1 つに 1 つ。用意の途中でも、ここにあれば作り直さない)。
  final Map<String, ValueNotifier<VideoPlayerController?>> _objectPlayerHolders = {};

  /// 画面に出ている動くオブジェクト(id → その要素。先に出たものが先頭 = 加工画面の本物。書き出しの写し用の複製は後ろ)。
  final Map<String, List<BuildContext>> _objectContexts = {};

  /// 本体の動画が画面に出ている要素(枠を測る。エディターは動画の面を複数の場所に作るので GlobalKey は使えない。先頭 = 最初に出たもの)。
  final List<BuildContext> _videoAreaContexts = [];

  /// 置いたオブジェクトの設定 (D-266): meta `rasqObject` → 繰り返し / 速さ / 音 / 不透明度。
  final Map<String, ValueNotifier<MediaObjectSettings>> _objectSettings = {};

  /// 動画の書き出しに失敗した直後(エディターの「完了 → 閉じる」を 1 回だけ無視して、加工を続けられるようにする)。
  bool _renderFailed = false;

  /// 置いた投稿オブジェクトの絵(閉じるときに捨てる)。
  final List<ui.Image> _postImages = [];

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

  /// 「完了」で動画を書き出している間の進み具合(0..1、書き出し中だけ。書き出し中の表示と広告の枠 D-327)。
  final ValueNotifier<double?> _renderProgress = ValueNotifier(null);

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
      videoPlayer: AspectRatio(aspectRatio: player.value.aspectRatio == 0 ? 16 / 9 : player.value.aspectRatio, child: _Registered(mounted: _videoAreaContexts, child: VideoPlayer(player))),
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
    // D-420: 何も変えていなければ書き出し直さず、元のファイルを返す(向きの印 = tkhd の行列をそのまま残す)。
    if (!_isAudio && !proVideoNeedsRender(p, mimeType: widget.args.mimeType, duration: m.duration, audioEnabled: _video?.isAudioEnabled ?? true)) {
      _finish(MediaEditResult(bytes: widget.args.bytes, mimeType: widget.args.mimeType, name: widget.args.name));
      return;
    }
    try {
      final data = pve.VideoRenderData(
        id: 'rasq-${DateTime.now().microsecondsSinceEpoch}',
        videoSegments: [pve.VideoSegment(video: pve.EditorVideo.file(f.path))],
        imageLayers: [if (p.layers.isNotEmpty) pve.ImageLayer(image: pve.EditorLayerImage.memory(p.image))],
        blur: p.blur,
        colorFilters: proVideoColorFilters(p),
        startTime: p.startTime,
        endTime: p.endTime,
        transform: proVideoExportTransform(p),
        enableAudio: _video?.isAudioEnabled ?? true,
        outputFormat: pve.VideoOutputFormat.mp4,
        bitrate: m.bitrate,
      );
      _renderProgress.value = 0;
      StreamSubscription<pve.ProgressModel>? progress;
      Uint8List bytes;
      try {
        try {
          progress = data.progressStream.listen((e) => _renderProgress.value = e.progress.clamp(0.0, 1.0), onError: (Object _) {});
        } catch (_) {
          progress = null; // 進み具合が取れない端末でも書き出しは続ける
        }
        bytes = await pve.ProVideoEditor.instance.renderVideo(data);
      } finally {
        await progress?.cancel();
      }
      if (!mounted) return;
      // 動くオブジェクト (D-262): 書き出した動画の上へ、置いた位置でもう一度重ねる(静止画は 1 回目で焼き込み済み)。
      final moving = [for (final l in p.layers) if (l is WidgetLayer && _motionPosts.containsKey(l.meta?['rasqPostVideo'])) l];
      if (moving.isNotEmpty) {
        if (p.isTransformed) {
          _notify('クロップ / 回転と、動くオブジェクトは一緒に使えません。静止画で入れました');
        } else {
          bytes = await _overlayOnVideo(bytes, moving) ?? bytes;
          if (!mounted) return;
        }
      }
      final n = widget.args.name;
      final dot = n.lastIndexOf('.');
      _finish(MediaEditResult(bytes: bytes, mimeType: 'video/mp4', name: '${dot > 0 ? n.substring(0, dot) : n}.mp4'));
    } catch (e) {
      // 失敗を黙って閉じない(変更が入らないまま戻ってしまう): 伝えて、加工画面に留まる。
      _renderFailed = true;
      _notify('動画を書き出せませんでした: $e');
    } finally {
      _renderProgress.value = null;
    }
  }

  /// 書き出した動画 + 動くオブジェクト (D-262)。失敗したら null(静止画のまま)。
  Future<Uint8List?> _overlayOnVideo(Uint8List rendered, List<WidgetLayer> layers) async {
    final editor = _imageEditor;
    if (editor == null) return null;
    final files = <File>[];
    try {
      final dir = await getTemporaryDirectory();
      final base = await videoEditTempFile(dir, 'overlay-base.mp4');
      await base.writeAsBytes(rendered);
      files.add(base);
      final meta = await pve.ProVideoEditor.instance.getMetadata(pve.EditorVideo.file(base.path));
      // `resolution` は向きを当てたあとの大きさ (pro_video_editor 1.6.0〜)。もう一度入れ替えない (D-420)。
      final size = meta.resolution;
      final out = await videoEditTempFile(dir, 'overlay-out.mp4');
      files.add(out);
      await overlayVideosOnVideo(base: base, canvas: size, length: meta.duration, posts: await _motionFiles(editor, layers, size, files), out: out);
      return await out.readAsBytes();
    } catch (e) {
      _notify('動くオブジェクトを重ねられなかったので、静止画で入れました: $e');
      return null;
    } finally {
      for (final f in files) {
        _deleteQuietly(f);
      }
    }
  }

  /// 動くオブジェクトの動画をファイルに出して、絵([size])の画素での枠と組にする。
  Future<List<OverlayVideo>> _motionFiles(ProImageEditorState editor, List<WidgetLayer> layers, ui.Size size, List<File> created) async {
    final dir = await getTemporaryDirectory();
    final posts = <OverlayVideo>[];
    for (final l in layers) {
      final m = _motionPosts[l.meta!['rasqPostVideo']]!;
      final f = await videoEditTempFile(dir, 'object-${posts.length}.${mediaContainerExt(m.video.length > 16 ? m.video.sublist(0, 16) : m.video) ?? 'mp4'}');
      await f.writeAsBytes(m.video, flush: true);
      created.add(f);
      // 枠は画面で測る(動画の加工)。測れなければ、レイヤーの数値から。
      final measured = _measureObject(l.meta!['rasqPostVideo'] as String, size);
      final set = _objectSettings[l.meta!['rasqObject']]?.value ?? const MediaObjectSettings();
      posts.add((
        video: f,
        rect: measured ?? postObjectRectInImage(image: size, shown: editor.sizesManager.decodedImageSize, offset: l.offset, width: m.width, aspect: m.aspect, scale: l.scale),
        loop: set.loop,
        speed: set.speed,
        volume: set.volume,
        opacity: set.opacity,
      ));
    }
    return posts;
  }

  static Rect? _screenRectOf(BuildContext? c) {
    if (c == null || !c.mounted) return null;
    final box = c.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return Rect.fromPoints(box.localToGlobal(Offset.zero), box.localToGlobal(box.size.bottomRight(Offset.zero)));
  }

  /// 動くオブジェクトの枠を、本体の動画の枠と比べて測る(絵 [size] の画素で)。測れなければ null。
  Rect? _measureObject(String id, ui.Size size) {
    final reference = _videoAreaContexts.map(_screenRectOf).whereType<Rect>().firstOrNull;
    final object = _screenRectOf((_objectContexts[id] ?? const []).where((c) => c.mounted).firstOrNull);
    if (reference == null || object == null) return null;
    final r = objectRectFromScreen(reference: reference, object: object, image: size);
    return r.isEmpty ? null : r;
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
    for (final id in _objectPlayerHolders.keys.toList()) {
      _disposeObjectPlayer(id);
    }
    for (final i in _postImages) {
      i.dispose();
    }
    super.dispose();
  }

  void _finish(MediaEditResult? result) {
    if (_closing || !mounted) return;
    _closing = true;
    for (final o in _objectPlayers.values) {
      o.player.value?.pause();
    }
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

  /// 開いた瞬間に掛けるカスタムフィルター(契約 v0.14 §2.2 temp、D-305): `auto`(利用者の上書き → 審査済みの宣言 → 既定 OFF)が
  /// オンのものを、画像の寸法が決まってから 1 回だけ掛ける(調整の FOW は開かない)。切り替えた値はこの加工画面限り。
  void _applyAutoFilters(ProImageEditorState editor, List<PluginAction> plugins) {
    if (_autoFiltersDone || _isVideo) return;
    final prefs = ref.read(actionButtonPrefsProvider);
    final auto = [for (final a in plugins) if (a.decl.isFilterOutput && a.effectiveAuto(prefs)) a];
    if (auto.isEmpty) {
      _autoFiltersDone = true;
      return;
    }
    final size = editor.sizesManager.originalImageSize ?? editor.sizesManager.decodedImageSize;
    if (size.width <= 0 || size.height <= 0) return; // まだ復号前: 次にバーを描くときにもう一度
    _autoFiltersDone = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (final a in auto) {
        if (!mounted) return;
        if (!_filters.containsKey(a.id)) await _toggleFilter(editor, a, openFow: false);
      }
    });
  }

  /// カスタムフィルターのボタン (D-255 → D-257): OFF → ON(`filter.preview` の描画リストをレイヤーとして重ねる。パラメーターが
  /// あれば調整の FOW も開く)。ON のとき: パラメーターがあれば FOW を開き直す(外すのは FOW の「外す」)、無ければ OFF。
  /// [openFow] = false は自動で掛けるとき(FOW を開かない)。
  Future<void> _toggleFilter(ProImageEditorState editor, PluginAction action, {bool openFow = true}) async {
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
    if (openFow && added.spec.value.params.isNotEmpty && mounted) await _openFilterFow(editor, added);
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
      var out = bytes;
      var mime = 'image/png';
      if (pixels.isNotEmpty && editor != null) {
        for (final f in pixels) {
          editor.removeLayer(f.layer);
        }
        out = await editor.captureEditorImage();
        if (!mounted) return;
        if (out.isEmpty) out = bytes;
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
      }
      // 動く投稿 (D-261) が置いてあれば、画像を土台にした動画にする。できなければ静止画のまま(投稿の静止画は焼き込み済み)。
      if (editor != null && _motionPosts.isNotEmpty) {
        final video = await _renderWithPostVideos(editor, out);
        if (!mounted) return;
        if (video != null) return _finish(video);
      }
      final n = _outName;
      _finish(MediaEditResult(bytes: out, mimeType: mime, name: mime == 'image/png' ? n : '${n.substring(0, n.lastIndexOf('.'))}.${mime == 'image/jpeg' ? 'jpg' : mime.split('/').last}'));
    } finally {
      _completing = false;
    }
  }

  /// 画像 + 動く投稿 → 動画 (D-261)。いま置いてあるレイヤーの位置 / 大きさから、絵の画素での枠を出して重ねる。
  Future<MediaEditResult?> _renderWithPostVideos(ProImageEditorState editor, Uint8List image) async {
    final layers = [for (final l in editor.activeLayers) if (l is WidgetLayer && _motionPosts.containsKey(l.meta?['rasqPostVideo'])) l];
    if (layers.isEmpty) return null; // 置いたあとで消した
    if (editor.stateManager.transformConfigs.isNotEmpty) {
      _notify('クロップ / 回転と、動く投稿は一緒に使えません。投稿は静止画で入れました');
      return null;
    }
    final files = <File>[];
    try {
      final decoded = await decodeUiImage(image);
      if (decoded == null) {
        _notify('動画にできなかったので、静止画で入れました(画像を読めませんでした)');
        return null;
      }
      final size = ui.Size(decoded.width.toDouble(), decoded.height.toDouble());
      decoded.dispose();
      final dir = await getTemporaryDirectory();
      final posts = await _motionFiles(editor, layers, size, files);
      final out = await buildImageWithPostVideos(imagePng: image, imageSize: size, posts: posts, workDir: dir);
      files.add(out);
      final bytes = await out.readAsBytes();
      final n = _outName;
      return MediaEditResult(bytes: bytes, mimeType: 'video/mp4', name: '${n.substring(0, n.lastIndexOf('.'))}.mp4');
    } catch (e) {
      _notify('動画にできなかったので、投稿は静止画で入れました: $e');
      return null;
    } finally {
      for (final f in files) {
        _deleteQuietly(f);
      }
    }
  }

  /// 「ノート」(D-260 → D-261): 「ノート画像の追加」FOW で投稿を選び、その投稿タイルを**オブジェクト(レイヤー)**として置く
  /// (動かす / 拡縮 / 回転 / 削除は pro_image_editor)。画像にも動画にも置ける。
  /// 画像の加工中に**動く / 鳴る投稿**を選ぶと「動画に変換しますか?」と尋ねる。はい → 置くのは静止画のまま、完了したときに
  /// 画像を土台にした動画へ書き出す(その位置で投稿が動く。回転はできない)。動画の加工中は静止画だけ。
  Future<void> _addPostObject(ProImageEditorState editor) async {
    final picked = await showPostImageFow(
      ref,
      id: 'media.pro.postImage',
      allowVideo: audioVideoSupported,
      // 動画の加工中は変換が要らないので、FOW の中のスイッチ(動画にする / 静止画)で選ぶ。
      confirmVideo: _isVideo ? null : (motion) => _confirmToVideo(postMotionNote(motion)),
    );
    if (picked == null || !mounted) return;
    final isVideo = picked.mimeType == 'video/mp4' && picked.still != null;
    await _addObject(editor, still: picked.still ?? picked.bytes, video: isVideo ? picked.bytes : null, meta: {'rasqPost': picked.post.key});
  }

  Future<bool> _confirmToVideo(String note) => _overlay.showAlert(
        id: 'media.pro.postVideo.confirm',
        title: '動画に変換しますか?',
        message: '$note\n「動画にする」と、置いた場所で動く動画として書き出します。「静止画で貼る」は今の画像だけを貼ります。',
        confirmText: '動画にする',
        cancelText: '静止画で貼る',
      );

  /// オブジェクト(レイヤー)を置く。[video] があれば「動くオブジェクト」: 置くのは静止画 [still] のまま、完了で動画を重ねる(回転は不可)。
  Future<void> _addObject(ProImageEditorState editor, {required Uint8List still, Uint8List? video, Map<String, Object?> meta = const {}}) async {
    // 復号してから置く(書き出しの瞬間に復号待ちで空にならないよう、RawImage で同期に描く)。
    final image = await decodeUiImage(still);
    if (image == null) return _notify('画像を読めませんでした');
    if (!mounted) return image.dispose();
    _postImages.add(image);
    final shown = editor.sizesManager.decodedImageSize;
    // 縦長は高さで抑える(絵の高さの 6 割まで)。
    final aspect = image.height / image.width;
    var width = (shown.width * 0.6).clamp(80.0, 480.0).toDouble();
    if (width * aspect > shown.height * 0.6) width = shown.height * 0.6 / aspect;
    final id = '${DateTime.now().microsecondsSinceEpoch}';
    if (video != null) _motionPosts[id] = (video: video, width: width, aspect: aspect);
    final settings = _objectSettings[id] = ValueNotifier(const MediaObjectSettings());
    settings.addListener(() => _applyObjectSettings(id));
    // 再生器は 1 つだけ作る(見た目の作り直しのたびに作ると、音が重なって、閉じても止まらない)。
    final player = video == null ? null : _startObjectPlayer(id, video);
    editor.addLayer(WidgetLayer(
      width: width,
      interaction: LayerInteraction(enableEdit: false, enableRotate: video == null),
      widget: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: image.width / image.height,
          child: ValueListenableBuilder<MediaObjectSettings>(
            valueListenable: settings,
            builder: (_, set, _) => Opacity(
              opacity: set.opacity,
              child: video == null
                  ? RawImage(image: image, fit: BoxFit.fill)
                  // 半透明のときは、書き出しの写しに静止画を入れない(下に焼き込むと、重ねた動画と二重に濃くなる)。
                  : _MotionObject(still: image, player: player!, live: _objectsLive, hideStillOnCapture: set.opacity < 1, mounted: _objectContexts.putIfAbsent(id, () => [])),
            ),
          ),
        ),
      ),
      meta: {...meta, 'rasqObject': id, if (video != null) 'rasqPostVideo': id},
    ));
    if (video != null && !_isVideo) _notify('完了すると、動画として書き出します');
  }

  /// 動くオブジェクトを、加工画面の中でも再生する (D-264)。繰り返し再生。画像の加工中は音も出す。動画の加工中は無音で、
  /// 本体の再生 / 一時停止に合わせる(音が重なるのを避ける。書き出しには入る)。用意できなければ静止画のまま。
  ValueNotifier<VideoPlayerController?> _startObjectPlayer(String id, Uint8List video) {
    final existing = _objectPlayerHolders[id];
    if (existing != null) return existing;
    final holder = _objectPlayerHolders[id] = ValueNotifier<VideoPlayerController?>(null);
    () async {
      File? file;
      try {
        file = await videoEditTempFile(await getTemporaryDirectory(), 'object-play.${mediaContainerExt(video.length > 16 ? video.sublist(0, 16) : video) ?? 'mp4'}');
        await file.writeAsBytes(video, flush: true);
        final c = VideoPlayerController.file(file);
        await c.initialize();
        // 用意している間に、画面が閉じた / オブジェクトが消された。
        if (!mounted || _objectPlayerHolders[id] != holder) {
          await c.dispose();
          return _deleteQuietly(file);
        }
        _objectPlayers[id] = (player: holder, file: file);
        holder.value = c;
        _applyObjectSettings(id);
        if (!_isVideo || _player?.value.isPlaying == true) await c.play();
      } catch (_) {
        if (file != null) _deleteQuietly(file);
      }
    }();
    return holder;
  }

  /// 設定を、加工画面の再生へ(不透明度は見た目の側が読む)。動画の加工中は、音は出さない(本体と重なる。書き出しには入る)。
  void _applyObjectSettings(String id) {
    final c = _objectPlayers[id]?.player.value;
    final set = _objectSettings[id]?.value;
    if (c == null || set == null) return;
    c.setLooping(set.loop);
    c.setPlaybackSpeed(set.speed);
    c.setVolume(_isVideo ? 0 : set.volume);
  }

  /// オブジェクトを押した (D-266): 再生していないときだけ、フッターから編集の FOW を出す。
  Future<void> _editObject(Layer layer) async {
    final id = layer.meta?['rasqObject'];
    final settings = _objectSettings[id];
    if (settings == null || _player?.value.isPlaying == true) return;
    final isVideo = _motionPosts.containsKey(id);
    final remove = await showMediaObjectFow(_overlay, title: layer.meta?['rasqPost'] != null ? 'ノート' : (isVideo ? '動画' : '画像'), isVideo: isVideo, settings: settings);
    if (remove != true || !mounted) return;
    final editor = _imageEditor;
    final current = editor?.activeLayers.where((l) => l.meta?['rasqObject'] == id).firstOrNull;
    if (editor != null && current != null) editor.removeLayer(current);
    _disposeObjectPlayer(id as String);
  }

  void _disposeObjectPlayer(String id) {
    final holder = _objectPlayerHolders.remove(id);
    final o = _objectPlayers.remove(id);
    final c = holder?.value ?? o?.player.value;
    holder?.value = null;
    c?.pause();
    c?.dispose();
    if (o != null) _deleteQuietly(o.file);
  }

  void _setObjectsPlaying(bool playing) {
    for (final o in _objectPlayers.values) {
      final c = o.player.value;
      if (c == null) continue;
      if (playing) {
        c.seekTo(Duration.zero);
        c.play();
      } else {
        c.pause();
      }
    }
  }

  /// 「メディア」(D-262): 端末の画像 / 動画を、オブジェクトとして置く。動画は最初のコマを置いて、完了で動画を重ねる。
  Future<void> _addMediaObject(ProImageEditorState editor, Rect anchor) async {
    final kind = !audioVideoSupported
        ? 'image'
        : await _overlay.showDropdown<String>(id: 'media.pro.addMedia', anchor: anchor, dense: true, items: const [RasqDropdownItem('画像を追加', 'image'), RasqDropdownItem('動画を追加', 'video')]);
    if (kind == null || !mounted) return;
    try {
      if (kind == 'image') {
        final f = await ImagePicker().pickImage(source: ImageSource.gallery);
        if (f == null || !mounted) return;
        return await _addObject(editor, still: await f.readAsBytes(), meta: const {'rasqMedia': 'image'});
      }
      final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (f == null || !mounted) return;
      final bytes = await f.readAsBytes();
      // 拡張子は中身から(ピッカーの名前に拡張子が無い / 違うことがある)。
      final ext = mediaContainerExt(bytes.length > 16 ? bytes.sublist(0, 16) : bytes) ?? 'mp4';
      final tmp = await videoEditTempFile(await getTemporaryDirectory(), 'object-pick.$ext');
      await tmp.writeAsBytes(bytes, flush: true);
      Uint8List? still;
      try {
        final frames = await pve.ProVideoEditor.instance.getThumbnails(pve.ThumbnailConfigs(video: pve.EditorVideo.file(tmp.path), outputSize: const Size(1280, 1280), timestamps: const [Duration.zero], boxFit: pve.ThumbnailBoxFit.contain, outputFormat: pve.ThumbnailFormat.png));
        if (frames.isNotEmpty) still = frames.first;
      } catch (e) {
        if (mounted) _notify(rasqDetail(context, '動画を読み込めませんでした', '動画(.$ext、${bytes.length} バイト)の最初のコマを取れませんでした: $e'));
        return;
      } finally {
        _deleteQuietly(tmp);
      }
      if (!mounted) return;
      if (still == null) return _notify('動画の最初のコマを取れませんでした');
      final asVideo = _isVideo || await _confirmToVideo('動画をオブジェクトとして置きます。');
      if (!mounted) return;
      await _addObject(editor, still: still, video: asVideo ? bytes : null, meta: const {'rasqMedia': 'video'});
    } catch (e) {
      _notify('メディアを追加できませんでした: $e');
    }
  }

  String get _configKey => editorConfigKeyFor(widget.args.mimeType, name: widget.args.name);

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
      case 'editor:media':
        final screen = MediaQuery.sizeOf(context);
        _addMediaObject(editor, Rect.fromLTWH(screen.width / 2 - 80, screen.height - 140, 160, 40));
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

  /// カスタムフィルターのボタンなら、長押しで temp のメニューを開く関数(ほかのボタンは null)。
  void Function(BuildContext ctx)? _filterTempMenu(List<PluginAction> plugins, String id) {
    final a = plugins.where((p) => p.id == id && p.decl.isFilterOutput).firstOrNull;
    if (a == null || _isVideo) return null;
    return (ctx) {
      final box = ctx.findRenderObject() as RenderBox;
      showActionTempMenu(ref, anchor: box.localToGlobal(Offset.zero) & box.size, action: a);
    };
  }

  Widget _bar(ProImageEditorState editor, Key key) {
    _imageEditor = editor;
    Widget extra(ProEditorExtraAction x, String label) => EditorActionBar.item('extra:${x.id}', label, Icon(x.icon, size: 22, color: RasqColors.accent), (_) => x.onTap(_ProEditorHandle(editor, context, _isVideo)),
        color: RasqColors.accent, onLongPress: x.onLongPress == null ? null : (_) => x.onLongPress!(_ProEditorHandle(editor, context, _isVideo)));
    final plugins = _pluginActions;
    _applyAutoFilters(editor, plugins);
    return EditorActionBar(
      key: key,
      configKey: _configKey,
      surface: _isVideo ? ActionBarSurface.editorVideo : ActionBarSurface.editorImage,
      // 「Visualizer」は音声を開いているときだけ(動画のバーの構成には常に居る)。
      builtins: [for (final a in editorBuiltinActionsFor(_configKey)) if (a.id != editorVisualizerActionId || _isAudio) a],
      plugins: plugins,
      controller: _barScroll,
      activeIds: _filters.keys.toSet(),
      leading: [
        for (final x in widget.args.extraActions)
          if (x.liveLabel case final live?) ValueListenableBuilder<String>(valueListenable: live, builder: (_, label, _) => extra(x, label)) else extra(x, x.label),
      ],
      onPerform: (a) => _perform(editor, a, plugins),
      // フィルターの長押し (契約 v0.14 temp): 「次からも自動でオン / オフ」。
      onLongPressFor: (id) => _filterTempMenu(plugins, id),
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
    final body = _buildEditor(context);
    if (!widget.args.avoidFows) return body;
    // D-413: FOW の大きさと位置に合わせて、エディターの面を FOW の逆サイドへ寄せる(全画面のメディア表示と同じ)。
    return ColoredBox(color: Colors.black, child: FowAvoidingBox(manager: _overlay, areaKey: proMediaEditorAreaKey, minFree: 200, child: body));
  }

  Widget _buildEditor(BuildContext context) {
    if (_isVideo) return _buildVideo(context);
    // バーの中身(プラグイン / 構成)の変化で作り直す。
    ref.watch(pluginActionsForProvider(_configKey));
    ref.watch(actionBarConfigProvider(_configKey));
    ref.watch(slotActionSettingsProvider('editor'));
    return _withPanel(ProImageEditor.memory(
      widget.args.bytes,
      key: _editorKey,
      callbacks: ProImageEditorCallbacks(
        mainEditorCallbacks: MainEditorCallbacks(onLayerTapUp: _editObject, onRemoveLayer: (l) => _objectPlayerHolders[l.meta?['rasqObject']]?.value?.pause()),
        onImageEditingStarted: () => _objectsLive.value = false,
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
                  // 変換の進み具合と、その間だけの広告の枠 (D-327)。
                  ? (_audioProgress == null
                      ? const CircularProgressIndicator()
                      : SingleChildScrollView(child: MediaExportProgress(progress: _audioProgress, label: '音声を動画に変換しています…', onDark: true, labelKey: proMediaEditorAudioNoteKey)))
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
        mainEditorCallbacks: MainEditorCallbacks(onLayerTapUp: _editObject, onRemoveLayer: (l) => _objectPlayerHolders[l.meta?['rasqObject']]?.value?.pause()),
        onImageEditingStarted: () => _objectsLive.value = false,
        onCompleteWithParameters: _renderVideo,
        onCloseEditor: (mode) {
          if (mode != EditorMode.main) return;
          if (_renderFailed) {
            _renderFailed = false;
            _objectsLive.value = true;
            return;
          }
          _finish(null);
        },
        videoEditorCallbacks: VideoEditorCallbacks(
          onPlay: () {
            _overlay.close(mediaObjectFowId);
            _player?.play();
            _setObjectsPlaying(true);
          },
          onPause: () {
            _player?.pause();
            _setObjectsPlaying(false);
          },
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

/// 動くオブジェクト (D-264): 下に静止画、上に再生中の動画。再生器が無い間 / 書き出しのために写す間は静止画だけ。
/// 画面に出ている間、自分の要素を [mounted] に載せる(書き出しのとき、画面上の枠を測るため。D-265)。
class _MotionObject extends StatefulWidget {
  const _MotionObject({required this.still, required this.player, required this.live, required this.mounted, this.hideStillOnCapture = false});
  final bool hideStillOnCapture;
  final ui.Image still;
  final ValueNotifier<VideoPlayerController?> player;
  final ValueNotifier<bool> live;
  final List<BuildContext> mounted;

  @override
  State<_MotionObject> createState() => _MotionObjectState();
}

class _MotionObjectState extends State<_MotionObject> {
  @override
  void initState() {
    super.initState();
    widget.mounted.add(context);
  }

  @override
  void dispose() {
    widget.mounted.remove(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        ValueListenableBuilder<bool>(valueListenable: widget.live, builder: (_, on, _) => !on && widget.hideStillOnCapture ? const SizedBox.shrink() : RawImage(image: widget.still, fit: BoxFit.fill)),
        ValueListenableBuilder<bool>(
          valueListenable: widget.live,
          builder: (_, on, _) => !on
              ? const SizedBox.shrink()
              : ValueListenableBuilder<VideoPlayerController?>(
                  valueListenable: widget.player,
                  builder: (_, c, _) => c == null ? const SizedBox.shrink() : FittedBox(fit: BoxFit.fill, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))),
                ),
        ),
      ]);
}

/// 画面に出ている間、自分の要素を [mounted] に載せる(画面上の枠を測るため。GlobalKey と違って、同じものが複数の場所に出てもよい)。
class _Registered extends StatefulWidget {
  const _Registered({required this.mounted, required this.child});
  final List<BuildContext> mounted;
  final Widget child;

  @override
  State<_Registered> createState() => _RegisteredState();
}

class _RegisteredState extends State<_Registered> {
  @override
  void initState() {
    super.initState();
    widget.mounted.add(context);
  }

  @override
  void dispose() {
    widget.mounted.remove(context);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
