import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/learning_api.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_consent.dart';
import '../../shell/headers.dart';
import '../../shell/rasq_account_fow.dart';
import '../../l10n/l10n.dart';
import '../learning/contribution.dart';
import '../learning/relational_cloud.dart';
import '../rai/rai_llm.dart';
import 'settings_dsl.dart';

/// アルゴリズムとコミュニティへの貢献 (D-243 → D-363、旧「学習へのデータ提供」): 状態の確認、同意、撤回、撤回用のコード、
/// 提供する種類(リレーショナルタイムライン / RAi)の切り替え。開発者モードでは集めている件数・書き手の判定・送信の記録も出す。
///
/// 任意で、既定は「提供しない」。RASQ の利用規約への同意とは別の画面にしてある(登録の FOW では聞かない)。
/// 同意の前に要点と説明文書を示し、チェックを入れてからだけ同意できる。撤回はいつでも、受付が閉じていてもできる。
class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key});
  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen> {
  bool _busy = false;
  String? _message;
  String? _code;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCode());
  }

  Future<void> _loadCode() async {
    final code = await ref.read(learningProvider.notifier).savedCode();
    if (mounted) setState(() => _code = code);
  }

  Future<void> _run(Future<String?> Function() body) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final m = await body();
      if (mounted) setState(() => _message = m);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _message = context.l10n.settingsLearningError('$e'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 同意の確認: 要点を読んでチェックを入れたときだけ進める。
  Future<bool> _confirmGrant(LearningStatus s) async {
    final manager = ref.read(overlayManagerProvider);
    final agreed = ValueNotifier(false);
    final ok = await manager.showBottomSheet<bool>(
      id: 'learning.grant',
      title: context.l10n.settingsLearningTitle,
      confirmText: context.l10n.settingsLearningGrantConfirmButton,
      confirmEnabled: agreed,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final l = ctx.l10n;
        Widget point(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('・$t', style: RasqTypography.bodySmall));
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 本人の範囲 (D-370、規約案 02 第 10 項): 自分が書いた公開投稿と、その投稿どうしの関連だけ。
            point(l.settingsLearningGrantPointOptional),
            point(l.settingsLearningGrantPointScope),
            point(l.settingsLearningGrantPointExcluded),
            point(l.settingsLearningGrantPointVerifiedOnly),
            point(l.settingsLearningGrantPointPurpose),
            point(l.settingsLearningGrantPointDeletion),
            if (s.extended)
              RasqNotice.warning(
                key: const ValueKey('learning.extendedNotice'),
                margin: const EdgeInsets.only(bottom: RasqSpacing.sm),
                text: l.settingsLearningGrantExtendedNotice,
                detail: l.settingsLearningGrantExtendedNoticeDetail,
              ),
            RasqCaption(
              '',
              devOnly: true,
              padding: EdgeInsets.zero,
              detail: l.settingsLearningGrantScopeDetail,
            ),
            TextButton(onPressed: () => ref.read(routerProvider).push('/settings/dsl/about.learning'), child: Text(l.settingsLearningGrantReadFullButton)),
            ValueListenableBuilder<bool>(
              valueListenable: agreed,
              builder: (_, v, _) => RasqListTile(
                key: const ValueKey('learning.agree'),
                title: l.settingsLearningGrantAgreeCheckbox,
                chevron: false,
                onTap: () => agreed.value = !v,
                trailing: Checkbox(value: v, onChanged: (x) => agreed.value = x ?? false),
              ),
            ),
            Text(l.settingsLearningDocumentVersion(rasqLearningVersion), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        );
      },
    );
    return ok == true && agreed.value;
  }

  /// 年齢の申告(登録の FOW より前に作ったアカウント向け)。
  Future<void> _declareAge() async {
    final l = context.l10n;
    final manager = ref.read(overlayManagerProvider);
    final age = ValueNotifier<RasqAgeBand?>(null);
    final guardian = ValueNotifier(false);
    final ready = ValueNotifier(false);
    void sync() => ready.value = age.value != null && (!age.value!.needsGuardian || guardian.value);
    age.addListener(sync);
    guardian.addListener(sync);
    final ok = await manager.showBottomSheet<bool>(
      id: 'learning.age',
      title: l.settingsLearningAgeTitle,
      confirmText: l.settingsLearningAgeConfirmButton,
      confirmEnabled: ready,
      builder: (ctx) => ListenableBuilder(
        listenable: Listenable.merge([age, guardian]),
        builder: (_, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          for (final a in RasqAgeBand.values)
            RasqRadioListTile<RasqAgeBand>(key: ValueKey('learning.age.${a.wire}'), title: a.label, value: a, groupValue: age.value, onChanged: (v) => age.value = v),
          if (age.value?.needsGuardian ?? false)
            RasqListTile(
              key: const ValueKey('learning.guardian'),
              title: ctx.l10n.settingsLearningGuardianConsent,
              chevron: false,
              onTap: () => guardian.value = !guardian.value,
              trailing: Checkbox(value: guardian.value, onChanged: (x) => guardian.value = x ?? false),
            ),
        ]),
      ),
    );
    if (ok != true || age.value == null) return;
    await _run(() async {
      final client = ref.read(centralClientProvider)!;
      final api = RasqConsentApi(client);
      await api.put('age', version: rasqTermsVersion, granted: true, detail: age.value!.wire);
      if (age.value!.needsGuardian) await api.put('guardian', version: rasqTermsVersion, granted: true);
      ref.invalidate(learningProvider);
      return l.settingsLearningAgeDeclared;
    });
  }

  Future<void> _withdrawByCode() async {
    final l = context.l10n;
    final manager = ref.read(overlayManagerProvider);
    final input = TextEditingController();
    final ok = await manager.showBottomSheet<bool>(
      id: 'learning.code',
      title: l.settingsLearningCodeSheetTitle,
      confirmText: l.settingsLearningCodeConfirmButton,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(RasqSpacing.page),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(ctx.l10n.settingsLearningCodeSheetBody, style: RasqTypography.bodySmall),
          const SizedBox(height: RasqSpacing.sm),
          RasqInput(key: const ValueKey('learning.code.input'), controller: input, hintText: ctx.l10n.settingsLearningCodeHint),
        ]),
      ),
    );
    if (ok != true || input.text.trim().isEmpty) return;
    await _run(() async {
      await ref.read(learningProvider.notifier).withdrawByCode(input.text);
      return l.settingsLearningWithdrawnByCode;
    });
  }

  String _reasonText(String? r) => switch (r) {
        'age-required' => context.l10n.settingsLearningReasonAgeRequired,
        'under-16' => context.l10n.settingsLearningReasonUnder16,
        'guardian-required' => context.l10n.settingsLearningReasonGuardianRequired,
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final configured = ref.watch(centralConfiguredProvider);
    final account = ref.watch(orgateAccountProvider);
    final noAccount = account.hasValue && account.value == null;
    final state = ref.watch(learningProvider);
    final notifier = ref.read(learningProvider.notifier);
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final l = context.l10n;
    return Scaffold(
      appBar: RasqPageHeader(title: l.settingsLearningTitle),
      body: ListView(children: [
        RasqNotice(
          text: l.settingsLearningIntroNotice,
          detail: l.settingsLearningIntroNoticeDetail,
        ),
        RasqListTile(title: l.settingsLearningReadAboutTitle, subtitle: l.settingsLearningReadAboutSubtitle, onTap: () => context.push('/settings/dsl/about.learning')),
        RasqSectionHeader(title: l.settingsLearningStatusSection),
        if (!configured)
          RasqListTile(title: l.settingsLearningServerNotConfiguredTitle, subtitle: l.settingsLearningServerNotConfiguredSubtitle, onTap: () => context.push('/settings/server'))
        else if (noAccount)
          RasqListTile(key: const ValueKey('learning.needAccount'), title: l.settingsLearningNoAccountTitle, subtitle: l.settingsLearningNoAccountSubtitle, onTap: () => openRasqAccountFow(ref))
        else
          state.when(
            loading: () => const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(l.settingsLearningLoadError('$e'), style: RasqTypography.bodySmall.copyWith(color: RasqColors.danger))),
            data: (s) {
              if (s == null) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                RasqValueListTile(key: const ValueKey('learning.status'), title: l.settingsLearningStatusTitle, value: s.granted ? l.settingsLearningStatusJoined : l.settingsLearningStatusNotJoined),
                if (s.granted && s.since != null) RasqValueListTile(title: l.settingsLearningSinceTitle, value: RasqTimestamp.format(s.since!)),
                RasqValueListTile(title: l.settingsLearningOpenTitle, value: s.open ? l.settingsLearningOpenYes : l.settingsLearningOpenNo),
                RasqValueListTile(title: l.settingsLearningAgeTitle, value: s.ageBand == null ? l.settingsLearningAgeUndeclared : RasqAgeBand.values.firstWhere((a) => a.wire == s.ageBand, orElse: () => RasqAgeBand.adult).label),
                RasqValueListTile(title: l.settingsLearningSentTitle, value: l.settingsLearningSentValue(s.contributions['relational'] ?? 0, s.contributions['rai'] ?? 0)),
                if ((s.contributions['examples'] ?? 0) > 0) RasqValueListTile(key: const ValueKey('learning.examples'), title: l.settingsLearningExamplesTitle, value: l.settingsLearningExamplesValue(s.contributions['examples'] ?? 0, s.contributions['hardNegative'] ?? 0)),
                if (RasqDeveloperMode.of(context)) RasqValueListTile(title: l.settingsLearningPostsLabelsTitle, value: '${s.posts} / ${s.labels}'),
                RasqValueListTile(title: l.settingsLearningModelsTitle, value: s.models.isEmpty ? l.settingsLearningModelsNone : s.models.join(l.settingsLearningModelsSeparator)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
                  child: s.granted
                      ? OutlinedButton(
                          key: const ValueKey('learning.withdraw'),
                          onPressed: _busy
                              ? null
                              : () async {
                                  final ok = await ref.read(overlayManagerProvider).showAlert(
                                        id: 'learning.withdraw',
                                        title: l.settingsLearningWithdrawTitle,
                                        message: l.settingsLearningWithdrawMessage,
                                        confirmText: l.settingsLearningWithdrawConfirm,
                                        cancelText: l.settingsLearningCancel,
                                        destructive: true,
                                      );
                                  if (!ok) return;
                                  await _run(() async {
                                    await notifier.withdraw();
                                    if (mounted) setState(() => _code = null);
                                    return l.settingsLearningWithdrawn;
                                  });
                                },
                          child: Text(l.settingsLearningWithdrawTitle),
                        )
                      : !s.eligible
                          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text(_reasonText(s.reason), key: const ValueKey('learning.reason'), style: RasqTypography.bodySmall),
                              if (s.reason != 'under-16')
                                OutlinedButton(key: const ValueKey('learning.declareAge'), onPressed: _busy ? null : _declareAge, child: Text(l.settingsLearningDeclareAgeButton)),
                            ])
                          : FilledButton(
                              key: const ValueKey('learning.grant'),
                              onPressed: _busy || !s.open
                                  ? null
                                  : () async {
                                      if (!await _confirmGrant(s)) return;
                                      await _run(() async {
                                        final code = await notifier.grant();
                                        if (mounted) setState(() => _code = code);
                                        return l.settingsLearningGranted;
                                      });
                                    },
                              child: Text(s.open ? l.settingsLearningGrantButton : l.settingsLearningGrantClosedButton),
                            ),
                ),
                if (_message != null) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text(_message!, key: const ValueKey('learning.message'), style: RasqTypography.bodySmall)),
                if (s.granted) const _ContributionKinds(),
                if (s.granted && _code != null) ...[
                  RasqSectionHeader(title: l.settingsLearningCodeSection),
                  RasqListTile(
                    key: const ValueKey('learning.code'),
                    title: _code!,
                    subtitle: l.settingsLearningCodeSubtitle,
                    chevron: false,
                    onTap: () {
                      unawaited(Clipboard.setData(ClipboardData(text: _code!)));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.settingsLearningCodeCopied)));
                    },
                  ),
                ] else if (s.granted && s.hasWithdrawCode)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text(l.settingsLearningCodeStoredOnGrantDevice, style: caption)),
              ]);
            },
          ),
        RasqSectionHeader(title: l.settingsLearningOtherSection),
        RasqListTile(key: const ValueKey('learning.byCode'), title: l.settingsLearningByCodeTitle, subtitle: l.settingsLearningByCodeSubtitle, onTap: configured ? _withdrawByCode : null),
        RasqCaption(
          l.settingsLearningDeletionCaption,
          detail: l.settingsLearningDeletionCaptionDetail,
          padding: const EdgeInsets.all(RasqSpacing.page),
        ),
        if (RasqDeveloperMode.of(context)) const _ContributionDebug(),
      ]),
    );
  }
}

