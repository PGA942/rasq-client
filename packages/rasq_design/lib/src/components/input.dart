import 'package:flutter/material.dart';

import '../tokens/sizes.dart';
import '../tokens/spacing.dart';
import '../l10n/design_l10n.dart';

/// Underlined text input (L2 atomic `Input`). Prediction hooks (正規表現/BERT)
/// are attached by the host through [onChanged]; this widget is dumb.
class RasqInput extends StatelessWidget {
  const RasqInput({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.obscureText = false,
    this.suffix,
    this.prefix,
    this.maxLines = 1,
    this.keyboardType,
    this.autofocus = false,
    this.enabled = true,
    this.focusNode,
    this.textInputAction,
  });

  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final Widget? suffix;
  final Widget? prefix;
  final int? maxLines;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool enabled;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        obscureText: obscureText,
        maxLines: obscureText ? 1 : maxLines,
        keyboardType: keyboardType,
        autofocus: autofocus,
        enabled: enabled,
        textInputAction: textInputAction,
        decoration: InputDecoration(hintText: hintText, suffixIcon: suffix, prefixIcon: prefix, contentPadding: const EdgeInsets.symmetric(vertical: RasqSpacing.md)),
      );
}

/// Rounded search bar with leading dropdown chevron (検索ヘッダー / 各リストの検索).
/// Sort/filter component attaches via [onDropdownTap].
class RasqSearchBar extends StatelessWidget {
  const RasqSearchBar({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onDropdownTap,
    this.onTap,
    this.readOnly = false,
    this.trailing,
    this.height = RasqSizes.searchBarHeight,
    this.focusNode,
  });

  final TextEditingController? controller;

  /// フォーカス連動 UI(検索フィルタ行 D-021)用。
  final FocusNode? focusNode;
  /// 入力欄の薄い字。省略すると「検索」(表示の言語で、D-484)。
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Tap on the leading `v` (opens sort/filter dropdown).
  final VoidCallback? onDropdownTap;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? trailing;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      decoration: BoxDecoration(border: Border.all(color: scheme.onSurface, width: 1.2), borderRadius: BorderRadius.circular(height)),
      child: Row(children: [
        SizedBox(
          width: RasqSizes.minTap,
          height: height,
          child: InkWell(
            onTap: onDropdownTap,
            customBorder: const StadiumBorder(),
            child: Icon(Icons.keyboard_arrow_down, size: 20, color: scheme.onSurface),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            onTap: onTap,
            readOnly: readOnly,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
            decoration: InputDecoration(
              hintText: hintText ?? context.designL10n.designSearchHint,
              isDense: true,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              suffixIcon: trailing ?? Icon(Icons.search, size: 16, color: scheme.onSurface),
              suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 16),
            ),
          ),
        ),
        const SizedBox(width: RasqSpacing.sm),
      ]),
    );
  }
}
