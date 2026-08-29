import 'package:flutter/material.dart';

/// Design tokens ported from the Hishab prototype (Open Design).
///
/// OKLCH values from the prototype were converted to sRGB; the `color-mix()`
/// results are precomputed so no stray hex lives outside this file.
abstract final class AppColors {
  // Surfaces.
  static const bg = Color(0xFFEFE7D2); // warm parchment cream
  static const bgDeep = Color(0xFFE8DCC8); // gradient end
  static const surface = Color(0xFFF5F0E6); // solid card fill
  static const group = Color(0xFFE6DCCA); // group header cream

  // Ink.
  static const fg = Color(0xFF1A1612); // near-black warm
  static const muted = Color(0xFF9A8F7A); // warm grey-brown

  // Accent (lime-chartreuse).
  static const accent = Color(0xFFA8CC00);
  static const accentInk = Color(0xFF485900); // legible lime on cream
  static const hairline = Color(0x66A8CC00); // accent 40%

  // Danger.
  static const danger = Color(0xFFBE222A);

  // Glass fills (white-tinted cream at the prototype's alphas).
  static const glassFill = Color(0x8CFFFCF5); // rgba(255,252,245,.55)
  static const glassFillStrong = Color(0xB3FFFCF5); // caption .70
  static const navFill = Color(0x99FFFCF5); // bottom nav .60
  static const sheetFill = Color(0xEBFAF6EE); // rgba(250,246,238,.92)
  static const dialogFill = Color(0xF2FAF6EE); // dialog .95
  static const snackFill = Color(0xEB1A1612); // dark snack .92
  static const barrier = Color(0x591A1612); // fg 35%

  // Rims & shadows.
  static const border = Color(0xC0FFFFFF); // bright white glass rim
  static const warmShadow = Color(0x26B4A078); // 0 4 24 rgba(180,160,120,.15)
  static const accentShadow = Color(0x4DA8CC00); // lime glow (btn/mic)
}

/// Category palette (OKLCH -> sRGB) and the darker icon tints
/// (`color-mix(in oklch, var(--cat) 68%, black)` in the prototype).
abstract final class CategoryPalette {
  static const food = Color(0xFFEA6F2F);
  static const foodInk = Color(0xFF8B3F18);
  static const transport = Color(0xFF2582DC);
  static const transportInk = Color(0xFF114B82);
  static const utilities = Color(0xFF7F59CB);
  static const utilitiesInk = Color(0xFF493278);
  static const rent = Color(0xFF009084);
  static const rentInk = Color(0xFF00544C);
  static const medicine = Color(0xFFD02B31);
  static const medicineInk = Color(0xFF7B1519);
  static const education = Color(0xFF0EA053);
  static const educationInk = Color(0xFF055D2E);
  static const entertainment = Color(0xFFD69C03);
  static const entertainmentInk = Color(0xFF7F5B01);
  static const mobile = Color(0xFF966136);
  static const mobileInk = Color(0xFF57371C);
}

abstract final class AppTheme {
  static const fontFamily = 'IBM Plex Mono';

  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.accentInk,
      onPrimary: AppColors.fg,
      secondary: AppColors.accent,
      onSecondary: AppColors.fg,
      surface: AppColors.bg,
      onSurface: AppColors.fg,
      surfaceContainerHighest: AppColors.group,
      onSurfaceVariant: AppColors.muted,
      error: AppColors.danger,
      onError: AppColors.bgDeep,
      outline: AppColors.muted,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: fontFamily,
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.fg,
        displayColor: AppColors.fg,
      ),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: AppColors.hairline,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.snackFill,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 13,
          color: AppColors.bg,
        ),
        actionTextColor: AppColors.accent,
      ),
      datePickerTheme: base.datePickerTheme.copyWith(
        backgroundColor: AppColors.surface,
        headerBackgroundColor: AppColors.group,
        headerForegroundColor: AppColors.fg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(26)),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.accentInk,
        selectionColor: Color(0x33A8CC00),
        selectionHandleColor: AppColors.accentInk,
      ),
    );
  }
}
