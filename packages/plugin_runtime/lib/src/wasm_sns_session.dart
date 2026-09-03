import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import 'wasm_timeline_plugin.dart';

/// プラグインへの `call` の実行口(同期/非同期コントローラの `invoke` を
/// そのまま渡す)。戻りは boundary の `result` メッセージ。
typedef WasmSnsInvoke = Future<Map<String, dynamic>> Function(String fn, Map<String, Object?> args);

/// SnsSession 契約の wasm 境界写像 v1 (D-074 / M5d)。
///
/// 基本思想の「SNS プラグインのイベントハンドラー関数は一定程度は抽象的な
/// 関数で共通化 → 既存 SnsSession 契約の boundary 写像として wasm 化」の
/// 実装形: 抽象関数を `call("sns.<fn>")` に写し、戻りの Post ワイヤ
/// (`rasq.post/1`、[SnsWire])をホストモデルへ取り込む。
///
/// v1 は `timeline` のみ — 以降の関数(thread / createPost / performAction
/// …)は同じ形で 1 本ずつ増やす。未実装は [UnsupportedError] のまま
/// (ホストが UI を隠す既定動作)。
class WasmSnsSession extends SnsSessionBase {
  WasmSnsSession({required this.account, required WasmSnsInvoke invoke, this.pluginId = 'wasm', this.extraArgs = const {}, Future<void> Function()? onClose})
      : _invoke = invoke, // ignore: prefer_initializing_formals
        // ignore: prefer_initializing_formals
        _onClose = onClose;

  @override
  final AccountId account;

  @override
  final String pluginId;

  final WasmSnsInvoke _invoke;

  /// 毎呼び出しに足す引数(接続先 host / 認証 token / dev の baseUrl 等)。
  final Map<String, Object?> extraArgs;

  final Future<void> Function()? _onClose;

  @override
  Future<void> close() async => _onClose?.call();

  /// 同じ wasm モジュールが提供する**タイムラインレンダラー契約**の口
  /// (M5e / D-080)。SNS プラグインは自分のカスタム TL(宣言 + ソート)も
  /// 持てる — 独立 TL プラグインの常設インストールはストア統合(M4)側。
  late final WasmTimelinePlugin timelinePlugin = WasmTimelinePlugin(invoke: _invoke, extraArgs: extraArgs);

  @override
  List<TimelineKind> get timelines => const [TimelineKind.local];

  List<ActionDescriptor> _actions = const [];

  /// `sns.actions` で宣言されたアクションバーのボタン (D-075)。
  /// [loadActions] 前(または未実装プラグイン)は空 = ホストはバー無しで
  /// 描画する。
  @override
  List<ActionDescriptor> get actions => _actions;

  /// `call("sns.actions")` → [ActionDescriptor] 群を取り込む(宣言 JSON は
  /// register_action と同形)。未実装(C01)は空のまま。
  Future<void> loadActions() async {
    try {
      final value = await _call('sns.actions', const {});
      _actions = [
        for (final a in (value['actions'] as List? ?? const [])) ActionDescriptor.fromJson((a as Map).cast<String, Object?>()),
      ];
    } on SnsApiException catch (e) {
      if (e.code.code != 'C01') rethrow;
      _actions = const [];
    }
  }

  /// `call("sns.<fn>")` → ok チェック → value。エラーは [SnsApiException]
  /// に写す(ホストのエラービュー/リトライがそのまま効く)。
  Future<Map<String, Object?>> _call(String fn, Map<String, Object?> args) async {
    final result = await _invoke(fn, {...args, ...extraArgs});
    if (result['ok'] == true) return (result['value'] as Map? ?? const {}).cast<String, Object?>();
    final error = (result['error'] as Map?)?.cast<String, Object?>() ?? const {};
    final message = '${error['message'] ?? 'wasm sns call failed: $fn'}';
    throw SnsApiException(ErrorCode.tryParse('${error['code'] ?? ''}', message: message) ?? ErrorCode.internalServerError.copyWith(message: message));
  }

  bool _actionsLoaded = false;

