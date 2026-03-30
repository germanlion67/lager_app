# 📝 Changelog

Alle wichtigen Änderungen am Projekt werden in dieser Datei dokumentiert.

## [0.7.3] — 2026-03-30

### Added — M-009: Login-Flow & Authentifizierung
- **Login-Screen** (`lib/screens/login_screen.dart`): E-Mail + Passwort Login mit
  Validierung, Loading-State, Fehlermeldungen und optionalem Passwort-Reset-Dialog
- **Auth-Gate in `main.dart`**: Automatische Prüfung des Auth-Status beim App-Start
  mit 4-stufiger Priorität (Setup → Auth-Check → Login → App)
- **Auto-Login**: Token-Refresh beim App-Start via `refreshAuthToken()` —
  PocketBase authStore persistiert Tokens automatisch
- **Logout**: Bestätigungs-Dialog im Settings-Screen mit Navigator-Cleanup
- **Benutzer-Info**: Account-Card im Settings-Screen zeigt angemeldeten User,
  Status-Badge und Auth-Status in der Info-Card
- **Token-Refresh** (`PocketBaseService.refreshAuthToken()`): Erneuert abgelaufene
  Tokens, räumt authStore bei Fehler auf
- **Passwort-Reset** (`PocketBaseService.requestPasswordReset()`): Sendet
  Reset-E-Mail über PocketBase
- **API-Regeln Migration** (`1700000000_set_auth_rules.js`): Collections `artikel`
  und `attachments` erfordern jetzt Authentifizierung (`@request.auth.id != ""`)
  mit Rollback-Migration (Regeln auf offen)

### Changed
- `PocketBaseService`: Neue Methoden `refreshAuthToken()`, `requestPasswordReset()`,
  `currentUserEmail` Getter hinzugefügt
- `main.dart`: Auth-Gate integriert — Sync startet erst nach erfolgreichem Login
- `SettingsScreen`: Optionaler `onLogout` Callback, Account-Card mit Logout-Button

### Security
- API-Regeln für `artikel` und `attachments` von offen auf Auth-pflichtig umgestellt
- Nur authentifizierte Benutzer können Daten lesen, erstellen, bearbeiten und löschen

--- 

## [0.7.2] — 2026-03-29

### Hinzugefügt
- **M-012: Dateianhänge (Attachments)** — Dokumente an Artikel anhängen
  - PocketBase Collection `attachments` mit File-Upload, Bezeichnung, Beschreibung
  - `AttachmentService` — CRUD-Operationen gegen PocketBase (plattformunabhängig)
  - `AttachmentModel` — Datenmodell mit MIME-Type-Erkennung und Größenformatierung
  - `AttachmentUploadWidget` — Upload-Dialog mit Dateiauswahl, Validierung und Fortschritt
  - `AttachmentListWidget` — Anhang-Liste mit Download, Bearbeiten und Löschen
  - `AnhaengeSektion` im Artikel-Detail-Screen mit Badge-Counter
  - Validierung: Max 20 Anhänge/Artikel, Max 10 MB/Datei, erlaubte MIME-Types
- **M-007: Artikelnummer-Anzeige** — Artikelnummer in Listen- und Detailansicht
  - Automatische Vergabe beim Erstellen (Startwert 1000, +1 pro Artikel)
  - `_getNextArtikelnummer()` prüft lokale DB und PocketBase für höchste Nummer
- **PocketBase Migration** `1774811640_updated_attachments.js` — API-Regeln für Attachments geöffnet und Sync-Felder (uuid, etag, device_id, deleted, updated_at) ergänzt

### Geändert
- **`artikel_model.dart`** — `toPocketBaseMap()` sendet jetzt `updated_at` für korrekten Sync
- **`artikel_detail_screen.dart`** — Zeigt `artikel.artikelnummer` statt `artikel.id` als Art.-Nr.
- **`artikel_list_screen.dart`** — Artikelnummer-Zeile in Listenansicht ergänzt
- **`attachment_service.dart`** — UUID wird beim Upload automatisch generiert (Pflichtfeld in PB-Schema)

### Behoben
- **Attachment-Upload 400-Fehler** — `uuid`-Pflichtfeld fehlte im Upload-Body
- **Attachment-Upload 400-Fehler** — API-Regeln erforderten Auth, App hat keinen Login-Flow
- **Artikelnummer nicht in PocketBase** — `toPocketBaseMap()` sendete `artikelnummer` bereits korrekt, aber `updated_at` fehlte
- **Falsche Art.-Nr. in Detailansicht** — Zeigte SQLite-ID statt fachliche Artikelnummer

