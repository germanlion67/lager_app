# 🏗️ Architecture Overview

## Production Deployment Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                          INTERNET                              │
└───────────────────────┬────────────────────────────────────────┘
                        │
                        │ HTTPS (443) / HTTP (80)
                        │
┌───────────────────────▼────────────────────────────────────────┐
│                 Nginx Proxy Manager                            │
│  ┌──────────────────────────────────────────────────────┐     │
│  │ • SSL Termination (Let's Encrypt)                    │     │
│  │ • Reverse Proxy                                      │     │
│  │ • Security Headers                                   │     │
│  │ • Rate Limiting                                      │     │
│  └──────────────────────────────────────────────────────┘     │
└────────┬────────────────────────────┬──────────────────────────┘
         │                            │
         │ :8081                      │ :8080
         │ (internal)                 │ (internal)
┌────────▼──────────────┐   ┌────────▼──────────────────────────┐
│  Flutter Web Frontend │   │  PocketBase Backend               │
│  ┌─────────────────┐  │   │  ┌─────────────────────────────┐  │
│  │ Caddy Server    │  │   │  │ • REST API                  │  │
│  │ • Static Files  │  │   │  │ • Admin UI                  │  │
│  │ • SPA Routing   │  │   │  │ • File Storage              │  │
│  └─────────────────┘  │   │  │ • Real-time Subscriptions   │  │
└───────────────────────┘   │  └─────────────────────────────┘  │
                            │  ┌─────────────────────────────┐  │
                            │  │ Auto-Initialization         │  │
                            │  │ • Create Admin User         │  │
                            │  │ • Apply Migrations          │  │
                            │  │ • Setup Collections         │  │
                            │  └─────────────────────────────┘  │
                            └───┬────────────────────────────────┘
                                │
                        ┌───────▼───────┐
                        │  Volumes      │
                        │  • pb_data    │
                        │  • pb_public  │
                        │  • pb_backups │
                        └───────────────┘
```

## Dev/Test Deployment Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                       DEVELOPER PC                             │
└───────────────────────┬────────────────────────────────────────┘
                        │
                        │ localhost
                        │
         ┌──────────────┴──────────────┐
         │                             │
         │ :8081                       │ :8080
         │ (exposed)                   │ (exposed)
┌────────▼──────────────┐   ┌──────────▼────────────────────────┐
│  Flutter Web Frontend │   │  PocketBase Backend               │
│  ┌─────────────────┐  │   │  ┌─────────────────────────────┐  │
│  │ Caddy Server    │  │   │  │ • REST API                  │  │
│  │ • Static Files  │  │   │  │ • Admin UI                  │  │
│  │ • SPA Routing   │  │   │  │ • File Storage              │  │
│  └─────────────────┘  │   │  └─────────────────────────────┘  │
└───────────────────────┘   │  ┌─────────────────────────────┐  │
                            │  │ Auto-Initialization         │  │
                            │  │ • Create Admin User         │  │
                            │  │ • Apply Migrations          │  │
                            │  │ • Setup Collections         │  │
                            │  └─────────────────────────────┘  │
                            └───┬────────────────────────────────┘
                                │
                        ┌───────▼────────┐
                        │  Local Volumes │
                        │  • pb_data     │
                        │  • pb_public   │
                        └────────────────┘
```

## Mobile/Desktop Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Mobile/Desktop App                          │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                   Flutter Frontend                       │ │
│  │  • Offline-First Architecture                           │ │
│  │  • Local SQLite Database                                │ │
│  │  • Image Caching                                        │ │
│  └────────┬─────────────────────────────────────────────────┘ │
└───────────┼────────────────────────────────────────────────────┘
            │
            │ Background Sync
            │
┌───────────▼────────────────────────────────────────────────────┐
│                    PocketBase Server                           │
│  • Conflict Resolution                                         │
│  • Delta Sync                                                  │
│  • File Upload/Download                                        │
└────────────────────────────────────────────────────────────────┘
```

## Data Flow

### 1. First Start (Auto-Initialization)

```
┌──────────────┐
│ Docker Start │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ PocketBase Container │
│ Starts               │
└──────┬───────────────┘
       │
       ▼
┌─────────────────────────────┐
│ init-pocketbase.sh Executes │
└──────┬──────────────────────┘
       │
       ├─► Check if data.db exists
       │   └─► No? Continue
       │
       ├─► Wait for PocketBase API
       │   └─► Health check loop
       │
       ├─► Create Admin User
       │   └─► From ENV variables
       │
       ├─► Copy Migrations
       │   └─► To pb_data/migrations/
       │
       └─► Apply Migrations
           └─► Create collections
               └─► Set API Rules
```

### 2. User Request Flow

```
┌─────────┐
│ Browser │
└────┬────┘
     │ HTTPS
     ▼
┌─────────────────┐
│ Nginx Proxy Mgr │ ◄─── SSL Certificate
└────┬────────────┘      (Let's Encrypt)
     │
     ├─► /         ──► Flutter Web (Caddy)
     │                  └─► Serve static files
     │
     └─► /api/*    ──► PocketBase
                        ├─► Check Authentication
                        ├─► Process Request
                        └─► Return JSON
```

### 3. Authentication Flow

```
┌──────────┐
│  Client  │
└────┬─────┘
     │ POST /api/collections/users/auth-with-password
     ▼
┌────────────────┐
│  PocketBase    │
│  Auth Service  │
└────┬───────────┘
     │ Validate
     ├─► Check email/password
     ├─► Generate JWT token
     └─► Return token + user
         │
         ▼
┌────────────────┐
│  Client Stores │
│  Token         │
└────────────────┘
     │
     │ Subsequent requests include:
     │ Authorization: Bearer <token>
     ▼
┌────────────────┐
│  PocketBase    │
│  Middleware    │
└────┬───────────┘
     │ Verify Token
     ├─► Valid? → Process request
     └─► Invalid? → 401 Unauthorized
```

## File Structure

```
lager_app/
├── app/                              # Flutter Application
│   ├── lib/                          # Dart source code
│   │   ├── config/                   # Zentrale Konfiguration
│   │   │   ├── app_config.dart       # URL, UI-Konstanten, Spacing/Radius/Font
│   │   │   ├── app_theme.dart        # Material3 Light/Dark Theme
│   │   │   └── app_images.dart       # Asset-Pfade, Feature-Flags
│   │   ├── core/                     # Kern-Infrastruktur
│   │   │   └── app_logger.dart       # Dünner Logger-Wrapper (AppLogService)
│   │   ├── models/                   # Datenmodelle
│   │   │   └── artikel_model.dart    # Artikel-Entity
│   │   ├── screens/                  # UI-Screens
│   │   │   ├── artikel_list_screen.dart
│   │   │   ├── artikel_detail_screen.dart
│   │   │   ├── artikel_erfassen_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   ├── sync_management_screen.dart
│   │   │   ├── conflict_resolution_screen.dart
│   │   │   ├── nextcloud_settings_screen.dart
│   │   │   ├── qr_scan_screen_mobile_scanner.dart
│   │   │   └── *_io.dart / *_stub.dart  # Platform-Adapter
│   │   ├── services/                 # Business-Logik & Services
│   │   │   ├── pocketbase_service.dart
│   │   │   ├── pocketbase_sync_service.dart
│   │   │   ├── artikel_db_service.dart
│   │   │   ├── sync_orchestrator.dart
│   │   │   ├── sync_service.dart
│   │   │   ├── sync_progress_service.dart
│   │   │   ├── sync_error_recovery.dart
│   │   │   ├── app_log_service.dart
│   │   │   ├── connectivity_service.dart
│   │   │   ├── tag_service.dart
│   │   │   ├── scan_service.dart
│   │   │   ├── pdf_service.dart
│   │   │   ├── artikel_export_service.dart
│   │   │   ├── artikel_import_service.dart
│   │   │   ├── nextcloud_sync_service.dart
│   │   │   ├── nextcloud_client.dart
│   │   │   └── *_io.dart / *_stub.dart  # Platform-Adapter
│   │   ├── utils/                    # Hilfsfunktionen
│   │   │   ├── dokumente_utils.dart  # Datei-Sortierung
│   │   │   ├── image_processing_utils.dart  # Bildverarbeitung
│   │   │   └── uuid_generator.dart   # UUID-Generierung
│   │   ├── widgets/                  # Wiederverwendbare Widgets
│   │   │   ├── artikel_bild_widget.dart  # Zentrales Bild-Widget
│   │   │   ├── sync_error_widgets.dart
│   │   │   ├── sync_progress_widgets.dart
│   │   │   ├── sync_conflict_handler.dart
│   │   │   ├── article_icons.dart
│   │   │   ├── image_crop_dialog.dart
│   │   │   └── nextcloud_resync_dialog.dart
│   │   ├── main.dart                 # App-Einstiegspunkt
│   │   ├── main_io.dart              # Desktop/Mobile-Initialisierung
│   │   └── main_stub.dart            # Web-Stub
│   ├── test/                         # Tests
│   │   ├── models/
│   │   ├── services/
│   │   ├── widgets/
│   │   └── performance/
│   ├── web/                          # Web-spezifische Dateien
│   │   ├── manifest.json             # PWA Manifest
│   │   └── index.html
│   ├── assets/images/                # App-Assets (Logo, Platzhalter)
│   ├── Caddyfile                     # Caddy Web Server Konfiguration
│   ├── Dockerfile                    # Multi-stage Build (Flutter→Caddy)
│   ├── docker-entrypoint.sh          # Entrypoint: Runtime-Config Generierung
│   ├── analysis_options.yaml         # Flutter Linter-Regeln
│   └── pubspec.yaml                  # Dependencies
│
├── server/                           # Backend Konfiguration
│   ├── Dockerfile                    # Custom PocketBase Image
│   ├── init-pocketbase.sh            # Auto-Initialisierungsscript
│   ├── manage_data.sh                # Daten-Management Script
│   ├── pb_migrations/                # Datenbank-Migrationen
│   │   ├── 1772784781_created_artikel.js
│   │   ├── 1772784782_created_users.js
│   │   ├── 1772784783_updated_artikel_ownership.js
│   │   ├── 1774186524_added_artikelnummer_indexes.js
│   │   └── pb_schema.json
│   └── pb_public/                    # Öffentliche Dateien (Volume)
│
├── packages/                         # Lokale Flutter Packages
│   └── runtime_env_config/           # Runtime-Konfiguration (Web)
│       └── lib/
│
├── .github/                          # GitHub-Konfiguration
│   └── workflows/                    # CI/CD Workflows
│       ├── release.yml               # Release: Test + Android + Windows + Linux
│       ├── docker-build-push.yml     # Docker Images bauen & pushen
│       ├── flutter-maintenance.yml   # Dependency-Updates überwachen
│       ├── build-and-deploy.yml      # Build & Deploy
│       ├── build-images.yml          # Images bauen
│       └── deploy.yml                # Deployment
│
├── docs/                             # Dokumentation
│   ├── PRIORITAETEN_CHECKLISTE.md    # Haupt-Checkliste aller Aufgaben
│   ├── ARCHITECTURE.md               # System-Architektur (diese Datei)
│   ├── PRODUCTION_DEPLOYMENT.md      # Produktions-Deployment-Anleitung
│   ├── MANUELLE_OPTIMIERUNGEN.md     # Manuelle Aufgaben & Klärungsfragen
│   ├── TECHNISCHE_ANALYSE_2026-03.md # Technische Analyse
│   ├── IMAGE_TAGGING_STRATEGIE.md    # Docker Image-Tagging
│   ├── M-007_ARTIKELNUMMER_INDIZES.md # Artikelnummer & Indizes
│   ├── OPTIMIZATIONS_MARCH_2026.md   # Optimierungen März 2026
│   ├── PHASE3_4_SUMMARY.md           # Phase 3/4 Zusammenfassung
│   ├── IMPLEMENTATION_SUMMARY.md     # Implementierungs-Zusammenfassung
│   ├── IMPLEMENTATION_SUMMARY_CRITICAL_PHASE.md
│   ├── README_ANALYSE.md             # README-Analyse
│   ├── datenkonstrukt.md             # Datenstruktur
│   └── logger.md                     # Logging-Dokumentation
│
├── android/                          # Android Platform-Dateien
├── ios/                              # iOS Platform-Dateien (zurückgestellt)
├── linux/                            # Linux Platform-Dateien
├── macos/                            # macOS Platform-Dateien
├── windows/                          # Windows Platform-Dateien
│
├── docker-compose.yml                # Dev/Test Setup
├── docker-compose.prod.yml           # Produktion (mit Build)
├── docker-compose.production.yml     # Produktion (Alternative)
├── docker-stack.yml                  # Docker Swarm Setup
├── portainer-stack.yml               # Portainer Stack
├── .env.example                      # Dev/Test Vorlage
├── .env.production.example           # Produktions-Vorlage
├── .env.production                   # Produktions-Config (nicht in Git)
├── test-deployment.sh                # Validierungsscript
├── DEPLOYMENT.md                     # Deployment-Anleitung (Kurzversion)
├── QUICKSTART.md                     # Schnellstart-Anleitung
├── CHANGELOG.md                      # Versionshistorie
└── README.md                         # Hauptdokumentation
```

## Security Boundaries

```
┌────────────────────────────────────────────────────────────────┐
│                       PUBLIC INTERNET                          │
│                      (Untrusted Zone)                          │
└───────────────────────┬────────────────────────────────────────┘
                        │
              ┌─────────▼──────────┐
              │   Firewall         │
              │   • Port 80 ✓      │
              │   • Port 443 ✓     │
              │   • Port 8080 ✗    │
              │   • Port 8081 ✗    │
              │   • Port 81 ✗      │
              └─────────┬──────────┘
                        │
┌───────────────────────▼────────────────────────────────────────┐
│                       DMZ                                      │
│  ┌────────────────────────────────────────────────────┐        │
│  │ Nginx Proxy Manager                                │        │
│  │ • SSL Termination                                  │        │
│  │ • Rate Limiting                                    │        │
│  │ • Security Headers                                 │        │
│  └────────────────────────────────────────────────────┘        │
└───────────────────────┬────────────────────────────────────────┘
                        │ Internal Network
┌───────────────────────▼────────────────────────────────────────┐
│                  APPLICATION ZONE                              │
│                  (Internal Only)                               │
│  ┌──────────────────┐        ┌──────────────────────┐         │
│  │ Flutter Web      │        │ PocketBase           │         │
│  │ Port: 8081       │        │ Port: 8080           │         │
│  │ (not exposed)    │        │ (not exposed)        │         │
│  └──────────────────┘        └──────────────────────┘         │
│                                      │                         │
│                              ┌───────▼──────┐                  │
│                              │  Volumes     │                  │
│                              │  (Encrypted) │                  │
│                              └──────────────┘                  │
└────────────────────────────────────────────────────────────────┘
```

## Deployment States

### State 1: Initial Deployment
```
[Fresh Server] → [Git Clone] → [Configure ENV] → [Docker Compose Up]
                                                         ↓
                                            [Auto-Init Runs]
                                                         ↓
                                            [Services Ready]
```

### State 2: Update Deployment
```
[Running Server] → [Git Pull] → [Docker Compose Build] → [Rolling Update]
                                                               ↓
                                                    [Zero Downtime]
```

### State 3: Backup & Restore
```
[Running Server] → [Create Backup] → [Copy to Safe Location]
                         ↓
                   [Disaster Occurs]
                         ↓
                   [Fresh Server] → [Restore Backup] → [Services Ready]
```

---

**Key Principles:**

1. **Security First**: Authentication required, no public endpoints
2. **Automation**: Zero-configuration deployment
3. **Simplicity**: One command to deploy
4. **Reliability**: Health checks and auto-restart
5. **Scalability**: Docker Stack support for multi-node
6. **Maintainability**: Clear structure and documentation
