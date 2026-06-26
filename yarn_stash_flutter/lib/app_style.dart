import 'package:flutter/material.dart';

abstract final class AppColors {
  static const bg = Color(0xFFFBF8F3);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2C241E);
  static const muted = Color(0xFF8B7D72);
  static const line = Color(0xFFECE2D8);
  static const accent = Color(0xFFB66F54);
  static const accentDark = Color(0xFF814734);
  static const sage = Color(0xFF8FA58B);
  static const cream = Color(0xFFFFF7ED);
  static const rose = Color(0xFFF6D9CD);
  static const sageSoft = Color(0xFFDCE7D7);
  static const goldSoft = Color(0xFFF7E7C6);
  static const lavenderSoft = Color(0xFFE7DDF6);
  static const taupeSoft = Color(0xFFEADFD5);
  static const danger = Color(0xFFB0453B);
  static const launchBrown = Color(0xFFA25E44);
}

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: AppColors.bg,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      onSurface: AppColors.ink,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    splashColor: AppColors.accent.withValues(alpha: 0.08),
    highlightColor: AppColors.accent.withValues(alpha: 0.05),
    inputDecorationTheme: const InputDecorationTheme(
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    ),
  );
}

const appShadow = [
  BoxShadow(color: Color(0x0E3C2A1D), blurRadius: 30, offset: Offset(0, 10)),
];

const accentShadow = [
  BoxShadow(color: Color(0x40B66F54), blurRadius: 28, offset: Offset(0, 14)),
];

const tightLetterSpacing = 0.0;
