import 'package:flutter/material.dart';

/// Palette sombre Catppuccin Mocha (portée depuis le dict `C` de l'ancien main.py).
class AppColors {
  static const crust = Color(0xFF11111B);
  static const mantle = Color(0xFF181825);
  static const base = Color(0xFF1E1E2E);
  static const surface0 = Color(0xFF313244);
  static const surface1 = Color(0xFF45475A);
  static const text = Color(0xFFCDD6F4);
  static const subtext = Color(0xFFA6ADC8);
  static const blue = Color(0xFF89B4FA);
  static const lavender = Color(0xFFB4BEFE);
  static const red = Color(0xFFF38BA8);
  static const green = Color(0xFFA6E3A1);
  static const yellow = Color(0xFFF9E2AF);
  static const peach = Color(0xFFFAB387);

  /// Couleurs saturées des annotations, identiques à l'export PDF (lisibles sur papier blanc).
  static const symbol = Color(0xFFE74C3C);
  static const indication = Color(0xFF27AE60);
  static const defaultCrayon = Color(0xFFE74C3C);
}

ThemeData buildArpegeTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.base,
    canvasColor: AppColors.base,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: AppColors.blue,
      onPrimary: AppColors.crust,
      secondary: AppColors.lavender,
      surface: AppColors.base,
      onSurface: AppColors.text,
      error: AppColors.red,
    ),
    dividerColor: AppColors.surface0,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.mantle,
      foregroundColor: AppColors.text,
      elevation: 0,
    ),
    iconTheme: const IconThemeData(color: AppColors.text),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.text,
      iconColor: AppColors.subtext,
      selectedColor: AppColors.crust,
      selectedTileColor: AppColors.blue,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface0,
      hintStyle: const TextStyle(color: AppColors.subtext),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.surface1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.surface1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.blue),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surface0,
        foregroundColor: AppColors.text,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.mantle,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.crust),
      textStyle: TextStyle(color: AppColors.text),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.surface1),
      radius: const Radius.circular(4),
      thickness: WidgetStateProperty.all(8),
    ),
  );
}
