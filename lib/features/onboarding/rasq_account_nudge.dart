import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../collections/rasq_collections.dart' show hasRasqAccountProvider;
import 'feature_tour.dart' show featureTourHoldNudge, featureTourHoldsProvider;
import 'rasq_register_screen.dart' show openRasqAccountCreation;

/// タイルから登録した人に、あとで RASQ アカウントを聞く (D-413)。
///
/// サーバー / RASQ リストのタイルから登録した人 (D-412) は、RASQ アカウントの問い(オンボーディングの入口)を通らない。
/// **最初のオンボーディング(タイル → サーバーに登録 → SNS のログイン → タップしたものを開く)が終わったら**、
/// 「RASQ アカウントを作りますか?」のポップアップを 1 回だけ出す: **作る**(① ② のページ、D-414 / D-419。前は登録のページ `/rasq-register`)/
/// **ログイン**(すでに持っている人)/ **あとで**(サイドバーの … からいつでも作れる)。
/// 出したことは端末に残す(KV [rasqAccountNudgeKey])。Central の RASQ アカウントをもう持っている人には出さない。

/// 出したかの印(端末の保存領域)。
const rasqAccountNudgeKey = 'onboarding.rasqAccountNudge.v1';

/// ポップアップの id。
const rasqAccountNudgeId = 'onboarding.rasqAccount';

/// 出すのを待っているか(シェルの [RasqAccountNudgeListener] が出す)。
class RasqAccountNudgeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final rasqAccountNudgeProvider = NotifierProvider<RasqAccountNudgeNotifier, bool>(RasqAccountNudgeNotifier.new);

/// Central の RASQ アカウントをもう持っているか(台帳に Central のアカウントがある / いま入っている)。
bool hasCentralRasqAccount(ProviderContainer c) => (c.read(rasqAccountsProvider).value?.hasCentral ?? false) || c.read(hasRasqAccountProvider);

/// 最初のオンボーディングが終わった(タイルから登録した人)。まだ出しておらず、RASQ アカウントが無ければ、ポップアップを頼む。
Future<void> requestRasqAccountNudge(ProviderContainer c) async {
  if (hasCentralRasqAccount(c)) return;
  final storage = c.read(sessionStorageProvider);
  if (await storage.read(rasqAccountNudgeKey) != null) return;
  c.read(rasqAccountNudgeProvider.notifier).set(true);
}

/// ポップアップの選択肢。
enum RasqAccountNudgeChoice { create, login, later }

/// シェルに置く: 頼まれたらポップアップを出す(いつ頼まれても、ログインしたあとの画面の上に出る)。
class RasqAccountNudgeListener extends ConsumerStatefulWidget {
  const RasqAccountNudgeListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<RasqAccountNudgeListener> createState() => _RasqAccountNudgeListenerState();
}

class _RasqAccountNudgeListenerState extends ConsumerState<RasqAccountNudgeListener> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    // 頼まれたのがこのウィジェットより前でも出す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(rasqAccountNudgeProvider)) unawaited(_show());
    });
  }

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _show() async {
    if (_showing) return;
    _showing = true;
    // 出している間は RASQ の機能の紹介 (D-471) を待たせる(先に印を付けてから、頼まれた印を下ろす)。
    final holds = ref.read(featureTourHoldsProvider.notifier)..hold(featureTourHoldNudge);
    ref.read(rasqAccountNudgeProvider.notifier).set(false);
    try {
      final c = ProviderScope.containerOf(context, listen: false);
      // 待っている間に作った / ログインしたなら出さない。出すと決めたら、選ぶ前に印を残す(1 回だけ)。
      if (hasCentralRasqAccount(c)) return;
      final storage = ref.read(sessionStorageProvider);
      if (await storage.read(rasqAccountNudgeKey) != null || !mounted) return;
      await storage.write(rasqAccountNudgeKey, DateTime.now().toUtc().toIso8601String());
      final picked = await ref.read(overlayManagerProvider).showChoiceAlert<RasqAccountNudgeChoice>(
        id: rasqAccountNudgeId,
        title: 'RASQ アカウントを作りますか?',
        message: 'RASQ アカウントがあると、入れたプラグインや設定・SNS のアカウントのまとまりを、ほかの端末でも使えます。Swing や RASQ リストも RASQ アカウントから使います。あとからサイドバーの … でも作れます。',
        cancelText: null,
        choices: const [
          RasqAlertChoice('作る', RasqAccountNudgeChoice.create, primary: true, key: ValueKey('rasqNudge.create')),
          RasqAlertChoice('ログイン(持っている人)', RasqAccountNudgeChoice.login, key: ValueKey('rasqNudge.login')),
          RasqAlertChoice('あとで', RasqAccountNudgeChoice.later, key: ValueKey('rasqNudge.later')),
        ],
      );
      if (!mounted) return;
      switch (picked) {
        case RasqAccountNudgeChoice.create:
          // 作る流れ (D-419): オンボーディング v2 の ①② のページ(ユーザー名・パスワード・年齢 → 規約)。作れたら元の画面へ戻る。
          final rec = await openRasqAccountCreation(ref.read(routerProvider), ProviderScope.containerOf(context, listen: false).read, onMessage: _toast);
          if (rec != null) _toast('RASQ アカウント @${rec.handle ?? ''} を作成しました');
        case RasqAccountNudgeChoice.login:
          unawaited(ref.read(routerProvider).push('${Routes.settings}/account-login'));
        case RasqAccountNudgeChoice.later || null:
          break;
      }
    } finally {
      _showing = false;
      holds.release(featureTourHoldNudge);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(rasqAccountNudgeProvider, (_, next) {
      if (next) unawaited(_show());
    });
    return widget.child;
  }
}
