import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../backend/orgate_client.dart' show OrgateException;
import '../../app/navigation.dart';
import '../../app/providers.dart' show overlayManagerProvider;
import '../../app/router.dart';
import '../../backend/rasq_collections_api.dart';
import '../../shell/headers.dart';
import '../collections/rasq_collections.dart';
import '../compose/media_file_pick.dart' show mediaVideoExtensions, mediaMimeFor;
import '../custom/custom_plugins_screen.dart' show installedPagePluginsProvider;
import '../plugins/media_plugin_panel.dart' show MediaEditResult;
import '../plugins/pro_media_editor_screen.dart' show ProEditorExtraAction, ProEditorHandle;
import '../plugins/slot_plugins.dart';
import '../store/rasqpkg.dart' show isRasqPackage, rasqpkgZstdProvider;
import 'swing_models.dart';
import 'swing_providers.dart';
import 'wagara.dart';

/// Swing を作る (D-377 / D-380 → D-386)。
///
/// D-386: 始め方を選ぶ一覧は無くし、**開くとすぐ和柄の背景**([wagara.dart]: 柄 2 つを乱数で選び、1 枚目 + 柄 A でマスクした
/// 2 枚目の紋様)で**全画面の編集画面**(投稿の添付と同じ pro_image_editor)に入る。画像 / 動画 / テキストは編集画面の
/// 「メディア」「テキスト」で**あとから足す**。下のバーの先頭には「**プラグイン**」(配るプラグインを選ぶ画面へ)と
/// 「背景を変える」(押すと別の柄、長押しで画像 / 動画を背景に、D-387)を自動で足す。できあがったものを送る画面([SwingComposerScreen]: 届け先と時間)へ。
/// プラグインは、入っている Swing 対応のもの / ファイルから(未審査)を選ぶ。ホームの ＋ から入る。
/// D-395: 送る画面で **CW(注意書き)** と「**センシティブな内容**」を付けられる(見る人の端末では覆ってから出し、
/// 隣に広告を置かない)。
///
/// D-410: 2 つの段に分けた。
/// - **編集の段**: 画像 / 動画 / テキストは編集画面(バーに「N 時間で消える」= 消えるまでの時間を足した)、プラグインは
///   この画面の「配るプラグイン」と「消えるまで」。
/// - **送る前の段**: プレビューの枠の**右下に CW のオン / オフ**、その**左に CW の文**(既定「センシティブな内容」)。
///   オンなら `sensitive: true` と `cw: 文`、オフならどちらも送らない。枠の**下に届け先の FOW**(フォロワーと自分の
///   RASQ リストのタイル、1 つ以上)。送るボタンはヘッダーの右。

const swingImageExtensions = ['png', 'jpg', 'jpeg', 'gif', 'webp', 'heic'];
const _imageMime = {'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'gif': 'image/gif', 'webp': 'image/webp', 'heic': 'image/heic'};

/// 画像 / 動画のファイル名 → MIME(分からなければ null)。
String? swingMediaMimeFor(String name, {String? reported}) {
  if (reported != null && (reported.startsWith('image/') || reported.startsWith('video/'))) return reported;
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  final v = mediaMimeFor(name);
  return _imageMime[ext] ?? (v != null && v.startsWith('video/') ? v : null);
}

/// 選択ダイアログ(テストで差し替える)。[video] = 動画を選ぶ。
final swingMediaPickerProvider = Provider<Future<XFile?> Function({required bool video})>((ref) => ({required bool video}) => openFile(acceptedTypeGroups: [
      video
          ? const XTypeGroup(label: '動画', extensions: mediaVideoExtensions, mimeTypes: ['video/*'], uniformTypeIdentifiers: ['public.movie'])
          : const XTypeGroup(label: '画像', extensions: swingImageExtensions, mimeTypes: ['image/*'], uniformTypeIdentifiers: ['public.image']),
    ]));

/// 未審査のプラグインの入れ物を選ぶ(テストで差し替える)。
final swingPackagePickerProvider = Provider<Future<XFile?> Function()>((ref) => () => openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'プラグイン', extensions: ['rasqpkg', 'wasm']),
    ]));

/// Swing に使えるプラグイン: 入っているページ型で、surface `swing` を宣言しているもの(solo)。
final swingPluginsProvider = Provider<List<SlotPlugin>>((ref) => [
      for (final p in ref.watch(installedPagePluginsProvider))
        if (p.manifest.page?.allows(PluginPageDecl.surfaceSwing) ?? false) p,
    ]);