/// 送る種類の切り替え (D-363)。
class _ContributionKinds extends ConsumerWidget {
  const _ContributionKinds();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contributionProvider);
    final store = ref.read(settingsAreaProvider(contributionArea).notifier);
    final l = context.l10n;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(title: l.settingsLearningKindsSection),
      RasqSwitchListTile(
        key: const ValueKey('learning.kind.relational'),
        title: l.settingsLearningKindRelationalTitle,
        subtitle: c.extended ? l.settingsLearningKindRelationalSubtitleExtended : l.settingsLearningKindRelationalSubtitle,
        detail: c.extended ? l.settingsLearningKindRelationalDetailExtended : l.settingsLearningKindRelationalDetail,
        value: c.relational,
        onChanged: (v) => store.set('relational', v),
      ),
      if (c.unverified > 0)
        RasqNotice(
          key: const ValueKey('learning.unverified'),
          text: l.settingsLearningUnverifiedNotice,
          action: TextButton(onPressed: () => context.push('/settings/rasq-profile'), child: Text(l.settingsLearningUnverifiedButton)),
        ),
      // 検証用の範囲 (extended、S-049 / S-050) だけの項目。
      if (c.extended) ...[
        RasqSwitchListTile(
          key: const ValueKey('learning.kind.cloudRelational'),
          title: l.settingsLearningKindCloudTitle,
          subtitle: l.settingsLearningKindCloudSubtitle,
          detail: l.settingsLearningKindCloudDetail,
          value: ref.watch(settingsAreaProvider(contributionArea)).value?['cloudRelational'] != false,
          onChanged: (v) => store.set('cloudRelational', v),
        ),
        RasqSwitchListTile(
          key: const ValueKey('learning.kind.rai'),
          title: 'RAi',
          subtitle: l.settingsLearningKindRaiSubtitle,
          detail: l.settingsLearningKindRaiDetail,
          value: c.rai,
          onChanged: (v) => store.set('rai', v),
        ),
        RasqSwitchListTile(
          key: const ValueKey('learning.preload'),
          title: l.settingsLearningPreloadTitle,
          subtitle: l.settingsLearningPreloadSubtitle,
          detail: l.settingsLearningPreloadDetail,
          value: c.preload,
          onChanged: (v) => store.set('preload', v),
        ),
      ],
    ]);
  }
}

