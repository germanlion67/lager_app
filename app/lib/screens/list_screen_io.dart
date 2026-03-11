// lib/screens/list_screen_io.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Prüft ob eine Kamera verfügbar ist
Future<bool> checkCamera() async {
  try {
    final controller = MobileScannerController();
    await controller.start();
    await controller.stop();
    return true;
  } catch (_) {
    return false;
  }
}

/// Prüft ob eine lokale Datei existiert
bool fileExists(String path) {
  return File(path).existsSync();
}

/// Baut ein Image.file Widget
Widget buildFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
  );
}
