//lib/services/nextcloud_sync_service.dart

import 'package:webdav_client/webdav_client.dart' as webdav;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';
import 'artikel_db_service.dart';
import '../models/artikel_model.dart';
import 'package:flutter/material.dart';

/// Ergebnis einer Resync-Operation
class ResyncResult {
  final int totalFiles;
  final int successfullysynced;
  final int failed;
  final List<String> errors;

  ResyncResult({
    required this.totalFiles,
    required this.successfullysynced,
    required this.failed,
    required this.errors,
  });

  @override
  String toString() {
    return 'ResyncResult(total: $totalFiles, successful: $successfullysynced, failed: $failed)';
  }
}

class NextcloudSyncService {
  late webdav.Client client;
  final Logger _logger = Logger();
  late String remoteFolder;

  Future<bool> init() async {
    try {
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        _logger.e('Nextcloud-Zugangsdaten nicht gefunden.');
        return false;
      }
      client = webdav.newClient(
        creds.server.toString(),
        user: creds.user,
        password: creds.appPw,
      );
      remoteFolder = creds.baseFolder;
      return true;
    } catch (e) {
      _logger.e('Fehler bei Initialisierung der Nextcloud-Verbindung:', error: e);
      return false;
    }
  }

  Future<bool> uploadJsonFile(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) {
        await client.write('$remoteFolder/$fileName', file.readAsBytesSync());
        _logger.i('Datei erfolgreich hochgeladen: $fileName');
        return true;
      } else {
        _logger.w('Datei nicht gefunden: $fileName');
        return false;
      }
    } catch (e) {
      _logger.e('Fehler beim Hochladen der Datei:', error: e);
      return false;
    }
  }

  Future<bool> downloadJsonFile(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      final data = await client.read('$remoteFolder/$fileName');
      await file.writeAsBytes(data);
      _logger.i('Datei erfolgreich heruntergeladen: $fileName');
      return true;
    } catch (e) {
      _logger.e('Fehler beim Herunterladen der Datei:', error: e);
      return false;
    }
  }

  Future<bool> uploadImage(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageName = imageFile.uri.pathSegments.last;
      if (await imageFile.exists()) {
        await client.write('$remoteFolder/images/$imageName', imageFile.readAsBytesSync());
        _logger.i('Bild erfolgreich hochgeladen: $imageName');
        return true;
      } else {
        _logger.w('Bild nicht gefunden: $imagePath');
        return false;
      }
    } catch (e) {
      _logger.e('Fehler beim Hochladen des Bildes:', error: e);
      return false;
    }
  }

  /// Synchronisiert alle lokalen Dateien nach, die noch nicht zu Nextcloud hochgeladen wurden
  Future<ResyncResult> resyncPendingFiles() async {
    _logger.i('Starte Nachsynchronisation von ausstehenden Dateien...');
    
    final errors = <String>[];
    int successfullysynced = 0;
    int failed = 0;

    try {
      // 1. Nextcloud-Verbindung initialisieren
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        const error = 'Nextcloud-Zugangsdaten nicht gefunden';
        _logger.e(error);
        errors.add(error);
        return ResyncResult(totalFiles: 0, successfullysynced: 0, failed: 0, errors: errors);
      }

      final webdavClient = NextcloudWebDavClient(
        NextcloudConfig(
          serverBase: creds.server,
          username: creds.user,
          appPassword: creds.appPw,
          baseRemoteFolder: creds.baseFolder,
        ),
      );

      // 2. Alle Artikel mit unsynchronisierten Bildern laden
      final dbService = ArtikelDbService();
      final unsyncedArtikel = await dbService.getUnsyncedArtikel();
      
      _logger.i('Gefundene Artikel mit unsynchronisierten Dateien: ${unsyncedArtikel.length}');

      // 3. Für jeden Artikel das Bild hochladen
      for (final artikel in unsyncedArtikel) {
        try {
          await _syncArtikelImage(artikel, webdavClient, dbService);
          successfullysynced++;
          _logger.i('Erfolgreich synchronisiert: ${artikel.name} (ID: ${artikel.id})');
        } catch (e) {
          failed++;
          final error = 'Fehler bei Artikel ${artikel.name} (ID: ${artikel.id}): $e';
          _logger.e(error);
          errors.add(error);
        }
      }

      // 4. Export-Dateien synchronisieren (JSON/CSV)
      final exportResult = await _syncExportFiles(webdavClient);
      successfullysynced += exportResult.successfullysynced;
      failed += exportResult.failed;
      errors.addAll(exportResult.errors);

      final result = ResyncResult(
        totalFiles: unsyncedArtikel.length + exportResult.totalFiles,
        successfullysynced: successfullysynced,
        failed: failed,
        errors: errors,
      );

      _logger.i('Nachsynchronisation abgeschlossen: $result');
      return result;

    } catch (e) {
      final error = 'Unerwarteter Fehler bei der Nachsynchronisation: $e';
      _logger.e(error);
      errors.add(error);
      return ResyncResult(
        totalFiles: 0,
        successfullysynced: successfullysynced,
        failed: failed + 1,
        errors: errors,
      );
    }
  }

  /// Synchronisiert das Bild eines einzelnen Artikels
  Future<void> _syncArtikelImage(Artikel artikel, NextcloudWebDavClient webdavClient, ArtikelDbService dbService) async {
    if (artikel.bildPfad.isEmpty) {
      throw Exception('Kein Bildpfad vorhanden');
    }

    final imageFile = File(artikel.bildPfad);
    if (!await imageFile.exists()) {
      throw Exception('Bilddatei nicht gefunden: ${artikel.bildPfad}');
    }

    // Remote-Pfad generieren (ähnlich wie in artikel_erfassen_screen.dart)
    final baseName = p.basename(artikel.bildPfad);
    final remotePath = _buildRemotePath(
      artikelName: artikel.name,
      dateiname: baseName,
    );

    // Bild hochladen
    await webdavClient.uploadFile(
      localPath: artikel.bildPfad,
      remoteRelativePath: remotePath,
    );

    // DB mit Remote-Pfad aktualisieren
    await dbService.updateRemoteBildPfad(artikel.id!, remotePath);
  }

  /// Synchronisiert Export-Dateien (JSON/CSV) falls vorhanden
  Future<ResyncResult> _syncExportFiles(NextcloudWebDavClient webdavClient) async {
    final errors = <String>[];
    int successfullysynced = 0;
    int failed = 0;
    int totalFiles = 0;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().where((file) => 
        file is File && 
        (file.path.endsWith('.json') || file.path.endsWith('.csv')) &&
        p.basename(file.path).startsWith('artikel_export_')
      ).cast<File>().toList();

      totalFiles = files.length;
      _logger.i('Gefundene Export-Dateien: $totalFiles');

      for (final file in files) {
        try {
          final fileName = p.basename(file.path);
          final remotePath = 'exports/$fileName';
          
          await webdavClient.uploadFile(
            localPath: file.path,
            remoteRelativePath: remotePath,
          );
          
          successfullysynced++;
          _logger.i('Export-Datei erfolgreich hochgeladen: $fileName');
        } catch (e) {
          failed++;
          final error = 'Fehler beim Hochladen von ${p.basename(file.path)}: $e';
          _logger.e(error);
          errors.add(error);
        }
      }
    } catch (e) {
      final error = 'Fehler beim Synchronisieren von Export-Dateien: $e';
      _logger.e(error);
      errors.add(error);
    }

    return ResyncResult(
      totalFiles: totalFiles,
      successfullysynced: successfullysynced,
      failed: failed,
      errors: errors,
    );
  }

  /// Generiert Remote-Pfad für Artikel-Bilder (ähnlich wie in artikel_erfassen_screen.dart)
  String _buildRemotePath({
    required String artikelName,
    required String dateiname,
  }) {
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final slug = _slug(artikelName);
    return 'Apps/Artikel/$ts-$slug/$dateiname';
  }

  /// Erstellt URL-tauglichen Slug aus Artikel-Namen
  String _slug(String input) {
    final s = input.toLowerCase();
    final replaced = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static Future<void> showResyncDialog(BuildContext context) async {
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Synchronisiere Dateien...'),
          ],
        ),
      ),
    );

    try {
      final syncService = NextcloudSyncService();
      final result = await syncService.resyncPendingFiles();

      if (!context.mounted) return;
      Navigator.pop(context); // Lade-Dialog schließen

      final message = result.failed == 0
          ? 'Synchronisation erfolgreich!\n${result.successfullysynced} Datei(en) hochgeladen.'
          : 'Synchronisation abgeschlossen mit Fehlern:\n'
            '✓ ${result.successfullysynced} erfolgreich\n'
            '✗ ${result.failed} fehlgeschlagen';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nextcloud Synchronisation'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Fehler-Details:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...result.errors.take(3).map((error) =>
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $error', style: const TextStyle(fontSize: 12)),
                  )
                ),
                if (result.errors.length > 3)
                  Text('... und ${result.errors.length - 3} weitere Fehler'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.failed == 0
            ? '${result.successfullysynced} Datei(en) synchronisiert'
            : '${result.successfullysynced} erfolgreich, ${result.failed} Fehler'),
          backgroundColor: result.failed == 0 ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context); // Lade-Dialog schließen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Synchronisation fehlgeschlagen: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
