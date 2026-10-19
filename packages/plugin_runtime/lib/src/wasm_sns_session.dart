import 'dart:convert';
import 'dart:typed_data';

import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';
import 'package:rasq_store/rasq_store.dart' show FollowState;

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

  /// `sns.timelines` で宣言された基本 TL (D-134)。読み込み前 / 未実装の
  /// プラグインは Misskey 参照実装に合わせたローカル TL 1 本に縮退する。
  List<TimelineKind> _timelines = const [TimelineKind.local];

  @override
  List<TimelineKind> get timelines => _timelines;

  /// 投稿の文字数上限。**インスタンスごとに違う**ので、プラグインの
  /// `sns.capabilities` から受け取る。取れるまで(未実装プラグイン含む)は
  /// ホスト既定の 500 のまま。
  int? _maxPostLength;

  @override
  int get maxPostLength => _maxPostLength ?? super.maxPostLength;

  /// `call("sns.capabilities")` → セッション単位の能力値。
  Future<void> loadCapabilities() async {
    try {
      final value = await _call('sns.capabilities', const {});
      final max = (value['maxPostLength'] as num?)?.toInt();
      if (max != null && max > 0) _maxPostLength = max;
    } on SnsApiException catch (e) {
      if (e.code.code != 'C01') rethrow; // 未実装は既定のまま
    }
  }

  /// `call("sns.timelines")` → タブに並べる TL の宣言 (CONTRACT §6)。
  /// SNS ごとに揃う TL が違うので、ホストは決め打ちせずここから受け取る。
  Future<void> loadTimelines() async {
    try {
      final value = await _call('sns.timelines', const {});
      final declared = <TimelineKind>[
        for (final t in (value['timelines'] as List? ?? const []))
          if (t is Map && t['id'] is String) TimelineKind(t['id'] as String, t['label'] as String? ?? '${t['id']}'),
      ];
      if (declared.isNotEmpty) _timelines = declared;
    } on SnsApiException catch (e) {
      if (e.code.code != 'C01') rethrow; // 未実装は既定のまま
    }
  }

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

  /// ローカル保存の設定ページ (D-044) の値。area → 値マップ。
  ///
  /// **毎呼び出しの `args.settings` に載せる** — プラグインは自分が知って
  /// いる area / キーだけ読む(例: Misskey の `settings.timeline.withRenotes`
  /// → TL 取得パラメーター)。area ごとに入れ子にしてあるので、別ページの
  /// 同名キーとぶつからない。
  final Map<String, Map<String, Object?>> _settings = {};

  /// ホストが設定値の変更毎(+ 最初の TL 取得前)に呼ぶ。
  @override
  Future<void> applySettings(String area, Map<String, Object?> values) async {
    _settings[area] = {...values};
    // 値を保存したいプラグインには通知もする。未実装(C01)は無視 —
    // 次回以降の呼び出しに args.settings として載るので実害はない。
    try {
      await _call('sns.applySettings', {'area': area, 'values': values});
    } on SnsApiException catch (e) {
      if (e.code.code != 'C01') rethrow;
    }
  }

  /// `call("sns.<fn>")` → ok チェック → value。エラーは [SnsApiException]
  /// に写す(ホストのエラービュー/リトライがそのまま効く)。
  Future<Map<String, Object?>> _call(String fn, Map<String, Object?> args) async {
    final result = await _invoke(fn, {
      if (_settings.isNotEmpty) 'settings': _settings,
      // 現在時刻 (D-175): wasm には時計が無いので、createdAt 等が要るプラグイン(Bluesky)へ渡す。
      'now': DateTime.now().toUtc().toIso8601String(),
      ...args,
      ...extraArgs,
    });
    if (result['ok'] == true) return (result['value'] as Map? ?? const {}).cast<String, Object?>();
    final error = (result['error'] as Map?)?.cast<String, Object?>() ?? const {};
    final message = '${error['message'] ?? 'wasm sns call failed: $fn'}';
    throw SnsApiException(ErrorCode.tryParse('${error['code'] ?? ''}', message: message) ?? ErrorCode.internalServerError.copyWith(message: message));
  }

  bool _actionsLoaded = false;

  /// 宣言(アクション / TL)を読んだときの表示の言語 (D-484 / 契約 v0.24)。ラベルはプラグインが `args.locale` で
  /// 選ぶので、言語が変わったら次の TL 取得の前に読み直す。
  String? _declarationsLocale;

  @override
  Future<Page<Post>> timeline(TimelineKind kind, {String? cursor, int limit = 20}) async {
    // 実登録セッション (D-079): 最初の TL 取得前にアクション宣言を取り込む
    // (TL 画面はこの await 後に session.actions を読むので間に合う)。
    if (!_actionsLoaded || _declarationsLocale != RasqUiLocale.tag) {
      _actionsLoaded = true;
      _declarationsLocale = RasqUiLocale.tag;
      // 宣言が取れなくても TL は出す(バー無し / 既定の TL 一覧)。
      try {
        await loadActions();
      } catch (_) {}
      try {
        await loadTimelines();
      } catch (_) {}
      try {
        await loadCapabilities();
      } catch (_) {}
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

  // ── 通知 (D-134) ────────────────────────────────────────────────

  @override
  Future<Page<NotificationItem>> notifications({String? cursor, int limit = 20}) async {
    final value = await _call('sns.notifications', {'limit': limit, 'cursor': ?cursor});
    return SnsWire.notificationPageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  @override
  Future<void> markNotificationsRead() async {
    await _call('sns.markNotificationsRead', const {});
  }

  // ── 関係(フォロー/ミュート/ブロック)(D-134) ────────────────────

  static FollowState _followState(Map<String, Object?> j) => FollowState(
        following: j['following'] == true,
        followedBy: j['followedBy'] == true,
        requested: j['requested'] == true,
        muted: j['muted'] == true,
        blocked: j['blocked'] == true,
        blockedBy: j['blockedBy'] == true,
      );

  @override
  Future<Map<String, FollowState>> relationships(List<String> userIds) async {
    if (userIds.isEmpty) return const {};
    final value = await _call('sns.relationships', {'ids': userIds});
    final states = (value['states'] as Map? ?? const {}).cast<String, Object?>();
    return {
      for (final e in states.entries)
        if (e.value is Map) e.key: _followState((e.value as Map).cast<String, Object?>()),
    };
  }

  @override
  Future<FollowState> relationship(String userId) async => (await relationships([userId]))[userId] ?? const FollowState();

  /// 3 つのセッターは 1 本の `sns.setRelation` に写す。戻りは**サーバーを
  /// 読み直した状態**なので、鍵アカウントへのフォローは `requested` で返る。
  Future<FollowState> _setRelation(String userId, String relation, bool on) async {
    final value = await _call('sns.setRelation', {'id': userId, 'relation': relation, 'on': on});
    return _followState((value['state'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<FollowState> setFollowing(String userId, bool following) => _setRelation(userId, 'following', following);

  @override
  Future<FollowState> setMuted(String userId, bool muted) => _setRelation(userId, 'muted', muted);

  @override
  Future<FollowState> setBlocked(String userId, bool blocked) => _setRelation(userId, 'blocked', blocked);

  Future<Page<UserSummary>> _follows(String id, String direction, String? cursor, int limit) async {
    final value = await _call('sns.follows', {'id': id, 'direction': direction, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.userPageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<Page<UserSummary>> followers(String id, {String? cursor, int limit = 20}) => _follows(id, 'followers', cursor, limit);

  @override
  Future<Page<UserSummary>> following(String id, {String? cursor, int limit = 20}) => _follows(id, 'following', cursor, limit);

  /// muted / blocked / followRequests は同じ「人の一覧」なので、境界では
  /// 1 本の `sns.userList` に束ねてある。
  Future<Page<UserSummary>> _userList(String kind, String? cursor, int limit) async {
    final value = await _call('sns.userList', {'kind': kind, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.userPageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<Page<UserSummary>> mutedUsers({String? cursor, int limit = 30}) => _userList('muted', cursor, limit);

  @override
  Future<Page<UserSummary>> blockedUsers({String? cursor, int limit = 30}) => _userList('blocked', cursor, limit);

  @override
  Future<List<FollowRequest>> followRequests() async {
    final page = await _userList('followRequests', null, 50);
    // 申請 id は Misskey では相手のユーザー id で足りる(accept/reject が
    // userId を取る)。id を別に持つ SNS は将来ワイヤへ足す。
    return [for (final u in page.items) FollowRequest(id: u.id, user: u)];
  }

  @override
  Future<void> acceptFollowRequest(String userId) async {
    await _call('sns.resolveFollowRequest', {'id': userId, 'accept': true});
  }

  @override
  Future<void> rejectFollowRequest(String userId) async {
    await _call('sns.resolveFollowRequest', {'id': userId, 'accept': false});
  }

  @override
  Future<void> reportUser(String userId, String comment) async {
    await _call('sns.reportUser', {'id': userId, 'comment': comment});
  }

  // ── 検索 / トレンド / お気に入り (D-134) ──────────────────────────

  @override
  Future<Page<Post>> searchPosts(String query, {String? cursor, int limit = 20}) async {
    final value = await _call('sns.search', {'kind': 'posts', 'q': query, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  @override
  Future<Page<UserSummary>> searchUsers(String query, {String? cursor, int limit = 20}) async {
    final value = await _call('sns.search', {'kind': 'users', 'q': query, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.userPageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>());
  }

  /// D-475: `sns.search {kind: hashtags}` → `{tags: [{tag, count?}]}`。この kind を知らない古いプラグインは posts の
  /// `{page}` を返す(`kind` が users 以外は投稿の検索に倒していた)ので、`tags` が無ければ非対応として扱う。
  @override
  Future<List<TrendTag>> searchHashtags(String query, {int limit = 10}) async {
    final value = await _call('sns.search', {'kind': 'hashtags', 'q': query, 'limit': limit});
    final tags = value['tags'];
    if (tags is! List) throw UnsupportedError('$pluginId does not support searchHashtags');
    return [
      for (final t in tags)
        if (t is Map && t['tag'] is String && (t['tag'] as String).isNotEmpty) TrendTag(tag: (t['tag'] as String).replaceFirst(RegExp('^#'), ''), usersCount: (t['count'] as num?)?.toInt()),
    ];
  }

  @override
  Future<List<TrendTag>> trendingTags() async {
    final value = await _call('sns.trendingTags', const {});
    return [
      for (final t in (value['tags'] as List? ?? const []))
        if (t is Map && t['tag'] is String) TrendTag(tag: t['tag'] as String, usersCount: (t['count'] as num?)?.toInt()),
    ];
  }

  @override
  Future<Page<Post>> favorites({String? cursor, int limit = 20}) async {
    final value = await _call('sns.favorites', {'limit': limit, 'cursor': ?cursor});
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  // ── DM (CONTRACT §7, D-134) ─────────────────────────────────────

  @override
  Future<List<DmRoom>> dmRooms() async {
    final value = await _call('sns.dmRooms', const {});
    return [
      for (final r in (value['rooms'] as List? ?? const []))
        if (r is Map) SnsWire.dmRoomFrom(r.cast<String, Object?>(), account: account),
    ];
  }

  @override
  Future<Post> sendDm(DmRoom room, NewPost draft) async {
    final value = await _call('sns.sendDm', {
      'roomKind': room.kind.name,
      'peerId': room.peer.id,
      'draft': SnsWire.newPost(draft),
    });
    return SnsWire.postFrom((value['post'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  // ── メディア / プロフィール (D-136) ─────────────────────────────

  @override
  Future<MediaItem> uploadMedia(Uint8List bytes, String filename, {String? mimeType, bool sensitive = false, String? alt}) async {
    // バイト列は base64 で境界を渡る(host-fn の `body: {b64}` と同じ規約)。
    // multipart の組み立てはプラグイン側 — SNS ごとにフィールド名が違うので、
    // 境界に multipart 専用の口を作るより面が増えない。
    final value = await _call('sns.uploadMedia', {
      'bytesB64': base64Encode(bytes),
      'filename': filename,
      'mimeType': ?mimeType,
      'sensitive': sensitive,
      'alt': ?alt,
    });
    return SnsWire.mediaFrom((value['media'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<UserProfile> updateProfile(ProfileUpdate update) async {
    final value = await _call('sns.updateProfile', {
      'update': {
        'displayName': ?update.displayName,
        'description': ?update.description,
        'location': ?update.location,
        'birthday': ?update.birthday,
        'avatarMediaId': ?update.avatarMediaId,
        'bannerMediaId': ?update.bannerMediaId,
        if (update.fields != null) 'fields': [for (final f in update.fields!) {'name': f.name, 'value': f.value}],
      },
    });
    return SnsWire.profileFrom((value['profile'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  // ── ユーザー一括 / リアクション済み (D-136) ──────────────────────

  @override
  Future<List<UserProfile>> users(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final value = await _call('sns.users', {'ids': ids});
    return [
      for (final p in (value['profiles'] as List? ?? const []))
        if (p is Map) SnsWire.profileFrom(p.cast<String, Object?>(), account: account),
    ];
  }

  // ── プラグイン設定 (D-044) ──────────────────────────────────────

  @override
  Future<Map<String, Object?>> settingsRead(String area) async {
    final value = await _call('sns.settingsRead', {'area': area});
    return (value['values'] as Map? ?? const {}).cast<String, Object?>();
  }

  @override
  Future<Map<String, Object?>> settingsWrite(String area, String key, Object? value) async {
    final res = await _call('sns.settingsWrite', {'area': area, 'key': key, 'value': value});
    return (res['values'] as Map? ?? const {}).cast<String, Object?>();
  }

  @override
  Future<Page<Post>> reactedPosts({String? cursor, int limit = 20}) async {
    final value = await _call('sns.reactedPosts', {'limit': limit, 'cursor': ?cursor});
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  // ── リスト (D-136) ──────────────────────────────────────────────

  static UserListInfo _listFrom(Map<String, Object?> j) => UserListInfo(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        memberIds: [for (final id in (j['memberIds'] as List? ?? const [])) '$id'],
        description: j['description'] as String?,
        isPublic: j['isPublic'] == true,
      );

  @override
  Future<List<UserListInfo>> lists() async {
    final value = await _call('sns.lists', const {});
    return [
      for (final l in (value['lists'] as List? ?? const []))
        if (l is Map) _listFrom(l.cast<String, Object?>()),
    ];
  }

  /// カスタムフィード (D-194): `sns.feeds {query, limit}` → `{feeds: [{uri, name, description?, likeCount?, creator?}]}`。未実装(C01)は空。
  @override
  Future<List<FeedInfo>> searchFeeds(String query, {int limit = 20}) async {
    try {
      final value = await _call('sns.feeds', {'query': query, 'limit': limit});
      return [
        for (final f in (value['feeds'] as List? ?? const []))
          if (f is Map) FeedInfo(uri: '${f['uri'] ?? ''}', name: '${f['name'] ?? f['displayName'] ?? ''}', description: f['description'] as String?, likeCount: (f['likeCount'] as num?)?.toInt(), creator: f['creator'] as String?),
      ];
    } on SnsApiException catch (e) {
      if (e.code.code != 'C01') rethrow;
      return const [];
    }
  }

  List<FeedInfo> _feedsFrom(Map<String, Object?> value) => [
        for (final f in (value['feeds'] as List? ?? const []))
          if (f is Map) FeedInfo(uri: '${f['uri'] ?? ''}', name: '${f['name'] ?? f['displayName'] ?? ''}', description: f['description'] as String?, likeCount: (f['likeCount'] as num?)?.toInt(), creator: f['creator'] as String?),
      ];

  /// フィードの保存 (D-227): `sns.saveFeed {uri, on}` → 保存後の `{feeds: [...]}`。未実装(C01)は unsupported のまま投げる
  /// (UI は非対応と分かるように)。
  @override
  Future<List<FeedInfo>> saveFeed(String uri, {bool on = true}) async {
    try {
      return _feedsFrom(await _call('sns.saveFeed', {'uri': uri, 'on': on}));
    } on SnsApiException catch (e) {
      if (e.code.code != 'C01') rethrow;
      throw UnsupportedError('$pluginId does not support saveFeed');
    }
  }

  /// 保存済みフィード (D-195): `sns.savedFeeds {}`。未実装(C01)は空。
  @override
  Future<List<FeedInfo>> savedFeeds() async {
    try {
      return _feedsFrom(await _call('sns.savedFeeds', const {}));
    } on SnsApiException catch (e) {
      if (e.code.code != 'C01') rethrow;
      return const [];
    }
  }

  @override
  Future<UserListInfo> listInfo(String listId) async {
    final value = await _call('sns.listInfo', {'id': listId});
    return _listFrom((value['list'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<List<UserSummary>> listMembers(String listId) async {
    final value = await _call('sns.listMembers', {'id': listId});
    return [
      for (final u in (value['users'] as List? ?? const []))
        if (u is Map) SnsWire.userFrom(u.cast<String, Object?>()),
    ];
  }

  @override
  Future<UserListInfo> createList(String name) async {
    final value = await _call('sns.createList', {'name': name});
    return _listFrom((value['list'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<void> addToList(String listId, String userId) async {
    await _call('sns.updateListMember', {'listId': listId, 'userId': userId, 'add': true});
  }

  @override
  Future<void> removeFromList(String listId, String userId) async {
    await _call('sns.updateListMember', {'listId': listId, 'userId': userId, 'add': false});
  }

  // ── クリップ / Play (D-136) ─────────────────────────────────────
  //
  // どちらも SNS 固有の機能。持たないプラグインは C01 を返し、
  // [SnsApiException] のまま上がってホストが該当タブ/メニューを隠す。

  static ClipInfo _clipFrom(Map<String, Object?> j) => ClipInfo(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        description: j['description'] as String?,
        isPublic: j['isPublic'] == true,
        notesCount: (j['notesCount'] as num?)?.toInt(),
      );

  @override
  Future<List<ClipInfo>> clips({String? userId}) async {
    final value = await _call('sns.clips', {'userId': ?userId});
    return [
      for (final c in (value['clips'] as List? ?? const []))
        if (c is Map) _clipFrom(c.cast<String, Object?>()),
    ];
  }

  @override
  Future<ClipInfo> clipInfo(String clipId) async {
    final value = await _call('sns.clipInfo', {'clipId': clipId});
    return _clipFrom((value['clip'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<Page<Post>> clipNotes(String clipId, {String? cursor, int limit = 20}) async {
    final value = await _call('sns.clipNotes', {'clipId': clipId, 'limit': limit, 'cursor': ?cursor});
    return SnsWire.pageFrom((value['page'] as Map? ?? const {}).cast<String, Object?>(), account: account);
  }

  @override
  Future<ClipInfo> createClip(String name, {String? description, bool isPublic = false}) async {
    final value = await _call('sns.createClip', {'name': name, 'description': ?description, 'isPublic': isPublic});
    return _clipFrom((value['clip'] as Map? ?? const {}).cast<String, Object?>());
  }

  @override
  Future<void> deleteClip(String clipId) async {
    await _call('sns.deleteClip', {'clipId': clipId});
  }

  @override
  Future<void> addToClip(String clipId, String postId) async {
    await _call('sns.updateClipNote', {'clipId': clipId, 'postId': _actionTarget(postId), 'add': true});
  }

  @override
  Future<void> removeFromClip(String clipId, String postId) async {
    await _call('sns.updateClipNote', {'clipId': clipId, 'postId': _actionTarget(postId), 'add': false});
  }

  @override
  Future<List<PlayInfo>> userPlays(String userId) async {
    final value = await _call('sns.userPlays', {'userId': userId});
    return [
      for (final p in (value['plays'] as List? ?? const []))
        if (p is Map && p['url'] is String)
          PlayInfo(
            id: '${p['id']}',
            title: '${p['title'] ?? ''}',
            summary: p['summary'] as String?,
            url: Uri.parse(p['url'] as String),
          ),
    ];
  }
}
