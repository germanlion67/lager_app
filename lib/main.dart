//lib/main.dart

//Startpunkt der App
//Lädt die Artikelliste als Hauptansicht
//Kann später mit Routing zu weiteren Seiten erweitert werden (z. B. Detailansicht, QR-Scan, Einstellungen)


import 'package:flutter/material.dart';
import 'screens/artikel_list_screen.dart';

void main() {
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
