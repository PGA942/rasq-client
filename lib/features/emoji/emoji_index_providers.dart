import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/limited_http.dart';
import '../compose/compose_providers.dart';
import '../rai/rai_embedding_model.dart';
import '../rai/rai_reference.dart' show NgramRaiEmbedder, RaiEmbedder;
import '../rai/rai_reference_providers.dart';
import '../settings/settings_dsl.dart';
import 'emoji_image_embedder.dart';
import 'emoji_index.dart';

/// 設定エリア (D-290)。`semantic`(既定 true): 絵文字の検索に、意味検索を足す(埋め込みモデルを入れてあるときだけ効く)。
const emojiSearchSettingsArea = 'plugins.emoji';

/// 索引の置き場(`ApplicationSupport/emoji_index`)。テストでは差し替える。
final emojiIndexDirProvider = Provider<Future<Directory> Function()>((ref) => () async {
      final base = await getApplicationSupportDirectory();
      return Directory('${base.path}/emoji_index');
    });

/// 意味検索に使う埋め込み (D-290)。**本物のモデルがあるときだけ**(n-gram の代用は、部分一致より良くならないので使わない)。
final emojiEmbedderProvider = FutureProvider<RaiEmbedder?>((ref) async {
  if (ref.watch(settingsAreaProvider(emojiSearchSettingsArea)).value?['semantic'] == false) return null;
  final e = await ref.watch(raiEmbedderProvider.future);
  return e is NgramRaiEmbedder ? null : e;
});

/// 索引づくりの進み具合(アカウントの key → (済み, 全部))。ピッカーが「準備中」を出すのに使う。
class EmojiIndexProgress extends Notifier<Map<String, (int, int)>> {
  @override
  Map<String, (int, int)> build() => const {};
  void set(String key, int done, int total) => state = {...state, key: (done, total)};
  void clear(String key) => state = {for (final e in state.entries) if (e.key != key) e.key: e.value};
}

final emojiIndexProgressProvider = NotifierProvider<EmojiIndexProgress, Map<String, (int, int)>>(EmojiIndexProgress.new);

String _fileName(String accountKey, RaiEmbedder e) => '${accountKey.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.${e.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.bin';

/// あるアカウントのサーバーの絵文字の索引 (D-290)。
///
/// 1. ディスクの索引を読む(同じモデルで、絵文字の名前が全部入っていれば、そのまま使う)。
/// 2. 足りなければ、**バックグラウンドで埋め込む**(32 件ずつ。モデルの推論は UI スレッドの外で動く)。前の索引のベクトルは使い回す。
/// 3. できたらディスクへ。モデルが変わったら、ファイル名が変わるので作り直しになる。
///
/// 埋め込みモデルが無い / 設定で切っているときは null(検索は、これまでどおりの部分一致だけ)。
final emojiIndexProvider = FutureProvider.family<EmojiEmbeddingIndex?, String?>((ref, accountKey) async {
  final embedder = await ref.watch(emojiEmbedderProvider.future);
  if (embedder == null) return null;
  final List<EmojiInfo> emojis = await ref.watch(customEmojisForProvider(accountKey).future);
  if (emojis.isEmpty) return null;
  final key = accountKey ?? '_current';
  var stopped = false;
  ref.onDispose(() => stopped = true);

  File? file;
  EmojiEmbeddingIndex? cached;
  try {
    final dir = await ref.read(emojiIndexDirProvider)();
    await dir.create(recursive: true);
    file = File('${dir.path}/${_fileName(key, embedder)}');
    if (await file.exists()) cached = EmojiEmbeddingIndex.fromBytes(await file.readAsBytes());
  } catch (e) {
    debugPrint('emoji index: cache unavailable: $e');
  }
  if (cached != null && cached.model == embedder.name) {
    final have = cached.names.toSet();
    if (emojis.every((e) => have.contains(e.name))) return cached;
  }
  final progress = ref.read(emojiIndexProgressProvider.notifier);
  try {
    final built = await EmojiEmbeddingIndex.build(
      emojis: emojis,
      embedder: embedder,
      reuse: cached,
      onProgress: (done, total) => scheduleMicrotask(() {
        if (!stopped) progress.set(key, done, total);
      }),
      shouldStop: () => stopped,
    );
    if (built == null) return cached;
    try {
      await file?.writeAsBytes(built.toBytes(), flush: true);
    } catch (e) {
      debugPrint('emoji index: cannot save: $e');
    }
    return built;
  } catch (e) {
    debugPrint('emoji index: build failed: $e');
    return cached;
  } finally {
    if (!stopped) scheduleMicrotask(() => progress.clear(key));
  }
});

