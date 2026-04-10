# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Übersicht über den Projektfortschritt,
offene Aufgaben und technische Optimierungen der **Lager_app**.

**Version:** 0.8.0 | **Zuletzt aktualisiert:** 10.04.2026

---

## 📊 Gesamtfortschritt

| Phase | Fortschritt | Status |
|---|---|---|
| Phase 1: Grundlagen | 100% | ✅ |
| Phase 2: Deployment & Security | 100% | ✅ |
| Phase 3: Performance & Optimierung | 100% | ✅ |
| Phase 4: Multi-Plattform & Politur | 52% | 🔴 |

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

### M-008: Backup-Status in der App anzeigen — Erledigt in v0.7.5+1
- `BackupStatusService` liest `last_backup.json` via HTTP ✅
- `BackupStatusWidget` mit Farbcodierung (Grün/Gelb/Rot) ✅
- Integration im Settings-Screen ✅
- `backup.sh` kopiert Status-JSON nach `pb_public` ✅
- `docker-compose.prod.yml` Volume für Backup-Container ergänzt ✅

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


### M-006: Input Validation — Erledigt in v0.7.6+1
- Pflichtfelder: Name, Ort, Fach mit Inline-Fehlermeldungen ✅
- Name: Mindestlänge 2 Zeichen, max. 100 Zeichen ✅
- Menge: Nur positive Ganzzahlen (≥ 0), max. 999.999, via `FilteringTextInputFormatter` ✅
- Artikelnummer: Automatisch vorgegeben (≥ 1000), manuell änderbar ✅
- Duplikat-Check: Name + Ort + Fach (Kombination), lokal + PocketBase ✅
- Duplikat-Check: Artikelnummer, lokal + PocketBase ✅
- 5 neue `AppConfig`-Tokens für Validierungsgrenzen ✅
- Neue DB-Methoden: `existsKombination()`, `existsArtikelnummer()` ✅

### M-004: Loading States — Erledigt in v0.7.6+2
- Zentrales `AppLoadingOverlay`-Widget mit optionalem Text ✅
- `AppLoadingIndicator` für Inline-Bereiche ✅
- `AppLoadingButton` ersetzt alle manuellen Spinner-in-Button Konstrukte ✅
- `ArtikelSkeletonTile` + `ArtikelSkeletonList` mit Shimmer-Animation ✅
- `artikel_list_screen.dart`: Skeleton statt `CircularProgressIndicator` ✅
- `artikel_detail_screen.dart`: Overlay beim Speichern und Löschen ✅
- `sync_management_screen.dart`: Overlay während aktivem Sync ✅
- 10 neue `AppConfig`-Tokens für Skeleton und Overlay ✅

### M-003: Error Handling — Erledigt in v0.7.6+3
- Neue `AppException`-Hierarchie (`sealed class`):
`NetworkException`, `ServerException`, `AuthException`,
`SyncException`, `StorageException`, `ValidationException`,
`UnknownException` (konkreter Fallback) ✅
- Neuer `AppErrorHandler` mit:
  · `classify()` — übersetzt rohe Exceptions automatisch ✅
  · `log()` — level-bewusstes Logging (warning vs. error) ✅
  · `showSnackBar()` — einfacher Fehler-SnackBar ✅
  · `showSnackBarWithDetails()` — SnackBar + Details-Dialog-Button ✅
  · `showErrorDialog()` — modaler Fehler-Dialog ✅
  · `_getSuggestions()` — kontextabhängige Lösungsvorschläge ✅
- `sync_conflict_handler.dart`: rohe `$e`-Strings → `AppErrorHandler` ✅
- `SocketException` / `HandshakeException` / `TimeoutException` /
`ClientException` werden automatisch klassifiziert ✅
- Lint-Fixes: `instantiate_abstract_class, unnecessary_null_comparison
(×2), unreachable_switch_case` behoben ✅

