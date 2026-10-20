import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_consent.dart';
import '../../l10n/l10n.dart';
import '../../shell/column_layout.dart';
import '../child_safe/child_safe_providers.dart' show childGateProvider;
import '../login/login_screen.dart' show SnsServiceButton, popOr;
import 'onboarding_feed.dart';
import 'rasq_register_screen.dart';
import 'region/region.dart';
import 'region/region_picker.dart';

/// 初回オンボーディング v2 (D-414)。**ページごとに 1 つ**:
/// ① ユーザー名・パスワード・年齢・住んでいる地域(D-542)([OnboardingAccountStep]。初回は `/onboarding` そのもの、ほかからは `/onboarding/account`)
/// ② 利用規約・プライバシーポリシー・チャイルドセーフ(`/onboarding/terms`、18 歳未満は保護者の同意 / 保護者からのコードの案内。
///    この端末に SNS アカウントがあればバンドルも)→「同意して登録する」で RASQ アカウントを作る(ORGATE の登録 D-398、承諾は一緒に D-371)
/// ③ 既存の SNS アカウントでログイン(`/onboarding/sns`、「SNS サービスを探す」→ 探す画面 `/sns-discover`)
/// RASQ アカウントは最初からあるので、D-413 の「RASQ アカウントを作りますか?」はこの流れでは出さない。
/// D-419: ①② は**オンボーディングの外でも**使う(`/onboarding/account?return=1`、サイドバーの RASQ アカウントの選択の「新規作成」)。
/// そのときは ③ へ進まず、作れたら元の画面へ戻る([OnboardingDraft.standalone])。
/// 幅の広い画面 (≥840dp) は D-405 と同じ 2 カラム: 左の小カラムに公開 RASQ リストの投稿 ([OnboardingFeedColumn])。

/// ① で入れた内容(② へ渡す。パスワードは画面の中だけ、保存しない)。
@immutable
class OnboardingDraft {
  const OnboardingDraft({required this.handle, required this.password, required this.age, this.standalone = false, this.attempt, this.region});
  final String handle;
  final String password;
  final RasqAgeBand age;

  /// 住んでいる地域(D-542 / ORGATE O-018。`JP` / `US-CA`)。作るときに送る。
  final String? region;

  /// オンボーディングの外から(作れたら ② は台帳の行を返して閉じる。ほかの RASQ アカウントに入っていても新しく作る)。
  final bool standalone;

  /// 同じ流れで先に作ったアカウント(ユーザー名をやり直すとき、それで続ける)。
  final RasqCreateAttempt? attempt;
}

/// オンボーディングの枠: 幅の広い画面は左に流れ、右に [child](幅 560px まで)。狭い画面は [child] だけ。
class OnboardingFrame extends ConsumerWidget {
  const OnboardingFrame({super.key, required this.builder});
  final Widget Function(BuildContext context, bool narrow) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < RasqSizes.tabletBreakpoint) return builder(context, true);
            final split = splitColumns(c.maxWidth, ref.watch(columnLayoutProvider));
            return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(width: split.small, child: const OnboardingFeedColumn()),
              const VerticalDivider(width: 1),
              Expanded(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: builder(context, false)))),
            ]);
          }),
        ),
      );
}

/// ページの上: 戻る(あれば)・「n / 3」・見出し・説明。
class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({super.key, required this.step, required this.title, this.description, this.onBack, this.total = 3});
  final int step;

  /// ページの数(オンボーディングの外から作るときは ①② の 2 つ、D-419)。
  final int total;
  final String title;
  final String? description;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.md, RasqSpacing.page, RasqSpacing.sm),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (onBack != null) IconButton(key: const ValueKey('onb.back'), icon: const Icon(Icons.arrow_back_ios_new, size: 18), tooltip: context.l10n.onboardingBack, onPressed: onBack) else const RasqLogo(height: 28),
          const Spacer(),
          Text('$step / $total', key: const ValueKey('onb.stepCount'), style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: RasqSpacing.sm),
        Row(children: [
          for (var i = 1; i <= total; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < total ? 4 : 0),
                decoration: BoxDecoration(color: i <= step ? scheme.primary : scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ]),
        const SizedBox(height: RasqSpacing.md),
        Text(title, style: RasqTypography.title),
        if (description != null) ...[
          const SizedBox(height: RasqSpacing.xs),
          Text(description!, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ]),
    );
  }
}