/// 送る画面に渡す下書き: 編集し終えた画像 / 動画、またはプラグインを選ぶところから。
@immutable
class SwingDraft {
  const SwingDraft.media({required Uint8List this.bytes, required String this.mime, required String this.name, this.ttlHours = 24})
      : plugin = false;
  const SwingDraft.plugin({this.ttlHours = 24})
      : bytes = null,
        mime = null,
        name = null,
        plugin = true;
  final Uint8List? bytes;
  final String? mime;
  final String? name;
  final bool plugin;

  /// 消えるまでの時間 (D-410: 編集の段で選ぶ)。
  final int ttlHours;

  SwingKind get kind => plugin ? SwingKind.plugin : (mime!.startsWith('video/') ? SwingKind.video : SwingKind.image);
}

/// 全画面の編集画面(テストで差し替える)。閉じたら null。[actions] = 下のバーの先頭に足すボタン。
typedef SwingEditor = Future<MediaEditResult?> Function(BuildContext context, {required Uint8List bytes, required String name, required String mime, List<ProEditorExtraAction> actions});

final swingEditorProvider = Provider<SwingEditor>(
    (ref) => (context, {required bytes, required name, required mime, actions = const []}) => context.pushProMediaEditor(bytes: bytes, name: name, mimeType: mime, extraActions: actions));

/// 背景 (D-386): 和柄 2 つを乱数で選んで描いた縦長の PNG。テストで差し替える。
final swingBackgroundProvider = Provider<Future<Uint8List> Function()>((ref) => () => renderSwingBackground(SwingBackgroundSpec.random(math.Random())));

/// 編集画面の下のバーに足すボタンの id(キーは `media.pro.bar.extra:<id>`)。
const swingPluginActionId = 'swing.plugin';
const swingBackgroundActionId = 'swing.background';
const swingTtlActionId = 'swing.ttl';

/// 消えるまでの時間の選び方 (D-410)。
const swingTtlChoices = [1, 6, 12, 24];

String swingTtlLabel(int hours) => '$hours 時間で消える';

/// 編集画面の「N 時間で消える」(D-410): 押すと時間を選ぶシート。[ttl] を書き換える。
ProEditorExtraAction swingTtlAction(ValueNotifier<int> ttl) {
  final label = ValueNotifier(swingTtlLabel(ttl.value));
  ttl.addListener(() => label.value = swingTtlLabel(ttl.value));
  return ProEditorExtraAction(
    id: swingTtlActionId,
    label: label.value,
    liveLabel: label,
    icon: Icons.timer_outlined,
    onTap: (h) => pickSwingTtl(h.context, ttl),
  );
}

/// 消えるまでの時間を選ぶシート。
Future<void> pickSwingTtl(BuildContext context, ValueNotifier<int> ttl) async {
  final picked = await showModalBottomSheet<int>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: Text('消えるまで', style: RasqTypography.bodySmall)),
        for (final h in swingTtlChoices)
          ListTile(
            key: ValueKey('swing.ttl.$h'),
            leading: const Icon(Icons.timer_outlined),
            title: Text('$h 時間'),
            trailing: ttl.value == h ? const Icon(Icons.check) : null,
            onTap: () => Navigator.of(ctx).pop(h),
          ),
      ]),
    ),
  );
  if (picked != null) ttl.value = picked;
}

/// 長押しで選ぶ背景の画像 / 動画のシートの key。
const swingPickImageKey = ValueKey('swing.background.image');
const swingPickVideoKey = ValueKey('swing.background.video');

