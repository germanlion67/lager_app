# 📦 Elektronik Lagerverwaltung

Eine plattformübergreifende Lagerverwaltungs-App für Elektronikbauteile, gebaut mit **Flutter** und **PocketBase**. Verfügbar als mobile App (Android) und als Web-App im Docker-Container.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![PocketBase](https://img.shields.io/badge/PocketBase-0.22+-green?logo=pocketbase)
![Docker](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Test Status](https://img.shields.io/badge/Tests-⚠️%20ungetestet-orange)

> ⚠️ **Teststatus**: Stand März 2026 – alle Features implementiert, manuelles Testing läuft.  Siehe [Roadmap](#Roadmap).
Nicht für Produktionseinsatz empfohlen.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Installation](#installation)
  - [Docker (Web)](#docker-web)
  - [Local Development](#local-development)
  - [Mobile (Android)](#mobile-android)
- [Configuration](#configuration)
  - [PocketBase Setup](#pocketbase-setup)
  - [Environment Variables](#environment-variables)
  - [App Settings](#app-settings)
  - [Nextcloud (Optional)](#nextcloud-optional)
- [Usage](#usage)
  - [Quick Start](#quick-start)
  - [Command Line](#command-line)
  - [Web Interface](#web-interface)
  - [Mobile App](#mobile-app)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
  - [Project Structure](#project-structure)
  - [Platform Architecture](#platform-architecture)
  - [Adding Features](#adding-features)
  - [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Die **Elektronik Lagerverwaltung** ist eine Offline-First-Anwendung zur Verwaltung von Elektronikbauteilen und Lagerbeständen. Sie wurde entwickelt, um sowohl auf mobilen Geräten als auch im Browser zu funktionieren.

### Kernkonzept

| Plattform | Datenbank | Bilder | Sync |
|-----------|-----------|--------|------|
| 📱 **Mobile (Android)** | SQLite (lokal) | Lokales Dateisystem | Background-Sync mit PocketBase |
| 🖥️ **Desktop (Linux)** | SQLite (lokal) | Lokales Dateisystem | Background-Sync mit PocketBase |
| 🌐 **Web (Docker)** | PocketBase (direkt) | PocketBase File Storage | Kein Sync nötig (immer online) |

```
┌──────────┐  :8081   ┌───────────┐  intern   ┌────────────┐
│ Browser  │─────────→│ nginx     │──────────→│ PocketBase │
└──────────┘          │ (Flutter  │           │ (API + DB) │
                      │  Web App) │           └────────────┘
┌──────────┐          └───────────┘                  ↑
│ 📱 App   │─────────────────────────────────────────┘
└──────────┘         PocketBase API (direkt)
```

---

## Features

### 📦 Artikelverwaltung
- Artikel erfassen mit Name, Beschreibung, Ort, Fach und Menge
- Artikelbilder per Kamera oder Dateiauswahl
- Mengensteuerung (erhöhen/verringern)
- Suche nach Name und Beschreibung
- Filter nach Lagerort
- Tag-Verwaltung

### 📷 Scanner
- QR-Code / Barcode Scanner (nur Mobile)
- Schnelles Auffinden von Artikeln

### 🔄 Synchronisation
- **Offline-First**: Mobile App funktioniert ohne Netzwerk
- **Background-Sync**: Automatische Synchronisation alle 15 Minuten
- **WiFi-Only Option**: Sync nur im WLAN
- **Sync bei App-Resume**: Automatischer Sync wenn App in den Vordergrund kommt
- **Konfliktlösung**: Manuelle Konfliktauflösung über eigenen Screen

### 📄 Export & Backup
- JSON-Export / -Import
- CSV-Export / -Import
- ZIP-Backup (Daten + Bilder)
- PDF-Berichte (Artikelliste, Einzelartikel) — nur Mobile/Desktop
- Nextcloud ZIP-Backup (optional, ungetestet)

### 🌐 Web-Version
- Identische UI wie Mobile
- Läuft als Docker-Container
- PocketBase Admin-UI über gleichen Port erreichbar
- Kein lokaler Speicher nötig

### ☁️ Nextcloud Integration (Optional, ungetestet)
- ZIP-Backup zu Nextcloud
- Dokumenten-Ablage pro Artikel
- Verbindungsstatus-Anzeige

---

## Architecture

```
lib/
├── main.dart                          # App-Einstiegspunkt
├── main_io.dart                       # Desktop DB-Init (conditional)
├── main_stub.dart                     # Web-Stub
├── models/
│   └── artikel_model.dart             # Datenmodell (SQLite + PocketBase kompatibel)
├── screens/
│   ├── artikel_list_screen.dart       # Hauptliste mit Suche & Filter
│   ├── artikel_detail_screen.dart     # Detailansicht & Bearbeitung
│   ├── artikel_erfassen_screen.dart   # Neuen Artikel anlegen
│   ├── conflict_resolution_screen.dart # Sync-Konfliktlösung
│   ├── settings_screen.dart           # PocketBase-URL & Einstellungen
│   ├── sync_management_screen.dart    # Sync-Verwaltung
│   ├── nextcloud_settings_screen.dart # Nextcloud (optional)
│   ├── qr_scan_screen_mobile_scanner.dart # QR/Barcode Scanner
│   ├── *_io.dart                      # Plattform-spezifisch (Mobile/Desktop)
│   └── *_stub.dart                    # Web-Stubs
├── services/
│   ├── pocketbase_service.dart        # PocketBase Client (Singleton)
│   ├── artikel_db_service.dart        # Lokale SQLite DB (nur Mobile/Desktop)
│   ├── pocketbase_sync_service.dart   # Push/Pull Sync
│   ├── sync_orchestrator.dart         # Sync-Koordination
│   ├── artikel_export_service.dart    # JSON/CSV/ZIP Export
│   ├── artikel_import_service.dart    # JSON/CSV/ZIP Import
│   ├── pdf_service.dart               # PDF-Generierung (nur Mobile/Desktop)
│   ├── scan_service.dart              # QR/Barcode Scanner (nur Mobile)
│   ├── tag_service.dart               # Tag-Verwaltung
│   ├── nextcloud_sync_service.dart    # Nextcloud Sync (optional)
│   └── nextcloud_client.dart          # Nextcloud WebDAV Client
├── utils/
│   ├── dokumente_utils.dart           # Datei-Hilfsfunktionen
│   ├── image_processing_utils.dart    # Bildverarbeitung
│   └── uuid_generator.dart           # UUID Generierung
├── widgets/
│   ├── article_icons.dart             # Custom Icons
│   ├── image_crop_dialog.dart         # Bild-Zuschnitt Dialog
│   ├── sync_conflict_handler.dart     # Konflikt-Handler Widget
│   ├── sync_error_widgets.dart        # Fehler-Anzeige Widgets
│   └── sync_progress_widgets.dart     # Sync-Fortschritt Widgets
└── docker/
    ├── Dockerfile                     # Multi-Stage Flutter Web Build
    ├── docker-compose.yml             # Web + PocketBase
    └── nginx.conf                     # Reverse Proxy
```

---

## Requirements

### Für Docker (Web-Deployment)
- [Docker](https://docs.docker.com/get-docker/) >= 20.10
- [Docker Compose](https://docs.docker.com/compose/) >= 2.0

### Für lokale Entwicklung
- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.41.4
- [Dart SDK](https://dart.dev/get-dart) >= 3.11.1
- [PocketBase](https://pocketbase.io/docs/) >= 0.36.6 (für Backend)
- Android Studio / VS Code mit Flutter-Plugin

### Für Mobile-Build
- Android SDK >= 21 (Android 5.0+)

> ℹ️ **iOS**: Nicht aktiv unterstützt. iOS-Build ist theoretisch möglich, wurde aber nicht getestet.

---

## Installation

### Docker (Web)

Die schnellste Methode – startet Frontend und Backend in einem Befehl:

```bash
# 1. Repository klonen
git clone git clone https://github.com/dein-user/elektronik-lagerverwaltung.git
cd elektronik-lagerverwaltung

# 2. Environment-Datei erstellen
cp .env.example .env

# 3. Container starten
docker compose up -d --build

# 4. Fertig! Öffne im Browser:
#    App:   http://localhost:8081
#    Admin: http://localhost:8080/_/
```

> ⚠️ **Wichtig**: Nach dem ersten Start muss die PocketBase Collection `artikel` manuell angelegt werden.  
> Siehe [PocketBase Setup](#pocketbase-setup).

### Local Development

```bash
# 1. Repository klonen
git clone https://github.com/dein-user/elektronik-lagerverwaltung.git
cd elektronik-lagerverwaltung/app

# 2. Dependencies installieren
flutter pub get

# 3. PocketBase starten (separates Terminal)
cd ../server
./pocketbase serve --http=0.0.0.0:8080

# 4. App starten
cd ../app

# Web:
flutter run -d chrome --dart-define=PB_URL=http://localhost:8080

# Desktop (Linux):
flutter run -d linux --dart-define=PB_URL=http://localhost:8080

# Mobile (Emulator/Gerät):
flutter run --dart-define=PB_URL=http://192.168.1.100:8080
```

### Mobile (Android)

```bash
# Android APK bauen
flutter build apk --release \
  --dart-define=PB_URL=http://<your-server>:8080
```

---

## Configuration

### PocketBase Setup

Beim ersten Start muss PocketBase konfiguriert werden:

1. **Admin-UI öffnen**: `http://localhost:8080/_/`
2. **Admin-Account erstellen** (E-Mail + Passwort)
3. **Collection `artikel` erstellen** mit folgendem Schema:

| Feld | Typ | Optionen |
|------|-----|----------|
| `name` | Text | Required |
| `menge` | Number | Default: 0 |
| `ort` | Text | Required |
| `fach` | Text | Required |
| `beschreibung` | Text | — |
| `bildPfad` | Text | — |
| `thumbnailPfad` | Text | — |
| `thumbnailEtag` | Text | — |
| `erstelltAm` | Text | — |
| `aktualisiertAm` | Text | — |
| `remoteBildPfad` | Text | — |
| `bild` | File | Max Size: 5MB, MIME: image/* |
| `uuid` | Text | Required, Unique |
| `updated_at` | Number | Default: 0 |
| `deleted` | Boolean | Default: false |
| `etag` | Text | — |
| `remote_path` | Text | — |a
| `device_id` | Text | — |

4. **API Rules konfigurieren** (für Collection `artikel`):
   - List/Search: `@request.auth.id != ""` (oder leer für öffentlich)
   - View/Create/Update/Delete: nach Bedarf

> 💡 **Tipp**: Ein PocketBase-Migrations-Script (`pb_migrations/`) ist geplant, um diesen Schritt zu automatisieren.

### Environment Variables

Erstelle eine `.env`-Datei im Projekt-Root (Vorlage: `.env.example`):

```env
# Port für die Web-App (Frontend + API über nginx)
WEB_PORT=8081

# Optional: PocketBase direkt erreichbar machen (für Debugging)
# PB_PORT=8080
```

### App Settings

In der App unter **Einstellungen** konfigurierbar:

| Einstellung | Beschreibung | Standard |
|-------------|-------------|----------|
| **PocketBase URL** | Server-Adresse | `/api` (Web) oder `http://127.0.0.1:8080` (Mobile) |
| **Start-Artikelnummer** | Erste ID für neue Artikel | `1000` |

### Nextcloud (Optional)

> ⚠️ **Hinweis**: Nextcloud-Integration ist implementiert aber **ungetestet**. Nur auf Mobile/Desktop verfügbar.

1. In der App: **Menü → Nextcloud-Einstellungen**
2. Server-URL, Benutzername und App-Passwort eingeben
3. Basis-Ordner für Backups festlegen

---

## Usage

### Quick Start

1. **Docker starten**: `docker compose up -d`
2. **Browser öffnen**: `http://localhost:8081`
3. **PocketBase Admin einrichten**: `http://localhost:8080/_/`
4. **Collection `artikel` erstellen** (siehe [PocketBase Setup](#pocketbase-setup))
5. **Ersten Artikel anlegen**: Klick auf "Neuer Artikel"

### Command Line

```bash
# Container starten
docker compose up -d --build

# Container stoppen
docker compose down

# Logs anzeigen
docker compose logs -f

# Nur Frontend-Logs
docker compose logs -f app

# Nur Backend-Logs
docker compose logs -f server

# Container neu bauen (nach Code-Änderungen)
docker compose up -d --build app

# PocketBase Daten sichern
docker compose exec server cp -r /pb_data /pb_data_backup

# Shell im Container öffnen
docker compose exec app sh
docker compose exec server sh
```

### Web Interface

| URL | Beschreibung |
|-----|-------------|
| `http://localhost:8081/` | Flutter Web App |
| `http://localhost:8080/_/` | PocketBase Admin UI |
| `http://localhost:8080/api/health` | Health-Check Endpoint |
| `http://localhost:8080/api/collections/artikel/records` | API: Alle Artikel |

### Mobile App

- **Artikelliste**: Startseite mit Suche und Filter
- **Neuer Artikel**: FAB-Button unten rechts
- **Scanner**: QR/Barcode-Button (wenn Kamera verfügbar)
- **Detail**: Tippe auf einen Artikel zum Bearbeiten
- **Menü**: Drei-Punkte-Menü oben rechts für Import/Export/Einstellungen
- **Pull-to-Refresh**: Liste nach unten ziehen zum Aktualisieren

---

## Troubleshooting

### 🔴 "PocketBase nicht erreichbar"

**Web (Docker)**:
```bash
# Prüfe ob Container laufen
docker compose ps

# Prüfe Health-Check
curl http://localhost:8080/api/health

# Logs prüfen
docker compose logs server
```

**Mobile**:
- Einstellungen → PocketBase URL prüfen
- Gerät muss im gleichen Netzwerk sein
- URL-Format: `http://192.168.1.100:8080/api` (über nginx) oder `http://192.168.1.100:8080` (direkt)

### 🔴 "Bilder werden nicht angezeigt"

**Web**: Prüfe ob das `bild`-Feld in der PocketBase Collection existiert (Typ: File)

**Mobile**: Bilder werden lokal gespeichert unter `app_flutter/images/`. Prüfe die Berechtigungen.

### 🔴 "Sync funktioniert nicht"

```bash
# Prüfe Netzwerk
ping dein-server

# Prüfe PocketBase API
curl http://dein-server:8080/api/health

# App-Log prüfen: Menü → Log-Ansicht
```

### 🟡 "Docker Build dauert sehr lange"

```bash
# Prüfe ob .dockerignore vorhanden ist
cat .dockerignore

# Nur Frontend neu bauen (ohne PocketBase)
docker compose up -d --build app

# Build-Cache nutzen (--no-cache nur wenn wirklich nötig!)
docker compose build app
```

### 🟡 "Port bereits belegt"

```bash
# Prüfe welcher Prozess den Port nutzt
lsof -i :8081
# oder
netstat -tlnp | grep 8081

# Anderen Port in .env setzen
echo "WEB_PORT=8082" > .env
docker compose up -d
```

---

## Development

### Project Structure

```
elektronik-lagerverwaltung/
├── app/                        # Flutter App
│   ├── lib/                    # Dart Source Code
│   ├── android/                # Android-spezifisch
│   ├── web/                    # Web-spezifisch
│   ├── linux/                  # Linux Desktop
│   ├── pubspec.yaml            # Dependencies
│   ├── Dockerfile              # Web Build
│   └── nginx.conf              # Reverse Proxy Config
├── server/
│   ├── pb_data/                # PocketBase Datenbank (gitignored)
│   └── pb_public/              # Öffentliche Dateien
├── docker-compose.yml
├── .env                        # Environment Variables (gitignored)
├── .env.example                # Template
├── .dockerignore
├── .gitignore
└── README.md
```

### Platform Architecture

Die App nutzt **Conditional Imports** um plattformspezifischen Code zu isolieren:

```
feature_screen.dart          # Haupt-Widget (plattformunabhängig)
├── feature_screen_io.dart   # Mobile/Desktop Implementation (dart:io)
└── feature_screen_stub.dart # Web-Stub (kein dart:io)
```

**Beispiel**:
```dart
// In der Hauptdatei:
import 'feature_io.dart'
    if (dart.library.html) 'feature_stub.dart' as platform;

// Verwendung:
if (kIsWeb) {
  // PocketBase direkt
} else {
  // Lokale DB + platform.doSomething()
}
```

### Key Design Decisions

| Entscheidung | Begründung |
|-------------|-----------|
| **Offline-First (Mobile)** | Zuverlässigkeit in Werkstatt/Lager ohne WLAN |
| **Online-Only (Web)** | Web läuft im Docker neben PocketBase → immer verbunden |
| **PocketBase statt eigenes Backend** | Einfach, eingebettete DB, File Storage, Admin UI |
| **nginx Reverse Proxy** | Ein Port für alles, kein CORS, einfaches Deployment |
| **Conditional Imports** | Saubere Trennung statt `kIsWeb`-Checks mit `dart:io` |
| **Soft-Delete** | Sync-Kompatibilität, Daten-Recovery möglich |
| **UUID statt Auto-Increment** | Eindeutige IDs über Geräte hinweg |

### Adding Features

1. **Neues Model-Feld**:
   - `artikel_model.dart` → `toMap()`, `fromMap()`, `copyWith()` erweitern
   - DB-Version in `artikel_db_service.dart` erhöhen + Migration schreiben
   - PocketBase Collection Schema aktualisieren

2. **Neuer Screen**:
   - Screen in `lib/screens/` erstellen
   - Bei `dart:io`-Nutzung: `_io.dart` + `_stub.dart` anlegen
   - Route in `main.dart` registrieren

3. **Neuer Service**:
   - Service in `lib/services/` erstellen
   - Bei `dart:io`-Nutzung: Conditional Import Pattern verwenden

### Testing

> ⚠️ **Teststatus**: Tests laufen


#### Test-Prioritäten

| Priorität | Bereich |
|-----------|---------|
| 🔴 Kritisch | Artikel anlegen / bearbeiten / löschen |
| 🔴 Kritisch | PocketBase Sync Push/Pull |
| 🔴 Kritisch | Konfliktlösung bei Sync |
| 🟡 Wichtig | CSV/JSON Import & Export |
| 🟡 Wichtig | Bildverwaltung |
| 🟢 Nice-to-have | PDF Export, QR Scanner, Nextcloud |

```bash
# Unit Tests
flutter test

# Integration Tests
flutter test integration_test/

# Web-Build testen
flutter build web --release --dart-define=PB_URL=/api
cd build/web && python3 -m http.server 8080

# Docker-Build testen
docker compose up -d --build
curl http://localhost:8081/api/health
```

---

## Contributing

Beiträge sind willkommen! Bitte beachte folgende Regeln:

1. **Fork** das Repository
2. **Feature-Branch** erstellen: `git checkout -b feature/mein-feature`
3. **Conditional Imports** verwenden wenn `dart:io` benötigt wird
4. **Testen** auf Web UND Mobile
5. **Commit**: `git commit -m 'feat: Beschreibung'`
6. **Push**: `git push origin feature/mein-feature`
7. **Pull Request** erstellen

### Commit Convention

```
feat:     Neues Feature
fix:      Bugfix
refactor: Code-Umstrukturierung
docs:     Dokumentation
style:    Formatierung
test:     Tests
chore:    Build/Dependencies
```

### Code Style

- Dart-Dateien: `snake_case.dart`
- Klassen: `PascalCase`
- Variablen: `camelCase`
- Deutsche UI-Texte, englische Code-Kommentare wo sinnvoll
- `flutter analyze` muss fehlerfrei sein

---

### Roadmap

- Datenbanktest (Web)
  - Artikel anlegen, ändern, löschen  ✅
  - Artikel export JSON / import JSON ❌ (fehlende Bilder)
- PocketBase-Migrations-Script
- Druck ud PDF Export



## License

Dieses Projekt steht unter der [MIT License](LICENSE).

```
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 🙏 Acknowledgements

- [Flutter](https://flutter.dev/) — UI Framework
- [PocketBase](https://pocketbase.io/) — Backend & Database
- [nginx](https://nginx.org/) — Reverse Proxy
- [Docker](https://www.docker.com/) — Containerization
- [Nextcloud](https://nextcloud.com/) — Optional Cloud Backup
