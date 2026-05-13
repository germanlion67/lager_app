// lib/services/scan_service_stub.dart
//
// Web/Desktop-Fallback: Kein Kamera-Scanner verfügbar.
// Zeigt einen Artikelnummer-Eingabe-Dialog.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart'; // ← NEU (O-017)

import '../services/app_log_service.dart'; // ← NEU (O-017)
import '../services/artikel_db_service.dart';
import '../services/scan_result.dart';
import '../models/artikel_model.dart';
import '../services/pocketbase_service.dart';
import '../screens/artikel_detail_screen.dart';


final Logger _logger = AppLogService.logger; // ← NEU (O-017)

/// Öffnet einen Artikelnummer-Eingabe-Dialog als Fallback für Web/Desktop.
Future<Object?> openQrScanner(
  BuildContext context,
  ArtikelDbService db,
) async {
  return _zeigeArtikelnummerDialog(context, db);
}

Future<Object?> _zeigeArtikelnummerDialog(
  BuildContext context,
  ArtikelDbService db,
) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final String? eingabe = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.search),
          SizedBox(width: 8),
          Text('Artikel suchen'),
        ],
      ),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QR-Scanner ist auf dieser Plattform nicht verfügbar.\n'
              'Bitte Artikelnummer eingeben:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              autofocus: true,
              // Nur Ziffern erlauben
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Artikelnummer',
                hintText: 'z.B. 1042',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Bitte Artikelnummer eingeben';
                }
                final nr = int.tryParse(value.trim());
                if (nr == null || nr < 1000) {
                  return 'Artikelnummern beginnen bei 1000';
                }
                return null;
              },
              onFieldSubmitted: (_) {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(controller.text.trim());
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Abbrechen'),
        ),
        FilledButton.icon(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.of(ctx).pop(controller.text.trim());
            }
          },
          icon: const Icon(Icons.search),
          label: const Text('Suchen'),
        ),
      ],
    ),
  );

  controller.dispose();

  if (eingabe == null || !context.mounted) {
    return const ScanResultCancelled();
  }

  final int artikelnummer = int.parse(eingabe); // Validator hat int sichergestellt

  try {
    // B-018: Plattformabhängige Artikelsuche
    final Artikel? gefunden = kIsWeb
        ? await _sucheArtikelWeb(artikelnummer)
        : await _sucheArtikelLokal(db, artikelnummer);

    if (!context.mounted) return const ScanResultCancelled();

    if (gefunden == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kein Artikel mit Artikelnummer $artikelnummer gefunden',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return const ScanResultCancelled();
    }

    // Detail-Screen öffnen
    final detailResult = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => ArtikelDetailScreen(artikel: gefunden),
      ),
    );

    if (!context.mounted) return const ScanResultCancelled();

    if (detailResult is Artikel) {
      return ScanResultArtikel(detailResult);
    } else if (detailResult == 'deleted') {
      return ScanResultDeleted(gefunden.uuid);
    } else {
      return const ScanResultCancelled();
    }
  } catch (e, st) {
    _logger.e('Artikelsuche fehlgeschlagen:', error: e, stackTrace: st);
    return ScanResultError(e.toString());
  }
}

/// B-018: Suche über PocketBase (Web)
Future<Artikel?> _sucheArtikelWeb(int artikelnummer) async {
  final pb = PocketBaseService().client;
  final result = await pb.collection('artikel').getList(
    filter: 'artikelnummer = $artikelnummer && deleted = false',
    perPage: 1,
  );

  if (result.items.isEmpty) return null;

  final record = result.items.first;
  return Artikel.fromPocketBase(
    record.data,
    record.id,
    created: record.get<String>('created'),
    updated: record.get<String>('updated'),
  );
}

/// B-018: Suche über lokale SQLite-DB (Mobile/Desktop)
Future<Artikel?> _sucheArtikelLokal(
  ArtikelDbService db,
  int artikelnummer,
) async {
  final alleArtikel = await db.getAlleArtikel();
  return alleArtikel.cast<Artikel?>().firstWhere(
        (a) => a?.artikelnummer == artikelnummer,
        orElse: () => null,
      );
}