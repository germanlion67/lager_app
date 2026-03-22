# 📝 Changelog

Alle wichtigen Änderungen am Projekt werden in dieser Datei dokumentiert.

## [1.2.0] - 2026-03-22

### 🎉 Hauptfeatures

#### H-001 & H-005: Release-Automatisierung & Image-Strategie
- **Automatische Release-Notes**: GitHub Release enthält automatisch generierte Release-Notes mit Download-Links
- **Image-Tagging-Strategie**: Vollständige Dokumentation für SemVer-Tags und Docker-Images
- **Production-Images**: docker-compose.prod.yml nutzt jetzt vorgebaute Images (kein lokaler Build)

#### M-007: Artikelnummer & Datenbank-Optimierung
- **Artikelnummer-Feld**: Eindeutige Artikelnummer (1-99999) für jeden Artikel
- **Unique Constraint**: Verhindert doppelte Artikelnummern
- **Performance-Indizes**: 5 neue Indizes für schnelle Abfragen (bis 10.000 Artikel)
- **Volltextsuche**: Optimierte Suche über Name, Beschreibung und Artikelnummer

### ✨ Neue Features

#### M-002: AppLogService Integration
- Debug-Prints in artikel_erfassen_screen.dart durch AppLogService ersetzt
- Debug-Prints in artikel_erfassen_io.dart durch AppLogService ersetzt
- Konsistente Logging-Strategie im gesamten Projekt

#### N-004: Roboto Font
- Roboto als Standard-Schriftart implementiert (via google_fonts)
- Funktioniert auf allen Plattformen (Web, Mobile, Desktop)
- Automatisches Font-Loading ohne Asset-Downloads

### 🔧 Verbesserungen

#### Dokumentation
- `docs/IMAGE_TAGGING_STRATEGIE.md` - Vollständige Image-Tagging-Dokumentation
- `docs/M-007_ARTIKELNUMMER_INDIZES.md` - Detaillierte Datenbank-Optimierungen
- `.env.production.example` erweitert mit VERSION-Variable
- `PRIORITAETEN_CHECKLISTE.md` aktualisiert (20/30 Punkte abgeschlossen)

#### Dependencies (N-001, N-002)
- `mocktail` entfernt (wurde nicht genutzt, mockito beibehalten)
- `dependency_overrides` ausführlich dokumentiert (Grund, Issue-Link, Prüfplan)
- Exakte Version für connectivity_plus_platform_interface (2.0.0)

#### CI/CD (H-001)
- Release-Notes werden automatisch generiert
- Download-Links für Android APK, AAB und Windows-Build
- Plattform-spezifische Installationsanleitungen

### 📚 Dokumentation

- Vollständige Image-Tagging-Strategie dokumentiert
- Performance-Analyse für 10.000 Artikel (O(log n) via B-Tree)
- Verifizierungs-Anleitung für produktionsbereite Deployments
- Dependency-Override mit Issue-Tracking und Wartungsplan

### 🔒 Datenintegrität

- **Unique Constraint**: Artikelnummern sind eindeutig (WHERE NOT deleted)
- **Performance-Indizes**: 
  - `idx_unique_artikelnummer` - Eindeutigkeit garantieren
  - `idx_search_name` - Namens-Suche optimieren
  - `idx_search_beschreibung` - Beschreibungs-Suche optimieren
  - `idx_sync_deleted_updated` - Sync-Abfragen beschleunigen
  - `idx_uuid` - UUID-Lookups optimieren

### ⚙️ Technische Details

**Datenbank-Migration:**
- Neue Migration: `1774186524_added_artikelnummer_indexes.js`
- Rollback-fähig (up/down migration)
- Automatische Ausführung beim PocketBase-Start

**Flutter-Model:**
- `Artikel.artikelnummer` (int?, optional für Abwärtskompatibilität)
- Vollständige Serialisierung (toMap, fromMap, toPocketBaseMap)
- Nullable int parsing (_parseIntNullable helper)

**Docker-Compose:**
- `docker-compose.prod.yml` nutzt nur `image:` (kein `build:`)
- ENV-Variable `VERSION` für flexible Image-Tags
- Unterstützt GHCR und Docker Hub

---

## [1.1.0] - 2026-03-21

### 🎉 Hauptfeatures

#### Automatische PocketBase-Initialisierung
- **K-003 BEHOBEN**: PocketBase wird beim ersten Start vollautomatisch initialisiert
- Admin-Benutzer wird automatisch erstellt (konfigurierbar via ENV-Variablen)
- Collections werden automatisch angelegt
- Migrationen werden automatisch angewendet
- Keine manuelle Konfiguration mehr erforderlich

#### Sicherheits-Verbesserungen
- **K-002 BEHOBEN**: API Rules erfordern jetzt Authentifizierung
- Alle Operationen (list, view, create, update, delete) benötigen Login
- Produktionssichere Konfiguration out-of-the-box
- Keine offenen API-Endpoints mehr

