# 📐 System-Architektur & Design

Dieses Dokument beschreibt die technische Architektur der **Lager_app**, die Datenstrukturen und die grundlegenden Design-Entscheidungen.

---
```text
┌────────────────────────────────────────────────────────────────┐
│                          INTERNET                              │
└───────────────────────┬────────────────────────────────────────┘
                        │
                        │ HTTPS (443) / HTTP (80)
                        │
┌───────────────────────▼────────────────────────────────────────┐
│                 Nginx Proxy Manager                            │
│  ┌──────────────────────────────────────────────────────┐      │
│  │ • SSL Termination (Let's Encrypt)                    │      │
│  │ • Reverse Proxy                                      │      │
│  │ • Security Headers                                   │      │
│  │ • Rate Limiting (kommt mit H-003)                    │      │
│  └──────────────────────────────────────────────────────┘      │
└────────┬────────────────────────────┬──────────────────────────┘
         │                            │
         │ :8081                      │ :8080
         │ (internal)                 │ (internal)
┌────────▼──────────────┐   ┌────────▼────────────────────────────┐
│  Flutter Web Frontend │   │  PocketBase Backend                 │
│  ┌─────────────────┐  │   │  ┌───────────────────────────────┐  │
│  │ Caddy Server    │  │   │  │ • REST API                    │  │
│  │ • Static Files  │  │   │  │ • Admin UI                    │  │
│  │ • SPA Routing   │  │   │  │ • File Storage                │  │
│  └─────────────────┘  │   │  │ • Real-time Subscriptions     │  │
│                       │   |  | • CORS (--origins Flag, H-002)│  │
└───────────────────────┘   │  └───────────────────────────────┘  │
                            │  ┌───────────────────────────────┐  │
                            │  │ Auto-Initialization           │  │
                            │  │ • Create Admin User           │  │
                            │  │ • Apply Migrations            │  │
                            │  │ • Setup Collections           │  │
                            │  └───────────────────────────────┘  │
                            └───┬─────────────────────────────────┘
                                │
                        ┌───────▼───────┐
                        │  Volumes      │
                        │  • pb_data    │◄──── Backup-Container
                        │  • pb_public  │      • Cron (konfigurierbar)
                        │  • pb_backups │      • SQLite WAL-Checkpoint
                        └───────────────┘      • tar.gz + Rotation
                                               • E-Mail / Webhook
                                               • last_backup.json

```

## 🏗️ High-Level Architektur

Die Lager_app folgt einem **Hybrid-Cloud-Modell** (Offline-First). Sie ist so konzipiert, dass sie auf mobilen Geräten ohne permanente Internetverbindung funktioniert, während die Web-Version direkt mit dem Backend kommuniziert.

### Plattform-Strategie

| Komponente | Mobile (Android/iOS) | Desktop (Linux/Win) | Web (Docker/Caddy) |
|---|---|---|---|
| **Frontend** | Flutter Native | Flutter Native | Flutter Web (SPA) |
| **Lokale DB** | SQLite (sqflite) | SQLite (FFI) | Keine (Direktzugriff) |
| **Dateisystem** | Pfad-basiert (Images, Docs) | Pfad-basiert (Images, Docs) | Browser Blob/Memory |
| **Sync-Logik** | Hintergrund-Worker | Manueller/Timer Sync | Nicht erforderlich |

---

## 📂 Projektstruktur

Das Repository ist als Monorepo organisiert, um Code-Teilung zwischen den Plattformen zu ermöglichen.

