import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';

import '../../backend/link_match_api.dart';

/// ほかの SNS の書き出し(エクスポート)を端末で読む (D-551)。書き出しは端末から出さない: ここで取り出すのは
/// 「どのサービスの、誰か」(サービス + 名前)だけで、Central へはそのハッシュを送る(`link_match_api.dart`)。
///
/// 読める形:
/// - **X(Twitter)** の zip か、中の `account.js` / `following.js` / `follower.js` / `tweets.js`。フォロー / フォロワーは
///   **内部 ID だけ**なので、鍵は `id:<数字>`。ツイートのメンションに出てくる相手は ID とハンドルの両方が分かるので、ハンドルの鍵も足す。
/// - **Mastodon / Misskey** のフォローの CSV(1 列目が `user@host`)。
/// - **Instagram / Threads** の zip か、中の `followers_*.json` / `following.json`(HTML 版も)。
/// - **Bluesky** の `repo.car`(フォローの相手の DID。ハンドルは [resolveBlueskyHandles] で公開 API から引き直す)。

enum ExportKind { x, fediverse, instagram, threads, bluesky }

enum ExportRelation { following, follower, mention }

/// 書き出しに出てきた 1 人。[keys] のどれかが当たれば、その人。
@immutable
class ExportPerson {
  const ExportPerson({required this.kind, required this.label, required this.keys, required this.relations});
  final ExportKind kind;

  /// 画面に出す名前(`@taro` / `@taro@example.social` / `ID 123`)。
  final String label;

  /// (サービス, 名前)。揃えたあとの形([linkMatchService] / [linkMatchName])。
  final List<({String service, String name})> keys;
  final Set<ExportRelation> relations;

  String get id => '${kind.name}:${keys.first.service}:${keys.first.name}';
}

/// 自分の X のアカウント(`account.js`)。
typedef ExportXSelf = ({String handle, String userId});

@immutable
class ExportArchive {
  const ExportArchive({this.people = const [], this.xSelf, this.recognized = const [], this.skipped = const []});
  final List<ExportPerson> people;
  final ExportXSelf? xSelf;

  /// 読めたファイルの名前。
  final List<String> recognized;

  /// 大きすぎて読まなかったファイルの名前。
  final List<String> skipped;

  bool get isEmpty => people.isEmpty && xSelf == null;
  Set<ExportKind> get kinds => {for (final p in people) p.kind, if (xSelf != null) ExportKind.x};
  int count(ExportKind kind, [ExportRelation? relation]) => people.where((p) => p.kind == kind && (relation == null || p.relations.contains(relation))).length;

  /// X のフォロー / フォロワーのうち、ハンドルまで分かった人の数。
  int get xWithHandle => people.where((p) => p.kind == ExportKind.x && p.keys.length > 1).length;
}

/// 読むもの 1 つ(選んだファイル、または zip の中のファイル)。[read] は呼んだときに中身を読む。
class ExportEntry {
  ExportEntry({required this.name, required this.size, required this.read});
  final String name;
  final int size;
  final Uint8List? Function() read;
  String get base => name.split(RegExp(r'[/\\]')).last.toLowerCase();
}

/// 1 つのファイルの上限(超えたら読まない)と、ツイートの合計の上限。
const exportEntryMaxBytes = 96 * 1024 * 1024;
const exportTweetsMaxBytes = 256 * 1024 * 1024;

/// zip の中身を [ExportEntry] に(読むのは要るものだけ)。
List<ExportEntry> exportEntriesOfArchive(Archive archive) => [
      for (final f in archive.files)
        if (f.isFile) ExportEntry(name: f.name, size: f.size, read: () => f.readBytes()),
    ];

bool _isTweets(String base) => RegExp(r'^tweets?(-part\d+)?\.js$').hasMatch(base);
bool _isInstaFollow(ExportEntry e) => RegExp(r'^(followers|following)(_\d+)?\.(json|html)$').hasMatch(e.base);

