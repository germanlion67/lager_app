// lib/services/scan_result.dart

import '../models/artikel_model.dart';

/// Typsicheres Ergebnis eines QR-Scan-Vorgangs.
/// Ersetzt Magic Strings wie 'deleted' als Kommunikationsprotokoll.
sealed class ScanResult {
  const ScanResult();
}

/// Artikel wurde gescannt und gefunden oder neu erstellt.
final class ScanResultArtikel extends ScanResult {
  final Artikel artikel;
  const ScanResultArtikel(this.artikel);
}

/// Artikel wurde im Scanner-Screen gelöscht.
final class ScanResultDeleted extends ScanResult {
  final String uuid;
  const ScanResultDeleted(this.uuid);
}

/// Scanner wurde ohne Ergebnis geschlossen.
final class ScanResultCancelled extends ScanResult {
  const ScanResultCancelled();
}

/// Scanner-Fehler (z.B. Kamera-Permission verweigert).
final class ScanResultError extends ScanResult {
  final String message;
  const ScanResultError(this.message);
}