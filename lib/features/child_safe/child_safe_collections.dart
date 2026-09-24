import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../clips/host_clips.dart';
import 'child_gate.dart';
import 'child_safe_providers.dart' show childGateProvider;

/// 見守り中に出さないクリップ / リスト (D-314): 中身が保護者の**止める例**に近いもの。
/// 止める例が無ければ何も読まない(空)。あれば、自分のクリップ / リスト(と RASQ 横断クリップ)の先頭
/// [_collectionPosts] 件の本文を読んで [ChildGate.collectionHidden] で確かめる。鍵 = `clip:<ClipInfo.id>` / `list:<id>`。
const _collectionPosts = 10;
const _collectionLimit = 30;

String _postText(Post p) => '${p.body} ${p.quote?.body ?? ''}';

/// クリップ / リストの名前 + 説明(例の要約と同じ形)。
String childSafeCollectionMeta(String name, String? description) => '$name ${description ?? ''}'.trim();

final childSafeHiddenCollectionsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  ref.watch(childGateProvider.select((g) => g.collectionSignature));
  final gate = ref.read(childGateProvider);
  if (!gate.hasDenyExamples) return const {};
  final session = ref.watch(currentSnsSessionProvider);
  final out = <String>{};
  Future<List<String>> bodies(Future<Page<Post>> Function() f) async {
    try {
      return [for (final p in (await f()).items.take(_collectionPosts)) _postText(p)];
    } catch (_) {
      return const []; // 読めなければ名前と説明だけで
    }
  }

  Future<List<T>> orEmpty<T>(Future<List<T>> Function() f) async {
    try {
      return await f();
    } catch (_) {
      return const [];
    }
  }

  final jobs = <Future<void>>[];
  if (session != null) {
    for (final l in (await orEmpty(session.lists)).take(_collectionLimit)) {
      jobs.add(bodies(() => session.timeline(TimelineKind.list(l.id, l.name), limit: _collectionPosts)).then((b) {
        if (gate.collectionHidden(childSafeCollectionMeta(l.name, l.description), b)) out.add('list:${l.id}');
      }));
    }
    for (final c in (await orEmpty(() => session.clips())).take(_collectionLimit)) {
      jobs.add(bodies(() => session.clipNotes(c.id, limit: _collectionPosts)).then((b) {
        if (gate.collectionHidden(childSafeCollectionMeta(c.name, c.description), b)) out.add('clip:${c.id}');
      }));
    }
  }
  final host = await orEmpty(() => ref.watch(hostClipsProvider.future));
  for (final h in host) {
    final b = [for (final e in h.entries.take(_collectionPosts)) _postText(postFromSnapshot(e.snapshot))];
    if (gate.collectionHidden(childSafeCollectionMeta(h.name, h.description), b)) out.add('clip:${h.info.id}');
  }
  await Future.wait(jobs);
  return out;
});

/// このクリップ / リスト([kind] = `clip` / `list`)を出さないか。中身を読み終わるまで([hidden] が null)は、
/// 止める例があれば**出さない**(読み終わってから出す)。名前と説明だけでも近ければ出さない。
bool childSafeCollectionHidden(ChildGate gate, Set<String>? hidden, {required String kind, required String id, required String name, String? description}) {
  if (!gate.hasDenyExamples) return false;
  if (hidden == null) return true;
  return hidden.contains('$kind:$id') || gate.collectionHidden(childSafeCollectionMeta(name, description));
}