### O-002: Unit-Tests für ArtikelDbService — Erledigt in v0.7.6+4
- 75 Tests, alle grün ✅
- `sqflite_common_ffi mit inMemoryDatabasePath` — kein Dateisystem ✅
- `injectDatabase() (@visibleForTesting`) für saubere Test-Isolation ✅
- `ArtikelDbServiceTestHelper` — wiederverwendbarer In-Memory-Setup ✅
- Abgedeckte Methoden: `insertArtikel, getAlleArtikel, updateArtikel,
deleteArtikel, getArtikelByUUID, getArtikelByRemotePath,
getPendingChanges, markSynced, upsertArtikel, searchArtikel,
existsKombination, existsArtikelnummer, setLastSyncTime,
getLastSyncTime, isDatabaseEmpty, getMaxArtikelnummer,
deleteAlleArtikel, insertArtikelList, updateBildPfad,
updateRemoteBildPfad, setBildPfadByUuid, setThumbnailPfadByUuid,
setThumbnailEtagByUuid, setRemoteBildPfadByUuid,
getUnsyncedArtikel` ✅
- Produktionsbug gefunden und gefixt: `getUnsyncedArtikel()` nutzte
`""` statt `''` für SQL-Leerstring-Literale — auf Mobile nicht
sichtbar, aber von `sqflite_common_ffi` korrekt abgelehnt ✅

### M-007: UI für Konfliktlösung — Erledigt in v0.7.5+0
- `ConflictResolutionScreen` mit Side-by-Side-Vergleich ✅
- `ConflictData` + `ConflictResolution` Enum ✅
- Multi-Konflikt-Navigation mit Fortschrittsanzeige ✅
- Merge-Dialog für manuelle Zusammenführung ✅
- Integration mit `SyncConflictHandler` und `SyncService` ✅
- Entscheidungs-Callbacks (`useLocal`, `useRemote`, `merge`, `skip`) ✅
- Unit- und Widget-Tests erstellt (T-001, 77 Tests) ✅

### P-001: Kamera-Vorschau-Delay auf Android — Erledigt in v0.7.7+2
- Crop-Dialog aus `pickImageCamera()` entfernt → sofortige Vorschau ✅
- `maxWidth`/`maxHeight`/`imageQuality` aus AppConfig übergeben (800px, Q85) ✅
- Hardcodierte 1600px-Dimensionen entfernt ✅
- `openCropDialog()` als public static Methode für On-Demand-Nutzung ✅
- Optionaler „Zuschneiden"-Button in `ArtikelErfassenScreen` ✅

### M-005: Pagination — Erledigt in v0.7.7+4
- `ScrollController` mit `_onScroll()`-Listener ✅
- `_ladeArtikel()`: Reset + erste Seite (offset = 0) ✅
- `_ladeNaechsteSeite()`: Offset-Pagination, Guard gegen Doppel-Requests ✅
- Lade-Footer (`CircularProgressIndicator`) am Listenende ✅
- Web: `_hasMore = false` — `getFullList()` unverändert ✅
- 2 neue AppConfig-Tokens: `paginationPageSize`, `paginationScrollThreshold` ✅

### O-005: Deprecated Code entfernt — Erledigt in v0.7.7+4
- `_dokumente_button.dart` gelöscht ✅
- `_dokumente_button_stub.dart` gelöscht ✅
- `dokumente_utils.dart` gelöscht ✅
- Zugehörige Testdateien gelöscht ✅
- `flutter analyze`: 0 Issues ✅

### P-002: Suche Debounce — Erledigt in v0.7.7+5
- `Timer`-basierter Debounce (300ms) ✅
- Mobile: `_db.searchArtikel()` (SQL LIKE) ✅
- Web: clientseitiger Filter über geladene Liste ✅
- Skeleton während DB-Suche ✅
- Pagination-Footer bei aktiver Suche ausgeblendet ✅
- 2 neue AppConfig-Tokens: `searchDebounceDuration`, `searchResultLimit` ✅

### O-006: Widget-Tests ArtikelErfassenScreen — Erledigt in v0.7.7+5
- 11 Tests, alle grün ✅
- Render, Validierung, Abbrechen-Pfade abgedeckt ✅
- `tester.view.physicalSize` + `scrollUntilVisible()` für ListView ✅