#### Produktions-Deployment
- Vollständige Produktions-Deployment-Dokumentation
- Docker Stack Support für Swarm-Deployments
- GitHub Actions Workflow für automatische Image-Builds
- Pre-built Images über GitHub Container Registry
- Vereinfachter Deployment-Prozess

### ✨ Neue Features

#### Docker & Deployment
- Custom PocketBase Dockerfile mit Initialisierung
- Automatisches Admin-User-Setup via ENV-Variablen
- `docker-stack.yml` für Swarm-Deployments
- `.env.production.example` Template
- GitHub Actions Workflow für Docker Hub/GHCR
- Deployment-Test-Script (`test-deployment.sh`)

#### Dokumentation
- `QUICKSTART.md` - Schnelleinstieg für Dev & Prod
- `docs/PRODUCTION_DEPLOYMENT.md` - Vollständige Produktions-Anleitung
- README aktualisiert mit automatischer Initialisierung
- Umgebungsvariablen-Dokumentation erweitert

#### Konfiguration
- PocketBase Admin-Credentials via ENV konfigurierbar
- Sichere API Rules vorkonfiguriert
- Migrations automatisch angewendet
- Konsistente ENV-Variablen für Dev/Test und Produktion

### 🔧 Verbesserungen

#### Projektstruktur
- `docker-compose.prod.yml` von `app/` nach Root verschoben
- Konsistente Verzeichnisstruktur
- Migrations-Ordner korrekt gemountet
- Init-Script mit ausführbaren Berechtigungen

#### Docker Compose
- Beide Compose-Files nutzen custom PocketBase Image
- Healthchecks erweitert (längere `start_period`)
- Bessere Service-Dependencies
- Klarere Kommentare und Dokumentation

#### Sicherheit
- API Rules mit Authentifizierungspflicht
- Admin-Passwort-Warnung prominent dokumentiert
- `.env` und `.env.production` nicht in Git
- Security-Checklisten in Dokumentation

### 🐛 Bugfixes

- PocketBase Migrations werden jetzt automatisch angewendet
- Collections werden beim ersten Start korrekt erstellt
- API Rules werden korrekt aus Migration übernommen
- Admin-User-Erstellung funktioniert zuverlässig

### 📚 Dokumentation

- Vollständige Produktions-Deployment-Anleitung hinzugefügt
- README aktualisiert mit automatischer Initialisierung
- Umgebungsvariablen vollständig dokumentiert
- Troubleshooting-Guides erweitert
- Quick Start Guide erstellt
- Test-Script für Deployment-Validierung

### 🔒 Sicherheit

- **KRITISCH**: API Rules erfordern jetzt Authentifizierung (K-002)
- Admin-Passwörter werden nicht mehr im Code gespeichert
- ENV-Dateien werden nicht ins Git committed
- Sichere Defaults für Produktion

### ⚠️ Breaking Changes

- **API Rules**: Authentifizierung ist jetzt erforderlich!
  - Bestehende Clients müssen sich anmelden
  - Öffentlicher Zugriff nicht mehr möglich
  - Falls gewünscht: Manuell in PocketBase Admin anpassen

- **Umgebungsvariablen**: Neue Pflicht-Variablen
  - `PB_ADMIN_EMAIL` - für Admin-User-Erstellung
  - `PB_ADMIN_PASSWORD` - für Admin-User-Erstellung
  - Siehe `.env.production.example` für Details

### 📦 Migration von älteren Versionen

Wenn Sie von einer Version vor 1.1.0 upgraden:

1. **Backup erstellen:**
   ```bash
   docker compose exec pocketbase /pb/pocketbase backup /pb_backups
   ```

2. **Neue ENV-Variablen setzen:**
   ```bash
   # In .env oder .env.production
   PB_ADMIN_EMAIL=admin@example.com
   PB_ADMIN_PASSWORD=changeme123
   ```

3. **Services neu bauen:**
   ```bash
   docker compose down
   git pull
   docker compose up -d --build
   ```

4. **API Rules prüfen:**
   - Öffne PocketBase Admin UI
   - Prüfe Collection "artikel" → API Rules
   - Falls öffentlicher Zugriff gewünscht: Manuell anpassen

### 🎯 Nächste Schritte

Geplant für zukünftige Versionen:

- **K-004**: Runtime-Konfiguration für POCKETBASE_URL
- **K-001**: Bundle Identifiers aktualisieren
- **H-002**: CORS-Konfiguration verbessern
- **M-001**: Testabdeckung erhöhen
- QR-Code-Scanning implementieren
- Backup/Restore-Automatisierung

---

## [1.0.0] - 2026-01-XX

### Initiales Release

- Flutter 3.41.4 mit Web-, Android- und Desktop-Support
- PocketBase 0.36.6 Backend
- Docker Compose Setup für Dev/Test
- Offline-First Architektur für Mobile/Desktop
- Background-Sync mit PocketBase
- Basis-Lagerverwaltungsfunktionen

---

**Legende:**
- 🎉 Hauptfeatures
- ✨ Neue Features
- 🔧 Verbesserungen
- 🐛 Bugfixes
- 📚 Dokumentation
- 🔒 Sicherheit
- ⚠️ Breaking Changes
- 📦 Migration
