// lib/widgets/artikel_bild_widget.dart
//
// M-011: Zentrales Bild-Widget für Artikel mit P-003 Bild-Caching.
//
// Strategie:
//   Liste  → Thumbnail (lokal: thumbnailPfad, web/fallback: ?thumb=1 Query-Param)
//   Detail → Vollbild  (lokal: bildPfad,      web/fallback: Original-URL)
//
// Caching (P-003):
//   - Lokal: Image.file mit RepaintBoundary (Flutter-intern gecacht)
//   - Remote: cached_network_image mit Disk- und Memory-Cache.
//   - Invalidation: Der cacheKey enthält den 'aktualisiertAm'-Zeitstempel.

import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_images.dart';
import '../models/artikel_model.dart';
import '../services/app_log_service.dart';
import '../services/pocketbase_service.dart';

final _log = AppLogService.logger;

// ─────────────────────────────────────────────────────────────────────────────
// ArtikelListBild
// ─────────────────────────────────────────────────────────────────────────────

class ArtikelListBild extends StatelessWidget {
  final Artikel artikel;
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
// ─────────────────────────────────────────────────────────────────────────────

class ArtikelDetailBild extends StatelessWidget {
  final Artikel artikel;
  final Uint8List? pendingBytes;
  final String? remoteBildUrl;
  final VoidCallback? onTap;
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
          borderRadius: BorderRadius.circular(AppConfig.cardBorderRadiusLarge),
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
    if (pendingBytes != null) {
      return Image.memory(
        pendingBytes!,
        height: height,
        width: double.infinity,
        fit: AppConfig.artikelDetailBildFit,
      );
    }

    if (kIsWeb) {
      if (remoteBildUrl != null) {
        return _buildCachedImage(remoteBildUrl!, isDetail: true);
      }
      return _Placeholder(height: height);
    }

    final pfad = artikel.bildPfad.isNotEmpty ? artikel.bildPfad : null;
    if (pfad != null && File(pfad).existsSync()) {
      return Image.file(
        File(pfad),
        height: height,
        width: double.infinity,
        fit: AppConfig.artikelDetailBildFit,
        cacheWidth: 800,
        errorBuilder: (_, __, ___) {
          _log.w('Lokales Bild fehlerhaft: $pfad. Nutze PB-Fallback.');
          return _buildPbDetailFallback();
        },
      );
    }

    return _buildPbDetailFallback();
  }

  Widget _buildPbDetailFallback() {
    final url = _getPbUrl(isThumb: false);
    if (url == null) return _Placeholder(height: height);
    return _buildCachedImage(url, isDetail: true);
  }

  Widget _buildCachedImage(String url, {required bool isDetail}) {
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: '${artikel.uuid}_${isDetail ? "full" : "thumb"}_${artikel.aktualisiertAm.millisecondsSinceEpoch}',
      height: height,
      width: double.infinity,
      fit: AppConfig.artikelDetailBildFit,
      placeholder: (_, __) => _LoadingPlaceholder(height: height),
      errorWidget: (context, url, error) {
        _log.e('Fehler beim Laden des Remote-Bildes (Detail): $url', error: error);
        return _Placeholder(height: height);
      },
    );
  }

  String? _getPbUrl({required bool isThumb}) {
    final recordId = artikel.remotePath;
    final bildField = artikel.remoteBildPfad;
    if (recordId == null || recordId.isEmpty || bildField == null || bildField.isEmpty) return null;

    final pbService = PocketBaseService();
    if (!pbService.hasClient || pbService.url.isEmpty) return null;

    final baseUri = Uri.parse(pbService.url);
    var urlPath = '/api/files/artikel/$recordId/${Uri.encodeComponent(bildField)}';
    if (isThumb) urlPath += '?thumb=${AppConfig.pbThumbGroesse}';
    
    return baseUri.resolve(urlPath).toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Hilfs-Widgets (Mobile/Desktop)
// ─────────────────────────────────────────────────────────────────────────────

class _LocalThumbnail extends StatelessWidget {
  final Artikel artikel;
  final double size;

  const _LocalThumbnail({required this.artikel, required this.size});

  @override
  Widget build(BuildContext context) {
    final thumbPfad = artikel.thumbnailPfad;
    if (thumbPfad != null && thumbPfad.isNotEmpty && File(thumbPfad).existsSync()) {
      return _buildFileImage(thumbPfad);
    }

    final bildPfad = artikel.bildPfad.isNotEmpty ? artikel.bildPfad : null;
    if (bildPfad != null && File(bildPfad).existsSync()) {
      return _buildFileImage(bildPfad);
    }

    return _buildPbFallback();
  }

  Widget _buildFileImage(String path) {
    return Image.file(
      File(path),
      width: size,
      height: size,
      fit: AppConfig.artikelListBildFit,
      cacheWidth: (size * 2).toInt(),
      errorBuilder: (_, __, ___) => _buildPbFallback(),
    );
  }

  Widget _buildPbFallback() {
    final url = _getPbThumbUrl();
    if (url == null) return _BildPlaceholder(size: size);

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: '${artikel.uuid}_thumb_${artikel.aktualisiertAm.millisecondsSinceEpoch}',
      width: size,
      height: size,
      fit: AppConfig.artikelListBildFit,
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      placeholder: (_, __) => _BildPlaceholder(size: size, loading: true),
      errorWidget: (context, url, error) {
        _log.w('PB-Thumbnail Fallback fehlgeschlagen für ${artikel.uuid}');
        return _BildPlaceholder(size: size);
      },
    );
  }

  String? _getPbThumbUrl() {
    final recordId = artikel.remotePath;
    final bildField = artikel.remoteBildPfad;
    if (recordId == null || recordId.isEmpty || bildField == null || bildField.isEmpty) return null;

    final pbService = PocketBaseService();
    if (!pbService.hasClient || pbService.url.isEmpty) return null;

    return Uri.parse(pbService.url)
        .resolve('/api/files/artikel/$recordId/${Uri.encodeComponent(bildField)}?thumb=${AppConfig.pbThumbGroesse}')
        .toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Hilfs-Widgets (Web)
// ─────────────────────────────────────────────────────────────────────────────

class _WebThumbnail extends StatelessWidget {
  final Artikel artikel;
  final double size;

  const _WebThumbnail({required this.artikel, required this.size});

  @override
  Widget build(BuildContext context) {
    final recordId = artikel.remotePath;
    final bildField = artikel.remoteBildPfad;
    if (recordId == null || recordId.isEmpty || bildField == null || bildField.isEmpty) {
      return _BildPlaceholder(size: size);
    }

    final pbService = PocketBaseService();
    final url = Uri.parse(pbService.url)
        .resolve('/api/files/artikel/$recordId/${Uri.encodeComponent(bildField)}?thumb=${AppConfig.pbThumbGroesse}')
        .toString();

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: '${artikel.uuid}_thumb_${artikel.aktualisiertAm.millisecondsSinceEpoch}',
      width: size,
      height: size,
      fit: AppConfig.artikelListBildFit,
      memCacheWidth: (size * 2).toInt(),
      memCacheHeight: (size * 2).toInt(),
      placeholder: (_, __) => _BildPlaceholder(size: size, loading: true),
      errorWidget: (_, __, ___) => _BildPlaceholder(size: size),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UI Platzhalter Widgets
// ─────────────────────────────────────────────────────────────────────────────

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