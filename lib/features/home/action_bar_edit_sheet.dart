import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../app/providers.dart';
import '../settings/settings_dsl.dart';
import '../store/store_providers.dart';
import 'action_bar_config.dart';
import 'material_icons.dart';
import 'plugin_actions.dart';
import 'post_row.dart';

/// 「アクションバーの編集」FOW (D-208 → D-210、ワイヤーフレーム p.7)。
///
/// 上から **アカウントタイル** / **全画面アクションバー**(ビューワー)の編集 / **投稿アクションバー**の編集。
/// 各バーは Android のホーム画面の編集のように少し大きいタイルを並べ、左上の (…)(アイコン本体の shift +
/// クリック / 右クリックでも)でドロップダウン: 詳細(バンドルには無い、RRL で描く FOW)/ アクションリスト化
/// (設定 FOW)/ リストの設定 / リストの解除 / 削除(プラグインボタンだけ)。
/// **押したまま動かす**と: 隙間で並び替え、別のアイコンの上で離すと新規バンドル(設定 FOW へ)、バンドルの上で
/// 離すとそのバンドルに入って設定 FOW。SNS のボタンも削除できる(強制配置の廃止 D-215、(+) の検索から戻す)。
/// 宣言されたプラグインボタン / 束ねる閾値は設定 →「SNSプラグイン」→「プラグインボタン」へ移動 (D-210)。
const actionBarEditFowId = 'actionbar.edit';
const actionBarPluginSearchFowId = 'actionbar.plugins';
const actionBarPluginSearchKey = Key('actionbar.plugins.search');
const actionBarBundleFowId = 'actionbar.bundle';
const actionBarDetailFowId = 'actionbar.detail';

/// バー(面)の種類 (D-210): 投稿タイル / 全画面ビューワー / 加工画面の下段バー(画像・動画、D-249)。
enum ActionBarSurface {
  post('', '投稿アクションバー'),
  viewer('.viewer', '全画面アクションバー'),
  editorImage('.editor.image', '加工画面のバー(画像)'),
  editorVideo('.editor.video', '加工画面のバー(動画 / 音声)'),
  rasqPost('.rasq', 'RASQ の投稿のバー');

  const ActionBarSurface(this.keySuffix, this.title);

  /// タイル / 隙間のキーの接尾辞。
  final String keySuffix;
  final String title;
  bool get isEditor => this == editorImage || this == editorVideo;

  /// 土台が SNS のアクションではないバー(加工画面 / RASQ の投稿。D-279)。
  bool get isBuiltin => isEditor || this == rasqPost;
}

String actionBarConfigKey(ActionBarSurface surface, String accountKey) => switch (surface) {
      ActionBarSurface.post => accountKey,
      ActionBarSurface.viewer => ActionBarConfigStore.viewerKey(accountKey),
      ActionBarSurface.editorImage => editorImageConfigKey,
      ActionBarSurface.editorVideo => editorVideoConfigKey,
      ActionBarSurface.rasqPost => rasqPostConfigKey,
    };

/// タイルの大きさ (D-208: 少し大型化)。
const actionBarTileSize = 56.0;

/// [surfaces] を渡すとそのバーだけ(加工画面から開くとき)。既定は全部。
/// [accountKey] = どのアカウントのバーを編集するか (D-284)。投稿の … から開くときは、**その投稿が流れてきたアカウント**(総合 TL では、
/// 表示中のアカウントとは限らない)。null = 表示中のアカウント。
Future<void> showActionBarEditSheet(WidgetRef ref, {int column = 0, List<ActionBarSurface>? surfaces, String? accountKey}) async {
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains(actionBarEditFowId)) return;
  await manager.showFow<void>(
    id: actionBarEditFowId,
    spec: FowSpec(title: 'アクションバーの編集', cancelText: '閉じる', initialHeightFactor: 0.85, maxHeightFactor: 0.92, maxWidth: 640, columnIndex: column),
    semanticsLabel: 'アクションバーの編集',
    builder: (_, _) => _ActionBarEditBody(surfaces: surfaces, accountKey: accountKey),
  );
}

// ── 検索 FOW ──────────────────────────────────────────────────────────