### Dokumentation
- `CHANGELOG.md` — Aktualisiert für v0.7.2
- `DEPLOYMENT.md` — Attachments-Collection und offene API-Regeln dokumentiert
- `ARCHITECTURE.md` — Attachments-Collection im Datenmodell ergänzt
- `DATABASE.md` — Attachments-Schema und Sync-Felder dokumentiert
- `HISTORY.md` — Meilenstein v0.7.2 dokumentiert
- `OPTIMIZATIONS.md` und `CHECKLIST.md` zusammengelegt
- `M-009` (Login-Flow) als neuer offener Punkt hinzugefügt

### Bekannte Einschränkungen
- **Kein Login-Flow**: Alle PocketBase-Collections haben offene API-Regeln. Für Produktionsumgebungen mit öffentlichem Zugang muss ein Login-Screen implementiert werden (siehe M-009)

---

## [0.7.1] — 2026-03-27

### Hinzugefügt
- **H-003: Automatisierte Backups** — Dedizierter Backup-Container für Produktions-Deployments
  - `server/backup/Dockerfile` — Alpine-basierter Container mit Cron, SQLite3 und SMTP-Support
  - `server/backup/backup.sh` — Backup-Logik mit SQLite WAL-Checkpoint, tar.gz-Archivierung und Integritätsprüfung
  - `server/backup/entrypoint.sh` — Automatische Cron- und SMTP-Konfiguration aus Umgebungsvariablen
  - `scripts/restore.sh` — Interaktives Restore-Script mit Sicherheitskopie und Healthcheck
- **Backup-Container als Service** in `docker-compose.prod.yml`
  - Konfiguration vollständig über `.env.production` (kein manueller Crontab nötig)
  - Rotation alter Backups (konfigurierbar, Standard: 7 Tage)
  - E-Mail-Benachrichtigung (SMTP) bei Erfolg oder Fehler
  - Webhook-Benachrichtigung (Slack, Discord, Gotify, etc.)
  - Status-JSON (`last_backup.json`) für zukünftige App-Anzeige (siehe M-008)
  - Initiales Backup beim ersten Container-Start
- **Backup-Variablen** in `.env.example` und `.env.production.example` ergänzt
  - `BACKUP_ENABLED`, `BACKUP_CRON`, `BACKUP_KEEP_DAYS`
  - `BACKUP_NOTIFY`, `BACKUP_SMTP_*`, `BACKUP_WEBHOOK_URL`
- **M-008** als neuer Optimierungspunkt: Backup-Status im Settings-Screen der App anzeigen

### Geändert
- **DEPLOYMENT.md** — Architektur-Diagramm um Backup-Container erweitert; Backup-Abschnitt komplett überarbeitet mit Container-Dokumentation, Konfigurationsbeispielen und Restore-Anleitung
- **ARCHITECTURE.md** — Architektur-Diagramm um Backup-Container erweitert; Projektstruktur um `scripts/`, `server/backup/`, `server/pb_backups/` und `server/npm/` ergänzt
- **OPTIMIZATIONS.md** — H-003 als abgeschlossen markiert; M-008 hinzugefügt; Fortschritts-Tabelle aktualisiert (7 von 20 erledigt)
- **Maintenance-Workflow** (`.github/workflows/flutter-maintenance.yml`) — `working-directory: ./app` ergänzt, Flutter-Version gepinnt, Linux-Build hinzugefügt, `--exclude-tags performance` ergänzt

### Behoben
- **Maintenance-Workflow** lief im falschen Verzeichnis (Root statt `app/`)
- **`flutter pub outdated`** brach den Workflow ab wenn Pakete veraltet waren (jetzt `|| true`)
- **Windows-Build-Artefakt-Pfad** korrigiert (`app/build/windows/x64/runner/Release`)

--- 


## [0.7.0] - 2026-03-27

### 🎉 Hauptfeatures

#### K-004: Runtime-Konfiguration für PocketBase-URL
- **Server-URL zur Laufzeit konfigurierbar**: Die PocketBase-URL muss nicht mehr zwingend beim Build per `--dart-define` gesetzt werden
- **Setup-Screen beim Erststart**: Wenn keine URL konfiguriert ist, wird ein Einrichtungsbildschirm angezeigt
- **Kein Crash bei fehlender URL**: Die App startet immer, auch ohne vorkonfigurierte Server-URL
- **Alle Plattformen**: Setup-Screen funktioniert auf Mobile, Desktop und Web

### ✨ Neue Features