/// 始める: 和柄の背景で編集画面へ → 送る画面。「プラグイン」を押したら、配るプラグインを選ぶ送る画面へ。
/// 「背景を変える」(D-387): 押すと別の和柄、**長押しで画像 / 動画を選んで背景に**。画像は編集画面のまま差し替え、動画
/// (や、動画を開いているときの和柄)は編集画面を開き直す(それまでの編集は捨てる)。
/// [replace] = いまの画面(開いたばかりの送る画面)を置き換える。編集画面を閉じたら、その画面も閉じる。
Future<void> startSwing(BuildContext context, WidgetRef ref, {bool replace = false}) async {
  // 消えるまで (D-410): 編集画面のバーで選ぶ。開き直しても引き継ぐ。
  final ttl = ValueNotifier(24);
  void open(SwingDraft d) => replace ? context.pushReplacement(Routes.swingNew, extra: d) : context.push(Routes.swingNew, extra: d);
  final background = ref.read(swingBackgroundProvider);
  final picker = ref.read(swingMediaPickerProvider);
  var base = (bytes: await background(), name: 'swing.png', mime: 'image/png');
  while (true) {
    if (!context.mounted) return;
    var plugin = false;
    ({Uint8List bytes, String name, String mime})? next;

    /// 選んだ画像 / 動画を背景に。
    Future<void> pickBase(ProEditorHandle h) async {
      final video = await showModalBottomSheet<bool>(
        context: h.context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(key: swingPickImageKey, leading: const Icon(Icons.image_outlined), title: const Text('画像を背景にする'), onTap: () => Navigator.of(ctx).pop(false)),
            ListTile(key: swingPickVideoKey, leading: const Icon(Icons.movie_outlined), title: const Text('動画を背景にする'), onTap: () => Navigator.of(ctx).pop(true)),
          ]),
        ),
      );
      if (video == null) return;
      final f = await picker(video: video);
      if (f == null) return;
      final mime = swingMediaMimeFor(f.name, reported: f.mimeType);
      if (mime == null || !mime.startsWith(video ? 'video/' : 'image/')) {
        if (h.context.mounted) ScaffoldMessenger.maybeOf(h.context)?.showSnackBar(SnackBar(content: Text(video ? '動画のファイルを選んでください' : '画像のファイルを選んでください')));
        return;
      }
      final bytes = await f.readAsBytes();
      if (!video && !h.isVideo) return h.setBackground(bytes);
      next = (bytes: bytes, name: f.name, mime: mime);
      h.close();
    }

    final edited = await ref.read(swingEditorProvider)(context, bytes: base.bytes, name: base.name, mime: base.mime, actions: [
      ProEditorExtraAction(
        id: swingPluginActionId,
        label: 'プラグイン',
        icon: Icons.extension_outlined,
        onTap: (h) {
          plugin = true;
          h.close();
        },
      ),
      ProEditorExtraAction(
        id: swingBackgroundActionId,
        label: '背景を変える',
        icon: Icons.shuffle,
        onTap: (h) async {
          final bytes = await background();
          if (!h.isVideo) return h.setBackground(bytes);
          next = (bytes: bytes, name: 'swing.png', mime: 'image/png');
          h.close();
        },
        onLongPress: pickBase,
      ),
      swingTtlAction(ttl),
    ]);
    if (!context.mounted) return;
    if (plugin) return open(SwingDraft.plugin(ttlHours: ttl.value));
    final n = next;
    if (n != null) {
      base = n;
      continue;
    }
    if (edited == null) {
      if (replace) context.pop();
      return;
    }
    return open(SwingDraft.media(bytes: edited.bytes, mime: edited.mimeType, name: edited.name ?? base.name, ttlHours: ttl.value));
  }
}

/// 届け先の FOW の id (D-410)。
const swingAudienceFowId = 'swing.audience';

/// CW の文の既定 (D-410)。
const swingDefaultCw = 'センシティブな内容';

/// 届け先の選び方 (D-410): フォロワーと RASQ リスト。送る画面と届け先の FOW で分け合う。
class SwingAudienceSelection extends ChangeNotifier {
  bool _followers = true;
  final _lists = <String>{};

  bool get followers => _followers;
  Set<String> get lists => Set.unmodifiable(_lists);
  bool get isEmpty => !_followers && _lists.isEmpty;

  set followers(bool v) {
    if (v == _followers) return;
    _followers = v;
    notifyListeners();
  }

  void setList(String id, bool on) {
    if (on ? _lists.add(id) : _lists.remove(id)) notifyListeners();
  }

  SwingAudience toAudience() => SwingAudience(followers: _followers, lists: _lists.toList());
}

class SwingComposerScreen extends ConsumerStatefulWidget {
  const SwingComposerScreen({super.key, this.draft});

  /// null = 開いたらすぐ和柄の背景で編集画面へ([startSwing])。
  final SwingDraft? draft;

  static const ttlChoices = swingTtlChoices;

  /// CW の上限(文字、Central S-060 と同じ)。
  static const maxCwChars = 100;

  @override
  ConsumerState<SwingComposerScreen> createState() => _SwingComposerScreenState();
}

