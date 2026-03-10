// lib/screens/_dokumente_button_stub.dart
// Web-Stub: Dokumente-Button ist nur auf Mobile verfügbar

import 'package:flutter/material.dart';

class DokumenteButton extends StatelessWidget {
  final int? artikelId;

  const DokumenteButton({super.key, required this.artikelId});

  @override
  Widget build(BuildContext context) {
    // Im Web nicht anzeigen
    return const SizedBox.shrink();
  }
}