import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../text/inline_spans.dart';
import '../settings/settings_dsl.dart';

/// RASQ のページ (D-446): RASQ アカウントのページの「ページ」タブに置けるもの。
///
/// - **Markdown ページ**: 下書きは端末([rasqPageDraftsProvider]、設定の置き場 `rasq.pages.drafts`)、「公開」で Central へ
///   (`PUT /me/md-pages/{id}`、訪れた人も読める)。本文は Markdown(見出し / 箇条書き / 引用 / コード / 画像 / リンク / 区切り)に、
///   Misskey の投稿と同じメンション / ハッシュタグ / カスタム絵文字 / URL、**MFM は HTML 風のタグ**(`<spin speed="1s">` / `<x2>` /
///   `<fg color="f00">` / `<center>` / `<ruby>本<rt>ほん</rt></ruby>` …、[InlineSpans.parse] の `htmlFns`)。
/// - **自作プラグイン(制限モード)**: 持ち主が上げたページ型の配布物(`.rspkg` / `.rasqpkg`、`profile` の面)を Central に置き
///   (`POST /me/sideload-pages`)、訪れた人の端末では同意のうえ**制限モード**(通信 / 保管庫などなし)で一時的に動かす
///   (Swing の未審査のプラグインと同じ流れ、`rasqpage:` の入れ物)。
/// - ストアのカスタムプラグイン(D-357 の置き場、`PUT /me/pages`)と、その**ホスト用ページ**(面 `profile.host` を宣言したもの。
///   置いた本人にだけ出る)は [CustomProfilePagesTab] が出す。

// ── 型 ──────────────────────────────────────────────────────────────

@immutable
class RasqMdPageInfo {
  const RasqMdPageInfo({required this.id, required this.title, this.updatedAt});
  final String id;
  final String title;
  final DateTime? updatedAt;

  factory RasqMdPageInfo.fromJson(Map<String, Object?> j) =>
      RasqMdPageInfo(id: '${j['id'] ?? ''}', title: '${j['title'] ?? ''}', updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}'));
}

@immutable
class RasqMdPage extends RasqMdPageInfo {
  const RasqMdPage({required super.id, required super.title, required this.body, super.updatedAt});
  final String body;

  factory RasqMdPage.fromJson(Map<String, Object?> j) =>
      RasqMdPage(id: '${j['id'] ?? ''}', title: '${j['title'] ?? ''}', body: '${j['body'] ?? ''}', updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}'));
}

/// Central に置いた自作プラグイン(制限モードで動かす)。
@immutable
class RasqSideloadPage {
  const RasqSideloadPage({required this.id, required this.pluginId, required this.version, required this.name, this.sha512 = '', this.size = 0, this.packageUrl});
  final String id;
  final String pluginId;
  final String version;
  final String name;
  final String sha512;
  final int size;
  final Uri? packageUrl;

  factory RasqSideloadPage.fromJson(Map<String, Object?> j) => RasqSideloadPage(
        id: '${j['id'] ?? ''}',
        pluginId: '${j['pluginId'] ?? ''}',
        version: '${j['version'] ?? ''}',
        name: '${j['name'] ?? j['pluginId'] ?? ''}',
        sha512: '${j['sha512'] ?? ''}',
        size: (j['size'] as num?)?.toInt() ?? 0,
        packageUrl: j['packageUrl'] is String ? Uri.tryParse(j['packageUrl'] as String) : null,
      );
}

/// Markdown ページの上限(Central と同じ)。
const rasqMdTitleMax = 80;
const rasqMdBodyMax = 50000;

// ── Central の口 ─────────────────────────────────────────────────────

class RasqPagesApi {
  RasqPagesApi(this._c, {this.base});
  final OrgateClient _c;
  final Uri? base;

  static String _h(String handle) => Uri.encodeComponent(handle);

  Future<List<RasqMdPageInfo>> mdPages(String handle) async => [
        for (final x in await _c.getList('/accounts/${_h(handle)}/md-pages'))
          if (x is Map) RasqMdPageInfo.fromJson(x.cast<String, Object?>()),
      ];

  Future<RasqMdPage> mdPage(String handle, String id) async => RasqMdPage.fromJson(await _c.getJson('/accounts/${_h(handle)}/md-pages/${Uri.encodeComponent(id)}'));

  /// 公開(作る / 書き換える)。
  Future<RasqMdPage> publishMdPage(String id, {required String title, required String body}) async =>
      RasqMdPage.fromJson(await _c.putJson('/me/md-pages/${Uri.encodeComponent(id)}', {'title': title, 'body': body}));

