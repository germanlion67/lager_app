# 🛠️ Projekt-Status, Roadmap & Technische Optimierungen

Dieses Dokument ist die zentrale Übersicht über den Projektfortschritt,
offene Aufgaben und technische Optimierungen der **Lager_app**.

**Version:** 0.8.1+12 | **Zuletzt aktualisiert:** 13.04.2026

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

### T-002: Unit-Tests PocketBase SyncService — Erledigt in v0.8.0+5 ✅
- 17 Tests, alle grün ✅
- Manuelle Fakes statt `@GenerateMocks` (Singleton-Kompatibilität) ✅
- `TestableSyncService` repliziert Sync-Logik mit injizierbaren Fakes ✅
- `FakeRecordService` mit exakten PocketBase SDK v0.23.2 Signaturen ✅
- `RecordModel.fromJson()` statt Konstruktor für `id`/`created`/`updated` ✅
- Push-Tests: Create, Update, Delete, Fehlerbehandlung, Auth/Owner ✅
- Pull-Tests: Insert, Lösch-Sync, leere UUIDs ✅
- syncOnce()-Tests: Reihenfolge, Fehler-Abfang, Nur-Pull ✅
- UUID-Sanitization (Finding 5): Anführungszeichen entfernt ✅
- Image-Download: Skip-Logik für fehlende Felder/URL ✅
- Kein `build_runner` nötig — keine Code-Generierung ✅

### T-005: Unit-Tests AttachmentService — Erledigt in v0.8.1+10 ✅
- 34 Tests, alle grün ✅
- `PocketBaseService.overrideForTesting()` injiziert Fake-Client in echten
  `AttachmentService`-Singleton — testet echten Code statt Kopie ✅
- `FakeAttachmentRecordService` mit erweiterten Parametern (`perPage`, `page`, `sort`) ✅
- `fakeClientException()` Helper für PocketBase SDK v0.23.2 (`originalError:` statt `message:`) ✅
- `getForArtikel()`: Leere Liste, 3 Ergebnisse, Filter, perPage, PB-Fehler, fehlende Felder ✅
- `countForArtikel()`: 0, korrekte Anzahl, PB-Fehler, effiziente Query ✅
- `upload()`: Happy-Path, Body-Felder, Limit=20/Limit>20, PB-Fehler, null-Felder, MultipartFile ✅
- `updateMetadata()`: Erfolg, Trimming, null→leerer String, PB-Fehler ✅
- `delete()`: Erfolg, korrekte ID, PB-Fehler, Netzwerkfehler ✅
- `deleteAllForArtikel()`: Alle löschen, leer, teilweise Fehler, getForArtikel-Fehler ✅
- Integration: Upload→Get-Roundtrip, Grenzwert 19 vs 20 ✅
- Kein `build_runner`, kein Netzwerk, kein Dateisystem ✅
- Gesamt: 499 → 533 Tests

### T-004: Widget-Tests Merge-Dialog — Erledigt in v0.8.1+10 ✅
- 18 Tests, alle grün ✅
- `_MergeDialog` über "Manuell zusammenführen"-Button getestet (private Klasse) ✅
- `MockSyncService` wiederverwendet aus T-001.5 ✅
- Grundstruktur: Titel, Icons, Buttons, Labels (6 Tests) ✅
- Konflikt-Anzeige: Lokal/Remote-Karten, Warning-Icons, Initialwerte (4 Tests) ✅
- Feld-Auswahl: Lokal/Remote-Buttons, manuelle Eingabe (3 Tests) ✅
- Bild-Auswahl: Radio-Optionen, "Kein Bild", initiale Selektion (3 Tests) ✅
- Zusammenführen: Dialog schließt, korrekte Werte, Fallbacks (4 Tests) ✅
- Dialog schließen: Abbrechen, Close-Icon (2 Tests) ✅
- Menge-Feld: Ungültige Eingabe Fallback, Remote-Übernahme (2 Tests) ✅
- Gesamt: 533 → 551 Tests

