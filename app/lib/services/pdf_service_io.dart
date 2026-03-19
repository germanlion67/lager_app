// lib/services/pdf_service_io.dart
//
// IO-Implementierung des PdfSaver für Mobile (Android/iOS) und
// Desktop (Linux/macOS/Windows).
//
// Verwendet dart:io, path_provider, file_picker, url_launcher, share_plus.
// Diese Datei wird NICHT auf Flutter Web kompiliert.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'pdf_service_shared.dart';

/// IO-Implementierung: Speichert PDFs auf dem lokalen Dateisystem.
///
/// - Mobile (Android/iOS): Download-Ordner + share_plus
/// - Desktop (Linux/macOS/Windows): FilePicker Save-Dialog mit Fallback
class PdfSaverImpl implements PdfSaver {
  final Logger _logger = Logger();

  /// Speichert [pdfBytes] plattformspezifisch und gibt den Pfad zurück.
  ///
  /// Gibt `null` zurück wenn der Benutzer den Save-Dialog abbricht.
  @override
  Future<String?> savePdfBytes(
    Uint8List pdfBytes,
    String fileName,
    String dialogTitle,
  ) async {
    File? file;

    if (Platform.isAndroid || Platform.isIOS) {
      file = await _saveMobile(pdfBytes, fileName);
    } else {
      file = await _saveDesktop(pdfBytes, fileName, dialogTitle);
    }

    return file?.path;
  }

  @override
  Future<Uint8List?> readLocalImageBytes(String path) async {
    if (path.isEmpty) return null;
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (e) {
      _logger.w('Bild lesen fehlgeschlagen: $e');
      return null;
    }
  }


  /// Öffnet oder teilt eine bereits gespeicherte PDF plattformspezifisch.
  ///
  /// - Mobile: share_plus
  /// - Linux:  xdg-open (Fallback: url_launcher)
  /// - macOS:  open
  /// - Windows: url_launcher
  @override
  Future<bool> openPdf(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        _logger.w('PDF-Datei nicht gefunden: $filePath');
        return false;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        _logger.w('PDF-Datei ist leer: $filePath');
        return false;
      }

      // ── Mobile ─────────────────────────────────────────────────────────────
      if (Platform.isAndroid || Platform.isIOS) {
        final shareResult = await Share.shareXFiles(
          [XFile(filePath)],
          text: 'PDF-Export aus Lager-App',
          subject: 'Artikel-PDF',
        );
        final success = shareResult.status == ShareResultStatus.success;
        if (success) {
          _logger.i('PDF geteilt: $filePath ($fileSize bytes)');
        } else {
          _logger.w('Share fehlgeschlagen: ${shareResult.status}');
        }
        return success;
      }

      // ── Linux ───────────────────────────────────────────────────────────────
      // Process.run('xdg-open') ist stabiler als launchUrl auf Linux
      // (kein laufendes xdg-desktop-portal nötig).
      // Fix: Auf WSL2 ist xdg-open ohne xdg-desktop-portal unzuverlässig.
      // Strategie: Bekannte PDF-Viewer der Reihe nach probieren.
      // evince und okular sind auf WSLg-Systemen typisch verfügbar.
      if (Platform.isLinux) {
        final viewers = ['evince', 'okular', 'xdg-open', 'mupdf'];

        for (final viewer in viewers) {
          // Prüfen ob der Viewer überhaupt installiert ist
          final which = await Process.run('which', [viewer]);
          if (which.exitCode != 0) {
            _logger.d('$viewer nicht gefunden — nächster Versuch');
            continue;
          }

          final result = await Process.run(viewer, [filePath]);
          if (result.exitCode == 0) {
            _logger.i('PDF geöffnet via $viewer: $filePath');
            return true;
          }
          _logger.w(
            '$viewer fehlgeschlagen (exit ${result.exitCode}) — nächster Versuch',
          );
        }

        // Alle Viewer fehlgeschlagen → url_launcher als letzter Versuch
        _logger.w('Alle PDF-Viewer fehlgeschlagen, versuche url_launcher …');
        final uri = Uri.file(filePath);
        final success = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        _logger.i(
          success
              ? 'PDF geöffnet via url_launcher: $filePath'
              : 'url_launcher fehlgeschlagen: $filePath',
        );
        return success;
      }
      // ── macOS ───────────────────────────────────────────────────────────────
      if (Platform.isMacOS) {
        final result = await Process.run('open', [filePath]);
        if (result.exitCode == 0) {
          _logger.i('PDF geöffnet via open: $filePath');
          return true;
        }
        _logger.w('open fehlgeschlagen (exit ${result.exitCode})');
        return false;
      }

