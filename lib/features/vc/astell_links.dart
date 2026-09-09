import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'astell_models.dart';
import 'astell_providers.dart';

/// AsTell ルームのリンク (D-159/D-160/D-165)。投稿で共有するのはサーバーが付ける
/// 共有 URL(`https://astell.rasq.jp/@handle/<Base58 id>`、OGP つきの公開ページ、
/// S-012)。無ければ(モック)`rasq://astell/<id>`。TL に流れてきた投稿の本文からは
/// 共有 URL / 旧 `…/astell/<id>` / `rasq://astell/<id>` のどれでも拾う。
/// 共有 URL からは Base58 コードを id として渡す(Central の `GET /astell/rooms/{id}`
/// はコードでも引ける)。
final _astellLink = RegExp(r'(?:rasq://astell/|https?://[^\s/]+/astell/)([0-9A-Za-z._-]{1,64})');
final _astellShareLink = RegExp(r'https?://[^\s/]+/@[A-Za-z0-9_.-]{1,64}/([1-9A-HJ-NP-Za-km-z]{16,22})(?![/A-Za-z0-9])');

/// 本文に含まれる最初の AsTell ルーム参照(id または共有 URL の Base58 コード)。
String? astellRoomIdIn(String text) {
  final a = _astellLink.firstMatch(text);
  final b = _astellShareLink.firstMatch(text);
  if (a == null) return b?.group(1);
  if (b == null) return a.group(1);
  return a.start <= b.start ? a.group(1) : b.group(1);
}

/// ルームの共有リンク: サーバーの `shareUrl`、無ければ `rasq://astell/<id>`。
String astellRoomLink(AstellRoom room) => room.shareUrl ?? 'rasq://astell/${Uri.encodeComponent(room.id)}';

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
