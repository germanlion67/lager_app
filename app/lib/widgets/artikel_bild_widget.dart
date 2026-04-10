// lib/widgets/artikel_bild_widget.dart
//
// M-011: Zentrales Bild-Widget für Artikel.
//
// Strategie:
//   Liste  → Thumbnail (lokal: thumbnailPfad, web: ?thumb=1 Query-Param)
//   Detail → Vollbild  (lokal: bildPfad,      web: Original-URL)
//
// Caching:
//   - Lokal: Image.file mit RepaintBoundary (Flutter-intern gecacht)
//   - Web:   cached_network_image mit Disk- und Memory-Cache
//
// ⚠️ FIX: cacheKey enthält jetzt aktualisiertAm-Timestamp, damit nach
// Bildänderung das neue Bild geladen wird statt des gecachten alten.
//
// Hinweis: Colors.grey in Platzhalter-Widgets wird bewusst beibehalten,
// da die Platzhalter-Hintergrundfarben über AppImages gesteuert werden
// und das Icon eine neutrale Farbe benötigt.

import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_images.dart';
import '../models/artikel_model.dart';
import '../services/pocketbase_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ArtikelListBild
// Für die Listenansicht: kleines Thumbnail (50×50), gecacht.
// ─────────────────────────────────────────────────────────────────────────────

class ArtikelListBild extends StatelessWidget {
  final Artikel artikel;

  /// Größe des Thumbnails in der Liste (quadratisch).
  final double size;