/// プラグインボタン / アクションを検索する FOW (D-176 → D-210: 「ノードを検索」に近い作り)。
/// 登録済みプラグインの `post.action` 宣言と SNS のアクションから選ぶ。戻りは選んだ id(キャンセルは null)。
Future<String?> showActionSearchFow(WidgetRef ref, {String title = 'プラグインを検索', Set<String> exclude = const {}, bool pluginsOnly = false, String? ownerId, String configKey = '', List<ActionDescriptor>? snsCandidates}) async {
  final manager = ref.read(overlayManagerProvider);
  // 全画面バーの構成 (D-214) なら全画面表示プラグイン(QR コード検出など)のトグルも候補。
  final plugins = ref.read(pluginActionsForProvider(configKey));
  // SNS のボタン: 指定があればそれ(バーから外したもの、D-215)。無ければ現在のアカウントの全部(pluginsOnly なら無し)。
  final sns = snsCandidates ?? (pluginsOnly ? const <ActionDescriptor>[] : (isBuiltinConfigKey(configKey) ? builtinActionsFor(configKey) : (ref.read(sessionForAccountProvider(accountKeyOfConfigKey(configKey)))?.actions ?? const <ActionDescriptor>[])));
  final query = TextEditingController();
  var genre = 'すべて';
  try {
    return await manager.showFow<String>(
      id: actionBarPluginSearchFowId,
      ownerId: ownerId,
      spec: FowSpec(title: title, cancelText: 'キャンセル', initialHeightFactor: 0.8, maxWidth: 640),
      semanticsLabel: title,
      builder: (ctx, _) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final scheme = Theme.of(ctx).colorScheme;
          final q = query.text.trim().toLowerCase();
          final rows = <({String id, String label, String subtitle, String genre, IconData icon})>[
            for (final a in sns)
              if (!exclude.contains(a.id)) (id: a.id, label: a.label, subtitle: '${isEditorConfigKey(configKey) ? '内蔵の編集' : configKey == rasqPostConfigKey ? 'RASQ のアクション' : 'SNS のアクション'} · ${a.genreTag}', genre: a.genreTag, icon: PostRow.iconFor(a.icon, Icons.circle_outlined)),
            for (final p in plugins)
              if (!exclude.contains(p.id))
                (
                  id: p.id,
                  label: p.decl.label,
                  subtitle: isViewerToggleActionId(p.id) ? '${p.plugin.manifest.name} · 全画面表示プラグイン(ON / OFF のボタン)' : '${p.plugin.manifest.name} · タグ: ${p.decl.tags.join(' / ')}',
                  genre: p.decl.tags.isEmpty ? 'Plugin' : p.decl.tags.first,
                  icon: PostRow.iconFor(p.decl.icon, Icons.extension_outlined),
                ),
          ];
          final genres = ['すべて', ...{for (final r in rows) r.genre}];
          final hits = [
            for (final r in rows)
              if ((genre == 'すべて' || r.genre == genre) && (q.isEmpty || r.label.toLowerCase().contains(q) || r.subtitle.toLowerCase().contains(q))) r,
          ];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
              child: RasqInput(key: actionBarPluginSearchKey, controller: query, hintText: 'ボタン名 / プラグイン名 / タグ', onChanged: (_) => setLocal(() {})),
            ),
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), children: [
                for (final g in genres)
                  Padding(
                    padding: const EdgeInsets.only(right: RasqSpacing.xs),
                    child: ChoiceChip(key: ValueKey('actionbar.search.genre.$g'), label: Text(g, style: RasqTypography.caption), selected: genre == g, onSelected: (_) => setLocal(() => genre = g)),
                  ),
              ]),
            ),
            Expanded(
              child: hits.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(RasqSpacing.page),
                      child: Text(rows.isEmpty ? (isEditorConfigKey(configKey) ? 'composer.media を宣言したプラグインがありません(ストアから追加)' : configKey.startsWith('viewer:') ? '全画面表示プラグイン / post.action を宣言したプラグインがありません(ストアから追加)' : 'post.action を宣言したプラグインがありません(ストアから追加)') : '見つかりません', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
                    )
                  : ListView(children: [
                      for (final r in hits)
                        RasqListTile(
                          key: ValueKey('actionbar.plugin.${r.id}'),
                          leading: Icon(r.icon, size: 22, color: scheme.onSurface),
                          title: r.label,
                          subtitle: r.subtitle,
                          onTap: () => manager.close(actionBarPluginSearchFowId, result: r.id),
                        ),
                    ]),
            ),
          ]);
        },
      ),
    );
  } finally {
    query.dispose();
  }
}

/// 旧 API 互換 (D-176): プラグインボタンだけを選ぶ。
Future<PluginAction?> showPluginActionSearchFow(WidgetRef ref, {String title = 'プラグインボタンを検索', String? ownerId}) async {
  final id = await showActionSearchFow(ref, title: title, pluginsOnly: true, ownerId: ownerId);
  if (id == null) return null;
  return ref.read(pluginActionsProvider).where((p) => p.id == id).firstOrNull;
}

// ── 詳細 FOW(RRL) ────────────────────────────────────────────────────

/// アクションの詳細 FOW (D-210): RRL で描く。上部はプラグインストアのページの使い回し(アイコン / 名前 / 提供元 /
/// 評価)、下にアクションの詳細(id / スロット / 確認 / 自動化 / タグ / 説明)。
Future<void> showActionDetailFow(WidgetRef ref, {required ActionDescriptor action, required String pluginId, required String pluginName, String? description, List<String> tags = const []}) async {
  final manager = ref.read(overlayManagerProvider);
  await manager.showFow<void>(
    id: actionBarDetailFowId,
    spec: FowSpec(title: action.label, cancelText: '閉じる', initialHeightFactor: 0.7, maxWidth: 600),
    semanticsLabel: 'アクションの詳細',
    builder: (ctx, _) => Consumer(
      builder: (ctx, ref, _) {
        final store = ref.watch(storePluginProvider(pluginId)).value;
        final node = actionDetailRrl(action: action, pluginId: pluginId, pluginName: store?.name ?? pluginName, developer: store == null ? null : (store.developerName.isEmpty ? '提供元不明' : store.developerName), iconUrl: store?.iconUrl, rating: store?.rating, downloads: store?.downloads, summary: store?.summary ?? description, tags: tags);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.lg),
          child: RrlRenderer(key: const ValueKey('actionbar.detail.rrl'), node: node, host: RrlHost(instanceScope: 'host:actionbar:detail', scope: RrlScope({}))),
        );
      },
    ),
  );
}

