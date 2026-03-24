// lib/../test/performance/import_500_smoke_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Performance Tests', () {
    // Prüfe CI-Umgebung VOR dem Test
    final isCI = Platform.environment['CI'] == 'true';
    
    test(
      'import_500 dataset existiert, 500 Einträge und Bilder vorhanden',
      () {
        // Überspringe im CI
        if (isCI) {
          markTestSkipped('Performance-Test benötigt lokal generierte Testdaten');
          return;
        }

        final file = File('test_data/import_500.json');
        expect(file.existsSync(), isTrue,
            reason: 'Datei test_data/import_500.json nicht gefunden. '
                'Bitte mit `dart run tool/generate_import_dataset.dart --count 500` erstellen.');

        final content = file.readAsStringSync();
        final json = jsonDecode(content);
        expect(json, isList);
        expect((json as List).length, equals(500));

        // Optional: Prüfe, ob Bilder existieren
        for (var i = 0; i < 10; i++) {  // Nur erste 10 prüfen
          final imagePath = 'test_data/images/test_image_$i.png';
          expect(File(imagePath).existsSync(), isTrue,
              reason: 'Test-Bild $imagePath nicht gefunden');
        }
      },
      tags: ['performance'],  // Tag hinzufügen für bessere Organisation
    );
  });
}