/// ① ユーザー名・パスワード・年齢。[alternatives] = 下に出すほかの入口(ログイン / スキップなど)。
class OnboardingAccountStep extends ConsumerStatefulWidget {
  const OnboardingAccountStep({super.key, this.alternatives = const [], this.onBack, this.narrow = false, this.standalone = false, this.onCreated});
  final List<Widget> alternatives;
  final VoidCallback? onBack;
  final bool narrow;

  /// オンボーディングの外から作る (D-419): ② で「同意して登録する」を押したら [onCreated](登録はページを閉じてから。③ へは進まない)。
  final bool standalone;
  final ValueChanged<RasqCreateRequest>? onCreated;

  @override
  ConsumerState<OnboardingAccountStep> createState() => _OnboardingAccountStepState();
}

class _OnboardingAccountStepState extends ConsumerState<OnboardingAccountStep> {
  final _handle = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  RasqAgeBand? _age;
  bool _show = false;

  /// 住んでいる地域 (D-542)。提供していない地域は入れない(選べば [RegionUnavailableScreen] を出して、空のまま)。
  String? _region;

  /// ② から戻ってきた理由(ユーザー名が使われていた など)。
  String? _handleRejected;

  /// この流れで先に作ったアカウント(② でユーザー名を断られて戻ってきたとき、作り直さない)。
  final _attempt = RasqCreateAttempt();

  @override
  void dispose() {
    _handle.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _handleError {
    if (_handleRejected != null) return _handleRejected;
    final h = _handle.text;
    if (h.isEmpty) return null;
    if (h.length < 3) return context.l10n.onboardingHandleTooShort;
    if (h.length > 32) return context.l10n.onboardingHandleTooLong;
    if (!rasqHandlePattern.hasMatch(h)) return context.l10n.onboardingHandleInvalid;
    return null;
  }

  bool get _ready =>
      rasqHandlePattern.hasMatch(_handle.text) &&
      _handleRejected == null &&
      _password.text.isNotEmpty &&
      rasqPasswordProblem(_password.text) == null &&
      _confirm.text == _password.text &&
      _age != null &&
      _region != null;

  Future<void> _pickRegion() async {
    final code = await pickRegion(context);
    if (code == null || !mounted) return;
    final regions = ref.read(rasqRegionsProvider).value;
    if (regions != null && !regions.isAvailable(code)) {
      // 提供していない地域 (D-542): 作成へは進めない。戻れば ① のまま(地域は空)。
      setState(() => _region = null);
      await showRegionUnavailable(Navigator.of(context), code);
      return;
    }
    setState(() => _region = code);
  }

  Future<void> _next() async {
    final draft = OnboardingDraft(handle: _handle.text, password: _password.text, age: _age!, standalone: widget.standalone, attempt: _attempt, region: _region);
    final result = await context.push<Object>(Routes.onboardingTerms, extra: draft);
    if (!mounted) return;
    // 文字列 = ユーザー名を断られた(① でやり直す)。[RasqCreateRequest] = オンボーディングの外から (D-419): 閉じてから登録する。
    if (result is String) setState(() => _handleRejected = result);
    // 作るときにサーバーが地域を断った (D-542): 進めない画面は ② で出した。地域を空に戻す。
    if (result is RasqRegionNotServed) setState(() => _region = null);
    if (result is RasqCreateRequest) widget.onCreated?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final centralOk = ref.watch(centralConfiguredProvider);
    // 選べる地域を先に読んでおく(選ぶ画面と、提供していない地域の判定に使う。D-542)。
    ref.watch(rasqRegionsProvider);
    final region = _region;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      OnboardingStepHeader(
        step: 1,
        total: widget.standalone ? 2 : 3,
        title: widget.standalone ? context.l10n.onboardingAccountTitleNew : context.l10n.onboardingAccountTitle,
        description: context.l10n.onboardingAccountDescription,
        onBack: widget.onBack,
      ),
      Expanded(
        child: SingleChildScrollView(
          key: const ValueKey('onb.account.list'),
          padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              key: const ValueKey('onb.handle'),
              controller: _handle,
              autofillHints: const [AutofillHints.newUsername],
              inputFormatters: [
                TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toLowerCase())),
                LengthLimitingTextInputFormatter(32),
              ],
              onChanged: (_) => setState(() => _handleRejected = null),
              decoration: InputDecoration(labelText: context.l10n.onboardingHandleLabel, prefixText: '@', errorText: _handleError, helperText: context.l10n.onboardingHandleHelper),
            ),
            const SizedBox(height: RasqSpacing.sm),
            TextField(
              key: const ValueKey('onb.password'),
              controller: _password,
              obscureText: !_show,
              autofillHints: const [AutofillHints.newPassword],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: context.l10n.onboardingPasswordLabel(rasqPasswordMinChars),
                errorText: rasqPasswordProblem(_password.text),
                suffixIcon: IconButton(icon: Icon(_show ? Icons.visibility_off : Icons.visibility), tooltip: _show ? context.l10n.onboardingPasswordHide : context.l10n.onboardingPasswordShow, onPressed: () => setState(() => _show = !_show)),
              ),
            ),
            TextField(
              key: const ValueKey('onb.passwordConfirm'),
              controller: _confirm,
              obscureText: !_show,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.l10n.onboardingPasswordConfirmLabel, errorText: _confirm.text.isNotEmpty && _confirm.text != _password.text ? context.l10n.onboardingPasswordMismatch : null),
            ),
            const SizedBox(height: RasqSpacing.xs),
            Text(context.l10n.onboardingPasswordCaption, style: caption),
            RasqSectionHeader(title: context.l10n.onboardingAgeHeading, topMargin: RasqSpacing.md),
            Text(context.l10n.onboardingAgeCaption, style: caption),
            for (final a in RasqAgeBand.values)
              RasqRadioListTile<RasqAgeBand>(key: ValueKey('onb.age.${a.wire}'), title: a.label, value: a, groupValue: _age, onChanged: (v) => setState(() => _age = v)),
            RasqSectionHeader(title: context.l10n.regionHeading, topMargin: RasqSpacing.md),
            Text(context.l10n.regionCaption, style: caption),
            ListTile(
              key: const ValueKey('onb.region'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: Text(region == null ? context.l10n.regionChoose : regionName(region)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickRegion,
            ),
            const SizedBox(height: RasqSpacing.md),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          if (!centralOk)
            Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(context.l10n.onboardingNoCentral, style: caption),
              TextButton(onPressed: () => context.push('${Routes.settings}/server'), child: Text(context.l10n.onboardingSetCentral)),
            ]),
          FilledButton(
            key: const ValueKey('onb.next'),
            onPressed: _ready && centralOk ? _next : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: Text(context.l10n.onboardingNext),
          ),
          ...widget.alternatives,
        ]),
      ),
    ]);
  }
}

