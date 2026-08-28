import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';

/// 設定第二階層の DSL 描画 (D-031 / D-044)。
///
/// ページの出どころは 2 つ:
/// - ホスト設定 = **wasm 不要の静的 RRL アセット**(`assets/settings/
///   <area>.rrl.json`)。保存先はアカウント毎 KV `<area>.v1`(D-035)。
/// - SNS プラグイン設定 (D-044) = プラグインが [SnsPlugin.settingsPages] で
///   提供する同形式の JSON。ルートは `/settings/dsl/sns.<短area>`、保存先は
///   KV `sns.<pluginId>.<短area>.v1`。`source: "remote"` のページは KV を
///   使わず [SnsSession.settingsRead]/[settingsWrite] でサーバーに読み書き。
///
/// 値は Bind `$.settings.<key>` で解決し、タイルの `change` イベント
/// (`on: {"change": "settings.set"}`、設定キー = ノードの `k`)を書き込みに
/// 変換する。`on: {"tap": "web.open"}` は `k` をパスとしてインスタンスの
/// web 設定を開く(パスワードが要る操作の逃がし先)。
class SettingsPageSpec {
  const SettingsPageSpec({required this.area, required this.title, required this.source, required this.defaults, required this.root});

  final String area;
  final String title;

  /// `local`(KV 保存)/ `remote`(プラグイン経由でサーバー保存)。
  final String source;

  /// 未保存キーの既定値(Bind 解決前に KV へマージされる)。
  final Map<String, Object?> defaults;
  final RrlNode root;

  bool get isRemote => source == 'remote';

  factory SettingsPageSpec.fromJson(Map<String, Object?> json) {
    if (json['schema'] != 'rasq.settings-page/1') {
      throw FormatException('unknown settings page schema: ${json['schema']}');
    }
    return SettingsPageSpec(
      area: json['area'] as String,
      title: json['title'] as String? ?? '設定',
      source: json['source'] as String? ?? 'local',
      defaults: (json['defaults'] as Map?)?.cast<String, Object?>() ?? const {},
      root: RrlNode.fromJson((json['root'] as Map).cast<String, Object?>()),
    );
  }
}

/// 現在の SNS プラグインが提供する設定ページ(短 area → spec)。壊れた
/// ページは読み飛ばす(V12: 縮退)。
final pluginSettingsPagesProvider = Provider<Map<String, SettingsPageSpec>>((ref) {
  final session = ref.watch(currentSnsSessionProvider);
  final plugin = session == null ? null : ref.watch(pluginRegistryProvider).plugin(session.pluginId);
  final out = <String, SettingsPageSpec>{};
  for (final raw in plugin?.settingsPages ?? const <String>[]) {
    try {
      final spec = SettingsPageSpec.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      out[spec.area] = spec;
    } catch (e) {
      debugPrint('settings page from ${plugin?.manifest.id} skipped: $e');
    }
  }
  return out;
});

final settingsPageSpecProvider = FutureProvider.family<SettingsPageSpec, String>((ref, area) async {
  if (area.startsWith('sns.')) {
    final short = area.substring(4);
    final spec = ref.watch(pluginSettingsPagesProvider)[short];
    if (spec == null) throw StateError('SNS プラグインが設定ページ "$short" を提供していません');
    return spec;
  }
  final raw = await rootBundle.loadString('assets/settings/$area.rrl.json');
  return SettingsPageSpec.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
});

/// 1 ページ(area)分の設定値 KV。ホスト設定は `<area>.v1`(D-035)、
/// プラグイン設定 (`sns.<短area>`) は `sns.<pluginId>.<短area>.v1`。
class SettingsAreaStore extends AsyncNotifier<Map<String, Object?>> {
  SettingsAreaStore(this.area);
  final String area;

  bool get _isPlugin => area.startsWith('sns.');
  String get _short => area.substring(4);

  String get storageKey {
    if (!_isPlugin) return '$area.v1';
    final pid = ref.read(currentSnsSessionProvider)?.pluginId ?? '-';
    return 'sns.$pid.$_short.v1';
  }

  @override
  Future<Map<String, Object?>> build() async {
    if (_isPlugin) ref.watch(currentSnsSessionProvider); // キーがプラグインに依存
    try {
      final raw = await ref.watch(sessionStorageProvider).read(storageKey);
      if (raw != null) return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {}
    return const {};
  }

  Future<void> set(String key, Object? value) async {
    final next = {...state.value ?? const <String, Object?>{}, key: value};
    state = AsyncData(next);
    await ref.read(sessionStorageProvider).write(storageKey, jsonEncode(next));
    if (!_isPlugin) return;
    // プラグインへ即時反映 (D-044)。失敗しても KV は書けているので落とさない。
    final session = ref.read(currentSnsSessionProvider);
    final defaults = ref.read(pluginSettingsPagesProvider)[_short]?.defaults ?? const {};
    try {
      await session?.applySettings(_short, {...defaults, ...next});
    } catch (e) {
      debugPrint('applySettings($_short): $e');
    }
  }
}

final settingsAreaProvider = AsyncNotifierProvider.family<SettingsAreaStore, Map<String, Object?>, String>(SettingsAreaStore.new);

/// remote ページ(source: "remote")の値。サーバーが真実で、書き込みは
/// 楽観反映 → 失敗時に巻き戻す。
class RemoteSettingsStore extends AsyncNotifier<Map<String, Object?>> {
  RemoteSettingsStore(this.shortArea);
  final String shortArea;