/// 詳細 FOW の RRL 木(テストで形を確かめる)。
RrlNode actionDetailRrl({required ActionDescriptor action, required String pluginId, required String pluginName, String? developer, Uri? iconUrl, double? rating, int? downloads, String? summary, List<String> tags = const []}) {
  RrlNode text(String k, String s, {bool bold = false, double? size, String? color}) => RrlNode(t: 'Text', k: k, p: {'text': s, 'bold': bold, 'size': ?size, 'color': ?color});
  return RrlNode(t: 'Column', k: 'detail', c: [
    // ── ストアのページの見出し部(使い回し) ──
    RrlNode(t: 'Row', k: 'head', c: [
      iconUrl != null ? RrlNode(t: 'Image', k: 'icon', p: {'src': iconUrl.toString(), 'width': 56, 'height': 56}) : const RrlNode(t: 'Icon', k: 'icon', p: {'icon': 'extension', 'size': 40}),
      RrlNode(t: 'Column', k: 'title', c: [
        text('name', pluginName, bold: true, size: 18),
        text('dev', developer ?? pluginId, color: '#6B7280'),
        if (rating != null) text('stat', '★${rating.toStringAsFixed(1)} ・ ${downloads ?? 0} DL', color: '#6B7280', size: 12),
      ]),
    ]),
    if (summary != null && summary.isNotEmpty) text('summary', summary),
    const RrlNode(t: 'SectionHeader', k: 'sec', p: {'title': 'アクション'}),
    RrlNode(t: 'ListTile', k: 'label', p: {'title': action.label, 'subtitle': 'id: ${action.id}'}),
    RrlNode(t: 'ListTile', k: 'slot', p: {'title': 'スロット(ジャンル)', 'subtitle': action.genreTag}),
    RrlNode(t: 'ListTile', k: 'confirm', p: {'title': '確認', 'subtitle': action.confirmMode.name}),
    RrlNode(t: 'ListTile', k: 'auto', p: {'title': '自動化', 'subtitle': action.automation.name}),
    if (tags.isNotEmpty) RrlNode(t: 'ListTile', k: 'tags', p: {'title': 'タグ', 'subtitle': tags.join(' / ')}),
  ]);
}

// ── バンドルの設定 FOW ──────────────────────────────────────────────

/// バンドルの写真アイコンの置き場 (D-212): 選んだ画像はここへコピーして `file:<path>` で持つ(image_picker の一時
/// ファイルは消えるため)。テストでは差し替える。
final bundleIconDirProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/action_icons');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      return dir;
    });

/// 写真の選択 (D-212): 既定は image_picker のギャラリー。テストでは差し替える。
final bundlePhotoPickerProvider = Provider<Future<XFile?> Function()>((ref) => () => ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256));

/// Material Icon のピッカー FOW (D-212、絵文字ピッカーの流用): 検索 + グリッド。戻りは名前(キャンセルは null)。
const materialIconPickerFowId = 'actionbar.icon.picker';

