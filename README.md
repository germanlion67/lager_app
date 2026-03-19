# 📦 Lager_app

Eine plattformübergreifende Lagerverwaltungs-App für z.B. Elektronikbauteile,
gebaut mit **Flutter** und **PocketBase**.
Verfügbar als mobile App (Android) und als Web-App im Docker-Container.

![Flutter](https://img.shields.io/badge/Flutter-3.41.4-blue?logo=flutter)
![PocketBase](https://img.shields.io/badge/PocketBase-0.36.6-green?logo=pocketbase)
![Docker](https://img.shields.io/badge/Docker-Compose-blue?logo=docker)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Test Status](https://img.shields.io/badge/Tests-⚠️%20ungetestet-orange)

> ⚠️ **Teststatus**: Stand März 2026 – Nicht für Produktionseinsatz empfohlen.
> Manuelles Testing läuft. Siehe [Prüfplan](#prüfplan).
> Nextcloud: Implementierung vorhanden (WebDAV-Client, Upload/Backup-Workflow).
> Integration ist als experimentell/ungeprüft gekennzeichnet.

---

## 📋 Inhaltsverzeichnis

- [Übersicht](#übersicht)
- [Features](#features)
- [Architektur](#architektur)
- [Voraussetzungen](#voraussetzungen)
- [Installation](#installation)
  - [Docker (Web) — Dev/Test](#docker-web--devtest)
  - [Docker (Web) — Produktion](#docker-web--produktion)
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
- [Prüfplan](#prüfplan)
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
| 🖥️ **Desktop (Linux/Windows)** | SQLite (lokal) | Lokales Dateisystem | Background-Sync mit PocketBase |
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

> ⚠️ **Wichtig**: `POCKETBASE_URL` muss eine vom **Browser** erreichbare
> Adresse sein — nicht die interne Docker-Adresse. Der Flutter Web Build
> läuft im Browser des Nutzers, nicht im Container. `localhost` funktioniert
> in Dev/Test nur weil Port `8080` nach außen gemappt ist.

### Produktions-Setup

```
Internet
  │
  └──→ Nginx Proxy Manager :80/:443  SSL, Header, Routing
         │
         ├──→ Flutter Web (Caddy :8081)
         │
         └──→ PocketBase (:8080)
```

Der vorgeschaltete **Nginx Proxy Manager** übernimmt in Produktion:
SSL/HTTPS, Sicherheits-Header, Gzip-Kompression und Zugriffskontrolle
für die PocketBase Admin UI.

PocketBase und Frontend sind in Produktion **nicht** direkt von außen
erreichbar — nur über den Nginx Proxy Manager.

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
- [Docker](https://docs.docker.com/get-docker/) >= 29.0
- [Docker Compose](https://docs.docker.com/compose/) >= 2.40

### Lokale Entwicklung
- [Flutter SDK](https://docs.flutter.dev/get-started/install) >= 3.41.4
- [Dart SDK](https://dart.dev/get-dart) >= 3.11.1
- [PocketBase](https://pocketbase.io/docs/) >= 0.36.6
- Android Studio / VS Code mit Flutter-Plugin

### Mobile-Build
- Android SDK >= 21 (Android 5.0+)

> ℹ️ **iOS**: Nicht aktiv unterstützt.

---

## Installation

### Docker (Web) — Dev/Test

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
> `artikel` manuell angelegt werden. Siehe [PocketBase Setup](#pocketbase-setup).

---

### Docker (Web) — Produktion

```bash
# 1. Repository klonen
git clone https://github.com/germanlion67/lager_app.git
cd lager_app

# 2. Produktions-.env anlegen
cp .env.example .env.production
nano .env.production
# → POCKETBASE_URL=https://api.deine-domain.de setzen

# 3. Stack starten (baut Flutter Web mit Produktions-URL)
docker compose \
  -f docker-compose.prod.yml \
  --env-file .env.production \
  up -d --build

# 4. Nginx Proxy Manager Admin UI öffnen
#    http://dein-server-ip:81
#    Standard-Login: admin@example.com / changeme
#    → Sofort Passwort ändern!
```

#### Nginx Proxy Manager — Proxy Hosts einrichten

Nach dem ersten Login zwei Proxy Hosts anlegen:

**Flutter Web Frontend:**

| Feld | Wert |
|---|---|
| Domain | `deine-domain.de` |
| Scheme | `http` |
| Forward Hostname | `lager_frontend` |
| Forward Port | `8081` |
| SSL | Let's Encrypt ✅ |
| Force SSL | ✅ |

**PocketBase API:**

| Feld | Wert |
|---|---|
| Domain | `api.deine-domain.de` |
| Scheme | `http` |
| Forward Hostname | `pocketbase` |
| Forward Port | `8080` |
| SSL | Let's Encrypt ✅ |
| Force SSL | ✅ |

> ⚠️ **Wichtig**: Nach URL-Änderung muss der Frontend-Container neu gebaut
> werden — `POCKETBASE_URL` wird zur Build-Zeit eingebrannt:
> ```bash
> docker compose -f docker-compose.prod.yml \
>   --env-file .env.production \
>   up -d --build app
> ```

---

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

# App starten (Desktop Windows)
flutter run -d windows \
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
3. **Collection `artikel` manuell erstellen**:

> 💡 Ein Migrations-Script (`server/pb_migrations/1772784781_created_artikel.js`)
> liegt im Repository und dient als Referenz für das Schema.
> Da der Migrations-Ordner nicht automatisch gemountet wird,
> muss die Collection beim ersten Start manuell angelegt werden.

| Feld | Typ | Pflicht | Hinweise |
|---|---|---|---|
| `name` | Text | ✅ | Artikelbezeichnung |
| `menge` | Number | — | Ganzzahl (`onlyInt`), min: 0 |
| `ort` | Text | ✅ | Lagerort |
| `fach` | Text | ✅ | Lagerfach |
| `beschreibung` | Text | — | Optionale Beschreibung |
| `bildPfad` | Text | — | Lokaler Bildpfad (Mobile/Desktop) |
| `erstelltAm` | Text | — | Erstellungszeitpunkt |
| `aktualisiertAm` | Text | — | Letzter Update-Zeitpunkt |
| `remoteBildPfad` | Text | — | Remote-Bildpfad (Nextcloud) |
| `bild` | File | — | Max: 5 MB, MIME: png/jpeg/gif/tiff/bmp/webp |
| `uuid` | Text | ✅ | Client-seitige UUID, Unique |
| `updated_at` | Number | — | Unix-Timestamp, letztes Update |
| `deleted` | Boolean | — | Soft-Delete Flag |
| `etag` | Text | — | Sync-ETag |
| `remote_path` | Text | — | WebDAV/Remote-Pfad |
| `device_id` | Text | — | Gerätekennzeichnung |
| `kategorie` | Text | — | Artikelkategorie |

> ℹ️ **Thumbnail-Felder**: Die Felder `thumbnailPfad` und `thumbnailEtag`
> existieren ausschließlich in der lokalen SQLite-Datenbank (Mobile/Desktop)
> und werden **nicht** zu PocketBase synchronisiert. Sie sind als Vorbereitung
> für ein noch nicht implementiertes Thumbnail-Feature angelegt. Das
> PocketBase-Schema benötigt diese Felder daher **nicht**.

4. **API Rules konfigurieren**:

> ⚠️ **Sicherheitshinweis:** Standardmäßig sind alle API-Regeln der
> `artikel`-Collection auf `""` gesetzt — das bedeutet **öffentlich
> zugänglich ohne Authentifizierung**. Für den Produktionsbetrieb
> müssen diese Regeln in der Admin UI eingeschränkt werden:
> **Collection → artikel → API Rules**

---

### Umgebungsvariablen

#### Dev/Test — `.env`

Vorlage: `.env.example`

```dotenv
# Port für Flutter Web App (Caddy)
WEB_PORT=8081

# Port für PocketBase (API + Admin UI)
PB_PORT=8080

# Vom Browser erreichbare PocketBase URL
# localhost funktioniert nur weil Port 8080 nach außen gemappt ist!
POCKETBASE_URL=http://localhost:8080
```

#### Produktion — `.env.production`

```dotenv
# Öffentliche PocketBase URL (vom Browser erreichbar!)
# Muss von außen erreichbar sein — kein localhost!
POCKETBASE_URL=https://api.deine-domain.de

# Interne Ports (nur Docker-intern, kein Port-Mapping in Prod)
PB_PORT=8080
WEB_PORT=8081
```

> ⚠️ **Wichtig**: Beide `.env`-Dateien **nicht** ins Git committen!
> Nur `.env.example` (ohne echte Werte) gehört ins Repository.

> ⚠️ **Wichtig**: Die PocketBase-URL für Flutter Web wird zur
> **Build-Zeit** eingebrannt. Wenn sich die URL ändert (z.B. für
> Produktion), muss der Container neu gebaut werden:
> `docker compose up -d --build app`

---

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
# Dev/Test
docker compose up -d --build
# Web-App:    http://localhost:8081
# PocketBase: http://localhost:8080/_/

# Produktion
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build
# Nginx Proxy Manager Admin: http://dein-server-ip:81
```

### Kommandozeile

```bash
# Starten (Dev)
docker compose up -d --build

# Starten (Prod)
docker compose -f docker-compose.prod.yml --env-file .env.production up -d --build

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
docker run --rm \
  -v lager_app_pb_data:/pb_data \
  -v $(pwd):/backup \
  alpine tar czf /backup/pb_backup_$(date +%Y%m%d_%H%M%S).tar.gz /pb_data

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

### 🟡 "Frontend zeigt alte Version nach Rebuild"

`POCKETBASE_URL` wird zur Build-Zeit eingebrannt — ein einfaches
`docker compose restart app` reicht nicht:

```bash
# Zwingend neu bauen
docker compose up -d --build app
```

### 🟡 "Nginx Proxy Manager Admin UI nicht erreichbar" (Prod)

```bash
# Container-Status prüfen
docker compose -f docker-compose.prod.yml ps

# Logs prüfen
docker compose -f docker-compose.prod.yml logs nginx-proxy-manager
```

> ⚠️ Der NPM Admin-Port `81` ist in Produktion nur auf `127.0.0.1`
> gebunden — kein direkter Zugriff von außen. SSH-Tunnel nutzen:
> `ssh -L 81:localhost:81 user@server`

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
│   ├── pb_migrations/           # Schema-Referenz (nicht auto-gemountet)
│   ├── pb_public/               # Öffentliche Dateien
│   ├── pb_backups/              # Backups — nur Produktion (gitignored)
│   └── npm/                     # Nginx Proxy Manager — nur Produktion
│       ├── data/                # NPM Konfiguration & Datenbank (gitignored)
│       └── letsencrypt/         # SSL-Zertifikate (gitignored)
├── .github/
│   └── workflows/               # CI/CD Pipelines
├── docker-compose.yml           # Dev/Test
├── docker-compose.prod.yml      # Produktion
├── .env                         # Dev-Umgebungsvariablen (gitignored)
├── .env.production              # Prod-Umgebungsvariablen (gitignored)
├── .env.example                 # Vorlage (im Git)
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
| **`POCKETBASE_URL` zur Build-Zeit** | Kein Runtime-Config-Server nötig; SharedPreferences als Override |
| **`expose` statt `ports` in Prod** | PocketBase & Frontend nicht direkt von außen erreichbar |
| **Conditional Imports** | Saubere Trennung ohne `kIsWeb`-Checks mit `dart:io` |
| **Soft-Delete** | Sync-Kompatibilität, Daten-Recovery |
| **UUID statt Auto-Increment** | Eindeutige IDs über Geräte hinweg |

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

## Prüfplan

### Phase 1 — Linux 🐧

```bash
# 1. PocketBase im Hintergrund starten
cd ~/lager_app
docker compose up pocketbase -d

# 2. Health-Check
curl http://localhost:8080/api/health

# 3. App bauen
cd app
flutter build linux --release \
  --dart-define=POCKETBASE_URL=http://localhost:8080

# 4. App starten
./build/linux/x64/release/bundle/lager_app
```

- [x] Artikel anlegen, ändern, löschen
- [x] Suche & Filter (Ort / ~~Fach~~ / Kombination)
- [x] PDF Export — Alle Artikel (FilePicker + xdg-open)
- [x] PDF Export — Gefilterte Artikel
- [x] PDF Export — Artikel-Detail (mit & ohne Bild)
- [x] PDF Öffnen — Fehlerfall (Snackbar max. 3 Sek., kein ewiges Hängen)
- [ ] ZIP-Backup lokal exportieren & importieren
- [ ] ZIP-Backup Nextcloud exportieren & importieren

> **Stolperstellen:**
> - `xdg-open` benötigt einen laufenden Desktop-Session-Bus — im reinen TTY-Modus schlägt es lautlos fehl
> - FilePicker braucht `xdg-desktop-portal` + passendes Backend (`xdg-desktop-portal-gtk` o.ä.) — ohne Portal greift der `~/Downloads/`-Fallback

```
sudo apt update && sudo apt install -y \
  xdg-desktop-portal \
  xdg-desktop-portal-gtk
```

> - `sqflite_common_ffi` benötigt `libsqlite3-dev` als System-Paket (`sudo apt install libsqlite3-dev`)

> **Bekannte Einschränkungen:**
> - Kamera-Funktion auf Desktop (Linux/Windows) und Web nicht verfügbar
  (kein `cameraDelegate` für `image_picker`).
  Der Kamera-Button wird auf diesen Plattformen automatisch ausgeblendet
  (`ImagePickerService.isCameraAvailable`).
  Nur Dateiauswahl verfügbar.
> - Kamera auf iOS: technisch vorbereitet, aktuell nicht aktiv getestet.

---

### Phase 1 — Windows 🪟

```powershell
flutter build windows --release
.\build\windows\x64\runner\Release\lager_app.exe
```

- [ ] Artikel anlegen, ändern, löschen
- [ ] Suche & Filter (Ort / Fach / Kombination)
- [ ] PDF Export — Alle Artikel (FilePicker + url_launcher)
- [ ] PDF Export — Gefilterte Artikel
- [ ] PDF Export — Artikel-Detail (mit & ohne Bild)
- [ ] PDF Öffnen — Fehlerfall (Snackbar max. 3 Sek., kein ewiges Hängen)
- [ ] ZIP-Backup lokal exportieren & importieren
- [ ] ZIP-Backup Nextcloud exportieren & importieren

> **Stolperstellen:**
> - Pfad-Trenner: `\` statt `/` — `Platform.environment['USERPROFILE']` statt `HOME` für den Downloads-Fallback prüfen
> - `url_launcher` benötigt zwingend `LaunchMode.externalApplication`, sonst öffnet sich nichts
> - Dateinamen mit Umlauten (`äöüÄÖÜß`) können auf NTFS-Partitionen zu Encoding-Problemen führen — Regex im `cleanName` testen
> - SQLite-DLL (`sqlite3.dll`) muss im App-Verzeichnis liegen — wird bei `flutter build windows` automatisch kopiert, bei manuellem Deployment prüfen

---

### Phase 2 — Android 🤖

```bash
# Debug auf angeschlossenem Gerät / Emulator
flutter run -d android

# Release APK (Sideloading)
flutter build apk --release
# APK liegt unter: build/app/outputs/flutter-apk/app-release.apk

# Release AAB (Play Store)
flutter build appbundle --release
```

- [ ] Artikel anlegen, ändern, löschen
- [ ] Suche & Filter (Ort / Fach / Kombination)
- [ ] PDF Export — Alle Artikel (share_plus Share-Sheet)
- [ ] PDF Export — Gefilterte Artikel
- [ ] PDF Export — Artikel-Detail (mit & ohne Bild)
- [ ] PDF Öffnen — Fehlerfall (Snackbar max. 3 Sek., kein ewiges Hängen)
- [ ] ZIP-Backup lokal exportieren & importieren
- [ ] ZIP-Backup Nextcloud exportieren & importieren

> **Stolperstellen:**
> - `WRITE_EXTERNAL_STORAGE` Permission ab Android 10+ eingeschränkt — `getExternalStorageDirectory()` liefert nur App-privaten Pfad, **nicht** den sichtbaren Download-Ordner
> - Ab Android 11+ (API 30) braucht man `MANAGE_EXTERNAL_STORAGE` oder `MediaStore`-API für öffentliche Ordner — im `AndroidManifest.xml` prüfen
> - Share-Sheet: `ShareResultStatus.success` wird auf manchen Android-Versionen **nicht** zuverlässig zurückgegeben (Samsung-ROMs bekannt) — Fehlerfall trotzdem testen
> - Bilder aus der Galerie: `file_picker` benötigt `READ_MEDIA_IMAGES` (Android 13+) statt `READ_EXTERNAL_STORAGE`

---

### Phase 3 — iOS 🍎

```bash
# Debug auf Simulator
flutter run -d ios

# Release Build (benötigt macOS + Xcode)
flutter build ios --release

# Auf Gerät installieren via Xcode
open ios/Runner.xcworkspace
```

- [ ] Artikel anlegen, ändern, löschen
- [ ] Suche & Filter (Ort / Fach / Kombination)
- [ ] PDF Export — Alle Artikel (iOS Share-Sheet)
- [ ] PDF Export — Gefilterte Artikel
- [ ] PDF Export — Artikel-Detail (mit & ohne Bild)
- [ ] PDF Öffnen — Fehlerfall (Snackbar max. 3 Sek., kein ewiges Hängen)
- [ ] ZIP-Backup lokal exportieren & importieren
- [ ] ZIP-Backup Nextcloud exportieren & importieren

> **Stolperstellen:**
> - iOS Sandbox: `getDownloadsDirectory()` zeigt nur App-internen Ordner — Dateien sind nur über die Dateien-App sichtbar wenn `UIFileSharingEnabled = true` in `Info.plist` gesetzt ist
> - `NSPhotoLibraryUsageDescription` + `NSCameraUsageDescription` müssen in `Info.plist` eingetragen sein, sonst Crash beim Bildpicker
> - Share-Sheet auf iOS gibt **immer** `ShareResultStatus.dismissed` zurück, nie `success` — Erfolgs-Logik entsprechend anpassen
> - TestFlight / physisches Gerät nötig für vollständigen Test — Simulator hat keinen Share-Sheet-Flow

---

### Phase 3 — Web 🌐

```bash
# Stack starten (PocketBase + Flutter Web via Caddy)
docker compose up --build

# Nur PocketBase neu starten (z.B. nach Schema-Änderung)
docker compose restart pocketbase

# Nur Frontend neu bauen (z.B. nach Code-Änderung)
docker compose up --build app

# Logs live verfolgen
docker compose logs -f

# PocketBase Admin UI
# → http://localhost:8080/_/

# Flutter Web App
# → http://localhost:8081/

# Stack stoppen
docker compose down
```

- [ ] Artikel anlegen, ändern, löschen
- [ ] Suche & Filter (Ort / Fach / Kombination)
- [ ] PDF Export — Download via Browser
- [ ] ZIP-Backup exportieren & importieren

> **Stolperstellen:**
> - `POCKETBASE_URL` wird zur **Build-Zeit** eingebrannt (`--dart-define`) — nach URL-Änderung zwingend `docker compose up --build app` ausführen, `restart` allein reicht nicht
> - PocketBase Schema muss vor dem ersten App-Start manuell angelegt sein — Admin UI unter `http://localhost:8080/_/` prüfen, sonst schlagen alle API-Calls lautlos fehl
> - Browser blockiert `http://localhost:8080` wenn die App über `https://` ausgeliefert wird (Mixed Content) — in Dev/Test beide Dienste auf `http` halten
> - CORS: PocketBase erlaubt in Dev standardmäßig alle Origins — in Produktion hinter Nginx Proxy Manager explizit einschränken (**Settings → Application → Allowed Origins**)
> - `dart:io` (`File`, `Directory`, `Platform`) existiert im Browser **nicht** — PDF- und ZIP-Funktionen benötigen eine Web-spezifische Implementierung (`dart:html` / `package:web`)
> - Caddy liefert nur statische Assets aus — SPA-Routing (alle Routen → `/index.html`) muss im `Caddyfile` korrekt konfiguriert sein, sonst gibt es `404` bei direktem URL-Aufruf

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