//lib/main.dart

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


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Elektronik Verwaltung',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ArtikelListScreen(),
    );
  }
}
