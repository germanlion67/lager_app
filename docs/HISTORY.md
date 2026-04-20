# 📜 Projekthistorie & Meilensteine

Dieses Dokument dient als geordnetes Archiv für alle bisherigen Phasen, Releases, technischen Meilensteine und historisch relevanten Entscheidungen der **Lager_app**.

> **Hinweis:**  
> Diese `HISTORY.md` enthält **nur abgeschlossene, historisch relevante und versionierte Änderungen**.  


Die Einträge sind **primär nach Versionsnummer**, **sekundär nach Datum** sortiert.  
Einträge **ohne eindeutige Versionszuordnung** stehen gesammelt im Archivbereich.

---

## Inhaltsverzeichnis

1. [Versionshistorie](#1-versionshistorie)
2. [O-004 Migrationshistorie aus `THEMING.md`](#2-o-004-migrationshistorie-aus-themingmd)
3. [Archiv: nicht eindeutig versionierte Einträge](#3-archiv-nicht-eindeutig-versionierte-einträge)
4. [Historische Architektur-Entscheidungen](#4-historische-architektur-entscheidungen)

---

## 1. Versionshistorie

### v0.8.6+21 — 2026-04-20

#### P-003: Bild-Caching — erledigt in `v0.8.6+21`
- Integration von `cached_network_image`
- `ArtikelBildWidget` nutzt persistenten Cache für Remote-Bilder
- Kein Flackern/Neu-Laden beim Scrollen in der Liste
- Cache-Invalidierung bei ETag-Änderung sichergestellt


### v0.8.5+19 — 2026-04-20

#### B-003: Bild-Download-Skip-Logik in downloadMissingImages — abgeschlossen in `v0.8.5+19`
- Skip-Bedingung war invertiert — Negation fehlte
- Korrigiert: Skip nur wenn `bildPfad.isNotEmpty && dateiExistiert && dateiHatInhalt`
- Bilder werden jetzt korrekt heruntergeladen wenn lokal nicht vorhanden

#### B-004: Konflikt-Callback-Registrierung nach Navigator-Init via GlobalKey — abgeschlossen in `v0.8.5+19`
- `GlobalKey<NavigatorState>` in `main.dart` eingeführt
- Callback-Registrierung via `addPostFrameCallback` nach erstem Frame
- DB-Reopen nach App-Resume vor Sync-Start sichergestellt

#### B-005: ETag-basierte Konflikt-Erkennung vor PATCH — abgeschlossen in `v0.8.5+19`
- Vor jedem PATCH: Remote-Record laden, `updated`-Timestamp mit lokalem `etag` vergleichen
- Bei Abweichung: `onConflictDetected`-Callback statt blindem Überschreiben
- ETag = PocketBase `updated`-Timestamp (ISO 8601), nicht Record-ID

#### B-006: SyncManagementScreen nutzt SyncOrchestrator statt SyncService — abgeschlossen in `v0.8.5+19`
- `SyncManagementScreen` erhält `SyncOrchestrator`-Instanz als Parameter
- Sync-Start über `orchestrator.runOnce()`
- Status-Updates korrekt über `syncStatus`-Stream

#### T-008: ETag-Konflikt-Logik und downloadMissingImages-Check-Logik — abgeschlossen in `v0.8.5+19`
- `pocketbase_sync_service_conflict_test.dart` — 11 Tests ✅
- `sync_orchestrator_test.dart` — 9 Tests (erweitert) ✅
- ETag-Grenzwerte, ConflictCallback-Typedef, SyncStatus-Enum abgedeckt ✅
- Gesamtstand: **610 Tests**, 28 Dateien ✅


### v0.8.4+17 — 2026-04-14

#### F-004: Nextcloud-Status-Icon Farbe angleichen
- Nextcloud-Online-Icon auf `AppConfig.statusColorConnected` (`Material Green 500`) umgestellt ✅
- Konsistente Farbsemantik:
  - Grün = verbunden
  - Rot = getrennt
  - Grau = unbekannt
- Bestehendes semantisches Token wiederverwendet — kein neuer Token nötig ✅

#### F-005: Detail-Screen Felder leserlicher darstellen
- Readonly-Felder: `OutlineInputBorder` + `filled: true` + `fillColor: surfaceContainerLow` ✅
- Text-Farbe im Readonly-Modus: volle Opazität via `onSurface` statt `disabledColor` ✅
- Edit-Modus visuell klar unterscheidbar: `fillColor: surface` + Unterstrich ✅
- Menge und Artikelnummer als `InputDecorator` mit Label statt inline-Text ✅
- Menge-`+/-`-Buttons nur noch im Edit-Modus sichtbar ✅
- Dark Mode: Kontrast in beiden Modi korrekt ✅
- 3 bestehende Widget-Tests an neues Layout angepasst ✅

#### N-003: App-Icon
- Neues App-Logo (`app_logo.png`) mit Lager-Design erstellt ✅
- `flutter_launcher_icons` für alle Plattformen generiert ✅
- Android: `mipmap-hdpi` bis `mipmap-xxxhdpi` ✅
- iOS: alle `AppIcon`-Größen (`20x20` bis `1024x1024`) ✅
- Web: `favicon.png`, `Icon-192`, `Icon-512`, maskable Icons ✅
- Windows: `app_icon.ico` ✅

#### N-005: Native Splash Screen
- `flutter_native_splash` Konfiguration erweitert ✅
- Light Mode: `#1976d2` mit App-Logo ✅
- Dark Mode: `#121212` mit App-Logo ✅
- Android 12+ Splash-API Support ✅
- Web Splash Screen ✅
- Alle Plattformen: Android, iOS, Web ✅

---

### v0.8.3+16 — 2026-04-14

#### B-001: Settings-Änderungen werden ohne Speichern übernommen
- Analyse des Settings-Verhaltens abgeschlossen ✅
- Dirty-Tracking war bereits korrekt implementiert (`_hasUnsavedChanges`, `_isDirty()`) ✅
- Unsaved-Changes-Dialog bei Zurück-Navigation vorhanden (`_onWillPop()`) ✅
- Save-Button mit Dirty-State-Kopplung vorhanden (`_buildSaveButton()`) ✅
- `onChanged`-Handler ändern nur lokalen State, keine direkten Service-Aufrufe ✅
- Alle Persistierung gebündelt in `_saveSettings()` ✅
- Snackbar-Feedback nach erfolgreichem Speichern vorhanden ✅
- Ergebnis: **Kein Code-Fix nötig**, Verhalten war bereits korrekt implementiert ✅

#### B-002: Biometrische Authentifizierung — System-Dialog & Verfügbarkeitsprüfung

##### B-002.1: Nativer System-Dialog
- `_authenticate()` ruft `auth.authenticate()` korrekt auf ✅
- `AuthenticationOptions(biometricOnly: true)` gesetzt ✅
- Automatischer Start via `addPostFrameCallback` in `initState()` ✅
- Fallback-Button für manuellen Retry vorhanden ✅
- Android: `FlutterFragmentActivity` in `MainActivity.kt` bestätigt ✅

##### B-002.2: Verfügbarkeitsprüfung beim Einschalten
- `canCheckBiometrics` + `isDeviceSupported()` wird vor Aktivierung geprüft ✅
- Bei nicht verfügbarer Biometrie: Toggle zurückgesetzt + Fehlermeldung ✅
- Probe-`authenticate()` bei Aktivierung durchgeführt ✅
- Nur bei erfolgreicher Probe wird `setBiometricsEnabled(true)` persistiert ✅

---

### v0.8.2+13 — 2026-04-13

#### F-001: Biometrische Authentifizierung (Mobile)
- `AppLockService` Singleton mit `SharedPreferences`-Persistenz ✅
- `WidgetsBindingObserver` für App-Lifecycle-Erkennung ✅
- `AppLockScreen` mit `local_auth 3.0.1` API ✅
- Automatischer Start der biometrischen Authentifizierung beim Anzeigen ✅
- Fallback auf Geräte-PIN/Pattern, wenn Biometrie nicht verfügbar ✅
- Integration in `main.dart` via `AppLockService().init()` ✅

#### F-002: Konfigurierbare App-Sperrzeit
- `AppLockService` überwacht App-Lebenszyklus (`didChangeAppLifecycleState`) ✅
- Inaktivitäts-Timer mit konfigurierbarer Dauer (`lockTimeout`) ✅
- Sperrzeit persistent in `SharedPreferences` gespeichert ✅
- App sperrt automatisch bei Hintergrundwechsel nach Timeout-Ablauf ✅

---

### v0.8.1+12 — 2026-04-13

#### T-003: Unit-Tests `NextcloudClient`
- **39 Tests**, alle grün ✅
- `MockClient` aus `package:http/testing.dart` — kein Netzwerk nötig ✅
- Optionaler `http.Client? client`-Parameter im Konstruktor (rückwärtskompatibel) ✅
- Alle 8 HTTP-Stellen auf injizierten `_client` umgestellt ✅

##### Abgedeckte Bereiche
- `RemoteItemMeta`: Equality (`path+etag`), `copyWith`, `toString` ✅
- `testConnection()`: `200`, `404`, `500`, Exception, Auth-Header ✅
- `createFolder()`: `201`, `405`, `500`, Exception ✅
- `listItemsEtags()`: 1 Item, Multi-Item, leer, `403`, Non-JSON-Filter, kein ETag, custom Path ✅
- `downloadItem()`: `200`, `404`, Netzwerkfehler ✅
- `uploadItem()`: `201+ETag`, `If-Match`, `412 Conflict`, `500`, kein ETag ✅
- `deleteItem()`: `204`, `404` idempotent, `500`, Exception ✅
- `uploadAttachment()`: `201+ETag`, Content-Type, Default-CT, `500` ✅
- `downloadAttachment()`: `200+Bytes`, `404` ✅
- URI-Auflösung: Items-Pfad, Attachments-Pfad ✅

##### Ergebnis
- Produktionscode minimal geändert: 1 Feld, 1 Parameter, 8 Aufrufstellen ✅
- Gesamtstand Tests: **551 → 590**

---

### v0.8.1+11 — 2026-04-13

#### T-004: Widget-Tests Merge-Dialog
- **18 Widget-Tests**, alle grün ✅
- Grundstruktur des Dialogs getestet ✅
- Konflikt-Anzeige getestet ✅
- Feld-Auswahl getestet ✅
- Bild-Auswahl getestet ✅
- Zusammenführen getestet ✅
- Dialog-Schließen getestet ✅
- Menge-Fallback getestet ✅
- Gesamtstand Tests: **533 → 551**

#### O-008: Magic-Number-Arithmetik in Spacing-Tokens
- Neuer Token `spacingSectionGap` (`20.0`) in `AppConfig` ✅
- 3 Stellen `spacingXLarge - 4` → `spacingSectionGap` ersetzt ✅
- Datei: `artikel_detail_screen.dart` ✅
- Reines Rename-/Token-Refactoring ohne Verhaltensänderung ✅
- Bestehende Widget-Tests decken die Stellen ab ✅

---

### v0.8.1+10 — 2026-04-13

#### T-005: Unit-Tests `AttachmentService`
- **34 Tests**, alle grün ✅
- Get-/Count-/Upload-/Update-/Delete-Pfade abgedeckt ✅
- Integration: Upload → Get-Roundtrip abgedeckt ✅
- Grenzwert 19 vs. 20 Anhänge getestet ✅
- `PocketBaseService.overrideForTesting` genutzt ✅
- `FakeAttachmentRecordService` und `fakeClientException` verwendet ✅
- Gesamtstand Tests: **499 → 533**

---

### v0.8.0+8 — 2026-04-13

#### F-003: Artikeldetailansicht — Ort & Fach nebeneinander
- `artikel_detail_screen.dart`: Ort- und Fach-`TextField` von vertikaler `Column`-Anordnung in eine `Row` mit zwei `Expanded`-Kindern umgebaut ✅
- Neuer `AppConfig`-Token `detailFieldSpacing` (`12.0 dp`) für den horizontalen Abstand ✅
- `crossAxisAlignment: CrossAxisAlignment.start` verhindert visuelles Springen bei unterschiedlich hohen Fehlertexten ✅
- Responsive: `Expanded` skaliert automatisch von Mobile bis Desktop ✅
- Dark Mode unverändert korrekt ✅
- Kein Hardcoding — neuer Abstand vollständig über Token ✅
- Alle 24 bestehenden Widget-Tests grün ✅
- `flutter analyze`: **0 Issues**

---

### v0.8.0+7 — 2026-04-13

#### T-006: Unit-Tests `BackupStatusService`
- **22 Tests**, alle grün ✅
- Tests seit `v0.8.0` vorhanden, formal abgenommen in `v0.8.0+7` ✅
- `MockClient` (`package:http/testing.dart`) — kein echter HTTP-Request ✅
- `last_backup.json`-Parsing vollständig abgedeckt ✅
- Farblogik:
  - Grün (`≤24 h`)
  - Gelb (`≤72 h`)
  - Rot (`>72 h`) ✅
- Fehlerfall: Server nicht erreichbar → `BackupStatus.unknown` ✅
- Fehlerfall: Malformed JSON → graceful degradation ✅

#### O-007: Tests für `ImagePickerService` nach P-001
- **15 Tests**, alle grün ✅
- `FakeImagePicker extends ImagePicker` überschreibt `pickImage()` vollständig ✅
- `@visibleForTesting overrideImagePicker` + `maxFileSizeBytesOverride` für saubere Injektion ✅
- `debugDefaultTargetPlatformOverride` via `try/finally` in `testWidgets` sauber zurückgesetzt ✅
- `XFile.fromData()` statt `XFile(path, bytes:)` wegen `dart:io`-Verhalten ✅
- `tester.runAsync()` für Pfade mit `readAsBytes()` / `compute()` ✅

##### Abgedeckt
- `PickedImage`-Datenklasse ✅
- `isCameraAvailable` für 5 Plattformen ✅
- `openCropDialog()` Guards ✅
- `pickImageCamera()` alle Pfade ✅

##### Ergebnis
- Gesamtstand Tests: **469 → 484**

---

### v0.8.0+6 — 2026-04-13

#### T-007: Performance-Test self-contained
- `setUpAll()` generiert `test_data/import_500.json` mit 500 Artikeln programmatisch ✅
- 10 minimale PNG-Fixtures (`1×1 Pixel`, `67 Byte`) werden in `setUpAll()` erzeugt ✅
- `tearDownAll()` löscht `test_data/images/`, JSON-Fixture und `test_data/` ✅
- `flutter test` läuft ohne Vorbereitung durch ✅
- `@Tags(['performance'])` bleibt — weiterhin separat ausführbar ✅
- `tool/generate_import_dataset.dart` bleibt als optionales CLI-Tool für größere Datensätze ✅
- Gesamtstand Tests: **468 → 469**

---

### v0.8.0+5 — 2026-04-12

#### T-002: Unit-Tests `PocketBaseSyncService`
- **17 Unit-Tests** abgeschlossen ✅
- Push-/Pull-/Fehler-/UUID-Sanitization-/Image-Skip-Logik abgedeckt ✅
- Manuelle Fakes eingesetzt, kein echter Netzwerkzugriff nötig ✅
- Gesamtstand Tests: **451 → 468**

#### P-005: Dependency-Update
- `cupertino_icons: ^1.0.9` ✅
- `shared_preferences: ^2.5.5` ✅
- `mockito: ^5.6.4` ✅
- `connectivity_plus: ^7.1.1` ✅
- `connectivity_service.dart` bereits auf `List<ConnectivityResult>`-API migriert ✅
- `dependency_overrides` für `connectivity_plus_platform_interface` entfernt ✅

---

### v0.8.0 — 2026-04-10

#### 🎉 K-006: Hauptfeature: Kaltstart-Bugfix

##### Problem
Nach einem Kaltstart (App-Daten gelöscht, neue PocketBase-URL konfiguriert)  
blieb die Artikelliste leer, obwohl der Sync im Hintergrund erfolgreich lief.  
Bilder wurden nicht heruntergeladen und der Benutzer sah keine Rückmeldung.

##### Ursachen
1. **Sync-UI-Entkopplung:** `ArtikelListScreen` wusste nicht, wann der Sync abgeschlossen war  
2. **Fehlender Bild-Download:** PocketBase-Sync übertrug nur Metadaten (`remoteBildPfad`)  
3. **Globaler Image-Cache-Clear:** `imageCache.clear()` verwarf alle gecachten Bilder  
4. **Sofortiger UI-Wechsel nach Setup:** Die UI wechselte zu früh zur leeren Liste

#### ✨ Neue Features
- `SyncStatusProvider`-Interface für lose Kopplung zwischen Sync und UI
- `ArtikelListScreen` reagiert auf `SyncStatus.success`
- `FakeSyncStatusProvider` als Test-Double
- Automatischer Bild-Download via `downloadMissingImages()`
- PocketBase-Bild-Fallback in `_LocalThumbnail` und `ArtikelDetailBild`
- Setup-Flow wartet auf initialen Sync
- Buttons im Setup-Screen während Sync deaktiviert

#### 🔧 Technisch
##### Neue Dateien
- `lib/services/sync_status_provider.dart`
- `lib/screens/list_screen_cache_io.dart`
- `lib/screens/list_screen_cache_stub.dart`
- `test/helpers/fake_sync_status_provider.dart`
- `test/services/sync_status_provider_test.dart`

##### Wichtige Änderungen
- `sync_orchestrator.dart` implementiert `SyncStatusProvider`
- `pocketbase_sync_service.dart` erweitert um Bild-Download
- `artikel_db_service.dart`: `setBildPfadByUuidSilent()`
- `artikel_list_screen.dart`: StreamSubscription + gezieltes Cache-Evict
- `main.dart`: Sync abwarten vor UI-Wechsel
- `server_setup_screen.dart`: Lade-Overlay
- `artikel_bild_widget.dart`: PB-Fallback

#### 📚 Dokumentation
- `CHANGELOG.md` aktualisiert
- `OPTIMIZATIONS.md` aktualisiert
- `TESTING.md` aktualisiert
- `ARCHITECTURE.md` aktualisiert
- `DATABASE.md` aktualisiert
- `LOGGER.md` aktualisiert

#### 🧪 Tests
- `flutter analyze`: **0 Issues**
- `flutter test`: **451 bestanden**, 3 übersprungen
- Testsuite: 347 → **451 Tests** (+104), 15 → **18 Dateien** (+3)

---

### v0.7.8 — 2026-04-09

#### ✨ Verbessert: UI-Ansicht

##### 🖼️ Artikel-Detail-Screen
- Artikelname direkt editierbar
- „Zuschneiden“-Button nach Bildauswahl
- Body aufgeräumt, Aktionen in die AppBar verschoben

##### 🎛️ AppBar-Aktionen
- Bild wählen / Kamera nur im Edit-Modus
- Anhänge immer sichtbar, mit Badge-Zähler
- Ändern / Speichern in der AppBar
- PDF-Export & Löschen konsistent in der AppBar

##### 📝 Artikel-Erfassen-Screen
- `textCapitalization: sentences` für Name, Beschreibung, Ort und Fach
- Menge-Feld markiert beim Antippen den gesamten Inhalt
- Bild-Buttons kompakter als `IconButton`

##### 🔍 Artikel-Liste
- QR-Scanner direkt neben dem Suchfeld
- „Neuer Artikel“ in der AppBar statt `FloatingActionButton.extended`
- DB-Icon grün bei Verbindung via `AppConfig.statusColorConnected`

##### 🔧 Technisch
- Neues semantisches Token `AppConfig.statusColorConnected` (`Color(0xFF4CAF50)`)
- `AnhaengeSektion.build()` gibt `SizedBox.shrink()` zurück
- `FocusNode _mengeFocus` mit automatischer Vollauswahl
- `_nameController` vollständig in den Detail-Screen integriert
- `flutter analyze`: **0 Issues**

---

### v0.7.7+5 — 2026-04-08

#### P-002: Suche Debounce + DB-Suche
- `Timer(300ms)` verhindert Suche bei jedem Tastendruck
- Mobile: SQL `LIKE` via `_db.searchArtikel()`
- Web: clientseitiger Filter über geladene PocketBase-Liste
- Skeleton während laufender Suche
- Footer bei aktiver Suche versteckt
- Leer-Feld → sofortiger Reset zur paginierten Liste

#### O-006: Widget-Tests `ArtikelErfassenScreen`
- 11 Tests: Render, Validierung, Abbrechen-Pfade
- `physicalSize 1080x2400` + `scrollUntilVisible()` für `ListView`
- `pumpAndSettle(5s)` für async `_initArtikelnummer()`

---

### v0.7.7+4 — 2026-04-08

#### M-005: Pagination für Artikelliste
- `ScrollController` mit `_onScroll()`-Listener
- `_ladeArtikel()`: Reset mit `offset = 0`
- `_ladeNaechsteSeite()`: offset-basiertes Nachladen mit Guard gegen Doppel-Requests
- Lade-Footer am Listenende
- Web unverändert: `getFullList()` + `_hasMore = false`
- Neue `AppConfig`-Tokens:
  - `paginationPageSize = 30`
  - `paginationScrollThreshold = 200.0`

#### O-005: Deprecated `DokumenteButton` entfernt
- 5 Dateien gelöscht
- `cached_network_image` bleibt anderweitig aktiv genutzt
- `flutter analyze`: **0 Issues**

---

### v0.7.7+2 — 2026-04-07

#### P-001: Kamera-Vorschau-Delay auf Android behoben
- Crop-Dialog aus dem Capture-Flow entfernt
- `maxWidth = 800`, `maxHeight = 800`, `imageQuality = 85` direkt an `picker.pickImage()`
- `openCropDialog()` als `public static`-Methode
- Optionaler „Zuschneiden“-Button im `ArtikelErfassenScreen`

##### Ergebnis
Kamera → sofortige Vorschau auf Android, Crop bleibt optional.

---

### v0.7.7+1 — 2026-04-06

#### T-001: Widget-Tests abgeschlossen
- Tests für Konfliktlösung — Unit- und Widget-Tests vollständig (**77 Tests**) ✅
- `SyncService.detectConflicts()` — 9 Tests
- `_determineConflictReason()` — 15 Tests
- `ConflictResolutionScreen` — 20 Widget-Tests

##### Technische Besonderheit
- `setSurfaceSize(1024×900)` für Widget-Tests
- Standard-Viewport (`800×600`) war zu klein
- `addTearDown` stellt den Default-Viewport wieder her

##### Ausstehend
- T-001.6–T-001.12 manuell auf zwei verbundenen Geräten

---

### v0.7.7 — 2026-04-05

#### Release: Qualitäts-Release mit Tests & Dokumentation

Dieses Release fasst die `v0.7.6+x`-Zwischenstände zusammen und bringt die Version auf `0.7.7`.

#### M-003: Error Handling — erledigt in `v0.7.6+3`
- Neue `AppException`-Hierarchie (`sealed class`) ✅
- Neuer `AppErrorHandler` mit Klassifizierung, Logging, SnackBars und Dialogen ✅
- `sync_conflict_handler.dart`: rohe `$e`-Strings → `AppErrorHandler` ✅
- Netzwerk- und Timeout-Fehler werden automatisch klassifiziert ✅
- Lint-Fixes behoben ✅

#### M-004: Loading States — erledigt in `v0.7.6+2`
- `AppLoadingOverlay`, `AppLoadingIndicator`, `AppLoadingButton` ✅
- `ArtikelSkeletonTile` + `ArtikelSkeletonList` ✅
- Skeleton statt `CircularProgressIndicator` ✅
- Overlay im Detail-Screen und Sync-Management ✅
- 10 neue `AppConfig`-Tokens ✅

#### M-006: Input Validation — erledigt in `v0.7.6+1`
- Pflichtfelder und Inline-Fehlermeldungen ✅
- Name: 2–100 Zeichen ✅
- Menge: nur positive Ganzzahlen, max. `999.999` ✅
- Artikelnummer automatisch ab `1000`, manuell änderbar ✅
- Duplikat-Checks lokal + PocketBase ✅
- `existsKombination()` und `existsArtikelnummer()` ✅

#### O-002: Unit-Tests für `ArtikelDbService` — erledigt in `v0.7.6+4`
- 75 Tests für `ArtikelDbService` ✅
- 64 Tests für `ArtikelModel` ✅
- 30 Tests für `ImageProcessingUtils` ✅
- 23 Tests für `UuidGenerator` ✅
- In-Memory-Setup via `sqflite_common_ffi` ✅
- Produktionsbug in `getUnsyncedArtikel()` gefunden und gefixt ✅

#### Dokumentation
- `docs/TESTING.md` neu erstellt
- `CHANGELOG.md`, `OPTIMIZATIONS.md`, `HISTORY.md`, `README.md` aktualisiert

---

### v0.7.5+1 — 2026-04-03

#### M-008: Backup-Status im Settings-Screen anzeigen
- `BackupStatusService` liest `last_backup.json` via HTTP vom PocketBase-Server
- `BackupStatusWidget` mit farbcodierter Status-Card
- Loading/Error/Unknown-States
- Detail-Zeilen: Zeitpunkt, Datei, Größe, Backup-Anzahl, Rotation
- Refresh-Button zum manuellen Aktualisieren
- Integration in `settings_screen.dart`
- `backup.sh` kopiert `last_backup.json` nach `pb_public`
- `docker-compose.prod.yml` um `pb_public`-Volume ergänzt

---

### v0.7.5+0 — 2026-04-02

#### M-007: UI für Konfliktlösung
- `ConflictResolutionScreen` mit Side-by-Side-Vergleich ✅
- `ConflictData` + `ConflictResolution`-Enum ✅
- Multi-Konflikt-Navigation mit Fortschrittsanzeige ✅
- Merge-Dialog für manuelle Zusammenführung ✅
- Integration mit `SyncConflictHandler` und `SyncService` ✅
- Entscheidungs-Callbacks (`useLocal`, `useRemote`, `merge`, `skip`) ✅
- Unit- und Widget-Tests erstellt (T-001, 77 Tests) ✅

##### Durchgeführte Arbeiten
- `OPTIMIZATIONS.md` bereinigt: Doppelung M-007 (alt) → K-003 umbenannt
- M-007 als erledigt markiert
- 37 Unit-Tests erstellt (`conflict_resolution_test.dart`)
- Neue Aufgabe T-001 für manuelle Integrationstests erstellt

---

### v0.7.4+7 — 2026-04-02

#### O-004 Batch 5
- Keine neuen `AppConfig`-Tokens nötig
- `list_screen_mobile_actions.dart` — 17 Hardcodes → 0
- `nextcloud_settings_screen.dart` — 21 Hardcodes → 0
- `qr_scan_screen_mobile_scanner.dart` — 12 → 6 (bewusst)
- `image_crop_dialog.dart` — 11 → 5 (bewusst)
- `artikel_erfassen_screen.dart` — 12 → 0
- `list_screen_web_actions.dart` — 8 → 0
- `artikel_bild_widget.dart` — 5 → 2 (bewusst)
- `nextcloud_resync_dialog.dart` — 7 → 0
- Übersprungen:
  - `detail_screen_io.dart`
  - `list_screen_io.dart`
  - `list_screen_mobile_actions_stub.dart`
  - `_dokumente_button.dart`

---

### v0.7.4+6 — 2026-04-02

#### O-004 Batch 4
- `app_config.dart` — 13 neue Tokens
- `attachment_upload_widget.dart` — 28 Hardcodes → 0
- `attachment_list_widget.dart` — 23 Hardcodes → 0
- `server_setup_screen.dart` — 23 Hardcodes → 0
- `login_screen.dart` — 18 Hardcodes → 0

---

### v0.7.4+5 — 2026-04-02

#### O-004 Batch 3
- Keine neuen `AppConfig`-Tokens nötig
- `artikel_detail_screen.dart` — 36 Hardcodes → 0
- `artikel_list_screen.dart` — 31 Hardcodes → 0
- `sync_conflict_handler.dart` — 31 Hardcodes → 0

---

### v0.7.4+4 — 2026-04-01

#### O-004 Batch 2: Sync-Cluster migriert
- **193 Hardcodes** in 4 Dateien eliminiert
- `app_theme.dart` — Component-Themes nutzen `AppConfig`-Tokens
- `conflict_resolution_screen.dart` — größte Einzeldatei (82 Hardcodes)
- `sync_error_widgets.dart` — Severity-Farben über `colorScheme`
- `sync_management_screen.dart` — AppBar und Buttons standardisiert

##### Entscheidungen
- `Colors.purple` → `colorScheme.tertiary`
- `Colors.orange` → `colorScheme.secondary`
- AppBar-Farben entfernt — Standard-Theme greift konsistent
- `_getSeverityColor()` nimmt jetzt `BuildContext`

---

### v0.7.4+3 — 2026-04-01

#### O-004 Batch 1: UI-Hardcoded Werte migrieren
- **109 Hardcodes eliminiert**
- `AppConfig` erweitert
- Dark Mode funktioniert korrekt in allen migrierten Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code

##### `sync_progress_widgets.dart`
- 55 Hardcodes → 0
- Farben auf `colorScheme` migriert
- Layout-Werte auf `AppConfig`-Tokens umgestellt

##### `settings_screen.dart`
- 54 Hardcodes → 0
- Status-Container vereinheitlicht
- `_buildStatusContainer()` als Helper extrahiert

##### Dokumentation
- `THEMING.md` aktualisiert
- `OPTIMIZATIONS.md` aktualisiert
- `CHANGELOG.md` aktualisiert

---

### v0.7.4+0 — 2026-03-30

#### H-002: CORS-Konfiguration & Infrastruktur-Bereinigung
- `CORS_ALLOWED_ORIGINS` wird beim PocketBase-Start korrekt als `--origins`-Flag übergeben
- Neues `entrypoint.sh` Script ersetzt die bisherige Inline-Startlogik
- Wildcard (`*`) bleibt für Entwicklung, Produktion nutzt strikte Origins
- CORS nur auf PocketBase-Ebene
- Zwei Subdomains: Frontend + API
- `docker-compose.production.yml` (Traefik) entfernt
- Portainer Stack an Produktions-Setup angeglichen
- `.env.production` korrigiert

---

### v0.7.3 — Datum im Ursprung nicht explizit genannt

#### M-009: Login-Flow & Authentifizierung
- Login-Screen mit E-Mail/Passwort-Validierung und Loading-State ✅
- Auth-Gate in `main.dart` mit Auto-Login (Token-Refresh) ✅
- Logout im Settings-Screen mit Bestätigungs-Dialog ✅
- PocketBase API-Regeln auf Auth umgestellt ✅

---

### v0.7.2 — 2026-03-29

#### M-012: Attachments (Dateianhänge pro Artikel)
- PocketBase Collection `attachments` mit File-Upload und Metadaten
- `AttachmentService` (Singleton) — CRUD gegen PocketBase
- `AttachmentModel` — MIME-Type-Erkennung und Größenformatierung
- `AttachmentUploadWidget` — Upload-Dialog mit Validierung
- `AttachmentListWidget` — Liste mit Download, Bearbeiten, Löschen
- `AnhaengeSektion` im Detail-Screen mit Badge-Counter und BottomSheet

##### Problem bei Inbetriebnahme
Upload schlug mit HTTP 400 fehl:
1. `uuid`-Pflichtfeld fehlte im Upload-Body
2. API-Regeln erforderten Auth, aber es gab noch keinen Login-Flow

##### Fix
- `UuidGenerator.generate()` ergänzt
- API-Regeln vorübergehend auf offen gesetzt

##### Weitere Fixes
- Detailansicht zeigt jetzt `artikel.artikelnummer` statt `artikel.id`
- `updated_at` wird in `toPocketBaseMap()` an PocketBase gesendet

---

### v0.7.1 — 2026-03-27 bis 2026-03-28

#### H-003: Backup-Automatisierung
- Dedizierter Backup-Container mit Cron ✅
- SQLite WAL-Checkpoint vor jedem Backup ✅
- Komprimiertes `tar.gz`-Archiv mit Integritätsprüfung ✅
- Rotation alter Backups (Standard: 7 Tage) ✅
- E-Mail- und Webhook-Benachrichtigung ✅
- Status-JSON (`last_backup.json`) für App-Anzeige ✅
- Restore-Script mit Sicherheitskopie und Healthcheck ✅

#### K-005: WSL2-Entwicklungsumgebung — Bildanzeige-Problem gelöst
**Problem:** `Image.memory` wurde unter WSL2 nicht korrekt angezeigt.  
In der Browser-Konsole erschien:

```text
WARNING: Falling back to CPU-only rendering. Reason: webGLVersion is -1
```

**Lösung:** Web-Server-Modus statt `flutter run -d chrome`:

```bash
flutter run -d web-server --web-port 8888 --web-hostname 0.0.0.0
```

Dann im Windows-Browser mit echtem WebGL öffnen: `http://localhost:8888`

**Dokumentation:**
- `DEV_SETUP.md` neu erstellt
- `INSTALL.md` ergänzt

---

### v0.7.0 — 2026-03-27

#### K-004: Runtime-Konfiguration der PocketBase-URL

##### Problem
Die PocketBase-URL wurde ausschließlich zur Build-Zeit per `--dart-define=POCKETBASE_URL=...` gesetzt.  
Das führte zu mehreren Problemen:
- App crashte beim Start, wenn die URL fehlte oder ungültig war
- URL-Änderung erforderte einen neuen Build
- Placeholder-URLs verursachten Fehler in Release-Builds
- `localhost` funktionierte auf Android nicht

##### Lösung
Dreistufige URL-Prioritätskette mit Setup-Screen als Fallback:

| Priorität | Quelle | Beschreibung |
|---|---|---|
| 1 | `SharedPreferences` / `localStorage` | Vom Benutzer gespeicherte URL |
| 2 | Runtime-Config (Web) / `--dart-define` | Build-Default oder Container-Config |
| 3 | Setup-Screen | Benutzer gibt URL manuell ein |

##### Ergebnis
- App startet immer, auch komplett ohne URL-Konfiguration
- Bestehende Installationen mit gespeicherter URL funktionieren unverändert
- `--dart-define` bleibt optional
- Web-Runtime-Config über `window.ENV_CONFIG` bleibt erhalten

---

### v0.3.0 — frühe Basisarbeiten

#### K-003: Artikelnummer & Indizes
- Eindeutige Artikelnummer (`1000+`) ✅
- 5 Performance-Indizes ✅
- Artikelnummer in Listen- und Detailansicht ✅

#### O-001: Bereinigung von `debugPrint`
- Alle `debugPrint`-Aufrufe durch `AppLogService` ersetzt ✅
- Verbleibende 8 Aufrufe in `app_log_io.dart` sind absichtlich ✅

#### M-002: AppLogService Integration
- Konsistentes Logging im gesamten Projekt ✅

#### N-004: Roboto Font
- Roboto als Standard-Schriftart via `google_fonts` ✅

---

### v0.2.0 — frühe Server- und Schema-Basis

#### K-002: PocketBase Schema & API Rules
- Automatische Initialisierung (Admin-User, Collections, Migrations) ✅
- API Rules konfiguriert ✅

---

## 2. O-004 Migrationshistorie aus `THEMING.md`

> Übernommen am **2026-04-15**.  
> Inhaltlich gehört diese Migration zur Versionsreihe **v0.7.4+3 bis v0.7.4+7**.

### Kumulierter Fortschritt

| Version | Batch | Hardcodes | Status |
|---|---|---|---|
| `v0.7.4+7` | Batch 5 | `~108` | ✅ Erledigt |
| `v0.7.4+6` | Batch 4 | `~92` | ✅ Erledigt |
| `v0.7.4+5` | Batch 3 | `~98` | ✅ Erledigt |
| `v0.7.4+4` | Batch 2 | `193` | ✅ Erledigt |
| `v0.7.4+3` | Batch 1 | `109` | ✅ Erledigt |

### Detailübersicht nach Version

#### v0.7.4+7 — Batch 5

| Datei | Hardcodes | Status |
|---|---|---|
| `list_screen_mobile_actions.dart` | `17 → 0` | ✅ |
| `nextcloud_settings_screen.dart` | `21 → 0` | ✅ |
| `qr_scan_screen_mobile_scanner.dart` | `12 → 6` | ✅ (6 bewusst) |
| `image_crop_dialog.dart` | `11 → 5` | ✅ (5 bewusst) |
| `artikel_erfassen_screen.dart` | `12 → 0` | ✅ |
| `list_screen_web_actions.dart` | `8 → 0` | ✅ |
| `artikel_bild_widget.dart` | `5 → 2` | ✅ (2 bewusst) |
| `nextcloud_resync_dialog.dart` | `7 → 0` | ✅ |
| `detail_screen_io.dart` | `3 → 3` | ⏭️ (kein `BuildContext`) |
| `list_screen_io.dart` | `3 → 3` | ⏭️ (kein `BuildContext`) |
| `list_screen_mobile_actions_stub.dart` | `4 → 4` | ⏭️ (Stub) |
| `_dokumente_button.dart` | `18` | ⏭️ (deprecated) |

#### v0.7.4+6 — Batch 4

| Datei | Hardcodes | Status |
|---|---|---|
| `attachment_upload_widget.dart` | `28 → 0` | ✅ |
| `attachment_list_widget.dart` | `23 → 0` | ✅ |
| `server_setup_screen.dart` | `23 → 0` | ✅ |
| `login_screen.dart` | `18 → 0` | ✅ |

#### v0.7.4+5 — Batch 3

| Datei | Hardcodes | Status |
|---|---|---|
| `artikel_detail_screen.dart` | `36 → 0` | ✅ |
| `artikel_list_screen.dart` | `31 → 0` | ✅ |
| `sync_conflict_handler.dart` | `31 → 0` | ✅ |

#### v0.7.4+4 — Batch 2

| Datei | Hardcodes | Status |
|---|---|---|
| `app_theme.dart` | `10 → 0` | ✅ |
| `conflict_resolution_screen.dart` | `82 → 0` | ✅ |
| `sync_error_widgets.dart` | `59 → 0` | ✅ |
| `sync_management_screen.dart` | `43 → 0` | ✅ |

#### v0.7.4+3 — Batch 1

| Datei | Hardcodes | Status |
|---|---|---|
| `sync_progress_widgets.dart` | `55 → 0` | ✅ |
| `settings_screen.dart` | `54 → 0` | ✅ |

---


## 3. 📊 Historische Phasen-Planung (Archiv)

Dieser Status entspricht dem Stand zum Abschluss der Performance-Phase (v0.8.6).

| Phase | Fortschritt | Status |
|---|---|---|
| Phase 1: Grundlagen | 100% | ✅ Abgeschlossen |
| Phase 2: Deployment & Security | 100% | ✅ Abgeschlossen |
| Phase 3: Performance & Optimierung | 100% | ✅ Abgeschlossen |
| Phase 4: Multi-Plattform & Politur | 100% | ✅ Abgeschlossen |

### Historischer Plattform-Status

| Plattform | Status (Stand v0.8.6) |
|---|---|
| Web (Chrome) | ✅ Voll funktionsfähig |
| Linux Desktop | ✅ Build & PDF-Export stabil |
| Windows Desktop | ✅ Build & Export stabil |
| Android | ✅ Build & Kamera stabil (S20 verifiziert) |
| iOS/macOS | ⏸️ Zurückgestellt (Account fehlt) |

---


## 4. Archiv: nicht eindeutig versionierte Einträge

### 2026-03-25 — 📋 Dokumente zum Artikel

#### 🗄️ Datenbank (lokal & Server)
- Neue Tabelle `artikel_dokumente` in der lokalen SQLite-Datenbank
- PocketBase Collection `artikel_dokumente` als serverseitiges Gegenstück

#### 📱 Flutter App
- `DokumentModel`
- `DokumentRepository`
- `DokumentSyncService`
- Dokumente-Tab im Artikel-Detail

#### 🔄 Synchronisation
- Dokumente getrennt von Textdaten und Bildern
- Gleiche ETag/UUID-Strategie wie bei Artikeln
- Hard-Delete auf dem Server bei lokal `deleted = 1`

---

### März 2026 — Die „kritische Phase“ (Härtung & Optimierung)

In diesem Monat wurde die App von einem Prototyp zu einem produktionsreifen System transformiert.

#### Meilensteine Phase 3 & 4
- Datenbank-Tuning mit 5 strategischen Indizes
- Artikelnummer-System ab 1000
- Security Hardening in Docker
- CI/CD für Android, Windows und Docker

---

### 🔍 Zusammenfassung technischer Analysen

#### Analyse der README & Struktur (März 2026)
- Problem: fragmentierte Dokumentation und Redundanzen
- Lösung: Modularisierung in `README.md`, `INSTALL.md` und `docs/*.md`
- Ergebnis: saubere Single-Source-of-Truth-Struktur

#### Synchronisations-Architektur (Phase 2 Review)
- Konzept: Offline-First mit Delta-Synchronisation
- Implementierung: `updated_at` + `deleted`
- Erkenntnis: Last-Write-Wins reicht für Einzelnutzer, benötigt aber Konflikt-UI für Multi-User

---

### 🚀 Pull-Request-Historie (Zusammenfassung)

#### PR #33: Dokumentations-Konsolidierung
- Modulare Dokumentationsstruktur finalisiert
- `README.md` auf < 200 Zeilen verschlankt
- Historische Zusammenfassungen in `HISTORY.md` archiviert

#### PR #32: Zentralisierte Konfiguration
- Einführung von `AppConfig`, `AppTheme` und `AppImages`
- Eliminierung von 200+ hartcodierten Werten
- Vollständiger Dark-Mode Support via Material 3

#### PR #30 & #31: Docker & Backup
- Docker-Build-Context auf Repository-Root korrigiert
- 3 Backup-Methoden dokumentiert

---

### Ohne explizite Versions- und Datumsangabe

#### K-001: Bundle Identifiers
- Android: `com.germanlion67.lagerverwaltung` ✅
- iOS: `com.germanlion67.lagerverwaltung` ✅

---

## 5. Historische Architektur-Entscheidungen

1. **Caddy statt Nginx (Container)**  
   Caddy wurde gewählt, da es HTTPS/HSTS und SPA-Routing mit minimaler Konfiguration ermöglicht.

2. **Docker-Context auf Root**  
   Um lokale Pakete im Docker-Build nutzen zu können, wurde der Kontext auf die oberste Ebene gehoben.

3. **Soft-Delete**  
   Datensätze werden nie physikalisch gelöscht, damit Clients Löschvorgänge beim nächsten Sync erkennen.

4. **Singleton statt Provider für `PocketBaseService`**  
   Die URL-Konfiguration wird vor `runApp()` benötigt. Ein Provider wäre dafür zu spät verfügbar.

---

*Dieses Dokument wird bei Abschluss größerer versionierter Meilensteine aktualisiert, um den Projektverlauf nachvollziehbar zu halten.*