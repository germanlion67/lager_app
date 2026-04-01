// lib/config/app_theme.dart
//
// Zentrale Theme-Konfiguration mit Material3-Unterstützung.
//
// Enthält:
// - Primär-, Akzent- und Hintergrundfarben
// - Light Theme (hell)
// - Dark Theme (dunkel)
// - Gemeinsame Theme-Eigenschaften
//
// O-004 Batch 2: Hardcodierte Spacing/Radius/Font-Size-Werte in
// Component-Themes durch AppConfig-Tokens ersetzt.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_config.dart';

class AppTheme {
  AppTheme._();

  // ============================================================================
  // Farben
  // ============================================================================

  /// Primärfarbe der App (Blau).
  static const Color primaerFarbe = Color(0xFF2196F3);

  /// Akzentfarbe der App (Hellblau).
  static const Color akzentFarbe = Color(0xFF64B5F6);

  /// Hintergrundfarbe für Light Theme.
  static const Color hintergrundFarbeHell = Color(0xFFFFFFFF);

  /// Hintergrundfarbe für Dark Theme.
  static const Color hintergrundFarbeDunkel = Color(0xFF121212);

  /// Textfarbe für Light Theme.
  static const Color textFarbeHell = Color(0xFF000000);

  /// Textfarbe für Dark Theme.
  static const Color textFarbeDunkel = Color(0xFFFFFFFF);

  // ============================================================================
  // Grey Color Palette
  // ============================================================================

  /// Extra helles Grau (Grey 100) - für Hintergründe.
  static const Color greyLight100 = Color(0xFFF5F5F5);

  /// Helles Grau (Grey 200) - für Platzhalter.
  static const Color greyLight200 = Color(0xFFEEEEEE);

  /// Neutrales Grau (Grey 300) - für Borders und Separatoren.
  static const Color greyNeutral300 = Color(0xFFE0E0E0);

  /// Mittleres Grau (Grey 400) - für deaktivierte Elemente.
  static const Color greyNeutral400 = Color(0xFFBDBDBD);

  /// Dunkles Grau (Grey 600) - für sekundären Text.
  static const Color greyNeutral600 = Color(0xFF757575);

  /// Extra dunkles Grau (Grey 700) - für Icons und Akzente.
  static const Color greyDark700 = Color(0xFF616161);

  /// Extra extra dunkles Grau (Grey 800) - für starken Kontrast.
  static const Color greyDark800 = Color(0xFF424242);

  // ============================================================================
  // Semantic Colors (für Status-Anzeigen)
  // ============================================================================

  /// Rot für Fehler und kritische Warnungen (Red 700).
  static const Color errorColor = Color(0xFFD32F2F);

  /// Orange für Warnungen (Orange 700).
  static const Color warningColor = Color(0xFFF57C00);

  /// Grün für Erfolg (Green 700).
  static const Color successColor = Color(0xFF388E3C);

  /// Blau für Informationen (Blue 700).
  static const Color infoColor = Color(0xFF1976D2);

  // ============================================================================
  // Themes
  // ============================================================================

  /// Light Theme (hell) mit Material3.
  static ThemeData get hell {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaerFarbe,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: hintergrundFarbeHell,

      // Roboto Font als Standard-Schriftart (N-004)
      textTheme: GoogleFonts.robotoTextTheme(
        ThemeData.light().textTheme.copyWith(
          bodyLarge: const TextStyle(color: textFarbeHell),
          bodyMedium: const TextStyle(color: textFarbeHell),
          bodySmall: const TextStyle(color: textFarbeHell),
        ),
      ),

      // Input-Dekoration
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: textFarbeHell),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppConfig.spacingLarge,
          vertical: AppConfig.spacingMedium,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: AppConfig.fontSizeXXLarge,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimary,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppConfig.cardBorderRadiusLarge,
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),

      // List Tiles
      listTileTheme: ListTileThemeData(
        contentPadding: AppConfig.listTilePadding,
        tileColor: Colors.transparent,
        selectedColor: colorScheme.primary,
      ),
    );
  }

  /// Dark Theme (dunkel) mit Material3.
  static ThemeData get dunkel {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaerFarbe,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: hintergrundFarbeDunkel,

      // Roboto Font als Standard-Schriftart (N-004)
      textTheme: GoogleFonts.robotoTextTheme(
        ThemeData.dark().textTheme.copyWith(
          bodyLarge: const TextStyle(color: textFarbeDunkel),
          bodyMedium: const TextStyle(color: textFarbeDunkel),
          bodySmall: const TextStyle(color: textFarbeDunkel),
        ),
      ),

      // Input-Dekoration
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(color: textFarbeDunkel),
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppConfig.spacingLarge,
          vertical: AppConfig.spacingMedium,
        ),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: AppConfig.fontSizeXXLarge,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimary,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            AppConfig.cardBorderRadiusLarge,
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),

      // List Tiles
      listTileTheme: ListTileThemeData(
        contentPadding: AppConfig.listTilePadding,
        tileColor: Colors.transparent,
        selectedColor: colorScheme.primary,
      ),
    );
  }
}