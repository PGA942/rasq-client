import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rasq_design/rasq_design.dart';

import '../../app/navigation.dart';
import '../../l10n/l10n.dart';

/// プロフィールの画像(アイコン / ヘッダー)1 枚。
typedef ProfileImagePick = ({Uint8List bytes, String name, String? mime});

/// 画像を選ぶ口(テストで差し替える)。null = やめた。
final profileImagePickerProvider = Provider<Future<ProfileImagePick?> Function()>((ref) => () async {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x == null) return null;
      return (bytes: await x.readAsBytes(), name: x.name, mime: x.mimeType);
    });

/// 選んだ画像を全画面の加工画面(pro_image_editor、投稿の添付と同じ)で開く口(テストで差し替える)。null = やめた。
final profileImageEditorProvider = Provider<Future<ProfileImagePick?> Function(BuildContext, ProfileImagePick)>((ref) => (context, img) async {
      final r = await context.pushProMediaEditor(bytes: img.bytes, name: img.name, mimeType: img.mime ?? 'image/jpeg');
      if (r == null) return null;
      return (bytes: r.bytes, name: r.name ?? img.name, mime: r.mimeType);
    });

/// アイコン / ヘッダーの変更 (D-587): 画像を選ぶ → 全画面の加工画面 → 決めた画像。どちらかでやめたら null(何も変えない)。
Future<ProfileImagePick?> pickAndEditProfileImage(WidgetRef ref, BuildContext context) async {
  final img = await ref.read(profileImagePickerProvider)();
  if (img == null || !context.mounted) return null;
  return ref.read(profileImageEditorProvider)(context, img);
}

/// プロフィールの編集の、ヘッダーのすぐ下の段 (D-587): 左に「アイコンの変更」「アイコンにテーマを埋め込む」、右上に大きいアイコン
/// (上半分はヘッダーにかかる)。名前・誕生日の欄はこの段の下。
class ProfileEditAvatarRow extends StatelessWidget {
  const ProfileEditAvatarRow({super.key, required this.keyPrefix, required this.avatar, required this.onChange, required this.onEmbedTheme, this.onRemove, this.removeTooltip});

  /// ボタンの鍵の頭(`rasqProfile` / `profileEdit`)。
  final String keyPrefix;

  /// [avatarSize] の丸いアイコン。
  final Widget avatar;
  final VoidCallback onChange;
  final VoidCallback onEmbedTheme;

  /// アイコンを外す(RASQ アカウントだけ)。null = 出さない。
  final VoidCallback? onRemove;
  final String? removeTooltip;

  static const avatarSize = 96.0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final picture = Stack(clipBehavior: Clip.none, children: [
      DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.surface, width: 3)),
        child: avatar,
      ),
      if (onRemove != null)
        Positioned(
          left: -2,
          bottom: 2,
          child: Tooltip(
            message: removeTooltip ?? '',
            child: Material(
              color: scheme.surface,
              shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
              child: InkWell(
                key: ValueKey('$keyPrefix.avatar.remove'),
                customBorder: const CircleBorder(),
                onTap: onRemove,
                child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.delete_outline, size: 18)),
              ),
            ),
          ),
        ),
    ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, 0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Wrap(spacing: RasqSpacing.sm, runSpacing: RasqSpacing.sm, children: [
            FilledButton.tonalIcon(
              key: ValueKey('$keyPrefix.avatar.change'),
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(l.profileEditAvatarChange),
              onPressed: onChange,
            ),
            OutlinedButton.icon(
              key: ValueKey('$keyPrefix.avatar.theme'),
              icon: const Icon(Icons.palette_outlined, size: 18),
              label: Text(l.profileEditAvatarEmbedTheme),
              onPressed: onEmbedTheme,
            ),
          ]),
        ),
        const SizedBox(width: RasqSpacing.md),
        // 下半分だけがこの段の高さ。上半分はヘッダーの上に重なる(押せるのは下半分 = 外すボタンのある所)。
        SizedBox(
          width: avatarSize + 6,
          height: avatarSize / 2 + 6,
          child: OverflowBox(
            minHeight: avatarSize + 6,
            maxHeight: avatarSize + 6,
            alignment: Alignment.bottomCenter,
            child: KeyedSubtree(key: ValueKey('$keyPrefix.avatar'), child: picture),
          ),
        ),
      ]),
    );
  }
}

/// ヘッダーの画像: 押すと画像を選んで全画面の加工画面へ (D-587)。右下の小さいボタン(テーマ / 外す)はそのまま上に置ける。
class ProfileEditBanner extends StatelessWidget {
  const ProfileEditBanner({super.key, required this.keyPrefix, required this.image, required this.onChange, this.buttons = const []});
  final String keyPrefix;
  final Widget image;
  final VoidCallback onChange;
  final List<Widget> buttons;

  @override
  Widget build(BuildContext context) => Stack(children: [
        Semantics(
          button: true,
          label: context.l10n.profileEditBannerChange,
          child: GestureDetector(
            key: ValueKey('$keyPrefix.banner.change'),
            behavior: HitTestBehavior.opaque,
            onTap: onChange,
            child: SizedBox(height: 120, width: double.infinity, child: image),
          ),
        ),
        // 右下は大きいアイコンが重なるので、左下に。
        if (buttons.isNotEmpty) Positioned(left: 8, bottom: 8, child: Row(children: [for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(width: 6), b]])),
      ]);
}
