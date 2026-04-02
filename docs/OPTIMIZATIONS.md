# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Übersicht über den Projektfortschritt,
offene Aufgaben und technische Optimierungen der **Lager_app**.

**Version:** 0.7.5+0 | **Zuletzt aktualisiert:** 02.04.2026

---

## 📊 Gesamtfortschritt

| Phase | Fortschritt | Status |
|---|---|---|
| Phase 1: Grundlagen | 100% | ✅ |
| Phase 2: Deployment & Security | 100% | ✅ |
| Phase 3: Performance & Optimierung | 100% | ✅ |
| Phase 4: Multi-Plattform & Politur | 45% | 🔴 |

### Plattform-Status

| Plattform | Status |
|---|---|
| Web (Chrome) | ✅ Voll funktionsfähig |
| Linux Desktop | ✅ Build & PDF-Export stabil |
| Windows Desktop | ✅ Build & Export stabil |
| Android | ✅ Build stabil, Kamera-Test ausstehend |
| iOS/macOS | ⏸️ Zurückgestellt (Apple Developer Account) |

---

## ✅ Abgeschlossen

### K-001: Bundle Identifiers — Erledigt
- Android: `com.germanlion67.lagerverwaltung` ✅
- iOS: `com.germanlion67.lagerverwaltung` ✅

### K-002: PocketBase Schema & API Rules — Erledigt in v0.2.0
- Automatische Initialisierung (Admin-User, Collections, Migrations) ✅
- API Rules konfiguriert ✅

### K-003: Artikelnummer & Indizes — Erledigt in v0.3.0
- Eindeutige Artikelnummer (1000+) ✅
- 5 Performance-Indizes ✅
- Artikelnummer in Listen- und Detailansicht ✅ (v0.7.2)

### K-004: Runtime-Konfiguration PocketBase-URL — Erledigt in v0.7.0
- Setup-Screen beim Erststart ✅
- URL-Prioritätskette
  (`SharedPreferences` → Runtime-Config → `dart-define` → Setup-Screen) ✅
- Kein Crash bei fehlender URL ✅

### K-005: WSL2-Bildanzeige — Erledigt in v0.7.1
- Web-Server-Modus für WSL2-Entwicklung dokumentiert ✅

### O-001: Bereinigung von `debugPrint` — Erledigt
- Alle `debugPrint`-Aufrufe durch `AppLogService` ersetzt ✅
- Verbleibende 8 Aufrufe in `app_log_io.dart` sind absichtlich
  *(zirkuläre Abhängigkeit)* ✅

### M-002: AppLogService Integration — Erledigt in v0.3.0
- Konsistentes Logging im gesamten Projekt ✅

### N-004: Roboto Font — Erledigt in v0.3.0
- Roboto als Standard-Schriftart via `google_fonts` ✅

### H-003: Backup-Automatisierung — Erledigt in v0.7.1
- Dedizierter Backup-Container mit Cron ✅
- SQLite WAL-Checkpoint vor jedem Backup ✅
- Komprimiertes tar.gz-Archiv mit Integritätsprüfung ✅
- Rotation alter Backups (konfigurierbar, Standard: 7 Tage) ✅
- E-Mail- und Webhook-Benachrichtigung ✅
- Status-JSON (`last_backup.json`) für App-Anzeige ✅
- Restore-Script mit Sicherheitskopie und Healthcheck ✅

### M-012: Dateianhänge (Attachments) — Erledigt in v0.7.2
- PocketBase Collection `attachments` mit File-Upload ✅
- `AttachmentService` — CRUD gegen PocketBase ✅
- Upload-Widget mit Validierung (20 Anhänge, 10 MB, MIME-Types) ✅
- Anhang-Liste mit Download, Bearbeiten, Löschen ✅
- Badge-Counter im Detail-Screen ✅
- PB-Migration für offene API-Regeln ✅

### M-009: Login-Flow & Authentifizierung — Erledigt in v0.7.3
- Login-Screen mit E-Mail/Passwort-Validierung und Loading-State ✅
- Auth-Gate in `main.dart` mit Auto-Login (Token-Refresh) ✅
- Logout im Settings-Screen mit Bestätigungs-Dialog ✅
- PocketBase API-Regeln auf Auth umgestellt ✅

### H-002: CORS-Konfiguration — Erledigt in v0.7.4+0
- `CORS_ALLOWED_ORIGINS` Umgebungsvariable wird beim PocketBase-Start als
  `--origins` Flag übergeben ✅
