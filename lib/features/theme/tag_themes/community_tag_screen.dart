import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../../app/providers.dart';
import '../../../backend/orgate_client.dart';
import '../../../l10n/l10n.dart';
import '../../../shell/headers.dart';
import '../icon_theme/icon_theme_codec.dart';
import '../icon_theme/rasq_theme_spec.dart';
import '../icon_theme/theme_frames.dart';
import 'atmos.dart';
import 'tag_themes.dart';

/// コミュハッシュタグのテーマの申請 (D-583、既定は無効)。
///
/// 条件は ① **サブスクに入っている**(サーバーが支払いで確かめる)② **自分のコミュニティのタグを宣伝した投稿**(自分の公開の投稿で、
/// そのタグを含むもの)を添える。アプリは申請と状態の表示まで。審査・サブスクの確認・配信はサーバー(docs/TAG_THEMES.md)。
/// 通ったテーマは、そのタグのページ(トレンドのタグの TL)を開いた人に、そのページの表示だけで出る。

/// 自分の状態(機能が無効 / Central が無ければ null)。
final communityTagStatusProvider = FutureProvider.autoDispose<CommunityTagStatus?>((ref) async {
  final api = ref.watch(tagThemesApiProvider);
  if (api == null) return null;
  return api.mine();
});

/// 宣伝の投稿の候補: いまの SNS アカウントの最近の投稿のうち、公開で [tag] を含むもの。テストで差し替える。
final communityTagPromoFinderProvider = Provider<Future<List<Post>> Function(String tag)>((ref) => (tag) async {
      final session = ref.read(currentSnsSessionProvider);
      final me = ref.read(currentUserProvider);
      if (session == null || me.id.isEmpty) return const [];
      final page = await session.userPosts(me.id, limit: 40);
      final t = normalizeHashtag(tag);
      return [
        for (final p in page.items)
          if ((p.visibility == null || p.visibility == 'public') && p.repostedBy == null && postHashtags(p).contains(t)) p,
      ];
    });

/// 申請の画面で選べるテーマの見本(色と枠を選ぶだけ。細かい形はアイコンのテーマ編集 D-581 と同じデータを JSON で送る)。
class CommunityTagPreset {
  const CommunityTagPreset(this.id, this.basic, this.frames);
  final String id;
  final IconThemeBasic basic;
  final List<RasqThemeFrameRef> frames;

  String label(AppLocalizations l) => switch (id) {
        'night' => l.communityTagPresetNight,
        'sakura' => l.communityTagPresetSakura,
        'sea' => l.communityTagPresetSea,
        _ => l.communityTagPresetRing,
      };
}

const communityTagPresets = [
  CommunityTagPreset('night', IconThemeBasic(bgMode: IconThemeBg.gradient, gradient: 2, bg: [17, 34, 68], text: [255, 255, 255], accent: [0, 204, 255], particle: 3, amount: 8, speed: 4), [
    RasqThemeFrameRef(svgId: 'star', x: 0.86, y: 0.2, size: 0.3, opacity: 0.5),
    RasqThemeFrameRef(svgId: 'sparkle', x: 0.12, y: 0.75, size: 0.25, opacity: 0.4),
  ]),
  CommunityTagPreset('sakura', IconThemeBasic(bgMode: IconThemeBg.gradient, gradient: 1, bg: [255, 204, 221], text: [68, 17, 34], accent: [221, 68, 119], particle: 2, amount: 7, speed: 3), [
    RasqThemeFrameRef(svgId: 'sakura', x: 0.88, y: 0.2, size: 0.35, opacity: 0.5, rotation: 18),
  ]),
  CommunityTagPreset('sea', IconThemeBasic(bgMode: IconThemeBg.gradient, gradient: 0, bg: [0, 85, 136], text: [255, 255, 255], accent: [102, 221, 255], particle: 5, amount: 6, speed: 3), [
    RasqThemeFrameRef(svgId: 'wave', x: 0.5, y: 0.92, size: 0.9, opacity: 0.35),
  ]),
  CommunityTagPreset('ring', IconThemeBasic(bgMode: IconThemeBg.solid, bg: [34, 34, 34], text: [255, 255, 255], accent: [255, 170, 0], particle: 0), [
    RasqThemeFrameRef(svgId: 'ring', x: 0.15, y: 0.3, size: 0.4, opacity: 0.3),
  ]),
];