/// 開発者モードだけの詳細 (D-363): 集めている件数、書き手の判定、送信の記録、今すぐ送る。
class _ContributionDebug extends ConsumerWidget {
  const _ContributionDebug();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(contributionProvider);
    final llm = ref.watch(raiLlmStatusProvider).value ?? ref.read(raiLlmProvider).current;
    final caption = RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final verdicts = c.verdicts.entries.toList();
    final l = context.l10n;
    return Column(key: const ValueKey('learning.debug'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSectionHeader(title: l.settingsLearningDebugSection),
      RasqValueListTile(title: l.settingsLearningDebugActiveTitle, value: c.active ? l.settingsLearningDebugActiveYes : l.settingsLearningDebugActiveNo),
      RasqValueListTile(key: const ValueKey('learning.debug.scope'), title: l.settingsLearningDebugScopeTitle, value: c.extended ? l.settingsLearningDebugScopeExtended : l.settingsLearningDebugScopeOwn),
      RasqValueListTile(title: l.settingsLearningDebugPendingTitle, value: l.settingsLearningDebugPendingValue('${c.pendingRelational}', '${c.pendingRai}')),
      RasqValueListTile(title: l.settingsLearningDebugSentTitle, value: l.settingsLearningDebugSentValue('${c.sentRelational}', '${c.sentRai}', '${c.skipped}')),
      Builder(builder: (_) {
        final cloud = ref.watch(relationalCloudProvider);
        return RasqValueListTile(
          key: const ValueKey('learning.debug.cloud'),
          title: l.settingsLearningKindCloudTitle,
          value: cloud.active
              ? l.settingsLearningDebugCloudValue('${cloud.decisions.length}', '${cloud.hardNegative}', '${cloud.hardPositive}', '${cloud.agree}', '${cloud.pending}', '${cloud.skipped}')
              : l.settingsLearningDebugCloudOff,
        );
      }),
      RasqValueListTile(title: l.settingsLearningDebugModelTitle, value: '${ref.read(raiLlmProvider).spec.codename} ・ ${llm.phase.name}'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
        child: OutlinedButton(
          key: const ValueKey('learning.flush'),
          onPressed: c.busy || !c.active ? null : () => ref.read(contributionProvider.notifier).flush(),
          child: Text(c.busy ? l.settingsLearningDebugFlushing : l.settingsLearningDebugFlushButton),
        ),
      ),
      if (verdicts.isNotEmpty) ...[
        RasqSectionHeader(title: l.settingsLearningDebugVerdictsSection),
        for (final e in verdicts.take(30))
          RasqListTile(
            title: e.key.replaceAll('|', ' / '),
            subtitle: '${e.value.verdict} ・ ${e.value.judgedBy} ・ ${e.value.reason}',
            chevron: false,
          ),
      ],
      if (c.log.isNotEmpty) ...[
        RasqSectionHeader(title: l.settingsLearningDebugLogSection),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.page),
          child: Text(c.log.join('\n'), key: const ValueKey('learning.log'), style: caption),
        ),
      ],
    ]);
  }
}
