import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../settings/settings_dsl.dart';
import 'store_models.dart';
import 'store_providers.dart';

/// アップデートの設定 (D-356、ワイヤーフレーム p.8「アップデート/デプロイの設定」)。区分(SNS / アクション / ビュー)ごとに:
/// - **おまかせ**: 新しい版を入れて、**既定の版にする**(アカウントごとに指定した版はそのまま)。
/// - **インストールだけおまかせ**: 新しい版を入れて控えるだけ。既定は変えない(「アカウントごとにバージョンを設定」で選ぶ)。
/// - **全て手動で構成**: 何もしない(プラグインを管理に「更新」のチップが出る)。
/// どのモードでも、**最後に許可した内容より権限・接続先・データ・目的が広がる版 / 有料で買っていない版は自動では有効にしない**
/// (更新ログに理由を残す。比べるのは端末に記録した最後の承認で、サーバーの直前の版との差分ではない。セキュリティ確認 2026-10-09 の [8])。
enum PluginUpdateMode {
  auto('auto', 'おまかせ', '新しい版を入れて、既定の版にします(アカウントごとに指定した版はそのまま)'),
  installOnly('installOnly', 'インストールだけおまかせ', '新しい版を入れておくだけで、使う版は変えません'),
  manual('manual', '全て手動で構成', '自動では何もしません(プラグインを管理から入れます)');

  const PluginUpdateMode(this.wire, this.label, this.description);
  final String wire;
  final String label;
  final String description;
  static PluginUpdateMode fromWire(Object? w) => values.where((m) => m.wire == w).firstOrNull ?? PluginUpdateMode.installOnly;
}

/// アップデートの設定の区分(ワイヤーフレームのタブ)。
enum PluginUpdateGroup {
  sns('sns', 'SNSプラグイン'),
  action('action', 'アクションプラグイン'),
  view('view', 'ビュープラグイン');

  const PluginUpdateGroup(this.wire, this.label);
  final String wire;
  final String label;

  static PluginUpdateGroup of(StorePluginType t) => switch (t) {
        StorePluginType.sns => sns,
        StorePluginType.viewer || StorePluginType.theme || StorePluginType.assets => view,
        _ => action,
      };
}

/// 設定の領域(KV `store.updates.v1`): `mode.<区分>` / `popup`(アップデート後の起動時にポップアップを表示、既定 on)。
const pluginUpdateArea = 'store.updates';

final pluginUpdateModeProvider = Provider.family<PluginUpdateMode, PluginUpdateGroup>((ref, g) => PluginUpdateMode.fromWire(ref.watch(settingsAreaProvider(pluginUpdateArea)).value?['mode.${g.wire}']));
final pluginUpdatePopupProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(pluginUpdateArea)).value?['popup'] != false);

/// 更新ログの 1 行。
@immutable
class PluginUpdateLogEntry {
  const PluginUpdateLogEntry({required this.pluginId, required this.name, required this.from, required this.to, required this.at, required this.result, this.note});
  final String pluginId;
  final String name;
  final String from;
  final String to;
  final DateTime at;

  /// `activated`(入れて既定に)/ `installed`(入れただけ)/ `switched`(入っていた版を既定に)/ `skipped`(理由は [note])/ `failed`。
  final String result;
  final String? note;

  bool get changed => result == 'activated' || result == 'installed' || result == 'switched';

  String get summary => switch (result) {
        'activated' => '$from → $to(既定の版にしました)',
        'installed' => '$to を入れました(使う版は $from のまま)',
        'switched' => '$from → $to(入っていた版を既定に)',
        'skipped' => '$to は自動では入れません${note == null ? '' : '($note)'}',
        _ => '$to を入れられませんでした${note == null ? '' : '($note)'}',
      };

  Map<String, Object?> toJson() => {'pluginId': pluginId, 'name': name, 'from': from, 'to': to, 'at': at.toIso8601String(), 'result': result, 'note': ?note};
  factory PluginUpdateLogEntry.fromJson(Map<String, Object?> j) => PluginUpdateLogEntry(
        pluginId: '${j['pluginId']}',
        name: '${j['name'] ?? j['pluginId']}',
        from: '${j['from'] ?? ''}',
        to: '${j['to'] ?? ''}',
        at: DateTime.tryParse('${j['at']}') ?? DateTime.fromMillisecondsSinceEpoch(0),
        result: '${j['result'] ?? 'failed'}',
        note: j['note'] as String?,
      );
}

/// 更新ログ(KV `store.updateLog.v1` の `list`、新しい順に 100 件まで)。
const pluginUpdateLogArea = 'store.updateLog';

final pluginUpdateLogProvider = Provider<List<PluginUpdateLogEntry>>((ref) {
  final raw = ref.watch(settingsAreaProvider(pluginUpdateLogArea)).value?['list'];
  if (raw is! String) return const [];
  try {
    return [for (final j in jsonDecode(raw) as List) if (j is Map) PluginUpdateLogEntry.fromJson(j.cast<String, Object?>())];
  } catch (_) {
    return const [];
  }
});

