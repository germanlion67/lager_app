# 📂 Vollständige Projektstruktur

> Stand: v0.8.0 (April 2026)
>
> Dieses Dokument listet alle Dateien und Verzeichnisse des Repositories.
> Für Architektur-Entscheidungen und Design-Patterns siehe [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Monorepo-Übersicht

```text
lager_app/
├── app/                              # Flutter Hauptanwendung
├── packages/                         # Lokale Dart-Pakete
├── server/                           # PocketBase Backend + Backup
├── scripts/                          # Host-Scripts
├── docs/                             # Dokumentation
├── .github/                          # CI/CD Workflows
└── (Root-Konfiguration)              # Docker, ENV, README
```

---

## app/ — Flutter Hauptanwendung

### app/lib/ — Quellcode

```text
app/lib/
├── config/                           # Zentrale Steuerung (Theming, Config)
│   ├── app_config.dart               #   Technische Konstanten (Spacing, Radien, Timeouts)
│   ├── app_images.dart               #   Asset-Pfade & Feature-Flags
│   └── app_theme.dart                #   Material 3 Theme (Light/Dark)
├── core/                             # Plattform-Abstraktion
│   ├── app_exception.dart            #   Typisierte Exceptions
│   └── app_logger.dart               #   Logger-Konfiguration
├── models/                           # Datenklassen
│   ├── artikel_model.dart            #   Artikel (CRUD, Sync, toMap/fromMap)
│   └── attachment_model.dart         #   Dateianhänge (Limits, MIME-Whitelist)
├── screens/                          # UI-Pages
│   ├── artikel_detail_screen.dart    #   Artikel-Detail mit Tabs
│   ├── artikel_erfassen_screen.dart  #   Conditional Import Hub
│   ├── artikel_erfassen_io.dart      #     ↳ Native: Kamera + Dateisystem
│   ├── artikel_erfassen_stub.dart    #     ↳ Web: File-Upload
│   ├── artikel_list_screen.dart      #   Hauptliste mit Suche/Filter
│   ├── conflict_resolution_screen.dart   # Sync-Konflikt-Auflösung
│   ├── detail_screen_io.dart         #   Detail: Native-Aktionen
│   ├── detail_screen_stub.dart       #   Detail: Web-Aktionen
│   ├── list_screen_cache_io.dart     #   Image-Cache-Evict (Native)
│   ├── list_screen_cache_stub.dart   #   Image-Cache-Evict (Web)
│   ├── list_screen_io.dart           #   Liste: Native-Aktionen
│   ├── list_screen_stub.dart         #   Liste: Web-Aktionen
│   ├── list_screen_mobile_actions.dart       # Mobile-spezifische Aktionen
│   ├── list_screen_mobile_actions_stub.dart  # Mobile-Aktionen Stub (Web)
│   ├── list_screen_web_actions.dart  #   Web-spezifische Aktionen
│   ├── login_screen.dart             #   PocketBase Login
│   ├── nextcloud_settings_screen.dart    # Nextcloud-Konfiguration
│   ├── pdf_service_stub.dart         #   PDF-Stub für Web
│   ├── qr_scan_screen_mobile_scanner.dart  # QR/Barcode-Scanner
│   ├── server_setup_screen.dart      #   Server-URL Konfiguration
│   ├── settings_screen.dart          #   App-Einstellungen
│   └── sync_management_screen.dart   #   Sync-Übersicht & Steuerung
├── services/                         # Business-Logik
│   ├── app_log_service.dart          #   Zentrales Logging (Conditional Import)
│   ├── app_log_io.dart               #     ↳ Native Log-Implementierung
│   ├── app_log_stub.dart             #     ↳ Web Log-Implementierung
│   ├── artikel_db_service.dart       #   SQLite CRUD + Sync-Queries
│   ├── artikel_db_platform_io.dart   #     ↳ DB-Plattform: Native (FFI)
│   ├── artikel_db_platform_stub.dart #     ↳ DB-Plattform: Web (NoOp)
│   ├── artikel_export_service.dart   #   CSV/PDF Export-Logik
│   ├── artikel_import_service.dart   #   CSV Import-Logik
│   ├── attachment_service.dart       #   PocketBase Attachment CRUD
│   ├── backup_status_service.dart    #   Backup-Status (last_backup.json)
│   ├── connectivity_service.dart     #   Online/Offline-Erkennung
│   ├── database_service.dart         #   DB-Initialisierung & Injection
│   ├── export_io.dart                #   Export: Native (Dateisystem)
│   ├── export_stub.dart              #   Export: Web (Download)
│   ├── export_nextcloud.dart         #   Export: Nextcloud-Upload
│   ├── export_nextcloud_stub.dart    #   Export: Nextcloud-Stub (Web)
│   ├── image_picker.dart             #   Bild-Auswahl Abstraktion
│   ├── import_io.dart                #   Import: Native (Dateisystem)
│   ├── import_stub.dart              #   Import: Web (Upload)
│   ├── import_nextcloud.dart         #   Import: Nextcloud-Download
│   ├── nextcloud_client.dart         #   Nextcloud HTTP-Client
│   ├── nextcloud_connection_service.dart  # Nextcloud Verbindungstest
│   ├── nextcloud_credentials.dart    #   Nextcloud Zugangsdaten-Modell
│   ├── nextcloud_service_interface.dart  # Interface für Timer-freie Tests
│   ├── nextcloud_sync_service.dart   #   Nextcloud Sync-Logik
│   ├── nextcloud_webdav_client.dart  #   WebDAV-Client
│   ├── pdf_service.dart              #   PDF-Erzeugung (Conditional Import)
│   ├── pdf_service_io.dart           #     ↳ PDF: Native (dart:io)
│   ├── pdf_service_shared.dart       #     ↳ PDF: Gemeinsame Logik
│   ├── pdf_service_stub.dart         #     ↳ PDF: Stub
│   ├── pdf_service_web.dart          #     ↳ PDF: Web (Browser-Download)
│   ├── pocketbase_service.dart       #   PocketBase REST-Client
│   ├── pocketbase_sync_service.dart  #   PocketBase Sync (Push/Pull)
│   ├── scan_result.dart              #   Scan-Ergebnis Modell
│   ├── scan_service.dart             #   Scanner (Conditional Import)
│   ├── scan_service_io.dart          #     ↳ Scanner: Native
│   ├── scan_service_stub.dart        #     ↳ Scanner: Web-Stub
│   ├── sync_error_recovery.dart      #   Sync-Fehlerbehandlung
│   ├── sync_orchestrator.dart        #   Sync-Steuerung (Push→Pull→Images)
│   ├── sync_progress_service.dart    #   Sync-Fortschritt Stream
│   ├── sync_service.dart             #   Sync-Kernlogik
│   ├── sync_status_provider.dart     #   Interface: Sync-Status Stream
│   └── tag_service.dart              #   Tag/Label-Verwaltung
├── utils/                            # Helfer
│   ├── attachment_utils.dart         #   Attachment-Validierung (Größe→Anzahl→MIME)
│   ├── image_processing_utils.dart   #   Thumbnail-Erzeugung, Kompression
│   └── uuid_generator.dart           #   UUID v4 Erzeugung
├── widgets/                          # Wiederverwendbare UI-Komponenten
│   ├── app_error_handler.dart        #   Globaler Error-Handler + Klassifizierung
│   ├── app_loading_overlay.dart      #   Lade-Overlay
│   ├── article_icons.dart            #   Artikel-Status-Icons
│   ├── artikel_bild_widget.dart      #   Bild-Anzeige (4-stufige Fallback-Kette)
│   ├── attachment_list_widget.dart   #   Attachment-Liste (Detail-Tab)
│   ├── attachment_upload_widget.dart  #   Attachment-Upload Dialog
│   ├── backup_status_widget.dart     #   Backup-Status Anzeige
│   ├── image_crop_dialog.dart        #   Bild-Zuschnitt Dialog
│   ├── nextcloud_resync_dialog.dart  #   Nextcloud Re-Sync Dialog
│   ├── sync_conflict_handler.dart    #   Sync-Konflikt UI-Handler
│   ├── sync_error_widgets.dart       #   Sync-Fehler Anzeige-Widgets
│   └── sync_progress_widgets.dart    #   Sync-Fortschritt Anzeige
├── main.dart                         # App-Einstiegspunkt (gemeinsam)
├── main_io.dart                      # Einstiegspunkt: Native (dart:io)
└── main_stub.dart                    # Einstiegspunkt: Web (kein dart:io)
```

### Conditional Imports — Übersicht

| Hub-Datei | Native (`_io.dart`) | Web (`_stub.dart`) | Zweck |
|---|---|---|---|
| `artikel_erfassen_screen.dart` | `artikel_erfassen_io.dart` | `artikel_erfassen_stub.dart` | Kamera vs. File-Upload |
| `artikel_list_screen.dart` | `list_screen_io.dart` | `list_screen_stub.dart` | Native vs. Web Aktionen |
| `artikel_list_screen.dart` | `list_screen_cache_io.dart` | `list_screen_cache_stub.dart` | Image-Cache-Evict |
| `artikel_list_screen.dart` | `list_screen_mobile_actions.dart` | `list_screen_mobile_actions_stub.dart` | Mobile-spezifisch |
| `artikel_detail_screen.dart` | `detail_screen_io.dart` | `detail_screen_stub.dart` | Detail-Aktionen |
| `app_log_service.dart` | `app_log_io.dart` | `app_log_stub.dart` | Logging |
| `artikel_db_service.dart` | `artikel_db_platform_io.dart` | `artikel_db_platform_stub.dart` | DB-Plattform |
| `artikel_export_service.dart` | `export_io.dart` | `export_stub.dart` | Export |
| `artikel_export_service.dart` | `export_nextcloud.dart` | `export_nextcloud_stub.dart` | Nextcloud-Export |
| `artikel_import_service.dart` | `import_io.dart` | `import_stub.dart` | Import |
| `pdf_service.dart` | `pdf_service_io.dart` | `pdf_service_stub.dart` / `pdf_service_web.dart` | PDF-Erzeugung |
| `scan_service.dart` | `scan_service_io.dart` | `scan_service_stub.dart` | QR/Barcode-Scanner |
| `main.dart` | `main_io.dart` | `main_stub.dart` | App-Einstiegspunkt |

---

### app/test/ — Tests (451 Tests, 18 Dateien)

```text
app/test/
├── helpers/                          # Test-Doubles & Utilities
│   ├── fake_sync_status_provider.dart    # FakeSyncStatusProvider
│   └── no_op_nextcloud_service.dart      # NoOp NextcloudService
├── mocks/                            # Mockito-generierte Mocks
│   ├── sync_service_mocks.dart           # Mock-Definitionen (@GenerateMocks)
│   └── sync_service_mocks.mocks.dart     # Generierter Code
├── models/                           # Modell-Tests
│   ├── artikel_model_test.dart           # Konstruktor, fromMap, toMap, copyWith, Sync
│   ├── attachment_model_test.dart        # Limits, MIME-Whitelist, Validierung
│   └── nextcloud_credentials_test.dart   # Parsing, Gleichheit, Edge-Cases
├── services/                         # Service-Tests
│   ├── app_log_service_test.dart         # Logging-Tests
│   ├── artikel_db_service_test.dart      # In-Memory SQLite CRUD (alle Methoden)
│   ├── artikel_db_service_test_helper.dart  # Schema-Setup Helper
│   ├── artikel_export_service_test.dart  # CSV-Erzeugung
│   ├── artikel_import_service_test.dart  # CSV-Parsing
│   ├── backup_status_test.dart           # fromJson, Status-Auswertung
│   ├── nextcloud_listfiles_test.dart     # Nextcloud Dateiliste
│   └── sync_status_provider_test.dart    # Stream-Events, State-Änderungen
├── utils/                            # Utility-Tests
│   ├── attachment_utils_test.dart        # Validierung: Größe→Anzahl→MIME
│   ├── image_processing_utils_test.dart  # Thumbnail, Kompression
│   └── uuid_generator_test.dart          # UUID-Format, Eindeutigkeit
├── widgets/                          # Widget-Tests
│   ├── artikel_detail_screen_test.dart   # Detail-Screen (DI-basiert)
│   ├── artikel_erfassen_test.dart        # Erfassen-Screen
│   └── artikel_list_screen_test.dart     # Listen-Screen (pump statt pumpAndSettle)
├── performance/                      # Performance-Tests
│   ├── import_500_smoke_test.dart        # 500-Artikel Import-Smoke
│   └── import_500/                       # Externe Testdaten (nicht committed)
└── conflict_resolution_test.dart     # Konflikt-Auflösung Widget-Test
```

### app/ — Weitere Dateien

```text
app/
├── tool/                             # Build-Hilfsskripte
│   ├── Erklärung.txt                     # Dokumentation der Tools
│   ├── generate_import_dataset.dart      # Import-Testdaten Generator
│   └── generate_test_dataset.dart        # Test-Datensatz Generator
├── assets/
│   └── images/                       # Statische Bilder (Icons, Platzhalter)
├── web/
│   ├── index.html                    # SPA-Einstiegspunkt
│   ├── config.template.js            # Runtime-ENV Template
│   ├── manifest.json                 # PWA-Manifest
│   ├── favicon.png                   # Favicon
│   └── icons/                        # Web-Icons (verschiedene Größen)
├── android/                          # Android-spezifische Konfiguration
├── ios/                              # iOS-spezifische Konfiguration
├── linux/                            # Linux Desktop Konfiguration
├── macos/                            # macOS-spezifische Konfiguration
├── windows/                          # Windows Desktop Konfiguration
├── Caddyfile                         # Caddy Webserver-Konfiguration
├── Dockerfile                        # Container-Build für Flutter Web
├── docker-entrypoint.sh              # Startskript für den Web-Container
├── pubspec.yaml                      # Flutter Abhängigkeiten & Metadaten
├── analysis_options.yaml             # Dart Analyzer-Regeln
└── setup_flutter_wsl.sh              # WSL Flutter-Setup Skript
```

---

## packages/ — Lokale Dart-Pakete

```text
packages/
└── runtime_env_config/               # Dynamische ENV-Injektion zur Laufzeit
    ├── lib/                          # Paket-Quellcode
    ├── test/                         # Paket-Tests
    ├── example/                      # Verwendungsbeispiel
    ├── pubspec.yaml                  # Paket-Abhängigkeiten
    ├── README.md                     # Paket-Dokumentation
    ├── CHANGELOG.md                  # Paket-Versionshistorie
    └── LICENSE                       # Lizenz
```

---

## server/ — PocketBase Backend

```text
server/
├── backup/                           # Backup-Container
│   ├── Dockerfile                    # Alpine + Cron + SQLite3
│   ├── entrypoint.sh                 # Cron-Setup, SMTP-Config
│   └── backup.sh                     # Backup-Logik (WAL, tar.gz, Rotation)
├── pb_migrations/                    # Schema-Versionierung (JS-Migrationen)
│   ├── 1772784781_created_artikel.js
│   ├── 1772784782_created_users.js
│   ├── 1772784783_updated_artikel_ownership.js
│   ├── 1774186524_added_artikelnummer_indexes.js
│   ├── 1774200000_created_attachments.js
│   ├── 1774811640_updated_attachments.js
│   ├── 1775000000_set_auth_rules.js
│   └── pb_schema.json                # Aktuelles Schema-Snapshot
├── pb_data/                          # PocketBase-Datenbank & Uploads (gitignored)
├── pb_public/                        # Öffentliche PocketBase-Dateien
│   └── .gitkeep
├── Dockerfile                        # PocketBase Server-Container
├── entrypoint.sh                     # PocketBase Startskript
├── init-pocketbase.sh                # Erstinitialisierung
└── manage_data.sh                    # Daten-Management Skript
```

---

## docs/ — Dokumentation

```text
docs/
├── ARCHITECTURE.md                   # Architektur & Design-Entscheidungen
├── PROJECT_STRUCTURE.md              # Vollständige Dateistruktur (diese Datei)
├── ANDROID_RELEASE_KEYSTORE.md       # Android Release-Signierung
├── CHECKLIST.md                      # Aktueller Implementierungsstand
├── DATABASE.md                       # Datenbank-Design & Synchronisation
├── DEV_SETUP.md                      # Entwicklungsumgebung einrichten
├── HISTORY.md                        # Projekthistorie & Entscheidungslog
├── IMAGE_TAGGING_STRATEGIE.md        # Docker Image-Tagging Konzept
├── LOGGER.md                         # Logging-System Dokumentation
├── OPTIMIZATIONS.md                  # Offene Optimierungsaufgaben
├── PORTAINER_PROD.md                 # Portainer Produktions-Setup
├── SETUP_BASHRC.md                   # Shell-Konfiguration
├── TESTING.md                        # Test-Strategie & Übersicht
├── THEMING.md                        # AppConfig, AppTheme & Design-Tokens
├── prompt.txt                        # AI-Coding-Agent Prompt
├── prompt_Datenbank.txt              # Datenbank-spezifischer Prompt
├── prompt_deployment.txt             # Deployment-spezifischer Prompt
├── info._js                          # PocketBase Migration-Info
└── .bashrc                           # Shell-Aliases für Entwicklung
```

---

## .github/ — CI/CD

```text
.github/
├── how_do_Release_Workflow.md        # Release-Workflow Anleitung
└── workflows/
    ├── docker-build-push.yml         # Docker Build & Push (GHCR)
    ├── flutter-maintenance.yml       # Flutter Wartungs-Checks
    └── release.yml                   # Release-Automatisierung
```

---

## Root-Verzeichnis — Konfiguration & Deployment

```text
lager_app/
├── docker-compose.yml                # Entwicklungs-Setup
├── docker-compose.prod.yml           # Produktions-Setup (NPM)
├── docker-stack.yml                  # Docker Swarm Stack-Definition
├── portainer-stack.yml               # Portainer Stack (mit NPM, Produktion)
├── test-deployment.sh                # Deployment-Testskript
├── CHANGELOG.md                      # Versionshistorie
├── DEPLOYMENT.md                     # Produktions-Setup & SSL-Anleitung
├── INSTALL.md                        # Detaillierte Installationsanleitung
├── README.md                         # Projektübersicht & Schnellstart
├── .env.example                      # Vorlage für lokale Umgebungsvariablen
├── .env.production.example           # Vorlage für Produktions-Variablen
├── .gitignore                        # Git-Ignore Regeln
├── .dockerignore                     # Docker-Ignore Regeln
├── android/                          # Root-Level Android Wrapper
├── ios/                              # Root-Level iOS Wrapper
├── linux/                            # Root-Level Linux Wrapper
├── macos/                            # Root-Level macOS Wrapper
├── windows/                          # Root-Level Windows Wrapper
└── scripts/
    └── restore.sh                    # Backup-Wiederherstellung (manuell)
```

---

## Statistiken

| Bereich | Anzahl |
|---|---|
| **Quellcode-Dateien** (`app/lib/`) | 70 |
| **Davon Conditional Imports** | 26 (13 Paare) |
| **Test-Dateien** | 18 + 2 Helpers + 2 Mocks |
| **Tests gesamt** | 451 (3 skipped) |
| **PocketBase Migrationen** | 7 |
| **Dokumentations-Dateien** | 19 |
| **CI/CD Workflows** | 3 |
| **Docker-Compose Varianten** | 4 |

---

[Zurück zur Architektur](ARCHITECTURE.md) | [Zurück zur README](../README.md)