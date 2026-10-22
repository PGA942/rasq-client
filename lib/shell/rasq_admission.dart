import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../backend/orgate_client.dart';
import '../backend/rasq_account.dart' show currentCentralAccountIdProvider;
import '../features/plugins/slot_plugins.dart' show rootMessengerKeyProvider;
import '../l10n/l10n.dart';

/// 入場の審査 (D-548 / Central S-120 / ORGATE O-022 / Judge J-024)。
///
/// 運営が Judge で制限を入れると、新しい RASQ アカウントは作った時点では「審査待ち」(`pending`)か「枠待ち・招待コード待ち」
/// (`waitlisted`)になる。**審査待ちでも自分の SNS は今まで通り使える**(読む・書く・同期・保管庫・端末間の共有)。止まるのは
/// RASQ の中で他人に見えるもの(公開プロフィール・AsTell・Swing の投稿・共有ページへの書き込み など)だけで、Central は
/// `403 admission_pending` を返す([AdmissionPendingException]、エラーではなく案内として出す)。
///
/// - 状態: `GET /api/v1/me/admission`([rasqAdmissionProvider])。アカウントの切り替え・アプリへ戻ったとき・止められたとき
///   ([OrgateClient.admissionBlocked])に読み直す。読めない(古いサーバー / つながらない)なら null = 何も出さない。
/// - 帯: [RasqAdmissionBanner]。ホーム(閉じられる)と、止められる機能の入口(AsTell・Swing)に出す。招待コード待ちなら
///   コードを入れる欄も出す(`POST /api/v1/me/admission/code`)。
/// - 通った利用者がコードを出せる設定なら、設定に「招待コード」の画面(`RasqInvitesScreen`)。

/// 入場の状態(Central の `accounts.admission`)。
enum RasqAdmissionState {
  pending,
  waitlisted,
  approved,
  rejected;

  static RasqAdmissionState fromWire(Object? w) => values.where((v) => v.name == w).firstOrNull ?? approved;
}

/// 枠待ちの理由。
enum RasqWaitReason {
  /// 人数の枠(1 日 / 全体)が埋まっている。
  capacity,

  /// 招待コードが要る(無い / 効かなかった)。
  invite;

  static RasqWaitReason? fromWire(Object? w) => values.where((v) => v.name == w).firstOrNull;
}

/// `GET /api/v1/me/admission` の答え。
@immutable
class RasqAdmission {
  const RasqAdmission({required this.state, this.waitReason, this.position, this.canIssue = false, this.remaining});
  final RasqAdmissionState state;
  final RasqWaitReason? waitReason;

  /// 枠待ちの順番の目安(分からなければ null)。
  final int? position;

  /// 招待コードを出せる(`invite_user_issue` が有効で、本人が `approved`)と、出せる残りの数。
  final bool canIssue;
  final int? remaining;

  /// 審査を通っていない(帯を出す)。`rejected` は今の恒久の凍結の画面が扱うので、ここでは出さない。
  bool get limited => state == RasqAdmissionState.pending || state == RasqAdmissionState.waitlisted;

  /// 設定に「招待コード」の画面を出す。
  bool get canInvite => canIssue && state == RasqAdmissionState.approved;

  factory RasqAdmission.fromJson(Map<String, Object?> j) {
    final invites = j['invites'] is Map ? (j['invites'] as Map).cast<String, Object?>() : const <String, Object?>{};
    return RasqAdmission(
      state: RasqAdmissionState.fromWire(j['admission']),
      waitReason: RasqWaitReason.fromWire(j['waitReason']),
      position: (j['position'] as num?)?.toInt(),
      canIssue: invites['canIssue'] == true,
      remaining: (invites['remaining'] as num?)?.toInt(),
    );
  }
}

/// 自分が出した招待コード(平文は出したときだけ。あとは末尾の [hint] だけ)。
@immutable
class RasqInvite {
  const RasqInvite({required this.id, required this.hint, required this.uses, required this.used, this.expiresAt, this.revokedAt, this.createdAt});
  final String id;
  final String hint;
  final int uses;
  final int used;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final DateTime? createdAt;

