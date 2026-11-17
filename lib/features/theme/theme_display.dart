import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_store/rasq_store.dart';

import '../../session/session_providers.dart';
import '../settings/settings_dsl.dart';
import 'icon_theme/icon_theme_backdrop.dart' show IconThemeBackdrop, iconThemeBackground, themeColor;
import 'icon_theme/rasq_theme_spec.dart';
import 'theme_packs.dart' show activeSkinProvider, themeSettingsArea;

/// ほかの人のテーマを、どこに・どれだけ出すか (D-587)。
///
/// - **どこに**: アイコンに埋め込まれたテーマ = その人のユーザーページと、その人が根の投稿を書いたスレッドのページ。
///   RASQ Atmos のスレッドのテーマ = そのスレッドのページ(アイコンのテーマより先)。コミュハッシュタグ = そのタグのページ。
///   アイコンの全画面表示には出さない。
/// - **層**: 色と背景は着せ替え(テーマプラグイン)と同じ層([ThemedSurface] がそのページの範囲だけ ColorScheme を上書きし、
///   一番下に背景を敷く)。エフェクト(テーマフレームの SVG・パーティクル)は**中身の上に**重ねる(触れない。押す / なぞるは届く)。
/// - **設定**(設定 → アプリの外観 → フォントやカラースキーム): 種類ごとに
///   ①着せ替えとどちらを優先するか(既定 = 着せ替え。着せ替えを選んでいないときは、いつも出す)
///   ②どの人のものを出すか(フォローしている人だけ / 全員 / 出さない。既定 = 全員)。
///   Atmos / コミュハッシュタグの「フォローしている人だけ」は、その投稿の作者で決める(タグのページは作者がいないので出す)。
/// - **個別ミュート**: テーマの**値**(色・拡張・フレーム・きっかけ)のハッシュで覚える。同じ値のテーマは、誰のものでも出さない。
///   入口はテーマを出しているページの「…」、解除は設定の「ミュートしたテーマ」。
enum ThemeOrigin {
  /// アイコンに埋め込まれたテーマ (D-577)。
  icon,

  /// RASQ Atmos (D-584)。
  atmos,

  /// コミュハッシュタグ (D-582)。
  community,
}

enum ThemeDisplayScope { followees, all, off }

String _scopeKey(ThemeOrigin o) => 'display.${o.name}.scope';
String _overPluginKey(ThemeOrigin o) => 'display.${o.name}.overPlugin';
const mutedThemesKey = 'mutedThemes';

/// ミュートしておける数(古いものから捨てる)。
const mutedThemesMax = 200;

final themeDisplayScopeProvider = Provider.family<ThemeDisplayScope, ThemeOrigin>((ref, o) {
  final v = ref.watch(settingsAreaProvider(themeSettingsArea)).value?[_scopeKey(o)];
  return ThemeDisplayScope.values.asNameMap()[v] ?? ThemeDisplayScope.all;
});

/// 着せ替えより優先するか(既定 false = 着せ替えを選んでいる間は出さない)。
final themeOverPluginProvider = Provider.family<bool, ThemeOrigin>((ref, o) => ref.watch(settingsAreaProvider(themeSettingsArea)).value?[_overPluginKey(o)] == true);

Future<void> setThemeDisplayScope(WidgetRef ref, ThemeOrigin o, ThemeDisplayScope s) => ref.read(settingsAreaProvider(themeSettingsArea).notifier).set(_scopeKey(o), s.name);
Future<void> setThemeOverPlugin(WidgetRef ref, ThemeOrigin o, bool v) => ref.read(settingsAreaProvider(themeSettingsArea).notifier).set(_overPluginKey(o), v);

// ── 値でのミュート ──────────────────────────────────────

/// テーマの値のハッシュ: 見た目に効く部分(基本・拡張・フレーム・きっかけ)だけを、キーを並べた JSON にして SHA-256(16 進 32 桁)。
/// どこに出すか(`scope`)・出どころ(`source`)は入れない(同じ見た目なら、アイコンでも Atmos でも同じ値)。
String themeValueHash(RasqThemeSpec spec) {
  final j = Map<String, Object?>.of(spec.toJson())
    ..remove('scope')
    ..remove('source');
  return crypto.sha256.convert(utf8.encode(_canonicalJson(j))).toString().substring(0, 32);
}

