import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha512;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rasq_client/backend/orgate_client.dart';
import 'package:rasq_client/backend/rasq_account.dart';
import 'package:rasq_client/features/child_safe/child_gate.dart';
import 'package:rasq_client/features/child_safe/child_safe_api.dart';
import 'package:rasq_client/features/child_safe/child_safe_policy.dart';
import 'package:rasq_client/features/child_safe/child_safe_providers.dart';
import 'package:rasq_client/features/child_safe/child_safe_screens.dart' show childSafeSummaryLines;
import 'package:rasq_client/features/rai/rai_functions.dart';
import 'package:rasq_client/features/rai/rai_reference.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/sanctions.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';

import 'support/child_safe_fakes.dart';

/// チャイルドセーフ v2 (D-307): 制限の解釈 / 署名 / 関所 / 子の端末の控え(フェイクの Central)。
Post post(String id, String body) => Post(
      id: id,
      account: const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'kid'),
      author: const UserSummary(id: 'u', account: AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'someone'), displayName: 'someone'),
      createdAt: DateTime(2026, 9, 24, 12),
      body: body,
    );

ChildGate gateOf(Map<String, Object?> settings, {DateTime? now, String state = 'active'}) =>
    ChildGate(state: ChildSafeState(managed: true, state: state, policy: ChildSafePolicy.fromJson(settings)), now: now ?? DateTime(2026, 9, 24, 12));