      // ── Windows ─────────────────────────────────────────────────────────────
      if (Platform.isWindows) {
        final uri = Uri.file(filePath);
        final success = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        _logger.i(
          success
              ? 'PDF geöffnet via url_launcher (Windows): $filePath'
              : 'url_launcher fehlgeschlagen (Windows): $filePath',
        );
        return success;
      }

      _logger.w('Unbekannte Plattform — PDF kann nicht geöffnet werden');
      return false;
    } catch (e, stack) {
      _logger.e(
        'Fehler beim Öffnen/Teilen der PDF:',
        error: e,
        stackTrace: stack,
      );
      return false;
    }
  }

  // ── Private Hilfsmethoden ──────────────────────────────────────────────────

  /// Speichert auf Mobile im Download-Ordner.
  Future<File?> _saveMobile(Uint8List pdfBytes, String fileName) async {
    try {
      Directory? directory;

      if (Platform.isAndroid) {
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          final downloadDir = Directory('${directory.path}/Download');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          directory = downloadDir;
        }
      } else if (Platform.isIOS) {
        directory = await getDownloadsDirectory();
      }

      // Fallback falls kein spezifisches Verzeichnis gefunden
      directory ??= await getApplicationDocumentsDirectory();

      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      _logger.i('PDF gespeichert (Mobile): ${file.path}');
      return file;
    } catch (e, stack) {
      _logger.e('Mobile Speicher Fehler:', error: e, stackTrace: stack);
      return null;
    }
  }

  /// Speichert auf Desktop via FilePicker Save-Dialog.
  /// Fallback: ~/Downloads/ wenn kein xdg-desktop-portal verfügbar.
  Future<File?> _saveDesktop(
    Uint8List pdfBytes,
    String fileName,
    String dialogTitle,
  ) async {
    try {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        bytes: pdfBytes,
      );

      if (savedPath == null) {
        // Benutzer hat den Dialog abgebrochen
        _logger.d('FilePicker Save-Dialog abgebrochen');
        return null;
      }

      final file = File(savedPath);
      // Auf manchen Plattformen schreibt FilePicker selbst — prüfen & ggf. nachschreiben
      if (!await file.exists() || await file.length() == 0) {
        await file.writeAsBytes(pdfBytes);
      }

      _logger.i('PDF gespeichert (Desktop): ${file.path}');
      return file;
    } catch (e) {
      // FilePicker nicht verfügbar (kein xdg-desktop-portal) → Fallback
      _logger.w('FilePicker nicht verfügbar, Fallback ~/Downloads/: $e');
      return _saveDesktopFallback(pdfBytes, fileName);
    }
  }

  /// Fallback: Speichert direkt in ~/Downloads/ ohne Dialog.
  Future<File?> _saveDesktopFallback(
    Uint8List pdfBytes,
    String fileName,
  ) async {
    try {
      final home = Platform.environment['USERPROFILE'] // Windows
          ??
          Platform.environment['HOME'] // Linux/macOS
          ??
          '/tmp'; // letzter Ausweg

      final downloadsDir = Directory('$home/Downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);

      _logger.i('PDF Fallback gespeichert: ${file.path}');
      return file;
    } catch (e, stack) {
      _logger.e('Desktop Fallback Fehler:', error: e, stackTrace: stack);
      return null;
    }
  }
}