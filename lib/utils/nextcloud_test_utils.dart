import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/nextcloud_credentials.dart';
import '../services/nextcloud_webdav_client.dart';
import '../services/app_log_service.dart';

/// Utility-Klasse zum Testen der Nextcloud listFiles Methode
/// Kann direkt in der App verwendet werden
class NextcloudTestUtils {
  
  /// Führt einen einfachen Test der listFiles Methode durch
  static Future<void> testListFiles(BuildContext context) async {
    // Context-Check vor async operation
    if (!context.mounted) return;
    
    // Loading indicator anzeigen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 16),
            Text('Teste Nextcloud Verbindung...'),
          ],
        ),
        duration: Duration(seconds: 60), // Lange Duration für Test
      ),
    );

    try {
      await AppLogService().log('🔍 Starte Nextcloud listFiles Test');
      
      // 1. Credentials prüfen
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        await AppLogService().logError('❌ Keine Nextcloud-Zugangsdaten gefunden');
        if (!context.mounted) return;
        _showResult(context, false, 'Keine Nextcloud-Zugangsdaten gefunden!');
        return;
      }

      await AppLogService().log('✅ Nextcloud-Zugangsdaten geladen');
      await AppLogService().log('   Server: ${creds.server}');
      await AppLogService().log('   User: ${creds.user}');
      await AppLogService().log('   BaseFolder: ${creds.baseFolder}');

      // 2. WebDAV Client erstellen
      final webdavClient = NextcloudWebDavClient(
        NextcloudConfig(
          serverBase: creds.server,
          username: creds.user,
          appPassword: creds.appPw,
          baseRemoteFolder: creds.baseFolder,
        ),
      );

      await AppLogService().log('🔗 WebDAV Client erstellt');

      // 3. Test: Dateien im Basis-Ordner auflisten
      await AppLogService().log('📂 Teste listFiles("${creds.baseFolder}")...');
      
      // ERWEITERTE DEBUG VERSION - Zeige rohe XML-Antwort
      await _debugListFilesRaw(webdavClient, creds.baseFolder);
      
      final rootFiles = await webdavClient.listFiles(creds.baseFolder);
      
      await AppLogService().log('✅ listFiles erfolgreich!');
      await AppLogService().log('   Gefundene Dateien: ${rootFiles.length}');
      await AppLogService().log('🚨 PROBLEM: Sollten 23 Dateien sein (19 JPG + 4 ZIP)!');
      
      // Dateien loggen mit ZIP-Detection
      if (rootFiles.isEmpty) {
        await AppLogService().log('   (Keine Dateien im Root-Ordner)');
      } else {
        for (int i = 0; i < rootFiles.length && i < 10; i++) { // Max 10 Dateien loggen
          final file = rootFiles[i];
          final isZip = file.toLowerCase().endsWith('.zip');
          await AppLogService().log('   📄 $file${isZip ? ' ← ZIP!' : ''}');
        }
        if (rootFiles.length > 10) {
          await AppLogService().log('   ... und ${rootFiles.length - 10} weitere Dateien');
        }
      }

      // 4. Test: Ordner im Basis-Ordner auflisten
      await AppLogService().log('📁 Teste listFolders("${creds.baseFolder}")...');
      final rootFolders = await webdavClient.listFolders(creds.baseFolder);
      
      await AppLogService().log('✅ listFolders erfolgreich!');
      await AppLogService().log('   Gefundene Ordner: ${rootFolders.length}');
      
      // Ordner loggen mit Backup-Detection
      if (rootFolders.isEmpty) {
        await AppLogService().log('   (Keine Ordner im Root-Ordner)');
      } else {
        for (int i = 0; i < rootFolders.length && i < 10; i++) { // Max 10 Ordner loggen
          final folder = rootFolders[i];
          final isBackupFolder = folder.startsWith('backup_');
          await AppLogService().log('   📁 $folder${isBackupFolder ? ' ← Backup-Ordner!' : ''}');
        }
        if (rootFolders.length > 10) {
          await AppLogService().log('   ... und ${rootFolders.length - 10} weitere Ordner');
        }
      }

      // 5. ZIP-Dateien suchen
      final zipFiles = <String>[];
      
      // In Root-Dateien
      for (final file in rootFiles) {
        if (file.toLowerCase().endsWith('.zip')) {
          zipFiles.add('ROOT/$file');
        }
      }
      
      // In ALLEN Unterordnern suchen (nicht nur backup_*)
      await AppLogService().log('🗃️ Durchsuche ALLE ${rootFolders.length} Ordner nach ZIP-Dateien...');
      
      for (final folder in rootFolders) {
        try {
          final subFiles = await webdavClient.listFiles(folder);
          final zipFilesInFolder = <String>[];
          
          for (final file in subFiles) {
            if (file.toLowerCase().endsWith('.zip')) {
              zipFiles.add('$folder/$file');
              zipFilesInFolder.add(file);
            }
          }
          
          final isBackupFolder = folder.startsWith('backup_');
          final zipInfo = zipFilesInFolder.isNotEmpty ? ' → ${zipFilesInFolder.length} ZIP-Dateien!' : '';
          await AppLogService().log('   📁 $folder: ${subFiles.length} Dateien$zipInfo${isBackupFolder ? ' (Backup-Ordner)' : ''}');
          
          // Alle Dateien im Ordner loggen wenn ZIP gefunden
          if (zipFilesInFolder.isNotEmpty) {
            for (final file in subFiles.take(5)) { // Max 5 Dateien
              final isZip = file.toLowerCase().endsWith('.zip');
              await AppLogService().log('      📄 $file${isZip ? ' ← ZIP!' : ''}');
            }
          }
        } catch (e) {
          await AppLogService().logError('   ❌ Fehler in Ordner $folder: $e');
        }
      }

      await AppLogService().log('🗜️ Gefundene ZIP-Dateien: ${zipFiles.length}');
      for (final zip in zipFiles) {
        await AppLogService().log('   🗜️ $zip');
      }

      await AppLogService().log('🎉 Test erfolgreich abgeschlossen!');
      
      // Erfolgs-Message
      if (!context.mounted) return;
      final summary = 'Verbindung erfolgreich!\n'
          'Dateien: ${rootFiles.length}\n'
          'Ordner: ${rootFolders.length}\n'
          'ZIP-Backups: ${zipFiles.length}';
      _showResult(context, true, summary);

    } catch (e, stackTrace) {
      await AppLogService().logError('💥 Test fehlgeschlagen: $e');
      await AppLogService().logError('StackTrace: $stackTrace');
      
      if (!context.mounted) return;
      _showResult(context, false, 'Verbindungstest fehlgeschlagen:\n$e');
    }
  }

  /// Zeigt das Testergebnis in einer SnackBar an
  static void _showResult(BuildContext context, bool success, String message) {
    // Vorherige SnackBar entfernen
    ScaffoldMessenger.of(context).clearSnackBars();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Logs',
          textColor: Colors.white,
          onPressed: () {
            // Hier könnte eine Log-Anzeige geöffnet werden
            // Oder Navigation zu einer Log-Seite
          },
        ),
      ),
    );
  }

  /// Erstellt einen Test-Button für die UI
  static Widget buildTestButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => testListFiles(context),
      icon: const Icon(Icons.cloud_download),
      label: const Text('Test Nextcloud Verbindung'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Erstellt einen Test-ListTile für Einstellungen
  static Widget buildTestListTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bug_report, color: Colors.orange),
      title: const Text('Nextcloud Verbindung testen'),
      subtitle: const Text('Prüft listFiles und listFolders Methoden'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () => testListFiles(context),
    );
  }

  /// Debug-Methode für Raw XML-Antwort von PROPFIND
  static Future<void> _debugListFilesRaw(NextcloudWebDavClient webdavClient, String remoteFolderPath) async {
    try {
      await AppLogService().log('🔬 DEBUG: Rohe PROPFIND-Anfrage...');
      
      // Direkte HTTP-Anfrage (kopiert aus NextcloudWebDavClient)
      
      final config = webdavClient.config;
      final targetUri = config.webDavRoot.resolve(remoteFolderPath);
      final client = http.Client();
      
      final authBytes = utf8.encode('${config.username}:${config.appPassword}');
      final authHeader = 'Basic ${base64Encode(authBytes)}';
      
      final request = http.Request('PROPFIND', targetUri);
      request.headers.addAll({
        'Authorization': authHeader,
        'Depth': '1',
        'Content-Type': 'application/xml',
      });
      request.body = '''<?xml version="1.0"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:displayname/>
  </d:prop>
</d:propfind>''';
      
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      client.close();

      await AppLogService().log('📡 Status Code: ${response.statusCode}');
      await AppLogService().log('📄 Response Length: ${response.body.length} Zeichen');
      
      // Ersten 1000 Zeichen der XML-Antwort loggen
      final xmlSnippet = response.body.length > 1000 
          ? '${response.body.substring(0, 1000)}...[GEKÜRZT]'
          : response.body;
      await AppLogService().log('🔍 XML Response:\n$xmlSnippet');
      
      // Manuelles Parsen und Zählen
      final lines = response.body.split('\n');
      int displayNameCount = 0;
      final foundFiles = <String>[];
      
      for (final line in lines) {
        if (line.contains('<d:displayname>') && line.contains('</d:displayname>')) {
          displayNameCount++;
          final start = line.indexOf('<d:displayname>') + 15;
          final end = line.indexOf('</d:displayname>');
          if (start < end) {
            final filename = line.substring(start, end).trim();
            if (filename.isNotEmpty && filename != remoteFolderPath) {
              foundFiles.add(filename);
            }
          }
        }
      }
      
      await AppLogService().log('🧮 Gefundene <d:displayname> Tags: $displayNameCount');
      await AppLogService().log('📋 Extrahierte Dateinamen: ${foundFiles.length}');
      
      for (int i = 0; i < foundFiles.length && i < 10; i++) {
        await AppLogService().log('   → ${foundFiles[i]}');
      }
      if (foundFiles.length > 10) {
        await AppLogService().log('   ... und ${foundFiles.length - 10} weitere');
      }
      
    } catch (e) {
      await AppLogService().logError('❌ Debug PROPFIND Fehler: $e');
    }
  }
}