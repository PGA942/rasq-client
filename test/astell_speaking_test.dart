import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rasq_client/features/vc/astell_fows.dart';
import 'package:rasq_client/features/vc/astell_models.dart';
import 'package:rasq_client/features/vc/astell_providers.dart';

/// D-467: ASTell のホスト(とメンバー)の話している印(緑の波形)が出なかった。
/// ホストの行は `speaking` を見ておらず、自分は参加メンバーに入っていなかった。
void main() {
  const host = AstellPeer(peerId: 'p1', accountId: 'douglas', handle: 'douglas', displayName: 'ダグラス', micOn: true);
  const guest = AstellPeer(peerId: 'p2', accountId: 'tivard', handle: 'tivard', displayName: 'TiVard', micOn: true);
  final room = AstellRoom(id: 'r1', title: '打ち上げ', ownerId: 'douglas', ownerHandle: 'douglas', ownerDisplayName: 'ダグラス', peerCount: 2, createdAt: DateTime(2026, 10, 12));

  Future<void> pump(WidgetTester tester, Widget w) => tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));

  Finder wave(Type of) => find.descendant(of: find.byType(of), matching: find.byIcon(Icons.graphic_eq));
  Finder mic(Type of) => find.descendant(of: find.byType(of), matching: find.byIcon(Icons.mic));

  testWidgets('ホストの行: 話している間は緑の波形、静かならマイク', (tester) async {
    await pump(tester, AstellHostRow(room: room, peers: [host.copyWith(speaking: true), guest]));
    expect(wave(AstellHostRow), findsOneWidget);
    expect(mic(AstellHostRow), findsNothing);
    final badge = tester.widget<Container>(find.ancestor(of: find.byIcon(Icons.graphic_eq), matching: find.byType(Container)).first);
    expect((badge.decoration! as BoxDecoration).color, astellSpeakingColor);

    await pump(tester, AstellHostRow(room: room, peers: const [host, guest]));
    expect(wave(AstellHostRow), findsNothing);
    expect(mic(AstellHostRow), findsOneWidget);

    // 強制ミュート中は話している印を出さない(メンバー行と同じ)。
    await pump(tester, AstellHostRow(room: room, peers: [host.copyWith(speaking: true, mutedByMod: true)]));
    expect(wave(AstellHostRow), findsNothing);
  });

  testWidgets('参加メンバーの行: 話している人だけ緑の波形', (tester) async {
    const quiet = AstellPeer(peerId: 'p3', accountId: 'yamahaya', handle: 'yamahaya', displayName: '山ハヤ');
    await pump(tester, AstellMembersRow(peers: [guest.copyWith(speaking: true), quiet]));
    expect(wave(AstellMembersRow), findsOneWidget);
    expect(find.descendant(of: find.byType(AstellMembersRow), matching: find.byIcon(Icons.volume_up)), findsOneWidget, reason: '聞いているだけの人はスピーカー');
    await pump(tester, const AstellMembersRow(peers: [guest, quiet]));
    expect(wave(AstellMembersRow), findsNothing);
  });

  testWidgets('自分のタイル: マイクを立てて話している間だけ波形。自分がホストならホストの行に出る', (tester) async {
    const me = AstellPeer(peerId: 'me', accountId: 'me', handle: 'me', displayName: 'あなた');
    final mine = AstellRoom(id: 'r2', title: '自分のルーム', ownerId: 'me', ownerHandle: 'me', ownerDisplayName: 'あなた', peerCount: 2, createdAt: DateTime(2026, 10, 12));
    var s = AstellSessionState(room: mine, myPeerId: 'me', myAccountId: 'me', me: me, peers: const [guest], selfSpeaking: true);
    expect([for (final p in s.members) p.peerId], ['me', 'p2']);
    expect(s.members.first.speaking, isFalse, reason: 'マイクを下ろしている');

    s = s.copyWith(micOn: true);
    expect([s.members.first.micOn, s.members.first.speaking], [true, true]);
    await pump(tester, Column(children: [AstellHostRow(room: mine, peers: s.members), AstellMembersRow(peers: [for (final p in s.members) if (p.accountId != mine.ownerId) p])]));
    expect(find.descendant(of: find.byType(AstellHostRow), matching: find.text('参加中')), findsOneWidget);
    expect(wave(AstellHostRow), findsOneWidget);
    expect(wave(AstellMembersRow), findsNothing);

    // 強制ミュートなら話している印は立てない。
    s = s.copyWith(forceMuted: true);
    expect([s.members.first.mutedByMod, s.members.first.speaking], [true, false]);

    // ホストでないルームでは参加メンバーの先頭に。
    s = AstellSessionState(room: room, myPeerId: 'me', myAccountId: 'me', me: me, peers: const [host, guest], micOn: true, selfSpeaking: true);
    await pump(tester, AstellMembersRow(peers: [for (final p in s.members) if (p.accountId != room.ownerId) p]));
    expect(wave(AstellMembersRow), findsOneWidget);
    expect(tester.getCenter(find.text('あなた')).dx, lessThan(tester.getCenter(find.text('TiVard')).dx), reason: '自分が先頭');

    // welcome に me が無い(古いサーバー)ときは、ほかの参加者だけ。
    expect(AstellSessionState(room: room, myPeerId: 'me', peers: const [host]).members, [host]);
  });
}
