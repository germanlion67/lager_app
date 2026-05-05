// test/services/artikel_export_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:lager_app/services/artikel_export_service.dart';
import 'package:lager_app/services/app_log_service.dart';
import 'package:logger/logger.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

// Test-Implementierung für FileSelectorPlatform
class TestFileSelectorPlatform extends FileSelectorPlatform {
  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    return const FileSaveLocation('test.zip');
  }
}

void main() {
  late ArtikelExportService exportService;

  setUp(() {
    exportService = ArtikelExportService();
    FileSelectorPlatform.instance = TestFileSelectorPlatform();
    // Vorherige Log-Einträge löschen
    AppLogService.memoryOutput.buffer.clear();
  });

  testWidgets('backupToZipFile gibt null zurück, wenn keine Artikel vorhanden',
      (WidgetTester tester) async {
    await tester.pumpWidget(Container());
    final context = tester.element(find.byType(Container));
    final result = await exportService.backupToZipFile(context);
    expect(result, isNull);
  }, skip: true,); // Test hängt — UI-Abhängigkeit

  test('backupZipToNextcloud fängt Fehler ab und loggt sie', () async {
    final fakePath = 'not_existing.zip';

    // Sollte NICHT werfen — Fehler wird intern gefangen
    await exportService.backupZipToNextcloud(fakePath);

    // Prüfe: Es wurde ein Error-Log in den MemoryOutput geschrieben
    final errorLogs = AppLogService.memoryOutput.buffer
        .where((e) => e.level == Level.error)
        .toList();

    expect(errorLogs, isNotEmpty,
        reason: 'Es sollte ein Error-Log für den fehlgeschlagenen '
            'Nextcloud-Upload geschrieben werden',);

    // Prüfe: Mindestens ein Error-Log enthält "Nextcloud"
    final hasNextcloudRef = errorLogs.any(
      (e) => e.lines.any((line) => line.contains('Nextcloud')),
    );
    expect(hasNextcloudRef, isTrue,
        reason: 'Der Error-Log sollte "Nextcloud" enthalten',);
  });
}