  factory RasqInvite.fromJson(Map<String, Object?> j) => RasqInvite(
        id: '${j['id'] ?? ''}',
        hint: j['hint'] as String? ?? '',
        uses: (j['uses'] as num?)?.toInt() ?? 0,
        used: (j['used'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''),
        revokedAt: DateTime.tryParse(j['revokedAt'] as String? ?? ''),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}

/// 出したばかりの招待コード(`code` は平文。このときだけ)。
@immutable
class RasqIssuedInvite {
  const RasqIssuedInvite({required this.id, required this.code, required this.uses, this.expiresAt});
  final String id;
  final String code;
  final int uses;
  final DateTime? expiresAt;

  factory RasqIssuedInvite.fromJson(Map<String, Object?> j) => RasqIssuedInvite(
        id: '${j['id'] ?? ''}',
        code: j['code'] as String? ?? '',
        uses: (j['uses'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.tryParse(j['expiresAt'] as String? ?? ''),
      );
}

/// 効かなかった招待コードの理由(`400 admission_invite_invalid` の `error.reason`)。
enum RasqInviteProblem {
  unknown,
  expired,
  usedUp,
  revoked;

  static RasqInviteProblem of(OrgateException e) => switch (e.details['reason']) {
        'expired' => expired,
        'used_up' => usedUp,
        'revoked' => revoked,
        _ => unknown,
      };

  String get message => switch (this) {
        unknown => appL10n.admissionCodeUnknown,
        expired => appL10n.admissionCodeExpired,
        usedUp => appL10n.admissionCodeUsedUp,
        revoked => appL10n.admissionCodeRevoked,
      };
}

/// 招待コードが効かなかった(`400 admission_invite_invalid`)。
bool isAdmissionInviteInvalid(Object e) => e is OrgateException && e.isReason('admission_invite_invalid');

/// Central の利用者の口(`/api/v1/me/admission*`)。
class RasqAdmissionApi {
  const RasqAdmissionApi(this._client);
  final OrgateClient _client;

  Future<RasqAdmission> status() async => RasqAdmission.fromJson(await _client.getJson('/me/admission'));

  /// 後から招待コードを入れる(`waitlisted` → `pending`)。効かなければ `400 admission_invite_invalid`。
  Future<RasqAdmission> submitCode(String code) async => RasqAdmission.fromJson(await _client.postJson('/me/admission/code', {'code': code}));

  Future<({List<RasqInvite> items, int remaining})> invites() async {
    final j = await _client.getJson('/me/admission/invites');
    return (
      items: [for (final e in j['items'] as List? ?? const []) if (e is Map) RasqInvite.fromJson(e.cast<String, Object?>())],
      remaining: (j['remaining'] as num?)?.toInt() ?? 0,
    );
  }

  /// 招待コードを出す。平文の `code` が返るのはこのときだけ。
  Future<RasqIssuedInvite> issue() async => RasqIssuedInvite.fromJson(await _client.postJson('/me/admission/invites', const {}));
}

/// いまの RASQ アカウントの入場の状態。ログインしていない / 読めないなら null(何も出さない)。
final rasqAdmissionProvider = AsyncNotifierProvider<RasqAdmissionNotifier, RasqAdmission?>(RasqAdmissionNotifier.new);

class RasqAdmissionNotifier extends AsyncNotifier<RasqAdmission?> {
  @override
  Future<RasqAdmission?> build() async {
    final accountId = ref.watch(currentCentralAccountIdProvider);
    final client = ref.watch(centralClientProvider);
    // 止められた口の答え(どの画面から呼んでも)/ アプリへ戻ったとき: 読み直す(通った・枠待ちに替わった を拾う)。
    final blocked = OrgateClient.admissionBlocked.listen((_) => unawaited(refresh()));
    AppLifecycleListener? lifecycle;
    try {
      lifecycle = AppLifecycleListener(onResume: () => unawaited(refresh()));
    } catch (_) {
      lifecycle = null; // バインディングの無いテスト
    }
    ref.onDispose(() {
      blocked.cancel();
      lifecycle?.dispose();
    });
    if (accountId == null || accountId.isEmpty || client == null) return null;
    return _read(client);
  }

  Future<RasqAdmission?> _read(OrgateClient client) async {
    try {
      return await RasqAdmissionApi(client).status();
    } on OrgateException catch (e) {
      // 404 = 審査の無い(古い)サーバー。ほかの失敗も、帯を出さずに今まで通り(止めるのはサーバー)。
      debugPrint('admission: status unavailable (${e.code.code})');
      return null;
    } catch (e) {
      // 形の違う答え(JSON のオブジェクトでない など)も同じ。
      debugPrint('admission: unexpected status ($e)');
      return null;
    }
  }

  /// 読み直す(前の値は、読めるまで残す)。
  Future<void> refresh() async {
    final client = ref.read(centralClientProvider);
    if (client == null || ref.read(currentCentralAccountIdProvider) == null) return;
    final next = await _read(client);
    if (ref.mounted && next != null) state = AsyncData(next);
  }

  /// 後から招待コードを入れる。受け付けたら新しい状態、効かなければ [OrgateException](`admission_invite_invalid`)。
  Future<RasqAdmission?> submitCode(String code) async {
    final client = ref.read(centralClientProvider);
    if (client == null) return null;
    final next = await RasqAdmissionApi(client).submitCode(code);
    if (ref.mounted) state = AsyncData(next);
    return next;
  }
}

/// ホームの帯を、この起動のあいだ閉じた(閉じたときの状態。状態が替わればまた出す)。
final rasqAdmissionBannerHiddenProvider = NotifierProvider<_HiddenNotifier, String?>(_HiddenNotifier.new);

class _HiddenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void hide(String key) => state = key;
}

/// 審査を通っていないときの帯。自分の SNS は使えることを先に言い、公開の機能が止まっていることを添える。
/// [dismissible] = 閉じられる(ホーム。読む・書くの邪魔をしない)。止められる機能の入口では閉じない。
class RasqAdmissionBanner extends ConsumerWidget {
  const RasqAdmissionBanner({super.key, this.dismissible = false, this.margin});
  final bool dismissible;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(rasqAdmissionProvider).value;
    if (a == null || !a.limited) return const SizedBox.shrink();
    final key = '${a.state.name}:${a.waitReason?.name}';
    if (dismissible && ref.watch(rasqAdmissionBannerHiddenProvider) == key) return const SizedBox.shrink();
    final l = context.l10n;
    final reason = switch ((a.state, a.waitReason)) {
      (RasqAdmissionState.waitlisted, RasqWaitReason.invite) => l.admissionWaitInvite,
      (RasqAdmissionState.waitlisted, _) => a.position == null ? l.admissionWaitCapacity : l.admissionWaitCapacityPosition(a.position!),
      _ => null,
    };
    final invite = a.state == RasqAdmissionState.waitlisted && a.waitReason == RasqWaitReason.invite;
    return Column(key: const ValueKey('admission.banner'), crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      RasqNotice(
        key: ValueKey('admission.banner.$key'),
        margin: margin,
        title: reason,
        text: l.admissionBannerText,
        action: dismissible
            ? TextButton(key: const ValueKey('admission.banner.close'), onPressed: () => ref.read(rasqAdmissionBannerHiddenProvider.notifier).hide(key), child: Text(l.admissionBannerClose))
            : null,
      ),
      if (invite) const RasqAdmissionCodeField(),
    ]);
  }
}

/// 招待コード待ちのときの、コードを入れる欄(`POST /api/v1/me/admission/code`)。
class RasqAdmissionCodeField extends ConsumerStatefulWidget {
  const RasqAdmissionCodeField({super.key});

  @override
  ConsumerState<RasqAdmissionCodeField> createState() => _RasqAdmissionCodeFieldState();
}

class _RasqAdmissionCodeFieldState extends ConsumerState<RasqAdmissionCodeField> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ref.read(rootMessengerKeyProvider).currentState;
    try {
      await ref.read(rasqAdmissionProvider.notifier).submitCode(code);
      messenger?.showSnackBar(SnackBar(content: Text(appL10n.admissionCodeAccepted)));
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = isAdmissionInviteInvalid(e) ? RasqInviteProblem.of(e).message : appL10n.admissionCodeFailed(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              key: const ValueKey('admission.code'),
              controller: _code,
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(isDense: true, labelText: context.l10n.admissionCodeLabel, errorText: _error, errorMaxLines: 3),
            ),
          ),
          const SizedBox(width: RasqSpacing.sm),
          FilledButton(key: const ValueKey('admission.code.submit'), onPressed: _busy ? null : _submit, child: Text(context.l10n.admissionCodeSubmit)),
        ]),
      );
}