  Future<void> deleteMdPage(String id) => _c.delete('/me/md-pages/${Uri.encodeComponent(id)}');

  Future<List<RasqSideloadPage>> sideloadPages(String handle) async => [
        for (final x in await _c.getList('/accounts/${_h(handle)}/sideload-pages'))
          if (x is Map) RasqSideloadPage.fromJson(x.cast<String, Object?>()),
      ];

  Future<RasqSideloadPage> uploadSideload(Uint8List bytes) async => RasqSideloadPage.fromJson(await _c.postBytes('/me/sideload-pages', bytes, contentType: 'application/octet-stream'));

  Future<void> deleteSideload(String id) => _c.delete('/me/sideload-pages/${Uri.encodeComponent(id)}');

  /// 入れ物を取る(訪れた人も)。
  Future<Uint8List> sideloadPackage(String handle, String id) => _c.getBytes('/accounts/${_h(handle)}/sideload-pages/${Uri.encodeComponent(id)}/package');

  /// ページに貼る画像を上げる(`POST /me/md-pages/images`、S-086。100 枚まで)。返り = 画像の URL(匿名で読める)。
  Future<Uri> uploadImage(List<int> bytes, String contentType) async {
    final j = await _c.postBytes('/me/md-pages/images', bytes, contentType: contentType);
    final url = j['url'];
    if (url is String && Uri.tryParse(url) != null) {
      final u = Uri.parse(url);
      return u.hasScheme || base == null ? u : base!.resolveUri(u);
    }
    throw StateError('画像の URL が返りませんでした');
  }
}

final rasqPagesApiProvider = Provider<RasqPagesApi?>((ref) {
  final client = ref.watch(centralClientProvider);
  return client == null ? null : RasqPagesApi(client, base: ref.watch(centralBaseUrlProvider));
});

final rasqMdPagesProvider = FutureProvider.autoDispose.family<List<RasqMdPageInfo>, String>((ref, handle) async {
  final api = ref.watch(rasqPagesApiProvider);
  return api == null ? const [] : api.mdPages(handle);
});

final rasqMdPageProvider = FutureProvider.autoDispose.family<RasqMdPage, ({String handle, String id})>((ref, k) async {
  final api = ref.watch(rasqPagesApiProvider);
  if (api == null) throw StateError('RASQ のサーバーにつないでいません');
  return api.mdPage(k.handle, k.id);
});

final rasqSideloadPagesProvider = FutureProvider.autoDispose.family<List<RasqSideloadPage>, String>((ref, handle) async {
  final api = ref.watch(rasqPagesApiProvider);
  return api == null ? const [] : api.sideloadPages(handle);
});

/// 自作プラグインの配布物を選ぶ(テストで差し替える)。
final rasqPagePackagePickerProvider = Provider<Future<Uint8List?> Function()>((ref) => () async {
      final f = await fs.openFile(acceptedTypeGroups: const [fs.XTypeGroup(label: 'プラグイン(.rspkg / .rasqpkg)', extensions: ['rspkg', 'rasqpkg'])]);
      return f == null ? null : await f.readAsBytes();
    });

