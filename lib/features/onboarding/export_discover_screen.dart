import 'dart:async';
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/router.dart';
import '../../backend/limited_http.dart';
import '../../backend/link_match_api.dart';
import '../../backend/orgate_client.dart';
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import '../collections/rasq_collections.dart' show hasRasqAccountProvider;
import 'export_archive.dart';

/// 外部 SNS のエクスポートデータから探す (D-551、Central S-129)。
///
/// 書き出しのファイルを選ぶ → **端末で読む**(`export_archive.dart`。書き出しは端末から出さない)→ X の書き出しなら
/// 「X で認証」(**ダミー**: いまは X には確かめに行かない)→ 1 人ずつ `sha256(ソルト \n サービス \n 名前)` を作って
/// Central に照合(200 件ずつ)→ 見つかった RASQ のユーザーを並べる。

/// ファイルを選ぶ口(テストで差し替える)。
final exportFilePickerProvider = Provider<Future<List<XFile>> Function()>((ref) => () => openFiles(acceptedTypeGroups: [
      XTypeGroup(label: appL10n.onboardingExportFileTypeLabel, extensions: const ['zip', 'js', 'json', 'html', 'csv', 'txt', 'car'], uniformTypeIdentifiers: const ['public.data']),
    ]));

/// 選んだファイルを読む口(テストで差し替える)。端末ではパスから別の isolate で読み、パスで読めなければ中身を読んでから。
final exportArchiveReaderProvider = Provider<Future<ExportArchive> Function(List<XFile>)>((ref) => (files) async {
      if (!kIsWeb) {
        try {
          return await compute(parseExportPaths, [for (final f in files) (name: f.name, path: f.path)]);
        } catch (e) {
          debugPrint('export read by path: $e');
        }
      }
      final loaded = [for (final f in files) (name: f.name, bytes: await f.readAsBytes())];
      return kIsWeb ? parseExportBytes(loaded) : compute(parseExportBytes, loaded);
    });

/// Bluesky の DID → ハンドル(公開 API、25 件ずつ)。引けなかった DID は入らない。テストで差し替える。
final blueskyHandleResolverProvider = Provider<Future<Map<String, String>> Function(List<String> dids)>((ref) => resolveBlueskyHandles);

/// 一度に引き直す DID の上限(これより多い分は DID のまま照合する)。
const blueskyResolveMax = 2000;

Future<Map<String, String>> resolveBlueskyHandles(List<String> dids) async {
  final out = <String, String>{};
  final todo = dids.take(blueskyResolveMax).toList();
  for (var i = 0; i < todo.length; i += 25) {
    final chunk = todo.sublist(i, i + 25 > todo.length ? todo.length : i + 25);
    final url = Uri.parse('https://public.api.bsky.app/xrpc/app.bsky.actor.getProfiles?${chunk.map((d) => 'actors=${Uri.encodeQueryComponent(d)}').join('&')}');
    try {
      final res = await getLimited(url, maxBytes: 2 * 1024 * 1024, timeout: const Duration(seconds: 15));
      if (res.statusCode != 200) continue;
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      for (final p in (j is Map ? j['profiles'] : null) as List? ?? const []) {
        if (p is Map && p['did'] is String && p['handle'] is String && p['handle'] != 'handle.invalid') out[(p['did'] as String).toLowerCase()] = p['handle'] as String;
      }
    } catch (e) {
      debugPrint('bluesky resolve: $e');
    }
  }
  return out;
}

/// 見つかった RASQ のユーザーと、書き出しのどの人で当たったか。
@immutable
class ExportMatch {
  const ExportMatch({required this.account, required this.people});
  final LinkMatchAccount account;
  final List<ExportPerson> people;
}

