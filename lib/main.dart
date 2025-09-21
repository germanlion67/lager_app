//lib/main.dart

//Startpunkt der App
//Lädt die Artikelliste als Hauptansicht
//Kann später mit Routing zu weiteren Seiten erweitert werden (z. B. Detailansicht, QR-Scan, Einstellungen)

import 'package:flutter/material.dart';
import 'screens/artikel_list_screen.dart';
import 'services/artikel_db_service.dart';in.dart

//Startpunkt der App
//Lädt die Artikelliste als Hauptansicht
//Kann später mit Routing zu weiteren Seiten erweitert werden (z. B. Detailansicht, QR-Scan, Einstellungen)

import 'package:flutter/material.dart';
import 'screens/artikel_list_screen.dart';

// ffi imports (nur für Desktop notwendig)
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Web braucht nichts, dort funktioniert sqflite nicht
  if (!kIsWeb) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // FFI initialisieren für Desktop
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    // Android/iOS → normales sqflite, keine Init notwendig
  }

  runApp(const MyApp());
}


class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      // App wird beendet - Datenbank sauber schließen
      _cleanupResources();
    }
  }

  Future<void> _cleanupResources() async {
    try {
      final dbService = ArtikelDbService();
      await dbService.closeDatabase();
    } catch (e) {
      // Fehler beim Cleanup ignorieren, da App bereits beendet wird
      print('Cleanup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elektronik Verwaltung',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        inputDecorationTheme: const InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.black), // Label-Schriftfarbe
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),   // Textfarbe groß
          bodyMedium: TextStyle(color: Colors.black),  // Textfarbe mittel
          bodySmall: TextStyle(color: Colors.black),   // Textfarbe klein
        ),
      ),
      home: const ArtikelListScreen(),
    );
  }
}
