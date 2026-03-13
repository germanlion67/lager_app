// lib/screens/list_screen_stub.dart

import 'package:flutter/material.dart';

Future<bool> checkCamera() async => false;

bool fileExists(String path) => false;

Widget buildFileImage(
  String path, {
  double? width,
  double? height,
  BoxFit? fit,
}) =>
    const SizedBox.shrink();