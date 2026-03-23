// lib/config/app_theme.dart
//
// Zentrale Theme-Konfiguration mit Material3-Unterstützung.
//
// Enthält:
// - Primär-, Akzent- und Hintergrundfarben
// - Light Theme (hell)
// - Dark Theme (dunkel)
// - Gemeinsame Theme-Eigenschaften

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimary,
        ),
      ),

      // Cards
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),

      // List Tiles
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        titleTextStyle: GoogleFonts.roboto(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: colorScheme.onPrimary,
        ),
      ),

      // Cards
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),

      // List Tiles
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        tileColor: Colors.transparent,
        selectedColor: colorScheme.primary,
      ),
    );
  }
}