/// ページに貼る画像を選ぶ(テストで差し替える)。返り = (中身, MIME)。
final rasqPageImagePickerProvider = Provider<Future<({Uint8List bytes, String contentType})?> Function()>((ref) => () async {
      final f = await fs.openFile(acceptedTypeGroups: const [fs.XTypeGroup(label: '画像', extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'])]);
      if (f == null) return null;
      final name = f.name.toLowerCase();
      final type = name.endsWith('.png') ? 'image/png' : name.endsWith('.webp') ? 'image/webp' : name.endsWith('.gif') ? 'image/gif' : 'image/jpeg';
      return (bytes: await f.readAsBytes(), contentType: type);
    });

// ── 下書き(端末)─────────────────────────────────────────────────────

const rasqPageDraftsArea = 'rasq.pages.drafts';

typedef RasqPageDraft = ({String id, String title, String body, DateTime at});

/// 端末に残している下書き(id → 下書き)。公開したら消す。
final rasqPageDraftsProvider = Provider<Map<String, RasqPageDraft>>((ref) {
  final raw = ref.watch(settingsAreaProvider(rasqPageDraftsArea)).value ?? const {};
  return {
    for (final e in raw.entries)
      if (e.value is Map)
        e.key: (
          id: e.key,
          title: '${(e.value as Map)['title'] ?? ''}',
          body: '${(e.value as Map)['body'] ?? ''}',
          at: DateTime.tryParse('${(e.value as Map)['at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
  };
});

Future<void> saveRasqPageDraft(WidgetRef ref, String id, {required String title, required String body}) =>
    ref.read(settingsAreaProvider(rasqPageDraftsArea).notifier).set(id, {'title': title, 'body': body, 'at': DateTime.now().toIso8601String()});

Future<void> dropRasqPageDraft(WidgetRef ref, String id) => ref.read(settingsAreaProvider(rasqPageDraftsArea).notifier).set(id, null);

/// 新しいページの id(Central のキー。端末で作る)。
String newRasqPageId() {
  final now = DateTime.now().microsecondsSinceEpoch;
  final r = (now ^ identityHashCode(Object())).toRadixString(16).padLeft(12, '0');
  final t = now.toRadixString(16).padLeft(16, '0');
  // uuid v4 の形(Central は uuid を受ける)。
  final h = '$t$r'.padRight(32, '0').substring(0, 32);
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-4${h.substring(13, 16)}-a${h.substring(17, 20)}-${h.substring(20, 32)}';
}

// ── Markdown の表示 ──────────────────────────────────────────────────

/// Markdown(+ Misskey の投稿と同じ書き方 + HTML 風の MFM)を描く (D-446)。ブロックは 1 行ずつ見る:
/// `#` 〜 `###` 見出し / `-` `*` `+` / `1.` 箇条書き / `![代替](URL)` だけの行は画像 / `---` 区切り / ```` ``` ```` コード。
/// ほか(続く行)は段落で、行内は [InlineSpans.parse](太字 / 斜体 / 打ち消し / コード / リンク / 引用 / メンション / ハッシュタグ /
/// カスタム絵文字 / URL / HTML 風の MFM)。
class RasqMarkdownView extends ConsumerWidget {
  const RasqMarkdownView(this.markdown, {super.key, this.selectable = false});
  final String markdown;
  final bool selectable;

  static final _heading = RegExp(r'^(#{1,3})\s+(.*)$');
  static final _bullet = RegExp(r'^\s*([-*+]|\d+\.)\s+(.*)$');
  static final _image = RegExp(r'^!\[([^\]]*)\]\((https?://[^\s)]+)\)\s*$');
  static final _rule = RegExp(r'^\s*(---+|\*\*\*+|___+)\s*$');

  /// 段落 / 見出し / 箇条書きなどのブロックに分ける(テストでも使う)。
  static List<({String kind, String text, String? extra})> blocks(String md) {
    final out = <({String kind, String text, String? extra})>[];
    final lines = const LineSplitter().convert(md);
    final para = <String>[];
    void flush() {
      if (para.isEmpty) return;
      out.add((kind: 'p', text: para.join('\n'), extra: null));
      para.clear();
    }

    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.trimLeft().startsWith('```')) {
        flush();
        final code = <String>[];
        var j = i + 1;
        while (j < lines.length && !lines[j].trimLeft().startsWith('```')) {
          code.add(lines[j]);
          j++;
        }
        out.add((kind: 'code', text: code.join('\n'), extra: null));
        i = j;
        continue;
      }
      if (l.trim().isEmpty) {
        flush();
        continue;
      }
      final h = _heading.firstMatch(l);
      final img = _image.firstMatch(l.trim());
      final b = _bullet.firstMatch(l);
      if (h != null) {
        flush();
        out.add((kind: 'h${h.group(1)!.length}', text: h.group(2)!, extra: null));
      } else if (_rule.hasMatch(l)) {
        flush();
        out.add((kind: 'hr', text: '', extra: null));
      } else if (img != null) {
        flush();
        out.add((kind: 'img', text: img.group(1)!, extra: img.group(2)));
      } else if (b != null) {
        flush();
        final mark = b.group(1)!;
        out.add((kind: 'li', text: b.group(2)!, extra: mark.endsWith('.') ? mark : '•'));
      } else {
        para.add(l);
      }
    }
    flush();
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final emojis = ref.watch(emojiCacheProvider);
    List<RasqSpan> spans(String t) => InlineSpans.parse(
          t,
          emojis: emojis,
          htmlFns: true,
          onLink: (u) => launchUrl(u, mode: LaunchMode.externalApplication),
          onHashtag: (tag) => context.pushTrend(tag),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final b in blocks(markdown))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: RasqSpacing.xs),
          child: switch (b.kind) {
            'h1' => RasqRichText(spans(b.text), style: RasqTypography.title.copyWith(fontSize: 22)),
            'h2' => RasqRichText(spans(b.text), style: RasqTypography.title.copyWith(fontSize: 19)),
            'h3' => RasqRichText(spans(b.text), style: RasqTypography.title),
            'hr' => const Divider(),
            'code' => Container(
                padding: const EdgeInsets.all(RasqSpacing.sm),
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusSm)),
                child: Text(b.text, style: RasqTypography.bodySmall.copyWith(fontFamily: 'monospace')),
              ),
            'img' => ClipRRect(
                borderRadius: BorderRadius.circular(RasqSizes.radiusMd),
                child: Image.network(b.extra!, semanticLabel: b.text, fit: BoxFit.contain, webHtmlElementStrategy: rasqWebImageStrategy, errorBuilder: (_, _, _) => Text('(画像: ${b.text})', style: RasqTypography.caption)),
              ),
            'li' => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 24, child: Text(b.extra!, style: RasqTypography.body)),
                Expanded(child: RasqRichText(spans(b.text), style: RasqTypography.body)),
              ]),
            _ => RasqRichText(spans(b.text), style: RasqTypography.body),
          },
        ),
    ]);
  }
}

