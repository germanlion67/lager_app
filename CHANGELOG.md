# 📝 Changelog

Alle wichtigen Änderungen am Projekt werden in dieser Datei dokumentiert.

## [0.8.0+1] - 2026-04-11

### 🔑 Infrastruktur: Android Release-Keystore hinzugefügt

- **Neues Feature:** Implementierung eines stabilen Android Release-Keystores für GitHub Actions.
- **Ziel:** Sicherstellung der Update-Fähigkeit von Android-Apps und sauberer Signierung im Release-Workflow.
- **Details:** Ausführliche Anleitung zur Erzeugung des Keystores, Base64-Kodierung für GitHub Secrets, Workflow-Anpassung zur Dekodierung und Nutzung der `key.properties`-Datei, sowie Gradle-Konfiguration für das Signieren von Release-Builds.
- **Sicherheit:** Keystore-Dateien und Passwörter werden niemals im Repository gespeichert (`.gitignore` aktualisiert), sondern sicher über GitHub Secrets verwaltet.
- **Dokumentation:** Detaillierte Schritte und Hinweise sind in der neuen Datei `ANDROID_RELEASE_KEYSTORE.md` zu finden. Ein Verweis wurde in der `README.md` hinzugefügt.


## [0.8.0] - 2026-04-10

### 🎉 Hauptfeature: Kaltstart-Bug Fix

#### Problem
Nach einem Kaltstart (App-Daten gelöscht, neue PocketBase-URL konfiguriert)
blieb die Artikelliste leer, obwohl der Sync im Hintergrund erfolgreich lief.
Bilder wurden nicht heruntergeladen und der Benutzer sah keine Rückmeldung.

#### Ursachen (4 Stück)
1. **Sync-UI-Entkopplung:** ArtikelListScreen wusste nicht, wann der Sync
   abgeschlossen war → Liste wurde nie automatisch neu geladen
2. **Fehlender Bild-Download:** PocketBase-Sync übertrug nur Metadaten
   (remoteBildPfad), lud aber keine Bilddateien herunter
3. **Globaler Image-Cache-Clear:** `imageCache.clear()` verwarf bei jeder
   Bildänderung ALLE gecachten Bilder → Flackern der gesamten Liste
4. **Sofortiger UI-Wechsel nach Setup:** Setup-Screen wechselte sofort
   zur leeren Artikelliste, ohne auf den initialen Sync zu warten

### ✨ Neue Features

#### SyncStatusProvider Interface
- Neues `SyncStatusProvider`-Interface für lose Kopplung zwischen
  `SyncOrchestrator` und UI-Komponenten
- `ArtikelListScreen` hört auf `SyncStatus`-Events und lädt bei
  `success` automatisch die Artikelliste neu
