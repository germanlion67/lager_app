//test/services/artikel_export_service_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'artikel_export_service_test.mocks.dart';
import 'package:flutter/material.dart';
import 'package:elektronik_verwaltung/services/artikel_export_service.dart';
import 'package:elektronik_verwaltung/services/app_log_service.dart';
import 'package:elektronik_verwaltung/services/nextcloud_webdav_client.dart';

@GenerateMocks([AppLogService, NextcloudWebDavClient])
void main() {
  late ArtikelExportService exportService;
  late MockAppLogService mockLogService;
  late MockNextcloudWebDavClient mockWebDavClient;

  setUp(() {
    exportService = ArtikelExportService();
    mockLogService = MockAppLogService();
    mockWebDavClient = MockNextcloudWebDavClient();
  });

  testWidgets('backupToZipFile gibt null zurück, wenn keine Artikel vorhanden',
      (WidgetTester tester) async {
    await tester.pumpWidget(Container());
    final context = tester.element(find.byType(Container));
    final result = await exportService.backupToZipFile(context);
    expect(result, isNull);
  });

  test('backupZipToNextcloud loggt Fehler, wenn Datei nicht existiert',
      () async {
    final fakePath = 'not_existing.zip';
    await exportService.backupZipToNextcloud(fakePath);
    // Hier könnte geprüft werden, ob ein Log-Eintrag erfolgt ist
  });
}
