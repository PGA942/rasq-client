import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_ml/rasq_ml.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'package:plugin_runtime/plugin_runtime.dart' show WasmSnsSession;

import '../child_safe/child_gate.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../learning/relational_cloud.dart';
import '../../app/providers.dart';
import '../plugins/slot_plugins.dart';
import '../rai/prompts/rai_prompts.dart' show raiPrompts;
import '../../session/session_providers.dart';
import '../home/post_duplicates.dart';
import '../home/timeline_providers.dart';
import '../nodeprog/node_executor.dart';
import '../nodeprog/node_graph.dart';
import '../nodeprog/node_tabs.dart';
import '../settings/settings_dsl.dart';
import 'relational_engine.dart';
import 'post_embeddings.dart';
import 'relational_ml.dart';
import 'relational_wasm.dart';
import '../trend/tendency_profile.dart';

/// 設定の永続化キー(FOW チューニングの実測値をセッションを跨いで保持)。
const relationalSettingsStorageKey = 'relational.settings.v1';

class RelationalSettingsStore extends Notifier<RelationalSettings> {
  @override
  RelationalSettings build() {
    // 同期 build なので保存値は後追いで復元(壊れた値は既定のまま)。
    Future(() async {
      try {
        final raw = await ref.read(sessionStorageProvider).read(relationalSettingsStorageKey);
        if (raw != null) state = RelationalSettings.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
      } catch (_) {}
    });
    return const RelationalSettings();
  }

  void set(RelationalSettings next) {
    state = next;
    ref.read(sessionStorageProvider).write(relationalSettingsStorageKey, jsonEncode(next.toJson()));
  }

  void reset() => set(const RelationalSettings());
}

final relationalSettingsProvider = NotifierProvider<RelationalSettingsStore, RelationalSettings>(RelationalSettingsStore.new);

/// 遡り表示の窓(分)。0 = 通常(ACTIVE のみ)。リスト末尾(または空の状態)で
/// 引っ張るたびに +30 分ずつ広がり、TTL で沈んだ過去の空リプ会話も表示に
/// 含める(D-028: アクティブフォロイーが少ないとき対策)。リフレッシュで戻る。
class RelationalLookbackStore extends Notifier<int> {
  static const stepMinutes = 30;
  static const maxMinutes = 12 * 60;

  @override
  int build() => 0;

  /// 1 段階(30分)遡る。広がったら true。
  bool extend() {
    if (state >= maxMinutes) return false;
    state = (state + stepMinutes).clamp(0, maxMinutes);
    return true;
  }

  void reset() => state = 0;
}

final relationalLookbackProvider = NotifierProvider<RelationalLookbackStore, int>(RelationalLookbackStore.new);

/// 直近 10 分の HTL 流入投稿数(D-024 追補「HTL アクティブ数」— ローカル
/// SigLIP 実行の可否判定に使う)。
int activeHtlPostCount(Ref ref, {DateTime? now}) {
  final posts = ref.read(timelineProvider(TimelineKind.home)).value?.posts ?? const [];
  final cutoff = (now ?? DateTime.now()).subtract(const Duration(minutes: 10));
  return posts.where((p) => p.createdAt.isAfter(cutoff)).length;
}

/// ML ゲートウェイ (D-024)。`--dart-define=RASQ_ML_BASE_URL=https://…` を
/// 渡すと Triton(+vLLM)実配線、無指定なら null(ルールベースのみで動く)。
/// マニフェストは同梱アセット(assets/models/*.model.json)。
///
/// ローカル SigLIP: `DevicePolicy`(CPU < 75% かつ HTL アクティブ数 ≤ 30)で
/// 判定。サーバー未構成ならローカルへ倒す(試験手段がローカルしか無いため)。
/// デバイス実行器そのもの(onnx runtime + GPU/NPU EP)はモデル実体の配布
/// (M4 ストア)と同時に `device:` へ注入する。
final mlGatewayProvider = FutureProvider<MlGateway?>((ref) async {
  const baseUrl = String.fromEnvironment('RASQ_ML_BASE_URL');
  if (baseUrl.isEmpty) return null;
  final manifests = <String, MlModelManifest>{};
  for (final asset in ['assets/models/gliner-ner.model.json', 'assets/models/siglip-similarity.model.json', 'assets/models/astell-summarizer.model.json']) {
    final m = MlModelManifest.fromJson((jsonDecode(await rootBundle.loadString(asset)) as Map).cast<String, Object?>());
    manifests[m.id] = m;
  }
  final base = Uri.parse(baseUrl);
  return MlGateway(
    manifests: manifests,
    triton: TritonExecutor(baseUrl: base),
    vllm: VllmExecutor(baseUrl: base),
    policy: const DevicePolicy(maxCpuUsage: 0.75, maxActiveHtlPosts: 30),
    cpuProbe: const ProcStatCpuProbe(),
    activeHtlPosts: () => activeHtlPostCount(ref),
  );
});

