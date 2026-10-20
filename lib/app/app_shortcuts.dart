import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_actions/quick_actions.dart';

import '../features/child_safe/child_gate.dart';
import '../features/child_safe/child_safe_providers.dart' show childGateProvider, childSafeProvider;
import '../features/compose/compose_target.dart';
import '../features/compose/composer_sheet.dart' show showComposerWith;
import '../features/dm/dm_providers.dart';
import '../features/dm/dm_screen.dart' show startNewDm;
import '../features/plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../features/rai/rai_providers.dart' show raiProvider;
import '../features/search/search_screen.dart' show searchFocusRequestsProvider;
import 'navigation.dart' show visibleLocationOf;
import 'providers.dart';
import 'router.dart';
import '../l10n/l10n.dart';

/// ホーム画面のアプリのショートカット (D-483): アプリのアイコンを長押しして出るクイックアクション(X の「検索 / 新しいポスト /
/// メッセージを作成」と同じ形)に、RASQ の「RAiと探す」を足した 4 つ。
///
/// - **iOS / iPadOS**: `ios/Runner/Info.plist` の `UIApplicationShortcutItems`(静的な項目。アイコンは SF Symbols、名前は
///   `InfoPlist.strings` の ja / en)。入れた直後から(1 度も開かないうちから)出て、App ライブラリからも使える。
///   quick_actions の動的な項目は SF Symbols を使えない(アセットの画像名だけ)ので、iOS では動的な項目を置かない。
/// - **Android**: quick_actions の動的なショートカット([appShortcutLabel] の名前 + `res/drawable*/ic_shortcut_*` のアイコン)。
///   アプリを 1 度開くと出る。
/// - **Web / デスクトップ**: 何もしない。
///
/// 押されたら、起動の直後(コールドスタート)でも開いている間でも、ログインと保存した状態を読み終えてから [planAppShortcut] の
/// とおりに開く。ログインしていなければ入口(オンボーディング / ログイン)、見守り(チャイルドセーフ)で止めている機能は開かず理由を出す。
enum AppShortcut {
  search('rasq.search'),
  newPost('rasq.post'),
  newMessage('rasq.message'),
  askRai('rasq.rai');

  const AppShortcut(this.type);

  /// 端末に渡す種類(iOS の `UIApplicationShortcutItemType` と同じ値)。
  final String type;

  static AppShortcut? fromType(String? type) => values.where((s) => s.type == type).firstOrNull;
}

/// ショートカットの名前(表示の言語、部品 app_nav)。iOS の名前は `ios/Runner/{ja,en}.lproj/InfoPlist.strings`
/// (静的な項目なので端末の言語で OS が選ぶ)。変えるときは両方を揃える。
String appShortcutLabel(AppShortcut s) => switch (s) {
      AppShortcut.search => appL10n.appNavShortcutSearch,
      AppShortcut.newPost => appL10n.appNavShortcutNewPost,
      AppShortcut.newMessage => appL10n.appNavShortcutNewMessage,
      AppShortcut.askRai => appL10n.appNavShortcutAskRai,
    };

/// Android のアイコン(`res/drawable/ic_shortcut_*.xml`、API 26 からはアダプティブアイコン `drawable-anydpi-v26`)。
String appShortcutAndroidIcon(AppShortcut s) => switch (s) {
      AppShortcut.search => 'ic_shortcut_search',
      AppShortcut.newPost => 'ic_shortcut_post',
      AppShortcut.newMessage => 'ic_shortcut_message',
      AppShortcut.askRai => 'ic_shortcut_rai',
    };

/// 端末のショートカットの口(テストは差し替える)。
abstract class AppShortcutsPlatform {
  /// 押されたときに [onAction] を呼ぶようにする。Android は起動のもとになったショートカットもここで届く。
  Future<void> initialize(void Function(String type) onAction);

  /// 動的な項目を置く(Android)。
  Future<void> setItems(List<ShortcutItem> items);
}

