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

import 'dart:io';
import 'dart:typed_data'; // ← NEU hinzufügen

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

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
    this.size = 50,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: size,
          height: size,
          child: kIsWeb ? _WebThumbnail(artikel: artikel, size: size)
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
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
        fit: BoxFit.cover,
      );
    }

    // 2. Web: Remote-URL via CachedNetworkImage
    if (kIsWeb) {
      if (remoteBildUrl != null) {
        return CachedNetworkImage(
          imageUrl: remoteBildUrl!,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
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
        fit: BoxFit.cover,
        cacheWidth: 800, // M-011: Speicher-Limit für Dekodierung
        errorBuilder: (_, __, ___) => _Placeholder(height: height),
      );
    }

    return _Placeholder(height: height);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Hilfs-Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Lokales Thumbnail für die Listenansicht.
/// Bevorzugt thumbnailPfad, fällt auf bildPfad zurück.
class _LocalThumbnail extends StatelessWidget {
  final Artikel artikel;
  final double size;

  const _LocalThumbnail({required this.artikel, required this.size});

  @override
  Widget build(BuildContext context) {
    // M-011: Thumbnail bevorzugen
    final thumbPfad = artikel.thumbnailPfad;
    if (thumbPfad != null &&
        thumbPfad.isNotEmpty &&
        File(thumbPfad).existsSync()) {
      return Image.file(
        File(thumbPfad),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // M-011: cacheWidth = physische Pixel → Flutter dekodiert nur so groß
        // wie nötig → weniger RAM
        cacheWidth: (size * 2).toInt(), // ×2 für High-DPI
        errorBuilder: (_, __, ___) => _fallbackBild(context),
      );
    }

    // Fallback: Vollbild mit cacheWidth-Limit
    final bildPfad = artikel.bildPfad.isNotEmpty ? artikel.bildPfad : null;
    if (bildPfad != null && File(bildPfad).existsSync()) {
      return Image.file(
        File(bildPfad),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (_, __, ___) => _BildPlaceholder(size: size),
      );
    }

    return _BildPlaceholder(size: size);
  }

  Widget _fallbackBild(BuildContext context) {
    final bildPfad = artikel.bildPfad.isNotEmpty ? artikel.bildPfad : null;
    if (bildPfad != null && File(bildPfad).existsSync()) {
      return Image.file(
        File(bildPfad),
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        errorBuilder: (_, __, ___) => _BildPlaceholder(size: size),
      );
    }
    return _BildPlaceholder(size: size);
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
      width: size,
      height: size,
      fit: BoxFit.cover,
      // M-011: Memory-Cache auf Thumbnail-Größe begrenzen
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      placeholder: (_, __) => _BildPlaceholder(size: size, loading: true),
      errorWidget: (_, __, ___) => _BildPlaceholder(size: size),
    );
  }

  /// Baut die PocketBase-Bild-URL.
  /// M-011: `?thumb=60x60` Query-Parameter → PocketBase liefert Thumbnail.
  /// PocketBase unterstützt on-the-fly Thumbnails via `thumb` Parameter.
  String? _buildThumbnailUrl() {
    final recordId = artikel.remotePath;
    final bildField = artikel.remoteBildPfad;

    if (recordId == null || recordId.isEmpty) return null;
    if (bildField == null || bildField.isEmpty) return null;

    final pbService = PocketBaseService();
    final baseUri = Uri.parse(pbService.url);

    // M-011: PocketBase thumb-Parameter für serverseitiges Thumbnail
    // Format: ?thumb=WxH (z.B. 60x60 für 50px-Liste mit 1.2× Puffer)
    return baseUri
        .resolve(
          '/api/files/artikel/$recordId/${Uri.encodeComponent(bildField)}'
          '?thumb=60x60',
        )
        .toString();
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  final double? height;
  const _LoadingPlaceholder({this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final double? height;
  const _Placeholder({this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
    );
  }
}

class _BildPlaceholder extends StatelessWidget {
  final double size;
  final bool loading;
  const _BildPlaceholder({required this.size, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey[300],
      alignment: Alignment.center,
      child: loading
          ? const CircularProgressIndicator(strokeWidth: 1.5)
          : const Icon(Icons.image_not_supported, color: Colors.grey),
    );
  }
}
