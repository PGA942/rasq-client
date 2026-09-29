import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../backend/orgate_client.dart' show OrgateException;
import '../../backend/rasq_collections_api.dart';
import '../../shell/headers.dart';
import '../collections/rasq_collections.dart';
import '../compose/media_file_pick.dart' show mediaVideoExtensions, mediaMimeFor;
import '../custom/custom_plugins_screen.dart' show installedPagePluginsProvider;
import '../plugins/slot_plugins.dart';
import '../store/rasqpkg.dart' show isRasqPackage, rasqpkgZstdProvider;
import 'swing_models.dart';
import 'swing_providers.dart';

/// Swing を作る (D-377)。中身(テキスト / 画像 / 動画 / プラグイン)、届け先(フォロワー / 自分の RASQ リスト)、時間。

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

class SwingComposerScreen extends ConsumerStatefulWidget {
  const SwingComposerScreen({super.key});

  static const ttlChoices = [1, 6, 12, 24];

  @override
  ConsumerState<SwingComposerScreen> createState() => _SwingComposerScreenState();
}

class _SwingComposerScreenState extends ConsumerState<SwingComposerScreen> {
  final _text = TextEditingController();
  SwingKind _kind = SwingKind.text;
  ({String name, Uint8List bytes, String mime})? _media;
  String? _pluginId;

  /// 未審査のプラグイン (D-379): ファイルから読んだ入れ物(確かめ済み)。
  ({String name, Uint8List bytes, String id, String version, String title})? _package;
  bool _followers = true;
  final _lists = <String>{};
  int _ttl = 24;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _ready {
    if (!_followers && _lists.isEmpty) return false;
    return switch (_kind) {
      SwingKind.text => _text.text.trim().isNotEmpty,
      SwingKind.image || SwingKind.video => _media != null,
      SwingKind.plugin => _pluginId != null || _package != null,
    };
  }

  Future<void> _pick() async {
    final f = await ref.read(swingMediaPickerProvider)(video: _kind == SwingKind.video);
    if (f == null) return;
    final mime = swingMediaMimeFor(f.name, reported: f.mimeType);
    final want = _kind == SwingKind.video ? 'video/' : 'image/';
    if (mime == null || !mime.startsWith(want)) {
      setState(() => _error = '${_kind.label}のファイルを選んでください');
      return;
    }
    final bytes = await f.readAsBytes();
    setState(() {
      _media = (name: f.name, bytes: bytes, mime: mime);
      _error = null;
    });
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
    if (api == null || !_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? mediaId;
      final m = _media;
      if ((_kind == SwingKind.image || _kind == SwingKind.video) && m != null) mediaId = await api.uploadMedia(m.bytes, contentType: m.mime);
      final plugin = _pluginId == null ? null : ref.read(swingPluginsProvider).where((p) => (p.storePluginId ?? p.id) == _pluginId).firstOrNull;
      final pkg = _kind == SwingKind.plugin ? _package : null;
      final packageId = pkg == null ? null : await api.uploadMedia(pkg.bytes, contentType: isRasqPackage(pkg.bytes) ? 'application/vnd.rasq.pkg' : 'application/wasm');
      await api.create(NewSwing(
        kind: _kind,
        text: _kind == SwingKind.plugin ? '' : _text.text,
        mediaId: mediaId,
        plugin: pkg != null
            ? SwingPlugin(id: pkg.id, version: pkg.version, packageId: packageId)
            : _kind == SwingKind.plugin && _pluginId != null
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
    final lists = ref.watch(myRasqCollectionsProvider(RasqCollectionKind.list)).value ?? const <RasqCollection>[];
    final plugins = ref.watch(swingPluginsProvider);
    final hasApi = ref.watch(swingApiProvider) != null;
    return Scaffold(
      appBar: const RasqPageHeader(title: 'Swing を作る', showMore: false),
      body: !hasApi
          ? const RasqEmptyView(key: ValueKey('swing.composer.noAccount'), title: 'RASQ アカウントが要ります', hint: 'Swing は RASQ アカウントから出します。サイドバーからログインしてください')
          : ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.xxl), children: [
              const RasqCaption(
                'フォロワーと、RASQ リストに入れた人に届きます。時間がたつと消えます',
                detail: 'D-377 / Central S-056。RASQ リストのメンバーには、その SNS アカウントの持ち主の確認を済ませた人にだけ届きます。見た人がスワイプで次へ進むと、その人にはもう出ません。',
                padding: EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, 0),
              ),
              const RasqSectionHeader(title: '中身'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                child: Wrap(spacing: RasqSpacing.xs, children: [
                  for (final k in SwingKind.values)
                    ChoiceChip(
                      key: ValueKey('swing.kind.${k.wire}'),
                      label: Text(k.label),
                      selected: _kind == k,
                      onSelected: (_) => setState(() {
                        _kind = k;
                        _media = null;
                        _error = null;
                      }),
                    ),
                ]),
              ),
              if (_kind != SwingKind.plugin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
                  child: TextField(
                    key: const ValueKey('swing.text'),
                    controller: _text,
                    maxLength: 500,
                    minLines: _kind == SwingKind.text ? 3 : 1,
                    maxLines: 6,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(hintText: _kind == SwingKind.text ? '伝えたいこと' : '添える文(なくてもよい)', border: const OutlineInputBorder()),
                  ),
                ),
              if (_kind == SwingKind.image || _kind == SwingKind.video)
                RasqListTile(
                  key: const ValueKey('swing.media'),
                  title: _media == null ? '${_kind.label}を選ぶ' : _media!.name,
                  subtitle: _media == null ? null : '${(_media!.bytes.length / 1024).ceil()} KB',
                  leading: Icon(_kind == SwingKind.video ? Icons.movie_outlined : Icons.image_outlined),
                  onTap: _busy ? null : _pick,
                ),
              if (_kind == SwingKind.plugin) ...[
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
              ],
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
              if (!_followers && _lists.isEmpty)
                const RasqNotice.warning(key: ValueKey('swing.audience.empty'), text: '届け先を 1 つ以上選んでください'),
              const RasqSectionHeader(title: '消えるまで'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                child: Wrap(spacing: RasqSpacing.xs, children: [
                  for (final h in SwingComposerScreen.ttlChoices)
                    ChoiceChip(key: ValueKey('swing.ttl.$h'), label: Text('$h 時間'), selected: _ttl == h, onSelected: (_) => setState(() => _ttl = h)),
                ]),
              ),
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
}