/// quick_actions (flutter.dev) を使う口。
class QuickActionsShortcutsPlatform implements AppShortcutsPlatform {
  const QuickActionsShortcutsPlatform();
  static const _qa = QuickActions();

  @override
  Future<void> initialize(void Function(String type) onAction) => _qa.initialize(onAction);

  @override
  Future<void> setItems(List<ShortcutItem> items) => _qa.setShortcutItems(items);
}

/// Android / iOS のアプリだけ。Web とデスクトップは null(何もしない)。
final appShortcutsPlatformProvider = Provider<AppShortcutsPlatform?>((ref) {
  if (kIsWeb) return null;
  return switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => const QuickActionsShortcutsPlatform(),
    _ => null,
  };
});

/// Android に置く動的な項目(並びは長押しのメニューの並び)。iOS は Info.plist の静的な項目なので空。
List<ShortcutItem> appShortcutItemsFor(TargetPlatform platform) => platform != TargetPlatform.android
    ? const []
    : [for (final s in AppShortcut.values) ShortcutItem(type: s.type, localizedTitle: appShortcutLabel(s), icon: appShortcutAndroidIcon(s))];

/// 開いたあとにすること。
enum AppShortcutFollowUp {
  none,

  /// 検索タブの検索欄にフォーカス。
  focusSearch,

  /// いまのアカウントで投稿のコンポーザー(＋ の「投稿」と同じ)。
  composePost,

  /// 新規メッセージ(DM の + と同じ: 相手を選ぶシート → ルーム)。
  composeMessage,

  /// RAi ホームを入力欄にフォーカスして。
  askRai,
}

/// ショートカット → 行き先。[location] = 移る場所(null = いまの画面のまま)、[blocked] = 開かずに出す理由。
typedef AppShortcutPlan = ({String? location, AppShortcutFollowUp followUp, String? blocked});

/// 押されたショートカットの行き先を決める(状態だけを見る、テスト用に切り出し)。
/// - 保護者が決めるまでの鍵 / SNS アカウントにログインしていない → どこへも移らず案内だけ。そのときはルーターがもう設定待ちの画面 /
///   入口(オンボーディング / ログイン)に置いている(起動の直後も)ので、入口の途中の画面から動かさない。
/// - 見守りで止めている機能 → どこへも移らず理由だけ(ルーターの [ChildGate.routeBlockReason] と同じ文)。
@visibleForTesting
AppShortcutPlan planAppShortcut(AppShortcut s, {required bool loggedIn, required ChildGate gate}) {
  if (gate.locked) return (location: null, followUp: AppShortcutFollowUp.none, blocked: appL10n.appNavShortcutGuardianPending);
  if (!loggedIn) return (location: null, followUp: AppShortcutFollowUp.none, blocked: appShortcutLoginHint);
  AppShortcutPlan open(String? location, AppShortcutFollowUp f, String? blocked) =>
      blocked != null ? (location: null, followUp: AppShortcutFollowUp.none, blocked: blocked) : (location: location, followUp: f, blocked: null);
  return switch (s) {
    // 幅の広い画面でも検索タブ(レールの「検索」と同じ。第3カラムの検索は設定で別のものにできるので使わない)。
    AppShortcut.search => open(Routes.search, AppShortcutFollowUp.focusSearch, gate.routeBlockReason(Routes.search)),
    // コンポーザーは FOW なので、いまの画面の上に開く(起動の直後はホーム)。
    AppShortcut.newPost => open(null, AppShortcutFollowUp.composePost, gate.blockedMessage('post')),
    AppShortcut.newMessage => open(Routes.dm, AppShortcutFollowUp.composeMessage, gate.routeBlockReason(Routes.dm) ?? gate.blockedMessage('dm')),
    AppShortcut.askRai => open(Routes.raiAsk, AppShortcutFollowUp.askRai, gate.routeBlockReason(Routes.rai)),
  };
}