  const ArtikelListBild({
    super.key,
    required this.artikel,
    this.size = AppConfig.artikelListBildSize,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusSmall),
        child: SizedBox(
          width: size,
          height: size,
          child: kIsWeb
              ? _WebThumbnail(artikel: artikel, size: size)
              : _LocalThumbnail(artikel: artikel, size: size),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ArtikelDetailBild
// Für die Detailansicht: Vollbild, tippbar für Vollbild-Overlay.
// ─────────────────────────────────────────────────────────────────────────────

class ArtikelDetailBild extends StatelessWidget {
  final Artikel artikel;

  /// Bytes eines neu gewählten (noch nicht gespeicherten) Bildes.
  final Uint8List? pendingBytes;

  /// Remote-URL (wird im Web nach dem Laden gesetzt).
  final String? remoteBildUrl;

  /// Wird aufgerufen wenn der Nutzer auf das Bild tippt.
  final VoidCallback? onTap;

  /// Höhe des Bild-Containers.
  final double height;

  const ArtikelDetailBild({
    super.key,
    required this.artikel,
    this.pendingBytes,
    this.remoteBildUrl,
    this.onTap,
    this.height = AppConfig.artikelDetailBildHoehe,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AppConfig.cardBorderRadiusLarge),
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
      // 1. Neu gewähltes Bild (noch nicht gespeichert) hat höchste Priorität
      if (pendingBytes != null) {
        return Image.memory(
          pendingBytes!,
          height: height,
          width: double.infinity,
          fit: AppConfig.artikelDetailBildFit,
        );
      }

      // 2. Web: Remote-URL via CachedNetworkImage
      if (kIsWeb) {
        if (remoteBildUrl != null) {
          return CachedNetworkImage(
            imageUrl: remoteBildUrl!,
            cacheKey: '${artikel.uuid}_detail_'
                '${artikel.aktualisiertAm.millisecondsSinceEpoch}',
            height: height,
            width: double.infinity,
            fit: AppConfig.artikelDetailBildFit,
            placeholder: (_, __) => _LoadingPlaceholder(height: height),
            errorWidget: (_, __, ___) => _Placeholder(height: height),
          );
        }
        return _Placeholder(height: height);
      }

      // 3. Mobile/Desktop: Lokaler Bildpfad (Vollbild)
      final pfad = artikel.bildPfad.isNotEmpty ? artikel.bildPfad : null;
      if (pfad != null && File(pfad).existsSync()) {
        return Image.file(
          File(pfad),
          height: height,
          width: double.infinity,
          fit: AppConfig.artikelDetailBildFit,
          cacheWidth: 800,
          errorBuilder: (_, __, ___) => _buildPbDetailFallback(),  // ← GEÄNDERT
        );
      }

      // 4. NEU: PocketBase-URL-Fallback für Detail (Kaltstart)
      return _buildPbDetailFallback();
    }

    /// PocketBase-URL-Fallback für die Detailansicht.
    Widget _buildPbDetailFallback() {
      final recordId = artikel.remotePath;
      final bildField = artikel.remoteBildPfad;

      if (recordId == null ||
          recordId.isEmpty ||
          bildField == null ||
          bildField.isEmpty) {
        return _Placeholder(height: height);
      }

      try {
        final pbService = PocketBaseService();
        if (!pbService.hasClient || pbService.url.isEmpty) {
          return _Placeholder(height: height);
        }

        final baseUri = Uri.parse(pbService.url);
        final url = baseUri
            .resolve(
              '/api/files/artikel/$recordId/${Uri.encodeComponent(bildField)}',
            )
            .toString();

        return CachedNetworkImage(
          imageUrl: url,
          cacheKey: '${artikel.uuid}_detail_pb_'
              '${artikel.aktualisiertAm.millisecondsSinceEpoch}',
          height: height,
          width: double.infinity,
          fit: AppConfig.artikelDetailBildFit,
          placeholder: (_, __) => _LoadingPlaceholder(height: height),
          errorWidget: (_, __, ___) => _Placeholder(height: height),
        );
      } catch (_) {
        return _Placeholder(height: height);
      }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Hilfs-Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Lokales Thumbnail für die Listenansicht.
/// Bevorzugt thumbnailPfad, fällt auf bildPfad zurück.
/// NEU: Falls keine lokale Datei existiert, wird ein PocketBase-URL-Fallback
/// über CachedNetworkImage verwendet (Kaltstart-Szenario).
class _LocalThumbnail extends StatelessWidget {
  final Artikel artikel;
  final double size;

  const _LocalThumbnail({required this.artikel, required this.size});

  @override
  Widget build(BuildContext context) {
    // 1. Lokales Thumbnail bevorzugen (schnellste Option)
    final thumbPfad = artikel.thumbnailPfad;
    if (thumbPfad != null &&
        thumbPfad.isNotEmpty &&
        File(thumbPfad).existsSync()) {
      return Image.file(
        File(thumbPfad),
        width: size,
        height: size,
        fit: AppConfig.artikelListBildFit,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (_, __, ___) => _fallbackBild(context),
      );
    }

    // 2. Lokales Vollbild als Fallback
    final bildPfad = artikel.bildPfad.isNotEmpty ? artikel.bildPfad : null;
    if (bildPfad != null && File(bildPfad).existsSync()) {
      return Image.file(
        File(bildPfad),
        width: size,
        height: size,
        fit: AppConfig.artikelListBildFit,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (_, __, ___) => _buildPbFallback(),
      );
    }

    // 3. NEU: PocketBase-URL als Fallback (Kaltstart — Bild noch nicht
    //    heruntergeladen, aber remoteBildPfad + remotePath vorhanden)
    return _buildPbFallback();
  }

  Widget _fallbackBild(BuildContext context) {
    final bildPfad = artikel.bildPfad.isNotEmpty ? artikel.bildPfad : null;
    if (bildPfad != null && File(bildPfad).existsSync()) {
      return Image.file(
        File(bildPfad),
        width: size,
        height: size,
        fit: AppConfig.artikelListBildFit,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (_, __, ___) => _buildPbFallback(),
      );
    }
    return _buildPbFallback();
  }

  /// PocketBase-URL-Fallback via CachedNetworkImage.
  /// Wird verwendet wenn keine lokale Datei existiert (Kaltstart).
  Widget _buildPbFallback() {
    final url = _buildPbThumbnailUrl();
    if (url == null) return _BildPlaceholder(size: size);

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: '${artikel.uuid}_local_thumb_'
          '${artikel.aktualisiertAm.millisecondsSinceEpoch}',
      width: size,
      height: size,
      fit: AppConfig.artikelListBildFit,
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      placeholder: (_, __) => _BildPlaceholder(size: size, loading: true),
      errorWidget: (_, __, ___) => _BildPlaceholder(size: size),
    );
  }

  /// Baut die PocketBase Thumbnail-URL (identisch zur Web-Logik).
  String? _buildPbThumbnailUrl() {
    final recordId = artikel.remotePath;
    final bildField = artikel.remoteBildPfad;

    if (recordId == null || recordId.isEmpty) return null;
    if (bildField == null || bildField.isEmpty) return null;

    try {
      final pbService = PocketBaseService();
      if (!pbService.hasClient || pbService.url.isEmpty) return null;

      final baseUri = Uri.parse(pbService.url);
      return baseUri
          .resolve(
            '/api/files/artikel/$recordId/${Uri.encodeComponent(bildField)}'
            '?thumb=${AppConfig.pbThumbGroesse}',
          )
          .toString();
    } catch (_) {
      return null;
    }
  }
}

/// Web-Thumbnail für die Listenansicht via CachedNetworkImage.
/// Nutzt PocketBase-URL mit automatischem Disk- und Memory-Cache.
class _WebThumbnail extends StatelessWidget {
  final Artikel artikel;
  final double size;

  const _WebThumbnail({required this.artikel, required this.size});

  @override
  Widget build(BuildContext context) {
    final url = _buildThumbnailUrl();
    if (url == null) return _BildPlaceholder(size: size);

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: '${artikel.uuid}_thumb_'
          '${artikel.aktualisiertAm.millisecondsSinceEpoch}',
      width: size,
      height: size,
      fit: AppConfig.artikelListBildFit,
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      placeholder: (_, __) => _BildPlaceholder(size: size, loading: true),
      errorWidget: (_, __, ___) => _BildPlaceholder(size: size),
    );
  }

  String? _buildThumbnailUrl() {
    final recordId = artikel.remotePath;
    final bildField = artikel.remoteBildPfad;

    if (recordId == null || recordId.isEmpty) return null;
    if (bildField == null || bildField.isEmpty) return null;

    final pbService = PocketBaseService();
    final baseUri = Uri.parse(pbService.url);

    return baseUri
        .resolve(
          '/api/files/artikel/$recordId/${Uri.encodeComponent(bildField)}'
          '?thumb=${AppConfig.pbThumbGroesse}',
        )
        .toString();
  }
}

/// Lade-Platzhalter für Detail-Bilder (Web).
class _LoadingPlaceholder extends StatelessWidget {
  final double? height;
  const _LoadingPlaceholder({this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppImages.ladePlatzhalterHintergrund,
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        strokeWidth: AppConfig.strokeWidthMedium,
      ),
    );
  }
}

/// Fehler-/Leer-Platzhalter für Detail-Bilder.
/// Hinweis: Colors.grey wird hier bewusst beibehalten — das Icon benötigt
/// eine neutrale Farbe, die auf dem AppImages-Hintergrund sichtbar ist.
class _Placeholder extends StatelessWidget {
  final double? height;
  const _Placeholder({this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: AppImages.platzhalterHintergrund,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported,
        size: AppImages.platzhalterIconGroesse,
        color: Colors.grey,
      ),
    );
  }
}

/// Kleiner Platzhalter für Listen-Thumbnails.
/// Hinweis: Colors.grey wird hier bewusst beibehalten — das Icon benötigt
/// eine neutrale Farbe, die auf dem AppImages-Hintergrund sichtbar ist.
class _BildPlaceholder extends StatelessWidget {
  final double size;
  final bool loading;
  const _BildPlaceholder({required this.size, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: AppImages.platzhalterHintergrundKlein,
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator(
              strokeWidth: AppConfig.strokeWidthThin,
            )
          : const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}