import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/home/timeline_providers.dart';
import 'package:rasq_client/features/nodeprog/tl_components.dart';
import 'package:rasq_models/rasq_models.dart';

import 'support/fakes.dart';

/// TL のソース「RASQ の投稿」(D-283)。
void main() {
  const rasq = AccountId(kind: SnsKind.other, instance: 'rasq', handle: 'taro');
  final post = Post(id: 'r1', account: rasq, author: const UserSummary(id: 'rasq:a', account: rasq, displayName: 'タロ'), createdAt: DateTime(2026, 9, 20), body: 'RASQ から');

  test('rasq:posts は SNS のセッションではなく、RASQ のフィードに解決する(acct: で包まれていても)', () async {
    final session = FakeSnsSession(fakeSession(), const []);
    final asked = <String?>[];
    String? next;
    Future<(List<Post>, String?)> feed(String? until) async {
      asked.add(until);
      return ([post], 'older');
    }

    expect((await resolveNodeFetch(session, rasqPostsKind, rasqFeed: feed, onCursor: (n) => next = n)).single.id, 'r1');
    expect(next, 'older');
    // 続きは、前のページの nextUntil を渡す。
    await resolveNodeFetch(session, 'acct:@someone@mk.example|$rasqPostsKind', cursor: 'older', rasqFeed: feed);
    expect(asked, [null, 'older']);
    // フィードの口が無い画面(コンポーザーの比較など)では、空。
    expect(await resolveNodeFetch(session, rasqPostsKind), isEmpty);
  });

  test('構成 → グラフ: RASQ の投稿は、アカウントを付けない tl.source になる', () {
    final g = compileTlConfig(const TlConfig(sources: [TlSourceComponent(tl: rasqPostsKind, account: '@x@mk.example')]), scope: 'tl.bundle');
    final src = g.nodes.firstWhere((n) => n.type == 'tl.source');
    String? input(String label) => src.inputs.where((i) => i.label == label).firstOrNull?.value;
    expect(input('TL'), rasqPostsKind);
    expect(input('アカウント') ?? '', isEmpty);
  });
}
