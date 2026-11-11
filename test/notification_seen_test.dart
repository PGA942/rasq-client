import 'package:flutter/material.dart' hide Page;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/notifications/notification_seen.dart';
import 'package:rasq_client/features/notifications/notifications_screen.dart';
import 'package:rasq_client/session/session_providers.dart';
import 'package:rasq_client/session/session_storage.dart';
import 'package:rasq_models/rasq_models.dart';

// 通知の青いハイライトが残る問題 (D-557): Misskey は通知ごとの既読を返さないので、端末の「どこまで見たか」で決める。

const _acct = AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'me');

NotificationItem _n(String id, DateTime at, {bool read = false}) => NotificationItem(
      id: id,
      account: _acct,
      kind: NotificationKind.follow,
      createdAt: at,
      read: read,
      actors: [UserSummary(id: 'u-$id', account: const AccountId(kind: SnsKind.misskey, instance: 'misskey.io', handle: 'someone'), displayName: 'だれか $id')],
    );

void main() {
  final t1 = DateTime.utc(2026, 11, 11, 10);
  final t2 = DateTime.utc(2026, 11, 11, 11);
  final t3 = DateTime.utc(2026, 11, 11, 12);

  test('未読 = SNS が既読と言っていなくて、見たところより新しい', () {
    expect(isNotificationUnread(_n('a', t2), null), isTrue);
    expect(isNotificationUnread(_n('a', t2), t1), isTrue);
    expect(isNotificationUnread(_n('a', t2), t2), isFalse);
    expect(isNotificationUnread(_n('a', t2), t3), isFalse);
    expect(isNotificationUnread(_n('a', t2, read: true), null), isFalse);
    expect(newestNotificationAt([_n('a', t1), _n('b', t3), _n('c', t2)]), t3);
    expect(newestNotificationAt(const []), isNull);
  });

  test('見たところは前に進むだけ。端末に残り、次の起動でも読める', () async {
    final storage = MemorySessionStorage({});
    final c = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(c.dispose);
    c.read(notificationSeenProvider);
    await pumpEventQueue();
    expect(c.read(notificationSeenProvider).ready, isTrue);
    await c.read(notificationSeenProvider.notifier).markSeen(_acct.key, t2);
    await c.read(notificationSeenProvider.notifier).markSeen(_acct.key, t1);
    expect(c.read(notificationSeenProvider).of(_acct.key), t2, reason: '後ろへは戻さない');
    final c2 = ProviderContainer(overrides: [sessionStorageProvider.overrideWithValue(storage)]);
    addTearDown(c2.dispose);
    c2.read(notificationSeenProvider);
    await pumpEventQueue();
    expect(c2.read(notificationSeenProvider).of(_acct.key), t2);
  });

  testWidgets('開いたときの新しい通知だけ青く、読み直すと消える。未読の数も 0 に', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var items = [_n('new', t3), _n('old', t1)];
    final storage = MemorySessionStorage({});
    late ProviderContainer c;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionStorageProvider.overrideWithValue(storage),
        notificationsProvider.overrideWith((ref) async => Page(items: items)),
      ],
      child: Consumer(builder: (context, ref, _) {
        c = ProviderScope.containerOf(context);
        return const MaterialApp(home: NotificationsScreen());
      }),
    ));
    // 前に t2 まで見ていた。
    await tester.runAsync(() => c.read(notificationSeenProvider.notifier).markSeen(_acct.key, t2));
    await tester.pumpAndSettle();
    bool? unreadOf(String id) => tester.widgetList<NotificationTile>(find.byType(NotificationTile)).firstWhere((t) => t.item.id == id).unread;
    expect(unreadOf('new'), isTrue, reason: '見たところより新しい');
    expect(unreadOf('old'), isFalse, reason: 'Misskey は既読を返さないが、見たところより前');
    // 画面に出したので、見たところはいちばん新しい通知まで進んだ。未読の数は 0。
    expect(c.read(notificationSeenProvider).of(_acct.key), t3);
    expect(c.read(unreadNotificationCountProvider), 0);

    // 読み直すと、さっきの通知はもう青くない。新しく来た通知だけ青い。
    final t4 = t3.add(const Duration(hours: 1));
    items = [_n('newer', t4), _n('new', t3), _n('old', t1)];
    c.invalidate(notificationsProvider);
    await tester.pumpAndSettle();
    expect(unreadOf('new'), isFalse);
    expect(unreadOf('newer'), isTrue);
    expect(c.read(notificationSeenProvider).of(_acct.key), t4);
  });
}