class _SwingComposerScreenState extends ConsumerState<SwingComposerScreen> {
  late SwingDraft? _draft = widget.draft;
  String? _pluginId;

  /// 編集の段 (D-410)。画像 / 動画は編集画面が編集の段なので、ここは送る前の段から。プラグインは選ぶところから。
  late bool _editing = widget.draft?.plugin ?? false;

  /// 未審査のプラグイン (D-379): ファイルから読んだ入れ物(確かめ済み)。
  ({String name, Uint8List bytes, String id, String version, String title})? _package;
  final _audience = SwingAudienceSelection();
  late final _ttl = ValueNotifier(widget.draft?.ttlHours ?? 24);
  bool _busy = false;
  String? _error;

  /// CW (D-395 → D-410): 枠の右下のオン / オフと、その左の文。
  final _cw = TextEditingController(text: swingDefaultCw);
  bool _cwOn = false;

  /// プレビューの枠(届け先の FOW をこの下に付ける)。
  final _frameKey = GlobalKey();
  OverlayManager? _manager;
  FowSpec? _fowSpec;

  /// 出し終えて閉じるところ(届け先の FOW を付け直さない)。
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _audience.addListener(_onAudience);
    _ttl.addListener(_onAudience);
    if (widget.draft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(swingApiProvider) != null) startSwing(context, ref, replace: true);
      });
    }
  }

  void _onAudience() {
    if (mounted) setState(() {});
  }

  bool get _cwTooLong => _cwOn && _cw.text.trim().characters.length > SwingComposerScreen.maxCwChars;

  @override
  void dispose() {
    // 外すのは木を組み直している最中なので、FOW を閉じるのはこのフレームのあと(中身が使う選び方もそのあとで捨てる)。
    final manager = _manager;
    final audience = _audience;
    _fowSpec = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (manager != null && !manager.disposed && manager.contains(swingAudienceFowId)) manager.close(swingAudienceFowId);
      audience.dispose();
    });
    _ttl.dispose();
    _cw.dispose();
    super.dispose();
  }

  bool get _hasContent {
    final d = _draft;
    if (d == null) return false;
    return d.plugin ? (_pluginId != null || _package != null) : d.bytes != null;
  }

  bool get _ready => _hasContent && !_editing && !_audience.isEmpty && !_cwTooLong;

  /// 届け先の FOW (D-410): プレビューの枠の**下**に付ける(widget の FOW なので、後ろの枠も触れる)。
  void _syncAudienceFow() {
    if (!mounted) return;
    final show = !_leaving && !_editing && _draft != null && ref.read(swingApiProvider) != null;
    if (!show) return _closeAudienceFow();
    final box = _frameKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final manager = ref.read(overlayManagerProvider);
    _manager = manager;
    final spec = _fowSpec;
    if (spec != null && manager.contains(swingAudienceFowId)) {
      if (spec.anchor != rect) {
        spec.anchor = rect;
        manager.requestRebuild();
      }
      return;
    }
    final next = _fowSpec = FowSpec(
      type: FowPanelType.widget,
      title: '届け先',
      anchor: rect,
      anchorBelow: true,
      maxWidth: rect.width,
      resizable: false,
      showHandle: false,
      initialHeightFactor: 0.9,
      minHeightFactor: 0.05,
      maxHeightFactor: 0.9,
    );
    unawaited(manager.showFow<void>(
      id: swingAudienceFowId,
      spec: next,
      semanticsLabel: '届け先',
      builder: (ctx, handle) => SwingAudienceFowBody(selection: _audience),
    ).whenComplete(() {
      if (identical(_fowSpec, next)) _fowSpec = null;
    }));
  }

  void _closeAudienceFow() {
    final manager = _manager;
    _fowSpec = null;
    if (manager != null && manager.contains(swingAudienceFowId)) manager.close(swingAudienceFowId);
  }

  /// 編集し直す(同じ絵 / 動画で編集画面を開き直す。消えるまでの時間もそこで選び直せる)。
  Future<void> _reedit() async {
    final d = _draft;
    if (d == null || d.plugin) return;
    // 編集画面はページなので、FOW が上に重ならないよう閉じておく(戻ったら付け直す)。
    _closeAudienceFow();
    final edited = await ref.read(swingEditorProvider)(context, bytes: d.bytes!, name: d.name!, mime: d.mime!, actions: [swingTtlAction(_ttl)]);
    if (!mounted) return;
    if (edited != null) setState(() => _draft = SwingDraft.media(bytes: edited.bytes, mime: edited.mimeType, name: edited.name ?? d.name!, ttlHours: _ttl.value));
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncAudienceFow());
  }

  void _setEditing(bool v) {
    setState(() => _editing = v);
    if (v) _closeAudienceFow();
  }

  /// 入れ物を選んで、Swing で配れるか確かめる(子プラグイン無しの 1 つ、Swing の面のページ型)。一度動かして宣言を読む。
  Future<void> _pickPackage() async {
    final f = await ref.read(swingPackagePickerProvider)();
    if (f == null) return;
    final bytes = await f.readAsBytes();
    final slots = ref.read(slotPluginsProvider.notifier);
    SlotPlugin? p;
    try {
      checkSwingPackage(bytes, decompress: ref.read(rasqpkgZstdProvider));
      p = await slots.register('${swingSlotSourcePrefix}preview', bytes: bytes, persist: false, temporary: true);
      if (p == null) throw StateError(ref.read(slotPluginsNoticeProvider) ?? '読み込めませんでした');
      setState(() {
        _package = (name: f.name, bytes: bytes, id: p!.manifest.id, version: p.manifest.version, title: p.manifest.page?.title ?? p.manifest.name);
        _pluginId = null;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = e is StateError ? e.message : '$e');
    } finally {
      if (p != null) slots.disposeTemporary(p);
    }
  }

  Future<void> _send() async {
    final api = ref.read(swingApiProvider);
    final d = _draft;
    if (api == null || d == null || !_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final mediaId = d.plugin ? null : await api.uploadMedia(d.bytes!, contentType: d.mime!);
      final plugin = _pluginId == null ? null : ref.read(swingPluginsProvider).where((p) => (p.storePluginId ?? p.id) == _pluginId).firstOrNull;
      final pkg = d.plugin ? _package : null;
      final packageId = pkg == null ? null : await api.uploadMedia(pkg.bytes, contentType: isRasqPackage(pkg.bytes) ? 'application/vnd.rasq.pkg' : 'application/wasm');
      final cw = _cw.text.trim();
      final ttl = _ttl.value;
      await api.create(NewSwing(
        kind: d.kind,
        mediaId: mediaId,
        plugin: pkg != null
            ? SwingPlugin(id: pkg.id, version: pkg.version, packageId: packageId)
            : d.plugin && _pluginId != null
                ? SwingPlugin(id: _pluginId!, version: plugin?.storeVersion)
                : null,
        audience: _audience.toAudience(),
        ttlHours: ttl,
        // D-410: オンなら センシティブ + CW の文、オフならどちらも送らない。
        cw: _cwOn && cw.isNotEmpty ? cw : null,
        sensitive: _cwOn,
      ));
      ref.invalidate(mySwingsProvider);
      if (!mounted) return;
      _leaving = true;
      _closeAudienceFow();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Swing を出しました($ttl 時間で消えます)')));
      context.pop();
    } on OrgateException catch (e) {
      setState(() => _error = e.message.contains('swing_limit') || e.toString().contains('429') ? '同時に出しておける Swing は 20 個までです' : '出せませんでした: ${e.message}');
    } catch (e) {
      setState(() => _error = '出せませんでした: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasApi = ref.watch(swingApiProvider) != null;
    final d = _draft;
    final ready = hasApi && d != null;
    // 枠が動いたら FOW も付け直す(描き終えてから)。
    if (ready && !_editing) WidgetsBinding.instance.addPostFrameCallback((_) => _syncAudienceFow());
    final error = _error == null
        ? null
        : Padding(
            key: const ValueKey('swing.error'),
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: Text(_error!, style: RasqTypography.caption.copyWith(color: scheme.error)),
          );
    return Scaffold(
      appBar: RasqPageHeader(
        title: 'Swing を作る',
        showMore: false,
        // プラグインの送る前の段から戻る = 選ぶ段へ。
        onBack: ready && d.plugin && !_editing ? () => _setEditing(true) : null,
        actions: [
          if (ready)
            Padding(
              padding: const EdgeInsets.only(right: RasqSpacing.sm),
              child: _editing
                  ? FilledButton(key: const ValueKey('swing.next'), onPressed: _hasContent ? () => _setEditing(false) : null, child: const Text('次へ'))
                  : FilledButton(
                      key: const ValueKey('swing.send'),
                      onPressed: _ready && !_busy ? _send : null,
                      child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('出す'),
                    ),
            ),
        ],
      ),
      body: !hasApi
          ? const RasqEmptyView(key: ValueKey('swing.composer.noAccount'), title: 'RASQ アカウントが要ります', hint: 'Swing は RASQ アカウントから出します。サイドバーからログインしてください')
          : d == null
              ? const RasqLoading(key: ValueKey('swing.composer.starting'))
              : _editing
                  ? ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xxl), children: [
                      ..._pluginSection(),
                      ..._ttlSection(),
                      ?error,
                    ])
                  : LayoutBuilder(
                      builder: (_, box) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        ?error,
                        Padding(
                          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
                          // 下に届け先の FOW を付けるので、枠は高さの半分ほど。
                          child: SizedBox(height: (box.maxHeight * 0.52).clamp(200.0, 460.0), child: _previewFrame(d)),
                        ),
                      ]),
                    ),
    );
  }

  /// 送る前の段のプレビューの枠 (D-410): 中身、右上に編集し直す / 選び直すと消えるまで、下に CW の文 + オン / オフ。
  Widget _previewFrame(SwingDraft d) {
    final video = d.kind == SwingKind.video;
    final Widget content;
    if (d.plugin) {
      final plugin = _pluginId == null ? null : ref.watch(swingPluginsProvider).where((p) => (p.storePluginId ?? p.id) == _pluginId).firstOrNull;
      final title = _package != null ? '${_package!.title}(未審査)' : (plugin?.manifest.page?.title ?? plugin?.manifest.name ?? 'プラグイン');
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.extension_outlined, color: Colors.white70, size: 40),
        const SizedBox(height: RasqSpacing.xs),
        Text(title, key: const ValueKey('swing.preview.plugin'), style: RasqTypography.body.copyWith(color: Colors.white)),
        Text('見る人の端末で全画面で動きます', style: RasqTypography.caption.copyWith(color: Colors.white70)),
      ]);
    } else if (video) {
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.movie_outlined, color: Colors.white70, size: 40),
        Text(d.name ?? '動画', style: RasqTypography.caption.copyWith(color: Colors.white70)),
      ]);
    } else {
      content = Image.memory(d.bytes!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: Colors.white70, size: 40));
    }
    return ClipRRect(
      key: _frameKey,
      borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
      child: ColoredBox(
        key: const ValueKey('swing.preview'),
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [
          Center(child: content),
          // 右上: 消えるまで(編集の段で選んだもの)と、編集し直す / 選び直す。
          Positioned(
            top: RasqSpacing.xs,
            right: RasqSpacing.xs,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${_ttl.value} 時間で消えます', key: const ValueKey('swing.ttl.label'), style: RasqTypography.caption.copyWith(color: Colors.white70)),
              d.plugin
                  ? RasqIconButton(key: const ValueKey('swing.plugin.change'), icon: Icons.edit_outlined, tooltip: '選び直す', color: Colors.white, onPressed: _busy ? null : () => _setEditing(true))
                  : RasqIconButton(key: const ValueKey('swing.reedit'), icon: Icons.edit_outlined, tooltip: '編集し直す', color: Colors.white, onPressed: _busy ? null : _reedit),
            ]),
          ),
          // 下: CW の文(左)+ オン / オフ(右下)。
          Positioned(left: 0, right: 0, bottom: 0, child: _cwBar()),
        ]),
      ),
    );
  }

  /// CW (D-410): 右下のスイッチがオンなら、左の文を CW にしてセンシティブとして出す。
  Widget _cwBar() => DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.lg, RasqSpacing.xs, RasqSpacing.xs),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_cwTooLong)
              Padding(
                key: const ValueKey('swing.cw.tooLong'),
                padding: const EdgeInsets.only(bottom: RasqSpacing.xs),
                child: Text('CW は ${SwingComposerScreen.maxCwChars} 文字までです', style: RasqTypography.caption.copyWith(color: RasqColors.salmon)),
              ),
            Row(children: [
              Expanded(
                child: SizedBox(
                  key: const ValueKey('swing.cw'),
                  child: TextField(
                    controller: _cw,
                    enabled: !_busy,
                    onChanged: (_) => setState(() {}),
                    style: RasqTypography.bodySmall.copyWith(color: _cwOn ? Colors.white : Colors.white60),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.12),
                      hintText: 'CW の文',
                      hintStyle: RasqTypography.bodySmall.copyWith(color: Colors.white38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.xs),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RasqSpacing.xs),
              Tooltip(
                message: _cwOn ? 'CW をはずす' : 'CW を付ける(センシティブな内容)',
                child: Semantics(
                  label: 'CW',
                  child: Switch(key: const ValueKey('swing.cw.toggle'), value: _cwOn, onChanged: _busy ? null : (v) => setState(() => _cwOn = v)),
                ),
              ),
            ]),
          ]),
        ),
      );

  List<Widget> _pluginSection() {
    final plugins = ref.watch(swingPluginsProvider);
    return [
      const RasqSectionHeader(title: '配るプラグイン'),
      if (plugins.isEmpty)
        const RasqNotice(key: ValueKey('swing.plugin.none'), text: 'Swing に対応したプラグインが入っていません。ストアで入れるか、下の「ファイルから」で自分のプラグインを配れます。', detail: 'ページ型(カスタムプラグイン)のうち、manifest.page.surfaces に swing を書いた solo のもの(契約 v0.19)。'),
      for (final p in plugins)
        RasqRadioListTile<String>(
          key: ValueKey('swing.plugin.${p.storePluginId ?? p.id}'),
          title: p.manifest.page?.title ?? p.manifest.name,
          subtitle: '見る人の端末で全画面で動きます',
          value: p.storePluginId ?? p.id,
          groupValue: _pluginId,
          onChanged: (v) => setState(() {
            _pluginId = v;
            _package = null;
          }),
        ),
      // 未審査のまま配る (D-379)。見る人の端末では制限モード(通信なし、GPU は可)。
      RasqListTile(
        key: const ValueKey('swing.plugin.file'),
        title: _package == null ? 'ファイルから(未審査)' : '${_package!.title}(未審査)',
        subtitle: _package == null ? '自分で作った .rasqpkg / .wasm を配ります' : _package!.name,
        detail: '審査していないプラグインは、見る人の端末で通信できない状態で動きます(GPU は使えます)。ほかのプラグインを土台にする子プラグインは配れません。',
        leading: Icon(_package == null ? Icons.file_open_outlined : Icons.check_circle_outline),
        onTap: _busy ? null : _pickPackage,
      ),
    ];
  }

  /// 消えるまで (D-410: 編集の段。プラグインはここ、画像 / 動画は編集画面のバー)。
  List<Widget> _ttlSection() => [
        const RasqSectionHeader(title: '消えるまで'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, children: [
            for (final h in swingTtlChoices)
              ChoiceChip(key: ValueKey('swing.ttl.$h'), label: Text('$h 時間'), selected: _ttl.value == h, onSelected: (_) => _ttl.value = h),
          ]),
        ),
      ];
}