### T-003: Unit-Tests NextcloudClient — Erledigt in v0.8.1+12 ✅
- 39 Tests, alle grün ✅
- `MockClient` aus `package:http/testing.dart` — kein Netzwerk nötig ✅
- Optionaler `http.Client? client`-Parameter im Konstruktor (rückwärtskompatibel) ✅
- Alle 8 HTTP-Stellen auf injizierten `_client` umgestellt ✅
- `RemoteItemMeta`: equality (path+etag), copyWith, toString (3 Tests) ✅
- `testConnection()`: 200, 404, 500, Exception, Auth-Header (5 Tests) ✅
- `createFolder()`: 201, 405, 500, Exception (4 Tests) ✅
- `listItemsEtags()`: 1 Item, Multi-Item, leer, 403, Non-JSON-Filter, kein ETag, custom Path (7 Tests) ✅
- `downloadItem()`: 200, 404, Netzwerkfehler (3 Tests) ✅
- `uploadItem()`: 201+ETag, If-Match, 412 Conflict, 500, kein ETag (5 Tests) ✅
- `deleteItem()`: 204, 404 idempotent, 500, Exception (4 Tests) ✅
- `uploadAttachment()`: 201+ETag, Content-Type, Default-CT, 500 (4 Tests) ✅
- `downloadAttachment()`: 200+Bytes, 404 (2 Tests) ✅
- URI-Auflösung: items-Pfad, attachments-Pfad (2 Tests) ✅
- Produktionscode minimal geändert: 1 Feld, 1 Parameter, 8 Aufrufstellen ✅
- Gesamt: 551 → 590 Tests

### O-008: Magic-Number-Arithmetik in Spacing-Tokens — Erledigt in v0.8.1+10 ✅
- Neuer Token `spacingSectionGap` (20.0) in `AppConfig` ✅
- 3 Stellen `spacingXLarge - 4` → `spacingSectionGap` ersetzt ✅
- Datei: `artikel_detail_screen.dart` ✅
- 0 Risiko — reines Rename-Refactoring ✅
- Bestehende Widget-Tests decken die Stellen ab ✅

### P-005: Dependency-Update — Erledigt (bereits in v0.8.0+5 enthalten)
- `cupertino_icons: ^1.0.9` ✅ (war ^1.0.8)
- `shared_preferences: ^2.5.5` ✅ (war ^2.5.4)
- `mockito: ^5.6.4` ✅ (war ^5.6.3)
- `connectivity_plus: ^7.1.1` ✅ (war ^6.1.5 — Major Update inkl. API-Migration)
- `sqlite3`, `flutter_plugin_android_lifecycle`, `image_picker_android` — transitiv,
  kein direkter Eintrag in `pubspec.yaml` erforderlich ✅
- `connectivity_service.dart` bereits auf `List<ConnectivityResult>`-API migriert ✅
- `dependency_overrides` für `connectivity_plus_platform_interface` entfernt ✅

### T-007: Performance-Test Self-Contained — Erledigt in v0.8.0+6
- `setUpAll()` generiert `test_data/import_500.json` (500 Artikel) programmatisch ✅
- 10 minimale PNG-Fixtures (1×1 Pixel, 67 Byte) werden in `setUpAll()` erzeugt ✅
- `tearDownAll()` löscht `test_data/images/`, JSON-Fixture und `test_data/` ✅
- `flutter test` läuft ohne Vorbereitung durch — kein manueller Schritt mehr nötig ✅
- `@Tags(['performance'])` bleibt — weiterhin separat ausführbar ✅
- `tool/generate_import_dataset.dart` bleibt als optionales CLI-Tool (1000+, 5000+) ✅
- Gesamt: 468 → 469 Tests

### T-006: Unit-Tests BackupStatusService — Erledigt in v0.8.0+7
- 22 Tests, alle grün ✅ *(Tests seit v0.8.0 vorhanden, formal abgenommen in v0.8.0+7)*
- `MockClient` (`package:http/testing.dart`) — kein echter HTTP-Request ✅
- `last_backup.json`-Parsing: Timestamp, Status, Dateiname vollständig abgedeckt ✅
- Farblogik: Grün (≤24 h), Gelb (≤72 h), Rot (>72 h) — alle Schwellwerte getestet ✅
- Fehlerfall: Server nicht erreichbar → `BackupStatus.unknown` ✅
- Fehlerfall: Malformed JSON → graceful degradation ✅

### O-007: Tests für ImagePickerService nach P-001 — Erledigt in v0.8.0+7
- 15 Tests, alle grün ✅
- `FakeImagePicker extends ImagePicker` überschreibt `pickImage()` vollständig
  (kein Plattformkanal) ✅
- `@visibleForTesting overrideImagePicker` + `maxFileSizeBytesOverride`
  für saubere Injektion ohne zusätzliche Produktionscode-Komplexität ✅
- `debugDefaultTargetPlatformOverride` via `try/finally` innerhalb `testWidgets`
  zurückgesetzt — `addTearDown` greift nach `_verifyInvariants`, also zu spät ✅