- Neues `entrypoint.sh` Script ersetzt inline CMD im Dockerfile ✅
- Wildcard (`*`) als Default für Entwicklung, strikt für Produktion ✅
- Portainer Stack an Produktion angeglichen ✅
- Dokumentation in DEPLOYMENT.md ✅

### O-004: UI-Hardcoded Werte migrieren — Erledigt in v0.7.4+7 ✅
- ~560 von ~600 Hardcodes migriert (~93%)
- ~41 bewusst beibehalten (dokumentiert in THEMING.md)
- 28 neue AppConfig-Tokens über 5 Batches
- Dark Mode funktioniert jetzt korrekt in allen Widgets
- Alle `withOpacity` → `withValues` migriert

**Batch 1 — Erledigt ✅** (v0.7.4+3)
- `app_config.dart` — 13 neue Tokens (Icon-Sizes, Stroke, Opacity, Layout)
- `sync_progress_widgets.dart` — 55 Hardcodes → 0
- `settings_screen.dart` — 54 Hardcodes → 0
- Neuer `_buildStatusContainer()` Helper in Settings (DRY-Refactoring)

**Batch 2 — Erledigt ✅** (v0.7.4+4)
- `app_config.dart` — 2 neue Tokens (infoLabelWidthSmall, buttonPaddingVertical)
- `app_theme.dart` — 10 Hardcodes → 0 (Component-Themes nutzen AppConfig)
- `conflict_resolution_screen.dart` — 82 Hardcodes → 0
- `sync_error_widgets.dart` — 59 Hardcodes → 0
- `sync_management_screen.dart` — 43 Hardcodes → 0

**Batch 3 — Erledigt ✅** (v0.7.4+5)
- Keine neuen AppConfig-Tokens nötig
- `artikel_detail_screen.dart` — 36 Hardcodes → 0
- `artikel_list_screen.dart` — 31 Hardcodes → 0
- `sync_conflict_handler.dart` — 31 Hardcodes → 0

**Batch 4 — Erledigt ✅** (v0.7.4+6)
- `app_config.dart` — 13 neue Tokens (Icon-Sizes XL/XXL, Login/Setup-Layout,
  Attachment-Thumbnails, Button-Height, Progress-Small)
- `attachment_upload_widget.dart` — 28 Hardcodes → 0
- `attachment_list_widget.dart` — 23 Hardcodes → 0
- `server_setup_screen.dart` — 23 Hardcodes → 0
- `login_screen.dart` — 18 Hardcodes → 0

**Batch 5 — Erledigt ✅** (v0.7.4+7)
- Keine neuen AppConfig-Tokens nötig
- `list_screen_mobile_actions.dart` — 17 Hardcodes → 0
- `nextcloud_settings_screen.dart` — 21 Hardcodes → 0
- `qr_scan_screen_mobile_scanner.dart` — 12 → 6 (Kamera-Overlay bewusst)
- `image_crop_dialog.dart` — 11 → 5 (Crop-Library bewusst)
- `artikel_erfassen_screen.dart` — 12 Hardcodes → 0
- `list_screen_web_actions.dart` — 8 Hardcodes → 0
- `artikel_bild_widget.dart` — 5 → 2 (Platzhalter-Icons bewusst)
- `nextcloud_resync_dialog.dart` — 7 Hardcodes → 0
- Bewusst übersprungen: `detail_screen_io.dart`, `list_screen_io.dart`,
  `list_screen_mobile_actions_stub.dart` (kein BuildContext),
  `_dokumente_button.dart` (deprecated)

### M-007: UI für Konfliktlösung — Erledigt in v0.7.5+0
- `ConflictResolutionScreen` mit Side-by-Side-Vergleich ✅
- `ConflictData` + `ConflictResolution` Enum ✅
- Multi-Konflikt-Navigation mit Fortschrittsanzeige ✅
- Merge-Dialog für manuelle Zusammenführung ✅
- Integration mit `SyncConflictHandler` und `SyncService` ✅
- Entscheidungs-Callbacks (`useLocal`, `useRemote`, `merge`, `skip`) ✅
- Unit-Tests erstellt (T-001) ✅

---

## 🔴 Priorität: Hoch

*Aktuell keine offenen Aufgaben mit hoher Priorität.*

---

## 🟡 Priorität: Mittel

### O-002: Unit-Tests für Core-Utilities
**Zu testende Komponenten:**
- `uuid_generator.dart`: Eindeutigkeit
- `image_processing_utils.dart`: Kompression
- `artikel_model.dart`: `fromMap` / `toMap` mit Null-Werten

### M-003: Error Handling
Einheitliche Fehlerbehandlung (Result-Type oder Exception-Klassen).

