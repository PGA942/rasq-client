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
import '../../app/providers.dart' show overlayManagerProvider;
import '../../app/router.dart';
import '../../backend/rasq_collections_api.dart';
import '../../shell/column_takeover.dart';
import '../../shell/headers.dart';
import '../collections/rasq_collections.dart';
import '../compose/media_file_pick.dart' show mediaVideoExtensions, mediaMimeFor;
import '../custom/custom_plugins_screen.dart' show installedPagePluginsProvider;
import '../plugins/media_plugin_panel.dart' show MediaEditResult;
import '../media/fow_avoid.dart';
import '../plugins/pro_media_editor_screen.dart' show ProEditorExtraAction, ProEditorHandle, ProMediaEditorArgs, ProMediaEditorScreen;
import '../plugins/slot_plugins.dart';
import '../store/rasqpkg.dart' show isRasqPackage, rasqpkgZstdProvider;
import '../store/store_providers.dart' show installedPluginsProvider;
import 'swing_models.dart';
import 'swing_providers.dart';
import 'wagara.dart';
import '../../l10n/l10n.dart';

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
          ? XTypeGroup(label: appL10n.swingKindVideo, extensions: mediaVideoExtensions, mimeTypes: ['video/*'], uniformTypeIdentifiers: ['public.movie'])
          : XTypeGroup(label: appL10n.swingKindImage, extensions: swingImageExtensions, mimeTypes: ['image/*'], uniformTypeIdentifiers: ['public.image']),
    ]));

/// 未審査のプラグインの入れ物を選ぶ(テストで差し替える)。
final swingPackagePickerProvider = Provider<Future<XFile?> Function()>((ref) => () => openFile(acceptedTypeGroups: [
      XTypeGroup(label: appL10n.swingKindPlugin, extensions: ['rspkg', 'rasqpkg', 'wasm']), // .rspkg = SDK の既定の拡張子(中身は .rasqpkg と同じ)
    ]));

/// Swing に使えるプラグイン (D-424、契約 v0.20): 入っているページ型(カスタムプラグイン)のうち、**親子関係の無い**もの
/// ([pageSwingBlockReason])。solo も shared も(shared は見る人が作った人のセッションに入る)。surface `swing` を宣言した
/// もの(Swing 向けに作ったもの)を先に並べる。前 (v0.19) は `swing` を宣言した solo だけだった(「みんなのボード」が出なかった)。
final swingPluginsProvider = Provider<List<SlotPlugin>>((ref) {
  final all = ref.watch(slotPluginsProvider);
  final installed = {for (final r in ref.watch(installedPluginsProvider)) r.id: r};
  final ok = [
    for (final p in ref.watch(installedPagePluginsProvider))
      if (pageSwingBlockReason(p, all, requires: installed[p.storePluginId ?? p.id]?.requires ?? const []) == null) p,
  ];
  bool forSwing(SlotPlugin p) => p.manifest.page?.allows(PluginPageDecl.surfaceSwing) ?? false;
  return [...ok.where(forSwing), ...ok.where((p) => !forSwing(p))];
});

/// 入っているが Swing では配れないページ型と、そのわけ(親子関係、D-424)。作る画面で薄く出す。
final swingBlockedPluginsProvider = Provider<List<({SlotPlugin plugin, String reason})>>((ref) {
  final all = ref.watch(slotPluginsProvider);
  final installed = {for (final r in ref.watch(installedPluginsProvider)) r.id: r};
  return [
    for (final p in ref.watch(installedPagePluginsProvider))
      if (pageSwingBlockReason(p, all, requires: installed[p.storePluginId ?? p.id]?.requires ?? const []) case final String reason) (plugin: p, reason: reason),
  ];
});

/// Swing で配るときの説明(作る画面の行の下の文、D-424)。
String swingPluginSubtitle(SlotPlugin p) {
  final page = p.manifest.page;
  if (page?.isShared ?? false) return appL10n.swingComposerPluginShared;
  if (page?.allows(PluginPageDecl.surfaceSwing) ?? false) return appL10n.swingComposerPluginFullscreen;
  return appL10n.swingComposerPluginPage;
}

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