### K-006: Kaltstart-Bug Fix — Erledigt in v0.8.0
- Sync-UI-Kopplung über `SyncStatusProvider`-Interface ✅
- Automatischer Bild-Download nach Record-Sync (`downloadMissingImages()`) ✅
- PocketBase-Bild-Fallback in `_LocalThumbnail` und `ArtikelDetailBild` ✅
- Setup-Flow wartet auf initialen Sync vor UI-Wechsel ✅
- Lade-Overlay im Setup-Screen während Sync ✅
- Gezieltes Image-Cache-Evict statt globalem `imageCache.clear()` ✅
- Neue DB-Methode `setBildPfadByUuidSilent()` (kein Sync-Trigger) ✅
- Conditional Import für plattformübergreifendes Cache-Evict ✅
- `FakeSyncStatusProvider` Test-Double + Unit-Tests ✅

---

## 🔴 Priorität: Hoch

*Aktuell keine offenen Aufgaben mit hoher Priorität.*

---

## 🟡 Priorität: Mittel

### T-001: Tests für Konfliktlösung (M-007)
Manuelle Integrationstests für die gesamte Konflikt-Pipeline.

**Unit- und Widget-Tests — Abgeschlossen ✅ (77 Tests)**
- [x] **T-001.1** — `ConflictData`: Konstruktor, Felder, Null-Handling (11 Tests)
- [x] **T-001.2** — `ConflictResolution` Enum: Alle Werte, `byName`, Index (6 Tests)
- [x] **T-001.3** — `SyncService.detectConflicts()`: Mock-Daten, ETag-Abweichung erkennen (9 Tests)
- [x] **T-001.4** — `SyncService._determineConflictReason()`: Alle Zeitstempel-Szenarien (15 Tests)
- [x] **T-001.5** — `ConflictResolutionScreen`: Widget-Tests mit SyncService-Mock (20 Tests)

**Manuelle Integrationstests:**
- [ ] **T-001.6** — Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint
- [ ] **T-001.7** — „Lokal behalten" → Server wird überschrieben
- [ ] **T-001.8** — „Server übernehmen" → Lokale Daten werden ersetzt
- [ ] **T-001.9** — „Zusammenführen" → Merge-Dialog, Felder manuell wählen, Ergebnis korrekt
- [ ] **T-001.10** — „Überspringen" → Konflikt bleibt, erscheint beim nächsten Sync erneut
- [ ] **T-001.11** — Mehrere Konflikte gleichzeitig → Navigation Weiter/Zurück, Fortschrittsanzeige
- [ ] **T-001.12** — Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt

### T-002: Unit-Tests SyncService
Mock-basierte Tests für die Kern-Sync-Logik.
- [ ] `syncAll()` — Haupt-Einstiegspunkt
- [ ] `uploadPendingChanges()` — ETag/If-Match Handling
- [ ] `downloadNewItems()` — Remote-Artikel lokal einfügen
- [ ] `applyConflictResolution()` — useLocal/useRemote/merge/skip
- [ ] `deleteRemoteItem()` — Soft-Delete Sync

### T-003: Unit-Tests NextcloudClient
- [ ] `_parsePropfindResponse()` — XML-Fixtures direkt testen
- [ ] `_parseHttpDate()` — RFC-7231-Datumsformate, Edge Cases
- [ ] `uploadItem()` mit `If-Match` — Mock `http.Client`

### T-004: Widget-Tests Merge-Dialog
- [ ] Felder einzeln auswählen (lokal/remote pro Feld)
- [ ] Merge-Ergebnis korrekt an `applyConflictResolution()` übergeben
- [ ] Validierung: kein leerer Name möglich

### T-005: Unit-Tests AttachmentService
- [ ] Upload, Download, Delete gegen PocketBase-Mock
- [ ] MIME-Type-Validierung
- [ ] Max-Anhänge / Max-Dateigröße Grenzen

