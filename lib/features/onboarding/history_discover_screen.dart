import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../backend/link_match_api.dart' show LinkMatchAccount;
import '../../backend/onboarding_discover_api.dart';
import '../../backend/rasq_account_page_api.dart' show RasqPostAuthor, rasqAccountPageApiProvider;
import '../../l10n/l10n.dart';
import '../../shell/headers.dart';
import 'discover_history.dart';
import 'export_discover_screen.dart' show LinkMatchAccountCard;
import 'sns_discover_screen.dart' show DiscoverResultsView;

/// 検索履歴を統合して探す (D-553)。「SNS サービスを探す」でこれまでに探した言葉(人から探す / 画像から探す / この画面を探す)を
/// 並べ、選んだ言葉をまとめて、RASQ のユーザー(`/accounts/search`)と RASQ リスト(`/onboarding/discover/lists`)を探す。
/// 履歴は端末の中だけ。RAi は呼ばない(軽い検索だけ)。

/// 1 回に使う言葉の数の上限と、はじめに選んでおく数。
const historyDiscoverMaxTerms = 8;
const historyDiscoverPreselect = 5;

@immutable
class HistoryDiscoverOutcome {
  const HistoryDiscoverOutcome({this.accounts = const [], this.lists = const []});
  final List<RasqPostAuthor> accounts;
  final List<ListHit> lists;
  bool get isEmpty => accounts.isEmpty && lists.isEmpty;
}

/// 選んだ言葉で探す: ユーザーは言葉ごと、リストは言葉をまとめて 1 回。片方が失敗しても、もう片方は出す。
Future<HistoryDiscoverOutcome> runHistoryDiscover({
  required List<String> terms,
  required Future<List<RasqPostAuthor>> Function(String term) searchAccounts,
  required Future<List<ListHit>> Function(String query) searchLists,
}) async {
  final use = terms.take(historyDiscoverMaxTerms).toList();
  if (use.isEmpty) return const HistoryDiscoverOutcome();
  final accounts = <String, RasqPostAuthor>{};
  var lists = const <ListHit>[];
  await Future.wait([
    for (final t in use)
      () async {
        try {
          for (final a in await searchAccounts(t)) {
            accounts.putIfAbsent(a.handle, () => a);
          }
        } catch (e) {
          debugPrint('history discover accounts: $e');
        }
      }(),
    () async {
      try {
        lists = await searchLists(use.join(' '));
      } catch (e) {
        debugPrint('history discover lists: $e');
      }
    }(),
  ]);
  return HistoryDiscoverOutcome(accounts: accounts.values.toList(), lists: lists);
}

class DiscoverHistoryScreen extends ConsumerStatefulWidget {
  const DiscoverHistoryScreen({super.key});
  @override
  ConsumerState<DiscoverHistoryScreen> createState() => _DiscoverHistoryScreenState();
}

class _DiscoverHistoryScreenState extends ConsumerState<DiscoverHistoryScreen> {
  /// 選んでいる言葉。null = まだ触っていない(新しい方から [historyDiscoverPreselect] 個)。
  Set<String>? _picked;
  bool _busy = false;
  String? _error;
  HistoryDiscoverOutcome? _outcome;

  Set<String> _selection(List<DiscoverHistoryEntry> history) => _picked ?? {for (final e in history.take(historyDiscoverPreselect)) e.term};

  void _toggle(List<DiscoverHistoryEntry> history, String term, bool on) {
    final next = {..._selection(history)};
    if (on) {
      if (next.length >= historyDiscoverMaxTerms) {
        setState(() => _error = context.l10n.onboardingHistoryTooMany(historyDiscoverMaxTerms));
        return;
      }
      next.add(term);
    } else {
      next.remove(term);
    }
    setState(() {
      _picked = next;
      _error = null;
    });
  }

  Future<void> _search(List<DiscoverHistoryEntry> history) async {
    final discover = ref.read(onboardingDiscoverApiProvider);
    final page = ref.read(rasqAccountPageApiProvider);
    if (discover == null || page == null) {
      setState(() => _error = context.l10n.onboardingDiscoverNoCentral);
      return;
    }
    final picked = _selection(history);
    // 履歴の順(新しい方から)で。
    final terms = [for (final e in history) if (picked.contains(e.term)) e.term];
    if (terms.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _outcome = null;
    });
    final r = await runHistoryDiscover(terms: terms, searchAccounts: (t) => page.searchAccounts(t, limit: 5), searchLists: (q) => discover.lists(q, limit: 12));
    if (mounted) {
      setState(() {
        _busy = false;
        _outcome = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final bold = RasqTypography.bodySmall.copyWith(fontWeight: FontWeight.w700);
    final history = ref.watch(discoverHistoryProvider);
    final picked = _selection(history).where((t) => history.any((e) => e.term == t)).toSet();
    final o = _outcome;
    return Scaffold(
      appBar: RasqPageHeader(title: l10n.onboardingHistoryTitle, showMore: false),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(key: const ValueKey('discover.history.list'), padding: const EdgeInsets.all(RasqSpacing.page), children: [
              Text(l10n.onboardingHistoryIntro, style: caption),
              const SizedBox(height: RasqSpacing.sm),
              if (history.isEmpty)
                Text(l10n.onboardingHistoryEmpty, key: const ValueKey('discover.history.empty'), style: RasqTypography.bodySmall)
              else ...[
                Wrap(spacing: RasqSpacing.xs, runSpacing: RasqSpacing.xs, children: [
                  for (final e in history)
                    InputChip(
                      key: ValueKey('discover.history.term.${e.term}'),
                      avatar: Icon(switch (e.source) { DiscoverHistorySource.people => Icons.person_search, DiscoverHistorySource.content => Icons.image_search, DiscoverHistorySource.page => Icons.crop_free }, size: 14),
                      label: Text(e.term, maxLines: 1, overflow: TextOverflow.ellipsis),
                      selected: picked.contains(e.term),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: _busy ? null : (on) => _toggle(history, e.term, on),
                      onDeleted: _busy ? null : () => unawaited(ref.read(discoverHistoryProvider.notifier).remove(e.term)),
                      deleteButtonTooltipMessage: l10n.onboardingHistoryRemove,
                    ),
                ]),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(key: const ValueKey('discover.history.clear'), onPressed: _busy ? null : () => unawaited(ref.read(discoverHistoryProvider.notifier).clear()), child: Text(l10n.onboardingHistoryClear)),
                ),
                FilledButton.icon(
                  key: const ValueKey('discover.history.search'),
                  onPressed: picked.isEmpty || _busy ? null : () => _search(history),
                  icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.manage_search, size: 18),
                  label: Text(l10n.onboardingHistorySearch(picked.length)),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                ),
              ],
              if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_error!, key: const ValueKey('discover.history.error'), style: caption)),
              if (o != null) ...[
                const SizedBox(height: RasqSpacing.md),
                if (o.isEmpty) Text(l10n.onboardingDiscoverNoResults, key: const ValueKey('discover.history.noResults'), style: caption),
                if (o.accounts.isNotEmpty) ...[
                  Text(l10n.onboardingPageSearchUsersHeading, style: bold),
                  const SizedBox(height: RasqSpacing.xs),
                  for (final a in o.accounts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: RasqSpacing.xs),
                      child: LinkMatchAccountCard(account: LinkMatchAccount(id: a.id, handle: a.handle, displayName: a.displayName, avatarUrl: a.avatarUrl)),
                    ),
                  const SizedBox(height: RasqSpacing.sm),
                ],
                if (o.lists.isNotEmpty) DiscoverResultsView(result: DiscoverResult(lists: o.lists)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