void main() {
  group('制限 (rasq.child-safe/2)', () {
    test('v2 を読む: 面ごとの値と allow', () {
      final p = ChildSafePolicy.fromJson(v2());
      expect(p.schema, ChildSafePolicy.schemaV2);
      expect(p.timeline.level, ChildSafeLevel.strict);
      expect(p.timeline.topics, const ChildSafeTopics(topics: ['ホラー'], legacy: true)); // もとの形 blockedTopics = ブラックリスト
      expect(p.time.topics, const ChildSafeTopics(mode: ChildSafeTopicMode.allow, topics: ['宿題'], legacy: true));
      expect(p.postsPerDay, 10);
      expect(p.time.contains(DateTime(2026, 9, 24, 22)), isTrue);
      expect(p.time.contains(DateTime(2026, 9, 24, 5, 59)), isTrue);
      expect(p.time.contains(DateTime(2026, 9, 24, 6)), isFalse);
      expect(p.time.contains(DateTime(2026, 9, 24, 12)), isFalse);
      expect(p.time.nextBoundary(DateTime(2026, 9, 24, 12)), DateTime(2026, 9, 24, 21));
      expect(p.time.nextBoundary(DateTime(2026, 9, 24, 22)), DateTime(2026, 9, 25, 6));
      final a = p.allow!;
      expect(a.sns!.permits('misskey', 'misskey.io'), isTrue);
      expect(a.sns!.permits('misskey', 'misskey.example'), isFalse);
      expect(a.sns!.permits('bluesky', 'bsky.social'), isFalse);
      expect(a.plugins!.permits('jp.rasq.sample', 'composer.text'), isTrue);
      expect(a.plugins!.permits('jp.rasq.sample', 'post.action'), isFalse);
      expect(a.plugins!.install, ChildSafeInstall.none);
      expect(a.features, {'dm': false, 'astell.join': false});
      expect(a.rai!.groups, ['rai.guide', 'rai.read', 'rai.compose']);
      expect(p.catalogVersion, 1);
      // 書き戻しても同じ形。
      expect(ChildSafePolicy.fromJson(p.toJson()).toJson(), p.toJson());
    });

    test('v1(schema も allow も無い)= ほかの面は止めない。既定は止めない側', () {
      final p = ChildSafePolicy.fromJson({'timeline': {'enabled': true, 'level': 'mild', 'blockedTopics': []}, 'composer': {'enabled': false, 'level': 'mild'}, 'time': {'enabled': false, 'start': '21:00', 'end': '06:00'}, 'postsPerDay': null});
      expect(p.allow, isNull);
      expect(p.postsPerDay, isNull);
      expect(p.timeline.level, ChildSafeLevel.mild);
      final g = ChildGate(state: ChildSafeState(managed: true, state: 'active', policy: p));
      expect(g.routeBlockReason('/dm'), isNull);
      expect(g.pluginAllowed('any.plugin', 'tl'), isTrue);
      expect(g.installBlockReason('any.plugin'), isNull);
      expect(g.sessionVisible(const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'x')), isTrue);
      expect(g.raiAutomation, isTrue);
      // 知らない強さはきびしめ、壊れた時刻は「時間なし」、上限は 0〜1000。
      expect(ChildSafeLevel.fromWire('??'), ChildSafeLevel.strict);
      expect(const ChildSafeTime(enabled: true, start: '25:00', end: '06:00').contains(DateTime(2026, 1, 1, 23)), isFalse);
      expect(ChildSafePolicy.fromJson({'postsPerDay': 5000}).postsPerDay, 1000);
    });

    test('強さを選ぶと TL と投稿がそろう。カタログの帯の既定(控え)', () {
      final p = ChildSafeCatalog.fallback.presetFor('16-17');
      expect(p.preset, 'standard');
      expect(p.timeline.level, ChildSafeLevel.standard);
      expect(p.allow!.plugins!.install, ChildSafeInstall.listed);
      final m = p.withPreset(ChildSafeLevel.mild);
      expect((m.timeline.level, m.composer.level, m.preset), (ChildSafeLevel.mild, ChildSafeLevel.mild, 'mild'));
      final c = ChildSafeCatalog.fromJson({'version': 3, 'presets': {'13-15': v2()}, 'raiGroups': [{'id': 'rai.macro', 'label': 'マクロ', 'phase': 2}]});
      expect(c.presetFor('13-15').catalogVersion, 3);
      expect(c.raiGroups.single.phase, 2);
    });
  });

  group('署名 (ストアの鍵の ed25519、sha512(canonical JSON))', () {
    test('canonical JSON: キーを再帰的に並べ、空白なし、UTF-8 のまま', () {
      expect(canonicalJson({'b': 1, 'a': {'d': [true, null], 'c': 'あ"'}}), '{"a":{"c":"あ\\"","d":[true,null]},"b":1}');
    });

    // Central `docs/API.md`「署名」の参照のベクトル(Central `policy::tests::reference_vector_matches_the_contract` と同じ値)。
    test('参照のベクトル: Central と同じ決まった形 / SHA-512 / 署名', () async {
      final settings = jsonDecode(referenceSettingsJson);
      final canonical = canonicalJson({'childAccountId': '00000000-0000-4000-8000-000000000001', 'revision': 7, 'settings': settings, 'issuedAt': '2026-09-24T12:34:56Z'});
      expect(canonical, referenceCanonical);
      expect(sha512.convert(utf8.encode(canonical)).toString(), referenceSha512);
      final digest = childSafeSigningDigest(childAccountId: '00000000-0000-4000-8000-000000000001', revision: 7, settings: settings, issuedAt: '2026-09-24T12:34:56Z');
      expect(digest, hasLength(64));
      expect(digest, sha512.convert(utf8.encode(referenceCanonical)).bytes);
      // 試験の鍵(秘密鍵 = 32 バイトすべて 0x07)。Central が作った署名を、アプリの検証の道(SHA-512 の生 64 バイトに ed25519)で確かめる。
      final signer = await TestSigner.create(7);
      expect(signer.publicKey, referencePublicKey);
      expect(await signer.sign('00000000-0000-4000-8000-000000000001', 7, settings, '2026-09-24T12:34:56Z'), referenceSignature);
      Future<bool> check(Object? set, {int revision = 7}) => verifyChildSafeSignature(
          publicKey: referencePublicKey, signature: referenceSignature, childAccountId: '00000000-0000-4000-8000-000000000001', revision: revision, settings: set, issuedAt: '2026-09-24T12:34:56Z');
      expect(await check(settings), isTrue);
      expect(await check(settings, revision: 8), isFalse);
      expect(await check({...(settings as Map).cast<String, Object?>(), 'é': 2}), isFalse);
    });

    test('canonical JSON: UTF-8 のバイト順 / 決めていない値は断る(検証は false)', () async {
      // UTF-16 の順なら 😀 (D83D) が ｚ (FF5A) より前。UTF-8 の順(Central)では後。
      expect(canonicalJson({'😀': 1, 'ｚ': 2, 'é': 3, 'Z': 4}), '{"Z":4,"é":3,"ｚ":2,"😀":1}');
      expect(canonicalJson({'s': '\u007f /\u0001'}), '{"s":"\u007f /\\u0001"}');
      expect(canonicalJson(10.0), '10'); // Web では整数も double
      expect(() => canonicalJson(1.5), throwsArgumentError);
      expect(() => canonicalJson('\ud800'), throwsArgumentError);
      expect(() => canonicalJson({1: 'x'}), throwsArgumentError);
      final s = await TestSigner.create();
      expect(await verifyChildSafeSignature(publicKey: s.publicKey, signature: await s.sign('k', 1, {'a': 1}, 't'), childAccountId: 'k', revision: 1, settings: {'a': 1.5}, issuedAt: 't'), isFalse);
    });

    test('正しい署名だけ通る(別のアカウント / 版 / 中身 / 鍵は落ちる)', () async {
      final s = await TestSigner.create();
      final settings = v2();
      final sig = await s.sign('kid-1', 3, settings, '2026-09-24T00:00:00Z');
      Future<bool> check({String acc = 'kid-1', int rev = 3, Object? set, String? key, String? signature}) =>
          verifyChildSafeSignature(publicKey: key ?? s.publicKey, signature: signature ?? sig, childAccountId: acc, revision: rev, settings: set ?? settings, issuedAt: '2026-09-24T00:00:00Z');
      expect(await check(), isTrue);
      // キーの順が違っても同じ(canonical)。
      expect(await check(set: (jsonDecode(jsonEncode(Map.fromEntries(settings.entries.toList().reversed))) as Map).cast<String, Object?>()), isTrue);
      expect(await check(acc: 'kid-2'), isFalse);
      expect(await check(rev: 4), isFalse);
      expect(await check(set: {...settings, 'postsPerDay': 1000}), isFalse);
      expect(await check(key: (await TestSigner.create(9)).publicKey), isFalse);
      expect(await check(signature: 'not-base64!'), isFalse);
    });
  });

  group('関所 (ChildGate)', () {
    test('見守られていなければ素通し', () {
      final g = ChildGate.off;
      expect(g.routeBlockReason('/vc'), isNull);
      expect(g.filterPosts([post('a', 'バカ')]), hasLength(1));
      expect(g.raiBlockReason('whatever.fn'), isNull);
      expect(g.blockedMessage('dm'), isNull);
    });

    test('ルート: /vc /dm /rai /store /search と SNS の追加', () {
      final g = gateOf(v2());
      expect(g.routeBlockReason('/vc'), contains('ASTell'));
      expect(g.routeBlockReason('/dm/room/x'), contains('DM'));
      expect(g.routeBlockReason('/store'), contains('ストア'));
      expect(g.routeBlockReason('/store/installed'), isNull);
      expect(g.routeBlockReason('/search'), isNull); // 投稿 / トレンドは許している
      expect(g.routeBlockReason('/login/misskey'), contains('追加'));
      expect(g.routeBlockReason('/home'), isNull);
      final noSearch = v2();
      ((noSearch['allow'] as Map)['search'] as Map).updateAll((_, _) => false);
      ((noSearch['allow'] as Map)['rai'] as Map)['enabled'] = false;
      final g2 = gateOf(noSearch);
      expect(g2.routeBlockReason('/search/trend/x'), contains('検索'));
      expect(g2.routeBlockReason('/rai'), contains('RAi'));
      // 設定待ちは、どれも止める。
      expect(gateOf(v2(), state: 'pending_setup').locked, isTrue);
    });

    test('TL: 強さ(刺激性の閾値)と止める話題、見守りの時間は許した話題だけ', () {
      final g = gateOf(v2());
      final posts = [post('ok', '今日は晴れ'), post('bad', 'お前バカだな'), post('topic', 'ホラー映画を見た')];
      expect([for (final p in g.filterPosts(posts)) p.id], ['ok']);
      // 強さの閾値: 怒りの語 1 つ(0.5)はきびしめ / ふつうで落ち、ゆるめでは残る。
      final mild = v2()..['timeline'] = {'enabled': true, 'level': 'mild', 'blockedTopics': <String>[]};
      expect([for (final p in gateOf(mild).filterPosts(posts)) p.id], ['ok', 'bad', 'topic']);
      expect(ChildGate.stimulusOfText('お前バカだな'), greaterThanOrEqualTo(ChildSafeLevel.standard.stimulusThreshold));
      // 22 時 = 見守りの時間: 「宿題」の話題だけ。
      final night = gateOf(v2(), now: DateTime(2026, 9, 24, 22));
      expect(night.inTimeWindow, isTrue);
      expect([for (final p in night.filterPosts([...posts, post('hw', '宿題おわった')])) p.id], ['hw']);
      expect(night.routeBlockReason('/notifications'), contains('通知'));
      expect(night.blockedMessage('dm'), isNotNull);
      expect(night.postDetailBlockReason(post('hw', '宿題')), isNull); // hidePostDetail = false
      expect(g.postDetailBlockReason(post('bad', 'バカ')), 'この投稿は表示できません');
    });

    test('コンポーザー: 当たった語の範囲に印を付けて止める / 1 日の数', () async {
      final g = gateOf(v2());
      final v = g.judgeText('明日の宿題、あいつバカすぎ');
      expect(v, isNotNull);
      expect('明日の宿題、あいつバカすぎ'.substring(v!.start!, v.end!), 'バカ');
      expect(v.message, contains('「バカ」'));
      expect(g.judgeText('明日の宿題がんばる'), isNull);
      final storage = MemorySessionStorage();
      final daily = ChildSafeDaily(storage);
      final now = DateTime(2026, 9, 24, 12);
      for (var i = 0; i < 10; i++) {
        await daily.recordSent(now: now);
      }
      final limited = await childComposeVerdictFor(g, daily, now, text: '宿題おわり');
      expect(limited?.message, contains('10 件'));
      expect(await childComposeVerdictFor(g, daily, now.add(const Duration(days: 1)), text: '宿題おわり'), isNull);
      expect((await childComposeVerdictFor(g, daily, now.add(const Duration(days: 1)), text: 'dm', dm: true))?.message, contains('DM'));
      // アカウントの処置 (sanctions) が先に出る。
      expect(g.blockedMessage('post', RasqSanctionsStub.post), contains('アカウントの処置'));
    });

    test('話題の一覧 (D-315): 新しい形を読み、書くときはいつも新しい形。もとの形の意味はそのまま', () {
      final s = v2()
        ..['timeline'] = {'enabled': true, 'level': 'mild', 'topicMode': 'allow', 'topics': ['宿題', '#部活']}
        ..['composer'] = {'enabled': true, 'level': 'mild', 'topicMode': 'deny', 'topics': ['ホラー']}
        ..['time'] = {'enabled': true, 'start': '21:00', 'end': '06:00', 'topicMode': 'deny', 'topics': <String>[], 'hideNotifications': true};
      final p = ChildSafePolicy.fromJson(s);
      expect(p.timeline.topics, const ChildSafeTopics(mode: ChildSafeTopicMode.allow, topics: ['宿題', '#部活']));
      expect(p.composer.topics.mode, ChildSafeTopicMode.deny);
      expect(p.time.topics, const ChildSafeTopics());
      // もとの形から読んでも、書くのは新しい形(もとの欄は書かない)。
      final legacy = ChildSafePolicy.fromJson(v2()).toJson();
      expect(legacy['timeline'], {'enabled': true, 'level': 'strict', 'topicMode': 'deny', 'topics': ['ホラー']});
      expect((legacy['time'] as Map)['topicMode'], 'allow');
      expect((legacy['time'] as Map).containsKey('allowedTopics'), isFalse);
      expect(legacy['composer'], {'enabled': true, 'level': 'strict', 'topicMode': 'deny', 'topics': <String>[]});
      // もとの形で欄が無い: TL = 空のブラックリスト、時間 = 空のホワイトリスト(= 何も流さない)、投稿 = 空のブラックリスト。
      final bare = ChildSafePolicy.fromJson({'timeline': {'enabled': true}, 'time': {'enabled': true}});
      expect((bare.timeline.topics.allow, bare.time.topics.allow, bare.composer.topics.allow), (false, true, false));
      expect(bare.time.topics.legacy, isTrue);
      // 保存の前の確かめ: 有効な面の空のホワイトリストだけ。
      expect(childSafeTopicErrors(p), isEmpty);
      final empty = p.copyWith(timeline: p.timeline.copyWith(topics: const ChildSafeTopics(mode: ChildSafeTopicMode.allow)), composer: p.composer.copyWith(enabled: false, topics: const ChildSafeTopics(mode: ChildSafeTopicMode.allow)));
      expect(childSafeTopicErrors(empty).keys, ['timeline']);
      expect(childSafeTopicErrors(ChildSafePolicy.fromJson(v2()..['time'] = {'enabled': true, 'allowedTopics': <String>[]})).keys, ['time']);
    });

    test('TL / 見守りの時間の話題 (D-315): ホワイトリスト = 当たるものだけ、ブラックリスト = 当たるものを見せない', () {
      final posts = [post('hw', '宿題おわった'), post('club', '今日の部活 #部活'), post('movie', 'ホラー映画を見た'), post('sky', '今日は晴れ')];
      List<String> shown(Map<String, Object?> s, {DateTime? now}) => [for (final p in gateOf(s, now: now).filterPosts(posts)) p.id];
      Map<String, Object?> with_(Map<String, Object?> timeline, [Map<String, Object?>? time]) => v2()
        ..['timeline'] = {'enabled': true, 'level': 'mild', ...timeline}
        ..['time'] = {'enabled': true, 'start': '21:00', 'end': '06:00', ...?time};
      expect(shown(with_({'topicMode': 'allow', 'topics': ['宿題', '部活']})), ['hw', 'club']);
      expect(shown(with_({'topicMode': 'deny', 'topics': ['ホラー']})), ['hw', 'club', 'sky']);
      expect(shown(with_({'topicMode': 'deny', 'topics': <String>[]})), ['hw', 'club', 'movie', 'sky']);
      // TL が無効なら、TL の話題は見ない。
      expect(shown(with_({'enabled': false, 'topicMode': 'allow', 'topics': ['宿題']})), hasLength(4));
      // 夜(22 時): 時間の話題も重なる。新しい形のブラックリスト / ホワイトリスト、もとの形の空 = 何も流さない。
      final night = DateTime(2026, 9, 24, 22);
      expect(shown(with_({'topicMode': 'deny', 'topics': <String>[]}, {'topicMode': 'deny', 'topics': ['部活']}), now: night), ['hw', 'movie', 'sky']);
      expect(shown(with_({'topicMode': 'deny', 'topics': <String>[]}, {'topicMode': 'deny', 'topics': <String>[]}), now: night), hasLength(4));
      expect(shown(with_({'topicMode': 'allow', 'topics': ['宿題', '部活']}, {'topicMode': 'allow', 'topics': ['宿題']}), now: night), ['hw']);
      expect(shown(with_({'topicMode': 'deny', 'topics': <String>[]}, {'allowedTopics': <String>[]}), now: night), isEmpty);
      // 目印: 見方が変わると TL を作り直す。
      expect(gateOf(with_({'topicMode': 'allow', 'topics': ['宿題']})).timelineSignature, isNot(gateOf(with_({'topicMode': 'deny', 'topics': ['宿題']})).timelineSignature));
    });

    test('投稿の話題 (D-315): ホワイトリストは当たる投稿だけ、ブラックリストは当たった語に印を付けて止める。DM には当てない', () async {
      Map<String, Object?> composer(Map<String, Object?> c) => v2()..['composer'] = {'enabled': true, 'level': 'mild', ...c};
      final allow = gateOf(composer({'topicMode': 'allow', 'topics': ['宿題', '部活']}));
      expect(allow.judgeText('宿題おわった'), isNull);
      expect(allow.judgeText('今日は #部活 がんばった'), isNull);
      final off = allow.judgeText('今日は晴れ');
      expect(off?.message, contains('宿題・部活'));
      expect(off!.hasRange, isFalse);
      expect(allow.judgeText('今日は晴れ', dm: true), isNull); // DM は強さだけ
      final deny = gateOf(composer({'topicMode': 'deny', 'topics': ['ホラー', 'ゲーム課金']}));
      expect(deny.judgeText('宿題おわった'), isNull);
      final v = deny.judgeText('きのうのホラー映画こわかった');
      expect(v?.message, contains('「ホラー」'));
      expect('きのうのホラー映画こわかった'.substring(v!.start!, v.end!), 'ホラー');
      expect(deny.judgeText('ホラー', dm: true), isNull);
      // 強さが先(強い言葉は、話題に合っていても止める)。空のブラックリスト / もとの形(投稿の話題なし)は止めない。
      expect(gateOf(composer({'level': 'strict', 'topicMode': 'allow', 'topics': ['宿題']})).judgeText('宿題やらないバカ')?.message, contains('「バカ」'));
      expect(gateOf(composer({'topicMode': 'deny', 'topics': <String>[]})).judgeText('ホラー'), isNull);
      expect(gateOf(composer({})).judgeText('ホラー'), isNull);
      // 投稿を判定しないなら、話題も見ない。送る前の判定 (childComposeVerdictFor) からも同じ。
      expect(gateOf(composer({'enabled': false, 'topicMode': 'allow', 'topics': ['宿題']})).judgeText('今日は晴れ'), isNull);
      final daily = ChildSafeDaily(MemorySessionStorage());
      expect((await childComposeVerdictFor(deny, daily, DateTime(2026, 9, 24, 12), text: 'ホラーの話'))?.message, contains('ホラー'));
    });

    test('要約の行 (D-315): 面ごとの話題の見方', () {
      final s = v2()
        ..['timeline'] = {'enabled': true, 'level': 'mild', 'topicMode': 'allow', 'topics': ['宿題']}
        ..['composer'] = {'enabled': true, 'level': 'mild', 'topicMode': 'deny', 'topics': ['ホラー']};
      final lines = childSafeSummaryLines(gateOf(s));
      expect(lines, contains('タイムライン: ゆるめ(流す話題: 宿題)'));
      expect(lines, contains('投稿の判定: ゆるめ(送れない話題: ホラー)'));
      expect(lines, contains('見守りの時間: 21:00〜06:00(流す話題: 宿題)'));
      final legacyNight = childSafeSummaryLines(gateOf(v2()..['time'] = {'enabled': true, 'allowedTopics': <String>[]}));
      expect(legacyNight, contains('見守りの時間: 21:00〜06:00(投稿は流れません)'));
      expect(childSafeSummaryLines(gateOf(v2()..['composer'] = {'enabled': true, 'level': 'strict'})), contains('投稿の判定: きびしめ'));
    });

    test('プラグイン / インストール / SNS', () {
      final g = gateOf(v2());
      expect(g.pluginAllowed('jp.rasq.sample', 'composer.text'), isTrue);
      expect(g.pluginAllowed('jp.rasq.sample', 'post.action'), isFalse);
      expect(g.pluginAllowed('other.plugin', 'composer.text'), isFalse);
      expect(g.installBlockReason('jp.rasq.sample'), contains('インストール'));
      final listed = v2();
      ((listed['allow'] as Map)['plugins'] as Map)['install'] = 'listed';
      // strict のプリセットは store.install も止める(書いていない id はプリセットの値)ので、ここでは許す。
      ((listed['allow'] as Map)['features'] as Map)['store.install'] = true;
      expect(gateOf(listed).installBlockReason('jp.rasq.sample'), isNull);
      expect(gateOf(listed).installBlockReason('other.plugin'), contains('選んだ'));
      expect(g.sessionVisible(const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'k')), isTrue);
      expect(g.sessionVisible(const AccountId(kind: SnsKind.mastodon, instance: 'mstdn.jp', handle: 'k')), isFalse);
      expect(g.canAddAccounts, isFalse);
      expect(g.forceHideSensitive, isTrue);
    });
  });

  group('RAi のまとまり', () {
    test('許したまとまりだけ。まとまりの分からない関数は止める。自動化と web も', () async {
      final g = gateOf(v2());
      expect(g.raiBlockReason('posts.fetch'), isNull);
      expect(g.raiBlockReason('post.compose'), isNull);
      expect(g.raiBlockReason('follow.set'), contains(childSafeBlockedText));
      expect(g.raiBlockReason('settings.set'), contains(childSafeBlockedText));
      expect(g.raiBlockReason('web.search'), contains(childSafeBlockedText));
      expect(g.raiBlockReason('dm.compose'), contains(childSafeBlockedText)); // DM を止めている
      expect(g.raiBlockReason('brand.new.fn'), contains(childSafeBlockedText));
      expect(g.raiAutomation, isFalse);
      expect(g.raiWeb, isFalse);
      final usage = raiFunctionUsageFor(g);
      expect(usage.any((u) => u.startsWith('follow.set(')), isFalse);
      expect(usage.any((u) => u.startsWith('posts.fetch(')), isTrue);
      expect(raiFunctionUsageFor(ChildGate.off), raiFunctionUsage);

      // 実行: RaiFunctionRunner.run が断る。
      final runner = Provider((ref) => RaiFunctionRunner(ref));
      final c = ProviderContainer(overrides: [childGateProvider.overrideWithValue(g)]);
      addTearDown(c.dispose);
      final r = await c.read(runner).run(const RaiFunctionCall(name: 'follow.set', args: {'user': 'x', 'on': 'true'}));
      expect(r.ok, isFalse);
      expect(r.text, contains('保護者が止めています'));
    });

    test('実行できる関数はどれもまとまりを持つ / functions.jsonl の全行が既知のまとまり', () {
      final src = File('lib/features/rai/rai_functions.dart').readAsStringSync();
      final body = src.substring(src.indexOf('Future<RaiFunctionResult> run(RaiFunctionCall c)'), src.indexOf('return RaiFunctionResult(name: c.name, text: appL10n.raiFunctionsUnknown('));
      final cases = [for (final m in RegExp(r"case '([\w.]+)':").allMatches(body)) m.group(1)!];
      expect(cases.length, greaterThan(40));
      for (final fn in [...cases, ...raiNonAutomatable.keys]) {
        expect(raiFunctionGroups[fn], isNotNull, reason: fn);
      }
      final known = {...childSafeRaiGroups, ...childSafeRaiPhase2Groups};
      final lines = File('assets/rai/functions.jsonl').readAsLinesSync().where((l) => l.trim().isNotEmpty);
      expect(lines.length, greaterThan(150));
      for (final l in lines) {
        final f = RaiFunction.fromJson((jsonDecode(l) as Map).cast<String, Object?>());
        expect(known, contains(f.group), reason: f.id);
      }
    });
  });

  group('子の端末 (childSafeProvider、フェイクの Central)', () {
    late TestSigner signer;
    setUpAll(() async => signer = await TestSigner.create());

    http.Response json(Object body, [int code = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json'});

    ({ProviderContainer c, List<String> calls, List<Map<String, Object?>> bodies, MemorySessionStorage storage}) setup(Map<String, Object?>? Function() status, {Map<String, String>? seed, String accountId = 'kid-1', bool offline = false}) {
      final calls = <String>[];
      final bodies = <Map<String, Object?>>[];
      final storage = MemorySessionStorage({
        OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-kid', 'token': 'kid-token', 'accountId': accountId}),
        ...?seed,
      });
      final mock = MockClient((req) async {
        final path = req.url.path.replaceFirst('/api/v1', '');
        calls.add('${req.method} $path');
        if (req.body.isNotEmpty) bodies.add((jsonDecode(req.body) as Map).cast<String, Object?>());
        if (offline && path != '/me') throw const SocketException('offline');
        switch ('${req.method} $path') {
          case 'GET /me':
            return json({'id': accountId, 'handle': 'kid', 'displayName': 'キッド', 'roles': <String>[]});
          case 'GET /me/child-safe':
            final s = status();
            return s == null ? json({'error': {'code': '503', 'message': 'down'}}, 503) : json(s);
          case 'GET /store-key':
            return json({'algorithm': 'ed25519', 'publicKey': signer.publicKey});
          case 'POST /me/child-safe/report' when bodies.last['date'] == '2026-09-11':
            // Central の日本の日付では 14 日より前(端末の時計とのずれ)。
            return json({'error': {'code': '400', 'message': 'date: 直近 14 日の日付です'}}, 400);
          case 'POST /me/child-safe/ack':
          case 'POST /me/child-safe/report':
            return http.Response('', 204);
        }
        return json({'error': {'code': '404', 'message': 'not found'}}, 404);
      });
      final c = ProviderContainer(overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        orgateClientProvider.overrideWith((ref) => OrgateClient(baseUrl: Uri.parse('https://central.test'), httpClient: mock, tokenProvider: () => ref.read(orgateTokenHolderProvider).token)),
        centralBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        orgateBaseUrlProvider.overrideWithValue(Uri.parse('https://central.test')),
        childSafeNowProvider.overrideWithValue(() => DateTime(2026, 9, 24, 12)),
      ]);
      addTearDown(c.dispose);
      return (c: c, calls: calls, bodies: bodies, storage: storage);
    }

    Future<ChildSafeState> sync(ProviderContainer c) async {
      await c.read(childSafeProvider.future);
      await c.read(childSafeProvider.notifier).refresh();
      return c.read(childSafeProvider).value!;
    }

    Future<Map<String, Object?>> active({int revision = 2, int applied = 1, Map<String, Object?>? settings, String accountId = 'kid-1'}) async {
      final s = settings ?? v2();
      return {
        'managed': true,
        'state': 'active',
        'parent': {'handle': 'mama', 'displayName': 'ママ'},
        'revision': revision,
        'appliedRevision': applied,
        'settings': s,
        'signature': await signer.sign(accountId, revision, s, '2026-09-24T00:00:00Z'),
        'issuedAt': '2026-09-24T00:00:00Z',
        'guardian': {'verified': false},
      };
    }

    test('署名を確かめて当てはめ、控えて ack する', () async {
      final st = await active();
      final t = setup(() => st);
      final s = await sync(t.c);
      expect(s.managed, isTrue);
      expect(s.locked, isFalse);
      expect(s.policy!.postsPerDay, 10);
      expect(s.parentDisplayName, 'ママ');
      expect(t.calls, contains('POST /me/child-safe/ack'));
      expect(t.bodies.any((b) => b['revision'] == 2), isTrue);
      final cache = (jsonDecode((await t.storage.read(childSafePolicyStorageKey))!) as Map).cast<String, Object?>();
      expect((cache['accountId'], cache['revision'], cache['state']), ('kid-1', 2, 'active'));
      expect(t.c.read(childGateProvider).routeBlockReason('/vc'), isNotNull);
    });

    test('署名が合わなければ前の制限のまま(無ければ使わせない)', () async {
      final bad = {...await active(), 'signature': base64Encode(List<int>.filled(64, 1))};
      final t = setup(() => bad);
      final s = await sync(t.c);
      expect(s.managed, isTrue);
      expect(s.locked, isTrue);
      expect(s.state, 'unverified');
      expect(s.error, contains('署名'));
      expect(t.calls, isNot(contains('POST /me/child-safe/ack')));

      // 前の良い制限があれば、それを使い続ける。
      final good = await active(revision: 2);
      var current = good;
      final t2 = setup(() => current);
      expect((await sync(t2.c)).policy, isNotNull);
      current = {...await active(revision: 3), 'signature': base64Encode(List<int>.filled(64, 2))};
      final s2 = await sync(t2.c);
      expect(s2.locked, isFalse);
      expect(s2.revision, 2);
      expect(s2.error, contains('前の設定のまま'));
    });

    test('設定待ち = 鍵。一度見守られた端末はオフラインでも制限を外さない。終わりはオンラインで確かめてから', () async {
      Map<String, Object?>? current = {'managed': true, 'state': 'pending_setup', 'parent': {'handle': 'mama'}, 'revision': 0, 'settings': null};
      final t = setup(() => current);
      expect((await sync(t.c)).locked, isTrue);
      current = await active();
      expect((await sync(t.c)).locked, isFalse);

      // オフライン(Central が落ちている): 控えのまま。
      current = null;
      final s = await sync(t.c);
      expect(s.managed, isTrue);
      expect(s.offline, isTrue);
      expect(s.policy, isNotNull);

      // 起動し直してもオフライン: 控えから(署名を確かめ直して)当てはめる。
      final t2 = setup(() => null, seed: {childSafePolicyStorageKey: (await t.storage.read(childSafePolicyStorageKey))!}, offline: true);
      final s2 = await sync(t2.c);
      expect(s2.managed, isTrue);
      expect(s2.policy!.postsPerDay, 10);

      // 控えが書き換えられていたら当てはめない。
      final tampered = (jsonDecode((await t.storage.read(childSafePolicyStorageKey))!) as Map).cast<String, Object?>();
      (tampered['settings'] as Map)['postsPerDay'] = 1000;
      final t3 = setup(() => null, seed: {childSafePolicyStorageKey: jsonEncode(tampered)}, offline: true);
      expect((await sync(t3.c)).locked, isTrue);

      // 別のアカウントでは「見守られていない」でも外さない。
      final t4 = setup(() => {'managed': false, 'guardian': {'verified': true, 'method': 'jpki'}}, seed: {childSafePolicyStorageKey: (await t.storage.read(childSafePolicyStorageKey))!}, accountId: 'other');
      final s4 = await sync(t4.c);
      expect(s4.managed, isTrue);
      expect(s4.guardian.verified, isTrue);

      // 同じアカウントでオンラインで終わりを確かめたら外す。
      current = {'managed': false, 'guardian': {'verified': false}};
      final s5 = await sync(t.c);
      expect(s5.managed, isFalse);
      expect(await t.storage.read(childSafePolicyStorageKey), isNull);
    });

    test('[23] 見守られた A を外したあと、設定待ちの別のアカウント B に入って出ても、A の制限は残る。A でオンラインで終わりを確かめたら外す', () async {
      Future<String> cacheOf(MemorySessionStorage s) async => (await s.read(childSafePolicyStorageKey))!;
      // ログアウトした端末(RASQ アカウントのトークンが無い)。
      final loggedOut = {OrgateAccountNotifier.storageKey: jsonEncode({'deviceId': 'device-kid', 'tokens': <String, String>{}})};
      final pendingB = {'managed': true, 'state': 'pending_setup', 'parent': {'handle': 'papa'}, 'revision': 0, 'settings': null, 'guardian': {'verified': false}};

      final stA = await active();
      final tA = setup(() => stA);
      expect((await sync(tA.c)).policy, isNotNull);

      // A からログアウト(SNS は端末に残す): 制限は残る。
      final out1 = setup(() => null, seed: {childSafePolicyStorageKey: await cacheOf(tA.storage), ...loggedOut});
      final s1 = await sync(out1.c);
      expect((s1.managed, s1.accountId, s1.policy?.postsPerDay), (true, 'kid-1', 10));

      // 設定待ちの B にログイン: B の設定待ち(鍵)。
      final tB = setup(() => pendingB, seed: {childSafePolicyStorageKey: await cacheOf(out1.storage)}, accountId: 'kid-2');
      final sB = await sync(tB.c);
      expect((sB.managed, sB.state, sB.locked), (true, 'pending_setup', true));

      // B からログアウト(設定待ちの画面の「ログアウト」): B の控えは消えるが、A の制限に戻る(修正前は全部消えて ChildGate.off)。
      final out2 = setup(() => null, seed: {childSafePolicyStorageKey: await cacheOf(tB.storage), ...loggedOut});
      final s2 = await sync(out2.c);
      expect((s2.managed, s2.accountId, s2.policy?.postsPerDay), (true, 'kid-1', 10));
      expect(out2.c.read(childGateProvider).routeBlockReason('/vc'), isNotNull);
      expect(await out2.storage.read(childSafePolicyStorageKey), isNotNull);

      // 見守られていない B / オフラインでも残る。
      final unmanagedB = setup(() => {'managed': false, 'guardian': {'verified': false}}, seed: {childSafePolicyStorageKey: await cacheOf(out2.storage)}, accountId: 'kid-2');
      expect((await sync(unmanagedB.c)).policy?.postsPerDay, 10);
      final offline = setup(() => null, seed: {childSafePolicyStorageKey: await cacheOf(out2.storage)}, accountId: 'kid-2', offline: true);
      expect((await sync(offline.c)).policy?.postsPerDay, 10);

      // A でオンラインで「見守られていない」と確かめたら外す。
      final endA = setup(() => {'managed': false, 'guardian': {'verified': false}}, seed: {childSafePolicyStorageKey: await cacheOf(out2.storage)});
      expect((await sync(endA.c)).managed, isFalse);
      expect(await endA.storage.read(childSafePolicyStorageKey), isNull);
    });

    test('[23] 別のアカウント B の制限で上書きしても A の制限はアカウントごとに残り、B の終わりでは消えない。A に戻れば A の控えを使う', () async {
      Future<String> cacheOf(MemorySessionStorage s) async => (await s.read(childSafePolicyStorageKey))!;
      final stA = await active();
      final tA = setup(() => stA);
      await sync(tA.c);

      // B は別の保護者の(ゆるい)制限。B のあいだは B の制限。
      final stB = await active(accountId: 'kid-2', settings: {...v2(), 'postsPerDay': 99});
      final tB = setup(() => stB, seed: {childSafePolicyStorageKey: await cacheOf(tA.storage)}, accountId: 'kid-2');
      final sB = await sync(tB.c);
      expect((sB.accountId, sB.policy?.postsPerDay), ('kid-2', 99));
      final heldB = (jsonDecode(await cacheOf(tB.storage)) as Map)['held'] as Map;
      expect(heldB.keys, ['kid-1']);

      // A に戻る(同じ端末に両方ログインしている): A の控えを戻して使う。B の制限も B のぶんとして残る。
      final backA = setup(() => stA, seed: {childSafePolicyStorageKey: await cacheOf(tB.storage)});
      final sA = await sync(backA.c);
      expect((sA.accountId, sA.policy?.postsPerDay), ('kid-1', 10));
      expect(((jsonDecode(await cacheOf(backA.storage)) as Map)['held'] as Map).keys, ['kid-2']);

      // B の保護者が見守りを終えた(B でオンラインで確かめた): B のぶんだけ消え、A の制限に戻る。
      final endB = setup(() => {'managed': false, 'guardian': {'verified': false}}, seed: {childSafePolicyStorageKey: await cacheOf(tB.storage)}, accountId: 'kid-2');
      final sEnd = await sync(endB.c);
      expect((sEnd.managed, sEnd.accountId, sEnd.policy?.postsPerDay), (true, 'kid-1', 10));
      expect((jsonDecode(await cacheOf(endB.storage)) as Map).containsKey('held'), isFalse);
    });

    test('1 日の報告: 終わった日の数だけ(本文も話題の見出しも送らない。D-462)', () async {
      final st = await active();
      final t = setup(() => st);
      final daily = t.c.read(childSafeDailyProvider);
      await daily.recordSent(now: DateTime(2026, 9, 23, 20));
      await daily.recordSent(now: DateTime(2026, 9, 23, 21));
      await daily.recordBlocked(now: DateTime(2026, 9, 23, 22));
      await daily.recordSent(now: DateTime(2026, 9, 24, 9));
      await sync(t.c);
      final reports = [for (final b in t.bodies) if (b.containsKey('date')) b];
      expect(reports, hasLength(1));
      expect(reports.single.keys.toSet(), {'date', 'posts', 'blocked'});
      expect((reports.single['date'], reports.single['posts'], reports.single['blocked']), ('2026-09-23', 2, 1));
      // 2 回目は送らない(1 日 1 回)。
      await t.c.read(childSafeProvider.notifier).refresh();
      expect([for (final b in t.bodies) if (b.containsKey('date')) b], hasLength(1));
    });

    test('1 日の報告: Central が受ける 14 日(13 日前まで)だけ。400 の日は捨てて先へ進む', () async {
      final st = await active();
      final t = setup(() => st);
      final daily = t.c.read(childSafeDailyProvider);
      for (final d in [10, 11, 20]) {
        await daily.recordSent(now: DateTime(2026, 9, d, 20));
      }
      await sync(t.c);
      expect([for (final b in t.bodies) if (b.containsKey('date')) b['date']], ['2026-09-11', '2026-09-20']);
      await t.c.read(childSafeProvider.notifier).refresh();
      expect([for (final b in t.bodies) if (b.containsKey('date')) b['date']], hasLength(2));
    });
  });

  test('API のエラーの言い換え', () {
    OrgateException e(String code, String m) => OrgateException(ErrorCode.tryParse(code)!, m);
    expect(childSafeErrorMessage(e('410', 'gone')), contains('期限'));
    expect(childSafeErrorMessage(e('409', 'handle taken')), contains('ハンドル'));
    expect(childSafeErrorMessage(e('409', 'そのハンドルは使われています')), 'そのハンドルは使われています');
    expect(childSafeErrorMessage(e('409', 'このアカウントは、もう見守られています')), 'このアカウントは、もう見守られています');
    expect(childSafeErrorMessage(e('404', 'not found')), contains('コード'));
    expect(childSafeErrorMessage(e('404', '見守っているアカウントに、そのハンドルはありません')), contains('ハンドル'));
    // 403 は Central の文のまま(端末の 403 だけ言い換える)。
    expect(childSafeErrorMessage(e('403', '保護者の確認が済んでいません(POST /me/child-safe/guardian/verify)')), contains('保護者の確認'));
    expect(childSafeErrorMessage(e('403', 'this device cannot sign in')), contains('端末'));
  });

  group('Central との形 (docs/API.md)', () {
    Map<String, Object?> fixture() => (jsonDecode(File('test/fixtures/child_safe_catalog.json').readAsStringSync()) as Map).cast<String, Object?>();

    test('カタログ: Central の応答(知らない欄つき)を読める / 控えは Central と同じ値', () {
      final j = fixture();
      expect(j.keys, containsAll(['schema', 'serverFeatures']));
      final c = ChildSafeCatalog.fromJson(j);
      final f = ChildSafeCatalog.fallback;
      List<(String, String, int)> rows(List<ChildSafeCatalogItem> l) => [for (final i in l) (i.id, i.label, i.phase)];
      expect(rows(f.features), rows(c.features));
      expect(rows(f.search), rows(c.search));
      expect(rows(f.raiGroups), rows(c.raiGroups));
      expect(f.version, c.version);
      for (final band in childSafeAgeBands) {
        expect(canonicalJson(f.presets[band]), canonicalJson(c.presets[band]), reason: band);
      }
      // プリセットは帯ごと。strict は AsTell の共有とストアのレビューも止める。
      final strict = gateOf(c.presets['13-15']!);
      for (final id in ['dm', 'astell.join', 'astell.create', 'astell.share', 'astell.stream', 'store.install', 'store.review', 'sns.addAccount']) {
        expect(strict.featureAllowed(id), isFalse, reason: id);
      }
      expect(strict.featureAllowed('post'), isTrue);
      expect([for (final s in c.search) if (strict.searchAllowed(s.id)) s.id], ['posts', 'trend']);
      expect(strict.pluginAllowed('any.plugin', 'tl'), isFalse); // install none + ids なし
      expect(strict.installBlockReason('any.plugin'), isNotNull);
      final standard = gateOf(c.presets['16-17']!);
      expect([for (final x in c.features) if (!standard.featureAllowed(x.id)) x.id], ['astell.create', 'astell.stream', 'sns.addAccount']);
      expect(standard.searchAllowed('web'), isFalse);
      expect(standard.raiBlockReason('astell.rooms'), isNull);
      expect(standard.raiBlockReason('follow.set'), isNotNull); // rai.act なし
      expect(standard.raiBlockReason('web.search'), isNotNull);
      final mild = gateOf(c.presets['18+']!);
      expect([for (final x in c.features) if (!mild.featureAllowed(x.id)) x.id], isEmpty);
      expect(mild.pluginAllowed('any.plugin', 'post.action'), isTrue); // install any
      expect(mild.installBlockReason('any.plugin'), isNull);
      expect(mild.sessionVisible(const AccountId(kind: SnsKind.bluesky, instance: 'bsky.social', handle: 'x')), isTrue); // kinds が空 = 絞らない
      expect(mild.canAddAccounts, isTrue);
      expect(mild.raiAutomation, isTrue);
      expect(mild.raiBlockReason('web.search'), isNull);
    });

    test('書いていない機能 / 検索の id はプリセットの値。deny は <まとまり>.<関数>。SNS の追加は 2 つとも見る', () {
      final s = v2();
      final allow = s['allow'] as Map;
      allow['features'] = <String, Object?>{'dm': true};
      allow['search'] = <String, Object?>{};
      allow['rai'] = {'enabled': true, 'groups': ['rai.guide', 'rai.read', 'rai.compose'], 'deny': ['rai.compose.post.reply'], 'automation': false};
      (allow['sns'] as Map)['addAccounts'] = true;
      final g = gateOf(s);
      expect(g.featureAllowed('dm'), isTrue);
      expect(g.featureAllowed('astell.share'), isFalse); // strict のプリセット
      expect(g.searchAllowed('users'), isFalse);
      expect(g.searchAllowed('posts'), isTrue);
      expect(g.raiBlockReason('post.compose'), isNull);
      expect(g.raiBlockReason('post.reply'), isNotNull);
      expect(g.canAddAccounts, isFalse); // sns.addAccount はプリセットで止まる
      final custom = v2()..['preset'] = 'custom';
      ((custom['allow'] as Map)['sns'] as Map)['addAccounts'] = true;
      expect(gateOf(custom).featureAllowed('astell.share'), isTrue);
      expect(gateOf(custom).canAddAccounts, isTrue);
    });

    test('応答: 知らない欄を無視して読む(guardian / 子の詳細 / 要約)', () {
      final g = ChildSafeGuardianInfo.fromJson({
        'verified': true, 'method': 'self_declared', 'country': 'US', 'verifiedAt': '2026-09-24T12:00:00Z', 'pledgeVersion': '2026-09-24',
        'requiredMethod': 'self_declared', 'jpkiMode': 'off', 'requirements': {'emailVerified': true, 'ageBand': '18+', 'pledgeAccepted': true, 'future': 1},
        'children': [{'handle': 'kid', 'displayName': 'こども', 'state': 'active', 'revision': 2, 'appliedRevision': 2, 'ageBand': '13-15', 'createdByGuardian': true, 'linkedAt': '2026-09-24T12:00:00Z', 'updatedAt': '2026-09-24T12:00:00Z', 'extra': {}}],
        'somethingNew': [1, 2],
      });
      expect((g.status.verified, g.status.methodLabel, g.requiredMethod, g.jpkiAvailable, g.emailVerified, g.ageBand, g.pledgeAccepted), (true, '自己申告', 'self_declared', false, true, '18+', true));
      expect((g.children.single.handle, g.children.single.applied, g.children.single.createdByGuardian), ('kid', true, true));
      final d = ChildSafeChildDetail.fromJson({
        'handle': 'kid', 'displayName': 'こども', 'state': 'active', 'revision': 2, 'appliedRevision': 1, 'ageBand': '13-15', 'createdByGuardian': false,
        'linkedAt': '2026-09-24T12:00:00Z', 'updatedAt': '2026-09-24T12:00:00Z', 'settings': fixture()['presets'] is Map ? (fixture()['presets'] as Map)['13-15'] : null,
        'signature': 'c2ln', 'issuedAt': '2026-09-24T12:00:00Z', 'presetDefaults': (fixture()['presets'] as Map)['13-15'],
        'summary': {'since': '2026-09-11', 'days': [{'date': '2026-09-24', 'posts': 3, 'rasqPosts': 1, 'blocked': 1, 'topics': [], 'trips': {'sexual': 1, 'x': 'bad'}, 'reported': true}]},
      });
      expect((d.row.applied, d.settings?.preset, d.signature, d.summary.days.single.posts), (false, 'strict', 'c2ln', 3));
      expect(d.summary.days.single.trips, {'sexual': 1});
      expect(ChildSafeChildDetail.fromJson({'handle': 'kid', 'state': 'pending_setup', 'settings': null, 'signature': null, 'issuedAt': null}).settings, isNull);
    });
  });
}

/// 投稿が止まっている処置(blockedMessage の順の確かめ用)。
abstract final class RasqSanctionsStub {
  static final post = RasqSanctions.fromJson({'level': 'light', 'restrictedFeatures': ['post']});
}