/// 書き出しの人を Central に照合する。[onProgress] = (済んだ鍵の数, 全部の数)。回数の制限(429)は少し待って送り直す。
Future<List<ExportMatch>> matchExportPeople(LinkMatchApi api, List<ExportPerson> people, {void Function(int done, int total)? onProgress, Duration retryWait = const Duration(seconds: 5)}) async {
  final info = await api.info();
  // 鍵(サービス + ハッシュ)→ その鍵を持つ人。
  final owners = <String, List<ExportPerson>>{};
  final items = <({String service, String hash})>[];
  for (final p in people) {
    for (final k in p.keys) {
      final hash = linkMatchHash(info.salt, k.service, k.name);
      final id = '${k.service}\n$hash';
      if (!owners.containsKey(id)) items.add((service: k.service, hash: hash));
      (owners[id] ??= []).add(p);
    }
  }
  final byAccount = <String, ({LinkMatchAccount account, Set<ExportPerson> people})>{};
  var done = 0;
  onProgress?.call(0, items.length);
  for (var i = 0; i < items.length; i += info.maxItems) {
    final chunk = items.sublist(i, i + info.maxItems > items.length ? items.length : i + info.maxItems);
    Map<String, List<LinkMatchAccount>> hit;
    for (var attempt = 0;; attempt++) {
      try {
        hit = await api.match(chunk);
        break;
      } on OrgateException catch (e) {
        if (!isRateLimited(e) || attempt >= 6) rethrow;
        await Future<void>.delayed(retryWait);
      }
    }
    for (final MapEntry(key: id, value: accounts) in hit.entries) {
      for (final a in accounts) {
        final slot = byAccount[a.id] ??= (account: a, people: <ExportPerson>{});
        // 確認済みで当たった方を残す。
        if (a.verified && !slot.account.verified) byAccount[a.id] = (account: a, people: slot.people);
        byAccount[a.id]!.people.addAll(owners[id] ?? const []);
      }
    }
    done += chunk.length;
    onProgress?.call(done, items.length);
  }
  final out = [for (final v in byAccount.values) ExportMatch(account: v.account, people: v.people.toList())];
  // フォロー中の人 → フォロワー → やりとりだけ、の順。同じなら名前の順。
  int rank(ExportMatch m) => m.people.any((p) => p.relations.contains(ExportRelation.following)) ? 0 : (m.people.any((p) => p.relations.contains(ExportRelation.follower)) ? 1 : 2);
  out.sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.account.handle.compareTo(b.account.handle));
  return out;
}

String exportKindLabel(ExportKind k) => switch (k) {
      ExportKind.x => 'X',
      ExportKind.fediverse => 'Mastodon / Misskey',
      ExportKind.instagram => 'Instagram',
      ExportKind.threads => 'Threads',
      ExportKind.bluesky => 'Bluesky',
    };

class DiscoverExportScreen extends ConsumerStatefulWidget {
  const DiscoverExportScreen({super.key});
  @override
  ConsumerState<DiscoverExportScreen> createState() => _DiscoverExportScreenState();
}

class _DiscoverExportScreenState extends ConsumerState<DiscoverExportScreen> {
  ExportArchive? _archive;
  bool _reading = false;
  bool _matching = false;
  (int, int)? _progress;
  String? _error;
  List<ExportMatch>? _matches;

  /// ダミーの X 認証を済ませたか(X の書き出しを使うときだけ要る)。
  bool _xAuthed = false;

  /// 自分の X をプロフィールに登録した / している最中。
  bool _xRegistered = false;
  bool _xRegistering = false;

