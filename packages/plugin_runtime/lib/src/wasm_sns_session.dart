import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

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
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  @override
  Future<Thread> thread(String id) async {
    final value = await _call('sns.thread', {'id': id});
    return SnsWire.threadFrom((value['thread'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  @override
  Future<Post> post(String id) async => (await thread(id)).post;

  @override
  Future<ActionResult> performAction(String actionId, String postId, {Map<String, Object?> args = const {}}) async {
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
    final value = await _call('sns.reactions', {'postId': postId, 'type': ?type, 'limit': limit, 'cursor': ?cursor});
    final page = (value['page'] as Map? ?? const {}).cast<String, Object?>();
    return Page(
      items: [for (final e in (page['items'] as List? ?? const [])) SnsWire.reactionEntryFrom((e as Map).cast<String, Object?>())],
      nextCursor: page['nextCursor'] as String?,
    );
  }

  @override
  Future<Page<UserSummary>> reposters(String postId, {String? cursor, int limit = 30}) async {
    final value = await _call('sns.reposters', {'postId': postId, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.userPageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<Page<Post>> quotes(String postId, {String? cursor, int limit = 30}) async {
    final value = await _call('sns.quotes', {'postId': postId, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }
}