// ── 読む画面 ─────────────────────────────────────────────────────────

/// 公開した Markdown ページ(訪れた人も)。持ち主は ✎ で編集へ。
class RasqMdPageScreen extends ConsumerWidget {
  const RasqMdPageScreen({super.key, required this.handle, required this.id, this.isMine = false});
  final String handle;
  final String id;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(rasqMdPageProvider((handle: handle, id: id)));
    return Scaffold(
      appBar: AppBar(
        title: Text(page.value?.title ?? 'ページ'),
        actions: [
          if (isMine && page.value != null)
            RasqIconButton(
              key: const ValueKey('rasqPage.md.edit'),
              icon: Icons.edit_outlined,
              tooltip: '編集',
              onPressed: () => context.push(Routes.rasqMdPageEdit(id), extra: page.value),
            ),
        ],
      ),
      body: page.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqEmptyView(title: 'ページを読めませんでした', hint: '$e'),
        data: (p) => ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 96), children: [RasqMarkdownView(p.body, key: const ValueKey('rasqPage.md.view'))]),
      ),
    );
  }
}

// ── 編集画面 ─────────────────────────────────────────────────────────

/// Markdown ページの編集 (D-446)。書くたびに端末の下書きへ残し、「公開」で Central へ。プレビューは公開したときと同じ表示。
/// 道具の行: 太字 / 見出し / 箇条書き / リンク / 画像(上げて URL を貼る)/ HTML 風の MFM(中央 / 大きく / 回転 / 色 / ルビ …)。
class RasqMdPageEditorScreen extends ConsumerStatefulWidget {
  const RasqMdPageEditorScreen({super.key, required this.id, this.published});
  final String id;

  /// 公開済みの中身(編集から来たとき)。下書きがあれば下書きが先。
  final RasqMdPage? published;

  @override
  ConsumerState<RasqMdPageEditorScreen> createState() => _RasqMdPageEditorScreenState();
}

class _RasqMdPageEditorScreenState extends ConsumerState<RasqMdPageEditorScreen> {
  late final RasqPageDraft? _draft = ref.read(rasqPageDraftsProvider)[widget.id];
  late final _title = TextEditingController(text: _draft?.title ?? widget.published?.title ?? '');
  late final _body = TextEditingController(text: _draft?.body ?? widget.published?.body ?? '');
  bool _preview = false;
  bool _busy = false;
  Timer? _save;

  static const _snippets = <(String, String, String)>[
    ('太字', '**', '**'),
    ('見出し', '## ', ''),
    ('箇条書き', '- ', ''),
    ('リンク', '[', '](https://)'),
    ('中央', '<center>', '</center>'),
    ('大きく', '<x2>', '</x2>'),
    ('小さく', '<small>', '</small>'),
    ('回転', '<spin speed="1.5s">', '</spin>'),
    ('跳ねる', '<jump>', '</jump>'),
    ('色', '<fg color="f00">', '</fg>'),
    ('虹', '<rainbow>', '</rainbow>'),
    ('ルビ', '<ruby>', '<rt>よみ</rt></ruby>'),
  ];

  @override
  void initState() {
    super.initState();
    _title.addListener(_changed);
    _body.addListener(_changed);
  }

