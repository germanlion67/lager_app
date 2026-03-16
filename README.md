# 📦 Lager_app

Eine plattformübergreifende Lagerverwaltungs-App für z.B. Elektronikbauteile,
gebaut mit **Flutter** und **PocketBase**.
Verfügbar als mobile App (Android) und als Web-App im Docker-Container.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![PocketBase](https://img.shields.io/badge/PocketBase-0.36.6-green?logo=pocketbase)
![Docker](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Test Status](https://img.shields.io/badge/Tests-⚠️%20ungetestet-orange)

> ⚠️ **Teststatus**: Stand März 2026 – Nicht für Produktionseinsatz empfohlen.
> Manuelles Testing läuft. Siehe [Roadmap](#roadmap).
> Nextcloud: Implementierung vorhanden (WebDAV-Client, Upload/Backup-Workflow).
> Integration ist als experimentell/ungeprüft gekennzeichnet.

---

## 📋 Inhaltsverzeichnis

- [Übersicht](#übersicht)
- [Features](#features)
- [Architektur](#architektur)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
  - [Docker (Web)](#docker-web)
  - [Lokale Entwicklung](#lokale-entwicklung)
  - [Mobile (Android)](#mobile-android)
- [Konfiguration](#konfiguration)
  - [PocketBase Setup](#pocketbase-setup)
  - [Umgebungsvariablen](#umgebungsvariablen)
  - [App-Einstellungen](#app-einstellungen)
  - [Nextcloud (Optional)](#nextcloud-optional)
- [Verwendung](#verwendung)
  - [Quick Start](#quick-start)
  - [Kommandozeile](#kommandozeile)
  - [Web-Interface](#web-interface)
  - [Mobile App](#mobile-app)
- [Troubleshooting](#troubleshooting)
- [Entwicklung](#entwicklung)
  - [Projektstruktur](#projektstruktur)
  - [Plattform-Architektur](#plattform-architektur)
  - [Features hinzufügen](#features-hinzufügen)
  - [Tests](#tests)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Lizenz](#lizenz)

---

## Übersicht

Die **Lager_app** ist eine Offline-First-Anwendung zur Verwaltung von
Elektronikbauteilen und Lagerbeständen. Sie funktioniert auf mobilen Geräten
und im Browser.

### Kernkonzept

| Plattform | Datenbank | Bilder | Sync |
|---|---|---|---|
| 📱 **Mobile (Android)** | SQLite (lokal) | Lokales Dateisystem | Background-Sync mit PocketBase |
| 🖥️ **Desktop (Linux)** | SQLite (lokal) | Lokales Dateisystem | Background-Sync mit PocketBase |
| 🌐 **Web (Docker)** | PocketBase (direkt) | PocketBase File Storage | Kein Sync nötig (immer online) |

---

## Architektur

### Dev/Test-Setup

```
Browser
  │
  ├──→ Flutter Web (Caddy :8081)     statische Assets
  │
  └──→ PocketBase (:8080)            API + Admin UI
```

Flutter Web kommuniziert **direkt** mit PocketBase — kein interner
Reverse Proxy. Die PocketBase-URL wird zur **Build-Zeit** eingebrannt
(`--dart-define=POCKETBASE_URL=...`).

### Produktions-Setup

```
Internet
  │
  └──→ Nginx Proxy Manager           SSL, Header, Routing
         │
         ├──→ Flutter Web (Caddy :8081)
         │
         └──→ PocketBase (:8080)
```

Der vorgeschaltete **Nginx Proxy Manager** übernimmt in Produktion:
SSL/HTTPS, Sicherheits-Header, Gzip-Kompression und Zugriffskontrolle
für die PocketBase Admin UI.

> **Warum kein nginx im Container?**
> Da in Produktion ein Nginx Proxy Manager vorgeschaltet ist, wäre
> nginx im Container doppelt gemoppelt. Caddy übernimmt nur das
> Ausliefern der statischen Flutter-Assets und das SPA-Routing —
> das sind 4 Zeilen Konfiguration statt 200.

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
- **Sync bei App-Resume**: Automatischer Sync wenn App in den Vordergrund kommt
- **WiFi-Only Option**: Sync nur im WLAN
- **Konfliktlösung**: Manuelle Konfliktauflösung über eigenen Screen
- Desktop: Periodische Timer-Sync (15 min)
- Mobile Background-Sync: vorbereitet, aktuell nicht aktiv

### 📄 Export & Backup
- JSON-Export / -Import
- CSV-Export / -Import
- ZIP-Backup (Daten + Bilder)
- PDF-Berichte (nur Mobile/Desktop)
- Nextcloud ZIP-Backup (optional, ungetestet)

### 🌐 Web-Version
- Identische UI wie Mobile
- Läuft als Docker-Container (Caddy)
- PocketBase direkt erreichbar (kein Proxy)
- Kein lokaler Speicher nötig

### ☁️ Nextcloud Integration (Optional, ungetestet)
- ZIP-Backup zu Nextcloud
- Dokumenten-Ablage pro Artikel
- Verbindungsstatus-Anzeige

---

## Voraussetzungen

### Docker (Web-Deployment)
- [Docker](https://docs.docker.com/get-docker/) >= 20.10
- [Docker Compose](https://docs.docker.com/compose/) >= 2.0

### Lokale Entwicklung
- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.32.0
- [Dart SDK](https://dart.dev/get-dart) >= 3.8.0
- [PocketBase](https://pocketbase.io/docs/) >= 0.36.6
- Android Studio / VS Code mit Flutter-Plugin

### Mobile-Build
- Android SDK >= 21 (Android 5.0+)

> ℹ️ **iOS**: Nicht aktiv unterstützt.

---

## Installation

### Docker (Web)

```bash
# 1. Repository klonen
git clone https://github.com/germanlion67/lager_app.git
cd lager_app

# 2. Umgebungsvariablen anlegen
cp .env.example .env
# .env bei Bedarf anpassen (Ports)

# 3. Container starten
docker compose up -d --build

# 4. Fertig!
#    Web-App:       http://localhost:8081
#    PocketBase:    http://localhost:8080/_/
```

> ⚠️ **Wichtig**: Nach dem ersten Start muss die PocketBase Collection
> `artikel` angelegt werden. Siehe [PocketBase Setup](#pocketbase-setup).

### Lokale Entwicklung

```bash
# 1. Repository klonen
git clone https://github.com/germanlion67/lager_app.git
cd lager_app/app

# 2. Dependencies installieren
flutter pub get

# 3. PocketBase starten (separates Terminal)
cd ../server
./pocketbase serve --http=0.0.0.0:8080

# 4. App starten (Web)
cd ../app
flutter run -d chrome \
    --dart-define=POCKETBASE_URL=http://localhost:8080

# App starten (Desktop Linux)
flutter run -d linux \
    --dart-define=POCKETBASE_URL=http://localhost:8080

# App starten (Mobile — IP des Entwicklungsrechners angeben)
flutter run \
    --dart-define=POCKETBASE_URL=http://192.168.1.100:8080
```

### Mobile (Android)

```bash
flutter build apk --release \
    --dart-define=POCKETBASE_URL=http://<server-ip>:8080
```

---

## Konfiguration

### PocketBase Setup

Beim ersten Start:

1. **Admin-UI öffnen**: `http://localhost:8080/_/`
2. **Admin-Account erstellen** (E-Mail + Passwort)
3. **Collection `artikel` erstellen**:

| Feld | Typ | Optionen |
|---|---|---|
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
| `bild` | File | Max: 5 MB, MIME: image/* |
| `uuid` | Text | Required, Unique |
| `updated_at` | Number | Default: 0 |
| `deleted` | Boolean | Default: false |
| `etag` | Text | — |
| `remote_path` | Text | — |
| `device_id` | Text | — |

4. **API Rules** nach Bedarf konfigurieren.

> 💡 Ein PocketBase-Migrations-Script ist in Planung.

### Umgebungsvariablen

Datei: `.env` im Projekt-Root (Vorlage: `.env.example`)

```env
# Port für Flutter Web App (Caddy)
WEB_PORT=8081

# Port für PocketBase (API + Admin UI)
PB_PORT=8080
```

> ⚠️ **Wichtig**: Die PocketBase-URL für Flutter Web wird zur
> **Build-Zeit** eingebrannt. Wenn sich die URL ändert (z.B. für
> Produktion), muss der Container neu gebaut werden:
> `docker compose up -d --build app`

### App-Einstellungen

In der App unter **Einstellungen** konfigurierbar:

| Einstellung | Beschreibung | Standard |
|---|---|---|
| **PocketBase URL** | Server-Adresse (Laufzeit-Override) | `http://localhost:8080` |
| **Start-Artikelnummer** | Erste ID für neue Artikel | `1000` |

### Nextcloud (Optional)

> ⚠️ Nur Mobile/Desktop. Ungetestet.

1. **Menü → Nextcloud-Einstellungen**
2. Server-URL, Benutzername und App-Passwort eingeben
3. Basis-Ordner festlegen

---

## Verwendung

### Quick Start

```bash
docker compose up -d --build
# Web-App:    http://localhost:8081
# PocketBase: http://localhost:8080/_/
```

### Kommandozeile

```bash
# Starten
docker compose up -d --build

# Stoppen
docker compose down

# Alle Logs
docker compose logs -f

# Nur Frontend
docker compose logs -f app

# Nur Backend
docker compose logs -f pocketbase

# Frontend neu bauen (nach Code-Änderungen)
docker compose up -d --build app

# PocketBase-Daten sichern
docker compose exec pocketbase cp -r /pb_data /pb_data_backup

# Shell im Frontend-Container
docker compose exec app sh
```

### Web-Interface

| URL | Beschreibung |
|---|---|
| `http://localhost:8081/` | Flutter Web App |
| `http://localhost:8080/_/` | PocketBase Admin UI |
| `http://localhost:8080/api/health` | Health-Check |
| `http://localhost:8080/api/collections/artikel/records` | API: Alle Artikel |

### Mobile App

- **Artikelliste**: Startseite mit Suche und Filter
- **Neuer Artikel**: FAB-Button unten rechts
- **Scanner**: QR/Barcode-Button (wenn Kamera verfügbar)
- **Detail**: Tippe auf einen Artikel zum Bearbeiten
- **Menü**: Drei-Punkte-Menü für Import/Export/Einstellungen
- **Pull-to-Refresh**: Liste nach unten ziehen

---

## Troubleshooting

### 🔴 "PocketBase nicht erreichbar" (Web)

```bash
# Container-Status prüfen
docker compose ps

# Health-Check prüfen
curl http://localhost:8080/api/health

# Logs prüfen
docker compose logs pocketbase
```

Häufige Ursachen:
- Container noch nicht gestartet → kurz warten, `docker compose ps` erneut
- Port 8080 bereits belegt → `PB_PORT=8090` in `.env` setzen

### 🔴 "PocketBase nicht erreichbar" (Mobile)

- **Einstellungen → PocketBase URL** prüfen
- Gerät muss im gleichen Netzwerk sein
- Format: `http://192.168.1.100:8080`
- Firewall auf dem Server prüfen: Port 8080 muss offen sein

### 🔴 "Seite nicht gefunden" nach Flutter-Navigation

Caddy leitet alle unbekannten Pfade auf `/index.html` weiter
(SPA-Routing). Falls das nicht funktioniert:

```bash
# Caddyfile prüfen
docker compose exec app cat /etc/caddy/Caddyfile

# Caddy-Logs prüfen
docker compose logs app
```

### 🔴 "Bilder werden nicht angezeigt"

**Web**: `bild`-Feld in PocketBase Collection prüfen (Typ: File).
Browser-Konsole auf CORS-Fehler prüfen.

**Mobile**: Lokaler Speicher unter `app_flutter/images/`. Berechtigungen prüfen.

### 🟡 "Docker Build dauert sehr lange"

```bash
# .dockerignore vorhanden?
cat app/.dockerignore

# Nur Frontend neu bauen
docker compose up -d --build app

# Cache nutzen (--no-cache nur wenn wirklich nötig)
docker compose build app
```

### 🟡 "Port bereits belegt"

```bash
# Belegten Prozess finden
lsof -i :8081

# Anderen Port in .env setzen
WEB_PORT=8082
docker compose up -d
```

### 🟡 "CORS-Fehler in der Browser-Konsole"

Da Flutter Web direkt auf PocketBase zugreift (kein Proxy), muss
PocketBase CORS für den Frontend-Origin erlauben.

In der PocketBase Admin UI:
**Settings → Application → Allowed Origins** → `http://localhost:8081` eintragen.

Für Produktion: Produktions-Domain eintragen.

---

## Entwicklung

### Projektstruktur

```
lager_app/
├── app/                         # Flutter App
│   ├── lib/                     # Dart Source Code
│   │   ├── config/
│   │   │   └── app_config.dart  # URL-Konfiguration
│   │   ├── models/              # Datenmodelle
│   │   ├── screens/             # UI Screens
│   │   ├── services/            # Business Logic
│   │   ├── utils/               # Hilfsfunktionen
│   │   └── widgets/             # Wiederverwendbare Widgets
│   ├── web/                     # Web-spezifisch (index.html, Icons)
│   ├── test/                    # Unit & Widget Tests
│   ├── tool/                    # Entwicklungs-Tools
│   ├── Caddyfile                # Static File Server Konfiguration
│   ├── Dockerfile               # Multi-Stage Web Build
│   ├── pubspec.yaml             # Dependencies
│   └── .dockerignore
├── server/
│   ├── pb_data/                 # PocketBase Datenbank (gitignored)
│   ├── pb_migrations/           # Schema-Migrationen
│   └── pb_public/               # Öffentliche Dateien
├── .github/
│   └── workflows/               # CI/CD Pipelines
├── docker-compose.yml
├── .env                         # Umgebungsvariablen (gitignored)
├── .env.example                 # Vorlage
└── README.md
```

### Plattform-Architektur

Die App nutzt **Conditional Imports** für plattformspezifischen Code:

```
feature_screen.dart           # Haupt-Widget (plattformunabhängig)
├── feature_screen_io.dart    # Mobile/Desktop (dart:io)
└── feature_screen_stub.dart  # Web-Stub (kein dart:io)
```

```dart
// Conditional Import Pattern
import 'feature_io.dart'
    if (dart.library.html) 'feature_stub.dart' as platform;
```

### Architektur-Entscheidungen

| Entscheidung | Begründung |
|---|---|
| **Offline-First (Mobile)** | Zuverlässigkeit ohne WLAN |
| **Online-Only (Web)** | Läuft neben PocketBase, immer verbunden |
| **PocketBase** | Einfach, eingebettete DB, File Storage, Admin UI |
| **Caddy statt nginx** | 4 Zeilen statt 200, kein Proxy nötig in Dev/Test |
| **Nginx Proxy Manager (Prod)** | Übernimmt SSL, Header, Routing zentral |
| **Conditional Imports** | Saubere Trennung ohne `kIsWeb`-Checks mit `dart:io` |
| **Soft-Delete** | Sync-Kompatibilität, Daten-Recovery |
| **UUID statt Auto-Increment** | Eindeutige IDs über Geräte hinweg |
| **URL zur Build-Zeit** | Kein Runtime-Config-Server nötig; SharedPreferences als Override |

### Features hinzufügen

**Neues Model-Feld**:
1. `artikel_model.dart` → `toMap()`, `fromMap()`, `copyWith()` erweitern
2. DB-Version in `artikel_db_service.dart` erhöhen + Migration
3. PocketBase Collection Schema aktualisieren

**Neuer Screen**:
1. Screen in `lib/screens/` erstellen
2. Bei `dart:io`: `_io.dart` + `_stub.dart` anlegen
3. Route in `main.dart` registrieren

### Tests

```bash
# Unit Tests
flutter test

# Einzelnen Test
flutter test test/models/artikel_model_test.dart

# Performance-Test (500 Artikel Import)
dart run tool/generate_import_dataset.dart --count 500
flutter test test/performance/import_500_smoke_test.dart

# Web-Build lokal testen (ohne Docker)
flutter build web --release \
    --dart-define=POCKETBASE_URL=http://localhost:8080
cd build/web && python3 -m http.server 9000
# → http://localhost:9000

# Docker-Build testen
docker compose up -d --build
curl http://localhost:8081/
curl http://localhost:8080/api/health
```

#### Test-Prioritäten

| Priorität | Bereich | Status |
|---|---|---|
| 🔴 Kritisch | Artikel anlegen / bearbeiten / löschen | ⚠️ manuell |
| 🔴 Kritisch | PocketBase Sync Push/Pull | ⚠️ manuell |
| 🔴 Kritisch | Konfliktlösung bei Sync | ❌ offen |
| 🟡 Wichtig | CSV/JSON Import & Export | ⚠️ teilweise |
| 🟡 Wichtig | Bildverwaltung | ❌ offen |
| 🟢 Nice-to-have | PDF Export, QR Scanner, Nextcloud | ❌ offen |

---

## Roadmap

### Web

- [x] Artikel anlegen, ändern, löschen ✅
- [ ] Artikel Export JSON / Import JSON (fehlende Bilder)
- [ ] Artikel Backup / Restore (inklusive Bilder)
- [ ] PocketBase-Migrations-Script (automatisches Schema-Setup)
- [ ] PDF Export & Druck
- [ ] Automatisierte Integrationstests

### Mobile

- [ ] Artikel anlegen, ändern, löschen
- [ ] Artikel Export JSON / Import JSON
- [ ] Artikel Backup / Restore (inklusive Bilder)
- [ ] PDF Export & Druck
- [ ] Background-Sync

---

## Contributing

1. **Fork** das Repository
2. **Feature-Branch**: `git checkout -b feature/mein-feature`
3. **Conditional Imports** bei `dart:io`-Nutzung verwenden
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
- Deutsche UI-Texte
- `flutter analyze` muss fehlerfrei sein

---

## Lizenz

[MIT License](LICENSE) — Copyright (c) 2026

---

## Danksagungen

- [Flutter](https://flutter.dev/) — UI Framework
- [PocketBase](https://pocketbase.io/) — Backend & Datenbank
- [Caddy](https://caddyserver.com/) — Static File Server
- [Docker](https://www.docker.com/) — Containerisierung
- [Nginx Proxy Manager](https://nginxproxymanager.com/) — Produktions-Proxy
- [Nextcloud](https://nextcloud.com/) — Optionales Cloud-Backup