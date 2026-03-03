import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:archive/archive_io.dart';

Future<void> main(List<String> args) async {
  // Parameter (optional): --count 500 --quality 95
  final argMap = _parseArgs(args);
  final count = int.tryParse(argMap['count'] ?? '') ?? 500;
  final quality = int.tryParse(argMap['quality'] ?? '') ?? 95; // Höhere Qualität = größere Dateien

  final projectRoot = Directory.current;
  final outDir = Directory('${projectRoot.path}/test/performance/import_500');
  final imagesDir = Directory('${outDir.path}/images');

  await imagesDir.create(recursive: true);

  // Basisbild (4032x2268) einmalig erzeugen und als JPEG speichern
  final width = 4032;
  final height = 2268;
  final baseImagePath = '${imagesDir.path}/_base_4032x2268_q$quality.jpg';

  if (!File(baseImagePath).existsSync()) {
    stdout.writeln('Erzeuge Basisbild $width x $height (Qualität $quality) …');
    final rnd = Random(42);
    final r = 80 + rnd.nextInt(100);
    final g = 80 + rnd.nextInt(100);
    final b = 80 + rnd.nextInt(100);

    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(r, g, b));

    // Mehr Details für größere Dateien - komplexeres Muster
    final barH = max(8, height ~/ 180);

    // Horizontale Balken
    for (var y = 0; y < barH; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, min(255, r + 20), min(255, g + 10), min(255, b + 10));
        image.setPixelRgb(x, height - 1 - y, min(255, r + 10), min(255, g + 20), min(255, b + 10));
      }
    }

    // Zusätzliche Details für größere Dateigröße - Rauschen/Textur
    for (var y = barH; y < height - barH; y += 4) {
      for (var x = 0; x < width; x += 4) {
        final noise = rnd.nextInt(30) - 15; // -15 bis +15
        image.setPixelRgb(
          x, y,
          (r + noise).clamp(0, 255),
          (g + noise).clamp(0, 255),
          (b + noise).clamp(0, 255)
        );
      }
    }

    // Diagonale Linien für mehr Komplexität
    for (var i = 0; i < width; i += 100) {
      for (var y = 0; y < height; y++) {
        final x = (i + y ~/ 4) % width;
        image.setPixelRgb(x, y, min(255, r + 30), min(255, g + 30), min(255, b + 30));
      }
    }

    final jpg = img.encodeJpg(image, quality: quality);
    await File(baseImagePath).writeAsBytes(jpg, flush: true);

    // Größe des Basisbildes prüfen
    final baseSize = await File(baseImagePath).length();
    stdout.writeln('Basisbild-Größe: ${(baseSize / (1024 * 1024)).toStringAsFixed(2)} MB');
  } else {
    stdout.writeln('Basisbild bereits vorhanden, überspringe Erzeugung.');
  }

  // Dateien aus Basisbild kopieren
  stdout.writeln('Erzeuge $count Bildkopien …');
  final items = <Map<String, dynamic>>[];
  for (var i = 1; i <= count; i++) {
    final artikelNr = 999 + i; // Startet bei 1000
    final fileName = 'artikel_$artikelNr.jpg';
    final dstPath = '${imagesDir.path}/$fileName';

    if (!File(dstPath).existsSync()) {
      await File(baseImagePath).copy(dstPath);
    }

    // Format an echte App-Exports anpassen
    final now = DateTime.now().toIso8601String();
    items.add({
      'id': artikelNr,
      'name': 'Beispielartikel $artikelNr',
      'menge': i % 50,
      'ort': 'Lager ${1 + (i % 10)}',
      'fach': 'Fach ${1 + (i % 20)}',
      'beschreibung': 'Automatisch generierter Beispielartikel Nr. $artikelNr',
      'bildPfad': 'images/$fileName', // Wird beim Import angepasst
      'erstelltAm': now,
      'aktualisiertAm': now,
      'remoteBildPfad': '',
    });
  }

  // Kompaktes Format wie die echte App (ohne Einrückung)
  final jsonOut = const JsonEncoder().convert(items);
  final jsonFile = File('${outDir.path}/import.json');
  await jsonFile.writeAsString(jsonOut, flush: true);

  final totalBytes = await _dirSize(imagesDir);
  stdout.writeln('Fertig: ${items.length} Artikel');
  stdout.writeln('JSON:   ${jsonFile.path}');
  stdout.writeln('Bilder: ${imagesDir.path}');
  stdout.writeln('Gesamtgröße Bilder: ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB');

  // ZIP-Export für Nextcloud
  stdout.writeln('Erstelle ZIP-Datei für Nextcloud-Import...');
  final zipFilePath = '${outDir.path}/../import_500.zip';
  
  try {
    // Falls ZIP bereits existiert, löschen
    final zipFile = File(zipFilePath);
    if (await zipFile.exists()) {
      await zipFile.delete();
    }

    // Archive erstellen
    final archive = Archive();

    // import.json hinzufügen
    final jsonBytes = await jsonFile.readAsBytes();
    archive.addFile(ArchiveFile('import.json', jsonBytes.length, jsonBytes));

    // Alle Bilder aus images/ Ordner hinzufügen
    final imageFiles = await imagesDir.list().toList();
    for (final entity in imageFiles) {
      if (entity is File && !entity.path.contains('_base_')) {
        final fileName = entity.path.split(Platform.pathSeparator).last;
        final imageBytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile('images/$fileName', imageBytes.length, imageBytes));
      }
    }

    // ZIP erstellen und schreiben
    final zipData = ZipEncoder().encode(archive);
    await zipFile.writeAsBytes(zipData, flush: true);

    final zipSize = await zipFile.length();
    stdout.writeln('ZIP-Export für Nextcloud: $zipFilePath');
    stdout.writeln('ZIP-Größe: ${(zipSize / (1024 * 1024)).toStringAsFixed(1)} MB');
  } catch (e) {
    stdout.writeln('Fehler beim ZIP-Export: $e');
    stdout.writeln('Die Einzeldateien sind trotzdem verfügbar unter: ${outDir.path}');
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i].startsWith('--')) {
      map[args[i].substring(2)] = args[i + 1];
    }
  }
  return map;
}

Future<int> _dirSize(Directory dir) async {
  int size = 0;
  await for (final e in dir.list(recursive: true, followLinks: false)) {
    if (e is File) size += await e.length();
  }
  return size;
}