/// ログインしていないときの案内。
String get appShortcutLoginHint => appL10n.appNavShortcutLoginHint;

/// 押されたショートカットを受けて開く。起動時に 1 回 watch する([RasqApp])。
final appShortcutsProvider = Provider<AppShortcutRunner>((ref) {
  final runner = AppShortcutRunner(ref);
  final platform = ref.watch(appShortcutsPlatformProvider);
  if (platform != null) unawaited(runner._install(platform));
  // ログイン / 保存した状態 / 見守りの設定を読み終えたら、待たせていたものを開く。
  ref.listen(sessionsProvider, (_, _) => runner._drain());
  ref.listen(rasqAccountsProvider, (_, _) => runner._drain());
  ref.listen(childSafeProvider, (_, _) => runner._drain());
  ref.onDispose(runner._dispose);
  return runner;
});

class AppShortcutRunner {
  AppShortcutRunner(this._ref);
  final Ref _ref;
  AppShortcut? _pending;
  bool _disposed = false;

  Future<void> _install(AppShortcutsPlatform platform) async {
    try {
      await platform.initialize(handle);
    } catch (e) {
      debugPrint('app shortcuts: initialize failed: $e');
    }
    final items = appShortcutItemsFor(defaultTargetPlatform);
    if (items.isEmpty) return;
    try {
      await platform.setItems(items);
    } catch (e) {
      debugPrint('app shortcuts: setItems failed: $e');
    }
  }

  void _dispose() => _disposed = true;

  /// 端末から届いた種類。知らないものは捨てる。最後に押したものだけを開く。
  void handle(String type) {
    final s = AppShortcut.fromType(type);
    if (s == null || _disposed) return;
    _pending = s;
    _drain();
  }

  bool get _ready => !_ref.read(sessionsProvider).isLoading && !_ref.read(rasqAccountsProvider).isLoading && !_ref.read(childSafeProvider).isLoading;

  void _drain() {
    if (_pending == null || _disposed || !_ready) return;
    final s = _pending!;
    _pending = null;
    // ルーターが入口を決め直してから(起動の直後は最初のコマのあと)。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) unawaited(_run(s));
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _run(AppShortcut s) async {
    final plan = planAppShortcut(s, loggedIn: _ref.read(sessionsProvider).value?.isLoggedIn ?? false, gate: _ref.read(childGateProvider));
    if (plan.blocked != null) {
      _ref.read(rootMessengerKeyProvider).currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(plan.blocked!)));
      return;
    }
    final router = _ref.read(routerProvider);
    final manager = _ref.read(overlayManagerProvider);
    switch (plan.followUp) {
      case AppShortcutFollowUp.none:
        if (plan.location != null) router.go(plan.location!);
      case AppShortcutFollowUp.focusSearch:
        router.go(plan.location!);
        await WidgetsBinding.instance.endOfFrame;
        _ref.read(searchFocusRequestsProvider).request();
      case AppShortcutFollowUp.composePost:
        // ＋ の「投稿」と同じ(いまのアカウント)。
        unawaited(showComposerWith(const ComposeNormal(), manager: manager, router: router));
      case AppShortcutFollowUp.composeMessage:
        router.go(plan.location!);
        await WidgetsBinding.instance.endOfFrame;
        if (_disposed) return;
        unawaited(startNewDm(manager: manager, router: router, rooms: () => _ref.read(dmRoomsProvider).value ?? const []));
      case AppShortcutFollowUp.askRai:
        final rai = _ref.read(raiProvider.notifier);
        if (visibleLocationOf(router.routerDelegate.currentConfiguration).startsWith(Routes.rai)) {
          // もう RAi ホームにいる: 入力欄にフォーカスし直す(入力中の印を立て直す)。
          rai.setAsking(false);
          await WidgetsBinding.instance.endOfFrame;
          if (!_disposed) rai.setAsking(true);
        } else {
          unawaited(router.push(plan.location!));
        }
    }
  }
}
