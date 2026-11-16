import 'package:flutter/foundation.dart';

import 'icon_theme_codec.dart';

/// テーマのデータの形 (D-562)。アイコンに埋め込んだテーマ(アイコンチップ、D-561)だけでなく、第4回の
/// **コミュハッシュタグのテーマ**と **RASQ Atmos**(ハッシュタグがきっかけの SVG アイコン / アクションボタンで再生する SVG
/// アニメーション / そのスレッドの表示だけに効くテーマ)も、この 1 つの形を使い回す。
///
/// - 見た目の中身は [basic](背景・文字色・強調色・パーティクル・予約 3 ビット)と [ext](ベクターの形・軌道・スロット、
///   またはプラグインの配信 URL)= アイコンの四隅に入るものと同じ。アイコンに入らない分は JSON で配る(Central など)。
/// - [frames] = 背景に置く SVG(**ID で置き場から引く**、D-563)。
/// - [scope] = どこに効くか(プロフィール / スレッド / ハッシュタグ)。[triggers] = Atmos のきっかけ(ハッシュタグで
///   アイコンを付ける / アクションで SVG アニメーション)。
/// - JSON の `v` は形の版(今は 1)。知らない項目は読み飛ばす。
@immutable
class RasqThemeSpec {
  const RasqThemeSpec({required this.basic, this.ext, this.frames = const [], this.scope = const RasqThemeScope.profile(), this.triggers = const [], this.source = RasqThemeSource.iconEmbed});

  /// アイコンから読み戻したテーマ(拡張領域が読めなければ基本だけ)。
  factory RasqThemeSpec.fromIcon(IconThemeDecoded d, {List<RasqThemeFrameRef> frames = const []}) => RasqThemeSpec(basic: d.theme!, ext: d.ext, frames: frames);

  final IconThemeBasic basic;
  final IconThemeExt? ext;
  final List<RasqThemeFrameRef> frames;
  final RasqThemeScope scope;
  final List<RasqThemeTrigger> triggers;
  final RasqThemeSource source;

  static const version = 1;

  RasqThemeSpec copyWith({IconThemeBasic? basic, IconThemeExt? ext, bool clearExt = false, List<RasqThemeFrameRef>? frames, RasqThemeScope? scope, List<RasqThemeTrigger>? triggers, RasqThemeSource? source}) => RasqThemeSpec(
        basic: basic ?? this.basic,
        ext: clearExt ? null : (ext ?? this.ext),
        frames: frames ?? this.frames,
        scope: scope ?? this.scope,
        triggers: triggers ?? this.triggers,
        source: source ?? this.source,
      );

  Map<String, Object?> toJson() => {
        'v': version,
        'source': source.name,
        'basic': basic.toJson(),
        if (ext != null) 'ext': _extToJson(ext!),
        if (frames.isNotEmpty) 'frames': [for (final f in frames) f.toJson()],
        'scope': scope.toJson(),
        if (triggers.isNotEmpty) 'triggers': [for (final t in triggers) t.toJson()],
      };