/// EMA の永続化キー(セッションを跨いでフォロイーの話題傾向を持ち回る)。
const relationalEmaStorageKey = 'relational.ema.v1';

/// 復元済み EMA ストア。壊れた保存値は新品にフォールバック。
final relationalEmaStoreProvider = FutureProvider<FolloweeEmbeddingStore>((ref) async {
  try {
    final raw = await ref.watch(sessionStorageProvider).read(relationalEmaStorageKey);
    if (raw != null) {
      return FolloweeEmbeddingStore.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    }
  } catch (_) {}
  return FolloweeEmbeddingStore();
});

/// SigLIP EMA + Louvain の解析結果(ゲートウェイ無し/失敗時は null)。
/// 解析のたびに EMA を保存する。
final relationalMlProvider = FutureProvider<RelationalMlResult?>((ref) async {
  // サーバーの ML ゲートウェイが先。無ければ端末の埋め込み(本文 + 画像、D-390)。どちらも無ければルールベース。
  final gateway = await ref.watch(mlGatewayProvider.future);
  final device = gateway == null ? await ref.watch(postEmbedderProvider.future) : null;
  if (gateway == null && device == null) return null;
  final home = await ref.watch(timelineProvider(TimelineKind.home).future);
  try {
    final store = await ref.watch(relationalEmaStoreProvider.future);
    final pipeline = RelationalMlPipeline(gateway: gateway, embedPosts: device?.embedPosts, store: store);
    final result = await pipeline.analyze(home.posts);
    await ref.read(sessionStorageProvider).write(relationalEmaStorageKey, jsonEncode(store.toJson()));
    return result;
  } on MlUnavailableException {
    return null; // サーバー不達 → ルールベースに縮退
  } catch (e) {
    if (gateway != null) rethrow;
    debugPrint('relational: 端末の埋め込みに失敗: $e');
    return null; // 端末のモデルが回らない → ルールベースに縮退
  }
});

/// フォロイーTL(home)から**会話イベント**を組む (D-027)。
/// GTL/LTL 候補の連結は廃止(人気話題が複数コミュニティを誤結合するハブに
/// なるため)。ML 解析があれば SigLIP 類似度と Louvain コミュニティ
/// (事前分布)がリンク採点に入る。
/// イベントの ASTell 要約(D-029)。イベント id ごとに 1 回だけ計算する
/// (`ref.read` なので投稿追加では再要約しない — 実測後に見直し)。
/// ゲートウェイ未構成/実行手段なしは null → カードは要約なしで表示。
final eventSummaryProvider = FutureProvider.family<String?, String>((ref, eventId) async {
  final gateway = await ref.watch(mlGatewayProvider.future);
  if (gateway == null) return null;
  final events = ref.read(conversationEventsProvider).value ?? const [];
  ConversationEvent? event;
  for (final e in events) {
    if (e.id == eventId) {
      event = e;
      break;
    }
  }
  if (event == null) return null;
  final text = [for (final p in event.posts.take(12)) '${p.author.displayName}: ${p.body}'].join('\n');
  return gateway.summarize(raiPrompts.eventSummary(text));
});