/// `/onboarding/account`: ①だけのページ(ログアウトしたあとの「新しく RASQ アカウントを作成」から)。
/// `?return=1`([standalone]、D-419): オンボーディングの外から(サイドバーの RASQ アカウントの選択の「新規作成」など)。
/// ② で「同意して登録する」を押したら、選んだ内容 ([RasqCreateRequest]) を返して元の画面へ戻る(登録は戻ってから、
/// [openRasqAccountCreation])。開いている間は下の FOW を退避する(② と同じ)。
class OnboardingAccountScreen extends ConsumerStatefulWidget {
  const OnboardingAccountScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  ConsumerState<OnboardingAccountScreen> createState() => _OnboardingAccountScreenState();
}

class _OnboardingAccountScreenState extends ConsumerState<OnboardingAccountScreen> {
  late final OverlayManager _overlay = ref.read(overlayManagerProvider);

  @override
  void initState() {
    super.initState();
    if (widget.standalone) _overlay.setFowSuspend(_suspendAll);
  }

  @override
  void dispose() {
    if (widget.standalone) _overlay.setFowSuspend(null);
    super.dispose();
  }

  static bool _suspendAll(RasqOverlayEntry _) => true;

  @override
  Widget build(BuildContext context) => OnboardingFrame(
        builder: (context, narrow) => OnboardingAccountStep(
          narrow: narrow,
          standalone: widget.standalone,
          onBack: () => context.pop(),
          onCreated: widget.standalone ? (rec) => context.pop(rec) : null,
        ),
      );
}

/// ② 利用規約・プライバシーポリシー・チャイルドセーフ → 登録。
class OnboardingTermsScreen extends ConsumerStatefulWidget {
  const OnboardingTermsScreen({super.key, required this.draft});

  /// null = ① を通らずに開いた(戻ってもらう)。
  final OnboardingDraft? draft;

