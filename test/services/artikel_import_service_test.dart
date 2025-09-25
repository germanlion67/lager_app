import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:elektronik_verwaltung/services/artikel_import_service.dart';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ArtikelImportService', () {
    final service = ArtikelImportService();
    late Directory testDir;

    // Mock für path_provider setup
    setUpAll(() async {
      testDir = await Directory.systemTemp.createTemp('test_documents');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return testDir.path;
          }
          return null;
        },
      );
    });

    tearDownAll(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        null,
      );
      // Räume das Test-Verzeichnis auf
      if (await testDir.exists()) {
        await testDir.delete(recursive: true);
      }
    });


    test('importFromJson should correctly parse valid JSON', () async {
      final jsonString = '''
      [
        {"id": 1, "name": "Artikel 1", "bildPfad": "path/to/image1.jpg"},
        {"id": 2, "name": "Artikel 2", "bildPfad": "path/to/image2.jpg"}
      ]
      ''';

      final artikelList = await service.importFromJson(jsonString);

      expect(artikelList.length, 2);
      expect(artikelList[0].name, 'Artikel 1');
      expect(artikelList[0].bildPfad, 'path/to/image1.jpg');
      expect(artikelList[1].name, 'Artikel 2');
      expect(artikelList[1].bildPfad, 'path/to/image2.jpg');
    });

    test('importFromJson should skip invalid entries', () async {
      final jsonString = '''
      [
        {"id": 1, "name": "Artikel 1", "bildPfad": "path/to/image1.jpg"},
        {"id": 2, "name": "Artikel 2", "bildPfad": null}
      ]
      ''';

      final artikelList = await service.importFromJson(jsonString);

      expect(artikelList.length, 1);
      expect(artikelList[0].name, 'Artikel 1');
    });

    test('importFromCsv should correctly parse valid CSV', () async {
      final csvString = '''
      name,menge,ort,fach,beschreibung,bildPfad,erstelltAm,aktualisiertAm,remoteBildPfad
      Artikel 1,10,Ort 1,Fach 1,Beschreibung 1,path/to/image1.jpg,2025-09-24,2025-09-24,remote/path/image1.jpg
      Artikel 2,5,Ort 2,Fach 2,Beschreibung 2,path/to/image2.jpg,2025-09-24,2025-09-24,remote/path/image2.jpg
      ''';

      final artikelList = await service.importFromCsv(csvString);

      expect(artikelList.length, 2);
      expect(artikelList[0].name, 'Artikel 1');
      expect(artikelList[0].bildPfad, 'path/to/image1.jpg');
      expect(artikelList[1].name, 'Artikel 2');
      expect(artikelList[1].bildPfad, 'path/to/image2.jpg');
    });

    test('importFromCsv should skip invalid entries', () async {
      final csvString = '''
      name,menge,ort,fach,beschreibung,bildPfad,erstelltAm,aktualisiertAm,remoteBildPfad
      Artikel 1,10,Ort 1,Fach 1,Beschreibung 1,path/to/image1.jpg,2025-09-24,2025-09-24,remote/path/image1.jpg
      Artikel 2,5,Ort 2,Fach 2,Beschreibung 2,,2025-09-24,2025-09-24,remote/path/image2.jpg
      ''';

      final artikelList = await service.importFromCsv(csvString);

      expect(artikelList.length, 1);
      expect(artikelList[0].name, 'Artikel 1');
    });
  });
}