import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../app/providers.dart';

/// DM rooms of the current account (限定公開投稿を相手ユーザー単位に束ねる).
final dmRoomsProvider = FutureProvider.autoDispose<List<DmRoom>>((ref) async {
  ref.watch(currentAccountProvider);
  final s = ref.watch(currentSnsSessionProvider);
  if (s == null) return const [];
  final rooms = await s.dmRooms();
  rooms.sort((a, b) => (b.lastPost?.createdAt ?? DateTime(0)).compareTo(a.lastPost?.createdAt ?? DateTime(0)));
  return rooms;
});
