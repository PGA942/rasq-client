import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../session/rasq_accounts.dart' show currentRasqAccountProvider, rasqAccountsProvider;
import '../../../session/session_providers.dart' show currentAccountProvider, sessionStorageProvider, sessionsProvider;
import '../../../session/session_storage.dart';
import 'model.dart';

/// 落書きの道具の覚え (D-473): 最後に使ったペン先 / 太さ / 色 / 消しゴムの種類 / 手ぶれ補正を、ユーザーごとに端末の KV へ
/// (`svgpaint.prefs.v1.<RASQ アカウントの id か SNS アカウントの key>`、JSON)。
@immutable
class SvgPaintPrefs {
  const SvgPaintPrefs({this.nib = PaintNib.mili, this.size = 1, this.color = 0, this.wholeEraser = false, this.stabilizer = defaultStabilizer});

  /// 手ぶれ補正の強さ(0 = 切、[maxStabilizer] まで)。既定は控えめ。
  static const defaultStabilizer = 3;
  static const maxStabilizer = 10;

  final PaintNib nib;

  /// 太さのボタンの番号。
  final int size;

  /// 色のボタンの番号。
  final int color;
  final bool wholeEraser;
  final int stabilizer;

  SvgPaintPrefs copyWith({PaintNib? nib, int? size, int? color, bool? wholeEraser, int? stabilizer}) => SvgPaintPrefs(
        nib: nib ?? this.nib,
        size: size ?? this.size,
        color: color ?? this.color,
        wholeEraser: wholeEraser ?? this.wholeEraser,
        stabilizer: stabilizer ?? this.stabilizer,
      );

  Map<String, Object> toJson() => {'nib': nib.name, 'size': size, 'color': color, 'wholeEraser': wholeEraser, 'stabilizer': stabilizer};

  /// 読めない値は既定に([sizes] / [colors] はボタンの数)。
  static SvgPaintPrefs fromJson(Object? j, {required int sizes, required int colors}) {
    if (j is! Map) return const SvgPaintPrefs();
    int idx(Object? v, int n, int d) => v is int && v >= 0 && v < n ? v : d;
    final nibName = j['nib'];
    return SvgPaintPrefs(
      nib: PaintNib.values.where((n) => n.name == nibName).firstOrNull ?? PaintNib.mili,
      size: idx(j['size'], sizes, 1),
      color: idx(j['color'], colors, 0),
      wholeEraser: j['wholeEraser'] == true,
      stabilizer: idx(j['stabilizer'], maxStabilizer + 1, defaultStabilizer),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SvgPaintPrefs && other.nib == nib && other.size == size && other.color == color && other.wholeEraser == wholeEraser && other.stabilizer == stabilizer;

  @override
  int get hashCode => Object.hash(nib, size, color, wholeEraser, stabilizer);
}

/// 覚えの置き場(KV とキー)。
class SvgPaintPrefsStore {
  SvgPaintPrefsStore(this.storage, this.key);
  final SessionStorage storage;
  final String key;

  static const keyPrefix = 'svgpaint.prefs.v1';

  /// [context] の上の ProviderScope から、端末の KV と今のユーザーで作る。ProviderScope が無ければ(テスト / プレビュー)null = 覚えない。
  static SvgPaintPrefsStore? of(BuildContext context) {
    final ProviderContainer container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on StateError {
      return null;
    }
    String user = 'default';
    try {
      // アカウントの台帳は、アプリがもう読んでいるときだけ見る(ここから読み込みを始めない)。
      final rasq = container.exists(rasqAccountsProvider) ? container.read(currentRasqAccountProvider)?.id : null;
      final sns = container.exists(sessionsProvider) ? container.read(currentAccountProvider)?.key : null;
      user = rasq ?? sns ?? 'default';
    } on Object {
      // アカウントの読み込みに失敗していても、道具の覚えは共通のキーで続ける。
    }
    return SvgPaintPrefsStore(container.read(sessionStorageProvider), '$keyPrefix.$user');
  }

  Future<SvgPaintPrefs?> load({required int sizes, required int colors}) async {
    try {
      final raw = await storage.read(key);
      if (raw == null) return null;
      return SvgPaintPrefs.fromJson(jsonDecode(raw), sizes: sizes, colors: colors);
    } on Object {
      return null;
    }
  }

  Future<void> save(SvgPaintPrefs p) async {
    try {
      await storage.write(key, jsonEncode(p.toJson()));
    } on Object {
      // 書けなくても描くのは続ける(次に開いたときは既定)。
    }
  }
}
