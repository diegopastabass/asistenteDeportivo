/// Paleta Gruvbox de la versión web (src/index.css), en claro y oscuro.
library;

import 'package:flutter/material.dart';

import '../core/nutrition/models.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.bgHard,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.borderStrong,
    required this.fg,
    required this.fgStrong,
    required this.muted,
    required this.faint,
    required this.primary,
    required this.primary2,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.danger,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.chartLine,
  });

  static const dark = AppColors(
    bg: Color(0xFF282828),
    bgHard: Color(0xFF1D2021),
    surface: Color(0xFF32302F),
    surface2: Color(0xFF3C3836),
    border: Color(0xFF504945),
    borderStrong: Color(0xFF665C54),
    fg: Color(0xFFEBDBB2),
    fgStrong: Color(0xFFFBF1C7),
    muted: Color(0xFFA89984),
    faint: Color(0xFF7C6F64),
    primary: Color(0xFF8EC07C),
    primary2: Color(0xFF83A598),
    onPrimary: Color(0xFF1D2021),
    success: Color(0xFFB8BB26),
    warning: Color(0xFFFABD2F),
    danger: Color(0xFFFB4934),
    kcal: Color(0xFFFE8019),
    protein: Color(0xFFD3869B),
    carbs: Color(0xFFFABD2F),
    fat: Color(0xFFB8BB26),
    fiber: Color(0xFF83A598),
    chartLine: Color(0xFF68A258),
  );

  static const light = AppColors(
    bg: Color(0xFFFBF1C7),
    bgHard: Color(0xFFF9F5D7),
    surface: Color(0xFFF2E5BC),
    surface2: Color(0xFFEBDBB2),
    border: Color(0xFFD5C4A1),
    borderStrong: Color(0xFFBDAE93),
    fg: Color(0xFF3C3836),
    fgStrong: Color(0xFF282828),
    muted: Color(0xFF7C6F64),
    faint: Color(0xFFA89984),
    primary: Color(0xFF427B58),
    primary2: Color(0xFF076678),
    onPrimary: Color(0xFFFBF1C7),
    success: Color(0xFF79740E),
    warning: Color(0xFFB57614),
    danger: Color(0xFF9D0006),
    kcal: Color(0xFFAF3A03),
    protein: Color(0xFF8F3F71),
    carbs: Color(0xFFB57614),
    fat: Color(0xFF79740E),
    fiber: Color(0xFF076678),
    chartLine: Color(0xFF3F8A4F),
  );

  final Color bg;
  final Color bgHard;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color borderStrong;
  final Color fg;
  final Color fgStrong;
  final Color muted;
  final Color faint;
  final Color primary;
  final Color primary2;
  final Color onPrimary;
  final Color success;
  final Color warning;
  final Color danger;
  final Color kcal;
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color fiber;
  final Color chartLine;

  Color get primarySoft => primary.withValues(alpha: 0.14);

  LinearGradient get gradient => LinearGradient(colors: [primary, primary2], begin: Alignment.topLeft, end: Alignment.bottomRight);

  Color macro(MacroKey k) => switch (k) {
        MacroKey.kcal => kcal,
        MacroKey.protein => protein,
        MacroKey.carbs => carbs,
        MacroKey.fat => fat,
        MacroKey.fiber => fiber,
      };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => t < 0.5 || other is! AppColors ? this : other;
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.primary2,
    onSecondary: c.onPrimary,
    error: c.danger,
    onError: c.onPrimary,
    surface: c.bg,
    onSurface: c.fg,
    surfaceContainerLowest: c.bgHard,
    surfaceContainerLow: c.surface,
    surfaceContainer: c.surface,
    surfaceContainerHigh: c.surface2,
    surfaceContainerHighest: c.surface2,
    onSurfaceVariant: c.muted,
    outline: c.border,
    outlineVariant: c.border,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border));
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
    textTheme: base.textTheme.apply(bodyColor: c.fg, displayColor: c.fgStrong),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.fgStrong,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.bg,
      indicatorColor: c.primarySoft,
      surfaceTintColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, color: c.muted, fontWeight: FontWeight.w500)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.primary : c.muted)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.bgHard,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: c.primary, width: 1.5)),
      errorBorder: border.copyWith(borderSide: BorderSide(color: c.danger)),
      hintStyle: TextStyle(color: c.faint),
      labelStyle: TextStyle(color: c.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.fg,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: c.primary)),
    chipTheme: ChipThemeData(
      backgroundColor: c.bg,
      selectedColor: c.primarySoft,
      side: BorderSide(color: c.border),
      labelStyle: TextStyle(color: c.fg, fontSize: 12),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.surface2,
      contentTextStyle: TextStyle(color: c.fgStrong),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.bg, surfaceTintColor: Colors.transparent, showDragHandle: true),
    dialogTheme: DialogThemeData(backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
    sliderTheme: SliderThemeData(activeTrackColor: c.primary, thumbColor: c.primary, inactiveTrackColor: c.bgHard),
    listTileTheme: ListTileThemeData(iconColor: c.muted, textColor: c.fg),
  );
}
