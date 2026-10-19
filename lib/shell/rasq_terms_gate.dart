import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../app/providers.dart';
import '../app/router.dart';
import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart';
import '../backend/rasq_consent.dart';
import '../features/plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../l10n/l10n.dart';

/// 同意待ちの RASQ アカウント (D-371 / Central S-053、規約案 06 CONS-02)。
///
/// いまの版の利用規約・プライバシーポリシーを承諾していない(登録のときに承諾を残せなかった / 版が上がった / 以前の登録)
/// アカウントは、承諾するまで AsTell・購入・預託・学習への提供を使えない(サーバーが `403 terms_required`)。
/// ここはその案内: サイドバーなどの帯 [RasqTermsBanner] と、承諾のシート [showRasqTermsSheet]。起動後に 1 度だけ自動で開く。

/// 同意待ちか。サーバーが返さない(古いサーバー)なら false。
final rasqTermsPendingProvider = Provider<bool>((ref) => ref.watch(orgateAccountProvider).value?.termsAccepted == false);

/// 承諾のシート。承諾したら true。
Future<bool> showRasqTermsSheet(WidgetRef ref) async {
  final account = ref.read(orgateAccountProvider).value;
  final client = ref.read(centralClientProvider);
  if (account == null || client == null) return false;
  final manager = ref.read(overlayManagerProvider);
  if (manager.contains('rasq.terms')) return false;
  final needAge = account.termsMissing.contains('age');
  final age = ValueNotifier<RasqAgeBand?>(null);
  final guardian = ValueNotifier(false);
  final agreed = ValueNotifier(false);
  final ready = ValueNotifier(false);
  void sync() => ready.value = agreed.value && (!needAge || (age.value != null && (!age.value!.needsGuardian || guardian.value)));
  for (final n in [age, guardian, agreed]) {
    n.addListener(sync);
  }
  final ok = await manager.showBottomSheet<bool>(
    id: 'rasq.terms',
    title: appL10n.shellTermsSheetTitle,
    confirmText: appL10n.shellTermsAgreeButton,
    confirmEnabled: ready,
    builder: (ctx) => ListenableBuilder(
      listenable: Listenable.merge([age, guardian, agreed]),
      builder: (_, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: RasqSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          RasqNotice(
            text: ctx.l10n.shellTermsNotice,
            detail: ctx.l10n.shellTermsNoticeDetail('{terms,privacy,age,guardian}'),
          ),
          RasqListTile(key: const ValueKey('terms.read.terms'), title: ctx.l10n.shellTermsReadTermsButton, onTap: () => ref.read(routerProvider).push('/settings/dsl/about.terms')),
          RasqListTile(key: const ValueKey('terms.read.privacy'), title: ctx.l10n.shellTermsReadPrivacyButton, onTap: () => ref.read(routerProvider).push('/settings/dsl/about.privacy')),
          if (needAge) ...[
            RasqSectionHeader(title: ctx.l10n.shellTermsAgeHeader),
            for (final a in RasqAgeBand.values)
              RasqRadioListTile<RasqAgeBand>(key: ValueKey('terms.age.${a.wire}'), title: a.label, value: a, groupValue: age.value, onChanged: (v) => age.value = v),
            if (age.value?.needsGuardian ?? false)
              RasqListTile(
                key: const ValueKey('terms.guardian'),
                title: ctx.l10n.shellTermsGuardianConsentCheck,
                chevron: false,
                onTap: () => guardian.value = !guardian.value,
                trailing: Checkbox(value: guardian.value, onChanged: (x) => guardian.value = x ?? false),
              ),
          ],
          RasqListTile(
            key: const ValueKey('terms.agree'),
            title: ctx.l10n.shellTermsAgreeCheck,
            chevron: false,
            onTap: () => agreed.value = !agreed.value,
            trailing: Checkbox(value: agreed.value, onChanged: (x) => agreed.value = x ?? false),
          ),
          RasqCaption(ctx.l10n.shellTermsVersionCaption(rasqTermsVersion, rasqPrivacyVersion)),
        ]),
      ),
    ),
  );
  if (ok != true) return false;
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  try {
    await RasqConsentApi(client).acceptCurrent(age: needAge ? age.value : null);
    await ref.read(orgateAccountProvider.notifier).refresh();
    messenger?.showSnackBar(SnackBar(content: Text(appL10n.shellTermsAcceptedSnack)));
    return true;
  } on OrgateException catch (e) {
    final outdated = isTermsVersionError(e);
    messenger?.showSnackBar(SnackBar(content: Text(outdated ? appL10n.shellTermsOutdatedError : appL10n.shellTermsRecordFailedError('$e'))));
    return false;
  }
}

/// 同意待ちのときだけ出る帯(サイドバー / AsTell)。
class RasqTermsBanner extends ConsumerWidget {
  const RasqTermsBanner({super.key, this.margin});
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(rasqTermsPendingProvider)) return const SizedBox.shrink();
    return RasqNotice.warning(
      key: const ValueKey('terms.banner'),
      margin: margin,
      text: context.l10n.shellTermsBannerText,
      action: TextButton(key: const ValueKey('terms.banner.open'), onPressed: () => showRasqTermsSheet(ref), child: Text(context.l10n.shellTermsBannerOpenButton)),
    );
  }
}

/// 起動後、同意待ちと分かったら 1 度だけシートを開く(`app.dart` で listen)。
class RasqTermsAutoPrompt {
  bool _shown = false;

  void onAccount(WidgetRef ref, RasqAccount? account) {
    if (_shown || account?.termsAccepted != false) return;
    _shown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => showRasqTermsSheet(ref));
  }
}