/// 強調色の見本。
const communityTagAccents = <List<int>>[
  [0, 204, 255],
  [221, 68, 119],
  [255, 170, 0],
  [102, 204, 102],
  [153, 102, 255],
  [255, 255, 255],
];

String _stateLabel(AppLocalizations l, CommunityTagState s) => switch (s) {
      CommunityTagState.pending => l.communityTagStatePending,
      CommunityTagState.approved => l.communityTagStateApproved,
      CommunityTagState.rejected => l.communityTagStateRejected,
      CommunityTagState.suspended => l.communityTagStateSuspended,
      CommunityTagState.withdrawn => l.communityTagStateWithdrawn,
    };

/// サーバーの理由の名前 → 表示の文。知らない名前は null(理由を出さない)。
String? communityTagReasonText(AppLocalizations l, String? reason) => switch (reason) {
      'promo_missing' => l.communityTagReasonPromoMissing,
      'tag_taken' => l.communityTagReasonTagTaken,
      'subscription_inactive' => l.communityTagReasonSubscription,
      'theme_rejected' => l.communityTagReasonTheme,
      'policy' => l.communityTagReasonPolicy,
      _ => null,
    };

/// 状態と申請の一覧(`/settings/community-tags`)。
class CommunityTagScreen extends ConsumerWidget {
  const CommunityTagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final status = ref.watch(communityTagStatusProvider);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Scaffold(
      key: const ValueKey('communityTag.screen'),
      appBar: RasqPageHeader(title: l.communityTagTitle),
      body: status.when(
        loading: () => const RasqLoading(),
        error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(e is OrgateException ? e.message : l.communityTagLoadFailed, textAlign: TextAlign.center))),
        data: (s) => s == null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(l.communityTagUnavailable, textAlign: TextAlign.center)))
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(communityTagStatusProvider),
                child: ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xl), children: [
                  Text(l.communityTagIntro, style: RasqTypography.bodySmall.copyWith(color: muted)),
                  const SizedBox(height: RasqSpacing.md),
                  Text(l.communityTagRequirements, style: RasqTypography.title),
                  ListTile(
                    key: const ValueKey('communityTag.req.subscription'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(s.subscribed ? Icons.check_circle : Icons.radio_button_unchecked, color: s.subscribed ? Colors.green : muted),
                    title: Text(l.communityTagReqSubscription),
                    subtitle: Text(s.subscribed ? (s.plan == null ? l.communityTagSubscribed : l.communityTagSubscribedPlan(s.plan!)) : l.communityTagNotSubscribed),
                    trailing: s.subscribed ? null : TextButton(onPressed: () => context.push('/settings/dsl/about.subscription'), child: Text(l.communityTagSeeSubscription)),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.campaign_outlined, color: muted),
                    title: Text(l.communityTagReqPromo),
                    subtitle: Text(l.communityTagReqPromoHint),
                  ),
                  const Divider(),
                  Text(l.communityTagMine, style: RasqTypography.title),
                  if (s.applications.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: RasqSpacing.sm), child: Text(l.communityTagNone, style: RasqTypography.bodySmall.copyWith(color: muted))),
                  for (final a in s.applications) _ApplicationTile(app: a),
                  const SizedBox(height: RasqSpacing.md),
                  FilledButton.icon(
                    key: const ValueKey('communityTag.apply'),
                    icon: const Icon(Icons.add),
                    label: Text(l.communityTagApply),
                    onPressed: s.canApply
                        ? () async {
                            final done = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CommunityTagApplyScreen()));
                            if (done == true) ref.invalidate(communityTagStatusProvider);
                          }
                        : null,
                  ),
                  if (!s.canApply)
                    Padding(
                      padding: const EdgeInsets.only(top: RasqSpacing.xs),
                      child: Text(s.subscribed ? l.communityTagLimitReached(s.limit) : l.communityTagNeedSubscription, key: const ValueKey('communityTag.applyBlocked'), style: RasqTypography.caption.copyWith(color: muted)),
                    ),
                ]),
              ),
      ),
    );
  }
}

