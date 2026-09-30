import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation.dart';
import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../rai/rai_overlay.dart' show showRai;
import '../rai/rai_providers.dart';
import '../rai/rai_reference.dart' show RaiHit, RaiOperation;
import '../rai/rai_reference_providers.dart';
import 'settings_search.dart';
import 'settings_section_screen.dart' show openSettingsRow;
import 'settings_sections.dart';

/// 設定(ホーム) — 全ての設定 (ワイヤーフレーム P7). SNS plugin sections appear per
/// installed SNS plugin; 第一階層は `settings/:section`.
///
/// 上の検索欄 (D-385): トレンドの検索と同じ角丸の欄([RasqExpandableSearchBox])。入れると一覧の代わりに当たった設定
/// ([searchSettings]、ページの中の項目まで)と、RAi の操作リファレンスの当たり(押すと RAi が手順を案内)を出す。
/// 欄を押すと下に伸び、節のチップで絞れる。
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

/// 検索の欄の key。
const settingsSearchKey = ValueKey('settings.search');

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  bool _toggled = false;
  final Set<String> _sections = {};
  List<RaiHit<RaiOperation>> _ops = const [];
  Timer? _opsTimer;
  int _opsSeq = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
    _query.addListener(_onQuery);
  }

  void _changed() => setState(() {});

  void _onQuery() {
    setState(() {});
    // 操作リファレンスは埋め込みを使うので、打ち終わるのを少し待つ。
    _opsTimer?.cancel();
    final q = _query.text.trim();
    if (q.isEmpty) {
      _ops = const [];
      return;
    }
    _opsTimer = Timer(const Duration(milliseconds: 250), () async {
      final seq = ++_opsSeq;
      try {
        final index = await ref.read(raiReferenceProvider.future);
        final hits = await index.searchOperations(q, k: 3, threshold: 0.5);
        if (mounted && seq == _opsSeq) setState(() => _ops = hits);
      } catch (_) {
        // 引けなければ設定だけ。
      }
    });
  }

  @override
  void dispose() {
    _opsTimer?.cancel();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _searching => _query.text.trim().isNotEmpty || _sections.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RasqPageHeader(title: '全ての設定', onMore: () {}),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.sm, RasqSpacing.xs),
            child: RasqExpandableSearchBox(
              key: settingsSearchKey,
              expanded: _toggled || _focus.hasFocus || _sections.isNotEmpty,
              controller: _query,
              focusNode: _focus,
              hintText: '設定や操作を検索',
              onDropdownTap: () => setState(() => _toggled = !_toggled),
              onReset: _sections.isEmpty ? null : () => setState(_sections.clear),
              genreChips: [
                for (final MapEntry(key: id, value: section) in settingsSections.entries)
                  RasqFilterChipItem(label: section.title, selected: _sections.contains(id), onTap: () => setState(() => _sections.contains(id) ? _sections.remove(id) : _sections.add(id))),
              ],
              barTrailing: _query.text.isEmpty ? null : RasqIconButton(key: const ValueKey('settings.search.clear'), icon: Icons.close, size: 18, tooltip: '消す', onPressed: _query.clear),
            ),
          ),
          Expanded(child: _searching ? _results(context) : _list(context)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context) {
    final index = ref.watch(settingsSearchIndexProvider);
    final q = _query.text;
    return index.when(
      loading: () => const RasqLoading(),
      error: (e, _) => RasqEmptyView(title: '設定を探せませんでした', hint: '$e'),
      data: (entries) {
        final hits = searchSettings(entries, q, sections: _sections);
        if (hits.isEmpty && _ops.isEmpty) return RasqEmptyView(title: '見つかりませんでした', hint: '「$q」に当たる設定はありません。言い方を変えるか、RAi に聞いてみてください');
        return ListView(
          key: const ValueKey('settings.search.results'),
          children: [
            for (final h in hits)
              RasqListTile(
                key: ValueKey('settings.search.hit.${h.entry.path.join('/')}/${h.entry.title}'),
                title: h.entry.title,
                subtitle: h.entry.path.isEmpty ? null : h.entry.path.join(' › '),
                onTap: () {
                  final row = h.entry.row;
                  if (row == null) {
                    context.push(h.entry.route);
                  } else {
                    openSettingsRow(context, ref, row);
                  }
                },
              ),
            if (_ops.isNotEmpty) ...[
              const RasqSectionHeader(title: '操作(RAi が案内します)'),
              for (final o in _ops)
                RasqListTile(
                  key: ValueKey('settings.search.op.${o.item.id}'),
                  title: o.item.title,
                  leading: const Icon(Icons.assistant_navigation, size: 20),
                  onTap: () {
                    _focus.unfocus();
                    showRai(ref, mode: RaiMode.instruction);
                    unawaited(ref.read(raiProvider.notifier).guide(o.item.id));
                  },
                ),
            ],
          ],
        );
      },
    );
  }

  Widget _list(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final manager = ref.watch(overlayManagerProvider);
    final registry = ref.watch(pluginRegistryProvider);
    return ListView(
      children: [
        RasqListTile(title: 'プラグインの構成', onTap: () => context.push('/settings/section/plugins')),
        for (final p in registry.plugins)
          RasqListTile(
            title: p.manifest.name,
            // RASQ Official → brand mark; other store-verified plugins → verified glyph.
            trailing: p.manifest.official
                ? const RasqBrandIcon(size: 18, semanticsLabel: 'RASQ Official')
                : (p.manifest.verified ? const Icon(Icons.verified, color: Color(0xFF1E88E5), size: 18) : null),
            onTap: () => context.push('/settings/section/sns'),
          ),
        RasqListTile(title: 'アプリの外観', onTap: () => context.push('/settings/section/appearance')),
        RasqListTile(title: 'ASTell', onTap: () => context.push('/settings/section/astell')),
        RasqListTile(title: 'リレーショナルタイムライン', onTap: () => context.push('/settings/section/relational')),
        RasqListTile(title: 'トレンド', onTap: () => context.push('/settings/section/trend')),
        RasqListTile(title: 'RAi(アシスタント)', onTap: () => context.push('/settings/section/rai')),
        RasqListTile(title: '通知', onTap: () => context.push('/settings/section/notifications')),
        RasqListTile(title: 'RASQについて', onTap: () => context.push('/settings/section/about')),
        RasqListTile(title: 'ミュート/ブロック', onTap: () => context.pushMuteBlock()),
        // その他の設定 (D-131)。
        const RasqSectionHeader(title: 'その他の設定'),
        RasqListTile(title: '投稿コンポーザー', onTap: () => context.push('/settings/composer')),
        RasqListTile(
          title: 'アカウントの重要設定',
          subtitle: 'パスワードの変更やアカウント削除は web 版で',
          detail: 'パスワードの再設定やアカウント削除など、パスワードがいる処理は web 版で行います',
          trailing: const Icon(Icons.north_east, size: 18),
          chevron: false,
          onTap: () => launchUrl(Uri.https(me.account.instance, '/settings'), mode: LaunchMode.externalApplication),
        ),
        RasqDestructiveListTile(
          title: '@${me.handle}からログアウト',
          onTap: () async {
            final ok = await manager.showAlert(id: 'settings.logout', title: 'ログアウトしますか？', message: 'このアカウントのプラグイン構成はデバイスに残ります。', confirmText: 'ログアウト', cancelText: 'キャンセル', destructive: true);
            final account = ref.read(currentAccountProvider);
            if (ok && account != null) await ref.read(sessionsProvider.notifier).remove(account);
          },
        ),
      ],
    );
  }
}