String _canonicalJson(Object? v) => switch (v) {
      Map() => '{${(v.keys.map((k) => '$k').toList()..sort()).map((k) => '${jsonEncode(k)}:${_canonicalJson(v[k])}').join(',')}}',
      List() => '[${v.map(_canonicalJson).join(',')}]',
      _ => jsonEncode(v),
    };

/// ミュートしたテーマ 1 件(設定の一覧で見本を出すため、値そのものも持つ)。
@immutable
class MutedTheme {
  const MutedTheme({required this.hash, this.spec, this.origin, this.mutedAt});
  final String hash;
  final RasqThemeSpec? spec;
  final ThemeOrigin? origin;
  final DateTime? mutedAt;

  Map<String, Object?> toJson() => {'h': hash, if (spec != null) 'theme': spec!.toJson(), if (origin != null) 'origin': origin!.name, if (mutedAt != null) 'at': mutedAt!.toUtc().toIso8601String()};
  static MutedTheme? fromJson(Object? j) {
    if (j is! Map || j['h'] is! String) return null;
    return MutedTheme(
      hash: j['h'] as String,
      spec: RasqThemeSpec.fromJson(j['theme']),
      origin: ThemeOrigin.values.asNameMap()[j['origin']],
      mutedAt: j['at'] is String ? DateTime.tryParse(j['at'] as String) : null,
    );
  }
}

final mutedThemesProvider = Provider<List<MutedTheme>>((ref) {
  final raw = ref.watch(settingsAreaProvider(themeSettingsArea)).value?[mutedThemesKey];
  return [for (final e in (raw is List ? raw : const [])) ?MutedTheme.fromJson(e)];
});

final mutedThemeHashesProvider = Provider<Set<String>>((ref) => {for (final m in ref.watch(mutedThemesProvider)) m.hash});

Future<void> muteTheme(WidgetRef ref, RasqThemeSpec spec, ThemeOrigin origin, {DateTime? now}) async {
  final h = themeValueHash(spec);
  final list = [for (final m in ref.read(mutedThemesProvider)) if (m.hash != h) m];
  final next = [MutedTheme(hash: h, spec: spec, origin: origin, mutedAt: now ?? DateTime.now()), ...list].take(mutedThemesMax);
  await ref.read(settingsAreaProvider(themeSettingsArea).notifier).set(mutedThemesKey, [for (final m in next) m.toJson()]);
}

Future<void> unmuteTheme(WidgetRef ref, String hash) => ref
    .read(settingsAreaProvider(themeSettingsArea).notifier)
    .set(mutedThemesKey, [for (final m in ref.read(mutedThemesProvider)) if (m.hash != hash) m.toJson()]);

// ── フォローしているか(「フォローしている人だけ」のため)──────────────────

/// テーマの持ち主: 見ているアカウントと、そのアカウントのサーバーでの相手の id。
typedef ThemeAuthor = ({AccountId viewer, String userId});

/// その人をフォローしているか。端末の控え(フォロー状態)に無ければ、まとめて問い合わせて(200ms ごとに最大 40 人)、分かるまでは null。
final authorFollowedProvider = Provider.family<bool?, ThemeAuthor>((ref, a) {
  final key = followKey(a.viewer.key, followUserKey(a.viewer, a.userId));
  final st = ref.watch(followStateProvider.select((m) => m[key]));
  if (st != null) return st.following;
  ref.read(_followLookupProvider).request(a);
  return null;
});

final _followLookupProvider = Provider<_FollowLookup>((ref) {
  final l = _FollowLookup(ref);
  ref.onDispose(l.dispose);
  return l;
});

class _FollowLookup {
  _FollowLookup(this.ref);
  final Ref ref;
  final _pending = <String, (AccountId, Set<String>)>{};
  final _asked = <String>{};
  Timer? _timer;

