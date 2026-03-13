// lib/screens/list_screen_io.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Prüft ob eine Kamera verfügbar ist.
Future<bool> checkCamera() async {
  // Fix: Controller nach dem Check immer disposen — sonst Ressourcenleck
  final controller = MobileScannerController();
  try {
    await controller.start();
    return true;
  } catch (_) {
    return false;
  } finally {
    await controller.stop();
    await controller.dispose();
  }
}

/// Prüft ob eine lokale Datei existiert.
bool fileExists(String path) => File(path).existsSync();

/// Baut ein Image.file Widget.
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
    // Fix: errorBuilder — zeigt Placeholder statt rotem Fehler-Widget
    errorBuilder: (_, __, ___) => Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    ),
  );
}