///
/// D-413: 編集の段も全画面のメディア表示と同じ作り(FOW の大きさと位置に合わせて面を寄せる、[ProMediaEditorArgs.avoidFows])。
/// カラムを置き換えて開いた作る画面 ([ColumnTakeoverScope]) からは、そのカラムの中に開く(全画面にしない)。
final swingEditorProvider = Provider<SwingEditor>((ref) => (context, {required bytes, required name, required mime, actions = const []}) {
      final args = ProMediaEditorArgs(bytes: bytes, name: name, mimeType: mime, extraActions: actions, avoidFows: true);
      if (ColumnTakeoverScope.maybeOf(context) == null) return context.push<MediaEditResult>(Routes.mediaEditorPro, extra: args);
      return Navigator.of(context).push<MediaEditResult>(PageRouteBuilder(
        settings: const RouteSettings(name: Routes.mediaEditorPro),
        pageBuilder: (_, _, _) => ProMediaEditorScreen(args: args),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ));
    });

/// Swing を作る画面を開く (D-413)。幅の広い画面では、ボタンを押したカラム(ホームのカラム / 第3カラム)を置き換えて開く
/// ([ColumnTakeoverStore])。狭い画面は全画面のルート `/swing/new`(前と同じ)。
Future<void> openSwingComposer(BuildContext context) async {
  if (MediaQuery.sizeOf(context).width < RasqSizes.tabletBreakpoint) {
    await context.push(Routes.swingNew);
    return;
  }
  final store = ProviderScope.containerOf(context, listen: false).read(columnTakeoverProvider.notifier);
  await store.open<void>(takeoverColumnOf(context), id: swingComposerTakeoverId, builder: (_) => const SwingComposerScreen());
}

/// カラムに重ねた作る画面の id。
const swingComposerTakeoverId = 'swing.composer';

/// 背景 (D-386): 和柄 2 つを乱数で選んで描いた縦長の PNG。テストで差し替える。
final swingBackgroundProvider = Provider<Future<Uint8List> Function()>((ref) => () => renderSwingBackground(SwingBackgroundSpec.random(math.Random())));

/// 編集画面の下のバーに足すボタンの id(キーは `media.pro.bar.extra:<id>`)。
const swingPluginActionId = 'swing.plugin';
const swingBackgroundActionId = 'swing.background';
const swingTtlActionId = 'swing.ttl';

/// 消えるまでの時間の選び方 (D-410)。
const swingTtlChoices = [1, 6, 12, 24];

String swingTtlLabel(int hours) => appL10n.swingTtlLabel(hours);

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
        ListTile(title: Text(context.l10n.swingTtl, style: RasqTypography.bodySmall)),
        for (final h in swingTtlChoices)
          ListTile(
            key: ValueKey('swing.ttl.$h'),
            leading: const Icon(Icons.timer_outlined),
            title: Text(context.l10n.swingTtlHours(h)),
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
/// できあがった下書きを返す(編集画面を閉じたら null)。D-413: 送る前の段は同じ画面のまま進む(前は送る画面を置き換えていた)。
Future<SwingDraft?> editSwing(BuildContext context, WidgetRef ref) async {
  // 消えるまで (D-410): 編集画面のバーで選ぶ。開き直しても引き継ぐ。
  final ttl = ValueNotifier(24);
  final background = ref.read(swingBackgroundProvider);
  final picker = ref.read(swingMediaPickerProvider);
  var base = (bytes: await background(), name: 'swing.png', mime: 'image/png');
  while (true) {
    if (!context.mounted) return null;
    var plugin = false;
    ({Uint8List bytes, String name, String mime})? next;

    /// 選んだ画像 / 動画を背景に。
    Future<void> pickBase(ProEditorHandle h) async {
      final video = await showModalBottomSheet<bool>(
        context: h.context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(key: swingPickImageKey, leading: const Icon(Icons.image_outlined), title: Text(ctx.l10n.swingBackgroundImage), onTap: () => Navigator.of(ctx).pop(false)),
            ListTile(key: swingPickVideoKey, leading: const Icon(Icons.movie_outlined), title: Text(ctx.l10n.swingBackgroundVideo), onTap: () => Navigator.of(ctx).pop(true)),
          ]),
        ),
      );
      if (video == null) return;
      final f = await picker(video: video);
      if (f == null) return;
      final mime = swingMediaMimeFor(f.name, reported: f.mimeType);
      if (mime == null || !mime.startsWith(video ? 'video/' : 'image/')) {
        if (h.context.mounted) ScaffoldMessenger.maybeOf(h.context)?.showSnackBar(SnackBar(content: Text(video ? appL10n.swingPickVideoFile : appL10n.swingPickImageFile)));
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
        label: appL10n.swingKindPlugin,
        icon: Icons.extension_outlined,
        onTap: (h) {
          plugin = true;
          h.close();
        },
      ),
      ProEditorExtraAction(
        id: swingBackgroundActionId,
        label: appL10n.swingChangeBackground,
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
    if (!context.mounted) return null;
    if (plugin) return SwingDraft.plugin(ttlHours: ttl.value);
    final n = next;
    if (n != null) {
      base = n;
      continue;
    }
    if (edited == null) return null;
    return SwingDraft.media(bytes: edited.bytes, mime: edited.mimeType, name: edited.name ?? base.name, ttlHours: ttl.value);
  }
}