/// `window.YTD.x.part0 = [...]` の配列。読めなければ空。
List<Object?> _ytd(Uint8List bytes) {
  final s = utf8.decode(bytes, allowMalformed: true);
  final i = s.indexOf('[');
  if (i < 0) return const [];
  try {
    final j = jsonDecode(s.substring(i));
    return j is List ? j : const [];
  } catch (_) {
    return const [];
  }
}

final _mentionObject = RegExp(r'\{[^{}]*"screen_name"\s*:\s*"([A-Za-z0-9_]{1,15})"[^{}]*\}');
final _idStr = RegExp(r'"id_str"\s*:\s*"(\d{1,20})"');

/// ツイートのメンション(`user_mentions`)から、内部 ID → ハンドル。JSON として読まずに走査する(大きいファイルのため)。
Map<String, String> xMentionsOf(Uint8List tweetsJs) {
  final s = latin1.decode(tweetsJs);
  final out = <String, String>{};
  for (final m in _mentionObject.allMatches(s)) {
    final id = _idStr.firstMatch(m.group(0)!)?.group(1);
    // -1 は消えたアカウント。
    if (id != null && id != '-1') out[id] = m.group(1)!;
  }
  return out;
}

final _acct = RegExp(r'^@?([A-Za-z0-9_.-]{1,64})@([A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+)$');

/// CSV の 1 列目が `user@host` の行。
List<({String user, String host})> fediverseAccountsOf(Uint8List csv) {
  final out = <({String user, String host})>[];
  for (final line in const LineSplitter().convert(utf8.decode(csv, allowMalformed: true))) {
    final first = line.split(',').first.trim().replaceAll('"', '');
    final m = _acct.firstMatch(first);
    if (m != null) out.add((user: m.group(1)!, host: m.group(2)!));
  }
  return out;
}

final _instaUrl = RegExp(r'https?:(?:\\?/){2}(?:www\.)?(instagram\.com|threads\.net|threads\.com)\\?/(?:_u\\?/)?@?([A-Za-z0-9._]{1,30})');
const _instaReserved = {'p', 'reel', 'reels', 'explore', 'stories', 'accounts', '_u'};

/// Instagram / Threads のフォローのファイル(JSON / HTML)から、プロフィールの URL の (サービス, 名前)。
List<({String service, String name})> instagramAccountsOf(Uint8List file) {
  final s = utf8.decode(file, allowMalformed: true);
  final out = <({String service, String name})>[];
  for (final m in _instaUrl.allMatches(s)) {
    final name = m.group(2)!.toLowerCase();
    if (_instaReserved.contains(name)) continue;
    out.add((service: linkMatchService(m.group(1)!), name: name));
  }
  return out;
}

const _followType = 'app.bsky.graph.follow';

/// Bluesky の `repo.car` から、フォローの相手の DID。CAR / CBOR を全部は読まず、フォローの記録
/// (`$type: app.bsky.graph.follow` の次の鍵が `subject`)を走査して、CBOR の長さの頭から文字列を切り出す。
List<String> blueskyFollowDidsOf(Uint8List car) {
  final needle = ascii.encode(_followType);
  final subject = ascii.encode('subject');
  final did = ascii.encode('did:');
  final out = <String>{};
  int find(List<int> pat, int from, int to) {
    final end = to - pat.length;
    outer:
    for (var i = from; i <= end; i++) {
      for (var k = 0; k < pat.length; k++) {
        if (car[i + k] != pat[k]) continue outer;
      }
      return i;
    }
    return -1;
  }

  var at = 0;
  while (true) {
    final i = find(needle, at, car.length);
    if (i < 0) break;
    at = i + needle.length;
    final windowEnd = (at + 24 < car.length) ? at + 24 : car.length;
    final s = find(subject, at, windowEnd);
    if (s < 0) continue;
    final d = find(did, s + subject.length, (s + subject.length + 8 < car.length) ? s + subject.length + 8 : car.length);
    if (d < 2) continue;
    // 文字列の頭: 0x60+長さ(24 未満)/ 0x78, 長さ(255 まで)。
    int? len;
    if (car[d - 2] == 0x78) {
      len = car[d - 1];
    } else if (car[d - 1] >= 0x60 && car[d - 1] <= 0x77) {
      len = car[d - 1] - 0x60;
    }
    if (len == null || len < 8 || d + len > car.length) continue;
    final text = ascii.decode(car.sublist(d, d + len), allowInvalid: true);
    if (RegExp(r'^did:[a-z]+:[A-Za-z0-9._:%-]+$').hasMatch(text)) out.add(text);
  }
  return out.toList();
}

