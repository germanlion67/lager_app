// lib/screens/list_screen_cache_io.dart
//
// Gezieltes Image-Cache-Evict für Mobile/Desktop (dart:io).
// Wird über Conditional Import in artikel_list_screen.dart eingebunden.

import 'dart:io';
import 'package:flutter/painting.dart';

/// Entfernt ein einzelnes lokales Bild aus dem Flutter Image-Cache.
///
/// Nur auf Mobile/Desktop verfügbar (dart:io).
/// Fehler werden ignoriert — nicht kritisch für die App-Funktion.
void evictLocalImage(String? pfad) {
  if (pfad == null || pfad.isEmpty) return;
  try {
    final datei = File(pfad);
    if (datei.existsSync()) {
      FileImage(datei).evict();
    }
  } catch (_) {
    // Fehler beim Evict ignorieren — nicht kritisch
  }
}