/// リノート/引用で運ばれてきた**非フォロイー(ゲスト)**の自前投稿 (D-046)。
/// 「引用されたタイミングより前に話題について投稿していたら、遡ってページに
/// 適用」のための供給源: 最近紹介されたゲストから最大 [maxGuests] 人の
/// userPosts を引き、紹介時刻の 12 時間前まで遡って返す。エンジン側で
/// 既存イベントへのリンクのみ(+guestBias で厳しめ)を許す。
/// 紹介が古いゲストはそもそも取得しない = 追跡が自然に終わる(脱退)。
final relationalGuestPostsProvider = FutureProvider<List<Post>>((ref) async {
  const maxGuests = 8;
  // チャイルドセーフ (D-407、指摘 #26 / #27): ゲストの過去投稿も、ホームと同じ保護者の表示制限を通す。
  final gate = ref.watch(childGateProvider);
  final session = ref.watch(currentSnsSessionProvider);
  final home = ref.watch(timelineProvider(TimelineKind.home)).value;
  if (session == null || home == null || home.posts.isEmpty) return const [];
  final myKey = ref.watch(currentUserProvider).key;

  // フォロイー = 自分の HTL に直接投稿が流れる人(非 RT の著者)+ リノート主。
  final followees = <String>{};
  for (final p in home.posts) {
    followees.add(p.repostedBy?.key ?? p.author.key);
  }
  // ゲスト = RT で運ばれた著者 / 引用先の著者(フォロイー・自分を除く)。
  final guests = <String, UserSummary>{};
  final introducedAt = <String, DateTime>{};
  void consider(UserSummary u, DateTime at) {
    if (followees.contains(u.key) || u.key == myKey) return;
    guests[u.key] = u;
    final prev = introducedAt[u.key];
    if (prev == null || at.isAfter(prev)) introducedAt[u.key] = at;
  }

  for (final p in home.posts) {
    if (p.repostedBy != null) consider(p.author, p.createdAt);
    if (p.quote != null) consider(p.quote!.author, p.createdAt);
  }
  if (guests.isEmpty) return const [];

  final ranked = guests.keys.toList()..sort((a, b) => introducedAt[b]!.compareTo(introducedAt[a]!));
  final fetched = await Future.wait([
    for (final key in ranked.take(maxGuests))
      session.userPosts(guests[key]!.id, limit: 20).then((page) {
        final since = introducedAt[key]!.subtract(const Duration(hours: 12));
        return [for (final q in page.items) if (q.createdAt.isAfter(since)) q];
      }).catchError((_) => const <Post>[]),
  ]);
  return gate.filterPosts([for (final list in fetched) ...list]);
});

/// アカウントバンドル供給 (M5f / D-086): 関連TL は「バンドルに含まれる
/// **全アカウント**の TL 系を見る」特別枠 — 現在アカウントの HTL に加え、
/// 他のログイン済みアカウントの HTL も混ぜる(失敗アカウントは無視)。
/// 同一投稿の重複は 著者キー+投稿id で除外(同一インスタンスの複数
/// アカウントが同じ会話を見ているケース)。
final bundleFolloweePostsProvider = FutureProvider<List<Post>>((ref) async {
  // チャイルドセーフ (D-407、指摘 #26 / #27): ほかのアカウントのホームも、同じ保護者の表示制限を通す。
  final gate = ref.watch(childGateProvider);
  final home = ref.watch(timelineProvider(TimelineKind.home)).value?.posts ?? const <Post>[];
  final sessions = ref.watch(sessionsProvider).value;
  final current = sessions?.current;
  final registry = ref.watch(pluginRegistryProvider);
  // await の後で ref を使わない (D-205: 実機で「Ref after disposed」)。
  final alternates = ref.read(postAlternatesProvider.notifier);
  final out = [...home];
  final seen = {for (final p in home) '${p.author.key}/${p.id}'};
  // 中身比較の同定 (D-110): 複数アカウントに流れてきた同じ投稿は隠して
  // ↓(アカウント選択)の選択肢へ回す(関連TLの表示崩れ対策)。
  final byDup = <String, Post>{for (final p in home) postDupKey(p): p};
  final dropped = <String, List<Post>>{};
  for (final s in sessions?.sessions ?? const <AccountSession>[]) {
    if (s.account == current?.account) continue;
    try {
      final page = await registry.session(s).timeline(TimelineKind.home, limit: 20);
      for (final p in page.items) {
        if (!seen.add('${p.author.key}/${p.id}')) continue;
        final kept = byDup[postDupKey(p)];
        if (kept != null) {
          dropped.putIfAbsent(kept.key, () => []).add(p);
          continue;
        }
        byDup[postDupKey(p)] = p;
        out.add(p);
      }
    } catch (e) {
      debugPrint('bundle TL ${s.account.key}: $e');
    }
  }
  if (dropped.isNotEmpty) {
    Future.microtask(() => alternates.recordAll(dropped));
  }
  return gate.filterPosts(out);
});

