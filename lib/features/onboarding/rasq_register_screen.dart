import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/account_security_api.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_consent.dart';
import '../../l10n/l10n.dart';
import '../../session/rasq_account_logout.dart' show RasqProviderRead;
import 'region/region_picker.dart' show showRegionUnavailable;

/// RASQ アカウントの登録の手続き (D-241 → D-414 → D-419)。画面はオンボーディング v2 の ①② のページ(`onboarding_steps.dart`)。
/// 前の登録ページ(`/rasq-register`、D-405)は D-419 で外した(その経路は ① のページへ回る)。

/// パスワードの最短 (S-019)。
const rasqPasswordMinChars = 8;

/// パスワードの手前の確かめ(サーバーの決まり S-019 と同じ: 8〜256 文字、1 種類の字だけは不可)。空なら null(まだ入れていない)。
String? rasqPasswordProblem(String p) {
  if (p.isEmpty) return null;
  if (p.characters.length < rasqPasswordMinChars) return appL10n.onboardingPasswordTooShort(rasqPasswordMinChars);
  if (p.characters.length > 256) return appL10n.onboardingPasswordTooLong;
  if (p.characters.toSet().length == 1) return appL10n.onboardingPasswordRepeated;
  return null;
}

/// オンボーディングの外から作るとき (D-419) に ② が返すもの: 選んだ内容。**登録はページを閉じてから**行う
/// (ページの下で止まっている画面が、戻るときにアカウントの変化を一度に受けて、作り直しの途中で状態を変えないように。
/// ログインの画面と同じ理由)。
@immutable
class RasqCreateRequest {
  const RasqCreateRequest({required this.handle, required this.choice});
  final String handle;
  final RasqRegisterChoice choice;
}

/// 新しい RASQ アカウントを作る流れ(オンボーディングの外から、D-419)。① ユーザー名・パスワード・年齢 → ② 規約・
/// チャイルドセーフ のページ(D-414 と同じもの)を開き、② の「同意して登録する」でページを閉じて**元の画面へ戻ってから**登録する。
/// 作れたら台帳の行(キャンセル / 作れなければ null。理由は [onMessage])。ほかの RASQ アカウントに入っていても、新しく作る
/// (前は作らずにいまのアカウントを返していた)。ユーザー名が使われていたときは、アカウントは作って `rasq_…` のまま知らせる
/// (プロフィールで変えられる)。サイドバーの RASQ アカウントの選択の「新規作成」と、D-413 の「作る」から。
Future<RasqAccountRecord?> openRasqAccountCreation(GoRouter router, RasqProviderRead read, {required ValueChanged<String> onMessage}) async {
  final req = await router.push<RasqCreateRequest>(rasqCreateAccountLocation);
  if (req == null) return null;
  await WidgetsBinding.instance.endOfFrame;
  try {
    return await completeRasqRegistration(read, req.choice, handle: req.handle, another: true, keepOnHandleRejected: true, onMessage: onMessage);
  } on RasqRegionNotServed catch (e) {
    // 一覧を読めずに選べた地域を、作るときにサーバーが断った (D-542)。作成へは進めない画面を出す。
    final navigator = router.routerDelegate.navigatorKey.currentState;
    if (navigator != null) {
      await showRegionUnavailable(navigator, e.region);
    } else {
      onMessage(appL10n.regionUnavailableTitle);
    }
    return null;
  } on OrgateException catch (e) {
    onMessage(appL10n.onboardingCreateFailed(e.message));
    return null;
  }
}

/// [openRasqAccountCreation] の行き先(① のページの、元へ戻る形)。前の登録ページ `/rasq-register` もここへ回す。
const rasqCreateAccountLocation = '${Routes.onboardingAccount}?return=1';

/// 同じ作成の流れの中で、先に作ったアカウント(② でユーザー名が使われていて ① へ戻ったとき、作り直さずにそれで続ける)。
class RasqCreateAttempt {
  String? accountId;
}

/// ユーザー名(ハンドル)が使われている / 使えない (D-414)。アカウントはもう作ってあるので、名前を変えてやり直せる
/// ([completeRasqRegistration] はやり直しに強い: 作成済みならそのアカウントで続ける)。
class RasqHandleRejected implements Exception {
  const RasqHandleRejected(this.message);
  final String message;
  @override
  String toString() => message;
}

/// 住んでいる地域で RASQ を提供していない(ORGATE `403 region_not_served`、D-542 / O-018)。アカウントは作られていない。
/// 呼んだ画面は、作成へ進めない画面([showRegionUnavailable])を出す。
class RasqRegionNotServed implements Exception {
  const RasqRegionNotServed(this.region);
  final String? region;
  @override
  String toString() => 'region_not_served: $region';
}

/// ハンドルの決まり (Central `PATCH /me`): 3〜32 文字の `[a-z0-9_]`。
final rasqHandlePattern = RegExp(r'^[a-z0-9_]{3,32}$');

