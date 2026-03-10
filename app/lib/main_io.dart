// lib/main_io.dart
// Plattform-spezifische Initialisierung für Mobile/Desktop

import 'dart:io' show Platform;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initialisiert SQLite FFI für Desktop-Plattformen.
/// Auf Android/iOS ist keine Initialisierung nötig.
void initDesktopDatabase() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
