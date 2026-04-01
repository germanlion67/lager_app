# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Übersicht über den Projektfortschritt,
offene Aufgaben und technische Optimierungen der **Lager_app**.

**Version:** 0.7.4+4 | **Zuletzt aktualisiert:** 01.04.2026

---

## 📊 Gesamtfortschritt

| Phase | Fortschritt | Status |
|---|---|---|
| Phase 1: Grundlagen | 100% | ✅ |
| Phase 2: Deployment & Security | 100% | ✅ |
| Phase 3: Performance & Optimierung | 94% | 🟡 |
| Phase 4: Multi-Plattform & Politur | 40% | 🔴 |

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

### M-007 (alt): Artikelnummer & Indizes — Erledigt in v0.3.0
- Eindeutige Artikelnummer (1000+) ✅
- 5 Performance-Indizes ✅
- Artikelnummer in Listen- und Detailansicht ✅ (v0.7.2)

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

### H-002: CORS-Konfiguration — Erledigt in v0.7.4+0
- `CORS_ALLOWED_ORIGINS` Umgebungsvariable wird beim PocketBase-Start als
  `--origins` Flag übergeben ✅
- Neues `entrypoint.sh` Script ersetzt inline CMD im Dockerfile ✅
- Wildcard (`*`) als Default für Entwicklung, strikt für Produktion ✅
- Portainer Stack an Produktion angeglichen ✅
- Dokumentation in DEPLOYMENT.md ✅

### M-009: Login-Flow & Authentifizierung — Erledigt in v0.7.3
- Login-Screen mit E-Mail/Passwort-Validierung und Loading-State ✅
- Auth-Gate in `main.dart` mit Auto-Login (Token-Refresh) ✅
- Logout im Settings-Screen mit Bestätigungs-Dialog ✅
- PocketBase API-Regeln auf Auth umgestellt ✅

---

## 🔴 Priorität: Hoch

### M-007: UI für Konfliktlösung
Der Sync-Prozess erkennt Konflikte, aber die UI zur Auswahl zwischen
**„Lokal behalten"** oder **„Server übernehmen"** ist noch nicht finalisiert.

**Aufgaben:**
- `conflict_resolution_screen.dart` fertigstellen
- Vergleichs-Widget *(Vorher/Nachher)* für Artikeldaten implementieren

---

## 🟡 Priorität: Mittel

### O-004: UI-Hardcoded Werte migrieren

**Status:** 🟡 In Arbeit (Batch 1+2 erledigt, ~51% migriert)
**Datum:** 2026-04-01

Ursprünglich ca. 591 Stellen mit hardcodierten Farben, Abständen, Radien
oder Font-Sizes in `screens/` und `widgets/`.

**Batch 1 — Erledigt ✅** (v0.7.4+3)
- `app_config.dart` — 13 neue Tokens (Icon-Sizes, Stroke, Opacity, Layout)
- `sync_progress_widgets.dart` — 55 Hardcodes → 0
- `settings_screen.dart` — 54 Hardcodes → 0
- `artikel_list_item_widget.dart` — existiert nicht, übersprungen
- Neuer `_buildStatusContainer()` Helper in Settings (DRY-Refactoring)

**Batch 2 — Erledigt ✅** (v0.7.4+4)
- `app_config.dart` — 2 neue Tokens (infoLabelWidthSmall, buttonPaddingVertical)
- `app_theme.dart` — 10 Hardcodes → 0 (Component-Themes nutzen AppConfig)
- `conflict_resolution_screen.dart` — 82 Hardcodes → 0
- `sync_error_widgets.dart` — 59 Hardcodes → 0
- `sync_management_screen.dart` — 43 Hardcodes → 0
- AppBars nutzen jetzt Standard-Theme statt manueller Farbüberschreibung

**Batch 3 — Offen 🟡** (Artikel-Cluster, ~98 Hardcodes)
- `artikel_detail_screen.dart` (36)
- `artikel_list_screen.dart` (31)
- `sync_conflict_handler.dart` (31)

**Batch 4 — Offen 🟡** (Attachment & Setup, ~92 Hardcodes)
- `attachment_upload_widget.dart` (28)
- `attachment_list_widget.dart` (23)
- `server_setup_screen.dart` (23)
- `login_screen.dart` (18)

**Batch 5 — Offen 🟢** (Cleanup, ~108 Hardcodes)
- `_dokumente_button.dart` (18)
- `list_screen_mobile_actions.dart` (17)
- `nextcloud_settings_screen.dart` (21)
- `qr_scan_screen_mobile_scanner.dart` (12)
- `image_crop_dialog.dart` (11)
- Restliche Dateien mit ≤7 Hardcodes

**Kumulierter Fortschritt:**
| Batch | Hardcodes | Status |
|---|---|---|
| Batch 1 | 109 | ✅ Erledigt |
| Batch 2 | 193 | ✅ Erledigt |
| Batch 3 | ~98 | 🟡 Offen |
| Batch 4 | ~92 | 🟡 Offen |
| Batch 5 | ~108 | 🟢 Offen |
| **Gesamt** | **~600** | **302 erledigt (~51%)** |

**Regeln (für alle Batches):**
- Farben: `Colors.*` / `Color(0x...)` → `Theme.of(context).colorScheme.*`
- Spacing: `EdgeInsets.*(N)` / `SizedBox(height: N)` → `AppConfig.spacing*`
- Radien: `BorderRadius.circular(N)` → `AppConfig.borderRadius*` / `cardBorderRadius*`
- Font-Sizes: `fontSize: N` → `AppConfig.fontSize*` oder `textTheme.*`
- Keine neuen `AppTheme`-Farben (z.B. `greyLight100`) in UI-Code verwenden
  → stattdessen `colorScheme.surfaceContainerLow` etc.

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
| ✅ Abgeschlossen | 15 | 15 | 0 |
| 🔴 Hoch | 1 | 0 | 1 |
| 🟡 Mittel | 7 | 0 | 7 |
| 🟢 Nice-to-Have | 4 | 0 | 4 |
| **Gesamt** | **27** | **15** | **12** |

---

## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
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