  Future<void> _pick() async {
    List<XFile> files;
    try {
      files = await ref.read(exportFilePickerProvider)();
    } catch (e) {
      debugPrint('export pick: $e');
      if (mounted) setState(() => _error = context.l10n.onboardingExportPickFailed);
      return;
    }
    if (files.isEmpty || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
      _matches = null;
    });
    try {
      var archive = await ref.read(exportArchiveReaderProvider)(files);
      final dids = [for (final p in archive.people) if (p.kind == ExportKind.bluesky) p.keys.first.name];
      if (dids.isNotEmpty) archive = withBlueskyHandles(archive, await ref.read(blueskyHandleResolverProvider)(dids));
      if (!mounted) return;
      setState(() {
        _archive = archive;
        _xRegistered = false;
        if (archive.isEmpty) _error = context.l10n.onboardingExportNothingFound;
      });
    } catch (e) {
      debugPrint('export read: $e');
      if (mounted) setState(() => _error = context.l10n.onboardingExportReadFailed);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _search() async {
    final archive = _archive;
    final api = ref.read(linkMatchApiProvider);
    if (archive == null || archive.people.isEmpty || _matching) return;
    if (api == null) {
      setState(() => _error = context.l10n.onboardingDiscoverNoCentral);
      return;
    }
    setState(() {
      _matching = true;
      _progress = null;
      _error = null;
      _matches = null;
    });
    try {
      final r = await matchExportPeople(api, archive.people, onProgress: (d, t) {
        if (mounted) setState(() => _progress = (d, t));
      });
      if (mounted) setState(() => _matches = r);
    } catch (e) {
      debugPrint('export match: $e');
      if (mounted) setState(() => _error = isRateLimited(e) ? context.l10n.onboardingExportBusy : context.l10n.onboardingExportMatchFailed);
    } finally {
      if (mounted) setState(() => _matching = false);
    }
  }

  /// 自分の X(書き出しの account.js)をプロフィールに登録する = ダミーの X 認証の、探される側。
  Future<void> _registerX(ExportXSelf self) async {
    final api = ref.read(linkMatchApiProvider);
    if (api == null || _xRegistering) return;
    setState(() => _xRegistering = true);
    try {
      await api.putXIdentity(handle: self.handle, userId: self.userId);
      if (mounted) setState(() => _xRegistered = true);
    } catch (e) {
      debugPrint('export x identity: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.onboardingExportXRegisterFailed)));
    } finally {
      if (mounted) setState(() => _xRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final bold = RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700);
    final archive = _archive;
    final busy = _reading || _matching;
    final hasX = archive?.kinds.contains(ExportKind.x) ?? false;
    final needXAuth = hasX && !_xAuthed;
    final matches = _matches;
    final xSelf = archive?.xSelf;
    return Scaffold(
      appBar: RasqPageHeader(title: l10n.onboardingDiscoverExportTitle, showMore: false),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(key: const ValueKey('discover.export.list'), padding: const EdgeInsets.all(RasqSpacing.page), children: [
              Text(l10n.onboardingExportIntro, style: caption),
              const SizedBox(height: RasqSpacing.xs),
              Text(l10n.onboardingExportFormats, style: caption),
              const SizedBox(height: RasqSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('discover.export.pick'),
                  onPressed: busy ? null : _pick,
                  icon: const Icon(Icons.file_open_outlined, size: 18),
                  label: Text(archive == null ? l10n.onboardingExportPick : l10n.onboardingExportPickAgain),
                ),
              ),
              if (_reading) const Padding(padding: EdgeInsets.all(RasqSpacing.md), child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              if (archive != null && !archive.isEmpty) ...[
                const SizedBox(height: RasqSpacing.md),
                Text(l10n.onboardingExportFoundHeading, style: bold),
                const SizedBox(height: RasqSpacing.xs),
                for (final k in ExportKind.values)
                  if (archive.count(k) > 0)
                    Text(
                      l10n.onboardingExportFoundLine(exportKindLabel(k), archive.count(k, ExportRelation.following), archive.count(k, ExportRelation.follower), archive.count(k, ExportRelation.mention)),
                      key: ValueKey('discover.export.found.${k.name}'),
                      style: RasqTypography.bodySmall,
                    ),
                if (hasX && archive.count(ExportKind.x) > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: RasqSpacing.xs),
                    child: Text(l10n.onboardingExportXIdNote(archive.xWithHandle), key: const ValueKey('discover.export.xNote'), style: caption),
                  ),
                if (archive.skipped.isNotEmpty) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(l10n.onboardingExportSkipped(archive.skipped.length), style: caption)),
                if (hasX) ...[
                  const SizedBox(height: RasqSpacing.sm),
                  _Card(key: const ValueKey('discover.export.xAuth'), children: [
                    Row(children: [
                      Icon(_xAuthed ? Icons.check_circle_outline : Icons.lock_outline, size: 18),
                      const SizedBox(width: RasqSpacing.xs),
                      Expanded(child: Text(_xAuthed ? l10n.onboardingExportXAuthDone : l10n.onboardingExportXAuthTitle, style: bold)),
                    ]),
                    Text(l10n.onboardingExportXAuthDummyNote, key: const ValueKey('discover.export.xAuth.dummy'), style: caption),
                    if (!_xAuthed)
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton(key: const ValueKey('discover.export.xAuth.button'), onPressed: busy ? null : () => setState(() => _xAuthed = true), child: Text(l10n.onboardingExportXAuthButton)),
                      ),
                  ]),
                ],
                if (xSelf != null && _xAuthed && ref.watch(hasRasqAccountProvider)) ...[
                  const SizedBox(height: RasqSpacing.xs),
                  _Card(key: const ValueKey('discover.export.xSelf'), children: [
                    Text(l10n.onboardingExportXSelfTitle(xSelf.handle), style: bold),
                    Text(l10n.onboardingExportXSelfBody, style: caption),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _xRegistered
                          ? Text(l10n.onboardingExportXSelfDone, key: const ValueKey('discover.export.xSelf.done'), style: caption)
                          : TextButton(key: const ValueKey('discover.export.xSelf.register'), onPressed: _xRegistering ? null : () => _registerX(xSelf), child: Text(l10n.onboardingExportXSelfRegister)),
                    ),
                  ]),
                ],
                if (archive.people.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: RasqSpacing.sm),
                    child: FilledButton.icon(
                      key: const ValueKey('discover.export.search'),
                      onPressed: busy || needXAuth ? null : _search,
                      icon: const Icon(Icons.person_search, size: 18),
                      label: Text(l10n.onboardingExportSearch(archive.people.length)),
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    ),
                  ),
                Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(l10n.onboardingExportHashNote, style: caption)),
              ],
              if (_matching)
                Padding(
                  padding: const EdgeInsets.only(top: RasqSpacing.sm),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    LinearProgressIndicator(key: const ValueKey('discover.export.progress'), value: _progress == null || _progress!.$2 == 0 ? null : _progress!.$1 / _progress!.$2),
                    if (_progress != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(l10n.onboardingExportProgress(_progress!.$1, _progress!.$2), style: caption)),
                  ]),
                ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_error!, key: const ValueKey('discover.export.error'), style: RasqTypography.bodySmall.copyWith(color: scheme.error))),
              if (matches != null) ...[
                const SizedBox(height: RasqSpacing.md),
                Text(matches.isEmpty ? l10n.onboardingExportNoMatches : l10n.onboardingExportMatchesHeading(matches.length), key: const ValueKey('discover.export.matches'), style: matches.isEmpty ? caption : bold),
                const SizedBox(height: RasqSpacing.xs),
                for (final m in matches) Padding(padding: const EdgeInsets.only(bottom: RasqSpacing.xs), child: LinkMatchAccountCard(account: m.account, via: _via(context, m))),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  /// 「X のフォロー: @taro」のような、どこで当たったか。
  String _via(BuildContext context, ExportMatch m) {
    final l10n = context.l10n;
    final p = m.people.first;
    final relation = p.relations.contains(ExportRelation.following)
        ? l10n.onboardingExportRelationFollowing
        : p.relations.contains(ExportRelation.follower)
            ? l10n.onboardingExportRelationFollower
            : l10n.onboardingExportRelationMention;
    return l10n.onboardingExportVia(exportKindLabel(p.kind), relation, p.label);
  }
}