/// 読むものを全部読んで、人の一覧にする。重いので、端末では別の isolate から呼ぶ。
ExportArchive parseExportEntries(List<ExportEntry> entries) {
  final recognized = <String>[];
  final skipped = <String>[];
  Uint8List? take(ExportEntry e, {int max = exportEntryMaxBytes}) {
    if (e.size > max) {
      skipped.add(e.name);
      return null;
    }
    try {
      final b = e.read();
      if (b != null) recognized.add(e.name);
      return b;
    } catch (_) {
      return null;
    }
  }

  // 同じ人は 1 つに(鍵は足し、関係は合わせる)。
  final people = <String, ExportPerson>{};
  void add(ExportKind kind, String label, List<({String service, String name})> keys, ExportRelation relation) {
    if (keys.isEmpty) return;
    final id = '${kind.name}:${keys.first.service}:${keys.first.name}';
    final old = people[id];
    people[id] = old == null
        ? ExportPerson(kind: kind, label: label, keys: keys, relations: {relation})
        : ExportPerson(kind: kind, label: old.keys.length >= keys.length ? old.label : label, keys: old.keys.length >= keys.length ? old.keys : keys, relations: {...old.relations, relation});
  }

  // ── X ──
  ExportXSelf? xSelf;
  final xIds = <String, Set<ExportRelation>>{};
  final mentions = <String, String>{};
  var tweetBytes = 0;
  for (final e in entries) {
    switch (e.base) {
      case 'account.js':
        final b = take(e);
        if (b == null) break;
        for (final row in _ytd(b)) {
          final a = row is Map ? row['account'] : null;
          if (a is Map && '${a['username'] ?? ''}'.isNotEmpty && linkMatchXId('${a['accountId'] ?? ''}') != null) {
            xSelf = (handle: '${a['username']}', userId: '${a['accountId']}');
          }
        }
      case 'following.js' || 'follower.js':
        final b = take(e);
        if (b == null) break;
        final field = e.base == 'following.js' ? 'following' : 'follower';
        for (final row in _ytd(b)) {
          final id = row is Map && row[field] is Map ? '${(row[field] as Map)['accountId'] ?? ''}' : '';
          if (linkMatchXId(id) != null) (xIds[id] ??= {}).add(field == 'following' ? ExportRelation.following : ExportRelation.follower);
        }
      default:
        if (_isTweets(e.base)) {
          if (tweetBytes + e.size > exportTweetsMaxBytes) {
            skipped.add(e.name);
            break;
          }
          final b = take(e, max: exportTweetsMaxBytes);
          if (b == null) break;
          tweetBytes += e.size;
          mentions.addAll(xMentionsOf(b));
        }
    }
  }
  final selfId = xSelf?.userId;
  for (final MapEntry(key: id, value: rels) in xIds.entries) {
    final handle = mentions[id];
    for (final r in rels) {
      add(ExportKind.x, handle == null ? 'ID $id' : '@$handle', [(service: 'x.com', name: 'id:$id'), if (handle != null) (service: 'x.com', name: handle.toLowerCase())], r);
    }
  }
  for (final MapEntry(key: id, value: handle) in mentions.entries) {
    if (xIds.containsKey(id) || id == selfId) continue;
    add(ExportKind.x, '@$handle', [(service: 'x.com', name: 'id:$id'), (service: 'x.com', name: handle.toLowerCase())], ExportRelation.mention);
  }

  // ── Mastodon / Misskey ──
  for (final e in entries) {
    if (!(e.base.endsWith('.csv') || e.base.endsWith('.txt')) || e.base.contains('block') || e.base.contains('mute')) continue;
    final b = take(e);
    if (b == null) continue;
    final accounts = fediverseAccountsOf(b);
    if (accounts.isEmpty) {
      recognized.remove(e.name);
      continue;
    }
    final relation = e.base.contains('follower') ? ExportRelation.follower : ExportRelation.following;
    for (final a in accounts) {
      final name = linkMatchName(a.user);
      if (name != null) add(ExportKind.fediverse, '@${a.user}@${a.host}', [(service: linkMatchService(a.host), name: name)], relation);
    }
  }

  // ── Instagram / Threads ──
  for (final e in entries) {
    if (!_isInstaFollow(e)) continue;
    final b = take(e);
    if (b == null) continue;
    final accounts = instagramAccountsOf(b);
    if (accounts.isEmpty) {
      recognized.remove(e.name);
      continue;
    }
    final relation = e.base.startsWith('following') ? ExportRelation.following : ExportRelation.follower;
    for (final a in accounts) {
      add(a.service == 'threads.net' ? ExportKind.threads : ExportKind.instagram, '@${a.name}', [a], relation);
    }
  }

  // ── Bluesky ──
  for (final e in entries) {
    if (!e.base.endsWith('.car')) continue;
    final b = take(e);
    if (b == null) continue;
    for (final did in blueskyFollowDidsOf(b)) {
      add(ExportKind.bluesky, did, [(service: 'bsky.app', name: did.toLowerCase())], ExportRelation.following);
    }
  }

  return ExportArchive(people: people.values.toList(), xSelf: xSelf, recognized: recognized, skipped: skipped);
}