  @override
  ConsumerState<OnboardingTermsScreen> createState() => _OnboardingTermsScreenState();
}

class _OnboardingTermsScreenState extends ConsumerState<OnboardingTermsScreen> {
  late final OverlayManager _overlay = ref.read(overlayManagerProvider);
  bool _agree = false;
  bool _guardian = false;
  bool _replace = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 登録のページ (D-405) と同じ: 開いている間は下の FOW を退避する。
    _overlay.setFowSuspend(_suspendAll);
  }

  @override
  void dispose() {
    // オンボーディングの外から (D-419): 下の ① も FOW を退避しているので、戻しはそちらに任せる。
    if (!(widget.draft?.standalone ?? false)) _overlay.setFowSuspend(null);
    super.dispose();
  }

  static bool _suspendAll(RasqOverlayEntry _) => true;

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  /// バンドルを聞く SNS アカウントの数。オンボーディングの外から作るとき (D-419)、いまのアカウントが Central のものなら
  /// 聞かない(0)・持ち込まない(そのアカウントの SNS を、新しいアカウントへ写さない。D-409 と同じ考え)。
  int get _snsCount => _keepsCurrentBundle ? 0 : ref.read(sessionsProvider).value?.sessions.length ?? 0;

  bool get _keepsCurrentBundle => (widget.draft?.standalone ?? false) && (ref.read(currentRasqAccountProvider)?.isCentral ?? false);

  bool get _ready {
    final d = widget.draft;
    return d != null && _agree && (!d.age.needsGuardian || _guardian) && !_busy;
  }

  Future<void> _submit() async {
    final d = widget.draft!;
    setState(() => _busy = true);
    try {
      final choice = RasqRegisterChoice(age: d.age, replaceBundle: _keepsCurrentBundle ? false : (_snsCount > 0 ? _replace : true), password: d.password, region: d.region);
      // オンボーディングの外から (D-419): ここでは送らず、選んだ内容を ① へ返す(① も閉じ、元の画面へ戻ってから登録する)。
      if (d.standalone) return context.pop(RasqCreateRequest(handle: d.handle, choice: choice));
      final rec = await completeRasqRegistration(ref.read, choice, handle: d.handle, attempt: d.attempt, onMessage: _toast);
      if (rec == null || !mounted) return;
      await ref.read(rasqAccountsProvider.notifier).completeOnboarding();
      if (mounted) context.go(Routes.onboardingSns);
    } on RasqHandleRejected catch (e) {
      // アカウントはできている。ユーザー名を変えて、もう一度(① へ戻る)。
      if (mounted) context.pop(e.message);
    } on RasqRegionNotServed catch (e) {
      // 提供していない地域 (D-542 / ORGATE O-018)。アカウントは作られていない。進めない画面を出し、戻ったら ① へ(地域は空に)。
      if (!mounted) return;
      await showRegionUnavailable(Navigator.of(context), e.region);
      if (mounted) context.pop(e);
    } on OrgateException catch (e) {
      if (mounted) _toast(context.l10n.onboardingCreateFailed(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final d = widget.draft;
    final minor = d?.age.needsGuardian ?? false;
    final snsCount = _snsCount;
    Widget check(Key key, String title, bool value, ValueChanged<bool> onChanged, {String? subtitle}) => RasqListTile(
          key: key,
          title: title,
          subtitle: subtitle,
          chevron: false,
          onTap: () => onChanged(!value),
          trailing: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
        );
    return OnboardingFrame(
      builder: (context, narrow) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OnboardingStepHeader(step: 2, total: (d?.standalone ?? false) ? 2 : 3, title: context.l10n.onboardingTermsTitle, onBack: _busy ? null : () => context.pop()),
        if (d == null)
          Expanded(child: Center(child: Text(context.l10n.onboardingTermsNoDraft, style: caption)))
        else
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('onb.terms.list'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                RasqListTile(key: const ValueKey('onb.terms.read'), title: context.l10n.onboardingTermsRead, onTap: () => context.push(Routes.termsDoc)),
                RasqListTile(key: const ValueKey('onb.privacy.read'), title: context.l10n.onboardingPrivacyRead, onTap: () => context.push(Routes.privacyDoc)),
                check(const ValueKey('onb.agree'), context.l10n.onboardingAgree, _agree, (v) => setState(() => _agree = v)),
                // チャイルドセーフ (D-241 / D-307): 18 歳未満は保護者の同意。保護者が子のアカウントを作ったなら、ここで作らずにコードで入る。
                if (minor) ...[
                  RasqSectionHeader(title: context.l10n.onboardingChildSafeHeading),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                    child: Text(
                      context.l10n.onboardingChildSafeNote(d.age.label),
                      key: const ValueKey('onb.childSafe.note'),
                      style: caption,
                    ),
                  ),
                  check(const ValueKey('onb.guardian'), context.l10n.onboardingGuardianConsent, _guardian, (v) => setState(() => _guardian = v)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                    child: OutlinedButton.icon(
                      key: const ValueKey('onb.childLogin'),
                      onPressed: () => context.push(Routes.childSafeLogin),
                      icon: const Icon(Icons.family_restroom, size: 18),
                      label: Text(context.l10n.onboardingChildLogin),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, 0),
                    child: Text(context.l10n.onboardingChildLoginCaption, style: caption),
                  ),
                ],
                if (snsCount > 0) ...[
                  RasqSectionHeader(title: context.l10n.onboardingBundleHeading),
                  RasqRadioListTile<bool>(
                    key: const ValueKey('onb.bundle.replace'),
                    title: context.l10n.onboardingBundleReplace,
                    subtitle: context.l10n.onboardingBundleReplaceSubtitle(snsCount),
                    value: true,
                    groupValue: _replace,
                    onChanged: (v) => setState(() => _replace = v),
                  ),
                  RasqRadioListTile<bool>(
                    key: const ValueKey('onb.bundle.keep'),
                    title: context.l10n.onboardingBundleKeep,
                    subtitle: context.l10n.onboardingBundleKeepSubtitle,
                    value: false,
                    groupValue: _replace,
                    onChanged: (v) => setState(() => _replace = v),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.sm),
                  child: Text(context.l10n.onboardingTermsContributionNote, style: caption),
                ),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.md),
          child: FilledButton(
            key: const ValueKey('onb.register'),
            onPressed: _ready ? _submit : null,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
            child: _busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(context.l10n.onboardingRegister),
          ),
        ),
      ]),
    );
  }
}

