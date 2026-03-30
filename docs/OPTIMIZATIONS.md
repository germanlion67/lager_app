# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Übersicht über den Projektfortschritt,
offene Aufgaben und technische Optimierungen der **Lager_app**.

**Version:** 0.7.3 | **Zuletzt aktualisiert:** 30.03.2026

---

## 📊 Gesamtfortschritt

| Phase | Fortschritt | Status |
|---|---|---|
| Phase 1: Grundlagen | 100% | ✅ |
| Phase 2: Deployment & Security | 100% | ✅ |
| Phase 3: Performance & Optimierung | 90% | 🟡 |
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

---

## 🔴 Priorität: Hoch

### H-002: CORS-Konfiguration
PocketBase CORS muss für Produktion auf die tatsächliche Domain eingeschränkt werden.

**Aufgaben:**
- PocketBase-Settings: `Access-Control-Allow-Origin` auf `https://lager.deine-domain.de`
- Testen, ob Web-Frontend und Mobile-App weiterhin funktionieren
- Dokumentation in `DEPLOYMENT.md` ergänzen

### M-007: UI für Konfliktlösung
Der Sync-Prozess erkennt Konflikte, aber die UI zur Auswahl zwischen
**„Lokal behalten"** oder **„Server übernehmen"** ist noch nicht finalisiert.

**Aufgaben:**
- `conflict_resolution_screen.dart` fertigstellen
- Vergleichs-Widget *(Vorher/Nachher)* für Artikeldaten implementieren

--- 

### M-009 Login-Flow & Authentifizierung ✅

**Status:** Erledigt
**Datum:** 2026-03-30

**Umgesetzt:**
- Login-Screen mit E-Mail/Passwort-Validierung und Loading-State
- Auth-Gate in `main.dart` mit Auto-Login (Token-Refresh)
- Logout im Settings-Screen mit Bestätigungs-Dialog
- PocketBase API-Regeln auf Auth umgestellt (Migration + Rollback)
- Passwort-Reset-Funktion (optional, über Dialog im Login-Screen)

**Dateien:**
| Datei | Änderung |
|---|---|
| `lib/screens/login_screen.dart` | NEU — Login-UI |
| `lib/main.dart` | Auth-Gate, Auto-Login, Sync erst nach Login |
| `lib/screens/settings_screen.dart` | Account-Card, Logout-Button |
| `lib/services/pocketbase_service.dart` | `refreshAuthToken()`, `requestPasswordReset()`, `currentUserEmail` |
| `server/pb_migrations/1700000000_set_auth_rules.js` | NEU — Auth-Regeln für artikel + attachments |

**Architektur-Entscheidungen:**
- Kein separater Auth-Service — PocketBaseService Singleton beibehalten
- Kein Provider/Bloc — konsistent mit bestehendem Pattern
- Token-Persistierung durch PocketBase authStore (automatisch)
- Nur E-Mail + Passwort (kein OAuth/Social Login) — KISS-Prinzip
- Selbst-Registrierung deaktiviert — User werden über PocketBase Admin erstellt

--- 

## 🟡 Priorität: Mittel

### O-004: UI-Hardcoded Werte migrieren
Ca. 140 Stellen mit hardcodierten Farben, Abständen oder Radien.

**Fokus-Bereiche:**
- `sync_progress_widgets.dart`
- `artikel_list_item_widget.dart`
- `settings_screen.dart`

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
| ✅ Abgeschlossen | 11 | 11 | 0 |
| 🔴 Hoch | 3 | 0 | 3 |
| 🟡 Mittel | 7 | 0 | 7 |
| 🟢 Nice-to-Have | 4 | 0 | 4 |
| **Gesamt** | **25** | **11** | **14** |

---

## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-03-29 | v0.7.2 | M-012 (Attachments) abgeschlossen, M-009 (Login) hinzugefügt |
| 2026-03-27 | v0.7.1 | H-003 (Backup) abgeschlossen, M-008 hinzugefügt |
| 2026-03-27 | v0.7.0 | K-004 (Runtime-URL) abgeschlossen |
| 2026-03-25 | — | Dokumentation modularisiert |
| 2026-03-24 | — | Produktions-Hardening und Indizierung |
| 2026-03-23 | — | Design-Tokens und Themes |

---

[Zurück zur README](../README.md) | [Zum Changelog](../CHANGELOG.md)