- `XFile.fromData()` statt `XFile(path, bytes:)` — dart:io ignoriert den
  `bytes:`-Parameter und liest vom Dateipfad ✅
- `tester.runAsync()` für Pfade mit `readAsBytes()` / `compute()` ✅
- Abgedeckt: `PickedImage`-Datenklasse (4), `isCameraAvailable` 5 Plattformen (5),
  `openCropDialog()` Guards (2), `pickImageCamera()` alle Pfade (4) ✅
- Gesamt: 469 → 484 Tests


### F-003: Artikeldetailansicht — Ort & Fach nebeneinander — Erledigt in v0.8.0+8
- `artikel_detail_screen.dart`: Ort- und Fach-`TextField` von vertikaler
  `Column`-Anordnung in eine `Row` mit zwei `Expanded`-Kindern (je 50 %) umgebaut ✅
- Neuer AppConfig-Token `detailFieldSpacing` (12.0 dp) für den horizontalen
  Abstand zwischen den beiden Feldern ✅
- `crossAxisAlignment: CrossAxisAlignment.start` — Felder mit unterschiedlicher
  Fehlertext-Höhe (Validation) verschieben sich nicht gegenseitig ✅
- Dark Mode korrekt: `colorScheme.surface / surfaceContainerLow` unverändert ✅
- Responsive: `Expanded` skaliert automatisch auf 360 dp (Mobile) bis 1200+ dp (Desktop) ✅
- Kein Hardcoding: einziger neuer Wert in `AppConfig.detailFieldSpacing` ✅
- Alle 24 bestehenden Widget-Tests grün ✅
- `flutter analyze` — 0 Issues 

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

### T-003: Unit-Tests NextcloudClient
- [ ] `_parsePropfindResponse()` — XML-Fixtures direkt testen
- [ ] `_parseHttpDate()` — RFC-7231-Datumsformate, Edge Cases
- [ ] `uploadItem()` mit `If-Match` — Mock `http.Client`


### P-003: Bild-Caching
Remote-Bilder werden bei jedem Scroll neu geladen.
- [ ] `cached_network_image` Paket einbinden
- [ ] `ArtikelBildWidget` auf `CachedNetworkImage` umstellen
- [ ] Cache-Invalidierung bei ETag-Änderung

### F-001: Biometrische Authentifizierung (Mobile)
- [ ] Implementierung der biometrischen Authentifizierung (Fingerabdruck/Gesichtserkennung) für mobile Plattformen.
- [ ] Optionale Aktivierung in den Einstellungen.
- [ ] Fallback auf PIN/Passwort bei Fehlschlag oder Nichtverfügbarkeit.

### F-002: Konfigurierbare App-Sperrzeit
- [ ] Einstellung für eine Zeitspanne, nach der die App eine erneute Authentifizierung verlangt (bei Inaktivität oder Hintergrundwechsel).
- [ ] Implementierung der Logik zur Überwachung des App-Lebenszyklus und der Inaktivität.


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
| ✅ Abgeschlossen | 36 | 36 | 0 |
| 🔴 Hoch | 0 | 0 | 0 |
| 🟡 Mittel | 5 | 0 | 5 |
| 🟢 Nice-to-Have | 3 | 0 | 3 |
| ⏭️ Future | 1 | 0 | 1 |
| **Gesamt** | **45** | **36** | **9** |

---

## 📈 Vorschläge zur Vervollständigung von Phase 4: Multi-Plattform & Politur (100%)

Um Phase 4 auf 100% zu bringen, müssen die verbleibenden Aspekte der Multi-Plattform-Unterstützung und des Feinschliffs abgeschlossen werden. Basierend auf dem aktuellen Stand und den neuen Punkten schlage ich folgende Ergänzungen vor:

### **Neue To-Dos für Phase 4 (Priorität: Hoch/Mittel, je nach Wichtigkeit):**

*   **P-004: Android Kamera-Test abschließen (Hoch)**
    *   **Beschreibung:** Der aktuelle Status für Android ist "Build stabil, Kamera-Test ausstehend". Dies ist ein kritischer Punkt für die Android-Plattform.
    *   **Details:** Vollständige manuelle und ggf. automatisierte Tests der Kamerafunktionalität auf verschiedenen Android-Geräten und Versionen. Sicherstellung, dass Bilder korrekt aufgenommen, zugeschnitten und hochgeladen werden.
*   **F-001: Biometrische Authentifizierung (Mobile) (Mittel)**
    *   **Beschreibung:** Wie bereits besprochen, ist dies eine wichtige "Politur" für die mobile Nutzung.
