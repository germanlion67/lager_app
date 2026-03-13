// test/services/nextcloud_listfiles_test.dart

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
        (results['errors'] as List<String>).add('Keine Nextcloud-Zugangsdaten gefunden');
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
        (results['statistics'] as Map<String, int>)['rootFileCount'] = rootFiles.length;
        
        await AppLogService().log('✅ Gefundene Root-Dateien: ${rootFiles.length}');
        for (final file in rootFiles) {
          await AppLogService().log('   📄 $file');
          if (file.toLowerCase().endsWith('.zip')) {
            (results['zipFiles'] as List<String>).add('ROOT/$file');
          }
        }
      } catch (e) {
        final error = 'Fehler beim Auflisten der Root-Dateien: $e';
        (results['errors'] as List<String>).add(error);
        await AppLogService().logError('❌ $error');
      }

      // 4. Test 2: Root-Ordner auflisten
      await AppLogService().log('\n--- TEST 2: Root-Ordner (${creds.baseFolder}) ---');
      try {
        final rootFolders = await webdavClient.listFolders(creds.baseFolder);
        results['rootFolders'] = rootFolders;
        (results['statistics'] as Map<String, int>)['rootFolderCount'] = rootFolders.length;
        
        await AppLogService().log('✅ Gefundene Root-Ordner: ${rootFolders.length}');
        for (final folder in rootFolders) {
          await AppLogService().log('   📁 $folder');
        }
      } catch (e) {
        final error = 'Fehler beim Auflisten der Root-Ordner: $e';
        (results['errors'] as List<String>).add(error);
        await AppLogService().logError('❌ $error');
      }

      // 5. Test 3: Unterordner durchsuchen
      await AppLogService().log('\n--- TEST 3: Unterordner durchsuchen ---');
      int totalSubFiles = 0;

      // FIX: Cast auf List<String> — results['rootFolders'] ist dynamic
      for (final folder in results['rootFolders'] as List<String>) {
        try {
          await AppLogService().log('Durchsuche Ordner: $folder');
          final subFiles = await webdavClient.listFiles(folder);
          // FIX: Cast auf Map<String, List<String>> vor dem Zugriff
          (results['subFiles'] as Map<String, List<String>>)[folder] = subFiles;
          totalSubFiles += subFiles.length;

          await AppLogService().log('  ✅ Dateien in "$folder": ${subFiles.length}');
          for (final file in subFiles) {
            await AppLogService().log('     📄 $file');
            if (file.toLowerCase().endsWith('.zip')) {
              (results['zipFiles'] as List<String>).add('$folder/$file');
            }
          }
        } catch (e) {
          final warning = 'Warnung: Ordner "$folder" konnte nicht gelesen werden: $e';
          (results['warnings'] as List<String>).add(warning);
          await AppLogService().logError('⚠️ $warning');
        }
      }

      (results['statistics'] as Map<String, int>)['totalSubFiles'] = totalSubFiles;
      (results['statistics'] as Map<String, int>)['totalZipFiles'] =
          (results['zipFiles'] as List<String>).length;

      // 6. Test 4: Spezielle Backup-Ordner prüfen
      await AppLogService().log('\n--- TEST 4: Backup-Ordner Analysis ---');
      final backupFolders = (results['rootFolders'] as List<String>)
          // FIX: expliziter Parametertyp — Dart kann (f) nicht inferieren
          .where((String f) => f.startsWith('backup_'))
          .toList();
      
      (results['statistics'] as Map<String, int>)['backupFolderCount'] =
          backupFolders.length;
      await AppLogService().log('Backup-Ordner (backup_*): ${backupFolders.length}');
      
      // FIX: subFiles einmal casten — alle nachgelagerten Zugriffe typsicher
      final subFilesMap = results['subFiles'] as Map<String, List<String>>;

      for (final backupFolder in backupFolders) {
        await AppLogService().log('  📅 $backupFolder');
        if (subFilesMap.containsKey(backupFolder)) {
          final files = subFilesMap[backupFolder]!;
          // FIX: expliziter Parametertyp (String f) — non_bool_operand
          final hasJson = files.any((String f) => f.toLowerCase().endsWith('.json'));
          final hasImages = files.any((String f) =>
              f.toLowerCase().contains('images') ||
              f.toLowerCase().endsWith('.jpg') ||
              f.toLowerCase().endsWith('.png'),);
          await AppLogService().log(
            '    JSON: ${hasJson ? '✅' : '❌'}, Bilder: ${hasImages ? '✅' : '❌'}',
          );
        }
      }

      // 7. Zusammenfassung
      final stats = results['statistics'] as Map<String, int>;
      await AppLogService().log('\n--- TEST ZUSAMMENFASSUNG ---');
      await AppLogService().log('Root-Dateien: ${stats['rootFileCount'] ?? 0}');
      await AppLogService().log('Root-Ordner: ${stats['rootFolderCount'] ?? 0}');
      await AppLogService().log('Dateien in Unterordnern: ${stats['totalSubFiles'] ?? 0}');
      await AppLogService().log('ZIP-Dateien gesamt: ${stats['totalZipFiles'] ?? 0}');
      await AppLogService().log('Backup-Ordner: ${stats['backupFolderCount'] ?? 0}');
      await AppLogService().log('Fehler: ${(results['errors'] as List<String>).length}');
      await AppLogService().log('Warnungen: ${(results['warnings'] as List<String>).length}');

      // Test als erfolgreich markieren wenn keine kritischen Fehler
      // FIX: Cast auf List<String> — .isEmpty auf dynamic ist non_bool_condition
      results['success'] = (results['errors'] as List<String>).isEmpty;

      if (results['success'] as bool) {
        await AppLogService().log('\n✅ TEST ERFOLGREICH ABGESCHLOSSEN');
      } else {
        await AppLogService().log('\n❌ TEST MIT FEHLERN ABGESCHLOSSEN');
        // FIX: Cast auf List<String> — for-in auf dynamic schlägt fehl
        for (final error in results['errors'] as List<String>) {
          await AppLogService().logError('  - $error');
        }
      }

    } catch (e, stackTrace) {
      final error = 'Kritischer Testfehler: $e';
      (results['errors'] as List<String>).add(error);
      results['success'] = false;
      await AppLogService().logError('💥 $error');
      await AppLogService().logError('StackTrace: $stackTrace');
    }

    await AppLogService().log('=== NEXTCLOUD LISTFILES TEST BEENDET ===\n');
    return results;
  }

  /// Führt einen Test durch und zeigt die Ergebnisse in einer SnackBar an
  static Future<void> runTestWithUI(BuildContext context) async {
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
    
    if (!context.mounted) return;

    final success = results['success'] as bool;
    final zipCount = (results['zipFiles'] as List<String>).length;
    final errorCount = (results['errors'] as List<String>).length;
    final warningCount = (results['warnings'] as List<String>).length;

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

    // FIX: showDialog<void> — explizites Typargument
    showDialog<void>(
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
              if ((results['errors'] as List<String>).isNotEmpty)
                _buildResultSection('❌ Fehler', results['errors']),
              if ((results['warnings'] as List<String>).isNotEmpty)
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
      final results = await NextcloudListFilesTest.runListFilesTest();

      // Basis-Assertions
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
      
      // ignore: avoid_print
      print('Test Results: $results');
    }, skip: true,); // Test hängt - Nextcloud-Abhängigkeit
  });
}