class _Card extends StatelessWidget {
  const _Card({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(RasqSizes.radiusMd), border: Border.all(color: scheme.outlineVariant)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// 見つかった RASQ のユーザーのカード。タップでアカウントのページ(探す画面の中のルートなので、SNS にログインする前でも開ける)。
/// [via] = どこで当たったか(無ければ出さない)。
class LinkMatchAccountCard extends StatelessWidget {
  const LinkMatchAccountCard({super.key, required this.account, this.via});
  final LinkMatchAccount account;
  final String? via;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RasqSizes.radiusMd), side: BorderSide(color: scheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('discover.account.${account.handle}'),
        onTap: () => context.push(Routes.snsDiscoverAccount(account.handle)),
        child: Padding(
          padding: const EdgeInsets.all(RasqSpacing.sm),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RasqAvatar(imageUrl: account.avatarUrl, fallbackLabel: account.label, size: 40),
            const SizedBox(width: RasqSpacing.sm),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Flexible(child: Text(account.label, style: RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  if (account.verified) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.verified_outlined, size: 14, color: scheme.primary)),
                ]),
                Text('@${account.handle}', style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (account.bio.isNotEmpty) Text(account.bio, style: RasqTypography.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                if (via != null) Text(via!, style: caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (via != null && !account.verified) Text(context.l10n.onboardingExportUnverified, style: caption),
              ]),
            ),
            Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
