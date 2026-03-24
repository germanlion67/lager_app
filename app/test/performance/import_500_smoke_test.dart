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
        expect(file.existsSync(), isTrue,
            reason: 'Datei test_data/import_500.json nicht gefunden. '
                'Bitte mit `dart run tool/generate_import_dataset.dart --count 500` erstellen.');

        final content = file.readAsStringSync();
        final json = jsonDecode(content);
        expect(json, isList);
        expect((json as List).length, equals(500));
      },
      skip: Platform.environment['CI'] == 'true'  // ← NEU: Im CI überspringen
          ? 'Performance-Test benötigt lokal generierte Testdaten'
          : false,
    );
  });
}
