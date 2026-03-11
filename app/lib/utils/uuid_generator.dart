// lib/utils/uuid_generator.dart
//
// Zentrale UUID-Generierung für die gesamte App.
// Ersetzt die doppelte _generateUUID() Implementierung
// in artikel_model.dart und artikel_db_service.dart.
//
// Verwendet das 'uuid' Package (v4 = kryptografisch sicher).

import 'package:uuid/uuid.dart';

class UuidGenerator {
  // Private Konstruktor – nur statische Methoden
  UuidGenerator._();

  static const _uuid = Uuid();

  /// Generiert eine neue UUID v4 (kryptografisch sicher).
  /// Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
  ///
  /// Beispiel: "550e8400-e29b-41d4-a716-446655440000"
  static String generate() => _uuid.v4();

  /// Prüft ob ein String eine gültige UUID ist.
  static bool isValid(String uuid) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }
}