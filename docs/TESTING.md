# 🧪 Tests – Übersicht & lokaler Aufruf

Dieses Dokument beschreibt alle automatisierten Tests der **Lager_app**, ihre Zielsetzung und wie sie lokal ausgeführt werden.

**Version:** 0.8.1+12 | **Zuletzt aktualisiert:** 13.04.2026

---

## 🚀 Schnellstart

```bash
# Alle Tests ausführen (aus dem app/-Verzeichnis)
cd lager_app/app
flutter test
```

> 💡 Beim ersten Aufruf einmalig `flutter pub get` ausführen.

✅ **590 Tests bestanden, 3 skipped, 0 Fehler** — kein `--exclude-tags performance` mehr nötig.
Der Performance-Test ist self-contained und erzeugt seine Testdaten automatisch.

> `--exclude-tags performance` ist weiterhin optional verfügbar, aber nicht mehr erforderlich.
---

## 📋 Testübersicht

| Datei | Kategorie | Anzahl Tests | Aufgabe |
|---|---|---|---|
| `test/conflict_resolution_test.dart` | Unit + Widget | 77 | T-001 |
| `test/models/artikel_model_test.dart` | Unit | 64 | O-002 |
| `test/models/attachment_model_test.dart` | Unit | 30 | O-002 |
| `test/services/artikel_db_service_test.dart` | Integration | 75 | O-002 |
| `test/services/backup_status_test.dart`        | Unit          | 22  | T-006  |
| `test/services/attachment_service_test.dart`   | Unit          | 34  | T-005  |
| `test/services/image_picker_service_test.dart` | Unit + Widget | 15  | O-007  |
| `test/services/pocketbase_sync_service_test.dart` | Unit | 17 | T-002 |
| `test/utils/attachment_utils_test.dart` | Unit | 28 | – |
| `test/utils/image_processing_utils_test.dart` | Unit | 30 | O-002 |
| `test/utils/uuid_generator_test.dart` | Unit | 23 | O-002 |
| `test/services/app_log_service_test.dart` | Unit | 14 | – |
| `test/services/nextcloud_listfiles_test.dart` | Unit | 1 | – |
| `test/dokumente_utils_test.dart` | Unit | 3 | – |
| `test/models/nextcloud_credentials_test.dart` | Unit | 4 | – |
| `test/services/artikel_import_service_test.dart` | Unit | 4 | – |
| `test/services/artikel_export_service_test.dart` | Unit + Widget | 2 | – |
| `test/widgets/dokumente_button_test.dart` | Widget | 1 | – |
| `test/widgets/artikel_erfassen_test.dart` | Widget | 11 | O-006 |
| `test/widgets/artikel_detail_screen_test.dart` | Widget | 24 | O-006 |
| `test/widgets/artikel_list_screen_test.dart` | Widget | 15 | O-006 |
| `test/services/sync_status_provider_test.dart` | Unit | 5 | K-006 |
| `test/helpers/fake_sync_status_provider.dart` | Test-Helper | – | K-006 |
| `test/performance/import_500_smoke_test.dart` | Performance | 1  | T-007 |
| `test/widgets/merge_dialog_test.dart` | Widget | 18 | T-004 |
| `test/services/nextcloud_client_test.dart`     | Unit          | 39  | T-003  |
| **Gesamt** | | **576** (+3 skipped) | |

---

## 🔬 Test-Beschreibungen

### `services/nextcloud_client_test.dart` — T-003 (39 Tests) ✅ NEU

**Ziel:** Unit-Tests für `NextcloudClient` — alle WebDAV-Operationen (HEAD, MKCOL,
PROPFIND, GET, PUT, DELETE) gegen einen injizierten `MockClient` ohne Netzwerk.

**Strategie:**
- `MockClient` aus `package:http/testing.dart` — identisches Pattern wie T-006
- Optionaler `http.Client? client`-Parameter im `NextcloudClient`-Konstruktor
  (rückwärtskompatibel — Default: `http.Client()`)
- Alle 8 HTTP-Stellen von Top-Level `http.get/put/delete/head` und lokalen
  `http.Client()`-Instanzen auf `_client.get/put/delete/head/send` umgestellt
- PROPFIND-XML-Responses als Inline-Fixtures
- `RemoteItemMeta`-Datenklasse separat getestet (equality, copyWith, toString)

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `RemoteItemMeta` | 3 | equality (path+etag), copyWith, toString |
| `testConnection()` | 5 | 200, 404, 500, Exception, Auth-Header korrekt |
| `createFolder()` | 4 | 201 Created, 405 Already Exists, 500, Exception |
| `listItemsEtags()` | 7 | 1 Item, Multi-Item, leer, 403, Non-JSON-Filter, kein ETag, custom Path |
| `downloadItem()` | 3 | 200 OK, 404 Not Found, Netzwerkfehler |
| `uploadItem()` | 5 | 201+ETag, If-Match Header, 412 Conflict, 500, kein ETag |
| `deleteItem()` | 4 | 204, 404 idempotent, 500, Exception |
| `uploadAttachment()` | 4 | 201+ETag, Content-Type, Default application/octet-stream, 500 |
| `downloadAttachment()` | 2 | 200+Bytes, 404 |
| `URI-Auflösung` | 2 | items-Pfad, attachments-Pfad korrekt aufgelöst |

