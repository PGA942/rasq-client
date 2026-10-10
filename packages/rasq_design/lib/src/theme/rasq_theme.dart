import 'package:flutter/material.dart';

import '../tokens/colors.dart';
import '../tokens/sizes.dart';
import '../tokens/typography.dart';
import 'rasq_tokens_extension.dart';

/// Builds the Material theme from RASQ tokens.
abstract final class RasqTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: RasqColors.sub,
      onPrimary: RasqColors.white,
      primaryContainer: isDark ? RasqColors.navy : RasqColors.lightBlue,
      onPrimaryContainer: isDark ? RasqColors.white : RasqColors.navy,
      secondary: RasqColors.main,
      onSecondary: RasqColors.navy,
      secondaryContainer: isDark ? const Color(0xFF0B4F55) : const Color(0xFFCCFBFE),
      onSecondaryContainer: isDark ? RasqColors.white : RasqColors.navy,
      tertiary: RasqColors.accent,
      onTertiary: RasqColors.white,
      error: RasqColors.danger,
      onError: RasqColors.white,
      surface: isDark ? const Color(0xFF0E0E10) : RasqColors.white,
      onSurface: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF111111),
      onSurfaceVariant: isDark ? const Color(0xFF9AA0A6) : const Color(0xFF5F6368),
      outline: isDark ? const Color(0xFF3A3A3C) : RasqColors.gray,
      outlineVariant: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE0E0E0),
      surfaceContainerHighest: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEDEEF0),
      surfaceContainerHigh: isDark ? const Color(0xFF242426) : const Color(0xFFF1F2F4),
      surfaceContainer: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF4F5F7),
      surfaceContainerLow: isDark ? const Color(0xFF161618) : const Color(0xFFF8F9FA),
      surfaceContainerLowest: isDark ? const Color(0xFF0A0A0B) : RasqColors.white,
      inverseSurface: isDark ? const Color(0xFFF2F2F7) : const Color(0xFF111111),
      onInverseSurface: isDark ? const Color(0xFF111111) : RasqColors.white,
      inversePrimary: RasqColors.lightBlue,
      shadow: RasqColors.black,
      scrim: RasqColors.black,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
    // ボタン(FilledButton / OutlinedButton)の文言の書体は、ほかの文字(labelLarge)と同じ名前で。fontFamily を空のままにすると
    // エンジンの既定の書体で描かれ、flutter_tester ではテストのフォントに落ちて日本語が □ になる(D-458 のスクリーンショット)。
    final button = RasqTypography.button.copyWith(fontFamily: base.textTheme.labelLarge?.fontFamily, fontFamilyFallback: base.textTheme.labelLarge?.fontFamilyFallback);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: RasqTypography.title.copyWith(color: scheme.onSurface),
        toolbarHeight: RasqSizes.headerHeight,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: RasqTypography.tab,
        unselectedLabelStyle: RasqTypography.tab.copyWith(fontWeight: FontWeight.w500),
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: RasqSizes.navHeight,
        backgroundColor: scheme.surface,
        indicatorColor: Colors.transparent,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => RasqColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? RasqColors.inVc : scheme.outline,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          textStyle: button,
          shape: const StadiumBorder(),
          minimumSize: const Size(64, RasqSizes.minTap - 8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: button,
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.primary),
          minimumSize: const Size(64, RasqSizes.minTap - 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        border: UnderlineInputBorder(borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: scheme.primary, width: 1.5)),
        hintStyle: RasqTypography.body.copyWith(color: scheme.onSurfaceVariant),
      ),
      extensions: [isDark ? RasqTokens.dark : RasqTokens.light],
    );
  }
}
