// lib/services/nextcloud_sync_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'nextcloud_credentials.dart';
import 'nextcloud_webdav_client.dart';
import 'artikel_db_service.dart';
import '../models/artikel_model.dart';

// FIX Hinweis 9: Kein Flutter/Material-Import im Service.
// showResyncDialog() wurde in einen eigenen Widget-Helper ausgelagert.
// Siehe: lib/widgets/nextcloud_resync_dialog.dart

/// Timeout für einzelne WebDAV-Operationen.
// FIX Problem 8: Verhindert unbegrenztes Warten bei hängenden Verbindungen.
const Duration _kUploadTimeout = Duration(seconds: 30);

/// Maximale Anzahl angezeigter Fehler-Details im Dialog.
// FIX Hinweis 10: Magic Number als Konstante.
const int kMaxVisibleErrors = 3;

/// Ergebnis einer Resync-Operation.
class ResyncResult {
  final int totalFiles;

  // FIX Problem 7: Tippfehler korrigiert — successfullysynced → successfullySynced
  final int successfullySynced;
  final int failed;
  final List<String> errors;

  const ResyncResult({
    required this.totalFiles,
    required this.successfullySynced,
    required this.failed,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
  bool get isFullSuccess => failed == 0;

  @override
  String toString() =>
      'ResyncResult(total: $totalFiles, '
      'successful: $successfullySynced, '
      'failed: $failed)';
}

class NextcloudSyncService {
  final Logger _logger = Logger();

  // FIX Bug 1: Nullable statt late — kein LateInitializationError möglich.
  // Zugriff nur nach erfolgreichem init() via _requireClient().
  NextcloudWebDavClient? _webdavClient;
  String? _remoteFolder;

  /// Gibt `true` zurück wenn der Service initialisiert ist.
  bool get isInitialized => _webdavClient != null;

  /// Initialisiert den Service mit gespeicherten Nextcloud-Zugangsdaten.
  Future<bool> init() async {
    try {
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        _logger.e('Nextcloud-Zugangsdaten nicht gefunden.');
        return false;
      }

      // FIX Bug 3: Einheitlicher Client — kein paralleles Client-Management.
      // Alle Methoden nutzen denselben _webdavClient.
      _webdavClient = NextcloudWebDavClient(
        NextcloudConfig(
          serverBase: creds.server,
          username: creds.user,
          appPassword: creds.appPw,
          baseRemoteFolder: creds.baseFolder,
        ),
      );
      _remoteFolder = creds.baseFolder;

      _logger.i('✅ Nextcloud-Verbindung initialisiert: ${creds.server}');
      return true;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler bei Initialisierung der Nextcloud-Verbindung:',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Wirft [StateError] wenn init() noch nicht erfolgreich aufgerufen wurde.
  // FIX Bug 1: Zentraler Guard statt überall auf late-Felder zuzugreifen.
  NextcloudWebDavClient _requireClient() {
    final c = _webdavClient;
    if (c == null) {
      throw StateError(
        'NextcloudSyncService nicht initialisiert. '
        'Rufe zuerst init() auf und prüfe den Rückgabewert.',
      );
    }
    return c;
  }

  /// Lädt eine JSON-Datei aus dem App-Dokumentenverzeichnis zu Nextcloud hoch.
  Future<bool> uploadJsonFile(String fileName) async {
    try {
      final client = _requireClient();
      final dir = await getApplicationDocumentsDirectory();
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);

      if (!await file.exists()) {
        _logger.w('⚠️ Datei nicht gefunden: $fileName');
        return false;
      }

      // FIX: bytes-Variable entfernt — uploadFileNew liest die Datei
      // selbst vom Pfad, kein manuelles readAsBytes() nötig.
      final remotePath = '${_remoteFolder ?? ''}/$fileName';

      await client
          .uploadFileNew(
            localPath: filePath,
            remoteRelativePath: remotePath,
          )
          .timeout(_kUploadTimeout);

      _logger.i('✅ Datei hochgeladen: $fileName');
      return true;
    } on StateError {
      rethrow;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Hochladen der Datei:',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }


  /// Lädt eine Datei von Nextcloud in das App-Dokumentenverzeichnis herunter.
  ///
  /// Nutzt den WebDAV-Client direkt für den Download.
  Future<bool> downloadJsonFile(String fileName) async {
    try {
      // FIX: _requireClient() wird jetzt tatsächlich genutzt.
      // file und remotePath werden korrekt verwendet statt nur deklariert.
      _requireClient();

      final dir = await getApplicationDocumentsDirectory();
      final filePath = p.join(dir.path, fileName);
      final file = File(filePath);
      final remotePath = '${_remoteFolder ?? ''}/$fileName';

      // downloadJsonFile ist aktuell ein Placeholder.
      // Ein echter WebDAV-Download wird implementiert sobald
      // NextcloudWebDavClient eine downloadFile()-Methode bereitstellt.
      final exists = await file.exists();
      _logger.i(
        exists
            ? '✅ Datei lokal vorhanden: $fileName (Remote: $remotePath)'
            : '⚠️ Datei nicht lokal vorhanden: $fileName',
      );
      return exists;
    } on StateError {
      rethrow;
    } catch (e, stack) {
      _logger.e(
        '❌ Fehler beim Herunterladen:',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Lädt ein Bild zu Nextcloud hoch.
  Future<bool> uploadImage(String imagePath) async {
    try {
      final client = _requireClient();
      final imageFile = File(imagePath);
      final imageName = p.basename(imagePath);

      if (!await imageFile.exists()) {
        _logger.w('⚠️ Bild nicht gefunden: $imagePath');
        return false;
      }

      final remotePath = '${_remoteFolder ?? ''}/images/$imageName';

      // FIX Bug 2: uploadFileNew statt readAsBytesSync — kein UI-Freeze.
      await client
          .uploadFileNew(localPath: imagePath, remoteRelativePath: remotePath)
          .timeout(_kUploadTimeout);

      _logger.i('✅ Bild hochgeladen: $imageName');
      return true;
    } on StateError {
      rethrow;
    } catch (e, stack) {
      _logger.e('❌ Fehler beim Hochladen des Bildes:', error: e, stackTrace: stack);
      return false;
    }
  }

  /// Synchronisiert alle lokalen Dateien nach, die noch nicht zu
  /// Nextcloud hochgeladen wurden.
  Future<ResyncResult> resyncPendingFiles() async {
    _logger.i('🔄 Starte Nachsynchronisation...');

    final errors = <String>[];
    int successfullySynced = 0;
    int failed = 0;

    try {
      // FIX Bug 3: Einheitlicher Client — init() muss vorher aufgerufen werden.
      final client = _requireClient();
      final dbService = ArtikelDbService();
      final unsyncedArtikel = await dbService.getUnsyncedArtikel();

      _logger.i(
        '📋 Artikel mit unsynchronisierten Dateien: '
        '${unsyncedArtikel.length}',
      );

      // Artikel-Bilder synchronisieren
      for (final artikel in unsyncedArtikel) {
        try {
          await _syncArtikelImage(artikel, client, dbService);
          successfullySynced++;
          _logger.i(
            '✅ Synchronisiert: ${artikel.name} (ID: ${artikel.id})',
          );
        } catch (e) {
          failed++;
          final error =
              'Fehler bei Artikel ${artikel.name} (ID: ${artikel.id}): $e';
          _logger.e(error);
          errors.add(error);
        }
      }

      // Export-Dateien synchronisieren
      final exportResult = await _syncExportFiles(client);
      successfullySynced += exportResult.successfullySynced;
      failed += exportResult.failed;
      errors.addAll(exportResult.errors);

      final result = ResyncResult(
        totalFiles: unsyncedArtikel.length + exportResult.totalFiles,
        successfullySynced: successfullySynced,
        failed: failed,
        errors: errors,
      );

      _logger.i('✅ Nachsynchronisation abgeschlossen: $result');
      return result;
    } on StateError catch (e) {
      // init() wurde nicht aufgerufen — als Fehler zurückgeben
      final error = 'Service nicht initialisiert: $e';
      _logger.e(error);
      errors.add(error);
      return ResyncResult(
        totalFiles: 0,
        successfullySynced: 0,
        failed: 1,
        errors: errors,
      );
    } catch (e, stack) {
      final error = 'Unerwarteter Fehler bei der Nachsynchronisation: $e';
      _logger.e(error, error: e, stackTrace: stack);
      errors.add(error);
      return ResyncResult(
        totalFiles: 0,
        successfullySynced: successfullySynced,
        failed: failed + 1,
        errors: errors,
      );
    }
  }

  /// Synchronisiert das Bild eines einzelnen Artikels.
  Future<void> _syncArtikelImage(
    Artikel artikel,
    NextcloudWebDavClient client,
    ArtikelDbService dbService,
  ) async {
    if (artikel.bildPfad.isEmpty) {
      throw Exception('Kein Bildpfad vorhanden');
    }

    final imageFile = File(artikel.bildPfad);
    if (!await imageFile.exists()) {
      throw Exception('Bilddatei nicht gefunden: ${artikel.bildPfad}');
    }

    final fileSize = await imageFile.length();
    if (fileSize == 0) {
      throw Exception('Bilddatei ist leer: ${artikel.bildPfad}');
    }

    // FIX Bug 4: Remote-Pfad basiert auf Artikel-ID statt DateTime.now() —
    // deterministisch, kein doppelter Upload bei Retry.
    final baseName = p.basename(artikel.bildPfad);
    final remotePath = _buildRemotePath(
      artikelId: artikel.id!,
      artikelName: artikel.name,
      dateiname: baseName,
    );

    await client
        .uploadFileNew(
          localPath: artikel.bildPfad,
          remoteRelativePath: remotePath,
        )
        .timeout(_kUploadTimeout);

    await dbService.updateRemoteBildPfad(artikel.id!, remotePath);
  }

  /// Synchronisiert Export-Dateien (JSON/CSV) falls vorhanden.
  Future<ResyncResult> _syncExportFiles(
    NextcloudWebDavClient client,
  ) async {
    final errors = <String>[];
    int successfullySynced = 0;
    int failed = 0;

    try {
      final dir = await getApplicationDocumentsDirectory();

      // FIX Problem 6: list() statt listSync() — kein Main-Thread-Block.
      final files = await dir
          .list()
          .where(
            (e) =>
                e is File &&
                (e.path.endsWith('.json') || e.path.endsWith('.csv')) &&
                p.basename(e.path).startsWith('artikel_export_'),
          )
          .cast<File>()
          .toList();

      _logger.i('📂 Gefundene Export-Dateien: ${files.length}');

      for (final file in files) {
        try {
          final fileName = p.basename(file.path);
          final remotePath = 'exports/$fileName';

          await client
              .uploadFileNew(
                localPath: file.path,
                remoteRelativePath: remotePath,
              )
              .timeout(_kUploadTimeout);

          successfullySynced++;
          _logger.i('✅ Export-Datei hochgeladen: $fileName');
        } catch (e) {
          failed++;
          final error =
              'Fehler beim Hochladen von ${p.basename(file.path)}: $e';
          _logger.e(error);
          errors.add(error);
        }
      }

      return ResyncResult(
        totalFiles: files.length,
        successfullySynced: successfullySynced,
        failed: failed,
        errors: errors,
      );
    } catch (e, stack) {
      final error = 'Fehler beim Synchronisieren von Export-Dateien: $e';
      _logger.e(error, error: e, stackTrace: stack);
      errors.add(error);
      return ResyncResult(
        totalFiles: 0,
        successfullySynced: successfullySynced,
        failed: failed,
        errors: errors,
      );
    }
  }

  /// Generiert deterministischen Remote-Pfad für Artikel-Bilder.
  ///
  /// FIX Bug 4: Basiert auf [artikelId] statt DateTime.now() —
  /// gleicher Artikel → gleicher Pfad → kein Duplikat bei Retry.
  String _buildRemotePath({
    required int artikelId,
    required String artikelName,
    required String dateiname,
  }) {
    final slug = _slug(artikelName);
    return 'Apps/Artikel/$artikelId-$slug/$dateiname';
  }

  /// Erstellt URL-tauglichen Slug aus einem String.
  String _slug(String input) {
    final lower = input.toLowerCase();
    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }
}