```text
lager_app/
├── app/                              # Flutter Hauptanwendung
│   ├── lib/
│   │   ├── config/                   # Zentrale Steuerung (Theming, Config)
│   │   ├── core/                     # Plattform-Abstraktion (Logger, Env)
│   │   ├── models/                   # POJO Datenklassen (Artikel, Dokument, User)
│   │   ├── screens/                  # UI-Pages (Home, Detail, Sync)
│   │   ├── services/                 # Business Logik (API, DB, Sync, DokumentSync)
│   │   ├── utils/                    # Helfer (Validierung, Image-Tools)
│   │   ├── widgets/                  # Wiederverwendbare UI-Komponenten
│   │   ├── main.dart                 # App-Einstiegspunkt (gemeinsam)
│   │   ├── main_io.dart              # Einstiegspunkt für native Plattformen (dart:io)
│   │   └── main_stub.dart            # Einstiegspunkt für Web (kein dart:io)
│   ├── android/                      # Android-spezifische Konfiguration
│   ├── ios/                          # iOS-spezifische Konfiguration
│   ├── linux/                        # Linux Desktop Konfiguration
│   ├── macos/                        # macOS-spezifische Konfiguration
│   ├── windows/                      # Windows Desktop Konfiguration
│   ├── web/                          # Web-spezifische Assets (index.html)
│   ├── assets/                       # Statische App-Assets (Bilder, Fonts)
│   ├── test/                         # Unit- & Integration-Tests
│   ├── tool/                         # Build-Hilfsskripte
│   ├── Caddyfile                     # Caddy Webserver-Konfiguration
│   ├── Dockerfile                    # Container-Build für Flutter Web
│   ├── docker-entrypoint.sh          # Startskript für den Web-Container
│   └── pubspec.yaml                  # Flutter Abhängigkeiten & Metadaten
├── packages/                         # Geteilte lokale Dart-Pakete
│   └── runtime_env_config/           # Paket für dynamische ENV-Injektion
├── scripts/                          # Host-Scripts für manuelle Operationen
│   └── restore.sh                    # Backup-Wiederherstellung (manuell)
├── server/                           # Backend-Infrastruktur
│   ├── backup/                       # Backup-Container
│   │   ├── Dockerfile                # Alpine + Cron + SQLite3
│   │   ├── entrypoint.sh             # Cron-Setup, SMTP-Config
│   │   └── backup.sh                 # Backup-Logik (WAL, tar.gz, Rotation)
│   ├── pb_data/                      # PocketBase-Datenbank & Uploads
│   ├── pb_backups/                   # Backup-Archiv & Status-JSON
│   ├── pb_migrations/                # JS-Migrationen für Schema-Versionierung
│   ├── pb_public/                    # Öffentliche PocketBase-Dateien
│   └── npm/                          # Nginx Proxy Manager Daten
│       ├── data/                     # NPM Konfiguration
│       └── letsencrypt/              # SSL-Zertifikate
├── docs/                             # Dokumentation & Spezifikationen
│   ├── ARCHITECTURE.md               # Architektur & Design-Entscheidungen
│   ├── CHECKLIST.md                  # Aktueller Implementierungsstand
│   ├── DATABASE.md                   # Datenbank-Design & Synchronisation
│   ├── HISTORY.md                    # Projekthistorie & Entscheidungslog
│   ├── IMAGE_TAGGING_STRATEGIE.md    # Docker Image-Tagging Konzept
│   ├── LOGGER.md                     # Logging-System Dokumentation
│   ├── OPTIMIZATIONS.md              # Offene Optimierungsaufgaben
│   ├── THEMING.md                    # AppConfig, AppTheme & Design-Tokens
│   └── TECHNISCHE_ANALYSE_2026-03.md # Technische Tiefenanalyse (März 2026)
├── android/                          # Root-Level Android Wrapper
├── ios/                              # Root-Level iOS Wrapper
├── linux/                            # Root-Level Linux Wrapper
├── macos/                            # Root-Level macOS Wrapper
├── windows/                          # Root-Level Windows Wrapper
├── .github/                          # GitHub Actions & CI/CD Workflows
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
└── .env.production.example           # Vorlage für Produktions-Variablen
```

---

## 💾 Datenmodell (PocketBase Schema)

Das Herzstück der Anwendung ist die Collection `artikel`. Ergänzt wird sie durch die Collection `artikel_dokumente` für die Dokumentenverwaltung.

### Collection: `artikel`

