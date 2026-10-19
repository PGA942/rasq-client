import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart' show SnsKind;
import 'package:rasq_overlay/rasq_overlay.dart';

import '../../app/providers.dart';
import '../../app/router.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../backend/rasq_account_page_api.dart' hide RasqNotice;
import '../../l10n/l10n.dart';
import 'rasq_account_page_screen.dart' show RasqSnsTileChip;
import 'rasq_ownership_screens.dart' show rasqVerifiableKinds;
import '../../shell/headers.dart';
import '../../session/bluesky_auth.dart' show blueskyDidOf;

/// 選んだ画像の content-type(名前か、ピッカーの申告から)。サーバーは中身で判定し直すので、目安でよい。
String profileImageContentType(String name, String? reported) {
  if (reported != null && reported.startsWith('image/')) return reported;
  final ext = name.split('.').last.toLowerCase();
  return switch (ext) { 'png' => 'image/png', 'webp' => 'image/webp', 'gif' => 'image/gif', _ => 'image/jpeg' };
}

/// RASQ アカウントのプロフィール編集 (D-269 / S-020)。SNS(Misskey)のプロフィール編集と同じ作り:
/// バナー + アイコン(端末から選ぶ)/ 表示名 / ハンドル / 誕生日 / 自己紹介 / 場所 / リンク。右上の「決定」で保存。
/// アカウントを作った直後にも、この画面を開く(同意の FOW → 登録 → ここ)。
class RasqProfileEditScreen extends ConsumerStatefulWidget {
  const RasqProfileEditScreen({super.key});
  @override
  ConsumerState<RasqProfileEditScreen> createState() => _RasqProfileEditScreenState();
}

class _RasqProfileEditScreenState extends ConsumerState<RasqProfileEditScreen> {
  static const maxLinks = 8;
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  final _birthday = TextEditingController();
  final List<(TextEditingController, TextEditingController)> _links = [];
  ({Uint8List bytes, String contentType})? _avatar;
  ({Uint8List bytes, String contentType})? _banner;
  bool _removeAvatar = false;
  bool _removeBanner = false;
  RasqAccount? _loaded;

