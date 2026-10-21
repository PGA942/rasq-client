@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'storage_quota_cases.dart';

/// ブラウザで動かす確認 (D-546): `flutter test --platform chrome test/web`(packages/plugin_runtime で)。
///
/// セキュリティ確認 2026-10-21 の #2 (csf_2e9abe156286029a2ec69d3b): Web 版の Worker の JS も、`storage.set` を端末版
/// ([PluginStorageQuota]) と同じ予算・同じ答え (E02) で、保存と写しより前に断る。確かめ方は端末版のワーカーと同じ。
void main() => storageQuotaWorkerCases();
