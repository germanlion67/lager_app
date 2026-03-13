// lib/services/artikel_db_platform_stub.dart
//
// Web-Stub – wird im Web importiert, aber nie aufgerufen.
// ArtikelDbService wirft im Web einen UnsupportedError bevor
// diese Funktionen erreicht werden.
//
// Hinweis: Der sqflite-Import ist notwendig, damit die Signatur von
// openArtikelDatabase() mit der _io.dart-Variante übereinstimmt.
// Dart kompiliert beim Conditional Import nur die jeweils passende Datei,
// daher verursacht dieser Import auf Web-Targets keine Laufzeitprobleme.

import 'package:sqflite/sqflite.dart';

// FIX Hinweis 2: Im Web ist die Plattform nie Desktop — return false
// ist semantisch korrekt und verhindert einen unnötigen Crash,
// falls die Funktion versehentlich direkt aufgerufen wird.
bool isDesktopPlatform() => false;

Future<Database> openArtikelDatabase({
  required int version,
  required Future<void> Function(Database, int) onCreate,
  required Future<void> Function(Database, int, int) onUpgrade,
}) {
  throw UnsupportedError('openArtikelDatabase() ist im Web nicht verfügbar');
}