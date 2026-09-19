import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/providers.dart';
import '../../backend/orgate_client.dart';
import '../../backend/rasq_account.dart';
import '../../shell/headers.dart';

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
  bool _busy = false;
  String? _error;

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
      // 台帳(サイドバーの表示)にも写す。
      final central = ref.read(rasqAccountsProvider).value?.central;
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
    final account = ref.watch(orgateAccountProvider).value;
    if (account != null) _fill(account);
    final a = _loaded;
    return Scaffold(
      appBar: RasqPageHeader(
        title: 'プロフィールの更新',
        actions: [TextButton(key: const ValueKey('rasqProfile.save'), onPressed: _busy || a == null ? null : _save, child: const Text('決定'))],
      ),
      body: a == null
          ? Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text('RASQ アカウントにログインしていません。', style: RasqTypography.bodySmall.copyWith(color: scheme.onSurfaceVariant)))
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
                      : (a.bannerUrl == null || _removeBanner ? ColoredBox(color: scheme.surfaceContainerHighest) : Image.network(a.bannerUrl.toString(), fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: scheme.surfaceContainerHighest))),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Row(children: [
                    if (_banner != null || (a.bannerUrl != null && !_removeBanner))
                      _RoundButton(key: const ValueKey('rasqProfile.banner.remove'), icon: Icons.delete_outline, tooltip: 'バナーを外す', onTap: () => setState(() {
                            _banner = null;
                            _removeBanner = true;
                          })),
                    const SizedBox(width: 6),
                    _RoundButton(key: const ValueKey('rasqProfile.banner.pick'), icon: Icons.add, tooltip: 'バナーを選ぶ', onTap: () => _pick(true)),
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
                    Positioned(right: -4, bottom: -4, child: _RoundButton(key: const ValueKey('rasqProfile.avatar.pick'), icon: Icons.add, tooltip: 'アイコンを選ぶ', onTap: () => _pick(false))),
                    if (_avatar != null || (a.avatarUrl != null && !_removeAvatar))
                      Positioned(left: -4, bottom: -4, child: _RoundButton(key: const ValueKey('rasqProfile.avatar.remove'), icon: Icons.delete_outline, tooltip: 'アイコンを外す', onTap: () => setState(() {
                            _avatar = null;
                            _removeAvatar = true;
                          }))),
                  ]),
                  const SizedBox(width: RasqSpacing.md),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RasqInput(key: const ValueKey('rasqProfile.name'), controller: _name, hintText: '名前を入力..', suffix: IconButton(icon: const Icon(Icons.cancel, size: 18), onPressed: () => _name.clear())),
                      Row(children: [
                        const Icon(Icons.cake_outlined, size: 16),
                        const SizedBox(width: 4),
                        Expanded(child: RasqInput(key: const ValueKey('rasqProfile.birthday'), controller: _birthday, hintText: '誕生日 (YYYY-MM-DD / MM-DD)', keyboardType: TextInputType.datetime)),
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text(a.createdAt == null ? '' : '${a.createdAt!.year}年${a.createdAt!.month}月', style: RasqTypography.bodySmall),
                      ]),
                    ]),
                  ),
                ]),
              ),
              _Labeled('ハンドル(@ なし、a-z 0-9 _、3〜32 文字)', RasqInput(key: const ValueKey('rasqProfile.handle'), controller: _handle, hintText: 'handle')),
              _Labeled('自己紹介', RasqInput(key: const ValueKey('rasqProfile.bio'), controller: _bio, maxLines: 5, hintText: '自己紹介(500 文字まで)')),
              _Labeled('場所', RasqInput(key: const ValueKey('rasqProfile.location'), controller: _location, hintText: '場所')),
              _Labeled(
                'リンク',
                Column(children: [
                  for (var i = 0; i < _links.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(border: Border.all(color: scheme.onSurface), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
                      child: Row(children: [
                        IconButton(
                          icon: const Icon(Icons.cancel),
                          tooltip: '削除',
                          onPressed: () => setState(() {
                            final l = _links.removeAt(i);
                            l.$1.dispose();
                            l.$2.dispose();
                            if (_links.isEmpty) _links.add((TextEditingController(), TextEditingController()));
                          }),
                        ),
                        Expanded(
                          child: Column(children: [
                            TextField(key: ValueKey('rasqProfile.link.$i.label'), controller: _links[i].$1, decoration: InputDecoration(hintText: 'キャプション', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true)),
                            const SizedBox(height: 6),
                            TextField(key: ValueKey('rasqProfile.link.$i.url'), controller: _links[i].$2, decoration: InputDecoration(hintText: 'URL (https://…)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true), keyboardType: TextInputType.url),
                          ]),
                        ),
                        IconButton(icon: const Icon(Icons.add), tooltip: '追加', onPressed: _links.length >= maxLinks ? null : () => setState(() => _links.add((TextEditingController(), TextEditingController())))),
                      ]),
                    ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page),
                child: Text('プロフィールは、RASQ の公開ページとストアのレビューに出ます。画像はサーバーで縮めて保存し直します(位置情報などは残りません)。メールアドレスとパスワードは「セキュリティ」から。', style: RasqTypography.caption.copyWith(color: scheme.onSurfaceVariant)),
              ),
              if (_busy) const RasqLoading(),
            ]),
    );
  }
}

/// サーバーのエラーを、画面に出す 1 行へ。
String rasqProfileMessage(OrgateException e) => switch (e.code.code) {
      '409' => 'そのハンドルは使われています',
      '400' when e.message.contains('handle') => 'ハンドルは 3〜32 文字の a-z 0-9 _ にしてください',
      '400' when e.message.contains('birthday') => '誕生日は YYYY-MM-DD か MM-DD の形で入れてください',
      '400' when e.message.contains('link') => 'リンクは、キャプション(40 文字まで)と http(s) の URL の組にしてください(8 組まで)',
      '400' when e.message.contains('image') => 'その画像は使えません(PNG / JPEG / WebP / GIF、8 MiB まで)',
      '400' when e.message.contains('bio') => '自己紹介は 500 文字までです',
      '400' when e.message.contains('location') => '場所は 60 文字までです',
      _ => '更新に失敗しました: ${e.message}',
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
