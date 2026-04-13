// test/performance/import_500_smoke_test.dart
//
// Smoke-Test: 500-Artikel-Datensatz wird programmatisch erzeugt,
// validiert und nach dem Test vollständig aufgeräumt.
//
// Kein externes Fixture nötig — flutter test läuft ohne Vorbereitung.
// tool/generate_import_dataset.dart bleibt für manuelle Großdatensätze erhalten.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:lager_app/utils/uuid_generator.dart';

// ---------------------------------------------------------------------------
// Konstanten
// ---------------------------------------------------------------------------

const int _kArtikelCount = 500;
const int _kBildCount = 10; // Bilder für Artikel-Index 0–9

/// Minimale 1×1-Pixel PNG (67 Bytes).
/// Valide PNG-Signatur + IHDR + IDAT + IEND.
/// Der Test prüft nur existsSync() — valider Inhalt ist aber sauberer
/// und erlaubt spätere Erweiterungen (z. B. image-Paket-Tests).
const List<int> _kMinimalPng = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG-Signatur
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR-Chunk-Länge + Typ
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // Breite=1, Höhe=1
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // RGBA, CRC (Teil)
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // IHDR-CRC + IDAT-Länge
  0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00, // IDAT: zlib-komprimiert
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, // IDAT-Daten + CRC
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND-Chunk
  0x42, 0x60, 0x82,                                // IEND-CRC
];

// ---------------------------------------------------------------------------
// Hilfsfunktionen
// ---------------------------------------------------------------------------

/// Generiert eine flache Artikel-Map, die Artikel.fromMap() versteht.
Map<String, dynamic> _generateArtikelMap(int index) {
  final now = DateTime.now().toUtc();
  return {
    'name': 'Testartikel ${index + 1}',
    'menge': index % 100,
    'ort': 'Regal ${(index ~/ 10) + 1}',
    'fach': 'Fach ${(index % 5) + 1}',
    'beschreibung': 'Automatisch generierte Testbeschreibung ${index + 1}',
    // Artikel 0–9 bekommen einen Bild-Pfad, der Rest bleibt leer
    'bildPfad': index < _kBildCount
        ? 'test_data/images/test_image_$index.png'
        : '',
    'uuid': UuidGenerator.generate(),
    'artikelnummer': 1000 + index,
    'erstelltAm': now.toIso8601String(),
    'aktualisiertAm': now.toIso8601String(),
    'updated_at': now.millisecondsSinceEpoch,
    'deleted': 0,
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('Performance Tests', () {
    // ── Fixture erzeugen ──────────────────────────────────────────────────
    setUpAll(() {
      // Verzeichnisse anlegen (idempotent)
      Directory('test_data/images').createSync(recursive: true);

      // 500 Artikel-Datensätze generieren und als JSON schreiben
      final artikel = List.generate(_kArtikelCount, _generateArtikelMap);
      File('test_data/import_500.json')
          .writeAsStringSync(jsonEncode(artikel));

      // Minimale PNG-Dateien für Artikel-Indizes 0–9 anlegen
      for (var i = 0; i < _kBildCount; i++) {
        File('test_data/images/test_image_$i.png')
            .writeAsBytesSync(_kMinimalPng);
      }
    });

    // ── Aufräumen ─────────────────────────────────────────────────────────
    tearDownAll(() {
      // Bild-Verzeichnis rekursiv löschen
      final imagesDir = Directory('test_data/images');
      if (imagesDir.existsSync()) imagesDir.deleteSync(recursive: true);

      // JSON-Fixture löschen
      final jsonFile = File('test_data/import_500.json');
      if (jsonFile.existsSync()) jsonFile.deleteSync();

      // test_data/ nur löschen wenn leer —
      // andere Test-Artefakte (z. B. aus zukünftigen Performance-Tests)
      // dürfen nicht versehentlich entfernt werden.
      final dataDir = Directory('test_data');
      if (dataDir.existsSync()) {
        try {
          dataDir.deleteSync(); // wirft Exception wenn nicht leer → gewollt
        } catch (_) {
          // Nicht leer — anderen Inhalt nicht anfassen
        }
      }
    });

    // ── Eigentlicher Test ─────────────────────────────────────────────────
    test(
      'import_500 dataset existiert, 500 Einträge und Bilder vorhanden',
      () {
        final file = File('test_data/import_500.json');

        // Datei muss nach setUpAll() existieren
        expect(
          file.existsSync(),
          isTrue,
          reason: 'Fixture-Datei wurde von setUpAll() erzeugt',
        );

        // Inhalt: valides JSON, exakt 500 Einträge
        final content = file.readAsStringSync();
        final decoded = jsonDecode(content);
        expect(decoded, isList, reason: 'JSON muss eine Liste sein');
        expect(
          (decoded as List).length,
          equals(_kArtikelCount),
          reason: 'Exakt $_kArtikelCount Artikel erwartet',
        );

        // Bild-Fixtures für Artikel 0–9 müssen existieren
        for (var i = 0; i < _kBildCount; i++) {
          final imagePath = 'test_data/images/test_image_$i.png';
          expect(
            File(imagePath).existsSync(),
            isTrue,
            reason: 'Bild-Fixture $imagePath wurde von setUpAll() erzeugt',
          );
        }
      },
      tags: ['performance'], // ← Weiterhin separat ausführbar
    );
  });
}