  @override
  Future<Map<String, Object?>> build() async {
    final session = ref.watch(currentSnsSessionProvider);
    if (session == null) return const {};
    return session.settingsRead(shortArea);
  }

  Future<void> set(String key, Object? value) async {
    final session = ref.read(currentSnsSessionProvider);
    if (session == null) return;
    final before = state.value ?? const <String, Object?>{};
    state = AsyncData({...before, key: value});
    try {
      state = AsyncData(await session.settingsWrite(shortArea, key, value));
    } catch (e) {
      state = AsyncData(before);
      rethrow;
    }
  }
}

final remoteSettingsProvider = AsyncNotifierProvider.family<RemoteSettingsStore, Map<String, Object?>, String>(RemoteSettingsStore.new);

/// SNS プラグイン設定の現在値(defaults マージ済み)。ページ未提供の
/// プラグイン/未ログインは `{}` — 呼び出し側は既定動作に縮退する。
/// アプリ側で値を適用する場所(TL 取得・投稿タイル)から使う。
final snsSettingValuesProvider = FutureProvider.family<Map<String, Object?>, String>((ref, short) async {
  final spec = ref.watch(pluginSettingsPagesProvider)[short];
  if (spec == null || spec.isRemote) return const {};
  final values = await ref.watch(settingsAreaProvider('sns.$short').future);
  return {...spec.defaults, ...values};
});

/// area の設定値(既定値マージ済み)を同期的に読むヘルパー。アプリ側で
/// 値を適用する場所(テーマ/モーション等)から使う。
Object? settingValue(WidgetRef ref, String area, String key, Object? fallback) => ref.watch(settingsAreaProvider(area)).value?[key] ?? fallback;

/// 設定第二階層の DSL 画面。`/settings/dsl/:area`。
class SettingsDslScreen extends ConsumerWidget {
  const SettingsDslScreen({super.key, required this.area});
  final String area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = ref.watch(settingsPageSpecProvider(area));
    return spec.when(
      loading: () => Scaffold(appBar: const RasqPageHeader(title: '設定'), body: const RasqLoading()),
      error: (e, _) => Scaffold(appBar: const RasqPageHeader(title: '設定'), body: RasqEmptyView(title: '設定ページを読み込めません', hint: '$e')),
      data: (s) {
        if (!s.isRemote) return _page(context, ref, s, ref.watch(settingsAreaProvider(area)).value ?? const {});
        final remote = ref.watch(remoteSettingsProvider(s.area));
        return remote.when(
          loading: () => Scaffold(appBar: RasqPageHeader(title: s.title), body: const RasqLoading()),
          error: (e, _) => Scaffold(appBar: RasqPageHeader(title: s.title), body: RasqEmptyView(title: 'サーバーから設定を取得できません', hint: '$e')),
          data: (values) => _page(context, ref, s, values),
        );
      },
    );
  }

  Widget _page(BuildContext context, WidgetRef ref, SettingsPageSpec s, Map<String, Object?> values) {
    final host = RrlHost(
      // 疑似 instanceScope: ホスト自身の静的ページ(プラグイン非経由)。
      instanceScope: 'rasq.host.settings:-:0:$area',
      scope: RrlScope({
        'settings': {...s.defaults, ...values},
      }),
      onEvent: (nodeId, kind, {String? fn, Map<String, Object?> payload = const {}}) {
        // nodeId = `<instanceScope>:<node.k>`、設定キー/パス = ノードの k。
        final key = nodeId.split(':').last;
        switch (fn) {
          case 'settings.set' when s.isRemote:
            ref.read(remoteSettingsProvider(s.area).notifier).set(key, payload['value']).catchError((Object e) {
              ref.read(overlayManagerProvider).showAlert(id: 'settings.remote.error', title: '保存できませんでした', message: '$e', confirmText: 'OK');
            });
          case 'settings.set':
            ref.read(settingsAreaProvider(area).notifier).set(key, payload['value']);
          case 'web.open':
            final instance = ref.read(currentAccountProvider)?.instance;
            if (instance != null) launchUrl(Uri.https(instance, '/$key'), mode: LaunchMode.externalApplication);
        }
      },
    );
    return Scaffold(
      appBar: RasqPageHeader(title: s.title),
      body: ListView(children: [RrlRenderer(node: s.root, host: host)]),
    );
  }
}
