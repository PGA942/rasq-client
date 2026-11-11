import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../backend/link_match_api.dart';
import '../../l10n/l10n.dart';

/// 自分の X の名乗り(`GET /me/x-identity`)。Central が未設定 / 未ログインなら null。
final xIdentityProvider = FutureProvider.autoDispose<XIdentity?>((ref) async => ref.watch(linkMatchApiProvider)?.xIdentity());

/// プロフィール編集の「X アカウント(X で認証・試作)」(D-551、Central S-129)。
///
/// **ダミーの X 認証**: X には確かめに行かず、入れたハンドル(と任意の内部 ID)をそのまま RASQ に持たせる。ほかの人が X の書き出しから
/// 自分を見つけるための鍵になるが、確認済みの印は付かない。本物の X 認証が入ったら、このボタンの先を置き換える。
class XIdentitySection extends ConsumerStatefulWidget {
  const XIdentitySection({super.key});
  @override
  ConsumerState<XIdentitySection> createState() => _XIdentitySectionState();
}

class _XIdentitySectionState extends ConsumerState<XIdentitySection> {
  final _handle = TextEditingController();
  final _userId = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _handle.dispose();
    _userId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = ref.read(linkMatchApiProvider);
    final handle = validXHandle(_handle.text);
    final id = _userId.text.trim();
    if (api == null) return;
    if (handle == null || (id.isNotEmpty && linkMatchXId(id) == null)) {
      setState(() => _error = context.l10n.onboardingExportXIdentityInvalid);
      return;
    }
    await _run(() => api.putXIdentity(handle: handle, userId: id.isEmpty ? null : id));
    _handle.clear();
    _userId.clear();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(xIdentityProvider);
    } catch (e) {
      debugPrint('x identity: $e');
      if (mounted) setState(() => _error = context.l10n.onboardingExportXIdentityFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final caption = RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant);
    final current = ref.watch(xIdentityProvider).value;
    final api = ref.watch(linkMatchApiProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.onboardingExportXIdentityBody, style: caption),
      const SizedBox(height: RasqSpacing.xs),
      Row(children: [
        Expanded(
          child: Text(
            current == null ? l10n.onboardingExportXIdentityNone : l10n.onboardingExportXIdentityCurrent(current.handle),
            key: const ValueKey('rasqProfile.x.current'),
            style: RasqTypography.bodySmall,
          ),
        ),
        if (current != null)
          TextButton(key: const ValueKey('rasqProfile.x.remove'), onPressed: _busy || api == null ? null : () => _run(api.deleteXIdentity), child: Text(l10n.onboardingExportXIdentityRemove)),
      ]),
      const SizedBox(height: RasqSpacing.xs),
      TextField(key: const ValueKey('rasqProfile.x.handle'), controller: _handle, decoration: InputDecoration(isDense: true, prefixText: '@', labelText: l10n.onboardingExportXIdentityHandleLabel)),
      TextField(
        key: const ValueKey('rasqProfile.x.userId'),
        controller: _userId,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(isDense: true, labelText: l10n.onboardingExportXIdentityIdLabel, helperText: l10n.onboardingExportXIdentityIdHelp, helperMaxLines: 3),
      ),
      const SizedBox(height: RasqSpacing.xs),
      OutlinedButton(key: const ValueKey('rasqProfile.x.save'), onPressed: _busy || api == null ? null : _save, child: Text(l10n.onboardingExportXIdentitySave)),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: RasqSpacing.xs), child: Text(_error!, key: const ValueKey('rasqProfile.x.error'), style: RasqTypography.caption.copyWith(color: scheme.error))),
    ]);
  }
}