Future<void> _appendLog(ProviderContainer ref, List<PluginUpdateLogEntry> entries) async {
  if (entries.isEmpty) return;
  final area = await ref.read(settingsAreaProvider(pluginUpdateLogArea).future);
  var old = <PluginUpdateLogEntry>[];
  try {
    old = [for (final j in jsonDecode(area['list'] as String? ?? '[]') as List) if (j is Map) PluginUpdateLogEntry.fromJson(j.cast<String, Object?>())];
  } catch (_) {}
  final next = [...entries, ...old].take(100).toList();
  await ref.read(settingsAreaProvider(pluginUpdateLogArea).notifier).set('list', jsonEncode([for (final e in next) e.toJson()]));
}

/// インストール済みを 1 回見て、設定どおりにアップデートする。戻り値 = このとき書いた更新ログ(スキップも含む)。
/// 起動時([pluginAutoUpdateProvider])と、設定画面の「いま確かめる」から。
Future<List<PluginUpdateLogEntry>> runPluginUpdates(ProviderContainer ref) async {
  await ref.read(settingsAreaProvider('store.installed').future);
  await ref.read(settingsAreaProvider(pluginUpdateArea).future);
  final client = ref.read(storeClientProvider);
  final notifier = ref.read(installedPluginsProvider.notifier);
  final out = <PluginUpdateLogEntry>[];
  for (final p in [...ref.read(installedPluginsProvider)]) {
    final StorePluginDetail? detail;
    try {
      detail = await client.plugin(p.id);
    } catch (_) {
      continue; // つながらない / 消えた掲載は、次の起動で
    }
    if (detail == null || detail.version.isEmpty) continue;
    final latest = detail.version;
    // 新しい版のときだけ(ストアの現在版が古い / 同じなら何もしない、REC-10)。
    if (!isNewerVersion(latest, p.version)) continue;
    final group = PluginUpdateGroup.of(detail.pluginType != StorePluginType.other ? detail.pluginType : p.pluginType);
    final mode = ref.read(pluginUpdateModeProvider(group));
    if (mode == PluginUpdateMode.manual) continue;
    PluginUpdateLogEntry log(String result, [String? note]) => PluginUpdateLogEntry(pluginId: p.id, name: p.name.isEmpty ? p.id : p.name, from: p.version, to: latest, at: DateTime.now(), result: result, note: note);
    // 入っていた版なら、おまかせは既定に切り替えるだけ。インストールだけなら何もしない。
    // 「インストールだけ」で控えた版も、最後の承認より広がるなら切り替えない。
    if (p.versionInfo(latest) != null) {
      if (mode == PluginUpdateMode.auto) {
        final widened = notifier.versionWidening(p.id, latest);
        if (widened.isNotEmpty) {
          out.add(log('skipped', scopeWidenedMessage(p.approvedScope, widened)));
          continue;
        }
        final error = await notifier.setDefaultVersion(p.id, latest);
        out.add(error == null ? log('switched') : log('failed', error));
      }
      continue;
    }
    if (detail.needsPurchase) {
      out.add(log('skipped', '購入が必要です'));
      continue;
    }
    // 広がる版は自動では有効にしない(ユーザーが確認シートで見てから)。
    // 判断は [InstalledPlugins.install] が、選んだ版の配布物から読んだ内容と、端末に記録した最後の承認を比べてする
    // (サーバーのリリース情報の `permissionsAdded` は直前の公開版との差分なので、版を飛ばすと空になる。判断に使わない)。
    // 配布物を確かめられなければ install が失敗し、何も変えない(TERMS-09)。
    final outcome = await notifier.install(p.id, version: latest, activate: mode == PluginUpdateMode.auto);
    if (outcome.widened.isNotEmpty) {
      out.add(log('skipped', outcome.error));
      continue;
    }
    out.add(outcome.error == null ? log(mode == PluginUpdateMode.auto ? 'activated' : 'installed') : log('failed', outcome.error));
  }
  await _appendLog(ref, out);
  return out;
}

/// 起動時の自動アップデートを動かすか(テストでは動かさない。テストは上書きして確かめる)。
final pluginAutoUpdateEnabledProvider = Provider<bool>((ref) => kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST'));

/// 起動時に 1 回 (D-356): 少し待ってから([runPluginUpdates])、変わったものがあり「ポップアップを表示」なら知らせる。
final pluginAutoUpdateProvider = Provider<void>((ref) {
  if (!ref.watch(pluginAutoUpdateEnabledProvider)) return;
  var disposed = false;
  ref.onDispose(() => disposed = true);
  Future<void>.delayed(const Duration(seconds: 5), () async {
    if (disposed) return;
    try {
      final entries = await runPluginUpdates(ref.container);
      if (disposed) return;
      await showPluginUpdatePopup(ref.read(overlayManagerProvider), ref.read(routerProvider), entries, enabled: ref.read(pluginUpdatePopupProvider));
    } catch (e) {
      debugPrint('plugin updates: $e');
    }
  });
});

/// アップデート後のポップアップ(変わったものがあるときだけ)。「更新ログ」でログのページへ。
Future<void> showPluginUpdatePopup(OverlayManager manager, GoRouter router, List<PluginUpdateLogEntry> entries, {required bool enabled}) async {
  final changed = [for (final e in entries) if (e.changed) e];
  if (!enabled || changed.isEmpty) return;
  final showLog = await manager.showAlert(
    id: 'store.updates.popup',
    title: 'プラグインをアップデートしました',
    message: [for (final e in changed) '${e.name}: ${e.summary}'].join('\n'),
    confirmText: '更新ログ',
    cancelText: '閉じる',
  );
  if (showLog) router.push(Routes.storeUpdateLog);
}
