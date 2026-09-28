import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings_dsl.dart';

/// 開発者モード (D-362) の設定ページ(`assets/settings/about.developer.rrl.json`)。
const developerModeArea = 'about.developer';

/// 開発者モード: 公開テスト向けに短くした文面の代わりに、細かい説明(仕組み・保存先・送る値の形・決定番号など)を出す。
/// アプリの上の `RasqDeveloperMode` へ流し、部品は `RasqDeveloperMode.of(context)` で読む。既定はオフ。
final developerModeProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(developerModeArea)).value?['enabled'] == true);
