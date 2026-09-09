import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/orgate_client.dart';
import 'astell_models.dart';
import 'astell_providers.dart';

/// AsTell ルームのリンク (D-159/D-160)。投稿で共有するのは Central の公開ページ
/// (`CENTRAL_PUBLIC_URL/astell/<id>`、S-011)。Central 未接続(モック)なら
/// `rasq://astell/<id>`。TL に流れてきた投稿の本文からはどちらも拾う。
final _astellLink = RegExp(r'(?:rasq://astell/|https?://[^\s/]+/astell/)([0-9A-Za-z._-]{1,64})');

/// 本文に含まれる最初の AsTell ルーム id。無ければ null。
String? astellRoomIdIn(String text) => _astellLink.firstMatch(text)?.group(1);

/// ルームの共有リンク。
String astellRoomLink(Uri? centralBase, String roomId) {
  final id = Uri.encodeComponent(roomId);
  if (centralBase == null) return 'rasq://astell/$id';
  return '${centralBase.origin}/astell/$id';
}

/// 現在の接続先でのルーム共有リンク。
final astellRoomLinkProvider = Provider.family<String, String>((ref, roomId) => astellRoomLink(ref.watch(centralBaseUrlProvider), roomId));

/// 共有の投稿本文 (D-159): タイトル + 開催予定(あれば)+ リンク。
String astellShareText(AstellRoom room, String link) {
  final when = room.scheduledAt;
  final head = when != null && room.isScheduled ? '「${room.title}」を ${formatAstellSchedule(when)} に開催します' : '「${room.title}」を開催中です';
  final genres = room.genres.isEmpty ? '' : ' ${room.genres.take(3).map((g) => '#$g').join(' ')}';
  return '$head$genres\n$link';
}

/// 開催予定の表示 (M/d HH:mm)。
String formatAstellSchedule(DateTime at) {
  final l = at.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.month}/${l.day} ${two(l.hour)}:${two(l.minute)}';
}

/// id からルーム 1 件(TL のタイル用、D-160)。無ければ null。
final astellRoomProvider = FutureProvider.family<AstellRoom?, String>((ref, id) => ref.watch(astellClientProvider).room(id));