  @override
  void dispose() {
    _save?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _changed() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  Future<void> _saveDraft() => saveRasqPageDraft(ref, widget.id, title: _title.text, body: _body.text);

  void _wrap(String open, String close) {
    final v = _body.value;
    final sel = v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);
    final inner = sel.textInside(v.text);
    final text = v.text.replaceRange(sel.start, sel.end, '$open$inner$close');
    _body.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: sel.start + open.length + inner.length));
  }

  Future<void> _insertImage() async {
    final api = ref.read(rasqPagesApiProvider);
    final picked = await ref.read(rasqPageImagePickerProvider)();
    if (picked == null || api == null || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      final url = await api.uploadImage(picked.bytes, picked.contentType);
      _wrap('\n![画像]($url)\n', '');
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('画像を上げられませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final api = ref.read(rasqPagesApiProvider);
    final title = _title.text.trim();
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (title.isEmpty) {
      messenger?.showSnackBar(const SnackBar(content: Text('タイトルを入れてください')));
      return;
    }
    if (api == null) {
      messenger?.showSnackBar(const SnackBar(content: Text('RASQ アカウントにログインすると公開できます')));
      return;
    }
    setState(() => _busy = true);
    try {
      await api.publishMdPage(widget.id, title: title, body: _body.text);
      _save?.cancel();
      await dropRasqPageDraft(ref, widget.id);
      ref.invalidate(rasqMdPagesProvider);
      ref.invalidate(rasqMdPageProvider);
      messenger?.showSnackBar(const SnackBar(content: Text('公開しました')));
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('公開できませんでした: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await ref.read(overlayManagerProvider).showAlert(
          id: 'rasqPage.md.delete',
          title: 'ページを削除',
          message: widget.published == null ? '下書きを削除します。' : '公開したページと下書きを削除します。元に戻せません。',
          confirmText: '削除する',
          cancelText: 'キャンセル',
          destructive: true,
        );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      if (widget.published != null) await ref.read(rasqPagesApiProvider)?.deleteMdPage(widget.id);
      _save?.cancel();
      await dropRasqPageDraft(ref, widget.id);
      ref.invalidate(rasqMdPagesProvider);
      if (mounted) Navigator.of(context).maybePop();
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('削除できませんでした: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ページを編集'),
        actions: [
          RasqIconButton(key: const ValueKey('rasqPage.md.delete'), icon: Icons.delete_outline, tooltip: '削除', onPressed: _busy ? null : _delete),
          RasqIconButton(key: const ValueKey('rasqPage.md.preview'), icon: _preview ? Icons.edit_note : Icons.visibility_outlined, tooltip: _preview ? '書く' : 'プレビュー', onPressed: () => setState(() => _preview = !_preview)),
          Padding(
            padding: const EdgeInsets.only(right: RasqSpacing.sm),
            child: FilledButton(key: const ValueKey('rasqPage.md.publish'), onPressed: _busy ? null : _publish, child: const Text('公開')),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
            child: TextField(key: const ValueKey('rasqPage.md.title'), controller: _title, maxLength: rasqMdTitleMax, decoration: const InputDecoration(hintText: 'タイトル')),
          ),
          if (_preview)
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, 96), children: [
                ValueListenableBuilder(valueListenable: _body, builder: (_, v, _) => RasqMarkdownView(v.text, key: const ValueKey('rasqPage.md.previewView'))),
              ]),
            )
          else ...[
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), children: [
                Padding(padding: const EdgeInsets.only(right: RasqSpacing.xs), child: ActionChip(key: const ValueKey('rasqPage.md.tool.image'), avatar: const Icon(Icons.image_outlined, size: 16), label: const Text('画像'), onPressed: _busy ? null : _insertImage)),
                for (final (label, open, close) in _snippets)
                  Padding(
                    padding: const EdgeInsets.only(right: RasqSpacing.xs),
                    child: ActionChip(key: ValueKey('rasqPage.md.tool.$label'), label: Text(label), onPressed: () => _wrap(open, close)),
                  ),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                child: TextField(
                  key: const ValueKey('rasqPage.md.body'),
                  controller: _body,
                  maxLength: rasqMdBodyMax,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(hintText: 'Markdown で書きます。@メンション / #ハッシュタグ / :絵文字: / <center> などの MFM のタグも使えます', border: InputBorder.none),
                ),
              ),
            ),
            RasqCaption('下書きはこの端末に残ります。「公開」で RASQ のページに出します', padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm)),
          ],
        ]),
      ),
    );
  }
}
