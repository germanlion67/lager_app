// lib/screens/detail_screen_stub.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';

Future<String?> persistSelectedImage({
  Uint8List? bildBytes,
  String? bildPfad,
  required int artikelId,
  required String artikelName,
  Future<void> Function(String)? onThumbnailSaved,
}) async =>
    null; // Im Web nicht nötig

Future<Uint8List> readFileBytes(String path) async =>
    throw UnsupportedError('readFileBytes ist im Web nicht verfügbar');

/// M-013: No-op auf Web — keine lokalen Dateien.
Future<void> deleteFileIfExists(String path) async {}    

bool fileExists(String path) => false;

Widget buildFileImage(
  String path, {
  double? height,
  double? width,
  BoxFit? fit,
}) =>
    const SizedBox.shrink();