### M-004: Loading States
Konsistente Lade-Indikatoren in allen Screens.

### M-005: Pagination
`ListView.builder` mit Lazy-Loading und PocketBase-Pagination.

### M-006: Input Validation
Pflichtfelder, Bereichsprüfungen, Duplikat-Checks.

### M-008: Backup-Status in der App anzeigen
`last_backup.json` im Settings-Screen anzeigen.

### T-001: Tests für Konfliktlösung (M-007)
Manuelle Integrationstests und Unit-Tests für die gesamte Konflikt-Pipeline.

**Unit-Tests:**
- [ ] **T-001.1** — `ConflictData`: Konstruktor, Felder, Null-Handling
- [ ] **T-001.2** — `ConflictResolution` Enum: Alle Werte, `byName`, Index
- [ ] **T-001.3** — `SyncService.detectConflicts()`: Mock-Daten, ETag-Abweichung erkennen
- [ ] **T-001.4** — `SyncService._determineConflictReason()`: Alle Zeitstempel-Szenarien
- [ ] **T-001.5** — `ConflictResolutionScreen`: Widget-Test (erfordert SyncService-Mock)

**Manuelle Integrationstests:**
- [ ] **T-001.6** — Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint
- [ ] **T-001.7** — „Lokal behalten" → Server wird überschrieben
- [ ] **T-001.8** — „Server übernehmen" → Lokale Daten werden ersetzt
- [ ] **T-001.9** — „Zusammenführen" → Merge-Dialog, Felder manuell wählen, Ergebnis korrekt
- [ ] **T-001.10** — „Überspringen" → Konflikt bleibt, erscheint beim nächsten Sync erneut
- [ ] **T-001.11** — Mehrere Konflikte gleichzeitig → Navigation Weiter/Zurück, Fortschrittsanzeige
- [ ] **T-001.12** — Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt

---

## 🟢 Priorität: Nice-to-Have

### N-003: App Icon
Eigenes App-Icon statt Flutter-Default.

### N-005: Splash Screen
Eigener Splash-Screen mit App-Logo.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

### H-001 (alt): iOS/macOS Vorbereitung
Erfordert Apple Developer Account.

---

## 📊 Fortschritts-Übersicht

| Priorität | Gesamt | Erledigt | Offen |
|---|---|---|---|
| ✅ Abgeschlossen | 17 | 17 | 0 |
| 🔴 Hoch | 0 | 0 | 0 |
| 🟡 Mittel | 7 | 0 | 7 |
| 🟢 Nice-to-Have | 4 | 0 | 4 |
| **Gesamt** | **28** | **17** | **11** |

---

## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-04-02 | v0.7.5+0 | M-007 als erledigt markiert, K-003 umbenannt (ex M-007 alt), T-001 erstellt, Unit-Tests hinzugefügt |
| 2026-04-02 | v0.7.4+7 | O-004 Batch 5 erledigt + O-004 abgeschlossen: Restliche 11 Dateien migriert (~80 Hardcodes), ~41 bewusst beibehalten |
| 2026-04-02 | v0.7.4+6 | O-004 Batch 4 erledigt: Attachment-Widgets + Setup/Login migriert, 13 neue AppConfig-Tokens |
| 2026-04-02 | v0.7.4+5 | O-004 Batch 3 erledigt: Artikel-Cluster migriert (3 Dateien, 98 Hardcodes), keine neuen Tokens |
| 2026-04-01 | v0.7.4+4 | O-004 Batch 2 erledigt: app_theme + 3 Sync-Dateien migriert, 2 neue AppConfig-Tokens |
| 2026-04-01 | v0.7.4+3 | O-004 Batch 1 erledigt: sync_progress_widgets + settings_screen migriert, 13 neue AppConfig-Tokens |
| 2026-03-30 | v0.7.4+0 | H-002 (CORS) abgeschlossen, Traefik-Compose entfernt, Portainer Stack angeglichen |
| 2026-03-29 | v0.7.2 | M-012 (Attachments) abgeschlossen, M-009 (Login) hinzugefügt |
| 2026-03-27 | v0.7.1 | H-003 (Backup) abgeschlossen, M-008 hinzugefügt |
| 2026-03-27 | v0.7.0 | K-004 (Runtime-URL) abgeschlossen |
| 2026-03-25 | — | Dokumentation modularisiert |
| 2026-03-24 | — | Produktions-Hardening und Indizierung |
| 2026-03-23 | — | Design-Tokens und Themes |

---

[Zurück zur README](../README.md) | [Zum Changelog](../CHANGELOG.md)