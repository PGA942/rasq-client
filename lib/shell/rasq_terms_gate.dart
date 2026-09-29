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
    title: '利用規約への同意',
    confirmText: '同意する',
    confirmEnabled: ready,
    builder: (ctx) => ListenableBuilder(
      listenable: Listenable.merge([age, guardian, agreed]),
      builder: (_, _) => SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: RasqSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const RasqNotice(
            text: 'RASQ アカウントを使い続けるには、いまの利用規約とプライバシーポリシーへの同意が必要です。同意するまで、AsTell・購入・データの預け入れは使えません。',
            detail: 'D-371 / S-053。サーバーの CENTRAL_TERMS_VERSION / CENTRAL_PRIVACY_VERSION と同じ版の承諾がそろうまで「同意待ち」。PUT /me/consents/{terms,privacy,age,guardian}。',
          ),
          RasqListTile(key: const ValueKey('terms.read.terms'), title: '利用規約を読む', onTap: () => ref.read(routerProvider).push('/settings/dsl/about.terms')),
          RasqListTile(key: const ValueKey('terms.read.privacy'), title: 'プライバシーポリシーを読む', onTap: () => ref.read(routerProvider).push('/settings/dsl/about.privacy')),
          if (needAge) ...[
            const RasqSectionHeader(title: '年齢'),
            for (final a in RasqAgeBand.values)
              RasqRadioListTile<RasqAgeBand>(key: ValueKey('terms.age.${a.wire}'), title: a.label, value: a, groupValue: age.value, onChanged: (v) => age.value = v),
            if (age.value?.needsGuardian ?? false)
              RasqListTile(
                key: const ValueKey('terms.guardian'),
                title: '保護者の同意を得ています',
                chevron: false,
                onTap: () => guardian.value = !guardian.value,
                trailing: Checkbox(value: guardian.value, onChanged: (x) => guardian.value = x ?? false),
              ),
          ],
          RasqListTile(
            key: const ValueKey('terms.agree'),
            title: '利用規約とプライバシーポリシーを読み、同意します',
            chevron: false,
            onTap: () => agreed.value = !agreed.value,
            trailing: Checkbox(value: agreed.value, onChanged: (x) => agreed.value = x ?? false),
          ),
          RasqCaption('版: 利用規約 $rasqTermsVersion ・ プライバシーポリシー $rasqPrivacyVersion'),
        ]),
      ),
    ),
  );
  if (ok != true) return false;
  final messenger = ref.read(rootMessengerKeyProvider).currentState;
  try {
    await RasqConsentApi(client).acceptCurrent(age: needAge ? age.value : null);
    await ref.read(orgateAccountProvider.notifier).refresh();
    messenger?.showSnackBar(const SnackBar(content: Text('利用規約に同意しました')));
    return true;
  } on OrgateException catch (e) {
    final outdated = isTermsVersionError(e);
    messenger?.showSnackBar(SnackBar(content: Text(outdated ? '利用規約が新しくなっています。アプリを更新してから同意してください' : '同意を記録できませんでした: $e')));
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
      text: '利用規約への同意が必要です。同意するまで AsTell・購入などは使えません。',
      action: TextButton(key: const ValueKey('terms.banner.open'), onPressed: () => showRasqTermsSheet(ref), child: const Text('確認する')),
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