**Produktionscode-Änderung (minimal):**
- `NextcloudClient`: Neues Feld `final http.Client _client`
- Konstruktor: Optionaler `http.Client? client`-Parameter (`_client = client ?? http.Client()`)
- 6× `http.get/put/delete/head` → `_client.get/put/delete/head`
- 2× lokaler `http.Client()` + `client.send()` + `client.close()` → `_client.send()` (kein close nötig)

```bash
flutter test test/services/nextcloud_client_test.dart
```


### `conflict_resolution_test.dart` — T-001 (77 Tests)

**Ziel:** Testet die vollständige Konfliktlösungs-Pipeline aus `M-007`.

**Abgedeckte Klassen:** `ConflictData`, `ConflictResolution` (Enum), `SyncService.detectConflicts()`, `ConflictResolutionScreen`

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| T-001.1: ConflictData | 11 | Konstruktor, Pflichtfelder, Null-Handling |
| T-001.2: ConflictResolution Enum | 6 | Enum-Werte, Index, `byName` |
| T-001.3: detectConflicts() | 9 | ETag-Vergleich, Konflikt-Erkennung, Fehlerbehandlung |
| T-001.4: _determineConflictReason() | 15 | Zeitstempel-Szenarien (gleich, zeitnah, lokal/remote neuer) |
| T-001.5: Widget-Tests | 20 | ConflictResolutionScreen UI, Navigation, Dialog, Pop-Result |
| T-001.extra: Feld-Vergleiche | 10 | Artikel-Properties als Vergleichsgrundlage |
| T-001.extra: Collections | 4 | ConflictData in Listen, Resolution-Tracking |

**Besonderheit:** Widget-Tests laufen mit `setSurfaceSize(1024×900)` — der Standard-Viewport
(800×600) ist zu klein für die Side-by-Side-Versionskarten nach Auswahl. `addTearDown` stellt
den Default-Viewport nach jedem Test wieder her.

```bash
flutter test test/conflict_resolution_test.dart
```

---

### `services/pocketbase_sync_service_test.dart` — T-002 (17 Tests) ✅ NEU

**Ziel:** Unit-Tests für die PocketBase-Sync-Logik — Push, Pull, Fehlerbehandlung und Bild-Download.

**Strategie:**
- Manuelle Fakes statt `@GenerateMocks` — `PocketBaseService` und `ArtikelDbService` sind
  Singletons mit Factory-Konstruktoren, `PocketBase`/`RecordService` haben komplexe
  Vererbungsketten die mockito nicht automatisch mocken kann
- `TestableSyncService` repliziert die Sync-Logik mit injizierbaren Fakes
- `FakeRecordService` erweitert `RecordService` mit exakten Methoden-Signaturen
  (PocketBase SDK v0.23.2: `skipTotal: bool`, `http.MultipartFile`)
- `RecordModel.fromJson()` statt Konstruktor-Parameter für `id`/`created`/`updated`
- Kein Netzwerk, kein SQLite, kein Dateisystem nötig
- Kein `build_runner` nötig — keine Code-Generierung

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| Push: Create | 1 | Neuer Artikel → `create()`, `markSynced` mit remotePath |
| Push: Update | 1 | Bestehender Artikel → `update()`, kein `create()` |
| Push: Delete | 1 | Soft-deleted → `delete()` + `markSynced('deleted')` |
| Push: Delete (nicht remote) | 1 | Gelöscht aber remote nicht vorhanden → nur `markSynced` |
| Push: Fehlerbehandlung | 1 | Exception bei Artikel 1 → Artikel 2 wird trotzdem verarbeitet |
| Push: Auth/Owner | 1 | `owner` wird im Body gesetzt wenn authentifiziert |
| Pull: Insert | 1 | Neuer Remote-Record → `upsertArtikel()` |
| Pull: Lösch-Sync | 1 | Lokal vorhanden, remote nicht → `deleteArtikel()` |
| Pull: Leere UUIDs | 1 | Kein Lösch-Check wenn remoteUuids leer |
| syncOnce: lastSyncTime | 1 | Wird nach erfolgreichem Sync gesetzt |
| syncOnce: Fehler | 1 | Allgemeiner Fehler wird abgefangen, kein Throw |
| syncOnce: Nur Pull | 1 | Keine Pending Changes → kein Push, nur Pull |
| UUID-Sanitization | 1 | Anführungszeichen werden aus UUID entfernt (Finding 5) |
| Image: kein remoteBildPfad | 1 | Überspringt Download |
| Image: kein remotePath | 1 | Überspringt Download |
| Image: URL leer | 1 | Überspringt Download |
| Image: Bild existiert | 1 | Überspringt Download wenn lokal vorhanden |

