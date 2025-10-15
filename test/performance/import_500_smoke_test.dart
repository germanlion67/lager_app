//../test/performance/import_500_smoke_test.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final jsonFileSync = File('test/performance/import_500/import.json');
  final datasetExists = jsonFileSync.existsSync();

  test(
    'import_500 dataset existiert, 500 Einträge und Bilder vorhanden',
    () async {
      final jsonFile = File('test/performance/import_500/import.json');
      expect(await jsonFile.exists(), true);

    final list = List<Map<String, dynamic>>.from(
      json.decode(await jsonFile.readAsString()),
    );
    expect(list.length, 500);

    final imagesDir = Directory('test/performance/import_500/images');
    expect(await imagesDir.exists(), true);

    var missing = 0;
    var totalBytes = 0;
    for (final item in list) {
      final path = 'test/performance/import_500/${item['bildPfad']}';
      final f = File(path);
      final exists = await f.exists();
      if (!exists) missing++;
      if (exists) totalBytes += await f.length();
    }

    // Ausgabe für Performance-Betrachtung
    // ignore: avoid_print
    print('Fehlende Bilder: $missing, Gesamtgröße: '
        '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB');
    expect(missing, 0);
    },
    skip: datasetExists ? false : 'Dataset test/performance/import_500 fehlt, Test übersprungen',
  );
}
