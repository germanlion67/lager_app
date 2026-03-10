// lib/screens/list_screen_io.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Prüft ob eine Kamera verfügbar ist
Future<bool> checkCamera() async {
  try {
    final cameras = await availableCameras();
    return cameras.isNotEmpty;
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
    errorBuilder: (_, __, ___) => Container(
      width: width ?? 50,
      height: height ?? 50,
      color: Colors.grey[300],
      child: const Icon(Icons.broken_image, color: Colors.grey),
    ),
  );
}
