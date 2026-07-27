import 'package:flutter/material.dart';

/// Système de design RSMS — tokens + thèmes clair/sombre.
///
/// Un seul endroit à modifier pour retoucher toute l'identité visuelle.
class AppColors {
  // Marque
  static const brand = Color(0xFF0D9488); // teal 600
  static const brandDark = Color(0xFF0F766E);

  // Canevas / surfaces (clair)
  static const canvasLight = Color(0xFFF4F6F8);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceAltLight = Color(0xFFF9FAFB);
  static const borderLight = Color(0xFFE6E8EC);
  static const textLight = Color(0xFF111827);
  static const mutedLight = Color(0xFF6B7280);

  // Canevas / surfaces (sombre)
  static const canvasDark = Color(0xFF0E1116);
  static const surfaceDark = Color(0xFF171A21);
  static const surfaceAltDark = Color(0xFF1E222B);
  static const borderDark = Color(0xFF2A2F3A);
  static const textDark = Color(0xFFE5E7EB);
  static const mutedDark = Color(0xFF9AA4B2);
}

/// Espacements (multiples de 4).
class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Rayons d'arrondi.
class Radii {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

/// Largeur d'écran au-delà de laquelle on affiche la barre latérale.
const double kWideBreakpoint = 900;

/// Couleurs "sémantiques" dépendantes du thème (bordures, texte discret…).
class AppSurface {
  final Color canvas, surface, surfaceAlt, border, text, muted;
  const AppSurface({
    required this.canvas,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.text,
    required this.muted,
  });

  static AppSurface of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const AppSurface(
            canvas: AppColors.canvasDark,
            surface: AppColors.surfaceDark,
            surfaceAlt: AppColors.surfaceAltDark,
            border: AppColors.borderDark,
            text: AppColors.textDark,
            muted: AppColors.mutedDark,
          )
        : const AppSurface(
            canvas: AppColors.canvasLight,
            surface: AppColors.surfaceLight,
            surfaceAlt: AppColors.surfaceAltLight,
            border: AppColors.borderLight,
            text: AppColors.textLight,
            muted: AppColors.mutedLight,
          );
  }
}

ThemeData buildAppTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final s = dark
      ? const AppSurface(
          canvas: AppColors.canvasDark,
          surface: AppColors.surfaceDark,
          surfaceAlt: AppColors.surfaceAltDark,
          border: AppColors.borderDark,
          text: AppColors.textDark,
          muted: AppColors.mutedDark,
        )
      : const AppSurface(
          canvas: AppColors.canvasLight,
          surface: AppColors.surfaceLight,
          surfaceAlt: AppColors.surfaceAltLight,
          border: AppColors.borderLight,
          text: AppColors.textLight,
          muted: AppColors.mutedLight,
        );

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: brightness,
  ).copyWith(
    surface: s.surface,
    onSurface: s.text,
  );

  final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: s.canvas,
    dividerColor: s.border,
    textTheme: base.textTheme.apply(bodyColor: s.text, displayColor: s.text),
    dividerTheme: DividerThemeData(color: s.border, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: s.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: s.border),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: s.surface,
      foregroundColor: s.text,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(color: s.text, fontSize: 18, fontWeight: FontWeight.w600),
      shape: Border(bottom: BorderSide(color: s.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? AppColors.surfaceAltDark : AppColors.surfaceAltLight,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: s.muted),
      labelStyle: TextStyle(color: s.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: s.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: s.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.sm),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: BorderSide(color: s.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.sm)),
    ),
    listTileTheme: const ListTileThemeData(iconColor: AppColors.brand),
  );
}