  void request(ThemeAuthor a) {
    final k = '${a.viewer.key}|${a.userId}';
    if (!_asked.add(k)) return;
    (_pending[a.viewer.key] ??= (a.viewer, <String>{})).$2.add(a.userId);
    _timer ??= Timer(const Duration(milliseconds: 200), _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    final batch = Map.of(_pending);
    _pending.clear();
    for (final (viewer, ids) in batch.values) {
      final s = ref.read(sessionForAccountProvider(viewer.key));
      if (s == null) continue;
      final all = ids.toList();
      for (var i = 0; i < all.length; i += 40) {
        final chunk = all.sublist(i, (i + 40).clamp(0, all.length));
        try {
          final rel = await s.relationships(chunk);
          ref.read(followStateProvider.notifier).applyAll({for (final e in rel.entries) followKey(viewer.key, followUserKey(viewer, e.key)): e.value});
        } catch (e) {
          // 取れない(未対応の SNS など)ときは分からないまま = 「フォローしている人だけ」では出さない。
          debugPrint('theme display: relationships unavailable: $e');
        }
      }
    }
  }

  void dispose() => _timer?.cancel();
}

// ── 出すかどうか ──────────────────────────────────────

/// このテーマを、いまこの場所に出すか。[author] = 持ち主(タグのページなど、持ち主のいないものは null = 「フォローしている人だけ」でも出す)。
/// [surface] = ページの色と背景を替えるもの(着せ替えとの優先を見る)。Atmos の名前の横のアイコン・アニメーションは false。
bool watchThemeVisible(WidgetRef ref, {required ThemeOrigin origin, required RasqThemeSpec spec, ThemeAuthor? author, bool surface = true}) {
  final scope = ref.watch(themeDisplayScopeProvider(origin));
  if (scope == ThemeDisplayScope.off) return false;
  if (ref.watch(mutedThemeHashesProvider).contains(themeValueHash(spec))) return false;
  if (surface && ref.watch(activeSkinProvider) != null && !ref.watch(themeOverPluginProvider(origin))) return false;
  if (scope == ThemeDisplayScope.followees && author != null && ref.watch(authorFollowedProvider(author)) != true) return false;
  return true;
}

/// テーマ → 着せ替えと同じ形(色の上書き + 一番下の面)。色は明るさに関わらず同じ(テーマの持ち主が選んだ組み合わせ)。
RasqSkin themeSpecSkin(RasqThemeSpec spec) {
  final b = spec.basic;
  final bg = themeColor(b.bg), text = themeColor(b.text), accent = themeColor(b.accent);
  Color mix(double t) => Color.lerp(bg, text, t)!;
  final onAccent = accent.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  final colors = <String, Color>{
    'primary': accent,
    'onPrimary': onAccent,
    'secondary': accent,
    'onSecondary': onAccent,
    'tertiary': accent,
    'surface': bg,
    'onSurface': text,
    'onSurfaceVariant': text.withValues(alpha: 0.72),
    'surfaceContainer': mix(0.06),
    'surfaceContainerHigh': mix(0.10),
    'surfaceContainerHighest': mix(0.14),
    'outline': text.withValues(alpha: 0.42),
    'outlineVariant': text.withValues(alpha: 0.2),
  };
  final deco = iconThemeBackground(b) as BoxDecoration;
  return RasqSkin(
    id: 'rasq.theme.${themeValueHash(spec)}',
    name: '',
    colors: {Brightness.light: colors, Brightness.dark: colors},
    surfaces: {
      RasqSkinSurfaceId.app: RasqSkinSurface(color: deco.gradient == null ? deco.color : null, layers: [if (deco.gradient case final g?) RasqSkinLayer(gradient: g)]),
    },
  );
}

/// テーマをそのページの範囲に付ける(出すかどうかは呼び元が決めた後)。[spec] が null なら何もしない。
///
/// テーマの有無が後から変わっても(アイコンの読み取りは非同期)、中身(ページの状態・スクロール位置)は作り直さない。
class ThemedSurface extends StatefulWidget {
  const ThemedSurface({super.key, required this.spec, required this.child});
  final RasqThemeSpec? spec;
  final Widget child;

  @override
  State<ThemedSurface> createState() => _ThemedSurfaceState();
}

class _ThemedSurfaceState extends State<ThemedSurface> {
  final _content = GlobalKey(debugLabel: 'themedSurface.content');

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final content = KeyedSubtree(key: _content, child: widget.child);
    if (spec == null) return content;
    final skin = themeSpecSkin(spec);
    final app = skin.surfaces[RasqSkinSurfaceId.app]!;
    return Theme(
      data: skin.applyTo(Theme.of(context)),
      child: RasqSkinScope(
        skin: skin,
        child: Stack(key: ValueKey('themedSurface.${themeValueHash(spec)}'), fit: StackFit.passthrough, children: [
          if (app.color != null) Positioned.fill(child: IgnorePointer(child: ColoredBox(color: app.color!))),
          for (final l in app.layers) l.build(),
          IconThemeBackdrop.effects(spec: spec, child: content),
        ]),
      ),
    );
  }
}