/// wasm エンジン (M5f / D-084) での構築。ML(SigLIP/Louvain)が効いている
/// とき・モジュール不達時は null → Dart エンジンに縮退する。
final wasmConversationEventsProvider = FutureProvider<List<ConversationEvent>?>((ref) async {
  final ml = ref.watch(relationalMlProvider).value;
  if (ml != null) return null; // ML はホスト側資産 — カルクレーター統合後に wasm から ml.infer
  final controller = ref.watch(relationalWasmProvider).value;
  if (controller == null) return null;
  final settings = ref.watch(relationalSettingsProvider);
  final lookbackMinutes = ref.watch(relationalLookbackProvider);
  final home = ref.watch(timelineProvider(TimelineKind.home)).value;
  if (home == null) return null;
  // 前段絞り込み (D-102) > バンドル供給 (D-086) > 現在分、の順で使う。
  // 入口でもう一度、保護者の表示制限 (D-407、指摘 #26 / #27): 前段絞り込み(ノードの取得)を含むどの供給源からも、
  // 見せない投稿を会話イベントへ入れない。方針が変われば作り直す。
  final gate = ref.watch(childGateProvider);
  final followees = gate.filterPosts(ref.watch(relationalInputPostsProvider).value ?? home.posts);
  final guests = gate.filterPosts(ref.watch(relationalGuestPostsProvider).value ?? const <Post>[]);
  try {
    return await buildEventsViaWasm(
      controller,
      followees: followees,
      guests: guests,
      settings: settings,
      now: DateTime.now(),
      lookback: lookbackMinutes > 0 ? Duration(minutes: lookbackMinutes) : null,
    );
  } catch (e) {
    debugPrint('relational.build (wasm): $e');
    return null;
  }
});

/// 関連 TL の前段絞り込み (D-102): `tl.relational` スコープのノードグラフに
/// 「取得 →(加工)→ **関連タイムライン**」の完成した鎖があれば、その出力を
/// フォロイー入力の代わりに使う。処理系(会話イベント構築)はそのまま。
/// 鎖が無ければ null → 従来どおりバンドル/HTL。
/// 関連 TL の入力 (D-153): 前段絞り込み > バンドル供給 の結果に指向性/刺激性の
/// プロファイルを掛けたもの(効かない設定なら素通し)。
final relationalInputPostsProvider = FutureProvider<List<Post>?>((ref) async {
  final base = ref.watch(relationalNodePostsProvider).value ?? ref.watch(bundleFolloweePostsProvider).value;
  if (base == null) return null;
  final profile = await ref.watch(tendencyProfileProvider.future);
  return applyTendencyProfile(base, profile);
});

final relationalNodePostsProvider = FutureProvider<List<Post>?>((ref) async {
  final session = ref.watch(currentSnsSessionProvider);
  if (session == null) return null;
  final home = ref.watch(timelineProvider(TimelineKind.home)).value;
  try {
    // アカウント分離 (D-108): 現在アカウントの領域(旧共有領域は読み取り
    // フォールバック)。
    final accKey = ref.watch(currentAccountProvider)?.key;
    final raw = await readNodeGraphRaw((a) => ref.read(settingsAreaProvider(a).future), accKey, 'tl.relational');
    if (raw is! String) return null;
    final graph = NodeGraph.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
    final storageArea = storageSafeAreaFor(accKey);
    SnsSession? sessionForAccount(String label) {
      final s = ref.read(sessionsProvider).value?.sessions.where((x) => '${x.account}' == label || x.account.key == label).firstOrNull;
      return s == null ? null : ref.read(pluginRegistryProvider).session(s);
    }

    return await runNodeGraph(
      graph,
      terminal: 'timeline.relational',
      fetch: (kid) => resolveNodeFetch(session, kid, selfKindId: 'home', selfItems: home?.posts ?? const [], sessionFor: sessionForAccount, kindBlocked: childKindBlocked(ref.read(childGateProvider))),
      fetchTrends: () async => [for (final t in await session.trendingTags()) t.tag],
      pluginSort: (id, posts, params) => id.startsWith('slot:') ? ref.read(slotPluginsProvider.notifier).sortById(id, posts, params: params) : (session is WasmSnsSession ? session.timelinePlugin.compose(id, posts) : Future.value(posts)),
      storageRead: (slot) async {
        final own = (await ref.read(settingsAreaProvider(storageArea).future))[slot];
        if (own != null) return own;
        return (await ref.read(settingsAreaProvider('storage.safe').future))[slot];
      },
      storageWrite: (slot, value) => ref.read(settingsAreaProvider(storageArea).notifier).set(slot, value),
      loadFunction: (fnId) => loadFunctionBody((a) => ref.read(settingsAreaProvider(a).future), fnId), // カスタム関数の中身 (D-118)
    );
  } catch (e) {
    debugPrint('nodeprog(tl.relational): $e');
    return null;
  }
});

