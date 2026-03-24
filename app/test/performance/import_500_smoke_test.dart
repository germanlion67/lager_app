// lib/../test/performance/import_500_smoke_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Performance Tests', () {
    test(
      'import_500 dataset existiert, 500 Einträge und Bilder vorhanden',
      () {
        final file = File('test_data/import_500.json');
        
        if (!file.existsSync()) {
          fail('Datei test_data/import_500.json nicht gefunden. '
              'Bitte mit `dart run tool/generate_import_dataset.dart --count 500` erstellen.');
        }

        final content = file.readAsStringSync();
        final json = jsonDecode(content);
        expect(json, isList);
        expect((json as List).length, equals(500));

        // Optional: Prüfe, ob Bilder existieren
        for (var i = 0; i < 10; i++) {
          final imagePath = 'test_data/images/test_image_$i.png';
          if (!File(imagePath).existsSync()) {
            fail('Test-Bild $imagePath nicht gefunden');
          }
        }
      },
      tags: ['performance'],  // ← Tag für Performance-Tests
    );
  });
}