class _ApplicationTile extends ConsumerWidget {
  const _ApplicationTile({required this.app});
  final CommunityTagApplication app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final reason = communityTagReasonText(l, app.reason);
    final spec = app.spec;
    return Card(
      key: ValueKey('communityTag.app.${app.id}'),
      margin: const EdgeInsets.symmetric(vertical: RasqSpacing.xs),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (spec != null)
          TagThemeBanner(entry: TagThemeEntry(id: app.id, kind: TagThemeKind.community, tag: app.tag, spec: spec), caption: _stateLabel(l, app.state), height: 56),
        ListTile(
          title: Text('#${app.tag}'),
          subtitle: Text([_stateLabel(l, app.state), ?reason].join(' · '), key: ValueKey('communityTag.app.${app.id}.state')),
          trailing: app.open
              ? TextButton(
                  key: ValueKey('communityTag.app.${app.id}.withdraw'),
                  onPressed: () => _withdraw(context, ref),
                  child: Text(l.communityTagWithdraw),
                )
              : null,
        ),
      ]),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await ref.read(overlayManagerProvider).showAlert(
          id: 'communityTag.withdraw.confirm',
          title: l.communityTagWithdrawConfirmTitle(app.tag),
          message: l.communityTagWithdrawConfirmMessage,
          confirmText: l.communityTagWithdraw,
          cancelText: l.communityTagCancel,
          destructive: true,
        );
    if (!ok) return;
    try {
      await ref.read(tagThemesApiProvider)?.withdraw(app.id);
      ref.invalidate(communityTagStatusProvider);
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text(e is OrgateException ? e.message : l.communityTagSendFailed)));
    }
  }
}

/// 申請の画面: タグ → テーマ(見本・強調色・プレビュー)→ 宣伝の投稿 → 申請する。
class CommunityTagApplyScreen extends ConsumerStatefulWidget {
  const CommunityTagApplyScreen({super.key});

  @override
  ConsumerState<CommunityTagApplyScreen> createState() => _CommunityTagApplyScreenState();
}

