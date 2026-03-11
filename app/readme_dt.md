# 🏭 Lager App

Eine plattformübergreifende Flutter-App zur Lagerverwaltung mit Barcode-Scan,
Bildverwaltung, PDF-Export und PocketBase-Synchronisation.

## 🎯 Zielplattformen

| Plattform | Priorität | Datenhaltung |
|-----------|-----------|--------------|
| Android   | 🥇 Hoch   | SQLite lokal + PocketBase Sync |
| Web       | 🥈 Mittel | PocketBase direkt |
| Desktop   | 🥉 Niedrig | SQLite lokal + PocketBase Sync |

## 🏗️ Architektur

```
lib/
├── main.dart                  # Entry Point (Mobile/Desktop)
├── main_io.dart               # IO-spezifische Initialisierung
├── main_stub.dart             # Web Entry Point
├── models/
│   └── artikel_model.dart     # Datenmodell (SQLite + PocketBase kompatibel)
├── screens/
│   ├── artikel_list_screen.dart        # Artikelliste (Haupt-Screen)
│   ├── artikel_detail_screen.dart      # Artikel-Detailansicht + Bearbeitung
│   ├── artikel_erfassen_screen.dart    # Neuen Artikel anlegen
│   ├── conflict_resolution_screen.dart # Sync-Konfliktlösung
│   ├── settings_screen.dart            # App-Einstellungen + PocketBase URL
│   ├── sync_management_screen.dart     # Sync-Verwaltung
│   ├── nextcloud_settings_screen.dart  # Nextcloud (optional)
│   ├── qr_scan_screen_mobile_scanner.dart # QR/Barcode Scanner
│   └── *_io.dart / *_stub.dart        # Plattform-Splits
├── services/
│   ├── pocketbase_service.dart         # PocketBase Client (Singleton)
│   ├── pocketbase_sync_service.dart    # Push/Pull Sync Logik
│   ├── sync_orchestrator.dart          # Sync-Koordination
│   ├── artikel_db_service.dart         # SQLite Lokaldatenbank
│   ├── artikel_import_service.dart     # CSV/JSON/ZIP Import
│   ├── artikel_export_service.dart     # CSV/JSON/ZIP Export
│   ├── pdf_service.dart                # PDF Export
│   ├── scan_service.dart               # QR/Barcode Scan
│   ├── nextcloud_sync_service.dart     # Nextcloud Sync (optional)
│   ├── nextcloud_client.dart           # Nextcloud WebDAV Client
│   └── tag_service.dart                # Tag-Verwaltung
├── utils/
│   ├── dokumente_utils.dart            # Datei-Hilfsfunktionen
│   ├── image_processing_utils.dart     # Bildverarbeitung
│   └── uuid_generator.dart            # UUID Generierung
└── widgets/
    ├── article_icons.dart              # Artikel-Icons
    ├── image_crop_dialog.dart          # Bild-Zuschnitt Dialog
    ├── sync_conflict_handler.dart      # Konflikt-Handler Widget
    ├── sync_error_widgets.dart         # Fehler-Anzeige Widgets
    └── sync_progress_widgets.dart      # Sync-Fortschritt Widgets
```

## ⚙️ Sync-Backend

**Primär: PocketBase**
- Mobile/Desktop: SQLite lokal → PocketBase Sync (Push/Pull)
- Web: Direkt PocketBase (kein lokales SQLite)

**Optional: Nextcloud**
- Datei-Backup (Bilder, Dokumente) via WebDAV
- Keine Prio – kann deaktiviert bleiben

## 🚀 Features

- [x] Artikel anlegen / bearbeiten / löschen
- [x] Bildverwaltung (Kamera + Galerie)
- [x] QR/Barcode Scanner (Mobile/Desktop)
- [x] CSV / JSON / ZIP Import & Export
- [x] PDF Export
- [x] PocketBase Sync (Push/Pull)
- [x] Konfliktlösung bei Sync
- [x] Nextcloud Datei-Backup (optional)
- [x] Tag-Verwaltung
- [x] App-Logging

## ⚠️ Teststatus

> Stand: März 2026 – noch kein manuelles Testing durchgeführt.
> Alle Features sind implementiert, aber ungetestet.

## 🛠️ Setup

```bash
# Abhängigkeiten installieren
flutter pub get

# Android
flutter run -d android

# Web
flutter run -d chrome

# Desktop (Linux)
flutter run -d linux
```

## 🧪 Tests ausführen

```bash
flutter test
```

## 📦 PocketBase

Standard-URL konfigurierbar unter **Einstellungen → PocketBase Server**.

Standard: `http://127.0.0.1:8090`