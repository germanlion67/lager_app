// lib/config/app_images.dart
//
// Zentrale Konfiguration für Bilder, Assets und Platzhalter.
//
// Enthält:
// - Pfade zu Hintergrundbildern und anderen Assets
// - Platzhalter-Konfiguration (Größe, Farben)
// - Feature-Flags für optionale UI-Elemente (z.B. Hintergrund)

import 'package:flutter/material.dart' show Color;

class AppImages {
  AppImages._();

  // ============================================================================
  // Asset-Pfade
  // ============================================================================

  /// Pfad zum Hintergrundbild der App.
  /// Wird in main.dart als Background-Stack verwendet (wenn hintergrundAktiv == true).
  static const String hintergrundPfad = 'assets/images/hintergrund.jpg';

  /// Pfad zum Platzhalter-Bild für Artikel ohne Foto.
  static const String platzhalterBildPfad = 'assets/images/placeholder.jpg';

  // ============================================================================
  // Feature-Flags
  // ============================================================================

  /// Steuert ob das Hintergrundbild in der App angezeigt wird.
  /// false = kein Hintergrundbild (Standard)
  /// true  = Hintergrundbild wird als Background-Stack in main.dart verwendet
  static const bool hintergrundAktiv = false;

  // ============================================================================
  // Platzhalter-Konfiguration
  // ============================================================================

  /// Größe des Platzhalter-Icons (z.B. Icons.image_not_supported).
  static const double platzhalterIconGroesse = 48.0;

  /// Hintergrundfarbe für Platzhalter ohne Bild.
  /// Hellgrau für neutrales Erscheinungsbild.
  static const Color platzhalterHintergrund = Color(0xFFE0E0E0);

  /// Hintergrundfarbe für kleinere Platzhalter (z.B. in Listen).
  /// Etwas dunkler als der Standard-Platzhalter.
  static const Color platzhalterHintergrundKlein = Color(0xFFD0D0D0);

  /// Hintergrundfarbe für Lade-Platzhalter (während Bild lädt).
  static const Color ladePlatzhalterHintergrund = Color(0xFFF5F5F5);
}
