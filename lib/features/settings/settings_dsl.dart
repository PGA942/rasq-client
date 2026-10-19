import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart' show AccountSession, SnsSession;
import 'package:rrl_core/rrl_core.dart';
import 'package:rrl_renderer/rrl_renderer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../../l10n/ui_locale.dart' show uiLocaleTagProvider;
import '../../l10n/l10n.dart';

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
      title: json['title'] as String? ?? appL10n.settingsHomeGenericTitle,
      source: json['source'] as String? ?? 'local',
      defaults: (json['defaults'] as Map?)?.cast<String, Object?>() ?? const {},
      root: RrlNode.fromJson((json['root'] as Map).cast<String, Object?>()),
    );
  }
}

/// SNS プラグイン [pluginId] が提供する設定ページ(短 area → spec)(D-044 / D-482)。壊れたページは読み飛ばす
/// (V12: 縮退)。wasm のプラグインは `sns.settingsPages` で返すので非同期([SnsPlugin.loadSettingsPages])。
final snsPluginSettingsPagesProvider = FutureProvider.family<Map<String, SettingsPageSpec>, String>((ref, pluginId) async {
  // ページの文言はプラグインが表示の言語(`args.locale`)で選ぶ。言語が変われば読み直す (D-484 / 契約 v0.24)。
  ref.watch(uiLocaleTagProvider);
  final plugin = ref.watch(pluginRegistryProvider).plugin(pluginId);
  final out = <String, SettingsPageSpec>{};
  for (final raw in await plugin?.loadSettingsPages() ?? const <String>[]) {
    try {
      final spec = SettingsPageSpec.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      out[spec.area] = spec;
    } catch (e) {
      debugPrint('settings page from $pluginId skipped: $e');
    }
  }
  return out;
});

/// 現在の SNS プラグインが提供する設定ページ(短 area → spec)。読み込み中は空(値を使う側は既定動作に縮退する)。
final pluginSettingsPagesProvider = Provider<Map<String, SettingsPageSpec>>((ref) {
  final session = ref.watch(currentSnsSessionProvider);
  if (session == null) return const {};
  return ref.watch(snsPluginSettingsPagesProvider(session.pluginId)).value ?? const {};
});

/// 設定する SNS アカウント(D-131 の切替を含む)のプラグインが提供する設定ページ (D-482)。
/// 設定の「SNSプラグイン」の行はこれに無いページを出さず、ページはこれから開く。
final settingsTargetPagesProvider = FutureProvider<Map<String, SettingsPageSpec>>((ref) async {
  final session = settingsTargetSession(ref);
  if (session == null) return const {};
  return ref.watch(snsPluginSettingsPagesProvider(session.pluginId).future);
});

/// SNS プラグインが持たない設定ページを開こうとした (D-482)。行は出さないが、検索や古いリンクから来うる。
class MissingSnsSettingsPage implements Exception {
  const MissingSnsSettingsPage(this.area);
  final String area;
  @override
  String toString() => appL10n.settingsHomeMissingSnsPage(area);
}

/// 設定の行 [route] が SNS プラグインの設定ページ(`/settings/dsl/sns.<短area>`)なら、その短 area。
String? snsSettingsAreaOf(String? route) {
  const prefix = '/settings/dsl/sns.';
  return route != null && route.startsWith(prefix) ? route.substring(prefix.length) : null;
}

/// 設定の行を出すか (D-482): SNS プラグインの設定ページの行は、プラグインが宣言したものだけ。
/// 読み込み中は出しておく(出たり消えたりしないよう、宣言が分かってから消す)。
bool settingsRowVisible(WidgetRef ref, String? route) {
  final area = snsSettingsAreaOf(route);
  if (area == null) return true;
  final pages = ref.watch(settingsTargetPagesProvider).value;
  return pages == null || pages.containsKey(area);
}

