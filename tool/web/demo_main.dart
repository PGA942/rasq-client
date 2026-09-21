// Web 版の確認用の入口 (D-304): 偽の SNS プラグインでログイン済みの状態から起動する(サーバーもログインも要らない)。
// `flutter build web -t tool/web/demo_main.dart` → `tool/web/webshot.sh`(PAGE='#/rai' など)で、画面の写真を撮る。配るビルドには入らない。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/mock/mock_data.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../test/support/fakes.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = MemorySessionStorage({
    SessionsNotifier.storageKey: jsonEncode({'sessions': [fakeSession().toJson()], 'current': fakeSession().account.key}),
  });
  runApp(ProviderScope(
    overrides: [
      sessionStorageProvider.overrideWithValue(storage),
      pluginRegistryProvider.overrideWithValue(PluginRegistry()..register(FakeSnsPlugin(posts: MockData.timeline))),
    ],
    child: const RasqApp(),
  ));
}
