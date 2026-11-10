import 'package:flutter/material.dart';

/// Colours from the MyHome design canvas.
abstract final class AppColors {
  static const ground = Color(0xFFF3F2EF);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE3E1DC);
  static const text = Color(0xFF1A1B1E);
  static const text2 = Color(0xFF55595F);
  static const track = Color(0xFFECEAE5);

  // lights
  static const lightBase = Color(0xFFFFF4DC);
  static const lightBorder = Color(0xFFF3DDAE);
  static const lightFill = Color(0xFFFFDF99);
  static const lightBar = Color(0xFFF5B83D);
  static const lightIcon = Color(0xFF9A5B00);
  static const lightChip = Color(0xFFFFF1D6);
  static const favStar = Color(0xFFB86E00);

  // blinds
  static const blind = Color(0xFF2F54C8);
  static const blindSoft = Color(0xFFEEF2FC);
  static const blindTrack = Color(0xFFE7ECFA);
  static const blindBorder = Color(0xFFD5DEF6);
  static const slat = Color(0xFFD3DCF5);
  static const slatGap = Color(0xFFE7ECFA);

  static const danger = Color(0xFFC8372D);
  static const ok = Color(0xFF1F7A4D);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blind,
      surface: AppColors.ground,
      primary: AppColors.text,
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.ground,
    splashFactory: InkSparkle.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.5),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.lightChip,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.text : AppColors.text2,
          )),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
  );
}

const bigTitle = TextStyle(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6);
const sectionLabel =
    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5, color: AppColors.text2);
