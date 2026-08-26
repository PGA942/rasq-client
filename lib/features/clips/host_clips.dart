import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../session/session_providers.dart';

/// ホスト横断クリップ (D-032)。SNS を跨いで post key を束ねる端末ローカルの
/// クリップ。**表示用スナップショット**も一緒に保存する — 元投稿が消えたり
/// 別 SNS のセッションが閉じていても、クリップの中身は読み返せる。
/// 保存先はホスト KV `clips.host.v1`(同期は将来 RASQ アカウント)。
const hostClipsStorageKey = 'clips.host.v1';

/// [ClipInfo.id] のホスト接頭辞。ネイティブ id と衝突しない。
const hostClipIdPrefix = 'host:';

@immutable
class HostClipEntry {
  const HostClipEntry({required this.postKey, required this.addedAt, required this.snapshot});

  final String postKey;
  final DateTime addedAt;

  /// [postSnapshot] の JSON(表示に必要な最小限)。
  final Map<String, Object?> snapshot;

  Map<String, Object?> toJson() => {'postKey': postKey, 'addedAt': addedAt.toIso8601String(), 'snapshot': snapshot};

  factory HostClipEntry.fromJson(Map<String, Object?> j) => HostClipEntry(
        postKey: j['postKey'] as String,
        addedAt: DateTime.tryParse(j['addedAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        snapshot: (j['snapshot'] as Map?)?.cast<String, Object?>() ?? const {},
      );
}

@immutable
class HostClip {
  const HostClip({required this.id, required this.name, required this.createdAt, this.entries = const []});

  final String id;
  final String name;
  final DateTime createdAt;
  final List<HostClipEntry> entries;

  ClipInfo get info => ClipInfo(id: '$hostClipIdPrefix$id', name: name, notesCount: entries.length, isHost: true);

  HostClip copyWith({String? name, List<HostClipEntry>? entries}) => HostClip(id: id, name: name ?? this.name, createdAt: createdAt, entries: entries ?? this.entries);

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'createdAt': createdAt.toIso8601String(), 'entries': [for (final e in entries) e.toJson()]};

  factory HostClip.fromJson(Map<String, Object?> j) => HostClip(
        id: j['id'] as String,
        name: (j['name'] ?? '').toString(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        entries: [for (final e in (j['entries'] as List? ?? const [])) HostClipEntry.fromJson((e as Map).cast<String, Object?>())],
      );
}

/// 表示用スナップショット: 投稿 → 最小限の JSON。
Map<String, Object?> postSnapshot(Post p) => {
      'id': p.id,
      'kind': p.account.kind.name,
      'instance': p.account.instance,
      'handle': p.account.handle,
      'createdAt': p.createdAt.toIso8601String(),
      'body': p.body,
      'contentWarning': p.contentWarning,
      'author': {
        'id': p.author.id,
        'displayName': p.author.displayName,
        'avatarUrl': p.author.avatarUrl?.toString(),
      },
      'media': [
        for (final m in p.media.take(4)) {'id': m.id, 'type': m.type.name, 'url': m.url.toString(), 'sensitive': m.sensitive},
      ],
    };

Post postFromSnapshot(Map<String, Object?> j) {
  final account = AccountId(
    kind: SnsKind.values.asNameMap()[j['kind']] ?? SnsKind.other,
    instance: (j['instance'] ?? '-').toString(),
    handle: (j['handle'] ?? '-').toString(),
  );
  final author = (j['author'] as Map?)?.cast<String, Object?>() ?? const {};
  return Post(
    id: (j['id'] ?? '?').toString(),
    account: account,
    author: UserSummary(
      id: (author['id'] ?? '?').toString(),
      account: account,
      displayName: (author['displayName'] ?? '?').toString(),
      avatarUrl: author['avatarUrl'] == null ? null : Uri.tryParse(author['avatarUrl'].toString()),
    ),
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
    body: (j['body'] ?? '').toString(),
    contentWarning: j['contentWarning'] as String?,
    media: [
      for (final m in (j['media'] as List? ?? const []))
        MediaItem(
          id: ((m as Map)['id'] ?? '').toString(),
          type: MediaType.values.asNameMap()[m['type']] ?? MediaType.image,
          url: Uri.tryParse((m['url'] ?? '').toString()) ?? Uri.parse('about:blank'),
          sensitive: m['sensitive'] == true,
        ),
    ],
  );
}

class HostClipsStore extends AsyncNotifier<List<HostClip>> {
  @override
  Future<List<HostClip>> build() async {
    try {
      final raw = await ref.watch(sessionStorageProvider).read(hostClipsStorageKey);
      if (raw != null) {
        return [for (final c in (jsonDecode(raw) as List)) HostClip.fromJson((c as Map).cast<String, Object?>())];
      }
    } catch (_) {}
    return const [];
  }

  Future<void> _save(List<HostClip> next) async {
    state = AsyncData(next);
    await ref.read(sessionStorageProvider).write(hostClipsStorageKey, jsonEncode([for (final c in next) c.toJson()]));
  }

  Future<HostClip> createClip(String name) async {
    final clip = HostClip(id: DateTime.now().millisecondsSinceEpoch.toRadixString(36), name: name, createdAt: DateTime.now());
    await _save([...state.value ?? const <HostClip>[], clip]);
    return clip;
  }

  Future<void> deleteClip(String id) async => _save([for (final c in state.value ?? const <HostClip>[]) if (c.id != id) c]);

  Future<void> addPost(String clipId, Post post) async {
    await _save([
      for (final c in state.value ?? const <HostClip>[])
        if (c.id == clipId && !c.entries.any((e) => e.postKey == post.key))
          c.copyWith(entries: [...c.entries, HostClipEntry(postKey: post.key, addedAt: DateTime.now(), snapshot: postSnapshot(post))])
        else
          c,
    ]);
  }

  Future<void> removePost(String clipId, String postKey) async {
    await _save([
      for (final c in state.value ?? const <HostClip>[])
        if (c.id == clipId) c.copyWith(entries: [for (final e in c.entries) if (e.postKey != postKey) e]) else c,
    ]);
  }

  HostClip? byId(String id) => (state.value ?? const []).where((c) => c.id == id).firstOrNull;
}

final hostClipsProvider = AsyncNotifierProvider<HostClipsStore, List<HostClip>>(HostClipsStore.new);
