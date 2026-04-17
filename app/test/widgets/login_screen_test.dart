import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lager_app/config/app_config.dart';
import 'package:lager_app/screens/login_screen.dart';
import 'package:lager_app/services/pocketbase_service.dart';

class _SlowLoginService extends PocketBaseService {
  _SlowLoginService() : super.testable();

  @override
  Future<bool> login(String email, String password) async {
    await Future<void>.delayed(
      AppConfig.loginTimeout + const Duration(seconds: 1),
    );
    return true;
  }
}

void main() {
  testWidgets('zeigt Timeout-Fehler und beendet den Ladezustand',
      (tester) async {
    var onLoginSuccessCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          onLoginSuccess: () => onLoginSuccessCalled = true,
          pocketBaseService: _SlowLoginService(),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'E-Mail'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passwort'),
      '123456',
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Anmelden'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(AppConfig.loginTimeout + const Duration(seconds: 1));
    await tester.pump();

    expect(find.textContaining('Zeitüberschreitung beim Login'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Anmelden'), findsOneWidget);
    expect(onLoginSuccessCalled, isFalse);
  });
}
