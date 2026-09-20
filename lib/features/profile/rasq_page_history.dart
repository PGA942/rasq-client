import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../session/session_providers.dart';

/// 開いた RASQ アカウントページの履歴 (D-272)。サイドバーの … の横に、アイコンで出す(新しい順、タップでそのページへ)。
@immutable
class RasqVisited {
  const RasqVisited({required this.handle, this.displayName = '', this.avatarUrl});
  final String handle;
  final String displayName;
  final Uri? avatarUrl;

  Map<String, Object?> toJson() => {'handle': handle, 'displayName': displayName, if (avatarUrl != null) 'avatarUrl': avatarUrl.toString()};
  factory RasqVisited.fromJson(Map<String, Object?> j) => RasqVisited(
        handle: j['handle'] as String? ?? '',
        displayName: j['displayName'] as String? ?? '',
        avatarUrl: switch (j['avatarUrl']) { final String u when u.startsWith('http') => Uri.tryParse(u), _ => null },
      );
}

class RasqPageHistory extends Notifier<List<RasqVisited>> {
  static const storageKey = 'rasq.page.history.v1';
  static const max = 8;

  @override
  List<RasqVisited> build() {
    _restore();
    return const [];
  }

  Future<void> _restore() async {
    try {
      final raw = await ref.read(sessionStorageProvider).read(storageKey);
      if (raw == null) return;
      final list = [for (final e in jsonDecode(raw) as List) if (e is Map) RasqVisited.fromJson(e.cast<String, Object?>())];
      // 復元の前に開いたページがあれば、それを先頭に残す。
      state = _merge([...state, ...list]);
    } catch (_) {}
  }

  static List<RasqVisited> _merge(List<RasqVisited> items) {
    final seen = <String>{};
    return [for (final v in items) if (v.handle.isNotEmpty && seen.add(v.handle.toLowerCase())) v].take(max).toList();
  }

  /// 開いた(先頭へ。同じアカウントは 1 つだけ)。
  Future<void> record(RasqVisited v) async {
    state = _merge([v, ...state]);
    try {
      await ref.read(sessionStorageProvider).write(storageKey, jsonEncode([for (final e in state) e.toJson()]));
    } catch (_) {}
  }
}

final rasqPageHistoryProvider = NotifierProvider<RasqPageHistory, List<RasqVisited>>(RasqPageHistory.new);