/// 選んだ内容で登録する(オンボーディング v2 の ①② から)。`POST /auth/device`(承諾と一緒)→ 承諾の補い →
/// [handle] があればハンドル(`PATCH /me`、使われていれば [RasqHandleRejected]。パスワードより前に確かめる)→ パスワード → 台帳へ。
/// [another] = ほかの RASQ アカウントに入っていても新しく作る(オンボーディングの外から、D-419)。[attempt] = 同じ流れで
/// 先に作ったアカウントを覚えておく(ユーザー名をやり直すとき、それで続ける)。[keepOnHandleRejected] = ユーザー名を
/// 断られても止めずに、いまのユーザー名のまま続ける(知らせだけ。ページを閉じてから登録するとき)。
Future<RasqAccountRecord?> completeRasqRegistration(RasqProviderRead read, RasqRegisterChoice choice,
    {String? displayName, String? handle, bool another = false, RasqCreateAttempt? attempt, bool keepOnHandleRejected = false, required ValueChanged<String> onMessage}) async {
  final notifier = read(orgateAccountProvider.notifier);
  // 登録と承諾は一緒に (D-371 / S-053、規約案 06 CONS-02): サーバーが同じ処理で残す。承諾を残せなければアカウントも作られない
  // (以前は作ったあとで同意を書き、失敗しても登録を続けていた)。
  RasqAccount? account;
  try {
    account = await notifier.createAccount(displayName: displayName, consents: choice.toConsentsJson(), another: another, resume: attempt?.accountId, region: choice.region);
  } on OrgateException catch (e) {
    if (isTermsVersionError(e)) {
      onMessage(appL10n.onboardingTermsOutdated);
      return null;
    }
    // 住んでいる地域 (D-542 / ORGATE O-018): 提供していない → 進めない画面へ。無い / 形が違う → 選び直してもらう。
    if (e.isReason('region_not_served')) throw RasqRegionNotServed(choice.region);
    if (e.isReason('region_required') || e.isReason('region_invalid')) {
      onMessage(appL10n.regionRequiredError);
      return null;
    }
    rethrow;
  }
  if (account == null) {
    onMessage(appL10n.onboardingNoServer);
    return null;
  }
  return _finishRegistration(read, notifier, account, choice, handle: handle, attempt: attempt, keepOnHandleRejected: keepOnHandleRejected, onMessage: onMessage);
}

/// [completeRasqRegistration] の続き(アカウントはできている): 承諾の補い → ユーザー名 → パスワード → 台帳へ。
Future<RasqAccountRecord?> _finishRegistration(RasqProviderRead read, OrgateAccountNotifier notifier, RasqAccount account, RasqRegisterChoice choice,
    {String? handle, RasqCreateAttempt? attempt, required bool keepOnHandleRejected, required ValueChanged<String> onMessage}) async {
  attempt?.accountId = account.id;
  // 端末ですでに作っていたアカウントへ戻ったときは、承諾がまだなら承諾を送る(戻ったアカウントは作成の処理を通らない)。
  final client = read(centralClientProvider);
  if (client != null && account.termsAccepted == false) {
    await RasqConsentApi(client).acceptCurrent(age: account.termsMissing.contains('age') ? choice.age : null);
    await notifier.refresh();
  }
  // ユーザー名 (D-414)。作成のあとで変える(ORGATE の発行は名前を取らない)。使われていれば、パスワードより前に止める。
  if (handle != null && handle.isNotEmpty && account.handle != handle) {
    try {
      await notifier.updateProfile(handle: handle);
      account = read(orgateAccountProvider).value ?? account;
    } on OrgateException catch (e) {
      final code = e.code.code;
      final rejected = switch (code) {
        '409' => appL10n.onboardingHandleTaken,
        '400' || '422' => appL10n.onboardingHandleUnusable(e.message),
        _ => null,
      };
      if (rejected == null) rethrow;
      if (!keepOnHandleRejected) throw RasqHandleRejected(rejected);
      onMessage(appL10n.onboardingHandleKept(rejected, account.handle));
    }
  }
  // パスワード (D-299)。すでに設定済みのアカウントへ戻ったとき(この端末の前のアカウント)は、変えない。
  final security = read(accountSecurityApiProvider);
  if (choice.password.isNotEmpty && !account.hasPassword && security != null) {
    try {
      await security.setPassword(choice.password);
      await notifier.refresh();
    } on OrgateException catch (e) {
      onMessage(appL10n.onboardingPasswordSetFailed(accountSecurityMessage(e)));
    }
  }
  if (notifier.lastRestored) onMessage(appL10n.onboardingRestored);
  return read(rasqAccountsProvider.notifier).attachCentral(
        centralAccountId: account.id,
        handle: account.handle,
        displayName: account.displayName,
        avatarUrl: account.avatarUrl,
        inheritSessions: choice.replaceBundle,
      );
}