/// ③ 既存の SNS アカウントでログイン。「SNS サービスを探す」→ 探す画面。
class OnboardingSnsScreen extends ConsumerWidget {
  const OnboardingSnsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final canAdd = ref.watch(childGateProvider).canAddAccounts;
    return OnboardingFrame(
      builder: (context, narrow) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        OnboardingStepHeader(
          step: 3,
          // 戻る (D-422): ③ は ② の登録のあと `go` で来るので、戻る先が無ければ RASQ アカウントの入口へ(作ったアカウントは台帳に
          // 残り、「〜で続ける」で戻れる。別のアカウントでログイン / 新しく作る、もそこから)。
          onBack: () => popOr(context, Routes.onboarding),
          title: context.l10n.onboardingSnsTitle,
          description: context.l10n.onboardingSnsDescription,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (!canAdd)
                Padding(
                  padding: const EdgeInsets.only(bottom: RasqSpacing.sm),
                  child: Text(context.l10n.onboardingDiscoverAddAccountBlocked, key: const ValueKey('onb.sns.blocked'), style: RasqTypography.bodySmall.copyWith(color: scheme.error)),
                ),
              SnsServiceButton(kind: SnsKind.bluesky, label: context.l10n.onboardingSnsLoginWith('Bluesky'), onTap: () => context.push(Routes.loginBluesky)),
              SnsServiceButton(kind: SnsKind.misskey, label: context.l10n.onboardingSnsLoginWith('Misskey'), onTap: () => context.push(Routes.loginMisskey)),
              SnsServiceButton(kind: SnsKind.mixi2, label: context.l10n.onboardingSnsLoginWith('mixi2'), external: true, onTap: () => context.push(Routes.loginMixi2)),
              SnsServiceButton(kind: SnsKind.mastodon, label: context.l10n.onboardingSnsLoginWith('Mastodon'), onTap: () => context.push(Routes.loginMastodon)),
              Text(context.l10n.onboardingSnsPluginLoadNote, style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.md),
          child: FilledButton.icon(
            key: const ValueKey('onb.discover'),
            onPressed: () => context.push(Routes.snsDiscover),
            icon: const Icon(Icons.travel_explore, size: 18),
            label: Text(context.l10n.onboardingDiscoverTitle),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          ),
        ),
      ]),
    );
  }
}