#### Server-Setup-Screen
- Eingabefeld für Server-URL mit Validierung (Schema, Format, Host)
- Verbindungstest über PocketBase Health-Endpoint
- Beispiel-URLs für Produktion, LAN-Test und Android-Emulator
- Localhost-Warnung auf Android mit Alternativvorschlägen
- Visuelles Feedback (Erfolg/Fehler) beim Verbindungstest

#### Flexible Build-Konfiguration
- `--dart-define=POCKETBASE_URL=...` ist jetzt vollständig optional
- Optionaler URL-Default für Demo- oder Kunden-Builds über CI/CD
- Release-Workflow mit `pocketbase_url`-Input für vorkonfigurierte Builds

### 🔧 Verbesserungen

#### AppConfig
- Placeholder-URLs (`your-production-server.com`, `192.168.178.XX`) als Fallbacks entfernt
- `validateForRelease()` und `validateConfig()` werfen nicht mehr bei fehlender URL
- Leerer String statt Placeholder wenn keine URL-Quelle verfügbar

#### PocketBaseService
- Neues `needsSetup`-Flag: Gibt `true` zurück wenn keine brauchbare URL konfiguriert ist
- Neues `hasClient`-Flag: Prüft ob ein funktionsfähiger Client vorhanden ist
- `initialize()` crasht nie mehr bei fehlender oder ungültiger URL
- Placeholder-URLs werden nicht als gültig behandelt
- `resetToDefault()` behandelt leeren Default korrekt

#### App-Start (main.dart)
- Setup-Screen-Weiche nach `PocketBaseService().initialize()`
- Sync-Services werden nur bei vorhandenem Client initialisiert
- Health-Check nur bei vorhandenem Client
- Nahtloser Übergang vom Setup-Screen zur normalen App

#### Settings-Screen
- `_resetPocketBaseUrl()` behandelt leeren Default korrekt
- Benutzerfreundliche Meldung wenn kein Build-Default vorhanden

#### CI/CD-Workflows
- `docker-build-push.yml`: Placeholder `POCKETBASE_URL=https://your-production-server.com` entfernt
- `docker-build-push.yml`: URL optional über GitHub Secret oder Workflow-Input
- `release.yml`: Neuer optionaler `pocketbase_url`-Input für alle Plattform-Builds
- Release Notes: Hinweis auf Setup-Screen beim ersten Start

### 📚 Dokumentation

- CHANGELOG.md aktualisiert
- HISTORY.md aktualisiert
- DEPLOYMENT.md um Runtime-Konfiguration ergänzt
- INSTALL.md um Setup-Screen-Anleitung ergänzt

### ⚙️ Technische Details

**URL-Prioritätskette (alle Plattformen):**

| Priorität | Quelle | Web | Mobile/Desktop |
|---|---|---|---|
| 1 (höchste) | SharedPreferences / localStorage | ✅ | ✅ |
| 2 | `window.ENV_CONFIG` (Runtime) | ✅ | ❌ |
| 3 | `--dart-define=POCKETBASE_URL` | ✅ | ✅ |
| 4 | Kein Wert → Setup-Screen | ✅ | ✅ |

**Geänderte Dateien:**
- `app/lib/config/app_config.dart` — Placeholder entfernt, Validierung entschärft
- `app/lib/services/pocketbase_service.dart` — needsSetup, robuste initialize()
- `app/lib/main.dart` — Setup-Screen-Weiche
- `app/lib/screens/settings_screen.dart` — _resetPocketBaseUrl angepasst
- `.github/workflows/docker-build-push.yml` — Placeholder entfernt
- `.github/workflows/release.yml` — pocketbase_url-Input

**Neue Dateien:**
- `app/lib/screens/server_setup_screen.dart` — Ersteinrichtungs-Screen

--- 

### 📦 Migration von 0.3.0 auf 0.7.0

1. **Keine Breaking Changes für Endbenutzer**: Bestehende Installationen mit gespeicherter URL in SharedPreferences funktionieren weiterhin ohne Änderung.

2. **Build-Prozess**: `--dart-define=POCKETBASE_URL=...` ist jetzt optional. Bestehende Build-Skripte funktionieren weiterhin, können aber vereinfacht werden.

3. **CI/CD**: Falls `POCKETBASE_URL` als GitHub Secret gesetzt ist, wird es weiterhin als Default verwendet. Andernfalls erscheint der Setup-Screen beim ersten Start.

4. **Docker/Web**: Die bestehende Runtime-Config über `window.ENV_CONFIG` und `docker-entrypoint.sh` funktioniert unverändert.

---

## [0.3.0] - 2026-03-22

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

## [0.2.0] - 2026-03-21

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