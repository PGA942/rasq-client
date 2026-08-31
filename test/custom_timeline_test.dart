import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/app/app.dart';
import 'package:rasq_client/app/providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_client/features/post/post_detail_screen.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

/// D-080 (M5e): カスタム TL の口 — TL プラグインの宣言がホームのタブに現れ、
/// 基礎 TL の投稿がプラグインのソートアルゴリズムで並ぶ。
/// wasm は使わず、WasmSnsSession の invoke に canned JSON を差してワイヤ
/// 経路ごと検証する(実 wasm のソートは plugin_runtime 側でテスト済み)。
Future<Map<String, dynamic>> _invoke(String fn, Map<String, Object?> args) async {
  Map<String, dynamic> ok(Map<String, Object?> v) => {'ok': true, 'value': v};
  Map<String, Object?> post(String id, String body, int reactions) => {
        'id': id,
        'author': {'id': 'u', 'kind': 'misskey', 'instance': 'example.test', 'handle': 'u', 'displayName': 'ユーザー'},
        'createdAt': '2026-08-30T10:00:00Z',
        'body': body,
        'counts': {'reaction': reactions},
      };
  return switch (fn) {
    'sns.timeline' => ok({'page': {'items': [post('p1', '一点の投稿', 1), post('p5', '五点の投稿', 5), post('p3', '三点の投稿', 3)]}}),
    'sns.actions' => ok({'actions': []}),
    'tl.timelines' => ok({'timelines': [{'id': 'reaction-rank', 'label': 'リアクション順', 'base': 'local'}]}),
    'tl.sort' => ok({'order': ['p5', 'p3', 'p1']}),
    _ => {'ok': false, 'error': {'code': 'C01', 'message': fn}},
  };
}

class _WireBoundaryPlugin extends SnsPlugin {
  _WireBoundaryPlugin([WasmSnsInvoke? invoke]) : _customInvoke = invoke;
  final WasmSnsInvoke? _customInvoke;
  @override
  PluginManifest get manifest => const PluginManifest(id: 'fake.wire', name: 'wire boundary', version: '0.1.0', kind: PluginKind.sns, supportedSns: [SnsKind.misskey]);
  @override
  SnsKind get kind => SnsKind.misskey;
  @override
  Future<ServerInfo> inspectServer(String host) async => ServerInfo(host: host, name: host);
  @override
  Future<AuthFlow> beginAuth(String host, {Uri? callback}) => throw UnsupportedError('boundary test');
  @override
  SnsSession open(AccountSession session) => WasmSnsSession(account: session.account, pluginId: manifest.id, invoke: _customInvoke ?? _invoke);
}

/// tl.customize + lifecycle 検証用の canned invoke(呼び出しログ付き)。
WasmSnsInvoke _customizeInvoke(List<(String, Map<String, Object?>)> log) => (fn, args) async {
      log.add((fn, args));
      final base = await _invoke(fn, args);
      if (fn == 'tl.customize') {
        return {
          'ok': true,
          'value': {
            'tiles': {
              'p5': {
                't': 'Column',
                'k': 'top-p5',
                'c': [
                  {'t': 'Text', 'k': 'crown-p5', 'p': {'text': '👑 リアクション1位'}},
                  {
                    't': 'PostTile',
                    'k': 'post-p5',
                    'role': 'contentBody',
                    'p': {
                      'post': {
                        'id': 'p5',
                        'author': {'displayName': 'ユーザー', 'handle': 'u', 'kind': 'misskey', 'instance': 'example.test'},
                        'createdAt': '2026-08-30T10:00:00Z',
                      },
                      'variant': 'normal',
                    },
                    'c': [
                      {'t': 'RichText', 'k': 'body-p5', 'tag': 'main_text', 'p': {'source': '五点の投稿'}},
                    ],
                  },
                ],
              },
            },
          },
        };
      }
      if (fn == 'lifecycle' || fn == 'sns.thread') {
        if (fn == 'sns.thread') {
          return {
            'ok': true,
            'value': {
              'thread': {
                'post': {'id': 'p5', 'author': {'id': 'u', 'kind': 'misskey', 'instance': 'example.test', 'handle': 'u', 'displayName': 'ユーザー'}, 'createdAt': '2026-08-30T10:00:00Z', 'body': '五点の投稿'},
                'ancestors': [],
                'descendants': [],
              },
            },
          };
        }
        return {'ok': true, 'value': {}};
      }
      return base;
    };

