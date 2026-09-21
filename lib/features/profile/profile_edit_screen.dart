import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';
import 'package:rasq_models/rasq_models.dart';
import 'package:rasq_plugin_api/rasq_plugin_api.dart';

import '../../app/providers.dart';
import '../../shell/headers.dart';
import '../users/user_providers.dart';

/// プロフィールの更新 (ワイヤーフレーム): ＜ プロフィールの更新 決定 / アカウント行 /
/// バナー(📷) / アイコン(📷)+名前+誕生日+登録 / 自己紹介 / 場所 / リンク(キャプション+URL, ＋/✕).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _location = TextEditingController();
  final _birthday = TextEditingController();
  final List<(TextEditingController, TextEditingController)> _links = [];
  ({Uint8List bytes, String name, String? mime})? _avatar;
  ({Uint8List bytes, String name, String? mime})? _banner;
  UserProfile? _loaded;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _bio, _location, _birthday]) {
      c.dispose();
    }
    for (final l in _links) {
      l.$1.dispose();
      l.$2.dispose();
    }
    super.dispose();
  }

  void _fill(UserProfile p) {
    if (_loaded != null) return;
    _loaded = p;
    _name.text = p.summary.displayName;
    _bio.text = p.description ?? '';
    _location.text = p.location ?? '';
    _birthday.text = p.birthday ?? '';
    for (final f in p.fields) {
      _links.add((TextEditingController(text: f.name), TextEditingController(text: f.value)));
    }
    if (_links.isEmpty) _links.add((TextEditingController(), TextEditingController()));
  }

  Future<void> _pick(bool banner) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (x == null) return;
    final v = (bytes: await x.readAsBytes(), name: x.name, mime: x.mimeType);
    setState(() => banner ? _banner = v : _avatar = v);
  }

  Future<void> _save() async {
    final s = ref.read(currentSnsSessionProvider);
    if (s == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      String? avatarId, bannerId;
      if (_avatar != null) avatarId = (await s.uploadMedia(_avatar!.bytes, _avatar!.name, mimeType: _avatar!.mime)).id;
      if (_banner != null) bannerId = (await s.uploadMedia(_banner!.bytes, _banner!.name, mimeType: _banner!.mime)).id;
      await s.updateProfile(ProfileUpdate(
        displayName: _name.text.trim(),
        description: _bio.text,
        location: _location.text.trim(),
        birthday: _birthday.text.trim(),
        fields: [for (final l in _links) if (l.$1.text.trim().isNotEmpty || l.$2.text.trim().isNotEmpty) (name: l.$1.text.trim(), value: l.$2.text.trim())],
        avatarMediaId: avatarId,
        bannerMediaId: bannerId,
      ));
      final me = ref.read(currentUserProvider);
      ref.invalidate(userProfileProvider((id: me.id, account: null)));
      if (mounted) context.pop();
    } on SnsApiException catch (e) {
      setState(() => _error = '${e.code.display}${e.code.message == null ? '' : '\n${e.code.message}'}');
    } catch (e) {
      setState(() => _error = '更新に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider);
    final profile = ref.watch(userProfileProvider((id: me.id, account: null)));
    final scheme = Theme.of(context).colorScheme;
    final tokens = RasqTokens.of(context);
    profile.whenData(_fill);
    return Scaffold(
      appBar: RasqPageHeader(
        title: 'プロフィールの更新',
        actions: [TextButton(onPressed: _busy || _loaded == null ? null : _save, child: const Text('決定'))],
        onMore: () {},
      ),
      body: profile.when(
        loading: () => const RasqLoading(),
        error: (e, _) => RasqErrorView(code: e is SnsApiException ? e.code : ErrorCode.internalServerError.copyWith(message: '$e'), onRetry: () => ref.invalidate(userProfileProvider((id: me.id, account: null))), retryLabel: '再読み込み'),
        data: (p) => ListView(padding: const EdgeInsets.only(bottom: 48), children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
            child: Row(children: [Text('@${me.handle}', style: RasqTypography.bodySmall), const SizedBox(width: 4), RasqSnsPill(account: me.account)]),
          ),
          Stack(children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: _banner != null
                  ? Image.memory(_banner!.bytes, fit: BoxFit.cover)
                  : (p.bannerUrl == null ? ColoredBox(color: scheme.surfaceContainerHighest) : Image.network(webHtmlElementStrategy: rasqWebImageStrategy, p.bannerUrl.toString(), fit: BoxFit.cover)),
            ),
            Positioned(right: 8, bottom: 8, child: _PickButton(onTap: () => _pick(true))),
          ]),
          Padding(
            padding: const EdgeInsets.all(RasqSpacing.page),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(children: [
                _avatar != null ? ClipOval(child: Image.memory(_avatar!.bytes, width: 64, height: 64, fit: BoxFit.cover)) : RasqAvatar(imageUrl: p.summary.avatarUrl, size: 64, fallbackLabel: p.summary.displayName),
                Positioned(right: -4, bottom: -4, child: _PickButton(onTap: () => _pick(false))),
              ]),
              const SizedBox(width: RasqSpacing.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  RasqInput(controller: _name, hintText: '名前を入力..', suffix: IconButton(icon: const Icon(Icons.cancel, size: 18), onPressed: () => _name.clear())),
                  Row(children: [
                    const Icon(Icons.cake_outlined, size: 16),
                    const SizedBox(width: 4),
                    Expanded(child: RasqInput(controller: _birthday, hintText: '誕生日 (YYYY-MM-DD)', keyboardType: TextInputType.datetime)),
                    const SizedBox(width: 12),
                    const Icon(Icons.calendar_today_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text(p.createdAt == null ? '' : '${p.createdAt!.year}年${p.createdAt!.month}月', style: RasqTypography.bodySmall),
                  ]),
                ]),
              ),
            ]),
          ),
          _Labeled('自己紹介', RasqInput(controller: _bio, maxLines: 5, hintText: '自己紹介')),
          _Labeled('場所', RasqInput(controller: _location, hintText: '場所')),
          _Labeled(
            'リンク',
            Column(children: [
              for (var i = 0; i < _links.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(border: Border.all(color: scheme.onSurface), borderRadius: BorderRadius.circular(RasqSizes.radiusMd)),
                  child: Row(children: [
                    IconButton(icon: const Icon(Icons.cancel), onPressed: () => setState(() => _links.removeAt(i)), tooltip: '削除'),
                    Expanded(child: Column(children: [
                      TextField(controller: _links[i].$1, decoration: InputDecoration(hintText: 'キャプション', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true)),
                      const SizedBox(height: 6),
                      TextField(controller: _links[i].$2, decoration: InputDecoration(hintText: 'URL', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), isDense: true), keyboardType: TextInputType.url),
                    ])),
                    IconButton(icon: const Icon(Icons.add), onPressed: _links.length >= 4 ? null : () => setState(() => _links.add((TextEditingController(), TextEditingController()))), tooltip: '追加'),
                  ]),
                ),
            ]),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.all(RasqSpacing.page), child: Text(_error!, style: RasqTypography.bodySmall.copyWith(color: tokens.danger))),
          if (_busy) const RasqLoading(),
        ]),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.child);
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
        padding: const EdgeInsets.symmetric(horizontal: RasqSpacing.page, vertical: RasqSpacing.sm),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 64, child: Padding(padding: const EdgeInsets.only(top: 12), child: Text(label, style: RasqTypography.bodySmall.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)))),
          Expanded(child: child),
        ]),
      );
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        child: IconButton(icon: const Icon(Icons.add_photo_alternate_outlined, size: 18), onPressed: onTap, tooltip: '画像を選択', constraints: const BoxConstraints(minWidth: 36, minHeight: 36)),
      );
}
