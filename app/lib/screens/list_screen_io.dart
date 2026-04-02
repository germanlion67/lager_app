// lib/screens/list_screen_io.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Prüft ob eine Kamera verfügbar ist (mit Timeout).
Future<bool> checkCamera() async {
  final controller = MobileScannerController();
  try {
    await controller.start().timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Kamera-Start Timeout'),
    );
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
///
/// Hinweis: Colors.grey[300] und Colors.grey im errorBuilder sind
/// Platzhalter-Farben für fehlgeschlagene Bildanzeige. Da diese Funktion
/// keinen BuildContext hat, können sie nicht über colorScheme gesteuert werden.
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
    errorBuilder: (_, __, ___) => Container(
      width: width,
      height: height,
      color: Colors.grey[300],
      child: const Icon(Icons.image_not_supported, color: Colors.grey),
    ),
  );
}