```bash
flutter test test/services/pocketbase_sync_service_test.dart
```

---

### `services/attachment_service_test.dart` — T-005 (34 Tests) ✅ NEU

**Ziel:** Unit-Tests für `AttachmentService` — alle CRUD-Operationen gegen PocketBase
ohne Netzwerk, ohne Dateisystem.

**Strategie:**
- `PocketBaseService.overrideForTesting(FakePocketBase)` injiziert Fake-Client
  in den echten `AttachmentService`-Singleton — testet den **echten Code**, nicht eine Kopie
- `FakeAttachmentRecordService extends RecordService` mit Callback-Handlern
  (identisches Pattern wie T-002, erweitert um `perPage`/`page`/`sort`-Parameter)
- `FakePocketBaseForAttachment extends PocketBase` leitet `collection()` um
- `PocketBaseService.dispose()` im `tearDown` räumt Singleton-State auf
- `fakeClientException()` Helper — `ClientException` hat keinen `message`-Parameter
  (PocketBase SDK v0.23.2 nutzt `originalError:`)
- Reiner `test()`-Block — kein `testWidgets`, kein `tester.runAsync()` nötig

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `getForArtikel()` | 6 | Leere Liste, 3 Ergebnisse, Filter/Sort, perPage-Limit, PB-Fehler, fehlende Felder |
| `countForArtikel()` | 4 | 0 Ergebnis, korrekte Anzahl, PB-Fehler, effiziente Query (perPage=1) |
| `upload()` | 10 | Happy-Path, Body-Felder (trimmed, UUID, sort_order), Limit=20, Limit>20, PB-Fehler (create + count), null/leere Beschreibung, null MIME, MultipartFile-Dateiname |
| `updateMetadata()` | 4 | Erfolg, Trimming, null→leerer String, PB-Fehler |
| `delete()` | 4 | Erfolg, korrekte ID, PB-Fehler, Netzwerkfehler |
| `deleteAllForArtikel()` | 4 | Alle löschen, keine vorhanden, teilweise Fehler, getForArtikel-Fehler |
| Integration | 2 | Upload→Get-Roundtrip, Grenzwert 19 vs 20 |

**Architektur-Entscheidung:** `PocketBaseService.overrideForTesting()` statt
`TestableAttachmentService` (wie T-002) — weil `PocketBaseService` die Hooks
bereits anbietet und so der echte `AttachmentService`-Code getestet wird.

```bash
flutter test test/services/attachment_service_test.dart
```

---

### `models/attachment_model_test.dart` — O-002 (30 Tests) ✅

**Ziel:** Vollständige Abdeckung des `AttachmentModel` — reine Modell-Logik ohne Abhängigkeiten.