// ── 絵そのものの索引 (D-293) ──

/// 絵の埋め込み器(SigLIP2 の画像側)。**テキスト側も入っているときだけ**(片方だけでは、文と絵を比べられない)。
final emojiImageEmbedderProvider = FutureProvider<EmojiImageEmbedder?>((ref) async {
  if (ref.watch(settingsAreaProvider(emojiSearchSettingsArea)).value?['semantic'] == false) return null;
  final text = ref.watch(emojiTextStatusProvider).value;
  final vision = ref.watch(emojiVisionStatusProvider).value;
  if (text == null || vision == null || !text.ready || !vision.ready) return null;
  final loaded = await ref.watch(emojiImageEmbedderLoaderProvider)(ref.watch(emojiVisionModelProvider));
  if (loaded == null) return null;
  ref.onDispose(loaded.dispose);
  return loaded.embedder;
});

/// 入っているモデルから、絵の埋め込み器を作る口。端末では onnxruntime(`device_overrides_io.dart` が差し替える)。
/// 既定(テスト / Web 版 D-295)は「無い」。
typedef EmojiImageEmbedderLoader = Future<({EmojiImageEmbedder embedder, void Function() dispose})?> Function(RaiEmbeddingModel model);
final emojiImageEmbedderLoaderProvider = Provider<EmojiImageEmbedderLoader>((_) => (_) async => null);

/// 絵の索引と比べる文の埋め込み器(SigLIP2 のテキスト側)。
final emojiImageQueryEmbedderProvider = FutureProvider<RaiEmbedder?>((ref) async {
  final st = ref.watch(emojiTextStatusProvider).value;
  if (st == null || !st.ready) return null;
  return ref.watch(emojiTextModelProvider).embedder();
});

/// 絵文字の絵 1 枚の上限。
const emojiImageMaxBytes = 512 * 1024;

/// 読み途中の絵の本文の合計の上限(全アカウントの索引づくりで共有、D-546)。1 枚ぶんの上限を先に取ってから読むので、
/// 同時に読むのは 8 枚まで(アカウントがいくつあっても)。
const emojiImageInFlightBytes = 8 * emojiImageMaxBytes;

/// 読み途中の本文の大きさの予算。[acquire] で取れるまで順に待ち、読み終えたら [release] で返す。
class EmojiImageFetchBudget {
  EmojiImageFetchBudget(this.maxBytes);
  final int maxBytes;
  int _inFlight = 0;
  final _waiters = <(int, Completer<void>)>[];

  /// いま取ってある大きさ(テスト用)。
  int get inFlight => _inFlight;

  Future<void> acquire(int bytes) {
    if (_waiters.isEmpty && _inFlight + bytes <= maxBytes) {
      _inFlight += bytes;
      return Future.value();
    }
    final c = Completer<void>();
    _waiters.add((bytes, c));
    return c.future;
  }

  void release(int bytes) {
    _inFlight -= bytes;
    while (_waiters.isNotEmpty && _inFlight + _waiters.first.$1 <= maxBytes) {
      final (n, c) = _waiters.removeAt(0);
      _inFlight += n;
      c.complete();
    }
  }
}

final emojiImageFetchBudgetProvider = Provider<EmojiImageFetchBudget>((_) => EmojiImageFetchBudget(emojiImageInFlightBytes));

/// 絵を取ってくる(テストでは差し替える)。大きすぎる絵([emojiImageMaxBytes] 超)と失敗は null。
/// 本文は上限までしか読まない(超えたら読むのをやめて通信を切る。セキュリティ確認 2026-10-21 の #22、D-546)。
final emojiImageFetcherProvider = Provider<Future<Uint8List?> Function(EmojiInfo e)>((ref) {
  final budget = ref.watch(emojiImageFetchBudgetProvider);
  return (e) async {
    await budget.acquire(emojiImageMaxBytes);
    try {
      final res = await getLimited(e.url, maxBytes: emojiImageMaxBytes, timeout: const Duration(seconds: 8));
      return res.statusCode == 200 && res.bodyBytes.isNotEmpty ? res.bodyBytes : null;
    } catch (_) {
      return null;
    } finally {
      budget.release(emojiImageMaxBytes);
    }
  };
});

