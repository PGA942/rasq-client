import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../backend/orgate_client.dart' show OrgateException;
import '../../app/navigation.dart';
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
  const SwingDraft.media({required Uint8List this.bytes, required String this.mime, required String this.name})
      : plugin = false;
  const SwingDraft.plugin()
      : bytes = null,
        mime = null,
        name = null,
        plugin = true;
  final Uint8List? bytes;
  final String? mime;
  final String? name;
  final bool plugin;

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

/// 長押しで選ぶ背景の画像 / 動画のシートの key。
const swingPickImageKey = ValueKey('swing.background.image');
const swingPickVideoKey = ValueKey('swing.background.video');

/// 始める: 和柄の背景で編集画面へ → 送る画面。「プラグイン」を押したら、配るプラグインを選ぶ送る画面へ。
/// 「背景を変える」(D-387): 押すと別の和柄、**長押しで画像 / 動画を選んで背景に**。画像は編集画面のまま差し替え、動画
/// (や、動画を開いているときの和柄)は編集画面を開き直す(それまでの編集は捨てる)。
/// [replace] = いまの画面(開いたばかりの送る画面)を置き換える。編集画面を閉じたら、その画面も閉じる。
Future<void> startSwing(BuildContext context, WidgetRef ref, {bool replace = false}) async {
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
    ]);
    if (!context.mounted) return;
    if (plugin) return open(const SwingDraft.plugin());
    final n = next;
    if (n != null) {
      base = n;
      continue;
    }
    if (edited == null) {
      if (replace) context.pop();
      return;
    }
    return open(SwingDraft.media(bytes: edited.bytes, mime: edited.mimeType, name: edited.name ?? base.name));
  }
}

class SwingComposerScreen extends ConsumerStatefulWidget {
  const SwingComposerScreen({super.key, this.draft});

  /// null = 開いたらすぐ和柄の背景で編集画面へ([startSwing])。
  final SwingDraft? draft;

  static const ttlChoices = [1, 6, 12, 24];

  @override
  ConsumerState<SwingComposerScreen> createState() => _SwingComposerScreenState();
}

class _SwingComposerScreenState extends ConsumerState<SwingComposerScreen> {
  late SwingDraft? _draft = widget.draft;
  String? _pluginId;

  @override
  void initState() {
    super.initState();
    if (widget.draft == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(swingApiProvider) != null) startSwing(context, ref, replace: true);
      });
    }
  }

  /// 未審査のプラグイン (D-379): ファイルから読んだ入れ物(確かめ済み)。
  ({String name, Uint8List bytes, String id, String version, String title})? _package;
  bool _followers = true;
  final _lists = <String>{};
  int _ttl = 24;
  bool _busy = false;
  String? _error;

  bool get _ready {
    final d = _draft;
    if (d == null || (!_followers && _lists.isEmpty)) return false;
    return d.plugin ? (_pluginId != null || _package != null) : d.bytes != null;
  }

  /// 編集し直す(同じ絵 / 動画で編集画面を開き直す)。
  Future<void> _reedit() async {
    final d = _draft;
    if (d == null || d.plugin) return;
    final edited = await ref.read(swingEditorProvider)(context, bytes: d.bytes!, name: d.name!, mime: d.mime!);
    if (edited == null || !mounted) return;
    setState(() => _draft = SwingDraft.media(bytes: edited.bytes, mime: edited.mimeType, name: edited.name ?? d.name!));
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
      await api.create(NewSwing(
        kind: d.kind,
        mediaId: mediaId,
        plugin: pkg != null
            ? SwingPlugin(id: pkg.id, version: pkg.version, packageId: packageId)
            : d.plugin && _pluginId != null
                ? SwingPlugin(id: _pluginId!, version: plugin?.storeVersion)
                : null,
        audience: SwingAudience(followers: _followers, lists: _lists.toList()),
        ttlHours: _ttl,
      ));
      ref.invalidate(mySwingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Swing を出しました($_ttl 時間で消えます)')));
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
    return Scaffold(
      appBar: const RasqPageHeader(title: 'Swing を作る', showMore: false),
      body: !hasApi
          ? const RasqEmptyView(key: ValueKey('swing.composer.noAccount'), title: 'RASQ アカウントが要ります', hint: 'Swing は RASQ アカウントから出します。サイドバーからログインしてください')
          : d == null
              ? const RasqLoading(key: ValueKey('swing.composer.starting'))
              : ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xxl), children: [
                  if (d.plugin) ..._pluginSection() else _preview(d),
                  ..._audienceSection(),
                  if (_error != null)
                    Padding(
                      key: const ValueKey('swing.error'),
                      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
                      child: Text(_error!, style: RasqTypography.caption.copyWith(color: scheme.error)),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.lg, RasqSpacing.page, 0),
                    child: FilledButton(
                      key: const ValueKey('swing.send'),
                      onPressed: _ready && !_busy ? _send : null,
                      child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Swing を出す'),
                    ),
                  ),
                ]),
    );
  }

  /// 編集し終えた画像 / 動画。押すと編集し直す。
  Widget _preview(SwingDraft d) {
    final video = d.kind == SwingKind.video;
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(RasqSizes.radiusLg),
          child: Container(
            key: const ValueKey('swing.preview'),
            height: 240,
            color: Colors.black,
            alignment: Alignment.center,
            child: video
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.movie_outlined, color: Colors.white70, size: 40),
                    Text(d.name ?? '動画', style: RasqTypography.caption.copyWith(color: Colors.white70)),
                  ])
                : Image.memory(d.bytes!, fit: BoxFit.contain, errorBuilder: (_, _, _) => const Icon(Icons.image_outlined, color: Colors.white70, size: 40)),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(key: const ValueKey('swing.reedit'), onPressed: _busy ? null : _reedit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('編集し直す')),
        ),
      ]),
    );
  }

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

  List<Widget> _audienceSection() {
    final lists = ref.watch(myRasqCollectionsProvider(RasqCollectionKind.list)).value ?? const <RasqCollection>[];
    return [
      const RasqSectionHeader(title: '届け先'),
      SwitchListTile(
        key: const ValueKey('swing.audience.followers'),
        title: const Text('フォロワー'),
        subtitle: const Text('RASQ アカウントをフォローしている人'),
        value: _followers,
        onChanged: (v) => setState(() => _followers = v),
      ),
      if (lists.isEmpty)
        const RasqCaption('RASQ リストを作ると、リストに入れた人にも届けられます', padding: EdgeInsets.symmetric(horizontal: RasqSpacing.page))
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
            for (final l in lists)
              FilterChip(
                key: ValueKey('swing.audience.list.${l.id}'),
                label: Text(l.name),
                selected: _lists.contains(l.id),
                onSelected: (v) => setState(() => v ? _lists.add(l.id) : _lists.remove(l.id)),
              ),
          ]),
        ),
      if (!_followers && _lists.isEmpty) const RasqNotice.warning(key: ValueKey('swing.audience.empty'), text: '届け先を 1 つ以上選んでください'),
      const RasqSectionHeader(title: '消えるまで'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
        child: Wrap(spacing: RasqSpacing.xs, children: [
          for (final h in SwingComposerScreen.ttlChoices)
            ChoiceChip(key: ValueKey('swing.ttl.$h'), label: Text('$h 時間'), selected: _ttl == h, onSelected: (_) => setState(() => _ttl = h)),
        ]),
      ),
    ];
  }
}
