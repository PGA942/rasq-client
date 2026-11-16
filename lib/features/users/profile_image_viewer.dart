import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rasq_design/rasq_design.dart';
import '../../l10n/l10n.dart';

import '../home/plugin_actions.dart';
import '../theme/icon_theme/icon_theme_backdrop.dart' show IconThemeBackdrop, themeColor;
import '../theme/icon_theme/icon_theme_reader.dart' show iconThemeProvider;
import '../media/viewer_plugin_overlay.dart';

/// プロフィールのアイコン / バナーの全画面表示 (D-177)。黒背景 + ピンチズーム、
/// タップでヘッダーの表示切り替え。投稿のビューワー(`MediaViewerScreen`)と違い本文や投稿のアクションは無いが、
/// 全画面表示プラグイン(`viewer.overlay`)は同じく重なり (D-178)、**全画面アクションバー**(プラグインのトグル)も
/// ヘッダーの右に出る (D-246。投稿が無いので SNS のアクションボタンは並ばない)。
class ProfileImageViewerScreen extends ConsumerStatefulWidget {
  const ProfileImageViewerScreen({super.key, required this.url, this.title});
  final Uri url;
  final String? title;

  @override
  ConsumerState<ProfileImageViewerScreen> createState() => _ProfileImageViewerScreenState();
}

class _ProfileImageViewerScreenState extends ConsumerState<ProfileImageViewerScreen> {
  bool _chrome = true;
  late final ViewerPluginOverlays _overlays = ViewerPluginOverlays(ref, onChanged: () {
    if (mounted) setState(() {});
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _overlays.ask(0, widget.url));
  }

  @override
  void dispose() {
    _overlays.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // アイコンに埋め込まれたテーマ (D-580): 読めたら黒の代わりにテーマの背景・パーティクル・枠を敷き、アイコンはテーマの
    // フレーム(予約ビット: 角丸 / 丸)で、文字はテーマの文字色で。読めない画像はこれまでどおり。
    final spec = ref.watch(iconThemeProvider(widget.url.toString())).value;
    final fg = spec == null ? Colors.white : themeColor(spec.basic.text);
    Widget picture = Image.network(webHtmlElementStrategy: rasqWebImageStrategy, widget.url.toString(), fit: BoxFit.contain, errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: fg, size: 48));
    if (spec != null) {
      final rounded = spec.basic.hints?.roundedFrame ?? true;
      final image = picture;
      picture = LayoutBuilder(builder: (context, c) {
        final side = math.min(280.0, c.biggest.shortestSide * 0.62);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            key: const ValueKey('profileImage.themed'),
            width: side,
            height: side,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(rounded ? side * 0.2 : side / 2), boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 10))]),
            child: ClipRRect(borderRadius: BorderRadius.circular(rounded ? side * 0.2 : side / 2), child: SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: image))),
          ),
          if (spec.ext?.url case final url?)
            Padding(
              padding: const EdgeInsets.only(top: RasqSpacing.md),
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(8)),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Text(context.l10n.iconThemePluginUrlNote(url), key: const ValueKey('profileImage.pluginNote'), style: RasqTypography.caption.copyWith(color: Colors.white))),
              ),
            ),
        ]);
      });
    }
    final content = Stack(children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _chrome = !_chrome),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: _overlays.wrap(0, picture),
            ),
          ),
        ),
        if (_chrome)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(RasqSpacing.sm),
              child: Row(children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                  child: RasqIconButton(icon: Icons.arrow_back_ios_new, size: 18, color: Colors.white, onPressed: () => Navigator.of(context).maybePop(), tooltip: context.l10n.usersImageViewerBack),
                ),
                const SizedBox(width: RasqSpacing.sm),
                Expanded(child: Text(widget.title ?? '', style: RasqTypography.title.copyWith(color: fg), overflow: TextOverflow.ellipsis)),
                // 全画面アクションバー (D-246): 全画面表示プラグインのトグル。狭ければ横スクロール(右寄せ)。
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final a in ref.watch(viewerPluginActionsProvider)) ...[
                        const SizedBox(width: 2),
                        if (ref.watch(viewerOverlayPluginsProvider).any((p) => p.id == a.plugin.id)) // switch を切ったものは出さない (契約 v0.14)
                          ViewerPluginToggle(
                            pluginId: a.plugin.id,
                            label: a.decl.label,
                            iconName: a.decl.icon,
                            // ON / OFF はこの全画面限り(契約 v0.14 temp)。長押しで「次からも自動でオン / オフ」。
                            enabled: _overlays.isOn(a.plugin.id),
                            status: _overlays.statusOf(0, a.plugin.id),
                            onPressed: () => _overlays.toggle(a.plugin.id, 0, widget.url),
                            onLongPress: (anchor) => showActionTempMenu(ref, anchor: anchor, action: a),
                          ),
                      ],
                    ]),
                  ),
                ),
              ]),
            ),
          ),
      ]);
    return Scaffold(
      backgroundColor: spec == null ? Colors.black : Colors.transparent,
      // テーマの背景は全体の下。押す / なぞるとパーティクルが出る(ヘッダーの切り替えもそのまま)。
      body: spec == null ? content : IconThemeBackdrop(key: const ValueKey('profileImage.backdrop'), spec: spec, child: content),
    );
  }
}