  /// 読めなければ null(知らない版 / 形が違う)。
  static RasqThemeSpec? fromJson(Object? json) {
    if (json is! Map) return null;
    final v = json['v'];
    if (v is! int || v > version) return null;
    final basic = _basicFromJson(json['basic']);
    if (basic == null) return null;
    return RasqThemeSpec(
      basic: basic,
      ext: _extFromJson(json['ext']),
      frames: [for (final f in (json['frames'] as List? ?? const [])) ?RasqThemeFrameRef.fromJson(f)],
      scope: RasqThemeScope.fromJson(json['scope']) ?? const RasqThemeScope.profile(),
      triggers: [for (final t in (json['triggers'] as List? ?? const [])) ?RasqThemeTrigger.fromJson(t)],
      source: RasqThemeSource.values.where((s) => s.name == json['source']).firstOrNull ?? RasqThemeSource.iconEmbed,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RasqThemeSpec && other.basic == basic && other.ext == ext && listEquals(other.frames, frames) && other.scope == scope && listEquals(other.triggers, triggers) && other.source == source;

  @override
  int get hashCode => Object.hash(basic, ext, Object.hashAll(frames), scope, Object.hashAll(triggers), source);
}

/// テーマの出どころ。
enum RasqThemeSource {
  /// アイコンの四隅(D-561)。
  iconEmbed,

  /// コミュハッシュタグのテーマ(第4回、フラグで無効)。
  communityTag,

  /// RASQ Atmos のスレッド限定テーマ(第4回、フラグで無効)。
  atmos,

  /// アプリに同梱の見本。
  bundled,
}

/// どこに効くか。
@immutable
class RasqThemeScope {
  const RasqThemeScope.profile() : kind = 'profile', key = null;
  const RasqThemeScope.thread(String rootPostKey) : kind = 'thread', key = rootPostKey;
  const RasqThemeScope.hashtag(String tag) : kind = 'hashtag', key = tag;
  const RasqThemeScope._(this.kind, this.key);

  /// `profile` / `thread`(Atmos: そのスレッドの表示だけ)/ `hashtag`(コミュハッシュタグ)。
  final String kind;
  final String? key;

  Map<String, Object?> toJson() => {'kind': kind, if (key != null) 'key': key};
  static RasqThemeScope? fromJson(Object? j) {
    if (j is! Map) return null;
    final kind = j['kind'], key = j['key'];
    if (kind == 'profile') return const RasqThemeScope.profile();
    if ((kind == 'thread' || kind == 'hashtag') && key is String && key.isNotEmpty) return RasqThemeScope._(kind as String, key);
    return null;
  }

  @override
  bool operator ==(Object other) => other is RasqThemeScope && other.kind == kind && other.key == key;
  @override
  int get hashCode => Object.hash(kind, key);
}

/// 背景に置く SVG 1 つ(D-563)。[svgId] で置き場から引く(中身は持たない)。位置は画面に対する割合(0〜1)。
@immutable
class RasqThemeFrameRef {
  const RasqThemeFrameRef({required this.svgId, this.x = 0.5, this.y = 0.5, this.size = 0.3, this.opacity = 0.6, this.rotation = 0});
  final String svgId;
  final double x;
  final double y;

  /// 短い辺に対する大きさ(0.05〜1)。
  final double size;
  final double opacity;

  /// 度。
  final double rotation;

  static final idPattern = RegExp(r'^[a-z0-9][a-z0-9_.-]{0,63}$');

  Map<String, Object?> toJson() => {'svg': svgId, 'x': x, 'y': y, 'size': size, 'opacity': opacity, if (rotation != 0) 'rotation': rotation};
  static RasqThemeFrameRef? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['svg'];
    if (id is! String || !idPattern.hasMatch(id)) return null;
    double n(Object? v, double def, double lo, double hi) => v is num ? v.toDouble().clamp(lo, hi) : def;
    return RasqThemeFrameRef(svgId: id, x: n(j['x'], 0.5, 0, 1), y: n(j['y'], 0.5, 0, 1), size: n(j['size'], 0.3, 0.05, 1), opacity: n(j['opacity'], 0.6, 0, 1), rotation: n(j['rotation'], 0, -360, 360));
  }

  @override
  bool operator ==(Object other) => other is RasqThemeFrameRef && other.svgId == svgId && other.x == x && other.y == y && other.size == size && other.opacity == opacity && other.rotation == rotation;
  @override
  int get hashCode => Object.hash(svgId, x, y, size, opacity, rotation);
}

/// Atmos のきっかけ(第4回で使う)。
@immutable
class RasqThemeTrigger {
  const RasqThemeTrigger.hashtagBadge({required String this.hashtag, required this.svgId}) : kind = 'hashtagBadge', actionId = null;
  const RasqThemeTrigger.actionAnimation({required String this.actionId, required this.svgId}) : kind = 'actionAnimation', hashtag = null;
  const RasqThemeTrigger._(this.kind, this.svgId, this.hashtag, this.actionId);

  /// `hashtagBadge` = そのハッシュタグの投稿に SVG のアイコンを付ける / `actionAnimation` = そのアクションのボタンで SVG の
  /// アニメーションを再生する。
  final String kind;

  /// 置き場の SVG の ID。
  final String svgId;
  final String? hashtag;
  final String? actionId;

