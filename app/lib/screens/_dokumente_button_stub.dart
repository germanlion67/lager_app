// lib/screens/_dokumente_button_stub.dart

// M-012: DokumenteButton durch _AnhängeSektion in artikel_detail_screen.dart
// ersetzt. Diese Datei wird nicht mehr importiert und kann in einem
// späteren Cleanup-Ticket entfernt werden.
// TODO: M-012-Cleanup — Datei und Stub löschen wenn Nextcloud-Integration
// endgültig entfällt.

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