- `FakeSyncStatusProvider` als Test-Double für Widget-Tests
- Sync-Indikator („Synchronisiere Artikel…") bei leerer Liste
  während laufendem Sync

#### Automatischer Bild-Download
- Neue Methode `downloadMissingImages()` in `PocketBaseSyncService`
- Prüft nach jedem Record-Sync alle Artikel auf fehlende lokale Bilder
- Lädt Bilder von der PocketBase File-API herunter (mit Auth-Header)
- Speichert im App-Cache-Verzeichnis
- Neue DB-Methode `setBildPfadByUuidSilent()` — setzt nur `bildPfad`,
  ohne `updated_at`/`etag` zu ändern → kein erneuter Push

#### PocketBase-Bild-Fallback (Mobile/Desktop)
- `_LocalThumbnail` zeigt bei fehlendem lokalen Bild ein PocketBase-
  Thumbnail via `CachedNetworkImage` an (Kaltstart-Überbrückung)
- `ArtikelDetailBild` mit `_buildPbDetailFallback()` für Vollbild-
  Fallback aus PocketBase

#### Setup-Flow mit Sync-Abwarten
- Setup-Screen zeigt Lade-Overlay („Erstmalige Synchronisation…")
  während der initiale Sync läuft
- UI wechselt erst zur Artikelliste, wenn Sync abgeschlossen ist
- Buttons im Setup-Screen werden während Sync deaktiviert

### 🔧 Technisch

#### Neue Dateien
- `lib/services/sync_status_provider.dart` — Interface
- `lib/screens/list_screen_cache_io.dart` — Gezieltes Image-Evict (Mobile/Desktop)
- `lib/screens/list_screen_cache_stub.dart` — No-op für Web
- `test/helpers/fake_sync_status_provider.dart` — Test-Double
- `test/services/sync_status_provider_test.dart` — Unit-Tests

#### Geänderte Dateien
- `lib/services/sync_orchestrator.dart`
  — `implements SyncStatusProvider`
  — `downloadMissingImages()` in `runOnce()` eingebunden
- `lib/services/pocketbase_sync_service.dart`
  — `downloadMissingImages()`, `_buildImageUrl()`, `_buildAuthHeaders()`
  — Neue Imports: `dart:io`, `http`, `path_provider`
- `lib/services/artikel_db_service.dart`
  — Neue Methode `setBildPfadByUuidSilent()`
- `lib/screens/artikel_list_screen.dart`
  — `syncStatusProvider` Parameter + `StreamSubscription`
  — Sync-Indikator bei leerer Liste + laufendem Sync
  — Gezieltes `evictLocalImage()` statt `imageCache.clear()`
  — Conditional Import für Cache-Helper
- `lib/main.dart`
  — `_onServerConfigured()`: Sync abwarten vor UI-Wechsel
  — `_buildHomeWithBackground()`: Orchestrator als `syncStatusProvider`
- `lib/screens/server_setup_screen.dart`
  — `_isSyncingAfterSetup` + Lade-Overlay mit `Stack`
  — Buttons disabled während Sync
- `lib/widgets/artikel_bild_widget.dart`
  — `_LocalThumbnail`: PB-URL-Fallback via `CachedNetworkImage`
  — `ArtikelDetailBild`: `_buildPbDetailFallback()`

#### Performance-Verbesserung
- `_clearImageCache()` evicted jetzt nur das geänderte Bild + Thumbnail
  statt den gesamten Image-Cache zu leeren
- Conditional Import (`list_screen_cache_io.dart` / `_stub.dart`)
  für plattformübergreifende Kompatibilität

### 📚 Dokumentation
- `CHANGELOG.md` — Aktualisiert für v0.8.0
- `OPTIMIZATIONS.md` — Kaltstart-Fix dokumentiert, Version auf 0.8.0
- `TESTING.md` — Neue Tests dokumentiert, Gesamtzahl aktualisiert
- `ARCHITECTURE.md` — SyncStatusProvider Interface dokumentiert
- `DATABASE.md` — `setBildPfadByUuidSilent()` und Bild-Download dokumentiert
- `LOGGER.md` — Neue Log-Events dokumentiert

### ⚙️ Technische Details

**Bild-Fallback-Kette (Mobile/Desktop):**

| Priorität | Quelle | Geschwindigkeit |
|---|---|---|
| 1 (höchste) | Lokales Thumbnail (`thumbnailPfad`) | ⚡ Sofort |
| 2 | Lokales Vollbild (`bildPfad`) | ⚡ Sofort |
| 3 | PocketBase-URL via CachedNetworkImage | 🌐 Netzwerk |
| 4 (niedrigste) | Placeholder-Icon | ⚡ Sofort |

**Sync-Datenfluss:**
SyncOrchestrator.runOnce()
→ _emit(SyncStatus.running)
→ syncOnce() (Push + Pull)
→ downloadMissingImages()
→ _emit(SyncStatus.success)
↓
syncStatus Stream (broadcast)
↓
ArtikelListScreen._syncSubscription
↓
_ladeArtikel() → UI aktualisiert

### 🧪 Tests

#### Neue Test-Dateien (v0.8.0)
- `test/models/attachment_model_test.dart` — **30 Tests**
  Konstruktor, `fromPocketBase()` mit Null/Typ-Koercion, `dateiGroesseFormatiert`
  (B/KB/MB-Grenzen), `typLabel`, `istBild`, `copyWith()`, Gleichheit, Konstanten
- `test/utils/attachment_utils_test.dart` — **28 Tests**
  `validateAttachment()` (Größe, Limit, MIME, Erweiterung, Leer, Prioritäten),
  `mimeTypeFromExtension()`, `iconForMimeType()`, `colorForMimeType()`,
  `AttachmentValidation`
- `test/services/backup_status_test.dart` — **22 Tests**
  `fromJson()` mit Null/Typ-Koercion, `isSuccess`/`isError`, `lastBackupTime` UTC,
  `ageCategory` (fresh/aging/critical), `ageText` (Singular/Plural/Warnung),
  `BackupStatus.unknown`, `BackupAge` Enum

#### Gesamtstand
| Vorher | Nachher | Differenz |
|---|---|---|
| 347 Tests, 15 Dateien | **451 Tests**, 18 Dateien | **+104 Tests**, +3 Dateien |

- `flutter analyze`: **0 Issues**
- `flutter test`: **451 bestanden**, 3 übersprungen
- `docs/TESTING.md` auf v0.8.0 aktualisiert

## [0.7.8] - 2026-04-09 

### ✨ Verbessert - UI Ansicht

#### 🖼️ Artikel-Detail-Screen
- **Artikelname editierbar:** Name kann direkt im Detail-Screen geändert werden
  — neues Textfeld als erstes Eingabefeld, AppBar-Titel aktualisiert sich live
- **Crop-Button:** Nach Bildauswahl erscheint ein „Zuschneiden"-Button
  direkt unter dem Bild (nur im Edit-Modus, nur wenn neues Bild gewählt)
- **Aufgeräumter Body:** Bild-Buttons, Anhänge-Button und Speichern-Button
  aus dem Body entfernt — alle Aktionen jetzt übersichtlich in der AppBar

#### 🎛️ AppBar-Aktionen (Detail-Screen)
- **Bild wählen / Kamera:** Icons erscheinen nur im Edit-Modus
- **Anhänge:** Immer sichtbar, mit Badge-Zähler bei vorhandenen Anhängen
- **Ändern / Speichern:** Edit- und Save-Icon ersetzen den Body-Button
- **PDF-Export & Löschen:** Unverändert, jetzt konsistent in der AppBar

#### 📝 Artikel-Erfassen-Screen
- **Großbuchstabe am Anfang:** `textCapitalization: sentences` für Name,
  Beschreibung, Ort und Fach — Menge und Artikelnummer bleiben numerisch
- **Menge-Feld:** Beim Antippen wird der gesamte Inhalt automatisch
  markiert — die voreingestellte `0` muss nicht mehr manuell gelöscht werden
- **Bild-Buttons kompakter:** „Bilddatei wählen" und „Kamera" jetzt als
  schlanke `IconButton` statt breiter `FilledButton.tonalIcon`

#### 🔍 Artikel-Liste
- **QR-Scanner neben Suchfeld:** Scanner-Button direkt als `IconButton.filled`
  rechts neben dem Suchfeld — kein separater FAB mehr nötig
- **„Neuer Artikel" in AppBar:** `Icons.add` in der AppBar ersetzt den
  `FloatingActionButton.extended` — spart Platz, wirkt aufgeräumter
- **DB-Icon grün bei Verbindung:** PocketBase-Verbindungsicon zeigt nun
  `AppConfig.statusColorConnected` (Material Green 500) statt
  `colorScheme.tertiary` — eindeutigeres visuelles Feedback

### 🔧 Technisch

- `AppConfig.statusColorConnected` (`Color(0xFF4CAF50)`) als neues
  semantisches Token für den Online-Status ergänzt
- `import 'package:flutter/material.dart' show BoxFit, Color, EdgeInsets;`
  in `app_config.dart` um `Color` erweitert
- `AnhaengeSektion.build()` gibt `SizedBox.shrink()` zurück —
  Sheet wird ausschließlich über AppBar-Icon geöffnet
- `FocusNode _mengeFocus` mit automatischer Vollauswahl in
  `artikel_erfassen_screen.dart` eingeführt
- `_nameController` in `artikel_detail_screen.dart` vollständig in
  `initState`, `dispose`, `_speichernWeb`, `_speichernMobile` und
  `_generateArtikelDetailPdf` integriert
- `flutter analyze`: **0 Issues**

## [0.7.7+5] - 2026-04-08

### Test (O-006): Widget-Tests ArtikelErfassenScreen

11 Widget-Tests für `artikel_erfassen_screen.dart`.

**Render:** Pflichtfeld-Labels, Bilddatei-Button, Kamera-Button-Sichtbarkeit,
Speichern + Abbrechen vorhanden.

**Validierung:** Leere Pflichtfelder, Name < 2 Zeichen,
Artikelnummer < 1000, Menge 0 gültig.

**Abbrechen:** Ohne Änderungen kein Dialog, nach Eingabe Dialog,
Weiter bearbeiten schließt Dialog.

### Feature (P-002): Suche Debounce + DB-Suche

**Problem:** Jeder Tastendruck löste sofort einen clientseitigen Filter
über die gesamte geladene Liste aus — bei großen Beständen spürbar träge.

**AppConfig — neue Tokens:**
- `searchDebounceDuration = 300ms`
- `searchResultLimit = 100`

**artikel_list_screen.dart:**
- `_onSuchbegriffChanged()`: Timer(300ms) — feuert erst nach Tipp-Pause
- `_fuehreSucheAus()`: Mobile → `_db.searchArtikel()` (SQL LIKE),
  Web → clientseitig filtern
- Skeleton (count: 4) während laufender DB-Suche
- Pagination-Footer ausgeblendet bei aktiver Suche
- Leermeldung zeigt Suchbegriff an

**Neuer Such-Flow:**
Tastendruck → 300ms Pause → DB-Suche
Feld leeren → sofort zurück zur paginierten Liste
Suche aktiv → kein Pagination-Nachladen

## [0.7.7+4] - 2026-04-07

### Feature (M-005): Pagination für Artikelliste

**Problem:** Alle Artikel wurden beim Start auf einmal aus SQLite geladen —
bei großen Beständen führte das zu spürbaren Verzögerungen und hohem
Speicherverbrauch.

**AppConfig — neue Pagination-Tokens**
- `paginationPageSize = 30`
- `paginationScrollThreshold = 200.0`

**artikel_list_screen.dart**
- `ScrollController` mit `_onScroll()`-Listener
- `_ladeArtikel()`: Reset + erste Seite laden
- `_ladeNaechsteSeite()`: Offset-basiertes Nachladen mit Guard gegen
  Doppel-Requests und aktive Suche
- `ListView.builder`: Lade-Footer (`CircularProgressIndicator`) am
  Listenende solange `_hasMore = true`
- Web: `_hasMore = false` — `getFullList()` lädt weiterhin alles auf einmal

### Chore (O-005): Deprecated Code entfernt

Seit M-012 nicht mehr verwendete Dateien gelöscht.

**Entfernt:**
- `lib/screens/_dokumente_button.dart`
- `lib/screens/_dokumente_button_stub.dart`
- `lib/utils/dokumente_utils.dart`
- `test/dokumente_utils_test.dart`
- `test/widgets/dokumente_button_test.dart`

`cached_network_image` bleibt — wird in `artikel_bild_widget.dart`,
`artikel_detail_screen.dart` und `attachment_list_widget.dart` genutzt.

**Neuer Flow (Mobile/Desktop):**

## [0.7.7+2] - 2026-04-07

### Performance (P-001): Kamera-Vorschau-Delay auf Android behoben

**Problem:** Kamera-Capture auf Android verursachte Multi-Sekunden-Delays vor der
Vorschau, da Crop-Dialog + Re-Encode `pickImageCamera()` synchron blockierten.
Bildbreite war zusätzlich hardcodiert auf 1600px.

**AppConfig — neue Kamera-Tokens**
- `cameraTargetMaxWidth = 800`
- `cameraTargetMaxHeight = 800`
- `cameraImageQuality = 85`

**ImagePickerService**
- `pickImageCamera()` übergibt `maxWidth`/`maxHeight`/`imageQuality` aus AppConfig
  → reduziert Dateigröße direkt an der Quelle
- Automatischer Crop-Dialog entfernt — gibt Bytes sofort nach Capture zurück
  (`ensureTargetFormat(crop: false)`)
- `openCropDialog()` als public static Methode verfügbar

**ArtikelErfassenScreen**
- `_cropImage()`: öffnet `ImageCropDialog`, führt `ensureTargetFormat` auf Ergebnis
  aus und ruft `setState`
- „Zuschneiden" `OutlinedButton` rechts unterhalb der Vorschau,
  nur sichtbar wenn `_bildBytes != null`

**Neuer Flow:**

## [0.7.7+1] - 2026-04-06

### Tests (T-001): Konfliktlösungs-Tests — Widget-Tests abgeschlossen
- **T-001.3** — `SyncService.detectConflicts()`: 9 Tests mit Mockito-Mocks
  (`MockNextcloudClient`, `MockArtikelDbService`)
  - ETag-Übereinstimmung → kein Konflikt
  - ETag-Abweichung → Konflikt erkannt, `downloadItem()` aufgerufen
  - Mehrere Konflikte gleichzeitig
  - Fehlerbehandlung: DB-Fehler, `downloadItem()`-Fehler (graceful)
  - `detectedAt` liegt im erwarteten Zeitfenster
- **T-001.4** — `_determineConflictReason()` via `detectConflicts()`: 15 Tests
  - Gleiche Zeitstempel → `'Gleichzeitige Bearbeitung'`
  - |diff| < 60s → `'Zeitnahe Bearbeitung (Xs Unterschied)'`
  - Grenzfall 60s → `'Lokale Version neuer (1m)'`
  - Lokal neuer: Minuten, Stunden, Tage
  - Remote neuer: Minuten, Stunden
- **T-001.5** — `ConflictResolutionScreen` Widget-Tests: 20 Tests
  - Leere Liste, Fortschrittsanzeige, LinearProgressIndicator
  - `useLocal` / `useRemote` aktiviert `'Auflösen'`-Button
  - `applyConflictResolution()` wird korrekt aufgerufen
  - `skip` ruft `applyConflictResolution()` nicht auf
  - Pop-Result enthält `resolved`/`skipped` als `Map<String, dynamic>`
  - Multi-Konflikt-Navigation (`1/2` → `2/2`)
  - Hilfe-Dialog öffnen/schließen
  - Merge-Dialog öffnet sich

### Bugfix
- `RenderFlex`-Overflow (+4px) in Widget-Tests behoben:
  `setSurfaceSize(1024×900)` + `addTearDown(reset)` in `pumpConflictScreen()`

### Dokumentation
- `docs/TESTING.md` — T-001 auf 77 Tests aktualisiert, Kategorie `Unit + Widget`,
  `setSurfaceSize`-Besonderheit dokumentiert, Gesamtzahl auf 298 aktualisiert
- `OPTIMIZATIONS.md` — T-001 Unit/Widget-Tests als abgeschlossen markiert,
  Version auf 0.7.7+1, Datum auf 06.04.2026
- `HISTORY.md` — Meilenstein v0.7.7+1 dokumentiert
- `CHANGELOG.md` — Aktualisiert

## [0.7.7] - 2026-04-05

### Release-Zusammenfassung
Qualitäts-Release: Zentrales Error Handling, Loading States, Input Validation, umfangreiche Unit-Tests und neue Test-Dokumentation.

### Feature (M-003): Zentrales Error Handling — Abgeschlossen
- Neue `AppException`-Hierarchie (`sealed class`): `NetworkException`, `ServerException`,
  `AuthException`, `SyncException`, `StorageException`, `ValidationException`, `UnknownException`
- Neuer `AppErrorHandler` mit:
  - `classify()` — übersetzt rohe Exceptions automatisch
  - `log()` — level-bewusstes Logging (warning vs. error)
  - `showSnackBar()` — einfacher Fehler-SnackBar
  - `showSnackBarWithDetails()` — SnackBar + Details-Dialog-Button
  - `showErrorDialog()` — modaler Fehler-Dialog
  - `_getSuggestions()` — kontextabhängige Lösungsvorschläge
- `sync_conflict_handler.dart`: rohe `$e`-Strings → `AppErrorHandler`
- `SocketException` / `HandshakeException` / `TimeoutException` / `ClientException` automatisch klassifiziert
- Lint-Fixes: `instantiate_abstract_class`, `unnecessary_null_comparison`, `unreachable_switch_case`

### Feature (M-004): Loading States — Abgeschlossen
- Zentrales `AppLoadingOverlay`-Widget mit optionalem Text
- `AppLoadingIndicator` für Inline-Bereiche
- `AppLoadingButton` ersetzt alle manuellen Spinner-in-Button-Konstrukte
- `ArtikelSkeletonTile` + `ArtikelSkeletonList` mit Shimmer-Animation
- `artikel_list_screen.dart`: Skeleton statt `CircularProgressIndicator`
- `artikel_detail_screen.dart`: Overlay beim Speichern und Löschen
- `sync_management_screen.dart`: Overlay während aktivem Sync
- 10 neue `AppConfig`-Tokens für Skeleton und Overlay

### Feature (M-006): Input Validation — Abgeschlossen
- Pflichtfelder: Name, Ort, Fach mit Inline-Fehlermeldungen
- Name: Mindestlänge 2 Zeichen, max. 100 Zeichen
- Menge: Nur positive Ganzzahlen (≥ 0), max. 999.999, via `FilteringTextInputFormatter`
- Artikelnummer: Automatisch vorgegeben (≥ 1000), manuell änderbar
- Duplikat-Check: Name + Ort + Fach (Kombination), lokal + PocketBase
- Duplikat-Check: Artikelnummer, lokal + PocketBase
- 5 neue `AppConfig`-Tokens für Validierungsgrenzen
- Neue DB-Methoden: `existsKombination()`, `existsArtikelnummer()`

### Tests (O-002): Unit-Tests für Core-Utilities — Abgeschlossen (128 neue Tests)
**ArtikelDbService (75 Tests)**
- `sqflite_common_ffi` mit `inMemoryDatabasePath` — kein Dateisystem nötig
- `injectDatabase()` (`@visibleForTesting`) für saubere Test-Isolation
- `ArtikelDbServiceTestHelper` — wiederverwendbarer In-Memory-Setup
- Abgedeckte Methoden: `insertArtikel`, `getAlleArtikel`, `updateArtikel`, `deleteArtikel`,
  `getArtikelByUUID`, `getArtikelByRemotePath`, `getPendingChanges`, `markSynced`,
  `upsertArtikel`, `searchArtikel`, `existsKombination`, `existsArtikelnummer`,
  `setLastSyncTime`, `getLastSyncTime`, `isDatabaseEmpty`, `getMaxArtikelnummer`,
  `deleteAlleArtikel`, `insertArtikelList`, `updateBildPfad`, `updateRemoteBildPfad`,
  `setBildPfadByUuid`, `setThumbnailPfadByUuid`, `setThumbnailEtagByUuid`,
  `setRemoteBildPfadByUuid`, `getUnsyncedArtikel`

**ArtikelModel (64 Tests)**
- Konstruktor, `isValid()`, `toMap()`, `fromMap()`, Roundtrip, `copyWith()`, `==`/`hashCode`/`toString()`

**ImageProcessingUtils (30 Tests)**
- Kompression, Rotation, Thumbnail-Generierung vollständig abgedeckt
- `rotateClockwise()`: quadratische + rechteckige Bilder, 4 Richtungen
- Randwerte: leere Byte-Arrays, ungültige Formate

**UuidGenerator (23 Tests)**
- Eindeutigkeit: 10.000 UUIDs ohne Kollision
- RFC-4122 V4 Format-Validierung (8-4-4-4-12, version-bit, variant-bit)
- `isValidV4()`: gültige + ungültige Eingaben, Leerstring, Sonderzeichen

### Bugfix
- `getUnsyncedArtikel()` nutzte `""` statt `''` für SQL-Leerstring-Literale
  (auf Mobile nicht sichtbar, von `sqflite_common_ffi` korrekt abgelehnt)

### Dokumentation
- `docs/TESTING.md` — Neues Dokument: alle Tests beschrieben, lokaler Aufruf erklärt
- `OPTIMIZATIONS.md` — O-002 als abgeschlossen markiert, Version auf 0.7.7
- `HISTORY.md` — Meilensteine v0.7.6+x und v0.7.7 dokumentiert
- `README.md` — Link zu TESTING.md ergänzt

## [0.7.5+1] - 2026-04-03

### Feature (M-008): Backup-Status im Settings-Screen anzeigen — Abgeschlossen
Neues Feature: Backup-Status wird im Settings-Screen als Card angezeigt.

Änderungen:
- BackupStatusService: Liest last_backup.json via HTTP vom PocketBase-Server
- BackupStatusWidget: Farbcodierte Status-Card (Grün <24h, Gelb 1-3d, Rot >3d)
  - Loading/Error/Unknown-States
  - Detail-Zeilen: Zeitpunkt, Datei, Größe, Backup-Anzahl, Rotation
  - Fehler-Details bei fehlgeschlagenem Backup
  - Refresh-Button zum manuellen Aktualisieren
- settings_screen.dart: BackupStatusWidget zwischen PocketBase- und Artikelnummer-Card
- backup.sh: write_status() kopiert last_backup.json nach pb_public für HTTP-Zugriff
- docker-compose.prod.yml: pb_public Volume für Backup-Container ergänzt
- M-008 als erledigt markiert (18/28 Aufgaben abgeschlossen)

## [0.7.5+0] - 2026-04-02

### Feature (M-007): UI für Konfliktlösung — Abgeschlossen
- **M-007 als erledigt markiert**: `ConflictResolutionScreen` war bereits vollständig
  implementiert (seit O-004 Batch 2), fehlte nur in der OPTIMIZATIONS.md-Dokumentation
- **K-003 umbenannt**: Alte M-007 (Artikelnummer & Indizes) zu K-003 umbenannt,
  um Doppelung zu beseitigen

### Bestehende Implementierung (verifiziert)
- `ConflictResolutionScreen` mit Side-by-Side-Vergleich (Lokale vs. Remote Version)
- `ConflictData`-Klasse und `ConflictResolution`-Enum in `conflict_resolution_screen.dart`
- Multi-Konflikt-Navigation mit Fortschrittsanzeige und LinearProgressIndicator
- `_MergeDialog` für manuelle Feld-für-Feld-Zusammenführung mit Bild-Auswahl
- Entscheidungs-Callbacks: `useLocal`, `useRemote`, `merge`, `skip`
- Vollständige Integration mit `SyncConflictHandler` und `SyncService`
- Hilfe-Dialog mit Erklärung aller Konfliktarten und Lösungsoptionen

### Tests (T-001)
- **Neue Testdatei:** `app/test/conflict_resolution_test.dart`
  - 37 Unit-Tests in 6 Gruppen
  - T-001.1: `ConflictData` — Konstruktor, Felder, Null-Handling (11 Tests)
  - T-001.2: `ConflictResolution` Enum — Werte, Index, `byName` (6 Tests)
  - T-001.4: Konflikt-Grund-Szenarien (5 Tests)
  - T-001.extra: Feld-Vergleiche über Artikel-Properties (11 Tests)
  - T-001.extra: ConflictData in Collections und Resolution-Tracking (4 Tests)
- **T-001 als neue Aufgabe** in OPTIMIZATIONS.md erstellt (manuelle Integrationstests ausstehend)

### Dokumentation
- `OPTIMIZATIONS.md` — M-007 nach ✅ verschoben, K-003 umbenannt, T-001 erstellt,
  Fortschritts-Übersicht aktualisiert (17/28 erledigt), Version auf 0.7.5+0
- `CHANGELOG.md` — Aktualisiert für v0.7.5+0
- `HISTORY.md` — Meilenstein v0.7.5+0 dokumentiert

## [0.7.4+7] - 2026-04-02

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 5 (Cleanup, O-004 abgeschlossen ✅)
- **~80 Hardcodes migriert** in 11 Dateien, **~41 bewusst beibehalten** (dokumentiert)
- O-004 abgeschlossen: ~560 von ~600 Hardcodes eliminiert (~93%)
- Kein visuelles Redesign — gleiche Optik, sauberer Code

#### list_screen_mobile_actions.dart — 17 Hardcodes → 0
- `Colors.orange/red` (SnackBars) → `colorScheme.secondary/error`
- `Colors.blue/green/orange/purple` (Dialog-Icons) → `colorScheme.primary/tertiary/secondary`
- `SizedBox(width: 8)` → `AppConfig.spacingSmall`

#### nextcloud_settings_screen.dart — 21 Hardcodes → 0
- `Colors.green/red/orange` (Verbindungstest-SnackBars) → `colorScheme.tertiary/error/secondary`
- `Colors.blue/white` (Button-Styling) → `FilledButton` (nutzt Theme automatisch)
- `SizedBox(width: 18, height: 18)` → `AppConfig.iconSizeSmall`
- `fontSize: 14` → `textTheme.bodyMedium`
- Alle `EdgeInsets`/`SizedBox` → AppConfig-Tokens

#### qr_scan_screen_mobile_scanner.dart — 6 migriert, 6 bewusst beibehalten
- `fontSize: 18/14` → `textTheme.bodyLarge/bodyMedium`
- `BorderRadius.circular(16)` → `AppConfig.borderRadiusXLarge`
- `width: 3` → `AppConfig.strokeWidthThick`
- Bewusst beibehalten: `Colors.black54/black/white/red` (Kamera-Overlay-Maskierung)

#### image_crop_dialog.dart — 6 migriert, 5 bewusst beibehalten
- `Colors.red` (Fehler-Icon) → `colorScheme.error`
- `Colors.white` (Text auf schwarzem BG) → `colorScheme.onInverseSurface`
- `SizedBox(width: 18, height: 18)` → `AppConfig.iconSizeSmall`
- `size: 48` → `AppConfig.iconSizeXLarge`
- Alle `EdgeInsets`/`SizedBox` → AppConfig-Tokens
- Bewusst beibehalten: `Colors.black` + `Color.fromRGBO` (Crop-Library-Parameter)

#### artikel_erfassen_screen.dart — 12 Hardcodes → 0
- `const spacing = 12.0` → `AppConfig.spacingMedium`
- `SizedBox(width: 12)` → `AppConfig.spacingMedium`
- `BorderRadius.circular(8)` → `AppConfig.borderRadiusMedium`
- `SizedBox(width: 18, height: 18)` → `AppConfig.iconSizeSmall`
- `strokeWidth: 2` → `AppConfig.strokeWidthMedium`
- `EdgeInsets.all(16)` → `AppConfig.spacingLarge`

#### list_screen_web_actions.dart — 8 Hardcodes → 0
- `Colors.orange/red` (SnackBars) → `colorScheme.secondary/error`

#### artikel_bild_widget.dart — 3 migriert, 2 bewusst beibehalten
- `strokeWidth: 2` → `AppConfig.strokeWidthMedium`
- `strokeWidth: 1.5` → `AppConfig.strokeWidthThin`
- Bewusst beibehalten: `Colors.grey` in Platzhalter-Icons (neutrale Farbe auf AppImages-BG)

#### nextcloud_resync_dialog.dart — 7 Hardcodes → 0
- `Colors.red/green/orange` (SnackBars) → `colorScheme.error/tertiary/secondary`
- `SizedBox(width: 16)` → `AppConfig.spacingLarge`
- `fontSize: 12` → `textTheme.bodySmall`
- `fontWeight: FontWeight.bold` → `textTheme.bodyMedium?.copyWith(fontWeight: ...)`

#### Bewusst beibehalten (dokumentiert, ~41 Stellen)
- `detail_screen_io.dart` (3): Platzhalter-Farben ohne BuildContext
- `list_screen_io.dart` (3): Platzhalter-Farben ohne BuildContext
- `list_screen_mobile_actions_stub.dart` (4): Stub ohne Widget-Tree-Kontext
- `_dokumente_button.dart` (18): Deprecated (M-012-Cleanup)
- `qr_scan_screen_mobile_scanner.dart` (6): Kamera-Overlay-Maskierung
- `image_crop_dialog.dart` (5): Crop-Library-Parameter + Vorschau-BG
- `artikel_bild_widget.dart` (2): Platzhalter-Icons

### Dokumentation
- `THEMING.md` — Batch-5-Status aktualisiert, O-004 als abgeschlossen markiert
- `OPTIMIZATIONS.md` — O-004 als abgeschlossen markiert, Gesamtfortschritt ~93%
- `CHANGELOG.md` — Aktualisiert für v0.7.4+7

## [0.7.4+6] - 2026-04-02

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 4 (Attachment & Setup, ~92 Hardcodes)
- **92 Hardcodes eliminiert** in 4 Dateien + 13 neue AppConfig-Tokens
- Dark Mode funktioniert jetzt korrekt in allen Attachment- und Auth-Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code

#### AppConfig (`app/lib/config/app_config.dart`)
- 13 neue Design-Tokens ergänzt:
  - **Icon-Sizes:** `iconSizeXLarge` (48), `iconSizeXXLarge` (64)
  - **Layout:** `loginFormMaxWidth` (400), `setupFormMaxWidth` (480),
    `loginLogoSize` (80), `buttonHeight` (48), `exampleLabelWidth` (85)
  - **Progress:** `progressIndicatorSizeSmall` (20)
  - **Attachments:** `attachmentImageWidth` (56), `attachmentImageHeight` (48),
    `attachmentIconSize` (28), `attachmentIconContainerSize` (48),
    `uploadAreaIconSize` (40)

#### attachment_upload_widget.dart — 28 Hardcodes eliminiert
- `Colors.red/red.shade*` → `colorScheme.error/errorContainer/onErrorContainer`
- `Colors.grey` → `colorScheme.onSurfaceVariant`
- `Colors.white` (Progress-Color) → entfernt (const CircularProgressIndicator)
- `fontSize: 12/13/18` → `textTheme.bodySmall/titleMedium`
- Alle `EdgeInsets`/`SizedBox`/`BorderRadius` → AppConfig-Tokens
- `withOpacity` → `withValues`

#### attachment_list_widget.dart — 23 Hardcodes eliminiert
- `Colors.red` (Löschen-Button, SnackBar) → `colorScheme.error`
- `Colors.grey` (Leertext, Datei-Info) → `colorScheme.onSurfaceVariant`
- `withOpacity(0.1)` → `withValues(alpha: AppConfig.opacitySubtle)`
- `fontSize: 12` → `textTheme.bodySmall`
- `size: 48/28/32/40` → `AppConfig.attachmentIconContainerSize/attachmentIconSize/progressIndicatorSize/uploadAreaIconSize`
- Alle `EdgeInsets`/`SizedBox`/`BorderRadius` → AppConfig-Tokens
- Loading/Empty/Error-States nutzen jetzt `const` wo möglich

#### server_setup_screen.dart — 23 Hardcodes eliminiert
- `Colors.blue.shade*` → `colorScheme.primaryContainer/onPrimaryContainer`
- `Colors.green.shade*` → `colorScheme.tertiaryContainer/onTertiaryContainer`
- `Colors.red.shade*` → `colorScheme.errorContainer/onErrorContainer`
- `Colors.white` (Progress-Color) → `colorScheme.onPrimary`
- `size: 64` → `AppConfig.iconSizeXXLarge`
- `maxWidth: 480` → `AppConfig.setupFormMaxWidth`
- Alle `EdgeInsets`/`SizedBox`/`BorderRadius` → AppConfig-Tokens
- Alle `withOpacity` → `withValues`

#### login_screen.dart — 18 Hardcodes eliminiert
- `Colors.red.shade*` → `colorScheme.errorContainer/onErrorContainer`
- `Colors.grey[600]` → `colorScheme.onSurfaceVariant`
- `size: 80` → `AppConfig.loginLogoSize`
- `height: 48` → `AppConfig.buttonHeight`
- `fontSize: 14/16` → `textTheme.bodyMedium/titleMedium`
- `horizontal: 32.0` → `AppConfig.spacingXXLarge`
- Alle `withOpacity` → `withValues`

### Dokumentation
- `THEMING.md` — 13 neue Tokens dokumentiert, Batch-4-Status aktualisiert
- `CHANGELOG.md` — Aktualisiert für v0.7.4+6
- `CHECKLIST.md` — Batch 4 als erledigt markiert, Gesamtfortschritt ~82%

---

## [0.7.4+5] - 2026-04-02

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 3 (Artikel-Cluster, ~98 Hardcodes)
- **98 Hardcodes eliminiert** in 3 Dateien
- Dark Mode funktioniert jetzt korrekt in allen Artikel-bezogenen Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code
- Keine neuen AppConfig-Tokens nötig — alle Werte auf bestehende gemappt

#### artikel_detail_screen.dart — 36 Hardcodes eliminiert
- Colors.white/grey[100] (fillColor) → colorScheme.surface/surfaceContainerLow
- Colors.black (labelStyle/textStyle) → entfernt (Theme greift automatisch)
- Colors.grey[200]/grey[400] (Platzhalter) → colorScheme.surfaceContainerHighest/onSurfaceVariant
- Colors.red (Löschen-Button) → colorScheme.error
- Colors.white/black (Vollbild) → colorScheme.onInverseSurface + Colors.black (BG bleibt schwarz)
- Alle EdgeInsets/SizedBox → AppConfig-Tokens
- BorderRadius.circular(12/16) → AppConfig.cardBorderRadiusLarge/borderRadiusXLarge
- AnhaengeSheet: Handle-Bar + Header nutzen jetzt colorScheme + textTheme

#### artikel_list_screen.dart — 31 Hardcodes eliminiert
- Colors.green[600]/red[600]/grey[600] (Status-Icons) → colorScheme.tertiary/error/onSurfaceVariant
- Colors.red (SnackBar) → colorScheme.error
- Colors.grey (Leertext) → textTheme.titleSmall + colorScheme.onSurfaceVariant
- Colors.blueGrey[600] (Artikelnummer) → textTheme.labelSmall + colorScheme.onSurfaceVariant
- Colors.blue/green/red/orange (Dialog-Icons) → colorScheme.primary/tertiary/error/secondary
- fontSize: 11/12/16 → textTheme.labelSmall/bodySmall/bodyLarge
- PopupMenuItem PDF-Icon: Colors.red → colorScheme.error

#### sync_conflict_handler.dart — 31 Hardcodes eliminiert
- Colors.green/orange/grey/red/blue (SnackBar/Status) → colorScheme.*
- Colors.white (SnackBar textColor) → colorScheme.onTertiary/onError
- Colors.grey[100/300] (Error-Dialog) → colorScheme.surfaceContainerLow/outlineVariant
- buildSyncButton: Colors.blue/white → entfernt (FAB nutzt Theme)
- buildSyncStatus: Statische Methode → _SyncStatusCard Widget (BuildContext für colorScheme)
- Alle EdgeInsets/SizedBox → AppConfig-Tokens

### Dokumentation
- `THEMING.md` — Batch-3-Status aktualisiert
- `CHANGELOG.md` — Aktualisiert für v0.7.4+5
- `CHECKLIST.md` — Batch 3 als erledigt markiert, Gesamtfortschritt ~67%

---

## [0.7.4+4] - 2026-04-01

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 2 (Sync-Cluster)
- **193 Hardcodes eliminiert** in 4 Dateien + 2 neue AppConfig-Tokens
- Dark Mode funktioniert jetzt korrekt in allen Sync-bezogenen Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code

#### AppConfig (`app/lib/config/app_config.dart`)
- 2 neue Design-Tokens ergänzt:
  - **Layout:** `infoLabelWidthSmall` (80), `buttonPaddingVertical` (12)

#### app_theme.dart — 10 Hardcodes eliminiert
- `EdgeInsets`-Werte in Component-Themes → `AppConfig.spacingLarge/spacingMedium`
- `BorderRadius.circular(12)` → `AppConfig.cardBorderRadiusLarge`
- `fontSize: 20` → `AppConfig.fontSizeXXLarge`
- ListTile `contentPadding` → `AppConfig.listTilePadding`

#### conflict_resolution_screen.dart — 82 Hardcodes eliminiert
- `Colors.orange/green/blue/purple/grey` → `colorScheme.*`
- AppBar nutzt jetzt Standard-Theme (keine manuellen Farben)
- Merge-Dialog: `Colors.blue/green.withValues` → `colorScheme.*Container`
- Radio-Buttons: `Colors.blue/grey` → `colorScheme.primary/outlineVariant`
- 6 duplizierte Status-Container-Patterns konsolidiert

#### sync_error_widgets.dart — 59 Hardcodes eliminiert
- `_getSeverityColor()` nutzt jetzt `BuildContext` + `colorScheme`
- `Colors.red[700]/orange[700]/blue[700]/grey[700]` → `colorScheme.*`
- `SyncErrorBanner`: `Colors.red[100]/orange[100]` → `colorScheme.*Container`
- Technische Details: `Colors.grey[100]` → `colorScheme.surfaceContainerLow`

#### sync_management_screen.dart — 43 Hardcodes eliminiert
- AppBar nutzt jetzt Standard-Theme (keine manuellen Farben)
- `Colors.blue/orange/red/green` → `colorScheme.primary/secondary/error/tertiary`
- Alle Section-Titel → `textTheme.titleMedium`

### Dokumentation
- `THEMING.md` — 2 neue Tokens dokumentiert, Batch-2-Status aktualisiert
- `OPTIMIZATIONS.md` — Batch 2 als erledigt markiert, Gesamtfortschritt aktualisiert
- `HISTORY.md` — Meilenstein v0.7.4+4 dokumentiert

---

## [0.7.4+3] - 2026-04-01

### Refactoring (O-004): UI-Hardcoded Werte migrieren — Batch 1
- **109 Hardcodes eliminiert** in 2 Fokus-Dateien + AppConfig erweitert
- Dark Mode funktioniert jetzt korrekt in allen migrierten Widgets
- Kein visuelles Redesign — gleiche Optik, sauberer Code

#### AppConfig (`app/lib/config/app_config.dart`)
- 13 neue Design-Tokens ergänzt:
  - **Icon-Sizes:** `iconSizeXSmall` (14), `iconSizeSmall` (16),
    `iconSizeMedium` (20), `iconSizeLarge` (24)
  - **Stroke:** `strokeWidthThin` (1), `strokeWidthMedium` (2),
    `strokeWidthThick` (3)
  - **Layout:** `infoLabelWidth` (120), `avatarRadiusSmall` (20),
    `dialogContentWidth` (300), `progressIndicatorSize` (32)
  - **Opacity:** `opacitySubtle` (0.1), `opacityLight` (0.2),
    `opacityMedium` (0.3)

#### sync_progress_widgets.dart
- 55 Hardcodes → 0 verbleibend
- `Colors.red/green/blue/orange` → `colorScheme.error/tertiary/primary/secondary`
- `Colors.grey[300/600]` → `colorScheme.surfaceContainerHighest/onSurfaceVariant`
- `Colors.white` → `colorScheme.onPrimary`
- Alle `EdgeInsets`/`SizedBox`/`BorderRadius` → AppConfig-Tokens
- `_getStatusColor()` und `_buildStatChip()` nutzen jetzt `BuildContext`

#### settings_screen.dart
- 54 Hardcodes → 0 verbleibend
- `Colors.green.shade*` → `colorScheme.tertiary/tertiaryContainer`
- `Colors.red.shade*` → `colorScheme.error/errorContainer`
- `Colors.orange.shade*` → `colorScheme.secondary/secondaryContainer`
- `Colors.blue.shade*` → `colorScheme.primary/primaryContainer`
- 6 duplizierte Status-Container → wiederverwendbare `_buildStatusContainer()`
  Methode mit `_StatusType` Enum (DRY-Refactoring)
- SnackBar-Farben → `_showConnectionSnackBar()` Helper extrahiert

### Dokumentation
- `THEMING.md` — Vollständige Token-Referenz mit Tabellen, Farb-Zuordnungstabelle
  für O-004, Dark-Mode-Hinweise für Entwickler
- `OPTIMIZATIONS.md` — O-004 Batch 1 als erledigt markiert, Batch 2–5 Roadmap
  mit Hardcode-Counts, H-002 und M-009 in Abgeschlossen verschoben
- `CHANGELOG.md` — Aktualisiert

---

## [0.7.4+0] - 2026-03-30

### Sicherheit (H-002)
- **CORS-Konfiguration:** `CORS_ALLOWED_ORIGINS` wird jetzt als `--origins` Flag
  an PocketBase übergeben
- Neues `entrypoint.sh` ersetzt inline CMD im Dockerfile
- Wildcard-Warnung im Container-Log für Entwicklungsumgebungen
- Produktion erzwingt explizite Origins (Container startet nicht ohne)

### Infrastruktur
- Portainer Stack an Produktions-Setup angeglichen (NPM, Netzwerk-Isolation)
- `docker-compose.production.yml` (Traefik) entfernt — Nginx Proxy Manager ist Standard
- `.env.production` korrigiert: öffentliche URL statt Docker-interner URL

### Dokumentation
- DEPLOYMENT.md: CORS-Abschnitt mit Regeln, Prüfung und Domain-Umzug-Anleitung
- DEPLOYMENT.md: Portainer Stack mit NPM und Environment Variables
- OPTIMIZATIONS.md: H-002 als abgeschlossen markiert

---

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