  Map<String, Object?> toJson() => {'kind': kind, 'svg': svgId, if (hashtag != null) 'hashtag': hashtag, if (actionId != null) 'action': actionId};
  static RasqThemeTrigger? fromJson(Object? j) {
    if (j is! Map) return null;
    final svg = j['svg'];
    if (svg is! String || !RasqThemeFrameRef.idPattern.hasMatch(svg)) return null;
    return switch (j['kind']) {
      'hashtagBadge' when j['hashtag'] is String => RasqThemeTrigger._('hashtagBadge', svg, j['hashtag'] as String, null),
      'actionAnimation' when j['action'] is String => RasqThemeTrigger._('actionAnimation', svg, null, j['action'] as String),
      _ => null,
    };
  }

  @override
  bool operator ==(Object other) => other is RasqThemeTrigger && other.kind == kind && other.svgId == svgId && other.hashtag == hashtag && other.actionId == actionId;
  @override
  int get hashCode => Object.hash(kind, svgId, hashtag, actionId);
}

IconThemeBasic? _basicFromJson(Object? j) {
  if (j is! Map) return null;
  List<int>? rgb(Object? v) => v is List && v.length == 3 && v.every((e) => e is int && e >= 0 && e <= 255) ? v.cast<int>() : null;
  int n(Object? v, int def, int max) => v is int && v >= 0 && v <= max ? v : def;
  final bg = rgb(j['bg']), text = rgb(j['text']), accent = rgb(j['accent']);
  if (bg == null || text == null || accent == null) return null;
  final hint = j['hint'];
  return IconThemeBasic(
    bgMode: j['bgMode'] == 'grad' ? IconThemeBg.gradient : IconThemeBg.solid,
    gradient: n(j['grad'], 0, 15),
    bg: bg,
    text: text,
    accent: accent,
    particle: n(j['particle'], 0, 15),
    amount: n(j['amount'], 8, 15),
    speed: n(j['speed'], 4, 15),
    hint: hint is int && hint >= 0 && hint <= 7 ? hint : null,
  );
}

Map<String, Object?> _extToJson(IconThemeExt e) => e.url != null
    ? {'url': e.url}
    : {
        'shapes': [
          for (final s in e.shapes) [for (final c in s) c.toJson()],
        ],
        'paths': e.paths,
        'angle': e.angle,
        'anim': e.anim,
        'animSpeed': e.animSpeed,
        'slots': [
          for (final s in e.slots)
            {'trig': s.trigger.index, 'shape': s.shape, 'path': s.path, 'rand': s.rand, 'arand': s.angleRand, 'ea': s.easeA, 'eb': s.easeB, 'mix': s.mix, 'sway': s.sway, 'spin': s.spin},
        ],
      };

/// JSON の拡張は、アイコンに書けるものと同じ範囲だけ受ける(詰めて書ければ受ける = 同じ検査)。
IconThemeExt? _extFromJson(Object? j) {
  if (j is! Map) return null;
  try {
    final IconThemeExt ext;
    if (j['url'] is String) {
      ext = IconThemeExt.url(j['url'] as String);
    } else {
      int n(Object? v, int max) => v is int && v >= 0 && v <= max ? v : throw const FormatException('range');
      ext = IconThemeExt(
        shapes: [
          for (final s in (j['shapes'] as List))
            [
              for (final c in (s as List))
                () {
                  final cmd = (c as List), op = cmd.first as String;
                  if (!const {'M', 'L', 'Q', 'Z'}.contains(op)) throw const FormatException('op');
                  return IconThemeCmd(op, [for (final a in cmd.skip(1)) n(a, 31)]);
                }(),
            ],
        ],
        paths: [
          for (final p in (j['paths'] as List)) [for (final v in (p as List)) n(v, 31)],
        ],
        angle: n(j['angle'], 15),
        anim: n(j['anim'], 7),
        animSpeed: n(j['animSpeed'], 7),
        slots: [
          for (final s in (j['slots'] as List))
            () {
              final m = s as Map;
              return IconThemeSlot(
                trigger: IconThemeTrigger.values[n(m['trig'], 2)],
                shape: n(m['shape'], 3),
                path: n(m['path'], 3),
                rand: n(m['rand'], 15),
                angleRand: n(m['arand'], 15),
                easeA: n(m['ea'], 3),
                easeB: n(m['eb'], 3),
                mix: n(m['mix'], 7),
                sway: n(m['sway'], 15),
                spin: n(m['spin'], 15),
              );
            }(),
        ],
      );
    }
    final back = iconThemeUnpackExt(iconThemePackExt(ext).$1);
    return back == ext ? ext : null;
  } catch (_) {
    return null;
  }
}
