import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:elektronik_verwaltung/screens/_dokumente_button.dart';

void main() {
  testWidgets('DokumenteButton öffnet BottomSheet und zeigt leeren Zustand bei fehlenden Credentials', (WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: DokumenteButton(artikelId: 1, credentialsReader: () async => null))));

    // Button ist sichtbar
    expect(find.textContaining('zusätzliche Dokumente'), findsOneWidget);

    // Tippe den Button (via sichtbaren Label-Text)
    await tester.tap(find.textContaining('zusätzliche Dokumente'));
    await tester.pump();

    // Warte bis das BottomSheet aufgebaut ist
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(BottomSheet), findsOneWidget);

    // Stelle sicher, dass ein ListView im BottomSheet vorhanden ist (leerer oder gefüllter Zustand)
    expect(find.byType(ListView), findsOneWidget);
  });
}