| Feld | Typ | Beschreibung | Index |
|---|---|---|---|
| `uuid` | Text | Client-seitige Eindeutigkeit (Primary Key) | ✅ `idx_uuid` |
| `artikelnummer` | Number | Fortlaufende ID für Menschen (1000+) | ✅ `idx_unique_an` |
| `name` | Text | Bezeichnung des Artikels | ✅ `idx_search_name` |
| `menge` | Number | Aktueller Bestand (nur Ganzzahlen) | — |
| `ort` / `fach` | Text | Lager-Hierarchie | — |
| `bild` | File | Binärdatei in PocketBase (Max 5MB) | — |
| `deleted` | Boolean | Soft-Delete Flag für den Sync-Prozess | ✅ `idx_sync` |
| `updated_at` | Number | Unix-Timestamp für Delta-Sync | ✅ `idx_sync` |

### Collection: `artikel_dokumente` (Neu ✨)

Jedes Dokument ist über `artikel_uuid` eindeutig einem Artikel zugeordnet.
Unterstützte Dateitypen: PDF, DOCX, XLSX, TXT und weitere.

| Feld | Typ | Beschreibung | Index |
|---|---|---|---|
| `artikel_uuid` | Text | Fremdschlüssel zur `artikel.uuid` | ✅ `idx_dok_artikel_uuid` |
| `uuid` | Text | Client-seitige Eindeutigkeit des Dokuments | ✅ `idx_dok_uuid` |
| `dateiname` | Text | Originaler Dateiname (z. B. `datenblatt.pdf`) | — |
| `dateityp` | Text | MIME-Type (z. B. `application/pdf`) | — |
| `beschreibung` | Text | Optionale Beschreibung des Dokuments | — |
| `dokument` | File | Die eigentliche Datei (PocketBase File-Field) | — |
| `deleted` | Boolean | Soft-Delete Flag für den Sync-Prozess | ✅ `idx_dok_sync` |
| `updated_at` | Number | Unix-Timestamp für Delta-Sync | ✅ `idx_dok_sync` |


### Collection: `attachments` (ab v0.7.2)

Dateianhänge pro Artikel. Unterstützt PDF, Office-Dokumente, Bilder und Textdateien.

| Feld | Typ | Beschreibung | Index |
|---|---|---|---|
| `artikel_uuid` | Text | Fremdschlüssel zur `artikel.uuid` (UUID-Pattern) | ✅ `idx_attachments_artikel_uuid` |
| `uuid` | Text | Client-seitige Eindeutigkeit | ✅ `idx_attachments_uuid` |
| `datei` | File | Dateianhang (max 10 MB) | — |
| `bezeichnung` | Text | Vom Nutzer vergebener Name | — |
| `beschreibung` | Text | Optionale Beschreibung | — |
| `mime_type` | Text | MIME-Typ der Datei | — |
| `datei_groesse` | Number | Dateigröße in Bytes | — |
| `sort_order` | Number | Sortierreihenfolge | ✅ `idx_attachments_sort` |
| `deleted` | Boolean | Soft-Delete Flag | ✅ `idx_attachments_deleted` |
| `updated_at` | Number | Unix-Timestamp für Sync | — |

**API-Regeln:** Aktuell offen (kein Auth erforderlich). Wird mit Login-Flow (M-009) auf Auth umgestellt.

### Synchronisations-Logik (Offline-First)
Der Sync-Prozess nutzt das **Last-Write-Wins** Prinzip in Verbindung mit einem **Soft-Delete** Mechanismus:
1.  **Push**: Lokale Änderungen (SQLite) werden anhand der `uuid` zu PocketBase gepusht.
2.  **Pull**: Datensätze, deren `updated_at` neuer als der letzte Sync-Zeitpunkt ist, werden heruntergeladen.
3.  **Conflict**: Bei gleichzeitiger Änderung wird der Nutzer über den `ConflictResolutionScreen` zur Entscheidung aufgefordert.
4.  **Dokumente**: Werden in einem **separaten Sync-Zyklus** behandelt — unabhängig von Textdaten und Bildern.

---

