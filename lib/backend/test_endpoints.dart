import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../features/settings/settings_dsl.dart';
import 'orgate_client.dart';

/// テスト用の接続先(プレビュー録画用のダミー環境、D-360)。rasq-preview-assets の `dummy/run_all.sh` が立てるもの:
/// ダミーの Misskey / Mastodon / Bluesky(ポート 9101〜9103)と、本物の Central のデモ(8080)。
/// 設定 → RASQ サーバー →「テスト用の接続先」で、アドレス(例 127.0.0.1 / LAN の IP)を入れて入れる。
abstract final class TestEndpoints {
  static const misskeyHost = 'misskey.rasq.test';
  static const mastodonHost = 'mstdn.rasq.test';
  static const blueskyHost = 'bsky.rasq.test';
  static const ports = {misskeyHost: 9101, mastodonHost: 9102, blueskyHost: 9103};
  static const centralPort = 8080;

  /// 設定のキー(領域 [backendSettingsArea])。
  static const keyEnabled = 'testEndpoints';
  static const keyAddress = 'testEndpointsAddress';
  static const keyCentralBefore = 'centralUrlBeforeTest';
  static const defaultAddress = '127.0.0.1';

  /// `RASQ_DEV_SNS_BASE` と同じ形(`ホスト=基底 URL,…`)。
  static String snsBaseFor(String address) => [for (final e in ports.entries) '${e.key}=http://${address.trim()}:${e.value}'].join(',');
  static String centralFor(String address) => 'http://${address.trim()}:$centralPort';
}

/// 設定の「テスト用の接続先」を SNS の差し替え (D-359) に反映する(アプリの一番上で watch)。
final testEndpointsSyncProvider = Provider<void>((ref) {
  final area = ref.watch(settingsAreaProvider(backendSettingsArea)).value ?? const {};
  final on = area[TestEndpoints.keyEnabled] == true;
  final address = area[TestEndpoints.keyAddress] is String && (area[TestEndpoints.keyAddress] as String).trim().isNotEmpty ? area[TestEndpoints.keyAddress] as String : TestEndpoints.defaultAddress;
  setRuntimeDevSnsBase(on ? TestEndpoints.snsBaseFor(address) : '');
});

/// 入れる / 外す。Central の接続先も切り替え、外すときは元に戻す。
Future<void> setTestEndpoints(WidgetRef ref, {required bool enabled, String? address}) async {
  final store = ref.read(settingsAreaProvider(backendSettingsArea).notifier);
  final area = await ref.read(settingsAreaProvider(backendSettingsArea).future);
  final addr = (address ?? area[TestEndpoints.keyAddress] as String? ?? TestEndpoints.defaultAddress).trim();
  if (enabled) {
    if (area[TestEndpoints.keyEnabled] != true) await store.set(TestEndpoints.keyCentralBefore, area['centralUrl'] as String? ?? '');
    await store.set(TestEndpoints.keyAddress, addr);
    await store.set('centralUrl', TestEndpoints.centralFor(addr));
  } else {
    await store.set('centralUrl', area[TestEndpoints.keyCentralBefore] as String? ?? '');
  }
  await store.set(TestEndpoints.keyEnabled, enabled);
}
