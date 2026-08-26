import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';

import '../../session/session_providers.dart';
import '../../shell/headers.dart';

/// 設定第二階層の DSL 描画 (D-031)。
///
/// 設定ページ = **wasm 不要の静的 RRL アセット**(`assets/settings/<area>.rrl.json`)。
/// 値は Bind `$.settings.<key>` で解決し、タイルの `change` イベント
/// (`on: {"change": "settings.set"}`、設定キー = ノードの `k`)をホストが
/// KV 書き込みに変換する。保存規約は D-035: アカウント毎 KV `<area>.v1` に
/// JSON オブジェクト。プラグインの設定ページも同じレンダラーで描画する
/// (そちらの永続化は `storage.safe`)。
class SettingsPageSpec {
  const SettingsPageSpec({required this.area, required this.title, required this.defaults, required this.root});

  final String area;
  final String title;

  /// 未保存キーの既定値(Bind 解決前に KV へマージされる)。
  final Map<String, Object?> defaults;
  final RrlNode root;

  factory SettingsPageSpec.fromJson(Map<String, Object?> json) {
    if (json['schema'] != 'rasq.settings-page/1') {
      throw FormatException('unknown settings page schema: ${json['schema']}');
    }
    return SettingsPageSpec(
      area: json['area'] as String,
      title: json['title'] as String? ?? '設定',
      defaults: (json['defaults'] as Map?)?.cast<String, Object?>() ?? const {},
      root: RrlNode.fromJson((json['root'] as Map).cast<String, Object?>()),
    );
  }
}

final settingsPageSpecProvider = FutureProvider.family<SettingsPageSpec, String>((ref, area) async {
  final raw = await rootBundle.loadString('assets/settings/$area.rrl.json');
  return SettingsPageSpec.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
});

/// 1 ページ(area)分の設定値 KV。キーは `<area>.v1`(D-035)。
class SettingsAreaStore extends AsyncNotifier<Map<String, Object?>> {
  SettingsAreaStore(this.area);
  final String area;

  String get storageKey => '$area.v1';

  @override
  Future<Map<String, Object?>> build() async {
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
  }
}

final settingsAreaProvider = AsyncNotifierProvider.family<SettingsAreaStore, Map<String, Object?>, String>(SettingsAreaStore.new);

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
        final values = ref.watch(settingsAreaProvider(area)).value ?? const <String, Object?>{};
        final host = RrlHost(
          // 疑似 instanceScope: ホスト自身の静的ページ(プラグイン非経由)。
          instanceScope: 'rasq.host.settings:-:0:$area',
          scope: RrlScope({
            'settings': {...s.defaults, ...values},
          }),
          onEvent: (nodeId, kind, {String? fn, Map<String, Object?> payload = const {}}) {
            if (fn != 'settings.set') return;
            // nodeId = `<instanceScope>:<node.k>`、設定キー = ノードの k。
            final key = nodeId.split(':').last;
            ref.read(settingsAreaProvider(area).notifier).set(key, payload['value']);
          },
        );
        return Scaffold(
          appBar: RasqPageHeader(title: s.title),
          body: ListView(children: [RrlRenderer(node: s.root, host: host)]),
        );
      },
    );
  }
}