/// 届け先の FOW の中身 (D-410): フォロワーと自分の RASQ リストのタイル(オン / オフ)。1 つ以上。
class SwingAudienceFowBody extends ConsumerWidget {
  const SwingAudienceFowBody({super.key, required this.selection});
  final SwingAudienceSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(myRasqCollectionsProvider(RasqCollectionKind.list)).value ?? const <RasqCollection>[];
    return ListenableBuilder(
      listenable: selection,
      builder: (context, _) => ListView(key: const ValueKey('swing.audience'), padding: EdgeInsets.zero, children: [
        if (selection.isEmpty) const RasqNotice.warning(key: ValueKey('swing.audience.empty'), text: '届け先を 1 つ以上選んでください'),
        RasqSwitchListTile(
          key: const ValueKey('swing.audience.followers'),
          leading: const Icon(Icons.people_outline),
          title: 'フォロワー',
          subtitle: 'RASQ アカウントをフォローしている人',
          value: selection.followers,
          onChanged: (v) => selection.followers = v,
        ),
        for (final l in lists)
          RasqSwitchListTile(
            key: ValueKey('swing.audience.list.${l.id}'),
            leading: const Icon(Icons.list_alt_outlined),
            title: l.name,
            subtitle: 'RASQ リスト',
            value: selection.lists.contains(l.id),
            onChanged: (v) => selection.setList(l.id, v),
          ),
        if (lists.isEmpty) const RasqCaption('RASQ リストを作ると、リストに入れた人にも届けられます', padding: EdgeInsets.all(RasqSpacing.page)),
      ]),
    );
  }
}
