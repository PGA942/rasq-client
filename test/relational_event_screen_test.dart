import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/relational/relational_engine.dart';
import 'package:rasq_client/features/relational/relational_event_screen.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';

const account = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'yamada');

Post post(String id, String author, String body, {int minute = 0}) => Post(
      id: id,
      account: account,
      author: UserSummary(id: author, account: account, displayName: author),
      createdAt: DateTime(2026, 8, 27, 12, minute),
      body: body,
    );

void main() {
  testWidgets('リレーショナルページ: 見出し・キーワードチップ・投稿列を表示 (D-037)', (tester) async {
    final event = ConversationEvent.root(post('1', 'alice', 'ストラトローンチの機体が好き #打上げ'));
    event.add(post('2', 'bob', 'ストラトローンチの機体、翼が長い #打上げ', minute: 1));

    await tester.pumpWidget(ProviderScope(
      overrides: [sessionStorageProvider.overrideWithValue(MemorySessionStorage())],
      child: MaterialApp(theme: RasqTheme.light(), home: RelationalEventScreen(event: event)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('alice+1人'), findsOneWidget);
    expect(find.text('2件 ・ 2人'), findsOneWidget);
    // 実在語の見出し(共有ラベル)とキーワードチップ。
    expect(find.textContaining('ストラトローンチ'), findsWidgets);
    expect(find.text('#打上げ'), findsWidgets);
    // 投稿列。
    expect(find.textContaining('翼が長い'), findsOneWidget);
  });
}
