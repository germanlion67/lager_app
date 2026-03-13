// lib/services/database_service.dart
//
// ⚠️  DEPRECATED — wird in einer zukünftigen Version entfernt.
//
// Alle Aufrufe auf PocketBaseService migrieren:
//
//   Vorher:  DatabaseService.pb.collection('artikel')...
//   Nachher: PocketBaseService().client.collection('artikel')...
//
// Diese Datei existiert nur noch als Kompatibilitäts-Shim,
// damit bestehende Aufrufe nicht sofort brechen.

import 'package:pocketbase/pocketbase.dart';
import 'pocketbase_service.dart';

@Deprecated(
  'Nutze PocketBaseService().client statt DatabaseService.pb. '
  'DatabaseService wird in einer zukünftigen Version entfernt.',
)
class DatabaseService {
  DatabaseService._();

  /// @deprecated Nutze PocketBaseService().client
  @Deprecated('Nutze PocketBaseService().client')
  static PocketBase get pb => PocketBaseService().client;
}