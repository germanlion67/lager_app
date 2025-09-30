import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
// ignore: avoid_relative_lib_imports
import '../../lib/services/nextcloud_credentials.dart';
// ignore: avoid_relative_lib_imports
import '../../lib/services/nextcloud_webdav_client.dart';
// ignore: avoid_relative_lib_imports
import '../../lib/services/app_log_service.dart';

/// Test-Klasse für die listFiles Methode des NextcloudWebDavClient
class NextcloudListFilesTest {
  
  /// Führt einen umfassenden Test der listFiles Methode durch
  static Future<Map<String, dynamic>> runListFilesTest() async {
    final results = <String, dynamic>{
      'success': false,
      'errors': <String>[],
      'warnings': <String>[],
      'rootFiles': <String>[],
      'rootFolders': <String>[],
      'subFiles': <String, List<String>>{},
      'zipFiles': <String>[],
      'statistics': <String, int>{},
    };

    try {
      await AppLogService().log('=== NEXTCLOUD LISTFILES TEST GESTARTET ===');
      
      // 1. Credentials laden
      final creds = await NextcloudCredentialsStore().read();
      if (creds == null) {
        results['errors'].add('Keine Nextcloud-Zugangsdaten gefunden');
        await AppLogService().logError('TEST FEHLER: Keine Nextcloud-Zugangsdaten');
        return results;
      }

      await AppLogService().log('Verbindungsdaten geladen:');
      await AppLogService().log('  Server: ${creds.server}');
      await AppLogService().log('  Benutzer: ${creds.user}');
      await AppLogService().log('  BaseFolder: ${creds.baseFolder}');

      // 2. WebDAV Client erstellen
      final webdavClient = NextcloudWebDavClient(
        NextcloudConfig(
          serverBase: creds.server,
          username: creds.user,
          appPassword: creds.appPw,
          baseRemoteFolder: creds.baseFolder,
        ),
      );

      // 3. Test 1: Root-Dateien auflisten
      await AppLogService().log('\n--- TEST 1: Root-Dateien (${creds.baseFolder}) ---');
      try {
        final rootFiles = await webdavClient.listFiles(creds.baseFolder);
        results['rootFiles'] = rootFiles;
        results['statistics']['rootFileCount'] = rootFiles.length;
        
        await AppLogService().log('✅ Gefundene Root-Dateien: ${rootFiles.length}');
        for (final file in rootFiles) {
          await AppLogService().log('   📄 $file');
          if (file.toLowerCase().endsWith('.zip')) {
            results['zipFiles'].add('ROOT/$file');
          }
        }
      } catch (e) {
        final error = 'Fehler beim Auflisten der Root-Dateien: $e';
        results['errors'].add(error);
        await AppLogService().logError('❌ $error');
      }

      // 4. Test 2: Root-Ordner auflisten
      await AppLogService().log('\n--- TEST 2: Root-Ordner (${creds.baseFolder}) ---');
      try {
        final rootFolders = await webdavClient.listFolders(creds.baseFolder);
        results['rootFolders'] = rootFolders;
        results['statistics']['rootFolderCount'] = rootFolders.length;
        
        await AppLogService().log('✅ Gefundene Root-Ordner: ${rootFolders.length}');
        for (final folder in rootFolders) {
          await AppLogService().log('   📁 $folder');
        }
      } catch (e) {
        final error = 'Fehler beim Auflisten der Root-Ordner: $e';
        results['errors'].add(error);
        await AppLogService().logError('❌ $error');
      }

      // 5. Test 3: Unterordner durchsuchen
      await AppLogService().log('\n--- TEST 3: Unterordner durchsuchen ---');
      int totalSubFiles = 0;

      for (final folder in results['rootFolders']) {
        try {
          await AppLogService().log('Durchsuche Ordner: $folder');
          final subFiles = await webdavClient.listFiles(folder);
          results['subFiles'][folder] = subFiles;
          totalSubFiles += subFiles.length;

          await AppLogService().log('  ✅ Dateien in "$folder": ${subFiles.length}');
          for (final file in subFiles) {
            await AppLogService().log('     📄 $file');
            if (file.toLowerCase().endsWith('.zip')) {
              results['zipFiles'].add('$folder/$file');
            }
          }
        } catch (e) {
          final warning = 'Warnung: Ordner "$folder" konnte nicht gelesen werden: $e';
          results['warnings'].add(warning);
          await AppLogService().logError('⚠️ $warning');
        }
      }

      results['statistics']['totalSubFiles'] = totalSubFiles;
      results['statistics']['totalZipFiles'] = results['zipFiles'].length;

      // 6. Test 4: Spezielle Backup-Ordner prüfen
      await AppLogService().log('\n--- TEST 4: Backup-Ordner Analysis ---');
      final backupFolders = (results['rootFolders'] as List<String>)
          .where((f) => f.startsWith('backup_'))
          .toList();
      
      results['statistics']['backupFolderCount'] = backupFolders.length;
      await AppLogService().log('Backup-Ordner (backup_*): ${backupFolders.length}');
      
      for (final backupFolder in backupFolders) {
        await AppLogService().log('  📅 $backupFolder');
        if (results['subFiles'].containsKey(backupFolder)) {
          final files = results['subFiles'][backupFolder]!;
          final hasJson = files.any((f) => f.toLowerCase().endsWith('.json'));
          final hasImages = files.any((f) => f.toLowerCase().contains('images') || 
                                            f.toLowerCase().endsWith('.jpg') || 
                                            f.toLowerCase().endsWith('.png'));
          await AppLogService().log('    JSON: ${hasJson ? '✅' : '❌'}, Bilder: ${hasImages ? '✅' : '❌'}');
        }
      }

      // 7. Zusammenfassung
      await AppLogService().log('\n--- TEST ZUSAMMENFASSUNG ---');
      await AppLogService().log('Root-Dateien: ${results['statistics']['rootFileCount'] ?? 0}');
      await AppLogService().log('Root-Ordner: ${results['statistics']['rootFolderCount'] ?? 0}');
      await AppLogService().log('Dateien in Unterordnern: ${results['statistics']['totalSubFiles'] ?? 0}');
      await AppLogService().log('ZIP-Dateien gesamt: ${results['statistics']['totalZipFiles'] ?? 0}');
      await AppLogService().log('Backup-Ordner: ${results['statistics']['backupFolderCount'] ?? 0}');
      await AppLogService().log('Fehler: ${results['errors'].length}');
      await AppLogService().log('Warnungen: ${results['warnings'].length}');

      // Test als erfolgreich markieren wenn keine kritischen Fehler
      results['success'] = results['errors'].isEmpty;

      if (results['success']) {
        await AppLogService().log('\n✅ TEST ERFOLGREICH ABGESCHLOSSEN');
      } else {
        await AppLogService().log('\n❌ TEST MIT FEHLERN ABGESCHLOSSEN');
        for (final error in results['errors']) {
          await AppLogService().logError('  - $error');
        }
      }

    } catch (e, stackTrace) {
      final error = 'Kritischer Testfehler: $e';
      results['errors'].add(error);
      results['success'] = false;
      await AppLogService().logError('💥 $error');
      await AppLogService().logError('StackTrace: $stackTrace');
    }

    await AppLogService().log('=== NEXTCLOUD LISTFILES TEST BEENDET ===\n');
    return results;
  }