class _CommunityTagApplyScreenState extends ConsumerState<CommunityTagApplyScreen> {
  final _tag = TextEditingController();
  CommunityTagPreset _preset = communityTagPresets.first;
  List<int>? _accent;
  List<Post>? _candidates;
  bool _searching = false;
  Post? _promo;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _tag.dispose();
    super.dispose();
  }

  String get _tagValue => normalizeHashtag(_tag.text);

  RasqThemeSpec get _spec {
    final b = _preset.basic;
    final basic = _accent == null ? b : IconThemeBasic(bgMode: b.bgMode, gradient: b.gradient, bg: b.bg, text: b.text, accent: _accent!, particle: b.particle, amount: b.amount, speed: b.speed, hint: b.hint);
    return RasqThemeSpec(basic: basic, frames: _preset.frames, source: RasqThemeSource.communityTag, scope: RasqThemeScope.hashtag(_tagValue.isEmpty ? 'tag' : _tagValue));
  }

  Future<void> _search() async {
    if (!isValidHashtag(_tag.text)) return;
    setState(() {
      _searching = true;
      _promo = null;
    });
    List<Post> found;
    try {
      found = await ref.read(communityTagPromoFinderProvider)(_tagValue);
    } catch (_) {
      found = const [];
    }
    if (!mounted) return;
    setState(() {
      _searching = false;
      _candidates = found;
      _promo = found.length == 1 ? found.first : null;
    });
  }

  Future<void> _submit() async {
    final api = ref.read(tagThemesApiProvider);
    final promo = _promo;
    if (api == null || promo == null) return;
    final l = context.l10n;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await api.apply(tag: _tagValue, spec: _spec, promo: CommunityTagPromo.of(promo));
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l.communityTagSent)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e is OrgateException ? (communityTagReasonText(l, e.serverCode) ?? e.message) : l.communityTagSendFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final tagOk = isValidHashtag(_tag.text);
    final candidates = _candidates;
    final preview = TagThemeEntry(id: 'preview', kind: TagThemeKind.community, tag: tagOk ? _tagValue : '…', spec: _spec);
    return Scaffold(
      key: const ValueKey('communityTag.applyScreen'),
      appBar: RasqPageHeader(title: l.communityTagApplyTitle),
      body: ListView(padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xl), children: [
        // 1. タグ
        Text(l.communityTagStepTag, style: RasqTypography.title),
        TextField(
          key: const ValueKey('communityTag.tag'),
          controller: _tag,
          decoration: InputDecoration(prefixText: '#', hintText: l.communityTagTagHint, errorText: _tag.text.isNotEmpty && !tagOk ? l.communityTagTagInvalid : null),
          onChanged: (_) => setState(() {
            _candidates = null;
            _promo = null;
          }),
        ),
        const SizedBox(height: RasqSpacing.lg),
        // 2. テーマ
        Text(l.communityTagStepTheme, style: RasqTypography.title),
        const SizedBox(height: RasqSpacing.xs),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in communityTagPresets)
            ChoiceChip(key: ValueKey('communityTag.preset.${p.id}'), label: Text(p.label(l)), selected: p == _preset, onSelected: (_) => setState(() => _preset = p)),
        ]),
        const SizedBox(height: RasqSpacing.sm),
        Row(children: [
          Text(l.communityTagAccent, style: RasqTypography.bodySmall),
          const SizedBox(width: RasqSpacing.sm),
          for (final (i, c) in communityTagAccents.indexed)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                key: ValueKey('communityTag.accent.$i'),
                customBorder: const CircleBorder(),
                onTap: () => setState(() => _accent = c),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: Color.fromARGB(255, c[0], c[1], c[2]), shape: BoxShape.circle, border: Border.all(color: muted, width: _spec.basic.accent == c ? 3 : 1)),
                ),
              ),
            ),
        ]),
        const SizedBox(height: RasqSpacing.sm),
        Text(l.communityTagPreview, style: RasqTypography.caption.copyWith(color: muted)),
        const SizedBox(height: RasqSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            key: const ValueKey('communityTag.preview'),
            height: 180,
            child: TagThemeSurface(
              spec: _spec,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TagThemeBanner(entry: preview, caption: l.communityTagPageCaption),
                Padding(padding: const EdgeInsets.all(12), child: Text(l.communityTagPreviewBody, style: RasqTypography.bodySmall)),
              ]),
            ),
          ),
        ),
        Text(l.communityTagThemeNote(themeFramesMax), style: RasqTypography.caption.copyWith(color: muted)),
        const SizedBox(height: RasqSpacing.lg),
        // 3. 宣伝の投稿
        Text(l.communityTagStepPromo, style: RasqTypography.title),
        Text(l.communityTagReqPromoHint, style: RasqTypography.caption.copyWith(color: muted)),
        const SizedBox(height: RasqSpacing.xs),
        OutlinedButton.icon(
          key: const ValueKey('communityTag.findPromo'),
          icon: _searching ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
          label: Text(l.communityTagFindPromo),
          onPressed: tagOk && !_searching ? _search : null,
        ),
        if (candidates != null && candidates.isEmpty)
          Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(l.communityTagNoPromo(_tagValue), key: const ValueKey('communityTag.noPromo'), style: RasqTypography.bodySmall.copyWith(color: muted))),
        if (candidates != null)
          RadioGroup<String>(
            groupValue: _promo?.key,
            onChanged: (k) => setState(() => _promo = candidates.where((p) => p.key == k).firstOrNull),
            child: Column(children: [
              for (final p in candidates)
                RadioListTile<String>(
                  key: ValueKey('communityTag.promo.${p.id}'),
                  contentPadding: EdgeInsets.zero,
                  value: p.key,
                  title: Text(p.body.replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(RasqDateFormat.yearMonthDay(p.createdAt.toLocal())),
                ),
            ]),
          ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.sm), child: Text(_error!, key: const ValueKey('communityTag.error'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
          child: FilledButton(
            key: const ValueKey('communityTag.submit'),
            onPressed: tagOk && _promo != null && !_sending ? _submit : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: Text(l.communityTagSubmit),
          ),
        ),
      ),
    );
  }
}