/// いま組んである会話イベント (D-508)。関連 TL(など、[conversationEventsProvider] を見ている画面)が組んだものを写す。
/// 学習への貢献 (D-367) はこちらを見る: 見ても会話を組ませない(前は貢献が [conversationEventsProvider] をずっと見ていて、
/// 関連 TL を開いていなくても、フォロー中の TL が更新されるたびにゲストの投稿を取りに行き、会話を組み直していた)。
class LatestConversationEvents extends Notifier<List<ConversationEvent>> {
  LatestConversationEvents([this._initial = const []]);
  final List<ConversationEvent> _initial;

  @override
  List<ConversationEvent> build() => _initial;

  void set(List<ConversationEvent> events) => state = events;
}

final latestConversationEventsProvider = NotifierProvider<LatestConversationEvents, List<ConversationEvent>>(LatestConversationEvents.new);

/// [events] を [latestConversationEventsProvider] へ(provider の中から状態を変えないよう、次のマイクロタスクで)。
void _publishEvents(Ref ref, List<ConversationEvent> events) => scheduleMicrotask(() {
      if (ref.mounted) ref.read(latestConversationEventsProvider.notifier).set(events);
    });

final conversationEventsProvider = Provider<AsyncValue<List<ConversationEvent>>>((ref) {
  final settings = ref.watch(relationalSettingsProvider);
  final lookbackMinutes = ref.watch(relationalLookbackProvider);
  final home = ref.watch(timelineProvider(TimelineKind.home));
  final ml = ref.watch(relationalMlProvider).value;
  // 取得が終わるまではゲスト無しで組み、届いたら再構築(表示を待たせない)。
  // 入口でもう一度、保護者の表示制限 (D-407、指摘 #26 / #27)。方針が変われば作り直す。
  final gate = ref.watch(childGateProvider);
  final guests = gate.filterPosts(ref.watch(relationalGuestPostsProvider).value ?? const <Post>[]);

  // wasm エンジンの結果があればそれを使う (M5f / D-084 特別枠)。
  final wasmEvents = ref.watch(wasmConversationEventsProvider).value;
  if (wasmEvents != null) {
    _publishEvents(ref, wasmEvents);
    return AsyncData(wasmEvents);
  }

  return home.whenData((h) {
    // 前段絞り込み (D-102) > バンドル供給 (D-086) > 現在分、の順で使う。
    final followees = gate.filterPosts(ref.watch(relationalInputPostsProvider).value ?? h.posts);
    // クラウド版 (D-367): 貢献に同意した人は、しきい値の近くの結び付きをクラウドの判定で決め直す。
    final decisions = ref.watch(relationalCloudDecisionsProvider);
    final engine = ConversationEngine(settings: settings, semantic: ml?.postSimilarity, communityOf: ml?.communityOf, decisions: decisions);
    final events = engine.build(followeePosts: followees, guestPosts: guests, lookback: lookbackMinutes > 0 ? Duration(minutes: lookbackMinutes) : null);
    final borderline = [...engine.borderline];
    if (borderline.isNotEmpty) {
      // provider の中から状態を変えないよう、次のマイクロタスクで渡す。
      scheduleMicrotask(() {
        if (ref.mounted) ref.read(relationalCloudProvider.notifier).offer(borderline);
      });
    }
    _publishEvents(ref, events);
    return events;
  });
});

/// 会話イベントのうち、いまの保護者の表示制限で見せてよい投稿 (D-407、指摘 #26 / #27)。イベントは制限を通した投稿から
/// 組むが、方針が変わった直後 / 古いイベント(画面遷移で渡したもの)にも、表示の直前でもう一度掛ける。
/// ROOT(題・本文の元)が見せないものなら、イベントごと出さない(null)。
List<Post>? childSafeEventPosts(ChildGate gate, ConversationEvent e) {
  if (e.posts.isEmpty || gate.postHidden(e.root)) return null;
  final visible = gate.filterPosts(e.posts);
  return visible.isEmpty ? null : visible;
}

/// [posts] の参加メンバー(著者 + リノート主、[ConversationEvent.members] と同じ順)。
List<UserSummary> eventMembersOf(List<Post> posts) {
  final seen = <String>{};
  return [
    for (final p in posts) ...[
      if (seen.add(p.author.key)) p.author,
      if (p.repostedBy != null && seen.add(p.repostedBy!.key)) p.repostedBy!,
    ],
  ];
}