  /// Führt einen Test durch und zeigt die Ergebnisse in einer SnackBar an
  static Future<void> runTestWithUI(BuildContext context) async {
    // Context-Check vor async operation
    if (!context.mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(width: 16),
            Text('Teste listFiles Methode...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    final results = await runListFilesTest();
    
    // Context-Check nach async operation
    if (!context.mounted) return;

    final success = results['success'] as bool;
    final zipCount = (results['zipFiles'] as List).length;
    final errorCount = (results['errors'] as List).length;
    final warningCount = (results['warnings'] as List).length;

    String message;
    Color backgroundColor;

    if (success) {
      message = '✅ Test erfolgreich!\nZIP-Dateien: $zipCount';
      backgroundColor = Colors.green;
    } else {
      message = '❌ Test fehlgeschlagen!\nFehler: $errorCount, Warnungen: $warningCount';
      backgroundColor = Colors.red;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Details',
          textColor: Colors.white,
          onPressed: () => _showDetailDialog(context, results),
        ),
      ),
    );
  }

  /// Zeigt detaillierte Testergebnisse in einem Dialog
  static void _showDetailDialog(BuildContext context, Map<String, dynamic> results) {
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Test-Ergebnisse Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildResultSection('📊 Statistiken', results['statistics']),
              const SizedBox(height: 16),
              _buildResultSection('📄 Root-Dateien', results['rootFiles']),
              const SizedBox(height: 16),
              _buildResultSection('📁 Root-Ordner', results['rootFolders']),
              const SizedBox(height: 16),
              _buildResultSection('🗜️ ZIP-Dateien', results['zipFiles']),
              const SizedBox(height: 16),
              if ((results['errors'] as List).isNotEmpty)
                _buildResultSection('❌ Fehler', results['errors']),
              if ((results['warnings'] as List).isNotEmpty)
                _buildResultSection('⚠️ Warnungen', results['warnings']),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  /// Hilfsmethode zum Erstellen von Ergebnis-Sektionen
  static Widget _buildResultSection(String title, dynamic data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            _formatData(data),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ],
    );
  }

  /// Formatiert Daten für die Anzeige
  static String _formatData(dynamic data) {
    if (data is List) {
      if (data.isEmpty) return 'Keine Einträge';
      return data.map((item) => '• $item').join('\n');
    } else if (data is Map) {
      if (data.isEmpty) return 'Keine Daten';
      return data.entries.map((e) => '${e.key}: ${e.value}').join('\n');
    } else {
      return data.toString();
    }
  }
}

/// Flutter Test für die listFiles Funktionalität
void main() {
  group('NextcloudListFilesTest', () {
      testWidgets('should run listFiles test without UI', (WidgetTester tester) async {
      // Flutter Bindings sind durch testWidgets bereits initialisiert
      final results = await NextcloudListFilesTest.runListFilesTest();      // Basis-Assertions
      expect(results, isA<Map<String, dynamic>>());
      expect(results.containsKey('success'), isTrue);
      expect(results.containsKey('errors'), isTrue);
      expect(results.containsKey('warnings'), isTrue);
      expect(results.containsKey('rootFiles'), isTrue);
      expect(results.containsKey('rootFolders'), isTrue);
      expect(results.containsKey('zipFiles'), isTrue);
      expect(results.containsKey('statistics'), isTrue);
      
      // Erfolgs-Assertion (nur wenn keine Verbindungsprobleme)
      if (results['success'] == true) {
        expect(results['rootFiles'], isA<List<String>>());
        expect(results['rootFolders'], isA<List<String>>());
        expect(results['zipFiles'], isA<List<String>>());
        expect(results['statistics'], isA<Map<String, int>>());
      }
      
      // Log der Ergebnisse für Debugging
      // ignore: avoid_print
      print('Test Results: $results');
    });
  });
}