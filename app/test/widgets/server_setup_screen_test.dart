import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lager_app/screens/server_setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'prefills URL field with saved pocketbase_url',
    (tester) async {
      SharedPreferences.setMockInitialValues(
        {'pocketbase_url': 'https://saved.example.com'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ServerSetupScreen(
            onConfigured: () {},
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textFormField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Server-URL'),
      );

      expect(textFormField.controller?.text, 'https://saved.example.com');
    },
  );

  testWidgets(
    'does not overwrite user input while prefill resolves',
    (tester) async {
      SharedPreferences.setMockInitialValues(
        {'pocketbase_url': 'https://saved.example.com'},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ServerSetupScreen(
            onConfigured: () {},
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Server-URL'),
        'https://typed.example.com',
      );
      await tester.pumpAndSettle();

      final textFormField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Server-URL'),
      );

      expect(textFormField.controller?.text, 'https://typed.example.com');
    },
  );
}