Future<String?> showMaterialIconPickerFow(WidgetRef ref, {String? initial, String? ownerId}) async {
  final manager = ref.read(overlayManagerProvider);
  final query = TextEditingController();
  try {
    return await manager.showFow<String>(
      id: materialIconPickerFowId,
      ownerId: ownerId,
      spec: FowSpec(title: 'Material Icon', cancelText: 'キャンセル', initialHeightFactor: 0.7, maxWidth: 600),
      semanticsLabel: 'Material Icon',
      builder: (ctx, _) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final scheme = Theme.of(ctx).colorScheme;
          final q = query.text.trim().toLowerCase();
          final names = [for (final n in materialIconsByName.keys) if (q.isEmpty || n.contains(q)) n];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
              child: RasqInput(key: const ValueKey('actionbar.icon.search'), controller: query, hintText: 'アイコン名で検索(例: star, bolt)', onChanged: (_) => setLocal(() {})),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.sm),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 76, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 0.85),
                itemCount: names.length,
                itemBuilder: (_, i) {
                  final n = names[i];
                  final selected = n == initial;
                  return InkWell(
                    key: ValueKey('actionbar.icon.$n'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => manager.close(materialIconPickerFowId, result: n),
                    child: Container(
                      decoration: BoxDecoration(color: selected ? scheme.primaryContainer : null, borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.all(4),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(materialIconsByName[n], size: 26, color: scheme.onSurface),
                        const SizedBox(height: 2),
                        Text(n, style: RasqTypography.caption.copyWith(fontSize: 9, color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]);
        },
      ),
    );
  } finally {
    query.dispose();
  }
}

/// バンドルの設定 FOW (D-210): リスト名とアイコン(バンドル内のアイコンの使い回し / Material Icon / 写真)、
/// メンバーのプラグインタイル(アイコン + プラグイン名 + 説明 2 行、ホバーで出るハンドルと … ドロップダウン)、
/// 「プラグインを検索」で足す、「リストの解除」。
Future<void> showActionBundleSettingsFow(WidgetRef ref, {required String configKey, required String listId, Future<XFile?> Function()? pickPhoto}) async {
  final manager = ref.read(overlayManagerProvider);
  final store = ref.read(actionBarConfigProvider(configKey).notifier);
  final initial = ref.read(actionBarConfigProvider(configKey)).lists.where((l) => l.id == listId).firstOrNull;
  if (initial == null) return;
  final name = TextEditingController(text: initial.name);
  try {
    await manager.showFow<void>(
      id: actionBarBundleFowId,
      spec: FowSpec(title: 'バンドルの設定', cancelText: '閉じる', initialHeightFactor: 0.85, maxWidth: 600),
      semanticsLabel: 'バンドルの設定',
      builder: (_, _) => Consumer(
        builder: (ctx, ref, _) {
          final scheme = Theme.of(ctx).colorScheme;
          final config = ref.watch(actionBarConfigProvider(configKey));
          final list = config.lists.where((l) => l.id == listId).firstOrNull;
          if (list == null) return const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: Text('解除しました'));
          // そのバーのアカウントの SNS のアクション (D-284)。
          final session = ref.watch(sessionForAccountProvider(accountKeyOfConfigKey(configKey)));
          final plugins = ref.watch(pluginActionsForProvider(configKey));
          final accountKey = slotSettingsKeyFor(configKey, accountKeyOfConfigKey(configKey) ?? ref.watch(currentAccountProvider)?.key ?? '');
          final settings = ref.watch(slotActionSettingsProvider(accountKey));
          final merged = mergePluginActions(config: config, snsActions: isBuiltinConfigKey(configKey) ? builtinActionsFor(configKey) : (session?.actions ?? const []), plugins: plugins, settings: settings);
          final byId = {for (final a in merged.actions) a.id: a};
          final memberIds = ActionListDef.uniq(list.memberIds);
          final members = [for (final id in memberIds) if (byId.containsKey(id)) byId[id]!];
          void update(ActionListDef next) => store.set(config.copyWith(lists: [for (final l in config.lists) l.id == listId ? next : l]));
          String providerOf(String id) => isPluginActionId(id) ? (plugins.where((p) => p.id == id).firstOrNull?.plugin.manifest.name ?? 'プラグイン') : 'SNS のアクション';
          String describe(String id) => isPluginActionId(id) ? (plugins.where((p) => p.id == id).firstOrNull?.plugin.manifest.description ?? '') : 'SNS プラグインが提供するアクション(${byId[id]?.genreTag ?? ''})';
          return ListView(padding: const EdgeInsets.only(bottom: RasqSpacing.lg), children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
              child: RasqInput(key: const ValueKey('actionbar.bundle.name'), controller: name, hintText: 'リスト名', onChanged: (v) => update(list.copyWith(name: v.trim().isEmpty ? list.name : v.trim()))),
            ),
            const RasqSectionHeader(title: 'アイコン'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
              child: Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
                ChoiceChip(key: const ValueKey('actionbar.bundle.icon.default'), label: const Icon(Icons.apps, size: 18), selected: list.icon == null, onSelected: (_) => update(list.copyWith(clearIcon: true))),
                // バンドル内のアイコンを使い回す。
                for (final a in members)
                  ChoiceChip(
                    key: ValueKey('actionbar.bundle.icon.member.${a.id}'),
                    label: Icon(PostRow.iconFor(a.icon, Icons.circle_outlined), size: 18),
                    tooltip: a.label,
                    selected: list.icon == 'member:${a.id}',
                    onSelected: (_) => update(list.copyWith(icon: 'member:${a.id}')),
                  ),
                // Material Icon(ピッカー、D-212)。
                ChoiceChip(
                  key: const ValueKey('actionbar.bundle.icon.material'),
                  avatar: Icon(list.icon?.startsWith('material:') ?? false ? bundleIconOf(list, members) : Icons.apps_outlined, size: 16),
                  label: Text(list.icon?.startsWith('material:') ?? false ? list.icon!.substring('material:'.length) : 'Material Icon'),
                  selected: list.icon?.startsWith('material:') ?? false,
                  onSelected: (_) async {
                    final n = await showMaterialIconPickerFow(ref, initial: list.icon?.startsWith('material:') ?? false ? list.icon!.substring('material:'.length) : null, ownerId: actionBarBundleFowId);
                    if (n != null) update(list.copyWith(icon: 'material:$n'));
                  },
                ),
                // 写真 (D-212): アプリの保存領域へコピーしてから `file:` で持つ。
                ChoiceChip(
                  key: const ValueKey('actionbar.bundle.icon.photo'),
                  avatar: list.icon?.startsWith('file:') ?? false ? SizedBox(width: 18, height: 18, child: bundleIconWidget(list, members, size: 18)) : const Icon(Icons.photo_outlined, size: 16),
                  label: const Text('写真'),
                  selected: list.icon?.startsWith('file:') ?? false,
                  onSelected: (_) async {
                    final Future<XFile?> Function() pick = pickPhoto ?? ref.read(bundlePhotoPickerProvider);
                    final x = await pick();
                    if (x == null) return;
                    try {
                      final dir = await ref.read(bundleIconDirProvider)();
                      final f = File('${dir.path}/$listId.png');
                      await f.writeAsBytes(await x.readAsBytes(), flush: true);
                      update(list.copyWith(icon: 'file:${f.path}'));
                      // 同じパスの画像を差し替えたときにキャッシュが残らないように。
                      imageCache.clear();
                    } catch (e) {
                      manager.showAlert(id: 'actionbar.icon.error', title: '写真を使えません', message: '$e', confirmText: 'OK');
                    }
                  },
                ),
                SizedBox(width: 32, height: 32, child: Center(child: bundleIconWidget(list, members, size: 26, color: scheme.onSurface))),
              ]),
            ),
            const RasqSectionHeader(title: 'メンバー'),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              // onReorderItem は newIndex を取り出し後の位置で渡す(onReorder と違い自分で補正しない)。
              onReorderItem: (from, to) {
                final ids = [...list.memberIds];
                final moved = ids.removeAt(from);
                ids.insert(to.clamp(0, ids.length), moved);
                update(list.copyWith(memberIds: ids));
              },
              children: [
                for (final (i, id) in memberIds.indexed)
                  _MemberTile(
                    key: ValueKey('actionbar.bundle.member.$id'),
                    index: i,
                    icon: PostRow.iconFor(byId[id]?.icon, Icons.circle_outlined),
                    label: byId[id]?.label ?? id,
                    pluginName: providerOf(id),
                    description: describe(id),
                    onMenu: (rect) async {
                      final pick = await manager.showDropdown<String>(id: 'actionbar.bundle.member.menu', ownerId: actionBarBundleFowId, anchor: rect, dense: true, items: const [RasqDropdownItem('詳細', 'detail'), RasqDropdownItem('バンドルから外す', 'remove', destructive: true)]);
                      final a = byId[id];
                      if (pick == 'detail' && a != null) {
                        final p = plugins.where((x) => x.id == id).firstOrNull;
                        await showActionDetailFow(ref, action: a, pluginId: p?.plugin.id ?? session?.pluginId ?? '', pluginName: providerOf(id), description: p?.plugin.manifest.description, tags: p?.decl.tags ?? const []);
                      } else if (pick == 'remove') {
                        final ids = [...list.memberIds]..remove(id);
                        // 外したものはバンドルの後ろに戻す。
                        final order = [...config.order];
                        final at = order.indexOf(ActionBarConfig.listKey(list.id));
                        order.insert(at < 0 ? order.length : at + 1, id);
                        store.set(config.copyWith(order: order, lists: [for (final l in config.lists) l.id == listId ? l.copyWith(memberIds: ids) : l]));
                      }
                    },
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(RasqSpacing.md),
              child: Wrap(spacing: RasqSpacing.sm, alignment: WrapAlignment.spaceBetween, children: [
                TextButton.icon(
                  key: const ValueKey('actionbar.bundle.search'),
                  onPressed: () async {
                    final id = await showActionSearchFow(ref, exclude: list.memberIds.toSet(), ownerId: actionBarBundleFowId, configKey: configKey);
                    if (id == null) return;
                    if (isPluginActionId(id)) await ref.read(settingsAreaProvider(slotSettingsArea(accountKey)).notifier).set('enabled', {...settings.enabled, id: true});
                    final order = [...config.order]..remove(id);
                    // バーから外していたボタンをバンドルに入れたら戻す (D-215)。
                    store.set(config.copyWith(order: order, hidden: {...config.hidden}..remove(id), lists: [for (final l in config.lists) l.id == listId ? l.copyWith(memberIds: [...l.memberIds, id]) : l]));
                  },
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('プラグインを検索'),
                ),
                TextButton(
                  key: const ValueKey('actionbar.bundle.dissolve'),
                  onPressed: () {
                    final order = [...config.order];
                    final at = order.indexOf(ActionBarConfig.listKey(list.id));
                    order.remove(ActionBarConfig.listKey(list.id));
                    order.insertAll(at < 0 ? order.length : at, list.memberIds);
                    store.set(config.copyWith(order: order, lists: [for (final l in config.lists) if (l.id != listId) l]));
                    manager.close(actionBarBundleFowId);
                  },
                  child: const Text('リストの解除'),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  } finally {
    name.dispose();
  }
}

/// プラグインタイル (D-210): 縦方向のアイコン + プラグイン名 + 説明(2 行)。ホバーでハンドルが出る。… はドロップダウン。
class _MemberTile extends StatefulWidget {
  const _MemberTile({super.key, required this.index, required this.icon, required this.label, required this.pluginName, required this.description, required this.onMenu});
  final int index;
  final IconData icon;
  final String label;
  final String pluginName;
  final String description;
  final ValueChanged<Rect> onMenu;
  @override
  State<_MemberTile> createState() => _MemberTileState();
}

class _MemberTileState extends State<_MemberTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.sm, RasqSpacing.xs),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(10)), child: Icon(widget.icon, size: 22, color: scheme.onSurface)),
            const SizedBox(height: 2),
            SizedBox(width: 64, child: Text(widget.label, style: RasqTypography.caption, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(width: RasqSpacing.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.pluginName, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              Text(widget.description, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          ),
          // ホバーハンドル(タッチでは常に薄く出す)。
          ReorderableDragStartListener(index: widget.index, child: AnimatedOpacity(duration: const Duration(milliseconds: 120), opacity: _hover ? 1 : 0.35, child: Icon(Icons.drag_handle, size: 20, color: scheme.onSurfaceVariant))),
          Builder(
            builder: (ctx) => RasqIconButton(
              icon: Icons.more_horiz,
              size: 20,
              tooltip: 'メンバーの操作',
              onPressed: () {
                final box = ctx.findRenderObject() as RenderBox;
                widget.onMenu(box.localToGlobal(Offset.zero) & box.size);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 編集 FOW の本体 ──────────────────────────────────────────────────

class _ActionBarEditBody extends ConsumerWidget {
  const _ActionBarEditBody({this.surfaces, this.accountKey});
  final List<ActionBarSurface>? surfaces;
  final String? accountKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // 編集するアカウント (D-284): 指定があればそれ(投稿が流れてきたアカウント)、無ければ表示中のアカウント。
    final picked = this.accountKey == null ? null : ref.watch(sessionsProvider).value?.allSessions.where((s) => s.account.key == this.accountKey).firstOrNull;
    final current = ref.watch(currentUserProvider);
    final me = picked == null ? current : UserSummary(id: current.id, account: picked.account, displayName: picked.displayName ?? picked.account.handle, avatarUrl: picked.avatarUrl);
    final accountKey = picked?.account.key ?? ref.watch(currentAccountProvider)?.key ?? '';
    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── アカウントタイル ──
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
          child: Row(key: const ValueKey('actionbar.account'), children: [
            RasqAvatar(imageUrl: me.avatarUrl, fallbackLabel: me.displayName, size: 40),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(me.displayName, style: RasqTypography.body.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Row(children: [
                  Flexible(child: Text('@${me.account.handle}', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 4),
                  RasqSnsPill(account: me.account),
                ]),
              ]),
            ),
          ]),
        ),
        // ── バーごとの編集(全画面 → 投稿 → 加工画面)──
        for (final surface in surfaces ?? const [ActionBarSurface.viewer, ActionBarSurface.post, ActionBarSurface.editorImage, ActionBarSurface.editorVideo, ActionBarSurface.rasqPost]) ...[
          RasqSectionHeader(title: surface.title),
          _ActionBarTiles(key: ValueKey('actionbar.surface.${surface.name}'), surface: surface, accountKey: accountKey),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.lg),
          child: Text('(…) / shift + クリック / 右クリックでメニュー。長押しして動かすと並び替え、別のアイコンの上で離すとバンドル。宣言されたプラグインボタンと束ねる閾値は 設定 → SNSプラグイン →「プラグインボタン」。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
      ]),
    );
  }
}

/// 1 本のバーの編集(タイル列)。[surface] ごとに構成が違う (D-210)。
class _ActionBarTiles extends ConsumerStatefulWidget {
  const _ActionBarTiles({super.key, required this.surface, required this.accountKey});
  final ActionBarSurface surface;
  final String accountKey;
  @override
  ConsumerState<_ActionBarTiles> createState() => _ActionBarTilesState();
}

class _ActionBarTilesState extends ConsumerState<_ActionBarTiles> {
  /// ドラッグ中のキー(隙間を広げて落としやすくする)。
  String? _dragging;

  static String keyOf(ActionBarEntry e) => switch (e) {
        SingleActionEntry() => e.action.id,
        ActionListEntry() => ActionBarConfig.listKey(e.list.id),
      };

  String get _sfx => widget.surface.keySuffix;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = ref.watch(sessionForAccountProvider(widget.accountKey.isEmpty ? null : widget.accountKey));
    final registry = ref.watch(pluginRegistryProvider);
    final accountKey = widget.accountKey;
    final configKey = actionBarConfigKey(widget.surface, accountKey);
    final config = ref.watch(actionBarConfigProvider(configKey));
    final store = ref.read(actionBarConfigProvider(configKey).notifier);
    final manager = ref.read(overlayManagerProvider);
    // 加工画面のバーの土台は内蔵の編集(SNS のアクションではない)。プラグインボタンの有効 / 無効は `slots.editor`。
    final isEditor = widget.surface.isEditor;
    final snsActions = widget.surface.isBuiltin ? builtinActionsFor(configKey) : (session?.actions ?? const <ActionDescriptor>[]);
    final plugins = ref.watch(pluginActionsForProvider(configKey));
    final settingsKey = slotSettingsKeyFor(configKey, accountKey);
    final settings = ref.watch(slotActionSettingsProvider(settingsKey));
    final settingsStore = ref.read(settingsAreaProvider(slotSettingsArea(settingsKey)).notifier);
    // 表示中のバーと同じ合成(プラグインボタン込み)。
    final merged = mergePluginActions(config: config, snsActions: snsActions, plugins: plugins, settings: settings);
    final actions = merged.actions;
    final entries = merged.config.apply(actions);
    final pluginName = isEditor ? 'RASQ(内蔵の編集)' : widget.surface == ActionBarSurface.rasqPost ? 'RASQ' : (registry.plugins.where((p) => p.manifest.id == session?.pluginId).firstOrNull?.manifest.name ?? session?.pluginId ?? '');
    String providerOf(ActionDescriptor a) => isPluginActionId(a.id) ? (plugins.where((p) => p.id == a.id).firstOrNull?.plugin.manifest.name ?? 'プラグイン') : pluginName;
    Future<void> setEnabled(String id, bool on) => settingsStore.set('enabled', {...settings.enabled, id: on});

    /// 自動バンドルは並べ替え / 編集で固定リストに昇格する(order に残せるように)。
    List<ActionListDef> listsWithAuto() {
      final lists = [...config.lists];
      for (final e in entries) {
        if (e is ActionListEntry && !lists.any((l) => l.id == e.list.id)) lists.add(e.list);
      }
      return lists;
    }

    List<String> orderOf() => [for (final e in entries) keyOf(e)];

    void reorder(String key, int gap) {
      final ids = orderOf();
      final from = ids.indexOf(key);
      if (from < 0) return;
      ids.removeAt(from);
      final to = (gap > from ? gap - 1 : gap).clamp(0, ids.length);
      ids.insert(to, key);
      store.set(config.copyWith(order: ids, lists: listsWithAuto()));
    }

    /// 新規バンドル (D-210): 先頭メンバーの位置に置いて設定 FOW を開く。
    Future<void> newBundle(List<String> memberIds) async {
      final def = ActionListDef(id: DateTime.now().millisecondsSinceEpoch.toRadixString(36), name: 'マイリスト', memberIds: ActionListDef.uniq(memberIds));
      final order = orderOf();
      final first = order.indexWhere(memberIds.contains);
      order.removeWhere(memberIds.contains);
      order.insert(first < 0 ? order.length : first.clamp(0, order.length), ActionBarConfig.listKey(def.id));
      store.set(config.copyWith(lists: [...listsWithAuto(), def], order: order));
      await showActionBundleSettingsFow(ref, configKey: configKey, listId: def.id);
    }

    /// バンドルに入れる(自動バンドルは固定に昇格)→ 設定 FOW。
    Future<void> addToBundle(ActionListDef list, String memberId) async {
      final lists = listsWithAuto();
      final i = lists.indexWhere((l) => l.id == list.id);
      if (i < 0 || list.memberIds.contains(memberId)) return;
      lists[i] = list.copyWith(memberIds: [...list.memberIds, memberId]);
      final order = orderOf()..remove(memberId);
      store.set(config.copyWith(lists: lists, order: order));
      await showActionBundleSettingsFow(ref, configKey: configKey, listId: list.id);
    }

    Future<void> menuFor(BuildContext ctx, ActionBarEntry e) async {
      final box = ctx.findRenderObject() as RenderBox;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      switch (e) {
        case SingleActionEntry():
          final a = e.action;
          final isPlugin = isPluginActionId(a.id);
          final pick = await manager.showDropdown<String>(
            id: 'actionbar.action.menu',
            ownerId: actionBarEditFowId,
            anchor: rect,
            dense: true,
            items: [
              const RasqDropdownItem('詳細', 'detail'),
              const RasqDropdownItem('アクションリスト化', 'bundle'),
              const RasqDropdownItem('削除', 'delete', destructive: true),
            ],
          );
          switch (pick) {
            case 'detail':
              final p = plugins.where((x) => x.id == a.id).firstOrNull;
              await showActionDetailFow(ref, action: a, pluginId: p?.plugin.id ?? session?.pluginId ?? '', pluginName: providerOf(a), description: p?.plugin.manifest.description, tags: p?.decl.tags ?? const []);
            case 'bundle':
              await newBundle([a.id]);
            case 'delete':
              // プラグインボタンはスロット設定で無効に。SNS のボタンは構成の hidden へ(強制配置の廃止、D-215:
              // (+) の検索から戻せる)。
              if (isPlugin) {
                await setEnabled(a.id, false);
              } else {
                store.set(config.copyWith(hidden: {...config.hidden, a.id}, order: orderOf()..remove(a.id), lists: listsWithAuto()));
              }
          }
        case ActionListEntry():
          final auto = e.list.id.startsWith('auto:');
          final pick = await manager.showDropdown<String>(
            id: 'actionbar.list.menu',
            ownerId: actionBarEditFowId,
            anchor: rect,
            dense: true,
            items: [
              const RasqDropdownItem('アクションリストの設定', 'edit'),
              if (auto) const RasqDropdownItem('固定リストにする', 'pin'),
              const RasqDropdownItem('リストの解除', 'dissolve', destructive: true),
            ],
          );
          switch (pick) {
            case 'edit':
              if (auto) store.set(config.copyWith(lists: listsWithAuto()));
              await showActionBundleSettingsFow(ref, configKey: configKey, listId: e.list.id);
            case 'pin':
              store.set(config.copyWith(lists: listsWithAuto()));
            case 'dissolve':
              // 解除: 中身はバンドルの位置に戻る(非表示にはしない)。
              final order = orderOf();
              final at = order.indexOf(keyOf(e));
              order.remove(keyOf(e));
              order.insertAll(at < 0 ? order.length : at, e.list.memberIds);
              store.set(config.copyWith(order: order, lists: [for (final l in listsWithAuto()) if (l.id != e.list.id) l]));
          }
      }
    }

    Widget tile(ActionBarEntry e) {
      final key = keyOf(e);
      final label = switch (e) {
        SingleActionEntry() => e.action.label,
        ActionListEntry() => e.list.name,
      };
      final face = Container(
        width: actionBarTileSize,
        height: actionBarTileSize,
        decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
        alignment: Alignment.center,
        child: switch (e) {
          SingleActionEntry() => Icon(PostRow.iconFor(e.action.icon, Icons.circle_outlined), size: 28, color: scheme.onSurface),
          ActionListEntry() => bundleIconWidget(e.list, e.members, size: 28, color: scheme.onSurface),
        },
      );
      return DragTarget<String>(
        onWillAcceptWithDetails: (d) => d.data != key && d.data.startsWith('$_sfx:'),
        onAcceptWithDetails: (d) async {
          final dragged = d.data.substring(_sfx.length + 1);
          if (dragged.startsWith('list:')) return; // バンドル同士は重ねない
          switch (e) {
            case ActionListEntry():
              await addToBundle(e.list, dragged);
            case SingleActionEntry():
              await newBundle([e.action.id, dragged]);
          }
        },
        builder: (ctx, candidates, _) {
          final hot = candidates.isNotEmpty;
          return LongPressDraggable<String>(
            key: ValueKey('actionbar.tile.$key$_sfx'),
            data: '$_sfx:$key',
            delay: const Duration(milliseconds: 200),
            onDragStarted: () => setState(() => _dragging = key),
            onDragEnd: (_) => setState(() => _dragging = null),
            feedback: Material(color: Colors.transparent, child: Opacity(opacity: 0.85, child: face)),
            childWhenDragging: Opacity(opacity: 0.3, child: face),
            child: Semantics(
              label: label,
              child: GestureDetector(
                // shift + クリック / 右クリックでもメニュー (D-208)。
                onTap: () {
                  if (HardwareKeyboard.instance.isShiftPressed) menuFor(ctx, e);
                },
                onSecondaryTapUp: (_) => menuFor(ctx, e),
                child: Tooltip(
                  message: label,
                  child: SizedBox(
                    width: actionBarTileSize + 12,
                    height: actionBarTileSize + 12,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned(left: 8, top: 8, child: AnimatedScale(duration: const Duration(milliseconds: 120), scale: hot ? 1.12 : 1, child: face)),
                      // 左上の (…) (D-208)。
                      Positioned(
                        left: 0,
                        top: 0,
                        child: Builder(
                          builder: (bctx) => Material(
                            color: scheme.surface,
                            shape: const CircleBorder(),
                            elevation: 1,
                            child: InkWell(
                              key: ValueKey('actionbar.tile.menu.$key$_sfx'),
                              customBorder: const CircleBorder(),
                              onTap: () => menuFor(bctx, e),
                              child: SizedBox(width: 22, height: 22, child: Icon(Icons.more_horiz, size: 16, color: scheme.onSurface)),
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    /// 隙間 (D-208): ここに落とすと並び替え。ドラッグ中は広がる。
    Widget gap(int i) => DragTarget<String>(
          onWillAcceptWithDetails: (d) => d.data.startsWith('$_sfx:'),
          onAcceptWithDetails: (d) => reorder(d.data.substring(_sfx.length + 1), i),
          builder: (_, candidates, _) => AnimatedContainer(
            key: ValueKey('actionbar.gap.$i$_sfx'),
            duration: const Duration(milliseconds: 120),
            width: _dragging == null ? 6 : (candidates.isNotEmpty ? 28 : 18),
            height: actionBarTileSize + 12,
            alignment: Alignment.center,
            child: candidates.isNotEmpty ? Container(width: 3, height: actionBarTileSize, decoration: BoxDecoration(color: RasqColors.accent, borderRadius: BorderRadius.circular(2))) : null,
          ),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
      child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, runSpacing: RasqSpacing.xs, children: [
        // (+): プラグインを検索して足す。
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: RasqIconButton(
            key: ValueKey('actionbar.plugins.open$_sfx'),
            icon: Icons.add_circle_outline,
            size: 28,
            tooltip: 'プラグインを検索',
            onPressed: () async {
              // 候補 = バーから外した SNS のボタン (D-215) + プラグインボタン。
              final removed = [for (final a in snsActions) if (config.hidden.contains(a.id)) a];
              final id = await showActionSearchFow(ref, pluginsOnly: true, ownerId: actionBarEditFowId, configKey: configKey, snsCandidates: removed);
              if (id == null) return;
              if (config.hidden.contains(id)) {
                store.set(config.copyWith(hidden: {...config.hidden}..remove(id)));
              } else {
                await setEnabled(id, true);
              }
            },
          ),
        ),
        for (var i = 0; i < entries.length; i++) ...[gap(i), tile(entries[i])],
        gap(entries.length),
      ]),
    );
  }
}