  @override
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20}) async {
    // 実登録セッション (D-079): 最初の TL 取得前にアクション宣言を取り込む
    // (TL 画面はこの await 後に session.actions を読むので間に合う)。
    if (!_actionsLoaded) {
      _actionsLoaded = true;
      try {
        await loadActions();
      } catch (_) {} // 宣言が取れなくてもバー無しで TL は出す
    }
    final value = await _call('sns.timeline', {'kind': kind.id, 'limit': limit, 'cursor': ?cursor});
    final page = (value['page'] as Map? ?? const {}).cast<String, Object?>();
    _harvestRepostTargets(page);
    return SnsWire.pageFrom(page, account: account);
  }

  /// 純リノートのアクション読み替え (D-112): ワイヤの `repostTargetId` を
  /// 採取し、アクション/スレッド/各欄は**中身のノート**へ向ける(公式
  /// クライアントの appearNote と同じ。Misskey セッションの D-111 と対)。
  final Map<String, String> _repostTarget = {};

  void _harvestRepostTargets(Map<String, Object?> page) {
    for (final item in (page['items'] as List? ?? const [])) {
      if (item is Map && item['id'] is String && item['repostTargetId'] is String) {
        _repostTarget[item['id'] as String] = item['repostTargetId'] as String;
      }
    }
  }

  String _actionTarget(String postId) => _repostTarget[postId] ?? postId;

  @override
  Future<Thread> thread(String id) async {
    final value = await _call('sns.thread', {'id': _actionTarget(id)});
    return SnsWire.threadFrom((value['thread'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  @override
  Future<Post> post(String id) async => (await thread(id)).post;

  @override
  Future<ActionResult> performAction(String actionId, String postId, {Map<String, Object?> args = const {}}) async {
    postId = _actionTarget(postId); // 純リノートは中身のノートへ (D-112)
    final value = await _call('sns.performAction', {'actionId': actionId, 'postId': postId, 'args': args});
    final r = (value['result'] as Map? ?? const {}).cast<String, Object?>();
    return ActionResult(done: r['done'] == true, count: (r['count'] as num?)?.toInt(), message: r['message'] as String?);
  }

  // ---- 書き込み系 (D-076) ----------------------------------------------

  @override
  Future<Post> createPost(NewPost draft) async {
    final value = await _call('sns.createPost', {'draft': SnsWire.newPost(draft)});
    return SnsWire.postFrom((value['post'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  @override
  Future<void> deletePost(String id) async {
    await _call('sns.deletePost', {'id': id});
  }

  // ---- ユーザー系 (D-076) ----------------------------------------------

  @override
  Future<UserSummary> me() async {
    final value = await _call('sns.me', const {});
    return SnsWire.userFrom((value['user'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<UserProfile> user(String id) async {
    final value = await _call('sns.user', {'id': id});
    return SnsWire.profileFrom((value['profile'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  @override
  Future<UserProfile?> userByHandle(String handle, {String? host}) async {
    try {
      // 接続先(extraArgs の host)と衝突しないよう、ユーザーの所属ホストは
      // userHost で渡す。
      final value = await _call('sns.user', {'handle': handle, 'userHost': ?host});
      return SnsWire.profileFrom((value['profile'] as Map? ?? const {}).cast<String, Object?>(), account: account);
    } on SnsApiException catch (e) {
      if (e.code.code == '404') return null;
      rethrow;
    }
  }

  @override
  Future<Page<Post>> userPosts(String id, {String? cursor, int limit = 20, UserPostsFilter filter = UserPostsFilter.posts}) async {
    final value = await _call('sns.userPosts', {'id': id, 'filter': filter.name, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  // ---- スレッド画面の欄 (D-070 対応、D-076) ------------------------------

  @override
  Future<Page<ReactionEntry>> reactions(String postId, {String? type, String? cursor, int limit = 30}) async {
    postId = _actionTarget(postId); // D-112
    final value = await _call('sns.reactions', {'postId': postId, 'type': ?type, 'limit': limit, 'cursor': ?cursor});
    final page = (value['page'] as Map? ?? const {}).cast<String, Object?>();
    return Page(
      items: [for (final e in (page['items'] as List? ?? const [])) SnsWire.reactionEntryFrom((e as Map).cast<String, Object?>())],
      nextCursor: page['nextCursor'] as String?,
    );
  }

  @override
  Future<Page<UserSummary>> reposters(String postId, {String? cursor, int limit = 30}) async {
    postId = _actionTarget(postId); // D-112
    final value = await _call('sns.reposters', {'postId': postId, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.userPageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<Page<Post>> quotes(String postId, {String? cursor, int limit = 30}) async {
    postId = _actionTarget(postId); // D-112
    final value = await _call('sns.quotes', {'postId': postId, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  // --- カスタム絵文字 (D-111): wasm 側で取得できない問題の修正 ---

  Map<String, Uri>? _emojis;

  /// `call("sns.emojis")` → `{emojis: [{name, url, category?, aliases?}]}`。
  /// 未実装プラグイン(C01 等)は空に縮退する。
  @override
  Future<List<EmojiInfo>> customEmojis() async {
    try {
      final value = await _call('sns.emojis', {});
      final list = <EmojiInfo>[];
      for (final e in (value['emojis'] as List? ?? const [])) {
        if (e is! Map || e['name'] is! String || e['url'] is! String) continue;
        final url = Uri.tryParse(e['url'] as String);
        if (url == null) continue;
        list.add(EmojiInfo(name: e['name'] as String, url: url, category: e['category'] as String?, aliases: [for (final a in (e['aliases'] as List? ?? const [])) a.toString()]));
      }
      _emojis ??= {for (final e in list) e.name: e.url};
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// ショートコード → URL。一覧に無いローカルカスタムは Misskey 系の
  /// `/emoji/<name>.webp` に縮退する(接続先 host は extraArgs)。
  @override
  Future<Uri?> emojiUrl(String shortcode) async {
    if (_emojis == null) await customEmojis();
    final name = shortcode.replaceAll('@.', '');
    final hit = _emojis?[name];
    if (hit != null) return hit;
    final host = extraArgs['host'];
    if (host is String && host.isNotEmpty && account.kind == SnsKind.misskey) {
      return Uri.https(host, '/emoji/$name.webp');
    }
    return null;
  }
}