**Abgedeckte Klassen:** `AttachmentModel`, Konstanten (`kErlaubteMimeTypes`, `kMaxAttachmentBytes`, `kMaxAttachmentsPerArtikel`)

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| Konstruktor | 2 | Pflichtfelder, nullable optionale Felder |
| `fromPocketBase()` | 7 | Vollständiger Record, Null-Handling, String→int, double→int, UTC-Datum, ungültiges Datum, Parameter-Priorität |
| `dateiGroesseFormatiert` | 8 | null, 0, Bytes, KB, MB, Grenzwerte (1 KB, 1 MB, 10 MB) |
| `typLabel` | 7 | Bild, PDF, Word, Excel/CSV, Text, Fallback (unbekannt + null) |
| `istBild` | 3 | true für image/*, false für andere, false bei null |
| `copyWith()` | 3 | Identische Kopie, Teilüberschreibung, downloadUrl |
| Gleichheit | 4 | `==` nur auf id, `!=`, `hashCode`, `toString()` |
| Konstanten | 4 | Whitelist enthält erwartete Typen, keine unsicheren Typen, Limits |

```bash
flutter test test/models/attachment_model_test.dart
```

---

### `services/artikel_db_service_test.dart` — O-002 (75 Tests)

**Ziel:** Integrationstests für alle Methoden des `ArtikelDbService`.

**Strategie:**
- `sqflite_common_ffi` mit `inMemoryDatabasePath` — kein Dateisystem nötig
- `injectDatabase()` (`@visibleForTesting`) für saubere Test-Isolation
- `ArtikelDbServiceTestHelper` für wiederverwendbaren In-Memory-Setup

| Methode | Tests |
|---|---|
| `insertArtikel()` | Einfügen, UUID-Eindeutigkeit, ConflictAlgorithm |
| `getAlleArtikel()` | Pagination, `deleted`-Filter |
| `updateArtikel()` | Feldaktualisierung, `updated_at` |
| `deleteArtikel()` | Soft-Delete (`deleted=1`) |
| `getArtikelByUUID()` | Treffer, kein Treffer |
| `getArtikelByRemotePath()` | Treffer, kein Treffer |
| `getPendingChanges()` | `etag=null`-Filter |
| `markSynced()` | ETag + `remote_path` setzen |
| `upsertArtikel()` | Insert + Update-Pfad |
| `searchArtikel()` | Suche nach Name/Beschreibung |
| `existsKombination()` / `existsArtikelnummer()` | Duplikat-Erkennung |
| `setLastSyncTime()` / `getLastSyncTime()` | Persistierung des Sync-Zeitstempels |
| `isDatabaseEmpty()` | Leere DB erkennen |
| `getMaxArtikelnummer()` | Höchste Artikelnummer |
| `deleteAlleArtikel()` | Alle Einträge löschen |
| `insertArtikelList()` | Batch-Insert |
| `updateBildPfad()` / `updateRemoteBildPfad()` | Bild-Pfad-Updates |
| `setBildPfadByUuid()` / `setThumbnailPfadByUuid()` | UUID-basierte Bild-Updates |
| `setThumbnailEtagByUuid()` / `setRemoteBildPfadByUuid()` | ETag + Remote-Pfad |
| `getUnsyncedArtikel()` | Nicht synchronisierte Artikel |

```bash
flutter test test/services/artikel_db_service_test.dart
```

> ⚠️ **Hinweis:** Dieser Test setzt `sqflite_common_ffi` voraus. Unter Linux/Windows läuft er nativ. Unter macOS kann eine zusätzliche FFI-Konfiguration nötig sein.

---

### `widgets/merge_dialog_test.dart` — T-004 (18 Tests) ✅ NEU

**Ziel:** Widget-Tests für den `_MergeDialog` im `ConflictResolutionScreen` —
alle Felder, Feld-Auswahl, Bild-Auswahl, Zusammenführen-Aktion, Dialog-Schließen.

**Strategie:**
- `_MergeDialog` ist private → wird über den "Manuell zusammenführen"-Button
  im `ConflictResolutionScreen` geöffnet (echter Nutzerfluss)
- `MockSyncService` aus `test/mocks/sync_service_mocks.mocks.dart` (wiederverwendet)
- `setSurfaceSize(1024×900)` für Side-by-Side-Karten (wie T-001.5)
- Felder mit Unterschied isoliert testen (genau 1 "Remote"-Button)
  um Index-Probleme bei `find.widgetWithText()` zu vermeiden

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| Grundstruktur | 6 | Titel, Icons, Buttons, Feld-Labels, Bild-Label |
| Konflikt-Anzeige | 4 | Lokal/Remote-Karten, Warning-Icons, identische Werte, Initialwerte |
| Feld-Auswahl | 3 | Lokal-Button, Remote-Button, manuelle Eingabe |
| Bild-Auswahl | 3 | Radio-Optionen, "Kein Bild", initiale Selektion |
| Zusammenführen-Aktion | 4 | Dialog schließt, korrekte Werte, leerer Name, manuelle Edits |
| Dialog schließen | 2 | Abbrechen, Close-Icon |
| Menge-Feld | 2 | Ungültige Menge Fallback, Remote-Menge per Button |

```bash
flutter test test/widgets/merge_dialog_test.dart
```

---

### `services/backup_status_test.dart` — T-006 (22 Tests) ✅

**Ziel:** Vollständige Abdeckung der `BackupStatus`-Modell-Logik und des `BackupAge`-Enums.

**Abgedeckte Klassen:** `BackupStatus`, `BackupAge` (Enum)

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `fromJson()` | 4 | Vollständiges JSON, Null-Handling, String→int Koercion, Fehler-Status |
| `isSuccess` / `isError` | 3 | success, error, unknown |
| `lastBackupTime` | 2 | Unix→DateTime UTC, Epoch bei 0 |
| `ageCategory` | 4 | fresh (<24h), aging (24–72h), critical (>72h), critical bei Error |
| `ageText` | 6 | "Nie", Stunden, Tage, ⚠️-Warnung, Singular "Tag", Plural "Tagen" |
| `BackupStatus.unknown` | 3 | Defaults, weder success/error, ageText "Nie" |

```bash
flutter test test/services/backup_status_test.dart
```
--- 

### `services/image_picker_service_test.dart` — O-007 (15 Tests) ✅ NEU

**Ziel:** Tests für `ImagePickerService` nach P-001 —
`pickImageCamera()`, `isCameraAvailable`, `openCropDialog()`.

**Strategie:**
- `FakeImagePicker extends ImagePicker` überschreibt `pickImage()` vollständig
  (kein Plattformkanal, kein Platform-Channel-Mock nötig)
- `overrideImagePicker` + `maxFileSizeBytesOverride` (`@visibleForTesting`) für
  saubere Injektion ohne Produktionscode-Komplexität
- `debugDefaultTargetPlatformOverride` steuert `isCameraAvailable` pro Test

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `PickedImage`-Datenklasse | 4 | `empty`, `hasImage` true/false/leer |
| `isCameraAvailable` | 5 | Linux, Windows, macOS → false; Android, iOS → true |
| `openCropDialog()` | 2 | null-bytes → null, leere bytes → null |
| `pickImageCamera()` | 4 | Kamera nicht verfügbar, Picker null, Datei zu groß, Happy-Path |

```bash
flutter test test/services/image_picker_service_test.dart
```

**Strategische Erkenntnisse (dart:io + FakeAsync):**

| Pattern | Falsch ❌ | Richtig ✅ |
|---|---|---|
| `debugDefaultTargetPlatformOverride` zurücksetzen | `addTearDown` (zu spät, nach `_verifyInvariants`) | `try/finally` im Testbody |
| XFile mit In-Memory-Bytes | `XFile(path, bytes: data)` (dart:io ignoriert `bytes:`) | `XFile.fromData(data, name: '...')` |
| Async mit `compute()` / `readAsBytes()` | Direkt in `testWidgets` `await`en | `tester.runAsync(() => ...)` |
| Testbarer Größencheck | 10-MB-`Uint8List` in FakeAsync | `maxFileSizeBytesOverride` + kleine Bytes |

---

### `utils/attachment_utils_test.dart` (28 Tests) ✅

**Ziel:** Vollständige Abdeckung der Attachment-Validierung und Hilfs-Funktionen.

**Abgedeckte Funktionen:** `validateAttachment()`, `mimeTypeFromExtension()`, `iconForMimeType()`, `colorForMimeType()`, `AttachmentValidation`

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `validateAttachment()` | 13 | Gültige PDF/Bild, Limit erreicht/überschritten, zu groß, genau am Limit, leer, unerlaubter MIME, HTML, Erweiterungs-Fallback, alle erlaubten MIMEs, Prüf-Priorität |
| `mimeTypeFromExtension()` | 11 | PDF, JPG/JPEG, PNG, WebP, DOC/DOCX, XLS/XLSX, CSV, TXT, ODT, unbekannt, ohne Erweiterung |
| `iconForMimeType()` | 8 | Bild, PDF, Word, Excel, CSV, Text, Fallback, null |
| `colorForMimeType()` | 8 | Blau/Rot/Indigo/Grün/BlueGrey/Grau für alle Kategorien + null |
| `AttachmentValidation` | 2 | `ok()` gültig, `fehler()` ungültig mit Nachricht |

```bash
flutter test test/utils/attachment_utils_test.dart
```

---

### `utils/image_processing_utils_test.dart` — O-002 (30 Tests)

**Ziel:** Vollständige Abdeckung der Bild-Verarbeitungsfunktionen.

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `ensureTargetFormat()` | ~10 | JPEG-Kompression, Qualitätsstufen, Fehler-Fallback |
| `generateThumbnail()` | ~10 | Thumbnail-Erzeugung, Größe, `null` bei Fehler |
| `rotateClockwise()` | ~10 | Quadratische + rechteckige Bilder, 4 Richtungen, leere Bytes |

**Strategie:**
- `TestWidgetsFlutterBinding` erforderlich (wegen `compute()`)
- Echter JPEG/PNG-Byte-Payload als Fixture (minimal, valide)

```bash
flutter test test/utils/image_processing_utils_test.dart
```

---

### `utils/uuid_generator_test.dart` — O-002 (23 Tests)

**Ziel:** Abdeckung des `UuidGenerator`-Helpers.

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| `generate()` | ~8 | RFC-4122-V4-Format (8-4-4-4-12), Version-Bit, Variant-Bit, Nicht-Leer |
| Eindeutigkeit | 1 | 10.000 UUIDs ohne Kollision |
| `isValid()` | ~7 | Gültige/ungültige UUIDs (alle Versionen) |
| `isValidV4()` | ~6 | Nur V4-Format, Abgrenzung zu V1/V5, Sonderzeichen |
| Klassen-Eigenschaften | 1 | Kann nicht instanziiert werden (nur `static`) |

```bash
flutter test test/utils/uuid_generator_test.dart
```

---

### `services/sync_status_provider_test.dart` — K-006 (5 Tests)

**Ziel:** Tests für das `SyncStatusProvider`-Interface und den `FakeSyncStatusProvider` Test-Double.

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| Initial State | 1 | `isSyncing` ist initial `false` |
| State-Änderungen | 3 | `emitRunning/Success/Error` setzen `isSyncing` korrekt |
| Stream | 1 | `syncStatus` emittiert korrekte Event-Sequenz |

```bash
flutter test test/services/sync_status_provider_test.dart
```

--- 

### `services/nextcloud_listfiles_test.dart` (1 Test)

**Ziel:** Test für die Nextcloud-Dateilisten-Funktion.

- WebDAV-PROPFIND-Response-Parsing

```bash
flutter test test/services/nextcloud_listfiles_test.dart
```

---

### `services/app_log_service_test.dart` (14 Tests)

**Ziel:** Tests für den zentralen `AppLogService`.

- Log-Level-Filterung (debug, info, warning, error)
- Log-Datei-Erzeugung und Rotation
- Keine Abstürze bei fehlgeschlagenen Mock-Aufrufen

```bash
flutter test test/services/app_log_service_test.dart
```

---

### `dokumente_utils_test.dart` (3 Tests)

**Ziel:** Tests für `dokumente_utils.dart` (Datei-Sortierung).

- `sortFilesByName()`: Aufsteigend und absteigend
- `sortFilesByTypeThenName()`: Gruppierung nach Dateityp, dann alphabetisch

```bash
flutter test test/dokumente_utils_test.dart
```

---

### `models/nextcloud_credentials_test.dart` (4 Tests)

**Ziel:** Tests für die `NextcloudCredentials`-Datenklasse.

- Konstruktor mit allen Feldern
- Standard-Werte für optionale Felder
- URI-Parsing

```bash
flutter test test/models/nextcloud_credentials_test.dart
```

---

### `services/artikel_import_service_test.dart` (4 Tests)

**Ziel:** Tests für den `ArtikelImportService` (JSON-Import).

- Gültiges JSON parsen
- Ungültiges JSON (Fehlerfall)
- Leere Liste
- Mock für `path_provider`

```bash
flutter test test/services/artikel_import_service_test.dart
```

---

### `services/artikel_export_service_test.dart` (2 Tests)

**Ziel:** Tests für den `ArtikelExportService` (ZIP-Export).

- Export gibt `null` zurück bei leerer Artikelliste
- `FileSelectorPlatform` wird korrekt gemockt

```bash
flutter test test/services/artikel_export_service_test.dart
```

---

### `widgets/dokumente_button_test.dart` (1 Widget-Test)

**Ziel:** Widget-Test für `DokumenteButton`.

- Button ist sichtbar
- BottomSheet öffnet sich
- Leerzustand bei fehlenden Credentials wird angezeigt

```bash
flutter test test/widgets/dokumente_button_test.dart
```

---

### `widgets/artikel_erfassen_test.dart` — O-006 (11 Widget-Tests) ✅

**Ziel:** Widget-Tests für `ArtikelErfassenScreen`.

**Strategie:**
- `sqflite_common_ffi` In-Memory-DB via `injectDatabase()`
- `pump(Duration)` statt `pumpAndSettle()` — ignoriert laufende HTTP-Timer

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| Render | ~4 | Formularfelder, AppBar-Titel, Pflichtfeld-Markierungen |
| Bild-Buttons | ~4 | IconButtons für Kamera/Galerie/Crop (v0.7.8 Punkt 6) |
| Validierung | ~3 | Pflichtfelder, Fehlermeldungen |

```bash
flutter test test/widgets/artikel_erfassen_test.dart
```

---

### `widgets/artikel_detail_screen_test.dart` — O-006 (24 Widget-Tests) ✅

**Ziel:** Widget-Tests für `ArtikelDetailScreen`.

**Strategie:**
- `sqflite_common_ffi` In-Memory-DB via `injectDatabase()`
- Vollständiges Schema (inkl. `deleted`, `uuid`, `updated_at`)
- `pump(Duration)` statt `pumpAndSettle()`

| Gruppe | Tests | Was wird geprüft |
|---|---|---|
| Render | ~6 | Artikelname, Felder, AppBar |
| Name editierbar (Punkt 1) | ~4 | Inline-Edit, Speichern, Abbrechen |
| Crop-Button (Punkt 2) | ~3 | Button vorhanden, Icon korrekt |
| AppBar-Aktionen | ~5 | Bearbeiten, Löschen, Teilen |
| Navigation | ~6 | Zurück-Navigation, Pop-Result |

```bash
flutter test test/widgets/artikel_detail_screen_test.dart
```

---

### `widgets/artikel_list_screen_test.dart` — O-006 (15 Widget-Tests) ✅

**Ziel:** Widget-Tests für `ArtikelListScreen`.

**Strategie (v0.7.9 - Refactored):**
- `sqflite_common_ffi` In-Memory-DB via `injectDatabase()`
- Vollständiges Schema (inkl. `deleted`, `uuid`, `updated_at`)
- `NoOpNextcloudService` — Timer-freier Test-Double via `NextcloudServiceInterface`
- `initialArtikel: []` — überspringt async DB-Load, `_isLoading` sofort `false`
- Einfaches `pump()` reicht — kein `pumpAndSettle()`, kein `runAsync()`, kein Timer-Workaround

Architektur-Änderungen (v0.7.9):

| Gruppe | Tests | Status | Was wird geprüft |
|---|---|---|---|
| Render | 4 | ✅ | AppBar-Titel, Suchfeld, Dropdown, DB-Icon |
| QR-Button (Punkt 7) | 2 | ✅ | QR-Button neben Suchfeld, kein FAB |
| Neuer Artikel AppBar (Punkt 8) | 4 | ✅ | AppBar-Buttons, Navigation zu ErfassenScreen |
| Menü | 2 | ✅ | more_vert Button, Menü-Einträge |
| Suche | 2 | ✅ | Texteingabe, Leer-Hinweis |
| DB-Icon Farbe (Punkt 9) | 1 | ✅ | Icon-Farbe nicht null |

Gelöstes Problem: In v0.7.8 schlugen 3 Tests mit A Timer is still pending fehl, weil
NextcloudConnectionService.startPeriodicCheck() in initState() einen Timer.periodic
startete, der im Test-Kontext nicht gestoppt werden konnte (Singleton + Factory-Konstruktor).
Die Lösung: Dependency Injection über ein Interface — der Test injiziert einen
NoOpNextcloudService, der keinen Timer startet.

> **Hinweis (v0.8.0):** `ArtikelListScreen` akzeptiert jetzt einen optionalen
> `syncStatusProvider`-Parameter. In Tests ohne Sync-Bedarf kann dieser
> weggelassen werden (Default: `null`). Für Sync-UI-Tests wird
> `FakeSyncStatusProvider` aus `test/helpers/` verwendet.

```bash
flutter test test/widgets/artikel_list_screen_test.dart
```

---

### `performance/import_500_smoke_test.dart` — T-007 (1 Performance-Test) ✅

**Ziel:** Smoke-Test für Existenz und Struktur eines 500-Artikel-Datensatzes.

> ℹ️ **Self-contained seit v0.8.0+6:** `setUpAll()` generiert alle benötigten
> Testdaten programmatisch — kein manueller Vorbereitungsschritt nötig.
> `@Tags(['performance'])` bleibt erhalten — der Test kann weiterhin via
> `--exclude-tags performance` übersprungen werden.

**Test-Ablauf:**

| Schritt | Aktion |
|---|---|
| `setUpAll()` | Erzeugt `test_data/import_500.json` (500 Artikel) + 10 PNG-Fixtures (1×1 Pixel) |
| Test | Prüft Existenz der Fixture-Datei, JSON-Struktur (Liste, 500 Einträge) und Bild-Fixtures (Index 0–9) |
| `tearDownAll()` | Löscht `test_data/images/`, `test_data/import_500.json` und `test_data/` (wenn leer) |

```bash
# Im regulären flutter test automatisch enthalten:
flutter test

# Gezielt ausführen:
flutter test test/performance/import_500_smoke_test.dart

# Optional überspringen:
flutter test --exclude-tags performance
```

**Für manuelle Großdatensätze (1000+, 5000+):**
```bash
dart run tool/generate_import_dataset.dart --count 1000
```

---

## 🛠️ Einzelne Testgruppen ausführen

```bash
# Alle Unit-Tests
flutter test test/models/ test/utils/ test/services/ test/dokumente_utils_test.dart

# Nur Widget-Tests
flutter test test/widgets/

# Nur O-006 Widget-Tests
flutter test test/widgets/artikel_erfassen_test.dart \
             test/widgets/artikel_detail_screen_test.dart \
             test/widgets/artikel_list_screen_test.dart

# Nur O-002 Tests (Core-Utilities + DB)
flutter test test/services/artikel_db_service_test.dart \
             test/utils/uuid_generator_test.dart \
             test/utils/image_processing_utils_test.dart \
             test/models/artikel_model_test.dart \
             test/models/attachment_model_test.dart

# Nur T-002 Tests (PocketBase Sync)
flutter test test/services/pocketbase_sync_service_test.dart

# Nur T-004 Tests (MergeDialog)
flutter test test/widgets/merge_dialog_test.dart

# Nur T-005 Tests (AttachmentService)
flutter test test/services/attachment_service_test.dart

# Nur neue Tests (v0.8.1+11)
flutter test test/widgets/merge_dialog_test.dart \
             test/services/attachment_service_test.dart \
             test/services/pocketbase_sync_service_test.dart \
             test/models/attachment_model_test.dart \
             test/utils/attachment_utils_test.dart \
             test/services/backup_status_test.dart

# Verbose-Ausgabe (jeder Testname einzeln)
flutter test --exclude-tags performance --reporter expanded

# Bei Fehlern: Stack-Trace anzeigen
flutter test --exclude-tags performance --reporter expanded --no-pub
```

---

## 🔧 Voraussetzungen

| Anforderung | Details |
|---|---|
| Flutter SDK | ≥ 3.41.4 (empfohlen: aktuell) |
| Betriebssystem | Linux, Windows oder macOS |
| `flutter pub get` | Einmalig im `app/`-Verzeichnis ausführen |
| `--exclude-tags performance` | Empfohlen für reguläre Testläufe |
| Performance-Test | Optional: `dart run tool/generate_import_dataset.dart` |

---

## 🚫 Manuelle Integrationstests (T-001)

Die folgenden Tests sind **nicht automatisierbar** und müssen manuell durchgeführt werden (erfordern zwei verbundene Geräte oder Browser-Tabs):

| Test | Beschreibung |
|---|---|
| T-001.6 | Artikel auf Gerät A ändern, offline auf Gerät B ändern → Sync → Konflikt-UI erscheint |
| T-001.7 | „Lokal behalten" → Server wird überschrieben |
| T-001.8 | „Server übernehmen" → Lokale Daten werden ersetzt |
| T-001.9 | „Zusammenführen" → Merge-Dialog, Felder manuell wählen, Ergebnis korrekt |
| T-001.10 | „Überspringen" → Konflikt bleibt, erscheint beim nächsten Sync erneut |
| T-001.11 | Mehrere Konflikte gleichzeitig → Navigation Weiter/Zurück, Fortschrittsanzeige |
| T-001.12 | Edge Case: Soft-Delete lokal + Edit remote → Konflikt korrekt erkannt |

---

## 🧰 Test-Infrastruktur

### Test-Helpers (`test/helpers/`)

| Datei | Beschreibung | Verwendet in |
|---|---|---|
| `fake_sync_status_provider.dart` | Test-Double für `SyncStatusProvider` — emittiert kontrollierte Sync-Events | `sync_status_provider_test.dart`, zukünftige Sync-UI-Tests |

### Verwendung von `FakeSyncStatusProvider`

```dart
import '../helpers/fake_sync_status_provider.dart';

final fake = FakeSyncStatusProvider();

// In Widget-Test:
ArtikelListScreen(syncStatusProvider: fake);

// Events emittieren:
fake.emitRunning();   // → UI zeigt Lade-Indikator
fake.emitSuccess();   // → UI lädt Artikelliste neu
fake.emitError();     // → UI zeigt Fehlerzustand
fake.emitIdle();      // → UI im Ruhezustand

// Aufräumen:
fake.dispose();
```

### Fake-Klassen für PocketBase Sync (`pocketbase_sync_service_test.dart`)

| Klasse | Beschreibung |
|---|---|
| `FakePbService` | Minimaler Ersatz für `PocketBaseService` — kontrollierbare Properties (`client`, `isAuthenticated`, `currentUserId`, `url`) |
| `FakeArtikelDbService` | Ersatz für `ArtikelDbService` — speichert Aufrufe in Listen für Assertions |
| `FakeRecordService` | Erweitert `RecordService` — Handler-Callbacks für `getList`, `getFullList`, `create`, `update`, `delete` |
| `FakePocketBase` | Erweitert `PocketBase` — leitet `collection()` auf `FakeRecordService` um |
| `TestableSyncService` | Repliziert `PocketBaseSyncService`-Logik mit injizierbaren Fakes |


### Fake-Klassen für AttachmentService (`attachment_service_test.dart`)

| Klasse | Beschreibung |
|---|---|
| `FakeAttachmentRecordService` | Erweitert `RecordService` — Handler-Callbacks für `getList`, `create`, `update`, `delete` mit erweiterten Parametern (`perPage`, `page`, `sort`) |
| `FakePocketBaseForAttachment` | Erweitert `PocketBase` — leitet `collection()` auf `FakeAttachmentRecordService` um |
| `fakeClientException()` | Helper-Funktion — erzeugt `ClientException` mit `originalError:` (PocketBase SDK v0.23.2 hat keinen `message:`-Parameter) |

---

## 🔗 Verwandte Dokumente

- **[OPTIMIZATIONS.md](OPTIMIZATIONS.md)** — Aufgaben-Tracking
- **[DATABASE.md](DATABASE.md)** — Datenbankschema und Sync-Logik
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — Gesamtarchitektur

---

*Dieses Dokument wird bei jeder neuen Test-Suite aktualisiert.*

---

## Änderungen gegenüber v0.8.1+11

| **Aspekt** | **v0.8.1+11** | **v0.8.1+12** |
|---|---|---|
| **Version** | 0.8.1+11 | 0.8.1+12 |
| **Testübersicht** | 537 Tests, 25 Einträge | 576 Tests, 26 Einträge |
| **Gesamtzahl (Schnellstart)** | 551 bestanden | 590 bestanden |
| **T-003-Sektion** | Nicht vorhanden | Neu: 39 Tests NextcloudClient |
| **Testübersicht-Tabelle** | Kein `nextcloud_client_test.dart` | 1 neue Zeile |
| **Produktionscode** | `NextcloudClient` nutzt Top-Level `http.*` | `NextcloudClient` nutzt injizierten `_client` |
| **Gesamtzahl-Tabelle** | 537 | 576 |