final settingsPageSpecProvider = FutureProvider.family<SettingsPageSpec, String>((ref, area) async {
  if (area.startsWith('sns.')) {
    final short = area.substring(4);
    final spec = (await ref.watch(settingsTargetPagesProvider.future))[short];
    if (spec == null) throw MissingSnsSettingsPage(short);
    return spec;
  }
  final raw = await loadSettingsPageJson(area);
  return SettingsPageSpec.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
});

/// 設定ページの JSON を読む。`rootBundle.loadString` は 50KB を超えると別の isolate で解くので、
/// 長い文書ページ(プライバシーポリシーなど)でも同じ道を通るよう、バイト列をこの場で UTF-8 として読む。
Future<String> loadSettingsPageJson(String area) async =>
    utf8.decode((await rootBundle.load('assets/settings/$area.rrl.json')).buffer.asUint8List());

/// 1 ページ(area)分の設定値 KV。ホスト設定は `<area>.v1`(D-035)、
/// プラグイン設定 (`sns.<短area>`) は `sns.<pluginId>.<短area>.v1`。
/// SNS プラグイン設定で「設定するアカウント」を切り替えるオーバーライド
/// (D-131)。null = 現在のアカウント。SNS 設定ページのアカウントバンドル
/// タイル(RASQ 行なし)から選ぶ。
class SettingsAccountOverride extends Notifier<AccountSession?> {
  @override
  AccountSession? build() => null;
  void set(AccountSession? s) => state = s;
}

final settingsAccountOverrideProvider = NotifierProvider<SettingsAccountOverride, AccountSession?>(SettingsAccountOverride.new);