/// 選んだファイル(名前と中身)を読む。zip は中を開く。Web と、パスの無いファイルの口。
ExportArchive parseExportBytes(List<({String name, Uint8List bytes})> files) {
  final entries = <ExportEntry>[];
  for (final f in files) {
    if (f.name.toLowerCase().endsWith('.zip')) {
      try {
        entries.addAll(exportEntriesOfArchive(ZipDecoder().decodeBytes(f.bytes)));
      } catch (_) {}
    } else {
      entries.add(ExportEntry(name: f.name, size: f.bytes.length, read: () => f.bytes));
    }
  }
  return parseExportEntries(entries);
}

/// Bluesky の DID → ハンドルを足した一覧に([handles] に無い DID はそのまま)。
ExportArchive withBlueskyHandles(ExportArchive archive, Map<String, String> handles) => ExportArchive(
      xSelf: archive.xSelf,
      recognized: archive.recognized,
      skipped: archive.skipped,
      people: [
        for (final p in archive.people)
          if (p.kind == ExportKind.bluesky && handles[p.keys.first.name] != null && linkMatchName(handles[p.keys.first.name]!) != null)
            ExportPerson(kind: p.kind, label: '@${handles[p.keys.first.name]}', keys: [p.keys.first, (service: 'bsky.app', name: linkMatchName(handles[p.keys.first.name]!)!)], relations: p.relations)
          else
            p,
      ],
    );

/// 選んだファイル(名前とパス)を読む。zip は中を必要なものだけ読む(全体をメモリに載せない)。端末の口(別の isolate から)。
ExportArchive parseExportPaths(List<({String name, String path})> files) {
  final entries = <ExportEntry>[];
  final streams = <InputFileStream>[];
  try {
    for (final f in files) {
      final input = InputFileStream(f.path);
      streams.add(input);
      if (f.name.toLowerCase().endsWith('.zip')) {
        try {
          entries.addAll(exportEntriesOfArchive(ZipDecoder().decodeStream(input)));
        } catch (_) {}
      } else {
        entries.add(ExportEntry(name: f.name, size: input.length, read: () => input.toUint8List()));
      }
    }
    return parseExportEntries(entries);
  } finally {
    for (final s in streams) {
      try {
        s.closeSync();
      } catch (_) {}
    }
  }
}