*   **F-002: Konfigurierbare App-Sperrzeit (Mittel)**
    *   **Beschreibung:** Verbessert die Benutzerfreundlichkeit und Sicherheit auf mobilen Geräten.
*   **F-003: Artikeldetailansicht optimieren (Mittel)** ✅ Erledigt in v0.8.0+8
*   **N-003: App Icon (Nice-to-Have, aber für 100% Politur nötig)**
    *   **Beschreibung:** Ein professionelles App-Icon ist essentiell für den Feinschliff und die Markenidentität.
*   **N-005: Splash Screen (Nice-to-Have, aber für 100% Politur nötig)**
    *   **Beschreibung:** Ein ansprechender Splash Screen verbessert das Nutzererlebnis beim Start der App.
*   **N-006: Nextcloud-Workflow (Mittel/Nice-to-Have)**
    *   **Beschreibung:** Wenn die Nextcloud-Integration ein Kernbestandteil der Multi-Plattform-Strategie ist, sollte diese finalisiert und getestet werden.

### **Anpassung der "Fortschritts-Übersicht" für Phase 4:**

Um die 52% in Phase 4 zu erreichen, wurden wahrscheinlich schon einige Punkte dieser Phase abgearbeitet. Die oben genannten Punkte sind die verbleibenden, die für eine 100%ige Fertigstellung notwendig wären.

Ich würde vorschlagen, die "Phase 4" in der "Gesamtfortschritt"-Tabelle erst auf 100% zu setzen, wenn alle oben genannten Punkte (oder die, die du als Teil von Phase 4 definierst) als "Erledigt" markiert sind.

---

## 🔍 Wartungs-Historie

| Datum | Version | Änderung |
|---|---|---|
| 2026-04-13 | v0.8.1+12 | T-003 abgeschlossen: 39 Unit-Tests NextcloudClient — testConnection, createFolder, listItemsEtags, downloadItem, uploadItem, deleteItem, uploadAttachment, downloadAttachment, RemoteItemMeta, URI-Auflösung — MockClient injiziert, Produktionscode minimal refactored — Gesamt 551→590 |
| 2026-04-13 | v0.8.1+11 | T-004 abgeschlossen: 18 Widget-Tests MergeDialog — Grundstruktur, Konflikt-Anzeige, Feld-Auswahl, Bild-Auswahl, Zusammenführen, Dialog-Schließen, Menge-Fallback. O-008 abgeschlossen: spacingSectionGap Token, 3 Stellen ersetzt. Gesamt 533→551 |
| 2026-04-13 | v0.8.1+10 | T-005 abgeschlossen: 34 Tests AttachmentService — getForArtikel, countForArtikel, upload, updateMetadata, delete, deleteAllForArtikel, Integration — PocketBaseService.overrideForTesting, FakeAttachmentRecordService, fakeClientException — Gesamt 499→533 |
| 2026-04-13 | v0.8.0+8 | F-003: Artikeldetailansicht — Ort & Fach nebeneinander |
| 2026-04-13 | v0.8.0+7 | O-007 abgeschlossen: 15 Tests ImagePickerService — FakeImagePicker, isCameraAvailable (5 Plattformen), openCropDialog Guards, pickImageCamera alle Pfade — Gesamt 469→484 |
| 2026-04-13 | v0.8.0+7 | T-006 abgeschlossen: BackupStatusService (22 Tests seit v0.8.0) formal abgenommen — MockClient, Farblogik, Fehlerfälle |
| 2026-04-13 | v0.8.0+6 | T-007 abgeschlossen: Performance-Test self-contained — setUpAll/tearDownAll, minimale PNG-Fixtures, Gesamt 468→469 |
| 2026-04-13 | v0.8.0+6 | P-005 als erledigt markiert: alle Ziel-Versionen bereits in pubspec.yaml, connectivity_plus v7 API-Migration bereits umgesetzt |
| 2026-04-12 | v0.8.0+5 | T-002 abgeschlossen: 17 Unit-Tests PocketBase SyncService — Push/Pull/Fehler/UUID/Image, manuelle Fakes, Gesamt 451→468 |
| 2026-04-11 | v0.8.0 | F-001, F-002, F-003 hinzugefügt und in Priorität "Mittel" einsortiert. Fortschritts-Übersicht aktualisiert. |
| 2026-04-10 | v0.8.0 | +104 Tests: AttachmentModel (30), attachment_utils (28), BackupStatus (22) — Gesamt 347→451, TESTING.md aktualisiert |
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