  /// アカウントページの SNS タイル (D-270): 出す / 出さないを、アカウントごとに。変えたらすぐ保存する(「決定」を待たない)。
  List<RasqSnsLink>? _snsLinks;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSnsLinks());
  }

  Future<void> _loadSnsLinks() async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null || ref.read(orgateAccountProvider).value == null) return;
    try {
      final links = await api.mySnsLinks();
      if (mounted) setState(() => _snsLinks = links);
    } on OrgateException catch (_) {}
  }

  Future<void> _setSnsVisibility(RasqSnsLink link, SnsTileVisibility v) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null) return;
    try {
      final updated = await api.setSnsVisibility(link.accountKey, v);
      if (mounted) setState(() => _snsLinks = [for (final l in _snsLinks ?? const <RasqSnsLink>[]) l.accountKey == updated.accountKey ? updated : l]);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = rasqProfileMessage(e));
    }
  }

  /// 持ち主の確認の画面 (D-313)。戻ったら、確認済みの印を出し直す。
  Future<void> _openVerify(RasqSnsLink link) async {
    await context.push(Routes.rasqSnsVerify(link.accountKey));
    await _loadSnsLinks();
  }

  /// 「SNS のプロフィールにも、つないだアカウントを出す」(D-312)。変えたらすぐ保存する。
  Future<void> _setShowOnSns(bool on) async {
    try {
      await ref.read(orgateAccountProvider.notifier).setShowLinksOnSnsProfiles(on);
    } on OrgateException catch (e) {
      if (mounted) setState(() => _error = rasqProfileMessage(e));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _bio, _location, _birthday]) {
      c.dispose();
    }
    for (final l in _links) {
      l.$1.dispose();
      l.$2.dispose();
    }
    super.dispose();
  }

  void _fill(RasqAccount a) {
    if (_loaded != null) return;
    _loaded = a;
    _name.text = a.displayName;
    _handle.text = a.handle;
    _bio.text = a.bio;
    _location.text = a.location;
    _birthday.text = a.birthday;
    for (final l in a.links) {
      _links.add((TextEditingController(text: l.label), TextEditingController(text: l.url)));
    }
    if (_links.isEmpty) _links.add((TextEditingController(), TextEditingController()));
  }

  Future<void> _pick(bool banner) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final v = (bytes: await x.readAsBytes(), contentType: profileImageContentType(x.name, x.mimeType));
    setState(() {
      if (banner) {
        _banner = v;
        _removeBanner = false;
      } else {
        _avatar = v;
        _removeAvatar = false;
      }
    });
  }

  Future<void> _save() async {
    final before = _loaded;
    if (before == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final handle = _handle.text.trim().replaceFirst(RegExp('^@'), '');
      final links = [
        for (final l in _links)
          if (l.$1.text.trim().isNotEmpty || l.$2.text.trim().isNotEmpty) (label: l.$1.text.trim(), url: l.$2.text.trim()),
      ];
      final account = await ref.read(orgateAccountProvider.notifier).saveProfile(
            handle: handle.isEmpty || handle == before.handle ? null : handle,
            displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
            bio: _bio.text.trim(),
            location: _location.text.trim(),
            birthday: _birthday.text.trim(),
            links: links,
            avatar: _avatar,
            banner: _banner,
            removeAvatar: _removeAvatar,
            removeBanner: _removeBanner,
          );
      // 台帳(サイドバーの表示)の、そのアカウントの行にも写す(D-316: 台帳の「最初の」Central のアカウントではない)。
      final central = ref.read(rasqAccountsProvider).value?.centralRecord(account?.id);
      if (account != null && central != null) {
        await ref.read(rasqAccountsProvider.notifier).updateProfile(central.id, handle: account.handle, displayName: account.displayName, avatarUrl: account.avatarUrl);
      }
      if (mounted) context.pop();
    } on OrgateException catch (e) {
      setState(() => _error = rasqProfileMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    final l10n = context.l10n;
    final account = ref.watch(orgateAccountProvider).value;
    if (account != null) _fill(account);
    final a = _loaded;
    return Scaffold(
      appBar: RasqPageHeader(
        title: l10n.profileEditTitle,
        actions: [TextButton(key: const ValueKey('rasqProfile.save'), onPressed: _busy || a == null ? null : _save, child: Text(l10n.profileEditSave))],
      ),
      body: a == null
          ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(l10n.profileEditNotLoggedIn, style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)))
          : ListView(padding: const EdgeInsets.only(bottom: 48), children: [
              // 失敗は一番上に出す(下に置くと、長い画面では気づけない)。
              if (_error != null) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(_error!, key: const ValueKey('rasqProfile.error'), style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
                child: Row(children: [Text('@${a.handle}', style: RasqTypography.bodySmall), const SizedBox(width: 6), const RasqBrandIcon(size: 14), const SizedBox(width: 2), Text('RASQ', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant))]),
              ),
              Stack(children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: _banner != null
                      ? Image.memory(_banner!.bytes, fit: BoxFit.cover)
                      : (a.bannerUrl == null || _removeBanner ? ColoredBox(color: scheme.surfaceContainerHighest) : Image.network(webHtmlElementStrategy: rasqWebImageStrategy, a.bannerUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest))),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Row(children: [
                    if (_banner != null || (a.bannerUrl != null && !_removeBanner))
                      _RoundButton(key: const ValueKey('rasqProfile.banner.remove'), icon: Icons.delete_outline, tooltip: l10n.profileEditBannerRemove, onTap: () => setState(() {
                            _banner = null;
                            _removeBanner = true;
                          })),
                    const SizedBox(width: 6),
                    _RoundButton(key: const ValueKey('rasqProfile.banner.pick'), icon: Icons.add, tooltip: l10n.profileEditBannerPick, onTap: () => _pick(true)),
                  ]),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.all(RasqSpacing.page),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Stack(clipBehavior: Clip.none, children: [
                    _avatar != null
                        ? ClipOval(child: Image.memory(_avatar!.bytes, width: 64, height: 64, fit: BoxFit.cover))
                        : RasqAvatar(imageUrl: _removeAvatar ? null : a.avatarUrl, size: 64, fallbackLabel: a.displayName.isEmpty ? a.handle : a.displayName),
                    Positioned(right: -4, bottom: -4, child: _RoundButton(key: const ValueKey('rasqProfile.avatar.pick'), icon: Icons.add, tooltip: l10n.profileEditAvatarPick, onTap: () => _pick(false))),
                    if (_avatar != null || (a.avatarUrl != null && !_removeAvatar))
                      Positioned(left: -4, bottom: -4, child: _RoundButton(key: const ValueKey('rasqProfile.avatar.remove'), icon: Icons.delete_outline, tooltip: l10n.profileEditAvatarRemove, onTap: () => setState(() {
                            _avatar = null;
                            _removeAvatar = true;
                          }))),
                  ]),
                  const SizedBox(width: RasqSpacing.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RasqInput(key: const ValueKey('rasqProfile.name'), controller: _name, hintText: l10n.profileEditNameHint, suffix: IconButton(icon: const Icon(Icons.cancel, size: 18), onPressed: () => _name.clear())),
                      Row(children: [
                        const Icon(Icons.cake_outlined, size: 16),
                        const SizedBox(width: 4),
                        Expanded(child: RasqInput(key: const ValueKey('rasqProfile.birthday'), controller: _birthday, hintText: l10n.profileEditBirthdayHint, keyboardType: TextInputType.datetime)),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text(a.createdAt == null ? '' : RasqDateFormat.yearMonth(a.createdAt!), style: RasqTypography.bodySmall),
                      ]),
                    ]),
                  ),
                ]),
              ),
              _Labeled(l10n.profileEditHandleLabel, RasqInput(key: const ValueKey('rasqProfile.handle'), controller: _handle, hintText: 'handle')),
              _Labeled(l10n.profileEditBioLabel, RasqInput(key: const ValueKey('rasqProfile.bio'), controller: _bio, maxLines: 5, hintText: l10n.profileEditBioHint)),
              _Labeled(l10n.profileEditLocationLabel, RasqInput(key: const ValueKey('rasqProfile.location'), controller: _location, hintText: l10n.profileEditLocationLabel)),
              _Labeled(
                l10n.profileEditLinksLabel,
                Column(children: [
                  for (var i = 0; i < _links.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: scheme.onSurface), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.cancel),
                          tooltip: l10n.profileEditLinkRemove,
                          onPressed: () => setState(() {
                            final l = _links.removeAt(i);
                            l.$1.dispose();
                            l.$2.dispose();
                            if (_links.isEmpty) _links.add((TextEditingController(), TextEditingController()));
                          }),
                        ),
                        Expanded(
                          child: Column(children: [
                            TextField(key: ValueKey('rasqProfile.link.$i.label'), controller: _links[i].$1, decoration: InputDecoration(hintText: l10n.profileEditLinkCaptionHint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true)),
                            const SizedBox(height: 6),
                            TextField(key: ValueKey('rasqProfile.link.$i.url'), controller: _links[i].$2, decoration: InputDecoration(hintText: 'URL (https://…)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true), keyboardType: TextInputType.url),
                          ]),
                        ),
                        IconButton(icon: const Icon(Icons.add), tooltip: l10n.profileEditLinkAdd, onPressed: _links.length >= maxLinks ? null : () => setState(() => _links.add((TextEditingController(), TextEditingController())))),
                      ]),
                    ),
                ]),
              ),
              // ── アカウントページに出す SNS アカウント (D-270) ──
              if ((_snsLinks ?? const []).isNotEmpty)
                _Labeled(
                  l10n.profileEditSnsTilesLabel,
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        rasqDetail(context, l10n.profileEditSnsTilesCaption, l10n.profileEditSnsTilesCaptionDetail),
                        style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: RasqSpacing.sm),
                    for (final l in _snsLinks!)
                      Padding(
                        padding: const EdgeInsets.only(bottom: RasqSpacing.sm),
                        // 縦に積む(電話の幅では、タイルと 3 択が 1 行に入らない)。
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          SizedBox(height: 40, child: RasqSnsTileChip(tile: l.tile, dimmed: !l.visible)),
                          const SizedBox(height: RasqSpacing.xs),
                          SegmentedButton<SnsTileVisibility>(
                            key: ValueKey('rasqProfile.sns.${l.accountKey}'),
                            showSelectedIcon: false,
                            style: const ButtonStyle(visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            segments: [for (final v in SnsTileVisibility.values) ButtonSegment(value: v, label: Text(v == SnsTileVisibility.auto ? l10n.profileEditSnsTileAuto(l.autoVisible ? l10n.profileEditSnsTileShown : l10n.profileEditSnsTileHidden) : v.label, style: const TextStyle(fontSize: 12)))],
                            selected: {l.visibility},
                            onSelectionChanged: (s) => _setSnsVisibility(l, s.first),
                          ),
                          // 持ち主の確認 (D-313): 済んでいれば印、まだなら確認の画面へ。
                          if (l.tile.verified)
                            Padding(
                              key: ValueKey('rasqProfile.verified.${l.accountKey}'),
                              padding: const EdgeInsets.only(top: RasqSpacing.xs),
                              child: Row(children: [Icon(Icons.verified, size: 16, color: scheme.primary), const SizedBox(width: 4), Text(l10n.profileEditVerified(l.tile.verifiedLabel), style: RasqTypography.caption)]),
                            )
                          else if (rasqVerifiableKinds.contains(l.tile.kind))
                            TextButton.icon(
                              key: ValueKey('rasqProfile.verify.${l.accountKey}'),
                              style: const ButtonStyle(visualDensity: VisualDensity.compact),
                              onPressed: () => _openVerify(l),
                              icon: const Icon(Icons.verified_outlined, size: 16),
                              label: Text(l10n.profileEditVerify),
                            ),
                          // 投稿もアカウントページに出す (S-027): SNS のアクセストークンを ORGATE に預ける (D-399)。同意してから。
                          _SnsPostsSwitch(key: ValueKey('rasqProfile.snsPosts.${l.accountKey}'), accountKey: l.accountKey, onMessage: (m) => ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(m)))),
                        ]),
                      ),
                  ]),
                ),
              // ── SNS のプロフィールにも出す (D-312) ──
              _Labeled(
                l10n.profileEditShowOnSnsLabel,
                RasqSwitchListTile(
                  key: const ValueKey('rasqProfile.showOnSns'),
                  title: l10n.profileEditShowOnSnsTitle,
                  subtitle: l10n.profileEditShowOnSnsSubtitle,
                  detail: l10n.profileEditShowOnSnsDetail,
                  value: (account ?? a).showLinksOnSnsProfiles,
                  onChanged: _setShowOnSns,
                ),
              ),
              // ── Keybase (D-313) ──
              _Labeled(
                'Keybase',
                RasqListTile(
                  key: const ValueKey('rasqProfile.keybase'),
                  title: (account ?? a).keybase == null ? l10n.profileEditKeybaseConnect : 'Keybase: @${(account ?? a).keybase!.username}',
                  subtitle: (account ?? a).keybase == null ? l10n.profileEditKeybaseConnectSubtitle : l10n.profileEditKeybaseLinkedSubtitle,
                  leading: Icon((account ?? a).keybase == null ? Icons.key_outlined : Icons.verified, color: (account ?? a).keybase == null ? null : scheme.primary),
                  divider: false,
                  onTap: () async {
                    await context.push(Routes.rasqKeybase);
                    await _loadSnsLinks(); // Keybase の証明で確認済みになったリンクを出し直す
                  },
                ),
              ),
              RasqNotice(
                text: l10n.profileEditNotice,
                detail: l10n.profileEditNoticeDetail,
              ),
              if (_busy) const RasqLoading(),
            ]),
    );
  }
}