/// 届け先の FOW の id (D-410)。
const swingAudienceFowId = 'swing.audience';

/// 届け先の FOW の初めの高さ(カラムの高さに対して)。
const swingAudienceFowHeight = 0.34;

/// 作る画面のメディアの面(FOW の逆サイドへ寄せる。テストで矩形を測る、D-413)。
const swingMediaAreaKey = ValueKey('swing.media.area');

/// CW の文の既定 (D-410)。
String get swingDefaultCw => appL10n.swingSensitive;

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

  /// D-413: 届け先の FOW はカラム(作る画面を開いたカラム)の下に付け、プレビューの枠は FOW の逆サイドへ寄せる
  /// (全画面のメディア表示と同じ作り、[FowAvoidingBox])。
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  /// 開いたらすぐ編集の段(和柄の背景で編集画面)。閉じたら作る画面も閉じる。
  Future<void> _start() async {
    if (!mounted || ref.read(swingApiProvider) == null) return;
    final d = await editSwing(context, ref);
    if (!mounted) return;
    if (d == null) return _close();
    setState(() {
      _draft = d;
      _ttl.value = d.ttlHours;
      _editing = d.plugin;
    });
  }

  /// 閉じる: カラムに重ねていればそれを閉じ(元のカラムに戻る)、全画面ならルートを戻す。
  void _close() {
    _leaving = true;
    _closeAudienceFow();
    if (ColumnTakeoverScope.closeOf(context)) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  /// 届け先の FOW を置くカラム(カラムに重ねた作る画面ならそのカラム)。
  int get _column => ColumnTakeoverScope.maybeOf(context)?.column ?? 0;

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

  /// 届け先の FOW (D-410 → D-413): 作る画面のカラムの**下**に付ける(プレビューの枠はその上に寄る。FOW を伸ばす / 縮める /
  /// 動かすと、枠もそれに合わせて動く)。widget の FOW なので、後ろの枠も触れる。
  void _syncAudienceFow() {
    if (!mounted) return;
    final show = !_leaving && !_editing && _draft != null && ref.read(swingApiProvider) != null;
    if (!show) return _closeAudienceFow();
    final manager = ref.read(overlayManagerProvider);
    _manager = manager;
    if (_fowSpec != null && manager.contains(swingAudienceFowId)) return;
    final next = _fowSpec = FowSpec(
      type: FowPanelType.widget,
      title: context.l10n.swingAudience,
      columnIndex: _column,
      initialHeightFactor: swingAudienceFowHeight,
      minHeightFactor: 0.12,
      maxHeightFactor: 0.6,
    );
    unawaited(manager.showFow<void>(
      id: swingAudienceFowId,
      spec: next,
      semanticsLabel: context.l10n.swingAudience,
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
      if (p == null) throw StateError(ref.read(slotPluginsNoticeProvider) ?? appL10n.swingLoadFailedShort);
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
      // shared のカスタムプラグイン (D-424): この Swing のセッションを Central に作らせ、見る人はそこに入る。
      final shared = plugin?.manifest.page?.isShared ?? false;
      // 端末の版がそのサーバーで配られていなければ(同梱のサンプルなど)、サーバーの現在の版で作り直す(createServed)。
      await api.createServed(NewSwing(
        kind: d.kind,
        mediaId: mediaId,
        plugin: pkg != null
            ? SwingPlugin(id: pkg.id, version: pkg.version, packageId: packageId)
            : d.plugin && _pluginId != null
                ? SwingPlugin(id: _pluginId!, version: plugin?.storeVersion, session: shared ? SwingPlugin.newSession : null)
                : null,
        audience: _audience.toAudience(),
        ttlHours: ttl,
        // D-410: オンなら センシティブ + CW の文、オフならどちらも送らない。
        cw: _cwOn && cw.isNotEmpty ? cw : null,
        sensitive: _cwOn,
      ));
      ref.invalidate(mySwingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.swingSent(ttl))));
      _close();
    } on OrgateException catch (e) {
      // `429 swing_limit` (D-503: 文ではなく名前と HTTP の番号で見る)。
      setState(() => _error = e.isReason('swing_limit', legacyText: 'swing_limit') || e.code.code == '429' ? appL10n.swingErrorLimit : appL10n.swingSendFailed(e.message));
    } catch (e) {
      setState(() => _error = appL10n.swingSendFailed(e is StateError ? e.message : '$e'));
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
        title: context.l10n.swingComposerTitle,
        showMore: false,
        // プラグインの送る前の段から戻る = 選ぶ段へ。ほかは閉じる(カラムに重ねていれば元のカラムへ)。
        onBack: ready && d.plugin && !_editing ? () => _setEditing(true) : _close,
        actions: [
          if (ready)
            Padding(
              padding: const EdgeInsets.only(right: RasqSpacing.sm),
              child: _editing
                  ? FilledButton(key: const ValueKey('swing.next'), onPressed: _hasContent ? () => _setEditing(false) : null, child: Text(context.l10n.swingNext))
                  : FilledButton(
                      key: const ValueKey('swing.send'),
                      onPressed: _ready && !_busy ? _send : null,
                      child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.l10n.swingSend),
                    ),
            ),
        ],
      ),
      body: !hasApi
          ? RasqEmptyView(key: const ValueKey('swing.composer.noAccount'), title: context.l10n.swingNeedsAccount, hint: context.l10n.swingNeedsAccountHint)
          : d == null
              ? const RasqLoading(key: ValueKey('swing.composer.starting'))
              : _editing
                  ? ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xxl), children: [
                      ..._pluginSection(),
                      ..._ttlSection(),
                      ?error,
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      ?error,
                      // 全画面のメディア表示と同じ作り (D-413): 枠は届け先の FOW(と、ほかの FOW)の逆サイドへ寄って縮む。
                      Expanded(
                        child: FowAvoidingBox(
                          manager: ref.watch(overlayManagerProvider),
                          areaKey: swingMediaAreaKey,
                          minFree: 160,
                          child: Padding(padding: const EdgeInsets.all(RasqSpacing.md), child: _previewFrame(d)),
                        ),
                      ),
                    ]),
    );
  }

  /// 送る前の段のプレビューの枠 (D-410): 中身、右上に編集し直す / 選び直すと消えるまで、下に CW の文 + オン / オフ。
  Widget _previewFrame(SwingDraft d) {
    final video = d.kind == SwingKind.video;
    final Widget content;
    if (d.plugin) {
      final plugin = _pluginId == null ? null : ref.watch(swingPluginsProvider).where((p) => (p.storePluginId ?? p.id) == _pluginId).firstOrNull;
      final title = _package != null ? context.l10n.swingUnreviewed(_package!.title) : (plugin?.manifest.page?.title ?? plugin?.manifest.name ?? context.l10n.swingKindPlugin);
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.extension_outlined, color: Colors.white70, size: 40),
        const SizedBox(height: RasqSpacing.xs),
        Text(title, key: const ValueKey('swing.preview.plugin'), style: RasqTypography.body.copyWith(color: Colors.white)),
        Text(plugin == null ? context.l10n.swingComposerPluginFullscreen : swingPluginSubtitle(plugin), style: RasqTypography.caption.copyWith(color: Colors.white70)),
      ]);
    } else if (video) {
      content = Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.movie_outlined, color: Colors.white70, size: 40),
        Text(d.name ?? context.l10n.swingKindVideo, style: RasqTypography.caption.copyWith(color: Colors.white70)),
      ]);
    } else {
      content = Image.memory(d.bytes!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: Colors.white70, size: 40));
    }
    return ClipRRect(
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
              Text(context.l10n.swingTtlRemaining(_ttl.value), key: const ValueKey('swing.ttl.label'), style: RasqTypography.caption.copyWith(color: Colors.white70)),
              d.plugin
                  ? RasqIconButton(key: const ValueKey('swing.plugin.change'), icon: Icons.edit_outlined, tooltip: context.l10n.swingRepick, color: Colors.white, onPressed: _busy ? null : () => _setEditing(true))
                  : RasqIconButton(key: const ValueKey('swing.reedit'), icon: Icons.edit_outlined, tooltip: context.l10n.swingReedit, color: Colors.white, onPressed: _busy ? null : _reedit),
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
                child: Text(context.l10n.swingCwTooLong(SwingComposerScreen.maxCwChars), style: RasqTypography.caption.copyWith(color: RasqColors.salmon)),
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
                      hintText: context.l10n.swingCwHint,
                      hintStyle: RasqTypography.bodySmall.copyWith(color: Colors.white38),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm, vertical: RasqSpacing.xs),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RasqSpacing.xs),
              Tooltip(
                message: _cwOn ? context.l10n.swingCwOff : context.l10n.swingCwOn,
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
    final blocked = ref.watch(swingBlockedPluginsProvider);
    final scheme = Theme.of(context).colorScheme;
    return [
      RasqSectionHeader(title: context.l10n.swingPluginSection),
      if (plugins.isEmpty)
        RasqNotice(key: const ValueKey('swing.plugin.none'), text: context.l10n.swingPluginNone, detail: context.l10n.swingPluginNoneDetail),
      for (final p in plugins)
        RasqRadioListTile<String>(
          key: ValueKey('swing.plugin.${p.storePluginId ?? p.id}'),
          title: p.manifest.page?.title ?? p.manifest.name,
          subtitle: swingPluginSubtitle(p),
          value: p.storePluginId ?? p.id,
          groupValue: _pluginId,
          onChanged: (v) => setState(() {
            _pluginId = v;
            _package = null;
          }),
        ),
      // 親子関係のあるもの (D-424): 選べない。わけを出す。
      for (final b in blocked)
        RasqListTile(
          key: ValueKey('swing.plugin.blocked.${b.plugin.storePluginId ?? b.plugin.id}'),
          leading: Icon(Icons.block, color: scheme.onSurfaceVariant),
          title: b.plugin.manifest.page?.title ?? b.plugin.manifest.name,
          subtitle: b.reason,
          enabled: false,
          chevron: false,
        ),
      // 未審査のまま配る (D-379)。見る人の端末では制限モード(通信なし、GPU は可)。
      RasqListTile(
        key: const ValueKey('swing.plugin.file'),
        title: _package == null ? context.l10n.swingFromFile : context.l10n.swingUnreviewed(_package!.title),
        subtitle: _package == null ? context.l10n.swingFromFileSubtitle : _package!.name,
        detail: context.l10n.swingFromFileDetail,
        leading: Icon(_package == null ? Icons.file_open_outlined : Icons.check_circle_outline),
        onTap: _busy ? null : _pickPackage,
      ),
    ];
  }

  /// 消えるまで (D-410: 編集の段。プラグインはここ、画像 / 動画は編集画面のバー)。
  List<Widget> _ttlSection() => [
        RasqSectionHeader(title: context.l10n.swingTtl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, children: [
            for (final h in swingTtlChoices)
              ChoiceChip(key: ValueKey('swing.ttl.$h'), label: Text(context.l10n.swingTtlHours(h)), selected: _ttl.value == h, onSelected: (_) => _ttl.value = h),
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
        if (selection.isEmpty) RasqNotice.warning(key: const ValueKey('swing.audience.empty'), text: context.l10n.swingAudienceEmpty),
        RasqSwitchListTile(
          key: const ValueKey('swing.audience.followers'),
          leading: const Icon(Icons.people_outline),
          title: context.l10n.swingAudienceFollowers,
          subtitle: context.l10n.swingAudienceFollowersSubtitle,
          value: selection.followers,
          onChanged: (v) => selection.followers = v,
        ),
        for (final l in lists)
          RasqSwitchListTile(
            key: ValueKey('swing.audience.list.${l.id}'),
            leading: const Icon(Icons.list_alt_outlined),
            title: l.name,
            subtitle: context.l10n.swingAudienceList,
            value: selection.lists.contains(l.id),
            onChanged: (v) => selection.setList(l.id, v),
          ),
        if (lists.isEmpty) RasqCaption(context.l10n.swingAudienceNoLists, padding: EdgeInsets.all(RasqSpacing.page)),
      ]),
    );
  }
}