## 🎨 Design-System & Konfiguration

Um die Wartbarkeit zu erhöhen, nutzt die App eine dreistufige Konfiguration in `app/lib/config/`:

1.  **`AppConfig`**: Hält technische Konstanten (Spacing, Border-Radius, API-Timeouts).
2.  **`AppTheme`**: Implementiert Material 3 mit Unterstützung für `ThemeMode.system`.
3.  **`AppImages`**: Verwaltet Asset-Pfade und Feature-Flags für Hintergrundbilder oder Platzhalter.

**Vorteil**: Design-Änderungen (z.B. von 8px auf 12px Eckenradius) werden an genau einer Stelle geändert und wirken sich auf die gesamte App aus.

---

## 🛠️ Plattform-Abstraktion (Conditional Imports)

Da `dart:io` (Dateisystem) im Web nicht existiert, nutzt die App **Conditional Imports**. Dies verhindert Compiler-Fehler auf verschiedenen Plattformen.

**Beispiel**:
*   `artikel_erfassen_io.dart`: Implementiert Kamera-Zugriff und Datei-Operationen für Android/Linux.
*   `artikel_erfassen_stub.dart`: Implementiert Datei-Upload für Web.
*   `artikel_erfassen_screen.dart`: Importiert automatisch die richtige Version.

Dies gilt analog für die **Dokumenten-Funktionalität**: Auf nativen Plattformen werden Dokumente lokal gespeichert und via `open_file` geöffnet; im Web erfolgt der Zugriff direkt über den Browser-Download-Mechanismus.

---

## 🛡️ Sicherheits-Architektur

1.  **PocketBase Rules**: Der Zugriff auf die API ist im Produktionsmodus (`PB_DEV_MODE=0`) strikt an Rollen (`reader`/`writer`) gebunden. Dies gilt für `artikel` **und** `artikel_dokumente`.
2.  **Caddy Security**: Der interne Webserver liefert die App mit gehärteten HTTP-Headern aus:
    *   `Content-Security-Policy`: Verhindert XSS.
    *   `Strict-Transport-Security`: Erzwingt HTTPS.
    *   `X-Frame-Options`: Verhindert Clickjacking.
3.  **Network Isolation**: In Docker-Produktions-Setups kommunizieren Frontend und Backend über ein isoliertes internes Netzwerk ohne direkte Port-Exposition.
4.  **Datei-Validierung**: Beim Dokument-Upload wird der MIME-Type serverseitig geprüft, um unerwünschte Dateitypen abzuweisen.

---

## 📄 Dokument-Verwaltung (Neu ✨)

Der Artikel-Detail-Screen enthält einen dedizierten **Dokumente-Tab**, der folgende Funktionen bietet:

```text
┌─────────────────────────────────────────────────────────┐
│              DOKUMENTE-TAB (Artikel-Detail)             │
│                                                         │
│  ┌─────────────────────────────────────────────────┐   │
│  │ 📄 datenblatt.pdf          [Öffnen] [Löschen]   │   │
│  │ 📄 einbauanleitung.docx    [Öffnen] [Löschen]   │   │
│  │ 📄 pruefprotokoll.xlsx     [Öffnen] [Löschen]   │   │
│  └─────────────────────────────────────────────────┘   │
│                                                         │
│  [ + Dokument hinzufügen ]                              │
│                                                         │
│  Plattform-Verhalten:                                   │
│  • Native (Android/Linux): Speichern + open_file        │
│  • Web: Direkter Browser-Download                       │
└─────────────────────────────────────────────────────────┘
```

| Aktion | Native | Web |
|---|---|---|
| **Upload** | `file_picker` → lokale Kopie + PocketBase | `file_picker` → direkt zu PocketBase |
| **Öffnen** | Lokal gespeichert → `open_file` | Browser-Download / Inline-Anzeige |
| **Löschen** | Soft-Delete lokal → Hard-Delete beim Sync | Direktes DELETE via REST API |

---

[Zurück zur README](../README.md) | [Zu den Installationsdetails](../INSTALL.md)