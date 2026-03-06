//lib/service/pocketbase_sync_service.dart

//import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:logger/logger.dart';
import 'pocketbase_service.dart';
import 'artikel_db_service.dart';
import '../models/artikel_model.dart';
import 'app_log_service.dart';

class PocketBaseSyncService {
  final _dbService = ArtikelDbService();
  final _logger = Logger();
  final _logService = AppLogService();
  final String _collection = 'artikel';

  /// Führt einen vollständigen Abgleich durch (Zwei-Wege-Sync)
  Future<void> syncAll() async {
    if (kIsWeb) return; // Web nutzt PB direkt, kein Sync nötig

    try {
      await _logService.log('[Sync] Starte PocketBase Abgleich...');
      
      // 1. Lokale Änderungen -> PocketBase
      final pending = await _dbService.getPendingChanges();
      for (var artikel in pending) {
        await _pushToPocketBase(artikel);
      }

      // 2. PocketBase Änderungen -> Lokal
      await _pullFromPocketBase();

      await _dbService.setLastSyncTime();
      await _logService.log('[Sync] Abgleich erfolgreich beendet.');
    } catch (e, stack) {
      await _logService.logError('Sync-Fehler: $e', stack);
    }
  }

  Future<void> _pushArtikel(Artikel artikel) async {
    try {
      final col = PocketBaseService.client.collection('artikel');
      final result = await col.getList(filter: 'uuid = "${artikel.uuid}"');

      if (result.items.isEmpty) {
        await col.create(body: artikel.toMap());
      } else {
        final remote = result.items.first;
        final int remoteTs = remote.data['updated_at'] ?? 0;
        
        // Nur pushen, wenn lokal neuer ist
        if (artikel.updatedAt > remoteTs) {
          await col.update(remote.id, body: artikel.toMap());
        }
      }
      // Als synchronisiert markieren
      await _dbService.markSynced(artikel.uuid, 'pb_synced');
    } catch (e) {
      _logger.w('Konnte Artikel ${artikel.name} nicht pushen: $e');
    }
  }

  Future<void> _pullArtikel() async {
    try {
      final records = await PocketBaseService.client.collection('artikel').getFullList();
      
      for (final record in records) {
        final remote = Artikel.fromMap(record.data);
        final lokal = await _dbService.getArtikelByUUID(remote.uuid);

        if (lokal == null) {
          // Unbekannter Artikel vom Server -> lokal einfügen
          await _dbService.insertArtikel(remote);
        } else if (remote.updatedAt > lokal.updatedAt) {
          // Server-Version ist neuer -> lokal updaten
          await _dbService.updateArtikel(remote.copyWith(id: lokal.id));
        }
      }
    } catch (e) {
      _logger.w('Fehler beim Abrufen von PocketBase: $e');
    }
  }
}