/// サーバーのエラーを、画面に出す 1 行へ。
String rasqProfileMessage(OrgateException e) => switch (e.code.code) {
      '409' => appL10n.profileEditErrorHandleTaken,
      '400' when e.message.contains('handle') => appL10n.profileEditErrorHandle,
      '400' when e.message.contains('birthday') => appL10n.profileEditErrorBirthday,
      '400' when e.message.contains('link') => appL10n.profileEditErrorLink,
      '400' when e.message.contains('image') => appL10n.profileEditErrorImage,
      '400' when e.message.contains('bio') => appL10n.profileEditErrorBio,
      '400' when e.message.contains('location') => appL10n.profileEditErrorLocation,
      _ => appL10n.profileEditErrorFailed(e.message),
    };

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(RasqSpacing.page, 0, RasqSpacing.page, RasqSpacing.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          child,
        ]),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: scheme.surface,
        shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 18))),
      ),
    );
  }
}

/// 「この SNS アカウントの投稿も、アカウントページに出す」(S-027)。
///
/// 入れると、**その SNS のアクセストークンを ORGATE-Server に預ける**ことになる(D-399。ORGATE が本人の公開の投稿を読み、
/// 投稿だけを Central のアカウントページへ渡す。トークンは ORGATE から出ない)。
/// 重い同意なので、何が起きるかを書いた確認を必ず挟む。切ると、預けたトークンと取ってきた投稿を消す。
class _SnsPostsSwitch extends ConsumerStatefulWidget {
  const _SnsPostsSwitch({super.key, required this.accountKey, required this.onMessage});
  final String accountKey;
  final void Function(String) onMessage;
  @override
  ConsumerState<_SnsPostsSwitch> createState() => _SnsPostsSwitchState();
}