/// 設定対象の SNS セッション (D-131): オーバーライド → 現在の順。
SnsSession? settingsTargetSession(Ref ref) {
  final override = ref.watch(settingsAccountOverrideProvider);
  if (override != null) {
    try {
      return ref.watch(pluginRegistryProvider).session(override);
    } catch (_) {
      return null;
    }
  }
  return ref.watch(currentSnsSessionProvider);
}

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
    if (_isPlugin) {
      ref.watch(currentSnsSessionProvider); // キーがプラグインに依存
      ref.watch(settingsAccountOverrideProvider); // 設定対象の切替 (D-131)
    }
    try {
      final raw = await ref.watch(sessionStorageProvider).read(storageKey);
      if (raw != null) return (jsonDecode(raw) as Map).cast<String, Object?>();
    } catch (_) {}
    return const {};
  }

  Future<void> set(String key, Object? value) async {
    // 読み込みが終わってから書く (D-238): 読み込み中に書くと、後から届いた読み込み結果(保存前の値)で上書きされる。
    Map<String, Object?> base = state.value ?? const <String, Object?>{};
    if (!state.hasValue) {
      try {
        base = await future;
      } catch (_) {}
    }
    final next = {...base, ...state.value ?? const <String, Object?>{}, key: value};
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
    // 設定するアカウントの切替 (D-131): オーバーライドがあればそのセッション。
    final session = settingsTargetSession(ref);
    if (session == null) return const {};
    return session.settingsRead(shortArea);
  }

  Future<void> set(String key, Object? value) async {
    final override = ref.read(settingsAccountOverrideProvider);
    final session = override != null ? ref.read(pluginRegistryProvider).session(override) : ref.read(currentSnsSessionProvider);
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

/// ページの JSON に書けない既定値(端末の種類で変わるもの)(D-316)。ページの `defaults` に重ねて、画面の値の既定にする。
/// 値を使う側も、保存が無ければ同じ既定を使う(例: [timelineEdgeTilesProvider] の元)。
final hostSettingDefaultsProvider = Provider.family<Map<String, Object?>, String>((ref, area) => switch (area) {
      // TL の上下の「投稿を読み込む」: 電話のアプリは引っ張って更新できるので、既定は出さない。Web 版とデスクトップは出す。
      timelineDisplayArea => {'edgeTiles': !ref.watch(mobileAppProvider)},
      _ => const <String, Object?>{},
    });

/// TL の表示の設定 (D-316)。
const timelineDisplayArea = 'appearance.timeline';

/// TL のいちばん上 / いちばん下に「投稿を読み込む」のタイル (D-298) を出すか (D-316)。
final timelineEdgeTilesProvider = Provider<bool>((ref) {
  final v = ref.watch(settingsAreaProvider(timelineDisplayArea)).value?['edgeTiles'];
  return v is bool ? v : ref.watch(hostSettingDefaultsProvider(timelineDisplayArea))['edgeTiles'] != false;
});

/// TL を更新して新しい投稿が届いたとき、ヘッダーのすぐ下に「新しい投稿」の札を出すか (D-506)。既定は出す。
final timelineNewPostsPillProvider = Provider<bool>((ref) => ref.watch(settingsAreaProvider(timelineDisplayArea)).value?['newPostsPill'] != false);

/// area の設定値(既定値マージ済み)を同期的に読むヘルパー。アプリ側で
/// 値を適用する場所(テーマ/モーション等)から使う。
Object? settingValue(WidgetRef ref, String area, String key, Object? fallback) => ref.watch(settingsAreaProvider(area)).value?[key] ?? fallback;

/// 設定第二階層の DSL 画面。`/settings/dsl/:area`。
class SettingsDslScreen extends ConsumerWidget {
  const SettingsDslScreen({super.key, required this.area});
  final String area;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final spec = ref.watch(settingsPageSpecProvider(area));
    return spec.when(
      loading: () => Scaffold(appBar: RasqPageHeader(title: l.settingsHomeGenericTitle), body: const RasqLoading()),
      error: (e, _) => Scaffold(
        appBar: RasqPageHeader(title: l.settingsHomeGenericTitle),
        body: e is MissingSnsSettingsPage
            ? RasqEmptyView(title: l.settingsHomePageMissing, hint: rasqDetail(context, l.settingsHomePageMissingHint, '$e(D-482)'))
            : RasqEmptyView(title: l.settingsHomePageLoadError, hint: '$e'),
      ),
      data: (s) {
        if (!s.isRemote) return _page(context, ref, s, ref.watch(settingsAreaProvider(area)).value ?? const {});
        final remote = ref.watch(remoteSettingsProvider(s.area));
        return remote.when(
          loading: () => Scaffold(appBar: RasqPageHeader(title: s.title), body: const RasqLoading()),
          error: (e, _) => Scaffold(appBar: RasqPageHeader(title: s.title), body: RasqEmptyView(title: l.settingsHomeRemoteLoadError, hint: '$e')),
          data: (values) => _page(context, ref, s, values),
        );
      },
    );
  }

  Widget _page(BuildContext context, WidgetRef ref, SettingsPageSpec s, Map<String, Object?> values) {
    // チャイルドセーフ (D-307): 見守り中の「プライバシーとセーフモード」は読むだけ(閲覧注意のメディアは必ず隠す)。
    final childLocked = area == 'sns.safety' && ref.watch(childGateProvider).supervised;
    if (childLocked) values = {...values, 'sensitiveMedia': 'hide'};
    // 疑似 instanceScope: ホスト自身の静的ページ(プラグイン非経由)。
    final instanceScope = 'rasq.host.settings:-:0:$area';
    final host = RrlHost(
      instanceScope: instanceScope,
      scope: RrlScope({
        'settings': {...s.defaults, if (!s.isRemote && !area.startsWith('sns.')) ...ref.watch(hostSettingDefaultsProvider(area)), ...values},
      }),
      onEvent: (nodeId, kind, {String? fn, Map<String, Object?> payload = const {}}) {
        // nodeId = `<instanceScope>:<node.k>`、設定キー/パス = ノードの k。k には `:` も入りうる(web.open の URL、D-482)。
        final key = nodeId.startsWith('$instanceScope:') ? nodeId.substring(instanceScope.length + 1) : nodeId.split(':').last;
        // 値: 設定タイルの change は payload.value、文字の欄(Input)の submit は payload.text (D-482)。
        final value = payload.containsKey('value') ? payload['value'] : payload['text'];
        if (childLocked && fn == 'settings.set') return;
        switch (fn) {
          case 'settings.set' when s.isRemote:
            ref.read(remoteSettingsProvider(s.area).notifier).set(key, value).catchError((Object e) {
              // 権限不足 (D-045): スコープの増加は既存トークンに反映されない
              // ため、再ログインの誘導を添える。
              final permission = '$e'.contains('PERMISSION_DENIED') || '$e'.contains('403');
              final hint = permission ? appL10n.settingsHomeRemotePermissionHint : '';
              ref.read(overlayManagerProvider).showAlert(id: 'settings.remote.error', title: appL10n.settingsHomeSaveFailed, message: '$e$hint', confirmText: appL10n.settingsHomeOk);
            });
          case 'settings.set':
            ref.read(settingsAreaProvider(area).notifier).set(key, value);
          case 'web.open':
            // `https://` の URL はそのまま(Bluesky の bsky.app のように、設定の web がアカウントの接続先と別、D-482)。
            // ほかは設定するアカウントのインスタンス上のパス。
            if (key.startsWith('https://')) {
              final uri = Uri.tryParse(key);
              if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
              break;
            }
            final instance = (ref.read(settingsAccountOverrideProvider) ?? ref.read(currentAccountSessionProvider))?.account.instance;
            if (instance != null) launchUrl(Uri.https(instance, '/$key'), mode: LaunchMode.externalApplication);
          case 'route.push':
            // アプリ内の画面へ (D-238): `k` = ルート(`/store` など。`:` は含められない)。
            if (key.startsWith('/')) context.push(key);
        }
      },
    );
    return Scaffold(
      appBar: RasqPageHeader(title: s.title),
      body: ListView(children: [
        // SNS プラグイン設定のアカウント切替 (D-131): バンドルタイル型
        // (RASQ アカウント行なし)。選んだアカウントのセッションに読み書き。
        if (area.startsWith('sns.')) _accountTile(context, ref),
        if (childLocked)
          RasqNotice(
            key: const ValueKey('childSafe.safetyReadOnly'),
            text: context.l10n.settingsHomeChildLocked,
          ),
        IgnorePointer(ignoring: childLocked, child: RrlRenderer(node: s.root, host: host)),
      ]),
    );
  }

  Widget _accountTile(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final sessions = ref.watch(sessionsProvider).value?.sessions ?? const <AccountSession>[];
    if (sessions.length < 2) return const SizedBox.shrink();
    final selectedKey = (ref.watch(settingsAccountOverrideProvider) ?? ref.watch(currentAccountSessionProvider))?.account.key;
    return Container(
      margin: const EdgeInsets.fromLTRB(RasqSpacing.md, RasqSpacing.sm, RasqSpacing.md, RasqSpacing.xs),
      decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.md, 6, RasqSpacing.md, 0),
          child: Text(context.l10n.settingsHomeTargetAccount, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ),
        for (final s in sessions)
          InkWell(
            onTap: () {
              final current = ref.read(currentAccountSessionProvider);
              ref.read(settingsAccountOverrideProvider.notifier).set(s.account.key == current?.account.key ? null : s);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.md, vertical: 6),
              child: Row(children: [
                RasqSnsPill(account: s.account, showLabel: false, dotSize: 14),
                const SizedBox(width: RasqSpacing.sm),
                Expanded(child: Text('${s.account}', style: RasqTypography.bodySmall.copyWith(fontWeight: s.account.key == selectedKey ? FontWeight.w700 : null), overflow: TextOverflow.ellipsis)),
                if (s.account.key == selectedKey) Icon(Icons.check, size: 16, color: tokens.link),
              ]),
            ),
          ),
      ]),
    );
  }
}