/// あるアカウントのサーバーの、**絵から作った**絵文字の索引 (D-293)。流れは [emojiIndexProvider] と同じ
/// (ディスク → 足りなければ裏で作る → ディスクへ)。絵は 8 枚ずつ取ってきて埋め込む。進み具合は `<key>#image`。
final emojiImageIndexProvider = FutureProvider.family<EmojiEmbeddingIndex?, String?>((ref, accountKey) async {
  final embedder = await ref.watch(emojiImageEmbedderProvider.future);
  if (embedder == null) return null;
  final List<EmojiInfo> emojis = await ref.watch(customEmojisForProvider(accountKey).future);
  if (emojis.isEmpty) return null;
  final key = '${accountKey ?? '_current'}#image';
  var stopped = false;
  ref.onDispose(() => stopped = true);
  File? file;
  EmojiEmbeddingIndex? cached;
  try {
    final dir = await ref.read(emojiIndexDirProvider)();
    await dir.create(recursive: true);
    file = File('${dir.path}/${(accountKey ?? '_current').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_')}.${embedder.name}.bin');
    if (await file.exists()) cached = EmojiEmbeddingIndex.fromBytes(await file.readAsBytes());
  } catch (e) {
    debugPrint('emoji image index: cache unavailable: $e');
  }
  if (cached != null && cached.model == embedder.name) {
    final have = cached.names.toSet();
    // 読めなかった絵は索引に入らないので、9 割そろっていれば作り直さない(毎回、読めない絵を取りに行かない)。
    if (emojis.where((e) => have.contains(e.name)).length >= emojis.length * 0.9) return cached;
  }
  final progress = ref.read(emojiIndexProgressProvider.notifier);
  try {
    final built = await EmojiEmbeddingIndex.buildFromImages(
      emojis: emojis,
      model: embedder.name,
      fetch: ref.read(emojiImageFetcherProvider),
      embed: embedder.embedImages,
      reuse: cached,
      onProgress: (done, total) => scheduleMicrotask(() {
        if (!stopped) progress.set(key, done, total);
      }),
      shouldStop: () => stopped,
    );
    if (built == null) return cached;
    try {
      await file?.writeAsBytes(built.toBytes(), flush: true);
    } catch (e) {
      debugPrint('emoji image index: cannot save: $e');
    }
    return built;
  } catch (e) {
    debugPrint('emoji image index: build failed: $e');
    return cached;
  } finally {
    if (!stopped) scheduleMicrotask(() => progress.clear(key));
  }
});

/// 検索の文 → 絵文字の点数(名前 → コサイン)。索引が無ければ空。打つたびに呼ばれるので、文の埋め込みは 1 回ずつ。
final emojiSearchProvider = FutureProvider.autoDispose.family<Map<String, double>, ({String? accountKey, String query})>((ref, k) async {
  final q = k.query.trim();
  if (q.length < 2) return const {};
  // 絵の索引 (D-293) があれば、その点数も合わせる。
  final byImage = await ref.watch(_emojiImageSearchProvider(k).future);
  final index = await ref.watch(emojiIndexProvider(k.accountKey).future);
  final embedder = await ref.watch(emojiEmbedderProvider.future);
  if (index == null || embedder == null || index.length == 0) return byImage;
  // 打っている途中の連打を間引く(次の 1 文字が来たら、この provider は捨てられる)。
  var alive = true;
  ref.onDispose(() => alive = false);
  await Future<void>.delayed(const Duration(milliseconds: 180));
  if (!alive) return const {};
  final v = await embedder.embed([q]);
  return mergeEmojiScores(v.isEmpty ? const {} : index.scores(v.first), byImage);
});

/// 文 → 絵の点数。SigLIP の「文と絵」のコサインは、文どうしより小さい値に出る(合っていても 0.1 前後)ので、
/// **上位だけ**を取り、並びを保ったまま、部分一致のうしろに足せる点数([imageScoreFloor] 以上)へ写す。
final _emojiImageSearchProvider = FutureProvider.autoDispose.family<Map<String, double>, ({String? accountKey, String query})>((ref, k) async {
  final index = await ref.watch(emojiImageIndexProvider(k.accountKey).future);
  final embedder = await ref.watch(emojiImageQueryEmbedderProvider.future);
  if (index == null || embedder == null || index.length == 0) return const {};
  var alive = true;
  ref.onDispose(() => alive = false);
  await Future<void>.delayed(const Duration(milliseconds: 180));
  if (!alive) return const {};
  final v = await embedder.embed([k.query.trim()]);
  return v.isEmpty ? const {} : rescaleImageScores(index.scores(v.first));
});