class _SnsPostsSwitchState extends ConsumerState<_SnsPostsSwitch> {
  RasqVaultStatus? _status;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final st = await ref.read(rasqAccountPageApiProvider)?.vaultStatus(widget.accountKey);
      if (mounted) {
        setState(() {
          _status = st;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _set(bool on) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null || _busy) return;
    final l10n = context.l10n;
    if (!on) {
      setState(() => _busy = true);
      try {
        await api.withdrawToken(widget.accountKey);
        if (mounted) setState(() => _status = const RasqVaultStatus(hasToken: false));
        widget.onMessage(l10n.profileEditSnsPostsWithdrawn);
      } on OrgateException catch (e) {
        widget.onMessage(l10n.profileEditSnsPostsWithdrawFailed(e.message));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    // このアプリが持っている、その SNS アカウントのセッション(トークン)。
    final session = ref.read(sessionsProvider).value?.allSessions.where((s) => s.account.key == widget.accountKey).firstOrNull;
    if (session == null || session.token.isEmpty) return widget.onMessage(l10n.profileEditSnsPostsNoLogin);
    // Bluesky (D-423): 投稿はすべて公開で、ORGATE は Bluesky の公開の API(AppView)から読める。ログインの鍵(アプリパスワードで
    // 作ったセッション)は預けず、どのアカウントかを示す DID とハンドルだけを渡す。
    final bluesky = session.account.kind == SnsKind.bluesky;
    final did = blueskyDidOf(session);
    if (bluesky && did == null) return widget.onMessage(l10n.profileEditSnsPostsNoDid);
    final ok = bluesky
        ? await ref.read(overlayManagerProvider).showAlert(
            id: 'rasqProfile.snsPosts.consent',
            title: l10n.profileEditSnsPostsBlueskyConsentTitle,
            message: l10n.profileEditSnsPostsBlueskyConsentMessage('${session.account}'),
            confirmText: l10n.profileEditSnsPostsAgreeShow,
            cancelText: l10n.profileEditCancel,
          )
        : await ref.read(overlayManagerProvider).showAlert(
          id: 'rasqProfile.snsPosts.consent',
          title: l10n.profileEditSnsPostsTokenConsentTitle,
          // 規約案 02 第 4 項 (D-372): 誰でも見られる状態になること、サーバーが復号できる方式であることを先に。
          message: l10n.profileEditSnsPostsTokenConsentMessage('${session.account}'),
          confirmText: l10n.profileEditSnsPostsAgreeDeposit,
          cancelText: l10n.profileEditCancel,
        );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final st = await api.depositToken(widget.accountKey, bluesky ? jsonEncode({'did': did, 'handle': session.account.handle}) : session.token);
      if (mounted) setState(() => _status = st);
      widget.onMessage(st.lastError == null ? l10n.profileEditSnsPostsFetched(st.postCount) : l10n.profileEditSnsPostsFetchFailed('${st.lastError}'));
    } on OrgateException catch (e) {
      widget.onMessage(switch (e.code.code) {
        '501' => l10n.profileEditSnsPostsUnsupported,
        // Bluesky は持ち主の確認が済んだアカウントだけ (D-423 / ORGATE O-011)。
        '403' when bluesky => l10n.profileEditSnsPostsVerifyFirst,
        _ => l10n.profileEditSnsPostsDepositFailed(e.message),
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // サーバーがこの機能を閉じている / まだ分からない間は、出さない。
    if (!_loaded || _status == null) return const SizedBox.shrink();
    final st = _status!;
    final l10n = context.l10n;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RasqSwitchListTile(
        title: l10n.profileEditSnsPostsSwitchTitle,
        subtitle: st.hasToken
            ? (st.lastError != null ? l10n.profileEditSnsPostsFetchError('${st.lastError}') : l10n.profileEditSnsPostsCount(st.postCount))
            : (widget.accountKey.startsWith('bluesky:') ? l10n.profileEditSnsPostsBlueskySubtitle : l10n.profileEditSnsPostsTokenSubtitle),
        value: st.hasToken,
        onChanged: _busy ? null : _set,
      ),
      // 別の目的は別に選ぶ (D-373 / S-054、規約案 02 第 4 項 / PRIV-02)。預けているときだけ、既定はオフ。
      // Bluesky は鍵を預からないので、RASQ リストに使う鍵も無い(RASQ リストは鍵なしで読む。D-423)。
      if (st.hasToken && !widget.accountKey.startsWith('bluesky:'))
        RasqSwitchListTile(
          key: ValueKey('rasqProfile.snsPosts.collections.${widget.accountKey}'),
          title: l10n.profileEditSnsPostsCollectionsTitle,
          subtitle: l10n.profileEditSnsPostsCollectionsSubtitle,
          detail: l10n.profileEditSnsPostsCollectionsDetail,
          value: st.collectionsAllowed,
          onChanged: _busy ? null : _setCollections,
        ),
    ]);
  }

  Future<void> _setCollections(bool on) async {
    final api = ref.read(rasqAccountPageApiProvider);
    if (api == null) return;
    final l10n = context.l10n;
    if (on) {
      final ok = await ref.read(overlayManagerProvider).showAlert(
            id: 'rasqProfile.snsPosts.collections.consent',
            title: l10n.profileEditSnsPostsCollectionsConsentTitle,
            message: l10n.profileEditSnsPostsCollectionsConsentMessage,
            confirmText: l10n.profileEditSnsPostsCollectionsAgree,
            cancelText: l10n.profileEditCancel,
          );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      final st = await api.setCollectionsAllowed(widget.accountKey, on);
      if (mounted) setState(() => _status = st);
    } on OrgateException catch (e) {
      widget.onMessage(l10n.profileEditSnsPostsCollectionsFailed(e.message));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
