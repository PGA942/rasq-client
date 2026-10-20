import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';

import '../../backend/rasq_collections_api.dart';
import '../../session/session_providers.dart';
import '../../l10n/l10n.dart';

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
  const HostClip({required this.id, required this.name, required this.createdAt, this.description, this.entries = const [], this.remoteId, this.remoteUrl});

  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final List<HostClipEntry> entries;

  /// 公開したクリップ (D-344): Central のコレクション id と共有 URL(S-042)。null = 端末だけ。
  final String? remoteId;
  final String? remoteUrl;
  bool get isPublished => remoteId != null;

  ClipInfo get info => ClipInfo(id: '$hostClipIdPrefix$id', name: name, description: description, notesCount: entries.length, isHost: true);

  HostClip copyWith({String? name, String? description, List<HostClipEntry>? entries}) =>
      HostClip(id: id, name: name ?? this.name, description: description ?? this.description, createdAt: createdAt, entries: entries ?? this.entries, remoteId: remoteId, remoteUrl: remoteUrl);

  /// 公開 / 公開をやめる (D-344)。null を渡すと端末だけに戻る。
  HostClip withRemote(String? id, String? url) =>
      HostClip(id: this.id, name: name, description: description, createdAt: createdAt, entries: entries, remoteId: id, remoteUrl: id == null ? null : url);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'description': ?description,
        'createdAt': createdAt.toIso8601String(),
        'entries': [for (final e in entries) e.toJson()],
        'remoteId': ?remoteId,
        'remoteUrl': ?remoteUrl,
      };

  factory HostClip.fromJson(Map<String, Object?> j) => HostClip(
        id: j['id'] as String,
        name: (j['name'] ?? '').toString(),
        description: j['description'] as String?,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0),
        entries: [for (final e in (j['entries'] as List? ?? const [])) HostClipEntry.fromJson((e as Map).cast<String, Object?>())],
        remoteId: j['remoteId'] as String?,
        remoteUrl: j['remoteUrl'] as String?,
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
      // 公開するとき (D-344) に Central が公開範囲を確かめる材料。古いスナップショットには無い(= 確かめるまで本文を出さない)。
      'visibility': ?p.visibility,
      'url': ?p.url?.toString(),
      if (p.localOnly) 'localOnly': true,
      'author': {
        'id': p.author.id,
        'displayName': p.author.displayName,
        'avatarUrl': p.author.avatarUrl?.toString(),
        'handle': p.author.account.handle,
        'instance': p.author.account.instance,
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
    visibility: j['visibility'] as String?,
    localOnly: j['localOnly'] == true,
    url: j['url'] is String ? Uri.tryParse(j['url'] as String) : null,
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

  /// 書き換えは、読み込み(build)が終わってから — 途中で書くと、あとから届いた読み込みの結果で消える。
  Future<List<HostClip>> _loaded() async {
    // 読み終わっていれば待たない(読み終えた `future` を待つと、テストの FakeAsync では戻らない)。
    if (!state.isLoading) return state.value ?? const [];
    try {
      return await future;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save(List<HostClip> next) async {
    state = AsyncData(next);
    await ref.read(sessionStorageProvider).write(hostClipsStorageKey, jsonEncode([for (final c in next) c.toJson()]));
  }

  Future<HostClip> createClip(String name, {String? description}) async {
    await _loaded();
    final clip = HostClip(id: DateTime.now().millisecondsSinceEpoch.toRadixString(36), name: name, description: description, createdAt: DateTime.now());
    await _save([...state.value ?? const <HostClip>[], clip]);
    return clip;
  }

  /// 消す。公開中なら Central からも消す(失敗しても端末からは消す)。
  Future<void> deleteClip(String id) async {
    await _loaded();
    final clip = byId(id);
    await _save([for (final c in state.value ?? const <HostClip>[]) if (c.id != id) c]);
    final remote = clip?.remoteId;
    if (remote != null) {
      try {
        await ref.read(rasqCollectionsApiProvider)?.delete(remote);
      } catch (e) {
        debugPrint('clip unpublish on delete: $e');
      }
    }
  }

  Future<void> addPost(String clipId, Post post) async {
    await _loaded();
    await _save([
      for (final c in state.value ?? const <HostClip>[])
        if (c.id == clipId && !c.entries.any((e) => e.postKey == post.key))
          c.copyWith(entries: [...c.entries, HostClipEntry(postKey: post.key, addedAt: DateTime.now(), snapshot: postSnapshot(post))])
        else
          c,
    ]);
    await _syncRemote(clipId);
  }

  Future<void> removePost(String clipId, String postKey) async {
    await _loaded();
    await _save([
      for (final c in state.value ?? const <HostClip>[])
        if (c.id == clipId) c.copyWith(entries: [for (final e in c.entries) if (e.postKey != postKey) e]) else c,
    ]);
    await _syncRemote(clipId);
  }

  /// 公開する (D-344): Central にクリップ(`kind: clip`)を作って、載せられる項目([isPublishableEntry])を送る。
  /// 戻り値 = Central の詳細(`pending` / `gone` の数を案内に使う)。失敗したら端末は公開前のまま。
  Future<RasqCollectionDetail> publish(String clipId) async {
    final api = ref.read(rasqCollectionsApiProvider);
    final clip = byId(clipId);
    if (api == null) throw StateError(appL10n.clipsNoServer);
    if (clip == null) throw StateError(appL10n.clipsNotFound);
    final created = clip.remoteId == null ? await api.create(RasqCollectionKind.clip, clip.name, description: clip.description, isPublic: true) : null;
    final remoteId = clip.remoteId ?? created!.id;
    try {
      final detail = await api.putItems(remoteId, publishItemsOf(clip));
      await _save([for (final c in state.value ?? const <HostClip>[]) if (c.id == clipId) c.withRemote(remoteId, detail.collection.url ?? created?.url) else c]);
      return detail;
    } catch (_) {
      // 作ったばかりの空のクリップは残さない。
      if (created != null) await api.delete(created.id).catchError((_) {});
      rethrow;
    }
  }

  /// 公開をやめる (D-344): Central から消す(フォローしている人の一覧からも消える)。端末のクリップは残る。
  Future<void> unpublish(String clipId) async {
    final clip = byId(clipId);
    final remote = clip?.remoteId;
    if (remote == null) return;
    await ref.read(rasqCollectionsApiProvider)?.delete(remote);
    await _save([for (final c in state.value ?? const <HostClip>[]) if (c.id == clipId) c.withRemote(null, null) else c]);
  }

  /// 名前 / 説明を変える(公開中なら Central にも)。
  Future<void> rename(String clipId, {required String name, String? description}) async {
    await _loaded();
    await _save([for (final c in state.value ?? const <HostClip>[]) if (c.id == clipId) HostClip(id: c.id, name: name, description: description, createdAt: c.createdAt, entries: c.entries, remoteId: c.remoteId, remoteUrl: c.remoteUrl) else c]);
    final remote = byId(clipId)?.remoteId;
    if (remote != null) await ref.read(rasqCollectionsApiProvider)?.update(remote, name: name, description: description ?? '');
  }

  /// 公開中のクリップの中身を Central に写す。失敗は例外にしない(次の変更 / 公開し直しで追いつく)。
  /// 失敗は [lastSyncError] に残す(クリップのページが案内に使う)。
  Future<void> _syncRemote(String clipId) async {
    final clip = byId(clipId);
    final remote = clip?.remoteId;
    if (clip == null || remote == null) return;
    try {
      await ref.read(rasqCollectionsApiProvider)?.putItems(remote, publishItemsOf(clip));
      lastSyncError = null;
    } catch (e) {
      lastSyncError = e;
      debugPrint('clip sync: $e');
    }
  }

  /// 直近の公開中クリップの同期の失敗(無ければ null)。
  Object? lastSyncError;

  HostClip? byId(String id) => (state.value ?? const []).where((c) => c.id == id).firstOrNull;
}

/// 公開 (D-344) で Central に送る項目の形(S-042 `PUT /me/rasq-collections/{id}/items`)。
/// `refId` / `instance` は**クリップしたアカウントから見た**投稿(Central はそのサーバーで引き直す)。
/// `snapshot` は `rasq.post/1` の形。公開範囲の無い古いスナップショットは、Central が確かめるまで本文を出さない(`pending`)。
/// 公開したクリップに載せられる投稿か: 公開 / ホーム、または公開範囲の分からない古いスナップショット(Central が確かめる)。
/// フォロワー限定 / 指名 / ローカルのみは、端末のクリップには残して、公開する側には載せない(S-016 と同じ規則)。
bool isPublishableEntry(HostClipEntry e) {
  final v = e.snapshot['visibility'];
  if (e.snapshot['localOnly'] == true) return false;
  return v == null || v == 'public' || v == 'home' || v == 'unlisted';
}

/// Central に送る項目(載せられるものだけ)。
List<Map<String, Object?>> publishItemsOf(HostClip clip) => [for (final e in clip.entries) if (isPublishableEntry(e)) hostClipEntryItem(e)];

Map<String, Object?> hostClipEntryItem(HostClipEntry e) {
  final s = e.snapshot;
  final author = (s['author'] as Map?)?.cast<String, Object?>() ?? const {};
  final kind = (s['kind'] ?? 'other').toString();
  final instance = (s['instance'] ?? '').toString();
  return {
    'kind': kind,
    'instance': instance,
    'refId': (s['id'] ?? '').toString(),
    'url': ?s['url'],
    'snapshot': {
      'id': s['id'],
      'author': {
        'id': author['id'],
        'kind': kind,
        'instance': author['instance'] ?? instance,
        'handle': author['handle'] ?? '',
        'displayName': author['displayName'],
        'avatarUrl': ?author['avatarUrl'],
      },
      'createdAt': s['createdAt'],
      'body': s['body'] ?? '',
      'cw': ?s['contentWarning'],
      if ((s['media'] as List?)?.isNotEmpty ?? false) 'media': s['media'],
      'visibility': ?s['visibility'],
      if (s['localOnly'] == true) 'localOnly': true,
      'url': ?s['url'],
    },
  };
}

final hostClipsProvider = AsyncNotifierProvider<HostClipsStore, List<HostClip>>(HostClipsStore.new);