void main() {
  testWidgets('カスタム TL: タブ「リアクション順」が現れ、基礎 TL がプラグインの順で並ぶ', (tester) async {
    const account = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [
          AccountSession(account: account, pluginId: 'fake.wire', token: 't', createdAt: DateTime(2026), displayName: 'テスター').toJson(),
        ],
        'current': account.key,
      }),
    });
    final registry = PluginRegistry()..register(_WireBoundaryPlugin());
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    // TL プラグイン宣言のタブ (D-080)。
    expect(find.text('リアクション順'), findsOneWidget);
    await tester.tap(find.text('リアクション順'));
    await tester.pumpAndSettle();

    // 基礎 TL(sns.timeline)の投稿が tl.sort の順(リアクション降順)で並ぶ。
    expect(find.text('五点の投稿'), findsOneWidget);
    final y5 = tester.getTopLeft(find.text('五点の投稿')).dy;
    final y3 = tester.getTopLeft(find.text('三点の投稿')).dy;
    final y1 = tester.getTopLeft(find.text('一点の投稿')).dy;
    expect(y5, lessThan(y3));
    expect(y3, lessThan(y1));
  });

  testWidgets('投稿カスタマイザ (D-082): 置き換えタイルが RRL で描かれ、可視性 lifecycle とスレッドナビ保証が効く', (tester) async {
    const account = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [
          AccountSession(account: account, pluginId: 'fake.wire', token: 't', createdAt: DateTime(2026), displayName: 'テスター').toJson(),
        ],
        'current': account.key,
      }),
    });
    final log = <(String, Map<String, Object?>)>[];
    final registry = PluginRegistry()..register(_WireBoundaryPlugin(_customizeInvoke(log)));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('リアクション順'));
    await tester.pumpAndSettle();

    // 1 位(p5)は置き換えタイル(王冠 + PostTile)、他は通常 PostRow。
    expect(find.text('👑 リアクション1位'), findsOneWidget);
    expect(find.text('五点の投稿'), findsOneWidget);
    expect(find.text('三点の投稿'), findsOneWidget); // 通常タイルのまま

    // 可視性 lifecycle (D-082): 行の生成で visible が届いている。
    expect(
      log.where((e) => e.$1 == 'lifecycle' && e.$2['kind'] == 'visible' && e.$2['post'] == 'p5' && '${e.$2['surface']}' == 'tl:reaction-rank'),
      isNotEmpty,
    );

    // スレッドナビの保証 (V5): 置き換えタイルのタップでスレッド展開へ。
    await tester.tap(find.text('👑 リアクション1位'));
    await tester.pumpAndSettle();
    expect(find.byType(PostDetailScreen), findsOneWidget);
  });

  testWidgets('投稿加工プラグイン (D-083): 通常 TL でも表示前に本文が加工される', (tester) async {
    const account = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'tester');
    final storage = MemorySessionStorage({
      SessionsNotifier.storageKey: jsonEncode({
        'sessions': [
          AccountSession(account: account, pluginId: 'fake.wire', token: 't', createdAt: DateTime(2026), displayName: 'テスター').toJson(),
        ],
        'current': account.key,
      }),
    });
    Future<Map<String, dynamic>> invoke(String fn, Map<String, Object?> args) async {
      if (fn == 'post.transform') {
        return {
          'ok': true,
          'value': {'posts': {'p1': {'body': '🚀 一点の投稿'}}},
        };
      }
      return _invoke(fn, args);
    }

    final registry = PluginRegistry()..register(_WireBoundaryPlugin(invoke));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        pluginRegistryProvider.overrideWithValue(registry),
      ],
      child: const RasqApp(),
    ));
    await tester.pumpAndSettle();

    // 通常 TL(ローカル)でも本文加工が効く(構造はそのまま PostRow)。
    await tester.tap(find.text('ローカル'));
    await tester.pumpAndSettle();
    expect(find.text('🚀 一点の投稿'), findsOneWidget);
    expect(find.text('一点の投稿'), findsNothing);
    expect(find.text('五点の投稿'), findsOneWidget); // 非該当は無加工
  });
}
