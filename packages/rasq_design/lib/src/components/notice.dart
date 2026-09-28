import 'package:flutter/material.dart';

import '../theme/rasq_tokens_extension.dart';
import '../tokens/colors.dart';
import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../tokens/typography.dart';

/// 開発者モード (D-362): 公開テスト向けに画面の文面を短くし、細かい説明(仕組み・保存先・送る値の形など)は
/// 開発者モードのときだけ出す。アプリの上で [RasqDeveloperMode] を置き、部品は [RasqDeveloperMode.of] で読む。
class RasqDeveloperMode extends InheritedWidget {
  const RasqDeveloperMode({super.key, required this.enabled, required super.child});

  final bool enabled;

  /// 置いていなければ false(ふつうの表示)。
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<RasqDeveloperMode>()?.enabled ?? false;

  @override
  bool updateShouldNotify(RasqDeveloperMode oldWidget) => oldWidget.enabled != enabled;
}

/// ふつうは [simple]、開発者モードでは [detail](無ければ [simple])。
String rasqDetail(BuildContext context, String simple, String? detail) => detail != null && RasqDeveloperMode.of(context) ? detail : simple;

enum RasqNoticeKind {
  /// 水色の ℹ️(補足・ヒント)。
  info,

  /// 赤の ⚠️(危険・取り返しのつかないこと)。
  warning,
}

/// 水色(ℹ️)/ 赤(⚠️)の囲みの注意書き (D-362)。「トレンドの指向性/刺激性」の警告と同じ形。
/// [detail] は開発者モードのときだけ、本文の下に小さく出す。
class RasqNotice extends StatelessWidget {
  const RasqNotice({super.key, required this.text, this.kind = RasqNoticeKind.info, this.title, this.detail, this.margin, this.action});

  const RasqNotice.warning({super.key, required this.text, this.title, this.detail, this.margin, this.action}) : kind = RasqNoticeKind.warning;

  final String text;
  final RasqNoticeKind kind;
  final String? title;
  final String? detail;

  /// 既定はページの左右の余白 + 上の少しの余白。
  final EdgeInsetsGeometry? margin;

  /// 右下に出すボタンなど(任意)。
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = kind == RasqNoticeKind.warning ? RasqTokens.of(context).danger : RasqColors.info;
    final dev = detail != null && RasqDeveloperMode.of(context);
    return Container(
      margin: margin ?? const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.sm, RasqSpacing.page, RasqSpacing.xs),
      padding: const EdgeInsets.all(RasqSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(RasqSizes.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(kind == RasqNoticeKind.warning ? Icons.warning_amber_rounded : Icons.info_outline_rounded, color: color, size: 18),
        const SizedBox(width: RasqSpacing.xs),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (title != null) Text(title!, style: RasqTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
            Text(text, style: RasqTypography.caption.copyWith(color: color)),
            if (dev)
              Padding(
                padding: const EdgeInsets.only(top: RasqSpacing.xs),
                child: Text(detail!, key: const ValueKey('rasq.notice.detail'), style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)),
              ),
            if (action != null) Align(alignment: Alignment.centerRight, child: action!),
          ]),
        ),
      ]),
    );
  }
}

/// 説明文(灰色の小さな字)。ふつうは [text]、開発者モードでは [detail]。[devOnly] なら開発者モードのときだけ出す。
class RasqCaption extends StatelessWidget {
  const RasqCaption(this.text, {super.key, this.detail, this.devOnly = false, this.padding});

  final String text;
  final String? detail;
  final bool devOnly;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final dev = RasqDeveloperMode.of(context);
    if (devOnly && !dev) return const SizedBox.shrink();
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(RasqSpacing.page, RasqSpacing.xs, RasqSpacing.page, RasqSpacing.sm),
      child: Text(dev && detail != null ? detail! : text, style: RasqTypography.caption.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    );
  }
}