### T-006: Unit-Tests BackupStatusService
- [ ] HTTP-Mock für `last_backup.json`
- [ ] Farblogik: Grün/Gelb/Rot Schwellwerte
- [ ] Fehlerfall: Server nicht erreichbar


### O-006: Tests für pickImageCamera() nach P-001
P-001 hat die Logik in `ImagePickerService` geändert — Tests fehlen.
- [ ] `pickImageCamera()` mit Mock-Picker
- [ ] `openCropDialog()` public API testen
- [ ] `ensureTargetFormat(crop: false)` Pfad abdecken


### P-003: Bild-Caching
Remote-Bilder werden bei jedem Scroll neu geladen.
- [ ] `cached_network_image` Paket einbinden
- [ ] `ArtikelBildWidget` auf `CachedNetworkImage` umstellen
- [ ] Cache-Invalidierung bei ETag-Änderung

---

## 🟢 Priorität: Nice-to-Have

### N-003: App Icon
Eigenes App-Icon statt Flutter-Default.

### N-005: Splash Screen
Eigener Splash-Screen mit App-Logo.

### N-006: Nextcloud-Workflow
WebDAV-Anbindung finalisieren und mit Nextcloud 28+ testen.

---

## ⏭️ Future (nicht in Planung)

### H-001: iOS/macOS Vorbereitung
Erfordert Apple Developer Account. Zurückgestellt bis Account verfügbar.

---

## 📊 Fortschritts-Übersicht

| Priorität | Gesamt | Erledigt | Offen |
|---|---|---|---|
| ✅ Abgeschlossen | 27 | 27 | 0 |
| 🔴 Hoch | 0 | 0 | 0 |
| 🟡 Mittel | 6 | 0 | 6 |
| 🟢 Nice-to-Have | 3 | 0 | 3 |
| ⏭️ Future | 1 | 0 | 1 |
| **Gesamt** | **36** | **27** | **10** |

---

## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-04-10 | v0.8.0 | K-006 abgeschlossen: Kaltstart-Bug Fix — Sync-UI-Kopplung, Bild-Download, PB-Fallback, Setup-Flow |
| 2026-04-08 | v0.7.7+5 | O-006 abgeschlossen: 11 Widget-Tests ArtikelErfassenScreen, alle grün |
| 2026-04-08 | v0.7.7+5 | P-002 abgeschlossen: Debounce 300ms, DB-Suche Mobile, clientseitig Web |
| 2026-04-08 | v0.7.7+4 | O-005 abgeschlossen: 5 deprecated Dateien + Teststubs entfernt, 0 analyze-Issues |
| 2026-04-07 | v0.7.7+4 | M-005 abgeschlossen: Offset-Pagination, ScrollController, Lade-Footer |
| 2026-04-07 | v0.7.7+3 | H-001 nach Future verschoben, T-002–T-006, O-005–O-006, P-002–P-003 neu erfasst |
| 2026-04-07 | v0.7.7+2 | P-001 abgeschlossen: Kamera-Delay auf Android behoben, optionaler Crop-Button |
| 2026-04-06 | v0.7.7+1 | T-001 Unit- und Widget-Tests abgeschlossen (77 Tests), TESTING.md aktualisiert (298 Tests gesamt) |
| 2026-04-05 | v0.7.7 | Release v0.7.7: Dokumentation aktualisiert, TESTING.md erstellt, Version hochgezogen |
| 2026-04-05 | v0.7.6+4 | O-002 abgeschlossen: ArtikelDbService (75 Tests), ArtikelModel (64), ImageProcessingUtils (30), UuidGenerator (23) — 128 neue Tests gesamt |
| 2026-04-05 | v0.7.6+3 | M-003 Zentrales Error Handling abgeschlossen |
| 2026-04-05 | v0.7.6+2 | M-004 (Loading States) abgeschlossen |
| 2026-04-05 | v0.7.6+1 | M-006 (Input Validation) abgeschlossen |
| 2026-04-03 | v0.7.5+1 | M-008 als erledigt markiert |
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