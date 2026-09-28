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
import '../learning/contribution.dart';
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
      if (mounted) setState(() => _message = 'できませんでした — $e');
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
      title: 'アルゴリズムとコミュニティへの貢献',
      confirmText: '同意して参加する',
      confirmEnabled: agreed,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        Widget point(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('・$t', style: RasqTypography.bodySmall));
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.lg),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            point('任意です。断っても RASQ の機能はそのまま使えます。いつでもやめられます'),
            point('タイムラインでまとまった会話(公開の投稿)と、RAi への質問と答えを送ります'),
            point('ほかの人の投稿は、その人が AI の学習を断っていないと判定できたときだけ使います'),
            point('DM、限定公開の投稿、AsTell の会話、画像そのものは送りません'),
            point('リレーショナルタイムラインと RAi の改善に使います'),
            point('データは最大 ${s.retentionYears} 年で消します。やめたときは、送ったデータをすぐに消します'),
            RasqCaption(
              '',
              devOnly: true,
              padding: EdgeInsets.zero,
              detail: '書き手の判定: 端末の規則(自己紹介の「AI学習禁止」「#NoAI」など)と、インストール済みなら端末の 2B モデルで下見し、'
                  'Central(POST /me/learning/judge)がクラウドの LLM で決める(30 日控える)。許可の書き手と自分の投稿だけで束を組み直し、'
                  '2 件未満なら送らない。本文の @メンションと URL は伏せる。RAi は自分のやりとりだけ。学習したモデルは端末へ配布し、元のデータは配布しない。'
                  'すでに配布したモデルは次の更新で作り直す(端末に渡った古いモデルの完全な回収までは約束できない)。',
            ),
            TextButton(onPressed: () => ref.read(routerProvider).push('/settings/dsl/about.learning'), child: const Text('説明の全文を読む')),
            ValueListenableBuilder<bool>(
              valueListenable: agreed,
              builder: (_, v, _) => RasqListTile(
                key: const ValueKey('learning.agree'),
                title: '説明を読み、データの提供に同意します',
                chevron: false,
                onTap: () => agreed.value = !v,
                trailing: Checkbox(value: v, onChanged: (x) => agreed.value = x ?? false),
              ),
            ),
            Text('文書の版: $rasqLearningVersion', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
          ]),
        );
      },
    );
    return ok == true && agreed.value;
  }

  /// 年齢の申告(登録の FOW より前に作ったアカウント向け)。
  Future<void> _declareAge() async {
    final manager = ref.read(overlayManagerProvider);
    final age = ValueNotifier<RasqAgeBand?>(null);
    final guardian = ValueNotifier(false);
    final ready = ValueNotifier(false);
    void sync() => ready.value = age.value != null && (!age.value!.needsGuardian || guardian.value);
    age.addListener(sync);
    guardian.addListener(sync);
    final ok = await manager.showBottomSheet<bool>(
      id: 'learning.age',
      title: '年齢の申告',
      confirmText: '申告する',
      confirmEnabled: ready,
      builder: (ctx) => ListenableBuilder(
        listenable: Listenable.merge([age, guardian]),
        builder: (_, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          for (final a in RasqAgeBand.values)
            RasqRadioListTile<RasqAgeBand>(key: ValueKey('learning.age.${a.wire}'), title: a.label, value: a, groupValue: age.value, onChanged: (v) => age.value = v),
          if (age.value?.needsGuardian ?? false)
            RasqListTile(
              key: const ValueKey('learning.guardian'),
              title: '保護者の同意を得ています',
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
      return '年齢を申告しました';
    });
  }

  Future<void> _withdrawByCode() async {
    final manager = ref.read(overlayManagerProvider);
    final input = TextEditingController();
    final ok = await manager.showBottomSheet<bool>(
      id: 'learning.code',
      title: '撤回用のコードで撤回',
      confirmText: '撤回する',
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(RasqSpacing.page),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('同意したときに発行されたコードを入れます。提供した RASQ アカウントに入れなくなった場合でも撤回できます。', style: RasqTypography.bodySmall),
          const SizedBox(height: RasqSpacing.sm),
          RasqInput(key: const ValueKey('learning.code.input'), controller: input, hintText: '撤回用のコード'),
        ]),
      ),
    );
    if (ok != true || input.text.trim().isEmpty) return;
    await _run(() async {
      await ref.read(learningProvider.notifier).withdrawByCode(input.text);
      return 'やめました。送ったデータは消します';
    });
  }

  String _reasonText(String? r) => switch (r) {
        'age-required' => '年齢の申告が必要です',
        'under-16' => '16 歳以上から参加できます',
        'guardian-required' => '16〜17 歳の人は、保護者の同意が必要です',
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
    return Scaffold(
      appBar: const RasqPageHeader(title: 'アルゴリズムとコミュニティへの貢献'),
      body: ListView(children: [
        const RasqNotice(
          text: 'タイムラインの会話のまとまりと RAi のやりとりを送って、RASQ の改善に協力できます。任意で、いつでもやめられます。',
          detail: 'D-243 / D-363。同意は Central の account_consents(kind = learning)に記録。リレーショナルタイムラインの会話イベントと RAi のやりとりを '
              'POST /me/learning/contributions へ送る。ほかの人の投稿は書き手ごとの判定(POST /me/learning/judge)で許可のときだけ。',
        ),
        RasqListTile(title: '説明を読む', subtitle: '送るもの、使いみち、保存する期間', onTap: () => context.push('/settings/dsl/about.learning')),
        const RasqSectionHeader(title: '状態'),
        if (!configured)
          RasqListTile(title: 'RASQ サーバーの接続先が未設定です', subtitle: '接続先を入れると確認できます', onTap: () => context.push('/settings/server'))
        else if (noAccount)
          RasqListTile(key: const ValueKey('learning.needAccount'), title: 'RASQ アカウントが未作成です', subtitle: 'データの提供は RASQ アカウントごとに記録します', onTap: () => openRasqAccountFow(ref))
        else
          state.when(
            loading: () => const Padding(padding: EdgeInsets.all(RasqSpacing.page), child: RasqLoading()),
            error: (e, _) => Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('取得できませんでした: $e', style: RasqTypography.bodySmall.copyWith(color: RasqColors.danger))),
            data: (s) {
              if (s == null) return const SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                RasqValueListTile(key: const ValueKey('learning.status'), title: '貢献', value: s.granted ? '参加中' : '参加していません'),
                if (s.granted && s.since != null) RasqValueListTile(title: '同意した日', value: RasqTimestamp.format(s.since!)),
                RasqValueListTile(title: '受付', value: s.open ? '受付中' : 'まだ始まっていません'),
                RasqValueListTile(title: '年齢の申告', value: s.ageBand == null ? '未申告' : RasqAgeBand.values.firstWhere((a) => a.wire == s.ageBand, orElse: () => RasqAgeBand.adult).label),
                RasqValueListTile(title: '送ったデータ', value: '会話 ${s.contributions['relational'] ?? 0} 件 ・ RAi ${s.contributions['rai'] ?? 0} 件'),
                if (RasqDeveloperMode.of(context)) RasqValueListTile(title: '投稿 / ラベル', value: '${s.posts} / ${s.labels}'),
                RasqValueListTile(title: 'このデータを使ったモデル', value: s.models.isEmpty ? 'なし' : s.models.join('、')),
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
                                        title: '貢献をやめる',
                                        message: 'データを送るのをすぐに止め、送ったデータも消します。',
                                        confirmText: 'やめる',
                                        cancelText: 'キャンセル',
                                        destructive: true,
                                      );
                                  if (!ok) return;
                                  await _run(() async {
                                    await notifier.withdraw();
                                    if (mounted) setState(() => _code = null);
                                    return '撤回しました';
                                  });
                                },
                          child: const Text('貢献をやめる'),
                        )
                      : !s.eligible
                          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              Text(_reasonText(s.reason), key: const ValueKey('learning.reason'), style: RasqTypography.bodySmall),
                              if (s.reason != 'under-16')
                                OutlinedButton(key: const ValueKey('learning.declareAge'), onPressed: _busy ? null : _declareAge, child: const Text('年齢を申告する')),
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
                                        return '参加しました。下のコードを控えておくと、ログインできなくなってもやめられます';
                                      });
                                    },
                              child: Text(s.open ? '内容を確認して参加する' : '受付はまだ始まっていません'),
                            ),
                ),
                if (_message != null) Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text(_message!, key: const ValueKey('learning.message'), style: RasqTypography.bodySmall)),
                if (s.granted) const _ContributionKinds(),
                if (s.granted && _code != null) ...[
                  const RasqSectionHeader(title: '撤回用のコード'),
                  RasqListTile(
                    key: const ValueKey('learning.code'),
                    title: _code!,
                    subtitle: 'タップでコピー。ログインできなくなっても、このコードでやめられます',
                    chevron: false,
                    onTap: () {
                      unawaited(Clipboard.setData(ClipboardData(text: _code!)));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('撤回用のコードをコピーしました')));
                    },
                  ),
                ] else if (s.granted && s.hasWithdrawCode)
                  Padding(padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page), child: Text('撤回用のコードは、同意した端末に控えてあります。', style: caption)),
              ]);
            },
          ),
        const RasqSectionHeader(title: 'そのほか'),
        RasqListTile(key: const ValueKey('learning.byCode'), title: '撤回用のコードでやめる', subtitle: 'ログインできなくなったとき', onTap: configured ? _withdrawByCode : null),
        RasqCaption(
          'アカウントを削除したときも、送ったデータは消えます。ほかの人が参加しているかは、だれにも調べられません。',
          detail: 'RASQ アカウントを削除したときも、提供の停止と提供済みデータの削除が同時に始まります(learning_contributions は accounts の削除で消える)。'
              'ほかの人がデータを提供しているかどうかは、だれにも調べられません(GET /me/learning は自分の状態だけ)。',
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
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const RasqSectionHeader(title: '送るもの'),
      RasqSwitchListTile(
        key: const ValueKey('learning.kind.relational'),
        title: 'リレーショナルタイムライン',
        subtitle: 'タイムラインでまとまった会話',
        detail: '会話イベント(束)の公開の投稿。書き手ごとに学習してよいかを判定し、許可の書き手と自分の投稿だけを送る。本文の @メンションと URL は伏せる。',
        value: c.relational,
        onChanged: (v) => store.set('relational', v),
      ),
      RasqSwitchListTile(
        key: const ValueKey('learning.kind.rai'),
        title: 'RAi',
        subtitle: 'RAi への質問と答え',
        detail: '質問(@メンションと URL は伏せる)、答え、モード、使った関数の名前、モデルの id。ほかの人の投稿は含めない。',
        value: c.rai,
        onChanged: (v) => store.set('rai', v),
      ),
      RasqSwitchListTile(
        key: const ValueKey('learning.preload'),
        title: '端末のモデルを先に読み込む',
        subtitle: '判定の下見を早くします(ダウンロード済みのときだけ)',
        detail: 'RAi の端末内モデル(既定 Qwen3.5 2B)を起動の少しあとに読み込み、書き手の下見に使う。未ダウンロードならダウンロードはしない(規則だけで下見)。',
        value: c.preload,
        onChanged: (v) => store.set('preload', v),
      ),
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
    return Column(key: const ValueKey('learning.debug'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const RasqSectionHeader(title: '開発者向けの詳細'),
      RasqValueListTile(title: '集めているか', value: c.active ? 'はい' : 'いいえ(同意・受付・見守りを確認)'),
      RasqValueListTile(title: '送信待ち', value: '会話 ${c.pendingRelational} ・ RAi ${c.pendingRai}'),
      RasqValueListTile(title: 'この起動で送った', value: '会話 ${c.sentRelational} ・ RAi ${c.sentRai} ・ 見送り ${c.skipped}'),
      RasqValueListTile(title: '端末のモデル', value: '${ref.read(raiLlmProvider).spec.codename} ・ ${llm.phase.name}'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.xs),
        child: OutlinedButton(
          key: const ValueKey('learning.flush'),
          onPressed: c.busy || !c.active ? null : () => ref.read(contributionProvider.notifier).flush(),
          child: Text(c.busy ? '送信中…' : '今すぐ送る'),
        ),
      ),
      if (verdicts.isNotEmpty) ...[
        const RasqSectionHeader(title: '書き手の判定'),
        for (final e in verdicts.take(30))
          RasqListTile(
            title: e.key.replaceAll('|', ' / '),
            subtitle: '${e.value.verdict} ・ ${e.value.judgedBy} ・ ${e.value.reason}',
            chevron: false,
          ),
      ],
      if (c.log.isNotEmpty) ...[
        const RasqSectionHeader(title: '記録'),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.page),
          child: Text(c.log.join('\n'), key: const ValueKey('learning.log'), style: caption),
        ),
      ],
    ]);
  }
}
