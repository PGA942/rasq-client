import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/relational/relational_wasm.dart';
import 'package:rasq_models/rasq_models.dart';

/// M5f / D-084: 関連TL エンジンの wasm 移植のパリティ —
/// 同じ入力で Dart エンジンと wasm(relational-wasm)の束ね結果が一致する。
void main() {
  final wasmFile = File('../rasq-sdk-sample/rust/target/wasm32-unknown-unknown/release/relational_wasm.wasm');
  if (!wasmFile.existsSync()) {
    test('relational-wasm built', () {}, skip: 'build relational-wasm first');
    return;
  }
  final bytes = Uint8List.fromList(wasmFile.readAsBytesSync());

  const viewer = AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: 'me');
  UserSummary user(String id) => UserSummary(id: id, account: AccountId(kind: SnsKind.misskey, instance: 'example.test', handle: id), displayName: id);
  final t0 = DateTime.utc(2026, 8, 30, 12);
  Post post(String id, String author, int minute, String body, {UserSummary? repostedBy, Post? quote}) =>
      Post(id: id, account: viewer, author: user(author), createdAt: t0.add(Duration(minutes: minute)), body: body, repostedBy: repostedBy, quote: quote);

  test('Dart エンジンと wasm 移植で会話イベントの束ねと順序が一致する', () async {
    final followees = [
      post('a1', 'alice', 0, 'ロケットの打ち上げ見てる #rocket https://rocket.example/live'),
      post('c1', 'carol', 1, '今日のラーメンうまい'),
      post('b1', 'bob', 2, 'ロケット打ち上げすごいな #rocket'),
      post('a2', 'alice', 3, 'それな'),
      post('d1', 'dave', 4, 'ラーメンいいなぁ 俺もラーメン食べたい'),
      post('e1', 'eve', 5, '全然関係ない天気の話をしています'),
    ];
    final guests = [
      // ハードアンカー(同一 URL)持ちのゲスト — 遡及して A に接続される。
      post('g1', 'guest', -10, 'ロケット打ち上げの準備をずっと配信してた #rocket https://rocket.example/live'),
    ];
    final now = t0.add(const Duration(minutes: 6));
    const settings = RelationalSettings();

    // Dart エンジン。
    final dartEvents = ConversationEngine(settings: settings).build(followeePosts: followees, guestPosts: guests, now: now);

    // wasm エンジン(同一入力)。
    final controller = AsyncWasmPluginController(wasmBytes: bytes, nativeFetch: false);
    addTearDown(controller.dispose);
    await controller.load();
    final wasmEvents = await buildEventsViaWasm(controller, followees: followees, guests: guests, settings: settings, now: now);

    List<List<String>> shape(List<ConversationEvent> events) => [
          for (final e in events) [for (final p in e.posts) p.key],
        ];
    expect(shape(wasmEvents), shape(dartEvents));
    expect(dartEvents, isNotEmpty); // フィクスチャが空振りしていないこと
    // ロケット会話にはゲストの遡及投稿 (D-046) が時系列位置で入っている。
    final rocket = dartEvents.firstWhere((e) => e.posts.any((p) => p.id == 'a1'));
    expect(rocket.posts.first.id, 'g1');
    expect([for (final p in rocket.posts) p.id], containsAll(['g1', 'a1', 'b1', 'a2']));
  });
}
